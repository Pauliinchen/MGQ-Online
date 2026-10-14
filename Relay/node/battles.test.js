//----------------------------------------------------------------
//  battles.test.js
//
//  Changelog:
//      Paulinchen  2026-10-15: Covered the battle server's boss reports and the pool changes it hears of
//                            - Covered the players the battle server takes in late
//                            - Created
//
//----------------------------------------------------------------

// Tests of the Node relay's co-op battles on the battle server, over real HTTP, WebSockets and a
// stand-in battle server on TCP.

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import net from "node:net";
import { BATTLE_LIMITS, SERVER_SEAT } from "../core/battles.js";
import { Directory, sha256Hex } from "../core/directory.js";
import { AUTH_HEADER, CLOSE, FEATURES_HEADER, PLAYER_HEADER } from "../core/relay.js";
import { battleServerOf, createRelay, memoryStore } from "./server.js";

/**
 * The world's auth key.
 */
const AUTH = "ab".repeat(32);

/**
 * The world creator's key.
 */
const CREATOR = "c0".repeat(16);

/**
 * What every game names in X-MGQ-Features.
 */
const GAME = Object.freeze({ [FEATURES_HEADER]: "raid" });

/**
 * The rates the tests leave unlimited.
 */
const TEST_RATES = Object.fromEntries(["joins", "creates", "starts"].map((kind) => [kind, { burst: 10_000, refillMs: 1 }]));

/**
 * The battle limits of the tests: a short wait for the server and its first player.
 */
const TEST_BATTLE_LIMITS = { ...BATTLE_LIMITS, serveWaitMs: 500, arriveMs: 1000 };

/**
 * A setup in base64.
 */
const SETUP = Buffer.from("1\tsetup").toString("base64");

/**
 * The relay's clock, which the tests move by hand.
 */
let now = 1_000_000;

/**
 * How the stand-in battle server answers a battle: "serving", "refused" or "silent".
 */
let serverAnswers = "serving";

/**
 * The stand-in battle server's connections, each with the lines it got and a way to send one.
 */
const served = [];

let battleServer;

let relay;

let bare;

let httpBase;

let bareBase;

let wsBase;

before(async () => {
  battleServer = net.createServer((socket) => {
    const connection = { lines: [], waiting: [], send: (fields) => socket.write(`${JSON.stringify(fields)}\n`), socket, closed: false };
    let pending = "";
    served.push(connection);
    socket.on("data", (data) => {
      pending += data.toString("utf8");
      let end;

      while ((end = pending.indexOf("\n")) >= 0) {
        const line = JSON.parse(pending.slice(0, end));
        pending = pending.slice(end + 1);

        if (line.op === "serve" && serverAnswers !== "silent") {
          connection.send(serverAnswers === "serving" ? { op: "serving" } : { op: "refused", code: "data", error: "the game data differs" });
        }

        connection.waiting.length > 0 ? connection.waiting.shift()(line) : connection.lines.push(line);
      }
    });
    socket.on("close", () => {
      connection.closed = true;
    });
    socket.on("error", () => {});
  });
  await new Promise((resolve) => battleServer.listen(0, "127.0.0.1", resolve));
  const directory = new Directory(memoryStore(), { clock: () => now, rates: TEST_RATES });
  relay = createRelay({ clock: () => now, checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, directory, log: { info: () => {}, error: () => {} },
                        battleServer: { host: "127.0.0.1", port: battleServer.address().port }, battleLimits: TEST_BATTLE_LIMITS });
  bare = createRelay({ checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, log: { info: () => {}, error: () => {} } });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  await new Promise((resolve) => bare.server.listen(0, "127.0.0.1", resolve));
  httpBase = `http://127.0.0.1:${relay.server.address().port}/v1/worlds`;
  bareBase = `http://127.0.0.1:${bare.server.address().port}/v1/worlds`;
  wsBase = `ws://127.0.0.1:${relay.server.address().port}/v1`;
});

after(async () => {
  await relay.stop();
  await bare.stop();
  await new Promise((resolve) => battleServer.close(resolve));
});

/**
 * A world's id.
 *
 * @param {number} number Which world.
 * @returns {string} The id.
 */
function worldId(number) {
  return number.toString(16).padStart(32, "0");
}

/**
 * A player's key.
 *
 * @param {number} number Which player.
 * @returns {string} The key.
 */
function playerKey(number) {
  return number.toString(16).padStart(32, "a");
}

/**
 * Makes a world in the relay's directory.
 *
 * @param {string} world The world's id.
 * @param {object} [fields] More of the world, such as its type.
 */
async function makeWorld(world, fields = {}) {
  const response = await fetch(httpBase, {
    method: "POST",
    headers: GAME,
    body: JSON.stringify({
      id: world, name: `World ${world.slice(-3)}`, seats: 8, player: CREATOR, playerName: "Creator", authHash: await sha256Hex(AUTH),
      lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, ...fields,
    }),
  });
  assert.equal(response.status, 201);
}

/**
 * Opens a WebSocket and keeps what comes in.
 *
 * @param {string} address The address.
 * @param {object} headers The headers.
 * @returns {Promise<{socket: WebSocket, closed: Promise<{code: number, reason: string}>, next: () => Promise<any>}>} The connection.
 */
async function open(address, headers) {
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
  return { socket, closed, next: () => (inbox.length > 0 ? Promise.resolve(inbox.shift()) : new Promise((resolve) => waiting.push(resolve))) };
}

/**
 * Seats a player in a world's room.
 *
 * @param {string} world The world.
 * @param {number} player Which player.
 * @returns {Promise<{seat: number, connection: object}>} Their seat and connection.
 */
async function sit(world, player) {
  const connection = await open(`${wsBase}/world/${world}?name=Player%20${player}`, { ...GAME, [PLAYER_HEADER]: playerKey(player), [AUTH_HEADER]: AUTH });
  const seat = Number(String(await connection.next()).split(" ")[1]);
  return { seat, connection };
}

/**
 * Asks the relay to start a battle.
 *
 * @param {string} base The relay's worlds address.
 * @param {string} world The world.
 * @param {number} player Which player asks.
 * @param {object} body The request.
 * @param {string} [auth] The auth key.
 * @returns {Promise<{status: number, body: object}>} The answer.
 */
async function startBattle(base, world, player, body, auth = AUTH) {
  const response = await fetch(`${base}/${world}/battles`, {
    method: "POST", headers: { ...GAME, [PLAYER_HEADER]: playerKey(player), [AUTH_HEADER]: auth }, body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() };
}

/**
 * Opens a player's battle channel.
 *
 * @param {string} world The world.
 * @param {string} battle The battle.
 * @param {number} player Which player.
 * @returns {Promise<object>} The connection, see open.
 */
function channel(world, battle, player) {
  return open(`${wsBase}/worlds/${world}/battles/${battle}`, { ...GAME, [PLAYER_HEADER]: playerKey(player), [AUTH_HEADER]: AUTH });
}

/**
 * Takes the next line the battle server got on a connection.
 *
 * @param {object} connection The connection.
 * @returns {Promise<object>} The line.
 */
function nextLine(connection) {
  return connection.lines.length > 0 ? Promise.resolve(connection.lines.shift()) : new Promise((resolve) => connection.waiting.push(resolve));
}

/**
 * Takes text frames from a connection until one starts as asked.
 *
 * @param {object} connection The connection, see open.
 * @param {string} start How the frame starts.
 * @returns {Promise<string>} The frame.
 */
async function nextText(connection, start) {
  for (;;) {
    const frame = await connection.next();

    if (typeof frame === "string" && frame.startsWith(start)) {
      return frame;
    }
  }
}

/**
 * Waits until a condition holds.
 *
 * @param {() => boolean} condition The condition.
 */
async function until(condition) {
  for (let tries = 0; tries < 200; tries++) {
    if (condition()) {
      return;
    }

    await new Promise((resolve) => setTimeout(resolve, 10));
  }

  throw new Error("the condition never held");
}

test("a relay without a battle server refuses, so the starter hosts", async () => {
  const answer = await fetch(`${bareBase}/${worldId(1)}/battles`, { method: "POST", headers: GAME, body: "{}" });
  assert.equal(answer.status, 503);
  assert.equal((await answer.json()).code, "no_server");
});

test("where BATTLE_SERVER says the battle server listens", () => {
  assert.deepEqual(battleServerOf("127.0.0.1:8095"), { host: "127.0.0.1", port: 8095 });
  assert.equal(battleServerOf(undefined), null);
  assert.equal(battleServerOf("no port"), null);
});

test("a battle starts for players seated in the world, and its channel carries their messages to the server and back", async () => {
  serverAnswers = "serving";
  const world = worldId(2);
  await makeWorld(world);
  const first = await sit(world, 1);
  const second = await sit(world, 2);
  const answer = await startBattle(httpBase, world, 1, { battle: "k3x9", seats: [first.seat, second.seat], setup: SETUP });
  assert.deepEqual(answer, { status: 201, body: { battle: "k3x9", seat: SERVER_SEAT } });
  const server = served.at(-1);
  assert.deepEqual(await nextLine(server), { op: "serve", bid: "k3x9", setup: SETUP });

  const firstChannel = await channel(world, "k3x9", 1);
  assert.equal(await firstChannel.next(), `seat ${first.seat}`);
  assert.deepEqual(await nextLine(server), { op: "in", seat: first.seat });
  const secondChannel = await channel(world, "k3x9", 2);
  assert.equal(await secondChannel.next(), `seat ${second.seat}`);
  assert.deepEqual(await nextLine(server), { op: "in", seat: second.seat });

  firstChannel.socket.send(Uint8Array.from([SERVER_SEAT, 104, 105]));
  assert.deepEqual(await nextLine(server), { op: "message", seat: first.seat, text: "aGk=" });

  server.send({ op: "send", seat: -1, text: "b2s=" });
  assert.deepEqual([...new Uint8Array(await firstChannel.next())], [SERVER_SEAT, 111, 107]);
  assert.deepEqual([...new Uint8Array(await secondChannel.next())], [SERVER_SEAT, 111, 107]);
  server.send({ op: "send", seat: second.seat, text: "eA==" });
  assert.deepEqual([...new Uint8Array(await secondChannel.next())], [SERVER_SEAT, 120]);

  secondChannel.socket.close();
  assert.deepEqual(await nextLine(server), { op: "out", seat: second.seat });

  server.send({ op: "end", result: "victory" });
  assert.equal(await firstChannel.next(), "closed ended");
  assert.equal((await firstChannel.closed).code, CLOSE.normal);
  assert.equal(relay.battles.get(world, "k3x9"), null);
  await until(() => server.closed);
  first.connection.socket.close();
  second.connection.socket.close();
});

test("a player's message to another seat than the server's closes their channel", async () => {
  serverAnswers = "serving";
  const world = worldId(3);
  await makeWorld(world);
  const player = await sit(world, 1);
  assert.equal((await startBattle(httpBase, world, 1, { battle: "a1", seats: [player.seat], setup: SETUP })).status, 201);
  const own = await channel(world, "a1", 1);
  await own.next();
  own.socket.send(Uint8Array.from([player.seat, 1]));
  assert.equal((await own.closed).code, CLOSE.badRequest);
  player.connection.socket.close();
});

test("only the battle's players come onto its channel, and only players of the world start one for seated players", async () => {
  serverAnswers = "serving";
  const world = worldId(4);
  await makeWorld(world);
  const first = await sit(world, 1);
  const outsider = await sit(world, 3);
  assert.equal((await startBattle(httpBase, world, 1, { battle: "b2", seats: [first.seat, 30], setup: SETUP })).body.code, "seats");
  assert.equal((await startBattle(httpBase, world, 1, { battle: "b2", seats: [outsider.seat], setup: SETUP })).status, 403);
  assert.equal((await startBattle(httpBase, world, 1, { battle: "b2", seats: [first.seat], setup: SETUP }, "cd".repeat(32))).status, 401);
  assert.equal((await startBattle(httpBase, world, 1, { battle: "b2", seats: [first.seat], setup: "!" })).status, 400);
  assert.equal((await startBattle(httpBase, world, 1, { battle: "b2", seats: [first.seat], setup: SETUP })).status, 201);
  await assert.rejects(channel(world, "b2", 3));
  await assert.rejects(channel(world, "nothing", 1));
  first.connection.socket.close();
  outsider.connection.socket.close();
});

test("the battle server's refusal reaches the starter, and so does a server that never answers", async () => {
  const world = worldId(5);
  await makeWorld(world);
  const player = await sit(world, 1);
  serverAnswers = "refused";
  assert.deepEqual(await startBattle(httpBase, world, 1, { battle: "c3", seats: [player.seat], setup: SETUP }),
                   { status: 503, body: { error: "the game data differs", code: "data" } });
  serverAnswers = "silent";
  assert.equal((await startBattle(httpBase, world, 1, { battle: "c4", seats: [player.seat], setup: SETUP })).body.code, "timeout");
  serverAnswers = "serving";
  player.connection.socket.close();
});

test("a battle no player came onto ends, and the battle server hears of it", async () => {
  serverAnswers = "serving";
  const world = worldId(6);
  await makeWorld(world);
  const player = await sit(world, 1);
  assert.equal((await startBattle(httpBase, world, 1, { battle: "d5", seats: [player.seat], setup: SETUP })).status, 201);
  const server = served.at(-1);
  await nextLine(server);
  now += TEST_BATTLE_LIMITS.arriveMs;
  relay.sweepBattles();
  assert.deepEqual(await nextLine(server), { op: "close" });
  assert.equal(relay.battles.get(world, "d5"), null);
  player.connection.socket.close();
});

test("the battle server reports a Raid World's boss pool as the starter, and hears of every change to its world's pools", async () => {
  serverAnswers = "serving";
  const world = worldId(7);
  await makeWorld(world, { type: "raid" });
  const first = await sit(world, 1);
  const second = await sit(world, 2);
  assert.equal((await startBattle(httpBase, world, 1, { battle: "e6", seats: [first.seat, second.seat], setup: SETUP })).status, 201);
  const server = served.at(-1);
  await nextLine(server);

  server.send({ op: "boss_report", key: "Alma Elma", battle: "rp1", seq: 1, delta: 0.25, max: 90000, killed: false });
  assert.deepEqual(await nextLine(server), { op: "boss", key: "Alma Elma", left: 0.75, max: 90000, defeated: false, by: "", answer: true });
  assert.equal(await nextText(first.connection, "boss "), "boss 0.75 90000 0 Alma Elma");

  const response = await fetch(`${httpBase}/${world}/bosses/Alma%20Elma/report`, {
    method: "POST", headers: { ...GAME, [PLAYER_HEADER]: playerKey(2), [AUTH_HEADER]: AUTH },
    body: JSON.stringify({ battle: "rp2", seq: 1, delta: 0.75, max: 90000, killed: true }),
  });
  assert.equal(response.status, 200);
  assert.deepEqual(await nextLine(server), { op: "boss", key: "Alma Elma", left: 0, max: 90000, defeated: true, by: "", answer: false });

  server.send({ op: "boss_report", key: "", battle: "rp1", seq: 2, delta: 0.1, max: 90000, killed: false });
  assert.deepEqual(await nextLine(server), { op: "boss", key: "", answer: true });
  server.send({ op: "end", result: "victory" });
  first.connection.socket.close();
  second.connection.socket.close();
});

test("a Classic world's battle server reports no boss pool", async () => {
  serverAnswers = "serving";
  const world = worldId(8);
  await makeWorld(world);
  const player = await sit(world, 1);
  assert.equal((await startBattle(httpBase, world, 1, { battle: "f7", seats: [player.seat], setup: SETUP })).status, 201);
  const server = served.at(-1);
  await nextLine(server);
  server.send({ op: "boss_report", key: "Alma Elma", battle: "rp1", seq: 1, delta: 0.25, max: 90000, killed: false });
  assert.deepEqual(await nextLine(server), { op: "boss", key: "Alma Elma", answer: true });
  server.send({ op: "end", result: "victory" });
  player.connection.socket.close();
});

test("a player the battle server takes in late comes onto the battle's channel, as whoever sits on the seat it names", async () => {
  serverAnswers = "serving";
  const world = worldId(9);
  await makeWorld(world);
  const first = await sit(world, 1);
  const late = await sit(world, 2);
  assert.equal((await startBattle(httpBase, world, 1, { battle: "g8", seats: [first.seat], setup: SETUP })).status, 201);
  const server = served.at(-1);
  await nextLine(server);
  await assert.rejects(channel(world, "g8", 2));

  server.send({ op: "admit", seats: [late.seat, 20] });
  await until(() => relay.battles.get(world, "g8").players.size === 2);
  const lateChannel = await channel(world, "g8", 2);
  assert.equal(await lateChannel.next(), `seat ${late.seat}`);
  assert.deepEqual(await nextLine(server), { op: "in", seat: late.seat });
  server.send({ op: "end", result: "victory" });
  first.connection.socket.close();
  late.connection.socket.close();
});
