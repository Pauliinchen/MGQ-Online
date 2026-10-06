//----------------------------------------------------------------
//  mods.test.js
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { playerIdOf } from "./directory.js";
import { MOD_LIMITS, ModCatalog, handleModRequest, hashModFile, modKey, splitUpload } from "./mods.js";

/**
 * An admin's player key.
 */
const ADMIN = "ad".repeat(16);

/**
 * Another player's key.
 */
const OTHER = "0f".repeat(16);

/**
 * The link an admin sets: always the latest release's script.
 */
const LATEST = "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Level_Cap.rb";

/**
 * A release's script on GitHub, by its tag.
 *
 * @param {string} tag The release's tag.
 * @returns {string} The address.
 */
function releaseFile(tag) {
  return `https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/${tag}/Level_Cap.rb`;
}

/**
 * A fake GitHub: the latest link leads to the current release's script, which GitHub's file host serves.
 *
 * @param {{tag: string, script: string, host?: string, status?: number}} state The current release, changed by the tests.
 * @returns {typeof fetch} The fake fetch.
 */
function fakeGitHub(state) {
  return async (url) => {
    if (url === LATEST) {
      return new Response(null, { status: state.status ?? 302, headers: { Location: releaseFile(state.tag) } });
    }

    if (url === releaseFile(state.tag)) {
      return new Response(null, { status: 302, headers: { Location: `https://${state.host ?? "release-assets.githubusercontent.com"}/file/${state.tag}` } });
    }

    if (url.endsWith(`/file/${state.tag}`)) {
      return new Response(state.script, { status: 200 });
    }

    return new Response("not found", { status: 404 });
  };
}

/**
 * Makes a catalog over a store in memory, with the test admin and a fake GitHub.
 *
 * @param {object} state The fake GitHub's current release.
 * @param {object} [limits] The limits.
 * @returns {Promise<{catalog: ModCatalog, time: {now: number}, files: Map}>} The catalog, its clock and the uploaded zips.
 */
async function newCatalog(state, limits = MOD_LIMITS) {
  const mods = new Map();
  const files = new Map();
  const time = { now: 1_000_000 };
  const store = {
    getMod: async (key) => (mods.has(key) ? structuredClone(mods.get(key)) : undefined),
    putMod: async (entry) => void mods.set(entry.key, structuredClone(entry)),
    removeMod: async (key) => {
      mods.delete(key);
      files.delete(key);
    },
    allMods: async () => [...mods.values()].map((entry) => structuredClone(entry)),
    putModFile: async (key, bytes) => void files.set(key, Uint8Array.from(bytes)),
    getModFile: async (key) => files.get(key),
  };

  return { catalog: new ModCatalog(store, { clock: () => time.now, limits, admins: [await playerIdOf(ADMIN)], fetch: fakeGitHub(state) }), time, files };
}

/**
 * Makes an upload: the file list, an empty line, then the zip.
 *
 * @param {string[][]} files Each file's path and hash.
 * @param {string} zip The zip's bytes.
 * @returns {Uint8Array} The upload.
 */
function upload(files, zip) {
  return new TextEncoder().encode(`${files.map(([path, hash]) => `${path}\t${hash}`).join("\n")}\n\n${zip}`);
}

test("modKey compares names the way the games do", () => {
  assert.equal(modKey("Level_Cap.rb"), "levelcap");
  assert.equal(modKey("Level Cap"), "levelcap");
  assert.equal(modKey("Luka-Replacer"), "lukareplacer");
});

test("a script hashes the same with and without carriage returns, other files as they are", async () => {
  const unix = new TextEncoder().encode("a\nb\n");
  const windows = new TextEncoder().encode("a\r\nb\r\n");

  assert.equal(await hashModFile("Mod.rb", unix), await hashModFile("Mod.rb", windows));
  assert.notEqual(await hashModFile("pack.luka", unix), await hashModFile("pack.luka", windows));
});

test("only an admin adds a mod, by a link on the admins' GitHub", async () => {
  const { catalog } = await newCatalog({ tag: "v1.3.5", script: "# cap" });

  assert.equal((await catalog.setLink(OTHER, "Level Cap", LATEST)).status, 403);
  assert.equal((await catalog.setLink(ADMIN, "Level Cap", "https://example.com/Level_Cap.rb")).status, 400);
  assert.equal((await catalog.setLink(ADMIN, " ", LATEST)).status, 400);
  assert.deepEqual((await catalog.list()).body.mods, []);
});

test("a link mod takes its version from the release's tag and the hash of its script", async () => {
  const { catalog } = await newCatalog({ tag: "v1.3.5", script: "# cap\r\n" });

  const answer = await catalog.setLink(ADMIN, "Level Cap", LATEST);
  assert.equal(answer.status, 200);
  assert.equal(answer.body.mod.error, "");

  const [mod] = (await catalog.list()).body.mods;
  assert.deepEqual([mod.key, mod.name, mod.kind, mod.version, mod.fileUrl], ["levelcap", "Level Cap", "link", "1.3.5", releaseFile("v1.3.5")]);
  assert.deepEqual(mod.files, { "Level_Cap.rb": await hashModFile("Level_Cap.rb", new TextEncoder().encode("# cap\n")) });
  assert.equal(mod.link, undefined, "the link is for admins only");
  assert.equal((await catalog.list(ADMIN)).body.mods[0].link, LATEST);
});

test("a new release becomes the latest version, the earlier ones kept to name a player's copy", async () => {
  const state = { tag: "v1.3.5", script: "# one" };
  const { catalog } = await newCatalog(state);
  await catalog.setLink(ADMIN, "Level Cap", LATEST);

  assert.equal(await catalog.checkAll(), 0);
  state.tag = "v1.4.0";
  state.script = "# two";
  assert.equal(await catalog.checkAll(), 1);

  const [mod] = (await catalog.list()).body.mods;
  assert.equal(mod.version, "1.4.0");
  assert.deepEqual(mod.versions.map((version) => version.version), ["1.4.0", "1.3.5"]);

  state.tag = "v1.4.1";
  assert.equal(await catalog.checkAll(), 1, "a new tag with the same script is a new version name");
  assert.deepEqual((await catalog.list()).body.mods[0].versions.map((version) => version.version), ["1.4.1", "1.3.5"]);
});

test("a release that cannot be read keeps the last good version and tells the admin why", async () => {
  const state = { tag: "v1.3.5", script: "# cap" };
  const { catalog } = await newCatalog(state);
  await catalog.setLink(ADMIN, "Level Cap", LATEST);

  state.status = 404;
  await catalog.checkAll();
  let mod = (await catalog.list(ADMIN)).body.mods[0];
  assert.equal(mod.version, "1.3.5");
  assert.match(mod.error, /404/);

  state.status = undefined;
  state.host = "evil.example.com";
  state.tag = "v2.0.0";
  await catalog.checkAll();
  mod = (await catalog.list(ADMIN)).body.mods[0];
  assert.equal(mod.version, "1.3.5");
  assert.match(mod.error, /no GitHub file host/);
});

test("a release file larger than the limit is refused", async () => {
  const { catalog } = await newCatalog({ tag: "v1.0.0", script: "x".repeat(20) }, { ...MOD_LIMITS, maxLinkBytes: 10 });
  const answer = await catalog.setLink(ADMIN, "Level Cap", LATEST);
  assert.equal(answer.body.mod.version, "");
  assert.match(answer.body.mod.error, /bytes/);
});

test("splitUpload reads the file list and refuses paths outside Patch", () => {
  const hash = "ab".repeat(32);
  const good = splitUpload(upload([["Luka_Replacer.rb", hash], ["Luka_Replacer/Heroes/cecil.luka", hash]], "PK"));
  assert.deepEqual(Object.keys(good.files), ["Luka_Replacer.rb", "Luka_Replacer/Heroes/cecil.luka"]);
  assert.equal(new TextDecoder().decode(good.zip), "PK");

  for (const path of ["../Game.exe", "/abs.rb", "C:/x.rb", "a/../../b.rb", "a\\b.rb"]) {
    assert.equal(typeof splitUpload(upload([[path, hash]], "PK")), "string", path);
  }

  assert.equal(typeof splitUpload(upload([["a.rb", "nohash"]], "PK")), "string");
  assert.equal(typeof splitUpload(new TextEncoder().encode("a.rb\tx")), "string");
});

test("only an admin uploads a mod of several files, which games then fetch", async () => {
  const hash = "cd".repeat(32);
  const { catalog, time } = await newCatalog({ tag: "v1", script: "" });

  assert.equal((await catalog.upload(OTHER, "Luka Replacer", "1.0", upload([["Luka_Replacer.rb", hash]], "PK1"))).status, 403);
  assert.equal((await catalog.upload(ADMIN, "Luka Replacer", "", upload([["Luka_Replacer.rb", hash]], "PK1"))).status, 400);
  assert.equal((await catalog.upload(ADMIN, "Luka Replacer", "1.0", null)).status, 413);
  assert.equal((await catalog.upload(ADMIN, "Luka Replacer", "1.0", upload([["Luka_Replacer.rb", hash]], "PK1"))).status, 200);

  time.now += 1000;
  await catalog.upload(ADMIN, "Luka Replacer", "1.1", upload([["Luka_Replacer.rb", "ef".repeat(32)]], "PK2"));

  const [mod] = (await catalog.list()).body.mods;
  assert.deepEqual([mod.key, mod.kind, mod.version, mod.fileUrl], ["lukareplacer", "upload", "1.1", ""]);
  assert.deepEqual(mod.versions.map((version) => version.version), ["1.1", "1.0"]);
  assert.equal(new TextDecoder().decode((await catalog.file("lukareplacer")).bytes), "PK2");
  assert.equal((await catalog.file("levelcap")).status, 404);
});

test("only an admin removes a mod, with its uploaded files", async () => {
  const { catalog, files } = await newCatalog({ tag: "v1", script: "" });
  await catalog.upload(ADMIN, "Luka Replacer", "1.0", upload([["Luka_Replacer.rb", "cd".repeat(32)]], "PK"));

  assert.equal((await catalog.remove(OTHER, "lukareplacer")).status, 403);
  assert.equal((await catalog.remove(ADMIN, "nothing")).status, 404);
  assert.equal((await catalog.remove(ADMIN, "lukareplacer")).status, 200);
  assert.deepEqual([(await catalog.list()).body.mods, files.size], [[], 0]);
});

test("handleModRequest routes the catalog's requests", async () => {
  const state = { tag: "v1.3.5", script: "# cap" };
  const { catalog } = await newCatalog(state);
  const url = (path) => new URL(`https://relay.test${path}`);
  const body = (value) => async () => JSON.stringify(value);
  const none = async () => null;

  assert.equal((await handleModRequest(catalog, "POST", url("/v1/mods"), body({ player: ADMIN, name: "Level Cap", link: LATEST }), none)).status, 200);
  assert.equal((await handleModRequest(catalog, "GET", url("/v1/mods"), body({}), none)).body.mods.length, 1);

  state.tag = "v1.4.0";
  const checked = await handleModRequest(catalog, "POST", url("/v1/mods/check"), body({ player: ADMIN }), none);
  assert.equal(checked.body.mods[0].version, "1.4.0");
  assert.equal((await handleModRequest(catalog, "POST", url("/v1/mods/check"), body({ player: OTHER }), none)).status, 403);

  const zip = upload([["Pack/a.luka", "ab".repeat(32)]], "PK");
  assert.equal((await handleModRequest(catalog, "POST", url(`/v1/mods/pack/upload?player=${ADMIN}&name=Pack&version=2`), body({}), async () => zip)).status, 200);
  assert.equal(new TextDecoder().decode((await handleModRequest(catalog, "GET", url("/v1/mods/pack/file"), body({}), none)).bytes), "PK");
  assert.equal((await handleModRequest(catalog, "POST", url("/v1/mods/pack/delete"), body({ player: ADMIN }), none)).status, 200);
  assert.equal((await handleModRequest(catalog, "PUT", url("/v1/mods"), body({}), none)).status, 405);
  assert.equal((await handleModRequest(catalog, "GET", url("/v1/worlds"), body({}), none)).status, 404);
});
