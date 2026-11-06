//----------------------------------------------------------------
//  story_tracks.js
//
//  Changelog:
//      Paulinchen  2026-11-06: Ran one piece of work at a time through one shared queue
//                            - Started the world's track from the keyed story for every admin request, without the guards for a world never on tracks
//      Paulinchen  2026-11-05: Dropped the tracks feature, as every game the relay serves plays on tracks
//                            - Kept every variable the game uses as a place each player's own, whatever its row says
//                            - Read the story's ids from the table story.js hands on, the routes' counters too
//                            - Kept a run that gave or used up a found item, and changed no key, on the world's track and on every player's own track
//      Paulinchen  2026-11-01: Refused an admin's pins of keys the story mapping does not share
//                            - Kept the found items' marks for the whole world, whatever the mapping's row of them says
//                            - Kept the marks of the items used up for the whole world too
//      Paulinchen  2026-10-31: Named the routes the world may take at the Great Decision in its summary
//                            - Kept the run entries of each track in order and a cursor per player on it
//                            - Kept the place the world's log starts at in its summary, and its keys there
//                            - Started a world's tracks from its keyed story
//                            - Let an admin set keys of the world's track, read its story and take back its route lock
//                            - Held an admin's pins on the world's track only, so players behind keep their own story
//                            - Kept when the world's track last changed
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

// A Raid World's story as the relay keeps it for good (story plan phase 2): the world's track,
// which every player who keeps up with the world plays, and a track of their own for each player
// behind it. Games send the keys their own events write as requests; the relay applies them in
// arrival order by each key's kind in the story mapping, pushes what changed to every game on the
// track with the track's revision, and answers each request it did not take as written with its
// own value. A telling lock per map and track lets one game tell a story event while the others on
// that track watch. Each track also keeps, in order, the run entries of the events whose writes
// changed it, for good, which every game on it takes from its player's cursor. Games speak it in
// `track <JSON>` text frames over their world room. An admin's keys, pins and route lock act on the
// world's track only.

import { workQueue } from "./relay.js";
import {
  CLEAR_SWITCHES, FIRST_COUNTERS, FREEZE, FREEZE_ENDED, GREAT_DECISION, MAIN_PROGRESS, ROUTE, ROUTE_COUNTERS, STORY_IDS, VALUE as STORY_VALUE, activeRoute, compareKeys, countersOf, everyRouteDone, listsOf,
  partOf, storyKey,
} from "./story.js";

/**
 * The word every text frame of the tracks starts with, both ways, as `track <JSON>`.
 */
export const TRACK_FRAME = "track";

/**
 * The world's own track; a player's track is named `t<number>`.
 */
export const WORLD_TRACK = "world";

/**
 * The checkpoint that keeps the world's keys as they stood where its log starts.
 */
const LOG_CHECKPOINT = "log";

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
  // The characters of one run entry's JSON, far past the packed start values of any event's pages.
  maxRunLength: 32_768,
  // The run entries one frame hands a game.
  maxRunsPage: 16,
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
  // A key an admin sets or pins that the tracks keep not as set: each player's own, a scene, a chest flag,
  // or a count an admin sets.
  mapping: "mapping",
});

/**
 * The kinds a key of the story has on the tracks: the story mapping's, and `freeze` for a frozen
 * raid boss fight.
 */
const KIND = Object.freeze({ personal: "personal", shared: "shared", oneWay: "one_way", scene: "scene", chest: "chest", count: "count", freeze: "freeze" });

/**
 * A run entry's id.
 */
const RUN_ID = /^[A-Za-z0-9_:.-]{1,80}$/;

/**
 * A run entry's packed replay, in base64.
 */
const RUN_WIRE = /^[A-Za-z0-9+/=]+$/;

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
 * The site of the route return (the game's own reset of the Final Chapter), which clears keys that
 * only go up otherwise.
 */
const ROUTE_RETURN_SITE = `ce:${STORY_IDS.final_reset_event}`;

/**
 * The key of the main story's progress.
 */
const MAIN_KEY = `v${MAIN_PROGRESS}`;

/**
 * The variables the story's part follows: the main story's progress and the routes'.
 */
const PART_KEYS = Object.freeze([MAIN_KEY, ...Object.values(ROUTE_COUNTERS).map((counter) => `v${counter.slice(1)}`)]);

/**
 * Each route by the variable that carries how far it is.
 */
const ROUTE_OF_COUNTER = Object.freeze(Object.fromEntries(Object.entries(ROUTE_COUNTERS).map(([route, counter]) => [`v${counter.slice(1)}`, route])));

/**
 * Each route by the switch its finish turns on.
 */
const ROUTE_OF_CLEAR = Object.freeze(Object.fromEntries(Object.entries(CLEAR_SWITCHES).map(([route, id]) => [`s${id}`, route])));

/**
 * The rule of the Makina's found marks, the self switches of map 0 (world_catchup.rbx FOUND_MAP,
 * letter F), which the whole world keeps, players behind included, in place of the mapping's row,
 * for Makina by level: a relay seeded before the rule keeps the row without `wholeWorld`.
 */
const FOUND_MARKS = Object.freeze(["ss0.*.F"].map((key) => Object.freeze({ key, share: "shared", wholeWorld: true })));

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
    FOUND_MARKS.forEach((row) => this.events.set(row.key, row));
    // A variable the game uses as a place stays each player's own whatever its row says, as the
    // games read the mapping (MGQOnline.Game StoryMapping.Read).
    STORY_IDS.place_variables.map((id) => this.keys.get(`v${id}`)).filter((row) => row && row.kind !== KIND.personal)
      .forEach((row) => this.keys.set(row.key, { key: row.key, kind: KIND.personal, ...(row.defeatWrite ? { defeatWrite: true } : {}) }));
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
 * The story markers a place names, in its order: v1001, v1141, v1142 and v1143.
 */
const PLACE_MARKERS = 4;

/**
 * Reads the place of a story: its story markers.
 *
 * @param {Map<string, string>} keys The story's keys.
 * @returns {number[]} v1001, v1141, v1142 and v1143.
 */
function markersOf(keys) {
  const counters = countersOf(keys, FIRST_COUNTERS);
  return [counters.p, ...Object.values(ROUTE_COUNTERS).map((name) => counters[name])];
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
 * Where one world's tracks live: the world's summary, each track's keys and run entries, each
 * player's record and each part's checkpoint.
 *
 * @typedef {object} TrackStore
 * @property {() => Promise<object | undefined>} getMeta Reads the world's summary, undefined before its story started.
 * @property {(track: string) => Promise<[string, string][]>} getKeys Reads a track's keys.
 * @property {(track: string) => Promise<object[]>} getRuns Reads a track's run entries, oldest first.
 * @property {(player: string) => Promise<object | undefined>} getPlayer Reads a player's record.
 * @property {(part: string) => Promise<[string, string][] | undefined>} getCheckpoint Reads a part's checkpoint.
 * @property {(commit: {meta?: object, keys?: {track: string, drop?: boolean, set: [string, string][]}[], runs?: {track: string, drop?: boolean, add: object[]}[], players?: object[], checkpoint?: {part: string, keys: [string, string][]}}) => Promise<void>} commit Keeps a batch whole or not at all: the summary, keys per track (a dropped track loses every key first), run entries per track (a dropped track loses every entry first), player records and a checkpoint.
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
   * @param {{mapping: () => Promise<object>, pins?: () => Promise<{pinOf: (key: string) => string | undefined, keys: string[]}>, story?: () => Promise<Map<string, string> | undefined>, send: (player: string, text: string) => void, limits?: typeof TRACK_LIMITS, clock?: () => number}} options The story mapping as games read it; the pins an admin set (the keyed story's, story.js pinOf, which also reads the ranges an older relay pinned at off) with the keys pinned one by one; the keys of the world's keyed story, which a world without tracks starts them from; how a frame reaches a player's game; the limits; the clock.
   */
  constructor(store, { mapping, pins = async () => ({ pinOf: () => undefined, keys: [] }), story = async () => undefined, send, limits = TRACK_LIMITS, clock = Date.now }) {
    /** The store. */
    this.store = store;
    /** Reads the story mapping. */
    this.mapping = mapping;
    /** Reads the pins. */
    this.pins = pins;
    /** Reads the keys of the world's keyed story. */
    this.story = story;
    /** Sends a frame to a player's game. */
    this.send = send;
    /** The limits. */
    this.limits = limits;
    /** The clock, which dates each revision of the world's track. */
    this.clock = clock;
    /** The work under way, which every change waits for. */
    this.exclusive = workQueue();
    /** The world's summary, loaded with the world's keys on first use. */
    this.meta = null;
    /** The world's keys. */
    this.world = null;
    /** The world's keys where its log starts, read with the world's keys. */
    this.logKeys = new Map();
    /** The players' records read so far, by player id. */
    this.players = new Map();
    /** The players' tracks' keys read so far, by track. */
    this.tracks = new Map();
    /** The tracks' run entries read so far, by track, oldest first. */
    this.runs = new Map();
    /** The player whose write last changed each key, by track, until a run entry of theirs names the key. */
    this.marks = new Map();
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

      const handlers = { sync: this.sync, write: this.write, level: this.level, tell: this.tell, told: this.told, watch: this.watch, route: this.route, runs: this.page, took: this.took };
      const handler = frame && typeof frame === "object" && typeof frame.t === "string" && Object.hasOwn(handlers, frame.t) ? handlers[frame.t] : null;

      if (!handler) {
        this.reply(player, { t: "error", code: TRACK_CODE.bad, error: "a track frame is JSON with t one of sync, write, level, tell, told, watch, route, runs, took" });
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
   * @param {any} frame `level`, `cursors` (the cursors of the game's saved log by track) and, when the relay asks or the game starts afresh, `seed` (the story's keys and values) and `fresh`.
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

    this.placeCursors(record, frame.cursors);

    record.seen = null;
    await this.store.commit(commit);
    online.synced = true;
    const move = await this.moveOn(record);
    await this.sendState(player, move ? "moved" : why, move);
  }

  /**
   * Starts the world's story from the first player's: the keys the world keeps, its log starting at
   * their place with those keys.
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
    this.world = draft.changed();
    this.meta = { rev: 1, part: partOf(counters), route: ROUTE.none, done: [...counters.clear], checkpoints: [], next: 1, start: markersOf(this.world), at: this.clock() };
    this.logKeys = new Map(this.world);
    commit.meta = this.meta;
    commit.keys = [...(commit.keys ?? []), { track: WORLD_TRACK, set: [...this.world] }];
    commit.checkpoint = { part: LOG_CHECKPOINT, keys: [...this.logKeys] };
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
    this.runs.set(id, []);
    record.track = { id, part, rev: 1 };
    record.cursors = { ...record.cursors, [id]: 0 };
    commit.meta = this.meta;
    commit.keys = [...(commit.keys ?? []), { track: id, set: [...own] }];
  }

  /**
   * Takes a player off their track: their telling locks and watching end, and the store drops the
   * keys and run entries of a track of their own, with their cursor on it.
   *
   * @param {object} record The player's record.
   * @param {object} commit The commit.
   */
  dropTrack(record, commit) {
    this.releaseLocks(record.player, "moved");

    if (record.track === null) {
      return;
    }

    const id = record.track.id;
    commit.keys = [...(commit.keys ?? []), { track: id, drop: true, set: [] }];
    commit.runs = [...(commit.runs ?? []), { track: id, drop: true, add: [] }];
    this.tracks.delete(id);
    this.runs.delete(id);
    this.marks.delete(id);
    record.cursors = Object.fromEntries(Object.entries(record.cursors ?? {}).filter(([track]) => track !== id));
    record.track = null;
  }

  /**
   * Moves a player behind on while their level opens their part's gate: into the next part's
   * checkpoint while the world played past it, else onto the world's track, which ends their own;
   * on the world's track they walk on from their cursor there.
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
      await this.sendState(player, "moved", move);
    }
  }

  /**
   * Takes a game's batch of writes, in order, and answers it; pushes what changed to every game on
   * each track it changed, the world's and the player's own, then the run entry the batch ends
   * with, which the player's track keeps.
   *
   * @param {string} player The player's id.
   * @param {any} frame `seq` (above the last batch's), `track` (the one the game plays on), `writes`, each `[key, value, site]`, and `run`, the entry of a run that ended after them, see readRun; no writes with a run.
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

    const run = frame.run === undefined ? null : this.readRun(frame.run);

    if (run?.error) {
      answer({ code: TRACK_CODE.bad, error: run.error });
      return;
    }

    const writes = this.readWrites(frame.writes, run !== null);

    if (writes.error) {
      answer({ code: TRACK_CODE.bad, error: writes.error, index: writes.index });
      return;
    }

    await this.apply(record, seq, writes.list, run?.run ?? null);
  }

  /**
   * Applies a player's writes and the run entry after them, and tells every game what changed.
   * Called inside exclusive.
   *
   * @param {object} record The player's record.
   * @param {number} seq The batch's number.
   * @param {[string, string, string][]} writes The writes.
   * @param {object | null} [run] The run entry, see readRun; null for none.
   * @returns {Promise<void>} Completes once told.
   */
  async apply(record, seq, writes, run = null) {
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
      this.recount(draft, draft === world ? pinOf : () => undefined);
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
      this.meta = { ...this.meta, rev: this.meta.rev + 1, at: this.clock() };
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

    this.mark(WORLD_TRACK, worldChanged, record.player);

    if (ownChanged) {
      this.mark(record.track.id, ownChanged, record.player);
    }

    const track = record.track?.id ?? WORLD_TRACK;
    const kept = run ? await this.keepRun(record.player, track, run, commit) : [];
    await this.store.commit(commit);
    worldChanged.forEach((value, key) => this.world.set(key, value));
    ownChanged?.forEach((value, key) => own.keys.set(key, value));

    this.reply(record.player, { t: "answer", seq, revs: this.revsOf(record), mapping: this.rules.rev, keys: outcomes, ...(run ? { run: { id: run.id, n: kept.find((one) => one.track === track)?.entry.n ?? null } } : {}) });

    if (this.meta.rev !== before.rev) {
      this.pushWorld(before.rev, worldChanged, summaryChanged(before, this.meta));
    }

    if (ownChanged?.size > 0) {
      this.pushTrack(record, record.track.rev - 1, ownChanged);
    }

    for (const one of kept) {
      this.pushOnTrack(one.track, { t: "run", track: one.track, run: one.entry });
    }

    if (this.meta.part !== partBefore) {
      await this.leaveBehind(partBefore, record.player);
    }
  }

  /**
   * Notes the player whose write changed keys of a track.
   *
   * @param {string} track The track.
   * @param {Map<string, string>} changed The keys the write changed.
   * @param {string} player The writing player's id.
   */
  mark(track, changed, player) {
    if (changed.size === 0) {
      return;
    }

    const marks = this.marks.get(track) ?? this.marks.set(track, new Map()).get(track);
    changed.forEach((_value, key) => marks.set(key, player));
  }

  /**
   * Keeps a player's run entry on their track when the run changed the track: a key of its step
   * was last changed there by the player's own write. Every key of its step the player's writes
   * changed counts once. A run that gave or used up a found item and changed no key (`found`) goes
   * on the world's track, which later joiners walk, and on every other player's own track, so a
   * player behind gets the item at once. Called inside exclusive.
   *
   * @param {string} player The player's id.
   * @param {string} track The player's track.
   * @param {object} run The run entry, see readRun.
   * @param {object} commit The commit, which takes the entries.
   * @returns {Promise<{track: string, entry: object}[]>} Each entry as kept, with its number `n`, by track; none when the run changed nothing of the track.
   */
  async keepRun(player, track, run, commit) {
    if (run.found && run.keys.length === 0) {
      const own = [...this.players.values()].map((record) => record.track?.id).filter((id) => id && id !== track);
      return Promise.all([...new Set([WORLD_TRACK, ...own])].map((target) => this.addRun(target, run, commit)));
    }

    const marks = this.marks.get(track) ?? new Map();
    const changed = run.keys.filter((key) => marks.get(key) === player);
    changed.forEach((key) => marks.delete(key));
    return changed.length === 0 ? [] : [await this.addRun(track, run, commit)];
  }

  /**
   * Adds a run entry at the end of a track.
   *
   * @param {string} track The track.
   * @param {object} run The run entry, see readRun.
   * @param {object} commit The commit, which takes the entry.
   * @returns {Promise<{track: string, entry: object}>} The entry as kept, with its number `n`.
   */
  async addRun(track, run, commit) {
    const runs = await this.trackRuns(track);
    const entry = { ...run, n: (runs.at(-1)?.n ?? 0) + 1 };
    runs.push(entry);
    commit.runs = [...(commit.runs ?? []), { track, add: [entry] }];
    return { track, entry };
  }

  /**
   * Places a player's cursors on the world's track and on their own where their game's saved log
   * took the entries up to, before the first entry of a track it names none of: the log claims what
   * the player played, the place they stand at does not.
   *
   * @param {object} record The player's record, which takes the cursors.
   * @param {any} named The cursors the game names by track.
   */
  placeCursors(record, named) {
    const cursorOf = (track) => (named && typeof named === "object" && Number.isSafeInteger(named[track]) && named[track] >= 0 ? named[track] : 0);
    const tracks = record.track ? [WORLD_TRACK, record.track.id] : [WORLD_TRACK];
    record.cursors = Object.fromEntries(tracks.map((track) => [track, cursorOf(track)]));
  }

  /**
   * Takes a game's word that it took a run entry of its player's track, which moves their cursor
   * past it.
   *
   * @param {string} player The player's id.
   * @param {any} frame `track` and `n`, the entry's number.
   * @returns {Promise<void>} Completes once kept.
   */
  async took(player, frame) {
    const record = this.online.get(player).synced ? await this.record(player) : null;
    const track = record?.track?.id ?? WORLD_TRACK;

    if (!record || frame.track !== track || !Number.isSafeInteger(frame.n)) {
      return;
    }

    const last = (await this.trackRuns(track)).at(-1)?.n ?? 0;

    if (frame.n > (record.cursors?.[track] ?? 0) && frame.n <= last) {
      record.cursors = { ...record.cursors, [track]: frame.n };
      await this.store.commit({ players: [record] });
    }
  }

  /**
   * Hands a game the next run entries of its player's track after a number.
   *
   * @param {string} player The player's id.
   * @param {any} frame `track` and `after`.
   * @returns {Promise<void>} Completes once sent.
   */
  async page(player, frame) {
    const record = this.online.get(player).synced ? await this.record(player) : null;

    if (record && frame.track === (record.track?.id ?? WORLD_TRACK) && Number.isSafeInteger(frame.after)) {
      await this.sendRuns(player, frame.track, frame.after);
    }
  }

  /**
   * Sends a game a page of a track's run entries after a number, saying whether more follow.
   *
   * @param {string} player The player's id.
   * @param {string} track The track.
   * @param {number} after The number.
   * @returns {Promise<void>} Completes once sent.
   */
  async sendRuns(player, track, after) {
    const later = (await this.trackRuns(track)).filter((entry) => entry.n > after);
    const runs = later.slice(0, this.limits.maxRunsPage);
    this.reply(player, { t: "runs", track, runs, more: later.length > runs.length });
  }

  /**
   * Applies one write to the drafts of a batch by its key's kind.
   *
   * @param {{record: object, world: Draft, own: Draft, pinOf: (key: string) => string | undefined, route: string, chests: Map<string, string>}} context The batch: the writing player's record, the world's draft and the player's own (the same while they play the world's), the pins, which hold the world's draft only, the route locked so far and the chest flags written.
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
    const pinned = draft.id === WORLD_TRACK ? context.pinOf(key) : undefined;

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

      if ((wholeOf(draft.get(MAIN_KEY)) ?? 0n) < BigInt(GREAT_DECISION) || (running !== ROUTE.none && running !== started)) {
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

    const refused = routeRefusal(this.meta, this.runningRoute(), route);

    if (refused) {
      answer({ granted: false, code: refused });
      return;
    }

    if (this.meta.route === route) {
      answer({ granted: true });
      return;
    }

    const before = { ...this.meta };
    this.meta = { ...this.meta, route, rev: this.meta.rev + 1, at: this.clock() };
    await this.store.commit({ meta: this.meta });
    answer({ granted: true });
    this.pushWorld(before.rev, new Map(), true);
  }

  /**
   * Finds the route the world's story is under way on.
   *
   * @returns {string} The route, ROUTE.none for none.
   */
  runningRoute() {
    return activeRoute(countersOf(this.world, FIRST_COUNTERS));
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
   * Holds the keys an admin pins on the world's track, as a revision every game on it takes. Called
   * once the pins changed.
   *
   * @returns {Promise<Map<string, string>>} What changed.
   */
  pinsChanged() {
    return this.exclusive(async () => {
      await this.ready();
      const changed = pinned(new Draft(WORLD_TRACK, this.world), await this.pins(), this.rules);

      if (changed.size > 0) {
        const rev = this.meta.rev;
        this.meta = { ...this.meta, rev: rev + 1, at: this.clock() };
        await this.store.commit({ meta: this.meta, keys: [{ track: WORLD_TRACK, set: [...changed] }] });
        changed.forEach((value, key) => this.world.set(key, value));
        this.pushWorld(rev, changed, false);
      }

      return changed;
    });
  }

  /**
   * Hands an admin the world's story: its summary, its counters and, when asked, its keys.
   *
   * @param {boolean} withKeys Whether to add the keys, as story.js listsOf writes them.
   * @returns {Promise<{rev: number, part: string, route: string, done: string[], checkpoints: string[], at: number, counters: object, keys?: object}>} The story.
   */
  view(withKeys) {
    return this.exclusive(async () => {
      await this.ready();
      return this.viewOf(withKeys);
    });
  }

  /**
   * Sets keys of the world's track as an admin asks, as a revision every game on it takes: counts,
   * the part, the route lock and the checkpoints follow the keys as they follow a write, players
   * behind fall behind as for a write, and their own tracks stay as they are.
   *
   * @param {Map<string, string>} keys The keys and their values, as story.js readAdminKeys reads them.
   * @param {string} admin The admin's player id.
   * @returns {Promise<{changed: Map<string, string>, view: object} | {code: string, keys: string[]}>} What changed with the world's story after it, see view; or the keys refused, with TRACK_CODE `bad` for keys the tracks cannot name, `mapping` for keys they keep not as set, `pinned` for keys pinned at other values.
   */
  setKeys(keys, admin) {
    return this.exclusive(async () => {
      await this.ready();
      const { pinOf } = await this.pins();
      const held = [...keys].filter(([key, value]) => pinOf(key) !== undefined && pinOf(key) !== value).map(([key]) => key);
      const refused = adminRefusal(keys, this.rules, this.limits, false) ?? (held.length > 0 ? { code: TRACK_CODE.pinned, keys: held } : null);

      if (refused) {
        return refused;
      }

      const draft = new Draft(WORLD_TRACK, this.world);
      keys.forEach((value, key) => draft.set(key, value));
      this.recount(draft, pinOf);
      const running = activeRoute(countersOf(draft, FIRST_COUNTERS));
      const changed = draft.changed();

      if (changed.size === 0) {
        return { changed, view: this.viewOf(true) };
      }

      const before = { ...this.meta };
      const checkpoint = this.advanceWorld(draft, { route: running !== ROUTE.none ? running : this.meta.route }, admin);
      this.meta = { ...this.meta, rev: before.rev + 1, at: this.clock() };
      await this.store.commit({ meta: this.meta, keys: [{ track: WORLD_TRACK, set: [...changed] }], ...(checkpoint ? { checkpoint } : {}) });
      changed.forEach((value, key) => this.world.set(key, value));
      this.mark(WORLD_TRACK, changed, admin);
      this.pushWorld(before.rev, changed, summaryChanged(before, this.meta));

      if (this.meta.part !== before.part) {
        await this.leaveBehind(before.part, admin);
      }

      return { changed, view: this.viewOf(true) };
    });
  }

  /**
   * Tells which keys an admin would pin that the world's track cannot hold, before the keyed story
   * keeps the pins.
   *
   * @param {Map<string, string>} keys The keys and their values, as story.js readPins reads them.
   * @returns {Promise<{code: string, keys: string[]} | null>} The keys refused, see adminRefusal; null when the track holds them all.
   */
  pinRefusal(keys) {
    return this.exclusive(async () => {
      await this.ready();
      return adminRefusal(keys, this.rules, this.limits, true);
    });
  }

  /**
   * Takes back the route locked for the world's track, as an admin asks, so the next player who
   * chooses sets it again; refused while the world's track is on the locked route.
   *
   * @returns {Promise<{cleared: boolean, started?: true, view: object}>} Whether a lock was taken back, `started` when the world is on the locked route, and the world's story, see view.
   */
  clearRoute() {
    return this.exclusive(async () => {
      await this.ready();

      if (this.meta.route === ROUTE.none) {
        return { cleared: false, view: this.viewOf(false) };
      }

      if (activeRoute(countersOf(this.world, FIRST_COUNTERS)) === this.meta.route) {
        return { cleared: false, started: true, view: this.viewOf(false) };
      }

      const rev = this.meta.rev;
      this.meta = { ...this.meta, route: ROUTE.none, rev: rev + 1, at: this.clock() };
      await this.store.commit({ meta: this.meta });
      this.pushWorld(rev, new Map(), true);
      return { cleared: true, view: this.viewOf(false) };
    });
  }

  /**
   * Makes the world's story as an admin reads it, see view. Called inside exclusive, once ready.
   *
   * @param {boolean} withKeys Whether to add the keys.
   * @returns {object} The story.
   */
  viewOf(withKeys) {
    const { rev, part, route, done, checkpoints, at = 0 } = this.meta;
    const story = { rev, part, route, done: [...done], checkpoints: [...checkpoints], at, counters: countersOf(this.world, FIRST_COUNTERS) };
    return withKeys ? { ...story, keys: listsOf(this.world) } : story;
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
      this.runs.clear();
      this.marks.clear();
      this.locks.clear();
    });
  }

  /**
   * Lists the world's keys where its log starts that differ from the keys a state hands, a key the
   * log's start lacks at the value nobody wrote.
   *
   * @param {Object<string, string>} keys The keys the state hands.
   * @returns {Object<string, string>} Each key that differs, with its value where the log starts.
   */
  logDelta(keys) {
    const delta = {};

    for (const [key, value] of this.logKeys) {
      if (keys[key] !== value) {
        delta[key] = value;
      }
    }

    for (const [key, value] of Object.entries(keys)) {
      const off = offOf(key);

      if (!this.logKeys.has(key) && off !== undefined && value !== off) {
        delta[key] = off;
      }
    }

    return delta;
  }

  /**
   * Hands a game the whole of its player's track: the world's, or their own with the keys the whole
   * world keeps; with their cursor, the track's last run entry and the world's keys where its log
   * starts that differ from the keys handed; then the first entries after the cursor.
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
    const cursor = record.cursors?.[track] ?? 0;
    const last = (await this.trackRuns(track)).at(-1)?.n ?? 0;
    this.reply(player, {
      t: "state", why, track, rev: record.track?.rev ?? this.meta.rev, part: record.track?.part ?? this.meta.part, gate, ...(move ? { move } : {}),
      world: summaryOf(this.meta, this.runningRoute()), mapping: this.rules.rev, seq: record.seq, keys, chests: { ...record.chests }, tellings, cursor, last, log: this.logDelta(keys),
    });

    if (last > cursor) {
      await this.sendRuns(player, track, cursor);
    }
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
        this.reply(player, { t: "push", track: WORLD_TRACK, rev: this.meta.rev, prev, keys: behind ? whole : Object.fromEntries(changed), ...(summary ? { world: summaryOf(this.meta, this.runningRoute()) } : {}) });
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
   * @param {boolean} [ran] Whether the batch ends with a run entry, which may come without writes.
   * @returns {{list: [string, string, string][]} | {error: string, index?: number}} The writes, or why they are wrong and which one.
   */
  readWrites(writes, ran = false) {
    if (ran && writes === undefined) {
      return { list: [] };
    }

    if (!Array.isArray(writes) || writes.length < (ran ? 0 : 1) || writes.length > this.limits.maxWrites) {
      return { error: `writes must list 1 to ${this.limits.maxWrites} writes, or none before a run entry` };
    }

    for (const [index, write] of writes.entries()) {
      const fits = Array.isArray(write) && write.length === 3 && typeof write[0] === "string" && KEY.test(write[0]) && valueFits(write[0], write[1], this.limits)
        && typeof write[2] === "string" && SITE.test(write[2]);

      if (!fits) {
        return { error: "each write is [key, value, site]: a key such as s12, v1201, ss7.39.A or f868, a value that fits it, and a site such as map:7:60:1, ce:129 or game", index };
      }
    }

    return { list: writes };
  }

  /**
   * Reads a run entry: what the relay keeps it by, its id, site, the keys of its step and the place
   * its run started at, with who opened it and the packed replay the receivers' games play.
   *
   * @param {unknown} run `id`, `site`, `keys` (the step's keys), `place` (the story markers v1001, v1141, v1142 and v1143, null for none), `opener` (a name, null for none) and `wire`.
   * @returns {{run: {id: string, site: string, keys: string[], place: number[] | null, opener: string | null, wire: string}} | {error: string}} The entry, or why it is wrong.
   */
  readRun(run) {
    const error = { error: `a run entry is id, site, keys (1 to ${this.limits.maxWrites} keys, none for a found item's run), place (up to 4 whole numbers or null), opener (a name or null), found (true or false) and wire, at most ${this.limits.maxRunLength} characters` };

    if (!run || typeof run !== "object" || Array.isArray(run) || JSON.stringify(run).length > this.limits.maxRunLength) {
      return error;
    }

    const { id, site, keys, place = null, opener = null, found = false, wire } = run;
    const fits = typeof id === "string" && RUN_ID.test(id) && typeof site === "string" && SITE.test(site) && typeof found === "boolean"
      && Array.isArray(keys) && keys.length >= (found ? 0 : 1) && keys.length <= this.limits.maxWrites && keys.every((key) => typeof key === "string" && KEY.test(key))
      && (place === null || (Array.isArray(place) && place.length <= PLACE_MARKERS && place.every((marker) => Number.isSafeInteger(marker))))
      && (opener === null || (typeof opener === "string" && opener.length <= 64)) && typeof wire === "string" && RUN_WIRE.test(wire);
    return fits ? { run: { id, site, keys, place, opener, ...(found ? { found } : {}), wire } } : error;
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
        return { error: `the seed names a key such as s12, v1201, ss7.39.A or f868 with a value that fits it: ${key.slice(0, 40)}` };
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
   * Reads a track's run entries, once.
   *
   * @param {string} track The track.
   * @returns {Promise<object[]>} The entries, oldest first.
   */
  async trackRuns(track) {
    if (!this.runs.has(track)) {
      this.runs.set(track, await this.store.getRuns(track));
    }

    return this.runs.get(track);
  }

  /**
   * Reads the world's summary and keys and the story mapping, once each; a world without tracks
   * starts them from its keyed story, with no run entries before, and a world
   * whose tracks kept no run entries yet starts its log where it stands, keeping its keys there.
   * Called inside exclusive.
   *
   * @returns {Promise<void>} Completes once read.
   */
  async ready() {
    this.rules ??= new TrackRules(await this.mapping());

    if (!this.meta) {
      this.meta = (await this.store.getMeta()) ?? { rev: 0, part: partOf(FIRST_COUNTERS), route: ROUTE.none, done: [], checkpoints: [], next: 1 };
      this.world = new Map(await this.store.getKeys(WORLD_TRACK));
      const story = this.meta.rev ? undefined : await this.story();
      const seed = story ? this.readSeed(Object.fromEntries([...story].filter(([key, value]) => KEY.test(key) && valueFits(key, value, this.limits)))) : null;

      if (seed?.keys?.size > 0) {
        const commit = {};
        this.startWorld(seed.keys, commit);
        await this.store.commit(commit);
      }

      if (this.meta.rev && !this.meta.start) {
        this.meta = { ...this.meta, start: markersOf(this.world) };
        await this.store.commit({ meta: this.meta, checkpoint: { part: LOG_CHECKPOINT, keys: [...this.world] } });
      }

      this.logKeys = new Map((await this.store.getCheckpoint(LOG_CHECKPOINT)) ?? []);
    }
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

  if (scene?.steps.includes(step) && wholeOf(draft.get(MAIN_KEY)) === BigInt(scene.mainStep) && !scene.troops.some((troop) => world.get(`f${troop}`) !== undefined)) {
    return `n${scene.start}`;
  }

  const back = row.defeatReturns?.[String(step)];
  return back === undefined ? null : `n${back}`;
}

/**
 * Finds the keys an admin names that the world's track cannot take: TRACK_CODE `bad` for keys or
 * values the tracks cannot name, else `mapping` for keys the story mapping leaves to each player, to
 * a scene or a chest, and for counts unless the admin pins them.
 *
 * @param {Map<string, string>} keys The keys and their values.
 * @param {TrackRules} rules The story mapping.
 * @param {typeof TRACK_LIMITS} limits The limits.
 * @param {boolean} counts Whether counts go in, which the relay recounts unless pinned.
 * @returns {{code: string, keys: string[]} | null} The keys refused, null when it takes them all.
 */
function adminRefusal(keys, rules, limits, counts) {
  const bad = [...keys].filter(([key, value]) => !KEY.test(key) || !valueFits(key, value, limits)).map(([key]) => key);
  const unshared = [...keys.keys()].filter((key) => !bad.includes(key) && (!kept(rules.kindOf(key).kind) || (!counts && rules.kindOf(key).kind === KIND.count)));
  const refused = [[TRACK_CODE.bad, bad], [TRACK_CODE.mapping, unshared]].find(([, named]) => named.length > 0);
  return refused ? { code: refused[0], keys: refused[1] } : null;
}

/**
 * Sets the pinned keys the world's track keeps to their pinned values: each key an admin pinned, and
 * each key the track holds that a range an older relay pinned names.
 *
 * @param {Draft} draft The world's draft.
 * @param {{pinOf: (key: string) => string | undefined, keys: string[]}} pins The pins.
 * @param {TrackRules} rules The story mapping.
 * @returns {Map<string, string>} What changed.
 */
function pinned(draft, { pinOf, keys }, rules) {
  const named = new Set([...keys, ...[...draft.keys.keys()].filter((key) => pinOf(key) !== undefined)]);

  for (const key of named) {
    const value = pinOf(key);
    const keeps = draft.keys.has(key) || kept(rules.kindOf(key).kind);

    if (value !== undefined && KEY.test(key) && keeps) {
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
 * Tells why the world may not take a route at the Great Decision: another route locked or under
 * way, or a refusal of lockRefusal. The route locked is always granted again.
 *
 * @param {{route: string, done: string[]}} meta The world's summary as kept.
 * @param {string} running The route the world's story is under way on, ROUTE.none for none.
 * @param {string} route The route.
 * @returns {string | null} The code, null when it may.
 */
function routeRefusal(meta, running, route) {
  if (meta.route === route) {
    return null;
  }

  return meta.route !== ROUTE.none || (running !== ROUTE.none && running !== route) ? TRACK_CODE.route : lockRefusal(meta.done, route);
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
 * @param {string} running The route the world's story is under way on, ROUTE.none for none.
 * @returns {{rev: number, part: string, route: string, done: string[], open: string[], checkpoints: string[], start: number[] | null}} The summary,
 * open the routes a `route` request is granted, start the story markers where the world's log starts.
 */
function summaryOf(meta, running) {
  const open = Object.keys(ROUTE_COUNTERS).filter((route) => routeRefusal(meta, running, route) === null);
  return { rev: meta.rev, part: meta.part, route: meta.route, done: [...meta.done], open, checkpoints: [...meta.checkpoints], start: meta.start ?? null };
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
