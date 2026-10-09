//----------------------------------------------------------------
//  story.js
//
//  Changelog:
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

// The story of a Raid World, which the whole world plays together: a few counters the relay reads
// to tell which story is further, and the rest of the story sealed with a key from the world's
// token, which the relay only keeps. A game that moved the story on writes it here; the furthest
// story wins, and two games writing at once cannot overwrite each other, since each names the
// revision it built on. When a write moves the world into a later part, the story before it stays
// as that part's checkpoint, for players who are behind.
//
// The revision counts every change: a write, a route lock and a grown companions list, so the
// games are told of each by it. A write only has to build on the last sealed story, so a route
// lock or a companion between a game's read and its write does not turn the write away.
//
// Each world keeps its story apart from the directory, in its own world room's object on Cloudflare,
// so the directory carries none of the story's traffic.

import { badRequest, notFound, withJson } from "./http.js";
import { isId } from "./ids.js";
import { RateLimiter, VERSION } from "./relay.js";

/**
 * The limits a world's story keeps.
 */
export const STORY_LIMITS = Object.freeze({
  // The sealed story in base64: 200 KB of story, sealed, fits.
  maxBlobLength: 280_000,
  // A write's whole JSON body, the sealed story and the counters.
  maxBodyLength: 300_000,
  // The JSON body of a route lock or a companions list.
  maxSmallBodyLength: 32 * 1024,
  maxCompanions: 2000,
  maxCompanionsPerAdd: 500,
  maxActorId: 99_999,
  maxCounter: 1_000_000,
  maxMapId: 9999,
  maxTile: 9999,
  // Story writes per player: a burst, then one more every few seconds, so a game stuck in a loop
  // cannot spend the free plan's daily writes.
  writes: Object.freeze({ burst: 20, refillMs: 3 * 1000 }),
});

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
 * @param {any} counters The counters as sent: `p`, `r1141`, `r1142`, `r1143`, `clear` and maybe `end`.
 * @param {typeof STORY_LIMITS} [limits] The limits.
 * @returns {{counters: {p: number, r1141: number, r1142: number, r1143: number, clear: string[]}, end: object | null | undefined} | {error: string}} The counters, and the endpoint (null to clear it, undefined to keep it); or what is wrong.
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

  // Kept in the routes' own order, so the same finished routes always read the same.
  return { counters: { p: counters.p, r1141: counters.r1141, r1142: counters.r1142, r1143: counters.r1143, clear: routes.filter((route) => clear.includes(route)) }, end };
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
   * @returns {Promise<{status: number, body: object}>} The story's state with its sealed story, see stateOf.
   */
  async get() {
    return this.exclusive(async () => ({ status: 200, body: stateOf(await this.store.get(), true) }));
  }

  /**
   * Hands out a part's checkpoint: the story as it stood right before the write that moved the
   * world past that part.
   *
   * @param {unknown} part The part, one of PART.
   * @returns {Promise<{status: number, body: object}>} The checkpoint's state with its sealed story, or 404 with code `none`.
   */
  async checkpoint(part) {
    if (!Object.values(PART).includes(part)) {
      return badRequest(`the part must be one of ${Object.values(PART).join(", ")}`);
    }

    const checkpoint = await this.exclusive(() => this.store.getCheckpoint(part));
    return checkpoint ? { status: 200, body: { ...stateOf(checkpoint, true), part } } : { status: 404, body: { error: "the world has no checkpoint of this part", code: STORY_REFUSAL.none } };
  }

  /**
   * Takes a game's write of the story: accepted when it built on the story as it stands and its
   * counters are not behind the story's.
   *
   * @param {string} player The writing player's id.
   * @param {any} request The write: `base`, the revision it built on, any from the last write's on (0 before the first); `counters`, see readCounters; and `blob`, the sealed story in base64.
   * @returns {Promise<{status: number, body: object, push?: number}>} The new state with `accepted`, and the revision to tell every game; or 409 with the state as it stands, its sealed story and a code; or why the write is wrong.
   */
  async write(player, request) {
    if (!request || typeof request !== "object") {
      return badRequest("the write must be a JSON object");
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
      const refusal = this.refusalOf(story, request.base, read.counters);

      if (refusal) {
        return { status: 409, body: { ...stateOf(story, true), error: refusal.error, code: refusal.code } };
      }

      const now = this.clock();
      const route = activeRoute(read.counters);
      const done = [...(story?.done ?? [])];

      for (const cleared of read.counters.clear) {
        if (!done.includes(cleared)) {
          done.push(cleared);
        }
      }

      const locked = story?.route ?? ROUTE.none;
      const part = partOf(read.counters);
      const checkpoint = story?.blob && story.part !== part ? checkpointOf(story) : null;
      const checkpoints = checkpoint && !story.checkpoints.includes(story.part) ? [...story.checkpoints, story.part] : [...(story?.checkpoints ?? [])];

      const rev = (story?.rev ?? 0) + 1;
      const next = {
        rev,
        wrev: rev,
        counters: read.counters,
        part,
        route: route !== ROUTE.none ? route : done.includes(locked) ? ROUTE.none : locked,
        done,
        end: read.end === undefined ? (story?.end ?? null) : read.end,
        comps: story?.comps ?? [],
        checkpoints,
        blob: request.blob,
        at: now,
        by: player,
      };

      await this.store.put(next, checkpoint);
      return { status: 200, body: { ...stateOf(next, false), accepted: true }, push: next.rev };
    });
  }

  /**
   * Tells why a write may not replace the story. Called inside exclusive.
   *
   * @param {object | undefined} story The story as it stands.
   * @param {number} base The revision the write built on.
   * @param {object} counters The write's counters.
   * @returns {{error: string, code: string} | null} Why not, or null when it may.
   */
  refusalOf(story, base, counters) {
    // Any revision from the last write on saw the sealed story as it stands.
    if (base < (story?.wrev ?? 0) || base > (story?.rev ?? 0)) {
      return { error: "the story moved on since the revision the write built on", code: STORY_REFUSAL.rev };
    }

    if (story && compareKeys(storyKey(counters), storyKey(story.counters)) < 0) {
      return { error: "the write is behind the world's story", code: STORY_REFUSAL.behind };
    }

    const route = activeRoute(counters);
    const locked = story?.route ?? ROUTE.none;
    const done = story?.done ?? [];

    if (locked === ROUTE.none) {
      return null;
    }

    // While a route is under way only that route, or the return from it, goes on: a write from
    // another story would throw the route's progress away or finish routes the world never played.
    // Until the world's own story is on the locked route, a story with no route under way goes on
    // too, since the player who locked it writes its first step only once their scene ended.
    const started = activeRoute(story.counters) === locked;
    const onLocked = route === locked || (route === ROUTE.none && (counters.clear.includes(locked) || !started));
    const unplayed = counters.clear.some((cleared) => cleared !== locked && !done.includes(cleared));

    if (!onLocked || unplayed) {
      return { error: "another route was chosen first", code: STORY_REFUSAL.route };
    }

    return null;
  }

  /**
   * Locks the route the world takes at the Great Decision: the first route chosen wins, until the
   * world finished it and returned to the Great Decision.
   *
   * @param {any} route The route, one of ROUTE but none.
   * @returns {Promise<{status: number, body: object, push?: number}>} The state with `locked` (the same route again answers the same), and the revision to tell every game when it changed; or 409 with the state and code `route` when another route is locked, `finished` for a route the world finished, `closed` for Chaos before both other routes are finished.
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

      if (locked !== ROUTE.none) {
        return refuse("another route was chosen first", STORY_REFUSAL.route);
      }

      if (done.includes(route)) {
        return refuse("the world finished this route", STORY_REFUSAL.finished);
      }

      if (route === ROUTE.chaos && !(done.includes(ROUTE.ad) && done.includes(ROUTE.mr))) {
        return refuse("the third way opens once both other routes are finished", STORY_REFUSAL.closed);
      }

      const next = { ...(story ?? this.first()), route, rev: (story?.rev ?? 0) + 1 };
      await this.store.put(next, null);
      return { status: 200, body: { ...stateOf(next, true), locked: route }, push: next.rev };
    });
  }

  /**
   * Adds companions to the world's shared list, which only grows.
   *
   * @param {any} ids The companions' actor ids.
   * @returns {Promise<{status: number, body: object, push?: number}>} The state, and the revision to tell every game when the list grew; or why the ids are wrong.
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
      return { status: 200, body: stateOf(next, true), push: next.rev };
    });
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
    return { rev: 0, wrev: 0, counters: { ...FIRST_COUNTERS, clear: [] }, part: PART.one, route: ROUTE.none, done: [], end: null, comps: [], checkpoints: [], blob: "", at: this.clock(), by: null };
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
 * Makes a part's checkpoint of the story as it stands, without the lists that only the current
 * story keeps.
 *
 * @param {object} story The story as kept.
 * @returns {object} The checkpoint.
 */
function checkpointOf(story) {
  return { rev: story.wrev, wrev: story.wrev, counters: story.counters, part: story.part, route: story.route, done: story.done, end: story.end, blob: story.blob, at: story.at, by: story.by };
}

/**
 * Makes the state a game reads of the story.
 *
 * @param {object | undefined} story The story as kept, undefined before the first write.
 * @param {boolean} withBlob Whether to add the sealed story.
 * @returns {object} `rev` (every change counts it up), `wrev` (the revision of the last write, whose sealed story this is), `p`, `r1141`, `r1142`, `r1143`, `clear`, `part`, `route`, `done`, `end`, `comps`, `checkpoints` and `at`, and `blob` when asked for (empty before the first write).
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
    checkpoints: [...(story?.checkpoints ?? [])],
    at: story?.at ?? 0,
  };

  return withBlob ? { ...state, blob: story?.blob ?? "" } : state;
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
 * @returns {Promise<{status: number, body: object, push?: number}>} The answer, and the revision to tell every game of the world when the story changed.
 */
export async function handleStoryRequest(story, method, rest, readBody, player) {
  if (rest.length === 0 && method === "GET") {
    return story.get();
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
