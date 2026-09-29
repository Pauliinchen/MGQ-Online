Monster Girl Quest! Paradox RPG - Multiplayer
=============================================

Play Monster Girl Quest! Paradox RPG together with a friend over the
internet, with nothing to set up in your router. So far: PvP battles, in
which your Frontline fights your friend's Frontline live, each of you
commanding your own team.


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
   Multiplayer\Multiplayer.dll
   Patch\Multiplayer.rb
   Patch\mp_sync.rb
   Patch\mp_world.rb
   Patch\pvp_battle.rb
   ...

While this mod is installed, the game keeps running when its window is in
the background, so neither player holds the other up. A gamepad does
nothing meanwhile.


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
  friend or network needed. Multiplayer\Mirror Match.log then lists each
  of your characters next to its copy, before the battle and at its
  first turn, and marks every value that differs.


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
Close the game and delete Patch\Multiplayer.rb, Patch\mp_sync.rb,
Patch\mp_world.rb, Patch\pvp_battle.rb and the Multiplayer folder. The
Multiplayer folder also holds your worlds, so keep Multiplayer\Worlds if
you want to play them again later.
The mod loader stays for your other mods.


TROUBLESHOOTING
---------------
- "Your friend's game is not hosting with this join code any more": your
  friend stopped hosting, or hosted again, which makes a new join code.
  Ask for the new one.
- "The relay could not be reached": your internet connection is down, or
  something blocks the game from going online, such as a firewall.
  Multiplayer\Multiplayer.log says what the relay answered.
- "This join code comes from another version of the mod": one of you has
  an older version; both need the same one.
- "Your friend's game uses a relay this version does not know": your
  friend has a newer version of the mod; update yours.
- An accepted Discord invite loads your newest save, the one Continue
  picks first, never the autosave.
- Multiplayer\InGame.log only appears if something went wrong inside the
  game, Multiplayer\Multiplayer.log tells what the connection did. Include
  both when reporting a problem.


CREDITS
-------
The mod loader is the community's Patch.rb from the MGQ wiki (link above).
It is not included in this download.
