//----------------------------------------------------------------
//  trades.test.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Covered the sealed offers kept beside each trade: dropped once cancelled, moved out of older trades, listed and removed with the trade
//                            - Covered the limit on trades a player opened that ended cancelled within a day
//      Paulinchen  2026-10-07: Expected 404 for an unknown sub-route and 413 for a body the platform could not read whole
//      Paulinchen  2026-10-06: Covered the player's key in the X-MGQ-Player header
//                            - Created
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
 * @returns {Promise<{trades: TradeBook, time: {now: number}, records: Map, sealed: Map, ids: Record<string, string>}>} The trades, their clock, their records, the sealed offers kept beside them by `<trade>:<player id>` and the players' ids.
 */
async function newTrades(limits = TRADE_LIMITS) {
  const records = new Map();
  const sealed = new Map();
  const time = { now: 1_000_000 };
  const ids = { alice: await playerIdOf(ALICE), bob: await playerIdOf(BOB), carol: await playerIdOf(CAROL), stranger: await playerIdOf(STRANGER), banned: await playerIdOf(BANNED) };
  const world = { id: WORLD, members: { [ids.alice]: {}, [ids.bob]: {}, [ids.carol]: {} }, bans: [ids.banned] };
  const store = {
    getTrade: async (id) => (records.has(id) ? structuredClone(records.get(id)) : undefined),
    putTrade: async (record, { sealed: offers = {}, drop = [] } = {}) => {
      records.set(record.id, structuredClone(record));
      Object.entries(offers).forEach(([player, text]) => sealed.set(`${record.id}:${player}`, text));
      drop.forEach((player) => sealed.delete(`${record.id}:${player}`));
    },
    getSealed: async (id, player) => sealed.get(`${id}:${player}`),
    removeTrade: async (id, players = []) => {
      records.delete(id);
      players.forEach((player) => sealed.delete(`${id}:${player}`));
    },
    allTrades: async () => [...records.values()].map((record) => structuredClone(record)),
  };

  const trades = new TradeBook(store, async (id) => (id === WORLD ? structuredClone(world) : undefined), { clock: () => time.now, limits });
  return { trades, time, records, sealed, ids };
}

/**
 * Lists the sealed offers kept beside a trade.
 *
 * @param {Map} sealed The offers kept by `<trade>:<player id>`.
 * @param {string} trade The trade.
 * @returns {string[]} The keys of the trade's offers.
 */
function sealedKeysOf(sealed, trade) {
  return [...sealed.keys()].filter((key) => key.startsWith(`${trade}:`));
}

/**
 * Tells whether any trade record holds sealed offers in its commits.
 *
 * @param {Map} records The records.
 * @returns {boolean} Whether one does.
 */
function anyInlineSealed(records) {
  return [...records.values()].some((record) => Object.values(record.commits).some((commit) => "sealed" in commit));
}

/**
 * Makes a trade record as the relay kept it while the offers were part of it.
 *
 * @param {string} id The trade.
 * @param {Record<string, string>} ids The players' ids.
 * @param {object} fields The fields that differ from a pending trade Alice opened with Bob now.
 * @param {number} now The moment it was opened.
 * @returns {object} The record.
 */
function oldStyleRecord(id, ids, fields, now) {
  return { id, world: WORLD, players: [ids.alice, ids.bob], commits: { [ids.alice]: { hash: HASH, sealed: "b2xkQQ==" } }, state: "pending", created: now, updated: now, done: [], ...fields };
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

test("the offers are kept beside the trade, and a trade cancelled, expired or whose hashes differ keeps none", async () => {
  const { trades, time, ids, records, sealed } = await newTrades();

  await trades.commit(tradeId(1), commitOf(ALICE, ids.bob));
  assert.deepEqual(sealedKeysOf(sealed, tradeId(1)), [`${tradeId(1)}:${ids.alice}`]);
  await trades.cancel(tradeId(1), BOB);
  assert.deepEqual(sealedKeysOf(sealed, tradeId(1)), []);

  await trades.commit(tradeId(2), commitOf(ALICE, ids.bob));
  assert.deepEqual((await trades.commit(tradeId(2), commitOf(BOB, ids.alice, "22".repeat(32)))).body, { state: "cancelled", reason: "differ" });
  assert.deepEqual(sealedKeysOf(sealed, tradeId(2)), [], "the second player's offers are never kept");

  await trades.commit(tradeId(3), commitOf(ALICE, ids.bob));
  time.now += TRADE_LIMITS.pendingMs;
  assert.deepEqual((await trades.state(tradeId(3), ALICE)).body, { state: "cancelled", reason: "expired" });
  assert.deepEqual(sealedKeysOf(sealed, tradeId(3)), []);

  await trades.commit(tradeId(4), commitOf(ALICE, ids.bob));
  time.now += TRADE_LIMITS.pendingMs;
  await trades.pending(ALICE, WORLD);
  assert.equal(records.get(tradeId(4)).reason, "expired");
  assert.deepEqual(sealedKeysOf(sealed, tradeId(4)), [], "tidying an expired trade drops its offers too");
  assert.ok(!anyInlineSealed(records), "no record holds offers");
});

test("the same commit again is answered as before, and other offers under the same hash are refused", async () => {
  const { trades, ids, records } = await newTrades();

  await trades.commit(TRADE, commitOf(ALICE, ids.bob, HASH, "YWxpY2U="));
  assert.deepEqual(await trades.commit(TRADE, commitOf(ALICE, ids.bob, HASH, "YWxpY2U=")), { status: 200, body: { state: "pending" } });
  assert.equal((await trades.commit(TRADE, commitOf(ALICE, ids.bob, HASH, "b3RoZXI="))).status, 409);

  await trades.commit(TRADE, commitOf(BOB, ids.alice, HASH, "Ym9i"));
  assert.deepEqual(await trades.commit(TRADE, commitOf(ALICE, ids.bob, HASH, "YWxpY2U=")), { status: 200, body: { state: "committed" } });
  assert.deepEqual(await trades.commit(TRADE, commitOf(BOB, ids.alice, HASH, "Ym9i")), { status: 200, body: { state: "committed" } });
  assert.equal((await trades.commit(TRADE, commitOf(BOB, ids.alice, HASH, "b3RoZXI="))).status, 409);
  assert.ok(!anyInlineSealed(records));
});

test("a trade kept while its offers were part of it is still committed and listed, and tidying moves its offers out", async () => {
  const { trades, time, ids, records, sealed } = await newTrades();

  records.set(tradeId(1), oldStyleRecord(tradeId(1), ids, {}, time.now));
  assert.deepEqual((await trades.commit(tradeId(1), commitOf(BOB, ids.alice, HASH, "Ym9i"))).body, { state: "committed" });
  assert.equal(records.get(tradeId(1)).commits[ids.alice].sealed, "b2xkQQ==", "the first commit keeps its offers until a tidy");
  assert.deepEqual(await trades.commit(tradeId(1), commitOf(ALICE, ids.bob, HASH, "b2xkQQ==")), { status: 200, body: { state: "committed" } });

  const both = { [ids.alice]: { hash: HASH, sealed: "b2xkQQ==" }, [ids.bob]: { hash: HASH, sealed: "b2xkQg==" } };
  records.set(tradeId(2), oldStyleRecord(tradeId(2), ids, { commits: both, state: "committed", committed: time.now + 1 }, time.now));
  records.set(tradeId(3), oldStyleRecord(tradeId(3), ids, { state: "cancelled", reason: "cancelled" }, time.now));

  assert.deepEqual((await trades.pending(ALICE, WORLD)).body, { trades: [{ id: tradeId(1), hash: HASH, sealed: "b2xkQQ==" }, { id: tradeId(2), hash: HASH, sealed: "b2xkQQ==" }] });
  assert.deepEqual((await trades.pending(BOB, WORLD)).body, { trades: [{ id: tradeId(1), hash: HASH, sealed: "Ym9i" }, { id: tradeId(2), hash: HASH, sealed: "b2xkQg==" }] });
  assert.ok(!anyInlineSealed(records), "the tidy moved every offer out of the records");
  assert.equal(sealed.get(`${tradeId(2)}:${ids.alice}`), "b2xkQQ==");
  assert.equal(sealed.get(`${tradeId(2)}:${ids.bob}`), "b2xkQg==");
  assert.deepEqual(sealedKeysOf(sealed, tradeId(3)), [], "a cancelled trade's offers are dropped, not moved");

  records.set(tradeId(4), oldStyleRecord(tradeId(4), ids, {}, time.now));
  time.now += TRADE_LIMITS.pendingMs;
  assert.deepEqual((await trades.state(tradeId(4), ALICE)).body, { state: "cancelled", reason: "expired" });
  assert.ok(!("sealed" in records.get(tradeId(4)).commits[ids.alice]), "an expired trade loses its offers");
});

test("a trade both players marked done and a trade kept long enough take their offers with them", async () => {
  const { trades, time, ids, records, sealed } = await newTrades();

  await trades.commit(tradeId(1), commitOf(ALICE, ids.bob));
  await trades.commit(tradeId(1), commitOf(BOB, ids.alice));
  await trades.done(tradeId(1), ALICE);
  assert.equal(sealedKeysOf(sealed, tradeId(1)).length, 2, "the offers stay until both are done");
  await trades.done(tradeId(1), BOB);
  assert.deepEqual(sealedKeysOf(sealed, tradeId(1)), []);

  await trades.commit(tradeId(2), commitOf(ALICE, ids.bob));
  await trades.commit(tradeId(2), commitOf(BOB, ids.alice));
  time.now += TRADE_LIMITS.keepCommittedMs;
  await trades.pending(ALICE, WORLD);
  assert.equal(records.size, 0);
  assert.equal(sealed.size, 0);
});

test("a player who opened so many trades within a day that ended cancelled opens no more until the day passed", async () => {
  const { trades, time, ids } = await newTrades({ ...TRADE_LIMITS, maxCancelledPerPlayer: 2 });

  await trades.commit(tradeId(1), commitOf(ALICE, ids.bob));
  await trades.cancel(tradeId(1), ALICE);
  await trades.commit(tradeId(2), commitOf(ALICE, ids.bob));
  await trades.commit(tradeId(2), commitOf(BOB, ids.alice, "22".repeat(32)));

  const refused = await trades.commit(tradeId(3), commitOf(ALICE, ids.carol));
  assert.equal(refused.status, 429);
  assert.match(refused.body.error, /at most 2 trades a day/);
  assert.equal((await trades.commit(tradeId(4), commitOf(BOB, ids.alice))).status, 200, "the trades count against the player who opened them");

  time.now += TRADE_LIMITS.keepCancelledMs;
  assert.equal((await trades.commit(tradeId(3), commitOf(ALICE, ids.carol))).status, 200);
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
  assert.equal((await ask("DELETE", `/v1/trades/${TRADE}`)).status, 404);
  assert.equal((await ask("POST", `/v1/trades/${TRADE}/elsewhere`, {})).status, 404);
  assert.equal((await handleTradeRequest(trades, "POST", new URL(`https://relay/v1/trades/${tradeId(6)}/commit`), async () => null)).status, 413, "a body the platform could not read whole is too large too");
});

test("the routes take the player's key from the X-MGQ-Player header before the body or the address", async () => {
  const { trades, ids } = await newTrades();
  const ask = (method, path, body, player) => handleTradeRequest(trades, method, new URL(`https://relay${path}`), async () => (body === undefined ? "" : JSON.stringify(body)), player);
  const { player: _alice, ...aliceCommit } = commitOf(ALICE, ids.bob);
  const { player: _bob, ...bobCommit } = commitOf(BOB, ids.alice);

  assert.deepEqual((await ask("POST", `/v1/trades/${TRADE}/commit`, aliceCommit, ALICE)).body, { state: "pending" });
  assert.deepEqual((await ask("POST", `/v1/trades/${TRADE}/commit`, { ...bobCommit, player: STRANGER }, BOB)).body, { state: "committed" });
  assert.deepEqual((await ask("GET", `/v1/trades/${TRADE}`, undefined, ALICE)).body, { state: "committed" });
  assert.equal((await ask("GET", `/v1/trades?world=${WORLD}`, undefined, BOB)).body.trades.length, 1);
  assert.equal((await ask("GET", `/v1/trades/${TRADE}?player=${STRANGER}`, undefined, ALICE)).status, 200);
});
