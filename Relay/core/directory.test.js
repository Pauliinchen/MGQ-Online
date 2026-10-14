//----------------------------------------------------------------
//  directory.test.js
//
//  Changelog:
//      Paulinchen  2026-10-13: Covered whether a Classic world fights raid bosses
//                            - Covered a Raid World's squad settings
//      Paulinchen  2026-10-12: Covered the relay's own line in the chat of worlds with players online
//                            - Covered requests on one world made at once
//                            - Covered refusals of a new world costing its address no rate turn
//      Paulinchen  2026-10-10: Covered a Raid World's starting save from a game that names the dev feature
//                            - Covered the player's name member tells a world room
//                            - Covered an unchanged difficulty telling the world room nothing and the first difficulty of a world
//      Paulinchen  2026-10-09: Covered whether a world turns other mods off
//                            - Expected mods past 300 characters refused
//                            - Covered telling a world room whether a key is an admin's
//                            - Covered a Raid World's difficulty
//                            - Covered a Raid World refused with a starting save or a player's choice
//                            - Covered member's refusal during an upload with a Classic world
//                            - Covered a world room's member question refused while the starting save is uploaded
//      Paulinchen  2026-10-08: Covered telling a world room who plays its world
//                            - Covered a world's type and companion sharing and Raid Worlds kept from games that do not name them
//                            - Covered chat lines said at once and an admin's line for a world deleted meanwhile
//      Paulinchen  2026-10-07: Covered a world's chat
//                            - Covered the auth key header, the cap on removed players and rate turns taken after every check
//                            - Expected 413 for a JSON body over the limit and 404 for an unknown sub-route
//      Paulinchen  2026-10-06: Covered stale worlds, the budget for starting saves and the rate limits per address
//                            - Covered mod settings over the limit, long mod names, refusal codes and the player key header
//                            - Expected up to 300 characters of mods
//                            - Covered admins replacing a world's mod settings
//                            - Covered a world's mod hashes and mod settings
//      Paulinchen  2026-10-04: Expected the lock without the mods, the game data and the rule for it
//                            - Covered a creator replacing a world's game data
//                            - Covered hidden worlds listed for a player who names their ids
//                            - Covered changing a world's seats, description and mods
//                            - Covered a world's description, mods, game data and the same-data rule
//      Paulinchen  2026-10-02: Covered worlds whose new players choose where to start
//                            - Covered worlds without a password, featured worlds and when players were last seen
//      Paulinchen  2026-10-01: Covered the refusal of a delete by someone who is neither the creator nor an admin
//      Paulinchen  2026-09-30: Covered the relay's admins
//                            - Covered the starting save
//                            - Covered hidden worlds and the lock naming its world
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { DIRECTORY_LIMITS, Directory, MODS_RULE_TEXT, RAID_BOSSES_TEXT, RELAY_PLAYER, SQUAD_DEFAULTS, cleanName, handleDirectoryRequest, modsRuleText, parseAdmins, playerIdOf, raidBossesText, sha256Hex, squadText } from "./directory.js";
import { FEATURE, RateLimiter, parseFeatures } from "./relay.js";

/**
 * The creator's player key, as games make them.
 */
const CREATOR = "c0".repeat(16);

/**
 * Another player's key.
 */
const OTHER = "0f".repeat(16);

/**
 * An admin's player key.
 */
const ADMIN = "ad".repeat(16);

/**
 * The auth key the holders of the test world's token make.
 */
const AUTH = "ab".repeat(32);

/**
 * The test world's id.
 */
const WORLD = "0123456789abcdef0123456789abcdef";

/**
 * Makes a directory over a store in memory, with a clock the tests move.
 *
 * @param {object} [limits] The limits.
 * @param {string[]} [admins] The admins' player ids.
 * @returns {{directory: Directory, store: object, time: {now: number}}} The directory, its store and its clock.
 */
function newDirectory(limits = DIRECTORY_LIMITS, admins = []) {
  const entries = new Map();
  const starts = new Map();
  const chats = new Map();
  const time = { now: 1_000_000 };
  const store = {
    get: async (id) => (entries.has(id) ? structuredClone(entries.get(id)) : undefined),
    put: async (entry) => void entries.set(entry.id, structuredClone(entry)),
    remove: async (id) => {
      entries.delete(id);
      starts.delete(id);
      chats.delete(id);
    },
    all: async () => [...entries.values()].map((entry) => structuredClone(entry)),
    putStart: async (id, bytes) => void starts.set(id, Uint8Array.from(bytes)),
    getStart: async (id) => starts.get(id),
    putChat: async (id, lines) => void chats.set(id, structuredClone(lines)),
    getChat: async (id) => (chats.has(id) ? structuredClone(chats.get(id)) : undefined),
  };

  return { directory: new Directory(store, { clock: () => time.now, limits, admins }), store, time, starts, chats };
}

/**
 * Describes a new world as a game sends it.
 *
 * @param {object} [changes] Fields to change.
 * @returns {Promise<object>} The request.
 */
async function newWorld(changes = {}) {
  return {
    id: WORLD,
    name: "Iliasburg Crew",
    seats: 4,
    player: CREATOR,
    playerName: "Creator",
    authHash: await sha256Hex(AUTH),
    lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(60) },
    ...changes,
  };
}

test("cleanName keeps a name on one line, trimmed and short", () => {
  assert.equal(cleanName("  Luka\tthe\nHero  "), "LukatheHero");
  assert.equal(cleanName(" Alice "), "Alice");
  assert.equal(cleanName("x".repeat(40)).length, DIRECTORY_LIMITS.maxNameLength);
  assert.equal(cleanName(" \n "), null);
  assert.equal(cleanName(42), null);
});

test("a made world is listed without its hashes or lock, with the creator as its first player", async () => {
  const { directory } = newDirectory();

  assert.equal((await directory.create(await newWorld())).status, 201);

  const { body } = await directory.list();
  const creator = await playerIdOf(CREATOR);
  assert.deepEqual(body.worlds.map(({ id, name, seats, online }) => ({ id, name, seats, online })), [{ id: WORLD, name: "Iliasburg Crew", seats: 4, online: 0 }]);
  assert.deepEqual(body.worlds[0].creator, { id: creator, name: "Creator" });
  assert.deepEqual(body.worlds[0].members, [{ id: creator, name: "Creator", online: false, seen: 1_000_000 }]);
  assert.equal(body.worlds[0].start, "none");
  assert.equal(body.worlds[0].hidden, false);
  assert.equal(body.worlds[0].choose, false);
  assert.equal(body.worlds[0].open, false);
  assert.equal(body.worlds[0].featured, false);
  assert.equal(body.worlds[0].type, "classic");
  assert.equal(body.worlds[0].share, "off");
  assert.equal(body.worlds[0].otherModsOff, false);
  assert.equal(JSON.stringify(body).includes("authHash"), false);
  assert.equal(JSON.stringify(body).includes("box"), false);
  assert.notEqual(creator, CREATOR);
});

test("a world is refused twice, with bad fields, or beyond a creator's limit", async () => {
  const { directory } = newDirectory({ ...DIRECTORY_LIMITS, maxWorldsPerCreator: 1 });

  await directory.create(await newWorld());
  assert.equal((await directory.create(await newWorld())).status, 409);
  assert.equal((await directory.create(await newWorld({ id: "1".repeat(32) }))).status, 429);

  for (const bad of [{ start: "yes" }, { hidden: 1 }, { choose: "no" }, { open: "yes" }, { featured: 1 }, { description: 5 }, { mods: [] }, { data: "A B" }, { data: "x".repeat(161) }, { strict: "yes" }, { type: "duel" }, { type: true }, { share: "some" }, { share: 1 }, { otherModsOff: "yes" }, { otherModsOff: 1 }, { otherModsOff: null }, { mods: "x".repeat(301) }, { seats: 1 }, { seats: 33 }, { name: " " }, { id: "xyz" }, { player: "short" }, { authHash: "00" }, { lock: { salt: "12", iterations: 200_000, box: "ab" } }, { lock: { salt: "12".repeat(16), iterations: 10, box: "ab" } }]) {
    assert.equal((await directory.create(await newWorld({ id: "2".repeat(32), player: OTHER, ...bad }))).status, 400, JSON.stringify(bad));
  }
});

test("the lock is handed out to anyone, since only the password opens it", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());

  assert.deepEqual((await directory.lock(WORLD)).body, { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(60), name: "Iliasburg Crew", seats: 4, start: "none", choose: false });
  assert.equal((await directory.lock("f".repeat(32))).status, 404);
});

test("a world whose new players choose where to start says so in the list and the lock", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ start: true, choose: true }));

  assert.equal((await directory.list()).body.worlds[0].choose, true);
  assert.equal((await directory.lock(WORLD)).body.choose, true);
  assert.equal((await directory.lock(WORLD)).body.start, "pending");
});

test("a world tells what its creator wrote about it and which games may enter", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ description: "  A slow run\tthrough part one.  ", mods: ` ${"x".repeat(300)}\t `, data: "1:0a1b2c3d.ffffffff", strict: true }));

  const world = (await directory.list()).body.worlds[0];
  assert.equal(world.description, "A slow runthrough part one.");
  assert.equal(world.mods, "x".repeat(300), "300 characters are kept once tidied");
  assert.equal(world.data, "1:0a1b2c3d.ffffffff");
  assert.equal(world.strict, true);
});

test("a world made without them has no description, mods or game data, and takes every game", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());

  const world = (await directory.list()).body.worlds[0];
  assert.deepEqual([world.description, world.mods, world.data, world.strict], ["", "", "", false]);
});

test("only the creator replaces a world's game data, with data that reads as such", async () => {
  const { directory } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld({ data: "1:0a1b2c3d", strict: true }));

  assert.equal((await directory.edit(WORLD, ADMIN, { data: "1:ffffffff" })).status, 403);
  assert.equal((await directory.edit(WORLD, CREATOR, { data: "Not Data" })).status, 400);
  assert.equal((await directory.list()).body.worlds[0].data, "1:0a1b2c3d");

  assert.equal((await directory.edit(WORLD, CREATOR, { data: "1:ffffffff" })).status, 200);
  const world = (await directory.list()).body.worlds[0];
  assert.deepEqual([world.data, world.strict, world.seats], ["1:ffffffff", true, 4]);
});

test("a world keeps its creator's hashes of mods outside the catalog and its mod settings", async () => {
  const hashes = `Some Mod=${"a1".repeat(32)};Other=${"b2".repeat(32)}`;
  const { directory } = newDirectory();

  assert.equal((await directory.create(await newWorld({ modHashes: "Some Mod=notahash" }))).status, 400);
  assert.equal((await directory.create(await newWorld({ modHashes: hashes, settings: "mod_level_cap=i:1;\tmod_x=b:true" }))).status, 201);

  const world = (await directory.list()).body.worlds[0];
  assert.deepEqual([world.modHashes, world.settings], [hashes, "mod_level_cap=i:1;mod_x=b:true"]);
});

test("only the creator replaces a world's mod hashes, and the creator or an admin its mod settings", async () => {
  const { directory } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld());

  assert.equal((await directory.edit(WORLD, ADMIN, { modHashes: "" })).status, 403);
  assert.equal((await directory.edit(WORLD, CREATOR, { modHashes: "x".repeat(10) })).status, 400);
  assert.equal((await directory.edit(WORLD, CREATOR, { modHashes: `Mod=${"c3".repeat(32)}`, settings: "a=i:2" })).status, 200);

  const world = (await directory.list()).body.worlds[0];
  assert.deepEqual([world.modHashes, world.settings], [`Mod=${"c3".repeat(32)}`, "a=i:2"]);
  assert.equal((await directory.edit(WORLD, ADMIN, { seats: 6 })).status, 200);
  assert.equal((await directory.edit(WORLD, ADMIN, { settings: "a=i:3" })).status, 200);
  assert.equal((await directory.list()).body.worlds[0].settings, "a=i:3");
});

test("a hidden world is listed for whoever names its id, among other ids or none that exist", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ hidden: true }));

  assert.deepEqual((await directory.list(OTHER)).body.worlds, []);
  assert.deepEqual((await directory.list(OTHER, `${"f".repeat(32)},${WORLD},not-an-id`)).body.worlds.map((world) => world.id), [WORLD]);
  assert.deepEqual((await directory.list(undefined, WORLD)).body.worlds.map((world) => world.id), [WORLD]);
  assert.deepEqual((await directory.list(OTHER, "f".repeat(32))).body.worlds, []);
  assert.deepEqual((await directory.list(OTHER, 5)).body.worlds, []);
});

test("the creator or an admin changes a world's seats, description and mods, and nothing else", async () => {
  const { directory } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld({ description: "Old", mods: "Old Mod", data: "1:0a1b2c3d", strict: true }));

  assert.equal((await directory.edit(WORLD, OTHER, { seats: 8 })).status, 403);
  assert.equal((await directory.edit(WORLD, CREATOR, { seats: 1 })).status, 400);
  assert.equal((await directory.edit(WORLD, CREATOR, { description: 5 })).status, 400);
  assert.equal((await directory.edit("f".repeat(32), CREATOR, { seats: 8 })).status, 404);

  assert.deepEqual(await directory.edit(WORLD, CREATOR, { seats: 8, description: "  New\ttext  ", strict: false, name: "Other" }), { status: 200, body: { edited: WORLD } });
  let world = (await directory.list()).body.worlds[0];
  assert.deepEqual([world.seats, world.description, world.mods, world.strict, world.name, world.data], [8, "Newtext", "Old Mod", true, "Iliasburg Crew", "1:0a1b2c3d"]);
  assert.equal((await directory.admit(WORLD, CREATOR, AUTH)).seats, 8);

  assert.equal((await directory.edit(WORLD, ADMIN, { mods: "" })).status, 200);
  world = (await directory.list()).body.worlds[0];
  assert.deepEqual([world.seats, world.description, world.mods], [8, "Newtext", ""]);
});

test("a hidden world is listed only for its players, and found by its id", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ hidden: true }));

  assert.deepEqual((await directory.list()).body.worlds, []);
  assert.deepEqual((await directory.list(OTHER)).body.worlds, []);
  assert.deepEqual((await directory.list("nope")).body.worlds, []);
  assert.equal((await directory.list(CREATOR)).body.worlds[0].hidden, true);
  assert.equal((await directory.lock(WORLD)).body.name, "Iliasburg Crew");

  await directory.presence(WORLD, [{ player: await playerIdOf(OTHER), name: "Guest" }]);
  assert.equal((await directory.list(OTHER)).body.worlds.length, 1);

  await directory.ban(WORLD, CREATOR, await playerIdOf(OTHER));
  assert.deepEqual((await directory.list(OTHER)).body.worlds, []);
});

test("parseAdmins reads player ids separated by commas or white space, and nothing else", () => {
  const id = "ad".repeat(16);

  assert.deepEqual(parseAdmins(` ${id.toUpperCase()},\n${"0f".repeat(16)} nope `), [id, "0f".repeat(16)]);
  assert.deepEqual(parseAdmins(""), []);
  assert.deepEqual(parseAdmins(undefined), []);
});

test("an admin sees every world, hidden ones too, and deletes any, but removes nobody", async () => {
  const { directory } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld({ hidden: true }));

  const listed = (await directory.list(ADMIN)).body;
  assert.equal(listed.admin, true);
  assert.deepEqual(listed.worlds.map((world) => world.id), [WORLD]);
  assert.equal((await directory.list(CREATOR)).body.admin, false);
  assert.equal((await directory.list()).body.admin, false);

  assert.equal((await directory.ban(WORLD, ADMIN, await playerIdOf(CREATOR))).status, 403);
  assert.equal((await directory.putStart(WORLD, ADMIN, Uint8Array.of(1))).status, 403);
  assert.deepEqual(await directory.remove(WORLD, OTHER), { status: 403, body: { error: "only the world's creator or an admin may do this" } });

  const deleted = await directory.remove(WORLD, ADMIN);
  assert.equal(deleted.status, 200);
  assert.equal(deleted.close, true);
  assert.deepEqual((await directory.list(ADMIN)).body.worlds, []);
});

test("admit lets in whoever brings the auth key, and names their player id and the seats", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());

  const admitted = await directory.admit(WORLD, OTHER, AUTH);
  assert.equal(admitted.status, 200);
  assert.equal(admitted.seats, 4);
  assert.equal(admitted.player, await playerIdOf(OTHER));

  assert.equal((await directory.admit(WORLD, OTHER, "cd".repeat(32))).status, 401);
  assert.equal((await directory.admit(WORLD, "nope", AUTH)).status, 400);
  assert.equal((await directory.admit("f".repeat(32), OTHER, AUTH)).status, 404);
});

test("presence marks who is online, adds newcomers as players and notes activity", async () => {
  const { directory, time } = newDirectory();
  await directory.create(await newWorld());
  const other = await playerIdOf(OTHER);

  time.now += 5000;
  await directory.presence(WORLD, [{ player: other, name: "Guest" }]);

  let world = (await directory.list()).body.worlds[0];
  assert.equal(world.online, 1);
  assert.equal(world.active, time.now);
  assert.deepEqual(world.members.find((member) => member.id === other), { id: other, name: "Guest", online: true, seen: time.now });

  time.now += 7000;
  await directory.presence(WORLD, []);
  world = (await directory.list()).body.worlds[0];
  assert.equal(world.online, 0);
  assert.equal(world.members.length, 2);
  assert.equal(world.members.find((member) => member.id === other).seen, time.now, "a player who left was last seen as they left");
});

test("a world without a password says so in the list", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ open: true }));

  assert.equal((await directory.list()).body.worlds[0].open, true);
});

test("only an admin makes featured worlds, beyond the limit of worlds per creator", async () => {
  const { directory } = newDirectory({ ...DIRECTORY_LIMITS, maxWorldsPerCreator: 1 }, [await playerIdOf(ADMIN)]);

  assert.deepEqual(await directory.create(await newWorld({ featured: true })), { status: 403, body: { error: "only the relay's admins may make featured worlds" } });
  assert.equal((await directory.create(await newWorld({ player: ADMIN, featured: true }))).status, 201);
  assert.equal((await directory.create(await newWorld({ id: "1".repeat(32), player: ADMIN, featured: true }))).status, 201);
  assert.deepEqual((await directory.list()).body.worlds.map((world) => world.featured), [true, true]);
});

test("only the creator deletes a world or removes a player, who is then kept out", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());
  const other = await playerIdOf(OTHER);
  await directory.presence(WORLD, [{ player: other, name: "Guest" }]);

  assert.equal((await directory.ban(WORLD, OTHER, other)).status, 403);
  assert.equal((await directory.ban(WORLD, CREATOR, await playerIdOf(CREATOR))).status, 400);

  const removed = await directory.ban(WORLD, CREATOR, other);
  assert.equal(removed.status, 200);
  assert.equal(removed.kick, other);
  assert.equal((await directory.admit(WORLD, OTHER, AUTH)).status, 403);
  assert.deepEqual((await directory.list()).body.worlds[0].members.map((member) => member.id), [await playerIdOf(CREATOR)]);

  await directory.presence(WORLD, [{ player: other, name: "Guest" }]);
  assert.equal((await directory.list()).body.worlds[0].online, 0);

  assert.equal((await directory.remove(WORLD, OTHER)).status, 403);
  const deleted = await directory.remove(WORLD, CREATOR);
  assert.equal(deleted.status, 200);
  assert.equal(deleted.close, true);
  assert.deepEqual((await directory.list()).body.worlds, []);
});

test("a world with a starting save lets nobody in until its creator uploaded it, once", async () => {
  const { directory } = newDirectory({ ...DIRECTORY_LIMITS, maxStartBytes: 4 });
  const save = Uint8Array.of(1, 2, 3);
  await directory.create(await newWorld({ start: true }));

  assert.equal((await directory.list()).body.worlds[0].start, "pending");
  assert.equal((await directory.admit(WORLD, OTHER, AUTH)).status, 409);
  assert.equal((await directory.getStart(WORLD, OTHER, AUTH)).status, 404);

  assert.equal((await directory.putStart(WORLD, OTHER, save)).status, 403);
  assert.equal((await directory.putStart(WORLD, CREATOR, Uint8Array.of(1, 2, 3, 4, 5))).status, 413);
  assert.equal((await directory.putStart(WORLD, CREATOR, null)).status, 413);
  assert.equal((await directory.putStart(WORLD, CREATOR, save)).status, 200);
  assert.equal((await directory.putStart(WORLD, CREATOR, save)).status, 409);

  assert.equal((await directory.list()).body.worlds[0].start, "ready");
  assert.equal((await directory.admit(WORLD, OTHER, AUTH)).status, 200);
  assert.deepEqual((await directory.getStart(WORLD, OTHER, AUTH)).bytes, save);
});

test("only the world's players fetch its starting save, and it goes with the world", async () => {
  const { directory, starts } = newDirectory();
  await directory.create(await newWorld({ start: true }));
  await directory.putStart(WORLD, CREATOR, Uint8Array.of(7));

  assert.equal((await directory.getStart(WORLD, OTHER, "cd".repeat(32))).status, 401);
  await directory.ban(WORLD, CREATOR, await playerIdOf(OTHER));
  assert.equal((await directory.getStart(WORLD, OTHER, AUTH)).status, 403);

  await directory.remove(WORLD, CREATOR);
  assert.equal(starts.size, 0);
});

test("a world without a starting save takes none", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());

  assert.equal((await directory.putStart(WORLD, CREATOR, Uint8Array.of(1))).status, 409);
  assert.equal((await directory.getStart(WORLD, CREATOR, AUTH)).status, 404);
});

test("a world's chat keeps the lines its games mirror and the lines admins say, which its creator and the admins read", async () => {
  const { directory, time, chats } = newDirectory({ ...DIRECTORY_LIMITS, maxChatLines: 3 }, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld());
  const other = await playerIdOf(OTHER);

  assert.equal(await directory.say("f".repeat(32), { player: other, name: "Guest" }, "hello"), null, "no world, no line");
  assert.equal(await directory.say(WORLD, { player: other, name: "Guest" }, " \u0001 "), null, "an empty line is not kept");
  assert.deepEqual(await directory.say(WORLD, { player: other, name: "Guest" }, "  hello\tall "), { n: 1, at: time.now, player: other, name: "Guest", text: "helloall", admin: false });

  time.now += 1000;
  const said = await directory.sayAsAdmin(WORLD, ADMIN, "welcome", "Global");
  assert.equal(said.status, 200);
  assert.deepEqual(said.say, { name: "Global", text: "welcome" }, "the world room is told what to pass on");
  assert.deepEqual(said.body.line, { n: 2, at: time.now, player: await playerIdOf(ADMIN), name: "Global", text: "welcome", admin: true });
  assert.equal((await directory.sayAsAdmin(WORLD, ADMIN, "nameless")).body.line.name, "Admin", "an admin without a name is called Admin");
  assert.equal((await directory.sayAsAdmin(WORLD, CREATOR, "hi")).status, 403, "the creator talks through the game");
  assert.equal((await directory.sayAsAdmin(WORLD, ADMIN, "")).status, 400);
  assert.equal((await directory.sayAsAdmin(WORLD, ADMIN, 7)).status, 400);
  assert.equal((await directory.sayAsAdmin("f".repeat(32), ADMIN, "hi")).status, 404);

  assert.equal((await directory.chat(WORLD, OTHER)).status, 403, "a player reads the chat in the game");
  assert.deepEqual((await directory.chat(WORLD, CREATOR)).body.lines.map((line) => line.n), [1, 2, 3]);
  assert.deepEqual((await directory.chat(WORLD, ADMIN, "2")).body.lines.map((line) => line.text), ["nameless"], "only the lines after the one the asker has");
  assert.deepEqual((await directory.chat(WORLD, ADMIN, "junk")).body.lines.length, 3);

  await directory.say(WORLD, { player: other, name: "Guest" }, "x".repeat(500));
  const lines = (await directory.chat(WORLD, ADMIN)).body.lines;
  assert.deepEqual(lines.map((line) => line.n), [2, 3, 4], "the oldest line goes once the chat is full");
  assert.equal(lines.at(-1).text.length, DIRECTORY_LIMITS.maxChatLength, "a long line is cut");

  await directory.remove(WORLD, CREATOR);
  assert.equal(chats.has(WORLD), false, "the chat goes with the world");
});

test("lines of a world's chat said at once are all kept, one after another", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());
  const other = await playerIdOf(OTHER);

  const said = await Promise.all(Array.from({ length: 5 }, (_, index) => directory.say(WORLD, { player: other, name: "Guest" }, `line ${index}`)));

  assert.deepEqual(said.map((line) => line.n), [1, 2, 3, 4, 5]);
  assert.deepEqual((await directory.chat(WORLD, CREATOR)).body.lines.map((line) => line.text), ["line 0", "line 1", "line 2", "line 3", "line 4"]);
});

test("an admin's line for a world deleted while it waited is answered with 404", async () => {
  const { directory } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld());
  directory.say = async () => null;

  assert.equal((await directory.sayAsAdmin(WORLD, ADMIN, "hi")).status, 404);
});

test("handleDirectoryRequest routes the public requests and names the world an effect is for", async () => {
  const { directory } = newDirectory();
  const body = (value) => async () => JSON.stringify(value);
  const bytes = (value) => async (limit) => (value.length > limit ? null : value);
  const url = (path) => new URL(`https://relay.test${path}`);

  assert.equal((await handleDirectoryRequest(directory, "POST", url("/v1/worlds"), body(await newWorld({ start: true, hidden: true })))).status, 201);
  assert.equal((await handleDirectoryRequest(directory, "GET", url("/v1/worlds"), body(null))).body.worlds.length, 0);
  assert.equal((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds?player=${CREATOR}`), body(null))).body.worlds.length, 1);
  assert.equal((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/lock`), body(null))).status, 200);
  assert.equal((await handleDirectoryRequest(directory, "POST", url("/v1/worlds"), async () => "not json")).status, 400);
  assert.equal((await handleDirectoryRequest(directory, "PUT", url("/v1/worlds"), body(null))).status, 404);
  assert.equal((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/elsewhere`), body(null))).status, 404);

  assert.equal((await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/start?player=${CREATOR}`), body(null), bytes(Uint8Array.of(9, 8)))).status, 200);
  assert.deepEqual((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/start?player=${OTHER}&auth=${AUTH}`), body(null))).bytes, Uint8Array.of(9, 8));

  assert.equal((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/chat?player=${CREATOR}`), body(null))).body.lines.length, 0);
  assert.equal((await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/chat`), body({ player: CREATOR, text: "hi" }))).status, 403);

  const deleted = await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/delete`), body({ player: CREATOR }));
  assert.equal(deleted.status, 200);
  assert.equal(deleted.id, WORLD);
  assert.equal(deleted.close, true);
});

test("handleDirectoryRequest routes an admin's chat line and names the world it is for", async () => {
  const { directory } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  const url = (path) => new URL(`https://relay.test${path}`);
  await directory.create(await newWorld());

  const said = await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/chat`), async () => JSON.stringify({ text: "hi all", name: "Global" }), null, { player: ADMIN });
  assert.equal(said.status, 200);
  assert.deepEqual([said.id, said.say], [WORLD, { name: "Global", text: "hi all" }]);
  assert.deepEqual((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/chat?after=0`), async () => null, null, { player: ADMIN })).body.lines.map((line) => line.text), ["hi all"]);
});

test("announce says the relay's line in the chat of every world with players online, and in no other", async () => {
  const { directory } = newDirectory();
  const quiet = "1".repeat(32);
  await directory.create(await newWorld());
  await directory.create(await newWorld({ id: quiet }));
  await directory.presence(WORLD, [{ player: await playerIdOf(CREATOR), name: "Creator" }]);

  const said = await directory.announce("MGQ Online", "MGQ Online 0.6.5 is out.");
  assert.deepEqual(said, [{ id: WORLD, name: "MGQ Online", text: "MGQ Online 0.6.5 is out." }]);
  const [line] = await directory.store.getChat(WORLD);
  assert.deepEqual([line.player, line.name, line.text, line.admin], [RELAY_PLAYER, "MGQ Online", "MGQ Online 0.6.5 is out.", true]);
  assert.equal(await directory.store.getChat(quiet), undefined);
});

test("a world whose starting save did not come in time is deleted, and no longer counts for its creator", async () => {
  const { directory, time } = newDirectory({ ...DIRECTORY_LIMITS, maxWorldsPerCreator: 1 });
  await directory.create(await newWorld({ start: true }));

  time.now += DIRECTORY_LIMITS.pendingMs - 1;
  assert.equal((await directory.lock(WORLD)).status, 200);

  time.now += 1;
  assert.deepEqual((await directory.list(CREATOR)).body.worlds, []);
  assert.equal((await directory.lock(WORLD)).status, 404);
  assert.equal((await directory.create(await newWorld({ id: "1".repeat(32) }))).status, 201);
});

test("a ready starting save keeps its world, however long ago it was made", async () => {
  const { directory, time } = newDirectory();
  await directory.create(await newWorld({ start: true }));
  await directory.putStart(WORLD, CREATOR, Uint8Array.of(1));

  time.now += DIRECTORY_LIMITS.pendingMs * 10;
  assert.equal((await directory.lock(WORLD)).status, 200);
});

test("starting saves are kept within a budget for all of them together", async () => {
  const { directory } = newDirectory({ ...DIRECTORY_LIMITS, maxStartBytesTotal: 5 });
  await directory.create(await newWorld({ start: true }));
  await directory.create(await newWorld({ id: "1".repeat(32), start: true }));

  assert.equal((await directory.putStart(WORLD, CREATOR, Uint8Array.of(1, 2, 3))).status, 200);
  assert.deepEqual(await directory.putStart("1".repeat(32), CREATOR, Uint8Array.of(1, 2, 3)), { status: 507, body: { error: "the relay has no room for more starting saves", code: "storage" } });
  assert.equal((await directory.putStart("1".repeat(32), CREATOR, Uint8Array.of(1, 2))).status, 200);
});

test("mod settings over the limit are refused rather than cut, and mod names of up to 100 characters come with their hashes", async () => {
  const { directory } = newDirectory();
  const settings = `a=s:${"x".repeat(DIRECTORY_LIMITS.maxSettingsLength - 4)}`;

  assert.equal((await directory.create(await newWorld({ settings: `${settings}y` }))).status, 400);
  assert.equal((await directory.create(await newWorld({ settings: `${settings} ` }))).status, 400);
  assert.equal((await directory.create(await newWorld({ modHashes: `${"n".repeat(101)}=${"a1".repeat(32)}` }))).status, 400);
  assert.equal((await directory.create(await newWorld({ settings: "a=s:ends in a space ", modHashes: `${"n".repeat(100)}=${"a1".repeat(32)}` }))).status, 201);
  assert.equal((await directory.list()).body.worlds[0].settings, "a=s:ends in a space ");

  assert.equal((await directory.edit(WORLD, CREATOR, { settings: `${settings}y` })).status, 400);
  assert.equal((await directory.edit(WORLD, CREATOR, { settings })).status, 200);
  assert.equal((await directory.list()).body.worlds[0].settings, settings);
});

test("making worlds, uploading starting saves and entering world rooms are limited per address", async () => {
  const entries = new Map();
  const store = {
    get: async (id) => structuredClone(entries.get(id)),
    put: async (entry) => void entries.set(entry.id, structuredClone(entry)),
    remove: async (id) => void entries.delete(id),
    all: async () => [...entries.values()].map((entry) => structuredClone(entry)),
    putStart: async () => {},
    getStart: async () => undefined,
  };
  const time = { now: 1_000_000 };
  const once = { burst: 1, refillMs: 60_000 };
  const directory = new Directory(store, { clock: () => time.now, rates: { creates: once, starts: once, joins: once } });

  assert.equal((await directory.create(await newWorld({ start: true }), "1.2.3.4")).status, 201);
  assert.deepEqual(await directory.create(await newWorld({ id: "1".repeat(32) }), "1.2.3.4"), { status: 429, body: { error: "too many requests from this address, try again later", code: "rate" } });
  assert.equal((await directory.create(await newWorld({ id: "1".repeat(32) }), "5.6.7.8")).status, 201);
  assert.equal((await directory.create(await newWorld({ id: "2".repeat(32) }))).status, 201, "without an address nothing is limited");

  assert.equal((await directory.putStart(WORLD, CREATOR, Uint8Array.of(1), "1.2.3.4")).status, 200);
  assert.equal((await directory.admit("1".repeat(32), OTHER, AUTH, "1.2.3.4")).status, 200);
  assert.equal((await directory.admit("1".repeat(32), OTHER, AUTH, "1.2.3.4")).status, 429);

  time.now += 60_000;
  assert.equal((await directory.admit("1".repeat(32), OTHER, AUTH, "1.2.3.4")).status, 200);
});

test("a refusal to enter names why in a code", async () => {
  const { directory } = newDirectory({ ...DIRECTORY_LIMITS, maxMembers: 1 });
  await directory.create(await newWorld({ start: true }));

  assert.equal((await directory.admit(WORLD, CREATOR, AUTH)).body.code, "pending");
  await directory.putStart(WORLD, CREATOR, Uint8Array.of(1));
  assert.equal((await directory.admit(WORLD, OTHER, AUTH)).body.code, "members");

  await directory.ban(WORLD, CREATOR, await playerIdOf(OTHER));
  assert.equal((await directory.admit(WORLD, OTHER, AUTH)).body.code, "removed");
  assert.equal((await directory.getStart(WORLD, OTHER, AUTH)).body.code, "removed");
});

test("presence lists a player in the room twice only once", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());
  const other = await playerIdOf(OTHER);

  await directory.presence(WORLD, [{ player: other, name: "Guest" }, { player: other, name: "Guest" }]);
  assert.equal((await directory.list()).body.worlds[0].online, 1);
});

test("handleDirectoryRequest takes the player key of the header before the body's or the address's, and JSON of up to 32 KB", async () => {
  const { directory } = newDirectory();
  const body = (value) => async () => JSON.stringify(value);
  const url = (path) => new URL(`https://relay.test${path}`);
  const long = await newWorld({ start: true, hidden: true, description: "x".repeat(20_000), player: undefined });

  assert.equal((await handleDirectoryRequest(directory, "POST", url("/v1/worlds"), body(long), undefined, { player: CREATOR })).status, 201);
  assert.equal((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds?player=${OTHER}`), body(null), undefined, { player: CREATOR })).body.worlds.length, 1);
  assert.equal((await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/start?player=${OTHER}`), body(null), async () => Uint8Array.of(1), { player: CREATOR })).status, 200);
  assert.equal((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/start?auth=${AUTH}`), body(null), undefined, { player: OTHER })).status, 200);
  assert.equal((await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/edit`), body({ player: OTHER, seats: 8 }), undefined, { player: CREATOR })).status, 200);

  const tooLong = async () => JSON.stringify(await newWorld({ id: "1".repeat(32), description: "x".repeat(DIRECTORY_LIMITS.maxJsonLength) }));
  assert.equal((await handleDirectoryRequest(directory, "POST", url("/v1/worlds"), tooLong)).status, 413);
  assert.equal((await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/edit`), async () => null)).status, 413, "a body the platform could not read whole is too large too");
});

test("handleDirectoryRequest takes the auth key of the header before the address's", async () => {
  const { directory } = newDirectory();
  const url = (path) => new URL(`https://relay.test${path}`);
  const none = async () => "";
  await directory.create(await newWorld({ start: true }));
  await directory.putStart(WORLD, CREATOR, Uint8Array.of(7));

  assert.equal((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/start`), none, undefined, { player: OTHER, auth: AUTH })).status, 200);
  assert.equal((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/start?auth=${"cd".repeat(32)}`), none, undefined, { player: OTHER, auth: AUTH })).status, 200);
  assert.equal((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/start?auth=${AUTH}`), none, undefined, { player: OTHER })).status, 200, "released games send it in the address");
  assert.equal((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/start?auth=${AUTH}`), none, undefined, { player: OTHER, auth: "cd".repeat(32) })).status, 401);
});

test("a world keeps at most so many removed players", async () => {
  const { directory } = newDirectory({ ...DIRECTORY_LIMITS, maxBans: 2 });
  await directory.create(await newWorld());
  const other = await playerIdOf(OTHER);

  assert.equal((await directory.ban(WORLD, CREATOR, other)).status, 200);
  assert.equal((await directory.ban(WORLD, CREATOR, "1".repeat(32))).status, 200);
  assert.equal((await directory.ban(WORLD, CREATOR, "2".repeat(32))).status, 429);
  assert.equal((await directory.ban(WORLD, CREATOR, other)).status, 200, "a player removed already stays removed");
  assert.deepEqual((await directory.admit(WORLD, OTHER, AUTH)).body.code, "removed");
  assert.equal((await directory.admit(WORLD, "2".repeat(32), AUTH)).status, 200);
});

test("a request the directory refuses anyway costs its address no rate turn", async () => {
  const once = { burst: 1, refillMs: 3_600_000 };
  const { directory } = newDirectory();
  directory.rates.creates = new RateLimiter(once);
  directory.rates.starts = new RateLimiter(once);

  assert.equal((await directory.create(await newWorld({ seats: 1 }), "1.2.3.4")).status, 400);
  assert.equal((await directory.create(await newWorld({ start: true }), "1.2.3.4")).status, 201);
  assert.equal((await directory.create(await newWorld(), "1.2.3.4")).status, 409, "a taken id costs no turn either");
  assert.equal((await directory.create(await newWorld({ id: "1".repeat(32) }), "1.2.3.4")).status, 429);

  assert.equal((await directory.putStart(WORLD, OTHER, Uint8Array.of(1), "1.2.3.4")).status, 403);
  assert.equal((await directory.putStart(WORLD, CREATOR, new Uint8Array(0), "1.2.3.4")).status, 413);
  assert.equal((await directory.putStart(WORLD, CREATOR, Uint8Array.of(1), "1.2.3.4")).status, 200);
});

test("a featured, full or per-creator refusal of a new world costs its address no rate turn either", async () => {
  const { directory } = newDirectory({ ...DIRECTORY_LIMITS, maxWorldsPerCreator: 1 });
  assert.equal((await directory.create(await newWorld(), "1.2.3.4")).status, 201);

  for (let i = 1; i <= 6; i++) {
    const answer = await directory.create(await newWorld({ id: String(i).repeat(32) }), "1.2.3.4");
    assert.deepEqual([answer.status, answer.body.code], [429, undefined], `try ${i} names the creator limit, not the rate`);
  }

  assert.equal((await directory.create(await newWorld({ id: "7".repeat(32), player: OTHER, featured: true }), "1.2.3.4")).status, 403);
  assert.equal((await directory.create(await newWorld({ id: "7".repeat(32), player: OTHER }), "1.2.3.4")).status, 201);

  const full = newDirectory({ ...DIRECTORY_LIMITS, maxWorlds: 1 }).directory;
  full.rates.creates = new RateLimiter({ burst: 2, refillMs: 3_600_000 });
  assert.equal((await full.create(await newWorld(), "1.2.3.4")).status, 201);

  for (let i = 1; i <= 3; i++) {
    assert.equal((await full.create(await newWorld({ id: String(i).repeat(32), player: OTHER }), "1.2.3.4")).status, 503);
  }

  full.limits = { ...DIRECTORY_LIMITS, maxWorlds: 2 };
  assert.equal((await full.create(await newWorld({ id: "4".repeat(32), player: OTHER }), "1.2.3.4")).status, 201);
});

test("a Raid World keeps how it shares companions, a Classic one shares none, and both stay as made", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ type: "raid", share: "story" }));
  await directory.create(await newWorld({ id: "1".repeat(32), type: "classic", share: "all" }));
  await directory.create(await newWorld({ id: "2".repeat(32), type: "raid" }));

  const typeOf = async () => Object.fromEntries((await directory.list()).body.worlds.map((world) => [world.id, [world.type, world.share]]));
  assert.deepEqual(await typeOf(), { [WORLD]: ["raid", "story"], ["1".repeat(32)]: ["classic", "off"], ["2".repeat(32)]: ["raid", "off"] });

  assert.equal((await directory.edit(WORLD, CREATOR, { type: "classic", share: "all", seats: 6 })).status, 200);
  assert.deepEqual((await typeOf())[WORLD], ["raid", "story"]);
});

test("a Raid World keeps its difficulty, which its creator or an admin changes and a Classic world never has", async () => {
  const { directory } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld({ type: "raid", difficulty: 2 }));
  await directory.create(await newWorld({ id: "1".repeat(32), type: "classic", difficulty: 2 }));
  await directory.create(await newWorld({ id: "2".repeat(32), type: "raid" }));

  const difficultyOf = async () => Object.fromEntries((await directory.list()).body.worlds.map((world) => [world.id, world.difficulty]));
  assert.deepEqual(await difficultyOf(), { [WORLD]: 2, ["1".repeat(32)]: undefined, ["2".repeat(32)]: undefined }, "a Raid World made without one leaves each player their own");

  const edited = await directory.edit(WORLD, CREATOR, { difficulty: -2 });
  assert.deepEqual([edited.status, edited.difficulty], [200, -2], "the answer names the difficulty the world room tells");
  assert.equal((await directory.edit(WORLD, ADMIN, { difficulty: 4 })).difficulty, 4);
  assert.equal((await directory.edit(WORLD, OTHER, { difficulty: 0 })).status, 403);
  assert.equal((await difficultyOf())[WORLD], 4);
  const same = await directory.edit(WORLD, CREATOR, { difficulty: 4, seats: 6 });
  assert.deepEqual([same.status, same.difficulty], [200, undefined], "the difficulty the world has already tells nothing");
  assert.equal((await directory.edit("2".repeat(32), CREATOR, { difficulty: 0 })).difficulty, 0, "the first difficulty of a world made without one is told");

  for (const bad of [5, -3, 1.5, "1", null]) {
    assert.equal((await directory.edit(WORLD, CREATOR, { difficulty: bad })).status, 400, `difficulty ${bad}`);
  }

  assert.equal((await directory.edit("1".repeat(32), CREATOR, { difficulty: 1 })).status, 400, "only a Raid World sets a difficulty");
  assert.equal((await directory.edit("1".repeat(32), CREATOR, { seats: 6 })).difficulty, undefined, "an edit without one tells none");

  for (const bad of [5, -3, 0.5, "0"]) {
    assert.equal((await directory.create(await newWorld({ id: "3".repeat(32), type: "raid", difficulty: bad }))).status, 400, `new world with difficulty ${bad}`);
  }
});

test("a Raid World keeps its squad settings, which its creator or an admin changes and a Classic world never has", async () => {
  const { directory } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld({ type: "raid", squad: { luka: true, formation: 6, front: 2, raidFront: 1, extra: 1 } }));
  await directory.create(await newWorld({ id: "1".repeat(32), type: "classic", squad: { luka: true, formation: 6, front: 2, raidFront: 1 } }));
  await directory.create(await newWorld({ id: "2".repeat(32), type: "raid" }));

  const squadOf = async () => Object.fromEntries((await directory.list()).body.worlds.map((world) => [world.id, world.squad]));
  assert.deepEqual(await squadOf(), { [WORLD]: { luka: true, formation: 6, front: 2, raidFront: 1 }, ["1".repeat(32)]: undefined, ["2".repeat(32)]: undefined }, "only a Raid World made with them keeps them, without other fields");

  const edited = await directory.edit(WORLD, CREATOR, { squad: { luka: false, formation: 0, front: 4, raidFront: 3 } });
  assert.deepEqual([edited.status, edited.squad], [200, { luka: false, formation: 0, front: 4, raidFront: 3 }], "the answer names the squad settings the world room tells");
  assert.equal(squadText(edited.squad), "squad 0 0 4 3");
  assert.deepEqual((await directory.edit(WORLD, ADMIN, { squad: { luka: true, formation: 8, front: 1, raidFront: 4 } })).squad, { luka: true, formation: 8, front: 1, raidFront: 4 });
  assert.equal((await directory.edit(WORLD, OTHER, { squad: SQUAD_DEFAULTS })).status, 403);
  assert.deepEqual((await squadOf())[WORLD], { luka: true, formation: 8, front: 1, raidFront: 4 });
  const same = await directory.edit(WORLD, CREATOR, { squad: { luka: true, formation: 8, front: 1, raidFront: 4 }, seats: 6 });
  assert.deepEqual([same.status, same.squad], [200, undefined], "the squad settings the world has already tell nothing");

  const defaults = await directory.edit("2".repeat(32), CREATOR, { squad: { ...SQUAD_DEFAULTS } });
  assert.deepEqual([defaults.status, defaults.squad], [200, undefined], "a world made without them counts as having the defaults");
  assert.deepEqual((await squadOf())["2".repeat(32)], SQUAD_DEFAULTS);
  assert.deepEqual((await directory.edit("2".repeat(32), CREATOR, { squad: { ...SQUAD_DEFAULTS, front: 2 } })).squad, { ...SQUAD_DEFAULTS, front: 2 });

  const bads = [
    null, "0 4 1 1", [], { formation: 4, front: 1, raidFront: 1 }, { ...SQUAD_DEFAULTS, luka: 1 },
    { ...SQUAD_DEFAULTS, formation: 3 }, { ...SQUAD_DEFAULTS, formation: 9 }, { ...SQUAD_DEFAULTS, formation: 4.5 },
    { ...SQUAD_DEFAULTS, front: 0 }, { ...SQUAD_DEFAULTS, front: 5 }, { ...SQUAD_DEFAULTS, raidFront: 0 }, { ...SQUAD_DEFAULTS, raidFront: "1" },
  ];

  for (const bad of bads) {
    assert.equal((await directory.edit(WORLD, CREATOR, { squad: bad })).status, 400, `squad ${JSON.stringify(bad)}`);
    assert.equal((await directory.create(await newWorld({ id: "3".repeat(32), type: "raid", squad: bad }))).status, 400, `new world with squad ${JSON.stringify(bad)}`);
  }

  assert.equal((await directory.edit("1".repeat(32), CREATOR, { squad: SQUAD_DEFAULTS })).status, 400, "only a Raid World sets squad settings");
  assert.equal((await directory.edit("1".repeat(32), CREATOR, { seats: 6 })).squad, undefined, "an edit without them tells none");
});

test("a Classic world keeps whether it fights raid bosses, which its creator or an admin changes and a Raid World never has", async () => {
  const { directory, store } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld({ raidBosses: true }));
  await directory.create(await newWorld({ id: "1".repeat(32), raidBosses: false }));
  await directory.create(await newWorld({ id: "2".repeat(32) }));
  await directory.create(await newWorld({ id: "3".repeat(32), type: "raid", raidBosses: true }));

  const raidBossesOf = async () => Object.fromEntries((await directory.list()).body.worlds.map((world) => [world.id, world.raidBosses]));
  assert.deepEqual(await raidBossesOf(), { [WORLD]: true, ["1".repeat(32)]: false, ["2".repeat(32)]: false, ["3".repeat(32)]: undefined }, "every Classic world is listed with it, a Raid World never");
  assert.deepEqual([(await store.get("1".repeat(32))).raidBosses, (await store.get("3".repeat(32))).raidBosses], [undefined, undefined], "only a Classic world made with true keeps it");

  const off = await directory.edit(WORLD, CREATOR, { raidBosses: false });
  assert.deepEqual([off.status, off.raidBosses], [200, false], "the answer names the value the world room tells, false too");
  assert.equal(raidBossesText(off.raidBosses), `${RAID_BOSSES_TEXT} 0`);
  assert.equal((await raidBossesOf())[WORLD], false);
  const on = await directory.edit(WORLD, ADMIN, { raidBosses: true });
  assert.deepEqual([on.status, on.raidBosses], [200, true]);
  assert.equal(raidBossesText(on.raidBosses), "raid_bosses 1");
  assert.equal((await directory.edit(WORLD, OTHER, { raidBosses: false })).status, 403);
  assert.equal((await raidBossesOf())[WORLD], true);
  const same = await directory.edit(WORLD, CREATOR, { raidBosses: true, seats: 6 });
  assert.deepEqual([same.status, same.raidBosses], [200, undefined], "the value the world has already tells nothing");

  const missing = await directory.edit("2".repeat(32), CREATOR, { raidBosses: false });
  assert.deepEqual([missing.status, missing.raidBosses], [200, undefined], "a world made without it counts as false");
  assert.equal((await directory.edit("2".repeat(32), CREATOR, { raidBosses: true })).raidBosses, true);
  assert.equal((await directory.edit("2".repeat(32), CREATOR, { seats: 6 })).raidBosses, undefined, "an edit without it tells none");

  for (const bad of [1, 0, "yes", null, {}, []]) {
    assert.equal((await directory.edit(WORLD, CREATOR, { raidBosses: bad })).status, 400, `raidBosses ${JSON.stringify(bad)}`);
    assert.equal((await directory.create(await newWorld({ id: "4".repeat(32), raidBosses: bad }))).status, 400, `new world with raidBosses ${JSON.stringify(bad)}`);
  }

  const raid = await directory.edit("3".repeat(32), CREATOR, { raidBosses: true });
  assert.deepEqual([raid.status, raid.body.error], [400, "only a Classic world sets raid bosses"]);
  assert.equal((await raidBossesOf())["3".repeat(32)], undefined);
});

test("a Raid World starts from the beginning: no starting save and no player's choice", async () => {
  const { directory } = newDirectory();

  for (const changes of [{ start: true }, { choose: true }]) {
    const refused = await directory.create(await newWorld({ type: "raid", ...changes }));
    assert.deepEqual([refused.status, refused.body.code], [400, "raid_start"]);
  }

  assert.equal((await directory.create(await newWorld({ type: "raid", start: false, choose: false }))).status, 201);
  const upload = await directory.putStart(WORLD, CREATOR, Uint8Array.of(1));
  assert.deepEqual([upload.status, upload.body.code], [400, "raid_start"]);

  assert.equal((await directory.create(await newWorld({ id: "1".repeat(32), start: true, choose: true }))).status, 201, "a Classic world keeps both as before");
});

test("a game that names the dev feature gives a Raid World a starting save, never a player's choice", async () => {
  const { directory } = newDirectory();
  const dev = ["raid", "dev"];

  const choice = await directory.create(await newWorld({ type: "raid", start: true, choose: true }), null, dev);
  assert.deepEqual([choice.status, choice.body.code], [400, "raid_start"], "a player's choice stays refused");

  assert.equal((await directory.create(await newWorld({ type: "raid", start: true }), null, dev)).status, 201);
  assert.equal((await directory.lock(WORLD)).body.start, "pending");

  const released = await directory.putStart(WORLD, CREATOR, Uint8Array.of(1), null, ["raid"]);
  assert.deepEqual([released.status, released.body.code], [400, "raid_start"], "a released game uploads none");

  assert.deepEqual(await directory.putStart(WORLD, CREATOR, Uint8Array.of(1, 2, 3), null, dev), { status: 200, body: { bytes: 3 } });
  const listed = (await directory.list(CREATOR)).body.worlds.find((world) => world.id === WORLD);
  assert.deepEqual([listed.type, listed.start], ["raid", "ready"]);
  assert.equal((await directory.getStart(WORLD, CREATOR, AUTH)).bytes.length, 3);
});

test("handleDirectoryRequest hands what a game names in X-MGQ-Features to making a world and uploading its starting save", async () => {
  const { directory } = newDirectory();
  const url = (path) => new URL(`https://relay.example${path}`);
  const body = (value) => async () => JSON.stringify(value);
  const bytes = async () => Uint8Array.of(7, 7);
  const world = await newWorld({ type: "raid", start: true });

  const released = await handleDirectoryRequest(directory, "POST", url("/v1/worlds"), body(world), bytes, { features: ["raid"] });
  assert.deepEqual([released.status, released.body.code], [400, "raid_start"]);

  assert.equal((await handleDirectoryRequest(directory, "POST", url("/v1/worlds"), body(world), bytes, { features: ["raid", "dev"] })).status, 201);
  const refused = await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/start`), body(null), bytes, { player: CREATOR, features: ["raid"] });
  assert.deepEqual([refused.status, refused.body.code], [400, "raid_start"]);
  assert.equal((await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/start`), body(null), bytes, { player: CREATOR, features: ["raid", "dev"] })).status, 200);
});

test("a world's mods past the limit are refused, never cut, when it is made or edited", async () => {
  const { directory } = newDirectory();
  const refused = await directory.create(await newWorld({ mods: "!Level Cap;" + "x".repeat(300) }));
  assert.equal(refused.status, 400);
  assert.match(refused.body.error, /at most 300 characters/);

  await directory.create(await newWorld({ mods: "!Level Cap" }));
  assert.equal((await directory.edit(WORLD, CREATOR, { mods: "y".repeat(301) })).status, 400);
  assert.equal((await directory.list()).body.worlds[0].mods, "!Level Cap", "a refused edit changes nothing");
  assert.equal((await directory.edit(WORLD, CREATOR, { mods: "y".repeat(300) })).status, 200);
  assert.equal((await directory.list()).body.worlds[0].mods, "y".repeat(300));
});

test("a world turns other mods off as made, by default a Raid World only", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ type: "raid" }));
  await directory.create(await newWorld({ id: "1".repeat(32), type: "classic" }));
  await directory.create(await newWorld({ id: "2".repeat(32) }));
  await directory.create(await newWorld({ id: "3".repeat(32), type: "raid", otherModsOff: false }));
  await directory.create(await newWorld({ id: "4".repeat(32), otherModsOff: true }));

  const offOf = Object.fromEntries((await directory.list()).body.worlds.map((world) => [world.id, world.otherModsOff]));
  assert.deepEqual(offOf, { [WORLD]: true, ["1".repeat(32)]: false, ["2".repeat(32)]: false, ["3".repeat(32)]: false, ["4".repeat(32)]: true });
});

test("the creator or an admin turns other mods off or on, and the world room is told with the mods only on a change", async () => {
  const { directory } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld({ mods: "!Level Cap;?Party Sheet" }));
  const offOf = async () => (await directory.list()).body.worlds[0].otherModsOff;

  const on = await directory.edit(WORLD, CREATOR, { otherModsOff: true });
  assert.equal(on.status, 200);
  assert.deepEqual(on.modsRule, { off: true, mods: "!Level Cap;?Party Sheet" }, "the answer names what the world room tells");
  assert.equal(await offOf(), true);

  assert.equal((await directory.edit(WORLD, CREATOR, { otherModsOff: true, seats: 6 })).modsRule, undefined, "the same value tells nothing");
  assert.equal((await directory.edit(WORLD, CREATOR, { mods: "!Level Cap;?Party Sheet" })).modsRule, undefined, "the same mods tell nothing");
  assert.deepEqual((await directory.edit(WORLD, ADMIN, { mods: "  !Level Cap\t " })).modsRule, { off: true, mods: "!Level Cap" }, "the mods are told as kept");
  assert.deepEqual((await directory.edit(WORLD, ADMIN, { otherModsOff: false })).modsRule, { off: false, mods: "!Level Cap" });
  assert.equal(await offOf(), false);

  assert.equal((await directory.edit(WORLD, OTHER, { otherModsOff: true })).status, 403);

  for (const bad of ["1", 1, null, "true"]) {
    assert.equal((await directory.edit(WORLD, CREATOR, { otherModsOff: bad })).status, 400, `otherModsOff ${bad}`);
  }

  assert.equal(await offOf(), false);
});

test("modsRuleText writes the frame that tells a world room whether other mods are off and the world's mods", () => {
  assert.equal(MODS_RULE_TEXT, "mods_rule");
  assert.equal(modsRuleText(true, "!Level Cap;Party Sheet"), "mods_rule 1\t!Level Cap;Party Sheet");
  assert.equal(modsRuleText(false, ""), "mods_rule 0\t");
});

test("an edit over HTTP hands the mods rule on with the world it is for", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ type: "raid", mods: "Level Cap" }));
  const url = new URL(`https://relay.test/v1/worlds/${WORLD}/edit`);

  const answer = await handleDirectoryRequest(directory, "POST", url, async () => JSON.stringify({ player: CREATOR, otherModsOff: false }), async () => null);
  assert.deepEqual([answer.status, answer.id, answer.modsRule], [200, WORLD, { off: false, mods: "Level Cap" }]);
});

test("a world kept from before the setting turns other mods off when it is a Raid World", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ type: "raid", mods: "Level Cap" }));
  await directory.create(await newWorld({ id: "1".repeat(32), mods: "Level Cap" }));

  for (const id of [WORLD, "1".repeat(32)]) {
    const entry = await directory.store.get(id);
    delete entry.otherModsOff;
    await directory.store.put(entry);
  }

  const offOf = async () => Object.fromEntries((await directory.list()).body.worlds.map((world) => [world.id, world.otherModsOff]));
  assert.deepEqual(await offOf(), { [WORLD]: true, ["1".repeat(32)]: false });
  assert.equal((await directory.edit(WORLD, CREATOR, { otherModsOff: true })).modsRule, undefined, "the value read by type counts as the old one");
  assert.deepEqual((await directory.edit("1".repeat(32), CREATOR, { otherModsOff: true })).modsRule, { off: true, mods: "Level Cap" });
});

test("a world kept from before types is Classic", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());
  const entry = await directory.store.get(WORLD);
  delete entry.type;
  delete entry.share;
  await directory.store.put(entry);

  const world = (await directory.list()).body.worlds[0];
  assert.deepEqual([world.type, world.share], ["classic", "off"]);
  assert.equal((await directory.admit(WORLD, OTHER, AUTH)).status, 200);
});

test("a Raid World lets in only games that name Raid Worlds among their features", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ type: "raid", share: "all" }));

  assert.deepEqual((await directory.admit(WORLD, OTHER, AUTH)).body, { error: "the world is a Raid World, which this game cannot play", code: "raid_unsupported" });
  assert.equal((await directory.admit(WORLD, OTHER, AUTH, null, ["trades"])).status, 400);
  assert.equal((await directory.admit(WORLD, OTHER, AUTH, null, [FEATURE.raid])).status, 200);
  assert.equal((await directory.admit(WORLD, OTHER, "cd".repeat(32), null, [])).status, 401, "a wrong token is told before the type");

  await directory.create(await newWorld({ id: "1".repeat(32) }));
  assert.equal((await directory.admit("1".repeat(32), OTHER, AUTH)).status, 200, "a Classic world takes released games as before");
});

test("member tells a world room who plays its world, with the world's type and auth hash", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ type: "raid" }));

  const answer = await directory.member(WORLD, OTHER, AUTH);
  assert.equal(answer.status, 200);
  assert.deepEqual([answer.player, answer.type, answer.authHash], [await playerIdOf(OTHER), "raid", await sha256Hex(AUTH)]);

  assert.equal((await directory.member(WORLD, OTHER, "cd".repeat(32))).status, 401);
  assert.equal((await directory.member("9".repeat(32), OTHER, AUTH)).status, 404);
  assert.equal(answer.name, null, "a player who never entered the world has no name yet");
  assert.equal((await directory.member(WORLD, CREATOR, AUTH)).name, "Creator");

  await directory.ban(WORLD, CREATOR, await playerIdOf(OTHER));
  assert.equal((await directory.member(WORLD, OTHER, AUTH)).status, 403);
});

test("member refuses a world whose starting save is still being uploaded", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ start: true }));

  const pending = await directory.member(WORLD, CREATOR, AUTH);
  assert.equal(pending.status, 409);
  assert.equal(pending.body.code, "pending");

  await directory.putStart(WORLD, CREATOR, Uint8Array.of(7));
  assert.equal((await directory.member(WORLD, CREATOR, AUTH)).status, 200);
});

test("raidAdmin tells a world room whether a key is an admin's, with the world's type", async () => {
  const { directory } = newDirectory(DIRECTORY_LIMITS, [await playerIdOf(ADMIN)]);
  await directory.create(await newWorld({ type: "raid" }));

  const answer = await directory.raidAdmin(WORLD, ADMIN);
  assert.deepEqual([answer.status, answer.type], [200, "raid"]);
  assert.equal((await directory.raidAdmin(WORLD, CREATOR)).status, 403, "the creator is no admin");
  assert.equal((await directory.raidAdmin(WORLD, "zz")).status, 403);
  assert.equal((await directory.raidAdmin("9".repeat(32), ADMIN)).status, 404);
});

test("parseFeatures reads the features a game names, separated by commas or white space, in lower case", () => {
  assert.deepEqual(parseFeatures("raid"), ["raid"]);
  assert.deepEqual(parseFeatures(" Raid, trades  boss "), ["raid", "trades", "boss"]);
  assert.deepEqual(parseFeatures(""), []);
  assert.deepEqual(parseFeatures(null), []);
  assert.deepEqual(parseFeatures(undefined), []);
});

test("an edit and a presence at once keep the newcomer and the edit", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());
  const other = await playerIdOf(OTHER);

  await Promise.all([directory.edit(WORLD, CREATOR, { seats: 6, data: "x:1" }), directory.presence(WORLD, [{ player: other, name: "Guest" }])]);

  const world = (await directory.list()).body.worlds[0];
  assert.equal(world.seats, 6);
  assert.deepEqual(world.members.map((member) => member.id), [await playerIdOf(CREATOR), other]);
});

test("a removal and an edit at once keep both", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());
  const other = await playerIdOf(OTHER);
  await directory.presence(WORLD, [{ player: other, name: "Guest" }]);

  await Promise.all([directory.ban(WORLD, CREATOR, other), directory.edit(WORLD, CREATOR, { seats: 6 })]);

  const world = (await directory.list()).body.worlds[0];
  assert.equal(world.seats, 6);
  assert.deepEqual(world.members.map((member) => member.id), [await playerIdOf(CREATOR)]);
  assert.equal((await directory.admit(WORLD, OTHER, AUTH)).status, 403, "the removed player stays out");
});

test("a starting save and a presence at once keep both", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld({ start: true }));
  const other = await playerIdOf(OTHER);

  await Promise.all([directory.putStart(WORLD, CREATOR, Uint8Array.of(7)), directory.presence(WORLD, [{ player: other, name: "Guest" }])]);

  const world = (await directory.list()).body.worlds[0];
  assert.equal(world.start, "ready");
  assert.equal(world.members.some((member) => member.id === other), true);
});

test("two creates of the same world at once make it once", async () => {
  const { directory } = newDirectory();

  const answers = await Promise.all([directory.create(await newWorld()), directory.create(await newWorld({ player: OTHER }))]);

  assert.deepEqual(answers.map((answer) => answer.status).sort(), [201, 409]);
  assert.equal((await directory.list()).body.worlds.length, 1);
});
