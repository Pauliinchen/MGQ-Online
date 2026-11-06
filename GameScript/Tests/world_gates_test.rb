#----------------------------------------------------------------
#  world_gates_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Answered the shut area of a move with fixed values and checked what the script asks
#      Paulinchen  2026-11-05: Checked that a move kept back goes to the one guard of the game's flow
#                            - Read the scripts' clock from $frame_count
#      Paulinchen  2026-10-24: Created
#
#----------------------------------------------------------------

# Covers world_gates.rbx: a Raid World's gated areas, which nobody enters from outside before the
# world's story meets their needs, by any move or by a choice that leads there. WorldGatesTests own
# which area is shut and what it lacks.

require_relative "support"
require_relative "bridge_support"

# Stands in for the game's data.
module RPG
  # An event command.
  EventCommand = Struct.new(:code, :indent, :parameters)
end
# The scripts' clock reads $frame_count.
clock_from { $frame_count }
$frame_count = 1000
# Stands in for the map, on $map_id.
class Game_Map; def map_id; $map_id; end; end
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
# Stands in for the one guard of the game's flow (coop_flow.rbx), keeping why each move was kept back in $refused.
module MGQ_MpFlowGuard; def self.refused(why); ($refused ||= []) << why; end; end
load_script "world_gates"
# The DLL's side of the bridge: the gates read variables 1311 and 1345, and the Central Tartarus is
# shut while $missing names what the world's story lacks, each move asked kept in $asked.
bridge = FakeBridge.new
$asked = []
bridge.answer("gates.reads") { [1311, 1345] }
bridge.answer("gates.shut") do |request|
  $asked << request
  request["to"] == 1836 && !$missing.empty? ? { "area" => "Central Tartarus", "missing" => $missing } : nil
end
MGQ_Multiplayer::Bridge.open(bridge)

gates = MGQ_MpWorldGates
$game_map = Game_Map.new
$game_player = Game_Player.new
$game_variables = Hash.new(0)
$game_variables[1311] = 6
$raid = true
$map_id = 1287
$missing = ["Koron", "Granberia's Nightmare"]

# Moves.
$game_player.reserve_transfer(1836, 10, 10)
check("a Raid World keeps everyone out of an area the DLL tells is shut", $moves.to_a, [])
check("asked with the map, the player's map and the world's story the gates read", $asked.last, { "to" => 1836, "at" => 1287, "v" => [6, 0] })
check("and says what the world still has to finish", $notices.last, "Central Tartarus opens once the world finished: Koron, Granberia's Nightmare.")
$game_player.reserve_transfer(1836, 10, 10)
check("telling it once in a while", [$moves.to_a, $notices.size], [[], 1])
check("and hands each move kept back to the guard of the game's flow, which puts back the screen the scene faded out", $refused, ["Central Tartarus is shut"] * 2)
$missing = ["Koron"]
$frame_count += gates::NOTICE_FRAMES
$game_player.reserve_transfer(1836, 10, 10)
check("and names only what is missing", $notices.last, "Central Tartarus opens once the world finished: Koron.")
$missing = []
$game_player.reserve_transfer(1836, 10, 10)
check("a move the DLL lets go goes", $moves, [1836])
$missing = ["Koron"]
$raid = false
asked = $asked.size
$game_player.reserve_transfer(1836, 10, 10)
check("a Classic world gates nothing and asks nothing", [$moves, $asked.size], [[1836, 1836], asked])
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
$missing = []
interpreter = Game_Interpreter.new(list)
interpreter.execute_command
check("once the world's story opens it, the choice stays as it is", interpreter.list.equal?(list), true)
