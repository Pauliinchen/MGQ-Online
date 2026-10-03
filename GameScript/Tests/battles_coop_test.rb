#----------------------------------------------------------------
#  battles_coop_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-03: Checked that a guest's command the character may not give is left out
#      Paulinchen  2026-10-02: Checked that a player who joined and left the world before the roster does not stop the battle
#                            - Ended the guest's battle through guest_end
#      Paulinchen  2026-10-01: Checked that every player hears at once when another leaves the battle
#                            - Checked that a guest whose troop differs fights the host's enemies
#                            - Checked the squads players bring, the leader first, and swaps with the Backline
#                            - Took the stand-ins from battle_support.rb, which the team duel test shares
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers co-op battles, mp_battles_coop.rbx with mp_battles_sync.rbx, mp_battles.rbx and
# mp_coop_squad.rbx: from the invite to the end of the battle, for the host and for a guest.

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
check("the host gathers who joins", MGQ_MpBattlesCoop.gather(scene), nil)
$inject = nil
roster = $sent.map { |seat, text| fields_of(text) }.find { |f| f["battle"] == "roster" }
enemies, players = MGQ_MpBattlesSync::Wire.parse(roster[:payload])
check("and sends the party and the troop to everyone", [enemies, players.map { |p| p[0, 3] }], [[[31, 0, 0, 0], [32, 0, 0, 0]], [[0, "Me", "1,2,3"], [2, "Friend", "7,8,9"]]])
check("with each player's order and shares, the Backline's as far as their characters go", players.map { |p| p[4, 4] }, [[8, [0, 1, 2], 2, 1], [8, [0, 1, 2], 2, 1]])
party = $game_party.battle_members
check("two players bring two each, the host's own first", party.map(&:name), ["Actor1", "Actor2", "Actor7 (Friend)", "Actor8 (Friend)"])
check("the others' characters keep their HP and MP", party[2, 2].map { |a| [a.hp, a.mp, a.mp_seat] }, [[50, 5, 2], [60, 6, 2]])
check("the status windows show the party", $refreshed, true)
check("strangers and wrong battles are not heard", MGQ_MpBattlesSync.seats, [2])

# Commands.
party[2].make_actions
check("the computer plays a character without commands", party[2].actions, [:auto])
commands = MGQ_MpBattlesSync::Wire.line([[[], [], [["skill", 12, 0]], [["item", 3, 1]]]])
MGQ_MpBattlesSync::Commands.apply(commands, 2)
check("a guest's commands go to their characters", [party[2].actions.map(&:item), party[3].actions.map(&:item)], [[[:skill, 12]], [[:item, 3]]])
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[[["skill", 99, 0]], [], [], []]]), 2)
check("never to the host's own", party[0].actions, [])
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[[], [], [["skill", KNOWN_SKILLS, 0]], [["item", FIELD_ITEMS, 0]]]]), 2)
check("a skill the character lacks and an item no battle allows are left out", [party[2].actions.map(&:item), party[3].actions.map(&:item)], [[[:skill, 12]], [[:item, 3]]])
MGQ_MpBattlesSync::Commands.apply(MGQ_MpBattlesSync::Wire.line([[[], [], [["skill", 199, 0]], [["skill", -1, 0]]]]), 2)
check("a skill of no skill type is taken, an id below the database is not", [party[2].actions.map(&:item), party[3].actions.map(&:item)], [[[:skill, 199]], [[:item, 3]]])
check("the host's own characters are commanded here", [party[0].is_a?(Game_MpAlly), party[2].inputable?], [false, false])

# Playback and escape.
check("a co-op stream's sides stay as they are", [MGQ_MpBattlesSync::Playback.battler("a2"), MGQ_MpBattlesSync::Playback.battler("e1")], [party[2], $game_troop.members[1]])
check("the host escapes as in any battle", MGQ_MpBattlesSync::Live.escape_leaves?, false)

# The end.
$cancelled = false
MGQ_MpBattlesCoop.ended
check("the end gives the party back and ends the rules", [MGQ_MpBattlesCoop.active?, MGQ_MpBattlesSync.role, MGQ_MpBattles.running?, $game_party.battle_members], [false, nil, false, mine])
check("and leaves the world's room open", $cancelled, false)

# A guest.
$my_seat = 2
$sent.clear
$setup.clear
host = MGQ_MpOverworldSync::Peers::Peer.new(0, { "id" => "id-host", "name" => "Host", "map" => "5", "scene" => "map" }, nil, true)
MGQ_MpOverworldSync::Peers.all.push(host)
message = { "coop" => "invite", "party" => "p1", "bid" => "b9", "troop" => "40", "escape" => "1", "lose" => "0", "seats" => "2,3", "map" => "5" }
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

$sent.clear
$frames = 0
roster_body = MGQ_MpBattlesSync::Wire.line([[[31, 0, 0, 0], [32, 0, 0, 0]], [[0, "Host", "4,5", [[80, 8], [90, 9]], 8, [0, 1], 2, 0], [2, "Me", "1,2,3", [[100, 10]] * 3, 8, [0, 1, 2], 2, 1]]])
$inject = lambda { |frame| MGQ_MpBattlesSync.take(host, { "battle" => "roster", "bid" => "b9", :payload => roster_body }) if frame == 2 }
own_enemies = $game_troop.members.dup
check("the guest joins", MGQ_MpBattlesCoop.join(scene), nil)
$inject = nil
check("a guest whose troop is the host's keeps its own enemies", $game_troop.members.zip(own_enemies).all? { |now, before| now.equal?(before) }, true)
sent_join = $sent.map { |_, text| fields_of(text) }.find { |f| f["battle"] == "join" }
check("with the squad two players bring, and its places", MGQ_MpBattlesSync::Wire.parse(sent_join[:payload]), ["1,2,3", [[100, 10], [100, 10], [100, 10]], 8])
guest_party = $game_party.battle_members
check("and fights in the host's order, its own characters as they are", guest_party.map(&:name), ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor2"])
check("the guest's commands are only for its own", MGQ_MpBattlesSync::Wire.parse(MGQ_MpBattlesSync::Commands.build)[0].map(&:size), [0, 0, 0, 0])
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
five[0].hp = 0
five[1].hp = 0
$game_party.battle_members.each { |member| member.hp = 0 }
$game_party.battle_members[1].hp = 100
check("a swap may not leave nobody standing", MGQ_MpBattlesCoop.swap_kills_all?($game_party.battle_members[1], five[1]), true)
MGQ_MpBattlesCoop.ended

# The leader's characters come first, whoever hosts.
$leader = mate
$game_party.own = five.map { |actor| actor.tap { |a| a.hp = 100 } }
BattleManager.setup(61)
MGQ_MpBattlesSync.take(mate, { "battle" => "join", "bid" => MGQ_MpBattlesSync.battle_id, :payload => MGQ_MpBattlesSync::Wire.line(["7,8,9,10", [[50, 5]] * 4, 8]) })
$frames = 0
MGQ_MpBattlesCoop.gather(scene)
check("the party's leader leads the battle's party too", $game_party.battle_members.map(&:name).first, "Actor7 (Friend)")
MGQ_MpBattlesCoop.ended
$leader = :me
