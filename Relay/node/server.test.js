//----------------------------------------------------------------
//  server.test.js
//
//  Changelog:
//      Paulinchen  2026-10-06: Tested a guest waiting alone, counted keep-alives, a room ended by the relay, a replaced world connection, the player key header, named refusals, the rate limits and a body over the limit
//                            - Tested a trade between two players of a world over HTTP
//      Paulinchen  2026-10-04: Expected the lock without the mods, the game data and the rule for it again
//                            - Expected the lock to name the mods a world needs, its creator's game data and whether only games with the same data may enter
//      Paulinchen  2026-10-02: Expected the lock to say whether new players choose where to start
//                            - Expected the list to say when each player was last seen
//      Paulinchen  2026-09-30: Tested the starting save over HTTP, as bytes both ways
//                            - Expected the lock to name its world
//      Paulinchen  2026-09-29: Made every world in the directory first, and tested the directory over HTTP
//                            - Tested world rooms over real WebSockets
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import WebSocketClient from "ws";
import { DIRECTORY_LIMITS, Directory, playerIdOf, sha256Hex } from "../core/directory.js";
import { CLOSE, EVERYONE, LIMITS, PAIRED, PING, PLAYER_HEADER, PONG, REFUSAL_HEADER, REPLACED } from "../core/relay.js";
import { createRelay, memoryStore } from "./server.js";

/**
 * The auth key the tests' games make from their worlds' tokens.
 */
const AUTH = "ab".repeat(32);

/**
 * The player key of the tests' world creator.
 */
const CREATOR = "c0".repeat(16);

/**
 * The limits the tests use: small messages, so the size check is quick to reach.
 */
const TEST_LIMITS = { ...LIMITS, maxMessageBytes: 1024 };

/**
 * The rate limits the tests use: high enough for every test from the same address.
 */
const TEST_RATES = Object.fromEntries(["joins", "creates", "starts"].map((kind) => [kind, { burst: 10_000, refillMs: 1 }]));

/**
 * The directory limits the tests use: small starting saves, so a body over the limit is quick to send.
 */
const TEST_DIRECTORY_LIMITS = { ...DIRECTORY_LIMITS, maxStartBytes: 400_000 };

/**
 * The time the relay under test sees, which tests move forward.
 */
let now = 1_000_000;

/**
 * The relay under test.
 */
let relay;

/**
 * The address of the relay's rooms.
 */
let base;

/**
 * The address of the relay's world rooms.
 */
let worldBase;

/**
 * The address of the relay's world directory.
 */
let directoryBase;

before(async () => {
  const directory = new Directory(memoryStore(), { clock: () => now, limits: TEST_DIRECTORY_LIMITS, rates: TEST_RATES });
  relay = createRelay({ limits: TEST_LIMITS, clock: () => now, checkEveryMs: 3_600_000, directory });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  base = `ws://127.0.0.1:${relay.server.address().port}/v1/room/`;
  worldBase = `ws://127.0.0.1:${relay.server.address().port}/v1/world/`;
  directoryBase = `http://127.0.0.1:${relay.server.address().port}/v1/worlds`;
});

after(() => relay.stop());

/**
 * Makes a room id no other test uses.
 *
 * @param {number} number A number unique to the test.
 * @returns {string} A room id.
 */
function roomId(number) {
  return number.toString(16).padStart(32, "0");
}

/**
 * Connects a peer and collects what it receives.
 *
 * @param {string} room The room id.
 * @param {string} role "host" or "guest".
 * @returns {Promise<{socket: WebSocket, next: () => Promise<any>, closed: Promise<{code: number}>}>} The peer, its next message and its close.
 */
async function connect(room, role) {
  return open(`${base}${room}?role=${role}`);
}

/**
 * Makes a world in the directory, with the tests' auth key.
 *
 * @param {string} room The world's id.
 * @param {number} seats Its seats.
 * @returns {Promise<number>} The directory's HTTP status.
 */
async function makeWorld(room, seats) {
  const response = await fetch(directoryBase, {
    method: "POST",
    body: JSON.stringify({
      id: room,
      name: `World ${room.slice(-3)}`,
      seats,
      player: CREATOR,
      playerName: "Creator",
      authHash: await sha256Hex(AUTH),
      lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) },
    }),
  });
  return response.status;
}

/**
 * Makes a player key unique to a number.
 *
 * @param {number} number The number.
 * @returns {string} The key.
 */
function playerKey(number) {
  return number.toString(16).padStart(32, "a");
}

/**
 * Seats a game in a world room and collects what it receives.
 *
 * @param {string} room The world's id.
 * @param {number} player A number unique to the player.
 * @param {string} [auth] The auth key, the tests' own unless given.
 * @returns {Promise<{socket: WebSocket, next: () => Promise<any>, closed: Promise<{code: number}>}>} The game, its next message and its close.
 */
async function sit(room, player, auth = AUTH) {
  return open(`${worldBase}${room}?player=${playerKey(player)}&name=Player%20${player}&auth=${auth}`);
}

/**
 * Reads a world from the directory's list.
 *
 * @param {string} room The world's id.
 * @returns {Promise<object | undefined>} The world as everyone sees it.
 */
async function listed(room) {
  const { worlds } = await (await fetch(directoryBase)).json();
  return worlds.find((world) => world.id === room);
}

/**
 * Waits until a condition holds, looking every few milliseconds.
 *
 * @param {() => Promise<boolean>} condition The condition.
 * @returns {Promise<void>} Resolves once it holds.
 */
async function until(condition) {
  for (let tries = 0; tries < 100; tries++) {
    if (await condition()) {
      return;
    }

    await new Promise((resolve) => setTimeout(resolve, 10));
  }

  throw new Error("the condition never held");
}

/**
 * Opens a WebSocket and collects what it receives.
 *
 * @param {string} address The address.
 * @returns {Promise<{socket: WebSocket, next: () => Promise<any>, closed: Promise<{code: number, reason: string}>}>} The socket, its next message and its close.
 */
async function open(address) {
  const socket = new WebSocket(address);
  socket.binaryType = "arraybuffer";
  const inbox = [];
  const waiting = [];

  socket.addEventListener("message", (event) => (waiting.length > 0 ? waiting.shift()(event.data) : inbox.push(event.data)));
  const closed = new Promise((resolve) => socket.addEventListener("close", (event) => resolve({ code: event.code, reason: event.reason })));

  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  return {
    socket,
    closed,
    next: () => (inbox.length > 0 ? Promise.resolve(inbox.shift()) : new Promise((resolve) => waiting.push(resolve))),
  };
}

test("a host and a guest are told they are paired, and their binary messages pass both ways", async () => {
  const host = await connect(roomId(1), "host");
  const guest = await connect(roomId(1), "guest");

  assert.equal(await host.next(), PAIRED);
  assert.equal(await guest.next(), PAIRED);

  guest.socket.send(new Uint8Array([1, 2, 3]));
  assert.deepEqual([...new Uint8Array(await host.next())], [1, 2, 3]);

  host.socket.send(new Uint8Array([4, 5]));
  assert.deepEqual([...new Uint8Array(await guest.next())], [4, 5]);

  host.socket.close();
  guest.socket.close();
});

test("a second host is turned away before its WebSocket opens", async () => {
  const host = await connect(roomId(2), "host");

  await assert.rejects(connect(roomId(2), "host"));
  host.socket.close();
});

test("the guest is closed once the host leaves", async () => {
  const host = await connect(roomId(3), "host");
  const guest = await connect(roomId(3), "guest");

  host.socket.close();
  assert.equal((await guest.closed).code, CLOSE.peerLeft);
});

test("a keep-alive is answered, and other text closes the connection", async () => {
  const host = await connect(roomId(4), "host");

  host.socket.send("ping");
  assert.equal(await host.next(), PONG);

  host.socket.send("hello");
  assert.equal((await host.closed).code, CLOSE.badRequest);
});

test("a message over the size limit closes its sender", async () => {
  const host = await connect(roomId(5), "host");
  await connect(roomId(5), "guest");

  host.socket.send(new Uint8Array(TEST_LIMITS.maxMessageBytes + 1));
  assert.equal((await host.closed).code, CLOSE.tooLarge);
});

test("a host that waited alone too long is closed", async () => {
  const host = await connect(roomId(6), "host");

  now += TEST_LIMITS.aloneWaitMs;
  relay.check();
  assert.equal((await host.closed).code, CLOSE.waitedTooLong);
});

test("games in a world room get seats, each learns who comes and goes, and the directory knows who is online", async () => {
  assert.equal(await makeWorld(roomId(101), 4), 201);
  const first = await sit(roomId(101), 1);
  assert.equal(await first.next(), "seat 0");

  const second = await sit(roomId(101), 2);
  assert.equal(await second.next(), "seat 1 0");
  assert.equal(await first.next(), "in 1");

  const third = await sit(roomId(101), 3);
  assert.equal(await third.next(), "seat 2 0 1");

  await until(async () => (await listed(roomId(101))).online === 3);
  const secondId = await playerIdOf(playerKey(2));
  const members = (await listed(roomId(101))).members;
  const { seen, ...secondMember } = members.find((member) => member.id === secondId);
  assert.deepEqual(secondMember, { id: secondId, name: "Player 2", online: true });
  assert.equal(typeof seen, "number");

  second.socket.close();
  assert.equal(await first.next(), "in 2");
  assert.equal(await first.next(), "out 1");
  assert.equal(await third.next(), "out 1");
  await until(async () => (await listed(roomId(101))).online === 2);

  first.socket.close();
  third.socket.close();
});

test("a world message goes to every other game, or to the one seat it names, with the sender's seat in front", async () => {
  await makeWorld(roomId(102), 3);
  const games = [];

  for (let player = 0; player < 3; player++) {
    games.push(await sit(roomId(102), player));
  }

  await games[0].next();
  await games[0].next();
  await games[0].next();
  await games[1].next();
  await games[1].next();
  await games[2].next();

  games[2].socket.send(new Uint8Array([EVERYONE, 5, 6]));
  assert.deepEqual([...new Uint8Array(await games[0].next())], [2, 5, 6]);
  assert.deepEqual([...new Uint8Array(await games[1].next())], [2, 5, 6]);

  games[0].socket.send(new Uint8Array([1, 7]));
  assert.deepEqual([...new Uint8Array(await games[1].next())], [0, 7]);

  // Seat 2 got nothing meant for seat 1, so the next thing it hears is this broadcast.
  games[1].socket.send(new Uint8Array([EVERYONE, 8]));
  assert.deepEqual([...new Uint8Array(await games[2].next())], [1, 8]);

  for (const game of games) {
    game.socket.close();
  }
});

test("a full world room turns the next game away", async () => {
  await makeWorld(roomId(103), 2);
  const first = await sit(roomId(103), 1);
  const second = await sit(roomId(103), 2);

  await assert.rejects(sit(roomId(103), 3));
  first.socket.close();
  second.socket.close();
});

test("a world room turns away a game with the wrong auth key, and any game for a world the directory lacks", async () => {
  await makeWorld(roomId(104), 2);

  await assert.rejects(sit(roomId(104), 1, "cd".repeat(32)));
  await assert.rejects(sit(roomId(199), 1));
});

test("an empty world message closes its sender", async () => {
  await makeWorld(roomId(105), 2);
  const game = await sit(roomId(105), 1);
  await game.next();

  game.socket.send(new Uint8Array(0));
  assert.equal((await game.closed).code, CLOSE.badRequest);
});

test("a world connection that lasted too long is closed, and the others see its seat free", async () => {
  await makeWorld(roomId(106), 2);
  const first = await sit(roomId(106), 1);
  await first.next();
  now += 1000;
  const second = await sit(roomId(106), 2);
  await second.next();
  await first.next();

  now += TEST_LIMITS.worldConnectionMs - 1000;
  relay.check();
  assert.equal((await first.closed).code, CLOSE.connectionExpired);
  assert.equal(await second.next(), "out 0");
  second.socket.close();
});

test("a player the creator removes is closed and kept out, and deleting the world closes everyone", async () => {
  await makeWorld(roomId(107), 4);
  const guest = await sit(roomId(107), 5);
  const other = await sit(roomId(107), 6);
  await guest.next();
  await other.next();
  await guest.next();

  const post = (path, body) => fetch(`${directoryBase}/${roomId(107)}/${path}`, { method: "POST", body: JSON.stringify(body) });

  assert.equal((await post("ban", { player: playerKey(6), target: await playerIdOf(playerKey(5)) })).status, 403);
  assert.equal((await post("ban", { player: CREATOR, target: await playerIdOf(playerKey(5)) })).status, 200);
  assert.equal((await guest.closed).code, CLOSE.removed);
  await assert.rejects(sit(roomId(107), 5));

  assert.equal((await post("delete", { player: CREATOR })).status, 200);
  assert.equal((await other.closed).code, CLOSE.worldDeleted);
  assert.equal(await listed(roomId(107)), undefined);
});

test("the directory hands out a world's lock and refuses what is no directory route", async () => {
  await makeWorld(roomId(108), 2);

  assert.deepEqual(await (await fetch(`${directoryBase}/${roomId(108)}/lock`)).json(), { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40), name: `World ${roomId(108).slice(-3)}`, seats: 2, start: "none", choose: false });
  assert.equal((await fetch(`${directoryBase}/${roomId(109)}/lock`)).status, 404);
  assert.equal((await fetch(directoryBase.replace("/v1/worlds", "/elsewhere"))).status, 426);
});


test("the creator uploads a starting save as bytes, which the world's players fetch as they were", async () => {
  const room = roomId(110);
  const save = new Uint8Array(300_000).map((_, index) => index % 251);
  const response = await fetch(directoryBase, {
    method: "POST",
    body: JSON.stringify({
      id: room,
      name: "Started World",
      seats: 2,
      player: CREATOR,
      playerName: "Creator",
      authHash: await sha256Hex(AUTH),
      lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) },
      start: true,
    }),
  });
  assert.equal(response.status, 201);
  await assert.rejects(sit(room, 7));

  const uploaded = await fetch(`${directoryBase}/${room}/start?player=${CREATOR}`, { method: "POST", body: save });
  assert.equal(uploaded.status, 200);
  assert.equal((await listed(room)).start, "ready");

  const fetched = await fetch(`${directoryBase}/${room}/start?player=${playerKey(7)}&auth=${AUTH}`);
  assert.equal(fetched.status, 200);
  assert.deepEqual(new Uint8Array(await fetched.arrayBuffer()), save);
  assert.equal((await fetch(`${directoryBase}/${room}/start?player=${playerKey(7)}&auth=${"cd".repeat(32)}`)).status, 401);
});

test("two players of a world commit a trade over HTTP, which each finds again until done", async () => {
  const room = roomId(111);
  const trade = "7".repeat(32);
  const tradesBase = directoryBase.replace("/v1/worlds", "/v1/trades");
  await makeWorld(room, 4);
  const first = await sit(room, 21);
  const second = await sit(room, 22);
  await until(async () => (await listed(room)).online === 2);

  const commit = async (player, partner, sealed) => (await fetch(`${tradesBase}/${trade}/commit`, {
    method: "POST",
    body: JSON.stringify({ player: playerKey(player), world: room, partner: await playerIdOf(playerKey(partner)), hash: "ab".repeat(32), sealed }),
  })).json();

  assert.deepEqual(await commit(21, 22, "A".repeat(60_000)), { state: "pending" });
  assert.deepEqual(await commit(22, 21, "Qg=="), { state: "committed" });
  assert.deepEqual(await (await fetch(`${tradesBase}/${trade}?player=${playerKey(21)}`)).json(), { state: "committed" });
  assert.deepEqual(await (await fetch(`${tradesBase}?player=${playerKey(22)}&world=${room}`)).json(), { trades: [{ id: trade, hash: "ab".repeat(32), sealed: "Qg==" }] });

  const done = await fetch(`${tradesBase}/${trade}/done`, { method: "POST", body: JSON.stringify({ player: playerKey(22) }) });
  assert.equal(done.status, 200);
  assert.deepEqual(await (await fetch(`${tradesBase}?player=${playerKey(22)}&world=${room}`)).json(), { trades: [] });

  first.socket.close();
  second.socket.close();
});

/**
 * Opens a WebSocket with the ws client, which sends headers, and tells how the relay answered.
 *
 * @param {string} address The address.
 * @param {object} headers The request's headers.
 * @returns {Promise<{socket?: WebSocketClient, first?: Promise<string>, status?: number, refusal?: string}>} The open socket with its first message, or the refusal's status and REFUSAL_HEADER.
 */
function openWithHeaders(address, headers) {
  return new Promise((resolve) => {
    const socket = new WebSocketClient(address, { headers });
    const first = new Promise((received) => socket.once("message", (data) => received(data.toString())));

    socket.on("open", () => resolve({ socket, first }));
    socket.on("unexpected-response", (request, response) => {
      resolve({ status: response.statusCode, refusal: response.headers[REFUSAL_HEADER.toLowerCase()] });
      request.destroy();
    });
    socket.on("error", () => {});
  });
}

test("a guest that waited alone too long is closed too", async () => {
  const guest = await connect(roomId(7), "guest");

  now += TEST_LIMITS.aloneWaitMs;
  relay.check();
  assert.equal((await guest.closed).code, CLOSE.waitedTooLong);
});

test("keep-alives count against the message allowance", async () => {
  const host = await connect(roomId(8), "host");

  for (let sent = 0; sent <= TEST_LIMITS.burst; sent++) {
    host.socket.send(PING);
  }

  assert.equal((await host.closed).code, CLOSE.tooFast);
});

test("a room the relay ended takes new peers at once, whom the closed ones leave alone", async () => {
  const host = await connect(roomId(9), "host");
  const guest = await connect(roomId(9), "guest");
  await host.next();
  await guest.next();

  host.socket.send(new Uint8Array(TEST_LIMITS.maxMessageBytes + 1));
  const newHost = await connect(roomId(9), "host");
  const newGuest = await connect(roomId(9), "guest");

  assert.equal((await host.closed).code, CLOSE.tooLarge);
  assert.equal((await guest.closed).code, CLOSE.peerLeft);
  assert.equal(await newHost.next(), PAIRED);
  newGuest.socket.send(new Uint8Array([3]));
  await newGuest.next();
  assert.deepEqual([...new Uint8Array(await newHost.next())], [3]);

  newHost.socket.close();
  newGuest.socket.close();
});

test("a player who enters a world room again replaces the earlier connection, which gives up its seat", async () => {
  await makeWorld(roomId(112), 2);
  const first = await sit(roomId(112), 31);
  const other = await sit(roomId(112), 32);
  assert.equal(await first.next(), "seat 0");
  assert.equal(await other.next(), "seat 1 0");

  const again = await sit(roomId(112), 31);
  assert.deepEqual(await first.closed, { code: CLOSE.removed, reason: REPLACED });
  assert.equal(await again.next(), "seat 0 1");
  assert.equal(await other.next(), "out 0");
  assert.equal(await other.next(), "in 0");
  await until(async () => (await listed(roomId(112))).online === 2);

  again.socket.close();
  other.socket.close();
});

test("the player key may come in the X-MGQ-Player header, for the directory and the world rooms", async () => {
  const room = roomId(113);
  const created = await fetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: CREATOR },
    body: JSON.stringify({ id: room, name: "Header World", seats: 2, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 600_000, box: "ab".repeat(40) }, hidden: true }),
  });
  assert.equal(created.status, 201);

  const hidden = async (headers) => (await (await fetch(directoryBase, { headers })).json()).worlds.some((world) => world.id === room);
  assert.equal(await hidden({}), false);
  assert.equal(await hidden({ [PLAYER_HEADER]: CREATOR }), true);

  const game = await openWithHeaders(`${worldBase}${room}?name=Player%2042&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(42) });
  assert.equal(await game.first, "seat 0");
  await until(async () => (await (await fetch(directoryBase, { headers: { [PLAYER_HEADER]: CREATOR } })).json()).worlds.find((world) => world.id === room).online === 1);
  game.socket.close();
});

test("a world room names why it turned a game away", async () => {
  const room = roomId(114);
  await makeWorld(room, 4);
  await fetch(`${directoryBase}/${room}/ban`, { method: "POST", body: JSON.stringify({ player: CREATOR, target: await playerIdOf(playerKey(51)) }) });

  assert.deepEqual(await openWithHeaders(`${worldBase}${room}?player=${playerKey(51)}&name=Banned&auth=${AUTH}`, {}), { status: 403, refusal: "removed" });
});

test("a starting save over the limit is refused with its status, not a cut connection", async () => {
  const room = roomId(115);
  const created = await fetch(directoryBase, {
    method: "POST",
    body: JSON.stringify({ id: room, name: "Big Save", seats: 2, player: CREATOR, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, start: true }),
  });
  assert.equal(created.status, 201);

  const uploaded = await fetch(`${directoryBase}/${room}/start`, { method: "POST", headers: { [PLAYER_HEADER]: CREATOR }, body: new Uint8Array(TEST_DIRECTORY_LIMITS.maxStartBytes + 100_000) });
  assert.equal(uploaded.status, 413);
});

test("entering rooms and making worlds are limited per address", async () => {
  const once = { burst: 1, refillMs: 3_600_000 };
  const directory = new Directory(memoryStore(), { clock: () => now, rates: { joins: once, creates: once, starts: once } });
  const limited = createRelay({ limits: TEST_LIMITS, clock: () => now, checkEveryMs: 3_600_000, directory });
  await new Promise((resolve) => limited.server.listen(0, "127.0.0.1", resolve));
  const port = limited.server.address().port;

  const host = await open(`ws://127.0.0.1:${port}/v1/room/${roomId(10)}?role=host`);
  assert.equal((await openWithHeaders(`ws://127.0.0.1:${port}/v1/room/${roomId(11)}?role=host`, {})).status, 429);

  const world = (id) => JSON.stringify({ id, name: "Limited", seats: 2, player: CREATOR, playerName: "Creator", authHash: "ab".repeat(32), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) } });
  assert.equal((await fetch(`http://127.0.0.1:${port}/v1/worlds`, { method: "POST", body: world(roomId(116)) })).status, 201);
  const refused = await fetch(`http://127.0.0.1:${port}/v1/worlds`, { method: "POST", body: world(roomId(117)) });
  assert.deepEqual([refused.status, (await refused.json()).code], [429, "rate"]);

  host.socket.close();
  await limited.stop();
});
