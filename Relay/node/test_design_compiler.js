//----------------------------------------------------------------
//  test_design_compiler.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

// What the compiler tests share: a DesignCompiler over a fresh copy of test_compiler_stub.js, run
// as a real child process, in a folder of its own.

import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { COMPILER_LIMITS, DesignCompiler } from "./design_compiler.js";

/**
 * The folders the stub compilers were made in.
 */
const folders = [];

/**
 * Makes a compiler over a fresh copy of the stub CLI, which does what the mode says.
 *
 * @param {object} [mode] The stub's mode, see test_compiler_stub.js.
 * @param {Partial<typeof COMPILER_LIMITS>} [limits] Limits other than the default ones.
 * @returns {{compiler: DesignCompiler, folder: string, setMode: (mode: object) => void, calls: () => string[]}} The compiler, its folder, a way to change the mode, and the stub's calls so far.
 */
export function stubCompiler(mode = {}, limits = {}) {
  const folder = mkdtempSync(join(tmpdir(), "mgq-compiler-"));
  folders.push(folder);
  const binary = join(folder, "bin");
  mkdirSync(binary);
  mkdirSync(join(folder, "game"));
  copyFileSync(new URL("./test_compiler_stub.js", import.meta.url), join(binary, "raid-designer.js"));
  const setMode = (next) => writeFileSync(join(binary, "mode.json"), JSON.stringify(next));
  setMode(mode);
  const compiler = new DesignCompiler(
    { compiler: join(binary, "raid-designer.js"), gameData: join(folder, "game"), dataDir: join(folder, "data"), launcher: [process.execPath] },
    { limits: { ...COMPILER_LIMITS, ...limits }, log: { error: () => {} } },
  );
  const calls = () => (existsSync(join(binary, "calls.log")) ? readFileSync(join(binary, "calls.log"), "utf8").split("\n").filter(Boolean) : []);
  return { compiler, folder, setMode, calls };
}

/**
 * Removes the folders of every stub compiler made so far.
 */
export function removeStubCompilers() {
  for (const folder of folders.splice(0)) {
    rmSync(folder, { recursive: true, force: true });
  }
}
