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
Monster Girl Quest! Paradox RPG 3.06 on Windows, or on Linux with Wine
or Proton, untranslated or with the English or Russian translation.
Everyone needs the same game version and the same version of this mod.
The mod does not run on JoiPlay.

This is a Patch folder mod ("Type 1"), so the community's mod loader
must be installed: download "Patch.rb (enable Type 1 mods)" from the MGQ
wiki and put it into your Patch folder. If you already use other Patch
folder mods, you have it. The Russian translation brings its own Patch.rb,
which loads the mod too: keep it and skip the wiki one.

   https://mgq.miraheze.org/wiki/Paradox_mods#Patch.rb_(enable_Type_1_mods)

The mod runs on the Mod Framework 0.1.0 or later, which you install
first: download it from the website and extract it into the same folder
as this mod (see INSTALL). It installs and updates this mod, which has
no updater of its own. The mod's settings and hotkeys are in
Options > Mods. Without the framework the game says so as it starts,
and the mod stays off.

   https://mgqonline.org/mods


INSTALL
-------
Install the Mod Framework first (see REQUIREMENTS). Then install this
mod with the framework: "Browser" in the title's Mods box finds it. Or
close the game and extract the download into your Monster Girl Quest!
Paradox RPG folder (the one that contains Game.exe). It should then look
like this:

   Game.exe
   Patch\!Mod_Framework.rb              (the Mod Framework, which the mod runs on)
   Patch\Mod_Framework\
   Patch\Multiplayer.rb
   Patch\Multiplayer\Multiplayer.dll
   Patch\Multiplayer\Manifest.txt
   Patch\Multiplayer\README.txt
   Patch\Multiplayer\Scripts\*.rbx      (the mod's other scripts)
   Patch\Multiplayer\Data\events.db     (the game's events, read by the mod)
   ...

Your player name, hotkeys, favourites and worlds go into
Patch\Multiplayer, the logs into the Logs folder of the game folder.

While the mod is installed, the game keeps running when its window is in
the background, so no player holds the others up. A gamepad does nothing
meanwhile.


UPDATE
------
The Mod Framework updates this mod like any mod of the website.
When the server asks for another release, "Multiplayer" on the title
screen asks the framework for it, since everyone needs the same version.
The same question comes wherever the server turns your version away: at
once on the title or in the Multiplayer menu, and in a world at the next
title. Until you update, worlds, duels and trades stay off.

"Update and restart" installs the release and starts the game again in
the Multiplayer menu. This works under Wine and Proton too. Your player
name, hotkeys, favourites and worlds are kept. If the game cannot start
after an update, update by hand as below.

To update by hand, close the game and extract the new download over the
old one; then delete any Patch\Multiplayer\Scripts\*.rbx file the new
release's Manifest.txt no longer lists.


UNINSTALL
---------
Close the game and delete Multiplayer.rb and the Multiplayer folder in
Patch. That folder also holds your worlds: keep Patch\Multiplayer\Worlds
if you want to play them again later. The mod loader and the Mod
Framework stay for your other mods.


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

A world may start its new players from its creator's save. A save can
run code on your PC, so take it only from creators you trust. The game
asks first and lets you start at the beginning instead.

A world may need mods, in the versions its creator has. Entering it
installs them from the website through the Mod Framework; a mod the
website does not have you get from its author.


HOTKEYS
-------
   B        action wheel: invite, duel, trade, chat, report a bug,
            teleport to the leader
   T        chat: /g everyone, /m your map, /p your party, /w one player, /help
            (Alt + Left/Right switches tabs, Alt + drag resizes the chat)
   E        emote wheel
   F11      World overview, in a world and in single player
   Y / N    accept / decline the first invite among the notices
   M        make the party box small or full
   H        make the Leader HUD at the top left small or large
   J        join the battle of a player next to you in a Raid World
   F3       report a bug, with a screenshot and your logs

Rebind them in "Options > Mods > MGQ Online Hotkeys", Y and N in
"Mod Framework Hotkeys". The mod's settings are in "MGQ Online Settings",
those for single player in "MGQ Online SP".


TROUBLE?
--------
The guide's troubleshooting section explains the game's messages:

   https://github.com/Pauliinchen/MGQ-Online/blob/main/docs/GUIDE.md#troubleshooting

The log is in the Logs folder of your game folder, one per day you
played, named after the day, such as "Multiplayer 2026-10-07.log". It
tells what the mod did inside the game and what the connection did.
The quickest way to report a bug is F3 in the game, which sends
today's log and a screenshot to the developer. Otherwise please attach
the log of the day that went wrong to a bug report.

Starting the game deletes the logs of earlier days, so send it on the
day something went wrong.


CREDITS
-------
The mod loader is the community's Patch.rb from the MGQ wiki (link
above). It is not included in this download.

Monster Girl Quest! Online is an unofficial fan project. It is not
affiliated with or endorsed by Torotoro Resistance, the creators of
Monster Girl Quest!, or the English translation team. It contains no
game or translation files.

   https://github.com/Pauliinchen/MGQ-Online
