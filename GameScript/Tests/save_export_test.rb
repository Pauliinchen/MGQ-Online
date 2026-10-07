#----------------------------------------------------------------
#  save_export_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-07: Checked the menu's handler once its commands are made
#      Paulinchen  2026-10-06: Loaded world_mods.rbx, which the world screen calls
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Checks copying a world's latest save into the player's own game (world_save_export.rbx): the first
# free slot, the thumbnail, the own Save folder also while a world is open, a full Save folder, and
# the game menu's command.

require_relative "support"
require "fileutils"
require "tmpdir"

# Stand-ins for the game.
class Scene_Base; def return_scene; end; def update; end; def terminate; end; end
class Scene_MenuBase < Scene_Base; end
class Scene_Load < Scene_Base; end
class Scene_Menu < Scene_MenuBase; def create_command_window; end; end
class Window_Base; def initialize(*); end; end
class Window_Selectable < Window_Base; end
class Window_Command < Window_Selectable; end
class Window_MenuCommand < Window_Command
  attr_reader :commands
  def add_original_commands; @commands = [["Library", :library, true]]; end
  def add_command(name, symbol, enabled = true); @commands << [name, symbol, enabled]; end
end
class Window_NameEdit < Window_Base; end
class Window_NameInput < Window_Selectable; end
class Color; def initialize(*); end; end
class Sprite; def initialize(*); end; end
Rect = Struct.new(:x, :y, :width, :height)
class Scene_Title; def start; end; def create_command_window; end; def update; end; def terminate; end; end
class Window_TitleCommand; def make_command_list; end; end
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { } }; end
module SceneManager; def self.call(_scene); end; end
module DataManager
  def self.save_system; end
  def self.savefile_max; 3; end
  def self.make_filename(index); index.is_a?(Integer) ? format("Save/Save%02d.rvdata2", index + 1) : format("Save/AutoSave%s.rvdata2", index); end
  def self.make_thumbnailname(index); index.is_a?(Integer) ? format("Save/Save%02d.png", index + 1) : format("Save/AutoSave%s.png", index); end
end

# Stand-ins for the mod's base script.
module MGQ_Multiplayer
  def self.available?; true; end
  def self.outdated?; false; end
  def self.clean(text); text; end
  module Log; def self.write(_message); end; end
end

load_script "world_save_distribution"
load_script "ui"
load_script "ui_text_box"
load_script "world"
load_script "world_mods"
load_script "world_screen"
load_script "world_save_export"

Dir.mktmpdir do |root|
  Dir.chdir(root) do
    world = MGQ_MpWorld::World.new("abcdef012345", "code" => "code", "name" => "Free")
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

    # The game's menu.
    menu = Window_MenuCommand.new
    menu.add_original_commands
    check("the menu has no Copy to my game outside a world", menu.commands.map { |command| command[1] }, [:library])

    MGQ_MpWorld.instance_variable_set(:@world, world)
    menu.add_original_commands
    check("inside a world it comes after the game's own commands", menu.commands.last, ["Copy to my game", :mgq_mp_save_export, true])

    empty = MGQ_MpWorld::World.new("0123456789ab", "code" => "code", "name" => "Empty")
    MGQ_MpWorld.instance_variable_set(:@world, empty)
    menu.add_original_commands
    check("greyed out until the player saved in the world", menu.commands.last[2], false)
    MGQ_MpWorld.instance_variable_set(:@world, nil)
    check("the menu reports no open world", MGQ_MpSaveExport.export_open_world, "No world is open.")
  end
end

handlers = {}
menu_scene = Scene_Menu.new
menu_scene.instance_variable_set(:@command_window, Struct.new(:handlers) { def set_handler(symbol, handler); handlers[symbol] = handler; end }.new(handlers))
menu_scene.create_command_window
check("the menu's handler is in place once its commands are made", handlers.keys, [:mgq_mp_save_export])

# The notice ignores the press that opened it.
module Input; def self.trigger?(button); button == :C; end; end
notice = Window_MpSaveExportNotice.allocate
notice.instance_variable_set(:@frames, 0)
check("the notice stays open in the frame OK opened it", notice.closed?, false)
check("and closes on the next OK", notice.closed?, true)
