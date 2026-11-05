#----------------------------------------------------------------
#  world_data_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Acted on the world screen as its window of the UI layer hands over what the player does, leaving the list box and the mod picker's look to the in-game suite
#      Paulinchen  2026-11-05: Answered the mods text, the mod keys and the scripts in Patch with fixed values and checked what goes to the DLL instead of the rules
#                            - Checked the ids the fingerprint is made of and what goes to the DLL to compare, instead of what its stand-ins compared
#                            - Answered the forms, the list's rows, the choices, the list box and the mod picker with the values each check sets, leaving their rules to the DLL's tests
#                            - Checked that a fingerprint the DLL did not answer is measured again
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
# world_screen.rbx): the ids of a game's data the fingerprint is made of, what goes to the DLL to
# compare and name them, the forms' requests, the directory's fields, the list box, the text boxes
# and the mod picker drawn from the DLL's answers, whose rules its tests cover.

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

# The fingerprint: the script reads the ids in use of each part, the DLL writes the fingerprint of
# them (DataFingerprintTests) and compares two.
# Tells the ids the script handed the DLL's measure last.
measured = lambda { Marshal.load($world_bridge.calls.reverse.find { |topic, _| topic == "worlds.fingerprint" }[1]) }
game_data([DataUsable.new("Slash", "<power 2>"), DataUsable.new(""), DataUsable.new("Fire", "", [], [:damage])], [2, 1])
plain = MGQ_MpWorld::GameData.fingerprint
untranslated = measured.call
check("the fingerprint is the DLL's of the ids in use of each part, an entry holding a note, features or effects, the maps sorted",
      [plain, untranslated.values_at(0, 2, 8, 9, 10)], [$world_bridge.instance_variable_get(:@handlers)["worlds.fingerprint"].call(untranslated), [[1, 2], [1, 3], [1], [1], [1, 2, 1001]]])
$locals.clear
$locals.set("worlds.data_differing", [])
check("comparing it with another game's hands the DLL this game's fingerprint once, then the other's, each asked once",
      [MGQ_MpWorld::GameData.differing("2:other"), MGQ_MpWorld::GameData.differing("2:other"), $locals.asked("worlds.game_data"), $locals.asked("worlds.data_differing")],
      [[], [], [plain], ["2:other"]])
$locals.set("worlds.data_differing")
measuring = $world_bridge.instance_variable_get(:@handlers)["worlds.fingerprint"]
$world_bridge.answer("worlds.fingerprint") { nil }
MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)
silent = MGQ_MpWorld::GameData.fingerprint
$world_bridge.answer("worlds.fingerprint", &measuring)
check("a fingerprint the DLL did not answer is measured again at the next ask", [silent, MGQ_MpWorld::GameData.fingerprint], ["", plain])
game_data([DataUsable.new("Schlag", "<power 2>"), DataUsable.new("Leer", " \r\n"), DataUsable.new("Feuer", "", [], [:damage])], [1, 2])
MGQ_MpWorld::GameData.fingerprint
check("a translated game reads the same ids as the untranslated one, even where it names an empty place", measured.call, untranslated)
game_data([DataUsable.new("Slash", "<power 2>"), DataUsable.new("Mod Skill", "", [:feature]), DataUsable.new("Fire", "", [], [:damage])], [1, 2, 488])
MGQ_MpWorld::GameData.fingerprint
check("a mod's new skill and map are read, the skill by what it holds", measured.call.values_at(2, 10), [[1, 2, 3], [1, 2, 488, 1001]])
game_data([DataUsable.new("Slash", "<power 2>"), DataUsable.new(""), DataUsable.new("Fire", "", [], [:damage])], [1, 2], [1, 5])
check("the maps of a further map folder count on from a thousand", MGQ_MpWorld::GameData.map_ids, [1, 2, 1001, 1005])
game_data([DataUsable.new("Slash", "<power 2>"), DataUsable.new("Mod Skill", "", [:feature]), DataUsable.new("Fire", "", [], [:damage])], [1, 2, 488])
$locals.clear
check("a world without game data is not compared, the DLL not asked", [MGQ_MpWorld::GameData.differing(""), MGQ_MpWorld::GameData.differing(nil), $locals.asked("worlds.data_differing")],
      [nil, nil, []])
$locals.set("worlds.data_text", "skills, maps and 2 more")
check("the parts that differ are named as the DLL writes them, four at most unless asked otherwise",
      [MGQ_MpWorld::GameData.text(%w[skills maps]), MGQ_MpWorld::GameData.text(%w[skills], 2), $locals.asked("worlds.data_text")],
      ["skills, maps and 2 more", "skills, maps and 2 more", [{ "parts" => %w[skills maps], "named" => 4 }, { "parts" => %w[skills], "named" => 2 }]])
$locals.set("worlds.data_text")
modded = MGQ_MpWorld::GameData.fingerprint

# The measure once a world's mods loaded, which the battle server, measuring without them, never takes.
$data_items << DataEntry.new("Mod Potion", "<Mod Potion>")
entered = MGQ_MpWorld::GameData.measure_entered
check("a world's mod that adds an item shows in the measure taken once the world's mods loaded", [measured.call[3], entered == modded], [[1, 2], false])
MGQ_MpWorld::GameData.differing(entered)
check("while the fingerprint the DLL keeps and served battles carry stays the title's, so the server still hosts them",
      [MGQ_MpWorld::GameData.fingerprint, $locals.asked("worlds.game_data").last], [modded, modded])
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

# The forms' fields and rules are the DLL's (WorldFormsTests). The name form tells it whether
# Discord told the player's name, which lets the name stay empty.
rename = MGQ_MpWorld::WorldForm.rename(:rename, "")
# Discord, which tells the player's name from $discord_name.
module MGQ_Multiplayer; module Discord; def self.player_name; $discord_name; end; end; end
# Player.ini, whose settings come from $player_ini.
module MGQ_Multiplayer::Player; DISCORD_NAME = "discord_name"; def self.setting(key); ($player_ini || {})[key]; end; end
# Tells the facts the name form hands the DLL with a check of an empty name.
facts = lambda { rename.check(rename.fields[0], " "); $forms.asked("form.check").last["facts"] }
$discord_name = nil
told_none = facts.call
$discord_name = "Discord Me"
told_now = facts.call
$discord_name = nil
$player_ini = { "discord_name" => "Earlier Me" }
check("the name form tells the DLL whether Discord told the player's name, now or in an earlier session", [told_none, told_now, facts.call], [[], ["discord"], ["discord"]])
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
scene = new_scene
scene.enter_form(:new_world, :confirm)
$screen_steps = [["buzz"], ["say", "The request could not be started. Try again in a moment."], ["resume_form"]]
scene.create_world
check("a world the DLL refuses leaves the form open at the field it was sent from, with why", [said(scene), scene.form.nil?, focused(scene), scene.busy],
      ["The request could not be started. Try again in a moment.", false, :confirm, nil])
DATA_WORLDS = [listed_value("w1", "Strict", "open" => true, "strict" => true, "data" => plain, "mods" => "No mods", "description" => "Unmodded only."),
               listed_value("w2", "Loose", "open" => true, "data" => plain, "mods" => "Some Mod", "description" => "A slow run through part one of the story with friends."),
               listed_value("w3", "Same", "open" => true, "strict" => true, "data" => modded),
               listed_value("w4", "Old", "open" => true)]
$directory = directory_list(DATA_WORLDS)
_, _, listed, = MGQ_MpWorld::Directory.list
check("the list reads which worlds take the same data only", listed.map { |world| world.strict }, [true, false, true, false])
check("their creators' game data", listed.map { |world| world.data }, [plain, plain, modded, ""])
check("the mods they need and their descriptions", [listed[1].mods, listed[0].description, listed[3].mods, listed[3].description], ["Some Mod", "Unmodded only.", "", ""])
entries = DATA_WORLDS.map { |values| screen_entry(listed_row(values)) }
screen_list(entries.map { |entry| entry.row })
MGQ_MpWorld::GameData.instance_variable_set(:@handed, nil)
$locals.clear
$locals.set("worlds.data_differing") { |other| other == plain ? %w[skills maps] : [] }
check("an entry tells what the DLL finds differs from its creator's game data, each fingerprint asked once, none without one",
      [entries.map { |entry| entry.differing }, $locals.asked("worlds.data_differing")], [[["skills", "maps"], ["skills", "maps"], [], nil], [plain, modded]])
$locals.set("worlds.data_differing")

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
hidden_entry = screen_entry(screen_row("Hidden Base", "id" => "ab" * 16, "listed" => DATA_WORLDS[0]))
$screens.actions["ab" * 16] = [["Enter the world", "enter", true], ["Remove from my list", "forget", true], ["Back", "cancel", true]]
scene = new_scene
scene.on_world(hidden_entry)
check("a world's choices are the DLL's, asked by its row's key, in the menu", [$screens.asked("screen.actions").last, menu_texts], ["ab" * 16, ["Enter the world", "Remove from my list", "Back"]])
$screen_steps = [["say", "Hidden Base was removed from your list."], ["back"]]
pick_menu(scene, 1)
check("removing an added world has the DLL forget its id, and says what the DLL tells", [screen_requests("screen.do").last.values_at("do", "id"), said(scene)], [["forget", "ab" * 16], "Hidden Base was removed from your list."])

# The text box from here on types what $typed holds.
open_fake_ui { typed = $typed.to_s; $typed = nil; [typed, typed.size] }

# Changing a world.
MGQ_MpWorld::WorldForm.edit(:edit_world, listed[1], false)
check("the edit form opens on the world as the list tells it, for its creator or not",
      [$forms.asked("form.open").last.values_at("kind", "own"), $forms.asked("form.open").last["world"]],
      [["edit", false], { "name" => "Loose", "seats" => 4, "mods" => "Some Mod", "description" => "A slow run through part one of the story with friends.", "shared" => false,
                          "difficulty" => nil, "raid" => false, "other_mods_off" => false, "raid_bosses" => false, "squad" => nil }])
scene = new_scene
scene.instance_variable_set(:@entry, entries[1])
scene.on_edit_world
check("editing opens the form in place of the details, the focus on its first field", [scene.form.title, scene.form_symbol, focused(scene)],
      [FormAnswers.view("edit of a Classic world, by an admin")["title"], :edit_world, :seats])
scene.form[:seats] = "8"
$screen_steps = [["busy", "edit"]]
scene.send_form
check("sending it has the DLL edit the world, with whether the list is fresh", [screen_requests("screen.do").last.values_at("do", "id", "fresh"), scene.busy], [["edit", "w2", true], "edit"])
scene.play("steps" => [["idle"], ["close_form"], ["say", "Loose was changed. Its players play on VERY HARD now."], ["back"]])
check("once changed, the form closes and the screen says what the DLL tells", [scene.form, said(scene), scene.busy], [nil, "Loose was changed. Its players play on VERY HARD now.", nil])
scene.on_edit_world
scene.form[:seats] = "99"
calls = screen_requests("screen.do").size
$forms.set("form.send", "problem" => ["seats", "Max Players must be a number from 2 to 32."])
scene.send_form
$forms.set("form.send")
check("seats the DLL refuses are refused before anything is sent, the focus on them", [screen_requests("screen.do").size, said(scene), focused(scene)],
      [calls, "Max Players must be a number from 2 to 32.", :seats])
raid_listed = listed[1].dup
raid_listed.type = MGQ_MpWorld::RAID
raid_listed.difficulty = nil
scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w2", "Loose", raid_listed, nil, false, false))
scene.leave_form
raid_edit = FormAnswers.view("edit of a Raid World without a difficulty, by its creator")
$forms.set("form.open", raid_edit)
scene.on_edit_world
$forms.set("form.open")
scene.pressed(form_field(scene, :limits))
check("the button of the formation limits opens them over the world's form", [scene.limits.open?, scene.form.title], [true, raid_edit["title"]])
# The world's form as the DLL tells it once the limits changed: a Formation of 6 and two in front in raids.
picked = { "luka" => false, "formation" => 6, "front" => 1, "raid_front" => 2 }
$forms.set("form.view") { |request| request["page"] ? FormAnswers.view(FormAnswers::LIMITS) : raid_edit.merge("derived" => raid_edit["derived"].merge("squad" => picked)) }
scene.form.limits.turn(scene.form.limits.fields.find { |field| field.key == :formation }, 2)
scene.form.limits.turn(scene.form.limits.fields.find { |field| field.key == :raid_front }, 1)
scene.limits.close
check("the limits' switches go to the DLL on their page, and cancel goes back to the world's form at the button, which reads what the DLL adds up",
      [$forms.asked("form.turn").last(2).map { |request| request.values_at("page", "key", "step") }, scene.limits, scene.instance_variable_get(:@form_symbol),
       scene.instance_variable_get(:@field_key), scene.form.squad],
      [[["limits", "formation", 2], ["limits", "raid_front", 1]], nil, :edit_world, :limits, { :luka => false, :formation => 6, :front => 1, :raid_front => 2 }])
scene.pressed(form_field(scene, :limits))
scene.pressed(scene.form.limits.fields.find { |field| field.key == :done })
check("as Done does", [scene.limits, scene.form.squad[:formation]], [nil, 6])
$forms.set("form.view")
scene.leave_form

# The players and the mods of a world, listed from its choices: the DLL reads the mods text and
# makes each mod's key.
$rule_answers.set("mods.text", { "names" => ["Mod B", "Mod C", "Mod D", "Mod A"], "required" => ["Mod B", "Mod C"], "essential" => ["Mod D"] })
check("a world's mods are named as the DLL reads its mods text",
      [MGQ_MpWorld.mods_of("Mod A; ?Mod D; !Mod B;! Mod C; !; ?"), $rule_answers.asked("mods.text").last], [["Mod B", "Mod C", "Mod D", "Mod A"], "Mod A; ?Mod D; !Mod B;! Mod C; !; ?"])
$rule_answers.set("mods.text", nil)
mod_keys = { "Mod B" => "modb", "Mod C" => "modc", "Deep Mod" => "deepmod", "Other" => "other" }
$rule_answers.set("mods.keys") { |names| names.map { |name| mod_keys.fetch(name) } }
MGQ_MpWorld.instance_variable_set(:@installed, [["modb", "Patch/Mod_B.rb", "Mod_B"], ["maskofenvy", "Patch/Mask_of_Envy.rb", "Mask_of_Envy"]])
check("a mod is installed when the DLL's key of its name is a script's in Patch", ["Mod B", "Mod C"].map { |mod| MGQ_MpWorld.installed_mod?(mod) }, [true, false])

# A world the list names without its mods, as the relay lists it for this version.
unread_world = listed[1].dup
unread_world.mods = ""
unread_world.mods_unread = true
unread_entry = MGQ_MpWorld::Entry.new("w2", "Loose", unread_world, nil, false, false)
scene = new_scene
scene.instance_variable_set(:@entry, unread_entry)
list_before = $screens.list
$screens.list = { "state" => "ready", "error" => nil, "admin" => false, "info" => nil,
                  "rows" => [listed_row(listed_value("w2", "Loose", "open" => true, "data" => plain, "mods" => "!Mod C", "description" => "A slow run."))] }
$screen_steps = [["read"]]
scene.on_enter
check("once the DLL read its mods, the read step takes the world anew from the DLL's list", [$screens.asked("screen.world").last, unread_entry.listed.mods], ["w2", "!Mod C"])
$screens.list = list_before
$rule_answers.set("mods.installed", [["deepmod", "Patch/Sub/Deep Mod.rb", "Deep Mod"]])
MGQ_MpWorld.instance_variable_set(:@installed, nil)
check("the scripts in Patch are those the DLL lists", ["Deep Mod", "Other"].map { |mod| MGQ_MpWorld.installed_mod?(mod) }, [true, false])
MGQ_MpWorld.instance_variable_set(:@installed, [["modb", "Patch/Mod_B.rb", "Mod_B"]])
modded_world = listed[1].dup
modded_world.mods = "Mod A; Mod B"
member = MGQ_MpWorld::Directory::Member
modded_world.members = [member.new("me", true, "Me"), member.new("a", false, "Ann")]
modded_entry = MGQ_MpWorld::Entry.new("w2", "Loose", modded_world, nil, false, false, "w2")
# The edit form of a world's creator.
scene = new_scene
scene.instance_variable_set(:@me, "c")
scene.instance_variable_set(:@entry, entries[1])
scene.on_edit_world
$screen_steps = [["busy", "edit"]]
scene.pressed(form_field(scene, :confirm))
check("the form's own button has the DLL save the changes, the creator's form told it is theirs", [$forms.asked("form.open").last["own"], screen_requests("screen.do").last["do"]],
      [true, "edit"])
entries[1].listed.settings = ""
scene.play("steps" => [["idle"], ["close_form"]])

# The mod picker, which the DLL keeps: the script shows what it answers and hands each
# change over.
# Makes the picker as the DLL tells it: each mod with its state, whether it is installed, its label
# and its colour.
pick_view = lambda do |mods, text, all_listed = false|
  colors = { "unlisted" => "grey", "listed" => "plain", "required" => "bad", "essential" => "gold" }
  { "entries" => mods.map { |name, state, installed| [name, state, installed, state, colors[state]] }, "text" => text, "all_listed" => all_listed }
end
$locals.set("modpick.open", pick_view.call([["Battle_Dialogue", "unlisted", true], ["Level_Cap", "required", true], ["Data Pack", "essential", false]], "!Level_Cap; ?Data Pack"))
pick = MGQ_MpWorld::ModPick.new("!level cap; ?Data Pack")
check("the picker opens on the world's mods through the DLL and takes each mod's state, label and colour as it answers",
      [$locals.asked("modpick.open").last, pick.entries.map { |entry| entry.to_a }, pick.text, pick.all_listed?],
      [{ "text" => "!level cap; ?Data Pack" }, [["Battle_Dialogue", :unlisted, true, "unlisted", :grey], ["Level_Cap", :required, true, "required", :bad], ["Data Pack", :essential, false, "essential", :gold]],
       "!Level_Cap; ?Data Pack", false])
first = pick.entries[0]
$locals.set("modpick.act", "answer" => nil, "pick" => pick_view.call([["Battle_Dialogue", "listed", true], ["Level_Cap", "required", true], ["Data Pack", "essential", false]],
                                                                     "Battle_Dialogue; !Level_Cap; ?Data Pack", true))
pick.toggle(0)
check("a change goes to the DLL, and a mod read before it tells its new state", [$locals.asked("modpick.act").last, first.state, pick.text, pick.all_listed?],
      [{ "do" => "toggle", "index" => 0 }, :listed, "Battle_Dialogue; !Level_Cap; ?Data Pack", true])
pick.mark(1, :essential)
pick.set(1, :unlisted)
pick.list_all
pick.unlist_all
check("marks, states and the whole list go to the DLL by name", $locals.asked("modpick.act").last(4),
      [{ "do" => "mark", "index" => 1, "state" => "essential" }, { "do" => "set", "index" => 1, "state" => "unlisted" }, { "do" => "list_all" }, { "do" => "unlist_all" }])
$locals.set("modpick.act", "answer" => "Level_Cap is in the list already.", "pick" => pick_view.call([["Battle_Dialogue", "listed", true]], "Battle_Dialogue"))
check("a refusal comes back as the DLL says it, the picker made anew of the mods it tells", [pick.add("level_cap"), pick.entries.map { |entry| entry.name }],
      ["Level_Cap is in the list already.", ["Battle_Dialogue"]])
$locals.set("modpick.act", "answer" => true, "pick" => pick_view.call([], ""))
check("a mod removed is what the DLL says", [pick.remove(0), $locals.asked("modpick.act").last], [true, { "do" => "remove", "index" => 0 }])
$locals.set("modpick.act")
$locals.set("modpick.open")

# The text boxes of the forms.
named = nil
MGQ_Multiplayer::Player.define_singleton_method(:name=) { |name| named = name }
scene = new_scene
$returned = nil
scene.enter_form(:rename)
type_in("Bob\r")
check("Enter in the name's text box keeps the name and leaves the form, the screen still open", [named, scene.form, $returned], ["Bob", nil, nil])

scene.enter_form(:new_world)
create = scene.form
create[:name] = "  Spaced  "
create[:seats] = "08"
tidied = FormAnswers.view("create as it opens")
tidied["values"].merge!("name" => "Spaced", "seats" => "8")
$forms.set("form.send", tidied)
check("a form sent takes the values the DLL tidied", [create.problem, $forms.asked("form.set").last(2).map { |request| request["value"] }, create[:name], create[:seats]],
      [nil, ["  Spaced  ", "08"], "Spaced", "8"])
$forms.set("form.send")
