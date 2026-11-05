//----------------------------------------------------------------
//  story_mapping.js
//
//  Changelog:
//      Paulinchen  2026-11-05: Left the fields a table names no more out of the rows kept before, as games and admins read them
//                            - Took an admin's key on the mapping's reads from the X-MGQ-Player header only
//                            - Named a key outside the story's ids in the example of a refused key
//      Paulinchen  2026-11-01: Let shared self switches be the whole world's, players behind included
//      Paulinchen  2026-10-31: Let a personal key be one of the game's working values
//      Paulinchen  2026-10-28: Filled each table that holds no rows from seed rows, once
//      Paulinchen  2026-10-23: Let shared and one-way keys be the whole world's, players behind included
//                            - Kept the common events and the game's names with the derived index, which the battle server sends
//                            - Created
//
//----------------------------------------------------------------

// The story mapping every Raid World shares: which switches and variables the world's story shares
// and by which rule (story_keys), the events whose self switches go against the rule an index of
// the game's events derives (story_events), and that derived index. Admins keep the rows by hand,
// in batches that apply whole or not at all; every batch raises one revision, which games read the
// mapping by, and each row keeps its last changes. An empty mapping leaves every key personal.
// Further tables of rows, such as the catch-up's (story_catchup.js), plug into the same engine.

import { playerIdOf } from "./directory.js";
import { badRequest, notFound, withJson } from "./http.js";
import { cleanText } from "./ids.js";
import { VERSION } from "./relay.js";

/**
 * The limits the story mapping keeps.
 */
export const MAPPING_LIMITS = Object.freeze({
  // A batch's JSON body and its edits: a part of the story reviewed at once, such as a few hundred
  // joins, with room to spare.
  maxBodyLength: 1_000_000,
  maxEdits: 2000,
  // The changes each row remembers, newest first.
  history: 20,
  maxNoteLength: 500,
  // The derived index: one entry per map event whose self switches are shared, of about 70,000
  // events in the game.
  maxIndexEvents: 100_000,
  maxIndexBodyLength: 1_000_000,
  // The common events of the derived index, of about 10,000 in the game.
  maxIndexCommons: 10_000,
  // The names of the game's keys, maps and events kept with the index, of about 70,000 events.
  maxNames: 200_000,
  maxNameLength: 200,
});

/**
 * The codes a refusal of the story mapping names why with.
 */
export const MAPPING_REFUSAL = Object.freeze({
  edits: "edits",
  table: "table",
  field: "field",
  kind: "kind",
  option: "option",
  exists: "exists",
  missing: "missing",
  twice: "twice",
  key: "key",
  rev: "rev",
});

/**
 * Who the derived index names as its author when the battle server built it.
 */
export const BATTLE_SERVER_AUTHOR = "battle server";

/**
 * Who a row names as its author when a seed file put it there, see StoryMapping.seed.
 */
export const SEED_AUTHOR = "seed";

/**
 * The route's name after `/v1/admin`.
 */
export const MAPPING_ADMIN_ROUTE = "story";

/**
 * The route's name after the version that games read the mapping from, open to every game.
 */
export const MAPPING_GAME_ROUTE = "story-mapping";

/**
 * The highest id of a switch, variable, companion, item, skill or class a row names.
 */
const MAX_ID = 99_999;

/**
 * The highest map, troop or common event id a row names.
 */
const MAX_MAP = 9999;

/**
 * The highest event id on a map a row names, which a found item's self switch on map 0 holds its
 * item id in.
 */
const MAX_EVENT = 99_999;

/**
 * The highest story step a row names.
 */
const MAX_STEP = 1_000_000;

/**
 * The lowest and highest value a row sets a variable to or asks of one: the game's 32-bit range,
 * which keeps every value exact in JSON.
 */
const MIN_VALUE = -2_147_483_648;

/**
 * See MIN_VALUE.
 */
const MAX_VALUE = 2_147_483_647;

/**
 * The most entries a list of a row holds, such as a chest's items or a scene's steps.
 */
const MAX_LIST = 64;

/**
 * The most marks a row's place holds.
 */
const MAX_MARKS = 32;

/**
 * A self switch's letter as the game keys it.
 */
const LETTER = /^[A-Za-z0-9_]{1,8}$/;

/**
 * A switch's or variable's key: `s` or `v` and its id, without leading zeros.
 */
const STORY_KEY = /^(s|v)([1-9]\d{0,4})$/;

/**
 * A row of story_events by its key: a map's self switches as `ss<map>.<event>.<letter>`, `*` for
 * every event or letter; or the self switches a common event writes as `ce<id>.<letter>`.
 */
const EVENT_KEY = /^(?:ss(0|[1-9]\d{0,3})\.([1-9]\d{0,4}|\*)|ce([1-9]\d{0,3}))\.([A-Za-z0-9_]{1,8}|\*)$/;

/**
 * The parts of the game's names kept with the derived index, each with the keys it takes: switch,
 * variable and map ids, and `<map>.<event>`.
 */
const NAME_PARTS = Object.freeze([["switches", /^[1-9]\d{0,4}$/], ["variables", /^[1-9]\d{0,4}$/], ["maps", /^[1-9]\d{0,3}$/], ["events", /^[1-9]\d{0,3}\.[1-9]\d{0,4}$/]]);

/**
 * One self switch as the story names it: `ss<map>.<event>.<letter>`.
 */
const SELF_SWITCH = /^ss([1-9]\d{0,3})\.([1-9]\d{0,4})\.([A-Za-z0-9_]{1,8})$/;

/**
 * An event command's site as the game scripts name it: a map event's page (`map:<map>:<event>:<page>`,
 * pages from 1) or a common event (`ce:<id>`).
 */
const SITE = /^(?:map:[1-9]\d{0,3}:[1-9]\d{0,4}:[1-9]\d{0,2}|ce:[1-9]\d{0,3})$/;

/**
 * An event as the game scripts name it: a map event (`map:<map>:<event>`) or a common event (`ce:<id>`).
 */
const EVENT_SITE = /^(?:map:[1-9]\d{0,3}:[1-9]\d{0,4}|ce:[1-9]\d{0,3})$/;

/**
 * A field's reader: what it takes, as a refusal names it; how it reads a value, undefined for one
 * it refuses; whether a field it reads may be left out, and whether one left out reads as null.
 *
 * @typedef {object} FieldReader
 * @property {string} what What it takes, such as "a whole number of 1 to 9999".
 * @property {(value: unknown) => any} read Reads a value as kept, undefined for one it refuses.
 * @property {boolean} [optional] Whether the field may be left out, which keeps it out of the row.
 * @property {boolean} [nullable] Whether the field may be null, which it reads as when left out.
 */

/**
 * A table of rows: the store's table they live in, their fields, whether they keep a story order,
 * what keys a row when its fields name it (otherwise the relay numbers new rows), and the rules
 * between fields.
 *
 * @typedef {object} TableSpec
 * @property {string} store The store's table, such as "story_keys".
 * @property {Object<string, FieldReader>} fields The fields in the order rows keep them.
 * @property {boolean} [ordered] Whether rows keep an `order`, the story's order games read them in.
 * @property {(row: object) => string} [key] The key a row's fields name, which is its id.
 * @property {(row: object) => {error: string, code: string} | null} [check] Why a row read field by field is still wrong, null when it is not.
 */

/**
 * Makes a reader of whole numbers in a range.
 *
 * @param {number} min The lowest.
 * @param {number} max The highest.
 * @returns {FieldReader} The reader.
 */
export function whole(min, max) {
  return { what: `a whole number of ${min} to ${max}`, read: (value) => (Number.isSafeInteger(value) && value >= min && value <= max ? value : undefined) };
}

/**
 * Makes a reader of one of a few texts.
 *
 * @param {string[]} values The texts it takes.
 * @returns {FieldReader} The reader.
 */
export function oneOf(values) {
  return { what: `one of ${values.join(", ")}`, read: (value) => (values.includes(value) ? value : undefined) };
}

/**
 * Makes a reader of a text that matches a pattern.
 *
 * @param {RegExp} pattern The pattern.
 * @param {string} what What it takes, such as "a site such as map:7:60:1 or ce:8".
 * @returns {FieldReader} The reader.
 */
export function matching(pattern, what) {
  return { what, read: (value) => (typeof value === "string" && pattern.test(value) ? value : undefined) };
}

/**
 * Makes a reader of a list.
 *
 * @param {FieldReader} entry The reader of each entry.
 * @param {number} min The fewest entries.
 * @param {number} max The most entries.
 * @returns {FieldReader} The reader.
 */
export function listOf(entry, min, max) {
  return {
    what: `a list of ${min} to ${max} entries, each ${entry.what}`,
    read: (value) => {
      if (!Array.isArray(value) || value.length < min || value.length > max) {
        return undefined;
      }

      const read = value.map((each) => entry.read(each));
      return read.includes(undefined) ? undefined : read;
    },
  };
}

/**
 * Makes a reader of an object of fields, read as a row's are.
 *
 * @param {Object<string, FieldReader>} fields The fields.
 * @param {(record: object) => boolean} [fits] Whether the fields fit together.
 * @returns {FieldReader} The reader.
 */
export function record(fields, fits = () => true) {
  return {
    what: `an object of ${Object.entries(fields).map(([name, reader]) => `${name} (${reader.what})`).join(", ")}`,
    read: (value) => {
      const read = readFields(fields, value);
      return read.row && fits(read.row) ? read.row : undefined;
    },
  };
}

/**
 * Makes a reader take null too, which a field left out reads as.
 *
 * @param {FieldReader} reader The reader.
 * @returns {FieldReader} The reader that takes null.
 */
export function nullable(reader) {
  return { what: `${reader.what}, or null`, read: (value) => (value === null ? null : reader.read(value)), nullable: true };
}

/**
 * Makes a field optional: left out, it stays out of the row.
 *
 * @param {FieldReader} reader The reader.
 * @returns {FieldReader} The optional reader.
 */
export function optional(reader) {
  return { ...reader, optional: true };
}

/**
 * Reads true or false.
 */
export const FLAG = Object.freeze({ what: "true or false", read: (value) => (typeof value === "boolean" ? value : undefined) });

/**
 * Reads an option that is on, as true; a row leaves an option that is off out.
 */
export const ON = Object.freeze({ what: "true, or left out", read: (value) => (value === true ? true : undefined) });

/**
 * Reads an id of a switch, variable, companion, item, skill or class.
 */
export const ID = whole(1, MAX_ID);

/**
 * Reads a map's, troop's or common event's id.
 */
export const MAP = whole(1, MAX_MAP);

/**
 * Reads an event's id on a map.
 */
export const EVENT = whole(1, MAX_EVENT);

/**
 * Reads a story step, such as a value of variable 1001.
 */
export const STEP = whole(0, MAX_STEP);

/**
 * Reads a value a row sets a variable to or asks of one.
 */
export const VALUE = whole(MIN_VALUE, MAX_VALUE);

/**
 * Reads an event command's site, see SITE.
 */
export const SITE_FIELD = matching(SITE, "a site such as map:7:60:1 (map, event, page from 1) or ce:8");

/**
 * Reads an event, see EVENT_SITE.
 */
export const EVENT_FIELD = matching(EVENT_SITE, "an event such as map:181:10 or ce:346");

/**
 * Reads one self switch as `ss<map>.<event>.<letter>`, see SELF_SWITCH.
 */
export const SELF_SWITCH_FIELD = matching(SELF_SWITCH, "a self switch such as ss127.81.A");

/**
 * Reads a story's marks: what holds in the story once an event ran, each `["s", switch]` on,
 * `["v", variable, at least]` or `["ss", map, event, letter]` on.
 */
export const MARKS = listOf({
  what: `["s", switch], ["v", variable, at least] or ["ss", map, event, letter]`,
  read: (mark) => {
    if (!Array.isArray(mark)) {
      return undefined;
    }

    const [kind, ...rest] = mark;
    const ok = (kind === "s" && rest.length === 1 && ID.read(rest[0]) !== undefined)
      || (kind === "v" && rest.length === 2 && ID.read(rest[0]) !== undefined && VALUE.read(rest[1]) !== undefined)
      || (kind === "ss" && rest.length === 3 && MAP.read(rest[0]) !== undefined && EVENT.read(rest[1]) !== undefined && typeof rest[2] === "string" && LETTER.test(rest[2]));
    return ok ? [kind, ...rest] : undefined;
  },
}, 0, MAX_MARKS);

/**
 * Reads a row's `order`, its place in the story's order; rows of one order keep their ids' order.
 */
const ORDER = whole(0, 1_000_000_000);

/**
 * The kinds of story_keys, each with what it fits (switches, variables), the options it takes and
 * the option it needs:
 * - `personal`: each player's own, as a key without a row; a row only carries an option or a
 *   reviewed decision. With `work` it is one of the game's working values, which a story replay
 *   keeps apart from the save; released builds read it as personal.
 * - `shared`: the world's story shares it.
 * - `one_way`: shared and only goes up (world_catchup_data.rbx ONE_WAY_VARIABLES, and the
 *   companions' affection, world_affection.rbx).
 * - `scene`: on only while a scene runs; mirrored to viewers, never kept in the world's story
 *   (SCENE_SWITCHES).
 * - `chest`: a switch only chests turn on, each player's own as the chest is
 *   (coop_story_rewards.rbx CHEST_FLAGS).
 * - `count`: how many switches of a range are on, which the relay counts (world_catchup.rbx COUNTS).
 */
export const KEY_KINDS = Object.freeze({
  personal: Object.freeze({ switches: true, variables: true, options: ["defeatWrite", "work"] }),
  shared: Object.freeze({ switches: true, variables: true, options: ["defeatWrite", "wholeWorld", "routeReturnClears", "defeatReturns", "battleScene", "localSteps"] }),
  one_way: Object.freeze({ switches: false, variables: true, options: ["defeatWrite", "wholeWorld", "routeReturnClears", "defeatReturns", "battleScene", "localSteps"] }),
  scene: Object.freeze({ switches: true, variables: false, options: ["defeatWrite"] }),
  chest: Object.freeze({ switches: true, variables: false, options: ["defeatWrite"] }),
  count: Object.freeze({ switches: false, variables: true, options: ["counts"], needs: "counts" }),
});

/**
 * The options of story_keys that only a variable takes.
 */
const VARIABLE_OPTIONS = Object.freeze(["routeReturnClears", "defeatReturns", "battleScene", "localSteps", "counts"]);

/**
 * Reads a step's value by step, such as `{"4": 3}`: each step a story event sets before a battle it
 * cannot lose, to the value its defeat sets.
 */
const DEFEAT_RETURNS = Object.freeze({
  what: `an object of 1 to ${MAX_LIST} steps, each to the value its defeat sets, such as {"4": 3}`,
  read: (value) => {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      return undefined;
    }

    const entries = Object.entries(value);
    const ok = entries.length >= 1 && entries.length <= MAX_LIST
      && entries.every(([step, back]) => /^(0|[1-9]\d{0,6})$/.test(step) && Number(step) <= MAX_STEP && STEP.read(back) !== undefined && back !== Number(step));
    return ok ? Object.fromEntries(entries) : undefined;
  },
});

/**
 * The fields of story_keys: its key, its kind and the options of its kind.
 */
const KEY_FIELDS = Object.freeze({
  key: matching(STORY_KEY, "a switch or variable such as s2029 or v1201 (ids of 1 to 99999)"),
  kind: oneOf(Object.keys(KEY_KINDS)),
  // The game's post-defeat processing (common event 3000) writes it, and a frozen fight's undo
  // leaves it as the defeat set it (battles_raid_freeze_data.rbx DEFEAT_WRITES).
  defeatWrite: optional(ON),
  // One of the game's working values, such as the transfer's map (v57): each game keeps its own,
  // and a story replay never leaves one changed.
  work: optional(ON),
  // Players behind the world share it with the world too, as the companions' affection, which is
  // the highest any player of the world reached (story_tracks.js).
  wholeWorld: optional(ON),
  // The route return (common event 154) clears it, so a one-way key may go down then
  // (world_catchup_data.rbx RETURN_CLEARED).
  routeReturnClears: optional(ON),
  // Steps the world never shares, kept as the value their defeat sets (DEFEAT_RETURNS).
  defeatReturns: optional(DEFEAT_RETURNS),
  // A story event that sets steps before raid boss battles of its own; the world keeps `start`
  // while the main story (v1001) is at `mainStep` and no fight of the troops is frozen or over
  // (world_story.rbx BATTLE_SCENES).
  battleScene: optional(record({ steps: listOf(STEP, 1, MAX_LIST), start: STEP, mainStep: STEP, troops: listOf(MAP, 1, MAX_LIST) })),
  // Steps that stay each player's own while they stand in one of the places, and that the world
  // keeps as `sharedAs` (the Queen's Cup: world_story.rbx CUP_VARIABLE, CUP_STEPS, CUP_OPEN,
  // CUP_PLACES).
  localSteps: optional(record({
    steps: listOf(STEP, 1, MAX_LIST),
    sharedAs: STEP,
    places: listOf(record({ map: MAP, fromX: whole(0, MAX_MAP) }), 1, MAX_LIST),
  }, (steps) => !steps.steps.includes(steps.sharedAs))),
  // The switches it counts, from and to, at most 1000 (world_catchup.rbx COUNTS).
  counts: optional(record({ from: ID, to: ID }, (range) => range.from <= range.to && range.to - range.from < 1000)),
});

/**
 * The tables of the story mapping itself.
 *
 * @type {Object<string, TableSpec>}
 */
export const MAPPING_TABLES = Object.freeze({
  keys: Object.freeze({
    store: "story_keys",
    fields: KEY_FIELDS,
    key: (row) => row.key,
    check: checkKey,
  }),
  events: Object.freeze({
    store: "story_events",
    fields: Object.freeze({
      key: matching(EVENT_KEY, "self switches such as ss7.39.A, ss231.*.* (every event and letter of map 231), ss0.*.F or ce154.*"),
      share: oneOf(["shared", "personal"]),
      // A chest's self switch, each player's own (coop_story_rewards.rbx CHESTS).
      chest: optional(ON),
      // Players behind the world share it with the world too, as the found items' marks, which
      // reach every player of the world (world_catchup.rbx FOUND_MAP).
      wholeWorld: optional(ON),
    }),
    key: (row) => row.key,
    check: checkEvent,
  }),
});

/**
 * Checks a row of story_keys against its kind: whether the kind fits a switch or a variable, and
 * takes the options the row names.
 *
 * @param {object} row The row, read field by field.
 * @returns {{error: string, code: string} | null} Why it is wrong, null when it is not.
 */
function checkKey(row) {
  const variable = row.key[0] === "v";
  const kind = KEY_KINDS[row.kind];

  if (!(variable ? kind.variables : kind.switches)) {
    return { error: `a ${variable ? "variable" : "switch"} cannot be ${row.kind}`, code: MAPPING_REFUSAL.kind };
  }

  const wrong = Object.keys(row).find((name) => name !== "key" && name !== "kind" && (!kind.options.includes(name) || (!variable && VARIABLE_OPTIONS.includes(name))));

  if (wrong) {
    return { error: `a ${row.kind} ${variable ? "variable" : "switch"} takes no ${wrong}`, code: MAPPING_REFUSAL.option };
  }

  return kind.needs && row[kind.needs] === undefined ? { error: `a ${row.kind} key needs ${kind.needs}`, code: MAPPING_REFUSAL.option } : null;
}

/**
 * Checks a row of story_events: a chest's self switches are each player's own, and only shared
 * self switches are the whole world's.
 *
 * @param {object} row The row, read field by field.
 * @returns {{error: string, code: string} | null} Why it is wrong, null when it is not.
 */
function checkEvent(row) {
  if (row.chest && row.share !== "personal") {
    return { error: "a chest's self switches are each player's own: share must be personal", code: MAPPING_REFUSAL.option };
  }

  return row.wholeWorld && (row.share !== "shared" || row.chest) ? { error: "only shared self switches are the whole world's", code: MAPPING_REFUSAL.option } : null;
}

/**
 * Reads an object's fields: each one the fields name, none they do not.
 *
 * @param {Object<string, FieldReader>} fields The fields.
 * @param {unknown} raw The object.
 * @returns {{row: object} | {error: string}} The fields as kept, in the fields' order; or why they are wrong.
 */
function readFields(fields, raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return { error: "the row must be a JSON object" };
  }

  const unknown = Object.keys(raw).find((name) => !Object.hasOwn(fields, name));

  if (unknown !== undefined) {
    return { error: `there is no field ${unknown.slice(0, 40)}` };
  }

  const row = {};

  for (const [name, reader] of Object.entries(fields)) {
    if (raw[name] === undefined) {
      if (reader.optional) {
        continue;
      }

      if (!reader.nullable) {
        return { error: `${name} is missing: it must be ${reader.what}` };
      }
    }

    const value = raw[name] === undefined ? null : reader.read(raw[name]);

    if (value === undefined) {
      return { error: `${name} must be ${reader.what}` };
    }

    row[name] = value;
  }

  return { row };
}

/**
 * Reads a row of a table: its fields, its order in an ordered table, and the table's rules between
 * fields.
 *
 * @param {TableSpec} spec The table.
 * @param {unknown} raw The row as an admin sent it.
 * @returns {{row: object} | {error: string, code: string}} The row as kept, or why it is wrong.
 */
export function readRow(spec, raw) {
  const read = readFields(spec.ordered ? { ...spec.fields, order: ORDER } : spec.fields, raw);

  if (read.error) {
    return { error: read.error, code: MAPPING_REFUSAL.field };
  }

  return spec.check?.(read.row) ?? read;
}

/**
 * Compares two row ids: numbers by their value, texts as words with numbers in them.
 *
 * @param {string} a One id.
 * @param {string} b The other.
 * @returns {number} Below 0 when a comes first, 0 when they are the same, above 0 when b does.
 */
function compareIds(a, b) {
  return a.localeCompare(b, "en", { numeric: true });
}

/**
 * Sorts a table's entries as games read them: by `order` in an ordered table, else by id; each
 * row without the fields its table names no more, which rows kept before still hold.
 *
 * @param {TableSpec} spec The table.
 * @param {object[]} entries The entries.
 * @returns {object[]} The entries, sorted.
 */
function sorted(spec, entries) {
  const named = (name) => Object.hasOwn(spec.fields, name) || (spec.ordered && name === "order");
  return [...entries].sort((a, b) => (spec.ordered ? a.row.order - b.row.order : 0) || compareIds(a.id, b.id))
    .map((entry) => ({ ...entry, row: Object.fromEntries(Object.entries(entry.row).filter(([name]) => named(name))) }));
}

/**
 * Makes a refusal of a batch's edit.
 *
 * @param {number} status The status.
 * @param {string} error Why.
 * @param {string} code The code, see MAPPING_REFUSAL.
 * @param {number} [edit] The edit's index in the batch.
 * @returns {{status: number, body: object}} The answer.
 */
function refusal(status, error, code, edit) {
  return { status, body: { error, code, ...(edit === undefined ? {} : { edit }) } };
}

/**
 * Where the story mapping lives: the revision with the next number of each table whose rows the
 * relay numbers, each table's entries, each row's last changes and the derived index.
 *
 * An entry is `{id, row, note, author, time, rev}`; a change `{rev, op, before, after, note,
 * author, time}`.
 *
 * @typedef {object} StoryMappingStore
 * @property {() => Promise<{rev: number, rowsRev: number, next: Object<string, number>, seeded?: Object<string, number>} | undefined>} getMeta Reads the revision, undefined before the first change.
 * @property {(table: string) => Promise<object[]>} all Reads every entry of a store's table.
 * @property {(table: string, id: string) => Promise<object | undefined>} get Reads one entry.
 * @property {(table: string, id: string) => Promise<object[]>} history Reads a row's changes, newest first.
 * @property {(commit: {meta: object, puts: {table: string, entry: object}[], removes: {table: string, id: string}[], changes: {table: string, id: string, change: object}[], index?: object}, keep: number) => Promise<void>} commit Keeps a batch whole or not at all, and the newest `keep` changes of each row it changed.
 * @property {() => Promise<object | undefined>} getIndex Reads the derived index, undefined before the first.
 */

/**
 * The story mapping and the tables beside it, kept by the relay's admins.
 */
export class StoryMapping {
  /**
   * Makes the story mapping over its store.
   *
   * @param {StoryMappingStore} store The store.
   * @param {{tables?: Object<string, TableSpec>, limits?: typeof MAPPING_LIMITS, clock?: () => number}} [options] The tables, MAPPING_TABLES unless given; the limits; the clock.
   */
  constructor(store, { tables = MAPPING_TABLES, limits = MAPPING_LIMITS, clock = Date.now } = {}) {
    /** The store. */
    this.store = store;
    /** The tables by name. */
    this.tables = tables;
    /** The limits. */
    this.limits = limits;
    /** The clock. */
    this.clock = clock;
    /** The work under way, which every change waits for. */
    this.queue = Promise.resolve();
    /** What games read at the revision it names, until a change. */
    this.gameView = null;
  }

  /**
   * Reads the revision, with the tables the seeding is done with (see seed).
   *
   * @returns {Promise<{rev: number, rowsRev: number, next: Object<string, number>, seeded?: Object<string, number>}>} The revision, 0 before the first change.
   */
  async meta() {
    return (await this.store.getMeta()) ?? { rev: 0, rowsRev: 0, next: {} };
  }

  /**
   * Sums up the mapping for an admin: the revision, the rows of each table and the derived index.
   *
   * @returns {Promise<{status: number, body: object}>} `rev` (raised by every change), `rowsRev` (the last change of rows), `tables` (each table's rows counted) and `index` (`built`, the rows' revision it was built from, `stale`, `events` and `commons` counted, `author`, `time`; null before the first).
   */
  async summary() {
    const meta = await this.meta();
    const tables = {};

    for (const [name, spec] of Object.entries(this.tables)) {
      tables[name] = (await this.store.all(spec.store)).length;
    }

    const index = await this.store.getIndex();
    const view = index ? { built: index.built, stale: index.built !== meta.rowsRev, events: index.events.length, commons: (index.commons ?? []).length, author: index.author, time: index.time } : null;
    return { status: 200, body: { rev: meta.rev, rowsRev: meta.rowsRev, tables, index: view } };
  }

  /**
   * Hands an admin a table's entries.
   *
   * @param {string} table The table.
   * @returns {Promise<{status: number, body: object}>} `rev`, `table` and `rows` (each `{id, row, note, author, time, rev}`, in the order games read them); 404 for no such table.
   */
  async rows(table) {
    const spec = this.tableOf(table);

    if (!spec) {
      return notFound("table");
    }

    const meta = await this.meta();
    return { status: 200, body: { rev: meta.rev, table, rows: sorted(spec, await this.store.all(spec.store)) } };
  }

  /**
   * Hands an admin a row's last changes, also of a row removed since.
   *
   * @param {string} table The table.
   * @param {string} id The row's id.
   * @returns {Promise<{status: number, body: object}>} `table`, `id` and `history` (newest first, each `{rev, op, before, after, note, author, time}`); 404 for no such table.
   */
  async history(table, id) {
    const spec = this.tableOf(table);
    return spec ? { status: 200, body: { table, id, history: await this.store.history(spec.store, id) } } : notFound("table");
  }

  /**
   * Hands an admin the derived index whole, without the game's names (see names).
   *
   * @returns {Promise<{status: number, body: object}>} `rowsRev` and `index` (`built`, `stale`, `events` as `[map, event]` pairs, `commons`, `author`, `time`; null before the first).
   */
  async index() {
    const meta = await this.meta();
    const index = await this.store.getIndex();
    const view = index ? { built: index.built, stale: index.built !== meta.rowsRev, events: index.events, commons: index.commons ?? [], author: index.author, time: index.time } : null;
    return { status: 200, body: { rowsRev: meta.rowsRev, index: view } };
  }

  /**
   * Hands an admin the names of the game's switches, variables, maps and events the battle server
   * sent with the derived index, which the website shows the keys with.
   *
   * @returns {Promise<{status: number, body: object}>} `rowsRev` and `names` (`built`, `stale`, `names`, `author`, `time`; null before an index with names).
   */
  async names() {
    const meta = await this.meta();
    const index = await this.store.getIndex();
    const view = index?.names ? { built: index.built, stale: index.built !== meta.rowsRev, names: index.names, author: index.author, time: index.time } : null;
    return { status: 200, body: { rowsRev: meta.rowsRev, names: view } };
  }

  /**
   * Applies an admin's batch of edits whole or not at all, as one new revision. Each edit names its
   * table and `op`: `add` with `row`, `change` with `id` and `row` (the whole row), `remove` with
   * `id`; `note` sets the row's note, left out it keeps the one it had. A change that leaves a row
   * and its note as they were changes nothing.
   *
   * @param {any} request `edits`, and `rev`, the revision the admin read, refused with code `rev` once the mapping moved on; left out, no check.
   * @param {string} admin The admin's player id, whom each row and change names.
   * @returns {Promise<{status: number, body: object, audit?: string}>} `rev` and `changed` (each `{table, id, op}`), with what changed for the log; or a refusal with `code` and `edit`, the index of the edit refused.
   */
  async edit(request, admin) {
    const read = this.readEdits(request);

    if (read.status) {
      return read;
    }

    return this.exclusive(async () => {
      const meta = await this.meta();

      if (request.rev !== undefined && request.rev !== meta.rev) {
        return { status: 409, body: { error: "the mapping changed since the revision the edits built on", code: MAPPING_REFUSAL.rev, rev: meta.rev } };
      }

      const next = { ...meta.next };
      const rev = meta.rev + 1;
      const time = this.clock();
      const commit = { puts: [], removes: [], changes: [] };
      const changed = [];

      for (const [index, edit] of read.edits.entries()) {
        const id = edit.id ?? (edit.spec.key ? edit.spec.key(edit.row) : String((next[edit.table] = (next[edit.table] ?? 0) + 1)));
        const kept = edit.op === "add" && !edit.spec.key ? undefined : await this.store.get(edit.spec.store, id);

        if (edit.op === "add" && kept) {
          return refusal(409, `${edit.table} holds ${id} already`, MAPPING_REFUSAL.exists, index);
        }

        if (edit.op !== "add" && !kept) {
          return refusal(409, `${edit.table} holds no ${id}`, MAPPING_REFUSAL.missing, index);
        }

        const note = edit.note ?? kept?.note ?? "";

        if (edit.op === "change" && JSON.stringify(edit.row) === JSON.stringify(kept.row) && note === kept.note) {
          continue;
        }

        const change = { rev, op: edit.op, before: kept?.row ?? null, after: edit.row ?? null, note, author: admin, time };

        if (edit.op === "remove") {
          commit.removes.push({ table: edit.spec.store, id });
        } else {
          commit.puts.push({ table: edit.spec.store, entry: { id, row: edit.row, note, author: admin, time, rev } });
        }

        commit.changes.push({ table: edit.spec.store, id, change });
        changed.push({ table: edit.table, id, op: edit.op });
      }

      if (changed.length === 0) {
        return { status: 200, body: { rev: meta.rev, changed } };
      }

      await this.store.commit({ meta: { ...meta, rev, rowsRev: rev, next }, ...commit }, this.limits.history);
      this.gameView = null;
      return { status: 200, body: { rev, changed }, audit: `admin ${admin} changed the story mapping to rev ${rev}: ${changesText(changed)}` };
    });
  }

  /**
   * Reads a batch's edits and their rows, before anything is read of the store.
   *
   * @param {any} request The batch.
   * @returns {{edits: {table: string, spec: TableSpec, op: string, id?: string, row?: object, note?: string}[]} | {status: number, body: object}} The edits, or the refusal.
   */
  readEdits(request) {
    if (!request || typeof request !== "object" || Array.isArray(request)) {
      return refusal(400, "the request must be a JSON object", MAPPING_REFUSAL.edits);
    }

    if (request.rev !== undefined && !Number.isSafeInteger(request.rev)) {
      return refusal(400, "rev must be the revision the edits built on, or left out", MAPPING_REFUSAL.edits);
    }

    const raw = request.edits;

    if (!Array.isArray(raw) || raw.length === 0 || raw.length > this.limits.maxEdits) {
      return refusal(400, `edits must list 1 to ${this.limits.maxEdits} edits`, MAPPING_REFUSAL.edits);
    }

    const edits = [];
    const named = new Set();

    for (const [index, edit] of raw.entries()) {
      const read = this.readEdit(edit);

      if (read.error) {
        return refusal(400, read.error, read.code, index);
      }

      const id = read.edit.id ?? (read.edit.op === "add" ? read.edit.spec.key?.(read.edit.row) : undefined);

      if (id !== undefined && named.has(`${read.edit.table}\n${id}`)) {
        return refusal(400, `the edits name ${read.edit.table} ${id} twice`, MAPPING_REFUSAL.twice, index);
      }

      if (id !== undefined) {
        named.add(`${read.edit.table}\n${id}`);
      }

      edits.push(read.edit);
    }

    return { edits };
  }

  /**
   * Reads one edit of a batch.
   *
   * @param {any} edit The edit.
   * @returns {{edit: {table: string, spec: TableSpec, op: string, id?: string, row?: object, note?: string}} | {error: string, code: string}} The edit, or why it is wrong.
   */
  readEdit(edit) {
    if (!edit || typeof edit !== "object" || Array.isArray(edit)) {
      return { error: "each edit must be a JSON object", code: MAPPING_REFUSAL.edits };
    }

    const spec = this.tableOf(edit.table);

    if (!spec) {
      return { error: `there is no table ${String(edit.table).slice(0, 40)}: the tables are ${Object.keys(this.tables).join(", ")}`, code: MAPPING_REFUSAL.table };
    }

    if (!["add", "change", "remove"].includes(edit.op)) {
      return { error: "op must be add, change or remove", code: MAPPING_REFUSAL.edits };
    }

    const note = edit.note === undefined ? undefined : cleanText(edit.note, Infinity);

    if (note !== undefined && (typeof edit.note !== "string" || [...note].length > this.limits.maxNoteLength)) {
      return { error: `note must be a text of at most ${this.limits.maxNoteLength} characters`, code: MAPPING_REFUSAL.field };
    }

    if ((edit.op === "add") !== (edit.id === undefined) || (edit.id !== undefined && (typeof edit.id !== "string" || edit.id.length === 0 || edit.id.length > 80))) {
      return { error: edit.op === "add" ? "an add names no id: the row's key or the relay names it" : `a ${edit.op} names the row's id`, code: MAPPING_REFUSAL.edits };
    }

    if (edit.op === "remove") {
      return edit.row === undefined ? { edit: { table: edit.table, spec, op: edit.op, id: edit.id, note } } : { error: "a remove names no row", code: MAPPING_REFUSAL.edits };
    }

    const read = readRow(spec, edit.row);

    if (read.error) {
      return read;
    }

    if (edit.op === "change" && spec.key && spec.key(read.row) !== edit.id) {
      return { error: `a change keeps the row's key ${edit.id}: remove the row and add the new one`, code: MAPPING_REFUSAL.key };
    }

    return { edit: { table: edit.table, spec, op: edit.op, ...(edit.id === undefined ? {} : { id: edit.id }), row: read.row, note } };
  }

  /**
   * Keeps the derived index an admin sends, see keepIndex.
   *
   * @param {any} request See keepIndex.
   * @param {string} admin The player id of the admin who sent it.
   * @returns {Promise<{status: number, body: object, audit?: string}>} See keepIndex.
   */
  async putIndex(request, admin) {
    return this.keepIndex(request, admin);
  }

  /**
   * Keeps the derived index of the map events and common events whose self switches are shared,
   * which the battle server builds from the rows of one revision and the game's events, and the
   * game's names it read on the way. Raises the revision, since games read it with the rows.
   *
   * @param {any} request `built`, the rows' revision (`rowsRev`) it was built from, `events`, each `[map, event]`, `commons` (common event ids, none when left out) and `names` (see readIndexNames, none when left out).
   * @param {string} by Who built it: the player id of an admin, or BATTLE_SERVER_AUTHOR.
   * @returns {Promise<{status: number, body: object, audit?: string}>} `rev` and `index` as summary names it; 409 with code `rev` when the rows changed since `built`; or why the request is wrong.
   */
  async keepIndex(request, by) {
    const events = readIndexEvents(request?.events, this.limits);
    const commons = request?.commons === undefined ? [] : readIndexCommons(request.commons, this.limits);
    const names = request?.names === undefined ? undefined : readIndexNames(request.names, this.limits);

    if (!events || !commons || names === null || !Number.isSafeInteger(request?.built)) {
      return badRequest(`the index needs built, the rows' revision it was built from, and events, at most ${this.limits.maxIndexEvents} [map, event] pairs; commons, at most ${this.limits.maxIndexCommons} common event ids, and names may come with it`);
    }

    return this.exclusive(async () => {
      const meta = await this.meta();

      if (request.built !== meta.rowsRev) {
        return { status: 409, body: { error: "the rows changed since the revision the index was built from", code: MAPPING_REFUSAL.rev, rowsRev: meta.rowsRev } };
      }

      const rev = meta.rev + 1;
      const index = { built: request.built, events, commons, ...(names ? { names } : {}), author: by, time: this.clock() };
      await this.store.commit({ meta: { ...meta, rev }, puts: [], removes: [], changes: [], index }, this.limits.history);
      this.gameView = null;
      const view = { built: index.built, stale: false, events: events.length, commons: commons.length, author: by, time: index.time };
      const who = by === BATTLE_SERVER_AUTHOR ? "the battle server" : `admin ${by}`;
      return { status: 200, body: { rev, index: view }, audit: `${who} kept the story index of rows rev ${index.built} with ${events.length} events and ${commons.length} common events${names ? " and the game's names" : ""}, rev ${rev}` };
    });
  }

  /**
   * Fills the tables that hold no rows yet with seed rows, all in one revision, as the relay's
   * start fills the catch-up's tables from its seed files (Relay/seed/story). The rows keep no
   * history, as nothing was there before them. A table the seeding filled or found with rows is
   * named in the meta's `seeded` and never seeded again, so a table the admins emptied stays empty.
   *
   * @param {Object<string, object[]>} seeds The rows by table, as an admin would add them.
   * @param {string} [by] Who the rows name as their author, SEED_AUTHOR unless given.
   * @returns {Promise<{rev: number, seeded: Object<string, number>}>} The revision and how many rows each table took; the revision as it was when none did.
   * @throws {Error} A table is unknown or a row does not read, since the seeds are the relay's own files.
   */
  async seed(seeds, by = SEED_AUTHOR) {
    return this.exclusive(async () => {
      const meta = await this.meta();
      const next = { ...meta.next };
      const rev = meta.rev + 1;
      const time = this.clock();
      const puts = [];
      const seeded = {};
      const done = { ...meta.seeded };

      for (const [name, rows] of Object.entries(seeds)) {
        const spec = this.tableOf(name);

        if (!spec || !Array.isArray(rows)) {
          throw new Error(`the seed of ${name} must be a list of rows of a table: the tables are ${Object.keys(this.tables).join(", ")}`);
        }

        if (rows.length === 0 || done[name] !== undefined) {
          continue;
        }

        if ((await this.store.all(spec.store)).length > 0) {
          done[name] = meta.rev;
          continue;
        }

        const ids = new Set();

        for (const [index, raw] of rows.entries()) {
          const read = readRow(spec, raw);

          if (read.error) {
            throw new Error(`seed row ${index} of ${name}: ${read.error}`);
          }

          const id = spec.key ? spec.key(read.row) : String((next[name] = (next[name] ?? 0) + 1));

          if (ids.has(id)) {
            throw new Error(`the seed rows of ${name} name ${id} twice`);
          }

          ids.add(id);
          puts.push({ table: spec.store, entry: { id, row: read.row, note: "", author: by, time, rev } });
        }

        seeded[name] = rows.length;
        done[name] = rev;
      }

      if (puts.length === 0) {
        if (Object.keys(done).length > Object.keys(meta.seeded ?? {}).length) {
          await this.store.commit({ meta: { ...meta, seeded: done }, puts: [], removes: [], changes: [] }, this.limits.history);
        }

        return { rev: meta.rev, seeded };
      }

      await this.store.commit({ meta: { ...meta, rev, rowsRev: rev, next, seeded: done }, puts, removes: [], changes: [] }, this.limits.history);
      this.gameView = null;
      return { rev, seeded };
    });
  }

  /**
   * Hands games the mapping and every table beside it, at one revision: each table's rows as games
   * read them, without the notes.
   *
   * @param {number | null} known The revision the game holds, which is answered with `same` alone.
   * @returns {Promise<{status: number, body: object}>} `rev`, `tables` (each table's rows) and `index` (`built`, `stale`, `events` and `commons`; null before the first); or `rev` and `same`.
   */
  async forGames(known) {
    const view = this.gameView ?? (await this.exclusive(() => this.buildGameView()));

    if (known === view.rev) {
      return { status: 200, body: { rev: view.rev, same: true } };
    }

    return { status: 200, body: view };
  }

  /**
   * Builds what games read and keeps it until a change. Called inside exclusive.
   *
   * @returns {Promise<object>} What games read, see forGames.
   */
  async buildGameView() {
    const meta = await this.meta();
    const tables = {};

    for (const [name, spec] of Object.entries(this.tables)) {
      tables[name] = sorted(spec, await this.store.all(spec.store)).map((entry) => entry.row);
    }

    const index = await this.store.getIndex();
    this.gameView = { rev: meta.rev, tables, index: index ? { built: index.built, stale: index.built !== meta.rowsRev, events: index.events, commons: index.commons ?? [] } : null };
    return this.gameView;
  }

  /**
   * Finds a table by its name.
   *
   * @param {unknown} name The name.
   * @returns {TableSpec | undefined} The table, undefined for none.
   */
  tableOf(name) {
    return typeof name === "string" && Object.hasOwn(this.tables, name) ? this.tables[name] : undefined;
  }

  /**
   * Runs work after the work under way, so two batches never read the same revision.
   *
   * @template T
   * @param {() => Promise<T>} work The work.
   * @returns {Promise<T>} What it returns.
   */
  exclusive(work) {
    const result = this.queue.then(work);
    this.queue = result.catch(() => {});
    return result;
  }
}

/**
 * Reads the derived index's events: `[map, event]` pairs, each once, sorted.
 *
 * @param {unknown} events The events.
 * @param {typeof MAPPING_LIMITS} limits The limits.
 * @returns {number[][] | null} The pairs, null when they are wrong.
 */
function readIndexEvents(events, limits) {
  if (!Array.isArray(events) || events.length > limits.maxIndexEvents) {
    return null;
  }

  const pairs = new Map();

  for (const pair of events) {
    if (!Array.isArray(pair) || pair.length !== 2 || MAP.read(pair[0]) === undefined || EVENT.read(pair[1]) === undefined) {
      return null;
    }

    pairs.set(`${pair[0]}.${pair[1]}`, [pair[0], pair[1]]);
  }

  return [...pairs.values()].sort((a, b) => a[0] - b[0] || a[1] - b[1]);
}

/**
 * Reads the derived index's common events: ids, each once, sorted.
 *
 * @param {unknown} commons The common events.
 * @param {typeof MAPPING_LIMITS} limits The limits.
 * @returns {number[] | null} The ids, null when they are wrong.
 */
function readIndexCommons(commons, limits) {
  if (!Array.isArray(commons) || commons.length > limits.maxIndexCommons || commons.some((id) => MAP.read(id) === undefined)) {
    return null;
  }

  return [...new Set(commons)].sort((a, b) => a - b);
}

/**
 * Reads the game's names kept with the derived index: `switches`, `variables` and `maps` (each id
 * to its name), `events` (each `"<map>.<event>"` to its name) and `companions` (how many affection
 * variables the game keeps); a part left out is none.
 *
 * @param {unknown} names The names.
 * @param {typeof MAPPING_LIMITS} limits The limits.
 * @returns {{switches: Object<string, string>, variables: Object<string, string>, maps: Object<string, string>, events: Object<string, string>, companions: number} | null} The names, null when they are wrong.
 */
function readIndexNames(names, limits) {
  if (!names || typeof names !== "object" || Array.isArray(names)) {
    return null;
  }

  const read = {};
  let count = 0;

  for (const [part, key] of NAME_PARTS) {
    const given = names[part] ?? {};

    if (!given || typeof given !== "object" || Array.isArray(given)) {
      return null;
    }

    read[part] = {};

    for (const [id, name] of Object.entries(given)) {
      if (!key.test(id) || typeof name !== "string" || name.length > limits.maxNameLength || ++count > limits.maxNames) {
        return null;
      }

      read[part][id] = name;
    }
  }

  const companions = names.companions ?? 0;
  return Number.isSafeInteger(companions) && companions >= 0 && companions <= MAX_ID ? { ...read, companions } : null;
}

/**
 * Names a batch's changes for the log, the first 20 of them.
 *
 * @param {{table: string, id: string, op: string}[]} changed The changes.
 * @returns {string} Such as "add keys s2029, remove joins 17".
 */
function changesText(changed) {
  const shown = changed.slice(0, 20).map((change) => `${change.op} ${change.table} ${change.id}`).join(", ");
  return changed.length > 20 ? `${shown} and ${changed.length - 20} more` : shown;
}

/**
 * Reads which mapping route an address names after `/v1/admin/story`.
 *
 * @param {string[]} rest The address's parts after `story`, still percent-encoded.
 * @returns {string[] | null} The parts decoded, null for parts that do not decode.
 */
function decodedParts(rest) {
  try {
    return rest.map((part) => decodeURIComponent(part));
  } catch {
    return null;
  }
}

/**
 * Answers a request to the story mapping's admin routes, for the relay's admins only:
 * `GET /v1/admin/story` sums it up, `GET .../<table>` hands out a table's rows,
 * `GET .../<table>/<id>/history` a row's last changes, `POST .../edit` applies a batch of edits,
 * `GET` and `POST .../index` hand out and keep the derived index, `GET .../names` the game's names kept with it.
 *
 * @param {StoryMapping} mapping The story mapping.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address, whose `player` names the admin's key when no header does.
 * @param {string[]} rest The address's parts after `story`, still percent-encoded.
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when it is too large to read.
 * @param {string | null} header The key the PLAYER_HEADER names, which wins over the address and the body.
 * @param {(key: unknown) => Promise<boolean>} isAdmin Tells whether a key is an admin's.
 * @returns {Promise<{status: number, body: object, audit?: string}>} The answer, with what changed for the log.
 */
export async function handleMappingAdminRequest(mapping, method, url, rest, readBody, header, isAdmin) {
  const refused = { status: 403, body: { error: "only the relay's admins may do this" } };
  const parts = decodedParts(rest);

  if (!parts) {
    return notFound("route");
  }

  if (method === "GET") {
    if (!(await isAdmin(header))) {
      return refused;
    }

    if (parts.length === 0) {
      return mapping.summary();
    }

    if (parts.length === 1 && parts[0] === "index") {
      return mapping.index();
    }

    if (parts.length === 1 && parts[0] === "names") {
      return mapping.names();
    }

    if (parts.length === 1) {
      return mapping.rows(parts[0]);
    }

    return parts.length === 3 && parts[2] === "history" ? mapping.history(parts[0], parts[1]) : notFound("route");
  }

  const post = (limit, work) => withJson(readBody, limit, async (body) => {
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return badRequest("the request must be a JSON object");
    }

    const key = header || body.player;
    return (await isAdmin(key)) ? work(body, await playerIdOf(key)) : refused;
  });

  if (method === "POST" && parts.length === 1 && parts[0] === "edit") {
    return post(mapping.limits.maxBodyLength, (body, admin) => mapping.edit(body, admin));
  }

  if (method === "POST" && parts.length === 1 && parts[0] === "index") {
    return post(mapping.limits.maxIndexBodyLength, (body, admin) => mapping.putIndex(body, admin));
  }

  return notFound("route");
}

/**
 * Answers a game's request for the story mapping, `GET /v1/story-mapping`, open to every game:
 * `?known=<rev>` answers `same` alone while the mapping is at that revision.
 *
 * @param {StoryMapping} mapping The story mapping.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @returns {Promise<{status: number, body: object}>} The answer, see StoryMapping.forGames.
 */
export async function handleMappingGameRequest(mapping, method, url) {
  if (method !== "GET" || url.pathname !== `/${VERSION}/${MAPPING_GAME_ROUTE}`) {
    return notFound("route");
  }

  const known = url.searchParams.get("known");
  return mapping.forGames(known !== null && /^\d{1,15}$/.test(known) ? Number(known) : null);
}
