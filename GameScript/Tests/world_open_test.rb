#----------------------------------------------------------------
#  world_open_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Reached the update over the title's commands through the world screen's opening alone, the Mod Framework adding Multiplayer
#                            - Checked that the title's commands stay off while the update question is still coming
#      Paulinchen  2026-10-31: Typed through the Mod Framework's text box, reading the typing from $mgq_text_input
#                            - Checked that a gamepad's cancel leaves a form's text box
#                            - Expected the plainer texts the player reads
#      Paulinchen  2026-10-30: Checked that the Mod Framework's restart carries an invite taken during a game
#                            - Checked that a world enters the game only right before its save loads or its New Game starts
#                            - Checked that backing out of a world's New Game after entering starts the game again into the world screen
#                            - Checked that an outdated game asks the Mod Framework for the release to play
#                            - Stopped loading the deleted world_mods_parking.rbx
#                            - Kept one check of each squad and seats topic
#                            - Left the hints fitting their lines to world_data_test.rb
#      Paulinchen  2026-10-28: Checked that the title screen opens the world screen for an invite once
#                            - Checked that a later screen of the session reads the list on its first look
#      Paulinchen  2026-10-23: Took a world off this PC through the stand-in's own state
#                            - Checked the requests of the forms through the DLL's steps, whose decisions its tests cover
#                            - Checked that the screen plays the DLL's steps into a world, its password and a Discord invite, whose rules the DLL's tests cover
#                            - Took the entries, the details and the texts from the stand-ins of the world screen's model
#                            - Opened the world screen's forms through the DLL
#                            - Checked the worlds on this PC, the favourites and the invite through the DLL's topics, whose rules its tests cover
#                            - Typed through the stand-in text box
#                            - Answered the rules the DLL owns through the bridge from the golden cases
#                            - Dropped the update offer under Wine and expected --version for a step back by hand
#                            - Gave the stand-in world list every field the DLL writes
#      Paulinchen  2026-10-22: Checked the update offer of a step back to an older release
#      Paulinchen  2026-10-15: Expected the options of mp_dir_create in one number
#      Paulinchen  2026-10-14: Expected a Raid World's starting save in its details and its Save in every build
#      Paulinchen  2026-10-13: Checked a Classic world's raid bosses in the list, the details, world.ini and the open world
#                            - Checked a Raid World's squad rules in the list, the details, world.ini and the open world
#      Paulinchen  2026-10-12: Checked the title screen's Multiplayer command handler
#                            - Checked when the worlds take the mouse wheel
#                            - Checked the favourites in Player.ini and unreadable Player.ini and world.ini files
#      Paulinchen  2026-10-11: Checked the cursor on a new world, the hidden world's id, a blocked form and the Password row
#      Paulinchen  2026-10-10: Checked where a Raid World with a shared save starts and a save's label width
#                            - Checked that unlisted Raid Worlds come after the listed worlds
#      Paulinchen  2026-10-09: Expected Sharing companions left out of a Classic world's form and loaded world_mods_parking.rbx
#                            - Expected the longer call of mp_dir_create
#                            - Checked a Raid World's difficulty in the list, the details and world.ini
#      Paulinchen  2026-10-08: Checked Raid Worlds in the list, the details, world.ini and the form
#                            - Checked the update offer in place of the update notice
#                            - Checked that the update offer keeps the game open under Wine
#                            - Checked the update offer of an outdated game for invites and restarts
#      Paulinchen  2026-10-07: Checked that the local worlds and favourites are read once until one changes
#                            - Looked DLL signatures up in the export table of Multiplayer.rb
#                            - Checked that a form's switch turns round
#      Paulinchen  2026-10-06: Checked typed passwords, failed invite codes, full worlds and waiting invites
#                            - Refused a DLL call whose arguments differ from its signature
#                            - Checked a Discord invite into a world
#                            - Checked backing out of a world's new game
#                            - Loaded world_mods.rbx
#      Paulinchen  2026-10-04: Checked that an outdated game enters no world and is told so
#                            - Followed the scripts to their new names
#                            - Read the details from their panels
#                            - Expected a hidden world's id alone in the form that adds it
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#      Paulinchen  2026-10-02: Checked the seats a world code tells
#                            - Created
#
#----------------------------------------------------------------

# Checks finding and entering worlds (world.rbx, world_screen.rbx): worlds without a password,
# featured worlds and Raid Worlds in the list, the details and world.ini, the worlds and favourites
# kept on this PC, the forms and their switches, the cursor on a world just made or added, Discord
# invites, a world's new game, and an outdated game kept out and offered the update.

require_relative "support"
require_relative "rules_support"
require "tmpdir"

# Stands in for the game's scenes: returning notes $returned.
class Scene_Base; def return_scene; $returned = true; end; end
# Stands in for the game's menu scenes.
class Scene_MenuBase < Scene_Base; end
# Stands in for the load screen.
class Scene_Load < Scene_Base; end
# Stands in for the game's windows, which draw nothing.
class Window_Base; def initialize(*); end; end
# Stands in for a window with a cursor.
class Window_Selectable < Window_Base; end
# Stands in for a window of commands.
class Window_Command < Window_Selectable; end
# Stands in for the game's name box.
class Window_NameEdit < Window_Base; end
# Stands in for the game's letters to pick a name from.
class Window_NameInput < Window_Selectable; end
# Stands in for a colour.
class Color; def initialize(*); end; end
# Stands in for a sprite, which draws nothing.
class Sprite; def initialize(*); end; end
# A rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# Stands in for the title screen, whose steps do nothing.
class Scene_Title; def start; end; def create_command_window; end; def close_command_window; end; def update; end; def terminate; end; end
# Stands in for the sounds: each one played goes into $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end

# Stands in for the scene manager.
module SceneManager
  # Records the scene called in $called.
  def self.call(scene); $called = scene; end

  # Gives a scene that takes any preparation.
  def self.scene; Object.new.tap { |scene| def scene.prepare(*); end }; end
end

# Stands in for saving the system data, which saves nothing.
module DataManager; def self.save_system; end; end

# Stand-ins for the mod's base script and its DLL.
$sounds = []
$calls = []
$dll = {}
$outdated = false

# Stands in for the mod's base script: available, and outdated while $outdated.
module MGQ_Multiplayer
  # What an outdated game is told.
  UPDATE_MESSAGE = "Update."

  # Gives the update message, for a step back with the version to play, from $rollback.
  def self.update_message; $rollback ? "#{newer_version} is the version to play now." : UPDATE_MESSAGE; end

  # Answers that the mod is available.
  def self.available?; true; end

  # Answers whether the game is outdated, from $outdated.
  def self.outdated?; $outdated; end

  # Gives the newer version while the game is outdated.
  def self.newer_version; $outdated ? "9.9.9" : nil; end

  # Answers whether the version to install is a step back, from $rollback.
  def self.rollback?; $rollback == true; end

  # Gives the text as it is.
  def self.clean(text); text; end

  # Gives the path as it is.
  def self.path(name); name; end

  # Stands in for the log, which writes nothing.
  module Log; def self.write(_message); end; end

  # Stands in for Player.ini: its settings are in $player_ini, and it cannot be read while
  # $player_ini_unreadable.
  module Player
    # Shares nothing.
    def self.share; end

    # The player's name, Me.
    def self.name; "Me"; end

    # Reads a setting.
    def self.setting(key); ($player_ini ||= {})[key]; end

    # Lists the keys under a prefix, without it.
    def self.keys_under(prefix); ($player_ini ||= {}).keys.select { |key| key.start_with?(prefix) }.map { |key| key[prefix.size..-1] }; end

    # Answers whether Player.ini can be read.
    def self.readable?; !$player_ini_unreadable; end

    # Changes settings, unless Player.ini cannot be read.
    #
    # @param changes [Hash{String => String, nil}] The values by key, nil removing a key.
    # @return [Boolean] Whether they were changed.
    def self.change(changes)
      return false if $player_ini_unreadable

      changes.each { |key, value| ($player_ini ||= {}).delete(key); $player_ini[key] = value unless value.nil? }
      true
    end
  end

  # Stands in for the ini files, which read empty.
  module Ini; def self.read(_path); {}; end; def self.load(_path, _quiet = false); {}; end; end

  # Stands in for holding the buttons: the owner holding them is in $capture, the button pressed in
  # $pressed.
  module Mod_Framework::UI::Capture
    # Holds the buttons for an owner.
    def self.start(owner); $capture = owner; end

    # Gives the buttons back if the owner holds them.
    def self.stop(owner); $capture = nil if $capture == owner; end

    # Answers whether a button is pressed, from $pressed.
    def self.trigger?(button); $pressed == button; end

    # Answers whether a button repeats, as it is pressed.
    def self.repeat?(button); trigger?(button); end
  end

  # Stands in for the mouse, never clicked.
  module Mod_Framework::UI::Mouse; def self.clicked?; false; end; end

  # Stands in for the DLL: each call is checked against its signature and noted in $calls, and what
  # it reads is in $dll.
  module Link
    # A function of the DLL with its signature.
    Function = Struct.new(:name, :signature) do
      # Checks the call against the signature, notes it in $calls and answers 1, started.
      def call(*args); check_dll_call(name, args); $calls << [name, signature, args]; 1; end
    end

    # Gives the DLL function of a name, with its signature from Multiplayer.rb.
    def self.function(name); Function.new(name, dll_signature(name)); end

    # Reads an export's text from $dll.
    def self.read(name, _size); $dll[name].to_s; end

    # Splits a DLL answer into its header fields and its payload.
    #
    # @param text [String] The answer.
    # @return [Hash] The fields by name, the payload under :payload.
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
fake = open_rules_bridge

# A small window of the world screen: keeps the commands it opened with and whether it takes input.
class FakeChoice
  # Whether it takes input.
  attr_reader :active

  # Opens with commands and takes input.
  #
  # @param _choices [Array<Array>] The commands.
  def start(_choices); @active = true; end

  # Closes.
  def finish; @active = false; end

  # Takes input.
  def activate; @active = true; end

  # Takes no input.
  def deactivate; @active = false; end

  # The cursor's row.
  #
  # @return [Integer] -1, no cursor.
  def index; -1; end

  # The world asked for with select_world.
  attr_reader :asked

  # Keeps the world to put the cursor on.
  #
  # @param id [String] The world's directory id.
  def select_world(id); @asked = id; end

  # Takes the worlds shown, keeping none.
  #
  # @param _entries [Array<MGQ_MpWorld::Entry>] The worlds.
  def entries=(_entries); end
end

# The lines at the top of the world screen, which show nothing.
class FakeInfo
  # Shows nothing.
  #
  # @param _lines [Array<String, nil>] The lines.
  def show(_lines); end
end

# Builds the world screen without its windows.
#
# @return [Scene_MpWorlds] The screen.
def new_scene
  scene = Scene_MpWorlds.allocate
  [:@actions_window, :@members_window, :@confirm_window, :@start_window, :@list_window, :@form_window].each { |name| scene.instance_variable_set(name, FakeChoice.new) }
  scene.instance_variable_set(:@info_window, FakeInfo.new)
  scene
end

# The forms.
form = MGQ_MpWorld::WorldForm.create(:new_world)
form[:name] = "Open Fields"
check("a new world needs no password", form.problem, nil)
password = form.fields.find { |field| field.key == :password }
check("a password keeps its spaces", form.check(password, " a b "), [" a b ", nil])
join = MGQ_MpWorld::WorldForm.join(:join_hidden)
join[:id] = "a" * 32
check("a hidden world is added by its id alone", [join.problem, join.fields.map { |field| field.key }], [nil, [:id, :confirm]])
switch = MGQ_MpWorld::Form::Field.new(:way, :switch, "Way", 0, "Which way.", :choices => %w(Left Middle Right), :note => lambda { |_, index| "Picked #{index}" })
ways = MGQ_MpWorld::Form.new("Ways", [switch], :way => 0)
check("a switch turns round between its outcomes, with the line of the one picked", [ways.turn(switch, -1), switch.note_of(ways), ways.turn(switch, 1)], [2, "Picked 2", 0])

# The directory.
$dll["mp_dir_list"] = "state=ready\n\n" \
  "world\tw1\t4\t0\tc\t0\tC\tPlain\tnone\t0\t0\t0\t0\t\t\t\t\t\t\tclassic\toff\t\t0\t\t0\n" \
  "world\tw2\t4\t0\tc\t0\tGlobal\tGolden\tnone\t0\t0\t1\t1\t\t\t\t\t\t\tclassic\toff\t\t0\t\t0\n" \
  "world\tw3\t4\t0\tc\t0\tC\tOld\tnone\t0\t0\t\t\t\t\t\t\t\t\tclassic\toff\t\t0\t\t0\n"
_, _, listed, = MGQ_MpWorld::Directory.list
check("the list reads which worlds have no password", listed.map { |world| world.open }, [false, true, false])
check("and which are featured", listed.map { |world| world.featured }, [false, true, false])

# The worlds on this PC and their order come from the DLL (LocalWorldsTests, WorldEntriesTests);
# the script hands the list over and builds its entries from the answer.
$local_worlds.clear
$world_lists["favourite"] = ["w3"]
made = MGQ_MpWorld::World.found("mgqmp2;abcdefghjkmnpqrs;r1;4", "First", "w1")
check("a world made comes back with its folder and its seats", [made.name, made.directory_id, made.seats, MGQ_MpWorld::World.all.map { |world| world.id }], ["First", "w1", 4, [made.id]])
check("which go over as the DLL takes them", fake.calls.reverse.map { |topic, bytes| topic == "worlds.found" ? Marshal.load(bytes) : nil }.compact.first,
      { "name" => "First", "world" => "w1", "type" => nil, "share" => nil, "difficulty" => nil, "squad" => nil, "raid_bosses" => nil, "code" => "mgqmp2;abcdefghjkmnpqrs;r1;4" })
check("a world played is written, and takes the time", [made.played!, made.played_at.nil?], [true, false])
# The DLL deletes a world's saves (WorldEnteringTests); the world is gone from this PC again.
$local_worlds.delete(made.id)
FileUtils.rm_rf("#{MGQ_MpWorld::WORLDS_DIR}/#{made.id}")

# The list's order.
entries = screen_entries(listed, true)
check("favourites come first, then featured worlds", entries.map { |entry| entry.name }, ["Old", "Golden", "Plain"])
check("an entry tells whether it is featured or open", [entries[1].featured?, entries[1].open?, entries[2].featured?], [true, true, false])
gone = MGQ_MpWorld::Entry.new("w9", "Gone", nil, nil, false, true)
check("a world the directory no longer lists is neither", [gone.featured?, gone.open?], [false, false])

# Entering, whose steps the DLL decides (WorldEnteringTests); the screen plays them.
scene = new_scene
scene.instance_variable_set(:@entry, entries[1])
$called = nil
$screen_steps = [["busy", "unlock"]]
scene.on_enter
check("entering hands the DLL the world", screen_requests("screen.enter").last.values_at("id", "name", "gone"), ["w2", "Golden", false])
check("and a busy step holds the input while the DLL's action runs", [scene.instance_variable_get(:@busy), $called], ["unlock", nil])

# What typing in place needs.
module MGQ_Multiplayer
  # Stands in for the keyboard, with no key pressed.
  module Mod_Framework::UI::Key; def self.pressed?(_code); false; end; def self.triggered?(code); pressed?(code); end; end
end

# Stands in for the game's buttons, none pressed.
module Input; def self.trigger?(_button); false; end; def self.press?(_button); false; end; end

# The form window of the world screen: shows a form and keeps the field the cursor is on.
class FakeForm < FakeChoice
  # The form shown.
  attr_accessor :form

  # Picks a row.
  #
  # @param index [Integer] The row.
  def select(index); @row = index; end

  # The cursor's row.
  #
  # @return [Integer] The row picked last, the first before any.
  def index; @row || 0; end

  # The field the cursor is on.
  #
  # @return [MGQ_MpWorld::Form::Field] The field.
  def field; form.fields[index]; end

  # Takes the cursor off.
  def unselect; @row = nil; end

  # Draws nothing.
  def refresh; end

  # Draws nothing.
  def redraw_current_item; end
  # Scrolls nothing, as a box of one line.
  def wheel_lines; 0; end
end

# The text box types what $typed holds.
open_fake_ui { typed = $typed.to_s; $typed = nil; [typed, typed.size] }

# Builds the world screen with a form window and no forms yet.
#
# @return [Scene_MpWorlds] The screen.
def form_scene
  scene = new_scene
  scene.instance_variable_set(:@form_window, FakeForm.new)
  scene.instance_variable_set(:@forms, {})
  scene
end

scene = form_scene
scene.instance_variable_set(:@entry, entries[2])
$called = nil
$screen_steps = [["password", "Plain"]]
scene.on_enter
check("the password step asks for it in a form typed in place", [$called, scene.form.title, scene.form.editing, $mgq_text_input], [nil, "Enter Plain", :password, true])
$typed = "secret"
scene.update_typing
ui_frame
scene.update_typing
check("Enter hands the password to the DLL", [screen_requests("screen.answer").last, $mgq_text_input], [{ "answer" => "password", "text" => "secret" }, false])
$screen_steps = [["password", "Plain"]]
scene.on_enter
scene.stop_typing
scene.on_form_cancel
check("backing out of the password tells the DLL, which may end an entry after a restart", [screen_requests("screen.answer").last, scene.form], [{ "answer" => "password_back" }, nil])

# A details window that draws on nothing and keeps the texts it draws.
#
# @param width [Integer] The width of its contents.
# @param height [Integer] The height of its contents.
# @return [Array] The window and the texts drawn, which fill as it shows a world.
def new_detail(width, height)
  detail = Window_MpWorldDetail.allocate
  # The details' old methods, such as panels, are the prototype's, which the DLL's model follows.
  detail.define_singleton_method(:method_missing) { |name, *args| screen_detail.send(name, *args) }
  texts = []
  font = Struct.new(:size).new(24)
  canvas = Struct.new(:font).new(font)
  canvas.define_singleton_method(:clear) { texts.clear }
  canvas.define_singleton_method(:fill_rect) { |*| }
  detail.define_singleton_method(:contents) { canvas }
  detail.define_singleton_method(:contents_width) { width }
  detail.define_singleton_method(:contents_height) { height }
  detail.define_singleton_method(:change_color) { |*| }
  detail.define_singleton_method(:reset_font_settings) { font.size = 24 }
  detail.define_singleton_method(:text_size) { |text| Struct.new(:width).new(text.size * font.size / 2) }
  detail.define_singleton_method(:draw_text) { |*args| texts << args[4] }
  %w[system_color normal_color power_up_color crisis_color].each { |name| detail.define_singleton_method(name) { name } }
  [detail, texts]
end

# Finds a value of the details by its label.
#
# @param panels [Array<Window_MpWorldDetail::Panel>] The panels.
# @param label [String] The label.
# @return [Window_MpWorldDetail::Cell, nil] The cell.
def cell_of(panels, label)
  panels.map { |panel| panel.rows }.flatten.compact.find { |cell| cell.label == label }
end

# What the details say.
detail, texts = new_detail(386, 336)
panels = detail.panels(entries[1], "me")
check("a featured world says so beside its heading", [panels[0].title, panels[0].note], ["World", "featured"])
check("a world without a password needs none", cell_of(panels, "Password").text, "None")
check("made by the admin tool's player", cell_of(panels, "Creator").text, "Global")
check("a world of the player's own is made by them", cell_of(detail.panels(entries[1], "c"), "Creator").text, "You")
check("a world the directory no longer lists says only so", detail.panels(gone, "me").map { |panel| panel.rows.flatten.map { |cell| cell.text } }, [["Only on this PC: deleted, or you were removed"]])
detail.show(entries[1], "me")
check("the name is drawn with when it was played, then the headings in capitals", [texts[0, 2], texts.include?("WORLD"), texts.include?("PLAYERS"), texts.include?("DESCRIPTION")], [["not entered yet", "Golden"], true, true, true])
check("a world without a description says so at the bottom", texts.last, "No description.")

# The seats, which the world code tells.
check("a world's code tells its seats", local_world("abcdef012345", "code" => "mgqmp2;abcdefghjkmnpqrs;r1;8").seats, 8)

# Raid Worlds: the type and companion sharing the list reads, their place and colour, the details,
# world.ini, what every script asks of the open world, and the new world's form.
$dll["mp_dir_list"] = "state=ready\n\n" \
  "world\tr1\t4\t0\tc\t0\tC\tRaid Night\tnone\t0\t0\t0\t0\t0\t\t\t\t\t\traid\tstory\t1\t1\t1 6 2 1\t0\n" \
  "world\tr2\t4\t0\tc\t0\tGlobal\tRaid Gold\tnone\t0\t0\t1\t1\t0\t\t\t\t\t\traid\tall\t\t1\t\t0\n" \
  "world\tw1\t4\t0\tc\t0\tC\tPlain\tnone\t0\t0\t0\t0\t0\t\t\t\t\t\tclassic\toff\t3\t0\t0 4 1 1\t0\n" \
  "world\tw3\t4\t0\tc\t0\tC\tOld\tnone\t0\t0\t\t\t\t\t\t\t\t\tclassic\toff\t\t0\t\t0\n"
_, _, typed, = MGQ_MpWorld::Directory.list
check("the list reads each world's type and companion sharing",
      typed.map { |world| [world.type, world.share, world.raid?] }, [["raid", "story", true], ["raid", "all", true], ["classic", "off", false], ["classic", "off", false]])
check("and a Raid World's difficulty, none for one without it and for every Classic world", typed.map { |world| world.difficulty }, [1, nil, nil, nil])
check("and a Raid World's squad rules, none for one without them and for every Classic world", typed.map { |world| world.squad },
      [{ :luka => true, :formation => 6, :front => 2, :raid_front => 1 }, nil, nil, nil])
$local_worlds.clear
raid_entries = screen_entries(typed, true)
check("Raid Worlds come above every other world, favourites and featured ones too", raid_entries.map { |entry| entry.name }, ["Raid Gold", "Raid Night", "Old", "Plain"])
raid_local = local_world("abcdef012345", "code" => "x", "name" => "Kept", "type" => "raid", "share" => "story")
check("a Raid World the directory no longer lists stays one by its world.ini", [MGQ_MpWorld::Entry.new("r9", "Kept", nil, raid_local, false, true).raid?, gone.raid?], [true, false])
$local_worlds.clear
local_world("abcdef012345", "code" => "x", "name" => "Kept", "type" => "raid", "share" => "story", "world" => "r9")
check("but comes after every world the directory lists", screen_entries(typed, true).map { |entry| [entry.name, entry.gone] },
      [["Raid Gold", false], ["Raid Night", false], ["Old", false], ["Plain", false], ["Kept", true]])
$local_worlds.clear

# The colour of a row in the list and of the details' title.
list_window = Window_MpWorldList.allocate
colors = []
list_window.define_singleton_method(:item_rect_for_text) { |_index| Rect.new(0, 0, 200, 24) }
list_window.define_singleton_method(:change_color) { |color, _enabled = true| colors << color }
list_window.define_singleton_method(:draw_text) { |*| }
%w[normal_color crisis_color].each { |name| list_window.define_singleton_method(name) { name } }
list_window.instance_variable_set(:@list, raid_entries.map { |entry| { :ext => entry } })
(0...raid_entries.size).each { |index| list_window.draw_item(index) }
check("a Raid World's row is red, which wins over a featured one's gold and a favourite's colour",
      colors.map { |color| color.equal?(MGQ_MpWorld::RAID_COLOR) ? :red : color }, [:red, :red, "crisis_color", "normal_color"])
detail, = new_detail(386, 336)
title_colors = []
detail.define_singleton_method(:change_color) { |color, _enabled = true| title_colors << color }
detail.draw_title(MGQ_MpWorldScreen.details(raid_entries[0]))
check("and so is a Raid World's name above its details", title_colors.last.equal?(MGQ_MpWorld::RAID_COLOR), true)
check("whose cells may ask for the red too", detail.color_of(:raid).equal?(MGQ_MpWorld::RAID_COLOR), true)

# The details.
raid_panels = detail.panels(raid_entries[1], "me")
check("the details tell a Raid World and how it shares companions", [cell_of(raid_panels, "Type").text, cell_of(raid_panels, "Type").color, cell_of(raid_panels, "Sharing").text],
      ["Raid", :raid, "Story"])
check("or that it shares story companions and battle recruits", cell_of(detail.panels(raid_entries[0], "me"), "Sharing").text, "Story, recruits")
check("a Raid World's players start at the beginning, on the difficulty it sets", [cell_of(raid_panels, "Start").text, cell_of(raid_panels, "Difficulty").text], ["The beginning", "HARD"])
check("or each on their own in one that sets none", cell_of(detail.panels(raid_entries[0], "me"), "Difficulty").text, "Per player")
check("and a Classic world names no difficulty", cell_of(detail.panels(raid_entries[3], "me"), "Difficulty"), nil)
plain_panels = detail.panels(raid_entries[3], "me")
check("but a Classic world's World panel keeps its three rows, with no type row", [plain_panels[0].rows.size, cell_of(plain_panels, "Type"), raid_panels[0].rows.size], [3, nil, 6])
check("a Raid World's details tell its squad rules", ["Luka", "Formation", "Frontline"].map { |label| cell_of(raid_panels, label).text }, ["Replaceable", "6", "2 | 1  (regular | raids)"])
check("the defaults for one that names none", ["Luka", "Formation", "Frontline"].map { |label| cell_of(detail.panels(raid_entries[0], "me"), label).text }, ["Fixed", "4", "1 | 1  (regular | raids)"])
check("and a Classic world's none", ["Luka", "Formation", "Frontline"].map { |label| cell_of(plain_panels, label) }, [nil, nil, nil])
saved_raid = typed[0].dup
saved_raid.start = "ready"
check("a Raid World with a shared save starts from the creator's save", cell_of(detail.panels(MGQ_MpWorld::Entry.new("r1", "Raid Night", saved_raid, nil, false, false), "me"), "Start").text,
      "The creator's save")
saved_raid.start = "pending"
check("or tells that its creator is still setting it up", detail.raid_start_text(saved_raid), "Its creator is still setting it up")
saved_raid.start = "none"
check("and one without starts at the beginning", detail.raid_start_text(saved_raid), "The beginning")

# A world entered while the directory listed it hands its type, sharing, difficulty and squad rules
# to the DLL, which keeps them in world.ini (LocalWorldsTests).
raid_found = MGQ_MpWorld::World.found("mgqmp2;abcdefghjkmnpqrs;r1;4", "Raid Night", "r1", "raid", "story", -1, { :luka => true, :formation => 0, :front => 3, :raid_front => 4 })
check("a Raid World found goes over with its type, companion sharing, difficulty and squad rules",
      Marshal.load(fake.calls.reverse.find { |topic, _| topic == "worlds.found" }[1]).values_at("type", "share", "difficulty", "squad"),
      ["raid", "story", -1, { "luka" => true, "formation" => 0, "front" => 3, "raid_front" => 4 }])
check("and reads back as one", [raid_found.raid?, raid_found.companion_sharing, raid_found.difficulty, raid_found.squad],
      [true, :story, -1, { :luka => true, :formation => 0, :front => 3, :raid_front => 4 }])
raid_found.describe("Raid Night", "r1", 8, nil, nil, 3, { :luka => false, :formation => 7, :front => 1, :raid_front => 2 })
check("a difficulty, squad rules and seats the list tells on entry replace the ones kept", [raid_found.difficulty, raid_found.squad[:formation], raid_found.seats], [3, 7, 8])
$local_worlds.clear
check("a world.ini from before types is Classic", [local_world("abcdef012345", "code" => "x").raid?, local_world("abcdef012345", "code" => "x").type], [false, nil])

# What every script asks of the open world.
check("outside a world there is no Raid World and no sharing", [MGQ_MpWorld.raid?, MGQ_MpWorld.companion_sharing], [false, :off])
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "raid", "share" => "all"))
check("in a Raid World both tell it", [MGQ_MpWorld.raid?, MGQ_MpWorld.companion_sharing], [true, :all])
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "raid", "share" => "lots"))
check("a sharing this game does not know shares nothing", MGQ_MpWorld.companion_sharing, :off)
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "classic", "share" => "all"))
check("a Classic world is no Raid World and shares nothing", [MGQ_MpWorld.raid?, MGQ_MpWorld.companion_sharing], [false, :off])
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "classic", "difficulty" => "2"))
check("and sets no difficulty, whatever its world.ini says, nor takes one", [MGQ_MpWorld.difficulty, MGQ_MpWorld.take_difficulty(1), MGQ_MpWorld.world.difficulty], [nil, false, 2])
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "raid", "difficulty" => "2"))
check("a Raid World tells its difficulty", MGQ_MpWorld.difficulty, 2)
check("and takes a new one the relay tells, keeping it in world.ini", [MGQ_MpWorld.take_difficulty(-2), MGQ_MpWorld.difficulty, $local_worlds["abcdef012345"]["difficulty"]], [true, -2, -2])
check("but no value that is no difficulty", [MGQ_MpWorld.take_difficulty(5), MGQ_MpWorld.difficulty], [false, -2])
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "raid", "difficulty" => "hard"))
check("a world.ini's difficulty this game does not know is none", MGQ_MpWorld.difficulty, nil)
check("the difficulties carry the game's own names", [MGQ_MpWorld.difficulty_name(-2), MGQ_MpWorld.difficulty_name(0), MGQ_MpWorld.difficulty_name(4), MGQ_MpWorld.difficulty_name(nil)],
      ["VERY EASY", "NORMAL", "PARADOX", nil])
MGQ_MpWorld.instance_variable_set(:@world, nil)

# A Raid World's squad rules: read and written as text, and what every script asks of the open world.
check("squad rules read from their text", [MGQ_MpWorld.squad_of("0 4 1 1"), MGQ_MpWorld.squad_of("1 0 4 3"), MGQ_MpWorld.squad_of("1 8 2 2")],
      [{ :luka => false, :formation => 4, :front => 1, :raid_front => 1 }, { :luka => true, :formation => 0, :front => 4, :raid_front => 3 },
       { :luka => true, :formation => 8, :front => 2, :raid_front => 2 }])
check("and written back the same", ["0 4 1 1", "1 0 4 3", "1 8 2 2"].map { |text| MGQ_MpWorld.squad_text(MGQ_MpWorld.squad_of(text)) }, ["0 4 1 1", "1 0 4 3", "1 8 2 2"])
check("Formation sizes are named for texts", [MGQ_MpWorld.formation_name(0), MGQ_MpWorld.formation_name(4), MGQ_MpWorld.formation_name(8)], ["Original", "4", "8"])
check("outside a world there are no squad rules", MGQ_MpWorld.squad, nil)
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "classic", "squad" => "1 6 2 2"))
check("nor in a Classic world, whatever its world.ini says, which takes none", [MGQ_MpWorld.squad, MGQ_MpWorld.take_squad(MGQ_MpWorld.default_squad)], [nil, false])
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "raid"))
check("a Raid World that names none plays with the defaults", MGQ_MpWorld.squad, { :luka => false, :formation => 4, :front => 1, :raid_front => 1 })
MGQ_MpWorld.squad[:formation] = 8
check("which no caller changes", MGQ_MpWorld.default_squad[:formation], 4)
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "raid", "squad" => "1 6 2 3"))
check("a Raid World tells its squad rules", MGQ_MpWorld.squad, { :luka => true, :formation => 6, :front => 2, :raid_front => 3 })
check("and takes new ones the relay tells, keeping them in world.ini",
      [MGQ_MpWorld.take_squad(MGQ_MpWorld.squad_of("0 0 4 1")), MGQ_MpWorld.squad, $local_worlds["abcdef012345"]["squad"]],
      [true, { :luka => false, :formation => 0, :front => 4, :raid_front => 1 }, { "luka" => false, "formation" => 0, "front" => 4, "raid_front" => 1 }])
check("but none out of range, nor nothing", [MGQ_MpWorld.take_squad({ :luka => false, :formation => 3, :front => 1, :raid_front => 1 }), MGQ_MpWorld.take_squad(nil), MGQ_MpWorld.squad[:formation]],
      [false, false, 0])
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "raid", "squad" => "lots"))
check("a world.ini's squad rules this game cannot read are the defaults", MGQ_MpWorld.squad, MGQ_MpWorld.default_squad)
MGQ_MpWorld.instance_variable_set(:@world, nil)

# A Classic world's raid bosses: the list, the details, world.ini and what every script asks of the
# open world.
$dll["mp_dir_list"] = "state=ready\n\n" \
  "world\tw1\t4\t0\tc\t0\tC\tPlain\tnone\t0\t0\t0\t0\t0\t\t\t\t\t\tclassic\toff\t\t0\t\t1\n" \
  "world\tw2\t4\t0\tc\t0\tC\tCalm\tnone\t0\t0\t0\t0\t0\t\t\t\t\t\tclassic\toff\t\t0\t\t0\n" \
  "world\tr1\t4\t0\tc\t0\tC\tRaid Night\tnone\t0\t0\t0\t0\t0\t\t\t\t\t\traid\tstory\t1\t1\t1 6 2 1\t1\n" \
  "world\tw3\t4\t0\tc\t0\tC\tOld\tnone\t0\t0\t\t\t\t\t\t\t\t\tclassic\toff\t\t0\t\t0\n"
_, _, bossed, = MGQ_MpWorld::Directory.list
check("the list reads a Classic world's raid bosses, never a Raid World's, none for a world without them", bossed.map { |world| world.raid_bosses }, [true, false, false, false])
bossed_panels = detail.panels(MGQ_MpWorld::Entry.new("w1", "Plain", bossed[0], nil, false, false), "me")
check("the details of a Classic world with them add a row that says so", [cell_of(bossed_panels, "Raid Bosses").text, bossed_panels[0].rows.size], ["On: story bosses of their tier", 4])
check("but none for one without them nor for a Raid World", [bossed[1], bossed[2]].map { |world| cell_of(detail.panels(MGQ_MpWorld::Entry.new(world.id, world.name, world, nil, false, false), "me"), "Raid Bosses") },
      [nil, nil])
bossed_found = MGQ_MpWorld::World.found("mgqmp2;abcdefghjkmnpqrs;r1;4", "Plain", "w1", "classic", "off", nil, nil, true)
check("a Classic world found goes over with its raid bosses and reads back with them",
      [Marshal.load(fake.calls.reverse.find { |topic, _| topic == "worlds.found" }[1])["raid_bosses"], bossed_found.raid_bosses], [true, true])
bossed_found.describe("Plain", "w1", nil, nil, nil, nil, nil, false)
check("and goes without them once the list tells they are off", bossed_found.raid_bosses, false)
$local_worlds.clear
check("outside a world there are no raid bosses, nor any to take", [MGQ_MpWorld.raid_bosses?, MGQ_MpWorld.take_raid_bosses(true)], [false, false])
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "classic", "raid_bosses" => "1"))
check("a Classic world tells its raid bosses", MGQ_MpWorld.raid_bosses?, true)
check("and takes them off as the relay tells, keeping that in world.ini",
      [MGQ_MpWorld.take_raid_bosses(false), MGQ_MpWorld.raid_bosses?, $local_worlds["abcdef012345"]["raid_bosses"]], [true, false, false])
check("and on again", [MGQ_MpWorld.take_raid_bosses(true), MGQ_MpWorld.raid_bosses?, $local_worlds["abcdef012345"]["raid_bosses"]], [true, true, true])
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "code" => "x", "type" => "raid", "raid_bosses" => "1"))
check("a Raid World has none, whatever its world.ini says, and takes none", [MGQ_MpWorld.raid_bosses?, MGQ_MpWorld.take_raid_bosses(true)], [false, false])
MGQ_MpWorld.instance_variable_set(:@world, nil)

# The new world's form.
raid_form = MGQ_MpWorld::WorldForm.create(:new_world)
type_field = raid_form.fields.find { |field| field.key == :type }
check("the form has a World type switch beside Hidden, Classic at first", [type_field.kind, type_field.row, type_field.side, type_field.choices, raid_form.type], [:switch, 2, :right, ["Classic", "Raid"], "classic"])
check("and Sharing companions is left out of a Classic world", [raid_form.fields.any? { |field| field.key == :share }, raid_form.share], [false, "off"])
raid_form[:type] = 1
raid_form[:share] = 1
share_field = raid_form.fields.find { |field| field.key == :share }
check("a Raid World brings it back below the type", [share_field.kind, share_field.row, share_field.choices.size, raid_form.type, raid_form.share], [:switch, 3, 3, "raid", "story"])

# Turning the form's switches on the world screen.
scene = form_scene
scene.instance_variable_set(:@forms, { :new_world => MGQ_MpWorld::WorldForm.create(:new_world) })
scene.instance_variable_set(:@form_symbol, :new_world)
form_window = scene.instance_variable_get(:@form_window)
form_window.form = scene.form
form_window.select(scene.form.fields.index { |field| field.key == :type })
$sounds.clear
scene.on_field
check("confirm turns a switch", [scene.form.type, $sounds.last], ["raid", "cursor"])
form_window.select(scene.form.fields.index { |field| field.key == :share })
scene.turn_switch(-1)
check("and an arrow back turns it round", scene.form.share, "all")

# The form window's arrows and switches.
window = Window_MpWorldForm.allocate
window.instance_variable_set(:@form, MGQ_MpWorld::WorldForm.create(:new_world))
picked = [nil]
window.define_singleton_method(:field) { picked[0] }
turned = []
moved = []
window.on_turn = lambda { |step| turned << step }
window.define_singleton_method(:move_side) { |side| moved << side }
picked[0] = type_field
window.cursor_right
window.cursor_left
check("an arrow away from a switch's neighbour turns it, one toward it moves there", [turned, moved], [[1], [:left]])
picked[0] = MGQ_MpWorld::Form::Field.new(:greyed, :switch, "Greyed", 3, "", :choices => ["A", "B"], :needs => lambda { |_form| false })
$sounds.clear
window.cursor_right
check("a greyed-out switch buzzes", [turned, $sounds], [[1], ["buzzer"]])
picked[0] = share_field
window.form[:type] = 1
window.cursor_left
check("a switch across its row turns both ways", turned, [1, -1])
picked[0] = window.form.fields.find { |field| field.key == :password }
window.cursor_right
check("other fields move as before", moved, [:left, :right])

# A switch's label takes the field's width, else the window's, which a window of its own may widen.

# A form window of its own, whose switches' names are wider.
class WideForm < Window_MpWorldForm
  # Width of the switches' names.
  LABEL_WIDTH = 150
end

# Builds a form window that draws on nothing and keeps the label widths it draws.
#
# @param kind [Class] Window_MpWorldForm or a window of its own.
# @param form [MGQ_MpWorld::Form] The form.
# @return [Array] The window and the texts drawn with their widths.
def drawing_form(kind, form)
  window = kind.allocate
  window.instance_variable_set(:@form, form)
  drawn = []
  font = Struct.new(:size).new(24)
  canvas = Struct.new(:font).new(font)
  canvas.define_singleton_method(:fill_rect) { |*| }
  window.define_singleton_method(:contents) { canvas }
  window.define_singleton_method(:change_color) { |*| }
  window.define_singleton_method(:cut) { |text, _width| text }
  window.define_singleton_method(:draw_text) { |*args| drawn << [args[2], args[4]] }
  %w[system_color normal_color].each { |name| window.define_singleton_method(name) { name } }
  [window, drawn]
end
plain_window, plain_drawn = drawing_form(Window_MpWorldForm, raid_form)
plain_window.draw_switch(Rect.new(0, 0, 188, 21), type_field, true)
plain_window.draw_switch(Rect.new(0, 0, 380, 21), share_field, true)
check("the world type's label is narrower, Sharing companions takes the window's", [plain_drawn[0], plain_drawn[2]], [[70, "World type"], [84, "Sharing companions"]])
check("each shows its outcome between arrows", [plain_drawn[1][1], plain_drawn[3][1]], ["< Raid >", "< Story companions >"])
noted = MGQ_MpWorld::Form::Field.new(:way, :switch, "Way", 0, "Which way.", :choices => %w(Left Right), :note => lambda { |_, index| "Picked #{index}" })
wide_window, wide_drawn = drawing_form(WideForm, MGQ_MpWorld::Form.new("Ways", [noted], :way => 1))
wide_window.draw_switch(Rect.new(0, 0, 380, 37), noted, true)
check("a window of its own draws its names wider, and a switch's line below it", wide_drawn, [[150, "Way"], [380 - 150 - 8, "< Right >"], [376, "Picked 1"]])
check("which makes its row higher than a switch without one", [wide_window.height_of(noted), wide_window.height_of(type_field)], [21 + 16, 21])
saved_form = MGQ_MpWorld::WorldForm.create(:new_world)
saved_form[:type] = 1
save_window, save_drawn = drawing_form(Window_MpWorldForm, saved_form)
save_window.draw_box(Rect.new(0, 0, 188, 21), saved_form.fields.find { |field| field.key == :save }, true)
check("a Raid World draws its Save's label narrower, asking for a save while none is chosen", save_drawn, [[40, "Save"], [188 - 40 - 8, "Choose one of your saves"]])

# An outdated game.
$outdated = true
$calls.clear
check("an outdated game enters no world", [MGQ_MpWorld.start(local_world("abcdef012345", {}), new_scene), MGQ_MpWorld.open?, $calls], ["Update.", false, []])

# The update over the title's commands, which the Mod Framework offers and installs.

# The title's commands, which take input or not.
class TitleMenu
  # Whether they take input.
  attr_reader :active

  # Answers that they are not disposed.
  def disposed?; false; end

  # Takes input.
  def activate; @active = true; end

  # Takes no input.
  def deactivate; @active = false; end
end

# The Mod Framework's update, which keeps each question and its block in $required.
module Mod_Framework
  module Mods
    def self.require(name, version, options = {}, &done); $required << [name, version, options, done]; :asking; end
  end
end
# The action after the framework's restart that opens the world screen, and the way back to the
# title, which starts no game again until a test says so.
module MGQ_Multiplayer; module Stages; OPEN_ACTION = "multiplayer.open" unless const_defined?(:OPEN_ACTION); def self.restart_needed?; false; end; end; end
$required = []
title_scene = Scene_Title.new
title_scene.instance_variable_set(:@command_window, TitleMenu.new)
update = MGQ_MpWorld::Update
$called = nil
MGQ_MpWorld.open_world_screen(title_scene)
name, version, options, done = $required.last
check("picking Multiplayer asks the Mod Framework for the release to play in place of the world screen, holding the title's commands",
      [$called, name, version, options, update.asking?, title_scene.instance_variable_get(:@command_window).active],
      [nil, "mgq-online", "9.9.9", { :exact => false, :reason => MGQ_MpWorld::Update::REASON, :action => "multiplayer.open" }, true, false])
done.call(:declined)
check("declining gives the title's commands back", [update.asking?, title_scene.instance_variable_get(:@command_window).active], [false, true])
MGQ_MpWorld.open_world_screen(title_scene)
$required.last[3].call(:restarting)
check("an update that restarts the game leaves them waiting", title_scene.instance_variable_get(:@command_window).active, false)
$rollback = true
MGQ_MpWorld.open_world_screen(title_scene)
check("a step back the relay asks for is asked for as exactly that version", $required.last[2].values_at(:exact, :reason), [true, MGQ_MpWorld::Update::ROLLBACK_REASON])
$required.last[3].call(:declined)
check("and the world refusal says so too", MGQ_MpWorld.start(MGQ_MpWorld::World.allocate, nil), "9.9.9 is the version to play now.")
$rollback = false
# The Mod Framework waiting for the mod lists before it asks, its question opening a frame later.
module Mod_Framework
  module Mods
    def self.require(name, version, options = {}, &done); $required << [name, version, options, done]; :waiting; end
  end
end
title_scene.instance_variable_get(:@command_window).activate
asked = $required.size
answer = MGQ_MpWorld.open_world_screen(title_scene)
check("a question still coming leaves the title's commands off, the framework told not to give them back",
      [answer, update.asking?, title_scene.instance_variable_get(:@command_window).active], [:off, true, false])
check("and opening the world screen again meanwhile asks no second time", [MGQ_MpWorld.open_world_screen(title_scene), $required.size], [:off, asked + 1])
$required.last[3].call(:declined)
check("its answer gives them back", [update.asking?, title_scene.instance_variable_get(:@command_window).active], [false, true])
$outdated = false

# A world's new game that asks something first, such as a hero, and the player backing out of it.

# The title's commands, which take input or not.
class TitleCommands
  # Whether they take input.
  attr_reader :active

  # Answers that they are not disposed.
  def disposed?; false; end

  # Takes input.
  def activate; @active = true; end

  # Takes no input.
  def deactivate; @active = false; end
end

# A title screen whose New Game asks something first.
class Scene_Title
  # Asks something first, which takes the input off the commands.
  def command_new_game; @asked = true; @command_window.deactivate; end

  # Answers whether New Game asked.
  def asked?; @asked; end

  # Answers that the scene stays.
  def scene_changing?; false; end
end
asking = Scene_Title.new
asking.instance_variable_set(:@command_window, TitleCommands.new)
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", {}))
MGQ_MpWorld.instance_variable_set(:@pending, :new_game)
MGQ_MpWorld.on_title_update(asking)
MGQ_MpWorld.on_title_update(asking)
check("a new game that asks first keeps the world open while the question stands", [asking.asked?, MGQ_MpWorld.open?], [true, true])
asking.instance_variable_get(:@command_window).activate
MGQ_MpWorld.on_title_update(asking)
check("backing out to the title's commands leaves the world", MGQ_MpWorld.open?, false)
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", {}))
MGQ_MpWorld.instance_variable_set(:@pending, :new_game)
asking.instance_variable_get(:@command_window).deactivate
MGQ_MpWorld.on_title_update(asking)
MGQ_MpWorld.new_game_started
asking.instance_variable_get(:@command_window).activate
MGQ_MpWorld.on_title_update(asking)
check("a new game that started keeps the world", MGQ_MpWorld.open?, true)
MGQ_MpWorld.instance_variable_set(:@world, nil)

# A world entered under the Mod Framework, which restarts the game on every way back to the title
# once the player entered: the world enters only right before its save loads, or at the title right
# before its New Game, never before the world screen goes back to the title.
entered = []
module MGQ_Multiplayer; module Stages; end; end
MGQ_Multiplayer::Stages.define_singleton_method(:staged?) { true }
MGQ_Multiplayer::Stages.define_singleton_method(:enter) { |reason, only = nil| entered << [reason, only]; true }
leaving = new_scene
leaving.define_singleton_method(:return_scene) { $went_back = entered.empty? ? :title : :restart }
MGQ_MpWorld.singleton_class.send(:alias_method, :tested_enter, :enter)
MGQ_MpWorld.define_singleton_method(:enter) { |world| @world = world }
modded = MGQ_MpWorld::Directory::ListedWorld.new("w1", 4, 0, "creator", 0, "Creator", "Modded", "none", [], false, false, true, false, false, "", "", "", "", "")
fresh = local_world("abcdef012345", {})
fresh.define_singleton_method(:latest_save) { nil }
MGQ_MpWorldMods.note_session(modded)
MGQ_MpWorld.start(fresh, leaving)
check("a world without a save goes back to the title for its new game before it enters, so the title does not restart the game", [$went_back, entered], [:title, []])
starting = Scene_Title.new
starting.instance_variable_set(:@command_window, TitleCommands.new)
MGQ_MpWorld.on_title_update(starting)
check("the title enters the game for the world right before its New Game", [entered, starting.asked?], [[["the world Modded", nil]], true])
restarts = []
Mod_Framework::Mods.define_singleton_method(:restart) { |reason, action = nil, value = nil| restarts << [action, value]; :restarting }
MGQ_Multiplayer::Stages.define_singleton_method(:entered?) { true }
starting.instance_variable_get(:@command_window).activate
MGQ_MpWorld.on_title_update(starting)
check("backing out of that New Game's question leaves the world and starts the game again into the world screen, so none of its mods stays loaded",
      [MGQ_MpWorld.open?, restarts], [false, [["multiplayer.open", nil]]])
MGQ_Multiplayer::Stages.define_singleton_method(:entered?) { false }
MGQ_MpWorld.instance_variable_set(:@pending, nil)

entered.clear
saved = local_world("abcdef012345", {})
saved.define_singleton_method(:latest_save) { 2 }
loads = []
DataManager.define_singleton_method(:load_game) { |index| loads << [index, entered.size]; true }
# Finishes a load as the game's load screen does, which the world's load does too.
class Scene_Load; def on_load_success; end; end
MGQ_MpWorldMods.note_session(modded)
check("a world with a save enters the game right before the save loads",
      [MGQ_MpWorld.start(saved, leaving), loads, entered], [nil, [[2, 1]], [["the world Modded", nil]]])
MGQ_MpWorld.singleton_class.send(:alias_method, :enter, :tested_enter)
MGQ_MpWorld.instance_variable_set(:@world, nil)
MGQ_Multiplayer::Stages.define_singleton_method(:staged?) { false }

# A Discord invite into a world, which carries the world code.
$invite_world_id = "w3"
added = []
MGQ_MpWorld::Added.define_singleton_method(:add) { |id| added << id }
check("an invite that is no world code is left to PvP battles", MGQ_MpWorld::Invite.receive("mgqmp1;abcdefghjk;47625;203.0.113.7"), false)
MGQ_MpWorld.instance_variable_set(:@world, local_world("abcdef012345", "world" => "w3"))
check("an invite into the world already open is dropped", [MGQ_MpWorld::Invite.receive("mgqmp2;abcdefghjkmnpqrs;r1;4"), MGQ_Multiplayer::Bridge.call("worlds.invite_take")], [true, nil])
MGQ_MpWorld.instance_variable_set(:@world, nil)
check("an invite into a world is taken", MGQ_MpWorld::Invite.receive("mgqmp2;abcdefghjkmnpqrs;r1;4"), true)
$called = nil
MGQ_MpWorld.on_title_update(asking)
check("the title screen opens the world screen for it", $called, Scene_MpWorlds)
$called = nil
MGQ_MpWorld.on_title_update(asking)
check("and only once, since the screen takes the invite from the DLL", $called, nil)

# An invite taken during a game the Mod Framework entered, whose way back to the title starts the
# game again: the restart carries it to the title of the game that starts again.
module MGQ_Multiplayer; module Stages; INVITE_ACTION = "multiplayer.invite" unless const_defined?(:INVITE_ACTION); end; end
carried = []
Mod_Framework::Mods.define_singleton_method(:carry_after_restart) { |name, value = nil| carried << [name, value] }
MGQ_Multiplayer::Stages.define_singleton_method(:restart_needed?) { false }
MGQ_MpWorld::Invite.receive("mgqmp2;abcdefghjkmnpqrs;r1;4")
check("an invite taken where the way back to the title needs no restart waits for the title alone", carried, [])
MGQ_Multiplayer::Stages.define_singleton_method(:restart_needed?) { true }
MGQ_MpWorld::Invite.receive("mgqmp2;abcdefghjkmnpqrs;r1;4")
check("one taken in a game the framework entered goes with the restart the way back to the title makes",
      carried, [["multiplayer.invite", "mgqmp2;abcdefghjkmnpqrs;r1;4"]])
MGQ_Multiplayer::Stages.define_singleton_method(:restart_needed?) { false }
MGQ_MpWorld::Invite.drop

# The DLL takes the invite and enters the world once the list holds it (WorldEnteringTests).
invited = new_scene
invited.instance_variable_set(:@me, "me")
$screen_waiting = true
invited.open_steps
check("the world screen tells the DLL it opened, which takes the invite", screen_requests("screen.do").last.values_at("do", "rejoin", "me"), ["open", nil, "me"])
invited.instance_variable_get(:@actions_window).start([])
$screen_steps = [["entry", "w3"], ["busy", "unlock"]]
invited.look_for_entry(entries, "ready")
check("while it waits, the list goes to the DLL with whether the screen is free", screen_requests("screen.do").last.values_at("do", "state", "idle", "entries"),
      ["look", "ready", false, entries.map { |entry| [entry.id, entry.local && entry.local.id, entry.name, entry.gone ? true : false] }])
check("and the entry step points the screen at the invited world", [invited.instance_variable_get(:@entry).id, invited.instance_variable_get(:@busy)], ["w3", "unlock"])
$screen_waiting = false

# A later screen of the session reads the list on its first look although the list bit was taken
# before, so the DLL sees how the list stands and not an empty one it would drop the invite over.
MGQ_MpWorld::Changes.take?(MGQ_MpWorld::Changes::LIST)
later = new_scene
later.instance_variable_set(:@me, "me")
$screen_waiting = true
later.open_steps
MGQ_MpWorldScreen.open
later.look_at_list
check("a later screen reads the list on its first look, so the DLL sees how it stands",
      screen_requests("screen.do").last.values_at("do", "state", "entries").map { |value| value.is_a?(Array) ? value.map { |row| row[0] }.include?("w3") : value }, ["look", "ready", true])
$screen_waiting = false

# An outdated game offers the update on the title screen where it would open the world screen on
# its own: for a Discord invite, and to enter a world again after a restart for its mods.

$outdated = true
offering = Scene_Title.new
offering.instance_variable_set(:@command_window, TitleMenu.new)
offering.instance_variable_get(:@command_window).activate
MGQ_MpWorld::Invite.receive("mgqmp2;abcdefghjkmnpqrs;r1;4")
$called = nil
$required.clear
MGQ_MpWorld.on_title_update(offering)
check("an outdated game asks for the update for a Discord invite instead of opening the world screen, and drops the invite",
      [$called, $required.size, update.asking?, offering.instance_variable_get(:@command_window).active, MGQ_Multiplayer::Bridge.call("worlds.invite_take")],
      [nil, 1, true, false, nil])
$required.last[3].call(:declined)
check("declining it gives the title's commands back", [update.asking?, offering.instance_variable_get(:@command_window).active], [false, true])
MGQ_MpWorldMods.restarted_for("w1")
# The title screen stays.
class Scene_Title; def scene_changing?; false; end; end
MGQ_MpWorldMods.on_title_update(offering)
check("so does an outdated game started again to enter a world, which it then no longer enters on its own",
      [$called, $required.size, MGQ_MpWorldMods.rejoining, MGQ_MpWorldMods.take_rejoin], [nil, 2, nil, nil])
$required.last[3].call(:declined)
$outdated = false

# What the lines at the top say.
#
# @param scene [Scene_MpWorlds] The screen.
# @return [String] The message.
def said(scene)
  scene.instance_variable_get(:@message)
end

# The world just created gets the cursor, and the screen says to confirm to enter it, as the DLL's
# steps after the request tell it (WorldEnteringTests).
made = local_world("abcdef012345", "code" => "code", "name" => "Free")
scene = form_scene
scene.instance_variable_set(:@forms, { :new_world => MGQ_MpWorld::WorldForm.create(:new_world) })
scene.instance_variable_set(:@form_symbol, :new_world)
scene.instance_variable_set(:@busy, "create")
$screen_steps = [["idle"], ["place_start", { "id" => made.id, "name" => "Free", "code" => "code" }, [["Save01.rvdata2", "Save/Save01.rvdata2"]]]]
placed = []
place_was = MGQ_MpSaveDistribution.method(:place)
MGQ_MpSaveDistribution.define_singleton_method(:place) { |world, files| placed << [world.name, files]; true }
$screen_steps_after = [["fresh_form", "new_world"], ["close_form"], ["select", "w7"], ["say", "Free was created. #{MGQ_MpWorldScreen.text("enter_hint")}"], ["back"]]
scene.play(MGQ_Multiplayer::Bridge.call("screen.step"))
check("the starting save is copied in as the steps say, and the DLL told so", [placed, screen_requests("screen.answer").last.values_at("answer", "ok")],
      [[["Free", [["Save01.rvdata2", "Save/Save01.rvdata2"]]]], ["placed", true]])
MGQ_MpSaveDistribution.define_singleton_method(:place, place_was)
scene.play("steps" => $screen_steps_after)
check("a world created is the one the list puts the cursor on, and the screen says to confirm to enter it",
      [scene.instance_variable_get(:@list_window).asked, said(scene), scene.form, scene.instance_variable_get(:@busy)], ["w7", "Free was created. #{MGQ_MpWorldScreen.text("enter_hint")}", nil, nil])
check("the hint says to confirm to enter it, as the guide does", MGQ_MpWorldScreen.text("enter_hint"), "Confirm to enter it.")

# The pane moves the cursor onto the world asked for once the list shows it.

# A window of the left side of the world screen: keeps its rows, its cursor and whether it takes input.
class PaneList
  # The cursor's row, whether it takes input, whether it is picked as a whole, and its pane.
  attr_accessor :index, :active, :boxed, :pane
  # The rows, each [symbol, ext].
  attr_reader :rows

  # Creates the window with its rows, each [symbol, ext], the cursor on the first.
  #
  # @param rows [Array<Array>] The rows.
  def initialize(rows); @rows = rows; @index = 0; @active = true; end

  # The number of rows.
  def item_max; @rows.size; end

  # Puts the cursor on a row.
  def select(index); @index = index; end

  # Takes the cursor off.
  def unselect; @index = -1; end

  # Takes input.
  def activate; @active = true; end

  # Takes no input.
  def deactivate; @active = false; end

  # The window's width.
  def width; 230; end

  # The window's height.
  def height; 100; end

  # The symbol of the cursor's row, nil without a cursor.
  def current_symbol; @index >= 0 && @rows[@index] ? @rows[@index][0] : nil; end

  # The ext of the cursor's row, nil without a cursor.
  def current_ext; @index >= 0 && @rows[@index] ? @rows[@index][1] : nil; end

  # Puts the cursor on the row of a symbol.
  def select_symbol(symbol); @index = @rows.index { |row| row[0] == symbol }; end

  # Shows worlds as its rows, keeping a cursor within them.
  def entries=(entries); @rows = entries.map { |entry| [:world, entry] }; @index = [@index, @rows.size - 1].min if @index >= 0; end

  # Takes a handler, keeping none.
  def set_handler(_symbol, _method); end
end

# A world the list shows, known by its id.
Shown = Struct.new(:id)
worlds = PaneList.new([])
commands = PaneList.new([[:new_world, nil], [:join_hidden, nil], [:back, nil]])
pane = MpWorldListPane.new(worlds, commands)
pane.entries = [Shown.new("w1"), Shown.new("w2")]
pane.pick(:commands)
pane.enter
commands.select(1)
pane.select_world("w7")
pane.entries = [Shown.new("w1"), Shown.new("w2")]
check("a world asked for that the list does not show yet leaves the cursor on the command", [pane.inside?, pane.current_symbol, commands.index], [true, :join_hidden, 1])
pane.entries = [Shown.new("w1"), Shown.new("w7"), Shown.new("w2")]
check("once the list shows it, the cursor is on it inside the worlds, which take the input", [pane.inside?, pane.current_ext, worlds.index, worlds.active, commands.active, commands.index], [true, Shown.new("w7"), 1, true, false, -1])
worlds.deactivate
pane.back_out
pane.select_world("w1")
pane.entries = [Shown.new("w7"), Shown.new("w1")]
check("a pane picking between its windows moves into the worlds too", [pane.inside?, pane.current_ext, worlds.active], [true, Shown.new("w1"), true])
worlds.deactivate
pane.back_out
pane.pick(:commands)
pane.enter
commands.select(0)
pane.select_world("w2")
pane.deactivate
pane.entries = [Shown.new("w2"), Shown.new("w7")]
check("but not once the player moved on to a form, which takes the input", [pane.inside?, pane.current_symbol, commands.index], [true, :new_world, 0])
pane.activate
pane.entries = [Shown.new("w2"), Shown.new("w7")]
check("and the ask is over then", pane.current_symbol, :new_world)

# The worlds take the mouse wheel while they have the cursor, or have none while the pane takes the
# input, never behind a form or a box.
list = Window_MpWorldList.allocate
state = { :active => false, :index => -1 }
list.define_singleton_method(:active) { state[:active] }
list.define_singleton_method(:index) { state[:index] }
list.pane = pane
taking = [pane.active, list.takes_wheel?]
pane.deactivate
behind = list.takes_wheel?
state[:active] = true
state[:index] = 0
check("the worlds without a cursor scroll while the pane takes the input, not behind a form, and always with the cursor",
      [worlds.pane.equal?(pane), taking, behind, list.takes_wheel?, Window_MpWorldList.include?(MGQ_MpScrollingWindow)], [true, [true, true], false, true, true])
pane.activate

# The ask is logged, a world asked for before and not shown yet named as the one giving way.
logged = []
write_was = MGQ_Multiplayer::Log.method(:write)
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
pane.select_world("w1")
pane.select_world("w2")
MGQ_Multiplayer::Log.define_singleton_method(:write, write_was)
check("the ask is logged, and a world asked for before gives way", [logged.map { |line| line[/the cursor goes onto .*/] }, pane.instance_variable_get(:@select)],
      [["the cursor goes onto world w1 once the list shows it", "the cursor goes onto world w2 once the list shows it, instead of world w1"], "w2"])
pane.entries = [Shown.new("w2"), Shown.new("w7")]
check("until the list shows the one asked for last", [pane.current_ext, pane.instance_variable_get(:@select)], [Shown.new("w2"), nil])

# Enter in the hidden world's id sends the form, as in the password form.
scene = form_scene
scene.instance_variable_set(:@forms, { :join_hidden => MGQ_MpWorld::WorldForm.join(:join_hidden) })
scene.instance_variable_set(:@form_symbol, :join_hidden)
form_window = scene.instance_variable_get(:@form_window)
form_window.form = scene.form
form_window.select(0)
scene.start_typing(scene.form.fields.first)
$calls.clear
$typed = "#{'ab' * 16}\r"
$screen_steps = [["busy", "find"]]
scene.update_typing
ui_frame
scene.update_typing
check("Enter in the world id has the DLL look the world up", [scene.sends_on_enter?, screen_requests("screen.do").last["do"], scene.instance_variable_get(:@busy), $mgq_text_input], [true, "find", "find", false])
check("and the action holds the form's cursor, so its button cannot send it again meanwhile", [scene.instance_variable_get(:@resume_form), form_window.active], [false, false])
scene.instance_variable_set(:@busy, nil)
two = MGQ_MpWorld::Form.new("Two", [
  MGQ_MpWorld::Form::Field.new(:first, :text, "First", 0, "One.", :max_chars => 10),
  MGQ_MpWorld::Form::Field.new(:second, :text, "Second", 1, "Two.", :max_chars => 10),
  MGQ_MpWorld::Form::Field.new(:confirm, :button, "Send", 2, "Sends."),
], :first => "", :second => "")
scene.instance_variable_set(:@forms, { :password => two })
scene.instance_variable_set(:@form_symbol, :password)
form_window.form = two
form_window.select(0)
scene.start_typing(two.fields.first)
$calls.clear
$typed = "x\r"
scene.update_typing
ui_frame
scene.update_typing
check("a form with two text boxes keeps the text with Enter and is sent from its button", [scene.sends_on_enter?, two[:first], two.editing, $calls, scene.instance_variable_get(:@busy)], [false, "x", nil, [], nil])

# A gamepad's cancel leaves a text box, as the keyboard's does, and opens no letters screen.
form_window.select(0)
scene.start_typing(two.fields.first)
scene.update_typing
$called = nil
$pressed = :B
Input.define_singleton_method(:trigger?) { |button| $pressed == button }
scene.update_typing
Input.define_singleton_method(:trigger?) { |_button| false }
$pressed = nil
check("a gamepad's cancel leaves a form's text box with its text as it was, no letters screen opened", [two.editing, two[:first], $called, $mgq_text_input], [nil, "x", nil, false])
scene.instance_variable_set(:@forms, {})
check("without a form Enter sends nothing", scene.sends_on_enter?, false)

# The details say Known once this PC's folder holds the world code, which entering reads.
plain = entries[2]
held = local_world("abcdef012345", "code" => "x", "name" => "Plain")
known = MGQ_MpWorld::Entry.new("w1", "Plain", plain.listed, held, false, false)
check("a world's password is known with its folder on this PC, which holds the world code, not without", [known.password_known?, plain.password_known?], [true, false])
detail, = new_detail(386, 336)
check("the details say so", [cell_of(detail.panels(known, "me"), "Password").text, cell_of(detail.panels(plain, "me"), "Password").text], ["Known", "Needed"])
open_known = MGQ_MpWorld::Entry.new("w2", "Golden", entries[1].listed, held, false, false)
check("while a world without a password needs none, entered or not", cell_of(detail.panels(open_known, "me"), "Password").text, "None")
