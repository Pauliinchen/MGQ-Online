//----------------------------------------------------------------
//  sqlite_store.js
//
//  Changelog:
//      Paulinchen  2026-10-31: Kept the run entries of each story track one row each
//      Paulinchen  2026-10-23: Kept the story mapping, its revision, each row's last changes and the derived index
//                            - Kept each Raid World's story tracks: its summary, each track's keys, each player's record and each part's checkpoint
//      Paulinchen  2026-10-22: Kept the release control the relay's admins set
//      Paulinchen  2026-10-12: Kept the newest release of the mod the relay has seen
//                            - Kept each trade's sealed offers in a table of their own beside the trade
//      Paulinchen  2026-10-09: Kept each Raid World's boss pools
//      Paulinchen  2026-10-08: Kept each Raid World's story and its checkpoints
//      Paulinchen  2026-10-07: Kept each world's chat
//                            - Created
//
//----------------------------------------------------------------

// The Node relay's stores over one SQLite database, so worlds, mods, trades, stories, boss pools,
// the story mapping and the story tracks outlast a restart. Records are kept as JSON, starting saves
// and uploaded mods' zips as blobs, the tracks' keys one row each.

import { DatabaseSync } from "node:sqlite";

/**
 * Opens the stores over a SQLite database, making its tables when they are missing.
 *
 * @param {string} path The database file's path, made when it is missing.
 * @returns {{path: string, directory: import("../core/directory.js").DirectoryStore, mods: import("../core/mods.js").ModStore, trades: import("../core/trades.js").TradeStore, stories: (id: string) => import("../core/story.js").StoryStore, bosses: (id: string) => import("../core/bosses.js").BossStore, releases: import("../core/releases.js").ReleaseStore, mapping: import("../core/story_mapping.js").StoryMappingStore, tracks: (id: string) => import("../core/story_tracks.js").TrackStore, close: () => void}} The stores, and a way to close the database.
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
  const tradeSealed = jsonTable(db, "trade_sealed");
  const stories = jsonTable(db, "stories");
  const checkpoints = jsonTable(db, "story_checkpoints");
  const worldCheckpoints = db.prepare("DELETE FROM story_checkpoints WHERE id LIKE ?");
  // A world id is hexadecimal, so its prefix holds none of the characters LIKE reads.
  const pools = jsonTable(db, "boss_pools");
  const worldPools = db.prepare("SELECT json FROM boss_pools WHERE id LIKE ?");
  const worldPoolsRemove = db.prepare("DELETE FROM boss_pools WHERE id LIKE ?");
  const releases = jsonTable(db, "releases");
  const mapping = mappingStore(db);
  const tracks = trackStores(db);

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
      putTrade: async (record, { sealed = {}, drop = [] } = {}) => transaction(db, () => {
        trades.put(record.id, record);

        for (const [player, text] of Object.entries(sealed)) {
          tradeSealed.put(`${record.id}:${player}`, text);
        }

        for (const player of drop) {
          tradeSealed.remove(`${record.id}:${player}`);
        }
      }),
      getSealed: async (id, player) => tradeSealed.get(`${id}:${player}`),
      removeTrade: async (id, players = []) => transaction(db, () => {
        trades.remove(id);

        for (const player of players) {
          tradeSealed.remove(`${id}:${player}`);
        }
      }),
      allTrades: async () => trades.all(),
    },
    stories: (id) => ({
      get: async () => stories.get(id),
      // One transaction, so a checkpoint is never kept without the story that moved past it.
      put: async (story, checkpoint) => transaction(db, () => {
        stories.put(id, story);

        if (checkpoint) {
          checkpoints.put(`${id}:${checkpoint.part}`, checkpoint);
        }
      }),
      getCheckpoint: async (part) => checkpoints.get(`${id}:${part}`),
      remove: async () => {
        stories.remove(id);
        worldCheckpoints.run(`${id}:%`);
      },
    }),
    bosses: (id) => ({
      get: async (key) => pools.get(`${id}:${key}`),
      put: async (pool) => pools.put(`${id}:${pool.key}`, pool),
      all: async () => worldPools.all(`${id}:%`).map((row) => JSON.parse(row.json)),
      remove: async (key) => pools.remove(`${id}:${key}`),
      removeAll: async () => void worldPoolsRemove.run(`${id}:%`),
    }),
    releases: {
      getRelease: async () => releases.get("latest"),
      putRelease: async (version) => releases.put("latest", version),
      getControl: async () => releases.get("control"),
      putControl: async (record) => releases.put("control", record),
    },
    mapping,
    tracks,
    close: () => db.close(),
  };
}

/**
 * The store of the story mapping: its revision and derived index, one JSON table per table of
 * rows, made when first used, and each row's last changes.
 *
 * @param {DatabaseSync} db The database.
 * @returns {import("../core/story_mapping.js").StoryMappingStore} The store.
 */
function mappingStore(db) {
  const meta = jsonTable(db, "story_meta");
  db.exec("CREATE TABLE IF NOT EXISTS story_history (tbl TEXT NOT NULL, id TEXT NOT NULL, rev INTEGER NOT NULL, json TEXT NOT NULL, PRIMARY KEY (tbl, id, rev))");
  const history = db.prepare("SELECT json FROM story_history WHERE tbl = ? AND id = ? ORDER BY rev DESC");
  const addChange = db.prepare("INSERT OR REPLACE INTO story_history (tbl, id, rev, json) VALUES (?, ?, ?, ?)");
  const trim = db.prepare("DELETE FROM story_history WHERE tbl = ? AND id = ? AND rev <= (SELECT rev FROM story_history WHERE tbl = ? AND id = ? ORDER BY rev DESC LIMIT 1 OFFSET ?)");
  /** @type {Map<string, ReturnType<typeof jsonTable>>} */
  const tables = new Map();
  const table = (name) => {
    // The names come from the table specs in core, never from a request; checked anyway, since
    // they go into SQL as they are.
    if (!/^story_[a-z_]+$/.test(name)) {
      throw new Error(`no story mapping table may be named ${name}`);
    }

    return tables.get(name) ?? tables.set(name, jsonTable(db, name)).get(name);
  };
  const write = (commit, keep) => {
    meta.put("mapping", commit.meta);

    for (const { table: name, entry } of commit.puts) {
      table(name).put(entry.id, entry);
    }

    for (const { table: name, id } of commit.removes) {
      table(name).remove(id);
    }

    for (const { table: name, id, change } of commit.changes) {
      addChange.run(name, id, change.rev, JSON.stringify(change));
      trim.run(name, id, name, id, keep);
    }

    if (commit.index) {
      meta.put("index", commit.index);
    }
  };

  return {
    getMeta: async () => meta.get("mapping"),
    all: async (name) => table(name).all(),
    get: async (name, id) => table(name).get(id),
    history: async (name, id) => history.all(name, id).map((row) => JSON.parse(row.json)),
    commit: async (commit, keep) => {
      try {
        transaction(db, () => write(commit, keep));
      } catch (error) {
        // A table first made in the batch went with its rollback, so its statements are made anew.
        tables.clear();
        throw error;
      }
    },
    getIndex: async () => meta.get("index"),
  };
}

/**
 * The stores of the Raid Worlds' story tracks: each world's summary, each player's record and each
 * part's checkpoint as JSON, each track's keys and run entries one row each, so a write changes
 * only its own keys and adds only its own entry.
 *
 * @param {DatabaseSync} db The database.
 * @returns {(id: string) => import("../core/story_tracks.js").TrackStore} Makes the store of a world's tracks.
 */
function trackStores(db) {
  const meta = jsonTable(db, "track_meta");
  const players = jsonTable(db, "track_players");
  const checkpoints = jsonTable(db, "track_checkpoints");
  db.exec("CREATE TABLE IF NOT EXISTS track_keys (world TEXT NOT NULL, track TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (world, track, key))");
  const keysOf = db.prepare("SELECT key, value FROM track_keys WHERE world = ? AND track = ?");
  const putKey = db.prepare("INSERT OR REPLACE INTO track_keys (world, track, key, value) VALUES (?, ?, ?, ?)");
  const dropTrack = db.prepare("DELETE FROM track_keys WHERE world = ? AND track = ?");
  const dropWorld = db.prepare("DELETE FROM track_keys WHERE world = ?");
  db.exec("CREATE TABLE IF NOT EXISTS track_runs (world TEXT NOT NULL, track TEXT NOT NULL, n INTEGER NOT NULL, entry TEXT NOT NULL, PRIMARY KEY (world, track, n))");
  const runsOf = db.prepare("SELECT entry FROM track_runs WHERE world = ? AND track = ? ORDER BY n");
  const putRun = db.prepare("INSERT OR REPLACE INTO track_runs (world, track, n, entry) VALUES (?, ?, ?, ?)");
  const dropRuns = db.prepare("DELETE FROM track_runs WHERE world = ? AND track = ?");
  const dropWorldRuns = db.prepare("DELETE FROM track_runs WHERE world = ?");
  // A world id is hexadecimal, so its prefix holds none of the characters LIKE reads.
  const dropPlayers = db.prepare("DELETE FROM track_players WHERE id LIKE ?");
  const dropCheckpoints = db.prepare("DELETE FROM track_checkpoints WHERE id LIKE ?");

  return (id) => ({
    getMeta: async () => meta.get(id),
    getKeys: async (track) => keysOf.all(id, track).map((row) => [row.key, row.value]),
    getRuns: async (track) => runsOf.all(id, track).map((row) => JSON.parse(row.entry)),
    getPlayer: async (player) => players.get(`${id}:${player}`),
    getCheckpoint: async (part) => checkpoints.get(`${id}:${part}`),
    commit: async ({ meta: summary, keys = [], runs = [], players: records = [], checkpoint }) => transaction(db, () => {
      if (summary) {
        meta.put(id, summary);
      }

      for (const { track, drop, set } of keys) {
        if (drop) {
          dropTrack.run(id, track);
        }

        set.forEach(([key, value]) => putKey.run(id, track, key, value));
      }

      for (const { track, drop, add } of runs) {
        if (drop) {
          dropRuns.run(id, track);
        }

        add.forEach((entry) => putRun.run(id, track, entry.n, JSON.stringify(entry)));
      }

      records.forEach((record) => players.put(`${id}:${record.player}`, record));

      if (checkpoint) {
        checkpoints.put(`${id}:${checkpoint.part}`, checkpoint.keys);
      }
    }),
    remove: async () => transaction(db, () => {
      meta.remove(id);
      dropWorld.run(id);
      dropWorldRuns.run(id);
      dropPlayers.run(`${id}:%`);
      dropCheckpoints.run(`${id}:%`);
    }),
  });
}

/**
 * Runs work in one transaction, which keeps nothing of it when it throws.
 *
 * @param {DatabaseSync} db The database.
 * @param {() => void} work The work.
 */
function transaction(db, work) {
  db.exec("BEGIN");

  try {
    work();
    db.exec("COMMIT");
  } catch (error) {
    db.exec("ROLLBACK");
    throw error;
  }
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
