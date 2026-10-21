//----------------------------------------------------------------
//  designs_socket.test.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { WebSocket } from "ws";
import { memoryDesignStore } from "../core/design_store_memory.js";
import { DesignerReleases } from "../core/designer_releases.js";
import { DESIGNERS, fixtureBook, fixtureReleases } from "../core/test_designs.js";
import { createRelay } from "./server.js";

/**
 * Logs nothing.
 */
const QUIET = { info: () => {}, error: () => {} };

/**
 * The headers of a designer on a released version.
 *
 * @param {{key: string}} designer The designer.
 * @param {Record<string, string>} [more] Headers to change.
 * @returns {Record<string, string>} The headers.
 */
function headersOf(designer, more = {}) {
  return { "X-MGQ-Designer": designer.key, "X-MGQ-Features": "designer", "X-MGQ-Designer-Version": "1.3.0", "X-MGQ-Design-Format": "1", ...more };
}

/**
 * The entity the designers edit.
 */
const BOSS = "boss:1b0a822614f83839e33ac1cbaa895e36";

/**
 * The bytes of the release exe the relay serves.
 */
const EXE = Buffer.from(Array.from({ length: 4096 }, (_, index) => index % 251));

let folder;
let relay;
let address;
let releases;

before(async () => {
  folder = mkdtempSync(join(tmpdir(), "mgq-designs-socket-"));
  const sha256 = createHash("sha256").update(EXE).digest("hex");
  releases = fixtureReleases();
  releases.folder = join(folder, "releases");
  mkdirSync(releases.folder);
  writeFileSync(releases.exePath(sha256), EXE);
  releases.restore({ ...releases.current, sha256, size: EXE.length });

  const designs = await fixtureBook(memoryDesignStore(), { releases: () => releases });
  // The fixtures' clock stands still; the socket's presence runs on real time.
  designs.presence.clock = Date.now;
  relay = createRelay({ checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, log: QUIET, designs });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  address = `127.0.0.1:${relay.server.address().port}`;
});

after(async () => {
  await relay.stop();
  rmSync(folder, { recursive: true, force: true });
});

/**
 * Opens a designer socket and collects its frames.
 *
 * @param {Record<string, string>} headers The headers.
 * @param {string} [path] The path.
 * @param {{autoPong?: boolean}} [options] Whether the socket answers pings, as it does unless told.
 * @returns {Promise<{socket: WebSocket, frames: any[], next: (op: string) => Promise<any>, closed: Promise<{code: number, reason: string}>, hello: Promise<any>}>} The socket, its frames so far, a wait for the next frame of an op, its close and its hello frame.
 */
async function connect(headers, path = "/v1/designs/socket", { autoPong = true } = {}) {
  const socket = new WebSocket(`ws://${address}${path}`, { headers, autoPong });
  const frames = [];
  const waiting = [];
  socket.on("message", (data) => {
    const frame = JSON.parse(data.toString());
    frames.push(frame);

    for (const wait of waiting.filter((each) => each.op === frame.op)) {
      waiting.splice(waiting.indexOf(wait), 1);
      wait.resolve(frame);
    }
  });
  const closed = new Promise((resolve) => socket.on("close", (code, reason) => resolve({ code, reason: reason.toString() })));
  const next = (op) => new Promise((resolve) => waiting.push({ op, resolve }));
  const hello = next("hello");
  await new Promise((resolve, reject) => {
    socket.on("open", resolve);
    socket.on("error", reject);
    socket.on("unexpected-response", (request, response) => reject(new Error(`refused with ${response.statusCode}`)));
  });
  return { socket, frames, next, closed, hello };
}

/**
 * Sends a request to the relay.
 *
 * @param {string} method The HTTP method.
 * @param {string} path The path.
 * @param {Record<string, string>} headers The headers.
 * @param {unknown} [body] The JSON body.
 * @returns {Promise<Response>} The response.
 */
function call(method, path, headers, body) {
  return fetch(`http://${address}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
}

test("designers are greeted, hear each other edit, hear pushes and hear a designer leave", async () => {
  const a = await connect(headersOf(DESIGNERS.A));
  assert.deepEqual(await a.hello, { op: "hello", seq: 0, you: { id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, presence: [] });

  a.socket.send(JSON.stringify({ op: "editing", entity: BOSS, path: "skills.game:1515.shape" }));
  const joined = a.next("presence");
  const b = await connect(headersOf(DESIGNERS.B));
  const hello = await b.hello;
  assert.deepEqual(hello.presence, [{ id: DESIGNERS.A.id, name: DESIGNERS.A.name, entity: BOSS, path: "skills.game:1515.shape" }]);
  assert.deepEqual({ ...(await joined), at: 0 }, { op: "presence", id: DESIGNERS.B.id, name: DESIGNERS.B.name, entity: null, path: null, at: 0 });

  const roster = await (await call("GET", "/v1/designs/designers", headersOf(DESIGNERS.B))).json();
  assert.deepEqual(roster.designers.map((designer) => [designer.name, designer.online, designer.editing]), [[DESIGNERS.A.name, true, BOSS], [DESIGNERS.B.name, true, null]]);

  const edited = a.next("presence");
  b.socket.send(JSON.stringify({ op: "editing", entity: "state:40", path: "hardCc" }));
  assert.deepEqual({ ...(await edited), at: 0 }, { op: "presence", id: DESIGNERS.B.id, name: DESIGNERS.B.name, entity: "state:40", path: "hardCc", at: 0 });

  const pushedA = a.next("pushed");
  const pushedB = b.next("pushed");
  const push = await call("POST", "/v1/designs/push", headersOf(DESIGNERS.A), { designFormat: 1, message: "m", changes: [{ id: "state:40", kind: "state", schema: 1, baseRev: 0, body: { hardCc: true } }] });
  assert.equal(push.status, 200);
  const frame = { op: "pushed", seq: 1, by: DESIGNERS.A.id, name: DESIGNERS.A.name, ids: ["state:40"] };
  assert.deepEqual(await pushedA, frame);
  assert.deepEqual(await pushedB, frame);

  const left = a.next("left");
  b.socket.close();
  assert.deepEqual(await left, { op: "left", id: DESIGNERS.B.id });
  assert.deepEqual(relay.designs.presence.of(DESIGNERS.B.id), { online: false, editing: null });
  a.socket.close();
  await a.closed;
});

test("an unlisted key and an outdated designer are closed with 4403 and 4426", async () => {
  const unlisted = await connect(headersOf(DESIGNERS.C));
  assert.deepEqual(await unlisted.closed, { code: 4403, reason: "not a designer" });

  const outdated = await connect(headersOf(DESIGNERS.B, { "X-MGQ-Designer-Version": "1.1.0" }));
  assert.deepEqual(await outdated.closed, { code: 4426, reason: "update" });

  const oldFormat = await connect(headersOf(DESIGNERS.B, { "X-MGQ-Design-Format": "0" }));
  assert.deepEqual(await oldFormat.closed, { code: 4426, reason: "update" });
  assert.equal(unlisted.frames.length + outdated.frames.length + oldFormat.frames.length, 0, "no hello");
});

test("another design path refuses the upgrade, and the game's rooms still open as before", async () => {
  await assert.rejects(connect(headersOf(DESIGNERS.A), "/v1/designs/me"), /refused with 404/);
  await assert.rejects(connect({}, "/v1/room/not-a-room"), /refused with 400/);
});

test("a removed designer's socket closes with 4403", async () => {
  const c = { ...DESIGNERS.C };
  assert.equal((await call("PUT", `/v1/designs/designers/${c.id}`, headersOf(DESIGNERS.A), { name: "Designer C" })).status, 200);
  const socket = await connect(headersOf(c));
  await socket.hello;
  assert.equal((await call("DELETE", `/v1/designs/designers/${c.id}`, headersOf(DESIGNERS.A))).status, 200);
  assert.deepEqual(await socket.closed, { code: 4403, reason: "not a designer" });
});

test("a designer socket that misses a pong is closed", async () => {
  const b = await connect(headersOf(DESIGNERS.B), undefined, { autoPong: false });
  await b.hello;
  relay.pingDesigners();
  relay.pingDesigners();
  const closed = await b.closed;
  assert.equal(closed.code, 1006, "terminated without a close frame");
});

test("a frame larger than the socket takes closes it", async () => {
  const b = await connect(headersOf(DESIGNERS.B));
  await b.hello;
  b.socket.send(JSON.stringify({ op: "editing", entity: BOSS, path: "x".repeat(8 * 1024) }));
  assert.equal((await b.closed).code, 1009);
});

test("a new designer release is told on the socket", async () => {
  const a = await connect(headersOf(DESIGNERS.A));
  await a.hello;
  const told = a.next("release");
  const check = releases.check;
  releases.check = async () => "1.4.0";

  try {
    assert.equal(await relay.checkDesignerRelease(), "1.4.0");
  } finally {
    releases.check = check;
  }

  assert.deepEqual(await told, { op: "release", version: "1.4.0" });
  a.socket.close();
  await a.closed;
});

test("the release and its file are served with ranges to a listed designer of any version", async () => {
  const old = headersOf(DESIGNERS.B, { "X-MGQ-Designer-Version": "0.9.0" });
  const answer = await call("GET", "/v1/designs/release", old);
  assert.equal(answer.status, 200);
  assert.equal((await answer.json()).size, EXE.length);

  const whole = await call("GET", "/v1/designs/release/file", old);
  assert.equal(whole.status, 200);
  assert.equal(whole.headers.get("Content-Type"), "application/octet-stream");
  assert.equal(whole.headers.get("Accept-Ranges"), "bytes");
  assert.equal(whole.headers.get("Content-Length"), String(EXE.length));
  assert.equal(whole.headers.get("Content-Disposition"), 'attachment; filename="RaidDesigner-1.3.0-win-x64.exe"');
  assert.deepEqual(Buffer.from(await whole.arrayBuffer()), EXE);

  const part = await call("GET", "/v1/designs/release/file", { ...old, Range: "bytes=4000-" });
  assert.equal(part.status, 206);
  assert.equal(part.headers.get("Content-Range"), `bytes 4000-4095/${EXE.length}`);
  assert.deepEqual(Buffer.from(await part.arrayBuffer()), EXE.subarray(4000));

  const past = await call("GET", "/v1/designs/release/file", { ...old, Range: "bytes=5000-" });
  assert.equal(past.status, 416);
  assert.equal(past.headers.get("Content-Range"), `bytes */${EXE.length}`);
  await past.arrayBuffer();

  const limited = await call("GET", "/v1/designs/release/file", old);
  assert.deepEqual({ status: limited.status, body: await limited.json() }, { status: 429, body: { code: "rate" } });

  const unlisted = await call("GET", "/v1/designs/release/file", headersOf(DESIGNERS.C));
  assert.deepEqual(await unlisted.json(), { code: "not_designer", id: DESIGNERS.C.id });
});

test("the release routes answer none on a relay without designer releases", async () => {
  const bare = createRelay({ checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, log: QUIET, designs: await fixtureBook(memoryDesignStore()) });
  await new Promise((resolve) => bare.server.listen(0, "127.0.0.1", resolve));

  try {
    const answer = await fetch(`http://127.0.0.1:${bare.server.address().port}/v1/designs/release`, { headers: headersOf(DESIGNERS.A) });
    assert.deepEqual({ status: answer.status, body: await answer.json() }, { status: 404, body: { code: "none" } });
    assert.equal(await bare.checkDesignerRelease(), null);
  } finally {
    await bare.stop();
  }

  assert.ok(releases instanceof DesignerReleases);
});
