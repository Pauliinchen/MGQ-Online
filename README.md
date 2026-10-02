# Monster Girl Quest! Online

*An unofficial multiplayer mod for Monster Girl Quest! Paradox RPG.*

Play Monster Girl Quest! Paradox RPG together with friends over the internet, with nothing to set up in your router.

- **Worlds:** up to 32 players on the same maps. Form a party to play the story together and fight co-op battles.
- **PvP battles:** your Frontline against a friend's, live, each of you commanding your own team.

Worlds, parties and co-op battles are a **prototype**: expect bugs, and please [report them](https://github.com/Pauliinchen/MGQ-Online/issues/new?template=bug_report.yml).

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

- **Enter a world:** type its password the first time; your game remembers it after that. You continue from your latest save in that world; the first time, you start at the opening or from the creator's save, or choose where to start if the creator let you.
- **Create new world:** point at it and fill in the form at the right: a name, a password, and Max Players (2 to 32).
  - *Hidden* leaves the world out of the list. Only its players see it there.
  - *From my save* lets every new player start from one of your saves, with your party, items, story and Library, instead of the opening. Choose the save after ticking it.
  - *Players choose their start* lets each new player choose when they first enter: at the beginning, from one of their own saves, or from yours if you ticked *From my save*. Their own save is copied into the world; the original stays untouched.
  - Max Players, the starting save and Players choose can't be changed later.
- **Join a hidden world:** type or paste (Ctrl+V) the world id its creator sent you, and its password. The creator copies the id with *Copy the world id* on the world.
- **The creator** can remove a player, who can then no longer enter, or delete the world for everyone.

### On the map

- **Other players** on your map walk around with their name above them and an icon for what they're doing: fighting, talking or watching an event, typing in the chat, in a menu, the inventory or their equipment, shopping, at the casino, in the Library, sailing, flying, or away. They walk through everything and trigger nothing.
- **Ping** shows after each player's name, and yours right above your head: green up to 100 ms, yellow up to 200 ms, red beyond.
- **The bottom left** of the screen tells who joined and left, and when the connection is being restored.
- **The world never pauses.** While you're in a menu, a shop, a battle or a story scene, the map goes on behind it: the others walk on, NPCs move, and background events and timers run. Menus show the live map instead of a still picture. Anything that needs you, such as a message, a battle, a move to another map, or an NPC walking into you, waits until you're back on the map.
- The PvP battle screen is off while you're in a world: challenge other players to a duel instead, and F11 opens the World overview.

### Action wheel and chat

- **Action wheel:** press **B** on the map. Pick a choice with the arrow keys and take it with the confirm button; **B** or cancel closes the wheel. Grey choices can't be taken right now and tell you why. The wheel opens on its middle, the globe over your character, which opens the World overview; an arrow picks a side, the opposite arrow goes back.
- **Chat:** press **T**, or pick *Chat* in the wheel. **Enter** sends, **Esc** closes; the arrow keys, **Home** and **End** move the cursor, and **Delete** removes the character after it. Your line shows in a speech bubble above your head for the players on your map, and in the chat log at the bottom left for everyone in the world. The chat works in battles too, where its log sits above the battle's windows.

### World overview

- **Open it** with **F11** or the middle of the action wheel; **F11**, **B**, cancel or a click outside it closes it. The world keeps running behind it.
- **Every player online**, grouped by where they are, yours first: their name, the level of their highest companion, where they are in the story ("Part 2: Alice side") and their ping. Party leaders have a crown, a party's size shows as "2 / 4", and your party's members are green, you included. A player whose party invite or duel challenge reaches you shows "Invites you to a party" or "Challenges you to a duel" in their row.
- **Pick a player** with the arrow keys and confirm, or click them, for a menu: invite them to your party or accept their invite, and challenge them to a duel or accept theirs, wherever in the world they are. As your party's leader you also remove members here. On your own row you can leave your party or stop inviting.

### Parties

- **Forming one:** stand next to another player, open the wheel and pick *Invite to a party*. "Invites to a party (B)" shows above your head on their screen for 15 seconds; when they pick *Accept* in their wheel next to you, you're a party. A party holds up to four players, and only its leader, the player who made it, invites more and removes members (in the World overview). *Leave the party* at the bottom of the wheel leaves it.
- **Who's in it:** party members are fully visible with green names; everyone else is slightly see-through. A party's size shows after its players' names and above your head ("2 / 4"), its leader has a crown, and Discord shows it as "(2 of 4)". A box at the top right of the map lists your party, its leader first and then by name, with each player's highest companion level, ping, and where they are on a line below (long names shortened).
- **Your squad:** a party shares one team's worth of companions. The Frontline's four places and the Backline's are split between you, the player who made the party taking any place left over: with two players, each has two in front and half of the Backline; with three, the player who made the party has two in front and the others one; with four, everyone has one. Your Formation screens show your whole team: your share of the Frontline as the Frontline, your share of the Backline as the game shows the Backline, and the companions past your share in black and white below a line, so you can see who stays home.
- **Followers:** only your share of the Frontline walks behind you, and behind your ghost on the other members' screens; with one place in front, you walk alone. The player who made the party can show nobody but the players instead: *Mod Config → Monster Girl Quest! Online → Party Followers*.
- **NPCs:** on a map you share, you all see the same NPCs in the same places. Whoever of you entered the map first is its Map Owner, and the NPCs move as they do in that player's game.
- **Story:** everyone plays the story of the player who made the party. Its events, doors and conversations are as far along as in that player's game, and story events you start are handed to them. Everyone on the map sees the dialogue in their own message window, which moves on when that player moves on; only they can continue or close it. Conversations, shops and the job change menu stay your own, and so do the companions, merchants, inn and maids of the Pocket Castle.
- **What stays yours:** your party, companions and affection, and your saves keep your own story. When you leave the party, you're back in your own story. If your story was exactly as far along as theirs when you joined, you keep what you played together, companions who joined in the story included.
- **Travelling:** everyone goes where they like; only story scenes bring the party together.
- **Story scenes wait for everyone:** when the player who made the party starts a story scene, it waits until every member stands next to them, and they can't move meanwhile. Members see a 5-second countdown above their head to finish what they're doing, then are brought over, wherever they are; a member in a battle or a menu comes once it's over. No random encounter or co-op battle starts for them during the countdown. The scene waits 30 seconds at most, then starts without whoever hasn't come; they play on where they are. While the scene plays, the members on that map stand still and can't open the menu.
- **Chests** are everyone's own: when a member opens one, everyone in the party who hasn't looted it yet gets the same items.

### Co-op battles

When a battle starts for a party member, whether a random encounter, a wandering monster or a story boss, the party members playing on the same map join it.

- Each of you brings your squad: your share of the Frontline fights, your share of the Backline waits. The companions past it stay out of the battle.
- Everyone commands their own characters and can swap their own Backline in with *Party*. The game where the battle started works it out.
- Everyone fights the enemies of the game where the battle started, even when a mod there changes them, such as one that doubles them.
- Each of you can try to escape. Whoever gets away leaves the battle, and the others fight on without their characters. Everyone still in the battle reads "<name> left the battle." in the chat log at once; the characters leave at the next round. The one left alone fights on with their own full team.
- Each of you gets the full EXP, gold and your own item drops, or your own defeat.

### Duels

- **Challenge** the players next to you with *Challenge to a duel* on the right of the action wheel, or one player anywhere through the World overview. "Challenges you to a duel (B)" shows above your head on their screen for 15 seconds.
- **Accept** in the wheel next to them, or in the World overview. The duel is the same PvP battle as F11 outside a world: your Frontline against theirs, each commanding their own team, and both games are put back as they were afterwards.
- **Team duels:** when a party's leader duels, their whole party fights, and so does the other player's party when they lead one. Everyone gets ready on the map; the duel starts once all are ready, or after 10 seconds with those who are. Each player brings their share of the Frontline, as in co-op battles, and commands their own characters; a player alone brings their whole Frontline. Whoever leaves the duel leaves their characters to the next player of their side, who commands them from then on.

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
- **Logs:** `Patch\Multiplayer\InGame.log` only appears when something went wrong inside the game; `Patch\Multiplayer\Multiplayer.log` tells what the connection did. Please attach both to a [bug report](https://github.com/Pauliinchen/MGQ-Online/issues/new?template=bug_report.yml).

## Building from source

See [docs/DEVELOPER.md](docs/DEVELOPER.md).

## Disclaimer

Monster Girl Quest! Online is an unofficial fan project. It is not affiliated with or endorsed by Torotoro Resistance, the creators of Monster Girl Quest!, or the English translation team. It contains no game or translation files.
