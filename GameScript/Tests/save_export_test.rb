#----------------------------------------------------------------
#  save_export_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Checked Copy to my game in the game's menu through the Mod Framework and its message
#      Paulinchen  2026-10-31: Loaded ui_online.rbx and ui_boxes.rbx in place of the scripts the Mod Framework took over
#      Paulinchen  2026-10-30: Stopped loading the deleted world_mods_parking.rbx
#      Paulinchen  2026-10-23: Made the worlds on this PC through the stand-ins of the DLL's topics
#                            - Answered the rules the DLL owns through the bridge from the golden cases
#      Paulinchen  2026-10-12: Checked the menu taking input after the notice and a menu without commands
#      Paulinchen  2026-10-09: Loaded world_mods_parking.rbx
#      Paulinchen  2026-10-07: Checked the menu's handler once its commands are made
#      Paulinchen  2026-10-06: Loaded world_mods.rbx
#      Paulinchen  2026-10-04: Followed the scripts to their new names
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Covers world_save_export.rbx: copying a world's latest save into the first free slot of the
# player's own game with its thumbnail, into the own Save folder also while a world is open, a full
# Save folder, and the game menu's command and its message.

require_relative "support"
require_relative "rules_support"
require "fileutils"
require "tmpdir"

# Stands in for the game's base scene.
class Scene_Base; def return_scene; end; def update; end; def terminate; end; end
# Stands in for the game's menu scenes.
class Scene_MenuBase < Scene_Base; end
# Stands in for the game's load screen.
class Scene_Load < Scene_Base; end
# Stands in for the game's base window.
class Window_Base; def initialize(*); end; end
# Stands in for the game's selectable windows.
class Window_Selectable < Window_Base; end
# Stands in for the game's command windows.
class Window_Command < Window_Selectable; end
# Stands in for the game menu's commands, which make their list as the game's do, keep their
# handlers and take the keys or not.
class Window_MenuCommand < Window_Command
  # @return [Boolean] Whether it takes the keys.
  attr_reader :active

  # Makes the list of the game's commands, Library and Config among them, Save near its end.
  def make_command_list
    @list = [:item, :skill, :library, :config, :save, :game_end].map { |symbol| { :name => symbol.to_s, :symbol => symbol, :enabled => true, :ext => nil } }
  end

  # Lists the symbols of its commands.
  #
  # @return [Array<Symbol>] The symbols.
  def symbols; @list.map { |entry| entry[:symbol] }; end

  # Finds a command.
  #
  # @param symbol [Symbol] Its symbol.
  # @return [Hash, nil] The command.
  def entry(symbol); @list.find { |each| each[:symbol] == symbol }; end

  # Keeps a handler.
  #
  # @param symbol [Symbol] Its command.
  # @param handler [Proc] The handler.
  def set_handler(symbol, handler); handlers[symbol] = handler; end

  # Tells whether a command has a handler.
  #
  # @param symbol [Symbol] The command.
  # @return [Boolean] Whether it has.
  def handle?(symbol); handlers.key?(symbol); end

  # Lists the handlers by symbol.
  #
  # @return [Hash{Symbol => Proc}] The handlers.
  def handlers; @handlers ||= {}; end

  # Takes the keys.
  def activate; @active = true; end

  # Takes no keys.
  def deactivate; @active = false; end

  # Goes, as at a scene change.
  def dispose; @disposed = true; end

  # Tells whether it went.
  #
  # @return [Boolean] Whether it did.
  def disposed?; @disposed == true; end
end
# Stands in for the game's name entry.
class Window_NameEdit < Window_Base; end
# Stands in for the game's name entry's letters.
class Window_NameInput < Window_Selectable; end
# Stands in for the game's colors.
class Color; def initialize(*); end; end
# Stands in for the game's sprites.
class Sprite; def initialize(*); end; end
# Stands in for the game's rectangles.
Rect = Struct.new(:x, :y, :width, :height)
# Stands in for the game's title screen.
class Scene_Title; def start; end; def create_command_window; end; def update; end; def terminate; end; end
# Stands in for the game's sounds, which play nothing.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { } }; end
# Stands in for the game's scenes, calling none.
module SceneManager; def self.call(_scene); end; end
# Stands in for the game's saves: three slots, named as the game names them.
module DataManager
  # Stands in for writing the system save, doing nothing.
  def self.save_system; end
  # Answers the number of the player's save slots.
  def self.savefile_max; 3; end
  # Names a slot's save file as the game does.
  #
  # @param index [Integer, String] The slot's index, or an autosave's number.
  # @return [String] The file.
  def self.make_filename(index); index.is_a?(Integer) ? format("Save/Save%02d.rvdata2", index + 1) : format("Save/AutoSave%s.rvdata2", index); end
  # Names a slot's thumbnail as the game does.
  #
  # @param index [Integer, String] The slot's index, or an autosave's number.
  # @return [String] The file.
  def self.make_thumbnailname(index); index.is_a?(Integer) ? format("Save/Save%02d.png", index + 1) : format("Save/AutoSave%s.png", index); end
end

# Stands in for the mod's base script.
module MGQ_Multiplayer
  # Stands in for whether the mod can run: answers true.
  def self.available?; true; end
  # Stands in for whether the mod is outdated: answers false.
  def self.outdated?; false; end
  # Stands in for cleaning a text for the screen, keeping it as it is.
  def self.clean(text); text; end
  # Stands in for the log, which writes nothing.
  module Log; def self.write(_message); end; end
end

load_script "world_save_distribution"
load_script "ui_online"
load_script "ui_boxes"
load_script "world"
load_script "world_mods"
load_script "world_screen"
load_script "world_save_export"
open_rules_bridge

Dir.mktmpdir do |root|
  Dir.chdir(root) do
    world = local_world("abcdef012345", "code" => "code", "name" => "Free")
    FileUtils.mkdir_p(world.save_folder)
    check("a world without a save says so", MGQ_MpSaveExport.export(world), "You have no save of Free yet. Save in the world first.")

    # The world's saves: an older save and a newer autosave, each with a thumbnail.
    File.binwrite("#{world.save_folder}/Save02.rvdata2", "older")
    File.binwrite("#{world.save_folder}/Save02.png", "older picture")
    File.binwrite("#{world.save_folder}/AutoSave01.rvdata2", "newest")
    File.binwrite("#{world.save_folder}/AutoSave01.png", "newest picture")
    File.utime(Time.now - 3600, Time.now - 3600, "#{world.save_folder}/Save02.rvdata2")
    FileUtils.mkdir_p("Save")
    File.binwrite("Save/Save01.rvdata2", "my own")

    said = MGQ_MpSaveExport.export(world)
    check("the latest save, an autosave too, goes into the first free slot", File.binread("Save/Save02.rvdata2"), "newest")
    check("with its thumbnail", File.binread("Save/Save02.png"), "newest picture")
    check("the player's own save stays", File.binread("Save/Save01.rvdata2"), "my own")
    check("the player is told the slot", said.end_with?("is now save 2 of your own game."), true)
    check("and when the save was made", said.start_with?("Your save of Free from #{File.mtime("#{world.save_folder}/AutoSave01.rvdata2").strftime('%Y-%m-%d %H:%M')}"), true)
    check("the world's saves stay", Dir.entries(world.save_folder).sort - %w[. ..], %w[AutoSave01.png AutoSave01.rvdata2 Save02.png Save02.rvdata2])

    # While the world is open, Save/ stands for the world's folder; the copy still reaches the player's own.
    MGQ_MpWorld::Files.root = world.save_folder
    MGQ_MpSaveExport.export(world)
    check("while the world is open, Save/ is still the world's", File.exist?("Save/Save03.rvdata2"), false)
    MGQ_MpWorld::Files.root = nil
    check("but the copy went into the player's own Save folder", File.binread("Save/Save03.rvdata2"), "newest")
    check("and nothing into the world's", File.exist?("#{world.save_folder}/Save03.rvdata2"), false)

    check("a full Save folder says so", MGQ_MpSaveExport.export(world), "Your own game has no free save slot. Delete one of your saves first.")
    FileUtils.rm("Save/Save03.rvdata2")

    # The game's menu, made as the game makes it, with the commands the Mod Framework adds once
    # the game runs.
    rule = Mod_Framework::UI::Adopt.rules.find { |each| each.target == Window_MenuCommand }
    make_menu = lambda do
      menu = Window_MenuCommand.new
      menu.make_command_list
      Mod_Framework::UI::Adopt.edit_commands(menu)
      rule.install_handlers(menu)
      menu
    end
    check("the menu has no Copy to my game outside a world", make_menu.call.symbols, [:item, :skill, :library, :config, :save, :game_end])

    MGQ_MpWorld.instance_variable_set(:@world, world)
    menu = make_menu.call
    check("inside a world it comes after the game's own commands, before Save, and can be picked",
          [menu.symbols, menu.entry(:mgq_mp_save_export).values_at(:name, :enabled)],
          [[:item, :skill, :library, :config, :mgq_mp_save_export, :save, :game_end], ["Copy to my game", true]])

    # Picking it shows how the copy went in the framework's message.
    shown = []
    Mod_Framework::UI::Message.define_singleton_method(:show) { |title, text| shown << [title, text]; nil }
    menu.handlers[:mgq_mp_save_export].call
    saved = File.mtime("#{world.save_folder}/AutoSave01.rvdata2").strftime("%Y-%m-%d %H:%M")
    check("picking it copies the save and shows how it went", shown.last, ["Copy to my game", "Your save of Free from #{saved} is now save 3 of your own game."])

    empty = local_world("0123456789ab", "code" => "code", "name" => "Empty")
    MGQ_MpWorld.instance_variable_set(:@world, empty)
    check("greyed out until the player saved in the world", make_menu.call.entry(:mgq_mp_save_export)[:enabled], false)
    MGQ_MpWorld.instance_variable_set(:@world, nil)
    check("the menu reports no open world", MGQ_MpSaveExport.export_open_world, "No world is open.")
  end
end
