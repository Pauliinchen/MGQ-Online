//----------------------------------------------------------------
//  releases.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

// Watching the mod's own releases: once GitHub names a newer release than the last one seen, the
// relay says so in the chat of every world with players online, under UPDATE_NAME, which games
// from 0.6.5 on draw as a red notice and older ones as an admin's line.

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
 * Where the watch keeps the newest release it has seen.
 *
 * @typedef {object} ReleaseStore
 * @property {() => Promise<string | undefined>} getRelease Reads the newest version seen.
 * @property {(version: string) => Promise<void>} putRelease Keeps the newest version seen.
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
