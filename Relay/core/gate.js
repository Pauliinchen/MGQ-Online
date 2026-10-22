//----------------------------------------------------------------
//  gate.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Let a relay admin set the design formats
//      Paulinchen  2026-10-21: Added the designer gate of the Raid design routes and held the game's design routes to X-MGQ-Features
//      Paulinchen  2026-10-12: Held the world directory's and the mod catalog's routes to X-MGQ-Features
//                            - Named the update code on the 400 of a world room refused to a game too old
//                            - Refused a world room of a game too old with 400 and counted a request without X-MGQ-Version as 0.6.4
//                            - Held the world directory's and the mod catalog's routes to the lowest version
//                            - Passed only the 0.0.0-dev stamp as a development build
//                            - Created
//
//----------------------------------------------------------------

// Which games the relay still serves: every game from 0.6.0 names its features in X-MGQ-Features,
// and newer ones name their version in X-MGQ-Version, which the relay holds against a lowest
// version. Both platform layers ask the gate before they route a request.

import { bossRouteOf } from "./bosses.js";
import { routeIs } from "./http.js";
import { MOD_LIMITS } from "./mods.js";
import { REPORT_LIMITS } from "./reports.js";
import { storyRouteOf } from "./story.js";

/**
 * The request header in which a game names its version, such as `0.6.5`, or DEVELOPMENT_VERSION
 * for a development build and the World Admin tool; released games up to 0.6.4 send none.
 */
export const VERSION_HEADER = "X-MGQ-Version";

/**
 * The version a request counts as when it names none, the last release that names none.
 */
export const UNNAMED_VERSION = "0.6.4";

/**
 * The stamp of a development build and the World Admin tool, which passes on every relay.
 */
export const DEVELOPMENT_VERSION = "0.0.0-dev";

/**
 * The lowest version the relay serves unless its MIN_VERSION setting names another.
 */
export const DEFAULT_MIN_VERSION = "0.6.0";

/**
 * The HTTP status of a game too old for the relay, on every route but the world rooms.
 */
export const UPDATE_STATUS = 426;

/**
 * The HTTP status of a game too old for a world room, sent with WORLD_ROOM_UPDATE_CODE.
 *
 * Released games from 0.5.1 to 0.6.4 stop at a 400 and show their own "The relay turned the request
 * down. Update the mod.", while they would try a 426 again and again.
 */
export const WORLD_ROOM_UPDATE_STATUS = 400;

/**
 * The code in REFUSAL_HEADER that names a world room's WORLD_ROOM_UPDATE_STATUS a refusal of a game
 * too old for the relay.
 *
 * Released games from 0.5.1 to 0.6.4 read a 400 with a code they do not know as their generic refusal.
 */
export const WORLD_ROOM_UPDATE_CODE = "update";

/**
 * What the relay tells a game too old for it, in the body and, for a PvP room, in REFUSAL_HEADER.
 */
export const UPDATE_NEEDED = "Update MGQ Online to play online.";

/**
 * What a route asks of a game: `features` the X-MGQ-Features header, which every game from 0.6.0
 * sends, and a version new enough; `version` only a version new enough; `designer` what the
 * designer gate asks, which the design routes check themselves, see designerRefusal.
 */
export const GATE = Object.freeze({ features: "features", version: "version", designer: "designer" });

/**
 * The route's name after the version of the routes the Raid Designer uses.
 */
export const DESIGN_ROUTE = "designs";

/**
 * The route's name after the version of the routes games and the battle server read published
 * Raid designs from.
 */
export const GAME_DESIGN_ROUTE = "raid-design";

/**
 * The request header in which the Raid Designer names its designer key, 32 lowercase hexadecimal
 * characters.
 */
export const DESIGNER_HEADER = "X-MGQ-Designer";

/**
 * The request header in which the Raid Designer names its version, such as `1.3.0`, or
 * DEVELOPMENT_VERSION for a development build.
 */
export const DESIGNER_VERSION_HEADER = "X-MGQ-Designer-Version";

/**
 * The request header in which the Raid Designer names the design format it writes, an integer.
 */
export const DESIGN_FORMAT_HEADER = "X-MGQ-Design-Format";

/**
 * The lowest designer version the relay serves unless its DESIGNER_MIN_VERSION setting names
 * another: every version.
 */
export const DEFAULT_DESIGNER_MIN_VERSION = "0.0.0";

/**
 * What each kind of design route asks of a designer: `listed` a designer the relay lists,
 * `current` a version and design format new enough, `write` the development rule, `admin` a
 * designer admin, and `relayAdmin` whether a relay admin's player key passes too.
 */
export const DESIGNER_RULE = Object.freeze({
  open: Object.freeze({ listed: false, current: false, write: false, admin: false, relayAdmin: false }),
  listed: Object.freeze({ listed: true, current: false, write: false, admin: false, relayAdmin: false }),
  read: Object.freeze({ listed: true, current: true, write: false, admin: false, relayAdmin: false }),
  write: Object.freeze({ listed: true, current: true, write: true, admin: false, relayAdmin: false }),
  adminWrite: Object.freeze({ listed: true, current: true, write: true, admin: true, relayAdmin: false }),
  roster: Object.freeze({ listed: true, current: true, write: false, admin: false, relayAdmin: true }),
  manage: Object.freeze({ listed: true, current: true, write: false, admin: true, relayAdmin: true }),
  adminSetting: Object.freeze({ listed: true, current: true, write: true, admin: true, relayAdmin: true }),
});

/**
 * The design routes beside `POST builds` that change what players get, for designer admins only.
 */
const ADMIN_WRITES = new Set(["publish", "rollback"]);

/**
 * How much of a refused request's body is read and dropped before the refusal is answered, as much
 * as the largest body a gated route takes, an uploaded mod's or a bug report's, and for as long as a
 * bug report may take.
 */
export const DRAIN_LIMITS = Object.freeze({ maxBytes: Math.max(REPORT_LIMITS.maxBodyBytes, MOD_LIMITS.maxUploadBytes), readMs: REPORT_LIMITS.bodyReadMs });

/**
 * A version: numbers separated by dots, with an optional suffix and build data.
 */
const VERSION_PATTERN = /^(\d+(?:\.\d+)*)(-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;

/**
 * Tells what a route asks of a game's version.
 *
 * @param {URL} url The request's address.
 * @returns {string | null} GATE.features for the world directory's and the mod catalog's routes, the Raid World admin, story and boss routes included, the trades, the bug reports, the world rooms and the game's design routes; GATE.version for the PvP rooms, which released games open without X-MGQ-Features; GATE.designer for the Raid Designer's routes; null for every other route.
 */
export function gateOf(url) {
  if (storyRouteOf(url) || bossRouteOf(url) || routeIs(url, "trades") || routeIs(url, "reports") || routeIs(url, "world") || routeIs(url, "worlds") || routeIs(url, "mods")
      || routeIs(url, GAME_DESIGN_ROUTE)) {
    return GATE.features;
  }

  if (routeIs(url, DESIGN_ROUTE)) {
    return GATE.designer;
  }

  return routeIs(url, "room") ? GATE.version : null;
}

/**
 * Tells what a design route asks of a designer.
 *
 * @param {string} method The HTTP method.
 * @param {string[]} rest The address's parts after `designs`.
 * @returns {typeof DESIGNER_RULE.open} The rule: `me` is open to any key to read and to a listed designer to rename; `release` needs a listed designer of any version; the designer list a designer or a relay admin, changing it a designer admin or a relay admin; builds, publish and rollback a designer admin; format a designer admin or a relay admin, who can undo a lowest format no designer reaches; push the development rule; everything else a current designer.
 */
export function designerRuleOf(method, rest) {
  const [route] = rest;

  if (route === "me") {
    return method === "GET" ? DESIGNER_RULE.open : DESIGNER_RULE.listed;
  }

  if (route === "release") {
    return DESIGNER_RULE.listed;
  }

  if (route === "designers") {
    return method === "GET" ? DESIGNER_RULE.roster : DESIGNER_RULE.manage;
  }

  if (route === "push") {
    return DESIGNER_RULE.write;
  }

  if (route === "format") {
    return DESIGNER_RULE.adminSetting;
  }

  if (ADMIN_WRITES.has(route) || (route === "builds" && method === "POST" && rest.length === 1)) {
    return DESIGNER_RULE.adminWrite;
  }

  return DESIGNER_RULE.read;
}

/**
 * Reads the design format a designer names.
 *
 * @param {string | null | undefined} header The request's DESIGN_FORMAT_HEADER.
 * @returns {number} The format, 0 when it names none or no integer.
 */
export function designFormatOf(header) {
  return typeof header === "string" && /^\s*\d{1,6}\s*$/.test(header) ? Number(header.trim()) : 0;
}

/**
 * Turns a designer away from a design route it may not use: an unlisted key with
 * `not_designer`, a version below the lowest the relay serves or a design format below the lowest
 * it takes with `update`, a designer who is no admin from an admin route with `admin_only`, and a
 * development build that writes with `dev_build`.
 *
 * Only DEVELOPMENT_VERSION passes the version check, as a game's development build passes the game
 * gate; its design format is still checked, since it reads and writes the design.
 *
 * @param {typeof DESIGNER_RULE.open} rule What the route asks, see designerRuleOf.
 * @param {{id: string | null, listed: boolean, admin: boolean}} designer The designer the key names: its id, null for a key that is none, whether the relay lists it and whether it is an admin.
 * @param {{version: string | null | undefined, format: string | null | undefined}} client The request's DESIGNER_VERSION_HEADER and DESIGN_FORMAT_HEADER.
 * @param {{minVersion: string, minFormat: number, allowDev: boolean}} settings The lowest designer version and design format the relay serves, and whether a development build writes as any designer.
 * @returns {{status: number, body: object} | null} The refusal, or null when the designer may go on.
 */
export function designerRefusal(rule, designer, client, settings) {
  if (rule.listed && !designer.listed) {
    return { status: 403, body: designer.id ? { code: "not_designer", id: designer.id } : { code: "not_designer" } };
  }

  const version = parseVersion(client.version);
  const minimum = parseVersion(settings.minVersion)?.parts ?? [];
  const outdated = version === null || (!version.development && compareVersions(version.parts, minimum) < 0) || designFormatOf(client.format) < settings.minFormat;

  if (rule.current && outdated) {
    return { status: UPDATE_STATUS, body: { code: "update", minimum: settings.minVersion, minFormat: settings.minFormat } };
  }

  if (rule.admin && !designer.admin) {
    return { status: 403, body: { code: "admin_only" } };
  }

  if (rule.write && version?.development && !designer.admin && !settings.allowDev) {
    return { status: 403, body: { code: "dev_build" } };
  }

  return null;
}

/**
 * Reads a version a game names.
 *
 * @param {string | null | undefined} text The version, such as `0.6.5+<commit>`.
 * @returns {{parts: number[], development: boolean} | null} Its numbers and whether it is DEVELOPMENT_VERSION, with or without build data; null when it is no version.
 */
export function parseVersion(text) {
  const match = typeof text === "string" ? VERSION_PATTERN.exec(text.trim()) : null;
  return match ? { parts: match[1].split(".").map(Number), development: `${match[1]}${match[2] ?? ""}` === DEVELOPMENT_VERSION } : null;
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
 * @returns {number[]} The version's numbers; DEFAULT_MIN_VERSION's when the setting is unset, no version or DEVELOPMENT_VERSION.
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
 * GATE.features asks for, or names a version that is none or older than the lowest the relay serves,
 * a game naming none counting as UNNAMED_VERSION.
 *
 * Only DEVELOPMENT_VERSION always passes, so a development build reaches every relay while a
 * pre-release such as `0.7.0-beta` is held to its numbers. GATE.designer passes here, since the
 * design routes hold a designer to designerRefusal.
 *
 * @param {string | null} gate What the route asks, see gateOf.
 * @param {string | null | undefined} featuresHeader The request's FEATURES_HEADER.
 * @param {string | null | undefined} versionHeader The request's VERSION_HEADER.
 * @param {string | null | undefined} [minVersion] The relay's MIN_VERSION setting.
 * @returns {boolean} Whether it is.
 */
export function tooOld(gate, featuresHeader, versionHeader, minVersion) {
  if (gate === null || gate === GATE.designer) {
    return false;
  }

  if (gate === GATE.features && !sent(featuresHeader)) {
    return true;
  }

  const version = parseVersion(sent(versionHeader) ? versionHeader : UNNAMED_VERSION);
  return version === null || (!version.development && compareVersions(version.parts, minVersionOf(minVersion)) < 0);
}

/**
 * Turns a game too old for the relay away before its request is routed.
 *
 * @param {URL} url The request's address.
 * @param {string | null | undefined} featuresHeader The request's FEATURES_HEADER.
 * @param {string | null | undefined} versionHeader The request's VERSION_HEADER.
 * @param {string | null | undefined} [minVersion] The relay's MIN_VERSION setting.
 * @returns {{status: number, reason: string, socket: boolean, code: string | null} | null} The refusal, with whether the route is a PvP room's or a world room's, answered as a refused WebSocket, and the code to name in REFUSAL_HEADER, which only a PvP room's and a world room's carry; null when the game may go on.
 */
export function updateRefusal(url, featuresHeader, versionHeader, minVersion) {
  if (!tooOld(gateOf(url), featuresHeader, versionHeader, minVersion)) {
    return null;
  }

  if (routeIs(url, "world")) {
    return { status: WORLD_ROOM_UPDATE_STATUS, reason: UPDATE_NEEDED, socket: true, code: WORLD_ROOM_UPDATE_CODE };
  }

  const room = routeIs(url, "room");
  return { status: UPDATE_STATUS, reason: UPDATE_NEEDED, socket: room, code: room ? UPDATE_NEEDED : null };
}
