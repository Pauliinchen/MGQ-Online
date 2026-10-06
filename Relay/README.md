# Relay

Passes Monster Girl Quest! Online's frames between games. The games never connect to each other directly: many home connections cannot be reached from outside (DS-Lite, CGNAT, no IPv6, no forwarded port), but every one can connect out, so every game connects out to the relay.

The relay never sees what is played: the games encrypt every frame with a key derived from the join code or the world's token, which the relay never gets. For PvP battles it sees a room id, message sizes and timing, and stores nothing. For worlds it keeps the **world directory**, which everyone can read, but for hidden worlds, which only their players and whoever names their id see listed: each world's name, seats and creator, its description, the mods it needs and what tells its creator's game data from another's, the names of its players and who is online. It never learns a world's password or token: it keeps the token locked with the password, and checks a game that enters against a hash. A world may keep a **starting save**, which the games encrypt with a key from the token before it arrives, so the relay only keeps its bytes.

## Layout

```
core/relay.js          the rules: routes, pairing, size and rate limits, deadlines (no platform code)
core/relay.test.js     tests of the rules
core/directory.js      the world directory's rules, over a store the platform passes in
core/directory.test.js tests of the directory
cloudflare/worker.js   the relay on Cloudflare Workers, one Durable Object per room and per world room, one for the directory
cloudflare/wrangler.toml
node/server.js         the relay as a plain Node server, for a rented machine
node/server.test.js    tests of the Node server over real WebSockets
```

Both servers follow the same rules from `core/`, so the games cannot tell them apart.

## Protocol (v1)

A **room** pairs two games for a PvP battle. A **world room** seats up to 32 games that play in the same world.

### Rooms

- **Connect:** `wss://<relay>/v1/room/<room id>?role=host` or `?role=guest`. The room id is 32 lowercase hexadecimal characters, the start of a hash of the join code's token.
- **Pairing:** one host and one guest per room. Another peer of a taken role is refused with HTTP 409 before its WebSocket opens.
- **Messages:** binary messages go to the other peer unchanged. Once both are in, the relay sends each the text `paired`.
- **Limits:** a host waits alone at most 30 minutes, a room lasts at most 2 hours.

### World directory

Plain HTTP with JSON bodies. A world's id is 32 lowercase hexadecimal characters, the start of a hash of its token.

| Request | What it does |
|---|---|
| `GET /v1/worlds?player=<key>&ids=<id>,<id>` | Lists every public world, and the hidden ones the player of `player` joined or `ids` names (up to 50 ids, which the worlds' creators hand out; without `player` and `ids`, public ones only), or every world for an admin. Answers `worlds`, each with the listed fields below, and `admin`, true for an admin. |
| `POST /v1/worlds` | Makes a world from the fields sent on create below. 201, or 409 when the id is taken, 429 past 20 worlds per creator, a limit admins do not have, or past 2000 worlds in all. |
| `GET /v1/worlds/<id>/lock` | Hands out the world's `lock` (`salt`, `iterations`, `box`), which only the password opens, with its `name`, `seats`, `start` and `choose`, so a hidden world is entered by its id. |
| `POST /v1/worlds/<id>/edit` | Changes whichever of `seats`, `description` and `mods` the body names, if `player` is the creator's or an admin's key, and replaces `data`, the creator's game data, `modHashes` and `settings`, if it is the creator's. Everything else of a world stays as it was made. |
| `POST /v1/worlds/<id>/delete` | Deletes the world, if `player` is the creator's or an admin's key, and closes its world room. |
| `POST /v1/worlds/<id>/ban` | Removes the player whose id is `target` and keeps them out, if `player` is the creator's key. |
| `POST /v1/worlds/<id>/start?player=<key>` | Keeps the world's starting save, the body as bytes (at most 8 MB), if `player` is the creator's key and the world was made with `start: true`. Only once: 409 afterwards. |
| `GET /v1/worlds/<id>/start?player=<key>&auth=<auth key>` | Hands out the starting save as bytes, to a game the world room would let in. 404 when the world has none. |

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
| `mods` | optional | yes | The mods it needs, up to 80 characters. |
| `data` | optional | yes | What tells the creator's game data from another's; the relay only keeps it. |
| `strict` | optional | yes | Only games with the same data may enter, which the games check themselves. |
| `modHashes` | optional | yes | The creator's hashes of required mods outside the mod catalog: `name=hash` pairs separated by semicolons, up to 2000 characters. |
| `settings` | optional | yes | The creator's settings of the mods it names: `key=type:value` pairs separated by semicolons, up to 2000 characters. |
| `online`, `created`, `active` | | yes | How many players are in the world now, when it was made, when someone was last in it. |
| `members` | | yes | Every player who joined: `id`, `name`, `online`, `seen` (when last in the world). |

A player's key never appears in the list: everyone sees the player's id, the first 32 characters of the SHA-256 of `mgqmp player <key>`. Names are at most 32 characters, on one line.

**Admins** look after the directory: they see every world, hidden ones too, may delete any, and make the featured worlds. They cannot open a world's lock or enter it without its password. The relay reads their player ids from the setting `ADMINS`, separated by commas or spaces; without it there are none. On Cloudflare it is a secret, kept out of the repository: `npx wrangler secret put ADMINS --config cloudflare/wrangler.toml` sets it and deploys it at once. The Node server reads it from the environment variable of the same name. An admin's id is made from the key in their game's `Patch\Multiplayer\Player.ini`, as above.

### Mod catalog

The mods a world may require and games may download. Only admins add them: a single script or a zip laid out as in the game's `Patch` folder, by a link to a release on `https://github.com/Pauliinchen/`, the same for every version, or a mod of several files that an admin uploads. The relay keeps a link mod's hashes and version only, never the file, and checks every link every half hour (a cron trigger on Cloudflare, a timer on Node). A link such as `.../releases/latest/download/Mod.rb` (or `Mod.zip`) must lead to `.../releases/download/<tag>/Mod.rb`, whose tag (without `v`) is the version, and that file may only come from GitHub's file hosts, a script at most 2 MB, a zip at most 16 MB with at most 100 files of 64 MB in all, each a path inside `Patch` (plain or deflated; backslashes are read as slashes, and a `Patch` folder at the top of the zip as `Patch` itself). A script's hash is the SHA-256 of its bytes without carriage returns; any other file's of its bytes.

| Request | What it does |
|---|---|
| `GET /v1/mods?player=<key>` | Lists the mods: `mods`, each with `key` (the name in lower case without `.rb`, spaces, underscores and hyphens), `name`, `kind` (`link` or `upload`), `version`, `files` (each file's hash by its name, for an upload by its path inside `Patch`), `versions` (up to 20 earlier `version` and `files`, newest first) and `fileUrl` (a link mod's release file), `archive` (true when that file is a zip, whose files go to their paths inside `Patch`); for an admin also `link`, `size`, `checked` and `error` (why the last check failed, the last good version kept); and `admin`. |
| `POST /v1/mods` | Adds a link mod or changes its link: `player` (an admin's key), `name`, `link`. Checks it at once and answers the `mod`. |
| `POST /v1/mods/check` | Checks every link mod now, if `player` is an admin's key, and answers the list. |
| `POST /v1/mods/<key>/upload?player=<key>&name=<name>&version=<version>` | Keeps a mod of several files, if `player` is an admin's key. The body: one `path<TAB>hash` line per file (paths inside `Patch`, at most 100), an empty line, then the zip; at most 16 MB. |
| `GET /v1/mods/<key>/file` | Hands out an uploaded mod's zip as bytes. |
| `POST /v1/mods/<key>/delete` | Removes a mod, if `player` is an admin's key. |

### World rooms

- **Connect:** `wss://<relay>/v1/world/<world id>?player=<key>&name=<name>&auth=<auth key>`. The relay lets the game in only if the world is in the directory, the SHA-256 of the auth key is the world's `authHash`, and the creator has not removed the player: otherwise HTTP 404, 401 or 403 before the WebSocket opens, and HTTP 409 while the creator is still uploading the starting save. The world's seats come from the directory; once every one is taken, the next game gets HTTP 409. After every change the room tells the directory who is in it.
- **Seats:** a game takes the lowest free seat, from 0. It is told `seat <own> <others…>`, the seats already taken in ascending order, such as `seat 2 0 1`. The others are told `in <seat>`, and `out <seat>` once it leaves.
- **Messages:** a game sends a binary message as its target seat, or 255 for everyone, followed by the payload. The relay passes it on with the sender's seat in place of the target, so the receiver knows who sent it. A message for a free seat is dropped.
- **Limits:** each connection lasts at most 2 hours on its own; the game then connects again.

### Both

- The text `ping` is answered with `pong`, for keeping an idle connection open; any other text closes the connection.
- At most 512 KB per message and 60 messages per second over time (bursts of 240), per connection.
- **Close codes:** 4000 bad request, 4001 role taken, 4002 message too large, 4003 too many messages, 4004 nobody joined in time, 4005 the room lasted too long, 4006 the other side left, 4007 the world is full, 4008 the connection lasted too long, 4009 the creator removed the player, 4010 the world was deleted.

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
