Monster Girl Quest! Online
==========================
An unofficial multiplayer mod for Monster Girl Quest! Paradox RPG.

Play Monster Girl Quest! Paradox RPG together with friends over the
internet, with nothing to set up in your router. So far: PvP battles, in
which your Frontline fights your friend's Frontline live, each of you
commanding your own team; and worlds, which up to 32 players enter and
see each other walk the same maps.


REQUIREMENT
-----------
Monster Girl Quest! Paradox RPG 3.06, with or without the English
translation. Both games need the same version of the game and of this
mod. A translated and an untranslated game can play together; each
shows the battle in its own language.

This is a Patch folder mod ("Type 1"), so the community's mod loader must
be installed: download "Patch.rb (enable Type 1 mods)" from the MGQ wiki
and put it into your Patch folder. If you already use other Patch folder
mods, you have it.

   https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)

Optional, but recommended:
- Discord Rich Presence 1.5.1 or later
  (github.com/Pauliinchen/MGQ-Paradox-Discord-Rich-Presence): invite your
  friend through Discord instead of sending a join code, and show on your
  profile who you're playing with.
- Battle Dialogue (github.com/Pauliinchen/MGQ-Paradox-Mod-Collection):
  shows what characters say in boxes at the screen's sides, so neither of
  you waits for the other to press a key.


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
   Patch\Multiplayer\Scripts\mp_*.rbx   (the mod's other scripts)
   ...

Patch\Multiplayer.rb loads the scripts in Patch\Multiplayer\Scripts
itself. Your player name, favourites, worlds and the logs go into
Patch\Multiplayer.

While this mod is installed, the game keeps running when its window is in
the background, so neither player holds the other up. A gamepad does
nothing meanwhile.


UPDATE
------
The title screen greys out Multiplayer, and PvP battles (F11) stop
working, once a new release is out; both games need the same version, so
an old one is kept from joining a newer one. Close the game and
double-click Patch\Multiplayer\Update.bat: it shows what changed,
downloads the latest release and installs it, removing any file an
earlier version left behind that this one no longer ships. Your player
name, favourites and worlds are kept.

To update by hand, close the game and extract the new download over the
old one; then delete any Patch\Multiplayer\Scripts\mp_*.rbx file the
new release's Manifest.txt no longer lists.


PVP BATTLES (TEST)
------------------
Fight a friend's Frontline live: your games swap their Frontline, then
you both fight the same battle, each commanding your own team. The
hosting game works the battle out and the other shows what happened. The
team you meet is your friend's characters as they are, with their jobs,
races, equipment, gems and abilities, pre-battle spells and passives
included. Only the Frontline fights: the Party command, which swaps in
the backline, is gone during a PvP battle. Escape gives the battle up
at once, and Give Up is off. Battle messages move on by themselves, so
neither of you waits for the other to press a key. If your friend leaves
or the connection breaks, you win. When you have waited for your friend
for 10 seconds, Cancel lets you leave the battle, which also gives it
up. A defeated character of your friend stays as a see-through grey
silhouette, since their team can still revive it; it cannot be targeted
meanwhile. Nothing carries over: no EXP, gold or items, no defeat scene,
and your save, the Library and affection are put back exactly as they
were before.

Press F11 on the map to open the PvP battle screen.

- Host a PvP battle: your game waits for a friend. Send them the join
  code, which is put on your clipboard, or, with the Discord mod,
  invite them through the + in a Discord chat ("Invite to play").
- Your friend copies your join code and picks "Join with the copied
  code", or accepts the invite in Discord: their game starts if it is
  closed, loads their last save and joins by itself. While a game hosts,
  invites accepted there are ignored; stop hosting first.
- Once the teams are swapped, both battles start together.
- Fight your own team: a mirror match against your own Frontline, no
  friend or network needed. Patch\Multiplayer\Mirror Match.log then
  lists each of your characters next to its copy, before the battle and
  at its first turn, and marks every value that differs.


WORLDS (TEST)
-------------
Pick "Multiplayer" below "Continue" on the title screen. The first time,
the game asks for the name the others see, unless the Discord mod knows
yours. Names and passwords are typed on the keyboard; with a gamepad, the
game's letters appear.

- The list at the left holds every public world and the hidden worlds
  you joined, your favourites first (marked *), then those you played
  last. The right side shows who made the chosen world, how many of its
  players are online, and everyone who ever joined it.
- Create new world: point at it and fill in the form at the right: a
  name, a password, and Max Players, 2 to 32. Tick "Hidden" to leave the
  world out of the list. Tick "From my save" to have every new player
  start from one of your own saves, with your party, items, story and
  Library, instead of the opening; then choose the save. Tick "Players
  choose their start" to let each new player choose when they first
  enter: at the beginning, from one of their own saves (copied into the
  world, the original stays as it is), or from yours if you ticked "From
  my save". Max Players, the starting save and Players choose cannot be
  changed later. A save that needs a mod a player lacks tells them which.
- Join a hidden world: type or paste (Ctrl+V) the world id its creator
  sent you, and its password. The creator copies the id with "Copy the
  world id" on the world.
- Enter a world: the first time, type its password; your game remembers
  it after that. A world you have saves in loads your latest one.
- Its creator can remove a player or delete the world for everyone.

Each world keeps its own saves, Library, medals and affection in
Patch\Multiplayer\Worlds, apart from your own game. On the map, the other
players on the same map walk around with their names above them, and an
icon for what they do: fighting, talking, typing in the chat, in a
menu, the inventory or
their equipment, shopping, at the casino, in the Library, sailing,
flying, or away from the game. Their ping shows after their name, and
yours right above your head: green up to 100 ms, yellow up to 200 ms,
red beyond. They walk through everything and trigger nothing. PvP
battles (F11) are off in a world: duel the other players instead, and
F11 opens the World overview.

The world never pauses: while you are in a menu, a shop, a battle or a
story scene, the map goes on behind it. The others walk on, NPCs move,
and background events and timers run. Menus show the live map behind
them. Anything that needs you, such as a message, a battle, a move to
another map, or an NPC that walks into you, waits until you are back on
the map.

The action wheel: press B on the map to open it around your character.
Pick a choice with the arrow keys and take it with the confirm button; B
or cancel closes it. Grey choices cannot be taken right now and tell you
why. The wheel opens on its middle, the globe over your character, which
opens the World overview; an arrow picks a side and the opposite arrow
goes back.

World overview: F11 or the middle of the wheel opens it, and F11, B,
cancel or a click outside it closes it. It lists every player online,
grouped by where they are: their name, their highest companion's level,
where they are in the story and their ping, with a crown for a party's
leader and the party's size as "2 / 4"; your party's members are green,
you included. A player whose invite or challenge reaches you shows it in
their row. Pick a player with the arrow keys and confirm, or click
them, to invite them to your party, accept their invite, or challenge
them to a duel or accept theirs, wherever they are.

Duels: "Challenge to a duel" on the right of the wheel challenges the
players next to you for 15 seconds; they accept in their wheel or in the
World overview. A duel is the same PvP battle as F11 outside a world:
your Frontline against theirs, and both games are put back afterwards.
When a party's leader duels, it is a team duel: their whole party
fights, and the other side's party when its player leads one. Everyone
gets ready on the map, and it starts once all are ready, or after 10
seconds with those who are. Each brings their share of the Frontline,
as in co-op battles; whoever leaves leaves their characters to the next
player of their side.

Chat: press T, or pick "Chat" in the wheel, and type on the keyboard;
Enter sends, Esc closes. The arrow keys, Home and End move the cursor,
and Delete removes the character after it. Your line goes to everyone in
the world: in a speech bubble above your head for the players on your
map, and in the chat log at the bottom left of the map for everyone.
The chat works in battles too, where its log sits above the battle's
windows, and tells at once when a player leaves the battle.

Parties: players outside your party are slightly see-through. Stand next
to another player and pick "Invite to a party" in the wheel; when they
pick "Accept" in theirs next to you within 15 seconds, you form a party.
A party holds up to four players. Party members are fully visible and
their names are green; a party's size shows after its players' names and
above your head ("2 / 4"), its leader has a crown, and Discord shows it
as "(2 of 4)". A box at the top right of the map lists your party, its
leader first and then by name, with each player's highest companion
level, ping, and where they are below (long names shortened). "Leave
the party" at the bottom of the wheel
leaves it. Only the party's leader, the player who made it, invites
more and removes members (in the World overview). A party shares one
team's worth of companions: the
Frontline's four places and the Backline's are split between you, the
player who made the party taking any place left over. Your Formation
screens show your share of the Frontline as the Frontline, your share
of the Backline as the game shows the Backline, and the companions past
your share in black and white below a line. Only your share of the
Frontline follows you on the map, also on the other members' screens;
the player who made the party can show the players alone
instead (Mod Config, Monster Girl Quest! Online, Party Followers). On a
map you share with
party members, you all see the same NPCs in the same places: whoever of
you entered the map first is its Map Owner, and the NPCs move as they do
in their game. While in a party, everyone plays the story of the player
who made the party. Your own party, your companions and their affection
stay yours, and your saves keep your own story. When you leave the
party, you are back in your own story. If your story was exactly as far
along as theirs when you joined, you keep what you played together,
companions who joined in the story included.

Co-op battles: when a battle starts for a party member, the party
members on the same map who are playing on it join it. Each brings
their squad: their share of the Frontline fights and their share of the
Backline waits, the rest stays out. Everyone commands their own
characters and can swap their own Backline in with "Party". Everyone
fights the enemies of the game where the battle started, even when a mod
there changes them, such as one that doubles them. Each of you can try
to escape; whoever gets away leaves the battle, and the one
left alone fights on with their own full team. Each of you gets the full
EXP, gold and your own item drops, or your own defeat. Chests are everyone's own: when
a party member opens one, everyone in the party who has not looted it
yet gets the same items. Everyone goes where they like; only a story
scene brings the party together. A story scene the player who made the
party starts waits until every member stands next to them, 30 seconds
at most: members get 5 seconds to finish what they do, then are
brought over, wherever they are (after a battle or a menu once it is
over), and stand still while the scene plays. After 30 seconds it starts
without those who have not come, and they play on where they are. The story itself plays in their game: when you start a story event, it is
handed to them, and everyone on the map sees its dialogue in their own
message window, which moves on when that player moves on; only they can
continue or close it. Conversations, shops and the job change menu stay
your own, and so do the companions, merchants, inn and maids of the
Pocket Castle.


CONNECTION
----------
Your games meet at the mod's relay, a small server that passes their data
on. Both only connect out to it, which works on any internet connection,
so neither of you has to open a port, change a router setting or install
anything.

- Private: everything your games send each other is encrypted with a key
  from the join code. The relay never gets that key: it passes on data it
  cannot read and keeps nothing.
- No addresses: the join code holds a random token and the relay's name,
  so your friend's game never learns your IP address.


UNINSTALL
---------
Close the game and delete Patch\Multiplayer.rb and the Patch\Multiplayer
folder. That folder also holds your worlds, so keep
Patch\Multiplayer\Worlds if you want to play them again later. The mod
loader stays for your other mods.


TROUBLESHOOTING
---------------
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
- An accepted Discord invite loads your newest save, the one Continue
  picks first, never the autosave.
- Patch\Multiplayer\InGame.log only appears if something went wrong
  inside the game, Patch\Multiplayer\Multiplayer.log tells what the
  connection did. Include both when reporting a problem.


CREDITS
-------
The mod loader is the community's Patch.rb from the MGQ wiki (link above).
It is not included in this download.

Monster Girl Quest! Online is an unofficial fan project. It is not
affiliated with or endorsed by Torotoro Resistance, the creators of
Monster Girl Quest!, or the English translation team.

   https://github.com/Pauliinchen/MGQ-Online
