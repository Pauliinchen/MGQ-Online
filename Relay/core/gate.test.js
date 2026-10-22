//----------------------------------------------------------------
//  gate.test.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Tested that a relay admin passes on the format route
//                            - Tested which games hold a world's long mods and which read the world list with every world's mods
//      Paulinchen  2026-10-21: Tested the designer gate, the rule of every design route and the game's design routes asking for X-MGQ-Features
//      Paulinchen  2026-10-12: Tested that the world directory, the mod catalog and the Raid World admin routes ask for X-MGQ-Features
//                            - Tested the update code on the 400 of a world room and the World Admin tool passing with 0.0.0-dev
//                            - Tested 400 for a world room, a request without X-MGQ-Version as 0.6.4, the version gate on the directory and mod catalog and only 0.0.0-dev as a development build
//                            - Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  DESIGNER_RULE, GATE, UPDATE_NEEDED, UPDATE_STATUS, WORLD_ROOM_UPDATE_CODE, WORLD_ROOM_UPDATE_STATUS, compareVersions, designFormatOf, designerRefusal, designerRuleOf, gateOf, holdsLongMods,
  listsWorldMods, minVersionOf, parseVersion, tooOld, updateRefusal,
} from "./gate.js";

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

test("games from 0.6.8 and development builds hold long mods, and only they read the list without them but for the website and the World Admin tool", () => {
  assert.deepEqual(["0.6.7.7", "0.6.8", "0.6.8.1+abc", "0.7", "0.0.0-dev", "0.6.8-beta", null, "no version"].map(holdsLongMods), [false, true, true, true, true, true, false, false]);
  assert.equal(listsWorldMods("raid,keys", "0.6.7.7"), true, "a released game");
  assert.equal(listsWorldMods("raid", null), true, "a game naming no version");
  assert.equal(listsWorldMods("raid,keys", "0.6.8"), false);
  assert.equal(listsWorldMods("web", "0.0.0-dev"), true, "the website");
  assert.equal(listsWorldMods("admin", "0.0.0-dev"), true, "the World Admin tool");
});

test("the Raid Designer's routes go through the designer gate, which the game gate lets pass, and the game's design routes ask for X-MGQ-Features", () => {
  for (const path of ["/v1/designs", "/v1/designs/me", "/v1/designs/push", "/v1/designs/release/file"]) {
    assert.equal(gateOf(at(path)), GATE.designer, path);
    assert.equal(updateRefusal(at(path), null, null, "0.9.0"), null, path);
  }

  for (const path of ["/v1/raid-design", `/v1/raid-design/${"ab".repeat(32)}`]) {
    assert.equal(gateOf(at(path)), GATE.features, path);
    assert.notEqual(updateRefusal(at(path), null, null), null, path);
  }

  assert.equal(gateOf(at("/v1/designsx")), null);
  assert.equal(tooOld(GATE.designer, null, null, "9.0.0"), false);
});

test("each design route asks its own of a designer: me nothing, release a listed designer of any version, the designer list an admin to change it", () => {
  const cases = [
    ["GET", ["me"], DESIGNER_RULE.open], ["PUT", ["me"], DESIGNER_RULE.listed], ["GET", ["release"], DESIGNER_RULE.listed], ["GET", ["release", "file"], DESIGNER_RULE.listed],
    ["GET", ["entities"], DESIGNER_RULE.read], ["GET", ["entities", "state:1", "history"], DESIGNER_RULE.read], ["POST", ["push"], DESIGNER_RULE.write],
    ["POST", ["builds"], DESIGNER_RULE.adminWrite], ["GET", ["builds"], DESIGNER_RULE.read], ["GET", ["builds", "3", "snapshot"], DESIGNER_RULE.read],
    ["POST", ["publish"], DESIGNER_RULE.adminWrite], ["POST", ["rollback"], DESIGNER_RULE.adminWrite], ["POST", ["format"], DESIGNER_RULE.adminSetting],
    ["GET", ["designers"], DESIGNER_RULE.roster], ["PUT", ["designers", "x"], DESIGNER_RULE.manage], ["DELETE", ["designers", "x"], DESIGNER_RULE.manage], ["GET", ["socket"], DESIGNER_RULE.read],
  ];

  for (const [method, rest, rule] of cases) {
    assert.equal(designerRuleOf(method, rest), rule, `${method} ${rest.join("/")}`);
  }
});

test("the designer gate turns away an unlisted key first, then an old version or format, then a designer from an admin route, then a development build that writes", () => {
  const settings = { minVersion: "1.2.0", minFormat: 2, allowDev: false };
  const designer = { id: WORLD, listed: true, admin: false };
  const admin = { ...designer, admin: true };
  const current = { version: "1.3.0", format: "2" };
  const dev = { version: "0.0.0-dev", format: "2" };

  assert.deepEqual(designerRefusal(DESIGNER_RULE.read, { ...designer, listed: false }, { version: "0.1.0", format: null }, settings), { status: 403, body: { code: "not_designer", id: WORLD } });
  assert.deepEqual(designerRefusal(DESIGNER_RULE.read, { id: null, listed: false, admin: false }, current, settings), { status: 403, body: { code: "not_designer" } });
  assert.deepEqual(designerRefusal(DESIGNER_RULE.adminWrite, designer, { version: "1.1.9", format: "2" }, settings), { status: 426, body: { code: "update", minimum: "1.2.0", minFormat: 2 } });
  assert.deepEqual(designerRefusal(DESIGNER_RULE.read, designer, { version: "1.3.0", format: "1" }, settings).status, 426, "a format below the lowest");
  assert.deepEqual(designerRefusal(DESIGNER_RULE.read, designer, { version: "1.3.0", format: null }, settings).status, 426, "no format");
  assert.deepEqual(designerRefusal(DESIGNER_RULE.read, designer, { version: "soon", format: "2" }, settings).status, 426, "no version");
  assert.deepEqual(designerRefusal(DESIGNER_RULE.adminWrite, designer, current, settings), { status: 403, body: { code: "admin_only" } });
  assert.deepEqual(designerRefusal(DESIGNER_RULE.write, designer, dev, settings), { status: 403, body: { code: "dev_build" } });

  assert.equal(designerRefusal(DESIGNER_RULE.read, designer, dev, settings), null, "a development build reads");
  assert.equal(designerRefusal(DESIGNER_RULE.write, admin, dev, settings), null, "an admin's development build writes");
  assert.equal(designerRefusal(DESIGNER_RULE.write, designer, dev, { ...settings, allowDev: true }), null, "a relay that allows development builds");
  assert.equal(designerRefusal(DESIGNER_RULE.listed, designer, { version: "0.1.0", format: null }, settings), null, "release needs no version");
  assert.equal(designerRefusal(DESIGNER_RULE.open, { ...designer, listed: false }, { version: null, format: null }, settings), null, "me needs nothing");
  assert.equal(designerRefusal(DESIGNER_RULE.write, designer, { version: "1.2.0+abc", format: " 3 " }, settings), null);
  assert.deepEqual([designFormatOf("7"), designFormatOf("x"), designFormatOf(undefined), designFormatOf("-1")], [7, 0, 0, 0]);
});
