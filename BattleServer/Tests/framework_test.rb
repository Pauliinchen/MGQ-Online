#----------------------------------------------------------------
#  framework_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Hosted a served Raid World battle against a pooled boss in the server's order, up to its report
#                            - Checked that the server leaves the game folder's saves alone and reads the game's database
#      Paulinchen  2026-11-06: Expected the Mod Framework in its own folder, Patch/Mod_Framework, since MGQ Online no longer ships it
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Tests that the server loads MGQ Online on the Mod Framework, from the game folder BATTLE_GAME_DIR
# names, whose Patch folder holds MGQ Online and the framework's entry file and folder
# (Patch/Mod_Framework), installed from the framework's own release: the framework boots without its
# DLL, MGQ Online counts as available and loads every script, the database is the game's, nothing
# reaches the game folder's saves, and with BATTLE_CORE_LIBRARY a served Raid World battle against a
# pooled boss fights its pool at its tier and reports the kill. Skipped without such a game folder,
# since the game's files never go into the repository.

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
  # As a forked child: the scripts installed with the bridge closed, which opens at frame 0.
  Core.open(Core.load(library))
  ServedBattle.paced = false
  troop = 327
  battle_id = "b0000000000000001"

  # The starter's game writes the setup of its Raid World battle against Adramelech on map 619,
  # with the pool as its ledger knows it.
  DataManager.create_game_objects
  $game_party.setup_starting_members
  $game_map.setup(619)
  $game_troop.setup(troop)
  MGQ_MpOverworldSync::Me.take_seat(1)
  build = MGQ_MpBattlesCoop.own_build
  player = MGQ_MpBattlesCoop::Player.new(1, "Starter", build[0], build[1], build[2], [0, 1, 2, 3], 4, 0)
  MGQ_MpRaidPool.define_singleton_method(:served_fields) { [1, 0, [["Adramelech", "1.0000000000", 0, 0, ""]]] }
  ServedBattle.instance_variable_set(:@raid, true)
  setup = MGQ_MpBattlesServed.setup_text([player], nil)
  ServedBattle.instance_variable_set(:@raid, nil)
  MGQ_MpRaidPool.singleton_class.send(:remove_method, :served_fields)

  # The player's game comes onto the battle channel and answers ready; at the first command phase
  # the player's blow kills the boss.
  bridge = Online::Bridge.new
  bridge.push("in", player.seat)
  ready = MGQ_Multiplayer::Bridge.call("message.write", "fields" => { "battle" => "ready", "bid" => battle_id }, "body" => "")
  Boot::Wrap.around(Online.singleton_class, :send_to, :test) do |_online, original, args, _block|
    sent = original.call(*args)
    bridge.push("message", player.seat, ready) if args[1] == "ready"
    sent
  end
  stats = nil
  Boot::Wrap.around(Scene_Battle, :start_party_command_selection, :test) do |_scene, _original, _args, _block|
    boss = $game_troop.members[0]
    stats = %i[def mdf mhp].map { |stat| [boss.send(stat), boss.send(MGQ_MpHooks.plain(Game_Enemy, stat))] }
    boss.hp = 0
    BattleManager.judge_win_loss
  end

  outcome = ServedBattle.run(bridge, battle_id, setup)
  lines = online_log.string.lines
  check("the served battle against the pooled boss is won", outcome[:result], :victory)
  check("it fights the boss's pool, whose key the boss table gives once the bridge opened",
        [lines.grep(/against Adramelech \(troop 327, tier \d+\) fights the pool\(s\) Adramelech/).size, lines.grep(/key is none/)], [1, []])
  check("the boss has its tier's defense, magic defense and max HP",
        stats, %i[def mdf mhp].map.with_index { |stat, index| [(stats[index][1] * MGQ_MpRaidBosses.factor(troop, stat)).round, stats[index][1]] })
  check("the tier raises defense and magic defense", %i[def mdf].map { |stat| MGQ_MpRaidBosses.factor(troop, stat) > 1 }, [true, true])
  reports = []
  reports << bridge.reports.pop until bridge.reports.empty?
  check("the battle reports the kill of the pool through the relay's connection",
        reports.map { |key, _battle, text| [key, text.split("\t")[3]] }.last, ["Adramelech", "1"])
end

check("the database is the game's", [$data_actors.size > 1000, $data_troops.size > 1000], [true, true])
check("nothing the game writes reaches the game folder's saves", save_files, saves_before)
