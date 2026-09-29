//----------------------------------------------------------------
//  server.test.js
//
//  Changelog:
//      Paulinchen  2026-09-29: Tested world rooms over real WebSockets
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { CLOSE, EVERYONE, LIMITS, PAIRED, PONG } from "../core/relay.js";
import { createRelay } from "./server.js";

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

before(async () => {
  relay = createRelay({ limits: TEST_LIMITS, clock: () => now, checkEveryMs: 3_600_000 });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  base = `ws://127.0.0.1:${relay.server.address().port}/v1/room/`;
  worldBase = `ws://127.0.0.1:${relay.server.address().port}/v1/world/`;
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
 * Seats a game in a world room and collects what it receives.
 *
 * @param {string} room The room id.
 * @param {number} seats The seats the game asks for.
 * @returns {Promise<{socket: WebSocket, next: () => Promise<any>, closed: Promise<{code: number}>}>} The game, its next message and its close.
 */
async function sit(room, seats) {
  return open(`${worldBase}${room}?seats=${seats}`);
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

test("games in a world room get seats, and each learns who comes and goes", async () => {
  const first = await sit(roomId(101), 4);
  assert.equal(await first.next(), "seat 0");

  const second = await sit(roomId(101), 4);
  assert.equal(await second.next(), "seat 1 0");
  assert.equal(await first.next(), "in 1");

  const third = await sit(roomId(101), 4);
  assert.equal(await third.next(), "seat 2 0 1");

  second.socket.close();
  assert.equal(await first.next(), "in 2");
  assert.equal(await first.next(), "out 1");
  assert.equal(await third.next(), "out 1");

  first.socket.close();
  third.socket.close();
});

test("a world message goes to every other game, or to the one seat it names, with the sender's seat in front", async () => {
  const games = [];

  for (let seat = 0; seat < 3; seat++) {
    games.push(await sit(roomId(102), 3));
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

test("a full world room turns the next game away, and the first game's seats count, not a newcomer's", async () => {
  const first = await sit(roomId(103), 2);
  const second = await sit(roomId(103), 8);

  await assert.rejects(sit(roomId(103), 8));
  first.socket.close();
  second.socket.close();
});

test("an empty world message closes its sender", async () => {
  const game = await sit(roomId(104), 2);
  await game.next();

  game.socket.send(new Uint8Array(0));
  assert.equal((await game.closed).code, CLOSE.badRequest);
});

test("a world connection that lasted too long is closed, and the others see its seat free", async () => {
  const first = await sit(roomId(105), 2);
  await first.next();
  now += 1000;
  const second = await sit(roomId(105), 2);
  await second.next();
  await first.next();

  now += TEST_LIMITS.worldConnectionMs - 1000;
  relay.check();
  assert.equal((await first.closed).code, CLOSE.connectionExpired);
  assert.equal(await second.next(), "out 0");
  second.socket.close();
});
