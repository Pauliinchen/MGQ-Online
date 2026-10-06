//----------------------------------------------------------------
//  trades.test.js
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { playerIdOf } from "./directory.js";
import { TRADE_LIMITS, TradeBook, handleTradeRequest } from "./trades.js";

/**
 * The first player's key.
 */
const ALICE = "a1".repeat(16);

/**
 * The second player's key.
 */
const BOB = "b2".repeat(16);

/**
 * A third player's key, a player of the world too.
 */
const CAROL = "c3".repeat(16);

/**
 * A key of someone who never was in the world.
 */
const STRANGER = "d4".repeat(16);

/**
 * A key of a player the creator removed from the world.
 */
const BANNED = "e5".repeat(16);

/**
 * The test world's id.
 */
const WORLD = "0123456789abcdef0123456789abcdef";

/**
 * The test trade's id.
 */
const TRADE = "fedcba9876543210fedcba9876543210";

/**
 * A hash both games agree on.
 */
const HASH = "11".repeat(32);

/**
 * Makes a trade id unique to a number.
 *
 * @param {number} number The number.
 * @returns {string} The id.
 */
function tradeId(number) {
  return number.toString(16).padStart(32, "0");
}

/**
 * Makes trades over a store in memory, with one world whose players are Alice, Bob and Carol, and a clock the tests move.
 *
 * @param {object} [limits] The limits.
 * @returns {Promise<{trades: TradeBook, time: {now: number}, records: Map, ids: Record<string, string>}>} The trades, their clock, their records and the players' ids.
 */
async function newTrades(limits = TRADE_LIMITS) {
  const records = new Map();
  const time = { now: 1_000_000 };
  const ids = { alice: await playerIdOf(ALICE), bob: await playerIdOf(BOB), carol: await playerIdOf(CAROL), stranger: await playerIdOf(STRANGER), banned: await playerIdOf(BANNED) };
  const world = { id: WORLD, members: { [ids.alice]: {}, [ids.bob]: {}, [ids.carol]: {} }, bans: [ids.banned] };
  const store = {
    getTrade: async (id) => (records.has(id) ? structuredClone(records.get(id)) : undefined),
    putTrade: async (record) => void records.set(record.id, structuredClone(record)),
    removeTrade: async (id) => void records.delete(id),
    allTrades: async () => [...records.values()].map((record) => structuredClone(record)),
  };

  const trades = new TradeBook(store, async (id) => (id === WORLD ? structuredClone(world) : undefined), { clock: () => time.now, limits });
  return { trades, time, records, ids };
}

/**
 * Makes a commit's body.
 *
 * @param {string} player The committing player's key.
 * @param {string} partner The other player's id.
 * @param {string} [hash] The hash.
 * @param {string} [sealed] The sealed offers.
 * @returns {object} The body.
 */
function commitOf(player, partner, hash = HASH, sealed = "c2VhbGVk") {
  return { player, world: WORLD, partner, hash, sealed };
}

test("the second commit with the same hash commits the trade, and committing again changes nothing", async () => {
  const { trades, ids } = await newTrades();

  assert.deepEqual(await trades.commit(TRADE, commitOf(ALICE, ids.bob)), { status: 200, body: { state: "pending" } });
  assert.deepEqual(await trades.commit(TRADE, commitOf(ALICE, ids.bob)), { status: 200, body: { state: "pending" } });
  assert.deepEqual((await trades.state(TRADE, BOB)).body, { state: "pending" });

  assert.deepEqual(await trades.commit(TRADE, commitOf(BOB, ids.alice, HASH, "b3RoZXI=")), { status: 200, body: { state: "committed" } });
  assert.deepEqual(await trades.commit(TRADE, commitOf(ALICE, ids.bob)), { status: 200, body: { state: "committed" } });
  assert.deepEqual((await trades.state(TRADE, ALICE)).body, { state: "committed" });
  assert.equal((await trades.commit(TRADE, commitOf(ALICE, ids.bob, "22".repeat(32)))).status, 409);
});

test("both commits arriving at once still commit the trade exactly once", async () => {
  const { trades, ids, records } = await newTrades();

  const answers = await Promise.all([trades.commit(TRADE, commitOf(ALICE, ids.bob)), trades.commit(TRADE, commitOf(BOB, ids.alice))]);

  assert.deepEqual(answers.map((answer) => answer.body.state).sort(), ["committed", "pending"]);
  assert.equal(records.get(TRADE).state, "committed");
  assert.deepEqual(Object.keys(records.get(TRADE).commits).sort(), [ids.alice, ids.bob].sort());
});

test("different hashes cancel the trade, which stays cancelled", async () => {
  const { trades, ids } = await newTrades();

  await trades.commit(TRADE, commitOf(ALICE, ids.bob));
  assert.deepEqual((await trades.commit(TRADE, commitOf(BOB, ids.alice, "22".repeat(32)))).body, { state: "cancelled", reason: "differ" });
  assert.deepEqual((await trades.commit(TRADE, commitOf(BOB, ids.alice))).body, { state: "cancelled", reason: "differ" });
  assert.deepEqual((await trades.state(TRADE, ALICE)).body, { state: "cancelled", reason: "differ" });
});

test("either player cancels a pending trade, but a committed one stays committed", async () => {
  const { trades, ids } = await newTrades();

  await trades.commit(tradeId(1), commitOf(ALICE, ids.bob));
  assert.deepEqual(await trades.cancel(tradeId(1), BOB), { status: 200, body: { state: "cancelled", reason: "cancelled" } });
  assert.deepEqual((await trades.commit(tradeId(1), commitOf(BOB, ids.alice))).body, { state: "cancelled", reason: "cancelled" });

  await trades.commit(tradeId(2), commitOf(ALICE, ids.bob));
  await trades.commit(tradeId(2), commitOf(BOB, ids.alice));
  assert.deepEqual(await trades.cancel(tradeId(2), ALICE), { status: 200, body: { state: "committed" } });

  assert.equal((await trades.cancel(tradeId(2), CAROL)).status, 404);
  assert.equal((await trades.cancel(tradeId(3), ALICE)).status, 404);
});

test("a trade left pending for two minutes reads as expired, and a late commit no longer commits it", async () => {
  const { trades, time, ids, records } = await newTrades();

  await trades.commit(TRADE, commitOf(ALICE, ids.bob));
  time.now += TRADE_LIMITS.pendingMs - 1;
  assert.deepEqual((await trades.state(TRADE, ALICE)).body, { state: "pending" });

  time.now += 1;
  assert.deepEqual((await trades.state(TRADE, BOB)).body, { state: "cancelled", reason: "expired" });
  assert.equal(records.get(TRADE).reason, "expired");
  assert.deepEqual((await trades.commit(TRADE, commitOf(BOB, ids.alice))).body, { state: "cancelled", reason: "expired" });
});

test("only the trade's two players read it", async () => {
  const { trades, ids } = await newTrades();

  await trades.commit(TRADE, commitOf(ALICE, ids.bob));
  assert.equal((await trades.state(TRADE, CAROL)).status, 404);
  assert.equal((await trades.state(tradeId(9), ALICE)).status, 404);
  assert.equal((await trades.state(TRADE, "nope")).status, 400);
});

test("both players must be players of the world, not removed from it", async () => {
  const { trades, ids } = await newTrades();

  assert.equal((await trades.commit(tradeId(1), commitOf(STRANGER, ids.bob))).status, 403);
  assert.equal((await trades.commit(tradeId(2), commitOf(ALICE, ids.stranger))).status, 403);
  assert.equal((await trades.commit(tradeId(3), commitOf(ALICE, ids.banned))).status, 403);
  assert.equal((await trades.commit(tradeId(4), commitOf(ALICE, ids.alice))).status, 400);
  assert.equal((await trades.commit(tradeId(5), { ...commitOf(ALICE, ids.bob), world: "9".repeat(32) })).status, 404);
});

test("a commit naming another world or partner than the trade's is refused", async () => {
  const { trades, ids } = await newTrades();

  await trades.commit(TRADE, commitOf(ALICE, ids.bob));
  assert.equal((await trades.commit(TRADE, commitOf(CAROL, ids.alice))).status, 409);
  assert.equal((await trades.commit(TRADE, commitOf(BOB, ids.carol))).status, 409);
  assert.equal((await trades.commit(TRADE, commitOf(ALICE, ids.bob, "22".repeat(32)))).status, 409);
});

test("a commit's fields are checked, and sealed offers past the limit are refused as too large", async () => {
  const { trades, ids } = await newTrades();

  assert.equal((await trades.commit("nope", commitOf(ALICE, ids.bob))).status, 400);
  assert.equal((await trades.commit(TRADE, null)).status, 400);
  assert.equal((await trades.commit(TRADE, commitOf(ALICE, ids.bob, "XY"))).status, 400);
  assert.equal((await trades.commit(TRADE, commitOf(ALICE, ids.bob, HASH, "not base64!"))).status, 400);
  assert.equal((await trades.commit(TRADE, commitOf(ALICE, ids.bob, HASH, "A".repeat(TRADE_LIMITS.maxSealedLength + 4)))).status, 413);
  assert.equal((await trades.commit(TRADE, commitOf(ALICE, ids.bob, HASH, "A".repeat(TRADE_LIMITS.maxSealedLength)))).status, 200);
});

test("a player's committed trades not yet done are listed with the offers they sealed, and deleted once both are done", async () => {
  const { trades, ids, records } = await newTrades();

  await trades.commit(TRADE, commitOf(ALICE, ids.bob, HASH, "YWxpY2U="));
  assert.deepEqual((await trades.pending(ALICE, WORLD)).body, { trades: [] });

  await trades.commit(TRADE, commitOf(BOB, ids.alice, HASH, "Ym9i"));
  assert.deepEqual((await trades.pending(ALICE, WORLD)).body, { trades: [{ id: TRADE, hash: HASH, sealed: "YWxpY2U=" }] });
  assert.deepEqual((await trades.pending(BOB, WORLD)).body, { trades: [{ id: TRADE, hash: HASH, sealed: "Ym9i" }] });
  assert.deepEqual((await trades.pending(CAROL, WORLD)).body, { trades: [] });
  assert.deepEqual((await trades.pending(ALICE, "9".repeat(32))).body, { trades: [] });

  assert.deepEqual(await trades.done(TRADE, ALICE), { status: 200, body: { state: "committed" } });
  assert.deepEqual(await trades.done(TRADE, ALICE), { status: 200, body: { state: "committed" } });
  assert.deepEqual((await trades.pending(ALICE, WORLD)).body, { trades: [] });
  assert.equal((await trades.pending(BOB, WORLD)).body.trades.length, 1);
  assert.ok(records.has(TRADE));

  await trades.done(TRADE, BOB);
  assert.ok(!records.has(TRADE));
  assert.equal((await trades.done(TRADE, BOB)).status, 404);
});

test("only a committed trade is marked done", async () => {
  const { trades, ids } = await newTrades();

  await trades.commit(TRADE, commitOf(ALICE, ids.bob));
  assert.equal((await trades.done(TRADE, ALICE)).status, 409);
  assert.equal((await trades.done(TRADE, CAROL)).status, 404);
});

test("committed trades nobody finished are dropped after 30 days, cancelled ones after a day", async () => {
  const { trades, time, ids, records } = await newTrades();

  await trades.commit(tradeId(1), commitOf(ALICE, ids.bob));
  await trades.commit(tradeId(1), commitOf(BOB, ids.alice));
  await trades.commit(tradeId(2), commitOf(ALICE, ids.bob));
  await trades.cancel(tradeId(2), ALICE);

  time.now += TRADE_LIMITS.keepCancelledMs;
  await trades.pending(ALICE, WORLD);
  assert.deepEqual([...records.keys()], [tradeId(1)]);

  time.now += TRADE_LIMITS.keepCommittedMs;
  await trades.pending(ALICE, WORLD);
  assert.equal(records.size, 0);
});

test("a player has at most so many open trades at once", async () => {
  const { trades, ids } = await newTrades({ ...TRADE_LIMITS, maxOpenPerPlayer: 2 });

  assert.equal((await trades.commit(tradeId(1), commitOf(ALICE, ids.bob))).status, 200);
  assert.equal((await trades.commit(tradeId(2), commitOf(ALICE, ids.carol))).status, 200);
  assert.equal((await trades.commit(tradeId(3), commitOf(ALICE, ids.bob))).status, 429);
  assert.equal((await trades.commit(tradeId(1), commitOf(BOB, ids.alice))).status, 200);

  await trades.cancel(tradeId(2), ALICE);
  assert.equal((await trades.commit(tradeId(4), commitOf(ALICE, ids.carol))).status, 200);
  assert.equal((await trades.commit(tradeId(5), commitOf(ALICE, ids.carol))).status, 429);
  await trades.done(tradeId(1), ALICE);
  assert.equal((await trades.commit(tradeId(5), commitOf(ALICE, ids.carol))).status, 200);
});

test("the routes reach the trades, and a body past the limit is refused", async () => {
  const { trades, ids } = await newTrades();
  const ask = (method, path, body) => handleTradeRequest(trades, method, new URL(`https://relay${path}`), async () => (body === undefined ? "" : typeof body === "string" ? body : JSON.stringify(body)));

  assert.deepEqual((await ask("POST", `/v1/trades/${TRADE}/commit`, commitOf(ALICE, ids.bob))).body, { state: "pending" });
  assert.deepEqual((await ask("POST", `/v1/trades/${TRADE}/commit`, commitOf(BOB, ids.alice))).body, { state: "committed" });
  assert.deepEqual((await ask("GET", `/v1/trades/${TRADE}?player=${ALICE}`)).body, { state: "committed" });
  assert.equal((await ask("GET", `/v1/trades?player=${BOB}&world=${WORLD}`)).body.trades.length, 1);
  assert.deepEqual((await ask("POST", `/v1/trades/${TRADE}/done`, { player: BOB })).body, { state: "committed" });
  assert.deepEqual((await ask("POST", `/v1/trades/${TRADE}/cancel`, { player: ALICE })).body, { state: "committed" });
  assert.equal((await ask("POST", `/v1/trades/${tradeId(5)}/commit`, "x".repeat(TRADE_LIMITS.maxBodyLength + 1))).status, 413);
  assert.equal((await ask("POST", `/v1/trades/${tradeId(5)}/commit`, "no json")).status, 400);
  assert.equal((await ask("DELETE", `/v1/trades/${TRADE}`)).status, 405);
});
