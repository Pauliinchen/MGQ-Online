//----------------------------------------------------------------
//  design_presence.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Greeted designers with the design epoch
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { memoryDesignStore } from "./design_store_memory.js";
import {
  DESIGN_CLOSE, DESIGN_SOCKET, DesignPresence, admitDesigner, buildFrame, helloFrame, leftFrame, liveFrame, presenceFrame, pushedFrame, readEditing, releaseFrame,
} from "./designs.js";
import { DESIGNERS, EPOCH, NOW, canonicalJson, clientOf, fixture, fixtureBook, fixtureReleases, send } from "./test_designs.js";

/**
 * The headers of designer A, a listed admin, on a released version.
 */
const A = { "X-MGQ-Designer": DESIGNERS.A.key, "X-MGQ-Features": "designer", "X-MGQ-Designer-Version": "1.3.0", "X-MGQ-Design-Format": "1" };

/**
 * The headers of designer B, a listed designer, on a released version.
 */
const B = { ...A, "X-MGQ-Designer": DESIGNERS.B.key };

/**
 * The entity the fixtures' designers edit.
 */
const BOSS = "boss:1b0a822614f83839e33ac1cbaa895e36";

/**
 * Makes a socket that keeps the frames it is sent.
 *
 * @returns {{readyState: number, frames: any[], closed: {code: number, reason: string} | null, send: (text: string) => void, close: (code: number, reason: string) => void}} The socket.
 */
function fakeSocket() {
  return {
    readyState: 1,
    frames: [],
    closed: null,
    send(text) {
      this.frames.push(JSON.parse(text));
    },
    close(code, reason) {
      this.closed = { code, reason };
      this.readyState = 3;
    },
  };
}

/**
 * Makes a presence on a clock the test moves, with the timers it was asked for kept to run by hand.
 *
 * @returns {{presence: DesignPresence, time: {now: number}, timers: {work: () => void, ms: number}[]}} The presence, its clock and its timers.
 */
function testPresence() {
  const time = { now: NOW * 1000 };
  const timers = [];
  const presence = new DesignPresence({ clock: () => time.now, schedule: (work, ms) => timers.push({ work, ms }) });
  return { presence, time, timers };
}

/**
 * Builds an editing frame as a designer sends it.
 *
 * @param {string | null} entity The entity.
 * @param {string | null} path The path.
 * @returns {string} The frame.
 */
function editing(entity, path) {
  return JSON.stringify({ op: "editing", entity, path });
}

test("every server frame is built as socket.json shows it", () => {
  const frames = fixture("socket.json").serverToClient;
  const of = (op) => frames.find((frame) => frame.op === op);
  const hello = of("hello");
  const presence = of("presence");
  const live = of("live");

  const built = [
    helloFrame(hello, hello.you, hello.presence),
    pushedFrame(of("pushed")),
    presenceFrame(presence, presence.at),
    leftFrame(of("left").id),
    buildFrame(of("build").build),
    liveFrame(live),
    releaseFrame(of("release").version),
  ];
  assert.deepEqual(built.map((frame) => canonicalJson(frame)), frames.map((frame) => canonicalJson(frame)));
  assert.deepEqual(built.map((frame) => JSON.stringify(Object.keys(frame))), frames.map((frame) => JSON.stringify(Object.keys(frame))), "the keys come in the fixture's order");
});

test("the close codes are the contract's", () => {
  const codes = fixture("socket.json").closeCodes;
  assert.deepEqual({ [DESIGN_CLOSE.notDesigner.code]: DESIGN_CLOSE.notDesigner.reason, [DESIGN_CLOSE.update.code]: DESIGN_CLOSE.update.reason }, codes);
});

test("an editing frame is read as socket.json shows it and anything else is dropped", () => {
  for (const frame of fixture("socket.json").clientToServer) {
    assert.deepEqual(readEditing(JSON.stringify(frame)), { entity: frame.entity, path: frame.path });
  }

  assert.deepEqual(readEditing(JSON.stringify({ op: "editing" })), { entity: null, path: null }, "missing fields mean nothing");
  assert.deepEqual(readEditing(editing(null, "skills")), { entity: null, path: null }, "a path without an entity is dropped");
  assert.equal(readEditing("{not json"), null);
  assert.equal(readEditing(JSON.stringify({ op: "pushed" })), null);
  assert.equal(readEditing(JSON.stringify([1])), null);
  assert.equal(readEditing(editing("boss:Lilith", null)), null, "an id off the pattern");
  assert.equal(readEditing(editing(BOSS, 3)), null);
  assert.equal(readEditing(editing(BOSS, "")), null);
  assert.equal(readEditing(editing(BOSS, "a\nb")), null, "a control character");
  assert.equal(readEditing(editing(BOSS, "x".repeat(DESIGN_SOCKET.maxPathLength + 1))), null);
  assert.deepEqual(readEditing(editing(BOSS, "x".repeat(DESIGN_SOCKET.maxPathLength))), { entity: BOSS, path: "x".repeat(DESIGN_SOCKET.maxPathLength) });
});

test("a designer joining is greeted with the seq and the others online, and the others hear of it", () => {
  const { presence } = testPresence();
  const a = fakeSocket();
  const b = fakeSocket();
  presence.join({ id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, { seq: 418, epoch: EPOCH }, a);
  presence.editing(a, editing(BOSS, null));
  presence.join({ id: DESIGNERS.B.id, name: DESIGNERS.B.name, admin: false }, { seq: 418, epoch: EPOCH }, b);

  assert.deepEqual(a.frames[0], { op: "hello", seq: 418, epoch: EPOCH, you: { id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, presence: [] });
  assert.deepEqual(b.frames, [{ op: "hello", seq: 418, epoch: EPOCH, you: { id: DESIGNERS.B.id, name: DESIGNERS.B.name, admin: false }, presence: [{ id: DESIGNERS.A.id, name: DESIGNERS.A.name, entity: BOSS, path: null }] }]);
  assert.deepEqual(a.frames.at(-1), { op: "presence", id: DESIGNERS.B.id, name: DESIGNERS.B.name, entity: null, path: null, at: NOW });
  assert.deepEqual(presence.of(DESIGNERS.A.id), { online: true, editing: BOSS });
  assert.deepEqual(presence.of(DESIGNERS.B.id), { online: true, editing: null });
  assert.deepEqual(presence.of(DESIGNERS.C.id), { online: false, editing: null });
});

test("what a designer edits reaches the others, never itself, at most once a second with the last frame told late", () => {
  const { presence, time, timers } = testPresence();
  const a = fakeSocket();
  const b = fakeSocket();
  presence.join({ id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, { seq: 1, epoch: EPOCH }, a);
  time.now += 5000;
  presence.join({ id: DESIGNERS.B.id, name: DESIGNERS.B.name, admin: false }, { seq: 1, epoch: EPOCH }, b);
  const told = () => b.frames.filter((frame) => frame.op === "presence");

  presence.editing(a, editing(BOSS, "skills.game:1515.shape"));
  assert.deepEqual(told(), [{ op: "presence", id: DESIGNERS.A.id, name: DESIGNERS.A.name, entity: BOSS, path: "skills.game:1515.shape", at: NOW + 5 }]);
  assert.ok(a.frames.every((frame) => frame.op !== "presence" || frame.id !== DESIGNERS.A.id));

  time.now += 200;
  presence.editing(a, editing(BOSS, "skills.game:1515.name"));
  time.now += 200;
  presence.editing(a, editing(BOSS, "skills.game:1515.cost"));
  assert.equal(told().length, 1, "frames within a second wait");
  assert.deepEqual(timers.map((timer) => timer.ms), [800], "one timer for the rest of the second after the first frame");

  time.now += 600;
  timers.shift().work();
  assert.equal(told().length, 2);
  assert.equal(told()[1].path, "skills.game:1515.cost", "the last frame is told");

  time.now += 1000;
  presence.editing(a, editing(null, null));
  assert.deepEqual(told()[2], { op: "presence", id: DESIGNERS.A.id, name: DESIGNERS.A.name, entity: null, path: null, at: NOW + 7 });
  assert.equal(timers.length, 0);

  presence.editing(a, "{not json");
  presence.editing(fakeSocket(), editing(BOSS, null));
  assert.equal(told().length, 3, "a bad frame and an unknown socket change nothing");
});

test("a frame told late is dropped once its designer left", () => {
  const { presence, time, timers } = testPresence();
  const a = fakeSocket();
  const b = fakeSocket();
  presence.join({ id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, { seq: 1, epoch: EPOCH }, a);
  presence.join({ id: DESIGNERS.B.id, name: DESIGNERS.B.name, admin: false }, { seq: 1, epoch: EPOCH }, b);
  time.now += 100;
  presence.editing(a, editing(BOSS, null));
  presence.leave(a);
  timers.shift().work();
  assert.deepEqual(b.frames.at(-1), { op: "left", id: DESIGNERS.A.id });
});

test("presence lasts 60 seconds unless told again, then the others hear the designer edits nothing", () => {
  const { presence, time } = testPresence();
  const a = fakeSocket();
  const b = fakeSocket();
  presence.join({ id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, { seq: 1, epoch: EPOCH }, a);
  presence.join({ id: DESIGNERS.B.id, name: DESIGNERS.B.name, admin: false }, { seq: 1, epoch: EPOCH }, b);
  presence.editing(a, editing(BOSS, "shape"));

  time.now += 30_000;
  presence.editing(a, editing(BOSS, "shape"));
  assert.equal(b.frames.at(-1).at, NOW + 30, "a refresh is told again");
  time.now += 59_000;
  presence.expire();
  assert.deepEqual(presence.of(DESIGNERS.A.id), { online: true, editing: BOSS }, "the refresh holds it");

  time.now += 1000;
  presence.expire();
  assert.deepEqual(presence.of(DESIGNERS.A.id), { online: true, editing: null });
  assert.deepEqual(b.frames.at(-1), { op: "presence", id: DESIGNERS.A.id, name: DESIGNERS.A.name, entity: null, path: null, at: NOW + 90 });

  const count = b.frames.length;
  time.now += 120_000;
  presence.expire();
  assert.equal(b.frames.length, count, "editing nothing never expires again");
});

test("a designer with two sockets stays online until both close, then the others hear it left", () => {
  const { presence } = testPresence();
  const a1 = fakeSocket();
  const a2 = fakeSocket();
  const b = fakeSocket();
  presence.join({ id: DESIGNERS.B.id, name: DESIGNERS.B.name, admin: false }, { seq: 1, epoch: EPOCH }, b);
  presence.join({ id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, { seq: 1, epoch: EPOCH }, a1);
  presence.join({ id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, { seq: 1, epoch: EPOCH }, a2);
  assert.equal(b.frames.filter((frame) => frame.op === "presence").length, 1, "the second socket is no new designer");

  presence.leave(a1);
  assert.equal(presence.of(DESIGNERS.A.id).online, true);
  presence.leave(a2);
  presence.leave(a2);
  assert.equal(presence.of(DESIGNERS.A.id).online, false);
  assert.deepEqual(b.frames.filter((frame) => frame.op === "left"), [{ op: "left", id: DESIGNERS.A.id }], "left once");
});

test("broadcast reaches every open socket, and disconnect closes every socket of a designer", () => {
  const { presence } = testPresence();
  const a = fakeSocket();
  const b1 = fakeSocket();
  const b2 = fakeSocket();
  presence.join({ id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, { seq: 1, epoch: EPOCH }, a);
  presence.join({ id: DESIGNERS.B.id, name: DESIGNERS.B.name, admin: false }, { seq: 1, epoch: EPOCH }, b1);
  presence.join({ id: DESIGNERS.B.id, name: DESIGNERS.B.name, admin: false }, { seq: 1, epoch: EPOCH }, b2);
  b2.readyState = 2;
  presence.broadcast(releaseFrame("1.3.0"));
  assert.deepEqual([a, b1, b2].map((socket) => socket.frames.at(-1)?.op), ["release", "release", "hello"], "a closing socket is sent nothing");

  presence.disconnect(DESIGNERS.B.id, DESIGN_CLOSE.notDesigner);
  assert.deepEqual([a.closed, b1.closed, b2.closed], [null, DESIGN_CLOSE.notDesigner, DESIGN_CLOSE.notDesigner]);
});

test("the socket admits a current listed designer, closes on others with 4403 or 4426 and refuses other paths", async () => {
  const store = memoryDesignStore();
  const book = await fixtureBook(store);

  const admitted = await admitDesigner(book, ["socket"], clientOf(A));
  assert.deepEqual(admitted, { designer: { id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, state: { seq: 0, epoch: EPOCH } });
  assert.equal((await store.designer(DESIGNERS.A.id)).last_seen, NOW);

  assert.deepEqual(await admitDesigner(book, ["socket"], clientOf({ ...A, "X-MGQ-Designer": DESIGNERS.C.key })), { close: DESIGN_CLOSE.notDesigner });
  assert.deepEqual(await admitDesigner(book, ["socket"], clientOf({ ...A, "X-MGQ-Designer": "not a key" })), { close: DESIGN_CLOSE.notDesigner });
  assert.deepEqual(await admitDesigner(book, ["socket"], clientOf({ ...B, "X-MGQ-Designer-Version": "1.1.0" })), { close: DESIGN_CLOSE.update });
  assert.deepEqual(await admitDesigner(book, ["socket"], clientOf({ ...B, "X-MGQ-Design-Format": "0" })), { close: DESIGN_CLOSE.update });
  assert.deepEqual((await admitDesigner(book, ["socket"], clientOf({ ...B, "X-MGQ-Designer-Version": "0.0.0-dev" }))).designer.id, DESIGNERS.B.id, "a development build reads");
  assert.equal((await admitDesigner(book, ["me"], clientOf(A))).status, 404);
  assert.equal((await admitDesigner(book, ["socket", "x"], clientOf(A))).status, 404);
});

test("the designer list shows who the presence has online", async () => {
  const { presence } = testPresence();
  const book = await fixtureBook(memoryDesignStore(), { presence });
  const socket = fakeSocket();
  presence.join({ id: DESIGNERS.A.id, name: DESIGNERS.A.name, admin: true }, { seq: 0, epoch: EPOCH }, socket);
  presence.editing(socket, editing(BOSS, null));

  const listed = await send(book, { method: "GET", path: "/v1/designs/designers", headers: B, body: null });
  assert.deepEqual(listed.body.designers.map((designer) => [designer.name, designer.online, designer.editing]), [[DESIGNERS.A.name, true, BOSS], [DESIGNERS.B.name, false, null]]);
});

test("a removed designer is named for its sockets to close", async () => {
  const book = await fixtureBook(memoryDesignStore());
  const removed = await send(book, { method: "DELETE", path: `/v1/designs/designers/${DESIGNERS.B.id}`, headers: A, body: null });
  assert.deepEqual(removed, { status: 200, body: {}, removed: DESIGNERS.B.id });
});

test("the release routes answer none without a release, serve listed designers of any version and limit the file to three an hour", async () => {
  const bare = await fixtureBook(memoryDesignStore());
  assert.deepEqual(await send(bare, { method: "GET", path: "/v1/designs/release", headers: A, body: null }), { status: 404, body: { code: "none" } });
  assert.deepEqual(await send(bare, { method: "GET", path: "/v1/designs/release/file", headers: A, body: null }), { status: 404, body: { code: "none" } });

  const time = { now: NOW * 1000 };
  const store = memoryDesignStore();
  const book = await fixtureBook(store, { releases: fixtureReleases });
  book.releaseFiles.clock = () => time.now;
  const file = (headers) => send(book, { method: "GET", path: "/v1/designs/release/file", headers, body: null });
  const old = { ...B, "X-MGQ-Designer-Version": "0.9.0", "X-MGQ-Design-Format": "0" };

  const first = await file(old);
  assert.equal(first.status, 200, "no version gate");
  assert.deepEqual({ ...first.file, path: undefined }, { path: undefined, name: "RaidDesigner-1.3.0-win-x64.exe", size: 71234567, sha256: fixture("release.json").exchanges[0].response.body.sha256 });
  assert.ok(first.file.path.endsWith(`${first.file.sha256}.exe`));
  assert.equal((await file(old)).status, 200);
  assert.equal((await file(old)).status, 200);
  assert.deepEqual(await file(old), { status: 429, body: { code: "rate" } });
  assert.equal((await file(A)).status, 200, "each designer apart");

  time.now += 20 * 60 * 1000;
  assert.equal((await file(old)).status, 200, "a turn back after twenty minutes");

  assert.deepEqual((await file({ ...A, "X-MGQ-Designer": DESIGNERS.C.key })).body, { code: "not_designer", id: DESIGNERS.C.id });
  assert.equal((await send(book, { method: "POST", path: "/v1/designs/release", headers: A, body: null })).status, 404);
  assert.equal((await send(book, { method: "GET", path: "/v1/designs/release/other", headers: A, body: null })).status, 404);
});
