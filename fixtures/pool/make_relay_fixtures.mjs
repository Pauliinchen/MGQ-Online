//----------------------------------------------------------------
//  make_relay_fixtures.mjs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

// Writes relay.json next to this file: the share of a pool left at a moment as the relay counts it
// (leftOf of Relay/core/bosses.js), which the C# ledger must count alike, byte for byte, for pools
// told at a moment and read later, sooner (a clock that ran back) and long after. make_fixtures.rb
// runs it.
//
//   node fixtures/pool/make_relay_fixtures.mjs

import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { BOSS_LIMITS, leftOf } from "../../Relay/core/bosses.js";

const at = 1_000_000_000;

/**
 * The pools and moments, each as [left, defeated, milliseconds after the pool was told].
 */
const moments = [
  [0.5, false, 0],
  [0.5, false, 60_000],
  [0.5, false, 1_234],
  [0.123456789, false, 7_777_777],
  [0.999, false, 2_001],
  [0.25, false, -30_000],
  [0.000001, false, 1],
  [0.4, true, 600_000],
  [0.1, false, 1_800_000],
];

const cases = moments.map(([left, defeated, after]) => ({
  left,
  defeated,
  after,
  share: String(leftOf({ left, defeated, at }, at + after)),
}));

const here = dirname(fileURLToPath(import.meta.url));
writeFileSync(join(here, "relay.json"), JSON.stringify({ regenPerMinute: BOSS_LIMITS.regenPerMinute, cases }, null, 2) + "\n");
