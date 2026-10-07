//----------------------------------------------------------------
//  http.js
//
//  Changelog:
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

// The answers every router of the relay gives alike, and how each reads a JSON body: a body longer
// than its route takes is answered with 413 everywhere, whether the route's own limit or the
// platform's cap on what it reads stopped it.

import { VERSION } from "./relay.js";

/**
 * What readJson hands back for a body longer than its route takes.
 */
export const TOO_LARGE = Symbol("too large");

/**
 * Tells whether an address is a route or one of its sub-routes, such as /v1/worlds or /v1/worlds/….
 *
 * @param {URL} url The request's address.
 * @param {string} name The route's name after the version, such as "worlds".
 * @returns {boolean} Whether it is.
 */
export function routeIs(url, name) {
  return url.pathname === `/${VERSION}/${name}` || url.pathname.startsWith(`/${VERSION}/${name}/`);
}

/**
 * The answer for a request that is not as it should be.
 *
 * @param {string} reason Why.
 * @returns {{status: number, body: object}} The answer.
 */
export function badRequest(reason) {
  return { status: 400, body: { error: reason } };
}

/**
 * The answer for something that does not exist, or not for the asking player.
 *
 * @param {string} what What there is none of, such as "world" or "route".
 * @returns {{status: number, body: object}} The answer.
 */
export function notFound(what) {
  return { status: 404, body: { error: `there is no such ${what}` } };
}

/**
 * The answer for a body longer than a route takes.
 *
 * @param {number} limit The most a route takes.
 * @param {string} [unit] What the limit counts, characters unless given.
 * @returns {{status: number, body: object}} The answer.
 */
export function tooLarge(limit, unit = "characters") {
  return { status: 413, body: { error: `the request may be at most ${limit} ${unit}` } };
}

/**
 * Reads a JSON body, small ones only.
 *
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when the platform found it too large to read.
 * @param {number} maxLength The most characters the route takes.
 * @returns {Promise<any>} The parsed body, TOO_LARGE when it is longer than the route takes, or null when it is no JSON.
 */
export async function readJson(readBody, maxLength) {
  let text;

  try {
    text = await readBody();
  } catch {
    return null;
  }

  if (text === null || text.length > maxLength) {
    return TOO_LARGE;
  }

  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

/**
 * Reads a JSON body and hands it to a route, or answers 413 for one longer than the route takes.
 *
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when the platform found it too large to read.
 * @param {number} maxLength The most characters the route takes.
 * @param {(body: any) => Promise<{status: number, body: object}> | {status: number, body: object}} handle The route, given the parsed body, or null for no JSON.
 * @returns {Promise<{status: number, body: object}>} The route's answer, or the refusal.
 */
export async function withJson(readBody, maxLength, handle) {
  const body = await readJson(readBody, maxLength);
  return body === TOO_LARGE ? tooLarge(maxLength) : handle(body);
}
