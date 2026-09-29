# MGQ Paradox Multiplayer

Play Monster Girl Quest! Paradox RPG together with a friend over the internet, with nothing to set up in your router. So far: **PvP battles**, in which your Frontline fights your friend's Frontline live, each of you commanding your own team. Overworld and co-op play are planned on the same connection.

## Requirements

- Monster Girl Quest! Paradox RPG 3.06 with the English translation, the same version on both sides.
- The community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder.

Optional:

- [Discord Rich Presence](https://github.com/Pauliinchen/MGQ-Paradox-Discord-Rich-Presence) 1.5.0 or later: invite your friend through Discord instead of sending a join code, and show on your profile who you're playing with.
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
- **Join:** copy your friend's join code and pick *Join with the copied code*, or accept their Discord invite: your game starts if it is closed, loads your newest save (the one *Continue* picks first) and joins by itself. While you host, invites you accept are ignored; stop hosting first.
- **Fight your own team:** a mirror match against your own Frontline, without any network. `Multiplayer\Mirror Match.log` then lists each of your characters next to its copy and marks every value that differs.

Once the teams are swapped, both battles start together. The host's game works the battle out, and the other game shows what happened. The team you meet is your friend's characters as they are: jobs, races, equipment, gems and abilities, pre-battle spells and passives included. A defeated character of your friend stays as a grey silhouette, since their team can still revive it.

Only the Frontline fights. Escape gives the battle up at once, Give Up is off, and if your friend leaves or the connection breaks, you win. When you have waited for your friend for 10 seconds, Cancel lets you leave the battle, which also gives it up. Battle messages move on by themselves. Nothing carries over: no EXP, gold or items, and your save, the Library and affection are put back exactly as they were before.

## Connection

Your games meet at the mod's **relay**, a small server that passes their data on. Both only connect out to it, which works on any internet connection, so neither of you has to open a port, change a router setting or install anything.

- **Private:** everything your games send each other is encrypted with a key from the join code. The relay never gets that key: it passes on data it cannot read and keeps nothing.
- **No addresses:** the join code holds a random token and the relay's name, so your friend's game never learns your IP address.

While the mod is installed, the game keeps running when its window is in the background, so neither player holds the other up.

## Troubleshooting

- **"Your friend's game is not hosting with this join code any more":** your friend stopped hosting, or hosted again, which makes a new join code. Ask for the new one.
- **"The relay could not be reached":** your internet connection is down, or something blocks the game from going online, such as a firewall. `Multiplayer\Multiplayer.log` says what the relay answered.
- **"This join code comes from another version of the mod":** one of you has an older version; both need the same one.
- **"Your friend's game uses a relay this version does not know":** your friend has a newer version of the mod; update yours.
- **Logs:** `Multiplayer\InGame.log` only appears when something went wrong inside the game; `Multiplayer\Multiplayer.log` tells what the connection did. Please attach both when [opening an issue](https://github.com/Pauliinchen/MGQ-Paradox-Multiplayer-Mod/issues).

## Building from source

See [docs/DEVELOPER.md](docs/DEVELOPER.md).

## Disclaimer

This is an unofficial fan project. It is not affiliated with Torotoro Resistance, the creators of Monster Girl Quest, or the English translation team. It contains no game or translation files.
