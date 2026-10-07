#----------------------------------------------------------------
#  coop_gather_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Created
#
#----------------------------------------------------------------

# Covers coop_gather.rbx where time and the world end what it waits for: a leader's call lapses, and
# a loaded save or the world closing forgets the calls, the question where the leader stands and the
# hold, since a loaded save sets the frame count back.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
module Graphics; def self.frame_count; $frame_count; end; def self.brightness; 255; end; end
class Game_Interpreter; def execute_command; end; end
class Game_Map; attr_accessor :map_id; def initialize; @map_id = 3; end; def update(main = false); end; end
class Game_Player
  attr_accessor :x, :y
  def initialize; @x = 0; @y = 0; end
  def direction; 2; end
  def encounter; true; end
  def movable?; true; end
  def perform_transfer; end
  def transfer?; false; end
  def make_encounter_count; end
end
class Scene_Map; def update_call_menu; end; end
module DataManager; def self.extract_save_contents(contents); end; end
module MGQ_MpActions; def self.own_line_from(&line); end; end
module MGQ_MpOverworldSync
  module Peers; Peer = Struct.new(:seat, :state); end
  def self.on_tick(&block); $tick = block; end
  def self.notice(text); ($notices ||= []) << text; end
end
module MGQ_MpCoop
  module Party; def self.members; [$member]; end; end
  def self.party_leader; $leader; end
  def self.party_leading?; $leader == :me; end
  def self.in_party?; true; end
end
module MGQ_MpCoopEvents
  def self.pvp_running?; false; end
  def self.tell(seat, kind, fields = {}); ($sent ||= []) << [seat, kind]; true; end
end

load_script "coop_gather"

gather = MGQ_MpCoopGather
$game_map = Game_Map.new
$game_player = Game_Player.new
$leader = MGQ_MpOverworldSync::Peers::Peer.new(2, { "name" => "Leader", "map" => "9", "x" => "10", "y" => "10" })
place = [9, 10, 10, 2]
$frame_count = 5000

gather.called($leader, place)
check("a member the leader calls is coming", gather.coming?, true)
$frame_count += MGQ_MpCoopGather::CALL_LAPSE_FRAMES
check("until the calls stop", gather.coming?, false)

gather.called($leader, place)
$frame_count = 100
check("a call from before a loaded save's lower frame count is long past", gather.coming?, false)

gather.called($leader, place)
DataManager.extract_save_contents({})
check("a loaded save forgets the call", gather.coming?, false)

gather.called($leader, place)
$tick.call(true)
check("an open world keeps it", gather.coming?, true)
$tick.call(false)
check("the world closing forgets it", gather.coming?, false)

gather.join_leader
check("a member asks the leader where they stand", $sent.last, [2, "where"])
DataManager.extract_save_contents({})
gather.answered($leader, place, false)
check("and a loaded save forgets the question", gather.coming?, false)

$member = $leader
$leader = :me
gather.hold(Game_Interpreter.new)
check("the leader's story waits for the party", gather.holding_story?, true)
DataManager.extract_save_contents({})
check("until a save is loaded", gather.holding_story?, false)
