//----------------------------------------------------------------
//  make_fixtures.mjs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

// Writes parts.json next to this file: story counters and the part the relay's partOf
// (Relay/core/story.js) finds them in. MGQOnline.Game.Tests checks the game's StoryParts against
// them, the relay's tests partOf, and the script tests answer the story.part topic from them. Run
// it again only when a case is added, with Node 24:
//
//   node fixtures/story/make_fixtures.mjs

import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { partOf } from "../../Relay/core/story.js";

/**
 * The counters: variable 1001 around the parts' starts, each route under way, two at once, and a
 * route under way before the Great Decision, which partOf counts as the route too.
 */
const COUNTERS = [
  [0, 0, 0, 0], [18, 0, 0, 0], [19, 0, 0, 0], [33, 0, 0, 0], [34, 0, 0, 0], [39, 0, 0, 0], [40, 0, 0, 0],
  [40, 1, 0, 0], [40, 0, 3, 0], [40, 0, 0, 1], [40, 0, 2, 1], [12, 0, 4, 0],
];

const cases = COUNTERS.map(([p, r1141, r1142, r1143]) => `    ${JSON.stringify({ p, r1141, r1142, r1143, part: partOf({ p, r1141, r1142, r1143 }) })}`);
const text = `{\n  "source": ${JSON.stringify(`partOf of Relay/core/story.js, Node ${process.versions.node}`)},\n  "parts": [\n${cases.join(",\n")}\n  ]\n}\n`;
writeFileSync(fileURLToPath(new URL("parts.json", import.meta.url)), text);
