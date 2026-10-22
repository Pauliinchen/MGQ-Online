//----------------------------------------------------------------
//  designs.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Tested that a seeded admin stays demoted
//                            - Replayed the build exchanges too and tested the routes that remain no routes
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { memoryDesignStore } from "./design_store_memory.js";
import { DESIGN_KINDS, DESIGN_LIMITS, DesignBook, ENTITY_ID, SEEDED_BY, designRouteOf, designerIdOf } from "./designs.js";
import { playerIdOf } from "./directory.js";
import { DEFAULT_DESIGNER_MIN_VERSION } from "./gate.js";
import { DESIGNERS, NOW, RELAY_ADMIN_KEY, SCENARIOS, canonicalJson, entity, fixture, fixtureBook, fixtureNames, replayScenarios, seedEntities, send } from "./test_designs.js";

/**
 * The headers of designer A, a listed admin, on a released version.
 */
const A = { "X-MGQ-Designer": DESIGNERS.A.key, "X-MGQ-Features": "designer", "X-MGQ-Designer-Version": "1.3.0", "X-MGQ-Design-Format": "1" };

/**
 * The headers of designer B, a listed designer, on a released version.
 */
const B = { ...A, "X-MGQ-Designer": DESIGNERS.B.key };

/**
 * Makes a fresh design book over memory with designers A and B listed.
 *
 * @returns {Promise<DesignBook>} The book.
 */
function freshBook() {
  return fixtureBook(memoryDesignStore());
}

/**
 * Makes a design book over memory with its own rate limits, with designers A and B listed.
 *
 * @param {{burst: number, refillMs: number}} pushes The push rate limit.
 * @returns {Promise<DesignBook>} The book.
 */
async function bookWithPushes(pushes) {
  const book = new DesignBook(memoryDesignStore(), { clock: () => NOW * 1000, rateLimits: { push: pushes } });

  for (const designer of [DESIGNERS.A, DESIGNERS.B]) {
    await book.store.putDesigner({ id: designer.id, name: designer.name, admin: designer.admin, addedBy: "test", at: 0 });
  }

  return book;
}

/**
 * Pushes changes as a designer.
 *
 * @param {DesignBook} book The design.
 * @param {Record<string, string>} headers The designer's headers.
 * @param {object[]} changes The changes.
 * @param {object} [extra] More fields of the push, such as confirmDeletes or designFormat.
 * @returns {Promise<{status: number, body: any}>} The answer.
 */
function push(book, headers, changes, extra = {}) {
  return send(book, { method: "POST", path: "/v1/designs/push", headers, body: { designFormat: 1, message: "test", changes, ...extra } });
}

/**
 * Makes one change of a push.
 *
 * @param {string} id The entity id.
 * @param {number} baseRev The rev it was made on.
 * @param {object | null} body The body, null to delete.
 * @param {number} [schema] The body schema, 1 unless given.
 * @returns {object} The change.
 */
function change(id, baseRev, body, schema = 1) {
  return { id, kind: id.split(":")[0], schema, baseRev, body };
}

/**
 * Pulls a page as designer A.
 *
 * @param {DesignBook} book The design.
 * @param {string} query The query, such as `since=0`.
 * @returns {Promise<{status: number, body: any}>} The answer.
 */
function pull(book, query) {
  return send(book, { method: "GET", path: `/v1/designs/entities?${query}`, headers: A, body: null });
}

test("every contract fixture parses, and every exchange is replayed here", () => {
  const replayed = new Set(SCENARIOS.map((scenario) => scenario.file));

  for (const name of fixtureNames()) {
    const data = fixture(name);

    if (Array.isArray(data.exchanges)) {
      assert.ok(replayed.has(name), `${name} is replayed`);
    }
  }

  assert.deepEqual(fixtureNames().filter((name) => name.startsWith("entity-")).map((name) => name.slice(7, -5)).sort(), [...DESIGN_KINDS].sort());
});

test("the contract's exchanges are answered as the fixtures show, compared as canonical JSON", async () => {
  const results = await replayScenarios(() => memoryDesignStore());
  assert.ok(results.length >= 20, `${results.length} exchanges replayed`);

  for (const { file, name, expected, actual } of results) {
    assert.deepEqual(actual, expected, `${file}: ${name}`);
  }
});

test("every entity fixture is pushed as a create and pulled back equal", async () => {
  const book = await freshBook();
  const envelopes = DESIGN_KINDS.map((kind) => fixture(`entity-${kind}.json`));
  const pushed = await push(book, A, envelopes.map((envelope) => change(envelope.id, 0, envelope.body, envelope.schema)));
  assert.equal(pushed.status, 200);
  assert.deepEqual(pushed.body, { seq: 1, accepted: envelopes.map((envelope) => ({ id: envelope.id, rev: 1 })) });

  const pulled = await pull(book, "since=0");
  assert.equal(pulled.body.next, null);
  assert.deepEqual(pulled.body.entities.map((each) => each.id), envelopes.map((envelope) => envelope.id).sort());

  for (const envelope of envelopes) {
    const wire = pulled.body.entities.find((each) => each.id === envelope.id);
    assert.ok(ENTITY_ID.test(envelope.id), envelope.id);
    assert.equal(canonicalJson({ ...wire, rev: envelope.rev }), canonicalJson({ ...envelope, deleted: false, by: DESIGNERS.A.id, name: DESIGNERS.A.name, at: NOW }), envelope.id);
  }
});

test("a designer id is the start of a SHA-256 of its own text, never the player id of the same key", async () => {
  for (const designer of Object.values(DESIGNERS)) {
    assert.equal(await designerIdOf(designer.key), designer.id);
    assert.notEqual(await playerIdOf(designer.key), designer.id);
  }
});

test("the design routes are read after /v1/designs, decoded, and no other route is one", () => {
  assert.deepEqual(designRouteOf(new URL("https://relay.test/v1/designs/entities/state%3A41/history")), { rest: ["entities", "state:41", "history"] });
  assert.deepEqual(designRouteOf(new URL("https://relay.test/v1/designs")), { rest: [] });
  assert.equal(designRouteOf(new URL("https://relay.test/v1/designsx")), null);
  assert.equal(designRouteOf(new URL("https://relay.test/v1/raid-design")), null);
});

test("a delete keeps a tombstone that a pull since 0 leaves out, a delete of what is missing or deleted changes nothing, and a push on the tombstone restores it", async () => {
  const book = await freshBook();
  assert.equal((await push(book, A, [change("state:1", 0, { hardCc: true }), change("state:2", 0, { hardCc: false })])).body.seq, 1);

  const deleted = await push(book, B, [change("state:1", 1, null), change("state:9", 0, null), change("state:8", 5, null)]);
  assert.deepEqual(deleted.body, { seq: 2, accepted: [{ id: "state:1", rev: 2 }, { id: "state:9", rev: 0 }, { id: "state:8", rev: 0 }] });
  assert.deepEqual((await pull(book, "since=0")).body.entities.map((each) => each.id), ["state:2"]);
  assert.deepEqual((await pull(book, "since=1")).body.entities.map((each) => [each.id, each.deleted, each.body, each.name]), [["state:1", true, null, DESIGNERS.B.name]]);

  assert.deepEqual((await push(book, A, [change("state:1", 2, null)])).body, { seq: 2, accepted: [{ id: "state:1", rev: 2 }] }, "a deleted entity stays as it is");
  const stale = await push(book, A, [change("state:1", 0, { hardCc: false })]);
  assert.equal(stale.status, 409);
  assert.deepEqual(stale.body.conflicts.map((each) => [each.id, each.deleted, each.rev]), [["state:1", true, 2]]);
  assert.deepEqual((await push(book, A, [change("state:1", 2, { hardCc: false })])).body, { seq: 3, accepted: [{ id: "state:1", rev: 3 }] });
});

test("a push is all or nothing: one conflict, a lower schema or an entity named on a base it never had keeps every change out", async () => {
  const book = await freshBook();
  await push(book, A, [change("state:1", 0, { hardCc: true }, 2), change("state:2", 0, {})]);

  const conflict = await push(book, B, [change("state:2", 1, { minTurns: 1 }), change("state:3", 0, {}), change("state:1", 0, {}, 2)]);
  assert.equal(conflict.status, 409);
  assert.deepEqual(conflict.body.conflicts.map((each) => each.id), ["state:1"]);

  assert.deepEqual((await push(book, B, [change("state:2", 1, { minTurns: 1 }), change("state:1", 1, {}, 1)])).body, { code: "schema", id: "state:1", stored: 2 });

  const missing = await push(book, B, [change("state:2", 1, { minTurns: 1 }), change("state:4", 3, {})]);
  assert.deepEqual(missing, { status: 400, body: { code: "invalid", errors: [{ id: "state:4", message: "The entity does not exist; create it on base rev 0." }] } });

  assert.deepEqual((await pull(book, "since=0")).body.seq, 1);
  assert.deepEqual((await pull(book, "since=0")).body.entities.map((each) => [each.id, each.rev]), [["state:1", 1], ["state:2", 1]]);
});

test("a push names each wrong change once, and refuses a body over 256 KiB with too_big", async () => {
  const book = await freshBook();
  const answer = await push(book, A, [change("rules", 0, []), { id: "tier:1", kind: "boss", schema: 1, baseRev: 0, body: {} }, change("tier:2", 0, {}, 1000), change("tier:3", -1, {}), change("tier:3", 0, {}), change("tier:3", 0, {})]);
  assert.deepEqual(answer.body.errors.map((error) => error.id), ["rules", "tier:1", "tier:2", "tier:3", "tier:3"]);
  assert.equal(answer.body.errors.at(-1).message, "The id appears twice in the push.");

  assert.equal((await push(book, A, [], { designFormat: 0 })).status, 400);
  assert.equal((await push(book, A, Array.from({ length: DESIGN_LIMITS.maxChanges + 1 }, (_, index) => change(`state:${index}`, 0, {})))).status, 400);
  assert.deepEqual((await push(book, A, [change("catalog", 0, { text: "x".repeat(DESIGN_LIMITS.maxEntityBytes) })])).body, { code: "too_big" });
  assert.equal((await push(book, A, [change("catalog", 0, { text: "x".repeat(DESIGN_LIMITS.maxEntityBytes - 20) })])).status, 200);
});

test("more than 20 deletes pass only with confirmDeletes from a designer admin", async () => {
  const book = await freshBook();
  const ids = Array.from({ length: 21 }, (_, index) => `state:${index + 1}`);
  await push(book, A, ids.map((id) => change(id, 0, {})));
  const deletes = ids.map((id) => change(id, 1, null));

  assert.deepEqual((await push(book, A, deletes)).body, { code: "deletes", count: 21 });
  assert.deepEqual((await push(book, B, deletes, { confirmDeletes: true })).body, { code: "deletes", count: 21 });
  assert.equal((await push(book, A, deletes, { confirmDeletes: true })).status, 200);
  assert.equal((await push(book, A, deletes.slice(0, 20).map((each) => ({ ...each, baseRev: 2 })))).status, 200, "20 deletes need no confirmation");
});

test("a released designer's push raises the design format and the lowest format, a development build's never does", async () => {
  const store = memoryDesignStore();
  const book = await fixtureBook(store);
  const dev = { ...A, "X-MGQ-Designer-Version": "0.0.0-dev" };

  await push(book, dev, [change("state:1", 0, {})], { designFormat: 3 });
  assert.deepEqual(await book.state(), { seq: 1, designFormat: 1, minFormat: 1 });

  await push(book, A, [change("state:2", 0, {})], { designFormat: 2 });
  assert.deepEqual(await book.state(), { seq: 2, designFormat: 2, minFormat: 2 });

  const behind = await push(book, { ...B, "X-MGQ-Design-Format": "2" }, [change("state:3", 0, {})], { designFormat: 1 });
  assert.deepEqual(behind, { status: 426, body: { code: "update", minimum: "1.2.0", minFormat: 2 } });
  assert.equal((await pull(book, "since=0")).status, 426, "a designer naming format 1 reads no more");
  assert.equal((await send(book, { method: "GET", path: "/v1/designs/me", headers: A, body: null })).body.minFormat, 2, "me answers any format");
});

test("a development build reads as any designer and writes only as an admin or where the relay allows it", async () => {
  const book = await freshBook();
  const devB = { ...B, "X-MGQ-Designer-Version": "0.0.0-dev" };
  assert.equal((await pull(book, "since=0")).status, 200);
  assert.equal((await send(book, { method: "GET", path: "/v1/designs/entities?since=0", headers: devB, body: null })).status, 200);
  assert.deepEqual((await push(book, devB, [change("state:1", 0, {})])).body, { code: "dev_build" });
  assert.equal((await push(book, { ...A, "X-MGQ-Designer-Version": "0.0.0-dev" }, [change("state:1", 0, {})])).status, 200);

  const open = new DesignBook(memoryDesignStore(), { allowDev: true });
  await open.store.putDesigner({ id: DESIGNERS.B.id, name: "B", admin: false, addedBy: "test", at: 0 });
  assert.equal((await push(open, devB, [change("state:1", 0, {})])).status, 200);
});

test("a pull pages by id with the next id only while more follow, and a page names at most 500", async () => {
  const book = await freshBook();
  await push(book, A, ["state:1", "state:2", "state:3", "state:4"].map((id) => change(id, 0, {})));

  const first = await pull(book, "since=0&limit=2");
  assert.deepEqual([first.body.entities.map((each) => each.id), first.body.next], [["state:1", "state:2"], "state:2"]);
  const last = await pull(book, "since=0&after=state:2&limit=2");
  assert.deepEqual([last.body.entities.map((each) => each.id), last.body.next], [["state:3", "state:4"], null]);
  assert.equal((await pull(book, "since=0&limit=9999")).body.entities.length, 4);
  assert.equal((await pull(book, "since=abc")).status, 400);
});

test("history keeps the last 50 revisions of each entity, newest first", async () => {
  const book = await bookWithPushes({ burst: 100, refillMs: 60_000 });
  let rev = 0;

  for (let index = 0; index < 55; index++) {
    rev = (await push(book, A, [change("state:7", rev, { minTurns: index })])).body.seq;
  }

  const history = await send(book, { method: "GET", path: "/v1/designs/entities/state:7/history", headers: A, body: null });
  assert.equal(history.body.revisions.length, 50);
  assert.deepEqual([history.body.revisions[0].rev, history.body.revisions.at(-1).rev], [55, 6]);
  assert.equal((await send(book, { method: "GET", path: "/v1/designs/entities/state:7/history?limit=3", headers: A, body: null })).body.revisions.length, 3);
  assert.deepEqual((await send(book, { method: "GET", path: "/v1/designs/entities/state:8/history", headers: A, body: null })).body, { id: "state:8", revisions: [] });
  assert.equal((await send(book, { method: "GET", path: "/v1/designs/entities/boss:Lilith/history", headers: A, body: null })).status, 400);
});

test("two pushes on the same base at once: one lands, the other meets it as a conflict", async () => {
  const book = await freshBook();
  await push(book, A, [change("catalog", 0, { bossSwitch: 1 })]);
  const answers = await Promise.all([push(book, A, [change("catalog", 1, { bossSwitch: 2 })]), push(book, B, [change("catalog", 1, { bossSwitch: 3 })])]);
  assert.deepEqual(answers.map((answer) => answer.status), [200, 409]);
  assert.deepEqual(answers[1].body.conflicts[0].body, { bossSwitch: 2 });
});

test("a push tells what to send the other designers, and the rate limit counts each designer apart", async () => {
  const book = await bookWithPushes({ burst: 1, refillMs: 60_000 });
  const pushed = await push(book, A, [change("state:1", 0, {})]);
  assert.deepEqual(pushed.pushed, { seq: 1, by: DESIGNERS.A.id, name: DESIGNERS.A.name, ids: ["state:1"] });
  assert.deepEqual(Object.keys(pushed.pushed).sort(), Object.keys(fixture("socket.json").serverToClient.find((frame) => frame.op === "pushed")).filter((key) => key !== "op").sort());
  assert.deepEqual((await push(book, A, [])).body, { code: "rate" });
  assert.deepEqual((await push(book, B, [])).body, { seq: 1, accepted: [] }, "an empty push changes nothing");
});

test("me names any key's id, renames a listed designer and notes when it was seen", async () => {
  const store = memoryDesignStore();
  const book = await fixtureBook(store);
  const me = (headers, method = "GET", body = null) => send(book, { method, path: "/v1/designs/me", headers, body });

  assert.deepEqual((await me({ ...A, "X-MGQ-Designer": "not a key" })).body, { code: "not_designer" });
  assert.deepEqual((await me({ ...A, "X-MGQ-Designer": DESIGNERS.C.key, "X-MGQ-Designer-Version": "0.1.0" })).body, { id: DESIGNERS.C.id, designer: false });
  assert.equal((await me({ ...B, "X-MGQ-Designer-Version": "0.1.0", "X-MGQ-Design-Format": "0" })).body.designer, true, "me has no version gate");
  assert.equal((await store.designer(DESIGNERS.B.id)).last_seen, NOW);

  assert.deepEqual((await me(B, "PUT", { name: "  Lime\n" })).body, { id: DESIGNERS.B.id, name: "Lime" });
  assert.equal((await me(B, "PUT", { name: " " })).status, 400);
  assert.deepEqual((await me({ ...A, "X-MGQ-Designer": DESIGNERS.C.key }, "PUT", { name: "C" })).body, { code: "not_designer", id: DESIGNERS.C.id });
  assert.equal((await store.designer(DESIGNERS.B.id)).admin, 0, "a rename keeps the admin flag");
});

test("designer admins and relay admins manage the designers; a relay admin can never push", async () => {
  const book = await freshBook();
  const relayAdmin = { "X-MGQ-Player": RELAY_ADMIN_KEY };
  const put = (headers, id, body) => send(book, { method: "PUT", path: `/v1/designs/designers/${id}`, headers, body });

  assert.deepEqual((await put(B, DESIGNERS.C.id, { name: "C" })).body, { code: "admin_only" });
  assert.deepEqual((await put(relayAdmin, DESIGNERS.C.id, { admin: true })).body, { code: "invalid", errors: [{ id: DESIGNERS.C.id, message: "A new designer needs a name." }] });
  assert.deepEqual((await put(relayAdmin, DESIGNERS.C.id, { name: "C" })).body, { id: DESIGNERS.C.id, name: "C", admin: false });
  assert.deepEqual((await put(A, DESIGNERS.C.id, { admin: true })).body, { id: DESIGNERS.C.id, name: "C", admin: true }, "a change keeps what it leaves out");
  assert.equal((await put(A, "C", { name: "C" })).status, 400);
  assert.equal((await send(book, { method: "GET", path: "/v1/designs/designers", headers: relayAdmin, body: null })).body.designers.length, 3);

  assert.deepEqual((await send(book, { method: "POST", path: "/v1/designs/push", headers: relayAdmin, body: { designFormat: 1, changes: [] } })).body, { code: "not_designer" });
  assert.deepEqual((await send(book, { method: "GET", path: "/v1/designs/entities", headers: relayAdmin, body: null })).body, { code: "not_designer" });
  assert.deepEqual((await send(book, { method: "GET", path: "/v1/designs/designers", headers: { "X-MGQ-Player": "b".repeat(32) }, body: null })).body, { code: "not_designer" });

  assert.deepEqual((await send(book, { method: "DELETE", path: `/v1/designs/designers/${DESIGNERS.C.id}`, headers: relayAdmin, body: null })).body, {});
  assert.equal(await book.store.designer(DESIGNERS.C.id), undefined);
});

test("the admins DESIGNER_ADMINS names are added under the start of their id, and a listed one keeps its row", async () => {
  const store = memoryDesignStore();
  const book = new DesignBook(store, { clock: () => NOW * 1000 });
  await store.putDesigner({ id: DESIGNERS.B.id, name: DESIGNERS.B.name, admin: false, addedBy: "test", at: 0 });
  await book.seedAdmins([DESIGNERS.A.id, DESIGNERS.B.id]);

  assert.deepEqual(await store.designer(DESIGNERS.A.id), { id: DESIGNERS.A.id, name: DESIGNERS.A.id.slice(0, 8), admin: 1, added_by: SEEDED_BY, at: NOW, last_seen: null });
  assert.deepEqual([(await store.designer(DESIGNERS.B.id)).name, (await store.designer(DESIGNERS.B.id)).admin], [DESIGNERS.B.name, 0]);
});

test("a seeded admin demoted through the designer routes stays demoted when the relay seeds again, and a removed one comes back", async () => {
  const store = memoryDesignStore();
  const book = new DesignBook(store, { clock: () => NOW * 1000 });
  await book.seedAdmins([DESIGNERS.A.id, DESIGNERS.B.id]);
  assert.equal((await send(book, { method: "PUT", path: `/v1/designs/designers/${DESIGNERS.B.id}`, headers: A, body: { admin: false } })).status, 200);

  await book.seedAdmins([DESIGNERS.A.id, DESIGNERS.B.id]);
  assert.equal((await store.designer(DESIGNERS.B.id)).admin, 0, "the restart keeps the demotion");

  assert.equal((await send(book, { method: "DELETE", path: `/v1/designs/designers/${DESIGNERS.B.id}`, headers: A, body: null })).status, 200);
  await book.seedAdmins([DESIGNERS.A.id, DESIGNERS.B.id]);
  assert.equal((await store.designer(DESIGNERS.B.id)).admin, 1, "a removed seeded admin is seeded again");
});

test("the lowest designer version is the setting's, every version without a setting, and other paths are no routes", async () => {
  assert.equal(new DesignBook(memoryDesignStore()).minVersion, DEFAULT_DESIGNER_MIN_VERSION);
  assert.equal(new DesignBook(memoryDesignStore(), { minVersion: "0.0.0-dev" }).minVersion, DEFAULT_DESIGNER_MIN_VERSION);
  assert.equal(new DesignBook(memoryDesignStore(), { minVersion: " 1.4 " }).minVersion, "1.4");

  const book = await freshBook();
  await seedEntities(book.store, [entity("rules", 1, {})]);

  for (const [method, path] of [["GET", "/v1/designs/builds/1/report"], ["PUT", "/v1/designs/publish"], ["GET", "/v1/designs/format"], ["POST", "/v1/designs/me"], ["GET", "/v1/designs"]]) {
    assert.deepEqual((await send(book, { method, path, headers: A, body: null })).body, { error: "there is no such route" }, `${method} ${path}`);
  }

  assert.deepEqual((await send(book, { method: "GET", path: "/v1/designs/release", headers: A, body: null })).body, { code: "none" }, "a relay without designer releases names none");
});
