# Relay

Passes Monster Girl Quest! Online's frames between games. The games never connect to each other directly: many home connections cannot be reached from outside (DS-Lite, CGNAT, no IPv6, no forwarded port), but every one can connect out, so every game connects out to the relay.

The relay never sees what is played: the games encrypt every frame with a key derived from the join code or the world's token, which the relay never gets. For PvP battles it sees a room id, message sizes and timing, and stores nothing. For worlds it keeps the **world directory**, which everyone can read, but for hidden worlds, which only their players and whoever names their id see listed: each world's name, seats and creator, its description, the mods it needs and what tells its creator's game data from another's, the names of its players and who is online. It never learns a world's password or token: it keeps the token locked with the password, and checks a game that enters against a hash. A world may keep a **starting save**, which the games encrypt with a key from the token before it arrives, so the relay only keeps its bytes. The one thing of a world it reads is its **chat**: the games mirror every line of the world's chat to it in plain text, so the relay's admins can read the chat and say something in it from outside the game; the map, party and whisper chats stay between their players.

## Layout

```
core/relay.js          the rules: routes, pairing, size and rate limits, deadlines (no platform code)
core/relay.test.js     tests of the rules
core/directory.js      the world directory's rules, over a store the platform passes in
core/directory.test.js tests of the directory
core/trades.js         the referee of trades between two players of a world
core/trades.test.js    tests of the trades
core/story.js          a Raid World's story: its counters, sealed story, checkpoints, route lock and shared companions
core/story.test.js     tests of the story
core/bosses.js         a Raid World's boss pools: the share of the raid HP left, the battles' reports, regeneration, the defeat
core/bosses.test.js    tests of the boss pools and the admin routes
core/raid_admin.js     what admins see and set right in a Raid World: counters, pools, the route lock
core/mods.js           the mod catalog's rules, over a store the platform passes in
core/mods.test.js      tests of the mod catalog
core/reports.js        the bug reports games send, committed to GitHub as private files with a public issue
core/reports.test.js   tests of the bug reports, against a stand-in for GitHub
core/http.js           the answers every router gives alike, and how each reads a JSON body
core/gate.js           which games the relay still serves, by X-MGQ-Features and X-MGQ-Version
core/gate.test.js      tests of the version gate
core/bodies.js         reading a body up to its limit, sending a stored file piece by piece, and the limit on downloads at once
core/bodies.test.js    tests of the bodies and the download limit
core/ids.js            how ids, hashes and texts are read everywhere
core/test_zip.js       the zips the tests feed the mod catalog
cloudflare/worker.js   the relay on Cloudflare Workers, one Durable Object per room and per world room, one for the directory, one for the bug reports
cloudflare/worker.test.js tests of the Worker and the Durable Objects against stand-ins for Cloudflare's storage and WebSockets
cloudflare/wrangler.toml
node/server.js         the relay as a plain Node server, for a rented machine
node/server.test.js    tests of the Node server over real WebSockets
node/sqlite_store.js   the directory's, the catalog's, the trades', the stories' and the boss pools' stores over one SQLite database, for the Node server
node/sqlite_store.test.js tests of the SQLite stores
```

Both servers follow the same rules from `core/`, so the games cannot tell them apart.

## Protocol (v1)

A **room** pairs two games for a PvP battle. A **world room** seats up to 32 games that play in the same world.

### Versions

Every game from 0.6.0 names its features in the header `X-MGQ-Features` on its directory requests and world rooms, and newer ones name their version in `X-MGQ-Version`, such as `0.6.5+<commit>` (`0.0.0-dev` for a development build). Before routing a request, the relay turns a game too old for it away with HTTP 426 and the error `Update MGQ Online to play online.`:
- the trades, the bug reports, a Raid World's story and boss routes and the world rooms need `X-MGQ-Features`, so games before 0.6.0 cannot play online;
- these routes and the rooms also hold a version named in `X-MGQ-Version` against the setting `MIN_VERSION` (`0.6.0` unless set): an older version or one that is no version is refused, a development version always passes, and a game that names none passes, as released games up to 0.6.4 do;
- the world directory's and the mod catalog's routes, the Raid World admin routes included, ask nothing, since the World Admin tool sends neither header; a room needs no `X-MGQ-Features`, since released games open rooms without it.

A refused WebSocket names the same text in the response header `X-MGQ-Refusal`; any other refused request gets it as `error` once its body is read and dropped, up to 15 MB or 60 seconds.

### Rooms

- **Connect:** `wss://<relay>/v1/room/<room id>?role=host` or `?role=guest`. The room id is 32 lowercase hexadecimal characters, the start of a hash of the join code's token.
- **Pairing:** one host and one guest per room. Another peer of a taken role is refused with HTTP 409 before its WebSocket opens.
- **Messages:** binary messages go to the other peer unchanged. Once both are in, the relay sends each the text `paired`.
- **Limits:** a peer waits alone at most 30 minutes, a room lasts at most 2 hours. A peer the relay closes leaves the room at once, which ends it for the other peer too.

### World directory

Plain HTTP with JSON bodies of up to 32 KB in general, and 413 beyond the size a route takes, on every route of the relay; a few routes take other sizes: a story write up to 300,000 bytes, the mod catalog's routes 8 KB (a mod's options 64 KB), a trade's commit, cancel and done 72 KB, and a boss report and an admin's request to a Raid World 4 KB. A world's id is 32 lowercase hexadecimal characters, the start of a hash of its token. A request names its player by the key in the header `X-MGQ-Player`, which wins over the `player` of its body or address, and a world's auth key by the header `X-MGQ-Auth`, which wins over the `auth` of its address; released games send both in the address, which is kept for them, and a key in an address ends up in logs. A refusal's body holds `error` and, where the games tell reasons apart, `code`: `removed`, `members` (the world has as many players as it may, 200), `pending`, `rate`, `storage` or `raid_unsupported` (a Raid World, which the game does not name in `X-MGQ-Features`). A route that does not exist is answered with 404.

| Request | What it does |
|---|---|
| `GET /v1/worlds?player=<key>&ids=<id>,<id>` | Lists every public world, and the hidden ones the player of `player` joined or `ids` names (up to 50 ids, which the worlds' creators hand out; without `player` and `ids`, public ones only), or every world for an admin. Answers `worlds`, each with the listed fields below, and `admin`, true for an admin. |
| `POST /v1/worlds` | Makes a world from the fields sent on create below. 201, or 409 when the id is taken, 429 past 20 worlds per creator, a limit admins do not have, 503 past 2000 worlds in all, and 429 with `code` `rate` past 5 worlds at once and 10 an hour from one address, counting only requests no other refusal turned away. A world whose starting save has not come 10 minutes after it was made is deleted. |
| `GET /v1/worlds/<id>/lock` | Hands out the world's `lock` (`salt`, `iterations`, `box`), which only the password opens, with its `name`, `seats`, `start` and `choose`, so a hidden world is entered by its id. |
| `POST /v1/worlds/<id>/edit` | Changes whichever of `seats`, `description`, `mods` (400 past 300 characters), `settings` (400 past 2000 characters), `otherModsOff` (400 for anything but `true` or `false`) and a Raid World's `difficulty` (400 for a Classic world) the body names, if `player` is the creator's or an admin's key, and replaces `data`, the creator's game data, and `modHashes`, if it is the creator's. Everything else of a world stays as it was made. A new `difficulty` goes to every game in the world room as a text frame, and so does an edit that changes whether the world turns other mods off or its mods (see world rooms below); an edit that sends the values the world has already tells nothing. |
| `POST /v1/worlds/<id>/delete` | Deletes the world, if `player` is the creator's or an admin's key, and closes its world room. |
| `POST /v1/worlds/<id>/ban` | Removes the player whose id is `target` and keeps them out, if `player` is the creator's key. A world keeps at most 500 removed players (429 beyond). |
| `POST /v1/worlds/<id>/start?player=<key>` | Keeps the world's starting save, the body as bytes (at most 8 MB), if `player` is the creator's key and the world was made with `start: true`. Only once: 409 afterwards. 413 past 8 MB, 507 with `code` `storage` once all starting saves together would pass 1 GB, and 429 with `code` `rate` past 5 uploads at once and 10 an hour from one address. |
| `GET /v1/worlds/<id>/start` | Hands out the starting save as bytes, to a game the world room would let in, with the player's key in `X-MGQ-Player` and the auth key in `X-MGQ-Auth` (released games send `?player=<key>&auth=<auth key>` instead). 404 when the world has none. On Cloudflare it is one of the downloads the relay sends only a few of at once (see below). |
| `GET /v1/worlds/<id>/chat?after=<n>` | Hands out the world's chat as the relay saw it, if `player` is the creator's or an admin's key: `lines`, oldest first, each with `n` (its number, counting up), `at`, `player` (the sender's id), `name`, `text` and `admin` (true for a line said over this route). With `after`, only the lines numbered beyond it. The relay keeps the last 200 lines of each world, 200 characters each at most; the games mirror every line of the world's chat into it (see world rooms below), the map, party and whisper chats stay between their players. |
| `POST /v1/worlds/<id>/chat` | Says a line in the world's chat as an admin: `text` (1 to 200 characters) and `name` (the name the line carries, up to 32 characters; `Admin` when left out), if `player` is an admin's key (403 for everyone else, the creator included, who talks through the game). The line goes into the chat and to every game in the world room as a text frame. Answers the `line` as kept. |

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
| `start` | `true` | `none`, `pending`, `ready` | Whether a starting save follows, and how far it is. A Raid World starts from the beginning: `true` is refused with 400 and `code` `raid_start`, and so is an upload, unless the request's `X-MGQ-Features` names `dev`, as development builds do, for testing only (to be removed before a release, see docs/DEVELOPER.md). |
| `hidden` | optional | yes | Left out of the list for everyone but its players. |
| `choose` | optional | yes | Each new player chooses where to start: the beginning, one of their own saves, or the starting save. Refused for a Raid World like `start`. |
| `open` | optional | yes | The password is empty, so the games enter without asking for it. |
| `featured` | admins only | yes | Shown as one of the relay's own worlds. |
| `description` | optional | yes | Kept up to 1000 characters. |
| `mods` | optional | yes | The mods it needs, up to 300 characters; longer ones are refused (400), never cut. |
| `otherModsOff` | optional | yes | Whether the games turn off every mod the world does not name in `mods` and the mod catalog does not mark personal, while their player is in it. Left out, `true` for a Raid World and `false` for a Classic one; a world kept without it is listed the same way. The creator or an admin changes it with an edit. The relay only keeps it: the games turn their mods off themselves. |
| `data` | optional | yes | What tells the creator's game data from another's; the relay only keeps it. |
| `strict` | optional | yes | Only games with the same data may enter, which the games check themselves. |
| `modHashes` | optional | yes | The creator's hashes of required mods outside the mod catalog: `name=hash` pairs separated by semicolons, names of up to 100 characters, up to 2000 characters in all. |
| `settings` | optional | yes | The creator's settings of the mods it names: `key=type:value` pairs separated by semicolons, up to 2000 characters; longer ones are refused, never cut. |
| `type` | optional | yes | `classic` or `raid`; a world kept without one is `classic`. Fixed once made: an edit leaves it. |
| `share` | optional | yes | How a Raid World shares companions: `off`, `story` (story companions) or `all` (story companions and battle recruits); `off` for every Classic world and when left out. Fixed once made. |
| `difficulty` | optional | Raid only | The difficulty a Raid World sets for every player, the game's own values: -2 (VERY EASY) to 4 (PARADOX). Kept and listed only for a Raid World; left out, each player keeps their own. The creator or an admin changes it with an edit. |
| `online`, `created`, `active` | | yes | How many players are in the world now, when it was made, when someone was last in it. |
| `members` | | yes | Every player who joined: `id`, `name`, `online`, `seen` (when last in the world). |

A player's key never appears in the list: everyone sees the player's id, the first 32 characters of the SHA-256 of `mgqmp player <key>`. Names are at most 32 characters, on one line.

**Admins** look after the directory: they see every world, hidden ones too, may delete any, and make the featured worlds. They cannot open a world's lock or enter it without its password. The relay reads their player ids from the setting `ADMINS`, separated by commas or spaces; without it there are none. On Cloudflare it is a secret, kept out of the repository: `npx wrangler secret put ADMINS --config cloudflare/wrangler.toml` sets it and deploys it at once. The Node server reads it from the environment variable of the same name. An admin's id is made from the key in their game's `Patch\Multiplayer\Player.ini`, as above.

### Mod catalog

The mods a world may require and games may download. Only admins add them: a single script or a zip laid out as in the game's `Patch` folder, by a link to a release on `https://github.com/Pauliinchen/`, the same for every version, or a mod of several files that an admin uploads. The relay keeps a link mod's hashes and version only, never the file, and checks every link every half hour (a cron trigger on Cloudflare, a timer on Node). A link such as `.../releases/latest/download/Mod.rb` (or `Mod.zip`) must lead to `.../releases/download/<tag>/Mod.rb`, whose tag (without `v`) is the version, and that file may only come from GitHub's file hosts, a script at most 2 MB, a zip at most 16 MB with at most 100 files of 64 MB in all, each a path inside `Patch` (plain or deflated; backslashes are read as slashes, and a `Patch` folder at the top of the zip as `Patch` itself). A script's hash is the SHA-256 of its bytes without carriage returns; any other file's of its bytes. The catalog also tells which mods are **personal**: the games keep them on in a world that turns other mods off (`otherModsOff`), whether the world names them or not. An admin marks any mod personal, or adds one by its name alone, with nothing to download.

| Request | What it does |
|---|---|
| `GET /v1/mods?player=<key>` | Lists the mods: `mods`, each with `key` (the name in lower case without `.rb`, spaces, underscores and hyphens), `name`, `kind` (`link`, `upload` or `name`), `personal` (true for a mod the games keep on in worlds that turn other mods off), `version`, `files` (each file's hash by its name, for an upload by its path inside `Patch`), `versions` (up to 20 earlier `version` and `files`, newest first) and `fileUrl` (a link mod's release file), `archive` (true when that file is a zip, whose files go to their paths inside `Patch`), `options` (the Mod Config options an admin's game sent, see below) and `optionsVersion` (the version they came from, empty before any arrived); for an admin also `link`, `size`, `checked` and `error` (why the last check failed, the last good version kept); `admin`; and `personal`, every mod marked personal as `key` and `name`, by name, whether checked or not, name entries included. A link never read successfully (no version, no files) and a `name` entry, which has nothing to download, are listed in `mods` for admins only. In every `<key>` below the key is percent-encoded, and a JSON body longer than its route takes (8 KB, the options 64 KB) is answered with 413. |
| `POST /v1/mods` | Adds a link mod or changes its link: `player` (an admin's key), `name` (400 when it holds `:`), `link`. Checks it at once and answers the `mod`; 409 when the mod was removed while its link was checked. A mod that the link replaces stays listed until the check is done. |
| `POST /v1/mods/check` | Checks every link mod now, if `player` is an admin's key, and answers the list. |
| `POST /v1/mods/<key>/upload?player=<key>&name=<name>&version=<version>` | Keeps a mod of several files, if `player` is an admin's key. The body: one `path<TAB>hash` line per file (paths inside `Patch`, at most 100), an empty line, then the zip; at most 16 MB. The relay hashes the zip's files itself and keeps those hashes; a file list that names other files or hashes is refused with 400, and so is a `name` that holds `:`. |
| `POST /v1/mods/<key>/options` | Keeps the mod's Mod Config options, if `player` is an admin's key: `version`, the version the game's copy is (empty for a copy matching no version the catalog knows, kept as `?`), and `options`, at most 100, each with `key` (the option's symbol), `name`, `type` (`i`, `f`, `b`, `y` or `s`, as in a world's `settings`), `default` and `choices` (at most 64, each `value` and `name`). The newest version's options are kept, by the order of `versions`: the current version's for good, an older one's only until a newer one's arrive, and a copy of no known version's only until a known version's arrive; options older than those kept are answered with `kept` false and change nothing. Only a running game can read them, since mods build their options when they load; the World Admin tool lists them. The body may be up to 64 KB. |
| `POST /v1/mods/<key>/personal` | Marks a mod personal or takes the mark off: `player` (an admin's key) and `personal` (`true` or `false`); 403 for everyone else, 404 for a mod the catalog lacks, 400 for anything but a boolean. Answers the `mod`. The mark stays when the mod's kind changes between `link`, `upload` and `name`. |
| `POST /v1/mods/<key>/name` | Adds a mod by its name alone, of kind `name`, or renames one: `player` (an admin's key) and `name` (up to 32 characters without `:`, whose key must be `<key>`; 400 otherwise). Such an entry has no link and no files, is never checked and is personal when made; it exists for mods the catalog hands out no copy of, such as someone else's cosmetic mod. 409 when a `link` or `upload` mod has that key: mark that one personal instead. Answers the `mod`. A link or upload added under the same name later takes its place and keeps the mark. |
| `GET /v1/mods/<key>/file` | Hands out an uploaded mod's zip as bytes; 404 for any other kind. On Cloudflare it is one of the downloads the relay sends only a few of at once (see below). |
| `POST /v1/mods/<key>/delete` | Removes a mod of any kind, if `player` is an admin's key. |

### Trades

Two players of a world swap items through their games, and the relay referees the swap, so a disconnect or crash never copies or loses anything. Each game commits a hash of the offers both games agreed on; the relay marks the trade committed once both hashes match, in one write, and only then do the games apply it. The offers travel sealed with a key from the world's token, so the relay keeps their bytes only, for a game that crashed before it applied the trade to fetch again. A trade's id is 32 lowercase hexadecimal characters, which the games make.

| Request | What it does |
|---|---|
| `POST /v1/trades/<id>/commit` | Commits one side: `player` (the key), `world`, `partner` (the other player's id), `hash` (SHA-256 of the offers, hexadecimal) and `sealed` (the sealed offers in base64, at most 64 KB; 413 beyond). Both players must be players of the world, whom the directory lists as members and the creator has not removed (403 otherwise; the creator always is one). The first commit makes the trade `pending`; the partner's commit with the same hash makes it `committed`, a different hash `cancelled` with `reason` `differ`. The same commit again changes nothing; other offers from a player who committed already, or a commit naming another world or partner than the trade's, get 409. A player may open at most 20 trades that are pending or committed and not yet done, and at most 100 a day that end cancelled (429). Answers `state` and, when cancelled, `reason`. |
| `POST /v1/trades/<id>/cancel` | Cancels a pending trade with `reason` `cancelled`, if `player` is the key of one of its two players. A committed trade stays committed. Answers `state` and `reason` as above. |
| `GET /v1/trades/<id>?player=<key>` | Answers `state` and `reason` to one of the trade's two players, 404 to anyone else. A trade still pending 2 minutes after its first commit is cancelled with `reason` `expired`. |
| `GET /v1/trades?player=<key>&world=<id>` | Lists the world's committed trades the player has not marked done: `trades`, each `id`, `hash` and `sealed`, the offers as the player's own game sealed them. |
| `POST /v1/trades/<id>/done` | Marks a committed trade done for `player`, whose game applied and saved it (409 for a trade not committed). The trade is deleted once both players marked it done. |

Committed trades nobody finished are dropped after 30 days, cancelled ones after a day. The relay keeps each player's sealed offers beside the trade, not in it, and drops them as soon as the trade is cancelled.

### Bug reports

A player reports a bug from the game. The relay commits the report as a folder of plain files, `reports/<id>/` with `report.md` as its index, in one commit to the branch `REPORT_FILES_BRANCH` (default `main`) of the private `REPORT_FILES_REPO` (default `Pauliinchen/MGQ-Online-Bug-Reports`), so a report reads in the browser or after a `git pull`. Then it opens a public issue in `REPORT_ISSUES_REPO` (default `Pauliinchen/MGQ-Online`) with the player's title and text and a few public facts, linking `report.md` and the screenshot, which only the developer can open. It takes reports only with two GitHub tokens (secrets on Cloudflare): `GITHUB_ISSUES_TOKEN`, which may write issues in the issues repository, and `GITHUB_BUG_FILES_TOKEN`, which may write contents in the files repository alone, so no token of the relay can change the public repository the mod updates from. The relay keeps nothing of a report; it unpacks the text files and passes the screenshot's base64 to GitHub as sent. It handles one report at a time and reads a report's body for at most 60 seconds. On Cloudflare the reports go to a Durable Object of their own, so a large report never takes the memory the world directory needs.

| Request | What it does |
|---|---|
| `POST /v1/reports` | Takes a report from the player whose key is in `X-MGQ-Player`. The body, at most 15 MB: one line of JSON, a line break, then the base64 of each file in the order the JSON lists them, with nothing between them. The JSON (at most 16 KB): `title` (1 to 100 characters on one line), `text` (1 to 4000 characters), `version` (1 to 32 letters, digits, `.`, `+` or `-`), `facts` (at most 12 `[label, value]` pairs on one line each, the label 1 to 32 characters, the value up to 120) and `files`, 1 to 32, each with `name`, `length` (the characters of its base64, a multiple of 4; together they add up to the rest of the body) and `gzip` (`true` or `false`, false unless given). A name is up to 120 characters, a file or a folder and a file, each starting with a letter or digit, then letters, digits, spaces and `._()+-`, and no two alike whatever their case. `report.md` is required; `screenshot.png` is the one binary file, never gzipped, at most 4 MB of base64; every other file ends in `.md`, `.log` or `.txt` and is text, unpacked from gzip when flagged and read as UTF-8, at most 8 MB each and 24 MB together unpacked. Answers 201 with `issue` (its number), `url` and `id` (the report's, `<UTC day>-<8 hexadecimal characters>`); 400 for a body that breaks a rule, a gzip stream that does not unpack or a body still arriving after 60 seconds, 401 with `code` `player` without a player key, 413 for a body or file over its limit, 429 with `code` `rate` past 3 reports a player an hour, 10 a player a day or 6 an address an hour (a report refused for its body or a gzip stream counts against none); the relay answers 401, 429 and both 503s before it reads the body, which it then reads to its end and drops, 503 with `code` `off` without both tokens, 503 with `code` `busy` while the relay handles another report, and 502 with `code` `github` when GitHub refused or could not be reached, whose status the relay logs per step. |

The commit goes through GitHub's Git Data API: the relay first checks that every text file unpacks within its limits, so a refused report leaves nothing on GitHub, then uploads the screenshot and every text file over 64 KB as a blob of its own, also the small ones once the inline texts would pass 1 MB together; the other text files go inline in a tree on the branch's head, the commit `report <id>: <title>`, then the branch moved to it; when another report moved the branch meanwhile, the relay commits again on the new head with the blobs it uploaded, 3 tries in all. The issue is titled `[In-game] <title>` and labelled `in-game report` (left off when GitHub refuses the label); every `@` in the title, text and facts gets a zero-width space after it, so a report mentions nobody.

### World story

A Raid World plays one story, which the relay keeps beside the world room, on Cloudflare in the world room's own object: the counters it reads to tell which story is further (`p` for variable 1001, `r1141`, `r1142`, `r1143`, the finished routes, the story teleport's endpoint, the shared companions) and the rest sealed with a key from the world's token, which it only keeps. Classic worlds keep none (404, code `classic`). The routes take the player's key and the auth key in the headers, as the world room does, and answer the world's players only. The full contract is in [docs/DEVELOPER.md](../docs/DEVELOPER.md#world-story-on-the-relay-raid-worlds).

| Request | What it does |
|---|---|
| `GET /v1/worlds/<id>/story` | Hands out the story: its revisions, counters, part, locked and finished routes, endpoint, shared companions, checkpoints and the sealed `blob`. |
| `POST /v1/worlds/<id>/story` | Writes the story: `base` (the revision it built on), `counters` and `blob` (the sealed story in base64, at most 280,000 characters). Taken when it built on the last write and its counters are not behind the story's; else 409 with the story and `code` `rev`, `behind` or `route` (while a route is locked, until the world returned from it, only a write on it or returning from it, finishing no route the world did not play; a write with no route under way also while the world's story has not started the locked route). A write that first moves the world out of a part keeps the story before it as that part's checkpoint, which a later return to the part never replaces. |
| `GET /v1/worlds/<id>/story/checkpoint/<part>` | Hands out a part's checkpoint (`1`, `2`, `3`, `ad`, `mr`, `chaos`), 404 with `code` `none` for a part without one. |
| `POST /v1/worlds/<id>/story/route` | Locks the route at the Great Decision: the first one wins (409 `route`, also while the world's story is on another route); a finished route (409 `finished`) and the third way before both others are finished (409 `closed`) are refused. |
| `POST /v1/worlds/<id>/story/companions` | Adds actor ids to the shared companions, which only grow. |

### Raid bosses

A Raid World's story bosses each have a pool whose HP the whole world shares, kept beside the story in the world room's own object. A pool keeps the share of the boss's raid max HP left, 0 to 1, with the max the first report named, since each game's difficulty and mods set the boss's max HP in its own game. It fills up again by 3% of its max a minute, also while battles fight it, and costs no writes for it: every read computes the share left now from the last report. The host of every battle fighting the boss reports what its players took off since its last report as each action ends, at most every two seconds, at each command phase and at the battle's end; the report that empties the pool defeats the boss for the world until an admin resets it. The routes take the player's key and the auth key in the headers, as the story's do, and answer the world's players only; Classic worlds keep none (404, code `classic`). A key may hold spaces and `#` (a boss of several enemies has a pool per enemy, such as `Metatronne and Sandalphone#1`) and is percent-encoded in the address, up to 72 characters; a world keeps at most 500 pools. The full contract is in [docs/DEVELOPER.md](../docs/DEVELOPER.md#raid-boss-pools-on-the-relay).

| Request | What it does |
|---|---|
| `GET /v1/worlds/<id>/bosses` | Hands out every pool a report touched (`bosses`, each with `key`, `left`, `max`, `defeated`, `at` and `by`) and `regenPerMinute`. `left` is the share left now; `by` names the player whose report emptied the pool. |
| `GET /v1/worlds/<id>/bosses/<key>` | Hands out one pool; a pool never reported is full, with `max` null. |
| `POST /v1/worlds/<id>/bosses/<key>/report` | Counts what a battle took off since its last report: `battle` (its id), `seq` (the report's number, rising within the battle), `delta` (the share of the max HP lost since the battle's last report, -1 to 1, negative for healing), `max` (the reporting game's raid max HP, which only the first report of a pool sets, at most 1e18) and `killed` (the boss died in the reporting game, which empties the pool). A `seq` the battle reported already counts nothing (`repeat`), so a report sent again counts once. A report on a defeated boss, or one that takes nothing off, changes nothing. Answers `boss`, the pool, and `repeat`. 400 for a body that is not as it should be, an old `dealt` body too; 413 with `code` `full` past 500 pools; 429 with `code` `rate` past 30 reports at once, then two a second, per player. |

**Admins** (the `ADMINS` setting) look after a Raid World from outside the game. Each route takes an admin's key in `X-MGQ-Player`, or as `player` in the address (GET) or the JSON body (POST); 403 for everyone else, the creator included, 404 with `code` `classic` for a Classic world.

| Request | What it does |
|---|---|
| `GET /v1/worlds/<id>/raid?player=<key>` | Hands out the story's counters without the sealed story (`story`), every pool with `hp` (the HP left now), `reports` and `byPlayer` (the id of the player whose report emptied it) besides what the players see, and `regenPerMinute`. |
| `POST /v1/worlds/<id>/raid/bosses/<key>/reset` | Deletes a pool, so it is full again and its defeat taken back; the next report sets its max again. |
| `POST /v1/worlds/<id>/raid/route/clear` | Takes back the route locked at the Great Decision, so the next player who chooses sets it again, and answers `cleared` (false when no route was locked). Refused with 409 and `code` `started` while the world's story is on the locked route, since another route locked then would turn away every write of both routes; once the world returns from the route, the lock is gone anyway. |

### World rooms

- **Connect:** `wss://<relay>/v1/world/<world id>?name=<name>`, with the player's key in the header `X-MGQ-Player` and the auth key in the header `X-MGQ-Auth` (released games send them as `player=<key>&auth=<auth key>` in the address instead, which is kept for them). The relay lets the game in only if the world is in the directory, the SHA-256 of the auth key is the world's `authHash`, and the creator has not removed the player: otherwise HTTP 404, 401 or 403 before the WebSocket opens, HTTP 409 while the creator is still uploading the starting save, and HTTP 400 when the world is a Raid World and the request's header `X-MGQ-Features` (features separated by commas) does not name `raid`, which games take as final, unlike a 409. A game without `X-MGQ-Features` gets HTTP 426 before any of these checks, see Versions. A 400, 403 or 409 names why in the response header `X-MGQ-Refusal`, with the codes of the directory. Entering rooms and world rooms is limited per address, 30 at once and one more every 2 seconds (HTTP 429). When a player enters a world room again, the relay closes the player's earlier connection with 4009 and the reason `replaced`. The world's seats come from the directory; once every one is taken, the next game gets HTTP 409. After every change the room tells the directory who is in it.
- **Seats:** a game takes the lowest free seat, from 0. It is told `seat <own> <others…>`, the seats already taken in ascending order, such as `seat 2 0 1`. The others are told `in <seat>`, and `out <seat>` once it leaves.
- **Messages:** a game sends a binary message as its target seat, or 255 for everyone, followed by the payload. The relay passes it on with the sender's seat in place of the target, so the receiver knows who sent it. A message for a free seat is dropped.
- **Chat:** the games send each other their lines encrypted, as any message. The relay keeps a plain copy of the global chat for the admins:
  - After every global line, a game sends the text `chat <line>`. The relay keeps it in the world's chat (`GET /v1/worlds/<id>/chat`) with the sender's player id and name, and passes it to nobody.
  - Each connection may send 2 chat lines a second, after a burst of 10. The relay drops a line beyond that and answers the text `slow chat`; games that don't know it ignore it. A `chat` text without a line is ignored.
  - When an admin says something (`POST /v1/worlds/<id>/chat`), the relay sends the text `chat <name>` + tab + `<line>` to every game in the room; games that don't know the frame ignore it.
- **Story:** after every change of a Raid World's story the relay sends the text `story <rev>` to every game in the room; games that don't know it ignore it.
- **Bosses:** after every change of a Raid World's boss pool (a report that changed it, an admin's reset of a pool there was) the relay sends the text `boss <left> <max> <defeated> <key>` to every game in the room: the share of the max HP left now with up to 6 decimals (at least `0.000001` while the boss stands), the raid max HP as a whole number, `1` when the boss is defeated, else `0`, and the key last, since it may hold spaces and `#`, such as `boss 0.25 5000000 0 Metatronne and Sandalphone#1`; a reset sends a share of 1. Games that don't know it ignore it.
- **Difficulty:** after an edit that changes a Raid World's `difficulty`, the relay sends the text `difficulty <n>` to every game in the room; games that don't know it ignore it.
- **Mods rule:** after an edit that changes `otherModsOff` or `mods` (compared as kept, a world without `otherModsOff` by its type), the relay sends the text `mods_rule <0|1>` + tab + `<the world's mods>` to every game in the room, 1 when the world turns other mods off; the mods never hold a tab or a line break. A game that now runs mods the world turns off leaves the world; games that don't know the frame ignore it.
- **Limits:** each connection lasts at most 2 hours on its own; the game then connects again.

### Both

- The text `ping` is answered with `pong`, for keeping an idle connection open; any other text than `ping` and a world room's `chat` closes the connection. On Node a `ping` counts against the message limits; Cloudflare answers it without waking the room, so there it does not. A `chat` text counts on both.
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
- **Downloads:** the directory sends starting saves and uploaded mods' zips piece by piece as it reads them, without a Content-Length, and at most 3 at once and 1 per address. A download that finds no free slot waits up to 30 seconds for one, at most 10 waiting in all; past that, and past 20 downloads at once and one more every 30 seconds from one address, it gets 503 with `code` `busy`, the error "the relay is sending other downloads, try again in a moment" and `Retry-After: 10`. A download still running after 5 minutes is ended and its slot given to the next. The Node relay sends both whole and has no such limit.
- **Lowest version:** `MIN_VERSION` in the `[vars]` of `wrangler.toml`, see Versions.
- **Bug reports:** `npx wrangler secret put GITHUB_ISSUES_TOKEN --config cloudflare/wrangler.toml` and the same for `GITHUB_BUG_FILES_TOKEN` set the tokens once; the repositories and the branch are the `[vars]` in `wrangler.toml`.

## Moving to a rented server

1. On the server, install Node.js 24 or later (the SQLite database needs `node:sqlite`) and [Caddy](https://caddyserver.com), and point a domain at the server.
2. Copy `core/`, `node/`, `package.json` and `package-lock.json`, then run `npm install --omit=dev`.
3. Start `node node/server.js` as a systemd service, with these environment variables:
   - `MGQ_RELAY_DB=/var/lib/mgq-relay/relay.sqlite`: the SQLite database the worlds, their starting saves, the mod catalog, its uploaded zips, the trades, the Raid Worlds' stories and their boss pools are kept in, made on the first start (with its `-wal` and `-shm` files beside it). Without it everything stays in memory and is gone with the process. Back the file up with `sqlite3 relay.sqlite ".backup copy.sqlite"`, never by copying it while the relay runs.
   - `ADMINS`: the admins' player ids, as above.
   - `GITHUB_ISSUES_TOKEN` and `GITHUB_BUG_FILES_TOKEN`, and `REPORT_ISSUES_REPO`, `REPORT_FILES_REPO` and `REPORT_FILES_BRANCH` unless the defaults fit: where the bug reports go, see above. Without both tokens the relay takes no reports.
   - `MIN_VERSION`: the lowest version a game may name, `0.6.0` unless set, see Versions.
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
