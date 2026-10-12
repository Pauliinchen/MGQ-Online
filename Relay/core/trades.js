//----------------------------------------------------------------
//  trades.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Kept the sealed offers beside each trade instead of in it, dropped them once a trade is cancelled, and moved those of older trades out as the trades are tidied
//                            - Refused a player a new trade with 429 once 100 trades they opened ended cancelled within a day
//      Paulinchen  2026-10-07: Answered an unknown sub-route with 404, and read ids, hashes and bodies through ids.js and http.js
//      Paulinchen  2026-10-06: Took the player's key from the X-MGQ-Player header too
//                            - Created
//
//----------------------------------------------------------------

// The referee of trades between two players of a world. The relay passes world messages through
// without keeping them, so two games alone cannot swap items atomically: if one applied a trade and
// the other dropped before it did, items would be copied or lost. Each game commits a hash of the
// offers both games agreed on, and the relay marks the trade committed once both hashes match, in
// one write. The offers arrive sealed with a key from the world's token, so the relay only keeps
// their bytes, for a game that crashed before it applied the trade to fetch again. They are kept
// beside the trade, not in it, so reading every trade never reads them.

import { playerIdOf } from "./directory.js";
import { badRequest, notFound, withJson } from "./http.js";
import { ID, isHash, isId } from "./ids.js";
import { VERSION } from "./relay.js";

/**
 * The limits the trades keep.
 */
export const TRADE_LIMITS = Object.freeze({
  maxSealedLength: 64 * 1024,
  maxBodyLength: 72 * 1024,
  maxOpenPerPlayer: 20,
  maxCancelledPerPlayer: 100,
  maxTrades: 5000,
  pendingMs: 120 * 1000,
  keepCommittedMs: 30 * 24 * 60 * 60 * 1000,
  keepCancelledMs: 24 * 60 * 60 * 1000,
});

/**
 * Where a trade stands: one game committed, both committed the same offers, or it ended without a swap.
 */
export const TRADE_STATE = Object.freeze({ pending: "pending", committed: "committed", cancelled: "cancelled" });

/**
 * Why a trade was cancelled: a player cancelled it, the two hashes differ, or the second commit never came.
 */
export const CANCEL_REASON = Object.freeze({ cancelled: "cancelled", differ: "differ", expired: "expired" });

/**
 * Base64 text.
 */
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

/**
 * @typedef {object} TradeStore Where the trades are kept, one record each, and each player's sealed offers beside it.
 * @property {(id: string) => Promise<object | undefined>} getTrade Reads a trade's record.
 * @property {(record: object, changes?: {sealed?: Record<string, string>, drop?: string[]}) => Promise<void>} putTrade Writes a trade's record, and in the same write the sealed offers of the players `sealed` names, and deletes those of the players `drop` names.
 * @property {(id: string, player: string) => Promise<string | undefined>} getSealed Reads the offers a player of a trade sealed.
 * @property {(id: string, players?: string[]) => Promise<void>} removeTrade Deletes a trade's record and the sealed offers of the players named.
 * @property {() => Promise<object[]>} allTrades Reads every trade's record, without the offers kept beside it.
 */

/**
 * The trades, over a store, with the world directory's entries to check who may trade.
 */
export class TradeBook {
  /**
   * Creates the trades.
   *
   * @param {TradeStore} store Where the trades are kept.
   * @param {(id: string) => Promise<object | undefined>} worldOf Reads a world's directory entry.
   * @param {{clock?: () => number, limits?: typeof TRADE_LIMITS}} [options] The clock and limits, which tests change.
   */
  constructor(store, worldOf, { clock = Date.now, limits = TRADE_LIMITS } = {}) {
    this.store = store;
    this.worldOf = worldOf;
    this.clock = clock;
    this.limits = limits;
    this.queue = Promise.resolve();
  }

  /**
   * Takes one player's commit of a trade: the first makes the trade pending, the partner's with the
   * same hash commits it, and a different hash cancels it. The same commit again changes nothing.
   *
   * @param {string} id The trade.
   * @param {any} request The commit: `player` (the key), `world`, `partner` (the other player's id), `hash` and `sealed`.
   * @returns {Promise<{status: number, body: object}>} The trade's state and why it was cancelled, or why the commit was refused.
   */
  async commit(id, request) {
    const refusal = this.checkCommit(id, request);

    if (refusal) {
      return refusal;
    }

    const player = await playerIdOf(request.player);
    const { world, partner, hash, sealed } = request;

    if (partner === player) {
      return badRequest("a player cannot trade with themselves");
    }

    const entry = await this.worldOf(world);

    if (!entry) {
      return { status: 404, body: { error: "there is no such world" } };
    }

    if (!isMember(entry, player) || !isMember(entry, partner)) {
      return { status: 403, body: { error: "both players must be players of the world" } };
    }

    // One commit at a time, so the second commit reads the first and writes the committed record in one step.
    return this.exclusive(async () => {
      const record = await this.current(id);

      if (!record) {
        return this.open(id, world, player, partner, hash, sealed);
      }

      if (record.world !== world || !record.players.includes(player) || otherOf(record, player) !== partner) {
        return { status: 409, body: { error: "the trade id belongs to another trade" } };
      }

      if (record.state === TRADE_STATE.cancelled) {
        return { status: 200, body: answerOf(record) };
      }

      const own = record.commits[player];

      if (own) {
        const same = own.hash === hash && (await this.sealedOf(record, player)) === sealed;
        return same ? { status: 200, body: answerOf(record) } : { status: 409, body: { error: "the player committed other offers already" } };
      }

      const now = this.clock();
      record.commits[player] = { hash };
      record.updated = now;

      if (record.commits[partner].hash === hash) {
        record.state = TRADE_STATE.committed;
        record.committed = now;
        await this.store.putTrade(record, { sealed: { [player]: sealed } });
      } else {
        cancelRecord(record, CANCEL_REASON.differ, now);
        await this.store.putTrade(record, { drop: record.players });
      }

      return { status: 200, body: answerOf(record) };
    });
  }

  /**
   * Cancels a pending trade for either of its players; a committed one stays committed.
   *
   * @param {string} id The trade.
   * @param {unknown} key The player's key.
   * @returns {Promise<{status: number, body: object}>} The trade's state, or why not.
   */
  async cancel(id, key) {
    const player = await this.playerOf(key);

    if (!ID.test(id) || !player) {
      return badRequest("a trade id and a player key are needed");
    }

    return this.exclusive(async () => {
      const record = await this.current(id);

      if (!record || !record.players.includes(player)) {
        return noTrade();
      }

      if (record.state === TRADE_STATE.pending) {
        cancelRecord(record, CANCEL_REASON.cancelled, this.clock());
        await this.store.putTrade(record, { drop: record.players });
      }

      return { status: 200, body: answerOf(record) };
    });
  }

  /**
   * Tells one of a trade's players where it stands.
   *
   * @param {string} id The trade.
   * @param {unknown} key The player's key.
   * @returns {Promise<{status: number, body: object}>} The trade's state and why it was cancelled, or 404 for anyone else.
   */
  async state(id, key) {
    const player = await this.playerOf(key);

    if (!ID.test(id) || !player) {
      return badRequest("a trade id and a player key are needed");
    }

    return this.exclusive(async () => {
      const record = await this.current(id);
      return record && record.players.includes(player) ? { status: 200, body: answerOf(record) } : noTrade();
    });
  }

  /**
   * Lists the committed trades of a world that a player has not marked done, with the offers the player sealed.
   *
   * @param {unknown} key The player's key.
   * @param {unknown} world The world.
   * @returns {Promise<{status: number, body: object}>} The trades, each `id`, `hash` and `sealed`.
   */
  async pending(key, world) {
    const player = await this.playerOf(key);

    if (!player || !isId(world)) {
      return badRequest("a player key and a world id are needed");
    }

    return this.exclusive(async () => {
      const records = (await this.tidy())
        .filter((record) => record.world === world && record.state === TRADE_STATE.committed && record.players.includes(player) && !record.done.includes(player))
        .sort((a, b) => a.committed - b.committed);
      const trades = [];

      for (const record of records) {
        trades.push({ id: record.id, hash: record.commits[player].hash, sealed: (await this.sealedOf(record, player)) ?? "" });
      }

      return { status: 200, body: { trades } };
    });
  }

  /**
   * Marks a committed trade done for one of its players, whose game applied and saved it, and
   * deletes it once both did.
   *
   * @param {string} id The trade.
   * @param {unknown} key The player's key.
   * @returns {Promise<{status: number, body: object}>} The trade's state, or why not.
   */
  async done(id, key) {
    const player = await this.playerOf(key);

    if (!ID.test(id) || !player) {
      return badRequest("a trade id and a player key are needed");
    }

    return this.exclusive(async () => {
      const record = await this.current(id);

      if (!record || !record.players.includes(player)) {
        return noTrade();
      }

      if (record.state !== TRADE_STATE.committed) {
        return { status: 409, body: { error: "the trade is not committed" } };
      }

      if (!record.done.includes(player)) {
        record.done.push(player);
      }

      if (record.players.every((each) => record.done.includes(each))) {
        await this.store.removeTrade(record.id, record.players);
      } else {
        record.updated = this.clock();
        await this.store.putTrade(record);
      }

      return { status: 200, body: answerOf(record) };
    });
  }

  /**
   * Makes a trade from its first commit, unless the relay has too many trades, or the player too
   * many open or too many opened within a day that ended cancelled.
   *
   * The cancelled ones count, since two players could otherwise fill the relay's trades by
   * committing and cancelling in a loop.
   *
   * @param {string} id The trade.
   * @param {string} world The world.
   * @param {string} player The committing player's id.
   * @param {string} partner The other player's id.
   * @param {string} hash The hash of the offers.
   * @param {string} sealed The sealed offers.
   * @returns {Promise<{status: number, body: object}>} The pending state, or why not.
   */
  async open(id, world, player, partner, hash, sealed) {
    const records = await this.tidy();
    const now = this.clock();

    if (records.length >= this.limits.maxTrades) {
      return { status: 503, body: { error: "the relay keeps as many trades as it may" } };
    }

    if (records.filter((record) => isOpenFor(record, player)).length >= this.limits.maxOpenPerPlayer) {
      return { status: 429, body: { error: `a player may have at most ${this.limits.maxOpenPerPlayer} open trades` } };
    }

    if (records.filter((record) => isCancelledOpenedBy(record, player, now - this.limits.keepCancelledMs)).length >= this.limits.maxCancelledPerPlayer) {
      return { status: 429, body: { error: `a player may open at most ${this.limits.maxCancelledPerPlayer} trades a day that end cancelled` } };
    }

    const record = { id, world, players: [player, partner], commits: { [player]: { hash } }, state: TRADE_STATE.pending, created: now, updated: now, done: [] };
    await this.store.putTrade(record, { sealed: { [player]: sealed } });
    return { status: 200, body: answerOf(record) };
  }

  /**
   * Reads the offers a player of a trade sealed, from the record itself for a trade kept before the
   * offers were kept beside it.
   *
   * @param {object} record The trade.
   * @param {string} player The player's id.
   * @returns {Promise<string | undefined>} The sealed offers, undefined when none are kept.
   */
  async sealedOf(record, player) {
    return record.commits[player]?.sealed ?? (await this.store.getSealed(record.id, player));
  }

  /**
   * Reads a trade, cancelling it first when it stayed pending too long.
   *
   * @param {string} id The trade.
   * @returns {Promise<object | undefined>} The trade, undefined when there is none.
   */
  async current(id) {
    const record = await this.store.getTrade(id);

    if (record && this.expire(record)) {
      await this.store.putTrade(record, { drop: record.players });
    }

    return record;
  }

  /**
   * Reads every trade without its offers, cancelling those that stayed pending too long, dropping
   * those kept long enough, and moving the offers out of a trade kept while they were part of it.
   *
   * @returns {Promise<object[]>} The trades that stay.
   */
  async tidy() {
    const now = this.clock();
    const kept = [];

    for (const record of await this.store.allTrades()) {
      const ended = record.state === TRADE_STATE.committed ? record.committed + this.limits.keepCommittedMs : record.updated + this.limits.keepCancelledMs;

      if (record.state !== TRADE_STATE.pending && now >= ended) {
        await this.store.removeTrade(record.id, record.players);
        continue;
      }

      if (this.expire(record)) {
        await this.store.putTrade(record, { drop: record.players });
      } else {
        const inline = takeInlineSealed(record);

        if (inline) {
          await this.store.putTrade(record, record.state === TRADE_STATE.cancelled ? { drop: record.players } : { sealed: inline });
        }
      }

      kept.push(record);
    }

    return kept;
  }

  /**
   * Cancels a trade that stayed pending too long.
   *
   * @param {object} record The trade, changed in place.
   * @returns {boolean} Whether it was cancelled now.
   */
  expire(record) {
    const now = this.clock();

    if (record.state !== TRADE_STATE.pending || now - record.created < this.limits.pendingMs) {
      return false;
    }

    cancelRecord(record, CANCEL_REASON.expired, now);
    return true;
  }

  /**
   * Checks a commit's fields.
   *
   * @param {string} id The trade.
   * @param {any} request The commit.
   * @returns {{status: number, body: object} | null} Why it is refused, or null.
   */
  checkCommit(id, request) {
    if (!ID.test(id)) return badRequest("the trade id must be 32 lowercase hexadecimal characters");
    if (!request || typeof request !== "object") return badRequest("the commit must be a JSON object");
    if (!isId(request.player)) return badRequest("a player key is needed");
    if (!isId(request.world)) return badRequest("the world id must be 32 lowercase hexadecimal characters");
    if (!isId(request.partner)) return badRequest("the partner must be a player id");
    if (!isHash(request.hash)) return badRequest("the hash must be 64 lowercase hexadecimal characters");
    if (typeof request.sealed !== "string" || !BASE64.test(request.sealed)) return badRequest("the sealed offers must be base64");
    if (request.sealed.length > this.limits.maxSealedLength) return { status: 413, body: { error: `the sealed offers may have at most ${this.limits.maxSealedLength} characters` } };
    return null;
  }

  /**
   * Turns a player's key into the player's id.
   *
   * @param {unknown} key The key.
   * @returns {Promise<string | null>} The id, or null when it is no player key.
   */
  async playerOf(key) {
    return isId(key) ? playerIdOf(key) : null;
  }

  /**
   * Runs work after every earlier one finished, so reading and writing a trade never interleaves
   * with another request's.
   *
   * @template T
   * @param {() => Promise<T>} work The work.
   * @returns {Promise<T>} What the work returns.
   */
  exclusive(work) {
    const result = this.queue.then(work);
    this.queue = result.catch(() => {});
    return result;
  }
}

/**
 * Tells whether a player may trade in a world: one of its players, the creator always among them, and not removed.
 *
 * @param {object} entry The world's directory entry.
 * @param {string} player The player's id.
 * @returns {boolean} Whether they may.
 */
function isMember(entry, player) {
  return Boolean(entry.members?.[player]) && !(entry.bans ?? []).includes(player);
}

/**
 * Tells whether a trade still counts against a player's open trades: pending, or committed and not yet done by them.
 *
 * @param {object} record The trade.
 * @param {string} player The player's id.
 * @returns {boolean} Whether it does.
 */
function isOpenFor(record, player) {
  return record.players.includes(player) && (record.state === TRADE_STATE.pending || (record.state === TRADE_STATE.committed && !record.done.includes(player)));
}

/**
 * Tells whether a player opened a trade that ended cancelled, opened since a moment.
 *
 * @param {object} record The trade.
 * @param {string} player The player's id.
 * @param {number} since The moment.
 * @returns {boolean} Whether they did.
 */
function isCancelledOpenedBy(record, player, since) {
  return record.state === TRADE_STATE.cancelled && record.players[0] === player && record.created >= since;
}

/**
 * Cancels a trade, and takes the offers out of one kept while they were part of it.
 *
 * @param {object} record The trade, changed in place.
 * @param {string} reason Why it is cancelled, one of CANCEL_REASON.
 * @param {number} now The moment.
 */
function cancelRecord(record, reason, now) {
  record.state = TRADE_STATE.cancelled;
  record.reason = reason;
  record.updated = now;
  takeInlineSealed(record);
}

/**
 * Takes the sealed offers out of the commits of a trade kept while they were part of it.
 *
 * @param {object} record The trade, changed in place.
 * @returns {Record<string, string> | null} The offers taken, by player id, null when it held none.
 */
function takeInlineSealed(record) {
  let taken = null;

  for (const [player, commit] of Object.entries(record.commits)) {
    if (commit.sealed !== undefined) {
      taken ??= {};
      taken[player] = commit.sealed;
      delete commit.sealed;
    }
  }

  return taken;
}

/**
 * Names the other player of a trade.
 *
 * @param {object} record The trade.
 * @param {string} player One player's id.
 * @returns {string} The other's id.
 */
function otherOf(record, player) {
  return record.players[0] === player ? record.players[1] : record.players[0];
}

/**
 * Makes what a player is told of a trade.
 *
 * @param {object} record The trade.
 * @returns {{state: string, reason?: string}} The state, and why it was cancelled.
 */
function answerOf(record) {
  return record.state === TRADE_STATE.cancelled ? { state: record.state, reason: record.reason } : { state: record.state };
}

/**
 * Answers a request to the trade routes.
 *
 * @param {TradeBook} trades The trades.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when it is too large to read.
 * @param {string | null} [player] The X-MGQ-Player header of the request, which wins over the key in its body or address, which released games send.
 * @returns {Promise<{status: number, body: object}>} The answer.
 */
export async function handleTradeRequest(trades, method, url, readBody, player = null) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);
  const fromQuery = () => player || url.searchParams.get("player");

  if (parts[0] !== VERSION || parts[1] !== "trades") {
    return notFound("route");
  }

  if (parts.length === 2 && method === "GET") {
    return trades.pending(fromQuery(), url.searchParams.get("world"));
  }

  if (parts.length === 3 && method === "GET") {
    return trades.state(parts[2], fromQuery());
  }

  if (parts.length === 4 && method === "POST" && ["commit", "cancel", "done"].includes(parts[3])) {
    return withJson(readBody, trades.limits.maxBodyLength, (parsed) => {
      const body = player && parsed && typeof parsed === "object" ? { ...parsed, player } : parsed;

      if (parts[3] === "commit") {
        return trades.commit(parts[2], body);
      }

      return parts[3] === "cancel" ? trades.cancel(parts[2], body?.player) : trades.done(parts[2], body?.player);
    });
  }

  return notFound("route");
}

/**
 * The answer for a trade that does not exist, or not for the asking player.
 *
 * @returns {{status: number, body: object}} The answer.
 */
function noTrade() {
  return notFound("trade");
}
