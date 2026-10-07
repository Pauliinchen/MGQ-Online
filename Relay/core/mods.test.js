//----------------------------------------------------------------
//  mods.test.js
//
//  Changelog:
//      Paulinchen  2026-10-06: Covered escaped keys, too large bodies, unchecked links listed for admins only and zips holding a file twice
//                            - Covered the options of a mod's current version, which only admins send
//                            - Covered zips whose files sit in a Patch folder
//                            - Covered zips of a release, hashed file by file
//                            - Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { playerIdOf } from "./directory.js";
import { MOD_LIMITS, ModCatalog, handleModRequest, hashModFile, modKey, splitUpload, zipHashes } from "./mods.js";

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
async function newCatalog(state, limits = MOD_LIMITS, fetcher = fakeGitHub(state)) {
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

  return { catalog: new ModCatalog(store, { clock: () => time.now, limits, admins: [await playerIdOf(ADMIN)], fetch: fetcher }), time, files };
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

test("an admin's game keeps the options of a mod's current version, which everyone lists", async () => {
  const { catalog } = await newCatalog({ tag: "v1.4.0", script: "# cap" });
  await catalog.setLink(ADMIN, "Level Cap", LATEST);
  const options = [{ key: "mod_level_cap", name: "Level Cap", type: "i", default: "1", choices: [{ value: "1", name: "On" }, { value: "0", name: "Off" }] }];

  assert.equal((await catalog.setOptions(OTHER, "levelcap", "1.4.0", options)).status, 403);
  assert.equal((await catalog.setOptions(ADMIN, "nomod", "1.4.0", options)).status, 404);
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.3.5", options)).status, 409, "only the current version's options are kept");
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.4.0", [{ key: "1bad", type: "i" }])).status, 400);
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.4.0", [{ key: "mod_x", type: "q" }])).status, 400);
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.4.0", options)).status, 200);

  const [mod] = (await catalog.list()).body.mods;
  assert.deepEqual([mod.options, mod.optionsVersion], [options, "1.4.0"]);
});

test("the options route reads a body larger than the other routes take", async () => {
  const { catalog } = await newCatalog({ tag: "v1.4.0", script: "# cap" });
  await catalog.setLink(ADMIN, "Level Cap", LATEST);
  const choices = Array.from({ length: 60 }, (_, index) => ({ value: String(index), name: `Choice ${index} `.padEnd(150, "x") }));
  const body = JSON.stringify({ player: ADMIN, version: "1.4.0", options: [{ key: "mod_level_cap", name: "Level Cap", type: "i", default: "0", choices }] });

  assert.ok(body.length > 8192);
  const answer = await handleModRequest(catalog, "POST", new URL("https://relay/v1/mods/levelcap/options"), async () => body, async () => null);
  assert.equal(answer.status, 200);
  assert.equal((await catalog.list()).body.mods[0].options[0].choices.length, 60);
});

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
  assert.equal((await catalog.list(ADMIN)).body.mods.length, 1, "an admin sees the link to fix it");
  assert.deepEqual((await catalog.list(OTHER)).body.mods, [], "a link never read keeps no game out of a world");
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

/**
 * Makes a zip, its files plain or deflated.
 *
 * @param {Array<[string, string, boolean?]>} entries Each file's name, text, and whether to deflate it.
 * @returns {Promise<Uint8Array>} The zip.
 */
async function makeZip(entries) {
  const parts = [];
  const directory = [];
  let offset = 0;

  for (const [name, text, deflate] of entries) {
    const data = new TextEncoder().encode(text);
    const packed = deflate ? new Uint8Array(await new Response(new Blob([data]).stream().pipeThrough(new CompressionStream("deflate-raw"))).arrayBuffer()) : data;
    const nameBytes = new TextEncoder().encode(name);
    const local = new DataView(new ArrayBuffer(30));
    local.setUint32(0, 0x04034b50, true);
    local.setUint16(8, deflate ? 8 : 0, true);
    local.setUint32(18, packed.length, true);
    local.setUint32(22, data.length, true);
    local.setUint16(26, nameBytes.length, true);
    const central = new DataView(new ArrayBuffer(46));
    central.setUint32(0, 0x02014b50, true);
    central.setUint16(10, deflate ? 8 : 0, true);
    central.setUint32(20, packed.length, true);
    central.setUint32(24, data.length, true);
    central.setUint16(28, nameBytes.length, true);
    central.setUint32(42, offset, true);
    parts.push(new Uint8Array(local.buffer), nameBytes, packed);
    directory.push(new Uint8Array(central.buffer), nameBytes);
    offset += 30 + nameBytes.length + packed.length;
  }

  const directorySize = directory.reduce((size, part) => size + part.length, 0);
  const end = new DataView(new ArrayBuffer(22));
  end.setUint32(0, 0x06054b50, true);
  end.setUint16(8, entries.length, true);
  end.setUint16(10, entries.length, true);
  end.setUint32(12, directorySize, true);
  end.setUint32(16, offset, true);
  const all = [...parts, ...directory, new Uint8Array(end.buffer)];
  const zip = new Uint8Array(all.reduce((size, part) => size + part.length, 0));
  let at = 0;

  for (const part of all) {
    zip.set(part, at);
    at += part.length;
  }

  return zip;
}

/**
 * A fake GitHub whose latest release holds a zip.
 *
 * @param {{tag: string, zip: Uint8Array}} state The current release.
 * @returns {typeof fetch} The fake fetch.
 */
function fakeZipRelease(state) {
  const base = "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases";
  return async (url) => {
    if (url === `${base}/latest/download/Luka_Replacer.zip`) {
      return new Response(null, { status: 302, headers: { Location: `${base}/download/${state.tag}/Luka_Replacer.zip` } });
    }

    if (url === `${base}/download/${state.tag}/Luka_Replacer.zip`) {
      return new Response(null, { status: 302, headers: { Location: "https://release-assets.githubusercontent.com/zip" } });
    }

    return url === "https://release-assets.githubusercontent.com/zip" ? new Response(state.zip, { status: 200 }) : new Response("not found", { status: 404 });
  };
}

test("zipHashes hashes every file of a zip by its path, plain or deflated, scripts without carriage returns", async () => {
  const zip = await makeZip([["Luka_Replacer.rb", "# hero\r\n", true], ["Luka_Replacer\\Heroes\\cecil.luka", "LUKA", false], ["Luka_Replacer/", ""]]);
  const files = await zipHashes(zip);

  assert.deepEqual(Object.keys(files), ["Luka_Replacer.rb", "Luka_Replacer/Heroes/cecil.luka"]);
  assert.equal(files["Luka_Replacer.rb"], await hashModFile("x.rb", new TextEncoder().encode("# hero\n")));
  assert.equal(files["Luka_Replacer/Heroes/cecil.luka"], await hashModFile("cecil.luka", new TextEncoder().encode("LUKA")));
});

test("zipHashes reads a zip whose files sit in a Patch folder by their paths inside it", async () => {
  const zip = await makeZip([["Patch/", ""], ["Patch/Luka_Replacer.rb", "# hero"], ["Patch/Luka_Replacer/Heroes/cecil.luka", "LUKA", true]]);

  assert.deepEqual(Object.keys(await zipHashes(zip)), ["Luka_Replacer.rb", "Luka_Replacer/Heroes/cecil.luka"]);
});

test("zipHashes refuses paths outside Patch, too many or too large files, and what is no zip", async () => {
  await assert.rejects(zipHashes(await makeZip([["../Game.exe", "x"]])), /no path inside Patch/);
  await assert.rejects(zipHashes(await makeZip([["a.rb", "x"], ["b.rb", "y"]]), { ...MOD_LIMITS, maxFiles: 1 }), /at most 1 files/);
  await assert.rejects(zipHashes(await makeZip([["a.rb", "x".repeat(20), true]]), { ...MOD_LIMITS, maxUnpackedBytes: 10 }), /bytes in all/);
  await assert.rejects(zipHashes(new TextEncoder().encode("# just a script")), /no zip/);
  await assert.rejects(zipHashes(await makeZip([["Folder/", ""]])), /no files/);
});

test("a link to a zip of a release keeps a hash per file and is marked as an archive", async () => {
  const state = { tag: "v1.0.0", zip: await makeZip([["Luka_Replacer.rb", "# one", true], ["Luka_Replacer/Heroes/a.luka", "A"]]) };
  const { catalog } = await newCatalog({ tag: "v1", script: "" }, MOD_LIMITS, fakeZipRelease(state));

  const answer = await catalog.setLink(ADMIN, "Luka Replacer", "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Luka_Replacer.zip");
  assert.equal(answer.body.mod.error, "");

  let mod = (await catalog.list()).body.mods[0];
  assert.deepEqual([mod.kind, mod.archive, mod.version, Object.keys(mod.files)], ["link", true, "1.0.0", ["Luka_Replacer.rb", "Luka_Replacer/Heroes/a.luka"]]);
  assert.match(mod.fileUrl, /\/download\/v1\.0\.0\/Luka_Replacer\.zip$/);

  state.tag = "v1.1.0";
  state.zip = await makeZip([["Luka_Replacer.rb", "# two", true], ["Luka_Replacer/Heroes/a.luka", "A"]]);
  assert.equal(await catalog.checkAll(), 1);
  mod = (await catalog.list()).body.mods[0];
  assert.deepEqual(mod.versions.map((version) => version.version), ["1.1.0", "1.0.0"]);

  state.zip = await makeZip([["../evil.rb", "x"]]);
  state.tag = "v1.2.0";
  await catalog.checkAll();
  mod = (await catalog.list(ADMIN)).body.mods[0];
  assert.equal(mod.version, "1.1.0");
  assert.match(mod.error, /no path inside Patch/);
});

test("a mod's key in a request's address is read percent-decoded, as the games escape it", async () => {
  const { catalog } = await newCatalog({ tag: "v1", script: "" });
  await catalog.upload(ADMIN, "Pack!", "1.0", upload([["Pack.rb", "cd".repeat(32)]], "PK"));
  const url = (path) => new URL(`https://relay.test${path}`);
  const none = async () => null;

  assert.equal((await handleModRequest(catalog, "GET", url(`/v1/mods/${encodeURIComponent("pack!")}/file`), async () => "", none)).status, 200);
  assert.equal((await handleModRequest(catalog, "GET", url("/v1/mods/%E0%A4%A/file"), async () => "", none)).status, 404);
});

test("a body larger than a route takes is answered with 413", async () => {
  const { catalog } = await newCatalog({ tag: "v1", script: "" });
  const url = (path) => new URL(`https://relay.test${path}`);
  const huge = async () => JSON.stringify({ player: ADMIN, padding: "x".repeat(MOD_LIMITS.maxOptionsBytes) });
  const none = async () => null;

  assert.equal((await handleModRequest(catalog, "POST", url("/v1/mods"), huge, none)).status, 413);
  assert.equal((await handleModRequest(catalog, "POST", url("/v1/mods/levelcap/options"), huge, none)).status, 413);
  assert.equal((await handleModRequest(catalog, "POST", url("/v1/mods/check"), async () => "no json", none)).status, 403);
});

test("zipHashes refuses a zip that holds a file twice", async () => {
  await assert.rejects(zipHashes(await makeZip([["Patch/a.rb", "x"], ["a.rb", "x"]])), /twice/);
});
