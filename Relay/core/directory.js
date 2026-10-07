//----------------------------------------------------------------
//  directory.js
//
//  Changelog:
//      Paulinchen  2026-10-07: Kept each world's chat, the lines its games mirror and the lines admins say, which admins read and write
//                            - Took the auth key for a starting save from the X-MGQ-Auth header too
//                            - Answered a JSON body longer than a route takes with 413, and an unknown sub-route with 404
//                            - Counted a world or a starting save against its address only once it passed every check
//                            - Kept at most 500 removed players per world
//                            - Read ids, hashes and texts by the rules of ids.js, and answered through http.js
//      Paulinchen  2026-10-06: Took the player's key from the X-MGQ-Player header too
//                            - Limited making worlds, uploading starting saves and entering world rooms per address
//                            - Kept starting saves within a total budget, and deleted worlds whose starting save did not come within 10 minutes
//                            - Refused mod settings longer than 2000 characters instead of cutting them, and took mod names of up to 100 characters with the hashes
//                            - Named why a player may not enter in a code of the refusal
//                            - Read JSON bodies of up to 32 KB
//                            - Kept up to 300 characters of the mods a world names
//                            - Let admins replace a world's mod settings too
//                            - Kept the hashes of a world's required mods outside the catalog and its mod settings, both from its creator's game
//      Paulinchen  2026-10-04: Left the mods, the game data and the rule for it out of a world's lock, which the list tells
//                            - Let a world's creator replace its game data with that of their game as it is now
//                            - Listed the hidden worlds a player names by their ids
//                            - Let a world's creator or an admin change its seats, description and mods
//                            - Kept a world's description, the mods it needs, its creator's game data and whether only games with the same data may enter
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
// featured; who may make, enter, delete or leave out whom; and who was in which world. The relay
// never learns a world's token or password: it keeps the token locked with the password, and
// checks entering against a hash of a key only the token's holders can make. A world's starting
// save reaches it encrypted with a key from the token, so the relay only keeps its bytes.
//
// It keeps its worlds through a store the platform layer passes in, and hands back what the layer
// must do beyond answering, such as closing a removed player's connection or telling a world room
// what an admin said.
//
// It also keeps each world's chat as far as the relay sees it: the games mirror every line of the
// world's chat as a text frame, which the world room hands in here, and an admin's line, said over
// HTTP, goes into the log and out to every game in the room.

import { badRequest, notFound, withJson } from "./http.js";
import { CONTROL_CHARACTERS, ID, cleanText, hexOf, isHash, isId } from "./ids.js";
import { MAX_CHAT_LENGTH, RATE_LIMITS, RateLimiter, VERSION, WORLD_SEATS } from "./relay.js";

/**
 * The limits the directory keeps.
 */
export const DIRECTORY_LIMITS = Object.freeze({
  maxNameLength: 32,
  maxDescriptionLength: 1000,
  maxModsLength: 300,
  maxModHashesLength: 2000,
  maxSettingsLength: 2000,
  maxWorlds: 2000,
  maxWorldsPerCreator: 20,
  maxMembers: 200,
  maxBans: 500,
  maxListedIds: 50,
  // Released games lock with 200 000 iterations, newer ones with more.
  minIterations: 100_000,
  maxIterations: 5_000_000,
  maxLockHex: 512,
  maxStartBytes: 8 * 1024 * 1024,
  // All starting saves together, well below what the platform's storage takes.
  maxStartBytesTotal: 1024 * 1024 * 1024,
  // How long a world waits for its starting save before it is deleted.
  pendingMs: 10 * 60 * 1000,
  maxJsonLength: 32 * 1024,
  // Lines of a world's chat kept, the oldest forgotten first, and the longest line.
  maxChatLines: 200,
  maxChatLength: MAX_CHAT_LENGTH,
});

/**
 * The name an admin's line of a world's chat carries when the request names none.
 */
export const ADMIN_NAME = "Admin";

/**
 * The codes a refusal names why with, which games tell their players apart.
 */
export const REFUSAL = Object.freeze({
  removed: "removed",
  members: "members",
  pending: "pending",
  rate: "rate",
  storage: "storage",
});

/**
 * How far a world is with its starting save: it has none, its creator is still uploading it, or it is ready.
 */
export const START = Object.freeze({ none: "none", pending: "pending", ready: "ready" });

/**
 * Lowercase hexadecimal of any length.
 */
const HEX = /^(?:[0-9a-f]{2})+$/;

/**
 * What tells one game's data from another's, as the creator's game wrote it; the relay only keeps it.
 */
const GAME_DATA = /^[0-9a-z:.]{1,160}$/;

/**
 * The hashes of a world's required mods outside the mod catalog, as the creator's game wrote them:
 * "name=hash" pairs separated by semicolons.
 */
const MOD_HASHES = /^(?:[^=;\u0000-\u001f]{1,100}=[0-9a-f]{64})(?:;[^=;\u0000-\u001f]{1,100}=[0-9a-f]{64})*$/;

/**
 * Hashes a text with SHA-256.
 *
 * @param {string} text The text.
 * @returns {Promise<string>} The hash as 64 lowercase hexadecimal characters.
 */
export async function sha256Hex(text) {
  return hexOf(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
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
  return typeof text === "string" ? text.toLowerCase().split(/[\s,]+/).filter((id) => ID.test(id)) : [];
}

/**
 * Tidies a name someone chose: on one line, without control characters, trimmed and not too long.
 *
 * @param {unknown} name The name.
 * @param {typeof DIRECTORY_LIMITS} [limits] The limits.
 * @returns {string | null} The name, or null when nothing is left of it.
 */
export function cleanName(name, limits = DIRECTORY_LIMITS) {
  const cleaned = cleanText(name, limits.maxNameLength);
  return cleaned.length > 0 ? cleaned : null;
}

/**
 * @typedef {object} DirectoryStore Where the directory keeps its worlds, one entry each, and their starting saves.
 * @property {(id: string) => Promise<object | undefined>} get Reads a world's entry.
 * @property {(entry: object) => Promise<void>} put Writes a world's entry.
 * @property {(id: string) => Promise<void>} remove Deletes a world's entry, its starting save and its chat.
 * @property {() => Promise<object[]>} all Reads every world's entry.
 * @property {(id: string, bytes: Uint8Array) => Promise<void>} putStart Writes a world's starting save.
 * @property {(id: string) => Promise<Uint8Array | undefined>} getStart Reads a world's starting save.
 * @property {(id: string, lines: object[]) => Promise<void>} putChat Writes a world's chat, every line kept.
 * @property {(id: string) => Promise<object[] | undefined>} getChat Reads a world's chat, undefined before its first line.
 */

/**
 * The world directory, over a store of world entries.
 */
export class Directory {
  /**
   * Creates the directory.
   *
   * @param {DirectoryStore} store Where the worlds and their starting saves are kept.
   * @param {{clock?: () => number, limits?: typeof DIRECTORY_LIMITS, admins?: string[], rates?: typeof RATE_LIMITS}} [options] The clock, limits and rate limits, which tests change, and the player ids of the relay's admins.
   */
  constructor(store, { clock = Date.now, limits = DIRECTORY_LIMITS, admins = [], rates = RATE_LIMITS } = {}) {
    this.store = store;
    this.clock = clock;
    this.limits = limits;
    this.admins = new Set(admins);
    this.rates = {
      creates: new RateLimiter(rates.creates, clock),
      starts: new RateLimiter(rates.starts, clock),
      joins: new RateLimiter(rates.joins, clock),
    };
  }

  /**
   * Lists the worlds a player sees: every public world, the hidden ones the player joined or
   * names by their ids, which their creators hand out, or every world for an admin.
   *
   * @param {unknown} [key] The asking player's key; without one, only the public worlds and the named ones.
   * @param {unknown} [ids] The ids of hidden worlds to list too, separated by commas.
   * @returns {Promise<{status: number, body: object}>} The worlds, and whether the player is an admin.
   */
  async list(key, ids) {
    const named = new Set(typeof ids === "string" ? ids.split(",").filter((id) => ID.test(id)).slice(0, this.limits.maxListedIds) : []);
    const player = isId(key) ? await playerIdOf(key) : null;
    const admin = this.admins.has(player);
    const worlds = (await this.entries()).filter((entry) => admin || !entry.hidden || (player && entry.members[player]) || named.has(entry.id)).map((entry) => publicView(entry));
    return { status: 200, body: { worlds, admin } };
  }

  /**
   * Hands out a world's locked token, which only its password opens, with what a player who
   * found it by its id alone needs to enter it.
   *
   * @param {string} id The world.
   * @returns {Promise<{status: number, body: object}>} The lock with the world's name, seats, starting save state, whether new players choose where to start, or why there is none.
   */
  async lock(id) {
    const entry = await this.load(id);
    return entry ? { status: 200, body: { ...entry.lock, name: entry.name, seats: entry.seats, start: entry.start ?? START.none, choose: entry.choose === true } } : noWorld();
  }

  /**
   * Makes a world.
   *
   * @param {object} request The world: id, name, seats, the creator's player key and name, the hash of the auth key, the lock, whether a starting save follows, whether it is hidden from the list, whether each new player chooses where to start, whether it has no password, whether it is featured, its description, the mods it needs, the creator's game data, whether only games with the same data may enter, the hashes of its required mods outside the catalog and its mod settings.
   * @param {string | null} [address] The asking game's address, whose worlds a rate limit counts; null for none.
   * @returns {Promise<{status: number, body: object}>} The world's id, or why it was refused.
   */
  async create(request, address = null) {
    const refusal = this.checkNewWorld(request);

    if (refusal) {
      return badRequest(refusal);
    }

    if (await this.load(request.id)) {
      return { status: 409, body: { error: "a world with this id exists" } };
    }

    // Counted only now, so a request the relay refuses anyway costs its address no turn.
    if (!this.rates.creates.take(address)) {
      return tooMany();
    }

    const creator = await playerIdOf(request.player);
    const admin = this.admins.has(creator);
    const worlds = await this.entries();

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
      description: cleanText(request.description, this.limits.maxDescriptionLength),
      mods: cleanText(request.mods, this.limits.maxModsLength),
      data: request.data ?? "",
      strict: request.strict === true,
      modHashes: request.modHashes ?? "",
      settings: cleanSettings(request.settings),
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
   * Changes what of a world may change after it was made, if the creator or an admin asks: its
   * seats, its description, the mods it needs and its mod settings. Games already in the world stay
   * when the seats become fewer. Its game data and its mods' hashes only the creator replaces,
   * whose game they come from.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @param {any} changes Whichever of `seats`, `description`, `mods`, `data`, `modHashes` and `settings` change.
   * @returns {Promise<{status: number, body: object}>} The answer.
   */
  async edit(id, key, changes) {
    const { entry, refusal } = await this.asCreatorOrAdmin(id, key);

    if (refusal) {
      return refusal;
    }

    const { seats, description, mods, data, modHashes, settings } = changes ?? {};

    if (data !== undefined && (typeof data !== "string" || !GAME_DATA.test(data))) {
      return badRequest("the game data must be 1 to 160 lowercase letters, digits, colons and dots");
    }

    if (modHashes !== undefined && !this.modHashesOk(modHashes)) {
      return badRequest("the mod hashes must be name=hash pairs separated by semicolons");
    }

    if (settings !== undefined && !this.settingsOk(settings)) {
      return badRequest(`the mod settings must be a text of at most ${this.limits.maxSettingsLength} characters`);
    }

    if ((data !== undefined || modHashes !== undefined) && (await playerIdOf(key)) !== entry.creator.id) {
      return { status: 403, body: { error: "only the world's creator may replace its game data and mod hashes" } };
    }

    if (seats !== undefined && (!Number.isInteger(seats) || seats < WORLD_SEATS.min || seats > WORLD_SEATS.max)) {
      return badRequest(`the seats must be ${WORLD_SEATS.min} to ${WORLD_SEATS.max}`);
    }

    if ((description !== undefined && typeof description !== "string") || (mods !== undefined && typeof mods !== "string")) {
      return badRequest("the description and the mods must be texts");
    }

    if (seats !== undefined) entry.seats = seats;
    if (description !== undefined) entry.description = cleanText(description, this.limits.maxDescriptionLength);
    if (mods !== undefined) entry.mods = cleanText(mods, this.limits.maxModsLength);
    if (data !== undefined) entry.data = data;
    if (modHashes !== undefined) entry.modHashes = modHashes;
    if (settings !== undefined) entry.settings = cleanSettings(settings);

    await this.store.put(entry);
    return { status: 200, body: { edited: entry.id } };
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

    if (!isId(target) || target === entry.creator.id) {
      return badRequest("the player to remove must be another player's id");
    }

    if (!entry.bans.includes(target)) {
      if (entry.bans.length >= this.limits.maxBans) {
        return { status: 429, body: { error: `a world may keep at most ${this.limits.maxBans} removed players` } };
      }

      entry.bans.push(target);
    }

    delete entry.members[target];
    entry.online = entry.online.filter((player) => player !== target);

    await this.store.put(entry);
    return { status: 200, body: { removed: target }, kick: target };
  }

  /**
   * Decides whether a game may take a seat in a world room.
   *
   * @param {string} id The world.
   * @param {unknown} key The player's key.
   * @param {unknown} auth The auth key the player's game made from the world's token.
   * @param {string | null} [address] The game's address, whose entering a rate limit counts; null for none.
   * @returns {Promise<{status: number, body: object, seats?: number, player?: string}>} The world's seats and the player's id, or why not.
   */
  async admit(id, key, auth, address = null) {
    if (!this.rates.joins.take(address)) {
      return tooMany();
    }

    const { entry, player, refusal } = await this.asPlayer(id, key, auth);

    if (refusal) {
      return refusal;
    }

    if (entry.start === START.pending) {
      return { status: 409, body: { error: "the world's starting save is still being uploaded", code: REFUSAL.pending } };
    }

    return { status: 200, body: { seats: entry.seats, player }, seats: entry.seats, player };
  }

  /**
   * Keeps a world's starting save, which its creator uploads once, right after making the world.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @param {Uint8Array | null} bytes The starting save, encrypted by the creator's game; null when it was too large to read.
   * @param {string | null} [address] The asking game's address, whose uploads a rate limit counts; null for none.
   * @returns {Promise<{status: number, body: object}>} The answer.
   */
  async putStart(id, key, bytes, address = null) {
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

    // Counted only now, so an upload the relay refuses anyway costs its address no turn.
    if (!this.rates.starts.take(address)) {
      return tooMany();
    }

    // Saves kept before their sizes were noted count as nothing.
    const used = (await this.entries()).reduce((total, world) => total + (world.startBytes ?? 0), 0);

    if (used + bytes.length > this.limits.maxStartBytesTotal) {
      return { status: 507, body: { error: "the relay has no room for more starting saves", code: REFUSAL.storage } };
    }

    await this.store.putStart(entry.id, bytes);
    entry.start = START.ready;
    entry.startBytes = bytes.length;
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
    const entry = await this.load(id);

    if (!entry) {
      return noWorld();
    }

    const now = this.clock();

    for (const player of entry.online) {
      if (entry.members[player]) {
        entry.members[player].seen = now;
      }
    }

    entry.online = [];

    for (const { player, name } of online) {
      if (entry.bans.includes(player) || entry.online.includes(player)) {
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
   * Keeps a line of a world's chat: one a game in the world room mirrored, or one an admin said.
   *
   * @param {string} id The world.
   * @param {{player: string, name: string}} who The sender's player id and name.
   * @param {unknown} text The line.
   * @param {boolean} [admin] Whether an admin said it from outside the game.
   * @returns {Promise<object | null>} The line as kept, with its number; null for a world the directory lacks or an empty line.
   */
  async say(id, who, text, admin = false) {
    const entry = await this.load(id);
    const line = cleanText(text, this.limits.maxChatLength);

    if (!entry || line.length === 0) {
      return null;
    }

    const lines = (await this.store.getChat(entry.id)) ?? [];
    const kept = { n: (lines.at(-1)?.n ?? 0) + 1, at: this.clock(), player: who.player, name: cleanName(who.name, this.limits) ?? "?", text: line, admin };

    lines.push(kept);
    await this.store.putChat(entry.id, lines.slice(-this.limits.maxChatLines));
    return kept;
  }

  /**
   * Hands out a world's chat as the relay saw it, to its creator or an admin.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @param {unknown} [after] The number of the last line the asker has; only later ones are handed out.
   * @returns {Promise<{status: number, body: object}>} The lines, oldest first, each with `n`, `at`, `player`, `name`, `text` and `admin`.
   */
  async chat(id, key, after) {
    const { entry, refusal } = await this.asCreatorOrAdmin(id, key);

    if (refusal) {
      return refusal;
    }

    const known = Number.isInteger(Number(after)) ? Number(after) : 0;
    const lines = ((await this.store.getChat(entry.id)) ?? []).filter((line) => line.n > known);
    return { status: 200, body: { lines } };
  }

  /**
   * Says a line in a world's chat as an admin, which every game in the world room is told.
   *
   * @param {string} id The world.
   * @param {unknown} key The asking player's key.
   * @param {unknown} text The line.
   * @param {unknown} [name] The name the line carries, ADMIN_NAME when left out.
   * @returns {Promise<{status: number, body: object, say?: {name: string, text: string}}>} The line as kept, and what the world room must tell every game.
   */
  async sayAsAdmin(id, key, text, name) {
    const { entry, player, refusal } = await this.worldAndPlayer(id, key);

    if (refusal) {
      return refusal;
    }

    if (!this.admins.has(player)) {
      return { status: 403, body: { error: "only an admin says something in a world's chat from outside the game" } };
    }

    if (typeof text !== "string" || cleanText(text, this.limits.maxChatLength).length === 0) {
      return badRequest(`the line must be a text of 1 to ${this.limits.maxChatLength} characters`);
    }

    const line = await this.say(entry.id, { player, name: cleanName(name, this.limits) ?? ADMIN_NAME }, text, true);
    return { status: 200, body: { line }, say: { name: line.name, text: line.text } };
  }

  /**
   * Reads a world's entry, deleting a world whose starting save did not come in time.
   *
   * @param {unknown} id The world.
   * @returns {Promise<object | undefined>} The entry, undefined when there is none.
   */
  async load(id) {
    const entry = isId(id) ? await this.store.get(id) : undefined;

    if (entry && this.stale(entry)) {
      await this.store.remove(entry.id);
      return undefined;
    }

    return entry;
  }

  /**
   * Reads every world's entry, deleting the worlds whose starting save did not come in time.
   *
   * @returns {Promise<object[]>} The entries.
   */
  async entries() {
    const kept = [];

    for (const entry of await this.store.all()) {
      if (this.stale(entry)) {
        await this.store.remove(entry.id);
      } else {
        kept.push(entry);
      }
    }

    return kept;
  }

  /**
   * Tells whether a world still waits for its starting save past the time it has, which happens
   * when its creator's game stopped between making it and uploading the save.
   *
   * @param {object} entry The world's entry.
   * @returns {boolean} Whether it does.
   */
  stale(entry) {
    return entry.start === START.pending && this.clock() - entry.created >= this.limits.pendingMs;
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
    const entry = await this.load(id);

    if (!entry) {
      return { refusal: noWorld() };
    }

    if (!isId(key) || !isHash(auth)) {
      return { refusal: badRequest("a player key and an auth key are needed") };
    }

    if ((await sha256Hex(auth)) !== entry.authHash) {
      return { refusal: { status: 401, body: { error: "the world's token does not match" } } };
    }

    const player = await playerIdOf(key);

    if (entry.bans.includes(player)) {
      return { refusal: { status: 403, body: { error: "the creator removed this player from the world", code: REFUSAL.removed } } };
    }

    if (!entry.members[player] && Object.keys(entry.members).length >= this.limits.maxMembers) {
      return { refusal: { status: 403, body: { error: "the world has as many players as it may", code: REFUSAL.members } } };
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
    const entry = await this.load(id);

    if (!entry) {
      return { refusal: noWorld() };
    }

    const player = isId(key) ? await playerIdOf(key) : null;
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
    if (!isId(request.id)) return "the id must be 32 lowercase hexadecimal characters";
    if (!cleanName(request.name, this.limits)) return "the world needs a name";
    if (!Number.isInteger(request.seats) || request.seats < WORLD_SEATS.min || request.seats > WORLD_SEATS.max) return `the seats must be ${WORLD_SEATS.min} to ${WORLD_SEATS.max}`;
    if (!isId(request.player)) return "the creator's player key is missing";
    if (!cleanName(request.playerName, this.limits)) return "the creator needs a name";
    if (!isHash(request.authHash)) return "the auth hash must be 64 lowercase hexadecimal characters";
    if (!lock || !isId(lock.salt)) return "the lock needs a salt of 32 lowercase hexadecimal characters";
    if (!Number.isInteger(lock.iterations) || lock.iterations < this.limits.minIterations || lock.iterations > this.limits.maxIterations) return "the lock's iterations are out of range";
    if (typeof lock.box !== "string" || !HEX.test(lock.box) || lock.box.length > this.limits.maxLockHex) return "the lock's box must be lowercase hexadecimal";
    if (request.start !== undefined && typeof request.start !== "boolean") return "start must be true or false";
    if (request.hidden !== undefined && typeof request.hidden !== "boolean") return "hidden must be true or false";
    if (request.choose !== undefined && typeof request.choose !== "boolean") return "choose must be true or false";
    if (request.open !== undefined && typeof request.open !== "boolean") return "open must be true or false";
    if (request.featured !== undefined && typeof request.featured !== "boolean") return "featured must be true or false";
    if (request.description !== undefined && typeof request.description !== "string") return "the description must be a text";
    if (request.mods !== undefined && typeof request.mods !== "string") return "the mods must be a text";
    if (request.data !== undefined && (typeof request.data !== "string" || !GAME_DATA.test(request.data))) return "the game data must be 1 to 160 lowercase letters, digits, colons and dots";
    if (request.strict !== undefined && typeof request.strict !== "boolean") return "strict must be true or false";
    if (request.modHashes !== undefined && !this.modHashesOk(request.modHashes)) return "the mod hashes must be name=hash pairs separated by semicolons";
    if (request.settings !== undefined && !this.settingsOk(request.settings)) return `the mod settings must be a text of at most ${this.limits.maxSettingsLength} characters`;
    return null;
  }

  /**
   * Checks the hashes of a world's required mods outside the catalog.
   *
   * @param {unknown} text The hashes, empty for none.
   * @returns {boolean} Whether they are as they should be.
   */
  modHashesOk(text) {
    return typeof text === "string" && text.length <= this.limits.maxModHashesLength && (text === "" || MOD_HASHES.test(text));
  }

  /**
   * Checks a world's mod settings, which are refused rather than cut, since a cut value reads as another value.
   *
   * @param {unknown} text The settings, empty for none.
   * @returns {boolean} Whether they are as they should be.
   */
  settingsOk(text) {
    return typeof text === "string" && [...cleanSettings(text)].length <= this.limits.maxSettingsLength;
  }
}

/**
 * Tidies a world's mod settings: without control characters, but otherwise as written, since a
 * text value may end in a space.
 *
 * @param {unknown} text The settings.
 * @returns {string} The settings, empty for none.
 */
function cleanSettings(text) {
  return typeof text === "string" ? text.replace(CONTROL_CHARACTERS, "") : "";
}

/**
 * Answers a request to the directory's public routes.
 *
 * @param {Directory} directory The directory.
 * @param {string} method The HTTP method.
 * @param {URL} url The request's address.
 * @param {() => Promise<string | null>} readBody Reads the request's body as text, null when it is too large to read.
 * @param {(limit: number) => Promise<Uint8Array | null>} readBytes Reads the request's body as bytes, null when it is longer than the limit.
 * @param {{player?: string | null, auth?: string | null, address?: string | null}} [client] The PLAYER_HEADER and AUTH_HEADER of the request, which win over the key and auth key in its body or address, and the address it came from.
 * @returns {Promise<{status: number, body: object, bytes?: Uint8Array, close?: boolean, kick?: string, id?: string}>} The answer, sent as the bytes when there are any, and what the platform layer must do beyond it for the world with that id.
 */
export async function handleDirectoryRequest(directory, method, url, readBody, readBytes, client = {}) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);
  const header = client.player || null;
  const address = client.address ?? null;
  const fromQuery = () => header ?? url.searchParams.get("player");
  const fromBody = (body) => header ?? body?.player;
  const authOf = () => client.auth || url.searchParams.get("auth");
  const json = (handle) => withJson(readBody, directory.limits.maxJsonLength, handle);

  if (parts[0] !== VERSION || parts[1] !== "worlds") {
    return notFound("route");
  }

  if (parts.length === 2 && method === "GET") {
    return directory.list(fromQuery(), url.searchParams.get("ids"));
  }

  if (parts.length === 2 && method === "POST") {
    return json((body) => directory.create(body && typeof body === "object" && header ? { ...body, player: header } : body, address));
  }

  if (parts.length === 4 && parts[3] === "lock" && method === "GET") {
    return directory.lock(parts[2]);
  }

  if (parts.length === 4 && parts[3] === "delete" && method === "POST") {
    return json(async (body) => ({ ...(await directory.remove(parts[2], fromBody(body))), id: parts[2] }));
  }

  if (parts.length === 4 && parts[3] === "edit" && method === "POST") {
    return json((body) => directory.edit(parts[2], fromBody(body), body));
  }

  if (parts.length === 4 && parts[3] === "ban" && method === "POST") {
    return json(async (body) => ({ ...(await directory.ban(parts[2], fromBody(body), body?.target)), id: parts[2] }));
  }

  if (parts.length === 4 && parts[3] === "start" && method === "POST") {
    return directory.putStart(parts[2], fromQuery(), await readBytes(directory.limits.maxStartBytes), address);
  }

  if (parts.length === 4 && parts[3] === "start" && method === "GET") {
    return directory.getStart(parts[2], fromQuery(), authOf());
  }

  if (parts.length === 4 && parts[3] === "chat" && method === "GET") {
    return directory.chat(parts[2], fromQuery(), url.searchParams.get("after"));
  }

  if (parts.length === 4 && parts[3] === "chat" && method === "POST") {
    return json(async (body) => ({ ...(await directory.sayAsAdmin(parts[2], fromBody(body), body?.text, body?.name)), id: parts[2] }));
  }

  return notFound("route");
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
    description: entry.description ?? "",
    mods: entry.mods ?? "",
    data: entry.data ?? "",
    strict: entry.strict === true,
    modHashes: entry.modHashes ?? "",
    settings: entry.settings ?? "",
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
function noWorld() {
  return notFound("world");
}

/**
 * The answer for an address that asked more often than a rate limit lets it.
 *
 * @returns {{status: number, body: object}} The answer.
 */
function tooMany() {
  return { status: 429, body: { error: "too many requests from this address, try again later", code: REFUSAL.rate } };
}
