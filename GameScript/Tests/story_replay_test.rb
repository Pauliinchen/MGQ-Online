#----------------------------------------------------------------
#  story_replay_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Checked that a replay takes a key item it uses up, and dropped the copy got as found
#                            - Checked that a member ahead keeps the route's key items when the leader returns to the Great Decision
#                            - Checked the replayer's lists against the fixture the generator's gate is checked against, instead of reading C# source
#                            - Checked that another player's battle drop gives its item with its notice
#      Paulinchen  2026-11-01: Checked that a choice the record lacks is asked with what its cancel answers
#                            - Covered a replay that costs nothing and follows the opener through the checks of what the party holds
#                            - Covered a replay done with the receiver's own answer only when it differs from the opener's
#                            - Covered a replay giving a key item the receiver got as found
#                            - Covered a choice noted at its Show Choices by its place among the kept commands, and the shapes a take hands over
#                            - Covered an extended choice noted at the script command that shows it, and asked with the answers the game shows
#      Paulinchen  2026-10-31: Checked that a party run's entry is kept in the party's stream at once
#                            - Covered asking the receiver a number, item or present the record lacks
#                            - Covered a replay committing only once it finished
#                            - Created
#
#----------------------------------------------------------------

# Covers story_replay.rbx: a run replayed in the receiving game, over an interpreter that runs its
# commands as the game's scripts 042, 148 and 167 do. The receiver's own keys decide, a world key
# reads its start value and never reaches the save, the page stays bound to its map and event, the
# presentation and the opener's play stay shut, the record answers the inputs, a replay keeps
# nothing until it finished and reached its step, the codes and functions the replay leaves out
# are those the generator's gate closes, and another player's battle drop gives its item.

require "json"
require_relative "support"

$log = []
# Stands in for the mod's log, keeping its lines in $log.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end

# The game's constants the scripts name.
module NWConst; module Var; MAP_TRANSFER = 57; EX_CHOICE_RESULT = 15; end; end

# The game's database objects, as RPG_Module has them.
module RPG
  EventCommand = Struct.new(:code, :indent, :parameters)
  MoveCommand = Struct.new(:code, :parameters)
  MoveRoute = Struct.new(:list, :wait)
  Page = Struct.new(:list)
  Event = Struct.new(:pages)
  Map = Struct.new(:events)
  CommonEvent = Struct.new(:list)
  # Music, which plays through Audio.
  class BGM; def initialize(name); @name = name; end; def play; Audio.bgm_play(@name); end; end
end

# Stands in for the sound, noting what plays in $played.
module Audio; def self.bgm_play(name); $played << name; end; end
# Stands in for the scene manager, noting the scenes called in $scenes.
module SceneManager; def self.call(scene); $scenes << scene; end; def self.scene; :map; end; end
# A scene the events open.
class Scene_JobChange; end
# Stands in for the frame counter.
module Graphics; def self.update; end; def self.frame_count; 0; end; end
# Stands in for the keyboard: no key pressed.
module Input; def self.press?(_key); false; end; end
# The maps' files by id, as DataManager names them.
module DataManager; def self.map_file_name(id); "Map#{id}"; end; end
$maps = {}
# Reads a map's file: the map of $maps.
#
# @param name [String] The file, such as "Map215".
# @return [RPG::Map] The map.
def load_data(name); $maps.fetch(name[/\d+/].to_i); end

# Stands in for the game's switches, off unless set, refreshing the map as the game does.
class Game_Switches
  def initialize; @data = []; end
  def [](id); @data[id] || false; end
  def []=(id, value); @data[id] = value; $game_map.need_refresh = true; end
end
# Stands in for the game's variables, 0 unless set.
class Game_Variables
  def initialize; @data = []; end
  def [](id); @data[id] || 0; end
  def []=(id, value); @data[id] = value; end
end
# Stands in for the game's self switches, with script 148's reset of maps.
class Game_SelfSwitches
  def initialize; @data = {}; end
  def [](key); @data[key] == true; end
  def []=(key, value); @data[key] = value; end
  def delete(map_ids); @data.reject! { |key, _| map_ids.include?(key[0]) }; end
end
# Stands in for the message the window shows: text, and a choice or an extended choice (script 223)
# that waits for its answer.
class Game_Message
  attr_reader :texts, :choices
  attr_accessor :choice_proc, :choice_cancel_type, :num_input_variable_id, :num_input_digits_max, :item_choice_variable_id, :present_actor_id
  attr_accessor :ex_choice_item, :ex_choice_setting
  def initialize; clear; ex_choice_clear; @present_actor_id = 0; end
  def ex_choice_clear; @ex_choice_item = []; @ex_choice_setting = nil; end
  def ex_choice?; @ex_choice_setting; end
  def clear; @texts = []; @choices = []; @choice_proc = nil; @num_input_variable_id = 0; @num_input_digits_max = 0; @item_choice_variable_id = 0; end
  def add(text); @texts << text; end
  def choice?; !@choices.empty?; end
  def num_input?; @num_input_variable_id > 0; end
  def item_choice?; @item_choice_variable_id > 0; end
  def present_choice?; @present_actor_id > 0; end
  def busy?; !@texts.empty? || choice? || num_input? || item_choice? || present_choice? || !@ex_choice_setting.nil?; end
end
# Stands in for a screen, noting the pictures shown.
class Game_Screen; attr_reader :pictures; def initialize; @pictures = []; end; def show_picture(name); @pictures << name; end; end
# Stands in for the player, noting a reserved transfer and the place they stand.
class Game_Player
  attr_reader :reserved, :x
  def initialize; @x = 7; end
  def reserve_transfer(*args); @reserved = args; end
  def transfer?; false; end
  def force_move_route(_route); @moved = true; end
  def moved?; @moved == true; end
end
# Stands in for the timer.
class Game_Timer; def sec; 0; end; def working?; false; end; end
# Stands in for the map: map 3, with its screen, its refresh, its own interpreter, and its events and
# parallel common events, which a transfer makes anew (script 033).
class Game_Map
  attr_accessor :map_id, :events, :need_refresh, :screen
  attr_reader :interpreter
  def initialize; @map_id = 3; @events = {}; @screen = Game_Screen.new; @interpreter = Game_Interpreter.new; @common_events = []; end
  def vehicles; []; end
  def update; end
end
# Stands in for a map event: the interpreter of its parallel page (script 041).
class Game_Event; attr_reader :id; def initialize(id); @id = id; @interpreter = Game_Interpreter.new; end; end
# Stands in for the battle manager: the handler of a battle's outcome, which the battle's end calls
# (script 009).
module BattleManager
  def self.event_proc=(proc); @event_proc = proc; end
  def self.battle_end(result); @event_proc.call(result) if @event_proc; @event_proc = nil; end
end
# Stands in for the party: items by id, gold and its unlock level.
class Game_Party
  attr_accessor :unlock_level
  attr_reader :gold
  def initialize; @items = Hash.new(0); @gold = 0; @unlock_level = 0; end
  def gain_item(item, amount); @items[item.respond_to?(:id) ? item.id : item] += amount; end
  def lose_item(item, amount); gain_item(item.id, -amount); end
  def gain_gold(amount); @gold += amount; end
  def all_items; @items.keys.sort.select { |id| @items[id] > 0 }.map { |id| $data_items[id] }.compact; end
  def item_number(id); @items[id]; end
  def in_battle; false; end
end
# Stands in for a companion: their affection and the presents they take.
class Game_Actor
  attr_accessor :love
  def initialize(id); @id = id; @love = 0; end
  def exist_present?(item_id); item_id == 700; end
  def present_loveup(_item_id); 5; end
end
# Stands in for the actors, each made when first asked for (script 029).
class Game_Actors; def initialize; @data = []; end; def [](id); @data[id] ||= Game_Actor.new(id); end; end
# Stands in for the temporary data: the medals the popup shows and the present picked.
class Game_Temp; attr_accessor :choice_present_id; def initialize; @gain_medals = []; end; def gain_medal_push(id); @gain_medals << id; end; end
# Stands in for the library: the medals gained, which pop up (script 159).
class Game_Library; attr_reader :medals; def initialize; @medals = []; end; def gain_medal(id); @medals << id; $game_temp.gain_medal_push(id); end; end

# Stands in for the game's interpreter, its commands as scripts 042, 148 and 167 run them.
class Game_Interpreter
  attr_reader :map_id, :event_id
  def initialize(depth = 0); @depth = depth; clear; end
  def clear; @map_id = 0; @event_id = 0; @list = nil; @index = 0; @branch = {}; @fiber = nil; end
  def setup(list, event_id = 0); clear; @map_id = $game_map.map_id; @event_id = event_id; @list = list; create_fiber; end
  def create_fiber; @fiber = Fiber.new { run } if @list; end
  def same_map?; @map_id == $game_map.map_id; end
  def run; wait_for_message; while @list[@index]; execute_command; @index += 1; end; Fiber.yield; @fiber = nil; end
  def running?; @fiber != nil; end
  def update; @fiber.resume if @fiber; end
  def screen; $game_map.screen; end
  def execute_command; command = @list[@index]; @params = command.parameters; @indent = command.indent; send("command_#{command.code}") if respond_to?("command_#{command.code}"); end
  def command_skip; @index += 1 while @list[@index + 1].indent > @indent; end
  def next_event_code; @list[@index + 1].code; end
  def get_character(param); param < 0 ? $game_player : (same_map? ? $game_map.events : {})[param > 0 ? param : @event_id]; end
  def wait(duration); duration.times { Fiber.yield }; end
  def wait_for_message; Fiber.yield while $game_message.busy?; end
  def command_0; end
  def command_101
    wait_for_message
    while next_event_code == 401; @index += 1; $game_message.add(@list[@index].parameters[0]); end
    case next_event_code
    when 102 then @index += 1; setup_choices(@list[@index].parameters)
    when 103 then @index += 1; $game_message.num_input_variable_id = @list[@index].parameters[0]; $game_message.num_input_digits_max = @list[@index].parameters[1]
    when 104 then @index += 1; $game_message.item_choice_variable_id = @list[@index].parameters[0]
    end
    wait_for_message
  end
  def command_102; wait_for_message; setup_choices(@params); Fiber.yield while $game_message.choice?; end
  def setup_choices(params); params[0].each { |s| $game_message.choices.push(s) }; $game_message.choice_cancel_type = params[1]; $game_message.choice_proc = proc { |n| @branch[@indent] = n }; end
  def command_402; command_skip if @branch[@indent] != @params[0]; end
  def command_111
    result = case @params[0]
             when 0 then $game_switches[@params[1]] == (@params[2] == 0)
             when 1 then $game_variables[@params[1]] == @params[3]
             when 2 then @event_id > 0 && $game_self_switches[[@map_id, @event_id, @params[1]]] == (@params[2] == 0)
             when 7 then $game_party.gold >= @params[1]
             when 8 then $game_party.item_number(@params[1]) > 0
             when 11 then Input.press?(@params[1])
             when 12 then eval(@params[1])
             end
    @branch[@indent] = result
    command_skip unless @branch[@indent]
  end
  def command_411; command_skip if @branch[@indent]; end
  def command_115; @index = @list.size; end
  def command_117; common_event = $data_common_events[@params[0]]; return unless common_event; child = Game_Interpreter.new(@depth + 1); child.setup(common_event.list, same_map? ? @event_id : 0); child.run; end
  def command_121; (@params[0]..@params[1]).each { |id| $game_switches[id] = @params[2] == 0 }; end
  def command_122
    value = case @params[3]
            when 2 then @params[4] + rand(@params[5] - @params[4] + 1)
            when 3 then game_data_operand(@params[4], @params[5], @params[6])
            else @params[4]
            end
    $game_variables[@params[0]] = value
  end
  def game_data_operand(type, param1, _param2); type == 7 ? $game_party.gold : $game_party.item_number(param1); end
  def command_123; $game_self_switches[[@map_id, @event_id, @params[0]]] = @params[1] == 0 if @event_id > 0; end
  def command_125; $game_party.gain_gold(@params[0] == 0 ? @params[2] : -@params[2]); end
  def command_126; $game_party.gain_item(($data_items && $data_items[@params[0]]) || @params[0], @params[1] == 0 ? @params[3] : -@params[3]); end
  def command_201
    if $game_variables[NWConst::Var::MAP_TRANSFER] > 0
      map_id = $game_variables[NWConst::Var::MAP_TRANSFER]
      $game_variables[NWConst::Var::MAP_TRANSFER] = 0
    else
      map_id = @params[1]
    end
    $game_player.reserve_transfer(map_id, @params[2], @params[3])
  end
  def command_205; character = get_character(@params[0]); character.force_move_route(@params[1]) if character; end
  def command_230; wait(@params[0]); end
  def command_231; screen.show_picture(@params[1]); end
  def command_241; @params[0].play; end
  def command_301; BattleManager.event_proc = proc { |n| @branch[@indent] = n }; SceneManager.call(:battle); Fiber.yield; end
  def command_601; command_skip if @branch[@indent] != 0; end
  def command_603; command_skip if @branch[@indent] != 2; end
  def command_355; script = @list[@index].parameters[0] + "\n"; while next_event_code == 655; @index += 1; script += @list[@index].parameters[0] + "\n"; end; eval(script); end
  def unlock_level; $game_party.unlock_level; end
  def gain_medal(id); $game_library.gain_medal(id); end
  def ex_choice_add(name, id, e = "true", disable = 0); $game_message.ex_choice_item.push([name, id, e, disable]); end
  def ex_choice_show(cancel = -1, row_max = 14, pos = [0, 0]); $game_message.ex_choice_setting = [cancel, row_max, pos]; wait_for_message; end
  def present_start(actor_id)
    loop do
      wait_for_message
      $game_message.present_actor_id = actor_id
      Fiber.yield while $game_message.present_choice?
      return if $game_temp.choice_present_id < 1
    end
  end
end

$data_common_events = []
load_script "story_state"
load_script "story_replay"

# A command of a list.
#
# @param code [Integer] Its code.
# @param params [Array] Its parameters.
# @param indent [Integer] Its depth in branches.
# @return [RPG::EventCommand] The command.
def c(code, *params, indent: 0); RPG::EventCommand.new(code, indent, params); end

# Puts a page on a map of $maps.
#
# @param map [Integer] The map.
# @param event [Integer] The event.
# @param list [Array<RPG::EventCommand>] The page's commands, the list's end added.
def page(map, event, list)
  ($maps[map] ||= RPG::Map.new({})).events[event] = RPG::Event.new([RPG::Page.new(list + [c(0)])])
end

# Starts the receiver's game: their own save, on map 3.
def new_game
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_self_switches = Game_SelfSwitches.new
  $game_message = Game_Message.new
  $game_player = Game_Player.new
  $game_timer = Game_Timer.new
  $game_map = Game_Map.new
  $game_party = Game_Party.new
  $game_actors = Game_Actors.new
  $game_temp = Game_Temp.new
  $game_library = Game_Library.new
  $played = []
  $scenes = []
end

# The world keys of the tests: the switches 1500-1599, the variables from 1000 and map 588's self
# switches; and the work key v57.
WORLD = lambda { |kind, key| (kind == 0 && (1500..1599).include?(key)) || (kind == 1 && (key >= 1000 || key == 57)) || (kind == 2 && key[0] == 588) }

# Replays a page of a map.
#
# @param site [String] The run's site.
# @param fields [Hash] The run's other fields: "start" and "inputs".
# @return [MGQ_MpStoryReplay::Replay] The replay.
def replay(site, fields = {})
  MGQ_MpStoryReplay.play({ "site" => site }.merge(fields), :view => WORLD)
end

# The mod's hooks on the game's interpreter, which a replay must not reach.
$hooked = []
MGQ_MpHooks.after(Game_Interpreter, :run, "coop_events") { $hooked << :run }
MGQ_MpHooks.before(Game_Interpreter, :execute_command, "coop_gather") { $hooked << :command }

# A Makina chest, 215:23: if 2045 is off, the Makina and 2045; the chest's own A. The opener's 2045
# was on; the receiver's is off, and the receiver's own decides.
new_game
page(215, 23, [c(111, 0, 2045, 1), c(126, 606, 0, 0, 1, indent: 1), c(121, 2045, 2045, 0, indent: 1), c(412), c(123, "A", 0)])
done = replay("map:215:23:1")
check("a Makina chest replayed for a receiver whose 2045 is off gives the Makina, 2045 and the chest's A",
      [done.state, $game_party.item_number(606), $game_switches[2045], $game_self_switches[[215, 23, "A"]]], [:done, 1, true, true])
check("and neither the receiver's map nor the mod's hooks on the interpreter saw it", [$game_self_switches[[3, 23, "A"]], $hooked], [false, []])
check("the replay notes the receiver's own keys it read", done.reads, { "s2045" => "0" })

# A world chest whose opened key arrived by value already (588:9): it reads the run's start value,
# gives, and the save keeps its own value of the key.
new_game
$game_self_switches[[588, 9, "A"]] = true
page(588, 9, [c(111, 2, "A", 1), c(123, "A", 0, indent: 1), c(126, 606, 0, 0, 1, indent: 1), c(412)])
done = replay("map:588:9:1", "start" => { "ss588.9.A" => "0" })
check("a world chest whose opened key already arrived still gives", $game_party.item_number(606), 1)
check("and the replay's write of the world key stayed in the view", [$game_self_switches[[588, 9, "A"]], done.writes.last], [true, [2, [588, 9, "A"], true, true]])

# A gift page that branches on a world key it writes itself (36:24): it goes the opener's way.
new_game
$game_variables[1020] = 3
page(36, 24, [c(111, 1, 1020, 0, 2), c(122, 1020, 1020, 0, 0, 3, indent: 1), c(126, 511, 0, 0, 1, indent: 1), c(412)])
replay("map:36:24:1", "start" => { "v1020" => "n2" })
check("a gift page that branches on a world key it writes goes the opener's way, and the save keeps its own value",
      [$game_party.item_number(511), $game_variables[1020]], [1, 3])

# A locked chest: the receiver's own party cannot unlock it, so it writes nothing and gives nothing.
new_game
page(419, 24, [c(111, 12, "unlock_level < 1"), c(101, "", 0, 0, 2, indent: 1), c(401, "It is locked.", indent: 1), c(115, indent: 1), c(412),
               c(126, 606, 0, 0, 1), c(123, "A", 0)])
done = replay("map:419:24:1")
check("a chest the receiver's party cannot unlock writes and gives nothing", [done.state, done.writes, $game_party.item_number(606)], [:done, [], 0])
$game_party.unlock_level = 1
replay("map:419:24:1")
check("once the party can unlock, the same replay gives it", [$game_party.item_number(606), $game_self_switches[[419, 24, "A"]]], [1, true])

# A page off the receiver's map calls a common event whose Control Self Switch belongs to the
# calling event (CE 106).
new_game
$data_common_events[106] = RPG::CommonEvent.new([c(123, "B", 0), c(0)])
page(216, 4, [c(117, 106)])
replay("map:216:4:1")
check("a common event a page off the map calls sets the bound event's self switch, not the current map's",
      [$game_self_switches[[216, 4, "B"]], $game_self_switches[[3, 4, "B"]]], [true, false])

# The page the receiver's game picked, a sibling of the run's page, is the one replayed.
new_game
$maps[2] = RPG::Map.new({ 5 => RPG::Event.new([RPG::Page.new([c(126, 20, 0, 0, 1), c(0)]), RPG::Page.new([c(126, 21, 0, 0, 1), c(0)])]) })
MGQ_MpStoryReplay.play({ "site" => "map:2:5:1" }, :view => WORLD, :page => 2)
check("the page the receiver's game picked is the one replayed", [$game_party.item_number(20), $game_party.item_number(21)], [0, 1])

# Nothing shows, the player stays, no scene opens and no sound plays; a move route's switch still
# turns on; a battle with no record counts as won, a recorded loss as lost.
new_game
route = RPG::MoveRoute.new([RPG::MoveCommand.new(1, []), RPG::MoveCommand.new(27, [31]), RPG::MoveCommand.new(0, [])], true)
page(1502, 30, [c(101, "", 0, 0, 2), c(401, "A chest!"), c(231, 1, "flash"), c(241, RPG::BGM.new("Fanfare")), c(205, -1, route), c(230, 60),
                c(355, "SceneManager.call(Scene_JobChange)"), c(355, "gain_medal(104)"), c(201, 0, 20, 5, 5, 2),
                c(301, 0, 12, false, false), c(601), c(126, 3317, 0, 0, 1, indent: 1), c(603), c(126, 1, 0, 0, 1, indent: 1), c(604)])
done = replay("map:1502:30:1")
check("nothing shows, the player neither moves nor transfers, and no scene opens and no sound plays",
      [$game_message.busy?, $game_map.screen.pictures, $game_player.reserved, $game_player.moved?, $scenes, $played], [false, [], nil, false, [], []])
check("a move route's switch still turns on, and the medal goes to the notice instead of the popup",
      [$game_switches[31], $game_library.medals, done.medals, MGQ_MpGame.get($game_temp, :gain_medals)], [true, [104], [104], []])
check("a battle with no record counts as won", [$game_party.item_number(3317), $game_party.item_number(1)], [1, 0])
replay("map:1502:30:1", "inputs" => [["map:1502:30:1@4", 0, "battle", 2]])
check("a recorded loss takes the loss's branch", $game_party.item_number(1), 1)

# A stage pay-out (CE 129) sets the transfer's map v57 before the transfer the replay never makes,
# and a world value arriving while the replay waits for the receiver's answer stays.
new_game
page(624, 202, [c(122, 57, 57, 0, 0, 1980), c(201, 0, 1, 1, 1, 2), c(101, "", 0, 0, 2), c(401, "Take the prize?"), c(102, ["Yes", "No"], 2),
                c(402, 0, "Yes", indent: 0), c(126, 77, 0, 0, 1, indent: 1), c(404), c(111, 0, 1500, 0), c(121, 1501, 1501, 0, indent: 1), c(412)])
waiting = replay("map:624:202:1", "start" => { "s1500" => "0" })
asked = [waiting.state, waiting.question && waiting.question["labels"], waiting.question && waiting.question["lines"]]
$game_switches[1500] = true
waiting.answer(0)
check("an answer the record lacks is asked with the choice's labels and lines", asked, [:asking, ["Yes", "No"], ["Take the prize?"]])
check("the save never holds the replay's work key v57, and a world value that arrived while it waited stays",
      [waiting.state, $game_variables[57], $game_switches[1500], $game_switches[1501], $game_party.item_number(77)], [:done, 0, true, false, 1])

# A sibling page's common event reads a world key the run's page never reads (78:36 page 3): it
# reads the run's start value too.
new_game
$game_variables[1103] = 9
$data_common_events[310] = RPG::CommonEvent.new([c(111, 1, 1103, 0, 5), c(126, 900, 0, 0, 1, indent: 1), c(412), c(0)])
page(78, 36, [c(117, 310)])
replay("map:78:36:1", "start" => { "v1103" => "n5" })
check("a called common event reads the run's start value of a key only it reads", $game_party.item_number(900), 1)

# The opener's choice and random draw are used, the record naming each by its command's place.
new_game
page(1994, 42, [c(102, ["Give", "Keep"], 2), c(402, 0, "Give"), c(126, 10, 0, 0, 1, indent: 1), c(402, 1, "Keep"), c(126, 11, 0, 0, 1, indent: 1), c(404),
                c(122, 200, 200, 0, 2, 1, 100)])
replay("map:1994:42:1", "inputs" => [["map:1994:42:1@0", 0, "choice", 1], ["map:1994:42:1@6", 0, "rand", 41]])
check("a recorded choice and random draw are used", [$game_party.item_number(10), $game_party.item_number(11), $game_variables[200]], [0, 1, 42])

# The Fortune Teller (51:23): her intro behind self switch A, then the trade of a wrist for a job
# item behind a check that the party holds the wrist, which turns B on. The opener had heard the
# intro and traded; the receiver never talked to her and holds no wrist, yet gets what the opener
# got, and keeps what they hold.
FORTUNE_TELLER = [c(111, 2, "A", 1), c(123, "A", 0, indent: 1), c(115, indent: 1), c(411), c(111, 8, 1734, indent: 1),
                  c(102, ["Trade", "Decline"], 1, indent: 2), c(402, 0, "Trade", indent: 2), c(126, 1734, 1, 0, 1, indent: 3),
                  c(126, 610, 0, 0, 1, indent: 3), c(123, "B", 0, indent: 3), c(402, 1, "Decline", indent: 2), c(404, indent: 2), c(412, indent: 1), c(412)]
TRADED = [["map:51:23:1@0", 0, "branch", 0], ["map:51:23:1@3", 0, "branch", 1], ["map:51:23:1@4", 0, "choice", 0]]
new_game
page(51, 23, FORTUNE_TELLER)
traded = replay("map:51:23:1", "keys" => { "ss51.23.B" => "0" }, "inputs" => TRADED)
check("a receiver who never heard the intro and holds no wrist goes the opener's way and gets the job item, the trade's B on",
      [traded.committed?, $game_party.item_number(610), $game_party.item_number(1734), $game_self_switches[[51, 23, "B"]], $game_self_switches[[51, 23, "A"]]],
      [true, 1, 0, true, false])
new_game
$game_party.gain_item(1734, 1)
replay("map:51:23:1", "keys" => { "ss51.23.B" => "0" }, "inputs" => TRADED)
check("a receiver who holds a wrist keeps it", [$game_party.item_number(610), $game_party.item_number(1734)], [1, 1])

# A chest closed by its own B: the opener's B was off, the receiver's is on, so the receiver's own
# decides and the chest gives nothing again.
new_game
$game_self_switches[[51, 24, "B"]] = true
page(51, 24, [c(111, 2, "B", 1), c(126, 611, 0, 0, 1, indent: 1), c(123, "B", 0, indent: 1), c(412)])
again = replay("map:51:24:1", "keys" => { "ss51.24.B" => "0" }, "inputs" => [["map:51:24:1@0", 0, "branch", 1]])
check("a check of the step's own self switch reads the receiver's, so a chest they opened gives nothing again", [again.committed?, $game_party.item_number(611)], [false, 0])

# The Medal King (CE 140): the medals held read into a variable, a prize for two of them, and a
# bet of gold; the opener held 50 medals and the gold, the receiver neither, and pays nothing.
new_game
page(140, 1, [c(122, 300, 300, 0, 3, 0, 32, 0), c(111, 1, 300, 0, 50, 0), c(126, 32, 1, 0, 2, indent: 1), c(126, 24, 0, 0, 1, indent: 1), c(412),
              c(111, 7, 180, 0), c(125, 1, 0, 180, indent: 1), c(126, 25, 0, 0, 1, indent: 1), c(412), c(123, "A", 0)])
replay("map:140:1:1", "inputs" => [["map:140:1:1@0", 0, "holding", 50], ["map:140:1:1@5", 0, "branch", 1]])
check("a count and gold the opener held decide, and the receiver gets the prizes without paying medals or gold",
      [$game_variables[300], $game_party.item_number(24), $game_party.item_number(25), $game_party.item_number(32), $game_party.gold], [50, 1, 1, 0, 0])

# A page that takes back what it gave keeps nothing of it, and still takes nothing of the receiver's.
new_game
$game_party.gain_item(26, 1)
page(140, 2, [c(126, 26, 0, 0, 1), c(126, 26, 1, 0, 3), c(123, "A", 0)])
replay("map:140:2:1")
check("a page that takes back what it gave leaves the receiver what they held", $game_party.item_number(26), 1)

# A page that gives an item, a companion's affection and the receiver's own switch and variable,
# then stops at a lock before its step's key: nothing of it stays, and once the lock opens the
# replay from the start gives each once.
new_game
page(419, 40, [c(126, 606, 0, 0, 1), c(355, "$game_actors[5].love += 3"), c(121, 2046, 2046, 0), c(122, 300, 300, 0, 0, 4),
               c(111, 12, "unlock_level < 1"), c(115, indent: 1), c(412), c(123, "A", 0)])
cut = replay("map:419:40:1", "keys" => { "ss419.40.A" => "0" })
check("a page cut by a check that fails before its step writes and gives nothing",
      [cut.state, cut.committed?, $game_party.item_number(606), $game_actors[5].love, $game_switches[2046], $game_variables[300]], [:done, false, 0, 0, false, 0])
$game_party.unlock_level = 1
replay("map:419:40:1", "keys" => { "ss419.40.A" => "0" })
check("its retry gives each once", [$game_party.item_number(606), $game_actors[5].love, $game_switches[2046], $game_variables[300], $game_self_switches[[419, 40, "A"]]],
      [1, 3, true, 4, true])

# A replay that waits for the receiver's answer while the game gains gold: the game's gold stays
# beside the replay's.
new_game
page(624, 210, [c(125, 0, 0, 100), c(102, ["Yes", "No"], 2), c(402, 0, "Yes"), c(126, 77, 0, 0, 1, indent: 1), c(404)])
waiting = replay("map:624:210:1")
meanwhile = [waiting.state, $game_party.gold]
$game_party.gain_gold(50)
waiting.answer(0)
check("a replay that waits gives nothing yet, and once it ends the gold the game gained meanwhile stays beside its gift",
      [meanwhile, $game_party.gold, $game_party.item_number(77)], [[:asking, 0], 150, 1])

# A replay that raises leaves the save as it was.
new_game
$game_variables[300] = 2
page(624, 211, [c(126, 606, 0, 0, 1), c(121, 2046, 2046, 0), c(122, 300, 300, 0, 0, 9), c(355, "raise 'broken'")])
broken = replay("map:624:211:1")
check("a replay that raises leaves the save as it was",
      [broken.state, $game_party.item_number(606), $game_switches[2046], $game_variables[300], $log.last.include?("broken")], [:failed, 0, false, 2, true])

check("a plain interpreter still runs the mod's hooks", lambda {
  $hooked.clear
  interpreter = Game_Interpreter.new
  interpreter.setup([c(0)])
  interpreter.update while interpreter.running?
  $hooked.uniq.sort
}.call, [:command, :run])

# The replay leaves out exactly the codes and the interpreter's functions the generator's gate
# classes as the presentation or the opener's play alone, as fixtures/replay/channels.json holds
# them, which MGQOnline.Data.Generator.Tests checks against the gate itself.
CHANNELS = JSON.parse(File.read(File.expand_path("../../fixtures/replay/channels.json", __dir__)))
check("the codes the replay leaves out are those the gate closes", MGQ_MpStoryReplay::CLOSED_CODES.sort, CHANNELS["closed_codes"].sort)
check("the functions the replay leaves out are those the gate closes", MGQ_MpStoryReplay::CLOSED_FUNCTIONS.map { |name| name.to_s }.sort, CHANNELS["closed_functions"].sort)

# The runs of the player's own game and the runs handed to them, over a stand-in of the DLL's topics:
# a Classic world's party, where 2045 and the chest's A are the party's, v1001 the world's and
# v57 the work's.
require_relative "bridge_support"

# Stands in for the party of a Classic world: in party p1.
module MGQ_MpCoop; def self.in_party?; true; end; module Party; def self.id; "p1"; end; end; module Scope; def self.raid?; false; end; end; end
# Stands in for the world: open, the player free on the map, the notices kept in $notices.
module MGQ_MpOverworldSync; def self.in_world?; true; end; def self.map_free?; true; end; def self.notice(text, _icon = nil); $notices << text; end; end
# Stands in for the co-op events: the entries handed to the party kept in $handed.
module MGQ_MpCoopEvents; def self.hand_entry(entry); $handed << entry; end; end
# Stands in for the choices' screen: the question kept in $asked.
module MGQ_MpCoopChoices; def self.ask(opener, lines, labels, done, cancel = nil); $asked = [opener, lines, labels, done, cancel]; end; end
# The currency's name.
module Vocab; def self.currency_unit; "G"; end; end
# An item of the database, a key item or a present as its flags say.
module RPG; class Item < Struct.new(:id, :name, :icon_index, :key, :present); def key_item?; key == true; end; def is_present?; present == true; end; end; end
Item = RPG::Item
$data_items = Array.new(800)
$data_items[511] = Item.new(511, "Silver Key", 3, true)
$data_items[700] = Item.new(700, "Flower", 4, false, true)
$data_items[606] = Item.new(606, "Makina", 5)
$data_weapons = []
$data_armors = []
# The party's gold and members, and its items read by the item as the game reads them.
class Game_Party
  def members; []; end
  def all_members; []; end
  def has_item?(item); item_number(item) > 0; end
  alias_method :item_number_by_id, :item_number
  def item_number(item); item_number_by_id(item.respond_to?(:id) ? item.id : item); end
end

fake = FakeBridge.new
MGQ_Multiplayer::Bridge.open(fake)
switches = "\0" * 2100
switches.setbyte(2045, MGQ_MpStoryKeys::SCOPE_PARTY)
variables = "\0" * 1100
variables.setbyte(1001, MGQ_MpStoryKeys::SCOPE_WORLD)
variables.setbyte(57, MGQ_MpStoryKeys::SCOPE_WORK)
fake.answer("story.replay_scopes") { |_request| { "switches" => switches, "variables" => variables, "keys" => { "ss215.23.A" => 2 }, "self" => {}, "index" => [], "self_default" => 0 } }
fake.answer("story.replay_reads") { |_request| ["v1001"] }
$ran = []
$resets = []
fake.answer("story.replay_ran") { |request| $ran << request; { "id" => "e1", "site" => request["site"], "stream" => request["party_stream"], "scope" => "party" } }
fake.answer("story.replay_reset") { |resets| $resets.concat(resets); nil }

# The Makina chest the opener's game runs: if 2045 is off, the Makina and 2045; then a choice whose
# taking draws a number; a range of switches turned off; the chest's A.
CHEST = [c(111, 0, 2045, 1), c(126, 606, 0, 0, 1, indent: 1), c(121, 2045, 2045, 0, indent: 1), c(412), c(102, ["Take", "Leave"], 1), c(402, 0, "Take"),
         c(122, 300, 300, 0, 2, 1, 6, indent: 1), c(404), c(121, 40, 45, 1), c(123, "A", 0), c(0)]

new_game
$handed = []
$game_map.map_id = 215
$game_variables[1001] = 5
opener = Game_Interpreter.new
opener.setup(CHEST, 23)
opener.update until $game_message.choice?
$game_variables[1001] = 6
$game_message.choice_proc.call(0)
$game_message.clear
opener.update while opener.running?
drawn = $game_variables[300]
request = $ran.last
check("a run of the player's own chest names the party keys it changed, their values before, and goes to the party's stream",
      [request["site"], request["changed"], request["owner"], request["party_stream"], request["place"]],
      ["map:215:23:1", { "s2045" => ["0", "1"], "ss215.23.A" => ["0", "1"] }, true, "party:p1", [5, 0, 0, 0]])
check("it carries the start values of the world keys its event reads, and the choice and draw of its player by their commands",
      [request["start"], request["inputs"]], [{ "v1001" => "n5" }, [["map:215:23:1@4", 0, "choice", 0], ["map:215:23:1@6", 0, "rand", drawn - 1]]])
check("its range of switches went to the DLL as a reset, and its entry to the party", [$resets, $handed.map { |entry| entry["id"] }], [[["s", 40, 45, "0"]], ["e1"]])

# The receiver's game takes the chest's entry: it names the value the DLL asks for, replays the
# page, and the DLL tells the notice from what the receiver held before and after.
taken = []
fake.answer("story.replay_take") do |request|
  taken << request["values"]
  request["values"].key?("ss215.23.A") ? { "do" => "replay", "page" => 1 } : { "needs" => ["ss215.23.A"] }
end
done = []
fake.answer("story.replay_done") { |request| done << request; { "notice" => "Ana opened a chest for the party: Makina." } }
page(215, 23, CHEST[0..-2])
entry = { "id" => "e1", "site" => "map:215:23:1", "stream" => "party:p1", "scope" => "party", "opener" => "Ana", "keys" => { "s2045" => "0", "ss215.23.A" => "0" },
          "place" => [5, 0, 0, 0], "start" => { "v1001" => "n5" }, "inputs" => request["inputs"], "derived" => false }
new_game
$notices = []
MGQ_MpStoryReplay.receive(entry)
MGQ_MpStoryReplay.update
check("a member's game asks for its own value the DLL lacks, then replays the chest with the opener's choice and draw",
      [taken, $game_party.item_number(606), $game_switches[2045], $game_self_switches[[215, 23, "A"]], $game_variables[300]],
      [[{}, { "ss215.23.A" => "0" }], 1, true, true, drawn])
check("the replay reached the step and told the DLL what the member held after, which tells the one notice",
      [done.last["reached"], done.last["before"], done.last["has"].assoc("i606"), $notices, MGQ_MpStoryReplay.waiting], 
      [true, { "s2045" => "0", "ss215.23.A" => "0" }, ["i606", 1, "Makina", false], ["Ana opened a chest for the party: Makina."], []])

# An answer the record lacks is asked on the choices' screen; the stream waits for it.
new_game
$notices = []
MGQ_MpStoryReplay.receive(entry.merge("inputs" => []))
MGQ_MpStoryReplay.update
asked = $asked
check("a choice the record lacks is asked with its labels and the label its cancel answers, and the run waits",
      [asked[0], asked[2], asked[4], $game_self_switches[[215, 23, "A"]]], ["Ana", ["Take", "Leave"], 0, false])
asked[3].call(1)
check("the receiver's own answer plays on", [$game_self_switches[[215, 23, "A"]], $game_variables[300], $notices.size], [true, 0, 1])

# A choice without cancel hands none, and one with its own cancel branch hands the place after its
# labels, whose answer it adds last.
replay = MGQ_MpStoryReplay::Replay.allocate
choice = Struct.new(:choices, :choice_cancel_type)
check("a choice hands no cancel, or its own branch after the labels",
      [replay.send(:choices_of, "choice", choice.new(["Yes", "No"], 0)), replay.send(:choices_of, "choice", choice.new(["Sword", "Shield"], 3))],
      [[["Yes", "No"], [0, 1], nil], [["Sword", "Shield"], [0, 1, 2], 2]])

# A run that waits, as for a lock, is taken again once the DLL names it due.
new_game
fake.answer("story.replay_take") { |_request| { "do" => "pending", "why" => "page 2 shows" } }
MGQ_MpStoryReplay.receive(entry)
MGQ_MpStoryReplay.update
waited = [$game_party.item_number(606), MGQ_MpStoryReplay.waiting]
fake.answer("story.replay_take") { |_request| { "do" => "replay", "page" => 1 } }
fake.answer("story.replay_due") { |request| request["values"].key?("holdings") ? [entry] : { "needs" => ["holdings"] } }
MGQ_MpStoryReplay.instance_variable_set(:@due_at, -MGQ_MpStoryReplay::DUE_FRAMES)
MGQ_MpStoryReplay.update
check("a run that waits is dropped from the queue, and replayed once the DLL names it due", [waited, $game_party.item_number(606)], [[0, []], 1])

# Issue 73's class: a chest that turns on a switch another event reads. The opener already had 2045,
# so their run changed the chest's A alone; the member whose 2045 is off still gets the Makina and
# 2045 by playing the chest in their own game, whatever the opener held.
fake.answer("story.replay_take") { |_request| { "do" => "replay", "page" => 1 } }
new_game
$handed = []
$game_map.map_id = 215
$game_switches[2045] = true
opener = Game_Interpreter.new
opener.setup(CHEST, 23)
opener.update until $game_message.choice?
$game_message.choice_proc.call(1)
$game_message.clear
opener.update while opener.running?
handed = $ran.last
check("an opener who had 2045 already hands over the chest with its A alone", handed["changed"], { "ss215.23.A" => ["0", "1"] })
new_game
MGQ_MpStoryReplay.receive(entry.merge("keys" => { "ss215.23.A" => "0" }, "inputs" => handed["inputs"]))
MGQ_MpStoryReplay.update
check("a member whose 2045 is off gets the Makina, 2045 and the chest's A from that run",
      [$game_party.item_number(606), $game_switches[2045], $game_self_switches[[215, 23, "A"]]], [1, true, true])

# The same chest taken through the catch-up, as an entry of the player's own history: its world
# key already arrived and reads as shut, and the player's own 2045 decides.
page(588, 9, [c(126, 606, 0, 0, 1), c(111, 0, 2045, 1), c(121, 2045, 2045, 0, indent: 1), c(0, indent: 1), c(412), c(123, "A", 0)])
new_game
$game_self_switches[[588, 9, "A"]] = true
MGQ_MpStoryReplay.receive({ "id" => "derived:map:588:9:1", "site" => "map:588:9:1", "stream" => "derived", "scope" => "world", "opener" => nil,
                            "keys" => { "ss588.9.A" => "0" }, "start" => { "ss588.9.A" => "0" }, "inputs" => [], "derived" => true })
MGQ_MpStoryReplay.update
check("a world chest the catch-up hands over gives the item and the player's own 2045, its key left as the world wrote it",
      [$game_party.item_number(606), $game_switches[2045], $game_self_switches[[588, 9, "A"]]], [1, true, true])

# A guest who borrows the leader's story keeps what a replay writes of their own keys in their own
# story kept aside, the chest's A and 2045 among them.
module MGQ_MpCoopStory; def self.guest?; true; end; def self.keep_own(kind, key, value); ($kept ||= []) << [kind, key, value]; end; end
new_game
$kept = []
MGQ_MpStoryReplay.receive(entry.merge("keys" => { "ss215.23.A" => "0" }, "inputs" => handed["inputs"]))
MGQ_MpStoryReplay.update
check("a guest keeps the chest's A and 2045 a replay wrote in their own story", [$kept.include?([0, 2045, true]), $kept.include?([2, [215, 23, "A"], true])], [true, true])
module MGQ_MpCoopStory; def self.guest?; false; end; end

# A receiver asked the Fortune Teller's trade who answers Decline is done with their own answer, so
# the question does not come back.
new_game
$notices = []
done.clear
MGQ_MpStoryReplay.receive(entry.merge("id" => "e7", "site" => "map:51:23:1", "keys" => { "ss51.23.B" => "0" }, "inputs" => TRADED.first(2)))
MGQ_MpStoryReplay.update
$asked[3].call(1)
check("a receiver who declines the trade they are asked is done with their answer, which gave nothing",
      [done.last["reached"], $game_party.item_number(610), $game_self_switches[[51, 23, "B"]], MGQ_MpStoryReplay.waiting], [true, 0, false, []])

# A receiver asked the trade who answers Trade, as the opener did, goes the opener's way: a later
# check of their own that fails leaves the run waiting instead of done.
page(51, 25, [c(102, ["Trade", "Decline"], 1), c(402, 0, "Trade"), c(111, 0, 900, 0, indent: 1), c(126, 612, 0, 0, 1, indent: 2), c(123, "B", 0, indent: 2),
              c(412, indent: 1), c(402, 1, "Decline"), c(404)])
fake.answer("story.replay_take") { |_request| { "do" => "replay", "page" => 1, "inputs" => [] } }
new_game
MGQ_MpStoryReplay.receive(entry.merge("id" => "e8", "site" => "map:51:25:1", "keys" => { "ss51.25.B" => "0" }, "inputs" => [["map:51:25:1@0", 0, "choice", 0]]))
MGQ_MpStoryReplay.update
$asked[3].call(0)
check("a receiver who answers as the opener did and fails a later check of their own is not done",
      [done.last["reached"], $game_party.item_number(612), $game_self_switches[[51, 25, "B"]]], [false, 0, false])
fake.answer("story.replay_take") { |_request| { "do" => "replay", "page" => 1 } }

# A replay of a run that used up a key item takes the receiver's too, though a replay costs nothing
# else (user decision 2026-11-04), so a later page that asks for the item, as the World Seed's for
# Lucretia, does not open early; a plain item it uses up stays theirs.
$data_items[610] = Item.new(610, "World Seed", 6, true)
$data_items[611] = Item.new(611, "Herb", 6, false)
page(51, 24, [c(126, 610, 1, 0, 1), c(126, 611, 1, 0, 1), c(123, "B", 0)])
new_game
$game_party.gain_item($data_items[610], 1)
$game_party.gain_item($data_items[611], 1)
MGQ_MpStoryReplay.receive(entry.merge("id" => "e9", "site" => "map:51:24:1", "keys" => { "ss51.24.B" => "0" }, "inputs" => []))
MGQ_MpStoryReplay.update
check("a replay that uses up a key item takes the receiver's, a plain item it uses up not",
      [$game_self_switches[[51, 24, "B"]], $game_party.item_number(610), $game_party.item_number(611)], [true, 0, 1])

# The leader returns to the Great Decision (map 889, event 3), whose page calls the Final Chapter's
# reset (common event 154): it turns switches 2444 to 2484 off and takes the route's key items 568
# to 580. A Classic member ahead of the leader replays it and keeps their own.
(568..580).each { |id| $data_items[id] = Item.new(id, "Route key #{id}", 6, true) }
$data_common_events[154] = RPG::CommonEvent.new([c(121, 2444, 2484, 1)] + (568..580).map { |id| c(126, id, 1, 0, 1) } + [c(0)])
page(889, 3, [c(117, 154), c(123, "A", 0)])
new_game
(568..580).each { |id| $game_party.gain_item($data_items[id], 1) }
MGQ_MpStoryReplay.receive(entry.merge("id" => "e10", "site" => "map:889:3:1", "keys" => { "ss889.3.A" => "0" }, "inputs" => []))
MGQ_MpStoryReplay.update
check("a Classic member ahead of the leader keeps the route key items when the leader returns to the Great Decision",
      [$game_self_switches[[889, 3, "A"]], (568..580).map { |id| $game_party.item_number(id) }.uniq], [true, [1]])

# The save keeps the DLL's log; a loaded save hands it back with its place.
logs = []
fake.answer("story.replay_log_save") { |_request| { "version" => 1, "steps" => [] } }
fake.answer("story.replay_log") { |request| logs << request; nil }
$game_system = Object.new
MGQ_MpStoryReplay.saving
MGQ_MpStoryReplay.loaded
check("the save keeps the log, and a loaded save hands it back with its place",
      logs, [{ "log" => { "version" => 1, "steps" => [] }, "place" => [0, 0, 0, 0] }])

# The runs that wait to be taken go into the save with the log: one handed over while the player is
# not free waits with the DLL too, a loaded save takes back those its log holds, and a new game or a
# world that closes forgets them.
queued = []
fake.answer("story.replay_queue") { |waiting_entry| queued << waiting_entry["id"]; nil }
fake.answer("story.replay_log") { |request| logs << request; request["log"] ? [entry] : [] }
def MGQ_MpOverworldSync.map_free?; false; end
MGQ_MpStoryReplay.receive(entry)
MGQ_MpStoryReplay.update
held = [queued, MGQ_MpStoryReplay.waiting.map { |waiting_entry| waiting_entry["id"] }]
MGQ_MpStoryReplay.new_game
after_new_game = MGQ_MpStoryReplay.waiting.size
$game_system.instance_variable_set(:@mgq_mp_replay_log, { "version" => 1 })
MGQ_MpStoryReplay.loaded
after_load = MGQ_MpStoryReplay.waiting.map { |waiting_entry| waiting_entry["id"] }
MGQ_MpStoryReplay.forget
check("a run that waits to be taken waits in the save's log too, comes back with a loaded save and is forgotten by a new game or a world that closes",
      [held, after_new_game, after_load, MGQ_MpStoryReplay.waiting, logs.last], [[["e1"], ["e1"]], 0, ["e1"], [], { "log" => nil, "place" => nil }])
def MGQ_MpOverworldSync.map_free?; true; end

# A battle the opener's run fought is noted by the command that started it once the battle ended,
# which happens while the run waits inside that command; a number asked after a text is noted by the
# text's command, which sets it up.
new_game
$game_map.map_id = 215
opener = Game_Interpreter.new
opener.setup([c(301, 0, 12, true, false), c(101, "", 0, 0, 2), c(401, "How many?"), c(103, 300, 2), c(123, "A", 0), c(0)], 23)
opener.update
BattleManager.battle_end(1)
opener.update until $game_message.num_input?
$game_variables[300] = 12
$game_message.clear
opener.update while opener.running?
check("a battle's outcome and a number asked after a text are noted by the commands that started them",
      $ran.last["inputs"], [["map:215:23:1@0", 0, "battle", 1], ["map:215:23:1@1", 0, "number", 12]])

# The opener's checks of the event's own self switch and of what the party holds, and a count of
# what it holds read into a variable, are noted by their commands.
new_game
$game_map.map_id = 215
$game_party.gain_item(1734, 1)
$game_party.gain_item(32, 5)
opener = Game_Interpreter.new
opener.setup([c(111, 2, "B", 1), c(111, 8, 1734, indent: 1), c(412, indent: 1), c(412), c(122, 300, 300, 0, 3, 0, 32, 0), c(123, "A", 0), c(0)], 23)
opener.update while opener.running?
check("the opener's checks of its self switch and of what the party holds and a count it read are noted by their commands",
      $ran.last["inputs"], [["map:215:23:1@0", 0, "branch", 1], ["map:215:23:1@1", 0, "branch", 1], ["map:215:23:1@4", 0, "holding", 5]])

# Without the choices' screen asking inputs, a number the record lacks stops the replay, which
# writes nothing of what it did before; one the record holds is used.
new_game
page(215, 30, [c(126, 606, 0, 0, 1), c(101, "", 0, 0, 2), c(401, "How many?"), c(103, 300, 2), c(123, "A", 0)])
stopped = replay("map:215:30:1")
check("without asking, a number the record lacks stops the replay, which writes and gives nothing",
      [stopped.state, $game_party.item_number(606), $game_self_switches[[215, 30, "A"]]], [:failed, 0, false])
replay("map:215:30:1", "inputs" => [["map:215:30:1@1", 0, "number", 3]])
check("a recorded number is used", [$game_variables[300], $game_party.item_number(606)], [3, 1])

# With the choices' screen asking inputs, a number, an item or a present the record lacks is asked
# of the receiver, and the run waits for the answer.
def MGQ_MpCoopChoices.ask_input(opener, lines, kind, spec, done); $asked_input = [opener, lines, kind, spec, done]; end
$chest_entry = entry
# Takes a run of a page of map 215, whose step is the page's A.
#
# @param event [Integer] The page's event.
def take_page(event)
  MGQ_MpStoryReplay.receive($chest_entry.merge("site" => "map:215:#{event}:1", "keys" => { "ss215.#{event}.A" => "0" }, "inputs" => []))
  MGQ_MpStoryReplay.update
end

new_game
$game_variables[300] = 4
take_page(30)
asked = $asked_input
check("a number the record lacks asks the receiver with its digits and the variable's value, and nothing is given yet",
      [asked[0..3], $game_party.item_number(606)], [["Ana", ["How many?"], "number", { "digits" => 2, "value" => 4 }], 0])
asked[4].call(7)
check("the variable takes their answer, and the page goes on", [$game_variables[300], $game_party.item_number(606), $game_self_switches[[215, 30, "A"]]], [7, 1, true])

page(215, 31, [c(101, "", 0, 0, 2), c(401, "Which one?"), c(104, 300), c(123, "A", 0)])
new_game
$game_party.gain_item(511, 1)
$game_party.gain_item(606, 2)
take_page(31)
check("an item the record lacks asks the receiver with the key items they hold", $asked_input[2..3], ["item", { "items" => [[511, "Silver Key", 1]] }])
$asked_input[4].call(511)
check("the variable takes the item they picked", [$game_variables[300], $game_self_switches[[215, 31, "A"]]], [511, true])

page(215, 32, [c(355, "present_start(5)"), c(123, "A", 0)])
new_game
$game_party.gain_item(700, 1)
take_page(32)
check("a present the record lacks asks the receiver with the presents the companion takes", $asked_input[2..3], ["present", { "actor" => 5, "items" => [[700, "Flower", 1]] }])
$asked_input[4].call(0)
check("a cancelled present gives nothing", [$game_party.item_number(700), $game_actors[5].love, $game_self_switches[[215, 32, "A"]]], [1, 0, true])

# A parallel event's run whose event the map made anew on a transfer closes with it, while the run
# of the map's own interpreter, which goes on across the transfer, stays open.
new_game
$game_map.map_id = 215
$game_map.events = { 23 => Game_Event.new(23) }
parallel = $game_map.events[23].instance_variable_get(:@interpreter)
parallel.setup([c(230, 5), c(123, "A", 0), c(0)], 23)
parallel.update
own = $game_map.interpreter
own.setup([c(230, 5), c(123, "B", 0), c(0)], 24)
own.update
open = MGQ_MpStoryKeys.instance_variable_get(:@runs).size
$game_map.events = { 23 => Game_Event.new(23) }
$game_map.update
check("a run whose interpreter the map let go closes, and the map's own run stays",
      [open, MGQ_MpStoryKeys.instance_variable_get(:@runs).keys, MGQ_MpStoryKeys.instance_variable_get(:@stacks).keys], [2, [own.object_id], [own.object_id]])

# A choice a text sets up is noted at its Show Choices, by its place among the commands the events
# database keeps, so a receiver whose translation gives the text another number of lines finds the
# opener's answer at the same place.
new_game
$game_map.map_id = 215
opener = Game_Interpreter.new
opener.setup([c(101, "", 0, 0, 2), c(401, "Take her along?"), c(401, "She waits."), c(102, ["Reconsider", "Take her along"], 1), c(402, 0, "Reconsider"),
              c(402, 1, "Take her along"), c(126, 77, 0, 0, 1, indent: 1), c(404), c(123, "A", 0), c(0)], 23)
opener.update until $game_message.choice?
$game_message.choice_proc.call(1)
$game_message.clear
opener.update while opener.running?
recorded = $ran.last["inputs"]
check("a choice after a text is noted at its Show Choices, counted among the commands the events database keeps", recorded, [["map:215:23:1@1", 0, "choice", 1]])
new_game
page(215, 23, [c(101, "", 0, 0, 2), c(401, "Take her along? She waits."), c(102, ["Reconsider", "Take her along"], 1), c(402, 0, "Reconsider"),
               c(402, 1, "Take her along"), c(126, 77, 0, 0, 1, indent: 1), c(404), c(123, "A", 0)])
replay("map:215:23:1", "inputs" => recorded)
check("a receiver whose text has a line less takes the opener's answer at the same place", $game_party.item_number(77), 1)

# A cup of the Colosseum's extended choice (CE 161), its answers added by the script that shows it,
# is noted at that script command; a receiver is asked only the cups the game shows them.
CUPS = [c(355, 'ex_choice_add("Demon Cup", 1)'), c(655, 'ex_choice_add("Saja Cup", 4, "s[1600]", 0)'), c(655, "ex_choice_show(0)"),
        c(111, 1, 15, 0, 1, 0), c(126, 81, 0, 0, 1, indent: 1), c(412), c(111, 1, 15, 0, 4, 0), c(126, 84, 0, 0, 1, indent: 1), c(412), c(123, "A", 0)]
new_game
$game_map.map_id = 215
$game_switches[1600] = true
opener = Game_Interpreter.new
opener.setup(CUPS + [c(0)], 23)
opener.update until $game_message.ex_choice?
$game_variables[15] = 4
$game_message.ex_choice_clear
opener.update while opener.running?
check("an extended choice is noted at the script command that shows it", $ran.last["inputs"], [["map:215:23:1@0", 0, "choice", 4]])
new_game
page(215, 23, CUPS)
waiting = replay("map:215:23:1")
asked = [waiting.state, waiting.question && waiting.question["at"], waiting.question && waiting.question["labels"], waiting.question && waiting.question["values"],
         waiting.question && waiting.question["cancel"]]
waiting.answer(1)
check("a receiver is asked an extended choice with the answers the game shows them, and what its cancel answers after them", asked, [:asking, "map:215:23:1@0", ["Demon Cup"], [1, 0], 1])
check("and their answer plays on", [waiting.state, $game_party.item_number(81), $game_party.item_number(84)], [:done, 1, 0])

# Taking a run, the player's game hands the DLL the shapes of its own lists of the run's choices, by
# which the DLL finds them in its events database; a list the game lacks is left out.
shapes = []
fake.answer("story.replay_take") { |request| shapes << request["shapes"]; { "do" => "pending", "why" => "page 2 shows" } }
page(217, 5, [c(102, ["Yes", "No"], 1), c(402, 0, "Yes"), c(126, 78, 0, 0, 1, indent: 1), c(404)])
new_game
MGQ_MpStoryReplay.receive(entry.merge("id" => "e10", "inputs" => [["map:217:5:1@0", 0, "choice", 1], ["ce:900@0", 0, "choice", 0], ["map:215:23:1@3", 0, "rand", 4]]))
MGQ_MpStoryReplay.update
check("a run's take names the shapes of the player's lists of its choices",
      shapes.last, { "map:217:5:1" => MGQ_MpStoryReplay.list_shape($maps[217].events[5].pages[0].list) })

# An input's place counts the commands the events database keeps, by the same codes.
check("the codes an input's place counts are those the events database keeps", MGQ_MpStoryReplay::KEPT_CODES, CHANNELS["kept_codes"])

# Another player's battle drop of a key item gives the receiver the item, with no event to replay,
# and the DLL tells the notice from what they held before and after (user decision 2026-11-05).
fake.answer("story.replay_take") { |_request| { "do" => "gain", "items" => [[511, 1]] } }
fake.answer("story.replay_done") { |request| done << request; { "notice" => "Ana won a battle drop for everyone: Silver Key." } }
new_game
$notices = []
MGQ_MpStoryReplay.receive("id" => "d1", "site" => "game:drop", "stream" => "party:p1", "scope" => "party", "opener" => "Ana", "keys" => {}, "place" => nil,
                          "start" => {}, "inputs" => [], "derived" => false, "found" => true, "drops" => [[511, 1]])
MGQ_MpStoryReplay.update
check("another player's battle drop gives the receiver its key item, and the DLL its notice",
      [$game_party.item_number(511), done.last["reached"], done.last["had"].assoc("i511"), done.last["has"].assoc("i511"), $notices, MGQ_MpStoryReplay.waiting],
      [1, true, nil, ["i511", 1, "Silver Key", false], ["Ana won a battle drop for everyone: Silver Key."], []])
