//----------------------------------------------------------------
//  worker.test.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

// Tests of the relay on Cloudflare: the Worker's routing and the Durable Objects, against
// stand-ins for Cloudflare's platform module, storage and WebSockets.

import { test } from "node:test";
import assert from "node:assert/strict";
import { registerHooks } from "node:module";
import { AUTH_HEADER, CHAT_LIMITS, CHAT_SLOW, CLOSE, EVERYONE, LIMITS, PAIRED, PLAYER_HEADER, REPLACED } from "../core/relay.js";
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

const { default: worker, Reports, Room, World } = await import("./worker.js");

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
 * Makes a stand-in for a Durable Object's storage, which keeps copies of its values in memory.
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

      for (const [each, entry] of Object.entries(entries)) {
        values.set(each, structuredClone(entry));
      }
    },
    delete: async (key) => {
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

test("the Worker refuses a story write whose Content-Length is too long before reading it, and reads one without the header to tell", async () => {
  const forwarded = [];
  const env = { WORLDS: namespace(() => ({ fetch: async (request) => (forwarded.push(await request.text()), new Response("{}")) })) };
  const url = `https://relay.test/v1/worlds/${WORLD}/story`;
  let pulled = false;
  const unread = new ReadableStream({ pull: (controller) => ((pulled = true), controller.close()) }, { highWaterMark: 0 });

  const declared = await worker.fetch(new Request(url, { method: "POST", headers: { "Content-Length": String(STORY_LIMITS.maxBodyLength + 1) }, body: unread, duplex: "half" }), env);
  assert.deepEqual([declared.status, pulled, forwarded.length], [413, false, 0], "refused unread");

  const chunked = (text) => new Request(url, { method: "POST", body: new ReadableStream({ start: (controller) => (controller.enqueue(new TextEncoder().encode(text)), controller.close()) }), duplex: "half" });
  assert.equal((await worker.fetch(chunked("x".repeat(STORY_LIMITS.maxBodyLength + 1)), env)).status, 413, "a body without the header is read to tell");
  assert.equal((await worker.fetch(chunked("{}"), env)).status, 200);
  assert.deepEqual(forwarded, ["{}"], "a body short enough is forwarded whole");
});

test("the Worker sends bug reports to an object of their own, never to the world directory", async () => {
  const reached = [];
  const answering = (name) => namespace((id) => ({ fetch: async () => (reached.push(`${name}:${id}`), new Response("{}")) }));
  const env = { DIRECTORY: answering("directory"), REPORTS: answering("reports") };

  await worker.fetch(new Request("https://relay.test/v1/reports", { method: "POST", body: "{}" }), env);
  await worker.fetch(new Request("https://relay.test/v1/worlds"), env);
  assert.deepEqual(reached, ["reports:reports", "directory:directory"]);

  const reports = new Reports(objectState(), {});
  const off = await reports.fetch(new Request("https://relay.test/v1/reports", { method: "POST", body: "{}", headers: { [PLAYER_HEADER]: playerKey(1) } }));
  assert.deepEqual([off.status, (await off.json()).code], [503, "off"], "the object reads its settings from the Worker's bindings");
  assert.equal((await reports.fetch(new Request("https://relay.test/v1/reports"))).status, 404);
});
