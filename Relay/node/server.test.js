//----------------------------------------------------------------
//  server.test.js
//
//  Changelog:
//      Paulinchen  2026-10-06: Tested a trade between two players of a world over HTTP
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
import { playerIdOf, sha256Hex } from "../core/directory.js";
import { CLOSE, EVERYONE, LIMITS, PAIRED, PONG } from "../core/relay.js";
import { createRelay } from "./server.js";

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
  relay = createRelay({ limits: TEST_LIMITS, clock: () => now, checkEveryMs: 3_600_000 });
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
 * @returns {Promise<{socket: WebSocket, next: () => Promise<any>, closed: Promise<{code: number}>}>} The socket, its next message and its close.
 */
async function open(address) {
  const socket = new WebSocket(address);
  socket.binaryType = "arraybuffer";
  const inbox = [];
  const waiting = [];

  socket.addEventListener("message", (event) => (waiting.length > 0 ? waiting.shift()(event.data) : inbox.push(event.data)));
  const closed = new Promise((resolve) => socket.addEventListener("close", (event) => resolve({ code: event.code })));

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

  now += TEST_LIMITS.hostWaitMs;
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
