//----------------------------------------------------------------
//  story.js
//
//  Changelog:
//      Paulinchen  2026-10-15: Kept a Raid World's story key by key, the first writer of a key keeping it, and pushed what each write changed
//                            - Moved a sealed story to keys with the first write of a game that opened it
//                            - Refused sealed writes to a keyed story with the code update
//                            - Told a keyed write whether other writes changed keys since its base
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

// The story of a Raid World, which the whole world plays together: a few counters the relay reads
// to tell which story is further, and the story itself key by key, each switch, variable and self
// switch, so the relay pushes what a write changed to every game at once. The furthest story wins,
// and each write names the revision it built on: of two games writing the same key at once, the
// first keeps it. Released games keep the story sealed with a key from the world's token, which the
// relay only keeps until a game that keeps keys opened it and wrote it as keys.

import { badRequest, notFound, withJson } from "./http.js";
import { isId } from "./ids.js";
import { RateLimiter, VERSION } from "./relay.js";

/**
 * The limits a world's story keeps.
 */
export const STORY_LIMITS = Object.freeze({
  // The sealed story in base64: 200 KB of story, sealed, fits.
  maxBlobLength: 280_000,
  // A write's whole JSON body: the sealed story or the lists of a keyed story's first write, and
  // the counters.
  maxBodyLength: 1_900_000,
  // The JSON body of a route lock or a companions list.
  maxSmallBodyLength: 32 * 1024,
  maxCompanions: 2000,
  maxCompanionsPerAdd: 500,
  maxActorId: 99_999,
  maxCounter: 1_000_000,
  maxMapId: 9999,
  maxTile: 9999,
  maxCaps: 200,
  maxCap: 9999,
  // Story writes per player: a burst, then one more every few seconds, so a game stuck in a loop
  // cannot spend the free plan's daily writes.
  writes: Object.freeze({ burst: 20, refillMs: 3 * 1000 }),
  // A keyed story's lists: all of them together, a late story's thousands of switches, variables
  // and self switches with room to spare, and the longest value a variable may hold.
  maxListsLength: 1_800_000,
  maxValueLength: 4096,
  maxId: 99_999,
  // The keys of the writes a keyed story remembers, which tell what changed since an older base.
  logKeys: 20_000,
  logWrites: 200,
  // The longest push of a write's changed keys; a longer one tells the revision alone.
  maxDeltaLength: 60_000,
});

/**
 * What a game names in X-MGQ-Features once it keeps a Raid World's story key by key. A world whose
 * story is keyed turns away games that do not.
 */
export const STORY_FEATURE = "keys";

/**
 * The word the text frame starts with that hands every game of a world what a write changed, as
 * `storyd <JSON>`.
 */
export const STORY_DELTA = "storyd";

/**
 * The lists a keyed story travels in: the switches on and off, the variables with their values, and
 * the self switches on and off, as the games write a story (story_state.rbx `story_lists`).
 */
export const LISTS = Object.freeze(["s", "sf", "v", "ss", "ssf"]);

/**
 * A variable's value as the games write it: a whole number, a decimal, a text in base64, true or
 * false (story_state.rbx `encode_value`).
 */
const VALUE = /^(n-?\d+|f-?\d+(\.\d+)?(e[-+]?\d+)?|s[A-Za-z0-9+/=]*|T|F)$/;

/**
 * A self switch's key: its map, its event and its letter.
 */
const SELF_KEY = /^(\d{1,5})\.(\d{1,6})\.([A-Za-z0-9_]{1,8})$/;

/**
 * The routes after the Great Decision, by the names the relay and the games use.
 */
export const ROUTE = Object.freeze({ none: "none", ad: "ad", mr: "mr", chaos: "chaos" });

/**
 * Which counter carries how far each route is: variables 1141 (Angelic Dominion), 1142 (Monster
 * Realm) and 1143 (Chaos).
 */
export const ROUTE_COUNTERS = Object.freeze({ ad: "r1141", mr: "r1142", chaos: "r1143" });

/**
 * The parts of the story, in their order: Part 1 and Part 2 by variable 1001, Part 3 up to the
 * Great Decision, then the route chosen.
 */
export const PART = Object.freeze({ one: "1", two: "2", three: "3", ad: "ad", mr: "mr", chaos: "chaos" });

/**
 * The value of variable 1001 each part ends at: Tartarus Escape sets 19, the Middle Chapter's
 * epilogue 34.
 */
export const PART_ENDS = Object.freeze({ one: 19, two: 34 });

/**
 * The value of variable 1001 the Great Decision sets, which every event that takes a route sets too.
 */
export const GREAT_DECISION = 40;

/**
 * The word the text frame starts with that tells every game of a world its story changed, as
 * `story <rev>`.
 */
export const STORY = "story";

/**
 * The codes a refused write or lock names why with.
 */
export const STORY_REFUSAL = Object.freeze({
  rev: "rev",
  behind: "behind",
  route: "route",
  finished: "finished",
  closed: "closed",
  classic: "classic",
  none: "none",
  rate: "rate",
  started: "started",
  update: "update",
});

/**
 * Base64 text.
 */
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

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
 * Reports whether counters name a route under way before the Great Decision, which no game tells:
 * every event that takes a route moves variable 1001 to the decision too.
 *
 * @param {{p: number, r1141: number, r1142: number, r1143: number}} counters The counters.
 * @returns {boolean} Whether they do.
 */
export function outOfOrder(counters) {
  return activeRoute(counters) !== ROUTE.none && counters.p < GREAT_DECISION;
}

/**
 * Reads counters as the story they can be: a route under way before the Great Decision, which an
 * older game wrote, as none, so a write without it goes on from there.
 *
 * @param {{p: number, r1141: number, r1142: number, r1143: number, clear: string[]}} counters The counters.
 * @returns {{p: number, r1141: number, r1142: number, r1143: number, clear: string[]}} The counters, the same object when in order.
 */
export function inOrder(counters) {
  return outOfOrder(counters) ? { ...counters, r1141: 0, r1142: 0, r1143: 0 } : counters;
}

/**
 * Reports whether a story's route lock came with a route under way before the Great Decision, see
 * outOfOrder, and goes with it.
 *
 * @param {object | undefined} story The story as kept.
 * @returns {string} The route locked, ROUTE.none when none is or the lock goes.
 */
function lockOf(story) {
  const locked = story?.route ?? ROUTE.none;
  return story && outOfOrder(story.counters) && locked === activeRoute(story.counters) ? ROUTE.none : locked;
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
 * Reads the counters of a write.
 *
 * @param {any} counters The counters as sent: `p`, `r1141`, `r1142`, `r1143`, `clear`, and maybe `end` and `caps`.
 * @param {typeof STORY_LIMITS} [limits] The limits.
 * @returns {{counters: {p: number, r1141: number, r1142: number, r1143: number, clear: string[]}, end: object | null | undefined, caps: number[]} | {error: string}} The counters, the endpoint (null to clear it, undefined to keep it) and the level caps the story unlocked; or what is wrong.
 */
export function readCounters(counters, limits = STORY_LIMITS) {
  if (!counters || typeof counters !== "object") {
    return { error: "the counters must be a JSON object" };
  }

  const counter = (value) => Number.isInteger(value) && value >= 0 && value <= limits.maxCounter;

  if (!["p", "r1141", "r1142", "r1143"].every((name) => counter(counters[name]))) {
    return { error: `p, r1141, r1142 and r1143 must be whole numbers of 0 to ${limits.maxCounter}` };
  }

  const routes = Object.keys(ROUTE_COUNTERS);
  const clear = counters.clear ?? [];

  if (!Array.isArray(clear) || clear.some((route) => !routes.includes(route)) || new Set(clear).size !== clear.length) {
    return { error: `clear must list finished routes of ${routes.join(", ")}, each once` };
  }

  if (routes.filter((route) => counters[ROUTE_COUNTERS[route]] > 0).length > 1) {
    return { error: "at most one route's counter may be above 0" };
  }

  const end = readEnd(counters.end, limits);

  if (end === false) {
    return { error: `end must be null or map, x and y as whole numbers, the map 1 to ${limits.maxMapId}` };
  }

  const caps = counters.caps ?? [];

  if (!Array.isArray(caps) || caps.length > limits.maxCaps || !caps.every((cap) => Number.isInteger(cap) && cap >= 1 && cap <= limits.maxCap)) {
    return { error: `caps must list at most ${limits.maxCaps} level caps of 1 to ${limits.maxCap}` };
  }

  // Kept in the routes' own order, so the same finished routes always read the same.
  return { counters: { p: counters.p, r1141: counters.r1141, r1142: counters.r1142, r1143: counters.r1143, clear: routes.filter((route) => clear.includes(route)) }, end, caps };
}

/**
 * Adds level caps to those a world's story unlocked.
 *
 * @param {number[]} kept The caps kept so far.
 * @param {number[]} added The caps a write names.
 * @returns {number[]} Every cap once, lowest first.
 */
export function mergeCaps(kept, added) {
  return [...new Set([...kept, ...added])].sort((a, b) => a - b);
}

/**
 * Reads the story's endpoint, where the last story teleport went.
 *
 * @param {any} end The endpoint as sent.
 * @param {typeof STORY_LIMITS} limits The limits.
 * @returns {{map: number, x: number, y: number} | null | undefined | false} The endpoint, null to clear it, undefined to keep it, or false when it is wrong.
 */
function readEnd(end, limits) {
  if (end === undefined || end === null) {
    return end;
  }

  const tile = (value) => Number.isInteger(value) && value >= 0 && value <= limits.maxTile;

  if (typeof end !== "object" || !Number.isInteger(end.map) || end.map < 1 || end.map > limits.maxMapId || !tile(end.x) || !tile(end.y)) {
    return false;
  }

  return { map: end.map, x: end.x, y: end.y };
}

/**
 * The counters of a world whose story nobody wrote yet.
 */
const FIRST_COUNTERS = Object.freeze({ p: 0, r1141: 0, r1142: 0, r1143: 0, clear: Object.freeze([]) });

/**
 * The switch each route's finish turns on: 7096 Angelic Dominion, 7097 Monster Realm, 7039 Chaos.
 */
const CLEAR_SWITCHES = Object.freeze({ ad: 7096, mr: 7097, chaos: 7039 });

/**
 * Reads a keyed story's lists into its keys: `s<id>` and `ss<map>.<event>.<letter>` to "1" or "0",
 * `v<id>` to the variable's value as written.
 *
 * @param {unknown} lists The lists, see LISTS, each a text of entries separated by commas.
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
  const items = (name) => (lists[name] ? lists[name].split(",") : []);
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

  return { keys };
}

/**
 * Writes keys as a keyed story's lists, each list in the keys' order, see readLists.
 *
 * @param {Iterable<[string, string]>} keys The keys and their values.
 * @returns {{s: string, sf: string, v: string, ss: string, ssf: string}} The lists.
 */
export function listsOf(keys) {
  const lists = { s: [], sf: [], v: [], ss: [], ssf: [] };

  for (const [key, value] of keys) {
    if (key.startsWith("ss")) {
      lists[value === "1" ? "ss" : "ssf"].push(key.slice(2));
    } else if (key.startsWith("s")) {
      lists[value === "1" ? "s" : "sf"].push(key.slice(1));
    } else {
      lists.v.push(`${key.slice(1)}:${value}`);
    }
  }

  return Object.fromEntries(LISTS.map((name) => [name, lists[name].join(",")]));
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
  return { p: whole(1001, fallback.p), r1141: whole(1141, fallback.r1141), r1142: whole(1142, fallback.r1142), r1143: whole(1143, fallback.r1143), clear };
}

/**
 * Lists the keys the writes after a revision changed, as a keyed story's log of writes holds them.
 *
 * @param {{rev: number, keys: string[]}[]} log The log, oldest first.
 * @param {number} base The revision.
 * @returns {Set<string>} The keys.
 */
function changedSince(log, base) {
  const keys = new Set();

  for (const entry of log) {
    if (entry.rev > base) {
      entry.keys.forEach((key) => keys.add(key));
    }
  }

  return keys;
}

/**
 * Writes the text frame that tells every game of a world its story changed: what a write changed
 * with the state after it (`storyd <JSON>`, see STORY_DELTA), or the revision alone, which the games
 * fetch (`story <rev>`), for a sealed story or a change too long for a frame.
 *
 * @param {number | {rev: number, prev: number, delta: object, state: object}} push The revision, or the change.
 * @param {typeof STORY_LIMITS} [limits] The limits.
 * @returns {string} The frame.
 */
export function storyPushText(push, limits = STORY_LIMITS) {
  if (typeof push === "number") {
    return storyText(push);
  }

  const text = `${STORY_DELTA} ${JSON.stringify(push)}`;
  return text.length <= limits.maxDeltaLength ? text : storyText(push.rev);
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
    this.writes = new RateLimiter(limits.writes, clock);
    this.queue = Promise.resolve();
  }

  /**
   * Hands out the story as it stands.
   *
   * @param {number | null} [known] The revision the asking game knows, which a keyed story at that
   *   revision answers without its lists.
   * @returns {Promise<{status: number, body: object}>} The story's state with its story, see stateOf; with `same` and without the story for the known revision.
   */
  async get(known = null) {
    return this.exclusive(async () => {
      const story = await this.store.get();
      return story?.lists && known === story.rev ? { status: 200, body: { ...stateOf(story, false), same: true } } : { status: 200, body: stateOf(story, true) };
    });
  }

  /**
   * Hands out a part's checkpoint: the story as it stood right before the write that first moved
   * the world past that part.
   *
   * @param {unknown} part The part, one of PART.
   * @returns {Promise<{status: number, body: object}>} The checkpoint's state with its sealed story, or 404 with code `none`.
   */
  async checkpoint(part) {
    if (!Object.values(PART).includes(part)) {
      return badRequest(`the part must be one of ${Object.values(PART).join(", ")}`);
    }

    // A checkpoint a repair dropped (see write) stays stored until the part ends again.
    const checkpoint = await this.exclusive(async () => (((await this.store.get())?.checkpoints ?? []).includes(part) ? this.store.getCheckpoint(part) : undefined));
    return checkpoint ? { status: 200, body: { ...stateOf(checkpoint, true), part } } : { status: 404, body: { error: "the world has no checkpoint of this part", code: STORY_REFUSAL.none } };
  }

  /**
   * Takes a game's write of the story: accepted when it built on the story as it stands and its
   * counters are not behind the story's.
   *
   * @param {string} player The writing player's id.
   * @param {any} request The write: `base`, the revision it built on, any from the last write's on (0 before the first); `counters`, see readCounters; and `blob`, the sealed story in base64.
   * @returns {Promise<{status: number, body: object, push?: number}>} The new state with `accepted`, and the revision to tell every game; or 409 with the state as it stands, its sealed story and a code, `update` for a keyed story; or why the write is wrong.
   */
  async write(player, request) {
    if (!request || typeof request !== "object") {
      return badRequest("the write must be a JSON object");
    }

    if (request.set !== undefined) {
      return this.writeKeys(player, request);
    }

    if (!Number.isInteger(request.base) || request.base < 0) {
      return badRequest("base must be the revision the write built on, 0 before the first");
    }

    if (typeof request.blob !== "string" || request.blob.length === 0 || request.blob.length > this.limits.maxBlobLength || !BASE64.test(request.blob)) {
      return badRequest(`the blob must be base64 of 1 to ${this.limits.maxBlobLength} characters`);
    }

    const read = readCounters(request.counters, this.limits);

    if (read.error) {
      return badRequest(read.error);
    }

    if (!this.writes.take(player)) {
      return { status: 429, body: { error: "the story is written too often, try again later", code: STORY_REFUSAL.rate } };
    }

    return this.exclusive(async () => {
      const story = await this.store.get();

      // A keyed story is no sealed story the game could build on: its game must update.
      if (story?.lists) {
        return { status: 409, body: { ...stateOf(story, false), error: "the world keeps its story key by key, which this game does not", code: STORY_REFUSAL.update } };
      }

      const refusal = this.refusalOf(story, request.base, read.counters);

      if (refusal) {
        return { status: 409, body: { ...stateOf(story, true), error: refusal.error, code: refusal.code } };
      }

      const { next, checkpoint } = this.advance(story, read, player);
      next.blob = request.blob;
      await this.store.put(next, checkpoint);
      return { status: 200, body: { ...stateOf(next, false), accepted: true }, push: next.rev };
    });
  }

  /**
   * Takes a game's write of a keyed story, the keys it changed in the lists `set`: each one goes in
   * unless a write after the revision it built on changed it, which the first writer keeps. A write
   * on a sealed story the game opened moves the world to keys, the sealed story's revision its base;
   * a story nobody wrote yet starts keyed.
   *
   * @param {string} player The writing player's id.
   * @param {any} request The write: `base`, the revision it built on; `counters`, see readCounters; and `set`, the lists of the keys it changed, see readLists.
   * @returns {Promise<{status: number, body: object, push?: object}>} The new state with `accepted`, `kept` (the lists of the keys the world kept, with their values) and `moved` (whether other writes changed keys since the base), and the change to tell every game, see storyPushText; or 409 with the state as it stands, its story and a code; or why the write is wrong.
   */
  async writeKeys(player, request) {
    if (!Number.isInteger(request.base) || request.base < 0) {
      return badRequest("base must be the revision the write built on, 0 before the first");
    }

    const lists = readLists(request.set, this.limits);

    if (lists.error) {
      return badRequest(lists.error);
    }

    const read = readCounters(request.counters, this.limits);

    if (read.error) {
      return badRequest(read.error);
    }

    if (!this.writes.take(player)) {
      return { status: 429, body: { error: "the story is written too often, try again later", code: STORY_REFUSAL.rate } };
    }

    return this.exclusive(async () => {
      const story = await this.store.get();
      const keyed = Boolean(story?.lists);
      // The log tells what changed after a base only from where it starts: before it, and on a
      // sealed story but its own revision, the game must take the story as it stands first.
      const oldest = keyed ? story.logBase : (story?.rev ?? 0);

      if (request.base < oldest || request.base > (story?.rev ?? 0)) {
        return { status: 409, body: { ...stateOf(story, true), error: "the story moved on since the revision the write built on", code: STORY_REFUSAL.rev } };
      }

      const refusal = this.refusalOf(story, request.base, read.counters, false);

      if (refusal) {
        return { status: 409, body: { ...stateOf(story, true), error: refusal.error, code: refusal.code } };
      }

      const keys = keyed ? readLists(story.lists, { ...this.limits, maxListsLength: Infinity }).keys : new Map();
      const changed = keyed ? changedSince(story.log, request.base) : new Set();
      const applied = new Map();
      const kept = new Map();

      for (const [key, value] of lists.keys) {
        if (keys.get(key) === value) {
          continue;
        }

        if (changed.has(key)) {
          kept.set(key, keys.get(key));
          continue;
        }

        keys.set(key, value);
        applied.set(key, value);
      }

      const stored = listsOf(keys);

      if (LISTS.reduce((length, name) => length + stored[name].length, 0) > this.limits.maxListsLength) {
        return { status: 413, body: { error: `the story's lists may take at most ${this.limits.maxListsLength} characters in all` } };
      }

      const { next, checkpoint } = this.advance(story, { ...read, counters: countersOf(keys, read.counters) }, player);
      const log = keyed ? [...story.log, { rev: next.rev, keys: [...applied.keys()] }] : [];
      let logBase = keyed ? story.logBase : next.rev;

      while (log.length > this.limits.logWrites || log.reduce((count, entry) => count + entry.keys.length, 0) > this.limits.logKeys) {
        logBase = log.shift().rev;
      }

      Object.assign(next, { blob: "", lists: stored, log, logBase });
      await this.store.put(next, checkpoint);
      const push = { rev: next.rev, prev: story?.rev ?? 0, delta: listsOf(applied), state: stateOf(next, false) };
      // Whether other writes changed keys since the base, which the writing game lacks then.
      return { status: 200, body: { ...stateOf(next, false), accepted: true, kept: listsOf(kept), moved: changed.size > 0 }, push };
    });
  }

  /**
   * Makes the story a write leaves: its counters, the routes it finished, the route lock, the part,
   * the endpoint, the level caps, and the checkpoint of the part it first left. Called inside
   * exclusive.
   *
   * @param {object | undefined} story The story as it stands.
   * @param {{counters: object, end: object | null | undefined, caps: number[]}} read The write's counters, endpoint and caps, see readCounters.
   * @param {string} player The writing player's id.
   * @returns {{next: object, checkpoint: object | null}} The story without its sealed story or lists, and the checkpoint to keep, null for none.
   */
  advance(story, read, player) {
    const route = activeRoute(read.counters);
    // A story an older game wrote with a route under way before the Great Decision: the level caps
    // it named and the checkpoint of the part it seemed to leave go with it.
    const repaired = story && outOfOrder(story.counters);
    const done = [...(story?.done ?? [])];

    for (const cleared of read.counters.clear) {
      if (!done.includes(cleared)) {
        done.push(cleared);
      }
    }

    const locked = lockOf(story);
    // Once every route was finished the locked one is finished from the start, so the lock ends
    // only with the return from it, not with the first write that has no route under way.
    const returned = done.includes(locked) && (!(story?.done ?? []).includes(locked) || activeRoute(inOrder(story?.counters ?? FIRST_COUNTERS)) === locked);
    const part = partOf(read.counters);
    // Only a part's first end is its checkpoint: the world leaves Part 3 once for every route,
    // and a later end would hand a player behind a story that already finished a route.
    const written = story?.lists || story?.blob;
    const checkpoint = written && !repaired && story.part !== part && !story.checkpoints.includes(story.part) ? checkpointOf(story) : null;
    const checkpoints = checkpoint ? [...story.checkpoints, story.part] : (story?.checkpoints ?? []).filter((kept) => !(repaired && kept === part));

    const rev = (story?.rev ?? 0) + 1;
    const next = {
      rev,
      wrev: rev,
      counters: read.counters,
      part,
      route: route !== ROUTE.none ? route : returned ? ROUTE.none : locked,
      done,
      end: read.end === undefined ? (story?.end ?? null) : read.end,
      comps: story?.comps ?? [],
      caps: mergeCaps(repaired ? [] : (story?.caps ?? []), read.caps).slice(-this.limits.maxCaps),
      checkpoints,
      at: this.clock(),
      by: player,
    };
    return { next, checkpoint };
  }

  /**
   * Tells every game what a change of the story that left its keys as they were made of it: the
   * state alone for a keyed story, the revision for a sealed one.
   *
   * @param {object | undefined} story The story before.
   * @param {object} next The story after.
   * @returns {number | object} The push, see storyPushText.
   */
  pushOf(story, next) {
    return next.lists ? { rev: next.rev, prev: story?.rev ?? 0, delta: listsOf([]), state: stateOf(next, false) } : next.rev;
  }

  /**
   * Tells why a write may not replace the story. Called inside exclusive.
   *
   * @param {object | undefined} story The story as it stands.
   * @param {number} base The revision the write built on.
   * @param {object} counters The write's counters.
   * @param {boolean} [sealed] Whether the write replaces a sealed story, which only a revision from its last write on may.
   * @returns {{error: string, code: string} | null} Why not, or null when it may.
   */
  refusalOf(story, base, counters, sealed = true) {
    // Any revision from the last write on saw the sealed story as it stands.
    if (sealed && (base < (story?.wrev ?? 0) || base > (story?.rev ?? 0))) {
      return { error: "the story moved on since the revision the write built on", code: STORY_REFUSAL.rev };
    }

    if (outOfOrder(counters)) {
      return { error: "a route cannot be under way before the Great Decision", code: STORY_REFUSAL.behind };
    }

    const route = activeRoute(counters);
    const kept = story && inOrder(story.counters);
    const locked = lockOf(story);
    const done = story?.done ?? [];
    // The locked route's first step from the Great Decision is taken whatever its key: once every
    // route was finished, a route under way no longer counts as returned from, so it ranks below
    // the decision.
    const firstStep = story && locked !== ROUTE.none && route === locked && activeRoute(kept) === ROUTE.none;

    if (story && !firstStep && compareKeys(storyKey(counters), storyKey(kept)) < 0) {
      return { error: "the write is behind the world's story", code: STORY_REFUSAL.behind };
    }

    if (locked === ROUTE.none) {
      return null;
    }

    // While a route is under way only that route, or the return from it, goes on: a write from
    // another story would throw the route's progress away or finish routes the world never played.
    // Until the world's own story is on the locked route, a story with no route under way goes on
    // too, since the player who locked it writes its first step only once their scene ended.
    const started = activeRoute(kept) === locked;
    const onLocked = route === locked || (route === ROUTE.none && (counters.clear.includes(locked) || !started));
    const unplayed = counters.clear.some((cleared) => cleared !== locked && !done.includes(cleared));

    if (!onLocked || unplayed) {
      return { error: "another route was chosen first", code: STORY_REFUSAL.route };
    }

    return null;
  }

  /**
   * Locks the route the world takes at the Great Decision: the first route chosen wins, until the
   * world finished it and returned to the Great Decision. Once the world finished every route, each
   * may be chosen again.
   *
   * @param {any} route The route, one of ROUTE but none.
   * @returns {Promise<{status: number, body: object, push?: number | object}>} The state with `locked` (the same route again answers the same), and the change to tell every game when it changed, see storyPushText; or 409 with the state and code `route` when another route is locked or the world's story is on another route, `finished` for a route the world finished while another is not, `closed` for Chaos before both other routes are finished.
   */
  async lockRoute(route) {
    if (!Object.keys(ROUTE_COUNTERS).includes(route)) {
      return badRequest(`the route must be one of ${Object.keys(ROUTE_COUNTERS).join(", ")}`);
    }

    return this.exclusive(async () => {
      const story = await this.store.get();
      const locked = story?.route ?? ROUTE.none;
      const done = story?.done ?? [];
      const refuse = (error, code) => ({ status: 409, body: { ...stateOf(story, true), error, code } });

      if (locked === route) {
        return { status: 200, body: { ...stateOf(story, true), locked: route } };
      }

      const running = activeRoute(story?.counters ?? FIRST_COUNTERS);

      if (locked !== ROUTE.none || (running !== ROUTE.none && running !== route)) {
        return refuse("another route was chosen first", STORY_REFUSAL.route);
      }

      if (!everyRouteDone(done) && done.includes(route)) {
        return refuse("the world finished this route", STORY_REFUSAL.finished);
      }

      if (route === ROUTE.chaos &&!(done.includes(ROUTE.ad) && done.includes(ROUTE.mr))) {
        return refuse("the third way opens once both other routes are finished", STORY_REFUSAL.closed);
      }

      const next = { ...(story ?? this.first()), route, rev: (story?.rev ?? 0) + 1 };
      await this.store.put(next, null);
      return { status: 200, body: { ...stateOf(next, true), locked: route }, push: this.pushOf(story, next) };
    });
  }

  /**
   * Takes back the route locked at the Great Decision, as an admin asks, so the next player who
   * chooses sets it again. Refused while the world's story is on the locked route, since another
   * route locked then would turn away every write of both routes.
   *
   * @returns {Promise<{status: number, body: object, push?: number | object}>} The state with `cleared` (whether a route was locked), and the change to tell every game when it changed, see storyPushText; or 409 with the state and code `started` while the world's story is on the locked route.
   */
  async clearRoute() {
    return this.exclusive(async () => {
      const story = await this.store.get();
      const locked = story?.route ?? ROUTE.none;

      if (locked === ROUTE.none) {
        return { status: 200, body: { ...stateOf(story, false), cleared: false } };
      }

      if (activeRoute(story.counters) === locked) {
        return { status: 409, body: { ...stateOf(story, false), error: "the world's story is on the locked route already", code: STORY_REFUSAL.started } };
      }

      const next = { ...story, route: ROUTE.none, rev: story.rev + 1 };
      await this.store.put(next, null);
      return { status: 200, body: { ...stateOf(next, false), cleared: true }, push: this.pushOf(story, next) };
    });
  }

  /**
   * Adds companions to the world's shared list, which only grows.
   *
   * @param {any} ids The companions' actor ids.
   * @returns {Promise<{status: number, body: object, push?: number | object}>} The state, and the change to tell every game when the list grew, see storyPushText; or why the ids are wrong.
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
        return { status: 200, body: stateOf(story, true) };
      }

      const next = { ...(story ?? this.first()), comps: [...comps].sort((a, b) => a - b), rev: (story?.rev ?? 0) + 1 };
      await this.store.put(next, null);
      return { status: 200, body: stateOf(next, true), push: this.pushOf(story, next) };
    });
  }

  /**
   * Tells whether the story is kept key by key, which games that keep it sealed can no longer play.
   *
   * @returns {Promise<boolean>} Whether it is.
   */
  async keyed() {
    return this.exclusive(async () => Boolean((await this.store.get())?.lists));
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
   * Makes the story of a world nobody wrote yet, for a route lock or a companion that comes first.
   *
   * @returns {object} The story, at revision 0 without a sealed story.
   */
  first() {
    return { rev: 0, wrev: 0, counters: { ...FIRST_COUNTERS, clear: [] }, part: PART.one, route: ROUTE.none, done: [], end: null, comps: [], caps: [], checkpoints: [], blob: "", at: this.clock(), by: null };
  }

  /**
   * Runs one read and write of the story at a time, so a second write reads the first.
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
 * Makes a part's checkpoint of the story as it stands: its sealed story or its lists, without the
 * log of writes that only the current story keeps.
 *
 * @param {object} story The story as kept.
 * @returns {object} The checkpoint.
 */
function checkpointOf(story) {
  const kept = { rev: story.wrev, wrev: story.wrev, counters: story.counters, part: story.part, route: story.route, done: story.done, end: story.end, at: story.at, by: story.by };
  return story.lists ? { ...kept, blob: "", lists: story.lists } : { ...kept, blob: story.blob };
}

/**
 * Makes the state a game reads of the story.
 *
 * @param {object | undefined} story The story as kept, undefined before the first write.
 * @param {boolean} withBlob Whether to add the story: a keyed story's lists under `keys` with `keyed`, else the sealed story under `blob`.
 * @returns {object} `rev` (every change counts it up), `wrev` (the revision of the last write, whose sealed story this is), `p`, `r1141`, `r1142`, `r1143`, `clear`, `part`, `route`, `done`, `end`, `comps`, `caps` (the level caps the story unlocked, lowest first), `checkpoints` and `at`, and `blob` when asked for (empty before the first write).
 */
export function stateOf(story, withBlob) {
  const counters = story?.counters ?? FIRST_COUNTERS;
  const state = {
    rev: story?.rev ?? 0,
    wrev: story?.wrev ?? 0,
    p: counters.p,
    r1141: counters.r1141,
    r1142: counters.r1142,
    r1143: counters.r1143,
    clear: [...counters.clear],
    part: story?.part ?? PART.one,
    route: story?.route ?? ROUTE.none,
    done: [...(story?.done ?? [])],
    end: story?.end ?? null,
    comps: [...(story?.comps ?? [])],
    caps: [...(story?.caps ?? [])],
    checkpoints: [...(story?.checkpoints ?? [])],
    at: story?.at ?? 0,
  };

  if (!withBlob) {
    return state;
  }

  return story?.lists ? { ...state, keyed: true, keys: story.lists } : { ...state, blob: story?.blob ?? "" };
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
 * @param {string} player The asking player's id.
 * @param {number | null} [known] The revision a GET names in `known`, see WorldStory.get.
 * @returns {Promise<{status: number, body: object, push?: number | object}>} The answer, and the change to tell every game of the world when the story changed, see storyPushText.
 */
export async function handleStoryRequest(story, method, rest, readBody, player, known = null) {
  if (rest.length === 0 && method === "GET") {
    return story.get(known);
  }

  if (rest.length === 0 && method === "POST") {
    return withJson(readBody, story.limits.maxBodyLength, (body) => story.write(player, body));
  }

  if (rest.length === 2 && rest[0] === "checkpoint" && method === "GET") {
    return story.checkpoint(rest[1]);
  }

  if (rest.length === 1 && rest[0] === "route" && method === "POST") {
    return withJson(readBody, story.limits.maxSmallBodyLength, (body) => story.lockRoute(body?.route));
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

/**
 * Tells whether a game that keeps a Raid World's story sealed must be turned away from a world,
 * since the world's story is keyed: it names no STORY_FEATURE.
 *
 * @param {WorldStory} story The world's story.
 * @param {string[]} features What the game names in FEATURES_HEADER.
 * @returns {Promise<boolean>} Whether it must.
 */
export async function sealedGameRefused(story, features) {
  return !features.includes(STORY_FEATURE) && (await story.keyed());
}

/**
 * The answer for a game that keeps a Raid World's story sealed, at a world whose story is keyed.
 *
 * @returns {{status: number, body: object}} The answer.
 */
export function sealedGameRefusal() {
  return { status: 426, body: { error: "the world keeps its story key by key, which this game does not", code: STORY_REFUSAL.update } };
}
