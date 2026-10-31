//----------------------------------------------------------------
//  track_harness.mjs
//
//  Changelog:
//      Paulinchen  2026-10-31: Kept the tracks' run entries
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

// Runs one Raid World's story tracks of the relay (Relay/core/story_tracks.js) in memory for a
// test of another language, which plays the games: each line read is a JSON step, `{"op":
// "enter", "player", "seat"}`, `{"op": "frame", "player", "text"}` (a `track <JSON>` frame of
// that player's game) or `{"op": "leave", "player"}`; each frame the relay sends a game is written
// as a line `{"player", "text"}`, and every step ends with a line `{"done": true}`. The mapping
// is the one of classes.json next to this file, with the parts' gates.
//
//   node fixtures/story/track_harness.mjs

import { readFileSync } from "node:fs";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import { StoryTracks } from "../../Relay/core/story_tracks.js";

const mapping = JSON.parse(readFileSync(fileURLToPath(new URL("classes.json", import.meta.url)), "utf8")).mapping;

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
