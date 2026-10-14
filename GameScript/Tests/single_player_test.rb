#----------------------------------------------------------------
#  single_player_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-13: Created
#
#----------------------------------------------------------------

# Covers ui_single_player.rbx with the scripts whose settings its rows show (ui_leader_hud.rbx,
# ui_raid_bar.rbx, battles_raid_tiers.rbx): the rows of MGQ Online SP in the Mod Config, the offer
# to start the game again once one changed in a game of the player's own, the save the game goes
# on from and the title screen that loads it. It runs in a folder of its own, where the game's
# saves and the mod folder lie.

require "fileutils"
require "tmpdir"

require_relative "world_support"

$notices = []
$msgboxes = []
$calls = []
$asks = []
$exits = 0
$load_successes = []
$restart_result = 1
$open = false

# Stands in for a Mod Config Remake that reads the rows the mod keeps from the mod.
module ModConfigRemake; def self.mod_stored?(_key); true; end; end
# The Mod Config's rows, the last of them the Return row, which the mod's rows go before.
NWConst::Config::MOD_CONTENTS = [{ :key => :return }] unless NWConst::Config.const_defined?(:MOD_CONTENTS)

# Stands in for the map scene, changing scene while $map_changing is set.
class Scene_Map; def start; end; def scene_changing?; $map_changing == true; end; end
# Stands in for the title screen, changing scene while $title_changing is set.
class Scene_Title; def start; end; def update; end; def scene_changing?; $title_changing == true; end; end
# Stands in for the load screen, noting for each load finished whether the game kept for the
# restart was still there.
class Scene_Load; def on_load_success; $load_successes << File.exist?(MGQ_MpSinglePlayer::RESUME_FILE); end; end
# Stands in for the map's interpreter, running while $running is set.
class Interpreter; def running?; $running == true; end; end
# Stands in for the game's message box: busy while busy is set.
class Game_Message; def busy?; @busy == true; end; end
# Stands in for the save's system object as VX Ace keeps it: whether saving is off and the number
# of saves, which a save raises.
class Game_System
  attr_accessor :save_disabled
  attr_reader :save_count
  # Starts with saving allowed and no saves.
  def initialize; @save_disabled = false; @save_count = 0; end
  # Counts a save, as the game's save does before it writes.
  def on_before_save; @save_count += 1; end
end

# Stands in for the game's saves as VX Ace keeps them: a file per slot, the save's contents taken
# from $game_state and loaded into $loaded, failing with $save_error after the save was counted.
module DataManager
  # Answers the slot the game saved to or loaded from last.
  def self.last_savefile_index; @last_savefile_index; end
  # Names a slot's file.
  def self.make_filename(index); format("Save%02d.rvdata2", index + 1); end
  # Writes $game_state to a slot's file and keeps the slot as the last one.
  def self.save_game_without_rescue(index)
    $game_system.on_before_save
    raise $save_error if $save_error

    File.open(make_filename(index), "wb") { |file| Marshal.dump($game_state, file) }
    @last_savefile_index = index
    true
  end
  # Reads a slot's file into $loaded, noting the slot in $load_index and keeping it as the last one.
  def self.load_game_without_rescue(index)
    $load_index = index
    File.open(make_filename(index), "rb") { |file| $loaded = Marshal.load(file) }
    @last_savefile_index = index
    true
  end
end
# Stands in for the game's scenes, counting each exit in $exits.
module SceneManager; def self.exit; $exits += 1; end; end

# Stands in for RGSS's message box, noting each text in $msgboxes.
def msgbox(*texts); $msgboxes << texts.join; end

# Stands in for the DLL: there unless $available is false, mp_restart_game noted in $calls and
# answering $restart_result, or raising $restart_error.
module MGQ_Multiplayer
  # Answers whether the DLL is there.
  def self.available?; $available != false; end
  # Stands in for the DLL's functions.
  module Link
    # A function of the DLL, which notes its calls.
    Function = Struct.new(:name) do
      # Notes the call in $calls, refusing arguments its signature does not name.
      def call(*args)
        check_dll_call(name, args)
        $calls << name
        raise $restart_error if $restart_error

        $restart_result
      end
    end
    # Answers a function of the DLL.
    def self.function(name); Function.new(name); end
  end
end

load_script "battles_raid_bosses"
load_script "battles_raid_pool"
load_script "battles_raid_tiers"
load_script "ui_raid_bar"
load_script "ui_leader_hud"
load_script "ui_single_player"
SceneManager.run

# Stands in for the notification box, noting each message's key and text in $notices.
module MGQ_MpNotices; def self.message(key, text, _frames = nil); $notices << [key, text]; end; end
# Stands in for the update offer at the title screen, shown while $update_offer is set.
module MGQ_MpWorld::UpdateOffer; def self.shown?; $update_offer == true; end; end
# Stands in for parked mods: saving off while $saving_off is set, the title screen busy while
# $parking_busy is and a restart due while $parking_restart is.
module MGQ_MpModParking
  # Answers whether parked mods turned the game's saves off.
  def self.saving_off?; $saving_off == true; end
  # Answers whether the title screen puts parked mods back.
  def self.title_busy?; $parking_busy == true; end
  # Answers whether the game restarts for parked mods.
  def self.restart_due?; $parking_restart == true; end
end
# The confirm box: each question noted in $asks with its block in $answer, open while
# $confirm_open is set.
MGQ_MpUi::Confirm.define_singleton_method(:ask) { |question, choices, &answer| $asks << [question, choices]; $answer = answer; true }
MGQ_MpUi::Confirm.define_singleton_method(:open?) { $confirm_open == true }

sp = MGQ_MpSinglePlayer
hud = MGQ_MpLeaderHud
bar = MGQ_MpRaidBar
tiers = MGQ_MpRaidTiers

game_dir = Dir.mktmpdir
FileUtils.mkdir_p(File.join(game_dir, "Patch", "Multiplayer"))
Dir.chdir(game_dir)
at_exit { Dir.chdir(__dir__); FileUtils.rm_rf(game_dir) }

# Finds a row of the Mod Config.
#
# @param key [Symbol] The row's key.
# @return [Hash, nil] The row.
def row(key)
  NWConst::Config::MOD_CONTENTS.find { |each| each[:key] == key }
end

# Lists the rows of MGQ Online SP in their order.
#
# @return [Array<Hash>] The rows.
def sp_rows
  NWConst::Config::MOD_CONTENTS.select { |each| each[:name].to_s.start_with?(MGQ_MpUi::SP_PREFIX) }
end

# Forgets the settings each script read from Player.ini, which then is empty.
def fresh_settings
  $player_ini = {}
  MGQ_MpLeaderHud.instance_variable_set(:@sp_shown, nil)
  MGQ_MpLeaderHud.instance_variable_set(:@shown, nil)
  MGQ_MpRaidBar.instance_variable_set(:@shown, {})
  MGQ_MpRaidTiers.instance_variable_set(:@single_player, nil)
end

# Opens the title screen, which forgets the game played and a change not offered yet.
def title
  Scene_Title.new.start
end

# Runs the title screen's frame.
def title_frame
  Scene_Title.new.update
end

# Starts the map, so the player plays a game.
def play
  Scene_Map.new.start
end

# Runs a frame of the map.
def map_frame
  Scene_Map.new.update_scene
end

# Changes a row to the value it does not show.
#
# @param key [Symbol] The row's key, the Leader HUD's single player row unless given.
def change(key = MGQ_MpLeaderHud::SP_SHOWN_OPTION)
  changed = row(key)
  changed[:on_change].call(changed[:value].call == "On" ? "Off" : "On")
end

# Lists the games put aside.
#
# @return [Array<String>] Their files.
def kept_files
  Dir[File.join("Patch", "Multiplayer", "Resume *.rvdata2")]
end

# Starts anew at the title, then on the map with nothing asked, nothing open and nothing running,
# the game last saved to slot 3 after 5 saves.
def reset
  title
  play
  [$asks, $notices, $msgboxes, $calls, $load_successes].each(&:clear)
  $exits = 0
  $restart_result = 1
  $restart_error = nil
  $save_error = nil
  $available = nil
  $answer = nil
  $loaded = nil
  $load_index = nil
  $open = false
  $new_game_pending = false
  $update_offer = false
  $saving_off = false
  $parking_busy = false
  $parking_restart = false
  $running = false
  $confirm_open = false
  $map_changing = false
  $title_changing = false
  $game_message.busy = false
  $game_player.define_singleton_method(:transfer?) { $transfer == true }
  $transfer = false
  $game_system = Game_System.new
  $game_system.instance_variable_set(:@save_count, 5)
  $game_switches = []
  $game_state = "on map 5 at 3, 4"
  $player_ini.delete(MGQ_MpSinglePlayer::SLOT_SETTING)
  DataManager.instance_variable_set(:@last_savefile_index, 3)
  FileUtils.rm_f(Dir["*.rvdata2"] + kept_files + [MGQ_MpSinglePlayer::RESUME_FILE])
end

# Changes a row, offers the restart and answers Restart.
def restart
  change
  map_frame
  $answer.call(true)
end

# The rows of MGQ Online SP: the Leader HUD, both raid bars and the raid bosses, each kept by its
# own script.
fresh_settings
check("the group's rows in their order, each with the SP prefix and before the Return row",
      [sp_rows.map { |each| [each[:key], each[:name]] }, NWConst::Config::MOD_CONTENTS.last[:key]],
      [[[:mp_sp_leader_hud, "[MGQ Online SP] Leader HUD"], [:mp_sp_raid_bar_map, "[MGQ Online SP] Raid Bar on Map"],
        [:mp_sp_raid_bar_battle, "[MGQ Online SP] Raid Bar in Battle"], [:mp_sp_raid_bosses, "[MGQ Online SP] Raid Bosses"]], :return])
check("each kept by the mod as the player's own, On or Off",
      sp_rows.map { |each| [each[:mod_stored], each[:personal], each[:sub], each[:values].call] }.uniq, [[true, true, true, ["On", "Off"]]])
check("each with its own script's help",
      sp_rows.map { |each| each[:help] }, [hud::SP_SHOWN_OPTION_HELP, bar::OPTION_HELPS[:map], bar::OPTION_HELPS[:battle], tiers::OPTION_HELP])
check("an empty Player.ini shows the HUD and both bars and leaves the raid bosses off", sp_rows.map { |each| each[:value].call }, ["On", "On", "On", "Off"])
title
sp_rows.each { |each| each[:on_change].call(each[:value].call == "On" ? "Off" : "On") }
check("each row takes the value picked into its own script's setting",
      [[hud.sp_shown?, bar.shown?(:map), bar.shown?(:battle), tiers.single_player?], sp_rows.map { |each| each[:value].call }],
      [[false, false, false, true], ["Off", "Off", "Off", "On"]])
check("which Player.ini keeps",
      $player_ini.values_at(hud::SP_SHOWN_SETTING, bar::SHOWN_SETTINGS[:map], bar::SHOWN_SETTINGS[:battle], tiers::SETTING), ["0", "0", "0", "1"])
check("the HUD's single player setting leaves the one inside worlds alone", $player_ini.key?(hud::SHOWN_SETTING), false)
fresh_settings

# The offer to start the game again: once per change, on a quiet map, outside worlds.
reset
title
change
play
map_frame
check("a change at the title, before any game is played, offers nothing", $asks, [])
reset
change
map_frame
check("a change while playing outside a world offers to start the game again on the map", $asks, [[sp::RESTART_QUESTION, ["Restart", "Later"]]])
map_frame
check("once", $asks.size, 1)
reset
hud_row = row(hud::SP_SHOWN_OPTION)
hud_row[:on_change].call(hud_row[:value].call)
map_frame
check("a value picked again that it had already offers nothing", $asks, [])
reset
change
change
map_frame
check("a row turned back to its value at the last offer counts as unchanged", $asks, [])
reset
change
change(bar::OPTIONS[:map])
change
map_frame
check("but not while another row still differs", $asks.size, 1)
$answer.call(false)
change(bar::OPTIONS[:map])
map_frame
check("after an offer, its values are what a change is compared with", $asks.size, 2)
fresh_settings
reset
$open = true
change
map_frame
$open = false
map_frame
check("a change inside a world applies as it is and offers nothing, then or later", $asks, [])
{
  "an event runs" => proc { |on| $running = on },
  "a message shows" => proc { |on| $game_message.busy = on },
  "the player moves between maps" => proc { |on| $transfer = on },
  "another box asks" => proc { |on| $confirm_open = on },
  "the scene changes" => proc { |on| $map_changing = on },
  "the game turned its saves off" => proc { |on| $game_system.save_disabled = on },
  "a Library replay runs" => proc { |on| $game_switches[sp::LIBRARY_REPLAY_SWITCH] = on },
  "parked mods turned saving off" => proc { |on| $saving_off = on },
}.each do |label, set|
  reset
  change
  set.call(true)
  2.times { map_frame }
  waited = $asks.size
  set.call(false)
  map_frame
  check("while #{label} the offer waits, then comes once", [waited, $asks.size], [0, 1])
end
reset
change
title
play
map_frame
check("the title screen forgets a change not offered yet", $asks, [])
reset
$available = false
change
lines = logged_lines { map_frame }
$available = nil
map_frame
check("without the DLL nothing is offered, once, and the log says why",
      [$asks, lines.grep(/no restart offered/).size], [[], 1])

# Later plays on; Restart saves the game apart from every slot and starts it again, unless the
# map got busy while the box showed.
reset
change
map_frame
$answer.call(false)
check("Later plays on: nothing saved, nothing started", [File.exist?(sp::RESUME_FILE), $calls, $exits, $notices], [false, [], 0, []])
change
map_frame
check("and the next change offers again", $asks.size, 2)
reset
change
map_frame
$running = true
$answer.call(true)
check("Restart while an event began under the box saves and starts nothing", [File.exist?(sp::RESUME_FILE), $calls, $exits], [false, [], 0])
map_frame
waited = $asks.size
$running = false
map_frame
check("and asks again once the map is free", [waited, $asks.size], [1, 2])
reset
restart
saved = File.exist?(sp::RESUME_FILE) ? File.open(sp::RESUME_FILE, "rb") { |file| Marshal.load(file) } : nil
check("Restart saves the game through the game's own save to the file kept for the restart, no slot's file",
      [saved, Dir["*.rvdata2"]], ["on map 5 at 3, 4", []])
check("a save the game's count of saves leaves out", $game_system.save_count, 5)
check("the slot the game saved to last stays, kept in Player.ini, and its files keep their names after",
      [DataManager.last_savefile_index, $player_ini[sp::SLOT_SETTING], DataManager.make_filename(3)], [3, "3", "Save04.rvdata2"])
check("then the DLL starts the game again and this one ends", [$calls, $exits, $msgboxes, $notices], [["mp_restart_game"], 1, [], []])
$game_state = "in the Pocket Castle"
$exits = 0
restart
kept = kept_files
check("a game kept from a restart before goes aside, the new one in its place",
      [kept.size, kept.map { |file| File.open(file, "rb") { |each| Marshal.load(each) } }, File.open(sp::RESUME_FILE, "rb") { |file| Marshal.load(file) }, $exits],
      [1, ["on map 5 at 3, 4"], "in the Pocket Castle", 1])
reset
$restart_result = 2
restart
check("under Wine the player reads that they start it themselves, and the game ends, keeping the save",
      [$msgboxes, $exits, File.exist?(sp::RESUME_FILE)], [[sp::BY_HAND_TEXT], 1, true])
reset
$restart_result = 0
restart
check("a game that could not start itself again removes the save, tells the player in the notification box and plays on",
      [File.exist?(sp::RESUME_FILE), $notices, $exits], [false, [[sp::NOTICE_KEY, sp::FAILED_TEXT]], 0])
reset
$restart_error = RuntimeError.new("no DLL call")
restart
check("so does a start that fails, without a notice", [File.exist?(sp::RESUME_FILE), $exits, $notices], [false, 0, []])
reset
$save_error = IOError.new("disk full")
restart
check("a save that fails starts nothing and tells the player",
      [$calls, $exits, File.exist?(sp::RESUME_FILE), $notices], [[], 0, false, [[sp::NOTICE_KEY, sp::SAVE_FAILED_TEXT]]])
check("keeping the count of saves and the files' names", [$game_system.save_count, DataManager.make_filename(3)], [5, "Save04.rvdata2"])

# The title screen goes on from the game kept for the restart.
reset
restart
DataManager.instance_variable_set(:@last_savefile_index, 0)
title
$title_changing = true
title_frame
$title_changing = false
check("a title screen already changing scene leaves the save", [$loaded, File.exist?(sp::RESUME_FILE)], [nil, true])
title_frame
check("its first frame loads the save through the game's own load, from the file kept for the restart, as the slot it kept",
      [$loaded, $load_index, DataManager.last_savefile_index], ["on map 5 at 3, 4", 3, 3])
check("finishes the load as Continue does while the save is still there, then removes it",
      [$load_successes, File.exist?(sp::RESUME_FILE), DataManager.make_filename(0)], [[true], false, "Save01.rvdata2"])
$game_state = "in the Pocket Castle"
DataManager.save_game_without_rescue(0)
FileUtils.cp("Save01.rvdata2", sp::RESUME_FILE)
$loaded = nil
title_frame
check("only once per visit of the title screen", [$loaded, $load_successes.size], [nil, 1])
$player_ini.delete(sp::SLOT_SETTING)
title
title_frame
check("the next visit looks again, slot 0 when none was kept", [$loaded, $load_index, $load_successes.size, File.exist?(sp::RESUME_FILE)], ["in the Pocket Castle", 0, 2, false])
{
  "a world is open" => proc { |on| $open = on },
  "a world's new game waits" => proc { |on| $new_game_pending = on },
  "the update offer shows" => proc { |on| $update_offer = on },
  "parked mods are put back" => proc { |on| $parking_busy = on },
  "the game restarts for parked mods" => proc { |on| $parking_restart = on },
}.each do |label, set|
  reset
  restart
  title
  set.call(true)
  2.times { title_frame }
  waited = [$loaded, File.exist?(sp::RESUME_FILE)]
  set.call(false)
  title_frame
  check("while #{label} the title screen waits, then goes on in the same visit", [waited, $loaded], [[nil, true], "on map 5 at 3, 4"])
end
reset
title
title_frame
check("without the save the title screen does nothing", [$loaded, $load_successes, $msgboxes], [nil, [], []])
File.binwrite(sp::RESUME_FILE, "not a save")
title
title_frame
kept = kept_files
check("a save that cannot be loaded goes aside, and the player reads where",
      [File.exist?(sp::RESUME_FILE), kept.size, $load_successes, $msgboxes], [false, 1, [], [format(sp::RESUME_FAILED_TEXT, kept.first.tr("/", "\\"))]])
title
title_frame
check("so later visits of the title screen ask nothing", $msgboxes.size, 1)
check("the files keep their names after", DataManager.make_filename(0), "Save01.rvdata2")
