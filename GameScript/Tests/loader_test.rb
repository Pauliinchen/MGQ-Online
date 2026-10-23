#----------------------------------------------------------------
#  loader_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Gave the closing its world room drain topic
#                            - Checked that no script names an Encoding constant
#      Paulinchen  2026-10-23: Checked that the log's lines wait for the bridge, cross it with the frame and go into the day's file while the mod stays off
#                            - Checked that an error the error box shows is written once
#                            - Dropped the checks of the day's file, the repeats, the cut and the old logs, which the DLL's tests cover
#                            - Dropped the checks of the chosen name, which the DLL keeps now
#                            - Dropped the check of the log rules of the deleted options dump
#      Paulinchen  2026-10-17: Checked the load order of the raid boss freeze scripts
#      Paulinchen  2026-10-15: Checked that every export takes at most 16 arguments
#                            - Checked the log of each day and that starting a game deletes those of earlier days
#      Paulinchen  2026-10-13: Checked that ui_single_player.rbx loads after the scripts whose rows it adds
#                            - Checked that battles_raid_tiers.rbx loads after the scripts it builds on and before ui_raid_bar.rbx
#      Paulinchen  2026-10-12: Stood in for Ini.load
#                            - Checked the mouse wheel's notches, read once a frame
#      Paulinchen  2026-10-11: Checked that a log past MAX_BYTES keeps its newest lines
#      Paulinchen  2026-10-10: Checked that a text that grew while read from the DLL is asked for again
#      Paulinchen  2026-10-09: Checked that story_state.rbx loads before the story scripts that build on it
#      Paulinchen  2026-10-08: Checked that a watched key goes down once per frame
#                            - Checked that a held key reads as one press per frame
#                            - Checked how the sessions kept are counted and which logs are deleted
#      Paulinchen  2026-10-07: Checked that a session start deletes all but the last five sessions' logs
#                            - Checked how the log's last line tells the game closing
#                            - Checked that the press closing the last screen reaches the game from the next frame only
#                            - Checked the DLL's export table against the scripts and the DLL
#                            - Checked the in-game log's file per session and its count of scripts loaded
#                            - Checked that clearing the chosen name brings the name on Discord back
#      Paulinchen  2026-10-06: Checked the buttons a closing screen leaves and the guard of Input
#                            - Checked the in-game log's repeated lines and a log grown too large
#                            - Checked that ui_wheel.rbx loads before both wheels
#      Paulinchen  2026-10-04: Checked that coop_gather.rbx loads after coop_events.rbx and coop_castle.rbx after coop_story.rbx
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked that a family's base script loads before its other scripts
#                            - Checked that core_log.rbx loads first
#      Paulinchen  2026-10-02: Checked that core_hooks.rbx loads first
#                            - Checked that the scripts whose constants the World overview shares load before it
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers how Multiplayer.rb loads the other scripts: SCRIPTS names exactly the files in
# GameScript/Multiplayer/Scripts, and load_scripts runs them at the top level, in order, logging one
# that fails or is missing while the others still load.

require_relative "bridge_support"
require "tmpdir"

source = File.read(File.expand_path("../Multiplayer.rb", __dir__), encoding: "UTF-8")
scripts = source[/SCRIPTS = %w\[(.*?)\]/m, 1].split
files = Dir[File.join(SCRIPTS_DIR, "*.rbx")].map { |file| File.basename(file, ".rbx") }

check("every script in SCRIPTS is a file", scripts - files, [])
check("every file is in SCRIPTS", files - scripts, [])
check("no script is in SCRIPTS twice", scripts.select { |name| scripts.count(name) > 1 }.uniq, [])
naming = (Dir[File.join(SCRIPTS_DIR, "*.rbx")] + [File.join(SCRIPTS_DIR, "..", "..", "Multiplayer.rb")]).select { |file| File.read(file, :encoding => "BOM|UTF-8") =~ /Encoding::[A-Z]/ }
check("no script names an Encoding constant, which the game's Ruby lacks", naming.map { |file| File.basename(file) }, [])
check("core_log and core_hooks load first, since every script logs and registers its hooks with them", scripts.first(2), %w[core_log core_hooks])
check("core_actors loads before the scripts whose classes build on Game_MpActor",
      %w[battles_coop battles_pvp].all? { |name| scripts.index("core_actors") < scripts.index(name) }, true)
check("the registries load before the scripts that join them",
      [scripts.index("overworld_sync") < scripts.index("ui_actions"), scripts.index("coop") < scripts.index("coop_events")], [true, true])
check("the wheels' shared reading of the arrows loads before both wheels", %w[ui_actions ui_emotes].all? { |name| scripts.index("ui_wheel") < scripts.index(name) }, true)
check("the scripts whose constants the World overview shares load before it",
      %w[ui_actions overworld battles_pvp].all? { |name| scripts.index(name) < scripts.index("world_overview") }, true)
check("a family's base script loads before its other scripts",
      %w[ui world battles battles_sync battles_pvp coop].all? { |base| scripts.select { |name| name.start_with?("#{base}_") }.all? { |name| scripts.index(base) < scripts.index(name) } }, true)
check("the party's gathering loads after the events that hand it its messages, the castle after the story it reads",
      [scripts.index("coop_events") < scripts.index("coop_gather"), scripts.index("coop_story") < scripts.index("coop_castle")], [true, true])
check("the story's state model loads before the story scripts that build on it",
      %w[coop_story coop_castle world_story world_catchup coop_choices].all? { |name| scripts.index("story_state") < scripts.index(name) }, true)
check("the battle scripts keep the order their late hooks rely on",
      %w[battles battles_coop battles_sync].map { |name| scripts.index(name) }.each_cons(2).all? { |a, b| a < b }, true)
check("the raid tiers load after the Mod Config rows, the push routes, the boss table and the pools whose rules they share, and before the bars that draw them",
      [%w[ui overworld_sync battles_raid_bosses battles_raid_pool].all? { |name| scripts.index(name) < scripts.index("battles_raid_tiers") }, scripts.index("battles_raid_tiers") < scripts.index("ui_raid_bar")],
      [true, true])
check("the single player rows load after the Mod Config rows, the world's sync and the scripts whose settings they show",
      %w[ui overworld_sync battles_raid_tiers ui_raid_bar ui_leader_hud].all? { |name| scripts.index(name) < scripts.index("ui_single_player") }, true)
check("the raid boss freeze loads its data before its engine and the engine before the world's list, all after the pools",
      %w[battles_raid_pool battles_raid_freeze_data battles_raid_freeze world_freeze].map { |name| scripts.index(name) }.each_cons(2).all? { |a, b| a < b }, true)
check("the frozen fights' stand-ins load after the bars that draw over them and the join hotkey that resumes them",
      %w[battles_coop_join battles_raid_freeze world_freeze ui_raid_bar].all? { |name| scripts.index(name) < scripts.index("ui_raid_freeze") }, true)

# The DLL's export table: each export once, and every call of the scripts names one of them.
table_names = source[/    EXPORTS = \{.*?\n    \}\n/m].scan(/^      '(mp_[a-z_]+)' =>/).flatten
check("every export is in the table once", table_names.select { |name| table_names.count(name) > 1 }.uniq, [])
calls = (Dir[File.join(SCRIPTS_DIR, "*.rbx")] + [File.expand_path("../Multiplayer.rb", __dir__)]).flat_map do |file|
  File.read(file, encoding: "UTF-8").scan(/(function|read)\('(mp_[a-z_]+)'/)
end.uniq
check("every export the scripts call is in the table", calls.map { |_way, name| name }.uniq - table_names, [])
# The game's Win32API refuses an export of more arguments, so the export could not be called at all.
check("every export takes at most 16 arguments", DLL_EXPORTS.select { |_name, arguments| arguments.size > 16 }.keys, [])
check("every export read into a buffer takes the buffer and its size",
      calls.select { |way, name| way == "read" && DLL_EXPORTS[name] != "pl" }.map { |_way, name| name }, [])
exported = Dir[File.expand_path("../../MGQParadox.Multiplayer/Exports/*.cs", __dir__)].flat_map do |file|
  File.read(file, encoding: "UTF-8").scan(/EntryPoint = "(mp_[a-z_]+)"/).flatten
end
check("the table names every export of the DLL and no other", [(table_names - exported), (exported - table_names)], [[], []]) unless exported.empty?

# The parts of Multiplayer.rb that load, taken out of it, so they run without the game.
harness = Module.new
%w[MOD_DIR SCRIPTS_DIR SCRIPT_EXTENSION].each do |name|
  harness.const_set(name, eval(source[/#{name} = (".*?")/, 1]))
end
harness.const_set(:SCRIPTS, %w[good broken missing after])
log = []
harness.const_set(:Log, Module.new.tap { |mod| mod.define_singleton_method(:write) { |line| log << line } })
harness.module_eval(source[/  def self\.path\(name\)\n.*?\n  end\n/m])
harness.module_eval(source[/  def self\.load_scripts\n.*?\n  end\n/m])

Dir.mktmpdir do |game|
  Dir.chdir(game) do
    folder = File.join("Patch", "Multiplayer", "Scripts")
    Dir.mkdir("Patch")
    Dir.mkdir(File.join("Patch", "Multiplayer"))
    Dir.mkdir(folder)
    File.write(File.join(folder, "good.rbx"), "\xEF\xBB\xBFmodule LoaderTestGood; VALUE = 1; end\nclass Array; def loader_test_good?; true; end; end\n")
    File.write(File.join(folder, "broken.rbx"), "module LoaderTestBroken\n  def self.x(\nend\n")
    File.write(File.join(folder, "after.rbx"), "module LoaderTestAfter; end\n")
    harness.load_scripts
  end
end

check("a script loads at the top level, past a byte order mark",
      [defined?(LoaderTestGood::VALUE) ? LoaderTestGood::VALUE : nil, [].respond_to?(:loader_test_good?)], [1, true])
check("the scripts after one that fails or is missing still load", defined?(LoaderTestAfter) ? true : false, true)
check("a script that does not parse is logged by name", log.any? { |line| line.start_with?("broken.rbx did not load: SyntaxError") }, true)
check("a missing script is logged by name", log.any? { |line| line.start_with?("missing.rbx did not load: Errno::ENOENT") }, true)
check("the log counts the scripts loaded and names those that did not", log.last, "loaded 2 of 4 scripts, not broken, missing")

# The log: lines wait for the bridge, then cross it with the frame's batch, each with its time of
# day; while the mod stays off, the scripts write them into the day's file themselves.
MGQ_Multiplayer.const_set(:LOG_DIR, "Logs")
MGQ_Multiplayer.module_eval(source[/  def self\.log_path\(name\)\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  module Log\n.*?\n  end\n/m])
load_bridge
log = MGQ_Multiplayer::Log
crossed = []
flushes = [0]
fake = FakeBridge.new
fake.answer("log.write") { |line| crossed << line; nil }
fake.answer("log.flush") { |_request| flushes[0] += 1; nil }
log.write("starting")
MGQ_Multiplayer::Bridge.open(fake)
log.write("Lukaルカ")
log.write("bytes \xFF".dup.force_encoding("UTF-8"))
MGQ_Multiplayer::Bridge.frame
check("the lines wait while the start has not decided", crossed, [])
log.settle(true)
MGQ_Multiplayer::Bridge.frame
check("then cross in order with the next frame, the bridge's opening among them",
      crossed.map { |_time, line| line.sub(/ with the DLL .*/, "") }, ["starting", "bridge: opened context 1", "Lukaルカ", "bytes \xFF".b])
check("each with the time of day it was written at, a line that is no valid text as its bytes",
      [crossed.all? { |time, _line| time =~ /\A\d\d:\d\d:\d\d\z/ }, crossed.last.last.encoding], [true, Encoding::ASCII_8BIT])
crossed.clear
log.write("the game closes")
log.flush
check("a flush hands a line over at once and has the DLL write every line", [crossed.map(&:last), flushes[0]], [["the game closes"], 1])
MGQ_Multiplayer::Bridge.close

Dir.mktmpdir do |game|
  Dir.chdir(game) do
    log.instance_variable_set(:@early, [])
    log.write("starting")
    log.write("not started: the mod is turned off")
    log.settle(false)
    log.settle(true)
    log.write("loaded 70 of 70 scripts")
    log.flush
    file = File.join("Logs", "Multiplayer #{Time.now.strftime('%Y-%m-%d')}.log")
    lines = File.binread(file).split("\r\n").map { |line| line.split("  ", 2)[1] }
    check("while the mod stays off, the lines and the reason go into the day's file directly, marked as the scripts'",
          [lines, flushes[0]], [["[script] starting", "[script] not started: the mod is turned off", "[script] loaded 70 of 70 scripts"], 1])
  end
end

# The rest of this file writes no log.
MGQ_Multiplayer::Log.define_singleton_method(:write) { |_message| }

# The buttons: every screen of the mod that holds them keeps them until it gives them back, and
# Input answers nothing past the guard but what a screen asks past the capture.
MGQ_Multiplayer.module_eval(source[/  module Capture\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  module Background\n.*?\n  end\n/m])
# Stands in for whether the game's window is in front, kept in $front.
module MGQ_Multiplayer; module Windows; def self.game_in_front?; $front; end; end; end
# Stands in for the game's input: C always held, the updates counted in $input_updates.
module Input
  def self.update; $input_updates = ($input_updates || 0) + 1; end
  def self.press?(button); button == :C; end
  def self.trigger?(button); button == :C; end
  def self.repeat?(button); button == :C; end
  def self.dir4; 2; end
  def self.dir8; 2; end
end
load File.join(SCRIPTS_DIR, "core_log.rbx")
load File.join(SCRIPTS_DIR, "core_hooks.rbx")
capture = MGQ_Multiplayer::Capture
background = MGQ_Multiplayer::Background
$front = true
background.guard_input
background.guard_input
Input.update
check("the guard leaves Input as it is while the game is in front", [Input.press?(:C), Input.trigger?(:C), Input.dir4, $input_updates], [true, true, 2, 1])
capture.start(:overview)
capture.start(:emotes)
capture.stop(:emotes)
check("a screen closing leaves the buttons with another that holds them", [capture.on?, Input.trigger?(:C), Input.dir8], [true, false, 0])
check("which still reads them past the capture", [capture.trigger?(:C), capture.press?(:C), capture.repeat?(:C), Input.trigger?(:C)], [true, true, true, false])
capture.stop(:overview)
check("the last one gives them back, but the press that closed it never reaches the game in the same frame", [capture.on?, Input.trigger?(:C), capture.trigger?(:C)], [false, false, false])
Input.update
check("the game has them again from the next frame", Input.trigger?(:C), true)
$front = false
Input.update
check("another window in front takes every button away", [Input.press?(:C), capture.trigger?(:C)], [false, false])
$front = true
Input.update

# A watched key, told frame by frame as Input.trigger? tells the game's buttons, such as the
# numpad's 0, which is the game's cancel button too with Num Lock on.
MGQ_Multiplayer.module_eval(source[/  module Key\n.*?\n  end\n/m])
# Stands in for the Windows key state a watched key is read through.
module MGQ_Multiplayer
  module Windows
    # A stand-in for GetAsyncKeyState, the keys in $keys_down held.
    KeyState = Struct.new(:name) { def call(code); $keys_down.include?(code) ? -32_768 : 0; end }
    # Hands out the key state stand-in.
    def self.api(_library, name, _arguments, _result); KeyState.new(name); end
  end
end
key = MGQ_Multiplayer::Key
$keys_down = []
key.watch(0x60)
Input.update
$keys_down = [0x60]
Input.update
check("a watched key that went down reads as pressed however often the frame asks", [key.triggered?(0x60), key.triggered?(0x60)], [true, true])
Input.update
check("the Input.update of a game window's cancel ends the press", key.triggered?(0x60), false)
Input.update
check("so the key held into the next frame cancels no second screen", key.triggered?(0x60), false)
$keys_down = []
Input.update
$keys_down = [0x60]
Input.update
check("letting it go and pressing it again counts", key.triggered?(0x60), true)
$front = false
Input.update
$keys_down = []
Input.update
$keys_down = [0x60]
Input.update
check("but not while another window is in front", key.triggered?(0x60), false)
$front = true
$keys_down = []
Input.update
check("a key asked for the first time reads as not pressed until the next frame", [key.triggered?(0x2D), key.instance_variable_get(:@watched).key?(0x2D)], [false, true])
$keys_down = [0x41]
first = key.pressed?(0x41)
Input.update
Input.update
key.next_frame
check("a held key reads as one press, though a game window's cancel runs Input.update twice in a frame", [first, key.pressed?(0x41)], [true, false])
$keys_down = []
key.next_frame
key.next_frame
key.next_frame
$keys_down = [0x41]
check("a key nobody asked about for frames reads as pressed again", key.pressed?(0x41), true)

# The mouse wheel: the DLL's notches read once a frame, the same for every box that asks, dropped
# after a frame nobody asked in, and none while the game is behind, the boxes are arranged or the
# DLL lacks the export.
MGQ_Multiplayer.module_eval(source[/  module Mouse\n.*?\n  end\n/m])
# Stands in for ui_layout.rbx, the boxes arranged while $arranging is.
module MGQ_MpUi; module Layout; def self.arranging?; $arranging == true; end; end; end
$wheel_turned = []
$wheel_reads = 0
wheel_export = Object.new
wheel_export.define_singleton_method(:call) do |*args|
  check_dll_call("mp_mouse_wheel", args)
  $wheel_reads += 1
  $wheel_turned.shift || 0
end
# Stands in for the link, whose function each check sets.
module MGQ_Multiplayer; module Link; end; end
MGQ_Multiplayer::Link.define_singleton_method(:function) { |name| name == "mp_mouse_wheel" ? wheel_export : raise("no #{name}") }
mouse = MGQ_Multiplayer::Mouse
key.next_frame
mouse.wheel
$wheel_turned = [2, -1, 3]
key.next_frame
check("the notches since the last frame, the same for every box that asks in it, read from the DLL once",
      [mouse.wheel, mouse.wheel, $wheel_reads], [2, 2, 2])
key.next_frame
check("a turn towards the player is negative", mouse.wheel, -1)
key.next_frame
key.next_frame
check("a turn gathered while nobody asked in the frame before is dropped", [mouse.wheel, $wheel_reads], [0, 4])
$wheel_turned = [1, 1]
key.next_frame
$arranging = true
check("none while the player arranges the boxes", mouse.wheel, 0)
$arranging = false
key.next_frame
$front = false
Input.update
check("none while another window is in front", mouse.wheel, 0)
$front = true
Input.update
MGQ_Multiplayer::Link.define_singleton_method(:function) { |name| raise "no #{name}" }
key.next_frame
lines = logged_lines { 3.times { key.next_frame; mouse.wheel } }
check("none without the export, which the log tells once", [mouse.wheel, lines.size], [0, 1])

# The log's last line: how the game closes.
MGQ_Multiplayer.module_eval(source[/  def self\.closing_text\(error.*?\n  end\n/m])
error = begin
  raise ArgumentError, "bad"
rescue => e
  e
end
check("the log's last line tells a game that ended from one quit and one an error ended",
      [MGQ_Multiplayer.closing_text(nil), MGQ_Multiplayer.closing_text(SystemExit.new(0)), MGQ_Multiplayer.closing_text(error)[/\A.*bad at /]],
      ["the game closes", "the game closes: it was quit (exit status 0)", "the game closes after an error: ArgumentError: bad at "])
MGQ_Multiplayer.module_eval(source[/  def self\.closing\(error\)\n.*?\n  end\n/m])
lines = logged_lines { [error, error, nil].each { |ended| MGQ_Multiplayer.closing(ended) } }
check("an error the game's error box shows is written once, though the game's end names it again",
      lines.map { |line| line[/\A[^:]*/] }, ["the game closes after an error", "the game closes"])

# A name someone else chose: nothing left of it reads as the fallback.
MGQ_Multiplayer.const_set(:MAX_NAME_LENGTH, 32) unless defined?(MGQ_Multiplayer::MAX_NAME_LENGTH)
MGQ_Multiplayer.module_eval(source[/  def self\.clean\(name.*?\n  end\n/m])
check("a name someone else chose that is empty still reads A friend", MGQ_Multiplayer.clean("  "), "A friend")

# Reading a text from the DLL: one that grew between asking its size and copying it is asked for
# again with the size it needs then, READ_TRIES times at most.
reader = Module.new
reader.const_set(:READ_TRIES, Integer(source[/    READ_TRIES = (\d+)/, 1]))
reader.module_eval(source[/    def self\.read\(name, size\)\n.*?\n    end\n/m])
# An export that answers each call from a list: a text it writes, or the size it needs, negated.
answers = []
sizes = []
export = Object.new
export.define_singleton_method(:call) do |buffer, size|
  sizes << size
  answer = answers.shift
  if answer.is_a?(Integer)
    answer
  else
    buffer[0, answer.bytesize] = answer
    answer.bytesize
  end
end
reader.define_singleton_method(:function) { |_name| export }
answers.replace(["fits"])
check("a text that fits is read at once", [reader.read("mp_text", 8), sizes], ["fits", [8]])
answers.replace([-5, "grown"])
sizes.clear
check("a larger one with the buffer it asks for", [reader.read("mp_text", 4), sizes], ["grown", [4, 6]])
answers.replace([-5, -7, -11, "grown again"])
sizes.clear
check("one that grew again between asking its size and copying it is asked for again",
      [reader.read("mp_text", 4), sizes], ["grown again", [4, 6, 8, 12]])
answers.replace([-5, -6, -7, -8, -9, -10])
sizes.clear
check("three more times at most, after which it reads as none", [reader.read("mp_text", 4), sizes, answers], ["", [4, 6, 7, 8, 9], [-10]])
