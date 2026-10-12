//----------------------------------------------------------------
//  gate.test.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { GATE, UPDATE_NEEDED, UPDATE_STATUS, compareVersions, gateOf, minVersionOf, parseVersion, tooOld, updateRefusal } from "./gate.js";

/**
 * A world's id as games make them.
 */
const WORLD = "0123456789abcdef0123456789abcdef";

/**
 * Makes an address on the relay.
 *
 * @param {string} path The path.
 * @returns {URL} The address.
 */
function at(path) {
  return new URL(`https://relay.test${path}`);
}

test("the routes only games use and the world rooms ask for X-MGQ-Features, the PvP rooms only for a version, the admin tool's routes for nothing", () => {
  for (const path of [`/v1/worlds/${WORLD}/story`, `/v1/worlds/${WORLD}/bosses/Lilith`, "/v1/trades", `/v1/trades/${WORLD}/commit`, "/v1/reports", `/v1/world/${WORLD}`]) {
    assert.equal(gateOf(at(path)), GATE.features, path);
  }

  assert.equal(gateOf(at(`/v1/room/${WORLD}`)), GATE.version);

  for (const path of ["/v1/worlds", `/v1/worlds/${WORLD}/edit`, `/v1/worlds/${WORLD}/start`, `/v1/worlds/${WORLD}/raid`, "/v1/mods", "/v1/mods/levelcap/file", "/internal/admit", "/"]) {
    assert.equal(gateOf(at(path)), null, path);
  }
});

test("versions are read with their build data and suffix, and compared by their numbers", () => {
  assert.deepEqual(parseVersion("0.6.5+0123abc"), { parts: [0, 6, 5], development: false });
  assert.deepEqual(parseVersion(" 0.6.2.1 "), { parts: [0, 6, 2, 1], development: false });
  assert.deepEqual(parseVersion("0.0.0-dev+0123abc"), { parts: [0, 0, 0], development: true });

  for (const text of ["", "v0.6.5", "0.6.", "six", null, undefined]) {
    assert.equal(parseVersion(text), null, String(text));
  }

  assert.ok(compareVersions([0, 6, 2, 1], [0, 6, 2]) > 0);
  assert.equal(compareVersions([0, 6], [0, 6, 0]), 0);
  assert.ok(compareVersions([0, 5, 10], [0, 6]) < 0);
});

test("the lowest version comes from the setting, or 0.6.0 when it is unset or no release version", () => {
  assert.deepEqual(minVersionOf("0.7.1"), [0, 7, 1]);

  for (const setting of [undefined, "", "soon", "0.7.0-dev"]) {
    assert.deepEqual(minVersionOf(setting), [0, 6, 0], String(setting));
  }
});

test("a game is too old without the features a route asks for, or with a version that is none or below the lowest; a development version always passes", () => {
  assert.equal(tooOld(GATE.features, null, null), true, "a game before 0.6.0");
  assert.equal(tooOld(GATE.features, " ", null), true, "an empty header counts as none");
  assert.equal(tooOld(GATE.features, "raid", null), false, "a released 0.6.x game");
  assert.equal(tooOld(GATE.features, "raid", "0.5.9"), true);
  assert.equal(tooOld(GATE.features, "raid", "0.6.0+abc"), false);
  assert.equal(tooOld(GATE.features, "raid", "0.6.9", "0.7.0"), true);
  assert.equal(tooOld(GATE.features, "raid", "0.0.0-dev", "0.7.0"), false);
  assert.equal(tooOld(GATE.features, "raid", "unknown"), true);
  assert.equal(tooOld(GATE.version, null, null), false, "a released game's PvP room");
  assert.equal(tooOld(GATE.version, null, "0.5.3"), true);
  assert.equal(tooOld(null, null, "0.1.0"), false, "a route that asks nothing");
});

test("the refusal names the update and whether its route is a WebSocket's", () => {
  assert.deepEqual(updateRefusal(at(`/v1/world/${WORLD}`), null, null), { status: UPDATE_STATUS, reason: UPDATE_NEEDED, socket: true });
  assert.deepEqual(updateRefusal(at("/v1/trades"), null, null), { status: 426, reason: "Update MGQ Online to play online.", socket: false });
  assert.equal(updateRefusal(at("/v1/trades"), "raid", null), null);
  assert.equal(updateRefusal(at("/v1/worlds"), null, null), null);
});
