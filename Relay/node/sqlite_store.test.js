//----------------------------------------------------------------
//  sqlite_store.test.js
//
//  Changelog:
//      Paulinchen  2026-10-07: Covered a world's chat kept and removed with the world
//                            - Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Directory, playerIdOf, sha256Hex } from "../core/directory.js";
import { ModCatalog, zipHashes } from "../core/mods.js";
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
  assert.equal(inMemory.path, undefined);
  assert.deepEqual(await inMemory.trades.allTrades(), []);
  inMemory.close();

  const again = await openStores(path);
  assert.equal((await again.trades.getTrade("1".repeat(32))).state, "pending");
  await again.trades.removeTrade("1".repeat(32));
  again.close();
});
