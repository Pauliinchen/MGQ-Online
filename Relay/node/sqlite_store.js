//----------------------------------------------------------------
//  sqlite_store.js
//
//  Changelog:
//      Paulinchen  2026-10-08: Kept each Raid World's story and its checkpoints
//      Paulinchen  2026-10-07: Kept each world's chat, which goes with the world
//                            - Created
//
//----------------------------------------------------------------

// The world directory's, the mod catalog's, the trades' and the Raid Worlds' stories' stores over
// one SQLite database, for the Node relay on a rented machine, so worlds, mods, trades and stories
// outlast a restart. Entries, records, chats and stories are kept as JSON, starting saves and
// uploaded mods' zips as blobs.

import { DatabaseSync } from "node:sqlite";

/**
 * Opens the stores over a SQLite database, making its tables when they are missing.
 *
 * @param {string} path The database file's path, made when it is missing.
 * @returns {{path: string, directory: import("../core/directory.js").DirectoryStore, mods: import("../core/mods.js").ModStore, trades: import("../core/trades.js").TradeStore, stories: (id: string) => import("../core/story.js").StoryStore, close: () => void}} The stores, and a way to close the database.
 */
export function openSqliteStores(path) {
  const db = new DatabaseSync(path);
  // Write-ahead logging lets the relay keep answering reads while a starting save is written.
  db.exec("PRAGMA journal_mode = WAL");
  const worlds = jsonTable(db, "worlds");
  const starts = blobTable(db, "starts");
  const chats = jsonTable(db, "chats");
  const mods = jsonTable(db, "mods");
  const modFiles = blobTable(db, "mod_files");
  const trades = jsonTable(db, "trades");
  const stories = jsonTable(db, "stories");
  const checkpoints = jsonTable(db, "story_checkpoints");
  const worldCheckpoints = db.prepare("DELETE FROM story_checkpoints WHERE id LIKE ?");

  return {
    path,
    directory: {
      get: async (id) => worlds.get(id),
      put: async (entry) => worlds.put(entry.id, entry),
      remove: async (id) => {
        worlds.remove(id);
        starts.remove(id);
        chats.remove(id);
      },
      all: async () => worlds.all(),
      putStart: async (id, bytes) => starts.put(id, bytes),
      getStart: async (id) => starts.get(id),
      putChat: async (id, lines) => chats.put(id, lines),
      getChat: async (id) => chats.get(id),
    },
    mods: {
      getMod: async (key) => mods.get(key),
      putMod: async (entry) => mods.put(entry.key, entry),
      removeMod: async (key) => {
        mods.remove(key);
        modFiles.remove(key);
      },
      allMods: async () => mods.all(),
      putModFile: async (key, bytes) => modFiles.put(key, bytes),
      getModFile: async (key) => modFiles.get(key),
    },
    trades: {
      getTrade: async (id) => trades.get(id),
      putTrade: async (record) => trades.put(record.id, record),
      removeTrade: async (id) => trades.remove(id),
      allTrades: async () => trades.all(),
    },
    stories: (id) => ({
      get: async () => stories.get(id),
      put: async (story, checkpoint) => {
        // One transaction, so a checkpoint is never kept without the story that moved past it.
        db.exec("BEGIN");

        try {
          stories.put(id, story);

          if (checkpoint) {
            checkpoints.put(`${id}:${checkpoint.part}`, checkpoint);
          }

          db.exec("COMMIT");
        } catch (error) {
          db.exec("ROLLBACK");
          throw error;
        }
      },
      getCheckpoint: async (part) => checkpoints.get(`${id}:${part}`),
      remove: async () => {
        stories.remove(id);
        worldCheckpoints.run(`${id}:%`);
      },
    }),
    close: () => db.close(),
  };
}

/**
 * A table of JSON values by id.
 *
 * @param {DatabaseSync} db The database.
 * @param {string} table The table's name.
 * @returns {{get: (id: string) => object | undefined, put: (id: string, value: object) => void, remove: (id: string) => void, all: () => object[]}} The table.
 */
function jsonTable(db, table) {
  db.exec(`CREATE TABLE IF NOT EXISTS ${table} (id TEXT PRIMARY KEY, json TEXT NOT NULL)`);
  const select = db.prepare(`SELECT json FROM ${table} WHERE id = ?`);
  const selectAll = db.prepare(`SELECT json FROM ${table}`);
  const insert = db.prepare(`INSERT OR REPLACE INTO ${table} (id, json) VALUES (?, ?)`);
  const remove = db.prepare(`DELETE FROM ${table} WHERE id = ?`);

  return {
    get: (id) => {
      const row = select.get(id);
      return row ? JSON.parse(row.json) : undefined;
    },
    put: (id, value) => void insert.run(id, JSON.stringify(value)),
    remove: (id) => void remove.run(id),
    all: () => selectAll.all().map((row) => JSON.parse(row.json)),
  };
}

/**
 * A table of blobs by id.
 *
 * @param {DatabaseSync} db The database.
 * @param {string} table The table's name.
 * @returns {{get: (id: string) => Uint8Array | undefined, put: (id: string, bytes: Uint8Array) => void, remove: (id: string) => void}} The table.
 */
function blobTable(db, table) {
  db.exec(`CREATE TABLE IF NOT EXISTS ${table} (id TEXT PRIMARY KEY, bytes BLOB NOT NULL)`);
  const select = db.prepare(`SELECT bytes FROM ${table} WHERE id = ?`);
  const insert = db.prepare(`INSERT OR REPLACE INTO ${table} (id, bytes) VALUES (?, ?)`);
  const remove = db.prepare(`DELETE FROM ${table} WHERE id = ?`);

  return {
    get: (id) => select.get(id)?.bytes,
    // Copied, so a view into a larger buffer, such as one the HTTP server pooled, is bound whole.
    put: (id, bytes) => void insert.run(id, Uint8Array.from(bytes)),
    remove: (id) => void remove.run(id),
  };
}
