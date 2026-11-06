//----------------------------------------------------------------
//  sqlite_store.test.js
//
//  Changelog:
//      Paulinchen  2026-11-06: Checked the database in memory without a path
//                            - Read the kept story through its keys
//                            - Kept the derived index through the relay's own call
//      Paulinchen  2026-11-05: Kept the story the store test starts from as older games wrote it, as games write no story over HTTP
//      Paulinchen  2026-10-31: Covered the story tracks' run entries kept over a restart and dropped with their track
//                            - Covered the place a world's log starts at kept over a restart
//                            - Wrote the story kept over a restart key by key
//                            - Covered the time the world's track last changed kept over a restart
//      Paulinchen  2026-10-23: Covered the story mapping, its rows' changes and its index kept over a restart, and a batch that fails kept not at all
//                            - Covered a Raid World's story tracks kept over a restart, a dropped track and a removed world
//      Paulinchen  2026-10-22: Covered the release control kept over a restart beside the newest release seen
//      Paulinchen  2026-10-12: Covered a trade's sealed offers kept beside it over a restart
//      Paulinchen  2026-10-10: Covered boss pools that keep the share of a raid max HP left over a restart
//      Paulinchen  2026-10-09: Covered a Raid World's boss pools kept over a restart
//      Paulinchen  2026-10-08: Covered a Raid World's story and its checkpoints kept over a restart
//      Paulinchen  2026-10-07: Covered a world's chat kept and removed with the world
//                            - Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { WorldBosses } from "../core/bosses.js";
import { Directory, playerIdOf, sha256Hex } from "../core/directory.js";
import { ModCatalog, zipHashes } from "../core/mods.js";
import { WorldStory } from "../core/story.js";
import { MAPPING_LIMITS, StoryMapping } from "../core/story_mapping.js";
import { StoryTracks } from "../core/story_tracks.js";
import { makeUpload, makeZip } from "../core/test_zip.js";
import { TradeBook } from "../core/trades.js";
import { openStores } from "./server.js";
import { openSqliteStores } from "./sqlite_store.js";

/**
 * The creator's player key.
 */
const CREATOR = "c0".repeat(16);

/**
 * Another player's key, an admin of the catalog.
 */
const OTHER = "0f".repeat(16);

/**
 * The auth key of the test world.
 */
const AUTH = "ab".repeat(32);

/**
 * The test world's id.
 */
const WORLD = "0123456789abcdef0123456789abcdef";

/**
 * The folder the test database lives in, deleted afterwards.
 */
let folder;

/**
 * The test database's path.
 */
let path;

before(() => {
  folder = mkdtempSync(join(tmpdir(), "mgq-relay-"));
  path = join(folder, "relay.sqlite");
});

after(() => rmSync(folder, { recursive: true, force: true }));

/**
 * Opens the directory, the catalog and the trades over the test database.
 *
 * @param {string[]} [admins] The admins' player ids.
 * @returns {{stores: ReturnType<typeof openSqliteStores>, directory: Directory, mods: ModCatalog, trades: TradeBook}} The stores and what runs over them.
 */
function openAll(admins = []) {
  const stores = openSqliteStores(path);
  const directory = new Directory(stores.directory, { admins });
  const mods = new ModCatalog(stores.mods, { admins });
  const trades = new TradeBook(stores.trades, (id) => stores.directory.get(id));
  return { stores, directory, mods, trades };
}

test("worlds, starting saves, mods, their zips and trades outlast closing the database", async () => {
  const admins = [await playerIdOf(OTHER)];
  const save = new Uint8Array(300_000).map((_, index) => index % 251);
  const zip = await makeZip([["Pack.rb", "# pack", true], ["Pack/a.luka", "A"]]);
  const files = await zipHashes(zip);
  const trade = "7".repeat(32);
  const first = openAll(admins);

  const created = await first.directory.create({ id: WORLD, name: "Kept World", seats: 4, player: CREATOR, playerName: "Creator", authHash: await sha256Hex(AUTH), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) }, start: true, hidden: true });
  assert.equal(created.status, 201);
  assert.equal((await first.directory.putStart(WORLD, CREATOR, save)).status, 200);
  assert.equal((await first.mods.upload(OTHER, "Pack", "1.0", makeUpload(files, zip))).status, 200);
  await first.directory.presence(WORLD, [{ player: await playerIdOf(OTHER), name: "Other" }]);
  assert.deepEqual((await first.trades.commit(trade, { player: OTHER, world: WORLD, partner: await playerIdOf(CREATOR), hash: "ab".repeat(32), sealed: "Qg==" })).body, { state: "pending" });
  assert.equal((await first.directory.say(WORLD, { player: await playerIdOf(OTHER), name: "Other" }, "kept line")).n, 1);
  first.stores.close();

  const second = openAll(admins);
  const [world] = (await second.directory.list(CREATOR)).body.worlds;
  assert.deepEqual([world.id, world.name, world.hidden, world.start, world.members.length], [WORLD, "Kept World", true, "ready", 2]);
  assert.deepEqual((await second.directory.chat(WORLD, CREATOR)).body.lines.map((line) => line.text), ["kept line"]);
  const fetched = await second.directory.getStart(WORLD, OTHER, AUTH);
  assert.equal(fetched.status, 200);
  assert.ok(fetched.bytes instanceof Uint8Array);
  assert.deepEqual(fetched.bytes, save);

  const [mod] = (await second.mods.list()).body.mods;
  assert.deepEqual([mod.key, mod.version, mod.files], ["pack", "1.0", files]);
  assert.deepEqual((await second.mods.file("pack")).bytes, zip);
  assert.deepEqual((await second.trades.state(trade, OTHER)).body, { state: "pending" });
  assert.deepEqual((await second.trades.commit(trade, { player: CREATOR, world: WORLD, partner: await playerIdOf(OTHER), hash: "ab".repeat(32), sealed: "Qg==" })).body, { state: "committed" });
  second.stores.close();
});

test("removing a world or a mod removes its bytes too, and a done trade goes", async () => {
  const { stores, directory, mods, trades } = openAll([await playerIdOf(OTHER)]);
  const trade = "7".repeat(32);

  assert.equal((await mods.remove(OTHER, "pack")).status, 200);
  assert.equal(await stores.mods.getModFile("pack"), undefined);
  assert.deepEqual(await stores.mods.allMods(), []);

  assert.deepEqual((await trades.done(trade, OTHER)).body, { state: "committed" });
  assert.deepEqual((await trades.done(trade, CREATOR)).body, { state: "committed" });
  assert.deepEqual(await stores.trades.allTrades(), []);

  assert.equal((await directory.remove(WORLD, CREATOR)).status, 200);
  assert.equal(await stores.directory.get(WORLD), undefined);
  assert.equal(await stores.directory.getStart(WORLD), undefined);
  assert.equal(await stores.directory.getChat(WORLD), undefined);
  assert.deepEqual(await stores.directory.all(), []);
  stores.close();
});

test("a put replaces what was there, and a view into a larger buffer is kept whole", async () => {
  const { stores } = openAll();
  const pool = Buffer.from([9, 9, 1, 2, 3, 9, 9]);

  await stores.directory.put({ id: WORLD, name: "One" });
  await stores.directory.put({ id: WORLD, name: "Two" });
  assert.deepEqual(await stores.directory.all(), [{ id: WORLD, name: "Two" }]);

  await stores.directory.putStart(WORLD, pool.subarray(2, 5));
  assert.deepEqual([...(await stores.directory.getStart(WORLD))], [1, 2, 3]);
  await stores.directory.remove(WORLD);
  stores.close();
});

test("openStores opens the database the environment names, and memory without one", async () => {
  const onDisk = await openStores(path);
  assert.equal(onDisk.path, path);
  await onDisk.trades.putTrade({ id: "1".repeat(32), state: "pending" });
  onDisk.close();

  const inMemory = await openStores(undefined);
  assert.equal(inMemory.path, ":memory:");
  assert.deepEqual(await inMemory.trades.allTrades(), []);
  inMemory.close();

  const again = await openStores(path);
  assert.equal((await again.trades.getTrade("1".repeat(32))).state, "pending");
  await again.trades.removeTrade("1".repeat(32));
  again.close();
});

test("a Raid World's story and its checkpoints outlast a restart, and each world keeps its own until removed", async () => {
  const first = openSqliteStores(path);
  const counters = (p) => ({ p, r1141: 0, r1142: 0, r1143: 0, clear: [] });
  const lists = (v) => ({ s: "", sf: "", v, ss: "", ssf: "", a: "", f: "" });
  const kept = { ...new WorldStory(first.stories(WORLD)).first(), rev: 2, wrev: 2, counters: counters(19), part: "2", checkpoints: ["1"], lists: lists("1001:n19"), log: [], logBase: 2 };
  await first.stories(WORLD).put(kept, { rev: 1, wrev: 1, counters: counters(18), part: "1", lists: lists("1001:n18") });
  first.close();

  const second = openSqliteStores(path);
  const reopened = new WorldStory(second.stories(WORLD));
  assert.deepEqual([(await reopened.get()).body.rev, (await reopened.keys()).get("v1001"), (await reopened.kept()).checkpoints], [2, "n19", ["1"]]);
  assert.equal((await second.stories(WORLD).getCheckpoint("1")).lists.v, "1001:n18");
  assert.equal((await new WorldStory(second.stories("f".repeat(32))).get()).body.rev, 0, "another world has a story of its own");

  await reopened.remove();
  assert.equal((await reopened.get()).body.rev, 0);
  assert.equal(await second.stories(WORLD).getCheckpoint("1"), undefined);
  second.close();
});

test("a Raid World's boss pools outlast a restart, and each world keeps its own until removed", async () => {
  const first = openSqliteStores(path);
  const bosses = new WorldBosses(first.bosses(WORLD), { clock: () => 5000 });
  assert.equal((await bosses.report("a1".repeat(16), "Queen%20Harpy", { battle: "b1", seq: 1, delta: 0.5, max: 1000 })).status, 200);
  assert.equal((await bosses.report("a1".repeat(16), "Morrigan", { battle: "b2", seq: 3, delta: 0.25, max: 1000 })).status, 200);
  first.close();

  const second = openSqliteStores(path);
  const reopened = new WorldBosses(second.bosses(WORLD), { clock: () => 5000 });
  assert.deepEqual((await reopened.list()).body.bosses.map((pool) => [pool.key, pool.left, pool.max]), [["Morrigan", 0.75, 1000], ["Queen Harpy", 0.5, 1000]]);
  assert.equal((await reopened.report("a1".repeat(16), "Morrigan", { battle: "b2", seq: 3, delta: 0.25, max: 1000 })).body.repeat, true, "the battles' report numbers outlast the restart too");
  assert.deepEqual((await new WorldBosses(second.bosses("f".repeat(32))).list()).body.bosses, [], "another world has pools of its own");

  await reopened.reset("Morrigan");
  assert.deepEqual((await reopened.list()).body.bosses.map((pool) => pool.key), ["Queen Harpy"]);
  await reopened.remove();
  assert.deepEqual((await reopened.list()).body.bosses, []);
  second.close();
});

test("a trade's sealed offers outlast a restart beside it, never in the list of trades, and go with a drop or the trade", async () => {
  const trade = "9".repeat(32);
  const record = { id: trade, state: "committed", commits: { alice: { hash: "ab".repeat(32) }, bob: { hash: "ab".repeat(32) } } };
  const first = openSqliteStores(path);
  await first.trades.putTrade(record, { sealed: { alice: "QQ==", bob: "Qg==" } });
  first.close();

  const second = openSqliteStores(path);
  assert.equal(await second.trades.getSealed(trade, "alice"), "QQ==");
  assert.equal(await second.trades.getSealed(trade, "bob"), "Qg==");
  assert.deepEqual(await second.trades.allTrades(), [record], "the list holds no offers");

  await second.trades.putTrade({ ...record, state: "cancelled" }, { drop: ["alice"] });
  assert.equal(await second.trades.getSealed(trade, "alice"), undefined);
  assert.equal(await second.trades.getSealed(trade, "bob"), "Qg==");

  await second.trades.removeTrade(trade, ["alice", "bob"]);
  assert.equal(await second.trades.getTrade(trade), undefined);
  assert.equal(await second.trades.getSealed(trade, "bob"), undefined);
  second.close();
});

test("the release control outlasts a restart beside the newest release seen", async () => {
  const first = openSqliteStores(path);
  await first.releases.putRelease("0.6.7.7");
  await first.releases.putControl({ current: "0.6.8", min: "0.6.7", updatedAt: 5000, updatedBy: "ad".repeat(16) });
  first.close();

  const second = openSqliteStores(path);
  assert.equal(await second.releases.getRelease(), "0.6.7.7");
  assert.deepEqual(await second.releases.getControl(), { current: "0.6.8", min: "0.6.7", updatedAt: 5000, updatedBy: "ad".repeat(16) });
  second.close();
});

test("a Raid World's story tracks outlast a restart, a player's track goes with them once dropped, and each world keeps its own until removed", async () => {
  const mapping = async () => ({ rev: 1, tables: { keys: [{ key: "v1001", kind: "one_way" }, { key: "v50", kind: "shared" }], parts: [{ id: "1", gate: 25 }] }, index: null });
  const heard = [];
  const tracksOver = (stores) => new StoryTracks(stores.tracks(WORLD), { mapping, send: (player, text) => heard.push(JSON.parse(text.slice(6))), clock: () => 5000 });
  const [alice, bob] = ["a1".repeat(16), "b2".repeat(16)];
  const first = openSqliteStores(path);
  const tracks = tracksOver(first);
  await tracks.enter(alice, 0);
  await tracks.frame(alice, `track ${JSON.stringify({ t: "sync", level: { best: 9, cap: null }, seed: { v1001: "n10" } })}`);
  const run = (id) => ({ id, site: "map:7:39:1", keys: ["v50"], place: [10, 0, 0, 0], opener: null, wire: "AAAA" });
  await tracks.frame(alice, `track ${JSON.stringify({ t: "write", seq: 1, track: "world", writes: [["v50", "n1", "map:7:39:1"], ["v1001", "n19", "map:7:39:1"]], run: run("r1") })}`);
  await tracks.enter(bob, 1);
  await tracks.frame(bob, `track ${JSON.stringify({ t: "sync", level: { best: 3, cap: null }, seed: { v1001: "n2" } })}`);
  await tracks.frame(bob, `track ${JSON.stringify({ t: "write", seq: 1, track: "t1", writes: [["v50", "n2", "map:7:39:1"]], run: run("r2") })}`);
  first.close();

  const second = openSqliteStores(path);
  const store = second.tracks(WORLD);
  assert.deepEqual(await store.getMeta(), { rev: 2, part: "2", route: "none", done: [], checkpoints: ["1"], next: 2, start: [10, 0, 0, 0], at: 5000 });
  assert.deepEqual(new Map(await store.getKeys("world")), new Map([["v1001", "n19"], ["v50", "n1"]]));
  assert.deepEqual([(await store.getPlayer(bob)).track, (await store.getPlayer(alice)).seq], [{ id: "t1", part: "1", rev: 2 }, 1]);
  assert.deepEqual(new Map(await store.getKeys("t1")), new Map([["v1001", "n10"], ["v50", "n2"]]));
  assert.deepEqual(await store.getCheckpoint("1"), [["v1001", "n10"]]);
  assert.deepEqual([(await store.getRuns("world")).map((entry) => [entry.n, entry.id]), (await store.getRuns("t1")).map((entry) => [entry.n, entry.id])], [[[1, "r1"]], [[1, "r2"]]]);
  assert.deepEqual(await second.tracks("f".repeat(32)).getMeta(), undefined, "another world has tracks of its own");

  const reopened = tracksOver(second);
  await reopened.enter(bob, 1);
  await reopened.frame(bob, `track ${JSON.stringify({ t: "sync", level: { best: 30, cap: null } })}`);
  const moved = heard.findLast((frame) => frame.t === "state");
  assert.deepEqual([moved.why, moved.track], ["moved", "world"]);
  assert.deepEqual([await store.getKeys("t1"), await store.getRuns("t1")], [[], []], "the track's keys and run entries went with it");

  await reopened.remove();
  assert.deepEqual([await store.getMeta(), await store.getKeys("world"), await store.getRuns("world"), await store.getPlayer(alice), await store.getCheckpoint("1")], [undefined, [], [], undefined, undefined]);
  second.close();
});

test("the story mapping outlasts a restart with each row's last changes and the index, and a batch that fails keeps nothing", async () => {
  const admin = "ad".repeat(16);
  const first = openSqliteStores(path);
  const mapping = new StoryMapping(first.mapping, { limits: { ...MAPPING_LIMITS, history: 2 } });

  for (const kind of ["shared", "one_way", "shared"]) {
    const edit = kind === "shared" && !(await first.mapping.get("story_keys", "v1009")) ? { op: "add" } : { op: "change", id: "v1009" };
    await mapping.edit({ edits: [{ table: "keys", ...edit, row: { key: "v1009", kind } }] }, admin);
  }

  await mapping.keepIndex({ built: 3, events: [[228, 51]] }, admin);
  const broken = { meta: { rev: 9, rowsRev: 9, next: {} }, puts: [{ table: "story_keys", entry: { id: "s1", row: {} } }, { table: "no such table", entry: { id: "s1", row: {} } }], removes: [], changes: [] };
  await assert.rejects(first.mapping.commit(broken, 2));
  first.close();

  const second = openSqliteStores(path);
  assert.deepEqual(await second.mapping.getMeta(), { rev: 4, rowsRev: 3, next: {} });
  assert.deepEqual((await second.mapping.all("story_keys")).map((entry) => entry.row), [{ key: "v1009", kind: "shared" }]);
  assert.deepEqual((await second.mapping.history("story_keys", "v1009")).map((change) => change.rev), [3, 2]);
  assert.deepEqual((await second.mapping.getIndex()).events, [[228, 51]]);
  second.close();
});
