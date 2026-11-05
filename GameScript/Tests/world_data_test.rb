#----------------------------------------------------------------
#  world_data_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Checked that a fingerprint the DLL did not answer is measured again
#                            - Read the directory's list and the player's id through the DLL's topics
#      Paulinchen  2026-11-01: Checked only the mods of a world as the DLL orders them, whose required and essential readers are gone
#                            - Dropped the checks that read the old screen prototype instead of the scripts
#                            - Dropped the checks of the form window no screen draws with any more
#                            - Named the Mod Framework's interface by its own name
#                            - Dropped the stand-in of the title screen's commands, which no script hooks any more
#                            - Stopped loading the deleted ui_boxes.rbx
#                            - Checked a world's players, mods and description and the mod picker in the list box of the Mod Framework's components
#                            - Dropped the stand-ins of the name box and letters of the deleted text screen
#                            - Checked the forms, the list box, the mod picker and the text boxes on the world screen built on the Mod Framework's components
#                            - Left the drawing of the old windows and the left side to world_screen_test.rb, and stopped loading the deleted world_text.rbx
#      Paulinchen  2026-10-31: Typed through the Mod Framework's text box, reading the typing from $mgq_text_input
#      Paulinchen  2026-10-30: Checked that the measure once the world's mods loaded leaves the title's fingerprint
#                            - Expected the forms and the details without the game data's fields and comparison
#                            - Stopped loading the deleted world_mods_parking.rbx
#                            - Checked that the fingerprint counts an entry by its note, features and effects, whatever its name
#                            - Checked the hints of the Raid World form and its formation limits with every other form's
#                            - Kept one check of each seats and mods topic
#      Paulinchen  2026-10-23: Checked that the forms' requests go to the DLL and that the screen plays the steps it answers
#                            - Left the data check and the mods read on entering to the DLL's tests and checked the steps the screen plays
#                            - Took the entries, the details and the list box's lines from the stand-ins of the world screen's model
#                            - Checked the details hand the DLL the shared settings and show what it says
#                            - Opened the world screen's forms through the DLL
#                            - Checked that the mod picker shows the DLL's answers, whose rules its tests cover
#                            - Widened the list box through Player.ini
#                            - Drew a box being typed into from what C# shows, the editor's own checks gone to C#
#                            - Answered the mod keys and the scripts in Patch through the bridge
#                            - Gave the stand-in world list every field the DLL writes
#      Paulinchen  2026-10-22: Checked a world read before entering while the list lacks its mods, and the mods measured against the relay's limit
#      Paulinchen  2026-10-15: Expected the options of mp_dir_create in one number
#      Paulinchen  2026-10-14: Expected a Raid World's Shared save and Save in the new world's form
#      Paulinchen  2026-10-13: Checked GameData.ini, written once per session as the title screen opens
#                            - Checked a Classic world's raid bosses in the forms, the calls and the edit's message
#                            - Checked a Raid World's squad rules in the forms, their fit, the calls and the edit's message
#                            - Checked opening the form of the squad rules and going back from it
#      Paulinchen  2026-10-12: Checked the description broken over several lines on the text screen
#                            - Checked the list box and a typed description scrolled with the mouse wheel
#                            - Stood in for Ini.load
#      Paulinchen  2026-10-11: Checked a description in the list box broken anew once wider and loaded ui_layout.rbx
#                            - Read the list box's rows from its lazy rectangle and gave the screen its size
#                            - Expected the added world's name with the confirm hint and the cursor on it
#      Paulinchen  2026-10-10: Expected the Raid World form of releases and development builds
#                            - Checked that a refused or failed data update enters nothing after a later update
#      Paulinchen  2026-10-09: Expected Sharing companions and Turn off other mods in the Raid World forms and loaded world_mods_parking.rbx
#                            - Checked that the edit forms' hints fit two lines
#                            - Expected the Difficulty switch in a new Raid World's form and its difficulty kept
#                            - Checked the difficulty sent when editing a Raid World
#      Paulinchen  2026-10-08: Expected the starting point in the World panel of the new world's form
#                            - Checked that a new world goes to the DLL as Classic or as a Raid World
#                            - Covered Shared Mod Settings in the forms and the details
#                            - Expected the mods of a world's options in the details and the edit form
#                            - Read cancel past the capture
#      Paulinchen  2026-10-07: Expected cut texts to end in three dots
#                            - Looked DLL signatures up in the export table of Multiplayer.rb
#      Paulinchen  2026-10-06: Checked names, Max Players, tidied form values and the mod picker's clicks
#                            - Expected mp_dir_edit with its signature's arguments and refused differing DLL calls
#                            - Checked an empty player name and each text box's own empty reason
#                            - Removed the check of missing_mods
#                            - Expected Allow data mismatch unticked in a new world's form
#                            - Checked that an added mod stays when unlisted and goes with Delete
#                            - Checked typing a mod's name in place in the picker
#                            - Checked that cancel closes the mod picker without drawing it again
#                            - Checked the mod picker
#                            - Expected mp_dir_edit without the mod settings
#                            - Expected the longer calls of mp_dir_create and mp_dir_edit
#                            - Loaded world_mods.rbx
#      Paulinchen  2026-10-04: Checked picking the worlds or the commands as a whole, and a long word broken inside it
#                            - Checked that a long word is broken without String#chars
#                            - Created
#
#----------------------------------------------------------------

# Checks what a creator tells about a world and which games may enter it (world.rbx,
# world_screen.rbx): the fingerprint of a game's data, the form's description, mods and rule,
# the directory's fields for them, a differing game kept out or asked first, what the details
# say, the list box, the text boxes and the mod picker.

require "zlib"
require "fileutils"
require "tmpdir"

require_relative "support"
require_relative "rules_support"

# Stand-ins for the game.

# The game's scene base: returning to the last scene sets $returned.
class Scene_Base; def start; end; def update; end; def terminate; end; def scene_changing?; false; end; def return_scene; $returned = true; end; end
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
# The game's input: the buttons in $buttons are pressed this frame, those in $held are held.
module Input; def self.trigger?(button); ($buttons || []).include?(button); end; def self.repeat?(button); trigger?(button); end; def self.press?(button); ($held || []).include?(button); end; end
# The game's scene manager: records the scene called and hands out a scene that takes any preparation.
module SceneManager
  # Records the scene called in $called.
  def self.call(scene); $called = scene; end
  # A scene that takes any preparation.
  def self.scene; Object.new.tap { |scene| def scene.prepare(*); end }; end
end
# The game's data manager, which saves nothing.
module DataManager; def self.save_system; end; end

# Stand-ins for the mod's base script and its DLL.
$sounds = []
$calls = []
# The mod's base script: always available, never outdated, with a player named Me and an empty
# world.ini.
module MGQ_Multiplayer
  # The DLL is always there.
  def self.available?; true; end
  # The game is never outdated.
  def self.outdated?; false; end
  # Leaves a text as it is.
  def self.clean(text); text; end
  # Leaves a path as it is.
  def self.path(name); name; end
  # A log that writes nothing.
  module Log; def self.write(_message); end; end
  # The player Me, without settings.
  module Player; def self.share; end; def self.name; "Me"; end; def self.setting(_key); nil; end; end
  # An ini file reader that reads every file as empty.
  module Ini; def self.read(_path); {}; end; def self.load(_path, _quiet = false); {}; end; end
  # Stands in for the player's id, as the DLL tells it.
  module Player; def self.id; "me"; end; end
end


require_relative "world_screen_support"
load_script "world_save_distribution"
load_script "ui_online"
load_script "world"
load_script "world_mods"
load_script "world_screen"
open_rules_bridge
open_fake_ui { typed = $typed.to_s; $typed = nil; [typed, typed.size] }

# Opens the world screen.
#
# @return [Scene_MpWorlds] The screen.
def new_scene
  world_scene
end

# An entry of the game's database: its name, its note and the features its file holds.
class DataEntry
  attr_reader :name, :note

  # Creates the entry.
  #
  # @param name [String] Its name.
  # @param note [String] Its note.
  # @param features [Array] The features its file holds.
  def initialize(name, note = "", features = [])
    @name = name
    @note = note
    @features = features
  end
end

# A skill or an item of the game's database, which holds effects too.
class DataUsable < DataEntry
  # Creates the entry.
  #
  # @param name [String] Its name.
  # @param note [String] Its note.
  # @param features [Array] The features its file holds.
  # @param effects [Array] The effects its file holds.
  def initialize(name, note = "", features = [], effects = [])
    super(name, note, features)
    @effects = effects
  end

  # Stands in for the game's reader, which adds the note's effects and fails before the game
  # analysed the entry.
  def effects
    raise NoMethodError, "the game never analysed this entry"
  end
end

# A troop of the game's database.
Troop = Struct.new(:members)

# A common event of the game's database.
Common = Struct.new(:list)

# The game's map lists: the main one and one per further map folder.
class MapInfos
  # Creates the lists.
  #
  # @param lists [Array<Hash>] The maps of each folder, by id.
  def initialize(lists); @data = lists; end
end

# Sets up a small database, which the fingerprint is read from anew.
#
# @param skills [Array<DataUsable>] The skills by id from 1.
# @param maps [Array<Integer>] The main folder's maps' ids.
# @param more_maps [Array<Integer>] The second folder's maps' ids.
def game_data(skills, maps, more_maps = [1])
  entries = lambda { |names| [nil] + names.map { |name| DataEntry.new(name, "<#{name}>") } }
  $data_actors = entries.call(%w[Luka Alice])
  $data_classes = entries.call(%w[Hero])
  $data_skills = [nil] + skills
  $data_items = entries.call(%w[Herb])
  $data_weapons = entries.call(%w[Sword])
  $data_armors = entries.call(%w[Shirt])
  $data_enemies = entries.call(%w[Slime])
  $data_states = entries.call(%w[Death])
  $data_troops = [nil, Troop.new([1]), Troop.new([])]
  $data_common_events = [nil, Common.new([1, 2]), Common.new([0])]
  lists = [maps, more_maps].map { |ids| Hash[ids.map { |id| [id, true] }] }
  $data_mapinfos = MapInfos.new(lists)
  MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)
end

# The fingerprint.
game_data([DataUsable.new("Slash", "<power 2>"), DataUsable.new(""), DataUsable.new("Fire", "", [], [:damage])], [2, 1])
plain = MGQ_MpWorld::GameData.fingerprint
check("the fingerprint names its format and a checksum per part", plain =~ /\A2:[0-9a-f]{8}(\.[0-9a-f]{8}){10}\z/ ? true : false, true)
check("a game matches itself", MGQ_MpWorld::GameData.differing(plain), [])
measuring = $world_bridge.instance_variable_get(:@handlers)["worlds.fingerprint"]
$world_bridge.answer("worlds.fingerprint") { nil }
MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)
silent = MGQ_MpWorld::GameData.fingerprint
$world_bridge.answer("worlds.fingerprint", &measuring)
check("a fingerprint the DLL did not answer is measured again at the next ask", [silent, MGQ_MpWorld::GameData.fingerprint], ["", plain])
game_data([DataUsable.new("Schlag", "<power 2>"), DataUsable.new("Leer", " \r\n"), DataUsable.new("Feuer", "", [], [:damage])], [1, 2])
check("a translated game matches the untranslated one, even where it names an empty place", MGQ_MpWorld::GameData.differing(plain), [])
game_data([DataUsable.new("Slash", "<power 2>"), DataUsable.new("Mod Skill", "", [:feature]), DataUsable.new("Fire", "", [], [:damage])], [1, 2, 488])
check("a mod's new skill and map are told apart, by what the skill holds", MGQ_MpWorld::GameData.differing(plain), ["skills", "maps"])
game_data([DataUsable.new("Slash", "<power 2>"), DataUsable.new(""), DataUsable.new("Fire", "", [], [:damage])], [1, 2], [1, 5])
check("so is a map in a further map folder", MGQ_MpWorld::GameData.differing(plain), ["maps"])
check("whose maps count on from a thousand", MGQ_MpWorld::GameData.map_ids, [1, 2, 1001, 1005])
game_data([DataUsable.new("Slash", "<power 2>"), DataUsable.new("Mod Skill", "", [:feature]), DataUsable.new("Fire", "", [], [:damage])], [1, 2, 488])
check("a world without game data is not compared", [MGQ_MpWorld::GameData.differing(""), MGQ_MpWorld::GameData.differing(nil)], [nil, nil])
check("nor one of another format", MGQ_MpWorld::GameData.differing(plain.sub("2:", "1:")), nil)
check("nor a damaged one", MGQ_MpWorld::GameData.differing("1:abc"), nil)
check("or past as many as asked", MGQ_MpWorld::GameData.text(%w[actors classes skills items], 2), "actors, classes and 2 more")
check("many parts are counted past the first four", MGQ_MpWorld::GameData.text(%w[actors classes skills items weapons armors]), "actors, classes, skills, items and 2 more")
check("few are all named", MGQ_MpWorld::GameData.text(%w[skills maps]), "skills, maps")
modded = MGQ_MpWorld::GameData.fingerprint

# The measure once a world's mods loaded, which the battle server, measuring without them, never takes.
$data_items << DataEntry.new("Mod Potion", "<Mod Potion>")
entered = MGQ_MpWorld::GameData.measure_entered
check("a world's mod that adds an item shows in the measure taken once the world's mods loaded", MGQ_MpWorld::GameData.differing(entered), ["items"])
check("while the fingerprint the DLL keeps and served battles carry stays the title's, so the server still hosts them",
      [MGQ_MpWorld::GameData.fingerprint, $game_fingerprint], [modded, modded])
$data_items.pop

# GameData.ini, which the title screen writes once per session for the World Admin tool.
written = []
MGQ_Multiplayer::Ini.define_singleton_method(:write) { |path, values| written << [path, values]; true }
first = Time.now.to_i
Scene_Title.new.start
check("the title screen writes the fingerprint and when to GameData.ini in the mod folder",
      [written.map { |path, values| [path, values.keys, values["fingerprint"]] }, written.map { |_path, values| values["written"].between?(first, Time.now.to_i) }],
      [[[MGQ_Multiplayer::MOD_DIR + "\\GameData.ini", ["fingerprint", "written"], modded]], [true]])
Scene_Title.new.start
check("once per session", written.size, 1)
MGQ_MpWorld::GameData.instance_variable_set(:@written, nil)
MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)
readable_maps = $data_mapinfos
$data_mapinfos = nil
lines = logged_lines { MGQ_MpWorld::GameData.write_file }
check("a game whose data cannot be read writes nothing and logs why",
      [written.size, lines.any? { |line| line.include?("reading the game data failed") }], [1, true])
$data_mapinfos = readable_maps
MGQ_MpWorld::GameData.instance_variable_set(:@written, nil)
MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)
MGQ_Multiplayer::Ini.define_singleton_method(:write) { |_path, _values| raise IOError, "disk full" }
raised = nil
begin
  lines = logged_lines { MGQ_MpWorld::GameData.write_file }
rescue => e
  raised = e
end
check("a write that fails raises nothing and only logs, naming the file and the error",
      [raised, lines.any? { |line| line.include?("writing #{MGQ_MpWorld::GameData::FILE} failed: IOError: disk full") }], [nil, true])
MGQ_Multiplayer::Ini.singleton_class.send(:remove_method, :write)
MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)

# The form.
form = MGQ_MpWorld::WorldForm.create(:new_world)
form[:name] = "Modded Run"
check("a new world needs no description and no mods", [form.problem, form[:description], form[:mods]], [nil, "", ""])
description = form.fields.find { |field| field.key == :description }
check("the description is a box of several lines in a panel of its own", [description.kind, description.lines, description.group, description.max_chars], [:area, 4, "Description", 1000])
check("the mods and Shared Mod Settings share the Game data panel", [:mods, :shared].map { |key| field = form.fields.find { |candidate| candidate.key == key }; [field.kind, field.label, field.group] }, [[:mods, "Mods", "Game data"], [:check, "Shared Mod Settings", "Game data"]])
check("the world type and the starting point share the World panel", form.fields.select { |field| field.group == "World" }.map { |field| field.label },
      ["Name", "Password", "Max Players", "Hidden", "World type", "Shared save", "Player's choice", "Save", "Raid Bosses"])
form[:type] = 1
check("a Raid World has Sharing companions in place of Player's choice, Shared save beside the Difficulty, and its Save beside the button of its squad rules",
      form.fields.select { |field| field.group == "World" }.map { |field| field.label },
      ["Name", "Password", "Max Players", "Hidden", "World type", "Sharing companions", "Shared save", "Difficulty", "Save", "Set formation limits"])
check("its Save's row comes off its description, so the form keeps its height",
      [form.fields.find { |field| field.key == :description }.lines, form.fields.map { |field| field.row }.max], [2, 10])
form[:type] = 0
check("a description is tidied", form.check(description, "  A slow run.  "), ["A slow run.", nil])
check("and may be empty", form.check(description, "  "), ["", nil])
$called = nil
check("while a name may not", form.check(form.fields[0], " ")[1], "The world needs a name.")
rename = MGQ_MpWorld::WorldForm.rename(:rename, "")
# Discord, which tells the player's name from $discord_name.
module MGQ_Multiplayer; module Discord; def self.player_name; $discord_name; end; end; end
# Player.ini, whose settings come from $player_ini.
module MGQ_Multiplayer::Player; DISCORD_NAME = "discord_name"; def self.setting(key); ($player_ini || {})[key]; end; end
$discord_name = nil
check("an empty name of the player is refused while Discord never told theirs", rename.check(rename.fields[0], " ")[1], "Type a name: Discord has not told yours yet.")
$discord_name = "Discord Me"
check("and taken while Discord tells it, which it then stands for", rename.check(rename.fields[0], " "), ["", nil])
$discord_name = nil
$player_ini = { "discord_name" => "Earlier Me" }
check("or told it in an earlier session", rename.check(rename.fields[0], ""), ["", nil])
$player_ini = nil

# A new world: the DLL builds the request from the form it holds and says what came of it
# (WorldEnteringTests), the screen hands it the starting save's files.
scene = new_scene
scene.enter_form(:new_world)
strict_form = scene.form
strict_form[:name] = "W"
$screen_steps = [["busy", "create"]]
scene.create_world
check("making a world has the DLL make it, with no files without a shared save", [screen_requests("screen.do").last.values_at("do", "start"), scene.busy], [["create", []], "create"])
shared_field = strict_form.fields.find { |field| field.key == :shared }
check("Shared Mod Settings has its row to itself, unticked, and says what it does to players, with no checkbox of the game data beside it",
      [shared_field.kind, shared_field.label, shared_field.group, shared_field.side, strict_form.fields.any? { |field| field.key == :mismatch }, MGQ_MpWorld::WorldForm.create(:new_world)[:shared], shared_field.hint],
      [:check, "Shared Mod Settings", "Game data", nil, false, false, "Ticked: every player plays with your mod options here. Unticked: each keeps their own."])
scene = new_scene
scene.enter_form(:new_world)
ui = Mod_Framework::UI
ui::Tree.focus(form_part(scene, :confirm))
$screen_steps = [["buzz"], ["say", "The request could not be started. Try again in a moment."], ["resume_form"]]
scene.create_world
check("a world the DLL refuses leaves the form open at the field it was sent from, with why", [said(scene), scene.form.nil?, $focused.id, scene.busy],
      ["The request could not be started. Try again in a moment.", false, "form:confirm", nil])
$directory = directory_list([
  listed_value("w1", "Strict", "open" => true, "strict" => true, "data" => plain, "mods" => "No mods", "description" => "Unmodded only."),
  listed_value("w2", "Loose", "open" => true, "data" => plain, "mods" => "Some Mod", "description" => "A slow run through part one of the story with friends."),
  listed_value("w3", "Same", "open" => true, "strict" => true, "data" => modded),
  listed_value("w4", "Old", "open" => true)])
_, _, listed, = MGQ_MpWorld::Directory.list
check("the list reads which worlds take the same data only", listed.map { |world| world.strict }, [true, false, true, false])
check("their creators' game data", listed.map { |world| world.data }, [plain, plain, modded, ""])
check("the mods they need and their descriptions", [listed[1].mods, listed[0].description, listed[3].mods, listed[3].description], ["Some Mod", "Unmodded only.", "", ""])
$local_worlds.clear
$world_lists["favourite"] = []
entries = screen_entries(listed, true).sort_by { |entry| entry.id }
check("an entry tells what differs", entries.map { |entry| entry.differing }, [["skills", "maps"], ["skills", "maps"], [], nil])

# Adding a hidden world by its id.
added = []
MGQ_MpWorld::Added.define_singleton_method(:all) { added }
MGQ_MpWorld::Added.define_singleton_method(:add) { |id| added << id }
MGQ_MpWorld::Added.define_singleton_method(:remove) { |id| added.delete(id) }
scene = new_scene
scene.enter_form(:join_hidden)
scene.form[:id] = "ab" * 16
$screen_steps = [["busy", "find"]]
scene.send_form
check("the form has the DLL look the world up by its id", [screen_requests("screen.do").last["do"], scene.busy], ["find", "find"])
scene.play("steps" => [["idle"], ["fresh_form", "join_hidden"], ["close_form"], ["select", "ab" * 16], ["say", "Hidden Base was added to your list. #{MGQ_MpWorldScreen.text("enter_hint")}"], ["back"]])
check("a world found is added, the form empty again and closed", [said(scene), scene.form, scene.instance_variable_get(:@forms)[:join_hidden][:id]],
      ["Hidden Base was added to your list. #{MGQ_MpWorldScreen.text("enter_hint")}", nil, ""])
# The DLL keeps the world found among those added (WorldLists).
added << "ab" * 16

# Taking an added world off the list again.
hidden_entry = screen_entry(MGQ_MpWorld::Entry.new("ab" * 16, "Hidden Base", listed[0], nil, false, false))
actions = lambda do |entry|
  screen = new_scene
  screen.on_world(entry)
  offered = MGQ_MpWorldScreen.actions(entry)
  shown = menu_texts == offered.map { |label, _symbol| label }
  [screen, offered.map { |_label, symbol| symbol }, shown]
end
scene, offered_actions, shown = actions.call(hidden_entry)
check("an added world never entered may be removed from the list, as its menu shows", [offered_actions.include?(:forget), shown], [true, true])
$screen_steps = [["say", "Hidden Base was removed from your list."], ["back"]]
pick_menu(scene, offered_actions.index(:forget))
check("removing it has the DLL forget its id, and says what the DLL tells", [screen_requests("screen.do").last.values_at("do", "id"), said(scene)], [["forget", "ab" * 16], "Hidden Base was removed from your list."])
check("another world may not", actions.call(entries[1])[1].include?(:forget), false)
cancel_menu(scene)

# Input past the capture: buttons held in $held, the key in $key_down, the mouse in $mouse, $click
# and $wheel.
$held = []
$key_down = nil
module MGQ_Multiplayer
  # The capture: a button repeats while in $held and triggers as Input says.
  module Mod_Framework::UI::Capture; def self.repeat?(button); $held.include?(button); end; def self.trigger?(button); Input.trigger?(button); end; end
  # Windows' keys: the one in $key_down is pressed and triggered.
  module Mod_Framework::UI::Key; def self.pressed?(code); $key_down == code; end; def self.triggered?(code); pressed?(code); end; def self.down?(code); pressed?(code); end; end
  # The mouse: its position from $mouse, a click from $click taken once, the wheel's notches from
  # $wheel.
  module Mod_Framework::UI::Mouse; def self.position; $mouse; end; def self.clicked?; $click ? ($click = false; true) : false; end; def self.wheel; $wheel.to_i; end; end
end
# Lines that keep each character's place.
widths = lambda { |part| part.size * 10 }
check("a text is broken before the word that does not fit, its spaces kept", Mod_Framework::UI.wrap_spans("one two  three four", 100, &widths), [[0, 9], [9, 10]])
check("an empty text is one empty line", Mod_Framework::UI.wrap_spans("", 100, &widths), [[0, 0]])
check("a word longer than a line is broken inside it", Mod_Framework::UI.wrap_spans("a verylongwordindeed b", 100, &widths), [[0, 2], [2, 10], [12, 10]])
# The game's Ruby 1.9 hands String#chars out as an Enumerator, which cannot count itself.
String.send(:alias_method, :chars_of_ruby_3, :chars)
String.send(:define_method, :chars) { Object.new }
spans_on_1_9 = Mod_Framework::UI.wrap_spans("a verylongwordindeed b", 100, &widths)
String.send(:alias_method, :chars, :chars_of_ruby_3)
check("and is broken without String#chars, as Ruby 1.9 needs", spans_on_1_9, [[0, 2], [2, 10], [12, 10]])
spans = Mod_Framework::UI.wrap_spans("one two three four", 80, &widths)
check("a place in the text is on the line that starts at or before it", [spans, [0, 7, 8, 13, 18].map { |place| Mod_Framework::UI.span_of(spans, place) }], [[[0, 8], [8, 6], [14, 4]], [0, 0, 1, 1, 2]])

# The text box from here on types what $typed holds.
open_fake_ui { typed = $typed.to_s; $typed = nil; [typed, typed.size] }

# The hints, which share two lines at the top of the world screen.
hinted_raid = listed[1].dup
hinted_raid.type = MGQ_MpWorld::RAID
edits = (listed + [hinted_raid]).flat_map { |world| MGQ_MpWorld::WorldForm.edit(:edit_world, world, false).fields + MGQ_MpWorld::WorldForm.edit(:edit_world, world, true).fields }
# A new form takes the slot of the one before, so each form's fields are read before the next opens.
classic_fields = MGQ_MpWorld::WorldForm.create(:new_world).fields
raid_create = MGQ_MpWorld::WorldForm.create(:new_world)
raid_create.turn(raid_create.fields.find { |field| field.key == :type }, 1)
raid_fields = raid_create.fields
form_fields = classic_fields + raid_fields + raid_create.limits.fields + MGQ_MpWorld::WorldForm.join(:join_hidden).fields
long = (form_fields + edits).select { |field| field.hint.size > 100 }
check("every field's hint fits two lines, a Raid World's and its formation limits' too",
      [long.map { |field| field.key }, [:difficulty, :limits] - raid_fields.map { |field| field.key }], [[], []])

# Changing a world.
edit = MGQ_MpWorld::WorldForm.edit(:edit_world, listed[1], false)
check("the edit form holds what may change, filled in as the world is", [edit.title, edit.fields.map { |field| field.key }, edit[:seats], edit[:mods], edit[:description]], ["Edit Loose", [:seats, :raid_bosses, :mods, :other_mods_off, :description, :confirm], "4", "Some Mod", "A slow run through part one of the story with friends."])
check("and may be sent as it is", edit.problem, nil)
offered = lambda do |me, admin|
  scene = new_scene
  scene.instance_variable_set(:@me, me)
  scene.instance_variable_set(:@admin, admin)
  world = screen_entry(entries[1].dup, admin, me)
  scene.on_world(world)
  edits = MGQ_MpWorldScreen.actions(world).any? { |_label, symbol| symbol == :edit_world }
  cancel_menu(scene)
  edits
end
check("the creator and an admin are offered to edit a world, another player is not", [offered.call("c", false), offered.call("me", true), offered.call("me", false)], [true, true, false])
scene = new_scene
scene.instance_variable_set(:@entry, entries[1])
scene.on_edit_world
check("editing opens the form in place of the details, the focus on its first field", [scene.form.title, scene.instance_variable_get(:@form_symbol), $focused.id], ["Edit Loose", :edit_world, "form:seats"])
scene.form[:seats] = "8"
$screen_steps = [["busy", "edit"]]
scene.send_form
check("sending it has the DLL edit the world, with whether the list is fresh", [screen_requests("screen.do").last.values_at("do", "id", "fresh"), scene.busy], [["edit", "w2", true], "edit"])
scene.play("steps" => [["idle"], ["close_form"], ["say", "Loose was changed. Its players play on VERY HARD now."], ["back"]])
check("once changed, the form closes and the screen says what the DLL tells", [scene.form, said(scene), scene.busy], [nil, "Loose was changed. Its players play on VERY HARD now.", nil])
scene.on_edit_world
scene.form[:seats] = "99"
calls = screen_requests("screen.do").size
scene.send_form
check("seats out of range are refused before anything is sent, the focus on them", [screen_requests("screen.do").size, said(scene), $focused.id], [calls, "Max Players must be a number from 2 to 32.", "form:seats"])
raid_listed = listed[1].dup
raid_listed.type = MGQ_MpWorld::RAID
raid_listed.difficulty = nil
scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w2", "Loose", raid_listed, nil, false, false))
scene.leave_form
scene.on_edit_world
picked = scene.form.fields.find { |field| field.key == :difficulty }
check("a Raid World that sets none shows Per player first", [picked.choices.first, picked.choices[scene.form[:difficulty]], scene.form.difficulty], ["Per player", "Per player", nil])
form_part(scene, :limits).receive("click")
check("the button of the formation limits opens them over the world's form", [scene.limits.open?, scene.form.title], [true, "Edit Loose"])
scene.form.limits.turn(scene.form.limits.fields.find { |field| field.key == :formation }, 2)
scene.form.limits.turn(scene.form.limits.fields.find { |field| field.key == :raid_front }, 1)
scene.limits.close(:cancel)
check("cancel goes back to the world's form at the button, keeping what was picked", [scene.limits, scene.instance_variable_get(:@form_symbol), scene.instance_variable_get(:@field_key), scene.form.squad],
      [nil, :edit_world, :limits, { :luka => false, :formation => 6, :front => 1, :raid_front => 2 }])
form_part(scene, :limits).receive("click")
scene.limits.find("form:done").receive("click")
check("as Done does", [scene.limits, scene.form.squad[:formation]], [nil, 6])
scene.leave_form

# The seats a world's code tells follow the directory.
world = local_world("abcdef012345", "code" => "mgqmp2;abcdefghjkmnpqrs;r1;4")
world.describe("Loose", "w2", 8)
check("a world's code takes the seats the directory lists", [world.seats, world.code], [8, "mgqmp2;abcdefghjkmnpqrs;r1;8"])

# The players and the mods of a world, listed from its choices.
check("a mod written with an exclamation mark or a question mark is named first without its mark, the required ones before the essential ones", MGQ_MpWorld.mods_of("Mod A; ?Mod D; !Mod B;! Mod C; !; ?"), ["Mod B", "Mod C", "Mod D", "Mod A"])
MGQ_MpWorld.instance_variable_set(:@installed, [["modb", "Patch/Mod_B.rb", "Mod_B"], ["maskofenvy", "Patch/Mask_of_Envy.rb", "Mask_of_Envy"]])
check("a mod's script is found by its name, whatever its case, spaces or underscores", ["Mod B", "mod_b.rb", "Mask of Envy", "Mask-Of-Envy", "Mod C"].map { |mod| MGQ_MpWorld.installed_mod?(mod) }, [true, true, true, true, false])

# A world the list names without its mods, as the relay lists it for this version.
unread_world = listed[1].dup
unread_world.mods = ""
unread_world.mods_unread = true
unread_entry = MGQ_MpWorld::Entry.new("w2", "Loose", unread_world, nil, false, false)
scene = new_scene
scene.instance_variable_set(:@entry, unread_entry)
listed_before = $directory
$directory = directory_list([listed_value("w2", "Loose", "open" => true, "data" => plain, "mods" => "!Mod C", "description" => "A slow run.")])
$screen_steps = [["read"]]
scene.on_enter
check("once the DLL read its mods, the read step takes the world anew from the list", unread_entry.listed.mods, "!Mod C")
$directory = listed_before
Dir.mktmpdir do |folder|
  FileUtils.mkdir_p(File.join(folder, "Patch", "Sub"))
  File.write(File.join(folder, "Patch", "Mask_of_Envy.rb"), "")
  File.write(File.join(folder, "Patch", "Sub", "Deep Mod.rb"), "")
  Dir.chdir(folder) do
    MGQ_MpWorld.instance_variable_set(:@installed, nil)
    check("the Patch folder is read with its folders", ["Mask of Envy", "deep_mod", "Other"].map { |mod| MGQ_MpWorld.installed_mod?(mod) }, [true, true, false])
  end
end
MGQ_MpWorld.instance_variable_set(:@installed, [["modb", "Patch/Mod_B.rb", "Mod_B"]])
modded_world = listed[1].dup
modded_world.mods = "Mod A; Mod B"
member = MGQ_MpWorld::Directory::Member
modded_world.members = [member.new("me", true, "Me"), member.new("a", false, "Ann")]
modded_entry = screen_entry(MGQ_MpWorld::Entry.new("w2", "Loose", modded_world, nil, false, false))
scene = new_scene
scene.instance_variable_set(:@me, "me")
scene.on_world(modded_entry)
check("a world's choices leave its players and its mods to the details", menu_texts.grep(/Players|Mods/), [])
cancel_menu(scene)
scene.instance_variable_set(:@entry, modded_entry)
scene.open_box(:players)
box = scene.list_box
check("the players open in the list box, under the world's name", [box.children.first.children.map { |label| label.text }], [["Loose", "Players"]])
check("those online first, then the others, each under a heading, the player marked", MGQ_MpListBox.list(box).rows,
      [{ :heading => "Online (1)" }, { :text => "Me (you)", :color => :good, :right => "online" }, { :heading => "Offline (1)" }, { :text => "Ann", :color => :dim, :right => "offline" }])
check("the first player is picked", MGQ_MpListBox.list(box).index, 1)
scene.open_box(:mods)
box = scene.list_box
check("each mod is listed on its own", [note_text(box), MGQ_MpListBox.list(box).rows],
      ["Mods", [{ :heading => "Mods (2)" }, { :text => "Mod A", :color => nil, :right => nil }, { :text => "Mod B", :color => nil, :right => nil }]])
box.close

# The description in the list box.
scene = new_scene
scene.instance_variable_set(:@entry, entries[1])
scene.open_box(:description)
box = scene.list_box
check("the whole description opens in the list box, wrapped", [note_text(box), box.find(MGQ_MpListBox::LIST), box.children[1].children.first.text, box.children[1].children.first.wrap],
      ["Description", nil, "A slow run through part one of the story with friends.", true])
box.close

# The edit form of a world's creator.
own_edit = MGQ_MpWorld::WorldForm.edit(:edit_world, listed[1], true)
check("the creator's edit form has Shared Mod Settings, unticked while the world leaves every player their own, and no button of the game data",
      [own_edit.fields.map { |field| field.key }, own_edit.fields[3].kind, own_edit.fields[3].label, own_edit.fields[3].group, own_edit[:shared]],
      [[:seats, :raid_bosses, :mods, :shared, :other_mods_off, :description, :confirm], :check, "Shared Mod Settings", "Game data", false])
check("another editor's form does not", MGQ_MpWorld::WorldForm.edit(:edit_world, listed[1], false).fields.map { |field| field.key }, [:seats, :raid_bosses, :mods, :other_mods_off, :description, :confirm])
scene = new_scene
scene.instance_variable_set(:@me, "c")
scene.instance_variable_set(:@entry, entries[1])
scene.on_edit_world
$screen_steps = [["busy", "edit"]]
form_part(scene, :confirm).receive("click")
check("the form's own button has the DLL save the changes, the shared settings with them", screen_requests("screen.do").last["do"], "edit")
entries[1].listed.settings = ""
scene.play("steps" => [["idle"], ["close_form"]])

# The mod picker, which the DLL keeps (ModPickTests): the script shows what it answers and hands each
# change over.
$picker_installed = ["Battle_Dialogue", "Level_Cap"]
pick = MGQ_MpWorld::ModPick.new("!level cap; Unknown Mod; ?Data Pack")
check("named mods take their state, label and colour, matched whatever their case or spaces, and those not installed follow as added", pick.entries.map { |entry| entry.to_a },
      [["Battle_Dialogue", :unlisted, true, "unlisted", :grey], ["Level_Cap", :required, true, "required", :bad], ["Data Pack", :essential, false, "essential", :gold], ["Unknown Mod", :listed, false, "listed", :plain]])
check("the text names the mods as the world keeps them, an installed one by its file's name", pick.text, "!Level_Cap; ?Data Pack; Unknown Mod")
first = pick.entries[0]
pick.toggle(0)
check("a change goes to the DLL, and a mod read before it tells its new state", [first.state, pick.text], [:listed, "Battle_Dialogue; !Level_Cap; ?Data Pack; Unknown Mod"])
check("a mod added by name is removed on its own, an installed one not", [pick.remove(3), pick.remove(0), pick.entries.size], [true, false, 3])
check("a refusal comes back as the DLL says it", pick.add("level_cap"), "Level_Cap is in the list already.")
check("and list all lists the rest", [pick.mark(1, :required), pick.unlist_all, pick.list_all, pick.text, pick.all_listed?], [nil, nil, nil, "Battle_Dialogue; Level_Cap; ?Data Pack", true])
$picker_installed = nil

Dir.mktmpdir do |folder|
  FileUtils.mkdir_p(File.join(folder, "Patch", "Sub"))
  %w[Patch.rb Multiplayer.rb 0_ModConfigRemake.rb Level_Cap.rb battle_dialogue.rb Zeta.rb].each { |name| File.write(File.join(folder, "Patch", name), "") }
  File.write(File.join(folder, "Patch", "Sub", "Party Sheet.rb"), "")
  File.write(File.join(folder, "Patch", "Sub", "Level Cap.rb"), "")

  Dir.chdir(folder) do
    MGQ_MpWorld.forget_installed
    off = [{ :text => "!", :color => :bad, :on => false }, { :text => "?", :color => :warn, :on => false }]
    scene = new_scene
    scene.enter_form(:new_world)
    form = scene.form
    form[:mods] = "?Data Pack"
    form_part(scene, :mods).receive("click")
    list = MGQ_MpListBox.list(scene.list_box)
    row = lambda { |name| list.rows.find { |each| each[:text] == name } }
    check("the picker lists the row that lists every mod, the installed mods with their two toggles, the added ones and the row that adds one",
          [list.rows.map { |each| each[:text] || each[:heading] }, row.call("Zeta").values_at(:color, :right, :toggles), list.index],
          [["List all your mods", "Your mods (4)", "battle_dialogue", "Level_Cap", "Party Sheet", "Zeta", "Added by name (1)", "Data Pack", "Add a mod by name . . ."],
           [:dim, "unlisted", off], 0])
    at = lambda { |name| list.rows.index(row.call(name)) }
    list.receive("submit", at.call("Level_Cap"))
    check("confirm on a mod lists it in the form at once", [form[:mods], row.call("Level_Cap")[:right]], ["Level_Cap; ?Data Pack", "listed"])
    list.receive("toggle", at.call("Level_Cap"), 0)
    check("its ! toggle makes it required, the toggle on", [form[:mods], row.call("Level_Cap")[:toggles][0][:on]], ["!Level_Cap; ?Data Pack", true])
    list.receive("toggle", at.call("Level_Cap"), 1)
    check("its ? toggle makes it essential", [form[:mods], row.call("Level_Cap")[:toggles].map { |toggle| toggle[:on] }], ["?Level_Cap; ?Data Pack", [false, true]])
    list.receive("submit", at.call("Level_Cap"))
    check("confirm unlists it again", form[:mods], "?Data Pack")
    list.receive("submit", 0)
    check("the first row lists every installed mod, then offers to unlist them", [form[:mods], list.rows[0][:text]], ["battle_dialogue; Level_Cap; Party Sheet; Zeta; ?Data Pack", "Unlist all your mods"])
    list.receive("submit", 0)
    check("and unlists them", [form[:mods], list.rows[0][:text]], ["?Data Pack", "List all your mods"])
    list.index = at.call("Data Pack")
    scene.show_remove
    check("while a mod added by name is picked, the Remove button shows", MGQ_MpListBox.remove_button(scene.list_box).visible, true)
    MGQ_MpListBox.remove_button(scene.list_box).receive("click")
    check("Remove takes it out of the list and the form", [list.rows.map { |each| each[:text] || each[:heading] }.include?("Data Pack"), form[:mods]], [false, ""])
    list.index = at.call("Zeta")
    scene.show_remove
    check("an installed mod has no Remove", MGQ_MpListBox.remove_button(scene.list_box).visible, false)
    $sounds.clear
    list.receive("submit", list.rows.index { |each| each[:data] == :add })
    field = MGQ_MpListBox.field(scene.list_box)
    help = MGQ_MpListBox.key_help(scene.list_box)
    check("the last row opens the Name field under the list, typing, the box at least as wide as its key line",
          [field.parent.parent.visible?, $focused.equal?(field), $mgq_text_input, scene.list_box.min_size[0] >= help.measure[0] + 2 * Mod_Framework::UI::Box::ROOM],
          [true, true, true, true])
    type_in("New Mod\r")
    check("Enter adds the mod, picked, and hides the field", [form[:mods], list.rows[list.index][:text], field.parent.parent.visible?, $focused.equal?(list)],
          ["New Mod", "New Mod", false, true])
    list.receive("submit", list.rows.size - 1)
    type_in("Other")
    cancel_in(field)
    check("cancel in the field goes back to the list without adding", [form[:mods], field.parent.parent.visible?, $mgq_text_input], ["New Mod", false, false])
    list.receive("submit", list.rows.size - 1)
    field.receive("submit")
    pad = Mod_Framework::UI::Tree.roots.find { |root| root.is_a?(Mod_Framework::UI::LetterPad) }
    check("a gamepad's letters take the keys from the Name field, which stays open", [pad.nil?, field.parent.parent.visible?], [false, true])
    "Pad Mod".each_char { |letter| pad.type(letter) } if pad
    pad.finish if pad
    check("their OK adds the mod and hides the field", [form[:mods], field.parent.parent.visible?], ["New Mod; Pad Mod", false])
    pad.close if pad
    $sounds.clear
    scene.add_mod("level cap")
    check("a name already listed is refused beside the title", [$sounds, note_text(scene.list_box)], [["buzzer"], "Level_Cap is in the list already."])
    scene.list_box.close(:cancel)
    check("closing goes back to the form, which shows the mods picked", [scene.list_box, form_part(scene, :mods).text, scene.instance_variable_get(:@field_key)], [nil, "New Mod; Pad Mod", :mods])
  end
end

# The text boxes of the forms.
named = nil
MGQ_Multiplayer::Player.define_singleton_method(:name=) { |name| named = name }
scene = new_scene
$returned = nil
scene.enter_form(:rename)
type_in("Bob\r")
check("Enter in the name's text box keeps the name and leaves the form, the screen still open", [named, scene.form, $returned, $mgq_text_input], ["Bob", nil, nil, false])

scene.commands_list.index = 0
scene.enter_form(:new_world)
create = scene.form
ui::Tree.focus(form_part(scene, :seats))
scene.show_typing_line
check("a text box of digits leaves the numpad's 0 out of the typing line", scene.instance_variable_get(:@typing_line).text,
      "Type on the keyboard. Arrows, Home, End move the cursor. Enter keeps it, Esc goes back.")
cancel_in($focused)
create[:name] = "  Spaced  "
create[:seats] = "08"
check("a form sends its tidied values", [create.problem, create[:name], create[:seats]], [nil, "Spaced", "8"])
