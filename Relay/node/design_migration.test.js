//----------------------------------------------------------------
//  design_migration.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { gunzipSync } from "node:zlib";
import { DesignBook } from "../core/designs.js";
import { Directory, playerIdOf } from "../core/directory.js";
import { FEATURES_HEADER, PLAYER_HEADER } from "../core/relay.js";
import { DESIGNERS, NOW, RELAY_ADMIN_KEY } from "../core/test_designs.js";
import { openSqliteDesignStore } from "./design_store_sqlite.js";
import { migrate } from "./migrate.js";
import { DESIGN_TABLE_NAMES, STEPS } from "./schema.js";
import { createRelay, openStores } from "./server.js";
import { removeStubCompilers, stubCompiler } from "./test_design_compiler.js";

/**
 * The design format the source relay's designers push, above the first, so the design formats are kept.
 */
const FORMAT = 2;

/**
 * The headers of designer A, a listed admin, on a released version.
 */
const A = { "X-MGQ-Designer": DESIGNERS.A.key, "X-MGQ-Features": "designer", "X-MGQ-Designer-Version": "1.3.0", "X-MGQ-Design-Format": String(FORMAT) };

/**
 * The headers of designer B, a listed designer who is no admin.
 */
const B = { ...A, "X-MGQ-Designer": DESIGNERS.B.key };

/**
 * The headers of a relay admin.
 */
const RELAY_ADMIN = { [PLAYER_HEADER]: RELAY_ADMIN_KEY };

/**
 * The headers of a game that reads compiled format 3.
 */
const GAME = { [FEATURES_HEADER]: "raid", "X-MGQ-Design-Reader": "3" };

/**
 * A designer the relay admin adds, by a key no fixture uses.
 */
const ADDED = { id: "5a".repeat(16), name: "Designer D" };

/**
 * The errors the relays logged.
 */
const errors = [];

/**
 * Logs errors only, into errors.
 */
const LOG = { info: () => {}, error: (line) => errors.push(line) };

/**
 * What to stop and remove once the tests ran.
 */
const cleanups = [];

/**
 * The folder the databases are kept in.
 */
let folder;

/**
 * The source relay, whose designs went through every kind of change.
 */
let source;

after(async () => {
  for (const cleanup of cleanups.reverse()) {
    await cleanup();
  }

  removeStubCompilers();
  rmSync(folder, { recursive: true, force: true });
});

before(async () => {
  folder = mkdtempSync(join(tmpdir(), "mgq-design-migration-"));
  const { compiler } = stubCompiler({ designFormat: FORMAT, catalogDiff: { removed: ["Lilith"] } });
  source = await startRelay(join(folder, "source.db"), compiler);
  const { address } = source;

  assert.equal((await call(address, "PUT", "/v1/designs/me", B, { name: "Designer B renamed" })).status, 200);
  assert.equal((await call(address, "PUT", `/v1/designs/designers/${ADDED.id}`, RELAY_ADMIN, { name: ADDED.name, admin: false })).status, 200);
  await push(address, A, "first bosses", [change("rules", 0, { grid: 16 }), change("state:7", 0, { name: "Light" }), change("state:8", 0, { name: "Dark" })]);
  await push(address, B, "renamed a state", [change("state:7", 1, { name: "Light leaves" })]);
  await build(address, 2);
  assert.equal((await call(address, "POST", "/v1/designs/publish", A, { buildId: 1 })).status, 200);

  await push(address, A, "dropped the dark state", [change("state:8", 1, null)]);
  await build(address, 3);
  assert.equal((await call(address, "POST", "/v1/designs/publish", A, { buildId: 2 })).status, 200);
  await push(address, A, "a fourth push", [change("catalog", 0, { bossSwitch: 22 })]);
});

/**
 * Starts a relay over a SQLite database whose designs build with a compiler, the fixtures'
 * designers A and B listed and the fixtures' relay admin its admin.
 *
 * @param {string} database The database file.
 * @param {import("./design_compiler.js").DesignCompiler | null} compiler The compiler, null for a relay that cannot build.
 * @returns {Promise<{relay: any, address: string, stores: any}>} The relay, its HTTP address and its stores.
 */
async function startRelay(database, compiler) {
  const stores = await openStores(database);
  const directory = new Directory(stores.directory, { admins: [await playerIdOf(RELAY_ADMIN_KEY)] });
  const designs = new DesignBook(stores.designs, { compiler, relayAdmins: directory.admins, clock: () => NOW * 1000 });

  if ((await stores.designs.designer(DESIGNERS.A.id)) === undefined) {
    for (const designer of [DESIGNERS.A, DESIGNERS.B]) {
      await stores.designs.putDesigner({ id: designer.id, name: designer.name, admin: designer.admin, addedBy: "test", at: NOW });
    }
  }

  const relay = createRelay({ checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, log: LOG, directory, stories: stores.stories, bosses: stores.bosses, designs });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  cleanups.push(async () => {
    await relay.stop();
    stores.close();
  });
  return { relay, address: `http://127.0.0.1:${relay.server.address().port}`, stores };
}

/**
 * Sends a request and reads its JSON answer.
 *
 * @param {string} address The relay's address.
 * @param {string} method The HTTP method.
 * @param {string} path The path.
 * @param {Record<string, string>} headers The headers.
 * @param {unknown} [body] The JSON body, none when left out.
 * @returns {Promise<{status: number, body: any}>} The answer.
 */
async function call(address, method, path, headers, body) {
  const response = await fetch(`${address}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: response.status, body: await response.json() };
}

/**
 * Reads a route's bytes, gunzipped.
 *
 * @param {string} address The relay's address.
 * @param {string} path The path.
 * @param {Record<string, string>} headers The headers.
 * @returns {Promise<Buffer>} The bytes.
 */
async function gunzipped(address, path, headers) {
  const response = await fetch(`${address}${path}`, { headers });
  assert.equal(response.status, 200, path);
  return gunzipSync(Buffer.from(await response.arrayBuffer()));
}

/**
 * Makes a change of a push.
 *
 * @param {string} id The entity id.
 * @param {number} baseRev The rev it was changed from, 0 for a new entity.
 * @param {object | null} body The body, null to delete it.
 * @returns {object} The change.
 */
function change(id, baseRev, body) {
  return { id, kind: id.split(":")[0], schema: 1, baseRev, body };
}

/**
 * Pushes changes and checks the relay took them.
 *
 * @param {string} address The relay's address.
 * @param {Record<string, string>} headers The designer's headers.
 * @param {string} message The push's message.
 * @param {object[]} changes The changes.
 * @returns {Promise<number>} The push's seq.
 */
async function push(address, headers, message, changes) {
  const answer = await call(address, "POST", "/v1/designs/push", headers, { designFormat: FORMAT, message, changes });
  assert.equal(answer.status, 200, JSON.stringify(answer.body));
  return answer.body.seq;
}

/**
 * Builds the design at a seq and waits until the build finished.
 *
 * @param {string} address The relay's address.
 * @param {number} seq The current seq.
 * @returns {Promise<any>} The finished build.
 */
async function build(address, seq) {
  const started = await call(address, "POST", "/v1/designs/builds", A, { seq });
  assert.equal(started.status, 202, JSON.stringify(started.body));

  for (let tries = 0; tries < 500; tries++) {
    const found = (await call(address, "GET", `/v1/designs/builds/${started.body.build.id}`, A)).body.builds[0];

    if (found.status !== "queued" && found.status !== "compiling") {
      assert.equal(found.status, "ok", JSON.stringify(found.report));
      return found;
    }

    await new Promise((resolve) => setTimeout(resolve, 20));
  }

  throw new Error(`build ${started.body.build.id} never finished`);
}

/**
 * Lists the design tables a database holds, by the names the design steps give them.
 *
 * @param {string} database The database file.
 * @returns {{tables: string[], version: number}} The tables, sorted, and the database's user_version.
 */
function designTablesOf(database) {
  const db = new DatabaseSync(database, { readOnly: true });

  try {
    const tables = db.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND (name LIKE 'design%')").all().map((row) => row.name).sort();
    return { tables, version: db.prepare("PRAGMA user_version").get().user_version };
  } finally {
    db.close();
  }
}

test("the migration hands out every design table the database steps make, each with rows once the designs were pushed, built and published", async () => {
  const { tables } = designTablesOf(join(folder, "source.db"));
  assert.deepEqual(tables, [...DESIGN_TABLE_NAMES].sort(), "a design table the migration leaves out would be lost in a move");

  const exported = (await call(source.address, "GET", "/v1/migration/designs", RELAY_ADMIN)).body.tables;
  assert.deepEqual(Object.keys(exported).sort(), tables);

  for (const name of tables) {
    assert.ok(exported[name].length > 0, `${name} has rows to carry`);
  }

  assert.deepEqual(exported.design_live.map((row) => [row.build_id, row.previous_build_id]), [[2, 1]]);
  assert.deepEqual(Object.fromEntries(exported.design_meta.map((row) => [row.key, row.value])), { design_format: String(FORMAT), min_format: String(FORMAT) });
  assert.ok(exported.design_history.some((row) => row.id === "state:8" && row.deleted === 1), "the tombstone's revision is kept");
});

test("a relay on the migrated copy serves the same entities, history, designers, builds, live build and blobs, and goes on from the same seq", async () => {
  const database = join(folder, "copy.db");
  await migrate({ from: source.address, key: RELAY_ADMIN_KEY, database, log: () => {} });
  assert.deepEqual(designTablesOf(database).version, STEPS.length, "the copy takes every step, so the relay opens it without a step left");

  const copy = await startRelay(database, null);
  const both = async (method, path, headers) => [await call(source.address, method, path, headers), await call(copy.address, method, path, headers)];

  for (const path of ["/v1/designs/me", "/v1/designs/entities?since=0", "/v1/designs/entities?since=2", "/v1/designs/entities/state:7/history", "/v1/designs/entities/state:8/history", "/v1/designs/builds", "/v1/designs/designers"]) {
    const [kept, copied] = await both("GET", path, A);
    assert.equal(copied.status, 200, path);
    assert.deepEqual(copied.body, kept.body, path);
  }

  const [liveKept, liveCopied] = await both("GET", "/v1/raid-design", GAME);
  assert.deepEqual(liveCopied, liveKept);

  for (const sha of [liveKept.body.marshal.sha256, liveKept.body.runtime.sha256]) {
    const bytes = await gunzipped(copy.address, `/v1/raid-design/${sha}`, GAME);
    assert.equal(createHash("sha256").update(bytes).digest("hex"), sha);
  }

  assert.deepEqual(await gunzipped(copy.address, "/v1/designs/builds/1/snapshot", A), await gunzipped(source.address, "/v1/designs/builds/1/snapshot", A));
  assert.deepEqual((await call(copy.address, "GET", "/v1/designs/me", { ...A, "X-MGQ-Designer": DESIGNERS.B.key })).body.name, "Designer B renamed");
  assert.equal(await push(copy.address, A, "the first push on the copy", [change("state:9", 0, { name: "New" })]), 5, "the copy's seq goes on after the source's");
  assert.equal((await call(copy.address, "POST", "/v1/designs/rollback", A)).body.live.buildId, 1, "the previous build is still the one to roll back to");

  const copied = openSqliteDesignStore(database);

  try {
    assert.equal(JSON.parse(JSON.stringify(await copied.exportTables())).design_pushes.length, 5);
  } finally {
    copied.close();
  }

  assert.deepEqual(errors, []);
});
