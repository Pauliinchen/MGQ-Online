//----------------------------------------------------------------
//  server.js
//
//  Changelog:
//      Paulinchen  2026-09-30: Kept each world's starting save in memory, taken and handed out as bytes
//      Paulinchen  2026-09-29: Kept the world directory, and seated a game in a world room only once the directory let it in
//                            - Added world rooms, which seat up to 32 games
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

// The relay as a plain Node server, for a rented machine behind a TLS proxy such as Caddy. It keeps
// its rooms and its world directory in memory and follows the core's rules, so it behaves like the
// Cloudflare relay.

import http from "node:http";
import { pathToFileURL } from "node:url";
import { WebSocketServer } from "ws";
import { Directory, handleDirectoryRequest } from "../core/directory.js";
import {
  CLOSE, IN, LIMITS, OUT, PAIRED, PING, PONG, admit, newPeer, newWorldPeer, overdue, parseRoute, presenceOf, routeWorldMessage, seatChangeText,
  seatText, takeMessage, takeSeat, worldOverdue,
} from "../core/relay.js";

/**
 * How often the server looks for rooms whose time is up.
 */
const CHECK_EVERY_MS = 60 * 1000;

/**
 * Longest request body the directory reads.
 */
const MAX_BODY_BYTES = 16 * 1024;

/**
 * Keeps world entries and starting saves in memory, as the directory's store.
 *
 * @returns {import("../core/directory.js").DirectoryStore} The store.
 */
export function memoryStore() {
  const entries = new Map();
  const starts = new Map();

  return {
    get: async (id) => (entries.has(id) ? structuredClone(entries.get(id)) : undefined),
    put: async (entry) => void entries.set(entry.id, structuredClone(entry)),
    remove: async (id) => {
      entries.delete(id);
      starts.delete(id);
    },
    all: async () => [...entries.values()].map((entry) => structuredClone(entry)),
    putStart: async (id, bytes) => void starts.set(id, Uint8Array.from(bytes)),
    getStart: async (id) => starts.get(id),
  };
}

/**
 * Reads a request's body as bytes, stopping past a limit.
 *
 * @param {http.IncomingMessage} request The request.
 * @param {number} limit The most bytes it may have.
 * @returns {Promise<Buffer | null>} The body, or null when it is longer than the limit.
 */
function readBytes(request, limit) {
  return new Promise((resolve, reject) => {
    const parts = [];
    let size = 0;

    request.on("data", (part) => {
      size += part.length;

      if (size > limit) {
        request.destroy();
        resolve(null);
        return;
      }

      parts.push(part);
    });
    request.on("end", () => resolve(Buffer.concat(parts)));
    request.on("error", reject);
  });
}

/**
 * Reads a request's body as text, stopping at MAX_BODY_BYTES.
 *
 * @param {http.IncomingMessage} request The request.
 * @returns {Promise<string>} The body, or "" when it is too large.
 */
async function readBody(request) {
  return (await readBytes(request, MAX_BODY_BYTES))?.toString("utf8") ?? "";
}

/**
 * Creates a relay server, not yet listening.
 *
 * @param {{limits?: typeof LIMITS, clock?: () => number, checkEveryMs?: number, directory?: Directory}} [options] Limits, clock, check interval and directory, which tests change.
 * @returns {{server: http.Server, check: () => void, stop: () => Promise<void>}} The HTTP server to listen with, a look at the deadlines, and a way to stop everything.
 */
export function createRelay({ limits = LIMITS, clock = Date.now, checkEveryMs = CHECK_EVERY_MS, directory = new Directory(memoryStore(), { clock }) } = {}) {
  /** @type {Map<string, {socket: import("ws").WebSocket, record: object}[]>} */
  const rooms = new Map();
  /** @type {Map<string, {socket: import("ws").WebSocket, record: object}[]>} */
  const worlds = new Map();
  // Larger messages than the core allows reach it and get its close code; far larger ones never
  // reach memory at all.
  const sockets = new WebSocketServer({ noServer: true, maxPayload: limits.maxMessageBytes * 2 });
  const server = http.createServer((request, response) => {
    answerDirectory(request, response).catch(() => {
      response.writeHead(500, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ error: "the directory failed" }));
    });
  });

  server.on("upgrade", (request, socket, head) => {
    const route = parseRoute(new URL(request.url, "http://relay"));

    if ("error" in route) {
      refuse(socket, 400, route.error);
      return;
    }

    if (route.kind === "room") {
      const refusal = admit((rooms.get(route.roomId) ?? []).map((peer) => peer.record.role), route.role);

      if (refusal) {
        refuse(socket, 409, refusal.reason);
        return;
      }

      sockets.handleUpgrade(request, socket, head, (webSocket) => join(route, webSocket));
      return;
    }

    directory.admit(route.roomId, route.player, route.auth).then((answer) => {
      if (answer.status !== 200) {
        refuse(socket, answer.status, answer.body.error);
        return;
      }

      const full = takeSeat((worlds.get(route.roomId) ?? []).map((peer) => peer.record), answer.seats).refusal;

      if (full) {
        refuse(socket, 409, full.reason);
        return;
      }

      sockets.handleUpgrade(request, socket, head, (webSocket) => sit(route, answer, webSocket));
    }, () => refuse(socket, 500, "the directory failed"));
  });

  /**
   * Answers a request to the directory, and carries out what it asks beyond answering.
   *
   * @param {http.IncomingMessage} request The request.
   * @param {http.ServerResponse} response The response.
   * @returns {Promise<void>} Completes once answered.
   */
  async function answerDirectory(request, response) {
    const url = new URL(request.url, "http://relay");

    if (!url.pathname.startsWith("/v1/worlds")) {
      response.writeHead(426, { "Content-Type": "text/plain" });
      response.end("the relay takes WebSockets and the world directory only");
      return;
    }

    const answer = await handleDirectoryRequest(directory, request.method, url, () => readBody(request), (limit) => readBytes(request, limit));

    if (answer.close) {
      closeWorld(answer.id, CLOSE.worldDeleted, "the world was deleted");
    }

    if (answer.kick) {
      closeWorld(answer.id, CLOSE.removed, "the creator removed this player from the world", answer.kick);
    }

    if (answer.bytes) {
      response.writeHead(answer.status, { "Content-Type": "application/octet-stream" });
      response.end(answer.bytes);
      return;
    }

    response.writeHead(answer.status, { "Content-Type": "application/json" });
    response.end(JSON.stringify(answer.body));
  }

  /**
   * Closes the connections of a world room: all, or one player's.
   *
   * @param {string} roomId The world.
   * @param {number} code The close code.
   * @param {string} reason The close reason.
   * @param {string} [player] The player whose connections close, all when left out.
   */
  function closeWorld(roomId, code, reason, player) {
    for (const peer of [...(worlds.get(roomId) ?? [])]) {
      if (!player || peer.record.player === player) {
        peer.socket.close(code, reason);
      }
    }
  }

  /**
   * Seats a game in its world room and passes its messages on.
   *
   * @param {{roomId: string, name: string}} route The world room and the player's name.
   * @param {{seats: number, player: string}} admission The world's seats and the player's id, from the directory.
   * @param {import("ws").WebSocket} socket The game's WebSocket.
   */
  function sit(route, admission, socket) {
    const peers = worlds.get(route.roomId) ?? [];
    // Another game may have taken the last seat while this one's handshake ran.
    const { seat, refusal } = takeSeat(peers.map((other) => other.record), admission.seats);

    if (refusal) {
      socket.close(refusal.code, refusal.reason);
      return;
    }

    const peer = { socket, record: newWorldPeer(seat, { player: admission.player, name: route.name }, clock(), limits) };
    worlds.set(route.roomId, peers);
    socket.send(seatText(seat, peers.map((other) => other.record.seat)));

    for (const other of peers) {
      other.socket.send(seatChangeText(IN, seat));
    }

    peers.push(peer);
    report(route.roomId, peers);

    socket.on("message", (data, isBinary) => {
      if (!isBinary) {
        if (data.toString() === PING) {
          socket.send(PONG);
        } else {
          socket.close(CLOSE.badRequest, "only binary messages are passed on");
        }
        return;
      }

      const { peer: record, refusal: tooMuch } = takeMessage(peer.record, data.length, clock(), limits);
      peer.record = record;
      const delivery = tooMuch ? { refusal: tooMuch } : routeWorldMessage(record.seat, data);

      if (delivery.refusal) {
        socket.close(delivery.refusal.code, delivery.refusal.reason);
        return;
      }

      for (const other of peers) {
        if (other !== peer && (delivery.target === null || other.record.seat === delivery.target)) {
          other.socket.send(delivery.forwarded, { binary: true });
        }
      }
    });

    socket.on("close", () => {
      peers.splice(peers.indexOf(peer), 1);

      for (const other of peers) {
        other.socket.send(seatChangeText(OUT, seat));
      }

      if (peers.length === 0) {
        worlds.delete(route.roomId);
      }

      report(route.roomId, peers);
    });

    socket.on("error", () => socket.terminate());
  }

  /**
   * Tells the directory who is in a world room now.
   *
   * @param {string} roomId The world.
   * @param {{record: object}[]} peers The games in the room.
   */
  function report(roomId, peers) {
    directory.presence(roomId, presenceOf(peers.map((peer) => peer.record))).catch(() => {});
  }

  /**
   * Turns a WebSocket request down before it opens.
   *
   * @param {import("node:net").Socket} socket The request's connection.
   * @param {number} status The HTTP status.
   * @param {string} reason Why.
   */
  function refuse(socket, status, reason) {
    socket.end(`HTTP/1.1 ${status} Refused\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n${reason}`);
  }

  /**
   * Puts a peer into its room and passes its messages on.
   *
   * @param {{roomId: string, role: string}} route The room and role.
   * @param {import("ws").WebSocket} socket The peer's WebSocket.
   */
  function join(route, socket) {
    // Another peer of the same role may have joined while this one's handshake ran.
    const taken = admit((rooms.get(route.roomId) ?? []).map((peer) => peer.record.role), route.role);

    if (taken) {
      socket.close(taken.code, taken.reason);
      return;
    }

    const peers = rooms.get(route.roomId) ?? [];
    const peer = { socket, record: newPeer(route.role, clock(), limits) };
    rooms.set(route.roomId, peers);
    peers.push(peer);

    if (peers.length === 2) {
      for (const each of peers) {
        each.socket.send(PAIRED);
      }
    }

    socket.on("message", (data, isBinary) => {
      if (!isBinary) {
        if (data.toString() === PING) {
          socket.send(PONG);
        } else {
          socket.close(CLOSE.badRequest, "only binary messages are passed on");
        }
        return;
      }

      const { peer: record, refusal } = takeMessage(peer.record, data.length, clock(), limits);
      peer.record = record;

      if (refusal) {
        socket.close(refusal.code, refusal.reason);
        return;
      }

      peers.find((other) => other !== peer)?.socket.send(data, { binary: true });
    });

    socket.on("close", () => {
      peers.splice(peers.indexOf(peer), 1);

      for (const other of peers) {
        other.socket.close(CLOSE.peerLeft, "the other side left");
      }

      if (peers.length === 0) {
        rooms.delete(route.roomId);
      }
    });

    socket.on("error", () => socket.terminate());
  }

  /**
   * Closes the peers whose time is up, in every room and world room.
   */
  function check() {
    for (const peers of rooms.values()) {
      for (const { index, code, reason } of overdue(peers.map((peer) => peer.record), clock(), limits)) {
        peers[index].socket.close(code, reason);
      }
    }

    for (const peers of worlds.values()) {
      for (const { index, code, reason } of worldOverdue(peers.map((peer) => peer.record), clock(), limits)) {
        peers[index].socket.close(code, reason);
      }
    }
  }

  const timer = setInterval(check, checkEveryMs);
  timer.unref();

  /**
   * Closes every connection and the server.
   *
   * @returns {Promise<void>} Resolves once the server stopped.
   */
  function stop() {
    clearInterval(timer);

    for (const socket of sockets.clients) {
      socket.terminate();
    }

    return new Promise((resolve) => server.close(() => resolve()));
  }

  return { server, check, stop };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  // Behind a TLS proxy the relay only needs to listen locally.
  const port = Number(process.env.PORT ?? 8080);
  const host = process.env.HOST ?? "127.0.0.1";

  createRelay().server.listen(port, host, () => console.log(`relay listening on ${host}:${port}`));
}
