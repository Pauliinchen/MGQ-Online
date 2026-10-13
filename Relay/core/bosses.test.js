//----------------------------------------------------------------
//  bosses.test.js
//
//  Changelog:
//      Paulinchen  2026-10-10: Covered boss pools that keep the share of a raid max HP left
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { BOSS_LIMITS, WorldBosses, bossRouteOf, bossText, handleBossRequest, leftOf, readKey } from "./bosses.js";
import { WORLD_TYPE } from "./directory.js";
import { handleRaidAdminRequest, raidAdminRouteOf } from "./raid_admin.js";
import { STORY_LIMITS, WorldStory } from "./story.js";

/**
 * A player's id.
 */
const ALICE = "a1".repeat(16);

/**
 * Another player's id.
 */
const BOB = "b2".repeat(16);

/**
 * A world's id.
 */
const WORLD = "0123456789abcdef0123456789abcdef";

/**
 * A minute in milliseconds.
 */
const MINUTE = 60_000;

/**
 * The raid max HP the tests' games name.
 */
const MAX = 5_000_000;

/**
 * Makes boss pools over a store in memory, with a clock the tests move.
 *
 * @param {object} [limits] The limits.
 * @returns {{bosses: WorldBosses, kept: {pools: Map<string, object>, puts: number}, time: {now: number}}} The pools, what their store keeps and how often it wrote, and their clock.
 */
function makeBosses(limits = { ...BOSS_LIMITS, reports: { burst: 1000, refillMs: 1 } }) {
  const kept = { pools: new Map(), puts: 0 };
  const time = { now: 1_000_000 };
  const store = {
    get: async (key) => structuredClone(kept.pools.get(key)),
    put: async (pool) => {
      kept.puts++;
      kept.pools.set(pool.key, structuredClone(pool));
    },
    all: async () => [...kept.pools.values()].map((pool) => structuredClone(pool)),
    remove: async (key) => void kept.pools.delete(key),
    removeAll: async () => kept.pools.clear(),
  };

  return { bosses: new WorldBosses(store, { clock: () => time.now, limits }), kept, time };
}

/**
 * Reports a battle's turn and expects it taken.
 *
 * @param {WorldBosses} bosses The pools.
 * @param {string} key The boss.
 * @param {object} report The report's fields over a first report of battle b1 that takes nothing off.
 * @param {string} [player] The reporting player's id.
 * @param {string | null} [name] The reporting player's name.
 * @returns {Promise<{status: number, body: object, boss?: object}>} The answer.
 */
async function reported(bosses, key, report, player = ALICE, name = "Luka") {
  const answer = await bosses.report(player, encodeURIComponent(key), { battle: "b1", seq: 1, delta: 0, max: MAX, killed: false, ...report }, name);
  assert.equal(answer.status, 200, JSON.stringify(answer.body));
  return answer;
}

test("a boss nobody reported is full with no max yet, and the list holds only the pools a report touched", async () => {
  const { bosses } = makeBosses();
  assert.deepEqual((await bosses.get("Queen%20Harpy")).body, { key: "Queen Harpy", left: 1, max: null, defeated: false, at: null, by: null });
  assert.deepEqual((await bosses.list()).body, { bosses: [], regenPerMinute: 0.03 });

  await reported(bosses, "Morrigan", { delta: 0.5 });
  await reported(bosses, "Adramelech#1", { battle: "b2", delta: 0.25 });
  assert.deepEqual((await bosses.list()).body.bosses.map((pool) => [pool.key, pool.left, pool.max]), [["Adramelech#1", 0.75, MAX], ["Morrigan", 0.5, MAX]]);
});

test("a report takes its share off the pool, the first report's max stays, and every game hears the pool", async () => {
  const { bosses, time } = makeBosses();
  const first = await reported(bosses, "Morrigan", { delta: 0.4 });
  assert.deepEqual(first.body, { boss: { key: "Morrigan", left: 0.6, max: MAX, defeated: false, at: time.now, by: null }, repeat: false });
  assert.deepEqual(first.boss, { key: "Morrigan", left: 0.6, max: MAX, defeated: false });

  const other = await reported(bosses, "Morrigan", { battle: "b2", delta: 0.1, max: 123.4 });
  assert.equal(other.body.boss.max, MAX, "a later game's max never changes the pool's");
  assert.ok(Math.abs(other.body.boss.left - 0.5) < 1e-12);

  const fresh = await reported(bosses, "Lilith", { max: 2.6 });
  assert.equal(fresh.body.boss.max, 3, "the max is kept as a whole number");
});

test("healing gives the share back up to full, and a report that takes nothing off writes nothing", async () => {
  const { bosses, kept } = makeBosses();
  await reported(bosses, "Morrigan", { delta: 0.3 });
  const healed = await reported(bosses, "Morrigan", { seq: 2, delta: -0.1 });
  assert.ok(Math.abs(healed.body.boss.left - 0.8) < 1e-12);
  assert.equal((await reported(bosses, "Morrigan", { seq: 3, delta: -1 })).body.boss.left, 1);

  const puts = kept.puts;
  const idle = await reported(bosses, "Morrigan", { seq: 4, delta: 0 });
  assert.deepEqual([idle.boss, kept.puts], [undefined, puts]);
});

test("a battle's report number counts once: a report sent again or an older one changes nothing", async () => {
  const { bosses, kept } = makeBosses();
  await reported(bosses, "Morrigan", { seq: 5, delta: 0.25 });
  const puts = kept.puts;

  const again = await reported(bosses, "Morrigan", { seq: 5, delta: 0.25 });
  assert.deepEqual([again.body.boss.left, again.body.repeat, again.boss], [0.75, true, undefined]);
  assert.equal((await reported(bosses, "Morrigan", { seq: 4, delta: 0.25 })).body.repeat, true);
  assert.equal(kept.puts, puts);

  assert.equal((await reported(bosses, "Morrigan", { seq: 6, delta: 0.25 })).body.boss.left, 0.5);
  assert.equal((await reported(bosses, "Morrigan", { battle: "b2", seq: 1, delta: 0.25 })).body.boss.left, 0.25, "another battle counts its own numbers");
});

test("a pool fills up by 3 percent a minute, also between a fight's reports, never past full", async () => {
  const { bosses, time } = makeBosses();
  await reported(bosses, "Morrigan", { delta: 0.9 });

  time.now += 10 * MINUTE;
  assert.ok(Math.abs((await bosses.get("Morrigan")).body.left - 0.4) < 1e-12);

  const after = await reported(bosses, "Morrigan", { seq: 2, delta: 0.2 });
  assert.ok(Math.abs(after.body.boss.left - 0.2) < 1e-12, "a report counts from the pool as it stands now");

  time.now += 60 * MINUTE;
  assert.equal((await bosses.get("Morrigan")).body.left, 1);
  assert.equal(leftOf({ left: 0.5, at: 0, defeated: false }, MINUTE / 2), 0.515);
});

test("a kill empties the pool and defeats the boss for good, named by its player", async () => {
  const { bosses, kept, time } = makeBosses();
  await reported(bosses, "Lilith", { delta: 0.2 });

  const killed = await reported(bosses, "Lilith", { battle: "b2", killed: true }, BOB, "Alice");
  assert.deepEqual(killed.body.boss, { key: "Lilith", left: 0, max: MAX, defeated: true, at: time.now, by: "Alice" });
  assert.deepEqual(killed.boss, { key: "Lilith", left: 0, max: MAX, defeated: true });
  assert.equal(kept.pools.get("Lilith").byPlayer, BOB);

  const puts = kept.puts;
  const late = await reported(bosses, "Lilith", { seq: 2, delta: -0.5, killed: true });
  assert.deepEqual([late.body.boss.left, late.body.boss.defeated, late.body.repeat, late.boss], [0, true, false, undefined]);
  assert.equal(kept.puts, puts, "a report on a defeated boss writes nothing");

  time.now += 600 * MINUTE;
  assert.deepEqual([(await bosses.get("Lilith")).body.left, (await bosses.get("Lilith")).body.defeated], [0, true], "a defeated boss never fills up");
});

test("taking the last of the pool off defeats the boss, even with float leftovers, and never goes below 0", async () => {
  const { bosses } = makeBosses();
  await reported(bosses, "Lilith", { delta: 0.7 });
  const emptied = await reported(bosses, "Lilith", { seq: 2, delta: 0.3 - 1e-8 });
  assert.deepEqual([emptied.body.boss.left, emptied.body.boss.defeated, emptied.body.boss.by], [0, true, "Luka"]);

  await reported(bosses, "Morrigan", { delta: 1, killed: 0 });
  assert.equal((await bosses.get("Morrigan")).body.defeated, true, "a whole share off defeats without a kill");

  const almost = await reported(bosses, "Alma Elma", { delta: 0.9999 });
  assert.deepEqual([almost.body.boss.defeated, Math.round(almost.body.boss.left * MAX)], [false, 500]);
});

test("pools kept in kills before the shared HP read as never reported and are replaced by the next report", async () => {
  const { bosses, kept } = makeBosses({ ...BOSS_LIMITS, maxPools: 1, reports: { burst: 1000, refillMs: 1 } });
  kept.pools.set("Lilith", { key: "Lilith", hp: 0, max: 5, regen: 5, at: 0, defeated: true, emptiedBy: "b1", by: ALICE, battles: ["b1"], reports: 5 });

  assert.deepEqual([(await bosses.get("Lilith")).body.left, (await bosses.get("Lilith")).body.defeated], [1, false]);
  assert.deepEqual((await bosses.list()).body.bosses, []);
  const report = await reported(bosses, "Lilith", { delta: 0.5 });
  assert.deepEqual([report.body.boss.left, report.body.boss.max], [0.5, MAX]);
});

test("a wrong report is refused before it counts against the player's reports, and each player has reports of their own", async () => {
  const { bosses } = makeBosses({ ...BOSS_LIMITS, reports: { burst: 1, refillMs: 60_000 } });
  const valid = { battle: "b1", seq: 1, delta: 0.1, max: MAX, killed: false };
  const refused = async (body) => (await bosses.report(ALICE, "Morrigan", body)).status;

  assert.equal(await refused(null), 400);
  assert.equal(await refused([valid]), 400);
  assert.equal(await refused({ battle: "b1", dealt: 1 }), 400, "a report in kills is refused");
  assert.equal(await refused({ ...valid, battle: "" }), 400);
  assert.equal(await refused({ ...valid, battle: "a b" }), 400);
  assert.equal(await refused({ ...valid, battle: "x".repeat(65) }), 400);
  assert.equal(await refused({ ...valid, seq: -1 }), 400);
  assert.equal(await refused({ ...valid, seq: 1.5 }), 400);
  assert.equal(await refused({ ...valid, seq: "1" }), 400);
  assert.equal(await refused({ ...valid, delta: 1.01 }), 400);
  assert.equal(await refused({ ...valid, delta: -1.01 }), 400);
  assert.equal(await refused({ ...valid, delta: Number.NaN }), 400);
  assert.equal(await refused({ ...valid, delta: "0.1" }), 400);
  assert.equal(await refused({ ...valid, max: 0 }), 400);
  assert.equal(await refused({ ...valid, max: 2e18 }), 400);
  assert.equal(await refused({ ...valid, max: Number.POSITIVE_INFINITY }), 400);
  assert.equal(await refused({ ...valid, max: undefined }), 400);
  assert.equal(await refused({ ...valid, killed: "yes" }), 400);
  assert.equal((await bosses.report(ALICE, "%20Morrigan", valid)).status, 400);

  assert.equal(await refused({ ...valid, max: 1e18, killed: undefined }), 200);
  const tooOften = await bosses.report(ALICE, "Morrigan", { ...valid, seq: 2 });
  assert.deepEqual([tooOften.status, tooOften.body.code], [429, "rate"]);
  assert.equal((await bosses.report(BOB, "Morrigan", { ...valid, battle: "b3" })).status, 200);
});

test("a player may report each pool every turn: a burst of 30, then two a second", async () => {
  const { bosses, time } = makeBosses(BOSS_LIMITS);
  const turn = (seq) => bosses.report(ALICE, "Morrigan", { battle: "b1", seq, delta: 0.001, max: MAX });

  for (let seq = 1; seq <= 30; seq++) {
    assert.equal((await turn(seq)).status, 200);
  }

  assert.equal((await turn(31)).status, 429);
  time.now += 500;
  assert.equal((await turn(31)).status, 200);
});

test("a world keeps a limited number of pools and remembers a limited number of battles each", async () => {
  const { bosses, kept } = makeBosses({ ...BOSS_LIMITS, maxPools: 2, recentBattles: 2, reports: { burst: 1000, refillMs: 1 } });
  await reported(bosses, "One", { delta: 0.1 });
  await reported(bosses, "Two", { delta: 0.1 });
  const full = await bosses.report(ALICE, "Three", { battle: "b3", seq: 1, delta: 0.1, max: MAX });
  assert.deepEqual([full.status, full.body.code], [413, "full"]);

  await reported(bosses, "One", { battle: "b4", delta: 0.1 });
  await reported(bosses, "One", { battle: "b5", delta: 0.1 });
  await reported(bosses, "One", { battle: "b4", seq: 2, delta: 0.1 });
  assert.deepEqual(kept.pools.get("One").battles, [{ id: "b5", seq: 1 }, { id: "b4", seq: 2 }]);
});

test("boss keys are read percent-decoded, a troop member's index after # included, and keys that are none are refused", () => {
  assert.equal(readKey("Alma%20Elma%2C%20then%20Granberia"), "Alma Elma, then Granberia");
  assert.equal(readKey("Four%20Heavenly%20Knights%230"), "Four Heavenly Knights#0");
  assert.equal(readKey(encodeURIComponent(`${"x".repeat(64)}#12`)), `${"x".repeat(64)}#12`);
  assert.equal(readKey("1507"), "1507");
  assert.equal(readKey(encodeURIComponent("アリス")), "アリス");
  assert.equal(readKey(""), null);
  assert.equal(readKey("%E0%A4%A"), null);
  assert.equal(readKey("a%09b"), null);
  assert.equal(readKey("x".repeat(73)), null);
  assert.equal(readKey(undefined), null);
});

test("an admin's reset deletes a pool, which fills it up and takes its defeat back, and removing forgets every pool", async () => {
  const { bosses } = makeBosses();
  await reported(bosses, "Lilith", { killed: true });
  assert.equal((await bosses.get("Lilith")).body.defeated, true);

  const reset = await bosses.reset("Lilith");
  assert.deepEqual([reset.body.left, reset.body.defeated, reset.body.reset], [1, false, true]);
  assert.deepEqual(reset.boss, { key: "Lilith", left: 1, max: MAX, defeated: false });
  assert.deepEqual((await bosses.get("Lilith")).body, { key: "Lilith", left: 1, max: null, defeated: false, at: null, by: null });

  const untouched = await bosses.reset("Morrigan");
  assert.deepEqual([untouched.body.reset, untouched.boss], [false, undefined]);
  assert.equal((await bosses.reset("%20")).status, 400);

  await reported(bosses, "Morrigan", { delta: 0.5 });
  await bosses.remove();
  assert.deepEqual((await bosses.list()).body.bosses, []);
});

test("the frame names the share left to six decimals, the max as a whole number and the defeat, with the key last", () => {
  assert.equal(bossText("Alma Elma, then Granberia", 0.25, 5_000_000, false), "boss 0.25 5000000 0 Alma Elma, then Granberia");
  assert.equal(bossText("Lilith#2", 2 / 3, 1e18, false), "boss 0.666667 1000000000000000000 0 Lilith#2");
  assert.equal(bossText("Lilith", 0, 3, true), "boss 0 3 1 Lilith");
  assert.equal(bossText("Lilith", 1, 3, false), "boss 1 3 0 Lilith");
  assert.equal(bossText("Lilith", 0.0000004, 2.4e12, false), "boss 0.000001 2400000000000 0 Lilith");
  assert.equal(bossText("Lilith", 0.0000004, 2.4e12, true), "boss 0 2400000000000 1 Lilith");
});

test("the routes are read from the address, and the router answers each", async () => {
  assert.deepEqual(bossRouteOf(new URL(`https://relay/v1/worlds/${WORLD}/bosses`)), { id: WORLD, rest: [] });
  assert.deepEqual(bossRouteOf(new URL(`https://relay/v1/worlds/${WORLD}/bosses/Queen%20Harpy%231/report`)).rest, ["Queen%20Harpy%231", "report"]);
  assert.equal(bossRouteOf(new URL(`https://relay/v1/worlds/${WORLD}/story`)), null);
  assert.equal(bossRouteOf(new URL("https://relay/v1/worlds/XYZ/bosses")), null);
  assert.deepEqual(raidAdminRouteOf(new URL(`https://relay/v1/worlds/${WORLD}/raid/route/clear`)), { id: WORLD, rest: ["route", "clear"] });
  assert.equal(raidAdminRouteOf(new URL(`https://relay/v1/worlds/${WORLD}/bosses`)), null);

  const { bosses } = makeBosses();
  const body = (value) => async () => JSON.stringify(value);
  const report = await handleBossRequest(bosses, "POST", ["Morrigan%230", "report"], body({ battle: "b1", seq: 1, delta: 0.5, max: MAX, killed: true }), ALICE, "Luka");
  assert.deepEqual([report.body.boss.key, report.body.boss.by, report.boss.defeated], ["Morrigan#0", "Luka", true]);
  assert.equal((await handleBossRequest(bosses, "GET", ["Morrigan%230"], body(null), ALICE)).body.defeated, true);
  assert.equal((await handleBossRequest(bosses, "GET", [], body(null), ALICE)).body.bosses.length, 1);
  assert.equal((await handleBossRequest(bosses, "POST", ["Morrigan", "report"], body({ battle: "b1", dealt: 0.5 }), ALICE)).status, 400);
  assert.equal((await handleBossRequest(bosses, "POST", ["Morrigan", "report"], async () => "{", ALICE)).status, 400);
  assert.equal((await handleBossRequest(bosses, "POST", ["Morrigan", "report"], async () => null, ALICE)).status, 413);
  assert.equal((await handleBossRequest(bosses, "POST", ["Morrigan", "report"], async () => "x".repeat(BOSS_LIMITS.maxBodyLength + 1), ALICE)).status, 413);
  assert.equal((await handleBossRequest(bosses, "POST", ["Morrigan"], body({}), ALICE)).status, 404);
  assert.equal((await handleBossRequest(bosses, "DELETE", [], body(null), ALICE)).status, 404);
});

/**
 * Makes a Raid World's story and boss pools for the admin routes, and a directory answer for keys.
 *
 * @param {string} [type] The world's type.
 * @returns {{world: {story: WorldStory, bosses: WorldBosses}, adminOf: (key: unknown) => Promise<object>, asked: unknown[], time: {now: number}}} The world, the directory's answer, the keys it was asked about, and the pools' clock.
 */
function makeAdminWorld(type = WORLD_TYPE.raid) {
  const kept = { story: undefined };
  const story = new WorldStory({
    get: async () => structuredClone(kept.story),
    put: async (next) => void (kept.story = structuredClone(next)),
    getCheckpoint: async () => undefined,
    remove: async () => void (kept.story = undefined),
  }, { limits: STORY_LIMITS });
  const asked = [];
  const adminOf = async (key) => {
    asked.push(key);
    return key === "admin" ? { status: 200, body: { type }, type } : { status: 403, body: { error: "only the relay's admins may do this" } };
  };
  const { bosses, time } = makeBosses();

  return { world: { story, bosses }, adminOf, asked, time };
}

test("admins read a Raid World's counters and pools, fill a pool up and take the route lock back; nobody else may", async () => {
  const { world, adminOf, asked, time } = makeAdminWorld();
  const url = (path) => new URL(`https://relay/v1/worlds/${WORLD}/raid${path}`);
  const body = (value) => async () => JSON.stringify(value);
  const none = async () => "";

  await world.story.write(ALICE, { base: 0, counters: { p: 40, r1141: 0, r1142: 0, r1143: 0, clear: [] }, blob: "QUJD" });
  await world.story.lockRoute("mr");
  await world.bosses.report(ALICE, "Morrigan", { battle: "b1", seq: 1, delta: 0.25, max: MAX }, "Luka");
  await world.bosses.report(BOB, "Lilith", { battle: "b2", seq: 1, delta: 0, max: 900, killed: true }, "Alice");

  const read = await handleRaidAdminRequest(world, "GET", url("?player=admin"), [], none, null, adminOf);
  assert.equal(read.status, 200);
  assert.deepEqual([read.body.story.p, read.body.story.route, read.body.story.blob, read.body.regenPerMinute], [40, "mr", undefined, 0.03]);
  assert.deepEqual(read.body.bosses, [
    { key: "Lilith", left: 0, max: 900, defeated: true, at: time.now, by: "Alice", hp: 0, reports: 1, byPlayer: BOB },
    { key: "Morrigan", left: 0.75, max: MAX, defeated: false, at: time.now, by: null, hp: 3_750_000, reports: 1, byPlayer: null },
  ]);
  assert.equal((await handleRaidAdminRequest(world, "GET", url("?player=other"), [], none, null, adminOf)).status, 403);
  assert.equal((await handleRaidAdminRequest(world, "GET", url("?player=other"), [], none, "admin", adminOf)).status, 200, "the header wins over the address");

  const reset = await handleRaidAdminRequest(world, "POST", url("/bosses/Lilith/reset"), ["bosses", "Lilith", "reset"], body({ player: "admin" }), null, adminOf);
  assert.deepEqual([reset.status, reset.body.left, reset.body.reset, reset.boss], [200, 1, true, { key: "Lilith", left: 1, max: 900, defeated: false }]);

  const cleared = await handleRaidAdminRequest(world, "POST", url("/route/clear"), ["route", "clear"], body({ player: "admin" }), null, adminOf);
  assert.deepEqual([cleared.status, cleared.body.route, cleared.body.cleared, cleared.push], [200, "none", true, 3]);
  const again = await handleRaidAdminRequest(world, "POST", url("/route/clear"), ["route", "clear"], body({}), "admin", adminOf);
  assert.deepEqual([again.body.cleared, again.push], [false, undefined]);
  assert.equal((await world.story.lockRoute("ad")).status, 200, "another route may be chosen once the lock is taken back");

  assert.equal((await handleRaidAdminRequest(world, "POST", url("/route/clear"), ["route", "clear"], body({ player: "other" }), null, adminOf)).status, 403);
  assert.equal((await handleRaidAdminRequest(world, "POST", url("/route/clear"), ["route", "clear"], body(5), null, adminOf)).status, 400);
  assert.equal((await handleRaidAdminRequest(world, "POST", url("/route/clear"), ["route", "clear"], async () => null, null, adminOf)).status, 413);
  assert.equal((await handleRaidAdminRequest(world, "POST", url("/story"), ["story"], body({}), "admin", adminOf)).status, 404);
  assert.ok(asked.includes("other"));
});

test("a Classic world has no admin routes", async () => {
  const { world, adminOf } = makeAdminWorld(WORLD_TYPE.classic);
  const answer = await handleRaidAdminRequest(world, "GET", new URL(`https://relay/v1/worlds/${WORLD}/raid`), [], async () => "", "admin", adminOf);
  assert.deepEqual([answer.status, answer.body.code], [404, "classic"]);
});
