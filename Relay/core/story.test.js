//----------------------------------------------------------------
//  story.test.js
//
//  Changelog:
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { PART, ROUTE, STORY_LIMITS, WorldStory, compareKeys, handleStoryRequest, partOf, readCounters, storyKey, storyRouteOf, storyText } from "./story.js";

/**
 * A player's id.
 */
const ALICE = "a1".repeat(16);

/**
 * Another player's id.
 */
const BOB = "b2".repeat(16);

/**
 * Some sealed story, as base64.
 */
const BLOB = "c2VhbGVk";

/**
 * Another sealed story.
 */
const OTHER_BLOB = "b3RoZXI=";

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
 * @param {string} [blob] The sealed story.
 * @returns {Promise<object>} The answer's body.
 */
async function accepted(story, base, values, blob = BLOB) {
  const answer = await story.write(ALICE, { base, counters: counters(values), blob });
  assert.equal(answer.status, 200, JSON.stringify(answer.body));
  assert.equal(answer.body.accepted, true);
  assert.equal(answer.push, answer.body.rev);
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

test("a world nobody wrote a story for answers revision 0 without a sealed story", async () => {
  const { story } = makeStory();
  const answer = await story.get();
  assert.equal(answer.status, 200);
  assert.deepEqual(answer.body, { rev: 0, wrev: 0, p: 0, r1141: 0, r1142: 0, r1143: 0, clear: [], part: "1", route: "none", done: [], end: null, comps: [], checkpoints: [], at: 0, blob: "" });
});

test("a write on the current revision is accepted and counts the revision up, with the same counters too", async () => {
  const { story, time } = makeStory();
  const first = await accepted(story, 0, { p: 5, end: { map: 12, x: 3, y: 4 } });
  assert.equal(first.rev, 1);
  assert.equal(first.blob, undefined);
  assert.deepEqual(first.end, { map: 12, x: 3, y: 4 });

  time.now = 2000;
  const second = await accepted(story, 1, { p: 5 }, OTHER_BLOB);
  assert.equal(second.rev, 2);
  assert.deepEqual(second.end, { map: 12, x: 3, y: 4 }, "an endpoint left out stays");
  assert.equal(second.at, 2000);

  const fetched = (await story.get()).body;
  assert.equal(fetched.rev, 2);
  assert.equal(fetched.blob, OTHER_BLOB);

  const cleared = await accepted(story, 2, { p: 6, end: null });
  assert.equal(cleared.end, null);
});

test("a write on an older revision gets 409 with the world's story, so two writers never overwrite each other", async () => {
  const { story } = makeStory();
  await accepted(story, 0, { p: 5 });
  await accepted(story, 1, { p: 6 }, OTHER_BLOB);

  const late = await story.write(BOB, { base: 1, counters: counters({ p: 7 }), blob: BLOB });
  assert.equal(late.status, 409);
  assert.equal((await story.write(BOB, { base: 3, counters: counters({ p: 7 }), blob: BLOB })).body.code, "rev", "a revision the relay never had");
  assert.equal(late.body.code, "rev");
  assert.equal(late.body.rev, 2);
  assert.equal(late.body.p, 6);
  assert.equal(late.body.blob, OTHER_BLOB);
  assert.equal(late.push, undefined);
});

test("a write behind the world's story gets 409 even on the current revision", async () => {
  const { story } = makeStory();
  await accepted(story, 0, { p: 20 });
  const behind = await story.write(BOB, { base: 1, counters: counters({ p: 19 }), blob: BLOB });
  assert.equal(behind.status, 409);
  assert.equal(behind.body.code, "behind");
});

test("a write into a later part keeps the story before it as that part's checkpoint", async () => {
  const { story, kept } = makeStory();
  await accepted(story, 0, { p: 18 }, "cGFydDE=");
  const into2 = await accepted(story, 1, { p: 19 });
  assert.equal(into2.part, "2");
  assert.deepEqual(into2.checkpoints, ["1"]);

  const checkpoint = await story.checkpoint("1");
  assert.equal(checkpoint.status, 200);
  assert.equal(checkpoint.body.part, "1");
  assert.equal(checkpoint.body.rev, 1);
  assert.equal(checkpoint.body.wrev, 1);
  assert.equal(checkpoint.body.p, 18);
  assert.equal(checkpoint.body.blob, "cGFydDE=");

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
  assert.equal(locked.push, 2);
  const again = await story.lockRoute("ad");
  assert.equal(again.status, 200, "the same route again");
  assert.equal(again.push, undefined);

  const taken = await story.lockRoute("mr");
  assert.equal(taken.status, 409);
  assert.equal(taken.body.code, "route");
  assert.equal(taken.body.route, "ad");

  const wrongRoute = await story.write(BOB, { base: 1, counters: counters({ p: 40, r1142: 1 }), blob: BLOB });
  assert.equal(wrongRoute.status, 409);
  assert.equal(wrongRoute.body.code, "route");

  const started = await accepted(story, 1, { p: 40, r1141: 1 });
  assert.equal(started.part, "ad");
  assert.equal(started.rev, 3, "a write that built on the story before the lock is taken");
  assert.deepEqual(started.checkpoints, ["3"]);

  const offRoute = await story.write(BOB, { base: 3, counters: counters({ p: 41 }), blob: BLOB });
  assert.equal(offRoute.body.code, "route", "a story with no route under way once the world is on the locked one");

  const otherReturn = await story.write(BOB, { base: 3, counters: counters({ p: 39, clear: ["mr"] }), blob: BLOB });
  assert.equal(otherReturn.body.code, "route", "a story back from a route the world never played, though further");
  const unplayed = await story.write(BOB, { base: 3, counters: counters({ p: 40, r1141: 2, clear: ["mr"] }), blob: BLOB });
  assert.equal(unplayed.body.code, "route", "a finish of a route the world never played");

  await accepted(story, 3, { p: 40, r1141: 76 });
  const finished = await accepted(story, 4, { p: 40, r1141: 76, clear: ["ad"] });
  assert.deepEqual(finished.done, ["ad"]);
  assert.equal(finished.route, "ad", "the route stays until the world returned");
  const otherAfterFinish = await story.write(BOB, { base: 5, counters: counters({ p: 40, r1142: 80 }), blob: BLOB });
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

  const sideEvent = await accepted(story, 2, { p: 39 }, OTHER_BLOB);
  assert.equal(sideEvent.route, "ad", "the lock stays");
  const boss = await accepted(story, 3, { p: 39 });
  assert.equal(boss.wrev, 4);

  const unplayed = await story.write(BOB, { base: 4, counters: counters({ p: 39, clear: ["mr"] }), blob: BLOB });
  assert.equal(unplayed.body.code, "route", "a finish of a route the world never played");
  const otherRoute = await story.write(BOB, { base: 4, counters: counters({ p: 40, r1142: 1 }), blob: BLOB });
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

test("a route lock before any write keeps revision 0 for the first write", async () => {
  const { story } = makeStory();
  assert.equal((await story.lockRoute("mr")).status, 200);
  const first = await accepted(story, 1, { p: 40, r1142: 1 });
  assert.equal(first.route, "mr");
  assert.deepEqual(first.checkpoints, [], "a story without a sealed story leaves no checkpoint");
});

test("shared companions only grow, and the same ids again write nothing", async () => {
  const { story, kept } = makeStory();
  await accepted(story, 0, { p: 5 });

  const added = await story.addCompanions([382, 5, 382]);
  assert.equal(added.status, 200);
  assert.deepEqual(added.body.comps, [5, 382]);
  assert.equal(added.push, 2);
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
  const { story } = makeStory({ ...STORY_LIMITS, maxBlobLength: 8, writes: { burst: 1, refillMs: 60_000 } });
  assert.equal((await story.write(ALICE, null)).status, 400);
  assert.equal((await story.write(ALICE, { base: -1, counters: counters(), blob: BLOB })).status, 400);
  assert.equal((await story.write(ALICE, { base: 0, counters: counters(), blob: "" })).status, 400);
  assert.equal((await story.write(ALICE, { base: 0, counters: counters(), blob: "not base64!" })).status, 400);
  assert.equal((await story.write(ALICE, { base: 0, counters: counters(), blob: "QUJDREVGR0hJ" })).status, 400);
  assert.equal((await story.write(ALICE, { base: 0, counters: { p: "1" }, blob: BLOB })).status, 400);

  assert.equal((await story.write(ALICE, { base: 0, counters: counters(), blob: BLOB })).status, 200);
  const tooOften = await story.write(ALICE, { base: 1, counters: counters(), blob: BLOB });
  assert.equal(tooOften.status, 429);
  assert.equal(tooOften.body.code, "rate");
  assert.equal((await story.write(BOB, { base: 1, counters: counters(), blob: BLOB })).status, 200, "each player has writes of their own");
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
  assert.equal((await handleStoryRequest(story, "POST", [], body({ base: 0, counters: counters({ p: 18 }), blob: BLOB }), ALICE)).status, 200);
  assert.equal((await handleStoryRequest(story, "GET", [], body(null), ALICE)).body.rev, 1);
  assert.equal((await handleStoryRequest(story, "POST", ["route"], body({ route: "ad" }), ALICE)).status, 200);
  assert.equal((await handleStoryRequest(story, "POST", ["companions"], body({ ids: [5] }), ALICE)).status, 200);
  assert.equal((await handleStoryRequest(story, "GET", ["checkpoint", "1"], body(null), ALICE)).status, 404);
  assert.equal((await handleStoryRequest(story, "DELETE", [], body(null), ALICE)).status, 404);
  assert.equal((await handleStoryRequest(story, "POST", [], async () => null, ALICE)).status, 413);
  assert.equal((await handleStoryRequest(story, "POST", [], async () => "x".repeat(STORY_LIMITS.maxBodyLength + 1), ALICE)).status, 413);
  assert.equal(ROUTE.none, "none");
});
