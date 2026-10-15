//----------------------------------------------------------------
//  migrate.test.js
//
//  Changelog:
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Directory, playerIdOf } from "../core/directory.js";
import { ModCatalog } from "../core/mods.js";
import { PLAYER_HEADER } from "../core/relay.js";
import { TradeBook } from "../core/trades.js";
import { migrate } from "./migrate.js";
import { createRelay } from "./server.js";
import { openSqliteStores } from "./sqlite_store.js";

/**
 * The admin's player key.
 */
const ADMIN = "a".repeat(32);

/**
 * A Raid World with a starting save, a chat, a story, a checkpoint and a boss pool.
 */
const RAID = "d4".repeat(16);

/**
 * A Classic world with nothing beside its entry.
 */
const CLASSIC = "c3".repeat(16);

/**
 * Logs nothing.
 */
const QUIET = { info: () => {}, error: () => {} };

let folder;
let source;
let relay;
let address;

before(async () => {
  folder = mkdtempSync(join(tmpdir(), "mgq-migrate-"));
  source = openSqliteStores(join(folder, "source.db"));
  await source.directory.put({ id: RAID, name: "Raid Night", members: { p1: { name: "One" } }, bans: [] });
  await source.directory.putStart(RAID, new Uint8Array(200_000).map((_, index) => index % 253));
  await source.directory.putChat(RAID, [{ name: "One", text: "hi" }]);
  await source.directory.put({ id: CLASSIC, name: "Classic", members: {}, bans: [] });
  await source.stories(RAID).put({ rev: 7, keyed: true, keys: { v1001: "n12", a5: "2173" } }, { part: "1", rev: 5 });
  await source.bosses(RAID).put({ key: "adramelech", hp: 0.88 });
  await source.mods.putMod({ key: "teamboostfix", name: "Team Boost Fix" });
  await source.mods.putModFile("teamboostfix", new Uint8Array([80, 75, 3, 4, 1, 2, 3]));
  await source.trades.putTrade({ id: "7".repeat(32), world: RAID, players: ["p1", "p2"], state: "pending" }, { sealed: { p1: "QQ==" } });

  const admins = [await playerIdOf(ADMIN)];
  const directory = new Directory(source.directory, { admins });
  relay = createRelay({
    checkEveryMs: 3_600_000, sweepEveryMs: 3_600_000, log: QUIET, directory, mods: new ModCatalog(source.mods, { admins }),
    trades: new TradeBook(source.trades, (id) => directory.store.get(id)), stories: source.stories, bosses: source.bosses,
  });
  await new Promise((resolve) => relay.server.listen(0, "127.0.0.1", resolve));
  address = `http://127.0.0.1:${relay.server.address().port}`;
});

after(async () => {
  relay.stop();
  source.close();
  rmSync(folder, { recursive: true, force: true });
});

test("a relay's worlds, starting saves, chats, stories, checkpoints, boss pools, mods, uploads and trades go into a new database alike", async () => {
  const database = join(folder, "copy.db");
  const counts = await migrate({ from: address, key: ADMIN, database, log: () => {} });
  assert.deepEqual(counts, { worlds: 2, starts: 1, stories: 1, checkpoints: 1, pools: 1, mods: 1, files: 1, trades: 1 });

  const copy = openSqliteStores(database);

  try {
    assert.deepEqual(await copy.directory.get(RAID), await source.directory.get(RAID));
    assert.deepEqual(await copy.directory.getStart(RAID), await source.directory.getStart(RAID));
    assert.equal(await copy.directory.getStart(CLASSIC), undefined);
    assert.deepEqual(await copy.stories(RAID).get(), { rev: 7, keyed: true, keys: { v1001: "n12", a5: "2173" } });
    assert.deepEqual(await copy.stories(RAID).getCheckpoint("1"), { part: "1", rev: 5 });
    assert.deepEqual(await copy.bosses(RAID).all(), [{ key: "adramelech", hp: 0.88 }]);
    assert.deepEqual(await copy.mods.getModFile("teamboostfix"), await source.mods.getModFile("teamboostfix"));
    assert.equal(await copy.trades.getSealed("7".repeat(32), "p1"), "QQ==");
    assert.equal(await copy.trades.getSealed("7".repeat(32), "p2"), undefined);
  } finally {
    copy.close();
  }

  await assert.rejects(migrate({ from: address, key: ADMIN, database, log: () => {} }), /exists already/, "a database that exists is never written over");
});

test("the migration routes answer the relay's admins only", async () => {
  const answer = (key) => fetch(`${address}/v1/migration`, { headers: key ? { [PLAYER_HEADER]: key } : {} }).then((response) => response.status);
  assert.deepEqual([await answer(ADMIN), await answer("b".repeat(32)), await answer(null)], [200, 403, 403]);
  await assert.rejects(migrate({ from: address, key: "b".repeat(32), database: join(folder, "refused.db"), log: () => {} }), /403/);
});
