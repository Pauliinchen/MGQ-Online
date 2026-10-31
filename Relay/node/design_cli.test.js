//----------------------------------------------------------------
//  design_cli.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Required an import without errors unless the dropped parts are accepted
//                            - Created
//
//----------------------------------------------------------------

// Runs the relay's designs against a real `raid-designer` binary, as on the server: the CLI imports
// a format 1 design and pushes it, the relay builds it through the same binary against real game
// data and publishes it, and a game fetches the build. Skipped unless RAID_DESIGNER_CLI names the
// binary; RAID_DESIGNER_GAME then names the game folder (only read) and RAID_DESIGNER_FIXTURE the
// format 1 design file, such as MGQ-Online-Raid-Designer/RaidDesigner.Tests/Fixtures/Format1/test-install-2026-10-17.json.
// The import must report no errors; RAID_DESIGNER_ACCEPT_DROPPED=1 pushes the parts it drops anyway.

import { after, test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { gunzipSync } from "node:zlib";
import { DesignBook, designerIdOf } from "../core/designs.js";
import { Directory, parseAdmins } from "../core/directory.js";
import { DESIGN_FORMAT_HEADER, DESIGNER_HEADER, DESIGNER_VERSION_HEADER } from "../core/gate.js";
import { FEATURES_HEADER } from "../core/relay.js";
import { COMPILER_LIMITS, DesignCompiler, designCompilerSettingsOf } from "./design_compiler.js";
import { createRelay, openStores } from "./server.js";

/**
 * The raid-designer binary, null while the environment names none.
 */
const CLI = process.env.RAID_DESIGNER_CLI?.trim() || null;

/**
 * The game folder the binary compiles against.
 */
const GAME = process.env.RAID_DESIGNER_GAME?.trim() || null;

/**
 * The format 1 design file the binary imports.
 */
const FIXTURE = process.env.RAID_DESIGNER_FIXTURE?.trim() || null;

/**
 * Whether the import pushes a design whose report has errors, the parts it drops left out.
 */
const ACCEPT_DROPPED = process.env.RAID_DESIGNER_ACCEPT_DROPPED?.trim() === "1";

/**
 * How long a build may take before the harness gives up: the compile's own limit, the probe's,
 * and room for the queue.
 */
const BUILD_WAIT_MS = COMPILER_LIMITS.compileTimeoutMs + 2 * COMPILER_LIMITS.probeTimeoutMs + 30 * 1000;

/**
 * How long one CLI call of the harness may take.
 */
const CLI_TIMEOUT_MS = 5 * 60 * 1000;

/**
 * The headers of a game that reads compiled format 3.
 */
const GAME_HEADERS = { [FEATURES_HEADER]: "raid", "X-MGQ-Design-Reader": "3" };

/**
 * The first two bytes of every Ruby Marshal dump.
 */
const MARSHAL_HEADER = [4, 8];

/**
 * The errors the relay logged.
 */
const errors = [];

/**
 * What to stop and remove once the test ran.
 */
const cleanups = [];

after(async () => {
  for (const cleanup of cleanups.reverse()) {
    await cleanup();
  }
});

/**
 * Runs the CLI and reads its JSON output.
 *
 * @param {string[]} args The arguments, `--json` added.
 * @returns {Promise<{code: number, output: any, stderr: string}>} The exit code, the JSON it wrote (null when it wrote none) and its stderr.
 */
function cli(args) {
  return new Promise((resolve) => {
    execFile(CLI, [...args, "--json"], { timeout: CLI_TIMEOUT_MS, maxBuffer: 64 * 1024 * 1024, windowsHide: true }, (error, stdout, stderr) => {
      let output = null;

      try {
        output = JSON.parse(String(stdout).trim().split("\n").at(-1));
      } catch {
        output = null;
      }

      resolve({ code: error ? (Number.isInteger(error.code) ? error.code : -1) : 0, output, stderr: String(stderr) });
    });
  });
}

/**
 * Sends a request and reads its JSON answer.
 *
 * @param {string} address The relay's address.
 * @param {string} method The HTTP method.
 * @param {string} path The path.
 * @param {Record<string, string>} headers The headers.
 * @param {unknown} [body] The JSON body, none when left out.
 * @returns {Promise<{status: number, body: any}>} The answer.
 */
async function call(address, method, path, headers, body) {
  const response = await fetch(`${address}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: response.status, body: await response.json() };
}

/**
 * Reads a route's gzipped bytes and gunzips them.
 *
 * @param {string} address The relay's address.
 * @param {string} path The path.
 * @param {Record<string, string>} headers The headers.
 * @returns {Promise<Buffer>} The bytes.
 */
async function gunzipped(address, path, headers) {
  const response = await fetch(`${address}${path}`, { headers });
  assert.equal(response.status, 200, path);
  return gunzipSync(Buffer.from(await response.arrayBuffer()));
}

/**
 * Hashes bytes with SHA-256.
 *
 * @param {Uint8Array} bytes The bytes.
 * @returns {string} The SHA-256, lowercase hexadecimal.
 */
function sha256Of(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

/**
 * Starts a relay over a fresh SQLite database whose designs build with the real CLI, set up from
 * the environment variables the server reads, with one designer admin.
 *
 * @param {string} folder The folder of the database and the builds.
 * @param {string} designerId The designer admin's id, as DESIGNER_ADMINS names it.
 * @returns {Promise<string>} The relay's HTTP address.
 */
async function startRelay(folder, designerId) {
  const settings = designCompilerSettingsOf({ DESIGN_COMPILER: CLI, DESIGN_GAME_DATA: GAME, DESIGN_DATA_DIR: join(folder, "designs") });
  const stores = await openStores(join(folder, "relay.sqlite"));
  const log = { info: () => {}, error: (line) => errors.push(line) };
  const designs = new DesignBook(stores.designs, { compiler: new DesignCompiler(settings, { log }) });
  await designs.seedAdmins(parseAdmins(designerId));
  const relay = createRelay({ checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, log, directory: new Directory(stores.directory), stories: stores.stories, bosses: stores.bosses, designs });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  cleanups.push(async () => {
    await relay.stop();
    stores.close();
  });
  return `http://127.0.0.1:${relay.server.address().port}`;
}

/**
 * Pulls every entity the relay holds, page by page, without tombstones.
 *
 * @param {string} address The relay's address.
 * @param {Record<string, string>} headers The designer's headers.
 * @returns {Promise<any[]>} The entities, sorted by id.
 */
async function pullAll(address, headers) {
  const entities = [];
  let after = "";

  do {
    const page = (await call(address, "GET", `/v1/designs/entities?since=0&limit=500${after ? `&after=${encodeURIComponent(after)}` : ""}`, headers)).body;
    entities.push(...page.entities);
    after = page.next ?? "";
  } while (after);

  return entities;
}

/**
 * Waits until a build finished.
 *
 * @param {string} address The relay's address.
 * @param {Record<string, string>} headers The designer's headers.
 * @param {number} id The build.
 * @returns {Promise<any>} The build.
 */
async function finished(address, headers, id) {
  const end = Date.now() + BUILD_WAIT_MS;

  while (Date.now() < end) {
    const build = (await call(address, "GET", `/v1/designs/builds/${id}`, headers)).body.builds[0];

    if (build.status !== "queued" && build.status !== "compiling") {
      return build;
    }

    await new Promise((resolve) => setTimeout(resolve, 500));
  }

  throw new Error(`build ${id} did not finish within ${BUILD_WAIT_MS / 1000} s`);
}

test("a local relay builds the user design through the real raid-designer binary and serves the build to games", { skip: CLI ? false : "set RAID_DESIGNER_CLI to the raid-designer binary to run it", timeout: 2 * BUILD_WAIT_MS }, async (t) => {
  assert.ok(GAME && FIXTURE, "RAID_DESIGNER_GAME (the game folder) and RAID_DESIGNER_FIXTURE (a format 1 design file) go with RAID_DESIGNER_CLI");
  const folder = mkdtempSync(join(tmpdir(), "mgq-design-cli-"));
  cleanups.push(() => rmSync(folder, { recursive: true, force: true }));

  const version = await cli(["--version"]);
  assert.equal(version.code, 0, version.stderr);
  t.diagnostic(`raid-designer ${version.output.version}: design format ${version.output.designFormat}, runtime format ${version.output.runtimeFormat}, marshal format ${version.output.marshalFormat}`);

  const preflight = await cli(["preflight", "--game", GAME]);
  assert.equal(preflight.code, 0, `preflight against ${GAME}: ${JSON.stringify(preflight.output) ?? preflight.stderr}`);

  const key = randomBytes(16).toString("hex");
  const keyFile = join(folder, "designer.key");
  writeFileSync(keyFile, key, { mode: 0o600 });
  const designerId = await designerIdOf(key);
  const address = await startRelay(folder, designerId);
  const headers = { [DESIGNER_HEADER]: key, [FEATURES_HEADER]: "designer", [DESIGNER_VERSION_HEADER]: version.output.version, [DESIGN_FORMAT_HEADER]: String(version.output.designFormat) };

  const imported = await cli(["import", "--format1", FIXTURE, "--push", ...(ACCEPT_DROPPED ? ["--accept-dropped"] : []), "--message", "the user design, imported by the relay harness", "--server", address, "--key-file", keyFile]);

  if (!ACCEPT_DROPPED) {
    assert.equal(imported.output?.errors, 0, `the import report holds errors; RAID_DESIGNER_ACCEPT_DROPPED=1 pushes the design anyway: ${JSON.stringify(imported.output?.report?.filter((note) => note.severity === "error")) ?? imported.stderr}`);
  }

  assert.equal(imported.code, 0, `import: ${JSON.stringify(imported.output) ?? imported.stderr}`);
  t.diagnostic(`imported ${imported.output.imported} entities with ${imported.output.errors} errors and ${imported.output.warnings} warnings in the report`);

  const me = (await call(address, "GET", "/v1/designs/me", headers)).body;
  assert.deepEqual([me.designer, me.admin], [true, true]);
  assert.ok(me.seq > 0, "the push reached the relay");
  const pulled = await pullAll(address, headers);
  assert.ok(pulled.length > 0);

  const started = await call(address, "POST", "/v1/designs/builds", headers, { seq: me.seq });
  assert.equal(started.status, 202, JSON.stringify(started.body));
  const build = await finished(address, headers, started.body.build.id);
  assert.equal(build.status, "ok", `the build ended ${build.status}: ${JSON.stringify(build.report).slice(0, 4000)}`);
  t.diagnostic(`build ${build.id}: format ${build.format}, compiler ${build.report.compiler}, game data ${build.report.gameData}, ${build.report.issues?.length ?? 0} issues, ${build.report.bossKeys?.length ?? 0} boss keys`);

  const snapshot = JSON.parse((await gunzipped(address, `/v1/designs/builds/${build.id}/snapshot`, headers)).toString("utf8"));
  assert.deepEqual(snapshot.entities.map((entity) => entity.id), pulled.map((entity) => entity.id), "the build compiled every entity the push left");

  const published = await call(address, "POST", "/v1/designs/publish", headers, { buildId: build.id });
  assert.equal(published.status, 200, JSON.stringify(published.body));
  t.diagnostic(`catalogDiff ${JSON.stringify(published.body.catalogDiff)}`);

  const live = await call(address, "GET", "/v1/raid-design", GAME_HEADERS);
  assert.deepEqual([live.status, live.body.buildId, live.body.marshal.sha256, live.body.runtime.sha256], [200, build.id, build.marshalSha, build.runtimeSha]);

  const marshal = await gunzipped(address, `/v1/raid-design/${build.marshalSha}`, GAME_HEADERS);
  assert.equal(sha256Of(marshal), build.marshalSha);
  assert.deepEqual([...marshal.subarray(0, 2)], MARSHAL_HEADER, "RaidDesign.rvdata2 is a Ruby Marshal dump");

  const runtime = await gunzipped(address, `/v1/raid-design/${build.runtimeSha}`, GAME_HEADERS);
  assert.equal(sha256Of(runtime), build.runtimeSha);
  assert.equal(typeof JSON.parse(runtime.toString("utf8")), "object", "runtime.json is JSON");
  t.diagnostic(`RaidDesign.rvdata2 ${marshal.length} bytes, runtime.json ${runtime.length} bytes`);
  assert.deepEqual(errors, []);
});
