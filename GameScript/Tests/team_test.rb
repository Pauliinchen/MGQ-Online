#----------------------------------------------------------------
#  team_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Covers team duels in battle, mp_battles_team.rbx with mp_battles_sync.rbx and mp_battles_coop.rbx:
# the two sides on the host and on guests of either side, whose commands reach whose characters,
# and the characters of a player who left, which another player of their side takes over.

require_relative "battle_support"

# Stand-ins for the PvP battle.
module MGQ_MpBattlesPvp
  class Opponent < Game_MpActor
    attr_accessor :mp_seat, :mp_place
  end
  module Opponents; def self.stand(opponents); opponents; end; end
end
load_script "mp_battles_team"

team = MGQ_MpBattlesTeam
sync = MGQ_MpBattlesSync
wire = MGQ_MpBattlesSync::Wire
scene = Scene_Battle.new
$scene_now = scene

mine = (1..4).map { |id| Game_Actor.new(id) }
$game_party.own = mine.dup
friend = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "b-friend", "name" => "Friend", "map" => "5" }, nil, true)
rival = MGQ_MpOverworldSync::Peers::Peer.new(5, { "id" => "a-rival", "name" => "Rival", "map" => "5" }, nil, false)
mate = MGQ_MpOverworldSync::Peers::Peer.new(6, { "id" => "c-mate", "name" => "Mate", "map" => "5" }, nil, false)
MGQ_MpOverworldSync::Peers.all.push(friend, rival, mate)
$leader = :me
$leaders = [rival]

# The host's sides, as the duel's gathering arranges them.
$my_seat = 0
builds, max = MGQ_MpBattlesCoop.team_build
check("a player of a team duel sends their Frontline", [builds, max], ["1,2,3,4", 8])
own = MGQ_MpBattlesCoop.arrange([[2, "Friend", "7,8,9,10", [], 8], [0, "Me", builds, [], max]])
other = MGQ_MpBattlesCoop.arrange([[6, "Mate", "30,31,32,33", [], 8], [5, "Rival", "20,21,22,23", [], 8]])
check("each side has its leader first and two of each player's Frontline in front", [own, other].map { |side| side.map { |p| [p[0], p[6], p[7]] } },
      [[[0, 2, 2], [2, 2, 2]], [[5, 2, 2], [6, 2, 2]]])
solo = MGQ_MpBattlesCoop.arrange([[5, "Rival", "20,21,22,23", [], 8]])
check("a single player brings their whole Frontline", solo.map { |p| p[6] }, [4])

sync.join_world(:host, "t1", [2, 5, 6], "the duel", :pvp, true)
team.prepare(own, other, true)
$game_troop.members = team.opponents
sync.battle_started
team.form(scene)
check("the host's party is its side, its troop the other side", [$game_party.battle_members.map(&:name), $game_troop.members.map(&:name)],
      [["Actor1", "Actor2", "Actor7 (Friend)", "Actor8 (Friend)"], ["Actor20 (Rival)", "Actor21 (Rival)", "Actor30 (Mate)", "Actor31 (Mate)"]])
check("the other side's characters know their owners", $game_troop.members.map { |o| [o.mp_seat, o.mp_place] }, [[5, 0], [5, 1], [6, 0], [6, 1]])
check("a team duel is a PvP battle with several guests", [sync.team?, sync.coop?, sync.several?, sync.same_side?], [true, false, true, true])
check("Discord names the other side's leader", team.opponent_name, "Rival")

# Commands reach their owner's characters, on either side.
skill = lambda { |id| [["skill", id, 0]] }
MGQ_MpBattlesSync::Commands.apply(wire.line([[skill.call(11), skill.call(12), [], []]]), 5)
check("a guest of the other side commands their characters in the host's troop", $game_troop.members.map { |o| o.actions.map(&:item) },
      [[[:skill, 11]], [[:skill, 12]], [], []])
MGQ_MpBattlesSync::Commands.apply(wire.line([[skill.call(13), [], skill.call(14), []]]), 6)
check("never another player's", $game_troop.members.map { |o| o.actions.map(&:item) }, [[[:skill, 11]], [[:skill, 12]], [[:skill, 14]], []])
MGQ_MpBattlesSync::Commands.apply(wire.line([[skill.call(15), [], skill.call(16), []]]), 2)
check("a guest of the host's side commands theirs in the host's party", [$game_party.battle_members[0].actions, $game_party.battle_members[2].actions.map(&:item)],
      [[], [[:skill, 16]]])
check("the host commands only its own characters", $game_party.battle_members.map(&:inputable?), [true, true, false, false])

# A player who leaves leaves their characters to their side.
$sent.clear
sync.guest_left(5)
team.settle
heirs = $sent.map { |_, text| fields_of(text) }.find { |f| f["battle"] == "team_heirs" }
check("the first player of their side still in it takes them over, told to the guests", [team.heir_of(5), wire.parse(heirs[:payload])[0]], [6, [5, 6]])
MGQ_MpBattlesSync::Commands.apply(wire.line([[skill.call(21), skill.call(22), skill.call(23), []]]), 6)
check("whose commands then reach them", $game_troop.members.map { |o| o.actions.map(&:item).last }, [[:skill, 21], [:skill, 22], [:skill, 23], nil])
$sent.clear
team.settle
check("nothing more while nobody else leaves", $sent.size, 0)
sync.guest_left(2)
team.settle
check("the host takes over its own side's leavers", [team.heir_of(2), $game_party.battle_members.map(&:inputable?)], [0, [true, true, true, true]])
check("the other side is still there", team.other_side_gone?, false)
sync.guest_left(6)
check("until all its players left", team.other_side_gone?, true)
check("which the host's link check sees as the end", MGQ_MpBattlesSync::Channel.world_gone?, true)
MGQ_MpBattlesCoop.ended
sync.finish

# A guest of the other side.
$my_seat = 5
$game_party.own = mine.dup
MGQ_MpBattlesCoop.team_build
sync.join_world(:guest, "t2", [0], "Me", :pvp, true)
team.prepare(other, own, false)
$game_troop.members = team.opponents
sync.battle_started
team.form(scene)
check("the other side's guest has its side as party, the host's as troop", [$game_party.battle_members.map(&:name), $game_troop.members.map(&:name)],
      [["Actor1", "Actor2", "Actor30 (Mate)", "Actor31 (Mate)"], ["Actor1 (Me)", "Actor2 (Me)", "Actor7 (Friend)", "Actor8 (Friend)"]])
check("so the host's references swap", [sync.same_side?, MGQ_MpBattlesSync::Playback.battler("a1").name, MGQ_MpBattlesSync::Playback.battler("e2").name],
      [false, "Actor2 (Me)", "Actor30 (Mate)"])
check("its commands are its own characters'", wire.parse(MGQ_MpBattlesSync::Commands.build)[0].map(&:size), [0, 0, 0, 0])
MGQ_MpBattlesSync::Channel.receive(0, "team_heirs", wire.line([[6, 5]]))
MGQ_MpBattlesSync::Channel.receive(0, "events", "")
MGQ_MpBattlesSync::Playback.reset
MGQ_MpBattlesSync::Playback.next_event(scene)
ally = $game_party.battle_members[2]
check("a taken-over character can be commanded", [team.heir_of(6), ally.inputable?], [5, true])
ally.actions = [Game_Action.new(ally).tap { |a| a.set_skill(7); a.target_index = 1; a.item = RPG::Skill.new; def (a.item).id; 7; end }]
check("and its commands go to the host", wire.parse(MGQ_MpBattlesSync::Commands.build)[0][2], [["skill", 7, 1]])
check("a guest leaves a team duel rather than forfeiting it", MGQ_MpBattlesSync::Live.escape_leaves?, true)
MGQ_MpBattlesCoop.ended
sync.finish

# A guest of the host's side.
$my_seat = 2
$game_party.own = mine.dup
MGQ_MpBattlesCoop.team_build
sync.join_world(:guest, "t3", [0], "Me", :pvp, true)
team.prepare(own, other, true)
check("the host's side's guest keeps the host's references", [sync.same_side?, MGQ_MpBattlesSync::Playback.battler("a0").equal?($game_party.battle_members[0])], [true, true])
$aborted = false
MGQ_MpBattlesSync::Live.team_end("process_abort")
check("a host who left ends the duel for its side without a winner", [$aborted, $game_message_texts.to_a.last], [true, "Me left the duel."])

# A host's wait for its guests starts with nobody ready, whatever an earlier wait left behind.
$my_seat = 0
sync.finish
sync.join_world(:host, "t4", [2, 5, 6], "the duel", :pvp, true)
team.prepare(own, other, true)
MGQ_MpBattlesSync::Live.instance_variable_set(:@ready, [5, 6])
MGQ_MpBattlesSync::Channel.receive(2, "ready", "")
$answers = []
$game_system = Struct.new(:conf).new({})
def (MGQ_MpBattlesSync::Waiting).wait_for(scene, text); $answers << yield; :broken; end
MGQ_MpBattlesSync::Live.host_start(scene)
check("guests ready in an earlier wait do not count in the next", $answers, [nil])
