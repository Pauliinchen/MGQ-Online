#----------------------------------------------------------------
#  loader_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Checked that the in-game log counts a repeated line, while it repeats and when the game closes, and moves a log grown too large aside
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

# The in-game log: a line repeated is counted, and a log grown too large is moved aside once a
# session starts.
module MGQ_Multiplayer; end
MGQ_Multiplayer.const_set(:LOG_DIR, "Logs")
MGQ_Multiplayer.module_eval(source[/  def self\.log_path\(name\)\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  module Log\n.*?\n  end\n/m])
Dir.mktmpdir do |game|
  Dir.chdir(game) do
    Dir.mkdir("Logs")
    File.write(File.join("Logs", "Multiplayer InGame.log"), "x" * (MGQ_Multiplayer::Log::MAX_BYTES + 1))
    3.times { MGQ_Multiplayer::Log.write("same") }
    MGQ_Multiplayer::Log.write("other")
    lines = File.read(File.join("Logs", "Multiplayer InGame.log")).lines.map { |line| line.split("  ", 2)[1].to_s.chomp }
    check("a line repeated is written once, with how often it repeated before the next one", lines, ["same", "(the line above repeated 2 times in all)", "other"])
    12.times { MGQ_Multiplayer::Log.write("flood") }
    MGQ_Multiplayer::Log.flush
    lines = File.read(File.join("Logs", "Multiplayer InGame.log")).lines.map { |line| line.split("  ", 2)[1].to_s.chomp }
    check("a line that keeps repeating says so while it goes on, and in all when the game closes", lines.last(3),
          ["flood", "(the line above repeated 10 times so far)", "(the line above repeated 11 times in all)"])
    check("the log of earlier sessions, grown past its limit, is kept as the old log", File.size(File.join("Logs", "Multiplayer InGame.old.log")), MGQ_Multiplayer::Log::MAX_BYTES + 1)
  end
end
