//----------------------------------------------------------------
//  admin.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

// The relay's own admin routes, beside the directory's: what the relay carries right now, for the
// website's dashboard. The platform layer gathers the figures, since only it holds the rooms.

import { notFound } from "./http.js";
import { VERSION } from "./relay.js";

/**
 * The route's name after the version.
 */
export const ADMIN_ROUTE = "admin";

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
 * @param {{stats: () => Promise<object>}} relay What the platform layer hands out: the figures of what it carries now.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address, whose `player` names the admin's key when no header does.
 * @param {string[]} rest The address's parts after `admin`, see adminRouteOf.
 * @param {string | null} header The key the PLAYER_HEADER names, which wins over the address.
 * @param {(key: unknown) => Promise<boolean>} isAdmin Tells whether a key is an admin's, see adminCheck.
 * @returns {Promise<{status: number, body: object}>} The answer.
 */
export async function handleAdminRequest(relay, method, url, rest, header, isAdmin) {
  if (rest.length === 1 && rest[0] === "stats" && method === "GET") {
    if (!(await isAdmin(header || url.searchParams.get("player")))) {
      return { status: 403, body: { error: "only the relay's admins may do this" } };
    }

    return { status: 200, body: await relay.stats() };
  }

  return notFound("route");
}
