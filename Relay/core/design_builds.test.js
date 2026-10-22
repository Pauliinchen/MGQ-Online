//----------------------------------------------------------------
//  design_builds.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Tested that the world rooms hear racing publishes in the order the builds went live
//                            - Tested that a request that is not as it should be takes no rate limit token
//                            - Tested that a publish refuses a build compiled against another live build
//                            - Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { gunzipSync } from "node:zlib";
import { memoryDesignStore } from "./design_store_memory.js";
import { DESIGN_LIMITS, DesignBook, SNAPSHOT_FORMAT, handleGameDesignRequest } from "./designs.js";
import { DESIGNERS, NOW, compiledBuild, entity, fakeCompiler, fixture, seedEntities, send } from "./test_designs.js";

/**
 * The headers of designer A, a listed admin, on a released version.
 */
const A = { "X-MGQ-Designer": DESIGNERS.A.key, "X-MGQ-Features": "designer", "X-MGQ-Designer-Version": "1.3.0", "X-MGQ-Design-Format": "1" };

/**
 * The headers of designer B, a listed designer, on a released version.
 */
const B = { ...A, "X-MGQ-Designer": DESIGNERS.B.key };

/**
 * A request from this machine, which no download limit counts.
 */
const LOCAL = Object.freeze({ reader: "3", address: "127.0.0.1", local: true, etag: null });

/**
 * Makes a design book over memory with designers A and B listed, a compiler the test drives and
 * the frames it tells the designers.
 *
 * @param {{compiler?: object, worldNotice?: boolean, limits?: typeof DESIGN_LIMITS, rateLimits?: object, downloads?: object}} [options] The compiler, a fakeCompiler unless given; the rest as DesignBook takes them.
 * @returns {Promise<{book: DesignBook, compiler: any, frames: object[]}>} The book, its compiler and the frames told so far.
 */
async function buildBook({ compiler = fakeCompiler(), ...options } = {}) {
  const frames = [];
  const presence = { of: () => ({ online: false, editing: null }), broadcast: (frame) => frames.push(frame) };
  const unlimited = { build: { burst: 1000, refillMs: 1 }, publish: { burst: 1000, refillMs: 1 }, push: { burst: 1000, refillMs: 1 } };
  const book = new DesignBook(memoryDesignStore(), { clock: () => NOW * 1000, presence, compiler, rateLimits: unlimited, ...options });

  for (const designer of [DESIGNERS.A, DESIGNERS.B]) {
    await book.store.putDesigner({ id: designer.id, name: designer.name, admin: designer.admin, addedBy: "test", at: NOW });
  }

  return { book, compiler, frames };
}

/**
 * Sends a design request as a designer.
 *
 * @param {DesignBook} book The design.
 * @param {string} method The HTTP method.
 * @param {string} path The path after /v1/designs.
 * @param {object | null} [body] The JSON body.
 * @param {Record<string, string>} [headers] The designer's headers, A's unless given.
 * @returns {Promise<{status: number, body: any, bytes?: Uint8Array, headers?: object, notice?: object}>} The answer.
 */
function call(book, method, path, body = null, headers = A) {
  return send(book, { method, path: `/v1/designs${path}`, headers, body });
}

/**
 * Pushes one entity as designer A on base rev 0.
 *
 * @param {DesignBook} book The design.
 * @param {string} id The entity id.
 * @returns {Promise<{status: number, body: any}>} The answer.
 */
function pushNew(book, id) {
  return call(book, "POST", "/push", { designFormat: 1, message: "test", changes: [{ id, kind: id.split(":")[0], schema: 1, baseRev: 0, body: { name: id } }] });
}

/**
 * Builds the design as it stands and waits for the compile.
 *
 * @param {DesignBook} book The design.
 * @returns {Promise<any>} The finished build as GET builds/<id> hands it out.
 */
async function buildNow(book) {
  const { seq } = await book.state();
  const started = await call(book, "POST", "/builds", { seq });
  assert.equal(started.status, 202, JSON.stringify(started.body));
  await book.idle();
  return (await call(book, "GET", `/builds/${started.body.build.id}`)).body.builds[0];
}

/**
 * Asks for the live build as a game.
 *
 * @param {DesignBook} book The design.
 * @param {string} path The path after /v1/raid-design.
 * @param {object} [client] The game's reader format, address and If-None-Match, LOCAL unless given.
 * @returns {Promise<{status: number, body: any, bytes?: Uint8Array, headers?: object}>} The answer.
 */
function game(book, path, client = LOCAL) {
  return handleGameDesignRequest(book, "GET", new URL(`https://relay.test/v1/raid-design${path}`), client, async () => {});
}

test("a build compiles outside the push lock: a push lands while the compile runs, and each status is told", async () => {
  const { book, compiler, frames } = await buildBook();
  await pushNew(book, "state:1");
  const release = compiler.hold();

  const started = await call(book, "POST", "/builds", { seq: 1 });
  assert.deepEqual(started, { status: 202, body: { build: { id: 1, seq: 1, status: "queued" } } });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(compiler.jobs.length, 1, "the compile runs");

  const pushed = await pushNew(book, "state:2");
  assert.deepEqual(pushed.body, { seq: 2, accepted: [{ id: "state:2", rev: 2 }] }, "the push did not wait for the compile");
  assert.equal((await call(book, "GET", "/builds/1")).body.builds[0].status, "compiling");

  release();
  await book.idle();
  const build = (await call(book, "GET", "/builds/1")).body.builds[0];
  assert.deepEqual([build.status, build.seq, build.format, build.report.ok, build.by, build.at], ["ok", 1, 3, true, DESIGNERS.A.id, NOW]);
  assert.deepEqual(frames.map((frame) => frame.build.status), ["queued", "compiling", "ok"]);
  assert.deepEqual(Object.keys(frames[0]).sort(), Object.keys(fixture("socket.json").serverToClient.find((frame) => frame.op === "build")).sort());

  const snapshot = JSON.parse(compiler.snapshots.get(1));
  assert.deepEqual(snapshot, { designFormat: 1, entities: [{ body: { name: "state:1" }, id: "state:1", kind: "state", schema: 1 }], format: SNAPSHOT_FORMAT }, "the snapshot is the design at seq 1");
});

test("the snapshot holds every entity but the tombstones, sorted by id over every page, in canonical JSON", async () => {
  const { book, compiler } = await buildBook({ limits: { ...DESIGN_LIMITS, maxPage: 2 } });
  await seedEntities(book.store, [entity("state:3", 1, { b: 2, a: [1, null], c: null }), entity("state:1", 1, {}), entity("map:4", 2, {}), entity("tier:2", 2, {}), entity("state:9", 3, null)]);
  await buildNow(book);
  assert.equal(compiler.snapshots.get(1),
    `{"designFormat":1,"entities":[{"body":{},"id":"map:4","kind":"map","schema":1},{"body":{},"id":"state:1","kind":"state","schema":1},{"body":{"a":[1,null],"b":2},"id":"state:3","kind":"state","schema":1},{"body":{},"id":"tier:2","kind":"tier","schema":1}],"format":"${SNAPSHOT_FORMAT}"}`);
});

test("a build on a seq a push moved past while the compiler was probed is refused as moved", async () => {
  const compiler = fakeCompiler();
  let reached;
  const probing = new Promise((resolve) => {
    reached = resolve;
  });
  let goOn;
  const probe = compiler.probe;
  compiler.probe = async () => {
    reached();
    await new Promise((resolve) => {
      goOn = resolve;
    });
    return probe();
  };
  const { book } = await buildBook({ compiler });
  await pushNew(book, "state:1");

  const started = call(book, "POST", "/builds", { seq: 1 });
  await probing;
  await pushNew(book, "state:2");
  goOn();
  assert.deepEqual(await started, { status: 409, body: { code: "moved", seq: 2 } });
  assert.deepEqual((await call(book, "GET", "/builds")).body.builds, []);
});

test("a build the compiler refuses keeps its report; a failed compile, a throwing one and a compiler that fell behind the format fail", async () => {
  const { book, compiler } = await buildBook();
  compiler.outcome = () => ({ status: "refused", report: { ok: false, issues: [{ severity: "error", code: "formula" }] }, fields: { format: 3 }, blobs: [] });
  const refused = await buildNow(book);
  assert.deepEqual([refused.status, refused.report.issues[0].code, refused.marshalSha, refused.format], ["refused", "formula", null, 3]);

  compiler.outcome = () => {
    throw new Error("the disk is full");
  };
  const thrown = await buildNow(book);
  assert.deepEqual([thrown.status, thrown.report], ["failed", { ok: false, failure: { message: "the disk is full" } }]);

  // Another compiler was installed while the build waited.
  const release = compiler.hold();
  compiler.outcome = (job) => compiledBuild(job.seq);
  const started = await call(book, "POST", "/builds", { seq: 0 });
  compiler.probe = async () => ({ designFormat: 1, version: "1.0.0", message: "The compiler misses game data on the relay." });
  release();
  await book.idle();
  const late = (await call(book, "GET", `/builds/${started.body.build.id}`)).body.builds[0];
  assert.deepEqual([late.status, late.report.failure.message], ["failed", "The compiler misses game data on the relay."]);
  assert.deepEqual(await call(book, "POST", "/builds", { seq: 0 }), { status: 503, body: { code: "compiler", message: "The compiler misses game data on the relay." } });
});

test("a relay without a compiler refuses builds, and a bad seq is invalid", async () => {
  const { book } = await buildBook({ compiler: null });
  assert.deepEqual(await call(book, "POST", "/builds", { seq: 0 }), { status: 503, body: { code: "compiler", message: "This relay has no compiler." } });
  assert.equal((await call(book, "POST", "/builds", { seq: "0" })).status, 400);
  assert.equal((await call(book, "POST", "/builds", null)).status, 400);
});

test("only designer admins build, publish, roll back and set the format; every designer reads the builds", async () => {
  const { book } = await buildBook();
  await buildNow(book);

  for (const [method, path, body] of [["POST", "/builds", { seq: 0 }], ["POST", "/publish", { buildId: 1 }], ["POST", "/rollback", null], ["POST", "/format", { minFormat: 1 }]]) {
    assert.deepEqual((await call(book, method, path, body, B)).body, { code: "admin_only" }, path);
  }

  assert.equal((await call(book, "GET", "/builds", null, B)).status, 200);
  assert.equal((await call(book, "GET", "/builds/1/snapshot", null, B)).status, 200);
  assert.deepEqual((await call(book, "POST", "/builds", { seq: 0 }, { ...A, "X-MGQ-Designer-Version": "0.0.0-dev" })).status, 202, "an admin builds from a development build");
});

test("builds, publishing and rolling back are rate limited per designer, and a request that is not as it should be counts against none", async () => {
  const { book } = await buildBook({ rateLimits: {} });
  const answers = [];

  for (let index = 0; index < 4; index++) {
    answers.push((await call(book, "POST", "/builds", { seq: "0" })).status, (await call(book, "POST", "/publish", { buildId: 0 })).status);
  }

  assert.deepEqual(answers.splice(0), [400, 400, 400, 400, 400, 400, 400, 400]);

  for (let index = 0; index < 4; index++) {
    answers.push((await call(book, "POST", "/builds", { seq: 0 })).status);
  }

  assert.deepEqual(answers, [202, 202, 202, 429]);
  await book.idle();
  const publishes = [];

  for (const path of ["/publish", "/rollback", "/publish", "/rollback"]) {
    publishes.push((await call(book, "POST", path, path === "/publish" ? { buildId: 1 } : null)).status);
  }

  assert.deepEqual(publishes, [200, 404, 200, 429]);
});

test("publish makes an ok build live with the one before it as previous, rollback swaps them, and each tells the designers", async () => {
  const { book, compiler, frames } = await buildBook();
  compiler.outcome = () => ({ status: "failed", report: { ok: false, failure: { message: "no" } }, fields: {}, blobs: [] });
  await buildNow(book);
  compiler.outcome = (job) => compiledBuild(job.seq, { removed: ["Lilith"], renamed: [{ id: "boss:1", from: "Morrigan", to: "Morrigan Prime" }] });
  await pushNew(book, "state:1");
  const first = await buildNow(book);

  assert.deepEqual(await call(book, "POST", "/publish", { buildId: 1 }), { status: 409, body: { code: "status", status: "failed" } });
  assert.deepEqual(await call(book, "POST", "/publish", { buildId: 99 }), { status: 404, body: { code: "none" } });
  assert.equal((await call(book, "POST", "/publish", { buildId: "2" })).status, 400);
  assert.deepEqual(await call(book, "POST", "/rollback"), { status: 404, body: { code: "none" } }, "nothing to roll back to");

  const published = await call(book, "POST", "/publish", { buildId: first.id });
  assert.deepEqual(published, {
    status: 200,
    body: { live: { buildId: 2, previousBuildId: null, by: DESIGNERS.A.id, at: NOW }, catalogDiff: { removed: ["Lilith"], renamed: [{ id: "boss:1", from: "Morrigan", to: "Morrigan Prime" }], troopsChanged: [] } },
  });
  assert.equal(published.notice, undefined, "DESIGN_WORLD_NOTICE is off");
  assert.deepEqual(frames.at(-1), { op: "live", buildId: 2, marshalSha: first.marshalSha, runtimeSha: first.runtimeSha, by: DESIGNERS.A.id, name: DESIGNERS.A.name });

  compiler.outcome = (job) => compiledBuild(job.seq);
  await pushNew(book, "state:2");
  const second = await buildNow(book);
  assert.deepEqual((await call(book, "POST", "/publish", { buildId: second.id })).body.live, { buildId: 3, previousBuildId: 2, by: DESIGNERS.A.id, at: NOW });
  assert.deepEqual((await call(book, "POST", "/publish", { buildId: second.id })).body.live.previousBuildId, 2, "publishing the live build again keeps its previous");
  assert.deepEqual((await call(book, "GET", "/builds")).body.live, 3);

  assert.deepEqual(await call(book, "POST", "/rollback"), { status: 200, body: { live: { buildId: 2, previousBuildId: 3, by: DESIGNERS.A.id, at: NOW } } });
  assert.deepEqual(frames.at(-1).buildId, 2);
  const list = (await call(book, "GET", "/builds")).body;
  assert.deepEqual([list.live, list.previous, list.builds.map((build) => build.id)], [2, 3, [3, 2, 1]]);
  assert.deepEqual(Object.keys(list.builds[0]).sort(), ["at", "by", "format", "id", "marshalSha", "report", "runtimeSha", "seq", "snapshotSha", "status"]);
});

test("publish refuses a build compiled against another live build than the one live now as stale, but not the live build itself", async () => {
  const { book } = await buildBook();
  const first = await buildNow(book);
  const early = await buildNow(book);
  assert.equal((await call(book, "POST", "/publish", { buildId: first.id })).status, 200);
  assert.deepEqual(await call(book, "POST", "/publish", { buildId: early.id }), { status: 409, body: { code: "stale" } }, "compiled while nothing was live");

  const second = await buildNow(book);
  assert.equal((await call(book, "POST", "/publish", { buildId: second.id })).status, 200);
  assert.equal((await call(book, "POST", "/publish", { buildId: second.id })).status, 200, "the live build again");
  assert.deepEqual(await call(book, "POST", "/publish", { buildId: first.id }), { status: 409, body: { code: "stale" } }, "the previous build is made live by a rollback");

  assert.equal((await call(book, "POST", "/rollback")).status, 200);
  assert.equal((await call(book, "POST", "/publish", { buildId: second.id })).status, 200, "compiled against the build live again");
  assert.deepEqual((await call(book, "GET", "/builds")).body.live, second.id);
});

test("a later build is compiled against the live build's runtime JSON", async () => {
  const { book, compiler } = await buildBook();
  const first = await buildNow(book);
  assert.equal(compiler.jobs[0].previous, null, "no build is live yet");
  await call(book, "POST", "/publish", { buildId: first.id });
  await buildNow(book);
  assert.equal(gunzipSync(compiler.jobs[1].previous).toString("utf8"), "runtime 0");
});

test("with DESIGN_WORLD_NOTICE a publish names the world-room frame and the pools of removed and renamed bosses to end, a rollback the frame alone", async () => {
  const { book, compiler } = await buildBook({ worldNotice: true });
  compiler.outcome = (job) => compiledBuild(job.seq, { removed: ["Lilith", "Morrigan"], renamed: [{ id: "boss:1", from: "Morrigan", to: "Alma" }, { id: "boss:2", from: "Tamamo", to: "Tama" }] });
  const first = await buildNow(book);
  const published = await call(book, "POST", "/publish", { buildId: first.id });
  assert.deepEqual(published.notice, { text: `raid_design ${first.marshalSha} ${first.runtimeSha}`, resetKeys: ["Lilith", "Morrigan", "Tamamo"] });

  compiler.outcome = (job) => compiledBuild(job.seq + 100);
  const second = await buildNow(book);
  await call(book, "POST", "/publish", { buildId: second.id });
  assert.deepEqual((await call(book, "POST", "/rollback")).notice, { text: `raid_design ${first.marshalSha} ${first.runtimeSha}`, resetKeys: [] });
});

test("the world rooms hear racing rollbacks one at a time, in the order the builds went live", async () => {
  const { book, compiler } = await buildBook({ worldNotice: true });
  const first = await buildNow(book);
  await call(book, "POST", "/publish", { buildId: first.id });
  compiler.outcome = (job) => compiledBuild(job.seq + 100);
  const second = await buildNow(book);
  await call(book, "POST", "/publish", { buildId: second.id });
  const textOf = (build) => `raid_design ${build.marshalSha} ${build.runtimeSha}`;

  const started = [];
  const told = [];
  let release;
  const held = new Promise((resolve) => {
    release = resolve;
  });
  book.worldTeller = async (notice) => {
    started.push(notice.text);

    if (started.length === 1) {
      await held;
    }

    told.push(notice.text);
  };

  const answers = await Promise.all([call(book, "POST", "/rollback"), call(book, "POST", "/rollback")]);
  assert.deepEqual(answers.map((answer) => answer.status), [200, 200]);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(started.length, 1, "the later notice waits for the earlier one");

  release();
  await book.notices;
  assert.deepEqual(told, [textOf(first), textOf(second)]);
  assert.equal((await call(book, "GET", "/builds")).body.live, second.id);
});

test("an admin raises the lowest format up to the design format, which then holds older designers back", async () => {
  const { book } = await buildBook();
  await call(book, "POST", "/push", { designFormat: 3, message: "format 3", changes: [{ id: "rules", kind: "rules", schema: 1, baseRev: 0, body: {} }] }, { ...A, "X-MGQ-Design-Format": "3" });
  assert.deepEqual((await book.state()).minFormat, 3, "a released push raised both");

  const admin = { ...A, "X-MGQ-Design-Format": "3" };
  assert.equal((await call(book, "POST", "/format", { minFormat: 4 }, admin)).status, 400, "not above the design format");
  assert.equal((await call(book, "POST", "/format", { minFormat: 2 }, admin)).status, 400, "never lower");
  assert.deepEqual(await call(book, "POST", "/format", { minFormat: 3 }, admin), { status: 200, body: { designFormat: 3, minFormat: 3 } });
  assert.deepEqual((await call(book, "GET", "/builds", null, { ...B, "X-MGQ-Design-Format": "2" })).body, { code: "update", minimum: "0.0.0", minFormat: 3 });
});

test("a game reads the live build at or below its format, else the previous one, else none", async () => {
  const { book, compiler } = await buildBook();
  assert.deepEqual(await game(book, ""), { status: 404, body: { code: "none" } });

  const first = await buildNow(book);
  await call(book, "POST", "/publish", { buildId: first.id });
  compiler.outcome = (job) => ({ ...compiledBuild(job.seq + 50), fields: { ...compiledBuild(job.seq + 50).fields, format: 4 } });
  const second = await buildNow(book);
  await call(book, "POST", "/publish", { buildId: second.id });

  const answer = await game(book, "", { ...LOCAL, reader: "4" });
  assert.deepEqual(answer, { status: 200, body: { buildId: 2, format: 4, seq: 0, marshal: { sha256: second.marshalSha, size: 10 }, runtime: { sha256: second.runtimeSha, size: 10 }, at: NOW } });
  assert.equal((await game(book, "", { ...LOCAL, reader: " 3 " })).body.buildId, 1, "a format 3 reader gets the previous build");
  assert.deepEqual(await game(book, "", { ...LOCAL, reader: "2" }), { status: 404, body: { code: "none" } });
  assert.deepEqual(await game(book, "", { ...LOCAL, reader: null }), { status: 404, body: { code: "none" } });
});

test("a blob is served gzipped under its SHA-256 for good, a held copy gets 304, and other paths, snapshots and unknown hashes get none", async () => {
  const { book } = await buildBook({ downloads: { burst: 1, refillMs: 60_000 } });
  const build = await buildNow(book);

  const blob = await game(book, `/${build.marshalSha}`);
  assert.equal(blob.status, 200);
  assert.equal(gunzipSync(blob.bytes).toString("utf8"), "marshal 0");
  assert.deepEqual(blob.headers, { "Cache-Control": "public, max-age=31536000, immutable", ETag: `"${build.marshalSha}"`, "Content-Type": "application/gzip" });
  assert.deepEqual(await game(book, `/${build.marshalSha}`, { ...LOCAL, etag: `"other", "${build.marshalSha}"` }), { status: 304, body: {}, headers: { "Cache-Control": "public, max-age=31536000, immutable", ETag: `"${build.marshalSha}"` } });

  for (const path of [`/${build.snapshotSha}`, `/${"0".repeat(64)}`, "/ABC", `/${build.marshalSha}/more`]) {
    assert.equal((await game(book, path)).status, 404, path);
  }

  assert.equal((await handleGameDesignRequest(book, "POST", new URL("https://relay.test/v1/raid-design"), LOCAL, async () => {})).status, 404);

  const remote = { reader: "3", address: "203.0.113.5", local: false, etag: null };
  assert.equal((await game(book, `/${build.runtimeSha}`, remote)).status, 200);
  assert.deepEqual(await game(book, `/${build.runtimeSha}`, remote), { status: 429, body: { code: "rate" } });
  assert.equal((await game(book, `/${build.runtimeSha}`)).status, 200, "this machine, such as the battle server, is not counted");

  const snapshot = await call(book, "GET", `/builds/${build.id}/snapshot`);
  assert.deepEqual([snapshot.status, snapshot.headers["Content-Type"], gunzipSync(snapshot.bytes).toString("utf8")], [200, "application/gzip", "snapshot 0"]);
  assert.deepEqual(await call(book, "GET", "/builds/99/snapshot"), { status: 404, body: { code: "none" } });
  assert.deepEqual(await call(book, "GET", "/builds/x"), { status: 404, body: { code: "none" } });
});

test("the sweep keeps the newest builds, the live and the previous one, and drops the blobs no build names; a restart fails unfinished builds", async () => {
  const { book, compiler } = await buildBook({ limits: { ...DESIGN_LIMITS, buildsKept: 3 } });
  let next = 0;
  compiler.outcome = () => compiledBuild((next += 1));

  await buildNow(book);
  await call(book, "POST", "/publish", { buildId: 1 });

  for (let index = 0; index < 5; index++) {
    await buildNow(book);
  }

  await call(book, "POST", "/publish", { buildId: 2 });
  const marshalOf3 = (await call(book, "GET", "/builds/3")).body.builds[0].marshalSha;
  assert.deepEqual(await book.tidyBuilds(), { builds: 1, blobs: 3 });
  assert.deepEqual((await call(book, "GET", "/builds")).body.builds.map((build) => build.id), [6, 5, 4, 2, 1]);
  assert.equal(await book.store.blob(marshalOf3), undefined);
  assert.equal((await game(book, "")).body.buildId, 2);

  const release = compiler.hold();
  await call(book, "POST", "/builds", { seq: 0 });
  await call(book, "POST", "/builds", { seq: 0 });
  assert.deepEqual(await book.recoverBuilds(), [7, 8]);
  assert.deepEqual((await call(book, "GET", "/builds/8")).body.builds[0].report, { ok: false, failure: { message: "The relay restarted during the build." } });
  release();
});
