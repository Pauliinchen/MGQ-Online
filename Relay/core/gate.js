//----------------------------------------------------------------
//  gate.js
//
//  Changelog:
//      Paulinchen  2026-11-06: Held the PvP rooms older games ask for to X-MGQ-Features, so those games get the update refusal
//                            - Named the lowest version the relay serves in X-MGQ-Min-Version beside a refusal of a game too old for it
//                            - Refused a request that names no version and dropped the PvP room answer and the long drain before a refusal
//      Paulinchen  2026-11-05: Held the story mapping games read to the lowest version too
//                            - Listed the worlds with their mods for the website and the World Admin tool only
//                            - Answered every request to a PvP room with the update refusal
//                            - Raised the lowest version served while MIN_VERSION names none to 0.7.0
//      Paulinchen  2026-10-30: Let a GET of the mod catalog and its files pass ungated, as the Mod Framework reads them naming no game version
//      Paulinchen  2026-10-22: Let a relay admin set the design formats
//                            - Told which games hold a world's long mods and which read the world list with every world's mods
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
import { REFUSAL_HEADER, parseFeatures } from "./relay.js";
import { REPORT_LIMITS } from "./reports.js";
import { storyRouteOf } from "./story.js";
import { MAPPING_GAME_ROUTE } from "./story_mapping.js";

/**
 * The request header in which a game names its version, such as `0.6.5`, or DEVELOPMENT_VERSION
 * for a development build and the World Admin tool.
 */
export const VERSION_HEADER = "X-MGQ-Version";

/**
 * The stamp of a development build and the World Admin tool, which passes on every relay.
 */
export const DEVELOPMENT_VERSION = "0.0.0-dev";

/**
 * What the website and the World Admin tool name in X-MGQ-Features: both read the world list with
 * every world's mods.
 */
const FULL_LIST_FEATURES = Object.freeze(["web", "admin"]);

/**
 * The lowest version the relay serves unless its MIN_VERSION setting names another.
 */
export const DEFAULT_MIN_VERSION = "0.7.0";

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
 * The response header that names the lowest version the relay serves beside a refusal of a game too
 * old for it, so the game asks for that version; released games read no such header.
 */
export const MIN_VERSION_HEADER = "X-MGQ-Min-Version";

/**
 * What the relay tells a game too old for it.
 */
export const UPDATE_NEEDED = "Update MGQ Online to play online.";

/**
 * What a route asks of a game: `features` the X-MGQ-Features header, which every game from 0.6.0
 * sends, and a version new enough; `designer` what the designer gate asks, which the design routes
 * check themselves, see designerRefusal.
 */
export const GATE = Object.freeze({ features: "features", designer: "designer" });

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
 * How long a refused request's body is read and dropped before the refusal is answered, as long as
 * a bug report may take.
 */
export const DRAIN_LIMITS = Object.freeze({ readMs: REPORT_LIMITS.bodyReadMs });

/**
 * A version: numbers separated by dots, with an optional suffix and build data.
 */
const VERSION_PATTERN = /^(\d+(?:\.\d+)*)(-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;

/**
 * Tells what a route asks of a game's version.
 *
 * A GET of the mod catalog asks nothing, since the Mod Framework reads the catalog and its files for every game, naming no game version.
 *
 * @param {URL} url The request's address.
 * @param {string} [method] The request's HTTP method; none counts as a change.
 * @returns {string | null} GATE.features for the world directory's and the mod catalog's routes, the Raid World admin, story and boss routes included, the trades, the bug reports, the world rooms, the PvP rooms older games ask for, the game's design routes and the story mapping games read; GATE.designer for the Raid Designer's routes; null for every other route and a GET of the mod catalog.
 */
export function gateOf(url, method = undefined) {
  if (routeIs(url, "mods") && method === "GET") {
    return null;
  }

  if (storyRouteOf(url) || bossRouteOf(url) || routeIs(url, "trades") || routeIs(url, "reports") || routeIs(url, "world") || routeIs(url, "worlds") || routeIs(url, "mods")
      || routeIs(url, "room") || routeIs(url, GAME_DESIGN_ROUTE) || routeIs(url, MAPPING_GAME_ROUTE)) {
    return GATE.features;
  }

  return routeIs(url, DESIGN_ROUTE) ? GATE.designer : null;
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
 * Names the lowest version the relay serves from its MIN_VERSION setting, as a game reads it.
 *
 * @param {string | null | undefined} setting The setting, unset for DEFAULT_MIN_VERSION.
 * @returns {string} The version; DEFAULT_MIN_VERSION when the setting is unset, no version or DEVELOPMENT_VERSION.
 */
export function minVersionText(setting) {
  const version = parseVersion(setting);
  return version && !version.development ? setting.trim() : DEFAULT_MIN_VERSION;
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
 * GATE.features asks for, or names no version or one older than the lowest the relay serves.
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

  const version = parseVersion(versionHeader);
  return version === null || (!version.development && compareVersions(version.parts, minVersionOf(minVersion)) < 0);
}

/**
 * Tells whether the world list names each world's mods, mod hashes and settings for a request:
 * for the website and the World Admin tool, while games read them from the world's own route.
 *
 * @param {string | null | undefined} featuresHeader The request's FEATURES_HEADER.
 * @returns {boolean} Whether it does.
 */
export function listsWorldMods(featuresHeader) {
  return parseFeatures(featuresHeader).some((feature) => FULL_LIST_FEATURES.includes(feature));
}

/**
 * Turns a game too old for the relay away before its request is routed.
 *
 * @param {URL} url The request's address.
 * @param {string | null | undefined} featuresHeader The request's FEATURES_HEADER.
 * @param {string | null | undefined} versionHeader The request's VERSION_HEADER.
 * @param {string | null | undefined} [minVersion] The relay's MIN_VERSION setting.
 * @param {string} [method] The request's HTTP method, see gateOf.
 * @returns {{status: number, reason: string, socket: boolean, code: string | null, minimum: string | null} | null} The refusal, with whether the route is a world room's, answered as a refused WebSocket, the code to name in REFUSAL_HEADER, which only a world room's carries, and the lowest version the relay serves to name in MIN_VERSION_HEADER; null when the game may go on.
 */
export function updateRefusal(url, featuresHeader, versionHeader, minVersion, method = undefined) {
  if (!tooOld(gateOf(url, method), featuresHeader, versionHeader, minVersion)) {
    return null;
  }

  const minimum = minVersionText(minVersion);
  return routeIs(url, "world")
    ? { status: WORLD_ROOM_UPDATE_STATUS, reason: UPDATE_NEEDED, socket: true, code: WORLD_ROOM_UPDATE_CODE, minimum }
    : { status: UPDATE_STATUS, reason: UPDATE_NEEDED, socket: false, code: null, minimum };
}

/**
 * Names the headers a refusal of a game too old for the relay carries: its code in REFUSAL_HEADER,
 * where it has one, and the lowest version the relay serves in MIN_VERSION_HEADER.
 *
 * @param {{code: string | null, minimum: string | null}} refusal The refusal, see updateRefusal.
 * @returns {Object<string, string>} The headers.
 */
export function refusalHeaders(refusal) {
  return { ...(refusal.code ? { [REFUSAL_HEADER]: refusal.code } : {}), [MIN_VERSION_HEADER]: refusal.minimum };
}
