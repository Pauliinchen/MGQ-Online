//----------------------------------------------------------------
//  design_store_sqlite.test.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { memoryDesignStore } from "../core/design_store_memory.js";
import { DESIGNERS, fixtureBook, replayScenarios, send } from "../core/test_designs.js";
import { openSqliteDesignStore } from "./design_store_sqlite.js";

/**
 * The folder the test databases live in, deleted afterwards.
 */
let folder;

/**
 * How many databases the tests opened, for a new file each.
 */
let opened = 0;

before(() => {
  folder = mkdtempSync(join(tmpdir(), "mgq-designs-"));
});

after(() => {
  rmSync(folder, { recursive: true, force: true });
});

/**
 * Opens the design store over a new database file.
 *
 * @returns {import("../core/designs.js").DesignStore} The store.
 */
function freshStore() {
  return openSqliteDesignStore(join(folder, `designs-${++opened}.db`));
}

/**
 * The headers of designer A, a listed admin, on a released version.
 */
const A = { "X-MGQ-Designer": DESIGNERS.A.key, "X-MGQ-Designer-Version": "1.3.0", "X-MGQ-Design-Format": "1" };

/**
 * Pushes changes as designer A.
 *
 * @param {import("../core/designs.js").DesignBook} book The design.
 * @param {object[]} changes The changes.
 * @returns {Promise<{status: number, body: any}>} The answer.
 */
function push(book, changes) {
  return send(book, { method: "POST", path: "/v1/designs/push", headers: A, body: { designFormat: 1, message: "test", changes } });
}

/**
 * Edits, deletes and restores entities, renames a designer, and keeps a blob, through a store.
 *
 * @param {import("../core/designs.js").DesignStore} store The store.
 * @returns {Promise<Record<string, object[]>>} The store's tables afterwards, as JSON reads them.
 */
async function workThrough(store) {
  const book = await fixtureBook(store);
  await push(book, [{ id: "rules", kind: "rules", schema: 1, baseRev: 0, body: { units: { cap: 16 } } }, { id: "state:4", kind: "state", schema: 1, baseRev: 0, body: { hardCc: true } }]);
  await push(book, [{ id: "state:4", kind: "state", schema: 2, baseRev: 1, body: null }]);
  await push(book, [{ id: "state:4", kind: "state", schema: 2, baseRev: 2, body: { minTurns: 2 } }]);
  await send(book, { method: "PUT", path: "/v1/designs/me", headers: A, body: { name: "Alice" } });
  await store.importTables({ design_blobs: [{ sha256: "ab".repeat(32), kind: "runtime", size: 3, at: 5 }] }, new Map([["ab".repeat(32), new Uint8Array([1, 2, 3])]]));
  return JSON.parse(JSON.stringify(await store.exportTables()));
}

test("the contract's exchanges are answered as the fixtures show over SQLite too", async () => {
  for (const { file, name, expected, actual } of await replayScenarios(freshStore)) {
    assert.deepEqual(actual, expected, `${file}: ${name}`);
  }
});

test("the SQLite store keeps the same rows as the memory store", async () => {
  const sqlite = freshStore();
  const memory = memoryDesignStore();

  try {
    const tables = await workThrough(sqlite);
    assert.deepEqual(tables, await workThrough(memory));
    assert.deepEqual(tables.design_history.map((row) => [row.id, row.rev, row.deleted]), [["rules", 1, 0], ["state:4", 1, 0], ["state:4", 2, 1], ["state:4", 3, 0]]);
    assert.deepEqual(tables.design_blobs, [{ sha256: "ab".repeat(32), kind: "runtime", size: 3, at: 5 }]);
    assert.deepEqual(await sqlite.blob("ab".repeat(32)), new Uint8Array([1, 2, 3]));
    assert.deepEqual(await memory.blob("ab".repeat(32)), new Uint8Array([1, 2, 3]));
  } finally {
    sqlite.close();
  }
});

test("the design outlasts a restart, and an export read into a new database comes out the same", async () => {
  const path = join(folder, "restart.db");
  const first = openSqliteDesignStore(path);
  const tables = await workThrough(first);
  first.close();

  const again = openSqliteDesignStore(path);
  const book = await fixtureBook(again);
  const pulled = await send(book, { method: "GET", path: "/v1/designs/entities?since=0", headers: A, body: null });
  assert.deepEqual(pulled.body.entities.map((entity) => [entity.id, entity.rev, entity.schema, entity.body]), [["rules", 1, 1, { units: { cap: 16 } }], ["state:4", 3, 2, { minTurns: 2 }]]);
  again.close();

  const copy = freshStore();

  try {
    await copy.importTables(tables, new Map([["ab".repeat(32), new Uint8Array([1, 2, 3])]]));
    assert.deepEqual(JSON.parse(JSON.stringify(await copy.exportTables())), tables);
    await assert.rejects(copy.importTables({ designers: [{ "id) VALUES (1); --": "x" }] }, new Map()), /no plain name/);
  } finally {
    copy.close();
  }
});
