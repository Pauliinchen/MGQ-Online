# Relay

Passes the Multiplayer mod's frames between two games that cannot reach each other directly, for example when one player's connection has no public IPv4 of its own (DS-Lite, CGNAT) and the other has no IPv6. The games try each other directly first; the relay is the fallback.

The relay never sees a battle: the games encrypt every frame with a key derived from the join code, which the relay never gets. It sees a room id, message sizes and timing, stores nothing and keeps no content.

## Layout

```
core/relay.js          the rules: routes, pairing, size and rate limits, deadlines (no platform code)
core/relay.test.js     tests of the rules
cloudflare/worker.js   the relay on Cloudflare Workers, one Durable Object per room
cloudflare/wrangler.toml
node/server.js         the relay as a plain Node server, for a rented machine
node/server.test.js    tests of the Node server over real WebSockets
```

Both servers follow the same rules from `core/`, so the games cannot tell them apart.

## Protocol (v1)

- **Connect:** `wss://<relay>/v1/room/<room id>?role=host` or `?role=guest`. The room id is 32 lowercase hexadecimal characters, the start of a hash of the join code's token.
- **Pairing:** one host and one guest per room. Another peer of a taken role is refused with HTTP 409 before its WebSocket opens.
- **Messages:** binary messages go to the other peer unchanged. Once both are in, the relay sends each the text `paired`. The text `ping` is answered with `pong`, for keeping an idle connection open; any other text closes the connection.
- **Limits:** at most 512 KB per message, 60 messages per second over time (bursts of 240), a host waits alone at most 30 minutes, a room lasts at most 2 hours.
- **Close codes:** 4000 bad request, 4001 role taken, 4002 message too large, 4003 too many messages, 4004 nobody joined in time, 4005 the room lasted too long, 4006 the other side left.

## Tests

You need Node.js 22 or later.

```powershell
cd Relay
npm install
npm test
```

## Cloudflare (relay r1)

The relay runs on the free Workers plan at `relay.mgqmp.workers.dev`. Past the free plan's daily limits, requests fail until midnight UTC; nothing is billed.

- **Try it locally:** `npm run dev:cloudflare` runs the Worker on this PC at `ws://127.0.0.1:8787`, without an account.
- **Log in once:** `npx wrangler login` (in PowerShell `npx.cmd wrangler login` if scripts are blocked) opens the browser to allow wrangler on the Cloudflare account.
- **Deploy:** `npm run deploy:cloudflare`.

## Moving to a rented server

1. On the server, install Node.js 22 or later and [Caddy](https://caddyserver.com), and point a domain at the server.
2. Copy `core/`, `node/`, `package.json` and `package-lock.json`, then run `npm install --omit=dev` and start `node node/server.js`, for example as a systemd service. It listens on `127.0.0.1:8080` (`HOST` and `PORT` change that).
3. Have Caddy fetch the certificate and pass WebSockets on, with a `Caddyfile` like:

   ```
   relay.example.org {
       reverse_proxy 127.0.0.1:8080
   }
   ```

4. Add the new relay under a new id (`r2`) to the relay list in the Multiplayer DLL and release that version. Keep `r1` running until most players have updated, since the host's join code names the relay both games use.
