//----------------------------------------------------------------
//  bosses.test.js
//
//  Changelog:
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { BOSS_LIMITS, WorldBosses, bossRouteOf, bossText, handleBossRequest, readKey } from "./bosses.js";
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
 * An hour in milliseconds.
 */
const HOUR = 3_600_000;

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
 * Reports a battle and expects it taken.
 *
 * @param {WorldBosses} bosses The pools.
 * @param {string} key The boss.
 * @param {string} battle The battle's id.
 * @param {number} dealt The share of the boss's max HP dealt.
 * @param {string} [player] The reporting player's id.
 * @returns {Promise<object>} The answer's body.
 */
async function reported(bosses, key, battle, dealt, player = ALICE) {
  const answer = await bosses.report(player, encodeURIComponent(key), { battle, dealt });
  assert.equal(answer.status, 200, JSON.stringify(answer.body));
  return answer.body;
}

test("a boss nobody reported is full, and the list holds only the pools a report touched", async () => {
  const { bosses } = makeBosses();
  assert.deepEqual((await bosses.get("Queen%20Harpy")).body, { key: "Queen Harpy", hp: 5, max: 5, regen: 5, defeated: false });
  assert.deepEqual((await bosses.list()).body, { bosses: [], max: 5, regen: 5 });

  await reported(bosses, "Morrigan", "b1", 0.5);
  await reported(bosses, "Adramelech", "b2", 0.25);
  assert.deepEqual((await bosses.list()).body.bosses.map((pool) => [pool.key, pool.hp]), [["Adramelech", 4.75], ["Morrigan", 4.5]]);
});

test("a report takes the share dealt off the pool, at most one kill, and every game hears the pool", async () => {
  const { bosses } = makeBosses();
  const first = await bosses.report(ALICE, "Morrigan", { battle: "b1", dealt: 0.4 });
  assert.deepEqual(first.body, { key: "Morrigan", hp: 4.6, max: 5, regen: 5, defeated: false, dealt: 0.4, emptied: false, repeat: false });
  assert.deepEqual(first.boss, { key: "Morrigan", hp: 4.6 });

  const capped = await reported(bosses, "Morrigan", "b2", 3);
  assert.equal(capped.dealt, 1);
  assert.equal(capped.hp, 3.6);
});

test("the same battle reported again counts once and changes nothing", async () => {
  const { bosses, kept } = makeBosses();
  await reported(bosses, "Morrigan", "b1", 1);
  const puts = kept.puts;

  const again = await bosses.report(ALICE, "Morrigan", { battle: "b1", dealt: 1 });
  assert.deepEqual([again.body.hp, again.body.dealt, again.body.repeat], [4, 0, true]);
  assert.equal(again.boss, undefined);
  assert.equal(kept.puts, puts);
});

test("a pool fills up again at its rate, a whole pool within the hour, never past full", async () => {
  const { bosses, time } = makeBosses();
  await reported(bosses, "Morrigan", "b1", 1);
  await reported(bosses, "Morrigan", "b2", 1);
  await reported(bosses, "Morrigan", "b3", 1);

  time.now += HOUR / 5;
  assert.equal((await bosses.get("Morrigan")).body.hp, 3);
  time.now += HOUR / 10;
  assert.equal((await bosses.get("Morrigan")).body.hp, 3.5);

  const after = await reported(bosses, "Morrigan", "b4", 0.5);
  assert.equal(after.hp, 3, "a report counts from the pool as it stands now");

  time.now += HOUR;
  assert.equal((await bosses.get("Morrigan")).body.hp, 5);
});

test("the report that empties a pool defeats the boss for good, and only that battle is told it emptied it", async () => {
  const { bosses, kept, time } = makeBosses();

  for (let battle = 1; battle <= 4; battle++) {
    assert.equal((await reported(bosses, "Lilith", `b${battle}`, 1)).emptied, false);
  }

  const last = await reported(bosses, "Lilith", "b5", 1, BOB);
  assert.deepEqual([last.hp, last.emptied, last.defeated], [0, true, true]);
  assert.equal(kept.pools.get("Lilith").by, BOB);

  const puts = kept.puts;
  const late = await bosses.report(ALICE, "Lilith", { battle: "b6", dealt: 1 });
  assert.deepEqual([late.body.hp, late.body.emptied, late.body.defeated, late.body.dealt], [0, false, true, 0]);
  assert.equal(late.boss, undefined);
  assert.equal(kept.puts, puts, "a report on a defeated boss writes nothing");

  const repeat = await reported(bosses, "Lilith", "b5", 1, BOB);
  assert.deepEqual([repeat.emptied, repeat.repeat], [true, true], "the emptying battle sent again is told it emptied the pool");

  time.now += 10 * HOUR;
  assert.deepEqual([(await bosses.get("Lilith")).body.hp, (await bosses.get("Lilith")).body.defeated], [0, true], "a defeated boss never fills up");
});

test("float leftovers close to 0 empty the pool", async () => {
  const { bosses } = makeBosses({ ...BOSS_LIMITS, max: 0.3, reports: { burst: 1000, refillMs: 1 } });
  await reported(bosses, "Morrigan", "b1", 0.1);
  await reported(bosses, "Morrigan", "b2", 0.1);
  assert.equal((await reported(bosses, "Morrigan", "b3", 0.1)).emptied, true);
});

test("a pool whose hit points answer as 0 is defeated, and one that answers more is not", async () => {
  const { bosses } = makeBosses({ ...BOSS_LIMITS, max: 1, reports: { burst: 1000, refillMs: 1 } });
  const left = await reported(bosses, "Lilith", "b1", 0.999);
  assert.deepEqual([left.hp, left.defeated], [0.001, false]);
  const emptied = await reported(bosses, "Lilith", "b2", 0.0006);
  assert.deepEqual([emptied.hp, emptied.defeated, emptied.emptied], [0, true, true]);
});

test("a wrong report is refused before it counts against the player's reports, and each player has reports of their own", async () => {
  const { bosses } = makeBosses({ ...BOSS_LIMITS, reports: { burst: 1, refillMs: 60_000 } });
  assert.equal((await bosses.report(ALICE, "Morrigan", null)).status, 400);
  assert.equal((await bosses.report(ALICE, "Morrigan", { battle: "", dealt: 1 })).status, 400);
  assert.equal((await bosses.report(ALICE, "Morrigan", { battle: "a b", dealt: 1 })).status, 400);
  assert.equal((await bosses.report(ALICE, "Morrigan", { battle: "x".repeat(65), dealt: 1 })).status, 400);
  assert.equal((await bosses.report(ALICE, "Morrigan", { battle: "b1", dealt: -0.1 })).status, 400);
  assert.equal((await bosses.report(ALICE, "Morrigan", { battle: "b1", dealt: "1" })).status, 400);
  assert.equal((await bosses.report(ALICE, "Morrigan", { battle: "b1", dealt: Number.NaN })).status, 400);
  assert.equal((await bosses.report(ALICE, "%20Morrigan", { battle: "b1", dealt: 1 })).status, 400);

  assert.equal((await bosses.report(ALICE, "Morrigan", { battle: "b1", dealt: 0 })).status, 200);
  const tooOften = await bosses.report(ALICE, "Morrigan", { battle: "b2", dealt: 1 });
  assert.deepEqual([tooOften.status, tooOften.body.code], [429, "rate"]);
  assert.equal((await bosses.report(BOB, "Morrigan", { battle: "b3", dealt: 1 })).status, 200);
});

test("a world keeps a limited number of pools and remembers a limited number of battles each", async () => {
  const { bosses, kept } = makeBosses({ ...BOSS_LIMITS, maxPools: 2, recentBattles: 2, reports: { burst: 1000, refillMs: 1 } });
  await reported(bosses, "One", "b1", 0.1);
  await reported(bosses, "Two", "b2", 0.1);
  const full = await bosses.report(ALICE, "Three", { battle: "b3", dealt: 0.1 });
  assert.deepEqual([full.status, full.body.code], [413, "full"]);

  await reported(bosses, "One", "b4", 0.1);
  await reported(bosses, "One", "b5", 0.1);
  assert.deepEqual(kept.pools.get("One").battles, ["b4", "b5"]);
});

test("boss keys are read percent-decoded, and keys that are none are refused", () => {
  assert.equal(readKey("Alma%20Elma%2C%20then%20Granberia"), "Alma Elma, then Granberia");
  assert.equal(readKey("1507"), "1507");
  assert.equal(readKey(encodeURIComponent("アリス")), "アリス");
  assert.equal(readKey(""), null);
  assert.equal(readKey("%E0%A4%A"), null);
  assert.equal(readKey("a%09b"), null);
  assert.equal(readKey("x".repeat(65)), null);
  assert.equal(readKey(undefined), null);
});

test("an admin's reset fills a pool up and takes its defeat back, and removing forgets every pool", async () => {
  const { bosses } = makeBosses({ ...BOSS_LIMITS, max: 1, reports: { burst: 1000, refillMs: 1 } });
  await reported(bosses, "Lilith", "b1", 1);
  assert.equal((await bosses.get("Lilith")).body.defeated, true);

  const reset = await bosses.reset("Lilith");
  assert.deepEqual([reset.body.hp, reset.body.defeated, reset.body.reset], [1, false, true]);
  assert.deepEqual(reset.boss, { key: "Lilith", hp: 1 });
  assert.equal((await bosses.get("Lilith")).body.defeated, false);

  const untouched = await bosses.reset("Morrigan");
  assert.deepEqual([untouched.body.reset, untouched.boss], [false, undefined]);
  assert.equal((await bosses.reset("%20")).status, 400);

  await reported(bosses, "Morrigan", "b2", 0.5);
  await bosses.remove();
  assert.deepEqual((await bosses.list()).body.bosses, []);
});

test("the routes are read from the address, and the router answers each", async () => {
  assert.deepEqual(bossRouteOf(new URL(`https://relay/v1/worlds/${WORLD}/bosses`)), { id: WORLD, rest: [] });
  assert.deepEqual(bossRouteOf(new URL(`https://relay/v1/worlds/${WORLD}/bosses/Queen%20Harpy/report`)).rest, ["Queen%20Harpy", "report"]);
  assert.equal(bossRouteOf(new URL(`https://relay/v1/worlds/${WORLD}/story`)), null);
  assert.equal(bossRouteOf(new URL("https://relay/v1/worlds/XYZ/bosses")), null);
  assert.deepEqual(raidAdminRouteOf(new URL(`https://relay/v1/worlds/${WORLD}/raid/route/clear`)), { id: WORLD, rest: ["route", "clear"] });
  assert.equal(raidAdminRouteOf(new URL(`https://relay/v1/worlds/${WORLD}/bosses`)), null);
  assert.equal(bossText("Alma Elma, then Granberia", 3.25), "boss 3.25 Alma Elma, then Granberia");
  assert.equal(bossText("Lilith", 2 / 3), "boss 0.667 Lilith");

  const { bosses } = makeBosses();
  const body = (value) => async () => JSON.stringify(value);
  assert.equal((await handleBossRequest(bosses, "POST", ["Morrigan", "report"], body({ battle: "b1", dealt: 0.5 }), ALICE)).body.hp, 4.5);
  assert.equal((await handleBossRequest(bosses, "GET", ["Morrigan"], body(null), ALICE)).body.hp, 4.5);
  assert.equal((await handleBossRequest(bosses, "GET", [], body(null), ALICE)).body.bosses.length, 1);
  assert.equal((await handleBossRequest(bosses, "POST", ["Morrigan", "report"], async () => null, ALICE)).status, 413);
  assert.equal((await handleBossRequest(bosses, "POST", ["Morrigan", "report"], async () => "x".repeat(BOSS_LIMITS.maxBodyLength + 1), ALICE)).status, 413);
  assert.equal((await handleBossRequest(bosses, "POST", ["Morrigan"], body({}), ALICE)).status, 404);
  assert.equal((await handleBossRequest(bosses, "DELETE", [], body(null), ALICE)).status, 404);
});

/**
 * Makes a Raid World's story and boss pools for the admin routes, and a directory answer for keys.
 *
 * @param {string} [type] The world's type.
 * @returns {{world: {story: WorldStory, bosses: WorldBosses}, adminOf: (key: unknown) => Promise<object>, asked: unknown[]}} The world, the directory's answer, and the keys it was asked about.
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

  return { world: { story, bosses: makeBosses().bosses }, adminOf, asked };
}

test("admins read a Raid World's counters and pools, fill a pool up and take the route lock back; nobody else may", async () => {
  const { world, adminOf, asked } = makeAdminWorld();
  const url = (path) => new URL(`https://relay/v1/worlds/${WORLD}/raid${path}`);
  const body = (value) => async () => JSON.stringify(value);
  const none = async () => "";

  await world.story.write(ALICE, { base: 0, counters: { p: 40, r1141: 0, r1142: 0, r1143: 0, clear: [] }, blob: "QUJD" });
  await world.story.lockRoute("mr");
  await world.bosses.report(ALICE, "Morrigan", { battle: "b1", dealt: 1 });

  const read = await handleRaidAdminRequest(world, "GET", url("?player=admin"), [], none, null, adminOf);
  assert.equal(read.status, 200);
  assert.deepEqual([read.body.story.p, read.body.story.route, read.body.story.blob, read.body.max, read.body.regen], [40, "mr", undefined, 5, 5]);
  assert.deepEqual([read.body.bosses[0].key, read.body.bosses[0].hp, read.body.bosses[0].reports], ["Morrigan", 4, 1]);
  assert.equal((await handleRaidAdminRequest(world, "GET", url("?player=other"), [], none, null, adminOf)).status, 403);
  assert.equal((await handleRaidAdminRequest(world, "GET", url("?player=other"), [], none, "admin", adminOf)).status, 200, "the header wins over the address");

  const reset = await handleRaidAdminRequest(world, "POST", url("/bosses/Morrigan/reset"), ["bosses", "Morrigan", "reset"], body({ player: "admin" }), null, adminOf);
  assert.deepEqual([reset.status, reset.body.hp, reset.boss], [200, 5, { key: "Morrigan", hp: 5 }]);

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
