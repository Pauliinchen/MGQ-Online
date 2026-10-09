//----------------------------------------------------------------
//  server.test.js
//
//  Changelog:
//      Paulinchen  2026-10-08: Tested a Raid World's story over HTTP: writes, conflicts, checkpoints, the route lock, companions, the frame every game hears, removed players and a deleted world, and that a Classic world keeps none
//                            - Tested that a world room lets into a Raid World only the games that name it in X-MGQ-Features
//                            - Tested the chat's rate limit and a chat frame without a line, which keeps the connection
//      Paulinchen  2026-10-07: Tested a world's chat: a game's mirrored line kept, an admin's line reaching every game, and other text still closing the connection
//                            - Tested the auth key header, the request and error log lines, every mod catalog route, editing a world, the address behind a proxy, the sweep and a text body over the cap
//                            - Expected 400 for a path that is no route and 426 for a room path without an upgrade
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
import { ModCatalog, zipHashes } from "../core/mods.js";
import { AUTH_HEADER, CHAT_LIMITS, CHAT_SLOW, CLOSE, EVERYONE, FEATURES_HEADER, LIMITS, PAIRED, PING, PLAYER_HEADER, PONG, REFUSAL_HEADER, REPLACED } from "../core/relay.js";
import { STORY_LIMITS } from "../core/story.js";
import { TRADE_LIMITS } from "../core/trades.js";
import { makeUpload, makeZip } from "../core/test_zip.js";
import { addressOf, createRelay, errorLine, memoryModStore, memoryStore, requestLine } from "./server.js";

/**
 * The auth key the tests' games make from their worlds' tokens.
 */
const AUTH = "ab".repeat(32);

/**
 * The player key of the tests' world creator.
 */
const CREATOR = "c0".repeat(16);

/**
 * An admin's player key, of the directory and of the mod catalog.
 */
const ADMIN = "ad".repeat(16);

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
 * What the relay under test logged: request lines and error lines.
 */
const logged = { info: [], error: [] };

/**
 * The log the relays under test write to, so the tests can read it and the output stays clean.
 */
const LOG = { info: (line) => logged.info.push(line), error: (line) => logged.error.push(line) };

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
  const directory = new Directory(memoryStore(), { clock: () => now, limits: TEST_DIRECTORY_LIMITS, rates: TEST_RATES, admins: [await playerIdOf(ADMIN)] });
  relay = createRelay({ limits: TEST_LIMITS, clock: () => now, checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, directory, log: LOG });
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

test("a chat line a game sends as text is kept for the admins, an admin's line reaches every game, and other text still closes", async () => {
  await makeWorld(roomId(130), 4);
  const first = await sit(roomId(130), 7);
  const second = await sit(roomId(130), 8);
  await first.next();
  await second.next();
  await first.next();

  first.socket.send("chat  hello there ");
  const chat = (headers) => fetch(`${directoryBase}/${roomId(130)}/chat`, { headers });
  await until(async () => (await (await chat({ [PLAYER_HEADER]: CREATOR })).json()).lines.length === 1);
  const [mirrored] = (await (await chat({ [PLAYER_HEADER]: CREATOR })).json()).lines;
  assert.deepEqual([mirrored.n, mirrored.player, mirrored.name, mirrored.text, mirrored.admin], [1, await playerIdOf(playerKey(7)), "Player 7", "hello there", false]);
  assert.equal((await chat({ [PLAYER_HEADER]: playerKey(8) })).status, 403, "players read the chat in the game");

  const say = (headers, body) => fetch(`${directoryBase}/${roomId(130)}/chat`, { method: "POST", headers, body: JSON.stringify(body) });
  assert.equal((await say({ [PLAYER_HEADER]: CREATOR }, { text: "hi" })).status, 403);
  assert.equal((await say({ [PLAYER_HEADER]: ADMIN }, { text: "welcome, all", name: "Global" })).status, 200);
  assert.equal(await first.next(), "chat Global\twelcome, all");
  assert.equal(await second.next(), "chat Global\twelcome, all");
  assert.deepEqual((await (await chat({ [PLAYER_HEADER]: ADMIN, })).json()).lines.map((line) => [line.text, line.admin]), [["hello there", false], ["welcome, all", true]]);

  second.socket.send("something else");
  assert.equal((await second.closed).code, CLOSE.badRequest);
  first.socket.close();
});

test("a game's chat lines past the chat's rate limit are dropped and answered, and an empty one is ignored", async () => {
  await makeWorld(roomId(131), 4);
  const game = await sit(roomId(131), 9);
  await game.next();

  game.socket.send("chat    ");

  for (let index = 0; index <= CHAT_LIMITS.burst; index++) {
    game.socket.send(`chat line ${index}`);
  }

  assert.equal(await game.next(), CHAT_SLOW, "the line past the burst is answered");
  const chat = async () => (await (await fetch(`${directoryBase}/${roomId(131)}/chat`, { headers: { [PLAYER_HEADER]: CREATOR } })).json()).lines;
  await until(async () => (await chat()).length === CHAT_LIMITS.burst);
  assert.deepEqual((await chat()).map((line) => line.text), Array.from({ length: CHAT_LIMITS.burst }, (_, index) => `line ${index}`), "the lines are kept in order, without the empty one");

  now += 1000;
  game.socket.send("chat later");
  await until(async () => (await chat()).length === CHAT_LIMITS.burst + 1);
  game.socket.send(PING);
  assert.equal(await game.next(), PONG, "the connection stays open");
  game.socket.close();
});

test("the directory hands out a world's lock and refuses what is no directory route", async () => {
  await makeWorld(roomId(108), 2);

  assert.deepEqual(await (await fetch(`${directoryBase}/${roomId(108)}/lock`)).json(), { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40), name: `World ${roomId(108).slice(-3)}`, seats: 2, start: "none", choose: false });
  assert.equal((await fetch(`${directoryBase}/${roomId(109)}/lock`)).status, 404);
  assert.equal((await fetch(`${directoryBase}/${roomId(108)}/elsewhere`)).status, 404);
  assert.equal((await fetch(directoryBase.replace("/v1/worlds", "/elsewhere"))).status, 400);
  assert.equal((await fetch(`${base.replace("ws:", "http:")}${roomId(108)}?role=host`)).status, 426, "a room's address needs its WebSocket");
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

test("a world room lets into a Raid World only the games that name it in X-MGQ-Features", async () => {
  const room = roomId(123);
  const created = await fetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: CREATOR },
    body: JSON.stringify({ id: room, name: "Raid World", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, type: "raid", share: "story" }),
  });
  assert.equal(created.status, 201);
  assert.deepEqual([(await listed(room)).type, (await listed(room)).share], ["raid", "story"]);

  const address = `${worldBase}${room}?name=Player%2052&auth=${AUTH}`;
  assert.deepEqual(await openWithHeaders(address, { [PLAYER_HEADER]: playerKey(52) }), { status: 400, refusal: "raid_unsupported" });

  const game = await openWithHeaders(address, { [PLAYER_HEADER]: playerKey(52), [FEATURES_HEADER]: "raid" });
  assert.equal(await game.first, "seat 0");
  game.socket.close();
});

test("a Raid World's players write its story over HTTP, every game in the room hears of each change, and deleting the world forgets it", async () => {
  const room = roomId(124);
  const created = await fetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: CREATOR },
    body: JSON.stringify({ id: room, name: "Raid Story", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, type: "raid" }),
  });
  assert.equal(created.status, 201);
  const watcher = await openWithHeaders(`${worldBase}${room}?name=Watcher&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(54), [FEATURES_HEADER]: "raid" });
  assert.equal(await watcher.first, "seat 0");
  const heard = [];
  watcher.socket.on("message", (data) => heard.push(data.toString()));

  const story = (path, init = {}, key = playerKey(53), auth = AUTH) => fetch(`${directoryBase}/${room}/story${path}`, { ...init, headers: { [PLAYER_HEADER]: key, [AUTH_HEADER]: auth } });
  const write = (body) => story("", { method: "POST", body: JSON.stringify(body) });
  const counters = (p) => ({ p, r1141: 0, r1142: 0, r1143: 0, clear: [] });

  assert.equal((await story("")).status, 200);
  assert.equal((await story("", {}, playerKey(53), "cd".repeat(32))).status, 401);
  assert.equal((await story("", {}, "zz")).status, 400);

  const first = await write({ base: 0, counters: counters(18), blob: "QUJD" });
  assert.equal(first.status, 200);
  assert.equal((await first.json()).rev, 1);
  await until(async () => heard.includes("story 1"));

  const second = await write({ base: 1, counters: { ...counters(19), end: { map: 2, x: 148, y: 243 } }, blob: "REVG" });
  assert.deepEqual(await second.json().then((body) => [body.rev, body.part, body.checkpoints, body.end]), [2, "2", ["1"], { map: 2, x: 148, y: 243 }]);

  const conflict = await write({ base: 1, counters: counters(20), blob: "R0hJ" });
  assert.equal(conflict.status, 409);
  assert.deepEqual(await conflict.json().then((body) => [body.code, body.rev, body.blob]), ["rev", 2, "REVG"]);

  const checkpoint = await (await story("/checkpoint/1")).json();
  assert.deepEqual([checkpoint.part, checkpoint.p, checkpoint.blob], ["1", 18, "QUJD"]);
  assert.equal((await story("/route", { method: "POST", body: JSON.stringify({ route: "mr" }) })).status, 200);
  assert.deepEqual((await (await story("/companions", { method: "POST", body: JSON.stringify({ ids: [382] }) })).json()).comps, [382]);
  await until(async () => heard.includes("story 4"));
  assert.equal((await write({ base: 2, counters: { ...counters(40), r1142: 1 }, blob: "R0hJ" })).status, 200, "a write on the last sealed story is taken after a lock and a companion");
  assert.equal((await story("", { method: "POST", body: "x".repeat(STORY_LIMITS.maxBodyLength + 10) })).status, 413);

  await fetch(`${directoryBase}/${room}/ban`, { method: "POST", body: JSON.stringify({ player: CREATOR, target: await playerIdOf(playerKey(55)) }) });
  assert.equal((await story("", {}, playerKey(55))).status, 403);

  assert.equal((await fetch(`${directoryBase}/${room}/delete`, { method: "POST", body: JSON.stringify({ player: CREATOR }) })).status, 200);
  assert.equal((await story("")).status, 404);
  assert.equal((await relay.storyOf(room).get()).body.rev, 0, "the deleted world's story is gone");
});

test("a Classic world keeps no story", async () => {
  await makeWorld(roomId(125), 4);
  const answer = await fetch(`${directoryBase}/${roomId(125)}/story`, { headers: { [PLAYER_HEADER]: playerKey(56), [AUTH_HEADER]: AUTH } });
  assert.equal(answer.status, 404);
  assert.equal((await answer.json()).code, "classic");
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
  const limited = createRelay({ limits: TEST_LIMITS, clock: () => now, checkEveryMs: 3_600_000, directory, log: LOG });
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

test("the auth key may come in the X-MGQ-Auth header, for the world rooms and the starting save", async () => {
  const room = roomId(118);
  const created = await fetch(directoryBase, {
    method: "POST",
    body: JSON.stringify({ id: room, name: "Auth World", seats: 2, player: CREATOR, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, start: true }),
  });
  assert.equal(created.status, 201);
  assert.equal((await fetch(`${directoryBase}/${room}/start`, { method: "POST", headers: { [PLAYER_HEADER]: CREATOR }, body: Uint8Array.of(4, 2) })).status, 200);

  const headers = { [PLAYER_HEADER]: playerKey(61), [AUTH_HEADER]: AUTH };
  const fetched = await fetch(`${directoryBase}/${room}/start`, { headers });
  assert.equal(fetched.status, 200);
  assert.deepEqual(new Uint8Array(await fetched.arrayBuffer()), Uint8Array.of(4, 2));
  assert.equal((await fetch(`${directoryBase}/${room}/start?auth=${AUTH}`, { headers: { [PLAYER_HEADER]: playerKey(61), [AUTH_HEADER]: "cd".repeat(32) } })).status, 401, "the header wins over the address");
  assert.equal((await fetch(`${directoryBase}/${room}/start?player=${playerKey(61)}&auth=${AUTH}`)).status, 200, "released games send both in the address");

  const game = await openWithHeaders(`${worldBase}${room}?name=Player%2061`, headers);
  assert.equal(await game.first, "seat 0");
  assert.deepEqual(await openWithHeaders(`${worldBase}${room}?name=Player%2062&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(62), [AUTH_HEADER]: "cd".repeat(32) }), { status: 401, refusal: undefined });
  game.socket.close();
});

test("every request is logged as one line without its query, and a caught error with its stack", async () => {
  const before = logged.info.length;
  await fetch(`${directoryBase}?player=${CREATOR}`);
  await fetch(`${directoryBase}/${roomId(119)}/lock`);
  const lines = logged.info.slice(before);

  assert.equal(lines.length, 2);
  assert.match(lines[0], /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z GET \/v1\/worlds 200 \d+ms 127\.0\.0\.1$/);
  assert.match(lines[1], /^\S+ GET \/v1\/worlds\/[0-9a-f]{32}\/lock 404 \d+ms 127\.0\.0\.1$/);
  assert.ok(!lines.some((line) => line.includes(CREATOR)), "a key in the address stays out of the log");
  assert.ok(logged.info.some((line) => / GET \/v1\/room\/[0-9a-f]{32} 101 /.test(line)), "an opened WebSocket is logged as 101");
  assert.ok(logged.info.some((line) => / GET \/v1\/world\/[0-9a-f]{32} 403 /.test(line)), "a refused WebSocket is logged with its status");

  assert.equal(requestLine(new Date(0), "POST", "/v1/mods", 413, 2.6, null), "1970-01-01T00:00:00.000Z POST /v1/mods 413 3ms -");
  const line = errorLine(new Date(0), "sweep", new Error("the store failed"));
  assert.match(line, /^1970-01-01T00:00:00\.000Z error sweep: Error: the store failed\n\s+at /);
  assert.equal(errorLine(new Date(0), "sweep", "plain"), "1970-01-01T00:00:00.000Z error sweep: plain");
});

test("an error while answering is logged with its stack and answered with 500", async () => {
  const broken = new Directory({ ...memoryStore(), all: async () => { throw new Error("the disk is gone"); } }, { clock: () => now });
  const relayOfBroken = createRelay({ clock: () => now, checkEveryMs: 3_600_000, directory: broken, log: LOG });
  await new Promise((resolve) => relayOfBroken.server.listen(0, "127.0.0.1", resolve));
  const port = relayOfBroken.server.address().port;

  const answer = await fetch(`http://127.0.0.1:${port}/v1/worlds`);
  assert.equal(answer.status, 500);
  assert.deepEqual(await answer.json(), { error: "the directory failed" });
  assert.match(logged.error.at(-1), /^\S+ error GET \/v1\/worlds: Error: the disk is gone\n\s+at /);
  assert.match(logged.info.at(-1), / GET \/v1\/worlds 500 /);
  await relayOfBroken.stop();
});

test("the sweep deletes worlds whose starting save never came and trades kept long enough", async () => {
  const room = roomId(120);
  const trade = "8".repeat(32);
  const tradesBase = directoryBase.replace("/v1/worlds", "/v1/trades");
  await makeWorld(room, 4);
  const game = await sit(room, 71);
  await until(async () => (await listed(room)).online === 1);
  const commit = await fetch(`${tradesBase}/${trade}/commit`, {
    method: "POST",
    body: JSON.stringify({ player: playerKey(71), world: room, partner: await playerIdOf(CREATOR), hash: "ab".repeat(32), sealed: "Qg==" }),
  });
  assert.deepEqual(await commit.json(), { state: "pending" });

  const pending = roomId(121);
  const created = await fetch(directoryBase, {
    method: "POST",
    body: JSON.stringify({ id: pending, name: "Never Started", seats: 2, player: CREATOR, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, start: true }),
  });
  assert.equal(created.status, 201);

  now += DIRECTORY_LIMITS.pendingMs;
  await relay.sweep();
  assert.equal(await relay.directory.store.get(pending), undefined);
  assert.equal((await relay.trades.store.getTrade(trade)).state, "cancelled");

  now += TRADE_LIMITS.keepCancelledMs;
  await relay.sweep();
  assert.equal(await relay.trades.store.getTrade(trade), undefined);
  game.socket.close();
});

test("the creator or an admin edits a world over HTTP", async () => {
  const room = roomId(122);
  await makeWorld(room, 4);
  const edit = (headers, body) => fetch(`${directoryBase}/${room}/edit`, { method: "POST", headers, body: JSON.stringify(body) });

  assert.equal((await edit({ [PLAYER_HEADER]: playerKey(81) }, { seats: 8 })).status, 403);
  assert.equal((await edit({ [PLAYER_HEADER]: CREATOR }, { seats: 99 })).status, 400);
  assert.equal((await edit({ [PLAYER_HEADER]: CREATOR }, { seats: 8, description: "  A world\nof two lines  ", mods: "!Level Cap" })).status, 200);
  assert.equal((await edit({}, { player: CREATOR, data: "1:abc" })).status, 200, "released games send the key in the body");

  const world = await listed(room);
  assert.deepEqual([world.seats, world.description, world.mods, world.data], [8, "A worldof two lines", "!Level Cap", "1:abc"]);
  assert.equal((await fetch(`${directoryBase}/${room}/edit`, { method: "POST", headers: { [PLAYER_HEADER]: CREATOR }, body: "x".repeat(300_000) })).status, 413, "a text body over the cap is too large");
});

/**
 * The link an admin sets, which leads to a release's script on a fake GitHub.
 */
const LINK = "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Level_Cap.rb";

/**
 * A fake GitHub: the latest link leads to the release's script, which GitHub's file host serves.
 *
 * @param {string} url The address fetched.
 * @returns {Promise<Response>} The answer.
 */
async function fakeGitHub(url) {
  const file = "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/v1.4.0/Level_Cap.rb";

  if (url === LINK) {
    return new Response(null, { status: 302, headers: { Location: file } });
  }

  if (url === file) {
    return new Response(null, { status: 302, headers: { Location: "https://release-assets.githubusercontent.com/file" } });
  }

  return url === "https://release-assets.githubusercontent.com/file" ? new Response("# cap", { status: 200 }) : new Response("not found", { status: 404 });
}

test("every mod catalog route answers over HTTP", async () => {
  const mods = new ModCatalog(memoryModStore(), { clock: () => now, admins: [await playerIdOf(ADMIN)], fetch: fakeGitHub });
  const catalogRelay = createRelay({ clock: () => now, checkEveryMs: 3_600_000, mods, log: LOG });
  await new Promise((resolve) => catalogRelay.server.listen(0, "127.0.0.1", resolve));
  const modsBase = `http://127.0.0.1:${catalogRelay.server.address().port}/v1/mods`;
  const admin = { [PLAYER_HEADER]: ADMIN };
  const post = (path, body, headers = admin) => fetch(`${modsBase}${path}`, { method: "POST", headers, body: typeof body === "string" || body instanceof Uint8Array ? body : JSON.stringify(body) });

  assert.deepEqual(await (await fetch(modsBase)).json(), { mods: [], admin: false });
  assert.equal((await post("", { name: "Level Cap", link: LINK }, {})).status, 403);
  const added = await post("", { name: "Level Cap", link: LINK });
  assert.equal(added.status, 200);
  assert.equal((await added.json()).mod.version, "1.4.0");
  assert.equal((await (await fetch(modsBase, { headers: admin })).json()).mods[0].link, LINK);

  const checked = await post("/check", {});
  assert.equal(checked.status, 200);
  assert.equal((await checked.json()).mods.length, 1);

  const zip = await makeZip([["Pack.rb", "# pack", true], ["Pack/a.luka", "A"]]);
  const files = await zipHashes(zip);
  assert.equal((await post(`/${encodeURIComponent("pack!")}/upload?name=Pack!&version=2.0`, makeUpload(files, zip))).status, 200);
  assert.equal((await post("/pack!/upload?name=Pack!&version=2.1", makeUpload({ ...files, "Pack.rb": "00".repeat(32) }, zip))).status, 400);
  const listedMods = (await (await fetch(modsBase)).json()).mods;
  assert.deepEqual(listedMods.map((mod) => [mod.key, mod.version]), [["levelcap", "1.4.0"], ["pack!", "2.0"]]);
  assert.deepEqual(listedMods[1].files, files);

  const options = [{ key: "mod_pack", name: "Pack", type: "b", default: "1", choices: [] }];
  assert.equal((await post("/pack%21/options", { version: "1.0", options })).status, 200, "an older version's options are kept until the current version's arrive");
  assert.equal((await (await fetch(modsBase)).json()).mods[1].optionsVersion, "1.0");
  assert.equal((await post("/pack%21/options", { version: "2.0", options })).status, 200);
  assert.deepEqual((await (await fetch(modsBase)).json()).mods[1].options, options);

  const file = await fetch(`${modsBase}/pack%21/file`);
  assert.equal(file.headers.get("content-type"), "application/octet-stream");
  assert.deepEqual(new Uint8Array(await file.arrayBuffer()), zip);
  assert.equal((await fetch(`${modsBase}/levelcap/file`)).status, 404);

  assert.equal((await post("/pack%21/delete", {}, {})).status, 403);
  assert.equal((await post("/pack%21/delete", {})).status, 200);
  assert.equal((await fetch(`${modsBase}/pack%21/file`)).status, 404);
  assert.equal((await post("", "x".repeat(9000))).status, 413);
  assert.equal((await fetch(`${modsBase}/levelcap/elsewhere`)).status, 404);
  await catalogRelay.stop();
});

test("addressOf trusts X-Forwarded-For from this machine only, and takes the address the proxy appended last", () => {
  const request = (remoteAddress, forwarded) => ({ socket: { remoteAddress }, headers: forwarded === undefined ? {} : { "x-forwarded-for": forwarded } });

  assert.equal(addressOf(request("127.0.0.1", "203.0.113.5, 198.51.100.7")), "198.51.100.7");
  assert.equal(addressOf(request("::ffff:127.0.0.1", "198.51.100.7")), "198.51.100.7");
  assert.equal(addressOf(request("::1", " 198.51.100.7 ")), "198.51.100.7");
  assert.equal(addressOf(request("127.0.0.1", "")), "127.0.0.1");
  assert.equal(addressOf(request("127.0.0.1")), "127.0.0.1");
  assert.equal(addressOf(request("203.0.113.5", "198.51.100.7")), "203.0.113.5", "a client cannot name another address");
  assert.equal(addressOf(request(undefined)), null);
});
