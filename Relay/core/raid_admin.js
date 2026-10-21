//----------------------------------------------------------------
//  raid_admin.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Let an admin defeat every pool of a troop at once
//                            - Handed out a keyed story's keys only when the request asks for them
//                            - Let an admin set a keyed story's switches, variables and self switches by id
//                            - Let an admin pin a keyed story's keys at values, take pins off and see them
//      Paulinchen  2026-10-10: Showed each boss pool's share of HP left and the pools' regeneration per minute
//      Paulinchen  2026-10-09: Created
//
//----------------------------------------------------------------

// What the relay's admins may look at and set right in a Raid World from outside the game: the
// story's counters and the boss pools, a boss pool filled up again or defeated, and the route lock
// taken back.
// The sealed story stays out, since admins cannot open it anyway.

import { WORLD_TYPE } from "./directory.js";
import { badRequest, notFound, withJson } from "./http.js";
import { isId } from "./ids.js";
import { VERSION } from "./relay.js";
import { STORY_LIMITS, noRaidWorld, pinsView } from "./story.js";

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
 * @param {(key: unknown) => Promise<{status: number, body: object, type?: string, player?: string}>} adminOf Asks the directory whether a key is an admin's, and the world's type and the admin's player id.
 * @returns {Promise<{status: number, body: object, push?: number | object, boss?: import("./bosses.js").BossPush, bosses?: import("./bosses.js").BossPush[], audit?: string}>} The answer, the story's change to tell every game when it changed, the pool or pools to tell every game when they changed, and what an admin changed of the story's keys, for the log.
 */
export async function handleRaidAdminRequest(world, method, url, rest, readBody, header, adminOf) {
  const asAdmin = async (key, work) => {
    const access = await adminOf(key);

    if (access.status !== 200) {
      return access;
    }

    return access.type === WORLD_TYPE.raid ? work(access) : noRaidWorld();
  };

  if (rest.length === 0 && method === "GET") {
    return asAdmin(header || url.searchParams.get("player"), async () => {
      // A late story's keys run to a megabyte, which only a view of the keys needs.
      const { blob: _sealed, keyed, keys, ...counters } = (await world.story.get()).body;
      const story = url.searchParams.get("keys") === "1" ? { ...counters, keyed: keyed === true, ...(keys ? { keys } : {}) } : counters;
      const pins = pinsView(await world.story.kept());
      const { bosses, regenPerMinute } = (await world.bosses.list(true)).body;
      return { status: 200, body: { story, pins, bosses, regenPerMinute } };
    });
  }

  const post = (work) => withJson(readBody, MAX_ADMIN_BODY_LENGTH, (body) => (body !== null && typeof body !== "object" ? badRequest("the request must be a JSON object") : asAdmin(header || body?.player, (access) => work(access, body))));

  if (rest.length === 2 && rest[0] === "bosses" && rest[1] === "kill" && method === "POST") {
    return post((access, body) => world.bosses.kill(body, access.player ?? null));
  }

  if (rest.length === 3 && rest[0] === "bosses" && rest[2] === "reset" && method === "POST") {
    return post(() => world.bosses.reset(rest[1]));
  }

  const keyed = (work) => withJson(readBody, STORY_LIMITS.maxAdminBodyLength, (body) => asAdmin(header || body?.player, (access) => work(access, body)));

  if (rest.length === 1 && rest[0] === "keys" && method === "POST") {
    return keyed(async (access, body) => {
      const answer = await world.story.setKeys(body, access.player);
      return answer.status === 200 ? { ...answer, audit: `admin ${access.player} set keys of rev ${answer.body.rev}: ${JSON.stringify(answer.body.set)}` } : answer;
    });
  }

  if (rest.length === 1 && rest[0] === "pins" && method === "POST") {
    return keyed(async (access, body) => {
      const answer = await world.story.pinKeys(body, access.player);
      return answer.status === 200 ? { ...answer, audit: `admin ${access.player} pinned ${JSON.stringify(body.keys)}, rev ${answer.body.rev}` } : answer;
    });
  }

  if (rest.length === 2 && rest[0] === "pins" && rest[1] === "clear" && method === "POST") {
    return keyed(async (access, body) => {
      const answer = await world.story.clearPins(body);
      return answer.status === 200 ? { ...answer, audit: `admin ${access.player} took the pins off ${JSON.stringify(answer.body.cleared)}` } : answer;
    });
  }

  if (rest.length === 2 && rest[0] === "route" && rest[1] === "clear" && method === "POST") {
    return post(() => world.story.clearRoute());
  }

  return notFound("route");
}
