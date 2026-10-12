//----------------------------------------------------------------
//  gate.test.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Tested that the world directory, the mod catalog and the Raid World admin routes ask for X-MGQ-Features
//                            - Tested the update code on the 400 of a world room and the World Admin tool passing with 0.0.0-dev
//                            - Tested 400 without a code for a world room, a request without X-MGQ-Version as 0.6.4, the version gate on the world directory's and the mod catalog's routes and only 0.0.0-dev as a development build
//                            - Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { GATE, UPDATE_NEEDED, UPDATE_STATUS, WORLD_ROOM_UPDATE_CODE, WORLD_ROOM_UPDATE_STATUS, compareVersions, gateOf, minVersionOf, parseVersion, tooOld, updateRefusal } from "./gate.js";

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

test("the routes games and the World Admin tool use and the world rooms ask for X-MGQ-Features, the PvP rooms only for a version", () => {
  for (const path of [
    `/v1/worlds/${WORLD}/story`, `/v1/worlds/${WORLD}/bosses/Lilith`, "/v1/trades", `/v1/trades/${WORLD}/commit`, "/v1/reports", `/v1/world/${WORLD}`,
    "/v1/worlds", `/v1/worlds/${WORLD}/edit`, `/v1/worlds/${WORLD}/start`, `/v1/worlds/${WORLD}/chat`, `/v1/worlds/${WORLD}/raid`, `/v1/worlds/${WORLD}/raid/route/clear`, "/v1/mods", "/v1/mods/levelcap/file",
  ]) {
    assert.equal(gateOf(at(path)), GATE.features, path);
  }

  assert.equal(gateOf(at(`/v1/room/${WORLD}`)), GATE.version);

  for (const path of ["/internal/admit", "/v1/worldsx", "/"]) {
    assert.equal(gateOf(at(path)), null, path);
  }
});

test("versions are read with their build data and suffix, only 0.0.0-dev counts as a development build, and versions compare by their numbers", () => {
  assert.deepEqual(parseVersion("0.6.5+0123abc"), { parts: [0, 6, 5], development: false });
  assert.deepEqual(parseVersion(" 0.6.2.1 "), { parts: [0, 6, 2, 1], development: false });
  assert.deepEqual(parseVersion("0.0.0-dev"), { parts: [0, 0, 0], development: true });
  assert.deepEqual(parseVersion("0.0.0-dev+0123abc"), { parts: [0, 0, 0], development: true });
  assert.deepEqual(parseVersion("0.7.0-beta"), { parts: [0, 7, 0], development: false });
  assert.deepEqual(parseVersion("0.6.5-dev"), { parts: [0, 6, 5], development: false });
  assert.deepEqual(parseVersion("0.0.0-dev.1"), { parts: [0, 0, 0], development: false });
  assert.deepEqual(parseVersion("0.0-dev"), { parts: [0, 0], development: false });

  for (const text of ["", "v0.6.5", "0.6.", "six", null, undefined]) {
    assert.equal(parseVersion(text), null, String(text));
  }

  assert.ok(compareVersions([0, 6, 2, 1], [0, 6, 2]) > 0);
  assert.equal(compareVersions([0, 6], [0, 6, 0]), 0);
  assert.ok(compareVersions([0, 5, 10], [0, 6]) < 0);
});

test("the lowest version comes from the setting by its numbers, or 0.6.0 when it is unset, no version or the development stamp", () => {
  assert.deepEqual(minVersionOf("0.7.1"), [0, 7, 1]);
  assert.deepEqual(minVersionOf("0.7.0-beta"), [0, 7, 0]);

  for (const setting of [undefined, "", "soon", "0.0.0-dev"]) {
    assert.deepEqual(minVersionOf(setting), [0, 6, 0], String(setting));
  }
});

test("a game is too old without the features a route asks for, or with a version that is none or below the lowest; the development stamp always passes", () => {
  assert.equal(tooOld(GATE.features, null, null), true, "a game before 0.6.0");
  assert.equal(tooOld(GATE.features, " ", null), true, "an empty header counts as none");
  assert.equal(tooOld(GATE.features, "raid", null), false, "a released 0.6.x game");
  assert.equal(tooOld(GATE.features, "raid", "0.5.9"), true);
  assert.equal(tooOld(GATE.features, "raid", "0.6.0+abc"), false);
  assert.equal(tooOld(GATE.features, "raid", "0.6.9", "0.7.0"), true);
  assert.equal(tooOld(GATE.features, "raid", "0.0.0-dev", "0.7.0"), false);
  assert.equal(tooOld(GATE.features, "raid", "0.0.0-dev+abc", "0.7.0"), false);
  assert.equal(tooOld(GATE.features, "raid", "0.6.9-dev", "0.7.0"), true, "another suffixed version is held to its numbers");
  assert.equal(tooOld(GATE.features, "raid", "0.7.0-beta", "0.7.0"), false);
  assert.equal(tooOld(GATE.version, null, "0.7.0-beta", "0.7.1"), true);
  assert.equal(tooOld(GATE.features, "raid", "unknown"), true);
  assert.equal(tooOld(GATE.version, null, null), false, "a released game's PvP room");
  assert.equal(tooOld(GATE.version, null, "0.5.3"), true);
  assert.equal(tooOld(null, null, "0.1.0"), false, "a route that asks nothing");
});

test("a game that names no version counts as 0.6.4, so it is turned away only once the lowest is above 0.6.4", () => {
  for (const gate of [GATE.features, GATE.version]) {
    assert.equal(tooOld(gate, "raid", null, "0.6.4"), false, gate);
    assert.equal(tooOld(gate, "raid", " ", "0.6.4"), false, `${gate}: an empty header counts as none`);
    assert.equal(tooOld(gate, "raid", null, "0.6.4.1"), true, gate);
    assert.equal(tooOld(gate, "raid", null, "0.6.5"), true, gate);
  }

  assert.equal(tooOld(GATE.version, null, null, "0.6.5"), true, "a released game's PvP room");
  assert.equal(tooOld(GATE.version, null, null), false, "a request naming no version while the lowest stays at 0.6.0");
  assert.equal(tooOld(GATE.version, "admin", "0.0.0-dev", "0.9.0"), false, "the World Admin tool names 0.0.0-dev");
});

test("a world room refuses with 400 and the update code, a PvP room with 426 and the text as its code, any other route with 426", () => {
  assert.deepEqual(updateRefusal(at(`/v1/world/${WORLD}`), null, null), { status: WORLD_ROOM_UPDATE_STATUS, reason: UPDATE_NEEDED, socket: true, code: WORLD_ROOM_UPDATE_CODE });
  assert.deepEqual([WORLD_ROOM_UPDATE_STATUS, WORLD_ROOM_UPDATE_CODE], [400, "update"], "released games stop at a 400 with a code they do not know and show an update hint");
  assert.deepEqual(updateRefusal(at(`/v1/world/${WORLD}`), "raid", "0.6.9", "0.7.0"), { status: 400, reason: UPDATE_NEEDED, socket: true, code: "update" });
  assert.deepEqual(updateRefusal(at(`/v1/room/${WORLD}`), null, "0.5.3"), { status: UPDATE_STATUS, reason: UPDATE_NEEDED, socket: true, code: UPDATE_NEEDED });
  assert.deepEqual(updateRefusal(at("/v1/trades"), null, null), { status: 426, reason: "Update MGQ Online to play online.", socket: false, code: null });
  assert.deepEqual(updateRefusal(at("/v1/worlds"), null, "0.5.3"), { status: 426, reason: UPDATE_NEEDED, socket: false, code: null });
  assert.deepEqual(updateRefusal(at("/v1/mods"), null, null, "0.7.0"), { status: 426, reason: UPDATE_NEEDED, socket: false, code: null });
  assert.equal(updateRefusal(at("/v1/trades"), "raid", null), null);
  assert.deepEqual(updateRefusal(at("/v1/worlds"), null, null), { status: 426, reason: UPDATE_NEEDED, socket: false, code: null }, "a game before 0.6.0 or an older World Admin tool build");
  assert.deepEqual(updateRefusal(at(`/v1/worlds/${WORLD}/raid`), null, "0.0.0-dev"), { status: 426, reason: UPDATE_NEEDED, socket: false, code: null }, "the version alone is not enough");
  assert.equal(updateRefusal(at("/v1/mods"), "admin", "0.0.0-dev", "0.9.0"), null, "the World Admin tool");
  assert.equal(updateRefusal(at(`/v1/worlds/${WORLD}/raid/route/clear`), "admin", "0.0.0-dev", "0.7.0"), null, "the World Admin tool on a Raid World admin route");

  for (const path of ["/v1/worlds", `/v1/worlds/${WORLD}/raid`, "/v1/mods"]) {
    assert.equal(updateRefusal(at(path), "raid", null, "0.6.4"), null, `${path}: a released 0.6.x game`);
    assert.notEqual(updateRefusal(at(path), "raid", null, "0.6.5"), null, `${path}: a released 0.6.x game once the lowest is above 0.6.4`);
  }

  assert.equal(updateRefusal(at(`/v1/world/${WORLD}`), "raid", null, "0.6.4"), null, "a released 0.6.4 game");
});
