Monster Girl Quest! Online
==========================
An unofficial multiplayer mod for Monster Girl Quest! Paradox RPG.

Play Monster Girl Quest! Paradox RPG together with friends over the
internet, with nothing to set up in your router.

- Worlds: up to 32 players on the same maps. Form a party to play the
  story together and fight co-op battles.
- PvP battles: your team against a friend's, live, each of you
  commanding your own.

Worlds, parties and co-op battles are a prototype: expect bugs, and
please report them:

   https://github.com/Pauliinchen/MGQ-Online/issues


REQUIREMENTS
------------
Monster Girl Quest! Paradox RPG 3.06, with or without the English
translation. Everyone needs the same game version and the same version
of this mod. A translated and an untranslated game can play together;
each shows battles in its own language.

This is a Patch folder mod ("Type 1"), so the community's mod loader
must be installed: download "Patch.rb (enable Type 1 mods)" from the MGQ
wiki and put it into your Patch folder. If you already use other Patch
folder mods, you have it.

   https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)

Optional:

- Discord Rich Presence 1.5.1 or later
  (github.com/Pauliinchen/MGQ-Paradox-Discord-Rich-Presence): invite
  friends through Discord instead of sending a join code, show on your
  profile who you're playing with, and use your Discord name in worlds.
- Battle Dialogue (github.com/Pauliinchen/MGQ-Paradox-Mod-Collection):
  shows what characters say in boxes at the screen's sides, so nobody
  waits for another player to press a key.
- Mod Config Remake (github.com/Pauliinchen/MGQ-Paradox-Mod-Collection):
  bind other keys to the action wheel, the chat, the World overview and
  the notification box.


INSTALL
-------
Close the game and extract the download into your Monster Girl Quest!
Paradox RPG folder (the one that contains Game.exe). It should then look
like this:

   Game.exe
   Patch\Multiplayer.rb
   Patch\Multiplayer\Multiplayer.dll
   Patch\Multiplayer\Manifest.txt
   Patch\Multiplayer\README.txt
   Patch\Multiplayer\Update.bat
   Patch\Multiplayer\Update.ps1
   Patch\Multiplayer\Scripts\*.rbx      (the mod's other scripts)
   ...

Patch\Multiplayer.rb loads the scripts in Patch\Multiplayer\Scripts
itself. Your player name, keys, favourites, worlds and the logs go into
Patch\Multiplayer.

While the mod is installed, the game keeps running when its window is in
the background, so no player holds the others up. A gamepad does nothing
meanwhile.


UPDATE
------
When a new release is out, the title screen says so. Until you update,
"Multiplayer" is greyed out and F11 doesn't open PvP battles, since
everyone needs the same version.

Close the game and double-click Patch\Multiplayer\Update.bat. It shows
what's new, downloads the release, installs it, and removes files an
older version left behind. Your player name, keys, favourites and worlds
are kept.

To update by hand, close the game and extract the new download over the
old one; then delete any Patch\Multiplayer\Scripts\*.rbx file the new
release's Manifest.txt no longer lists.


UNINSTALL
---------
Close the game and delete Multiplayer.rb and the Multiplayer folder in
Patch. That folder also holds your worlds: keep Patch\Multiplayer\Worlds
if you want to play them again later. The mod loader stays for your
other mods.


KEYS
----
B opens the action wheel, T the chat, E the emote wheel and F11 the
World overview, or the PvP battle screen outside a world. Y accepts and
N declines the first invite at the top left, and Tab makes the party box
small or full. This README names these default keys.

With Mod Config Remake installed, you can bind others: "Mod Config >
Monster Girl Quest! Online", confirm "Action Wheel", "Chat", "World
Overview", "Accept Notification", "Decline Notification", "Emote Wheel"
or "Party Box Size", then press the new key (Esc keeps the old one).
Keys the game uses itself, such as the arrows, Enter, Esc, Z, X, Shift,
A, S, D, Q and W, can't be bound, and neither can a key another option
already has. Your keys are kept in Patch\Multiplayer\Player.ini, so they
hold in every save and every world. The texts in the game name the keys
you bound.


WORLDS
------
Pick Multiplayer below "Continue" on the title screen. The first time,
the game asks for the name the others see, unless the Discord mod knows
yours. Names and passwords are typed on the keyboard; with a gamepad,
the game's letters appear.

Each world keeps its own saves, Library, medals and affection in
Patch\Multiplayer\Worlds, so your own game stays untouched. Going back
to the title screen leaves the world.

Finding, creating and joining
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The world screen has two boxes at the left: the worlds, and below them
the commands ("Create new world", "Add a hidden world", "Change your
name", "Back"). It opens with the cursor around one of the two boxes. Up
and down pick a box, confirm moves into it, and cancel moves back out,
so the commands are reached without scrolling through a long list.
Cancel with a box picked leaves the screen.

The worlds box lists every public world, the hidden worlds you joined
and the hidden worlds you added by their id: your favourites first
(marked *), then the featured worlds in gold, which the relay's admins
run, then the ones you played last. With the cursor on a world, the
right side shows its details: who made it, its password and players, how
new players start, the mods it needs, whether your game data matches the
creator's, and what its creator wrote about it.

- Enter a world: confirm on it and pick "Enter the world". Type its
  password the first time, unless it has none; your game remembers it
  after that. You continue from your latest save in that world; the
  first time, you start at the opening or from the creator's save, or
  choose where to start if the creator let you. A world is only entered
  once the list has loaded, since the list tells what the world asks of
  your game.
- Create new world: fill in the form at the right: a name, a password
  (left empty, anyone may enter), and Max Players (2 to 32). Creating a
  world does not enter it: it appears in the list, marked as a
  favourite, and you enter it from there.
  - "Hidden" leaves the world out of the list. Only its players see it
    there, and whoever adds it by its id.
  - "Shared save" lets every new player start from one of your saves,
    with your party, items, story and Library, instead of the opening.
    Choose the save after ticking it.
  - "Player's choice" lets each new player choose when they first enter:
    at the beginning, from one of their own saves, or from yours if you
    ticked "Shared save". Their own save is copied into the world; the
    original stays untouched.
  - "Mods" names the mods a game needs to play there, separated by
    semicolons, 80 characters at most. See "Mods of a world" below.
  - "Allow data mismatch" is ticked at first: a game whose data differs
    from yours is warned before it enters and may enter anyway.
    Unticked, such a game can't enter. See "Game data" below.
  - The "Description" says what the world is about, in up to 1000
    characters.
- Edit the world: the creator changes Max Players, Mods and the
  Description later; everything else is fixed once the world exists.
- Add a hidden world: type or paste (Ctrl+V) the world id its creator
  sent you. The world then shows in your list with its details, and you
  enter it like any other, with its password if it has one. "Remove from
  my list" takes it off again as long as you never entered it. Your game
  keeps the 50 worlds you added last. The creator copies the id with
  "Copy the world id" on the world.
- A world's details: with the cursor on a world, the right arrow moves
  into its details; up and down pick the mods, "Your game", the players
  or the description, and confirm opens a box that lists each mod, every
  player who ever joined (those online first), or the whole description.
  A click on them does the same. The left arrow or cancel goes back to
  the list.
- Favourites: "Mark as a favourite" on a world puts it at the top of
  your list.
- Take a world's save home: "Copy my latest save to my game" on a world
  you've played, or "Copy to my game" in the menu while you're in it,
  copies that world's latest save into the first free slot of your own
  saves. Your own Library, medals and affection stay as they are.
- Delete my saves of it removes your saves of a world from this PC.
  You'd start anew there, and need its password again.
- The creator can also remove a player, who can then no longer enter, or
  delete the world for everyone. The relay's admins can edit and delete
  any world.

Mods of a world
~~~~~~~~~~~~~~~

A world's "Mods" are names its creator typed; how a name is written
decides what it does:

- Name only tells the players. It keeps nobody out.
- !Name is required: a game needs a script Name.rb in its Patch folder
  to enter (case, spaces, underscores and hyphens don't matter). It
  shows first, in green when you have it and in red when you don't.
- ?Name is essential, for mods that are data files without a script. It
  keeps nobody out by itself, and shows in green while your game data
  matches the world's and in gold otherwise.

The details show each mod in a box of its own, as many as fit the row,
and count the rest in a last box.

Game data
~~~~~~~~~

- What is compared: which actors, classes, skills, items, weapons,
  armors, enemies, states, troops, common events and maps exist. A mod
  that adds or removes any is noticed, while a translated game still
  matches the untranslated one. A mod that only changes numbers isn't
  noticed.
- A game that differs: the world's details say whether your game matches
  its creator's and, if not, in what. Entering then asks first, or is
  refused when the creator unticked "Allow data mismatch". Worlds made
  before this check say nothing and take every game.
- Updating your world's data: when a mod you play with gets an update,
  your game no longer matches your own world. Move onto "Your game" in
  the world's details and confirm: the world then takes your game's data
  as it is now, and everyone else has to match it again. "Edit the
  world" does the same with its button "Update current data scan". Only
  the world's creator can do this.

On the map
~~~~~~~~~~

- Other players on your map walk around with their name above them and
  an icon for what they're doing: fighting, talking or watching an
  event, typing in the chat, in a menu, the inventory or their
  equipment, shopping, at the casino, in the Library, sailing, flying,
  or away. They walk through everything and trigger nothing.
- Ping shows after each player's name, and yours right above your head:
  green up to 100 ms, yellow up to 200 ms, red beyond.
- The bottom left of the screen tells who joined and left, and when the
  connection is being restored. A player whose connection drops stays in
  the world and in their party for 15 seconds, so a short break changes
  nothing.
- The world never pauses. While you're in a menu, a shop, a battle or a
  story scene, the map goes on behind it: the others walk on, NPCs move,
  and background events and timers run. Menus show the live map instead
  of a still picture. Anything that needs you, such as a message, a
  battle, a move to another map, or an NPC walking into you, waits until
  you're back on the map.
- The PvP battle screen is off while you're in a world: challenge other
  players to a duel instead, and F11 opens the World overview.

Action wheel and chat
~~~~~~~~~~~~~~~~~~~~~

- Action wheel: press B on the map. Pick a choice with the arrow keys
  and take it with the confirm button; B or cancel closes the wheel.
  Grey choices can't be taken right now and tell you why. The wheel
  opens on its middle, the globe over your character, which opens the
  World overview; an arrow picks a side, the opposite arrow goes back.
- Chat: press T, or pick "Chat" in the wheel. Enter sends, Esc closes;
  the arrow keys, Home and End move the cursor, and Delete removes the
  character after it. Your line shows in a speech bubble above your head
  for the players on your map, and in the chat log at the bottom left
  for everyone in the world. The chat works in battles too, where its
  log sits above the battle's windows, and while your party gathers for
  a story scene. Start a line with /p to send it to your party only; it
  shows as "[Party]" in the log. Names in the log are yellow for you,
  green for your party's members and white for everyone else.
- Emotes: press E on the map for a ring of emotes around your character:
  a jump, or a balloon such as a heart, a music note or a light bulb
  above your head. The arrow keys go round it and the confirm button
  plays it; the players on your map see it on your character too.

World overview
~~~~~~~~~~~~~~

- Open it with F11 or the middle of the action wheel; F11, B, cancel or
  a click outside it closes it. The world keeps running behind it.
- Every player online, grouped by where they are, yours first: their
  name, the level of their highest companion, where they are in the
  story ("Part 2: Alice side") and their ping. Party leaders have a
  crown, a party's size shows as "2 / 4", and your party's members are
  green, you included. A player whose party invite or duel challenge
  reaches you shows "Invites you to a party" or "Challenges you to a
  duel" in their row.
- Pick a player with the arrow keys and confirm, or click them, for a
  menu: invite them to your party or accept their invite, and challenge
  them to a duel or accept theirs, wherever in the world they are. A
  party invite from afar stands for a minute. As your party's leader you
  also remove members here. On your own row you can leave your party or
  stop inviting.

Notifications
~~~~~~~~~~~~~

- The box at the top left, on the map and in menus, lists the party
  invites and duel challenges that reach you, from wherever in the world
  they come, for as long as they stand. Below them, messages show for a
  moment, such as a party member meeting enemies.
- Y accepts the first invite or challenge (a challenge only on the map),
  N declines it: the other player reads that you declined, and it stays
  away until they invite you anew.

Parties
~~~~~~~

- Forming one: stand next to another player, open the wheel and pick
  "Invite to a party". "Invites to a party (B)" shows above your head on
  their screen for 15 seconds; when they pick "Accept" in their wheel
  next to you, you're a party. A party holds up to four players, and
  only its leader, the player who made it, invites more and removes
  members (in the World overview). "Leave the party" at the bottom of
  the wheel leaves it.
- Who's in it: party members are fully visible with green names;
  everyone else is slightly see-through. A party's size shows after its
  players' names and above your head ("2 / 4"), its leader has a crown,
  and Discord shows it as "(2 of 4)". A box at the top right of the map
  lists your party, its leader first and then by name, with each
  player's highest companion level, ping, and where they are on a line
  below (long names shortened). Tab makes it small, with only names and
  pings, and full again; it stays as you left it.
- Your squad: a party shares one team's worth of companions. The
  Frontline's four places and the Backline's are split between you, the
  player who made the party taking any place left over: with two
  players, each has two in front and half of the Backline; with three,
  the player who made the party has two in front and the others one;
  with four, everyone has one. Your Formation screens show your whole
  team: your share of the Frontline as the Frontline, your share of the
  Backline as the game shows the Backline, and the companions past your
  share in black and white below a line, so you can see who stays home.
- Followers: only your share of the Frontline walks behind you, and
  behind your ghost on the other members' screens; with one place in
  front, you walk alone. The player who made the party can show nobody
  but the players instead: "Mod Config > Monster Girl Quest! Online >
  Party Followers".
- NPCs: on a map you share, you all see the same NPCs in the same
  places. Whoever of you entered the map first is its Map Owner, and the
  NPCs move as they do in that player's game. In the Pocket Castle it's
  always the party's leader: you see their companions, and one you don't
  have yourself stands there see-through, a ghost you can't talk to.
  Your own companions stay yours to talk to.
- Story: everyone plays the story of the player who made the party. Its
  events, doors and conversations are as far along as in that player's
  game, and only that player starts story events: a member reads "Only
  <leader> can move the story on." Everyone on the map sees the dialogue
  in their own message window, which moves on when that player moves on;
  only they can continue or close it. The story's pictures, such as its
  CGs, and its fades, tints and flashes show for everyone on the map
  too. Conversations, shops (the Casino's coin sellers too) and the job
  change menu stay your own, and so do the companions, merchants, inn
  and maids of the Pocket Castle. A trader whose talk would move a side
  quest on stops there for a member; the leader's moves it on for the
  party.
- What stays yours: your party, companions and affection, and your saves
  keep your own story. When you leave the party, you're back in your own
  story. If your story was exactly as far along as theirs when you
  joined, you keep what you played together: the story's progress, its
  items and gold, and the companions who joined or left in it. Otherwise
  the story lends you its key items, such as the one that opens a locked
  door, while you're in the party; they go back when you leave it and
  stay out of your saves. Where the Pocket Castle's way out takes you is
  your own too: when the party brings you into the castle, you leave it
  where you came from.
- Travelling: everyone goes where they like; only story scenes bring the
  party together. A member teleports to the party's leader whenever they
  like: "Teleport to <leader>" takes the place of "Invite to a party" at
  the top of the wheel, and the leader's row in the World overview
  offers it too. It brings you over as soon as you're free on the map.
  When a story scene moves its leader somewhere else, such as onto a
  theater's stage and back, the members with them come along at once.
- Story scenes wait for everyone: when the player who made the party
  starts a story scene, it waits until every member stands next to them,
  and they can't move meanwhile. Members see a 5-second countdown above
  their head to finish what they're doing, then are brought over,
  wherever they are; a member in a battle or a menu comes once it's
  over. No random encounter or co-op battle starts for them during the
  countdown. The scene waits 30 seconds at most, then starts without
  whoever hasn't come; they play on where they are. While the scene
  plays, the members on that map stand still and can't open the menu;
  the chat stays open meanwhile. Story events don't get stuck on a
  member standing in their way.
- Chests are everyone's own: when a member opens one, everyone in the
  party who hasn't looted it yet gets the same items, hears the chest
  open and sees the first item's icon in the notice; in a battle, once
  it's over.

Co-op battles
~~~~~~~~~~~~~

When a battle starts for a party member, whether a random encounter, a
wandering monster or a story boss, the party members playing on the same
map join it.

- A random encounter waits up to 3 seconds for party members on the same
  map who are in a menu, typing or on a vehicle: you stand still, they
  read "<name> is in a battle!" in the notification box for a moment,
  and the battle starts as soon as they're back on the map. Whoever is
  still busy after 3 seconds misses it. Every party member on that map
  stands still until they join the battle, so nobody walks off first.
- Each of you brings your squad: your share of the Frontline fights,
  your share of the Backline waits. The companions past it stay out of
  the battle.
- Everyone commands their own characters and can swap their own Backline
  in with "Party". The party leader's game works it out, with the
  leader's difficulty and mods, whoever met the enemies: "Asking
  <leader> to lead the battle..." shows while a member's game hands it
  over. When the leader isn't playing on that map, is busy or doesn't
  answer within 6 seconds, the game where the battle started works it
  out.
- Everyone fights the enemies of the game that works the battle out,
  even when a mod there changes them, such as one that doubles them.
- Each of you can try to escape. Whoever gets away leaves the battle,
  and the others fight on without their characters. Everyone still in
  the battle reads "<name> left the battle." in the chat log at once;
  the characters leave at the next round. The one left alone fights on
  with their own full team.
- Each of you gets the full EXP, gold and your own item drops, or your
  own defeat. After a lost battle, everyone sees the defeat scene of the
  same enemy, the one the game that worked the battle out chose.

Duels
~~~~~

- Challenge the players next to you with "Challenge to a duel" on the
  right of the action wheel, or one player anywhere through the World
  overview. "Challenges you to a duel (B)" shows above your head on
  their screen for 15 seconds.
- Accept in the wheel next to them, or in the World overview. The duel
  is the same PvP battle as F11 outside a world: your team against
  theirs, each commanding their own, and both games are put back as they
  were afterwards. The challenger's "PvP Backline" option decides
  whether the Backline takes part; a challenge "with Backline" says so.
- Team duels: when a party's leader duels, their whole party fights, and
  so does the other player's party when they lead one. Everyone gets
  ready on the map; the duel starts once all are ready, or after 10
  seconds with those who are. Each player brings their share of the
  Frontline, as in co-op battles, and commands their own characters; a
  player alone brings their whole Frontline. The Backline stays out of a
  team duel. Whoever leaves the duel leaves their characters to the next
  player of their side, who commands them from then on.


PVP BATTLES
-----------
Press F11 on the map, outside a world, to open the PvP battle screen.

- Host: your game waits for a friend and puts a join code on your
  clipboard. Send it to your friend, or invite them through the + in a
  Discord chat when the Discord mod is installed.
- Join: copy your friend's join code and pick "Join with the copied
  code", or accept their Discord invite: your game starts if it's
  closed, loads your newest save (the one "Continue" picks first) and
  joins by itself. While you host, invites you accept are ignored; stop
  hosting first.
- Fight your own team: a mirror match against a copy of your own team,
  played by the computer, no network needed. Patch\Multiplayer\Mirror
  Match.log then lists each of your characters next to its copy and
  marks every value that differs.

Once the games have sent each other their teams, both battles start
together. The host's game works the battle out, and the other game shows
what happened. You meet your friend's characters as they are: jobs,
races, equipment, gems and abilities, pre-battle spells and passives
included. A defeated character of your friend stays as a grey
silhouette, since their team can still revive it.

- Backline: both of you swap your Backline in with the battle's "Party"
  command. You choose a swap with the round's commands: the character
  swapped in gives no commands that round, and an attack hits whoever
  stands in the place it was aimed at once it lands. A fallen character
  can be swapped out, and a team loses once its whole Frontline is down.
- Frontline only: the host decides. "Mod Config > Monster Girl Quest!
  Online > PvP Backline" set to "Frontline Only" takes the "Party"
  command out of the battles you host and the duels you challenge to,
  for both players.
- PvP balance: skills deal what they deal in a monster's hands and every
  character has 4 times its max HP, and one action takes at most 60% of
  a character's HP however strong it is, so no team falls to the first
  hit. A character that takes no damage at all, as under Quantization,
  still takes a quarter of a hit. Evasion and reflection stop at 75%, an
  element a character nullifies or absorbs still deals a quarter of the
  damage, and a defense wall takes a quarter of max HP off a hit instead
  of all of it.
- Escape gives the battle up at once. If your friend leaves or the
  connection breaks, you win.
- After waiting 10 seconds for your friend, Cancel lets you leave the
  battle, which also gives it up.
- Nothing carries over: no EXP, gold or items, and your save, the
  Library and affection are put back exactly as they were.


RULES OF EVERY MULTIPLAYER BATTLE
---------------------------------
- Ero offers and Give Up are off.
- Battle messages move on by themselves, so nobody waits for another
  player.
- Swapping characters: the battle's "Party" command swaps your Backline
  in during co-op battles, PvP battles and duels. It is off only in team
  duels, and in PvP battles and duels whose host chose "Frontline Only".


CONNECTION
----------
Your games meet at the mod's relay, a small server that passes their
data on. Every game only connects out to it, which works on any internet
connection: nobody has to open a port, change a router setting or
install anything.

- Private: everything your games send each other is encrypted with a key
  only the players have. The relay never gets it: it passes on data it
  can't read.
- What the relay keeps: the list of worlds, with each world's name,
  description and mods, what tells its creator's game data from
  another's, its players' names and who is online; hidden worlds are
  listed only for their players and for whoever names their id. A
  world's password never reaches it, and a starting save arrives
  encrypted.
- No addresses: a join code holds a random token and the relay's name,
  so your friend's game never learns your IP address.


TROUBLESHOOTING
---------------
- Multiplayer is greyed out on the title screen: a new release is out.
  Update with Patch\Multiplayer\Update.bat, see UPDATE.
- "Your friend's game is not hosting with this join code any more": your
  friend stopped hosting, or hosted again, which makes a new join code.
  Ask for the new one.
- "The relay could not be reached": your internet connection is down, or
  something blocks the game from going online, such as a firewall.
  Patch\Multiplayer\Multiplayer.log says what the relay answered.
- "This join code comes from another version of the mod": one of you has
  an older version; both need the same one.
- "Your friend's game uses a relay this version does not know": your
  friend has a newer version of the mod; update yours.
- "<world> is not in the list right now": the world list hasn't loaded
  yet or couldn't be fetched; the top of the world screen says which.
  Try again once it has loaded.
- "<world> only takes matching game data": its creator unticked "Allow
  data mismatch", and your mods differ from theirs. The world's details
  name what differs and the mods it needs.
- "<world> needs ...: no such script in your Patch folder": the world
  requires a mod you don't have. Install it, then enter again.
- "This is a world code": you pasted a world's code into a PvP join.
  Enter worlds through "Multiplayer" on the title screen.
- Logs: Patch\Multiplayer\InGame.log only appears when something went
  wrong inside the game; Patch\Multiplayer\Multiplayer.log tells what
  the connection did. Please attach both to a bug report
  (https://github.com/Pauliinchen/MGQ-Online/issues/new?template=bug_report.yml).


CREDITS
-------
The mod loader is the community's Patch.rb from the MGQ wiki (link
above). It is not included in this download.

Monster Girl Quest! Online is an unofficial fan project. It is not
affiliated with or endorsed by Torotoro Resistance, the creators of
Monster Girl Quest!, or the English translation team. It contains no
game or translation files.

   https://github.com/Pauliinchen/MGQ-Online
