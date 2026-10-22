//----------------------------------------------------------------
//  admin.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Handed out and set the release games should run and the lowest one the relay serves
//      Paulinchen  2026-10-21: Said an admin's line in every world with players online
//                            - Created
//
//----------------------------------------------------------------

// The relay's own admin routes, beside the directory's: what the relay carries right now, for the
// website's dashboard, a line said in every world with players online, and the release control.
// The platform layer gathers the figures and tells the world rooms, since only it holds the rooms.

import { playerIdOf } from "./directory.js";
import { badRequest, notFound, withJson } from "./http.js";
import { cleanText } from "./ids.js";
import { VERSION } from "./relay.js";

/**
 * The route's name after the version.
 */
export const ADMIN_ROUTE = "admin";

/**
 * The longest line an admin announces: released games cut every chat line they show to 120
 * characters.
 */
export const MAX_ANNOUNCE_LENGTH = 120;

/**
 * The longest JSON body an admin's request may have.
 */
const MAX_BODY_LENGTH = 4 * 1024;

/**
 * Reads which admin route an address names.
 *
 * @param {URL} url The request's address.
 * @returns {{rest: string[]} | null} The parts after `admin`, or null when it is no admin route.
 */
export function adminRouteOf(url) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);
  return parts.length >= 2 && parts[0] === VERSION && parts[1] === ADMIN_ROUTE ? { rest: parts.slice(2) } : null;
}

/**
 * Answers a request to the relay's admin routes, for the relay's admins only.
 *
 * @param {{stats: () => Promise<object>, announce: (text: string) => Promise<number>, release: import("./releases.js").ReleaseControl, releaseSet?: (answer: {status: number, body: object, before?: object}, admin: string) => void}} relay What the platform layer does: hands out the figures of what it carries now, says a line in every world with players online, answering in how many, keeps the release control, and hears of each change an admin made to it.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address, whose `player` names the admin's key when no header does.
 * @param {string[]} rest The address's parts after `admin`, see adminRouteOf.
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when it is too large to read.
 * @param {string | null} header The key the PLAYER_HEADER names, which wins over the address and the body.
 * @param {(key: unknown) => Promise<boolean>} isAdmin Tells whether a key is an admin's, see adminCheck.
 * @returns {Promise<{status: number, body: object}>} The answer.
 */
export async function handleAdminRequest(relay, method, url, rest, readBody, header, isAdmin) {
  const refused = { status: 403, body: { error: "only the relay's admins may do this" } };

  if (rest.length === 1 && rest[0] === "stats" && method === "GET") {
    return (await isAdmin(header || url.searchParams.get("player"))) ? { status: 200, body: await relay.stats() } : refused;
  }

  if (rest.length === 1 && rest[0] === "release" && method === "GET") {
    return (await isAdmin(header || url.searchParams.get("player"))) ? { status: 200, body: relay.release.adminView() } : refused;
  }

  if (rest.length === 1 && rest[0] === "release" && method === "POST") {
    return withJson(readBody, MAX_BODY_LENGTH, async (body) => {
      const key = header || body?.player;

      if (!(await isAdmin(key))) {
        return refused;
      }

      const admin = await playerIdOf(key);
      const answer = await relay.release.set(body, admin);
      relay.releaseSet?.(answer, admin);
      return { status: answer.status, body: answer.body };
    });
  }

  if (rest.length === 1 && rest[0] === "announce" && method === "POST") {
    return withJson(readBody, MAX_BODY_LENGTH, async (body) => {
      if (!(await isAdmin(header || body?.player))) {
        return refused;
      }

      const text = cleanText(body?.text, Infinity);

      if (typeof body?.text !== "string" || text.length === 0 || [...text].length > MAX_ANNOUNCE_LENGTH) {
        return badRequest(`the line must be a text of 1 to ${MAX_ANNOUNCE_LENGTH} characters`);
      }

      return { status: 200, body: { text, worlds: await relay.announce(text) } };
    });
  }

  return notFound("route");
}
