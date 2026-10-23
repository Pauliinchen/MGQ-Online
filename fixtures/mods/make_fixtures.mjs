//----------------------------------------------------------------
//  make_fixtures.mjs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

// Writes keys.json next to this file: mod names and the key the relay's modKey (Relay/core/mods.js)
// makes of each, which the relay holds its stored keys by. MGQOnline.Game.Tests checks the game's
// ModKey against them, the relay's tests modKey, and the script tests answer the mods.keys topic
// from them. Run it again only when a case is added, with Node 24:
//
//   node fixtures/mods/make_fixtures.mjs

import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { modKey } from "../../Relay/core/mods.js";

/**
 * The names: the catalog's and the scripts' own spellings, every white space JavaScript strips and
 * some it keeps, and the casing JavaScript does beyond a character's simple lower case.
 */
const NAMES = [
  "Level_Cap.rb", "Level Cap", "Luka-Replacer", "0_Mod Config-Remake.rb", "Victory_Screen.RB", "Patch", "Multiplayer",
  "Ruby", "x.rb.rb", "x.rb ", "", "  ", "Tab\tName", "Line\nBreak\r", "Form\fFeed\vTab",
  "A\u00a0B", "A\u1680B", "A\u2000B\u200aC", "A\u2028B\u2029C", "A\u202fB", "A\u205fB", "A\u3000B", "A\ufeffB",
  "A\u0085B", "A\u180eB", "A\u200bB",
  "\u00c4_\u00d6-\u00dc", "\uff26\uff35\uff2c\uff2c", "\u01c4emal", "\u216b", "\u13a0", "\u{10400}\u{10401}", "\u0130stanbul",
  "\u03a3\u039f\u03a6\u039f\u03a3", "\u03a3\u039f\u03a6\u039f\u03a3 MOD", "\u03a3\u0391", "\u03a3", "\u0391\u03a3'\u0391", "\u0391\u03a3.rb",
  "\u0391\u03a3\u0301", "\u0391\u03a3\u0301\u0391", "\u0391\u0301\u03a3",
];

/**
 * Writes a JSON text with every UTF-16 unit outside printable ASCII as an escape, so the file shows
 * what each case holds.
 *
 * @param {unknown} value The value.
 * @returns {string} The JSON text.
 */
function escaped(value) {
  return JSON.stringify(value).replace(/[^\x20-\x7e]/g, (unit) => `\\u${unit.charCodeAt(0).toString(16).padStart(4, "0")}`);
}

const cases = NAMES.map((name) => `    ${escaped({ name, key: modKey(name) })}`);
const text = `{\n  "source": ${escaped(`modKey of Relay/core/mods.js, Node ${process.versions.node}`)},\n  "keys": [\n${cases.join(",\n")}\n  ]\n}\n`;
writeFileSync(fileURLToPath(new URL("keys.json", import.meta.url)), text);
