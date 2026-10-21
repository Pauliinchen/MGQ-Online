//----------------------------------------------------------------
//  designs.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

// The Raid designs several designers edit together, on the Node relay only: entities with their
// revisions and history, all-or-nothing pushes on a base revision, pulls since a revision, and the
// designers the relay serves. The relay never reads an entity's body; the contract is
// MGQ-Online-Raid-Designer/docs/SERVER_FORMAT.md, its fixtures are in fixtures/designs.

import { playerIdOf, sha256Hex } from "./directory.js";
import { DEFAULT_DESIGNER_MIN_VERSION, DESIGN_ROUTE, designerRefusal, designerRuleOf, parseVersion } from "./gate.js";
import { notFound, routeIs } from "./http.js";
import { cleanText, isId } from "./ids.js";
import { RateLimiter } from "./relay.js";

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
});

/**
 * The rate limits of the design routes, per designer.
 */
export const DESIGN_RATE_LIMITS = Object.freeze({
  push: Object.freeze({ burst: 30, refillMs: 2 * 1000 }),
});

/**
 * Who added the designer admins the DESIGNER_ADMINS setting names.
 */
export const SEEDED_BY = "DESIGNER_ADMINS";

/**
 * What a conflict tells the designer.
 */
const CONFLICT_MESSAGE = "Someone changed these since your base.";

/**
 * The presence of designers without the designer socket: nobody is online.
 */
const NO_PRESENCE = Object.freeze({ of: () => ({ online: false, editing: null }) });

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
 * Turns a stored entity row into the entity the wire carries.
 *
 * @param {{id: string, kind: string, schema: number, rev: number, deleted: number, body: string | null, by: string, name: string, at: number}} row The row.
 * @returns {object} The wire entity.
 */
function wireEntity(row) {
  return { id: row.id, kind: row.kind, schema: row.schema, rev: row.rev, deleted: row.deleted === 1, body: row.body === null ? null : JSON.parse(row.body), by: row.by, name: row.name, at: row.at };
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
 * The Raid design several designers share, over a store: the entities, their history, the pushes
 * and the designers. Writes run one at a time.
 */
export class DesignBook {
  /**
   * Creates the book.
   *
   * @param {DesignStore} store Where the design is kept.
   * @param {{clock?: () => number, minVersion?: string, allowDev?: boolean, relayAdmins?: Set<string>, presence?: {of: (id: string) => {online: boolean, editing: string | null}}, limits?: typeof DESIGN_LIMITS, rateLimits?: typeof DESIGN_RATE_LIMITS}} [options] The clock, which tests change; the lowest designer version served, as DESIGNER_MIN_VERSION names it; whether a development build writes as any designer, as DESIGNER_ALLOW_DEV=1 sets it; the relay admins' player ids; who is online and what they edit; the limits; the rate limits.
   */
  constructor(store, { clock = Date.now, minVersion, allowDev = false, relayAdmins = new Set(), presence = NO_PRESENCE, limits = DESIGN_LIMITS, rateLimits = DESIGN_RATE_LIMITS } = {}) {
    const version = parseVersion(minVersion);
    this.store = store;
    this.clock = clock;
    this.minVersion = version && !version.development ? minVersion.trim() : DEFAULT_DESIGNER_MIN_VERSION;
    this.allowDev = allowDev;
    this.relayAdmins = relayAdmins;
    this.presence = presence;
    this.limits = limits;
    this.pushes = new RateLimiter(rateLimits.push, clock);
    this.queue = Promise.resolve();
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
   * Makes the designer admins a setting names admins, adding the ones the relay does not list yet.
   *
   * @param {string[]} ids Their designer ids, as DESIGNER_ADMINS names them.
   * @returns {Promise<void>} Completes once they are admins.
   */
  async seedAdmins(ids) {
    await this.exclusive(async () => {
      for (const id of ids) {
        const earlier = await this.store.designer(id);
        // A new admin is named by the start of its id until it renames itself.
        await this.store.putDesigner({ id, name: earlier?.name ?? id.slice(0, 8), admin: true, addedBy: SEEDED_BY, at: this.now() });
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
   * @returns {Promise<{status: number, body: object}>} An empty answer, also for a designer the relay did not list.
   */
  async removeDesigner(id) {
    if (!isId(id)) {
      return invalid([{ id, message: "The id must be 32 lowercase hexadecimal characters." }]);
    }

    return this.exclusive(async () => {
      await this.store.removeDesigner(id);
      return { status: 200, body: {} };
    });
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
 * `GET entities/<id>/history`, `POST push`, `GET designers` and `PUT/DELETE designers/<id>`.
 * A relay admin's player key passes on the designer list's routes only.
 *
 * @param {DesignBook} book The design.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @param {{designer: string | null, player: string | null, version: string | null, format: string | null}} client The request's DESIGNER_HEADER, PLAYER_HEADER, DESIGNER_VERSION_HEADER and DESIGN_FORMAT_HEADER.
 * @param {(limit: number) => Promise<string | null>} readBody Reads the request's body as text up to a limit in bytes, null when it is longer.
 * @param {(limit: number) => Promise<void>} drain Reads the request's body to its end and drops it, for a refusal answered before the body was read.
 * @returns {Promise<{status: number, body: object, pushed?: {seq: number, by: string, name: string, ids: string[]}}>} The answer, with what a push changed.
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

  await drain(limit);
  return notFound("route");
}
