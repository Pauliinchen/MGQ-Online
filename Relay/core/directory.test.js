//----------------------------------------------------------------
//  directory.test.js
//
//  Changelog:
//      Paulinchen  2026-10-06: Expected up to 300 characters of mods
//                            - Covered admins replacing a world's mod settings
//                            - Covered a world's mod hashes and mod settings, which only its creator sets
//      Paulinchen  2026-10-04: Expected the lock without the mods, the game data and the rule for it
//                            - Covered a creator replacing a world's game data, which an admin may not
//                            - Covered hidden worlds listed for a player who names their ids
//                            - Covered changing a world's seats, description and mods
//                            - Covered a world's description, the mods it needs, its creator's game data and whether only games with the same data may enter
//      Paulinchen  2026-10-02: Covered worlds whose new players choose where to start
//                            - Covered worlds without a password, featured worlds and when players were last seen
//      Paulinchen  2026-10-01: Covered the refusal of a delete by someone who is neither the creator nor an admin
//      Paulinchen  2026-09-30: Covered the relay's admins, who see every world and delete any
//                            - Covered the starting save: uploaded once by the creator, fetched by players only
//                            - Covered hidden worlds, listed only for their players, and the lock naming its world
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { DIRECTORY_LIMITS, Directory, cleanName, handleDirectoryRequest, parseAdmins, playerIdOf, sha256Hex } from "./directory.js";

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
 * @returns {{directory: Directory, time: {now: number}}} The directory and its clock.
 */
function newDirectory(limits = DIRECTORY_LIMITS, admins = []) {
  const entries = new Map();
  const starts = new Map();
  const time = { now: 1_000_000 };
  const store = {
    get: async (id) => (entries.has(id) ? structuredClone(entries.get(id)) : undefined),
    put: async (entry) => void entries.set(entry.id, structuredClone(entry)),
    remove: async (id) => {
      entries.delete(id);
      starts.delete(id);
    },
    all: async () => [...entries.values()].map((entry) => structuredClone(entry)),
    putStart: async (id, bytes) => void starts.set(id, Uint8Array.from(bytes)),
    getStart: async (id) => starts.get(id),
  };

  return { directory: new Directory(store, { clock: () => time.now, limits, admins }), time, starts };
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
  assert.equal(JSON.stringify(body).includes("authHash"), false);
  assert.equal(JSON.stringify(body).includes("box"), false);
  assert.notEqual(creator, CREATOR);
});

test("a world is refused twice, with bad fields, or beyond a creator's limit", async () => {
  const { directory } = newDirectory({ ...DIRECTORY_LIMITS, maxWorldsPerCreator: 1 });

  await directory.create(await newWorld());
  assert.equal((await directory.create(await newWorld())).status, 409);
  assert.equal((await directory.create(await newWorld({ id: "1".repeat(32) }))).status, 429);

  for (const bad of [{ start: "yes" }, { hidden: 1 }, { choose: "no" }, { open: "yes" }, { featured: 1 }, { description: 5 }, { mods: [] }, { data: "A B" }, { data: "x".repeat(161) }, { strict: "yes" }, { seats: 1 }, { seats: 33 }, { name: " " }, { id: "xyz" }, { player: "short" }, { authHash: "00" }, { lock: { salt: "12", iterations: 200_000, box: "ab" } }, { lock: { salt: "12".repeat(16), iterations: 10, box: "ab" } }]) {
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
  await directory.create(await newWorld({ description: "  A slow run\tthrough part one.  ", mods: "x".repeat(320), data: "1:0a1b2c3d.ffffffff", strict: true }));

  const world = (await directory.list()).body.worlds[0];
  assert.equal(world.description, "A slow runthrough part one.");
  assert.equal(world.mods, "x".repeat(300));
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
  assert.equal((await handleDirectoryRequest(directory, "PUT", url("/v1/worlds"), body(null))).status, 405);

  assert.equal((await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/start?player=${CREATOR}`), body(null), bytes(Uint8Array.of(9, 8)))).status, 200);
  assert.deepEqual((await handleDirectoryRequest(directory, "GET", url(`/v1/worlds/${WORLD}/start?player=${OTHER}&auth=${AUTH}`), body(null))).bytes, Uint8Array.of(9, 8));

  const deleted = await handleDirectoryRequest(directory, "POST", url(`/v1/worlds/${WORLD}/delete`), body({ player: CREATOR }));
  assert.equal(deleted.status, 200);
  assert.equal(deleted.id, WORLD);
  assert.equal(deleted.close, true);
});
