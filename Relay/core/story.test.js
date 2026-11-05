//----------------------------------------------------------------
//  story.test.js
//
//  Changelog:
//      Paulinchen  2026-11-05: Dropped the tests of the games' story writes, checkpoint reads and route locks over HTTP, and covered the keyed story as world data
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
  PART, ROUTE, STORY_LIMITS, WorldStory, compareKeys, countersOf, handleStoryRequest, listsOf, mergeCaps, partOf, readLists, storyKey, storyPushText, storyRouteOf, storyText,
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
 * Keeps a story as an older game wrote it key by key, which the relay keeps as world data.
 *
 * @param {{story: object | undefined}} kept What the story's store keeps.
 * @param {object} lists The story's lists.
 * @param {object} values The counters that differ from 0.
 * @param {object} [extra] Fields of the story that differ, such as its revision or route.
 */
function keepKeyed(kept, lists, values, extra = {}) {
  const rev = extra.rev ?? 1;
  const storyCounters = counters(values);
  kept.story = {
    rev, wrev: rev, counters: storyCounters, part: partOf(storyCounters), route: "none", done: [], end: null, comps: [], caps: [], checkpoints: [], at: 1000, by: ALICE,
    lists: { s: "", sf: "", v: "", ss: "", ssf: "", a: "", f: "", ...lists }, log: [], logBase: rev, ...extra,
  };
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

test("the world keeps every level cap, lowest first", () => {
  assert.deepEqual(mergeCaps([10, 18], [15, 10]), [10, 15, 18]);
});

test("a world nobody wrote a story for answers revision 0 without keys", async () => {
  const { story } = makeStory();
  const answer = await story.get();
  assert.equal(answer.status, 200);
  assert.deepEqual(answer.body, { rev: 0, wrev: 0, p: 0, r1141: 0, r1142: 0, r1143: 0, clear: [], part: "1", route: "none", done: [], end: null, comps: [], caps: [], checkpoints: [], at: 0 });
});

test("a story older games wrote key by key is read with its keys, without them at the known revision, and hands its keys to the story tracks", async () => {
  const { story, kept } = makeStory();
  keepKeyed(kept, { s: "5", v: "1001:n10,30:n2" }, { p: 10 }, { rev: 2 });

  const fetched = (await story.get()).body;
  assert.deepEqual([fetched.rev, fetched.p, fetched.keyed, fetched.keys.v], [2, 10, true, "1001:n10,30:n2"]);
  assert.deepEqual([(await story.get(2)).body.same, (await story.get(2)).body.keys], [true, undefined]);
  assert.deepEqual([...(await story.keys())], [["s5", "1"], ["v1001", "n10"], ["v30", "n2"]]);
});

test("a story an older relay kept sealed counts as one nobody wrote key by key", async () => {
  const { story, kept } = makeStory();
  kept.story = { ...story.first(), rev: 2, wrev: 2, counters: counters({ p: 6 }), blob: "c2VhbGVk" };
  const fetched = (await story.get()).body;
  assert.deepEqual([fetched.rev, fetched.p, fetched.keyed, fetched.keys, fetched.blob, await story.keys()], [2, 6, undefined, undefined, undefined, undefined]);
});

test("an admin's keys repair a story an older game wrote with a route under way before the Great Decision", async () => {
  const { story, kept } = makeStory();
  keepKeyed(kept, { v: "1001:n24,1141:n1" }, { p: 24, r1141: 1 }, { part: "ad", route: "ad", caps: [25, 65], checkpoints: ["1", "2"] });
  kept.checkpoints.set("2", { rev: 1, wrev: 1, counters: counters({ p: 24 }), part: "2", route: "none", done: [], end: null, lists: {}, at: 1000, by: ALICE });

  const repaired = await story.setKeys({ v: { 1141: 0 } }, ALICE);
  assert.equal(repaired.status, 200, JSON.stringify(repaired.body));
  assert.deepEqual([repaired.body.part, repaired.body.r1141, repaired.body.route], ["2", 0, "none"], "the route lock taken with it goes");
  assert.deepEqual([repaired.body.caps, repaired.body.checkpoints], [[], ["1"]], "and the level caps and the checkpoint of the part it seemed to leave");
});

test("shared companions only grow, and the same ids again write nothing", async () => {
  const { story, kept } = makeStory();
  keepKeyed(kept, { v: "1001:n5" }, { p: 5 });

  const added = await story.addCompanions([382, 5, 382]);
  assert.equal(added.status, 200);
  assert.deepEqual(added.body.comps, [5, 382]);
  assert.deepEqual([added.push.rev, added.push.delta.v, added.body.wrev], [2, "", 1], "a keyed story pushes the state alone");

  const puts = kept.puts;
  const again = await story.addCompanions([5]);
  assert.equal(again.push, undefined);
  assert.equal(kept.puts, puts);
  assert.equal(typeof (await makeStory().story.addCompanions([5])).push, "number", "a story nobody wrote pushes its revision");

  assert.equal((await story.addCompanions([])).status, 400);
  assert.equal((await story.addCompanions([0])).status, 400);
  assert.equal((await story.addCompanions("5")).status, 400);
});

test("too many shared companions are refused", async () => {
  const { story } = makeStory({ ...STORY_LIMITS, maxCompanions: 2 });
  assert.equal((await story.addCompanions([1, 2])).status, 200);
  assert.equal((await story.addCompanions([3])).status, 413);
});

test("taking back the route lock counts the revision up once, and is refused while the world's story is on that route", async () => {
  const { story, kept } = makeStory();
  const none = await story.clearRoute();
  assert.deepEqual([none.body.cleared, none.push, kept.puts], [false, undefined, 0], "a world without a lock writes nothing");

  keepKeyed(kept, { v: "1001:n40" }, { p: 40 }, { route: "ad", rev: 2 });
  const cleared = await story.clearRoute();
  assert.deepEqual([cleared.body.cleared, cleared.body.route, cleared.push.rev], [true, "none", 3]);

  keepKeyed(kept, { v: "1001:n40,1141:n1" }, { p: 40, r1141: 1 }, { route: "ad", rev: 4 });
  const puts = kept.puts;
  const refused = await story.clearRoute();
  assert.deepEqual([refused.status, refused.body.code, refused.body.route, refused.push, kept.puts], [409, "started", "ad", undefined, puts]);
});

test("removing the story forgets it and its checkpoints", async () => {
  const { story, kept } = makeStory();
  keepKeyed(kept, { v: "1001:n19" }, { p: 19 }, { checkpoints: ["1"] });
  kept.checkpoints.set("1", { rev: 1, part: "1" });
  await story.remove();
  assert.deepEqual([(await story.get()).body.rev, kept.checkpoints.size], [0, 0]);
});

test("the routes are read from the address, and the router answers the reads and the shared companions alone", async () => {
  assert.deepEqual(storyRouteOf(new URL("https://relay/v1/worlds/0123456789abcdef0123456789abcdef/story")), { id: "0123456789abcdef0123456789abcdef", rest: [] });
  assert.deepEqual(storyRouteOf(new URL("https://relay/v1/worlds/0123456789abcdef0123456789abcdef/story/companions")).rest, ["companions"]);
  assert.equal(storyRouteOf(new URL("https://relay/v1/worlds/0123456789abcdef0123456789abcdef/chat")), null);
  assert.equal(storyRouteOf(new URL("https://relay/v1/worlds/XYZ/story")), null);
  assert.equal(storyText(12), "story 12");

  const { story, kept } = makeStory();
  keepKeyed(kept, { v: "1001:n40" }, { p: 40 });
  const body = (value) => async () => JSON.stringify(value);
  assert.equal((await handleStoryRequest(story, "GET", [], body(null), ALICE)).body.rev, 1);
  assert.equal((await handleStoryRequest(story, "POST", ["companions"], body({ ids: [5] }), ALICE)).status, 200);
  assert.equal((await handleStoryRequest(story, "POST", ["companions"], async () => null, ALICE)).status, 413);

  for (const [method, rest] of [["POST", []], ["POST", ["route"]], ["GET", ["checkpoint", "1"]], ["DELETE", []]]) {
    assert.equal((await handleStoryRequest(story, method, rest, body({ base: 1, counters: counters({ p: 41 }), set: {}, route: "ad" }), ALICE)).status, 404, `${method} ${rest.join("/")}`);
  }

  assert.deepEqual([(await story.get()).body.p, (await story.get()).body.route], [40, "none"], "no game writes the story over HTTP");
  assert.equal(ROUTE.none, "none");
});

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

test("a write's push names what it changed while it fits a frame, else the revision alone", () => {
  assert.equal(storyPushText(7), "story 7");
  const push = { rev: 8, prev: 7, delta: { s: "5", sf: "", v: "", ss: "", ssf: "" }, state: { rev: 8 } };
  assert.equal(storyPushText(push), `storyd ${JSON.stringify(push)}`);
  assert.equal(storyPushText({ ...push, delta: { ...push.delta, s: "1,".repeat(STORY_LIMITS.maxDeltaLength) } }), "story 8");
});
