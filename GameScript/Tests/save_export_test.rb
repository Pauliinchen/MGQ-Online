#----------------------------------------------------------------
#  save_export_test.rb
#
#  Changelog:
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
# Save folder, and the game menu's command and notice.

require_relative "support"
require "fileutils"
require "tmpdir"

# Stands in for the game's base scene.
class Scene_Base; def return_scene; end; def update; end; def terminate; end; end
# Stands in for the game's menu scenes.
class Scene_MenuBase < Scene_Base; end
# Stands in for the game's load screen.
class Scene_Load < Scene_Base; end
# Stands in for the game's menu, whose commands the export hooks into.
class Scene_Menu < Scene_MenuBase; def create_command_window; end; end
# Stands in for the game's base window.
class Window_Base; def initialize(*); end; end
# Stands in for the game's selectable windows.
class Window_Selectable < Window_Base; end
# Stands in for the game's command windows.
class Window_Command < Window_Selectable; end
# Stands in for the game menu's commands, which it keeps in commands.
class Window_MenuCommand < Window_Command
  attr_reader :commands
  # Stands in for the game's extra commands: starts the list with the Library.
  def add_original_commands; @commands = [["Library", :library, true]]; end
  # Adds a command to the list.
  #
  # @param name [String] Its name.
  # @param symbol [Symbol] Its handler's symbol.
  # @param enabled [Boolean] Whether it can be chosen.
  def add_command(name, symbol, enabled = true); @commands << [name, symbol, enabled]; end
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
# Stands in for the title screen's commands.
class Window_TitleCommand; def make_command_list; end; end
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
load_script "ui"
load_script "ui_text_box"
load_script "world"
load_script "world_mods"
load_script "world_mods_parking"
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

    # The game's menu offers Copy to my game inside a world.
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

# The menu's commands take input again once the notice closes, or once it could not open.

# Stands in for the menu's commands, noting in active whether they take input.
class MenuCommands
  attr_reader :active
  # Lets the commands take input.
  def activate; @active = true; end
  # Answers whether the window is gone: never.
  def disposed?; false; end
end
# Stands in for a notice the player closed, noting in disposed whether it went.
ClosedNotice = Struct.new(:disposed) do
  # Answers whether the player closed the notice: always.
  def closed?; true; end
  # Takes the notice off the screen.
  def dispose; self.disposed = true; end
end
commands = MenuCommands.new
menu_scene.instance_variable_set(:@command_window, commands)
menu_scene.instance_variable_set(:@mgq_mp_save_export_notice, closed = ClosedNotice.new(false))
menu_scene.update
check("a closed notice goes and the menu's commands take input again",
      [closed.disposed, menu_scene.instance_variable_get(:@mgq_mp_save_export_notice), commands.active], [true, nil, true])
logged = []
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
failing = Window_MpSaveExportNotice.method(:new)
Window_MpSaveExportNotice.define_singleton_method(:new) { |*_| raise "no picture" }
commands = MenuCommands.new
menu_scene.instance_variable_set(:@command_window, commands)
check("a notice that cannot open gives the menu's commands back", [MGQ_MpSaveExport.open_notice(menu_scene), commands.active], [nil, true])
bare = Scene_Menu.new
check("and a menu without commands gets nothing back, never an error", MGQ_MpSaveExport.open_notice(bare), nil)
bare.create_command_window
bare.instance_variable_set(:@mgq_mp_save_export_notice, ClosedNotice.new(false))
bare.update
check("a menu without commands makes its commands and closes the notice without a failing hook",
      [logged.grep(/world_save_export failed/), logged.grep(/has no @command_window/).size, bare.instance_variable_get(:@mgq_mp_save_export_notice)], [[], 1, nil])
Window_MpSaveExportNotice.define_singleton_method(:new, failing)

# The notice ignores the press that opened it.

# Stands in for the game's input, with OK pressed in every frame.
module Input; def self.trigger?(button); button == :C; end; end
notice = Window_MpSaveExportNotice.allocate
notice.instance_variable_set(:@frames, 0)
check("the notice stays open in the frame OK opened it", notice.closed?, false)
check("and closes on the next OK", notice.closed?, true)
