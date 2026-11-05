#----------------------------------------------------------------
#  battles_coop_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Compared the colors of the names in the status window by their values
#      Paulinchen  2026-11-05: Answered the squad math with fixed values per case
#                            - Read the messages sent as the scripts hand them and handed those of other games as the DLL reads them
#                            - Answered the co-op topics with the values each case sets and checked what the scripts ask and do with the answers
#                            - Answered the live battle's topics and the battlers' plans with the values each case sets and checked what the scripts ask
#                            - Expected whether the player is busy as true or false
#                            - Wrote and read the battle lines through the codec's stand-in
#                            - Named a defeat that names no scene without an older host
#                            - Checked that other players' characters, the host's troop and a guest's start go through the game's own battle start
#                            - Checked that a Classic battle invites a party member busy in a menu too, who keeps the invite until free (issue 76)
#                            - Checked that an invite waits while the player types in the chat box
#                            - Checked that a guest taking a battle over goes on from the battlers its start made whole, each started once
#                            - Checked that a guest following its host to another battle starts that battle's troop once
#                            - Checked that the screens the mod opens on its own wait while an invite is open (issue 79)
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#      Paulinchen  2026-10-31: Took a player's color from MGQ_MpPlayerColor
#      Paulinchen  2026-10-30: Handed invites, requests and stand-stills over through the matchmaking's routes
#                            - Checked the matchmaking's wiring on its stand-in, its notices as the DLL's events
#                            - Checked an id past this game's database through the troop the guest takes
#      Paulinchen  2026-10-23: Started the recorder without the deleted file sink
#                            - Took the wait for the host party from roster_frames
#                            - Sent nothing to a player gone from the world
#                            - Checked that a Challenge Battle's enemies keep their kind on the battle server
#      Paulinchen  2026-10-20: Checked the skills a guest chains after an action
#      Paulinchen  2026-10-17: Checked that a guest's start sets the party's battle counters
#                            - Checked that a rebuilt character starts the battle at the HP sent
#      Paulinchen  2026-10-15: Checked that a player whose characters all fell in a won battle or a loaded save stands up
#      Paulinchen  2026-10-12: Read who joined the battle from its popup instead of the chat
#                            - Checked invites while the leader's story calls the player over
#                            - Checked that a leave from a player outside the battle tells nothing
#                            - Checked that the host keeps the actions for a guest's broken commands
#                            - Checked that a broken defeat scene id or enemy is replaced by one here
#                            - Checked that a join whose party_member_max is no number still forms the party
#                            - Checked that a player's fields of the wrong kind are dropped
#                            - Checked that a guest drops a host's enemy whose fields are no numbers
#                            - Checked a host's troop whose places, marks or ids this game cannot take
#                            - Checked the defeat scene a guest picks when leaving or taking a battle over
#      Paulinchen  2026-10-11: Checked that leaving a story's battle without escape loses it for the player alone
#                            - Checked the encounter stretch near other players and Raid invites of those near
#                            - Checked that the party takes commands while the Backline may swap in
#                            - Checked that the status window names each character in its player's color
#                            - Checked that a guest reads in the chat log who joined the host's party
#                            - Checked how long the notice of a member's battle lasts
#                            - Checked status names the mod cannot draw and the host choosing again
#      Paulinchen  2026-10-10: Checked how a Raid World stretches the steps to the next random encounter
#                            - Checked how a Classic party stretches the steps to the next random encounter
#                            - Checked that a Raid boss battle invites the players reading the player's story
#                            - Checked that a guest following its host to another battle fights its pools
#                            - Checked the enemy rates and pools of a player who yields to a rival
#                            - Checked a raid boss battle with empty pools and a rival's invite that comes twice
#                            - Checked that a Raid battle invites no player whose battle waits under the Library
#      Paulinchen  2026-10-09: Checked that a Classic co-op host tells its guest a troop that grew mid-battle
#                            - Checked that a player who yields to a rival's boss battle notes it as one
#                            - Checked that a Raid World's battle takes a player whose window is in the background
#      Paulinchen  2026-10-08: Checked that a face this game lacks is left out of a message the host shows
#                            - Checked that a Raid World's co-op battle gives every player one and two
#                            - Checked that a player brings only their squad to a Raid World's team duel
#                            - Checked whom a Raid World's battle takes and who hosts it
#                            - Checked invites taken back, trading players and refused requests to lead
#                            - Checked who hosts two battles started at the same moment
#                            - Checked waiting invites and rivals, held encounters and the map's gate
#                            - Checked yielding to waiting invites and event battles, and battles called off
#      Paulinchen  2026-10-07: Read a rebuilt character's log line with its id after its name
#                            - Checked what the log names of a co-op battle
#                            - Checked the actions of a guest who leaves or is waited for
#                            - Checked that a guest's party is named after its own characters
#      Paulinchen  2026-10-06: Checked that another player's fallen character comes fallen
#                            - Checked skills that reach the Backline and the Library's counts
#                            - Checked that the end drops the game's Retry and a reset forgets the battle
#                            - Checked a guest who takes over and a guest left out
#                            - Checked that invites and requests the player cannot take are turned down at once
#                            - Checked that a guest's commands go no further than the host's actions
#                            - Checked that the guest takes the turns the host's states have left
#                            - Checked that the guest shows the host's messages with their speaker
#      Paulinchen  2026-10-04: Checked that only players who lost a target to a swap choose again
#                            - Checked that a player who leaves mid-phase stays in the party until the next phase
#                            - Checked the battle's level in the roster and the level sync
#                            - Checked that the host logs a rebuild that differs
#                            - Checked that new states let the game read a guest's character's features anew
#                            - Checked that a member's encounter holds the party members on the map
#                            - Followed the scripts to their new names, without mp_
#                            - Checked the defeat scene the guest of a lost battle takes
#      Paulinchen  2026-10-03: Checked that the others' characters start the battle and each turn with a hit count
#                            - Checked that the map shows the player's own leader again after the battle
#                            - Checked that the party's leader leads a member's battle
#                            - Checked that invites the player cannot take in time are turned down
#                            - Checked that a random encounter waits up to three seconds for busy members on the map
#                            - Checked that a guest's command the character may not give is left out
#      Paulinchen  2026-10-02: Checked a player who joined and left the world before the roster
#                            - Ended the guest's battle through guest_end
#      Paulinchen  2026-10-01: Checked that every player hears at once when another leaves the battle
#                            - Checked that a guest whose troop differs fights the host's enemies
#                            - Checked the squads players bring, the leader first, and swaps with the Backline
#                            - Took the stand-ins from battle_support.rb
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers co-op battles, battles_coop.rbx with battles_sync.rbx, battles.rbx and
# coop_squad.rbx: from the invite to the end of the battle, for the host and for a guest.

require_relative "battle_support"

# The DLL's arrangement of the battles' players below, by the players
# handed over, each [id, first, party_member_max, characters], answered as [index, Frontline,
# Backline] of each in their order.
$rule_answers.cases("squad.arrange", {
  [["id-me", true, 8, 3], ["id-friend", false, 8, 3]] => [[0, 2, 1], [1, 2, 1]],
  [["id-me", true, 8, 3], ["", false, 8, 3]] => [[0, 2, 1], [1, 2, 1]],
  [["id-me", true, 8, 3], ["id-friend", false, 0, 3]] => [[0, 2, 1], [1, 2, 0]],
  [["id-me", true, 8, 3], ["id-friend", false, 8, 3], ["id-other", false, 8, 2]] => [[0, 2, 1], [1, 1, 1], [2, 1, 1]],
  [["id-me", true, 8, 4], ["id-friend", false, 8, 4]] => [[0, 2, 2], [1, 2, 2]],
  [["id-me", false, 8, 4], ["id-friend", true, 8, 4]] => [[1, 2, 2], [0, 2, 2]],
  [["id-me", true, 0, 3]] => [[0, 3, 0]],
  [["id-me", true, 4, 4], ["id-friend", false, 4, 4]] => [[0, 2, 0], [1, 2, 0]],
  [["", false, 4, 1], ["id-me", true, 4, 1]] => [[1, 1, 0], [0, 1, 0]],
  [["id-me", true, 4, 3], ["id-friend", false, 4, 3], ["", false, 4, 3]] => [[0, 1, 2], [2, 1, 2], [1, 1, 2]],
  [["id-me", true, 8, 3], ["id-friend", false, 4, 3]] => [[0, 1, 2], [1, 1, 2]]
}) { |request| request["players"] }
$rule_answers.cases("squad.shares", { { "count" => 2, "max" => 8 } => [[2, 2], [2, 2]], { "count" => 3, "max" => 8 } => [[2, 2], [1, 1], [1, 1]] })
$rule_answers.set("squad.raid", { "regular" => [1, 2], "raid" => [1, 2], "largest" => 3 })

# A co-op battle's guests stand on the host's side, the host's stream carries the party's and the
# troop's changes, and an enemy the host marks 1 is hidden, as the DLL tells.
$live.set("live.mode same_side", true)
$live.set("live.mode kinds", ["coop_party", "coop_troop"])
$battlers.plans["enemy"] = lambda { |request| { "hide" => request["mark"] == 1 } }

mine = [Game_Actor.new(1), Game_Actor.new(2), Game_Actor.new(3)]
$game_party.own = mine
friend = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "id-friend", "name" => "Friend", "map" => "5", "scene" => "map" }, nil, true)
busy = MGQ_MpOverworldSync::Peers::Peer.new(3, { "name" => "Busy", "map" => "5", "scene" => "menu" }, nil, true)
away = MGQ_MpOverworldSync::Peers::Peer.new(4, { "name" => "Away", "map" => "9", "scene" => "map" }, nil, true)
stranger = MGQ_MpOverworldSync::Peers::Peer.new(6, { "name" => "Stranger", "map" => "5", "scene" => "map" }, nil, false)
MGQ_MpOverworldSync::Peers.all.push(friend, busy, away, stranger)
$my_seat = 0
$leader = :me
scene = Scene_Battle.new
$scene_now = scene

# The host: the DLL's matchmaking hosts the battle the game set up, inviting the party.
$coop.hosts("b1", [2, 3])
BattleManager.setup(40, true, false)
offer = $coop.asked("coop.offer").last
check("a battle the game sets up goes to the DLL's matchmaking with its troop, escape and lose, how it came and the player's map",
      [offer["troop"], offer["escape"], offer["lose"], offer["encounter"], offer["joining"], offer["facts"]["map"], offer["facts"]["role"]], [40, true, false, false, false, 5, nil])
check("and becomes the live co-op battle the DLL hosts", [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.battle_id, MGQ_MpBattlesSync.seats, MGQ_MpBattlesSync.coop?, MGQ_MpBattlesSync.live?, MGQ_MpBattles.kind],
      [:host, "b1", [2, 3], true, true, :coop])
check("with the multiplayer rules", BattleManager.can_giveup?, false)

# Reads the request that started the host's last gathering.
#
# @return [Hash] The request.
def gather_start
  $coop.asked("coop.gather").select { |request| request["op"] == "start" }.last
end

# Nobody joins.
$sent.clear
$frames = 0
check("a gathering nobody joined ends", MGQ_MpBattlesCoop.gather(scene), nil)
check("the DLL gathering the invited players for as long as a Classic battle waits", gather_start, { "op" => "start", "seats" => [2, 3], "limit" => MGQ_MpBattlesCoop::JOIN_FRAMES })
check("and without anyone the battle is the host's own", [MGQ_MpBattlesSync.role, MGQ_MpBattles.running?, MGQ_MpBattlesCoop.active?], [nil, false, false])

# Somebody joins, then leaves the world before the roster goes out.
BattleManager.setup(40, true, false)
$sent.clear
$frames = 0
$coop.gathered([2, wire_line(["7,8,9", [[50, 5], [60, 6], [70, 7]], 8])])
MGQ_MpOverworldSync::Peers.all.delete(friend)
check("a player who joined and left the world since does not stop the battle", MGQ_MpBattlesCoop.gather(scene), nil)
check("the DLL hears which invited player the world no longer knows", $coop.asked("coop.gather").select { |request| request["op"] == "frame" }.last["gone"], [2])
roster = $sent.map(&:last).find { |f| f["battle"] == "roster" }
check("and is named as unknown, the roster going to nobody gone", [MGQ_MpBattlesCoop.players.map { |p| [p.seat, p.name] }, roster], [[[0, "Me"], [2, "?"]], nil])
MGQ_MpOverworldSync::Peers.all.unshift(friend)
MGQ_MpBattlesCoop.ended

# Somebody joins with a party_member_max that is no number.
BattleManager.setup(40, true, false)
$sent.clear
$frames = 0
$coop.gathered([2, wire_line(["7,8,9", [[50, 5]], [1]])])
check("a join whose party_member_max is no number still forms the party", MGQ_MpBattlesCoop.gather(scene), nil)
roster = $sent.map(&:last).find { |f| f["battle"] == "roster" }
check("which counts it as 0", wire_values(roster[:payload])[1].map { |p| [p[0], p[4]] }, [[0, 8], [2, 0]])
MGQ_MpBattlesCoop.ended

# Somebody joins.
BattleManager.setup(40, true, false)
$coop.hosts(nil)
join = wire_line(["7,8,9", [[50, 5], [60, 6], [70, 7]], 8])
$sent.clear
$frames = 0
$coop.gathered([2, join])
$sync_level = 30
$synced = []
vitals = [{ "hp" => 50, "mp" => 5 }, { "hp" => 60, "mp" => 6 }]
$battlers.plans["ally"] = lambda { |_request| vitals.shift }
check("the host gathers who joins", MGQ_MpBattlesCoop.gather(scene), nil)
$battlers.plans.delete("ally")
roster = $sent.map(&:last).find { |f| f["battle"] == "roster" }
enemies, players, level = wire_values(roster[:payload])
check("and sends the party and the troop to everyone", [enemies, players.map { |p| p[0, 3] }], [[[31, 0, 0, 0], [32, 0, 0, 0]], [[0, "Me", "1,2,3"], [2, "Friend", "7,8,9"]]])
check("with each player's order and shares, the Backline's as far as their characters go", players.map { |p| p[4, 4] }, [[8, [0, 1, 2], 2, 1], [8, [0, 1, 2], 2, 1]])
party = $game_party.battle_members
check("and the battle's level, which the host's level sync starts with", [level, $sync_began], [30, 30])
check("every character of the party is offered to the level sync", $synced.map(&:name), party.map(&:name))
check("two players bring two each, the host's own first", party.map(&:name), ["Actor1", "Actor2", "Actor7 (Friend)", "Actor8 (Friend)"])
check("the others' characters are planned with the HP and MP their player sent, and take what the DLL plans",
      [$battlers.asked("battlers.plan").select { |request| request["kind"] == "ally" }.last(2).map { |request| request["vitals"] }, party[2, 2].map { |a| [a.hp, a.mp, a.mp_seat] }],
      [[[50, 5], [60, 6]], [[50, 5, 2], [60, 6, 2]]])
check("the status windows show the party", $refreshed, true)

# The status window names each character in its player's color.
# A character's max HP.
class Game_Actor; def mhp; 100; end; end
# A status window that records what it draws.
class Window_BattleStatus
  attr_reader :drawn, :color
  def change_color(color); @color = color; end
  def line_height; 24; end
  def text_size(text); Rect.new(0, 0, text.to_s.size * 8, 24); end
  def draw_text(x, y, width, height, text, align = 0); (@drawn ||= []) << [x, y, width, height, text, @color]; end
end
status = Window_BattleStatus.new
own_drawn = status.draw_actor_name(party[0], 4, 0, 100)
ally_drawn = status.draw_actor_name(party[2], 4, 24, 100)
values = lambda { |color| [color.red, color.green, color.blue] }
check("the status window names the player's own character in their color and another player's by its own name in its owner's",
      [own_drawn, ally_drawn, status.drawn.map { |x, y, width, height, text, color| [x, y, width, height, text, values.call(color) == values.call(Mod_Framework::UI.color_now(:own)), values.call(color) == values.call(MGQ_MpPlayerColor.of(friend))] }],
      [nil, nil, [[4, 0, 100, 24, "Actor1", true, false], [4, 24, 100, 24, "Actor7", false, true]]])
party[2].hp = 24
check("a character in crisis is left to the game's colors, as is one drawn without a width", [status.draw_actor_name(party[2], 4, 24, 100), status.draw_actor_name(party[0], 4, 0), status.drawn.size], [:original, :original, 2])
party[2].hp = 50
# A status window whose color fails.
class Window_MpFailingStatus < Window_BattleStatus; def change_color(_color); raise "no color"; end; end
failing = Window_MpFailingStatus.new
check("a name the mod cannot draw is left to the game, logged once",
      [failing.draw_actor_name(party[2], 4, 24, 100), failing.draw_actor_name(party[2], 4, 24, 100), $log.grep(/drawing a status name failed, the game draws it: RuntimeError: no color/).size], [:original, :original, 1])
check("its name for the battle's messages stays whole", party[2].name, "Actor7 (Friend)")
check("the others' characters start the battle, which the game does only for its own", party[2, 2].map(&:turn_hit_damage_count), [0, 0])
party[2].turn_hit_damage_count = 3
party[2].on_turn_start
check("and each turn", party[2].turn_hit_damage_count, 0)
check("the battle keeps only the invited players who joined", MGQ_MpBattlesSync.seats, [2])

# Another mod adds an enemy mid-battle: the host tells the guest the troop once, before its stream.
recorder = MGQ_MpBattlesSync::Recorder
recorder.start
$sent.clear
$live.set("live.record flush", "sends" => ["a send"])
recorder.event("turn", 2)
recorder.flush
check("an unchanged troop is never told again", $sent.map { |_, message| message["battle"] }, ["events"])
$game_troop.members.push(Game_Enemy.new(2, 33))
$sent.clear
recorder.event("turn", 2)
recorder.flush
sent_troop = $sent.dup
check("a troop that grew is told to the guest before the send", sent_troop.map { |seat, f| [seat, f["battle"]] }, [[2, "coop_troop"], [2, "events"]])
check("with every enemy", wire_values(sent_troop[0][1][:payload])[0].map(&:first), [31, 32, 33])
$sent.clear
MGQ_MpBattlesCoop::Mode.settle(scene)
check("and not again as the command phase opens", $sent.map { |_, message| message["battle"] }, [])
$game_troop.members.push(Game_Enemy.new(3, 34))
troop_entries = MGQ_MpBattlesHotjoin.method(:late_entries)
MGQ_MpBattlesHotjoin.define_singleton_method(:late_entries) { raise "an enemy this game cannot read" }
recorder.event("turn", 2)
recorder.flush
MGQ_MpBattlesHotjoin.define_singleton_method(:late_entries, troop_entries)
$sent.clear
recorder.event("turn", 2)
recorder.flush
check("a troop whose telling failed is told before the next send", $sent.map { |_, message| message["battle"] }, ["coop_troop", "events"])
$game_troop.members.pop(2)
recorder.stop
$live.set("live.record flush", nil)

# Commands: the DLL plans which of a guest's commands the host can read for each place of the
# party, and the host gives them as far as the character may.
party[2].make_actions
check("the host's computer chooses nothing for a guest's character while it waits for the guest", party[2].actions.map(&:item), [nil])
# Gives a guest's commands as the DLL plans them.
#
# @param places [Array<Array, nil>] What the DLL plans for each place, nil to leave a place as it is.
apply = lambda do |*places|
  $live.set("live.plan", "places" => places)
  MGQ_MpBattlesSync::Commands.apply(wire_line([places.map { |entries| entries && entries.map { |entry| entry && entry.first(3) } }]), 2)
  $live.set("live.plan", nil)
end
apply.call(nil, nil, [["skill", 12, 0, nil]], [["item", 3, 1, nil]])
plan = $live.asked("live.plan").last
check("a guest's commands go to the DLL with the owners of the party's places and the database's sizes",
      [plan["seat"], plan["owners"], plan["skills"], plan["items"]], [2, [nil, nil, 2, 2], $data_skills.size, $data_items.size])
check("and to the characters it plans them for", [party[2].actions.map(&:item), party[3].actions.map(&:item)], [[[:skill, 12]], [[:item, 3]]])
apply.call(nil, nil, nil, nil)
check("a character the DLL plans no commands for keeps its own", [party[2].actions.map(&:item), party[3].actions.map(&:item)], [[[:skill, 12]], [[:item, 3]]])
apply.call(nil, nil, [["skill", KNOWN_SKILLS, 0, nil]], [["item", FIELD_ITEMS, 0, nil]])
check("a skill the character lacks and an item no battle allows are left out", [party[2].actions.map(&:item), party[3].actions.map(&:item)], [[[:skill, 12]], [[:item, 3]]])
apply.call(nil, nil, [["skill", 199, 0, nil]], nil)
check("a skill of no skill type is taken", party[2].actions.map(&:item), [[:skill, 199]])
apply.call(nil, nil, [["skill", 5, 0, nil], ["skill", 6, 0, nil]], nil)
check("a guest's commands go no further than the actions the host gave the character", party[2].actions.map(&:item), [[:skill, 5]])
apply.call(nil, nil, [], nil)
check("and an empty list, as after a failed escape, takes its actions away", [party[2].actions, party[3].actions.map(&:item)], [[], [[:item, 3]]])
apply.call(nil, nil, [["skill", 5, 0, nil]], nil)
$log.clear
apply.call(nil, nil, [nil], [nil])
check("commands the DLL cannot read keep the actions there, logged",
      [party[2].actions.map(&:item), party[3].actions.map(&:item), $log.grep(/gave the commands of .*none it may give, the computer's actions kept/).size], [[[:skill, 5]], [[:item, 3]], 1])

# Skills chained after a guest's action.
#
# @param action [Game_Action] The action.
# @return [Array<Array>] The item, target and kind of each chained skill.
def chain_of(action)
  links = []
  links << [(action = action.chain_action).item, action.target_index, action.symbol] while action.chain_action
  links
end
# Plans a skill on a target with skills chained after it, each chained skill a skill on a target.
#
# @param links [Array<Array>] The chained skills' ids and targets.
# @return [Array] The command as the DLL plans it.
chained = lambda { |*links| ["skill", 5, 0, links.map { |id, target| ["skill", id, target, nil] }] }
apply.call(nil, nil, [chained.call([6, 0], [7, 1])], nil)
check("a guest's chained skills follow their action", chain_of(party[2].actions[0]), [[[:skill, 6], 0, :chain_action], [[:skill, 7], 1, :chain_action]])
apply.call(nil, nil, [chained.call([6, 0], [KNOWN_SKILLS, 0], [7, 0])], nil)
check("up to the first the character may not give", chain_of(party[2].actions[0]).map(&:first), [[:skill, 6]])
$unchained = [7]
apply.call(nil, nil, [chained.call([6, 0], [7, 0], [8, 0])], nil)
$unchained = nil
check("and the game's check cuts what the character's skill types do not chain", chain_of(party[2].actions[0]).map(&:first), [[:skill, 6]])
apply.call(nil, nil, [["skill", 5, 0, nil]], nil)
check("an action sent without a chain has none", party[2].actions[0].chain_action, nil)
wire_read = MGQ_MpBattlesSync::Wire.method(:read)
MGQ_MpBattlesSync::Wire.define_singleton_method(:read) { |*| raise "broken" }
$log.clear
MGQ_MpBattlesSync::Commands.apply("anything", 2)
MGQ_MpBattlesSync::Wire.define_singleton_method(:read, wire_read)
check("commands that fail to apply keep the actions there, logged once",
      [party[2].actions.map(&:item), party[3].actions.map(&:item), $log.grep(/could not give the commands of .*: RuntimeError: broken; the computer's kept/).size], [[[:skill, 5]], [[:item, 3]], 1])
check("the host's own characters are commanded here", [party[0].is_a?(Game_MpAlly), party[2].inputable?], [false, false])

# Playback and escape.
check("a co-op stream's sides stay as they are", [MGQ_MpBattlesSync::Playback.battler("a2"), MGQ_MpBattlesSync::Playback.battler("e1")], [party[2], $game_troop.members[1]])
check("the host escapes as in any battle", MGQ_MpBattlesSync::Live.escape_leaves?, false)

# The end.
$cancelled = false
$game_player.leader_shown = party[2]
$sync_finished = false
MGQ_MpBattlesCoop.ended
check("the end gives the party back and ends the rules", [MGQ_MpBattlesCoop.active?, MGQ_MpBattlesSync.role, MGQ_MpBattles.running?, $game_party.battle_members], [false, nil, false, mine])
check("and ends the level sync", $sync_finished, true)
check("and the map shows the player's own leader again", $game_player.leader_shown, mine[0])
check("and leaves the world's room open", $cancelled, false)

# A guest: the DLL's matchmaking keeps the invite and has the player join it once free on the map.
$my_seat = 2
$sent.clear
$setup.clear
host = MGQ_MpOverworldSync::Peers::Peer.new(0, { "id" => "id-host", "name" => "Host", "map" => "5", "scene" => "map" }, nil, true)
MGQ_MpOverworldSync::Peers.all.push(host)
message = { "coop" => "invite", "party" => "p1", "bid" => "b9", "troop" => "40", "escape" => true, "lose" => false, "seats" => [2, 3], "map" => "5" }
$scene_now = Scene_Map.new
$game_map.interpreter.busy = true
MGQ_MpBattlesCoop.on_map
check("every frame on the map tells the DLL what keeps the player busy, such as an event", [$coop.asked("coop.poll").last["facts"]["interpreter"], $setup], [true, []])
$game_map.interpreter.busy = false
$coop.set("coop.poll", "actions" => [coop_step("accept", "seat" => 0, "fields" => message)])
MGQ_MpBattlesCoop.on_map
$coop.set("coop.poll", nil)
check("the invite the DLL accepts starts that battle as guest", [$setup, $called, MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.player, MGQ_MpBattlesSync.seats, MGQ_MpBattles.kind, $cleared],
      [[[40, true, false]], Scene_Battle, :guest, "Host", [0], :coop, true])
check("its own setup goes to the DLL as one the player joins, which invites nobody", $coop.asked("coop.offer").last["joining"], true)
$scene_now = scene

$sent.clear
$frames = 0
roster_body = wire_line([[[31, 0, 0, 0], [32, 0, 0, 0]], [[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3", [[100, 10]] * 3, 8, [0, 1, 2], 2, 1]], 25])
$coop.roster(roster_body)
own_enemies = $game_troop.members.dup
check("the guest joins with the roster the DLL took", MGQ_MpBattlesCoop.join(scene), nil)
$coop.roster(nil)
check("having waited for it as long as a guest waits", $coop.asked("coop.roster_wait").select { |request| request["op"] == "start" }.last["limit"], MGQ_MpBattlesCoop.roster_frames)
check("a guest whose troop is the host's keeps its own enemies", $game_troop.members.zip(own_enemies).all? { |now, before| now.equal?(before) }, true)
sent_join = $sent.map(&:last).find { |f| f["battle"] == "join" }
check("with the squad two players bring, and its places", wire_values(sent_join[:payload]), ["1,2,3", [[100, 10], [100, 10], [100, 10]], 8])
guest_party = $game_party.battle_members
check("and fights in the host's order, its own characters as they are", guest_party.map(&:name), ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor2"])
check("its party, as it runs away or is defeated, is named after its own characters", $game_party.name, "Actor1's party")
check("at the level the host sent", $sync_began, 25)
check("the guest's commands are only for its own, none named for the others'", wire_values(MGQ_MpBattlesSync::Commands.build)[0].map { |list| list && list.size }, [nil, nil, 0, 0])
guest_party[2].actions = [Game_Action.new(guest_party[2]).tap { |a| a.set_skill(5); a.target_index = 0; a.item = RPG::Skill.new; def (a.item).id; 5; end }]
check("which it sends by the party's places", wire_values(MGQ_MpBattlesSync::Commands.build)[0][2], [["skill", 5, 0]])
check("with the order of its own places", wire_values(MGQ_MpBattlesSync::Commands.build)[1], [0, 1, 2])
chained = Game_Action.new(guest_party[2]).tap { |a| a.item = $data_skills[6]; a.target_index = 1 }
guest_party[2].actions[0].chain_action = chained
chained.chain_action = Game_Action.new(guest_party[2])
check("and the skills it chained after an action, up to the first link without a skill",
      wire_values(MGQ_MpBattlesSync::Commands.build)[0][2], [["skill", 5, 0, [["skill", 6, 1]]]])
check("its Backline is its own share", $game_party.bench_members.map(&:name), ["Actor3"])
check("a guest tries to escape as in any battle", MGQ_MpBattlesSync::Live.escape_leaves?, false)
MGQ_MpBattlesCoop.ended

# A guest whose troop differs from the host's, through a mod of either game, fights the host's.
own_enemies = $game_troop.members.dup
troop_scene = Scene_Battle.new
troop_scene.instance_variable_set(:@spriteset, Spriteset_Battle.new)
hosts = [[31, 100, 300, 0], [31, 200, 300, 0], [32, 300, 300, 0], [32, 400, 300, 1]]
MGQ_MpBattlesCoop.take_troop(troop_scene, hosts)
rebuilt = $game_troop.members
check("a guest whose troop differs fights the host's enemies, in the host's places, each planned by its mark",
      [rebuilt.map { |e| [e.index, e.enemy_id, e.screen_x, e.screen_y, e.hidden?] }, $battlers.asked("battlers.plan").last(4).map { |request| request["mark"] }],
      [[[0, 31, 100, 300, false], [1, 31, 200, 300, false], [2, 32, 300, 300, false], [3, 32, 400, 300, true]], [0, 0, 0, 1]])
check("named apart as the game names a troop's enemies", rebuilt.map(&:name), ["Enemy31 A", "Enemy31 B", "Enemy32 A", "Enemy32"])
check("and drawn anew", troop_scene.instance_variable_get(:@spriteset).enemies, rebuilt.reverse)
$game_troop.members = own_enemies
$coop.set("coop.repair", "enemies" => nil, "enemy_dropped" => [], "lacking" => [500])
$log.clear
MGQ_MpBattlesCoop.take_troop(troop_scene, [[31, 0, 0, 0], [500, 0, 0, 0]])
check("a host's troop the DLL finds enemies this game lacks in keeps the guest's own troop, naming them in the log",
      [$game_troop.members.equal?(own_enemies), $log.grep(/lacks/)], [true, ["co-op battle: the host's troop holds enemies this game lacks (500); it keeps its own"]])
$log.clear
own_places = [Game_Enemy.new(0, 31), Game_Enemy.new(1, 32).tap { |enemy| enemy.screen_x, enemy.screen_y = 250, 310 }]
$game_troop.members = own_places
odd_enemies = [[31, 100, 300, 0], [31, [200], nil, 0], [32, 300, "300"], [32, 400, 300, 1]]
$coop.set("coop.repair", "enemies" => [[31, 100, 300, 0], [31, 250, 310, 0], [32, 300, 0, 0], [32, 400, 300, 1]], "lacking" => [],
          "enemy_dropped" => [["x", "Array", "the host's enemy"], ["y", "NilClass", "the host's enemy"], ["y", "String", "the host's enemy"], ["mark", "NilClass", "the host's enemy"]])
2.times { MGQ_MpBattlesCoop.take_troop(troop_scene, odd_enemies) }
repair = $coop.asked("coop.repair").last
check("a host's enemies go to the DLL's repair as plain values, a field that is no number by its kind, with this game's places and the size of its table of enemies",
      [repair["enemies"], repair["own"][1], repair["count"]],
      [[[31, 100, 300, 0], [31, "Array", "NilClass", 0], [32, 300, "String", "NilClass"], [32, 400, 300, 1]], [250, 310], $data_enemies.size])
check("the guest fights the enemies the DLL repaired, each at its place", $game_troop.members.map { |e| [e.index, e.enemy_id, e.screen_x, e.screen_y, e.hidden?] },
      [[0, 31, 100, 300, false], [1, 31, 250, 310, false], [2, 32, 300, 0, false], [3, 32, 400, 300, true]])
check("logging each field the DLL dropped once per field and kind", $log.grep(/dropped the host's enemy/),
      ["co-op battle: dropped the host's enemy x another game sent as Array", "co-op battle: dropped the host's enemy y another game sent as NilClass",
       "co-op battle: dropped the host's enemy y another game sent as String",
       "co-op battle: dropped the host's enemy mark another game sent as NilClass"])
check("instead of failing", $log.grep(/taking the host's troop failed/), [])
$log.clear
$game_troop.members = own_places
$coop.set("coop.repair", "enemies" => nil, "lacking" => [], "enemy_dropped" => [["id", "String", "the host's troop for its enemy"]])
2.times { MGQ_MpBattlesCoop.take_troop(troop_scene, [[31, 0, 0, 0], ["32", 0, 0, 0]]) }
check("a troop the DLL cannot repair keeps the guest's own, logged once",
      [$game_troop.members.equal?(own_places), $log.grep(/dropped the host's troop/)], [true, ["co-op battle: dropped the host's troop for its enemy id another game sent as String"]])
$coop.set("coop.repair", nil)

# A Challenge Battle's enemies take damage without falling; the battle server, without pictures,
# places them elsewhere than the player who started the battle (issue #47).
class ChallengeEnemy < Game_Enemy; end
def $game_troop.enemy_class; ChallengeEnemy; end
challenge = [ChallengeEnemy.new(0, 31)]
$game_troop.members = challenge
MGQ_MpBattlesCoop.take_troop(troop_scene, [[31, 320, 480, 0]])
check("a troop that holds the host's enemies at other places keeps them, at the host's places",
      [$game_troop.members[0].equal?(challenge[0]), challenge[0].screen_x, challenge[0].screen_y], [true, 320, 480])
MGQ_MpBattlesCoop.take_troop(troop_scene, [[31, 320, 480, 1]])
check("one the host hides is rebuilt", [$game_troop.members[0].equal?(challenge[0]), $game_troop.members[0].hidden?], [false, true])
$battle_starts = []
MGQ_MpBattlers.start_guest
MGQ_MpBattlesCoop.take_troop(troop_scene, [[31, 320, 480, 0], [32, 100, 300, 0]])
check("a troop rebuilt after the guest's start makes its enemies of the kind its battle needs, each started once as the game starts its own",
      [$game_troop.members.map(&:class), $game_troop.members.map { |enemy| $battle_starts.count(enemy) }], [[ChallengeEnemy, ChallengeEnemy], [1, 1]])
$game_party.in_battle = false
class << $game_troop; remove_method :enemy_class; end
$game_troop.members = own_enemies

# A battle the DLL leaves to the player alone.
$my_seat = 0
$coop.set("coop.offer", "actions" => [coop_step("fight_alone")])
BattleManager.setup(41)
$coop.set("coop.offer", nil)
check("a battle the DLL leaves to the player stays their own, which a member who missed it joins late (issue 76)",
      [MGQ_MpBattlesSync.role, MGQ_MpBattlesHotjoin.state_fields["rb"].to_s.empty?], [nil, false])
MGQ_MpBattlesCoop.ended

# Shares.
check("of three players the leader brings two and two of the Backline, the others one each", [0, 1, 2].map { |at| MGQ_MpCoopSquad.share(at, 3, 8) }, [[2, 2], [1, 1], [1, 1]])

# Players who get away: three players, then two, then one.
$my_seat = 0
MGQ_MpOverworldSync::Peers.all.clear
g1 = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "id-friend", "name" => "Friend", "map" => "5", "scene" => "map" }, nil, true)
g2 = MGQ_MpOverworldSync::Peers::Peer.new(3, { "id" => "id-other", "name" => "Other", "map" => "5", "scene" => "map" }, nil, true)
MGQ_MpOverworldSync::Peers.all.push(g1, g2)
$game_map.map_id = 5
$game_party.own = mine
$coop.hosts("b3", [2, 3])
BattleManager.setup(50)
$coop.hosts(nil)
bid3 = MGQ_MpBattlesSync.battle_id
$coop.gathered([2, wire_line(["7,8,9", [[50, 5], [60, 6], [65, 6]], 8])], [3, wire_line(["10,11", [[70, 7], [80, 8]], 8])])
$frames = 0
$sent.clear
MGQ_MpBattlesCoop.gather(scene)
three = $game_party.battle_members
check("of three players the leader brings two, the others one each", three.map(&:name), ["Actor1", "Actor2", "Actor7 (Friend)", "Actor10 (Other)"])
roster3 = $sent.map(&:last).find { |f| f["battle"] == "roster" }
check("the roster carries everyone's squad for two players", wire_values(roster3[:payload])[1].map { |p| p[2] }, ["1,2,3", "7,8,9", "10,11"])
three[2].hp = 12

$notices = []
MGQ_MpOverworldSync::Peers.all.concat([g1, g2])
outsider = MGQ_MpOverworldSync::Peers::Peer.new(9, { "name" => "Stranger" }, nil, false)
MGQ_MpBattlesSync.take(outsider, { "battle" => "leave", "bid" => bid3, :payload => "" })
check("a leave with the battle's id from a player outside it tells nothing", [$notices, $game_party.battle_members.size], [[], 4])
MGQ_MpBattlesSync.take(g2, { "battle" => "leave", "bid" => bid3, :payload => "" })
check("a player who leaves is told of at once, before the next command phase", [$notices, $game_party.battle_members.size], [["Other left the battle."], 4])
departures = $live.asked("live.departure").size
$live.set("live.departure", false)
MGQ_MpBattlesSync.take(g2, { "battle" => "leave", "bid" => bid3, :payload => "" })
MGQ_MpBattlesSync::Departures.gone(g2)
check("and not again where the DLL says it was told", [$notices, $live.asked("live.departure").drop(departures).map { |request| request["seat"] }], [["Other left the battle."], [3, 3]])
$live.set("live.departure", nil)
MGQ_MpBattlesSync::Departures.gone(MGQ_MpOverworldSync::Peers::Peer.new(9, { "name" => "Stranger" }, nil, false))
check("a player outside the battle who leaves the world is not", $notices.size, 1)
# The player who stays is still in the world, whom the new party goes to.
MGQ_MpOverworldSync::Peers.all.replace([g1])

MGQ_MpBattlesSync.guest_left(3)
$sent.clear
$coop.set("coop.settle", "staying" => [0, 2], "left" => [3], "outcome" => "reform")
MGQ_MpBattlesCoop.settle(scene)
$coop.set("coop.settle", nil)
check("the DLL settles the party from the battle's players, the player's seat and the guests still in",
      $coop.asked("coop.settle").last, { "players" => [0, 2, 3], "own" => 0, "in" => [2], "served" => false })
two = $game_party.battle_members
check("when one gets away, the others bring two each", two.map(&:name), ["Actor1", "Actor2", "Actor7 (Friend)", "Actor8 (Friend)"])
check("characters who stay keep what the battle did to them", [two[2].equal?(three[2]), two[2].hp], [true, 12])
change = $sent.map(&:last).find { |f| f["battle"] == "coop_party" }
check("the guests hear of the new party", wire_values(change[:payload])[0].map { |p| p[0] }, [0, 2])
$sent.clear
MGQ_MpBattlesCoop.settle(scene)
check("nothing more while the DLL finds nobody else gone", $sent.size, 0)

MGQ_MpBattlesSync.guest_left(2)
$coop.set("coop.settle", "staying" => [0], "left" => [2], "outcome" => "solo")
MGQ_MpBattlesCoop.settle(scene)
$coop.set("coop.settle", nil)
check("alone, the host fights on with their own full team", [MGQ_MpBattlesCoop.active?, $game_party.battle_members], [false, mine])
check("as a battle of their own", [MGQ_MpBattlesSync.role, MGQ_MpBattles.running?, BattleManager.can_giveup?], [nil, false, true])

# A guest takes the new party in order, and takes over when the host gets away.
$my_seat = 2
MGQ_MpBattlesSync.join_world(:guest, "g7", [0], "Host")
MGQ_MpBattlesSync.battle_started
MGQ_MpBattles.begin(:coop)
MGQ_MpBattlesCoop.form(scene, [[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3", [[100, 10]] * 3, 8, [0, 1, 2], 1, 1], [3, "Other", "10,11", [], 8, [0, 1], 1, 1]])
check("the guest's party of three", $game_party.battle_members.map(&:name), ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor10 (Other)"])
MGQ_MpBattlesSync::Channel.receive(0, "coop_party", wire_line([[[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3", [], 8, [0, 1, 2], 2, 1]]]))
MGQ_MpBattlesSync::Channel.receive(0, "events", "")
MGQ_MpBattlesSync::Playback.reset
MGQ_MpBattlesSync::Playback.next_event(scene)
check("a new party is taken before the next send", $game_party.battle_members.map(&:name), ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor2"])
newcomer = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "id-new", "name" => "Newcomer", "map" => "5", "scene" => "battle" }, nil, false)
MGQ_MpOverworldSync::Peers.all.push(newcomer)
$chat = []
$notices = []
popups_on(scene)
MGQ_MpBattlesSync::Channel.receive(0, "coop_party", wire_line([[[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3", [], 8, [0, 1, 2], 2, 1], [4, "Newcomer", "12", [[70, 7]], 8, [0], 1, 0]]]))
MGQ_MpBattlesSync::Channel.receive(0, "events", "")
MGQ_MpBattlesSync::Playback.next_event(scene)
check("a guest reads in the battle's popup, not the chat, who joined the host's party", [$chat, $popups, $notices, $game_party.battle_members.map(&:name)],
      [[], ["Newcomer joined the battle."], ["Newcomer joined the battle."], ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor2", "Actor12 (Newcomer)"]])
MGQ_MpBattlesSync::Channel.receive(0, "coop_party", wire_line([[[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3", [], 8, [0, 1, 2], 2, 1]]]))
MGQ_MpBattlesSync::Channel.receive(0, "events", "")
MGQ_MpBattlesSync::Playback.next_event(scene)
check("and nothing when a player leaves it, which the departure tells", [$popups.size, $game_party.battle_members.size], [1, 4])
MGQ_MpOverworldSync::Peers.all.delete(newcomer)
$game_party.battle_members[0].actions = [:hosts]
$game_party.battle_members[2].actions = [:chosen]
$chat = []
$commands_phase = false
$actor_cleared = false
$troop_actions = 0
$turn_ends = 0
choices = ["choose_again", [3]], ["choose_again", [2]]
MGQ_MpBattlesSync::Channel.receive(0, "events", choices.map { |event| wire_line(event) }.join("\n"))
MGQ_MpBattlesSync::Live.play_until_commands(scene)
check("a guest the host names chooses again within the same command phase", [$commands_phase, $actor_cleared, $turn_ends, $troop_actions], [true, true, 0, 0])
check("only its own characters' commands start anew", [$game_party.battle_members[2].actions.map(&:item), $game_party.battle_members[0].actions], [[nil], [:hosts]])
check("told why, once: the host's word for another player passes by", $chat, ["A character you chose a command for left the Frontline. Choose your commands again."])

scene.changing = true
$sent.clear
MGQ_MpBattlesSync::Live.escaped(scene)
check("a guest who got away tells the host", $sent.map { |_, message| message["battle"] }, ["leave"])
scene.changing = false
$sent.clear
MGQ_MpBattlesSync::Live.escaped(scene)
check("one whose escape failed stays", $sent.size, 0)
check("in co-op every player tries to escape as in any battle", MGQ_MpBattlesSync::Live.escape_leaves?, false)

# Leaving a story's battle without escape loses it for the player alone, since its event has no
# branch for an escape; any other battle is left as an escape.
# The defeat scene the battle picked and its enemy.
class Game_Temp; attr_accessor :lose_event_id, :lose_event_enemy_id; end
# An enemy whose defeat scene is 6000 plus its id.
class Game_Enemy; def lose_event_id; 6000 + @enemy_id; end; def id; @enemy_id; end; end
known_events = $data_common_events
$data_common_events = []
$data_common_events[6031] = $data_common_events[6032] = $data_common_events[6099] = :scene
$game_temp.lose_event_id = 6031
# Notes the defeat in $defeated.
def BattleManager.process_defeat; $defeated = true; end
scene.instance_variable_set(:@info_viewport, Struct.new(:visible).new(true))
leave = lambda do |event_proc, can_escape|
  MGQ_MpGame.set(BattleManager, :event_proc, event_proc)
  MGQ_MpGame.set(BattleManager, :can_escape, can_escape)
  $sent.clear
  $aborted = $defeated = false
  offer = MGQ_MpBattlesSync::Live.leaving_loses?
  MGQ_MpBattlesSync::Live.forfeit(scene)
  [offer, $aborted, $defeated, $sent.map { |_, message| message["battle"] }]
end
check("leaving a story's battle without escape loses it here, the others told the player left",
      leave.call(proc {}, false), [true, false, true, ["leave"]])
check("leaving one the party may escape, or a battle no event started, is an escape",
      [leave.call(proc {}, true), leave.call(nil, false)], [[false, true, false, ["leave"]], [false, true, false, ["leave"]]])
picked = [nil, 9999, 6099].map do |stale|
  $game_temp.lose_event_id = stale
  $game_temp.lose_event_enemy_id = nil
  left = leave.call(proc {}, false)
  [left[2], [6031, 6032].include?($game_temp.lose_event_id), $game_temp.lose_event_enemy_id == $game_temp.lose_event_id - 6000]
end
check("a guest leaving it takes a defeat scene of this battle's enemies, whether it had none or a former battle's",
      picked, [[true, true, true]] * 3)
$data_common_events[6031] = $data_common_events[6032] = nil
$game_temp.lose_event_id = nil
$log.clear
check("and leaves it as an escape when none of them has a scene this game knows", [leave.call(proc {}, false)[1, 2], $log.grep(/leaves it as an escape/).size], [[true, false], 1])
$data_common_events[6031] = $data_common_events[6032] = :scene
role = MGQ_MpBattlesSync.instance_variable_get(:@role)
MGQ_MpBattlesSync.instance_variable_set(:@role, :host)
$game_temp.lose_event_id = 6031
$game_temp.lose_event_enemy_id = 31
check("a host leaving it keeps the defeat scene its battle picked", [leave.call(proc {}, false)[2], $game_temp.lose_event_id, $game_temp.lose_event_enemy_id], [true, 6031, 31])
MGQ_MpBattlesSync.instance_variable_set(:@role, role)
MGQ_MpGame.set(BattleManager, :event_proc, nil)

$turn_ends = 0
$commands_phase = false
$aborted = false
$live.set("live.end guest", "first" => "the host's battle ended", "process" => "take_over", "otherwise" => { "process" => "process_abort" })
MGQ_MpBattlesSync::Live.guest_end("process_abort", scene)
$live.set("live.end guest", nil)
check("when the host gets away, the guest asks the DLL and, as it says, takes the battle over and fights on alone",
      [$live.asked("live.end").last, MGQ_MpBattlesCoop.active?, $game_party.battle_members, MGQ_MpBattlesSync.role, MGQ_MpBattles.running?],
      [{ "of" => "guest", "result" => "process_abort", "side" => true }, false, mine, nil, false])
check("from a new command phase", [$turn_ends, $commands_phase, $aborted], [1, true, false])

# The defeat scene of a lost battle, which the guest's own battle never picks.
$data_common_events[6031] = $data_common_events[6032] = nil
$data_common_events[6040] = :scene
$game_temp.lose_event_id = nil
MGQ_MpBattlesSync::Live.take_defeat_scene(["end", "process_defeat", 6040, 40])
check("the guest of a lost battle takes the host's defeat scene", [$game_temp.lose_event_id, $game_temp.lose_event_enemy_id], [6040, 40])
$data_common_events[6031] = $data_common_events[6032] = :scene
MGQ_MpBattlesSync::Live.take_defeat_scene(["end", "process_defeat", 9999, 40])
check("or one of its own enemies when this game lacks the host's", [6031, 6032].include?($game_temp.lose_event_id) && $game_temp.lose_event_enemy_id == $game_temp.lose_event_id - 6000, true)
$game_temp.lose_event_id = nil
MGQ_MpBattlesSync::Live.take_defeat_scene(["end", "process_defeat"])
check("as when the host names none", [6031, 6032].include?($game_temp.lose_event_id), true)
MGQ_MpBattlesSync::Live.take_defeat_scene(["end", "process_defeat", 2**70, 40])
check("or a scene id too large for the game", [6031, 6032].include?($game_temp.lose_event_id) && $game_temp.lose_event_enemy_id == $game_temp.lose_event_id - 6000, true)
MGQ_MpBattlesSync::Live.take_defeat_scene(["end", "process_defeat", 6040, [40]])
check("a defeat scene whose enemy is no id keeps the scene and takes an enemy here", [$game_temp.lose_event_id, [31, 32].include?($game_temp.lose_event_enemy_id)], [6040, true])
$data_common_events = known_events

# Swaps with the Backline: the host with five characters, a friend with four.
$my_seat = 0
MGQ_MpOverworldSync::Peers.all.clear
mate = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "id-friend", "name" => "Friend", "map" => "5", "scene" => "map" }, nil, true)
MGQ_MpOverworldSync::Peers.all.push(mate)
five = (1..5).map { |id| Game_Actor.new(id) }
$game_party.own = five.dup
$coop.hosts("b4", [2])
BattleManager.setup(60)
$coop.hosts(nil)
$coop.gathered([2, wire_line(["7,8,9,10", [[50, 5]] * 4, 8])])
$frames = 0
MGQ_MpBattlesCoop.gather(scene)
check("each of two players brings their squad of four, two of them in front", [$game_party.battle_members.map(&:name), $game_party.bench_members.map(&:name)],
      [["Actor1", "Actor2", "Actor7 (Friend)", "Actor8 (Friend)"], ["Actor3", "Actor4"]])
$shift = true
status = Window_BattleStatus.new
status.index = 2
check("a shift change picks none of the others' characters", status.current_item_enabled?, false)
status.index = 1
check("but the player's own", status.current_item_enabled?, true)
$shift = false
check("outside a shift change the window is the game's", status.current_item_enabled?, :original)
friend_front = $game_party.battle_members[2]
check("another player's character never swaps", MGQ_MpBattlesCoop.swap(scene, friend_front, 0), false)
scene.instance_variable_set(:@status_window, Struct.new(:index).new(1))
scene.instance_variable_set(:@bench_window, Struct.new(:index).new(1))
$bench_cancelled = false
scene.bench_member_ok
check("the shift change swaps the player's own in", [$game_party.battle_members.map(&:name), $game_party.bench_members.map(&:name), $bench_cancelled],
      [["Actor1", "Actor4", "Actor7 (Friend)", "Actor8 (Friend)"], ["Actor3", "Actor2"], true])
check("in their own party too, as in a battle of their own", $game_party.own.map(&:id), [1, 4, 3, 2, 5])
front = $game_party.battle_members
front.each { |member| member.define_singleton_method(:inputable?) { false } }
check("a party whose characters cannot act still takes commands while the player's Backline may swap in", [MGQ_MpBattlesCoop.may_swap_in?, $game_party.inputable?], [true, true])
$game_switches[NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE] = true
check("but not while the game forbids the change", $game_party.inputable?, false)
$game_switches[NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE] = false
$game_party.bench_members.each { |member| member.hp = 0 }
check("nor once nobody of the Backline stands", [MGQ_MpBattlesCoop.may_swap_in?, $game_party.inputable?], [false, false])
$game_party.bench_members.each { |member| member.hp = 100 }
front.each { |member| member.singleton_class.send(:remove_method, :inputable?) }
$sent.clear
MGQ_MpBattlesCoop.share_order
told = $sent.map(&:last).find { |f| f["battle"] == "coop_party" }
check("the host tells the guests the new order before the turn", wire_values(told[:payload])[0].map { |p| p[5] }, [[0, 3, 2, 1], [0, 1, 2, 3]])
$sent.clear
MGQ_MpBattlesCoop.share_order
check("only once", $sent.size, 0)
$live.set("live.plan", "places" => [nil, nil, nil, [["skill", 12, 0, nil]]])
MGQ_MpBattlesSync::Commands.apply(wire_line([[[], [], [], [["skill", 12, 0]]], [3, 1, 2, 0]]), 2)
$live.set("live.plan", nil)
swapped = $game_party.battle_members
check("a guest's commands bring their swap first", swapped.map(&:name), ["Actor1", "Actor4", "Actor10 (Friend)", "Actor8 (Friend)"])
check("so their commands reach the character they see", swapped[3].actions.map(&:item), [[:skill, 12]])
check("the character swapped out leaves the party", $game_party.battle_members.include?(friend_front), false)
MGQ_MpBattlesSync::Commands.apply(wire_line([[[], [], [], []], [0, 1, 2, 3]]), 2)
check("and comes back as the battle left it", $game_party.battle_members[2].equal?(friend_front), true)
MGQ_MpBattlesSync::Commands.apply(wire_line([[[], [], [], []], [0, 0, 1, 2]]), 2)
check("a broken order puts the guest's characters back in theirs", MGQ_MpBattlesCoop.instance_variable_get(:@players).find { |p| p[0] == 2 }[5], [0, 1, 2, 3])

# Commands for one character of the party, which another player's swap takes away.
# A skill's scope: for a friend, for one, for the user.
Target = Struct.new(:friend, :one, :user) do
  def for_friend?; friend; end
  def for_one?; one; end
  def for_user?; user; end
end
# The id of the skill for one friend.
RAISE_SKILL = 141
# The scope of the skill for one friend.
RAISE = Target.new(true, true, false)
# An action whose RAISE_SKILL takes RAISE for its item.
class Game_Action
  alias_method :plain_set_skill, :set_skill
  def set_skill(id); id == RAISE_SKILL ? @item = RAISE : plain_set_skill(id); end
end
# Makes a command.
#
# @param actor [Game_Actor] Who gives it.
# @param item [Target] What it uses.
# @param target [Integer] The target's index.
# @return [Game_Action] The command.
def command(actor, item, target)
  Game_Action.new(actor).tap { |action| action.item = item; action.target_index = target }
end
live = MGQ_MpBattlesSync::Live
MGQ_MpBattlesCoop.instance_variable_set(:@seen, [])
live.close_phase
live.open_phase(scene)
check("a command phase notes the places anew", MGQ_MpBattlesCoop.instance_variable_get(:@seen), $game_party.battle_members)
own = $game_party.battle_members
own[0].actions = [command(own[0], RAISE, 2), command(own[0], Target.new(true, false, false), 2), command(own[0], Target.new(false, true, false), 2)]
own[1].actions = []
$chat = []
$commands_phase = false
$actor_cleared = false
$troop_actions = 0
$sent.clear
MGQ_MpBattlesSync::Channel.receive(2, "commands", wire_line([[[], [], [], [["skill", 12, 0]]], [3, 1, 2, 0]]))
$live.set("live.plan", "places" => [nil, nil, [], [["skill", 12, 0, nil]]])
check("the host whose command was for a character a guest swapped out chooses again", [live.host_guests_commands(scene), $commands_phase, $actor_cleared], [false, true, true])
$live.set("live.plan", nil)
check("the guests are told the host still chooses, after the wait for them was answered",
      $sent.map(&:last).select { |f| f["battle"] == "waiting" }.map { |f| f[:payload] }, ["2", "", "0"])
check("only the host's own commands start anew; the enemies keep theirs", [own[0].actions.map(&:item), $troop_actions], [[nil], 0])
check("the guest's commands were given as they came, and stay", $game_party.battle_members[3].actions.map(&:item), [[:skill, 12]])
check("the host is told why", $chat, ["A character you chose a command for left the Frontline. Choose your commands again."])
check("the log names who lost a target and who chooses again", $log.grep(/commands of seats 0 lost their target to a swap, choosing again: 0\z/).size, 1)
own = $game_party.battle_members
own[0].actions = [command(own[0], RAISE, 2)]
$live.set("live.phase unanswered", [])
check("chosen again, the turn goes on without waiting for a guest the DLL counts as answered", [live.host_guests_commands(scene), own[3].actions.map(&:item)], [true, [[:skill, 12]]])
$live.set("live.phase unanswered", nil)

live.close_phase
live.open_phase(scene)
MGQ_MpBattlesCoop.swap(scene, own[1], 0)
own = $game_party.battle_members
own[1].actions = [command(own[1], RAISE, 1)]
$chat = []
$commands_phase = false
$frames = 0
MGQ_MpBattlesSync::Channel.receive(2, "commands", wire_line([[[], [], [["skill", RAISE_SKILL, 1]], []], [3, 1, 2, 0]]))
plans = [[nil, nil, [["skill", RAISE_SKILL, 1, nil]], []], [nil, nil, [["skill", 12, 0, nil]], []]]
$live.set("live.plan") { |_request| { "places" => plans.shift } }
interim = nil
$inject = lambda do |frame|
  interim = $game_party.battle_members[2].actions.dup if frame == 1
  MGQ_MpBattlesSync::Channel.receive(2, "commands", wire_line([[[], [], [["skill", 12, 0]], []], [3, 1, 2, 0]])) if frame == 2
end
check("a guest whose command was for a character the host swapped out chooses again, the host waiting", live.host_guests_commands(scene), true)
$inject = nil
$live.set("live.plan", nil)
check("meanwhile the computer chooses nothing for the guest's characters", interim.map(&:item), [nil])
check("its new commands are taken, and the host's own command after its own swap stays", [$game_party.battle_members[2].actions.map(&:item), own[1].actions.size, $commands_phase, $chat], [[[:skill, 12]], 1, false, []])
check("the log names the guest", $log.grep(/choosing again: 2\z/).size, 1)

live.close_phase
live.open_phase(scene)
ally = $game_party.battle_members[2]
ally.actions = [command(ally, RAISE, 1)]
MGQ_MpBattlesCoop.swap(scene, $game_party.battle_members[1], 0)
MGQ_MpBattlesSync.guest_left(2)
check("a player who leaves takes their characters' actions along", ally.actions, [])
left_party = $game_party.battle_members.map(&:name)
live.open_phase(scene)
check("and stays in the party until the next phase", $game_party.battle_members.map(&:name), left_party)
$chat = []
ally.actions = [command(ally, RAISE, 1)]
check("a lost command of a player who left gives way to nothing, asking nobody", [live.host_guests_commands(scene), ally.actions, $chat], [true, [], []])
check("the log says nobody chooses again", $log.grep(/commands of seats 2 lost their target to a swap, choosing again: nobody/).size, 1)
five[0].hp = 0
five[1].hp = 0
$game_party.battle_members.each { |member| member.hp = 0 }
$game_party.battle_members[1].hp = 100
check("a swap may not leave nobody standing", MGQ_MpBattlesCoop.swap_kills_all?($game_party.battle_members[1], five[1]), true)
MGQ_MpBattlesCoop.ended

# A member's battle: the DLL asks the party's leader to lead it, and the member waits for the
# leader as its guest.
$leader = mate
$game_party.own = five.map { |actor| actor.tap { |a| a.hp = 100 } }
asks_leader = lambda { |bid| { "actions" => [coop_step("join", "role" => "guest", "bid" => bid, "seats" => [2], "label" => "Friend")], "asking" => true } }
$coop.set("coop.offer", asks_leader.call("m0"))
BattleManager.setup(62, false, true)
$coop.set("coop.offer", nil)
check("a member whose leader the DLL asks to lead the battle waits for it as its guest",
      [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.battle_id, MGQ_MpBattlesSync.seats, MGQ_MpBattles.kind], [:guest, "m0", [2], :coop])
answers = [nil, nil, "leads"]
$coop.set("coop.leader_wait") { |_request| answers.shift }
waits = $coop.asked("coop.leader_wait").size
MGQ_MpBattlesCoop.await_leader(scene)
$coop.set("coop.leader_wait", nil)
check("the member waits until the DLL has the leader's answer, which leading leaves the member the leader's guest",
      [$coop.asked("coop.leader_wait").size - waits, $coop.asked("coop.leader_end").last, MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.player], [3, "leads", :guest, "Friend"])
MGQ_MpBattlesCoop.ended

# The leader refuses: the member hosts, and the leader's characters still come first.
$sent.clear
$coop.set("coop.offer", asks_leader.call("m1"))
BattleManager.setup(61)
$coop.set("coop.offer", nil)
$coop.set("coop.leader_wait", "refused")
$coop.set("coop.leader_end", "troop" => 61, "escape" => true, "lose" => false)
$coop.set("coop.host", "actions" => [coop_step("join", "role" => "host", "bid" => "h1", "seats" => [2], "label" => "the party")])
MGQ_MpBattlesCoop.await_leader(scene)
%w(coop.leader_wait coop.leader_end coop.host).each { |topic| $coop.set(topic, nil) }
hosted = $coop.asked("coop.host").last
check("a leader who refuses leaves the battle to the member, who hosts it as the DLL says, under a new id",
      [$coop.asked("coop.leader_end").last, hosted.values_at("troop", "escape", "lose", "bid"), MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.battle_id],
      ["refused", [61, true, false, nil], :host, "h1"])
$coop.gathered([2, wire_line(["7,8,9,10", [[50, 5]] * 4, 8])])
$frames = 0
MGQ_MpBattlesCoop.gather(scene)
check("the party's leader leads the battle's party too", $game_party.battle_members.map(&:name).first, "Actor7 (Friend)")
check("the log names who joined, the roster and each rebuilt character", [$log.grep(/gathered battle .*Friend \(seat 2\) joined/).size > 0, $log.grep(/party of 2 players: Friend \(seat 2\): Frontline/).size > 0,
                                                                           $log.grep(/rebuilt Actor7 \(Friend\) \(7\) of seat 2, place 0/).size > 0], [true, true, true])
MGQ_MpBattlesCoop.ended

# The leader's side: the DLL has the player lead a member's battle once free on the map.
$leader = :me
$setup.clear
$sent.clear
$called = nil
lead = { "coop" => "lead", "bid" => "m2", "troop" => "64", "escape" => false, "lose" => true, "map" => "5" }
$coop.set("coop.poll", "actions" => [coop_step("lead", "seat" => 2, "fields" => lead)])
$coop.hosts("m2", [2])
MGQ_MpBattlesCoop.on_map
$coop.set("coop.poll", nil)
$coop.hosts(nil)
check("the leader starts the member's battle as its host", [$setup, $called, MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.battle_id], [[[64, false, true]], Scene_Battle, :host, "m2"])
check("telling the DLL whose battle it leads, under the id the member chose", $coop.asked("coop.offer").last["leading"], [2, "m2"])
$coop.gathered
$frames = 0
check("a member who asked and did not join calls the battle off", MGQ_MpBattlesCoop.gather(scene), :broken)
check("for everyone in it", $sent.map { |_, message| message["battle"] }.include?("broken"), true)
MGQ_MpBattlesCoop.ended
$coop.set("coop.poll", "actions" => [coop_step("lead", "seat" => 2, "fields" => lead.merge("bid" => "m3"))])
MGQ_MpBattlesCoop.on_map
$coop.set("coop.poll", nil)
check("a member's battle the DLL does not let the player host is refused, which the member then hosts",
      [$coop.asked("coop.refuse_lead").last.values_at("seat", "bid"), MGQ_MpBattlesSync.role], [[2, "m3"], nil])

# Invites: the DLL decides when the player joins one, from what the scripts tell it of the player.
$scene_now = Scene_Map.new
$typing = true
MGQ_MpBattlesCoop.on_map
check("a frame on the map tells the DLL the player types in the chat box, which an invite waits for", $coop.asked("coop.poll").last["facts"]["typing"], true)
$typing = false
story = { "coop" => "invite", "bid" => "s2", "troop" => "40", "escape" => true, "lose" => false, "seats" => [0], "map" => "5" }
$coop.status("waiting" => { "seat" => mate.seat, "bid" => "s2", "map" => "5" })
$gather_call = [mate.seat, 5]
MGQ_MpBattlesCoop.on_map
check("and that the invite waiting belongs to the story that calls the player over", $coop.asked("coop.poll").last["facts"]["story"], true)
$coop.set("coop.poll", "actions" => [coop_step("accept", "seat" => mate.seat, "label" => "story", "fields" => story)])
MGQ_MpBattlesCoop.on_map
$coop.set("coop.poll", nil)
check("joining the story's battle drops the call", [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.battle_id, $gather_call, !$gather_dropped.nil?], [:guest, "s2", nil, true])
MGQ_MpBattlesCoop.ended

# A random encounter the DLL holds for busy party members on the map.
$setup.clear
$called = nil
map = Scene_Map.new
$encounter_troop = 70
$coop.set("coop.offer", "actions" => [coop_step("held")], "holding" => true)
check("an encounter the DLL holds starts no battle yet", [$game_player.encounter, MGQ_MpBattlesCoop.holding?, $setup], [false, true, [[70, true, false]]])
check("told to the DLL as a random encounter", $coop.asked("coop.offer").last.values_at("encounter", "encountering"), [true, true])
$coop.set("coop.offer", nil)
map.update_call_menu
check("the player stands still and opens no menu meanwhile", [$game_player.movable?, map.menu_calling], [false, false])
check("nor meets another encounter", [($encounter_troop = 71) && $game_player.encounter, $setup.size], [false, 1])
$encounter_troop = nil
$coop.set("coop.poll", "actions" => [coop_step("start_held", "seats" => [2], "troop" => 70, "escape" => true, "lose" => false)])
$coop.hosts("b7", [2])
MGQ_MpBattlesCoop.on_map
$coop.set("coop.poll", nil)
$coop.hosts(nil)
check("once the DLL starts it, it is offered again and starts",
      [MGQ_MpBattlesCoop.holding?, $called, MGQ_MpBattlesSync.role, $coop.asked("coop.offer").last.values_at("troop", "encounter", "escape", "lose")],
      [false, Scene_Battle, :host, [70, true, true, false]])
check("letting the DLL release the players the hold froze whom the battle leaves out", $coop.asked("coop.release").last["seats"], [2])
MGQ_MpBattlesCoop.ended

$coop.set("coop.offer", "actions" => [coop_step("held")], "holding" => true)
$encounter_troop = 73
$game_player.encounter
$coop.set("coop.offer", nil)
drops = $coop.asked("coop.drop").size
MGQ_MpBattlesCoop.drop
check("a reset forgets a held encounter, the DLL told", [MGQ_MpBattlesCoop.holding?, $game_player.movable?, $coop.asked("coop.drop").size - drops], [false, true, 1])

# The DLL's messages for the notification box, and the stand-still for a member's encounter.
# The notification box, keeping what is posted in $notice_posts and dropped in $notice_drops.
module MGQ_MpNotices
  def self.message(key, text, frames = nil); ($notice_posts ||= []) << [key, text, frames]; end
  def self.drop(key, reason = "taken away"); ($notice_drops ||= []) << [key, reason]; end
end
$notice_posts = []
$notice_drops = []
$world_bridge.post("coop.notice", "key" => "soon", "seat" => 2, "text" => "Enemies! Friend is in a battle.", "frames" => 600)
$coop.status("frozen" => true)
check("a member's encounter the DLL holds the player for stops them, with the DLL's notice", [$game_player.movable?, $notice_posts], [false, [[[:soon, 2], "Enemies! Friend is in a battle.", 600]]])
$coop.status("frozen" => true, "waiting" => { "seat" => 2, "bid" => "i3", "map" => "5" })
check("a screen the mod opens on its own waits while an invite is open, so it never lapses behind one (issue 79)", MGQ_MpCoop.screens_wait?, true)
$coop.set("coop.decline_waiting", "frozen" => false, "waiting" => nil)
MGQ_MpBattlesCoop.decline_waiting("the player turns it down")
$coop.set("coop.decline_waiting", nil)
$world_bridge.post("coop.drop_notice", "key" => "soon", "seat" => 2, "reason" => "the invite was turned down")
MGQ_Multiplayer::Bridge.frame
check("turning the invite down goes to the DLL, whose answer lets the player walk on and the screens open, its notice taken away",
      [$coop.asked("coop.decline_waiting").last, $game_player.movable?, MGQ_MpCoop.screens_wait?, $notice_drops], ["the player turns it down", true, false, [[[:soon, 2], "the invite was turned down"]]])
$world_bridge.post("coop.drop_notice", "key" => "hold", "seat" => nil, "reason" => nil)
MGQ_Multiplayer::Bridge.frame
check("a notice taken away without a seat or reason is the box's own", $notice_drops.last, [:hold, "taken away"])
$scene_now = scene

# A guest's character takes the host's states, and the game reads its features anew, so a state's
# extra actions, such as Division's, count on the guest too.
$data_states = [nil, :poison, :division]
# The game's cache of features, keeping the id of each character it clears in $cleared.
module CacheActorFeatures; def self.init_actor(actor); ($cleared ||= []) << actor.id; end; end
# A character, which the game takes for an actor.
class Game_Actor; def actor?; true; end; end
guest_actor = Game_Actor.new(7)
$cleared = []
MGQ_MpBattlesSync::Playback.values(guest_actor, 90, 5, 0, [2], [3], [0] * 8, 0)
check("new states let the game read the character's features anew", [MGQ_MpGame.get(guest_actor, :states), $cleared], [[2], [7]])
check("with the turns the host's states have left", MGQ_MpGame.get(guest_actor, :state_turns), { 2 => 3 })
MGQ_MpBattlesSync::Playback.values(guest_actor, 80, 5, 0, [2], [2], [0] * 8, 0)
check("the same states only change its values", [$cleared, MGQ_MpGame.get(guest_actor, :state_turns)], [[7], { 2 => 2 }])

# The host logs where a rebuilt character differs from what its owner's game showed, its counter
# rate among them.
# A rebuilt character whose differences are $differences.
class Game_MpActor; def differences; $differences || []; end; end
$log.clear
$differences = ["counter 0 (sent 500)"]
MGQ_MpBattlesCoop.check(Game_MpAlly.allocate.tap { |ally| ally.define_singleton_method(:name) { "Actor9 (Mate)" } })
check("a rebuild that differs is logged", $log.last, "co-op battle: Actor9 (Mate) differs: counter 0 (sent 500)")
$differences = nil

# The guest shows the host's messages through the game's message, which names their speaker, and
# lets the game move an earlier message on before a new one starts.
# The game's message, holding text while $game_message_texts has lines.
class Game_Message
  attr_accessor :face_name, :face_index, :background, :position
  def has_text?; !$game_message_texts.to_a.empty?; end
end
# A battle whose wait for a message counts in $message_waits and moves the message on.
class Scene_Battle; def wait_for_message; $message_waits += 1; $game_message_texts = []; end; end
playback = MGQ_MpBattlesSync::Playback
speaker = $game_troop.members[0]
MGQ_MpBattlesSync.join_world(:guest, "g8", [0], "Host")
playback.reset
$message_waits = 0
$game_message_texts = []
playback.message(scene, speaker, "face", 1, 0, 2, "First line")
playback.message(scene, speaker, "face", 1, 0, 2, "Second line")
check("a message's lines go into the game's message with their speaker", [$game_message_texts, $game_message.speaker, $message_waits], [["First line", "Second line"], speaker, 0])
playback.instance_variable_set(:@message_complete, true)
playback.message(scene, nil, "", 0, 0, 2, "Next message")
check("a new message lets the game move the earlier one on first", [$message_waits, $game_message_texts, $game_message.speaker], [1, ["Next message"], nil])
$game_message_texts = []
playback.instance_variable_set(:@message_complete, true)
playback.message(scene, speaker, "face", 1, 0, 2, "Alone")
check("with nothing waiting it starts at once", [$message_waits, $game_message_texts], [1, ["Alone"]])
playback.message(scene, speaker, "MissingFace", 1, 0, 2, "Faceless")
check("a face this game lacks is left out of the message", [$game_message.face_name, $game_message_texts.last], ["", "Faceless"])
MGQ_MpBattlesSync.finish

# Another player's fallen character comes fallen; one without HP sent comes as rebuilt.
plans = [{ "hp" => 0, "mp" => 3 }, {}]
$battlers.plans["ally"] = lambda { |_request| plans.shift }
fallen = MGQ_MpBattlesCoop.new_ally(MGQ_MpActors::Builds::Member.new(12), "Mate", 2, 0, [0, 3])
whole = MGQ_MpBattlesCoop.new_ally(MGQ_MpActors::Builds::Member.new(13), "Mate", 2, 1, nil)
check("another player's fallen character is planned with the vitals sent and rebuilt fallen as the DLL plans, one without as rebuilt",
      [$battlers.asked("battlers.plan").last(2).map { |request| request["vitals"] }, fallen.hp, fallen.mp, whole.hp], [[[0, 3], nil], 0, 3, 100])

# Another player's character starts the battle at the HP it came with, which the game's states of a
# trait for low HP go by (issue #31), through the game's own start, which gives it its counters and
# clears its actions before a spell before the battle reads them (the crash of 2026-09-30).
$battlers.plans["ally"] = { "hp" => 3, "mp" => 1 }
pinched = MGQ_MpBattlesCoop.new_ally(MGQ_MpActors::Builds::Member.new(14), "Mate", 2, 2, [3, 1])
$battlers.plans.delete("ally")
check("another player's character starts the battle through the game's own start, at the HP and MP planned",
      [pinched.start_hp, pinched.mp, pinched.counters_set], [3, 1, true])

# Forms a guest's co-op battle with the host at seat 0 and the player's four characters at seat 2,
# two of them on the Backline.
#
# @param scene [Scene_Battle] The battle.
# @param bid [String] The battle's id.
def form_guest_battle(scene, bid)
  $my_seat = 2
  MGQ_MpBattlesSync.join_world(:guest, bid, [0], "Host")
  MGQ_MpBattlesSync.battle_started
  MGQ_MpBattles.begin(:coop)
  MGQ_MpBattlers.start_guest
  MGQ_MpBattlesCoop.own_build
  MGQ_MpBattlesCoop.form(scene, [[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3,4", [[100, 10]] * 4, 8, [0, 1, 2, 3], 2, 2]])
end

# Skills and items that reach the Backline too.
# A skill or item that reaches the Backline too or not.
class TargetItem
  def initialize(bench); @bench = bench; end
  def include_bench?; @bench; end
end
$game_party.own = five.dup
form_guest_battle(scene, "g30")
check("a skill that reaches the Backline too reaches the co-op party and the player's own Backline",
      $game_party.item_target_members(TargetItem.new(true)).map(&:name), ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor2", "Actor3", "Actor4"])
check("any other reaches the co-op party", $game_party.item_target_members(TargetItem.new(false)).map(&:name), ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor2"])

# The Library all saves share counts only the player's own characters.
$counted = []
members = $game_party.battle_members
BattleManager.battle_end(0)
check("the battle's end counts only the player's own characters' battles", $counted, [[1, :battle], [2, :battle]])
$counted = []
enemy = $game_troop.members[0]
scene.count_up_defeat(members[0], enemy)
check("a defeat by another player's character counts nothing", $counted, [])
scene.count_up_defeat(enemy, members[2])
check("one between the player's own and an enemy counts", $counted, [[enemy.id, :defeat], [1, :down]])

# A player whose own characters all fell while the co-op party won stands up as after a defeat,
# else the victory's autosave keeps them fallen and the map sends the player to the game over.
class Game_Actor; def dead?; @hp == 0; end; end
$game_party.own.each { |actor| actor.hp = 0 }
members[0].hp = 0
BattleManager.battle_end(0)
check("a player whose own characters all fell in a won battle has them stand up with 1 HP", [$game_party.own.map(&:hp).uniq, members[0].hp], [[1], 0])
$game_party.own.each { |actor| actor.hp = 0 }
$game_party.own[4].hp = 40
BattleManager.battle_end(0)
check("one with a character still standing keeps the fallen down", $game_party.own.map(&:hp), [0, 0, 0, 0, 40])
$game_party.own.each { |actor| actor.hp = 0 }
BattleManager.battle_end(2)
check("and a lost battle leaves standing up to the game's defeat", $game_party.own.map(&:hp).uniq, [0])
MGQ_MpBattlesCoop.stand_up_loaded
check("a save loaded in a world with all of them fallen stands them up too", $game_party.own.map(&:hp).uniq, [1])
$game_party.own.each { |actor| actor.hp = 100 }
members[0].hp = 100

# The end drops the game's Retry, whose snapshot holds synced stats or an older battle.
BattleManager.instance_variable_set(:@retry_data, "the start of the battle")
MGQ_MpBattlesCoop.ended
check("the end of a co-op battle drops the game's Retry", BattleManager.instance_variable_get(:@retry_data), nil)
$counted = []
BattleManager.battle_end(0)
check("outside a co-op battle the battle's end counts as the game does", $counted.size, 4)

# A reset in the middle of a co-op battle.
form_guest_battle(scene, "g31")
$coop.status("asking" => true)
$game_switches = Game_Switches.new
drops = $coop.asked("coop.drop").size
Scene_Title.new.start
check("a reset forgets the co-op party, the rules and the request to the leader, the DLL told",
      [MGQ_MpBattlesCoop.active?, MGQ_MpBattles.running?, $game_party.battle_members.map(&:name), MGQ_MpBattlesCoop.instance_variable_get(:@asking_leader), $coop.asked("coop.drop").size - drops],
      [false, false, five.first(4).map(&:name), false, 1])
MGQ_MpBattles.finish
check("and never puts the rules' switches into the save loaded next", $game_switches[86], false)
MGQ_MpBattlesSync.finish

# A guest whose host leaves takes the battle over: one before the host's party came starts it as
# its own, without starting its party and troop a second time; one later goes on from the battlers
# its start made whole and picks a defeat scene.
$game_party.in_battle = false
$my_seat = 2
MGQ_MpBattlesSync.join_world(:guest, "g32", [0], "Host")
MGQ_MpBattlesSync.battle_started
MGQ_MpBattles.begin(:coop)
$battle_starts = []
MGQ_MpBattlers.start_guest
started = $game_party.all_members + $game_troop.members
$battle_started = false
$turn_ends = 0
$commands_phase = false
MGQ_MpBattlesCoop.take_over(scene)
check("a guest whose host left before the party came starts the battle as its own, each battler started once",
      [$battle_started, $turn_ends, $commands_phase, MGQ_MpBattlesSync.role, MGQ_MpBattles.running?, started.map { |battler| $battle_starts.count(battler) }.uniq],
      [true, 0, true, nil, false, [1]])
$game_party.in_battle = false
$battle_starts = []
form_guest_battle(scene, "g33")
$battle_started = false
$data_common_events = [nil] * 6000
$data_common_events[6031] = $data_common_events[6032] = $data_common_events[6099] = :scene
$game_temp.lose_event_id = 6099
MGQ_MpBattlesCoop.take_over(scene)
check("one whose host left later goes on from the battlers the game's start gave, each started once",
      [$battle_started, $turn_ends, ($game_party.battle_members + $game_troop.members).map { |battler| $battle_starts.count(battler) }.uniq], [false, 1, [1]])
check("and a defeat scene of its enemies instead of a former battle's",
      [[6031, 6032].include?($game_temp.lose_event_id), $game_temp.lose_event_enemy_id == $game_temp.lose_event_id - 6000], [true, true])
$data_common_events = known_events

# A guest's start gives every character of its party and every enemy the game's own start, whose
# counters the EXP rate is among (issue #24), and marks the party as fighting.
$game_party.in_battle = false
$battle_starts = []
MGQ_MpBattlers.start_guest
check("a guest's start gives every character of the party and every enemy the game's start",
      [$game_party.all_members.size > 1, ($game_party.all_members + $game_troop.members).map { |battler| $battle_starts.count(battler) }.uniq, $game_party.in_battle],
      [true, [1], true])
# A guest whose game lacks every enemy of the battle's troop keeps the troop empty, whose start in
# the game reads a random enemy and failed.
troop = $game_troop.members
$game_troop.members = []
$game_party.in_battle = false
failure =
  begin
    MGQ_MpBattlers.start_guest
    nil
  rescue => e
    e
  end
check("a guest whose troop is empty starts its party without failing", [failure, $game_party.in_battle, $log.grep(/starting the guest's battle failed/)], [nil, true, []])
$game_troop.members = troop

# A guest the host's party leaves out, since it joined after the host stopped waiting.
$my_seat = 7
MGQ_MpOverworldSync::Peers.all.clear
MGQ_MpOverworldSync::Peers.all.push(mate)
MGQ_MpBattlesSync.join_world(:guest, "late1", [2], "Friend")
MGQ_MpBattlesSync.battle_started
$coop.roster(wire_line([[[31, 0, 0, 0]], [[2, "Friend", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0]], 0]))
$frames = 0
check("a guest the host's party leaves out ends its battle", [MGQ_MpBattlesCoop.join(scene), MGQ_MpBattlesSync.broken?, MGQ_MpBattlesCoop.active?], [:broken, true, false])
$coop.roster(nil)
MGQ_MpBattlesSync.finish
MGQ_MpBattlesSync.join_world(:guest, "late2", [2], "Friend")
MGQ_MpBattlesSync.battle_started
$frames = 0
$coop.roster(false)
check("so does one whose roster the DLL's wait runs late for", MGQ_MpBattlesCoop.join(scene), :broken)
$coop.roster(nil)
MGQ_MpBattlesSync.finish
$my_seat = 0
$leader = :me
$game_party.own = five.dup

# The steps to the next random encounter, which the DLL stretches while others who would fight it
# stand near.
$coop.set("coop.steps", 15000)
$game_player.make_encounter_count
check("the steps the game drew go to the DLL in hundredths with the player's facts, and the player takes the DLL's",
      [$coop.asked("coop.steps").last["steps"], $coop.asked("coop.steps").last["facts"]["map"], $game_player.encounter_count], [10000, 5, 150.0])
$coop.set("coop.steps", nil)
$game_player.make_encounter_count
check("a draw the DLL leaves as it is stays the game's", $game_player.encounter_count, 100.0)

# A Raid World: every player bringing one on the Frontline and two on the Backline.
# The world, a Raid World while $raid is set.
module MGQ_MpWorld; def self.raid?; $raid; end; end
$raid = true
$leader = :me
$my_seat = 0
$game_party.own = five.dup
$game_party.in_battle = true
MGQ_MpOverworldSync::Peers.all.clear
MGQ_MpOverworldSync::Peers.all.push(mate)
$game_map.map_id = 5
raid_build = MGQ_MpBattlesCoop.own_build
check("a player brings their first three", [raid_build[0], raid_build[1].size], ["1,2,3", 3])
raid_players = [[0, "Me", "1,2,3", [], 4], [2, "Friend", "7,8,9", [], 4], [3, "Pal", "10,11,12", [], 4]]
check("each of three players has one and two", MGQ_MpBattlesCoop.arrange(raid_players).map { |p| [p.front, p.bench] }, [[1, 2]] * 3)
check("a team duel splits its Frontline as in a Classic world",
      MGQ_MpBattlesCoop.arrange(raid_players.first(2).map { |seat, name, _, vitals, max| [seat, name, "1,2,3,4", vitals, max] }, false).map { |p| [p.front, p.bench] }, [[2, 0], [2, 0]])

$coop.hosts("r1", [2])
BattleManager.setup(70)
$coop.hosts(nil)
$coop.gathered([2, wire_line(["7,8,9", [[50, 5], [60, 6], [70, 7]], 4])])
$frames = 0
$sent.clear
MGQ_MpBattlesCoop.gather(scene)
check("a Raid World's host gathers the players for as long as a Raid World's battle waits", gather_start["limit"], MGQ_MpBattlesCoop::RAID_JOIN_FRAMES)
raid_roster = $sent.map(&:last).find { |f| f["battle"] == "roster" }
check("the roster gives each player one and two", wire_values(raid_roster[:payload])[1].map { |p| p[6, 2] }, [[1, 2], [1, 2]])
check("the party is each player's first character", $game_party.battle_members.map(&:name), ["Actor1", "Actor7 (Friend)"])
check("the player's Backline their next two", $game_party.bench_members.map(&:name), ["Actor2", "Actor3"])
MGQ_MpBattlesSync.guest_left(2)
$coop.set("coop.settle", "staying" => [0], "left" => [2], "outcome" => "solo")
MGQ_MpBattlesCoop.settle(scene)
$coop.set("coop.settle", nil)
check("alone, the host fights on with one and two, never a bigger team",
      [MGQ_MpBattlesCoop.active?, $game_party.max_battle_members, $game_party.battle_members, $game_party.bench_members], [false, 1, five.first(1), five[1, 2]])
check("the fourth stays out of the skills that reach the Backline too", $game_party.item_target_members(TargetItem.new(true)).size, 3)
MGQ_MpBattlesCoop.ended
$game_party.in_battle = false
check("outside a battle the game's Frontline stays", $game_party.max_battle_members, 4)
check("a team duel takes only the squad, never the fourth", MGQ_MpBattlesCoop.team_build[0], "1,2,3")
$raid = false
$game_party.in_battle = true
check("a Classic world's battles keep the whole team", [$game_party.max_battle_members, $game_party.battle_members], [4, five.first(4)])
$game_party.in_battle = false

# A Raid World's battle: whom it takes is the DLL's to say.
# The trading, whose session is $trade_session.
module MGQ_MpTrade; def self.session; $trade_session; end; end

# Makes another player on map 5.
#
# @param seat [Integer] Their seat.
# @param state [Hash] What their state says besides the map and the scene.
# @return [MGQ_MpOverworldSync::Peers::Peer] The player.
def raid_peer(seat, state = {})
  MGQ_MpOverworldSync::Peers::Peer.new(seat, { "id" => "id-#{seat}", "name" => "P#{seat}", "map" => "5", "scene" => "map", "x" => "0", "y" => "0" }.merge(state), nil, false)
end

$raid = true
$my_seat = 0
$game_party.own = five.dup
$scene_now = Scene_Map.new
MGQ_MpBattlesCoop.drop
near = raid_peer(6, { "x" => "1", "y" => "1" })
reader = raid_peer(9, { "scene" => "event" })
MGQ_MpOverworldSync::Peers.all.replace([near, reader])
# The players reading the story the player tells, $viewers while set.
class << MGQ_MpCoop::Scope
  alias_method :viewers_of_scope, :viewers
  def viewers; $viewers || viewers_of_scope; end
end
$viewers = [reader]
$coop.set("coop.raid_candidates", [9, 6, 40])
check("a Raid World's battle takes the players the DLL names, one the world does not know left out", MGQ_MpBattlesCoop.raid_candidates(true).map(&:seat), [9, 6])
check("asking with the players reading the player's story for a boss battle", $coop.asked("coop.raid_candidates").last.values_at("viewers", "stays_out"), [[9], []])
MGQ_MpBattlesCoop.raid_candidates(false)
check("and none for another battle", $coop.asked("coop.raid_candidates").last["viewers"], [])
$coop.set("coop.raid_candidates", nil)
$viewers = nil
check("the host comes first", MGQ_MpBattlesCoop.arrange([[3, "P3", "1", [], 4], [0, "Me", "1", [], 4]]).map(&:seat), [0, 3])

# A guest of a Raid World's battle.
MGQ_MpBattlesSync.join_world(:guest, "rg1", [6], "P6")
MGQ_MpBattlesSync.battle_started
$frames = 0
$coop.roster(false)
MGQ_MpBattlesCoop.join(scene)
$coop.roster(nil)
check("a guest waits longer for the roster than the host for the players",
      $coop.asked("coop.roster_wait").select { |request| request["op"] == "start" }.last["limit"], MGQ_MpBattlesCoop::RAID_JOIN_FRAMES + MGQ_MpBattlesCoop::ROSTER_MARGIN_FRAMES)
MGQ_MpBattlesSync.finish

# A host's word that their battle is off: the asking side first, then the matchmaking.
MGQ_MpBattlesSync.join_world(:guest, "h2", [6], "P6")
MGQ_MpBattlesSync.battle_started
$coop.set("coop.take_off", "actions" => [coop_step("break_off", "label" => "P6 gave battle h2 up for another")])
$coop.message(near, { "coop" => "off", "bid" => "h2" })
check("a host's word that their battle is off goes to the DLL's asking side, then its matchmaking, whose word to break off the guest takes",
      [$coop.asked("coop.ask_off").last.values_at("seat", "fields"), $coop.asked("coop.take_off").last.values_at("seat", "fields"), MGQ_MpBattlesSync.broken?],
      [[6, { "coop" => "off", "bid" => "h2" }], [6, { "coop" => "off", "bid" => "h2" }], true])
MGQ_MpBattlesSync.finish
$coop.set("coop.ask_off", true)
offs = $coop.asked("coop.take_off").size
$coop.message(near, { "coop" => "off", "bid" => "h3" })
check("one the asking side took goes no further", $coop.asked("coop.take_off").size, offs)
$coop.set("coop.ask_off", nil)
$coop.set("coop.take_off", nil)

# Trading.
$trade_session = Object.new
MGQ_MpBattlesCoop.on_map
check("a player who trades tells the DLL every frame", $coop.asked("coop.poll").last["facts"]["trading"], true)
$coop.status("busy" => true)
check("and tells the others they are busy as the DLL's status says", MGQ_MpBattlesCoop.state_fields, { "busy" => true })
$trade_session = nil
$coop.status
check("a free player tells it too", MGQ_MpBattlesCoop.state_fields, { "busy" => false })
$raid = false
check("a Classic world's player tells nothing", MGQ_MpBattlesCoop.state_fields, {})
$raid = true

# A rival's battle the DLL has the player yield to: the player gives up their own and becomes its
# guest, with its troop, its enemy rates and its pools, and has their own rates back as it ends.
# The raid boss pools, keeping each troop set up in $pool_set_ups.
module MGQ_MpRaidPool
  def self.note_invite(_message); end
  def self.set_up(troop_id); ($pool_set_ups ||= []) << troop_id; end
  def self.invite_fields(_troop_id = nil); {}; end
  def self.won_already?(_troop_id); false; end
  def self.rescale; end
end
# Keeps the troop whose chance to escape is made in $escape_troop.
def BattleManager.make_escape_ratio; $escape_troop = $game_troop.troop_id; end
rival = raid_peer(13)
early = raid_peer(14)
MGQ_MpOverworldSync::Peers.all.replace([near, rival, early])
rates = MGQ_MpBattlesCoop::RATE_VARIABLES
rates.each { |id| $game_variables[id] = 50 }
rival_invite = { "coop" => "invite", "bid" => "rv1", "troop" => "90", "escape" => false, "lose" => true, "seats" => [0, 3], "map" => "5", "boss" => true,
                 "rates" => [110, 110, 110, 110, 110, 110] }
$coop.hosts("own1", [6])
$encounter_troop = 81
$game_player.encounter
$coop.hosts(nil)
check("a Raid World's battle tells the DLL the player's enemy rates for its invites", $coop.asked("coop.offer").last["rates"], [50] * 6)
$scene_now = scene
$coop.status("rival" => true)
$coop.set("coop.yield", "actions" => [coop_step("yield", "seat" => 13, "label" => "P13", "fields" => rival_invite)])
check("a rival the DLL keeps ends the gathering, the player becoming its guest", [MGQ_MpBattlesCoop.gather(scene), MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.battle_id, MGQ_MpBattlesSync.seats],
      [:guest, :guest, "rv1", [13]])
$coop.set("coop.yield", nil)
check("fighting its troop, escape and lose, with the troop's own chance to escape",
      [$game_troop.troop_id, MGQ_MpGame.get(BattleManager, :can_escape), MGQ_MpGame.get(BattleManager, :can_lose), $escape_troop], [90, false, true, 90])
check("and its word that it is a boss battle, its enemy rates and the raid boss's pools it names",
      [MGQ_MpBattlesHotjoin.instance_variable_get(:@boss_battle), rates.map { |id| $game_variables[id] }, $pool_set_ups.last], [true, [110] * 6, 90])
BattleManager.battle_end(0)
check("and has its own rates back as the battle ends", rates.map { |id| $game_variables[id] }, [50] * 6)
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish

# A guest whose host gave its battle up follows to the battle whose invite the DLL kept.
a_invite = { "coop" => "invite", "bid" => "a1", "troop" => "93", "escape" => false, "lose" => true, "seats" => [0], "map" => "5", "enc" => "1" }
MGQ_MpBattlesSync.join_world(:guest, "b1", [13], "P13")
MGQ_MpBattlesSync.battle_started
$sent.clear
$frames = 0
$coop.set("coop.take_off", "actions" => [coop_step("follow", "seat" => 14, "label" => "P14", "fields" => a_invite)])
$coop.set("coop.roster_wait frame") { |_request| { "roster" => nil, "late" => MGQ_MpBattlesSync.battle_id == "a1", "frames" => 1 } }
$inject = lambda { |frame| $coop.message(rival, { "coop" => "off", "bid" => "b1" }) if frame == 1 }
MGQ_MpBattlesCoop.join(scene)
$inject = nil
$coop.set("coop.take_off", nil)
$coop.set("coop.roster_wait frame", nil)
joins = $sent.select { |_, f| f["battle"] == "join" }.map { |seat, f| [seat, f["bid"]] }
check("and joins that battle, its troop and the raid boss's pools it names", [joins, MGQ_MpBattlesSync.battle_id, $game_troop.troop_id, $pool_set_ups.last],
      [[[13, "b1"], [14, "a1"]], "a1", 93, 93])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish
$scene_now = Scene_Map.new

# A raid boss battle whose pools are all empty already, which the DLL invites nobody to.
# Takes troop 95's pools for empty.
def MGQ_MpRaidPool.won_already?(troop_id); troop_id.to_i == 95; end
BattleManager.setup(95)
check("a raid boss battle whose pools are all empty goes to the DLL as one", [$coop.asked("coop.offer").last["pools_won"], MGQ_MpBattlesSync.role], [true, nil])
# Takes no troop's pools for empty.
def MGQ_MpRaidPool.won_already?(_troop_id); false; end
MGQ_MpBattlesCoop.drop
$raid = false
$scene_now = scene

# Players another game sends with fields of the wrong kind.
player_class = MGQ_MpBattlesCoop::Player
odd = player_class.read([2, "Pal", "1,2", true, [8], ["x"], "2", -1])
check("a player's fields of the wrong kind are dropped", odd.to_a, [2, "Pal", "1,2", [], nil, nil, nil, nil])
check("so their places on the Frontline and the Backline still read", odd.lines, [[], []])
player_class.read([3, "Mate", "1", [], [8]])
check("each dropped field is logged once", $log.grep(/dropped a player's max another game sent as Array/).size, 1)
check("a player whose seat is no number is left out", player_class.read_all([["2", "Pal"], [3, "Mate", "1"], true, nil]).map(&:seat), [3])
arranged = MGQ_MpBattlesCoop.arrange([[0, "Me", "1,2,3", [], [8]], [[2], "Pal", "4,5"]])
check("arranging such players counts a party_member_max that is no number as none", arranged.map { |player| [player.seat, player.max, player.order] }, [[0, nil, [0, 1, 2]]])
check("no hook failed", $log.grep(/FAILED/), [])
