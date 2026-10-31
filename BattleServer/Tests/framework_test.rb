#----------------------------------------------------------------
#  framework_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Tests that the server loads MGQ Online on the Mod Framework it ships inside, from the game folder
# BATTLE_GAME_DIR names, whose Patch folder holds the framework's entry file and MGQ Online with its
# embedded copy (Patch/Multiplayer/Mod_Framework): the framework boots without its DLL, MGQ Online
# counts as available and loads every script, and with BATTLE_CORE_LIBRARY a served battle's setup
# is read. Skipped without such a game folder, since the game's files never go into the repository.

require_relative "support"

dir = game_dir
unless dir && File.file?(File.join(dir, "Patch", "!Mod_Framework.rb")) && File.directory?(File.join(dir, "Patch", "Multiplayer", "Mod_Framework"))
  Checks.skip("BATTLE_GAME_DIR names no game folder with MGQ Online and its Mod Framework")
  exit
end

require_relative File.join(LIB_DIR, "boot")
require_relative File.join(LIB_DIR, "battle")
require_relative File.join(LIB_DIR, "served")
require_relative File.join(LIB_DIR, "core")

log = StringIO.new
Boot.run(log)
check("every script of the game loads, the framework's entry file among the mods it keeps",
      [Boot.failures.map { |index, name, _| "#{index} #{name}" }, log.string.include?("!Mod_Framework.rb")], [[], false])
check("the server serves MGQ Online's battles, which the framework loads only as the game runs", Boot.served_game?, true)

online_log = StringIO.new
ServedBattle.install(online_log)
lines = online_log.string.lines
check("the framework boots from MGQ Online's copy, its handshake refused without its DLL", [Mod_Framework.booted?, Mod_Framework::FOLDER, Mod_Framework.available?],
      [true, "Patch/Multiplayer/Mod_Framework", false])
check("MGQ Online counts as available, with no line that it needs the framework", [MGQ_Multiplayer.available?, lines.grep(/needs the Mod Framework/)], [true, []])
check("entering through the framework loads every script and installs the battle hooks",
      [MGQ_Multiplayer.instance_variable_get(:@loaded).to_a.sort == MGQ_Multiplayer::SCRIPTS.sort, lines.grep(/battle hooks installed/).size, lines.grep(/FAILED/)],
      [true, 1, []])

library = Core.library(StringIO.new)
if library
  Core.open(Core.load(library))
  DataManager.create_game_objects
  $game_troop.setup(1)
  MGQ_MpOverworldSync::Me.define_singleton_method(:seat) { 0 }
  text = MGQ_MpBattlesServed.setup_text([MGQ_MpBattlesCoop::Player.new(0, "Me", "1,2,3", [], 8)], nil)
  setup = ServedBattle.check(text)
  check("with the core, a served battle's setup is written and read as the server hosts it", [setup[:troop], setup[:players].size], [1, 1])
end
