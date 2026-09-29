//----------------------------------------------------------------
//  worker.js
//
//  Changelog:
//      Paulinchen  2026-09-29: Added the world directory, a Durable Object that world rooms ask before seating a game
//                            - Added world rooms, each a Durable Object that seats up to 32 games
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

// The relay on Cloudflare: a Worker that sends each room's requests to a Durable Object of its own,
// which keeps the room's WebSockets, and the world directory's to the one directory object. The
// rules come from the core, so the Node server keeps the same ones.
//
// The directory and the world rooms also talk to each other under /internal, which the Worker
// never passes on from outside.

import { DurableObject } from "cloudflare:workers";
import { Directory as WorldDirectory, handleDirectoryRequest } from "../core/directory.js";
import {
  CLOSE, IN, OUT, PAIRED, PING, PONG, admit, newPeer, newWorldPeer, nextDeadline, nextWorldDeadline, overdue, parseRoute, presenceOf,
  routeWorldMessage, seatChangeText, seatText, takeMessage, takeSeat, worldOverdue,
} from "../core/relay.js";

/**
 * The name of the one directory object.
 */
const DIRECTORY_NAME = "directory";

/**
 * Sends a WebSocket request to its room or world room, a directory request to the directory, and
 * refuses anything else.
 */
export default {
  /**
   * Handles a request to the relay.
   *
   * @param {Request} request The request.
   * @param {{ROOMS: DurableObjectNamespace, WORLDS: DurableObjectNamespace, DIRECTORY: DurableObjectNamespace}} env The Worker's bindings.
   * @returns {Promise<Response>} The answer, or why the request is refused.
   */
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/v1/worlds" || url.pathname.startsWith("/v1/worlds/")) {
      return directoryOf(env).fetch(request);
    }

    const route = parseRoute(url);

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
 * Finds the directory object.
 *
 * @param {{DIRECTORY: DurableObjectNamespace}} env The bindings.
 * @returns {DurableObjectStub} The directory.
 */
function directoryOf(env) {
  return env.DIRECTORY.get(env.DIRECTORY.idFromName(DIRECTORY_NAME));
}

/**
 * Finds a world room's object.
 *
 * @param {{WORLDS: DurableObjectNamespace}} env The bindings.
 * @param {string} id The world.
 * @returns {DurableObjectStub} The world room.
 */
function worldOf(env, id) {
  return env.WORLDS.get(env.WORLDS.idFromName(id));
}

/**
 * Sends an internal request to another object and reads its JSON answer.
 *
 * @param {DurableObjectStub} stub The object.
 * @param {string} path The internal route.
 * @param {object} [body] The request's body.
 * @returns {Promise<any>} The answer.
 */
async function internal(stub, path, body = {}) {
  const response = await stub.fetch(`https://relay/internal/${path}`, { method: "POST", body: JSON.stringify(body) });
  return response.json();
}

/**
 * Answers with JSON.
 *
 * @param {number} status The HTTP status.
 * @param {object} body The body.
 * @returns {Response} The answer.
 */
function json(status, body) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

/**
 * The world directory: every world with its players, bans and locked token, one entry per world
 * in the object's storage.
 */
export class Directory extends DurableObject {
  /**
   * Creates the directory over the object's storage.
   *
   * @param {DurableObjectState} ctx The object's state.
   * @param {object} env The Worker's bindings.
   */
  constructor(ctx, env) {
    super(ctx, env);
    this.directory = new WorldDirectory({
      get: (id) => ctx.storage.get(`world:${id}`),
      put: (entry) => ctx.storage.put(`world:${entry.id}`, entry),
      remove: (id) => ctx.storage.delete(`world:${id}`),
      all: async () => [...(await ctx.storage.list({ prefix: "world:" })).values()],
    });
  }

  /**
   * Answers the directory's routes, and the world rooms' questions under /internal.
   *
   * @param {Request} request The request.
   * @returns {Promise<Response>} The answer.
   */
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/internal/admit") {
      const { id, player, auth } = await request.json();
      return json(200, await this.directory.admit(id, player, auth));
    }

    if (url.pathname === "/internal/presence") {
      const { id, online } = await request.json();
      return json(200, await this.directory.presence(id, online));
    }

    const answer = await handleDirectoryRequest(this.directory, request.method, url, () => request.text());

    if (answer.close) {
      await internal(worldOf(this.env, answer.id), "close");
    }

    if (answer.kick) {
      await internal(worldOf(this.env, answer.id), "kick", { player: answer.kick });
    }

    return json(answer.status, answer.body);
  }
}

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
 * Like a room, it hibernates and keeps each game's record on its socket. It asks the directory
 * before seating a game, and tells it who is in the room after every change.
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
   * Seats a game the directory lets in, unless the world is full, and tells the others; or closes
   * connections when the directory asks.
   *
   * @param {Request} request The WebSocket request, already checked by the Worker, or the directory's internal request.
   * @returns {Promise<Response>} The WebSocket, or why the game may not join.
   */
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/internal/close") {
      await this.closeWhere(() => true, CLOSE.worldDeleted, "the world was deleted");
      return json(200, {});
    }

    if (url.pathname === "/internal/kick") {
      const { player } = await request.json();
      await this.closeWhere((record) => record.player === player, CLOSE.removed, "the creator removed this player from the world");
      return json(200, {});
    }

    const route = parseRoute(url);
    const answer = await internal(directoryOf(this.env), "admit", { id: route.roomId, player: route.player, auth: route.auth });

    if (answer.status !== 200) {
      return new Response(answer.body.error, { status: answer.status });
    }

    if (!this.world) {
      this.world = route.roomId;
      await this.ctx.storage.put("world", route.roomId);
    }

    // Seats are counted after the directory answered, since other games may have come meanwhile.
    const present = this.peers();
    const records = present.map((peer) => peer.record);
    const { seat, refusal } = takeSeat(records, answer.seats);

    if (refusal) {
      return new Response(refusal.reason, { status: 409 });
    }

    const [client, server] = Object.values(new WebSocketPair());
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment(newWorldPeer(seat, { player: answer.player, name: route.name }, Date.now()));
    server.send(seatText(seat, records.map((record) => record.seat)));

    for (const other of present) {
      other.socket.send(seatChangeText(IN, seat));
    }

    await this.schedule();
    await this.report();
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
      await this.report();
    }
  }

  /**
   * Closes the games whose records meet a condition, then tells the directory who is left.
   *
   * @param {(record: object) => boolean} condition Which games to close.
   * @param {number} code The close code.
   * @param {string} reason The close reason.
   */
  async closeWhere(condition, code, reason) {
    for (const peer of this.peers().filter((each) => condition(each.record))) {
      await this.leave(peer.socket, code, reason, false);
    }

    await this.schedule();
    await this.report();
  }

  /**
   * Tells the directory who is in the room now.
   *
   * The room's world id is the name it was made under, which only a game's request carries, so the
   * first one stores it.
   */
  async report() {
    this.world ??= await this.ctx.storage.get("world");

    if (this.world) {
      await internal(directoryOf(this.env), "presence", { id: this.world, online: presenceOf(this.peers().map((peer) => peer.record)) });
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
