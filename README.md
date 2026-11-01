# Monster Girl Quest! Online

*An unofficial multiplayer mod for Monster Girl Quest! Paradox RPG.*

[![Latest release](https://img.shields.io/github/v/release/Pauliinchen/MGQ-Online?include_prereleases&label=download)](https://github.com/Pauliinchen/MGQ-Online/releases/latest)

Play Monster Girl Quest! Paradox RPG together with friends over the internet, with nothing to set up in your router.

<p align="center">
  <img src="docs/images/action-wheel.png" alt="Two players in a world, with the action wheel open" width="48%">
  <img src="docs/images/chat.png" alt="The open chat, with its tabs and an unread Party tab glowing" width="48%">
  <img src="docs/images/world-list.png" alt="The world screen, with the list of worlds and a world's details" width="48%">
  <img src="docs/images/quests.png" alt="The World overview's Quests page, with the main quest next to Amira, the side and companion quests, and the picked quest's whole text" width="48%">
</p>

- **Worlds:** up to 32 players on the same maps, with emotes and an overview of everyone online and of your quests under way: the main quest, Amira's side quests and your companions' requests. A world is *Classic*, where each party plays its own story, or a *Raid World*.
- **Raid Worlds:** the whole world plays one story together, party or not. Everyone on a map watches its scenes, battles pull in the nearest players, and each story boss is one fight the whole world wears down, which waits where it beat you. A player behind catches up as they level, with up to ten times the experience.
- **Raid bosses everywhere:** a Classic world, or single player through *Options → Mods → MGQ Online SP*, can make the story bosses raid bosses of their tier, with their HP bars and without any connection in single player.
- **Chat:** global, map, party and whisper chats in tabs, a gold dot on tabs with unread lines, and speech bubbles over the players on your map.
- **Turn off other mods:** a world can be played with its own mods and nothing else. Entering it loads only the world's mods, and yours come back when you leave the world.
- **Parties:** up to four players play the leader's story together and share one team's worth of companions. Teleport to any party member once they allow it, or to the leader at once.
- **Co-op battles:** party members on the same map join each other's battles, each commanding their own characters.
- **Duels and PvP battles:** your team against a friend's, live, inside a world.
- **Trading:** swap items, equipment, stones and gold with a player on your map; a disconnect never loses or copies anything.
- **Mods:** install, update and remove mods of the [website](https://mgqonline.org/mods) from the title screen, through the Mod Framework that comes with the mod.
- **Your interface:** three looks for the mod and the game alike, Monarch, Legacy and the game's own window color, and every box of the mod moves and resizes while you hold the left **Alt**.

Worlds, Raid Worlds, parties and co-op battles are a **prototype**: expect bugs, and please [report them](https://github.com/Pauliinchen/MGQ-Online/issues/new?template=bug_report.yml).

## Requirements

- **Monster Girl Quest! Paradox RPG 3.06**, untranslated or with the English or Russian translation. Everyone needs the same game version and the same version of this mod. A translated and an untranslated game can play together; each shows battles in its own language.
- **The community's mod loader:** the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder. The Russian translation brings its own `Patch.rb`, which loads the mod too: keep it and skip the wiki one.

Optional:

- [Discord Rich Presence](https://github.com/Pauliinchen/MGQ-Paradox-Discord-Rich-Presence) 1.5.1 or later: show on your profile who you're playing with and use your Discord name in worlds. With 1.6.1 or later you also invite friends into your world, password included.
- [Battle Dialogue](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/tree/main/Battle_Dialogue): shows what characters say in boxes at the screen's sides, so nobody waits for another player to press a key.

The [Mod Framework](https://github.com/Pauliinchen/MGQ-Mod-Framework) comes with the mod: its *Options → Mods* binds other hotkeys and shows which options a world sets.

## Install

1. Download `MGQ-Online-<version>.zip` from the [latest release](https://github.com/Pauliinchen/MGQ-Online/releases/latest).
2. Close the game and extract the zip into the folder that contains `Game.exe`.

You then have `!Mod_Framework.rb` and `Multiplayer.rb` in your `Patch` folder, and next to them a `Multiplayer` folder with the rest of the mod; your name and worlds go there too. The mod runs on the [Mod Framework](https://github.com/Pauliinchen/MGQ-Mod-Framework), which comes inside it and loads your other mods too, also those that keep their scripts in a folder inside `Patch`. The logs go into the `Logs` folder of the game folder.

While the mod is installed, the game keeps running when its window is in the background. A gamepad does nothing meanwhile.

**Update:** the Mod Framework counts the updates waiting on *Browser* in the title's Mods box and installs them, this mod's too. When a new release is needed, *Multiplayer* on the title screen offers it; until then PvP battles stay off too. The framework closes the game, installs the release, shows what's new and starts the game again in the Multiplayer menu; under Wine and Proton too. If the game cannot start, run `Update.bat` in `Patch\Mod_Framework`. Your name, hotkeys, favourites and worlds are kept.

**Uninstall:** close the game and delete `Multiplayer.rb` and the `Multiplayer` folder in `Patch`. Keep `Patch\Multiplayer\Worlds` if you want to play your worlds again later.

## Quick start

1. Pick **Multiplayer** below *Continue* on the title screen and type the name the others see.
2. One of you picks *Create new world*, gives it a name, picks *Classic* or *Raid* (fixed once created) and, if you like, a password.
3. Everyone confirms on that world and picks *Enter the world*.
4. On the map, stand next to a friend, press **B** and pick *Invite to a party*; they accept in their own wheel. You now play the leader's story together and fight co-op battles. In a Raid World everyone plays the world's story, and a party gets the first places in battles.

## Hotkeys

| Hotkey | What it does |
|---|---|
| **B** | Action wheel: invite, duel, trade, chat, report a bug, teleport to the leader (other members from the World overview) |
| **T** | Chat: **/g** everyone, **/m** your map, **/p** your party, **/w** one player, **/help** |
| **E** | Emote wheel |
| **F11** | World overview, in a world and in single player |
| **Y** / **N** | Accept / decline the first invite at the top left, or answer a question box |
| **Tab** | Make the party box small or full; in a raid boss battle, shrink the boss's HP bar to the bars alone or back |
| **H** | Make the Leader HUD at the top left small or large |
| **J** | Join the battle of a player next to you in a Raid World, fight a raid boss alongside a full boss battle, or fight a raid boss again where it beat you |
| **F3** | Report a bug, with a screenshot and your logs, anywhere but the title and game over screens |

Rebind them in *Options → Mods → MGQ Online Hotkeys*, Y and N in *Mod Framework Hotkeys*; the mod's other options are in *MGQ Online Settings*.

## Documentation

- [Player guide](docs/GUIDE.md): worlds, parties, co-op battles, duels, trading and PvP battles in full, and [troubleshooting](docs/GUIDE.md#troubleshooting).
- World types: [Classic Worlds](docs/CLASSIC_WORLDS.md), where each party plays its leader's story, and [Raid Worlds](docs/RAID_WORLDS.md), with the world's story, catching up and every raid boss.
- [Developer notes](docs/DEVELOPER.md): building, testing and how the mod works inside.
- [Relay](Relay/README.md): the server the games meet at, and its protocol.
- [Battle server](BattleServer/README.md): the game's own battles played on the server, without Game.exe.

## Disclaimer

Monster Girl Quest! Online is an unofficial fan project. It is not affiliated with or endorsed by Torotoro Resistance, the creators of Monster Girl Quest!, or the English translation team. It contains no game or translation files.
