//----------------------------------------------------------------
//  releases.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Tested the current release cleared by a newer release only
//                            - Tested the release control the relay's admins set
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { RELEASE_REPO, ReleaseControl, ReleaseWatch, compareVersions, handleReleaseRequest, readLatestVersion, updateLine } from "./releases.js";

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
 * Keeps the newest release seen and the release control in memory.
 *
 * @returns {{getRelease: () => Promise<string | undefined>, putRelease: (version: string) => Promise<void>, getControl: () => Promise<object | undefined>, putControl: (record: object) => Promise<void>, seen: {version?: string, control?: object}}} The store and what it holds.
 */
function memoryRelease() {
  const seen = {};
  return {
    getRelease: async () => seen.version,
    putRelease: async (version) => {
      seen.version = version;
    },
    getControl: async () => seen.control,
    putControl: async (record) => {
      seen.control = record;
    },
    seen,
  };
}

/**
 * The player id of the admin who sets the release control in the tests.
 */
const ADMIN_ID = "ad".repeat(16);

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

test("the release control serves the MIN_VERSION setting and no current release until an admin sets them", async () => {
  const control = await new ReleaseControl(memoryRelease(), { envMin: "0.6.7" }).load();
  assert.deepEqual(control.view(), { current: null, min: "0.6.7", repo: RELEASE_REPO });
  assert.deepEqual(control.adminView(), { current: null, min: "0.6.7", repo: RELEASE_REPO, envMin: "0.6.7", updatedAt: null, updatedBy: null });
  assert.equal(new ReleaseControl(memoryRelease()).min, "0.6.0", "without the setting, the gate's default");
  assert.deepEqual(handleReleaseRequest(control, "GET", new URL("https://relay.test/v1/release")), { status: 200, body: control.view() });
  assert.equal(handleReleaseRequest(control, "POST", new URL("https://relay.test/v1/release")).status, 404);
});

test("an admin sets the current and the lowest release, keeps what is left out and clears either back with null", async () => {
  const store = memoryRelease();
  const control = await new ReleaseControl(store, { envMin: "0.6.7", clock: () => 5000 }).load();

  const set = await control.set({ current: "0.6.8", min: "0.6.7.7" }, ADMIN_ID);
  assert.deepEqual([set.status, set.body], [200, { current: "0.6.8", min: "0.6.7.7", repo: RELEASE_REPO, envMin: "0.6.7", updatedAt: 5000, updatedBy: ADMIN_ID }]);
  assert.deepEqual(set.before, { current: null, min: null });
  assert.equal(control.min, "0.6.7.7", "the gate reads it at once");

  assert.deepEqual((await control.set({ current: "0.6.7.7" }, ADMIN_ID)).body.min, "0.6.7.7", "a rollback keeps the lowest release");
  assert.deepEqual((await control.set({ min: null }, ADMIN_ID)).body.min, "0.6.7");
  assert.equal((await control.set({ current: null }, ADMIN_ID)).body.current, null);

  await control.set({ current: "0.6.8", min: "0.6.8" }, ADMIN_ID);
  const reloaded = await new ReleaseControl(store, { envMin: "0.6.7" }).load();
  assert.deepEqual([reloaded.view().current, reloaded.min], ["0.6.8", "0.6.8"], "what was set outlasts a restart");
});

test("the release control refuses a lowest release above the current one and anything that is no version", async () => {
  const control = await new ReleaseControl(memoryRelease(), { envMin: "0.6.7" }).load();
  await control.set({ current: "0.6.8" }, ADMIN_ID);

  assert.deepEqual(await control.set({ min: "0.6.8.1" }, ADMIN_ID), { status: 400, body: { error: "the lowest release may not be above the current one", code: "min_above_current" } });
  assert.equal((await control.set({ current: "0.6.6" }, ADMIN_ID)).body.code, "min_above_current", "the MIN_VERSION setting counts while no lowest release is set");
  assert.equal((await control.set({ current: null, min: "0.7" }, ADMIN_ID)).status, 200, "without a current release any lowest goes");

  for (const changes of [{}, null, { current: "0.6.8-beta" }, { min: "1.2.3.4.5" }, { current: 68 }, { min: "" }]) {
    assert.equal((await control.set(changes, ADMIN_ID)).status, 400, JSON.stringify(changes));
  }

  assert.deepEqual(control.view(), { current: null, min: "0.7", repo: RELEASE_REPO }, "a refused change changes nothing");
});

test("a release published after the current one was set clears it, while the latest seen when it was set keeps a rollback", async () => {
  const store = memoryRelease();
  await store.putRelease("0.6.8");
  const control = await new ReleaseControl(store, { envMin: "0.6.7", clock: () => 7000 }).load();
  await control.set({ current: "0.6.7.7", min: "0.6.7.7" }, ADMIN_ID);

  assert.equal(await control.seen("0.6.8"), null, "the latest seen when it was set");
  assert.equal(control.view().current, "0.6.7.7");

  assert.equal(await control.seen("0.6.9"), "0.6.7.7");
  assert.deepEqual(control.adminView(), { current: null, min: "0.6.7.7", repo: RELEASE_REPO, envMin: "0.6.7", updatedAt: 7000, updatedBy: "relay" }, "the lowest release stays");
  assert.equal((await new ReleaseControl(store).load()).view().current, null, "kept cleared");
});

test("a current release set ahead of the latest stays once it is published, and one set before any release was read waits for the next", async () => {
  const store = memoryRelease();
  const control = await new ReleaseControl(store, { envMin: "0.6.7" }).load();
  await control.set({ current: "0.6.7.7" }, ADMIN_ID);
  assert.equal(await control.seen("0.6.8"), null, "an older latest the watch reads first");
  assert.equal(await control.seen("0.6.9"), "0.6.7.7");

  await control.set({ current: "0.7.0" }, ADMIN_ID);
  assert.equal(await control.seen("0.7.0"), null, "its own release");
  assert.equal(await control.seen("0.7.1"), "0.7.0");
});
