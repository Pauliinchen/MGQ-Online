#----------------------------------------------------------------
#  framework_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Checked that the server's wait for an invited player who never comes counts from the serve
#                            - Loaded a world's mods from a stand-in website into the served battle, their run wrappers set up and the database read again
#                            - Hosted a served Raid World battle against a pooled boss in the server's order, up to its report
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
# pooled boss fights its pool at its tier and reports the kill, with world mods from a stand-in
# website whose SceneManager.run wrappers set up their battle hooks. Skipped without such a game
# folder, since the game's files never go into the repository.

require "tmpdir"
require_relative "support"

dir = game_dir
unless dir && File.file?(File.join(dir, "Patch", "!Mod_Framework.rb")) && File.directory?(File.join(dir, "Patch", "Mod_Framework"))
  Checks.skip("BATTLE_GAME_DIR names no game folder with MGQ Online and its Mod Framework")
  exit
end

cache = Dir.mktmpdir("battle-mods")
ENV["BATTLE_MOD_CACHE"] = cache
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
  # with the pool as its ledger knows it, for itself and an invited player who never comes.
  DataManager.create_game_objects
  $game_party.setup_starting_members
  $game_map.setup(619)
  $game_troop.setup(troop)
  MGQ_MpOverworldSync::Me.take_seat(1)
  build = MGQ_MpBattlesCoop.own_build
  player = MGQ_MpBattlesCoop::Player.new(1, "Starter", build[0], build[1], build[2], [0, 1, 2, 3], 4, 0)
  absent = MGQ_MpBattlesCoop::Player.new(2, "Absent", build[0], build[1], build[2], [0, 1, 2, 3], 4, 0)
  MGQ_MpRaidPool.define_singleton_method(:served_fields) { [1, 0, [["Adramelech", "1.0000000000", 0, 0, ""]]] }
  ServedBattle.instance_variable_set(:@raid, true)
  setup = MGQ_MpBattlesServed.setup_text([player, absent], nil)
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
  # Frames run unpaced here, so the frames since the serve are the seconds up to hosting, the
  # database read again among them, plus the frames drawn after it.
  served_at = hosted_at = roster_frames = nil
  drawn = 0
  Boot::Wrap.around(MGQ_MpBattlesServed.singleton_class, :host, :test) do |_served, original, args, _block|
    hosted_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    drawn = 0
    original.call(*args)
  end
  Boot::Wrap.around(Graphics.singleton_class, :update, :test) do |_graphics, original, args, _block|
    drawn += 1
    original.call(*args)
  end
  Boot::Wrap.around(MGQ_MpBattlesCoop.singleton_class, :start_battle, :test) do |_coop, original, args, _block|
    roster_frames ||= ((hosted_at - served_at) / ServedBattle::FRAME_SECONDS + drawn).round
    original.call(*args)
  end
  stats = nil
  Boot::Wrap.around(Scene_Battle, :start_party_command_selection, :test) do |_scene, _original, _args, _block|
    boss = $game_troop.members[0]
    stats = %i[def mdf mhp].map { |stat| [boss.send(stat), boss.send(MGQ_MpHooks.plain(Game_Enemy, stat))] }
    boss.hp = 0
    BattleManager.judge_win_loss
  end

  # The world runs two mods of the website. Raider sets up its battle hook in a SceneManager.run
  # wrapper, as Invasions does, wraps the database's read, as the Unified Bugfix Module does, and
  # reads a file of its own; Broken's run wrapper fails.
  raider = { "Raider/Raider.rb" => <<~RAIDER, "Raider/data.txt" => "アリス\r\n" }
    RAIDER_DATA = File.read("Patch/Raider/data.txt")
    $raider_battles = 0
    class << DataManager
      alias raider_load_normal_database load_normal_database
      def load_normal_database
        raider_load_normal_database
        $data_skills[1].instance_variable_set(:@raider, true)
      end
    end
    class << SceneManager
      alias raider_run run
      def run
        Scene_Battle.class_eval do
          alias_method :raider_start, :start
          def start
            $raider_battles += 1
            raider_start
          end
        end
        raider_run
      end
    end
  RAIDER
  broken = { "Broken/Broken.rb" => "class << SceneManager\n  alias broken_run run\n  def run\n    raise 'Broken cannot set up'\n  end\nend\n" }
  routes = {}
  address, _requests = stand_in_site(routes)
  wanted = { "raider" => raider, "broken" => broken }.map do |slug, files|
    list_on_site(routes, address, slug, "1.0", files)
    [slug, "site", "1.0", files.transform_values { |bytes| ServedMods.hash_of(bytes) }]
  end
  mods = ServedMods.fetch(wanted, address, StringIO.new)

  # The child's errors are the lines the server's log takes from it.
  child_errors = StringIO.new
  $stderr = child_errors
  begin
    served_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    outcome = ServedBattle.run(bridge, battle_id, setup, mods)
  ensure
    $stderr = STDERR
  end
  check("the world's mods load and read their other files from memory as if they lay in Patch",
        [RAIDER_DATA.force_encoding("UTF-8"), File.exist?("Patch/Raider/data.txt"), File.open("Patch\\Raider\\data.txt", &:read).force_encoding("UTF-8"),
         File.size("Patch/Raider/data.txt"), File.exist?("Patch/Raider/none.txt")],
        ["アリス\r\n", true, "アリス\r\n", 11, false])
  check("the battle hook a mod sets up in its SceneManager.run wrapper runs in the served battle", $raider_battles, 1)
  check("the database is read again through a mod's wrapper of its read", $data_skills[1].instance_variable_get(:@raider), true)
  check("a mod's run wrapper that fails is written to the server's log",
        child_errors.string.lines.grep(/\Amod run setup: RuntimeError: Broken cannot set up/).size, 1)
  check("the same mods load once in a process that hosts one battle after another", ServedMods.load(mods, StringIO.new), 0)
  lines = online_log.string.lines
  # The players count their wait for the roster from the serve, so the server's wait for one who
  # never comes counts the seconds its setup took.
  check("the roster goes out within the server's wait for the players, counted from the serve, while one never comes",
        [lines.grep(/1 of 2 players came onto the battle channel, not seats 2/).size, roster_frames <= MGQ_MpBattlesServed::ARRIVE_FRAMES], [1, true])
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
FileUtils.rm_rf(cache)
