#----------------------------------------------------------------
#  stages_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Covers how Multiplayer.rb loads: without the Mod Framework all at once, under it as a Title mod,
# its title part as the game starts and the rest as the player enters the game, with the hooks
# asleep in a game entered without the mod.

require_relative "support"
require "fileutils"
require "tmpdir"

source = File.read(File.expand_path("../Multiplayer.rb", __dir__), :encoding => "UTF-8")

# The Mod Framework loads the mod as a Title mod from the tag the package declares while the
# website and the relay are unknown, as on the first start after an update or with the site out
# of reach.
declared = File.read(File.expand_path("../../package/Multiplayer/Mod.ini", __dir__)).lines.map { |line| line.split("=", 2).map(&:strip) }
check("the package declares the Title tag in the mod's folder", declared.find { |key, _value| key.casecmp("tag") == 0 }, %w[tag Title])

$calls = []
$log = []
$loaded = []

# The parts of MGQ_Multiplayer the stages call, standing in for the DLL, the hooks and the log.
module MGQ_Multiplayer
  SCRIPTS_DIR = "Scripts"
  SCRIPT_EXTENSION = ".rbx"
  SCRIPTS = %w[core_hooks ui world coop battles]
  BOOT_SCRIPTS = %w[core_hooks ui]
  WORLD_SCRIPTS = %w[world]
  module Log; def self.write(line); $log << line; end; end
  def self.start; $calls << :start; end
  def self.install_hooks(run); $calls << [:hooks, run]; end
  def self.available?; true; end
  def self.closing(error); $calls << [:closing, error]; end
end
MGQ_Multiplayer.module_eval(source[/  def self\.path\(name\)\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  def self\.load_scripts\(names = SCRIPTS, part = false\)\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  def self\.load_script\(name, part\)\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  module Stages\n.*?\n  end\n/m])

# Stands in for the game's scenes.
module SceneManager; def self.scene; :title; end; end

# Puts the stages back as they were before the game started.
def fresh_stages
  $calls.clear
  $loaded.clear
  MGQ_Multiplayer.instance_variable_set(:@loaded, [])
  stages = MGQ_Multiplayer::Stages
  [:@staged, :@everything_loaded, :@world_loaded].each { |name| stages.instance_variable_set(name, nil) }
  stages.instance_variable_set(:@waiting, [])
end

Dir.mktmpdir do |game|
  Dir.chdir(game) do
    folder = File.join("Patch", "Multiplayer", "Scripts")
    FileUtils.mkdir_p(folder)
    File.write(File.join(folder, "core_hooks.rbx"), "module MGQ_MpHooks; def self.sleep_while(&asleep); $asleep = asleep; end; def self.report; end; end\n$loaded << 'core_hooks'\n")
    %w[ui coop battles].each { |name| File.write(File.join(folder, "#{name}.rbx"), "$loaded << '#{name}'\n") }
    # The world screens, opened and told of a restart in $calls.
    File.write(File.join(folder, "world.rbx"), "$loaded << 'world'\n" \
               "module MGQ_MpWorld; def self.open_world_screen(scene); $calls << [:world_screen, scene]; end; end\n" \
               "module MGQ_MpWorld; module Invite; def self.receive(code); $calls << [:invite, code]; true; end; end; end\n" \
               "module MGQ_MpWorldMods; def self.restarted_for(world); $calls << [:restarted_for, world]; end; end\n")

    # Without the Mod Framework, as on the battle server.
    fresh_stages
    MGQ_Multiplayer::Stages.when_loaded("test") { $calls << :loaded }
    MGQ_Multiplayer::Stages.boot
    check("without the framework every script loads at once, the hooks follow the game's start",
          [$calls, $loaded, MGQ_Multiplayer::Stages.staged?], [[:start, :loaded, [:hooks, true]], %w[core_hooks ui world coop battles], false])
    check("and the world needs no framework to enter", MGQ_Multiplayer::Stages.enter("the world W"), false)

    # Under the Mod Framework.
    module ::Mod_Framework
      module Mods
        @commands = []
        @enter_blocks = []
        @parts = []
        @restarts = {}
        class << self
          attr_reader :commands, :parts, :entered_by, :restarts
          def after_restart(name, tag, &block); @restarts[name] = block; end
          attr_accessor :entered
          def title_command(name, options = {}, &block); @commands << [name, options, block]; :command; end
          def on_enter(tag, &block); @enter_blocks << [tag, block]; end
          def entered?; @entered == true; end
          def load_part(path)
            @parts << path
            file = File.join("Patch", "Multiplayer", path)
            eval(File.read(file), TOPLEVEL_BINDING, file)
            true
          end
          def enter(reason, options = {})
            return false if @entered

            @entered = true
            @entered_by = [reason, options]
            @enter_blocks.each { |_tag, block| block.call }
            true
          end
        end
      end
      module Run
        @closings = []
        class << self
          attr_reader :closings
          def on_start(tag, options = {}, &block); block.call; end
          def on_close(tag, &block); @closings << block; end
        end
      end
    end
    fresh_stages
    MGQ_Multiplayer::Stages.when_loaded("test") { $calls << :loaded }
    MGQ_Multiplayer::Stages.boot
    name, options, picked = Mod_Framework::Mods.commands.first
    check("under the framework the title's Multiplayer command comes after Continue, on while the DLL runs",
          [name, options[:after], options[:enabled].call(:window)], ["Multiplayer", :continue, true])
    check("as the game starts the DLL and the first stage load, through the framework, which counts the mod as used",
          [$calls, Mod_Framework::Mods.parts, $loaded], [[:start, [:hooks, false]], %w[Scripts/core_hooks.rbx Scripts/ui.rbx], %w[core_hooks ui]])
    check("the hooks sleep only in a game entered without the mod", [$asleep.call, MGQ_Multiplayer::Stages.staged?], [false, true])
    picked.call(:window)
    check("the command loads the world screens through the framework and opens one", [Mod_Framework::Mods.parts.last, $loaded.last, $calls.last], ["Scripts/world.rbx", "world", [:world_screen, :title]])
    picked.call(:window)
    check("and loads them once", $loaded.count("world"), 1)
    Mod_Framework::Mods.restarts["multiplayer.rejoin"].call("w9")
    check("a restart the framework made for a world's mods enters that world again", $calls.last, [:restarted_for, "w9"])
    Mod_Framework::Mods.restarts["multiplayer.open"].call(nil)
    check("one an update made opens the world screen", $calls.last, [:world_screen, :title])

    $calls.clear
    MGQ_Multiplayer::Stages.enter("the world W")
    check("a world enters through the framework, which loads the rest of the scripts in their order, as do the blocks that waited",
          [Mod_Framework::Mods.entered_by, $loaded.last(2), $calls], [["the world W", {}], %w[coop battles], [:loaded]])
    check("then the hooks stay awake", $asleep.call, false)
    Mod_Framework::Run.closings.first.call
    check("and the framework writes how the game closes", $calls.last, [:closing, nil])

    # A restart for a world's mods loads the world screens before it enters the world again.
    fresh_stages
    Mod_Framework::Mods.entered = false
    Mod_Framework::Mods.instance_variable_set(:@enter_blocks, [])
    MGQ_Multiplayer::Stages.boot
    Mod_Framework::Mods.restarts["multiplayer.rejoin"].call("w8")
    check("a restart the framework made for a world's mods loads the world screens and enters that world again", [$loaded, $calls.last], [%w[core_hooks ui world], [:restarted_for, "w8"]])

    # A restart that carried a Discord invite taken during the game.
    fresh_stages
    MGQ_Multiplayer::Stages.boot
    Mod_Framework::Mods.restarts["multiplayer.invite"].call("mgqmp2;abcdefghjkmnpqrs;r1;4")
    check("a restart that carried a Discord invite loads the world screens and takes the invite anew at the title",
          [$loaded, $calls.last], [%w[core_hooks ui world], [:invite, "mgqmp2;abcdefghjkmnpqrs;r1;4"]])

    # A game entered without the mod, turned off after the game started.
    fresh_stages
    Mod_Framework::Mods.entered = false
    Mod_Framework::Mods.instance_variable_set(:@enter_blocks, [])
    MGQ_Multiplayer::Stages.boot
    Mod_Framework::Mods.instance_variable_set(:@enter_blocks, [])
    Mod_Framework::Mods.enter("New Game")
    check("a game entered without the mod loads none of its rest and its hooks sleep", [$loaded, $asleep.call], [%w[core_hooks ui], true])
  end
end
