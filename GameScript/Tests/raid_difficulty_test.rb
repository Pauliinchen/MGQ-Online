#----------------------------------------------------------------
#  raid_difficulty_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# Covers a Raid World's difficulty and start: the new world's form without a starting point and
# with the Difficulty switch for a Raid World only, the creator's edit form, what goes to the DLL,
# no starting save or choice on entering (world.rbx, world_save_distribution.rbx); the world's
# difficulty on entry, load, new game and after the relay's push, the game's own choice and the
# Reaper's change set to the world's, and the Labyrinth of Chaos's, the Colosseum's and the special
# bosses' own values left alone (world_difficulty.rbx); and these values each Raid World player's
# own in the story (story_state.rbx).

require_relative "support"

# Stand-ins for the game.
class Scene_Base; def return_scene; end; end
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
class Scene_Title; def start; end; def create_command_window; end; def close_command_window; end; def update; end; def terminate; end; end
class Window_TitleCommand; def make_command_list; end; end
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") {} }; end
module SceneManager; def self.call(_scene); end; end
module RPG
  EventCommand = Struct.new(:code, :indent, :parameters)
  CommonEvent = Struct.new(:list)
end
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
class Game_Map; def update(_main = false); end; end
$quiet = true
# The map's interpreter, running while a test says an event runs.
class MapInterpreter; def running?; !$quiet; end; end

# Runs an event's commands as the game's interpreter does, as far as the tests need: a variable set
# to a constant (122), a common event's call (117), a comment (108), a script line (355) and a
# picture's erase (235).
class Game_Interpreter
  def setup(list, _event_id = 0); @list = list; @index = 0; @running = true; end
  def running?; @running; end

  def update
    while @list[@index]
      execute_command
      @index += 1
    end
    @running = false
  end

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
module DataManager
  def self.save_system; end
  def self.load_game_without_rescue(_index); true; end
  def self.setup_new_game; end
end

# Stand-ins for the mod's base script and its DLL.
$calls = []
$dll = {}
$ini = {}
module MGQ_Multiplayer
  UPDATE_MESSAGE = "Update."
  def self.available?; true; end
  def self.outdated?; false; end
  def self.newer_version; nil; end
  def self.clean(text); text; end
  def self.path(name); name; end
  module Log; def self.write(message); puts "  log: #{message}"; end; end
  module Player; def self.share; end; def self.name; "Me"; end; end
  module Ini; def self.read(path); ($ini[path] || {}).dup; end; def self.write(path, values); $ini[path] = values.dup; true; end; end
  module Link
    Function = Struct.new(:name, :signature) do
      def call(*args); check_dll_call(name, args); $calls << [name, signature, args]; 1; end
    end
    def self.function(name); Function.new(name, dll_signature(name)); end
    def self.read(name, _size); $dll[name].to_s; end
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| k, v = line.split("=", 2); state[k] = v if v }
      state
    end
  end
end
module MGQ_MpWorldMods; def self.shared?(_settings); false; end; end
$notices = []
$routes = {}
module MGQ_MpOverworldSync
  DIFFICULTY_FIELD = "difficulty_value"
  def self.route(field, &handler); $routes[field] = handler; end
  def self.notice(text, _icon = nil); $notices << text; end
  def self.map_quiet?; $quiet; end
end
module MGQ_MpCoop; module Scope; def self.raid?; MGQ_MpWorld.raid?; end; end; end

load_script "world_save_distribution"
load_script "ui"
load_script "ui_text_box"
load_script "world"
load_script "story_state"
load_script "world_difficulty"

difficulty = MGQ_MpWorldDifficulty

# Finds a form's field by its key.
#
# @param form [MGQ_MpWorld::Form] The form.
# @param key [Symbol] The field's key.
# @return [MGQ_MpWorld::Form::Field, nil] The field.
def field_of(form, key)
  form.fields.find { |field| field.key == key }
end

# The new world's form.
form = MGQ_MpWorld::Form.create
form[:name] = "Raid Night"
starting = [:from_save, :choose].map { |key| field_of(form, key) }
save = field_of(form, :save)
check("a Classic world offers its starting point and its Save across the row, without the difficulty",
      [starting.map { |field| form.enabled?(field) }, save.row, save.side, field_of(form, :difficulty)], [[true, true], 5, nil, nil])
form[:from_save] = true
form[:choose] = true
check("a Classic world takes a starting save and the player's choice", [form.enabled?(save), form.from_save?, form.choose?], [true, true, true])
form[:type] = 1
picked = field_of(form, :difficulty)
check("a Raid World greys the starting point out and has the Difficulty across the Save's row instead",
      [starting.map { |field| form.enabled?(field) }, field_of(form, :save), picked.row, picked.side, form.enabled?(picked), form.fields.size], [[false, false], nil, 5, nil, true, 14])
check("which offers the game's difficulties and starts on NORMAL", [picked.kind, picked.choices, form.difficulty],
      [:switch, ["VERY EASY", "EASY", "NORMAL", "HARD", "VERY HARD", "HELL", "PARADOX"], 0])
check("whose hint fits the lines at the top, as the starting point's do", ([picked] + starting).map { |field| field.hint.size <= 100 }, [true, true, true])
check("and starts from the beginning even with the boxes ticked before", [form.from_save?, form.choose?, form.problem], [false, false, nil])
form.turn(picked, 1)
check("its switch turns to the next difficulty", [form.difficulty, MGQ_MpWorld.difficulty_name(form.difficulty)], [1, "HARD"])
form[:type] = 0
check("back on Classic the Save takes its place again", [field_of(form, :difficulty), field_of(form, :save).equal?(save), form.fields.size], [nil, true, 14])

# What goes to the DLL.
MGQ_MpWorld::Directory.create("Raid Night", "", 4, false, true, "Save01.rvdata2=Save/Save01.rvdata2", :type => "raid", :share => "story", :difficulty => 3)
args = $calls.last[2]
check("a Raid World goes without a starting save and the player's choice, with its difficulty", [$calls.last[1], args[4], args[5], args[12], args[14]],
      ["pplllpppplppppl", 0, "\0", "raid\0", 3])
MGQ_MpWorld::Directory.create("Raid Plain", "", 4, false, false, "", :type => "raid")
check("on NORMAL unless told otherwise", $calls.last[2][14], 0)
MGQ_MpWorld::Directory.create("Plain", "", 4, false, true, "Save01.rvdata2=Save/Save01.rvdata2", :difficulty => 3)
check("a Classic world keeps both, and its difficulty is left at NORMAL, which the relay drops", [$calls.last[2][4], $calls.last[2][5], $calls.last[2][14]],
      [1, "Save01.rvdata2=Save/Save01.rvdata2\0", 0])
MGQ_MpWorld::Directory.edit("r1", 6, "", "", nil, -2)
check("an edit hands a Raid World's difficulty to the DLL", [$calls.last[1], $calls.last[2][6..7]], ["plppplll", [-2, 1]])
MGQ_MpWorld::Directory.edit("w1", 6, "", "")
check("and none for a Classic world", $calls.last[2][6..7], [0, 0])

# The creator's edit form.
listed = MGQ_MpWorld::Directory::ListedWorld.new("r1", 4, 0, "me", 0, "Me", "Raid Night", "none", [], false, false, false, false, false, "", "", "", "", "", "raid", "story", 2)
edit = MGQ_MpWorld::Form.edit(listed, true)
check("a Raid World's edit form has the Difficulty switch below Max Players, on its difficulty",
      [edit.fields.map { |field| field.key }, field_of(edit, :seats).side, field_of(edit, :difficulty).side, field_of(edit, :difficulty).choices.size, edit.difficulty],
      [[:seats, :difficulty, :mods, :data, :shared, :description, :confirm], nil, nil, 7, 2])
listed.difficulty = nil
unset = MGQ_MpWorld::Form.edit(listed, false)
check("on Per player for a Raid World that sets none yet, its first outcome", [field_of(unset, :difficulty).choices.first, unset[:difficulty], unset.difficulty], ["Per player", 0, nil])
unset.turn(field_of(unset, :difficulty), 1)
check("turned on, it picks one of the game's", unset.difficulty, -2)
listed.type = "classic"
check("and a Classic world's has none", MGQ_MpWorld::Form.edit(listed, true).fields.map { |field| field.key }.include?(:difficulty), false)

# Entering: a Raid World never asks where to start nor fetches a starting save.
raid_world = MGQ_MpWorld::World.new("abcdef012345", "code" => "x", "type" => "raid", "difficulty" => "1")
plain_world = MGQ_MpWorld::World.new("fedcba987654", "code" => "y", "type" => "classic")
[raid_world, plain_world].each { |world| world.define_singleton_method(:latest_save) { nil } }
check("a new player of a Raid World starts a new game, even if it was made with a choice or a save",
      [MGQ_MpSaveDistribution.ask_start?(raid_world, true), MGQ_MpSaveDistribution.fetch?(raid_world, "ready")], [false, false])
check("while a Classic world asks and fetches as before", [MGQ_MpSaveDistribution.ask_start?(plain_world, true), MGQ_MpSaveDistribution.fetch?(plain_world, "ready")], [true, true])

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

# A Raid World on HARD.
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
raid_world.difficulty = 2
30.times { $game_map.update }
check("after a defeat there, with switch 28 still on, the world's difficulty applies again", [$game_variables[902], $rates.last], [2, 2])
$game_switches[28] = false
raid_world.difficulty = 1
$game_variables[902] = 1

# A special boss on EASY and below: it saved the difficulty in 908 and fights on NORMAL.
raid_world.difficulty = -1
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
raid_world.difficulty = 2
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

# The relay's push of a new difficulty.
$routes[MGQ_MpOverworldSync::DIFFICULTY_FIELD].call(nil, MGQ_MpOverworldSync::DIFFICULTY_FIELD => "4")
check("a push not from the relay is ignored", MGQ_MpWorld.difficulty, 2)
$routes[MGQ_MpOverworldSync::DIFFICULTY_FIELD].call(nil, MGQ_MpOverworldSync::DIFFICULTY_FIELD => "4", :relay => true)
check("the relay's push changes the world's difficulty and says so", [MGQ_MpWorld.difficulty, $notices.last], [4, "The world plays on PARADOX now."])
$game_map.update
check("which the next look plays on at once", [$game_variables[902], $rates.last], [4, 4])

# The game's own difficulty choice and the Reaper's change.
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
raid_world.difficulty = nil
interpreter.setup([RPG::EventCommand.new(117, 0, [110])])
interpreter.update
check("a Raid World that sets no difficulty leaves the choice to the player", $game_variables[902], -2)
MGQ_MpWorld.instance_variable_set(:@world, plain_world)
interpreter.setup([RPG::EventCommand.new(122, 0, [902, 902, 0, 0, 0]), RPG::EventCommand.new(117, 0, [110])])
interpreter.update
check("as does a Classic world", $game_variables[902], -2)

# The story: the difficulty and the fights' own values are each Raid World player's own.
state = MGQ_MpStoryState
MGQ_MpWorld.instance_variable_set(:@world, raid_world)
check("in a Raid World the difficulty, the rates, the Ruler Ruler's, the records and the kept difficulty are each player's own",
      [902, 908, 41, 45, 49, 92, 99, 903, 906].map { |id| state.personal_variable?(id) }, [true] * 9)
check("as are the Labyrinth's floors, area, level and tier", [121, 123, 149, 151].map { |id| state.personal_variable?(id) }, [true] * 4)
check("and the switches of the Labyrinth, the Colosseum and its match, the special bosses and the final battles", [23, 28, 41, 87, 507].map { |id| state.personal_switch?(id) }, [true] * 5)
check("while the story's eased scaling and its progress are the world's", [state.personal_switch?(506), state.personal_variable?(1001), state.personal_variable?(152)], [false, false, false])
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
check("a Classic world's party stories stay as they were", [state.personal_variable?(902), state.personal_switch?(41)], [false, false])
MGQ_MpWorld.instance_variable_set(:@world, nil)
