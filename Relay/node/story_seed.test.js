//----------------------------------------------------------------
//  story_seed.test.js
//
//  Changelog:
//      Paulinchen  2026-11-06: Ran over SQLite stores in memory
//      Paulinchen  2026-10-28: Counted the seeded rules by the rules the relay knows
//                            - Seeded the reviewed rows of every story table and kept a table the admins emptied empty
//                            - Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { CATCHUP_RULES, STORY_TABLES } from "../core/story_catchup.js";
import { StoryMapping } from "../core/story_mapping.js";
import { openStores } from "./server.js";
import { STORY_SEED_FOLDER, readStorySeeds, seedStoryTables } from "./story_seed.js";

/**
 * Makes an empty story mapping with every table over a store in memory.
 *
 * @returns {StoryMapping} The mapping.
 */
function makeMapping() {
  return new StoryMapping(openStores().mapping, { tables: STORY_TABLES, clock: () => 1000 });
}

test("the seed files hold the hand-kept rules and the reviewed rows of story tables, which fill a fresh relay at its start", async () => {
  const seeds = await readStorySeeds();
  const lines = [];
  const mapping = makeMapping();

  assert.deepEqual(Object.keys(seeds).filter((table) => !STORY_TABLES[table]), [], "every seed file names a story table");
  assert.ok(["rules", "counts", "companion_values"].every((table) => seeds[table]), "the hand-kept tables are seeded");
  assert.deepEqual(seeds.rules.map((row) => row.rule).sort(), Object.keys(CATCHUP_RULES).sort());

  const done = await seedStoryTables(mapping, { info: (line) => lines.push(line) });
  assert.equal(done.rev, 1);
  assert.deepEqual(done.seeded, Object.fromEntries(Object.entries(seeds).map(([table, rows]) => [table, rows.length])));
  assert.ok(lines[0].startsWith("seeded the story tables to rev 1: "));

  const read = (await mapping.forGames(null)).body;
  assert.deepEqual(read.tables.counts.map((row) => row.variable), [1353, 1354]);
  assert.deepEqual(read.tables.companion_values.map((row) => row.actor), [540]);

  for (const [table, rows] of Object.entries(seeds)) {
    assert.equal(read.tables[table].length, rows.length, `${table} holds every seed row`);
  }

  assert.deepEqual(await seedStoryTables(mapping, { info: () => assert.fail("nothing to log") }), { rev: 1, seeded: {} }, "a second start seeds nothing");
});

test("a seed file is a list of rows or a list of edits adding them, and anything else stops the start", async () => {
  const folder = mkdtempSync(join(tmpdir(), "mgq-seed-"));

  try {
    writeFileSync(join(folder, "makina.json"), JSON.stringify({ rows: { item: 700 } }));
    await assert.rejects(readStorySeeds(folder), /makina.json must be a JSON object with rows or a list of edits/);
    writeFileSync(join(folder, "makina.json"), JSON.stringify({ rows: [{ item: 700, level: 6, site: "nowhere" }] }));
    await assert.rejects(seedStoryTables(makeMapping(), { info: () => {} }, folder), /seed row 0 of makina/);

    writeFileSync(join(folder, "makina.json"), JSON.stringify([{ op: "add", table: "makina", row: { item: 700, level: 6, site: "map:215:23:1" } }, { op: "remove", table: "makina", id: "700" }]));
    await assert.rejects(readStorySeeds(folder), /edit 1 of the seed file makina.json must add a row of makina/);
    writeFileSync(join(folder, "makina.json"), JSON.stringify([{ op: "add", table: "makina", row: { item: 700, level: 6, site: "map:215:23:1" } }, { op: "add", table: "parts", row: { id: "1" } }]));
    await assert.rejects(readStorySeeds(folder), /edit 1 of the seed file makina.json must add a row of makina/);

    writeFileSync(join(folder, "makina.json"), JSON.stringify([{ op: "add", table: "makina", row: { item: 700, level: 6, site: "map:215:23:1" } }]));
    const mapping = makeMapping();
    assert.deepEqual(await seedStoryTables(mapping, { info: () => {} }, folder), { rev: 1, seeded: { makina: 1 } }, "the reviewed rows seed as edits, as an admin would add them");
    assert.deepEqual((await mapping.forGames(null)).body.tables.makina, [{ item: 700, level: 6, site: "map:215:23:1" }]);
  } finally {
    rmSync(folder, { recursive: true, force: true });
  }

  assert.ok(STORY_SEED_FOLDER.endsWith("story\\") || STORY_SEED_FOLDER.endsWith("story/"));
});

test("a relay installed without the seed folder starts and seeds nothing", async () => {
  const folder = join(mkdtempSync(join(tmpdir(), "mgq-seed-none-")), "story");
  const lines = [];

  assert.equal(await readStorySeeds(folder), null);
  assert.deepEqual(await seedStoryTables(makeMapping(), { info: (line) => lines.push(line) }, folder), { rev: 0, seeded: {} });
  assert.deepEqual(lines, [`no seed folder at ${folder}, nothing seeded`]);
});

test("the seeded rows outlast a restart, which seeds nothing more, not even a table the admins emptied", async () => {
  const folder = mkdtempSync(join(tmpdir(), "mgq-seed-db-"));
  const path = join(folder, "relay.sqlite");
  const first = await openStores(path);
  let emptied;

  try {
    const mapping = new StoryMapping(first.mapping, { tables: STORY_TABLES });
    await seedStoryTables(mapping, { info: () => {} });
    const counts = (await mapping.rows("counts")).body.rows;
    assert.ok(counts.length > 0);
    emptied = await mapping.edit({ edits: counts.map((entry) => ({ op: "remove", table: "counts", id: entry.id })) }, "admin");
    assert.equal(emptied.status, 200);
  } finally {
    first.close();
  }

  const second = await openStores(path);

  try {
    const mapping = new StoryMapping(second.mapping, { tables: STORY_TABLES });
    assert.deepEqual(await seedStoryTables(mapping, { info: () => assert.fail("nothing to log") }), { rev: emptied.body.rev, seeded: {} });
    assert.equal((await mapping.rows("rules")).body.rows.length, Object.keys(CATCHUP_RULES).length);
    assert.deepEqual((await mapping.rows("counts")).body.rows, [], "the emptied table stays empty");
  } finally {
    second.close();
    rmSync(folder, { recursive: true, force: true });
  }
});
