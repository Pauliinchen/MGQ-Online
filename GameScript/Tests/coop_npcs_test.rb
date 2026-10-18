#----------------------------------------------------------------
#  coop_npcs_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-17: Checked that a player resuming a frozen raid boss fight follows no Map Owner
#      Paulinchen  2026-10-12: Checked that a whole map that failed to reach a newcomer is sent again
#      Paulinchen  2026-10-11: Checked that a follower on another map forgets the last map's events
#      Paulinchen  2026-10-09: Checked that the Map Owner sends the events to everyone on the map in one message
#      Paulinchen  2026-10-08: Checked a Raid World's shared map, its Map Owner and its blockers
#                            - Asked coop_scope.rbx for the players sharing the map
#                            - Stood in for MGQ_MpOverworldSync::Peers.on_this_map?
#      Paulinchen  2026-10-06: Checked that a party member whose connection is down is left out of the map's party
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# Covers coop_npcs.rbx where events meet party members: a member blocks an event that walks on its
# own, but never a story's forced route or an event while the leader's story plays. In a Raid World
# everyone on the map shares it.

require_relative "support"

# Stands in for the loader's log, printing its lines.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
# Stands in for coop.rbx's routes, ignored here.
module MGQ_MpCoop; def self.route(*); end; end
# Stands in for coop_events.rbx, the leader's story playing while $telling is.
module MGQ_MpCoopEvents; def self.telling?; $telling; end; end
# Stands in for the map.
class Game_Map; def update(main = false); end; end
# Stands in for an event walking on its own, which the game's own characters block at x 9.
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

# A player's ghost on the map.
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

# A party member whose connection is down does not count on the map, so they hold no events still.
# Stands in for the world room's players, kept in $peers.
module MGQ_MpOverworldSync
  def self.in_world?; true; end
  module Peers
    # A player in the room, away set while their connection is down.
    Peer = Struct.new(:seat, :state, :ghost, :member, :away)
    def self.all; $peers; end
    def self.on_this_map?(peer); peer.away.nil? && peer.state["map"].to_i == $game_map.map_id; end
  end
end
# Stands in for the party's id.
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
# Stands in for world.rbx, a Raid World while $raid is.
module MGQ_MpWorld; def self.raid?; $raid; end; end
# Gives the world room stand-in who, tell into $told, the own state and the players present.
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
MGQ_MpCoop.take_map("npcs", stranger, { "map_npcs" => "5", "mmap" => "5", "full" => "0", "events" => "1:3,3,8,0" })
check("a part of the map before the Map Owner's whole map moves nothing", MGQ_MpCoopNpcs.targets[1], nil)
MGQ_MpCoop.take_map("npcs", stranger, { "map_npcs" => "5", "mmap" => "5", "full" => "1", "events" => "1:4,4,8,0" })
check("the Map Owner's events come through the map's gate", MGQ_MpCoopNpcs.targets[1], [4, 4, 8, 0])
MGQ_MpCoop.take_map("npcs", elsewhere, { "map_npcs" => "9", "mmap" => "9", "full" => "0", "events" => "1:9,9,2,0" })
check("but nothing from a player on another map", MGQ_MpCoopNpcs.targets[1], [4, 4, 8, 0])
[stranger, connected].each { |peer| peer.state["map"] = "7" }
$game_map.map_id = 7
MGQ_MpCoopNpcs.update
check("a follower who comes onto another map, still following, forgets the last map's events", [MGQ_MpCoopNpcs.following?, MGQ_MpCoopNpcs.targets], [true, {}])
MGQ_MpCoop.take_map("npcs", stranger, { "map_npcs" => "7", "mmap" => "7", "full" => "0", "events" => "1:9,9,2,0" })
check("and follows none before the Map Owner's whole map came", MGQ_MpCoopNpcs.targets[1], nil)
[stranger, connected].each { |peer| peer.state["map"] = "5" }
$game_map.map_id = 5
MGQ_MpCoopNpcs.update
stranger.state["since"] = "9000"
MGQ_MpCoopNpcs.update
check("once the player came first, their game moves the events", MGQ_MpCoopNpcs.following?, false)
check("and sends them to the seats new on the map, then to everyone on it in one message, through the map's gate",
      $told.map { |seat, fields| [seat, fields["map_npcs"], fields["mmap"], fields.key?("npcs")] },
      [[2, 5, 5, false], [4, 5, 5, false], [-1, 5, 5, false]])

# A whole map that fails to go out is sent again on the Map Owner's beat until it does.
# Keeps the log's lines in $npc_log too.
module MGQ_Multiplayer; module Log; def self.write(m); $npc_log << m; puts "  log: #{m}"; end; end; end
# Lets a tell fail while $tell_fails is.
module MGQ_MpOverworldSync; def self.tell(seat, fields); $told << [seat, fields]; !$tell_fails; end; end
$npc_log = []
newcomer = MGQ_MpOverworldSync::Peers::Peer.new(6, { "id" => "n", "name" => "Newcomer", "map" => "5", "since" => "9500" }, nil, false, nil)
$peers << newcomer
wholes = lambda { $told.count { |seat, fields| seat == 6 && fields["full"] == 1 } }
$told.clear
$tell_fails = true
MGQ_MpCoopNpcs.instance_variable_set(:@frames, 0)
MGQ_MpCoopNpcs.update
check("a newcomer is sent the whole map at once", wholes.call, 1)
(MGQ_MpCoopNpcs::SEND_FRAMES - 2).times { MGQ_MpCoopNpcs.update }
check("which failed, so it is not sent again every frame", wholes.call, 1)
MGQ_MpCoopNpcs.update
check("but again on the next beat", wholes.call, 2)
check("the failure logged once for the newcomer's arrival", $npc_log.grep(/seat 6 all .* failed/).size, 1)
$tell_fails = false
MGQ_MpCoopNpcs::SEND_FRAMES.times { MGQ_MpCoopNpcs.update }
check("until it goes out", [wholes.call, $npc_log.grep(/sent seat 6 all/).size], [3, 1])
MGQ_MpCoopNpcs::SEND_FRAMES.times { MGQ_MpCoopNpcs.update }
check("and then no more", wholes.call, 3)
newcomer.state["since"] = "9900"
MGQ_MpCoopNpcs.update
check("a player who came onto the map again gets it anew at once", wholes.call, 4)
$peers.delete(newcomer)
$raid = false
check("in a Classic world again only the party shares the map", MGQ_MpCoopNpcs.peers_here, [connected])

# A player who resumes a frozen raid boss fight moves the map's events in their own game meanwhile,
# whose scene put them where they stood at the battle.
# Stands in for battles_raid_freeze.rbx, resuming while $resuming is.
module MGQ_MpRaidFreeze; def self.resuming?(_troop = nil); $resuming; end; end
MGQ_MpCoopNpcs.instance_variable_set(:@role, :follower)
MGQ_MpCoopNpcs.instance_variable_set(:@targets, { 1 => [9, 9, 2, 0] })
$resuming = true
$npc_log.clear
check("a follower who resumes a frozen fight follows nobody", MGQ_MpCoopNpcs.following?, false)
MGQ_MpCoopNpcs.follow
check("and walks no event toward the Map Owner's places, saying so once", [$game_map.events[1].mgq_mp_npc_state, $npc_log.grep(/left the events of map 5 where they are: the player resumes/).size],
      [[2, 3, 2, 0], 1])
$resuming = false
check("once the resume ended, the follower follows again", MGQ_MpCoopNpcs.following?, true)
