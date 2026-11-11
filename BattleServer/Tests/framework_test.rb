#----------------------------------------------------------------
#  framework_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Checked that the server leaves the game folder's saves alone and reads the game's database
#      Paulinchen  2026-11-06: Expected the Mod Framework in its own folder, Patch/Mod_Framework, since MGQ Online no longer ships it
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Tests that the server loads MGQ Online on the Mod Framework, from the game folder BATTLE_GAME_DIR
# names, whose Patch folder holds MGQ Online and the framework's entry file and folder
# (Patch/Mod_Framework), installed from the framework's own release: the framework boots without its
# DLL, MGQ Online counts as available and loads every script, the database is the game's, nothing
# reaches the game folder's saves, and with BATTLE_CORE_LIBRARY a served battle's setup is read. Skipped without such a game folder, since the game's files never go into
# the repository.

require_relative "support"

dir = game_dir
unless dir && File.file?(File.join(dir, "Patch", "!Mod_Framework.rb")) && File.directory?(File.join(dir, "Patch", "Mod_Framework"))
  Checks.skip("BATTLE_GAME_DIR names no game folder with MGQ Online and its Mod Framework")
  exit
end

require_relative File.join(LIB_DIR, "boot")
require_relative File.join(LIB_DIR, "served")
require_relative File.join(LIB_DIR, "core")

# Lists the files of the game folder's Save folder with their sizes and times, which the tests only
# read: the folder holds the player's own saves.
#
# @return [Hash{String => Array}] Each file's path inside the folder to its size and time; empty
#   without the folder.
def save_files
  folder = File.join(game_dir, "Save")
  Dir.glob("**/*", base: folder).select { |name| File.file?(File.join(folder, name)) }.to_h do |name|
    path = File.join(folder, name)
    [name, [File.size(path), File.mtime(path)]]
  end
end

saves_before = save_files
log = StringIO.new
Boot.run(log)
check("every script of the game loads, the framework's entry file among the mods it keeps",
      [Boot.failures.map { |index, name, _| "#{index} #{name}" }, log.string.include?("!Mod_Framework.rb")], [[], false])
check("the server serves MGQ Online's battles, which the framework loads only as the game runs", Boot.served_game?, true)

online_log = StringIO.new
ServedBattle.install(online_log)
lines = online_log.string.lines
check("the framework boots from its own folder, its handshake refused without its DLL", [Mod_Framework.booted?, Mod_Framework::FOLDER, Mod_Framework.available?],
      [true, "Patch/Mod_Framework", false])
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

check("the database is the game's", [$data_actors.size > 1000, $data_troops.size > 1000], [true, true])
check("nothing the game writes reaches the game folder's saves", save_files, saves_before)
