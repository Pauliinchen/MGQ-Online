//----------------------------------------------------------------
//  story.test.js
//
//  Changelog:
//      Paulinchen  2026-10-31: Covered the keys a keyed story hands its story tracks
//                            - Wrote every story key by key and covered games that keep no keys being turned away
//      Paulinchen  2026-10-23: Covered the affection of a keyed story keeping the highest value written
//                            - Checked partOf against the golden parts the game's StoryParts passes too
//      Paulinchen  2026-10-21: Covered the pins an older relay kept as rules
//                            - Covered a write that changes pinned keys keeping its other keys
//      Paulinchen  2026-10-17: Covered the frozen raid boss fights in a keyed story's lists and the end of one
//                            - Covered the end of a frozen fight staying final
//      Paulinchen  2026-10-15: Covered the companions' affection in a keyed story's lists
//                            - Covered a route under way before the Great Decision
//      Paulinchen  2026-10-12: Covered the level caps of story writes
//                            - Moved the test of the Worker refusing a story write too long to cloudflare/worker.test.js
//      Paulinchen  2026-10-11: Covered a world that finished every route choosing and playing a route again
//      Paulinchen  2026-10-10: Covered route lock refusals while a route is under way
//                            - Covered the Worker refusing a story write too long
//      Paulinchen  2026-10-09: Covered an admin taking back the route lock
//                            - Covered Part 3 keeping the checkpoint of its first end
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  PART, ROUTE, STORY_LIMITS, WorldStory, compareKeys, countersOf, handleStoryRequest, listsOf, mergeCaps, partOf, readCounters, readLists, keylessGame, keylessGameRefusal, storyKey,
  storyPushText, storyRouteOf, storyText,
} from "./story.js";

/**
 * A player's id.
 */
const ALICE = "a1".repeat(16);

/**
 * Another player's id.
 */
const BOB = "b2".repeat(16);

/**
 * Some keys a write changes, which tell one story from another.
 */
const SOME = Object.freeze({ v: "70:n1" });

/**
 * Other keys a write changes.
 */
const OTHER = Object.freeze({ v: "70:n2" });

/**
 * A frozen raid boss fight of troop 1234 as the games write it, with commas, colons and bars inside.
 */
const FROZEN = "1234|map:138:32:1|map:138:32:1|1|138|9:4:5:2:0:%24boss:3:0:0:0:0:1:0,10:6:7:8:0:Lamia:1:0:0:0:0:0:1|12.13|138.10.12.2|s31~T,v1075~n14";

/**
 * Makes counters, 0 and no finished route unless given.
 *
 * @param {object} [values] The counters that differ.
 * @returns {object} The counters.
 */
function counters(values = {}) {
  return { p: 0, r1141: 0, r1142: 0, r1143: 0, clear: [], ...values };
}

/**
 * Makes a story over a store in memory, with a clock the tests move.
 *
 * @param {object} [limits] The limits.
 * @returns {{story: WorldStory, kept: {story: object | undefined, checkpoints: Map<string, object>, puts: number}, time: {now: number}}} The story, what its store keeps and how often it wrote, and its clock.
 */
function makeStory(limits = STORY_LIMITS) {
  const kept = { story: undefined, checkpoints: new Map(), puts: 0 };
  const time = { now: 1000 };
  const store = {
    get: async () => structuredClone(kept.story),
    put: async (story, checkpoint) => {
      kept.puts++;
      kept.story = structuredClone(story);

      if (checkpoint) {
        kept.checkpoints.set(checkpoint.part, structuredClone(checkpoint));
      }
    },
    getCheckpoint: async (part) => structuredClone(kept.checkpoints.get(part)),
    remove: async () => {
      kept.story = undefined;
      kept.checkpoints.clear();
    },
  };

  return { story: new WorldStory(store, { clock: () => time.now, limits }), kept, time };
}

/**
 * Writes the story and expects it accepted.
 *
 * @param {WorldStory} story The story.
 * @param {number} base The revision the write builds on.
 * @param {object} values The counters that differ from 0.
 * @param {object} [set] The lists of the keys it changes.
 * @returns {Promise<object>} The answer's body.
 */
async function accepted(story, base, values, set = SOME) {
  const answer = await story.write(ALICE, { base, counters: counters(values), set });
  assert.equal(answer.status, 200, JSON.stringify(answer.body));
  assert.equal(answer.body.accepted, true);
  assert.equal(answer.push.rev, answer.body.rev);
  assert.equal(answer.body.wrev, answer.body.rev);
  return answer.body;
}

test("the parts follow variable 1001 up to the Great Decision, then the route chosen", () => {
  assert.equal(partOf(counters({ p: 0 })), PART.one);
  assert.equal(partOf(counters({ p: 18 })), PART.one);
  assert.equal(partOf(counters({ p: 19 })), PART.two);
  assert.equal(partOf(counters({ p: 33 })), PART.two);
  assert.equal(partOf(counters({ p: 34 })), PART.three);
  assert.equal(partOf(counters({ p: 40 })), PART.three);
  assert.equal(partOf(counters({ p: 40, r1141: 1 })), PART.ad);
  assert.equal(partOf(counters({ p: 40, r1142: 81 })), PART.mr);
  assert.equal(partOf(counters({ p: 40, r1143: 25, clear: ["ad", "mr", "chaos"] })), PART.chaos);
  assert.equal(partOf(counters({ p: 39, clear: ["ad"] })), PART.three);
});

test("partOf still finds the golden parts, which the game's StoryParts finds too", () => {
  const cases = JSON.parse(readFileSync(new URL("../../fixtures/story/parts.json", import.meta.url), "utf8")).parts;

  for (const { part, ...found } of cases) {
    assert.equal(partOf(found), part, JSON.stringify(found));
  }
});

test("the story's order grows through a route, its finish and the return to the Great Decision", () => {
  const steps = [
    counters({ p: 39 }),
    counters({ p: 40, r1141: 1 }),
    counters({ p: 40, r1141: 76 }),
    counters({ p: 40, r1141: 76, clear: ["ad"] }),
    counters({ p: 39, clear: ["ad"] }),
    counters({ p: 40, r1142: 1, clear: ["ad"] }),
    counters({ p: 40, r1142: 81, clear: ["ad", "mr"] }),
    counters({ p: 39, clear: ["ad", "mr"] }),
    counters({ p: 40, r1143: 1, clear: ["ad", "mr"] }),
    counters({ p: 40, r1143: 25, clear: ["ad", "mr", "chaos"] }),
  ];

  for (let index = 1; index < steps.length; index++) {
    assert.ok(compareKeys(storyKey(steps[index]), storyKey(steps[index - 1])) > 0, `step ${index}`);
  }
});

test("counters are read with their finished routes in order, and wrong ones are refused", () => {
  const read = readCounters({ p: 40, r1141: 0, r1142: 3, r1143: 0, clear: ["mr", "ad"], end: { map: 544, x: 12, y: 30 } });
  assert.deepEqual(read.counters.clear, ["ad", "mr"]);
  assert.deepEqual(read.end, { map: 544, x: 12, y: 30 });
  assert.equal(readCounters({ p: 1, r1141: 0, r1142: 0, r1143: 0 }).end, undefined);
  assert.equal(readCounters({ p: 1, r1141: 0, r1142: 0, r1143: 0, end: null }).end, null);

  assert.ok(readCounters(null).error);
  assert.ok(readCounters({ p: -1, r1141: 0, r1142: 0, r1143: 0 }).error);
  assert.ok(readCounters({ p: 1.5, r1141: 0, r1142: 0, r1143: 0 }).error);
  assert.ok(readCounters({ p: 40, r1141: 2, r1142: 3, r1143: 0 }).error);
  assert.ok(readCounters({ p: 40, r1141: 0, r1142: 0, r1143: 0, clear: ["xy"] }).error);
  assert.ok(readCounters({ p: 40, r1141: 0, r1142: 0, r1143: 0, clear: ["ad", "ad"] }).error);
  assert.ok(readCounters({ p: 40, r1141: 0, r1142: 0, r1143: 0, end: { map: 0, x: 1, y: 1 } }).error);
});

test("the level caps a write names are read, and wrong ones are refused", () => {
  assert.deepEqual(readCounters({ p: 1, r1141: 0, r1142: 0, r1143: 0 }).caps, []);
  assert.deepEqual(readCounters({ p: 1, r1141: 0, r1142: 0, r1143: 0, caps: [15, 10] }).caps, [15, 10]);

  assert.ok(readCounters({ p: 1, r1141: 0, r1142: 0, r1143: 0, caps: "10" }).error);
  assert.ok(readCounters({ p: 1, r1141: 0, r1142: 0, r1143: 0, caps: [0] }).error);
  assert.ok(readCounters({ p: 1, r1141: 0, r1142: 0, r1143: 0, caps: [10.5] }).error);
  assert.ok(readCounters({ p: 1, r1141: 0, r1142: 0, r1143: 0, caps: [STORY_LIMITS.maxCap + 1] }).error);
  assert.ok(readCounters({ p: 1, r1141: 0, r1142: 0, r1143: 0, caps: Array.from({ length: STORY_LIMITS.maxCaps + 1 }, (_, index) => index + 1) }).error);
});

test("the world keeps every level cap a write named, lowest first, and a write naming fewer loses none", async () => {
  assert.deepEqual(mergeCaps([10, 18], [15, 10]), [10, 15, 18]);

  const { story } = makeStory();
  assert.deepEqual((await accepted(story, 0, { p: 7, caps: [10] })).caps, [10]);
  assert.deepEqual((await accepted(story, 1, { p: 8, caps: [15, 10] })).caps, [10, 15]);
  assert.deepEqual((await accepted(story, 2, { p: 9 })).caps, [10, 15], "a write without caps, as from an older game, keeps them");
  assert.deepEqual((await story.lockRoute("ad")).body.caps, [10, 15], "a route lock keeps them");
  assert.deepEqual((await story.get()).body.caps, [10, 15]);
});

test("the world keeps only the highest level caps once more than the limit came together", async () => {
  const { story } = makeStory({ ...STORY_LIMITS, maxCaps: 3 });
  await accepted(story, 0, { p: 7, caps: [10, 15, 18] });
  assert.deepEqual((await accepted(story, 1, { p: 8, caps: [20] })).caps, [15, 18, 20]);
});

test("a world nobody wrote a story for answers revision 0 without keys", async () => {
  const { story } = makeStory();
  const answer = await story.get();
  assert.equal(answer.status, 200);
  assert.deepEqual(answer.body, { rev: 0, wrev: 0, p: 0, r1141: 0, r1142: 0, r1143: 0, clear: [], part: "1", route: "none", done: [], end: null, comps: [], caps: [], checkpoints: [], at: 0 });
});

test("a write on the current revision is accepted and counts the revision up, with the same counters too", async () => {
  const { story, time } = makeStory();
  const first = await accepted(story, 0, { p: 5, end: { map: 12, x: 3, y: 4 } });
  assert.equal(first.rev, 1);
  assert.equal(first.keys, undefined);
  assert.deepEqual(first.end, { map: 12, x: 3, y: 4 });

  time.now = 2000;
  const second = await accepted(story, 1, { p: 5 }, OTHER);
  assert.equal(second.rev, 2);
  assert.deepEqual(second.end, { map: 12, x: 3, y: 4 }, "an endpoint left out stays");
  assert.equal(second.at, 2000);

  const fetched = (await story.get()).body;
  assert.equal(fetched.rev, 2);
  assert.equal(fetched.keys.v, OTHER.v);

  const cleared = await accepted(story, 2, { p: 6, end: null });
  assert.equal(cleared.end, null);
});

test("a write on a revision the relay never had gets 409 with the world's story", async () => {
  const { story } = makeStory();
  await accepted(story, 0, { p: 5 });
  await accepted(story, 1, { p: 6 }, OTHER);

  const late = await story.write(BOB, { base: 3, counters: counters({ p: 7 }), set: {} });
  assert.deepEqual([late.status, late.body.code, late.body.rev, late.body.p, late.body.keys.v, late.push], [409, "rev", 2, 6, OTHER.v, undefined]);
});

test("a write behind the world's story gets 409 even on the current revision", async () => {
  const { story } = makeStory();
  await accepted(story, 0, { p: 20 });
  const behind = await story.write(BOB, { base: 1, counters: counters({ p: 19 }), set: {} });
  assert.equal(behind.status, 409);
  assert.equal(behind.body.code, "behind");
});

test("a write into a later part keeps the story before it as that part's checkpoint", async () => {
  const { story, kept } = makeStory();
  await accepted(story, 0, { p: 18 }, { v: "70:n18" });
  const into2 = await accepted(story, 1, { p: 19 });
  assert.equal(into2.part, "2");
  assert.deepEqual(into2.checkpoints, ["1"]);

  const checkpoint = await story.checkpoint("1");
  assert.equal(checkpoint.status, 200);
  assert.equal(checkpoint.body.part, "1");
  assert.equal(checkpoint.body.rev, 1);
  assert.equal(checkpoint.body.wrev, 1);
  assert.equal(checkpoint.body.p, 18);
  assert.equal(checkpoint.body.keys.v, "70:n18");

  await accepted(story, 2, { p: 25 });
  assert.equal(kept.checkpoints.size, 1, "a write inside a part keeps no checkpoint");

  const none = await story.checkpoint("2");
  assert.equal(none.status, 404);
  assert.equal(none.body.code, "none");
  assert.equal((await story.checkpoint("x")).status, 400);
});

test("the first route chosen wins, and a finished route returns the world to the Great Decision with it disabled", async () => {
  const { story } = makeStory();
  await accepted(story, 0, { p: 39 });

  const locked = await story.lockRoute("ad");
  assert.equal(locked.status, 200);
  assert.equal(locked.body.locked, "ad");
  assert.equal(locked.body.route, "ad");
  assert.equal(locked.body.rev, 2);
  assert.equal(locked.body.wrev, 1);
  assert.equal(locked.push.rev, 2);
  const again = await story.lockRoute("ad");
  assert.equal(again.status, 200, "the same route again");
  assert.equal(again.push, undefined);

  const taken = await story.lockRoute("mr");
  assert.equal(taken.status, 409);
  assert.equal(taken.body.code, "route");
  assert.equal(taken.body.route, "ad");

  const wrongRoute = await story.write(BOB, { base: 1, counters: counters({ p: 40, r1142: 1 }), set: {} });
  assert.equal(wrongRoute.status, 409);
  assert.equal(wrongRoute.body.code, "route");

  const started = await accepted(story, 1, { p: 40, r1141: 1 });
  assert.equal(started.part, "ad");
  assert.equal(started.rev, 3, "a write that built on the story before the lock is taken");
  assert.deepEqual(started.checkpoints, ["3"]);

  const offRoute = await story.write(BOB, { base: 3, counters: counters({ p: 41 }), set: {} });
  assert.equal(offRoute.body.code, "route", "a story with no route under way once the world is on the locked one");

  const otherReturn = await story.write(BOB, { base: 3, counters: counters({ p: 39, clear: ["mr"] }), set: {} });
  assert.equal(otherReturn.body.code, "route", "a story back from a route the world never played, though further");
  const unplayed = await story.write(BOB, { base: 3, counters: counters({ p: 40, r1141: 2, clear: ["mr"] }), set: {} });
  assert.equal(unplayed.body.code, "route", "a finish of a route the world never played");

  await accepted(story, 3, { p: 40, r1141: 76 });
  const finished = await accepted(story, 4, { p: 40, r1141: 76, clear: ["ad"] });
  assert.deepEqual(finished.done, ["ad"]);
  assert.equal(finished.route, "ad", "the route stays until the world returned");
  const otherAfterFinish = await story.write(BOB, { base: 5, counters: counters({ p: 40, r1142: 80 }), set: {} });
  assert.equal(otherAfterFinish.body.code, "route", "another route's story before the world returned, though further");

  const returned = await accepted(story, 5, { p: 39, clear: ["ad"] });
  assert.equal(returned.route, "none");
  assert.equal(returned.part, "3");
  assert.deepEqual(returned.checkpoints, ["3", "ad"]);

  assert.equal((await story.lockRoute("ad")).body.code, "finished");
  assert.equal((await story.lockRoute("chaos")).body.code, "closed");
  assert.equal((await story.lockRoute("mr")).status, 200);
  assert.equal((await story.lockRoute("none")).status, 400);
});

test("a story with no route under way goes on while the world has not started the locked route", async () => {
  const { story } = makeStory();
  await accepted(story, 0, { p: 39 });
  assert.equal((await story.lockRoute("ad")).status, 200);

  const sideEvent = await accepted(story, 2, { p: 39 }, OTHER);
  assert.equal(sideEvent.route, "ad", "the lock stays");
  const boss = await accepted(story, 3, { p: 39 });
  assert.equal(boss.wrev, 4);

  const unplayed = await story.write(BOB, { base: 4, counters: counters({ p: 39, clear: ["mr"] }), set: {} });
  assert.equal(unplayed.body.code, "route", "a finish of a route the world never played");
  const otherRoute = await story.write(BOB, { base: 4, counters: counters({ p: 40, r1142: 1 }), set: {} });
  assert.equal(otherRoute.body.code, "route", "a start of another route");
  const started = await accepted(story, 4, { p: 40, r1141: 1 });
  assert.equal(started.route, "ad");
});

test("the third way opens once both other routes are finished", async () => {
  const { story } = makeStory();
  await accepted(story, 0, { p: 39, clear: ["ad", "mr"] });
  const locked = await story.lockRoute("chaos");
  assert.equal(locked.status, 200);
  assert.equal(locked.body.route, "chaos");
});

test("a world that finished every route, as a starting save that cleared them makes it, lets each route be chosen and played again", async () => {
  const { story } = makeStory();
  const all = ["ad", "mr", "chaos"];
  const decision = await accepted(story, 0, { p: 40, clear: all });
  assert.deepEqual(decision.done, all);

  assert.equal((await story.lockRoute("ad")).status, 200);
  const sideEvent = await accepted(story, 2, { p: 40, clear: all }, OTHER);
  assert.equal(sideEvent.route, "ad", "the lock stays through a write at the decision");

  const otherRoute = await story.write(BOB, { base: 3, counters: counters({ p: 40, r1142: 1, clear: all }), set: {} });
  assert.equal(otherRoute.status, 409, "another route's first step");
  const started = await accepted(story, 3, { p: 40, r1141: 1, clear: all });
  assert.equal(started.route, "ad", "the first step ranks below the decision, and is taken");
  assert.equal(started.part, "ad");
  const later = await accepted(story, 4, { p: 40, r1141: 30, clear: all });
  assert.equal(later.route, "ad");

  const returned = await accepted(story, 5, { p: 39, clear: all });
  assert.equal(returned.route, "none", "the return ends the lock");
  assert.equal((await story.lockRoute("ad")).status, 200, "the same route again");
});

test("a route lock before any write keeps revision 0 for the first write", async () => {
  const { story } = makeStory();
  assert.equal((await story.lockRoute("mr")).status, 200);
  const first = await accepted(story, 1, { p: 40, r1142: 1 });
  assert.equal(first.route, "mr");
  assert.deepEqual(first.checkpoints, [], "a story nobody wrote leaves no checkpoint");
});

test("leaving Part 3 again for the next route keeps the checkpoint of its first end", async () => {
  const { story } = makeStory();
  const first = { v: "70:n39" };
  await accepted(story, 0, { p: 39 }, first);
  assert.equal((await story.lockRoute("ad")).status, 200);
  await accepted(story, 2, { p: 40, r1141: 1 });
  await accepted(story, 3, { p: 40, r1141: 76, clear: ["ad"] });
  await accepted(story, 4, { p: 39, clear: ["ad"] }, OTHER);
  assert.equal((await story.lockRoute("mr")).status, 200);

  const second = await accepted(story, 6, { p: 40, r1142: 1, clear: ["ad"] });
  assert.equal(second.part, "mr");
  assert.deepEqual(second.checkpoints, ["3", "ad"]);

  const checkpoint = await story.checkpoint("3");
  assert.equal(checkpoint.body.keys.v, first.v);
  assert.equal(checkpoint.body.p, 39);
  assert.deepEqual(checkpoint.body.clear, [], "the checkpoint is the story before any route");
});

test("a route under way before the Great Decision is refused as behind", async () => {
  const { story } = makeStory();
  await accepted(story, 0, { p: 24 });
  const early = await story.write(BOB, { base: 1, counters: counters({ p: 24, r1141: 1 }), set: {} });
  assert.equal(early.status, 409);
  assert.equal(early.body.code, "behind");
  assert.equal(early.body.r1141, 0);
});

test("a story an older relay took with a route before the Great Decision is repaired by the next write", async () => {
  const { story, kept } = makeStory();
  await accepted(story, 0, { p: 24 });
  kept.story = { ...kept.story, counters: counters({ p: 24, r1141: 1 }), part: "ad", route: "ad", caps: [25, 65], checkpoints: ["1", "2"] };
  kept.checkpoints.set("2", { rev: 1, wrev: 1, counters: counters({ p: 24 }), part: "2", route: "none", done: [], end: null, lists: {}, at: 1000, by: ALICE });

  const repaired = await accepted(story, 1, { p: 24, caps: [25] }, OTHER);
  assert.equal(repaired.part, "2");
  assert.equal(repaired.r1141, 0);
  assert.equal(repaired.route, "none", "the route lock taken with it goes");
  assert.deepEqual(repaired.caps, [25], "and the level caps it named");
  assert.deepEqual(repaired.checkpoints, ["1"], "and the checkpoint of the part it seemed to leave");
  assert.equal(kept.checkpoints.size, 1, "the repaired story itself is no checkpoint");
  assert.equal((await story.checkpoint("2")).status, 404);

  await accepted(story, 2, { p: 34 });
  const left = await story.checkpoint("2");
  assert.equal(left.status, 200, "Part 2's real end is its checkpoint");
  assert.equal(left.body.keys.v, OTHER.v);
});

test("shared companions only grow, and the same ids again write nothing", async () => {
  const { story, kept } = makeStory();
  await accepted(story, 0, { p: 5 });

  const added = await story.addCompanions([382, 5, 382]);
  assert.equal(added.status, 200);
  assert.deepEqual(added.body.comps, [5, 382]);
  assert.equal(added.push.rev, 2);
  assert.equal(added.body.wrev, 1);

  const puts = kept.puts;
  const again = await story.addCompanions([5]);
  assert.equal(again.push, undefined);
  assert.equal(kept.puts, puts);

  const next = await accepted(story, 1, { p: 6 });
  assert.equal(next.rev, 3);
  assert.deepEqual(next.comps, [5, 382], "a write keeps the shared companions");

  assert.equal((await story.addCompanions([])).status, 400);
  assert.equal((await story.addCompanions([0])).status, 400);
  assert.equal((await story.addCompanions("5")).status, 400);
});

test("too many shared companions are refused", async () => {
  const { story } = makeStory({ ...STORY_LIMITS, maxCompanions: 2 });
  assert.equal((await story.addCompanions([1, 2])).status, 200);
  assert.equal((await story.addCompanions([3])).status, 413);
});

test("a wrong write is refused before it counts against the player's writes", async () => {
  const { story } = makeStory({ ...STORY_LIMITS, writes: { burst: 1, refillMs: 60_000 } });
  assert.equal((await story.write(ALICE, null)).status, 400);
  assert.equal((await story.write(ALICE, { base: -1, counters: counters(), set: {} })).status, 400);
  assert.equal((await story.write(ALICE, { base: 0, counters: counters(), blob: "c2VhbGVk" })).status, 400, "a sealed story without keys");
  assert.equal((await story.write(ALICE, { base: 0, counters: counters(), set: { v: "x" } })).status, 400);
  assert.equal((await story.write(ALICE, { base: 0, counters: { p: "1" }, set: {} })).status, 400);

  assert.equal((await story.write(ALICE, { base: 0, counters: counters(), set: {} })).status, 200);
  const tooOften = await story.write(ALICE, { base: 1, counters: counters(), set: {} });
  assert.equal(tooOften.status, 429);
  assert.equal(tooOften.body.code, "rate");
  assert.equal((await story.write(BOB, { base: 1, counters: counters(), set: {} })).status, 200, "each player has writes of their own");
});

test("taking back the route lock counts the revision up once and lets another route be chosen", async () => {
  const { story, kept } = makeStory();
  const none = await story.clearRoute();
  assert.deepEqual([none.body.cleared, none.push, kept.puts], [false, undefined, 0], "a world without a lock writes nothing");

  await accepted(story, 0, { p: 40 });
  await story.lockRoute("ad");
  const cleared = await story.clearRoute();
  assert.deepEqual([cleared.body.cleared, cleared.body.route, cleared.push.rev], [true, "none", 3]);
  assert.equal((await story.lockRoute("mr")).body.locked, "mr");
  assert.equal((await accepted(story, 1, { p: 40, r1142: 1 })).route, "mr", "a write on the revision before the lock is still taken");
});

test("taking back the route lock is refused while the world's story is on that route, and the story goes on", async () => {
  const { story, kept } = makeStory();
  await accepted(story, 0, { p: 39 });
  await story.lockRoute("ad");
  await accepted(story, 2, { p: 40, r1141: 1 });
  const puts = kept.puts;

  const refused = await story.clearRoute();
  assert.deepEqual([refused.status, refused.body.code, refused.body.route, refused.push], [409, "started", "ad", undefined]);
  assert.equal(kept.puts, puts, "a refused clear writes nothing");
  assert.equal((await story.lockRoute("mr")).body.code, "route", "the lock stays");
  assert.equal((await accepted(story, 3, { p: 40, r1141: 2 })).route, "ad", "the route's next write is taken");

  await accepted(story, 4, { p: 39, clear: ["ad"] });
  const returned = await story.clearRoute();
  assert.deepEqual([returned.status, returned.body.cleared], [200, false], "the return from the route took the lock back already");
});

test("a route lock is refused while the world's story is on another route without a lock", async () => {
  const { story, kept } = makeStory();
  await accepted(story, 0, { p: 39 });
  await story.lockRoute("ad");
  await accepted(story, 2, { p: 40, r1141: 1 });
  kept.story.route = "none";

  const other = await story.lockRoute("mr");
  assert.deepEqual([other.status, other.body.code, other.body.route], [409, "route", "none"]);
  const same = await story.lockRoute("ad");
  assert.deepEqual([same.status, same.body.locked], [200, "ad"], "the route the story is on locks again");
});

test("removing the story forgets it and its checkpoints", async () => {
  const { story } = makeStory();
  await accepted(story, 0, { p: 18 });
  await accepted(story, 1, { p: 19 });
  await story.remove();
  assert.equal((await story.get()).body.rev, 0);
  assert.equal((await story.checkpoint("1")).status, 404);
});

test("the routes are read from the address, and the router answers each", async () => {
  assert.deepEqual(storyRouteOf(new URL("https://relay/v1/worlds/0123456789abcdef0123456789abcdef/story")), { id: "0123456789abcdef0123456789abcdef", rest: [] });
  assert.deepEqual(storyRouteOf(new URL("https://relay/v1/worlds/0123456789abcdef0123456789abcdef/story/checkpoint/2")).rest, ["checkpoint", "2"]);
  assert.equal(storyRouteOf(new URL("https://relay/v1/worlds/0123456789abcdef0123456789abcdef/chat")), null);
  assert.equal(storyRouteOf(new URL("https://relay/v1/worlds/XYZ/story")), null);
  assert.equal(storyText(12), "story 12");

  const { story } = makeStory();
  const body = (value) => async () => JSON.stringify(value);
  assert.equal((await handleStoryRequest(story, "POST", [], body({ base: 0, counters: counters({ p: 18 }), set: {} }), ALICE)).status, 200);
  assert.equal((await handleStoryRequest(story, "GET", [], body(null), ALICE)).body.rev, 1);
  assert.equal((await handleStoryRequest(story, "POST", ["route"], body({ route: "ad" }), ALICE)).status, 200);
  assert.equal((await handleStoryRequest(story, "POST", ["companions"], body({ ids: [5] }), ALICE)).status, 200);
  assert.equal((await handleStoryRequest(story, "GET", ["checkpoint", "1"], body(null), ALICE)).status, 404);
  assert.equal((await handleStoryRequest(story, "DELETE", [], body(null), ALICE)).status, 404);
  assert.equal((await handleStoryRequest(story, "POST", [], async () => null, ALICE)).status, 413);
  assert.equal((await handleStoryRequest(story, "POST", [], async () => "x".repeat(STORY_LIMITS.maxBodyLength + 1), ALICE)).status, 413);
  assert.equal(ROUTE.none, "none");
});

/**
 * Writes a keyed story and expects it accepted.
 *
 * @param {WorldStory} story The story.
 * @param {string} player The writing player.
 * @param {number} base The revision the write builds on.
 * @param {object} set The lists of the keys it changes.
 * @param {object} [values] The counters that differ from 0.
 * @returns {Promise<{body: object, push: object, restore?: object}>} The answer's body, push and the push of pinned values after it.
 */
async function wrote(story, player, base, set, values = {}) {
  const answer = await story.write(player, { base, counters: counters(values), set });
  assert.equal(answer.status, 200, JSON.stringify(answer.body));
  assert.equal(answer.body.accepted, true);
  return { body: answer.body, push: answer.push, restore: answer.restore };
}

test("a keyed story's lists are read into keys and written back, and wrong ones are refused", () => {
  const read = readLists({ s: "5,12", sf: "7", v: "1001:n40,20:sQUI=,21:T", ss: "12.3.A", ssf: "12.3.B", a: "5:2173,16:1303", f: `${FROZEN};77|0` });
  assert.deepEqual([...read.keys], [["s5", "1"], ["s12", "1"], ["s7", "0"], ["v1001", "n40"], ["v20", "sQUI="], ["v21", "T"], ["ss12.3.A", "1"], ["ss12.3.B", "0"], ["a5", "2173"], ["a16", "1303"],
                                    ["f1234", FROZEN.slice(5)], ["f77", "0"]]);
  assert.deepEqual(listsOf(read.keys), { s: "5,12", sf: "7", v: "1001:n40,20:sQUI=,21:T", ss: "12.3.A", ssf: "12.3.B", a: "5:2173,16:1303", f: `${FROZEN};77|0` });
  assert.deepEqual(readLists({}).keys, new Map());
  assert.match(readLists({ s: "0" }).error, /switch ids/);
  assert.match(readLists({ v: "5:x" }).error, /variable ids/);
  assert.match(readLists({ ss: "12.3" }).error, /self switches/);
  assert.match(readLists({ a: "5:0" }).error, /affection/);
  assert.match(readLists({ f: "1234" }).error, /frozen fight/, "a frozen fight without its troop's bar");
  assert.match(readLists({ f: "0|map:1:2:3" }).error, /frozen fight/);
  assert.match(readLists({ f: "1234|map;1" }).error, /frozen fight/, "a semicolon splits the fight");
  assert.match(readLists({ f: "1234|map:1:2:3=x" }).error, /frozen fight/);
  assert.match(readLists({ f: `1234|${"1".repeat(STORY_LIMITS.maxFreezeLength + 1)}` }).error, /frozen fight/);
  assert.deepEqual([...readLists({ v: "5:n1" }).keys], [["v5", "n1"]], "a write of a released game has no frozen fights");
  assert.match(readLists({ s: 5 }).error, /texts/);
  assert.match(readLists(null).error, /JSON object/);
  assert.match(readLists({ s: "1,".repeat(STORY_LIMITS.maxListsLength) }).error, /at most/);
  assert.deepEqual(countersOf(readLists({ v: "1001:n40,1142:n3", s: "7097" }).keys, counters({ p: 1, r1141: 2 })),
                   { p: 40, r1141: 2, r1142: 3, r1143: 0, clear: ["mr"] }, "a counter the keys lack keeps the write's");
});

test("a keyed story starts with its first write, takes each key a write changes, and pushes only those", async () => {
  const { story } = makeStory();
  const first = await wrote(story, ALICE, 0, { s: "5", v: "1001:n10,30:n1" }, { p: 10 });
  assert.equal(first.body.rev, 1);
  assert.deepEqual(first.body.kept, { s: "", sf: "", v: "", ss: "", ssf: "", a: "", f: "" });
  assert.equal(first.body.moved, false);
  assert.deepEqual(first.push.delta, { s: "5", sf: "", v: "1001:n10,30:n1", ss: "", ssf: "", a: "", f: "" });
  assert.deepEqual([first.push.rev, first.push.prev, first.push.state.p], [1, 0, 10]);

  const second = await wrote(story, ALICE, 1, { s: "5", sf: "6", v: "30:n2" }, { p: 10 });
  assert.deepEqual(second.push.delta, { s: "", sf: "6", v: "30:n2", ss: "", ssf: "", a: "", f: "" }, "a key the write leaves as it is changes nothing");

  const fetched = (await story.get()).body;
  assert.deepEqual([fetched.rev, fetched.keyed, fetched.keys], [2, true, { s: "5", sf: "6", v: "1001:n10,30:n2", ss: "", ssf: "", a: "", f: "" }]);
  assert.equal((await story.get(2)).body.same, true, "the known revision comes back without its lists");
  assert.equal((await story.get(2)).body.keys, undefined);
  assert.equal((await story.get(1)).body.keys.v, "1001:n10,30:n2");
});

test("of two writes on the same revision, the first keeps the keys both changed, the second the rest", async () => {
  const { story } = makeStory();
  await wrote(story, ALICE, 0, { v: "1001:n10,50:n1,60:n1" }, { p: 10 });
  await wrote(story, ALICE, 1, { v: "50:n2" }, { p: 10 });
  const late = await wrote(story, BOB, 1, { v: "50:n3,60:n4" }, { p: 10 });
  assert.deepEqual(late.body.kept, { s: "", sf: "", v: "50:n2", ss: "", ssf: "", a: "", f: "" }, "the world's value of the key it kept");
  assert.equal(late.body.moved, true, "another write changed keys since its base");
  assert.equal(late.push.delta.v, "60:n4");
  assert.equal((await story.get()).body.keys.v, "1001:n10,50:n2,60:n4");
  const rebuilt = await wrote(story, BOB, 3, { v: "50:n3" }, { p: 10 });
  assert.equal(rebuilt.push.delta.v, "50:n3", "once the game built on the world's value it may change it");
});

test("a companion's affection keeps the highest value written, whichever write came first", async () => {
  const { story } = makeStory();
  await wrote(story, ALICE, 0, { v: "1001:n10" }, { p: 10 });
  await wrote(story, ALICE, 1, { a: "5:10" }, { p: 10 });
  const raised = await wrote(story, BOB, 1, { a: "5:20" }, { p: 10 });
  assert.equal(raised.push.delta.a, "5:20", "a higher value goes in over a write since its base");
  const lower = await wrote(story, ALICE, 3, { a: "5:15" }, { p: 10 });
  assert.deepEqual([lower.body.kept.a, lower.push.delta.a], ["5:20", ""], "a lower value comes back as the world's");
  assert.equal((await story.get()).body.keys.a, "5:20");
});

test("a frozen raid boss fight is one key of its troop, which the write that ends it replaces for every game", async () => {
  const { story } = makeStory();
  const first = await wrote(story, ALICE, 0, { v: "1001:n18", f: `${FROZEN};88|map:5:6:7|map:5:6:7|0|5|1:2:3:4:0:x:0:0:0:0:0:1:0||5.1.1.2|` }, { p: 18 });
  assert.equal(first.push.delta.f, `${FROZEN};88|map:5:6:7|map:5:6:7|0|5|1:2:3:4:0:x:0:0:0:0:0:1:0||5.1.1.2|`);

  const grown = await wrote(story, BOB, 1, { f: `${FROZEN},x138.4.A~T` }, { p: 18 });
  assert.equal(grown.push.delta.f, `${FROZEN},x138.4.A~T`, "a fight that holds more keys replaces the troop's key alone");

  const ended = await wrote(story, BOB, 2, { f: "1234|0" }, { p: 18 });
  assert.equal(ended.push.delta.f, "1234|0", "every game hears of the end, also one that only reads");
  const fetched = (await story.get()).body;
  assert.equal(fetched.keys.f, "1234|0;88|map:5:6:7|map:5:6:7|0|5|1:2:3:4:0:x:0:0:0:0:0:1:0||5.1.1.2|");
  assert.equal(fetched.keys.v, "1001:n18");

  const late = await wrote(story, ALICE, 2, { f: `${FROZEN},s40~F` }, { p: 18 });
  assert.equal(late.body.kept.f, "1234|0", "a write that built on the fight before its end keeps the end");

  const fresh = await wrote(story, ALICE, 4, { f: FROZEN }, { p: 18 });
  assert.deepEqual([fresh.body.kept.f, fresh.push.delta.f], ["1234|0", ""], "the end is final: a fresh freeze on the current revision never replaces it");
  assert.equal((await story.get()).body.keys.f.split(";")[0], "1234|0");
});

test("the end of a frozen raid boss fight goes in over a freeze another write brought since its base", async () => {
  const { story } = makeStory();
  await wrote(story, ALICE, 0, { v: "1001:n18" }, { p: 18 });
  await wrote(story, ALICE, 1, { f: FROZEN }, { p: 18 });
  const ended = await wrote(story, BOB, 1, { f: "1234|0" }, { p: 18 });
  assert.deepEqual([ended.body.kept.f, ended.push.delta.f], ["", "1234|0"], "the end beats the first writer");
  assert.equal((await story.get()).body.keys.f, "1234|0");
});

test("a keyed write on a revision older than the writes the story remembers, or behind it, gets 409 with the world's lists", async () => {
  const { story } = makeStory({ ...STORY_LIMITS, logWrites: 2 });
  await wrote(story, ALICE, 0, { v: "1001:n10" }, { p: 10 });
  await wrote(story, ALICE, 1, { v: "40:n1" }, { p: 10 });
  await wrote(story, ALICE, 2, { v: "40:n2" }, { p: 10 });
  await wrote(story, ALICE, 3, { v: "40:n3" }, { p: 10 });
  const old = await story.write(BOB, { base: 1, counters: counters({ p: 10 }), set: { v: "41:n1" } });
  assert.deepEqual([old.status, old.body.code, old.body.keys.v], [409, "rev", "1001:n10,40:n3"]);
  assert.equal((await story.write(BOB, { base: 9, counters: counters({ p: 10 }), set: {} })).body.code, "rev", "a revision the relay never had");
  const behind = await story.write(BOB, { base: 4, counters: counters({ p: 9 }), set: { v: "1001:n9" } });
  assert.deepEqual([behind.status, behind.body.code], [409, "behind"]);
  assert.equal((await story.write(BOB, { base: 4, counters: counters({ p: 10 }), set: { v: "x" } })).status, 400);
});

test("a write that changes pinned keys goes in without them, as a clean write, and a revision after it tells every game the pinned values", async () => {
  const { story, kept } = makeStory();
  await wrote(story, ALICE, 0, { s: "40", v: "1001:n37,1201:n0,1219:n2" }, { p: 37 });
  kept.story.pinned = { v1201: "n0", s2950: "0" };

  const write = await wrote(story, BOB, 1, { s: "2950", v: "1201:n8,1219:n3" }, { p: 37 });
  assert.deepEqual([write.body.rev, write.body.kept, write.body.moved], [2, { s: "", sf: "", v: "", ss: "", ssf: "", a: "", f: "" }, false], "released games take an answer without kept keys as their write taken whole");
  assert.deepEqual([write.push.rev, write.push.delta.v, write.push.delta.s], [2, "1219:n3", ""], "the player's other keys go in");
  assert.deepEqual([write.restore.rev, write.restore.prev, write.restore.state.wrev, write.restore.delta.v, write.restore.delta.sf], [3, 2, 3, "1201:n0", "2950"]);
  assert.deepEqual((await story.get()).body.keys.v, "1001:n37,1201:n0,1219:n3");

  const next = await wrote(story, ALICE, 2, { v: "1219:n4" }, { p: 37 });
  assert.deepEqual([next.body.rev, next.body.moved, next.restore], [4, false, undefined], "the restoring revision moves no key a later write built on");
  const same = await wrote(story, ALICE, 4, { v: "1201:n0" }, { p: 37 });
  assert.equal(same.restore, undefined, "a pinned key written at its value needs no restoring");
});

test("the rules an older relay pinned keys off with keep those keys off", async () => {
  const { story, kept } = makeStory();
  await wrote(story, ALICE, 0, { s: "40", sf: "2902", v: "1001:n37,1201:n0,1219:n2" }, { p: 37 });
  kept.story.pins = ["s2901-2962", "v1201-1218", "ss845-936"];
  const write = await wrote(story, ALICE, 1, { v: "1201:n8,1219:n3", ss: "860.1.A", s: "2950" }, { p: 37 });
  assert.deepEqual([write.push.delta.v, write.push.delta.ss, write.restore.delta.v, write.restore.delta.sf, write.restore.delta.ssf], ["1219:n3", "", "1201:n0", "2950", "860.1.A"]);
  assert.equal((await story.get()).body.keys.v, "1001:n37,1201:n0,1219:n3");
});

test("a story an older relay kept sealed counts as one nobody wrote key by key, and games that keep no keys are turned away", async () => {
  const { story, kept } = makeStory();
  kept.story = { ...story.first(), rev: 2, wrev: 2, counters: counters({ p: 6 }), blob: "c2VhbGVk" };
  const fetched = (await story.get()).body;
  assert.deepEqual([fetched.rev, fetched.p, fetched.keyed, fetched.keys, fetched.blob, await story.keys()], [2, 6, undefined, undefined, undefined, undefined]);
  assert.equal((await story.write(ALICE, { base: 1, counters: counters({ p: 6 }), set: { v: "1001:n6" } })).body.code, "rev", "only on the story's own revision");

  const first = await wrote(story, ALICE, 2, { v: "1001:n6,70:n1" }, { p: 6 });
  assert.equal(first.push.delta.v, "1001:n6,70:n1");
  assert.equal(kept.story.blob, undefined, "the sealed story goes with the first write");
  assert.deepEqual([...(await story.keys())], [["v1001", "n6"], ["v70", "n1"]], "a keyed story hands its keys to the story tracks");

  assert.equal(keylessGame(["raid"]), true);
  assert.equal(keylessGame(["raid", "keys"]), false);
  assert.equal(keylessGameRefusal().body.code, "update");
});

test("a keyed story's part checkpoint holds its lists, and a route lock pushes the state alone", async () => {
  const { story } = makeStory();
  await wrote(story, ALICE, 0, { v: "1001:n18,80:n1" }, { p: 18 });
  await wrote(story, ALICE, 1, { v: "1001:n19" }, { p: 19 });
  const checkpoint = (await story.checkpoint("1")).body;
  assert.deepEqual([checkpoint.keyed, checkpoint.keys.v, checkpoint.part], [true, "1001:n18,80:n1", "1"]);

  await wrote(story, ALICE, 2, { v: "1001:n40" }, { p: 40 });
  const locked = await story.lockRoute("ad");
  assert.deepEqual([locked.push.rev, locked.push.prev, locked.push.delta.v, locked.push.state.route], [4, 3, "", "ad"]);
  assert.equal(typeof (await makeStory().story.lockRoute("ad")).push, "number", "a story nobody wrote is no keyed one");
});

test("a write's push names what it changed while it fits a frame, else the revision alone", () => {
  assert.equal(storyPushText(7), "story 7");
  const push = { rev: 8, prev: 7, delta: { s: "5", sf: "", v: "", ss: "", ssf: "" }, state: { rev: 8 } };
  assert.equal(storyPushText(push), `storyd ${JSON.stringify(push)}`);
  assert.equal(storyPushText({ ...push, delta: { ...push.delta, s: "1,".repeat(STORY_LIMITS.maxDeltaLength) } }), "story 8");
});
