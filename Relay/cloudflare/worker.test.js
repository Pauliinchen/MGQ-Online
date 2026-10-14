//----------------------------------------------------------------
//  worker.test.js
//
//  Changelog:
//      Paulinchen  2026-10-15: Tested that every battle on the battle server is refused
//      Paulinchen  2026-10-12: Tested the schedules and the release notice to world rooms with players online
//                            - Tested that the world directory, the mod catalog and the Raid World admin routes refuse a request without X-MGQ-Features
//                            - Tested the update code on the 400 of a refused world room and the World Admin tool passing with 0.0.0-dev
//                            - Tested that the Worker turns a game without X-MGQ-Features or below MIN_VERSION away with 426
//                            - Tested a world room refused with 400, a request without X-MGQ-Version taken as 0.6.4 and the directory and mod catalog held to MIN_VERSION
//                            - Tested that the reports object answers a report busy while it handles another
//                            - Tested that a trade's sealed offers lie beside it and go once it is cancelled
//                            - Tested streamed downloads, bodies read up to their limit and removals of many keys
//                            - Tested that a game or peer the relay closed passes nothing on while its connection closes
//                            - Created
//
//----------------------------------------------------------------

// Tests of the relay on Cloudflare: the Worker's routing and the Durable Objects, against
// stand-ins for Cloudflare's platform module, storage and WebSockets.

import { test } from "node:test";
import assert from "node:assert/strict";
import { registerHooks } from "node:module";
import { DOWNLOAD_LIMITS, concatBytes } from "../core/bodies.js";
import { playerIdOf, sha256Hex } from "../core/directory.js";
import { UPDATE_NEEDED, VERSION_HEADER } from "../core/gate.js";
import { AUTH_HEADER, CHAT_LIMITS, CHAT_SLOW, CLOSE, EVERYONE, FEATURES_HEADER, LIMITS, PAIRED, PLAYER_HEADER, REFUSAL_HEADER, REPLACED } from "../core/relay.js";
import { STORY_LIMITS } from "../core/story.js";

// The Worker's platform module exists on Cloudflare only.
registerHooks({
  resolve: (specifier, context, next) => (specifier === "cloudflare:workers"
    ? { url: "data:text/javascript,export class DurableObject { constructor(ctx, env) { this.ctx = ctx; this.env = env; } }", shortCircuit: true }
    : next(specifier, context)),
});

/**
 * One end of a WebSocket as a Durable Object holds it: it records what the object sends and how the
 * object closed it, and keeps the attachment Cloudflare keeps on a hibernating socket.
 */
class FakeSocket {
  /**
   * Creates an open socket that sent nothing yet.
   */
  constructor() {
    this.sent = [];
    this.closed = null;
    this.attachment = undefined;
  }

  /**
   * Keeps a copy of a value on the socket, as Cloudflare stores it.
   *
   * @param {any} value The value.
   */
  serializeAttachment(value) {
    this.attachment = structuredClone(value);
  }

  /**
   * Hands back a copy of the value kept on the socket.
   *
   * @returns {any} The value, or null when none was kept.
   */
  deserializeAttachment() {
    return this.attachment === undefined ? null : structuredClone(this.attachment);
  }

  /**
   * Records a message the object sends to the game.
   *
   * @param {string | ArrayBuffer | Uint8Array} message The message.
   */
  send(message) {
    if (this.closed) {
      throw new TypeError("send() after close()");
    }

    this.sent.push(message);
  }

  /**
   * Records how the object closed the socket, the first time it does.
   *
   * @param {number} code The close code.
   * @param {string} reason The close reason.
   */
  close(code, reason) {
    this.closed ??= { code, reason };
  }
}

/**
 * Cloudflare's pair of WebSocket ends: the client end goes back in the answer, the server end to
 * the object. The client end names its server end, so a test finds the socket the object holds.
 */
globalThis.WebSocketPair = class {
  /**
   * Creates both ends.
   */
  constructor() {
    this[0] = new FakeSocket();
    this[1] = new FakeSocket();
    this[0].server = this[1];
  }
};

/**
 * Cloudflare's keep-alive question and answer, which the objects hand to their state.
 */
globalThis.WebSocketRequestResponsePair = class {
  /**
   * Keeps the question and the answer.
   *
   * @param {string} request The question.
   * @param {string} response The answer.
   */
  constructor(request, response) {
    this.request = request;
    this.response = response;
  }
};

/**
 * Node's own Response, which refuses status 101.
 */
const NodeResponse = globalThis.Response;

/**
 * A Response that also takes Cloudflare's WebSocket answer: status 101 with the client end of a pair.
 */
globalThis.Response = class extends NodeResponse {
  /**
   * Creates the answer.
   *
   * @param {any} body The body.
   * @param {{status?: number, webSocket?: FakeSocket}} [init] The status, headers and WebSocket.
   */
  constructor(body, init) {
    super(body, init?.status === 101 ? { ...init, status: 200 } : init);

    if (init?.status === 101) {
      Object.defineProperty(this, "status", { value: 101 });
      this.webSocket = init.webSocket;
    }
  }
};

const { default: worker, Directory, Reports, Room, World } = await import("./worker.js");

/**
 * The auth key the tests' games make from their world's token.
 */
const AUTH = "ab".repeat(32);

/**
 * The world the tests' games enter.
 */
const WORLD = "d4".repeat(16);

/**
 * The room the tests' peers enter.
 */
const ROOM = "e5".repeat(16);

/**
 * The time the tests with a clock start at.
 */
const START = 1_000_000;

/**
 * Makes a player key no other player of a test has.
 *
 * @param {number} number A number unique to the player.
 * @returns {string} The key.
 */
function playerKey(number) {
  return number.toString(16).padStart(32, "0");
}

/**
 * Names the id the stand-in directory gives a player.
 *
 * @param {string} key The player's key.
 * @returns {string} The id.
 */
function playerIdFor(key) {
  return `id-${key}`;
}

/**
 * Most keys Cloudflare's storage takes in one write or delete.
 */
const STORAGE_BATCH = 128;

/**
 * Makes a stand-in for a Durable Object's storage, which keeps copies of its values in memory and
 * refuses a write or delete of more keys than Cloudflare takes at once.
 *
 * @returns {object} The storage, with get, put, delete, list and the alarm's methods.
 */
function memoryStorage() {
  const values = new Map();
  let alarm = null;

  return {
    get: async (key) => (Array.isArray(key)
      ? new Map(key.filter((each) => values.has(each)).map((each) => [each, structuredClone(values.get(each))]))
      : structuredClone(values.get(key))),
    put: async (key, value) => {
      const entries = typeof key === "string" ? { [key]: value } : key;
      assert.ok(Object.keys(entries).length <= STORAGE_BATCH, "storage writes at most 128 keys at once");

      for (const [each, entry] of Object.entries(entries)) {
        values.set(each, structuredClone(entry));
      }
    },
    delete: async (key) => {
      assert.ok(!Array.isArray(key) || key.length <= STORAGE_BATCH, "storage deletes at most 128 keys at once");

      for (const each of Array.isArray(key) ? key : [key]) {
        values.delete(each);
      }
    },
    list: async ({ prefix = "" } = {}) => new Map([...values.keys()].filter((key) => key.startsWith(prefix)).sort().map((key) => [key, structuredClone(values.get(key))])),
    setAlarm: async (at) => {
      alarm = at;
    },
    getAlarm: async () => alarm,
    deleteAlarm: async () => {
      alarm = null;
    },
  };
}

/**
 * Makes a stand-in for a Durable Object's state: its storage and the WebSockets it accepted. A
 * socket the object closed stays listed until the test finishes its close, as on Cloudflare.
 *
 * @param {object} [storage] The storage.
 * @returns {object} The state.
 */
function objectState(storage = memoryStorage()) {
  const sockets = [];

  return {
    storage,
    sockets,
    acceptWebSocket: (socket) => sockets.push(socket),
    getWebSockets: () => [...sockets],
    setWebSocketAutoResponse: () => {},
  };
}

/**
 * Ends a socket's close handshake: Cloudflare stops listing it and tells the object.
 *
 * @param {Room | World} object The object.
 * @param {FakeSocket} socket The socket.
 */
async function finishClose(object, socket) {
  const sockets = object.ctx.sockets;
  sockets.splice(sockets.indexOf(socket), 1);
  await object.webSocketClose(socket);
}

/**
 * Makes a stand-in for a Durable Object namespace, with one object per name made on first use.
 *
 * @param {(id: string) => {fetch: (request: Request) => Promise<Response>}} make Makes the object of a name.
 * @returns {object} The namespace.
 */
function namespace(make) {
  const objects = new Map();

  return {
    idFromName: (name) => name,
    get: (id) => ({
      fetch: (input, init) => {
        if (!objects.has(id)) {
          objects.set(id, make(id));
        }

        return objects.get(id).fetch(input instanceof Request ? input : new Request(input, init));
      },
    }),
  };
}

/**
 * Makes a stand-in for the directory's namespace that lets every game in, and records what the
 * world rooms ask it.
 *
 * @param {number} [seats] The seats of the world.
 * @returns {object} The namespace, with `calls`: each route the world rooms asked with its body.
 */
function fakeDirectory(seats = 32) {
  const calls = [];

  const answer = async (request) => {
    const route = new URL(request.url).pathname.replace("/internal/", "");
    const body = await request.json();
    calls.push({ route, body });

    if (route === "admit") {
      return Response.json({ status: 200, body: {}, seats, player: playerIdFor(body.player) });
    }

    return Response.json(route === "say" ? { line: { text: body.text } } : {});
  };

  return Object.assign(namespace(() => ({ fetch: answer })), { calls });
}

/**
 * Makes a world room over stand-ins.
 *
 * @param {number} [seats] The seats of the world.
 * @returns {{world: World, directory: object}} The world room and its stand-in directory.
 */
function newWorld(seats = 32) {
  const directory = fakeDirectory(seats);
  return { world: new World(objectState(), { DIRECTORY: directory }), directory };
}

/**
 * Seats a game in a world room.
 *
 * @param {World} world The world room.
 * @param {string} key The player's key.
 * @param {string} name The player's name.
 * @returns {Promise<FakeSocket>} The socket the world room holds for the game.
 */
async function joinWorld(world, key, name) {
  const request = new Request(`https://relay.test/v1/world/${WORLD}?name=${encodeURIComponent(name)}`, { headers: { [PLAYER_HEADER]: key, [AUTH_HEADER]: AUTH } });
  const response = await world.fetch(request);
  assert.equal(response.status, 101, await response.clone().text());
  return response.webSocket.server;
}

/**
 * Lets a peer into a room.
 *
 * @param {Room} room The room.
 * @param {string} role "host" or "guest".
 * @returns {Promise<FakeSocket>} The socket the room holds for the peer.
 */
async function joinRoom(room, role) {
  const response = await room.fetch(new Request(`https://relay.test/v1/room/${ROOM}?role=${role}`));
  assert.equal(response.status, 101, await response.clone().text());
  return response.webSocket.server;
}

/**
 * Sends a world room what the directory sends it under /internal.
 *
 * @param {World} world The world room.
 * @param {string} path The internal route.
 * @param {object} [body] The body.
 * @returns {Promise<Response>} The answer.
 */
function internalTo(world, path, body = {}) {
  return world.fetch(new Request(`https://relay/internal/${path}`, { method: "POST", body: JSON.stringify(body) }));
}

/**
 * Makes a binary message as Cloudflare hands it to an object.
 *
 * @param {number[]} bytes The bytes.
 * @returns {ArrayBuffer} The message.
 */
function binary(bytes) {
  return new Uint8Array(bytes).buffer;
}

/**
 * Takes what the object sent a socket since the last call, binary messages as byte arrays.
 *
 * @param {FakeSocket} socket The socket.
 * @returns {(string | number[])[]} The messages.
 */
function takeSent(socket) {
  return socket.sent.splice(0).map((message) => (typeof message === "string" ? message : [...new Uint8Array(message)]));
}

/**
 * Lists who the world room last told the directory is online.
 *
 * @param {{calls: {route: string, body: object}[]}} directory The stand-in directory.
 * @returns {{player: string, name: string}[]} The players.
 */
function lastPresence(directory) {
  return directory.calls.filter((call) => call.route === "presence").at(-1).body.online;
}

test("a room pairs a host with a guest, passes their binary messages both ways and turns a second host away", async () => {
  const room = new Room(objectState(), {});
  const host = await joinRoom(room, "host");
  const guest = await joinRoom(room, "guest");

  assert.deepEqual([takeSent(host), takeSent(guest)], [[PAIRED], [PAIRED]]);

  await room.webSocketMessage(guest, binary([1, 2, 3]));
  await room.webSocketMessage(host, binary([4, 5]));
  assert.deepEqual([takeSent(host), takeSent(guest)], [[[1, 2, 3]], [[4, 5]]]);

  assert.equal((await room.fetch(new Request(`https://relay.test/v1/room/${ROOM}?role=host`))).status, 409);
});

test("text in a room closes its sender, and the other peer with it", async () => {
  const room = new Room(objectState(), {});
  const host = await joinRoom(room, "host");
  const guest = await joinRoom(room, "guest");

  await room.webSocketMessage(host, "hello");
  assert.equal(host.closed.code, CLOSE.badRequest);
  assert.equal(guest.closed.code, CLOSE.peerLeft);
});

test("a host that waited alone too long is closed", async (t) => {
  t.mock.timers.enable({ apis: ["Date"], now: START });
  const state = objectState();
  const room = new Room(state, {});
  const host = await joinRoom(room, "host");
  assert.equal(await state.storage.getAlarm(), START + LIMITS.aloneWaitMs);

  t.mock.timers.tick(LIMITS.aloneWaitMs);
  await room.alarm();
  assert.equal(host.closed.code, CLOSE.waitedTooLong);
  assert.equal(await state.storage.getAlarm(), null);
});

test("games in a world room get seats, each learns who comes and goes, and the directory knows who is online", async () => {
  const { world, directory } = newWorld();
  const first = await joinWorld(world, playerKey(1), "Player 1");
  const second = await joinWorld(world, playerKey(2), "Player 2");
  const third = await joinWorld(world, playerKey(3), "Player 3");

  assert.deepEqual(takeSent(first), ["seat 0", "in 1", "in 2"]);
  assert.deepEqual(takeSent(second), ["seat 1 0", "in 2"]);
  assert.deepEqual(takeSent(third), ["seat 2 0 1"]);
  assert.deepEqual(directory.calls.find((call) => call.route === "admit").body, { id: WORLD, player: playerKey(1), auth: AUTH, address: null, features: [] });
  assert.deepEqual(lastPresence(directory).map((each) => each.name), ["Player 1", "Player 2", "Player 3"]);

  await finishClose(world, second);
  assert.deepEqual([takeSent(first), takeSent(third)], [["out 1"], ["out 1"]]);
  assert.deepEqual(lastPresence(directory), [{ player: playerIdFor(playerKey(1)), name: "Player 1" }, { player: playerIdFor(playerKey(3)), name: "Player 3" }]);

  const fourth = await joinWorld(world, playerKey(4), "Player 4");
  assert.deepEqual(takeSent(fourth), ["seat 1 0 2"], "the lowest free seat is taken");
});

test("a world message goes to every other game, or to the one seat it names, with the sender's seat in front", async () => {
  const { world } = newWorld();
  const games = [];

  for (let player = 0; player < 3; player++) {
    games.push(await joinWorld(world, playerKey(player), `Player ${player}`));
  }

  games.forEach(takeSent);

  await world.webSocketMessage(games[2], binary([EVERYONE, 5, 6]));
  await world.webSocketMessage(games[0], binary([1, 7]));
  assert.deepEqual(games.map(takeSent), [[[2, 5, 6]], [[2, 5, 6], [0, 7]], []]);

  await world.webSocketMessage(games[1], binary([]));
  assert.equal(games[1].closed.code, CLOSE.badRequest, "an empty world message closes its sender");
});

test("a chat line a game sends as text goes to the directory, an admin's line reaches every game, and other text still closes", async (t) => {
  t.mock.timers.enable({ apis: ["Date"], now: START });
  const { world, directory } = newWorld();
  const first = await joinWorld(world, playerKey(1), "Player 1");
  const second = await joinWorld(world, playerKey(2), "Player 2");
  takeSent(first);
  takeSent(second);
  const said = () => directory.calls.filter((call) => call.route === "say").map((call) => call.body);

  await world.webSocketMessage(first, "chat  hello there ");
  await world.webSocketMessage(first, "chat    ");
  assert.deepEqual(said(), [{ id: WORLD, player: playerIdFor(playerKey(1)), name: "Player 1", text: "hello there" }], "the empty line is ignored");
  assert.deepEqual(takeSent(second), [], "the other games get the line from the game, not from the relay");

  await internalTo(world, "say", { name: "Global", text: "welcome, all" });
  assert.deepEqual([takeSent(first), takeSent(second)], [["chat Global\twelcome, all"], ["chat Global\twelcome, all"]]);

  for (let index = 1; index <= CHAT_LIMITS.burst; index++) {
    await world.webSocketMessage(first, `chat line ${index}`);
  }

  assert.equal(said().length, CHAT_LIMITS.burst);
  assert.deepEqual(takeSent(first), [CHAT_SLOW], "the line past the burst is dropped and answered");

  t.mock.timers.tick(1000);
  await world.webSocketMessage(first, "chat later");
  assert.equal(said().at(-1).text, "later");
  assert.equal(first.closed, null);

  await world.webSocketMessage(second, "something else");
  assert.equal(second.closed.code, CLOSE.badRequest);
});

test("a player who enters a world room again replaces the earlier connection, which gives up its seat", async () => {
  const { world } = newWorld();
  const first = await joinWorld(world, playerKey(1), "Player 1");
  const other = await joinWorld(world, playerKey(2), "Player 2");
  takeSent(other);

  const again = await joinWorld(world, playerKey(1), "Player 1");
  assert.deepEqual(first.closed, { code: CLOSE.removed, reason: REPLACED });
  assert.deepEqual(takeSent(again), ["seat 0 1"]);
  assert.deepEqual(takeSent(other), ["out 0", "in 0"]);
});

test("a player the creator removes is closed, and the directory hears who is left", async () => {
  const { world, directory } = newWorld();
  const removed = await joinWorld(world, playerKey(1), "Player 1");
  const other = await joinWorld(world, playerKey(2), "Player 2");
  takeSent(other);

  assert.equal((await internalTo(world, "kick", { player: playerIdFor(playerKey(1)) })).status, 200);
  assert.equal(removed.closed.code, CLOSE.removed);
  assert.equal(other.closed, null);
  assert.deepEqual(takeSent(other), ["out 0"]);
  assert.deepEqual(lastPresence(directory).map((each) => each.name), ["Player 2"]);
});

test("deleting the world closes every game in its world room", async () => {
  const { world, directory } = newWorld();
  const games = [await joinWorld(world, playerKey(1), "Player 1"), await joinWorld(world, playerKey(2), "Player 2")];

  assert.equal((await internalTo(world, "close")).status, 200);
  assert.deepEqual(games.map((game) => game.closed.code), [CLOSE.worldDeleted, CLOSE.worldDeleted]);
  assert.deepEqual(lastPresence(directory), []);
  assert.equal(await world.ctx.storage.getAlarm(), null);
});

test("a world connection that lasted too long is closed, the others see its seat free, and the alarm moves to the next deadline", async (t) => {
  t.mock.timers.enable({ apis: ["Date"], now: START });
  const { world, directory } = newWorld();
  const first = await joinWorld(world, playerKey(1), "Player 1");
  t.mock.timers.tick(1000);
  const second = await joinWorld(world, playerKey(2), "Player 2");
  takeSent(second);
  assert.equal(await world.ctx.storage.getAlarm(), START + LIMITS.worldConnectionMs);

  t.mock.timers.tick(LIMITS.worldConnectionMs - 1000);
  await world.alarm();
  assert.equal(first.closed.code, CLOSE.connectionExpired);
  assert.deepEqual(takeSent(second), ["out 0"]);
  assert.equal(await world.ctx.storage.getAlarm(), START + 1000 + LIMITS.worldConnectionMs);
  assert.deepEqual(lastPresence(directory).map((each) => each.name), ["Player 2"]);
});

test("a game that leaves moves the alarm to the next deadline and the directory hears it, and the last one clears the alarm", async (t) => {
  t.mock.timers.enable({ apis: ["Date"], now: START });
  const { world, directory } = newWorld();
  const first = await joinWorld(world, playerKey(1), "Player 1");
  t.mock.timers.tick(1000);
  const second = await joinWorld(world, playerKey(2), "Player 2");

  await finishClose(world, first);
  assert.equal(await world.ctx.storage.getAlarm(), START + 1000 + LIMITS.worldConnectionMs);
  assert.deepEqual(lastPresence(directory).map((each) => each.name), ["Player 2"]);

  await finishClose(world, second);
  assert.equal(await world.ctx.storage.getAlarm(), null);
  assert.deepEqual(lastPresence(directory), []);
});

test("a game the relay removed passes nothing on while its connection closes, to the newcomer on its seat or the chat", async () => {
  const { world, directory } = newWorld();
  const removed = await joinWorld(world, playerKey(1), "Player 1");
  const other = await joinWorld(world, playerKey(2), "Player 2");
  await internalTo(world, "kick", { player: playerIdFor(playerKey(1)) });
  assert.ok(world.ctx.getWebSockets().includes(removed), "Cloudflare still lists the socket while it closes");

  const newcomer = await joinWorld(world, playerKey(3), "Player 3");
  assert.deepEqual(takeSent(newcomer), ["seat 0 1"]);
  takeSent(other);
  const record = removed.deserializeAttachment();

  await world.webSocketMessage(removed, binary([EVERYONE, 1, 2]));
  await world.webSocketMessage(removed, binary([1, 3]));
  await world.webSocketMessage(removed, "chat hi");
  assert.deepEqual([takeSent(other), takeSent(newcomer)], [[], []]);
  assert.equal(directory.calls.filter((call) => call.route === "say").length, 0);
  assert.deepEqual(removed.deserializeAttachment(), record);
});

test("a game the relay closed for sending too fast passes nothing on while its connection closes", async (t) => {
  t.mock.timers.enable({ apis: ["Date"], now: START });
  const { world, directory } = newWorld();
  const fast = await joinWorld(world, playerKey(1), "Player 1");
  const other = await joinWorld(world, playerKey(2), "Player 2");

  for (let index = 0; index <= LIMITS.burst; index++) {
    await world.webSocketMessage(fast, binary([EVERYONE, 1]));
  }

  assert.equal(fast.closed.code, CLOSE.tooFast);
  const newcomer = await joinWorld(world, playerKey(3), "Player 3");
  assert.deepEqual(takeSent(newcomer), ["seat 0 1"]);
  takeSent(other);
  const record = fast.deserializeAttachment();

  // Long enough for the allowance to refill, so only the closing itself keeps the frames back.
  t.mock.timers.tick(1000);
  await world.webSocketMessage(fast, binary([EVERYONE, 1, 2]));
  await world.webSocketMessage(fast, "chat hi");
  assert.deepEqual([takeSent(other), takeSent(newcomer)], [[], []]);
  assert.equal(directory.calls.filter((call) => call.route === "say").length, 0);
  assert.deepEqual(fast.deserializeAttachment(), record);
});

test("peers of a room the relay ended pass nothing on to the peers who joined the room since", async () => {
  const room = new Room(objectState(), {});
  const host = await joinRoom(room, "host");
  const guest = await joinRoom(room, "guest");

  await room.webSocketMessage(host, new ArrayBuffer(LIMITS.maxMessageBytes + 1));
  assert.deepEqual([host.closed.code, guest.closed.code], [CLOSE.tooLarge, CLOSE.peerLeft]);

  const newHost = await joinRoom(room, "host");
  const newGuest = await joinRoom(room, "guest");
  takeSent(newHost);
  takeSent(newGuest);

  await room.webSocketMessage(guest, binary([1]));
  await room.webSocketMessage(host, binary([2]));
  assert.deepEqual([takeSent(newHost), takeSent(newGuest)], [[], []]);

  await room.webSocketMessage(newGuest, binary([3]));
  assert.deepEqual(takeSent(newHost), [[3]], "the new peers still reach each other");
});

test("the Worker refuses a story write whose Content-Length is too long before reading it, and reads one without the header to tell", async () => {
  const forwarded = [];
  const env = { WORLDS: namespace(() => ({ fetch: async (request) => (forwarded.push(await request.text()), new Response("{}")) })) };
  const url = `https://relay.test/v1/worlds/${WORLD}/story`;
  let pulled = false;
  const unread = new ReadableStream({ pull: (controller) => ((pulled = true), controller.close()) }, { highWaterMark: 0 });

  const declared = await worker.fetch(new Request(url, { method: "POST", headers: { [FEATURES_HEADER]: "raid", "Content-Length": String(STORY_LIMITS.maxBodyLength + 1) }, body: unread, duplex: "half" }), env);
  assert.deepEqual([declared.status, pulled, forwarded.length], [413, false, 0], "refused unread");

  const chunked = (text) => new Request(url, { method: "POST", headers: { [FEATURES_HEADER]: "raid" }, body: new ReadableStream({ start: (controller) => (controller.enqueue(new TextEncoder().encode(text)), controller.close()) }), duplex: "half" });
  assert.equal((await worker.fetch(chunked("x".repeat(STORY_LIMITS.maxBodyLength + 1)), env)).status, 413, "a body without the header is read to tell");
  assert.equal((await worker.fetch(chunked("{}"), env)).status, 200);
  assert.deepEqual(forwarded, ["{}"], "a body short enough is forwarded whole");
});

test("the Worker refuses every battle on the battle server, which it has none of, and reaches no object for it", async () => {
  const reached = [];
  const env = { DIRECTORY: namespace(() => ({ fetch: async () => (reached.push("directory"), new Response("{}")) })) };
  const world = "ab".repeat(16);
  const start = await worker.fetch(new Request(`https://relay.test/v1/worlds/${world}/battles`, { method: "POST", headers: { [FEATURES_HEADER]: "raid" }, body: "{}" }), env);
  assert.deepEqual([start.status, (await start.json()).code], [503, "no_server"]);
  const channel = await worker.fetch(new Request(`https://relay.test/v1/worlds/${world}/battles/k3x9`, { headers: { [FEATURES_HEADER]: "raid", Upgrade: "websocket" } }), env);
  assert.equal(channel.status, 503);
  assert.deepEqual(reached, []);
});

test("the Worker sends bug reports to an object of their own, never to the world directory", async () => {
  const reached = [];
  const answering = (name) => namespace((id) => ({ fetch: async () => (reached.push(`${name}:${id}`), new Response("{}")) }));
  const env = { DIRECTORY: answering("directory"), REPORTS: answering("reports") };

  await worker.fetch(new Request("https://relay.test/v1/reports", { method: "POST", headers: { [FEATURES_HEADER]: "raid" }, body: "{}" }), env);
  await worker.fetch(new Request("https://relay.test/v1/worlds", { headers: { [FEATURES_HEADER]: "raid" } }), env);
  assert.deepEqual(reached, ["reports:reports", "directory:directory"]);

  const reports = new Reports(objectState(), {});
  const off = await reports.fetch(new Request("https://relay.test/v1/reports", { method: "POST", body: "{}", headers: { [PLAYER_HEADER]: playerKey(1) } }));
  assert.deepEqual([off.status, (await off.json()).code], [503, "off"], "the object reads its settings from the Worker's bindings");
  assert.equal((await reports.fetch(new Request("https://relay.test/v1/reports"))).status, 404);
});

test("the schedule checks the mod catalog's links every half hour and the mod's own releases on the other schedule", async () => {
  const reached = [];
  const env = { DIRECTORY: namespace(() => ({ fetch: async (request) => (reached.push(new URL(request.url).pathname), new Response("{}")) })) };
  const waited = [];
  const ctx = { waitUntil: (promise) => waited.push(promise) };

  await worker.scheduled({ cron: "*/30 * * * *" }, env, ctx);
  await worker.scheduled({ cron: "*/5 * * * *" }, env, ctx);
  await Promise.all(waited);
  assert.deepEqual(reached, ["/internal/check-mods", "/internal/check-release"]);
});

test("the directory tells the world rooms with players online of a newer release, once, and keeps the first release it reads", async (t) => {
  let tag = "v0.6.4";
  const asked = [];
  t.mock.method(globalThis, "fetch", async (url) => (asked.push(url), new Response(null, { status: 302, headers: { Location: `https://github.com/someone/fork/releases/tag/${tag}` } })));
  const told = [];
  const env = { RELEASE_REPO: "someone/fork", WORLDS: namespace((id) => ({ fetch: async (request) => (told.push([id, new URL(request.url).pathname, await request.json()]), new Response("{}")) })) };
  const state = objectState();
  const quiet = "1".repeat(32);
  await state.storage.put({ [`world:${WORLD}`]: { id: WORLD, online: ["p1"], start: "none", created: 0 }, [`world:${quiet}`]: { id: quiet, online: [], start: "none", created: 0 } });
  const directory = new Directory(state, env);
  const check = async () => (await directory.fetch(new Request("https://relay/internal/check-release", { method: "POST", body: "{}" }))).json();

  assert.deepEqual(await check(), { version: null, worlds: 0 });
  tag = "v0.6.5";
  assert.deepEqual(await check(), { version: "0.6.5", worlds: 1 });
  assert.deepEqual(await check(), { version: null, worlds: 0 });
  assert.deepEqual(told, [[WORLD, "/internal/say", { name: "MGQ Online", text: "MGQ Online 0.6.5 is out. Restart the game and pick Multiplayer to update." }]]);
  assert.equal(asked[0], "https://github.com/someone/fork/releases/latest");
});

test("the Worker turns a game without X-MGQ-Features or below MIN_VERSION away before routing it, and lets the World Admin tool and released games through", async () => {
  const reached = [];
  const answering = (name) => namespace((id) => ({ fetch: async () => (reached.push(`${name}:${id}`), new Response("{}")) }));
  const env = { DIRECTORY: answering("directory"), REPORTS: answering("reports"), WORLDS: answering("world"), ROOMS: answering("room"), MIN_VERSION: "0.7.0" };
  const upgrade = { Upgrade: "websocket" };

  const world = await worker.fetch(new Request(`https://relay.test/v1/world/${WORLD}?name=Old&auth=${AUTH}`, { headers: { ...upgrade, [PLAYER_HEADER]: playerKey(1) } }), env);
  assert.deepEqual([world.status, world.headers.get(REFUSAL_HEADER), await world.text()], [400, "update", UPDATE_NEEDED], "released games stop at a 400 with a code they do not know");
  const named = await worker.fetch(new Request(`https://relay.test/v1/world/${WORLD}?name=Old&auth=${AUTH}`, { headers: { ...upgrade, [PLAYER_HEADER]: playerKey(1), [FEATURES_HEADER]: "raid", [VERSION_HEADER]: "0.6.9" } }), env);
  assert.deepEqual([named.status, named.headers.get(REFUSAL_HEADER)], [400, "update"]);

  const room = await worker.fetch(new Request(`https://relay.test/v1/room/${ROOM}?role=host`, { headers: { ...upgrade, [VERSION_HEADER]: "0.6.9" } }), env);
  assert.deepEqual([room.status, room.headers.get(REFUSAL_HEADER)], [426, UPDATE_NEEDED]);

  let pulled = 0;
  const streamed = new ReadableStream({ pull: (controller) => (++pulled > 3 ? controller.close() : controller.enqueue(new Uint8Array(1024))) }, { highWaterMark: 0 });
  const report = await worker.fetch(new Request("https://relay.test/v1/reports", { method: "POST", headers: { [FEATURES_HEADER]: "raid", [VERSION_HEADER]: "0.6.9" }, body: streamed, duplex: "half" }), env);
  assert.deepEqual([report.status, await report.json(), pulled], [426, { error: UPDATE_NEEDED }, 4], "the body is read to its end before the refusal");
  const unnamedRoom = await worker.fetch(new Request(`https://relay.test/v1/room/${ROOM}?role=host`, { headers: upgrade }), env);
  assert.deepEqual([unnamedRoom.status, unnamedRoom.headers.get(REFUSAL_HEADER)], [426, UPDATE_NEEDED], "a game naming no version counts as 0.6.4");
  const listing = await worker.fetch(new Request("https://relay.test/v1/worlds"), env);
  assert.deepEqual([listing.status, await listing.json()], [426, { error: UPDATE_NEEDED }], "a request without headers, as games before 0.6.0 and older World Admin tool builds send");
  const directoryVersion = await worker.fetch(new Request("https://relay.test/v1/worlds", { headers: { [VERSION_HEADER]: "0.7.0" } }), env);
  assert.deepEqual([directoryVersion.status, await directoryVersion.json()], [426, { error: UPDATE_NEEDED }], "the world directory needs X-MGQ-Features on top of a version new enough");
  const raid = await worker.fetch(new Request(`https://relay.test/v1/worlds/${WORLD}/raid?player=${playerKey(1)}`, { headers: { [FEATURES_HEADER]: "admin", [VERSION_HEADER]: "0.6.9" } }), env);
  assert.equal(raid.status, 426, "the Raid World admin routes hold a named version against the lowest");
  pulled = 0;
  const uploaded = new ReadableStream({ pull: (controller) => (++pulled > 3 ? controller.close() : controller.enqueue(new Uint8Array(1024))) }, { highWaterMark: 0 });
  const upload = await worker.fetch(new Request("https://relay.test/v1/mods", { method: "POST", body: uploaded, duplex: "half" }), env);
  assert.deepEqual([upload.status, pulled], [426, 4], "a refused upload is read to its end first");
  assert.deepEqual(reached, [], "nothing too old reaches an object");

  await worker.fetch(new Request(`https://relay.test/v1/room/${ROOM}?role=host`, { headers: { ...upgrade, [VERSION_HEADER]: "0.7.0-beta" } }), env);
  await worker.fetch(new Request(`https://relay.test/v1/world/${WORLD}?name=New&auth=${AUTH}`, { headers: { ...upgrade, [PLAYER_HEADER]: playerKey(1), [FEATURES_HEADER]: "raid", [VERSION_HEADER]: "0.0.0-dev" } }), env);
  await worker.fetch(new Request("https://relay.test/v1/worlds", { headers: { [FEATURES_HEADER]: "raid", [VERSION_HEADER]: "0.7.0" } }), env);
  await worker.fetch(new Request("https://relay.test/v1/mods", { headers: { [FEATURES_HEADER]: "raid", [VERSION_HEADER]: "0.0.0-dev+abc" } }), env);
  await worker.fetch(new Request("https://relay.test/v1/worlds", { headers: { [FEATURES_HEADER]: "admin", [VERSION_HEADER]: "0.0.0-dev" } }), env);
  assert.deepEqual(reached, [`room:${ROOM}`, `world:${WORLD}`, "directory:directory", "directory:directory", "directory:directory"], "the World Admin tool names 0.0.0-dev");

  reached.length = 0;
  const released = { ...env, MIN_VERSION: "0.6.4" };
  await worker.fetch(new Request(`https://relay.test/v1/room/${ROOM}?role=host`, { headers: upgrade }), released);
  await worker.fetch(new Request(`https://relay.test/v1/world/${WORLD}?name=New&auth=${AUTH}`, { headers: { ...upgrade, [PLAYER_HEADER]: playerKey(1), [FEATURES_HEADER]: "raid" } }), released);
  await worker.fetch(new Request("https://relay.test/v1/worlds"), released);
  await worker.fetch(new Request("https://relay.test/v1/mods"), released);
  assert.deepEqual(reached, [`room:${ROOM}`, `world:${WORLD}`], "a request without X-MGQ-Features stays refused on the world directory and the mod catalog");
  await worker.fetch(new Request("https://relay.test/v1/worlds", { headers: { [FEATURES_HEADER]: "raid" } }), released);
  await worker.fetch(new Request("https://relay.test/v1/mods", { headers: { [FEATURES_HEADER]: "raid" } }), released);
  await worker.fetch(new Request(`https://relay.test/v1/worlds/${WORLD}/raid?player=${playerKey(1)}`, { headers: { [FEATURES_HEADER]: "admin", [VERSION_HEADER]: "0.0.0-dev" } }), released);
  assert.deepEqual(reached, [`room:${ROOM}`, `world:${WORLD}`, "directory:directory", "directory:directory", `world:${WORLD}`], "released games and requests naming no version pass while the lowest is at most 0.6.4");
});

test("the reports object answers a report busy while it handles another, after reading its streamed body to the end", async () => {
  const reports = new Reports(objectState(), { GITHUB_ISSUES_TOKEN: "issues", GITHUB_BUG_FILES_TOKEN: "files" });
  const held = new Promise(() => {});
  reports.desk.fetch = () => held;
  const header = { title: "Busy", text: "Sent twice.", version: "0.6.4", facts: [], files: [{ name: "report.md", length: 4 }] };
  const report = (number, body) => new Request("https://relay.test/v1/reports", { method: "POST", body, duplex: "half", headers: { [PLAYER_HEADER]: playerKey(number) } });

  reports.fetch(report(1, `${JSON.stringify(header)}\nAAAA`));

  while (reports.desk.pending === 0) {
    await new Promise((resolve) => setImmediate(resolve));
  }

  let pulled = 0;
  let cancelled = false;
  const streamed = new ReadableStream({
    pull(controller) {
      if (++pulled > 5) {
        controller.close();
      } else {
        controller.enqueue(new Uint8Array(64 * 1024));
      }
    },
    cancel: () => void (cancelled = true),
  }, { highWaterMark: 0 });

  const busy = await reports.fetch(report(2, streamed));
  assert.deepEqual([busy.status, await busy.json()], [503, { error: "the relay is handling other bug reports, try again in a minute", code: "busy" }]);
  assert.deepEqual([pulled, cancelled], [6, false], "the body was read to its end, never cancelled");
});

/**
 * The address of a test's download, one per game.
 *
 * @param {number} number A number unique to the game.
 * @returns {string} The address, from a range kept for documentation.
 */
function addressOf(number) {
  return `203.0.113.${number}`;
}

/**
 * Lets every promise that can settle now settle.
 */
function settle() {
  return new Promise((resolve) => setImmediate(resolve));
}

/**
 * Reads a response's body as it streams.
 *
 * @param {Response} response The response.
 * @returns {Promise<Uint8Array>} Its bytes.
 */
async function bytesOf(response) {
  const chunks = [];

  for await (const chunk of response.body) {
    chunks.push(chunk);
  }

  return concatBytes(chunks);
}

/**
 * Makes a directory object over stand-ins with an uploaded mod of one piece, ready to download.
 *
 * @returns {Promise<{directory: Directory, download: (number: number) => Promise<Response>}>} The directory, and how a game downloads the mod from an address of its own.
 */
async function directoryWithMod() {
  const state = objectState();
  await state.storage.put({ "mod:luka": { key: "luka", name: "Luka", kind: "upload" }, "modfile:luka:0000": new Uint8Array([1, 2, 3]) });
  const directory = new Directory(state, {});
  const download = (number) => directory.fetch(new Request("https://relay.test/v1/mods/luka/file", { headers: { "CF-Connecting-IP": addressOf(number) } }));
  return { directory, download };
}

test("the directory sends a starting save of several pieces as it was uploaded, and frees the download slot once sent", async () => {
  const state = objectState();
  const directory = new Directory(state, {});
  const headers = { [PLAYER_HEADER]: playerKey(1), "CF-Connecting-IP": addressOf(1) };
  const world = { id: WORLD, name: "Iliasburg Crew", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(60) }, start: true };
  const created = await directory.fetch(new Request("https://relay.test/v1/worlds", { method: "POST", headers, body: JSON.stringify(world) }));
  assert.equal(created.status, 201, await created.clone().text());

  const save = Uint8Array.from({ length: 300 * 1024 }, (_, index) => index % 251);
  const uploaded = await directory.fetch(new Request(`https://relay.test/v1/worlds/${WORLD}/start`, { method: "POST", headers, body: save }));
  assert.equal(uploaded.status, 200, await uploaded.clone().text());
  assert.deepEqual([...(await state.storage.list({ prefix: `start:${WORLD}:` })).keys()], [`start:${WORLD}:0000`, `start:${WORLD}:0001`, `start:${WORLD}:0002`]);

  const fetched = await directory.fetch(new Request(`https://relay.test/v1/worlds/${WORLD}/start`, { headers: { ...headers, [AUTH_HEADER]: AUTH } }));
  assert.equal(fetched.status, 200);
  assert.equal(fetched.headers.get("Content-Type"), "application/octet-stream");
  assert.equal(directory.downloads.active.size, 1, "the slot is held while the bytes are sent");
  assert.deepEqual(await bytesOf(fetched), save);
  assert.equal(directory.downloads.active.size, 0);

  const missing = await directory.fetch(new Request(`https://relay.test/v1/worlds/${"0f".repeat(16)}/start`, { headers: { ...headers, [AUTH_HEADER]: AUTH } }));
  assert.equal(missing.status, 404);
  assert.equal(directory.downloads.active.size, 0, "a refused download gives its slot back at once");
});

test("a fourth download at once waits for a free slot, and is refused with Retry-After when none comes in time", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout", "Date"], now: START });
  const { download } = await directoryWithMod();
  const running = [];

  for (let number = 1; number <= DOWNLOAD_LIMITS.maxActive; number++) {
    running.push(await download(number));
  }

  assert.ok(running.every((response) => response.status === 200));
  let fourth = null;
  download(4).then((response) => (fourth = response));
  await settle();
  assert.equal(fourth, null, "the fourth waits");

  assert.deepEqual([...(await bytesOf(running[0]))], [1, 2, 3]);
  await settle();
  assert.equal(fourth?.status, 200, "an ended download hands its slot on");

  let fifth = null;
  download(5).then((response) => (fifth = response));
  await settle();
  t.mock.timers.tick(DOWNLOAD_LIMITS.maxWaitMs);
  await settle();
  assert.equal(fifth?.status, 503);
  assert.equal(fifth.headers.get("Retry-After"), String(DOWNLOAD_LIMITS.retryAfterSeconds));
  assert.deepEqual(await fifth.json(), { error: "the relay is sending other downloads, try again in a moment", code: "busy" });
});

test("the directory reads a body sent without Content-Length only up to its limit and answers 413", async () => {
  const directory = new Directory(objectState(), {});
  const chunk = 64 * 1024;
  let pulled = 0;

  const body = new ReadableStream({
    pull: (controller) => {
      pulled++;
      controller.enqueue(new Uint8Array(chunk).fill(32));
    },
  }, { highWaterMark: 0 });

  const response = await directory.fetch(new Request("https://relay.test/v1/worlds", { method: "POST", headers: { [PLAYER_HEADER]: playerKey(1) }, body, duplex: "half" }));
  assert.equal(response.status, 413);
  assert.ok(pulled <= (256 * 1024) / chunk + 2, `read ${pulled} chunks`);
});

test("removing a Raid World's story and boss pools deletes more keys than storage deletes at once", async () => {
  const state = objectState();
  const world = new World(state, {});
  const many = [];

  for (let index = 0; index < 200; index++) {
    many.push([`checkpoint:${index}`, { part: index }], [`boss:${index}`, { key: String(index) }]);
  }

  for (let start = 0; start < many.length; start += STORAGE_BATCH) {
    await state.storage.put(Object.fromEntries(many.slice(start, start + STORAGE_BATCH)));
  }

  await state.storage.put("story", { part: 1 });
  await world.removeRaidData();
  assert.deepEqual([...(await state.storage.list()).keys()], []);
});

test("the directory keeps a trade's sealed offers beside it, out of the list of trades, and drops them once it is cancelled", async () => {
  const state = objectState();
  const directory = new Directory(state, {});
  const [alice, bob] = [playerKey(1), playerKey(2)];
  const [aliceId, bobId] = [await playerIdOf(alice), await playerIdOf(bob)];
  const trade = "7".repeat(32);
  await state.storage.put(`world:${WORLD}`, { id: WORLD, members: { [aliceId]: {}, [bobId]: {} }, bans: [] });

  const committed = await directory.fetch(new Request(`https://relay.test/v1/trades/${trade}/commit`, {
    method: "POST",
    headers: { [PLAYER_HEADER]: alice },
    body: JSON.stringify({ world: WORLD, partner: bobId, hash: "ab".repeat(32), sealed: "QQ==" }),
  }));
  assert.deepEqual(await committed.json(), { state: "pending" });
  assert.equal(await state.storage.get(`trade-sealed:${trade}:${aliceId}`), "QQ==");
  assert.deepEqual(await directory.trades.store.allTrades(), [await state.storage.get(`trade:${trade}`)]);
  assert.ok(!("sealed" in (await state.storage.get(`trade:${trade}`)).commits[aliceId]));

  const cancelled = await directory.fetch(new Request(`https://relay.test/v1/trades/${trade}/cancel`, { method: "POST", headers: { [PLAYER_HEADER]: bob }, body: "{}" }));
  assert.deepEqual(await cancelled.json(), { state: "cancelled", reason: "cancelled" });
  assert.deepEqual([...(await state.storage.list({ prefix: "trade-sealed:" })).keys()], []);
});
