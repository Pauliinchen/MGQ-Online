//----------------------------------------------------------------
//  make_classes.mjs
//
//  Changelog:
//      Paulinchen  2026-11-05: Added a shared row of a variable the game uses as a place, which stays each player's own
//      Paulinchen  2026-11-01: Replaced the case of another self switch of map 0 by the mark of a used up item
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

// Writes classes.json next to this file: a story mapping as games read it and the kind the
// relay's tracks (TrackRules of Relay/core/story_tracks.js) give each of a list of keys, with the
// site of the write and whether the whole world keeps it. MGQOnline.Game.Tests checks the game's
// StoryTable against them, and the script tests the scripts' lookup over the table the DLL hands
// them. Run it again only when a case is added, with Node 24:
//
//   node fixtures/story/make_classes.mjs

import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { TrackRules } from "../../Relay/core/story_tracks.js";

/**
 * The mapping: a row of every kind and option, self switch rules of every shape, a shared row of a
 * variable the game uses as a place, and the index.
 */
const MAPPING = {
  rev: 7,
  tables: {
    keys: [
      { key: "s7096", kind: "shared" },
      { key: "s2029", kind: "scene" },
      { key: "s7102", kind: "chest" },
      { key: "s23", kind: "personal", defeatWrite: true },
      { key: "s31", kind: "shared", defeatWrite: true },
      { key: "v1001", kind: "one_way" },
      { key: "v1141", kind: "one_way", routeReturnClears: true },
      { key: "v1354", kind: "count", counts: { from: 3101, to: 3180 } },
      { key: "v1062", kind: "shared", defeatReturns: { 4: 3 } },
      { key: "v1052", kind: "shared", localSteps: { steps: [3, 4, 5], sharedAs: 2, places: [{ map: 484, fromX: 30 }, { map: 483, fromX: 0 }] } },
      { key: "v3005", kind: "one_way", wholeWorld: true },
      { key: "v53", kind: "shared" },
    ],
    events: [
      { key: "ss231.*.*", share: "shared" },
      { key: "ss231.4.*", share: "personal" },
      { key: "ss231.5.B", share: "shared" },
      { key: "ss0.*.F", share: "shared" },
      { key: "ss12.5.A", share: "personal", chest: true },
      { key: "ss40.*.C", share: "personal" },
      { key: "ce154.*", share: "shared" },
      { key: "ce20.A", share: "personal" },
    ],
    parts: [
      { id: "1", name: "Part 1", ending: [], gate: 25, order: 1 },
      { id: "2", name: "Part 2", ending: [], gate: 55, order: 2 },
    ],
  },
  index: { built: 7, stale: false, events: [[7, 39], [40, 2]] },
};

/**
 * The keys asked, each with the site of its write.
 */
const KEYS = [
  ["s7096", null], ["s2029", null], ["s7102", null], ["s23", null], ["s31", null], ["s8000", null], ["v1001", null], ["v1141", "ce:154"],
  ["v1354", null], ["v1062", null], ["v1052", null], ["v3005", null], ["v900", null], ["v53", null], ["f868", null],
  ["ss231.9.A", null], ["ss231.4.B", null], ["ss231.5.B", null], ["ss231.5.A", null], ["ss0.501.F", null], ["ss0.508.U1se3r6i", "map:88:4:1"],
  ["ss12.5.A", null], ["ss12.5.B", null], ["ss40.2.C", null], ["ss40.2.A", null], ["ss7.39.A", null], ["ss7.40.A", null],
  ["ss9.1.A", "ce:154"], ["ss9.1.A", null], ["ss40.2.A", "ce:20"], ["ss231.4.A", "ce:154"], ["ss7.39.A", "ce:20"],
];

const rules = new TrackRules(MAPPING);
const cases = KEYS.map(([key, site]) => `    ${JSON.stringify({ key, site, kind: rules.kindOf(key, site).kind, wholeWorld: rules.wholeWorld(key) })}`);
const text = `{\n  "source": ${JSON.stringify(`TrackRules of Relay/core/story_tracks.js, Node ${process.versions.node}`)},\n  "mapping": ${JSON.stringify(MAPPING)},\n  "cases": [\n${cases.join(",\n")}\n  ]\n}\n`;
writeFileSync(fileURLToPath(new URL("classes.json", import.meta.url)), text);
