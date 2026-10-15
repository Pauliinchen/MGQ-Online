//----------------------------------------------------------------
//  served_load.mjs
//
//  Changelog:
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

// Plays many served co-op battles at once through a running relay and its battle server, as
// players would: a few worlds, two players per battle, each player with an address of its own
// (X-Forwarded-For, which the relay reads from its own machine only), a think time before every
// command, and the time from both players' commands to the first event of their turn measured.
// make_setups.rb writes the setups. Run it on the relay's machine:
//   node served_load.mjs <relay address> <setups.json> <worlds> <battles per world> <think s>
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";

const [relay, setupFile, worldCount, perWorld, thinkText] = process.argv.slice(2);
const setups = JSON.parse(readFileSync(setupFile, "utf8"));
const think = Number(thinkText) * 1000;
const auth = "ab".repeat(32);
const ws = relay.replace(/^http/, "ws");
const keyOf = (number) => number.toString(16).padStart(32, "e");
const game = (number) => ({ "X-MGQ-Features": "raid,keys", "X-MGQ-Version": "0.0.0-dev", "X-MGQ-Player": keyOf(number), "X-MGQ-Auth": auth,
                            "X-Forwarded-For": `10.${(number >> 16) & 255}.${(number >> 8) & 255}.${number & 255}` });
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const encoder = new TextEncoder();
const decoder = new TextDecoder();
const toServer = (text) => Uint8Array.from([250, ...encoder.encode(text)]);
const started = Date.now();
const latencies = [];
const results = {};

/**
 * Opens a WebSocket and keeps what comes in, with the time each binary frame arrived.
 *
 * @param {string} address The address.
 * @param {object} headers The headers.
 * @returns {Promise<{socket: WebSocket, closed: Promise<object>, arrived: WeakMap<ArrayBuffer, number>, next: () => Promise<any>}>} The connection.
 */
async function open(address, headers) {
  const socket = new WebSocket(address, { headers });
  socket.binaryType = "arraybuffer";
  const inbox = [];
  const waiting = [];
  const arrived = new WeakMap();
  socket.addEventListener("message", (event) => { if (typeof event.data === "object") arrived.set(event.data, Date.now()); waiting.length > 0 ? waiting.shift()(event.data) : inbox.push(event.data); });
  const closed = new Promise((resolve) => socket.addEventListener("close", (event) => resolve({ code: event.code, reason: event.reason })));
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  return { socket, closed, arrived, next: () => (inbox.length > 0 ? Promise.resolve(inbox.shift()) : new Promise((resolve) => waiting.push(resolve))) };
}

/**
 * Starts one battle for two players of a world and plays it to its end as their games would.
 *
 * @param {string} world The world.
 * @param {number} base The number the world's player keys count from, see keyOf.
 * @param {{battle: string, seats: number[], setup: string, ready: string, commands: string}} setup The battle's setup, see make_setups.rb.
 */
async function playBattle(world, base, setup) {
  const [first, second] = setup.seats.map((seat) => base + seat + 1);
  const start = await fetch(`${relay}/v1/worlds/${world}/battles`, {
    method: "POST", headers: game(first), body: JSON.stringify({ battle: setup.battle, seats: setup.seats, setup: setup.setup }),
  });

  if (start.status !== 201) {
    results[`start ${start.status}`] = (results[`start ${start.status}`] ?? 0) + 1;
    return;
  }

  const began = Date.now();
  const phase = { sent: new Set(), at: 0 };
  await Promise.all([first, second].map(async (number, index) => {
    const channel = await open(`${ws}/v1/worlds/${world}/battles/${setup.battle}`, game(number));
    const seat = setup.seats[index];
    await channel.next();

    for (;;) {
      const frame = await Promise.race([channel.next(), channel.closed.then(() => null)]);

      if (frame === null || typeof frame === "string") {
        const end = frame ?? "closed";
        if (index === 0) {
          results[end] = (results[end] ?? 0) + 1;
          console.log(`${world.slice(0, 6)} ${setup.battle}: ${end} after ${Math.round((Date.now() - began) / 1000)} s`);
        }
        return;
      }

      const text = decoder.decode(new Uint8Array(frame).subarray(1));
      const kind = /battle=([^\n]*)/.exec(text)?.[1] ?? "?";

      if (index === 0 && kind !== "waiting" && phase.sent.size === 2 && (channel.arrived.get(frame) ?? 0) >= phase.at) {
        latencies.push(channel.arrived.get(frame) - phase.at);
        phase.sent.clear();
      }

      if (kind === "ready") {
        channel.socket.send(toServer(setup.ready));
      } else if (kind === "waiting" && text.split("\n\n")[1].split(",").map(Number).includes(seat)) {
        await sleep(think * (0.5 + Math.random()));
        channel.socket.send(toServer(setup.commands));
        phase.sent.add(seat);
        phase.at = Date.now();
      }
    }
  }));
}

const worlds = [];

for (let w = 0; w < Number(worldCount); w++) {
  const base = (Math.floor(Date.now() / 1000) % 1000 + 1) * 10000 + w * 1000;
  const world = createHash("sha256").update(`load ${Date.now()} ${w}`).digest("hex").slice(0, 32);
  const made = await fetch(`${relay}/v1/worlds`, {
    method: "POST", headers: game(base + 1),
    body: JSON.stringify({ id: world, name: `Load ${w + 1}`, seats: 32, player: keyOf(base + 1), playerName: "Player 1",
                           authHash: createHash("sha256").update(auth).digest("hex"), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) } }),
  });

  if (made.status !== 201) {
    throw new Error(`world ${w + 1}: ${made.status} ${await made.text()}`);
  }

  const rooms = [];

  for (let p = 0; p < Number(perWorld) * 2; p++) {
    const room = await open(`${ws}/v1/world/${world}?name=Player%20${p + 1}`, game(base + p + 1));
    const seat = Number(String(await room.next()).split(" ")[1]);

    if (seat !== p) {
      throw new Error(`world ${w + 1}: player ${p + 1} got seat ${seat}`);
    }

    rooms.push(room);
  }

  worlds.push({ world, base, rooms });
}

console.log(`${worlds.length} worlds with ${Number(perWorld) * 2} players each ready after ${Math.round((Date.now() - started) / 1000)} s; starting the battles`);
const battlesStarted = Date.now();
await Promise.all(worlds.flatMap(({ world, base }) => setups.slice(0, Number(perWorld)).map((setup, index) => sleep(index * 300).then(() => playBattle(world, base, setup)))));
latencies.sort((a, b) => a - b);
const at = (share) => latencies[Math.min(latencies.length - 1, Math.floor(latencies.length * share))] ?? 0;
console.log(`all battles over after ${Math.round((Date.now() - battlesStarted) / 1000)} s: ${JSON.stringify(results)}`);
console.log(`commands to the server's next frame: ${latencies.length} turns, median ${at(0.5)} ms, 95% ${at(0.95)} ms, slowest ${at(1)} ms`);

for (const { rooms } of worlds) {
  rooms.forEach((room) => room.socket.close());
}
