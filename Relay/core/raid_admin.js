//----------------------------------------------------------------
//  raid_admin.js
//
//  Changelog:
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

// What the relay's admins may look at and set right in a Raid World from outside the game: the
// story's counters and the boss pools, a boss pool filled up again, and the route lock taken back.
// The sealed story stays out, since admins cannot open it anyway.

import { WORLD_TYPE } from "./directory.js";
import { badRequest, notFound, withJson } from "./http.js";
import { isId } from "./ids.js";
import { VERSION } from "./relay.js";
import { noRaidWorld } from "./story.js";

/**
 * The longest JSON body an admin's request may have.
 */
export const MAX_ADMIN_BODY_LENGTH = 4 * 1024;

/**
 * Reads which world and admin route an address names.
 *
 * @param {URL} url The request's address.
 * @returns {{id: string, rest: string[]} | null} The world and the parts after `raid`, still percent-encoded; or null when it is no admin route of a Raid World.
 */
export function raidAdminRouteOf(url) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);
  return parts.length >= 4 && parts[0] === VERSION && parts[1] === "worlds" && isId(parts[2]) && parts[3] === "raid" ? { id: parts[2], rest: parts.slice(4) } : null;
}

/**
 * Answers a request to a Raid World's admin routes, for the relay's admins only.
 *
 * @param {{story: import("./story.js").WorldStory, bosses: import("./bosses.js").WorldBosses}} world The world's story and boss pools.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address, whose `player` names the admin's key when no header does.
 * @param {string[]} rest The address's parts after `raid`, see raidAdminRouteOf.
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when it is too large to read.
 * @param {string | null} header The key the PLAYER_HEADER names, which wins over the address and the body.
 * @param {(key: unknown) => Promise<{status: number, body: object, type?: string}>} adminOf Asks the directory whether a key is an admin's, and the world's type.
 * @returns {Promise<{status: number, body: object, push?: number, boss?: {key: string, hp: number}}>} The answer, the story's revision to tell every game when it changed, and the pool to tell every game when it changed.
 */
export async function handleRaidAdminRequest(world, method, url, rest, readBody, header, adminOf) {
  const asAdmin = async (key, work) => {
    const access = await adminOf(key);

    if (access.status !== 200) {
      return access;
    }

    return access.type === WORLD_TYPE.raid ? work() : noRaidWorld();
  };

  if (rest.length === 0 && method === "GET") {
    return asAdmin(header || url.searchParams.get("player"), async () => {
      const { blob: _sealed, ...story } = (await world.story.get()).body;
      const { bosses, max, regen } = (await world.bosses.list(true)).body;
      return { status: 200, body: { story, bosses, max, regen } };
    });
  }

  const post = (work) => withJson(readBody, MAX_ADMIN_BODY_LENGTH, (body) => (body !== null && typeof body !== "object" ? badRequest("the request must be a JSON object") : asAdmin(header || body?.player, work)));

  if (rest.length === 3 && rest[0] === "bosses" && rest[2] === "reset" && method === "POST") {
    return post(() => world.bosses.reset(rest[1]));
  }

  if (rest.length === 2 && rest[0] === "route" && rest[1] === "clear" && method === "POST") {
    return post(() => world.story.clearRoute());
  }

  return notFound("route");
}
