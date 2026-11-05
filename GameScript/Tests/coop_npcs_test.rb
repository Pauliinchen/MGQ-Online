#----------------------------------------------------------------
#  coop_npcs_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Expected the events of the map handed over as values
#      Paulinchen  2026-10-30: Checked the frame told to the DLL, the events handed to it and those it gives to follow, and left its rules to MGQOnline.Game.Tests
#      Paulinchen  2026-10-23: Handed the Map Owner's events to the route past the DLL's map gate
#                            - Checked that a follower whose own event runs follows no Map Owner meanwhile
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
# everyone on the map shares it. Each frame tells the DLL the map and its Map Owner, hands it the
# events when it asks and follows the events it gives once they changed (MGQOnline.Game.Tests covers
# its rules).

require_relative "party_support"

# Stands in for the loader's log, printing its lines and keeping them in $npc_log.
module MGQ_Multiplayer; module Log; def self.write(m); ($npc_log ||= []) << m; puts "  log: #{m}"; end; end; end
# Stands in for coop.rbx's routes and event names.
module MGQ_MpCoop; def self.route(*); end; def self.event_name(_id); ""; end; end
# Stands in for the world's sync's routes, which keep each field's handler in $routes.
module MGQ_MpOverworldSync; def self.route(field, _gate = nil, &handler); ($routes ||= {})[field] = handler; end; end
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
MGQ_Multiplayer::Bridge.open(answer_party(FakeBridge.new))

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
# Gives the world room stand-in who, the own state and the players present.
module MGQ_MpOverworldSync
  def self.who(peer); peer == :me ? "the player" : peer.state["name"].to_s; end
  module Me; def self.map_since; 2000; end; def self.id; "me"; end; end
  module Peers; def self.present; $peers.select { |peer| peer.away.nil? }; end; end
end
# Stands in for overworld.rbx's tiles beyond which an event moves to its place at once.
module MGQ_MpOverworld; CATCH_UP_TILES = 8; end
# An event that stands, faces, walks and shows its first page.
class StandingEvent
  attr_reader :x, :y, :direction
  def initialize(x, y); @x = x; @y = y; @direction = 2; end
  def mgq_mp_npc_free?; true; end
  def mgq_mp_page; 0; end
  def mgq_mp_npc_state; [@x, @y, @direction, 0]; end
  def moving?; false; end
  def moveto(x, y); @x = x; @y = y; end
  def mgq_mp_npc_face(direction); @direction = direction; end
  def move_straight(direction); @x += { 4 => -1, 6 => 1 }.fetch(direction, 0); @y += { 2 => 1, 8 => -1 }.fetch(direction, 0); end
end
$raid = true
connected.state.update("id" => "c", "name" => "Member", "since" => "3000")
stranger.state.update("id" => "s", "name" => "Stranger", "since" => "1000")
elsewhere.state.update("id" => "e", "name" => "Elsewhere", "since" => "500")
stranger.ghost = Ghost.new(6, 6)
$peers = [connected, dropped, stranger, elsewhere]
standing = StandingEvent.new(2, 3)
# Stands in for the map's interpreter, running an event while $running is.
MapInterpreter = Struct.new(:event_id) { def running?; $running; end }
$running = false
$game_map = Struct.new(:map_id, :events, :interpreter).new(5, { 1 => standing }, MapInterpreter.new(12))
check("in a Raid World everyone on the map shares it, but not who is elsewhere or away", MGQ_MpCoopNpcs.peers_here, [connected, stranger])
check("its Map Owner is whoever entered it first, party or not", MGQ_MpCoopNpcs.owner(MGQ_MpCoopNpcs.peers_here), stranger)
MGQ_MpCoopNpcs.update
check("each frame tells the DLL the map and the Map Owner's seat", $npc_calls, [["npcs.update", { "map" => 5, "owner" => 4, "arrivals" => {} }]])
check("so the player's game follows them", MGQ_MpCoopNpcs.following?, true)
check("and every player on the map blocks an event, not only party members", MGQ_MpCoopNpcs.member_at?(6, 6), true)

# The DLL took the Map Owner's whole map.
$npc_frame = { "snapshot" => false, "revision" => 1 }
$npc_targets = { "revision" => 1, "whole" => true, "targets" => { 1 => [9, 9, 8, 0] } }
$npc_calls.clear
$npc_log.clear
MGQ_MpCoopNpcs.update
check("a new revision reads the events to follow", [$npc_calls.map(&:first), MGQ_MpCoopNpcs.targets], [["npcs.update", "npcs.targets"], { 1 => [9, 9, 8, 0] }])
check("and a whole map places every event at once", [standing.x, standing.y, standing.direction, $npc_log.grep(/took all 1 event\(s\) of map 5 from Stranger, placing them/).size], [9, 9, 8, 1])
$npc_targets = { "revision" => 2, "whole" => false, "targets" => { 1 => [7, 9, 8, 0] } }
$npc_frame = { "snapshot" => false, "revision" => 2 }
MGQ_MpCoopNpcs.update
check("a part walks the event a step toward its place", [standing.x, standing.y], [8, 9])
$npc_calls.clear
MGQ_MpCoopNpcs.update
check("the same revision is not read again", $npc_calls.map(&:first), ["npcs.update"])

# The player came first, so their game moves the events.
stranger.state["since"] = "9000"
$npc_frame = { "snapshot" => true, "revision" => 3 }
$npc_targets = { "revision" => 3, "whole" => false, "targets" => {} }
$npc_turned = [[1, 0, 1]]
$npc_calls.clear
$npc_log.clear
MGQ_MpCoopNpcs.update
check("once the player came first, their game moves the events", MGQ_MpCoopNpcs.following?, false)
check("and tells the DLL when each player sharing the map came onto it",
      $npc_calls.first, ["npcs.update", { "map" => 5, "owner" => -1, "arrivals" => { 2 => "3000", 4 => "9000" } }])
check("handing it every event of the map when it asks", $npc_calls[1], ["npcs.snapshot", { "map" => 5, "events" => [[1, 7, 9, 8, 0]] }])
check("and naming the pages that changed in what went to everyone", $npc_log.grep(/event 1 on map 5 turned to page 1 from 0, told the others/).size, 1)

# Nobody shares the map any more.
$npc_frame = { "snapshot" => false, "revision" => 3 }
$peers = []
$npc_calls.clear
MGQ_MpCoopNpcs.update
MGQ_MpCoopNpcs.update
check("the DLL hears once that nobody shares the map", $npc_calls, [["npcs.update", { "map" => 5, "owner" => nil, "arrivals" => {} }]])
$raid = false

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
      [[7, 9, 8, 0], 1])
$resuming = false
check("once the resume ended, the follower follows again", MGQ_MpCoopNpcs.following?, true)

# A follower's own event, such as their own story or an autorun, moves the map's events in their
# own game while it runs, since its move routes may wait for them; once it ended they stand where
# the Map Owner's do (issue #57). Another player's story the follower watches leaves them followed.
# Stands in for coop_scene.rbx, the player watching another player's story while $watching is.
module MGQ_MpCoopScene; def self.watching?; $watching; end; end
standing = StandingEvent.new(2, 3)
$game_map.events[1] = standing
MGQ_MpCoopNpcs.instance_variable_set(:@targets, { 1 => [5, 3, 4, 0] })
$watching = true
$running = true
MGQ_MpCoopNpcs.follow
check("a follower who watches another player's story follows the Map Owner", [MGQ_MpCoopNpcs.following?, standing.x], [true, 3])
$watching = false
$npc_log.clear
MGQ_MpCoopNpcs.follow
MGQ_MpCoopNpcs.follow
check("one whose own event runs follows nobody meanwhile, saying so once",
      [MGQ_MpCoopNpcs.following?, standing.x, $npc_log.grep(/left the events of map 5 to the player's own game: it runs event 12/).size], [false, 3, 1])
MGQ_MpCoopNpcs.targets[1] = [9, 9, 8, 0]
$running = false
MGQ_MpCoopNpcs.follow
check("once it ended, the events stand where the Map Owner's do at once", [MGQ_MpCoopNpcs.following?, standing.x, standing.y, standing.direction], [true, 9, 9, 8])
