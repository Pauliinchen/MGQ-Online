# Relay

Passes Monster Girl Quest! Online's frames between games. The games never connect to each other directly: many home connections cannot be reached from outside (DS-Lite, CGNAT, no IPv6, no forwarded port), but every one can connect out, so every game connects out to the relay.

The relay never sees what is played: the games encrypt every frame with a key derived from the join code or the world's token, which the relay never gets. For PvP battles it sees a room id, message sizes and timing, and stores nothing. For worlds it keeps the **world directory**, which everyone can read, but for hidden worlds, which only their players and whoever names their id see listed: each world's name, seats and creator, its description, the mods it needs and what tells its creator's game data from another's, the names of its players and who is online. It never learns a world's password or token: it keeps the token locked with the password, and checks a game that enters against a hash. A world may keep a **starting save**, which the games encrypt with a key from the token before it arrives, so the relay only keeps its bytes.

## Layout

```
core/relay.js          the rules: routes, pairing, size and rate limits, deadlines (no platform code)
core/relay.test.js     tests of the rules
core/directory.js      the world directory's rules, over a store the platform passes in
core/directory.test.js tests of the directory
core/trades.js         the referee of trades between two players of a world
core/trades.test.js    tests of the trades
core/mods.js           the mod catalog's rules, over a store the platform passes in
core/mods.test.js      tests of the mod catalog
core/http.js           the answers every router gives alike, and how each reads a JSON body
core/ids.js            how ids, hashes and texts are read everywhere
core/test_zip.js       the zips the tests feed the mod catalog
cloudflare/worker.js   the relay on Cloudflare Workers, one Durable Object per room and per world room, one for the directory
cloudflare/wrangler.toml
node/server.js         the relay as a plain Node server, for a rented machine
node/server.test.js    tests of the Node server over real WebSockets
node/sqlite_store.js   the directory's, the catalog's and the trades' stores over one SQLite database, for the Node server
node/sqlite_store.test.js tests of the SQLite stores
```

Both servers follow the same rules from `core/`, so the games cannot tell them apart.

## Protocol (v1)

A **room** pairs two games for a PvP battle. A **world room** seats up to 32 games that play in the same world.

### Rooms

- **Connect:** `wss://<relay>/v1/room/<room id>?role=host` or `?role=guest`. The room id is 32 lowercase hexadecimal characters, the start of a hash of the join code's token.
- **Pairing:** one host and one guest per room. Another peer of a taken role is refused with HTTP 409 before its WebSocket opens.
- **Messages:** binary messages go to the other peer unchanged. Once both are in, the relay sends each the text `paired`.
- **Limits:** a peer waits alone at most 30 minutes, a room lasts at most 2 hours. A peer the relay closes leaves the room at once, which ends it for the other peer too.

### World directory

Plain HTTP with JSON bodies of up to 32 KB (413 beyond, on every route of the relay). A world's id is 32 lowercase hexadecimal characters, the start of a hash of its token. A request names its player by the key in the header `X-MGQ-Player`, which wins over the `player` of its body or address, and a world's auth key by the header `X-MGQ-Auth`, which wins over the `auth` of its address; released games send both in the address, which is kept for them, and a key in an address ends up in logs. A refusal's body holds `error` and, where the games tell reasons apart, `code`: `removed`, `members` (the world has as many players as it may, 200), `pending`, `rate` or `storage`. A route that does not exist is answered with 404.

| Request | What it does |
|---|---|
| `GET /v1/worlds?player=<key>&ids=<id>,<id>` | Lists every public world, and the hidden ones the player of `player` joined or `ids` names (up to 50 ids, which the worlds' creators hand out; without `player` and `ids`, public ones only), or every world for an admin. Answers `worlds`, each with the listed fields below, and `admin`, true for an admin. |
| `POST /v1/worlds` | Makes a world from the fields sent on create below. 201, or 409 when the id is taken, 429 past 20 worlds per creator, a limit admins do not have, 503 past 2000 worlds in all, and 429 with `code` `rate` past 5 worlds at once and 10 an hour from one address. A world whose starting save has not come 10 minutes after it was made is deleted. |
| `GET /v1/worlds/<id>/lock` | Hands out the world's `lock` (`salt`, `iterations`, `box`), which only the password opens, with its `name`, `seats`, `start` and `choose`, so a hidden world is entered by its id. |
| `POST /v1/worlds/<id>/edit` | Changes whichever of `seats`, `description`, `mods` and `settings` (400 past 2000 characters) the body names, if `player` is the creator's or an admin's key, and replaces `data`, the creator's game data, and `modHashes`, if it is the creator's. Everything else of a world stays as it was made. |
| `POST /v1/worlds/<id>/delete` | Deletes the world, if `player` is the creator's or an admin's key, and closes its world room. |
| `POST /v1/worlds/<id>/ban` | Removes the player whose id is `target` and keeps them out, if `player` is the creator's key. A world keeps at most 500 removed players (429 beyond). |
| `POST /v1/worlds/<id>/start?player=<key>` | Keeps the world's starting save, the body as bytes (at most 8 MB), if `player` is the creator's key and the world was made with `start: true`. Only once: 409 afterwards. 413 past 8 MB, 507 with `code` `storage` once all starting saves together would pass 1 GB, and 429 with `code` `rate` past 5 uploads at once and 10 an hour from one address. |
| `GET /v1/worlds/<id>/start` | Hands out the starting save as bytes, to a game the world room would let in, with the player's key in `X-MGQ-Player` and the auth key in `X-MGQ-Auth` (released games send `?player=<key>&auth=<auth key>` instead). 404 when the world has none. |

A world's fields, as `POST /v1/worlds` takes them and `GET /v1/worlds` lists them:

| Field | Create | Listed | What it is |
|---|---|---|---|
| `id` | yes | yes | The world's id. |
| `name` | yes | yes | The world's name. |
| `seats` | yes | yes | Max players, 2 to 32. |
| `player`, `playerName` | yes | | The creator's key and name. |
| `creator` | | yes | The creator's `id` and `name`. |
| `authHash` | yes | | SHA-256 of the auth key, hexadecimal. |
| `lock` | yes | | `salt`, `iterations`, `box`: the token encrypted with a key from the password. |
| `start` | `true` | `none`, `pending`, `ready` | Whether a starting save follows, and how far it is. |
| `hidden` | optional | yes | Left out of the list for everyone but its players. |
| `choose` | optional | yes | Each new player chooses where to start: the beginning, one of their own saves, or the starting save. |
| `open` | optional | yes | The password is empty, so the games enter without asking for it. |
| `featured` | admins only | yes | Shown as one of the relay's own worlds. |
| `description` | optional | yes | Kept up to 1000 characters. |
| `mods` | optional | yes | The mods it needs, up to 300 characters. |
| `data` | optional | yes | What tells the creator's game data from another's; the relay only keeps it. |
| `strict` | optional | yes | Only games with the same data may enter, which the games check themselves. |
| `modHashes` | optional | yes | The creator's hashes of required mods outside the mod catalog: `name=hash` pairs separated by semicolons, names of up to 100 characters, up to 2000 characters in all. |
| `settings` | optional | yes | The creator's settings of the mods it names: `key=type:value` pairs separated by semicolons, up to 2000 characters; longer ones are refused, never cut. |
| `online`, `created`, `active` | | yes | How many players are in the world now, when it was made, when someone was last in it. |
| `members` | | yes | Every player who joined: `id`, `name`, `online`, `seen` (when last in the world). |

A player's key never appears in the list: everyone sees the player's id, the first 32 characters of the SHA-256 of `mgqmp player <key>`. Names are at most 32 characters, on one line.

**Admins** look after the directory: they see every world, hidden ones too, may delete any, and make the featured worlds. They cannot open a world's lock or enter it without its password. The relay reads their player ids from the setting `ADMINS`, separated by commas or spaces; without it there are none. On Cloudflare it is a secret, kept out of the repository: `npx wrangler secret put ADMINS --config cloudflare/wrangler.toml` sets it and deploys it at once. The Node server reads it from the environment variable of the same name. An admin's id is made from the key in their game's `Patch\Multiplayer\Player.ini`, as above.

### Mod catalog

The mods a world may require and games may download. Only admins add them: a single script or a zip laid out as in the game's `Patch` folder, by a link to a release on `https://github.com/Pauliinchen/`, the same for every version, or a mod of several files that an admin uploads. The relay keeps a link mod's hashes and version only, never the file, and checks every link every half hour (a cron trigger on Cloudflare, a timer on Node). A link such as `.../releases/latest/download/Mod.rb` (or `Mod.zip`) must lead to `.../releases/download/<tag>/Mod.rb`, whose tag (without `v`) is the version, and that file may only come from GitHub's file hosts, a script at most 2 MB, a zip at most 16 MB with at most 100 files of 64 MB in all, each a path inside `Patch` (plain or deflated; backslashes are read as slashes, and a `Patch` folder at the top of the zip as `Patch` itself). A script's hash is the SHA-256 of its bytes without carriage returns; any other file's of its bytes.

| Request | What it does |
|---|---|
| `GET /v1/mods?player=<key>` | Lists the mods: `mods`, each with `key` (the name in lower case without `.rb`, spaces, underscores and hyphens), `name`, `kind` (`link` or `upload`), `version`, `files` (each file's hash by its name, for an upload by its path inside `Patch`), `versions` (up to 20 earlier `version` and `files`, newest first) and `fileUrl` (a link mod's release file), `archive` (true when that file is a zip, whose files go to their paths inside `Patch`), `options` (the Mod Config options an admin's game sent, see below) and `optionsVersion` (the version they came from, empty before any arrived); for an admin also `link`, `size`, `checked` and `error` (why the last check failed, the last good version kept); and `admin`. A link never read successfully (no version, no files) is listed for admins only. In every `<key>` below the key is percent-encoded, and a JSON body longer than its route takes (8 KB, the options 64 KB) is answered with 413. |
| `POST /v1/mods` | Adds a link mod or changes its link: `player` (an admin's key), `name`, `link`. Checks it at once and answers the `mod`. |
| `POST /v1/mods/check` | Checks every link mod now, if `player` is an admin's key, and answers the list. |
| `POST /v1/mods/<key>/upload?player=<key>&name=<name>&version=<version>` | Keeps a mod of several files, if `player` is an admin's key. The body: one `path<TAB>hash` line per file (paths inside `Patch`, at most 100), an empty line, then the zip; at most 16 MB. The relay hashes the zip's files itself and keeps those hashes; a file list that names other files or hashes is refused with 400. |
| `POST /v1/mods/<key>/options` | Keeps the mod's Mod Config options, if `player` is an admin's key and `version` is the mod's current version (409 otherwise): `options`, at most 100, each with `key` (the option's symbol), `name`, `type` (`i`, `f`, `b`, `y` or `s`, as in a world's `settings`), `default` and `choices` (at most 64, each `value` and `name`). Only a running game can read them, since mods build their options when they load; the World Admin tool lists them. The body may be up to 64 KB. |
| `GET /v1/mods/<key>/file` | Hands out an uploaded mod's zip as bytes. |
| `POST /v1/mods/<key>/delete` | Removes a mod, if `player` is an admin's key. |

### Trades

Two players of a world swap items through their games, and the relay referees the swap, so a disconnect or crash never copies or loses anything. Each game commits a hash of the offers both games agreed on; the relay marks the trade committed once both hashes match, in one write, and only then do the games apply it. The offers travel sealed with a key from the world's token, so the relay keeps their bytes only, for a game that crashed before it applied the trade to fetch again. A trade's id is 32 lowercase hexadecimal characters, which the games make.

| Request | What it does |
|---|---|
| `POST /v1/trades/<id>/commit` | Commits one side: `player` (the key), `world`, `partner` (the other player's id), `hash` (SHA-256 of the offers, hexadecimal) and `sealed` (the sealed offers in base64, at most 64 KB; 413 beyond). Both players must be players of the world, whom the directory lists as members and the creator has not removed (403 otherwise; the creator always is one). The first commit makes the trade `pending`; the partner's commit with the same hash makes it `committed`, a different hash `cancelled` with `reason` `differ`. The same commit again changes nothing; other offers from a player who committed already, or a commit naming another world or partner than the trade's, get 409. A player may open at most 20 trades that are pending or committed and not yet done (429). Answers `state` and, when cancelled, `reason`. |
| `POST /v1/trades/<id>/cancel` | Cancels a pending trade with `reason` `cancelled`, if `player` is the key of one of its two players. A committed trade stays committed. Answers `state` and `reason` as above. |
| `GET /v1/trades/<id>?player=<key>` | Answers `state` and `reason` to one of the trade's two players, 404 to anyone else. A trade still pending 2 minutes after its first commit is cancelled with `reason` `expired`. |
| `GET /v1/trades?player=<key>&world=<id>` | Lists the world's committed trades the player has not marked done: `trades`, each `id`, `hash` and `sealed`, the offers as the player's own game sealed them. |
| `POST /v1/trades/<id>/done` | Marks a committed trade done for `player`, whose game applied and saved it (409 for a trade not committed). The trade is deleted once both players marked it done. |

Committed trades nobody finished are dropped after 30 days, cancelled ones after a day.

### World rooms

- **Connect:** `wss://<relay>/v1/world/<world id>?name=<name>`, with the player's key in the header `X-MGQ-Player` and the auth key in the header `X-MGQ-Auth` (released games send them as `player=<key>&auth=<auth key>` in the address instead, which is kept for them). The relay lets the game in only if the world is in the directory, the SHA-256 of the auth key is the world's `authHash`, and the creator has not removed the player: otherwise HTTP 404, 401 or 403 before the WebSocket opens, and HTTP 409 while the creator is still uploading the starting save. A 403 or 409 names why in the response header `X-MGQ-Refusal`, with the codes of the directory. Entering rooms and world rooms is limited per address, 30 at once and one more every 2 seconds (HTTP 429). When a player enters a world room again, the relay closes the player's earlier connection with 4009 and the reason `replaced`. The world's seats come from the directory; once every one is taken, the next game gets HTTP 409. After every change the room tells the directory who is in it.
- **Seats:** a game takes the lowest free seat, from 0. It is told `seat <own> <others…>`, the seats already taken in ascending order, such as `seat 2 0 1`. The others are told `in <seat>`, and `out <seat>` once it leaves.
- **Messages:** a game sends a binary message as its target seat, or 255 for everyone, followed by the payload. The relay passes it on with the sender's seat in place of the target, so the receiver knows who sent it. A message for a free seat is dropped.
- **Limits:** each connection lasts at most 2 hours on its own; the game then connects again.

### Both

- The text `ping` is answered with `pong`, for keeping an idle connection open; any other text closes the connection. On Node a `ping` counts against the message limits; Cloudflare answers it without waking the room, so there it does not.
- At most 512 KB per message and 60 messages per second over time (bursts of 240), per connection.
- **Close codes:** 4000 bad request, 4001 role taken, 4002 message too large, 4003 too many messages, 4004 nobody joined in time, 4005 the room lasted too long, 4006 the other side left, 4007 the world is full, 4008 the connection lasted too long, 4009 the creator removed the player, or the player entered from elsewhere (reason `replaced`), 4010 the world was deleted.

## Tests

You need Node.js 24 or later, since the SQLite stores and their tests use `node:sqlite`.

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

1. On the server, install Node.js 24 or later (the SQLite database needs `node:sqlite`) and [Caddy](https://caddyserver.com), and point a domain at the server.
2. Copy `core/`, `node/`, `package.json` and `package-lock.json`, then run `npm install --omit=dev`.
3. Start `node node/server.js` as a systemd service, with these environment variables:
   - `MGQ_RELAY_DB=/var/lib/mgq-relay/relay.sqlite`: the SQLite database the worlds, their starting saves, the mod catalog, its uploaded zips and the trades are kept in, made on the first start (with its `-wal` and `-shm` files beside it). Without it everything stays in memory and is gone with the process. Back the file up with `sqlite3 relay.sqlite ".backup copy.sqlite"`, never by copying it while the relay runs.
   - `ADMINS`: the admins' player ids, as above.
   - `HOST` and `PORT`: where it listens, `127.0.0.1:8080` unless set.
4. The relay writes one line per request to stdout (`<time> <method> <path> <status> <ms> <address>`, the path without its query, so no key ever appears) and every error it catches to stderr, with its stack. Under systemd both go to the journal (`journalctl -u <service>`); the service file's `StandardOutput=append:/var/log/mgq-relay/relay.log` keeps them in a file instead. The rooms and the WebSockets live in memory, so a restart ends every connection; the games connect again on their own.
5. On its own the relay closes rooms and connections whose time is up every minute, checks the mod catalog's links every half hour, and every ten minutes sweeps out worlds whose starting save never came and trades kept long enough, so the database does not grow with what nobody asks for again.
6. Have Caddy fetch the certificate and pass WebSockets on, with a `Caddyfile` like the one below. The relay counts its rate limits by the address Caddy appends to `X-Forwarded-For` last, for requests from this machine only.

   ```
   relay.example.org {
       reverse_proxy 127.0.0.1:8080
   }
   ```

7. Run one process. The rate limits per address are counted in memory, so several processes behind one proxy would each let an address have the full allowance, and the rooms are in memory too, so two games of one room must reach the same process. One Node process carries the relay's load with room to spare.
8. Add the new relay under a new id (`r2`) to the relay list in the Multiplayer DLL and release that version. Keep `r1` running until most players have updated, since the host's join code names the relay both games use.
