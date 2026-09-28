# MGQ Paradox Multiplayer

Play Monster Girl Quest! Paradox RPG together with a friend over a direct connection. So far: **PvP battles**, in which your Frontline fights your friend's Frontline live, each of you commanding your own team. Overworld and co-op play are planned on the same connection.

## Requirements

- Monster Girl Quest! Paradox RPG 3.06 with the English translation, the same version on both sides.
- The community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder.
- For hosting: port 47625 (TCP) reachable, by forwarding it in your router, IPv6, or a virtual network like Tailscale, ZeroTier or Radmin VPN.

Optional:

- [Discord Rich Presence](https://github.com/Pauliinchen/MGQ-Paradox-Discord-Rich-Presence): invite your friend through Discord instead of sending a join code, and show on your profile who you're playing with.
- [Battle Dialogue](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/tree/main/Battle_Dialogue): shows what characters say in boxes at the screen's sides, so neither of you waits for the other to press a key.

## Install

Close the game and extract the release zip into the folder that contains `Game.exe`:

```
Game.exe
Multiplayer\Multiplayer.dll
Patch\Multiplayer.rb
Patch\mp_sync.rb
Patch\pvp_battle.rb
```

To uninstall, delete the `Multiplayer` folder and the three scripts in `Patch`.

## PvP battles

Press **F11** on the map to open the PvP battle screen.

- **Host:** your game waits for a friend and puts a join code on your clipboard. Send it to your friend, or invite them through the **+** in a Discord chat when the Discord mod is installed.
- **Join:** copy your friend's join code and pick *Join with the copied code*, or accept their Discord invite.
- **Fight your own team:** a mirror match against your own Frontline, without any network.

Only the Frontline fights. Escape gives the battle up at once, Give Up is off, and if your friend leaves or the connection breaks, you win. Nothing carries over: your save, the Library and affection are put back exactly as they were before.

While the mod is installed, the game keeps running when its window is in the background, so neither player holds the other up.

## Troubleshooting

`Multiplayer\InGame.log` only appears when something went wrong inside the game; `Multiplayer\Multiplayer.log` tells what the connection did. Please attach both when [opening an issue](https://github.com/Pauliinchen/MGQ-Paradox-Multiplayer-Mod/issues).

## Building from source

See [docs/DEVELOPER.md](docs/DEVELOPER.md).

## Disclaimer

This is an unofficial fan project. It is not affiliated with Torotoro Resistance, the creators of Monster Girl Quest, or the English translation team. It contains no game or translation files.
