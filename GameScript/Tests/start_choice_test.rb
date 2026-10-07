#----------------------------------------------------------------
#  start_choice_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-07: Checked that every text of the save screen fits its line of help
#      Paulinchen  2026-10-06: Refused a DLL call whose arguments differ from its signature
#                            - Expected the longer calls of mp_dir_create and mp_dir_edit
#                            - Loaded world_mods.rbx, which the world screen calls
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#                            - Expected the button below the new rows of the form, and the longer call of mp_dir_create
#                            - Expected the shorter texts of the details' Start row
#                            - Expected a new world to be left in the list as a favourite, and its creator asked where to start on entering it
#                            - Gave the stand-in for the mod's base script its settings files, which the list's refresh reads
#                            - Expected Player's choice beside Shared save in the form's Starting point panel
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Checks where a new player of a world starts (world.rbx, world_save_distribution.rbx): the
# creator's Players choose checkbox, the directory's flag for it, and the world screen asking a
# new player to start at the beginning, from their own save or from the creator's.

require_relative "support"
require "fileutils"
require "tmpdir"

# Stand-ins for the game.
class Scene_Base; def return_scene; $returned = true; end; end
class Scene_MenuBase < Scene_Base; end
class Scene_Load < Scene_Base; end
class Window_Base; def initialize(*); end; end
class Window_Selectable < Window_Base; end
class Window_Command < Window_Selectable; end
class Window_NameEdit < Window_Base; end
class Window_NameInput < Window_Selectable; end
class Color; def initialize(*); end; end
class Sprite; def initialize(*); end; end
Rect = Struct.new(:x, :y, :width, :height)
class Scene_Title; def start; end; def create_command_window; end; def update; end; def terminate; end; end
class Window_TitleCommand; def make_command_list; end; end
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
module SceneManager; def self.call(scene); $called = scene; end; end
module DataManager
  def self.save_system; end
  def self.make_filename(index); format("Save/Save%02d.rvdata2", index + 1); end
end

# Stand-ins for the mod's base script and its DLL.
$sounds = []
$calls = []
$dll = {}
module MGQ_Multiplayer
  def self.available?; true; end
  def self.outdated?; false; end
  def self.clean(text); text; end
  module Log; def self.write(_message); end; end
  module Player; def self.share; end; def self.name; "Me"; end; end
  module Ini; def self.read(_path); {}; end; end
  def self.path(name); name; end
  module Link
    Function = Struct.new(:name, :signature) do
      def call(*args); check_dll_call(name, signature, args); $calls << [name, signature, args]; 1; end
    end
    def self.function(name, signature); Function.new(name, signature); end
    def self.read(name, _size); $dll[name].to_s; end
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| k, v = line.split("=", 2); state[k] = v if v }
      state
    end
  end
end

load_script "world_save_distribution"
load_script "ui"
load_script "ui_text_box"
load_script "world"
load_script "world_mods"
load_script "world_text"
load_script "world_screen"

$started = []
$start_error = nil
def MGQ_MpWorld.start(world, _scene); $started << world; $start_error; end

# A small window of the world screen: keeps the commands it opened with and whether it takes input.
class FakeChoice
  # The commands it opened with, nil while closed.
  attr_reader :choices

  # Whether it takes input.
  attr_reader :active

  # Opens with commands and takes input.
  #
  # @param choices [Array<Array>] The commands.
  def start(choices); @choices = choices; @active = true; end

  # Closes.
  def finish; @choices = nil; @active = false; end

  # Takes input.
  def activate; @active = true; end

  # Takes no input.
  def deactivate; @active = false; end

  # Takes the cursor off.
  def unselect; end

  # The cursor's row.
  #
  # @return [Integer] -1, no cursor.
  def index; -1; end
end

# The lines at the top of the world screen: keeps what they show.
class FakeInfo
  # What they show.
  attr_reader :lines

  # Shows lines.
  #
  # @param lines [Array<String, nil>] The lines.
  def show(lines); @lines = lines; end
end

# Builds the world screen without its windows, with stand-ins for those the start choice uses.
#
# @return [Scene_MpWorlds] The screen.
def new_scene
  scene = Scene_MpWorlds.allocate
  [:@actions_window, :@members_window, :@confirm_window, :@start_window, :@list_window, :@form_window].each { |name| scene.instance_variable_set(name, FakeChoice.new) }
  scene.instance_variable_set(:@info_window, FakeInfo.new)
  scene.instance_variable_set(:@forms, { :new_world => MGQ_MpWorld::Form.create })
  scene
end

# The commands a window opened with, by their symbols.
#
# @param scene [Scene_MpWorlds] The world screen.
# @return [Array<Symbol>, nil] The symbols, nil while it is closed.
def start_choices(scene)
  choices = scene.instance_variable_get(:@start_window).choices
  choices && choices.map { |choice| choice[1] }
end

# What the lines at the top of the world screen say, the player's name left out.
#
# @param scene [Scene_MpWorlds] The world screen.
# @return [String] The message.
def said(scene)
  scene.instance_variable_get(:@info_window).lines[1]
end

# The form.
form = MGQ_MpWorld::Form.create
choose = form.fields.find { |field| field.key == :choose }
check("the form has a Player's choice checkbox beside Shared save", [choose.kind, choose.row, choose.side, choose.label, choose.group], [:check, 3, :right, "Player's choice", "Starting point"])
check("Players choose starts unticked", form[:choose], false)
check("the button comes last", form.fields.last.row, 8)
check("a form with Players choose ticked alone can be sent", (form[:name] = "W"; form[:password] = "p"; form[:choose] = true; form.problem), nil)

# The directory.
$dll["mp_dir_list"] = "state=ready\n\nworld\tw1\t4\t0\tc\t0\tC\tFree\tnone\t0\t1\nworld\tw2\t4\t0\tc\t0\tC\tFixed\tready\t1\t0\nworld\tw3\t4\t0\tc\t0\tC\tOld\tnone\t0\n"
_, _, listed, = MGQ_MpWorld::Directory.list
check("the list reads which worlds let their players choose", listed.map { |world| world.choose }, [true, false, false])
MGQ_MpWorld::Directory.create("W", "p", 4, false, true, "")
check("create hands Players choose to the DLL", $calls.last[0..1] + [$calls.last[2][4]], ["mp_dir_create", "pplllpppplpp", 1])

# What the details say.
detail = Window_MpWorldDetail.allocate
listed_as = lambda { |start, choose| MGQ_MpWorld::Directory::ListedWorld.new("w", 4, 0, "c", 0, "C", "W", start, [], false, choose) }
check("details: choose with the creator's save", detail.start_text(listed_as.call("ready", true)), "Your choice: beginning, own or creator's save")
check("details: choose without one", detail.start_text(listed_as.call("none", true)), "Your choice: beginning or own save")
check("details: the creator's save only", detail.start_text(listed_as.call("ready", false)), "The creator's save")
check("details: the beginning for everyone", detail.start_text(listed_as.call("none", false)), "The beginning")
check("details: uploading comes first", detail.start_text(listed_as.call("pending", true)), "Its creator is still setting it up")

Dir.mktmpdir do |root|
  Dir.chdir(root) do
    FileUtils.mkdir_p("Save")
    my_save = Marshal.dump("my save")
    my_system = Marshal.dump("my system")
    File.binwrite("Save/Save03.rvdata2", my_save)
    File.binwrite("Save/SystemSave.rvdata2", my_system)
    world = MGQ_MpWorld::World.new("abcdef012345", "code" => "code", "name" => "Free")
    FileUtils.mkdir_p(world.folder)

    # A world made with Player's choice: it is left in the list as a favourite, and its creator is asked on entering it.
    favourites = []
    MGQ_MpWorld::Favourites.define_singleton_method(:add) { |id| favourites << id }
    MGQ_MpWorld::World.define_singleton_method(:found) { |*| $found }
    $found = world
    $dll["mp_dir_action"] = "state=done\nkind=create\ncode=code\nworld=w\n\n"
    scene = new_scene
    scene.instance_variable_set(:@form_symbol, :new_world)
    scene.instance_variable_get(:@forms)[:new_world].tap { |made| made[:name] = "Free"; made[:choose] = true }
    scene.instance_variable_set(:@busy, "create")
    scene.instance_variable_set(:@creating, "Free")
    scene.instance_variable_set(:@start_files, [])
    $calls.clear
    scene.follow_action
    check("making a world fetches the list again", $calls.map { |call| call[0] }.include?("mp_dir_refresh"), true)
    check("and empties the form, which no longer has the cursor", [scene.instance_variable_get(:@forms)[:new_world][:name], scene.form], ["", nil])
    check("marks the world as a favourite and says where to enter it", [favourites, said(scene), start_choices(scene)], [["w"], "Free was created. Enter it from the list.", nil])
    scene.enter(world, "none", true)
    check("entering it asks the creator where to start", start_choices(scene), [:from_beginning, :from_own, :cancel])

    # Asking a new player.
    scene = new_scene
    scene.instance_variable_get(:@list_window).activate
    scene.enter(world, "ready", true)
    check("a new player of a world with the creator's save gets three choices", start_choices(scene), [:from_creator, :from_beginning, :from_own, :cancel])
    check("the question names the world", said(scene).start_with?("Where do you start in Free?"), true)
    check("and only the choice takes input", [scene.instance_variable_get(:@list_window).active, scene.instance_variable_get(:@form_window).active], [false, false])

    scene = new_scene
    scene.enter(world, "none", true)
    check("without the creator's save, two", start_choices(scene), [:from_beginning, :from_own, :cancel])

    scene = new_scene
    scene.enter(world, "none", false)
    check("a world without the choice is entered at once", [start_choices(scene), $started.last], [nil, world])

    # A first entry without the listing.
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w", "Free", nil, world, false, false))
    scene.on_enter
    check("a first entry waits for the list", [$started.size, said(scene)], [1, "Free is not in the list right now. Try again once the list has loaded."])
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w", "Free", nil, world, false, true))
    scene.on_enter
    check("a world gone from the list says so", said(scene), "Free is no longer in the list: it was deleted, or you were removed.")

    # At the beginning.
    scene = new_scene
    scene.enter(world, "ready", true)
    scene.on_from_beginning
    check("At the beginning enters without fetching", [$started.size, scene.instance_variable_get(:@busy)], [2, nil])

    # From the creator's save.
    scene = new_scene
    scene.enter(world, "ready", true)
    scene.on_from_creator
    check("From the creator's save fetches it first", [scene.instance_variable_get(:@busy), $calls.last[0]], ["start", "mp_dir_fetch_start"])
    check("and closes the choice", start_choices(scene), nil)

    # From one of my saves, left without one.
    scene = new_scene
    scene.enter(world, "none", true)
    scene.on_from_own
    check("From one of my saves opens the save screen", $called, Scene_MpStartSave)
    check("which says what the save is for", Scene_MpStartSave.allocate.help_window_text, MGQ_MpSaveDistribution::HELP_TEXTS[:own])
    check("every text of the save screen fits its line of help, 48 characters at most", MGQ_MpSaveDistribution::HELP_TEXTS.values.select { |text| text.size > 48 }, [])
    scene.take_start_save
    check("leaving it without a save enters nothing", [scene.instance_variable_get(:@own_start), $started.size], [nil, 2])
    check("and asks again", start_choices(scene), [:from_beginning, :from_own, :cancel])
    scene.take_start_save
    check("the world screen starting again later asks nothing more", start_choices(scene), [:from_beginning, :from_own, :cancel])

    # From one of my saves, copied halfway.
    scene.on_from_own
    MGQ_MpSaveDistribution.chosen = 2
    scene.take_start_save
    File.rename("Save/SystemSave.rvdata2", "Save/Hidden.rvdata2")
    FileUtils.mkdir_p("Save/SystemSave.rvdata2")
    scene.start_from_own
    check("a copy that failed halfway leaves no save behind", [File.exist?("#{world.save_folder}/Save01.rvdata2"), said(scene)], [false, "Your save could not be copied into Free."])
    FileUtils.rmdir("Save/SystemSave.rvdata2")
    File.rename("Save/Hidden.rvdata2", "Save/SystemSave.rvdata2")

    # From one of my saves, which this game cannot load.
    scene.on_from_own
    MGQ_MpSaveDistribution.chosen = 2
    scene.take_start_save
    $start_error = "The latest save of Free could not be loaded."
    scene.start_from_own
    check("a save that cannot be loaded is thrown away", [File.exist?("#{world.save_folder}/Save01.rvdata2"), said(scene)], [false, $start_error])
    check("so the next entry asks again", MGQ_MpSaveDistribution.ask_start?(world, true), true)
    $start_error = nil

    # From one of my saves.
    scene = new_scene
    scene.enter(world, "none", true)
    scene.on_from_own
    MGQ_MpSaveDistribution.chosen = 2
    scene.take_start_save
    check("the picked save waits for the next frame", scene.instance_variable_get(:@own_start), 2)
    scene.start_from_own
    check("it becomes the world's first save", File.binread("#{world.save_folder}/Save01.rvdata2"), my_save)
    check("with the player's system save", File.binread("#{world.save_folder}/SystemSave.rvdata2"), my_system)
    check("and the world is entered", [$started.size, $started.last], [4, world])
    check("the player's own save stays", File.binread("Save/Save03.rvdata2"), my_save)
    check("once the world has a save, nobody is asked again", [MGQ_MpSaveDistribution.new_player?(world), MGQ_MpSaveDistribution.ask_start?(world, true)], [false, false])
    check("nothing is asked or fetched while the list does not tell", [MGQ_MpSaveDistribution.ask_start?(world, nil), MGQ_MpSaveDistribution.fetch?(world, nil)], [false, false])

    # A fetched creator's save the game cannot load.
    $start_error = "The latest save of Free could not be loaded."
    new_scene.start_world(world, true)
    check("a fetched save that cannot be loaded is thrown away too", File.exist?("#{world.save_folder}/Save01.rvdata2"), false)
    $start_error = nil

    # The creator's starting save still goes into the form.
    scene = new_scene
    MGQ_MpSaveDistribution.choose(:world)
    MGQ_MpSaveDistribution.chosen = 4
    scene.take_start_save
    check("a save picked for a new world goes into the form", scene.instance_variable_get(:@forms)[:new_world][:save], 4)
  end
end
