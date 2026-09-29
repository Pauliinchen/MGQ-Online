//----------------------------------------------------------------
//  server.js
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

// The relay as a plain Node server, for a rented machine behind a TLS proxy such as Caddy. It keeps
// its rooms in memory and follows the core's rules, so it behaves like the Cloudflare relay.

import http from "node:http";
import { pathToFileURL } from "node:url";
import { WebSocketServer } from "ws";
import { CLOSE, LIMITS, PAIRED, PING, PONG, admit, newPeer, overdue, parseRoute, takeMessage } from "../core/relay.js";

/**
 * How often the server looks for rooms whose time is up.
 */
const CHECK_EVERY_MS = 60 * 1000;

/**
 * Creates a relay server, not yet listening.
 *
 * @param {{limits?: typeof LIMITS, clock?: () => number, checkEveryMs?: number}} [options] Limits, clock and check interval, which tests change.
 * @returns {{server: http.Server, check: () => void, stop: () => Promise<void>}} The HTTP server to listen with, a look at the deadlines, and a way to stop everything.
 */
export function createRelay({ limits = LIMITS, clock = Date.now, checkEveryMs = CHECK_EVERY_MS } = {}) {
  /** @type {Map<string, {socket: import("ws").WebSocket, record: object}[]>} */
  const rooms = new Map();
  // Larger messages than the core allows reach it and get its close code; far larger ones never
  // reach memory at all.
  const sockets = new WebSocketServer({ noServer: true, maxPayload: limits.maxMessageBytes * 2 });
  const server = http.createServer((_request, response) => {
    response.writeHead(426, { "Content-Type": "text/plain" });
    response.end("the relay only takes WebSockets");
  });

  server.on("upgrade", (request, socket, head) => {
    const route = parseRoute(new URL(request.url, "http://relay"));
    const refusal = "error" in route ? { status: 400, reason: route.error } : conflict(route);

    if (refusal) {
      socket.end(`HTTP/1.1 ${refusal.status} Refused\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n${refusal.reason}`);
      return;
    }

    sockets.handleUpgrade(request, socket, head, (webSocket) => join(route, webSocket));
  });

  /**
   * Tells why a peer may not join its room.
   *
   * @param {{roomId: string, role: string}} route The room and role.
   * @returns {{status: number, reason: string} | null} The HTTP status and reason, or null when it may.
   */
  function conflict(route) {
    const refusal = admit((rooms.get(route.roomId) ?? []).map((peer) => peer.record.role), route.role);
    return refusal ? { status: 409, reason: refusal.reason } : null;
  }

  /**
   * Puts a peer into its room and passes its messages on.
   *
   * @param {{roomId: string, role: string}} route The room and role.
   * @param {import("ws").WebSocket} socket The peer's WebSocket.
   */
  function join(route, socket) {
    // Another peer of the same role may have joined while this one's handshake ran.
    if (conflict(route)) {
      socket.close(CLOSE.roleTaken, `the room has a ${route.role} already`);
      return;
    }

    const peers = rooms.get(route.roomId) ?? [];
    const peer = { socket, record: newPeer(route.role, clock(), limits) };
    rooms.set(route.roomId, peers);
    peers.push(peer);

    if (peers.length === 2) {
      for (const each of peers) {
        each.socket.send(PAIRED);
      }
    }

    socket.on("message", (data, isBinary) => {
      if (!isBinary) {
        if (data.toString() === PING) {
          socket.send(PONG);
        } else {
          socket.close(CLOSE.badRequest, "only binary messages are passed on");
        }
        return;
      }

      const { peer: record, refusal } = takeMessage(peer.record, data.length, clock(), limits);
      peer.record = record;

      if (refusal) {
        socket.close(refusal.code, refusal.reason);
        return;
      }

      peers.find((other) => other !== peer)?.socket.send(data, { binary: true });
    });

    socket.on("close", () => {
      peers.splice(peers.indexOf(peer), 1);

      for (const other of peers) {
        other.socket.close(CLOSE.peerLeft, "the other side left");
      }

      if (peers.length === 0) {
        rooms.delete(route.roomId);
      }
    });

    socket.on("error", () => socket.terminate());
  }

  /**
   * Closes the peers whose time is up, in every room.
   */
  function check() {
    for (const peers of rooms.values()) {
      for (const { index, code, reason } of overdue(peers.map((peer) => peer.record), clock(), limits)) {
        peers[index].socket.close(code, reason);
      }
    }
  }

  const timer = setInterval(check, checkEveryMs);
  timer.unref();

  /**
   * Closes every connection and the server.
   *
   * @returns {Promise<void>} Resolves once the server stopped.
   */
  function stop() {
    clearInterval(timer);

    for (const socket of sockets.clients) {
      socket.terminate();
    }

    return new Promise((resolve) => server.close(() => resolve()));
  }

  return { server, check, stop };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  // Behind a TLS proxy the relay only needs to listen locally.
  const port = Number(process.env.PORT ?? 8080);
  const host = process.env.HOST ?? "127.0.0.1";

  createRelay().server.listen(port, host, () => console.log(`relay listening on ${host}:${port}`));
}
