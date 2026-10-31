#----------------------------------------------------------------
#  start_choice_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Dropped the stand-in of the title screen's commands, which no script hooks any more
#      Paulinchen  2026-10-31: Loaded ui_online.rbx and ui_boxes.rbx in place of the scripts the Mod Framework took over
#      Paulinchen  2026-10-30: Stopped loading the deleted world_mods_parking.rbx
#      Paulinchen  2026-10-23: Checked that a new world goes to the DLL and that the screen plays the steps it answers
#                            - Checked that the screen plays the DLL's steps of where to start and hands back the player's choice
#                            - Read the details and the texts through the stand-ins of the world screen's model
#                            - Opened the world screen's forms through the DLL
#                            - Made the worlds on this PC through the stand-ins of the DLL's topics
#                            - Answered the rules the DLL owns through the bridge from the golden cases
#      Paulinchen  2026-10-15: Expected the options of mp_dir_create in one number
#      Paulinchen  2026-10-13: Expected the longer call of mp_dir_create, with the raid bosses, and the rows of the squad rules' button
#      Paulinchen  2026-10-12: Expected the warning before a new player takes the creator's starting save
#                            - Stood in for Ini.load and the favourites in Player.ini
#      Paulinchen  2026-10-11: Expected the created world's name with the confirm hint and the cursor on it
#      Paulinchen  2026-10-09: Expected the longer call of mp_dir_create
#                            - Expected Player's choice beside Sharing companions and Turn off other mods, and loaded world_mods_parking.rbx
#      Paulinchen  2026-10-08: Expected Player's choice below Sharing companions and the longer call of mp_dir_create
#      Paulinchen  2026-10-07: Looked DLL signatures up in the export table of Multiplayer.rb
#                            - Checked that every save screen text fits its help line
#      Paulinchen  2026-10-06: Refused a DLL call whose arguments differ from its signature
#                            - Expected the longer calls of mp_dir_create and mp_dir_edit
#                            - Loaded world_mods.rbx
#      Paulinchen  2026-10-04: Followed the scripts to their new names
#                            - Expected the button below the new form rows and the longer call of mp_dir_create
#                            - Expected the shorter texts of the details' Start row
#                            - Expected a new world kept as a favourite and its creator asked where to start
#                            - Gave the base script stand-in its settings files
#                            - Expected Player's choice beside Shared save
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Checks where a new player of a world starts (world.rbx, world_save_distribution.rbx): the
# creator's Players choose checkbox, the directory's flag for it, and the world screen asking a
# new player to start at the beginning, from their own save or from the creator's.

require_relative "support"
require_relative "rules_support"
require "fileutils"
require "tmpdir"

# Stand-ins for the game.

# The game's scene base: returning to the last scene sets $returned.
class Scene_Base; def return_scene; $returned = true; end; end
# The game's base of menu scenes.
class Scene_MenuBase < Scene_Base; end
# The game's load screen.
class Scene_Load < Scene_Base; end
# The game's window base, which draws nothing.
class Window_Base; def initialize(*); end; end
# The game's window with a cursor.
class Window_Selectable < Window_Base; end
# The game's command window.
class Window_Command < Window_Selectable; end
# The game's name box of its text screen.
class Window_NameEdit < Window_Base; end
# The game's letter table of its text screen.
class Window_NameInput < Window_Selectable; end
# The game's color, which keeps nothing.
class Color; def initialize(*); end; end
# The game's sprite, which draws nothing.
class Sprite; def initialize(*); end; end
# The game's rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# The game's title screen, which does nothing.
class Scene_Title; def start; end; def create_command_window; end; def update; end; def terminate; end; end
# The game's system sounds: each one played is added to $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
# The game's scene manager: the scene called is recorded in $called.
module SceneManager; def self.call(scene); $called = scene; end; end
# The game's data manager, as far as its save files.
module DataManager
  # Saves nothing.
  def self.save_system; end
  # The file of a slot, named as the game names it.
  def self.make_filename(index); format("Save/Save%02d.rvdata2", index + 1); end
end

# Stand-ins for the mod's base script and its DLL.
$sounds = []
$calls = []
$dll = {}
# The mod's base script: always available, never outdated, with a player named Me and an empty
# world.ini.
module MGQ_Multiplayer
  # The DLL is always there.
  def self.available?; true; end
  # The game is never outdated.
  def self.outdated?; false; end
  # Leaves a text as it is.
  def self.clean(text); text; end
  # A log that writes nothing.
  module Log; def self.write(_message); end; end
  # The player Me, without favourites.
  module Player; def self.share; end; def self.name; "Me"; end; def self.keys_under(_prefix); []; end; end
  # An ini file reader that reads every file as empty.
  module Ini; def self.read(_path); {}; end; def self.load(_path, _quiet = false); {}; end; end
  # Leaves a path as it is.
  def self.path(name); name; end
  # The link to the DLL: records each call in $calls and reads its values from $dll.
  module Link
    # A DLL function: a call is checked against its signature, recorded and answered with 1.
    Function = Struct.new(:name, :signature) do
      # Checks a call's arguments against the signature, records the call in $calls and answers 1.
      def call(*args); check_dll_call(name, args); $calls << [name, signature, args]; 1; end
    end
    # A DLL function with its signature from the export table of Multiplayer.rb.
    def self.function(name); Function.new(name, dll_signature(name)); end
    # The DLL's value of a name, from $dll.
    def self.read(name, _size); $dll[name].to_s; end
    # Reads a DLL answer: its name=value lines up to a blank line, and the rest as :payload.
    #
    # @param text [String] The answer.
    # @return [Hash] The values by name, and the payload under :payload.
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| k, v = line.split("=", 2); state[k] = v if v }
      state
    end
  end
end

load_script "world_save_distribution"
load_script "ui_online"
load_script "ui_boxes"
load_script "world"
load_script "world_mods"
load_script "world_text"
load_script "world_screen"
open_rules_bridge

$started = []
$start_error = nil
# Records the world started in $started and answers $start_error.
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

  # Tells whether it is open.
  #
  # @return [Boolean] Whether it has commands.
  def open?; !@choices.nil?; end

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

  # Keeps the world to put the cursor on.
  #
  # @param _id [String] The world's directory id.
  def select_world(_id); end
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
  scene.instance_variable_set(:@forms, { :new_world => MGQ_MpWorld::WorldForm.create(:new_world) })
  scene
end

# The commands the start window opened with, by their symbols.
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
form = MGQ_MpWorld::WorldForm.create(:new_world)
choose = form.fields.find { |field| field.key == :choose }
check("the form has a Player's choice checkbox beside Shared save", [choose.kind, choose.row, choose.side, choose.label, choose.group], [:check, 3, :right, "Player's choice", "World"])
check("Players choose starts unticked", form[:choose], false)
check("the button comes last", form.fields.last.row, 10)
check("a form with Players choose ticked alone can be sent", (form[:name] = "W"; form[:password] = "p"; form[:choose] = true; form.problem), nil)

# The directory.
$dll["mp_dir_list"] = "state=ready\n\nworld\tw1\t4\t0\tc\t0\tC\tFree\tnone\t0\t1\nworld\tw2\t4\t0\tc\t0\tC\tFixed\tready\t1\t0\nworld\tw3\t4\t0\tc\t0\tC\tOld\tnone\t0\n"
_, _, listed, = MGQ_MpWorld::Directory.list
check("the list reads which worlds let their players choose", listed.map { |world| world.choose }, [true, false, false])

# What the details say.
detail = screen_detail
# A listed world with a starting save's state and whether its players choose.
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
    world = local_world("abcdef012345", "code" => "code", "name" => "Free")
    FileUtils.mkdir_p(world.folder)

    # A world made with Player's choice: the DLL makes it from the form, and its steps empty the
    # form, leave it and say where to enter it (WorldEnteringTests); its creator is asked on
    # entering it.
    scene = new_scene
    scene.instance_variable_set(:@form_symbol, :new_world)
    scene.instance_variable_get(:@forms)[:new_world].tap { |made| made[:name] = "Free"; made[:choose] = true }
    $screen_steps = [["busy", "create"]]
    scene.send_form
    check("sending the form has the DLL make the world, with no starting save to copy", screen_requests("screen.do").last.values_at("do", "start"), ["create", []])
    scene.play("steps" => [["idle"], ["fresh_form", "new_world"], ["close_form"], ["select", "w"], ["say", "Free was created. #{MGQ_MpWorldScreen.text("enter_hint")}"], ["back"]])
    check("once made, the form is empty and no longer has the cursor", [scene.instance_variable_get(:@forms)[:new_world][:name], scene.form], ["", nil])
    check("and the screen says where to enter it", [said(scene), start_choices(scene)], ["Free was created. #{MGQ_MpWorldScreen.text("enter_hint")}", nil])
    # Where to start, which the DLL's steps decide (WorldEnteringTests); the screen plays them.
    where = [["say", "Where do you start in Free? A save cannot be undone."],
             ["choices", [["From the creator's save", "from_creator"], ["At the beginning", "from_beginning"], ["From one of my saves", "from_own"], ["Back", "cancel"]]]]
    scene = new_scene
    scene.instance_variable_get(:@list_window).activate
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w", "Free", nil, world, false, false))
    scene.instance_variable_set(:@me, "me")
    $screen_steps = where
    scene.on_enter
    check("entering hands the DLL the world, its folder, the player and the game data",
          screen_requests("screen.enter").last.values_at("id", "folder", "name", "gone", "me"), ["w", world.id, "Free", false, "me"])
    check("and shows the choices the steps name", start_choices(scene), [:from_creator, :from_beginning, :from_own, :cancel])
    check("with the question they say", said(scene), "Where do you start in Free? A save cannot be undone.")
    check("and only the choice takes input", [scene.instance_variable_get(:@list_window).active, scene.instance_variable_get(:@form_window).active], [false, false])

    scene.on_from_beginning
    check("a choice goes back to the DLL as the answer", [screen_requests("screen.answer").last["answer"], start_choices(scene)], ["from_beginning", nil])
    $screen_steps = where
    scene.on_enter
    scene.on_from_creator
    scene.on_take_start
    check("the creator's save and Take go back too", screen_requests("screen.answer").last(2).map { |request| request["answer"] }, ["from_creator", "take_start"])
    $screen_steps = where
    scene.on_enter
    scene.on_back
    check("Back out of the choice goes back to the DLL", screen_requests("screen.answer").last["answer"], "back")

    # The steps of the running action.
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w", "Free", nil, world, false, false))
    $screen_steps = [["busy", "start"]]
    scene.on_enter
    check("a step holds the input while the DLL's action runs", [scene.instance_variable_get(:@busy), said(scene)], ["start", MGQ_MpWorldScreen.busy_text("start")])
    MGQ_MpWorld::Changes.note(MGQ_MpWorld::Changes::SCREEN)
    $screen_steps = [["idle"], ["back"]]
    scene.follow_steps
    check("and the step that ends it lets go of it", [screen_requests("screen.step").size, scene.instance_variable_get(:@busy)], [1, nil])
    scene.follow_steps
    check("the action is followed again only once the DLL tells of a change", screen_requests("screen.step").size, 1)

    # From one of my saves.
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w", "Free", nil, world, false, false))
    $screen_steps = [["save_screen"]]
    scene.on_from_own
    check("From one of my saves opens the save screen", $called, Scene_MpStartSave)
    check("which says what the save is for", Scene_MpStartSave.allocate.help_window_text, MGQ_MpSaveDistribution::HELP_TEXTS[:own])
    check("every text of the save screen fits its line of help, 48 characters at most", MGQ_MpSaveDistribution::HELP_TEXTS.values.select { |text| text.size > 48 }, [])
    scene.take_start_save
    check("leaving it without a save tells the DLL, which asks again", screen_requests("screen.answer").last, { "answer" => "own_save", "index" => nil })
    MGQ_MpSaveDistribution.choose(:own)
    MGQ_MpSaveDistribution.chosen = 2
    $screen_steps = [["copy_own", $local_worlds[world.id], 2]]
    scene.take_start_save
    check("a save picked tells the DLL which", screen_requests("screen.answer").last, { "answer" => "own_save", "index" => 2 })
    check("and the copy waits for the next frame", scene.instance_variable_get(:@own_start)[1], 2)
    $screen_steps = [["start", $local_worlds[world.id], true, false, true]]
    scene.start_from_own
    check("the save becomes the world's first save", File.binread("#{world.save_folder}/Save01.rvdata2"), my_save)
    check("with the player's system save", File.binread("#{world.save_folder}/SystemSave.rvdata2"), my_system)
    check("the DLL is told the copy worked", screen_requests("screen.answer").last, { "answer" => "own_copied", "ok" => true })
    check("and its start step enters the world", $started.last.id, world.id)
    check("the player's own save stays", File.binread("Save/Save03.rvdata2"), my_save)

    # A start that fails.
    $start_error = "The latest save of Free could not be loaded."
    $screen_steps = [["start", $local_worlds[world.id], true, false, true]]
    scene.on_enter
    check("a start that fails tells the DLL why, and whether its save was just placed",
          screen_requests("screen.answer").last, { "answer" => "start_failed", "text" => $start_error, "placed" => true })
    $start_error = nil
    $screen_steps = [["discard", $local_worlds[world.id]], ["buzz"], ["say", "Could not."], ["back"]]
    scene.on_enter
    check("the discard step throws the placed save away", File.exist?("#{world.save_folder}/Save01.rvdata2"), false)

    # The creator's starting save still goes into the form.
    scene = new_scene
    MGQ_MpSaveDistribution.choose(:world)
    MGQ_MpSaveDistribution.chosen = 4
    scene.take_start_save
    check("a save picked for a new world goes into the form", scene.instance_variable_get(:@forms)[:new_world][:save], 4)
  end
end
