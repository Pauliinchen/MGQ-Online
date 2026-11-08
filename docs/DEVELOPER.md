# Developer notes

This file holds what the code cannot say: how to build, test and release, how the parts connect, why things are the way they are, and the traps that broke before. What a method does, which topics exist and which fields they carry is in the code and its docs.

Monster Girl Quest! Online keeps its first name inside: the `Multiplayer` install folder, `Multiplayer.dll`, `MGQ_Multiplayer`, the `MGQ_Mp` modules and the DLL's `mp_` functions. The `mgqmp` strings in join and world codes, key derivation labels and player ids must never change, since every world and player id on the relay derives from them.

## Build and test

### What you need

- The .NET 10 SDK and the Visual Studio workload **Desktop development with C++**: NativeAOT links with its linker, and its compiler builds SQLite into the DLL. `Directory.Build.targets` puts `vswhere.exe` on the PATH, which the NativeAOT link needs.
- The x86 .NET 10 runtime (`C:\Program Files (x86)\dotnet`) for the 32-bit test projects. With `DOTNET_ROOT` pointing at the x64 install, set `DOTNET_ROOT_X86` to the x86 one.
- Ruby 3.3 or later for the script tests, Node for the relay and the tests that run the relay's code, Docker for the battle server's core.
- A copy of the Mod Framework's scripts for the script tests: its release's `Patch/Mod_Framework` or its checkout's `GameScript/Mod_Framework`, named by `MGQ_MOD_FRAMEWORK_DIR`; and the framework installed in the game folder you try the mod in.

### Building the mod

Only a publish runs NativeAOT, so a plain build gives no usable DLL:

```powershell
dotnet publish MGQOnline.Multiplayer -c Release -p:Version=0.1.0
```

The DLL is 32-bit, because the game is a 32-bit process; players need no .NET installed. A publish assembles the release layout in `Shipping/` (replaced every time); a Release publish also writes `bin/Release/MGQ-Online-<Version>.zip`. Copy `Shipping/` into a game folder to install; close the game first, since `Multiplayer.dll` is locked while it runs.

```
Patch/                      Multiplayer.rb
Patch/Multiplayer/          Multiplayer.dll  Manifest.txt  README.txt
Patch/Multiplayer/Data/     events.db
Patch/Multiplayer/Scripts/  *.rbx
```

- **The Mod Framework is not in the package.** Players install it on their own (`Patch/!Mod_Framework.rb` and `Patch/Mod_Framework/`, from the website), as every mod built on it requires. `MOD_FRAMEWORK_REQUIRED` in `Multiplayer.rb` names the oldest framework the mod runs on. Without the framework the mod stays off and the game's message box says where to get it (see [Loading](#loading)). The manifest lists MGQ Online's own files only, so the updater of 0.6 removes `Patch/0_ModConfigRemake.rb`, which 0.6 shipped, as it updates to 0.7.
- **The events database** `package/Multiplayer/Data/events.db` is committed and shipped as it is; a publish without it stops (see [The events database](#the-events-database)).

### Trying it out

- **Two games on one PC** can play each other; both go through the real relay as between two homes.
- **A relay on this PC:** `node Relay/node/server.js` (port 8080; `ADMINS` for admin ids; `MGQ_RELAY_DB=<file>` keeps worlds, saves and trades in SQLite instead of memory). Start the game with `MGQMP_RELAY=ws://127.0.0.1:8080` and the DLL talks to it instead of the live relay, so relay changes can be tried before a deploy.
- A development build names itself `0.0.0-dev`: the relay's version check always lets it pass, and it never asks for updates.

### Tests

| Project | Run | Runtime |
|---|---|---|
| `MGQOnline.Multiplayer.Tests` (the DLL) | `dotnet run --project MGQOnline.Multiplayer.Tests` | 32-bit, x86 runtime |
| `MGQOnline.Data.Tests` | `dotnet run --project MGQOnline.Data.Tests` | 32-bit, x86 runtime |
| `MGQOnline.Bridge.Tests`, `MGQOnline.Game.Tests`, `MGQOnline.ServerCore.Tests`, `MGQOnline.Data.Generator.Tests` | `dotnet run --project <name>` | 64-bit, any .NET 10 runtime |
| Script tests (`GameScript/Tests/`) | `ruby GameScript/Tests/run.rb` (`-v` shows every check) | Ruby 3.3+ |
| Relay | see [Relay/README.md](../Relay/README.md) | Node |
| Battle server | see [BattleServer/README.md](../BattleServer/README.md) | Ruby |

- The DLL's tests meet at a relay inside the test process (`TestRelay`), which never reaches the real one and closes a peer that sends too fast as the real relay does.
- Each script test file runs in a Ruby process of its own, since each brings its own stand-ins for RGSS and the game. They load the Mod Framework's scripts first, as the game does, from the folder `MGQ_MOD_FRAMEWORK_DIR` names (a framework release's `Patch/Mod_Framework` or a checkout's `GameScript/Mod_Framework`); without it, `run.rb` stops and says so. The workflows fetch the framework release `MOD_FRAMEWORK_REQUIRED` names.
- The script tests answer the C# topics with fixed values per case and check what the scripts ask and do with the answer; the rules themselves are tested in C#. The fake bridge round-trips every request and reply through Marshal and the core's plain-value check, so a test fails where the game would refuse a value.
- **Trap:** the script tests run on Ruby 3.3, not the game's 1.9.2, so they do not catch what only 1.9.2 lacks. The C# number parsing that copies Ruby (`RubyNumbers`) was checked against Ruby 3.3 only. Drawing, input and the game's own battle and event engine need the game.
- The JIT test hosts and the generator load SQLite from the `SQLitePCLRaw.lib.e_sqlite3` package (3.53.3), not the checked-in amalgamation the published DLL compiles in.
- Tests against a real game run only when their variables are set: `EVENTS_SOURCE_DIR` names the untranslated 3.06 copy (`MGQ Paradox src`), `BATTLE_GAME_DIR` the installed game. They check that both copies give the same fingerprint as the running game wrote to `Patch/Multiplayer/GameData.ini`, that the shipped database is the generator's build byte for byte, and that the story replay's gate classes both copies. `BATTLE_CORE_LIBRARY` names a built core library for the battle server tests that run the real one.
- The *Scripts* workflow runs the script tests on every push; the *Release* workflow runs everything before it builds.

### Building the battle server's core

NativeAOT cannot build across systems, so `MGQOnline.ServerCore/build.ps1 [-Version x]` builds the linux-x64 library in Docker (the pinned `mcr.microsoft.com/dotnet/sdk:10.0-noble-aot` image; the library needs `GLIBC_2.34` and links only `libc`, `libm` and `ld-linux`). For a battle server on Windows during development: `dotnet publish MGQOnline.ServerCore -c Release -r win-x64`. `BattleServer/tools/core_check.ps1` runs each sandboxed child's check in a privileged Ubuntu container as on the server; the *Release* workflow runs it before it attaches the library.

### Releasing

1. Push your changes.
2. On GitHub, draft a release with a tag like `v0.1.0` and publish it. Players read the notes as they update, so write them for players, not as a commit log.
3. The *Release* workflow runs the tests, builds the mod, attaches `MGQ-Online-0.1.0.zip` and builds and attaches `MGQOnline.ServerCore.so` (the mod zip does not hold it). Keep the zip name: the website's import takes it, and older releases' updaters look for `MGQ-Online-*.zip`. Its tests fail while the committed events database is older than the schema or the generator. If the run failed, fix the cause on `main`, then run **Actions → Release → Run workflow** with the release's tag.
4. Import the release on the website as a new version of the mod `mgq-online`, which the Mod Framework updates from.
5. Deploy the battle server: the release's scripts and events database into its game folder (`BattleServer/tools/deploy_release.sh`), the Mod Framework only when the release needs a newer one, and the core library (see [BattleServer/README.md](../BattleServer/README.md)). Its core reads the same `events.db` as the game.

Before a release, check the changes against the newest translation: the generator's `compare` counts which lists of a translated copy differ from the database (see below).

Relay r1 ran as a Cloudflare Worker up to 0.6.6.1 and is frozen there. Its source is gone from the tree: commit `babdbfca` moved r1 to the own server and set the Worker's lowest version to 0.6.7, and `729e4966` is the last commit that holds the source.

### Logs

- One log per day, `Logs\Multiplayer <day>.log` in the game folder, holds the DLL's and the scripts' lines in one timeline (script lines marked `[script]`), stamped with the day the game started, so a session past midnight stays in one file and every game of that day appends to it. Past 4 MB it keeps its newest 2 MB. As the DLL starts it deletes the mod's logs of other days and older per-session logs; other mods' logs stay.
- The scripts stage their lines into the frame's bridge batch, so a script line can land a few lines after a DLL line of the same frame. Lines written before the handshake wait for it; while the mod stays off the scripts write the file themselves, with the reason.
- **Trap:** Ruby's `at_exit` never runs. The game's Main section (the WF-RGSS Exit-EX plugin) ends the process with `ExitProcess`, and `AppDomain.ProcessExit` may never come in the NativeAOT DLL. The last moment the scripts run is the end of `SceneManager.run` (a quit returns, the window closing throws `SystemExit`, an error throws before the game's error box), so everything that must happen on close happens there: flush the log, flush the story's last writes and wait for the world room to send them (3 s at most). A world left for the title closes its story before its room for the same reason.
- A repeated line is counted instead of written again. The world's messages are summed into one line about every minute.
- A crash in native code ends the game before anything can log it. So the scripts log the game's memory at every switch of screens, and the DLL logs the crashes Windows recorded in its Application event log since the last start (never under Wine).

## Architecture

### Layout

| Path | What it is |
|---|---|
| `GameScript/Multiplayer.rb` | The scripts' foundation: loading, the log, the bridge client; loads the others |
| `GameScript/Multiplayer/Scripts/*.rbx` | The game scripts, one per area (Ruby 1.9.2 in RGSS3) |
| `GameScript/Tests/` | Script tests outside the game |
| `MGQOnline.Multiplayer/` | NativeAOT project -> `Multiplayer.dll` (win-x86): the bridge host, the network (relay, world rooms, directory), the files on disk, the topics |
| `MGQOnline.Bridge/`, `MGQOnline.Bridge.Native/` | The bridge between the scripts and C#, and its four exports |
| `MGQOnline.Game/` | The game-side rules, one folder per area, shared by the DLL and the battle server's core |
| `MGQOnline.Data/` | The events database over a static SQLite |
| `MGQOnline.Data.Generator/` | Console tool, run by hand: builds the events database from the untranslated game |
| `MGQOnline.ServerCore/` | NativeAOT library -> `MGQOnline.ServerCore.so`: the bridge's C# side on the battle server |
| `*.Tests/` | xUnit tests of the project of the same name |
| `Relay/` | The relay server (Node), see [Relay/README.md](../Relay/README.md) |
| `BattleServer/` | The battle server: the game's battles without Game.exe, see [BattleServer/README.md](../BattleServer/README.md) |
| `MGQOnline.Data/native/` | The SQLite amalgamation and its build targets |
| `package/Multiplayer/` | Static files shipped as they are, the events database among them |
| `docs/` | This file and the player guide (`GUIDE.md`, `CLASSIC_WORLDS.md`, `RAID_WORLDS.md`, `images/`) |

### How the parts connect

```
game scripts (Ruby 1.9.2, RGSS3)
   | Marshal plain values over four DLL exports (topics, one batch per frame, events drained per frame)
Multiplayer.dll (win-x86): bridge host + MGQOnline.Game rules + network + files
   | HTTPS and one WebSocket per world room / per served battle
relay (Node) -- battle server (Ruby + the game's scripts + MGQOnline.ServerCore.so over Fiddle)
```

- **Scripts read and apply; C# decides.** A script reads what only the game knows, hands it to a topic, and carries out the answer with the game's own methods. New logic goes to C#. No script writes or reads a message's text, a network format or a store C# reads; the formats that stay inside the game are the bridge's Marshal, copies of game objects, the game's own saves and event scripts, and a frozen fight's save field. No test guards this; reviews check it.
- **Rules both hosts need** (the battle server runs the same battle scripts) are registered on both through `SharedTopics`, so a script asks them the same way in the game and on the server.
- **The Mod Framework** owns the interface (components, wheels, text boxes, question box, places, looks), the keyboard, mouse, button capture, running behind other windows, the mod loading stages and updates. MGQ Online builds on it and keeps no input or drawing engine of its own; only `ModFramework.dll` hooks the game's window.
- **The relay** keeps worlds, the directory, trades, a Raid World's story tracks and boss pools, and routes world room messages it cannot read (sealed per sender). **The battle server** hosts co-op battles the relay hands it, as a stand-in host with no world room of its own.

### Where state lives

| State | Where | Who writes it |
|---|---|---|
| Player key, name, hotkeys, settings, favourites, hidden worlds added | `Patch/Multiplayer/Player.ini` | the DLL only |
| A world's code, settings and saves | `Patch/Multiplayer/Worlds/<id>/` (`world.ini`, `Save/`) | the DLL; the game writes saves through the redirect |
| A world's story, boss pools, shared companions, mods, settings | the relay | the relay alone changes them |
| Notes a save must carry (catch-up, replay log, frozen fights, raid rewards, trades applied, side pick, repair mark) | fields of `$game_system` in each save | the scripts, from the DLL's answers |
| Events of the untranslated game | `Patch/Multiplayer/Data/events.db`, shipped, read-only | the generator |
| The game's copy of the relay's story mapping | `Patch/Multiplayer/Data/story.db`, in no manifest, never shipped | the DLL |
| The game data's fingerprint for the World Admin tool | `Patch/Multiplayer/GameData.ini` | the scripts, as the title first opens |

### Rules that hold everywhere

- **Nothing blocks the game.** The DLL's threads run the network; every export returns at once.
- **Nothing throws into the game.** Every export and the DLL's threads catch everything; an escaping exception would end the game.
- **One clock: the bridge's frame.** Scripts read `Bridge.frame_number`, C# reads `BridgeContext.Frame`; rules never read a wall clock. `Graphics.frame_count` goes back when a save loads, so no timer uses it. The few exceptions are deliberate: the raid pools follow the relay's clock, the time a player entered their map is compared across computers, and a few waits count milliseconds because a player in a menu counts no map frames.
- **Ids come from a `Random` of the bridge context**, never the game's `rand`: battle replays and seeded log lines follow the game's random stream, and an id drawn from it would shift every seed after it.
- **Versions never mix.** Different mod versions never speak the same protocol on purpose. The relay alone tells which release the games must play; an outdated game keeps worlds, duels and trades shut and asks for the update, rather than failing mid-exchange with a friend's newer game.
- **Released versions still matter** where they meet this one: the relay's new text frames are logged and dropped as unknown by released DLLs, so a push may only add frames; formats players keep (Player.ini values, world settings, trade offers, world locks) are written as every release wrote them.

### Ruby 1.9.2 and RGSS3 traps

- RGSS3's Fixnum is 31 bits. The bridge writes larger integers as Bignums (1.9.2 reads a larger `i` wrong), and hashes the scripts compute (the 24-bit list shape) stay below it.
- `at_exit` never runs (see Logs).
- The game's Win32API refuses to load an export with more than 16 arguments.
- RGSS3 has no Fiddle; the battle server's newer Ruby uses it to load the core.
- RGSS3's `downcase` and `capitalize` are ASCII-only, so C# copies them (`RubyAscii`) where the scripts compared names before ("Élise" and "élise" stay two names).
- The game's Ruby reads file names in the system's code page, so the DLL lists the Patch folder's scripts in UTF-8.
- The game's plugins load after the Patch folder and define methods anew (`Scene_Battle#battle_start` and `#turn_start`, `Window_BattleLog#add_text`, the Yanfly plugin's `command_101`, `Game_Party#battle_members`, `Window_BattleStatus`), which drops a hook installed before them. Such hooks go in once the first scene starts (a `SceneManager.run` hook), and a method wrapped twice keeps each wrap under its own name.
- Marshal data from another game can run code. Only plain numbers and texts cross between games, never save data, and a starting save is checked for classes before Marshal reads it.
- The game is a 32-bit process: it runs out of a free block of the size it asks for long before its address space runs out.

## The scripts in the game

### Loading

- `Multiplayer.rb` is a Patch folder mod that loads the other scripts itself, once each, in the order of its `SCRIPTS`. They are `.rbx` files because the game's loader recurses into folders and would load `.rb` files a second time, in alphabetical order.
- **Order matters.** A script may use only what loaded before it at load time; later ones are reached at run time (`defined?`). The order also decides how the battle scripts' hooks wrap each other, since they install them as the game starts running, the last loaded first. A script that fails to load is logged and the others load all the same.
- **Under the Mod Framework** the mod is a Title mod in three stages: as the game starts it loads the log, hooks, hotkeys and look and adds the title's *Multiplayer* command; picking it loads the world screens; the rest loads as the player enters the game (New Game, a load, or a world, right before the world's save loads or its New Game starts). Never load before the world screen goes back to the title: the framework would make that a restart once the game counts as entered. A player who backs out of a world's New Game question has entered with the world's mods, so the game starts again into the world screen rather than letting Continue run with them.
- A script of the world screens that joins a later script's registry waits for `Stages.when_loaded`. Every hook sleeps in a game entered without the mod (turned off on the title's Mods screen after its title part loaded).
- **Trap:** the Russian translation's own `Patch.rb` loads only `Patch/*.rb`, reads each as it is (a byte order mark breaks the file) and catches no error. So `Multiplayer.rb` is ASCII only and catches the errors of its own load, writing them to the log at once and showing them in the game's message box.
- The mod requires a booted Mod Framework of at least `MOD_FRAMEWORK_REQUIRED`; without it no script loads, and the log says why. When no framework is installed at all, the game's own message box (`msgbox`, which needs nothing of the framework) also tells the player where to get it, once per start.

### Hooks

- A game method several scripts follow is wrapped once, by `core_hooks.rbx`; scripts register `before` and `after` blocks under their own name. They run in the order nested wraps would (before blocks from the last script loaded to the first, after blocks the other way), so the old order of effects holds. A failing block is logged once and the others run on.
- A hook that changes what a method does or returns is an `around` registered under the script's name, so a script loaded again replaces its wrap instead of wrapping twice.
- Only what the registry cannot express stays a plain alias: `world.rbx`'s redirect of `File`, `Dir` and `Bitmap#initialize` into a world's save folder.
- `MGQ_MpHooks.plain` names the game's own body of a hooked method; the story replay runs the game's interpreter without any script's hooks through it.
- Holding the player (no move, no menu) goes through one registry, `MGQ_MpHooks.hold_player`.

### Reaching the game

- `core_game_access.rbx` reads and writes what the game keeps private, by key, in one place, so a game update that renames a field is followed in one script. The game's classes get no accessors of the mod's own, since another mod's could clash with them.
- Hotkeys are defined through the framework and keep their keys in `Player.ini`, since `$game_system.conf` lives in each save. A hotkey is refused while any mod types (`UI.typing?`) or the question box is open, so nothing opens under them; while a mod types, a key is a letter typed and no refusal is logged.
- The game's cancel as the player bound it, plus Numpad 0, closes every screen of the mod (`UI.cancel?`). Every text box is the framework's `text_field`; a new screen should take it too.

## The bridge

The bridge carries plain values between the scripts and C#: nil, true, false, Integer, String (UTF-8, US-ASCII or binary), Array, and Hash with String or Integer keys, as Marshal 4.8. Anything else (a Symbol, a Float, a game object) is refused by name; the call answers nil and logs why. The core (`MGQOnline.Bridge`) holds no statics with state; everything hangs off a context, so the DLL and the battle server's core run the same code.

- **Exports:** `mp_bridge_open`, `mp_call`, `mp_reply` and `mp_drain`, stdcall, nothing else (a test checks the DLL exports nothing beside them). Without an installed host they answer 0, as a stand-in DLL does (JoiPlay), and the mod stays off.
- **Trap:** NativeAOT exports a referenced assembly's entry points only when the publishing project names it (`<UnmanagedEntryPointsAssembly>`), and runs a module initializer only for an assembly it compiled code of. A library that installs its host from a `[ModuleInitializer]` must also be rooted (`<TrimmerRootAssembly>`), or the exports answer 0 for good. A test checks the DLL's project does both.
- **Handshake:** a version mismatch, a missing DLL, a DLL without the exports or one that answers 0 keeps the mod off with one log line. Only a handshake that succeeds sets `MGQ_Multiplayer.available?`. A new handshake closes the older contexts, since F12 restarts the scripts but not the process.
- **Calls and replies:** a reply larger than the caller's buffer is parked and handed out by `mp_reply`, so a handler never runs twice. The scripts load a reply at once and never keep the slice, since the next call writes into the same buffer behind Ruby's back. A failing handler answers an error envelope; the core logs the first failure of each topic and code.
- **One batch and one drain per frame:** what scripts stage during a frame goes as one `batch` call from the `Graphics.update` hook; then one `mp_drain` passes the frame and hands back every queued event. Network threads never touch the queue; they hand their work to a frame step. An event of a topic no script takes yet is held until a handler registers. A status topic keeps only its latest event.
- **Full mode** reads game data, through a pruner that leaves out fields no reader needs: the game's 49 MB `CommonEvents.rvdata2` read whole takes about 650 MB, more than the 32-bit game or the server core's heap take.
- **Floats and Symbols** cross as tagged Hashes (`{"float" => text}`, `{"symbol" => name}`, `WirePlain`); C# writes Ruby's float text exactly.
- **Adding a topic:** register the handler in the host's setup (`GameBridge.RegisterTopics`, `ServerBridge`, or `SharedTopics` for both), call it with `Bridge.call` or stage it with `Bridge.stage`, take its events with `Bridge.on`. Cover the handler with xUnit and the script with the fake bridge.
- **Changes in worlds** come as one bit set per drain (`worlds.changed`), so the world screen asks for rows and details only after a change.

## The battle server's core

`MGQOnline.ServerCore` is the bridge's C# side on the battle server: the same four exports over `Bridge`, `Data` (SQLite linked in) and `Game`, with no network, no file writes and `InvariantGlobalization`, so it loads nothing from `/usr/lib` once a battle's sandbox hid it. The battle server's Ruby loads it through Fiddle (`BATTLE_CORE_LIBRARY`).

- **Traps of the fork and the sandbox:** nothing calls the core in the parent before a fork; a child of a process whose .NET runtime started hangs at its first garbage collection, since a fork copies no runtime thread. Each child loads the library after the fork and before the sandbox (the chroot hides its path), and opens it (the handshake starts the runtime) after the sandbox closed, so the runtime starts under its limits. A child reads its setup's mods in Ruby before the sandbox, since the sandbox reaches neither the network nor the mods' cache.
- **One Ruby thread calls the core:** a Fiddle call releases the GVL and the bridge keeps one reply buffer. So the relay connection's reading thread only queues lines, and the game's thread hands them to the core.
- **GC:** workstation and non-concurrent (one thread less per child against the sandbox's process limit), heap limit 256 MB baked in. The GC reserves about five times its limit as address space, which must fit the sandbox beside the game. `DOTNET_GCHeapHardLimit` overrides it, in hexadecimal without `0x` (NativeAOT reads `0x10000000` as no limit).
- **Events database:** opened immutable and read-only, so a sandboxed child writes no journal or temporary file; it is checked against the game data's fingerprint the scripts hand over after each handshake.
- **A server without its core** refuses every MGQ Online battle with the code `core` rather than hosting it half; the starter then hosts it and stops asking for the session. The core writes no file: each of its log lines becomes a `log` event, which the server writes into its own log.
- The core derives the story mapping's index of shared events for the relay (see [World story on the relay](#world-story-on-the-relay)), refused while its database differs from the server's game data in the maps or common events.

## The events database

The game's events as numbers, built once from the untranslated 3.06 by the generator and shipped, so the DLL and the server core never read the game's data files for events (`MGQOnline.Data`, schema in `Events/EventSchema.cs`).

- **Why numbers only:** no name or text is stored, so a translation leaves the database valid. Each list carries a shape, a 24-bit hash over the codes, indents and whole-number parameters of its kept commands, which stays a Fixnum on RGSS3 and changes with a branch, call, troop or variable but not with a translated text. Commands are numbered among the kept commands (`ord`), which a translation leaves where they were.
- **A list is used only while it matches:** the scripts name a list with its length and shape; a list the database does not hold as the game shows it (a translation's changed branch, another mod's list) is handed over whole and still sorts. `LocalMaps` compares each map file's pages with the database and reads a map a mod changed from the player's own data. Before the scripts hand the fingerprint over, nothing of the database is read.
- **The fingerprint gate:** the game data fingerprint has one CRC32 per part of the database (actors, items, troops, common events, maps, ...). A mod that changes another part leaves the maps' and common events' tables readable; a part that differs is not read.
- **Static SQLite:** the public-domain amalgamation is checked in untouched (`MGQOnline.Data/native/sqlite/`); every NativeAOT publish compiles it into the binary, so no SQLite library ships and no compiled library is ever checked in. To move to another release, replace both files from sqlite.org's amalgamation zip. The flags leave out WAL, extensions and shared cache and keep temporary tables in memory, since a sandboxed child may write no file.
- **Read-only and immutable** (`file:...?immutable=1&mode=ro`): no lock and no journal, so it works in a read-only game folder, under Wine and in the sandbox. A missing file, another schema or a non-database makes the store foreign: it opens, says why, and answers nothing.
- **The relay mirror** `story.db` holds the game's copy of the relay's story mapping beside it. It is never swapped as a file, since a file attached cannot be replaced on Windows: the tables are emptied and filled in one transaction. A torn file is deleted and made anew, never repaired; a folder the game may not write leaves the store without a mirror. It is in no manifest, so an update never removes it.
- **Regenerating:** whenever the game data, the schema or a generator rule changes, build and commit again, then check:

  ```powershell
  dotnet run --project MGQOnline.Data.Generator -- build "<MGQ Paradox src>" package/Multiplayer/Data/events.db
  dotnet run --project MGQOnline.Data.Generator -- check "<MGQ Paradox src>" package/Multiplayer/Data/events.db
  ```

  `check` must say byte-equal (`VACUUM INTO` gives the same bytes for the same rows and SQLite). CI never generates it, since it has no game data. The file is committed as binary, without Git LFS while regenerations stay rare.
- **Other generator commands:** `fingerprint <game folder>`; `compare <events.db> <other game folder>`, the release's check against a new translation; `names` (the story keys' names from a translated copy, since the database holds none); `ordinals` (rewrites the relay's join and removal indexes into ords); `story-ids Relay/core/story_ids.json` (the relay's copy of the story's ids).
- **The build fails** on a command code or script root the story replay does not class (see [Runs handed over by replay](#runs-handed-over-by-replay)).
- **Hand-written raid rules** (`RaidRules`: the boss switch 22, the preamble, the excluded maps 154 and 576, the arena switches 87 and 97, the post-defeat processing common event 3000) stay hand-written until the Raid Designer redesign owns them. The raid bar and the raid freeze still walk some lists themselves for the same reason.
- **Repair pairs** drive a one-time repair of saves the 0.6.9.2 chest path left stuck ("Issue 73 chest effects.md", E2): a gift page whose self switch, once on, proves a story switch on. Three gates keep a pair safe: nothing else turns the self switch on, every list that turns the switch off also resets the self switch's map, and no game script or database entry uses the switch.

## Game rules (MGQOnline.Game)

A net10.0 library, AOT-clean, BCL plus `Bridge` and `Data` only, no state in statics, one folder per area. The DLL answers the scripts with it through topics in `MGQOnline.Multiplayer/Topics/`, the server core through `ServerBridge`; rules the battle scripts need on both go through `SharedTopics`.

- **Event sorting** (`Events/`): what a page or list is for a party (story, talk, travel, chest, battle, own) and what it reads and writes; see [Events in a party](#events-in-a-party). The rules read the game only through `IEventSource`, answered by the database or, outside it, by the game's own data.
- **Battle lines** (`Battles/Wire/`): the codec of live battle messages. It reads with the same refusals Ruby did (512 KB, 8 deep) and gives nil for a token naming nothing the reading game has; the script then finds each id within its own tables and each symbol among those the game already has, never made from the peer's text.
- **Builds** (`Actors/`): characters as text for co-op and PvP. Builds are live texts only, never stored. Reading another game's text (field counts, ranges, ids) is C#'s.
- **Telling, story pages, gather calls, story scene, flow guard, choices, catch-up, story tracks, raid pools and bosses, co-op matchmaking, trades, chat, HUD, overview, forms, worlds**: each folder holds the rules of the feature section of the same name below.
- `StoryIds` is the one table of the story's ids (markers 1001 and 1141-1143, the Great Decision's step, routes, clears, castle bosses, places). No story id is written as a number or key in a script, relay module or C# file outside the table (no test guards this; reviews check it). The relay reads them from `Relay/core/story_ids.json`, written by the generator; `StoryIdsTests` fails while that copy differs from what the generator writes.

## Worlds

A world is a lasting place up to 32 games play in at once. There is no host: every game takes a seat in the world's room at the relay.

### Codes, keys and the directory

- **The world code** (`mgqmp2;<token>;<relay>;<seats>`) never changes; whoever holds it may enter. The world's folder is named by a hash of the token, so it never gives the code away.
- **The password locks the token:** PBKDF2-SHA256 (600,000 iterations; locks of released versions have 200,000), then AES-GCM, so the relay only keeps the lock. The DLL derives PBKDF2 itself, since .NET's goes through a BCrypt pseudo-handle no Proton release supports. An empty password locks it too and marks the world `open`.
- **Proving the token:** every connection sends an auth key (HKDF of the token, apart from the frames' keys and the room id). The player's key goes in a header, never in an address; the relay turns it into the id everyone sees, and only the creator's key may delete the world or remove a player.
- **One key per sender:** each game derives its frame key from the token and a salt it picks per connection; sender and target seats are authenticated, so a frame passed on under another seat fails. Salts of games that left are refused from then on.
- **The directory runs one action at a time** on a thread of its own; each of the DLL's machines claims the action it starts (`DirectoryTickets`), so the world screen and the shared settings never take each other's answer. The DLL reads the relay's JSON by hand, since NativeAOT leaves out what serializing by reflection needs. The directory checks seats and squad rules before it asks the relay, so the form check is not the only guard.
- The list carries a world's mods only for the world opened last; other worlds' mods are read on demand (`mods_unread`), and the screen reads a world before entering or editing it.
- **Hidden worlds by id** are kept in `Player.ini`, the 50 added last only (the relay's limit), so deleted worlds' ids do not crowd new ones out. Whoever holds the id sees the details but still needs the password.
- **The starting save** is zipped and sealed with a key from the token before the world is made, so a save that cannot be read or is too large leaves no world behind. The world is made with `start: true`, which keeps everyone out until the upload arrived; a failed upload deletes it.

### The connection

- **Versions:** every request and the world room's WebSocket carry `X-MGQ-Features` and `X-MGQ-Version`. The relay turns away a game without features (builds before 0.6.0) or below its `MIN_VERSION` with "Update MGQ Online to play online." (426, or 400 with the code `update` on a world room, which released 0.5.1 to 0.6.4 read as final). Every refusal of the version raises `update.needed`. The World Admin tool names itself `0.0.0-dev` so `MIN_VERSION` never applies to it.
- **A session ends for good** on a world the directory lacks, a token that no longer fits, a removed player, a full world, the close codes 4009 (removed or `replaced`) and 4010 (deleted), or an update refusal. **Trap:** a `replaced` close can come from this game's own earlier connect that was cut when the world was left or entered again (the relay may hold a request past the connect's timeout); within a connect timeout after such a cut it connects again instead.
- **Coming back by itself:** a cut connection, 60 s of silence or the relay's 2-hour limit lead back after 2, 5, 10, then every 30 s; the game plays on meanwhile, and the seat may change.
- **Pacing:** the DLL sends at most 50 messages a second after a burst of 200, below the relay's 60 after 240, which closes a faster connection with 4003. It delays and never drops. Sends to many players go out once and name the receivers (`mto`), since one send per seat ran past the relay's limit on a busy map.
- **Messages** are `key=value` lines and a body, written and read only by C# (`MessageFields` names the fields that hold more than a text); the scripts hand over values and get values back. A state is any message with the marker `state=1`, so a state field may share a route's name.
- A state goes out only when it changed: every incoming message counts against the relay's plan, so a player standing still sends nothing.
- The relay reads the global chat (a copy as the text frame `chat`) for the world's admins; the line itself still goes to the others sealed.

### Files on disk

- Only the DLL reads and writes the ini files. A write goes to a `.tmp` next to the target, is flushed and moved over the target in one step. A read takes UTF-8 with or without BOM, UTF-16 by BOM and anything else as Latin-1 (Notepad's ANSI).
- While `Player.ini` exists but cannot be read, the DLL never writes it and makes no key, so no world action runs; the player is told once. The scripts hand true, false and whole numbers, which the DLL writes in the form every release wrote.
- The player's key is made the first time and never handed to the scripts.

### A world's own saves

- Entering writes the player's own system save, then redirects every path below the game's `Save` folder to the world's (`File`, `Dir`, `Bitmap.new` for thumbnails) and loads the world's system save (Library, system switches, affection, which the game otherwise shares between saves). The game names `Save/` in many places (backups, thumbnails, the temporary file), so paths are changed where they reach the files, and only while a world is open. The game's options live in each save and are unaffected.
- A world without saves goes back to the title, whose own New Game starts it, so everything the game and other mods do for a new game happens. Leaving (To Title, reset, game over) writes the world's system save and puts the player's own back.
- Copying a world's save to the player's own `Save` folder writes past the redirect (`Files.unmapped`).

### Game data across games

- The fingerprint reads no names, since the translations name entries the untranslated game leaves unnamed; the untranslated game and the English and Russian translations give the same one.
- Under the framework the title has loaded only Framework and Title mods, so the data is compared only once the world's mods loaded, right before the world's save loads. The fingerprint the title measured stays the one the DLL keeps and served battles carry, since the battle server measures its data without the world's mods.
- A game whose data differs is warned and plays on: going back to the title from there would restart the game. The creator's game makes its data the world's at each entry, so after a mod update the others are compared with the creator's game as it is now.

### Updates

The Mod Framework finds and installs every mod's updates, this one's too (website mod `mgq-online`, tagged Title). The relay alone names the release the games must play, newer or a step back; then *Multiplayer* on the title, a Discord invite and the entry after a restart ask the framework for it instead of opening the world screen, and the framework restarts the game into the world screen. The DLL passes its own version (`:have`), since the framework reads a changed copy's version as unknown. MGQ Online has no updater of its own; a player whose game cannot start extracts the release by hand.

## World mods

- **Required (`!`) mods must match** in every game, by the creator's copies written with the world: the version of each mod the website has (`modVersions`, from the framework's `Mods.state`) and the hash of the script of each other one (`modHashes`, SHA-256 without carriage returns). The DLL compares them with the mods the framework lists, which the scripts hand it (`mods.framework`) as the world screen opens, after an install and each second while the framework fetches the website; without a version or hash, being installed and on is enough. Essential (`?`) mods have no script to look for, which suits data mods.
- Names are compared by a mod key (`ModKey`): a world's name matches an installed mod's name in Patch, its title or its website slug.
- **Differing mods** go to the framework's dialog, which installs them; where a running mod changes, the framework restarts into the world (`multiplayer.rejoin`). A world this PC has no folder of asks for its password again then, since no file holds it.
- **Shared mod settings:** the world's settings for its mods' *Options → Mods* rows apply whenever a save of the world loads or starts and show greyed out; never the game's own options, hotkeys or personal rows. The DLL owns their text (`key=type:value`, as every release wrote it). **The relay's latest settings win:** before the creator's game sends, it reads the relay's, so an admin's change is never overwritten; only the creator's own changes are joined to them.
- **Options for the website:** mods build their rows as they load, often from constants and method calls, so only a running game knows them. An admin's game sends them once a session per website mod's version to `POST /api/mods/<slug>/versions/<version>/options` with its player key in `X-MGQ-Player`, for the website's world settings editor.
- **Turn off other mods:** the framework loads only the world's mods, the mods the website marks `personal` in `GET /api/mods`, the mods every player has and those that run from the start (which nothing can take out). The DLL fetches the website's list with the world list, and the entry waits for it, since only it tells which mods are personal. Nothing moves in the Patch folder any more; files an older release parked in `Parked mods` are put back as the DLL starts. A changed rule restarts the game into the world once the map is free.

## The open world

### The world room

The DLL keeps the open world (`WorldRoom`): the other games, the party, the inbox, the ping and the gates. The scripts hand the player's state each frame and get views and routed messages as drained events, each posted after the views it depends on.

- **Gates:** a message goes to the first route registered for its field: C# routes first, then the scripts'. The party's gate passes only an admitted member's message naming the party; the map's gate only a player on the player's map (or naming it, or the story's map). A field a C# rule takes never reaches a script.
- **Presence:** after every (re)connect every game tells everything and others are kept for a grace of 900 frames (`Sessions`, the one owner of presence and battle sessions); a game that went is the same player when its id tells again on any seat. Shared names are numbered by id ("Name (2)").
- The "joined the world" notice waits for the first 300 frames, since every game tells a newcomer at once.
- The battle server keeps no world room; its scripts fill their mirror from the starter's word and the battle channel.

### On the map

- Ghosts are `Game_Character`s with `@through` that walk one tile at a time toward where the player stands and jump when far; they trigger nothing, since only the player and events check triggers.
- The scripts that load after the sync join it at load time (routes, state fields, ticks, presence); a failing block is logged and left out.
- Labels, pings and the own line are framework boxes that follow a character; they open in a fixed order so two players on one tile stack instead of drawing over each other.

### The world never pauses

In single player the map stops behind menus, battles and story scenes. In a world it goes on (`core_async.rbx`), so what others see and what the player comes back to never waits.

- Behind every screen but the map, title and game over, the map updates without the player moving and without its main event. Commands that would reach the player (messages, choices, transfers, battles, shops, scripts, music, `HELD_CODES`) yield until the map runs them again; an event that starts by touch or autoruns only marks itself.
- The field music refresh is left to the map, since it would cut into a battle's music.
- **The live map behind menus** shows only while the largest free block of address space is at least 64 MB; a 32-bit game runs out of a block of the size it asks for long before its free space as a whole (140 MB largest of about 600 MB free in the in-game tests). The crashes in RGSS301.dll behind menus (issues 42 to 70) were not a lack of memory but a sprite or window left on a viewport the game freed, which the Mod Framework now moves off first. A menu passes its live map to the next menu, so no second spriteset is built.
- Between the map and menus the freeze and transition are skipped, since even a zero-frame transition takes about 117 ms in which the world stands still. Battles, story scenes and the title keep their fades.

## Parties and the map

### Parties

- The party is the DLL's; every state carries the player's party id, admitted members and invites, so a party needs no message of its own. At most four players, one per Frontline place. The leader is the player whose id starts the party's id, else the lowest id.
- Ghosts outside the party are see-through in a Classic world and solid in a Raid World, where everyone on the map shares it.
- **Teleports between members:** at once to the leader; to anyone else once they allow it. Each request is answered once and an older answer is ignored.

### Party or map

`MGQ_MpCoop::Scope` answers whom the player shares the map and the story with: the party in a Classic world, everyone on the map in a Raid World. Every co-op script asks it, so Classic worlds behave as before. In a Raid World who tells the story on a map is the relay's telling lock (one per map and track), not the party.

### Squads

- A party shares one single-player team: each player keeps a squad of their first characters and the rest are cut. The split and order are C# (`SquadMath`), since the battle server arranges its players too; scripts cache answers by request, since the game's hooks ask many times a frame.
- Variable 56 is each player's own, since the game cuts its party list to `party_member_max` on every change and a leader's smaller value would drop a member's characters.
- The formation list and the party edit screen take their looks through the Mod Framework's row patch (`UI.patch` with `rows`), so the game's and the translation's drawing stays.
- **In a Raid World** every player has a squad sized by the world's rules. The cap applies only to the `$game_party` fitted to the current rules and is lifted for a story's temporary party (a cut character would leave the story). Luka is never swapped to the front by the game's follower command, and Give Up is off unless he leads, since Give Up swaps him to the front.
- The game's Backline window and swap count from `max_battle_members`, which is why the Frontline is narrowed there.

### NPCs in a party

One game, the Map Owner (the earliest `since` on the map, then the lower id), moves the map's events; the others follow. Every game finds the same owner without asking.

- `since` starts anew after leaving the world, a load or a new game, so a returning player never takes the owner role at once; a reconnect keeps it. A player whose connection is down no longer counts.
- A follower takes no part of a map before its full picture: the last map's places on a new map's events of the same ids once put Hades' exit into a wall.
- While the player's own event runs, the follower moves no event, since that event's move routes would wait for events held elsewhere for good. Others never block an event's forced route nor any event while the story plays, for the same reason.
- An event on another page than the owner's (another story state) or talking to the player stays where it is.

## Story

The party's story (Classic worlds) and a Raid World's story share one state model (`story_state.rbx`): switches, variables and self switches read and written as raw data, and a table of what stays each player's own.

- **Raw data, not `[]=`:** the game's own setter runs side effects (a switch in 1001-2000 adds or removes a companion, an awakening switch refreshes an actor, affection writes through to the global system).
- **What stays each player's own** includes the side switches 4 and 5 until the Great Decision, configuration switches, party membership 1001-2000, awakening 6000-6999, chest flags, the medals handed in (55, 59), the return point 1002, friendliness 2000-2999 and affection from 3000. Switches from 7000 (bosses defeated) belong to the story.
- **The warp ban (switch 100) never stops a player in a world:** it is turned off again after every write and after a load. Only the warp spell, the warp items and the Pocket Castle's common event 3 read it, so nothing else depends on it.
- **The Realm of Chaos** (map 1836 and below) is gated in a Raid World until the world's story has the ten chains, since the God of Chaos otherwise plays the bad end. A refused move goes to the flow guard, which brings back the screen the scene faded out.

### Events in a party

Every event page is sorted as it starts, since the answer depends on the game's state; the DLL sorts (`EventSorter`), and no script keeps a rule of its own.

- Only commands that can run now count; called common events count up to 5 deep, except the player's own common events (2, 3, 5, 114, which every exit calls).
- **Kinds and why:**
  - *Battlefucks* (a page that can call common events 6999 or 7000) are the player's own: they play in the game that starts them.
  - *Pocket Castle* companions' pages and service pages are talks whatever they set, so each player talks to them in their own game (issue #53); only the speaker's affection variable tells them apart from story.
  - *Exits* that set bookkeeping flags without dialogue are travel, so a member takes the exit in their own game.
  - *Story* sets a key that is neither scratch nor the player's own, changes the party, uses vehicles and the like. A self switch with dialogue alone is a one-time talk.
  - *Chests* give items or gold and set their own self switch.
  - A talk or travel with story only behind a choice is watched command by command: at the first command that moves the story on, the leader tells it as story and a member's game ends it. The Great Decision and 216 other pages hold their transfer behind the same choice as their story.
- A sort the DLL cannot give plays as a talk, logged once.
- **Chests** are each player's own; in a Classic party opening one opens it for the party by replay (see [Runs handed over by replay](#runs-handed-over-by-replay)).

### Story scenes together

- **Gathering (Classic):** the leader's story scene waits at its first command while members are away, calls them, and plays once they stand near or after a hold. A called member meets no random encounter and turns battle invites down, so nothing new holds them. A call lapses after a few seconds without a new one, so a member is never brought over to a scene that started without them.
- **Trap:** whether a map exists is read from where the game keeps it (`Data/Map/Data` for 1000-1999, `Data/Map2/Data` for 2000-2999); `Data/Map1650.rvdata2` does not exist, and every follow onto such a map was once dropped.
- **Trap:** a call that waited through a duel and moved the player as the map started again left a lasting black screen (field test 2026-10-04). A member is moved only on a settled map (no PvP battle, no Library battle, full brightness), and a duel's restore drops a waiting call.
- **Raid Worlds** gather nobody: whoever is on the map watches. A transfer of the telling takes along those on the map at once only while they watch it, are not behind and the telling moves the world's story on (the DLL decides, issue #61); others get an offer to follow. While a player is on the way their own copy of the story event is kept from starting, so the scene does not play twice.
- **Pages:** the teller's message pages go to the viewers, who show them in their own message window and wait for the teller's "done" plus a reading time. While the teller holds the skip key, at most one page per 10 frames goes out, since two messages per page every frame ran past the relay's limit and closed the connection. Pages are caught in `Game_Interpreter#wait_for_message`, since the Yanfly plugin writes its own `command_101` after the Patch folder loads. A page that fails to hold waits for the player's buttons, since an error there would end the game. A viewer's pages give way to a follow or battle invite that would otherwise lapse while pages keep them busy (field test 2026-10-11).
- **The scene** (pictures, screen effects, move routes, camera, sounds, map look, zoom) goes to viewers too, but only changes made inside the map's main interpreter count; parallel events stay the teller's own. The interpreter is told apart rather than the command, since a command may wait frames before it runs. A viewer checks every change before it applies it (`SceneChecks`): the game keeps the arguments, and a wrong one raises or hangs in its update each frame. A move route the viewer takes always skips a blocked step, since their characters stand elsewhere.
- In a Raid World the scene also sends the story's values, since the world's story reaches viewers only once the telling ended and the scene's characters would otherwise stand on no page.
- Several changes go as one batch message below the DLL's 256 KB frame; a lone change still goes as a single message, which earlier builds take.
- **The flow guard** (`coop_flow.rbx`, rules in `FlowGuard`): wherever the mod cuts, skips, moves or ends a game event, the game's own flow cannot put back what it set (a dark screen, a hidden character, a temporary party, a ban), so the guard does, for every such place. It only lifts, never starts what the rest of an event would. The rules without an interrupt point: a screen left dark while the player stands free and nothing runs fades in, and the pictures a loaded world save shows go as the game runs on from the load while nothing runs.

### The party's story (Classic worlds)

- Members synced with the leader (close enough in the main story or on the same route past the Great Decision) borrow the leader's story and get their own back when they leave. A member who is not synced plays their own story completely.
- The leader sends the whole story once, then deltas of what their game wrote, recorded at the write hook, so no comparison of the whole story runs. Variables carry only numbers, strings, Floats and true or false, so no message can make objects in another game.
- How a member keeps the story depends on how far along they were: behind keeps what they played together, as far records and lays it over their own, ahead gets their own back unchanged.
- Every save made while borrowing holds the member's own story with their own values.
- Both sides wait for the relay's reward tables before any story moves, since a member would otherwise catch up with nothing or with both sides' rewards.
- **Named exceptions:** the leader lends key items to a member ahead (a loan, never saved, so a crash or load borrows again), and the side the player took along in Iliasville is asked of a player who lacks one. A member who follows a leader past the Great Decision catches up with the side rows of the leader's side, the one the switches show, whichever side they answer.
- The Pocket Castle's way-out variables (21-23) are each player's own and set on arrival, since the leader's sent a member to an old save's place.
- Under the reviewed list and replay, only world keys follow the leader by value; chest keys are each member's own copy, and runs reach members by replay. A derived entry's answers are never asked, so a player caught up past a trade gets its item silently and pays nothing.

### The story's choices

- A member makes the story's choices for themselves. The outcomes come from a walk of the game's data, kept as committed data in `ChoiceTable.Outcomes.cs` (its generator command is gone); `ChoiceTableTests` fail when a label names no walked outcome or the other way round.
- In a Raid World every choice is each player's own; a choice the world's story carries the player past is asked once they are free. The Navy's and Pirates' lines' self switches are each player's own, so one pirate's treasure leaves the next pirate's chest full.
- A choice whose run a stream hands the player is asked during the replay; the old outcome rows are frozen history for choices before the stream began.

## World story on the relay

A Raid World's story is the relay's, key by key, on its story tracks (protocol in [Relay/README.md](../Relay/README.md)): the world's track, and a track of their own for each player behind. Every game keeps a copy in its own `$game_*`; the relay alone changes it. The game sends what its events write as requests, applies them at once so the event reads them, and writes what the relay hands back straight into its story: nothing is merged. Classic worlds keep no story on the relay.

- **The story mapping** (one for every Raid World) says which keys a track keeps; a key without a row is each player's own. It is filled by hand after review, never imported. Its index of shared map events (those that read or write a shared key, through the common events they call but not the player's own) is derived by the battle server's core from the shipped events database. The game keeps a mirror (`story.db`) so a start fetches nothing but `same`, and an unreachable relay still leaves the table.
- **The mapping check** (`MappingCheckTests`) holds every reviewed row to the shipped events database. The transfer variable v57 is named by hand, since the database holds no game scripts.
- A variable the story table names as a place stays each player's own whatever its row says, in a Classic party too.
- Until the mapping comes, a Raid World's events sort by a Classic party's table and its writes wait unsorted.
- **What comes back** is written only once the player is free (no event, battle, transfer) and no lost raid boss fight's defeat is being undone. A value for a key the player's own unanswered request wrote is dropped, since the relay applied the batch that carried it before the player's.
- **Values the player keeps:** affection the relay hands lower than the player's own stays and goes to the relay again, which keeps the highest, so the world converges on each companion's highest. An unlock the player holds that the track hands off (the second accessory slot, 445) stays on and goes to the relay too, since an earlier build kept it each player's own.
- A telling's story events wait until the game took the track revision the last telling ended at, else the scene would play again; ten seconds at most, so a take that stays held never keeps them for good.
- A new game in a Raid World whose story is past the opening runs the opening's setup first, as the mod's own writes, then the relay's track is written.
- The relay keeps the route rules alone: the first route a write takes locks the world's.

### The write hook

`story_keys.rbx` follows every write of the game's own switch, variable and self switch objects.

- A frame can write about 1,900 keys (common event 154, the Final Chapter's reset), so the hook looks keys up in a byte table the DLL handed and makes no call per write.
- The site of each write is tracked per interpreter, swapped in around its update, since a wait inside a command leaves the update with the command still running.
- **Never recorded:** the mod's own writes (the relay's values, a teller's values a viewer takes, the opening's setup, the difficulty) and writes while a lost battle's defeat runs.
- Inputs are noted by the command that read them, counted among the database's kept commands so a translation leaves the place. A battle's outcome is noted at `BattleManager.event_proc=`, since command 301 waits for the battle inside itself.

### Runs handed over by replay

The model of "Issue 73 chest effects.md": no effects are copied. A run whose event counts for others travels as an entry, and each receiver's own game plays that event again, silently, against its own state.

- **Who keeps each key** comes from the reviewed list: work keys are the game's, chest keys the party's in a Classic party and each player's in a Raid World, other kept keys the world's.
- **The replayer** runs the page's real list in an interpreter bound to the run's map and event, through the game's own bodies (no mod hook sees it). World and work keys read from a view of the entry's start values; presentation and the opener's play (transfers, shops, menus, saves, sound, scene changes) are shut. Inputs come from the opener's record. Only a choice whose answers change the receiver's own things is left out of it and asked; a number, a key item and a present always go the opener's way, since a replay costs the receiver nothing, and one the record lacks takes what the game's window starts with: the variable's value within the digits, no item, no present (user decision 2026-11-06).
- **All or nothing:** a replay commits only when it reached a key of its step (or the receiver answered their own way); else the save stays unchanged and the run waits. A replay costs the receiver nothing: gold and items it spends come back.
- A replayed run is taken only while the player stands free and no battle invite is open, so a replayed message never holds a player while an invite lapses (issue 79).
- **The generator's gate:** every command code and script root of the maps and common events is classed by the channels it touches (state, presentation, play, input), or the build fails; keys a shut command writes must be work keys.
- **Named exceptions** (user decision 2026-11-04): the Medal King's free gift is never handed over (his exchanges reach players by prize switches); the Alice or Ilias pick is never replayed; the companion filter, the Great Decision's rows, the Classic key item loan and the Raid route rules stay their own; history from before the log comes by the frozen rows and the one-time repairs, and the reward repair never gives back an item an event takes away.
- **Found items** (key items, ores, CDs, job and race unlock items; not the medals) reach every player by the replay of the run that gave them and leave by the replay of the run that used them up, battle drops included (user decisions 2026-11-04 and 2026-11-05). A story reset's lists use none up, so a member ahead keeps the route's key items when the leader returns to the Great Decision. A Raid World's Makina come by level instead.

### Catch-up

A player behind a Raid World's story is carried along; `CatchupEngine` in C# decides over the relay's catch-up tables, the scripts hand a snapshot and carry out the actions with the game's own grants. The engine's notes travel in the save.

- **Behind:** the relay keeps the player's part's checkpoint as their track and holds only what would move their story past the end of their part. Before such an event starts, the DLL asks whether it, its common events and the chain it starts across maps would leave the part. Asking the chain is the point: a part's ending on a cutscene map without exits (the Middle Chapter's epilogue on map 750) is started by an event on a map the player can leave. Story that runs by itself waits silently, so a teleport onto its map cannot loop.
- **Moving on** happens at the level gate; another mod's lower level cap counts for the gate, but companions and Makina wait for the real level.
- **Rows count by story position:** a row counts once the story is in its part and its marks hold, so an optional event nobody played is never past. A row the player's own game played gives nothing, since the game gave it.
- **Return points and encounters** are set only on the map of the event that sets them, never by a common event's row, since a return point the world's story set elsewhere could send the player into another player's scene with no way out.
- **Counts** (such as Randolphs found) are recounted from their switches, since two players who each found one before either story reached the other kept one addition.
- Companions, class levels and lessons go by what each character knows rather than by the notes, so a step passed before an update and a later join both count.
- The side the player took along is noted in the save once, before the Great Decision, since the route's reset sets switches 4 and 5 to the route.
- A shared companion joins a player who lacks it at its gate; never one the player had, nor one their story took away for good.
- The new build ignores chest flags; the relay still serves them to released builds.
- **Catch-up experience:** a character below the target gains up to tenfold, fading to 1 at the target. The fade follows the target, since a fixed number of levels per step kept a late world's characters at tenfold for 159 levels and barely helped an early one. It wraps `Game_Actor#gain_exp`, so it grows after EXP mods.

### Raid World difficulty and own keys

- A Raid World sets one difficulty (variable 902) for every player and takes no *Player's choice* of start. It is applied by setting 902 and running common event 112 at once, as the game's own choice does, after every load and new game and whenever 902 drifts while the map is quiet.
- **Fights with values of their own** (the Colosseum, the special bosses on EASY and below, the Labyrinth of Chaos, the final battles' NORMAL) keep them: while their switch is on, nothing writes 902, 908 or runs 112, and the game's own restore puts the difficulty back. Trap: a Colosseum defeat leaves switch 28 on, so 28 counts only with 87.
- **Kept each player's own** in a Raid World, since one player's values would reach everyone: the recruit refusal switch 3, the Pocket Castle tour (2013, 2015), the rates and difficulty variables, the Ruler Ruler and Labyrinth values. Scene switches stay the world's, but a take turns any left on off while no scene runs, since a story written while one ran would leave its character standing for everyone.
- **A guest uses the host's enemy rates** (sent with the invite) until the battle ends and gives them back as `battle_end` ends, since the game's victory saves its autosave right after it and before the scene terminates.
- **Affection** is a one-way key the whole world keeps at its highest; gifts and battles raise it outside events, so every write is a request.

### Starting save

- A save can run code, so a new player sees a warning and nothing is fetched before *Take*. The files are walked for classes (Ruby's own or its libraries', known gadgets) before Marshal reads them, then every object is loaded before the world opens, since the game quits when a system save fails to load.
- A save of another player's starting save is marked (`OtherStart.txt`), so its side is not taken as the player's.
- A Raid World from a starting save starts its story there; later players from the same save are placed on the world's track, and a new game in such a world starts behind.

## Raid bosses

Each story boss of a Raid World is one fight the whole world shares: a pool at the relay keeps the share of its raid max HP left, every battle reports what it dealt, and the boss falls once the world wore the pool down. The pool refills 3% of its max a minute and stays defeated until an admin resets it. Classic worlds keep none.

- **No clock comparison:** every answer's share is the share now, and between the relay's words the game keeps the last one: only the relay counts what a pool gains back, and the game never asks for it on a timer (user 2026-11-08). The relay's `at` is never read.
- **The newest word wins:** the relay tells the world room before it answers, and the two travel apart, so every pool carries a rising stamp and an answer to a request sent before the pool was last heard is not taken. A defeat is lifted only by a reset or an answer to a request sent after the defeat was heard.
- **Reports** go in order and are never merged; a resent report with the same `seq` counts once. A report the relay cannot take (unreachable, 429, 5xx) is tried again for about two minutes and then dropped, since the queue goes in order and one the relay never takes would hold back every later one; any other refusal drops it at once.
- Nothing waits for the relay: a local kill is a kill and the battle wins at once.
- This replaced earlier pools counted in kills, where a won battle took a share off and the story was put back; nothing of that is left.

### In battle

- The DLL decides which battles fight a pool (`BossRules`): an event's battle against a boss's last phase of a milestone the story has not beaten, outside the Great Decision fights, Hades rematches and the Colosseum. A random encounter never does.
- **Raid stats** wrap `Game_Enemy#mhp` and each stat a tier names, applied on every call and never stored, since the game computes them anew from the difficulty and states, so the tier always comes after the world's difficulty.
- **Order at the start:** an enemy takes its pool's HP after the battle's start events (which may lower the boss's max) and before the party's start skills (whose damage the first report counts); then the troop's pages are checked once, so an HP-condition phase runs before anyone acts (user decision 2026-11-05).
- **Each command phase** the reporter reports first, then sets HP from the pools, so the turn's own damage is kept. The hook sits inside hotjoining's wrap and outside the live battle's, so it runs before the host records what it sends. A guest never reports or sets HP; one that takes the battle over starts its base from that moment, so the host's last turn is not reported twice.
- A report's base belongs to the enemy object it was taken of, so an enemy built anew never reports its full HP as healing.
- While the battle waits for commands, enemies retake their pools' HP every few seconds; a victory meanwhile is left to the live battle's wait, so the turn never starts on a finished battle.
- **Side battles:** next to a full boss battle a player may fight the same pools alone. A defeat there is the game's own, since a defeat back on the map at 1 HP let a player start the next side battle at once while each one's damage stayed in the pools. Only the first side battle won against a boss pays out.
- The two routes' Doppel Lukas share one pool.

### Frozen fights

A lost story battle against a raid boss keeps the story at the battle. The game's interpreter cannot resume there (`marshal_dump` saves the index after the battle command and drops the common events it runs inside), so the mod keeps its own record and a stand-in to resume from.

- The page is found by the list that runs, never by the page the event shows, since Sonya's page 1 turns page 2 on before its battle.
- The defeat's changes go back once its chain ended, by a write journal the DLL keeps from marks; a mark whose writes overflowed counts as unknown, and then nothing of the story is undone.
- The relay's story stays out of the journal: it is the world's, never an event's or a defeat's to put back, and it lands only while the player is free.
- While a defeat is being undone, the story take, the write hook and the catch-up wait.
- A fight with no record and not over is never frozen, since it would leave no stand-in to resume from (#71). The world's list of frozen fights is shared through the story tracks; a fight is over when the player won it, its pools are defeated or its beaten marker holds, and the other side's alternative counts too.

### Raid bosses outside Raid Worlds and the bars

- A Classic world with *Raid Bosses* and single player with the option give story bosses their tier's stats; nothing reports or regenerates, and single player needs no connection (the option is read in Ruby).
- The HP bars are worked out by the DLL; the map's bars follow the boss events, and the battle strip pushes the game's own boss HP bar (Basic Enemy HP Bars Lite) below it.

## Battles

### Rules every multiplayer battle shares

No ero offers, no Give Up, no swapping the Backline in where the battle has none. `MGQ_MpBattles.begin` sets them and keeps the game's settings; `finish` puts them back. Each kind of live battle registers a mode; what every kind decides the same way is the DLL's (`live.mode`).

### Battlers the game's setup never makes

Another player's character, enemies of another game's troop, a troop set up anew mid-battle, the other side's PvP characters and Backline and a guest's start all go through one factory (`MGQ_MpBattlers`), which makes each as the game makes its own and gives it the game's own battle start where that start never reaches it.

- A rebuilt character starts from the game's own setup of its actor; C# lists the steps of its build (`BattlerSetup.AllySteps`) and each goes through the game's own changer. The game settles a character at every change, so the rebuild holds that settle back until the whole build is on and settles once, as the owner's game had it settled; otherwise equipment that an ability or another piece makes wearable, or abilities that equipment gives the AP for, would come off.
- The game's `add_ability` takes off what a later ability may not be set with, though the owner's game may have let it be set after that one, so the set abilities go in as the build lists them; `forget_skill` leaves the proof abilities of jobs learned, so those the build lacks are dropped directly. A rebuilt character never trades equipment with the player's bag (the game's settle would put what it takes off there).

- An ally's HP goes in before its start, since a trait's low-HP states come only at the start (#31).
- A Challenge Battle's enemy must be of the troop's `enemy_class` (#47).
- A guest's start enters the troop in the Library as the host's start does (user decision 2026-11-05) and gives its own characters the counters their EXP needs (#24). An empty troop is not started, since the game's troop start reads a random enemy's defeat scene.
- Enemies marked fallen are laid down after lettering, since the game letters only the living.

### Live battles

- **The host computes, the guests play back.** Each game sees its own team as the party, so both would draw random numbers in a different order if both computed. The host streams what its battle shows every 10 frames (values before and after every action and hit, and every battler's at each command phase, which corrects what a guest missed); the guest never runs battle logic and sends only its commands.
- **Each game's language:** a translated and an untranslated game play together, so wherever the game builds a line from data (`Window_BattleLog#display_*`, skill words and names) the host sends the call, its arguments and a seed, and the guest writes the line with its own game's texts and the same random picks. "X appears!" comes from `battle_start`, which the guest never runs, so the host sends an `emerge` event instead.
- **Trap:** the host must send a `commands` marker as its command phase starts, since with none of its characters able to act the game goes straight to `turn_start`.
- **Trap:** after setting values directly, the guest clears the game's feature cache (`CacheActorFeatures`, which only `refresh` clears), or a state's extra actions and counters never count.
- The guest ends its turn before the next command phase, since `input_start` makes new actions only when the phase is not `:input` already.
- The host turns its skip settings off for the battle, since the guest sees only what the host shows; they come back as `battle_end` ends, before the victory autosave.
- No message holds a player: one moves on by itself after 90 frames; the Battle Dialogue mod shows them in side boxes. There is no turn timer, but after 10 s a waiting player may leave, which asks first since players press cancel to go back.
- **Seats and order:** a battle names its players by the seats they held as it began, kept with their ids, so a reconnect that deals seats anew changes nothing. Every message carries a number per receiver; a receiver takes each number once and in order and asks for the gap after a player came back.
- **Input from the other game is hostile:** lines are read with C#'s refusals, ids only within their tables, symbols only among those the game has, action result fields only those `Game_ActionResult` has. A guest's commands that fail leave the computer's actions. The guest's intake (`GuestStream`) lets through only the kinds, calls, audio files, pictures, waits and animations it knows.
- **Not yet:** effects outside the battle log's calls turned around for the other side, a confirmation before Escape, the computer taking over the host's team when the host leaves, the Backline in team duels, levelling the two teams.

### Co-op battles

- When a party member's game sets up a battle, the members on the same map who are walking, reading an event or in the background are invited; busy members keep the invite until free and turn it down after 3 s. The leader hosts, so the leader's game and mods decide; a member whose game set the battle up asks the leader to lead and hosts it only if the leader refuses or stays silent.
- **Stretched encounter steps:** while another player who would fight stands within 20 tiles, the game's steps are stretched by a random factor, so the players' steps never fall into step. Stretching once per member kept a party of four from meeting enemies at all, and counting the whole map kept players far apart from meeting any.
- **Held encounters and standing still:** an encounter waits up to 3 s for busy members; meanwhile every member on the map stands still and opens no menu, since before only the member who met the enemies and the leader stood still and the others walked off before their invite came.
- **The party** is the same on every game, in the roster's order; others' characters are `Game_MpAlly`s rebuilt once per battle. `battle_members` is hooked once the first scene starts, since plugins define it anew; `all_members` stays the player's own, so EXP goes to their own characters.
- A guest whose troop differs (through a mod) fights the host's troop, rebuilt and lettered by place, since the host names every enemy by its place; it keeps its own only when the host names an enemy its database lacks. The host sends troop changes before any send that names a new enemy.
- **Leaving:** the others fight on with the shares of the smaller party; a host left alone, and a guest whose host left, fight on as a battle of their own.
- **In a Raid World** a battle takes the players near it, party or not, up to four; the player who starts it hosts. Of two battles started at once, a random encounter still gathering yields to an event's battle or to the host who entered the map first; an event's battle never yields, since its event goes on by the battle's result.
- **Hotjoining and joining by choice:** a random encounter near a running battle asks to join it with its enemies; the host fits them on the screen (at most 8, half the narrower picture may hide behind another) using the asker's measured picture widths, since the battle server measures every picture as 32 pixels wide. A player can also press the join hotkey near a battle that takes players in. Party members are asked rather than brought along into a battle outside the party.
- Each game ends the battle as the host's ended, each with its own EXP, gold and drops.

### PvP battles

- Two games swap their teams' builds and fight live; on the host the friend's characters are rebuilt as real `Game_Actor`s, so every trait, passive and automatic skill works. **Only numbers leave the game, never save data**, since loading someone else's Marshal data can run code. Database sizes must match, since ids and fields differ between versions.
- A rebuilt character answers for the enemy side wherever the game assumes the player's party (an audit of the battle scripts' `$game_party`, `actor?`, Luka references). Any monster-only method the audit missed is answered by a stand-in and logged once, so it does not end the game mid-battle.
- **Traps found:** enchanted equipment needs the enchant-off switch turned off in the switches' own entries for the check, since the game's setter takes every enchanted item off the party; skills aimed at one sex or at Luka find no target in a team without one and break the battle log, so such an action shows "is watching the situation"; a dead rebuilt character must stay dead to the game so every target choice skips it, but stays on the field as a silhouette since its team can revive it.
- **Nothing reaches the disk:** the game writes the system save at every scene change, so while a PvP battle runs the save writers swap the pre-battle snapshot in and back. The battle runs in the game's battle replay mode (no EXP, gold, drops, recruiting or autosave); the snapshot is put back on the map. F12 during a battle restores the shared objects and closes the link, so the friend wins instead of waiting.
- The feature caches are keyed by object, so a rebuilt character never shares an entry with the player's own character of the same id.
- **The Backline** (host's option, never in team duels): each game tells its Frontline, and both reorder between the same two sends, so stream places mean the same characters on both. Targets are places, resolved as the action runs.
- **Duels** start like party invites; never use a state field named `duel` or `trade`, which mark those messages and would turn every state into one. **Team duels** form sides from parties; a player who leaves hands their characters to the first player of their side still in it.

### Battles on the battle server

A co-op battle of two or more players goes to the relay's battle server where there is one: the server hosts it with the game's own battle code and this mod's host scripts, and every player, the starter too, plays it back as a guest over the battle's own channel. The server reads that battle alone; the world's token stays with the players.

- The setup is checked on the server against the scripts' and game data's fingerprints and its mods; refused or unanswered, the starter hosts as before. A lasting refusal (no server, other scripts or data, no core) stops asking for the session.
- **The starter stands in for the server in the world room**, since the server sits in none: requests to join go to the server through it.
- The server leaves out the recruit roll after a victory, since each player's game offers its own.
- Each served battle runs in a sandboxed child with the relay's battle lifetime as its CPU time.

## Trades

- Items and gold between two players on the same map; key items stay out (enchant stones excepted), only the bag counts.
- **The relay commits, never reads:** both games send the SHA-256 of the agreed offers and the offers sealed with a key from the world's token; the relay commits once both sent the same text. Both games must build byte-equal text, so the commit id and text are ordered by player id and both games keep the same limits.
- An offer or unconfirm from the other player cancels a commit the relay has not decided. While the other player is away, the own offer and confirmation go out again once they are back, so a lost unconfirm never lets the other game commit alone.
- A committed trade is applied, noted in the save, saved, and only then marked done at the relay. **Recovery:** a loaded save fetches committed trades it lacks and applies them once the player is free.
- The offer format is the one every release wrote.

## Interface

- **The framework owns it:** looks, places (arranged with the left Alt), text boxes, question box, notices, wheels and menus. The look and box places 0.6 kept in `Player.ini` are not carried over (user decision 2026-11-07): MGQ Online's boxes start in their default places once, and every UI id carries the `mgq_online_` prefix.
- **Avatars:** the Leader HUD and the World overview's heads and reading pane show characters through the framework's `avatar`, so MGQ Online keeps no face or sprite drawing of its own.
- **Hotkeys:** action wheel B, emote wheel E, chat T, World overview F11, party box size M, Leader HUD size H, join battle J, bug report F3; accept and decline invites are the framework's Y and N.
- A wheel's choice runs in the next frame, so its confirm never reaches the screen it opens.
- The mod's timers count frames; a countdown converts with `MGQ_MpActions.lapse_in`. The emote cooldown counts the bridge's frames in C# (`Emotes`), so a load or new game does not end it.
- The DLL's `AltMenuGuard` swallows `SC_KEYMENU` for a lone Alt and while a text screen takes the keyboard, since letting Alt go would open the window's menu, in which the game waits.
- The clipboard is owned by the game's window while the DLL writes it.
- **Single player restart:** a changed *MGQ Online SP* row offers a restart only while the map is quiet, since a save in the middle of an event would skip its command. The restart saves to its own file through the game's own save, so no slot is touched, and the framework restarts and resumes from it.
- **The bug report** files the title, text and public facts as a public GitHub issue; the screenshot, logs and private details reach the developer only. The screenshot is read from RGSS3's bitmap in the game's process by the DLL.
- **The chat's rules** (channels, whispers, commands, rate limits) are C#'s; the script only shows the view. **The World overview** is a framework window, not a scene, so the world runs on behind it; other mods append their tabs to `#mgq_online_overview_tabs` through `UI.patch "#mgq_online_overview"`.
- The DLL walks the quests (`QuestWalk`: Amira's objective and lists, the Pocket Castle's board) as the game would run them now, without running them, over the commands the events database keeps, so the walk reads alike from the database and the game's own data; it names each message by its kept place, and the script looks the text up in the player's own game data, translated or not. A script's check in a quest branch never holds. A Japanese name in a translated game finds no portrait.

## Discord and other mods

- **Discord Rich Presence**, when installed, shows the player's world and brings Discord invites into worlds; the two mods meet only in its `MGQ_Discord::Bridge`. Under the framework an invite during a game is carried through the restart that going back to the title makes.
- **Battle Dialogue** (MGQ-Paradox-Mod-Collection), when installed, shows battle messages in side boxes, so neither side of a live battle waits for a key. The guest's playback sets `$game_message.speaker`, which that mod reads.

## Conventions

These are not enforced by tooling.

- **File headers:** every `.cs`, `.rb` and `.rbx` file starts with a header block naming the file and a changelog, newest entry first, entries of the same author and day grouped. Only changes after the first commit are recorded; before that a file carries just `Created`.
- **Documentation comments:** every type and member, XML comments in C# and YARD-style in Ruby: a summary always, parameters and return values where they apply, remarks only where they add a why or a trap. Short, present-state.
- **Inline comments:** only where the code cannot say it: a constraint, a trap, or the failure a line prevents.
- **Names:** magic strings and numbers get a named constant.
- **Language:** code, comments and documentation are English.
- **Ruby 1.9.2:** the game's scripts run on RGSS3's Ruby 1.9.2, so they use no keyword arguments, no `&.`, no `%i` and no `Encoding::`. `at_exit` never runs, so closing work goes inside the `SceneManager.run` hook, and a DLL export takes at most 16 arguments (see [Ruby 1.9.2 and RGSS3 traps](#ruby-192-and-rgss3-traps)).
