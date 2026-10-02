//----------------------------------------------------------------
//  directory.js
//
//  Changelog:
//      Paulinchen  2026-10-02: Kept whether a world lets each new player choose where to start
//                            - Kept whether a world has no password, and let admins make featured worlds beyond the creator limit
//                            - Listed when each player was last seen in a world, noting it as they leave too
//      Paulinchen  2026-10-01: Named admins in the refusal of a delete, and checked admin and banned ids as player ids
//      Paulinchen  2026-09-30: Listed every world for the relay's admins, hidden ones too, and let them delete any
//                            - Kept a world's starting save, which its creator uploads once and only its players fetch
//                            - Left hidden worlds out of the list for everyone but their players, and named a world with its lock
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

// The world directory's rules, the same on every server: the list of worlds, public ones for
// everyone and hidden ones only for their players and the relay's admins, whose own worlds may be
// featured; who may make, enter,
// delete or leave out whom; and who was in which world. The relay never learns a
// world's token or password: it keeps the token locked with the password, and checks entering
// against a hash of a key only the token's holders can make. A world's starting save reaches it
// encrypted with a key from the token, so the relay only keeps its bytes.
//
// It keeps its worlds through a store the platform layer passes in, and hands back what the layer
// must do beyond answering, such as closing a removed player's connection.

import { WORLD_SEATS } from "./relay.js";

/**
 * The limits the directory keeps.
 */
export const DIRECTORY_LIMITS = Object.freeze({
  maxNameLength: 32,
  maxWorlds: 2000,
  maxWorldsPerCreator: 20,
  maxMembers: 200,
  minIterations: 100_000,
  maxIterations: 5_000_000,
  maxLockHex: 512,
  maxStartBytes: 8 * 1024 * 1024,
});

/**
 * How far a world is with its starting save: it has none, its creator is still uploading it, or it is ready.
 */
export const START = Object.freeze({ none: "none", pending: "pending", ready: "ready" });

/**
 * A world id: 32 lowercase hexadecimal characters, the world room's id.
 */
const WORLD_ID = /^[0-9a-f]{32}$/;

/**
 * A player's key: 32 lowercase hexadecimal characters, which only the player's game knows.
 */
const PLAYER_KEY = /^[0-9a-f]{32}$/;

/**
 * A player's id, as playerIdOf makes it: 32 lowercase hexadecimal characters.
 */
const PLAYER_ID = /^[0-9a-f]{32}$/;

/**
 * A key or hash of 32 bytes, as 64 lowercase hexadecimal characters.
 */
const HEX_32 = /^[0-9a-f]{64}$/;

/**
 * A salt of 16 bytes, as 32 lowercase hexadecimal characters.
 */
const SALT = /^[0-9a-f]{32}$/;

/**
 * Lowercase hexadecimal of any length.
 */
const HEX = /^(?:[0-9a-f]{2})+$/;

/**
 * Characters a name may not hold: control characters, and the tab and line break the games read lists by.
 */
const NAME_BREAKERS = /[\u0000-\u001f\u007f]/g;

/**
 * Hashes a text with SHA-256.
 *
 * @param {string} text The text.
 * @returns {Promise<string>} The hash as 64 lowercase hexadecimal characters.
 */
export async function sha256Hex(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/**
 * Turns a player's key into the id everyone sees, which does not give the key away.
 *
 * @param {string} key The player's key.
 * @returns {Promise<string>} The player's id, 32 lowercase hexadecimal characters.
 */
export async function playerIdOf(key) {
  return (await sha256Hex(`mgqmp player ${key}`)).slice(0, 32);
}

/**
 * Reads the relay's admins from its settings: player ids, separated by commas or white space.
 *
 * @param {unknown} text The setting, undefined when it is not set.
 * @returns {string[]} The admins' player ids, empty for none; anything else in the setting is left out.
 */
export function parseAdmins(text) {
  return typeof text === "string" ? text.toLowerCase().split(/[\s,]+/).filter((id) => PLAYER_ID.test(id)) : [];
}

/**
 * Tidies a name someone chose: on one line, without control characters, trimmed and not too long.
 *
 * @param {unknown} name The name.
 * @param {typeof DIRECTORY_LIMITS} [limits] The limits.
 * @returns {string | null} The name, or null when nothing is left of it.
 */
export function cleanName(name, limits = DIRECTORY_LIMITS) {
  if (typeof name !== "string") {
    return null;
  }

  const cleaned = [...name.replace(NAME_BREAKERS, "").trim()].slice(0, limits.maxNameLength).join("");
  return cleaned.length > 0 ? cleaned : null;
}

/**
 * @typedef {object} DirectoryStore Where the directory keeps its worlds, one entry each, and their starting saves.
 * @property {(id: string) => Promise<object | undefined>} get Reads a world's entry.
 * @property {(entry: object) => Promise<void>} put Writes a world's entry.
 * @property {(id: string) => Promise<void>} remove Deletes a world's entry and its starting save.
 * @property {() => Promise<object[]>} all Reads every world's entry.
 * @property {(id: string, bytes: Uint8Array) => Promise<void>} putStart Writes a world's starting save.
 * @property {(id: string) => Promise<Uint8Array | undefined>} getStart Reads a world's starting save.
 */

/**
 * The world directory, over a store of world entries.
 */
export class Directory {
  /**
   * Creates the directory.
   *
   * @param {DirectoryStore} store Where the worlds and their starting saves are kept.
   * @param {{clock?: () => number, limits?: typeof DIRECTORY_LIMITS, admins?: string[]}} [options] The clock and limits, which tests change, and the player ids of the relay's admins.
   */
  constructor(store, { clock = Date.now, limits = DIRECTORY_LIMITS, admins = [] } = {}) {
    this.store = store;
    this.clock = clock;
    this.limits = limits;
    this.admins = new Set(admins);
  }

  /**
   * Lists the worlds a player sees: every public world, and the hidden ones the player joined, or
   * every world for an admin.
   *
   * @param {unknown} [key] The asking player's key; without one, only the public worlds.
   * @returns {Promise<{status: number, body: object}>} The worlds, and whether the player is an admin.
   */
  async list(key) {
    const player = typeof key === "string" && PLAYER_KEY.test(key) ? await playerIdOf(key) : null;
    const admin = this.admins.has(player);
    const worlds = (await this.store.all()).filter((entry) => admin || !entry.hidden || (player && entry.members[player])).map((entry) => publicView(entry));
    return { status: 200, body: { worlds, admin } };
  }

  /**
   * Hands out a world's locked token, which only its password opens, with what a player who
   * found it by its id alone needs to enter it.
   *
   * @param {string} id The world.
   * @returns {Promise<{status: number, body: object}>} The lock with the world's name, seats, starting save state and whether new players choose where to start, or why there is none.
   */
  async lock(id) {
    const entry = WORLD_ID.test(id) ? await this.store.get(id) : undefined;
    return entry ? { status: 200, body: { ...entry.lock, name: entry.name, seats: entry.seats, start: entry.start ?? START.none, choose: entry.choose === true } } : notFound();
  }

  /**
   * Makes a world.
   *
   * @param {object} request The world: id, name, seats, the creator's player key and name, the hash of the auth key, the lock, whether a starting save follows, whether it is hidden from the list, whether each new player chooses where to start, whether it has no password, and whether it is featured.
   * @returns {Promise<{status: number, body: object}>} The world's id, or why it was refused.
   */
  async create(request) {
    const refusal = this.checkNewWorld(request);

    if (refusal) {
      return badRequest(refusal);
    }

    if (await this.store.get(request.id)) {
      return { status: 409, body: { error: "a world with this id exists" } };
    }

    const creator = await playerIdOf(request.player);
    const admin = this.admins.has(creator);
    const worlds = await this.store.all();

    if (request.featured === true && !admin) {
      return { status: 403, body: { error: "only the relay's admins may make featured worlds" } };
    }

    if (worlds.length >= this.limits.maxWorlds) {
      return { status: 503, body: { error: "the directory is full" } };
    }

    if (!admin && worlds.filter((entry) => entry.creator.id === creator).length >= this.limits.maxWorldsPerCreator) {
      return { status: 429, body: { error: `a player may make at most ${this.limits.maxWorldsPerCreator} worlds` } };
    }

    const now = this.clock();
    const creatorName = cleanName(request.playerName, this.limits);

    await this.store.put({
      id: request.id,
      name: cleanName(request.name, this.limits),
      seats: request.seats,
      creator: { id: creator, name: creatorName },
      authHash: request.authHash,
      lock: { salt: request.lock.salt, iterations: request.lock.iterations, box: request.lock.box },
      start: request.start === true ? START.pending : START.none,
      hidden: request.hidden === true,
      choose: request.choose === true,
      open: request.open === true,
      featured: request.featured === true,
      created: now,
      active: now,
      members: { [creator]: { name: creatorName, seen: now } },
      online: [],
      bans: [],
    });

    return { status: 201, body: { id: request.id } };
  }

  /**
   * Deletes a world for everyone, if the creator or an admin asks.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @returns {Promise<{status: number, body: object, close?: boolean}>} The answer, and whether the world room must close.
   */
  async remove(id, key) {
    const { entry, refusal } = await this.asCreatorOrAdmin(id, key);

    if (refusal) {
      return refusal;
    }

    await this.store.remove(entry.id);
    return { status: 200, body: { deleted: entry.id }, close: true };
  }

  /**
   * Removes a player from a world and keeps them out, if the creator asks.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @param {unknown} target The id of the player to remove.
   * @returns {Promise<{status: number, body: object, kick?: string}>} The answer, and the player whose connection must close.
   */
  async ban(id, key, target) {
    const { entry, refusal } = await this.asCreator(id, key);

    if (refusal) {
      return refusal;
    }

    if (typeof target !== "string" || !PLAYER_ID.test(target) || target === entry.creator.id) {
      return badRequest("the player to remove must be another player's id");
    }

    delete entry.members[target];
    entry.online = entry.online.filter((player) => player !== target);

    if (!entry.bans.includes(target)) {
      entry.bans.push(target);
    }

    await this.store.put(entry);
    return { status: 200, body: { removed: target }, kick: target };
  }

  /**
   * Decides whether a game may take a seat in a world room.
   *
   * @param {string} id The world.
   * @param {unknown} key The player's key.
   * @param {unknown} auth The auth key the player's game made from the world's token.
   * @returns {Promise<{status: number, body: object, seats?: number, player?: string}>} The world's seats and the player's id, or why not.
   */
  async admit(id, key, auth) {
    const { entry, player, refusal } = await this.asPlayer(id, key, auth);

    if (refusal) {
      return refusal;
    }

    if (entry.start === START.pending) {
      return { status: 409, body: { error: "the world's starting save is still being uploaded" } };
    }

    return { status: 200, body: { seats: entry.seats, player }, seats: entry.seats, player };
  }

  /**
   * Keeps a world's starting save, which its creator uploads once, right after making the world.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @param {Uint8Array | null} bytes The starting save, encrypted by the creator's game; null when it was too large to read.
   * @returns {Promise<{status: number, body: object}>} The answer.
   */
  async putStart(id, key, bytes) {
    const { entry, refusal } = await this.asCreator(id, key);

    if (refusal) {
      return refusal;
    }

    if (entry.start !== START.pending) {
      return { status: 409, body: { error: "the world takes no starting save" } };
    }

    if (!bytes || bytes.length === 0 || bytes.length > this.limits.maxStartBytes) {
      return { status: 413, body: { error: `the starting save must be 1 to ${this.limits.maxStartBytes} bytes` } };
    }

    await this.store.putStart(entry.id, bytes);
    entry.start = START.ready;
    await this.store.put(entry);
    return { status: 200, body: { bytes: bytes.length } };
  }

  /**
   * Hands a world's starting save to one of its players.
   *
   * @param {string} id The world.
   * @param {unknown} key The player's key.
   * @param {unknown} auth The auth key the player's game made from the world's token.
   * @returns {Promise<{status: number, body: object, bytes?: Uint8Array}>} The starting save, or why not.
   */
  async getStart(id, key, auth) {
    const { entry, refusal } = await this.asPlayer(id, key, auth);

    if (refusal) {
      return refusal;
    }

    const bytes = entry.start === START.ready ? await this.store.getStart(entry.id) : undefined;
    return bytes ? { status: 200, body: {}, bytes } : { status: 404, body: { error: "the world has no starting save" } };
  }

  /**
   * Notes who is in a world's room now, as the room reports after every change, and when those
   * who left were last seen.
   *
   * @param {string} id The world.
   * @param {{player: string, name: string}[]} online The players in the room.
   * @returns {Promise<{status: number, body: object}>} The answer.
   */
  async presence(id, online) {
    const entry = WORLD_ID.test(id) ? await this.store.get(id) : undefined;

    if (!entry) {
      return notFound();
    }

    const now = this.clock();

    for (const player of entry.online) {
      if (entry.members[player]) {
        entry.members[player].seen = now;
      }
    }

    entry.online = [];

    for (const { player, name } of online) {
      if (entry.bans.includes(player)) {
        continue;
      }

      entry.members[player] = { name: cleanName(name, this.limits) ?? entry.members[player]?.name ?? "?", seen: now };
      entry.online.push(player);
    }

    if (online.length > 0) {
      entry.active = now;
    }

    await this.store.put(entry);
    return { status: 200, body: { online: entry.online.length } };
  }

  /**
   * Finds a world for a player who holds its token and was not removed from it.
   *
   * @param {string} id The world.
   * @param {unknown} key The player's key.
   * @param {unknown} auth The auth key the player's game made from the world's token.
   * @returns {Promise<{entry?: object, player?: string, refusal?: {status: number, body: object}}>} The world and the player's id, or why the player may not.
   */
  async asPlayer(id, key, auth) {
    const entry = WORLD_ID.test(id) ? await this.store.get(id) : undefined;

    if (!entry) {
      return { refusal: notFound() };
    }

    if (typeof key !== "string" || !PLAYER_KEY.test(key) || typeof auth !== "string" || !HEX_32.test(auth)) {
      return { refusal: badRequest("a player key and an auth key are needed") };
    }

    if ((await sha256Hex(auth)) !== entry.authHash) {
      return { refusal: { status: 401, body: { error: "the world's token does not match" } } };
    }

    const player = await playerIdOf(key);

    if (entry.bans.includes(player)) {
      return { refusal: { status: 403, body: { error: "the creator removed this player from the world" } } };
    }

    if (!entry.members[player] && Object.keys(entry.members).length >= this.limits.maxMembers) {
      return { refusal: { status: 403, body: { error: "the world has as many players as it may" } } };
    }

    return { entry, player };
  }

  /**
   * Finds a world for its creator.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @returns {Promise<{entry?: object, refusal?: {status: number, body: object}}>} The world, or why the player may not act on it.
   */
  async asCreator(id, key) {
    const { entry, player, refusal } = await this.worldAndPlayer(id, key);

    if (refusal) {
      return { refusal };
    }

    if (player !== entry.creator.id) {
      return { refusal: { status: 403, body: { error: "only the world's creator may do this" } } };
    }

    return { entry };
  }

  /**
   * Finds a world for its creator or one of the relay's admins.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @returns {Promise<{entry?: object, refusal?: {status: number, body: object}}>} The world, or why the player may not act on it.
   */
  async asCreatorOrAdmin(id, key) {
    const { entry, player, refusal } = await this.worldAndPlayer(id, key);

    if (refusal) {
      return { refusal };
    }

    if (player !== entry.creator.id && !this.admins.has(player)) {
      return { refusal: { status: 403, body: { error: "only the world's creator or an admin may do this" } } };
    }

    return { entry };
  }

  /**
   * Finds a world and the id of the player asking about it.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @returns {Promise<{entry?: object, player?: string | null, refusal?: {status: number, body: object}}>} The world and the player's id, null for a key that is no player key, or why there is no world.
   */
  async worldAndPlayer(id, key) {
    const entry = WORLD_ID.test(id) ? await this.store.get(id) : undefined;

    if (!entry) {
      return { refusal: notFound() };
    }

    const player = typeof key === "string" && PLAYER_KEY.test(key) ? await playerIdOf(key) : null;
    return { entry, player };
  }

  /**
   * Checks a new world's fields.
   *
   * @param {any} request The new world.
   * @returns {string | null} What is wrong with it, or null.
   */
  checkNewWorld(request) {
    const lock = request?.lock;

    if (!request || typeof request !== "object") return "the world must be a JSON object";
    if (typeof request.id !== "string" || !WORLD_ID.test(request.id)) return "the id must be 32 lowercase hexadecimal characters";
    if (!cleanName(request.name, this.limits)) return "the world needs a name";
    if (!Number.isInteger(request.seats) || request.seats < WORLD_SEATS.min || request.seats > WORLD_SEATS.max) return `the seats must be ${WORLD_SEATS.min} to ${WORLD_SEATS.max}`;
    if (typeof request.player !== "string" || !PLAYER_KEY.test(request.player)) return "the creator's player key is missing";
    if (!cleanName(request.playerName, this.limits)) return "the creator needs a name";
    if (typeof request.authHash !== "string" || !HEX_32.test(request.authHash)) return "the auth hash must be 64 lowercase hexadecimal characters";
    if (!lock || typeof lock.salt !== "string" || !SALT.test(lock.salt)) return "the lock needs a salt of 32 lowercase hexadecimal characters";
    if (!Number.isInteger(lock.iterations) || lock.iterations < this.limits.minIterations || lock.iterations > this.limits.maxIterations) return "the lock's iterations are out of range";
    if (typeof lock.box !== "string" || !HEX.test(lock.box) || lock.box.length > this.limits.maxLockHex) return "the lock's box must be lowercase hexadecimal";
    if (request.start !== undefined && typeof request.start !== "boolean") return "start must be true or false";
    if (request.hidden !== undefined && typeof request.hidden !== "boolean") return "hidden must be true or false";
    if (request.choose !== undefined && typeof request.choose !== "boolean") return "choose must be true or false";
    if (request.open !== undefined && typeof request.open !== "boolean") return "open must be true or false";
    if (request.featured !== undefined && typeof request.featured !== "boolean") return "featured must be true or false";
    return null;
  }
}

/**
 * Answers a request to the directory's public routes.
 *
 * @param {Directory} directory The directory.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @param {() => Promise<string>} readBody Reads the request's body as text.
 * @param {(limit: number) => Promise<Uint8Array | null>} readBytes Reads the request's body as bytes, null when it is longer than the limit.
 * @returns {Promise<{status: number, body: object, bytes?: Uint8Array, close?: boolean, kick?: string, id?: string}>} The answer, sent as the bytes when there are any, and what the platform layer must do beyond it for the world with that id.
 */
export async function handleDirectoryRequest(directory, method, url, readBody, readBytes) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);

  if (parts[0] !== "v1" || parts[1] !== "worlds") {
    return notFound();
  }

  if (parts.length === 2 && method === "GET") {
    return directory.list(url.searchParams.get("player"));
  }

  if (parts.length === 2 && method === "POST") {
    return directory.create(await readJson(readBody));
  }

  if (parts.length === 4 && parts[3] === "lock" && method === "GET") {
    return directory.lock(parts[2]);
  }

  if (parts.length === 4 && parts[3] === "delete" && method === "POST") {
    const body = await readJson(readBody);
    return { ...(await directory.remove(parts[2], body?.player)), id: parts[2] };
  }

  if (parts.length === 4 && parts[3] === "ban" && method === "POST") {
    const body = await readJson(readBody);
    return { ...(await directory.ban(parts[2], body?.player, body?.target)), id: parts[2] };
  }

  if (parts.length === 4 && parts[3] === "start" && method === "POST") {
    return directory.putStart(parts[2], url.searchParams.get("player"), await readBytes(directory.limits.maxStartBytes));
  }

  if (parts.length === 4 && parts[3] === "start" && method === "GET") {
    return directory.getStart(parts[2], url.searchParams.get("player"), url.searchParams.get("auth"));
  }

  return { status: 405, body: { error: "not a directory route" } };
}

/**
 * Reads a JSON body, small ones only.
 *
 * @param {() => Promise<string>} readBody Reads the request's body.
 * @returns {Promise<any>} The parsed body, or null when it is no JSON or too large.
 */
async function readJson(readBody) {
  try {
    const text = await readBody();
    return text.length <= 8192 ? JSON.parse(text) : null;
  } catch {
    return null;
  }
}

/**
 * Makes the view of a world everyone may see: no hashes, no lock, and players by id, name and when they were last seen.
 *
 * @param {object} entry The world entry.
 * @returns {object} The view.
 */
export function publicView(entry) {
  const members = Object.entries(entry.members).map(([id, member]) => ({ id, name: member.name, online: entry.online.includes(id), seen: member.seen }));

  return {
    id: entry.id,
    name: entry.name,
    seats: entry.seats,
    creator: entry.creator,
    start: entry.start ?? START.none,
    hidden: entry.hidden === true,
    choose: entry.choose === true,
    open: entry.open === true,
    featured: entry.featured === true,
    online: entry.online.length,
    created: entry.created,
    active: entry.active,
    members,
  };
}

/**
 * The answer for a world that does not exist.
 *
 * @returns {{status: number, body: object}} The answer.
 */
function notFound() {
  return { status: 404, body: { error: "there is no such world" } };
}

/**
 * The answer for a request that is not as it should be.
 *
 * @param {string} reason Why.
 * @returns {{status: number, body: object}} The answer.
 */
function badRequest(reason) {
  return { status: 400, body: { error: reason } };
}
