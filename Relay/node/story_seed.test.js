//----------------------------------------------------------------
//  story_seed.test.js
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { CATCHUP_RULES, STORY_TABLES } from "../core/story_catchup.js";
import { StoryMapping } from "../core/story_mapping.js";
import { memoryMappingStore, openStores } from "./server.js";
import { STORY_SEED_FOLDER, readStorySeeds, seedStoryTables } from "./story_seed.js";

/**
 * Makes an empty story mapping with every table over a store in memory.
 *
 * @returns {StoryMapping} The mapping.
 */
function makeMapping() {
  return new StoryMapping(memoryMappingStore(), { tables: STORY_TABLES, clock: () => 1000 });
}

test("the seed files hold the hand-kept rules of the catch-up alone, which fill their tables at a start", async () => {
  const seeds = await readStorySeeds();
  const lines = [];
  const mapping = makeMapping();

  assert.deepEqual(Object.keys(seeds).sort(), ["companion_values", "counts", "rules"], "no generated and unreviewed rows are seeded");
  assert.deepEqual(seeds.rules.map((row) => row.rule).sort(), Object.keys(CATCHUP_RULES).sort());

  const done = await seedStoryTables(mapping, { info: (line) => lines.push(line) });
  assert.equal(done.rev, 1);
  assert.deepEqual(Object.keys(done.seeded).sort(), Object.keys(seeds).sort());
  assert.ok(lines[0].startsWith("seeded the story tables to rev 1: "));

  const read = (await mapping.forGames(null)).body;
  assert.deepEqual(read.tables.counts.map((row) => row.variable), [1353, 1354]);
  assert.deepEqual(read.tables.companion_values.map((row) => row.actor), [540]);
  assert.deepEqual(read.tables.joins, [], "the generated joins start empty, for the admins to fill with reviewed rows");

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

test("the seeded rows outlast a restart, which seeds nothing more", async () => {
  const folder = mkdtempSync(join(tmpdir(), "mgq-seed-db-"));
  const path = join(folder, "relay.sqlite");
  const first = await openStores(path);

  try {
    const seeded = await seedStoryTables(new StoryMapping(first.mapping, { tables: STORY_TABLES }), { info: () => {} });
    first.close();
    const second = await openStores(path);

    try {
      const mapping = new StoryMapping(second.mapping, { tables: STORY_TABLES });
      assert.deepEqual(await seedStoryTables(mapping, { info: () => assert.fail("nothing to log") }), { rev: seeded.rev, seeded: {} });
      assert.equal((await mapping.rows("rules")).body.rows.length, 6);
    } finally {
      second.close();
    }
  } finally {
    rmSync(folder, { recursive: true, force: true });
  }
});
