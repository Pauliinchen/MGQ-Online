//----------------------------------------------------------------
//  relay.test.js
//
//  Changelog:
//      Paulinchen  2026-09-29: Tested world rooms: seats, routing and each connection's lifetime
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  CLOSE, EVERYONE, IN, LIMITS, WORLD_SEATS, admit, newPeer, newWorldPeer, nextDeadline, nextWorldDeadline, overdue, parseRoute,
  routeWorldMessage, seatChangeText, seatText, takeMessage, takeSeat, worldCapacity, worldOverdue,
} from "./relay.js";

/**
 * A room id as clients make them.
 */
const ROOM = "0123456789abcdef0123456789abcdef";

/**
 * When the tests start.
 */
const T0 = 1_000_000;

test("parseRoute takes a room and a role", () => {
  assert.deepEqual(parseRoute(new URL(`https://relay.test/v1/room/${ROOM}?role=host`)), { kind: "room", roomId: ROOM, role: "host" });
  assert.deepEqual(parseRoute(new URL(`https://relay.test/v1/room/${ROOM}?role=guest`)), { kind: "room", roomId: ROOM, role: "guest" });
});

test("parseRoute takes a world room and its seats", () => {
  assert.deepEqual(parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?seats=4`)), { kind: "world", roomId: ROOM, seats: 4 });
  assert.deepEqual(parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?seats=${WORLD_SEATS.max}`)).seats, WORLD_SEATS.max);
});

test("parseRoute refuses other versions, ids, roles and seats", () => {
  for (const address of [
    `https://relay.test/v2/room/${ROOM}?role=host`,
    `https://relay.test/v1/room/${ROOM.toUpperCase()}?role=host`,
    `https://relay.test/v1/room/${ROOM}0?role=host`,
    `https://relay.test/v1/room/${ROOM}?role=spectator`,
    `https://relay.test/v1/room/${ROOM}`,
    `https://relay.test/v1/room/${ROOM}/extra?role=host`,
    `https://relay.test/v1/world/${ROOM}`,
    `https://relay.test/v1/world/${ROOM}?seats=1`,
    `https://relay.test/v1/world/${ROOM}?seats=${WORLD_SEATS.max + 1}`,
    `https://relay.test/v1/world/${ROOM}?seats=4.5`,
    `https://relay.test/v1/world/${ROOM}?seats=-4`,
    `https://relay.test/v1/hall/${ROOM}?seats=4`,
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

test("worldCapacity keeps the seats of the games in the room, and takes the newcomer's for an empty one", () => {
  assert.equal(worldCapacity([], 6), 6);
  assert.equal(worldCapacity([newWorldPeer(0, 4, T0)], 32), 4);
});

test("takeSeat gives the lowest free seat, and refuses once every seat is taken", () => {
  assert.equal(takeSeat([], 4).seat, 0);
  assert.equal(takeSeat([newWorldPeer(0, 4, T0), newWorldPeer(2, 4, T0)], 4).seat, 1);

  const full = [0, 1].map((seat) => newWorldPeer(seat, 2, T0));
  assert.deepEqual(takeSeat(full, 2), { seat: null, refusal: { code: CLOSE.worldFull, reason: "the world is full" } });
});

test("seatText and seatChangeText write what the games are told", () => {
  assert.equal(seatText(2, [1, 0]), "seat 2 0 1");
  assert.equal(seatText(0, []), "seat 0");
  assert.equal(seatChangeText(IN, 3), "in 3");
});

test("routeWorldMessage puts the sender's seat in place of the target", () => {
  const toOne = routeWorldMessage(2, new Uint8Array([1, 7, 8]));
  assert.equal(toOne.target, 1);
  assert.deepEqual([...toOne.forwarded], [2, 7, 8]);

  const toAll = routeWorldMessage(0, new Uint8Array([EVERYONE, 9]));
  assert.equal(toAll.target, null);
  assert.deepEqual([...toAll.forwarded], [0, 9]);
});

test("routeWorldMessage refuses an empty message and leaves the original untouched", () => {
  assert.equal(routeWorldMessage(0, new Uint8Array(0)).refusal.code, CLOSE.badRequest);

  const message = new Uint8Array([EVERYONE, 1]);
  routeWorldMessage(3, message);
  assert.equal(message[0], EVERYONE);
});

test("worldOverdue closes each connection on its own once it lasted too long", () => {
  const peers = [newWorldPeer(0, 4, T0), newWorldPeer(1, 4, T0 + 5000)];
  const closed = worldOverdue(peers, T0 + LIMITS.worldConnectionMs);

  assert.deepEqual(closed, [{ index: 0, code: CLOSE.connectionExpired, reason: "the connection lasted too long" }]);
  assert.deepEqual(worldOverdue(peers, T0 + LIMITS.worldConnectionMs - 1), []);
});

test("nextWorldDeadline names the oldest connection's end", () => {
  assert.equal(nextWorldDeadline([]), null);
  assert.equal(nextWorldDeadline([newWorldPeer(1, 4, T0 + 5000), newWorldPeer(0, 4, T0)]), T0 + LIMITS.worldConnectionMs);
});
