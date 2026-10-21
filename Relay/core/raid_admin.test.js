//----------------------------------------------------------------
//  raid_admin.test.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { BOSS_LIMITS, WorldBosses } from "./bosses.js";
import { WORLD_TYPE } from "./directory.js";
import { handleRaidAdminRequest } from "./raid_admin.js";
import { STORY_LIMITS, WorldStory } from "./story.js";

/**
 * A player's id.
 */
const ALICE = "a1".repeat(16);

/**
 * The admin's player id, as the directory names it.
 */
const ADMIN_ID = "ad".repeat(16);

/**
 * A world's id.
 */
const WORLD = "0123456789abcdef0123456789abcdef";

/**
 * Makes a Raid World's story and boss pools over stores in memory, and a directory that knows the
 * key "admin" as an admin's.
 *
 * @returns {{world: {story: WorldStory, bosses: WorldBosses}, kept: {story: object | undefined, pools: Map<string, object>}, ask: (method: string, path: string, body?: object, key?: string) => Promise<object>}} The world, what its stores keep, and a request to its admin routes, as the admin unless another key is given.
 */
function makeWorld() {
  const kept = { story: undefined, pools: new Map() };
  const story = new WorldStory({
    get: async () => structuredClone(kept.story),
    put: async (next) => void (kept.story = structuredClone(next)),
    getCheckpoint: async () => undefined,
    remove: async () => void (kept.story = undefined),
  }, { limits: { ...STORY_LIMITS, writes: { burst: 1000, refillMs: 1 } } });
  const bosses = new WorldBosses({
    get: async (key) => structuredClone(kept.pools.get(key)),
    put: async (pool) => void kept.pools.set(pool.key, structuredClone(pool)),
    all: async () => [...kept.pools.values()].map((pool) => structuredClone(pool)),
    remove: async (key) => void kept.pools.delete(key),
    removeAll: async () => kept.pools.clear(),
  }, { limits: BOSS_LIMITS });
  const world = { story, bosses };
  const adminOf = async (key) => (key === "admin" ? { status: 200, body: { type: WORLD_TYPE.raid }, type: WORLD_TYPE.raid, player: ADMIN_ID } : { status: 403, body: { error: "only the relay's admins may do this" } });
  const ask = (method, path, body = {}, key = "admin") => {
    const url = new URL(`https://relay/v1/worlds/${WORLD}/raid${path}`);
    const rest = url.pathname.split("/").filter((part) => part.length > 0).slice(4);
    return handleRaidAdminRequest(world, method, url, rest, async () => JSON.stringify(body), key, adminOf);
  };

  return { world, kept, ask };
}

/**
 * Makes counters, 0 and no finished route unless given.
 *
 * @param {object} [values] The counters that differ.
 * @returns {object} The counters.
 */
function counters(values = {}) {
  return { p: 0, r1141: 0, r1142: 0, r1143: 0, clear: [], ...values };
}

test("the admin view leaves a keyed story's keys out unless the request asks for them", async () => {
  const { world, ask } = makeWorld();
  await world.story.write(ALICE, { base: 0, counters: counters({ p: 10 }), set: { s: "5", v: "1001:n10" } });

  const plain = await ask("GET", "");
  assert.deepEqual([plain.status, plain.body.story.rev, plain.body.story.p, plain.body.story.keys, plain.body.story.keyed], [200, 1, 10, undefined, undefined]);
  const keyed = await ask("GET", "?keys=1");
  assert.deepEqual([keyed.body.story.keyed, keyed.body.story.keys.v], [true, "1001:n10"]);
});

test("an admin sets switches, variables and self switches by id as a revision every game takes, and the counters follow", async () => {
  const { world, ask } = makeWorld();
  assert.deepEqual(await ask("POST", "/keys", { s: { 5: true } }).then((answer) => [answer.status, answer.body.code]), [409, "none"], "a story nobody wrote has no keys yet");
  await world.story.write(ALICE, { base: 0, counters: counters({ p: 10 }), set: { s: "5", v: "1001:n10,30:n1", ss: "12.3.A" } });

  const set = await ask("POST", "/keys", { s: { 5: false, 6: true }, v: { 1001: 18, 30: 1, 31: "Lime", 32: 1.5, 33: true }, ss: { "12.3.A": false } });
  assert.equal(set.status, 200, JSON.stringify(set.body));
  assert.deepEqual([set.body.rev, set.body.wrev, set.body.p], [2, 2, 18], "the counters follow variable 1001");
  assert.deepEqual(set.push.delta, { s: "6", sf: "5", v: "31:sTGltZQ==,32:f1.5,33:T,1001:n18", ss: "", ssf: "12.3.A", a: "", f: "" }, "a key that holds the value already is no change");
  assert.deepEqual([set.push.rev, set.push.prev], [2, 1]);
  assert.equal(set.audit, `admin ${ADMIN_ID} set keys of rev 2: ${JSON.stringify(set.push.delta)}`, "the log names who set what");

  const late = await world.story.write(ALICE, { base: 1, counters: counters({ p: 18 }), set: { s: "5" } });
  assert.equal(late.body.kept.s, "", "the admin's key is kept against a game that wrote on an older revision");
  assert.equal(late.body.kept.sf, "5");

  assert.equal((await ask("POST", "/keys", { v: { 1: null } })).status, 400);
  assert.equal((await ask("POST", "/keys", { s: { 0: true } })).status, 400);
  assert.equal((await ask("POST", "/keys", { ss: { "12.3": true } })).status, 400);
  assert.equal((await ask("POST", "/keys", {})).status, 400, "a request that names no key");
  assert.equal((await ask("POST", "/keys", { s: { 5: true } }, "other")).status, 403);
});
