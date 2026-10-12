//----------------------------------------------------------------
//  bodies.test.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

import { test } from "node:test";
import assert from "node:assert/strict";
import { DOWNLOAD_LIMITS, DownloadGate, concatBytes, downloadBusy, piecesStream, readLimited, releaseWhenDone } from "./bodies.js";
import { RATE_LIMITS } from "./relay.js";

/**
 * Addresses of different games, from a range kept for documentation.
 */
const ADDRESSES = Array.from({ length: 20 }, (_, index) => `198.51.100.${index + 1}`);

/**
 * Makes a stream that hands out chunks only when read, and counts how many it handed out.
 *
 * @param {number} count How many chunks.
 * @param {number} size Bytes per chunk, each chunk filled with its number.
 * @returns {{stream: ReadableStream<Uint8Array>, pulled: () => number, cancelled: () => boolean}} The stream and its counts.
 */
function countingStream(count, size) {
  let pulled = 0;
  let cancelled = false;

  const stream = new ReadableStream({
    pull(controller) {
      if (pulled === count) {
        controller.close();
        return;
      }

      pulled++;
      controller.enqueue(new Uint8Array(size).fill(pulled));
    },
    cancel() {
      cancelled = true;
    },
  }, { highWaterMark: 0 });

  return { stream, pulled: () => pulled, cancelled: () => cancelled };
}

/**
 * Reads a stream to its end.
 *
 * @param {ReadableStream<Uint8Array>} stream The stream.
 * @returns {Promise<Uint8Array>} Its bytes.
 */
async function readAll(stream) {
  const chunks = [];

  for await (const chunk of stream) {
    chunks.push(chunk);
  }

  return concatBytes(chunks);
}

/**
 * Lets every promise that can settle now settle.
 */
function settle() {
  return new Promise((resolve) => setImmediate(resolve));
}

/**
 * Follows a promise, so a test can see whether it settled yet.
 *
 * @param {Promise<any>} promise The promise.
 * @returns {{value: any}} Its value once it settled, undefined before.
 */
function watch(promise) {
  const watched = { value: undefined };
  promise.then((value) => {
    watched.value = value;
  });
  return watched;
}

test("concatBytes joins chunks in order", () => {
  assert.deepEqual([...concatBytes([new Uint8Array([1, 2]), new Uint8Array(0), new Uint8Array([3])])], [1, 2, 3]);
  assert.equal(concatBytes([]).length, 0);
});

test("readLimited stops reading a body over the limit after one chunk past it", async () => {
  const source = countingStream(10, 100);

  assert.equal(await readLimited(source.stream, 250), null);
  assert.equal(source.pulled(), 3, "the limit and one chunk past it");
  assert.equal(source.cancelled(), true);
});

test("readLimited hands back a body at or under the limit as it is, and nothing for no body", async () => {
  const source = countingStream(3, 100);
  const bytes = await readLimited(source.stream, 300);

  assert.equal(bytes.length, 300);
  assert.deepEqual([bytes[0], bytes[100], bytes[299]], [1, 2, 3]);
  assert.equal((await readLimited(null, 10)).length, 0);
});

test("piecesStream sends the pieces in order, reading each only when the reader wants it", async () => {
  const pieces = [new Uint8Array([1, 2]), new Uint8Array([3]), new Uint8Array([4, 5, 6])];
  const read = [];
  const stream = await piecesStream(async (index) => (read.push(index), pieces[index]));

  assert.deepEqual(read, [0], "only the first piece is read before sending");
  assert.deepEqual([...(await readAll(stream))], [1, 2, 3, 4, 5, 6]);
  assert.deepEqual(read, [0, 1, 2, 3]);
});

test("piecesStream finds no file when its first piece is missing", async () => {
  assert.equal(await piecesStream(async () => undefined), undefined);
});

test("piecesStream fails the stream when a piece cannot be read", async () => {
  const stream = await piecesStream(async (index) => {
    if (index === 1) {
      throw new Error("storage failed");
    }

    return new Uint8Array([index]);
  });

  await assert.rejects(readAll(stream), /storage failed/);
});

test("releaseWhenDone calls back once when the stream ends, is cancelled or fails", async () => {
  let released = 0;
  const release = () => released++;

  const finished = releaseWhenDone(countingStream(2, 3).stream, release);
  assert.equal((await readAll(finished.stream)).length, 6);
  assert.equal(released, 1);

  const source = countingStream(5, 3);
  const cancelled = releaseWhenDone(source.stream, release);
  const reader = cancelled.stream.getReader();
  await reader.read();
  await reader.cancel();
  assert.deepEqual([released, source.cancelled()], [2, true]);

  const failing = releaseWhenDone(new ReadableStream({ pull: (controller) => controller.error(new Error("broken")) }), release);
  await assert.rejects(readAll(failing.stream), /broken/);
  assert.equal(released, 3);

  finished.abort();
  assert.equal(released, 3, "a stream that ended calls back no more");
});

test("releaseWhenDone ends a stream early on abort, which fails its reader and cancels the source", async () => {
  let released = 0;
  const source = countingStream(5, 3);
  const held = releaseWhenDone(source.stream, () => released++);
  const reader = held.stream.getReader();
  await reader.read();

  held.abort();
  await assert.rejects(reader.read(), /took too long/);
  await settle();
  assert.deepEqual([released, source.cancelled()], [1, true]);
});

test("the gate lets three downloads run at once, and a fourth waits until one ends", async () => {
  const gate = new DownloadGate();
  const slots = [];

  for (const address of ADDRESSES.slice(0, DOWNLOAD_LIMITS.maxActive)) {
    slots.push(await gate.enter(address));
  }

  assert.ok(slots.every((slot) => slot.release));
  const fourth = watch(gate.enter(ADDRESSES[3]));
  await settle();
  assert.equal(fourth.value, undefined, "the fourth waits");

  slots[1].release();
  slots[1].release();
  await settle();
  assert.ok(fourth.value.release, "a freed slot goes to the waiting download");
  assert.equal(gate.active.size, DOWNLOAD_LIMITS.maxActive, "a slot given back twice counts once");
});

test("the gate runs one download per address, and lets another address pass one that waits", async () => {
  const gate = new DownloadGate();
  const first = await gate.enter(ADDRESSES[0]);
  const again = watch(gate.enter(ADDRESSES[0]));
  const other = watch(gate.enter(ADDRESSES[1]));
  await settle();

  assert.equal(again.value, undefined);
  assert.ok(other.value.release);

  first.release();
  await settle();
  assert.ok(again.value.release);
});

test("the gate refuses a download at once when as many are waiting as may", async () => {
  const gate = new DownloadGate();

  for (const address of ADDRESSES.slice(0, DOWNLOAD_LIMITS.maxActive)) {
    await gate.enter(address);
  }

  const waiting = ADDRESSES.slice(DOWNLOAD_LIMITS.maxActive, DOWNLOAD_LIMITS.maxActive + DOWNLOAD_LIMITS.maxWaiting).map((address) => watch(gate.enter(address)));
  const refused = await gate.enter(ADDRESSES[DOWNLOAD_LIMITS.maxActive + DOWNLOAD_LIMITS.maxWaiting]);

  assert.deepEqual(refused, { refusal: downloadBusy() });
  assert.deepEqual([refused.refusal.status, refused.refusal.body.code, refused.refusal.headers["Retry-After"]], [503, "busy", "10"]);
  assert.ok(waiting.every((each) => each.value === undefined));
  assert.equal(gate.waiting.length, DOWNLOAD_LIMITS.maxWaiting);
});

test("the gate refuses a download that waited too long for its turn", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout", "Date"], now: 1_000_000 });
  const gate = new DownloadGate();

  for (const address of ADDRESSES.slice(0, DOWNLOAD_LIMITS.maxActive)) {
    await gate.enter(address);
  }

  const late = watch(gate.enter(ADDRESSES[3]));
  t.mock.timers.tick(DOWNLOAD_LIMITS.maxWaitMs - 1);
  await settle();
  assert.equal(late.value, undefined);

  t.mock.timers.tick(1);
  await settle();
  assert.deepEqual(late.value, { refusal: downloadBusy() });
  assert.equal(gate.waiting.length, 0);
});

test("the gate refuses an address that starts too many downloads", async (t) => {
  t.mock.timers.enable({ apis: ["Date"], now: 1_000_000 });
  const gate = new DownloadGate();

  for (let turn = 0; turn < RATE_LIMITS.downloads.burst; turn++) {
    (await gate.enter(ADDRESSES[0])).release();
  }

  assert.deepEqual(await gate.enter(ADDRESSES[0]), { refusal: downloadBusy() });
  assert.ok((await gate.enter(ADDRESSES[1])).release, "other addresses keep their turns");

  t.mock.timers.tick(RATE_LIMITS.downloads.refillMs);
  assert.ok((await gate.enter(ADDRESSES[0])).release);
});

test("the gate ends a download that holds its slot too long and gives the slot to the next one", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout", "Date"], now: 1_000_000 });
  const gate = new DownloadGate();
  const stalled = await gate.enter(ADDRESSES[0]);
  const source = countingStream(5, 3);
  const reader = stalled.hold(source.stream).getReader();
  await reader.read();

  // The others start later and keep their slots; the waiting one starts waiting before the stalled
  // download runs out of time, and gets its slot then.
  t.mock.timers.tick(DOWNLOAD_LIMITS.maxHoldMs - DOWNLOAD_LIMITS.maxWaitMs / 2);

  for (const address of ADDRESSES.slice(1, DOWNLOAD_LIMITS.maxActive)) {
    await gate.enter(address);
  }

  const waiting = watch(gate.enter(ADDRESSES[3]));
  t.mock.timers.tick(DOWNLOAD_LIMITS.maxWaitMs);
  await settle();

  assert.ok(waiting.value.release, "the stalled slot went to the waiting download");
  await assert.rejects(reader.read(), /took too long/);
  assert.equal(source.cancelled(), true);
  assert.equal(gate.active.size, DOWNLOAD_LIMITS.maxActive);
});

test("the gate gives a held slot back once its stream is read to the end", async () => {
  const gate = new DownloadGate();
  const slot = await gate.enter(ADDRESSES[0]);
  const stream = slot.hold(countingStream(2, 4).stream);

  assert.equal(gate.active.size, 1);
  assert.equal((await readAll(stream)).length, 8);
  assert.equal(gate.active.size, 0);
});
