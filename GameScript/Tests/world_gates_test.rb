#----------------------------------------------------------------
#  world_gates_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-24: Created
#
#----------------------------------------------------------------

# Covers world_gates.rbx: a Raid World's gated areas, which nobody enters from outside before the
# world's story meets their needs, by any move or by a choice that leads there.

require_relative "support"

# Stands in for the game's data.
module RPG
  # An event command.
  EventCommand = Struct.new(:code, :indent, :parameters)
end
# Stands in for RGSS graphics, whose frame count is $frame_count.
module Graphics; def self.frame_count; $frame_count; end; end
$frame_count = 1000
# Stands in for the map's screen, keeping its fade-ins.
class Game_Screen; attr_accessor :brightness, :fadein; def initialize; @brightness = 255; end; def start_fadein(frames); @fadein = frames; end; end
# Stands in for the map, on $map_id.
class Game_Map; attr_reader :screen; def initialize; @screen = Game_Screen.new; end; def map_id; $map_id; end; end
# Stands in for the player, keeping the moves that went through in $moves.
class Game_Player; def reserve_transfer(map_id, x, y, d = 2); ($moves ||= []) << map_id; end; end
# Stands in for the event interpreter of a map's event, running the list it holds.
class Game_Interpreter
  attr_accessor :list, :index
  def initialize(list, map_id = 1287, event_id = 232); @list = list; @index = 0; @map_id = map_id; @event_id = event_id; end
  def execute_command; end
end
# Stands in for the scope, a Raid World while $raid is.
module MGQ_MpCoop; module Scope; def self.raid?; $raid; end; end; end
# Stands in for overworld_sync.rbx, keeping its notices in $notices.
module MGQ_MpOverworldSync; def self.notice(text, _icon = nil); ($notices ||= []) << text; end; end
load_script "world_gates"

gates = MGQ_MpWorldGates
area = gates::AREAS.first
$game_map = Game_Map.new
$game_player = Game_Player.new
$game_variables = Hash.new(0)
$raid = true
$map_id = 1287
done = lambda { area.needs.each { |need| $game_variables[need.variable] = need.value } }

# Moves.
$game_player.reserve_transfer(1836, 10, 10)
check("a Raid World keeps everyone out of the Central Tartarus while the world's story lacks its chains", $moves.to_a, [])
check("and says what the world still has to finish", $notices.last,
      "Central Tartarus opens once the world finished: Chaos Ilias Temple, Chaos Dark God's Castle, Kagetsumugi's Return, Administrator's Tower, " \
      "White Rabbit's Revival, Koron, Ilias's Power-up, Alice's Power-up, Hero of the North, Granberia's Nightmare.")
$game_player.reserve_transfer(1752, 10, 10)
check("its deepest map too, as a follow or teleport would reach it, telling it once in a while", [$moves.to_a, $notices.size], [[], 1])
$game_map.screen.brightness = 0
$game_player.reserve_transfer(1836, 10, 10)
check("a move kept back after the scene faded out fades the screen in again", $game_map.screen.fadein, gates::FADEIN_FRAMES)
done.call
$game_variables[1345] = 4
$game_player.reserve_transfer(1836, 10, 10)
check("one chain short is still shut", $moves.to_a, [])
$frame_count += gates::NOTICE_FRAMES
$game_player.reserve_transfer(1836, 10, 10)
check("and names only what is missing", $notices.last, "Central Tartarus opens once the world finished: Koron.")
done.call
$game_player.reserve_transfer(1836, 10, 10)
check("all ten open it", $moves, [1836])
$game_variables[1345] = 0
$map_id = 1938
$game_player.reserve_transfer(1951, 10, 10)
check("a player inside moves on within it", $moves, [1836, 1951])
$map_id = 1287
$game_player.reserve_transfer(2, 10, 10)
check("every other map stays open", $moves, [1836, 1951, 2])
$raid = false
$game_player.reserve_transfer(1836, 10, 10)
check("a Classic world gates nothing", $moves, [1836, 1951, 2, 1836])
$raid = true

# Choices.
command = lambda { |code, indent, parameters| RPG::EventCommand.new(code, indent, parameters) }
list = [command.call(102, 0, [["Prepare", "Charge into Central Tartarus"], 1]),
        command.call(402, 0, [0, "Prepare"]), command.call(0, 1, []),
        command.call(402, 0, [1, "Charge into Central Tartarus"]), command.call(301, 1, [0, 2200]), command.call(201, 1, [0, 836, 10, 7, 8, 2]), command.call(0, 1, []),
        command.call(404, 0, []), command.call(0, 0, [])]
interpreter = Game_Interpreter.new(list)
interpreter.execute_command
choice = interpreter.list
check("a choice leaves out what leads into the shut area, its fights too, the map named in its own map folder as the game does", [choice[0].parameters[0], choice.map(&:code)], [["Prepare"], [102, 402, 0, 404, 0]])
check("and keeps its cancel on the option kept", choice[0].parameters[1], 1)
cancelled = list.dup
cancelled[0] = command.call(102, 0, [["Prepare", "Charge into Central Tartarus"], 5])
cancelled[7, 0] = [command.call(403, 0, []), command.call(0, 1, [])]
interpreter = Game_Interpreter.new(cancelled)
interpreter.execute_command
check("and a cancel's own branch", interpreter.list.map(&:code), [102, 402, 0, 403, 0, 404, 0])
spoken = [command.call(101, 0, ["", 0, 0, 2]), command.call(401, 0, ["The Central Tartarus..."])] + list
interpreter = Game_Interpreter.new(spoken)
interpreter.execute_command
check("also the choice a message shows along, as the game's message does without running the choice (review H1)", interpreter.list[2].parameters[0], ["Prepare"])
straight = [command.call(111, 0, [1, 1348, 0, 2, 1]), command.call(221, 1, []), command.call(216, 1, [0]), command.call(201, 1, [0, 836, 10, 7, 8, 2]),
            command.call(0, 1, []), command.call(412, 0, []), command.call(0, 0, [])]
interpreter = Game_Interpreter.new(straight)
interpreter.index = 1
interpreter.execute_command
check("a branch that moves the player there itself is left out from its start, before its fade and the airship's landing (review H2)",
      interpreter.list.map(&:code), [111, 0, 412, 0])
done.call
interpreter = Game_Interpreter.new(list)
interpreter.execute_command
check("once the world's story opens it, the choice stays as it is", interpreter.list.equal?(list), true)
