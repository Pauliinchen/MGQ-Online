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
.\MGQOnline.ServerCore\build.ps1 -Version 0.6.9   # -> MGQOnline.ServerCore\bin\linux-x64\MGQOnline.ServerCore.so
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

## The story mapping's index

The relay asks the server for the derived index of the story mapping (see "Story mapping" in
[Relay/README.md](../Relay/README.md)) over a connection of its own, after every batch of the
mapping that changed rows and as it starts while the index is missing or stale:
`{"op":"story_index","rowsRev":3,"keys":[{"key":"v1001","kind":"one_way"}],"events":[{"key":"ss231.*.*","share":"personal"}]}`.
The child that takes the connection hands the rows to the core (`lib/story_index.rb`, the core's
topic `story.index`), which reads every map and common event of the game folder, about 2.5 s and
under 256 MB, and answers one line:
`{"ok":true,"built":3,"events":[[12,3],...],"commons":[40,...],"names":{"switches":{...},"variables":{...},"maps":{...},"events":{"12.3":"EV003",...},"companions":3202}}`.
Without the core library the answer is `{"ok":false,"error":"..."}` and the relay keeps the index it has.
