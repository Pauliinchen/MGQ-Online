#----------------------------------------------------------------
#  raid_scope_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Checked the messages of a Classic world to several members and to a lone member
#      Paulinchen  2026-10-09: Checked messages to the whole map or several players going out once
#                            - Checked tellers whose connection is down and the teller who took the player along
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# Covers coop_scope.rbx: whom the player shares the map and the story with, the party in a Classic
# world and everyone on the map in a Raid World, the map's gate and the sends to the seats on the map.

require_relative "support"

# The mod's log, printed with the checks.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$routes = {}
$told = []
# The open world: the other players from $peers, the player's own map entry from $since, and the
# routes and sends recorded in $routes and $told.
module MGQ_MpOverworldSync
  # The other players of the world.
  module Peers
    # Another player: their seat, their state, their ghost, whether they are in the party and since when
    # their connection is down.
    Peer = Struct.new(:seat, :state, :ghost, :member, :away)
    # Every other player.
    def self.all; $peers; end
    # The other players whose connection stands.
    def self.present; $peers.select { |peer| peer.away.nil? }; end
    # Whether a player whose connection stands is on the player's map.
    def self.on_this_map?(peer); peer.away.nil? && peer.state["map"].to_i == $game_map.map_id; end
  end
  # The player: id me, on the map since $since.
  module Me; def self.map_since; $since; end; def self.id; "me"; end; end
  # The player is always in a world.
  def self.in_world?; true; end
  # Names a player for the log.
  def self.who(peer); peer == :me ? "the player" : (peer ? peer.state["name"].to_s : "an unknown player"); end
  # Keeps a field's handler in $routes.
  def self.route(field, &handler); $routes[field] = handler; end
  # Records a send in $told.
  def self.tell(seat, fields); $told << [seat, fields]; true; end
end
# The party: its id from $party and its leader from $leader; sends through its gate go to $told.
module MGQ_MpCoop
  # The party's id.
  module Party; def self.id; $party; end; end
  # The party's leader.
  def self.party_leader; $leader; end
  # Whether the player is in a party.
  def self.in_party?; !$party.nil?; end
  # Records a send through the party's gate in $told.
  def self.tell(seat, field, value, fields = {}); $told << [seat, { field => value, "party" => $party }.merge(fields)]; true; end
end
# The story's telling: whether the player tells it, from $telling, and follows it, from $following.
module MGQ_MpCoopEvents
  # Whether the player tells the story.
  def self.telling?; $telling; end
  # The story markers as the telling started, nil while not telling.
  def self.told_markers; $telling ? [12, 0, 0, 0] : nil; end
  # Whether the player follows a telling.
  def self.following?; $following; end
end
# How far each story is, and the synced members, as coop_story.rbx tells them.
module MGQ_MpCoopStory
  # Reads four comma-separated story markers, nil for anything else.
  def self.read_markers(text); values = text.to_s.split(","); values.size == 4 ? values.map(&:to_i) : nil; end
  # The player's own story markers.
  def self.own_markers; $own_markers; end
  # The members synced with the player.
  def self.synced_members; $synced; end
  # Whether the player follows the leader's story.
  def self.follows_leader?; $following; end
  # Whether the player leads synced members.
  def self.leading_synced?; !$synced.empty?; end
end

load_script "coop_scope"

scope = MGQ_MpCoop::Scope
$game_map = Struct.new(:map_id).new(5)
$game_variables = {}
$own_markers = [12, 0, 0, 0]
$since = 2000
$telling = false
$following = false
$synced = []
$party = "p1"
member = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "m", "name" => "Member", "map" => "5", "since" => "3000", "sm" => "12,0,0,0" }, nil, true, nil)
stranger = MGQ_MpOverworldSync::Peers::Peer.new(3, { "id" => "k", "name" => "Stranger", "map" => "5", "since" => "2000", "sm" => "9,0,0,0" }, nil, false, nil)
elsewhere = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "e", "name" => "Elsewhere", "map" => "8", "since" => "100", "sm" => "12,0,0,0" }, nil, false, nil)
away = MGQ_MpOverworldSync::Peers::Peer.new(5, { "id" => "a", "name" => "Away", "map" => "5", "since" => "100", "sm" => "12,0,0,0" }, nil, false, 600)
$peers = [member, stranger, elsewhere, away]
$leader = member

check("without world.rbx's answer the world is Classic", [scope.raid?, scope.current], [false, scope::Classic])
# The world script before it can tell the world's type.
module MGQ_MpWorld; end
check("as it is while world.rbx cannot tell the type yet", scope.raid?, false)
# The world script, which tells a Raid World from $raid.
module MGQ_MpWorld; def self.raid?; $raid; end; end
$raid = false

check("a Classic world shares the map with the party members on it", scope.peers_here, [member])
check("its teller is the party's leader", scope.teller, member)
check("its story goes to the synced members", [scope.viewers, ($synced = [member]; scope.viewers)], [[], [member]])
check("which the player follows only while synced", [scope.watches?(member), scope.follows_teller?, ($following = true; scope.watches?(member))], [false, false, true])
$following = false
scope.tell(-1, "npcs", 5, "full" => 0)
check("its messages go through the party's gate, to everyone", $told.last, [-1, { "npcs" => 5, "party" => "p1", "full" => 0 }])
check("and only a party shares at all", [scope.sharing?, ($party = nil; scope.sharing?)], [true, false])
$party = "p1"

$raid = true
check("a Raid World is told by world.rbx", [scope.raid?, scope.current], [true, scope::Raid])
check("it shares the map with everyone on it whose connection stands, party or not", scope.peers_here, [member, stranger])
check("and shares it without a party too", ($party = nil; scope.sharing?), true)
$party = "p1"
check("its sync host entered the map first, the lower id among equals", scope.sync_host, stranger)
stranger.state["since"] = "3000"
check("the player when they came first", scope.sync_host, :me)
check("who tells the story here is nobody while nobody's state says so", scope.teller, nil)
member.state["telling"] = "1"
check("the player on the map whose state says they tell it", [scope.teller, scope.follows_teller?, scope.leads_story?], [member, true, false])
elsewhere.state["telling"] = "1"
check("never one on another map", scope.teller, member)
$telling = true
check("the player while telling, having entered the map before the other teller", [scope.teller, scope::Raid.first_teller_here], [:me, :me])
$since = 4000
check("still the player once the other teller entered it first, of whom only a tie hears",
      [scope.teller, scope::Raid.first_teller_here], [:me, member])
$since = 2000
member.state["telling"] = "0"
check("the story goes to the players on the map whose story is where the player's was as the telling started",
      scope.viewers, [member])
# The players the story took along, as coop_gather.rbx tells them.
module MGQ_MpCoopGather; def self.taken_along; $along; end; def self.story_map?(map_id); map_id == $game_map.map_id; end; end
$along = [elsewhere, member]
check("and to those it took along who are not on the map yet", scope.viewers, [member, elsewhere])
$along = []
$telling = false
member.state["telling"] = "1"
check("a player whose story matches the teller's watches it", scope.watches?(member), true)
member.state["tsm"] = "11,0,0,0"
check("as told when the telling started, not as the teller's story moved on since", scope.watches?(member), false)
member.state.delete("tsm")
check("pages come from the teller alone", [scope.story_from?(member), scope.story_from?(stranger)], [true, false])
member.state["telling"] = "0"
check("or from anyone while nobody's state says they tell yet, since states and pages travel apart", scope.story_from?(stranger), true)

$told.clear
MGQ_MpCoop.tell_map(-1, "npcs", 5, "full" => 1)
check("a message to everyone on the map goes out once, marked for the map's gate, which sorts it on arrival",
      $told.map { |seat, fields| [seat, fields["map_npcs"], fields["mmap"], fields["full"], fields.key?("party")] },
      [[-1, 5, 5, 1, false]])
$told.clear
$game_map.map_id = 6
check("and not at all while nobody else is on the map", [MGQ_MpCoop.tell_map(-1, "npcs", 6), $told], [true, []])
$game_map.map_id = 5
scope.tell_each([member, elsewhere], "pevent", "say", "page" => "x")
check("a message for several players goes out once and names them, wherever they stand",
      $told.map { |seat, fields| [seat, fields["map_pevent"], fields["mto"], fields["mmap"]] }, [[-1, "say", "m,e", 5]])
$told.clear
scope.tell_each([member], "pevent", "say", "page" => "x")
check("one for a single player goes to their seat", $told.map { |seat, fields| [seat, fields.key?("mto")] }, [[2, false]])
$told.clear
$raid = false
scope.tell_each([member, stranger], "pevent", "say", "page" => "x")
check("a Classic world sends several members one message through the party's gate, which those it is not for ignore",
      $told.map { |seat, fields| [seat, fields["pevent"], fields.key?("mto")] }, [[-1, "say", false]])
$told.clear
scope.tell_each([member], "pevent", "say", "page" => "x")
check("and a lone member one to their seat", $told.map { |seat, _fields| seat }, [2])
$raid = true
$told.clear
scope.tell(4, "pevent", "follow", "mmap" => 8)
check("a message to one seat goes there, and may name the map it is for", $told, [[4, { "map_pevent" => "follow", "mmap" => 8 }]])

taken = []
MGQ_MpCoop.route_map("npcs") { |peer, message| taken << [peer.state["id"], message["npcs"]] }
check("the map's gate listens on its own field", $routes.keys, ["map_npcs"])
$routes["map_npcs"].call(stranger, { "map_npcs" => "5", "mmap" => "5" })
$routes["map_npcs"].call(elsewhere, { "map_npcs" => "8", "mmap" => "8" })
$routes["map_npcs"].call(nil, { "map_npcs" => "5", "mmap" => "5" })
$routes["map_npcs"].call(elsewhere, { "map_npcs" => "5", "mmap" => "5" })
check("it takes a message from a player on the map, or one for the player's map, and hands it on under its field",
      taken, [["k", "5"], ["e", "5"]])
# The map the story takes the player to, as coop_gather.rbx tells it.
module MGQ_MpCoopGather; def self.story_map?(map_id); map_id == $game_map.map_id || map_id == 8; end; end
taken.clear
$routes["map_npcs"].call(elsewhere, { "map_npcs" => "8", "mmap" => "8" })
check("and one for the map the story takes the player to", taken, [["e", "8"]])
taken.clear
$routes["map_npcs"].call(stranger, { "map_npcs" => "5", "mmap" => "5", "mto" => "m,k" })
$routes["map_npcs"].call(stranger, { "map_npcs" => "6", "mmap" => "5", "mto" => "k,me" })
check("but none that names other players", taken, [["k", "6"]])

# Tellers whose connection is down, and the one whose story took the player along.
member.state.merge!("telling" => "1", "since" => "3000")
stranger.state.merge!("telling" => "0")
elsewhere.state["telling"] = "0"
member.away = 600
check("a teller whose connection is down still tells until their game is forgotten", [scope.teller, scope::Raid.first_teller_here, scope.watches?(member)], [member, member, true])
member.away = nil
elsewhere.state.merge!("telling" => "1", "map" => "8", "since" => "9000")
check("of two tellers on the story's maps the one who entered their map first", scope.teller, member)
# The player whose story took the player along, from $followed.
module MGQ_MpCoopGather; def self.followed_id; $followed; end; end
# The player whose pages the player follows, from $heard.
module MGQ_MpCoopEvents; def self.heard_from; $heard; end; end
$followed = "e"
check("but the one whose story takes the player along, though another entered first", [scope.teller, scope.story_from?(elsewhere), scope.story_from?(member)], [elsewhere, true, false])
$followed = nil
$heard = "e"
check("or whose pages the player follows", scope.teller, elsewhere)
elsewhere.state["telling"] = "0"
check("until they stop telling", scope.teller, member)
$heard = nil
member.state["telling"] = "0"
elsewhere.state["map"] = "8"
