#----------------------------------------------------------------
#  world_room_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Played the DLL telling who stands near the player
#      Paulinchen  2026-11-05: Named each told player by the name the test wrote instead of by a copy of the DLL's naming
#                            - Handed states and messages over with their fields as the test writes them instead of through a copy of the DLL's codec
#                            - Read a message as the DLL reads it
#                            - Handed states and messages over with each field as its kind reads
#      Paulinchen  2026-11-01: Handed the chat's messages to C#, which the chat's model takes, and dropped the stand-in for its send
#      Paulinchen  2026-10-31: Dropped the messages whose field a rule in C# takes, as the room does
#      Paulinchen  2026-10-23: Kept the stand-in bridge a test already opened
#                            - Created
#
#----------------------------------------------------------------

# Stands in for the DLL's world room (MGQOnline.Game's WorldRoom) through the fake bridge: it
# records what the scripts hand the DLL and lets the tests play the DLL's events (the players'
# states, the party's view, routed messages) straight into the scripts' mirror. It keeps none of
# the room's rules (settle and away windows, the party, the gates), which MGQOnline.Game.Tests
# covers against the scripts' former cases. Require it before loading overworld_sync.rbx.

require_relative "bridge_support"

load_bridge unless defined?(MGQ_Multiplayer::Bridge)

# The fields the rules in C# take through WorldRoom.Take, the party's own included: the room hands
# a message carrying one of them to C#, never to the scripts.
CSHARP_FIELDS = %w[kick party_decline ptp npcs map_npcs coop map_coop trade chat whisper pchat]

# The fake DLL the scripts' world room topics go to, the test's one FakeBridge, which the rules' and
# the interface's answers share.
$world_bridge ||= FakeBridge.new
# What the scripts staged for the world room, each [topic, payload].
$staged_world = []
# The party's actions the scripts asked the DLL for, each [action, request].
$party_calls = []

%w[world.me world.routes world.reset_since].each do |topic|
  $world_bridge.answer(topic) { |request| $staged_world << [topic, request]; nil }
end
# Answers when the player entered a map: $map_since, 1000 by default.
$world_bridge.answer("world.since") { |map| { "map" => map, "since" => $map_since || 1_000 } }
# Records a party action and answers $party_answer, else the view the scripts hold.
%w[invite stop_inviting join decline leave remove].each do |action|
  $world_bridge.answer("party.#{action}") do |request|
    $party_calls << [action, request]
    $party_answer || (defined?(MGQ_MpCoop::Party) ? MGQ_MpCoop::Party.instance_variable_get(:@view) : nil)
  end
end
MGQ_Multiplayer::Bridge.open($world_bridge)

# A state as the DLL hands it on, its fields as the test writes them, marked as a state.
#
# @param state [Hash] The state's fields.
# @return [Hash] The state.
def plain_state(state)
  { "state" => "1" }.merge(state)
end

# The names the DLL hands to tell the players apart, by seat: each told player's name as the test
# wrote it, as no check gives two players one name.
$peer_labels = {}

# Plays the DLL telling that another player told their state: the mirror takes it with the names
# of $peer_labels, and the scripts follow it.
#
# @param seat [Integer] Their seat.
# @param state [Hash] Their state's fields.
# @param member [Boolean, nil] Whether the party counts them, nil to take the party's view's word.
# @return [MGQ_MpOverworldSync::Peers::Peer] The player.
def peer_told(seat, state, member = nil)
  peers = MGQ_MpOverworldSync::Peers
  state = plain_state(state)
  if member.nil?
    member = defined?(MGQ_MpCoop::Party) && !MGQ_MpCoop::Party.id.nil? && state["party"] == MGQ_MpCoop::Party.id &&
             MGQ_MpCoop::Party.instance_variable_get(:@view)["member_ids"].include?(state["id"])
  end
  peers.take(seat, state, member)
  name = state["name"].to_s
  name.empty? ? $peer_labels.delete(seat) : ($peer_labels[seat] = name)
  peers.take_labels($peer_labels.dup)
  peers.at(seat)
end

# Plays the DLL telling who stands near the player, as its Sessions counts them.
#
# @param seats [Array<Integer>] Their seats.
def near_seats(*seats)
  MGQ_MpOverworldSync::Peers.take_near(seats)
end

# Plays the DLL handing a message to the script registered for its field, past the gates; one
# carrying a field of CSHARP_FIELDS goes to C# and the scripts get nothing.
#
# @param seat [Integer, nil] The sender's seat, nil for the relay.
# @param fields [Hash] The message's fields.
# @param body [String] What follows them.
# @param relay [Boolean] Whether the relay pushed it.
def message_from(seat, fields, body = "", relay = false)
  message = Hash[fields.map { |key, value| [key.to_s, value] }]
  return if message.keys.any? { |key| CSHARP_FIELDS.include?(key) }

  MGQ_MpOverworldSync.take_route("field" => message.keys.first, "seat" => seat, "fields" => message, "body" => body, "relay" => relay)
end

# Writes the party's view as the DLL posts it.
#
# @param id [String, nil] The party's id, nil outside a party.
# @param members [Array<MGQ_MpOverworldSync::Peers::Peer>] Its other members.
# @param leader [Integer, nil] The leader's seat, -1 for the player.
# @param more [Hash] Other fields of the view, such as "inviting".
# @return [Hash] The view.
def party_view(id, members = [], leader = -1, more = {})
  ids = members.map { |peer| peer.state["id"].to_s }
  view = MGQ_MpCoop::Party::NONE.merge("id" => id, "leader" => id ? leader : nil, "members" => members.map(&:seat), "member_ids" => ids,
                                       "admitted" => id ? ids : [], "admitted_me" => !id.nil?, "may_invite" => members.empty? || leader == -1,
                                       "parties" => id ? { id => [members.size + 1, leader] } : {})
  view.merge(more)
end

# Plays the DLL posting the party's view.
#
# @param id [String, nil] The party's id, nil outside a party.
# @param members [Array<MGQ_MpOverworldSync::Peers::Peer>] Its other members.
# @param leader [Integer, nil] The leader's seat, -1 for the player.
# @param more [Hash] Other fields of the view.
def take_party(id, members = [], leader = -1, more = {})
  MGQ_MpCoop::Party.take_view(party_view(id, members, leader, more))
end

# Plays one frame as the game does: the player's frame staged, the bridge's batch and drain, then
# the scripts' tick.
def world_frame
  MGQ_MpOverworldSync.before_frame
  MGQ_Multiplayer::Bridge.frame
  MGQ_MpOverworldSync.tick
end

# The world room's inbox as the tests fill it: each entry the DLL would turn into events goes to
# the mirror at once, a state as peer_told, any other message as message_from, a dropped
# connection as away; seats and newcomers are the DLL's alone.
class WorldInbox
  # Plays an entry, see entry.
  #
  # @param item [Hash] The entry.
  # @return [WorldInbox] The inbox.
  def <<(item)
    seat = item["seat"].to_i
    case item["kind"]
    when "seat" then MGQ_MpOverworldSync::Me.take_seat(seat)
    when "out" then MGQ_MpOverworldSync::Peers.away(seat)
    when "message"
      fields = item[:payload].dup
      body = fields.delete(:payload).to_s
      fields["state"] ? peer_told(seat, fields.reject { |key, _| key == "state" }) : message_from(seat, fields, body)
    end
    self
  end

  # Empties nothing, as every entry was played at once.
  def clear; end

  # Hands out no entry, as every entry was played at once.
  #
  # @return [nil] None.
  def shift; end
end
