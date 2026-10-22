//----------------------------------------------------------------
//  mods.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Covered a check whose link still leads to the same release
//                            - Published a new release before holding the schedule's check, which reads only new ones
//      Paulinchen  2026-10-12: Covered changes made while a link is checked and an upload listed until the link that replaces it is checked
//                            - Covered a mod name with ':' refused by a link, an upload and a name alone
//      Paulinchen  2026-10-09: Covered personal mods and mods known by their name alone
//      Paulinchen  2026-10-08: Covered an older copy's options that do not replace a newer version's
//      Paulinchen  2026-10-07: Covered the options of any version kept until the current version's arrive
//                            - Uploaded real zips and covered a file list that says otherwise and a header that lies about a file's size
//                            - Expected 404 for an unknown sub-route and made the test zips through test_zip.js
//      Paulinchen  2026-10-06: Covered escaped keys, too large bodies, unchecked links listed for admins only and zips holding a file twice
//                            - Covered the options of a mod's current version
//                            - Covered zips whose files sit in a Patch folder
//                            - Covered zips of a release, hashed file by file
//                            - Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { playerIdOf } from "./directory.js";
import { MOD_LIMITS, ModCatalog, NAME_ONLY, OTHER_VERSION, handleModRequest, hashModFile, modKey, splitUpload, zipHashes } from "./mods.js";
import { makeUpload, makeZip } from "./test_zip.js";

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
 * A fake GitHub that, once armed, holds the next download of a release's script until the test
 * opens it, so the test can change the catalog while a link is checked.
 *
 * @param {{tag: string, script: string, host?: string, status?: number}} state The current release, changed by the tests.
 * @returns {{fetch: typeof fetch, arm: () => {reached: Promise<void>, open: () => void}}} The fake fetch, and how to arm it: `reached` settles once a check waits, `open` lets it go on.
 */
function gatedGitHub(state) {
  const github = fakeGitHub(state);
  let gate = null;

  return {
    fetch: async (url, init) => {
      if (gate && url.endsWith(`/file/${state.tag}`)) {
        const held = gate;
        gate = null;
        held.reach();
        await held.opened;
      }

      return github(url, init);
    },
    arm: () => {
      const armed = {};
      armed.reached = new Promise((resolve) => (armed.reach = resolve));
      armed.opened = new Promise((resolve) => (armed.open = resolve));
      gate = armed;
      return armed;
    },
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

/**
 * Makes a real upload: a zip of the files, and the file list with the hashes the relay will make.
 *
 * @param {Array<[string, string, boolean?]>} entries Each file's name, text, and whether to deflate it.
 * @returns {Promise<{zip: Uint8Array, upload: Uint8Array, files: Record<string, string>}>} The zip, the upload and the hashes.
 */
async function packed(entries) {
  const zip = await makeZip(entries);
  const files = await zipHashes(zip);
  return { zip, upload: makeUpload(files, zip), files };
}

test("an admin's game keeps the options of a mod's current version, which everyone lists", async () => {
  const { catalog } = await newCatalog({ tag: "v1.4.0", script: "# cap" });
  await catalog.setLink(ADMIN, "Level Cap", LATEST);
  const options = [{ key: "mod_level_cap", name: "Level Cap", type: "i", default: "1", choices: [{ value: "1", name: "On" }, { value: "0", name: "Off" }] }];

  const older = [{ key: "mod_level_cap", name: "Level Cap", type: "i", default: "1", choices: [] }];
  const listed = async () => (await catalog.list()).body.mods[0];

  assert.equal((await catalog.setOptions(OTHER, "levelcap", "1.4.0", options)).status, 403);
  assert.equal((await catalog.setOptions(ADMIN, "nomod", "1.4.0", options)).status, 404);
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.4.0", [{ key: "1bad", type: "i" }])).status, 400);
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.4.0", [{ key: "mod_x", type: "q" }])).status, 400);

  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "", older)).body.kept, true, "a copy of no known version is better than nothing");
  assert.deepEqual([(await listed()).options, (await listed()).optionsVersion], [older, OTHER_VERSION]);
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.3.5", older)).body.kept, true, "an older version's options replace those of no known version");
  assert.equal((await listed()).optionsVersion, "1.3.5");

  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.4.0", options)).body.kept, true);
  assert.deepEqual([(await listed()).options, (await listed()).optionsVersion], [options, "1.4.0"]);
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.3.5", older)).body.kept, false, "the current version's options stay");
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "", older)).body.kept, false);
  assert.deepEqual([(await listed()).options, (await listed()).optionsVersion], [options, "1.4.0"]);
});

test("an older copy's options never replace those of a newer version that is not the current one", async () => {
  const state = { tag: "v1.3.5", script: "# cap 1" };
  const { catalog } = await newCatalog(state);
  await catalog.setLink(ADMIN, "Level Cap", LATEST);
  state.tag = "v1.4.0";
  state.script = "# cap 2";
  await catalog.checkAll();
  state.tag = "v1.5.0";
  state.script = "# cap 3";
  await catalog.checkAll();
  const newer = [{ key: "mod_level_cap", name: "Level Cap", type: "i", default: "1", choices: [] }];
  const older = [{ key: "mod_level_cap", name: "Level Cap", type: "i", default: "0", choices: [] }];
  const listed = async () => (await catalog.list()).body.mods[0];

  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.4.0", newer)).body.kept, true);
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.3.5", older)).body.kept, false, "an older version's options do not replace a newer one's");
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "", older)).body.kept, false, "a copy of no known version does not replace a known version's");
  assert.deepEqual([(await listed()).options, (await listed()).optionsVersion], [newer, "1.4.0"]);
  assert.equal((await catalog.setOptions(ADMIN, "levelcap", "1.4.0", older)).body.kept, true, "the same version's options are taken anew");
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

test("a check whose link still leads to the same release downloads nothing", async () => {
  const state = { tag: "v1.3.5", script: "# one" };
  const github = fakeGitHub(state);
  let downloads = 0;
  const counting = async (url, init) => {
    downloads += url.endsWith(`/file/${state.tag}`) ? 1 : 0;
    return github(url, init);
  };
  const { catalog } = await newCatalog(state, MOD_LIMITS, counting);
  await catalog.setLink(ADMIN, "Level Cap", LATEST);
  assert.equal(downloads, 1);

  assert.equal(await catalog.checkAll(), 0);
  assert.equal(downloads, 1, "the same release is not read again");

  state.tag = "v1.4.0";
  state.script = "# two";
  assert.equal(await catalog.checkAll(), 1);
  assert.equal(downloads, 2);
  assert.equal((await catalog.list()).body.mods[0].version, "1.4.0");
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
  const { catalog, time } = await newCatalog({ tag: "v1", script: "" });
  const first = await packed([["Luka_Replacer.rb", "# one", true]]);
  const second = await packed([["Luka_Replacer.rb", "# two"], ["Luka_Replacer/Heroes/a.luka", "A", true]]);

  assert.equal((await catalog.upload(OTHER, "Luka Replacer", "1.0", first.upload)).status, 403);
  assert.equal((await catalog.upload(ADMIN, "Luka Replacer", "", first.upload)).status, 400);
  assert.equal((await catalog.upload(ADMIN, "Luka Replacer", "1.0", null)).status, 413);
  assert.equal((await catalog.upload(ADMIN, "Luka Replacer", "1.0", first.upload)).status, 200);

  time.now += 1000;
  assert.equal((await catalog.upload(ADMIN, "Luka Replacer", "1.1", second.upload)).status, 200);

  const [mod] = (await catalog.list()).body.mods;
  assert.deepEqual([mod.key, mod.kind, mod.version, mod.fileUrl], ["lukareplacer", "upload", "1.1", ""]);
  assert.deepEqual(mod.versions.map((version) => version.version), ["1.1", "1.0"]);
  assert.deepEqual(mod.files, second.files);
  assert.deepEqual((await catalog.file("lukareplacer")).bytes, second.zip);
  assert.equal((await catalog.file("levelcap")).status, 404);
});

test("an upload's hashes come from its zip, and a file list that says otherwise is refused", async () => {
  const { catalog } = await newCatalog({ tag: "v1", script: "" });
  const { zip, files } = await packed([["Pack.rb", "# pack"], ["Pack/a.luka", "A"]]);
  const wrongHash = makeUpload({ ...files, "Pack.rb": "00".repeat(32) }, zip);
  const missingFile = makeUpload({ "Pack.rb": files["Pack.rb"] }, zip);
  const extraFile = makeUpload({ ...files, "Pack/b.luka": "00".repeat(32) }, zip);
  const noZip = makeUpload(files, new TextEncoder().encode("PK"));

  for (const [upload, reason] of [[wrongHash, /does not match the zip at Pack\.rb/], [missingFile, /does not match the zip at Pack\/a\.luka/], [extraFile, /does not match/], [noZip, /no zip/]]) {
    const answer = await catalog.upload(ADMIN, "Pack", "1.0", upload);
    assert.equal(answer.status, 400);
    assert.match(answer.body.error, reason);
  }

  assert.deepEqual((await catalog.list()).body.mods, []);
  assert.equal((await catalog.upload(ADMIN, "Pack", "1.0", makeUpload(files, zip))).status, 200);
  assert.deepEqual((await catalog.list()).body.mods[0].files, files);
});

test("only an admin removes a mod, with its uploaded files", async () => {
  const { catalog, files } = await newCatalog({ tag: "v1", script: "" });
  await catalog.upload(ADMIN, "Luka Replacer", "1.0", (await packed([["Luka_Replacer.rb", "# hero"]])).upload);

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

  const pack = await packed([["Pack/a.luka", "A"]]);
  assert.equal((await handleModRequest(catalog, "POST", url(`/v1/mods/pack/upload?player=${ADMIN}&name=Pack&version=2`), body({}), async () => pack.upload)).status, 200);
  assert.deepEqual((await handleModRequest(catalog, "GET", url("/v1/mods/pack/file"), body({}), none)).bytes, pack.zip);
  assert.equal((await handleModRequest(catalog, "POST", url("/v1/mods/pack/delete"), body({ player: ADMIN }), none)).status, 200);
  assert.equal((await handleModRequest(catalog, "PUT", url("/v1/mods"), body({}), none)).status, 404);
  assert.equal((await handleModRequest(catalog, "GET", url("/v1/worlds"), body({}), none)).status, 404);
});

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
  await catalog.upload(ADMIN, "Pack!", "1.0", (await packed([["Pack.rb", "# pack"]])).upload);
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

test("zipHashes stops inflating an entry past the size its header claims", async () => {
  const text = "x".repeat(100_000);

  await assert.rejects(zipHashes(await makeZip([["a.rb", text, true, 10]])), /inflates past the size/);
  await assert.rejects(zipHashes(await makeZip([["a.rb", text, true, 200_000]])), /not the size the zip says/);
  await assert.rejects(zipHashes(await makeZip([["a.rb", text, false, 10]])), /not the size the zip says/);
  assert.deepEqual(Object.keys(await zipHashes(await makeZip([["a.rb", text, true]]))), ["a.rb"]);
});

test("only an admin marks a mod personal, which every game lists, checked or not", async () => {
  const state = { tag: "v1.4.0", script: "# cap" };
  const { catalog } = await newCatalog(state);
  await catalog.setLink(ADMIN, "Level Cap", LATEST);

  assert.equal((await catalog.setPersonal(OTHER, "levelcap", true)).status, 403);
  assert.equal((await catalog.setPersonal(ADMIN, "nomod", true)).status, 404);

  for (const bad of ["true", 1, null, undefined]) {
    assert.equal((await catalog.setPersonal(ADMIN, "levelcap", bad)).status, 400, `personal ${bad}`);
  }

  assert.equal((await catalog.list()).body.mods[0].personal, false);
  assert.deepEqual((await catalog.list()).body.personal, []);

  const marked = await catalog.setPersonal(ADMIN, "levelcap", true);
  assert.deepEqual([marked.status, marked.body.mod.personal], [200, true]);
  assert.equal((await catalog.list()).body.mods[0].personal, true);
  assert.deepEqual((await catalog.list()).body.personal, [{ key: "levelcap", name: "Level Cap" }]);

  state.status = 404;
  await catalog.setLink(ADMIN, "Victory Screen", LATEST.replace("Level_Cap", "Victory_Screen"));
  await catalog.setPersonal(ADMIN, "victoryscreen", true);
  const listed = (await catalog.list(OTHER)).body;
  assert.deepEqual(listed.mods.map((mod) => mod.key), ["levelcap"], "a link never read stays out of the mods");
  assert.deepEqual(listed.personal.map((mod) => mod.key), ["levelcap", "victoryscreen"], "but not out of the personal mods");

  assert.equal((await catalog.setPersonal(ADMIN, "levelcap", false)).body.mod.personal, false);
  assert.deepEqual((await catalog.list()).body.personal.map((mod) => mod.key), ["victoryscreen"]);
});

test("an admin adds a mod by its name alone, which is personal and never in the games' list of mods", async () => {
  const { catalog } = await newCatalog({ tag: "v1", script: "" });

  assert.equal((await catalog.setName(OTHER, "victoryscreen", "Victory_Screen")).status, 403);
  assert.equal((await catalog.setName(ADMIN, "victoryscreen", " ")).status, 400);
  assert.equal((await catalog.setName(ADMIN, "other", "Victory_Screen")).status, 400, "the name must have the address's key");

  const added = await catalog.setName(ADMIN, "victoryscreen", "Victory_Screen");
  assert.equal(added.status, 200);
  assert.deepEqual([added.body.mod.kind, added.body.mod.personal, added.body.mod.files, added.body.mod.link, added.body.mod.fileUrl], [NAME_ONLY, true, {}, "", ""]);

  const forGames = (await catalog.list(OTHER)).body;
  assert.deepEqual([forGames.mods, forGames.personal], [[], [{ key: "victoryscreen", name: "Victory_Screen" }]]);
  assert.deepEqual((await catalog.list(ADMIN)).body.mods.map((mod) => [mod.key, mod.kind]), [["victoryscreen", NAME_ONLY]], "admins see it");
  assert.equal((await catalog.file("victoryscreen")).status, 404, "there is nothing to download");

  await catalog.setPersonal(ADMIN, "victoryscreen", false);
  const renamed = await catalog.setName(ADMIN, "victoryscreen", "Victory Screen");
  assert.deepEqual([renamed.body.mod.name, renamed.body.mod.personal], ["Victory Screen", false], "a rename keeps the flag");
  assert.equal(await catalog.checkAll(), 0, "the schedule never checks it");

  assert.equal((await catalog.remove(ADMIN, "victoryscreen")).status, 200);
  assert.deepEqual((await catalog.list(ADMIN)).body.mods, []);
});

test("a mod known by its name alone is refused for a key the catalog hands out, and a mod keeps personal through kind changes", async () => {
  const { catalog } = await newCatalog({ tag: "v1.4.0", script: "# cap" });
  await catalog.setLink(ADMIN, "Level Cap", LATEST);
  await catalog.setPersonal(ADMIN, "levelcap", true);

  assert.equal((await catalog.setName(ADMIN, "levelcap", "Level_Cap")).status, 409);

  const uploaded = await catalog.upload(ADMIN, "Level Cap", "2.0", (await packed([["Level_Cap.rb", "# two"]])).upload);
  assert.deepEqual([uploaded.body.mod.kind, uploaded.body.mod.personal], ["upload", true], "link to upload");
  assert.equal((await catalog.setName(ADMIN, "levelcap", "Level Cap")).status, 409);

  const linked = await catalog.setLink(ADMIN, "Level Cap", LATEST);
  assert.deepEqual([linked.body.mod.kind, linked.body.mod.personal], ["link", true], "upload to link");

  await catalog.setName(ADMIN, "partysheet", "Party Sheet");
  const fromName = await catalog.upload(ADMIN, "Party Sheet", "1.0", (await packed([["Party_Sheet.rb", "# sheet"]])).upload);
  assert.deepEqual([fromName.body.mod.kind, fromName.body.mod.personal], ["upload", true], "name to upload");
  assert.deepEqual((await catalog.list(OTHER)).body.mods.map((mod) => [mod.key, mod.personal]), [["levelcap", true], ["partysheet", true]]);
});

test("handleModRequest routes marking a mod personal and adding one by name", async () => {
  const { catalog } = await newCatalog({ tag: "v1", script: "" });
  const url = (path) => new URL(`https://relay.test${path}`);
  const body = (value) => async () => JSON.stringify(value);
  const none = async () => null;

  const added = await handleModRequest(catalog, "POST", url(`/v1/mods/${encodeURIComponent("victoryscreen")}/name`), body({ player: ADMIN, name: "Victory_Screen" }), none);
  assert.deepEqual([added.status, added.body.mod.kind], [200, NAME_ONLY]);
  assert.equal((await handleModRequest(catalog, "POST", url("/v1/mods/victoryscreen/name"), body({ player: OTHER, name: "Victory_Screen" }), none)).status, 403);

  const unmarked = await handleModRequest(catalog, "POST", url("/v1/mods/victoryscreen/personal"), body({ personal: false }), none, ADMIN);
  assert.deepEqual([unmarked.status, unmarked.body.mod.personal], [200, false], "the player header counts");
  assert.equal((await handleModRequest(catalog, "POST", url("/v1/mods/victoryscreen/personal"), body({ player: ADMIN, personal: "no" }), none)).status, 400);
  assert.equal((await handleModRequest(catalog, "POST", url("/v1/mods/nomod/personal"), body({ player: ADMIN, personal: true }), none)).status, 404);
  assert.equal((await handleModRequest(catalog, "GET", url("/v1/mods/victoryscreen/personal"), body({}), none)).status, 404);
});

test("a mod removed during the schedule's check stays removed", async () => {
  const state = { tag: "v1.3.5", script: "# cap" };
  const github = gatedGitHub(state);
  const { catalog } = await newCatalog(state, MOD_LIMITS, github.fetch);
  await catalog.setLink(ADMIN, "Level Cap", LATEST);

  state.tag = "v1.4.0";
  const gate = github.arm();
  const checking = catalog.checkAll();
  await gate.reached;
  assert.equal((await catalog.remove(ADMIN, "levelcap")).status, 200);
  gate.open();

  assert.equal(await checking, 0);
  assert.deepEqual((await catalog.list(ADMIN)).body.mods, []);
});

test("a personal mark and options set during the schedule's check survive it, and the version moves on", async () => {
  const state = { tag: "v1.3.5", script: "# one" };
  const github = gatedGitHub(state);
  const { catalog } = await newCatalog(state, MOD_LIMITS, github.fetch);
  await catalog.setLink(ADMIN, "Level Cap", LATEST);
  const options = [{ key: "mod_level_cap", name: "Level Cap", type: "i", default: "1", choices: [] }];

  state.tag = "v1.4.0";
  state.script = "# two";
  const gate = github.arm();
  const checking = catalog.checkAll();
  await gate.reached;
  await catalog.setPersonal(ADMIN, "levelcap", true);
  await catalog.setOptions(ADMIN, "levelcap", "1.3.5", options);
  gate.open();

  assert.equal(await checking, 1);
  const [mod] = (await catalog.list(ADMIN)).body.mods;
  assert.deepEqual([mod.personal, mod.options, mod.optionsVersion, mod.version], [true, options, "1.3.5", "1.4.0"]);
});

test("a link changed during the schedule's check is not overwritten by the old link's result", async () => {
  const state = { tag: "v1.3.5", script: "# cap" };
  const github = gatedGitHub(state);
  const { catalog } = await newCatalog(state, MOD_LIMITS, github.fetch);
  await catalog.setLink(ADMIN, "Level Cap", LATEST);

  state.tag = "v1.3.6";
  const gate = github.arm();
  const checking = catalog.checkAll();
  await gate.reached;
  assert.equal((await catalog.setLink(ADMIN, "Level Cap", releaseFile("v1.3.6"))).status, 200);
  gate.open();

  assert.equal(await checking, 0);
  assert.equal((await catalog.list(ADMIN)).body.mods[0].link, releaseFile("v1.3.6"));
});

test("setLink keeps a personal mark set during its own check", async () => {
  const state = { tag: "v1.3.5", script: "# one" };
  const github = gatedGitHub(state);
  const { catalog } = await newCatalog(state, MOD_LIMITS, github.fetch);
  await catalog.setLink(ADMIN, "Level Cap", LATEST);

  state.tag = "v1.4.0";
  state.script = "# two";
  const gate = github.arm();
  const linking = catalog.setLink(ADMIN, "Level Cap", LATEST);
  await gate.reached;
  await catalog.setPersonal(ADMIN, "levelcap", true);
  gate.open();

  const answer = await linking;
  assert.deepEqual([answer.status, answer.body.mod.personal, answer.body.mod.version], [200, true, "1.4.0"]);
  assert.equal((await catalog.list(ADMIN)).body.mods[0].personal, true);
});

test("a mod removed while setLink checks its link stays removed", async () => {
  const state = { tag: "v1.3.5", script: "# cap" };
  const github = gatedGitHub(state);
  const { catalog } = await newCatalog(state, MOD_LIMITS, github.fetch);
  await catalog.setLink(ADMIN, "Level Cap", LATEST);

  const gate = github.arm();
  const linking = catalog.setLink(ADMIN, "Level Cap", LATEST);
  await gate.reached;
  await catalog.remove(ADMIN, "levelcap");
  gate.open();

  assert.deepEqual(await linking, { status: 409, body: { error: "the mod was removed while its link was checked" } });
  assert.deepEqual((await catalog.list(ADMIN)).body.mods, []);
});

test("an upload replaced by a link stays listed, with its files, until the link is checked", async () => {
  const state = { tag: "v1.3.5", script: "# cap" };
  const github = gatedGitHub(state);
  const { catalog, files } = await newCatalog(state, MOD_LIMITS, github.fetch);
  await catalog.upload(ADMIN, "Level Cap", "1.0", (await packed([["Level_Cap.rb", "# one"]])).upload);
  await catalog.setPersonal(ADMIN, "levelcap", true);

  const gate = github.arm();
  const linking = catalog.setLink(ADMIN, "Level Cap", LATEST);
  await gate.reached;
  assert.deepEqual((await catalog.list(OTHER)).body.mods.map((mod) => [mod.key, mod.kind]), [["levelcap", "upload"]]);
  assert.equal(files.size, 1);
  gate.open();

  const answer = await linking;
  assert.deepEqual([answer.status, answer.body.mod.kind, answer.body.mod.version, answer.body.mod.personal], [200, "link", "1.3.5", true]);
  assert.equal(files.size, 0, "the upload's zip goes once the link replaced it");
});

test("a new mod whose link is checked while the catalog fills up is refused", async () => {
  const state = { tag: "v1.3.5", script: "# cap" };
  const github = gatedGitHub(state);
  const { catalog } = await newCatalog(state, { ...MOD_LIMITS, maxMods: 1 }, github.fetch);

  const gate = github.arm();
  const linking = catalog.setLink(ADMIN, "Level Cap", LATEST);
  await gate.reached;
  assert.equal((await catalog.setName(ADMIN, "victoryscreen", "Victory_Screen")).status, 200);
  gate.open();

  assert.equal((await linking).status, 503);
  assert.deepEqual((await catalog.list(ADMIN)).body.mods.map((mod) => mod.key), ["victoryscreen"]);
});

test("a mod name with ':' is refused by a link, an upload and a name alone, and nothing is stored", async () => {
  const { catalog, files } = await newCatalog({ tag: "v1.4.0", script: "# cap" });
  const { upload: body } = await packed([["Luka_Replacer.rb", "# one"]]);

  for (const answer of [
    await catalog.setLink(ADMIN, "Level:Cap", LATEST),
    await catalog.upload(ADMIN, "Luka:Replacer", "1.0", body),
    await catalog.setName(ADMIN, "victory:screen", "Victory:Screen"),
  ]) {
    assert.deepEqual([answer.status, answer.body.error], [400, "a mod's name may not contain ':'"]);
  }

  assert.deepEqual((await catalog.list(ADMIN)).body.mods, []);
  assert.equal(files.size, 0);
});
