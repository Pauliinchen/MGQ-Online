//----------------------------------------------------------------
//  design_compiler.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

// The Raid Designer's command-line compiler as the relay runs it: a child process per call with a
// timeout, against the battle server's game data, in DESIGN_DATA_DIR/work/<build id>. The relay
// checks every file it writes against the compiler's report before it keeps them, gzipped. Node
// only; core/designs.js queues the builds and runs one at a time.

import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, readFile, realpath, rm, stat, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { promisify } from "node:util";
import { gunzip, gzip } from "node:zlib";

/**
 * The limits and timings of the compiler's calls.
 */
export const COMPILER_LIMITS = Object.freeze({
  compileTimeoutMs: 180 * 1000,
  // `--version` and `preflight`.
  probeTimeoutMs: 60 * 1000,
  // What the relay keeps of the compiler's stdout and stderr, in bytes.
  maxOutputBytes: 4 * 1024 * 1024,
  // What a failed build's report keeps of the compiler's output, in characters.
  outputTail: 2000,
  maxReportBytes: 16 * 1024 * 1024,
  maxFileBytes: 512 * 1024 * 1024,
});

/**
 * The compiler's exit codes the relay tells apart.
 */
export const COMPILER_EXIT = Object.freeze({ ok: 0, refused: 2, gameDataMissing: 4 });

/**
 * The folder under DESIGN_DATA_DIR each build is compiled in.
 */
const WORK_FOLDER = "work";

/**
 * The files the compiler writes into its output folder, by blob kind.
 */
const OUTPUT_FILES = Object.freeze({ runtime: "runtime.json", marshal: "RaidDesign.rvdata2", snapshot: "snapshot.json" });

/**
 * The compiler's report in its output folder.
 */
const REPORT_FILE = "report.json";

/**
 * A SHA-256 as the compiler's report writes it.
 */
const SHA256 = /^[0-9a-f]{64}$/;

/**
 * Compresses bytes with gzip.
 */
const gzipAsync = promisify(gzip);

/**
 * Decompresses gzip bytes.
 */
const gunzipAsync = promisify(gunzip);

/**
 * Reads the compiler settings from the environment.
 *
 * @param {Record<string, string | undefined>} env The environment: DESIGN_COMPILER (the compiler binary, such as /opt/mgq-designer/current/raid-designer), DESIGN_GAME_DATA (the game folder it compiles against) and DESIGN_DATA_DIR.
 * @returns {{compiler: string, gameData: string, dataDir: string} | null} The settings; null while one is missing, which leaves the builds off.
 */
export function designCompilerSettingsOf(env) {
  const compiler = env.DESIGN_COMPILER?.trim();
  const gameData = env.DESIGN_GAME_DATA?.trim();
  const dataDir = env.DESIGN_DATA_DIR?.trim();
  return compiler && gameData && dataDir ? { compiler, gameData, dataDir } : null;
}

/**
 * Runs a program and collects how it ended; never throws.
 *
 * @param {string} file The program.
 * @param {string[]} args Its arguments.
 * @param {{timeoutMs: number, maxOutputBytes: number}} limits How long it may run and how much output is kept.
 * @returns {Promise<{code: number | null, timedOut: boolean, stdout: string, stderr: string, error: string | null}>} Its exit code, null when it did not exit by itself or never started; whether it ran out of time; its output; and why it did not start or was stopped.
 */
export function runFile(file, args, limits) {
  return new Promise((resolve) => {
    execFile(file, args, { timeout: limits.timeoutMs, maxBuffer: limits.maxOutputBytes, killSignal: "SIGKILL", windowsHide: true }, (error, stdout, stderr) => {
      const code = error ? (Number.isInteger(error.code) ? error.code : null) : 0;
      resolve({ code, timedOut: Boolean(error?.killed && code === null), stdout: String(stdout ?? ""), stderr: String(stderr ?? ""), error: error ? error.message : null });
    });
  });
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
 * Reads a JSON file the compiler wrote.
 *
 * @param {string} path The file.
 * @param {number} limit The most bytes it may have.
 * @returns {Promise<any>} The JSON, undefined when the file is missing, too large or no JSON.
 */
async function readJsonFile(path, limit) {
  try {
    if ((await stat(path)).size > limit) {
      return undefined;
    }

    return JSON.parse(await readFile(path, "utf8"));
  } catch {
    return undefined;
  }
}

/**
 * Tells whether a value is a JSON object, not a list.
 *
 * @param {unknown} value The value.
 * @returns {boolean} Whether it is.
 */
function isObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * The Raid Designer's compiler, run as a child process.
 */
export class DesignCompiler {
  /**
   * Creates the compiler.
   *
   * @param {{compiler: string, gameData: string, dataDir: string, launcher?: string[]}} settings The compiler binary, the game folder, the folder builds are compiled in, and the program with its arguments that starts the binary, none unless given, which tests set to run a script.
   * @param {{run?: typeof runFile, limits?: typeof COMPILER_LIMITS, log?: {error: (line: string) => void}}} [options] Runs a program, which tests change; the limits; where a failed probe is logged.
   */
  constructor(settings, { run = runFile, limits = COMPILER_LIMITS, log = console } = {}) {
    this.settings = settings;
    this.run = run;
    this.limits = limits;
    this.log = log;
    /** @type {{identity: string, probe: {designFormat: number, version: string | null, message: string | null}} | null} */
    this.probed = null;
  }

  /**
   * Runs the compiler with arguments.
   *
   * @param {string[]} args The arguments.
   * @param {number} timeoutMs How long it may run.
   * @returns {Promise<{code: number | null, timedOut: boolean, stdout: string, stderr: string, error: string | null}>} How it ended, see runFile.
   */
  call(args, timeoutMs) {
    const [program, ...before] = this.settings.launcher ?? [];
    const file = program ?? this.settings.compiler;
    const all = program ? [...before, this.settings.compiler, ...args] : args;
    return this.run(file, all, { timeoutMs, maxOutputBytes: this.limits.maxOutputBytes });
  }

  /**
   * Tells which compiler binary is installed now, so a replaced one is probed again.
   *
   * @returns {Promise<string | null>} The binary's resolved path, size and change time; null when it is missing.
   */
  async identity() {
    try {
      const path = await realpath(this.settings.compiler);
      const info = await stat(path);
      return `${path}|${info.size}|${info.mtimeMs}`;
    } catch {
      return null;
    }
  }

  /**
   * Reads the compiler's version and design format and checks the game data, once per binary; a
   * failed probe is tried again on the next call, since the game data may be fixed meanwhile.
   *
   * @returns {Promise<{designFormat: number, version: string | null, message: string | null}>} The design format it writes, 0 for a compiler that is missing or names none; its version; and why it cannot compile, null when it can.
   */
  async probe() {
    const identity = await this.identity();

    if (identity === null) {
      this.log.error(`the compiler ${this.settings.compiler} is missing`);
      return { designFormat: 0, version: null, message: null };
    }

    if (this.probed?.identity === identity) {
      return this.probed.probe;
    }

    const probe = await this.freshProbe();

    if (probe.message === null && probe.designFormat > 0) {
      this.probed = { identity, probe };
    } else {
      this.log.error(`the compiler ${this.settings.compiler} failed its probe: ${probe.message ?? `design format ${probe.designFormat}`}`);
    }

    return probe;
  }

  /**
   * Runs `--version` and `preflight` of the compiler.
   *
   * @returns {Promise<{designFormat: number, version: string | null, message: string | null}>} The probe, see probe.
   */
  async freshProbe() {
    const versionRun = await this.call(["--version", "--json"], this.limits.probeTimeoutMs);
    let version;

    try {
      version = versionRun.code === COMPILER_EXIT.ok ? JSON.parse(versionRun.stdout) : undefined;
    } catch {
      version = undefined;
    }

    const designFormat = Number.isSafeInteger(version?.designFormat) && version.designFormat > 0 ? version.designFormat : 0;
    const named = typeof version?.version === "string" ? version.version : null;

    if (designFormat === 0) {
      return { designFormat, version: named, message: null };
    }

    const preflight = await this.call(["preflight", "--game", this.settings.gameData, "--json"], this.limits.probeTimeoutMs);

    if (preflight.code === COMPILER_EXIT.gameDataMissing) {
      return { designFormat, version: named, message: "The compiler misses game data on the relay." };
    }

    return { designFormat, version: named, message: preflight.code === COMPILER_EXIT.ok ? null : `The compiler's preflight failed with exit code ${preflight.code ?? "none"}.` };
  }

  /**
   * Names a build's folder.
   *
   * @param {number} buildId The build.
   * @returns {string} The folder.
   */
  folderOf(buildId) {
    return join(this.settings.dataDir, WORK_FOLDER, String(buildId));
  }

  /**
   * Keeps a build's snapshot for its compile, in a fresh folder.
   *
   * @param {number} buildId The build.
   * @param {string} snapshot The snapshot.
   * @returns {Promise<void>} Completes once written.
   */
  async prepare(buildId, snapshot) {
    const folder = this.folderOf(buildId);
    await rm(folder, { recursive: true, force: true });
    await mkdir(join(folder, "out"), { recursive: true });
    await writeFile(join(folder, "snapshot.json"), snapshot, "utf8");
  }

  /**
   * Compiles a prepared build; never throws.
   *
   * @param {{buildId: number, seq: number, previous: Uint8Array | null}} job The build, its seq, and the live build's runtime JSON gzipped, null before the first publish.
   * @returns {Promise<{status: string, report: object | null, fields: object, blobs: {sha256: string, kind: string, size: number, gz: Uint8Array}[]}>} `ok` with the build's fields and blobs; `refused` with the compiler's report when its checks found errors; `failed` with a report of what went wrong.
   */
  async compile({ buildId, seq, previous }) {
    const folder = this.folderOf(buildId);
    const out = join(folder, "out");

    try {
      const args = ["compile", "--snapshot", join(folder, "snapshot.json"), "--game", this.settings.gameData, "--out", out, "--seq", String(seq)];

      if (previous) {
        const path = join(folder, "previous.runtime.json");
        await writeFile(path, await gunzipAsync(previous));
        args.push("--previous", path);
      }

      const run = await this.call([...args, "--json"], this.limits.compileTimeoutMs);
      const report = await readJsonFile(join(out, REPORT_FILE), this.limits.maxReportBytes);

      if (run.timedOut) {
        return this.failed(`The compiler took longer than ${Math.ceil(this.limits.compileTimeoutMs / 1000)} s.`, run, report);
      }

      if (run.code === COMPILER_EXIT.refused) {
        return isObject(report) ? { status: "refused", report, fields: this.fieldsOf(report, null), blobs: [] } : this.failed("The compiler refused the design without a report.", run, report);
      }

      if (run.code !== COMPILER_EXIT.ok) {
        return this.failed(`The compiler failed with exit code ${run.code ?? "none"}.`, run, report);
      }

      return await this.collect(report, seq, out, run);
    } catch (error) {
      return this.failed(`The relay could not run the compiler: ${error.message}`, null, undefined);
    }
  }

  /**
   * Checks the compiler's files against its report and gzips them.
   *
   * @param {any} report The report.
   * @param {number} seq The build's seq.
   * @param {string} out The output folder.
   * @param {{stdout: string, stderr: string}} run How the compiler ended.
   * @returns {Promise<{status: string, report: object | null, fields: object, blobs: {sha256: string, kind: string, size: number, gz: Uint8Array}[]}>} The ok build, or the failed one whose files do not match its report.
   */
  async collect(report, seq, out, run) {
    const named = isObject(report) ? { runtime: report.runtime, marshal: report.marshal, snapshot: { sha256: report.snapshotSha256 } } : null;

    if (!named || report.ok !== true || report.seq !== seq || !Number.isSafeInteger(report.format) || !Object.values(named).every((file) => SHA256.test(file?.sha256 ?? ""))) {
      return this.failed("The compiler's report is not as the contract asks.", run, report);
    }

    const blobs = [];

    for (const [kind, name] of Object.entries(OUTPUT_FILES)) {
      const path = join(out, name);

      if ((await stat(path)).size > this.limits.maxFileBytes) {
        return this.failed(`The compiler's ${name} is too large.`, run, report);
      }

      const bytes = await readFile(path);
      const sha256 = sha256Of(bytes);
      const size = named[kind].size;

      if (sha256 !== named[kind].sha256 || (size !== undefined && size !== bytes.length)) {
        return this.failed(`The compiler's ${name} does not match its report.`, run, report);
      }

      blobs.push({ sha256, kind, size: bytes.length, gz: new Uint8Array(await gzipAsync(bytes, { level: 9 })) });
    }

    return { status: "ok", report, fields: this.fieldsOf(report, blobs), blobs };
  }

  /**
   * Reads a build's fields from the compiler's report.
   *
   * @param {any} report The report.
   * @param {{sha256: string, kind: string}[] | null} blobs The build's blobs, null for a build without them.
   * @returns {{snapshotSha: string | null, runtimeSha: string | null, marshalSha: string | null, format: number | null, runtimeFormat: number | null, compiler: string | null, gameData: string | null}} The fields.
   */
  fieldsOf(report, blobs) {
    const sha = (kind) => blobs?.find((blob) => blob.kind === kind)?.sha256 ?? null;
    const whole = (value) => (Number.isSafeInteger(value) ? value : null);
    const text = (value) => (typeof value === "string" ? value : null);
    return {
      snapshotSha: sha("snapshot"), runtimeSha: sha("runtime"), marshalSha: sha("marshal"), format: whole(report?.format), runtimeFormat: whole(report?.runtimeFormat),
      compiler: text(report?.compiler), gameData: text(report?.gameData),
    };
  }

  /**
   * Makes the result of a failed build: the compiler's report where it wrote one, with what went
   * wrong and the end of its output.
   *
   * @param {string} message What went wrong.
   * @param {{code?: number | null, stdout: string, stderr: string} | null} run How the compiler ended, null when it never ran.
   * @param {any} report The compiler's report, undefined for none.
   * @returns {{status: string, report: object, fields: object, blobs: []}} The result.
   */
  failed(message, run, report) {
    const output = run ? (run.stderr.trim() || run.stdout.trim()).slice(-this.limits.outputTail) : "";
    const failure = { message, ...(run ? { exit: run.code ?? null } : {}), ...(output ? { output } : {}) };
    return { status: "failed", report: { ...(isObject(report) ? report : {}), ok: false, failure }, fields: this.fieldsOf(isObject(report) ? report : null, null), blobs: [] };
  }

  /**
   * Removes a build's folder.
   *
   * @param {number} buildId The build.
   * @returns {Promise<void>} Completes once removed.
   */
  clean(buildId) {
    return rm(this.folderOf(buildId), { recursive: true, force: true });
  }

  /**
   * Removes every build's folder, as the relay starts.
   *
   * @returns {Promise<void>} Completes once removed.
   */
  reset() {
    return rm(join(this.settings.dataDir, WORK_FOLDER), { recursive: true, force: true });
  }
}
