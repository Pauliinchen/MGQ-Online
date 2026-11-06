//----------------------------------------------------------------
//  story.js
//
//  Changelog:
//      Paulinchen  2026-11-06: Ran one piece of work at a time through one shared queue
//                            - Handed games the story's revision and shared companions alone and dropped the admin's keyed writes, the route lock and the write log
//      Paulinchen  2026-11-05: Dropped the games' story writes, part checkpoint reads and route locks over HTTP, which only games without story tracks used; the keyed story stays as world data
//                            - Dropped the keys feature and the refusal of games without it, which the version gate turns away
//                            - Read the story's ids from story_ids.json, which the generator writes from MGQOnline.Game's StoryIds
//                            - Named the routes' counters by the story's ids everywhere
//      Paulinchen  2026-10-31: Handed a keyed story's keys to the story tracks that start from it
//                            - Dropped the sealed story and turned away every game that keeps no keys
//                            - Kept the pins of a world whose story runs on tracks without keys of its own
//      Paulinchen  2026-10-23: Kept the highest affection any write of a keyed story named
//                            - Shared the value patterns, the first counters and the clear switches with the story tracks
//      Paulinchen  2026-10-21: Let an admin set switches, variables and self switches of a keyed story by id as a revision every game takes
//                            - Let an admin pin keys of a keyed story at any value and take pins off again, reading the pins kept before as pins at off
//                            - Took a write that changes pinned keys without them and told every game the pinned values in a revision of its own
//      Paulinchen  2026-10-18: Let an admin pin keys of a keyed story off and refused writes that change pinned keys
//      Paulinchen  2026-10-17: Kept the frozen raid boss fights key by key in a keyed story, one per troop
//                            - Kept the end of a frozen fight for good
//      Paulinchen  2026-10-15: Kept a Raid World's story key by key, the first writer of a key keeping it, and pushed what each write changed
//                            - Moved a sealed story to keys with the first write of a game that opened it
//                            - Refused sealed writes to a keyed story with the code update
//                            - Told a keyed write whether other writes changed keys since its base
//                            - Kept the companions' affection key by key in a keyed story
//                            - Refused a route under way before the Great Decision and repaired a story written with one
//      Paulinchen  2026-10-12: Kept the level caps the world's story unlocked
//      Paulinchen  2026-10-11: Opened every route again once the world finished all of them
//                            - Took the locked route's first step from the Great Decision once every route was finished
//                            - Kept the lock of a route finished before until the world returned from it
//      Paulinchen  2026-10-10: Refused taking back the route lock while the story is on that route and a route lock while it is on another
//      Paulinchen  2026-10-09: Let an admin take back the route locked at the Great Decision
//                            - Kept only the first end of a part as its checkpoint
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

// A Raid World's keyed story, kept as world data beside its story tracks (story_tracks.js), which
// play the story: the counters, the keys older games wrote, which the world's tracks start from,
// the shared companions, the pins and the route lock. Games read it and add shared companions;
// admins set its keys and pins while the world's tracks have not started.

import { badRequest, notFound, withJson } from "./http.js";
import { isId } from "./ids.js";
import { VERSION, workQueue } from "./relay.js";
import STORY_IDS from "./story_ids.json" with { type: "json" };

/**
 * The limits a world's story keeps.
 */
export const STORY_LIMITS = Object.freeze({
  // The JSON body of a companions list.
  maxSmallBodyLength: 32 * 1024,
  maxCompanions: 2000,
  maxCompanionsPerAdd: 500,
  maxActorId: 99_999,
  // A keyed story's lists: all of them together, a late story's thousands of switches, variables
  // and self switches with room to spare, and the longest value a variable may hold.
  maxListsLength: 1_800_000,
  maxValueLength: 4096,
  // The longest frozen raid boss fight: its stand-ins and the keys it holds.
  maxFreezeLength: 65_536,
  maxId: 99_999,
  // The keys an admin sets at once, and the JSON body that names them.
  maxAdminKeys: 2000,
  maxAdminBodyLength: 128 * 1024,
  maxPins: 5000,
});

/**
 * The lists a keyed story travels in: the switches on and off, the variables with their values, the
 * self switches on and off, as the games write a story (story_state.rbx `story_lists`), the
 * companions' affection (world_affection.rbx) and the frozen raid boss fights (world_freeze.rbx).
 */
export const LISTS = Object.freeze(["s", "sf", "v", "ss", "ssf", "a", "f"]);

/**
 * The list of the frozen raid boss fights, whose entries hold commas and so are separated by
 * semicolons, each its troop and its fight split by the first bar.
 */
const FREEZES = "f";

/**
 * A companion's affection as the games write it: a whole number above 0.
 */
const AFFECTION = /^[1-9]\d{0,8}$/;

/**
 * A frozen raid boss fight as the games write it: its fields with every free text escaped, or "0"
 * once it ended, which replaces the fight for every game.
 */
export const FREEZE = /^(0|[A-Za-z0-9_$!%:,.|~-]+)$/;

/**
 * What a frozen raid boss fight's key holds once the fight ended, for good.
 */
export const FREEZE_ENDED = "0";

/**
 * A variable's value as the games write it: a whole number, a decimal, a text in base64, true or
 * false (story_state.rbx `encode_value`).
 */
export const VALUE = /^(n-?\d+|f-?\d+(\.\d+)?(e[-+]?\d+)?|s[A-Za-z0-9+/=]*|T|F)$/;

/**
 * A self switch's key: its map, its event and its letter.
 */
const SELF_KEY = /^(\d{1,5})\.(\d{1,6})\.([A-Za-z0-9_]{1,8})$/;

/**
 * The value of a switch or self switch that is off and of a variable at 0, by the key's first letter.
 */
const OFF_VALUE = Object.freeze({ s: "0", v: "n0" });

/**
 * The kinds of keys an admin sets by id: switches and variables by their ids, self switches as
 * map.event.letter.
 */
export const ADMIN_KINDS = Object.freeze(["s", "v", "ss"]);

/**
 * Writes a value an admin names as a key of a keyed story holds it: a switch or self switch as "1"
 * or "0", a variable as the games write it (story_state.rbx `encode_value`).
 *
 * @param {string} kind The key's kind, one of ADMIN_KINDS.
 * @param {unknown} value The value: true or false for a switch or self switch; a number, a text, true or false for a variable.
 * @param {typeof STORY_LIMITS} [limits] The limits.
 * @returns {string | null} The value as kept, or null when it is none of these.
 */
export function keyValueOf(kind, value, limits = STORY_LIMITS) {
  if (kind !== "v") {
    return typeof value === "boolean" ? (value ? "1" : "0") : null;
  }

  const written = typeof value === "boolean" ? (value ? "T" : "F")
    : Number.isSafeInteger(value) ? `n${value}`
      : typeof value === "number" && Number.isFinite(value) ? `f${value}`
        : typeof value === "string" ? `s${base64Of(value)}`
          : null;
  return written !== null && written.length <= limits.maxValueLength && VALUE.test(written) ? written : null;
}

/**
 * Reads a value of a keyed story as an admin names it, see keyValueOf.
 *
 * @param {string} key The key, such as "v1201".
 * @param {string} value The value as kept.
 * @returns {boolean | number | string} The value.
 */
export function keyValueView(key, value) {
  if (!key.startsWith("v")) {
    return value === "1";
  }

  switch (value[0]) {
    case "n":
    case "f":
      return Number(value.slice(1));
    case "s":
      return textOf(value.slice(1));
    default:
      return value === "T";
  }
}

/**
 * Encodes a text's UTF-8 bytes as base64, as the games write a text variable.
 *
 * @param {string} text The text.
 * @returns {string} The base64.
 */
function base64Of(text) {
  return btoa(Array.from(new TextEncoder().encode(text), (byte) => String.fromCharCode(byte)).join(""));
}

/**
 * Decodes base64 of UTF-8 bytes into a text.
 *
 * @param {string} base64 The base64.
 * @returns {string} The text.
 */
function textOf(base64) {
  return new TextDecoder().decode(Uint8Array.from(atob(base64), (character) => character.charCodeAt(0)));
}

/**
 * Reads the keys an admin sets by id: `s` (switch ids to true or false), `v` (variable ids to their
 * values) and `ss` ("map.event.letter" to true or false).
 *
 * @param {any} request The request.
 * @param {typeof STORY_LIMITS} [limits] The limits.
 * @returns {{keys: Map<string, string>} | {error: string}} The keys as a keyed story names them with their values as kept, or why the request is wrong.
 */
export function readAdminKeys(request, limits = STORY_LIMITS) {
  const plain = (value) => value === undefined || (value !== null && typeof value === "object" && !Array.isArray(value));

  if (!request || typeof request !== "object" || !ADMIN_KINDS.every((kind) => plain(request[kind]))) {
    return { error: `the request must be a JSON object of ${ADMIN_KINDS.join(", ")}, each an object of keys and values` };
  }

  const keys = new Map();

  for (const kind of ADMIN_KINDS) {
    for (const [id, value] of Object.entries(request[kind] ?? {})) {
      const key = keyNameOf(kind, id, limits);
      const kept = keyValueOf(kind, value, limits);

      if (key === null || kept === null) {
        return { error: `${kind} names ${kind === "ss" ? "self switches as map.event.letter to true or false" : kind === "s" ? `switch ids of 1 to ${limits.maxId} to true or false` : `variable ids of 1 to ${limits.maxId} to numbers, texts, true or false`}: ${String(id).slice(0, 40)}` };
      }

      keys.set(key, kept);
    }
  }

  if (keys.size === 0 || keys.size > limits.maxAdminKeys) {
    return { error: `the request must name 1 to ${limits.maxAdminKeys} keys` };
  }

  return { keys };
}

/**
 * Names a key of a keyed story by its kind and id, as readLists names it.
 *
 * @param {string} kind The key's kind, one of ADMIN_KINDS.
 * @param {string} id The switch's or variable's id, or the self switch's map.event.letter.
 * @param {typeof STORY_LIMITS} limits The limits.
 * @returns {string | null} The key, such as "s12" or "ss858.139.A", or null when the id is none.
 */
function keyNameOf(kind, id, limits) {
  if (kind === "ss") {
    return SELF_KEY.test(id) ? `ss${id}` : null;
  }

  return /^\d{1,6}$/.test(id) && Number(id) >= 1 && Number(id) <= limits.maxId ? `${kind}${Number(id)}` : null;
}

/**
 * Reads a key as the story names it, such as "s12", "v1201" or "ss858.139.A".
 *
 * @param {unknown} text The key.
 * @param {typeof STORY_LIMITS} limits The limits.
 * @returns {string | null} The key as a keyed story keeps it (ids without leading zeros), or null when it is no switch, variable or self switch.
 */
function keyOfName(text, limits) {
  const [, kind, id] = typeof text === "string" ? /^(ss|s|v)(.+)$/.exec(text) ?? [] : [];
  return kind ? keyNameOf(kind, id, limits) : null;
}

/**
 * Reads the keys an admin pins with their values: each key as the story names it to its value, see
 * keyValueOf.
 *
 * @param {any} named The keys and values.
 * @param {typeof STORY_LIMITS} [limits] The limits.
 * @returns {{keys: Map<string, string>} | {error: string}} The keys with their values as kept, or why they are wrong.
 */
export function readPins(named, limits = STORY_LIMITS) {
  if (!named || typeof named !== "object" || Array.isArray(named)) {
    return { error: "keys must be an object of keys such as s12, v1201 or ss858.139.A and their values" };
  }

  const keys = new Map();

  for (const [name, value] of Object.entries(named)) {
    const key = keyOfName(name, limits);
    const kept = key === null ? null : keyValueOf(key.startsWith("ss") ? "ss" : key[0], value, limits);

    if (kept === null) {
      return { error: `a pin names a switch or self switch with true or false, or a variable with a number, a text, true or false: ${name.slice(0, 40)}` };
    }

    keys.set(key, kept);
  }

  if (keys.size === 0 || keys.size > limits.maxAdminKeys) {
    return { error: `keys must name 1 to ${limits.maxAdminKeys} keys` };
  }

  return { keys };
}

/**
 * Tells the value an admin pinned a key of a keyed story at: its pin with a value, or off for a key
 * the rules an older relay kept name, see pinnedKey.
 *
 * @param {object | undefined} story The story as kept.
 * @param {string} key The key.
 * @returns {string | undefined} The pinned value as kept, undefined for a key no pin holds.
 */
export function pinOf(story, key) {
  return story?.pinned?.[key] ?? (pinnedKey(story?.pins, key) ? OFF_VALUE[key[0]] : undefined);
}

/**
 * Makes the pins of a story as an admin reads them.
 *
 * @param {object | undefined} story The story as kept.
 * @returns {{keys: object, rules: string[]}} `keys`, each pinned key to its value as an admin names it (see keyValueView), and `rules`, the ranges an older relay pinned at off.
 */
export function pinsView(story) {
  return { keys: Object.fromEntries(Object.entries(story?.pinned ?? {}).map(([key, value]) => [key, keyValueView(key, value)])), rules: [...(story?.pins ?? [])] };
}

/**
 * Reports whether an admin's rules, which an older relay kept and pinned at off, pin a key: "s"
 * and "v" rules name switch and variable ids, "ss" rules the maps of self switches, each one id or
 * a range such as "v1201-1218".
 *
 * @param {string[] | undefined} rules The rules.
 * @param {string} key The key, such as "v1201" or "ss858.139.A".
 * @returns {boolean} Whether a rule names it.
 */
export function pinnedKey(rules, key) {
  const [, kind, id] = /^(ss|s|v)(\d+)/.exec(key) ?? [];
  return Boolean(kind) && (rules ?? []).some((rule) => {
    const [, ruleKind, from, to] = /^(ss|s|v)(\d+)(?:-(\d+))?$/.exec(rule) ?? [];
    return ruleKind === kind && Number(id) >= Number(from) && Number(id) <= Number(to ?? from);
  });
}

/**
 * The routes after the Great Decision, by the names the relay and the games use.
 */
export const ROUTE = Object.freeze({ none: "none", ad: "ad", mr: "mr", chaos: "chaos" });

/**
 * The story's ids as MGQOnline.Game's StoryIds holds them, from story_ids.json, which its
 * generator writes.
 */
export { STORY_IDS };

/**
 * The variable of the main story's progress.
 */
export const MAIN_PROGRESS = STORY_IDS.main_progress;

/**
 * Which counter carries how far each route is: `r` and the route's variable.
 */
export const ROUTE_COUNTERS = Object.freeze(Object.fromEntries(STORY_IDS.routes.map((route, index) => [route, `r${STORY_IDS.route_variables[index]}`])));

/**
 * Takes the routes' counters of counters, in the routes' order.
 *
 * @param {object} counters The counters.
 * @param {(name: string) => number} [valueOf] What each counter holds, its value in the counters unless given.
 * @returns {object} Each route's counter by its name, such as `r1141`.
 */
export function routeCounters(counters, valueOf = (name) => counters[name]) {
  return Object.fromEntries(Object.values(ROUTE_COUNTERS).map((name) => [name, valueOf(name)]));
}

/**
 * The parts of the story, in their order: Part 1 and Part 2 by variable 1001, Part 3 up to the
 * Great Decision, then the route chosen.
 */
export const PART = Object.freeze({ one: "1", two: "2", three: "3", ad: "ad", mr: "mr", chaos: "chaos" });

/**
 * The value of the main story's progress each part ends at: Tartarus Escape starts Part 2, the
 * Middle Chapter's epilogue Part 3.
 */
export const PART_ENDS = Object.freeze({ one: STORY_IDS.part_two, two: STORY_IDS.part_three });

/**
 * The value of the main story's progress the Great Decision sets, which every event that takes a
 * route sets too.
 */
export const GREAT_DECISION = STORY_IDS.great_decision;

/**
 * The word the text frame starts with that tells every game of a world its story changed, as
 * `story <rev>`.
 */
export const STORY = "story";

/**
 * The codes a refused request names why with.
 */
export const STORY_REFUSAL = Object.freeze({
  classic: "classic",
  none: "none",
  started: "started",
  pinned: "pinned",
});

/**
 * Writes the text frame that tells every game of a world its story changed.
 *
 * @param {number} rev The story's revision now.
 * @returns {string} The frame, such as "story 12".
 */
export function storyText(rev) {
  return `${STORY} ${rev}`;
}

/**
 * Finds the route whose counter is above 0.
 *
 * @param {{r1141: number, r1142: number, r1143: number}} counters The counters.
 * @returns {string} The route, ROUTE.none when none is.
 */
export function activeRoute(counters) {
  return Object.keys(ROUTE_COUNTERS).find((route) => counters[ROUTE_COUNTERS[route]] > 0) ?? ROUTE.none;
}

/**
 * Tells which part of the story counters are in.
 *
 * @param {{p: number, r1141: number, r1142: number, r1143: number}} counters The counters.
 * @returns {string} The part, one of PART.
 */
export function partOf(counters) {
  const route = activeRoute(counters);

  if (route !== ROUTE.none) {
    return route;
  }

  if (counters.p < PART_ENDS.one) {
    return PART.one;
  }

  return counters.p < PART_ENDS.two ? PART.two : PART.three;
}

/**
 * Places counters in the story's order, which only grows as the story goes on.
 *
 * Variable 1001 alone does not grow: a finished route takes the world back to the Great Decision
 * with 1001 at 39 and the route variables at 0. So the finished routes the world returned from come
 * first, then 1001, then the route's own counter, then whether the route was just finished.
 *
 * @param {{p: number, r1141: number, r1142: number, r1143: number, clear: string[]}} counters The counters.
 * @returns {number[]} The routes returned from, 1001, the route's counter, and the routes finished.
 */
export function storyKey(counters) {
  const route = activeRoute(counters);
  const returned = counters.clear.filter((cleared) => cleared !== route).length;
  const step = route === ROUTE.none ? 0 : counters[ROUTE_COUNTERS[route]];
  return [returned, counters.p, step, counters.clear.length];
}

/**
 * Reports whether the world finished every route, which opens each of them again.
 *
 * A starting save that cleared every route names them all as finished from the first write on, so
 * without this no route could ever be chosen in its world.
 *
 * @param {string[]} done The routes the world finished.
 * @returns {boolean} Whether it finished all of them.
 */
export function everyRouteDone(done) {
  return Object.keys(ROUTE_COUNTERS).every((route) => done.includes(route));
}

/**
 * Compares two places in the story's order.
 *
 * @param {number[]} a One place, see storyKey.
 * @param {number[]} b The other.
 * @returns {number} Below 0 when a comes first, 0 when both are the same, above 0 when b does.
 */
export function compareKeys(a, b) {
  for (let index = 0; index < a.length; index++) {
    if (a[index] !== b[index]) {
      return a[index] - b[index];
    }
  }

  return 0;
}

/**
 * The counters of a world whose story nobody wrote yet.
 */
export const FIRST_COUNTERS = Object.freeze({ p: 0, ...routeCounters({}, () => 0), clear: Object.freeze([]) });

/**
 * The switch each route's finish turns on.
 */
export const CLEAR_SWITCHES = Object.freeze(Object.fromEntries(STORY_IDS.routes.map((route, index) => [route, STORY_IDS.clear_switches[index]])));

/**
 * Reads a keyed story's lists into its keys: `s<id>` and `ss<map>.<event>.<letter>` to "1" or "0",
 * `v<id>` to the variable's value as written, `a<id>` to the companion's affection, `f<troop>` to the
 * frozen raid boss fight as written.
 *
 * @param {unknown} lists The lists, see LISTS, each a text of entries separated by commas, the frozen fights' by semicolons.
 * @param {typeof STORY_LIMITS} [limits] The limits.
 * @returns {{keys: Map<string, string>} | {error: string}} The keys, or why the lists are wrong.
 */
export function readLists(lists, limits = STORY_LIMITS) {
  if (!lists || typeof lists !== "object" || Array.isArray(lists)) {
    return { error: "the story's lists must be a JSON object" };
  }

  if (LISTS.some((name) => lists[name] !== undefined && typeof lists[name] !== "string")) {
    return { error: `the lists ${LISTS.join(", ")} must be texts` };
  }

  if (LISTS.reduce((length, name) => length + (lists[name]?.length ?? 0), 0) > limits.maxListsLength) {
    return { error: `the lists may take at most ${limits.maxListsLength} characters in all` };
  }

  const keys = new Map();
  const items = (name) => (lists[name] ? lists[name].split(name === FREEZES ? ";" : ",") : []);
  const id = (text) => /^\d{1,6}$/.test(text) && Number(text) >= 1 && Number(text) <= limits.maxId;

  for (const [name, value] of [["s", "1"], ["sf", "0"]]) {
    for (const item of items(name)) {
      if (!id(item)) {
        return { error: `${name} lists switch ids of 1 to ${limits.maxId}: ${item.slice(0, 40)}` };
      }

      keys.set(`s${Number(item)}`, value);
    }
  }

  for (const item of items("v")) {
    const split = item.indexOf(":");
    const value = item.slice(split + 1);

    if (split < 1 || !id(item.slice(0, split)) || value.length > limits.maxValueLength || !VALUE.test(value)) {
      return { error: `v lists variable ids of 1 to ${limits.maxId} with their values: ${item.slice(0, 40)}` };
    }

    keys.set(`v${Number(item.slice(0, split))}`, value);
  }

  for (const [name, value] of [["ss", "1"], ["ssf", "0"]]) {
    for (const item of items(name)) {
      if (!SELF_KEY.test(item)) {
        return { error: `${name} lists self switches as map.event.letter: ${item.slice(0, 40)}` };
      }

      keys.set(`ss${item}`, value);
    }
  }

  for (const item of items("a")) {
    const split = item.indexOf(":");
    const value = item.slice(split + 1);

    if (split < 1 || !id(item.slice(0, split)) || !AFFECTION.test(value)) {
      return { error: `a lists companion ids of 1 to ${limits.maxId} with their affection: ${item.slice(0, 40)}` };
    }

    keys.set(`a${Number(item.slice(0, split))}`, value);
  }

  for (const item of items(FREEZES)) {
    const split = item.indexOf("|");
    const value = item.slice(split + 1);

    if (split < 1 || !id(item.slice(0, split)) || value.length > limits.maxFreezeLength || !FREEZE.test(value)) {
      return { error: `f lists troop ids of 1 to ${limits.maxId} with their frozen fight of up to ${limits.maxFreezeLength} characters: ${item.slice(0, 40)}` };
    }

    keys.set(`f${Number(item.slice(0, split))}`, value);
  }

  return { keys };
}

/**
 * Writes keys as a keyed story's lists, each list in the keys' order, see readLists.
 *
 * @param {Iterable<[string, string]>} keys The keys and their values.
 * @returns {{s: string, sf: string, v: string, ss: string, ssf: string, a: string, f: string}} The lists.
 */
export function listsOf(keys) {
  const lists = { s: [], sf: [], v: [], ss: [], ssf: [], a: [], f: [] };

  for (const [key, value] of keys) {
    if (key.startsWith("ss")) {
      lists[value === "1" ? "ss" : "ssf"].push(key.slice(2));
    } else if (key.startsWith("s")) {
      lists[value === "1" ? "s" : "sf"].push(key.slice(1));
    } else if (key.startsWith("a")) {
      lists.a.push(`${key.slice(1)}:${value}`);
    } else if (key.startsWith(FREEZES)) {
      lists.f.push(`${key.slice(1)}|${value}`);
    } else {
      lists.v.push(`${key.slice(1)}:${value}`);
    }
  }

  return Object.fromEntries(LISTS.map((name) => [name, lists[name].join(name === FREEZES ? ";" : ",")]));
}

/**
 * Reads a keyed story's counters from its keys: variable 1001, the route variables and the routes'
 * clear switches; a counter the keys lack keeps the write's.
 *
 * @param {Map<string, string>} keys The story's keys.
 * @param {{p: number, r1141: number, r1142: number, r1143: number, clear: string[]}} fallback The write's counters.
 * @returns {{p: number, r1141: number, r1142: number, r1143: number, clear: string[]}} The counters.
 */
export function countersOf(keys, fallback) {
  const whole = (name, kept) => {
    const value = keys.get(`v${name}`);
    return value && /^n\d+$/.test(value) ? Number(value.slice(1)) : kept;
  };
  const clear = Object.keys(CLEAR_SWITCHES).filter((route) => {
    const value = keys.get(`s${CLEAR_SWITCHES[route]}`);
    return value === undefined ? fallback.clear.includes(route) : value === "1";
  });
  const routes = Object.values(ROUTE_COUNTERS).map((counter) => [counter, whole(counter.slice(1), fallback[counter])]);
  return { p: whole(MAIN_PROGRESS, fallback.p), ...Object.fromEntries(routes), clear };
}

/**
 * @typedef {object} StoryStore Where one world's story is kept: the story with its counters, and one checkpoint per part.
 * @property {() => Promise<object | undefined>} get Reads the story, undefined before the first write.
 * @property {(story: object, checkpoint: object | null) => Promise<void>} put Writes the story, and a checkpoint with it, in one step where the platform allows.
 * @property {(part: string) => Promise<object | undefined>} getCheckpoint Reads a part's checkpoint.
 * @property {() => Promise<void>} remove Deletes the story and its checkpoints.
 */

/**
 * One Raid World's story, over a store of its own.
 */
export class WorldStory {
  /**
   * Creates the story.
   *
   * @param {StoryStore} store Where the story is kept.
   * @param {{clock?: () => number, limits?: typeof STORY_LIMITS}} [options] The clock and limits, which tests change.
   */
  constructor(store, { clock = Date.now, limits = STORY_LIMITS } = {}) {
    this.store = store;
    this.clock = clock;
    this.limits = limits;
    this.exclusive = workQueue();
  }

  /**
   * Hands out what games read of the story: its revision and the shared companions.
   *
   * @returns {Promise<{status: number, body: {rev: number, comps: number[]}}>} The answer.
   */
  async get() {
    return this.exclusive(async () => ({ status: 200, body: sharedOf(await this.store.get()) }));
  }

  /**
   * Keeps pins as an admin asks, which the world's track holds: the story's keys stay as they are.
   * A key pinned again takes its new value.
   *
   * @param {any} request `keys`, each key as the story names it ("s12", "v1201", "ss858.139.A") to its value, see readPins.
   * @returns {Promise<{status: number, body: object}>} `pins`, see pinsView; or why the request is wrong.
   */
  async keepPins(request) {
    const read = readPins(request?.keys, this.limits);

    if (read.error) {
      return badRequest(read.error);
    }

    return this.exclusive(async () => {
      const story = (await this.store.get()) ?? this.first();
      const pinned = { ...(story.pinned ?? {}), ...Object.fromEntries(read.keys) };

      if (Object.keys(pinned).length > this.limits.maxPins) {
        return { status: 413, body: { error: `a story keeps at most ${this.limits.maxPins} pinned keys` } };
      }

      const next = { ...story, pinned };
      await this.store.put(next, null);
      return { status: 200, body: { pins: pinsView(next) } };
    });
  }

  /**
   * Takes pins off, as an admin asks, so writes change those keys again; the keys keep their
   * values until a write changes them.
   *
   * @param {any} request `keys`, the keys as the story names them, or rules an older relay kept (such as "v1201-1218"), each as kept.
   * @returns {Promise<{status: number, body: object}>} `cleared` (the keys and rules taken off) and `pins`, see pinsView; or 409 with code `none` for a world without a story; or why the request is wrong.
   */
  async clearPins(request) {
    const named = request?.keys;

    if (!Array.isArray(named) || named.length === 0 || named.length > this.limits.maxAdminKeys || !named.every((key) => typeof key === "string")) {
      return badRequest(`keys must list 1 to ${this.limits.maxAdminKeys} pinned keys`);
    }

    return this.exclusive(async () => {
      const story = await this.store.get();

      if (!story) {
        return { status: 409, body: { error: "the world has no story to take pins off", code: STORY_REFUSAL.none } };
      }

      const pinned = { ...(story.pinned ?? {}) };
      const rules = [...(story.pins ?? [])];
      const cleared = [];

      for (const text of named) {
        const key = keyOfName(text, this.limits) ?? text;

        if (key in pinned) {
          delete pinned[key];
          cleared.push(key);
        } else if (rules.includes(text)) {
          rules.splice(rules.indexOf(text), 1);
          cleared.push(text);
        }
      }

      const next = { ...story, pinned, pins: rules };
      await this.store.put(next, null);
      return { status: 200, body: { cleared, pins: pinsView(next) } };
    });
  }

  /**
   * Adds companions to the world's shared list, which only grows.
   *
   * @param {any} ids The companions' actor ids.
   * @returns {Promise<{status: number, body: object, push?: number}>} The revision and the companions, see get, and the revision to tell every game when the list grew; or why the ids are wrong.
   */
  async addCompanions(ids) {
    const actor = (id) => Number.isInteger(id) && id >= 1 && id <= this.limits.maxActorId;

    if (!Array.isArray(ids) || ids.length === 0 || ids.length > this.limits.maxCompanionsPerAdd || !ids.every(actor)) {
      return badRequest(`ids must list 1 to ${this.limits.maxCompanionsPerAdd} actor ids of 1 to ${this.limits.maxActorId}`);
    }

    return this.exclusive(async () => {
      const story = await this.store.get();
      const comps = new Set(story?.comps ?? []);
      const before = comps.size;

      for (const id of ids) {
        comps.add(id);
      }

      if (comps.size > this.limits.maxCompanions) {
        return { status: 413, body: { error: `the world shares at most ${this.limits.maxCompanions} companions` } };
      }

      if (comps.size === before) {
        return { status: 200, body: sharedOf(story) };
      }

      const next = { ...(story ?? this.first()), comps: [...comps].sort((a, b) => a - b), rev: (story?.rev ?? 0) + 1 };
      await this.store.put(next, null);
      return { status: 200, body: sharedOf(next), push: next.rev };
    });
  }

  /**
   * Reads the story as kept, for what only admins see of it, such as its pins.
   *
   * @returns {Promise<object | undefined>} The story, undefined before the first write.
   */
  async kept() {
    return this.exclusive(() => this.store.get());
  }

  /**
   * Reads a keyed story's keys, which the world's story tracks start from.
   *
   * @returns {Promise<Map<string, string> | undefined>} The keys, see readLists; undefined before the first write key by key.
   */
  async keys() {
    const story = await this.kept();
    return story?.lists ? readLists(story.lists, this.limits).keys : undefined;
  }

  /**
   * Deletes the story and its checkpoints, as when the world is deleted.
   *
   * @returns {Promise<void>} Completes once deleted.
   */
  remove() {
    return this.exclusive(() => this.store.remove());
  }

  /**
   * Makes the story of a world nobody wrote yet, for a pin or a companion that comes first.
   *
   * @returns {object} The story, at revision 0 without keys.
   */
  first() {
    return { rev: 0, wrev: 0, counters: { ...FIRST_COUNTERS, clear: [] }, part: PART.one, route: ROUTE.none, done: [], end: null, comps: [], caps: [], checkpoints: [], at: this.clock(), by: null };
  }

}


/**
 * Makes what games read of the story.
 *
 * @param {object | undefined} story The story as kept, undefined before the first write.
 * @returns {{rev: number, comps: number[]}} Its revision, which every change counts up, and the shared companions.
 */
function sharedOf(story) {
  return { rev: story?.rev ?? 0, comps: [...(story?.comps ?? [])] };
}

/**
 * Reads which world and story route an address names.
 *
 * @param {URL} url The request's address.
 * @returns {{id: string, rest: string[]} | null} The world and the parts after `story`, or null when it is no story route.
 */
export function storyRouteOf(url) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);
  return parts.length >= 4 && parts[0] === VERSION && parts[1] === "worlds" && isId(parts[2]) && parts[3] === STORY ? { id: parts[2], rest: parts.slice(4) } : null;
}

/**
 * Answers a request to a world's story routes, once the platform layer found the asking game to be
 * a player of that Raid World.
 *
 * @param {WorldStory} story The world's story.
 * @param {string} method The HTTP method.
 * @param {string[]} rest The address's parts after `story`, see storyRouteOf.
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when it is too large to read.
 * @returns {Promise<{status: number, body: object, push?: number}>} The answer, and the revision to tell every game of the world when the story changed, see storyText.
 */
export async function handleStoryRequest(story, method, rest, readBody) {
  if (rest.length === 0 && method === "GET") {
    return story.get();
  }

  if (rest.length === 1 && rest[0] === "companions" && method === "POST") {
    return withJson(readBody, story.limits.maxSmallBodyLength, (body) => story.addCompanions(body?.ids));
  }

  return notFound("route");
}

/**
 * The answer for a story route of a world that is no Raid World.
 *
 * @returns {{status: number, body: object}} The answer.
 */
export function noRaidWorld() {
  return { status: 404, body: { error: "the world is no Raid World, which alone keeps a story here", code: STORY_REFUSAL.classic } };
}

