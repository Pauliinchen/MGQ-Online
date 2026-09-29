//----------------------------------------------------------------
//  directory.js
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

// The world directory's rules, the same on every server: the list of worlds everyone sees, who may
// make, enter, delete or leave out whom, and who was in which world. The relay never learns a
// world's token or password: it keeps the token locked with the password, and checks entering
// against a hash of a key only the token's holders can make.
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
});

/**
 * A world id: 32 lowercase hexadecimal characters, the world room's id.
 */
const WORLD_ID = /^[0-9a-f]{32}$/;

/**
 * A player's key: 32 lowercase hexadecimal characters, which only the player's game knows.
 */
const PLAYER_KEY = /^[0-9a-f]{32}$/;

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
 * The world directory, over a store of world entries.
 */
export class Directory {
  /**
   * Creates the directory.
   *
   * @param {{get(id: string): Promise<object | undefined>, put(entry: object): Promise<void>, remove(id: string): Promise<void>, all(): Promise<object[]>}} store Where the worlds are kept.
   * @param {{clock?: () => number, limits?: typeof DIRECTORY_LIMITS}} [options] The clock and limits, which tests change.
   */
  constructor(store, { clock = Date.now, limits = DIRECTORY_LIMITS } = {}) {
    this.store = store;
    this.clock = clock;
    this.limits = limits;
  }

  /**
   * Lists every world as everyone sees it.
   *
   * @returns {Promise<{status: number, body: object}>} The worlds.
   */
  async list() {
    const worlds = (await this.store.all()).map((entry) => publicView(entry));
    return { status: 200, body: { worlds } };
  }

  /**
   * Hands out a world's locked token, which only its password opens.
   *
   * @param {string} id The world.
   * @returns {Promise<{status: number, body: object}>} The lock, or why there is none.
   */
  async lock(id) {
    const entry = WORLD_ID.test(id) ? await this.store.get(id) : undefined;
    return entry ? { status: 200, body: entry.lock } : notFound();
  }

  /**
   * Makes a world.
   *
   * @param {object} request The world: id, name, seats, the creator's player key and name, the hash of the auth key, and the lock.
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
    const worlds = await this.store.all();

    if (worlds.length >= this.limits.maxWorlds) {
      return { status: 503, body: { error: "the directory is full" } };
    }

    if (worlds.filter((entry) => entry.creator.id === creator).length >= this.limits.maxWorldsPerCreator) {
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
      created: now,
      active: now,
      members: { [creator]: { name: creatorName, seen: now } },
      online: [],
      bans: [],
    });

    return { status: 201, body: { id: request.id } };
  }

  /**
   * Deletes a world for everyone, if the creator asks.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @returns {Promise<{status: number, body: object, close?: boolean}>} The answer, and whether the world room must close.
   */
  async remove(id, key) {
    const { entry, refusal } = await this.asCreator(id, key);

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

    if (typeof target !== "string" || !PLAYER_KEY.test(target) || target === entry.creator.id) {
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
    const entry = WORLD_ID.test(id) ? await this.store.get(id) : undefined;

    if (!entry) {
      return notFound();
    }

    if (typeof key !== "string" || !PLAYER_KEY.test(key) || typeof auth !== "string" || !HEX_32.test(auth)) {
      return badRequest("a player key and an auth key are needed");
    }

    if ((await sha256Hex(auth)) !== entry.authHash) {
      return { status: 401, body: { error: "the world's token does not match" } };
    }

    const player = await playerIdOf(key);

    if (entry.bans.includes(player)) {
      return { status: 403, body: { error: "the creator removed this player from the world" } };
    }

    if (!entry.members[player] && Object.keys(entry.members).length >= this.limits.maxMembers) {
      return { status: 403, body: { error: "the world has as many players as it may" } };
    }

    return { status: 200, body: { seats: entry.seats, player }, seats: entry.seats, player };
  }

  /**
   * Notes who is in a world's room now, as the room reports after every change.
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
   * Finds a world for its creator.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @returns {Promise<{entry?: object, refusal?: {status: number, body: object}}>} The world, or why the player may not act on it.
   */
  async asCreator(id, key) {
    const entry = WORLD_ID.test(id) ? await this.store.get(id) : undefined;

    if (!entry) {
      return { refusal: notFound() };
    }

    if (typeof key !== "string" || !PLAYER_KEY.test(key) || (await playerIdOf(key)) !== entry.creator.id) {
      return { refusal: { status: 403, body: { error: "only the world's creator may do this" } } };
    }

    return { entry };
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
    return null;
  }
}

/**
 * Answers a request to the directory's public routes.
 *
 * @param {Directory} directory The directory.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @param {() => Promise<string>} readBody Reads the request's body.
 * @returns {Promise<{status: number, body: object, close?: boolean, kick?: string, id?: string}>} The answer, and what the platform layer must do beyond it for the world with that id.
 */
export async function handleDirectoryRequest(directory, method, url, readBody) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);

  if (parts[0] !== "v1" || parts[1] !== "worlds") {
    return notFound();
  }

  if (parts.length === 2 && method === "GET") {
    return directory.list();
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
 * Makes the view of a world everyone may see: no hashes, no lock, and players by id and name.
 *
 * @param {object} entry The world entry.
 * @returns {object} The view.
 */
export function publicView(entry) {
  const members = Object.entries(entry.members).map(([id, member]) => ({ id, name: member.name, online: entry.online.includes(id) }));

  return {
    id: entry.id,
    name: entry.name,
    seats: entry.seats,
    creator: entry.creator,
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
