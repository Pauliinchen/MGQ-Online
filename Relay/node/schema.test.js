//----------------------------------------------------------------
//  schema.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Tested that step 3 adds the live build each design build was compiled against
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { DESIGN_TABLE_NAMES, STEPS, migrate, versionOf } from "./schema.js";
import { openSqliteStores } from "./sqlite_store.js";

/**
 * The folder the test databases live in, deleted afterwards.
 */
let folder;

before(() => {
  folder = mkdtempSync(join(tmpdir(), "mgq-schema-"));
});

after(() => {
  rmSync(folder, { recursive: true, force: true });
});

/**
 * Lists a database's tables.
 *
 * @param {DatabaseSync} db The database.
 * @returns {string[]} Their names, sorted.
 */
function tablesOf(db) {
  return db.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name").all().map((row) => row.name);
}

test("a database the relay kept before the steps keeps every record, gains the design tables at step 2 and the base of each build at step 3, once", async () => {
  const path = join(folder, "live.db");
  const live = openSqliteStores(path);
  await live.directory.put({ id: "a".repeat(32), name: "Raid Night" });
  await live.releases.putRelease("0.6.7.7");
  live.close();

  const db = new DatabaseSync(path);
  const before = tablesOf(db);
  assert.equal(versionOf(db), 0);
  assert.equal(migrate(db, STEPS), 3);
  assert.deepEqual(tablesOf(db), [...before, ...DESIGN_TABLE_NAMES].sort());
  assert.ok(db.prepare("PRAGMA table_info(design_builds)").all().some((column) => column.name === "base_build_id"));
  assert.equal(migrate(db, STEPS), 3, "a second run changes nothing");
  db.close();

  const again = openSqliteStores(path);
  assert.equal((await again.directory.get("a".repeat(32))).name, "Raid Night");
  assert.equal(await again.releases.getRelease(), "0.6.7.7");
  again.close();
});

test("step 1 makes the relay's own tables in a new database, and a failing step leaves the database as it was", () => {
  const db = new DatabaseSync(join(folder, "fresh.db"));
  assert.equal(migrate(db, [STEPS[0]]), 1);
  assert.ok(tablesOf(db).includes("worlds") && tablesOf(db).includes("boss_pools"));
  assert.throws(() => migrate(db, [STEPS[0], ["CREATE TABLE half (id TEXT)", "NOT SQL"]]));
  assert.equal(versionOf(db), 1);
  assert.equal(tablesOf(db).includes("half"), false);
  db.close();
});

test("a database newer than the relay's steps is refused", () => {
  const db = new DatabaseSync(":memory:");
  db.exec("PRAGMA user_version = 9");
  assert.throws(() => migrate(db, STEPS), /step 9/);
  db.close();
});
