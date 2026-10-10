//----------------------------------------------------------------
//  bosses.js
//
//  Changelog:
//      Paulinchen  2026-10-10: Kept each boss pool as the share of its raid max HP left, which every pooled battle's host reports turn by turn, instead of a count of kills
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

// The raid bosses of a Raid World: one pool per story boss, whose HP the whole world shares. Every
// battle fighting a boss reports what its players took off since its last report, as a share of
// the boss's max HP, since each host's difficulty and mods set the boss's max HP in its own game.
// The share left fills up again slowly; the report that empties it defeats the boss for the world
// for good.
//
// The share left is kept as it stood at the last report and read lazily, so regeneration costs no
// writes: only a report and an admin's reset write.

import { badRequest, notFound, withJson } from "./http.js";
import { CONTROL_CHARACTERS, isId } from "./ids.js";
import { RateLimiter, VERSION } from "./relay.js";

/**
 * The limits a world's raid bosses keep.
 */
export const BOSS_LIMITS = Object.freeze({
  // The share of the max HP a pool fills up by per minute, also while battles fight it.
  regenPerMinute: 0.03,
  // A game's key of up to 64 characters, with "#" and the index of a troop's member after it.
  maxKeyLength: 72,
  maxBattleLength: 64,
  maxPools: 500,
  // The battles each pool remembers with their last report, so a report sent again counts once.
  recentBattles: 32,
  // The highest raid max HP a game may name; Void Image of Paradise reaches about 6e15 at tier 1 on Hell.
  maxMax: 1e18,
  maxBodyLength: 4 * 1024,
  // Reports per player: a burst, then two a second, enough for a report per pool every two seconds
  // of a battle against up to four enemies, while a game stuck in a loop cannot spend the free plan's
  // daily writes in minutes.
  reports: Object.freeze({ burst: 30, refillMs: 500 }),
});

/**
 * The word the text frame starts with that tells every game of a world a boss pool changed, as
 * `boss <left> <max> <defeated> <key>`.
 */
export const BOSS = "boss";

/**
 * The codes a refused report names why with.
 */
export const BOSS_REFUSAL = Object.freeze({ rate: "rate", full: "full" });

/**
 * A battle's id: letters, digits, `_` and `-`.
 */
const BATTLE = /^[A-Za-z0-9_-]+$/;

/**
 * A minute in milliseconds.
 */
const MINUTE = 60_000;

/**
 * The decimals the share left travels with in a text frame.
 */
const FRAME_DECIMALS = 6;

/**
 * The smallest share left a text frame names for a boss still standing.
 */
const FRAME_SMALLEST = 10 ** -FRAME_DECIMALS;

/**
 * Writes the text frame that tells every game of a world a boss pool changed.
 *
 * @param {string} key The boss.
 * @param {number} left The share of the max HP left now, 0 to 1.
 * @param {number} max The raid max HP.
 * @param {boolean} defeated Whether the boss is defeated for the world.
 * @returns {string} The frame, such as "boss 0.25 5000000 0 Alma Elma#1"; the key goes last since it may hold spaces.
 */
export function bossText(key, left, max, defeated) {
  // A standing pool of a huge max may hold less than the frame's smallest share, which must not
  // read as empty in the games.
  const shown = defeated ? 0 : left > 0 ? Math.max(FRAME_SMALLEST, Number(left.toFixed(FRAME_DECIMALS))) : 0;
  return `${BOSS} ${shown} ${Math.round(max)} ${defeated ? 1 : 0} ${key}`;
}

/**
 * Reads a boss's key from the address: the milestone or troop key the game sends, percent-encoded.
 *
 * @param {unknown} raw The address's part.
 * @param {typeof BOSS_LIMITS} [limits] The limits.
 * @returns {string | null} The key, or null when it is no key.
 */
export function readKey(raw, limits = BOSS_LIMITS) {
  if (typeof raw !== "string") {
    return null;
  }

  let key;

  try {
    key = decodeURIComponent(raw);
  } catch {
    return null;
  }

  const length = [...key].length;
  return length >= 1 && length <= limits.maxKeyLength && key.trim() === key && !new RegExp(CONTROL_CHARACTERS.source).test(key) ? key : null;
}

/**
 * @typedef {object} BossPool A boss pool as kept.
 * @property {string} key The boss.
 * @property {number} max The raid max HP the first report named, a whole number of 1 or more.
 * @property {number} left The share of the max HP left at the last report, 0 to 1.
 * @property {number} at When it was last reported.
 * @property {boolean} defeated Whether a report emptied it, which defeats the boss for the world.
 * @property {string | null} by The name of the player whose report emptied it.
 * @property {string | null} byPlayer The id of the player whose report emptied it.
 * @property {{id: string, seq: number}[]} battles The battles reported lately with their last report's number, the most recent last.
 * @property {number} reports How many reports were counted.
 */

/**
 * @typedef {object} BossStore Where one world's boss pools are kept.
 * @property {(key: string) => Promise<object | undefined>} get Reads a pool, undefined for one never reported.
 * @property {(pool: BossPool) => Promise<void>} put Writes a pool.
 * @property {() => Promise<object[]>} all Reads every pool.
 * @property {(key: string) => Promise<void>} remove Deletes a pool.
 * @property {() => Promise<void>} removeAll Deletes every pool.
 */

/**
 * @typedef {object} BossPush The pool to tell every game of the world, see bossText.
 * @property {string} key The boss.
 * @property {number} left The share left now.
 * @property {number} max The raid max HP.
 * @property {boolean} defeated Whether the boss is defeated for the world.
 */

/**
 * One Raid World's boss pools, over a store of their own.
 */
export class WorldBosses {
  /**
   * Creates the pools.
   *
   * @param {BossStore} store Where the pools are kept.
   * @param {{clock?: () => number, limits?: typeof BOSS_LIMITS}} [options] The clock and limits, which tests change.
   */
  constructor(store, { clock = Date.now, limits = BOSS_LIMITS } = {}) {
    this.store = store;
    this.clock = clock;
    this.limits = limits;
    this.reports = new RateLimiter(limits.reports, clock);
    this.queue = Promise.resolve();
  }

  /**
   * Hands out every pool a report touched, as they stand now.
   *
   * @param {boolean} [admin] Whether to add what only admins see, see viewOf.
   * @returns {Promise<{status: number, body: object}>} `bosses`, sorted by key, and `regenPerMinute`.
   */
  async list(admin = false) {
    const pools = await this.exclusive(() => this.pools());
    const now = this.clock();
    const bosses = pools.sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0)).map((pool) => viewOf(pool, now, this.limits, admin));
    return { status: 200, body: { bosses, regenPerMinute: this.limits.regenPerMinute } };
  }

  /**
   * Hands out one pool as it stands now; a pool never reported is full, with no max yet.
   *
   * @param {unknown} raw The boss's key as the address names it.
   * @returns {Promise<{status: number, body: object}>} The pool, see viewOf.
   */
  async get(raw) {
    const key = readKey(raw, this.limits);

    if (key === null) {
      return badRequest(this.keyError());
    }

    const pool = await this.exclusive(async () => poolOf(await this.store.get(key)));
    return { status: 200, body: pool ? viewOf(pool, this.clock(), this.limits, false) : untouchedView(key) };
  }

  /**
   * Counts a battle's report against a boss's pool, once per report number of the battle.
   *
   * @param {string} player The reporting player's id.
   * @param {unknown} raw The boss's key as the address names it.
   * @param {any} request The report: `battle`, the battle's id; `seq`, the report's number, rising within the battle; `delta`, the share of the boss's max HP lost since the battle's last report, negative for healing; `max`, the raid max HP in the reporting game; `killed`, whether the boss died in the reporting game.
   * @param {string | null} [name] The reporting player's name, which a defeat keeps.
   * @returns {Promise<{status: number, body: object, boss?: BossPush}>} `boss`, the pool as viewOf makes it, and `repeat`, whether the battle reported this number before; the pool to tell every game when it changed; or why the report is wrong.
   */
  async report(player, raw, request, name = null) {
    const key = readKey(raw, this.limits);

    if (key === null) {
      return badRequest(this.keyError());
    }

    const refusal = this.reportError(request);

    if (refusal) {
      return badRequest(refusal);
    }

    if (!this.reports.take(player)) {
      return { status: 429, body: { error: "the bosses are reported too often, try again later", code: BOSS_REFUSAL.rate } };
    }

    const { battle, seq, delta } = request;
    const killed = request.killed === true || request.killed === 1;

    return this.exclusive(async () => {
      const now = this.clock();
      const kept = poolOf(await this.store.get(key));
      const answer = (pool, repeat) => ({ status: 200, body: { boss: viewOf(pool, now, this.limits, false), repeat } });
      const last = kept?.battles.find((each) => each.id === battle);

      if (last && seq <= last.seq) {
        return answer(kept, true);
      }

      // A defeated boss stays defeated, and a report that takes nothing off changes nothing, so
      // neither writes.
      if (kept && (kept.defeated || (delta === 0 && !killed))) {
        return answer(kept, false);
      }

      if (!kept && (await this.pools()).length >= this.limits.maxPools) {
        return { status: 413, body: { error: `the world keeps at most ${this.limits.maxPools} boss pools`, code: BOSS_REFUSAL.full } };
      }

      const pool = kept ?? this.fresh(key, request.max, now);
      const left = killed ? 0 : Math.min(1, Math.max(0, leftOf(pool, now, this.limits) - delta));
      // A pool whose HP shows as 0 is empty, so float leftovers never keep a boss standing.
      const defeated = left * pool.max < 0.5;
      const next = {
        ...pool,
        left: defeated ? 0 : left,
        at: now,
        defeated,
        by: defeated ? name : null,
        byPlayer: defeated ? player : null,
        battles: [...pool.battles.filter((each) => each.id !== battle), { id: battle, seq }].slice(-this.limits.recentBattles),
        reports: pool.reports + 1,
      };

      await this.store.put(next);
      return { ...answer(next, false), boss: { key, left: next.left, max: next.max, defeated } };
    });
  }

  /**
   * Fills a boss's pool up again and takes its defeat back, as an admin asks, by deleting it.
   *
   * @param {unknown} raw The boss's key as the address names it.
   * @returns {Promise<{status: number, body: object, boss?: BossPush}>} The full pool with `reset` (whether there was one to reset), and the pool to tell every game when it changed.
   */
  async reset(raw) {
    const key = readKey(raw, this.limits);

    if (key === null) {
      return badRequest(this.keyError());
    }

    return this.exclusive(async () => {
      const stored = await this.store.get(key);
      const kept = poolOf(stored);

      if (stored) {
        await this.store.remove(key);
      }

      const body = { ...untouchedView(key), reset: Boolean(kept) };
      return kept ? { status: 200, body, boss: { key, left: 1, max: kept.max, defeated: false } } : { status: 200, body };
    });
  }

  /**
   * Deletes every pool, as when the world is deleted.
   *
   * @returns {Promise<void>} Completes once deleted.
   */
  remove() {
    return this.exclusive(() => this.store.removeAll());
  }

  /**
   * Reads every pool kept in the current shape; pools kept in kills before the shared HP read as
   * never reported, so they never count.
   * @returns {Promise<BossPool[]>} The pools.
   */
  async pools() {
    return (await this.store.all()).map(poolOf).filter(Boolean);
  }

  /**
   * Makes the pool of a boss nobody reported yet: full.
   *
   * @param {string} key The boss.
   * @param {number} max The raid max HP the first report names.
   * @param {number} now The time now.
   * @returns {BossPool} The pool.
   */
  fresh(key, max, now) {
    return { key, max: Math.max(1, Math.round(max)), left: 1, at: now, defeated: false, by: null, byPlayer: null, battles: [], reports: 0 };
  }

  /**
   * Finds what is wrong with a report's body.
   *
   * @param {any} request The report.
   * @returns {string | null} Why it is wrong, or null when it is right.
   */
  reportError(request) {
    if (!request || typeof request !== "object" || Array.isArray(request)) {
      return "the report must be a JSON object";
    }

    const { battle, seq, delta, max, killed } = request;

    if (typeof battle !== "string" || battle.length === 0 || battle.length > this.limits.maxBattleLength || !BATTLE.test(battle)) {
      return `battle must be 1 to ${this.limits.maxBattleLength} letters, digits, _ or -`;
    }

    if (!Number.isSafeInteger(seq) || seq < 0) {
      return "seq must be the report's number within the battle, a whole number of 0 or more";
    }

    if (typeof delta !== "number" || !Number.isFinite(delta) || Math.abs(delta) > 1) {
      return "delta must be the share of the boss's max HP lost since the battle's last report, -1 to 1";
    }

    if (typeof max !== "number" || !Number.isFinite(max) || max <= 0 || max > this.limits.maxMax) {
      return `max must be the boss's raid max HP, more than 0 and at most ${this.limits.maxMax}`;
    }

    if (killed !== undefined && killed !== true && killed !== false && killed !== 0 && killed !== 1) {
      return "killed must be true or false";
    }

    return null;
  }

  /**
   * Tells what a boss's key must be.
   *
   * @returns {string} The rule.
   */
  keyError() {
    return `the boss's key must be 1 to ${this.limits.maxKeyLength} characters without control characters or spaces at either end`;
  }

  /**
   * Runs one read and write of the pools at a time, so a second report reads the first.
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
 * Reads a kept pool, if it is one in the current shape.
 *
 * @param {any} kept What the store kept.
 * @returns {BossPool | undefined} The pool, undefined for none or one kept in kills.
 */
function poolOf(kept) {
  return kept && typeof kept.left === "number" && typeof kept.max === "number" && Array.isArray(kept.battles) ? kept : undefined;
}

/**
 * Reads the share of a pool's max HP left now: what was left at the last report, filled up since,
 * at most full; a defeated boss stays at 0.
 *
 * @param {BossPool} pool The pool as kept.
 * @param {number} now The time now.
 * @param {typeof BOSS_LIMITS} [limits] The limits.
 * @returns {number} The share left, 0 to 1.
 */
export function leftOf(pool, now, limits = BOSS_LIMITS) {
  if (pool.defeated) {
    return 0;
  }

  return Math.min(1, pool.left + (limits.regenPerMinute * Math.max(0, now - pool.at)) / MINUTE);
}

/**
 * Makes the view of a pool a game or an admin reads.
 *
 * @param {BossPool} pool The pool as kept.
 * @param {number} now The time now.
 * @param {typeof BOSS_LIMITS} limits The limits.
 * @param {boolean} admin Whether to add what only admins see.
 * @returns {object} `key`, `left` (the share left now), `max`, `defeated`, `at` (the last report) and `by` (the name of the player whose report emptied it); for admins also `hp` (the HP left now, rounded), `reports` and `byPlayer`.
 */
export function viewOf(pool, now, limits, admin) {
  const left = leftOf(pool, now, limits);
  const view = { key: pool.key, left, max: pool.max, defeated: pool.defeated, at: pool.at, by: pool.by };
  return admin ? { ...view, hp: Math.round(left * pool.max), reports: pool.reports, byPlayer: pool.byPlayer } : view;
}

/**
 * Makes the view of a pool nobody reported: full, with its max HP still unknown.
 *
 * @param {string} key The boss.
 * @returns {object} The view, see viewOf.
 */
function untouchedView(key) {
  return { key, left: 1, max: null, defeated: false, at: null, by: null };
}

/**
 * Reads which world and boss route an address names.
 *
 * @param {URL} url The request's address.
 * @returns {{id: string, rest: string[]} | null} The world and the parts after `bosses`, still percent-encoded; or null when it is no boss route.
 */
export function bossRouteOf(url) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);
  return parts.length >= 4 && parts[0] === VERSION && parts[1] === "worlds" && isId(parts[2]) && parts[3] === "bosses" ? { id: parts[2], rest: parts.slice(4) } : null;
}

/**
 * Answers a request to a world's boss routes, once the platform layer found the asking game to be
 * a player of that Raid World.
 *
 * @param {WorldBosses} bosses The world's boss pools.
 * @param {string} method The HTTP method.
 * @param {string[]} rest The address's parts after `bosses`, see bossRouteOf.
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when it is too large to read.
 * @param {string} player The asking player's id.
 * @param {string | null} [name] The asking player's name, which a defeat keeps.
 * @returns {Promise<{status: number, body: object, boss?: BossPush}>} The answer, and the pool to tell every game of the world when it changed.
 */
export async function handleBossRequest(bosses, method, rest, readBody, player, name = null) {
  if (rest.length === 0 && method === "GET") {
    return bosses.list();
  }

  if (rest.length === 1 && method === "GET") {
    return bosses.get(rest[0]);
  }

  if (rest.length === 2 && rest[1] === "report" && method === "POST") {
    return withJson(readBody, bosses.limits.maxBodyLength, (body) => bosses.report(player, rest[0], body, name));
  }

  return notFound("route");
}
