//----------------------------------------------------------------
//  design_store_sqlite.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Tested that both stores keep the live build each build was compiled against
//                            - Tested that both stores keep builds, blobs and the live build alike
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

/**
 * Queues, finishes, fails and tidies builds, keeps their blobs and sets the live build, through a store.
 *
 * @param {import("../core/designs.js").DesignStore} store The store.
 * @returns {Promise<{tables: Record<string, object[]>, results: object}>} The store's tables afterwards, as JSON reads them, and what each call handed out.
 */
async function buildThrough(store) {
  const blob = (sha256, kind) => ({ sha256, kind, size: 4, gz: new Uint8Array([kind.length, 1, 2, 3]), at: 9 });
  const fields = (status, marshal, baseBuildId = null) => ({
    status, report: JSON.stringify({ ok: status === "ok" }), snapshotSha: "11".repeat(32), runtimeSha: "22".repeat(32), marshalSha: marshal, format: 3, runtimeFormat: 1, compiler: "1.3.0", gameData: "33".repeat(32), baseBuildId,
  });
  const ids = [];

  for (let seq = 1; seq <= 5; seq++) {
    ids.push(await store.addBuild({ seq, by: DESIGNERS.A.id, at: seq }));
  }

  await store.setBuildStatus(1, "compiling");
  await store.finishBuild(1, fields("ok", "44".repeat(32)), [blob("11".repeat(32), "snapshot"), blob("22".repeat(32), "runtime"), blob("44".repeat(32), "marshal")]);
  await store.finishBuild(2, fields("ok", "55".repeat(32), 1), [blob("11".repeat(32), "snapshot"), blob("22".repeat(32), "runtime"), blob("55".repeat(32), "marshal")]);
  await store.finishBuild(3, fields("ok", "66".repeat(32)), [blob("66".repeat(32), "marshal")]);
  await store.setLive({ buildId: 2, previousBuildId: 1, by: DESIGNERS.A.id, at: 7 });
  await store.setBuildStatus(4, "compiling");
  const failed = await store.failUnfinished("{\"ok\":false}");
  const tidied = await store.tidyBuilds(2);
  const results = { ids, failed, tidied, live: await store.live(), info: await store.blobInfo("55".repeat(32)), gone: await store.blob("66".repeat(32)), newest: (await store.builds(2)).map((row) => row.id) };
  return { tables: JSON.parse(JSON.stringify(await store.exportTables())), results };
}

test("the SQLite store keeps builds, their blobs and the live build as the memory store does, and hands out new build ids after an import", async () => {
  const sqlite = freshStore();
  const memory = memoryDesignStore();
  const copy = freshStore();

  try {
    const done = await buildThrough(sqlite);
    assert.deepEqual(done, await buildThrough(memory));
    assert.deepEqual(done.results.ids, [1, 2, 3, 4, 5]);
    assert.deepEqual([done.results.failed, done.results.tidied, done.results.newest], [[4, 5], { builds: 1, blobs: 1 }, [5, 4]]);
    assert.deepEqual(done.results.live, { channel: "live", build_id: 2, previous_build_id: 1, by: DESIGNERS.A.id, at: 7 });
    assert.deepEqual([done.results.info, done.results.gone], [{ sha256: "55".repeat(32), kind: "marshal", size: 4, at: 9 }, undefined]);
    assert.deepEqual(done.tables.design_builds.map((row) => [row.id, row.status, row.base_build_id]), [[1, "ok", null], [2, "ok", 1], [4, "failed", null], [5, "failed", null]]);
    assert.deepEqual(await sqlite.blob("22".repeat(32)), new Uint8Array([7, 1, 2, 3]), "a blob two builds name is kept once");

    await copy.importTables(done.tables, new Map(await Promise.all(done.tables.design_blobs.map(async (row) => [row.sha256, await sqlite.blob(row.sha256)]))));
    await memory.importTables({}, new Map());
    assert.deepEqual([await copy.addBuild({ seq: 9, by: DESIGNERS.A.id, at: 9 }), await memory.addBuild({ seq: 9, by: DESIGNERS.A.id, at: 9 })], [6, 6]);
  } finally {
    sqlite.close();
    copy.close();
  }
});
