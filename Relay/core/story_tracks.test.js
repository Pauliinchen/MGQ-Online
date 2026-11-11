//----------------------------------------------------------------
//  story_tracks.test.js
//
//  Changelog:
//      Paulinchen  2026-11-11: Checked that a sync without a level keeps the gate shut whatever level the game named before
//      Paulinchen  2026-11-08: Checked that a world's track keeps the route lock and the part checkpoints of the keyed story it starts from
//      Paulinchen  2026-11-07: Checked that a found item's run that changed keys reaches a player behind on their own track at once
//      Paulinchen  2026-11-06: Dropped the checks of a world never on tracks
//      Paulinchen  2026-11-05: Checked that a found item's run goes on the world's track and on every player's own
//                            - Dropped the check of used up items' marks, whose runs the story replay hands over
//      Paulinchen  2026-11-01: Checked that an item any player found reaches players behind and the world from them, though the mapping's row of the found marks predates the rule
//                            - Checked that the mark of an item an event used up reaches players behind and the world from them
//      Paulinchen  2026-10-31: Checked an admin's keys, pins and route lock acting on the world's story only
//                            - Checked the routes the world's summary names as open at the Great Decision
//                            - Checked the run entries kept on the tracks and the players' cursors
//                            - Checked the place a world's log starts at in its summary
//                            - Checked a world's tracks starting from its keyed story
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { WorldStory } from "./story.js";
import { StoryTracks, TRACK_CODE, WORLD_TRACK, gateOpen, nextPart } from "./story_tracks.js";

/**
 * Players' ids.
 */
const ALICE = "a1".repeat(16);
const BOB = "b2".repeat(16);
const CARA = "c3".repeat(16);
const DORA = "d4".repeat(16);

/**
 * The story mapping the tests play by.
 */
const MAPPING = Object.freeze({
  rev: 4,
  tables: {
    keys: [
      { key: "v1001", kind: "one_way" },
      { key: "v1141", kind: "one_way", routeReturnClears: true },
      { key: "v1142", kind: "one_way", routeReturnClears: true },
      { key: "v1143", kind: "one_way", routeReturnClears: true },
      { key: "s7096", kind: "shared" },
      { key: "s7097", kind: "shared" },
      { key: "s500", kind: "scene" },
      { key: "s2045", kind: "chest" },
      { key: "s3101", kind: "shared" },
      { key: "s3102", kind: "shared" },
      { key: "v1354", kind: "count", counts: { from: 3101, to: 3102 } },
      { key: "v1062", kind: "shared", defeatReturns: { 4: 3 } },
      { key: "v1052", kind: "shared", localSteps: { steps: [3, 4, 5], sharedAs: 2, places: [{ map: 484, fromX: 30 }] } },
      { key: "v1075", kind: "shared", battleScene: { steps: [15, 16], start: 14, mainStep: 33, troops: [868, 869] } },
      { key: "v3005", kind: "one_way", wholeWorld: true },
      { key: "v50", kind: "shared" },
      { key: "v60", kind: "shared" },
    ],
    events: [
      { key: "ss9.*.*", share: "shared" },
      { key: "ss9.3.A", share: "personal" },
      { key: "ce154.*", share: "shared" },
      { key: "ss12.5.A", share: "personal", chest: true },
      { key: "ss0.*.F", share: "shared" },
    ],
    parts: [
      { id: "1", name: "Part 1", ending: [], gate: 25, order: 1 },
      { id: "2", name: "Part 2", ending: [], gate: 55, order: 2 },
      { id: "3", name: "Part 3", ending: [], gate: 65, order: 3 },
    ],
  },
  index: { built: 4, stale: false, events: [[7, 39]] },
});

/**
 * Makes one world's track store in memory.
 *
 * @returns {import("./story_tracks.js").TrackStore} The store.
 */
function memoryStore() {
  const kept = { meta: undefined, keys: new Map(), runs: new Map(), players: new Map(), checkpoints: new Map() };
  const keysOf = (track) => kept.keys.get(track) ?? kept.keys.set(track, new Map()).get(track);

  return {
    getMeta: async () => structuredClone(kept.meta),
    getKeys: async (track) => [...keysOf(track)],
    getRuns: async (track) => structuredClone(kept.runs.get(track) ?? []),
    getPlayer: async (player) => structuredClone(kept.players.get(player)),
    getCheckpoint: async (part) => structuredClone(kept.checkpoints.get(part)),
    commit: async ({ meta, keys = [], runs = [], players = [], checkpoint }) => {
      kept.meta = meta ? structuredClone(meta) : kept.meta;

      for (const { track, drop, set } of keys) {
        if (drop) {
          kept.keys.delete(track);
        }

        set.forEach(([key, value]) => keysOf(track).set(key, value));
      }

      for (const { track, drop, add } of runs) {
        const list = drop ? [] : (kept.runs.get(track) ?? []);
        kept.runs.set(track, [...list, ...structuredClone(add)]);
      }

      players.forEach((record) => kept.players.set(record.player, structuredClone(record)));

      if (checkpoint) {
        kept.checkpoints.set(checkpoint.part, structuredClone(checkpoint.keys));
      }
    },
    remove: async () => {
      kept.meta = undefined;
      kept.keys.clear();
      kept.runs.clear();
      kept.players.clear();
      kept.checkpoints.clear();
    },
  };
}

/**
 * Makes a world's tracks and its games: each game enters with a seat, says frames and reads what it
 * heard since it last looked.
 *
 * @param {{pins?: Object<string, string>, story?: object, store?: import("./story_tracks.js").TrackStore}} [options] Keys an admin pinned, with their values; the world's keyed story as story.js trackStart reads it; the store, a new one in memory when left out.
 * @returns {{tracks: StoryTracks, pins: Object<string, string>, enter: (player: string, seat: number) => Promise<void>, say: (player: string, frame: object) => Promise<void>, heard: (player: string) => object[], answer: (player: string) => object | undefined}} The tracks and the games.
 */
function makeWorld({ pins = {}, story, store = memoryStore() } = {}) {
  const inboxes = new Map();
  const tracks = new StoryTracks(store, {
    mapping: async () => MAPPING,
    pins: async () => ({ pinOf: (key) => pins[key], keys: Object.keys(pins) }),
    story: async () => story,
    send: (player, text) => inboxes.get(player)?.push(JSON.parse(text.slice("track ".length))),
  });

  return {
    tracks,
    pins,
    enter: (player, seat) => {
      inboxes.set(player, []);
      return tracks.enter(player, seat);
    },
    say: (player, frame) => tracks.frame(player, `track ${JSON.stringify(frame)}`),
    heard: (player) => inboxes.get(player).splice(0),
    answer: (player) => {
      const inbox = inboxes.get(player);
      const at = inbox.findIndex((frame) => frame.t === "answer");
      return at < 0 ? undefined : inbox.splice(at, 1)[0];
    },
  };
}

/**
 * Makes a world whose story Alice started at a value of variable 1001, with more games synced on it.
 *
 * @param {number} step The value of variable 1001.
 * @param {string[]} [others] More players, synced at level 99 on the world's track.
 * @param {{pins?: Object<string, string>}} [options] See makeWorld.
 * @returns {Promise<ReturnType<typeof makeWorld>>} The world.
 */
async function startedWorld(step, others = [], options = {}) {
  const world = makeWorld(options);
  await world.enter(ALICE, 0);
  await world.say(ALICE, { t: "sync", level: { best: 99, cap: null }, seed: { v1001: `n${step}` } });

  for (const [index, player] of others.entries()) {
    await world.enter(player, index + 1);
    await world.say(player, { t: "sync", level: { best: 99, cap: null }, seed: { v1001: `n${step}` } });
  }

  [ALICE, ...others].forEach((player) => world.heard(player));
  return world;
}

/**
 * Sends a batch of writes and hands back its answer; the game keeps what else it heard.
 *
 * @param {ReturnType<typeof makeWorld>} world The world.
 * @param {string} player The writing player.
 * @param {number} seq The batch's number.
 * @param {[string, string, string?][]} writes The writes, each key, value and site (a map event's unless given).
 * @param {string} [track] The track the game plays on.
 * @returns {Promise<object>} The answer.
 */
async function write(world, player, seq, writes, track = WORLD_TRACK) {
  await world.say(player, { t: "write", seq, track, writes: writes.map(([key, value, site = "map:7:39:1"]) => [key, value, site]) });
  return world.answer(player);
}

test("a world starts from its first player's story, and a second player is asked for theirs and placed beside", async () => {
  const world = makeWorld();
  await world.enter(ALICE, 0);
  await world.say(ALICE, { t: "sync", level: { best: 5, cap: null } });
  assert.deepEqual(world.heard(ALICE), [{ t: "need", what: "seed" }]);

  await world.say(ALICE, { t: "sync", seed: { v1001: "n3", v50: "n1", s100: "1", s2045: "1", "ss12.5.A": "1" } });
  const [started] = world.heard(ALICE);
  assert.deepEqual([started.why, started.track, started.rev, started.part, started.mapping], ["started", WORLD_TRACK, 1, "1", 4]);
  assert.deepEqual(started.keys, { v1001: "n3", v50: "n1" }, "the world keeps the keys the mapping shares");
  assert.deepEqual(started.chests, { s2045: "1", "ss12.5.A": "1" }, "chest flags stay the player's own");

  await world.enter(BOB, 1);
  await world.say(BOB, { t: "sync", seed: { v1001: "n5", v50: "n9" } });
  const [placed] = world.heard(BOB);
  assert.deepEqual([placed.why, placed.track, placed.keys.v50], ["sync", WORLD_TRACK, "n1"], "a player in the world's part plays the world's story, never their own");
});

test("writes go in in the order they arrive and each batch reaches every game as one revision", async () => {
  const world = await startedWorld(3, [BOB]);
  const first = await write(world, ALICE, 1, [["v50", "n1"], ["v60", "n1"]]);
  assert.deepEqual([first.revs, first.keys], [{ world: 2 }, {}]);
  await write(world, BOB, 1, [["v50", "n2"]]);

  const pushes = world.heard(ALICE).filter((frame) => frame.t === "push");
  assert.deepEqual(pushes.map(({ rev, prev, keys }) => ({ rev, prev, keys })), [{ rev: 2, prev: 1, keys: { v50: "n1", v60: "n1" } }, { rev: 3, prev: 2, keys: { v50: "n2" } }]);
  assert.deepEqual(world.heard(BOB).map((frame) => frame.rev), [2, 3], "the writer hears its own revision too, so no revision goes missing");
});

test("personal and scene keys come back without a value, chest flags stay the player's, and counts are the relay's", async () => {
  const world = await startedWorld(3, [BOB]);
  const answer = await write(world, ALICE, 1, [["s100", "1"], ["s500", "1"], ["s2045", "1"], ["s3101", "1"], ["v1354", "n5"], ["ss9.3.A", "1"], ["ss9.4.B", "1"], ["ss7.39.A", "1"]]);
  assert.deepEqual(answer.keys, { s100: { code: TRACK_CODE.personal }, s500: { code: TRACK_CODE.scene }, v1354: { code: TRACK_CODE.count, value: "n1" }, "ss9.3.A": { code: TRACK_CODE.personal } });
  const [push] = world.heard(BOB).filter((frame) => frame.t === "push");
  assert.deepEqual(push.keys, { s3101: "1", "ss9.4.B": "1", "ss7.39.A": "1", v1354: "n1" }, "a chest flag reaches nobody else; a self switch is shared by its map's row or the derived index");

  const common = await write(world, ALICE, 2, [["ss40.2.C", "1", "ce:154"], ["ss40.2.D", "1"]]);
  assert.deepEqual(common.keys, { "ss40.2.D": { code: TRACK_CODE.personal } }, "a common event's row shares the self switches it writes");
  await world.say(ALICE, { t: "sync" });
  assert.deepEqual(world.heard(ALICE).find((frame) => frame.t === "state").chests, { s2045: "1" });
});

test("a one-way key only goes up, also past what a JavaScript number holds, but the route return may clear it", async () => {
  const world = await startedWorld(40);
  assert.deepEqual((await write(world, ALICE, 1, [["v1001", "n9007199254740993"]])).keys, {});
  assert.deepEqual((await write(world, ALICE, 2, [["v1001", "n9007199254740992"]])).keys, { v1001: { code: TRACK_CODE.oneWay, value: "n9007199254740993" } });

  await write(world, ALICE, 3, [["v1141", "n3"]]);
  assert.deepEqual((await write(world, ALICE, 4, [["v1141", "n0"]])).keys, { v1141: { code: TRACK_CODE.oneWay, value: "n3" } });
  assert.deepEqual((await write(world, ALICE, 5, [["v1141", "n0", "ce:154"]])).keys, {}, "common event 154 clears a key whose row says so");
});

test("steps the world never shares are kept as its value and answered as steps", async () => {
  const world = await startedWorld(33);
  const answer = await write(world, ALICE, 1, [["v1062", "n4"], ["v1052", "n3"], ["v1075", "n15"], ["v1062", "n5"]]);
  assert.deepEqual(answer.keys, { v1052: { code: TRACK_CODE.step, value: "n2" }, v1075: { code: TRACK_CODE.step, value: "n14" } }, "the later write of v1062 answers for it");

  await write(world, ALICE, 2, [["f868", "map:5:6:7|x"]]);
  assert.deepEqual((await write(world, ALICE, 3, [["v1075", "n15"]])).keys, {}, "a battle scene's step goes in once a fight of it is frozen");
  assert.deepEqual((await write(world, ALICE, 4, [["v1062", "n4"]])).keys, { v1062: { code: TRACK_CODE.step, value: "n3" } });
});

test("a frozen fight's end is final", async () => {
  const world = await startedWorld(18);
  await write(world, ALICE, 1, [["f868", "map:5:6:7|x"], ["f868", "0"]]);
  assert.deepEqual((await write(world, ALICE, 2, [["f868", "map:5:6:7|y"]])).keys, { f868: { code: TRACK_CODE.ended, value: "0" } });
});

test("pinned keys hold the world's story against writes, a new pin reaches every game on it as a revision, and players behind keep their own", async () => {
  const world = await startedWorld(10, [BOB], { pins: { v50: "n7" } });
  assert.deepEqual((await write(world, ALICE, 1, [["v50", "n1"]])).keys, { v50: { code: TRACK_CODE.pinned, value: "n7" } });
  await write(world, ALICE, 2, [["v1001", "n19"]]);
  await world.enter(CARA, 2);
  await world.say(CARA, { t: "sync", level: { best: 3, cap: null }, seed: { v1001: "n2", v60: "n5" } });
  assert.equal(world.heard(CARA)[0].track, "t1");
  assert.deepEqual((await write(world, CARA, 1, [["v50", "n1"]], "t1")).keys, {}, "a player behind writes a pinned key on their own track");

  world.heard(CARA);
  world.pins.v60 = "n2";
  const changed = await world.tracks.pinsChanged();
  assert.deepEqual([...changed], [["v50", "n7"], ["v60", "n2"]]);
  const push = world.heard(BOB).filter((frame) => frame.t === "push").at(-1);
  assert.deepEqual(push.keys, { v50: "n7", v60: "n2" });
  assert.deepEqual(world.heard(CARA).filter((frame) => frame.t === "push"), [], "the pin leaves a track of one's own as it is");
});

test("the first route started locks it, another route and an unplayed finish are refused, and the return ends the lock", async () => {
  const world = await startedWorld(39, [BOB]);
  assert.deepEqual((await write(world, ALICE, 1, [["v1141", "n1"]])).keys, { v1141: { code: TRACK_CODE.route, value: "n0" } }, "no route before the Great Decision");

  await write(world, ALICE, 2, [["v1001", "n40"], ["v1141", "n1"]]);
  assert.equal(world.heard(BOB).filter((frame) => frame.t === "push").at(-1).world.route, "ad");
  assert.deepEqual((await write(world, BOB, 1, [["v1142", "n1"], ["s7097", "1"]])).keys, { v1142: { code: TRACK_CODE.route, value: "n0" }, s7097: { code: TRACK_CODE.route, value: "0" } });
  await world.say(BOB, { t: "route", route: "mr" });
  assert.deepEqual(world.heard(BOB).find((frame) => frame.t === "route"), { t: "route", route: "mr", granted: false, code: TRACK_CODE.route });

  await write(world, ALICE, 3, [["s7096", "1"], ["v1141", "n0", "ce:154"], ["v1001", "n39", "ce:154"]]);
  await world.say(BOB, { t: "route", route: "ad" });
  assert.deepEqual(world.heard(BOB).find((frame) => frame.t === "route"), { t: "route", route: "ad", granted: false, code: TRACK_CODE.finished });
  await world.say(BOB, { t: "route", route: "mr" });
  assert.equal(world.heard(BOB).find((frame) => frame.t === "route").granted, true, "the return to the Great Decision ended the lock");
});

test("the world's summary names the routes a route request is granted, so games offer no other", async () => {
  const world = await startedWorld(39, [BOB]);
  const open = () => world.heard(BOB).filter((frame) => frame.world).at(-1).world.open;
  await world.enter(CARA, 2);
  await world.say(CARA, { t: "sync", level: { best: 99, cap: null }, seed: { v1001: "n39" } });
  assert.deepEqual(world.heard(CARA).find((frame) => frame.world).world.open, ["ad", "mr"], "the third way waits for both other routes");

  await write(world, ALICE, 1, [["v1001", "n40"], ["v1141", "n1"]]);
  assert.deepEqual(open(), ["ad"], "the locked route alone");
  await write(world, ALICE, 2, [["s7096", "1"], ["v1141", "n0", "ce:154"], ["v1001", "n39", "ce:154"]]);
  assert.deepEqual(open(), ["mr"], "the finished route is closed after the return");
  await write(world, ALICE, 3, [["v1001", "n40"], ["v1142", "n1"]]);
  await write(world, ALICE, 4, [["s7097", "1"], ["v1142", "n0", "ce:154"], ["v1001", "n39", "ce:154"]]);
  assert.deepEqual(open(), ["chaos"], "both routes finished open the third way alone");
});

test("the first game to start a story event on a map tells it; the lock ends with the event or with the teller leaving", async () => {
  const world = await startedWorld(3, [BOB, CARA]);
  await world.say(ALICE, { t: "tell", telling: "e1", map: 7, event: "map:7:39:1" });
  assert.deepEqual(world.heard(ALICE), [{ t: "tell", telling: "e1", granted: true, track: WORLD_TRACK }]);
  assert.deepEqual(world.heard(BOB), [{ t: "telling", telling: "e1", teller: 0, map: 7, event: "map:7:39:1", track: WORLD_TRACK }]);

  await world.say(BOB, { t: "tell", telling: "b1", map: 7, event: "map:7:40:1" });
  assert.deepEqual(world.heard(BOB), [{ t: "tell", telling: "b1", granted: false, code: TRACK_CODE.taken, teller: 0, holding: "e1", event: "map:7:39:1" }]);
  await world.say(BOB, { t: "tell", telling: "b2", map: 8, event: "map:8:1:1" });
  assert.equal(world.heard(BOB)[0].granted, true, "another map tells on its own");

  await world.say(ALICE, { t: "told", telling: "e1" });
  assert.deepEqual(world.heard(CARA).filter((frame) => frame.t === "told").map(({ telling, why, rev }) => ({ telling, why, rev })), [{ telling: "e1", why: "ended", rev: 1 }]);

  await world.tracks.leave(BOB);
  assert.deepEqual(world.heard(CARA).filter((frame) => frame.t === "told").map(({ telling, why }) => ({ telling, why })), [{ telling: "b2", why: "left" }]);
  await world.say(CARA, { t: "tell", telling: "c1", map: 8, event: "map:8:1:1" });
  assert.equal(world.heard(CARA)[0].granted, true);
});

test("a player behind plays a track of their own from their part's checkpoint, held only at its end, until their level moves them on", async () => {
  const world = await startedWorld(10, [BOB]);
  await write(world, ALICE, 1, [["v50", "n1"]]);
  await world.say(ALICE, { t: "tell", telling: "end", map: 7, event: "map:7:39:1" });
  await write(world, ALICE, 2, [["v60", "n1"]]);
  await write(world, ALICE, 3, [["v1001", "n19"]]);

  await world.enter(CARA, 2);
  await world.say(CARA, { t: "sync", level: { best: 10, cap: null }, seed: { v1001: "n2", v50: "n5" } });
  const [behind] = world.heard(CARA);
  assert.deepEqual([behind.why, behind.track, behind.part, behind.gate], ["behind", "t1", "1", 25]);
  assert.deepEqual(behind.keys, { v1001: "n10", v50: "n1" }, "the checkpoint is the world as the telling that ended the part started");

  world.heard(BOB);
  const own = await write(world, CARA, 1, [["v50", "n9"], ["v1001", "n15"], ["v1001", "n19"]], "t1");
  assert.deepEqual([own.revs, own.keys], [{ world: 4, t1: 2 }, { v1001: { code: TRACK_CODE.held, value: "n15" } }], "only the step out of the part waits for the level gate");
  assert.equal(world.heard(BOB).length, 0, "a track of one's own reaches nobody else");
  assert.equal((await write(world, CARA, 2, [["v50", "n3"]])).code, TRACK_CODE.track, "a write must name the track the player plays on");

  await world.say(CARA, { t: "level", best: 25, cap: null });
  const moved = world.heard(CARA).find((frame) => frame.t === "state");
  assert.deepEqual([moved.why, moved.track, moved.move], ["moved", WORLD_TRACK, { from: "1", to: WORLD_TRACK, gate: 25, by: "level" }]);
  assert.equal(moved.keys.v60, "n1");
});

test("a sync without a level, as after another save loads, keeps the gate shut though the game named a higher level before", async () => {
  const world = await startedWorld(10);
  await write(world, ALICE, 1, [["v1001", "n19"]]);
  await world.enter(CARA, 1);
  await world.say(CARA, { t: "sync", level: { best: 40, cap: null }, seed: { v1001: "n19" } });
  world.heard(CARA);

  await world.say(CARA, { t: "sync", fresh: true, seed: { v1001: "n2" } });
  const [placed] = world.heard(CARA);
  assert.deepEqual([placed.why, placed.track, placed.part], ["behind", "t1", "1"]);
});

test("crossing a gate moves into the next part's checkpoint while the world is past that part, and a cap below the gate opens it too", async () => {
  const world = await startedWorld(10);
  await write(world, ALICE, 1, [["v1001", "n19"]]);
  await write(world, ALICE, 2, [["v1001", "n34"]]);

  await world.enter(CARA, 1);
  await world.say(CARA, { t: "sync", level: { best: 30, cap: null }, seed: { v1001: "n2" } });
  const [moved] = world.heard(CARA);
  assert.deepEqual([moved.why, moved.track, moved.part, moved.gate, moved.keys.v1001], ["moved", "t2", "2", 55, "n19"]);

  await world.say(CARA, { t: "level", best: 50, cap: 50 });
  assert.deepEqual(world.heard(CARA)[0].move, { from: "2", to: WORLD_TRACK, gate: 55, by: "cap" }, "another mod caps the player below the gate");
  assert.deepEqual(gateOpen(55, { best: 49, cap: 50 }), { open: false });
});

test("affection is the highest any player of the world reached, players behind included", async () => {
  const world = await startedWorld(10);
  await write(world, ALICE, 1, [["v3005", "n10"], ["v1001", "n19"]]);
  await world.enter(CARA, 1);
  await world.say(CARA, { t: "sync", level: { best: 1, cap: null }, seed: { v1001: "n2" } });
  assert.equal(world.heard(CARA)[0].keys.v3005, "n10", "a player behind reads the world's affection");

  const raised = await write(world, CARA, 1, [["v3005", "n20", "game:affection"]], "t1");
  assert.deepEqual(raised.revs, { world: 3, t1: 1 });
  assert.deepEqual(world.heard(ALICE).filter((frame) => frame.t === "push").at(-1).keys, { v3005: "n20" });
  assert.deepEqual((await write(world, ALICE, 2, [["v3005", "n15", "game:affection"]])).keys, { v3005: { code: TRACK_CODE.oneWay, value: "n20" } });
});

test("an item any player found reaches the whole world, players behind included, though the mapping's row lacks wholeWorld", async () => {
  const world = await startedWorld(10);
  await write(world, ALICE, 1, [["ss0.616.F", "1"], ["v1001", "n19"]]);
  await world.enter(CARA, 1);
  await world.say(CARA, { t: "sync", level: { best: 1, cap: null }, seed: { v1001: "n2" } });
  assert.equal(world.heard(CARA)[0].keys["ss0.616.F"], "1", "a player behind reads what the world found");

  await write(world, CARA, 1, [["ss0.610.F", "1", "map:51:23:1"]], "t1");
  assert.deepEqual(world.heard(ALICE).filter((frame) => frame.t === "push").at(-1).keys, { "ss0.610.F": "1" }, "the world reads what a player behind found");
});

test("a repeated batch and one before the sync are answered without applying", async () => {
  const world = await startedWorld(3);
  await write(world, ALICE, 5, [["v50", "n1"]]);
  assert.deepEqual(await write(world, ALICE, 5, [["v50", "n2"]]), { t: "answer", seq: 5, code: TRACK_CODE.seen, revs: { world: 2 } });
  await world.enter(BOB, 1);
  assert.equal((await write(world, BOB, 1, [["v50", "n2"]])).code, TRACK_CODE.sync);
  assert.equal((await write(world, ALICE, 6, [["v50", "x"]])).code, TRACK_CODE.bad);
});

test("players who did not see the world leave a part fall behind below its gate, the teller and those watching go along", async () => {
  const world = await startedWorld(10, [BOB, CARA, DORA]);
  await world.say(BOB, { t: "level", best: 3, cap: null });
  await world.say(CARA, { t: "level", best: 3, cap: null });
  await world.say(ALICE, { t: "tell", telling: "end", map: 7, event: "map:7:39:1" });
  await world.say(CARA, { t: "watch", teller: 0, telling: "end" });
  assert.equal(world.heard(CARA).find((frame) => frame.t === "watch").watching, true);
  world.heard(BOB);
  world.heard(DORA);

  await write(world, ALICE, 1, [["v1001", "n19"]]);
  assert.deepEqual(world.heard(BOB).filter((frame) => frame.t === "state").map(({ why, track, part }) => ({ why, track, part })), [{ why: "behind", track: "t1", part: "1" }]);
  assert.equal(world.heard(CARA).filter((frame) => frame.t === "state").length, 0, "a game watching the telling goes along");
  assert.equal(world.heard(DORA).filter((frame) => frame.t === "state").length, 0, "a level past the gate goes along");
});

test("a player who left in a part the world has left since is behind when they come back", async () => {
  const world = await startedWorld(10, [BOB]);
  await world.tracks.leave(BOB);
  await write(world, ALICE, 1, [["v1001", "n19"]]);
  await world.enter(BOB, 1);
  await world.say(BOB, { t: "sync", level: { best: 3, cap: null } });
  assert.deepEqual(world.heard(BOB).map(({ why, track }) => ({ why, track })), [{ why: "behind", track: "t1" }]);
});

test("a player behind moves on to the next part the world played that has a checkpoint, and to the world from its part", () => {
  const meta = { part: "mr", done: ["ad"], checkpoints: ["1", "2", "3"] };
  assert.equal(nextPart("1", meta), "2");
  assert.equal(nextPart("3", meta), WORLD_TRACK, "a finished route is never a next part");
  assert.equal(nextPart("ad", meta), WORLD_TRACK);
  assert.equal(nextPart("mr", meta), WORLD_TRACK);
});

/**
 * Makes a run entry as a game sends it with the writes of its run.
 *
 * @param {string} id The entry's id.
 * @param {string[]} keys The keys of its step.
 * @param {number} step The value of variable 1001 its run started at.
 * @returns {object} The entry.
 */
function run(id, keys, step) {
  return { id, site: "map:7:39:1", keys, place: [step, 0, 0, 0], opener: "Ana", wire: "AAAA" };
}

test("a run entry stays only when its writes changed the track, so the second of two openers and a refused write make none", async () => {
  const world = await startedWorld(10, [BOB]);
  await world.say(ALICE, { t: "write", seq: 1, track: WORLD_TRACK, writes: [["v50", "n1", "map:7:39:1"]] });
  await world.say(BOB, { t: "write", seq: 1, track: WORLD_TRACK, writes: [["v50", "n1", "map:7:39:1"]] });
  await world.say(ALICE, { t: "write", seq: 2, track: WORLD_TRACK, run: run("first", ["v50"], 10) });
  await world.say(BOB, { t: "write", seq: 2, track: WORLD_TRACK, run: run("second", ["v50"], 10) });

  world.answer(ALICE);
  world.answer(BOB);
  assert.deepEqual([world.answer(ALICE).run, world.answer(BOB).run], [{ id: "first", n: 1 }, { id: "second", n: null }]);
  assert.deepEqual(world.heard(BOB).filter((frame) => frame.t === "run").map((frame) => [frame.track, frame.run.n, frame.run.id, frame.run.opener]), [[WORLD_TRACK, 1, "first", "Ana"]], "every game on the track hears the entry kept");

  await world.say(ALICE, { t: "write", seq: 3, track: WORLD_TRACK, writes: [["v1001", "n5", "map:7:39:1"]], run: run("lowered", ["v1001"], 10) });
  assert.deepEqual(world.answer(ALICE).run, { id: "lowered", n: null }, "a one-way key the write would lower changed nothing");
});

test("a cursor moves only by its own player's word that their game took the entry, and a sync names the cursor of the game's saved log", async () => {
  const world = await startedWorld(10, [BOB]);
  await write(world, ALICE, 1, [["v50", "n1"]]);
  await world.say(ALICE, { t: "write", seq: 2, track: WORLD_TRACK, run: run("gift", ["v50"], 10) });
  await world.say(ALICE, { t: "took", track: WORLD_TRACK, n: 1 });

  const rejoin = async (cursors) => {
    await world.tracks.leave(BOB);
    await world.enter(BOB, 1);
    await world.say(BOB, { t: "sync", level: { best: 99, cap: null }, cursors });
    return world.heard(BOB);
  };
  const [state, page] = await rejoin({ world: 0 });
  assert.deepEqual([state.cursor, state.last, page.t, page.runs.map((entry) => entry.id), page.more], [0, 1, "runs", ["gift"], false], "another player's word moves nothing");

  await world.say(BOB, { t: "took", track: WORLD_TRACK, n: 1 });
  const again = await rejoin({ world: 1 });
  assert.deepEqual([again.length, again[0].cursor], [1, 1], "entries the saved log took never come again");

  const unsaved = await rejoin({ world: 0 });
  assert.deepEqual([unsaved[0].cursor, unsaved[1].runs.map((entry) => entry.id)], [0, ["gift"]], "a save that never kept what the game took gets the entry again");
});

test("a track keeps every run entry, so a cursor far behind still gets the first", async () => {
  const world = await startedWorld(10, [BOB]);

  for (let index = 1; index <= 1001; index++) {
    await world.say(ALICE, { t: "write", seq: index, track: WORLD_TRACK, writes: [["v50", `n${index}`, "map:7:39:1"]], run: run(`gift${index}`, ["v50"], 10) });
  }

  const [state, page] = await (async () => {
    await world.tracks.leave(BOB);
    await world.enter(BOB, 1);
    await world.say(BOB, { t: "sync", level: { best: 99, cap: null }, cursors: { world: 0 } });
    return world.heard(BOB);
  })();
  assert.deepEqual([state.last, page.runs[0].n, page.more], [1001, 1, true]);
});

test("a player who reaches the world's track from their own walks it from their world cursor, the world's runs they never played among them", async () => {
  const world = await startedWorld(10);
  await write(world, ALICE, 1, [["v50", "n1"]]);
  await world.say(ALICE, { t: "write", seq: 2, track: WORLD_TRACK, run: run("early", ["v50"], 10) });
  await write(world, ALICE, 3, [["v1001", "n19"]]);
  await write(world, ALICE, 4, [["v60", "n1"]]);
  await world.say(ALICE, { t: "write", seq: 5, track: WORLD_TRACK, run: run("later", ["v60"], 19) });

  await world.enter(CARA, 1);
  await world.say(CARA, { t: "sync", level: { best: 10, cap: null }, seed: { v1001: "n2" }, cursors: {} });
  await write(world, CARA, 1, [["v1001", "n15"], ["v50", "n7"]], "t1");
  await world.say(CARA, { t: "write", seq: 2, track: "t1", run: run("own", ["v50"], 10) });
  assert.deepEqual(world.answer(CARA).run, { id: "own", n: 1 }, "a track of one's own keeps its own entries");
  world.heard(CARA);

  await world.say(CARA, { t: "level", best: 25, cap: null });
  const [moved, page] = world.heard(CARA);
  assert.deepEqual([moved.track, moved.cursor, moved.last], [WORLD_TRACK, 0, 2], "their game's log claims what they played on their own track, not their place");
  assert.deepEqual(page.runs.map((entry) => entry.id), ["early", "later"]);
});

test("a run that gave a found item and changed no key goes on the world's track and every other player's own, which a later joiner walks", async () => {
  const world = await startedWorld(10, [BOB]);
  await write(world, ALICE, 1, [["v1001", "n19"]]);
  await world.enter(CARA, 1);
  await world.say(CARA, { t: "sync", level: { best: 10, cap: null }, seed: { v1001: "n2" }, cursors: {} });
  await write(world, CARA, 1, [["v1001", "n15"]], "t1");
  world.heard(CARA);

  await world.say(ALICE, { t: "write", seq: 2, track: WORLD_TRACK, run: { ...run("pass", [], 19), found: true } });
  assert.deepEqual(world.answer(ALICE).run, { id: "pass", n: 1 });
  assert.deepEqual([world.heard(BOB), world.heard(CARA)].map((frames) => frames.filter((frame) => frame.t === "run").map((frame) => [frame.track, frame.run.id])),
    [[[WORLD_TRACK, "pass"]], [["t1", "pass"]]], "a player behind gets it on their own track at once");

  await write(world, ALICE, 3, [["v50", "n1"]]);
  await world.say(ALICE, { t: "write", seq: 4, track: WORLD_TRACK, run: { ...run("chest", ["v50"], 19), found: true } });
  assert.deepEqual([world.heard(BOB), world.heard(CARA)].map((frames) => frames.filter((frame) => frame.t === "run").map((frame) => [frame.track, frame.run.id])),
    [[[WORLD_TRACK, "chest"]], [["t1", "chest"]]], "so does a run that also changed keys of the world's story");

  await world.say(BOB, { t: "write", seq: 1, track: WORLD_TRACK, run: run("nothing", [], 10) });
  assert.equal(world.answer(BOB).code, TRACK_CODE.bad, "a run without a key and without a found item is no entry");
});

test("a world that kept a keyed story starts its tracks from it, with no run entries before", async () => {
  const world = makeWorld({ story: { keys: new Map([["v1001", "n12"], ["v50", "n4"], ["s100", "1"], ["a5", "n3"]]), route: "none", checkpoints: new Map() } });
  await world.enter(ALICE, 0);
  await world.say(ALICE, { t: "sync", level: { best: 99, cap: null }, seed: { v1001: "n12", v50: "n9" } });
  const [state] = world.heard(ALICE);
  assert.deepEqual([state.why, state.keys, state.cursor, state.last], ["sync", { v1001: "n12", v50: "n4" }, 0, 0]);
});

test("a world's track keeps the route lock and the part checkpoints of a keyed story from before tracks", async () => {
  const lists = (v) => ({ s: "", sf: "", v, ss: "", ssf: "", a: "", f: "" });
  const counters = (p) => ({ p, r1141: 0, r1142: 0, r1143: 0, clear: [] });
  const kept = {
    story: { rev: 9, wrev: 9, counters: counters(40), part: "3", route: "chaos", done: [], end: null, comps: [], caps: [], checkpoints: ["1"], at: 1000, by: ALICE, lists: lists("1001:n40,50:n6"), log: [], logBase: 9 },
    checkpoint: { rev: 3, wrev: 3, counters: counters(19), part: "1", route: "none", done: [], end: null, at: 900, by: ALICE, lists: lists("1001:n10,50:n1") },
  };
  const story = new WorldStory({ get: async () => kept.story, put: async () => {}, getCheckpoint: async (part) => (part === "1" ? kept.checkpoint : undefined), remove: async () => {} });
  const world = makeWorld({ story: await story.trackStart() });

  await world.enter(ALICE, 0);
  await world.say(ALICE, { t: "sync", level: { best: 99, cap: null }, seed: { v1001: "n40" } });
  const [state] = world.heard(ALICE);
  assert.deepEqual([state.why, state.world.part, state.world.route, state.world.checkpoints, state.keys.v50], ["sync", "3", "chaos", ["1"], "n6"]);
  await world.say(ALICE, { t: "route", route: "ad" });
  assert.equal(world.heard(ALICE)[0].code, TRACK_CODE.route, "another route stays locked out");

  await world.enter(CARA, 1);
  await world.say(CARA, { t: "sync", level: { best: 10, cap: null }, seed: { v1001: "n2", v50: "n9" } });
  const [behind] = world.heard(CARA);
  assert.deepEqual([behind.why, behind.part, behind.keys], ["behind", "1", { v1001: "n10", v50: "n1" }], "a player behind starts from the world's checkpoint, not their own story");
});

test("a world's summary names the place its log starts at, which a world kept from before run entries takes as it stands", async () => {
  const fresh = makeWorld();
  await fresh.enter(ALICE, 0);
  await fresh.say(ALICE, { t: "sync", level: { best: 99, cap: null }, seed: { v1001: "n5" } });
  const store = memoryStore();
  await store.commit({ meta: { rev: 3, part: "1", route: "none", done: [], checkpoints: [], next: 1 }, keys: [{ track: WORLD_TRACK, set: [["v1001", "n20"]] }] });
  const kept = makeWorld({ store });
  await kept.enter(ALICE, 0);
  await kept.say(ALICE, { t: "sync", level: { best: 99, cap: null }, seed: { v1001: "n2" } });

  assert.deepEqual(fresh.heard(ALICE)[0].world.start, [5, 0, 0, 0]);
  assert.deepEqual(kept.heard(ALICE)[0].world.start, [20, 0, 0, 0]);
});

test("a state hands the world's keys at the start of its log where they differ from the keys it hands", async () => {
  const world = await startedWorld(5, [BOB]);
  await write(world, ALICE, 1, [["v50", "n3"], ["s3101", "1"]]);
  await world.tracks.leave(BOB);
  await world.enter(BOB, 1);
  await world.say(BOB, { t: "sync", level: { best: 99, cap: null }, cursors: {} });
  const [state] = world.heard(BOB);
  assert.deepEqual(state.log, { v50: "n0", s3101: "0", v1354: "n0" }, "the count of s3101 came with it");

  const store = memoryStore();
  await store.commit({ meta: { rev: 3, part: "1", route: "none", done: [], checkpoints: [], next: 1 }, keys: [{ track: WORLD_TRACK, set: [["v1001", "n20"], ["v50", "n4"]] }] });
  const kept = makeWorld({ store });
  await kept.enter(ALICE, 0);
  await kept.say(ALICE, { t: "sync", level: { best: 99, cap: null }, seed: { v1001: "n2" } });
  await write(kept, ALICE, 1, [["v50", "n6"]]);
  await kept.tracks.leave(ALICE);
  await kept.enter(ALICE, 0);
  await kept.say(ALICE, { t: "sync", level: { best: 99, cap: null }, cursors: {} });
  assert.deepEqual(kept.heard(ALICE).at(-1).log, { v50: "n4" }, "a world kept from before run entries starts its log as it stands");
});

test("an admin's keys go on the world's track as a revision every game on it hears, its part following, and leave the tracks of players behind as they are", async () => {
  const world = await startedWorld(10, [BOB], { pins: { v60: "n2" } });
  await write(world, ALICE, 1, [["v1001", "n19"]]);
  await world.enter(CARA, 2);
  await world.say(CARA, { t: "sync", level: { best: 3, cap: null }, seed: { v1001: "n2", v50: "n5" } });
  [ALICE, BOB, CARA].forEach((player) => world.heard(player));

  const set = await world.tracks.setKeys(new Map([["v50", "n4"], ["s3101", "1"]]), "admin");
  assert.deepEqual([...set.changed], [["v50", "n4"], ["s3101", "1"], ["v1354", "n1"]], "a count follows the switches it counts");
  assert.deepEqual([set.view.rev, set.view.part, set.view.keys.v.split(",").includes("50:n4")], [3, "2", true]);
  const [push] = world.heard(BOB).filter((frame) => frame.t === "push");
  assert.deepEqual([push.rev, push.prev, push.keys], [3, 2, { v50: "n4", s3101: "1", v1354: "n1" }]);
  assert.deepEqual(world.heard(CARA), [], "a player behind keeps their own story");

  const ahead = await world.tracks.setKeys(new Map([["v1001", "n34"]]), "admin");
  assert.deepEqual([ahead.view.part, ahead.view.checkpoints], ["3", ["1", "2"]], "the part and its checkpoint move as for a write");
  assert.equal(world.heard(BOB).filter((frame) => frame.t === "push")[0].world.part, "3");
  assert.deepEqual((await world.tracks.setKeys(new Map([["v1001", "n34"]]), "admin")).changed, new Map(), "a key at its value makes no revision");

  assert.deepEqual(await world.tracks.setKeys(new Map([["v60", "n9"], ["v50", "n1"]]), "admin"), { code: "pinned", keys: ["v60"] });
  assert.deepEqual(await world.tracks.setKeys(new Map([["s100", "1"], ["s500", "1"], ["v1354", "n4"], ["v50", "n1"]]), "admin"), { code: "mapping", keys: ["s100", "s500", "v1354"] });
  assert.deepEqual(await world.tracks.setKeys(new Map([["v050", "n1"]]), "admin"), { code: "bad", keys: ["v050"] });
});

test("an admin reads the world's story with its part and routes, and takes back the route lock unless the world is on that route", async () => {
  const world = await startedWorld(40, [BOB]);
  await world.say(ALICE, { t: "route", route: "mr" });
  const view = await world.tracks.view(false);
  assert.deepEqual([view.rev, view.part, view.route, view.done, view.counters.p, view.keys], [2, "3", "mr", [], 40, undefined]);
  assert.ok(view.at > 0);
  world.heard(BOB);

  assert.deepEqual(await world.tracks.clearRoute(), { cleared: true, view: await world.tracks.view(false) });
  assert.equal(world.heard(BOB).find((frame) => frame.t === "push").world.route, "none", "every game hears the lock taken back");
  assert.equal((await world.tracks.clearRoute()).cleared, false, "no lock to take back");

  await write(world, ALICE, 1, [["v1141", "n1"]]);
  assert.deepEqual((await world.tracks.clearRoute()).started, true, "the world is on the locked route");
  const keyed = await world.tracks.view(true);
  assert.deepEqual([keyed.part, keyed.route, keyed.keys.v], ["ad", "ad", "1001:n40,1141:n1"]);
});

test("an admin reads the world's story after the relay starts again, before any game enters", async () => {
  const store = memoryStore();
  const before = makeWorld({ store });
  await before.enter(ALICE, 0);
  await before.say(ALICE, { t: "sync", level: { best: 99, cap: null }, seed: { v1001: "n40" } });

  const after = makeWorld({ store });
  const [plain, keyed] = [await after.tracks.view(false), await after.tracks.view(true)];
  assert.deepEqual([plain.rev, plain.part, plain.route, plain.keys, keyed.keys.v], [1, "3", "none", undefined, "1001:n40"]);
});
