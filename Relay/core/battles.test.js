//----------------------------------------------------------------
//  battles.test.js
//
//  Changelog:
//      Paulinchen  2026-10-23: Covered how a battle that just ended answers a player who comes onto it
//      Paulinchen  2026-10-15: Covered the battle server's boss reports and pool lines
//                            - Covered the players the battle server takes in late
//                            - Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  BATTLE_END, BATTLE_LIMITS, BATTLE_REFUSAL, BattleTable, SERVER_SEAT, battleClosedText, battleRouteOf, battleSeatText, bossLine, messageLine,
  playerMessage, presenceLine, readOpen, readServerLine, serveLine, serverFrame,
} from "./battles.js";
import { CLOSE } from "./relay.js";

/**
 * A world's id.
 */
const WORLD = "ab".repeat(16);

/**
 * The id of the player who starts the battle.
 */
const STARTER = "1".repeat(32);

/**
 * The id of a player who joins it.
 */
const GUEST = "2".repeat(32);

/**
 * The id of a player who is not in it.
 */
const STRANGER = "3".repeat(32);

/**
 * A setup in base64, as the starter's game writes it.
 */
const SETUP = Buffer.from("1\tsetup").toString("base64");

/**
 * Makes a clock the test moves by hand.
 *
 * @returns {{now: () => number, add: (ms: number) => void}} The clock.
 */
function handClock() {
  let time = 1_000_000;
  return { now: () => time, add: (ms) => { time += ms; } };
}

test("a battle route names the world, and the battle for its channel", () => {
  assert.deepEqual(battleRouteOf(new URL(`http://relay/v1/worlds/${WORLD}/battles`)), { id: WORLD, battle: null });
  assert.deepEqual(battleRouteOf(new URL(`http://relay/v1/worlds/${WORLD}/battles/k3x9`)), { id: WORLD, battle: "k3x9" });
  assert.equal(battleRouteOf(new URL(`http://relay/v1/worlds/${WORLD}/battles/NOT-AN-ID`)), null);
  assert.equal(battleRouteOf(new URL(`http://relay/v1/worlds/${WORLD}/story`)), null);
  assert.equal(battleRouteOf(new URL("http://relay/v1/worlds/short/battles")), null);
});

test("a request to start a battle names its id, distinct world seats and a base64 setup", () => {
  assert.deepEqual(readOpen({ battle: "k3x9", seats: [0, 3], setup: SETUP }), { battle: "k3x9", seats: [0, 3], setup: SETUP });
  assert.equal(readOpen({ battle: "k3x9", seats: [0, 0], setup: SETUP }).status, 400);
  assert.equal(readOpen({ battle: "k3x9", seats: [32], setup: SETUP }).status, 400);
  assert.equal(readOpen({ battle: "k3x9", seats: [], setup: SETUP }).status, 400);
  assert.equal(readOpen({ battle: "k3x9", seats: [1], setup: "not base64!" }).status, 400);
  assert.equal(readOpen({ battle: "k3x9", seats: [1], setup: "A".repeat(BATTLE_LIMITS.maxSetupLength + 4) }).status, 400);
  assert.equal(readOpen({ battle: "", seats: [1], setup: SETUP }).status, 400);
  assert.equal(readOpen(null).status, 400);
});

test("only the battle's players come onto its channel, each as their world seat", () => {
  const table = new BattleTable();
  table.open(WORLD, "k3x9", new Map([[STARTER, 0], [GUEST, 4]]), STARTER);
  assert.deepEqual(table.admit(WORLD, "k3x9", GUEST), { seat: 4 });
  assert.equal(table.admit(WORLD, "k3x9", STRANGER).status, 403);
  assert.equal(table.admit(WORLD, "other", GUEST).status, 404);
  assert.equal(table.admit("cd".repeat(16), "k3x9", GUEST).status, 404);
});

test("a player who comes onto a battle that just ended learns how it ended, for as long as players may take to come", () => {
  const clock = handClock();
  const table = new BattleTable({ clock: clock.now });
  table.open(WORLD, "k3x9", new Map([[STARTER, 0]]), STARTER);
  table.close(WORLD, "k3x9", BATTLE_END.server);
  assert.deepEqual(table.admit(WORLD, "k3x9", STARTER), { status: 404, body: { error: "the battle ended: server", code: BATTLE_END.server } });
  clock.add(BATTLE_LIMITS.arriveMs);
  table.overdue(clock.now());
  assert.equal(table.admit(WORLD, "k3x9", STARTER).body.code, undefined);
});

test("a battle id runs once per world, and a world runs a limited number of server battles", () => {
  const limits = { ...BATTLE_LIMITS, maxBattlesPerWorld: 2 };
  const table = new BattleTable({ limits });
  assert.equal(table.refusalOf(WORLD, "a", STARTER), null);
  table.open(WORLD, "a", new Map([[STARTER, 0]]), STARTER);
  assert.equal(table.refusalOf(WORLD, "a", STARTER).status, 409);
  table.open(WORLD, "b", new Map([[STARTER, 0]]), STARTER);
  assert.equal(table.refusalOf(WORLD, "c", STARTER).body.code, BATTLE_REFUSAL.full);
  table.close(WORLD, "a");
  assert.equal(table.refusalOf(WORLD, "c", STARTER), null);
});

test("a player starts only so many battles at once, one more every refill", () => {
  const clock = handClock();
  const table = new BattleTable({ clock: clock.now, limits: { ...BATTLE_LIMITS, openBurst: 2, openRefillMs: 1000 } });
  assert.equal(table.refusalOf(WORLD, "a", STARTER), null);
  assert.equal(table.refusalOf(WORLD, "b", STARTER), null);
  assert.equal(table.refusalOf(WORLD, "c", STARTER).body.code, BATTLE_REFUSAL.rate);
  assert.equal(table.refusalOf(WORLD, "c", GUEST), null);
  clock.add(1000);
  assert.equal(table.refusalOf(WORLD, "c", STARTER), null);
});

test("a battle no player came onto ends, and so does one that lasted too long", () => {
  const clock = handClock();
  const table = new BattleTable({ clock: clock.now });
  table.open(WORLD, "empty", new Map([[STARTER, 0]]), STARTER);
  table.open(WORLD, "met", new Map([[STARTER, 0]]), STARTER);
  table.admit(WORLD, "met", STARTER);
  clock.add(BATTLE_LIMITS.arriveMs);
  assert.deepEqual(table.overdue(clock.now()), [{ world: WORLD, battle: "empty", end: BATTLE_END.arrive }]);
  clock.add(BATTLE_LIMITS.lifetimeMs);
  assert.deepEqual(table.overdue(clock.now()).map((entry) => entry.end), [BATTLE_END.expired, BATTLE_END.expired]);
});

test("players talk to the server's seat alone, and the server's frames carry its seat", () => {
  const payload = Uint8Array.from([1, 2, 3]);
  assert.deepEqual(playerMessage(Uint8Array.from([SERVER_SEAT, 1, 2, 3])).payload, payload);
  assert.equal(playerMessage(Uint8Array.from([7, 1])).refusal.code, CLOSE.badRequest);
  assert.equal(playerMessage(new Uint8Array()).refusal.code, CLOSE.badRequest);
  assert.deepEqual(serverFrame(payload), Uint8Array.from([SERVER_SEAT, 1, 2, 3]));
  assert.equal(battleSeatText(4), "seat 4");
  assert.equal(battleClosedText(BATTLE_END.ended), "closed ended");
});

test("the lines to the battle server and back carry the battle, presence and messages", () => {
  assert.deepEqual(JSON.parse(serveLine("k3x9", SETUP)), { op: "serve", bid: "k3x9", setup: SETUP });
  assert.deepEqual(JSON.parse(presenceLine("in", 4)), { op: "in", seat: 4 });
  assert.deepEqual(JSON.parse(messageLine(4, Uint8Array.from([104, 105]))), { op: "message", seat: 4, text: "aGk=" });
  assert.deepEqual(readServerLine('{"op":"serving"}'), { op: "serving" });
  assert.deepEqual(readServerLine('{"op":"refused","code":"data","error":"differs"}'), { op: "refused", code: "data", error: "differs" });
  assert.deepEqual(readServerLine('{"op":"send","seat":-1,"text":"aGk="}'), { op: "send", seat: -1, payload: Uint8Array.from([104, 105]) });
  assert.deepEqual(readServerLine('{"op":"end","result":"victory"}'), { op: "end", result: "victory" });
  assert.equal(readServerLine('{"op":"send","seat":"x","text":"aGk="}'), null);
  assert.equal(readServerLine("not json"), null);
  assert.deepEqual(readServerLine('{"op":"boss_report","key":"Sara","battle":"rp1","seq":2,"delta":0.5,"max":900,"killed":true}'),
                   { op: "boss_report", key: "Sara", report: { battle: "rp1", seq: 2, delta: 0.5, max: 900, killed: true } });
  assert.equal(readServerLine('{"op":"boss_report","key":5,"battle":"rp1"}'), null);
  assert.deepEqual(readServerLine('{"op":"admit","seats":[3,4]}'), { op: "admit", seats: [3, 4] });
  assert.equal(readServerLine('{"op":"admit","seats":[32]}'), null);
});

test("the battle server hears how a boss pool stands, or that its report was refused", () => {
  assert.deepEqual(JSON.parse(bossLine("Sara", { left: 0.5, max: 900, defeated: false, by: null }, true)),
                   { op: "boss", key: "Sara", left: 0.5, max: 900, defeated: false, by: "", answer: true });
  assert.deepEqual(JSON.parse(bossLine("Sara", null, true)), { op: "boss", key: "Sara", answer: true });
});
