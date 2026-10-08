Monster Girl Quest! Online
==========================
An unofficial multiplayer mod for Monster Girl Quest! Paradox RPG.

Play Monster Girl Quest! Paradox RPG together with friends over the
internet, with nothing to set up in your router.

Worlds, parties and co-op battles are a prototype: expect bugs, and
please report them:

   https://github.com/Pauliinchen/MGQ-Online/issues

The player guide explains everything the mod does:

   https://github.com/Pauliinchen/MGQ-Online/blob/main/docs/GUIDE.md


REQUIREMENTS
------------
Monster Girl Quest! Paradox RPG 3.06, with or without the English
translation. Everyone needs the same game version and the same version
of this mod.

This is a Patch folder mod ("Type 1"), so the community's mod loader
must be installed: download "Patch.rb (enable Type 1 mods)" from the MGQ
wiki and put it into your Patch folder. If you already use other Patch
folder mods, you have it.

   https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)

Mod Config Remake comes with the mod (Patch\0_ModConfigRemake.rb): with
it you bind other hotkeys and see which options a world sets.


INSTALL
-------
Close the game and extract the download into your Monster Girl Quest!
Paradox RPG folder (the one that contains Game.exe). It should then look
like this:

   Game.exe
   Patch\0_ModConfigRemake.rb
   Patch\Multiplayer.rb
   Patch\Multiplayer\Multiplayer.dll
   Patch\Multiplayer\Manifest.txt
   Patch\Multiplayer\README.txt
   Patch\Multiplayer\Update.bat
   Patch\Multiplayer\Update.ps1
   Patch\Multiplayer\Scripts\*.rbx      (the mod's other scripts)
   ...

Your player name, hotkeys, favourites and worlds go into
Patch\Multiplayer, the logs into the Logs folder of the game folder.

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
older version left behind. Your player name, hotkeys, favourites and worlds
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


QUICK START
-----------
1. Pick "Multiplayer" below "Continue" on the title screen and type the
   name the others see.
2. One of you picks "Create new world", gives it a name and, if you
   like, a password.
3. Everyone confirms on that world and picks "Enter the world".
4. On the map, stand next to a friend, press B and pick "Invite to a
   party"; they accept in their own wheel. You now play the leader's
   story together and fight co-op battles.

For a PvP battle without a world, press F11 on the map and host; your
friend joins with the join code you send them.


HOTKEYS
-------
   B        action wheel: invite, duel, trade, chat, teleport to the leader
   T        chat: /g everyone, /p your party, /s your map, /w one player, /help
   E        emote wheel
   F11      World overview, or the PvP battle screen outside a world
   Y / N    accept / decline the first invite at the top left
   Tab      make the party box small or full

Rebind them in "Mod Config > Monster Girl Quest! Online".


TROUBLE?
--------
The guide's troubleshooting section explains the game's messages:

   https://github.com/Pauliinchen/MGQ-Online/blob/main/docs/GUIDE.md#troubleshooting

Both logs are in the Logs folder of your game folder, a pair per time
you played, named after when the game started, such as
"Multiplayer InGame 2026-10-07 18-30-05.log" and
"Multiplayer 2026-10-07 18-30-05.log". The Multiplayer InGame log tells
what the mod did inside the game; the Multiplayer log tells what the
connection did. Please attach both of the session that went wrong to a
bug report.


CREDITS
-------
The mod loader is the community's Patch.rb from the MGQ wiki (link
above). It is not included in this download.

Monster Girl Quest! Online is an unofficial fan project. It is not
affiliated with or endorsed by Torotoro Resistance, the creators of
Monster Girl Quest!, or the English translation team. It contains no
game or translation files.

   https://github.com/Pauliinchen/MGQ-Online
