//----------------------------------------------------------------
//  migration.js
//
//  Changelog:
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

// Hands everything a relay keeps to its admins, so another relay can take it over: the worlds with
// their starting saves, chats, stories and boss pools, the mod catalog with its uploads, and the
// trades with their sealed offers. Both relays answer it through the same stores, the Cloudflare
// relay from its objects and the Node relay from SQLite; node/migrate.js reads it into a database.

import { playerIdOf } from "./directory.js";
import { notFound } from "./http.js";
import { isId } from "./ids.js";
import { VERSION } from "./relay.js";
import { PART } from "./story.js";

/**
 * The route's name after the version.
 */
export const MIGRATION_ROUTE = "migration";

/**
 * The format of what the routes hand out, which an importer checks before reading anything.
 */
export const MIGRATION_FORMAT = 1;

/**
 * Reads which part of the migration an address names.
 *
 * @param {URL} url The request's address.
 * @returns {{rest: string[]} | null} The parts after `migration`, decoded; or null when it is no migration route.
 */
export function migrationRouteOf(url) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);

  if (parts.length < 2 || parts[0] !== VERSION || parts[1] !== MIGRATION_ROUTE) {
    return null;
  }

  try {
    return { rest: parts.slice(2).map((part) => decodeURIComponent(part)) };
  } catch {
    return { rest: [""] };
  }
}

/**
 * Makes the check whether a player key is one of the relay's admins.
 *
 * @param {Set<string>} admins The admins' player ids.
 * @returns {(key: unknown) => Promise<boolean>} The check.
 */
export function adminCheck(admins) {
  return async (key) => isId(key) && admins.has(await playerIdOf(key));
}

/**
 * Reads what a world keeps beside the directory: its story, the story's part checkpoints and its
 * boss pools, which a Classic world with raid bosses has too.
 *
 * @param {import("./story.js").StoryStore} story The world's story store.
 * @param {import("./bosses.js").BossStore} bosses The world's boss pool store.
 * @returns {Promise<{story: object | null, checkpoints: object[], pools: object[]}>} What it keeps.
 */
export async function exportWorldData(story, bosses) {
  const checkpoints = [];

  for (const part of Object.values(PART)) {
    const checkpoint = await story.getCheckpoint(part);

    if (checkpoint) {
      checkpoints.push(checkpoint);
    }
  }

  return { story: (await story.get()) ?? null, checkpoints, pools: await bosses.all() };
}

/**
 * Answers a request to the migration routes, for the relay's admins only:
 * `GET /v1/migration` lists the worlds, mods and trades; `GET /v1/migration/worlds/<id>` hands out a
 * world's entry, chat, story, checkpoints and boss pools, `.../start` its starting save;
 * `GET /v1/migration/mods/<key>` a mod's entry, `.../file` its upload; `GET /v1/migration/trades/<id>`
 * a trade's record and sealed offers.
 *
 * @param {{directory: import("./directory.js").DirectoryStore, mods: import("./mods.js").ModStore, trades: import("./trades.js").TradeStore}} stores The relay's stores.
 * @param {(id: string) => Promise<{story: object | null, checkpoints: object[], pools: object[]}>} worldData Reads what a world keeps beside the directory, see exportWorldData.
 * @param {string} method The HTTP method.
 * @param {string[]} rest The address's parts after `migration`, see migrationRouteOf.
 * @param {string | null} key The player key the request names.
 * @param {(key: unknown) => Promise<boolean>} isAdmin Tells whether a key is an admin's, see adminCheck.
 * @returns {Promise<{status: number, body?: object, bytes?: Uint8Array | ReadableStream<Uint8Array>}>} The answer.
 */
export async function handleMigrationRequest(stores, worldData, method, rest, key, isAdmin) {
  if (method !== "GET") {
    return notFound("route");
  }

  if (!(await isAdmin(key))) {
    return { status: 403, body: { error: "only the relay's admins may read what it keeps" } };
  }

  const [kind, id, part] = rest;

  if (rest.length === 0) {
    const worlds = (await stores.directory.all()).map((entry) => entry.id);
    const mods = (await stores.mods.allMods()).map((entry) => entry.key);
    const trades = (await stores.trades.allTrades()).map((record) => record.id);
    return { status: 200, body: { format: MIGRATION_FORMAT, worlds, mods, trades } };
  }

  if (kind === "worlds" && rest.length <= 3) {
    const entry = await stores.directory.get(id);

    if (!entry) {
      return notFound("world");
    }

    if (rest.length === 2) {
      return { status: 200, body: { entry, chat: (await stores.directory.getChat(id)) ?? null, ...(await worldData(id)) } };
    }

    return part === "start" ? bytesAnswer(await stores.directory.getStart(id), "starting save") : notFound("route");
  }

  if (kind === "mods" && rest.length <= 3) {
    const entry = await stores.mods.getMod(id);

    if (!entry) {
      return notFound("mod");
    }

    if (rest.length === 2) {
      return { status: 200, body: { entry } };
    }

    return part === "file" ? bytesAnswer(await stores.mods.getModFile(id), "upload") : notFound("route");
  }

  if (kind === "trades" && rest.length === 2) {
    const record = await stores.trades.getTrade(id);

    if (!record) {
      return notFound("trade");
    }

    const sealed = {};

    for (const player of Array.isArray(record.players) ? record.players : []) {
      const text = await stores.trades.getSealed(id, player);

      if (text !== undefined) {
        sealed[player] = text;
      }
    }

    return { status: 200, body: { record, sealed } };
  }

  return notFound("route");
}

/**
 * Answers with stored bytes, or that there are none.
 *
 * @param {Uint8Array | ReadableStream<Uint8Array> | undefined} bytes The bytes, as the store hands them out.
 * @param {string} what What they are, for the refusal.
 * @returns {{status: number, body?: object, bytes?: Uint8Array | ReadableStream<Uint8Array>}} The answer.
 */
function bytesAnswer(bytes, what) {
  return bytes ? { status: 200, bytes } : notFound(what);
}
