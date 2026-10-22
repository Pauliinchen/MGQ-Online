//----------------------------------------------------------------
//  designs.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Left the designers DESIGNER_ADMINS names alone once listed
//                            - Failed a build whose result could not be kept
//                            - Told the world rooms of new live builds in the order they went live
//                            - Checked a build or publish request before counting it against the rate limit
//                            - Refused to publish a build compiled against another live build
//                            - Built the design on the server one build at a time, published a build, rolled back to the previous one and served the live build to games
//      Paulinchen  2026-10-21: Kept the designers' presence and their sockets and served the newest designer release
//                            - Created
//
//----------------------------------------------------------------

// The Raid designs several designers edit together, on the Node relay only: entities with their
// revisions and history, all-or-nothing pushes on a base revision, pulls since a revision, the
// designers the relay serves, who of them is online and what they edit, the newest designer
// release, the builds the compiler makes, the live build and the routes games read it from. The
// relay never reads an entity's body; the contract is
// MGQ-Online-Raid-Designer/docs/SERVER_FORMAT.md, its fixtures are in fixtures/designs.

import { playerIdOf, sha256Hex } from "./directory.js";
import { DEFAULT_DESIGNER_MIN_VERSION, DESIGN_ROUTE, GAME_DESIGN_ROUTE, designerRefusal, designerRuleOf, parseVersion } from "./gate.js";
import { notFound, routeIs } from "./http.js";
import { CONTROL_CHARACTERS, cleanText, isId } from "./ids.js";
import { RATE_LIMITS, RateLimiter } from "./relay.js";

/**
 * @typedef {object} DesignStore What the design book keeps its entities, history, pushes and designers in, see core/design_store_memory.js and node/design_store_sqlite.js.
 * @property {() => Promise<{seq: number, designFormat: number | undefined, minFormat: number | undefined}>} state The newest push's seq, 0 before the first, and the design formats, undefined while never set.
 * @property {(id: string) => Promise<object | undefined>} entity An entity's row with its designer's name, a tombstone included.
 * @property {(query: {since: number, after: string, limit: number, tombstones: boolean}) => Promise<object[]>} entities The rows changed after a seq whose ids come after an id, sorted by id.
 * @property {(id: string, limit: number) => Promise<object[]>} history An entity's revisions with their designers' names, newest first.
 * @property {(push: {seq: number, by: string, name: string, at: number, message: string, designFormat: number, clientVersion: string, entities: {id: string, kind: string, schema: number, body: string | null, deleted: boolean}[], keep: number, format: {designFormat: number, minFormat: number} | null}) => Promise<void>} commit Keeps a push, its entities and their history, keeping `keep` revisions per entity, all or nothing.
 * @property {(format: {designFormat: number, minFormat: number}) => Promise<void>} setFormat Sets the design formats.
 * @property {(id: string) => Promise<object | undefined>} designer A designer's row.
 * @property {() => Promise<object[]>} designers Every designer's row, sorted by name.
 * @property {(designer: {id: string, name: string, admin: boolean, addedBy: string, at: number}) => Promise<void>} putDesigner Adds a designer, or changes the name and admin flag of one.
 * @property {(id: string) => Promise<void>} removeDesigner Removes a designer.
 * @property {(id: string, at: number) => Promise<void>} seen Notes when a designer was last seen.
 * @property {() => Promise<Record<string, object[]>>} exportTables Every design table's rows, blobs without their bytes.
 * @property {(sha256: string) => Promise<Uint8Array | undefined>} blob A blob's gzipped bytes.
 * @property {(sha256: string) => Promise<{sha256: string, kind: string, size: number, at: number} | undefined>} blobInfo A blob's row without its bytes, `size` the bytes before gzip.
 * @property {(build: {seq: number, by: string, at: number}) => Promise<number>} addBuild Adds a queued build and hands out its id, never one handed out before.
 * @property {(id: number) => Promise<object | undefined>} build A build's row.
 * @property {(limit: number) => Promise<object[]>} builds The newest builds' rows, newest first.
 * @property {(id: number, status: string) => Promise<void>} setBuildStatus Sets a build's status.
 * @property {(id: number, fields: {status: string, report: string | null, snapshotSha: string | null, runtimeSha: string | null, marshalSha: string | null, format: number | null, runtimeFormat: number | null, compiler: string | null, gameData: string | null, baseBuildId: number | null}, blobs: {sha256: string, kind: string, size: number, gz: Uint8Array, at: number}[]) => Promise<void>} finishBuild Keeps a build's result, with the live build it was compiled against, null for none, and its blobs, all or nothing; a blob kept before stays as it is.
 * @property {(report: string) => Promise<number[]>} failUnfinished Fails every build still queued or compiling with a report, and hands out their ids.
 * @property {() => Promise<{build_id: number, previous_build_id: number | null, by: string, at: number} | undefined>} live The live build's row.
 * @property {(live: {buildId: number, previousBuildId: number | null, by: string, at: number}) => Promise<void>} setLive Sets the live build and the one before it.
 * @property {(keep: number) => Promise<{builds: number, blobs: number}>} tidyBuilds Drops the builds past the newest `keep` but the live, the previous and unfinished ones, then every blob no build names; hands out how many of each.
 * @property {(rows: Record<string, object[]>, blobs: Map<string, Uint8Array>) => Promise<void>} importTables Writes exported rows and blobs into an empty store.
 * @property {() => void} close Closes the store.
 */

/**
 * The entity kinds a design holds.
 */
export const DESIGN_KINDS = Object.freeze(["rules", "catalog", "tier", "boss", "skillDefault", "customSkill", "map", "tileset", "state", "bossFight"]);

/**
 * The pattern every entity id matches; the kind comes before the colon, or is the whole id.
 */
export const ENTITY_ID = /^(rules|catalog)$|^(tier|skillDefault|map|tileset|state|bossFight):\d{1,6}$|^(boss|customSkill):[0-9a-f]{32}$/;

/**
 * The first design format, which a relay without pushes from a released designer holds.
 */
export const FIRST_DESIGN_FORMAT = 1;

/**
 * The limits of the design routes.
 */
export const DESIGN_LIMITS = Object.freeze({
  // A push's whole body, in bytes.
  maxPushBytes: 2 * 1024 * 1024,
  // Every other route's body, in bytes.
  maxBodyBytes: 256 * 1024,
  // One entity's body as JSON, in bytes.
  maxEntityBytes: 256 * 1024,
  maxChanges: 200,
  // More deletes in one push need confirmDeletes from a designer admin.
  maxDeletes: 20,
  maxSchema: 999,
  maxFormat: 999,
  // Entities per page of a pull, and the page a pull asks for unless it names one.
  maxPage: 500,
  // Revisions kept per entity, and the most a history request hands out.
  historyKept: 50,
  maxNameLength: 32,
  maxMessageLength: 200,
  maxVersionLength: 64,
  // Builds kept beside the live and the previous one.
  buildsKept: 20,
});

/**
 * The rate limits of the design routes, per designer.
 */
export const DESIGN_RATE_LIMITS = Object.freeze({
  push: Object.freeze({ burst: 30, refillMs: 2 * 1000 }),
  build: Object.freeze({ burst: 3, refillMs: 5 * 60 * 1000 }),
  // Publishing and rolling back, counted together.
  publish: Object.freeze({ burst: 3, refillMs: 60 * 1000 }),
  // Three downloads of the designer's exe an hour.
  releaseFile: Object.freeze({ burst: 3, refillMs: 20 * 60 * 1000 }),
});

/**
 * The designer socket's limits and timings.
 */
export const DESIGN_SOCKET = Object.freeze({
  // The part of the address after `designs`.
  route: "socket",
  // How long a designer's presence lasts unless it is told again.
  presenceTtlMs: 60 * 1000,
  // The fewest milliseconds between two presence frames of one designer.
  editingEveryMs: 1000,
  pingEveryMs: 30 * 1000,
  // How often presences past their TTL are looked for.
  expireEveryMs: 10 * 1000,
  // The largest frame a designer sends, in bytes; a larger one closes its socket.
  maxFrameBytes: 4 * 1024,
  maxPathLength: 200,
});

/**
 * The close codes of the designer socket.
 */
export const DESIGN_CLOSE = Object.freeze({
  notDesigner: Object.freeze({ code: 4403, reason: "not a designer" }),
  update: Object.freeze({ code: 4426, reason: "update" }),
});

/**
 * The statuses of a build: waiting for the compiler, compiling, compiled, refused by the
 * compiler's checks, or failed.
 */
export const BUILD_STATUS = Object.freeze({ queued: "queued", compiling: "compiling", ok: "ok", refused: "refused", failed: "failed" });

/**
 * The `format` field of a snapshot, the compiler's input.
 */
export const SNAPSHOT_FORMAT = "mgq-raid-design-snapshot";

/**
 * The request header in which a game names the highest compiled format it reads, an integer.
 */
export const DESIGN_READER_HEADER = "X-MGQ-Design-Reader";

/**
 * The world-room text frame that tells every game of a new live build, followed by the build's
 * marshal and runtime SHA-256.
 */
export const WORLD_DESIGN_FRAME = "raid_design";

/**
 * A SHA-256 as the builds and the game routes write it.
 */
const SHA256 = /^[0-9a-f]{64}$/;

/**
 * The result fields of a build without them, as a failed or refused build keeps them.
 */
const EMPTY_FIELDS = Object.freeze({ snapshotSha: null, runtimeSha: null, marshalSha: null, format: null, runtimeFormat: null, compiler: null, gameData: null, baseBuildId: null });

/**
 * Who added the designer admins the DESIGNER_ADMINS setting names.
 */
export const SEEDED_BY = "DESIGNER_ADMINS";

/**
 * What a conflict tells the designer.
 */
const CONFLICT_MESSAGE = "Someone changed these since your base.";

/**
 * The ready state of an open WebSocket, the same in Node's ws and in browsers.
 */
const OPEN = 1;

/**
 * Turns a designer key into the designer id everyone sees, which does not give the key away and
 * differs from the player id the same text would give.
 *
 * @param {string} key The designer key.
 * @returns {Promise<string>} The designer id, 32 lowercase hexadecimal characters.
 */
export async function designerIdOf(key) {
  return (await sha256Hex(`mgqmp designer ${key}`)).slice(0, 32);
}

/**
 * Reads which design route an address names.
 *
 * @param {URL} url The request's address.
 * @returns {{rest: string[]} | null} The parts after `designs`, decoded; or null when it is no design route.
 */
export function designRouteOf(url) {
  if (!routeIs(url, DESIGN_ROUTE)) {
    return null;
  }

  try {
    return { rest: url.pathname.split("/").filter((part) => part.length > 0).slice(2).map((part) => decodeURIComponent(part)) };
  } catch {
    return { rest: [""] };
  }
}

/**
 * The answer of every design route on a relay that keeps no designs, such as the Cloudflare relay.
 *
 * @returns {{status: number, body: object}} The answer.
 */
export function noDesigns() {
  return { status: 404, body: { code: "no_designs" } };
}

/**
 * The answer for a request that is not as the contract asks.
 *
 * @param {{id: string | null, message: string}[]} errors What is wrong, per entity id where one is named.
 * @returns {{status: number, body: object}} The answer.
 */
function invalid(errors) {
  return { status: 400, body: { code: "invalid", errors } };
}

/**
 * The answer for a body longer than its route takes.
 *
 * @returns {{status: number, body: object}} The answer.
 */
function tooBig() {
  return { status: 413, body: { code: "too_big" } };
}

/**
 * Tells whether a value is a whole number within bounds.
 *
 * @param {unknown} value The value.
 * @param {number} min The lowest number.
 * @param {number} max The highest number.
 * @returns {boolean} Whether it is.
 */
function wholeIn(value, min, max) {
  return Number.isSafeInteger(value) && value >= min && value <= max;
}

/**
 * Tells whether a value is a JSON object, not a list.
 *
 * @param {unknown} value The value.
 * @returns {boolean} Whether it is.
 */
function isObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Counts the bytes of a text in UTF-8.
 *
 * @param {string} text The text.
 * @returns {number} The bytes.
 */
function utf8Length(text) {
  return new TextEncoder().encode(text).length;
}

/**
 * Writes a value as canonical JSON, as the contract compares values and the snapshot is written:
 * object keys in ordinal order, nulls in objects left out, integral numbers as integers and others
 * without an exponent.
 *
 * @param {unknown} value The value.
 * @returns {string} The canonical text.
 * @throws {Error} For a number the contract refuses.
 */
export function canonicalJson(value) {
  if (value === null || value === undefined) {
    return "null";
  }

  if (typeof value === "number") {
    return canonicalNumber(value);
  }

  if (typeof value !== "object") {
    return JSON.stringify(value);
  }

  if (Array.isArray(value)) {
    return `[${value.map((item) => canonicalJson(item)).join(",")}]`;
  }

  const keys = Object.keys(value).filter((key) => value[key] !== null && value[key] !== undefined).sort();
  return `{${keys.map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(",")}}`;
}

/**
 * Writes a number as the contract does.
 *
 * @param {number} value The number.
 * @returns {string} The number's text.
 * @throws {Error} For NaN, Infinity and non-integral numbers of 1e15 or more.
 */
function canonicalNumber(value) {
  if (Number.isInteger(value)) {
    return Number.isSafeInteger(value) ? String(value) : BigInt(value).toString();
  }

  if (!Number.isFinite(value) || Math.abs(value) >= 1e15) {
    throw new Error(`the contract refuses the number ${value}`);
  }

  const text = String(value);

  if (!text.includes("e")) {
    return text;
  }

  // Only numbers below 1e-6 come with an exponent here, always a negative one.
  const [mantissa, exponent] = text.split("e");
  const unsigned = mantissa.replace("-", "");
  const point = unsigned.indexOf(".");
  const digits = unsigned.replace(".", "");
  const whole = (point < 0 ? digits.length : point) + Number(exponent);
  return `${mantissa.startsWith("-") ? "-" : ""}0.${"0".repeat(-whole)}${digits}`;
}

/**
 * Turns a stored entity row into the entity the wire carries.
 *
 * @param {{id: string, kind: string, schema: number, rev: number, deleted: number, body: string | null, by: string, name: string, at: number}} row The row.
 * @returns {object} The wire entity.
 */
function wireEntity(row) {
  return { id: row.id, kind: row.kind, schema: row.schema, rev: row.rev, deleted: row.deleted === 1, body: row.body === null ? null : JSON.parse(row.body), by: row.by, name: row.name, at: row.at };
}

/**
 * Turns a stored build row into the build the wire carries.
 *
 * @param {{id: number, seq: number, status: string, format: number | null, marshal_sha: string | null, runtime_sha: string | null, snapshot_sha: string | null, report: string | null, by: string, at: number}} row The row.
 * @returns {object} The wire build, its report as JSON.
 */
function wireBuild(row) {
  return {
    id: row.id, seq: row.seq, status: row.status, format: row.format, marshalSha: row.marshal_sha, runtimeSha: row.runtime_sha, snapshotSha: row.snapshot_sha,
    report: row.report === null ? null : JSON.parse(row.report), by: row.by, at: row.at,
  };
}

/**
 * The answer for a build, a live build or a blob the relay does not hold.
 *
 * @returns {{status: number, body: object}} The answer.
 */
function none() {
  return { status: 404, body: { code: "none" } };
}

/**
 * The answer for a build the compiler cannot make.
 *
 * @param {string} message Why.
 * @returns {{status: number, body: object}} The answer.
 */
function compilerRefusal(message) {
  return { status: 503, body: { code: "compiler", message } };
}

/**
 * The report of a build the relay failed on its own, beside the compiler's reports.
 *
 * @param {string} message What went wrong.
 * @returns {object} The report.
 */
export function failureReport(message) {
  return { ok: false, failure: { message } };
}

/**
 * Reads the catalog changes a build's report names against the build live as it was compiled.
 *
 * @param {any} report The report.
 * @returns {{removed: string[], renamed: {id: string, from: string, to: string}[], troopsChanged: string[]}} The changes, lists the report lacks empty.
 */
export function catalogDiffOf(report) {
  const diff = report?.catalogDiff;
  const texts = (list) => (Array.isArray(list) ? list.filter((item) => typeof item === "string") : []);
  const renamed = Array.isArray(diff?.renamed) ? diff.renamed.filter((item) => isObject(item) && typeof item.from === "string" && typeof item.to === "string") : [];
  return { removed: texts(diff?.removed), renamed: renamed.map((item) => ({ id: item.id, from: item.from, to: item.to })), troopsChanged: texts(diff?.troopsChanged) };
}

/**
 * Tells whether a build was compiled against another live build than the one live now, so its
 * catalog changes, which the pools follow, no longer name what the publish changes.
 *
 * @param {{id: number, base_build_id: number | null}} build The build.
 * @param {{build_id: number} | undefined} live The live build's row, undefined for none.
 * @returns {boolean} Whether it was; never for the live build itself.
 */
function isStale(build, live) {
  const liveId = live?.build_id ?? null;
  return build.id !== liveId && (build.base_build_id ?? null) !== liveId;
}

/**
 * The world-room text frame that tells every game of a new live build.
 *
 * @param {string} marshalSha The build's marshal SHA-256.
 * @param {string} runtimeSha The build's runtime SHA-256.
 * @returns {string} The frame.
 */
export function worldDesignText(marshalSha, runtimeSha) {
  return `${WORLD_DESIGN_FRAME} ${marshalSha} ${runtimeSha}`;
}

/**
 * Reads a query parameter that must be a whole number.
 *
 * @param {URLSearchParams} query The query.
 * @param {string} name The parameter.
 * @param {number} fallback Its value when it is not given.
 * @returns {number | null} The number, the fallback when not given, null when it is no whole number.
 */
function wholeParameter(query, name, fallback) {
  const text = query.get(name);

  if (text === null || text === "") {
    return fallback;
  }

  return /^\d{1,15}$/.test(text) ? Number(text) : null;
}

/**
 * The frame that greets a designer on its socket.
 *
 * @param {number} seq The newest push's seq.
 * @param {{id: string, name: string, admin: boolean}} you The designer.
 * @param {{id: string, name: string, entity: string | null, path: string | null}[]} presence The other designers online and what they edit.
 * @returns {object} The frame.
 */
export function helloFrame(seq, you, presence) {
  return { op: "hello", seq, you: { id: you.id, name: you.name, admin: you.admin }, presence };
}

/**
 * The frame that tells the designers of a push.
 *
 * @param {{seq: number, by: string, name: string, ids: string[]}} pushed The push's seq, its designer's id and name and the ids it changed.
 * @returns {object} The frame.
 */
export function pushedFrame(pushed) {
  return { op: "pushed", seq: pushed.seq, by: pushed.by, name: pushed.name, ids: pushed.ids };
}

/**
 * The frame that tells the designers what one of them edits.
 *
 * @param {{id: string, name: string, entity: string | null, path: string | null}} presence The designer and what it edits, nulls for nothing.
 * @param {number} at When, in unix seconds.
 * @returns {object} The frame.
 */
export function presenceFrame(presence, at) {
  return { op: "presence", id: presence.id, name: presence.name, entity: presence.entity, path: presence.path, at };
}

/**
 * The frame that tells the designers one of them closed its last socket.
 *
 * @param {string} id The designer's id.
 * @returns {object} The frame.
 */
export function leftFrame(id) {
  return { op: "left", id };
}

/**
 * The frame that tells the designers a build changed its status.
 *
 * @param {{id: number, seq: number, status: string}} build The build.
 * @returns {object} The frame.
 */
export function buildFrame(build) {
  return { op: "build", build: { id: build.id, seq: build.seq, status: build.status } };
}

/**
 * The frame that tells the designers which build is live.
 *
 * @param {{buildId: number, marshalSha: string, runtimeSha: string, by: string, name: string}} live The live build, its blobs' SHA-256 and who published it.
 * @returns {object} The frame.
 */
export function liveFrame(live) {
  return { op: "live", buildId: live.buildId, marshalSha: live.marshalSha, runtimeSha: live.runtimeSha, by: live.by, name: live.name };
}

/**
 * The frame that tells the designers of a new designer release.
 *
 * @param {string} version The release's version.
 * @returns {object} The frame.
 */
export function releaseFrame(version) {
  return { op: "release", version };
}

/**
 * Reads what a designer says it edits, from a frame of its socket.
 *
 * @param {string} text The frame, `{"op": "editing", "entity", "path"}`.
 * @param {number} maxPathLength The longest path taken.
 * @returns {{entity: string | null, path: string | null} | null} The entity and the path in its body, nulls for nothing and a path only beside an entity; null for any other frame.
 */
export function readEditing(text, maxPathLength = DESIGN_SOCKET.maxPathLength) {
  let frame;

  try {
    frame = JSON.parse(text);
  } catch {
    return null;
  }

  if (!isObject(frame) || frame.op !== "editing") {
    return null;
  }

  const entity = frame.entity ?? null;
  const path = frame.path ?? null;
  const goodEntity = entity === null || (typeof entity === "string" && ENTITY_ID.test(entity));
  const goodPath = path === null || (typeof path === "string" && path.length > 0 && path.length <= maxPathLength && !new RegExp(CONTROL_CHARACTERS.source).test(path));
  return goodEntity && goodPath ? { entity, path: entity === null ? null : path } : null;
}

/**
 * The designers online on the designer socket: their sockets, what each edits, and the frames they
 * are told. A designer may hold several sockets; it is online while one is open.
 */
export class DesignPresence {
  /**
   * Creates the presence, with nobody online.
   *
   * @param {{clock?: () => number, schedule?: (work: () => void, ms: number) => void, limits?: typeof DESIGN_SOCKET}} [options] The clock and the timer, which tests change; the socket's limits.
   */
  constructor({ clock = Date.now, schedule = (work, ms) => setTimeout(work, ms), limits = DESIGN_SOCKET } = {}) {
    this.clock = clock;
    this.schedule = schedule;
    this.limits = limits;
    /** @type {Map<string, {id: string, name: string, admin: boolean, sockets: Set<any>, entity: string | null, path: string | null, at: number, toldAt: number, pending: boolean}>} */
    this.designers = new Map();
    /** @type {Map<any, string>} */
    this.sockets = new Map();
  }

  /**
   * Tells whether a designer is online and what it edits, for the list of designers.
   *
   * @param {string} id The designer's id.
   * @returns {{online: boolean, editing: string | null}} Whether it is, and the entity it edits, null for none.
   */
  of(id) {
    const designer = this.designers.get(id);
    return { online: Boolean(designer), editing: designer?.entity ?? null };
  }

  /**
   * Lists the designers online and what they edit, but one.
   *
   * @param {string} except The designer left out.
   * @returns {{id: string, name: string, entity: string | null, path: string | null}[]} Them, by id.
   */
  list(except) {
    return [...this.designers.values()].filter((designer) => designer.id !== except).sort((left, right) => (left.id < right.id ? -1 : 1))
      .map((designer) => ({ id: designer.id, name: designer.name, entity: designer.entity, path: designer.path }));
  }

  /**
   * Takes a designer's socket in and greets it; the other designers hear of a designer that was not
   * online yet.
   *
   * @param {{id: string, name: string, admin: boolean}} designer The designer.
   * @param {number} seq The newest push's seq.
   * @param {{readyState: number, send: (text: string) => void, close: (code: number, reason: string) => void}} socket Its socket.
   */
  join(designer, seq, socket) {
    const earlier = this.designers.get(designer.id);
    const entry = earlier ?? { id: designer.id, name: designer.name, admin: designer.admin, sockets: new Set(), entity: null, path: null, at: this.clock(), toldAt: 0, pending: false };
    entry.sockets.add(socket);
    this.designers.set(designer.id, entry);
    this.sockets.set(socket, designer.id);
    send(socket, helloFrame(seq, designer, this.list(designer.id)));

    if (!earlier) {
      this.tell(entry);
    }
  }

  /**
   * Notes what a designer says it edits and tells the others, at most once per editingEveryMs;
   * a frame sent sooner is told once that time is up.
   *
   * @param {any} socket The designer's socket.
   * @param {string} text The frame.
   */
  editing(socket, text) {
    const entry = this.designers.get(this.sockets.get(socket));
    const read = entry ? readEditing(text, this.limits.maxPathLength) : null;

    if (!read) {
      return;
    }

    entry.entity = read.entity;
    entry.path = read.path;
    entry.at = this.clock();
    const wait = entry.toldAt + this.limits.editingEveryMs - entry.at;

    if (wait <= 0) {
      this.tell(entry);
      return;
    }

    if (!entry.pending) {
      entry.pending = true;
      this.schedule(() => {
        entry.pending = false;

        // A designer that left in the meantime is told no more.
        if (this.designers.get(entry.id) === entry) {
          this.tell(entry);
        }
      }, wait);
    }
  }

  /**
   * Lets a socket go; once a designer's last socket is gone, the others hear it left.
   *
   * @param {any} socket The socket.
   */
  leave(socket) {
    const id = this.sockets.get(socket);
    const entry = this.designers.get(id);
    this.sockets.delete(socket);

    if (!entry) {
      return;
    }

    entry.sockets.delete(socket);

    if (entry.sockets.size === 0) {
      this.designers.delete(id);
      this.broadcast(leftFrame(id));
    }
  }

  /**
   * Forgets what designers edit once they have not told it again within the TTL, and tells the
   * others they edit nothing.
   */
  expire() {
    const now = this.clock();

    for (const entry of this.designers.values()) {
      if (entry.entity !== null && now - entry.at >= this.limits.presenceTtlMs) {
        entry.entity = null;
        entry.path = null;
        this.tell(entry);
      }
    }
  }

  /**
   * Closes every socket of a designer, such as one no longer listed.
   *
   * @param {string} id The designer's id.
   * @param {{code: number, reason: string}} close The close code and reason.
   */
  disconnect(id, close) {
    for (const socket of [...(this.designers.get(id)?.sockets ?? [])]) {
      socket.close(close.code, close.reason);
    }
  }

  /**
   * Tells every designer online a frame, but those a designer id names.
   *
   * @param {object} frame The frame.
   * @param {string | null} [except] The designer left out, none unless given.
   */
  broadcast(frame, except = null) {
    for (const [socket, id] of this.sockets) {
      if (id !== except) {
        send(socket, frame);
      }
    }
  }

  /**
   * Tells the other designers what a designer edits now.
   *
   * @param {{id: string, name: string, entity: string | null, path: string | null, toldAt: number}} entry The designer.
   */
  tell(entry) {
    entry.toldAt = this.clock();
    this.broadcast(presenceFrame(entry, Math.floor(entry.toldAt / 1000)), entry.id);
  }
}

/**
 * Sends a frame on a socket that is still open.
 *
 * @param {{readyState: number, send: (text: string) => void}} socket The socket.
 * @param {object} frame The frame.
 */
function send(socket, frame) {
  if (socket.readyState === OPEN) {
    socket.send(JSON.stringify(frame));
  }
}

/**
 * @typedef {object} DesignCompilerPort What the design book builds with, see node/design_compiler.js; every file it writes stays its own.
 * @property {() => Promise<{designFormat: number, version: string | null, message: string | null}>} probe Reads the compiler's version and design format and checks the game data, once per compiler binary; `message` names why it cannot compile, null when it can.
 * @property {(buildId: number, snapshot: string) => Promise<void>} prepare Keeps a build's snapshot for its compile.
 * @property {(job: {buildId: number, seq: number, previous: Uint8Array | null}) => Promise<{status: string, report: object | null, fields: {snapshotSha: string | null, runtimeSha: string | null, marshalSha: string | null, format: number | null, runtimeFormat: number | null, compiler: string | null, gameData: string | null}, blobs: {sha256: string, kind: string, size: number, gz: Uint8Array}[]}>} compile Compiles a prepared build against the live runtime JSON, gzipped, none before the first publish; never throws.
 * @property {(buildId: number) => Promise<void>} clean Removes a build's files.
 * @property {() => Promise<void>} reset Removes the files of every build, as the relay starts.
 */

/**
 * The Raid design several designers share, over a store: the entities, their history, the pushes
 * and the designers, the builds and the live build. Writes run one at a time; compiles run one at
 * a time on a queue of their own, so a push never waits for a compile.
 */
export class DesignBook {
  /**
   * Creates the book.
   *
   * @param {DesignStore} store Where the design is kept.
   * @param {{clock?: () => number, minVersion?: string, allowDev?: boolean, relayAdmins?: Set<string>, presence?: DesignPresence, releases?: {answer: (minimum: string) => {status: number, body: object}, file: () => {path: string, name: string, size: number, sha256: string} | null} | null, compiler?: DesignCompilerPort | null, worldNotice?: boolean, limits?: typeof DESIGN_LIMITS, rateLimits?: Partial<typeof DESIGN_RATE_LIMITS>, downloads?: {burst: number, refillMs: number}}} [options] The clock, which tests change; the lowest designer version served, as DESIGNER_MIN_VERSION names it; whether a development build writes as any designer, as DESIGNER_ALLOW_DEV=1 sets it; the relay admins' player ids; who is online and what they edit, a DesignPresence of its own unless given; the newest designer release, see core/designer_releases.js, none unless given; the compiler, none unless given; whether a publish tells the world rooms and ends the pools of removed and renamed bosses, as DESIGN_WORLD_NOTICE=1 sets it; the limits; the rate limits, DESIGN_RATE_LIMITS' for those not given; the rate limit of blob downloads per address.
   */
  constructor(store, {
    clock = Date.now, minVersion, allowDev = false, relayAdmins = new Set(), presence = new DesignPresence({ clock }), releases = null, compiler = null, worldNotice = false,
    limits = DESIGN_LIMITS, rateLimits = DESIGN_RATE_LIMITS, downloads = RATE_LIMITS.downloads,
  } = {}) {
    const version = parseVersion(minVersion);
    this.store = store;
    this.clock = clock;
    this.minVersion = version && !version.development ? minVersion.trim() : DEFAULT_DESIGNER_MIN_VERSION;
    this.allowDev = allowDev;
    this.relayAdmins = relayAdmins;
    this.presence = presence;
    this.releases = releases;
    this.limits = limits;
    this.pushes = new RateLimiter(rateLimits.push ?? DESIGN_RATE_LIMITS.push, clock);
    this.releaseFiles = new RateLimiter(rateLimits.releaseFile ?? DESIGN_RATE_LIMITS.releaseFile, clock);
    this.buildStarts = new RateLimiter(rateLimits.build ?? DESIGN_RATE_LIMITS.build, clock);
    this.publishes = new RateLimiter(rateLimits.publish ?? DESIGN_RATE_LIMITS.publish, clock);
    this.blobDownloads = new RateLimiter(downloads, clock);
    this.compiler = compiler;
    this.worldNotice = worldNotice;
    /** @type {((notice: {text: string, resetKeys: string[]}) => Promise<void>) | null} Tells the world rooms of a new live build, as the relay serving the book sets it; never throws. */
    this.worldTeller = null;
    /** @type {Promise<void>} The world notices queued so far, told one after another in the order their builds went live. */
    this.notices = Promise.resolve();
    this.queue = Promise.resolve();
    this.compiles = Promise.resolve();
  }

  /**
   * Tells the time as the design stores it.
   *
   * @returns {number} Unix seconds.
   */
  now() {
    return Math.floor(this.clock() / 1000);
  }

  /**
   * Reads the newest push's seq and the design formats.
   *
   * @returns {Promise<{seq: number, designFormat: number, minFormat: number}>} The state; both formats FIRST_DESIGN_FORMAT while never set.
   */
  async state() {
    const state = await this.store.state();
    return { seq: state.seq, designFormat: state.designFormat ?? FIRST_DESIGN_FORMAT, minFormat: state.minFormat ?? FIRST_DESIGN_FORMAT };
  }

  /**
   * Reads what the designer gate holds a designer to.
   *
   * @returns {Promise<{minVersion: string, minFormat: number, allowDev: boolean}>} The settings, see designerRefusal.
   */
  async gateSettings() {
    return { minVersion: this.minVersion, minFormat: (await this.state()).minFormat, allowDev: this.allowDev };
  }

  /**
   * Adds the designer admins a setting names that the relay does not list yet. A listed designer
   * keeps its row, so an admin demoted through the designer routes stays demoted after a restart.
   *
   * @param {string[]} ids Their designer ids, as DESIGNER_ADMINS names them.
   * @returns {Promise<void>} Completes once they are listed.
   */
  async seedAdmins(ids) {
    await this.exclusive(async () => {
      for (const id of ids) {
        if (await this.store.designer(id)) {
          continue;
        }

        // A new admin is named by the start of its id until it renames itself.
        await this.store.putDesigner({ id, name: id.slice(0, 8), admin: true, addedBy: SEEDED_BY, at: this.now() });
      }
    });
  }

  /**
   * Finds the designer a key names.
   *
   * @param {string | null | undefined} key The designer key.
   * @returns {Promise<{id: string | null, listed: boolean, admin: boolean, name: string | null}>} The designer: its id, null for a key that is none, whether the relay lists it, whether it is an admin and its name.
   */
  async designerOf(key) {
    if (!isId(key)) {
      return { id: null, listed: false, admin: false, name: null };
    }

    const id = await designerIdOf(key);
    const row = await this.store.designer(id);
    return { id, listed: Boolean(row), admin: row?.admin === 1, name: row?.name ?? null };
  }

  /**
   * Finds the relay admin a player key names.
   *
   * @param {string | null | undefined} key The player key.
   * @returns {Promise<string | null>} The admin's player id, null when the key names no relay admin.
   */
  async relayAdminOf(key) {
    if (!isId(key)) {
      return null;
    }

    const id = await playerIdOf(key);
    return this.relayAdmins.has(id) ? id : null;
  }

  /**
   * Tells a designer who the relay takes it for: `GET me`.
   *
   * @param {{id: string | null, listed: boolean, admin: boolean, name: string | null}} designer The designer.
   * @returns {Promise<{status: number, body: object}>} Its id, name, admin flag and the design's seq, formats and lowest version for a listed designer; its id alone for any other key.
   */
  async me(designer) {
    if (!designer.id) {
      return { status: 403, body: { code: "not_designer" } };
    }

    if (!designer.listed) {
      return { status: 200, body: { id: designer.id, designer: false } };
    }

    await this.store.seen(designer.id, this.now());
    const state = await this.state();
    return {
      status: 200,
      body: { id: designer.id, name: designer.name, designer: true, admin: designer.admin, seq: state.seq, designFormat: state.designFormat, minFormat: state.minFormat, minVersion: this.minVersion },
    };
  }

  /**
   * Renames a designer: `PUT me`.
   *
   * @param {{id: string}} designer The designer.
   * @param {any} body The request, `{name}`.
   * @returns {Promise<{status: number, body: object}>} Its id and new name.
   */
  async rename(designer, body) {
    const name = cleanText(body?.name, this.limits.maxNameLength);

    if (!name) {
      return invalid([{ id: designer.id, message: "The name must hold at least one character." }]);
    }

    return this.exclusive(async () => {
      const earlier = await this.store.designer(designer.id);

      if (!earlier) {
        return { status: 403, body: { code: "not_designer", id: designer.id } };
      }

      await this.store.putDesigner({ id: designer.id, name, admin: earlier.admin === 1, addedBy: earlier.added_by, at: earlier.at });
      return { status: 200, body: { id: designer.id, name } };
    });
  }

  /**
   * Hands out the entities changed since a seq, a page at a time: `GET entities`.
   *
   * @param {URLSearchParams} query `since` (0 for every entity without tombstones), `after` (the id the page starts after) and `limit`.
   * @returns {Promise<{status: number, body: object}>} The seq, the formats, the page's entities sorted by id and the id to pass as `after` for the next page, null on the last.
   */
  async pull(query) {
    const since = wholeParameter(query, "since", 0);
    const limit = wholeParameter(query, "limit", this.limits.maxPage);

    if (since === null || limit === null) {
      return invalid([{ id: null, message: "since and limit must be whole numbers." }]);
    }

    const page = Math.min(Math.max(limit, 1), this.limits.maxPage);
    // Read first, so a push landing during the pull is pulled again rather than skipped.
    const state = await this.state();
    const rows = await this.store.entities({ since, after: query.get("after") ?? "", limit: page + 1, tombstones: since > 0 });
    const entities = rows.slice(0, page).map(wireEntity);
    const next = rows.length > page ? entities.at(-1).id : null;
    return { status: 200, body: { seq: state.seq, designFormat: state.designFormat, minFormat: state.minFormat, entities, next } };
  }

  /**
   * Hands out an entity's revisions, newest first: `GET entities/<id>/history`.
   *
   * @param {string} id The entity id.
   * @param {URLSearchParams} query `limit`, the most revisions.
   * @returns {Promise<{status: number, body: object}>} The id and its revisions, none for an entity never pushed.
   */
  async history(id, query) {
    const limit = wholeParameter(query, "limit", this.limits.historyKept);

    if (!ENTITY_ID.test(id) || limit === null) {
      return invalid([{ id, message: ENTITY_ID.test(id) ? "limit must be a whole number." : "The id does not match the id pattern." }]);
    }

    const revisions = (await this.store.history(id, Math.min(Math.max(limit, 1), this.limits.historyKept)))
      .map((row) => ({ rev: row.rev, schema: row.schema, body: row.body === null ? null : JSON.parse(row.body), deleted: row.deleted === 1, by: row.by, name: row.name, at: row.at }));
    return { status: 200, body: { id, revisions } };
  }

  /**
   * Takes a push: every change or none, each on the revision it was made on: `POST push`.
   *
   * @param {{id: string, name: string, admin: boolean}} designer The pushing designer.
   * @param {{version: string | null | undefined}} client The request's DESIGNER_VERSION_HEADER.
   * @param {any} body The push, `{designFormat, message, confirmDeletes?, changes: [{id, kind, schema, baseRev, body | null}]}`.
   * @returns {Promise<{status: number, body: object, pushed?: {seq: number, by: string, name: string, ids: string[]}}>} The push's seq and every change's new rev, with what to tell the other designers; or why not.
   */
  async push(designer, client, body) {
    const read = this.readPush(body);

    if (read.refusal) {
      return read.refusal;
    }

    const { push } = read;
    const deletes = push.changes.filter((change) => change.body === null).length;

    if (deletes > this.limits.maxDeletes && !(push.confirmDeletes && designer.admin)) {
      return { status: 409, body: { code: "deletes", count: deletes } };
    }

    return this.exclusive(async () => {
      const state = await this.state();

      if (push.designFormat < state.minFormat) {
        return { status: 426, body: { code: "update", minimum: this.minVersion, minFormat: state.minFormat } };
      }

      const stored = new Map();

      for (const change of push.changes) {
        stored.set(change.id, await this.store.entity(change.id));
      }

      const refusal = this.pushRefusal(push.changes, stored, state.seq);

      if (refusal) {
        return refusal;
      }

      // A delete of an entity that does not exist, or no longer, changes nothing.
      const unchanged = (change) => change.body === null && (!stored.get(change.id) || stored.get(change.id).deleted === 1);
      const writes = push.changes.filter((change) => !unchanged(change));
      const seq = writes.length > 0 ? state.seq + 1 : state.seq;
      const accepted = push.changes.map((change) => ({ id: change.id, rev: unchanged(change) ? (stored.get(change.id)?.rev ?? 0) : seq }));

      if (writes.length === 0) {
        return { status: 200, body: { seq, accepted } };
      }

      const version = parseVersion(client.version);
      const released = version !== null && !version.development;
      const format = released && push.designFormat > state.designFormat ? { designFormat: push.designFormat, minFormat: Math.max(state.minFormat, push.designFormat) } : null;

      await this.store.commit({
        seq, by: designer.id, name: designer.name, at: this.now(), message: push.message, designFormat: push.designFormat,
        clientVersion: cleanText(client.version, this.limits.maxVersionLength), keep: this.limits.historyKept, format,
        entities: writes.map((change) => ({ id: change.id, kind: change.kind, schema: change.schema, body: change.body, deleted: change.body === null })),
      });

      return { status: 200, body: { seq, accepted }, pushed: { seq, by: designer.id, name: designer.name, ids: writes.map((change) => change.id) } };
    });
  }

  /**
   * Reads a push and checks everything that needs no stored entity: its shape, the ids, kinds,
   * schemas and base revisions, and the size of every body.
   *
   * @param {any} body The push.
   * @returns {{push: {designFormat: number, message: string, confirmDeletes: boolean, changes: {id: string, kind: string, schema: number, baseRev: number, body: string | null}[]}, refusal?: undefined} | {refusal: {status: number, body: object}}} The push, each body as JSON text; or why not.
   */
  readPush(body) {
    const limits = this.limits;

    if (!isObject(body)) {
      return { refusal: invalid([{ id: null, message: "The push must be a JSON object." }]) };
    }

    const errors = [];

    if (!wholeIn(body.designFormat, 1, limits.maxFormat)) {
      errors.push({ id: null, message: `The design format must be a whole number from 1 to ${limits.maxFormat}.` });
    }

    if (body.message !== undefined && body.message !== null && typeof body.message !== "string") {
      errors.push({ id: null, message: "The message must be a text." });
    }

    if (body.confirmDeletes !== undefined && body.confirmDeletes !== null && typeof body.confirmDeletes !== "boolean") {
      errors.push({ id: null, message: "confirmDeletes must be true or false." });
    }

    if (!Array.isArray(body.changes) || body.changes.length > limits.maxChanges) {
      errors.push({ id: null, message: `The changes must be a list of at most ${limits.maxChanges}.` });
      return { refusal: invalid(errors) };
    }

    const seen = new Set();
    const changes = [];
    let large = false;

    for (const change of body.changes) {
      const id = typeof change?.id === "string" ? change.id : null;
      const error = this.changeError(change, seen);

      if (error) {
        errors.push({ id, message: error });
        continue;
      }

      seen.add(id);
      const text = change.body === null ? null : JSON.stringify(change.body);
      large ||= text !== null && utf8Length(text) > limits.maxEntityBytes;
      changes.push({ id, kind: change.kind, schema: change.schema, baseRev: change.baseRev, body: text });
    }

    if (errors.length > 0) {
      return { refusal: invalid(errors) };
    }

    if (large) {
      return { refusal: tooBig() };
    }

    return { push: { designFormat: body.designFormat, message: cleanText(body.message ?? "", limits.maxMessageLength), confirmDeletes: body.confirmDeletes === true, changes } };
  }

  /**
   * Tells what is wrong with one change of a push, the first thing only.
   *
   * @param {any} change The change.
   * @param {Set<string>} seen The ids of the push's earlier changes.
   * @returns {string | null} What is wrong, null when nothing is.
   */
  changeError(change, seen) {
    if (!isObject(change)) {
      return "A change must be a JSON object.";
    }

    if (typeof change.id !== "string" || !ENTITY_ID.test(change.id)) {
      return "The id does not match the id pattern.";
    }

    if (!DESIGN_KINDS.includes(change.kind) || change.id.split(":")[0] !== change.kind) {
      return "The kind is no known kind or does not match the id.";
    }

    if (!wholeIn(change.schema, 1, this.limits.maxSchema)) {
      return `The schema must be a whole number from 1 to ${this.limits.maxSchema}.`;
    }

    if (!wholeIn(change.baseRev, 0, Number.MAX_SAFE_INTEGER)) {
      return "The base rev must be a whole number from 0.";
    }

    if (change.body !== null && !isObject(change.body)) {
      return "The body must be a JSON object, or null to delete the entity.";
    }

    return seen.has(change.id) ? "The id appears twice in the push." : null;
  }

  /**
   * Tells why a push may not land on the stored entities: a lower schema than stored, an entity
   * changed since its base revision, or one that never existed named on a base. Called inside
   * exclusive.
   *
   * @param {{id: string, schema: number, baseRev: number, body: string | null}[]} changes The push's changes.
   * @param {Map<string, object | undefined>} stored Each change's stored row, undefined for none.
   * @param {number} seq The newest push's seq.
   * @returns {{status: number, body: object} | null} The refusal, null when the push may land.
   */
  pushRefusal(changes, stored, seq) {
    for (const change of changes) {
      const row = stored.get(change.id);

      if (row && change.schema < row.schema) {
        return { status: 409, body: { code: "schema", id: change.id, stored: row.schema } };
      }
    }

    const missing = changes.filter((change) => !stored.get(change.id) && change.body !== null && change.baseRev !== 0);

    if (missing.length > 0) {
      return invalid(missing.map((change) => ({ id: change.id, message: "The entity does not exist; create it on base rev 0." })));
    }

    const conflicts = changes.filter((change) => stored.get(change.id) && stored.get(change.id).rev !== change.baseRev).map((change) => wireEntity(stored.get(change.id)));
    return conflicts.length > 0 ? { status: 409, body: { code: "conflict", message: CONFLICT_MESSAGE, seq, conflicts } } : null;
  }

  /**
   * Lists the designers with whether they are online and what they edit: `GET designers`.
   *
   * @returns {Promise<{status: number, body: object}>} The designers.
   */
  async roster() {
    const designers = (await this.store.designers()).map((row) => ({ id: row.id, name: row.name, admin: row.admin === 1, ...this.presence.of(row.id) }));
    return { status: 200, body: { designers } };
  }

  /**
   * Adds a designer, or renames one or changes whether it is an admin: `PUT designers/<id>`.
   *
   * @param {string} by Who asks, a designer admin's designer id or a relay admin's player id.
   * @param {string} id The designer id.
   * @param {any} body The request, `{name, admin}`; a new designer needs a name.
   * @returns {Promise<{status: number, body: object}>} The designer's id, name and admin flag.
   */
  async putDesigner(by, id, body) {
    const name = body?.name === undefined || body?.name === null ? null : cleanText(body.name, this.limits.maxNameLength);
    const admin = body?.admin ?? null;

    if (!isId(id) || !isObject(body) || name === "" || (admin !== null && typeof admin !== "boolean")) {
      return invalid([{ id, message: "The id must be 32 lowercase hexadecimal characters, the name a text and admin true or false." }]);
    }

    return this.exclusive(async () => {
      const earlier = await this.store.designer(id);

      if (!earlier && name === null) {
        return invalid([{ id, message: "A new designer needs a name." }]);
      }

      const designer = { id, name: name ?? earlier.name, admin: admin ?? earlier?.admin === 1 };
      await this.store.putDesigner({ ...designer, addedBy: by, at: this.now() });
      return { status: 200, body: designer };
    });
  }

  /**
   * Removes a designer: `DELETE designers/<id>`.
   *
   * @param {string} id The designer id.
   * @returns {Promise<{status: number, body: object, removed?: string}>} An empty answer, also for a designer the relay did not list, with the id whose sockets to close.
   */
  async removeDesigner(id) {
    if (!isId(id)) {
      return invalid([{ id, message: "The id must be 32 lowercase hexadecimal characters." }]);
    }

    return this.exclusive(async () => {
      await this.store.removeDesigner(id);
      return { status: 200, body: {}, removed: id };
    });
  }

  /**
   * Names the newest designer release: `GET release`.
   *
   * @returns {{status: number, body: object}} The release with the lowest designer version served, or `404 none` while the relay holds none.
   */
  release() {
    return this.releases ? this.releases.answer(this.minVersion) : { status: 404, body: { code: "none" } };
  }

  /**
   * Hands out the newest designer release's exe, a few times an hour per designer: `GET release/file`.
   *
   * @param {{id: string}} designer The designer.
   * @returns {{status: number, body: object, file?: {path: string, name: string, size: number, sha256: string}}} The file to send; or `429 rate`, or `404 none` while the relay holds no release.
   */
  releaseFile(designer) {
    const file = this.releases?.file() ?? null;

    if (!file) {
      return { status: 404, body: { code: "none" } };
    }

    return this.releaseFiles.take(designer.id) ? { status: 200, body: {}, file } : { status: 429, body: { code: "rate" } };
  }

  /**
   * Starts a build of the design as it stands: `POST builds`. Under the exclusive queue it checks
   * the seq and keeps the snapshot; the compile then waits on the compile queue, outside the lock.
   *
   * @param {{id: string, name: string}} designer The designer admin.
   * @param {any} body The request, `{seq}`, the current seq.
   * @returns {Promise<{status: number, body: object}>} `202 {build}` once queued; `409 moved` on an old seq, `429 rate` past the designer's build limit, which a request that is not as it should be never counts against, `503 compiler` while the compiler cannot build.
   */
  async startBuild(designer, body) {
    if (!isObject(body) || !wholeIn(body.seq, 0, Number.MAX_SAFE_INTEGER)) {
      return invalid([{ id: null, message: "seq must be a whole number." }]);
    }

    if (!this.buildStarts.take(designer.id)) {
      return { status: 429, body: { code: "rate" } };
    }

    const moved = (state) => (body.seq === state.seq ? null : { status: 409, body: { code: "moved", seq: state.seq } });
    const state = await this.state();
    // Probed outside the lock, since it may run the compiler.
    const refusal = moved(state) ?? (await this.compilerCheck(state.minFormat));

    if (refusal) {
      return refusal;
    }

    const queued = await this.exclusive(async () => {
      const current = await this.state();
      const late = moved(current);

      if (late) {
        return { refusal: late };
      }

      const id = await this.store.addBuild({ seq: current.seq, by: designer.id, at: this.now() });

      try {
        await this.compiler.prepare(id, await this.snapshotText(current.designFormat));
      } catch (error) {
        const report = JSON.stringify(failureReport(`The relay could not keep the snapshot: ${error.message}`));
        await this.store.finishBuild(id, { ...EMPTY_FIELDS, status: BUILD_STATUS.failed, report }, []);
        return { refusal: compilerRefusal("The relay could not keep the snapshot.") };
      }

      return { build: { id, seq: current.seq, status: BUILD_STATUS.queued } };
    });

    if (queued.refusal) {
      return queued.refusal;
    }

    this.presence.broadcast(buildFrame(queued.build));
    this.enqueueCompile(queued.build.id, queued.build.seq);
    return { status: 202, body: { build: queued.build } };
  }

  /**
   * Tells why the compiler cannot build now, after probing it.
   *
   * @param {number} minFormat The lowest design format the relay takes.
   * @returns {Promise<{status: number, body: object} | null>} `503 compiler`, or null when it can build.
   */
  async compilerCheck(minFormat) {
    if (!this.compiler) {
      return compilerRefusal("This relay has no compiler.");
    }

    const probe = await this.compiler.probe();

    if (probe.message) {
      return compilerRefusal(probe.message);
    }

    return probe.designFormat < minFormat ? compilerRefusal(`The compiler knows design format ${probe.designFormat}, below the minimum ${minFormat}.`) : null;
  }

  /**
   * Writes the snapshot of the design as it stands: every entity but the tombstones, sorted by id.
   * Called inside exclusive.
   *
   * @param {number} designFormat The design format.
   * @returns {Promise<string>} The snapshot, canonical JSON.
   */
  async snapshotText(designFormat) {
    const entities = [];
    let after = "";

    for (;;) {
      const rows = await this.store.entities({ since: 0, after, limit: this.limits.maxPage, tombstones: false });
      entities.push(...rows.map((row) => ({ body: JSON.parse(row.body), id: row.id, kind: row.kind, schema: row.schema })));

      if (rows.length < this.limits.maxPage) {
        break;
      }

      after = rows.at(-1).id;
    }

    return canonicalJson({ designFormat, entities, format: SNAPSHOT_FORMAT });
  }

  /**
   * Puts a build on the compile queue, which runs one compile at a time.
   *
   * @param {number} id The build.
   * @param {number} seq Its seq.
   * @returns {Promise<void>} Completes once the build finished.
   */
  enqueueCompile(id, seq) {
    const run = this.compiles.then(() => this.compile(id, seq));
    this.compiles = run.catch(() => {});
    return run;
  }

  /**
   * Waits until every build queued so far finished.
   *
   * @returns {Promise<void>} Completes once the compile queue is empty.
   */
  idle() {
    return this.compiles;
  }

  /**
   * Compiles a queued build against the live build's runtime JSON, keeps its result and tells the
   * designers each status.
   *
   * @param {number} id The build.
   * @param {number} seq Its seq.
   * @returns {Promise<void>} Completes once kept.
   */
  async compile(id, seq) {
    let result;
    let baseBuildId = null;

    try {
      await this.store.setBuildStatus(id, BUILD_STATUS.compiling);
      this.presence.broadcast(buildFrame({ id, seq, status: BUILD_STATUS.compiling }));
      // The compiler may have been replaced since the build was queued.
      const refusal = await this.compilerCheck((await this.state()).minFormat);

      if (refusal) {
        result = { status: BUILD_STATUS.failed, report: failureReport(refusal.body.message), fields: EMPTY_FIELDS, blobs: [] };
      } else {
        const { build } = await this.liveRows();
        baseBuildId = build?.id ?? null;
        const previous = build?.runtime_sha ? ((await this.store.blob(build.runtime_sha)) ?? null) : null;
        result = await this.compiler.compile({ buildId: id, seq, previous });
      }
    } catch (error) {
      result = { status: BUILD_STATUS.failed, report: failureReport(error.message), fields: EMPTY_FIELDS, blobs: [] };
    }

    const kept = await this.keepBuild(id, result, baseBuildId).then(() => result, async (error) => {
      const failed = { status: BUILD_STATUS.failed, report: failureReport(`The relay could not keep the build: ${error.message}`), fields: EMPTY_FIELDS, blobs: [] };
      await this.keepBuild(id, failed, baseBuildId).catch(() => {});
      return failed;
    });
    await this.compiler?.clean(id).catch(() => {});
    this.presence.broadcast(buildFrame({ id, seq, status: kept.status }));
  }

  /**
   * Keeps a compiled build's result and blobs under the exclusive queue.
   *
   * @param {number} id The build.
   * @param {{status: string, report: object | null, fields: object, blobs: {sha256: string, kind: string, size: number, gz: Uint8Array}[]}} result The compile's result.
   * @param {number | null} baseBuildId The live build it was compiled against, null for none.
   * @returns {Promise<void>} Completes once kept; rejects when the store failed, which keeps nothing.
   */
  keepBuild(id, result, baseBuildId) {
    const at = this.now();
    const fields = { ...EMPTY_FIELDS, ...result.fields, baseBuildId, status: result.status, report: result.report === null ? null : JSON.stringify(result.report) };
    return this.exclusive(() => this.store.finishBuild(id, fields, result.blobs.map((blob) => ({ ...blob, at }))));
  }

  /**
   * Fails the builds a restart cut off and removes their files, as the relay starts.
   *
   * @returns {Promise<number[]>} The failed builds' ids.
   */
  async recoverBuilds() {
    const failed = await this.exclusive(() => this.store.failUnfinished(JSON.stringify(failureReport("The relay restarted during the build."))));
    await this.compiler?.reset();
    return failed;
  }

  /**
   * Drops the builds past the newest DESIGN_LIMITS.buildsKept, but the live, the previous and
   * unfinished ones, and every blob no build names.
   *
   * @returns {Promise<{builds: number, blobs: number}>} How many of each were dropped.
   */
  tidyBuilds() {
    return this.exclusive(() => this.store.tidyBuilds(this.limits.buildsKept));
  }

  /**
   * Reads the live build and the one before it.
   *
   * @returns {Promise<{live: object | undefined, build: object | undefined, previous: object | undefined}>} The live row and both builds' rows, undefined for none.
   */
  async liveRows() {
    const live = await this.store.live();
    return { live, build: live ? await this.store.build(live.build_id) : undefined, previous: live?.previous_build_id ? await this.store.build(live.previous_build_id) : undefined };
  }

  /**
   * Lists the builds, or one: `GET builds` and `GET builds/<id>`.
   *
   * @param {string | undefined} raw The build id as the address names it, undefined for every build.
   * @returns {Promise<{status: number, body: object}>} `{live, previous, builds}`: the live and the previous build's ids, null for none, and the builds newest first, the one asked for alone; `404 none` for a build the relay does not hold.
   */
  async buildList(raw) {
    const live = await this.store.live();
    const ids = { live: live?.build_id ?? null, previous: live?.previous_build_id ?? null };

    if (raw === undefined) {
      const rows = await this.store.builds(this.limits.buildsKept);

      for (const id of [ids.live, ids.previous]) {
        if (id !== null && !rows.some((row) => row.id === id)) {
          rows.push(await this.store.build(id));
        }
      }

      return { status: 200, body: { ...ids, builds: rows.filter(Boolean).sort((left, right) => right.id - left.id).map(wireBuild) } };
    }

    const row = await this.buildOf(raw);
    return row ? { status: 200, body: { ...ids, builds: [wireBuild(row)] } } : none();
  }

  /**
   * Finds the build an address names.
   *
   * @param {string} raw The build id as the address names it.
   * @returns {Promise<object | undefined>} Its row, undefined for none.
   */
  async buildOf(raw) {
    return /^\d{1,15}$/.test(raw) ? this.store.build(Number(raw)) : undefined;
  }

  /**
   * Hands out a build's snapshot, gzipped: `GET builds/<id>/snapshot`.
   *
   * @param {string} raw The build id as the address names it.
   * @returns {Promise<{status: number, body: object, bytes?: Uint8Array, headers?: Record<string, string>}>} The bytes; `404 none` for a build without one.
   */
  async buildSnapshot(raw) {
    const row = await this.buildOf(raw);
    const bytes = row?.snapshot_sha ? await this.store.blob(row.snapshot_sha) : undefined;
    return bytes ? { status: 200, body: {}, bytes, headers: { "Content-Type": "application/gzip", ETag: `"${row.snapshot_sha}"` } } : none();
  }

  /**
   * Makes a compiled build live, the live one before it the previous: `POST publish`.
   *
   * @param {{id: string, name: string}} designer The designer admin.
   * @param {any} body The request, `{buildId}` of a build whose status is ok.
   * @returns {Promise<{status: number, body: object, notice?: {text: string, resetKeys: string[]}}>} `{live, catalogDiff}`, with what to tell the world rooms while DESIGN_WORLD_NOTICE is on; `404 none` for a build the relay does not hold, `409 status` for one not ok, `409 stale` for one compiled against another live build than the one live now, which a new build replaces; `429 rate` past the designer's publish limit, which a request that is not as it should be never counts against.
   */
  async publish(designer, body) {
    if (!isObject(body) || !wholeIn(body.buildId, 1, Number.MAX_SAFE_INTEGER)) {
      return invalid([{ id: null, message: "buildId must be a whole number from 1." }]);
    }

    if (!this.publishes.take(designer.id)) {
      return { status: 429, body: { code: "rate" } };
    }

    return this.exclusive(async () => {
      const build = await this.store.build(body.buildId);

      if (!build) {
        return none();
      }

      if (build.status !== BUILD_STATUS.ok) {
        return { status: 409, body: { code: "status", status: build.status } };
      }

      const earlier = await this.store.live();

      if (isStale(build, earlier)) {
        return { status: 409, body: { code: "stale" } };
      }

      // Publishing the live build again keeps the build before it.
      const previousBuildId = earlier?.build_id === build.id ? earlier.previous_build_id : (earlier?.build_id ?? null);
      const live = { buildId: build.id, previousBuildId, by: designer.id, at: this.now() };
      await this.store.setLive(live);
      const catalogDiff = catalogDiffOf(build.report === null ? null : JSON.parse(build.report));
      this.presence.broadcast(liveFrame({ buildId: build.id, marshalSha: build.marshal_sha, runtimeSha: build.runtime_sha, by: designer.id, name: designer.name }));
      const resetKeys = [...new Set([...catalogDiff.removed, ...catalogDiff.renamed.map((renamed) => renamed.from)])];
      return { status: 200, body: { live, catalogDiff }, ...this.tellWorlds(build, resetKeys) };
    });
  }

  /**
   * Makes the previous build live again, the live one the previous: `POST rollback`.
   *
   * @param {{id: string, name: string}} designer The designer admin.
   * @returns {Promise<{status: number, body: object, notice?: {text: string, resetKeys: string[]}}>} `{live}`, with what to tell the world rooms while DESIGN_WORLD_NOTICE is on; `404 none` without a previous build.
   */
  rollback(designer) {
    return this.exclusive(async () => {
      const { live: earlier, previous } = await this.liveRows();

      if (!previous) {
        return none();
      }

      const live = { buildId: previous.id, previousBuildId: earlier.build_id, by: designer.id, at: this.now() };
      await this.store.setLive(live);
      this.presence.broadcast(liveFrame({ buildId: previous.id, marshalSha: previous.marshal_sha, runtimeSha: previous.runtime_sha, by: designer.id, name: designer.name }));
      return { status: 200, body: { live }, ...this.tellWorlds(previous, []) };
    });
  }

  /**
   * Queues what a new live build tells the world rooms behind the notices before it, only while
   * DESIGN_WORLD_NOTICE is on, since released games read no compiled format 3 yet. Called inside
   * exclusive, so the world rooms hear the builds in the order they went live.
   *
   * @param {{marshal_sha: string, runtime_sha: string}} build The build now live.
   * @param {string[]} resetKeys The boss keys whose pools end.
   * @returns {{notice?: {text: string, resetKeys: string[]}}} The notice, none while off.
   */
  tellWorlds(build, resetKeys) {
    if (!this.worldNotice) {
      return {};
    }

    const notice = { text: worldDesignText(build.marshal_sha, build.runtime_sha), resetKeys };
    this.notices = this.notices.then(() => this.worldTeller?.(notice)).catch(() => {});
    return { notice };
  }

  /**
   * Raises the lowest design format the relay takes: `POST format`.
   *
   * @param {any} body The request, `{minFormat}`, from the current lowest up to the design format.
   * @returns {Promise<{status: number, body: object}>} `{designFormat, minFormat}`.
   */
  setMinFormat(body) {
    return this.exclusive(async () => {
      const state = await this.state();

      if (!isObject(body) || !wholeIn(body.minFormat, state.minFormat, state.designFormat)) {
        return invalid([{ id: null, message: `minFormat must be a whole number from ${state.minFormat} to ${state.designFormat}.` }]);
      }

      await this.store.setFormat({ designFormat: state.designFormat, minFormat: body.minFormat });
      return { status: 200, body: { designFormat: state.designFormat, minFormat: body.minFormat } };
    });
  }

  /**
   * Names the live build a game reads: `GET /v1/raid-design`.
   *
   * @param {string | null | undefined} reader The request's DESIGN_READER_HEADER, the highest compiled format the game reads.
   * @returns {Promise<{status: number, body: object}>} `{buildId, format, seq, marshal, runtime, at}` of the live build, else of the previous one, whose format the game reads; `404 none` when neither is.
   */
  async gameDesign(reader) {
    const format = typeof reader === "string" && /^\s*\d{1,6}\s*$/.test(reader) ? Number(reader.trim()) : 0;
    const { build, previous } = await this.liveRows();

    for (const row of [build, previous]) {
      if (row?.status !== BUILD_STATUS.ok || row.format === null || row.format > format) {
        continue;
      }

      const marshal = await this.store.blobInfo(row.marshal_sha);
      const runtime = await this.store.blobInfo(row.runtime_sha);

      if (marshal && runtime) {
        const body = { buildId: row.id, format: row.format, seq: row.seq, marshal: { sha256: marshal.sha256, size: marshal.size }, runtime: { sha256: runtime.sha256, size: runtime.size }, at: row.at };
        return { status: 200, body };
      }
    }

    return none();
  }

  /**
   * Hands out a compiled blob, gzipped, by its SHA-256: `GET /v1/raid-design/<sha256>`. The bytes
   * never change, so games and the battle server keep them for good.
   *
   * @param {string} sha256 The blob's SHA-256.
   * @param {{address: string | null, local: boolean, etag: string | null}} client The request's address; whether it came from this machine, which the download limit leaves out; its If-None-Match header.
   * @returns {Promise<{status: number, body: object, bytes?: Uint8Array, headers?: Record<string, string>}>} The bytes, or 304 for the copy the game holds; `404 none` for a blob that is no compiled design the relay holds, `429 rate` past the download limit.
   */
  async gameBlob(sha256, client) {
    const info = SHA256.test(sha256) ? await this.store.blobInfo(sha256) : undefined;

    if (!info || (info.kind !== "marshal" && info.kind !== "runtime")) {
      return none();
    }

    const headers = { "Cache-Control": "public, max-age=31536000, immutable", ETag: `"${sha256}"` };
    const held = client.etag?.split(",").map((tag) => tag.trim()).some((tag) => tag === `"${sha256}"` || tag === `W/"${sha256}"` || tag === "*");

    if (held) {
      return { status: 304, body: {}, headers };
    }

    if (!client.local && !this.blobDownloads.take(client.address)) {
      return { status: 429, body: { code: "rate" } };
    }

    const bytes = await this.store.blob(sha256);
    return bytes ? { status: 200, body: {}, bytes, headers: { ...headers, "Content-Type": "application/gzip" } } : none();
  }

  /**
   * Runs one read and write of the design at a time, so a second push reads the first.
   *
   * @template T
   * @param {() => Promise<T>} work The work.
   * @returns {Promise<T>} Its result.
   */
  exclusive(work) {
    const result = this.queue.then(work);
    this.queue = result.catch(() => {});
    return result;
  }
}

/**
 * Reads a design route's JSON body.
 *
 * @param {(limit: number) => Promise<string | null>} readBody Reads the request's body as text up to a limit in bytes, null when it is longer.
 * @param {number} limit The most bytes the route takes.
 * @returns {Promise<{body: any} | {refusal: {status: number, body: object}}>} The parsed body, or the refusal of a body too long or no JSON.
 */
async function readDesignJson(readBody, limit) {
  const text = await readBody(limit);

  if (text === null) {
    return { refusal: tooBig() };
  }

  try {
    return { body: JSON.parse(text) };
  } catch {
    return { refusal: invalid([{ id: null, message: "The body is no JSON." }]) };
  }
}

/**
 * Answers a request to the design routes, after the designer gate: `GET/PUT me`, `GET entities`,
 * `GET entities/<id>/history`, `POST push`, `GET designers`, `PUT/DELETE designers/<id>`,
 * `GET release`, `GET release/file`, `POST builds`, `GET builds`, `GET builds/<id>`,
 * `GET builds/<id>/snapshot`, `POST publish`, `POST rollback` and `POST format`. A relay admin's
 * player key passes on the designer list's routes only.
 *
 * @param {DesignBook} book The design.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @param {{designer: string | null, player: string | null, version: string | null, format: string | null}} client The request's DESIGNER_HEADER, PLAYER_HEADER, DESIGNER_VERSION_HEADER and DESIGN_FORMAT_HEADER.
 * @param {(limit: number) => Promise<string | null>} readBody Reads the request's body as text up to a limit in bytes, null when it is longer.
 * @param {(limit: number) => Promise<void>} drain Reads the request's body to its end and drops it, for a refusal answered before the body was read.
 * @returns {Promise<{status: number, body: object, pushed?: {seq: number, by: string, name: string, ids: string[]}, removed?: string, file?: {path: string, name: string, size: number, sha256: string}, bytes?: Uint8Array, headers?: Record<string, string>, notice?: {text: string, resetKeys: string[]}}>} The answer, with what a push changed, the designer removed, the release file or the bytes with their headers to send in place of the body, or what a new live build was queued to tell the world rooms.
 */
export async function handleDesignRequest(book, method, url, client, readBody, drain) {
  const rest = designRouteOf(url)?.rest ?? [];
  const rule = designerRuleOf(method, rest);
  const relayAdmin = rule.relayAdmin ? await book.relayAdminOf(client.player) : null;
  const designer = relayAdmin ? null : await book.designerOf(client.designer);
  const refusal = relayAdmin ? null : designerRefusal(rule, designer, client, await book.gateSettings());
  const limit = rest[0] === "push" ? book.limits.maxPushBytes : book.limits.maxBodyBytes;

  if (refusal) {
    await drain(limit);
    return refusal;
  }

  const [route, id, part] = rest;
  const bare = rest.length === 1;
  const withBody = async (handle) => {
    const read = await readDesignJson(readBody, limit);
    return read.refusal ?? handle(read.body);
  };

  if (route === "me" && bare && method === "GET") {
    return book.me(designer);
  }

  if (route === "me" && bare && method === "PUT") {
    return withBody((body) => book.rename(designer, body));
  }

  if (route === "entities" && bare && method === "GET") {
    return book.pull(url.searchParams);
  }

  if (route === "entities" && rest.length === 3 && part === "history" && method === "GET") {
    return book.history(id, url.searchParams);
  }

  if (route === "push" && bare && method === "POST") {
    if (!book.pushes.take(designer.id)) {
      await drain(limit);
      return { status: 429, body: { code: "rate" } };
    }

    return withBody((body) => book.push(designer, client, body));
  }

  if (route === "designers" && bare && method === "GET") {
    return book.roster();
  }

  if (route === "designers" && rest.length === 2 && method === "PUT") {
    return withBody((body) => book.putDesigner(relayAdmin ?? designer.id, id, body));
  }

  if (route === "designers" && rest.length === 2 && method === "DELETE") {
    await drain(limit);
    return book.removeDesigner(id);
  }

  if (route === "release" && method === "GET" && (bare || (rest.length === 2 && id === "file"))) {
    await drain(limit);
    return bare ? book.release() : book.releaseFile(designer);
  }

  if (route === "builds" && bare && method === "POST") {
    return withBody((body) => book.startBuild(designer, body));
  }

  if (route === "builds" && method === "GET" && (rest.length <= 2 || (rest.length === 3 && part === "snapshot"))) {
    await drain(limit);
    return rest.length === 3 ? book.buildSnapshot(id) : book.buildList(id);
  }

  if (route === "publish" && bare && method === "POST") {
    return withBody((body) => book.publish(designer, body));
  }

  if (route === "rollback" && bare && method === "POST") {
    await drain(limit);
    return book.publishes.take(designer.id) ? book.rollback(designer) : { status: 429, body: { code: "rate" } };
  }

  if (route === "format" && bare && method === "POST") {
    return withBody((body) => book.setMinFormat(body));
  }

  await drain(limit);
  return notFound("route");
}

/**
 * Reads which game design route an address names.
 *
 * @param {URL} url The request's address.
 * @returns {{sha256: string | null} | null} The blob's SHA-256 the address names, null for the live build's route, an empty text for a deeper path; or null when it is no game design route.
 */
export function gameDesignRouteOf(url) {
  if (!routeIs(url, GAME_DESIGN_ROUTE)) {
    return null;
  }

  const rest = url.pathname.split("/").filter((part) => part.length > 0).slice(2);
  return { sha256: rest.length === 0 ? null : rest.length === 1 ? rest[0] : "" };
}

/**
 * Answers a request to the routes games and the battle server read the live build from, after the
 * game gate: `GET /v1/raid-design` and `GET /v1/raid-design/<sha256>`.
 *
 * @param {DesignBook} book The design.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @param {{reader: string | null, address: string | null, local: boolean, etag: string | null}} client The request's DESIGN_READER_HEADER, its address, whether it came from this machine, and its If-None-Match header.
 * @param {(limit: number) => Promise<void>} drain Reads the request's body to its end and drops it.
 * @returns {Promise<{status: number, body: object, bytes?: Uint8Array, headers?: Record<string, string>}>} The answer, with the bytes and their headers to send in place of the body.
 */
export async function handleGameDesignRequest(book, method, url, client, drain) {
  const route = gameDesignRouteOf(url);
  await drain(book.limits.maxBodyBytes);

  if (method !== "GET" || !route || route.sha256 === "") {
    return notFound("route");
  }

  return route.sha256 === null ? book.gameDesign(client.reader) : book.gameBlob(route.sha256, client);
}

/**
 * Admits a designer to the designer socket, `GET socket` with an upgrade, under the same gate as
 * the read routes.
 *
 * @param {DesignBook} book The design.
 * @param {string[]} rest The address's parts after `designs`.
 * @param {{designer: string | null, version: string | null, format: string | null}} client The request's DESIGNER_HEADER, DESIGNER_VERSION_HEADER and DESIGN_FORMAT_HEADER.
 * @returns {Promise<{designer: {id: string, name: string, admin: boolean}, seq: number} | {close: {code: number, reason: string}} | {status: number, reason: string}>} The designer and the newest push's seq to greet it with; the close code to open and close the socket with; or the status to refuse the upgrade with for any other path.
 */
export async function admitDesigner(book, rest, client) {
  if (rest.length !== 1 || rest[0] !== DESIGN_SOCKET.route) {
    return { status: 404, reason: "there is no such route" };
  }

  const designer = await book.designerOf(client.designer);
  const refusal = designerRefusal(designerRuleOf("GET", rest), designer, client, await book.gateSettings());

  if (refusal) {
    return { close: refusal.status === 403 ? DESIGN_CLOSE.notDesigner : DESIGN_CLOSE.update };
  }

  await book.store.seen(designer.id, book.now());
  return { designer: { id: designer.id, name: designer.name, admin: designer.admin }, seq: (await book.state()).seq };
}
