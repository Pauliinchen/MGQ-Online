#----------------------------------------------------------------
#  battles_hotjoin_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Checked that a guest and an encounter taken in fight with the host's enemy rates and get their own back
#                            - Checked that a battle that calls the Library or Config ends nothing
#                            - Checked that a player another request brought along is taken in with their own encounter and ignores the invite it sent, and that an encounter brings along nobody who fights
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# Covers hotjoining in a Raid World, battles_coop_hotjoin.rbx with battles_coop.rbx and
# battles_sync.rbx, and the story's boss troops of battles_raid_bosses.rbx: the state a battle
# tells, the encounter that asks a running battle, the host that takes it in or refuses it, the
# command phase that adds the new players and enemies, and the guests that take the grown troop.

require_relative "battle_support"

sync = MGQ_MpBattlesSync
hotjoin = MGQ_MpBattlesHotjoin
coop = MGQ_MpBattlesCoop
scene = Scene_Battle.new
spriteset = Spriteset_Battle.new
scene.instance_variable_set(:@spriteset, spriteset)

# Stand-ins for what the recorder reads of every battler and of the game's settings.
class Game_System
  attr_reader :conf
  def initialize; @conf = {}; end
end
class Game_Actor
  attr_accessor :tp
  def states; []; end
end
class Game_Enemy
  attr_accessor :hp, :mp, :tp
  def states; []; end
  def actor?; false; end
  def death_state_id; 1; end
end
$data_states = [nil, :death]
class Game_Party; attr_accessor :od_turn, :od_user; end
class Game_Troop; def turn_count; @turn_count.to_i; end; end
module MGQ_MpWorld; def self.raid?; $raid; end; end
module MGQ_MpTrade; def self.session; nil; end; end
# Enemy pictures: those of the enemies named here are as wide as told, the rest unknown.
EnemyData = Struct.new(:battler_name, :battler_hue)
Picture = Struct.new(:width)
module Cache; def self.battler(name, _hue); Picture.new($widths.fetch(name)); end; end
$widths = { "Wide" => 600, "Full" => 640 }
$data_enemies[60] = EnemyData.new("Wide", 0)
$data_enemies[61] = EnemyData.new("Full", 0)
$game_system = Game_System.new
BattleManager.instance_variable_set(:@phase, :turn_end)

# Reads the messages sent through the map's gate.
#
# @param kind [String] The co-op message's kind.
# @return [Array<Array>] Each message's seat and fields.
def map_sent(kind)
  $sent.map { |seat, text| [seat, fields_of(text)] }.select { |_, f| f["map_coop"] == kind }
end

# Reads the battle messages sent.
#
# @param kind [String] The battle message's kind.
# @return [Array<Array>] Each message's seat and fields.
def battle_sent(kind)
  $sent.map { |seat, text| [seat, fields_of(text)] }.select { |_, f| f["battle"] == kind }
end

# Makes another player on map 5.
#
# @param seat [Integer] Their seat.
# @param state [Hash] What their state says besides the map and the scene.
# @return [MGQ_MpOverworldSync::Peers::Peer] The player.
def player(seat, state = {})
  MGQ_MpOverworldSync::Peers::Peer.new(seat, { "id" => "id-#{seat}", "name" => "P#{seat}", "map" => "5", "scene" => "map", "x" => "0", "y" => "0", "since" => "300" }.merge(state), nil, false)
end

# Opens a command phase as the game does: battles_coop_hotjoin.rbx's hook, then the steps of
# battles_sync_live.rbx's, whose hooks need game classes the tests leave out.
#
# @param scene [Scene_Battle] The battle.
def open_phase(scene)
  scene.start_party_command_selection
  return unless MGQ_MpBattlesSync.host?

  MGQ_MpBattlesSync::Live.open_phase(scene)
  MGQ_MpBattlesSync::Recorder.command_phase
end

# Forgets every battle, invite and hotjoin, as after a reset.
def reset
  MGQ_MpBattlesCoop.drop
  MGQ_MpBattlesSync.finish
  MGQ_MpBattles.drop
  $sent.clear
  $frames = 0
  $inject = nil
end

# Sets up the troop of the player's own battle: one enemy 31 in the middle of the screen.
def own_troop
  $game_troop.setup(31)
  $game_troop.members[0].screen_x = 320
  $game_troop.members[0].screen_y = 300
end

# The story's boss troops.
bosses = MGQ_MpRaidBosses
check("a boss troop names its milestone and cap", bosses.at(1507).to_a, ["Great Decision", 65, true])
check("an earlier phase is no last phase", bosses.last_phase?(1506), false)
$game_switches[4] = true
check("Salamander ends on Luka's side with her own troop", bosses.last_phase?(751), true)
$game_switches[4] = false
check("and goes on to Granberia on Alice's", [bosses.last_phase?(751), bosses.last_phase?(752)], [false, true])
check("a random troop is no boss", [bosses.boss?(31), bosses.battle?(31)], [false, false])
$game_switches[22] = true
check("but its battle is one while the game's events say so", bosses.battle?(31), true)
$game_switches[22] = false
check("every milestone's cap rises with the story", bosses::TROOPS.values.map { |row| row[1] }.compact.max, 300)

$my_seat = 0
$my_since = 200
$leader = nil
$raid = true
$game_party.own = [Game_Actor.new(1), Game_Actor.new(2), Game_Actor.new(3)]
$game_map.map_id = 5
$scene_now = Scene_Map.new

# The state of a battle.
check("on the map a Raid World's player tells no battle", hotjoin.state_fields, { "rb" => "", "rbh" => "" })
$scene_now = scene
hotjoin.fight_alone("own1")
check("one who fights alone tells their own", hotjoin.state_fields, { "rb" => "own1", "rbh" => "0" })
sync.join_world(:guest, "g1", [4], "P4")
check("a guest tells the battle and its host", hotjoin.state_fields, { "rb" => "g1", "rbh" => "4" })
$raid = false
check("a Classic world's player tells nothing", hotjoin.state_fields, {})
$raid = true
reset

# An encounter on a map where a battle runs asks its host.
host = player(5, { "scene" => "battle", "rb" => "hb1", "rbh" => "5", "since" => "100" })
guest = player(6, { "scene" => "battle", "rb" => "hb1", "rbh" => "5" })
free = player(7)
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free])
$scene_now = Scene_Map.new
$game_troop.setup(50)
$encounter_troop = 50
$game_player.encounter
hot = map_sent("hot")
check("a random encounter asks the running battle's host instead of hosting",
      hot.map { |seat, f| [seat, f["bid"], f["troop"], f["seats"], f["enemies"]] }, [[5, "hb1", "50", "7", "50:0:0:0"]])
check("and invites nobody itself", map_sent("invite"), [])
check("it waits as that battle's guest", [sync.role, sync.battle_id, sync.seats], [:guest, "hb1", [5]])
check("holding the free player it would have taken", map_sent("freeze").map(&:first), [7])
coop.take(host, { "coop" => "hot_ok", "bid" => "hb1", "escape" => "0", "lose" => "1" })
MGQ_MpGame.set(BattleManager, :preemptive, true)
$scene_now = scene
coop::Mode.before_start(scene)
check("taken in, it joins as a guest with the host's escape and lose and no first strike",
      [sync.role, hotjoin.own_troop?, MGQ_MpGame.get(BattleManager, :can_escape), MGQ_MpGame.get(BattleManager, :can_lose), MGQ_MpGame.get(BattleManager, :preemptive)],
      [:guest, true, false, true, false])
$sent.clear
$inject = lambda { |frame| coop.take(host, { "coop" => "off", "bid" => "hb1" }) if frame == 3 }
check("the host calling it off before the roster starts the encounter on its own", coop.join(scene), :gone)
check("with its own escape and lose back", [MGQ_MpGame.get(BattleManager, :can_escape), MGQ_MpGame.get(BattleManager, :can_lose)], [true, false])
check("having waited for the roster as a late guest", battle_sent("join").map(&:first), [5])
reset

$encounter_troop = 50
$scene_now = Scene_Map.new
$game_player.encounter
coop.take(host, { "coop" => "hot_ok", "bid" => "hb1", "escape" => "1", "lose" => "0" })
$scene_now = scene
coop::Mode.before_start(scene)
$frames = 0
check("a late guest whose roster never comes fights its encounter alone", [coop.join(scene), $frames], [:gone, hotjoin::ROSTER_FRAMES - 1])
reset

$encounter_troop = 50
$scene_now = Scene_Map.new
$game_player.encounter
$sent.clear
coop.take(host, { "coop" => "hot_no", "bid" => "hb1" })
$scene_now = scene
coop::Mode.before_start(scene)
check("refused, the player hosts the encounter", [sync.role, sync.battle_id == "hb1"], [:host, false])
check("inviting the free player", map_sent("invite").map { |seat, f| [seat, f["troop"]] }, [[7, "50"]])
check("telling the host nothing more", map_sent("off"), [])
reset

$encounter_troop = 50
$scene_now = Scene_Map.new
$game_player.encounter
$sent.clear
$scene_now = scene
coop::Mode.before_start(scene)
check("without an answer the host hears it is off", map_sent("off").map { |seat, f| [seat, f["bid"]] }, [[5, "hb1"]])
check("and the player hosts it after #{hotjoin::ANSWER_FRAMES / 60} s", [sync.role, $frames], [:host, hotjoin::ANSWER_FRAMES - 1])
reset

$encounter_troop = 50
$scene_now = Scene_Map.new
$game_player.encounter
coop.take(host, { "coop" => "off", "bid" => "hb1" })
$sent.clear
$scene_now = scene
coop::Mode.before_start(scene)
check("a host whose battle ends before it answers refuses", [sync.role, sync.battle_id == "hb1", map_sent("off")], [:host, false, []])
reset

busy_member = player(9, { "scene" => "menu" })
busy_member.member = true
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free, busy_member])
$scene_now = Scene_Map.new
$encounter_troop = 50
$game_player.encounter
busy_member.state["scene"] = "map"
$sent.clear
coop.on_map
check("a held encounter asks the running battle too", map_sent("hot").map { |seat, f| [seat, f["seats"]] }, [[5, "9,7"]])
check("leaving the players it brings along standing still", map_sent("off"), [])
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free])
reset

$scene_now = Scene_Map.new
BattleManager.setup(52)
check("an event's battle never asks", [map_sent("hot"), sync.role], [[], :host])
reset
$encounter_troop = 29
$game_player.encounter
check("nor does a boss troop", map_sent("hot"), [])
check("whose invite marks it a boss battle", map_sent("invite").map { |seat, f| [seat, f["boss"]] }, [[7, "1"]])
reset

early_host = player(8, { "scene" => "battle", "rb" => "hb2", "rbh" => "8", "since" => "50" })
MGQ_MpOverworldSync::Peers.all.replace([host, guest, early_host])
check("of two running battles it asks the one whose host entered the map first", hotjoin.target_battle, [early_host, "hb2"])
host.state.merge!("scene" => "map", "rb" => "")
MGQ_MpOverworldSync::Peers.all.replace([host, guest])
check("and none whose host left it", hotjoin.target_battle, nil)
host.state.merge!("scene" => "battle", "rb" => "hb1")
$raid = false
$encounter_troop = 50
$game_player.encounter
check("a Classic world's encounter never asks", map_sent("hot"), [])
$raid = true
reset

# The host who fights alone takes an encounter in.
$scene_now = scene
own_troop
hotjoin.fight_alone("own7")
asker = player(8, { "scene" => "battle", "rb" => "own7", "rbh" => "0" })
comrade = player(9)
latecomer = player(10, { "scene" => "battle" })
MGQ_MpOverworldSync::Peers.all.replace([asker, comrade, latecomer])
request = { "coop" => "hot", "bid" => "own7", "troop" => "50", "enemies" => "50:320:300:0", "seats" => "9", "map" => "5" }
coop.take(asker, request)
check("a host takes the encounter in and tells its player the battle's escape and lose",
      map_sent("hot_ok").map { |seat, f| [seat, f["bid"], f["escape"], f["lose"]] }, [[8, "own7", "1", "0"]])
check("and invites the player who comes along to the running battle",
      map_sent("invite").map { |seat, f| [seat, f["bid"], f["troop"], f["seats"], f["hot"]] }, [[9, "own7", "31", "9", "1"]])
check("the battle becomes the host's, not live until someone joins", [sync.role, sync.live?, sync.expected], [:host, false, [8, 9]])
check("its enemies stand beside the troop's, where they hide least",
      hotjoin.instance_variable_get(:@pending)[0][:enemies], [[50, 160, 300, 0]])

$sent.clear
coop.take(latecomer, request.merge("seats" => "11"))
check("two more players would make five: refused", map_sent("hot_no").map(&:first), [10])
$sent.clear
coop.take(latecomer, request.merge("bid" => "other", "seats" => ""))
check("so is a request for another battle", map_sent("hot_no").map(&:first), [10])
$sent.clear
coop.take(latecomer, request.merge("troop" => "29", "seats" => ""))
check("and a boss's encounter", map_sent("hot_no").map(&:first), [10])
$sent.clear
coop.take(latecomer, request.merge("enemies" => "60:320:300:0", "seats" => ""))
check("and enemies with no room on the screen", map_sent("hot_no").map(&:first), [10])
check("a picture as wide as the screen stands in its middle, as the game stacks them", hotjoin.place([[61, 0, 280, 0]]), [[61, 320, 280, 0]])
$game_troop.members.push(Game_Enemy.new(1, 61))
$game_troop.members[1].screen_x = 320
check("and leaves room beside it", hotjoin.place([[50, 0, 300, 0]]), [[50, 480, 300, 0]])
$game_troop.members.pop
$sent.clear
coop.take(latecomer, request.merge("enemies" => Array.new(7) { "50:320:300:0" }.join(";"), "seats" => ""))
check("and more enemies than a troop holds", map_sent("hot_no").map(&:first), [10])

# The command phase turns the battle live and takes in who joined.
$sent.clear
sync.take(asker, { "battle" => "join", "bid" => "own7", :payload => sync::Wire.line(["5,6,7", [[50, 5], [60, 6], [70, 7]], 4]) })
open_phase(scene)
check("the command phase still opens", $commands_phase, true)
check("the battle turned live, the player hosting it", [sync.host?, sync.coop?, MGQ_MpBattles.kind, sync::Recorder.active?], [true, true, :coop, true])
check("with the player who joined as its guest", [sync.guests_in, sync.expected], [[8], [9]])
check("whose first character joins the party", $game_party.battle_members.map(&:name), ["Actor1", "Actor5 (P8)"])
check("and the encounter's enemies the troop", $game_troop.members.map { |enemy| [enemy.enemy_id, enemy.screen_x, enemy.letter] }, [[31, 320, " A"], [50, 160, " A"]])
check("drawn anew", spriteset.enemies.size, 2)
roster = battle_sent("roster")
check("the player who joined gets the roster", roster.map(&:first), [8])
roster_values = sync::Wire.parse(roster[0][1][:payload])
check("with the whole troop and both players", [roster_values[0].map(&:first), roster_values[1].map(&:first)], [[31, 50], [0, 8]])
check("and the battle's names, ready", battle_sent("ready").map(&:first), [8])
check("then the command phase's stream", battle_sent("events").map(&:first), [8])

# A second encounter joins the live battle: the guest hears of the new party and troop.
$sent.clear
third = player(11, { "scene" => "battle", "rb" => "own7", "rbh" => "0" })
MGQ_MpOverworldSync::Peers.all.replace([asker, comrade, latecomer, third])
coop.take(third, request.merge("seats" => "", "enemies" => "51:300:300:0"))
check("a live battle takes another encounter in", map_sent("hot_ok").map(&:first), [11])
sync.take(third, { "battle" => "join", "bid" => "own7", :payload => sync::Wire.line(["8", [[40, 4]], 4]) })
sync.take(comrade, { "battle" => "decline", "bid" => "own7", :payload => "" })
sync.take(asker, { "battle" => "ready", "bid" => "own7", :payload => "" })
sync::Live.close_phase
sync::Recorder.turn_started
$sent.clear
open_phase(scene)
check("the guest gets the new party and troop before the phase's stream",
      $sent.select { |seat, _| seat == 8 }.map { |_, text| fields_of(text)["battle"] }, ["coop_party", "coop_troop", "events"])
check("the new player gets the roster", battle_sent("roster").map(&:first), [11])
check("three players fight, the host first, then by their ids", $game_party.battle_members.map(&:name), ["Actor1", "Actor8 (P11)", "Actor5 (P8)"])
check("the word of the late guest that it is ready is dropped", sync::Channel.pending("ready"), 0)
check("the player who turned the invite down is forgotten", [sync.expected, hotjoin.instance_variable_get(:@pending)], [[], []])

# The guest takes the grown troop.
troop_body = battle_sent("coop_troop").find { |seat, _| seat == 8 }[1][:payload]
reset
sync.join_world(:guest, "own7", [0], "Me")
own_troop
$game_troop.members.push(Game_Enemy.new(1, 50))
coop::Mode.take("coop_troop", scene, troop_body)
check("a guest adds the host's new enemies after its own", $game_troop.members.map { |enemy| [enemy.enemy_id, enemy.screen_x] }, [[31, 320], [50, 0], [51, 480]])
check("drawing them", spriteset.enemies.size, 3)
$game_troop.setup(77)
coop::Mode.take("coop_troop", scene, troop_body)
check("a guest whose troop differs takes the host's whole troop", $game_troop.members.map(&:enemy_id), [31, 50, 51])
reset

# A late guest takes the battle's turn and waits for its next command phase.
hotjoin.note_invite({ "hot" => "1" })
sync.join_world(:guest, "lt1", [5], "P5")
sync.battle_started
MGQ_MpOverworldSync::Peers.all.replace([host])
$inject = lambda do |frame|
  next unless frame == 2

  line = sync::Wire.line([[[31, 320, 300, 0], [50, 160, 300, 1]], [[5, "P5", "1,2,3", [], 4, [0, 1, 2], 1, 2], [0, "Me", "1,2,3", [], 4, [0, 1, 2], 1, 2]], nil, 3])
  sync.take(host, { "battle" => "roster", "bid" => "lt1", :payload => line })
end
check("a late guest takes the roster", coop.join(scene), nil)
check("with the battle's turn", $game_troop.instance_variable_get(:@turn_count), 3)
check("and a hidden enemy hidden", $game_troop.members.map(&:hidden?), [false, true])
reset
hotjoin.note_invite({ "hot" => "1" })
sync.join_world(:guest, "lt3", [5], "P5")
sync.battle_started
$inject = lambda do |frame|
  next unless frame == 2

  line = sync::Wire.line([[[31, 320, 300, 0], [50, 160, 300, hotjoin::FALLEN]], [[5, "P5", "1,2,3", [], 4, [0, 1, 2], 1, 2], [0, "Me", "1,2,3", [], 4, [0, 1, 2], 1, 2]], nil, 3])
  sync.take(host, { "battle" => "roster", "bid" => "lt3", :payload => line })
end
coop.join(scene)
fallen = $game_troop.members[1]
check("a late guest takes a fallen enemy fallen, not hidden, so the host may revive it",
      [fallen.hidden?, fallen.instance_variable_get(:@hp), fallen.instance_variable_get(:@states)], [false, 0, [1]])
reset
own_troop
$game_troop.members.push(Game_Enemy.new(1, 50))
$game_troop.members[1].dead = true
check("the host marks fallen enemies for late guests", hotjoin.late_entries.map(&:last), [0, hotjoin::FALLEN])
reset
hotjoin.note_invite({ "hot" => "1" })
sync.join_world(:guest, "lt2", [5], "P5")
sync.battle_started
$inject = lambda { |frame| coop.take(host, { "coop" => "off", "bid" => "lt2" }) if frame == 2 }
check("an invited late guest whose host calls it off breaks off", [coop.join(scene), sync.broken?], [:broken, true])
reset
invite = { "coop" => "invite", "bid" => "rv9", "troop" => "90", "escape" => "1", "lose" => "0", "seats" => "0", "map" => "5", "hot" => "1" }
$encounter_troop = 85
$scene_now = Scene_Map.new
MGQ_MpOverworldSync::Peers.all.replace([player(13, { "since" => "10" })])
$game_player.encounter
coop.take(MGQ_MpOverworldSync::Peers.all[0], invite)
check("an invite to a running battle is never a rival's", coop.instance_variable_get(:@rival), nil)
reset

# The battle's end tells those taken in who did not join.
$scene_now = scene
own_troop
hotjoin.fight_alone("own8")
MGQ_MpOverworldSync::Peers.all.replace([asker, comrade])
coop.take(asker, request.merge("bid" => "own8"))
$sent.clear
SceneManager.instance_variable_set(:@stack, [Scene_Map.new, scene])
scene.terminate
check("a battle that calls the Library or Config ends nothing", [map_sent("off"), hotjoin.state_fields["rb"], sync.role], [[], "own8", :host])
SceneManager.instance_variable_set(:@stack, [Scene_Map.new])
coop.ended
check("the end of the battle calls joining off", map_sent("off").map { |seat, f| [seat, f["bid"]] }, [[8, "own8"], [9, "own8"]])
check("and forgets the player's own battle", [hotjoin.state_fields, sync.role], [{ "rb" => "", "rbh" => "" }, nil])
reset

own_troop
hotjoin.fight_alone("own9")
coop.take(asker, request.merge("bid" => "own9", "seats" => ""))
coop.take(asker, { "coop" => "off", "bid" => "own9" })
check("a player whose encounter starts on its own after all is forgotten", [hotjoin.instance_variable_get(:@pending), sync.expected], [[], []])
open_phase(scene)
check("and the battle stays the player's own", [sync.role, sync.live?], [nil, false])
reset

# A late guest who stops waiting without the roster tells the host.
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free])
$encounter_troop = 50
$scene_now = Scene_Map.new
$game_player.encounter
coop.take(host, { "coop" => "hot_ok", "bid" => "hb1", "escape" => "0", "lose" => "1" })
$scene_now = scene
coop::Mode.before_start(scene)
$sent.clear
$inject = lambda { |frame| sync.take(host, { "battle" => "broken", "bid" => "hb1", :payload => "" }) if frame == 2 }
check("a late guest whose battle breaks off before the roster stops waiting", coop.join(scene), :broken)
check("telling the host", battle_sent("decline").map(&:first), [5])
check("with its encounter's own escape and lose back", [MGQ_MpGame.get(BattleManager, :can_escape), MGQ_MpGame.get(BattleManager, :can_lose)], [true, false])
reset

# The host forgets a player taken in who left the battle before it took them in.
$scene_now = scene
own_troop
hotjoin.fight_alone("own10")
MGQ_MpOverworldSync::Peers.all.replace([asker, comrade])
coop.take(asker, request.merge("bid" => "own10"))
sync.take(asker, { "battle" => "join", "bid" => "own10", :payload => sync::Wire.line(["5", [[50, 5]], 4]) })
sync.take(asker, { "battle" => "leave", "bid" => "own10", :payload => "" })
hotjoin.expire
pending = hotjoin.instance_variable_get(:@pending)
check("a host forgets a player taken in who left the battle, and their join", [pending.map { |entry| entry[:seats] }, sync::Channel.pending("join")], [[[9]], 0])
check("and counts their encounter's enemies no more", pending[0][:enemies], [])
open_phase(scene)
check("so the battle does not turn live for nobody", sync.live?, false)
$sent.clear
coop.stand_alone(scene)
check("a battle that goes on alone calls joining off for those who did not join", map_sent("off").map { |seat, f| [seat, f["bid"]] }, [[9, "own10"]])
reset

own_troop
hotjoin.fight_alone("own11")
coop.take(asker, request.merge("bid" => "own11", "seats" => ""))
MGQ_MpGame.set(BattleManager, :retry_data, "snapshot")
coop.ended
check("a battle that ends before anyone it took in joined keeps the game's Retry", [MGQ_MpGame.get(BattleManager, :retry_data), sync.role], ["snapshot", nil])
MGQ_MpGame.set(BattleManager, :retry_data, nil)
reset

hotjoin.note_invite({ "boss" => "1" })
own_troop
hotjoin.fight_alone("own12")
$sent.clear
coop.take(asker, request.merge("bid" => "own12", "seats" => ""))
check("a boss battle taken over from its host takes no encounter in", map_sent("hot_no").map(&:first), [8])
reset

# Two encounters that ask at once, each bringing the other's player along.
$scene_now = scene
own_troop
hotjoin.fight_alone("own13")
MGQ_MpOverworldSync::Peers.all.replace([asker, comrade])
coop.take(asker, request.merge("bid" => "own13"))
$sent.clear
coop.take(comrade, request.merge("bid" => "own13", "seats" => "8", "enemies" => "51:320:300:0"))
check("a player another request brought along is taken in with their own encounter", map_sent("hot_ok").map(&:first), [9])
check("which brings nobody, the other request only its own player",
      [hotjoin.instance_variable_get(:@pending).map { |entry| [entry[:requester], entry[:seats]] }, sync.expected.sort], [[[8, [8]], [9, [9]]], [8, 9]])
reset

fighter = player(12, { "rb" => "hb9" })
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free, fighter])
$encounter_troop = 50
$scene_now = Scene_Map.new
$game_player.encounter
check("an encounter brings along nobody whose state tells a battle", map_sent("hot").map { |_, f| f["seats"] }, ["7"])
$sent.clear
coop.take(host, { "coop" => "invite", "bid" => "hb1", "troop" => "31", "escape" => "1", "lose" => "0", "seats" => "0", "map" => "5", "hot" => "1" })
check("a player who asks a running battle ignores its host's invite another request sent", battle_sent("decline"), [])
reset

# The enemy rates: every game of a battle fights with its host's, each player's own back after it.
rates = coop::RATE_VARIABLES
own_rates = lambda { rates.map { |id| $game_variables[id] } }
rates.each { |id| $game_variables[id] = 75 }
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free])
$encounter_troop = 50
$scene_now = Scene_Map.new
$game_player.encounter
coop.take(host, { "coop" => "hot_no", "bid" => "hb1" })
$scene_now = scene
coop::Mode.before_start(scene)
check("a Raid World's invite carries its host's enemy rates", map_sent("invite").map { |seat, f| [seat, f["rates"]] }, [[7, "75,75,75,75,75,75"]])
reset

$scene_now = Scene_Map.new
MGQ_MpOverworldSync::Peers.all.replace([host])
coop.take(host, { "coop" => "invite", "bid" => "rt1", "troop" => "31", "escape" => "1", "lose" => "0", "seats" => "0", "map" => "5", "rates" => "100,100,100,90,100,100" })
coop.on_map
check("a guest fights with its host's enemy rates, such as a special boss's NORMAL on the guest's EASY", [sync.role, own_rates.call], [:guest, [100, 100, 100, 90, 100, 100]])
SceneManager.instance_variable_set(:@stack, [Scene_Map.new])
coop.ended
check("and has its own back once the battle ended", own_rates.call, [75] * 6)
reset

$encounter_troop = 50
$scene_now = Scene_Map.new
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free])
$game_player.encounter
coop.take(host, { "coop" => "hot_ok", "bid" => "hb1", "escape" => "1", "lose" => "0", "rates" => "120,120,120,120,120,120" })
$scene_now = scene
coop::Mode.before_start(scene)
check("an encounter a running battle takes in fights with that battle's enemy rates", own_rates.call, [120] * 6)
$inject = lambda { |frame| coop.take(host, { "coop" => "off", "bid" => "hb1" }) if frame == 3 }
coop.join(scene)
check("and with its own again once the host called it off", own_rates.call, [75] * 6)
reset
coop.borrow_rates("rates" => "1,2")
coop.borrow_rates("rates" => "")
check("an invite without the host's enemy rates leaves the player's own", own_rates.call, [75] * 6)

$raid = false
coop.take(asker, request)
check("a Classic world takes no request through the party's gate", map_sent("hot_no"), [])
$scene_now = scene
check("no hook of hotjoining failed", $log.grep(/hotjoin.*FAILED/), [])
