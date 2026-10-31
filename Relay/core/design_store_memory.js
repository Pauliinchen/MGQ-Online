//----------------------------------------------------------------
//  design_store_memory.js
//
//  Changelog:
//      Paulinchen  2026-10-22: Kept the design epoch
//                            - Kept the live build each build was compiled against
//                            - Kept the builds, their blobs and the live build
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

// The Raid design store in memory, for a Node relay without a database and for the tests. It keeps
// the same tables and rows as node/design_store_sqlite.js, so a migration reads both alike.

import { hexOf } from "./ids.js";

/**
 * The tables the store keeps, by name, with each row's key.
 */
const KEYS = Object.freeze({
  designers: (row) => row.id,
  design_meta: (row) => row.key,
  design_pushes: (row) => row.seq,
  design_entities: (row) => row.id,
  design_history: (row) => `${row.id}\u0000${String(row.rev).padStart(16, "0")}`,
  design_blobs: (row) => row.sha256,
  design_builds: (row) => row.id,
  design_live: (row) => row.channel,
});

/**
 * The design meta key of the design epoch.
 */
export const EPOCH_KEY = "epoch";

/**
 * Makes a new design epoch.
 *
 * @returns {string} 32 random hex characters.
 */
export function newEpoch() {
  return hexOf(crypto.getRandomValues(new Uint8Array(16)));
}

/**
 * Compares two keys in ordinal order, as SQLite sorts text and integers.
 *
 * @param {string | number} left The first key.
 * @param {string | number} right The second key.
 * @returns {number} Below 0 when the first comes first, 0 when both are equal, above 0 otherwise.
 */
function byKey(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

/**
 * Makes a Raid design store in memory.
 *
 * @returns {import("./designs.js").DesignStore} The store.
 */
export function memoryDesignStore() {
  /** @type {Record<string, Map<string | number, object>>} */
  const tables = Object.fromEntries(Object.keys(KEYS).map((name) => [name, new Map()]));
  /** @type {Map<string, Uint8Array>} */
  const blobs = new Map();
  // The newest build id handed out, which never comes again, as SQLite's AUTOINCREMENT keeps it.
  let lastBuild = 0;

  /**
   * Puts a row into a table, a copy of it, over the row of the same key.
   *
   * @param {string} name The table.
   * @param {object} row The row.
   */
  const put = (name, row) => void tables[name].set(KEYS[name](row), { ...row });

  /**
   * Names the designer of a revision: as the push named them, else as the designer list names them.
   *
   * @param {{rev: number, by: string}} row The revision.
   * @returns {string} The name, empty when neither knows one.
   */
  const nameOf = (row) => tables.design_pushes.get(row.rev)?.by_name ?? tables.designers.get(row.by)?.name ?? "";

  /**
   * Reads a value of the design meta table.
   *
   * @param {string} key The key.
   * @returns {string | undefined} The value, undefined when it is not set.
   */
  const meta = (key) => tables.design_meta.get(key)?.value;

  /**
   * Reads the design epoch, making a new one when an import left none.
   *
   * @returns {string} The epoch.
   */
  const epoch = () => {
    if (meta(EPOCH_KEY) === undefined) {
      put("design_meta", { key: EPOCH_KEY, value: newEpoch() });
    }

    return meta(EPOCH_KEY);
  };

  /**
   * Sets the design format and the lowest design format the relay takes.
   *
   * @param {{designFormat: number, minFormat: number}} format The formats.
   */
  const putFormat = ({ designFormat, minFormat }) => {
    put("design_meta", { key: "design_format", value: String(designFormat) });
    put("design_meta", { key: "min_format", value: String(minFormat) });
  };

  // A store in memory starts empty on every start, so every start is a new epoch.
  epoch();

  return {
    state: async () => ({
      seq: [...tables.design_pushes.keys()].reduce((newest, seq) => Math.max(newest, seq), 0),
      epoch: epoch(),
      designFormat: meta("design_format") === undefined ? undefined : Number(meta("design_format")),
      minFormat: meta("min_format") === undefined ? undefined : Number(meta("min_format")),
    }),
    entity: async (id) => {
      const row = tables.design_entities.get(id);
      return row ? { ...row, name: nameOf(row) } : undefined;
    },
    entities: async ({ since, after, limit, tombstones }) => [...tables.design_entities.values()]
      .filter((row) => row.rev > since && row.id > after && (tombstones || row.deleted === 0))
      .sort((left, right) => byKey(left.id, right.id))
      .slice(0, limit)
      .map((row) => ({ ...row, name: nameOf(row) })),
    history: async (id, limit) => [...tables.design_history.values()]
      .filter((row) => row.id === id)
      .sort((left, right) => right.rev - left.rev)
      .slice(0, limit)
      .map((row) => ({ ...row, name: nameOf(row) })),
    commit: async (push) => {
      put("design_pushes", {
        seq: push.seq, by: push.by, by_name: push.name, at: push.at, message: push.message, design_format: push.designFormat,
        client_version: push.clientVersion, ids: JSON.stringify(push.entities.map((entity) => entity.id)),
      });

      for (const entity of push.entities) {
        const row = { id: entity.id, kind: entity.kind, schema: entity.schema, rev: push.seq, body: entity.body, deleted: entity.deleted ? 1 : 0, by: push.by, at: push.at };
        put("design_entities", row);
        put("design_history", { id: row.id, rev: row.rev, schema: row.schema, body: row.body, deleted: row.deleted, by: row.by, at: row.at });
        const revisions = [...tables.design_history.values()].filter((each) => each.id === entity.id).sort((left, right) => right.rev - left.rev);

        for (const old of revisions.slice(push.keep)) {
          tables.design_history.delete(KEYS.design_history(old));
        }
      }

      if (push.format) {
        putFormat(push.format);
      }
    },
    setFormat: async (format) => putFormat(format),
    setEpoch: async (value) => put("design_meta", { key: EPOCH_KEY, value }),
    designer: async (id) => (tables.designers.has(id) ? { ...tables.designers.get(id) } : undefined),
    designers: async () => [...tables.designers.values()].sort((left, right) => byKey(left.name, right.name) || byKey(left.id, right.id)).map((row) => ({ ...row })),
    putDesigner: async ({ id, name, admin, addedBy, at }) => {
      const earlier = tables.designers.get(id);
      put("designers", earlier ? { ...earlier, name, admin: admin ? 1 : 0 } : { id, name, admin: admin ? 1 : 0, added_by: addedBy, at, last_seen: null });
    },
    removeDesigner: async (id) => void tables.designers.delete(id),
    seen: async (id, at) => {
      const earlier = tables.designers.get(id);

      if (earlier) {
        put("designers", { ...earlier, last_seen: at });
      }
    },
    addBuild: async ({ seq, by, at }) => {
      lastBuild += 1;
      put("design_builds", {
        id: lastBuild, seq, snapshot_sha: null, runtime_sha: null, marshal_sha: null, format: null, runtime_format: null, compiler: null, game_data: null,
        status: "queued", report: null, by, at, base_build_id: null,
      });
      return lastBuild;
    },
    build: async (id) => (tables.design_builds.has(id) ? { ...tables.design_builds.get(id) } : undefined),
    builds: async (limit) => [...tables.design_builds.values()].sort((left, right) => right.id - left.id).slice(0, limit).map((row) => ({ ...row })),
    setBuildStatus: async (id, status) => {
      const earlier = tables.design_builds.get(id);

      if (earlier) {
        put("design_builds", { ...earlier, status });
      }
    },
    finishBuild: async (id, fields, finished) => {
      const earlier = tables.design_builds.get(id);

      if (!earlier) {
        return;
      }

      for (const blob of finished) {
        if (!tables.design_blobs.has(blob.sha256)) {
          put("design_blobs", { sha256: blob.sha256, kind: blob.kind, size: blob.size, at: blob.at });
          blobs.set(blob.sha256, Uint8Array.from(blob.gz));
        }
      }

      put("design_builds", {
        ...earlier, status: fields.status, report: fields.report, snapshot_sha: fields.snapshotSha, runtime_sha: fields.runtimeSha, marshal_sha: fields.marshalSha,
        format: fields.format, runtime_format: fields.runtimeFormat, compiler: fields.compiler, game_data: fields.gameData, base_build_id: fields.baseBuildId,
      });
    },
    failUnfinished: async (report) => {
      const unfinished = [...tables.design_builds.values()].filter((row) => row.status === "queued" || row.status === "compiling");

      for (const row of unfinished) {
        put("design_builds", { ...row, status: "failed", report });
      }

      return unfinished.map((row) => row.id).sort((left, right) => left - right);
    },
    blobInfo: async (sha256) => (tables.design_blobs.has(sha256) ? { ...tables.design_blobs.get(sha256) } : undefined),
    live: async () => (tables.design_live.has("live") ? { ...tables.design_live.get("live") } : undefined),
    setLive: async ({ buildId, previousBuildId, by, at }) => put("design_live", { channel: "live", build_id: buildId, previous_build_id: previousBuildId, by, at }),
    tidyBuilds: async (keep) => {
      const live = tables.design_live.get("live");
      const kept = new Set([live?.build_id, live?.previous_build_id]);
      const newest = [...tables.design_builds.values()].sort((left, right) => right.id - left.id);
      const dropped = newest.slice(keep).filter((row) => !kept.has(row.id) && row.status !== "queued" && row.status !== "compiling");

      for (const row of dropped) {
        tables.design_builds.delete(row.id);
      }

      const used = new Set([...tables.design_builds.values()].flatMap((row) => [row.snapshot_sha, row.runtime_sha, row.marshal_sha]));
      const unused = [...tables.design_blobs.keys()].filter((sha256) => !used.has(sha256));

      for (const sha256 of unused) {
        tables.design_blobs.delete(sha256);
        blobs.delete(sha256);
      }

      return { builds: dropped.length, blobs: unused.length };
    },
    exportTables: async () => Object.fromEntries(Object.keys(KEYS).map((name) => [name, [...tables[name].values()]
      .sort((left, right) => byKey(KEYS[name](left), KEYS[name](right)))
      .map(({ gz, ...row }) => row)])),
    blob: async (sha256) => blobs.get(sha256),
    importTables: async (rows, bytes) => {
      if (rows.design_meta) {
        tables.design_meta.clear();
      }

      for (const [name, list] of Object.entries(rows).filter(([name]) => name in KEYS)) {
        for (const row of list) {
          put(name, row);
        }
      }

      for (const [sha256, gz] of bytes) {
        blobs.set(sha256, Uint8Array.from(gz));
      }

      lastBuild = Math.max(lastBuild, ...tables.design_builds.keys());
    },
    close: () => {},
  };
}
