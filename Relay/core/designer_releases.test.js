//----------------------------------------------------------------
//  designer_releases.test.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

import { after, test } from "node:test";
import assert from "node:assert/strict";
import { createHash, createPublicKey, generateKeyPairSync, sign } from "node:crypto";
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  DESIGNER_PRODUCT, DESIGNER_RELEASE_LIMITS, DESIGNER_REPO, DesignerReleases, byteRangeOf, designerReleaseSettingsOf, readSignedManifest, releaseFileNames,
} from "./designer_releases.js";
import { fixture } from "./test_designs.js";

/**
 * The key that signs the fake releases, and one that does not.
 */
const KEY = generateKeyPairSync("ec", { namedCurve: "P-256" });
const OTHER_KEY = generateKeyPairSync("ec", { namedCurve: "P-256" });

/**
 * The release key's public half as the relay's setting holds it.
 */
const PUBLIC_PEM = KEY.publicKey.export({ type: "spki", format: "pem" });

/**
 * The token the fake GitHub takes.
 */
const TOKEN = "github_pat_test";

/**
 * The repository of the fake releases.
 */
const REPO = "owner/designer";

/**
 * The folders the tests made, removed at the end.
 */
const folders = [];

after(() => {
  for (const folder of folders) {
    rmSync(folder, { recursive: true, force: true });
  }
});

/**
 * Makes an empty folder for a test.
 *
 * @returns {string} The folder.
 */
function freshFolder() {
  const folder = mkdtempSync(join(tmpdir(), "mgq-designer-releases-"));
  folders.push(folder);
  return folder;
}

/**
 * Builds a release as the release workflow uploads it.
 *
 * @param {string} version The version.
 * @param {{exe?: Buffer, signWith?: object, manifestSha?: string, manifestSize?: number, product?: string}} [options] The exe's bytes; the key that signs, the release key unless given; the SHA-256 and size the manifest names, the exe's unless given; the product.
 * @returns {{version: string, exe: Buffer, manifest: Buffer, signature: Buffer, ids: {exe: number, manifest: number, signature: number}}} The release.
 */
function makeRelease(version, { exe = Buffer.from(`exe of ${version} `.repeat(5000)), signWith = KEY.privateKey, manifestSha, manifestSize, product = DESIGNER_PRODUCT } = {}) {
  const names = releaseFileNames(version);
  const manifest = Buffer.from(JSON.stringify({
    product, version, commit: "abc1234", designFormat: 1,
    files: [
      { rid: "win-x64", name: names.exe, size: manifestSize ?? exe.length, sha256: manifestSha ?? createHash("sha256").update(exe).digest("hex") },
      { rid: "linux-x64", name: `raid-designer-cli-${version}-linux-x64`, size: 10, sha256: "0".repeat(64) },
    ],
    notes: `Notes of ${version}.`,
  }));
  const base = Number(version.replaceAll(".", "")) * 10;
  return { version, exe, manifest, signature: sign("sha256", manifest, { key: signWith, dsaEncoding: "der" }), ids: { exe: base + 1, manifest: base + 2, signature: base + 3 } };
}

/**
 * Makes a fake GitHub that serves one latest release and counts what it is asked.
 *
 * @returns {{fetcher: typeof fetch, calls: {url: string, headers: Record<string, string>}[], latest: {release: object | null, status: number, assets?: object[]}}} The fetcher, the calls it took and the release it serves, which tests change.
 */
function fakeGitHub() {
  const calls = [];
  const latest = { release: null, status: 200 };
  const fetcher = async (url, init) => {
    calls.push({ url, headers: init.headers });

    if (init.headers.Authorization !== `Bearer ${TOKEN}`) {
      return new Response("{}", { status: 401 });
    }

    if (url === `https://api.github.test/repos/${REPO}/releases/latest`) {
      if (latest.status !== 200 || !latest.release) {
        return new Response(JSON.stringify({ message: "Not Found" }), { status: latest.status === 200 ? 404 : latest.status });
      }

      const release = latest.release;
      const names = releaseFileNames(release.version);
      const assets = latest.assets ?? [
        { id: release.ids.exe, name: names.exe, size: release.exe.length },
        { id: release.ids.manifest, name: names.manifest, size: release.manifest.length },
        { id: release.ids.signature, name: names.signature, size: release.signature.length },
      ];
      return new Response(JSON.stringify({ tag_name: `v${release.version}`, body: "release text", assets }), { status: 200 });
    }

    const asset = /\/releases\/assets\/(\d+)$/.exec(url);
    const release = latest.release;

    if (asset && release && init.headers.Accept === "application/octet-stream") {
      const id = Number(asset[1]);
      const bytes = id === release.ids.exe ? release.exe : id === release.ids.manifest ? release.manifest : id === release.ids.signature ? release.signature : null;
      return bytes ? new Response(bytes, { status: 200 }) : new Response("{}", { status: 404 });
    }

    return new Response("{}", { status: 404 });
  };
  return { fetcher, calls, latest };
}

/**
 * Makes the releases over a fake GitHub and a fresh folder.
 *
 * @param {{folder?: string, github?: ReturnType<typeof fakeGitHub>, clock?: () => number, tokenExpires?: number | null}} [options] The data folder, the fake GitHub, the clock and the token's expiry.
 * @returns {{releases: DesignerReleases, github: ReturnType<typeof fakeGitHub>, folder: string, lines: string[]}} The releases, the fake GitHub, the folder and the lines logged.
 */
function testReleases({ folder = freshFolder(), github = fakeGitHub(), clock = Date.now, tokenExpires = null } = {}) {
  const lines = [];
  const log = { info: (line) => lines.push(line), error: (line) => lines.push(line) };
  const releases = new DesignerReleases({ repo: REPO, token: TOKEN, publicKey: PUBLIC_PEM, dataDir: folder, tokenExpires }, { fetcher: github.fetcher, clock, log, api: "https://api.github.test" });
  return { releases, github, folder, lines };
}

/**
 * Lists the files in the releases folder.
 *
 * @param {string} folder The data folder.
 * @returns {string[]} Their names, sorted.
 */
function keptFiles(folder) {
  const path = join(folder, "releases");
  return existsSync(path) ? readdirSync(path).sort() : [];
}

test("a signed manifest is read; a wrong key, a changed byte, another product or version and a missing exe are refused", () => {
  const release = makeRelease("1.3.0");
  const publicKey = createPublicKey(PUBLIC_PEM);
  const read = readSignedManifest(release.manifest, release.signature, publicKey, "1.3.0");
  assert.deepEqual(read, { notes: "Notes of 1.3.0.", exe: { name: "RaidDesigner-1.3.0-win-x64.exe", size: release.exe.length, sha256: createHash("sha256").update(release.exe).digest("hex") } });

  const changed = Buffer.from(release.manifest);
  changed[10] ^= 1;
  assert.throws(() => readSignedManifest(release.manifest, makeRelease("1.3.0", { signWith: OTHER_KEY.privateKey }).signature, publicKey, "1.3.0"), /signature/);
  assert.throws(() => readSignedManifest(changed, release.signature, publicKey, "1.3.0"), /signature/);
  assert.throws(() => readSignedManifest(release.manifest, Buffer.from("not der"), publicKey, "1.3.0"), /signature/);
  assert.throws(() => readSignedManifest(release.manifest, release.signature, publicKey, "1.4.0"), /names/);

  const other = makeRelease("1.3.0", { product: "Something else" });
  assert.throws(() => readSignedManifest(other.manifest, other.signature, publicKey, "1.3.0"), /names Something else/);

  const noExe = makeRelease("1.3.0", { manifestSha: "nope" });
  assert.throws(() => readSignedManifest(noExe.manifest, noExe.signature, publicKey, "1.3.0"), /no win-x64 exe/);
});

test("the contract's manifest names the exe the relay reads", () => {
  const manifest = fixture("manifest.json");
  const exe = manifest.files.find((file) => file.rid === "win-x64");
  assert.equal(exe.name, releaseFileNames(manifest.version).exe);
  assert.equal(manifest.product, DESIGNER_PRODUCT);
});

test("a check keeps a release whose signature and exe check out and serves it as release.json shows", async () => {
  const { releases, github, folder } = testReleases();
  const release = makeRelease("1.3.0");
  github.latest.release = release;

  assert.equal(releases.answer("1.2.0").status, 404, "none before the first check");
  assert.equal(releases.file(), null);
  assert.equal(await releases.check(), "1.3.0");

  const sha256 = createHash("sha256").update(release.exe).digest("hex");
  const answer = releases.answer("1.2.0");
  assert.deepEqual(answer, {
    status: 200,
    body: { version: "1.3.0", minimum: "1.2.0", notes: "Notes of 1.3.0.", manifest: release.manifest.toString("base64"), signature: release.signature.toString("base64"), size: release.exe.length, sha256 },
  });
  assert.deepEqual(Object.keys(answer.body), Object.keys(fixture("release.json").exchanges[0].response.body), "the keys of release.json");
  assert.deepEqual(Buffer.from(answer.body.manifest, "base64"), release.manifest, "the exact manifest bytes");
  assert.deepEqual(releases.file(), { path: join(folder, "releases", `${sha256}.exe`), name: "RaidDesigner-1.3.0-win-x64.exe", size: release.exe.length, sha256 });
  assert.deepEqual(readFileSync(releases.file().path), release.exe);
  assert.deepEqual(keptFiles(folder), [`${sha256}.exe`, "current.json"]);

  assert.ok(github.calls.every((call) => call.headers.Authorization === `Bearer ${TOKEN}` && !call.url.includes(TOKEN)), "the token goes in the header only");
  assert.ok(github.calls.every((call) => call.url.startsWith(`https://api.github.test/repos/${REPO}/`)));
});

test("the cache: a check of the same release downloads nothing, and a restart takes the kept release up", async () => {
  const { releases, github, folder } = testReleases();
  github.latest.release = makeRelease("1.3.0");
  await releases.check();
  const calls = github.calls.length;

  assert.equal(await releases.check(), null);
  assert.equal(github.calls.length, calls + 1, "only the latest release is read");

  const restarted = testReleases({ folder, github });
  assert.equal(await restarted.releases.load(), "1.3.0");
  assert.deepEqual(restarted.releases.answer("1.2.0"), releases.answer("1.2.0"));
  assert.equal(await restarted.releases.check(), null, "the kept release is the latest");
  assert.equal(github.calls.length, calls + 2);
});

test("a restart leaves a kept release whose exe changed, and a folder without one, for the next check", async () => {
  const { releases, github, folder } = testReleases();
  github.latest.release = makeRelease("1.3.0");
  await releases.check();

  assert.equal(await testReleases({ folder: freshFolder(), github }).releases.load(), null, "nothing kept, nothing logged");

  writeFileSync(releases.file().path, "changed");
  const restarted = testReleases({ folder, github });
  assert.equal(await restarted.releases.load(), null);
  assert.match(restarted.lines.join("\n"), /differs from its manifest/);
  assert.equal(restarted.releases.answer("1.2.0").status, 404);

  assert.equal(await restarted.releases.check(), "1.3.0", "the check downloads it again");
  assert.equal(await testReleases({ folder, github }).releases.load(), "1.3.0");
});

test("a bad signature keeps nothing and leaves the release served as it was", async () => {
  const { releases, github, folder } = testReleases();
  github.latest.release = makeRelease("1.3.0");
  await releases.check();
  const served = releases.answer("1.2.0");

  github.latest.release = makeRelease("1.4.0", { signWith: OTHER_KEY.privateKey });
  await assert.rejects(releases.check(), /signature does not verify/);
  assert.deepEqual(releases.answer("1.2.0"), served);
  assert.equal(keptFiles(folder).length, 2, "no exe of 1.4.0 downloaded");
  assert.ok(github.calls.every((call) => !call.url.endsWith(`/assets/${github.latest.release.ids.exe}`)));
});

test("an exe whose SHA-256 or size differs from the manifest is never kept", async () => {
  const { releases, github, folder } = testReleases();
  github.latest.release = makeRelease("1.3.0", { manifestSha: "ab".repeat(32) });
  await assert.rejects(releases.check(), /differs from its manifest/);
  assert.deepEqual(keptFiles(folder), [], "no exe and no part left");
  assert.equal(releases.answer("1.2.0").status, 404);

  const short = makeRelease("1.3.0");
  github.latest.release = makeRelease("1.3.0", { manifestSize: short.exe.length + 1 });
  await assert.rejects(releases.check(), /manifest names/);

  github.latest.release = makeRelease("1.3.0", { manifestSize: short.exe.length - 1 });
  github.latest.assets = [
    { id: github.latest.release.ids.exe, name: "RaidDesigner-1.3.0-win-x64.exe", size: short.exe.length - 1 },
    { id: github.latest.release.ids.manifest, name: "RaidDesigner-1.3.0.manifest.json", size: 1 },
    { id: github.latest.release.ids.signature, name: "RaidDesigner-1.3.0.manifest.json.sig", size: 1 },
  ];
  await assert.rejects(releases.check(), /longer than its manifest/, "a download longer than the manifest stops");
  assert.deepEqual(keptFiles(folder), []);
});

test("a new release is served and announced, the one before stays for running downloads and older ones go", async () => {
  const { releases, github, folder } = testReleases();
  const sha = (release) => `${createHash("sha256").update(release.exe).digest("hex")}.exe`;
  const first = makeRelease("1.3.0");
  const second = makeRelease("1.4.0");
  const third = makeRelease("1.5.0");

  github.latest.release = first;
  await releases.check();
  github.latest.release = second;
  assert.equal(await releases.check(), "1.4.0");
  assert.deepEqual(keptFiles(folder), [sha(first), sha(second), "current.json"].sort());
  github.latest.release = third;
  assert.equal(await releases.check(), "1.5.0");
  assert.deepEqual(keptFiles(folder), [sha(second), sha(third), "current.json"].sort());
  assert.equal(releases.answer("1.2.0").body.version, "1.5.0");
});

test("the same version uploaded again is taken without a new download of its exe and is no new release", async () => {
  const { releases, github } = testReleases();
  const release = makeRelease("1.3.0");
  github.latest.release = release;
  await releases.check();

  const resigned = { ...release, signature: sign("sha256", release.manifest, { key: KEY.privateKey, dsaEncoding: "der" }), ids: { exe: 901, manifest: 902, signature: 903 } };
  github.latest.release = resigned;
  assert.equal(await releases.check(), null);
  assert.equal(releases.answer("1.2.0").body.signature, resigned.signature.toString("base64"));
  assert.ok(github.calls.every((call) => !call.url.endsWith("/assets/901")), "the exe is kept already");
});

test("no release, a release still missing a file, a tag that is no version and a GitHub failure serve nothing new", async () => {
  const { releases, github } = testReleases();
  assert.equal(await releases.check(), null, "no release yet");

  const release = makeRelease("1.3.0");
  github.latest.release = release;
  github.latest.assets = [{ id: release.ids.exe, name: "RaidDesigner-1.3.0-win-x64.exe", size: release.exe.length }];
  await assert.rejects(releases.check(), /lacks RaidDesigner-1.3.0.manifest.json, RaidDesigner-1.3.0.manifest.json.sig/);

  github.latest.assets = undefined;
  github.latest.release = { ...release, version: "latest" };
  await assert.rejects(releases.check(), /names no version/);

  github.latest.release = release;
  github.latest.status = 500;
  await assert.rejects(releases.check(), /GitHub answered 500/);
  assert.equal(releases.answer("1.2.0").status, 404);

  const wrongToken = new DesignerReleases({ repo: REPO, token: "other", publicKey: PUBLIC_PEM, dataDir: freshFolder() }, { fetcher: github.fetcher, api: "https://api.github.test", log: { info: () => {}, error: () => {} } });
  github.latest.status = 200;
  await assert.rejects(wrongToken.check(), /GitHub answered 401/);
});

test("two checks at once share one", async () => {
  const { releases, github } = testReleases();
  github.latest.release = makeRelease("1.3.0");
  const [left, right] = await Promise.all([releases.check(), releases.check()]);
  assert.deepEqual([left, right], ["1.3.0", "1.3.0"]);
  assert.equal(github.calls.filter((call) => call.url.endsWith("/releases/latest")).length, 1);
});

test("the token's expiry is warned of once a day from thirty days before", async () => {
  const day = 24 * 60 * 60 * 1000;
  const expires = Date.parse("2027-10-01");
  const time = { now: expires - 31 * day };
  const { releases, lines } = testReleases({ clock: () => time.now, tokenExpires: expires });

  await releases.check();
  assert.equal(lines.length, 0);
  time.now += day;
  await releases.check();
  await releases.check();
  assert.deepEqual(lines, ["the designer release token DESIGNER_GITHUB_TOKEN expires on 2027-10-01; designer updates stop once it has"]);
  time.now += day;
  await releases.check();
  assert.equal(lines.length, 2);
});

test("the settings come from the environment and leave the releases off while incomplete", () => {
  const env = { DESIGNER_GITHUB_TOKEN: " token ", DESIGNER_RELEASE_PUBKEY: PUBLIC_PEM.replaceAll("\n", "\\n"), DESIGN_DATA_DIR: "/var/lib/mgq-designs" };
  assert.deepEqual(designerReleaseSettingsOf(env), { repo: DESIGNER_REPO, token: "token", publicKey: PUBLIC_PEM.trim(), dataDir: "/var/lib/mgq-designs", tokenExpires: null });
  assert.deepEqual(designerReleaseSettingsOf({ ...env, DESIGNER_REPO: "someone/else", DESIGNER_GITHUB_TOKEN_EXPIRES: "2027-10-01" }).repo, "someone/else");
  assert.equal(designerReleaseSettingsOf({ ...env, DESIGNER_GITHUB_TOKEN_EXPIRES: "2027-10-01" }).tokenExpires, Date.parse("2027-10-01"));
  assert.doesNotThrow(() => createPublicKey(designerReleaseSettingsOf(env).publicKey));

  for (const missing of ["DESIGNER_GITHUB_TOKEN", "DESIGNER_RELEASE_PUBKEY", "DESIGN_DATA_DIR"]) {
    assert.equal(designerReleaseSettingsOf({ ...env, [missing]: "" }), null, missing);
  }

  assert.throws(() => new DesignerReleases({ repo: REPO, token: TOKEN, publicKey: "no key", dataDir: freshFolder() }));
  assert.equal(DESIGNER_RELEASE_LIMITS.checkEveryMs, 10 * 60 * 1000);
});

test("a Range header asks for one byte range; anything else for the whole file, a range past the end for none", () => {
  const cases = [
    [undefined, { start: 0, end: 99, partial: false }],
    ["", { start: 0, end: 99, partial: false }],
    ["bytes=0-9", { start: 0, end: 9, partial: true }],
    ["bytes=90-", { start: 90, end: 99, partial: true }],
    ["bytes=90-500", { start: 90, end: 99, partial: true }],
    ["bytes=-10", { start: 90, end: 99, partial: true }],
    ["bytes=-500", { start: 0, end: 99, partial: true }],
    ["bytes=100-", null],
    ["bytes=-0", null],
    ["bytes=9-0", { start: 0, end: 99, partial: false }],
    ["bytes=0-1,5-6", { start: 0, end: 99, partial: false }],
    ["items=0-1", { start: 0, end: 99, partial: false }],
    ["bytes=-", { start: 0, end: 99, partial: false }],
  ];

  for (const [header, expected] of cases) {
    assert.deepEqual(byteRangeOf(header, 100), expected, String(header));
  }
});
