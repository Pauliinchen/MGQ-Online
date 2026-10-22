//----------------------------------------------------------------
//  design_builds_server.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

import { after, test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { gunzipSync } from "node:zlib";
import WebSocket from "ws";
import { memoryDesignStore } from "../core/design_store_memory.js";
import { DesignBook } from "../core/designs.js";
import { Directory, sha256Hex } from "../core/directory.js";
import { FEATURES_HEADER, PLAYER_HEADER } from "../core/relay.js";
import { DESIGNERS, NOW } from "../core/test_designs.js";
import { createRelay, memoryStore, openStores } from "./server.js";
import { removeStubCompilers, stubCompiler } from "./test_design_compiler.js";

/**
 * The headers of designer A, a listed admin, on a released version.
 */
const A = { "X-MGQ-Designer": DESIGNERS.A.key, "X-MGQ-Features": "designer", "X-MGQ-Designer-Version": "1.3.0", "X-MGQ-Design-Format": "1" };

/**
 * The headers of a game that reads compiled format 3.
 */
const GAME = { [FEATURES_HEADER]: "raid", "X-MGQ-Design-Reader": "3" };

/**
 * The auth key of the tests' worlds.
 */
const AUTH = "ab".repeat(32);

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

after(async () => {
  for (const cleanup of cleanups.reverse()) {
    await cleanup();
  }

  removeStubCompilers();
});

/**
 * Starts a relay whose designs build with a stub compiler, designers A and B listed.
 *
 * @param {{worldNotice: boolean, database: boolean, mode?: object}} options Whether a publish tells the world rooms; whether the designs live in SQLite rather than in memory; the stub's mode.
 * @returns {Promise<{relay: any, address: string, setMode: (mode: object) => void}>} The relay, its HTTP address and a way to change the stub's mode.
 */
async function startRelay({ worldNotice, database, mode = {} }) {
  const { compiler, setMode } = stubCompiler(mode);
  const folder = mkdtempSync(join(tmpdir(), "mgq-builds-server-"));
  const stores = database ? await openStores(join(folder, "relay.db")) : null;
  const designs = new DesignBook(stores ? stores.designs : memoryDesignStore(), { compiler, worldNotice });

  for (const designer of [DESIGNERS.A, DESIGNERS.B]) {
    await designs.store.putDesigner({ id: designer.id, name: designer.name, admin: designer.admin, addedBy: "test", at: NOW });
  }

  const directory = new Directory(stores ? stores.directory : memoryStore());
  const relay = createRelay({ checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, log: LOG, directory, designs, ...(stores ? { stories: stores.stories, bosses: stores.bosses } : {}) });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  cleanups.push(async () => {
    await relay.stop();
    stores?.close();
    rmSync(folder, { recursive: true, force: true });
  });
  return { relay, address: `127.0.0.1:${relay.server.address().port}`, setMode };
}

/**
 * Sends a JSON request.
 *
 * @param {string} address The relay's address.
 * @param {string} method The HTTP method.
 * @param {string} path The path.
 * @param {Record<string, string>} headers The headers.
 * @param {unknown} [body] The JSON body, none when left out.
 * @returns {Promise<{status: number, body: any}>} The answer.
 */
async function call(address, method, path, headers, body) {
  const response = await fetch(`http://${address}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: response.status, body: await response.json() };
}

/**
 * Waits until a build finished.
 *
 * @param {string} address The relay's address.
 * @param {number} id The build.
 * @returns {Promise<any>} The build.
 */
async function finished(address, id) {
  for (let tries = 0; tries < 500; tries++) {
    const build = (await call(address, "GET", `/v1/designs/builds/${id}`, A)).body.builds[0];

    if (build.status !== "queued" && build.status !== "compiling") {
      return build;
    }

    await new Promise((resolve) => setTimeout(resolve, 20));
  }

  throw new Error(`build ${id} never finished`);
}

/**
 * Makes a Raid World with a boss pool for Lilith and seats a game in its world room.
 *
 * @param {any} relay The relay.
 * @param {string} address Its address.
 * @param {string} room The world's id.
 * @returns {Promise<string[]>} What the seated game hears, filled as it hears it.
 */
async function raidWorld(relay, address, room) {
  const created = await fetch(`http://${address}/v1/worlds`, {
    method: "POST",
    headers: { [FEATURES_HEADER]: "raid", [PLAYER_HEADER]: "c0".repeat(16) },
    body: JSON.stringify({ id: room, name: "Raid Designs", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, type: "raid" }),
  });
  assert.equal(created.status, 201);
  await relay.bossesOf(room).report("watcher", "Lilith", { battle: "b1", seq: 1, delta: 0.5, max: 900 });

  const heard = [];
  const socket = new WebSocket(`ws://${address}/v1/world/${room}?name=Watcher&auth=${AUTH}`, { headers: { [PLAYER_HEADER]: "57".repeat(16), [FEATURES_HEADER]: "raid" } });
  socket.on("message", (data) => heard.push(data.toString()));
  await new Promise((resolve, reject) => {
    socket.once("open", resolve);
    socket.once("error", reject);
  });
  cleanups.push(() => socket.terminate());
  await until(() => heard.includes("seat 0"));
  return heard;
}

/**
 * Waits until a condition holds, looking every few milliseconds.
 *
 * @param {() => boolean} condition The condition.
 * @returns {Promise<void>} Resolves once it holds.
 */
async function until(condition) {
  for (let tries = 0; tries < 200; tries++) {
    if (condition()) {
      return;
    }

    await new Promise((resolve) => setTimeout(resolve, 10));
  }

  throw new Error("the condition never held");
}

/**
 * Pushes one entity as designer A on base rev 0.
 *
 * @param {string} address The relay's address.
 * @param {string} id The entity id.
 * @returns {Promise<{status: number, body: any}>} The answer.
 */
function pushNew(address, id) {
  return call(address, "POST", "/v1/designs/push", A, { designFormat: 1, message: "test", changes: [{ id, kind: id.split(":")[0], schema: 1, baseRev: 0, body: { name: id } }] });
}

test("over HTTP a designer pushes while the compiler runs, publishes the build, and a game fetches it gzipped by its SHA-256", async () => {
  const { relay, address, setMode } = await startRelay({ worldNotice: false, database: true, mode: { sleepMs: 1500, catalogDiff: { removed: ["Lilith"] } } });
  const heard = await raidWorld(relay, address, "1d".repeat(16));
  await pushNew(address, "state:1");

  const started = await call(address, "POST", "/v1/designs/builds", A, { seq: 1 });
  assert.deepEqual(started, { status: 202, body: { build: { id: 1, seq: 1, status: "queued" } } });
  const status = async () => (await call(address, "GET", "/v1/designs/builds/1", A)).body.builds[0].status;
  assert.equal(await status(), "compiling");
  assert.deepEqual((await pushNew(address, "state:2")).body, { seq: 2, accepted: [{ id: "state:2", rev: 2 }] });
  assert.equal(await status(), "compiling", "the push landed while the stub compiler slept");

  const build = await finished(address, 1);
  assert.deepEqual([build.status, build.format, build.report.bossKeys], ["ok", 3, ["Lilith"]]);
  const snapshot = await fetch(`http://${address}/v1/designs/builds/1/snapshot`, { headers: A });
  assert.deepEqual(JSON.parse(gunzipSync(Buffer.from(await snapshot.arrayBuffer())).toString("utf8")).entities.map((entity) => entity.id), ["state:1"]);

  assert.equal((await call(address, "POST", "/v1/designs/publish", A, { buildId: 1 })).status, 200);
  const live = await call(address, "GET", "/v1/raid-design", GAME);
  assert.deepEqual([live.status, live.body.buildId, live.body.marshal.sha256, live.body.runtime.sha256], [200, 1, build.marshalSha, build.runtimeSha]);
  assert.equal((await fetch(`http://${address}/v1/raid-design`, { headers: { "X-MGQ-Design-Reader": "3" } })).status, 426, "the game route asks for X-MGQ-Features");

  for (const sha of [build.marshalSha, build.runtimeSha]) {
    const blob = await fetch(`http://${address}/v1/raid-design/${sha}`, { headers: GAME });
    const bytes = gunzipSync(Buffer.from(await blob.arrayBuffer()));
    assert.deepEqual([blob.status, blob.headers.get("content-type"), blob.headers.get("cache-control"), blob.headers.get("etag")], [200, "application/gzip", "public, max-age=31536000, immutable", `"${sha}"`]);
    assert.equal(createHash("sha256").update(bytes).digest("hex"), sha);
  }

  assert.equal((await fetch(`http://${address}/v1/raid-design/${build.marshalSha}`, { headers: { ...GAME, "If-None-Match": `"${build.marshalSha}"` } })).status, 304);
  assert.equal((await relay.bossesOf("1d".repeat(16)).list()).body.bosses.length, 1, "without DESIGN_WORLD_NOTICE the pool stays");
  assert.equal(heard.some((line) => line.startsWith("raid_design")), false, "without DESIGN_WORLD_NOTICE the world rooms hear nothing");

  setMode({ compile: "refuse" });
  const refused = (await call(address, "POST", "/v1/designs/builds", A, { seq: 2 })).body.build;
  assert.deepEqual([(await finished(address, refused.id)).status, (await finished(address, refused.id)).report.issues[0].code], ["refused", "formula"]);
  await relay.sweep();
  assert.deepEqual(errors, []);
});

test("with DESIGN_WORLD_NOTICE a publish tells every world room the new build and ends the pools of the bosses it removed", async () => {
  const { relay, address } = await startRelay({ worldNotice: true, database: false, mode: { catalogDiff: { removed: ["Lilith"] } } });
  const room = "2e".repeat(16);
  const heard = await raidWorld(relay, address, room);
  await pushNew(address, "state:1");
  await call(address, "POST", "/v1/designs/builds", A, { seq: 1 });
  const build = await finished(address, 1);

  assert.equal((await call(address, "POST", "/v1/designs/publish", A, { buildId: 1 })).status, 200);
  await until(() => heard.includes(`raid_design ${build.marshalSha} ${build.runtimeSha}`) && heard.includes("boss 1 900 0 Lilith"));
  assert.deepEqual((await relay.bossesOf(room).list()).body.bosses, []);
});
