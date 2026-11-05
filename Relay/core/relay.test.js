//----------------------------------------------------------------
//  relay.test.js
//
//  Changelog:
//      Paulinchen  2026-11-05: Tested a world room's keys taken from the headers only
//                            - Dropped the tests of the PvP rooms
//      Paulinchen  2026-10-30: Dropped the test of the presence list
//      Paulinchen  2026-10-08: Covered the chat's rate limit and chat frames without a line
//      Paulinchen  2026-10-07: Covered the auth key header
//      Paulinchen  2026-10-06: Covered a guest waiting alone, the player key header, the rate limiter and replaced connections
//      Paulinchen  2026-09-29: Read a world room's player key, name and auth key instead of its seats
//                            - Tested world rooms
//                            - Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  CHAT_LIMITS, CLOSE, EVERYONE, IN, LIMITS, REPLACED, RateLimiter, chatLineOf, newPeer, newWorldPeer, nextWorldDeadline,
  parseRoute, replacedBy, routeWorldMessage, seatChangeText, seatText, takeChatLine, takeMessage, takeSeat, worldOverdue,
} from "./relay.js";

/**
 * A world room's id as games make them.
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

test("parseRoute takes a world room with its name from the address and the player's key and auth key from the headers", () => {
  assert.deepEqual(
    parseRoute(new URL(`https://relay.test/v1/world/${ROOM}?name=Luka%20the%20Hero`), KEY, AUTH),
    { kind: "world", roomId: ROOM, player: KEY, name: "Luka the Hero", auth: AUTH },
  );
});

test("parseRoute refuses other versions, routes and ids, world rooms without key, name or auth, and keys in the address", () => {
  for (const [address, player, auth] of [
    [`https://relay.test/v2/world/${ROOM}?name=Luka`, KEY, AUTH],
    [`https://relay.test/v1/world/${ROOM.toUpperCase()}?name=Luka`, KEY, AUTH],
    [`https://relay.test/v1/world/${ROOM}0?name=Luka`, KEY, AUTH],
    [`https://relay.test/v1/world/${ROOM}/extra?name=Luka`, KEY, AUTH],
    [`https://relay.test/v1/room/${ROOM}?role=host`, KEY, AUTH],
    [`https://relay.test/v1/hall/${ROOM}?name=Luka`, KEY, AUTH],
    [`https://relay.test/v1/world/${ROOM}?name=Luka`, null, AUTH],
    [`https://relay.test/v1/world/${ROOM}?name=Luka`, KEY, null],
    [`https://relay.test/v1/world/${ROOM}`, KEY, AUTH],
    [`https://relay.test/v1/world/${ROOM}?name=%20%0A`, KEY, AUTH],
    [`https://relay.test/v1/world/${ROOM}?name=${"x".repeat(33)}`, KEY, AUTH],
    [`https://relay.test/v1/world/${ROOM}?name=Luka`, KEY.toUpperCase(), AUTH],
    [`https://relay.test/v1/world/${ROOM}?name=Luka`, KEY, "nope"],
    [`https://relay.test/v1/world/${ROOM}?player=${KEY}&name=Luka&auth=${AUTH}`, null, null],
  ]) {
    assert.ok("error" in parseRoute(new URL(address), player, auth), `${address} ${player} ${auth}`);
  }
});

test("takeMessage refuses a message larger than the limit", () => {
  const { refusal } = takeMessage(newPeer("player", T0), LIMITS.maxMessageBytes + 1, T0);

  assert.equal(refusal.code, CLOSE.tooLarge);
});

test("takeMessage allows a burst, then refuses until the allowance refills", () => {
  let peer = newPeer("player", T0);

  for (let sent = 0; sent < LIMITS.burst; sent++) {
    const result = takeMessage(peer, 100, T0);
    assert.equal(result.refusal, null);
    peer = result.peer;
  }

  assert.equal(takeMessage(peer, 100, T0).refusal.code, CLOSE.tooFast);
  assert.equal(takeMessage(peer, 100, T0 + 1000).refusal, null);
});

test("takeSeat gives the lowest free seat, and refuses once every seat is taken", () => {
  assert.equal(takeSeat([], 4).seat, 0);
  assert.equal(takeSeat([newWorldPeer(0, WHO, T0), newWorldPeer(2, WHO, T0)], 4).seat, 1);

  const full = [0, 1].map((seat) => newWorldPeer(seat, WHO, T0));
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
  const peers = [newWorldPeer(0, WHO, T0), newWorldPeer(1, WHO, T0 + 5000)];
  const closed = worldOverdue(peers, T0 + LIMITS.worldConnectionMs);

  assert.deepEqual(closed, [{ index: 0, code: CLOSE.connectionExpired, reason: "the connection lasted too long" }]);
  assert.deepEqual(worldOverdue(peers, T0 + LIMITS.worldConnectionMs - 1), []);
});

test("nextWorldDeadline names the oldest connection's end", () => {
  assert.equal(nextWorldDeadline([]), null);
  assert.equal(nextWorldDeadline([newWorldPeer(1, WHO, T0 + 5000), newWorldPeer(0, WHO, T0)]), T0 + LIMITS.worldConnectionMs);
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
