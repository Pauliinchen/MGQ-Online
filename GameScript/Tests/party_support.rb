#----------------------------------------------------------------
#  party_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the player's squad and the teleports' view with the values each test sets instead of from their stand-ins
#                            - Answered the player's squad with the share each test sets instead of from the squad math's stand-in
#      Paulinchen  2026-10-30: Stood in for the player's squad over the party
#                            - Stood in for the NPCs shared on a map
#                            - Created
#
#----------------------------------------------------------------

# The DLL's side of the party's teleports (MGQOnline.Game's Teleports, behind TeleportTopics), of
# the NPCs shared on a map (Npcs, behind NpcTopics) and of the player's squad over the party
# (Squads/SquadView, behind SquadViewTopics) for the script tests, on the test's FakeBridge: each
# topic is written down and answered with what a test sets. The rules themselves are
# MGQOnline.Game.Tests', the teleports' and the NPCs' replayed from the scripts' golden cases.

require_relative "bridge_support"

# The teleports' calls the scripts made, each [topic, request].
$teleport_calls = []

# The teleports' view a test sets for the DLL to answer, nil for one that offers nothing.
$teleport_view = nil

# The teleports' view with no member offered anything.
NO_TELEPORTS = { "tpask" => "", "doing" => nil, "own" => [], "members" => {} }.freeze

# Writes a member's offer of the teleports' view: the teleport to them, unless a refusal closes it.
#
# @param text [String] The offer, such as "Teleport to Friend".
# @param refusal [String, nil] Why it is closed, nil for open.
# @return [Hash] The offer.
def teleport_offer(text, refusal = nil)
  { "text" => text, "refusal" => refusal, "request" => nil, "allow" => nil, "call" => nil, "notice" => nil, "action" => nil }
end

# Writes the teleports' view with offers to members and nothing else under way.
#
# @param members [Hash{Integer => Hash}] Each member's offer by their seat, see teleport_offer.
# @return [Hash] The view.
def teleport_view(members)
  NO_TELEPORTS.merge("members" => members)
end

# Answers the teleports' topics with the view a test sets, writing each call down.
#
# @param fake [FakeBridge] The bridge.
def answer_teleports(fake)
  %w[tp.ask tp.allow tp.decline tp.stop tp.forget tp.view].each do |topic|
    fake.answer(topic) do |request|
      $teleport_calls << [topic, request]
      $teleport_view || NO_TELEPORTS
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

# The player's squad as squad.view answers it, which a test sets for its case: "share" (the
# Frontline and Backline), "mode" (the followers') and "squads"; nil for that of a player alone
# outside a Raid World.
$squad_view = nil

# The squad.view requests, oldest first.
$squad_view_asks = []

# The squad of a player alone outside a Raid World, the followers active.
NO_SQUAD = { "share" => nil, "mode" => 0, "squads" => false }.freeze

# Writes the squad of a player in squads.
#
# @param share [Array<Integer>] The Frontline and Backline.
# @param mode [Integer] The followers' mode.
# @return [Hash] The answer of squad.view.
def squad_view(share, mode = 0)
  { "share" => share, "mode" => mode, "squads" => true }
end

# Answers the squad's view with the one a test sets, writing each request down.
#
# @param fake [FakeBridge] The bridge.
def answer_squad_view(fake)
  fake.answer("squad.view") { |request| $squad_view_asks << request; $squad_view || NO_SQUAD }
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
