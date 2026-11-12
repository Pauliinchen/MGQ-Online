#----------------------------------------------------------------
#  raid_difficulty_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-12: Ran events in a stand-in of the game's interpreter with its fiber and called common events through its command_117
#                            - Checked that a world mod hooking the call of the enemy rates' common event sets the rates on load, new game and the opening
#                            - Checked the line a boss battle's enemies are logged with
#      Paulinchen  2026-11-07: Answered whether a fight has values of its own and whether the difficulty is due with fixed values and checked what the script asks
#      Paulinchen  2026-11-05: Left the forms' fields to the DLL's tests, checking what the edit form hands over and reads back
#                            - Put the worlds on this PC as the DLL tells them
#                            - Pushed the difficulty as the number the DLL reads
#                            - Asked whether the DLL is a development build through its topic
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

# Covers a Raid World's difficulty, squad rules and start: what the edit form hands the DLL and
# reads back, and its starting save but never a choice on entering (world.rbx,
# world_save_distribution.rbx); the world's difficulty on load, new game and the relay's push, set
# over the game's own choice and the Reaper's change, while a fight the DLL tells has values of its
# own keeps them (world_difficulty.rbx; RaidDifficultyTests own when); and these values each Raid
# World player's own in the story (story_state.rbx); the line a boss battle's enemies are logged
# with (world_difficulty.rbx).

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
# Stands in for the battle's scene, whose first command phase logs a boss battle's enemies.
class Scene_Battle; def start_party_command_selection; end; end
# Stands in for the battle's setup.
module BattleManager; def self.setup(_troop_id, _can_escape = true, _can_lose = false); end; end
# Stands in for an enemy with its numbers.
Game_Enemy = Struct.new(:enemy_id, :mhp, :atk, :def, :min_action_times, :max_action_times)
# Stands in for the battle's enemies and their troop.
class Game_Troop; attr_accessor :members; def setup(troop_id); @troop_id = troop_id; end; end
# Stands in for the story's boss battles: troop 609.
module MGQ_MpRaidBosses; def self.battle?(troop_id); troop_id == 609; end; end
$quiet = true
# The map's interpreter, running while a test says an event runs.
class MapInterpreter; def running?; !$quiet; end; end

# Stands in for RGSS3's interpreter, as far as the tests need: its fiber, a variable set to a
# constant (122), a common event's call (117), a script line (355) and a picture's erase (235).
class Game_Interpreter
  # Starts the interpreter at a call depth with no list.
  def initialize(depth = 0); @depth = depth; @list = nil; @index = 0; end
  # Takes a list to run in a fiber of its own.
  def setup(list, event_id = 0); @list = list; @index = 0; @event_id = event_id; @fiber = Fiber.new { run }; end
  # Answers whether the list still runs.
  def running?; !@fiber.nil?; end
  # Runs the list on until it waits.
  def update; @fiber.resume if @fiber; end
  # Answers that the event is on the current map.
  def same_map?; true; end

  # Runs the list's commands to their end, then waits a last time and ends.
  def run
    while @list[@index]
      execute_command
      @index += 1
    end
    Fiber.yield
    @fiber = nil
  end

  # Runs the command at the interpreter's place, when the stand-in knows it.
  def execute_command
    command = @list[@index]
    @params = command.parameters
    @indent = command.indent
    method_name = "command_#{command.code}"
    send(method_name) if respond_to?(method_name)
  end

  # Sets a variable to a constant.
  def command_122; $game_variables[@params[0]] = @params[4]; end
  # Runs a script line.
  def command_355; eval(@params[0]); end
  # Erases a picture.
  def command_235; $erased << @params[0]; end

  # Runs a common event in a child interpreter.
  def command_117
    child = Game_Interpreter.new(@depth + 1)
    child.setup($data_common_events[@params[0]].list, same_map? ? @event_id : 0)
    child.run
  end
end

# Stands in for a world mod that changes the enemy rates the way Difficulty Overhaul does: after
# the game's call of the enemy rates' common event, it writes the max HP rate over.
class Game_Interpreter
  alias world_mod_command_117 command_117
  # Calls a common event, then writes the world mod's max HP rate after the enemy rates' one.
  def command_117
    world_mod_command_117
    $game_variables[41] = WORLD_MOD_HP_RATE if @params[0] == 112
  end
end
# The max HP rate the world mod writes.
WORLD_MOD_HP_RATE = 180

# Runs an event's commands to their end, as the map's updates do.
#
# @param interpreter [Game_Interpreter] The interpreter.
# @param list [Array<RPG::EventCommand>] The commands.
def run_event(interpreter, list)
  interpreter.setup(list)
  10.times { interpreter.update if interpreter.running? }
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
  module Log; def self.write(message); ($logged ||= []) << message; puts "  log: #{message}"; end; end
  # Stands in for the player, named Me.
  module Player; def self.share; end; def self.name; "Me"; end; end
  # Stands in for the ini files, which live in $ini by path.
  module Ini; def self.read(path); ($ini[path] || {}).dup; end; def self.load(path, _quiet = false); read(path); end; def self.write(path, values); $ini[path] = values.dup; true; end; end
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
load_script "world_opening"
load_script "world_difficulty"
open_rules_bridge

difficulty = MGQ_MpWorldDifficulty
# A release, unless a check says otherwise.
MGQ_MpWorld.instance_variable_set(:@dev_build, false)

# The forms' fields and rules are the DLL's (WorldFormsTests): the edit form hands it the world's
# type, difficulty and squad rules, and reads back what the DLL adds them up to.
listed = MGQ_MpWorld::Directory::ListedWorld.new("r1", 4, 0, "me", 0, "Me", "Raid Night", "none", [], false, false, false, false, false, "", "", "", "", "", "raid", "story", 2)
listed.squad = { :luka => true, :formation => 8, :front => 4, :raid_front => 3 }
$forms.set("form.open", FormAnswers.view("edit of a Raid World turned to its first difficulty"))
edit = MGQ_MpWorld::WorldForm.edit(:edit_world, listed, true)
$forms.set("form.open")
check("a Raid World's edit form hands the DLL its type, difficulty and squad rules",
      $forms.asked("form.open").last.values_at("kind", "own") + $forms.asked("form.open").last["world"].values_at("raid", "difficulty", "squad"),
      ["edit", true, true, 2, { "luka" => true, "formation" => 8, "front" => 4, "raid_front" => 3 }])
check("and reads the difficulty and the squad rules the DLL adds up", [edit.difficulty, edit.squad], [-2, { :luka => true, :formation => 6, :front => 2, :raid_front => 3 }])

# A Raid World and a Classic world on this PC.
raid_world = local_world("abcdef012345", "code" => "x", "type" => "raid", "difficulty" => 1)
plain_world = local_world("fedcba987654", "code" => "y", "type" => "classic")

MGQ_MpWorld.instance_variable_set(:@dev_build, nil)
$calls.clear
$dev_build = true
check("the DLL tells a development build once", [MGQ_MpWorld.dev_build?, MGQ_MpWorld.dev_build?, $calls.map { |call| call[0] }], [true, true, ["update.dev_build"]])
$dev_build = nil
MGQ_MpWorld.instance_variable_set(:@dev_build, false)

# The game's state: the enemy rates' common event notes each time it works them out and sets the
# game's max HP rate, which the world mod writes over.
$rates = []
$data_common_events = []
$data_common_events[112] = RPG::CommonEvent.new([RPG::EventCommand.new(355, 0, ["$rates << $game_variables[902]"]), RPG::EventCommand.new(122, 0, [41, 41, 0, 0, 300])])
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_party = Struct.new(:in_battle).new(false)
$game_map = Game_Map.new
$game_map.instance_variable_set(:@interpreter, MapInterpreter.new)

# The DLL tells whether a fight has values of its own set ($own_values) and whether the game is due
# to be put on the world's difficulty ($due), asked with the switches it reads.
$difficulty_asked = []
$world_bridge.answer("difficulty.reads") { [23, 41, 507, 28, 87] }
$world_bridge.answer("difficulty.state") { |request| $difficulty_asked << request; { "own_values" => $own_values, "due" => $due } }
$own_values = false
$due = false

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
check("a save loaded in a Raid World plays on its difficulty, the enemy rates worked out at once through the game's call, which the world mod hooks",
      [$game_variables[902], $rates, $game_variables[41]], [1, [1], WORLD_MOD_HP_RATE])
$game_variables[902] = -2
$game_variables[41] = 0
DataManager.setup_new_game
check("and so does a new game", [$game_variables[902], $rates, $game_variables[41]], [1, [1, 1], WORLD_MOD_HP_RATE])

$own_values = true
$game_switches[28] = true
$game_switches[87] = true
$game_variables[902] = 0
rates = $rates.size
DataManager.load_game_without_rescue(0)
check("a save loaded while a fight has values of its own keeps them, its rates too", [$game_variables[902], $rates.size], [0, rates])
check("asked with the world's and the game's difficulty, the switches the DLL reads, the battle and the map",
      $difficulty_asked.last, { "world" => 1, "game" => 0, "s" => [false, false, false, true, true], "battle" => false, "quiet" => true })
30.times { $game_map.update }
check("the look every 30 frames writes nothing while the DLL says it is not due", [$game_variables[902], $rates.size], [0, rates])
$quiet = false
$game_party.in_battle = true
30.times { $game_map.update }
check("and tells the DLL of an event on the map and a battle", $difficulty_asked.last.values_at("battle", "quiet"), [true, false])
$quiet = true
$game_party.in_battle = false
$game_switches[28] = false
$game_switches[87] = false
$own_values = false
$due = true
raid_world.instance_variable_set(:@difficulty, 2)
29.times { $game_map.update }
check("the look comes every 30 frames", $game_variables[902], 0)
$game_map.update
check("and puts the game on the world's difficulty once the DLL says it is due", [$game_variables[902], $rates.last], [2, 2])
$due = false

# The relay's push changes the world's difficulty.
$routes[MGQ_MpOverworldSync::DIFFICULTY_FIELD].call(nil, MGQ_MpOverworldSync::DIFFICULTY_FIELD => 4)
check("a push not from the relay is ignored", MGQ_MpWorld.difficulty, 2)
$routes[MGQ_MpOverworldSync::DIFFICULTY_FIELD].call(nil, MGQ_MpOverworldSync::DIFFICULTY_FIELD => 4, :relay => true)
check("the relay's push changes the world's difficulty and says so", [MGQ_MpWorld.difficulty, $notices.last], [4, "The world plays on PARADOX now."])
$due = true
$game_map.update
$due = false
check("which the next look plays on at once", [$game_variables[902], $rates.last], [4, 4])

# The game's own difficulty choice and the Reaper's change set the world's.
$data_common_events[110] = RPG::CommonEvent.new([RPG::EventCommand.new(122, 0, [902, 902, 0, 0, -2])])
$data_common_events[146] = RPG::CommonEvent.new([RPG::EventCommand.new(117, 0, [110]), RPG::EventCommand.new(235, 0, [5])])
$erased = []
intro = [RPG::EventCommand.new(122, 0, [92, 92, 0, 0, 100]), RPG::EventCommand.new(117, 1, [110]), RPG::EventCommand.new(122, 0, [903, 903, 0, 0, -3])]
interpreter = Game_Interpreter.new
run_event(interpreter, intro)
check("the new game's difficulty choice sets the world's instead and works the rates out, the rest of the event as it was",
      [$game_variables[902], $game_variables[92], $game_variables[903], $rates.last, $notices.last], [4, 100, -3, 4, "The world sets the difficulty: PARADOX."])
check("the event's own commands stay as the game has them", intro.map { |command| command.code }, [122, 117, 122])
$game_variables[902] = 0
$game_variables[41] = 0
run_event(Game_MpOpeningInterpreter.new, intro)
check("the opening of a world past its start, whose interpreter calls common events itself, ends on the world mod's rates too",
      [$game_variables[902], $game_variables[41]], [4, WORLD_MOD_HP_RATE])
$game_variables[902] = 0
reaper = [RPG::EventCommand.new(117, 0, [146])]
run_event(interpreter, reaper)
check("the Reaper's difficulty change runs, its call of the choice setting the world's, and erases the Reaper's picture", [$game_variables[902], $erased, reaper.map { |command| command.parameters[0] }], [4, [5], [146]])
$own_values = true
$game_variables[902] = 0
rates = $rates.size
run_event(interpreter, [RPG::EventCommand.new(117, 0, [110])])
check("but never while the game has its own values set", [$game_variables[902], $rates.size], [0, rates])
$own_values = false
raid_world.instance_variable_set(:@difficulty, nil)
run_event(interpreter, [RPG::EventCommand.new(117, 0, [110])])
check("a Raid World that sets no difficulty leaves the choice to the player", $game_variables[902], -2)
MGQ_MpWorld.instance_variable_set(:@world, plain_world)
run_event(interpreter, [RPG::EventCommand.new(122, 0, [902, 902, 0, 0, 0]), RPG::EventCommand.new(117, 0, [110])])
check("as does a Classic world", $game_variables[902], -2)

# A boss battle's enemies are logged once, as its first command phase opens.
$game_troop = Game_Troop.new
$game_troop.members = [Game_Enemy.new(177, 216000, 850, 246, 2, 2), Game_Enemy.new(40, 900, 30, 20, 1, 2)]
[41, 42, 43, 44, 45, 48].zip([180, 250, 150, 200, 100, 125]).each { |id, rate| $game_variables[id] = rate }
scene = Scene_Battle.new
$logged = []
BattleManager.setup(609)
$game_troop.setup(609)
2.times { scene.start_party_command_selection }
BattleManager.setup(12)
$game_troop.setup(12)
scene.start_party_command_selection
check("a boss battle logs its enemies' numbers in one line once, another battle none",
      $logged.grep(/boss battle/),
      ["world difficulty: boss battle of troop 609 (alone): rates 41,42,43,44,45,48 = 180/250/150/200/100/125; " \
       "enemy 177 HP 216000 ATK 850 DEF 246 actions 2-2; enemy 40 HP 900 ATK 30 DEF 20 actions 1-2"])

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
