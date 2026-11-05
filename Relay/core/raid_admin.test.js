//----------------------------------------------------------------
//  raid_admin.test.js
//
//  Changelog:
//      Paulinchen  2026-11-05: Kept the stories the tests start from as older games wrote them, as games write no story over HTTP
//      Paulinchen  2026-11-01: Covered the pins refused for keys the story mapping does not share
//      Paulinchen  2026-10-31: Covered the admin view, keys, pins and route lock of a world whose story runs on tracks
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { BOSS_LIMITS, WorldBosses } from "./bosses.js";
import { WORLD_TYPE } from "./directory.js";
import { handleRaidAdminRequest } from "./raid_admin.js";
import { STORY_LIMITS, WorldStory, pinOf } from "./story.js";
import { StoryTracks } from "./story_tracks.js";

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
 * The story mapping a world's tracks play by.
 */
const MAPPING = Object.freeze({
  rev: 1,
  tables: { keys: [{ key: "v1001", kind: "one_way" }, { key: "v1141", kind: "one_way" }, { key: "v50", kind: "shared" }], events: [], parts: [] },
  index: null,
});

/**
 * Makes one world's track store in memory.
 *
 * @returns {import("./story_tracks.js").TrackStore} The store.
 */
function memoryTrackStore() {
  const kept = { meta: undefined, keys: new Map(), players: new Map(), checkpoints: new Map() };
  const keysOf = (track) => kept.keys.get(track) ?? kept.keys.set(track, new Map()).get(track);

  return {
    getMeta: async () => structuredClone(kept.meta),
    getKeys: async (track) => [...keysOf(track)],
    getRuns: async () => [],
    getPlayer: async (player) => structuredClone(kept.players.get(player)),
    getCheckpoint: async (part) => structuredClone(kept.checkpoints.get(part)),
    commit: async ({ meta, keys = [], players = [], checkpoint }) => {
      kept.meta = meta ? structuredClone(meta) : kept.meta;
      keys.forEach(({ track, set }) => set.forEach(([key, value]) => keysOf(track).set(key, value)));
      players.forEach((record) => kept.players.set(record.player, structuredClone(record)));

      if (checkpoint) {
        kept.checkpoints.set(checkpoint.part, structuredClone(checkpoint.keys));
      }
    },
    remove: async () => {},
  };
}

/**
 * Makes a Raid World's story, story tracks and boss pools over stores in memory, and a directory
 * that knows the key "admin" as an admin's.
 *
 * @returns {{world: {story: WorldStory, bosses: WorldBosses, tracks: StoryTracks}, kept: {story: object | undefined, pools: Map<string, object>}, heard: object[], ask: (method: string, path: string, body?: object, key?: string) => Promise<object>, restart: () => void}} The world, what its stores keep, the track frames its games heard, a request to its admin routes, as the admin unless another key is given, and a relay start that makes the world's tracks anew over the same store.
 */
function makeWorld() {
  const kept = { story: undefined, pools: new Map() };
  const story = new WorldStory({
    get: async () => structuredClone(kept.story),
    put: async (next) => void (kept.story = structuredClone(next)),
    getCheckpoint: async () => undefined,
    remove: async () => void (kept.story = undefined),
  }, { limits: STORY_LIMITS });
  const bosses = new WorldBosses({
    get: async (key) => structuredClone(kept.pools.get(key)),
    put: async (pool) => void kept.pools.set(pool.key, structuredClone(pool)),
    all: async () => [...kept.pools.values()].map((pool) => structuredClone(pool)),
    remove: async (key) => void kept.pools.delete(key),
    removeAll: async () => kept.pools.clear(),
  }, { limits: BOSS_LIMITS });
  const heard = [];
  const trackStore = memoryTrackStore();
  const tracksOf = () => new StoryTracks(trackStore, {
    mapping: async () => MAPPING,
    pins: async () => {
      const pinned = await story.kept();
      return { pinOf: (key) => pinOf(pinned, key), keys: Object.keys(pinned?.pinned ?? {}) };
    },
    send: (_player, text) => heard.push(JSON.parse(text.slice("track ".length))),
  });
  const world = { story, bosses, tracks: tracksOf() };
  const adminOf = async (key) => (key === "admin" ? { status: 200, body: { type: WORLD_TYPE.raid }, type: WORLD_TYPE.raid, player: ADMIN_ID } : { status: 403, body: { error: "only the relay's admins may do this" } });
  const ask = (method, path, body = {}, key = "admin") => {
    const url = new URL(`https://relay/v1/worlds/${WORLD}/raid${path}`);
    const rest = url.pathname.split("/").filter((part) => part.length > 0).slice(4);
    return handleRaidAdminRequest(world, method, url, rest, async () => JSON.stringify(body), key, adminOf);
  };

  const restart = () => void (world.tracks = tracksOf());

  return { world, kept, heard, ask, restart };
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

/**
 * Keeps a story as an older game wrote it key by key, at revision 1, which the relay keeps as
 * world data.
 *
 * @param {{story: object | undefined}} kept What the story's store keeps.
 * @param {object} lists The story's lists.
 * @param {object} values The counters that differ from 0.
 */
function keepKeyed(kept, lists, values) {
  kept.story = {
    rev: 1, wrev: 1, counters: counters(values), part: "1", route: "none", done: [], end: null, comps: [], caps: [], checkpoints: [], at: 1000, by: ALICE,
    lists: { s: "", sf: "", v: "", ss: "", ssf: "", a: "", f: "", ...lists }, log: [], logBase: 1,
  };
}

test("the admin view leaves a keyed story's keys out unless the request asks for them", async () => {
  const { kept, ask } = makeWorld();
  keepKeyed(kept, { s: "5", v: "1001:n10" }, { p: 10 });

  const plain = await ask("GET", "");
  assert.deepEqual([plain.status, plain.body.story.rev, plain.body.story.p, plain.body.story.keys, plain.body.story.keyed], [200, 1, 10, undefined, undefined]);
  const keyed = await ask("GET", "?keys=1");
  assert.deepEqual([keyed.body.story.keyed, keyed.body.story.keys.v], [true, "1001:n10"]);
});

test("an admin sets switches, variables and self switches by id as a revision every game takes, and the counters follow", async () => {
  const { kept, ask } = makeWorld();
  assert.deepEqual(await ask("POST", "/keys", { s: { 5: true } }).then((answer) => [answer.status, answer.body.code]), [409, "none"], "a story nobody wrote has no keys yet");
  keepKeyed(kept, { s: "5", v: "1001:n10,30:n1", ss: "12.3.A" }, { p: 10 });

  const set = await ask("POST", "/keys", { s: { 5: false, 6: true }, v: { 1001: 18, 30: 1, 31: "Lime", 32: 1.5, 33: true }, ss: { "12.3.A": false } });
  assert.equal(set.status, 200, JSON.stringify(set.body));
  assert.deepEqual([set.body.rev, set.body.wrev, set.body.p], [2, 2, 18], "the counters follow variable 1001");
  assert.deepEqual(set.push.delta, { s: "6", sf: "5", v: "31:sTGltZQ==,32:f1.5,33:T,1001:n18", ss: "", ssf: "12.3.A", a: "", f: "" }, "a key that holds the value already is no change");
  assert.deepEqual([set.push.rev, set.push.prev], [2, 1]);
  assert.equal(set.audit, `admin ${ADMIN_ID} set keys of rev 2: ${JSON.stringify(set.push.delta)}`, "the log names who set what");

  assert.equal((await ask("POST", "/keys", { v: { 1: null } })).status, 400);
  assert.equal((await ask("POST", "/keys", { s: { 0: true } })).status, 400);
  assert.equal((await ask("POST", "/keys", { ss: { "12.3": true } })).status, 400);
  assert.equal((await ask("POST", "/keys", {})).status, 400, "a request that names no key");
  assert.equal((await ask("POST", "/keys", { s: { 5: true } }, "other")).status, 403);
});

test("an admin pins keys at values, which sets them for every game and keeps them against writes, and takes pins off again", async () => {
  const { kept, ask } = makeWorld();
  keepKeyed(kept, { s: "12", v: "1001:n10,1201:n2" }, { p: 10 });
  kept.story.pins = ["v1300-1310"];

  const pinned = await ask("POST", "/pins", { keys: { s12: true, v1201: 5, "ss858.139.A": false, v1202: "Lime" } });
  assert.equal(pinned.status, 200, JSON.stringify(pinned.body));
  assert.deepEqual(pinned.push.delta, { s: "", sf: "", v: "1201:n5,1202:sTGltZQ==", ss: "", ssf: "858.139.A", a: "", f: "" }, "a key pinned at the value it holds is no change");
  assert.deepEqual(pinned.body.pins, { keys: { s12: true, v1201: 5, "ss858.139.A": false, v1202: "Lime" }, rules: ["v1300-1310"] });
  assert.equal(pinned.body.wrev, 2);

  const view = await ask("GET", "");
  assert.deepEqual(view.body.pins, pinned.body.pins, "the admin view shows the pins");
  assert.deepEqual(await ask("POST", "/keys", { v: { 1201: 6 } }).then((answer) => [answer.status, answer.body.code, answer.body.keys]), [409, "pinned", ["v1201"]]);

  const again = await ask("POST", "/pins", { keys: { v1201: 5 } });
  assert.deepEqual([again.body.rev, again.push], [2, undefined], "pinning a key at the value it holds makes no revision");

  const cleared = await ask("POST", "/pins/clear", { keys: ["v01201", "v1300-1310", "s99"] });
  assert.deepEqual(cleared.body, { cleared: ["v1201", "v1300-1310"], pins: { keys: { s12: true, "ss858.139.A": false, v1202: "Lime" }, rules: [] } });

  assert.equal((await ask("POST", "/pins", { keys: { s12: 1 } })).status, 400);
  assert.equal((await ask("POST", "/pins", { keys: { x12: true } })).status, 400);
  assert.equal((await ask("POST", "/pins/clear", { keys: "s12" })).status, 400);
  assert.equal((await ask("POST", "/pins", { keys: { s12: true } }, "other")).status, 403);
});

test("on a world whose story runs on tracks, the admin view, keys, pins and route lock act on the world's track, and its keyed story keeps the companions alone", async () => {
  const { world, heard, ask } = makeWorld();
  await world.tracks.enter(ALICE, 0);
  await world.tracks.frame(ALICE, `track ${JSON.stringify({ t: "sync", level: { best: 99, cap: null }, seed: { v1001: "n40", v50: "n1" } })}`);
  await world.story.addCompanions([5]);
  heard.length = 0;

  const view = await ask("GET", "?keys=1");
  const story = view.body.story;
  assert.deepEqual([view.status, story.tracks, story.rev, story.wrev, story.part, story.route, story.p, story.comps, story.keyed, story.keys.v], [200, true, 1, 1, "3", "none", 40, [5], true, "1001:n40,50:n1"]);
  assert.equal((await ask("GET", "")).body.story.keys, undefined, "the keys only when asked for");

  const set = await ask("POST", "/keys", { v: { 50: 4, 1141: 1 } });
  assert.equal(set.status, 200, JSON.stringify(set.body));
  assert.deepEqual([set.body.rev, set.body.part, set.body.route, set.body.r1141, set.body.set.v, set.push], [2, "ad", "ad", 1, "50:n4,1141:n1", undefined]);
  assert.equal(set.audit, `admin ${ADMIN_ID} set keys of rev 2: ${JSON.stringify(set.body.set)}`);
  assert.deepEqual(heard.map(({ t, rev, keys, world: summary }) => [t, rev, keys, summary.route]), [["push", 2, { v50: "n4", v1141: "n1" }, "ad"]], "every game on the world's track hears it");
  assert.deepEqual(await ask("POST", "/keys", { s: { 100: true } }).then((answer) => [answer.status, answer.body.code, answer.body.keys]), [409, "mapping", ["s100"]]);
  assert.equal(await world.story.keys(), undefined, "the keyed story keeps no keys");

  heard.length = 0;
  const pinned = await ask("POST", "/pins", { keys: { v50: 7 } });
  assert.deepEqual([pinned.status, pinned.body.rev, pinned.body.set.v, pinned.body.pins.keys], [200, 3, "50:n7", { v50: 7 }]);
  assert.deepEqual(heard.map(({ rev, keys }) => [rev, keys]), [[3, { v50: "n7" }]]);
  assert.deepEqual(await ask("POST", "/keys", { v: { 50: 1 } }).then((answer) => [answer.status, answer.body.code, answer.body.keys]), [409, "pinned", ["v50"]]);
  assert.deepEqual((await ask("POST", "/pins/clear", { keys: ["v50"] })).body.cleared, ["v50"]);

  heard.length = 0;
  const unshared = await ask("POST", "/pins", { keys: { v50: 2, s100: true } });
  assert.deepEqual([unshared.status, unshared.body.code, unshared.body.keys], [409, "mapping", ["s100"]]);
  assert.deepEqual([(await ask("GET", "")).body.pins.keys, heard], [{}, []], "a refused pin keeps nothing and changes nothing");

  const refused = await ask("POST", "/route/clear");
  assert.deepEqual([refused.status, refused.body.code, refused.body.route], [409, "started", "ad"], "the world is on the locked route");
});

test("on a world whose story runs on tracks, the admin view answers after the relay starts again, before any game enters", async () => {
  const { world, ask, restart } = makeWorld();
  await world.tracks.enter(ALICE, 0);
  await world.tracks.frame(ALICE, `track ${JSON.stringify({ t: "sync", level: { best: 99, cap: null }, seed: { v1001: "n40" } })}`);
  restart();

  const view = await ask("GET", "?keys=1");
  assert.equal(view.status, 200, JSON.stringify(view.body));
  assert.deepEqual([view.body.story.tracks, view.body.story.rev, view.body.story.part, view.body.story.keys.v], [true, 1, "3", "1001:n40"]);
});
