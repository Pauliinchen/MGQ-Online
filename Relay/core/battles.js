//----------------------------------------------------------------
//  battles.js
//
//  Changelog:
//      Paulinchen  2026-10-23: Told a player who comes onto a battle that just ended how it ended
//      Paulinchen  2026-10-15: Read the battle server's boss reports and wrote the pools' lines for it
//                            - Added the players the battle server takes in late
//                            - Created
//
//----------------------------------------------------------------

// Co-op battles the battle server hosts. The game that starts a battle hands its players and
// what the server needs to the relay, which starts the battle on its battle server; the players
// then come onto the battle's channel, a WebSocket of its own beside the world room, and talk to
// the server alone. The world room stays end to end encrypted; the channel carries that one
// battle's messages in plain text, which TLS covers on the way. A relay without a battle server
// refuses, and the game hosts the battle itself as before.

import { badRequest } from "./http.js";
import { isId } from "./ids.js";
import { CLOSE, RateLimiter, VERSION, WORLD_SEATS } from "./relay.js";

/**
 * The battle server's seat on a battle channel, which no world seat reaches.
 */
export const SERVER_SEAT = 250;

/**
 * The seat the battle server names for every player of its battle.
 */
export const EVERY_PLAYER = -1;

/**
 * What a battle id is: the game's own, up to 8 base-36 characters, with room for longer ones.
 */
export const BATTLE_ID = /^[0-9a-z]{1,32}$/;

/**
 * The limits server battles keep.
 */
export const BATTLE_LIMITS = Object.freeze({
  // The setup in base64: four players' builds and the starter's switches and variables, with room.
  maxSetupLength: 1_000_000,
  maxBodyLength: 1_100_000,
  maxPlayers: 16,
  maxBattlesPerWorld: 16,
  // Battles a player may start at once, and one more every refill.
  openBurst: 10,
  openRefillMs: 6_000,
  // How long the relay waits for the battle server to take a battle.
  serveWaitMs: 5_000,
  // How long a battle waits for its first player on its channel, and how long it may last at all.
  arriveMs: 60_000,
  lifetimeMs: 2 * 60 * 60 * 1000,
});

/**
 * Why a battle ends, as its players' channels are told: the server finished it, the server's
 * connection broke, no player came, it lasted too long, or the world was deleted.
 */
export const BATTLE_END = Object.freeze({
  ended: "ended",
  server: "server",
  arrive: "arrive",
  expired: "expired",
  deleted: "deleted",
});

/**
 * The refusals a game tells apart: no battle server, a busy one, the limits, or the server's own,
 * such as its MGQ Online or game data differing from the starter's.
 */
export const BATTLE_REFUSAL = Object.freeze({
  noServer: "no_server",
  busy: "busy",
  timeout: "timeout",
  seats: "seats",
  rate: "rate",
  full: "full",
});

/**
 * Reads a battle route: /v1/worlds/<world id>/battles to start one, /v1/worlds/<world id>/battles/<battle id>
 * for its channel.
 *
 * @param {URL} url The request's address.
 * @returns {{id: string, battle: string | null} | null} The world and the battle, null for another route.
 */
export function battleRouteOf(url) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);

  if (parts.length < 4 || parts.length > 5 || parts[0] !== VERSION || parts[1] !== "worlds" || parts[3] !== "battles" || !isId(parts[2])) {
    return null;
  }

  if (parts.length === 5 && !BATTLE_ID.test(parts[4])) {
    return null;
  }

  return { id: parts[2], battle: parts[4] ?? null };
}

/**
 * Reads a request to start a battle: its id, its players' world seats and the setup for the
 * server, which the relay passes on unread.
 *
 * @param {unknown} body The request's JSON body.
 * @param {typeof BATTLE_LIMITS} [limits] The limits.
 * @returns {{battle: string, seats: number[], setup: string} | {status: number, body: object}} The request, or why it is refused.
 */
export function readOpen(body, limits = BATTLE_LIMITS) {
  const { battle, seats, setup } = body ?? {};

  if (typeof battle !== "string" || !BATTLE_ID.test(battle)) {
    return badRequest("battle must be the battle's id");
  }

  if (!Array.isArray(seats) || seats.length === 0 || seats.length > limits.maxPlayers
      || !seats.every((seat) => Number.isInteger(seat) && seat >= 0 && seat < WORLD_SEATS.max) || new Set(seats).size !== seats.length) {
    return badRequest(`seats must list 1 to ${limits.maxPlayers} distinct world seats`);
  }

  if (typeof setup !== "string" || setup.length === 0 || setup.length > limits.maxSetupLength || !/^[A-Za-z0-9+/]*={0,2}$/.test(setup)) {
    return badRequest(`setup must be base64 of at most ${limits.maxSetupLength} characters`);
  }

  return { battle, seats, setup };
}

/**
 * The battles that run, by world and battle id: their players, who may come onto their channel,
 * and the starting rate per player.
 */
export class BattleTable {
  /**
   * @param {{clock?: () => number, limits?: typeof BATTLE_LIMITS}} [options] The clock and limits, which tests change.
   */
  constructor({ clock = Date.now, limits = BATTLE_LIMITS } = {}) {
    this.clock = clock;
    this.limits = limits;
    /** @type {Map<string, {world: string, battle: string, players: Map<string, number>, came: Set<string>, startedAt: number, starter: string}>} */
    this.battles = new Map();
    /**
     * Why each battle that ended within the last limits.arriveMs ended, so its players who come
     * late learn it.
     *
     * @type {Map<string, {end: string, at: number}>}
     */
    this.ended = new Map();
    this.opens = new RateLimiter({ burst: limits.openBurst, refillMs: limits.openRefillMs }, clock);
  }

  /**
   * Checks whether a player may start a battle in a world, before the battle server is asked.
   *
   * @param {string} world The world.
   * @param {string} battle The battle's id.
   * @param {string} starter The starting player's id.
   * @returns {{status: number, body: object} | null} Why not, or null when they may.
   */
  refusalOf(world, battle, starter) {
    if (this.battles.has(keyOf(world, battle))) {
      return { status: 409, body: { error: "a battle with this id runs in the world" } };
    }

    if (this.count(world) >= this.limits.maxBattlesPerWorld) {
      return { status: 503, body: { error: `a world runs at most ${this.limits.maxBattlesPerWorld} server battles at once`, code: BATTLE_REFUSAL.full } };
    }

    if (!this.opens.take(starter)) {
      return { status: 429, body: { error: "too many battles started, try again later", code: BATTLE_REFUSAL.rate } };
    }

    return null;
  }

  /**
   * Keeps a battle the battle server took.
   *
   * @param {string} world The world.
   * @param {string} battle The battle's id.
   * @param {Map<string, number>} players Each player's world seat by their id, who alone may come onto the channel.
   * @param {string} starter The starting player's id.
   * @returns {object} The battle.
   */
  open(world, battle, players, starter) {
    const entry = { world, battle, players, came: new Set(), startedAt: this.clock(), starter };
    this.battles.set(keyOf(world, battle), entry);
    return entry;
  }

  /**
   * Finds a running battle.
   *
   * @param {string} world The world.
   * @param {string} battle The battle's id.
   * @returns {object | null} The battle.
   */
  get(world, battle) {
    return this.battles.get(keyOf(world, battle)) ?? null;
  }

  /**
   * Lets a player onto a battle's channel, as the seat they had in the world when it started.
   *
   * @param {string} world The world.
   * @param {string} battle The battle's id.
   * @param {string} player The player's id.
   * @returns {{seat: number} | {status: number, body: object}} Their seat, or why not: for a battle
   *   that ended within limits.arriveMs, 404 with how it ended, one of BATTLE_END, as its code.
   */
  admit(world, battle, player) {
    const entry = this.get(world, battle);

    if (!entry) {
      const ended = this.ended.get(keyOf(world, battle));
      return ended
        ? { status: 404, body: { error: `the battle ended: ${ended.end}`, code: ended.end } }
        : { status: 404, body: { error: "no such battle runs in the world" } };
    }

    if (!entry.players.has(player)) {
      return { status: 403, body: { error: "this player is not in the battle" } };
    }

    entry.came.add(player);
    return { seat: entry.players.get(player) };
  }

  /**
   * Adds a player the battle server takes in late, who may come onto the channel from then on;
   * a player of the battle already keeps their seat.
   *
   * @param {string} world The world.
   * @param {string} battle The battle's id.
   * @param {string} player The player's id.
   * @param {number} seat Their world seat now.
   * @returns {boolean} Whether they are a player of the battle now, false for a battle that runs no more or is full.
   */
  add(world, battle, player, seat) {
    const entry = this.get(world, battle);

    if (!entry || (!entry.players.has(player) && entry.players.size >= this.limits.maxPlayers)) {
      return false;
    }

    if (!entry.players.has(player)) {
      entry.players.set(player, seat);
    }

    return true;
  }

  /**
   * Forgets a battle, but for how it ended, see admit.
   *
   * @param {string} world The world.
   * @param {string} battle The battle's id.
   * @param {string} [end] Why it ended, one of BATTLE_END.
   */
  close(world, battle, end = BATTLE_END.ended) {
    const key = keyOf(world, battle);

    if (this.battles.delete(key)) {
      this.ended.set(key, { end, at: this.clock() });
    }
  }

  /**
   * Counts a world's running battles.
   *
   * @param {string} world The world.
   * @returns {number} How many.
   */
  count(world) {
    let count = 0;

    for (const entry of this.battles.values()) {
      if (entry.world === world) {
        count += 1;
      }
    }

    return count;
  }

  /**
   * Finds the battles whose time is up: no player came since they started, or they lasted too long;
   * forgets how the battles that ended long enough ago ended.
   *
   * @param {number} now The current time in milliseconds.
   * @returns {{world: string, battle: string, end: string}[]} The battles and why they end.
   */
  overdue(now) {
    for (const [key, { at }] of this.ended) {
      if (now - at >= this.limits.arriveMs) {
        this.ended.delete(key);
      }
    }

    const ended = [];

    for (const entry of this.battles.values()) {
      if (now - entry.startedAt >= this.limits.lifetimeMs) {
        ended.push({ world: entry.world, battle: entry.battle, end: BATTLE_END.expired });
      } else if (entry.came.size === 0 && now - entry.startedAt >= this.limits.arriveMs) {
        ended.push({ world: entry.world, battle: entry.battle, end: BATTLE_END.arrive });
      }
    }

    return ended;
  }
}

/**
 * Reads a player's message on a battle's channel: it names the server's seat, then the payload.
 * Players talk to the server alone.
 *
 * @param {Uint8Array} message The message.
 * @returns {{payload: Uint8Array, refusal: null} | {refusal: {code: number, reason: string}}} The payload, or why the message is refused.
 */
export function playerMessage(message) {
  if (message.length === 0 || message[0] !== SERVER_SEAT) {
    return { refusal: { code: CLOSE.badRequest, reason: `a battle channel's message goes to the server's seat ${SERVER_SEAT}` } };
  }

  return { payload: message.subarray(1), refusal: null };
}

/**
 * Makes the frame a player gets from the server: the server's seat, then the payload.
 *
 * @param {Uint8Array} payload The server's message.
 * @returns {Uint8Array} The frame.
 */
export function serverFrame(payload) {
  const frame = new Uint8Array(payload.length + 1);
  frame[0] = SERVER_SEAT;
  frame.set(payload, 1);
  return frame;
}

/**
 * The text frame a player gets on coming onto a battle's channel: their seat on it.
 *
 * @param {number} seat The seat.
 * @returns {string} The frame.
 */
export function battleSeatText(seat) {
  return `seat ${seat}`;
}

/**
 * The text frame a battle's players get as the battle ends, before their channels close.
 *
 * @param {string} end Why it ends, one of BATTLE_END.
 * @returns {string} The frame.
 */
export function battleClosedText(end) {
  return `closed ${end}`;
}

/**
 * The line that hands a battle to the battle server.
 *
 * @param {string} battle The battle's id.
 * @param {string} setup The setup in base64.
 * @returns {string} The line, without its line end.
 */
export function serveLine(battle, setup) {
  return JSON.stringify({ op: "serve", bid: battle, setup });
}

/**
 * The line that tells the battle server a player came onto the channel or left it.
 *
 * @param {"in" | "out"} op Which.
 * @param {number} seat The player's world seat.
 * @returns {string} The line.
 */
export function presenceLine(op, seat) {
  return JSON.stringify({ op, seat });
}

/**
 * The line that hands the battle server a player's message.
 *
 * @param {number} seat The player's world seat.
 * @param {Uint8Array} payload The message.
 * @returns {string} The line.
 */
export function messageLine(seat, payload) {
  return JSON.stringify({ op: "message", seat, text: Buffer.from(payload).toString("base64") });
}

/**
 * The line that tells the battle server how a Raid World's boss pool stands: the answer to its
 * own report, or a change another battle or an admin made.
 *
 * @param {string} key The pool's key.
 * @param {{left: number, max: number, defeated: boolean, by?: string} | null} pool The pool, null for a report the relay refused.
 * @param {boolean} answer Whether it answers the server's report.
 * @returns {string} The line.
 */
export function bossLine(key, pool, answer) {
  return JSON.stringify(pool ? { op: "boss", key, left: pool.left, max: pool.max, defeated: pool.defeated, by: pool.by ?? "", answer } : { op: "boss", key, answer });
}

/**
 * Reads a line the battle server sent: serving, refused, a message for a player or every player,
 * a report of a Raid World's boss pool, players it takes in late, or the battle's end.
 *
 * @param {string} line The line.
 * @returns {{op: "serving"} | {op: "refused", code: string, error: string} | {op: "send", seat: number, payload: Uint8Array} | {op: "boss_report", key: string, report: {battle: string, seq: number, delta: number, max: number, killed: boolean}} | {op: "admit", seats: number[]} | {op: "end", result: string} | null} What it says, null for a line it cannot read.
 */
export function readServerLine(line) {
  let fields;

  try {
    fields = JSON.parse(line);
  } catch {
    return null;
  }

  switch (fields?.op) {
    case "serving":
      return { op: "serving" };
    case "refused":
      return { op: "refused", code: String(fields.code ?? "refused"), error: String(fields.error ?? "the battle server refused the battle") };
    case "send":
      return Number.isInteger(fields.seat) && typeof fields.text === "string"
        ? { op: "send", seat: fields.seat, payload: Uint8Array.from(Buffer.from(fields.text, "base64")) }
        : null;
    case "boss_report":
      // The boss pools check the report's fields as they check a game's.
      return typeof fields.key === "string" && typeof fields.battle === "string"
        ? { op: "boss_report", key: fields.key, report: { battle: fields.battle, seq: fields.seq, delta: fields.delta, max: fields.max, killed: fields.killed } }
        : null;
    case "admit":
      return Array.isArray(fields.seats) && fields.seats.length <= WORLD_SEATS.max && fields.seats.every((seat) => Number.isInteger(seat) && seat >= 0 && seat < WORLD_SEATS.max)
        ? { op: "admit", seats: fields.seats }
        : null;
    case "end":
      return { op: "end", result: String(fields.result ?? "ended") };
    default:
      return null;
  }
}

/**
 * The key of a battle in a world.
 *
 * @param {string} world The world.
 * @param {string} battle The battle's id.
 * @returns {string} The key.
 */
function keyOf(world, battle) {
  return `${world}/${battle}`;
}
