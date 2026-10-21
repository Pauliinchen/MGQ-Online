//----------------------------------------------------------------
//  schema.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

// The versions of the Node relay's SQLite database: PRAGMA user_version counts the steps a database
// has taken, and each step runs once, in a transaction of its own. Later plans append their steps.

/**
 * Step 1: the tables the relay kept before the steps, made exactly as node/sqlite_store.js makes
 * them, so the step leaves a database that has them as it is.
 */
const RELAY_TABLES = [
  "CREATE TABLE IF NOT EXISTS worlds (id TEXT PRIMARY KEY, json TEXT NOT NULL)",
  "CREATE TABLE IF NOT EXISTS starts (id TEXT PRIMARY KEY, bytes BLOB NOT NULL)",
  "CREATE TABLE IF NOT EXISTS chats (id TEXT PRIMARY KEY, json TEXT NOT NULL)",
  "CREATE TABLE IF NOT EXISTS mods (id TEXT PRIMARY KEY, json TEXT NOT NULL)",
  "CREATE TABLE IF NOT EXISTS mod_files (id TEXT PRIMARY KEY, bytes BLOB NOT NULL)",
  "CREATE TABLE IF NOT EXISTS trades (id TEXT PRIMARY KEY, json TEXT NOT NULL)",
  "CREATE TABLE IF NOT EXISTS trade_sealed (id TEXT PRIMARY KEY, json TEXT NOT NULL)",
  "CREATE TABLE IF NOT EXISTS stories (id TEXT PRIMARY KEY, json TEXT NOT NULL)",
  "CREATE TABLE IF NOT EXISTS story_checkpoints (id TEXT PRIMARY KEY, json TEXT NOT NULL)",
  "CREATE TABLE IF NOT EXISTS boss_pools (id TEXT PRIMARY KEY, json TEXT NOT NULL)",
  "CREATE TABLE IF NOT EXISTS releases (id TEXT PRIMARY KEY, json TEXT NOT NULL)",
];

/**
 * Step 2: the Raid design tables.
 */
const DESIGN_TABLES = [
  `CREATE TABLE design_entities (id TEXT PRIMARY KEY, kind TEXT NOT NULL, schema INTEGER NOT NULL, rev INTEGER NOT NULL,
    body TEXT, deleted INTEGER NOT NULL DEFAULT 0, by TEXT NOT NULL, at INTEGER NOT NULL)`,
  "CREATE INDEX design_entities_rev ON design_entities (rev)",
  `CREATE TABLE design_history (id TEXT NOT NULL, rev INTEGER NOT NULL, schema INTEGER NOT NULL, body TEXT,
    deleted INTEGER NOT NULL, by TEXT NOT NULL, at INTEGER NOT NULL, PRIMARY KEY (id, rev))`,
  `CREATE TABLE design_pushes (seq INTEGER PRIMARY KEY AUTOINCREMENT, by TEXT NOT NULL, by_name TEXT NOT NULL,
    at INTEGER NOT NULL, message TEXT, design_format INTEGER NOT NULL, client_version TEXT NOT NULL, ids TEXT NOT NULL)`,
  `CREATE TABLE designers (id TEXT PRIMARY KEY, name TEXT NOT NULL, admin INTEGER NOT NULL DEFAULT 0,
    added_by TEXT NOT NULL, at INTEGER NOT NULL, last_seen INTEGER)`,
  `CREATE TABLE design_blobs (sha256 TEXT PRIMARY KEY, kind TEXT NOT NULL, size INTEGER NOT NULL, gz BLOB NOT NULL,
    at INTEGER NOT NULL)`,
  `CREATE TABLE design_builds (id INTEGER PRIMARY KEY AUTOINCREMENT, seq INTEGER NOT NULL, snapshot_sha TEXT,
    runtime_sha TEXT, marshal_sha TEXT, format INTEGER, runtime_format INTEGER, compiler TEXT, game_data TEXT,
    status TEXT NOT NULL, report TEXT, by TEXT NOT NULL, at INTEGER NOT NULL)`,
  `CREATE TABLE design_live (channel TEXT PRIMARY KEY, build_id INTEGER NOT NULL, previous_build_id INTEGER,
    by TEXT NOT NULL, at INTEGER NOT NULL)`,
  "CREATE TABLE design_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)",
];

/**
 * The steps of the relay's database in order; step n brings user_version from n - 1 to n.
 */
export const STEPS = Object.freeze([RELAY_TABLES, DESIGN_TABLES]);

/**
 * The tables the design steps add, in the order a migration copies them.
 */
export const DESIGN_TABLE_NAMES = Object.freeze(["designers", "design_meta", "design_pushes", "design_entities", "design_history", "design_blobs", "design_builds", "design_live"]);

/**
 * Brings a database up to the last of its steps: runs every step past its user_version, each in a
 * transaction that also sets the new user_version, so a failed step leaves the database as it was.
 *
 * @param {import("node:sqlite").DatabaseSync} db The database.
 * @param {readonly (readonly string[])[]} steps The steps, each a list of statements.
 * @returns {number} The user_version the database has now.
 * @throws {Error} When the database is newer than the steps, or a step fails.
 */
export function migrate(db, steps) {
  const version = versionOf(db);

  if (version > steps.length) {
    throw new Error(`the database is at step ${version}, this relay knows ${steps.length} steps`);
  }

  for (let step = version; step < steps.length; step++) {
    db.exec("BEGIN IMMEDIATE");

    try {
      for (const statement of steps[step]) {
        db.exec(statement);
      }

      db.exec(`PRAGMA user_version = ${step + 1}`);
      db.exec("COMMIT");
    } catch (error) {
      db.exec("ROLLBACK");
      throw error;
    }
  }

  return versionOf(db);
}

/**
 * Reads how many steps a database has taken.
 *
 * @param {import("node:sqlite").DatabaseSync} db The database.
 * @returns {number} Its user_version, 0 for a database before the steps.
 */
export function versionOf(db) {
  return Number(db.prepare("PRAGMA user_version").get().user_version);
}
