//----------------------------------------------------------------
//  server.js
//
//  Changelog:
//      Paulinchen  2026-10-07: Kept the chat lines the games mirror as text frames, and told every game of a world what an admin said
//                            - Logged every request as one line and every caught error with its stack, never a key
//                            - Kept the worlds, mods and trades in a SQLite database when MGQ_RELAY_DB names one
//                            - Swept stale worlds and finished trades on a timer, not only when a request read them
//                            - Took the auth key of the X-MGQ-Auth header for world rooms and starting saves
//                            - Answered a text body over 256 KB with 413, a path that is no route with 400 and a room path without an upgrade with 426, as the Cloudflare relay does
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
// its rooms in memory and its world directory, mod catalog and trades in memory or in a SQLite
// database, and follows the core's rules, so it behaves like the Cloudflare relay. It writes one
// line per request to stdout and every error it catches to stderr.

import http from "node:http";
import { pathToFileURL } from "node:url";
import { WebSocketServer } from "ws";
import { Directory, handleDirectoryRequest, parseAdmins } from "../core/directory.js";
import { routeIs } from "../core/http.js";
import { ModCatalog, handleModRequest } from "../core/mods.js";
import { TradeBook, handleTradeRequest } from "../core/trades.js";
import {
  AUTH_HEADER, CLOSE, IN, LIMITS, OUT, PAIRED, PING, PLAYER_HEADER, PONG, REFUSAL_HEADER, admit, chatLineOf, chatText, newPeer, newWorldPeer, overdue,
  parseRoute, presenceOf, replacedBy, routeWorldMessage, seatChangeText, seatText, takeMessage, takeSeat, worldOverdue,
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
 * How often the server sweeps out worlds whose starting save never came and trades kept long enough.
 */
const SWEEP_EVERY_MS = 10 * 60 * 1000;

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
 * The environment variable that names the SQLite database the relay keeps its worlds, mods and
 * trades in; without it everything stays in memory.
 */
export const DATABASE_VARIABLE = "MGQ_RELAY_DB";

/**
 * The log the server writes to unless given another: request lines to stdout, errors to stderr.
 */
export const consoleLog = Object.freeze({
  info: (line) => console.log(line),
  error: (line) => console.error(line),
});

/**
 * Writes the log line of one request. The path comes without its query, since released games put
 * their player key and auth key there.
 *
 * @param {Date} time When the request was answered.
 * @param {string} method The HTTP method.
 * @param {string} path The request's path, without its query.
 * @param {number} status The HTTP status answered.
 * @param {number} durationMs How long the request took.
 * @param {string | null} address The address it came from, null when unknown.
 * @returns {string} The line, such as "2026-10-07T12:00:00.000Z GET /v1/worlds 200 3ms 203.0.113.5".
 */
export function requestLine(time, method, path, status, durationMs, address) {
  return `${time.toISOString()} ${method} ${path} ${status} ${Math.round(durationMs)}ms ${address ?? "-"}`;
}

/**
 * Writes the log line of a caught error, with its stack.
 *
 * @param {Date} time When the error was caught.
 * @param {string} where What the server was doing.
 * @param {unknown} error The error.
 * @returns {string} The line.
 */
export function errorLine(time, where, error) {
  return `${time.toISOString()} error ${where}: ${error?.stack ?? error}`;
}

/**
 * Keeps world entries and starting saves in memory, as the directory's store.
 *
 * @returns {import("../core/directory.js").DirectoryStore} The store.
 */
export function memoryStore() {
  const entries = new Map();
  const starts = new Map();
  const chats = new Map();

  return {
    get: async (id) => (entries.has(id) ? structuredClone(entries.get(id)) : undefined),
    put: async (entry) => void entries.set(entry.id, structuredClone(entry)),
    remove: async (id) => {
      entries.delete(id);
      starts.delete(id);
      chats.delete(id);
    },
    all: async () => [...entries.values()].map((entry) => structuredClone(entry)),
    putStart: async (id, bytes) => void starts.set(id, Uint8Array.from(bytes)),
    getStart: async (id) => starts.get(id),
    putChat: async (id, lines) => void chats.set(id, structuredClone(lines)),
    getChat: async (id) => (chats.has(id) ? structuredClone(chats.get(id)) : undefined),
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
 * Opens the stores the relay keeps its worlds, mods and trades in: a SQLite database at a path,
 * or memory without one.
 *
 * @param {string | undefined} path The database's path, as DATABASE_VARIABLE names it; empty or undefined for memory.
 * @returns {Promise<{directory: import("../core/directory.js").DirectoryStore, mods: import("../core/mods.js").ModStore, trades: import("../core/trades.js").TradeStore, close: () => void}>} The stores, and a way to close them.
 */
export async function openStores(path) {
  if (path) {
    const { openSqliteStores } = await import("./sqlite_store.js");
    return openSqliteStores(path);
  }

  return { directory: memoryStore(), mods: memoryModStore(), trades: memoryTradeStore(), close: () => {} };
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
 * Reads a request's body as text, stopping at MAX_BODY_BYTES, which the routers then answer with 413.
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
 * Reads one of the relay's own headers of a request, such as PLAYER_HEADER.
 *
 * @param {http.IncomingMessage} request The request.
 * @param {string} name The header's name.
 * @returns {string | null} The value as sent, null without one.
 */
function headerOf(request, name) {
  const value = request.headers[name.toLowerCase()];
  return typeof value === "string" && value.length > 0 ? value : null;
}

/**
 * Creates a relay server, not yet listening.
 *
 * @param {{limits?: typeof LIMITS, clock?: () => number, checkEveryMs?: number, sweepEveryMs?: number, directory?: Directory, mods?: ModCatalog, trades?: TradeBook, log?: typeof consoleLog}} [options] Limits, clock, check and sweep intervals, directory, mod catalog, trades and log, which tests change.
 * @returns {{server: http.Server, directory: Directory, mods: ModCatalog, trades: TradeBook, check: () => void, sweep: () => Promise<void>, stop: () => Promise<void>}} The HTTP server to listen with, what it serves, a look at the deadlines, a sweep of what is kept too long, and a way to stop everything.
 */
export function createRelay({
  limits = LIMITS, clock = Date.now, checkEveryMs = CHECK_EVERY_MS, sweepEveryMs = SWEEP_EVERY_MS, directory = new Directory(memoryStore(), { clock }),
  mods = new ModCatalog(memoryModStore(), { clock }), trades = new TradeBook(memoryTradeStore(), (id) => directory.store.get(id), { clock }), log = consoleLog,
} = {}) {
  /** @type {Map<string, {socket: import("ws").WebSocket, record: object}[]>} */
  const rooms = new Map();
  /** @type {Map<string, {socket: import("ws").WebSocket, record: object}[]>} */
  const worlds = new Map();
  // Larger messages than the core allows reach it and get its close code; far larger ones never
  // reach memory at all.
  const sockets = new WebSocketServer({ noServer: true, maxPayload: limits.maxMessageBytes * 2 });
  const server = http.createServer((request, response) => {
    const started = performance.now();
    const path = pathOf(request);
    response.on("finish", () => log.info(requestLine(new Date(), request.method, path, response.statusCode, performance.now() - started, addressOf(request))));

    answerDirectory(request, response).catch((error) => {
      log.error(errorLine(new Date(), `${request.method} ${path}`, error));

      if (response.headersSent) {
        response.end();
        return;
      }

      response.writeHead(500, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ error: "the directory failed" }));
    });
  });

  server.on("upgrade", (request, socket, head) => {
    const started = performance.now();
    const path = pathOf(request);
    const address = addressOf(request);
    const logged = (status) => log.info(requestLine(new Date(), request.method, path, status, performance.now() - started, address));
    const turnAway = (status, reason, code) => {
      refuse(socket, status, reason, code);
      logged(status);
    };
    const accept = (seat) => sockets.handleUpgrade(request, socket, head, (webSocket) => {
      logged(101);
      seat(webSocket);
    });
    const route = parseRoute(new URL(request.url, "http://relay"), headerOf(request, PLAYER_HEADER), headerOf(request, AUTH_HEADER));

    if ("error" in route) {
      turnAway(400, route.error);
      return;
    }

    if (route.kind === "room") {
      if (!directory.rates.joins.take(address)) {
        turnAway(429, "too many requests from this address, try again later");
        return;
      }

      const refusal = admit((rooms.get(route.roomId) ?? []).map((peer) => peer.record.role), route.role);

      if (refusal) {
        turnAway(409, refusal.reason);
        return;
      }

      accept((webSocket) => join(route, webSocket));
      return;
    }

    directory.admit(route.roomId, route.player, route.auth, address).then((answer) => {
      if (answer.status !== 200) {
        turnAway(answer.status, answer.body.error, answer.body.code);
        return;
      }

      // The player's earlier connection gives up its seat to this one.
      const staying = (worlds.get(route.roomId) ?? []).filter((peer) => peer.record.player !== answer.player);
      const full = takeSeat(staying.map((peer) => peer.record), answer.seats).refusal;

      if (full) {
        turnAway(409, full.reason);
        return;
      }

      accept((webSocket) => sit(route, answer, webSocket));
    }, (error) => {
      log.error(errorLine(new Date(), `admit ${path}`, error));
      turnAway(500, "the directory failed");
    });
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
    const catalog = routeIs(url, "mods");
    const trading = routeIs(url, "trades");

    if (!routeIs(url, "worlds") && !catalog && !trading) {
      // The same answers as the Cloudflare relay gives: a room's address needs its WebSocket.
      const route = parseRoute(url);
      const [status, reason] = "error" in route ? [400, route.error] : [426, "the relay only takes WebSockets"];
      response.writeHead(status, { "Content-Type": "text/plain" });
      response.end(reason);
      return;
    }

    const client = { player: headerOf(request, PLAYER_HEADER), auth: headerOf(request, AUTH_HEADER), address: addressOf(request) };
    const answer = trading
      ? await handleTradeRequest(trades, request.method, url, () => readText(request), client.player)
      : catalog
        ? await handleModRequest(mods, request.method, url, () => readText(request), (limit) => readBytes(request, limit), client.player)
        : await handleDirectoryRequest(directory, request.method, url, () => readText(request), (limit) => readBytes(request, limit), client);

    if (answer.close) {
      closeWorld(answer.id, CLOSE.worldDeleted, "the world was deleted");
    }

    if (answer.kick) {
      closeWorld(answer.id, CLOSE.removed, "the creator removed this player from the world", answer.kick);
    }

    if (answer.say) {
      tellWorld(answer.id, chatText(answer.say.name, answer.say.text));
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
   * Sends a text frame to every game in a world room, such as what an admin said.
   *
   * @param {string} roomId The world.
   * @param {string} text The frame.
   */
  function tellWorld(roomId, text) {
    for (const peer of worlds.get(roomId) ?? []) {
      peer.socket.send(text);
    }
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
        const text = data.toString();
        const line = chatLineOf(text);

        if (text === PING) {
          socket.send(PONG);
        } else if (line !== null) {
          directory.say(route.roomId, { player: admission.player, name: route.name }, line).catch((error) => log.error(errorLine(new Date(), `chat of world ${route.roomId}`, error)));
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
    directory.presence(roomId, presenceOf(peers.map((peer) => peer.record))).catch((error) => log.error(errorLine(new Date(), `presence of world ${roomId}`, error)));
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

  /**
   * Sweeps out the worlds whose starting save did not come in time and the trades kept long
   * enough, which the directory and the trades otherwise only do when a request reads them.
   *
   * @returns {Promise<void>} Completes once swept.
   */
  async function sweep() {
    try {
      await directory.entries();
      await trades.exclusive(() => trades.tidy());
    } catch (error) {
      log.error(errorLine(new Date(), "sweep", error));
    }
  }

  const timer = setInterval(check, checkEveryMs);
  timer.unref();
  const sweepTimer = setInterval(sweep, sweepEveryMs);
  sweepTimer.unref();
  const modTimer = setInterval(() => mods.checkAll().catch((error) => log.error(errorLine(new Date(), "check of the mod catalog", error))), CHECK_MODS_EVERY_MS);
  modTimer.unref();

  /**
   * Closes every connection and the server.
   *
   * @returns {Promise<void>} Resolves once the server stopped.
   */
  function stop() {
    clearInterval(timer);
    clearInterval(sweepTimer);
    clearInterval(modTimer);

    for (const socket of sockets.clients) {
      socket.terminate();
    }

    return new Promise((resolve) => server.close(() => resolve()));
  }

  return { server, directory, mods, trades, check, sweep, stop };
}

/**
 * Reads a request's path without its query, for the log.
 *
 * @param {http.IncomingMessage} request The request.
 * @returns {string} The path.
 */
function pathOf(request) {
  try {
    return new URL(request.url, "http://relay").pathname;
  } catch {
    return "-";
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  // Behind a TLS proxy the relay only needs to listen locally.
  const port = Number(process.env.PORT ?? 8080);
  const host = process.env.HOST ?? "127.0.0.1";
  const database = process.env[DATABASE_VARIABLE];

  const admins = parseAdmins(process.env.ADMINS);
  const stores = await openStores(database);
  const directory = new Directory(stores.directory, { admins });
  const mods = new ModCatalog(stores.mods, { admins });
  const trades = new TradeBook(stores.trades, (id) => directory.store.get(id));
  const relay = createRelay({ directory, mods, trades });

  relay.server.listen(port, host, () => console.log(`${new Date().toISOString()} relay listening on ${host}:${port}, ${database ? `database ${database}` : "everything in memory"}`));

  for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, async () => {
      await relay.stop();
      stores.close();
      process.exit(0);
    });
  }
}
