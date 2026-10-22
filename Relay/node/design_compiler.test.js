//----------------------------------------------------------------
//  design_compiler.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

import { after, test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { gunzipSync, gzipSync } from "node:zlib";
import { designCompilerSettingsOf } from "./design_compiler.js";
import { removeStubCompilers, stubCompiler } from "./test_design_compiler.js";

after(removeStubCompilers);

/**
 * Hashes bytes with SHA-256.
 *
 * @param {Uint8Array | string} bytes The bytes.
 * @returns {string} The SHA-256, lowercase hexadecimal.
 */
function sha256Of(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

test("the compiler settings need DESIGN_COMPILER, DESIGN_GAME_DATA and DESIGN_DATA_DIR, else the builds stay off", () => {
  const env = { DESIGN_COMPILER: " /opt/mgq-designer/current/raid-designer ", DESIGN_GAME_DATA: "/opt/mgq-battle/game", DESIGN_DATA_DIR: "/var/lib/mgq-relay/designs" };
  assert.deepEqual(designCompilerSettingsOf(env), { compiler: "/opt/mgq-designer/current/raid-designer", gameData: "/opt/mgq-battle/game", dataDir: "/var/lib/mgq-relay/designs" });

  for (const name of Object.keys(env)) {
    assert.equal(designCompilerSettingsOf({ ...env, [name]: " " }), null, name);
  }
});

test("the probe runs --version and preflight once per binary, again after the binary changed, and again after a failure", async () => {
  const { compiler, setMode, calls } = stubCompiler({ designFormat: 2 });
  assert.deepEqual(await compiler.probe(), { designFormat: 2, version: "1.3.0", message: null });
  assert.deepEqual(await compiler.probe(), { designFormat: 2, version: "1.3.0", message: null });
  assert.deepEqual(calls(), ["--version", "preflight"], "the second probe is the first one's");

  // An update replaces the binary: another size and time.
  writeFileSync(compiler.settings.compiler, `${readFileSync(compiler.settings.compiler, "utf8")}\n// 1.4.0\n`);
  setMode({ designFormat: 3, preflight: 4 });
  assert.deepEqual(await compiler.probe(), { designFormat: 3, version: "1.3.0", message: "The compiler misses game data on the relay." });
  setMode({ designFormat: 3 });
  assert.deepEqual(await compiler.probe(), { designFormat: 3, version: "1.3.0", message: null }, "a failed probe is tried again");
  assert.equal(calls().length, 6);

  setMode({ designFormat: 3, preflight: 1 });
  writeFileSync(compiler.settings.compiler, `${readFileSync(compiler.settings.compiler, "utf8")}\n// 1.4.1\n`);
  assert.equal((await compiler.probe()).message, "The compiler's preflight failed with exit code 1.");
});

test("a missing compiler, or one that names no design format, knows design format 0", async () => {
  const { compiler, setMode } = stubCompiler({ designFormat: 0 });
  assert.deepEqual(await compiler.probe(), { designFormat: 0, version: "1.3.0", message: null });
  setMode({});
  rmSync(compiler.settings.compiler);
  assert.deepEqual(await compiler.probe(), { designFormat: 0, version: null, message: null });
});

test("an ok compile hands out every file gzipped under the SHA-256 its report names, compiled against the previous runtime", async () => {
  const { compiler, folder } = stubCompiler({ catalogDiff: { removed: ["Lilith"] } });
  const snapshot = JSON.stringify({ designFormat: 1, entities: [], format: "mgq-raid-design-snapshot" });
  await compiler.prepare(7, snapshot);
  const result = await compiler.compile({ buildId: 7, seq: 12, previous: new Uint8Array(gzipSync("previous runtime")) });

  assert.equal(result.status, "ok");
  assert.deepEqual(result.blobs.map((blob) => blob.kind), ["runtime", "marshal", "snapshot"]);

  for (const blob of result.blobs) {
    const bytes = gunzipSync(blob.gz);
    assert.equal(sha256Of(bytes), blob.sha256, blob.kind);
    assert.equal(bytes.length, blob.size, blob.kind);
  }

  const runtime = JSON.parse(gunzipSync(result.blobs[0].gz).toString("utf8"));
  assert.deepEqual([runtime.seq, runtime.snapshotSha256, runtime.previous], [12, sha256Of(snapshot), "previous runtime"]);
  assert.deepEqual(result.fields, {
    snapshotSha: sha256Of(snapshot), runtimeSha: result.blobs[0].sha256, marshalSha: result.blobs[1].sha256, format: 3, runtimeFormat: 1, compiler: "1.3.0", gameData: sha256Of(join(folder, "game")),
  });
  assert.deepEqual(result.report.catalogDiff.removed, ["Lilith"]);

  await compiler.clean(7);
  assert.equal(existsSync(compiler.folderOf(7)), false);
});

test("exit 2 is refused with the compiler's report; any other exit, a timeout and a file unlike its report fail", async () => {
  const run = async (mode, limits = {}) => {
    const { compiler } = stubCompiler(mode, limits);
    await compiler.prepare(1, "{}");
    return compiler.compile({ buildId: 1, seq: 3, previous: null });
  };

  const refused = await run({ compile: "refuse" });
  assert.deepEqual([refused.status, refused.report.issues[0].code, refused.blobs.length, refused.fields.runtimeSha, refused.fields.format], ["refused", "formula", 0, null, 3]);

  const failed = await run({ compile: "fail" });
  assert.equal(failed.status, "failed");
  assert.deepEqual(failed.report.failure, { message: "The compiler failed with exit code 1.", exit: 1, output: "the stub failed on purpose" });
  assert.equal(failed.report.ok, false);

  const slow = await run({ sleepMs: 5000 }, { compileTimeoutMs: 300 });
  assert.deepEqual([slow.status, slow.report.failure.message], ["failed", "The compiler took longer than 1 s."]);

  const unlike = await run({ compile: "badsha" });
  assert.deepEqual([unlike.status, unlike.report.failure.message], ["failed", "The compiler's runtime.json does not match its report."]);
});

test("a compile whose snapshot was never prepared fails, and reset removes every build's folder", async () => {
  const { compiler } = stubCompiler();
  const result = await compiler.compile({ buildId: 9, seq: 1, previous: null });
  assert.equal(result.status, "failed");

  await compiler.prepare(10, "{}");
  await compiler.reset();
  assert.equal(existsSync(compiler.folderOf(10)), false);
});
