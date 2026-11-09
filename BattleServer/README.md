# Battle server

Plays Monster Girl Quest Paradox battles without Game.exe, with the game's own battle code in plain
Ruby 3.3, and hosts MGQ Online's co-op battles the relay hands over (see
[Relay/README.md](../Relay/README.md), Server battles, and "Battles on the battle server" in
[docs/DEVELOPER.md](../docs/DEVELOPER.md)).

## The core library

MGQ Online's C# core on the server is `MGQOnline.ServerCore`, a native library each battle's child
loads through Fiddle (see "The battle server's core" in [docs/DEVELOPER.md](../docs/DEVELOPER.md)).
MGQ Online's scripts ask it for rules they share with the game, so without it the server refuses MGQ
Online's battles (code `core`, with why) and says so once as it starts; their starters then host
them.

**Build.** The Release workflow attaches `MGQOnline.ServerCore.so` (linux-x64) to every release,
after checking it in sandboxed battle children. To build it on this PC (Docker running):

```powershell
.\MGQOnline.ServerCore\build.ps1 -Version 0.7.0   # -> MGQOnline.ServerCore\bin\linux-x64\MGQOnline.ServerCore.so
.\BattleServer\tools\core_check.ps1               # loads it in two sandboxed children and prints a table
```

For a battle server on Windows during development:
`dotnet publish MGQOnline.ServerCore -c Release -r win-x64` gives
`MGQOnline.ServerCore\bin\Release\net10.0\win-x64\publish\MGQOnline.ServerCore.dll`.

**Deploy.** Copy the `.so` of the release whose game scripts the server runs (the core and
`Patch/Multiplayer.rb` speak one bridge version) outside the game folder, root-owned and not
writable by others, for example `/opt/mgq-battle/core/MGQOnline.ServerCore.so`, and name it in the
service's settings:

```
BATTLE_CORE_LIBRARY=/opt/mgq-battle/core/MGQOnline.ServerCore.so
```

Then restart the server. Its log says `core library: <path>` as it starts, each battle's child
`[mgq] bridge: opened context 1 ...` and the core's own lines as `[mgq] core: ...`. A path that
does not exist, game scripts older than the bridge, or a library a child cannot load or that does
not shake hands is logged, and those battles are refused. The library carries its GC heap
limit (256 MB); leave `DOTNET_GCHeapHardLimit` unset unless a larger one is needed (hexadecimal
without `0x`). Removing the setting and restarting turns the core off again, and with it MGQ Online's battles on
this server.

## A world's mods

A co-op battle's starter names the website mods of its world it runs, each with its version and
the hashes of its files as the website lists them (`lib/mods.rb`). The server takes them from its
cache (`BATTLE_MOD_CACHE`), else downloads the version's PC package from the website's catalog
(`GET /api/mods/<slug>?schema=3`; `MGQ_MODS_SITE` names another website than mgqonline.org, as for
the Mod Framework) and keeps it only when the package matches the website's hash and each file the
starter's. A mod the website does not have, or a download that differs, refuses the battle with
the code `mods`.

## The story mapping's index

The relay asks the server for the derived index of the story mapping (see "Story mapping" in
[Relay/README.md](../Relay/README.md)) over a connection of its own, after every batch of the
mapping that changed rows and as it starts while the index is missing or stale:
`{"op":"story_index","rowsRev":3,"keys":[{"key":"v1001","kind":"one_way"}],"events":[{"key":"ss231.*.*","share":"personal"}]}`.
The child that takes the connection hands the rows to the core (`lib/story_index.rb`, the core's
topic `story.index`), which derives the index from the events database the mod ships,
`Patch/Multiplayer/Data/events.db` under the game folder (opened once per child, read-only and
unchanging, so it writes nothing beside it in the sandbox; the derive takes about 30 ms and its
time is logged as `[mgq] core: story.index: derived ... in N ms`), reads the names of the
story's keys from the game folder's own data (the core's topic `story.names`, a few seconds, the
translation's names), and answers one line:
`{"ok":true,"built":3,"events":[[12,3],...],"commons":[40,...],"names":{"switches":{...},"variables":{...},"maps":{...},"events":{"12.3":"EV003",...},"companions":3202}}`.
Each child hands the core the fingerprint of the game data it loaded as it shakes hands
(`Core.open`, the core's topic `core.game_data`); the core refuses the index while the events
database differs from it in the maps or the common events, which the index reads, and logs once
in which parts it differs. So the events database must be deployed with every release next to
the core library (see Deploying a release). Without the core library, without the events
database, or with one that differs, the answer is `{"ok":false,"error":"..."}` and the relay
keeps the index it has.

## Deploying a release

Every release of MGQ Online installs its game scripts and its events database into the server's
game folder, since the server serves only games whose scripts match its own and the core reads the
events database the release ships. Copy the release zip's `Patch` folder to the server (as a
tarball, for example), unpack it, and run as root:

```
sudo bash deploy_release.sh /tmp/mgq-0.7.0 0.7.0   # the folder holding the release's Patch folder, and its version
```

`tools/deploy_release.sh` backs the game folder's `Patch` up to
`/var/cache/mgq-battle/patch-before-<version>`, installs `Patch/Multiplayer.rb`,
`Patch/Multiplayer/Scripts/` (removing the scripts the release no longer has) and
`Patch/Multiplayer/Data/events.db`, root-owned and not writable by others, restarts `mgq-battle`
and compares every file it installed with the release's; it stops before changing anything when
the release lacks one of them. `MGQ_BATTLE_GAME`, `MGQ_BATTLE_BACKUPS` and `MGQ_BATTLE_SERVICE`
name another game folder, backup folder or service. The core library is deployed as above.

### The Mod Framework

MGQ Online's scripts run on the Mod Framework, which the release zip does not hold; the server
keeps its own copy in `Patch/!Mod_Framework.rb` and `Patch/Mod_Framework/`. It is redeployed only
when needed: the first deploy of 0.7, a release whose `MOD_FRAMEWORK_REQUIRED` (in
`Multiplayer.rb`) is newer than the server's copy, or a framework release that changes how the
scripts load or run. Then copy the `Patch` folder of the framework release's zip
(`MGQ-Mod-Framework-<version>.zip`) to the server as well and name its folder third:

```
sudo bash deploy_release.sh /tmp/mgq-0.7.0 0.7.0 /tmp/framework-0.1.0
```

The script then installs the framework's entry file and folder the same way, keeping the `*.ini`
settings in its folder, and compares them with the framework release too. Without the third
argument the installed framework stays, and the deploy stops before changing anything when the
server has none. Each deploy removes what earlier deploys left that the framework replaces: the
copy inside MGQ Online's folder (`Patch/Multiplayer/Mod_Framework/`) and Mod Config Remake
(`Patch/0_ModConfigRemake.rb`).
