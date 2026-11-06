//----------------------------------------------------------------
//  designs_server.test.js
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the tests of the migration
//      Paulinchen  2026-10-22: Answered the builds route on a relay without a compiler
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DESIGN_LIMITS } from "../core/designs.js";
import { Directory, playerIdOf } from "../core/directory.js";
import { PLAYER_HEADER } from "../core/relay.js";
import { DESIGNERS, RELAY_ADMIN_KEY, fixtureBook } from "../core/test_designs.js";
import { createRelay, openStores } from "./server.js";

/**
 * A relay admin's player key, of the directory and of the designer list.
 */
const ADMIN = RELAY_ADMIN_KEY;

/**
 * Logs nothing.
 */
const QUIET = { info: () => {}, error: () => {} };

/**
 * The headers of designer A, a listed admin, on a released version.
 */
const A = { "X-MGQ-Designer": DESIGNERS.A.key, "X-MGQ-Features": "designer", "X-MGQ-Designer-Version": "1.3.0", "X-MGQ-Design-Format": "1" };

let folder;
let stores;
let relay;
let address;

before(async () => {
  folder = mkdtempSync(join(tmpdir(), "mgq-designs-server-"));
  stores = await openStores(join(folder, "relay.db"));
  const directory = new Directory(stores.directory, { admins: [await playerIdOf(ADMIN)] });
  const designs = await fixtureBook(stores.designs);
  relay = createRelay({ checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, log: QUIET, directory, stories: stores.stories, bosses: stores.bosses, designs });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  address = `http://127.0.0.1:${relay.server.address().port}`;
});

after(async () => {
  await relay.stop();
  stores.close();
  rmSync(folder, { recursive: true, force: true });
});

/**
 * Sends a request to the relay.
 *
 * @param {string} method The HTTP method.
 * @param {string} path The path.
 * @param {Record<string, string>} headers The headers.
 * @param {unknown} [body] The JSON body, a text as it is, none when left out.
 * @returns {Promise<{status: number, body: any}>} The answer.
 */
async function call(method, path, headers, body) {
  const text = body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body);
  const response = await fetch(`${address}${path}`, { method, headers, body: text });
  return { status: response.status, body: await response.json() };
}

test("a designer pushes and pulls over HTTP without the game's X-MGQ-Features or X-MGQ-Version", async () => {
  const headers = { ...A };
  delete headers["X-MGQ-Features"];
  const pushed = await call("POST", "/v1/designs/push", headers, { designFormat: 1, message: "first", changes: [{ id: "catalog", kind: "catalog", schema: 1, baseRev: 0, body: { bossSwitch: 22 } }] });
  assert.deepEqual(pushed, { status: 200, body: { seq: 1, accepted: [{ id: "catalog", rev: 1 }] } });

  const pulled = await call("GET", "/v1/designs/entities?since=0", headers);
  assert.deepEqual(pulled.body.entities.map((entity) => [entity.id, entity.body, entity.name]), [["catalog", { bossSwitch: 22 }, DESIGNERS.A.name]]);
  assert.deepEqual((await call("GET", "/v1/designs/me", { "X-MGQ-Designer": DESIGNERS.C.key })).body, { id: DESIGNERS.C.id, designer: false });
  assert.deepEqual(await call("GET", "/v1/designs/entities", { ...headers, "X-MGQ-Designer": DESIGNERS.C.key }), { status: 403, body: { code: "not_designer", id: DESIGNERS.C.id } });
  assert.deepEqual(await call("GET", "/v1/designs/builds", headers), { status: 200, body: { live: null, previous: null, builds: [] } });
  assert.deepEqual(await call("POST", "/v1/designs/builds", headers, { seq: 1 }), { status: 503, body: { code: "compiler", message: "This relay has no compiler." } });
  assert.deepEqual((await call("GET", "/v1/designs/designers", { [PLAYER_HEADER]: ADMIN })).body.designers.map((designer) => designer.id), [DESIGNERS.A.id, DESIGNERS.B.id]);
});

test("a push takes up to 2 MiB and every other design route up to 256 KiB, past which each answers too_big", async () => {
  const body = (size) => ({ name: "x".repeat(size) });
  const changes = Array.from({ length: 6 }, (_, index) => ({ id: `state:${100 + index}`, kind: "state", schema: 1, baseRev: 0, body: body(250 * 1024) }));
  assert.equal((await call("POST", "/v1/designs/push", A, { designFormat: 1, message: "large", changes })).status, 200, "1.5 MiB in six bodies");

  const tooMany = Array.from({ length: 9 }, (_, index) => ({ id: `state:${200 + index}`, kind: "state", schema: 1, baseRev: 0, body: body(250 * 1024) }));
  assert.deepEqual(await call("POST", "/v1/designs/push", A, { designFormat: 1, message: "too large", changes: tooMany }), { status: 413, body: { code: "too_big" } });
  assert.deepEqual(await call("PUT", "/v1/designs/me", A, { name: "x".repeat(DESIGN_LIMITS.maxBodyBytes) }), { status: 413, body: { code: "too_big" } });
  assert.deepEqual(await call("POST", "/v1/designs/push", A, "{not json"), { status: 400, body: { code: "invalid", errors: [{ id: null, message: "The body is no JSON." }] } });
});

test("a refused push still has its whole body read, so the refusal reaches the designer", async () => {
  const refused = await call("POST", "/v1/designs/push", { ...A, "X-MGQ-Designer-Version": "1.0.0" }, { designFormat: 1, changes: [{ id: "state:300", kind: "state", schema: 1, baseRev: 0, body: { text: "x".repeat(1024 * 1024) } }] });
  assert.deepEqual(refused, { status: 426, body: { code: "update", minimum: "1.2.0", minFormat: 1 } });
});
