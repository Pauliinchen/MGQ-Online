//----------------------------------------------------------------
//  gate.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

// Which games the relay still serves: every game from 0.6.0 names its features in X-MGQ-Features,
// and newer ones name their version in X-MGQ-Version, which the relay holds against a lowest
// version. Both platform layers ask the gate before they route a request.

import { bossRouteOf } from "./bosses.js";
import { routeIs } from "./http.js";
import { REPORT_LIMITS } from "./reports.js";
import { storyRouteOf } from "./story.js";

/**
 * The request header in which a game names its version, such as `0.6.5+<commit>`, or `0.0.0-dev`
 * for a development build; released games up to 0.6.4 send none.
 */
export const VERSION_HEADER = "X-MGQ-Version";

/**
 * The lowest version the relay serves unless its MIN_VERSION setting names another.
 */
export const DEFAULT_MIN_VERSION = "0.6.0";

/**
 * The HTTP status of a game too old for the relay.
 */
export const UPDATE_STATUS = 426;

/**
 * What the relay tells a game too old for it, in the body and, for a WebSocket, in REFUSAL_HEADER.
 */
export const UPDATE_NEEDED = "Update MGQ Online to play online.";

/**
 * What a route asks of a game: `features` the X-MGQ-Features header, which every game from 0.6.0
 * sends, and `version` only a version new enough when the game names one.
 */
export const GATE = Object.freeze({ features: "features", version: "version" });

/**
 * How much of a refused request's body is read and dropped before the refusal is answered, as much
 * as the largest body a gated route takes, a bug report's, and for as long as one may take.
 */
export const DRAIN_LIMITS = Object.freeze({ maxBytes: REPORT_LIMITS.maxBodyBytes, readMs: REPORT_LIMITS.bodyReadMs });

/**
 * A release version: numbers separated by dots, with an optional suffix and build data.
 */
const VERSION_PATTERN = /^(\d+(?:\.\d+)*)(-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;

/**
 * Tells what a route asks of a game's version.
 *
 * The world directory's and the mod catalog's routes ask nothing, since the World Admin tool uses
 * them without X-MGQ-Features.
 *
 * @param {URL} url The request's address.
 * @returns {string | null} GATE.features for the routes only games use and the world rooms, GATE.version for the PvP rooms, which released games open without X-MGQ-Features, and null for every other route.
 */
export function gateOf(url) {
  if (storyRouteOf(url) || bossRouteOf(url) || routeIs(url, "trades") || routeIs(url, "reports") || routeIs(url, "world")) {
    return GATE.features;
  }

  return routeIs(url, "room") ? GATE.version : null;
}

/**
 * Reads a version a game names.
 *
 * @param {string | null | undefined} text The version, such as `0.6.5+<commit>`.
 * @returns {{parts: number[], development: boolean} | null} Its numbers and whether it carries a suffix such as `-dev`, which no release has; null when it is no version.
 */
export function parseVersion(text) {
  const match = typeof text === "string" ? VERSION_PATTERN.exec(text.trim()) : null;
  return match ? { parts: match[1].split(".").map(Number), development: match[2] !== undefined } : null;
}

/**
 * Compares two versions by their numbers, a missing number counting as 0.
 *
 * @param {number[]} left The first version's numbers.
 * @param {number[]} right The second version's numbers.
 * @returns {number} Below 0 when the first is older, 0 when both are the same, above 0 when the first is newer.
 */
export function compareVersions(left, right) {
  for (let index = 0; index < Math.max(left.length, right.length); index++) {
    const difference = (left[index] ?? 0) - (right[index] ?? 0);

    if (difference !== 0) {
      return difference;
    }
  }

  return 0;
}

/**
 * Reads the lowest version the relay serves from its MIN_VERSION setting.
 *
 * @param {string | null | undefined} setting The setting, unset for DEFAULT_MIN_VERSION.
 * @returns {number[]} The version's numbers; DEFAULT_MIN_VERSION's when the setting is unset or no release version.
 */
export function minVersionOf(setting) {
  const version = parseVersion(setting);
  return version && !version.development ? version.parts : parseVersion(DEFAULT_MIN_VERSION).parts;
}

/**
 * Tells whether a header was sent with a value.
 *
 * @param {string | null | undefined} header The header.
 * @returns {boolean} Whether it was.
 */
function sent(header) {
  return typeof header === "string" && header.trim().length > 0;
}

/**
 * Tells whether a game is too old for a route: it lacks the X-MGQ-Features header a route of
 * GATE.features asks for, or names a version that is none or older than the lowest the relay serves.
 *
 * A development version always passes, so a development build reaches every relay.
 *
 * @param {string | null} gate What the route asks, see gateOf.
 * @param {string | null | undefined} featuresHeader The request's FEATURES_HEADER.
 * @param {string | null | undefined} versionHeader The request's VERSION_HEADER.
 * @param {string | null | undefined} [minVersion] The relay's MIN_VERSION setting.
 * @returns {boolean} Whether it is.
 */
export function tooOld(gate, featuresHeader, versionHeader, minVersion) {
  if (gate === null) {
    return false;
  }

  if (gate === GATE.features && !sent(featuresHeader)) {
    return true;
  }

  if (!sent(versionHeader)) {
    return false;
  }

  const version = parseVersion(versionHeader);
  return version === null || (!version.development && compareVersions(version.parts, minVersionOf(minVersion)) < 0);
}

/**
 * Turns a game too old for the relay away before its request is routed.
 *
 * @param {URL} url The request's address.
 * @param {string | null | undefined} featuresHeader The request's FEATURES_HEADER.
 * @param {string | null | undefined} versionHeader The request's VERSION_HEADER.
 * @param {string | null | undefined} [minVersion] The relay's MIN_VERSION setting.
 * @returns {{status: number, reason: string, socket: boolean} | null} The refusal, with whether the route is a room's or a world room's, whose WebSocket refusal names its reason in REFUSAL_HEADER; null when the game may go on.
 */
export function updateRefusal(url, featuresHeader, versionHeader, minVersion) {
  if (!tooOld(gateOf(url), featuresHeader, versionHeader, minVersion)) {
    return null;
  }

  return { status: UPDATE_STATUS, reason: UPDATE_NEEDED, socket: routeIs(url, "room") || routeIs(url, "world") };
}
