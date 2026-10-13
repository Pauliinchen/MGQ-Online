//----------------------------------------------------------------
//  bodies.js
//
//  Changelog:
//      Paulinchen  2026-10-12: Stopped reading a body at a deadline and drained a body up to a limit
//                            - Created
//
//----------------------------------------------------------------

// How the relay reads and sends large bodies without holding more of them than it must: a body read
// up to a limit and no further, a file sent piece by piece as it is stored, and a gate that lets
// only a few such downloads run at once. It uses plain Web Streams, the same on every platform.

import { RATE_LIMITS, RateLimiter } from "./relay.js";

/**
 * How many downloads of starting saves and mod files may run at once, and how long a request waits
 * for its turn.
 */
export const DOWNLOAD_LIMITS = Object.freeze({
  maxActive: 3,
  perAddress: 1,
  maxWaiting: 10,
  maxWaitMs: 30 * 1000,
  // A download still running after this long gives up its slot, so a reader that stalls frees it.
  maxHoldMs: 5 * 60 * 1000,
  retryAfterSeconds: 10,
});

/**
 * Joins byte chunks into one array.
 *
 * @param {Uint8Array[]} chunks The chunks.
 * @returns {Uint8Array} Their bytes in order.
 */
export function concatBytes(chunks) {
  const bytes = new Uint8Array(chunks.reduce((size, chunk) => size + chunk.byteLength, 0));
  let offset = 0;

  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return bytes;
}

/**
 * Reads a stream's bytes, unless they are more than a limit, in which case it stops reading at
 * once.
 *
 * @param {ReadableStream<Uint8Array> | null} stream The stream, null for an empty body.
 * @param {number} limit The most bytes it may have.
 * @param {AbortSignal} [signal] Ends the reading with an error once it aborts, as at a deadline.
 * @returns {Promise<Uint8Array | null>} The bytes, or null when there are more than the limit.
 */
export async function readLimited(stream, limit, signal) {
  const chunks = [];
  return (await eachChunk(stream, limit, signal, (chunk) => chunks.push(chunk))) ? concatBytes(chunks) : null;
}

/**
 * Reads a stream to its end and drops what it reads, stopping past a limit or once a signal
 * aborts. It never fails.
 *
 * @param {ReadableStream<Uint8Array> | null} stream The stream, null for an empty body.
 * @param {number} limit The most bytes read.
 * @param {AbortSignal} [signal] Stops the reading once it aborts, as at a deadline.
 * @returns {Promise<void>} Completes once the stream ended or the reading stopped.
 */
export async function drainLimited(stream, limit, signal) {
  await eachChunk(stream, limit, signal, () => {}).catch(() => {});
}

/**
 * Reads a stream chunk by chunk, cancelling it past a limit or once a signal aborts.
 *
 * @param {ReadableStream<Uint8Array> | null} stream The stream, null for an empty body.
 * @param {number} limit The most bytes it may have.
 * @param {AbortSignal | undefined} signal Ends the reading with its reason once it aborts.
 * @param {(chunk: Uint8Array) => void} take Gets each chunk within the limit.
 * @returns {Promise<boolean>} True once the stream ended within the limit, false past it.
 */
async function eachChunk(stream, limit, signal, take) {
  signal?.throwIfAborted();

  if (!stream) {
    return true;
  }

  const reader = stream.getReader();
  let stop = () => {};
  // Raced against each read, since a read a cancel ends reports a plain end of the stream.
  const aborted = signal ? new Promise((_, reject) => (stop = () => reject(signal.reason))) : null;
  const read = () => (aborted ? Promise.race([reader.read(), aborted]) : reader.read());
  const abort = () => {
    stop();
    reader.cancel(signal.reason).catch(() => {});
  };

  aborted?.catch(() => {});
  signal?.addEventListener("abort", abort, { once: true });

  try {
    for (let size = 0; ;) {
      const { done, value } = await read();

      if (done) {
        return true;
      }

      size += value.byteLength;

      if (size > limit) {
        await reader.cancel();
        return false;
      }

      take(value);
    }
  } finally {
    signal?.removeEventListener("abort", abort);
  }
}

/**
 * Sends bytes stored in pieces as a stream that reads one piece each time its reader wants more.
 *
 * @param {(index: number) => Promise<Uint8Array | undefined>} readPiece Reads a piece, undefined past the last one.
 * @returns {Promise<ReadableStream<Uint8Array> | undefined>} The stream, or undefined when there is no first piece, decided before any byte is sent.
 */
export async function piecesStream(readPiece) {
  const first = await readPiece(0);

  if (first === undefined) {
    return undefined;
  }

  let next = 0;

  return new ReadableStream({
    async pull(controller) {
      try {
        const piece = next === 0 ? first : await readPiece(next);
        next++;

        if (piece === undefined) {
          controller.close();
        } else {
          controller.enqueue(piece);
        }
      } catch (error) {
        controller.error(error);
      }
    },
  }, { highWaterMark: 0 });
}

/**
 * Passes a stream on and calls back once it ends, whether it finished, its reader cancelled it or
 * it failed.
 *
 * @param {ReadableStream<Uint8Array>} stream The stream.
 * @param {() => void} release Called once when the stream ends.
 * @returns {{stream: ReadableStream<Uint8Array>, abort: (reason?: any) => void}} The stream to send, and how to end it early, which also calls back.
 */
export function releaseWhenDone(stream, release) {
  const reader = stream.getReader();
  let ended = false;
  let wrapper;

  const end = () => {
    if (!ended) {
      ended = true;
      release();
    }
  };

  const passed = new ReadableStream({
    start(controller) {
      wrapper = controller;
    },
    async pull(controller) {
      try {
        const { done, value } = await reader.read();

        // An abort meanwhile already ended the stream, which then takes nothing more.
        if (ended) {
          return;
        }

        if (done) {
          end();
          controller.close();
        } else {
          controller.enqueue(value);
        }
      } catch (error) {
        end();
        controller.error(error);
      }
    },
    async cancel(reason) {
      end();
      await reader.cancel(reason);
    },
  }, { highWaterMark: 0 });

  const abort = (reason = new Error("the download took too long")) => {
    if (ended) {
      return;
    }

    end();
    wrapper.error(reason);
    reader.cancel(reason).catch(() => {});
  };

  return { stream: passed, abort };
}

/**
 * The answer for a download the relay cannot send now. Released games show its error as it is.
 *
 * @param {typeof DOWNLOAD_LIMITS} limits The limits, which name when to try again.
 * @returns {{status: number, body: object, headers: object}} The answer.
 */
export function downloadBusy(limits = DOWNLOAD_LIMITS) {
  return {
    status: 503,
    body: { error: "the relay is sending other downloads, try again in a moment", code: "busy" },
    headers: { "Retry-After": String(limits.retryAfterSeconds) },
  };
}

/**
 * Lets only a few downloads run at once, at most one per address, in memory. A download waits a
 * while for its turn before it is refused.
 */
export class DownloadGate {
  /**
   * Creates the gate with no downloads running.
   *
   * @param {typeof DOWNLOAD_LIMITS} [limits] The limits.
   * @param {{burst: number, refillMs: number}} [rate] How many downloads one address may start.
   * @param {() => number} [clock] The clock, which tests change.
   */
  constructor(limits = DOWNLOAD_LIMITS, rate = RATE_LIMITS.downloads, clock = () => Date.now()) {
    this.limits = limits;
    this.clock = clock;
    this.rates = new RateLimiter(rate, clock);
    this.active = new Set();
    this.waiting = [];
  }

  /**
   * Takes a slot for a download, waiting for one when all are taken. The slot is taken before the
   * download reads anything, so downloads that start together cannot pass the limit while they
   * wait for storage.
   *
   * @param {string | null | undefined} address The address the request came from; without one only the total counts.
   * @returns {Promise<{release: () => void, hold: (stream: ReadableStream<Uint8Array>) => ReadableStream<Uint8Array>} | {refusal: {status: number, body: object, headers: object}}>} The slot, given back by release or once the held stream ends; or the answer when the address starts too many downloads or no slot came in time.
   */
  enter(address) {
    if (!this.rates.take(address)) {
      return Promise.resolve({ refusal: downloadBusy(this.limits) });
    }

    this.reclaim();

    return new Promise((resolve) => {
      const waiter = { address: address || null, resolve, timer: null };
      this.waiting.push(waiter);
      this.pump();

      if (!this.waiting.includes(waiter)) {
        return;
      }

      if (this.waiting.length > this.limits.maxWaiting) {
        this.waiting.splice(this.waiting.indexOf(waiter), 1);
        resolve({ refusal: downloadBusy(this.limits) });
        return;
      }

      waiter.timer = setTimeout(() => {
        this.reclaim();

        if (this.waiting.includes(waiter)) {
          this.waiting.splice(this.waiting.indexOf(waiter), 1);
          resolve({ refusal: downloadBusy(this.limits) });
        }
      }, this.limits.maxWaitMs);
    });
  }

  /**
   * Hands free slots to the waiting requests, oldest first, skipping those whose address has its
   * own slot taken.
   */
  pump() {
    for (const waiter of [...this.waiting]) {
      if (!this.fits(waiter.address)) {
        continue;
      }

      this.waiting.splice(this.waiting.indexOf(waiter), 1);
      clearTimeout(waiter.timer);
      waiter.resolve(this.grant(waiter.address));
    }
  }

  /**
   * Tells whether a download from an address may start now.
   *
   * @param {string | null} address The address, null for none.
   * @returns {boolean} Whether it may.
   */
  fits(address) {
    if (this.active.size >= this.limits.maxActive) {
      return false;
    }

    return !address || [...this.active].filter((slot) => slot.address === address).length < this.limits.perAddress;
  }

  /**
   * Takes a slot for an address.
   *
   * @param {string | null} address The address, null for none.
   * @returns {{release: () => void, hold: (stream: ReadableStream<Uint8Array>) => ReadableStream<Uint8Array>}} The slot.
   */
  grant(address) {
    const slot = { address, at: this.clock(), abort: null };
    this.active.add(slot);

    const release = () => this.free(slot);

    const hold = (stream) => {
      const held = releaseWhenDone(stream, release);
      slot.abort = held.abort;
      return held.stream;
    };

    return { release, hold };
  }

  /**
   * Gives a slot back, once, and lets the next waiting request in.
   *
   * @param {object} slot The slot.
   */
  free(slot) {
    if (this.active.delete(slot)) {
      this.pump();
    }
  }

  /**
   * Ends the downloads that held their slot longer than they may, and gives their slots back.
   */
  reclaim() {
    const now = this.clock();

    for (const slot of [...this.active]) {
      if (now - slot.at >= this.limits.maxHoldMs) {
        slot.abort?.();
        this.free(slot);
      }
    }
  }
}
