# Player guide

Everything Monster Girl Quest! Online does, for players. To install the mod, see the [README](../README.md).

- [Hotkeys](#hotkeys)
- [Interface](#interface)
- [Worlds](#worlds)
- [On the map](#on-the-map)
- [Parties](#parties)
- [Raid Worlds](#raid-worlds)
- [Co-op battles](#co-op-battles)
- [Duels](#duels)
- [Trading](#trading)
- [PvP battles](#pvp-battles)
- [Rules of every multiplayer battle](#rules-of-every-multiplayer-battle)
- [Connection and privacy](#connection-and-privacy)
- [Troubleshooting](#troubleshooting)

## Hotkeys

| Hotkey | What it does |
|---|---|
| **B** | Opens the action wheel. |
| **T** | Opens the chat. |
| **E** | Opens the emote wheel. |
| **F11** | Opens the World overview, or the PvP battle screen outside a world. |
| **Y** / **N** | Accepts / declines the first invite in the notification box, and answers a question box (see [Notifications](#notifications)). |
| **Tab** | Makes the party box small or full. In a raid boss battle, shrinks the boss's HP bar to the bars alone, without its title and the names, or back. |
| **J** | Joins the battle of a player next to you in a Raid World, or fights a raid boss alongside a full boss battle, while the prompt below your character shows. |

This guide names the default hotkeys. To bind others, open *Mod Config → Monster Girl Quest! Online*, confirm the hotkey's row (*Action Wheel*, *Chat*, *World Overview*, *Accept Notification*, *Decline Notification*, *Emote Wheel*, *Party Box Size* or *Join Battle*) and press the new key; **Esc** keeps the old one.

- Keys the game uses itself can't be bound: the arrows, Enter, Space, Esc, Z, X, Shift, Ctrl, A, S, D, Q, W, Page Up, Page Down, numpad 0, 2, 4, 6 and 8, F1, F2, F5 to F9 and F12. Neither can a key another hotkey already uses.
- Your hotkeys are kept in `Patch\Multiplayer\Player.ini`, so they hold in every save and every world, and the texts in the game name the hotkeys you bound.

## Interface

**Look.** *Mod Config → Monster Girl Quest! Online → Interface Look* sets the colors of every box, frame and window of the mod:

- **Monarch** (the default): dark maroon with a gold edge in a black rim and gold titles, the look of the raid boss bar.
- **Legacy**: black glass with a thin grey edge, the look the mod had before.

The raid boss bar's red HP stays red in both.

**Moving and resizing.** Hold the left **Alt** and every box of the mod you can move gets a white outline with its name, and the screen names the controls at its bottom:

- Drag inside a box to move it.
- Drag its edge or corner to resize it. Some boxes only change their width, since their height follows what they show.
- Double-click a box to put it back where it starts.

The boxes you can move: the chat (on the map and in battles, each its own place), the notification box, the party box, the world status lines, the World overview, the raid boss bar, the waiting box of a co-op battle, the question and message boxes, and the list box of the world screen. Things that follow a character (names, bubbles, wheels, the bar above a raid boss) stay with it.

- A box never gets smaller than it needs to show everything it holds, and never leaves the screen.
- While **Alt** is held, the mouse only moves and resizes; clicks don't reach the boxes.
- *Mod Config → Monster Girl Quest! Online → Interface Positions* says *Moved* while any box is moved; pick *Default* to put every box back.
- The look and the places are kept in `Patch\Multiplayer\Player.ini`, so they hold in every save and every world, and a world that sets its mods' options never changes them.

## Worlds

Pick **Multiplayer** below *Continue* on the title screen. The first time, the game asks for the name the others see, unless the Discord mod knows yours. Names and passwords are typed on the keyboard; with a gamepad, the game's letters appear.

Each world keeps its own saves, Library, medals and affection in `Patch\Multiplayer\Worlds`, so your own game stays untouched. Going back to the title screen leaves the world.

### The world screen

![The world screen: the worlds and commands at the left, a world's details at the right](images/world-list.png)

The left side has two boxes: the worlds, and below them the commands (*Create new world*, *Add a hidden world*, *Change your name*, *Back*). Up and down pick a box, confirm moves into it and cancel moves back out, so the commands are reached without scrolling through a long list. Cancel with a box picked leaves the screen.

**Your name** is the one the others see: your name on Discord, until you choose one in *Change your name*, typed in place at the right; **Enter** keeps it. Without Discord and without a name, the world screen asks for one when it opens. The last name Discord told stands in while Discord is still connecting, such as right after a restart.

The worlds box lists every public world, the hidden worlds you joined and the hidden worlds you added by their id, in this order:

1. the Raid Worlds, in red, even above your favourites; a featured Raid World is red rather than gold;
2. your favourites, marked `*`;
3. the featured worlds in gold, which the relay's admins run;
4. the ones you played last.

Worlds you played that the relay no longer lists, such as one its creator deleted, come last.

With the cursor on a world, the right side shows its details: who made it, its password (*None*, *Needed*, or *Known* once this PC entered it with the password), its players, how new players start, the mods it needs, whether your game data matches the creator's, and its description. The right arrow moves into the details; up and down pick the mods, *Your game*, the players or the description, and confirm (or a click) opens the full list or text. Every player who ever joined is listed, those online first. The left arrow or cancel goes back to the list.

### Entering a world

Confirm on a world and pick *Enter the world*.

- Type its password the first time, unless it has none; your game remembers it after that.
- You continue from your latest save in that world. The first time, you start at the opening or from the creator's save, or choose where to start if the creator lets you.
- A world is only entered once the list has loaded, since the list tells what the world asks of your game.
- **Through Discord** (with the Discord mod): while you play in a world, friends can be invited through the **+** in a Discord chat or ask to join from your profile. Accepting starts their game if it's closed and enters the world from the title screen, without its password; a friend in the middle of a game is told to go back to the title screen. Discord offers no invite while the party it shows is full.

### Creating a world

*Create new world* opens a form at the right. Creating a world does not enter it: it appears in the list, marked as a favourite, the cursor lands on it ("\<name> was created. Confirm to enter it.") and you enter it from there.

| Field | What it does |
|---|---|
| Name | What the list shows. |
| Password | Left empty, anyone may enter. |
| Max Players | 2 to 32. |
| Hidden | Leaves the world out of the list. Only its players see it, and whoever adds it by its id. |
| World type | *Classic*: each party plays its own story, as described under [Parties](#parties). *Raid*: the whole world plays one story together, see [Raid Worlds](#raid-worlds). Fixed once created. |
| Sharing companions | Raid World only. *Off*: everyone recruits their own companions. *Story companions*: once any player has a companion the story brings, every other player gets them on reaching that companion's level. *Story + battle recruits*: the same, also for companions recruited after a battle. Nobody gets back a companion they had, or one their own story took away for good. Fixed once created. |
| Shared save | Every new player starts from one of your saves, with your party, items, story and Library, instead of the opening. Choose the save after ticking it. Not in a Raid World, which starts from the beginning. |
| Player's choice | Each new player chooses when they first enter: the beginning, one of their own saves, or yours if *Shared save* is ticked. Their own save is copied into the world; the original stays untouched. Not in a Raid World. |
| Difficulty | Raid World only: the difficulty every player plays on. The game's own difficulty choice and the Reaper's change set this one instead of the one picked. The Labyrinth of Chaos, the Colosseum and the bosses with their own difficulty keep theirs, and a battle you join fights with its host's. |
| Mods | The mods of the world, picked from a list of yours. See [Mods of a world](#mods-of-a-world). |
| Allow data mismatch | Unticked at first: a game whose data differs from yours can't enter. Ticked, it is warned and may enter anyway. See [Game data](#game-data). |
| Shared Mod Settings | Ticked: every player in the world plays with your options of its mods. Unticked: each keeps their own. See [Mods of a world](#mods-of-a-world). |
| Turn off other mods | While a player is in the world, their mods the world doesn't name are off. Ticked at first for a Raid World, unticked for a Classic one, until you tick or untick it yourself. See [Turning off other mods](#turning-off-other-mods). |
| Description | What the world is about, up to 1000 characters. |

The creator can change Max Players, Mods, *Shared Mod Settings*, *Turn off other mods*, the Description and a Raid World's Difficulty later with *Edit the world*; a new difficulty reaches the players in the world at once. A Raid World made without one shows *Per player* there until a difficulty is picked. Everything else is fixed once the world exists.

### Managing worlds

- **Hidden worlds:** the creator copies the id with *Copy the world id* and sends it. The others pick *Add a hidden world* and type or paste it (Ctrl+V); **Enter** adds it, and the cursor lands on the world in their list ("\<name> was added to your list. Confirm to enter it."). *Remove from my list* takes it off again as long as you never entered it. Your game keeps the 50 worlds you added last.
- **Favourites:** *Mark as a favourite* puts a world at the top of your list.
- **Taking a save home:** *Copy my latest save to my game* on a world you've played, or *Copy to my game* in the menu while you're in it, copies that world's latest save into the first free slot of your own saves. Your own Library, medals and affection stay as they are.
- **Deleting your saves:** *Delete my saves of it* removes your saves of a world from this PC. You'd start anew there, and need its password again.
- **The creator** can remove a player, who can then no longer enter, or delete the world for everyone. The relay's admins can edit and delete any world.

### Mods of a world

*Mods* in the create or edit form opens a list of the mods in your `Patch` folder, all unlisted at first. The mod loader, this mod and Mod Config Remake aren't in it, since every player has them.

- **Enter** or a click on a mod lists or unlists it. *List all your mods* at the top lists every one at once, and then *Unlist all your mods* unlists them again.
- Each mod has two buttons at the right, under the columns *Required* and *Essential*, reached with the right arrow or a click: the red **!** makes it required, the orange **?** essential. A filled button shows how a mod is named; pressing it again makes the mod only listed.

| Mod is | Meaning |
|---|---|
| Listed | Only tells the players; keeps nobody out. |
| Required | A game needs a script `Name.rb` in its `Patch` folder, in the world's version, to enter. Case, spaces, underscores and hyphens don't matter. Shows first: green when you have the world's version, gold when yours is another, red when you don't have it. |
| Essential | For mods that are data files without a script. Keeps nobody out by itself; green while your game data matches the world's, gold otherwise. |

- *Add a mod by name* names a mod you don't have yourself, such as a mod of data files: its row becomes a text box, **Enter** adds the name you typed, **Esc** or numpad **0** goes back. Such a mod stays in the list when unlisted; **Del** removes it.
- The mods take 300 characters at most; the top right of the list says when a change would pass that. **Esc** or numpad **0** goes back to the form, which shows them as the world keeps them: `!` in front of a required mod, `?` in front of an essential one.

The details show each mod in a box of its own, as many as fit the row, and count the rest in a last box.

**Same version for everyone.** The relay keeps a catalog of mods its admins added, with each one's current version.

- When you enter a world, each required mod is compared with the catalog. If one is missing or another version, the world screen says which and offers *Download and restart*: it fetches the world's version, checks every file, puts it into your `Patch` folder, restarts the game and enters the world. Under Wine or Proton the game cannot restart itself: close it and start it again, and it enters the world. *See the mods* lists your version and the world's.
- A required mod the catalog doesn't know is compared with the creator's copy. If yours differs, get the creator's version from the mod's author; nothing downloads it for you.
- A new version only reaches players the next time they enter.

**The creator's settings.** With *Shared Mod Settings* ticked in the create or edit form, or switched *On* in *Mod Config → Monster Girl Quest! Online → Shared Mod Settings* while the creator plays in the world, the creator's options of the world's mods, required or listed, are the world's settings. Every player in the world gets them at once, and again whenever the creator changes an option; the notification box says what the world sets, and the menu shows those options greyed out as set by the world. Every player sees the row, but only the creator can switch it. Hotkeys and other personal options stay yours, and your own saves keep your own settings. The relay's admins can see and change a world's settings too; the creator's game then takes the admin's settings and tells the creator what changed.

### Turning off other mods

A world with *Turn off other mods* is played with the mods it names and nothing else. While you're in it, your game turns off every mod in your `Patch` folder that the world doesn't name in its mods, whether listed, required or essential, unless the relay's admins mark it **personal**. The mod loader, this mod and Mod Config Remake always stay on.

A script in a folder inside `Patch` belongs to the mod that folder is named after: `Patch\Luka_Replacer\heroes.rb` is Luka Replacer's, so it stays on when the world names Luka Replacer and is turned off with it otherwise. A script right in `Patch` is the mod its file is named after. Only scripts are moved; a mod's other files stay where they are.

- **Personal mods** stay on in every world, named or not, such as mods that only change how the game looks. The relay's admins decide which mods are personal.
- **The world's details** say *Other mods: turned off (2 of yours)* or *Other mods: allowed*. The mods box lists *Your mods turned off here* below the world's mods, one line per mod, saying how many scripts it has when there are several.
- **Entering** such a world while you have mods it turns off asks first: "These mods are turned off while you play in \<world>: ... Restart and join?". *See the mods* lists them, *Back* enters nothing. *Restart and join* moves them out of `Patch` into the `Parked mods` folder of your game folder, starts the game again and enters the world. The `Parked mods` folder only exists while mods are turned off; the game removes it once they're all back and it holds nothing else. When the world also needs a mod downloaded, one restart does both. The world is only entered once the mod catalog has loaded, since the catalog tells which mods are personal.
- **Your mods come back** when you go back to the title screen: "Your mods are back after a restart." shows and the game starts again on the title screen. They also come back when the game closes any other way, a crash included: a small helper waits in the background and puts them back once the game is gone, and the next start of the game checks again ("The game closed while mods were turned off. Your mods are back after a restart.").
- **When the creator or an admin changes the rule** while you're in the world, ticking *Turn off other mods* or changing the mods, and you now have mods on that the world turns off, the notification box says "\<world> now turns off other mods. Enter it again to play." and a few seconds later, once you're free on the map, the game goes to the title screen, as *To Title* does: anything you haven't saved is lost. Entering again turns the mods off.
- **Two games from the same game folder** never move mods under each other. While one of them has mods turned off, the other can't turn them on or off, and leaving a world there says "Another game of this folder has mods turned off. They come back when it closes."
- **A mod you put back into `Patch` yourself** while it was turned off is never overwritten: the turned-off copy goes to `Parked mods\Conflicts\<date and time>` instead. So does a turned-off mod whose file changed while it was turned off. The title screen then says how many went there ("2 of your mods went to Parked mods/Conflicts because another file took their place in Patch."). Leave the `Parked mods` folder alone while the game runs.
- **Mods behind a link:** a mod script in `Patch` that lies on another drive behind a link (a junction) is never turned off. A world that would turn it off can't be entered while it is installed: the world screen says how many such scripts there are and names the first.
- **Saving is off** outside a world while your other mods are turned off, such as after they could not come back on leaving a world: a save you make shows "Saving is off until your other mods are back. Start the game again to bring them back.", and the autosave is skipped. Saving inside a world works as usual.
- **A world's mods downloaded** while your other mods could not be turned off, or kept off, for the restart: the game stays on the world screen and asks you to try again, instead of restarting with your mods half turned off.
- **Updating the mod** while mods are turned off: they come back once the updater has started. If the updater can't start, they stay off until the next start of the game.
- **Under Wine or Proton** the game cannot start itself again: close it and start it yourself. It enters the world once it is back, and after you leave the world, the mods are back once you start it again.

### Game data

- **What is compared:** which actors, classes, skills, items, weapons, armors, enemies, states, troops, common events and maps exist. A mod that adds or removes any is noticed; a mod that only changes numbers isn't. A translated game still matches the untranslated one.
- **A game that differs:** the world's details say whether your game matches the creator's and, if not, in what. Entering then asks first, or is refused when the creator left *Allow data mismatch* unticked. Worlds made before this check say nothing and take every game.
- **Updating your world's data:** when a mod you play with gets an update, your game no longer matches your own world. Move onto *Your game* in the world's details and confirm, or press *Update current data scan* in *Edit the world*: the world takes your game's data as it is now, and everyone else has to match it again. Only the creator can do this.
- **In a world that turns other mods off**, the creator's scan may have been made with mods on that the world now turns off. When the creator enters it with them off and the data differs, the game asks to take the game's data as it is now first.

## On the map

![The action wheel, with a chat bubble and the party box](images/action-wheel.png)

- **Other players** on your map walk around with their name above them and an icon for what they're doing: fighting, talking or watching an event, typing (a keyboard), in a menu, the inventory or their equipment, shopping, at the casino, in the Library, sailing, flying, or away. They walk through everything and trigger nothing.
- **Player colors:** your own name is yellow, your party's members are green, and everyone else is white. The party box, the World overview, the chat and co-op battles use the same colors. A companion following them whose picture your game lacks, such as one from a hero pack you don't have, shows as an outline: green for your party's members, white for anyone else.
- **Ping** shows after each player's name, and yours above your head: green up to 100 ms, yellow up to 200 ms, red beyond; past 999 ms it says "999+ ms".
- **Above your own head** the mod says what you're waiting for, with the seconds it still stands: "Inviting to a party (12 s) . . .", "Asking \<name> to teleport (45 s) . . .", "Challenging to a duel (9 s) . . ." and the like.
- **The bottom left** tells who joined and left, and when the connection is being restored. A player whose connection drops stays in the world and in their party for 15 seconds, so a short break changes nothing.
- **The world never pauses.** While you're in a menu, a shop, a battle or a story scene, the map goes on behind it: the others walk on, NPCs move, and background events and timers run. Menus show the live map instead of a still picture. Anything that needs you, such as a message, a battle, a move to another map or an NPC walking into you, waits until you're back on the map.
- **No PvP battle screen** while you're in a world: challenge other players to a [duel](#duels) instead.

### Where the others are

A small triangle at the edge of the screen points at every party member on your map who is off the screen, in their color, with their name and how many tiles away they are. In a Raid World everyone on your map gets one, the nearest eight at most. The arrows fade out while a wheel, the World overview or the chat is open and while a message shows.

### Action wheel

Press **B** on the map. Its choices sit in a ring around your character. The wheel opens on the middle: the globe over your character, which opens the World overview. Hold an arrow, or two for a diagonal, to point at a choice; it stays picked when you let go, and a direction without a choice goes back to the middle. Confirm takes the choice pointed at, and **B**, cancel or numpad **0** closes the wheel; a hint below the wheel says so. Grey choices can't be taken right now and tell you why. The wheel fades in and out.

### Chat

![The open chat: the tabs above the log, the Party tab glowing for unread lines, and the hint in the empty box](images/chat.png)

Press **T**, or pick *Chat* in the wheel. The chat works on the map, in battles (above the battle's windows) and while your party gathers for a story scene.

| Key | What it does |
|---|---|
| **Enter** | Send the line |
| **Esc** or numpad **0** | Close the chat (Num Lock on or off) |
| **Up** / **Down** | Scroll the log; **Page Up** / **Page Down** a page at a time |
| **Alt** + **Left** / **Right** | Switch tabs (left Alt) |
| **Alt** + **Up** / **Down** | Bring back the lines you sent, the last 20, until you leave the world |
| **Alt** + drag | Move the chat, or resize it by an edge or corner (see [Interface](#interface)) |
| **Ctrl** + **V** | Paste |
| **Left**, **Right**, **Home**, **End**, **Delete** | Move the cursor and delete in the line |

The empty box names the controls, and shows the **Alt** ones while you hold it.

#### Chats and tabs

| Tab | Who reads it | Command |
|---|---|---|
| **All** | Every line you can see | |
| **Global** | Everyone in the world, in white | **/g** |
| **Map** | The players on your map, "[Map]" in light pink; where you start | **/m** |
| **Party** | Your party only, "[Party]" in blue | **/p** |
| **Whisper** | One player, in magenta; the tab shows once you whisper or get a whisper | **/w** and a name, or **/r** |

The chats take the colors World of Warcraft gives its chats.

- A command, or a click on a chat's tab, picks the chat your next lines go to; the box shows which. It stays until you pick another.
- For **/w**, a list of matching players shows above the box after the first letter of the name: **Up** and **Down** pick one, **Enter** or **Tab** takes it.
- **/r** whispers back to the last player who whispered to you; it's refused while nobody has, or once they left the world.
- **/help** opens a help tab at the far right.
- **Unread lines:** a tab glows yellow at its top right corner until you pick it or **All**, the **Whisper** tab too.
- **Closed chat:** the log at the bottom left shows the tab you picked last, plus whispers. While a tab has unread lines, the tabs show dimmed above the closed log, so you see the glow. A whisper that arrives while the chat is closed plays a short chime (the game's recovery sound). Lines fade away as they go.
- **Too fast:** Global lines are limited to two a second after a burst of ten; a faster one is turned down with "You are sending too fast".

#### Players in the chat

- Your line shows in a speech bubble in its chat's color just above your name, for the players on your map.
- Names are yellow for you, green for your party's members and white for everyone else.
- When several players share a name, the later ones show as "Name (2)", "Name (3)" in the log, above their head and in the whisper list.
- Click a player's name in the open chat to invite them to your party, challenge them to a duel, offer a trade or whisper to them. In a battle only the whisper is offered. **Esc** or numpad **0** closes the menu.

### Emotes

![An emote balloon above a player](images/emotes.png)

Press **E** on the map for a ring of eight emotes around your character: a jump, or a balloon such as a heart, a music note or a light bulb. Hold an arrow, or two for a diagonal, to point at one, like a joystick; it stays pointed at when you let go. Confirm plays the emote pointed at, or closes the wheel before you pointed at any; **E**, cancel or numpad **0** closes it too, as the hint below the wheel says. The players on your map see it on your character too.

### World overview

![The World overview](images/world-overview.png)

Press **F11** or pick the middle of the action wheel; **F11**, **B**, cancel, numpad **0** or a click outside closes it. The world keeps running behind it. The title names the world, its type and a Raid World's difficulty ("World | Raid | Hard") and your party's size, and two tabs below it hold the pages **Players** and **World**: **Left** and **Right**, or a click on a tab, switch between them.

**The Players page:**

- **Every player online**, grouped by where they are, yours first: their name in their color, the level of their highest companion, where they are in the story ("Part 2: Alice side") and their ping.
- Party leaders have a crown, a party's size shows as "2 / 4", and your party's members are green, you yellow. A player whose invite or challenge reaches you shows "Invites you to a party" or "Challenges you to a duel" in their row.
- **Pick a player** with the arrow keys and confirm, or click them, to invite them to your party or accept their invite, and to challenge them to a duel or accept theirs, wherever in the world they are. A party invite from afar stands for a minute; "Inviting to a party (58 s) . . ." above your head counts it down. As your party's leader you also remove members here, after a question ("Remove \<name> from the party?"). On your own row you can leave your party, after a question too, or stop inviting.

**The World page:**

- The world's name, its type (*Classic* or *Raid*), its difficulty (*Per player* in a Classic world), and its players online of its seats ("3 / 8").
- In a Raid World also where the world's story stands ("Part 2: Alice side", *Not told yet* before anyone moved it) and its **raid bosses**, grouped under a heading per part of the story in the order the story meets them: *Part 1*, *Part 2*, *Part 3*, *Angelic Dominion*, *Monster Realm*, *Chaos route* and *Chaos Domain*. Only the parts the world's story has reached show, and any part with a boss someone has fought already. Each boss shows its name, its tier, a thin gauge of the HP the world has left of it with the share ("68%"), *Defeated* once it fell, and who last hurt it. A boss nobody has fought yet is full.
- While you look at the World page, a gold corner on the *Players* tab tells you an invite, challenge or trade offer waits there; **Y** and **N** answer it once you're back on the Players page or have closed the overview.
- **Up** and **Down** scroll the page.

### Notifications

The box at the top left, on the map and in menus, lists the invites that reach you, such as party invites, duel challenges, trade offers and teleport requests, from anywhere in the world, for as long as they stand. Below them, messages show for a moment, such as a party member meeting enemies; "Enemies! \<name> is in a battle." stays as long as you stand still for that battle, and goes as soon as you may walk on. The box shows five rows, more or fewer once you resize it (see [Interface](#interface)); past them, the last counts the rest ("+2 more"). Messages fade away, and the box fades in and out.

**Y** accepts the first of them (a challenge only on the map), **N** declines it: the other player reads that you declined, and it stays away until they invite you anew.

**Questions.** Some choices ask first, in a box in the middle of the screen: leaving your party, removing a member, cancelling a trade. The box names its two answers; the safe one starts picked. **Y** takes the first answer, **N**, **Esc** or numpad **0** the second; **Left** and **Right** move the pick and confirm takes the picked one; a hint under the answers says so. While the box is open, the hotkeys below it do nothing, so a **Y** never answers an invite by mistake.

## Parties

![A party of three at the casino, with the party box at the top right](images/party-casino.png)

A party holds up to four players. Its leader is the player who made it: only they invite more and remove members (in the World overview).

### Forming a party

Stand next to another player, open the wheel and pick *Invite to a party*. "Invites to a party (B)" shows above your head on their screen for 15 seconds, and "Inviting to a party (15 s) . . ." above your own head counts them down; when they pick *Accept* in their wheel next to you, you're a party. *Leave the party* at the bottom left of the wheel leaves it.

### Seeing your party

- Party members are fully visible with green names; everyone else is slightly see-through, in white, except in a Raid World, where everyone on the map is fully visible.
- A party's size shows after its players' names and above your head ("2 / 4"), and its leader has a crown. Discord shows it as "(2 of 4)".
- **The party box** at the top right lists your party, its leader first and then by name: the crown, the icon of what they're doing, their name (yours in yellow, the others in green, a long one cut with "..."), their highest companion level, their ping in its own column ("999+ ms" at most) and where they are on a smaller line. A member whose connection dropped shows dimmed with the away icon until they're back. The title names the hotkey that resizes the box: **Tab** makes it small, with only icons, names and pings, and full again; it stays as you left it. The box fades in and out.
- **The map box:** in a Raid World the party box lists everyone on your map instead, while anyone else is on it: your party first, in green, with its leader's crown, then the other players by name in white, each with their icon, the level of their Frontline character and their ping, without a place. Its title says how many are on the map ("Map 4"). It grows up to 10 lines; with more players the last line says "+3 more". **Tab** makes it small too.

### Your squad

A party shares one team's worth of companions. The Frontline's four places and the Backline's are split between you, and the leader takes any place left over:

| Players | Frontline places each |
|---|---|
| 2 | 2 each, and half of the Backline each |
| 3 | 2 for the leader, 1 for the others |
| 4 | 1 each |

Your Formation screens show your whole team: your share of the Frontline as the Frontline, your share of the Backline as the Backline, and the companions past your share in black and white below a line, so you can see who stays home.

- **Followers:** only your share of the Frontline walks behind you, also on the other members' screens; with one place in front, you walk alone. The leader can show nobody but the players instead: *Mod Config → Monster Girl Quest! Online → Party Followers*.
- **In a Raid World** everyone has a squad, in a party or not and whatever the party's size: one Frontline and two Backline characters. The fourth character of your team is cut: the formation screens show them in black and white below the line, and they fight in no battle, your own and duels included. Your team holds four at most there; a companion who joins a full team waits in the Pocket Castle. Nobody walks behind anyone on the map: followers are hidden.
- **NPCs:** on a map you share, you all see the same NPCs in the same places. Whoever of you entered the map first is its Map Owner, and the NPCs move as they do in that player's game. In the Pocket Castle it's always the leader: you see their companions, and one you don't have yourself stands there see-through, a ghost you can't talk to. Your own companions stay yours to talk to.

### The story

In a Raid World nobody plays a leader's story: the whole world plays one, see [The story in a Raid World](#the-story-in-a-raid-world). Everything below is about Classic worlds.

Members close to the leader in the story play the leader's story. Its events, doors and conversations are as far along as in the leader's game, and only the leader starts story events: a member reads "Only \<leader> can move the story on."

- **Who plays the leader's story:** before the Great Decision, a member at most two story steps ahead of or behind the leader; after it, a member on the same route as the leader, at most five steps apart on it. You read "You follow \<leader>'s story while in the party." when it starts.
- Everyone else plays their own story while in the party: their own story events, scenes and progress, untouched by the leader's. They read why, such as "You and \<leader> are too far apart in the story; each of you plays your own.", or that you're on different sides of the Great Decision or on different routes. The map, battles, chat, trading, duels, the Pocket Castle and the chests you open stay shared all the same.
- This is checked again whenever your or the leader's story moves on, so two players who drift apart each go on with their own, and two who come close play together.
- Scenes replayed from the Library stay your own: the leader's replay never pulls the party in.

- Every member on the map who plays the leader's story sees the dialogue in their own message window, which moves on when the leader moves on; only the leader can continue or close it.
- The story's pictures, such as its CGs, and its fades, tints and flashes show for them too.
- Conversations, shops (the Casino's coin sellers too) and the job change menu stay your own, and so do the companions, merchants, inn and maids of the Pocket Castle.
- A trader whose talk would move a side quest on stops there for a member; the leader's talk moves it on for the party.

**What stays yours:** your party, companions and affection, the side you chose (Alice or Ilias), and your saves keep your own story. When you leave the party, you're back in your own story.

- If your story was as far along as the leader's or behind it when you joined, you keep what you play together: the story's progress, its items and gold, and the companions who join or leave in it.
- If you were a step or two behind, you catch up with the leader's story at once: you get the story's skills, companions and items the leader has, and keep the leader's progress when you leave. Side quests you played that the leader never touched stay yours, and so do chests: one only the leader looted is still there for you to open.
- Where Alice's and Ilias's side get different skills or companions, such as Luka's training at the camps or the companions who join at the Strategy Conference, you get those of your own side once the leader's story gets past that point, even where only your side gets someone. If you have not chosen a side yet, you choose once the leader has, and your companion joins you.
- After the Great Decision you follow the leader's route and get its companions.
- If you were ahead of the leader, you borrow the leader's key items you lack, such as the one that opens a locked door, while you're in the party. They go back when you leave it and stay out of your saves, and you borrow them again after a crash, a load or a duel.
- When the party brings you into the Pocket Castle, its way out takes you back to where you came from.

**Your own choices:** the story's choices are yours, whatever the leader chose: Alice or Ilias, Amira in Iliasburg, Lily or Lucia in Magistea Village, the Priestess or the Queen Bee at Plansect, Natasha or the mayor in Succubus Village, the Spider Princess or the Queen Ants, the Sphinx, and the Great Decision. The companions they bring join you only by your own answer.

- **Sync story:** a leader can bring a member who is behind up to their own point in the story: *Sync story* in the member's menu of the World overview. The member accepts or declines in the notification box ("\<leader> offers to bring your story up to theirs").
- Accepting opens one screen with every choice the jump carries you past, in story order, each with what your answer brings ("Lucia joins.", "Nobody joins: Natasha joins only while Lily is with you."). Left/Right, Enter or a click change an answer; *Bring me there* takes them all, *Cancel* leaves your story as it is. Amira is always asked until she joined you, since a killed Amira comes back.
- **The Great Decision:** "Side with the Dark Goddess (World Breaker)" leads to the Angelic Dominion route, "Side with the Goddess Ilias (Judgement)" to the Monster Realm route, and "Search for a third way (Chaos)" shows only if your own save cleared both endings. The leader's route catches you up with them; another route starts you at that route's beginning, where you play it on your own ("You start your own route. Each of you plays your own story.").
- While you play the leader's story, the same screen asks your own answer whenever the story passes one of these choices, or the leader makes one you haven't.

### Travelling and story scenes

Everyone goes where they like; only story scenes bring the party together.

- **Teleport to the leader:** *Teleport to \<leader>* takes the place of *Invite to a party* at the top of the wheel, and the leader's row in the World overview offers it too. It brings you over as soon as you're free on the map.
- **Teleport to another member:** *Ask to teleport to \<name>* in that member's row of the World overview; the leader asks this way too. They allow or decline it in the notification box ("\<name> asks to teleport to you") or in your row of their World overview; once allowed, you come over as soon as you're free. A request stands for a minute, counted down above your head ("Asking \<name> to teleport (45 s) . . ."), and *Stop asking to teleport* in your own row takes it back.
- **Busy when it's allowed:** an allowed teleport, to the leader or another member, waits up to a minute while you're in an event, a message or a menu, then lapses with "You were too busy to teleport to \<name>." Both teleports work in Classic and Raid Worlds alike.
- **Story scenes wait for everyone who plays the leader's story.** When the leader starts one, it waits until every such member stands next to them, and the leader can't move meanwhile. Members see a 5-second countdown above their head ("Joining \<leader> (4 s) . . .", then "Joining \<leader> once free . . .") to finish what they're doing, then are brought over from wherever they are; a member in a battle or a menu comes once it's over. No random encounter or co-op battle starts for them during the countdown.
- The scene waits 30 seconds at most, then starts without whoever hasn't come; they play on where they are. The leader's own line names up to two members still missing and counts the rest ("Gathering: \<name>, \<name> +1 (22 s) . . .").
- While the scene plays, the members on that map stand still and can't open the menu; the chat stays open. Story events don't get stuck on a member standing in their way.
- When a scene moves the leader somewhere else, such as onto a theater's stage and back, the members with them come along at once.

### Chests

Chests are everyone's own: when a member opens one, everyone in the party who hasn't looted it yet gets the same items, hears the chest open and sees the first item's icon in the notice; in a battle, once it's over.

## Raid Worlds

A Raid World plays one story for the whole world, and everyone on a map shares it, in a party or not. Everyone starts from the beginning, on the difficulty the creator set. Its battles are under [Co-op battles](#in-a-raid-world) and [Raid bosses](#raid-bosses), its squads and the map box under [Parties](#seeing-your-party).

### The story in a Raid World

- **One story:** the relay keeps the world's story, and whoever moves it on moves it on for everyone. Your game takes the world's story when you enter the world, load a save or start a new game, and whenever another player's story moved on, once you're free on the map. Your saves hold the world's story as it was then.
- **What stays yours:** your party, companions and affection, your side (Alice or Ilias), your own answers to the story's choices, and your chests. The chests that hold the story's key items are the world's: each opens once, for everyone.
- **Key items:** every key item the world's story gives or takes reaches every player, whatever part of the story they're in.
- **Telling the story:** a story event starts only while nobody else on your map tells one; otherwise you read "\<name> is telling the story here." Everyone on the map whose story stands where the teller's stood watches the scene, its dialogue, pictures and fades, and stands still while it plays, though not while the teller fights the story's battle. A player whose story stands elsewhere sees the NPCs move, but not the scene.
- **Two at once:** when two players on one map start a story event at the same moment, the one who came onto the map first goes on. The other's event waits a second at its start and usually stops before it changed anything; on a slow connection it can stop part-way. That second's wait comes before every story event while a player who came onto the map before you is on it.
- **NPCs:** everyone on a map sees the same NPCs, moved as in the game of whoever entered the map first.
- **Following the story:** when the story moves its teller to another map, the players watching it come along at once. Everyone else who was on that map, a player behind the world's story included, reads "\<name>'s story moved on to \<place>. Follow?" in the notification box: **Y** follows, **N** dismisses it. The offer stands while that story is still being told, for a minute at most.
- **Teleport to the story** on your own row of the World overview takes you where the world's story was last told, once you're free on the map. It's closed while you're behind.

### Behind the world's story

When your story is in an earlier part than the world's (Part 1, Part 2, Part 3 or a route), such as on your first entry into a world that played on without you, you're behind. In the world's own part you simply take the world's story, however far behind you were in it.

- **Your part's end:** you see the world as it was just before the end of your part and play on there ("The world's story is further than yours. You see the world as it was before the end of Part 1; reach level 25 to move on."). Story events don't start and say "Reach level 25 to continue the story."; side events, talks, shops, chests and battles work as usual.
- **Level gates:** once the highest base level among your characters reaches your part's gate, you move on ("Level 25 reached: catching up to Part 2."): Part 1 at 25, Part 2 at 55, Part 3 at 65, the Angelic Dominion and Monster Realm routes at 120, Chaos at 300. Each gate takes you to the next part the world played, one part at a time, until you're in the world's story. You never play a part's ending yourself.
- **Finished routes:** behind in Part 3 or earlier, you never catch up through a route the world already finished. At your part's gate you move straight into the world's current route, and you still get the finished route's story skills, key items and rewards; its companions join once you reach each one's level.
- **What the story carried you past:** its skills and items come to you with a notice. Its companions join once you reach the level they joined at ("\<name> joins you once you reach level 40."), and the companions it took away for good leave. The story's choices you were carried past are asked on the screen of choices, each with your own answer.
- **Your own changes stay:** side events and anything else you did while behind are kept when you move on; only what the world's story itself changed since then overrides them.
- **Loading and entering again** while behind keeps you behind until your level reaches your part's gate.

### The Great Decision

- **The first route chosen is the world's.** The first player to choose a route at the Great Decision chooses it for the whole world: from then on the choice offers only that route until the world finished it, and says "The whole world plays this route." A player who chose another route at the same moment reads "The world took the \<route> route first." and is taken to the story.
- **Carried past it:** a player the world's story carries past the Great Decision confirms the world's route on the screen of choices, which plays their own side's part of it.
- **Back to the Great Decision:** a finished route's credits take the world back to the Great Decision, and every player still on that route follows; the next route is chosen there, among those the world hasn't finished. The third way (Chaos) shows only once the world finished both others.
- **No reset:** the Reaper can't turn back time in a Raid World ("Time cannot be reset in a Raid World."), since one player would take the whole world back.

## Co-op battles

![A co-op battle: each player's characters carry their name](images/coop-battle.png)

When a battle starts for a party member, whether a random encounter, a wandering monster or a story boss, the party members playing on the same map join it.

- **Fewer encounters each:** in a Classic world your steps to the next random encounter are stretched once per party member on your map, within a wider random margin, so the party as a whole meets enemies about as often as a lone player would. In a Raid World every other player on your map adds half as much, up to the four players a battle holds, since they only fight with you as far as invites and hot-joins bring them.
- **Waiting for the party:** a random encounter waits up to 3 seconds for members on the same map who are in a menu, typing or on a vehicle. You stand still, they read "\<name> is in a battle!" in the notification box, and the battle starts as soon as they're back on the map. Whoever is still busy after 3 seconds misses it. Every member on that map stands still until they join, so nobody walks off first; "Enemies! \<name> is in a battle." shows for as long as they stand still.
- **The waiting box** in a battle says what your game waits for, who is still to come ("Still choosing: \<name>, \<name>", "Not ready: \<name>") and how long you've waited ("12 s"). The host's game names them, and the guests' boxes show the same names. After 10 seconds the last line offers to leave the battle with cancel instead.
- **Your squad fights:** your share of the Frontline fights and your share of the Backline waits. The companions past it stay out of the battle.
- **Everyone commands their own characters** and can swap their own Backline in with *Party*. The status window names each character in its player's color, yours in yellow, and another player's character by its own name; the battle's messages still add the player's name ("Alice (\<name>)"). When you swap out a character another player already chose a command for, such as a heal or a revive, that player chooses their commands again once everyone has chosen; their chat log tells them why. Their other characters' commands are cleared too, as the game's own *Party* does.
- **The leader's game runs the battle**, with the leader's difficulty and mods, whoever met the enemies: "Asking \<leader> to lead the battle..." shows meanwhile. When the leader isn't on that map, is busy or doesn't answer within 6 seconds, the game where the battle started runs it. Everyone fights that game's enemies, even when a mod there changes them, such as one that doubles them.
- **Level Sync:** when the leader fights in the battle, its level is the highest level among the leader's characters in it. Characters above it fight with the stats of that level, and their equipment loses half as much as the level takes; the chat log tells you when yours are synced. Levels, EXP, skills, jobs and races stay your own, and your full stats come back after the battle with the same share of HP and MP. Characters at or below the level fight as they are.
- **Escaping:** each of you can try. Whoever gets away leaves the battle, and the others fight on without their characters. Everyone still in it reads "\<name> left the battle." in the chat log at once, as they read "\<name> joined the battle." for a player who joins a running one; the characters leave at the next round. The one left alone fights on with their own full team.
- **Rewards:** each of you gets the full EXP, gold and your own item drops, or your own defeat. After a lost battle, everyone sees the defeat scene of the same enemy, the one the game running the battle chose.

### In a Raid World

A Raid World's battles take the players on the map, party or not, and some of the rules above change:

- **Whoever meets the enemies hosts the battle,** with their own difficulty and mods; nobody asks the leader. It invites the nearest free players on the map, your party's members first, up to four players, you included, and a busy party member is waited for as above. Players who watch the story you tell join its boss battle too.
- **Your squad fights:** every player brings one Frontline and two Backline characters.
- **No Level Sync:** everyone fights with their own levels.
- **Random encounters join a running battle:** when you meet enemies on a map where another player fights a battle that isn't a boss battle, an event's battle included, your game asks that battle to take you in. Your enemies and the players you'd bring along join it at its next turn ("Joining \<host>'s battle at its next turn...", with "Up to 75 s" and the seconds waited below it), as long as it then holds four players and eight enemies at most. When it can't take all of you, or doesn't answer within 3 seconds, your encounter starts as a battle of its own, which invites those players; anyone it doesn't invite walks on.
- **Joining by choice:** within 3 steps of a player in a battle that takes players in, "Press J to join battle" shows below your character. **J** asks its host, and you join at its next turn, an event's battle and a boss battle too. A battle that can't take you says why in the notification box, such as "Cannot join \<host>'s battle: it is full."
- A battle stays joinable, and shows as a battle, while its player has the Library or Config open from the battle's party command.

### Raid bosses

In a Raid World each story boss is one fight the whole world shares, and so are the six one-time bosses of the Chaos Domain (the Chaos' Phantoms). Its HP is kept on the relay, and every battle against it wears down the same HP, so a boss usually takes many battles, by many players, to fall.

- **Raid HP:** the boss has many times its usual max HP, by its tier: 5 times for the first bosses of the story (tier 9), 5 more for every tier above, up to 50 times for Chaos (tier 0). The bosses of tiers 0 to 5 also have up to 5 times their defense and magic defense. Both come on top of the world's difficulty.
- **Shared damage:** your battle tells the world what it dealt every couple of seconds, also in the middle of a long turn. While you choose your commands, and at the start of every round, the boss's HP is set to what the world has left of it, so damage dealt in other battles shows up there every few seconds.
- **It heals slowly:** a boss gets back 3% of its max HP a minute, also while it's being fought. A boss nobody fights fills up again in a little over half an hour.
- **Losing is fine:** a lost battle is an ordinary defeat, and the damage you dealt stays. A retry fights the boss with the HP the world has left.
- **The boss falls once its HP runs out,** whoever deals the last blow: every battle still fighting it wins at its next round, with the usual rewards. Everyone in the world reads "\<boss> is defeated for the whole world." The story goes on through the battle of the player who started it, and moves on for the whole world. A boss stays defeated for good; a battle that starts against it is won at once.
- **Bosses of several enemies,** such as Kagetsumugi and her dolls, have HP for each one. The bar shows a name and a gauge for each of them, side by side under one title, and the battle is won once all of them are down.
- **Watching the story:** players on the map who watch the scene leading up to the boss are invited to its battle too. A player who arrives while the boss battle already runs can move freely and join it with **J** next to the player fighting it.
- **Side battles:** when a boss battle near you, a side battle included, is full or won't take you in, the prompt below your character says "Press J to fight \<boss> alongside". Press **J** to fight the same boss in a battle of your own, so every player can fight a boss at the same time. It starts at once, invites and holds nobody, and other players near it can join it with **J**. It shares the same HP, plays no story scene and none of the boss's battle events, and losing it just brings you back to the map. You can't start one against a boss your own story has beaten already, or against a defeated one.
- **Side battle rewards:** the first side battle you win against a boss gives its EXP, gold and drops; later side battles against the same boss give none. The boss's own story battle still gives them. This holds for players who join a side battle too.

**The HP bars:**

- **In battle**, the top of the screen shows the boss's title (such as *Archangel*, *Phenomenon of Ruin* or *Tier 6 Raid Boss*), its name, and a big bar with its HP and the share left inside ("3,412,880 / 5,000,000  (68.3%)"). Very large HP is shortened, keeping at least 7 digits, such as "236,167 B / 1,009,500 B". A boss of several enemies, such as the Three Nobles of Black, gets a name and a bar for each of them, side by side under the one title, the three sharing the width. The bar hides while a message shows at the top of the screen. **Tab** shrinks it to the bars alone, without the title and the names, and back; a hint on the strip names the hotkey, and the game remembers your choice.
- **HP just lost** stays visible for 2 seconds as a darker part of the bar behind the HP left, then drains away, so you see each hit, yours and the other battles'.
- **On the map**, the boss's title and name with a thin bar above its event show its HP as the world has it right now, full while nobody has fought it yet; a boss of several enemies gets a wider bar with a name and a thin bar for each of them. When the boss's event can't be seen, the battle's bar runs across the top of the screen instead, and the notification box and the party box move down below it, unless you moved the bar or them elsewhere (see [Interface](#interface)).
- **Hades rematches** fight the bosses as the game has them, never their raid HP, and the rematch hall shows no boss bars.
- **The World overview's World page** lists the world's raid bosses by part of the story, each with its tier, a thin gauge of the HP left, its share or *Defeated*, and who last hurt it, see [World overview](#world-overview).

## Duels

- **Challenge** the players next to you with *Challenge to a duel* on the right of the action wheel, or one player anywhere through the World overview. "Challenges you to a duel (B)" shows above your head on their screen for 15 seconds, and "Challenging to a duel (15 s) . . ." above your own head counts them down.
- **Accept** in the wheel next to them, or in the World overview; accepting takes back a challenge of your own. "Waiting for \<name>'s duel (6 s) . . ." shows above your head until their game starts it. The duel is the same battle as a [PvP battle](#pvp-battles): your team against theirs, each commanding their own, and both games are put back as they were afterwards. The challenger's *PvP Backline* option decides whether the Backline takes part; a challenge "with Backline" says so.
- **Team duels:** when a party's leader duels, their whole party fights, and so does the other player's party when they lead one. Everyone gets ready on the map; the duel starts once all are ready, or after 10 seconds with those who are. The challenger reads "Getting the sides ready (10 s) . . ." above their head, everyone called "Ready for the duel (16 s) . . ." once they are. Each player brings their share of the Frontline and commands their own characters; a player alone brings their whole Frontline. The Backline stays out of a team duel. Whoever leaves the duel leaves their characters to the next player of their side.

## Trading

Trade items and gold with another player on your map. Nothing changes hands until you both confirm the same offers.

- **Offer** a trade to the players next to you with *Trade* at the bottom right of the action wheel, or to one player on your map through the World overview. "Wants to trade (B)" shows above your head on their screen for 15 seconds, or 60 when you picked them in the overview; "Offering a trade (15 s) . . ." above your own head counts them down.
- **Accept** in the wheel next to them, in the World overview, or with **Y** in the notification box; accepting takes back an offer of your own. "Waiting for \<name>'s trade (6 s) . . ." shows above your head until their game opens it. The trade screen opens for both of you.
- **Put your offer together:** pick *Items*, *Weapons*, *Armor* or *Stones* for your bag. **Right** and **Left** offer one more or one fewer, **R** and **L** ten, and confirm offers all or none. *Gold* sets the gold digit by digit: **Left** and **Right** pick a digit, **Up** and **Down** change it. The other player's offer shows on the right as they change it. *Offers* moves into the offers to look through a long one: **Up** and **Down** scroll, **Left** and **Right** switch between yours and theirs, cancel goes back.
- **What can be traded:** everything in your bag but key items, also enchanted and socketed equipment, which arrives with all its enchantments and stones. Equipped items and items in the storehouse aren't offered; unequip or take them out first.
- **Confirm** once both offers are right. Any change to either offer takes both confirmations back. Once you both confirmed, the relay completes the trade, both games save, and the screen closes: "Trade with \<player> complete, game saved". The save goes into the slot you last saved or loaded in the world, or the first free one.
- **Cancel**, **Esc** or numpad **0** asks first ("Cancel the trade with \<player>? Both offers are lost."): *Cancel trade* ends the trade for both of you, *Keep trading* goes back to it. It also ends when the other player leaves the world for longer than 15 seconds.
- **A cut-off trade:** if your game or connection drops right as the trade completes, the relay keeps it, and your game finishes it the next time you enter the world.

## PvP battles

Press **F11** on the map, outside a world, to open the PvP battle screen.

- **Host:** your game waits for a friend and puts a join code on your clipboard. Send it to your friend, or invite them through the **+** in a Discord chat when the Discord mod is installed.
- **Join:** copy your friend's join code and pick *Join with the copied code*, or accept their Discord invite: your game starts if it's closed, loads your newest save (the one *Continue* picks first) and joins by itself. While you host, invites you accept are ignored; stop hosting first.
- **Fight your own team:** a mirror match against a copy of your own team, played by the computer, no network needed. `Logs\Mirror Match.log` then lists each of your characters next to its copy and marks every value that differs.

Once the games have exchanged their teams, both battles start together. The host's game runs the battle, and the other game shows what happened. You meet your friend's characters as they are: jobs, races, equipment, gems and abilities, pre-battle spells and passives included. A defeated character of your friend stays as a grey silhouette, since their team can still revive it.

- **Backline:** both of you swap your Backline in with the battle's *Party* command, chosen with the round's commands. The character swapped in gives no commands that round, and an attack hits whoever stands in the place it was aimed at once it lands. A fallen character can be swapped out, and a team loses once its whole Frontline is down.
- **Frontline only:** the host decides. *Mod Config → Monster Girl Quest! Online → PvP Backline* set to *Frontline Only* takes the *Party* command out of the battles you host and the duels you challenge to, for both players.
- **Escape** gives the battle up at once. If your friend leaves or the connection breaks, you win. After waiting 10 seconds for your friend, *Cancel* lets you leave the battle, which also gives it up.
- **Nothing carries over:** no EXP, gold or items, and your save, the Library and affection are put back exactly as they were.

### PvP balance

So that no team falls to the first hit, PvP battles and duels change a few rules:

| Rule | In PvP |
|---|---|
| Skills | Deal what they deal in a monster's hands. |
| Max HP | 4 times as much. |
| One action | Takes at most 60% of a character's HP, however strong it is. |
| No damage at all (as under Quantization) | Still takes a quarter of a hit. |
| Evasion and reflection | 75% at most. |
| A nullified or absorbed element | Still deals a quarter of the damage. |
| Defense wall | Takes a quarter of max HP off a hit instead of all of it. |

## Rules of every multiplayer battle

- Ero offers and Give Up are off.
- Battle messages move on by themselves, so nobody waits for another player.
- The battle's *Party* command swaps your Backline in during co-op battles, PvP battles and duels. It is off only in team duels, and in PvP battles and duels whose host chose *Frontline Only*.

## Connection and privacy

Your games meet at the mod's **relay**, a small server that passes their data on. Every game only connects out to it, which works on any internet connection: nobody has to open a port, change a router setting or install anything.

- **Private:** everything your games send each other is encrypted with a key only the players have. The relay never gets it and passes on data it can't read.
- **The Global chat is the exception:** every line of a world's Global chat also goes to the relay as plain text, which keeps the last 200 lines of each world for its creator and the relay's admins to read. The Map, Party and Whisper chats stay between the players.
- **What the relay keeps:** the list of worlds, with each world's name, description, mods and shared mod settings, what tells its creator's game data from another's, its players' names and who is online; a Raid World's story progress and its raid bosses' HP; and a trade's encrypted offers until both games completed it. Hidden worlds are listed only for their players and for whoever names their id. A world's password never reaches the relay, and a starting save arrives encrypted.
- **No addresses:** a join code holds a random token and the relay's name, so your friend's game never learns your IP address.

## Troubleshooting

| Message or problem | What to do |
|---|---|
| *Multiplayer* says a new version is out | Press Enter for *update and install*: the game closes, updates the mod and starts again in the Multiplayer menu. Or close the game and run `Patch\Multiplayer\Update.bat`. A Discord invite, or the return to a world after a mod download, shows the same offer while the mod is outdated; after updating, enter the world again yourself. Under Wine or Proton the updater can't run: close the game and update by hand. |
| "Your friend's game is not hosting with this join code right now" | Your friend stopped hosting, or hosted again, which makes a new join code: ask for the new one. Or their game is reconnecting to the relay: try again in a minute. |
| "Nobody joined in time, so hosting stopped" | Hosting waits 30 minutes for a friend. Host again for a new join code. |
| "Your team is too large to send" | Your party has more characters, skills or equipment than one PvP exchange carries. Leave a few characters out of the party and try again. |
| "The relay could not be reached" | Your internet connection is down, or something such as a firewall blocks the game from going online. The newest `Logs\Multiplayer <date and time>.log` in the game folder says what the relay answered. |
| "This join code comes from another version of the mod" | One of you has an older version; both need the same one. |
| "Your friend's game uses a relay this version does not know" | Your friend has a newer version of the mod; update yours. |
| "\<world> is not in the list right now" | The world list hasn't loaded yet or couldn't be fetched; the top of the world screen says which. Try again once it has loaded. |
| "\<world> only takes matching game data" | Its creator left *Allow data mismatch* unticked, and your mods differ from theirs. The world's details name what differs and the mods it needs. |
| "\<world> needs ...: no such script in your Patch folder" | The world requires a mod you don't have. Install it, then enter again. |
| "The mod catalog has not loaded yet" | The world turns other mods off, and only the catalog tells which of your mods are personal. Wait until the world list has loaded and enter again. |
| "Your Patch folder could not be read" | The world turns other mods off, and the game couldn't list the scripts in your `Patch` folder. The log says why; try again, or restart the game. |
| "Another game of this folder has mods turned off" | Another game started from the same game folder turned mods off for its world. They come back when that game closes. |
| "Your mods were turned off or on since the game started" | Mods were moved while the game ran, so it no longer runs the mods its `Patch` folder holds. Close the game, start it again, then enter. |
| "Some of your mods could not be turned back on" | They could not be moved back, such as while another program had them open. They wait in the `Parked mods` folder of your game folder, and the next start of the game tries again. If they stay there, close the game and move them back into `Patch` by hand, keeping their folders. |
| "... lie on another drive behind a link in Patch and cannot be turned off" | The world turns other mods off, and a mod it turns off sits behind a link (a junction) to another drive. Put the mod's files into `Patch` itself, or take the link out, and enter again. |
| "The mods were installed, but your other mods could not be turned off or kept off" | The world's mods are in place, but the game could not move your other mods for the restart, such as while another program had them open. Enter the world again. |
| "Saving is off until your other mods are back" | Your other mods are still turned off outside a world. Close the game and start it again: they come back, and saving works again. |
| "This is a world code" | You pasted a world's code into a PvP join. Enter worlds through *Multiplayer* on the title screen. |

**Logs:** both are in the `Logs` folder of your game folder, a pair per time you played, named after when the game started, such as `Multiplayer InGame 2026-10-07 18-30-05.log` and `Multiplayer 2026-10-07 18-30-05.log`. The `Multiplayer InGame` log tells what the mod did inside the game; the `Multiplayer` log tells what the connection did. The folder keeps the logs of your last five game starts and deletes older ones (a start of the World Admin tool's options dump does not count), so send them soon after something went wrong. Please attach both of the session that went wrong to a [bug report](https://github.com/Pauliinchen/MGQ-Online/issues/new?template=bug_report.yml).
