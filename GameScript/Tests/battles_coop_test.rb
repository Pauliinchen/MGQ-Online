#----------------------------------------------------------------
#  battles_coop_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Checked that a Classic co-op host tells its guest a troop that grew mid-battle once, before the send of its stream, and again should telling it fail
#                            - Checked that a player who yields to a rival's boss battle notes it as one
#                            - Checked that a Raid World's battle takes a player whose game window is in the background, but not a busy one
#      Paulinchen  2026-10-08: Checked that a face this game lacks is left out of a message the host shows
#                            - Checked that a Raid World's co-op battle gives every player one and two, also to a host left alone, and that its team duels split as before
#                            - Checked that a player brings only their squad to a Raid World's team duel
#                            - Checked whom a Raid World's battle takes, that the player who starts it hosts it and invites through the map's gate, its ten seconds to join and that the host comes first
#                            - Checked that a host who gave a battle up takes its invite back, that a player who trades tells it and turns invites down, and that a Raid World refuses requests to lead
#                            - Checked that of two battles started at the same moment the player who entered the map first hosts, and that only a random encounter yields
#                            - Checked that a rival's invite that waited as the battle began is kept, that of two waiting invites or rivals the later host's is turned down, that a held encounter lets the players it leaves out walk on and that a Classic world takes no co-op message through the map's gate
#                            - Checked that a battle invites the host of a waiting invite, that a random encounter yields to an event's battle, that a guest follows to the battle its host yields to and that another host's word that their battle is off keeps the player still for a waiting invite
#      Paulinchen  2026-10-07: Read a rebuilt character's log line as the live battle names characters, its id after its name
#                            - Checked that the log names the leader's answer, who joined, the roster, each rebuild and why an invite was turned down
#                            - Checked that a guest who leaves takes their characters' actions along, and that the host's computer chooses none while it waits
#                            - Checked that a guest's party is named after its own characters
#      Paulinchen  2026-10-06: Checked that another player's fallen character comes fallen
#                            - Checked that a skill reaching the Backline too reaches the co-op party, and that the Library counts only the player's own characters
#                            - Checked that the end drops the game's Retry, and that a reset forgets the co-op battle and its rules
#                            - Checked that a guest who takes over starts the battle or sets its counters, and that a guest left out ends its battle
#                            - Checked that invites and requests the player cannot take are turned down at once
#                            - Checked that a guest's commands go no further than the host's actions, and that an empty list takes them away
#                            - Checked that the guest takes the turns the host's states have left
#                            - Checked that the guest shows the host's messages through the game's message, with their speaker
#      Paulinchen  2026-10-04: Checked that only the players whose command was for a character another player swapped out choose again
#                            - Checked that a player who leaves mid-phase stays in the party until the next phase
#                            - Checked that the roster carries the battle's level and that the party goes through the level sync
#                            - Checked that the host logs a rebuild that differs
#                            - Checked that new states let the game read a guest's character's features anew
#                            - Checked that a member's encounter holds the party members on the map
#                            - Followed the scripts to their new names, without mp_
#                            - Checked that the guest of a lost battle takes the host's defeat scene, or one of its own enemies
#      Paulinchen  2026-10-03: Checked that the others' characters start the battle and each turn with a hit count
#                            - Checked that the map shows the player's own leader again after the battle
#                            - Checked that the party's leader leads a member's battle, and that the member hosts once the leader refuses or stays silent
#                            - Checked that invites during a battle of the player's own or older than three seconds are turned down
#                            - Checked that a random encounter waits up to three seconds for busy members on the map
#                            - Checked that a guest's command the character may not give is left out
#      Paulinchen  2026-10-02: Checked that a player who joined and left the world before the roster does not stop the battle
#                            - Ended the guest's battle through guest_end
#      Paulinchen  2026-10-01: Checked that every player hears at once when another leaves the battle
#                            - Checked that a guest whose troop differs fights the host's enemies
#                            - Checked the squads players bring, the leader first, and swaps with the Backline
#                            - Took the stand-ins from battle_support.rb, which the team duel test shares
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers co-op battles, battles_coop.rbx with battles_sync.rbx, battles.rbx and
# coop_squad.rbx: from the invite to the end of the battle, for the host and for a guest.

require_relative "battle_support"

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

# The host invites.
BattleManager.setup(40, true, false)
invite = $sent.map { |seat, text| [seat, fields_of(text)] }.find { |_, f| f["coop"] == "invite" }
check("a battle invites the party members playing on the map", invite && [invite[0], invite[1]["troop"], invite[1]["seats"], invite[1]["escape"], invite[1]["lose"]], [-1, "40", "2", "1", "0"])
check("and becomes a live co-op battle as host", [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.coop?, MGQ_MpBattlesSync.live?, MGQ_MpBattles.kind], [:host, true, true, :coop])
check("with the multiplayer rules", BattleManager.can_giveup?, false)

# Nobody joins.
$sent.clear
$frames = 0
MGQ_MpBattlesSync.take(friend, { "battle" => "decline", "bid" => MGQ_MpBattlesSync.battle_id, :payload => "" })
check("a decline ends the gathering", MGQ_MpBattlesCoop.gather(scene), nil)
check("and without anyone the battle is the host's own", [MGQ_MpBattlesSync.role, MGQ_MpBattles.running?, MGQ_MpBattlesCoop.active?], [nil, false, false])

# Somebody joins, then leaves the world before the roster goes out.
BattleManager.setup(40, true, false)
bid = MGQ_MpBattlesSync.battle_id
$sent.clear
$frames = 0
$inject = lambda do |frame|
  next unless frame == 3

  MGQ_MpBattlesSync.take(friend, { "battle" => "join", "bid" => bid, :payload => MGQ_MpBattlesSync::Wire.line(["7,8,9", [[50, 5], [60, 6], [70, 7]], 8]) })
  MGQ_MpOverworldSync::Peers.all.delete(friend)
end
check("a player who joined and left the world since does not stop the battle", MGQ_MpBattlesCoop.gather(scene), nil)
$inject = nil
roster = $sent.map { |seat, text| fields_of(text) }.find { |f| f["battle"] == "roster" }
check("and is named as unknown", MGQ_MpBattlesSync::Wire.parse(roster[:payload])[1].map { |p| p[0, 2] }, [[0, "Me"], [2, "?"]])
MGQ_MpOverworldSync::Peers.all.unshift(friend)
MGQ_MpBattlesCoop.ended

# Somebody joins.
BattleManager.setup(40, true, false)
bid = MGQ_MpBattlesSync.battle_id
join = MGQ_MpBattlesSync::Wire.line(["7,8,9", [[50, 5], [60, 6], [70, 7]], 8])
MGQ_MpBattlesSync.take(stranger, { "battle" => "join", "bid" => bid, :payload => join })
MGQ_MpBattlesSync.take(friend, { "battle" => "join", "bid" => "other", :payload => join })
$sent.clear
$frames = 0
$inject = lambda { |frame| MGQ_MpBattlesSync.take(friend, { "battle" => "join", "bid" => bid, :payload => join }) if frame == 3 }
$sync_level = 30
$synced = []
check("the host gathers who joins", MGQ_MpBattlesCoop.gather(scene), nil)
$inject = nil
roster = $sent.map { |seat, text| fields_of(text) }.find { |f| f["battle"] == "roster" }
enemies, players, level = MGQ_MpBattlesSync::Wire.parse(roster[:payload])
check("and sends the party and the troop to everyone", [enemies, players.map { |p| p[0, 3] }], [[[31, 0, 0, 0], [32, 0, 0, 0]], [[0, "Me", "1,2,3"], [2, "Friend", "7,8,9"]]])
check("with each player's order and shares, the Backline's as far as their characters go", players.map { |p| p[4, 4] }, [[8, [0, 1, 2], 2, 1], [8, [0, 1, 2], 2, 1]])
party = $game_party.battle_members
check("and the battle's level, which the host's level sync starts with", [level, $sync_began], [30, 30])
check("every character of the party is offered to the level sync", $synced.map(&:name), party.map(&:name))
check("two players bring two each, the host's own first", party.map(&:name), ["Actor1", "Actor2", "Actor7 (Friend)", "Actor8 (Friend)"])
check("the others' characters keep their HP and MP", party[2, 2].map { |a| [a.hp, a.mp, a.mp_seat] }, [[50, 5, 2], [60, 6, 2]])
check("the status windows show the party", $refreshed, true)
check("the others' characters start the battle, which the game does only for its own", party[2, 2].map(&:turn_hit_damage_count), [0, 0])
party[2].turn_hit_damage_count = 3
party[2].on_turn_start
check("and each turn", party[2].turn_hit_damage_count, 0)
check("strangers and wrong battles are not heard", MGQ_MpBattlesSync.seats, [2])

# Another mod adds an enemy mid-battle: the host tells the guest the troop once, before its stream.
recorder = MGQ_MpBattlesSync::Recorder
recorder.start(:link)
$sent.clear
recorder.event("turn", 2)
recorder.flush
check("an unchanged troop is never told again", $sent.map { |_, text| fields_of(text)["battle"] }, ["events"])
$game_troop.members.push(Game_Enemy.new(2, 33))
$sent.clear
recorder.event("turn", 2)
recorder.flush
sent_troop = $sent.map { |seat, text| [seat, fields_of(text)] }
check("a troop that grew is told to the guest before the send", sent_troop.map { |seat, f| [seat, f["battle"]] }, [[2, "coop_troop"], [2, "events"]])
check("with every enemy", MGQ_MpBattlesSync::Wire.parse(sent_troop[0][1][:payload])[0].map(&:first), [31, 32, 33])
$sent.clear
MGQ_MpBattlesCoop::Mode.settle(scene)
check("and not again as the command phase opens", $sent.map { |_, text| fields_of(text)["battle"] }, [])
$game_troop.members.push(Game_Enemy.new(3, 34))
troop_entries = MGQ_MpBattlesHotjoin.method(:late_entries)
MGQ_MpBattlesHotjoin.define_singleton_method(:late_entries) { raise "an enemy this game cannot read" }
recorder.event("turn", 2)
recorder.flush
MGQ_MpBattlesHotjoin.define_singleton_method(:late_entries, troop_entries)
$sent.clear
recorder.event("turn", 2)
recorder.flush
check("a troop whose telling failed is told before the next send", $sent.map { |_, text| fields_of(text)["battle"] }, ["coop_troop", "events"])
$game_troop.members.pop(2)
recorder.stop

# Commands.
party[2].make_actions
check("the host's computer chooses nothing for a guest's character while it waits for the guest", party[2].actions.map(&:item), [nil])
commands = MGQ_MpBattlesSync::Wire.line([[[], [], [["skill", 12, 0]], [["item", 3, 1]]]])
MGQ_MpBattlesSync::Commands.apply(commands, 2)
check("a guest's commands go to their characters", [party[2].actions.map(&:item), party[3].actions.map(&:item)], [[[:skill, 12]], [[:item, 3]]])
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[[["skill", 99, 0]], [], nil, nil]]), 2)
check("never to the host's own", party[0].actions, [])
check("a character the guest names no commands for keeps its own", [party[2].actions.map(&:item), party[3].actions.map(&:item)], [[[:skill, 12]], [[:item, 3]]])
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[[], [], [["skill", KNOWN_SKILLS, 0]], [["item", FIELD_ITEMS, 0]]]]), 2)
check("a skill the character lacks and an item no battle allows are left out", [party[2].actions.map(&:item), party[3].actions.map(&:item)], [[[:skill, 12]], [[:item, 3]]])
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[[], [], [["skill", 199, 0]], [["skill", -1, 0]]]]), 2)
check("a skill of no skill type is taken, an id below the database is not", [party[2].actions.map(&:item), party[3].actions.map(&:item)], [[[:skill, 199]], [[:item, 3]]])
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[nil, nil, [["skill", 5, 0], ["skill", 6, 0]], nil]]), 2)
check("a guest's commands go no further than the actions the host gave the character", party[2].actions.map(&:item), [[:skill, 5]])
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[nil, nil, [], nil]]), 2)
check("and an empty list, as after a failed escape, takes its actions away", [party[2].actions, party[3].actions.map(&:item)], [[], [[:item, 3]]])
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

# A guest.
$my_seat = 2
$sent.clear
$setup.clear
host = MGQ_MpOverworldSync::Peers::Peer.new(0, { "id" => "id-host", "name" => "Host", "map" => "5", "scene" => "map" }, nil, true)
MGQ_MpOverworldSync::Peers.all.push(host)
message = { "coop" => "invite", "party" => "p1", "bid" => "b9", "troop" => "40", "escape" => "1", "lose" => "0", "seats" => "2,3", "map" => "5" }
$scene_now = Scene_Map.new
MGQ_MpBattlesCoop.take(host, message.merge("seats" => "3"))
MGQ_MpBattlesCoop.on_map
check("an invite for others is not taken", $setup, [])
MGQ_MpBattlesCoop.take(host, message)
$game_map.interpreter.busy = true
MGQ_MpBattlesCoop.on_map
check("a busy player joins once free", $setup, [])
$game_map.interpreter.busy = false
MGQ_MpBattlesCoop.on_map
check("then the same battle starts as guest", [$setup, $called, MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.player, MGQ_MpBattlesSync.seats, MGQ_MpBattles.kind, $cleared], [[[40, true, false]], Scene_Battle, :guest, "Host", [0], :coop, true])
check("its own setup invites nobody", $sent.select { |_, t| t.include?("coop=invite") }, [])
$scene_now = scene

$sent.clear
$frames = 0
roster_body = MGQ_MpBattlesSync::Wire.line([[[31, 0, 0, 0], [32, 0, 0, 0]], [[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3", [[100, 10]] * 3, 8, [0, 1, 2], 2, 1]], 25])
$inject = lambda { |frame| MGQ_MpBattlesSync.take(host, { "battle" => "roster", "bid" => "b9", :payload => roster_body }) if frame == 2 }
own_enemies = $game_troop.members.dup
check("the guest joins", MGQ_MpBattlesCoop.join(scene), nil)
$inject = nil
check("a guest whose troop is the host's keeps its own enemies", $game_troop.members.zip(own_enemies).all? { |now, before| now.equal?(before) }, true)
sent_join = $sent.map { |_, text| fields_of(text) }.find { |f| f["battle"] == "join" }
check("with the squad two players bring, and its places", MGQ_MpBattlesSync::Wire.parse(sent_join[:payload]), ["1,2,3", [[100, 10], [100, 10], [100, 10]], 8])
guest_party = $game_party.battle_members
check("and fights in the host's order, its own characters as they are", guest_party.map(&:name), ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor2"])
check("its party, as it runs away or is defeated, is named after its own characters", $game_party.name, "Actor1's party")
check("at the level the host sent", $sync_began, 25)
check("the guest's commands are only for its own, none named for the others'", MGQ_MpBattlesSync::Wire.parse(MGQ_MpBattlesSync::Commands.build)[0].map { |list| list && list.size }, [nil, nil, 0, 0])
guest_party[2].actions = [Game_Action.new(guest_party[2]).tap { |a| a.set_skill(5); a.target_index = 0; a.item = RPG::Skill.new; def (a.item).id; 5; end }]
check("which it sends by the party's places", MGQ_MpBattlesSync::Wire.parse(MGQ_MpBattlesSync::Commands.build)[0][2], [["skill", 5, 0]])
check("with the order of its own places", MGQ_MpBattlesSync::Wire.parse(MGQ_MpBattlesSync::Commands.build)[1], [0, 1, 2])
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
check("a guest whose troop differs fights the host's enemies, in the host's places", rebuilt.map { |e| [e.index, e.enemy_id, e.screen_x, e.screen_y, e.hidden?] },
      [[0, 31, 100, 300, false], [1, 31, 200, 300, false], [2, 32, 300, 300, false], [3, 32, 400, 300, true]])
check("named apart as the game names a troop's enemies", rebuilt.map(&:name), ["Enemy31 A", "Enemy31 B", "Enemy32 A", "Enemy32"])
check("and drawn anew", troop_scene.instance_variable_get(:@spriteset).enemies, rebuilt.reverse)
$game_troop.members = own_enemies
MGQ_MpBattlesCoop.take_troop(troop_scene, [[31, 0, 0, 0], [500, 0, 0, 0]])
check("a host's enemy this game lacks keeps the guest's own troop", $game_troop.members.equal?(own_enemies), true)

# A player with their window in the background.
friend.state["scene"] = "away"
check("a player whose window is in the background is invited too", MGQ_MpBattlesCoop.candidates.map(&:seat).include?(2), true)
friend.state["scene"] = "menu"
busy.state["scene"] = "menu"
host.state["scene"] = "battle"
$log.clear
$game_map.map_id = 5
$my_seat = 0
BattleManager.setup(41)
check("nobody to invite says why", $log.last.to_s.start_with?("co-op battle: nobody to invite on map 5: Friend on map 5 (menu), Busy on map 5 (menu)"), true)

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
BattleManager.setup(50)
bid3 = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesSync.take(g1, { "battle" => "join", "bid" => bid3, :payload => MGQ_MpBattlesSync::Wire.line(["7,8,9", [[50, 5], [60, 6], [65, 6]], 8]) })
MGQ_MpBattlesSync.take(g2, { "battle" => "join", "bid" => bid3, :payload => MGQ_MpBattlesSync::Wire.line(["10,11", [[70, 7], [80, 8]], 8]) })
$frames = 0
$sent.clear
MGQ_MpBattlesCoop.gather(scene)
three = $game_party.battle_members
check("of three players the leader brings two, the others one each", three.map(&:name), ["Actor1", "Actor2", "Actor7 (Friend)", "Actor10 (Other)"])
roster3 = $sent.map { |_, text| fields_of(text) }.find { |f| f["battle"] == "roster" }
check("the roster carries everyone's squad for two players", MGQ_MpBattlesSync::Wire.parse(roster3[:payload])[1].map { |p| p[2] }, ["1,2,3", "7,8,9", "10,11"])
three[2].hp = 12

$notices = []
MGQ_MpOverworldSync::Peers.all.concat([g1, g2])
MGQ_MpBattlesSync.take(g2, { "battle" => "leave", "bid" => bid3, :payload => "" })
check("a player who leaves is told of at once, before the next command phase", [$notices, $game_party.battle_members.size], [["Other left the battle."], 4])
MGQ_MpBattlesSync.take(g2, { "battle" => "leave", "bid" => bid3, :payload => "" })
MGQ_MpBattlesSync::Departures.gone(g2)
check("once per battle", $notices, ["Other left the battle."])
MGQ_MpBattlesSync::Departures.gone(MGQ_MpOverworldSync::Peers::Peer.new(9, { "name" => "Stranger" }, nil, false))
check("a player outside the battle who leaves the world is not", $notices.size, 1)
MGQ_MpOverworldSync::Peers.all.clear

MGQ_MpBattlesSync.guest_left(3)
$sent.clear
MGQ_MpBattlesCoop.settle(scene)
two = $game_party.battle_members
check("when one gets away, the others bring two each", two.map(&:name), ["Actor1", "Actor2", "Actor7 (Friend)", "Actor8 (Friend)"])
check("characters who stay keep what the battle did to them", [two[2].equal?(three[2]), two[2].hp], [true, 12])
change = $sent.map { |_, text| fields_of(text) }.find { |f| f["battle"] == "coop_party" }
check("the guests hear of the new party", MGQ_MpBattlesSync::Wire.parse(change[:payload])[0].map { |p| p[0] }, [0, 2])
$sent.clear
MGQ_MpBattlesCoop.settle(scene)
check("nothing more while nobody else leaves", $sent.size, 0)

MGQ_MpBattlesSync.guest_left(2)
MGQ_MpBattlesCoop.settle(scene)
check("alone, the host fights on with their own full team", [MGQ_MpBattlesCoop.active?, $game_party.battle_members], [false, mine])
check("as a battle of their own", [MGQ_MpBattlesSync.role, MGQ_MpBattles.running?, BattleManager.can_giveup?], [nil, false, true])

# A guest takes the new party in order, and takes over when the host gets away.
$my_seat = 2
MGQ_MpBattlesSync.join_world(:guest, "g7", [0], "Host")
MGQ_MpBattlesSync.battle_started
MGQ_MpBattles.begin(:coop)
MGQ_MpBattlesCoop.form(scene, [[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3", [[100, 10]] * 3, 8, [0, 1, 2], 1, 1], [3, "Other", "10,11", [], 8, [0, 1], 1, 1]])
check("the guest's party of three", $game_party.battle_members.map(&:name), ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor10 (Other)"])
MGQ_MpBattlesSync::Channel.receive(0, "coop_party", MGQ_MpBattlesSync::Wire.line([[[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3", [], 8, [0, 1, 2], 2, 1]]]))
MGQ_MpBattlesSync::Channel.receive(0, "events", "")
MGQ_MpBattlesSync::Playback.reset
MGQ_MpBattlesSync::Playback.next_event(scene)
check("a new party is taken before the next send", $game_party.battle_members.map(&:name), ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor2"])
$game_party.battle_members[0].actions = [:hosts]
$game_party.battle_members[2].actions = [:chosen]
$chat = []
$commands_phase = false
$actor_cleared = false
$troop_actions = 0
$turn_ends = 0
choices = ["choose_again", [3]], ["choose_again", [2]]
MGQ_MpBattlesSync::Channel.receive(0, "events", choices.map { |event| MGQ_MpBattlesSync::Wire.line(event) }.join("\n"))
MGQ_MpBattlesSync::Live.play_until_commands(scene)
check("a guest the host names chooses again within the same command phase", [$commands_phase, $actor_cleared, $turn_ends, $troop_actions], [true, true, 0, 0])
check("only its own characters' commands start anew", [$game_party.battle_members[2].actions.map(&:item), $game_party.battle_members[0].actions], [[nil], [:hosts]])
check("told why, once: the host's word for another player passes by", $chat, ["A character you chose a command for left the Frontline. Choose your commands again."])

scene.changing = true
$sent.clear
MGQ_MpBattlesSync::Live.escaped(scene)
check("a guest who got away tells the host", $sent.map { |_, text| fields_of(text)["battle"] }, ["leave"])
scene.changing = false
$sent.clear
MGQ_MpBattlesSync::Live.escaped(scene)
check("one whose escape failed stays", $sent.size, 0)
check("in co-op every player tries to escape as in any battle", MGQ_MpBattlesSync::Live.escape_leaves?, false)

$turn_ends = 0
$commands_phase = false
$aborted = false
MGQ_MpBattlesSync::Live.guest_end("process_abort", scene)
check("when the host gets away, the guest fights on alone", [MGQ_MpBattlesCoop.active?, $game_party.battle_members, MGQ_MpBattlesSync.role, MGQ_MpBattles.running?], [false, mine, nil, false])
check("from a new command phase", [$turn_ends, $commands_phase, $aborted], [1, true, false])

# The defeat scene of a lost battle, which the guest's own battle never picks.
class Game_Temp; attr_accessor :lose_event_id, :lose_event_enemy_id; end
class Game_Enemy; def lose_event_id; 6000 + @enemy_id; end; def id; @enemy_id; end; end
known_events = $data_common_events
$data_common_events = []
$data_common_events[6040] = :scene
$game_temp.lose_event_id = nil
MGQ_MpBattlesSync::Live.take_defeat_scene(["end", "process_defeat", 6040, 40])
check("the guest of a lost battle takes the host's defeat scene", [$game_temp.lose_event_id, $game_temp.lose_event_enemy_id], [6040, 40])
$data_common_events[6031] = $data_common_events[6032] = :scene
MGQ_MpBattlesSync::Live.take_defeat_scene(["end", "process_defeat", 9999, 40])
check("or one of its own enemies when this game lacks the host's", [6031, 6032].include?($game_temp.lose_event_id) && $game_temp.lose_event_enemy_id == $game_temp.lose_event_id - 6000, true)
$game_temp.lose_event_id = nil
MGQ_MpBattlesSync::Live.take_defeat_scene(["end", "process_defeat"])
check("as when an older host names none", [6031, 6032].include?($game_temp.lose_event_id), true)
$data_common_events = known_events

# Swaps with the Backline: the host with five characters, a friend with four.
$my_seat = 0
MGQ_MpOverworldSync::Peers.all.clear
mate = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "id-friend", "name" => "Friend", "map" => "5", "scene" => "map" }, nil, true)
MGQ_MpOverworldSync::Peers.all.push(mate)
five = (1..5).map { |id| Game_Actor.new(id) }
$game_party.own = five.dup
BattleManager.setup(60)
MGQ_MpBattlesSync.take(mate, { "battle" => "join", "bid" => MGQ_MpBattlesSync.battle_id, :payload => MGQ_MpBattlesSync::Wire.line(["7,8,9,10", [[50, 5]] * 4, 8]) })
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
$sent.clear
MGQ_MpBattlesCoop.share_order
told = $sent.map { |_, text| fields_of(text) }.find { |f| f["battle"] == "coop_party" }
check("the host tells the guests the new order before the turn", MGQ_MpBattlesSync::Wire.parse(told[:payload])[0].map { |p| p[5] }, [[0, 3, 2, 1], [0, 1, 2, 3]])
$sent.clear
MGQ_MpBattlesCoop.share_order
check("only once", $sent.size, 0)
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[[], [], [], [["skill", 12, 0]]], [3, 1, 2, 0]]), 2)
swapped = $game_party.battle_members
check("a guest's commands bring their swap first", swapped.map(&:name), ["Actor1", "Actor4", "Actor10 (Friend)", "Actor8 (Friend)"])
check("so their commands reach the character they see", swapped[3].actions.map(&:item), [[:skill, 12]])
check("the character swapped out leaves the party", $game_party.battle_members.include?(friend_front), false)
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[[], [], [], []], [0, 1, 2, 3]]), 2)
check("and comes back as the battle left it", $game_party.battle_members[2].equal?(friend_front), true)
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[[], [], [], []], [0, 0, 1, 2]]), 2)
check("a broken order puts the guest's characters back in theirs", MGQ_MpBattlesCoop.instance_variable_get(:@players).find { |p| p[0] == 2 }[5], [0, 1, 2, 3])

# Commands for one character of the party, which another player's swap takes away.
Target = Struct.new(:friend, :one, :user) do
  def for_friend?; friend; end
  def for_one?; one; end
  def for_user?; user; end
end
RAISE_SKILL = 141
RAISE = Target.new(true, true, false)
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
MGQ_MpBattlesSync::Channel.receive(2, "commands", MGQ_MpBattlesSync::Wire.line([[[], [], [], [["skill", 12, 0]]], [3, 1, 2, 0]]))
check("the host whose command was for a character a guest swapped out chooses again", [live.host_guests_commands(scene), $commands_phase, $actor_cleared], [false, true, true])
check("only the host's own commands start anew; the enemies keep theirs", [own[0].actions.map(&:item), $troop_actions], [[nil], 0])
check("the guest's commands were given as they came, and stay", $game_party.battle_members[3].actions.map(&:item), [[:skill, 12]])
check("the host is told why", $chat, ["A character you chose a command for left the Frontline. Choose your commands again."])
check("the log names who lost a target and who chooses again", $log.last.to_s.end_with?("commands of seats 0 lost their target to a swap, choosing again: 0"), true)
own = $game_party.battle_members
own[0].actions = [command(own[0], RAISE, 2)]
check("chosen again, the turn goes on without waiting for the guest again", [live.host_guests_commands(scene), own[3].actions.map(&:item)], [true, [[:skill, 12]]])

live.close_phase
live.open_phase(scene)
MGQ_MpBattlesCoop.swap(scene, own[1], 0)
own = $game_party.battle_members
own[1].actions = [command(own[1], RAISE, 1)]
$chat = []
$commands_phase = false
$frames = 0
MGQ_MpBattlesSync::Channel.receive(2, "commands", MGQ_MpBattlesSync::Wire.line([[[], [], [["skill", RAISE_SKILL, 1]], []], [3, 1, 2, 0]]))
interim = nil
$inject = lambda do |frame|
  interim = $game_party.battle_members[2].actions.dup if frame == 1
  MGQ_MpBattlesSync::Channel.receive(2, "commands", MGQ_MpBattlesSync::Wire.line([[[], [], [["skill", 12, 0]], []], [3, 1, 2, 0]])) if frame == 2
end
check("a guest whose command was for a character the host swapped out chooses again, the host waiting", live.host_guests_commands(scene), true)
$inject = nil
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

# A member's battle: the party's leader on the map is asked to lead it.
$leader = mate
$game_party.own = five.map { |actor| actor.tap { |a| a.hp = 100 } }
$sent.clear
BattleManager.setup(62, false, true)
ask = $sent.map { |seat, text| [seat, fields_of(text)] }.find { |_, f| f["coop"] == "lead" }
check("a member asks the party's leader to lead the battle", ask && [ask[0], ask[1]["troop"], ask[1]["escape"], ask[1]["lose"], ask[1]["map"]], [2, "62", "0", "1", "5"])
check("and joins it as a guest", [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.battle_id, MGQ_MpBattlesSync.seats, MGQ_MpBattles.kind], [:guest, ask[1]["bid"], [2], :coop])
MGQ_MpBattlesCoop.take(mate, { "coop" => "invite", "bid" => "other", "seats" => "0" })
MGQ_MpBattlesCoop.take(mate, { "coop" => "invite", "bid" => ask[1]["bid"], "seats" => "0,3", "map" => "5" })
$frames = 0
MGQ_MpBattlesCoop.await_leader(scene)
check("the leader's invite for the battle is the answer", [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.player, $frames], [:guest, "Friend", 0])
check("no other invite waits on the map", MGQ_MpBattlesCoop.instance_variable_get(:@invite), nil)
MGQ_MpBattlesCoop.ended

# The leader refuses: the member hosts, and the leader's characters still come first.
$sent.clear
BattleManager.setup(61)
asked = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesCoop.take(mate, { "coop" => "no_lead", "bid" => asked })
$sent.clear
MGQ_MpBattlesCoop.await_leader(scene)
invite = $sent.map { |seat, text| [seat, fields_of(text)] }.find { |_, f| f["coop"] == "invite" }
check("a leader who refuses leaves the battle to the member, who hosts it", [MGQ_MpBattlesSync.role, invite && invite[1]["troop"], MGQ_MpBattlesSync.battle_id == asked], [:host, "61", false])
check("the log names the leader's answer and the invite sent", [$log.grep(/answered for battle #{asked}: refused/).size, $log.grep(/sent invite to the party: bid=/).size > 0], [1, true])
MGQ_MpBattlesCoop.take(mate, { "coop" => "invite", "bid" => asked, "seats" => "0", "map" => "5" })
check("and a late invite for the battle it asked for is dropped", MGQ_MpBattlesCoop.instance_variable_get(:@invite), nil)
MGQ_MpBattlesSync.take(mate, { "battle" => "join", "bid" => MGQ_MpBattlesSync.battle_id, :payload => MGQ_MpBattlesSync::Wire.line(["7,8,9,10", [[50, 5]] * 4, 8]) })
$frames = 0
MGQ_MpBattlesCoop.gather(scene)
check("the party's leader leads the battle's party too", $game_party.battle_members.map(&:name).first, "Actor7 (Friend)")
check("the log names who joined, the roster and each rebuilt character", [$log.grep(/gathered battle .*Friend \(seat 2\) joined/).size > 0, $log.grep(/party of 2 players: Friend \(seat 2\): Frontline/).size > 0,
                                                                           $log.grep(/rebuilt Actor7 \(Friend\) \(7\) of seat 2, place 0/).size > 0], [true, true, true])
MGQ_MpBattlesCoop.ended

# A silent leader: the member hosts once the wait runs out.
BattleManager.setup(63)
$frames = 0
MGQ_MpBattlesCoop.await_leader(scene)
check("a silent leader leaves the battle to the member after the wait", [MGQ_MpBattlesSync.role, $frames], [:host, MGQ_MpBattlesCoop::LEADER_FRAMES - 1])
MGQ_MpBattlesCoop.ended

# The leader's side: leading a member's battle on the map.
$leader = :me
mate.state["scene"] = "battle"
$setup.clear
$sent.clear
$called = nil
MGQ_MpBattlesCoop.take(mate, { "coop" => "lead", "bid" => "m1", "troop" => "64", "escape" => "0", "lose" => "1", "map" => "5" })
MGQ_MpBattlesCoop.on_map
invite = $sent.map { |seat, text| [seat, fields_of(text)] }.find { |_, f| f["coop"] == "invite" }
check("the leader starts the member's battle as its host", [$setup, $called, MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.battle_id], [[[64, false, true]], Scene_Battle, :host, "m1"])
check("and invites the member, who is in that battle already", invite && invite[1]["seats"], "2")
$frames = 0
check("a member who asked and did not join calls the battle off", MGQ_MpBattlesCoop.gather(scene), :broken)
check("for everyone in it", $sent.map { |_, text| fields_of(text)["battle"] }.include?("broken"), true)
MGQ_MpBattlesCoop.ended
$sent.clear
MGQ_MpBattlesCoop.take(mate, { "coop" => "lead", "bid" => "m2", "troop" => "64", "map" => "9" })
MGQ_MpBattlesCoop.on_map
check("a leader on another map refuses", $sent.map { |seat, text| [seat, fields_of(text)["coop"], fields_of(text)["bid"]] }, [[2, "no_lead", "m2"]])
$sent.clear
MGQ_MpBattlesCoop.take(mate, { "coop" => "lead", "bid" => "m3", "troop" => "64", "map" => "5" })
MGQ_MpBattlesCoop.instance_variable_get(:@request)[:at] -= 60
MGQ_MpBattlesCoop.on_map
check("a request that waited through a battle of the leader's own is refused", [$sent.map { |_, text| fields_of(text)["coop"] }, MGQ_MpBattlesSync.role], [["no_lead"], nil])
mate.state["scene"] = "map"

# Invites a player cannot take in time.
invite_of = lambda { |bid| { "coop" => "invite", "bid" => bid, "troop" => "40", "seats" => "0", "map" => "5" } }
$sent.clear
MGQ_MpBattlesCoop.take(mate, invite_of.call("i1"))
check("an invite during a battle of the player's own is turned down at once",
      [$sent.map { |seat, text| [seat, fields_of(text)["battle"], fields_of(text)["bid"]] }, MGQ_MpBattlesCoop.instance_variable_get(:@invite)], [[[2, "decline", "i1"]], nil])
$scene_now = Scene_Map.new
$sent.clear
MGQ_MpBattlesCoop.take(mate, invite_of.call("i2"))
MGQ_MpBattlesCoop.instance_variable_get(:@invite)[:at] -= 60
MGQ_MpBattlesCoop.on_map
check("an invite that waited past three seconds is turned down, not joined", [$sent.map { |_, text| fields_of(text)["battle"] }, MGQ_MpBattlesSync.role], [["decline"], nil])
check("and the log says why", $log.grep(/declined Friend \(seat 2\)'s invite to battle i2: the player stayed busy for 3 s/).size, 1)

# A random encounter waits for the party members on the map who are busy.
$setup.clear
$sent.clear
$called = nil
mate.state["scene"] = "menu"
map = Scene_Map.new
$encounter_troop = 70
check("an encounter with a member in a menu on the map waits", [$game_player.encounter, MGQ_MpBattlesCoop.holding?, $setup], [false, true, [[70, true, false]]])
check("and tells that member, and the whole party that the members on the map stand still", $sent.map { |seat, text| [seat, fields_of(text)["coop"], fields_of(text)["map"]] },
      [[2, "soon", "5"], [-1, "freeze", "5"]])
map.update_call_menu
check("the player stands still and opens no menu meanwhile", [$game_player.movable?, map.menu_calling], [false, false])
check("nor meets another encounter", [($encounter_troop = 71) && $game_player.encounter, $setup.size], [false, 1])
$encounter_troop = nil
MGQ_MpBattlesCoop.on_map
check("it waits while the member stays busy", [MGQ_MpBattlesCoop.holding?, $called], [true, nil])
mate.state["scene"] = "map"
$sent.clear
MGQ_MpBattlesCoop.on_map
invite = $sent.map { |seat, text| [seat, fields_of(text)] }.find { |_, f| f["coop"] == "invite" }
check("once the member is back on the map, the battle starts and invites them", [MGQ_MpBattlesCoop.holding?, $called, MGQ_MpBattlesSync.role, invite && invite[1]["troop"]],
      [false, Scene_Battle, :host, "70"])
MGQ_MpBattlesCoop.ended

$called = nil
mate.state["scene"] = "menu"
$encounter_troop = 72
$game_player.encounter
MGQ_MpBattlesCoop::HOLD_FRAMES.times { MGQ_MpBattlesCoop.on_map }
check("after three seconds it starts without a member who stayed busy", [MGQ_MpBattlesCoop.holding?, $called, MGQ_MpBattlesSync.role], [false, Scene_Battle, nil])

$encounter_troop = 73
$game_player.encounter
MGQ_MpBattlesCoop.drop_hold
check("a reset forgets a held encounter", [MGQ_MpBattlesCoop.holding?, $game_player.movable?], [false, true])

mate.state["scene"] = "battle"
$encounter_troop = 74
check("a member in a battle of their own is not waited for", [$game_player.encounter, MGQ_MpBattlesCoop.holding?], [true, false])
MGQ_MpBattlesCoop.ended

# A member on the map stands still while another member's encounter waits for the party.
MGQ_MpBattlesCoop.take(mate, { "coop" => "freeze", "map" => "9" })
check("another map's encounter holds nobody here", $game_player.movable?, true)
MGQ_MpBattlesCoop.take(mate, { "coop" => "freeze", "map" => "5" })
check("a member's encounter on the player's map holds them", $game_player.movable?, false)
MGQ_MpBattlesCoop.decline(mate, invite_of.call("i3"))
check("until they turn its invite down", $game_player.movable?, true)
MGQ_MpBattlesCoop.take(mate, { "coop" => "freeze", "map" => "5" })
MGQ_MpBattlesCoop.instance_variable_set(:@frozen, Time.now - MGQ_MpBattlesCoop::FREEZE_SECONDS)
check("or ten seconds passed", $game_player.movable?, true)
mate.state["scene"] = "map"
$scene_now = scene

# A guest's character takes the host's states, and the game reads its features anew, so a state's
# extra actions, such as Division's, count on the guest too.
$data_states = [nil, :poison, :division]
module CacheActorFeatures; def self.init_actor(actor); ($cleared ||= []) << actor.id; end; end
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
class Game_MpActor; def differences; $differences || []; end; def on_battle_start; end; end
$log.clear
$differences = ["counter 0 (sent 500)"]
MGQ_MpBattlesCoop.check(Game_MpAlly.allocate.tap { |ally| ally.define_singleton_method(:name) { "Actor9 (Mate)" } })
check("a rebuild that differs is logged", $log.last, "co-op battle: Actor9 (Mate) differs: counter 0 (sent 500)")
$differences = nil

# The guest shows the host's messages through the game's message, which names their speaker, and
# lets the game move an earlier message on before a new one starts.
class Game_Message
  attr_accessor :face_name, :face_index, :background, :position
  def has_text?; !$game_message_texts.to_a.empty?; end
end
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
fallen = MGQ_MpBattlesCoop.new_ally(MGQ_MpActors::Builds::Member.new(12), "Mate", 2, 0, [0, 3])
whole = MGQ_MpBattlesCoop.new_ally(MGQ_MpActors::Builds::Member.new(13), "Mate", 2, 1, nil)
check("another player's fallen character is rebuilt fallen", [fallen.hp, fallen.mp, whole.hp], [0, 3, 100])

# Forms a guest's co-op battle with the host at seat 0 and the player's four characters at seat 2,
# two of them on the Backline.
def form_guest_battle(scene, bid)
  $my_seat = 2
  MGQ_MpBattlesSync.join_world(:guest, bid, [0], "Host")
  MGQ_MpBattlesSync.battle_started
  MGQ_MpBattles.begin(:coop)
  MGQ_MpBattlesCoop.own_build
  MGQ_MpBattlesCoop.form(scene, [[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3,4", [[100, 10]] * 4, 8, [0, 1, 2, 3], 2, 2]])
end

# A skill or item that reaches the Backline too.
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

# The end drops the game's Retry, whose snapshot holds synced stats or an older battle.
BattleManager.instance_variable_set(:@retry_data, "the start of the battle")
MGQ_MpBattlesCoop.ended
check("the end of a co-op battle drops the game's Retry", BattleManager.instance_variable_get(:@retry_data), nil)
$counted = []
BattleManager.battle_end(0)
check("outside a co-op battle the battle's end counts as the game does", $counted.size, 4)

# A reset in the middle of a co-op battle.
form_guest_battle(scene, "g31")
MGQ_MpBattlesCoop.instance_variable_set(:@asking, { :seat => 2, :bid => "g31" })
$game_switches = Game_Switches.new
Scene_Title.new.start
check("a reset forgets the co-op party, the rules and the request to the leader",
      [MGQ_MpBattlesCoop.active?, MGQ_MpBattles.running?, $game_party.battle_members.map(&:name), MGQ_MpBattlesCoop.instance_variable_get(:@asking)],
      [false, false, five.first(4).map(&:name), nil])
MGQ_MpBattles.finish
check("and never puts the rules' switches into the save loaded next", $game_switches[86], false)
MGQ_MpBattlesSync.finish

# A guest whose host leaves takes the battle over: one before the host's party came starts it as
# its own, one later sets the counters the start sets and picks a defeat scene.
class Game_Battler; attr_reader :counters_set; def set_counter; @counters_set = true; end; end
$my_seat = 2
MGQ_MpBattlesSync.join_world(:guest, "g32", [0], "Host")
MGQ_MpBattlesSync.battle_started
MGQ_MpBattles.begin(:coop)
$battle_started = false
$turn_ends = 0
$commands_phase = false
MGQ_MpBattlesCoop.take_over(scene)
check("a guest whose host left before the party came starts the battle as its own",
      [$battle_started, $turn_ends, $commands_phase, MGQ_MpBattlesSync.role, MGQ_MpBattles.running?], [true, 0, true, nil, false])
form_guest_battle(scene, "g33")
$battle_started = false
$game_temp.lose_event_id = 0
MGQ_MpBattlesCoop.take_over(scene)
check("one whose host left later goes on with the counters the start sets",
      [$battle_started, $turn_ends, ($game_party.battle_members + $game_troop.members).all?(&:counters_set)], [false, 1, true])
check("and a defeat scene of its enemies", $game_troop.members.map(&:lose_event_id).include?($game_temp.lose_event_id), true)

# A guest the host's party leaves out, since it joined after the host stopped waiting.
$my_seat = 7
MGQ_MpOverworldSync::Peers.all.clear
MGQ_MpOverworldSync::Peers.all.push(mate)
MGQ_MpBattlesSync.join_world(:guest, "late1", [2], "Friend")
MGQ_MpBattlesSync.battle_started
late = MGQ_MpBattlesSync::Wire.line([[[31, 0, 0, 0]], [[2, "Friend", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0]], 0])
$frames = 0
$inject = lambda { |frame| MGQ_MpBattlesSync.take(mate, { "battle" => "roster", "bid" => "late1", :payload => late }) if frame == 2 }
check("a guest the host's party leaves out ends its battle", [MGQ_MpBattlesCoop.join(scene), MGQ_MpBattlesSync.broken?, MGQ_MpBattlesCoop.active?], [:broken, true, false])
$inject = nil
MGQ_MpBattlesSync.finish
MGQ_MpBattlesSync.join_world(:guest, "late2", [2], "Friend")
MGQ_MpBattlesSync.battle_started
$frames = 0
check("so does one whose host's party never comes", [MGQ_MpBattlesCoop.join(scene), $frames], [:broken, MGQ_MpBattlesCoop::ROSTER_FRAMES - 1])
MGQ_MpBattlesSync.finish

# Invites and requests the player cannot take are turned down at once.
$my_seat = 0
pal = MGQ_MpOverworldSync::Peers::Peer.new(3, { "id" => "id-pal", "name" => "Pal", "map" => "5", "scene" => "menu" }, nil, true)
MGQ_MpOverworldSync::Peers.all.push(pal)
$leader = mate
$game_party.own = five.dup
$sent.clear
BattleManager.setup(65)
asked = MGQ_MpBattlesSync.battle_id
$sent.clear
MGQ_MpBattlesCoop.take(pal, { "coop" => "invite", "bid" => "p1", "seats" => "0", "map" => "5" })
check("another member's invite while the player asks the leader is turned down at once",
      $sent.map { |seat, text| [seat, fields_of(text)["battle"], fields_of(text)["bid"]] }, [[3, "decline", "p1"]])
MGQ_MpBattlesCoop.take(mate, { "coop" => "no_lead", "bid" => asked })
MGQ_MpBattlesCoop.await_leader(scene)
$sent.clear
MGQ_MpBattlesCoop.take(mate, { "coop" => "invite", "bid" => asked, "seats" => "0", "map" => "5" })
check("so is the leader's late invite to the battle the player hosts instead",
      $sent.map { |seat, text| [seat, fields_of(text)["battle"], fields_of(text)["bid"]] }, [[2, "decline", asked]])
MGQ_MpBattlesCoop.ended
$leader = :me
$sent.clear
MGQ_MpBattlesCoop.take(mate, { "coop" => "lead", "bid" => "r1", "troop" => "64", "map" => "5" })
MGQ_MpBattlesCoop.take(pal, { "coop" => "lead", "bid" => "r2", "troop" => "64", "map" => "5" })
check("a second request to lead refuses the one that waits",
      [$sent.map { |seat, text| [seat, fields_of(text)["coop"], fields_of(text)["bid"]] }, MGQ_MpBattlesCoop.instance_variable_get(:@request)[:message]["bid"]], [[[2, "no_lead", "r1"]], "r2"])
MGQ_MpBattlesCoop.drop

# A Raid World: every player brings one on the Frontline and two on the Backline.
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

BattleManager.setup(70)
raid_bid = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesSync.take(mate, { "battle" => "join", "bid" => raid_bid, :payload => MGQ_MpBattlesSync::Wire.line(["7,8,9", [[50, 5], [60, 6], [70, 7]], 4]) })
$frames = 0
$sent.clear
MGQ_MpBattlesCoop.gather(scene)
raid_roster = $sent.map { |_, text| fields_of(text) }.find { |f| f["battle"] == "roster" }
check("the roster gives each player one and two", MGQ_MpBattlesSync::Wire.parse(raid_roster[:payload])[1].map { |p| p[6, 2] }, [[1, 2], [1, 2]])
check("the party is each player's first character", $game_party.battle_members.map(&:name), ["Actor1", "Actor7 (Friend)"])
check("the player's Backline their next two", $game_party.bench_members.map(&:name), ["Actor2", "Actor3"])
MGQ_MpBattlesSync.guest_left(2)
MGQ_MpBattlesCoop.settle(scene)
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

# A Raid World's battle takes the free players on the map, party or not.
module MGQ_MpCoop::Party; def self.id; $no_party ? nil : "p1"; end; end
module MGQ_MpTrade; def self.session; $trade_session; end; end

# Reads the messages sent through the map's gate.
#
# @param kind [String] The co-op message's kind.
# @return [Array<Array>] Each message's seat and fields.
def map_sent(kind)
  $sent.map { |seat, text| [seat, fields_of(text)] }.select { |_, f| f["map_coop"] == kind }
end

# Makes another player on map 5.
#
# @param seat [Integer] Their seat.
# @param state [Hash] What their state says besides the map and the scene.
# @param member [Boolean] Whether they are in the player's party.
# @return [MGQ_MpOverworldSync::Peers::Peer] The player.
def raid_peer(seat, state, member = false)
  MGQ_MpOverworldSync::Peers::Peer.new(seat, { "id" => "id-#{seat}", "name" => "P#{seat}", "map" => "5", "scene" => "map", "x" => "0", "y" => "0" }.merge(state), nil, member)
end

$raid = true
$my_seat = 0
$my_since = 200
$game_player.x = 0
$game_player.y = 0
$game_party.own = five.dup
$scene_now = Scene_Map.new
MGQ_MpBattlesCoop.drop
comrade = raid_peer(3, { "x" => "20", "y" => "20" }, true)
near = raid_peer(6, { "x" => "1", "y" => "1" })
middle = raid_peer(7, { "x" => "5", "y" => "0" })
far = raid_peer(8, { "x" => "9", "y" => "9" })
others = [raid_peer(9, { "scene" => "event" }), raid_peer(10, { "scene" => "away", "busy" => "1" }), raid_peer(11, { "busy" => "1" }), raid_peer(12, { "map" => "9" })]
MGQ_MpOverworldSync::Peers.all.clear
MGQ_MpOverworldSync::Peers.all.push(comrade, near, middle, far, *others)
$leader = :me
check("a Raid World's battle takes the party members first, then the nearest to the leader, three players at most",
      MGQ_MpBattlesCoop.raid_candidates.map(&:seat), [3, 6, 7])
$leader = comrade
check("counting from the leader's tile when the leader is on the map", MGQ_MpBattlesCoop.raid_candidates.map(&:seat), [3, 8, 6])
comrade.state["map"] = "9"
check("else from the player's own", MGQ_MpBattlesCoop.raid_candidates.map(&:seat), [6, 7, 8])
comrade.state["map"] = "5"
background = raid_peer(13, { "scene" => "away", "x" => "3", "y" => "0" })
MGQ_MpOverworldSync::Peers.all.push(background)
$leader = :me
check("and a player whose game window is in the background, which keeps running", MGQ_MpBattlesCoop.raid_candidates.map(&:seat), [3, 6, 13])
MGQ_MpOverworldSync::Peers.all.delete(background)
$leader = comrade

$sent.clear
BattleManager.setup(80)
check("a member who starts a battle hosts it, asking no leader", [MGQ_MpBattlesSync.role, $sent.count { |_, t| t.include?("lead") }], [:host, 0])
check("inviting each player it takes through the map's gate", map_sent("invite").map { |seat, f| [seat, f["seats"], f["troop"], f["mmap"]] },
      [[3, "3,8,6", "80", "5"], [8, "3,8,6", "80", "5"], [6, "3,8,6", "80", "5"]])
check("and no one through the party's", $sent.count { |_, t| fields_of(t)["coop"] == "invite" }, 0)
check("holding only them", map_sent("freeze").map(&:first), [3, 8, 6])
$frames = 0
check("nobody answers within the Raid World's ten seconds", [MGQ_MpBattlesCoop.gather(scene), $frames], [nil, MGQ_MpBattlesCoop::RAID_JOIN_FRAMES - 1])
check("the host comes first", MGQ_MpBattlesCoop.arrange([[3, "P3", "1", [], 4], [0, "Me", "1", [], 4]]).map(&:seat), [0, 3])
MGQ_MpBattlesCoop.ended

$no_party = true
check("a battle outside a party may take others in a Raid World", MGQ_MpBattlesCoop.host_possible?, true)
$raid = false
check("but not in a Classic world", MGQ_MpBattlesCoop.host_possible?, false)
$raid = true
$no_party = false

# A guest of a Raid World's battle.
MGQ_MpBattlesSync.join_world(:guest, "rg1", [6], "P6")
MGQ_MpBattlesSync.battle_started
$frames = 0
check("a guest waits longer for the roster than the host for the players",
      [MGQ_MpBattlesCoop.join(scene), $frames], [:broken, MGQ_MpBattlesCoop::RAID_JOIN_FRAMES + MGQ_MpBattlesCoop::ROSTER_MARGIN_FRAMES - 1])
MGQ_MpBattlesSync.finish
invite = { "coop" => "invite", "bid" => "h1", "troop" => "40", "escape" => "1", "lose" => "0", "seats" => "0", "map" => "5" }
MGQ_MpBattlesCoop.take(near, invite)
MGQ_MpBattlesCoop.take(near, { "coop" => "off", "bid" => "h1" })
check("a host who gave the battle up takes its invite back", MGQ_MpBattlesCoop.instance_variable_get(:@invite), nil)
MGQ_MpBattlesSync.join_world(:guest, "h2", [6], "P6")
MGQ_MpBattlesSync.battle_started
MGQ_MpBattlesCoop.take(near, { "coop" => "off", "bid" => "h2" })
check("and breaks it off for a guest who waits for its party", MGQ_MpBattlesSync.broken?, true)
MGQ_MpBattlesSync.finish
$trade_session = Object.new
check("a player who trades tells it", MGQ_MpBattlesCoop.state_fields, { "busy" => 1 })
$sent.clear
MGQ_MpBattlesCoop.take(near, invite)
MGQ_MpBattlesCoop.on_map
check("and turns an invite down", $sent.map { |seat, t| [seat, fields_of(t)["battle"]] }, [[6, "decline"]])
$trade_session = nil
check("a free player tells it too", MGQ_MpBattlesCoop.state_fields, { "busy" => 0 })
$raid = false
check("a Classic world's player tells nothing", MGQ_MpBattlesCoop.state_fields, {})
$raid = true
$sent.clear
MGQ_MpBattlesCoop.take(near, { "coop" => "lead", "bid" => "l1", "troop" => "64", "map" => "5" })
check("a request to lead is refused at once", $sent.map { |seat, t| [seat, fields_of(t)["coop"]] }, [[6, "no_lead"]])

# Two battles starting at the same moment: the player who entered the map first hosts.
rival = raid_peer(13, { "x" => "2", "y" => "2", "since" => "100" })
MGQ_MpOverworldSync::Peers.all.replace([comrade, near, rival])
$leader = :me
rival_invite = { "coop" => "invite", "bid" => "rv1", "troop" => "90", "escape" => "0", "lose" => "1", "seats" => "0,3", "map" => "5" }
$sent.clear
$encounter_troop = 81
$game_player.encounter
own_bid = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesCoop.take(rival, rival_invite.merge("boss" => "1"))
check("a rival who entered the map first is not turned down", $sent.count { |_, t| t.include?("battle=decline") }, 0)
$sent.clear
$frames = 0
$inject = lambda { |frame| MGQ_MpBattlesSync.take(rival, { "battle" => "broken", "bid" => "rv1", :payload => "" }) if frame == 2 }
check("their invite ends the gathering, and the battle starts as their guest", MGQ_MpBattlesSync::Live.host_start(scene), false)
$inject = nil
check("the players the own battle invited hear it is off", map_sent("off").map { |seat, f| [seat, f["bid"]] }, [[3, own_bid], [6, own_bid], [13, own_bid]])
sent_join = $sent.map { |seat, t| [seat, fields_of(t)] }.find { |_, f| f["battle"] == "join" }
check("the player joins the rival's battle", [sent_join[0], sent_join[1]["bid"], MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.seats], [13, "rv1", :guest, [13]])
check("with its troop, escape and lose", [$game_troop.troop_id, MGQ_MpGame.get(BattleManager, :can_escape), MGQ_MpGame.get(BattleManager, :can_lose)], [90, false, true])
check("and its word that it is a boss battle", MGQ_MpBattlesHotjoin.instance_variable_get(:@boss_battle), true)
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish

$my_since = 50
$sent.clear
$encounter_troop = 82
$game_player.encounter
MGQ_MpBattlesCoop.take(rival, rival_invite)
check("a rival who entered the map later is turned down", $sent.map { |seat, t| [seat, fields_of(t)["battle"]] }.select { |_, kind| kind == "decline" }, [[13, "decline"]])
MGQ_MpBattlesCoop.ended
$my_since = 200
$sent.clear
BattleManager.setup(83)
MGQ_MpBattlesCoop.take(rival, rival_invite)
check("an event's battle never yields", $sent.map { |seat, t| [seat, fields_of(t)["battle"]] }.select { |_, kind| kind == "decline" }, [[13, "decline"]])
MGQ_MpBattlesCoop.ended
$sent.clear
$encounter_troop = 84
$game_player.encounter
MGQ_MpBattlesCoop.take(rival, rival_invite.merge("seats" => "0,3,6,7"))
check("nor one to a rival's battle with four players", $sent.map { |seat, t| [seat, fields_of(t)["battle"]] }.select { |_, kind| kind == "decline" }, [[13, "decline"]])
MGQ_MpBattlesCoop.ended

# Reads the battles the player's game turned down.
#
# @return [Array<Array>] Each decline's seat and battle id.
def declines
  $sent.map { |seat, t| [seat, fields_of(t)] }.select { |_, f| f["battle"] == "decline" }.map { |seat, f| [seat, f["bid"]] }
end

# Reads the invite that waits for the player.
#
# @return [String, nil] Its battle's id.
def waiting_bid
  invite = MGQ_MpBattlesCoop.instance_variable_get(:@invite)
  invite && invite[:message]["bid"]
end

$sent.clear
MGQ_MpBattlesCoop.take(rival, rival_invite)
$encounter_troop = 85
$game_player.encounter
check("a rival's invite that waited as the player's encounter began ends its gathering",
      [MGQ_MpBattlesCoop.instance_variable_get(:@rival)[:message]["bid"], waiting_bid, declines], ["rv1", nil, []])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish
rival.state["scene"] = "battle"
MGQ_MpOverworldSync::Peers.all.replace([rival])
MGQ_MpBattlesCoop.take(rival, rival_invite)
$encounter_troop = 86
$game_player.encounter
check("also when the player's battle invites nobody else",
      [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.seats, MGQ_MpBattlesCoop.instance_variable_get(:@rival)[:peer]], [:host, [], rival])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish
$my_since = 50
$sent.clear
MGQ_MpBattlesCoop.take(rival, rival_invite)
$encounter_troop = 87
$game_player.encounter
check("a later player's invite that waited is turned down as the player's battle begins", [declines, waiting_bid], [[[13, "rv1"]], nil])
check("and its host is invited, whose battle gathers too", map_sent("invite").map { |seat, f| [seat, f["seats"], f["enc"]] }, [[13, "13", "1"]])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish
$my_since = 200
rival.state["scene"] = "map"

early = raid_peer(14, { "since" => "60" })
earliest = raid_peer(15, { "since" => "40" })
MGQ_MpOverworldSync::Peers.all.replace([rival, early, earliest])
$sent.clear
MGQ_MpBattlesCoop.take(early, rival_invite.merge("bid" => "e1"))
MGQ_MpBattlesCoop.take(rival, rival_invite)
check("of two waiting invites the one whose host entered the map first stays, the other is turned down", [waiting_bid, declines], ["e1", [[13, "rv1"]]])
$sent.clear
MGQ_MpBattlesCoop.take(earliest, rival_invite.merge("bid" => "e0"))
check("an earlier host's invite takes the place of one that waits, which is turned down", [waiting_bid, declines], ["e0", [[14, "e1"]]])
MGQ_MpBattlesCoop.drop

$encounter_troop = 88
$game_player.encounter
$sent.clear
MGQ_MpBattlesCoop.take(early, rival_invite.merge("bid" => "e1"))
MGQ_MpBattlesCoop.take(rival, rival_invite)
check("a later rival is turned down", [MGQ_MpBattlesCoop.instance_variable_get(:@rival)[:message]["bid"], declines], ["e1", [[13, "rv1"]]])
$sent.clear
MGQ_MpBattlesCoop.take(earliest, rival_invite.merge("bid" => "e0"))
check("an earlier rival replaces the one kept, which is turned down", [MGQ_MpBattlesCoop.instance_variable_get(:@rival)[:message]["bid"], declines], ["e0", [[14, "e1"]]])
MGQ_MpBattlesCoop.take(earliest, { "coop" => "off", "bid" => "e0" })
check("a rival who gave their battle up is forgotten, the player's own goes on", MGQ_MpBattlesCoop.instance_variable_get(:@rival), nil)
def BattleManager.make_escape_ratio; $escape_troop = $game_troop.troop_id; end
MGQ_MpBattlesCoop.adopt_troop(scene, rival_invite)
check("a rival's troop gets its own chance to escape", $escape_troop, 90)
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish

# An event's battle hosts before a random encounter, whoever entered the map first.
$my_since = 50
$encounter_troop = 91
$game_player.encounter
$sent.clear
MGQ_MpBattlesCoop.take(rival, rival_invite.merge("enc" => "0"))
check("a random encounter yields to a later player's event battle", [MGQ_MpBattlesCoop.instance_variable_get(:@rival)[:message]["bid"], declines], ["rv1", []])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish
$my_since = 200
$encounter_troop = 92
$game_player.encounter
MGQ_MpBattlesCoop.take(earliest, rival_invite.merge("bid" => "e0", "enc" => "1"))
$sent.clear
MGQ_MpBattlesCoop.take(rival, rival_invite.merge("enc" => "0"))
check("and an event's battle replaces an earlier rival's random encounter", [MGQ_MpBattlesCoop.instance_variable_get(:@rival)[:message]["bid"], declines], ["rv1", [[15, "e0"]]])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish

# A guest whose host yields follows to the battle it yields to.
$scene_now = scene
b_invite = rival_invite.merge("bid" => "b1", "seats" => "0", "enc" => "1")
a_invite = rival_invite.merge("bid" => "a1", "troop" => "93", "seats" => "0", "enc" => "1")
MGQ_MpBattlesCoop.accept(rival, b_invite)
$sent.clear
MGQ_MpBattlesCoop.take(early, a_invite)
check("a guest keeps the invite of an earlier host its own host yields to", [waiting_bid, declines], ["a1", []])
$frames = 0
$inject = lambda { |frame| MGQ_MpBattlesCoop.take(rival, { "coop" => "off", "bid" => "b1" }) if frame == 2 }
MGQ_MpBattlesCoop.join(scene)
$inject = nil
joins = $sent.map { |seat, t| [seat, fields_of(t)] }.select { |_, f| f["battle"] == "join" }.map { |seat, f| [seat, f["bid"]] }
check("and joins that battle once its host gives up", [joins, MGQ_MpBattlesSync.battle_id, $game_troop.troop_id, waiting_bid], [[[13, "b1"], [14, "a1"]], "a1", 93, nil])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.accept(rival, b_invite.merge("enc" => "0"))
$sent.clear
MGQ_MpBattlesCoop.take(early, a_invite)
check("a guest of an event's battle turns other invites down at once", [waiting_bid, declines], [nil, [[14, "a1"]]])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish
$scene_now = Scene_Map.new

# A battle called off lets the player walk on only when no other battle holds them.
MGQ_MpBattlesCoop.drop
MGQ_MpBattlesCoop.take(rival, { "coop" => "freeze", "map" => "5" })
MGQ_MpBattlesCoop.take(rival, rival_invite)
MGQ_MpBattlesCoop.take(early, { "coop" => "freeze", "map" => "5" })
MGQ_MpBattlesCoop.take(early, { "coop" => "off", "map" => "5" })
check("another host's word that their battle is off keeps the player still for a waiting invite", MGQ_MpBattlesCoop.frozen?, true)
MGQ_MpBattlesCoop.take(rival, { "coop" => "off", "bid" => "rv1" })
check("its own host's lets them walk on", [MGQ_MpBattlesCoop.frozen?, waiting_bid], [false, nil])
MGQ_MpBattlesCoop.drop

# A held encounter lets the players its battle leaves out walk on.
menu_mate = raid_peer(3, { "scene" => "menu", "x" => "9", "y" => "9" }, true)
strangers = [raid_peer(6, { "x" => "1" }), raid_peer(7, { "x" => "2" }), raid_peer(8, { "x" => "3" })]
MGQ_MpOverworldSync::Peers.all.replace([menu_mate, *strangers])
$leader = :me
$sent.clear
$encounter_troop = 89
$game_player.encounter
check("a held encounter freezes the nearest and the busy member", map_sent("freeze").map(&:first), [6, 7, 8, 3])
menu_mate.state["scene"] = "map"
$sent.clear
MGQ_MpBattlesCoop.on_map
check("its battle takes the member first", map_sent("invite").map(&:first), [3, 6, 7])
check("and lets the stranger it leaves out walk on", map_sent("off").map(&:first), [8])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish

$raid = false
$sent.clear
MGQ_MpBattlesCoop.take_map(near, invite)
check("a Classic world takes no co-op message through the map's gate", waiting_bid, nil)
$raid = true
MGQ_MpBattlesCoop.take_map(near, invite)
check("a Raid World does", waiting_bid, "h1")
MGQ_MpBattlesCoop.drop
$raid = false
$scene_now = scene
check("no hook failed", $log.grep(/FAILED/), [])
