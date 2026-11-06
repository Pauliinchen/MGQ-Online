//----------------------------------------------------------------
//  design_store_sqlite.test.js
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the comparisons with the memory store, which is gone
//                            - Dropped the checks of the export and import of every table
//      Paulinchen  2026-10-22: Tested the design epoch over restarts, restores from a backup and imports
//                            - Tested that both stores keep the live build each build was compiled against
//                            - Tested that both stores keep builds, blobs and the live build alike
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { copyFileSync, existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { DESIGNERS, fixtureBook, replayScenarios, send } from "../core/test_designs.js";
import { openSqliteDesignStore, seqMarkOf } from "./design_store_sqlite.js";

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
 * Edits, deletes and restores entities and renames a designer, through a store.
 *
 * @param {import("../core/designs.js").DesignStore} store The store.
 * @returns {Promise<void>} Completes once done.
 */
async function workThrough(store) {
  const book = await fixtureBook(store);
  await push(book, [{ id: "rules", kind: "rules", schema: 1, baseRev: 0, body: { units: { cap: 16 } } }, { id: "state:4", kind: "state", schema: 1, baseRev: 0, body: { hardCc: true } }]);
  await push(book, [{ id: "state:4", kind: "state", schema: 2, baseRev: 1, body: null }]);
  await push(book, [{ id: "state:4", kind: "state", schema: 2, baseRev: 2, body: { minTurns: 2 } }]);
  await send(book, { method: "PUT", path: "/v1/designs/me", headers: A, body: { name: "Alice" } });
}

test("the contract's exchanges are answered as the fixtures show over SQLite too", async () => {
  for (const { file, name, expected, actual } of await replayScenarios(freshStore)) {
    assert.deepEqual(actual, expected, `${file}: ${name}`);
  }
});

test("the design outlasts a restart", async () => {
  const path = join(folder, "restart.db");
  const first = openSqliteDesignStore(path);
  await workThrough(first);
  first.close();

  const again = openSqliteDesignStore(path);
  const book = await fixtureBook(again);
  const pulled = await send(book, { method: "GET", path: "/v1/designs/entities?since=0", headers: A, body: null });
  assert.deepEqual(pulled.body.entities.map((entity) => [entity.id, entity.rev, entity.schema, entity.body]), [["rules", 1, 1, { units: { cap: 16 } }], ["state:4", 3, 2, { minTurns: 2 }]]);
  again.close();
});

/**
 * Keeps an empty push in a store.
 *
 * @param {import("../core/designs.js").DesignStore} store The store.
 * @param {number} seq The push's seq.
 * @returns {Promise<void>} Completes once kept.
 */
function commitSeq(store, seq) {
  return store.commit({
    seq, by: DESIGNERS.A.id, name: DESIGNERS.A.name, at: seq, message: "test", designFormat: 1, clientVersion: "1.3.0", keep: 50, format: null,
    entities: [{ id: `state:${seq}`, kind: "state", schema: 1, body: "{}", deleted: false }],
  });
}

test("the design epoch outlasts a restart and comes anew once a restored backup holds fewer pushes than the relay handed out", async () => {
  const path = join(folder, "relay.sqlite");
  const backup = join(folder, "backup.sqlite");
  const lines = [];
  const open = () => openSqliteDesignStore(path, { log: (line) => lines.push(line) });
  let store = open();
  const first = (await store.state()).epoch;
  assert.match(first, /^[0-9a-f]{32}$/);

  for (let seq = 1; seq <= 90; seq++) {
    await commitSeq(store, seq);
  }

  store.close();
  copyFileSync(path, backup);
  store = open();
  assert.equal((await store.state()).epoch, first, "a restart keeps the epoch");

  for (let seq = 91; seq <= 100; seq++) {
    await commitSeq(store, seq);
  }

  store.close();
  assert.equal(seqMarkOf(path), join(folder, "relay.design-seq"), "moving relay.sqlite* aside leaves the mark");
  assert.equal(readFileSync(seqMarkOf(path), "utf8"), "100\n");
  assert.ok(!existsSync(path + "-wal"), "the relay left no write-ahead log to restore beside the copy");
  copyFileSync(backup, path);

  store = open();
  const restored = await store.state();
  assert.equal(restored.seq, 90);
  assert.notEqual(restored.epoch, first, "the restored database starts a new epoch");
  assert.equal(readFileSync(seqMarkOf(path), "utf8"), "90\n", "the mark goes back, so the next start keeps the new epoch");
  assert.match(lines.join("\n"), /holds pushes up to seq 90, the relay handed out 100/);
  await commitSeq(store, 91);
  store.close();

  store = open();
  assert.equal((await store.state()).epoch, restored.epoch, "a start after the restore keeps its epoch");
  store.close();
  assert.equal(lines.length, 1);
});

test("a database whose epoch the restore procedure removed gets a new epoch", async () => {
  const path = join(folder, "removed.sqlite");
  let store = openSqliteDesignStore(path);
  const first = (await store.state()).epoch;
  store.close();

  const db = new DatabaseSync(path);
  db.exec("DELETE FROM design_meta WHERE key = 'epoch'");
  db.close();
  store = openSqliteDesignStore(path);
  const second = (await store.state()).epoch;
  assert.match(second, /^[0-9a-f]{32}$/);
  assert.notEqual(second, first);
  store.close();
});
