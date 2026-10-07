//----------------------------------------------------------------
//  ids.js
//
//  Changelog:
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

// What every part of the relay reads ids, hashes and texts by, so the rules are written once: a
// room, world or trade id, a player's key or id and a salt are 32 lowercase hexadecimal characters;
// a SHA-256 hash and an auth key are 64.

/**
 * An id of 16 bytes as 32 lowercase hexadecimal characters: a room, world or trade id, a player's
 * key or id, or a salt.
 */
export const ID = /^[0-9a-f]{32}$/;

/**
 * A hash or key of 32 bytes as 64 lowercase hexadecimal characters: a SHA-256 hash or an auth key.
 */
export const HASH = /^[0-9a-f]{64}$/;

/**
 * Characters a text someone chose may not hold: control characters, and the tab and line break the
 * games read lists by.
 */
export const CONTROL_CHARACTERS = /[\u0000-\u001f\u007f]/g;

/**
 * Tells whether a value is an id of 32 lowercase hexadecimal characters.
 *
 * @param {unknown} value The value.
 * @returns {boolean} Whether it is.
 */
export function isId(value) {
  return typeof value === "string" && ID.test(value);
}

/**
 * Tells whether a value is a hash or key of 64 lowercase hexadecimal characters.
 *
 * @param {unknown} value The value.
 * @returns {boolean} Whether it is.
 */
export function isHash(value) {
  return typeof value === "string" && HASH.test(value);
}

/**
 * Writes bytes, such as a digest, as lowercase hexadecimal.
 *
 * @param {ArrayBuffer | Uint8Array} bytes The bytes.
 * @returns {string} Two hexadecimal characters per byte.
 */
export function hexOf(bytes) {
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/**
 * Tidies a text someone wrote: on one line, without control characters, trimmed and not too long.
 *
 * @param {unknown} text The text.
 * @param {number} maxLength The most characters kept.
 * @returns {string} The text, empty when there is none.
 */
export function cleanText(text, maxLength) {
  return typeof text === "string" ? [...text.replace(CONTROL_CHARACTERS, "").trim()].slice(0, maxLength).join("") : "";
}
