//----------------------------------------------------------------
//  test_designs.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Replayed the build exchanges over a compiler the tests drive and took canonical JSON from the designs
//      Paulinchen  2026-10-21: Replayed the release exchanges over a release the relay serves
//                            - Created
//
//----------------------------------------------------------------

// What the design tests share: the contract's fixtures, canonical JSON to compare answers by, and
// the state each fixture's exchanges start from, so every design store replays them alike.

import { createHash, generateKeyPairSync } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { gzipSync } from "node:zlib";
import { DesignerReleases } from "./designer_releases.js";
import { playerIdOf } from "./directory.js";
import { DESIGN_FORMAT_HEADER, DESIGNER_HEADER, DESIGNER_VERSION_HEADER } from "./gate.js";
import { DesignBook, canonicalJson, handleDesignRequest } from "./designs.js";
import { PLAYER_HEADER } from "./relay.js";

/**
 * The folder of the contract's fixtures, a copy of MGQ-Online-Raid-Designer/contract/designs.
 */
const FIXTURES = new URL("./fixtures/designs/", import.meta.url);

/**
 * The lowest designer version the fixtures' relay serves.
 */
export const MIN_VERSION = "1.2.0";

/**
 * The time the fixtures' relay runs at, in unix seconds.
 */
export const NOW = 1792500000;

/**
 * The player key of the relay admin in the fixtures.
 */
export const RELAY_ADMIN_KEY = "aaaabbbbccccddddeeeeffff00001111";

/**
 * Reads one of the contract's fixtures.
 *
 * @param {string} name The file name, such as `me.json`.
 * @returns {any} The fixture.
 */
export function fixture(name) {
  return JSON.parse(readFileSync(new URL(name, FIXTURES), "utf8"));
}

/**
 * Lists the contract's fixtures.
 *
 * @returns {string[]} Their file names, sorted.
 */
export function fixtureNames() {
  return readdirSync(FIXTURES).filter((name) => name.endsWith(".json")).sort();
}

/**
 * The fixtures' sample designers: A, a listed admin; B, a listed designer; C, a key the relay does
 * not list.
 */
export const DESIGNERS = Object.freeze(Object.fromEntries(fixture("identity.json").designers.map((designer, index) => ["ABC"[index], Object.freeze(designer)])));

export { canonicalJson };

/**
 * Reads the headers of a fixture's request as the design routes take them.
 *
 * @param {Record<string, string>} headers The headers.
 * @returns {{designer: string | null, player: string | null, version: string | null, format: string | null}} The client.
 */
export function clientOf(headers) {
  return {
    designer: headers[DESIGNER_HEADER] ?? null,
    player: headers[PLAYER_HEADER] ?? null,
    version: headers[DESIGNER_VERSION_HEADER] ?? null,
    format: headers[DESIGN_FORMAT_HEADER] ?? null,
  };
}

/**
 * Sends a fixture's request to the design routes.
 *
 * @param {DesignBook} book The design.
 * @param {{method: string, path: string, headers: Record<string, string>, body: any}} request The request.
 * @returns {Promise<{status: number, body: object}>} The answer.
 */
export function send(book, request) {
  const text = request.body === null || request.body === undefined ? "" : JSON.stringify(request.body);
  const readBody = async (limit) => (new TextEncoder().encode(text).length > limit ? null : text);
  return handleDesignRequest(book, request.method, new URL(`https://relay.test${request.path}`), clientOf(request.headers), readBody, async () => {});
}

/**
 * Keeps wire entities in a store as the pushes that made them, one push per rev.
 *
 * @param {import("./designs.js").DesignStore} store The store.
 * @param {{id: string, kind: string, schema: number, rev: number, deleted?: boolean, body: object | null, by: string, name: string, at: number}[]} entities The entities, earlier revisions of one entity included.
 * @returns {Promise<void>} Completes once kept.
 */
export async function seedEntities(store, entities) {
  for (const rev of [...new Set(entities.map((entity) => entity.rev))].sort((left, right) => left - right)) {
    const pushed = entities.filter((entity) => entity.rev === rev);
    await store.commit({
      seq: rev, by: pushed[0].by, name: pushed[0].name, at: pushed[0].at, message: "seed", designFormat: 1, clientVersion: "1.3.0", keep: 50, format: null,
      entities: pushed.map((entity) => ({ id: entity.id, kind: entity.kind, schema: entity.schema, body: entity.body === null ? null : JSON.stringify(entity.body), deleted: entity.body === null })),
    });
  }
}

/**
 * Makes a design book over a store as the fixtures' relay runs it, with designers A and B listed.
 *
 * @param {import("./designs.js").DesignStore} store The store.
 * @param {{presence?: {of: (id: string) => {online: boolean, editing: string | null}}, releases?: () => object, compiler?: () => object}} [options] Who is online; makes the designer release served, none unless given; makes the compiler, none unless given.
 * @returns {Promise<DesignBook>} The book.
 */
export async function fixtureBook(store, { presence, releases, compiler } = {}) {
  const book = new DesignBook(store, {
    clock: () => NOW * 1000, minVersion: MIN_VERSION, relayAdmins: new Set([await playerIdOf(RELAY_ADMIN_KEY)]), ...(presence ? { presence } : {}), ...(releases ? { releases: releases() } : {}),
    ...(compiler ? { compiler: compiler() } : {}),
  });

  for (const designer of [DESIGNERS.A, DESIGNERS.B]) {
    await store.putDesigner({ id: designer.id, name: designer.name, admin: designer.admin, addedBy: "test", at: NOW });
  }

  return book;
}

/**
 * Makes a wire entity the fixtures' designers pushed, for a state an exchange starts from.
 *
 * @param {string} id The entity id.
 * @param {number} rev Its rev.
 * @param {object | null} body Its body, null for a tombstone.
 * @param {{designer?: object, at?: number, schema?: number}} [options] Who pushed it, A unless given; when, NOW unless given; its schema, 1 unless given.
 * @returns {object} The wire entity.
 */
export function entity(id, rev, body, { designer = DESIGNERS.A, at = NOW, schema = 1 } = {}) {
  return { id, kind: id.split(":")[0], schema, rev, deleted: body === null, body, by: designer.id, name: designer.name, at };
}

/**
 * Makes the designer releases as serving the release of release.json, whose signature is a
 * placeholder and so is restored rather than checked.
 *
 * @returns {DesignerReleases} The releases.
 */
export function fixtureReleases() {
  const publicKey = generateKeyPairSync("ec", { namedCurve: "P-256" }).publicKey.export({ type: "spki", format: "pem" });
  const releases = new DesignerReleases({ repo: "owner/designer", token: "token", publicKey, dataDir: tmpdir() });
  const answer = fixture("release.json").exchanges[0].response.body;
  const manifest = JSON.parse(Buffer.from(answer.manifest, "base64").toString("utf8"));
  releases.restore({ version: answer.version, notes: answer.notes, manifest: answer.manifest, signature: answer.signature, sha256: answer.sha256, size: answer.size, name: manifest.files[0].name });
  return releases;
}

/**
 * Makes a compiler that compiles in memory, as the tests drive it: each compile waits for the
 * test's go-ahead when one is asked for, and ends as the test sets.
 *
 * @param {{designFormat?: number, message?: string | null}} [probe] What its probe names: design format 1 and no refusal unless given.
 * @returns {{probe: () => Promise<object>, prepare: (id: number, snapshot: string) => Promise<void>, compile: (job: object) => Promise<object>, clean: (id: number) => Promise<void>, reset: () => Promise<void>, snapshots: Map<number, string>, jobs: object[], probes: number, hold: () => () => void, outcome: (job: object) => object}} The compiler, with the snapshots it was given, the jobs it ran, how often it was probed, a hold that keeps the next compiles waiting until its release is called, and the outcome the test sets.
 */
export function fakeCompiler({ designFormat = 1, message = null } = {}) {
  let gate = Promise.resolve();
  const compiler = {
    snapshots: new Map(),
    jobs: [],
    probes: 0,
    probe: async () => {
      compiler.probes += 1;
      return { designFormat, version: "1.3.0", message };
    },
    prepare: async (id, snapshot) => void compiler.snapshots.set(id, snapshot),
    compile: async (job) => {
      compiler.jobs.push(job);
      await gate;
      return compiler.outcome(job);
    },
    clean: async () => {},
    reset: async () => {},
    hold: () => {
      let release;
      gate = new Promise((resolve) => {
        release = resolve;
      });
      return release;
    },
    outcome: (job) => compiledBuild(job.seq),
  };
  return compiler;
}

/**
 * Makes the result of an ok build whose blobs are made of its seq, so each seq gives other bytes.
 *
 * @param {number} seq The build's seq.
 * @param {{removed?: string[], renamed?: object[]}} [catalogDiff] The catalog changes its report names.
 * @returns {{status: string, report: object, fields: object, blobs: object[]}} The result.
 */
export function compiledBuild(seq, catalogDiff = {}) {
  const blob = (kind) => {
    const text = `${kind} ${seq}`;
    const sha256 = createHash("sha256").update(text).digest("hex");
    return { sha256, kind, size: text.length, gz: new Uint8Array(gzipSync(text)) };
  };
  const blobs = [blob("marshal"), blob("runtime"), blob("snapshot")];
  const [marshal, runtime, snapshot] = blobs;
  const report = {
    ok: true, designFormat: 1, format: 3, runtimeFormat: 1, seq, snapshotSha256: snapshot.sha256, marshal: { sha256: marshal.sha256, size: marshal.size }, runtime: { sha256: runtime.sha256, size: runtime.size },
    compiler: "1.3.0", gameData: "ab".repeat(32), bossKeys: [], catalogDiff: { removed: [], renamed: [], troopsChanged: [], ...catalogDiff }, issues: [],
  };
  const fields = { snapshotSha: snapshot.sha256, runtimeSha: runtime.sha256, marshalSha: marshal.sha256, format: 3, runtimeFormat: 1, compiler: "1.3.0", gameData: report.gameData };
  return { status: "ok", report, fields, blobs };
}

/**
 * The state each exchange fixture starts from, and what changes a request before it is sent.
 */
export const SCENARIOS = Object.freeze([
  {
    file: "me.json",
    setup: (store) => seedEntities(store, [entity("rules", 418, {})]),
  },
  {
    file: "pull.json",
    setup: (store) => {
      const [first, last, since] = fixture("pull.json").exchanges.map((exchange) => exchange.response.body.entities);
      return seedEntities(store, [...first, ...last, ...since.filter((each) => each.deleted), entity("state:41", 300, { hardCc: true }, { designer: DESIGNERS.B, at: 1792300000 })]);
    },
  },
  {
    file: "push.json",
    setup: (store) => seedEntities(store, [
      entity("boss:1b0a822614f83839e33ac1cbaa895e36", 417, { key: "morrigan" }), entity("state:40", 15, { hardCc: false }), entity("state:41", 300, { hardCc: true }), entity("rules", 418, {}),
    ]),
  },
  {
    file: "conflict.json",
    setup: (store) => seedEntities(store, fixture("conflict.json").exchanges[0].response.body.conflicts),
  },
  {
    file: "schema.json",
    setup: (store) => seedEntities(store, [entity("state:40", 421, { hardCc: true, disables: 2 }, { schema: 2 })]),
  },
  {
    file: "designers.json",
    setup: async () => {},
    presence: {
      of: (id) => ({
        [DESIGNERS.A.id]: { online: true, editing: "boss:1b0a822614f83839e33ac1cbaa895e36" },
        [DESIGNERS.B.id]: { online: true, editing: null },
      })[id] ?? { online: false, editing: null },
    },
  },
  {
    file: "history.json",
    setup: (store) => seedEntities(store, [...fixture("history.json").exchanges[0].response.body.revisions].reverse().map((revision) => ({ ...revision, id: "state:41", kind: "state" }))),
  },
  {
    file: "refusals.json",
    setup: (store) => seedEntities(store, [entity("rules", 419, {})]),
    before: {
      // Every turn of designer B's push allowance is taken.
      "rate limit": (book) => {
        while (book.pushes.take(DESIGNERS.B.id)) {
          // Taken.
        }
      },
    },
    request: {
      "body too big": (request) => ({ ...request, body: { ...request.body, changes: [{ ...request.body.changes[0], body: { ...request.body.changes[0].body, description: "x".repeat(300 * 1024) } }] } }),
    },
    // A compiler that names no design format, as a missing one.
    compiler: () => fakeCompiler({ designFormat: 0 }),
  },
  {
    file: "release.json",
    setup: async () => {},
    releases: fixtureReleases,
  },
]);

/**
 * Replays every exchange of the scenarios over fresh stores and tells how each answer compares
 * with the fixture's.
 *
 * @param {() => Promise<import("./designs.js").DesignStore> | import("./designs.js").DesignStore} makeStore Makes an empty store.
 * @returns {Promise<{file: string, name: string, expected: {status: number, body: object}, actual: {status: number, body: object}}[]>} Every exchange's expected and actual answer, canonical bodies.
 */
export async function replayScenarios(makeStore) {
  const results = [];

  for (const scenario of SCENARIOS) {
    const store = await makeStore();
    const book = await fixtureBook(store, scenario);
    await scenario.setup(store);

    try {
      for (const exchange of fixture(scenario.file).exchanges) {
        scenario.before?.[exchange.name]?.(book);
        const request = scenario.request?.[exchange.name]?.(exchange.request) ?? exchange.request;
        const answer = await send(book, request);
        results.push({
          file: scenario.file, name: exchange.name,
          expected: { status: exchange.response.status, body: canonicalJson(exchange.response.body) },
          actual: { status: answer.status, body: canonicalJson(answer.body) },
        });
      }
    } finally {
      store.close();
    }
  }

  return results;
}
