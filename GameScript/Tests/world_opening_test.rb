#----------------------------------------------------------------
#  world_opening_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

# Covers a new game's opening in a Raid World (world_opening.rbx): played as the game has it while
# the world's story is at its start; past it, the opening's setup runs without its scene, in
# common events too, the opening's own start is held meanwhile, the game's own transfer takes the
# player where the opening ends, and the world's story waits until the setup ended there; a loaded
# save, another map and a failure leave the opening to the game.

require_relative "support"

# Stand-ins for the game.
module RPG; EventCommand = Struct.new(:code, :indent, :parameters); CommonEvent = Struct.new(:list); end
System = Struct.new(:start_map_id)
$data_system = System.new(545)
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
class Game_Temp; attr_accessor :fade_type; end
class Game_Player
  attr_accessor :transparent, :reserved
  def reserve_transfer(map_id, x, y, direction); @reserved = [map_id, x, y, direction]; end
  def transfer?; !@reserved.nil?; end
  def x; 48; end
  def y; 44; end
end
Game_Event = Struct.new(:id, :trigger, :list)
class Game_Map; attr_accessor :map_id, :events; def update(_main = false); end; end
class Scene_Map; end
class Scene_Menu; end
module SceneManager; class << self; attr_accessor :scene; end; def self.scene_is?(klass); @scene.is_a?(klass); end; end
module DataManager; def self.setup_new_game; end; def self.load_game_without_rescue(_index); true; end; end

# The game's interpreter as RGSS3 has it, as far as the tests need: its fiber, waits that yield,
# switches, variables, a common event's call, a choice's branch, the transparency and the
# transfer, which waits until the map moved the player; every command of the scene fails the test
# when it runs.
class Game_Interpreter
  def initialize(depth = 0); @depth = depth; @list = nil; @index = 0; end
  def setup(list, event_id = 0); @list = list; @index = 0; @event_id = event_id; @fiber = Fiber.new { run }; end
  def running?; !@fiber.nil?; end
  def update; @fiber.resume if @fiber; end
  def same_map?; true; end

  def run
    while @list[@index]
      execute_command
      @index += 1
    end
    Fiber.yield
    @fiber = nil
  end

  def execute_command
    command = @list[@index]
    @params = command.parameters
    @indent = command.indent
    method_name = "command_#{command.code}"
    send(method_name) if respond_to?(method_name)
  end

  def command_121; $game_switches[@params[0]] = @params[2] == 0; end
  def command_122; $game_variables[@params[0]] = @params[4]; end
  def command_211; $game_player.transparent = @params[0] == 0; end
  def command_230; @params[0].times { Fiber.yield }; end
  def command_402; command_skip if (@branch ||= {})[@indent] != @params[0]; end
  def command_skip; @index += 1 while @list[@index + 1].indent > @indent; end

  def command_201
    $game_player.reserve_transfer(@params[1], @params[2], @params[3], @params[4])
    $game_temp.fade_type = @params[5]
    Fiber.yield while $game_player.transfer?
  end

  def command_117
    child = Game_Interpreter.new(@depth + 1)
    child.setup($data_common_events[@params[0]].list, @event_id)
    child.run
  end

  [101, 102, 205, 221, 231, 241, 250, 301, 353].each do |code|
    define_method("command_#{code}") { ($ran ||= []) << code }
  end
end

load_script "world_opening"

def command(code, *parameters); RPG::EventCommand.new(code, 0, parameters); end
$data_common_events = [nil, RPG::CommonEvent.new([command(122, 52, 52, 0, 0, 1), command(230, 60), command(101, "", 0, 0, 2), command(0)])]
opening = [
  command(122, 1001, 1001, 0, 0, 0), command(121, 90, 90, 0), command(101, "", 0, 0, 2), command(401, "Choose."),
  command(117, 1), command(221), command(230, 30), command(231, 1, "bg001"), command(241, "irias"), command(250, "Step"),
  command(201, 0, 6, 48, 44, 2, 0), command(211, 1), command(205, -1, nil), command(102, ["Yes", "No"], 0),
  command(402, 0, "Yes"), RPG::EventCommand.new(122, 1, [77, 77, 0, 0, 9]), command(404), command(301, 0, 1), command(353), command(0)
]
fresh = lambda do |map_id = 545|
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_variables[1001] = 7
  $game_temp = Game_Temp.new
  $game_player = Game_Player.new
  $game_player.transparent = true
  $game_map = Game_Map.new
  $game_map.map_id = map_id
  $game_map.events = { 1 => Game_Event.new(1, 3, opening), 2 => Game_Event.new(2, 0, [command(0)]) }
  SceneManager.scene = Scene_Map.new
  $ran = []
  DataManager.setup_new_game
end
world = lambda { |progress| { "p" => progress } }
opening_event = lambda { $game_map.events[1] }
frames = lambda { |count| count.times { $game_map.update } }

# A world at its start.
fresh.call
check("a world whose story is at its start lets the new game play the opening", MGQ_MpWorldOpening.before_take(world.call(0)), nil)
check("and holds nothing of it", MGQ_MpWorldOpening.holds?(opening_event.call), false)

# A world past it.
fresh.call
check("a world past the start keeps its story waiting while the opening's setup runs", MGQ_MpWorldOpening.before_take(world.call(7)), :wait)
check("the opening's own event does not start meanwhile", [MGQ_MpWorldOpening.holds?(opening_event.call), MGQ_MpWorldOpening.holds?($game_map.events[2])], [true, false])
frames.call(3)
check("the setup runs within a few updates, one more per common event it calls, as the game runs it: switches and variables, the common event's too",
      [$game_variables[1001], $game_switches[90], $game_variables[52]], [0, true, 1])
check("up to the game's own transfer to where the opening ends, which it waits for", [$game_player.reserved, $game_temp.fade_type, $game_player.transparent], [[6, 48, 44, 2], 0, true])
check("the world's story still waits while the player is on the way", MGQ_MpWorldOpening.before_take(world.call(7)), :wait)
$game_player.reserved = nil
$game_map.map_id = 6
frames.call(2)
check("there the setup runs on to its end and shows the player", $game_player.transparent, false)
check("but none of the scene: messages, choices and their branches, pictures, sounds, fades, routes, battles, the game over",
      [$ran, $game_variables[77]], [[], 0])
check("then the world's story is laid over the story the setup made", MGQ_MpWorldOpening.before_take(world.call(7)), :opened)
check("and only once", MGQ_MpWorldOpening.before_take(world.call(7)), nil)
$game_map.map_id = 545
check("the opening's event is free again", MGQ_MpWorldOpening.holds?(opening_event.call), false)

# No transfer.
fresh.call
$game_map.events[1] = Game_Event.new(1, 3, [command(121, 5, 5, 0), command(0)])
MGQ_MpWorldOpening.before_take(world.call(7))
frames.call(2)
check("a setup that moves the player nowhere is done once it ran", [$game_switches[5], MGQ_MpWorldOpening.before_take(world.call(7))], [true, :opened])

# Another screen over the map.
fresh.call
SceneManager.scene = Scene_Menu.new
check("over another screen the setup waits for the map", [MGQ_MpWorldOpening.before_take(world.call(7)), MGQ_MpWorldOpening.holds?(opening_event.call)], [:wait, false])
SceneManager.scene = Scene_Map.new
check("and starts once the map is back", [MGQ_MpWorldOpening.before_take(world.call(7)), MGQ_MpWorldOpening.holds?(opening_event.call)], [:wait, true])

# Off the start map, after a load, after a failure.
fresh.call(6)
check("a new game the world's story finds off the start map leaves it to the game", MGQ_MpWorldOpening.before_take(world.call(7)), nil)
fresh.call
DataManager.load_game_without_rescue(1)
check("a loaded save has no opening", MGQ_MpWorldOpening.before_take(world.call(7)), nil)
fresh.call
$game_map.events[1] = Game_Event.new(1, 3, [command(355, "boom"), command(0)])
class Game_Interpreter; def command_355; raise "boom"; end; end
MGQ_MpWorldOpening.before_take(world.call(7))
frames.call(1)
check("a setup that fails leaves the opening to the game", [MGQ_MpWorldOpening.holds?(opening_event.call), MGQ_MpWorldOpening.before_take(world.call(7))], [false, nil])
