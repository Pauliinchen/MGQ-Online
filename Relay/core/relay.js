//----------------------------------------------------------------
//  relay.js
//
//  Changelog:
//      Paulinchen  2026-09-29: Took a world room's seats from the directory, and a game's player key, name and auth key from its request
//                            - Added world rooms, which seat up to 32 games and pass each message to one or all of the others
//                            - Created
//
//----------------------------------------------------------------

// The relay's rules, the same on every server: which requests it takes, who may join a room, how
// fast and how large messages may be, and when a room ends. It keeps no state and touches no
// socket, so a thin layer per platform (Cloudflare, Node) can store the peers its own way.
//
// A room pairs one host with one guest, for a PvP battle. A world room seats several games that
// play in the same world; each gets a seat number, which the relay puts in front of every message
// it passes on, since it cannot read who sent what.

/**
 * The protocol version the relay speaks, the first part of every room's path.
 */
export const VERSION = "v1";

/**
 * The two sides of a room.
 */
export const ROLES = ["host", "guest"];

/**
 * What the relay sends as text once both sides are in the room.
 */
export const PAIRED = "paired";

/**
 * What a client may send as text to keep an idle connection open, and what it gets back.
 */
export const PING = "ping";

/**
 * The answer to PING.
 */
export const PONG = "pong";

/**
 * What a world room tells a game that took a seat: its own seat, then the seats already taken.
 */
export const SEAT = "seat";

/**
 * What a world room tells the others when a game took a seat.
 */
export const IN = "in";

/**
 * What a world room tells the others when a game left its seat.
 */
export const OUT = "out";

/**
 * The target seat of a world message meant for every other game in the room.
 */
export const EVERYONE = 255;

/**
 * How many games a world room may seat, as its world in the directory says.
 */
export const WORLD_SEATS = Object.freeze({ min: 2, max: 32 });

/**
 * The limits every room keeps.
 */
export const LIMITS = Object.freeze({
  // A frame of the mod is at most 256 KB, plus encryption.
  maxMessageBytes: 512 * 1024,
  // Messages a peer may send per second over time, and at once after a quiet spell.
  messagesPerSecond: 60,
  burst: 240,
  // How long a host may wait alone, and how long a room may last at all.
  hostWaitMs: 30 * 60 * 1000,
  roomLifetimeMs: 2 * 60 * 60 * 1000,
  // How long one connection to a world room may last. Games come and go there, so each connection
  // ends on its own, and the game connects again.
  worldConnectionMs: 2 * 60 * 60 * 1000,
});

/**
 * The close codes the relay ends a connection with, from the range WebSocket leaves to applications.
 */
export const CLOSE = Object.freeze({
  normal: 1000,
  badRequest: 4000,
  roleTaken: 4001,
  tooLarge: 4002,
  tooFast: 4003,
  waitedTooLong: 4004,
  roomExpired: 4005,
  peerLeft: 4006,
  worldFull: 4007,
  connectionExpired: 4008,
  removed: 4009,
  worldDeleted: 4010,
});

/**
 * A room id, 32 lowercase hexadecimal characters: the start of a hash the client made from its
 * join code, never the join code itself.
 */
const ROOM_ID = /^[0-9a-f]{32}$/;

/**
 * A player's key, 32 lowercase hexadecimal characters.
 */
const PLAYER_KEY = /^[0-9a-f]{32}$/;

/**
 * An auth key made from a world's token, 64 lowercase hexadecimal characters.
 */
const AUTH_KEY = /^[0-9a-f]{64}$/;

/**
 * Longest player name a world room passes on to the directory.
 */
const MAX_PLAYER_NAME = 32;

/**
 * Reads the room a request asks for: a room with its role, or a world room with the player's key,
 * name and auth key.
 *
 * @param {URL} url The request's address, such as /v1/room/<room id>?role=host or /v1/world/<world id>?player=…&name=…&auth=….
 * @returns {{kind: "room", roomId: string, role: string} | {kind: "world", roomId: string, player: string, name: string, auth: string} | {error: string}} The room, or why the request is refused.
 */
export function parseRoute(url) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);

  if (parts.length !== 3 || parts[0] !== VERSION || (parts[1] !== "room" && parts[1] !== "world")) {
    return { error: `the address must be /${VERSION}/room/<room id> or /${VERSION}/world/<room id>` };
  }

  if (!ROOM_ID.test(parts[2])) {
    return { error: "the room id must be 32 lowercase hexadecimal characters" };
  }

  if (parts[1] === "world") {
    const player = url.searchParams.get("player") ?? "";
    const auth = url.searchParams.get("auth") ?? "";
    const name = (url.searchParams.get("name") ?? "").replace(/[\u0000-\u001f\u007f]/g, "").trim();

    if (!PLAYER_KEY.test(player) || !AUTH_KEY.test(auth)) {
      return { error: "a world room needs the player's key and an auth key" };
    }

    if (name.length === 0 || [...name].length > MAX_PLAYER_NAME) {
      return { error: `the player's name must be 1 to ${MAX_PLAYER_NAME} characters` };
    }

    return { kind: "world", roomId: parts[2], player, name, auth };
  }

  const role = url.searchParams.get("role");

  if (!ROLES.includes(role)) {
    return { error: "the role must be host or guest" };
  }

  return { kind: "room", roomId: parts[2], role };
}

/**
 * Decides whether a peer may join a room.
 *
 * @param {string[]} present The roles of the peers already in the room.
 * @param {string} role The role that asks to join.
 * @returns {{code: number, reason: string} | null} Why it may not, or null when it may.
 */
export function admit(present, role) {
  return present.includes(role) ? { code: CLOSE.roleTaken, reason: `the room has a ${role} already` } : null;
}

/**
 * Makes the record a peer carries while it is in a room.
 *
 * @param {string} role The peer's role.
 * @param {number} now The current time in milliseconds.
 * @param {typeof LIMITS} [limits] The limits.
 * @returns {{role: string, joinedAt: number, allowance: number, refilledAt: number}} The record, with a full message allowance.
 */
export function newPeer(role, now, limits = LIMITS) {
  return { role, joinedAt: now, allowance: limits.burst, refilledAt: now };
}

/**
 * Checks a message a peer sent against its size and its allowance, which refills over time.
 *
 * @param {{role: string, joinedAt: number, allowance: number, refilledAt: number}} peer The peer's record.
 * @param {number} bytes The message's size.
 * @param {number} now The current time in milliseconds.
 * @param {typeof LIMITS} [limits] The limits.
 * @returns {{peer: object, refusal: {code: number, reason: string} | null}} The peer's new record, and why the message is refused, if it is.
 */
export function takeMessage(peer, bytes, now, limits = LIMITS) {
  if (bytes > limits.maxMessageBytes) {
    return { peer, refusal: { code: CLOSE.tooLarge, reason: `messages are at most ${limits.maxMessageBytes} bytes` } };
  }

  const refilled = Math.min(limits.burst, peer.allowance + ((now - peer.refilledAt) / 1000) * limits.messagesPerSecond);

  if (refilled < 1) {
    return { peer: { ...peer, allowance: refilled, refilledAt: now }, refusal: { code: CLOSE.tooFast, reason: "too many messages" } };
  }

  return { peer: { ...peer, allowance: refilled - 1, refilledAt: now }, refusal: null };
}

/**
 * Finds the peers whose time is up: a host that waited alone too long, or everyone in a room that
 * lasted too long.
 *
 * @param {{role: string, joinedAt: number}[]} peers The records of the peers in the room.
 * @param {number} now The current time in milliseconds.
 * @param {typeof LIMITS} [limits] The limits.
 * @returns {{index: number, code: number, reason: string}[]} The peers to close, by their place in peers.
 */
export function overdue(peers, now, limits = LIMITS) {
  if (peers.length === 0) {
    return [];
  }

  const openedAt = Math.min(...peers.map((peer) => peer.joinedAt));

  if (now - openedAt >= limits.roomLifetimeMs) {
    return peers.map((_, index) => ({ index, code: CLOSE.roomExpired, reason: "the room lasted too long" }));
  }

  if (peers.length === 1 && peers[0].role === "host" && now - peers[0].joinedAt >= limits.hostWaitMs) {
    return [{ index: 0, code: CLOSE.waitedTooLong, reason: "nobody joined in time" }];
  }

  return [];
}

/**
 * Tells when the relay has to look at a room's deadlines next.
 *
 * @param {{role: string, joinedAt: number}[]} peers The records of the peers in the room.
 * @param {typeof LIMITS} [limits] The limits.
 * @returns {number | null} The time in milliseconds of the next deadline, or null for an empty room.
 */
export function nextDeadline(peers, limits = LIMITS) {
  if (peers.length === 0) {
    return null;
  }

  const roomEnds = Math.min(...peers.map((peer) => peer.joinedAt)) + limits.roomLifetimeMs;

  return peers.length === 1 && peers[0].role === "host" ? Math.min(roomEnds, peers[0].joinedAt + limits.hostWaitMs) : roomEnds;
}

/**
 * Finds the seat a game takes in a world room: the lowest one free.
 *
 * @param {{seat: number}[]} peers The records of the games in the room.
 * @param {number} capacity The room's seats.
 * @returns {{seat: number, refusal: null} | {seat: null, refusal: {code: number, reason: string}}} The seat, or why the game may not join.
 */
export function takeSeat(peers, capacity) {
  const taken = new Set(peers.map((peer) => peer.seat));

  for (let seat = 0; seat < capacity; seat++) {
    if (!taken.has(seat)) {
      return { seat, refusal: null };
    }
  }

  return { seat: null, refusal: { code: CLOSE.worldFull, reason: "the world is full" } };
}

/**
 * Makes the record a game carries while it holds a seat in a world room.
 *
 * @param {number} seat The game's seat.
 * @param {{player: string, name: string}} who The player's id, as the directory made it, and name.
 * @param {number} now The current time in milliseconds.
 * @param {typeof LIMITS} [limits] The limits.
 * @returns {{seat: number, player: string, name: string, joinedAt: number, allowance: number, refilledAt: number}} The record, with a full message allowance.
 */
export function newWorldPeer(seat, who, now, limits = LIMITS) {
  return { seat, player: who.player, name: who.name, joinedAt: now, allowance: limits.burst, refilledAt: now };
}

/**
 * Lists the players in a world room, as the directory takes them.
 *
 * @param {{player: string, name: string}[]} peers The records of the games in the room.
 * @returns {{player: string, name: string}[]} The players.
 */
export function presenceOf(peers) {
  return peers.map((peer) => ({ player: peer.player, name: peer.name }));
}

/**
 * Writes what a game is told once it took its seat.
 *
 * @param {number} seat The game's seat.
 * @param {number[]} others The seats of the games already in the room, in any order.
 * @returns {string} The text, such as "seat 2 0 1", with the others in ascending order.
 */
export function seatText(seat, others) {
  return [SEAT, seat, ...[...others].sort((a, b) => a - b)].join(" ");
}

/**
 * Writes what the other games are told when a game took or left a seat.
 *
 * @param {string} change IN or OUT.
 * @param {number} seat The seat.
 * @returns {string} The text, such as "in 2".
 */
export function seatChangeText(change, seat) {
  return `${change} ${seat}`;
}

/**
 * Reads where a game's world message goes, and turns it into what the others receive: the same
 * bytes with the sender's seat in place of the target.
 *
 * @param {number} sender The sending game's seat.
 * @param {Uint8Array} message The message: the target seat, or EVERYONE, then the payload.
 * @returns {{target: number | null, forwarded: Uint8Array, refusal: null} | {refusal: {code: number, reason: string}}} The target seat, null for everyone, and the message to pass on; or why the message is refused.
 */
export function routeWorldMessage(sender, message) {
  if (message.length === 0) {
    return { refusal: { code: CLOSE.badRequest, reason: "a world message starts with its target seat" } };
  }

  const forwarded = Uint8Array.from(message);
  forwarded[0] = sender;
  return { target: message[0] === EVERYONE ? null : message[0], forwarded, refusal: null };
}

/**
 * Finds the games in a world room whose connection lasted too long.
 *
 * @param {{joinedAt: number}[]} peers The records of the games in the room.
 * @param {number} now The current time in milliseconds.
 * @param {typeof LIMITS} [limits] The limits.
 * @returns {{index: number, code: number, reason: string}[]} The games to close, by their place in peers.
 */
export function worldOverdue(peers, now, limits = LIMITS) {
  return peers
    .map((peer, index) => ({ index, due: now - peer.joinedAt >= limits.worldConnectionMs }))
    .filter((entry) => entry.due)
    .map(({ index }) => ({ index, code: CLOSE.connectionExpired, reason: "the connection lasted too long" }));
}

/**
 * Tells when the relay has to look at a world room's deadlines next.
 *
 * @param {{joinedAt: number}[]} peers The records of the games in the room.
 * @param {typeof LIMITS} [limits] The limits.
 * @returns {number | null} The time in milliseconds of the next deadline, or null for an empty room.
 */
export function nextWorldDeadline(peers, limits = LIMITS) {
  return peers.length === 0 ? null : Math.min(...peers.map((peer) => peer.joinedAt)) + limits.worldConnectionMs;
}
