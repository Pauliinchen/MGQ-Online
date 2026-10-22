//----------------------------------------------------------------
//  releases.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Kept the release games should run and the lowest one the relay serves, which its admins set
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

// Watching the mod's own releases: once GitHub names a newer release than the last one seen, the
// relay says so in the chat of every world with players online, under UPDATE_NAME, which current
// games show as a notice and older ones as an admin's line. Beside it the release control: which
// release games should run and the lowest one the relay serves, both set by its admins.

import { minVersionOf } from "./gate.js";
import { badRequest, notFound } from "./http.js";
import { VERSION } from "./relay.js";

/**
 * The repository whose releases the relay watches, unless RELEASE_REPO names another.
 */
export const RELEASE_REPO = "Pauliinchen/MGQ-Online";

/**
 * The name the update notice carries in a world's chat, which games read as the relay's notice.
 */
export const UPDATE_NAME = "MGQ Online";

/**
 * Where GitHub's answer to the latest release leads: the release's tag page.
 */
const TAG_PAGE = /\/releases\/tag\/v?(\d+(?:\.\d+)*)$/;

/**
 * The route's name after the version, public and open to every game.
 */
export const RELEASE_ROUTE = "release";

/**
 * A version an admin sets: one to four whole numbers separated by dots.
 */
const SET_VERSION = /^\d{1,9}(?:\.\d{1,9}){0,3}$/;

/**
 * The codes a refusal of the release control names why with.
 */
export const RELEASE_REFUSAL = Object.freeze({ minAboveCurrent: "min_above_current" });

/**
 * Where the watch keeps the newest release it has seen, and the release control what its admins set.
 *
 * @typedef {object} ReleaseStore
 * @property {() => Promise<string | undefined>} getRelease Reads the newest version seen.
 * @property {(version: string) => Promise<void>} putRelease Keeps the newest version seen.
 * @property {() => Promise<object | undefined>} getControl Reads the release control's record, undefined before an admin first set it.
 * @property {(record: object) => Promise<void>} putControl Keeps the release control's record.
 */

/**
 * Reads the version of a repository's latest release from where GitHub's latest release page
 * leads, which needs no API and so no API rate limit.
 *
 * @param {string} repo The repository, like owner/name.
 * @param {typeof fetch} fetcher Fetches an address.
 * @returns {Promise<string>} The version, like 0.6.5, without the tag's v.
 */
export async function readLatestVersion(repo, fetcher) {
  const answer = await fetcher(`https://github.com/${repo}/releases/latest`, { redirect: "manual" });
  const location = answer.headers.get("Location") ?? "";
  const match = TAG_PAGE.exec(new URL(location, "https://github.com").pathname);

  if (answer.status < 300 || answer.status >= 400 || !match) {
    throw new Error(`the latest release answered ${answer.status} instead of leading to a release's tag`);
  }

  return match[1];
}

/**
 * Compares two versions part by part, a missing part counting as 0.
 *
 * @param {string} a A version, like 0.6.5.
 * @param {string} b Another version.
 * @returns {number} Below 0 when a is older, 0 when they are the same, above 0 when a is newer.
 */
export function compareVersions(a, b) {
  const left = a.split(".").map(Number);
  const right = b.split(".").map(Number);

  for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
    const difference = (left[index] ?? 0) - (right[index] ?? 0);

    if (difference !== 0) {
      return difference;
    }
  }

  return 0;
}

/**
 * Writes the update notice the worlds' chats are told.
 *
 * @param {string} version The new release's version.
 * @returns {string} The notice.
 */
export function updateLine(version) {
  return `MGQ Online ${version} is out. Restart the game and pick Multiplayer to update.`;
}

/**
 * Notices a newer release of the mod than the last one seen.
 */
export class ReleaseWatch {
  /**
   * Creates the watch.
   *
   * @param {ReleaseStore} store Where it keeps the newest version seen.
   * @param {{fetch?: typeof fetch, repo?: string}} [options] How it reads GitHub and which repository it watches.
   */
  constructor(store, { fetch: fetcher = (...args) => fetch(...args), repo = RELEASE_REPO } = {}) {
    this.store = store;
    this.fetch = fetcher;
    this.repo = repo;
  }

  /**
   * Reads the latest release and keeps it when it is newer than the last one seen.
   *
   * The first release ever read is only kept, so a fresh relay announces nothing old.
   *
   * @returns {Promise<string | null>} The new release's version to announce, null when there is none.
   */
  async check() {
    const latest = await readLatestVersion(this.repo, this.fetch);
    const seen = await this.store.getRelease();

    if (seen && compareVersions(latest, seen) <= 0) {
      return null;
    }

    await this.store.putRelease(latest);
    return seen ? latest : null;
  }
}

/**
 * Which release games should run and the lowest one the relay serves, as its admins set them. The
 * gate reads the lowest from here, so a change takes effect at once.
 */
export class ReleaseControl {
  /**
   * Creates the release control, empty until load reads what was kept.
   *
   * @param {ReleaseStore} store Where it keeps what the admins set.
   * @param {{envMin?: string, clock?: () => number, repo?: string}} [options] The relay's MIN_VERSION setting, the lowest release while no admin set one; the clock; and the repository games update from.
   */
  constructor(store, { envMin, clock = Date.now, repo = RELEASE_REPO } = {}) {
    this.store = store;
    this.envMin = minVersionOf(envMin).join(".");
    this.clock = clock;
    this.repo = repo;
    this.kept = { current: null, min: null, updatedAt: null, updatedBy: null };
    this.writing = Promise.resolve();
  }

  /**
   * Reads what the admins set before, once, before the relay serves its first request.
   *
   * @returns {Promise<ReleaseControl>} The release control.
   */
  async load() {
    this.kept = { ...this.kept, ...(await this.store.getControl()) };
    return this;
  }

  /**
   * The lowest version the relay serves: the one an admin set, else the MIN_VERSION setting.
   *
   * @returns {string} The version.
   */
  get min() {
    return this.kept.min ?? this.envMin;
  }

  /**
   * What every game may read.
   *
   * @returns {{current: string | null, min: string, repo: string}} The release games should run, null while unset; the lowest the relay serves; the repository games update from.
   */
  view() {
    return { current: this.kept.current, min: this.min, repo: this.repo };
  }

  /**
   * What the admins see.
   *
   * @returns {{current: string | null, min: string, repo: string, envMin: string, updatedAt: number | null, updatedBy: string | null}} The view, the MIN_VERSION setting, and when and by which admin's player id it was last set.
   */
  adminView() {
    return { ...this.view(), envMin: this.envMin, updatedAt: this.kept.updatedAt, updatedBy: this.kept.updatedBy };
  }

  /**
   * Sets the release games should run, the lowest one the relay serves, or both, one change at a
   * time.
   *
   * @param {any} changes `current` and `min`, each a version or null to clear it; one left out stays.
   * @param {string} admin The player id of the admin who sets them.
   * @returns {Promise<{status: number, body: object, before?: {current: string | null, min: string | null}}>} The admin view, with what was kept before; or why not.
   */
  set(changes, admin) {
    const done = this.writing.then(() => this.apply(changes, admin));
    this.writing = done.catch(() => {});
    return done;
  }

  /**
   * Checks and keeps a change, see set.
   *
   * @param {any} changes The change.
   * @param {string} admin The admin's player id.
   * @returns {Promise<{status: number, body: object, before?: {current: string | null, min: string | null}}>} The answer.
   */
  async apply(changes, admin) {
    const { current, min } = changes && typeof changes === "object" ? changes : {};

    if (current === undefined && min === undefined) {
      return badRequest("name current or min");
    }

    if (![current, min].every((version) => version === undefined || version === null || (typeof version === "string" && SET_VERSION.test(version)))) {
      return badRequest("a version must be 1 to 4 whole numbers separated by dots, or null");
    }

    const before = { current: this.kept.current, min: this.kept.min };
    const next = { current: current === undefined ? before.current : current, min: min === undefined ? before.min : min };

    if (next.current !== null && compareVersions(next.min ?? this.envMin, next.current) > 0) {
      return { status: 400, body: { error: "the lowest release may not be above the current one", code: RELEASE_REFUSAL.minAboveCurrent } };
    }

    const record = { ...next, updatedAt: this.clock(), updatedBy: admin };
    await this.store.putControl(record);
    this.kept = record;
    return { status: 200, body: this.adminView(), before };
  }
}

/**
 * Answers a request to the public release route, which every game may read whatever its version.
 *
 * @param {ReleaseControl} control The release control.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @returns {{status: number, body: object}} The answer.
 */
export function handleReleaseRequest(control, method, url) {
  return method === "GET" && url.pathname === `/${VERSION}/${RELEASE_ROUTE}` ? { status: 200, body: control.view() } : notFound("route");
}
