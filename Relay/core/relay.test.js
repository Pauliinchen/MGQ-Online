//----------------------------------------------------------------
//  relay.test.js
//
//  Changelog:
//      Paulinchen  2026-10-08: Covered the chat's rate limit and chat frames without a line
//      Paulinchen  2026-10-07: Covered the auth key header
//      Paulinchen  2026-10-06: Covered a guest waiting alone, the player key header, the rate limiter and replaced connections
//      Paulinchen  2026-09-29: Read a world room's player key, name and auth key instead of its seats
//                            - Tested world rooms: seats, routing and each connection's lifetime
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  CHAT_LIMITS, CLOSE, EVERYONE, IN, LIMITS, REPLACED, RateLimiter, admit, chatLineOf, newPeer, newWorldPeer, nextDeadline, nextWorldDeadline, overdue,
  parseRoute, presenceOf, replacedBy, routeWorldMessage, seatChangeText, seatText, takeChatLine, takeMessage, takeSeat, worldOverdue,
} from "./relay.js";

/**
 * A room id as clients make them.
 */
const ROOM = "0123456789abcdef0123456789abcdef";

/**
 * A player's key as games make them.
 */
const KEY = "fedcba9876543210fedcba9876543210";

/**
 * An auth key as games make them from a world's token.
 */
const AUTH = "ab".repeat(32);

/**
 * Who sits on a seat, as the tests seat them.
 */
const WHO = { player: "11".repeat(16), name: "Tester" };

/**
 * When the tests start.
 */
const T0 = 1_000_000;

test("parseRoute takes a room and a role", () => {
  assert.deepEqual(parseRoute(new URL(`https://relay.test/v1/room/${ROOM}?role=host`)), { kind: "room", roomId: ROOM, role: "host" });
  assert.deepEqual(parseRoute(new URL(`https://relay.test/v1/room/${ROOM}?role=guest`)), { kind: "room", roomId: ROOM, role: "guest" });
});

test("parseRoute takes a world room with the player's key, name and auth key", () => {
  assert.deepEqual(
    parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?player=${KEY}&name=Luka%20the%20Hero&auth=${AUTH}`)),
    { kind: "world", roomId: ROOM, player: KEY, name: "Luka the Hero", auth: AUTH },
  );
});

test("parseRoute refuses other versions, ids, roles and world rooms without key, name or auth", () => {
  for (const address of [
    `https://relay.test/v2/room/${ROOM}?role=host`,
    `https://relay.test/v1/room/${ROOM.toUpperCase()}?role=host`,
    `https://relay.test/v1/room/${ROOM}0?role=host`,
    `https://relay.test/v1/room/${ROOM}?role=spectator`,
    `https://relay.test/v1/room/${ROOM}`,
    `https://relay.test/v1/room/${ROOM}/extra?role=host`,
    `https://relay.test/v1/world/${ROOM}`,
    `https://relay.test/v1/world/${ROOM}?player=${KEY}&name=Luka`,
    `https://relay.test/v1/world/${ROOM}?player=${KEY}&auth=${AUTH}`,
    `https://relay.test/v1/world/${ROOM}?player=${KEY}&name=%20%0A&auth=${AUTH}`,
    `https://relay.test/v1/world/${ROOM}?player=${KEY.toUpperCase()}&name=Luka&auth=${AUTH}`,
    `https://relay.test/v1/world/${ROOM}?player=${KEY}&name=${"x".repeat(33)}&auth=${AUTH}`,
    `https://relay.test/v1/hall/${ROOM}?player=${KEY}&name=Luka&auth=${AUTH}`,
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
  const later = T0 + LIMITS.aloneWaitMs;

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
  assert.equal(nextDeadline([newPeer("host", T0)]), T0 + LIMITS.aloneWaitMs);
  assert.equal(nextDeadline([newPeer("host", T0), newPeer("guest", T0 + 1000)]), T0 + LIMITS.roomLifetimeMs);
});

test("takeSeat gives the lowest free seat, and refuses once every seat is taken", () => {
  assert.equal(takeSeat([], 4).seat, 0);
  assert.equal(takeSeat([newWorldPeer(0, WHO, T0), newWorldPeer(2, WHO, T0)], 4).seat, 1);

  const full = [0, 1].map((seat) => newWorldPeer(seat, WHO, T0));
  assert.deepEqual(takeSeat(full, 2), { seat: null, refusal: { code: CLOSE.worldFull, reason: "the world is full" } });
});

test("presenceOf lists who sits in a world room", () => {
  assert.deepEqual(presenceOf([newWorldPeer(1, WHO, T0)]), [WHO]);
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
  const peers = [newWorldPeer(0, WHO, T0), newWorldPeer(1, WHO, T0 + 5000)];
  const closed = worldOverdue(peers, T0 + LIMITS.worldConnectionMs);

  assert.deepEqual(closed, [{ index: 0, code: CLOSE.connectionExpired, reason: "the connection lasted too long" }]);
  assert.deepEqual(worldOverdue(peers, T0 + LIMITS.worldConnectionMs - 1), []);
});

test("nextWorldDeadline names the oldest connection's end", () => {
  assert.equal(nextWorldDeadline([]), null);
  assert.equal(nextWorldDeadline([newWorldPeer(1, WHO, T0 + 5000), newWorldPeer(0, WHO, T0)]), T0 + LIMITS.worldConnectionMs);
});

test("overdue closes a guest that waited alone too long too", () => {
  const guest = newPeer("guest", T0);

  assert.equal(overdue([guest], T0 + LIMITS.aloneWaitMs)[0].code, CLOSE.waitedTooLong);
  assert.equal(nextDeadline([guest]), T0 + LIMITS.aloneWaitMs);
});

test("parseRoute takes a world room's player key from the header before the address", () => {
  const route = parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?name=Luka&auth=${AUTH}`), KEY);
  assert.equal(route.player, KEY);

  const other = "0f".repeat(16);
  assert.equal(parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?player=${other}&name=Luka&auth=${AUTH}`), KEY).player, KEY);
  assert.equal(parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?player=${other}&name=Luka&auth=${AUTH}`)).player, other);
  assert.ok("error" in parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?name=Luka&auth=${AUTH}`), "nope"));
});

test("parseRoute takes a world room's auth key from the header before the address", () => {
  const other = "cd".repeat(32);

  assert.equal(parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?player=${KEY}&name=Luka`), null, AUTH).auth, AUTH);
  assert.equal(parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?name=Luka&auth=${other}`), KEY, AUTH).auth, AUTH);
  assert.equal(parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?player=${KEY}&name=Luka&auth=${other}`)).auth, other);
  assert.ok("error" in parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?player=${KEY}&name=Luka`), null, "nope"));
  assert.ok("error" in parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?player=${KEY}&name=Luka&auth=${AUTH}`), null, "nope"), "a header that is no auth key is not helped by the address");
});

test("RateLimiter lets each address go on a burst, then once per refill, and forgets the least recent addresses", () => {
  let now = T0;
  const limiter = new RateLimiter({ burst: 2, refillMs: 1000 }, () => now, 2);

  assert.deepEqual([limiter.take("a"), limiter.take("a"), limiter.take("a")], [true, true, false]);
  assert.equal(limiter.take("b"), true);
  assert.equal(limiter.take(null), true);

  now += 1000;
  assert.deepEqual([limiter.take("a"), limiter.take("a")], [true, false]);

  limiter.take("c");
  assert.deepEqual([...limiter.buckets.keys()], ["a", "c"]);
});

test("replacedBy names a player's earlier connections to a world room", () => {
  const peers = [newWorldPeer(0, WHO, T0), newWorldPeer(1, { player: "22".repeat(16), name: "Other" }, T0)];

  assert.deepEqual(replacedBy(peers, WHO.player), [{ index: 0, code: CLOSE.removed, reason: REPLACED }]);
  assert.deepEqual(replacedBy(peers, "33".repeat(16)), []);
});

test("chatLineOf tells a chat frame without a line apart from a frame that is no chat frame", () => {
  assert.equal(chatLineOf("chat  hello\u0001 "), "hello");
  assert.equal(chatLineOf("chat    "), "");
  assert.equal(chatLineOf("chatter"), null);
  assert.equal(chatLineOf("hello"), null);
});

test("takeChatLine lets a burst of lines through, then two a second", () => {
  let peer = newWorldPeer(0, WHO, T0);

  for (let index = 0; index < CHAT_LIMITS.burst; index++) {
    ({ peer } = takeChatLine(peer, T0));
  }

  assert.equal(takeChatLine(peer, T0).allowed, false, "the line past the burst");
  assert.equal(takeChatLine(peer, T0 + 400).allowed, false, "less than half a second later");
  ({ peer } = takeChatLine(peer, T0 + 500));
  assert.equal(takeChatLine(peer, T0 + 500).allowed, false, "the refilled line is used up");
  assert.equal(takeChatLine({ ...newWorldPeer(0, WHO, T0), chatAllowance: undefined, chatRefilledAt: undefined }, T0).allowed, true, "a record from before the chat's limit starts full");
});
