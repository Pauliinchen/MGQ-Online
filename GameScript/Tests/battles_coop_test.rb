#----------------------------------------------------------------
#  battles_coop_test.rb
#
#  Changelog:
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers co-op battles, mp_battles_coop.rbx with mp_battles_sync.rbx and mp_battles.rbx: from the
# invite to the end of the battle, for the host and for a guest.

require_relative "support"

$sent = []
$log = []
module MGQ_Multiplayer
  module Log; def self.write(m); $log << m; end; end
  module Player; def self.name; "Me"; end; end
  module Link; def self.cancel; $cancelled = true; end; end
end
module MGQ_MpOverworldSync
  def self.in_world?; true; end
  module Peers
    Peer = Struct.new(:seat, :state, :ghost, :member)
    @all = []
    def self.all; @all; end
    def self.at(seat); @all.find { |p| p.seat == seat }; end
  end
  module Me; def self.encode(state); state.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n\n"; end; end
  module Link
    def self.send_to(seat, text); $sent << [seat, text]; true; end
    def self.status; { "seat" => $my_seat.to_s }; end
  end
end
module MGQ_MpCoop
  module Party
    def self.id; "p1"; end
    def self.members; MGQ_MpOverworldSync::Peers.all.select(&:member); end
  end
end
module RPG; class Item; end; class Skill; end; class State; end; class Weapon; end; class Armor; end; end
class Color; end
class Tone; end
class Game_ActionResult; end
class Game_BaseItem; end
class Game_Battler; end
class Game_Action
  attr_accessor :item, :target_index
  def initialize(battler); @battler = battler; end
  def set_skill(id); @item = [:skill, id]; end
  def set_item(id); @item = [:item, id]; end
end
class Game_Actor < Game_Battler
  attr_accessor :id, :hp, :mp, :actions
  def initialize(id); @id = id; @hp = 100; @mp = 10; @actions = []; end
  def name; "Actor#{@id}"; end
  def make_actions; @actions = [Game_Action.new(self)]; end
  def make_auto_battle_actions; @actions = [:auto]; end
end
class Game_MpActor < Game_Actor
  def initialize(member, player); super(member.actor_id); @player = player; end
  def name; "Actor#{@id} (#{@player})"; end
end
class Game_Enemy < Game_Battler
  attr_reader :enemy_id
  def initialize(id); @enemy_id = id; end
  def name; "Enemy#{@enemy_id}"; end
end
module MGQ_MpActors
  module Builds
    Member = Struct.new(:actor_id)
    def self.write(actors); actors.map(&:id).join(","); end
    def self.parse(text, count); text.to_s.split(",").first(count).map { |id| Member.new(id.to_i) }; end
  end
end
class Game_Party
  attr_accessor :own
  def battle_members; @own; end
end
class Game_Troop; attr_accessor :members; end
class Game_Temp; attr_accessor :in_memory_battle; end
class Game_Message; def clear; $cleared = true; end; end
class Interpreter; attr_accessor :busy; def running?; @busy; end; end
class Game_Map; attr_accessor :map_id, :interpreter; end
class Game_Player; attr_accessor :moving; def transfer?; false; end; def moving?; @moving; end; end
class Game_Switches; def initialize; @d = {}; end; def [](i); @d[i] || false; end; def []=(i, v); @d[i] = v; end; end
System = Struct.new(:switches)
$data_system = System.new(Array.new(100, ""))
module NWConst; module Sw; FORBID_BATTLE_SHIFT_CHANGE = 27; end; end
module BattleManager
  def self.setup(troop_id, can_escape = true, can_lose = false); $setup << [troop_id, can_escape, can_lose]; end
  def self.can_giveup?; true; end
  def self.turn_end; $turn_ends = ($turn_ends || 0) + 1; end
  def self.process_abort; $aborted = true; end
end
$setup = []
$data_skills = Array.new(200, :skill)
$data_items = Array.new(50, :item)
module SceneManager
  def self.run; end
  def self.call(scene); $called = scene; end
end
class Scene_Battle
  def terminate; end
  def refresh_status; $refreshed = true; end
  def start_party_command_selection; $commands_phase = true; end
  attr_accessor :changing
  def scene_changing?; @changing; end
  def update_for_wait; $frames += 1; $inject.call($frames) if $inject; end
end
class Scene_Map; def update_scene; end; def scene_changing?; false; end; end
class Window_Base; end
module Input; def self.trigger?(*); false; end; end

module MGQ_MpCoop
  def self.tell(seat, field, value, fields = {})
    MGQ_MpOverworldSync::Link.send_to(seat, MGQ_MpOverworldSync::Me.encode({ field => value, "party" => Party.id }.merge(fields)))
  end
  def self.route(*); end
end
module MGQ_MpOverworldSync
  def self.route(*); end
  def self.on_tick(*); end
  def self.state_fields(*); end
  def self.busy_scene(*); end
  def self.on_observe(*); end
  def self.on_leave(*); end
  def self.label_line(*); end
end
load_script "mp_battles"
load_script "mp_battles_coop"
load_script "mp_battles_sync"
module MGQ_MpBattlesSync::Waiting
  def self.open(text); :window; end
  def self.close(window); nil; end
  def self.leave?(window, frames); false; end
end
SceneManager.run
MGQ_MpBattlesCoop.install

# Reads a message another game sent into its fields, its body under :payload.
#
# @param text [String] The message.
# @return [Hash] The fields.
def fields_of(text)
  head, payload = text.split("\n\n", 2)
  fields = {}
  head.to_s.split("\n").each { |line| k, v = line.split("=", 2); fields[k] = v if v }
  fields[:payload] = payload.to_s
  fields
end

$game_switches = Game_Switches.new
$game_temp = Game_Temp.new
$game_message = Game_Message.new
$game_map = Game_Map.new
$game_map.map_id = 5
$game_map.interpreter = Interpreter.new
$game_player = Game_Player.new
$game_party = Game_Party.new
$game_troop = Game_Troop.new
$game_troop.members = [Game_Enemy.new(31), Game_Enemy.new(32)]
mine = [Game_Actor.new(1), Game_Actor.new(2), Game_Actor.new(3)]
$game_party.own = mine
friend = MGQ_MpOverworldSync::Peers::Peer.new(2, { "name" => "Friend", "map" => "5", "scene" => "map" }, nil, true)
busy = MGQ_MpOverworldSync::Peers::Peer.new(3, { "name" => "Busy", "map" => "5", "scene" => "menu" }, nil, true)
away = MGQ_MpOverworldSync::Peers::Peer.new(4, { "name" => "Away", "map" => "9", "scene" => "map" }, nil, true)
stranger = MGQ_MpOverworldSync::Peers::Peer.new(6, { "name" => "Stranger", "map" => "5", "scene" => "map" }, nil, false)
MGQ_MpOverworldSync::Peers.all.push(friend, busy, away, stranger)
$my_seat = 0
scene = Scene_Battle.new

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

# Somebody joins.
BattleManager.setup(40, true, false)
bid = MGQ_MpBattlesSync.battle_id
join = MGQ_MpBattlesSync::Wire.line(["7,8", [[50, 5], [60, 6]]])
MGQ_MpBattlesSync.take(stranger, { "battle" => "join", "bid" => bid, :payload => join })
MGQ_MpBattlesSync.take(friend, { "battle" => "join", "bid" => "other", :payload => join })
$sent.clear
$frames = 0
$inject = lambda { |frame| MGQ_MpBattlesSync.take(friend, { "battle" => "join", "bid" => bid, :payload => join }) if frame == 3 }
check("the host gathers who joins", MGQ_MpBattlesCoop.gather(scene), nil)
$inject = nil
roster = $sent.map { |seat, text| fields_of(text) }.find { |f| f["battle"] == "roster" }
enemies, players = MGQ_MpBattlesSync::Wire.parse(roster[:payload])
check("and sends the party to everyone", [enemies, players.map { |p| p[0, 3] }], [[31, 32], [[0, "Me", "1,2"], [2, "Friend", "7,8"]]])
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
host = MGQ_MpOverworldSync::Peers::Peer.new(0, { "name" => "Host", "map" => "5", "scene" => "map" }, nil, true)
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
roster_body = MGQ_MpBattlesSync::Wire.line([[31, 32], [[0, "Host", "4,5", [[80, 8], [90, 9]]], [2, "Me", "1,2", [[100, 10], [100, 10]]]]])
$inject = lambda { |frame| MGQ_MpBattlesSync.take(host, { "battle" => "roster", "bid" => "b9", :payload => roster_body }) if frame == 2 }
check("the guest joins", MGQ_MpBattlesCoop.join(scene), nil)
$inject = nil
sent_join = $sent.map { |_, text| fields_of(text) }.find { |f| f["battle"] == "join" }
check("with up to two of its own characters", MGQ_MpBattlesSync::Wire.parse(sent_join[:payload]), ["1,2", [[100, 10], [100, 10]]])
guest_party = $game_party.battle_members
check("and fights in the host's order, its own characters as they are", guest_party.map(&:name), ["Actor4 (Host)", "Actor5 (Host)", "Actor1", "Actor2"])
check("the guest's commands are only for its own", MGQ_MpBattlesSync::Wire.parse(MGQ_MpBattlesSync::Commands.build)[0].map(&:size), [0, 0, 0, 0])
guest_party[2].actions = [Game_Action.new(guest_party[2]).tap { |a| a.set_skill(5); a.target_index = 0; a.item = RPG::Skill.new; def (a.item).id; 5; end }]
check("which it sends by the party's places", MGQ_MpBattlesSync::Wire.parse(MGQ_MpBattlesSync::Commands.build)[0][2], [["skill", 5, 0]])
check("a guest tries to escape as in any battle", MGQ_MpBattlesSync::Live.escape_leaves?, false)
MGQ_MpBattlesCoop.ended

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

# 3 players bring one each.
check("three players bring one each", MGQ_MpBattlesCoop.share(3), 1)

# Players who get away: three players, then two, then one.
$my_seat = 0
MGQ_MpOverworldSync::Peers.all.clear
g1 = MGQ_MpOverworldSync::Peers::Peer.new(2, { "name" => "Friend", "map" => "5", "scene" => "map" }, nil, true)
g2 = MGQ_MpOverworldSync::Peers::Peer.new(3, { "name" => "Other", "map" => "5", "scene" => "map" }, nil, true)
MGQ_MpOverworldSync::Peers.all.push(g1, g2)
$game_map.map_id = 5
$game_party.own = mine
BattleManager.setup(50)
bid3 = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesSync.take(g1, { "battle" => "join", "bid" => bid3, :payload => MGQ_MpBattlesSync::Wire.line(["7,8", [[50, 5], [60, 6]]]) })
MGQ_MpBattlesSync.take(g2, { "battle" => "join", "bid" => bid3, :payload => MGQ_MpBattlesSync::Wire.line(["9,10", [[70, 7], [80, 8]]]) })
$frames = 0
$sent.clear
MGQ_MpBattlesCoop.gather(scene)
three = $game_party.battle_members
check("three players bring one each", three.map(&:name), ["Actor1", "Actor7 (Friend)", "Actor9 (Other)"])
roster3 = $sent.map { |_, text| fields_of(text) }.find { |f| f["battle"] == "roster" }
check("the roster carries two of everyone's characters", MGQ_MpBattlesSync::Wire.parse(roster3[:payload])[1].map { |p| p[2] }, ["1,2", "7,8", "9,10"])
three[1].hp = 12

MGQ_MpBattlesSync.guest_left(3)
$sent.clear
MGQ_MpBattlesCoop.settle(scene)
two = $game_party.battle_members
check("when one gets away, the others bring two each", two.map(&:name), ["Actor1", "Actor2", "Actor7 (Friend)", "Actor8 (Friend)"])
check("characters who stay keep what the battle did to them", [two[2].equal?(three[1]), two[2].hp], [true, 12])
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
MGQ_MpBattlesCoop.form(scene, [[0, "Host", "4,5", [[80, 8], [90, 9]]], [2, "Me", "1,2", [[100, 10], [100, 10]]], [3, "Other", "9,10", []]])
check("the guest's party of three", $game_party.battle_members.map(&:name), ["Actor4 (Host)", "Actor1", "Actor9 (Other)"])
MGQ_MpBattlesSync::Channel.receive(0, "coop_party", MGQ_MpBattlesSync::Wire.line([[[0, "Host", "4,5", [[80, 8], [90, 9]]], [2, "Me", "1,2", []]]]))
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
MGQ_MpBattlesSync::Live.coop_end("process_abort", scene)
check("when the host gets away, the guest fights on alone", [MGQ_MpBattlesCoop.active?, $game_party.battle_members, MGQ_MpBattlesSync.role, MGQ_MpBattles.running?], [false, mine, nil, false])
check("from a new command phase", [$turn_ends, $commands_phase, $aborted], [1, true, false])
