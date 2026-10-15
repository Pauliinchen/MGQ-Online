//----------------------------------------------------------------
//  migrate.js
//
//  Changelog:
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

// Copies everything a relay keeps into a new SQLite database for the Node relay, through the
// relay's migration routes (core/migration.js): the worlds with their starting saves, chats,
// stories, checkpoints and boss pools, the mod catalog with its uploads, and the trades with their
// sealed offers. Every record is read back from the database and compared with the relay's before
// the copy counts as done.
//
//   MGQ_ADMIN_KEY=<an admin's player key> node node/migrate.js <relay address> <new database file>

import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { isDeepStrictEqual } from "node:util";
import { pathToFileURL } from "node:url";
import { MIGRATION_FORMAT, MIGRATION_ROUTE } from "../core/migration.js";
import { PLAYER_HEADER, VERSION } from "../core/relay.js";
import { openSqliteStores } from "./sqlite_store.js";

/**
 * The environment variable that names the admin's player key, kept out of the command line.
 */
export const KEY_VARIABLE = "MGQ_ADMIN_KEY";

/**
 * Copies a relay's records into a new database and checks the copy.
 *
 * @param {{from: string, key: string, database: string, fetch?: typeof globalThis.fetch, log?: (line: string) => void}} options The relay's address, an admin's player key, the new database's file, and stand-ins for fetching and logging.
 * @returns {Promise<{worlds: number, starts: number, stories: number, checkpoints: number, pools: number, mods: number, files: number, trades: number}>} How many records it copied.
 * @throws {Error} When the database file exists already, the relay refuses or a record differs once copied.
 */
export async function migrate({ from, key, database, fetch = globalThis.fetch, log = console.log }) {
  if (existsSync(database)) {
    throw new Error(`${database} exists already; the copy goes into a new database only`);
  }

  const base = `${from.replace(/\/+$/, "")}/${VERSION}/${MIGRATION_ROUTE}`;
  const get = async (path, bytes = false) => {
    const response = await fetch(`${base}${path}`, { headers: { [PLAYER_HEADER]: key } });

    if (bytes && response.status === 404) {
      return null;
    }

    if (response.status !== 200) {
      throw new Error(`GET ${path || "/"} answered ${response.status}: ${await response.text()}`);
    }

    return bytes ? new Uint8Array(await response.arrayBuffer()) : response.json();
  };

  const list = await get("");

  if (list.format !== MIGRATION_FORMAT) {
    throw new Error(`the relay hands out format ${list.format}, this tool reads format ${MIGRATION_FORMAT}`);
  }

  log(`the relay keeps ${list.worlds.length} world(s), ${list.mods.length} mod(s) and ${list.trades.length} trade(s)`);
  const stores = openSqliteStores(database);
  const counts = { worlds: 0, starts: 0, stories: 0, checkpoints: 0, pools: 0, mods: 0, files: 0, trades: 0 };

  try {
    for (const id of list.worlds) {
      const world = await get(`/worlds/${encodeURIComponent(id)}`);
      const start = await get(`/worlds/${encodeURIComponent(id)}/start`, true);
      await putWorld(stores, id, world, start);
      await checkWorld(stores, id, world, start);
      counts.worlds++;
      counts.starts += start ? 1 : 0;
      counts.stories += world.story ? 1 : 0;
      counts.checkpoints += world.checkpoints.length;
      counts.pools += world.pools.length;
      log(`world ${id}: ${world.entry.name ?? "?"}${start ? `, starting save of ${start.length} bytes` : ""}${world.story ? `, story at revision ${world.story.rev}` : ""}` +
          `${world.checkpoints.length ? `, ${world.checkpoints.length} checkpoint(s)` : ""}${world.pools.length ? `, ${world.pools.length} boss pool(s)` : ""}`);
    }

    for (const key of list.mods) {
      const { entry } = await get(`/mods/${encodeURIComponent(key)}`);
      const file = await get(`/mods/${encodeURIComponent(key)}/file`, true);
      await stores.mods.putMod(entry);

      if (file) {
        await stores.mods.putModFile(key, file);
      }

      same(`mod ${key}`, await stores.mods.getMod(key), entry);
      sameBytes(`the upload of mod ${key}`, await stores.mods.getModFile(key), file);
      counts.mods++;
      counts.files += file ? 1 : 0;
      log(`mod ${key}${file ? `, upload of ${file.length} bytes` : ""}`);
    }

    for (const id of list.trades) {
      const { record, sealed } = await get(`/trades/${encodeURIComponent(id)}`);
      await stores.trades.putTrade(record, { sealed });
      same(`trade ${id}`, await stores.trades.getTrade(id), record);

      for (const [player, text] of Object.entries(sealed)) {
        same(`the sealed offers of ${player} in trade ${id}`, await stores.trades.getSealed(id, player), text);
      }

      counts.trades++;
    }
  } finally {
    stores.close();
  }

  log(`copied and checked ${Object.entries(counts).map(([name, count]) => `${count} ${name}`).join(", ")}`);
  return counts;
}

/**
 * Writes a world's records into the database.
 *
 * @param {ReturnType<typeof openSqliteStores>} stores The database's stores.
 * @param {string} id The world.
 * @param {{entry: object, chat: object | null, story: object | null, checkpoints: object[], pools: object[]}} world What the relay keeps of it.
 * @param {Uint8Array | null} start Its starting save, null for none.
 */
async function putWorld(stores, id, world, start) {
  await stores.directory.put(world.entry);

  if (world.chat) {
    await stores.directory.putChat(id, world.chat);
  }

  if (start) {
    await stores.directory.putStart(id, start);
  }

  const story = stores.stories(id);

  if (world.story) {
    await story.put(world.story);

    for (const checkpoint of world.checkpoints) {
      await story.put(world.story, checkpoint);
    }
  }

  for (const pool of world.pools) {
    await stores.bosses(id).put(pool);
  }
}

/**
 * Reads a world's records back from the database and compares them with the relay's.
 *
 * @param {ReturnType<typeof openSqliteStores>} stores The database's stores.
 * @param {string} id The world.
 * @param {{entry: object, chat: object | null, story: object | null, checkpoints: object[], pools: object[]}} world What the relay keeps of it.
 * @param {Uint8Array | null} start Its starting save, null for none.
 * @throws {Error} When a record differs.
 */
async function checkWorld(stores, id, world, start) {
  same(`world ${id}`, await stores.directory.get(id), world.entry);
  same(`the chat of world ${id}`, (await stores.directory.getChat(id)) ?? null, world.chat);
  sameBytes(`the starting save of world ${id}`, await stores.directory.getStart(id), start);
  same(`the story of world ${id}`, (await stores.stories(id).get()) ?? null, world.story);

  for (const checkpoint of world.checkpoints) {
    same(`checkpoint ${checkpoint.part} of world ${id}`, await stores.stories(id).getCheckpoint(checkpoint.part), checkpoint);
  }

  const byKey = (pools) => [...pools].sort((a, b) => String(a.key).localeCompare(String(b.key)));
  same(`the boss pools of world ${id}`, byKey(await stores.bosses(id).all()), byKey(world.pools));
}

/**
 * Throws unless a record read back equals the relay's.
 *
 * @param {string} what The record, for the error.
 * @param {unknown} copied What the database holds.
 * @param {unknown} kept What the relay handed out.
 * @throws {Error} When they differ.
 */
function same(what, copied, kept) {
  if (!isDeepStrictEqual(copied, kept)) {
    throw new Error(`${what} differs once copied`);
  }
}

/**
 * Throws unless bytes read back equal the relay's.
 *
 * @param {string} what The bytes, for the error.
 * @param {Uint8Array | undefined | null} copied What the database holds.
 * @param {Uint8Array | null} kept What the relay handed out, null for none.
 * @throws {Error} When they differ.
 */
function sameBytes(what, copied, kept) {
  const hash = (bytes) => (bytes ? createHash("sha256").update(bytes).digest("hex") : null);

  if (hash(copied) !== hash(kept)) {
    throw new Error(`${what} differs once copied`);
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const [from, database] = process.argv.slice(2);
  const key = process.env[KEY_VARIABLE];

  if (!from || !database || !key) {
    console.error(`usage: ${KEY_VARIABLE}=<an admin's player key> node node/migrate.js <relay address> <new database file>`);
    process.exit(2);
  }

  migrate({ from, key, database }).catch((error) => {
    console.error(`the copy failed: ${error.message}`);
    process.exit(1);
  });
}
