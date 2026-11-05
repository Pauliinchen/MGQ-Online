//----------------------------------------------------------------
//  track_harness.mjs
//
//  Changelog:
//      Paulinchen  2026-11-06: Moved next to its test with the mapping written out
//      Paulinchen  2026-10-31: Kept the tracks' run entries
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

// Runs one Raid World's story tracks of the relay (Relay/core/story_tracks.js) in memory for a
// test of another language, which plays the games: each line read is a JSON step, `{"op":
// "enter", "player", "seat"}`, `{"op": "frame", "player", "text"}` (a `track <JSON>` frame of
// that player's game) or `{"op": "leave", "player"}`; each frame the relay sends a game is written
// as a line `{"player", "text"}`, and every step ends with a line `{"done": true}`.
//
//   node MGQOnline.Game.Tests/Story/track_harness.mjs

import { createInterface } from "node:readline";
import { StoryTracks } from "../../Relay/core/story_tracks.js";

/**
 * The story mapping the tracks share: a few keys of each kind, events and the parts' gates.
 */
const mapping = {
  rev: 7,
  tables: {
    keys: [
      {"key": "s7096", "kind": "shared"},
      {"key": "s2029", "kind": "scene"},
      {"key": "s7102", "kind": "chest"},
      {"key": "s23", "kind": "personal", "defeatWrite": true},
      {"key": "s31", "kind": "shared", "defeatWrite": true},
      {"key": "v1001", "kind": "one_way"},
      {"key": "v1141", "kind": "one_way", "routeReturnClears": true},
      {"key": "v1354", "kind": "count", "counts": {"from": 3101, "to": 3180}},
      {"key": "v1062", "kind": "shared", "defeatReturns": {"4": 3}},
      {"key": "v1052", "kind": "shared", "localSteps": {"steps": [3, 4, 5], "sharedAs": 2, "places": [{"map": 484, "fromX": 30}, {"map": 483, "fromX": 0}]}},
      {"key": "v3005", "kind": "one_way", "wholeWorld": true},
      {"key": "v53", "kind": "shared"},
    ],
    events: [
      {"key": "ss231.*.*", "share": "shared"},
      {"key": "ss231.4.*", "share": "personal"},
      {"key": "ss231.5.B", "share": "shared"},
      {"key": "ss0.*.F", "share": "shared"},
      {"key": "ss12.5.A", "share": "personal", "chest": true},
      {"key": "ss40.*.C", "share": "personal"},
      {"key": "ce154.*", "share": "shared"},
      {"key": "ce20.A", "share": "personal"},
    ],
    parts: [
      {"id": "1", "name": "Part 1", "ending": [], "gate": 25, "order": 1},
      {"id": "2", "name": "Part 2", "ending": [], "gate": 55, "order": 2},
    ],
  },
  index: {"built": 7, "stale": false, "events": [[7, 39], [40, 2]]},
};

/**
 * Makes one world's track store in memory, as the relay's tests do.
 *
 * @returns {import("../../Relay/core/story_tracks.js").TrackStore} The store.
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

        for (const [key, value] of set) {
          keysOf(track).set(key, value);
        }
      }

      for (const { track, drop, add, before = 0 } of runs) {
        const list = drop ? [] : (kept.runs.get(track) ?? []);
        kept.runs.set(track, [...list, ...structuredClone(add)].filter((entry) => entry.n >= before));
      }

      for (const record of players) {
        kept.players.set(record.player, structuredClone(record));
      }

      if (checkpoint) {
        kept.checkpoints.set(checkpoint.part, structuredClone(checkpoint.keys));
      }
    },
    remove: async () => {},
  };
}

const tracks = new StoryTracks(memoryStore(), {
  mapping: async () => mapping,
  send: (player, text) => process.stdout.write(`${JSON.stringify({ player, text })}\n`),
});

const lines = createInterface({ input: process.stdin });

for await (const line of lines) {
  if (line.trim() === "") {
    continue;
  }

  const step = JSON.parse(line);

  if (step.op === "enter") {
    await tracks.enter(step.player, step.seat);
  } else if (step.op === "frame") {
    await tracks.frame(step.player, step.text);
  } else if (step.op === "leave") {
    await tracks.leave(step.player);
  }

  process.stdout.write(`${JSON.stringify({ done: true })}\n`);
}
