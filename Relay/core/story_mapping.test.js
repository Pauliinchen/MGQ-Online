//----------------------------------------------------------------
//  story_mapping.test.js
//
//  Changelog:
//      Paulinchen  2026-11-01: Covered the shared self switches the whole world keeps
//      Paulinchen  2026-10-31: Covered the game's working values among the personal keys
//      Paulinchen  2026-10-28: Covered the seeding of the tables that hold no rows yet
//      Paulinchen  2026-10-23: Covered the keys the whole world keeps
//                            - Covered the derived index's common events and the game's names kept with it
//                            - Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { playerIdOf } from "./directory.js";
import { BATTLE_SERVER_AUTHOR, MAPPING_LIMITS, MAPPING_REFUSAL, SEED_AUTHOR, StoryMapping, handleMappingAdminRequest, handleMappingGameRequest } from "./story_mapping.js";

/**
 * The admin's player key.
 */
const ADMIN = "ad".repeat(16);

/**
 * Another player's key.
 */
const PLAYER = "a1".repeat(16);

/**
 * Makes a store of the story mapping in memory.
 *
 * @returns {import("./story_mapping.js").StoryMappingStore} The store.
 */
function memoryStore() {
  const kept = { meta: undefined, index: undefined, tables: new Map(), histories: new Map() };
  const table = (name) => kept.tables.get(name) ?? kept.tables.set(name, new Map()).get(name);

  return {
    getMeta: async () => structuredClone(kept.meta),
    all: async (name) => [...table(name).values()].map((entry) => structuredClone(entry)),
    get: async (name, id) => structuredClone(table(name).get(id)),
    history: async (name, id) => structuredClone(kept.histories.get(`${name}\n${id}`) ?? []),
    commit: async (commit, keep) => {
      kept.meta = structuredClone(commit.meta);
      commit.puts.forEach(({ table: name, entry }) => table(name).set(entry.id, structuredClone(entry)));
      commit.removes.forEach(({ table: name, id }) => table(name).delete(id));
      commit.changes.forEach(({ table: name, id, change }) => kept.histories.set(`${name}\n${id}`, [change, ...(kept.histories.get(`${name}\n${id}`) ?? [])].slice(0, keep)));
      kept.index = commit.index ? structuredClone(commit.index) : kept.index;
    },
    getIndex: async () => structuredClone(kept.index),
  };
}

/**
 * Makes a story mapping in memory, and a request to its admin routes as the admin unless another
 * key is given.
 *
 * @param {Partial<typeof MAPPING_LIMITS>} [limits] Limits that differ.
 * @returns {{mapping: StoryMapping, ask: (method: string, path: string, body?: object, key?: string) => Promise<{status: number, body: object, audit?: string}>}} The mapping and the request.
 */
function makeMapping(limits = {}) {
  const mapping = new StoryMapping(memoryStore(), { limits: { ...MAPPING_LIMITS, ...limits }, clock: () => 1000 });
  const isAdmin = async (key) => key === ADMIN;
  const ask = (method, path, body = {}, key = ADMIN) => {
    const url = new URL(`https://relay/v1/admin/story${path}`);
    const rest = url.pathname.split("/").filter((part) => part.length > 0).slice(3);
    return handleMappingAdminRequest(mapping, method, url, rest, async () => JSON.stringify(body), key, isAdmin);
  };

  return { mapping, ask };
}

/**
 * Makes a batch's edit that adds a row.
 *
 * @param {string} table The table.
 * @param {object} row The row.
 * @returns {object} The edit.
 */
function add(table, row) {
  return { table, op: "add", row };
}

test("a key's kind must fit a switch or a variable and take the options it names", async () => {
  const { ask } = makeMapping();
  const refused = async (row) => (await ask("POST", "/edit", { edits: [add("keys", row)] })).body.code;

  assert.equal(await refused({ key: "v2029", kind: "scene" }), MAPPING_REFUSAL.kind);
  assert.equal(await refused({ key: "s1001", kind: "one_way" }), MAPPING_REFUSAL.kind);
  assert.equal(await refused({ key: "s2029", kind: "shared", defeatReturns: { 4: 3 } }), MAPPING_REFUSAL.option);
  assert.equal(await refused({ key: "s2029", kind: "scene", routeReturnClears: true }), MAPPING_REFUSAL.option);
  assert.equal(await refused({ key: "v1354", kind: "count" }), MAPPING_REFUSAL.option);
  assert.equal(await refused({ key: "v1354", kind: "count", counts: { from: 3180, to: 3101 } }), MAPPING_REFUSAL.field);
  assert.equal(await refused({ key: "v1062", kind: "one_way", defeatReturns: { 4: 4 } }), MAPPING_REFUSAL.field);
  assert.equal(await refused({ key: "v0", kind: "shared" }), MAPPING_REFUSAL.field);
  assert.equal(await refused({ key: "v1001", kind: "shared", sharde: true }), MAPPING_REFUSAL.field);
  assert.equal(await refused({ key: "s2045", kind: "chest", defeatWrite: false }), MAPPING_REFUSAL.field);
  assert.equal(await refused({ key: "v1354", kind: "count", counts: { from: 3101, to: 3180 }, wholeWorld: true }), MAPPING_REFUSAL.option, "only shared and one-way keys are the whole world's");
  assert.equal(await refused({ key: "v1001", kind: "shared", work: true }), MAPPING_REFUSAL.option, "only a personal key is one of the game's working values");

  const taken = await ask("POST", "/edit", {
    edits: [
      add("keys", { key: "v1052", kind: "one_way", localSteps: { steps: [3, 4, 5], sharedAs: 2, places: [{ map: 484, fromX: 30 }, { map: 483, fromX: 0 }] } }),
      add("keys", { key: "v1075", kind: "one_way", battleScene: { steps: [15, 16], start: 14, mainStep: 33, troops: [868, 869] } }),
      add("keys", { key: "v1354", kind: "count", counts: { from: 3101, to: 3180 } }),
      add("keys", { key: "s22", kind: "personal", defeatWrite: true }),
      add("keys", { key: "v3005", kind: "one_way", wholeWorld: true }),
      add("keys", { key: "v57", kind: "personal", work: true }),
    ],
  });
  assert.equal(taken.status, 200);
  assert.deepEqual(taken.body.changed.map((change) => change.id), ["v1052", "v1075", "v1354", "s22", "v3005", "v57"]);
});

test("an event's self switches name a map's events and letters, a chest's only as personal", async () => {
  const { ask } = makeMapping();
  const edit = (row) => ask("POST", "/edit", { edits: [add("events", row)] });

  assert.equal((await edit({ key: "ss0.*.F", share: "shared" })).status, 200);
  assert.equal((await edit({ key: "ss231.*.*", share: "personal" })).status, 200);
  assert.equal((await edit({ key: "ce154.*", share: "shared" })).status, 200);
  assert.equal((await edit({ key: "ss6.9.A", share: "personal", chest: true })).status, 200);
  assert.equal((await edit({ key: "ss6.10.A", share: "shared", chest: true })).body.code, MAPPING_REFUSAL.option);
  assert.equal((await edit({ key: "ss07.39.A", share: "shared" })).body.code, MAPPING_REFUSAL.field);
  assert.equal((await edit({ key: "ss0.*.G", share: "shared", wholeWorld: true })).status, 200);
  assert.equal((await edit({ key: "ss0.*.H", share: "personal", wholeWorld: true })).body.code, MAPPING_REFUSAL.option, "only shared self switches are the whole world's");
});

test("a batch applies whole or not at all, and raises the revision once", async () => {
  const { ask } = makeMapping();
  const first = await ask("POST", "/edit", { edits: [add("keys", { key: "v1001", kind: "one_way" }), add("keys", { key: "s2029", kind: "scene" })] });
  assert.equal(first.body.rev, 1);
  assert.match(first.audit, /changed the story mapping to rev 1: add keys v1001, add keys s2029$/);

  const late = await ask("POST", "/edit", { edits: [add("keys", { key: "s2030", kind: "scene" }), add("keys", { key: "v1001", kind: "shared" })] });
  assert.equal(late.status, 409);
  assert.deepEqual([late.body.code, late.body.edit], [MAPPING_REFUSAL.exists, 1]);

  const wrong = await ask("POST", "/edit", { edits: [{ table: "keys", op: "remove", id: "s2029" }, add("keys", { key: "s2031", kind: "loud" })] });
  assert.deepEqual([wrong.status, wrong.body.code, wrong.body.edit], [400, MAPPING_REFUSAL.field, 1]);

  const twice = await ask("POST", "/edit", { edits: [{ table: "keys", op: "remove", id: "s2029" }, { table: "keys", op: "change", id: "s2029", row: { key: "s2029", kind: "shared" } }] });
  assert.equal(twice.body.code, MAPPING_REFUSAL.twice);

  const keys = (await ask("GET", "/keys")).body;
  assert.equal(keys.rev, 1);
  assert.deepEqual(keys.rows.map((entry) => entry.id), ["s2029", "v1001"]);
});

test("a change keeps the row's key, an unchanged one leaves the revision, and a stale revision is refused", async () => {
  const { ask } = makeMapping();
  await ask("POST", "/edit", { edits: [{ ...add("keys", { key: "v1001", kind: "one_way" }), note: "main story progress" }] });

  const moved = await ask("POST", "/edit", { edits: [{ table: "keys", op: "change", id: "v1001", row: { key: "v1002", kind: "one_way" } }] });
  assert.equal(moved.body.code, MAPPING_REFUSAL.key);

  const same = await ask("POST", "/edit", { rev: 1, edits: [{ table: "keys", op: "change", id: "v1001", row: { key: "v1001", kind: "one_way" } }] });
  assert.deepEqual(same.body, { rev: 1, changed: [] });

  await ask("POST", "/edit", { rev: 1, edits: [{ table: "keys", op: "change", id: "v1001", row: { key: "v1001", kind: "shared" } }] });
  const stale = await ask("POST", "/edit", { rev: 1, edits: [{ table: "keys", op: "remove", id: "v1001" }] });
  assert.deepEqual([stale.status, stale.body.code, stale.body.rev], [409, MAPPING_REFUSAL.rev, 2]);

  const [entry] = (await ask("GET", "/keys")).body.rows;
  assert.deepEqual(entry, { id: "v1001", row: { key: "v1001", kind: "shared" }, note: "main story progress", author: await playerIdOf(ADMIN), time: 1000, rev: 2 });
});

test("each row keeps its last changes, newest first, also once removed", async () => {
  const { ask } = makeMapping({ history: 3 });

  for (const kind of ["shared", "one_way", "shared", "one_way"]) {
    await ask("POST", "/edit", { edits: [(await ask("GET", "/keys")).body.rows.length === 0 ? add("keys", { key: "v1009", kind }) : { table: "keys", op: "change", id: "v1009", row: { key: "v1009", kind } }] });
  }

  await ask("POST", "/edit", { edits: [{ table: "keys", op: "remove", id: "v1009", note: "Amira's step is personal after all" }] });
  const { history } = (await ask("GET", "/keys/v1009/history")).body;

  assert.deepEqual(history.map((change) => [change.rev, change.op, change.before?.kind ?? null, change.after?.kind ?? null]), [
    [5, "remove", "one_way", null],
    [4, "change", "shared", "one_way"],
    [3, "change", "one_way", "shared"],
  ]);
  assert.equal(history[0].note, "Amira's step is personal after all");
});

test("only the relay's admins read or change the mapping", async () => {
  const { ask } = makeMapping();

  assert.equal((await ask("GET", "", {}, PLAYER)).status, 403);
  assert.equal((await ask("GET", "/keys", {}, PLAYER)).status, 403);
  assert.equal((await ask("POST", "/edit", { edits: [add("keys", { key: "v1001", kind: "one_way" })] }, PLAYER)).status, 403);
  assert.equal((await ask("POST", "/index", { built: 0, events: [] }, PLAYER)).status, 403);
  assert.deepEqual((await ask("GET", "")).body, { rev: 0, rowsRev: 0, tables: { keys: 0, events: 0 }, index: null });
});

test("the derived index keeps the rows' revision it was built from and goes stale with the next change of rows", async () => {
  const { mapping, ask } = makeMapping();
  await ask("POST", "/edit", { edits: [add("keys", { key: "s2010", kind: "shared" })] });

  assert.equal((await ask("POST", "/index", { built: 0, events: [[7, 60]] })).body.code, MAPPING_REFUSAL.rev);
  const kept = await ask("POST", "/index", { built: 1, events: [[7, 60], [5, 27], [7, 60]] });
  assert.deepEqual([kept.body.rev, kept.body.index.events, kept.body.index.stale], [2, 2, false]);
  assert.deepEqual((await ask("GET", "/index")).body.index.events, [[5, 27], [7, 60]]);

  const game = (known) => handleMappingGameRequest(mapping, "GET", new URL(`https://relay/v1/story-mapping${known === undefined ? "" : `?known=${known}`}`));
  assert.deepEqual((await game()).body, { rev: 2, tables: { keys: [{ key: "s2010", kind: "shared" }], events: [] }, index: { built: 1, stale: false, events: [[5, 27], [7, 60]], commons: [] } });
  assert.deepEqual((await game(2)).body, { rev: 2, same: true });

  await ask("POST", "/edit", { edits: [add("keys", { key: "s2018", kind: "shared" })] });
  assert.deepEqual((await game(2)).body.index.stale, true);
  assert.deepEqual((await ask("GET", "")).body.index.stale, true);
});

test("the battle server's index keeps its common events and the game's names, which only the names route hands out", async () => {
  const { mapping, ask } = makeMapping();
  await ask("POST", "/edit", { edits: [add("keys", { key: "v1001", kind: "one_way" })] });
  const names = { switches: { 60: "Sonya met" }, variables: { 1001: "Story progress" }, maps: { 7: "Iliasville", 1848: "Mt. Horai" }, events: { "7.60": "EV060" }, companions: 3202 };

  assert.equal((await mapping.keepIndex({ built: 1, events: [[7, 60]], commons: [380, 154, 380], names: { ...names, events: { "7": "no event" } } }, BATTLE_SERVER_AUTHOR)).status, 400);
  assert.equal((await mapping.keepIndex({ built: 1, events: [], commons: [0] }, BATTLE_SERVER_AUTHOR)).status, 400);
  const kept = await mapping.keepIndex({ built: 1, events: [[7, 60]], commons: [380, 154, 380], names }, BATTLE_SERVER_AUTHOR);
  assert.deepEqual([kept.status, kept.body.index.commons, kept.body.index.author], [200, 2, BATTLE_SERVER_AUTHOR]);

  const index = (await ask("GET", "/index")).body.index;
  assert.deepEqual([index.commons, "names" in index], [[154, 380], false]);
  const game = (await handleMappingGameRequest(mapping, "GET", new URL("https://relay/v1/story-mapping"))).body.index;
  assert.deepEqual(game, { built: 1, stale: false, events: [[7, 60]], commons: [154, 380] });
  assert.deepEqual((await ask("GET", "/names")).body, { rowsRev: 1, names: { built: 1, stale: false, names, author: BATTLE_SERVER_AUTHOR, time: 1000 } });

  await ask("POST", "/edit", { edits: [add("keys", { key: "v1141", kind: "one_way" })] });
  assert.equal((await ask("GET", "/names")).body.names.stale, true);
});

test("seeds fill only the tables that hold no rows, in one revision without history and only once, and a seed row that does not read stops the seeding", async () => {
  const { mapping, ask } = makeMapping();
  await ask("POST", "/edit", { edits: [add("events", { key: "ss0.*.F", share: "shared" })] });

  const seeded = await mapping.seed({ keys: [{ key: "v1001", kind: "one_way" }, { key: "s2029", kind: "scene" }], events: [{ key: "ce154.*", share: "shared" }] });
  assert.deepEqual(seeded, { rev: 2, seeded: { keys: 2 } });

  const read = (await handleMappingGameRequest(mapping, "GET", new URL("https://relay/v1/story-mapping"))).body;
  assert.deepEqual([read.rev, read.tables.keys.map((row) => row.key), read.tables.events.map((row) => row.key)], [2, ["s2029", "v1001"], ["ss0.*.F"]]);
  assert.deepEqual((await ask("GET", "/keys")).body.rows.map((row) => [row.author, row.rev]), [[SEED_AUTHOR, 2], [SEED_AUTHOR, 2]]);
  assert.deepEqual((await ask("GET", "/keys/v1001/history")).body.history, []);
  assert.deepEqual(await mapping.seed({ keys: [{ key: "v1141", kind: "one_way" }], events: [] }), { rev: 2, seeded: {} }, "a table with rows is left as it is");

  await ask("POST", "/edit", { edits: [{ table: "keys", op: "remove", id: "v1001" }, { table: "keys", op: "remove", id: "s2029" }] });
  await ask("POST", "/edit", { edits: [{ table: "events", op: "remove", id: "ss0.*.F" }] });
  assert.deepEqual(await mapping.seed({ keys: [{ key: "v1141", kind: "one_way" }], events: [{ key: "ce154.*", share: "shared" }] }), { rev: 4, seeded: {} },
    "a table the seeding filled or found with rows stays empty once the admins emptied it");

  await assert.rejects(mapping.seed({ parts: [{ id: "1" }] }), /seed of parts must be a list of rows of a table/);
  const { mapping: empty } = makeMapping();
  await assert.rejects(empty.seed({ keys: [{ key: "v1001", kind: "later" }] }), /seed row 0 of keys: kind must be/);
  await assert.rejects(empty.seed({ keys: [{ key: "v1001", kind: "shared" }, { key: "v1001", kind: "one_way" }] }), /seed rows of keys name v1001 twice/);
  assert.equal((await empty.meta()).rev, 0, "a refused seeding changes nothing");
});
