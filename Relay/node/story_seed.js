//----------------------------------------------------------------
//  story_seed.js
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

// The seed rows of the story tables: one JSON file per table under seed/story, holding either
// `rows` (each as an admin would add it) and `source` (where they came from), or the list of edits
// an admin would send to POST /v1/admin/story/edit, each an `add` of the file's table. The relay's
// start fills every table that holds no rows yet from them, once, see StoryMapping.seed in
// core/story_mapping.js; a relay installed without the folder seeds nothing.

import { readFile, readdir } from "node:fs/promises";
import { basename, extname, join } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * The folder of the seed files.
 */
export const STORY_SEED_FOLDER = fileURLToPath(new URL("../seed/story/", import.meta.url));

/**
 * Lists the seed files of a folder.
 *
 * @param {string} folder The folder.
 * @returns {Promise<string[] | null>} The file names in order; null when there is no such folder.
 */
async function seedFileNames(folder) {
  try {
    return (await readdir(folder)).filter((name) => extname(name) === ".json").sort();
  } catch (error) {
    if (error.code === "ENOENT") {
      return null;
    }

    throw error;
  }
}

/**
 * Takes the rows of one seed file: its `rows`, or the `row` of each edit adding one to its table.
 *
 * @param {string} name The file's name.
 * @param {string} table The table the file is named after.
 * @param {unknown} file The file's JSON.
 * @returns {object[]} The rows.
 * @throws {Error} The file is neither a list of rows nor a list of edits adding rows of its table.
 */
function rowsOf(name, table, file) {
  if (Array.isArray(file)) {
    return file.map((edit, index) => {
      if (!edit || typeof edit !== "object" || edit.op !== "add" || edit.table !== table || !edit.row || typeof edit.row !== "object") {
        throw new Error(`edit ${index} of the seed file ${name} must add a row of ${table}`);
      }

      return edit.row;
    });
  }

  if (!file || typeof file !== "object" || !Array.isArray(file.rows)) {
    throw new Error(`the seed file ${name} must be a JSON object with rows or a list of edits adding rows`);
  }

  return file.rows;
}

/**
 * Reads the seed rows of every table that has a file, `<table>.json`.
 *
 * @param {string} [folder] The folder, STORY_SEED_FOLDER unless given.
 * @returns {Promise<Object<string, object[]> | null>} The rows by table; null when there is no such folder.
 * @throws {Error} A file is neither a list of rows nor a list of edits adding rows, see rowsOf.
 */
export async function readStorySeeds(folder = STORY_SEED_FOLDER) {
  const names = await seedFileNames(folder);

  if (names === null) {
    return null;
  }

  const seeds = {};

  for (const name of names) {
    const table = basename(name, ".json");
    seeds[table] = rowsOf(name, table, JSON.parse(await readFile(join(folder, name), "utf8")));
  }

  return seeds;
}

/**
 * Fills the story tables that hold no rows yet from the seed files and logs what they took, or
 * that there is no seed folder.
 *
 * @param {import("../core/story_mapping.js").StoryMapping} mapping The story mapping.
 * @param {{info: (line: string) => void}} log The log.
 * @param {string} [folder] The folder of the seed files, STORY_SEED_FOLDER unless given.
 * @returns {Promise<{rev: number, seeded: Object<string, number>}>} See StoryMapping.seed.
 */
export async function seedStoryTables(mapping, log, folder = STORY_SEED_FOLDER) {
  const seeds = await readStorySeeds(folder);

  if (seeds === null) {
    log.info(`no seed folder at ${folder}, nothing seeded`);
    return mapping.seed({});
  }

  const done = await mapping.seed(seeds);
  const tables = Object.entries(done.seeded);

  if (tables.length > 0) {
    log.info(`seeded the story tables to rev ${done.rev}: ${tables.map(([table, count]) => `${table} ${count}`).join(", ")}`);
  }

  return done;
}
