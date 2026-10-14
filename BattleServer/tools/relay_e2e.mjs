//----------------------------------------------------------------
//  relay_e2e.mjs
//
//  Changelog:
//      Paulinchen  2026-10-15: Created
//
//----------------------------------------------------------------

// Plays a served co-op battle through a running relay and its battle server, as two games would:
// makes a world, seats two players in its room, starts the battle with a setup make_setup.rb wrote
// and answers the server as guests do, with ready and attacks whenever it waits for them.
//   node relay_e2e.mjs <relay address, such as http://127.0.0.1:8080> <make_setup.rb's JSON file>

import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";

const [relay, setupFile] = process.argv.slice(2);
const { setup, ready, commands } = JSON.parse(readFileSync(setupFile, "utf8"));
const world = createHash("sha256").update(`e2e ${Date.now()}`).digest("hex").slice(0, 32);
const auth = "ab".repeat(32);
const game = { "X-MGQ-Features": "raid", "X-MGQ-Version": "0.0.0-dev" };
const keyOf = (number) => number.toString(16).padStart(32, "e");
const ws = relay.replace(/^http/, "ws");
const battle = process.env.BATTLE_ID ?? "e2e";
const started = Date.now();

/**
 * Opens a WebSocket and keeps what comes in.
 *
 * @param {string} address The address.
 * @param {object} headers The headers.
 * @returns {Promise<{socket: WebSocket, closed: Promise<object>, next: () => Promise<any>}>} The connection.
 */
async function open(address, headers) {
  const socket = new WebSocket(address, { headers });
  socket.binaryType = "arraybuffer";
  const inbox = [];
  const waiting = [];
  socket.addEventListener("message", (event) => (waiting.length > 0 ? waiting.shift()(event.data) : inbox.push(event.data)));
  const closed = new Promise((resolve) => socket.addEventListener("close", (event) => resolve({ code: event.code, reason: event.reason })));
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  return { socket, closed, next: () => (inbox.length > 0 ? Promise.resolve(inbox.shift()) : new Promise((resolve) => waiting.push(resolve))) };
}

const made = await fetch(`${relay}/v1/worlds`, {
  method: "POST",
  headers: game,
  body: JSON.stringify({ id: world, name: "Battle e2e", seats: 8, player: keyOf(1), playerName: "Player 1",
                         authHash: createHash("sha256").update(auth).digest("hex"), lock: { salt: "12".repeat(16), iterations: 200_000, box: "ab".repeat(40) } }),
});
console.log(`world: ${made.status}`);

const players = [];
for (const number of [1, 2]) {
  const room = await open(`${ws}/v1/world/${world}?name=Player%20${number}`, { ...game, "X-MGQ-Player": keyOf(number), "X-MGQ-Auth": auth });
  const seat = Number(String(await room.next()).split(" ")[1]);
  players.push({ number, room, seat });
}
console.log(`seats: ${players.map((player) => player.seat).join(", ")}`);

const start = await fetch(`${relay}/v1/worlds/${world}/battles`, {
  method: "POST",
  headers: { ...game, "X-MGQ-Player": keyOf(1), "X-MGQ-Auth": auth },
  body: JSON.stringify({ battle, seats: players.map((player) => player.seat), setup }),
});
console.log(`battle: ${start.status} ${await start.text()} after ${Date.now() - started} ms`);

const counts = {};
const encoder = new TextEncoder();
const decoder = new TextDecoder();
const toServer = (text) => Uint8Array.from([250, ...encoder.encode(text)]);
const channels = await Promise.all(players.map(async (player) => {
  const channel = await open(`${ws}/v1/worlds/${world}/battles/${battle}`, { ...game, "X-MGQ-Player": keyOf(player.number), "X-MGQ-Auth": auth });
  console.log(`player ${player.number} on the channel: ${await channel.next()}`);
  return { player, channel };
}));

await Promise.all(channels.map(async ({ player, channel }) => {
  for (;;) {
    const frame = await Promise.race([channel.next(), channel.closed.then(() => null)]);

    if (frame === null || typeof frame === "string") {
      console.log(`player ${player.number}: ${frame ?? "closed"} after ${Date.now() - started} ms`);
      return;
    }

    const text = decoder.decode(new Uint8Array(frame).subarray(1));
    const kind = /battle=([^\n]*)/.exec(text)?.[1] ?? "?";
    counts[kind] = (counts[kind] ?? 0) + 1;

    if (kind === "ready") {
      channel.socket.send(toServer(ready));
    } else if (kind === "waiting" && text.split("\n\n")[1].split(",").map(Number).includes(player.seat)) {
      channel.socket.send(toServer(commands));
    }
  }
}));
console.log(`the server sent: ${Object.entries(counts).map(([kind, count]) => `${kind} x${count}`).join(", ")}`);
for (const player of players) {
  player.room.socket.close();
}
