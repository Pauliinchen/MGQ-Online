# Monster Girl Quest! Online

*An unofficial multiplayer mod for Monster Girl Quest! Paradox RPG.*

Play Monster Girl Quest! Paradox RPG together with friends over the internet, with nothing to set up in your router.

- **Worlds:** up to 32 players on the same maps. Form a party to play the story together and fight co-op battles.
- **PvP battles:** your Frontline against a friend's, live, each of you commanding your own team.

## Requirements

- Monster Girl Quest! Paradox RPG 3.06, with or without the English translation. Everyone needs the same game version and the same version of this mod. A translated and an untranslated game can play together; each shows battles in its own language.
- The community's mod loader: the `Patch.rb` from [*Patch.rb (enable Type 1 mods)*](https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)) on the MGQ wiki, in your `Patch` folder.

Optional:

- [Discord Rich Presence](https://github.com/Pauliinchen/MGQ-Paradox-Discord-Rich-Presence) 1.5.1 or later: invite friends through Discord instead of sending a join code, show on your profile who you're playing with, and use your Discord name in worlds.
- [Battle Dialogue](https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/tree/main/Battle_Dialogue): shows what characters say in boxes at the screen's sides, so nobody waits for another player to press a key.

## Install

Close the game and extract the release zip into the folder that contains `Game.exe`. You then have `Multiplayer.rb` in your `Patch` folder, and next to it a `Multiplayer` folder with everything else of the mod: the DLL, the other scripts, and later your name, worlds and logs.
While the mod is installed, the game keeps running when its window is in the background, so no player holds the others up. A gamepad does nothing meanwhile.

## Update

When a new release is out, the title screen says so. Until you update, *Multiplayer* is greyed out and F11 doesn't open PvP battles, since everyone needs the same version.

Close the game and double-click `Patch\Multiplayer\Update.bat`. It shows what's new, downloads the release, installs it, and removes files an older version left behind. Your player name, favourites and worlds are kept.

## Uninstall

Close the game and delete `Multiplayer.rb` and the `Multiplayer` folder in `Patch`. That folder also holds your worlds: keep `Patch\Multiplayer\Worlds` if you want to play them again later. The mod loader stays for your other mods.

## Worlds

Pick **Multiplayer** below *Continue* on the title screen. The first time, the game asks for the name the others see, unless the Discord mod knows yours. Names and passwords are typed on the keyboard; with a gamepad, the game's letters appear.

Each world keeps its own saves, Library, medals and affection in `Patch\Multiplayer\Worlds`, so your own game stays untouched. Going back to the title screen leaves the world.

### Finding, creating and joining

The list at the left shows every public world and the hidden worlds you joined: your favourites first (marked `*`), then the ones you played last. The right side shows who made the chosen world, how many of its players are online, and everyone who ever joined it.

- **Enter a world:** type its password the first time; your game remembers it after that. You continue from your latest save in that world; the first time, you start at the opening or from the creator's save.
- **Create new world:** point at it and fill in the form at the right: a name, a password, and Max Players (2 to 32).
  - *Hidden* leaves the world out of the list. Only its players see it there.
  - *From my save* lets every new player start from one of your saves, with your party, items, story and Library, instead of the opening. Choose the save after ticking it.
  - Max Players and the starting save can't be changed later.
- **Join a hidden world:** type or paste (Ctrl+V) the world id its creator sent you, and its password. The creator copies the id with *Copy the world id* on the world.
- **The creator** can remove a player, who can then no longer enter, or delete the world for everyone.

### On the map

- **Other players** on your map walk around with their name above them and an icon for what they're doing: fighting, talking or watching an event, typing in the chat, in a menu, the inventory or their equipment, shopping, at the casino, in the Library, sailing, flying, or away. They walk through everything and trigger nothing.
- **Ping** shows after each player's name, and yours right above your head: green up to 100 ms, yellow up to 200 ms, red beyond.
- **The bottom left** of the screen tells who joined and left, and when the connection is being restored.
- **The world never pauses.** While you're in a menu, a shop, a battle or a story scene, the map goes on behind it: the others walk on, NPCs move, and background events and timers run. Menus show the live map instead of a still picture. Anything that needs you, such as a message, a battle, a move to another map, or an NPC walking into you, waits until you're back on the map.
- PvP battles (F11) are off while you're in a world.

### Action wheel and chat

- **Action wheel:** press **B** on the map. Pick a choice with the arrow keys and take it with the confirm button; **B** or cancel closes the wheel. Grey choices can't be taken right now and tell you why. Duels are shown already and come in a later version.
- **Chat:** press **T**, or pick *Chat* in the wheel. **Enter** sends, **Esc** closes; the arrow keys, **Home** and **End** move the cursor, and **Delete** removes the character after it. Your line shows in a speech bubble above your head for the players on your map, and in the chat log at the bottom left for everyone in the world.

### Parties

- **Forming one:** stand next to another player, open the wheel and pick *Invite to a party*. "Invites to a party (B)" shows above your head on their screen for 15 seconds; when they pick *Accept* in their wheel next to you, you're a party. *Leave the party* at the bottom of the wheel leaves it.
- **Who's in it:** party members are fully visible with green names; everyone else is slightly see-through.
- **NPCs:** on a map you share, you all see the same NPCs in the same places. Whoever of you entered the map first is its Map Owner, and the NPCs move as they do in that player's game.
- **Story:** everyone plays the story of the player who made the party. Its events, doors and conversations are as far along as in that player's game, and story events you start are handed to them. Everyone on the map sees the dialogue in their own message window, at their own pace. Conversations, shops and the job change menu stay your own.
- **What stays yours:** your party, companions and affection, and your saves keep your own story. When you leave the party, you're back in your own story. If your story was exactly as far along as theirs when you joined, you keep what you played together, companions who joined in the story included.
- **Travelling:** when the player who made the party goes to another map, everyone follows. When a story scene starts, everyone on that map is brought to them.
- **Chests** are everyone's own: when a member opens one, everyone in the party who hasn't looted it yet gets the same items.

### Co-op battles

When a battle starts for a party member, whether a random encounter, a wandering monster or a story boss, the party members playing on the same map join it.

- With two players, each brings the first two of their Frontline; with three or four, each brings their first.
- Everyone commands their own characters. The game where the battle started works it out.
- Each of you can try to escape. Whoever gets away leaves the battle, and the others fight on without their characters. The one left alone fights on with their own full team.
- Each of you gets the full EXP, gold and your own item drops, or your own defeat.

## PvP battles

Press **F11** on the map to open the PvP battle screen.

- **Host:** your game waits for a friend and puts a join code on your clipboard. Send it to your friend, or invite them through the **+** in a Discord chat when the Discord mod is installed.
- **Join:** copy your friend's join code and pick *Join with the copied code*, or accept their Discord invite: your game starts if it's closed, loads your newest save (the one *Continue* picks first) and joins by itself. While you host, invites you accept are ignored; stop hosting first.
- **Fight your own team:** a mirror match against your own Frontline, no network needed. `Patch\Multiplayer\Mirror Match.log` then lists each of your characters next to its copy and marks every value that differs.

Once the teams are swapped, both battles start together. The host's game works the battle out, and the other game shows what happened. You meet your friend's characters as they are: jobs, races, equipment, gems and abilities, pre-battle spells and passives included. A defeated character of your friend stays as a grey silhouette, since their team can still revive it.

- Only the Frontline fights.
- **Escape** gives the battle up at once. If your friend leaves or the connection breaks, you win.
- After waiting 10 seconds for your friend, **Cancel** lets you leave the battle, which also gives it up.
- **Nothing carries over:** no EXP, gold or items, and your save, the Library and affection are put back exactly as they were.

## Rules of every multiplayer battle

Ero offers, Give Up and swapping in the backline are off. Battle messages move on by themselves, so nobody waits for another player.

## Connection

Your games meet at the mod's **relay**, a small server that passes their data on. Every game only connects out to it, which works on any internet connection: nobody has to open a port, change a router setting or install anything.

- **Private:** everything your games send each other is encrypted with a key only the players have. The relay never gets it: it passes on data it can't read.
- **What the relay keeps:** the list of worlds, with each world's name, its players' names and who is online; hidden worlds are listed only for their players. A world's password never reaches it, and a starting save arrives encrypted.
- **No addresses:** a join code holds a random token and the relay's name, so your friend's game never learns your IP address.

## Troubleshooting

- **Multiplayer is greyed out on the title screen:** a new release is out. Update with `Patch\Multiplayer\Update.bat`, see [Update](#update).
- **"Your friend's game is not hosting with this join code any more":** your friend stopped hosting, or hosted again, which makes a new join code. Ask for the new one.
- **"The relay could not be reached":** your internet connection is down, or something blocks the game from going online, such as a firewall. `Patch\Multiplayer\Multiplayer.log` says what the relay answered.
- **"This join code comes from another version of the mod":** one of you has an older version; both need the same one.
- **"Your friend's game uses a relay this version does not know":** your friend has a newer version of the mod; update yours.
- **"This is a world code":** you pasted a world's code into a PvP join. Enter worlds through *Multiplayer* on the title screen.
- **Logs:** `Patch\Multiplayer\InGame.log` only appears when something went wrong inside the game; `Patch\Multiplayer\Multiplayer.log` tells what the connection did. Please attach both when [opening an issue](https://github.com/Pauliinchen/MGQ-Online/issues).

## Building from source

See [docs/DEVELOPER.md](docs/DEVELOPER.md).

## Disclaimer

Monster Girl Quest! Online is an unofficial fan project. It is not affiliated with or endorsed by Torotoro Resistance, the creators of Monster Girl Quest!, or the English translation team. It contains no game or translation files.
