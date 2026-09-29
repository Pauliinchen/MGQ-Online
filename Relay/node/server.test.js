//----------------------------------------------------------------
//  server.test.js
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { CLOSE, LIMITS, PAIRED, PONG } from "../core/relay.js";
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
 * The address the relay listens on.
 */
let base;

before(async () => {
  relay = createRelay({ limits: TEST_LIMITS, clock: () => now, checkEveryMs: 3_600_000 });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  base = `ws://127.0.0.1:${relay.server.address().port}/v1/room/`;
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
  const socket = new WebSocket(`${base}${room}?role=${role}`);
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
