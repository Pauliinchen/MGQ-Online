//----------------------------------------------------------------
//  releases.test.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { RELEASE_REPO, ReleaseWatch, compareVersions, readLatestVersion, updateLine } from "./releases.js";

/**
 * Stands in for GitHub's latest release page, which leads to the tag of the release it names.
 *
 * @param {{tag: string | null, status?: number}} release The tag the page leads to, null for no lead, and the page's status.
 * @returns {{fetch: typeof fetch, asked: string[]}} The stand-in and the addresses it was asked for.
 */
function latestPage(release) {
  const asked = [];
  const fetcher = async (url, options) => {
    asked.push(url);
    assert.equal(options.redirect, "manual");
    const headers = new Headers(release.tag ? { Location: `https://github.com/${RELEASE_REPO}/releases/tag/${release.tag}` } : {});
    return new Response(null, { status: release.status ?? 302, headers });
  };

  return { fetch: fetcher, asked };
}

/**
 * Keeps the newest release seen in memory.
 *
 * @returns {{getRelease: () => Promise<string | undefined>, putRelease: (version: string) => Promise<void>, seen: {version?: string}}} The store and what it holds.
 */
function memoryRelease() {
  const seen = {};
  return {
    getRelease: async () => seen.version,
    putRelease: async (version) => {
      seen.version = version;
    },
    seen,
  };
}

test("readLatestVersion reads the version from where the latest release leads, without its v", async () => {
  const page = latestPage({ tag: "v0.6.5" });
  assert.equal(await readLatestVersion(RELEASE_REPO, page.fetch), "0.6.5");
  assert.deepEqual(page.asked, [`https://github.com/${RELEASE_REPO}/releases/latest`]);
  assert.equal(await readLatestVersion(RELEASE_REPO, latestPage({ tag: "1.2" }).fetch), "1.2");
});

test("readLatestVersion fails when the page leads to no release's tag", async () => {
  await assert.rejects(readLatestVersion(RELEASE_REPO, latestPage({ tag: null, status: 404 }).fetch), /answered 404/);
  await assert.rejects(readLatestVersion(RELEASE_REPO, latestPage({ tag: "latest-build" }).fetch), /instead of leading to a release's tag/);
  await assert.rejects(readLatestVersion(RELEASE_REPO, latestPage({ tag: "v0.6.5", status: 200 }).fetch), /answered 200/);
});

test("compareVersions compares part by part, a missing part counting as 0", () => {
  assert.ok(compareVersions("0.6.10", "0.6.9") > 0);
  assert.ok(compareVersions("0.6.4", "0.6.5") < 0);
  assert.equal(compareVersions("0.6", "0.6.0"), 0);
  assert.ok(compareVersions("0.6.3.1", "0.6.3") > 0);
});

test("updateLine names the release and how to update", () => {
  assert.equal(updateLine("0.6.5"), "MGQ Online 0.6.5 is out. Restart the game and pick Multiplayer to update.");
});

test("the watch only keeps the first release it reads, then announces each newer one once", async () => {
  const store = memoryRelease();
  const release = { tag: "v0.6.4" };
  const watch = new ReleaseWatch(store, { fetch: async (...args) => latestPage(release).fetch(...args) });

  assert.equal(await watch.check(), null);
  assert.equal(store.seen.version, "0.6.4");
  assert.equal(await watch.check(), null);

  release.tag = "v0.6.5";
  assert.equal(await watch.check(), "0.6.5");
  assert.equal(await watch.check(), null);

  release.tag = "v0.6.4";
  assert.equal(await watch.check(), null, "a release taken back announces nothing");
  assert.equal(store.seen.version, "0.6.5");
});

test("the watch reads the repository it is given", async () => {
  const page = latestPage({ tag: "v1.0.0" });
  await new ReleaseWatch(memoryRelease(), { fetch: page.fetch, repo: "someone/fork" }).check();
  assert.deepEqual(page.asked, ["https://github.com/someone/fork/releases/latest"]);
});
