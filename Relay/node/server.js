//----------------------------------------------------------------
//  server.js
//
//  Changelog:
//      Paulinchen  2026-10-06: Passed the X-MGQ-Player header on to the trade and mod catalog routes too
//                            - Answered a body over the limit with its refusal instead of cutting the connection, and read text bodies of up to 256 KB
//                            - Took the player key of the X-MGQ-Player header, limited entering rooms per address, and named why a world room turned a game away
//                            - Closed a player's earlier connection to a world room once the same player enters it again
//                            - Took a peer the relay closes out of its room at once, and counted keep-alives against the message allowance
//                            - Kept the trades between two players of a world in memory
//                            - Kept the mod catalog in memory, checked its links every half hour
//      Paulinchen  2026-09-30: Read the relay's admins from the ADMINS environment variable
//                            - Kept each world's starting save in memory, taken and handed out as bytes
//      Paulinchen  2026-09-29: Kept the world directory, and seated a game in a world room only once the directory let it in
//                            - Added world rooms, which seat up to 32 games
//                            - Created
//
//----------------------------------------------------------------

// The relay as a plain Node server, for a rented machine behind a TLS proxy such as Caddy. It keeps
// its rooms and its world directory in memory and follows the core's rules, so it behaves like the
// Cloudflare relay.

import http from "node:http";
import { pathToFileURL } from "node:url";
import { WebSocketServer } from "ws";
import { Directory, handleDirectoryRequest, parseAdmins } from "../core/directory.js";
import { ModCatalog, handleModRequest } from "../core/mods.js";
import { TradeBook, handleTradeRequest } from "../core/trades.js";
import {
  CLOSE, IN, LIMITS, OUT, PAIRED, PING, PLAYER_HEADER, PONG, REFUSAL_HEADER, admit, newPeer, newWorldPeer, overdue, parseRoute, presenceOf,
  replacedBy, routeWorldMessage, seatChangeText, seatText, takeMessage, takeSeat, worldOverdue,
} from "../core/relay.js";

/**
 * How often the server looks for rooms whose time is up.
 */
const CHECK_EVERY_MS = 60 * 1000;

/**
 * How often the server checks the mod catalog's links for new releases, half an hour.
 */
const CHECK_MODS_EVERY_MS = 30 * 60 * 1000;

/**
 * Longest request body the directory and the mod catalog read as text, in bytes: the longest JSON
 * either takes, written in characters of up to four bytes each.
 */
const MAX_BODY_BYTES = 256 * 1024;

/**
 * How much of a body over its limit is still read and dropped, so the refusal reaches a client
 * that sends its whole body before it reads the answer; past it the connection is cut.
 */
const MAX_DRAINED_BYTES = 64 * 1024 * 1024;

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
 * Keeps the mod catalog and uploaded mods' zips in memory, as the catalog's store.
 *
 * @returns {import("../core/mods.js").ModStore} The store.
 */
export function memoryModStore() {
  const mods = new Map();
  const files = new Map();

  return {
    getMod: async (key) => (mods.has(key) ? structuredClone(mods.get(key)) : undefined),
    putMod: async (entry) => void mods.set(entry.key, structuredClone(entry)),
    removeMod: async (key) => {
      mods.delete(key);
      files.delete(key);
    },
    allMods: async () => [...mods.values()].map((entry) => structuredClone(entry)),
    putModFile: async (key, bytes) => void files.set(key, Uint8Array.from(bytes)),
    getModFile: async (key) => files.get(key),
  };
}

/**
 * Keeps the trades in memory, as the trades' store.
 *
 * @returns {import("../core/trades.js").TradeStore} The store.
 */
export function memoryTradeStore() {
  const trades = new Map();

  return {
    getTrade: async (id) => (trades.has(id) ? structuredClone(trades.get(id)) : undefined),
    putTrade: async (record) => void trades.set(record.id, structuredClone(record)),
    removeTrade: async (id) => void trades.delete(id),
    allTrades: async () => [...trades.values()].map((record) => structuredClone(record)),
  };
}

/**
 * Reads a request's body as bytes. A body over the limit is read on and dropped, up to
 * MAX_DRAINED_BYTES, so its refusal can still be answered.
 *
 * @param {http.IncomingMessage} request The request.
 * @param {number} limit The most bytes it may have.
 * @returns {Promise<Buffer | null>} The body, or null when it is longer than the limit.
 */
export function readBytes(request, limit) {
  return new Promise((resolve, reject) => {
    const parts = [];
    let size = 0;
    let tooLong = Number(request.headers["content-length"] ?? 0) > limit;

    request.on("data", (part) => {
      size += part.length;
      tooLong ||= size > limit;

      if (!tooLong) {
        parts.push(part);
      } else if (size > limit + MAX_DRAINED_BYTES) {
        resolve(null);
        request.destroy();
      }
    });
    request.on("end", () => resolve(tooLong ? null : Buffer.concat(parts)));
    request.on("error", reject);
  });
}

/**
 * Reads a request's body as text, stopping at MAX_BODY_BYTES.
 *
 * @param {http.IncomingMessage} request The request.
 * @returns {Promise<string | null>} The body, or null when it is too large.
 */
async function readText(request) {
  return (await readBytes(request, MAX_BODY_BYTES))?.toString("utf8") ?? null;
}

/**
 * Tells the address a request came from: the socket's, or behind a TLS proxy on this machine the
 * one the proxy appended to X-Forwarded-For last, since earlier entries come from the client.
 *
 * @param {http.IncomingMessage} request The request.
 * @returns {string | null} The address, null when unknown.
 */
export function addressOf(request) {
  const remote = request.socket.remoteAddress ?? null;
  const forwarded = request.headers["x-forwarded-for"];
  const local = remote === "127.0.0.1" || remote === "::1" || remote === "::ffff:127.0.0.1";

  if (local && typeof forwarded === "string" && forwarded.trim().length > 0) {
    return forwarded.split(",").at(-1).trim();
  }

  return remote;
}

/**
 * Reads the player key header of a request.
 *
 * @param {http.IncomingMessage} request The request.
 * @returns {string | null} The key as sent, null without one.
 */
function playerHeaderOf(request) {
  const value = request.headers[PLAYER_HEADER.toLowerCase()];
  return typeof value === "string" && value.length > 0 ? value : null;
}

/**
 * Creates a relay server, not yet listening.
 *
 * @param {{limits?: typeof LIMITS, clock?: () => number, checkEveryMs?: number, directory?: Directory, mods?: ModCatalog, trades?: TradeBook}} [options] Limits, clock, check interval, directory, mod catalog and trades, which tests change.
 * @returns {{server: http.Server, check: () => void, stop: () => Promise<void>}} The HTTP server to listen with, a look at the deadlines, and a way to stop everything.
 */
export function createRelay({
  limits = LIMITS, clock = Date.now, checkEveryMs = CHECK_EVERY_MS, directory = new Directory(memoryStore(), { clock }), mods = new ModCatalog(memoryModStore(), { clock }),
  trades = new TradeBook(memoryTradeStore(), (id) => directory.store.get(id), { clock }),
} = {}) {
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
    const route = parseRoute(new URL(request.url, "http://relay"), playerHeaderOf(request));
    const address = addressOf(request);

    if ("error" in route) {
      refuse(socket, 400, route.error);
      return;
    }

    if (route.kind === "room") {
      if (!directory.rates.joins.take(address)) {
        refuse(socket, 429, "too many requests from this address, try again later");
        return;
      }

      const refusal = admit((rooms.get(route.roomId) ?? []).map((peer) => peer.record.role), route.role);

      if (refusal) {
        refuse(socket, 409, refusal.reason);
        return;
      }

      sockets.handleUpgrade(request, socket, head, (webSocket) => join(route, webSocket));
      return;
    }

    directory.admit(route.roomId, route.player, route.auth, address).then((answer) => {
      if (answer.status !== 200) {
        refuse(socket, answer.status, answer.body.error, answer.body.code);
        return;
      }

      // The player's earlier connection gives up its seat to this one.
      const staying = (worlds.get(route.roomId) ?? []).filter((peer) => peer.record.player !== answer.player);
      const full = takeSeat(staying.map((peer) => peer.record), answer.seats).refusal;

      if (full) {
        refuse(socket, 409, full.reason);
        return;
      }

      sockets.handleUpgrade(request, socket, head, (webSocket) => sit(route, answer, webSocket));
    }, () => refuse(socket, 500, "the directory failed"));
  });

  /**
   * Answers a request to the directory, the mod catalog or the trades, and carries out what it asks
   * beyond answering.
   *
   * @param {http.IncomingMessage} request The request.
   * @param {http.ServerResponse} response The response.
   * @returns {Promise<void>} Completes once answered.
   */
  async function answerDirectory(request, response) {
    const url = new URL(request.url, "http://relay");
    const catalog = url.pathname === "/v1/mods" || url.pathname.startsWith("/v1/mods/");
    const trading = url.pathname === "/v1/trades" || url.pathname.startsWith("/v1/trades/");

    if (!url.pathname.startsWith("/v1/worlds") && !catalog && !trading) {
      response.writeHead(426, { "Content-Type": "text/plain" });
      response.end("the relay takes WebSockets, the world directory, the mod catalog and trades only");
      return;
    }

    const readTextOrEmpty = async () => (await readText(request)) ?? "";
    const client = { player: playerHeaderOf(request), address: addressOf(request) };
    const answer = trading
      ? await handleTradeRequest(trades, request.method, url, () => readText(request), client.player)
      : catalog
        ? await handleModRequest(mods, request.method, url, readTextOrEmpty, (limit) => readBytes(request, limit), client.player)
        : await handleDirectoryRequest(directory, request.method, url, readTextOrEmpty, (limit) => readBytes(request, limit), client);

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
        unseat(roomId, peer, code, reason);
      }
    }
  }

  /**
   * Takes a game out of its world room at once, tells the others its seat is free, closes its
   * connection and tells the directory who is left; once, however often it is asked.
   *
   * @param {string} roomId The world.
   * @param {{socket: import("ws").WebSocket, record: object}} peer The game.
   * @param {number} code The close code.
   * @param {string} reason The close reason.
   */
  function unseat(roomId, peer, code, reason) {
    const peers = worlds.get(roomId) ?? [];
    const index = peers.indexOf(peer);

    if (index < 0) {
      return;
    }

    peers.splice(index, 1);

    for (const other of peers) {
      other.socket.send(seatChangeText(OUT, peer.record.seat));
    }

    if (peers.length === 0) {
      worlds.delete(roomId);
    }

    peer.socket.close(code, reason);
    report(roomId, peers);
  }

  /**
   * Seats a game in its world room and passes its messages on.
   *
   * @param {{roomId: string, name: string}} route The world room and the player's name.
   * @param {{seats: number, player: string}} admission The world's seats and the player's id, from the directory.
   * @param {import("ws").WebSocket} socket The game's WebSocket.
   */
  function sit(route, admission, socket) {
    const earlier = worlds.get(route.roomId) ?? [];

    for (const { index, code, reason } of replacedBy(earlier.map((other) => other.record), admission.player).reverse()) {
      unseat(route.roomId, earlier[index], code, reason);
    }

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
      // A game the relay unseated passes nothing on while its connection closes.
      if (!(worlds.get(route.roomId) ?? []).includes(peer)) {
        return;
      }

      const { peer: record, refusal: tooMuch } = takeMessage(peer.record, data.length, clock(), limits);
      peer.record = record;

      if (tooMuch) {
        unseat(route.roomId, peer, tooMuch.code, tooMuch.reason);
        return;
      }

      if (!isBinary) {
        if (data.toString() === PING) {
          socket.send(PONG);
        } else {
          unseat(route.roomId, peer, CLOSE.badRequest, "only binary messages are passed on");
        }
        return;
      }

      const delivery = routeWorldMessage(record.seat, data);

      if (delivery.refusal) {
        unseat(route.roomId, peer, delivery.refusal.code, delivery.refusal.reason);
        return;
      }

      for (const other of worlds.get(route.roomId) ?? []) {
        if (other !== peer && (delivery.target === null || other.record.seat === delivery.target)) {
          other.socket.send(delivery.forwarded, { binary: true });
        }
      }
    });

    socket.on("close", () => unseat(route.roomId, peer, CLOSE.normal, "closed"));
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
   * @param {string} [code] The code that names why, sent in REFUSAL_HEADER.
   */
  function refuse(socket, status, reason, code) {
    const named = code ? `${REFUSAL_HEADER}: ${code}\r\n` : "";
    socket.end(`HTTP/1.1 ${status} Refused\r\nContent-Type: text/plain\r\n${named}Connection: close\r\n\r\n${reason}`);
  }

  /**
   * Takes a peer out of its room at once and closes it, and the other peer with it, which ends the
   * room; once, however often it is asked.
   *
   * @param {string} roomId The room.
   * @param {{socket: import("ws").WebSocket, record: object}} peer The leaving peer.
   * @param {number} code The leaving peer's close code.
   * @param {string} reason The leaving peer's close reason.
   */
  function endRoom(roomId, peer, code, reason) {
    const peers = rooms.get(roomId) ?? [];

    if (!peers.includes(peer)) {
      return;
    }

    rooms.delete(roomId);
    peer.socket.close(code, reason);

    for (const other of peers) {
      if (other !== peer) {
        other.socket.close(CLOSE.peerLeft, "the other side left");
      }
    }
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
      // A room the relay ended passes nothing on while its connections close.
      if (rooms.get(route.roomId) !== peers) {
        return;
      }

      const { peer: record, refusal } = takeMessage(peer.record, data.length, clock(), limits);
      peer.record = record;

      if (refusal) {
        endRoom(route.roomId, peer, refusal.code, refusal.reason);
        return;
      }

      if (!isBinary) {
        if (data.toString() === PING) {
          socket.send(PONG);
        } else {
          endRoom(route.roomId, peer, CLOSE.badRequest, "only binary messages are passed on");
        }
        return;
      }

      peers.find((other) => other !== peer)?.socket.send(data, { binary: true });
    });

    socket.on("close", () => endRoom(route.roomId, peer, CLOSE.normal, "closed"));
    socket.on("error", () => socket.terminate());
  }

  /**
   * Closes the peers whose time is up, in every room and world room.
   */
  function check() {
    for (const [roomId, peers] of [...rooms]) {
      const closed = overdue(peers.map((peer) => peer.record), clock(), limits);

      // The overdue peers are always the whole room: everyone once it lasted too long, or its lone peer.
      if (closed.length > 0) {
        rooms.delete(roomId);
      }

      for (const { index, code, reason } of closed) {
        peers[index].socket.close(code, reason);
      }
    }

    for (const [roomId, peers] of [...worlds]) {
      const closed = worldOverdue(peers.map((peer) => peer.record), clock(), limits).map(({ index, code, reason }) => ({ peer: peers[index], code, reason }));

      for (const { peer, code, reason } of closed) {
        unseat(roomId, peer, code, reason);
      }
    }
  }

  const timer = setInterval(check, checkEveryMs);
  timer.unref();
  const modTimer = setInterval(() => mods.checkAll().catch(() => {}), CHECK_MODS_EVERY_MS);
  modTimer.unref();

  /**
   * Closes every connection and the server.
   *
   * @returns {Promise<void>} Resolves once the server stopped.
   */
  function stop() {
    clearInterval(timer);
    clearInterval(modTimer);

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

  const admins = parseAdmins(process.env.ADMINS);
  const directory = new Directory(memoryStore(), { admins });
  const mods = new ModCatalog(memoryModStore(), { admins });
  const trades = new TradeBook(memoryTradeStore(), (id) => directory.store.get(id));

  createRelay({ directory, mods, trades }).server.listen(port, host, () => console.log(`relay listening on ${host}:${port}`));
}
