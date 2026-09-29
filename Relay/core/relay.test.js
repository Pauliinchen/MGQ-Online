//----------------------------------------------------------------
//  relay.test.js
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { CLOSE, LIMITS, admit, newPeer, nextDeadline, overdue, parseRoute, takeMessage } from "./relay.js";

/**
 * A room id as clients make them.
 */
const ROOM = "0123456789abcdef0123456789abcdef";

/**
 * When the tests start.
 */
const T0 = 1_000_000;

test("parseRoute takes a room and a role", () => {
  assert.deepEqual(parseRoute(new URL(`https://relay.test/v1/room/${ROOM}?role=host`)), { roomId: ROOM, role: "host" });
  assert.deepEqual(parseRoute(new URL(`https://relay.test/v1/room/${ROOM}?role=guest`)), { roomId: ROOM, role: "guest" });
});

test("parseRoute refuses other versions, ids and roles", () => {
  for (const address of [
    `https://relay.test/v2/room/${ROOM}?role=host`,
    `https://relay.test/v1/room/${ROOM.toUpperCase()}?role=host`,
    `https://relay.test/v1/room/${ROOM}0?role=host`,
    `https://relay.test/v1/room/${ROOM}?role=spectator`,
    `https://relay.test/v1/room/${ROOM}`,
    `https://relay.test/v1/room/${ROOM}/extra?role=host`,
  ]) {
    assert.ok("error" in parseRoute(new URL(address)), address);
  }
});

test("admit lets one host and one guest in, never a second of either", () => {
  assert.equal(admit([], "host"), null);
  assert.equal(admit(["host"], "guest"), null);
  assert.equal(admit([], "guest"), null);
  assert.equal(admit(["host"], "host").code, CLOSE.roleTaken);
  assert.equal(admit(["host", "guest"], "guest").code, CLOSE.roleTaken);
});

test("takeMessage refuses a message larger than the limit", () => {
  const { refusal } = takeMessage(newPeer("host", T0), LIMITS.maxMessageBytes + 1, T0);

  assert.equal(refusal.code, CLOSE.tooLarge);
});

test("takeMessage allows a burst, then refuses until the allowance refills", () => {
  let peer = newPeer("host", T0);

  for (let sent = 0; sent < LIMITS.burst; sent++) {
    const result = takeMessage(peer, 100, T0);
    assert.equal(result.refusal, null);
    peer = result.peer;
  }

  assert.equal(takeMessage(peer, 100, T0).refusal.code, CLOSE.tooFast);
  assert.equal(takeMessage(peer, 100, T0 + 1000).refusal, null);
});

test("overdue closes a host that waited alone too long, but not one with a guest", () => {
  const host = newPeer("host", T0);
  const later = T0 + LIMITS.hostWaitMs;

  assert.deepEqual(overdue([host], later - 1), []);
  assert.equal(overdue([host], later)[0].code, CLOSE.waitedTooLong);
  assert.deepEqual(overdue([host, newPeer("guest", T0 + 1000)], later), []);
});

test("overdue closes everyone once the room lasted too long", () => {
  const peers = [newPeer("host", T0), newPeer("guest", T0 + 1000)];
  const closed = overdue(peers, T0 + LIMITS.roomLifetimeMs);

  assert.deepEqual(closed.map((entry) => entry.code), [CLOSE.roomExpired, CLOSE.roomExpired]);
});

test("nextDeadline names the host's wait while alone, the room's end once paired", () => {
  assert.equal(nextDeadline([]), null);
  assert.equal(nextDeadline([newPeer("host", T0)]), T0 + LIMITS.hostWaitMs);
  assert.equal(nextDeadline([newPeer("host", T0), newPeer("guest", T0 + 1000)]), T0 + LIMITS.roomLifetimeMs);
});
