//----------------------------------------------------------------
//  test_compiler_stub.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

// A stand-in for the Raid Designer's `raid-designer` CLI in the relay's tests, run as a child
// process. It answers `--version`, `preflight` and `compile` as the CLI's contract describes, and
// does what `mode.json` beside it says: `designFormat`, `preflight` (an exit code), `compile`
// (`ok`, `refuse`, `fail` or `badsha`), `sleepMs`, `format` and `catalogDiff`. Every call is
// appended to `calls.log` beside it.

import { createHash } from "node:crypto";
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * The folder the stub, its mode and its call log are in.
 */
const HERE = dirname(fileURLToPath(import.meta.url));

/**
 * What the stub does, see the file's description.
 */
const MODE = existsSync(join(HERE, "mode.json")) ? JSON.parse(readFileSync(join(HERE, "mode.json"), "utf8")) : {};

/**
 * Reads the value after an option.
 *
 * @param {string[]} args The arguments.
 * @param {string} name The option, such as `--out`.
 * @returns {string | null} Its value, null without the option.
 */
function option(args, name) {
  const index = args.indexOf(name);
  return index < 0 ? null : args[index + 1];
}

/**
 * Hashes bytes with SHA-256.
 *
 * @param {Uint8Array | string} bytes The bytes.
 * @returns {string} The SHA-256, lowercase hexadecimal.
 */
function sha256Of(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

/**
 * Compiles as the mode says: writes the three files and the report into the output folder.
 *
 * @param {string[]} args The arguments after `compile`.
 * @returns {Promise<number>} The exit code.
 */
async function compile(args) {
  if (MODE.sleepMs) {
    await new Promise((resolve) => setTimeout(resolve, MODE.sleepMs));
  }

  const out = option(args, "--out");
  const seq = Number(option(args, "--seq"));
  const snapshot = readFileSync(option(args, "--snapshot"));
  const previous = option(args, "--previous");
  const runtime = JSON.stringify({ seq, snapshotSha256: sha256Of(snapshot), previous: previous ? readFileSync(previous, "utf8") : null });
  const marshal = Buffer.from(`marshal ${seq} ${sha256Of(snapshot)}`);
  const report = {
    ok: MODE.compile !== "refuse", designFormat: 1, format: MODE.format ?? 3, runtimeFormat: 1, seq, snapshotSha256: sha256Of(snapshot),
    marshal: { sha256: sha256Of(marshal), size: marshal.length }, runtime: { sha256: MODE.compile === "badsha" ? "0".repeat(64) : sha256Of(runtime), size: Buffer.byteLength(runtime) },
    compiler: "1.3.0", gameData: sha256Of(option(args, "--game")), bossKeys: ["Lilith"], catalogDiff: { removed: [], renamed: [], troopsChanged: [], ...MODE.catalogDiff },
    issues: MODE.compile === "refuse" ? [{ severity: "error", code: "formula", path: "rules", text: "A formula the grammar refuses." }] : [],
  };

  writeFileSync(join(out, "report.json"), JSON.stringify(report));

  if (MODE.compile === "refuse") {
    return 2;
  }

  if (MODE.compile === "fail") {
    process.stderr.write("the stub failed on purpose\n");
    return 1;
  }

  writeFileSync(join(out, "runtime.json"), runtime);
  writeFileSync(join(out, "RaidDesign.rvdata2"), marshal);
  writeFileSync(join(out, "snapshot.json"), snapshot);
  return 0;
}

/**
 * Answers one call of the CLI.
 *
 * @param {string[]} args The arguments.
 * @returns {Promise<number>} The exit code.
 */
async function main(args) {
  appendFileSync(join(HERE, "calls.log"), `${args[0]}\n`);

  if (args[0] === "--version") {
    process.stdout.write(JSON.stringify({ version: "1.3.0", designFormat: MODE.designFormat ?? 1, runtimeFormat: 1, marshalFormat: 3 }));
    return 0;
  }

  if (args[0] === "preflight") {
    process.stdout.write(JSON.stringify({ files: [] }));
    return MODE.preflight ?? 0;
  }

  return args[0] === "compile" ? compile(args.slice(1)) : 3;
}

process.exitCode = await main(process.argv.slice(2));
