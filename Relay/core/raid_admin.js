//----------------------------------------------------------------
//  raid_admin.js
//
//  Changelog:
//      Paulinchen  2026-11-06: Took an admin's key from the X-MGQ-Player header only
//                            - Showed and changed the world's track alone, without falling back on the keyed story
//      Paulinchen  2026-11-05: Took an admin's key on the story view from the X-MGQ-Player header only
//                            - Named the routes' counters by the story's ids
//      Paulinchen  2026-11-01: Refused pins of keys the story mapping does not share on a world whose story runs on tracks
//      Paulinchen  2026-10-31: Left the sealed story out, which the relay keeps no more
//                            - Showed, set and pinned the world's track of a world whose story runs on tracks, with its part and routes
//                            - Took back the route lock of the world's track
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
// taken back. The story shown and changed is the world's track, never the tracks of players behind;
// the keyed story only keeps the shared companions and the pins.

import { WORLD_TYPE } from "./directory.js";
import { badRequest, notFound, withJson } from "./http.js";
import { isId } from "./ids.js";
import { VERSION } from "./relay.js";
import { STORY_LIMITS, STORY_REFUSAL, listsOf, noRaidWorld, pinsView, readAdminKeys, readPins, routeCounters } from "./story.js";
import { TRACK_CODE } from "./story_tracks.js";

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
 * Makes the state an admin reads of a world's story: the world's track, with the shared companions
 * and what older games wrote of the keyed story.
 *
 * @param {object} view The world's track, see StoryTracks.view.
 * @param {object | undefined} keyed The keyed story as kept, undefined before the first write.
 * @returns {object} The state, with `tracks` true, and `keyed` with the track's `keys` when the view has them.
 */
function trackStateOf(view, keyed) {
  const { counters, keys, ...summary } = view;
  const state = {
    rev: summary.rev, wrev: summary.rev, p: counters.p, ...routeCounters(counters), clear: counters.clear, part: summary.part, route: summary.route, done: summary.done,
    end: keyed?.end ?? null, comps: [...(keyed?.comps ?? [])], caps: [...(keyed?.caps ?? [])], checkpoints: summary.checkpoints, at: summary.at, tracks: true,
  };
  return keys ? { ...state, keyed: true, keys } : state;
}

/**
 * Answers a request to a Raid World's admin routes, for the relay's admins only.
 *
 * @param {{story: import("./story.js").WorldStory, bosses: import("./bosses.js").WorldBosses, tracks: import("./story_tracks.js").StoryTracks}} world The world's keyed story, boss pools and story tracks.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address, whose `player` names the admin's key when no header does.
 * @param {string[]} rest The address's parts after `raid`, see raidAdminRouteOf.
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when it is too large to read.
 * @param {string | null} header The key the PLAYER_HEADER names, which wins over the address and the body.
 * @param {(key: unknown) => Promise<{status: number, body: object, type?: string, player?: string}>} adminOf Asks the directory whether a key is an admin's, and the world's type and the admin's player id.
 * @returns {Promise<{status: number, body: object, boss?: import("./bosses.js").BossPush, bosses?: import("./bosses.js").BossPush[], audit?: string}>} The answer, the pool or pools to tell every game when they changed (the tracks tell their games themselves), and what an admin changed of the story's keys, for the log.
 */
export async function handleRaidAdminRequest(world, method, url, rest, readBody, header, adminOf) {
  const asAdmin = async (key, work) => {
    const access = await adminOf(key);

    if (access.status !== 200) {
      return access;
    }

    return access.type === WORLD_TYPE.raid ? work(access) : noRaidWorld();
  };

  const trackState = async (view) => trackStateOf(view, await world.story.kept());

  if (rest.length === 0 && method === "GET") {
    return asAdmin(header, async () => {
      // A late story's keys run to a megabyte, which only a view of the keys needs.
      const story = await trackState(await world.tracks.view(url.searchParams.get("keys") === "1"));
      const pins = pinsView(await world.story.kept());
      const { bosses, regenPerMinute } = (await world.bosses.list(true)).body;
      return { status: 200, body: { story, pins, bosses, regenPerMinute } };
    });
  }

  const post = (work) => withJson(readBody, MAX_ADMIN_BODY_LENGTH, (body) => (body !== null && typeof body !== "object" ? badRequest("the request must be a JSON object") : asAdmin(header, (access) => work(access, body))));

  if (rest.length === 2 && rest[0] === "bosses" && rest[1] === "kill" && method === "POST") {
    return post((access, body) => world.bosses.kill(body, access.player ?? null));
  }

  if (rest.length === 3 && rest[0] === "bosses" && rest[2] === "reset" && method === "POST") {
    return post(() => world.bosses.reset(rest[1]));
  }

  const keyed = (work) => withJson(readBody, STORY_LIMITS.maxAdminBodyLength, (body) => asAdmin(header, (access) => work(access, body)));

  if (rest.length === 1 && rest[0] === "keys" && method === "POST") {
    return keyed(async (access, body) => {
      const answer = await setTrackKeys(world, body, access.player, trackState);
      return answer.status === 200 ? { ...answer, audit: `admin ${access.player} set keys of rev ${answer.body.rev}: ${JSON.stringify(answer.body.set)}` } : answer;
    });
  }

  if (rest.length === 1 && rest[0] === "pins" && method === "POST") {
    return keyed(async (access, body) => {
      const answer = await pinTrackKeys(world, body, trackState);
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
    return post(async () => {
      const answer = await world.tracks.clearRoute();
      const state = await trackState(answer.view);
      return answer.started
        ? { status: 409, body: { ...state, error: "the world's story is on the locked route already", code: STORY_REFUSAL.started } }
        : { status: 200, body: { ...state, cleared: answer.cleared } };
    });
  }

  return notFound("route");
}

/**
 * Sets keys of the world's track as an admin asks.
 *
 * @param {{tracks: import("./story_tracks.js").StoryTracks}} world The world.
 * @param {any} body The keys, see story.js readAdminKeys.
 * @param {string} admin The admin's player id.
 * @param {(view: object) => Promise<object>} trackState Makes the state an admin reads, see trackStateOf.
 * @returns {Promise<{status: number, body: object}>} The world's state with `set` (the lists of the keys that changed); 409 with `code` and `keys` for keys refused, `pinned` for keys pinned at other values, `mapping` for keys the tracks keep not as set; or why the request is wrong.
 */
async function setTrackKeys(world, body, admin, trackState) {
  const read = readAdminKeys(body, STORY_LIMITS);

  if (read.error) {
    return badRequest(read.error);
  }

  const answer = await world.tracks.setKeys(read.keys, admin);

  if (answer.code === TRACK_CODE.bad) {
    return badRequest(`keys are named without leading zeros, such as s12, v1201 or ss858.139.A: ${answer.keys.join(", ").slice(0, 200)}`);
  }

  if (answer.code) {
    return answer.code === TRACK_CODE.pinned ? { status: 409, body: { error: "an admin pinned these keys at other values", code: answer.code, keys: answer.keys } } : mappingRefusal(answer.keys, true);
  }

  return { status: 200, body: { ...(await trackState(answer.view)), set: listsOf(answer.changed) } };
}

/**
 * Makes the answer to an admin who names keys the story mapping does not share.
 *
 * @param {string[]} keys The keys.
 * @param {boolean} counts Whether counts are among the keys refused, which the relay counts itself.
 * @returns {{status: number, body: object}} 409 with code `mapping` and `keys`.
 */
function mappingRefusal(keys, counts) {
  const error = `the story mapping leaves these keys to each player, to a scene or a chest${counts ? ", or counts them itself" : ""}`;
  return { status: 409, body: { error, code: TRACK_CODE.mapping, keys } };
}

/**
 * Pins keys as an admin asks: the keyed story keeps the pins, and the world's track takes their
 * values as a revision every game on it hears.
 *
 * @param {{story: import("./story.js").WorldStory, tracks: import("./story_tracks.js").StoryTracks}} world The world.
 * @param {any} body `keys`, see story.js readPins.
 * @param {(view: object) => Promise<object>} trackState Makes the state an admin reads, see trackStateOf.
 * @returns {Promise<{status: number, body: object}>} The world's state with `set` (the lists of the keys that changed) and `pins`, see pinsView; 409 with code `mapping` and `keys` for keys the story mapping does not share; or why the request is wrong.
 */
async function pinTrackKeys(world, body, trackState) {
  const read = readPins(body?.keys, STORY_LIMITS);
  const refused = read.error ? null : await world.tracks.pinRefusal(read.keys);

  if (refused?.code === TRACK_CODE.bad) {
    return badRequest(`keys are named without leading zeros, such as s12, v1201 or ss858.139.A: ${refused.keys.join(", ").slice(0, 200)}`);
  }

  if (refused) {
    return mappingRefusal(refused.keys, false);
  }

  const kept = await world.story.keepPins(body);

  if (kept.status !== 200) {
    return kept;
  }

  const changed = await world.tracks.pinsChanged();
  return { status: 200, body: { ...(await trackState(await world.tracks.view(false))), set: listsOf(changed), pins: kept.body.pins } };
}
