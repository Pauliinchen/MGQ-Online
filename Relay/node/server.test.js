//----------------------------------------------------------------
//  server.test.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Tested the admins' stats of the world rooms, PvP rooms, players and game versions
//      Paulinchen  2026-10-15: Tested that a relay that starts marks every player offline
//                            - Covered a keyed Raid World story's pushes and the games sent to update
//      Paulinchen  2026-10-14: Tested a Raid World's starting save from every game over HTTP
//      Paulinchen  2026-10-13: Tested that every game of a Classic world hears whether it fights raid bosses
//                            - Tested that every game of a Raid World hears its new squad settings
//      Paulinchen  2026-10-12: Tested that a newer release of the mod reaches every game of a world with players online
//                            - Sent X-MGQ-Features on the world directory and mod catalog requests and tested refusals without it
//                            - Tested the update code on the 400 of a refused world room and the World Admin tool passing with 0.0.0-dev
//                            - Sent X-MGQ-Features as released games do and tested that games without it or below the lowest version are turned away with 426
//                            - Tested a world room refused with 400, a request without X-MGQ-Version taken as 0.6.4 and the directory and mod catalog held to MIN_VERSION
//                            - Tested a busy bug report over HTTP and the screenshot blob uploaded before the branch is read
//                            - Checked that the sweep drops the sealed offers of a trade it cancels
//      Paulinchen  2026-10-11: Tested a bug report over HTTP
//      Paulinchen  2026-10-10: Tested a Raid World starting save from a game naming the dev feature over HTTP
//                            - Tested boss pools that keep the share of a raid max HP left over HTTP
//      Paulinchen  2026-10-09: Tested that every game of a world hears whether it turns other mods off
//                            - Tested a Raid World's boss pools over HTTP
//                            - Tested that every game of a Raid World hears its new difficulty
//                            - Tested that a story write whose body comes after the world was deleted leaves no story behind
//      Paulinchen  2026-10-08: Tested a Raid World's story over HTTP
//                            - Tested that a world room lets into a Raid World only the games that name it in X-MGQ-Features
//                            - Tested the chat's rate limit and a chat frame without a line
//      Paulinchen  2026-10-07: Tested a world's chat
//                            - Tested the auth key header, the log lines, the mod catalog routes, editing a world, the address behind a proxy, the sweep and a text body over the cap
//                            - Expected 400 for a path that is no route and 426 for a room path without an upgrade
//      Paulinchen  2026-10-06: Tested a guest waiting alone, keep-alives, ended rooms, replaced connections, the player key header, refusals, the rate limits and a body over the limit
//                            - Tested a trade between two players of a world over HTTP
//      Paulinchen  2026-10-04: Expected the lock without the mods, the game data and the rule for it again
//                            - Expected the lock to name a world's mods, game data and same-data rule
//      Paulinchen  2026-10-02: Expected the lock to say whether new players choose where to start
//                            - Expected the list to say when each player was last seen
//      Paulinchen  2026-09-30: Tested the starting save over HTTP, as bytes both ways
//                            - Expected the lock to name its world
//      Paulinchen  2026-09-29: Made every world in the directory first and tested the directory over HTTP
//                            - Tested world rooms over real WebSockets
//                            - Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { gzipSync } from "node:zlib";
import WebSocketClient from "ws";
import { BOSS_LIMITS } from "../core/bosses.js";
import { DIRECTORY_LIMITS, Directory, playerIdOf, sha256Hex } from "../core/directory.js";
import { UPDATE_NEEDED, VERSION_HEADER } from "../core/gate.js";
import { ModCatalog, zipHashes } from "../core/mods.js";
import { AUTH_HEADER, CHAT_LIMITS, CHAT_SLOW, CLOSE, EVERYONE, FEATURES_HEADER, LIMITS, PAIRED, PING, PLAYER_HEADER, PONG, REFUSAL_HEADER, REPLACED } from "../core/relay.js";
import { RELEASE_REPO, ReleaseWatch } from "../core/releases.js";
import { REPORT_LIMITS, ReportDesk } from "../core/reports.js";
import { STORY_LIMITS } from "../core/story.js";
import { TRADE_LIMITS } from "../core/trades.js";
import { makeUpload, makeZip } from "../core/test_zip.js";
import { addressOf, clearPresence, createRelay, errorLine, memoryModStore, memoryReleaseStore, memoryStore, requestLine } from "./server.js";

/**
 * The auth key the tests' games make from their worlds' tokens.
 */
const AUTH = "ab".repeat(32);

/**
 * The player key of the tests' world creator.
 */
const CREATOR = "c0".repeat(16);

/**
 * An admin's player key, of the directory and of the mod catalog.
 */
const ADMIN = "ad".repeat(16);

/**
 * The limits the tests use: small messages, so the size check is quick to reach.
 */
const TEST_LIMITS = { ...LIMITS, maxMessageBytes: 1024 };

/**
 * The rate limits the tests use: high enough for every test from the same address.
 */
const TEST_RATES = Object.fromEntries(["joins", "creates", "starts"].map((kind) => [kind, { burst: 10_000, refillMs: 1 }]));

/**
 * The directory limits the tests use: small starting saves, so a body over the limit is quick to
 * send, and room for every test's world of the one creator.
 */
const TEST_DIRECTORY_LIMITS = { ...DIRECTORY_LIMITS, maxStartBytes: 400_000, maxWorldsPerCreator: 100 };

/**
 * What the relay under test logged: request lines and error lines.
 */
const logged = { info: [], error: [] };

/**
 * The log the relays under test write to, so the tests can read it and the output stays clean.
 */
const LOG = { info: (line) => logged.info.push(line), error: (line) => logged.error.push(line) };

/**
 * The header every released game from 0.6.0 sends on its directory requests and world rooms.
 */
const GAME = Object.freeze({ [FEATURES_HEADER]: "raid" });

/**
 * The headers the World Admin tool sends on every request.
 */
const ADMIN_TOOL = Object.freeze({ [FEATURES_HEADER]: "admin", [VERSION_HEADER]: "0.0.0-dev" });

/**
 * Sends a request as a released game from 0.6.0 sends it to the world directory and the mod catalog,
 * with GAME before the request's own headers.
 *
 * @param {string} address The address.
 * @param {RequestInit} [init] The request, its headers as an object.
 * @returns {Promise<Response>} The answer.
 */
function gameFetch(address, init = {}) {
  return fetch(address, { ...init, headers: { ...GAME, ...init.headers } });
}

/**
 * The time the relay under test sees, which tests move forward.
 */
let now = 1_000_000;

/**
 * The tag GitHub's latest release page of the mod leads to, which tests change.
 */
let latestTag = "v0.6.4";

/**
 * The relay under test.
 */
let relay;

/**
 * The address of the relay's rooms.
 */
let base;

/**
 * The address of the relay's world rooms.
 */
let worldBase;

/**
 * The address of the relay's world directory.
 */
let directoryBase;

before(async () => {
  const directory = new Directory(memoryStore(), { clock: () => now, limits: TEST_DIRECTORY_LIMITS, rates: TEST_RATES, admins: [await playerIdOf(ADMIN)] });
  const latestPage = async () => new Response(null, { status: 302, headers: { Location: `https://github.com/${RELEASE_REPO}/releases/tag/${latestTag}` } });
  const releases = new ReleaseWatch(memoryReleaseStore(), { fetch: latestPage });
  relay = createRelay({ limits: TEST_LIMITS, clock: () => now, checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, directory, log: LOG, releases });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  base = `ws://127.0.0.1:${relay.server.address().port}/v1/room/`;
  worldBase = `ws://127.0.0.1:${relay.server.address().port}/v1/world/`;
  directoryBase = `http://127.0.0.1:${relay.server.address().port}/v1/worlds`;
});

after(() => relay.stop());

/**
 * Makes a room id no other test uses.
 *
 * @param {number} number A number unique to the test.
 * @returns {string} A room id.
 */
function roomId(number) {
  return number.toString(16).padStart(32, "0");
}

/**
 * Connects a peer and collects what it receives.
 *
 * @param {string} room The room id.
 * @param {string} role "host" or "guest".
 * @returns {Promise<{socket: WebSocket, next: () => Promise<any>, closed: Promise<{code: number}>}>} The peer, its next message and its close.
 */
async function connect(room, role) {
  // Released games open PvP rooms without GAME.
  return open(`${base}${room}?role=${role}`, {});
}

/**
 * Makes a world in the directory, with the tests' auth key.
 *
 * @param {string} room The world's id.
 * @param {number} seats Its seats.
 * @returns {Promise<number>} The directory's HTTP status.
 */
async function makeWorld(room, seats) {
  const response = await gameFetch(directoryBase, {
    method: "POST",
    body: JSON.stringify({
      id: room,
      name: `World ${room.slice(-3)}`,
      seats,
      player: CREATOR,
      playerName: "Creator",
      authHash: await sha256Hex(AUTH),
      lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) },
    }),
  });
  return response.status;
}

/**
 * Makes a player key unique to a number.
 *
 * @param {number} number The number.
 * @returns {string} The key.
 */
function playerKey(number) {
  return number.toString(16).padStart(32, "a");
}

/**
 * Seats a game in a world room and collects what it receives.
 *
 * @param {string} room The world's id.
 * @param {number} player A number unique to the player.
 * @param {string} [auth] The auth key, the tests' own unless given.
 * @returns {Promise<{socket: WebSocket, next: () => Promise<any>, closed: Promise<{code: number}>}>} The game, its next message and its close.
 */
async function sit(room, player, auth = AUTH) {
  return open(`${worldBase}${room}?player=${playerKey(player)}&name=Player%20${player}&auth=${auth}`);
}

/**
 * Reads a world from the directory's list.
 *
 * @param {string} room The world's id.
 * @returns {Promise<object | undefined>} The world as everyone sees it.
 */
async function listed(room) {
  const { worlds } = await (await gameFetch(directoryBase)).json();
  return worlds.find((world) => world.id === room);
}

/**
 * Waits until a condition holds, looking every few milliseconds.
 *
 * @param {() => Promise<boolean>} condition The condition.
 * @returns {Promise<void>} Resolves once it holds.
 */
async function until(condition) {
  for (let tries = 0; tries < 100; tries++) {
    if (await condition()) {
      return;
    }

    await new Promise((resolve) => setTimeout(resolve, 10));
  }

  throw new Error("the condition never held");
}

/**
 * Opens a WebSocket and collects what it receives.
 *
 * @param {string} address The address.
 * @param {object} [headers] The request's headers, GAME unless given.
 * @returns {Promise<{socket: WebSocket, next: () => Promise<any>, closed: Promise<{code: number, reason: string}>}>} The socket, its next message and its close.
 */
async function open(address, headers = GAME) {
  const socket = new WebSocket(address, { headers });
  socket.binaryType = "arraybuffer";
  const inbox = [];
  const waiting = [];

  socket.addEventListener("message", (event) => (waiting.length > 0 ? waiting.shift()(event.data) : inbox.push(event.data)));
  const closed = new Promise((resolve) => socket.addEventListener("close", (event) => resolve({ code: event.code, reason: event.reason })));

  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  return {
    socket,
    closed,
    next: () => (inbox.length > 0 ? Promise.resolve(inbox.shift()) : new Promise((resolve) => waiting.push(resolve))),
  };
}

test("a host and a guest are told they are paired, and their binary messages pass both ways", async () => {
  const host = await connect(roomId(1), "host");
  const guest = await connect(roomId(1), "guest");

  assert.equal(await host.next(), PAIRED);
  assert.equal(await guest.next(), PAIRED);

  guest.socket.send(new Uint8Array([1, 2, 3]));
  assert.deepEqual([...new Uint8Array(await host.next())], [1, 2, 3]);

  host.socket.send(new Uint8Array([4, 5]));
  assert.deepEqual([...new Uint8Array(await guest.next())], [4, 5]);

  host.socket.close();
  guest.socket.close();
});

test("a second host is turned away before its WebSocket opens", async () => {
  const host = await connect(roomId(2), "host");

  await assert.rejects(connect(roomId(2), "host"));
  host.socket.close();
});

test("the guest is closed once the host leaves", async () => {
  const host = await connect(roomId(3), "host");
  const guest = await connect(roomId(3), "guest");

  host.socket.close();
  assert.equal((await guest.closed).code, CLOSE.peerLeft);
});

test("a keep-alive is answered, and other text closes the connection", async () => {
  const host = await connect(roomId(4), "host");

  host.socket.send("ping");
  assert.equal(await host.next(), PONG);

  host.socket.send("hello");
  assert.equal((await host.closed).code, CLOSE.badRequest);
});

test("a message over the size limit closes its sender", async () => {
  const host = await connect(roomId(5), "host");
  await connect(roomId(5), "guest");

  host.socket.send(new Uint8Array(TEST_LIMITS.maxMessageBytes + 1));
  assert.equal((await host.closed).code, CLOSE.tooLarge);
});

test("a host that waited alone too long is closed", async () => {
  const host = await connect(roomId(6), "host");

  now += TEST_LIMITS.aloneWaitMs;
  relay.check();
  assert.equal((await host.closed).code, CLOSE.waitedTooLong);
});

test("games in a world room get seats, each learns who comes and goes, and the directory knows who is online", async () => {
  assert.equal(await makeWorld(roomId(101), 4), 201);
  const first = await sit(roomId(101), 1);
  assert.equal(await first.next(), "seat 0");

  const second = await sit(roomId(101), 2);
  assert.equal(await second.next(), "seat 1 0");
  assert.equal(await first.next(), "in 1");

  const third = await sit(roomId(101), 3);
  assert.equal(await third.next(), "seat 2 0 1");

  await until(async () => (await listed(roomId(101))).online === 3);
  const secondId = await playerIdOf(playerKey(2));
  const members = (await listed(roomId(101))).members;
  const { seen, ...secondMember } = members.find((member) => member.id === secondId);
  assert.deepEqual(secondMember, { id: secondId, name: "Player 2", online: true });
  assert.equal(typeof seen, "number");

  second.socket.close();
  assert.equal(await first.next(), "in 2");
  assert.equal(await first.next(), "out 1");
  assert.equal(await third.next(), "out 1");
  await until(async () => (await listed(roomId(101))).online === 2);

  first.socket.close();
  third.socket.close();
});

test("a world message goes to every other game, or to the one seat it names, with the sender's seat in front", async () => {
  await makeWorld(roomId(102), 3);
  const games = [];

  for (let player = 0; player < 3; player++) {
    games.push(await sit(roomId(102), player));
  }

  await games[0].next();
  await games[0].next();
  await games[0].next();
  await games[1].next();
  await games[1].next();
  await games[2].next();

  games[2].socket.send(new Uint8Array([EVERYONE, 5, 6]));
  assert.deepEqual([...new Uint8Array(await games[0].next())], [2, 5, 6]);
  assert.deepEqual([...new Uint8Array(await games[1].next())], [2, 5, 6]);

  games[0].socket.send(new Uint8Array([1, 7]));
  assert.deepEqual([...new Uint8Array(await games[1].next())], [0, 7]);

  // Seat 2 got nothing meant for seat 1, so the next thing it hears is this broadcast.
  games[1].socket.send(new Uint8Array([EVERYONE, 8]));
  assert.deepEqual([...new Uint8Array(await games[2].next())], [1, 8]);

  for (const game of games) {
    game.socket.close();
  }
});

test("a full world room turns the next game away", async () => {
  await makeWorld(roomId(103), 2);
  const first = await sit(roomId(103), 1);
  const second = await sit(roomId(103), 2);

  await assert.rejects(sit(roomId(103), 3));
  first.socket.close();
  second.socket.close();
});

test("a world room turns away a game with the wrong auth key, and any game for a world the directory lacks", async () => {
  await makeWorld(roomId(104), 2);

  await assert.rejects(sit(roomId(104), 1, "cd".repeat(32)));
  await assert.rejects(sit(roomId(199), 1));
});

test("an empty world message closes its sender", async () => {
  await makeWorld(roomId(105), 2);
  const game = await sit(roomId(105), 1);
  await game.next();

  game.socket.send(new Uint8Array(0));
  assert.equal((await game.closed).code, CLOSE.badRequest);
});

test("a world connection that lasted too long is closed, and the others see its seat free", async () => {
  await makeWorld(roomId(106), 2);
  const first = await sit(roomId(106), 1);
  await first.next();
  now += 1000;
  const second = await sit(roomId(106), 2);
  await second.next();
  await first.next();

  now += TEST_LIMITS.worldConnectionMs - 1000;
  relay.check();
  assert.equal((await first.closed).code, CLOSE.connectionExpired);
  assert.equal(await second.next(), "out 0");
  second.socket.close();
});

test("a player the creator removes is closed and kept out, and deleting the world closes everyone", async () => {
  await makeWorld(roomId(107), 4);
  const guest = await sit(roomId(107), 5);
  const other = await sit(roomId(107), 6);
  await guest.next();
  await other.next();
  await guest.next();

  const post = (path, body) => gameFetch(`${directoryBase}/${roomId(107)}/${path}`, { method: "POST", body: JSON.stringify(body) });

  assert.equal((await post("ban", { player: playerKey(6), target: await playerIdOf(playerKey(5)) })).status, 403);
  assert.equal((await post("ban", { player: CREATOR, target: await playerIdOf(playerKey(5)) })).status, 200);
  assert.equal((await guest.closed).code, CLOSE.removed);
  await assert.rejects(sit(roomId(107), 5));

  assert.equal((await post("delete", { player: CREATOR })).status, 200);
  assert.equal((await other.closed).code, CLOSE.worldDeleted);
  assert.equal(await listed(roomId(107)), undefined);
});

test("a chat line a game sends as text is kept for the admins, an admin's line reaches every game, and other text still closes", async () => {
  await makeWorld(roomId(130), 4);
  const first = await sit(roomId(130), 7);
  const second = await sit(roomId(130), 8);
  await first.next();
  await second.next();
  await first.next();

  first.socket.send("chat  hello there ");
  const chat = (headers) => gameFetch(`${directoryBase}/${roomId(130)}/chat`, { headers });
  await until(async () => (await (await chat({ [PLAYER_HEADER]: CREATOR })).json()).lines.length === 1);
  const [mirrored] = (await (await chat({ [PLAYER_HEADER]: CREATOR })).json()).lines;
  assert.deepEqual([mirrored.n, mirrored.player, mirrored.name, mirrored.text, mirrored.admin], [1, await playerIdOf(playerKey(7)), "Player 7", "hello there", false]);
  assert.equal((await chat({ [PLAYER_HEADER]: playerKey(8) })).status, 403, "players read the chat in the game");

  const say = (headers, body) => gameFetch(`${directoryBase}/${roomId(130)}/chat`, { method: "POST", headers, body: JSON.stringify(body) });
  assert.equal((await say({ [PLAYER_HEADER]: CREATOR }, { text: "hi" })).status, 403);
  assert.equal((await say({ [PLAYER_HEADER]: ADMIN }, { text: "welcome, all", name: "Global" })).status, 200);
  assert.equal(await first.next(), "chat Global\twelcome, all");
  assert.equal(await second.next(), "chat Global\twelcome, all");
  assert.deepEqual((await (await chat({ [PLAYER_HEADER]: ADMIN, })).json()).lines.map((line) => [line.text, line.admin]), [["hello there", false], ["welcome, all", true]]);

  second.socket.send("something else");
  assert.equal((await second.closed).code, CLOSE.badRequest);
  first.socket.close();
});

test("a newer release of the mod reaches every game of a world with players online as the relay's chat line, once", async () => {
  await makeWorld(roomId(136), 4);
  const first = await sit(roomId(136), 7);
  const second = await sit(roomId(136), 8);
  await first.next();
  await second.next();
  await first.next();

  assert.deepEqual(await relay.checkRelease(), { version: null, worlds: 0 }, "the first release read is only kept");
  latestTag = "v0.6.5";
  const announced = await relay.checkRelease();
  assert.equal(announced.version, "0.6.5");
  const line = "chat MGQ Online	MGQ Online 0.6.5 is out. Restart the game and pick Multiplayer to update.";
  assert.equal(await first.next(), line);
  assert.equal(await second.next(), line);
  const lines = (await (await gameFetch(`${directoryBase}/${roomId(136)}/chat`, { headers: { [PLAYER_HEADER]: ADMIN } })).json()).lines;
  assert.deepEqual(lines.map((kept) => [kept.name, kept.admin]), [["MGQ Online", true]]);
  assert.deepEqual(await relay.checkRelease(), { version: null, worlds: 0 }, "the same release is announced once");

  // The world goes again, so it counts against neither the creator's worlds nor later tests.
  assert.equal((await gameFetch(`${directoryBase}/${roomId(136)}/delete`, { method: "POST", body: JSON.stringify({ player: CREATOR }) })).status, 200);
  await first.closed;
  await second.closed;
});

test("a game's chat lines past the chat's rate limit are dropped and answered, and an empty one is ignored", async () => {
  await makeWorld(roomId(131), 4);
  const game = await sit(roomId(131), 9);
  await game.next();

  game.socket.send("chat    ");

  for (let index = 0; index <= CHAT_LIMITS.burst; index++) {
    game.socket.send(`chat line ${index}`);
  }

  assert.equal(await game.next(), CHAT_SLOW, "the line past the burst is answered");
  const chat = async () => (await (await gameFetch(`${directoryBase}/${roomId(131)}/chat`, { headers: { [PLAYER_HEADER]: CREATOR } })).json()).lines;
  await until(async () => (await chat()).length === CHAT_LIMITS.burst);
  assert.deepEqual((await chat()).map((line) => line.text), Array.from({ length: CHAT_LIMITS.burst }, (_, index) => `line ${index}`), "the lines are kept in order, without the empty one");

  now += 1000;
  game.socket.send("chat later");
  await until(async () => (await chat()).length === CHAT_LIMITS.burst + 1);
  game.socket.send(PING);
  assert.equal(await game.next(), PONG, "the connection stays open");
  game.socket.close();
});

test("the directory hands out a world's lock and refuses what is no directory route", async () => {
  await makeWorld(roomId(108), 2);

  assert.deepEqual(await (await gameFetch(`${directoryBase}/${roomId(108)}/lock`)).json(), { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40), name: `World ${roomId(108).slice(-3)}`, seats: 2, start: "none", choose: false });
  assert.equal((await gameFetch(`${directoryBase}/${roomId(109)}/lock`)).status, 404);
  assert.equal((await gameFetch(`${directoryBase}/${roomId(108)}/elsewhere`)).status, 404);
  assert.equal((await gameFetch(directoryBase.replace("/v1/worlds", "/elsewhere"))).status, 400);
  assert.equal((await fetch(`${base.replace("ws:", "http:")}${roomId(108)}?role=host`)).status, 426, "a room's address needs its WebSocket");
});


test("the creator uploads a starting save as bytes, which the world's players fetch as they were", async () => {
  const room = roomId(110);
  const save = new Uint8Array(300_000).map((_, index) => index % 251);
  const response = await gameFetch(directoryBase, {
    method: "POST",
    body: JSON.stringify({
      id: room,
      name: "Started World",
      seats: 2,
      player: CREATOR,
      playerName: "Creator",
      authHash: await sha256Hex(AUTH),
      lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) },
      start: true,
    }),
  });
  assert.equal(response.status, 201);
  await assert.rejects(sit(room, 7));

  const uploaded = await gameFetch(`${directoryBase}/${room}/start?player=${CREATOR}`, { method: "POST", body: save });
  assert.equal(uploaded.status, 200);
  assert.equal((await listed(room)).start, "ready");

  const fetched = await gameFetch(`${directoryBase}/${room}/start?player=${playerKey(7)}&auth=${AUTH}`);
  assert.equal(fetched.status, 200);
  assert.deepEqual(new Uint8Array(await fetched.arrayBuffer()), save);
  assert.equal((await gameFetch(`${directoryBase}/${room}/start?player=${playerKey(7)}&auth=${"cd".repeat(32)}`)).status, 401);
});

test("two players of a world commit a trade over HTTP, which each finds again until done", async () => {
  const room = roomId(111);
  const trade = "7".repeat(32);
  const tradesBase = directoryBase.replace("/v1/worlds", "/v1/trades");
  await makeWorld(room, 4);
  const first = await sit(room, 21);
  const second = await sit(room, 22);
  await until(async () => (await listed(room)).online === 2);

  const commit = async (player, partner, sealed) => (await fetch(`${tradesBase}/${trade}/commit`, {
    method: "POST",
    headers: GAME,
    body: JSON.stringify({ player: playerKey(player), world: room, partner: await playerIdOf(playerKey(partner)), hash: "ab".repeat(32), sealed }),
  })).json();

  assert.deepEqual(await commit(21, 22, "A".repeat(60_000)), { state: "pending" });
  assert.deepEqual(await commit(22, 21, "Qg=="), { state: "committed" });
  assert.deepEqual(await (await fetch(`${tradesBase}/${trade}?player=${playerKey(21)}`, { headers: GAME })).json(), { state: "committed" });
  assert.deepEqual(await (await fetch(`${tradesBase}?player=${playerKey(22)}&world=${room}`, { headers: GAME })).json(), { trades: [{ id: trade, hash: "ab".repeat(32), sealed: "Qg==" }] });

  const done = await fetch(`${tradesBase}/${trade}/done`, { method: "POST", headers: GAME, body: JSON.stringify({ player: playerKey(22) }) });
  assert.equal(done.status, 200);
  assert.deepEqual(await (await fetch(`${tradesBase}?player=${playerKey(22)}&world=${room}`, { headers: GAME })).json(), { trades: [] });

  first.socket.close();
  second.socket.close();
});

/**
 * Opens a WebSocket with the ws client, which sends headers, and tells how the relay answered.
 *
 * @param {string} address The address.
 * @param {object} headers The request's headers.
 * @returns {Promise<{socket?: WebSocketClient, first?: Promise<string>, status?: number, refusal?: string}>} The open socket with its first message, or the refusal's status and REFUSAL_HEADER.
 */
function openWithHeaders(address, headers) {
  return new Promise((resolve) => {
    const socket = new WebSocketClient(address, { headers });
    const first = new Promise((received) => socket.once("message", (data) => received(data.toString())));

    socket.on("open", () => resolve({ socket, first }));
    socket.on("unexpected-response", (request, response) => {
      resolve({ status: response.statusCode, refusal: response.headers[REFUSAL_HEADER.toLowerCase()] });
      request.destroy();
    });
    socket.on("error", () => {});
  });
}

test("a guest that waited alone too long is closed too", async () => {
  const guest = await connect(roomId(7), "guest");

  now += TEST_LIMITS.aloneWaitMs;
  relay.check();
  assert.equal((await guest.closed).code, CLOSE.waitedTooLong);
});

test("keep-alives count against the message allowance", async () => {
  const host = await connect(roomId(8), "host");

  for (let sent = 0; sent <= TEST_LIMITS.burst; sent++) {
    host.socket.send(PING);
  }

  assert.equal((await host.closed).code, CLOSE.tooFast);
});

test("a room the relay ended takes new peers at once, whom the closed ones leave alone", async () => {
  const host = await connect(roomId(9), "host");
  const guest = await connect(roomId(9), "guest");
  await host.next();
  await guest.next();

  host.socket.send(new Uint8Array(TEST_LIMITS.maxMessageBytes + 1));
  const newHost = await connect(roomId(9), "host");
  const newGuest = await connect(roomId(9), "guest");

  assert.equal((await host.closed).code, CLOSE.tooLarge);
  assert.equal((await guest.closed).code, CLOSE.peerLeft);
  assert.equal(await newHost.next(), PAIRED);
  newGuest.socket.send(new Uint8Array([3]));
  await newGuest.next();
  assert.deepEqual([...new Uint8Array(await newHost.next())], [3]);

  newHost.socket.close();
  newGuest.socket.close();
});

test("a player who enters a world room again replaces the earlier connection, which gives up its seat", async () => {
  await makeWorld(roomId(112), 2);
  const first = await sit(roomId(112), 31);
  const other = await sit(roomId(112), 32);
  assert.equal(await first.next(), "seat 0");
  assert.equal(await other.next(), "seat 1 0");

  const again = await sit(roomId(112), 31);
  assert.deepEqual(await first.closed, { code: CLOSE.removed, reason: REPLACED });
  assert.equal(await again.next(), "seat 0 1");
  assert.equal(await other.next(), "out 0");
  assert.equal(await other.next(), "in 0");
  await until(async () => (await listed(roomId(112))).online === 2);

  again.socket.close();
  other.socket.close();
});

test("the player key may come in the X-MGQ-Player header, for the directory and the world rooms", async () => {
  const room = roomId(113);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: CREATOR },
    body: JSON.stringify({ id: room, name: "Header World", seats: 2, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 600_000, box: "ab".repeat(40) }, hidden: true }),
  });
  assert.equal(created.status, 201);

  const hidden = async (headers) => (await (await gameFetch(directoryBase, { headers })).json()).worlds.some((world) => world.id === room);
  assert.equal(await hidden({}), false);
  assert.equal(await hidden({ [PLAYER_HEADER]: CREATOR }), true);

  const game = await openWithHeaders(`${worldBase}${room}?name=Player%2042&auth=${AUTH}`, { ...GAME, [PLAYER_HEADER]: playerKey(42) });
  assert.equal(await game.first, "seat 0");
  await until(async () => (await (await gameFetch(directoryBase, { headers: { [PLAYER_HEADER]: CREATOR } })).json()).worlds.find((world) => world.id === room).online === 1);
  game.socket.close();
});

test("a world room names why it turned a game away", async () => {
  const room = roomId(114);
  await makeWorld(room, 4);
  await gameFetch(`${directoryBase}/${room}/ban`, { method: "POST", body: JSON.stringify({ player: CREATOR, target: await playerIdOf(playerKey(51)) }) });

  assert.deepEqual(await openWithHeaders(`${worldBase}${room}?player=${playerKey(51)}&name=Banned&auth=${AUTH}`, GAME), { status: 403, refusal: "removed" });
});

test("a world room lets into a Raid World only the games that name it in X-MGQ-Features", async () => {
  const room = roomId(123);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: CREATOR },
    body: JSON.stringify({ id: room, name: "Raid World", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, type: "raid", share: "story" }),
  });
  assert.equal(created.status, 201);
  assert.deepEqual([(await listed(room)).type, (await listed(room)).share], ["raid", "story"]);

  const address = `${worldBase}${room}?name=Player%2052&auth=${AUTH}`;
  assert.deepEqual(await openWithHeaders(address, { [PLAYER_HEADER]: playerKey(52), [FEATURES_HEADER]: "other" }), { status: 400, refusal: "raid_unsupported" });

  const game = await openWithHeaders(address, { [PLAYER_HEADER]: playerKey(52), [FEATURES_HEADER]: "raid" });
  assert.equal(await game.first, "seat 0");
  game.socket.close();
});

test("a Raid World's players write its story over HTTP, every game in the room hears of each change, and deleting the world forgets it", async () => {
  const room = roomId(124);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: CREATOR },
    body: JSON.stringify({ id: room, name: "Raid Story", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, type: "raid" }),
  });
  assert.equal(created.status, 201);
  const watcher = await openWithHeaders(`${worldBase}${room}?name=Watcher&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(54), [FEATURES_HEADER]: "raid" });
  assert.equal(await watcher.first, "seat 0");
  const heard = [];
  watcher.socket.on("message", (data) => heard.push(data.toString()));

  const story = (path, init = {}, key = playerKey(53), auth = AUTH) => gameFetch(`${directoryBase}/${room}/story${path}`, { ...init, headers: { ...GAME, [PLAYER_HEADER]: key, [AUTH_HEADER]: auth } });
  const write = (body) => story("", { method: "POST", body: JSON.stringify(body) });
  const counters = (p) => ({ p, r1141: 0, r1142: 0, r1143: 0, clear: [] });

  assert.equal((await story("")).status, 200);
  assert.equal((await story("", {}, playerKey(53), "cd".repeat(32))).status, 401);
  assert.equal((await story("", {}, "zz")).status, 400);

  const first = await write({ base: 0, counters: counters(18), blob: "QUJD" });
  assert.equal(first.status, 200);
  assert.equal((await first.json()).rev, 1);
  await until(async () => heard.includes("story 1"));

  const second = await write({ base: 1, counters: { ...counters(19), end: { map: 2, x: 148, y: 243 } }, blob: "REVG" });
  assert.deepEqual(await second.json().then((body) => [body.rev, body.part, body.checkpoints, body.end]), [2, "2", ["1"], { map: 2, x: 148, y: 243 }]);

  const conflict = await write({ base: 1, counters: counters(20), blob: "R0hJ" });
  assert.equal(conflict.status, 409);
  assert.deepEqual(await conflict.json().then((body) => [body.code, body.rev, body.blob]), ["rev", 2, "REVG"]);

  const checkpoint = await (await story("/checkpoint/1")).json();
  assert.deepEqual([checkpoint.part, checkpoint.p, checkpoint.blob], ["1", 18, "QUJD"]);
  assert.equal((await story("/route", { method: "POST", body: JSON.stringify({ route: "mr" }) })).status, 200);
  assert.deepEqual((await (await story("/companions", { method: "POST", body: JSON.stringify({ ids: [382] }) })).json()).comps, [382]);
  await until(async () => heard.includes("story 4"));
  assert.equal((await write({ base: 2, counters: { ...counters(40), r1142: 1 }, blob: "R0hJ" })).status, 200, "a write on the last sealed story is taken after a lock and a companion");
  assert.equal((await story("", { method: "POST", body: "x".repeat(STORY_LIMITS.maxBodyLength + 10) })).status, 413);

  await gameFetch(`${directoryBase}/${room}/ban`, { method: "POST", body: JSON.stringify({ player: CREATOR, target: await playerIdOf(playerKey(55)) }) });
  assert.equal((await story("", {}, playerKey(55))).status, 403);

  assert.equal((await gameFetch(`${directoryBase}/${room}/delete`, { method: "POST", body: JSON.stringify({ player: CREATOR }) })).status, 200);
  assert.equal((await story("")).status, 404);
  assert.equal((await relay.storyOf(room).get()).body.rev, 0, "the deleted world's story is gone");
});

test("a keyed Raid World's games hear what each write changed, and games that keep the story sealed are sent to update", async () => {
  const room = roomId(190);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: playerKey(65) },
    body: JSON.stringify({ id: room, name: "Raid Keys", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, type: "raid" }),
  });
  assert.equal(created.status, 201);
  const keys = { [FEATURES_HEADER]: "raid,keys" };
  const watcher = await openWithHeaders(`${worldBase}${room}?name=Watcher&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(61), ...keys });
  assert.equal(await watcher.first, "seat 0");
  const heard = [];
  watcher.socket.on("message", (data) => heard.push(data.toString()));
  const story = (path, init = {}, features = keys) => gameFetch(`${directoryBase}/${room}/story${path}`, { ...init, headers: { ...GAME, ...features, [PLAYER_HEADER]: playerKey(62), [AUTH_HEADER]: AUTH } });
  const counters = { p: 18, r1141: 0, r1142: 0, r1143: 0, clear: [] };

  const written = await story("", { method: "POST", body: JSON.stringify({ base: 0, counters, set: { s: "5", v: "1001:n18" } }) });
  assert.equal(written.status, 200);
  await until(async () => heard.some((text) => text.startsWith("storyd ")));
  const push = JSON.parse(heard.find((text) => text.startsWith("storyd ")).slice(7));
  assert.deepEqual([push.rev, push.prev, push.delta.s, push.delta.v, push.state.p], [1, 0, "5", "1001:n18", 18]);
  assert.deepEqual(await (await story("?known=1")).json().then((body) => [body.same, body.keys]), [true, undefined]);
  assert.equal(await (await story("")).json().then((body) => body.keys.v), "1001:n18");

  assert.equal((await story("", {}, { [FEATURES_HEADER]: "raid" })).status, 426, "a game that keeps the story sealed reads none of it");
  assert.deepEqual(await openWithHeaders(`${worldBase}${room}?name=Old&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(63), [FEATURES_HEADER]: "raid" }), { status: 400, refusal: "update" });
  const newer = await openWithHeaders(`${worldBase}${room}?name=New&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(64), ...keys });
  assert.equal(await newer.first, "seat 1 0");
  watcher.socket.close();
  newer.socket.close();
});

test("a story write whose body comes after the world was deleted leaves no story behind", async () => {
  const room = roomId(132);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: CREATOR },
    body: JSON.stringify({ id: room, name: "Raid Gone", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, type: "raid" }),
  });
  assert.equal(created.status, 201);

  const body = JSON.stringify({ base: 0, counters: { p: 18, r1141: 0, r1142: 0, r1143: 0, clear: [] }, blob: "QUJD" });
  const answered = new Promise((resolve, reject) => {
    const request = http.request(`${directoryBase}/${room}/story`, { method: "POST", headers: { ...GAME, [PLAYER_HEADER]: playerKey(60), [AUTH_HEADER]: AUTH, "Content-Length": Buffer.byteLength(body) } }, (response) => {
      response.resume();
      response.on("end", () => resolve(response.statusCode));
    });
    request.on("error", reject);
    request.write(body.slice(0, 10));
    // The member check passes while the body is still on its way; the world goes before the rest.
    setTimeout(async () => {
      const deleted = await gameFetch(`${directoryBase}/${room}/delete`, { method: "POST", body: JSON.stringify({ player: CREATOR }) });
      assert.equal(deleted.status, 200);
      request.end(body.slice(10));
    }, 50);
  });

  assert.equal(await answered, 200);
  assert.equal((await relay.storyOf(room).get()).body.rev, 0, "the late write is removed again");
});

test("a Classic world keeps no story", async () => {
  await makeWorld(roomId(125), 4);
  const answer = await gameFetch(`${directoryBase}/${roomId(125)}/story`, { headers: { ...GAME, [PLAYER_HEADER]: playerKey(56), [AUTH_HEADER]: AUTH } });
  assert.equal(answer.status, 404);
  assert.equal((await answer.json()).code, "classic");
});

test("a Raid World's players wear its boss pools down over HTTP, every game hears each change, admins set them right, and deleting the world forgets them", async () => {
  const room = roomId(126);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: CREATOR },
    body: JSON.stringify({ id: room, name: "Raid Bosses", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, type: "raid" }),
  });
  assert.equal(created.status, 201);
  const watcher = await openWithHeaders(`${worldBase}${room}?name=Watcher&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(57), [FEATURES_HEADER]: "raid" });
  assert.equal(await watcher.first, "seat 0");
  const heard = [];
  watcher.socket.on("message", (data) => heard.push(data.toString()));

  const bosses = (path, init = {}, key = playerKey(58), auth = AUTH) => gameFetch(`${directoryBase}/${room}/bosses${path}`, { ...init, headers: { ...GAME, [PLAYER_HEADER]: key, [AUTH_HEADER]: auth } });
  const report = (key, body, player = playerKey(58)) => bosses(`/${encodeURIComponent(key)}/report`, { method: "POST", body: JSON.stringify(body) }, player);

  assert.deepEqual(await (await bosses("")).json(), { bosses: [], regenPerMinute: 0.03 });
  assert.equal((await bosses("", {}, playerKey(58), "cd".repeat(32))).status, 401);

  const first = await report("Queen Harpy#1", { battle: "b1", seq: 1, delta: 0.25, max: 5_000_000, killed: false });
  const firstBody = await first.json();
  assert.deepEqual([firstBody.boss.key, firstBody.boss.left, firstBody.boss.max, firstBody.boss.defeated, firstBody.repeat], ["Queen Harpy#1", 0.75, 5_000_000, false, false]);
  await until(async () => heard.includes("boss 0.75 5000000 0 Queen Harpy#1"));
  assert.equal((await (await bosses("/Queen%20Harpy%231")).json()).max, 5_000_000);
  assert.equal((await report("Queen Harpy#1", { battle: "b1", seq: 1, delta: 0.25, max: 5_000_000 }).then((answer) => answer.json())).repeat, true);
  assert.equal((await report("Queen Harpy#1", { battle: "b1", dealt: 0.25 })).status, 400, "a report in kills is refused");
  assert.equal((await bosses("/Queen%20Harpy%231/report", { method: "POST", body: "x".repeat(BOSS_LIMITS.maxBodyLength + 10) })).status, 413);

  const killed = await report("Lilith", { battle: "b3", seq: 1, delta: 0, max: 900, killed: true }, playerKey(57));
  assert.deepEqual(await killed.json().then((body) => [body.boss.defeated, body.boss.by]), [true, "Watcher"]);
  await until(async () => heard.includes("boss 0 900 1 Lilith"));

  const admin = (path, init = {}) => gameFetch(`${directoryBase}/${room}/raid${path}`, init);
  assert.equal((await admin(`?player=${CREATOR}`)).status, 403, "the creator is no admin");
  const view = await (await admin(`?player=${ADMIN}`)).json();
  assert.deepEqual([view.story.rev, view.bosses.map((pool) => [pool.key, pool.hp, pool.max, pool.defeated, pool.by, pool.reports]), view.regenPerMinute],
    [0, [["Lilith", 0, 900, true, "Watcher", 1], ["Queen Harpy#1", 3_750_000, 5_000_000, false, null, 1]], 0.03]);

  const reset = await admin("/bosses/Lilith/reset", { method: "POST", body: JSON.stringify({ player: ADMIN }) });
  assert.deepEqual(await reset.json().then((body) => [body.left, body.reset]), [1, true]);
  await until(async () => heard.includes("boss 1 900 0 Lilith"));

  const story = (path, init = {}) => gameFetch(`${directoryBase}/${room}/story${path}`, { ...init, headers: { ...GAME, [PLAYER_HEADER]: playerKey(58), [AUTH_HEADER]: AUTH } });
  assert.equal((await story("/route", { method: "POST", body: JSON.stringify({ route: "ad" }) })).status, 200);
  const cleared = await admin("/route/clear", { method: "POST", headers: { [PLAYER_HEADER]: ADMIN }, body: "{}" });
  assert.deepEqual(await cleared.json().then((body) => [body.cleared, body.route, body.rev]), [true, "none", 2]);
  await until(async () => heard.includes("story 2"));

  await report("Morrigan", { battle: "b2", seq: 1, delta: 0.5, max: 900 });
  assert.equal((await gameFetch(`${directoryBase}/${room}/delete`, { method: "POST", body: JSON.stringify({ player: CREATOR }) })).status, 200);
  assert.equal((await bosses("")).status, 404);
  assert.deepEqual((await relay.bossesOf(room).list()).body.bosses, [], "the deleted world's pools are gone");
});

test("a Classic world keeps no boss pools and has no admin routes", async () => {
  await makeWorld(roomId(127), 4);
  const answer = await gameFetch(`${directoryBase}/${roomId(127)}/bosses`, { headers: { ...GAME, [PLAYER_HEADER]: playerKey(59), [AUTH_HEADER]: AUTH } });
  assert.deepEqual([answer.status, (await answer.json()).code], [404, "classic"]);
  const admin = await gameFetch(`${directoryBase}/${roomId(127)}/raid?player=${ADMIN}`);
  assert.deepEqual([admin.status, (await admin.json()).code], [404, "classic"]);
  assert.equal((await gameFetch(`${directoryBase}/${roomId(128)}/raid?player=${ADMIN}`)).status, 404);
  // Deleted, so the creator stays below the worlds a creator may have for the tests after this one.
  assert.equal((await gameFetch(`${directoryBase}/${roomId(127)}/delete`, { method: "POST", body: JSON.stringify({ player: CREATOR }) })).status, 200);
});

test("a starting save over the limit is refused with its status, not a cut connection", async () => {
  const room = roomId(115);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    body: JSON.stringify({ id: room, name: "Big Save", seats: 2, player: CREATOR, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, start: true }),
  });
  assert.equal(created.status, 201);

  const uploaded = await gameFetch(`${directoryBase}/${room}/start`, { method: "POST", headers: { [PLAYER_HEADER]: CREATOR }, body: new Uint8Array(TEST_DIRECTORY_LIMITS.maxStartBytes + 100_000) });
  assert.equal(uploaded.status, 413);
});

test("entering rooms and making worlds are limited per address", async () => {
  const once = { burst: 1, refillMs: 3_600_000 };
  const directory = new Directory(memoryStore(), { clock: () => now, rates: { joins: once, creates: once, starts: once } });
  const limited = createRelay({ limits: TEST_LIMITS, clock: () => now, checkEveryMs: 3_600_000, directory, log: LOG });
  await new Promise((resolve) => limited.server.listen(0, "127.0.0.1", resolve));
  const port = limited.server.address().port;

  const host = await open(`ws://127.0.0.1:${port}/v1/room/${roomId(10)}?role=host`);
  assert.equal((await openWithHeaders(`ws://127.0.0.1:${port}/v1/room/${roomId(11)}?role=host`, {})).status, 429);

  const world = (id) => JSON.stringify({ id, name: "Limited", seats: 2, player: CREATOR, playerName: "Creator", authHash: "ab".repeat(32), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) } });
  assert.equal((await gameFetch(`http://127.0.0.1:${port}/v1/worlds`, { method: "POST", body: world(roomId(116)) })).status, 201);
  const refused = await gameFetch(`http://127.0.0.1:${port}/v1/worlds`, { method: "POST", body: world(roomId(117)) });
  assert.deepEqual([refused.status, (await refused.json()).code], [429, "rate"]);

  host.socket.close();
  await limited.stop();
});

test("the auth key may come in the X-MGQ-Auth header, for the world rooms and the starting save", async () => {
  const room = roomId(118);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    body: JSON.stringify({ id: room, name: "Auth World", seats: 2, player: CREATOR, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, start: true }),
  });
  assert.equal(created.status, 201);
  assert.equal((await gameFetch(`${directoryBase}/${room}/start`, { method: "POST", headers: { [PLAYER_HEADER]: CREATOR }, body: Uint8Array.of(4, 2) })).status, 200);

  const headers = { ...GAME, [PLAYER_HEADER]: playerKey(61), [AUTH_HEADER]: AUTH };
  const fetched = await gameFetch(`${directoryBase}/${room}/start`, { headers });
  assert.equal(fetched.status, 200);
  assert.deepEqual(new Uint8Array(await fetched.arrayBuffer()), Uint8Array.of(4, 2));
  assert.equal((await gameFetch(`${directoryBase}/${room}/start?auth=${AUTH}`, { headers: { [PLAYER_HEADER]: playerKey(61), [AUTH_HEADER]: "cd".repeat(32) } })).status, 401, "the header wins over the address");
  assert.equal((await gameFetch(`${directoryBase}/${room}/start?player=${playerKey(61)}&auth=${AUTH}`)).status, 200, "released games send both in the address");

  const game = await openWithHeaders(`${worldBase}${room}?name=Player%2061`, headers);
  assert.equal(await game.first, "seat 0");
  assert.deepEqual(await openWithHeaders(`${worldBase}${room}?name=Player%2062&auth=${AUTH}`, { ...GAME, [PLAYER_HEADER]: playerKey(62), [AUTH_HEADER]: "cd".repeat(32) }), { status: 401, refusal: undefined });
  game.socket.close();
});

test("a game makes a Raid World with a starting save over HTTP and uploads it", async () => {
  const room = roomId(135);
  const creator = playerKey(95);
  const world = JSON.stringify({ id: room, name: "Saved Raid", seats: 4, player: creator, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, start: true, type: "raid" });

  assert.equal((await gameFetch(directoryBase, { method: "POST", body: world })).status, 201);
  assert.equal((await gameFetch(`${directoryBase}/${room}/start`, { method: "POST", headers: { [PLAYER_HEADER]: creator }, body: Uint8Array.of(9) })).status, 200);
});

test("a game without X-MGQ-Features, or naming a version below the lowest, is turned away, while PvP rooms need no features", async () => {
  const room = roomId(132);
  await makeWorld(room, 4);
  const world = (headers) => openWithHeaders(`${worldBase}${room}?name=Old&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(80), ...headers });
  const update = { status: 426, refusal: UPDATE_NEEDED };
  const worldUpdate = { status: 400, refusal: "update" };

  assert.deepEqual(await world({}), worldUpdate, "a game before 0.6.0 stops at a 400 with a code it does not know");
  assert.deepEqual(await world({ ...GAME, [VERSION_HEADER]: "0.5.9+abc" }), worldUpdate);
  const current = await world({ ...GAME, [VERSION_HEADER]: "0.6.0+abc" });
  assert.equal(await current.first, "seat 0");
  current.socket.close();

  assert.deepEqual(await openWithHeaders(`${base}${roomId(12)}?role=host`, { [VERSION_HEADER]: "0.5.3" }), update, "a PvP room holds a named version against the lowest");
  const host = await openWithHeaders(`${base}${roomId(12)}?role=host`, {});
  assert.ok(host.socket, "a PvP room takes a game that names no features, as released games open them");
  host.socket.close();

  const trades = directoryBase.replace("/v1/worlds", "/v1/trades");
  const listing = await fetch(`${trades}?player=${playerKey(80)}&world=${room}`);
  assert.deepEqual([listing.status, await listing.json()], [426, { error: UPDATE_NEEDED }]);
  const posted = await fetch(`${trades}/${"9".repeat(32)}/commit`, { method: "POST", body: "x".repeat(300 * 1024) });
  assert.deepEqual([posted.status, await posted.json()], [426, { error: UPDATE_NEEDED }], "the refusal comes once the body is drained");

  const mods = directoryBase.replace("/v1/worlds", "/v1/mods");
  assert.deepEqual([(await fetch(directoryBase)).status, (await fetch(mods)).status], [426, 426], "a game before 0.6.0 or an older World Admin tool build");
  assert.equal((await fetch(`${directoryBase}/${room}/raid?player=${ADMIN}`, { headers: { [VERSION_HEADER]: "0.0.0-dev" } })).status, 426, "the Raid World admin routes ask for X-MGQ-Features too");
  assert.deepEqual([(await gameFetch(directoryBase)).status, (await gameFetch(mods)).status], [200, 200]);
  assert.equal((await fetch(`${directoryBase}/${room}/raid?player=${ADMIN}`, { headers: ADMIN_TOOL })).status, 404, "the World Admin tool passes");
  // Deleted, so the creator stays below the worlds a creator may have for the tests after this one.
  assert.equal((await gameFetch(`${directoryBase}/${room}/delete`, { method: "POST", body: JSON.stringify({ player: CREATOR }) })).status, 200);
});

test("the MIN_VERSION setting raises the lowest version a game may name, which only the development stamp passes, and a game naming none counts as 0.6.4", async () => {
  const gated = createRelay({ clock: () => now, checkEveryMs: 3_600_000, log: LOG, minVersion: "0.7.0" });
  await new Promise((resolve) => gated.server.listen(0, "127.0.0.1", resolve));
  const at = `127.0.0.1:${gated.server.address().port}`;
  const trades = `http://${at}/v1/trades?player=${playerKey(81)}&world=${roomId(133)}`;
  const status = async (address, headers) => (await fetch(address, { headers })).status;

  try {
    assert.deepEqual(
      await Promise.all(["0.6.9", "no version", "0.6.9-dev", "0.7.0+abc", "0.7.0-beta", "0.0.0-dev", "0.0.0-dev+abc"].map((version) => status(trades, { ...GAME, [VERSION_HEADER]: version }))),
      [426, 426, 426, 200, 200, 200, 200],
    );
    assert.equal(await status(trades, GAME), 426, "a game naming no version counts as 0.6.4");
    assert.deepEqual([await status(`http://${at}/v1/worlds`, {}), await status(`http://${at}/v1/mods`, {}), await status(`http://${at}/v1/worlds`, { [VERSION_HEADER]: "0.6.9" })], [426, 426, 426], "the world directory and the mod catalog too");
    assert.deepEqual([await status(`http://${at}/v1/worlds`, ADMIN_TOOL), await status(`http://${at}/v1/mods`, ADMIN_TOOL)], [200, 200], "the World Admin tool names 0.0.0-dev");
    assert.deepEqual([await status(`http://${at}/v1/worlds`, { ...GAME, [VERSION_HEADER]: "0.7.0" }), await status(`http://${at}/v1/mods`, { ...GAME, [VERSION_HEADER]: "0.7.1" })], [200, 200]);
    assert.deepEqual([await status(`http://${at}/v1/worlds`, { [VERSION_HEADER]: "0.7.0" }), await status(`http://${at}/v1/mods`, { [VERSION_HEADER]: "0.7.1" })], [426, 426], "they ask for X-MGQ-Features too");
    assert.deepEqual(await openWithHeaders(`ws://${at}/v1/room/${roomId(134)}?role=host`, {}), { status: 426, refusal: UPDATE_NEEDED }, "a released game's PvP room");
    assert.deepEqual(await openWithHeaders(`ws://${at}/v1/world/${roomId(133)}?name=Old&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(81), ...GAME }), { status: 400, refusal: "update" }, "a released game's world room");
  } finally {
    await gated.stop();
  }

  const released = createRelay({ clock: () => now, checkEveryMs: 3_600_000, log: LOG, minVersion: "0.6.4" });
  await new Promise((resolve) => released.server.listen(0, "127.0.0.1", resolve));
  const open = `127.0.0.1:${released.server.address().port}`;

  try {
    assert.deepEqual(
      [await status(`http://${open}/v1/trades?player=${playerKey(81)}&world=${roomId(133)}`, GAME), await status(`http://${open}/v1/worlds`, GAME), await status(`http://${open}/v1/mods`, GAME), await status(`http://${open}/v1/worlds`, {})],
      [200, 200, 200, 426],
      "released games naming no version pass while the lowest is at most 0.6.4, and a request without X-MGQ-Features stays refused",
    );
    const host = await openWithHeaders(`ws://${open}/v1/room/${roomId(135)}?role=host`, {});
    assert.ok(host.socket, "a released game's PvP room");
    host.socket.close();
  } finally {
    await released.stop();
  }
});

test("every request is logged as one line without its query, and a caught error with its stack", async () => {
  const before = logged.info.length;
  await gameFetch(`${directoryBase}?player=${CREATOR}`);
  await gameFetch(`${directoryBase}/${roomId(119)}/lock`);
  const lines = logged.info.slice(before);

  assert.equal(lines.length, 2);
  assert.match(lines[0], /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z GET \/v1\/worlds 200 \d+ms 127\.0\.0\.1$/);
  assert.match(lines[1], /^\S+ GET \/v1\/worlds\/[0-9a-f]{32}\/lock 404 \d+ms 127\.0\.0\.1$/);
  assert.ok(!lines.some((line) => line.includes(CREATOR)), "a key in the address stays out of the log");
  assert.ok(logged.info.some((line) => / GET \/v1\/room\/[0-9a-f]{32} 101 /.test(line)), "an opened WebSocket is logged as 101");
  assert.ok(logged.info.some((line) => / GET \/v1\/world\/[0-9a-f]{32} 403 /.test(line)), "a refused WebSocket is logged with its status");

  assert.equal(requestLine(new Date(0), "POST", "/v1/mods", 413, 2.6, null), "1970-01-01T00:00:00.000Z POST /v1/mods 413 3ms -");
  const line = errorLine(new Date(0), "sweep", new Error("the store failed"));
  assert.match(line, /^1970-01-01T00:00:00\.000Z error sweep: Error: the store failed\n\s+at /);
  assert.equal(errorLine(new Date(0), "sweep", "plain"), "1970-01-01T00:00:00.000Z error sweep: plain");
});

test("an error while answering is logged with its stack and answered with 500", async () => {
  const broken = new Directory({ ...memoryStore(), all: async () => { throw new Error("the disk is gone"); } }, { clock: () => now });
  const relayOfBroken = createRelay({ clock: () => now, checkEveryMs: 3_600_000, directory: broken, log: LOG });
  await new Promise((resolve) => relayOfBroken.server.listen(0, "127.0.0.1", resolve));
  const port = relayOfBroken.server.address().port;

  const answer = await gameFetch(`http://127.0.0.1:${port}/v1/worlds`);
  assert.equal(answer.status, 500);
  assert.deepEqual(await answer.json(), { error: "the directory failed" });
  assert.match(logged.error.at(-1), /^\S+ error GET \/v1\/worlds: Error: the disk is gone\n\s+at /);
  assert.match(logged.info.at(-1), / GET \/v1\/worlds 500 /);
  await relayOfBroken.stop();
});

test("the sweep deletes worlds whose starting save never came and trades kept long enough", async () => {
  const room = roomId(120);
  const trade = "8".repeat(32);
  const tradesBase = directoryBase.replace("/v1/worlds", "/v1/trades");
  await makeWorld(room, 4);
  const game = await sit(room, 71);
  await until(async () => (await listed(room)).online === 1);
  const commit = await fetch(`${tradesBase}/${trade}/commit`, {
    method: "POST",
    headers: GAME,
    body: JSON.stringify({ player: playerKey(71), world: room, partner: await playerIdOf(CREATOR), hash: "ab".repeat(32), sealed: "Qg==" }),
  });
  assert.deepEqual(await commit.json(), { state: "pending" });

  const pending = roomId(121);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    body: JSON.stringify({ id: pending, name: "Never Started", seats: 2, player: CREATOR, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, start: true }),
  });
  assert.equal(created.status, 201);

  now += DIRECTORY_LIMITS.pendingMs;
  await relay.sweep();
  assert.equal(await relay.directory.store.get(pending), undefined);
  assert.equal((await relay.trades.store.getTrade(trade)).state, "cancelled");
  assert.equal(await relay.trades.store.getSealed(trade, await playerIdOf(playerKey(71))), undefined, "a cancelled trade keeps no offers");

  now += TRADE_LIMITS.keepCancelledMs;
  await relay.sweep();
  assert.equal(await relay.trades.store.getTrade(trade), undefined);
  game.socket.close();
});

test("every game of a Raid World hears its new difficulty once its creator changes it over HTTP", async () => {
  const room = roomId(133);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: CREATOR },
    body: JSON.stringify({ id: room, name: "Raid Difficulty", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, type: "raid", difficulty: 1 }),
  });
  assert.equal(created.status, 201);
  assert.equal((await listed(room)).difficulty, 1);
  const watcher = await openWithHeaders(`${worldBase}${room}?name=Watcher&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(72), [FEATURES_HEADER]: "raid" });
  assert.equal(await watcher.first, "seat 0");
  const heard = [];
  watcher.socket.on("message", (data) => heard.push(data.toString()));

  const edit = await gameFetch(`${directoryBase}/${room}/edit`, { method: "POST", headers: { [PLAYER_HEADER]: CREATOR }, body: JSON.stringify({ seats: 4, difficulty: 3 }) });
  assert.equal(edit.status, 200);
  assert.deepEqual(await edit.json(), { edited: room }, "the answer names no difficulty");
  await until(async () => heard.includes("difficulty 3"));
  assert.equal((await listed(room)).difficulty, 3);

  await gameFetch(`${directoryBase}/${room}/edit`, { method: "POST", headers: { [PLAYER_HEADER]: CREATOR }, body: JSON.stringify({ seats: 6 }) });
  assert.deepEqual(heard.filter((text) => text.startsWith("difficulty")), ["difficulty 3"], "an edit without a difficulty tells none");
  watcher.socket.close();
});

test("every game of a Raid World hears its new squad settings once its creator changes them over HTTP", async () => {
  const room = roomId(137);
  // Its own creator, since CREATOR already made as many worlds as a player may.
  const creator = playerKey(96);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: creator },
    body: JSON.stringify({ id: room, name: "Raid Squad", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, type: "raid", squad: { luka: false, formation: 4, front: 1, raidFront: 1 } }),
  });
  assert.equal(created.status, 201);
  assert.deepEqual((await listed(room)).squad, { luka: false, formation: 4, front: 1, raidFront: 1 });
  const watcher = await openWithHeaders(`${worldBase}${room}?name=Watcher&auth=${AUTH}`, { [PLAYER_HEADER]: playerKey(97), [FEATURES_HEADER]: "raid" });
  assert.equal(await watcher.first, "seat 0");
  const heard = [];
  watcher.socket.on("message", (data) => heard.push(data.toString()));

  const edit = await gameFetch(`${directoryBase}/${room}/edit`, { method: "POST", headers: { [PLAYER_HEADER]: creator }, body: JSON.stringify({ squad: { luka: true, formation: 6, front: 2, raidFront: 1 } }) });
  assert.equal(edit.status, 200);
  assert.deepEqual(await edit.json(), { edited: room }, "the answer names no squad settings");
  await until(async () => heard.includes("squad 1 6 2 1"));
  assert.deepEqual((await listed(room)).squad, { luka: true, formation: 6, front: 2, raidFront: 1 });

  await gameFetch(`${directoryBase}/${room}/edit`, { method: "POST", headers: { [PLAYER_HEADER]: creator }, body: JSON.stringify({ seats: 6, squad: { luka: true, formation: 6, front: 2, raidFront: 1 } }) });
  assert.deepEqual(heard.filter((text) => text.startsWith("squad")), ["squad 1 6 2 1"], "an edit with the same squad settings tells none");
  watcher.socket.close();
});

test("every game of a Classic world hears whether it fights raid bosses once its creator changes it over HTTP", async () => {
  const room = roomId(138);
  // Its own creator, since CREATOR already made as many worlds as a player may.
  const creator = playerKey(98);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: creator },
    body: JSON.stringify({ id: room, name: "Raid Bosses", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) } }),
  });
  assert.equal(created.status, 201);
  assert.equal((await listed(room)).raidBosses, false);
  const watcher = await openWithHeaders(`${worldBase}${room}?name=Watcher&auth=${AUTH}`, { ...GAME, [PLAYER_HEADER]: playerKey(99) });
  assert.equal(await watcher.first, "seat 0");
  const heard = [];
  watcher.socket.on("message", (data) => heard.push(data.toString()));
  const edit = (body) => gameFetch(`${directoryBase}/${room}/edit`, { method: "POST", headers: { [PLAYER_HEADER]: creator }, body: JSON.stringify(body) });

  const on = await edit({ raidBosses: true });
  assert.equal(on.status, 200);
  assert.deepEqual(await on.json(), { edited: room }, "the answer names no raid bosses");
  await until(async () => heard.includes("raid_bosses 1"));
  assert.equal((await listed(room)).raidBosses, true);

  await edit({ seats: 6, raidBosses: true });
  await edit({ raidBosses: false });
  await until(async () => heard.includes("raid_bosses 0"));
  assert.deepEqual(heard.filter((text) => text.startsWith("raid_bosses")), ["raid_bosses 1", "raid_bosses 0"], "an edit with the same value tells none");
  watcher.socket.close();
});

test("every game of a world hears that it turns other mods off, with its mods, once its creator changes either over HTTP", async () => {
  const room = roomId(134);
  // Its own creator, since CREATOR already made as many worlds as a player may.
  const creator = playerKey(74);
  const created = await gameFetch(directoryBase, {
    method: "POST",
    headers: { [PLAYER_HEADER]: creator },
    body: JSON.stringify({ id: room, name: "Mods Rule", seats: 4, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) } }),
  });
  assert.equal(created.status, 201);
  assert.equal((await listed(room)).otherModsOff, false);
  const watcher = await openWithHeaders(`${worldBase}${room}?name=Watcher&auth=${AUTH}`, { ...GAME, [PLAYER_HEADER]: playerKey(73) });
  assert.equal(await watcher.first, "seat 0");
  const heard = [];
  watcher.socket.on("message", (data) => heard.push(data.toString()));
  const edit = (body) => gameFetch(`${directoryBase}/${room}/edit`, { method: "POST", headers: { [PLAYER_HEADER]: creator }, body: JSON.stringify(body) });

  const on = await edit({ otherModsOff: true, mods: "!Level Cap" });
  assert.equal(on.status, 200);
  assert.deepEqual(await on.json(), { edited: room }, "the answer names no rule");
  await until(async () => heard.includes("mods_rule 1\t!Level Cap"));
  assert.equal((await listed(room)).otherModsOff, true);

  await edit({ seats: 6, otherModsOff: true });
  await edit({ mods: "!Level Cap;Party Sheet" });
  await until(async () => heard.includes("mods_rule 1\t!Level Cap;Party Sheet"));
  assert.deepEqual(heard.filter((text) => text.startsWith("mods_rule")), ["mods_rule 1\t!Level Cap", "mods_rule 1\t!Level Cap;Party Sheet"], "an edit that changes neither tells none");
  watcher.socket.close();
});

test("the creator or an admin edits a world over HTTP", async () => {
  const room = roomId(122);
  await makeWorld(room, 4);
  const edit = (headers, body) => gameFetch(`${directoryBase}/${room}/edit`, { method: "POST", headers, body: JSON.stringify(body) });

  assert.equal((await edit({ [PLAYER_HEADER]: playerKey(81) }, { seats: 8 })).status, 403);
  assert.equal((await edit({ [PLAYER_HEADER]: CREATOR }, { seats: 99 })).status, 400);
  assert.equal((await edit({ [PLAYER_HEADER]: CREATOR }, { seats: 8, description: "  A world\nof two lines  ", mods: "!Level Cap" })).status, 200);
  assert.equal((await edit({}, { player: CREATOR, data: "1:abc" })).status, 200, "released games send the key in the body");

  const world = await listed(room);
  assert.deepEqual([world.seats, world.description, world.mods, world.data], [8, "A worldof two lines", "!Level Cap", "1:abc"]);
  assert.equal((await gameFetch(`${directoryBase}/${room}/edit`, { method: "POST", headers: { [PLAYER_HEADER]: CREATOR }, body: "x".repeat(300_000) })).status, 413, "a text body over the cap is too large");
});

test("the admins' stats count the world rooms with their players, the PvP rooms and the game versions in the world rooms", async () => {
  const room = roomId(200);
  await makeWorld(room, 4);
  const released = await open(`${worldBase}${room}?player=${playerKey(91)}&name=Released&auth=${AUTH}`, { ...GAME, [VERSION_HEADER]: "0.6.7.7" });
  const unnamed = await sit(room, 92);
  const host = await connect(roomId(201), "host");
  await until(async () => (await listed(room)).online === 2);
  const stats = async (headers) => fetch(`${directoryBase.replace("/worlds", "")}/admin/stats`, { headers });

  const answer = await stats({ [PLAYER_HEADER]: ADMIN });
  assert.equal(answer.status, 200);
  const body = await answer.json();
  assert.deepEqual(body.worlds.find((world) => world.id === room), { id: room, name: `World ${room.slice(-3)}`, type: "classic", seats: 4, players: 2 });
  assert.deepEqual([body.versions["0.6.7.7"], body.versions.unknown], [1, 1]);
  assert.ok(body.rooms >= 1 && body.players.total === body.players.worlds + body.players.rooms);
  assert.deepEqual([body.battles, body.battleServer, typeof body.memory.rss, body.startedAt], [{ tracked: 0, served: 0 }, null, "number", new Date(1_000_000).toISOString()]);
  assert.equal((await stats({ [PLAYER_HEADER]: CREATOR })).status, 403, "only admins read them");

  for (const each of [released, unnamed, host]) {
    each.socket.close();
  }
});

/**
 * The link an admin sets, which leads to a release's script on a fake GitHub.
 */
const LINK = "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Level_Cap.rb";

/**
 * A fake GitHub: the latest link leads to the release's script, which GitHub's file host serves.
 *
 * @param {string} url The address fetched.
 * @returns {Promise<Response>} The answer.
 */
async function fakeGitHub(url) {
  const file = "https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/v1.4.0/Level_Cap.rb";

  if (url === LINK) {
    return new Response(null, { status: 302, headers: { Location: file } });
  }

  if (url === file) {
    return new Response(null, { status: 302, headers: { Location: "https://release-assets.githubusercontent.com/file" } });
  }

  return url === "https://release-assets.githubusercontent.com/file" ? new Response("# cap", { status: 200 }) : new Response("not found", { status: 404 });
}

test("every mod catalog route answers over HTTP", async () => {
  const mods = new ModCatalog(memoryModStore(), { clock: () => now, admins: [await playerIdOf(ADMIN)], fetch: fakeGitHub });
  const catalogRelay = createRelay({ clock: () => now, checkEveryMs: 3_600_000, mods, log: LOG });
  await new Promise((resolve) => catalogRelay.server.listen(0, "127.0.0.1", resolve));
  const modsBase = `http://127.0.0.1:${catalogRelay.server.address().port}/v1/mods`;
  const admin = { [PLAYER_HEADER]: ADMIN };
  const post = (path, body, headers = admin) => gameFetch(`${modsBase}${path}`, { method: "POST", headers, body: typeof body === "string" || body instanceof Uint8Array ? body : JSON.stringify(body) });

  assert.deepEqual(await (await gameFetch(modsBase)).json(), { mods: [], admin: false, personal: [] });
  assert.equal((await post("", { name: "Level Cap", link: LINK }, {})).status, 403);
  const added = await post("", { name: "Level Cap", link: LINK });
  assert.equal(added.status, 200);
  assert.equal((await added.json()).mod.version, "1.4.0");
  assert.equal((await (await gameFetch(modsBase, { headers: admin })).json()).mods[0].link, LINK);

  const checked = await post("/check", {});
  assert.equal(checked.status, 200);
  assert.equal((await checked.json()).mods.length, 1);

  const zip = await makeZip([["Pack.rb", "# pack", true], ["Pack/a.luka", "A"]]);
  const files = await zipHashes(zip);
  assert.equal((await post(`/${encodeURIComponent("pack!")}/upload?name=Pack!&version=2.0`, makeUpload(files, zip))).status, 200);
  assert.equal((await post("/pack!/upload?name=Pack!&version=2.1", makeUpload({ ...files, "Pack.rb": "00".repeat(32) }, zip))).status, 400);
  const listedMods = (await (await gameFetch(modsBase)).json()).mods;
  assert.deepEqual(listedMods.map((mod) => [mod.key, mod.version]), [["levelcap", "1.4.0"], ["pack!", "2.0"]]);
  assert.deepEqual(listedMods[1].files, files);

  const options = [{ key: "mod_pack", name: "Pack", type: "b", default: "1", choices: [] }];
  assert.equal((await post("/pack%21/options", { version: "1.0", options })).status, 200, "an older version's options are kept until the current version's arrive");
  assert.equal((await (await gameFetch(modsBase)).json()).mods[1].optionsVersion, "1.0");
  assert.equal((await post("/pack%21/options", { version: "2.0", options })).status, 200);
  assert.deepEqual((await (await gameFetch(modsBase)).json()).mods[1].options, options);

  const file = await gameFetch(`${modsBase}/pack%21/file`);
  assert.equal(file.headers.get("content-type"), "application/octet-stream");
  assert.deepEqual(new Uint8Array(await file.arrayBuffer()), zip);
  assert.equal((await gameFetch(`${modsBase}/levelcap/file`)).status, 404);

  assert.equal((await post("/victoryscreen/name", { name: "Victory_Screen" })).status, 200);
  assert.equal((await post("/levelcap/personal", { personal: true }, {})).status, 403);
  assert.equal((await post("/levelcap/personal", { personal: true })).status, 200);
  const forGames = await (await gameFetch(modsBase)).json();
  assert.deepEqual(forGames.mods.map((mod) => [mod.key, mod.personal]), [["levelcap", true], ["pack!", false]], "a mod known by its name alone is no mod to download");
  assert.deepEqual(forGames.personal, [{ key: "levelcap", name: "Level Cap" }, { key: "victoryscreen", name: "Victory_Screen" }]);

  assert.equal((await post("/pack%21/delete", {}, {})).status, 403);
  assert.equal((await post("/pack%21/delete", {})).status, 200);
  assert.equal((await gameFetch(`${modsBase}/pack%21/file`)).status, 404);
  assert.equal((await post("", "x".repeat(9000))).status, 413);
  assert.equal((await gameFetch(`${modsBase}/levelcap/elsewhere`)).status, 404);
  await catalogRelay.stop();
});

test("addressOf trusts X-Forwarded-For from this machine only, and takes the address the proxy appended last", () => {
  const request = (remoteAddress, forwarded) => ({ socket: { remoteAddress }, headers: forwarded === undefined ? {} : { "x-forwarded-for": forwarded } });

  assert.equal(addressOf(request("127.0.0.1", "203.0.113.5, 198.51.100.7")), "198.51.100.7");
  assert.equal(addressOf(request("::ffff:127.0.0.1", "198.51.100.7")), "198.51.100.7");
  assert.equal(addressOf(request("::1", " 198.51.100.7 ")), "198.51.100.7");
  assert.equal(addressOf(request("127.0.0.1", "")), "127.0.0.1");
  assert.equal(addressOf(request("127.0.0.1")), "127.0.0.1");
  assert.equal(addressOf(request("203.0.113.5", "198.51.100.7")), "203.0.113.5", "a client cannot name another address");
  assert.equal(addressOf(request(undefined)), null);
});

test("a game sends a bug report over HTTP, which the relay hands to GitHub, and a relay without a GitHub token takes none", async () => {
  const requests = [];
  const github = async (url, init) => {
    requests.push({ url, method: init.method, body: init.body });
    const path = url.split("/git/")[1];

    if (path === "ref/heads/main") return Response.json({ object: { sha: "head" } });
    if (path === "commits/head") return Response.json({ tree: { sha: "tree" } });
    if (path === "refs/heads/main") return Response.json({});
    return Response.json({ sha: "made", number: 7, html_url: "https://github.com/Owner/Issues/issues/7" }, { status: 201 });
  };
  const settings = { issuesToken: "token", filesToken: "token", issuesRepo: "Owner/Issues", filesRepo: "Owner/Files", branch: "main" };
  const reports = new ReportDesk(settings, { clock: () => now, fetch: github, limits: { ...REPORT_LIMITS, maxBodyBytes: 4096 }, log: LOG });
  const reportRelay = createRelay({ clock: () => now, checkEveryMs: 3_600_000, reports, log: LOG });
  await new Promise((resolve) => reportRelay.server.listen(0, "127.0.0.1", resolve));
  const reportsUrl = `http://127.0.0.1:${reportRelay.server.address().port}/v1/reports`;
  const index = gzipSync(Buffer.from("# Stuck\n")).toString("base64");
  const header = { title: "Stuck", text: "The door stays shut.", version: "0.6.3", facts: [["Mod", "0.6.3"]], files: [{ name: "report.md", length: index.length, gzip: true }, { name: "screenshot.png", length: 8, gzip: false }] };
  const body = `${JSON.stringify(header)}\n${index}iVBORw0K`;
  const send = (headers, text = body, url = reportsUrl) => fetch(url, { method: "POST", headers: { "Content-Type": "text/plain; charset=utf-8", ...GAME, ...headers }, body: text });

  const sent = await send({ [PLAYER_HEADER]: playerKey(70) });
  assert.equal(sent.status, 201);
  const answer = await sent.json();
  assert.equal(answer.issue, 7);
  assert.match(answer.id, /^\d{4}-\d\d-\d\d-[0-9a-f]{8}$/);
  assert.deepEqual(requests.map((request) => `${request.method} ${request.url.split("/repos/")[1]}`), [
    "POST Owner/Files/git/blobs",
    "GET Owner/Files/git/ref/heads/main",
    "GET Owner/Files/git/commits/head",
    "POST Owner/Files/git/trees",
    "POST Owner/Files/git/commits",
    "PATCH Owner/Files/git/refs/heads/main",
    "POST Owner/Issues/issues",
  ]);
  assert.equal(JSON.parse(requests[0].body).content, "iVBORw0K");
  assert.deepEqual(JSON.parse(requests[3].body).tree.map((entry) => [entry.path, entry.content ?? entry.sha]), [[`reports/${answer.id}/report.md`, "# Stuck\n"], [`reports/${answer.id}/screenshot.png`, "made"]]);

  const keyless = await send({});
  assert.deepEqual([keyless.status, (await keyless.json()).code], [401, "player"]);
  assert.equal((await send({ [PLAYER_HEADER]: playerKey(70) }, "x".repeat(5000))).status, 413);
  assert.equal(requests.length, 7);
  await reportRelay.stop();

  const off = await send({ [PLAYER_HEADER]: playerKey(70) }, body, directoryBase.replace("/worlds", "/reports"));
  assert.deepEqual([off.status, (await off.json()).code], [503, "off"]);
});

test("a bug report sent while the relay handles another is answered busy over HTTP once its body is drained", async () => {
  let open;
  const gate = new Promise((resolve) => (open = resolve));
  const github = async (url) => {
    await gate;
    const path = url.split("/git/")[1];

    if (path === "ref/heads/main") return Response.json({ object: { sha: "head" } });
    if (path === "commits/head") return Response.json({ tree: { sha: "tree" } });
    if (path === "refs/heads/main") return Response.json({});
    return Response.json({ sha: "made", number: 8, html_url: "https://github.com/Owner/Issues/issues/8" }, { status: 201 });
  };
  const settings = { issuesToken: "token", filesToken: "token", issuesRepo: "Owner/Issues", filesRepo: "Owner/Files", branch: "main" };
  const reports = new ReportDesk(settings, { clock: () => now, fetch: github, log: LOG });
  const reportRelay = createRelay({ clock: () => now, checkEveryMs: 3_600_000, reports, log: LOG });
  await new Promise((resolve) => reportRelay.server.listen(0, "127.0.0.1", resolve));
  const reportsUrl = `http://127.0.0.1:${reportRelay.server.address().port}/v1/reports`;
  const index = gzipSync(Buffer.from("# Busy\n")).toString("base64");
  const header = { title: "Busy", text: "Sent twice.", version: "0.6.4", facts: [], files: [{ name: "report.md", length: index.length, gzip: true }] };
  const body = `${JSON.stringify(header)}\n${index}`;
  const send = (player, text) => fetch(reportsUrl, { method: "POST", headers: { ...GAME, [PLAYER_HEADER]: playerKey(player) }, body: text });

  try {
    const first = send(71, body);

    while (reports.pending === 0) {
      await new Promise((resolve) => setImmediate(resolve));
    }

    const busy = await send(72, `${body}${" ".repeat(256 * 1024)}`);
    assert.deepEqual([busy.status, await busy.json()], [503, { error: "the relay is handling other bug reports, try again in a minute", code: "busy" }]);

    open();
    assert.equal((await first).status, 201);
    assert.equal((await send(72, body)).status, 201, "the busy report took no turn");
  } finally {
    open();
    await reportRelay.stop();
  }
});

test("a relay that starts marks every player offline, since nobody is in its world rooms yet", async () => {
  const store = memoryStore();
  const directory = new Directory(store, { clock: () => now });
  await store.put({ id: "a1".repeat(16), name: "Busy", members: { p1: { name: "One", seen: 0 }, p2: { name: "Two", seen: 0 } }, bans: [], online: ["p1", "p2"] });
  await store.put({ id: "b2".repeat(16), name: "Quiet", members: {}, bans: [], online: [] });
  assert.equal(await clearPresence(directory), 1);
  const busy = await store.get("a1".repeat(16));
  assert.deepEqual([busy.online, busy.members.p1.seen, busy.members.p2.seen], [[], now, now], "who was online is noted as last seen now");
  assert.deepEqual((await store.get("b2".repeat(16))).online, []);
});
