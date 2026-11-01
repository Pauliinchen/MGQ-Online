#----------------------------------------------------------------
#  raid_difficulty_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Dropped the stand-in of the title screen's commands, which no script hooks any more
#                            - Stopped loading the deleted ui_boxes.rbx
#                            - Dropped the stand-ins of the name box and letters of the deleted text screen
#      Paulinchen  2026-10-31: Loaded ui_online.rbx and ui_boxes.rbx in place of the scripts the Mod Framework took over
#                            - Expected a Classic party to keep the difficulty each player's own, by the reviewed list
#      Paulinchen  2026-10-30: Expected the forms without the game data's fields
#                            - Left the hints fitting their lines to world_data_test.rb
#      Paulinchen  2026-10-23: Left the calls a new world and an edit hand the directory to the DLL's tests
#                            - Left where a Raid World's new player starts to the DLL's tests
#                            - Opened the world screen's forms through the DLL
#                            - Made the worlds on this PC through the stand-ins of the DLL's topics
#                            - Answered the rules the DLL owns through the bridge from the golden cases
#                            - Checked a Raid World's own values by its story mapping instead of the Raid personal lists
#      Paulinchen  2026-10-22: Stood in for whether the version to install is a step back and for the update message
#      Paulinchen  2026-10-15: Expected the options of mp_dir_create in one number
#      Paulinchen  2026-10-14: Checked a Raid World's Shared save in every build
#      Paulinchen  2026-10-13: Checked a Classic world's raid bosses in the forms and the calls of mp_dir_create and mp_dir_edit
#                            - Checked a Raid World's squad rules in the forms and the calls of mp_dir_create and mp_dir_edit
#                            - Checked the button of the squad rules and their form of its own
#      Paulinchen  2026-10-12: Stood in for Ini.load
#      Paulinchen  2026-10-10: Checked the Raid World starting save of releases and development builds
#      Paulinchen  2026-10-09: Expected the new Raid World form rows and the longer calls of mp_dir_create and mp_dir_edit
#                            - Created
#
#----------------------------------------------------------------

# Covers a Raid World's difficulty, squad rules and start: the Difficulty, the squad rules and the
# Shared save of the new world's and the edit form, what goes to the DLL, and its starting save but
# never a choice on entering (world.rbx, world_save_distribution.rbx); the world's difficulty on load, new game and
# the relay's push, set over the game's own choice and the Reaper's change, while the Labyrinth of
# Chaos, the Colosseum and the special bosses keep their own values (world_difficulty.rbx); and these
# values each Raid World player's own in the story (story_state.rbx).

require_relative "support"
require_relative "rules_support"

# Stands in for the game's base scene.
class Scene_Base; def return_scene; end; end
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
# Stands in for the game's colors.
class Color; def initialize(*); end; end
# Stands in for the game's sprites.
class Sprite; def initialize(*); end; end
# Stands in for the game's rectangles.
Rect = Struct.new(:x, :y, :width, :height)
# Stands in for the game's title screen.
class Scene_Title; def start; end; def create_command_window; end; def close_command_window; end; def update; end; def terminate; end; end
# Stands in for the game's sounds, which play nothing.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") {} }; end
# Stands in for the game's scenes, calling none.
module SceneManager; def self.call(_scene); end; end
# Stands in for the game's data.
module RPG
  # An event command.
  EventCommand = Struct.new(:code, :indent, :parameters)
  # A common event and its commands.
  CommonEvent = Struct.new(:list)
end
# Stands in for the game's switches, off unless set.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's variables, 0 unless set.
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the map, whose update the difficulty's look hooks into.
class Game_Map; def update(_main = false); end; end
$quiet = true
# The map's interpreter, running while a test says an event runs.
class MapInterpreter; def running?; !$quiet; end; end

# Runs an event's commands as the game's interpreter does, as far as the tests need: a variable set
# to a constant (122), a common event's call (117), a script line (355) and a picture's erase (235).
class Game_Interpreter
  # Starts running an event's commands.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  def setup(list, _event_id = 0); @list = list; @index = 0; @running = true; end
  # Answers whether the event still runs.
  def running?; @running; end

  # Runs the event's commands to its end.
  def update
    while @list[@index]
      execute_command
      @index += 1
    end
    @running = false
  end

  # Runs the command at the event's place.
  def execute_command
    command = @list[@index]
    case command.code
    when 122 then $game_variables[command.parameters[0]] = command.parameters[4]
    when 117
      child = Game_Interpreter.new
      child.setup($data_common_events[command.parameters[0]].list)
      child.update
    when 355 then eval(command.parameters[0])
    when 235 then $erased << command.parameters[0]
    end
  end
end
# Stands in for the game's saves, whose loads and new games the world's difficulty hooks into.
module DataManager
  # Stands in for writing the system save, doing nothing.
  def self.save_system; end
  # Stands in for loading a save, which always loads.
  def self.load_game_without_rescue(_index); true; end
  # Stands in for starting a new game, doing nothing.
  def self.setup_new_game; end
end

$calls = []
$dll = {}
$ini = {}
# Stands in for the mod's base script and its DLL, whose calls go into $calls.
module MGQ_Multiplayer
  # Stands in for the text that asks for an update.
  UPDATE_MESSAGE = "Update."
  # Gives the update message as it is.
  def self.update_message; UPDATE_MESSAGE; end
  # Stands in for whether the mod can run: answers true.
  def self.available?; true; end
  # Stands in for whether the mod is outdated: answers false.
  def self.outdated?; false; end
  # Stands in for a newer version: there is none.
  def self.newer_version; nil; end
  # Stands in for a step back to an older version: there is none.
  def self.rollback?; false; end
  # Stands in for cleaning a text for the screen, keeping it as it is.
  def self.clean(text); text; end
  # Stands in for a path in the game's folder, keeping it as it is.
  def self.path(name); name; end
  # Stands in for the log, which prints each line.
  module Log; def self.write(message); puts "  log: #{message}"; end; end
  # Stands in for the player, named Me.
  module Player; def self.share; end; def self.name; "Me"; end; end
  # Stands in for the ini files, which live in $ini by path.
  module Ini; def self.read(path); ($ini[path] || {}).dup; end; def self.load(path, _quiet = false); read(path); end; def self.write(path, values); $ini[path] = values.dup; true; end; end
  # Stands in for the DLL link, whose state reads come from $dll by function.
  module Link
    # A function of the DLL, which notes each call in $calls with its signature.
    Function = Struct.new(:name, :signature) do
      # Notes the call, refusing arguments its signature does not name.
      def call(*args); check_dll_call(name, args); $calls << [name, signature, args]; 1; end
    end
    # Answers a function of the DLL with its signature from Multiplayer.rb.
    def self.function(name); Function.new(name, dll_signature(name)); end
    # Answers what $dll holds for a function.
    def self.read(name, _size); $dll[name].to_s; end
    # Reads the DLL's description as Link.parse does: key=value lines, an empty line, the payload.
    #
    # @param text [String] The text.
    # @return [Hash] The fields, with the payload under :payload.
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| k, v = line.split("=", 2); state[k] = v if v }
      state
    end
  end
end
# Stands in for the world's mods, sharing no settings.
module MGQ_MpWorldMods; def self.shared?(_settings); false; end; end
$notices = []
$routes = {}
# Stands in for the world's sync, keeping each field's handler in $routes and each notice in $notices.
module MGQ_MpOverworldSync
  # The field of the relay's push of a new difficulty.
  DIFFICULTY_FIELD = "difficulty_value"
  # Keeps a field's handler in $routes.
  def self.route(field, &handler); $routes[field] = handler; end
  # Notes a notice's text in $notices.
  def self.notice(text, _icon = nil); $notices << text; end
  # Answers whether no event or message runs on the map: $quiet.
  def self.map_quiet?; $quiet; end
end
# Stands in for the co-op scope, in a Raid World whenever the open world is one.
module MGQ_MpCoop; module Scope; def self.raid?; MGQ_MpWorld.raid?; end; end; end

load_script "world_save_distribution"
load_script "ui_online"
load_script "world"
load_script "story_state"
load_script "world_difficulty"
open_rules_bridge

difficulty = MGQ_MpWorldDifficulty
# A release, unless a check says otherwise.
MGQ_MpWorld.instance_variable_set(:@dev_build, false)

# Finds a form's field by its key.
#
# @param form [MGQ_MpWorld::Form] The form.
# @param key [Symbol] The field's key.
# @return [MGQ_MpWorld::Form::Field, nil] The field.
def field_of(form, key)
  form.fields.find { |field| field.key == key }
end

# The new world's form has the Difficulty for a Raid World only.
form = MGQ_MpWorld::WorldForm.create(:new_world)
form[:name] = "Raid Night"
starting = [:from_save, :choose].map { |key| field_of(form, key) }
save = field_of(form, :save)
check("a Classic world offers its starting point and its Save on the left of its row, without the difficulty",
      [starting.map { |field| form.enabled?(field) }, save.row, save.side, field_of(form, :difficulty)], [[true, true], 4, :left, nil])
raid_bosses = field_of(form, :raid_bosses)
check("and Raid Bosses beside the Save, unticked, with a narrower Save label so both fit",
      [raid_bosses.kind, raid_bosses.label, raid_bosses.row, raid_bosses.side, raid_bosses.group, form[:raid_bosses], form.raid_bosses?, save.label_width],
      [:check, "Raid Bosses", 4, :right, "World", false, false, 40])
form[:raid_bosses] = true
check("ticked, the form has raid bosses", form.raid_bosses?, true)
form[:from_save] = true
form[:choose] = true
check("a Classic world takes a starting save and the player's choice", [form.enabled?(save), form.from_save?, form.choose?], [true, true, true])
form[:type] = 1
picked = field_of(form, :difficulty)
check("a Raid World's form has no Raid Bosses, and none even with the box ticked before", [field_of(form, :raid_bosses), form.raid_bosses?], [nil, false])
raid_from_save = field_of(form, :from_save)
raid_save = field_of(form, :save)
check("a Raid World has no Player's choice, Sharing companions on its row, its own Shared save beside the Difficulty, and its Save below",
      [starting.map { |field| form.fields.include?(field) }, field_of(form, :share).row, [raid_from_save.kind, raid_from_save.row, raid_from_save.side],
       [picked.row, picked.side, form.enabled?(picked)], [raid_save.row, raid_save.side, raid_save.label_width], form.fields.size],
      [[false, false], 3, [:check, 4, :left], [4, :right, true], [5, :left, 40], 15])
check("which offers the game's difficulties and starts on NORMAL", [picked.kind, picked.choices, form.difficulty],
      [:switch, ["VERY EASY", "EASY", "NORMAL", "HARD", "VERY HARD", "HELL", "PARADOX"], 0])
check("Shared save ticked before stays ticked, the player's choice does not, and the form asks for the save", [form.from_save?, form.choose?, form.problem],
      [true, false, [8, "Choose the save its players start from."]])
form.turn(picked, 1)
check("its switch turns to the next difficulty", [form.difficulty, MGQ_MpWorld.difficulty_name(form.difficulty)], [1, "HARD"])
form[:type] = 0
check("back on Classic the Save and Raid Bosses take their place again", [field_of(form, :difficulty), field_of(form, :save) == save, field_of(form, :raid_bosses) == raid_bosses, form.fields.size],
      [nil, true, true, 14])


# The creator's edit form has the Difficulty for a Raid World only.
listed = MGQ_MpWorld::Directory::ListedWorld.new("r1", 4, 0, "me", 0, "Me", "Raid Night", "none", [], false, false, false, false, false, "", "", "", "", "", "raid", "story", 2)
edit = MGQ_MpWorld::WorldForm.edit(:edit_world, listed, true)
check("a Raid World's edit form has the Difficulty switch below Max Players, on its difficulty",
      [edit.fields.map { |field| field.key }, field_of(edit, :seats).side, field_of(edit, :difficulty).side, field_of(edit, :difficulty).choices.size, edit.difficulty],
      [[:seats, :difficulty, :limits, :mods, :shared, :other_mods_off, :description, :confirm], nil, :left, 7, 2])
listed.difficulty = nil
unset = MGQ_MpWorld::WorldForm.edit(:edit_world, listed, false)
check("on Per player for a Raid World that sets none yet, its first outcome", [field_of(unset, :difficulty).choices.first, unset[:difficulty], unset.difficulty], ["Per player", 0, nil])
unset.turn(field_of(unset, :difficulty), 1)
check("turned on, it picks one of the game's", unset.difficulty, -2)
listed.type = "classic"
check("and a Classic world's has none", MGQ_MpWorld::WorldForm.edit(:edit_world, listed, true).fields.map { |field| field.key }.include?(:difficulty), false)

# The squad rules of a Raid World in the new world's form, what goes to the DLL, and the edit form.
squad_form = MGQ_MpWorld::WorldForm.create(:new_world)
squad_keys = [:luka, :formation, :front, :raid_front]
check("a Classic world's form has no squad rules nor their button", (squad_keys + [:limits]).map { |key| field_of(squad_form, key) }, [nil, nil, nil, nil, nil])
squad_form[:type] = 1
limits = field_of(squad_form, :limits)
check("a Raid World's form has the button of its formation limits beside the Save, and not the rules themselves",
      [[limits.kind, limits.label, limits.row, limits.side, limits.group], squad_keys.map { |key| field_of(squad_form, key) }],
      [[:button, "Set formation limits", 5, :right, "World"], [nil, nil, nil, nil]])
limits_form = squad_form.limits
check("which opens the same form each time", squad_form.limits.equal?(limits_form), true)
squad_fields = squad_keys.map { |key| field_of(limits_form, key) }
check("a form of Luka Replaceable beside the Formation Size, then the Frontline beside the Raid Frontline, then Done",
      limits_form.fields.map { |field| [field.kind, field.label, field.row, field.side] },
      [[:check, "Luka Replaceable", 0, :left], [:switch, "Formation Size", 0, :right], [:switch, "Frontline", 1, :left], [:switch, "Raid Frontline", 1, :right], [:button, "Done", 2, nil]])
check("whose title says what it sets", limits_form.title, "Formation limits")
check("the switches offer Original and 4 to 8, and 1 to 4", squad_fields[1..3].map { |field| field.choices },
      [["Original", "4", "5", "6", "7", "8"], ["1", "2", "3", "4"], ["1", "2", "3", "4"]])
check("which start on the defaults: Luka fixed, a team of four, one in front", squad_form.squad, { :luka => false, :formation => 4, :front => 1, :raid_front => 1 })
limits_form.tick(:luka)
limits_form.turn(squad_fields[1], -1)
limits_form.turn(squad_fields[2], 1)
limits_form.turn(squad_fields[3], -1)
check("ticked and turned there, the world's form picks Luka replaceable, the Original size, two in front and four in raids", squad_form.squad,
      { :luka => true, :formation => 0, :front => 2, :raid_front => 4 })
squad_listed = MGQ_MpWorld::Directory::ListedWorld.new("r1", 4, 0, "me", 0, "Me", "Raid Night", "none", [], false, false, false, false, false, "", "", "", "", "", "raid", "story", 2)
squad_listed.squad = { :luka => true, :formation => 8, :front => 4, :raid_front => 3 }
squad_edit = MGQ_MpWorld::WorldForm.edit(:edit_world, squad_listed, false)
check("a Raid World's edit form has the button of its formation limits beside the Difficulty, on the rules the world sets",
      [[field_of(squad_edit, :limits).row, field_of(squad_edit, :limits).side], squad_edit.limits.squad, squad_edit.squad],
      [[1, :right], { :luka => true, :formation => 8, :front => 4, :raid_front => 3 }, { :luka => true, :formation => 8, :front => 4, :raid_front => 3 }])
squad_listed.squad = nil
check("the defaults for one that names none", MGQ_MpWorld::WorldForm.edit(:edit_world, squad_listed, true).squad, MGQ_MpWorld.default_squad)
squad_listed.type = "classic"
check("and a Classic world's edit form has no button", field_of(MGQ_MpWorld::WorldForm.edit(:edit_world, squad_listed, true), :limits), nil)

bosses_listed = MGQ_MpWorld::Directory::ListedWorld.new("w1", 4, 0, "me", 0, "Me", "Plain", "none", [], false, false, false, false, false, "", "", "", "", "", "classic", "off", nil)
bosses_listed.raid_bosses = true
bosses_edit = MGQ_MpWorld::WorldForm.edit(:edit_world, bosses_listed, false)
bosses_field = field_of(bosses_edit, :raid_bosses)
check("a Classic world's edit form has Raid Bosses below Max Players, ticked as the world is",
      [bosses_edit.fields.index(bosses_field), bosses_field.kind, bosses_field.row, bosses_field.group, bosses_edit[:raid_bosses], bosses_edit.raid_bosses?],
      [1, :check, 1, "World", true, true])
bosses_listed.raid_bosses = false
check("unticked for a world without them", MGQ_MpWorld::WorldForm.edit(:edit_world, bosses_listed, false).raid_bosses?, false)
check("and a Raid World's edit form has none", field_of(MGQ_MpWorld::WorldForm.edit(:edit_world, squad_listed.tap { |world| world.type = "raid" }, true), :raid_bosses), nil)

# A Raid World and a Classic world on this PC.
raid_world = local_world("abcdef012345", "code" => "x", "type" => "raid", "difficulty" => "1")
plain_world = local_world("fedcba987654", "code" => "y", "type" => "classic")

# A Raid World's Shared save, as a Classic world's, but never with the player's choice.
saved_form = MGQ_MpWorld::WorldForm.create(:new_world)
saved_form[:name] = "Raid Test"
saved_form[:type] = 1
saved_save = field_of(saved_form, :save)
check("a new Raid World starts from the beginning, its Save greyed out until Shared save is ticked, its description a row shorter",
      [saved_form.from_save?, saved_form.problem, saved_form.enabled?(saved_save), field_of(saved_form, :description).lines, saved_form.fields.last.row],
      [false, nil, false, 2, 10])
saved_form[:from_save] = true
saved_form[:save] = 2
saved_form[:choose] = true
check("ticked with a save, its new players start from it, never with the player's choice", [saved_form.from_save?, saved_form.choose?, saved_form.problem], [true, false, nil])
MGQ_MpWorld.instance_variable_set(:@dev_build, nil)
$calls.clear
check("the DLL tells a development build once", [MGQ_MpWorld.dev_build?, MGQ_MpWorld.dev_build?, $calls.map { |call| call[0] }], [true, true, ["mp_dev_build"]])
MGQ_MpWorld.instance_variable_set(:@dev_build, false)

# The game's state: the enemy rates' common event notes each time it works them out.
$rates = []
$data_common_events = []
$data_common_events[112] = RPG::CommonEvent.new([RPG::EventCommand.new(355, 0, ["$rates << $game_variables[902]"])])
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_party = Struct.new(:in_battle).new(false)
$game_map = Game_Map.new
$game_map.instance_variable_set(:@interpreter, MapInterpreter.new)

# Outside a Raid World nothing changes.
$game_variables[902] = 3
DataManager.setup_new_game
check("outside a Raid World a new game keeps the player's difficulty", [$game_variables[902], $rates], [3, []])
MGQ_MpWorld.instance_variable_set(:@world, plain_world)
DataManager.load_game_without_rescue(0)
check("and so does a Classic world", [$game_variables[902], $rates], [3, []])

# A Raid World on HARD puts a loaded save and a new game on it.
MGQ_MpWorld.instance_variable_set(:@world, raid_world)
DataManager.load_game_without_rescue(0)
check("a save loaded in a Raid World plays on its difficulty, the enemy rates worked out at once", [$game_variables[902], $rates], [1, [1]])
$game_variables[902] = -2
DataManager.setup_new_game
check("and so does a new game", [$game_variables[902], $rates], [1, [1, 1]])

# The Colosseum: during a match it saved the difficulty in 908 and plays its fights on NORMAL.
$game_switches[28] = true
$game_switches[87] = true
$game_variables[908] = 1
$game_variables[902] = 0
DataManager.load_game_without_rescue(0)
30.times { $game_map.update }
check("a save loaded at the Colosseum keeps its NORMAL and the difficulty it put aside", [$game_variables[902], $game_variables[908], $rates.size], [0, 1, 2])
$game_switches[28] = false
$game_switches[87] = false
$game_variables[902] = $game_variables[908]
30.times { $game_map.update }
check("once it put the difficulty back, the world's stays without working the rates out again", [$game_variables[902], $rates.size], [1, 2])
# A defeat there puts the difficulty back and ends the match, yet leaves switch 28 on (common event 3000).
$game_switches[28] = true
$game_switches[87] = true
$game_variables[902] = 0
30.times { $game_map.update }
check("a Colosseum match keeps its NORMAL", [$game_variables[902], $rates.size], [0, 2])
$game_switches[87] = false
$game_variables[902] = $game_variables[908]
raid_world.instance_variable_set(:@difficulty, 2)
30.times { $game_map.update }
check("after a defeat there, with switch 28 still on, the world's difficulty applies again", [$game_variables[902], $rates.last], [2, 2])
$game_switches[28] = false
raid_world.instance_variable_set(:@difficulty, 1)
$game_variables[902] = 1

# A special boss on EASY and below: it saved the difficulty in 908 and fights on NORMAL.
raid_world.instance_variable_set(:@difficulty, -1)
$game_switches[23] = true
$game_variables[908] = -1
$game_variables[902] = 0
30.times { $game_map.update }
check("a special boss keeps its NORMAL while it is on", [$game_variables[902], $game_variables[908], $rates.size], [0, -1, 3])
$game_switches[23] = false
$game_variables[902] = 4
30.times { $game_map.update }
check("and once it is over, the next look puts the game back on the world's", [$game_variables[902], $rates.last], [-1, -1])

# The Labyrinth of Chaos: its rates come from its own level, not the difficulty.
raid_world.instance_variable_set(:@difficulty, 2)
$game_switches[41] = true
$game_variables[149] = 70
rates = $rates.size
DataManager.load_game_without_rescue(0)
30.times { $game_map.update }
check("in the Labyrinth of Chaos the world's difficulty waits, its level and rates stay", [$game_variables[902], $game_variables[149], $rates.size], [-1, 70, rates])
$game_switches[41] = false
$game_switches[507] = true
30.times { $game_map.update }
check("as it does at the final battles' fixed NORMAL", [$game_variables[902], $rates.size], [-1, rates])
$game_switches[507] = false

# No look while an event runs on the map or a battle is on, since either may set its own values.
$quiet = false
30.times { $game_map.update }
check("no look while an event runs on the map", $game_variables[902], -1)
$quiet = true
$game_party.in_battle = true
30.times { $game_map.update }
check("nor during a battle", $game_variables[902], -1)
$game_party.in_battle = false
29.times { $game_map.update }
check("the look comes every 30 frames", $game_variables[902], -1)
$game_map.update
check("and puts the game on the world's difficulty", [$game_variables[902], $rates.last], [2, 2])

# The relay's push changes the world's difficulty.
$routes[MGQ_MpOverworldSync::DIFFICULTY_FIELD].call(nil, MGQ_MpOverworldSync::DIFFICULTY_FIELD => "4")
check("a push not from the relay is ignored", MGQ_MpWorld.difficulty, 2)
$routes[MGQ_MpOverworldSync::DIFFICULTY_FIELD].call(nil, MGQ_MpOverworldSync::DIFFICULTY_FIELD => "4", :relay => true)
check("the relay's push changes the world's difficulty and says so", [MGQ_MpWorld.difficulty, $notices.last], [4, "The world plays on PARADOX now."])
$game_map.update
check("which the next look plays on at once", [$game_variables[902], $rates.last], [4, 4])

# The game's own difficulty choice and the Reaper's change set the world's.
$data_common_events[110] = RPG::CommonEvent.new([RPG::EventCommand.new(122, 0, [902, 902, 0, 0, -2])])
$data_common_events[146] = RPG::CommonEvent.new([RPG::EventCommand.new(117, 0, [110]), RPG::EventCommand.new(235, 0, [5])])
$erased = []
intro = [RPG::EventCommand.new(122, 0, [92, 92, 0, 0, 100]), RPG::EventCommand.new(117, 1, [110]), RPG::EventCommand.new(122, 0, [903, 903, 0, 0, -3])]
interpreter = Game_Interpreter.new
interpreter.setup(intro)
interpreter.update
check("the new game's difficulty choice sets the world's instead and works the rates out, the rest of the event as it was",
      [$game_variables[902], $game_variables[92], $game_variables[903], $rates.last, $notices.last], [4, 100, -3, 4, "The world sets the difficulty: PARADOX."])
check("the event's own commands stay as the game has them", intro.map { |command| command.code }, [122, 117, 122])
$game_variables[902] = 0
reaper = [RPG::EventCommand.new(117, 0, [146])]
interpreter.setup(reaper)
interpreter.update
check("the Reaper's difficulty change runs, its call of the choice setting the world's, and erases the Reaper's picture", [$game_variables[902], $erased, reaper.map { |command| command.parameters[0] }], [4, [5], [146]])
$game_switches[28] = true
$game_switches[87] = true
$game_variables[902] = 0
rates = $rates.size
interpreter.setup([RPG::EventCommand.new(117, 0, [110])])
interpreter.update
check("but never while the game has its own values set", [$game_variables[902], $rates.size], [0, rates])
$game_switches[28] = false
$game_switches[87] = false
raid_world.instance_variable_set(:@difficulty, nil)
interpreter.setup([RPG::EventCommand.new(117, 0, [110])])
interpreter.update
check("a Raid World that sets no difficulty leaves the choice to the player", $game_variables[902], -2)
MGQ_MpWorld.instance_variable_set(:@world, plain_world)
interpreter.setup([RPG::EventCommand.new(122, 0, [902, 902, 0, 0, 0]), RPG::EventCommand.new(117, 0, [110])])
interpreter.update
check("as does a Classic world", $game_variables[902], -2)

# The story: the difficulty and the fights' own values are each Raid World player's own, as its
# story mapping keeps no row of them.
state = MGQ_MpStoryState
MGQ_MpWorld.instance_variable_set(:@world, raid_world)
MGQ_MpStoryKeys.instance_variable_set(:@raid, MGQ_MpStoryKeys.table_of(story_table_hash([[0, 505, 0], [506, 506, 1]], [[0, 151, 0], [152, 152, 1], [153, 1000, 0], [1001, 1001, 3]], 0, "rev" => 1)))
check("in a Raid World the difficulty, the rates, the Ruler Ruler's, the records and the kept difficulty are each player's own",
      [902, 908, 41, 45, 49, 92, 99, 903, 906].map { |id| state.personal_variable?(id) }, [true] * 9)
check("and the switches of the Labyrinth, the Colosseum and its match, the special bosses and the final battles", [23, 28, 41, 87, 507].map { |id| state.personal_switch?(id) }, [true] * 5)
check("while the story's eased scaling and its progress, which the mapping shares, are the world's", [state.personal_switch?(506), state.personal_variable?(1001), state.personal_variable?(152)], [false, false, false])
story = [[nil, false, false], [nil], {}]
story[0][41] = true
story[0][28] = true
story[1][902] = -2
story[1][149] = 90
story[1][1001] = 30
mine = [[nil], [nil], {}]
mine[1][902] = 4
mine[1][149] = 5
mine[1][1001] = 20
mixed = state.mix(story, mine, [])
check("a teller's Labyrinth, Colosseum and difficulty never reach the player, the story does",
      [mixed[0][41], mixed[0][28], mixed[1][902], mixed[1][149], mixed[1][1001]], [nil, nil, 4, 5, 30])
MGQ_MpWorld.instance_variable_set(:@world, plain_world)
check("a Classic world's party keeps them each player's own too, by the same reviewed list", [state.personal_variable?(902), state.personal_switch?(41)], [true, true])
MGQ_MpWorld.instance_variable_set(:@world, nil)
