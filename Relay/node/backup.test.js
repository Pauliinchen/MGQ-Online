//----------------------------------------------------------------
//  backup.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

// Runs ops/backup-relay.sh against a database the relay holds open, and opens the copy as the
// relay would after a restore. Skipped where `sh` or sqlite3 (SQLITE3, else on the PATH) is missing.

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { DESIGNERS, NOW } from "../core/test_designs.js";
import { openStores } from "./server.js";

/**
 * The backup script, with forward slashes, which every shell reads.
 */
const SCRIPT = fileURLToPath(new URL("../ops/backup-relay.sh", import.meta.url)).replace(/\\/g, "/");

/**
 * The sqlite3 program the script runs.
 */
const SQLITE3 = process.env.SQLITE3 || "sqlite3";

/**
 * Why the tests cannot run here, false when they can.
 */
const SKIP = runs("sh", ["-c", "true"]) ? (runs(SQLITE3, ["--version"]) ? false : `${SQLITE3} is missing; set SQLITE3 to run the backup tests`) : "sh is missing";

/**
 * A world the database keeps.
 */
const WORLD = { id: "b4".repeat(16), name: "Backed Up", members: {}, bans: [] };

/**
 * The name the script gives its copies, by date.
 */
const COPY_NAME = /^relay-\d{4}-\d{2}-\d{2}\.sqlite$/;

/**
 * The folder the databases and copies are kept in.
 */
let folder;

/**
 * The relay's stores, open while the script copies their database, as on the server.
 */
let stores;

before(async () => {
  if (SKIP) {
    return;
  }

  folder = mkdtempSync(join(tmpdir(), "mgq-backup-")).replace(/\\/g, "/");
  stores = await openStores(`${folder}/relay.sqlite`);
  await stores.directory.put(WORLD);
  await stores.directory.putStart(WORLD.id, new Uint8Array(100_000).map((_, index) => index % 251));
  await stores.designs.putDesigner({ id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true, addedBy: "test", at: NOW });

  for (const [seq, body] of [[1, { name: "Light" }], [2, { name: "Light leaves" }], [3, null]]) {
    await stores.designs.commit({
      seq, by: DESIGNERS.A.id, name: DESIGNERS.A.name, at: NOW + seq, message: `push ${seq}`, designFormat: 1, clientVersion: "1.3.0",
      entities: [{ id: "state:7", kind: "state", schema: 1, body: body && JSON.stringify(body), deleted: body === null }, { id: `state:${10 + seq}`, kind: "state", schema: 1, body: "{}", deleted: false }],
      keep: 50, format: null,
    });
  }
});

after(() => {
  stores?.close();

  if (folder) {
    rmSync(folder, { recursive: true, force: true });
  }
});

/**
 * Tells whether a program runs here.
 *
 * @param {string} program The program.
 * @param {string[]} args Arguments it ends at once with.
 * @returns {boolean} Whether it ran and exited with 0.
 */
function runs(program, args) {
  const run = spawnSync(program, args, { stdio: "ignore", windowsHide: true });
  return !run.error && run.status === 0;
}

/**
 * Runs the backup script.
 *
 * @param {Record<string, string>} env The script's settings, beside the process's environment.
 * @returns {{status: number | null, stdout: string, stderr: string}} How it ended.
 */
function backup(env) {
  const run = spawnSync("sh", [SCRIPT], { env: { ...process.env, SQLITE3, ...env }, encoding: "utf8", windowsHide: true });
  return { status: run.status, stdout: run.stdout, stderr: run.stderr };
}

test("the script copies the open database with its design tables, keeps the newest copies and leaves other files alone", { skip: SKIP }, async () => {
  const dest = `${folder}/backups`;
  mkdirSync(dest);

  for (const day of ["2026-01-01", "2026-01-02", "2026-01-03", "2026-01-04"]) {
    writeFileSync(`${dest}/relay-${day}.sqlite`, "an old copy");
  }

  writeFileSync(`${dest}/relay-before-the-move.sqlite`, "a copy made by hand");
  const run = backup({ MGQ_RELAY_DB: `${folder}/relay.sqlite`, BACKUP_DIR: dest, BACKUP_KEEP: "3" });
  assert.equal(run.status, 0, run.stderr);
  assert.match(run.stdout, / 1 worlds, design_blobs=0 design_builds=0 design_entities=4 design_history=6 design_live=0 design_meta=0 design_pushes=3 designers=1\), keeping 3 copies/);

  const names = readdirSync(dest).sort();
  const today = names.filter((name) => COPY_NAME.test(name) && !name.startsWith("relay-2026-01-"));
  assert.equal(today.length, 1);
  assert.deepEqual(names, ["relay-2026-01-03.sqlite", "relay-2026-01-04.sqlite", ...today, "relay-before-the-move.sqlite"].sort());

  const restored = `${folder}/restored.sqlite`;
  copyFileSync(`${dest}/${today[0]}`, restored);
  const copy = await openStores(restored);

  try {
    assert.deepEqual(await copy.directory.get(WORLD.id), WORLD);
    assert.deepEqual(await copy.directory.getStart(WORLD.id), await stores.directory.getStart(WORLD.id));
    assert.deepEqual(JSON.parse(JSON.stringify(await copy.designs.exportTables())), JSON.parse(JSON.stringify(await stores.designs.exportTables())));
    assert.equal((await copy.designs.state()).seq, 3);
  } finally {
    copy.close();
  }

  assert.equal(backup({ MGQ_RELAY_DB: `${folder}/relay.sqlite`, BACKUP_DIR: dest, BACKUP_KEEP: "3" }).status, 0, "a second run on one day replaces that day's copy");
  assert.equal(readdirSync(dest).filter((name) => COPY_NAME.test(name)).length, 3);
  assert.equal(readdirSync(dest).some((name) => name.includes("partial")), false);
});

test("the script refuses a missing database and a count of copies that is no whole number above 0", { skip: SKIP }, () => {
  const dest = `${folder}/refused`;
  const missing = backup({ MGQ_RELAY_DB: `${folder}/none.sqlite`, BACKUP_DIR: dest });
  assert.deepEqual([missing.status, missing.stderr.trim()], [1, `backup-relay: the database ${folder}/none.sqlite is missing`]);

  for (const keep of ["0", "-1", "two"]) {
    const run = backup({ MGQ_RELAY_DB: `${folder}/relay.sqlite`, BACKUP_DIR: dest, BACKUP_KEEP: keep });
    assert.deepEqual([run.status, run.stderr.trim()], [1, `backup-relay: BACKUP_KEEP must be a whole number above 0, not '${keep}'`]);
  }

  assert.equal(existsSync(dest), false, "nothing is written before the checks pass");
});
