//----------------------------------------------------------------
//  story_catchup.test.js
//
//  Changelog:
//      Paulinchen  2026-11-06: Ran over SQLite stores in memory
//      Paulinchen  2026-11-05: Tested a world chest without chest flags, and one kept before read without them
//                            - Dropped the check of the prize counts
//      Paulinchen  2026-10-31: Checked that a world chest's flags still go to released builds
//      Paulinchen  2026-10-28: Checked the free order rule
//                            - Checked a prize by its switch
//                            - Checked a world chest the game shuts by a switch
//                            - Checked the chests and chest flags a party member keeps their own of
//                            - Checked the rules, counts, actor changes and prizes of the catch-up
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { openSqliteStores } from "../node/sqlite_store.js";
import { CATCHUP_TABLES, STORY_TABLES } from "./story_catchup.js";
import { MAPPING_REFUSAL, StoryMapping, readRow } from "./story_mapping.js";

/**
 * The admin's player id.
 */
const ADMIN = "ad".repeat(16);

/**
 * A join as world_catchup_data.rbx lists it: Alice's at Iliasville.
 */
const JOIN = Object.freeze({ actor: 5, persona: 5, site: "map:6:30:2", part: "1", step: 6, side: null, marks: [["v", 1001, 7]], gate: 2, rule: "start", index: 169, ran: true });

/**
 * Makes a story mapping with the catch-up tables over a SQLite database in memory.
 *
 * @returns {StoryMapping} The mapping.
 */
function makeMapping() {
  return new StoryMapping(openSqliteStores(":memory:").mapping, { tables: STORY_TABLES, clock: () => 1000 });
}

test("the relay numbers rows without a key of their own, never twice, and games read them in story order", async () => {
  const mapping = makeMapping();
  const added = await mapping.edit({ edits: [
    { table: "joins", op: "add", row: { ...JOIN, order: 20 } },
    { table: "joins", op: "add", row: { ...JOIN, actor: 26, persona: 26, site: "map:6:31:2", index: 203, order: 10 } },
    { table: "joins", op: "add", row: { ...JOIN, actor: 53, persona: 53, site: "map:7:63:1", step: 5, index: 33, order: 20 } },
  ] }, ADMIN);
  assert.deepEqual(added.body.changed.map((change) => change.id), ["1", "2", "3"]);

  await mapping.edit({ edits: [{ table: "joins", op: "remove", id: "3" }] }, ADMIN);
  const again = await mapping.edit({ edits: [{ table: "joins", op: "add", row: { ...JOIN, actor: 53, persona: 53, order: 30 } }] }, ADMIN);
  assert.equal(again.body.changed[0].id, "4");

  const read = (await mapping.forGames(null)).body;
  assert.deepEqual(read.tables.joins.map((row) => row.actor), [26, 5, 53]);
  assert.deepEqual(Object.keys(read.tables), Object.keys(STORY_TABLES));
});

test("each catch-up row needs every field its Ruby row holds, and its fields must fit together", () => {
  const code = (table, row) => readRow(CATCHUP_TABLES[table], row).code ?? null;

  assert.equal(code("joins", { ...JOIN, order: 0 }), null);
  assert.equal(code("joins", JOIN), MAPPING_REFUSAL.field, "an ordered table needs the row's order");
  assert.equal(code("joins", { ...JOIN, order: 0, rule: "level" }), MAPPING_REFUSAL.field);
  assert.equal(code("joins", { ...JOIN, order: 0, marks: [["v", 1001]] }), MAPPING_REFUSAL.field);
  assert.equal(code("key_items", { item: 502, amount: 0, site: "map:6:33:1", part: "1", step: 5, side: null, marks: [], ran: false, order: 0 }), MAPPING_REFUSAL.field);

  const setting = { site: "map:545:1:1", part: "1", step: 0, side: null, marks: [["v", 1001, 0]], ran: true, order: 0 };
  assert.equal(code("settings", { ...setting, kind: "encounters", id: 0, value: false }), null);
  assert.equal(code("settings", { ...setting, kind: "encounters", id: 0, value: 1 }), MAPPING_REFUSAL.field);
  assert.equal(code("settings", { ...setting, kind: "variable", id: 1002, value: true }), MAPPING_REFUSAL.field);

  const reward = { sided: false, route: false, final: false };
  assert.equal(code("event_rewards", { ...reward, kind: "item", id: 501, most: 1, final: true }), null);
  assert.equal(code("event_rewards", { ...reward, kind: "item", id: 501, most: null }), MAPPING_REFUSAL.field);
  assert.equal(code("event_rewards", { ...reward, kind: "companion", id: 5, most: null, route: true }), MAPPING_REFUSAL.field);
});

test("a world chest and its self switch go in one batch, and keyed catch-up rows keep their key", async () => {
  const mapping = makeMapping();
  const chest = { key: "ss127.81.A", items: [511], part: "1", step: 7, order: 0 };
  const done = await mapping.edit({ edits: [{ table: "chests", op: "add", row: chest }, { table: "events", op: "add", row: { key: "ss127.81.A", share: "shared" } }] }, ADMIN);
  assert.deepEqual(done.body, { rev: 1, changed: [{ table: "chests", id: "ss127.81.A", op: "add" }, { table: "events", id: "ss127.81.A", op: "add" }] });

  const moved = await mapping.edit({ edits: [{ table: "chests", op: "change", id: "ss127.81.A", row: { ...chest, key: "ss127.81.B" } }] }, ADMIN);
  assert.equal(moved.body.code, MAPPING_REFUSAL.key);
  assert.equal(readRow(CATCHUP_TABLES.chests, { ...chest, key: "s2719" }).code ?? null, null, "a chest the game shuts by a switch goes by its switch");
  assert.equal(readRow(CATCHUP_TABLES.chests, { ...chest, key: "v2719" }).code, MAPPING_REFUSAL.field);
  assert.equal((await mapping.edit({ edits: [{ table: "makina", op: "add", row: { item: 700, level: 6, site: "map:215:23:1" } }, { table: "makina", op: "add", row: { item: 700, level: 7, site: "map:215:23:1" } }] }, ADMIN)).body.code, MAPPING_REFUSAL.twice);
});

test("a world chest keeps no chest flags, and one kept before is read without them", async () => {
  const mapping = makeMapping();
  const chest = { key: "ss588.9.A", items: [606], part: "chaos", step: 12, order: 0 };
  assert.equal(readRow(CATCHUP_TABLES.chests, { ...chest, flags: [7102] }).code, MAPPING_REFUSAL.field);

  // A row an older relay kept with the chest's flags.
  await mapping.edit({ edits: [{ table: "chests", op: "add", row: chest }] }, ADMIN);
  const kept = (await mapping.store.all(CATCHUP_TABLES.chests.store))[0];
  await mapping.store.commit({ meta: await mapping.store.getMeta(), puts: [{ table: CATCHUP_TABLES.chests.store, entry: { ...kept, row: { ...kept.row, flags: [7102] } } }], removes: [], changes: [] }, 10);
  assert.deepEqual((await mapping.forGames(null)).body.tables.chests, [chest]);
  assert.deepEqual((await mapping.rows("chests")).body.rows.map((entry) => entry.row), [chest]);
});

test("a party member's own chests are rows by their self switch, the chest flags by their switch", async () => {
  const mapping = makeMapping();
  const done = await mapping.edit({ edits: [{ table: "party_chests", op: "add", row: { key: "ss6.9.A" } }, { table: "chest_flags", op: "add", row: { switch: 2045 } }] }, ADMIN);
  assert.deepEqual(done.body.changed.map((change) => change.id), ["ss6.9.A", "2045"]);
  assert.equal(readRow(CATCHUP_TABLES.party_chests, { key: "6.9.A" }).code, MAPPING_REFUSAL.field);
  assert.equal(readRow(CATCHUP_TABLES.chest_flags, { switch: 0 }).code, MAPPING_REFUSAL.field);

  const read = (await mapping.forGames(null)).body.tables;
  assert.deepEqual([read.party_chests, read.chest_flags], [[{ key: "ss6.9.A" }], [{ switch: 2045 }]]);
});

test("each rule of the catch-up is one row by its name, with the value its rule takes", async () => {
  const code = (row) => readRow(CATCHUP_TABLES.rules, row).code ?? null;

  assert.equal(code({ rule: "lasting_companions", value: [5, 26, 29, 30] }), null);
  assert.equal(code({ rule: "side_companions", value: { alice: 5, ilias: 26 } }), null);
  assert.equal(code({ rule: "orb_event", value: 330 }), null);
  assert.equal(code({ rule: "free_order", value: [{ part: "chaos", step: 21 }] }), null);
  assert.equal(code({ rule: "free_order", value: [{ part: "ilias", step: 21 }] }), MAPPING_REFUSAL.field);
  assert.equal(code({ rule: "orb_event", value: [330] }), MAPPING_REFUSAL.field);
  assert.equal(code({ rule: "side_companions", value: { alice: 5 } }), MAPPING_REFUSAL.field);
  assert.equal(code({ rule: "playthrough", value: 912 }), MAPPING_REFUSAL.field);

  const mapping = makeMapping();
  await mapping.edit({ edits: [{ table: "rules", op: "add", row: { rule: "side_step", value: 7 } }] }, ADMIN);
  assert.equal((await mapping.edit({ edits: [{ table: "rules", op: "add", row: { rule: "side_step", value: 8 } }] }, ADMIN)).body.code, MAPPING_REFUSAL.exists);
  assert.deepEqual((await mapping.forGames(null)).body.tables.rules, [{ rule: "side_step", value: 7 }]);
});

test("a count names its switches with their weights and its last value with its switch, an actor change its calls, a prize its variable or switch", () => {
  const code = (table, row) => readRow(CATCHUP_TABLES[table], row).code ?? null;
  const count = { variable: 1353, weights: [{ switch: 3204, weight: 1 }, { switch: 3211, weight: 2 }], doneSwitch: 7034, doneValue: 15, since: { variable: 1312, atLeast: 3 } };
  const change = { actor: 5, calls: [["persona_change", [6], false], ["level_adjust", [6, 65], false]], gate: 65, site: "map:1650:19:1", part: "ad", step: 18, side: null, marks: [["v", 1141, 18]], ran: true, order: 0 };

  assert.equal(code("counts", count), null);
  assert.equal(code("counts", { ...count, doneSwitch: null, doneValue: null, since: null }), null);
  assert.equal(code("counts", { ...count, doneValue: null }), MAPPING_REFUSAL.field, "a last value needs its switch");
  assert.equal(code("counts", { ...count, weights: [[3204, 1]] }), MAPPING_REFUSAL.field);
  assert.equal(code("actor_changes", change), null);
  assert.equal(code("actor_changes", { ...change, gate: null }), null);
  assert.equal(code("actor_changes", { ...change, calls: [["change_class", [6, 1], false]] }), MAPPING_REFUSAL.field);
  assert.equal(code("actor_changes", { ...change, calls: [["persona_change", [], false]] }), MAPPING_REFUSAL.field);
  assert.equal(code("prize_switches", { switch: 2324 }), null);
  assert.equal(code("prize_switches", { variable: 2324 }), MAPPING_REFUSAL.field);
});
