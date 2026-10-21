//----------------------------------------------------------------
//  design_store_sqlite.js
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

// The Raid design store over the relay's SQLite database, in the tables node/schema.js makes. Every
// write runs synchronously in one transaction, so nothing else of the relay runs while it is half
// done, although the store keeps a connection of its own beside node/sqlite_store.js.

import { DatabaseSync } from "node:sqlite";
import { DESIGN_TABLE_NAMES, STEPS, migrate } from "./schema.js";

/**
 * The column each design table is sorted by when it is handed out whole.
 */
const ORDER = Object.freeze({
  designers: "id",
  design_meta: "key",
  design_pushes: "seq",
  design_entities: "id",
  design_history: "id, rev",
  design_blobs: "sha256",
  design_builds: "id",
  design_live: "channel",
});

/**
 * A column's name as the design tables write them, the only names an imported row may use.
 */
const COLUMN = /^[a-z][a-z0-9_]*$/;

/**
 * The name of a revision's designer: as the push named them, else as the designer list names them.
 */
const NAME = "COALESCE(p.by_name, d.name, '') AS name";

/**
 * Opens the Raid design store over a SQLite database, bringing its tables up to the last step.
 *
 * @param {string} path The database file's path, made when it is missing.
 * @returns {import("../core/designs.js").DesignStore} The store.
 */
export function openSqliteDesignStore(path) {
  const db = new DatabaseSync(path);
  db.exec("PRAGMA journal_mode = WAL");
  migrate(db, STEPS);

  const state = db.prepare("SELECT (SELECT MAX(seq) FROM design_pushes) AS seq, (SELECT value FROM design_meta WHERE key = 'design_format') AS design_format, (SELECT value FROM design_meta WHERE key = 'min_format') AS min_format");
  const entity = db.prepare(`SELECT e.*, ${NAME} FROM design_entities e LEFT JOIN design_pushes p ON p.seq = e.rev LEFT JOIN designers d ON d.id = e.by WHERE e.id = ?`);
  const entities = db.prepare(`SELECT e.*, ${NAME} FROM design_entities e LEFT JOIN design_pushes p ON p.seq = e.rev LEFT JOIN designers d ON d.id = e.by
    WHERE e.rev > ? AND e.id > ? AND (? OR e.deleted = 0) ORDER BY e.id LIMIT ?`);
  const history = db.prepare(`SELECT h.*, ${NAME} FROM design_history h LEFT JOIN design_pushes p ON p.seq = h.rev LEFT JOIN designers d ON d.id = h.by
    WHERE h.id = ? ORDER BY h.rev DESC LIMIT ?`);
  const pushRow = db.prepare("INSERT INTO design_pushes (seq, by, by_name, at, message, design_format, client_version, ids) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
  const entityRow = db.prepare("INSERT OR REPLACE INTO design_entities (id, kind, schema, rev, body, deleted, by, at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
  const historyRow = db.prepare("INSERT OR REPLACE INTO design_history (id, rev, schema, body, deleted, by, at) VALUES (?, ?, ?, ?, ?, ?, ?)");
  const prune = db.prepare("DELETE FROM design_history WHERE id = ? AND rev NOT IN (SELECT rev FROM design_history WHERE id = ? ORDER BY rev DESC LIMIT ?)");
  const metaRow = db.prepare("INSERT OR REPLACE INTO design_meta (key, value) VALUES (?, ?)");
  const designer = db.prepare("SELECT * FROM designers WHERE id = ?");
  const designers = db.prepare("SELECT * FROM designers ORDER BY name, id");
  const designerRow = db.prepare(`INSERT INTO designers (id, name, admin, added_by, at, last_seen) VALUES (?, ?, ?, ?, ?, NULL)
    ON CONFLICT (id) DO UPDATE SET name = excluded.name, admin = excluded.admin`);
  const removeDesigner = db.prepare("DELETE FROM designers WHERE id = ?");
  const seen = db.prepare("UPDATE designers SET last_seen = ? WHERE id = ?");
  const blob = db.prepare("SELECT gz FROM design_blobs WHERE sha256 = ?");
  const blobBytes = db.prepare("UPDATE design_blobs SET gz = ? WHERE sha256 = ?");

  /**
   * Sets the design format and the lowest design format the relay takes.
   *
   * @param {{designFormat: number, minFormat: number}} format The formats.
   */
  const putFormat = ({ designFormat, minFormat }) => {
    metaRow.run("design_format", String(designFormat));
    metaRow.run("min_format", String(minFormat));
  };

  return {
    state: async () => {
      const row = state.get();
      return {
        seq: Number(row.seq ?? 0),
        designFormat: row.design_format === null ? undefined : Number(row.design_format),
        minFormat: row.min_format === null ? undefined : Number(row.min_format),
      };
    },
    entity: async (id) => plain(entity.get(id)),
    entities: async ({ since, after, limit, tombstones }) => entities.all(since, after, tombstones ? 1 : 0, limit).map(plain),
    history: async (id, limit) => history.all(id, limit).map(plain),
    commit: async (push) => transaction(db, () => {
      pushRow.run(push.seq, push.by, push.name, push.at, push.message, push.designFormat, push.clientVersion, JSON.stringify(push.entities.map((each) => each.id)));

      for (const each of push.entities) {
        const deleted = each.deleted ? 1 : 0;
        entityRow.run(each.id, each.kind, each.schema, push.seq, each.body, deleted, push.by, push.at);
        historyRow.run(each.id, push.seq, each.schema, each.body, deleted, push.by, push.at);
        prune.run(each.id, each.id, push.keep);
      }

      if (push.format) {
        putFormat(push.format);
      }
    }),
    setFormat: async (format) => transaction(db, () => putFormat(format)),
    designer: async (id) => plain(designer.get(id)),
    designers: async () => designers.all().map(plain),
    putDesigner: async ({ id, name, admin, addedBy, at }) => void designerRow.run(id, name, admin ? 1 : 0, addedBy, at),
    removeDesigner: async (id) => void removeDesigner.run(id),
    seen: async (id, at) => void seen.run(at, id),
    exportTables: async () => Object.fromEntries(DESIGN_TABLE_NAMES.map((name) => [name, db.prepare(`SELECT * FROM ${name} ORDER BY ${ORDER[name]}`).all()
      .map(({ gz, ...row }) => plain(row))])),
    blob: async (sha256) => blob.get(sha256)?.gz,
    importTables: async (rows, bytes) => transaction(db, () => {
      for (const name of DESIGN_TABLE_NAMES) {
        for (const row of rows[name] ?? []) {
          // A blob's bytes come apart from its row, so the row is first kept with none.
          const values = name === "design_blobs" ? { ...row, gz: new Uint8Array(0) } : row;
          const columns = Object.keys(values);

          if (!columns.every((column) => COLUMN.test(column))) {
            throw new Error(`a row of ${name} names a column that is no plain name`);
          }

          db.prepare(`INSERT INTO ${name} (${columns.join(", ")}) VALUES (${columns.map(() => "?").join(", ")})`).run(...columns.map((column) => values[column]));
        }
      }

      for (const [sha256, gz] of bytes) {
        blobBytes.run(Uint8Array.from(gz), sha256);
      }
    }),
    close: () => db.close(),
  };
}

/**
 * Copies a row SQLite handed out into a plain object.
 *
 * @param {object | undefined} row The row.
 * @returns {object | undefined} The copy, undefined for no row.
 */
function plain(row) {
  return row ? { ...row } : undefined;
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
