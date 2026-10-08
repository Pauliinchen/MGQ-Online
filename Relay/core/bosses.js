//----------------------------------------------------------------
//  bosses.js
//
//  Changelog:
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

// The raid bosses of a Raid World: one pool per story boss, which the whole world wears down
// together. A pool counts in kills, not HP, because each host's difficulty and mods set the boss's
// max HP: a won or lost battle takes off the share of the boss's max HP its players dealt. An
// untouched pool fills up again over time; the one battle that empties it defeats the boss for the
// world for good, and only that battle's story goes on.
//
// The hit points are kept as they stood at the last report and read lazily, so regeneration costs
// no writes: only a report and an admin's reset write.

import { badRequest, notFound, withJson } from "./http.js";
import { CONTROL_CHARACTERS, isId } from "./ids.js";
import { RateLimiter, VERSION } from "./relay.js";

/**
 * The limits a world's raid bosses keep.
 */
export const BOSS_LIMITS = Object.freeze({
  // A full pool, in kills: the boss falls five times before it is defeated for the world.
  max: 5,
  // How long an untouched pool takes from empty to full.
  refillMs: 60 * 60 * 1000,
  maxKeyLength: 64,
  maxBattleLength: 64,
  maxPools: 500,
  // The battle ids each pool remembers, so a report sent again is not counted twice.
  recentBattles: 32,
  maxBodyLength: 4 * 1024,
  // Reports per player: a burst, then one more every few seconds, so a game stuck in a loop
  // cannot empty a pool or spend the free plan's daily writes.
  reports: Object.freeze({ burst: 6, refillMs: 20 * 1000 }),
});

/**
 * The word the text frame starts with that tells every game of a world a boss pool changed, as
 * `boss <hp> <key>`.
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
 * Hit points that round to 0 in an answer count as 0, so a pool that answers 0 is always defeated.
 */
const EMPTY = 0.0005;

/**
 * Writes the text frame that tells every game of a world a boss pool changed.
 *
 * @param {string} key The boss.
 * @param {number} hp The pool's hit points now, in kills.
 * @returns {string} The frame, such as "boss 3.5 Alma Elma"; the key goes last since it may hold spaces.
 */
export function bossText(key, hp) {
  return `${BOSS} ${roundHp(hp)} ${key}`;
}

/**
 * Rounds hit points for an answer, so float leftovers do not travel.
 *
 * @param {number} hp The hit points.
 * @returns {number} The hit points to three decimals.
 */
function roundHp(hp) {
  return Math.round(hp * 1000) / 1000;
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
 * @property {number} hp The hit points in kills when last reported.
 * @property {number} max The full pool.
 * @property {number} regen The kills it fills up by per hour.
 * @property {number} at When it was last reported.
 * @property {boolean} defeated Whether a report emptied it, which defeats the boss for the world.
 * @property {string | null} emptiedBy The battle whose report emptied it.
 * @property {string | null} by The player whose report emptied it.
 * @property {string[]} battles The battles counted lately, newest last.
 * @property {number} reports How many reports were counted.
 */

/**
 * @typedef {object} BossStore Where one world's boss pools are kept.
 * @property {(key: string) => Promise<BossPool | undefined>} get Reads a pool, undefined for one never reported.
 * @property {(pool: BossPool) => Promise<void>} put Writes a pool.
 * @property {() => Promise<BossPool[]>} all Reads every pool.
 * @property {(key: string) => Promise<void>} remove Deletes a pool.
 * @property {() => Promise<void>} removeAll Deletes every pool.
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
   * @returns {Promise<{status: number, body: object}>} `bosses`, sorted by key; `max` and `regen`, which a pool never reported has.
   */
  async list(admin = false) {
    const pools = await this.exclusive(() => this.store.all());
    const now = this.clock();
    const bosses = pools.sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0)).map((pool) => viewOf(pool, now, admin));
    return { status: 200, body: { bosses, max: this.limits.max, regen: this.regen() } };
  }

  /**
   * Hands out one pool as it stands now; a pool never reported is full.
   *
   * @param {unknown} raw The boss's key as the address names it.
   * @returns {Promise<{status: number, body: object}>} The pool, see viewOf.
   */
  async get(raw) {
    const key = readKey(raw, this.limits);

    if (key === null) {
      return badRequest(this.keyError());
    }

    const pool = (await this.exclusive(() => this.store.get(key))) ?? this.fresh(key);
    return { status: 200, body: viewOf(pool, this.clock(), false) };
  }

  /**
   * Counts a battle against a boss's pool, once per battle.
   *
   * @param {string} player The reporting player's id.
   * @param {unknown} raw The boss's key as the address names it.
   * @param {any} request The report: `battle`, the battle's id; `dealt`, the share of the boss's max HP its players dealt, 0 or more, counted up to 1.
   * @returns {Promise<{status: number, body: object, boss?: {key: string, hp: number}}>} The pool with `dealt` (what was counted), `emptied` (this battle's report emptied it), `defeated` and `repeat` (the battle was counted before), and the pool to tell every game when it changed; or why the report is wrong.
   */
  async report(player, raw, request) {
    const key = readKey(raw, this.limits);

    if (key === null) {
      return badRequest(this.keyError());
    }

    if (!request || typeof request !== "object") {
      return badRequest("the report must be a JSON object");
    }

    const battle = request.battle;

    if (typeof battle !== "string" || battle.length === 0 || battle.length > this.limits.maxBattleLength || !BATTLE.test(battle)) {
      return badRequest(`battle must be 1 to ${this.limits.maxBattleLength} letters, digits, _ or -`);
    }

    if (typeof request.dealt !== "number" || !Number.isFinite(request.dealt) || request.dealt < 0) {
      return badRequest("dealt must be the share of the boss's max HP dealt, a number of 0 or more");
    }

    if (!this.reports.take(player)) {
      return { status: 429, body: { error: "the bosses are reported too often, try again later", code: BOSS_REFUSAL.rate } };
    }

    const dealt = Math.min(1, request.dealt);

    return this.exclusive(async () => {
      const now = this.clock();
      const kept = await this.store.get(key);
      const answer = (pool, counted, repeat) => ({ ...viewOf(pool, now, false), dealt: counted, emptied: pool.emptiedBy === battle, repeat });

      if (kept && (kept.battles.includes(battle) || kept.emptiedBy === battle)) {
        return { status: 200, body: answer(kept, 0, true) };
      }

      // A defeated boss stays defeated; a late report changes nothing, so it writes nothing.
      if (kept?.defeated) {
        return { status: 200, body: answer(kept, 0, false) };
      }

      if (!kept && (await this.store.all()).length >= this.limits.maxPools) {
        return { status: 413, body: { error: `the world keeps at most ${this.limits.maxPools} boss pools`, code: BOSS_REFUSAL.full } };
      }

      const pool = kept ?? this.fresh(key);
      const left = hpOf(pool, now) - dealt;
      const emptied = left < EMPTY;
      const next = {
        ...pool,
        hp: emptied ? 0 : left,
        at: now,
        defeated: emptied,
        emptiedBy: emptied ? battle : null,
        by: emptied ? player : null,
        battles: [...pool.battles, battle].slice(-this.limits.recentBattles),
        reports: pool.reports + 1,
      };

      await this.store.put(next);
      return { status: 200, body: answer(next, dealt, false), boss: { key, hp: next.hp } };
    });
  }

  /**
   * Fills a boss's pool up again and takes its defeat back, as an admin asks.
   *
   * @param {unknown} raw The boss's key as the address names it.
   * @returns {Promise<{status: number, body: object, boss?: {key: string, hp: number}}>} The full pool with `reset` (whether there was one to reset), and the pool to tell every game when it changed.
   */
  async reset(raw) {
    const key = readKey(raw, this.limits);

    if (key === null) {
      return badRequest(this.keyError());
    }

    return this.exclusive(async () => {
      const kept = await this.store.get(key);

      if (kept) {
        await this.store.remove(key);
      }

      const body = { ...viewOf(this.fresh(key), this.clock(), true), reset: Boolean(kept) };
      return kept ? { status: 200, body, boss: { key, hp: this.limits.max } } : { status: 200, body };
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
   * Makes the pool of a boss nobody reported yet: full.
   *
   * @param {string} key The boss.
   * @returns {BossPool} The pool.
   */
  fresh(key) {
    return { key, hp: this.limits.max, max: this.limits.max, regen: this.regen(), at: this.clock(), defeated: false, emptiedBy: null, by: null, battles: [], reports: 0 };
  }

  /**
   * Tells how many kills a pool fills up by per hour.
   *
   * @returns {number} The kills per hour.
   */
  regen() {
    return (this.limits.max * 3_600_000) / this.limits.refillMs;
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
 * Reads a pool's hit points now: what was left at the last report, filled up since, at most full;
 * a defeated boss stays at 0.
 *
 * @param {BossPool} pool The pool as kept.
 * @param {number} now The time now.
 * @returns {number} The hit points in kills.
 */
export function hpOf(pool, now) {
  if (pool.defeated) {
    return 0;
  }

  return Math.min(pool.max, pool.hp + (Math.max(0, now - pool.at) * pool.regen) / 3_600_000);
}

/**
 * Makes the view of a pool a game or an admin reads.
 *
 * @param {BossPool} pool The pool as kept.
 * @param {number} now The time now.
 * @param {boolean} admin Whether to add what only admins see.
 * @returns {object} `key`, `hp` (now, to three decimals), `max`, `regen` (kills per hour) and `defeated`; for admins also `at` (the last report), `reports` and `by` (the player whose report emptied it).
 */
export function viewOf(pool, now, admin) {
  const view = { key: pool.key, hp: roundHp(hpOf(pool, now)), max: pool.max, regen: pool.regen, defeated: pool.defeated };
  return admin ? { ...view, at: pool.at, reports: pool.reports, by: pool.by } : view;
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
 * @returns {Promise<{status: number, body: object, boss?: {key: string, hp: number}}>} The answer, and the pool to tell every game of the world when it changed.
 */
export async function handleBossRequest(bosses, method, rest, readBody, player) {
  if (rest.length === 0 && method === "GET") {
    return bosses.list();
  }

  if (rest.length === 1 && method === "GET") {
    return bosses.get(rest[0]);
  }

  if (rest.length === 2 && rest[1] === "report" && method === "POST") {
    return withJson(readBody, bosses.limits.maxBodyLength, (body) => bosses.report(player, rest[0], body));
  }

  return notFound("route");
}
