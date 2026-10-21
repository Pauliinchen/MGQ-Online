//----------------------------------------------------------------
//  test_designs.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

// What the design tests share: the contract's fixtures, canonical JSON to compare answers by, and
// the state each fixture's exchanges start from, so every design store replays them alike.

import { readFileSync, readdirSync } from "node:fs";
import { playerIdOf } from "./directory.js";
import { DESIGN_FORMAT_HEADER, DESIGNER_HEADER, DESIGNER_VERSION_HEADER } from "./gate.js";
import { DesignBook, handleDesignRequest } from "./designs.js";
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

/**
 * Writes a value as canonical JSON, as the contract compares values: object keys in ordinal order,
 * nulls in objects left out, integral numbers as integers and others without an exponent.
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
 * @param {{presence?: {of: (id: string) => {online: boolean, editing: string | null}}}} [options] Who is online.
 * @returns {Promise<DesignBook>} The book.
 */
export async function fixtureBook(store, { presence } = {}) {
  const book = new DesignBook(store, { clock: () => NOW * 1000, minVersion: MIN_VERSION, relayAdmins: new Set([await playerIdOf(RELAY_ADMIN_KEY)]), ...(presence ? { presence } : {}) });

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
 * The exchanges that belong to later relay packages, which R1's relay answers otherwise: the builds
 * (R3) and the release proxy (R2). The socket and the manifest hold no exchanges.
 */
export const DEFERRED = Object.freeze({
  "refusals.json": Object.freeze(["build on an old seq", "compiler missing"]),
  "release.json": Object.freeze(["the newest release", "an outdated designer may still update"]),
});

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
        if (DEFERRED[scenario.file]?.includes(exchange.name)) {
          continue;
        }

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
