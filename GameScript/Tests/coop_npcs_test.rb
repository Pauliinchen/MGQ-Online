#----------------------------------------------------------------
#  coop_npcs_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-08: Checked a Raid World: everyone on the map shares it, whoever entered first moves its events, every player there blocks them, and the Map Owner sends to the seats on the map alone
#                            - Asked the scope for the players sharing the map, which coop_scope.rbx now tells
#                            - Stood in for MGQ_MpOverworldSync::Peers.on_this_map?, which the map's party now asks
#      Paulinchen  2026-10-06: Checked that a party member whose connection is down is left out of the map's party
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# Covers coop_npcs.rbx where events meet party members: a member blocks an event that walks on its
# own, but never a story's forced route or an event while the leader's story plays. In a Raid World
# everyone on the map shares it.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
module MGQ_MpCoop; def self.route(*); end; end
module MGQ_MpCoopEvents; def self.telling?; $telling; end; end
class Game_Map; def update(main = false); end; end
class Game_Event
  attr_accessor :move_route_forcing, :priority
  def initialize; @priority = 1; end
  def update_self_movement; end
  def collide_with_characters?(x, y); x == 9; end
  def near_the_player?; false; end
  def move_toward_player; end
  def normal_priority?; @priority == 1; end
end

load_script "coop_scope"
load_script "coop_npcs"

Ghost = Struct.new(:x, :y)
MGQ_MpCoopNpcs.instance_variable_set(:@blockers, [Ghost.new(3, 4)])
event = Game_Event.new
$telling = false
check("a member blocks an event walking on its own", event.collide_with_characters?(3, 4), true)
check("but not another tile", event.collide_with_characters?(3, 5), false)
check("the game's own characters still block", event.collide_with_characters?(9, 0), true)
event.move_route_forcing = true
check("a story's forced route walks through a member", event.collide_with_characters?(3, 4), false)
event.move_route_forcing = false
$telling = true
check("as does any event while the leader's story plays", event.collide_with_characters?(3, 4), false)
$telling = false
event.priority = 0
check("an event below the characters never collides", event.collide_with_characters?(3, 4), false)

# A party member whose connection is down no longer counts on the map, so they hold no events still.
module MGQ_MpOverworldSync
  def self.in_world?; true; end
  module Peers
    Peer = Struct.new(:seat, :state, :ghost, :member, :away)
    def self.all; $peers; end
    def self.on_this_map?(peer); peer.away.nil? && peer.state["map"].to_i == $game_map.map_id; end
  end
end
module MGQ_MpCoop; module Party; def self.id; "p1"; end; end; end
$game_map = Struct.new(:map_id).new(5)
connected = MGQ_MpOverworldSync::Peers::Peer.new(2, { "map" => "5" }, nil, true, nil)
dropped = MGQ_MpOverworldSync::Peers::Peer.new(3, { "map" => "5" }, nil, true, 600)
$peers = [connected, dropped]
check("a party member whose connection is down is left out of the map's party", MGQ_MpCoopNpcs.peers_here, [connected])

# A Raid World shares the map with everyone on it, party or not, and its sync host moves the events.
stranger = MGQ_MpOverworldSync::Peers::Peer.new(4, { "map" => "5" }, nil, false, nil)
elsewhere = MGQ_MpOverworldSync::Peers::Peer.new(5, { "map" => "9" }, nil, false, nil)
check("in a Classic world a player outside the party shares nothing", MGQ_MpCoopNpcs.peers_here, [connected])
module MGQ_MpWorld; def self.raid?; $raid; end; end
module MGQ_MpOverworldSync
  def self.who(peer); peer == :me ? "the player" : peer.state["name"].to_s; end
  def self.tell(seat, fields); $told << [seat, fields]; true; end
  module Me; def self.map_since; 2000; end; def self.id; "me"; end; end
  module Peers; def self.present; $peers.select { |peer| peer.away.nil? }; end; end
end
$raid = true
$told = []
connected.state.update("id" => "c", "name" => "Member", "since" => "3000")
stranger.state.update("id" => "s", "name" => "Stranger", "since" => "1000")
elsewhere.state.update("id" => "e", "name" => "Elsewhere", "since" => "500")
stranger.ghost = Ghost.new(6, 6)
$peers = [connected, dropped, stranger, elsewhere]
npc = Struct.new(:mgq_mp_npc_state).new([2, 3, 2, 0])
$game_map = Struct.new(:map_id, :events).new(5, { 1 => npc })
check("in a Raid World everyone on the map shares it, but not who is elsewhere or away", MGQ_MpCoopNpcs.peers_here, [connected, stranger])
check("its Map Owner is whoever entered it first, party or not", MGQ_MpCoopNpcs.owner(MGQ_MpCoopNpcs.peers_here), stranger)
MGQ_MpCoopNpcs.update
check("so the player's game follows them", MGQ_MpCoopNpcs.following?, true)
check("and every player on the map blocks an event, not only party members", MGQ_MpCoopNpcs.member_at?(6, 6), true)
MGQ_MpCoop.take_map("npcs", stranger, { "map_npcs" => "5", "mmap" => "5", "full" => "0", "events" => "1:4,4,8,0" })
check("the Map Owner's events come through the map's gate", MGQ_MpCoopNpcs.targets[1], [4, 4, 8, 0])
MGQ_MpCoop.take_map("npcs", elsewhere, { "map_npcs" => "9", "mmap" => "9", "full" => "0", "events" => "1:9,9,2,0" })
check("but nothing from a player on another map", MGQ_MpCoopNpcs.targets[1], [4, 4, 8, 0])
stranger.state["since"] = "9000"
MGQ_MpCoopNpcs.update
check("once the player came first, their game moves the events", MGQ_MpCoopNpcs.following?, false)
check("and sends them to the seats on the map alone, through the map's gate",
      $told.map { |seat, fields| [seat, fields["map_npcs"], fields["mmap"], fields.key?("npcs")] },
      [[2, 5, 5, false], [4, 5, 5, false], [2, 5, 5, false], [4, 5, 5, false]])
$raid = false
check("in a Classic world again only the party shares the map", MGQ_MpCoopNpcs.peers_here, [connected])
