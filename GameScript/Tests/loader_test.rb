#----------------------------------------------------------------
#  loader_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-07: Checked how the log's last line tells the game closing
#                            - Checked that the press closing the last screen reaches the game from the next frame only
#                            - Checked that the DLL's export table names each export once, every export the scripts call and every one the DLL has
#                            - Checked that the in-game log writes a file per session, named after the game's start, without a line limit, and counts the scripts loaded
#                            - Checked that clearing the chosen name brings the name on Discord back instead of A friend
#      Paulinchen  2026-10-06: Checked that a screen closing leaves the buttons with another that holds them, and that the guard passes Input on only while the game is in front
#                            - Checked that the in-game log counts a repeated line, while it repeats and when the game closes, and moves a log grown too large aside
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

require_relative "support"
require "tmpdir"

source = File.read(File.expand_path("../Multiplayer.rb", __dir__), encoding: "UTF-8")
scripts = source[/SCRIPTS = %w\[(.*?)\]/m, 1].split
files = Dir[File.join(SCRIPTS_DIR, "*.rbx")].map { |file| File.basename(file, ".rbx") }

check("every script in SCRIPTS is a file", scripts - files, [])
check("every file is in SCRIPTS", files - scripts, [])
check("no script is in SCRIPTS twice", scripts.select { |name| scripts.count(name) > 1 }.uniq, [])
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
check("the battle scripts keep the order their late hooks rely on",
      %w[battles battles_coop battles_sync].map { |name| scripts.index(name) }.each_cons(2).all? { |a, b| a < b }, true)

# The DLL's export table: each export once, and every call of the scripts names one of them.
table_names = source[/    EXPORTS = \{.*?\n    \}\n/m].scan(/^      '(mp_[a-z_]+)' =>/).flatten
check("every export is in the table once", table_names.select { |name| table_names.count(name) > 1 }.uniq, [])
calls = (Dir[File.join(SCRIPTS_DIR, "*.rbx")] + [File.expand_path("../Multiplayer.rb", __dir__)]).flat_map do |file|
  File.read(file, encoding: "UTF-8").scan(/(function|read)\('(mp_[a-z_]+)'/)
end.uniq
check("every export the scripts call is in the table", calls.map { |_way, name| name }.uniq - table_names, [])
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

# The in-game log: a file per session, named after the game's start, without a line limit, and a
# line repeated is counted.
module MGQ_Multiplayer; end
MGQ_Multiplayer.const_set(:LOG_DIR, "Logs")
MGQ_Multiplayer.module_eval(source[/  def self\.log_path\(name\)\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  module Log\n.*?\n  end\n/m])
Dir.mktmpdir do |game|
  Dir.chdir(game) do
    3.times { MGQ_Multiplayer::Log.write("same") }
    MGQ_Multiplayer::Log.write("other")
    files = Dir[File.join("Logs", "*")].map { |file| File.basename(file) }
    check("the session's log is named after its start, the load standing in while Windows cannot tell it",
          files, ["Multiplayer InGame #{MGQ_Multiplayer::Log.instance_variable_get(:@loaded).strftime('%Y-%m-%d %H-%M-%S')}.log"])
    path = File.join("Logs", files.first.to_s)
    lines = File.read(path).lines.map { |line| line.split("  ", 2)[1].to_s.chomp }
    check("a line repeated is written once, with how often it repeated before the next one", lines, ["same", "(the line above repeated 2 times in all)", "other"])
    12.times { MGQ_Multiplayer::Log.write("flood") }
    MGQ_Multiplayer::Log.flush
    lines = File.read(path).lines.map { |line| line.split("  ", 2)[1].to_s.chomp }
    check("a line that keeps repeating says so while it goes on, and in all when the game closes", lines.last(3),
          ["flood", "(the line above repeated 10 times so far)", "(the line above repeated 11 times in all)"])
    3100.times { |index| MGQ_Multiplayer::Log.write("line #{index}") }
    check("the log has no line limit", File.read(path).lines.last.split("  ", 2)[1].chomp, "line 3099")
  end
end

# The session's start as Windows tells it: the process's creation time, made local.
module MGQ_Multiplayer
  module Windows
    # A stand-in for a kernel32 function, filling its output buffers as Windows would.
    Function = Struct.new(:name) do
      def call(*args)
        case name
        when "GetCurrentProcess" then -1
        when "GetProcessTimes" then args[1].replace([1, 2].pack("L2"))
        when "FileTimeToLocalFileTime" then args[1].replace(args[0])
        when "FileTimeToSystemTime" then args[1].replace([2026, 10, 3, 7, 18, 30, 5, 0].pack("S8"))
        end
        1
      end
    end

    def self.api(_library, name, _arguments, _result); Function.new(name); end
  end
end
check("the session's start comes from the game's process", MGQ_Multiplayer::Log.session_stamp, "2026-10-07 18-30-05")
# The rest of this file writes no log.
MGQ_Multiplayer::Log.define_singleton_method(:write) { |_message| }

# The buttons: every screen of the mod that holds them keeps them until it gives them back, and
# Input answers nothing past the guard but what a screen asks past the capture.
MGQ_Multiplayer.module_eval(source[/  module Capture\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  module Background\n.*?\n  end\n/m])
module MGQ_Multiplayer; module Windows; def self.game_in_front?; $front; end; end; end
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

# The player's name: a chosen one replaces the name on Discord, and clearing it brings that back.
MGQ_Multiplayer.const_set(:MAX_NAME_LENGTH, 32) unless defined?(MGQ_Multiplayer::MAX_NAME_LENGTH)
MGQ_Multiplayer.module_eval(source[/  def self\.clean\(name.*?\n  end\n/m])
module MGQ_Multiplayer
  def self.path(name); name; end
  module Ini
    def self.read(_path); {}; end
    def self.write(_path, values); $player_ini_written = values.dup; true; end
  end
  module Discord; def self.player_name; $discord_name; end; end
  module Link
    def self.new_id; "key"; end
    def self.set_player(_key, name); $shared_name = name; true; end
  end
end
MGQ_Multiplayer.module_eval(source[/  module Player\n.*?\n  end\n/m])
player = MGQ_Multiplayer::Player
$discord_name = "Discord Me"
check("a name someone else chose that is empty still reads A friend", MGQ_Multiplayer.clean("  "), "A friend")
player.name = "Chosen"
check("a chosen name replaces the name on Discord", [player.name, $player_ini_written["name"]], ["Chosen", "Chosen"])
player.name = "   "
check("clearing it keeps no name in Player.ini and brings the name on Discord back",
      [player.name, $player_ini_written.key?("name"), $shared_name], ["Discord Me", false, "Discord Me"])
