//----------------------------------------------------------------
//  worker.js
//
//  Changelog:
//      Paulinchen  2026-09-29: Added world rooms, each a Durable Object that seats up to 32 games
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

// The relay on Cloudflare: a Worker that sends each room's requests to a Durable Object of its own,
// which keeps the room's WebSockets. The rules come from the core, so the Node server keeps the
// same ones.

import { DurableObject } from "cloudflare:workers";
import {
  CLOSE, IN, OUT, PAIRED, PING, PONG, admit, newPeer, newWorldPeer, nextDeadline, nextWorldDeadline, overdue, parseRoute, routeWorldMessage,
  seatChangeText, seatText, takeMessage, takeSeat, worldCapacity, worldOverdue,
} from "../core/relay.js";

/**
 * Sends a WebSocket request to its room or world room, and refuses anything else.
 */
export default {
  /**
   * Handles a request to the relay.
   *
   * @param {Request} request The request.
   * @param {{ROOMS: DurableObjectNamespace, WORLDS: DurableObjectNamespace}} env The Worker's bindings.
   * @returns {Promise<Response>} The room's answer, or why the request is refused.
   */
  async fetch(request, env) {
    const route = parseRoute(new URL(request.url));

    if ("error" in route) {
      return new Response(route.error, { status: 400 });
    }

    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("the relay only takes WebSockets", { status: 426 });
    }

    const rooms = route.kind === "world" ? env.WORLDS : env.ROOMS;
    return rooms.get(rooms.idFromName(route.roomId)).fetch(request);
  },
};

/**
 * One room: a host and a guest, whose binary messages it passes on to each other.
 *
 * It uses Cloudflare's WebSocket hibernation, so a host waiting alone costs no run time; Cloudflare
 * may then drop the object's memory, which is why each peer's record rides on its socket.
 */
export class Room extends DurableObject {
  /**
   * Creates the room and has Cloudflare answer keep-alives itself.
   *
   * @param {DurableObjectState} ctx The object's state.
   * @param {object} env The Worker's bindings.
   */
  constructor(ctx, env) {
    super(ctx, env);
    // Answered without waking the room, so a host's keep-alives while it waits cost nothing.
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair(PING, PONG));
  }

  /**
   * Lets a peer into the room, unless its role is taken.
   *
   * @param {Request} request The WebSocket request, already checked by the Worker.
   * @returns {Promise<Response>} The WebSocket, or why the peer may not join.
   */
  async fetch(request) {
    const { role } = parseRoute(new URL(request.url));
    const refusal = admit(this.peers().map((peer) => peer.record.role), role);

    if (refusal) {
      return new Response(refusal.reason, { status: 409 });
    }

    const [client, server] = Object.values(new WebSocketPair());
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment(newPeer(role, Date.now()));

    const peers = this.peers();

    if (peers.length === 2) {
      for (const peer of peers) {
        peer.socket.send(PAIRED);
      }
    }

    await this.schedule(peers);
    return new Response(null, { status: 101, webSocket: client });
  }

  /**
   * Passes a peer's binary message on to the other peer. A message sent before the other peer
   * arrived is dropped, which the Multiplayer mod never does.
   *
   * @param {WebSocket} socket The peer's socket.
   * @param {ArrayBuffer | string} message The message.
   */
  async webSocketMessage(socket, message) {
    if (typeof message === "string") {
      // Keep-alives are answered by Cloudflare before they get here, so any other text is wrong.
      socket.close(CLOSE.badRequest, "only binary messages are passed on");
      return;
    }

    const { peer, refusal } = takeMessage(socket.deserializeAttachment(), message.byteLength, Date.now());
    socket.serializeAttachment(peer);

    if (refusal) {
      socket.close(refusal.code, refusal.reason);
      return;
    }

    this.peers().find((other) => other.socket !== socket)?.socket.send(message);
  }

  /**
   * Ends the room for the other peer once one leaves.
   *
   * @param {WebSocket} socket The peer's socket.
   */
  async webSocketClose(socket) {
    this.leave(socket);
  }

  /**
   * Ends the room for the other peer once one's connection breaks.
   *
   * @param {WebSocket} socket The peer's socket.
   */
  async webSocketError(socket) {
    this.leave(socket);
  }

  /**
   * Closes the peers whose time is up, and looks again at the next deadline.
   */
  async alarm() {
    const peers = this.peers();
    const closed = overdue(peers.map((peer) => peer.record), Date.now());

    for (const { index, code, reason } of closed) {
      peers[index].socket.close(code, reason);
    }

    await this.schedule(peers.filter((_, index) => !closed.some((entry) => entry.index === index)));
  }

  /**
   * Closes a leaving peer's socket and every other peer's.
   *
   * @param {WebSocket} socket The leaving peer's socket.
   */
  leave(socket) {
    try {
      socket.close(CLOSE.normal, "closed");
    } catch {
      // The socket is closed already, which is all this wants.
    }

    for (const other of this.peers()) {
      if (other.socket !== socket) {
        other.socket.close(CLOSE.peerLeft, "the other side left");
      }
    }
  }

  /**
   * Lists the peers in the room, with their records.
   *
   * @returns {{socket: WebSocket, record: object}[]} The peers.
   */
  peers() {
    return this.ctx.getWebSockets()
      .map((socket) => ({ socket, record: socket.deserializeAttachment() }))
      .filter((peer) => peer.record);
  }

  /**
   * Sets the alarm to the room's next deadline, or clears it for an empty room.
   *
   * @param {{record: object}[]} peers The peers that stay.
   */
  async schedule(peers) {
    const at = nextDeadline(peers.map((peer) => peer.record));

    if (at === null) {
      await this.ctx.storage.deleteAlarm();
    } else {
      await this.ctx.storage.setAlarm(at);
    }
  }
}

/**
 * One world room: up to 32 games in the same world, each on a seat of its own, whose binary
 * messages it passes on to one or all of the others with the sender's seat in front.
 *
 * Like a room, it hibernates and keeps each game's record on its socket. The room's number of
 * seats rides on every record too, so an empty room forgets it and the next game sets it anew.
 */
export class World extends DurableObject {
  /**
   * Creates the world room and has Cloudflare answer keep-alives itself.
   *
   * @param {DurableObjectState} ctx The object's state.
   * @param {object} env The Worker's bindings.
   */
  constructor(ctx, env) {
    super(ctx, env);
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair(PING, PONG));
  }

  /**
   * Seats a game, unless the world is full, and tells the others.
   *
   * @param {Request} request The WebSocket request, already checked by the Worker.
   * @returns {Promise<Response>} The WebSocket, or why the game may not join.
   */
  async fetch(request) {
    const { seats } = parseRoute(new URL(request.url));
    const present = this.peers();
    const records = present.map((peer) => peer.record);
    const capacity = worldCapacity(records, seats);
    const { seat, refusal } = takeSeat(records, capacity);

    if (refusal) {
      return new Response(refusal.reason, { status: 409 });
    }

    const [client, server] = Object.values(new WebSocketPair());
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment(newWorldPeer(seat, capacity, Date.now()));
    server.send(seatText(seat, records.map((record) => record.seat)));

    for (const other of present) {
      other.socket.send(seatChangeText(IN, seat));
    }

    await this.schedule();
    return new Response(null, { status: 101, webSocket: client });
  }

  /**
   * Passes a game's binary message on to the seat it names, or to every other game.
   *
   * @param {WebSocket} socket The game's socket.
   * @param {ArrayBuffer | string} message The message.
   */
  async webSocketMessage(socket, message) {
    if (typeof message === "string") {
      await this.leave(socket, CLOSE.badRequest, "only binary messages are passed on");
      return;
    }

    const { peer, refusal } = takeMessage(socket.deserializeAttachment(), message.byteLength, Date.now());
    socket.serializeAttachment(peer);

    const delivery = refusal ? { refusal } : routeWorldMessage(peer.seat, new Uint8Array(message));

    if (delivery.refusal) {
      await this.leave(socket, delivery.refusal.code, delivery.refusal.reason);
      return;
    }

    for (const other of this.peers()) {
      if (other.socket !== socket && (delivery.target === null || other.record.seat === delivery.target)) {
        other.socket.send(delivery.forwarded);
      }
    }
  }

  /**
   * Frees a leaving game's seat.
   *
   * @param {WebSocket} socket The game's socket.
   */
  async webSocketClose(socket) {
    await this.leave(socket, CLOSE.normal, "closed");
  }

  /**
   * Frees the seat of a game whose connection broke.
   *
   * @param {WebSocket} socket The game's socket.
   */
  async webSocketError(socket) {
    await this.leave(socket, CLOSE.normal, "closed");
  }

  /**
   * Closes the games whose connection lasted too long, and looks again at the next deadline.
   */
  async alarm() {
    const peers = this.peers();

    for (const { index, code, reason } of worldOverdue(peers.map((peer) => peer.record), Date.now())) {
      await this.leave(peers[index].socket, code, reason, false);
    }

    await this.schedule();
  }

  /**
   * Closes a game's socket and tells the others its seat is free, once.
   *
   * @param {WebSocket} socket The game's socket.
   * @param {number} code The close code.
   * @param {string} reason The close reason.
   * @param {boolean} [reschedule] Whether to look at the next deadline afterwards.
   */
  async leave(socket, code, reason, reschedule = true) {
    const record = socket.deserializeAttachment();

    // Closing leads back here through webSocketClose, and the seat must be given up only once.
    if (!record || record.left) {
      return;
    }

    try {
      socket.serializeAttachment({ ...record, left: true });
      socket.close(code, reason);
    } catch {
      // The socket is closed already, which is all this wants.
    }

    for (const other of this.peers()) {
      try {
        other.socket.send(seatChangeText(OUT, record.seat));
      } catch {
        // A game whose socket closed meanwhile learns of it no more.
      }
    }

    if (reschedule) {
      await this.schedule();
    }
  }

  /**
   * Lists the games that hold a seat, with their records.
   *
   * @returns {{socket: WebSocket, record: object}[]} The games.
   */
  peers() {
    return this.ctx.getWebSockets()
      .map((socket) => ({ socket, record: socket.deserializeAttachment() }))
      .filter((peer) => peer.record && !peer.record.left);
  }

  /**
   * Sets the alarm to the room's next deadline, or clears it for an empty room.
   */
  async schedule() {
    const at = nextWorldDeadline(this.peers().map((peer) => peer.record));

    if (at === null) {
      await this.ctx.storage.deleteAlarm();
    } else {
      await this.ctx.storage.setAlarm(at);
    }
  }
}
