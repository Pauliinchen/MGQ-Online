Monster Girl Quest! Paradox RPG - Multiplayer
=============================================

Play Monster Girl Quest! Paradox RPG together with a friend over a direct
connection. So far: PvP battles, in which your Frontline fights your
friend's Frontline live, each of you commanding your own team.


REQUIREMENT
-----------
Monster Girl Quest! Paradox RPG 3.06 with the English translation. Both
games need the same version of the game and of this mod.

This is a Patch folder mod ("Type 1"), so the community's mod loader must
be installed: download "Patch.rb (enable Type 1 mods)" from the MGQ wiki
and put it into your Patch folder. If you already use other Patch folder
mods, you have it.

   https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)

Optional, but recommended:
- Discord Rich Presence 1.5.0 or later
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
  code", or accepts the invite in Discord (their game starts if it is
  closed, then asks once a save is loaded).
- Once the teams are swapped, both battles start together.
- Fight your own team: a mirror match against your own Frontline, no
  friend or network needed. Multiplayer\Mirror Match.log then lists each
  of your characters next to its copy, before the battle and at its
  first turn, and marks every value that differs.

Hosting needs your PC to be reachable on port 47625 (TCP): forward it in
your router, or use IPv6, or a virtual network like Tailscale, ZeroTier or
Radmin VPN. Windows asks whether Game.exe may use the network the first
time you host; allow it. Your friend's game sees your IP address. To find
it, your game asks api.ipify.org once per hosting.


UNINSTALL
---------
Close the game and delete Patch\Multiplayer.rb, Patch\mp_sync.rb,
Patch\pvp_battle.rb and the Multiplayer folder.
The mod loader stays for your other mods.


TROUBLESHOOTING
---------------
- "Your friend's game could not be reached": the host's port 47625 is not
  reachable. Forward it in the router. Many cable and fibre connections
  share one public IPv4 address with other customers (DS-Lite, CGNAT), so
  forwarding is impossible there; use IPv6 or a virtual network instead.
- "Your friend's game offers only IPv6, which your connection lacks": the
  host can only be reached over IPv6, and the joining PC has none. Join the
  same virtual network (Tailscale, ZeroTier, Radmin VPN), or let the one
  with IPv6 join the other.
- Multiplayer\InGame.log only appears if something went wrong inside the
  game, Multiplayer\Multiplayer.log tells what the connection did. Include
  both when reporting a problem.


CREDITS
-------
The mod loader is the community's Patch.rb from the MGQ wiki (link above).
It is not included in this download.
