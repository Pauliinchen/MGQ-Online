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
