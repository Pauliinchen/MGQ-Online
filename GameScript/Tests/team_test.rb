#----------------------------------------------------------------
#  team_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the squad math with fixed values per case
#                            - Read the messages sent as the scripts hand them
#                            - Answered the commands' plan, the sides and the waits with the values each case sets and checked what the scripts ask
#                            - Wrote and read the battle lines through the codec's stand-in
#      Paulinchen  2026-10-30: Set the guests ready in an earlier wait on the stand-in of the DLL
#      Paulinchen  2026-10-12: Checked the commanders a guest takes for the characters of players who left
#      Paulinchen  2026-10-11: Let the waiting box stand-in take the names waited for and their prefix
#      Paulinchen  2026-10-06: Checked that team duel players bring no share of the Backline
#                            - Checked that a guest names no commands for the others' characters
#      Paulinchen  2026-10-04: Followed the scripts to their new names
#      Paulinchen  2026-10-02: Ended the guest's duel through guest_end
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Covers team duels in battle, battles_team.rbx with battles_sync.rbx and battles_coop.rbx:
# the two sides on the host and on guests of either side, whose commands reach whose characters,
# and the characters of a player who left, which another player of their side takes over.

require_relative "battle_support"

# The DLL's arrangement of the battles' players below (SquadMathTests covers it), by the players
# handed over, each [id, first, party_member_max, characters], answered as [index, Frontline,
# Backline] of each in their order.
$rule_answers.cases("squad.arrange", {
  [["b-friend", false, 8, 4], ["id-me", true, 8, 4]] => [[1, 2, 0], [0, 2, 0]],
  [["c-mate", false, 8, 4], ["a-rival", true, 8, 4]] => [[1, 2, 0], [0, 2, 0]],
  [["a-rival", true, 8, 4]] => [[0, 4, 0]]
}) { |request| request["players"] }

# Stands in for the PvP battle.
module MGQ_MpBattlesPvp
  # Stands in for a rebuilt character of the other side.
  class Opponent < Game_MpActor; end
  # Stands in for the opponents: stands them nowhere and answers them as they are.
  module Opponents; def self.stand(opponents); opponents; end; end
end
load_script "battles_team"

team = MGQ_MpBattlesTeam
sync = MGQ_MpBattlesSync
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
own = MGQ_MpBattlesCoop.arrange([[2, "Friend", "7,8,9,10", [], 8], [0, "Me", builds, [], max]], false)
other = MGQ_MpBattlesCoop.arrange([[6, "Mate", "30,31,32,33", [], 8], [5, "Rival", "20,21,22,23", [], 8]], false)
check("each side has its leader first and two of each player's Frontline in front, none on the Backline", [own, other].map { |side| side.map { |p| [p[0], p[6], p[7]] } },
      [[[0, 2, 0], [2, 2, 0]], [[5, 2, 0], [6, 2, 0]]])
solo = MGQ_MpBattlesCoop.arrange([[5, "Rival", "20,21,22,23", [], 8]], false)
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
check("the player's Frontline characters past their share wait on no Backline", $game_party.bench_members, [])

# Commands reach their owner's characters, on either side.

# Builds one character's commands as a guest sends them: a skill on the first target.
#
# @param id [Integer] The skill.
# @return [Array<Array>] The commands.
skill = lambda { |id| [["skill", id, 0]] }
# Plans the commands the DLL lets reach each place, a skill on the first target for each id.
#
# @param ids [Array<Integer, nil>] The skill of each place, nil for a place left as it is.
# @return [Hash] The plan.
planned = lambda { |*ids| { "places" => ids.map { |id| id && [["skill", id, 0, nil]] } } }
$live.set("live.plan", planned.call(11, 12, nil, nil))
MGQ_MpBattlesSync::Commands.apply(wire_line([[skill.call(11), skill.call(12), [], []]]), 5)
plan = $live.asked("live.plan").last
check("a guest of the other side's commands go to the DLL with the owners of the host's troop", [plan["seat"], plan["several"], plan["owners"]], [5, true, [5, 5, 6, 6]])
check("and reach the characters of the troop it plans them for", $game_troop.members.map { |o| o.actions.map(&:item) }, [[[:skill, 11]], [[:skill, 12]], [], []])
$live.set("live.plan", planned.call(nil, nil, 16, nil))
$live.set("live.mode same_side", true)
MGQ_MpBattlesSync::Commands.apply(wire_line([[skill.call(15), [], skill.call(16), []]]), 2)
check("a guest the DLL places on the host's side commands with the owners of the host's party and reaches its characters",
      [$live.asked("live.mode").last, $live.asked("live.plan").last["owners"], $game_party.battle_members[0].actions, $game_party.battle_members[2].actions.map(&:item)],
      [{ "op" => "same_side", "seat" => 2 }, [nil, nil, 2, 2], [], [[:skill, 16]]])
$live.set("live.plan", nil)
$live.set("live.mode same_side", nil)
check("the host commands only its own characters", $game_party.battle_members.map(&:inputable?), [true, true, false, false])

# A player who leaves leaves their characters to their side.
$sent.clear
sync.guest_left(5)
$live.set("live.team settle", "heirs" => [[5, 6]], "post" => wire_line([[5, 6]]))
team.settle
heirs = $sent.map(&:last).find { |f| f["battle"] == "team_heirs" }
check("the host asks the DLL who takes over, keeps the heirs it answers and tells the guests its message",
      [$live.asked("live.team").last, team.heir_of(5), heirs && heirs[:payload]], [{ "op" => "settle", "host" => 0 }, 6, wire_line([[5, 6]])])
$sent.clear
$live.set("live.team settle", "heirs" => [[5, 6], [2, 0]])
team.settle
check("the host commands its own side's characters the DLL hands it, telling nothing it answers no message for",
      [team.heir_of(2), $game_party.battle_members.map(&:inputable?), $sent.size], [0, [true, true, true, true], 0])
$live.set("live.team gone", "gone" => false)
check("the other side is still there while the DLL says so", [team.other_side_gone?, $live.asked("live.team").last], [false, { "op" => "gone", "host" => 0 }])
$live.set("live.team gone", "gone" => true)
check("and gone once it says all its players left", team.other_side_gone?, true)
$live.set("live.tick world", "ask" => true)
$live.set("live.mode gone", true)
check("the host's link check sees the end where the DLL lets the duel decide and it finds the other side gone",
      [MGQ_MpBattlesSync::Channel.world_gone?, $live.asked("live.mode").last], [true, { "op" => "gone", "host" => 0 }])
$live.set("live.mode gone", false)
check("but not while it finds the other side there", MGQ_MpBattlesSync::Channel.world_gone?, false)
$live.set("live.team settle", nil)
$live.set("live.team gone", nil)
$live.set("live.tick world", nil)
$live.set("live.mode gone", nil)
MGQ_MpBattlesCoop.ended
sync.finish

# A guest of the other side sees the sides swapped.
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
check("its commands are its own characters'", wire_values(MGQ_MpBattlesSync::Commands.build)[0].map { |list| list && list.size }, [0, 0, nil, nil])
$live.set("live.team take", "heirs" => [[6, 5]])
$live.set("live.mode kinds", ["team_heirs"])
MGQ_MpBattlesSync::Channel.receive(0, "team_heirs", wire_line([[6, 5]]))
MGQ_MpBattlesSync::Channel.receive(0, "events", "")
MGQ_MpBattlesSync::Playback.reset
MGQ_MpBattlesSync::Playback.next_event(scene)
$live.set("live.mode kinds", nil)
ally = $game_party.battle_members[2]
check("a guest hands the host's heirs to the DLL from the stream, and a character it took over can be commanded",
      [$live.asked("live.team").last, team.heir_of(6), ally.inputable?], [{ "op" => "take", "body" => wire_line([[6, 5]]) }, 5, true])
ally.actions = [Game_Action.new(ally).tap { |a| a.set_skill(7); a.target_index = 1; a.item = RPG::Skill.new; def (a.item).id; 7; end }]
check("and its commands go to the host", wire_values(MGQ_MpBattlesSync::Commands.build)[0][2], [["skill", 7, 1]])
check("a guest leaves a team duel rather than forfeiting it", MGQ_MpBattlesSync::Live.escape_leaves?, true)
MGQ_MpBattlesCoop.ended
sync.finish

# A guest of the host's side sees the sides as the host does.
$my_seat = 2
$game_party.own = mine.dup
MGQ_MpBattlesCoop.team_build
sync.join_world(:guest, "t3", [0], "Me", :pvp, true)
team.prepare(own, other, true)
check("the host's side's guest keeps the host's references", [sync.same_side?, MGQ_MpBattlesSync::Playback.battler("a0").equal?($game_party.battle_members[0])], [true, true])
$aborted = false
$live.set("live.end guest", "first" => "the host's battle ended", "process" => "take_over", "otherwise" => { "process" => "process_abort", "message" => "Me left the duel." })
MGQ_MpBattlesSync::Live.guest_end("process_abort", nil)
check("a guest of the host's side asks the DLL how the host's end ends its battle, and ends it so once the duel cannot take it over",
      [$live.asked("live.end").last, $aborted, $game_message_texts.to_a.last], [{ "of" => "guest", "result" => "process_abort", "side" => true }, true, "Me left the duel."])
$live.set("live.end guest", nil)

# A host's wait for its guests starts with nobody ready, whatever an earlier wait left behind.
$my_seat = 0
sync.finish
sync.join_world(:host, "t4", [2, 5, 6], "the duel", :pvp, true)
team.prepare(own, other, true)
$live.set("live.phase ready", "all" => false)
$answers = []
$game_system = Struct.new(:conf).new({})
# Stands in for the waiting box: records the block's first answer in $answers and ends the wait.
def (MGQ_MpBattlesSync::Waiting).wait_for(scene, text, *rest); $answers << yield; :broken; end
MGQ_MpBattlesSync::Live.host_start(scene)
steps = $live.asked("live.phase").map { |request| request["op"] }
check("a host's wait for its guests forgets who was ready before it asks, and waits while the DLL counts not all ready",
      [steps.index("ready_reset") < steps.index("ready"), $answers], [true, [nil]])
$live.set("live.phase ready", nil)

# A guest takes the heirs the DLL reads of the host's message, and nobody of one it finds broken.
$live.set("live.team take", "heirs" => [[7, 5]])
team.take_heirs(wire_line([[7, 5]]))
check("a guest keeps the heirs the DLL reads", [team.heir_of(7), team.heir_of(6)], [5, nil])
$live.set("live.team take", "heirs" => [], "broken" => true)
team.take_heirs("broken")
check("and nobody from a message it finds broken, logged once", [team.heir_of(7), $log.grep(/where the host sent no pair of seats/).size], [nil, 1])
