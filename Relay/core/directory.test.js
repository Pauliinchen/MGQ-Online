//----------------------------------------------------------------
//  directory.test.js
//
//  Changelog:
//      Paulinchen  2026-09-30: Covered the starting save: uploaded once by the creator, fetched by players only
//                            - Covered hidden worlds, listed only for their players, and the lock naming its world
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { DIRECTORY_LIMITS, Directory, cleanName, handleDirectoryRequest, playerIdOf, sha256Hex } from "./directory.js";

/**
 * The creator's player key, as games make them.
 */
const CREATOR = "c0".repeat(16);

/**
 * Another player's key.
 */
const OTHER = "0f".repeat(16);

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
 * @returns {{directory: Directory, time: {now: number}}} The directory and its clock.
 */
function newDirectory(limits = DIRECTORY_LIMITS) {
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

  return { directory: new Directory(store, { clock: () => time.now, limits }), time, starts };
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
  assert.deepEqual(body.worlds[0].members, [{ id: creator, name: "Creator", online: false }]);
  assert.equal(body.worlds[0].start, "none");
  assert.equal(body.worlds[0].hidden, false);
  assert.equal(JSON.stringify(body).includes("authHash"), false);
  assert.equal(JSON.stringify(body).includes("box"), false);
  assert.notEqual(creator, CREATOR);
});

test("a world is refused twice, with bad fields, or beyond a creator's limit", async () => {
  const { directory } = newDirectory({ ...DIRECTORY_LIMITS, maxWorldsPerCreator: 1 });

  await directory.create(await newWorld());
  assert.equal((await directory.create(await newWorld())).status, 409);
  assert.equal((await directory.create(await newWorld({ id: "1".repeat(32) }))).status, 429);

  for (const bad of [{ start: "yes" }, { hidden: 1 },{ seats: 1 }, { seats: 33 }, { name: " " }, { id: "xyz" }, { player: "short" }, { authHash: "00" }, { lock: { salt: "12", iterations: 200_000, box: "ab" } }, { lock: { salt: "12".repeat(16), iterations: 10, box: "ab" } }]) {
    assert.equal((await directory.create(await newWorld({ id: "2".repeat(32), player: OTHER, ...bad }))).status, 400, JSON.stringify(bad));
  }
});

test("the lock is handed out to anyone, since only the password opens it", async () => {
  const { directory } = newDirectory();
  await directory.create(await newWorld());

  assert.deepEqual((await directory.lock(WORLD)).body, { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(60), name: "Iliasburg Crew", seats: 4, start: "none" });
  assert.equal((await directory.lock("f".repeat(32))).status, 404);
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
  assert.deepEqual(world.members.find((member) => member.id === other), { id: other, name: "Guest", online: true });

  await directory.presence(WORLD, []);
  world = (await directory.list()).body.worlds[0];
  assert.equal(world.online, 0);
  assert.equal(world.members.length, 2);
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
