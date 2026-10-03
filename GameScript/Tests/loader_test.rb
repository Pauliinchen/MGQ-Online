#----------------------------------------------------------------
#  loader_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-03: Checked that a family's base script loads before its other scripts
#                            - Checked that mp_log.rbx loads first
#      Paulinchen  2026-10-02: Checked that mp_hooks.rbx loads first
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
check("mp_log and mp_hooks load first, since every script logs and registers its hooks with them", scripts.first(2), %w[mp_log mp_hooks])
check("mp_actors loads before the scripts whose classes build on Game_MpActor",
      %w[mp_battles_coop mp_battles_pvp].all? { |name| scripts.index("mp_actors") < scripts.index(name) }, true)
check("the registries load before the scripts that join them",
      [scripts.index("mp_overworld_sync") < scripts.index("mp_actions"), scripts.index("mp_coop") < scripts.index("mp_coop_events")], [true, true])
check("the scripts whose constants the World overview shares load before it",
      %w[mp_actions mp_overworld mp_battles_pvp].all? { |name| scripts.index(name) < scripts.index("mp_world_overview") }, true)
check("a family's base script loads before its other scripts",
      %w[mp_world mp_battles_sync mp_battles_pvp mp_coop].all? { |base| scripts.select { |name| name.start_with?("#{base}_") }.all? { |name| scripts.index(base) < scripts.index(name) } }, true)
check("the battle scripts keep the order their late hooks rely on",
      %w[mp_battles mp_battles_coop mp_battles_sync].map { |name| scripts.index(name) }.each_cons(2).all? { |a, b| a < b }, true)

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
