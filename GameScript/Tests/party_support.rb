#----------------------------------------------------------------
#  party_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Stood in for the player's squad over the party
#                            - Stood in for the NPCs shared on a map
#                            - Created
#
#----------------------------------------------------------------

# The DLL's side of the party's teleports (MGQOnline.Game's Teleports, behind TeleportTopics), of
# the NPCs shared on a map (Npcs, behind NpcTopics) and of the player's squad over the party
# (Squads/SquadView, behind SquadViewTopics) for the script tests, on the test's FakeBridge: each
# topic is written down and answered with what a test sets, the teleports' view while a test sets
# none and the squad with the party as its mirror stands. The rules themselves are
# MGQOnline.Game.Tests', the teleports' and the NPCs' replayed from the scripts' golden cases.

require_relative "bridge_support"

# The teleports' calls the scripts made, each [topic, request].
$teleport_calls = []

# The teleports' view a test sets for the DLL to answer, nil for the party's members as the mirror
# counts them, each offered a teleport.
$teleport_view = nil

# Where the player stands as the scripts handed it last with the view, nil before.
$teleport_place = nil

# Writes the teleports' view as the DLL answers it while no request stands: each member offered the
# teleport to them, at once to the party's leader, closed while the player stands within three
# tiles of them.
#
# @return [Hash] The view.
def stand_in_teleport_view
  return $teleport_view if $teleport_view

  members = {}
  if MGQ_MpCoop.in_party?
    leader = MGQ_MpCoop.party_leader
    MGQ_MpCoop::Party.members.each do |peer|
      name = peer.state["name"].to_s
      near = $teleport_place && peer.state["map"].to_i == $teleport_place["map"] &&
             [(peer.state["x"].to_i - $teleport_place["x"]).abs, (peer.state["y"].to_i - $teleport_place["y"]).abs].max <= 3
      members[peer.seat] = { "text" => leader.equal?(peer) ? "Teleport to #{name}" : "Ask to teleport to #{name}", "refusal" => near ? "You are with #{name} already." : nil,
                             "request" => nil, "allow" => nil, "call" => nil, "notice" => nil, "action" => nil }
    end
  end
  { "tpask" => "", "doing" => nil, "own" => [], "members" => members }
end

# Answers the teleports' topics with stand_in_teleport_view, writing each call down.
#
# @param fake [FakeBridge] The bridge.
def answer_teleports(fake)
  %w[tp.ask tp.allow tp.decline tp.stop tp.forget tp.view].each do |topic|
    fake.answer(topic) do |request|
      $teleport_calls << [topic, request]
      $teleport_place = request if topic == "tp.view"
      stand_in_teleport_view
    end
  end
end

# The NPC calls the scripts made, each [topic, request].
$npc_calls = []

# What the NPCs' frame answers: whether the Map Owner's events are needed and the revision of those
# followed.
$npc_frame = { "snapshot" => false, "revision" => 0 }

# The events followed as a test sets them: their revision, whether a whole map came, and the places.
$npc_targets = { "revision" => 0, "whole" => false, "targets" => {} }

# The pages that changed in what the Map Owner's events sent, as a test sets them.
$npc_turned = []

# Answers the NPCs' topics with what a test sets, writing each call down.
#
# @param fake [FakeBridge] The bridge.
def answer_npcs(fake)
  fake.answer("npcs.update") { |request| $npc_calls << ["npcs.update", request]; $npc_frame }
  fake.answer("npcs.snapshot") { |request| $npc_calls << ["npcs.snapshot", request]; { "turned" => $npc_turned } }
  fake.answer("npcs.targets") { |request| $npc_calls << ["npcs.targets", request]; $npc_targets }
end

# Reads the player's squad as the DLL does, over the party as its mirror stands and the squad math
# of rules_support.rb, which the test loads.
#
# @param request [Hash] The request of squad.view.
# @return [Hash] "share", "mode" and "squads".
def stand_in_squad_view(request)
  in_party = MGQ_MpCoop.in_party?
  leader = in_party ? MGQ_MpCoop.party_leader : :me
  mode = leader == :me || leader.nil? ? request["own_mode"] : (leader.state["follow"].to_s == "1" ? 1 : 0)
  share =
    if request["raid"]
      SquadStandIn.raid(request["rules"], request["max"])[request["raid_fight"] ? "raid" : "regular"]
    elsif in_party
      players = [[MGQ_MpOverworldSync::Me.id, leader == :me]] + MGQ_MpCoop::Party.members.map { |peer| [peer.state["id"].to_s, peer.equal?(leader)] }
      SquadStandIn.shares(players.size, request["max"])[SquadStandIn.ranked(players).index(0)] || [0, 0]
    end
  { "share" => share, "mode" => mode, "squads" => request["raid"] || in_party }
end

# Answers the squad's view with stand_in_squad_view.
#
# @param fake [FakeBridge] The bridge.
def answer_squad_view(fake)
  fake.answer("squad.view") { |request| stand_in_squad_view(request) }
end

# Answers every topic of the party's rules this file stands in for.
#
# @param fake [FakeBridge] The bridge.
# @return [FakeBridge] The bridge.
def answer_party(fake)
  answer_teleports(fake)
  answer_npcs(fake)
  answer_squad_view(fake)
  fake
end
