//----------------------------------------------------------------
//  story_tracks.js
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

// A Raid World's story as the relay keeps it for good (story plan phase 2): the world's track,
// which every player who keeps up with the world plays, and a track of their own for each player
// behind it. Games send the keys their own events write as requests; the relay applies them in
// arrival order by each key's kind in the story mapping, pushes what changed to every game on the
// track with the track's revision, and answers each request it did not take as written with its
// own value. A telling lock per map and track lets one game tell a story event while the others on
// that track watch. Games speak it in `track <JSON>` text frames over their world room.

import {
  CLEAR_SWITCHES, FIRST_COUNTERS, FREEZE, FREEZE_ENDED, GREAT_DECISION, ROUTE, ROUTE_COUNTERS, VALUE as STORY_VALUE, activeRoute, compareKeys, countersOf, everyRouteDone, partOf,
  storyKey,
} from "./story.js";

/**
 * What a game names in X-MGQ-Features once it plays a Raid World's story on tracks.
 */
export const TRACKS_FEATURE = "tracks";

/**
 * The word every text frame of the tracks starts with, both ways, as `track <JSON>`.
 */
export const TRACK_FRAME = "track";

/**
 * The world's own track; a player's track is named `t<number>`.
 */
export const WORLD_TRACK = "world";

/**
 * The limits the tracks keep.
 */
export const TRACK_LIMITS = Object.freeze({
  // The writes of one frame: common event 154 writes about 1,900 keys at once.
  maxWrites: 4000,
  // The keys a game's story sends to place a player the relay does not know yet.
  maxSeedKeys: 40_000,
  maxValueLength: 4096,
  maxFreezeLength: 65_536,
  // The telling locks one player holds at once.
  maxLocks: 4,
  maxLevel: 99_999,
});

/**
 * The codes an answer names why with, for a request the relay did not take as written or a frame
 * it refused.
 */
export const TRACK_CODE = Object.freeze({
  // A key without a row in the story mapping, or a row of kind personal: the game keeps its own.
  personal: "personal",
  // A scene key: on only while a scene runs, never kept.
  scene: "scene",
  pinned: "pinned",
  // A one-way key the request would lower.
  oneWay: "one_way",
  // A count the relay keeps itself.
  count: "count",
  // A step the world keeps as another value; the writing game keeps its own while its event runs.
  step: "step",
  // A request that would move a player behind past the end of their part before their level gate.
  held: "held",
  route: "route",
  finished: "finished",
  closed: "closed",
  // A frozen raid boss fight that ended, for good.
  ended: "ended",
  // A request on a track the player is no longer on.
  track: "track",
  // A request before the game synced.
  sync: "sync",
  // A request that repeats one the relay took already.
  seen: "seen",
  bad: "bad",
  // A telling lock another game holds.
  taken: "taken",
  // More telling locks than one player may hold.
  many: "many",
});

/**
 * The kinds a key of the story has on the tracks: the story mapping's, and `freeze` for a frozen
 * raid boss fight.
 */
const KIND = Object.freeze({ personal: "personal", shared: "shared", oneWay: "one_way", scene: "scene", chest: "chest", count: "count", freeze: "freeze" });

/**
 * A key as the tracks name it: a switch, a variable or a frozen raid boss fight's troop by id, or a
 * self switch as map.event.letter, without leading zeros.
 */
const KEY = /^(?:(s|v|f)([1-9]\d{0,4})|ss(0|[1-9]\d{0,4})\.([1-9]\d{0,5})\.([A-Za-z0-9_]{1,8}))$/;

/**
 * Where a write comes from: a map event's page (`map:<map>:<event>:<page>`, pages from 1), a common
 * event (`ce:<id>`), or the game itself outside events (`game`, or `game:<what>` such as
 * `game:affection`).
 */
const SITE = /^(?:map:[1-9]\d{0,3}:[1-9]\d{0,4}:[1-9]\d{0,2}|ce:[1-9]\d{0,3}|game(?::[a-z_]{1,24})?)$/;

/**
 * A telling's id as its game names it.
 */
const TELLING = /^[A-Za-z0-9_-]{1,32}$/;

/**
 * The site of the route return (common event 154), which clears keys that only go up otherwise.
 */
const ROUTE_RETURN_SITE = "ce:154";

/**
 * The variables the story's part follows: 1001 and the routes' 1141, 1142 and 1143.
 */
const PART_KEYS = Object.freeze(["v1001", ...Object.values(ROUTE_COUNTERS).map((counter) => `v${counter.slice(1)}`)]);

/**
 * Each route by the variable that carries how far it is.
 */
const ROUTE_OF_COUNTER = Object.freeze(Object.fromEntries(Object.entries(ROUTE_COUNTERS).map(([route, counter]) => [`v${counter.slice(1)}`, route])));

/**
 * Each route by the switch its finish turns on.
 */
const ROUTE_OF_CLEAR = Object.freeze(Object.fromEntries(Object.entries(CLEAR_SWITCHES).map(([route, id]) => [`s${id}`, route])));

/**
 * Reads a variable's value as a whole number, which may be longer than a JavaScript number holds.
 *
 * @param {string | undefined} value The value as kept, such as "n12".
 * @returns {bigint | null} The number, null for a value that is none.
 */
function wholeOf(value) {
  return typeof value === "string" && /^n-?\d+$/.test(value) ? BigInt(value.slice(1)) : null;
}

/**
 * The value of a key nobody wrote: a switch or self switch off, a variable at 0; none for a frozen
 * fight.
 *
 * @param {string} key The key.
 * @returns {string | undefined} The value.
 */
function offOf(key) {
  return key.startsWith("v") ? "n0" : key.startsWith("f") ? undefined : "0";
}

/**
 * Tells whether a value fits its key: a switch or self switch "1" or "0", a variable as the games
 * write it (story_state.rbx `encode_value`), a frozen fight as world_freeze.rbx writes it.
 *
 * @param {string} key The key.
 * @param {unknown} value The value.
 * @param {typeof TRACK_LIMITS} limits The limits.
 * @returns {boolean} Whether it fits.
 */
function valueFits(key, value, limits) {
  if (typeof value !== "string") {
    return false;
  }

  if (key.startsWith("v")) {
    return value.length <= limits.maxValueLength && STORY_VALUE.test(value);
  }

  return key.startsWith("f") ? value.length <= limits.maxFreezeLength && FREEZE.test(value) : value === "1" || value === "0";
}

/**
 * Reports whether a player's level opens a part's gate: their highest base level reached it, or the
 * highest level another mod lets that character reach is below the gate and reached.
 *
 * @param {number | undefined} gate The gate, undefined for a part without one.
 * @param {{best: number, cap: number | null} | null} level The player's highest base level and its cap, null before the game named it.
 * @returns {{open: boolean, by?: string}} Whether it does, and by `level` or `cap`.
 */
export function gateOpen(gate, level) {
  if (gate === undefined) {
    return { open: true, by: "level" };
  }

  if (level && level.best >= gate) {
    return { open: true, by: "level" };
  }

  return level && level.cap !== null && level.cap < gate && level.best >= level.cap ? { open: true, by: "cap" } : { open: false };
}

/**
 * The story mapping as the tracks read it, at one revision.
 */
export class TrackRules {
  /**
   * Reads the mapping games read (StoryMapping.forGames).
   *
   * @param {{rev: number, tables: Object<string, object[]>, index: {events: number[][]} | null}} view The mapping.
   */
  constructor(view) {
    /** The mapping's revision. */
    this.rev = view.rev;
    /** The rows of story_keys by key. */
    this.keys = new Map((view.tables.keys ?? []).map((row) => [row.key, row]));
    /** The rows of story_events by key. */
    this.events = new Map((view.tables.events ?? []).map((row) => [row.key, row]));
    /** The map events whose self switches the derived index shares, as "map.event". */
    this.index = new Set((view.index?.events ?? []).map(([map, event]) => `${map}.${event}`));
    /** The count keys with the switches each counts. */
    this.counts = [...this.keys.values()].filter((row) => row.kind === KIND.count).map((row) => ({ key: row.key, from: row.counts.from, to: row.counts.to }));
    /** Each part's level gate by its id. */
    this.gates = new Map((view.tables.parts ?? []).map((row) => [row.id, row.gate]));
  }

  /**
   * Finds a key's kind and its row: a switch's or variable's by its row of story_keys; a self
   * switch's by the most fitting row of story_events (its own, its event's, the common event's that
   * wrote it, its map's letter's, its map's), else shared when the derived index names its event.
   *
   * @param {string} key The key.
   * @param {string | null} [site] Where the write came from, which a common event's row reads.
   * @returns {{kind: string, row?: object}} The kind, see KIND, and its row.
   */
  kindOf(key, site = null) {
    const [, single, , map, event, letter] = KEY.exec(key) ?? [];

    if (single === "f") {
      return { kind: KIND.freeze };
    }

    if (single) {
      const row = this.keys.get(key);
      return { kind: row?.kind ?? KIND.personal, row };
    }

    const common = /^ce:(\d+)$/.exec(site ?? "")?.[1];
    const named = [`ss${map}.${event}.${letter}`, `ss${map}.${event}.*`, ...(common ? [`ce${common}.${letter}`, `ce${common}.*`] : []), `ss${map}.*.${letter}`, `ss${map}.*.*`];
    const row = named.map((name) => this.events.get(name)).find(Boolean);

    if (row) {
      return { kind: row.chest ? KIND.chest : row.share === "shared" ? KIND.shared : KIND.personal, row };
    }

    return { kind: this.index.has(`${map}.${event}`) ? KIND.shared : KIND.personal };
  }

  /**
   * Reports whether the whole world keeps a key, players behind included: a frozen fight, or a row
   * with `wholeWorld`.
   *
   * @param {string} key The key.
   * @returns {boolean} Whether it does.
   */
  wholeWorld(key) {
    const { kind, row } = this.kindOf(key);
    return kind === KIND.freeze || row?.wholeWorld === true;
  }
}

/**
 * Tells whether a kind keeps its keys on a track.
 *
 * @param {string} kind The kind.
 * @returns {boolean} Whether it does.
 */
function kept(kind) {
  return kind === KIND.shared || kind === KIND.oneWay || kind === KIND.count || kind === KIND.freeze;
}

/**
 * The changes one batch makes to a track, read over the track's keys.
 */
class Draft {
  /**
   * Starts a draft.
   *
   * @param {string} id The track.
   * @param {Map<string, string>} keys The track's keys, which the draft never changes.
   */
  constructor(id, keys) {
    /** The track. */
    this.id = id;
    /** The track's keys. */
    this.keys = keys;
    /** The values the batch set, by key. */
    this.changes = new Map();
  }

  /**
   * Reads a key's value as the batch leaves it so far.
   *
   * @param {string} key The key.
   * @returns {string | undefined} The value, undefined for a key nobody wrote.
   */
  get(key) {
    return this.changes.has(key) ? this.changes.get(key) : this.keys.get(key);
  }

  /**
   * Sets a key.
   *
   * @param {string} key The key.
   * @param {string} value The value.
   */
  set(key, value) {
    this.changes.set(key, value);
  }

  /**
   * Lists what the batch changed against the track's keys.
   *
   * @returns {Map<string, string>} The keys and their new values.
   */
  changed() {
    return new Map([...this.changes].filter(([key, value]) => this.keys.get(key) !== value));
  }
}

/**
 * Where one world's tracks live: the world's summary, each track's keys, each player's record and
 * each part's checkpoint.
 *
 * @typedef {object} TrackStore
 * @property {() => Promise<object | undefined>} getMeta Reads the world's summary, undefined before its story started.
 * @property {(track: string) => Promise<[string, string][]>} getKeys Reads a track's keys.
 * @property {(player: string) => Promise<object | undefined>} getPlayer Reads a player's record.
 * @property {(part: string) => Promise<[string, string][] | undefined>} getCheckpoint Reads a part's checkpoint.
 * @property {(commit: {meta?: object, keys?: {track: string, drop?: boolean, set: [string, string][]}[], players?: object[], checkpoint?: {part: string, keys: [string, string][]}}) => Promise<void>} commit Keeps a batch whole or not at all: the summary, keys per track (a dropped track loses every key first), player records and a checkpoint.
 * @property {() => Promise<void>} remove Deletes everything of the world.
 */

/**
 * One Raid World's tracks, over a store of its own.
 */
export class StoryTracks {
  /**
   * Makes the tracks.
   *
   * @param {TrackStore} store Where they live.
   * @param {{mapping: () => Promise<object>, pins?: () => Promise<{pinOf: (key: string) => string | undefined, keys: string[]}>, send: (player: string, text: string) => void, limits?: typeof TRACK_LIMITS}} options The story mapping as games read it; the pins an admin set (the keyed story's, story.js pinOf, which also reads the ranges an older relay pinned at off) with the keys pinned one by one; how a frame reaches a player's game; the limits.
   */
  constructor(store, { mapping, pins = async () => ({ pinOf: () => undefined, keys: [] }), send, limits = TRACK_LIMITS }) {
    /** The store. */
    this.store = store;
    /** Reads the story mapping. */
    this.mapping = mapping;
    /** Reads the pins. */
    this.pins = pins;
    /** Sends a frame to a player's game. */
    this.send = send;
    /** The limits. */
    this.limits = limits;
    /** The work under way, which every change waits for. */
    this.queue = Promise.resolve();
    /** The world's summary, loaded with the world's keys on first use. */
    this.meta = null;
    /** The world's keys. */
    this.world = null;
    /** The players' records read so far, by player id. */
    this.players = new Map();
    /** The players' tracks' keys read so far, by track. */
    this.tracks = new Map();
    /** The games in the world room that play on tracks, by player id: seat, whether synced, level. */
    this.online = new Map();
    /** The telling locks by track and map. */
    this.locks = new Map();
    /** The mapping as last read. */
    this.rules = null;
  }

  /**
   * Notes a game that entered the world room and plays on tracks; it hears nothing before it syncs.
   *
   * @param {string} player The player's id.
   * @param {number} seat The game's seat.
   * @returns {Promise<void>} Completes once noted.
   */
  enter(player, seat) {
    return this.exclusive(async () => {
      this.online.set(player, { seat, synced: false, level: null });
    });
  }

  /**
   * Notes a game that left the world room: its telling locks end, it watches no more, and a player
   * on the world's track keeps the world's place, where a later entry finds them.
   *
   * @param {string} player The player's id.
   * @returns {Promise<void>} Completes once noted.
   */
  leave(player) {
    return this.exclusive(async () => {
      const online = this.online.get(player);

      if (!online) {
        return;
      }

      this.releaseLocks(player, "left");
      this.online.delete(player);

      if (online.synced && this.meta) {
        const record = await this.record(player);

        if (record && record.track === null) {
          record.seen = countersOf(this.world, FIRST_COUNTERS);
          await this.store.commit({ players: [record] });
        }
      }
    });
  }

  /**
   * Takes a `track` frame of a game in the world room.
   *
   * @param {string} player The player's id.
   * @param {string} text The frame, `track <JSON>`.
   * @returns {Promise<void>} Completes once answered.
   */
  frame(player, text) {
    return this.exclusive(async () => {
      if (!this.online.has(player)) {
        return;
      }

      let frame;

      try {
        frame = JSON.parse(text.slice(TRACK_FRAME.length + 1));
      } catch {
        frame = null;
      }

      const handlers = { sync: this.sync, write: this.write, level: this.level, tell: this.tell, told: this.told, watch: this.watch, route: this.route };
      const handler = frame && typeof frame === "object" && typeof frame.t === "string" && Object.hasOwn(handlers, frame.t) ? handlers[frame.t] : null;

      if (!handler) {
        this.reply(player, { t: "error", code: TRACK_CODE.bad, error: "a track frame is JSON with t one of sync, write, level, tell, told, watch, route" });
        return;
      }

      await this.ready();
      await handler.call(this, player, frame);
    });
  }

  /**
   * Places a game's player on a track and hands it the track: an unknown player or one starting
   * afresh by their story's `seed`, which also starts a world nobody played yet; a player on the
   * world's track behind once the world left the part they last saw; then the level gate.
   *
   * @param {string} player The player's id.
   * @param {any} frame `level` and, when the relay asks or the game starts afresh, `seed` (the story's keys and values) and `fresh`.
   * @returns {Promise<void>} Completes once answered.
   */
  async sync(player, frame) {
    const online = this.online.get(player);
    const level = this.readLevel(frame.level);

    if (level === false) {
      this.reply(player, { t: "error", code: TRACK_CODE.bad, error: `level must be best and cap, whole numbers of 1 to ${this.limits.maxLevel}, cap null without one` });
      return;
    }

    online.level = level ?? online.level;
    let record = await this.record(player);
    const placed = !this.meta.rev || !record || frame.fresh === true;

    if (placed && frame.seed === undefined) {
      this.reply(player, { t: "need", what: "seed" });
      return;
    }

    const seed = placed ? this.readSeed(frame.seed) : null;

    if (seed?.error) {
      this.reply(player, { t: "error", code: TRACK_CODE.bad, error: seed.error });
      return;
    }

    if (!record) {
      record = { player, track: null, seen: null, chests: {}, seq: 0 };
      this.players.set(player, record);
    }

    const commit = { players: [record] };
    let why = "sync";

    if (placed) {
      record.chests = Object.fromEntries(seed.chests);
      this.dropTrack(record, commit);
      why = this.meta.rev ? await this.placeBySeed(record, seed.keys, commit) : this.startWorld(seed.keys, commit);
    } else if (record.track === null && record.seen) {
      why = await this.placeBySeen(record, commit);
    }

    record.seen = null;
    await this.store.commit(commit);
    online.synced = true;
    const move = await this.moveOn(record);
    await this.holdPins(record);
    await this.sendState(player, move ? "moved" : why, move);
  }

  /**
   * Starts the world's story from the first player's: the keys the world keeps.
   *
   * @param {Map<string, string>} seed The seed's keys the tracks keep.
   * @param {object} commit The commit, which takes the world's summary and keys.
   * @returns {string} Why the player stands where they do: `started`.
   */
  startWorld(seed, commit) {
    const draft = new Draft(WORLD_TRACK, new Map());

    for (const [key, value] of seed) {
      draft.set(key, value);
    }

    this.recount(draft, () => undefined);
    const counters = countersOf(draft, FIRST_COUNTERS);
    this.meta = { rev: 1, part: partOf(counters), route: ROUTE.none, done: [...counters.clear], checkpoints: [], next: 1 };
    this.world = draft.changed();
    commit.meta = this.meta;
    commit.keys = [...(commit.keys ?? []), { track: WORLD_TRACK, set: [...this.world] }];
    return "started";
  }

  /**
   * Places a player the relay does not know, or one starting afresh, by their story: behind on a
   * track of their own when it is in an earlier part than the world's (the part's checkpoint, else
   * their own story there), else on the world's track.
   *
   * @param {object} record The player's record.
   * @param {Map<string, string>} seed The seed's keys the tracks keep.
   * @param {object} commit The commit.
   * @returns {Promise<string>} Why the player stands where they do: `behind` or `sync`.
   */
  async placeBySeed(record, seed, commit) {
    const own = countersOf(seed, FIRST_COUNTERS);
    const world = countersOf(this.world, FIRST_COUNTERS);
    const part = partOf(own);

    if (this.rules.gates.size === 0 || part === this.meta.part || compareKeys(storyKey(own), storyKey(world)) >= 0) {
      return "sync";
    }

    const checkpoint = this.meta.checkpoints.includes(part) ? await this.store.getCheckpoint(part) : undefined;
    this.newTrack(record, part, checkpoint ? new Map(checkpoint) : seed, commit);
    return "behind";
  }

  /**
   * Places a player who left the world's track while the world was in a part it has left since:
   * behind at that part's checkpoint.
   *
   * @param {object} record The player's record.
   * @param {object} commit The commit.
   * @returns {Promise<string>} Why the player stands where they do: `behind` or `sync`.
   */
  async placeBySeen(record, commit) {
    const part = partOf(record.seen);
    const world = countersOf(this.world, FIRST_COUNTERS);

    if (this.rules.gates.size === 0 || part === this.meta.part || compareKeys(storyKey(record.seen), storyKey(world)) >= 0 || !this.meta.checkpoints.includes(part)) {
      return "sync";
    }

    this.newTrack(record, part, new Map(await this.store.getCheckpoint(part)), commit);
    return "behind";
  }

  /**
   * Gives a player a track of their own, in place of the one they had.
   *
   * @param {object} record The player's record.
   * @param {string} part The track's part.
   * @param {Map<string, string>} keys The story it starts from; the keys the whole world keeps stay the world's.
   * @param {object} commit The commit, which takes the track's keys and the world's summary.
   */
  newTrack(record, part, keys, commit) {
    this.dropTrack(record, commit);
    const id = `t${this.meta.next}`;
    this.meta = { ...this.meta, next: this.meta.next + 1 };
    const draft = new Draft(id, new Map());

    for (const [key, value] of keys) {
      if (!this.rules.wholeWorld(key)) {
        draft.set(key, value);
      }
    }

    this.recount(draft, () => undefined);
    const own = draft.changed();
    this.tracks.set(id, own);
    record.track = { id, part, rev: 1 };
    commit.meta = this.meta;
    commit.keys = [...(commit.keys ?? []), { track: id, set: [...own] }];
  }

  /**
   * Takes a player off their track: their telling locks and watching end, and the store drops the
   * keys of a track of their own.
   *
   * @param {object} record The player's record.
   * @param {object} commit The commit.
   */
  dropTrack(record, commit) {
    this.releaseLocks(record.player, "moved");

    if (record.track === null) {
      return;
    }

    commit.keys = [...(commit.keys ?? []), { track: record.track.id, drop: true, set: [] }];
    this.tracks.delete(record.track.id);
    record.track = null;
  }

  /**
   * Moves a player behind on while their level opens their part's gate: into the next part's
   * checkpoint while the world played past it, else onto the world's track, which ends their own.
   *
   * @param {object} record The player's record.
   * @returns {Promise<{from: string, to: string, gate: number | null, by: string} | null>} The move, `to` the part or `world`; null when the player stays.
   */
  async moveOn(record) {
    const from = record.track?.part;
    let move = null;

    while (record.track) {
      const gate = this.rules.gates.get(record.track.part);
      const opened = gateOpen(gate, this.online.get(record.player)?.level ?? null);

      if (!opened.open) {
        break;
      }

      const next = nextPart(record.track.part, this.meta);
      const commit = { players: [record] };
      move = { from, to: next, gate: gate ?? null, by: opened.by };

      if (next === WORLD_TRACK) {
        this.dropTrack(record, commit);
      } else {
        this.newTrack(record, next, new Map(await this.store.getCheckpoint(next)), commit);
      }

      await this.store.commit(commit);
    }

    return move;
  }

  /**
   * Takes a game's level, as it changes: a player behind whose level opens their gate moves on.
   *
   * @param {string} player The player's id.
   * @param {any} frame `best` and `cap`.
   * @returns {Promise<void>} Completes once taken.
   */
  async level(player, frame) {
    const level = this.readLevel(frame);
    const online = this.online.get(player);

    if (!level) {
      this.reply(player, { t: "error", code: TRACK_CODE.bad, error: `level must be best and cap, whole numbers of 1 to ${this.limits.maxLevel}, cap null without one` });
      return;
    }

    online.level = level;
    const record = online.synced ? await this.record(player) : null;
    const move = record ? await this.moveOn(record) : null;

    if (move) {
      await this.holdPins(record);
      await this.sendState(player, "moved", move);
    }
  }

  /**
   * Takes a game's batch of writes, in order, and answers it; pushes what changed to every game on
   * each track it changed, the world's and the player's own.
   *
   * @param {string} player The player's id.
   * @param {any} frame `seq` (above the last batch's), `track` (the one the game plays on) and `writes`, each `[key, value, site]`.
   * @returns {Promise<void>} Completes once answered.
   */
  async write(player, frame) {
    const seq = frame.seq;

    if (!Number.isSafeInteger(seq) || seq < 1) {
      this.reply(player, { t: "error", code: TRACK_CODE.bad, error: "seq must be a whole number above 0" });
      return;
    }

    const answer = (fields) => this.reply(player, { t: "answer", seq, ...fields });

    if (!this.online.get(player).synced) {
      answer({ code: TRACK_CODE.sync });
      return;
    }

    const record = await this.record(player);
    const track = record.track?.id ?? WORLD_TRACK;

    if (seq <= record.seq) {
      answer({ code: TRACK_CODE.seen, revs: this.revsOf(record) });
      return;
    }

    if (frame.track !== track) {
      answer({ code: TRACK_CODE.track, track });
      return;
    }

    const writes = this.readWrites(frame.writes);

    if (writes.error) {
      answer({ code: TRACK_CODE.bad, error: writes.error, index: writes.index });
      return;
    }

    await this.apply(record, seq, writes.list);
  }

  /**
   * Applies a player's writes and tells every game what changed. Called inside exclusive.
   *
   * @param {object} record The player's record.
   * @param {number} seq The batch's number.
   * @param {[string, string, string][]} writes The writes.
   * @returns {Promise<void>} Completes once told.
   */
  async apply(record, seq, writes) {
    const { pinOf } = await this.pins();
    const world = new Draft(WORLD_TRACK, this.world);
    const own = record.track ? new Draft(record.track.id, await this.trackKeys(record.track.id)) : world;
    const context = { record, world, own, pinOf, route: this.meta.route, chests: new Map() };
    const outcomes = {};
    const counted = [];

    for (const [key, value, site] of writes) {
      const outcome = this.applyOne(context, key, value, site);
      // A key the batch writes again answers for its last write.
      delete outcomes[key];

      if (outcome) {
        outcomes[key] = outcome;

        if (outcome.code === TRACK_CODE.count) {
          counted.push(key);
        }
      }
    }

    for (const draft of new Set([world, own])) {
      this.recount(draft, pinOf);
    }

    for (const key of counted) {
      outcomes[key] = { code: TRACK_CODE.count, value: (record.track && !this.rules.wholeWorld(key) ? own : world).get(key) ?? "n0" };
    }

    const before = { ...this.meta };
    const worldChanged = world.changed();
    const ownChanged = own === world ? null : own.changed();
    const commit = { players: [record], keys: [] };
    const partBefore = this.meta.part;
    const checkpoint = this.advanceWorld(world, context, record.player);

    if (checkpoint) {
      commit.checkpoint = checkpoint;
    }

    if (worldChanged.size > 0 || this.meta.route !== before.route) {
      this.meta.rev += 1;
      commit.meta = this.meta;
      commit.keys.push({ track: WORLD_TRACK, set: [...worldChanged] });
    }

    if (ownChanged?.size > 0) {
      record.track = { ...record.track, rev: record.track.rev + 1 };
      commit.keys.push({ track: record.track.id, set: [...ownChanged] });
    }

    record.seq = seq;

    for (const [key, value] of context.chests) {
      record.chests[key] = value;
    }

    await this.store.commit(commit);
    worldChanged.forEach((value, key) => this.world.set(key, value));
    ownChanged?.forEach((value, key) => own.keys.set(key, value));

    this.reply(record.player, { t: "answer", seq, revs: this.revsOf(record), mapping: this.rules.rev, keys: outcomes });

    if (this.meta.rev !== before.rev) {
      this.pushWorld(before.rev, worldChanged, summaryChanged(before, this.meta));
    }

    if (ownChanged?.size > 0) {
      this.pushTrack(record, record.track.rev - 1, ownChanged);
    }

    if (this.meta.part !== partBefore) {
      await this.leaveBehind(partBefore, record.player);
    }
  }

  /**
   * Applies one write to the drafts of a batch by its key's kind.
   *
   * @param {{record: object, world: Draft, own: Draft, pinOf: (key: string) => string | undefined, route: string, chests: Map<string, string>}} context The batch: the writing player's record, the world's draft and the player's own (the same while they play the world's), the pins, the route locked so far and the chest flags written.
   * @param {string} key The key.
   * @param {string} value The value written.
   * @param {string} site Where the write came from.
   * @returns {{code: string, value?: string} | null} Why the key does not hold the value written, with the value it holds when the tracks keep it; null when it does.
   */
  applyOne(context, key, value, site) {
    const { kind, row } = this.rules.kindOf(key, site);

    if (kind === KIND.personal || kind === KIND.scene) {
      return { code: kind === KIND.personal ? TRACK_CODE.personal : TRACK_CODE.scene };
    }

    if (kind === KIND.chest) {
      context.chests.set(key, value);
      return null;
    }

    const draft = kind === KIND.freeze || row?.wholeWorld ? context.world : context.own;
    const current = draft.get(key) ?? offOf(key);
    const pinned = context.pinOf(key);

    if (pinned !== undefined) {
      return { code: TRACK_CODE.pinned, value: pinned };
    }

    if (kind === KIND.count) {
      return { code: TRACK_CODE.count };
    }

    if (kind === KIND.freeze) {
      if (current === FREEZE_ENDED && value !== FREEZE_ENDED) {
        return { code: TRACK_CODE.ended, value: FREEZE_ENDED };
      }

      draft.set(key, value);
      return null;
    }

    const stored = stepOf(row, value, draft, context.world) ?? value;
    const lowered = wholeOf(current) !== null && wholeOf(stored) !== null && wholeOf(stored) < wholeOf(current);

    if (kind === KIND.oneWay && lowered && !(row.routeReturnClears && site === ROUTE_RETURN_SITE)) {
      return { code: TRACK_CODE.oneWay, value: current };
    }

    const refused = draft.id === WORLD_TRACK ? this.routeRefusal(context, draft, key, stored) : heldRefusal(context.record.track, draft, key, stored);

    if (refused) {
      return { code: refused, value: current };
    }

    draft.set(key, stored);
    return stored === value ? null : { code: TRACK_CODE.step, value: stored };
  }

  /**
   * Tells why the world's track refuses a write by the route rules: a route under way only from the
   * Great Decision on and one at a time; while a route is locked, no other one, and no finish of a
   * route the world did not play. The first write that starts a route locks it, as the route frame
   * does.
   *
   * @param {{route: string}} context The batch, whose route lock this may take.
   * @param {Draft} draft The world's draft.
   * @param {string} key The key.
   * @param {string} value The value the world would keep.
   * @returns {string | null} The code, null when the rules let it go in.
   */
  routeRefusal(context, draft, key, value) {
    const started = ROUTE_OF_COUNTER[key];

    if (started && (wholeOf(value) ?? 0n) > 0n) {
      const running = activeRoute(countersOf(draft, FIRST_COUNTERS));

      if ((wholeOf(draft.get("v1001")) ?? 0n) < BigInt(GREAT_DECISION) || (running !== ROUTE.none && running !== started)) {
        return TRACK_CODE.route;
      }

      if (context.route === ROUTE.none) {
        const refused = lockRefusal(this.meta.done, started);

        if (refused) {
          return refused;
        }

        context.route = started;
      }

      return context.route === started ? null : TRACK_CODE.route;
    }

    const finished = ROUTE_OF_CLEAR[key];
    return finished && value === "1" && context.route !== ROUTE.none && finished !== context.route && !this.meta.done.includes(finished) ? TRACK_CODE.route : null;
  }

  /**
   * Makes the world's summary a batch leaves: its part, the routes it finished, the route lock, and
   * the checkpoint of the part it first left. Called inside exclusive, before the batch is kept.
   *
   * @param {Draft} draft The world's draft.
   * @param {{route: string}} context The batch, with the route locked by its writes.
   * @param {string} player The writing player's id.
   * @returns {{part: string, keys: [string, string][]} | null} The checkpoint to keep, null for none.
   */
  advanceWorld(draft, context, player) {
    const before = countersOf(this.world, FIRST_COUNTERS);
    const after = countersOf(draft, FIRST_COUNTERS);
    const done = [...this.meta.done, ...after.clear.filter((route) => !this.meta.done.includes(route))];
    let route = context.route;

    // The lock ends with the return from the locked route, not with a first write that has no route
    // under way while every route was finished from the start.
    if (route !== ROUTE.none && done.includes(route) && activeRoute(after) === ROUTE.none && (activeRoute(before) === route || !this.meta.done.includes(route))) {
      route = ROUTE.none;
    }

    const part = partOf(after);
    const left = this.meta.part;
    const checkpoint = part !== left && !this.meta.checkpoints.includes(left) ? { part: left, keys: [...this.storyBefore(player)] } : null;
    this.meta = { ...this.meta, part, route, done, checkpoints: checkpoint ? [...this.meta.checkpoints, left] : this.meta.checkpoints };
    return checkpoint;
  }

  /**
   * Finds the world's story right before the story event that moves it out of a part: as it stood
   * when the writing player's telling on the world's track started, else before the batch.
   *
   * @param {string} player The writing player's id.
   * @returns {Map<string, string>} The keys.
   */
  storyBefore(player) {
    const lock = [...this.locks.values()].find((each) => each.player === player && each.track === WORLD_TRACK);
    return lock?.start ?? this.world;
  }

  /**
   * Puts the players on the world's track who did not see the world leave a part behind at that
   * part's checkpoint while their level does not open its gate: every one but the writer and the
   * games watching the writer's telling.
   *
   * @param {string} left The part the world left.
   * @param {string} writer The writing player's id.
   * @returns {Promise<void>} Completes once placed.
   */
  async leaveBehind(left, writer) {
    if (this.rules.gates.size === 0 || !this.meta.checkpoints.includes(left)) {
      return;
    }

    const watching = new Set([...this.locks.values()].filter((lock) => lock.player === writer && lock.track === WORLD_TRACK).flatMap((lock) => [...lock.viewers]));
    const checkpoint = new Map(await this.store.getCheckpoint(left));

    for (const [player, online] of this.online) {
      if (player === writer || watching.has(player) || !online.synced || gateOpen(this.rules.gates.get(left), online.level).open) {
        continue;
      }

      const record = await this.record(player);

      if (record.track === null) {
        const commit = { players: [record] };
        this.newTrack(record, left, checkpoint, commit);
        await this.store.commit(commit);
        await this.holdPins(record);
        await this.sendState(player, "behind", null);
      }
    }
  }

  /**
   * Locks the route at the Great Decision for the world's track, as today's route lock does: the
   * first one wins until the world finished it and returned; a finished route and the third way
   * before both others are finished are refused.
   *
   * @param {string} player The player's id.
   * @param {any} frame `route`.
   * @returns {Promise<void>} Completes once answered.
   */
  async route(player, frame) {
    const route = frame.route;
    const answer = (fields) => this.reply(player, { t: "route", route, ...fields });

    if (!Object.keys(ROUTE_COUNTERS).includes(route)) {
      answer({ granted: false, code: TRACK_CODE.bad });
      return;
    }

    const record = this.online.get(player).synced ? await this.record(player) : null;

    if (!record || record.track !== null) {
      answer({ granted: false, code: record ? TRACK_CODE.track : TRACK_CODE.sync });
      return;
    }

    if (this.meta.route === route) {
      answer({ granted: true });
      return;
    }

    const running = activeRoute(countersOf(this.world, FIRST_COUNTERS));
    const refused = this.meta.route !== ROUTE.none || (running !== ROUTE.none && running !== route) ? TRACK_CODE.route : lockRefusal(this.meta.done, route);

    if (refused) {
      answer({ granted: false, code: refused });
      return;
    }

    const before = { ...this.meta };
    this.meta = { ...this.meta, route, rev: this.meta.rev + 1 };
    await this.store.commit({ meta: this.meta });
    answer({ granted: true });
    this.pushWorld(before.rev, new Map(), true);
  }

  /**
   * Starts or moves a game's telling: the first game to start a story event on a map tells it for
   * every game on its track, which hears of it before the teller's answer. A telling that goes on
   * on another map takes that map's lock with it.
   *
   * @param {string} player The player's id.
   * @param {any} frame `telling` (the game's id of it), `map` and `event` (the site that started it).
   * @returns {Promise<void>} Completes once answered.
   */
  async tell(player, frame) {
    const { telling, map, event } = frame;
    const answer = (fields) => this.reply(player, { t: "tell", telling, ...fields });

    if (typeof telling !== "string" || !TELLING.test(telling) || !Number.isInteger(map) || map < 1 || map > 9999 || typeof event !== "string" || !SITE.test(event) || event.startsWith("game")) {
      answer({ granted: false, code: TRACK_CODE.bad });
      return;
    }

    const online = this.online.get(player);
    const record = online.synced ? await this.record(player) : null;

    if (!record) {
      answer({ granted: false, code: TRACK_CODE.sync });
      return;
    }

    const track = record.track?.id ?? WORLD_TRACK;
    const place = `${track}\n${map}`;
    const holder = this.locks.get(place);

    if (holder && holder.player !== player) {
      answer({ granted: false, code: TRACK_CODE.taken, teller: holder.seat, holding: holder.telling, event: holder.event });
      return;
    }

    const own = [...this.locks.entries()].filter(([, lock]) => lock.player === player && lock.track === track);
    // The same telling on another map moves on with its lock; another telling of the game on this
    // map gives way to the new one.
    const replaced = own.filter(([at, lock]) => lock.telling === telling || at === place);
    const going = replaced.find(([, lock]) => lock.telling === telling)?.[1];

    if (replaced.length === 0 && own.length >= this.limits.maxLocks) {
      answer({ granted: false, code: TRACK_CODE.many });
      return;
    }

    for (const [at, lock] of replaced) {
      this.locks.delete(at);

      if (lock.telling !== telling) {
        this.pushOnTrack(track, this.toldFrame(lock, "ended"));
      }
    }

    const start = going?.start ?? (track === WORLD_TRACK ? new Map(this.world) : null);
    const lock = { telling, player, seat: online.seat, map, event, track, start, viewers: going?.viewers ?? new Set() };
    this.locks.set(place, lock);
    this.pushOnTrack(track, { t: "telling", telling, teller: lock.seat, map, event, track }, player);
    answer({ granted: true, track });
  }

  /**
   * Ends a game's telling: every game on its track hears of it with the track's revision, the one of
   * the teller's last write.
   *
   * @param {string} player The player's id.
   * @param {any} frame `telling`.
   * @returns {Promise<void>} Completes once told.
   */
  async told(player, frame) {
    const found = [...this.locks.entries()].find(([, lock]) => lock.player === player && lock.telling === frame.telling);

    if (found) {
      this.locks.delete(found[0]);
      this.pushOnTrack(found[1].track, this.toldFrame(found[1], "ended"));
    }
  }

  /**
   * Notes a game that watches another's telling on its track, which carries it along when the
   * telling moves the world out of a part.
   *
   * @param {string} player The player's id.
   * @param {any} frame `teller` (the teller's seat) and `telling`.
   * @returns {Promise<void>} Completes once answered.
   */
  async watch(player, frame) {
    const record = this.online.get(player).synced ? await this.record(player) : null;
    const track = record ? (record.track?.id ?? WORLD_TRACK) : null;
    const lock = [...this.locks.values()].find((each) => each.seat === frame.teller && each.telling === frame.telling && each.track === track);

    if (lock && lock.player !== player) {
      lock.viewers.add(player);
    }

    this.reply(player, { t: "watch", teller: frame.teller, telling: frame.telling, watching: Boolean(lock && lock.player !== player) });
  }

  /**
   * Ends a player's telling locks and their watching, as when their game left or their track ended.
   *
   * @param {string} player The player's id.
   * @param {string} why Why, as the told frame names it: `left` or `moved`.
   */
  releaseLocks(player, why) {
    for (const [place, lock] of [...this.locks]) {
      lock.viewers.delete(player);

      if (lock.player === player) {
        this.locks.delete(place);
        this.pushOnTrack(lock.track, this.toldFrame(lock, why), player);
      }
    }
  }

  /**
   * Makes the frame that tells a telling ended.
   *
   * @param {object} lock The telling's lock.
   * @param {string} why `ended`, `left` or `moved`.
   * @returns {object} The frame.
   */
  toldFrame(lock, why) {
    const rev = lock.track === WORLD_TRACK ? this.meta.rev : (this.recordOfTrack(lock.track)?.track.rev ?? 0);
    return { t: "told", telling: lock.telling, teller: lock.seat, map: lock.map, track: lock.track, rev, why };
  }

  /**
   * Holds the keys an admin pins on every track that keeps them, as a revision every game on the
   * track takes. Called once the pins changed.
   *
   * @returns {Promise<void>} Completes once told.
   */
  pinsChanged() {
    return this.exclusive(async () => {
      await this.ready();

      if (!this.meta.rev) {
        return;
      }

      const pins = await this.pins();
      const changed = pinned(new Draft(WORLD_TRACK, this.world), pins, this.rules);

      if (changed.size > 0) {
        const rev = this.meta.rev;
        this.meta = { ...this.meta, rev: rev + 1 };
        await this.store.commit({ meta: this.meta, keys: [{ track: WORLD_TRACK, set: [...changed] }] });
        changed.forEach((value, key) => this.world.set(key, value));
        this.pushWorld(rev, changed, false);
      }

      for (const [player, online] of this.online) {
        const record = online.synced ? this.players.get(player) : null;
        const own = record?.track ? await this.holdPins(record, pins) : new Map();

        if (own.size > 0) {
          this.pushTrack(record, record.track.rev - 1, own);
        }
      }
    });
  }

  /**
   * Holds the pinned keys on a player's own track, as a revision of it. Called inside exclusive.
   *
   * @param {object} record The player's record.
   * @param {{pinOf: (key: string) => string | undefined, keys: string[]}} [pins] The pins, read anew unless given.
   * @returns {Promise<Map<string, string>>} What changed, empty for a player on the world's track.
   */
  async holdPins(record, pins = null) {
    if (!record.track) {
      return new Map();
    }

    const keys = await this.trackKeys(record.track.id);
    const changed = pinned(new Draft(record.track.id, keys), pins ?? (await this.pins()), this.rules);

    if (changed.size > 0) {
      record.track = { ...record.track, rev: record.track.rev + 1 };
      await this.store.commit({ players: [record], keys: [{ track: record.track.id, set: [...changed] }] });
      changed.forEach((value, key) => keys.set(key, value));
    }

    return changed;
  }

  /**
   * Tells every synced game the story mapping's new revision, which the relay reads its requests by
   * from now on.
   *
   * @returns {Promise<void>} Completes once told.
   */
  mappingChanged() {
    return this.exclusive(async () => {
      this.rules = null;
      const view = await this.mapping();

      for (const [player, online] of this.online) {
        if (online.synced) {
          this.reply(player, { t: "mapping", rev: view.rev });
        }
      }
    });
  }

  /**
   * Deletes everything of the world's tracks, as when the world is deleted.
   *
   * @returns {Promise<void>} Completes once deleted.
   */
  remove() {
    return this.exclusive(async () => {
      await this.store.remove();
      this.meta = null;
      this.world = null;
      this.players.clear();
      this.tracks.clear();
      this.locks.clear();
    });
  }

  /**
   * Hands a game the whole of its player's track: the world's, or their own with the keys the whole
   * world keeps.
   *
   * @param {string} player The player's id.
   * @param {string} why Why: `sync`, `started`, `behind` or `moved`.
   * @param {object | null} move The move on, see moveOn, null for none.
   * @returns {Promise<void>} Completes once sent.
   */
  async sendState(player, why, move) {
    const record = this.players.get(player);
    const own = record.track ? await this.trackKeys(record.track.id) : null;
    const keys = own ? { ...Object.fromEntries([...this.world].filter(([key]) => this.rules.wholeWorld(key))), ...Object.fromEntries(own) } : Object.fromEntries(this.world);
    const track = record.track?.id ?? WORLD_TRACK;
    const tellings = [...this.locks.values()].filter((lock) => lock.track === track).map((lock) => ({ telling: lock.telling, teller: lock.seat, map: lock.map, event: lock.event }));
    const gate = record.track ? (this.rules.gates.get(record.track.part) ?? null) : null;
    this.reply(player, {
      t: "state", why, track, rev: record.track?.rev ?? this.meta.rev, part: record.track?.part ?? this.meta.part, gate, ...(move ? { move } : {}),
      world: summaryOf(this.meta), mapping: this.rules.rev, seq: record.seq, keys, chests: { ...record.chests }, tellings,
    });
  }

  /**
   * Pushes a revision of the world's track: to every synced game on it what changed, and to every
   * game on a track of its own the keys of it the whole world keeps, or the summary alone when it
   * changed.
   *
   * @param {number} prev The revision before.
   * @param {Map<string, string>} changed What changed.
   * @param {boolean} summary Whether the world's summary changed.
   */
  pushWorld(prev, changed, summary) {
    const whole = Object.fromEntries([...changed].filter(([key]) => this.rules.wholeWorld(key)));

    for (const [player, online] of this.online) {
      const record = this.players.get(player);

      if (!online.synced || !record) {
        continue;
      }

      const behind = record.track !== null;

      if (!behind || Object.keys(whole).length > 0 || summary) {
        this.reply(player, { t: "push", track: WORLD_TRACK, rev: this.meta.rev, prev, keys: behind ? whole : Object.fromEntries(changed), ...(summary ? { world: summaryOf(this.meta) } : {}) });
      }
    }
  }

  /**
   * Pushes a revision of a player's own track to their game.
   *
   * @param {object} record The player's record.
   * @param {number} prev The revision before.
   * @param {Map<string, string>} changed What changed.
   */
  pushTrack(record, prev, changed) {
    this.reply(record.player, { t: "push", track: record.track.id, rev: record.track.rev, prev, keys: Object.fromEntries(changed) });
  }

  /**
   * Sends a frame to every synced game on a track.
   *
   * @param {string} track The track.
   * @param {object} frame The frame.
   * @param {string} [except] A player who does not hear it.
   */
  pushOnTrack(track, frame, except = null) {
    for (const [player, online] of this.online) {
      const record = this.players.get(player);

      if (player !== except && online.synced && record && (record.track?.id ?? WORLD_TRACK) === track) {
        this.reply(player, frame);
      }
    }
  }

  /**
   * Sends a frame to a player's game.
   *
   * @param {string} player The player's id.
   * @param {object} frame The frame.
   */
  reply(player, frame) {
    this.send(player, `${TRACK_FRAME} ${JSON.stringify(frame)}`);
  }

  /**
   * Names the revisions of the tracks a player writes to: the world's, and their own while behind.
   *
   * @param {object} record The player's record.
   * @returns {Object<string, number>} The revisions by track.
   */
  revsOf(record) {
    return { [WORLD_TRACK]: this.meta.rev, ...(record.track ? { [record.track.id]: record.track.rev } : {}) };
  }

  /**
   * Counts the switches each count key counts on a track and sets the count; a pinned count stays.
   *
   * @param {Draft} draft The track's draft.
   * @param {(key: string) => string | undefined} pinOf The pins.
   */
  recount(draft, pinOf) {
    for (const { key, from, to } of this.rules.counts) {
      if (pinOf(key) !== undefined) {
        continue;
      }

      let count = 0;

      for (let id = from; id <= to; id++) {
        count += draft.get(`s${id}`) === "1" ? 1 : 0;
      }

      if ((draft.get(key) ?? "n0") !== `n${count}`) {
        draft.set(key, `n${count}`);
      }
    }
  }

  /**
   * Reads a batch's writes: each `[key, value, site]` with a value that fits its key.
   *
   * @param {unknown} writes The writes.
   * @returns {{list: [string, string, string][]} | {error: string, index?: number}} The writes, or why they are wrong and which one.
   */
  readWrites(writes) {
    if (!Array.isArray(writes) || writes.length === 0 || writes.length > this.limits.maxWrites) {
      return { error: `writes must list 1 to ${this.limits.maxWrites} writes` };
    }

    for (const [index, write] of writes.entries()) {
      const fits = Array.isArray(write) && write.length === 3 && typeof write[0] === "string" && KEY.test(write[0]) && valueFits(write[0], write[1], this.limits)
        && typeof write[2] === "string" && SITE.test(write[2]);

      if (!fits) {
        return { error: "each write is [key, value, site]: a key such as s12, v1001, ss7.39.A or f868, a value that fits it, and a site such as map:7:60:1, ce:154 or game", index };
      }
    }

    return { list: writes };
  }

  /**
   * Reads a seed, the story of a player the relay places: each key the tracks keep and each chest
   * flag, by the mapping; every other key stays the game's.
   *
   * @param {unknown} seed The keys and their values.
   * @returns {{keys: Map<string, string>, chests: Map<string, string>} | {error: string}} The keys the tracks keep and the chest flags, or why the seed is wrong.
   */
  readSeed(seed) {
    if (!seed || typeof seed !== "object" || Array.isArray(seed) || Object.keys(seed).length > this.limits.maxSeedKeys) {
      return { error: `the seed must be an object of at most ${this.limits.maxSeedKeys} keys and their values` };
    }

    const keys = new Map();
    const chests = new Map();

    for (const [key, value] of Object.entries(seed)) {
      if (!KEY.test(key) || !valueFits(key, value, this.limits)) {
        return { error: `the seed names a key such as s12, v1001, ss7.39.A or f868 with a value that fits it: ${key.slice(0, 40)}` };
      }

      const { kind } = this.rules.kindOf(key);

      if (kind === KIND.chest) {
        chests.set(key, value);
      } else if (kept(kind)) {
        keys.set(key, value);
      }
    }

    return { keys, chests };
  }

  /**
   * Reads a game's level.
   *
   * @param {unknown} level `best` and `cap`, null without a cap.
   * @returns {{best: number, cap: number | null} | null | false} The level, null when left out, false when wrong.
   */
  readLevel(level) {
    if (level === undefined) {
      return null;
    }

    const fits = (value) => Number.isInteger(value) && value >= 1 && value <= this.limits.maxLevel;
    return level && typeof level === "object" && fits(level.best) && (level.cap === null || level.cap === undefined || fits(level.cap)) ? { best: level.best, cap: level.cap ?? null } : false;
  }

  /**
   * Reads a player's record, once.
   *
   * @param {string} player The player's id.
   * @returns {Promise<object | undefined>} The record, undefined for a player the tracks never placed.
   */
  async record(player) {
    if (!this.players.has(player)) {
      const record = await this.store.getPlayer(player);

      if (record) {
        this.players.set(player, record);
      }
    }

    return this.players.get(player);
  }

  /**
   * Finds the record of the player whose track this is, among those read.
   *
   * @param {string} track The track.
   * @returns {object | undefined} The record.
   */
  recordOfTrack(track) {
    return [...this.players.values()].find((record) => record.track?.id === track);
  }

  /**
   * Reads a player's track's keys, once.
   *
   * @param {string} track The track.
   * @returns {Promise<Map<string, string>>} The keys.
   */
  async trackKeys(track) {
    if (!this.tracks.has(track)) {
      this.tracks.set(track, new Map(await this.store.getKeys(track)));
    }

    return this.tracks.get(track);
  }

  /**
   * Reads the world's summary and keys and the story mapping, once each. Called inside exclusive.
   *
   * @returns {Promise<void>} Completes once read.
   */
  async ready() {
    this.rules ??= new TrackRules(await this.mapping());

    if (!this.meta) {
      this.meta = (await this.store.getMeta()) ?? { rev: 0, part: partOf(FIRST_COUNTERS), route: ROUTE.none, done: [], checkpoints: [], next: 1 };
      this.world = new Map(await this.store.getKeys(WORLD_TRACK));
    }
  }

  /**
   * Runs work after the work under way, so the tracks change in the order frames arrive.
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
 * Finds the value the world keeps for a step it never shares: a step that stays each player's own
 * where it plays (`localSteps`), a battle scene's step while the main story is at its step and no
 * fight of it is frozen or over (`battleScene`), a step before a battle the event cannot lose
 * (`defeatReturns`).
 *
 * @param {object | undefined} row The key's row.
 * @param {string} value The value written.
 * @param {Draft} draft The track's draft.
 * @param {Draft} world The world's draft, which holds the frozen fights.
 * @returns {string | null} The value kept, null when the value goes in as written.
 */
function stepOf(row, value, draft, world) {
  const whole = wholeOf(value);

  if (!row || whole === null || whole < 0n || whole > 1_000_000n) {
    return null;
  }

  const step = Number(whole);

  if (row.localSteps?.steps.includes(step)) {
    return `n${row.localSteps.sharedAs}`;
  }

  const scene = row.battleScene;

  if (scene?.steps.includes(step) && wholeOf(draft.get("v1001")) === BigInt(scene.mainStep) && !scene.troops.some((troop) => world.get(`f${troop}`) !== undefined)) {
    return `n${scene.start}`;
  }

  const back = row.defeatReturns?.[String(step)];
  return back === undefined ? null : `n${back}`;
}

/**
 * Sets the pinned keys a track keeps to their pinned values: each key an admin pinned, and each key
 * the track holds that a range an older relay pinned names. The world's track alone keeps the keys
 * the whole world keeps.
 *
 * @param {Draft} draft The track's draft.
 * @param {{pinOf: (key: string) => string | undefined, keys: string[]}} pins The pins.
 * @param {TrackRules} rules The story mapping.
 * @returns {Map<string, string>} What changed.
 */
function pinned(draft, { pinOf, keys }, rules) {
  const named = new Set([...keys, ...[...draft.keys.keys()].filter((key) => pinOf(key) !== undefined)]);

  for (const key of named) {
    const value = pinOf(key);
    const keeps = draft.keys.has(key) || kept(rules.kindOf(key).kind);

    if (value !== undefined && KEY.test(key) && keeps && (draft.id === WORLD_TRACK || !rules.wholeWorld(key))) {
      draft.set(key, value);
    }
  }

  return draft.changed();
}

/**
 * Tells whether a write on a player's own track would move their story past the end of their part,
 * which waits for their level gate.
 *
 * @param {{part: string} | null} track The player's track.
 * @param {Draft} draft The track's draft.
 * @param {string} key The key.
 * @param {string} value The value the track would keep.
 * @returns {string | null} TRACK_CODE.held, or null when it may go in.
 */
function heldRefusal(track, draft, key, value) {
  if (!track || !PART_KEYS.includes(key)) {
    return null;
  }

  const counters = countersOf({ get: (name) => (name === key ? value : draft.get(name)) }, FIRST_COUNTERS);
  return partOf(counters) === track.part ? null : TRACK_CODE.held;
}

/**
 * Tells why a route may not be locked: a route the world finished while another is not, or the
 * third way before both others are finished.
 *
 * @param {string[]} done The routes the world finished.
 * @param {string} route The route.
 * @returns {string | null} The code, null when it may.
 */
function lockRefusal(done, route) {
  if (!everyRouteDone(done) && done.includes(route)) {
    return TRACK_CODE.finished;
  }

  return route === ROUTE.chaos && !(done.includes(ROUTE.ad) && done.includes(ROUTE.mr)) ? TRACK_CODE.closed : null;
}

/**
 * Finds where a player behind moves on to from a part: the next of the parts the world played that
 * has a checkpoint, the routes aside, or the world's own story once that is the world's part or none
 * is left (world_catchup.rbx `next_part`).
 *
 * @param {string} from The player's part.
 * @param {{part: string, done: string[], checkpoints: string[]}} meta The world's summary.
 * @returns {string} The part, or WORLD_TRACK.
 */
export function nextPart(from, meta) {
  const routes = Object.keys(ROUTE_COUNTERS);
  const parts = ["1", "2", "3", ...meta.done];

  if (routes.includes(meta.part) && !parts.includes(meta.part)) {
    parts.push(meta.part);
  }

  const at = parts.indexOf(from);

  if (from === meta.part || at < 0) {
    return WORLD_TRACK;
  }

  for (const candidate of parts.slice(at + 1)) {
    if (candidate === meta.part) {
      return WORLD_TRACK;
    }

    if (!routes.includes(candidate) && meta.checkpoints.includes(candidate)) {
      return candidate;
    }
  }

  return WORLD_TRACK;
}

/**
 * Makes the world's summary a game reads.
 *
 * @param {object} meta The world's summary as kept.
 * @returns {{rev: number, part: string, route: string, done: string[], checkpoints: string[]}} The summary.
 */
function summaryOf(meta) {
  return { rev: meta.rev, part: meta.part, route: meta.route, done: [...meta.done], checkpoints: [...meta.checkpoints] };
}

/**
 * Tells whether a batch changed the world's summary beyond its revision.
 *
 * @param {object} before The summary before.
 * @param {object} after The summary after.
 * @returns {boolean} Whether it did.
 */
function summaryChanged(before, after) {
  return before.part !== after.part || before.route !== after.route || before.done.length !== after.done.length || before.checkpoints.length !== after.checkpoints.length;
}
