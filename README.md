# MGQ Paradox Multiplayer

Play Monster Girl Quest! Paradox RPG together with friends over the internet, with nothing to set up in your router. So far: **PvP battles**, in which your Frontline fights your friend's Frontline live, each of you commanding your own team; and **worlds**, which up to 32 players enter and see each other walk the same maps. Playing the story together and co-op battles are planned.

## Requirements

- Monster Girl Quest! Paradox RPG 3.06, the same version on both sides, with or without the English translation. A translated and an untranslated game can play together; each shows the battle in its own language.
- The community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder.

Optional:

- [Discord Rich Presence](https://github.com/Pauliinchen/MGQ-Paradox-Discord-Rich-Presence) 1.5.1 or later: invite your friend through Discord instead of sending a join code, and show on your profile who you're playing with.
- [Battle Dialogue](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/tree/main/Battle_Dialogue): shows what characters say in boxes at the screen's sides, so neither of you waits for the other to press a key.

## Install

Close the game and extract the release zip into the folder that contains `Game.exe`:

```
Game.exe
Multiplayer\Multiplayer.dll
Patch\Multiplayer.rb
Patch\mp_actions.rb
Patch\mp_actors.rb
Patch\mp_async.rb
Patch\mp_events.rb
Patch\mp_npcs.rb
Patch\mp_overworld.rb
Patch\mp_story.rb
Patch\mp_sync.rb
Patch\mp_world.rb
Patch\pvp_battle.rb
```

To uninstall, delete the `Multiplayer` folder and the eleven scripts in `Patch`. The `Multiplayer` folder also holds your worlds, so keep `Multiplayer\Worlds` if you want to play them again later.

## Worlds

Pick **Multiplayer** below *Continue* on the title screen. The first time, the game asks for the name the others see, unless the Discord mod knows yours.

- **The list** at the left holds every world, your favourites first (marked `*`), then those you played last. The right side shows who made the chosen world, how many of its players are online, and everyone who ever joined it.
- **New world:** give it a name, a password, and how many players it seats at once, 2 to 32. Then it starts at the opening.
- **Enter a world:** the first time, type its password; your game remembers it after that. A world you have saves in loads your latest one; otherwise you start at the opening.
- **Its creator** can remove a player, who can then no longer enter, or delete the world for everyone.
- **Names and passwords** are typed on the keyboard; with a gamepad, the game's letters appear.

Each world keeps its own saves, Library, medals and affection in `Multiplayer\Worlds`, apart from your own game. Going back to the title screen leaves the world.

**On the map**, the other players on the same map walk around as they do, with their names above them and an icon for what they do: fighting, talking or watching an event, typing in the chat, in a menu, the inventory or their equipment, shopping, at the casino, in the Library, sailing, flying, or away from the game. Their ping shows after their name, and yours right above your head: green up to 100 ms, yellow up to 200 ms, red beyond. They walk through everything and trigger nothing. The bottom left of the screen tells who joined and left, and when the connection is being restored. PvP battles (F11) are off while you are in a world.

**The world never pauses:** while you are in a menu, a shop, a battle or a story scene, the map goes on behind it. The others walk on, NPCs move, and background events and timers run. Menus show the live map behind them instead of a still picture. Anything that needs you, such as a message, a battle, a move to another map, or an NPC that walks into you, waits until you are back on the map.

**The action wheel:** press **B** on the map to open it around your character. Pick a choice with the arrow keys and take it with the confirm button; **B** or cancel closes the wheel. Choices you cannot take right now are grey and tell you why. Duels are shown already and come in a later version.

**Chat:** press **T**, or pick *Chat* in the wheel, and type on the keyboard; **Enter** sends, **Esc** closes. The arrow keys, **Home** and **End** move the cursor, and **Delete** removes the character after it. Your line goes to everyone in the world: it shows in a speech bubble above your head for the players on your map, and in the chat log at the bottom left of the map for everyone.

**Parties:** players outside your party are slightly see-through. Stand next to another player, open the wheel and pick *Invite to a party*; "Invites to a party (B)" then shows above your head on their screen for 15 seconds, and when they open the wheel next to you and pick *Accept*, you form a party. Party members are fully visible and their names are green. *Leave the party* at the bottom of the wheel leaves it. On a map you share with party members, you all see the same NPCs in the same places: whoever of you entered the map first is its Map Owner, and the NPCs move as they do in their game. While in a party, everyone plays the story of the player who made the party: its events, doors and conversations are as far along as in their game. Your own party, your companions and their affection stay yours, and your saves keep your own story. When you leave the party, you are back in your own story. If your story was exactly as far along as theirs when you joined, you keep what you played together, companions who joined in the story included. Chests are everyone's own: when a party member opens one, everyone in the party who has not looted it yet gets the same items. The party travels together: when the player who made the party goes to another map, everyone follows, and when a story scene starts there, everyone on that map is brought to them. The story itself plays in their game: when you start a story event, it is handed to them, and everyone on the map sees its dialogue in their own message window, at their own pace. Conversations, shops and the job change menu stay your own. Battles fought together as a party are planned.

## PvP battles

Press **F11** on the map to open the PvP battle screen.

- **Host:** your game waits for a friend and puts a join code on your clipboard. Send it to your friend, or invite them through the **+** in a Discord chat when the Discord mod is installed.
- **Join:** copy your friend's join code and pick *Join with the copied code*, or accept their Discord invite: your game starts if it is closed, loads your newest save (the one *Continue* picks first) and joins by itself. While you host, invites you accept are ignored; stop hosting first.
- **Fight your own team:** a mirror match against your own Frontline, without any network. `Multiplayer\Mirror Match.log` then lists each of your characters next to its copy and marks every value that differs.

Once the teams are swapped, both battles start together. The host's game works the battle out, and the other game shows what happened. The team you meet is your friend's characters as they are: jobs, races, equipment, gems and abilities, pre-battle spells and passives included. A defeated character of your friend stays as a grey silhouette, since their team can still revive it.

Only the Frontline fights. Escape gives the battle up at once, Give Up is off, and if your friend leaves or the connection breaks, you win. When you have waited for your friend for 10 seconds, Cancel lets you leave the battle, which also gives it up. Battle messages move on by themselves. Nothing carries over: no EXP, gold or items, and your save, the Library and affection are put back exactly as they were before.

## Connection

Your games meet at the mod's **relay**, a small server that passes their data on. Both only connect out to it, which works on any internet connection, so neither of you has to open a port, change a router setting or install anything.

- **Private:** everything your games send each other is encrypted with a key from the join code or the world's password. The relay never gets that key: it passes on data it cannot read. For worlds it keeps the list everyone sees: each world's name, its players' names and who is online.
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
