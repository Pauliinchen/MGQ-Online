//----------------------------------------------------------------
//  design_store_sqlite.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Kept the design epoch and made a new one after a restore from a backup
//                            - Kept the live build each build was compiled against
//                            - Kept the builds, their blobs and the live build
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

// The Raid design store over the relay's SQLite database, in the tables node/schema.js makes. Every
// write runs synchronously in one transaction, so nothing else of the relay runs while it is half
// done, although the store keeps a connection of its own beside node/sqlite_store.js.

import { readFileSync, renameSync, writeFileSync } from "node:fs";
import { basename, dirname, extname, join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { EPOCH_KEY, newEpoch } from "../core/design_store_memory.js";
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
 * The extension of the file beside the database that holds the highest seq the relay handed out.
 */
export const SEQ_MARK_EXTENSION = ".design-seq";

/**
 * Names the file that holds the highest seq the relay handed out: the database's name with
 * SEQ_MARK_EXTENSION in place of its extension, so moving `relay.sqlite*` aside leaves it behind.
 *
 * @param {string} path The database file's path.
 * @returns {string | null} The file's path, null for a database in memory.
 */
export function seqMarkOf(path) {
  return path === ":memory:" ? null : join(dirname(path), basename(path, extname(path)) + SEQ_MARK_EXTENSION);
}

/**
 * Opens the Raid design store over a SQLite database, bringing its tables up to the last step, and
 * makes a new design epoch when the database has none or holds fewer pushes than the relay handed
 * out, as after a restore from a backup.
 *
 * @param {string} path The database file's path, made when it is missing.
 * @param {{log?: (text: string) => void}} [options] Where to tell of a new epoch and of a seq mark that cannot be written.
 * @returns {import("../core/designs.js").DesignStore} The store.
 */
export function openSqliteDesignStore(path, { log = () => {} } = {}) {
  const db = new DatabaseSync(path);
  db.exec("PRAGMA journal_mode = WAL");
  migrate(db, STEPS);

  const state = db.prepare(`SELECT (SELECT MAX(seq) FROM design_pushes) AS seq, (SELECT value FROM design_meta WHERE key = '${EPOCH_KEY}') AS epoch,
    (SELECT value FROM design_meta WHERE key = 'design_format') AS design_format, (SELECT value FROM design_meta WHERE key = 'min_format') AS min_format`);
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
  const clearMeta = db.prepare("DELETE FROM design_meta");
  const designer = db.prepare("SELECT * FROM designers WHERE id = ?");
  const designers = db.prepare("SELECT * FROM designers ORDER BY name, id");
  const designerRow = db.prepare(`INSERT INTO designers (id, name, admin, added_by, at, last_seen) VALUES (?, ?, ?, ?, ?, NULL)
    ON CONFLICT (id) DO UPDATE SET name = excluded.name, admin = excluded.admin`);
  const removeDesigner = db.prepare("DELETE FROM designers WHERE id = ?");
  const seen = db.prepare("UPDATE designers SET last_seen = ? WHERE id = ?");
  const blob = db.prepare("SELECT gz FROM design_blobs WHERE sha256 = ?");
  const blobBytes = db.prepare("UPDATE design_blobs SET gz = ? WHERE sha256 = ?");
  const blobRow = db.prepare("INSERT OR IGNORE INTO design_blobs (sha256, kind, size, gz, at) VALUES (?, ?, ?, ?, ?)");
  const blobInfo = db.prepare("SELECT sha256, kind, size, at FROM design_blobs WHERE sha256 = ?");
  const buildRow = db.prepare("INSERT INTO design_builds (seq, status, by, at) VALUES (?, 'queued', ?, ?)");
  const build = db.prepare("SELECT * FROM design_builds WHERE id = ?");
  const builds = db.prepare("SELECT * FROM design_builds ORDER BY id DESC LIMIT ?");
  const buildStatus = db.prepare("UPDATE design_builds SET status = ? WHERE id = ?");
  const buildDone = db.prepare(`UPDATE design_builds SET status = ?, report = ?, snapshot_sha = ?, runtime_sha = ?, marshal_sha = ?, format = ?, runtime_format = ?,
    compiler = ?, game_data = ?, base_build_id = ? WHERE id = ?`);
  const unfinished = db.prepare("UPDATE design_builds SET status = 'failed', report = ? WHERE status IN ('queued', 'compiling') RETURNING id");
  const live = db.prepare("SELECT * FROM design_live WHERE channel = 'live'");
  const liveRow = db.prepare("INSERT OR REPLACE INTO design_live (channel, build_id, previous_build_id, by, at) VALUES ('live', ?, ?, ?, ?)");
  const dropBuilds = db.prepare(`DELETE FROM design_builds WHERE status NOT IN ('queued', 'compiling')
    AND id NOT IN (SELECT id FROM design_builds ORDER BY id DESC LIMIT ?)
    AND id NOT IN (SELECT build_id FROM design_live UNION SELECT previous_build_id FROM design_live WHERE previous_build_id IS NOT NULL)`);
  const dropBlobs = db.prepare(`DELETE FROM design_blobs WHERE sha256 NOT IN (SELECT snapshot_sha FROM design_builds WHERE snapshot_sha IS NOT NULL
    UNION SELECT runtime_sha FROM design_builds WHERE runtime_sha IS NOT NULL UNION SELECT marshal_sha FROM design_builds WHERE marshal_sha IS NOT NULL)`);

  /**
   * Sets the design format and the lowest design format the relay takes.
   *
   * @param {{designFormat: number, minFormat: number}} format The formats.
   */
  const putFormat = ({ designFormat, minFormat }) => {
    metaRow.run("design_format", String(designFormat));
    metaRow.run("min_format", String(minFormat));
  };

  const mark = seqMarkOf(path);

  /**
   * Writes the highest seq the relay handed out beside the database, through a temporary file.
   *
   * @param {number} seq The seq.
   */
  const putMark = (seq) => {
    if (!mark) {
      return;
    }

    try {
      writeFileSync(`${mark}.tmp`, `${seq}\n`);
      renameSync(`${mark}.tmp`, mark);
    } catch (error) {
      log(`designs: cannot write ${mark} (${error.message}); a restore from a backup is then only noticed when the restore removes the epoch`);
    }
  };

  /**
   * Reads the design epoch, making a new one when the database has none.
   *
   * @returns {object} The state row, with the epoch.
   */
  const stateRow = () => {
    const row = state.get();

    if (row.epoch !== null) {
      return row;
    }

    metaRow.run(EPOCH_KEY, newEpoch());
    return state.get();
  };

  const stored = Number(stateRow().seq ?? 0);
  const handedOut = mark ? readMark(mark) : 0;

  if (stored < handedOut) {
    metaRow.run(EPOCH_KEY, newEpoch());
    putMark(stored);
    log(`designs: the database holds pushes up to seq ${stored}, the relay handed out ${handedOut}; a new design epoch makes every designer pull again`);
  }

  return {
    state: async () => {
      const row = stateRow();
      return {
        seq: Number(row.seq ?? 0),
        epoch: row.epoch,
        designFormat: row.design_format === null ? undefined : Number(row.design_format),
        minFormat: row.min_format === null ? undefined : Number(row.min_format),
      };
    },
    entity: async (id) => plain(entity.get(id)),
    entities: async ({ since, after, limit, tombstones }) => entities.all(since, after, tombstones ? 1 : 0, limit).map(plain),
    history: async (id, limit) => history.all(id, limit).map(plain),
    commit: async (push) => {
      transaction(db, () => {
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
      });
      putMark(push.seq);
    },
    setFormat: async (format) => transaction(db, () => putFormat(format)),
    setEpoch: async (epoch) => void metaRow.run(EPOCH_KEY, epoch),
    designer: async (id) => plain(designer.get(id)),
    designers: async () => designers.all().map(plain),
    putDesigner: async ({ id, name, admin, addedBy, at }) => void designerRow.run(id, name, admin ? 1 : 0, addedBy, at),
    removeDesigner: async (id) => void removeDesigner.run(id),
    seen: async (id, at) => void seen.run(at, id),
    addBuild: async ({ seq, by, at }) => Number(buildRow.run(seq, by, at).lastInsertRowid),
    build: async (id) => plain(build.get(id)),
    builds: async (limit) => builds.all(limit).map(plain),
    setBuildStatus: async (id, status) => void buildStatus.run(status, id),
    finishBuild: async (id, fields, finished) => transaction(db, () => {
      for (const blob of finished) {
        blobRow.run(blob.sha256, blob.kind, blob.size, blob.gz, blob.at);
      }

      buildDone.run(fields.status, fields.report, fields.snapshotSha, fields.runtimeSha, fields.marshalSha, fields.format, fields.runtimeFormat, fields.compiler, fields.gameData, fields.baseBuildId, id);
    }),
    failUnfinished: async (report) => unfinished.all(report).map((row) => Number(row.id)).sort((left, right) => left - right),
    blobInfo: async (sha256) => plain(blobInfo.get(sha256)),
    live: async () => plain(live.get()),
    setLive: async ({ buildId, previousBuildId, by, at }) => void liveRow.run(buildId, previousBuildId, by, at),
    tidyBuilds: async (keep) => {
      let counts;
      transaction(db, () => {
        counts = { builds: Number(dropBuilds.run(keep).changes), blobs: Number(dropBlobs.run().changes) };
      });
      return counts;
    },
    exportTables: async () => Object.fromEntries(DESIGN_TABLE_NAMES.map((name) => [name, db.prepare(`SELECT * FROM ${name} ORDER BY ${ORDER[name]}`).all()
      .map(({ gz, ...row }) => plain(row))])),
    blob: async (sha256) => blob.get(sha256)?.gz,
    importTables: async (rows, bytes) => transaction(db, () => {
      if (rows.design_meta) {
        clearMeta.run();
      }

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
 * Reads the highest seq the relay handed out from the file beside the database.
 *
 * @param {string} mark The file's path.
 * @returns {number} The seq, 0 when the file is missing or holds no whole number.
 */
function readMark(mark) {
  try {
    const text = readFileSync(mark, "utf8").trim();
    return /^\d{1,15}$/.test(text) ? Number(text) : 0;
  } catch {
    return 0;
  }
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
