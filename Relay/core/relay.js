//----------------------------------------------------------------
//  relay.js
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

// The relay's rules, the same on every server: which requests it takes, who may join a room, how
// fast and how large messages may be, and when a room ends. It keeps no state and touches no
// socket, so a thin layer per platform (Cloudflare, Node) can store the peers its own way.

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
 * The limits every room keeps.
 */
export const LIMITS = Object.freeze({
  // A frame of the Multiplayer mod is at most 256 KB, plus encryption.
  maxMessageBytes: 512 * 1024,
  // Messages a peer may send per second over time, and at once after a quiet spell.
  messagesPerSecond: 60,
  burst: 240,
  // How long a host may wait alone, and how long a room may last at all.
  hostWaitMs: 30 * 60 * 1000,
  roomLifetimeMs: 2 * 60 * 60 * 1000,
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
});

/**
 * A room id, 32 lowercase hexadecimal characters: the start of a hash the client made from its
 * join code, never the join code itself.
 */
const ROOM_ID = /^[0-9a-f]{32}$/;

/**
 * Reads the room and role a request asks for.
 *
 * @param {URL} url The request's address, such as /v1/room/<room id>?role=host.
 * @returns {{roomId: string, role: string} | {error: string}} The room and role, or why the request is refused.
 */
export function parseRoute(url) {
  const parts = url.pathname.split("/").filter((part) => part.length > 0);

  if (parts.length !== 3 || parts[0] !== VERSION || parts[1] !== "room") {
    return { error: `the address must be /${VERSION}/room/<room id>` };
  }

  if (!ROOM_ID.test(parts[2])) {
    return { error: "the room id must be 32 lowercase hexadecimal characters" };
  }

  const role = url.searchParams.get("role");

  if (!ROLES.includes(role)) {
    return { error: "the role must be host or guest" };
  }

  return { roomId: parts[2], role };
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
