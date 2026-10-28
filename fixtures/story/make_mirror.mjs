//----------------------------------------------------------------
//  make_mirror.mjs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

// Writes mirror.json next to this file: the story mapping as the relay hands it to games
// (StoryMapping.forGames of Relay/core/story_mapping.js), seeded with a sample of every table of
// Relay/seed/story and a derived index. MGQOnline.Data.Tests writes it into the relay
// mirror and reads it back, and MGQParadox.Multiplayer.Tests fetches it as the relay's answer. Run
// it again only when the relay's tables change, with Node 24:
//
//   node fixtures/story/make_mirror.mjs

import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { STORY_TABLES } from "../../Relay/core/story_catchup.js";
import { StoryMapping } from "../../Relay/core/story_mapping.js";
import { readStorySeeds } from "../../Relay/node/story_seed.js";

/**
 * How many rows of each table the fixture keeps.
 */
const ROWS_PER_TABLE = 3;

/**
 * Makes a store of the story mapping in memory, as the relay's tests do.
 *
 * @returns {import("../../Relay/core/story_mapping.js").StoryMappingStore} The store.
 */
function memoryStore() {
  const kept = { meta: undefined, index: undefined, tables: new Map() };
  const table = (name) => kept.tables.get(name) ?? kept.tables.set(name, new Map()).get(name);

  return {
    getMeta: async () => structuredClone(kept.meta),
    all: async (name) => [...table(name).values()].map((entry) => structuredClone(entry)),
    get: async (name, id) => structuredClone(table(name).get(id)),
    history: async () => [],
    commit: async (commit) => {
      kept.meta = structuredClone(commit.meta);
      commit.puts.forEach(({ table: name, entry }) => table(name).set(entry.id, structuredClone(entry)));
      commit.removes.forEach(({ table: name, id }) => table(name).delete(id));
      kept.index = commit.index ? structuredClone(commit.index) : kept.index;
    },
    getIndex: async () => structuredClone(kept.index),
  };
}

/**
 * Samples a table's seed rows: the first ones, and the first row with each field none of them has,
 * so every option of a row is in the fixture.
 *
 * @param {object[]} rows The rows.
 * @returns {object[]} The sample, in the seed's order.
 */
function sample(rows) {
  const kept = rows.slice(0, ROWS_PER_TABLE);
  const fields = new Set(kept.flatMap((row) => Object.keys(row)));

  for (const row of rows.slice(ROWS_PER_TABLE)) {
    if (Object.keys(row).some((field) => !fields.has(field))) {
      kept.push(row);
      Object.keys(row).forEach((field) => fields.add(field));
    }
  }

  return kept;
}

const seeds = await readStorySeeds();
const sampled = Object.fromEntries(Object.entries(seeds).map(([name, rows]) => [name, sample(rows)]));
const mapping = new StoryMapping(memoryStore(), { tables: STORY_TABLES, clock: () => 1000 });
const { rev } = await mapping.seed(sampled);
await mapping.keepIndex({ built: rev, events: [[7, 39], [40, 2]], commons: [154] }, "fixture");
const { body } = await mapping.forGames(null);
const text = `{\n  "source": ${JSON.stringify(`StoryMapping.forGames of Relay/core/story_mapping.js over a sample of the seed rows of each table, Node ${process.versions.node}`)},\n  "mapping": ${JSON.stringify(body)}\n}\n`;
writeFileSync(fileURLToPath(new URL("mirror.json", import.meta.url)), text);
