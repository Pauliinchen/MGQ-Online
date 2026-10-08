//----------------------------------------------------------------
//  worker.js
//
//  Changelog:
//      Paulinchen  2026-10-08: Ignored a chat frame without a line instead of closing the connection
//      Paulinchen  2026-10-07: Handed the chat lines the games mirror to the directory, and told every game of a world what an admin said
//                            - Passed the X-MGQ-Auth header on to the world rooms and the directory
//                            - Answered a text body over 256 KB with 413 instead of taking it for no JSON, and named the routes by the core's version
//      Paulinchen  2026-10-06: Passed the X-MGQ-Player header on to the trade and mod catalog routes too
//                            - Told the directory who is in a world room after its alarm closed connections too
//                            - Closed a player's earlier connection to a world room once the same player enters it again
//                            - Took a peer the relay closes out of its room at once, and closed a peer that waited alone too long whatever its role
//                            - Passed the player key of the X-MGQ-Player header and each request's address on, limited entering rooms per address, and named why a world room turned a game away
//                            - Read bodies the directory takes as text up to a limit
//                            - Kept the trades between two players of a world in the directory object
//                            - Kept the mod catalog in the directory object, checked its links every half hour
//                            - Stored starting saves and uploaded mods in pieces through the same helpers
//      Paulinchen  2026-09-30: Read the relay's admins from the ADMINS secret
//                            - Kept each world's starting save in the directory's storage, in pieces
//      Paulinchen  2026-09-29: Added the world directory, a Durable Object that world rooms ask before seating a game
//                            - Added world rooms, each a Durable Object that seats up to 32 games
//                            - Created
//
//----------------------------------------------------------------

// The relay on Cloudflare: a Worker that sends each room's requests to a Durable Object of its own,
// which keeps the room's WebSockets, and the world directory's to the one directory object. The
// rules come from the core, so the Node server keeps the same ones.
//
// The directory and the world rooms also talk to each other under /internal, which the Worker
// never passes on from outside.

import { DurableObject } from "cloudflare:workers";
import { Directory as WorldDirectory, handleDirectoryRequest, parseAdmins } from "../core/directory.js";
import { routeIs } from "../core/http.js";
import { ModCatalog, handleModRequest } from "../core/mods.js";
import { TradeBook, handleTradeRequest } from "../core/trades.js";
import {
  AUTH_HEADER, CLOSE, IN, OUT, PAIRED, PING, PLAYER_HEADER, PONG, RATE_LIMITS, REFUSAL_HEADER, RateLimiter, admit, chatLineOf, chatText, newPeer,
  newWorldPeer, nextDeadline, nextWorldDeadline, overdue, parseRoute, presenceOf, replacedBy, routeWorldMessage, seatChangeText, seatText,
  takeMessage, takeSeat, worldOverdue,
} from "../core/relay.js";

/**
 * The name of the one directory object.
 */
const DIRECTORY_NAME = "directory";

/**
 * The header Cloudflare names the address a request came from in.
 */
const ADDRESS_HEADER = "CF-Connecting-IP";

/**
 * Longest body the directory, the mod catalog and the trades read as text, in bytes.
 */
const MAX_TEXT_BYTES = 256 * 1024;

/**
 * Counts how often each address enters a room. Each Worker instance keeps its own count, so it
 * only slows down an address that keeps reaching the same instance; world rooms are counted by
 * the directory instead.
 */
const roomJoins = new RateLimiter(RATE_LIMITS.joins);

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

    if (["worlds", "mods", "trades"].some((route) => routeIs(url, route))) {
      return directoryOf(env).fetch(request);
    }

    const route = parseRoute(url, request.headers.get(PLAYER_HEADER), request.headers.get(AUTH_HEADER));

    if ("error" in route) {
      return new Response(route.error, { status: 400 });
    }

    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("the relay only takes WebSockets", { status: 426 });
    }

    if (route.kind === "room" && !roomJoins.take(request.headers.get(ADDRESS_HEADER))) {
      return new Response("too many requests from this address, try again later", { status: 429 });
    }

    const rooms = route.kind === "world" ? env.WORLDS : env.ROOMS;
    return rooms.get(rooms.idFromName(route.roomId)).fetch(request);
  },

  /**
   * Checks the mod catalog's links for new releases, on the schedule wrangler.toml sets.
   *
   * @param {ScheduledController} _controller The scheduled run.
   * @param {{DIRECTORY: DurableObjectNamespace}} env The Worker's bindings.
   * @param {ExecutionContext} ctx The run's context.
   */
  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(internal(directoryOf(env), "check-mods"));
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
 * Size of the pieces a starting save or an uploaded mod is stored in, well below the largest value
 * storage takes.
 */
const CHUNK_BYTES = 128 * 1024;

/**
 * Names the storage keys of a world's starting save.
 *
 * @param {string} id The world.
 * @returns {string} The keys' common start.
 */
function startPrefix(id) {
  return `start:${id}:`;
}

/**
 * Names the storage key of a world's chat.
 *
 * @param {string} id The world.
 * @returns {string} The key.
 */
function chatKey(id) {
  return `chat:${id}`;
}

/**
 * Names the storage keys of an uploaded mod's zip.
 *
 * @param {string} key The mod.
 * @returns {string} The keys' common start.
 */
function modFilePrefix(key) {
  return `modfile:${key}:`;
}

/**
 * Writes bytes in pieces under a common start, replacing what was there.
 *
 * @param {DurableObjectStorage} storage The object's storage.
 * @param {string} prefix The keys' common start.
 * @param {Uint8Array} bytes The bytes.
 */
async function putPieces(storage, prefix, bytes) {
  await deletePieces(storage, prefix);
  const chunks = {};

  for (let offset = 0; offset < bytes.length; offset += CHUNK_BYTES) {
    // Padded, so the keys list in the order of the pieces.
    chunks[`${prefix}${String(offset / CHUNK_BYTES).padStart(4, "0")}`] = bytes.slice(offset, offset + CHUNK_BYTES);
  }

  // Storage takes at most 128 keys per write.
  const keys = Object.keys(chunks);

  for (let start = 0; start < keys.length; start += 128) {
    await storage.put(Object.fromEntries(keys.slice(start, start + 128).map((key) => [key, chunks[key]])));
  }
}

/**
 * Reads bytes kept in pieces under a common start.
 *
 * @param {DurableObjectStorage} storage The object's storage.
 * @param {string} prefix The keys' common start.
 * @returns {Promise<Uint8Array | undefined>} The bytes, undefined when there are none.
 */
async function getPieces(storage, prefix) {
  const chunks = [...(await storage.list({ prefix })).values()];

  if (chunks.length === 0) {
    return undefined;
  }

  const bytes = new Uint8Array(chunks.reduce((size, chunk) => size + chunk.length, 0));
  let offset = 0;

  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }

  return bytes;
}

/**
 * Deletes the pieces under a common start.
 *
 * @param {DurableObjectStorage} storage The object's storage.
 * @param {string} prefix The keys' common start.
 */
async function deletePieces(storage, prefix) {
  const keys = [...(await storage.list({ prefix })).keys()];

  // Storage deletes at most 128 keys at once.
  for (let start = 0; start < keys.length; start += 128) {
    await storage.delete(keys.slice(start, start + 128));
  }
}

/**
 * Reads a request's body as bytes, unless it is longer than a limit.
 *
 * @param {Request} request The request.
 * @param {number} limit The most bytes it may have.
 * @returns {Promise<Uint8Array | null>} The body, or null when it is too long.
 */
async function readBytes(request, limit) {
  if (Number(request.headers.get("Content-Length") ?? 0) > limit) {
    return null;
  }

  const bytes = new Uint8Array(await request.arrayBuffer());
  return bytes.length > limit ? null : bytes;
}

/**
 * Reads a request's body as text, unless it is longer than MAX_TEXT_BYTES, which the routers then
 * answer with 413.
 *
 * @param {Request} request The request.
 * @returns {Promise<string | null>} The body, or null when it is too long.
 */
async function readText(request) {
  const bytes = await readBytes(request, MAX_TEXT_BYTES);
  return bytes ? new TextDecoder().decode(bytes) : null;
}

/**
 * The world directory: every world with its players, bans and locked token, one entry per world
 * in the object's storage, and each world's starting save in pieces beside it. It also keeps the
 * mod catalog, one entry per mod and each uploaded mod's zip in pieces, and the trades, one entry
 * per trade.
 */
export class Directory extends DurableObject {
  /**
   * Creates the directory, the mod catalog and the trades over the object's storage, with the
   * admins the ADMINS secret names.
   *
   * @param {DurableObjectState} ctx The object's state.
   * @param {{ADMINS?: string}} env The Worker's bindings.
   */
  constructor(ctx, env) {
    super(ctx, env);
    const storage = ctx.storage;
    const admins = parseAdmins(env.ADMINS);

    this.directory = new WorldDirectory({
      get: (id) => storage.get(`world:${id}`),
      put: (entry) => storage.put(`world:${entry.id}`, entry),
      remove: async (id) => {
        await storage.delete([`world:${id}`, chatKey(id)]);
        await deletePieces(storage, startPrefix(id));
      },
      all: async () => [...(await storage.list({ prefix: "world:" })).values()],
      putStart: (id, bytes) => putPieces(storage, startPrefix(id), bytes),
      getStart: (id) => getPieces(storage, startPrefix(id)),
      putChat: (id, lines) => storage.put(chatKey(id), lines),
      getChat: (id) => storage.get(chatKey(id)),
    }, { admins });

    this.mods = new ModCatalog({
      getMod: (key) => storage.get(`mod:${key}`),
      putMod: (entry) => storage.put(`mod:${entry.key}`, entry),
      removeMod: async (key) => {
        await storage.delete(`mod:${key}`);
        await deletePieces(storage, modFilePrefix(key));
      },
      allMods: async () => [...(await storage.list({ prefix: "mod:" })).values()],
      putModFile: (key, bytes) => putPieces(storage, modFilePrefix(key), bytes),
      getModFile: (key) => getPieces(storage, modFilePrefix(key)),
    }, { admins });

    this.trades = new TradeBook({
      getTrade: (id) => storage.get(`trade:${id}`),
      putTrade: (record) => storage.put(`trade:${record.id}`, record),
      removeTrade: (id) => storage.delete(`trade:${id}`),
      allTrades: async () => [...(await storage.list({ prefix: "trade:" })).values()],
    }, (id) => storage.get(`world:${id}`));
  }

  /**
   * Answers the directory's, the mod catalog's and the trades' routes, the world rooms' questions
   * under /internal, and the schedule's check of the catalog's links.
   *
   * @param {Request} request The request.
   * @returns {Promise<Response>} The answer.
   */
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/internal/check-mods") {
      return json(200, { changed: await this.mods.checkAll() });
    }

    if (routeIs(url, "mods")) {
      return respond(await handleModRequest(this.mods, request.method, url, () => readText(request), (limit) => readBytes(request, limit), request.headers.get(PLAYER_HEADER)));
    }

    if (routeIs(url, "trades")) {
      return respond(await handleTradeRequest(this.trades, request.method, url, () => readText(request), request.headers.get(PLAYER_HEADER)));
    }

    if (url.pathname === "/internal/admit") {
      const { id, player, auth, address } = await request.json();
      return json(200, await this.directory.admit(id, player, auth, address ?? null));
    }

    if (url.pathname === "/internal/presence") {
      const { id, online } = await request.json();
      return json(200, await this.directory.presence(id, online));
    }

    if (url.pathname === "/internal/say") {
      const { id, player, name, text } = await request.json();
      return json(200, { line: await this.directory.say(id, { player, name }, text) });
    }

    const client = { player: request.headers.get(PLAYER_HEADER), auth: request.headers.get(AUTH_HEADER), address: request.headers.get(ADDRESS_HEADER) };
    const answer = await handleDirectoryRequest(this.directory, request.method, url, () => readText(request), (limit) => readBytes(request, limit), client);

    if (answer.close) {
      await internal(worldOf(this.env, answer.id), "close");
    }

    if (answer.kick) {
      await internal(worldOf(this.env, answer.id), "kick", { player: answer.kick });
    }

    if (answer.say) {
      await internal(worldOf(this.env, answer.id), "say", answer.say);
    }

    return respond(answer);
  }
}

/**
 * Answers with a directory or catalog answer: its bytes when it has any, else its JSON.
 *
 * @param {{status: number, body: object, bytes?: Uint8Array}} answer The answer.
 * @returns {Response} The response.
 */
function respond(answer) {
  if (answer.bytes) {
    return new Response(answer.bytes, { status: answer.status, headers: { "Content-Type": "application/octet-stream" } });
  }

  return json(answer.status, answer.body);
}

/**
 * Marks a peer left and closes its socket, so the room stops counting it at once, not only once
 * Cloudflare reports the socket closed.
 *
 * @param {WebSocket} socket The peer's socket.
 * @param {number} code The close code.
 * @param {string} reason The close reason.
 */
function closeSocket(socket, code, reason) {
  try {
    const record = socket.deserializeAttachment();

    if (record) {
      socket.serializeAttachment({ ...record, left: true });
    }

    socket.close(code, reason);
  } catch {
    // The socket is closed already, which is all this wants.
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
    // Answered without waking the room, so a peer's keep-alives while it waits alone cost nothing;
    // they never reach the message allowance, which only a woken room can count.
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
   * arrived is dropped, which the mod never does.
   *
   * @param {WebSocket} socket The peer's socket.
   * @param {ArrayBuffer | string} message The message.
   */
  async webSocketMessage(socket, message) {
    if (typeof message === "string") {
      // Keep-alives are answered by Cloudflare before they get here, so any other text is wrong.
      this.leave(socket, CLOSE.badRequest, "only binary messages are passed on");
      return;
    }

    const { peer, refusal } = takeMessage(socket.deserializeAttachment(), message.byteLength, Date.now());
    socket.serializeAttachment(peer);

    if (refusal) {
      this.leave(socket, refusal.code, refusal.reason);
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
      closeSocket(peers[index].socket, code, reason);
    }

    await this.schedule(this.peers());
  }

  /**
   * Closes a leaving peer's socket and every other peer's, which ends the room, once.
   *
   * @param {WebSocket} socket The leaving peer's socket.
   * @param {number} [code] The leaving peer's close code.
   * @param {string} [reason] The leaving peer's close reason.
   */
  leave(socket, code = CLOSE.normal, reason = "closed") {
    // A peer the relay closed already ended the room then, and a newer peer may sit in it since.
    if (socket.deserializeAttachment()?.left) {
      return;
    }

    const others = this.peers().filter((other) => other.socket !== socket);
    closeSocket(socket, code, reason);

    for (const other of others) {
      closeSocket(other.socket, CLOSE.peerLeft, "the other side left");
    }
  }

  /**
   * Lists the peers in the room, with their records, leaving out those the relay closed.
   *
   * @returns {{socket: WebSocket, record: object}[]} The peers.
   */
  peers() {
    return this.ctx.getWebSockets()
      .map((socket) => ({ socket, record: socket.deserializeAttachment() }))
      .filter((peer) => peer.record && !peer.record.left);
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

    if (url.pathname === "/internal/say") {
      const { name, text } = await request.json();
      this.tell(chatText(name, text));
      return json(200, {});
    }

    const route = parseRoute(url, request.headers.get(PLAYER_HEADER), request.headers.get(AUTH_HEADER));
    const address = request.headers.get(ADDRESS_HEADER);
    const answer = await internal(directoryOf(this.env), "admit", { id: route.roomId, player: route.player, auth: route.auth, address });

    if (answer.status !== 200) {
      return new Response(answer.body.error, { status: answer.status, headers: answer.body.code ? { [REFUSAL_HEADER]: answer.body.code } : {} });
    }

    if (!this.world) {
      this.world = route.roomId;
      await this.ctx.storage.put("world", route.roomId);
    }

    const earlier = this.peers();

    for (const { index, code, reason } of replacedBy(earlier.map((peer) => peer.record), answer.player)) {
      await this.leave(earlier[index].socket, code, reason, false);
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
   * Passes a game's binary message on to the seat it names, or to every other game, and hands a
   * chat line the game mirrors as text to the directory.
   *
   * @param {WebSocket} socket The game's socket.
   * @param {ArrayBuffer | string} message The message.
   */
  async webSocketMessage(socket, message) {
    const size = typeof message === "string" ? message.length : message.byteLength;
    const { peer, refusal } = takeMessage(socket.deserializeAttachment(), size, Date.now());
    socket.serializeAttachment(peer);

    if (typeof message === "string") {
      const line = refusal ? null : chatLineOf(message);

      if (line === null) {
        await this.leave(socket, refusal?.code ?? CLOSE.badRequest, refusal?.reason ?? "only binary messages are passed on");
      } else if (line.length > 0) {
        this.world ??= await this.ctx.storage.get("world");
        await internal(directoryOf(this.env), "say", { id: this.world, player: peer.player, name: peer.name, text: line });
      }

      return;
    }

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
   * Closes the games whose connection lasted too long, looks again at the next deadline, and tells
   * the directory who is left.
   */
  async alarm() {
    const peers = this.peers();

    for (const { index, code, reason } of worldOverdue(peers.map((peer) => peer.record), Date.now())) {
      await this.leave(peers[index].socket, code, reason, false);
    }

    await this.schedule();
    await this.report();
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
   * Sends a text frame to every game in the room, such as what an admin said.
   *
   * @param {string} text The frame.
   */
  tell(text) {
    for (const peer of this.peers()) {
      try {
        peer.socket.send(text);
      } catch {
        // A game whose socket closed meanwhile hears it no more.
      }
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
