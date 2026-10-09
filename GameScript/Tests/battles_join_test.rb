#----------------------------------------------------------------
#  battles_join_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# Covers joining a battle by choice in a Raid World, battles_coop_join.rbx with
# battles_coop_hotjoin.rbx, battles_coop.rbx and battles_sync.rbx: the state a host tells, when the
# prompt shows, the hotkey, the host that takes the player in or refuses them, and the late guest
# who joins an event's battle and a boss battle without enemies.

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
$game_system = Game_System.new
BattleManager.instance_variable_set(:@phase, :turn_end)
module BattleManager; def self.battle_end?; $ending ? true : false; end; end

# Stand-ins for the world, the screens over the map, the notification box and the hotkeys.
module MGQ_MpWorld; def self.raid?; $raid; end; end
module MGQ_MpTrade; def self.session; $trading; end; end
module MGQ_MpChat; def self.typing?; $typing ? true : false; end; end
module MGQ_MpActions; module Wheel; def self.open?; $wheel ? true : false; end; end; end
module MGQ_MpEmotes; def self.open?; false; end; end
module MGQ_MpNotices
  def self.message(_key, text, _frames = 180); ($messages ||= []) << text; end
  def self.drop(_key, _reason = ""); end
end
module MGQ_MpOverworldSync
  def self.map_free?; SceneManager.scene.is_a?(Scene_Map) && !$game_map.interpreter.running?; end
end
$down = []
module MGQ_Multiplayer
  module Player; def self.setting(key); ($settings || {})[key]; end; end
  module Key; def self.pressed?(code); $down.include?(code); end; end
end

# Stand-ins for the map's sprites, which the prompt draws with.
class Bitmap
  Font = Struct.new(:size, :outline, :color)
  attr_reader :font, :drawn
  def initialize(_width, _height); @font = Font.new; @drawn = []; end
  def clear; @drawn = []; end
  def draw_text(*args); @drawn << args; end
  def dispose; end
end
class Sprite
  attr_accessor :bitmap, :ox, :z, :x, :y, :visible, :opacity, :height
  def initialize(_viewport = nil); @visible = true; @opacity = 255; end
  def dispose; end
end
class Spriteset_Map; def update; end; def dispose; end; end
module MGQ_MpUi; Z = { :labels => 250 }; end

load_script "core_hotkeys"
load_script "battles_coop_join"
join = MGQ_MpBattlesJoin

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

# Forgets every battle, invite, hotjoin and request, as after a reset.
def reset
  MGQ_MpBattlesCoop.drop
  MGQ_MpBattlesJoin.drop
  MGQ_MpBattlesSync.finish
  MGQ_MpBattles.drop
  MGQ_MpBattles.instance_variable_set(:@kind, nil)
  $sent.clear
  $messages = []
  $frames = 0
  $inject = nil
  $down = []
  $ending = false
end

# Runs a frame of the map: the co-op battle's and this script's hooks.
#
# @return [Scene_Map] The map.
def map_frame
  map = Scene_Map.new
  $scene_now = map
  map.update_scene
  map
end

$my_seat = 0
$my_since = 200
$leader = nil
$raid = true
$game_party.own = [Game_Actor.new(1), Game_Actor.new(2), Game_Actor.new(3)]
$game_map.map_id = 5
$game_player.x = 0
$game_player.y = 0
$scene_now = Scene_Map.new

# The state a host tells.
check("the hotkey is J unless bound", [MGQ_MpHotkeys.code(:join_battle), MGQ_MpHotkeys.label(:join_battle)], [0x4A, "J"])
check("on the map a Raid World's player tells no battle that takes players in", join.state_fields, { "rbn" => 0 })
$raid = false
check("a Classic world's player tells nothing", join.state_fields, {})
$raid = true
$scene_now = scene
$game_troop.setup(31)
hotjoin.fight_alone("own1")
check("one who fights alone tells one player", join.state_fields, { "rbn" => 1 })
sync.join_world(:guest, "g1", [4], "P4")
check("a guest tells nothing of the battle, its host does", join.state_fields, { "rbn" => 0 })
reset
$scene_now = scene
sync.join_world(:host, "g2", [7], "the players")
sync.battle_started
hotjoin.fight_alone("g2")
check("a host still gathering its players takes nobody in", [join.state_fields, join.closed_reason[0]], [{ "rbn" => 0 }, "gathering"])
reset
$scene_now = scene
hotjoin.fight_alone("own2")
$ending = true
check("nor does a battle that ends", [join.state_fields, join.closed_reason[0]], [{ "rbn" => 0 }, "ending"])
$ending = false
MGQ_MpBattles.instance_variable_set(:@kind, :pvp)
check("nor a PvP battle", [join.state_fields, join.closed_reason[0]], [{ "rbn" => 0 }, "pvp"])
reset

# When the prompt shows.
host = player(5, { "scene" => "battle", "rb" => "b1", "rbh" => "5", "rbn" => "1", "x" => "2", "y" => "1" })
MGQ_MpOverworldSync::Peers.all.replace([host])
map_frame
check("a player near a battle that takes players in sees the prompt", [join.target, join.prompt_text], [[host, "b1"], "Press J to join battle"])
host.state["x"] = "4"
map_frame
check("not when its player stands further than #{join::JOIN_DISTANCE} steps", join.prompt_text, nil)
guest = player(6, { "scene" => "battle", "rb" => "b1", "rbh" => "5", "x" => "-1", "y" => "-3" })
MGQ_MpOverworldSync::Peers.all.replace([host, guest])
check("but near one of its guests, whose host stands further", join.target, [host, "b1"])
host.state["x"] = "1"
host.state["rbn"] = "4"
check("not when four players fight in it", join.target, nil)
host.state["rbn"] = "0"
check("nor when its host takes nobody in", join.target, nil)
host.state["rbn"] = "2"
host.state["map"] = "6"
check("nor when its host is on another map", join.target, nil)
host.state["map"] = "5"
duelist = player(7, { "scene" => "battle", "rb" => "", "x" => "1" })
MGQ_MpOverworldSync::Peers.all.replace([duelist])
check("nor near a PvP battle, which tells no battle to join", join.target, nil)
MGQ_MpOverworldSync::Peers.all.replace([host])
$raid = false
map_frame
check("never in a Classic world", join.prompt_text, nil)
$raid = true
$game_map.interpreter.busy = true
check("nor while an event runs", join.target, nil)
$game_map.interpreter.busy = false
$typing = true
check("nor while the chat box is open", join.target, nil)
$typing = false
$wheel = true
check("nor while the action wheel is open", join.target, nil)
$wheel = false
$trading = :session
check("nor while the player trades", join.target, nil)
$trading = nil
sync.join_world(:guest, "x1", [9], "P9")
check("nor while the player is in a battle", join.target, nil)
sync.finish
$scene_now = Object.new
check("nor outside the map", join.target, nil)
map_frame
check("the prompt shows again once the player is free", join.prompt_text, "Press J to join battle")

# The prompt below the player's character.
prompt = Sprite_MpJoinPrompt.new(nil)
feet = Struct.new(:x, :y, :height, :visible, :opacity).new(100, 200, 48, true, 255)
prompt.show(feet)
check("the prompt shows below the player's feet", [prompt.visible, prompt.x, prompt.y, prompt.bitmap.drawn.map { |args| args[4] }], [true, 100, 202, ["Press J to join battle"]])
feet.opacity = 0
prompt.show(feet)
check("not while the player's character is hidden", prompt.visible, false)

# The hotkey asks the host.
$sent.clear
$down = [0x4A]
map_frame
$down = []
check("the hotkey asks the battle's host through the map's gate", map_sent("pick").map { |seat, f| [seat, f["bid"], f["map"]] }, [[5, "b1", "5"]])
check("the player stands still meanwhile, the prompt hidden", [MGQ_MpHooks.player_held?, join.prompt_text], [true, nil])
check("and reads that they ask", $messages.last, "Asking P5 to join their battle...")
$down = [0x4A]
$sent.clear
map_frame
$down = []
check("a second press asks nothing more", map_sent("pick"), [])
coop.take_map(host, { "coop" => "pick_no", "bid" => "b1", "why" => "full" })
check("a refusal tells the player why", $messages.last, "Cannot join P5's battle: it is full.")
check("and lets them walk on", MGQ_MpHooks.player_held?, false)
map_frame
$down = [0x4A]
map_frame
$down = []
join.instance_variable_get(:@asking)[:at] -= join::ANSWER_SECONDS + 1
map_frame
check("without an answer the player walks on", [$messages.last, MGQ_MpHooks.player_held?], ["No answer from P5's battle.", false])
reset
MGQ_MpOverworldSync::Peers.all.replace([])
map_frame
$down = [0x4A]
map_frame
check("the hotkey asks nobody without a battle near the player", map_sent("pick"), [])
reset

# The host takes the player in or refuses them.
asker = player(8)
MGQ_MpOverworldSync::Peers.all.replace([asker])
$scene_now = scene
$game_troop.setup(52)
hotjoin.fight_alone("ev1")
request = { "coop" => "pick", "bid" => "ev1", "map" => "5" }
coop.take_map(asker, request)
check("a host who fights an event's battle alone takes the player in with an invite to the running battle",
      map_sent("invite").map { |seat, f| [seat, f["bid"], f["troop"], f["seats"], f["hot"], f["boss"]] }, [[8, "ev1", "52", "8", "1", nil]])
check("hosting it without turning it live until the player joins", [sync.role, sync.live?, sync.expected], [:host, false, [8]])
check("taking no enemies in", hotjoin.instance_variable_get(:@pending).map { |entry| [entry[:seats], entry[:enemies]] }, [[[8], []]])
check("its state counts the player taken in", join.state_fields, { "rbn" => 2 })
$sent.clear
coop.take_map(asker, request)
check("a player taken in already is refused", map_sent("pick_no").map { |seat, f| [seat, f["why"]] }, [[8, "closed"]])
$sent.clear
coop.take_map(player(9), request.merge("bid" => "other"))
check("so is a request for another battle", map_sent("pick_no").map { |seat, f| [seat, f["why"]] }, [[9, "closed"]])
coop.take_map(player(9), request)
coop.take_map(player(10), request)
$sent.clear
coop.take_map(player(11), request)
check("and a fifth player", map_sent("pick_no").map { |seat, f| [seat, f["why"]] }, [[11, "full"]])
check("whom the state tells, taking nobody in", join.state_fields, { "rbn" => 0 })
coop.take_map(asker, { "coop" => "off", "bid" => "ev1" })
check("a player who stopped waiting is forgotten", hotjoin.pending_seats.include?(8), false)

# The player who joins takes the host's party, the troop untouched.
reset
$scene_now = scene
$game_troop.setup(52)
hotjoin.fight_alone("ev2")
coop.take_map(asker, request.merge("bid" => "ev2"))
$sent.clear
sync.take(asker, { "battle" => "join", "bid" => "ev2", :payload => sync::Wire.line(["5,6,7", [[50, 5], [60, 6], [70, 7]], 4]) })
open_phase(scene)
check("the command phase turns the event's battle live for the player who joined", [sync.host?, sync.guests_in], [true, [8]])
check("whose first character joins the party", $game_party.battle_members.map(&:name), ["Actor1", "Actor5 (P8)"])
check("while the troop stays the event's", $game_troop.members.map(&:enemy_id), [52])
roster = battle_sent("roster")
check("the player gets the roster with the event's troop", [roster.map(&:first), sync::Wire.parse(roster[0][1][:payload])[0].map(&:first)], [[8], [52]])

reset
$scene_now = scene
$game_troop.setup(29)
hotjoin.fight_alone("boss1")
coop.take_map(asker, request.merge("bid" => "boss1"))
check("a boss battle takes the player in too, its invite marking it one", map_sent("invite").map { |seat, f| [seat, f["boss"]] }, [[8, "1"]])
$sent.clear
coop.take_map(player(9, { "scene" => "battle", "rb" => "boss1", "rbh" => "0" }),
              { "coop" => "hot", "bid" => "boss1", "troop" => "50", "enemies" => "50:320:300:0", "seats" => "", "map" => "5" })
check("though it still takes no encounter in", map_sent("hot_no").map(&:first), [9])
sync.take(asker, { "battle" => "join", "bid" => "boss1", :payload => sync::Wire.line(["5", [[50, 5]], 4]) })
open_phase(scene)
check("the player joins the boss battle, which keeps its own troop", [sync.guests_in, $game_troop.members.map(&:enemy_id)], [[8], [29]])
reset

$raid = false
coop.take_map(asker, request)
coop.take(asker, request)
check("a Classic world takes no request", [map_sent("pick_no"), map_sent("invite")], [[], []])
$raid = true
reset

# The player who asked joins as a late guest once the invite comes.
host = player(5, { "scene" => "battle", "rb" => "b1", "rbh" => "5", "rbn" => "1", "x" => "1" })
MGQ_MpOverworldSync::Peers.all.replace([host])
map_frame
$down = [0x4A]
map_frame
$down = []
$setup.clear
coop.take_map(host, { "coop" => "invite", "bid" => "b1", "troop" => "29", "escape" => "0", "lose" => "1", "seats" => "0", "map" => "5", "hot" => "1", "boss" => "1" })
map_frame
check("the invite of the host the player asked starts the battle as a late guest",
      [$called, $setup.last, sync.role, sync.battle_id, hotjoin.late?, hotjoin.own_troop?], [Scene_Battle, [29, false, true], :guest, "b1", true, false])
check("which stays a boss battle should the player take it over", hotjoin.boss_battle?, true)
check("the player waits for nothing more", [join.instance_variable_get(:@asking), MGQ_MpHooks.player_held?], [nil, false])
$scene_now = scene
$inject = lambda do |frame|
  next unless frame == 2

  line = sync::Wire.line([[[29, 320, 300, 0]], [[5, "P5", "1,2,3", [], 4, [0, 1, 2], 1, 2], [0, "Me", "1,2,3", [], 4, [0, 1, 2], 1, 2]], nil, 4])
  sync.take(host, { "battle" => "roster", "bid" => "b1", :payload => line })
end
check("and takes the roster at the host's next turn", [coop.join(scene), $game_troop.instance_variable_get(:@turn_count)], [nil, 4])
check("with the host's troop alone", $game_troop.members.map(&:enemy_id), [29])
reset

# The battle the player left, the map held, a player who stops waiting, and the hotkey's key.
$scene_now = Scene_Map.new
MGQ_MpOverworldSync::Peers.all.replace([host])
map_frame
check("no prompt near the battle the player left, whose host keeps them among its seats", join.target, nil)
host.state["rb"] = "b2"
map_frame
$game_map.interpreter.busy = true
check("the prompt hides while an event or a message holds the map", join.prompt_text, nil)
$game_map.interpreter.busy = false
$down = [0x4A]
map_frame
$down = []
join.instance_variable_get(:@asking)[:at] -= join::ANSWER_SECONDS + 1
$sent.clear
map_frame
check("a player who stops waiting tells the host, which forgets them", map_sent("off").map { |seat, f| [seat, f["bid"]] }, [[5, "b2"]])
coop.take_map(host, { "coop" => "invite", "bid" => "b2", "troop" => "29", "escape" => "0", "lose" => "1", "seats" => "0", "map" => "5", "hot" => "1" })
map_frame
check("and ignores its late invite", [sync.role, coop.invited_by?(5, "b2")], [nil, false])
reset
$scene_now = Scene_Map.new
map_frame
$down = [0x4A]
map_frame
$down = []
sync.join_world(:guest, "c9", [9], "P9")
map_frame
check("a player who joins another battle meanwhile is logged so", $log.grep(/joins battle c9 as guest instead of P5's battle b2/).size, 1)
reset
$scene_now = Scene_Map.new
$raid = false
before = $log.size
$down = [0x4A]
map_frame
$down = []
check("outside a Raid World the hotkey stays unread, so another may share its key", $log[before..-1].grep(/join battle|Join Battle/), [])
$raid = true
$settings = { "key_overview" => "74" }
map_frame
check("a hotkey with the same key turns Join Battle off, its prompt hidden", [join.reads_hotkey?, join.prompt_text], [false, nil])
$settings = nil
MGQ_MpOverworldSync::Peers.all.replace([])
$mgq_text_input = true
before = $log.size
$down = [0x4A]
map_frame
$down = []
$mgq_text_input = nil
check("a press while the player types logs nothing", $log[before..-1].grep(/join battle hotkey/), [])
reset

check("no hook of joining by choice failed", $log.grep(/join battle.*FAILED/), [])
