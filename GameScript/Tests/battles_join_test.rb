#----------------------------------------------------------------
#  battles_join_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Dropped the check of the late guest's wait limit, which only restated the request
#                            - Expected what keeps the player from a duel or a trade too before the player's own request
#      Paulinchen  2026-11-08: Expected the tiles of the bosses and the frozen fights in place of their steps
#      Paulinchen  2026-11-07: Typed through a text box of the Mod Framework instead of the old typing flag
#      Paulinchen  2026-11-06: Held the keys in $down down too, as the Mod Framework reads a hotkey's key
#                            - Reached the Mod Framework's engine under its own name
#                            - Named the action line's color as the scripts name it
#                            - Left how the prompt looks to the in-game suite
#                            - Expected a side battle's enemy rates as a list of numbers
#      Paulinchen  2026-11-05: Answered the squad math with fixed values per case
#                            - Read the messages sent as the scripts hand them and handed those of other games as the DLL reads them
#                            - Answered the co-op topics with the values each case sets and checked what the scripts ask and do with the answers
#                            - Wrote and read the battle lines through the codec's stand-in
#                            - Told every host's battle state in rbs beside its players in rbn
#                            - Expected the battle's players and state in the state, in a Classic world too
#                            - Covered a party member's battle a member who missed it joins late in a Classic world (issue 76)
#                            - Covered a press near a battle that ends, which tells why and starts no side battle (issue 74)
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#                            - Checked the prompt as a button of the Mod Framework below the player, which a click presses as the hotkey does
#                            - Stood in for the wheels of the Mod Framework
#      Paulinchen  2026-10-31: Stood in for the Mod Framework's keys
#                            - Expected the plainer texts the player reads
#      Paulinchen  2026-10-30: Read the players taken in from the joins stand-in
#                            - Read what the prompt offers from a map frame and asked by the hotkey
#                            - Handed messages through the map's gate over as the matchmaking's routes do
#                            - Read why a battle takes nobody in from the rules in C#
#                            - Dropped the default hotkey
#      Paulinchen  2026-10-23: Told a side battle through the pools' side_battle?
#      Paulinchen  2026-10-17: Covered the frozen fight the prompt offers near its boss's stand-in
#      Paulinchen  2026-10-11: Checked that a running battle takes an encounter with as many players as fit
#                            - Checked the prompt in the style's small font and solid outline
#                            - Stood in for the color every request and offer shares
#                            - Took the depths and the screen from ui.rbx
#                            - Kept the bitmap stand-in's width
#      Paulinchen  2026-10-10: Covered the side battle the prompt offers near a full raid boss battle
#                            - Checked that a side battle starts as the player's own
#                            - Checked that an encounter with more players than a running battle takes starts alone
#                            - Checked that the prompt stays whole on the screen at the map's edges
#                            - Checked the prompt near a battle whose players are under the Library or Config
#      Paulinchen  2026-10-09: Covered a boss battle whose troop grew mid-battle
#                            - Created
#
#----------------------------------------------------------------

# Covers joining a battle by choice in a Raid World, battles_coop_join.rbx with
# battles_coop_hotjoin.rbx, battles_coop.rbx and battles_sync.rbx: the state a host tells, the
# prompt and its hotkey, the host's answer, the late guest, the party members' offers, and the
# side battle the prompt offers near a full raid boss battle, and the frozen fight it offers near
# its boss's stand-in. What the prompt offers, whom a host takes in and the room a battle tells
# are the DLL's to answer (JoinChoice, JoinIntake), here with the fixed values each case sets.

require_relative "battle_support"

# The DLL's arrangement of the battles' players below, by the players
# handed over, each [id, first, party_member_max, characters], answered as [index, Frontline,
# Backline] of each in their order.
$rule_answers.cases("squad.arrange", {
  [["id-me", true, 8, 3]] => [[0, 1, 2]],
  [["id-me", true, 8, 3], ["id-8", false, 4, 3]] => [[0, 1, 2], [1, 1, 2]],
  [["id-me", true, 8, 3], ["id-8", false, 4, 1]] => [[0, 1, 2], [1, 1, 0]]
}) { |request| request["players"] }
$rule_answers.set("squad.raid", { "regular" => [1, 2], "raid" => [1, 2], "largest" => 3 })

sync = MGQ_MpBattlesSync
hotjoin = MGQ_MpBattlesHotjoin
coop = MGQ_MpBattlesCoop
scene = Scene_Battle.new
spriteset = Spriteset_Battle.new
scene.instance_variable_set(:@spriteset, spriteset)

# Stand-ins for what the recorder reads of every battler and of the game's settings.
# The game's system, whose conf holds the settings.
class Game_System
  attr_reader :conf
  def initialize; @conf = {}; end
end
# A character's TP and states.
class Game_Actor
  attr_accessor :tp
  def states; []; end
end
# An enemy's values and states.
class Game_Enemy
  attr_accessor :hp, :mp, :tp
  def states; []; end
  def actor?; false; end
  def death_state_id; 1; end
end
$data_states = [nil, :death]
# The party's od_turn and od_user.
class Game_Party; attr_accessor :od_turn, :od_user; end
# The troop's turn count.
class Game_Troop; def turn_count; @turn_count.to_i; end; end
$game_system = Game_System.new
BattleManager.instance_variable_set(:@phase, :turn_end)
# The battle, ending while $ending is set.
module BattleManager; def self.battle_end?; $ending ? true : false; end; end

# Stand-ins for the world, the screens over the map, the notification box and the hotkeys.
# The world, a Raid World while $raid is set.
module MGQ_MpWorld; def self.raid?; $raid; end; end
# The trading, whose session is $trading.
module MGQ_MpTrade; def self.session; $trading; end; end
# The chat box, typed in while $typing is set.
module MGQ_MpChat; def self.typing?; $typing ? true : false; end; end
# The line color requests and offers share, and the action wheel, open while $wheel is set.
module MGQ_MpActions; LINE_COLOR = :mgq_online_own; def self.wheel; StandInWheel.new(lambda { $wheel }); end; end
# The emote wheel, never open.
module MGQ_MpEmotes; def self.wheel; StandInWheel.new(lambda { false }); end; end
# The notification box, keeping each message's text in $messages.
module MGQ_MpNotices
  def self.message(_key, text, _frames = 180); ($messages ||= []) << text; end
  def self.drop(_key, _reason = ""); end
end
# The map, free while the scene is the map and no event runs.
module MGQ_MpOverworldSync
  def self.map_free?; SceneManager.scene.is_a?(Scene_Map) && !$game_map.interpreter.running?; end
end
$down = []
# The player's settings from $settings and the hotkeys held in $down.
module MGQ_Multiplayer
  module Player; def self.setting(key); ($settings || {})[key]; end; end
  module Mod_Framework::UI::Engine::Key; def self.pressed?(code); $down.include?(code); end; def self.down?(code); $down.include?(code); end; end
end

# Stand-ins for the map's sprites, which the prompt draws with.
# A bitmap that keeps what is drawn on it.
class Bitmap
  # The font a bitmap draws with.
  Font = Struct.new(:size, :outline, :color, :bold, :out_color)
  attr_reader :font, :drawn
  # The width stays, which the waiting box cuts its names line to.
  def initialize(width, height); @width = width; @height = height; @font = Font.new; @drawn = []; end
  def clear; @drawn = []; end
  def draw_text(*args); @drawn << args; end
  def dispose; end
end
# A sprite, shown and opaque from the start.
class Sprite
  attr_accessor :bitmap, :ox, :z, :x, :y, :visible, :opacity, :height
  def initialize(_viewport = nil); @visible = true; @opacity = 255; end
  def dispose; end
end
# The map's sprites, which do nothing.
class Spriteset_Map; def update; end; def dispose; end; end

load_script "core_hotkeys"
load_script "battles_coop_join"
join = MGQ_MpBattlesJoin

# Reads the messages sent through the map's gate.
#
# @param kind [String] The co-op message's kind.
# @return [Array<Array>] Each message's seat and fields.
def map_sent(kind)
  $sent.select { |_, f| f["map_coop"] == kind }
end

# Reads the battle messages sent.
#
# @param kind [String] The battle message's kind.
# @return [Array<Array>] Each message's seat and fields.
def battle_sent(kind)
  $sent.select { |_, f| f["battle"] == kind }
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
# battles_sync_live.rbx's.
#
# battles_sync_live.rbx's own hooks need game classes the tests leave out.
#
# @param scene [Scene_Battle] The battle.
def open_phase(scene)
  scene.start_party_command_selection
  return unless MGQ_MpBattlesSync.host?

  MGQ_MpBattlesSync::Live.open_phase(scene)
  MGQ_MpBattlesSync::Recorder.command_phase
end

# Forgets every battle, invite, hotjoin and request, as after a reset, and gives the scripts a DLL
# with nothing to say.
def reset
  MGQ_MpBattlesCoop.drop
  MGQ_MpBattlesJoin.drop
  MGQ_MpBattlesSync.finish
  MGQ_MpBattles.drop
  MGQ_MpBattles.instance_variable_set(:@kind, nil)
  answer_coop($world_bridge)
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
  # The DLL's messages for the box reach the scripts as events of the next frame.
  MGQ_Multiplayer::Bridge.frame
  map
end

# Runs a frame of the map with the Join Battle hotkey pressed.
#
# @return [Scene_Map] The map.
def press
  $down = [0x4A]
  map_frame
ensure
  $down = []
end

# Runs a frame on the map without the hotkey and reads what the prompt offers.
#
# @param part [Symbol] :target (the battle's host and id), :side or :freeze.
# @return [Array, nil] What it offers.
def offered(part = :target)
  MGQ_MpBattlesJoin.on_map(false)
  found = MGQ_MpBattlesJoin.instance_variable_get(:"@#{part}")
  part == :target && found ? [MGQ_MpOverworldSync::Peers.at(found[0]), found[1]] : found
end

# Reads the last frame on the map the scripts told the DLL of the prompt.
#
# @return [Hash] The request.
def join_frame
  $coop.asked("coop.join_frame").last
end

# Has a co-op topic's step answer a value once, then nil, as a DLL with nothing more to say.
#
# @param key [String] The topic and its step, such as "coop.pending joins".
# @param value [Object] The answer.
def once(key, value)
  answers = [value]
  $coop.set(key) { |_request| answers.shift }
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
reset

# The state a host tells, as the DLL tells it from the facts of the player's battle.
$scene_now = scene
$game_troop.setup(31)
hotjoin.fight_alone("own1")
$coop.set("coop.room", "rbn" => 1, "rbs" => "open")
check("one who fights alone tells the players and whether the battle takes players in as the DLL tells them, from the battle's facts",
      [join.state_fields, $coop.asked("coop.room").last.values_at("bid", "host", "role", "players", "live", "ending", "pvp", "boss")],
      [{ "rbn" => 1, "rbs" => "open" }, ["own1", 0, nil, 1, false, false, false, false]])
sync.join_world(:guest, "g1", [4], "P4")
join.state_fields
check("a guest tells the DLL the battle and its host", $coop.asked("coop.room").last.values_at("bid", "host", "role", "players"), ["g1", 4, "guest", 1])
reset
$scene_now = scene
sync.join_world(:host, "g2", [7], "the players")
sync.battle_started
hotjoin.fight_alone("g2")
join.state_fields
check("a host still gathering its players tells the DLL whom it waits for", $coop.asked("coop.room").last.values_at("role", "seats", "players"), ["host", [7], 2])
reset
$scene_now = scene
hotjoin.fight_alone("own2")
$ending = true
MGQ_MpBattles.instance_variable_set(:@kind, :pvp)
join.state_fields
check("a battle that ends tells so, as does a PvP battle", $coop.asked("coop.room").last.values_at("ending", "pvp"), [true, true])
$coop.set("coop.room") { |_request| nil }
check("a battle the DLL tells nothing of takes nobody in", join.state_fields, { "rbn" => 0, "rbs" => "closed" })
reset

# When the prompt shows.
host = player(5, { "scene" => "battle", "rb" => "b1", "rbh" => "5", "rbn" => "1", "rbs" => "open", "x" => "2", "y" => "1" })
MGQ_MpOverworldSync::Peers.all.replace([host])
$coop.set("coop.join_frame", "target" => [5, "b1"])
map_frame
check("a player near a battle the DLL finds sees the prompt", [offered, join.prompt_text], [[host, "b1"], "Press J to join battle"])
check("each frame on the map tells the DLL the player's facts, that the hotkey is read and not pressed, and nothing keeps the player busy",
      join_frame.values_at("reads", "pressed", "changing", "busy", "sides", "frozen") + [join_frame["facts"]["map"]], [true, false, false, [nil, nil], nil, [], 5])
busy = []
$game_map.interpreter.busy = true
offered
busy << join_frame["busy"]
check("the prompt hides while an event or a message holds the map", join.prompt_text, nil)
$game_map.interpreter.busy = false
# Each turns on or off what keeps the player busy: the chat box, the action wheel, and what keeps
# them from a duel and a trade too, such as a battle.
[lambda { |on| $typing = on }, lambda { |on| $wheel = on }, lambda { |on| $busy_reason = on ? "in a battle" : nil }].each do |turn|
  turn.call(true)
  offered
  busy << join_frame["busy"]
  turn.call(false)
end
check("it tells the DLL what keeps the player from joining: an event, the chat box, the action wheel, and before the player's own request what keeps them from a duel or a trade too",
      busy, [["the map is not free: an event, a message or a transfer", nil], [nil, "the chat box is open"], [nil, "the action wheel is open"], ["in a battle", nil]])
$settings = { "key_overview" => "74" }
map_frame
check("a hotkey with the same key turns Join Battle off, its prompt hidden and nothing read",
      [join.reads_hotkey?, join.prompt_text, join_frame.values_at("reads", "busy")], [false, nil, [false, [nil, nil]]])
$settings = nil
map_frame
check("the prompt shows again once the hotkey is free", join.prompt_text, "Press J to join battle")

# The hotkey asks the host through the DLL.
press
check("a press of the hotkey goes to the DLL with the frame", join_frame["pressed"], true)
$coop.status("join_waits" => true)
check("the player stands still while the DLL says they wait for the host's answer", [join.asking?, MGQ_MpHooks.player_held?], [true, true])
$coop.status
check("and walks on once it says no more", MGQ_MpHooks.player_held?, false)
join.click
map_frame
check("a click on the prompt presses the hotkey at the next frame", join_frame["pressed"], true)
$log.clear
$coop.set("coop.join_frame", "busy_reason" => "the battle is ending")
press
$coop.set("coop.join_frame", nil)
press
check("a press the DLL takes nothing for logs why", $log.grep(/ignored: /).map { |line| line[/ignored: .*/] },
      ["ignored: the battle is ending", "ignored: nobody near the player fights a battle that takes players in"])
$log.clear
$coop.set("coop.join_frame", "target" => [5, "b1"], "asked" => true)
press
$coop.set("coop.join_frame", nil)
while_typing { press }
check("a press the DLL asked the host for, or one while the player types, logs nothing", $log.grep(/ignored: /), [])
reset

# The host takes the player in or refuses them.
asker = player(8)
MGQ_MpOverworldSync::Peers.all.replace([asker, player(9)])
$scene_now = scene
$game_troop.setup(52)
hotjoin.fight_alone("ev1")
request = { "coop" => "pick", "bid" => "ev1", "map" => "5" }
$coop.message(asker, request)
intake = $coop.asked("coop.intake").last
check("a request to join by choice goes to the DLL's intake with the battle's facts",
      [intake.values_at("kind", "seat", "bid", "map"), intake["facts"]["bid"]], [["choice", 8, "ev1", "5"], "ev1"])
check("taken in, the player gets an invite to the running battle of the event the host fights alone",
      map_sent("invite").map { |seat, f| [seat, f["bid"], f["troop"], f["seats"], f["hot"], f["boss"]] }, [[8, "ev1", 52, [8], true, nil]])
check("hosting it without turning it live until the player joins", [sync.role, sync.live?, sync.expected], [:host, false, [8]])
check("the DLL keeping them without enemies", $coop.asked("coop.pending").last, { "op" => "take_in", "requester" => 8, "seats" => [8], "enemies" => [] })
$sent.clear
$coop.set("coop.intake", "refusal" => ["full", "the battle is full"], "kept" => [], "left" => [], "room" => 0)
$coop.message(MGQ_MpOverworldSync::Peers.at(9), request)
check("a request the DLL refuses tells the player why", map_sent("pick_no").map { |seat, f| [seat, f["bid"], f["why"]] }, [[9, "ev1", "full"]])
$coop.set("coop.intake", nil)
$raid = false
asked = $coop.asked("coop.intake").size
$sent.clear
$coop.message(asker, request)
check("a Classic world takes no request of a player outside the party", [map_sent("pick_no"), map_sent("invite"), $coop.asked("coop.intake").size - asked], [[], [], 0])
asker.member = true
$coop.message(asker, request)
check("but a party member's, who missed the battle (issue 76)", $coop.asked("coop.intake").last.values_at("kind", "seat"), ["choice", 8])
asker.member = false
$raid = true
reset

# The player who joins takes the host's party, the troop untouched.
$scene_now = scene
$game_troop.setup(52)
hotjoin.fight_alone("ev2")
$coop.message(asker, request.merge("bid" => "ev2"))
$sent.clear
sync.take(asker, { "battle" => "join", "bid" => "ev2", :payload => wire_line(["5,6,7", [[50, 5], [60, 6], [70, 7]], 4]) })
$coop.set("coop.pending count", 1)
once("coop.pending joins", [[8, wire_line(["5,6,7", [[50, 5], [60, 6], [70, 7]], 4])]])
open_phase(scene)
check("the command phase turns the event's battle live for the player who joined", [sync.host?, sync.guests_in], [true, [8]])
check("whose first character joins the party", $game_party.battle_members.map(&:name), ["Actor1", "Actor5 (P8)"])
check("while the troop stays the event's", $game_troop.members.map(&:enemy_id), [52])
roster = battle_sent("roster")
check("the player gets the roster with the event's troop", [roster.map(&:first), wire_values(roster[0][1][:payload])[0].map(&:first)], [[8], [52]])
reset

$scene_now = scene
$game_troop.setup(29)
hotjoin.fight_alone("boss1")
$coop.message(asker, request.merge("bid" => "boss1"))
check("a boss battle takes the player in too, its invite marking it one", map_sent("invite").map { |seat, f| [seat, f["boss"]] }, [[8, true]])
reset

# A boss battle whose troop grew mid-battle, such as by another mod, stays one.
$scene_now = scene
$game_troop.setup(29)
$game_troop.members << Game_Enemy.new(1, 31)
hotjoin.fight_alone("boss2")
$coop.message(asker, request.merge("bid" => "boss2"))
check("a boss battle whose troop grew mid-battle takes the player in as one",
      [hotjoin.boss_battle?, map_sent("invite").map { |seat, f| [seat, f["boss"]] }, $coop.asked("coop.intake").last["facts"]["boss"]], [true, [[8, true]], true])
sync.take(asker, { "battle" => "join", "bid" => "boss2", :payload => wire_line(["5", [[50, 5]], 4]) })
$coop.set("coop.pending count", 1)
once("coop.pending joins", [[8, wire_line(["5", [[50, 5]], 4])]])
open_phase(scene)
roster = battle_sent("roster")
check("the player joins with every enemy in the roster, the one added mid-battle after the troop's own",
      [sync.guests_in, wire_values(roster[0][1][:payload])[0].map(&:first), $game_troop.members.map(&:enemy_id)], [[8], [29, 31], [29, 31]])
reset

# The player who asked joins as a late guest once the DLL accepts the host's invite.
host = player(5, { "scene" => "battle", "rb" => "b1", "rbh" => "5", "rbn" => "1", "rbs" => "open", "x" => "1" })
MGQ_MpOverworldSync::Peers.all.replace([host])
$setup.clear
invite = { "coop" => "invite", "bid" => "b1", "troop" => "29", "escape" => false, "lose" => true, "seats" => [0], "map" => "5", "hot" => true, "boss" => true }
$coop.set("coop.poll", "actions" => [coop_step("accept", "seat" => 5, "fields" => invite)])
map_frame
$coop.set("coop.poll", nil)
check("the invite of the host the player asked starts the battle as a late guest",
      [$called, $setup.last, sync.role, sync.battle_id, hotjoin.late?, hotjoin.own_troop?], [Scene_Battle, [29, false, true], :guest, "b1", true, false])
check("which stays a boss battle should the player take it over", hotjoin.boss_battle?, true)
$scene_now = scene
$coop.roster(wire_line([[[29, 320, 300, 0]], [[5, "P5", "1,2,3", [], 4, [0, 1, 2], 1, 2], [0, "Me", "1,2,3", [], 4, [0, 1, 2], 1, 2]], nil, 4]))
check("and takes the roster at the host's next turn", [coop.join(scene), $game_troop.instance_variable_get(:@turn_count)], [nil, 4])
check("with the host's troop alone", $game_troop.members.map(&:enemy_id), [29])
reset

# A party member's offer to come along to a battle outside the party.
$scene_now = Scene_Map.new
fellow = player(8, { "scene" => "battle", "rb" => "hb9", "rbh" => "5" })
outsider = player(5, { "scene" => "battle", "rb" => "hb9", "rbh" => "5", "rbn" => "2", "rbs" => "open", "x" => "1" })
MGQ_MpOverworldSync::Peers.all.replace([fellow, outsider])
MGQ_Multiplayer::Bridge.frame
$coop.set("coop.party_offers", [[8, "join", 5, "hb9", 1000]])
check("a member's offer to join a battle along reads so", hotjoin.party_offer_text(fellow, hotjoin.party_offers[fellow.seat]), "Join battle with P8?")
hotjoin.party_offers
check("the offers the DLL keeps are read once a frame", $coop.asked("coop.party_offers").size, 1)
hotjoin.accept_party(fellow)
check("taken up, the DLL hears whom the player comes along with and what keeps the player busy",
      $coop.asked("coop.accept_party").last.values_at("seat", "busy"), [8, [nil, nil]])
$coop.set("coop.party_offers", [[8, "start", 5, "hb9", 1000]])
check("and the offers are read anew, such as a member's offer to start a battle instead",
      hotjoin.party_offer_text(fellow, hotjoin.party_offers[fellow.seat]), "Start battle with P8?")
hotjoin.decline_party(fellow)
check("declined, the DLL hears whose offer", $coop.asked("coop.decline_party").last["seat"], 8)
reset
MGQ_MpOverworldSync::Peers.all.clear

# A side battle near a full raid boss battle, through battles_raid_pool.rbx and ui_raid_bar.rbx,
# which stand in here.
# The raid boss pools, troop 71 being Queen Harpy.
module MGQ_MpRaidPool
  # Reads the raid boss troop and enemy rates a host's rpb state tells.
  def self.side_of(host); host.state["rpb"]; end
  def self.troop_label(troop); troop == 71 ? "Queen Harpy" : "?"; end
  # Keeps the side battle started in $side_started and starts it while $side_ok is set.
  def self.start_side(troop, rates); $side_started = [troop, rates]; $side_ok; end
  # Takes the troop in $side_troop for a side battle.
  def self.side_battle?(troop); troop.to_i == $side_troop; end
  def self.won_already?(_troop); false; end
  def self.invite_fields(_troop = nil); {}; end
  def self.note_invite(_message); end
end
$scene_now = Scene_Map.new
boss_host = player(5, { "scene" => "battle", "rb" => "b3", "rbh" => "5", "rbn" => "4", "rbs" => "full", "rpb" => [71, [100, 100, 0]], "x" => "2", "y" => "1" })
MGQ_MpOverworldSync::Peers.all.replace([boss_host, player(6, { "rpb" => [71, [100, 100, 0]], "map" => "6" })])
$coop.set("coop.join_frame", "side" => [71, [100, 100, 0], "Queen Harpy"])
map_frame
check("each frame tells the DLL the side battles the raid boss battles on the player's map offer, by their hosts' states",
      join_frame["sides"], [[5, 71, [100, 100, 0], [], "Queen Harpy"]])
check("the side battle the DLL picks is offered in the prompt", [offered, join.prompt_text], [nil, "Press J to fight Queen Harpy alongside"])
# The raid bar, whose boss of troop 71 stands on (3, 1).
module MGQ_MpRaidBar; def self.boss_tiles(troop); troop == 71 ? [[3, 1]] : []; end; end
map_frame
check("with the tiles of each boss's events", join_frame["sides"], [[5, 71, [100, 100, 0], [[3, 1]], "Queen Harpy"]])
$settings = { "key_overview" => "74" }
map_frame
check("a hotkey that turns Join Battle off hides the side battle's prompt too", [join.prompt_text, join_frame["sides"]], [nil, nil])
$settings = nil
$side_ok = true
press
check("the hotkey starts the side battle with the host's troop and enemy rates", $side_started, [71, [100, 100, 0]])
$side_ok = false
press
check("a side battle that cannot start tells the player", $messages.last, "Cannot fight Queen Harpy now.")
$side_started = nil
reset

# The side battle starts as the player's own, which others may join by choice.
bystander = player(9, { "x" => "1" })
MGQ_MpOverworldSync::Peers.all.replace([bystander])
$scene_now = Scene_Map.new
$side_troop = 71
$coop.set("coop.offer", "actions" => [coop_step("fight_alone")])
BattleManager.setup(71, false, true)
$coop.set("coop.offer", nil)
$scene_now = scene
side_bid = hotjoin.state_fields["rb"]
check("a side battle against a raid boss goes to the DLL as one, which leaves it the player's own",
      [$coop.asked("coop.offer").last["side"], sync.role, side_bid.empty?], [true, nil, false])
$coop.message(bystander, { "coop" => "pick", "bid" => side_bid, "map" => "5" })
check("and takes in a player who asks to join it by choice", map_sent("invite").map { |seat, f| [seat, f["bid"], f["hot"]] }, [[9, side_bid, true]])
$side_troop = nil
reset
# Takes troop 72 for a side battle.
def MGQ_MpRaidPool.side_battle?(troop); troop.to_i == 72; end
$scene_now = Scene_Map.new
BattleManager.setup(72, false, true)
check("battles_raid_pool.rbx's word that a battle is a side battle goes to the DLL", $coop.asked("coop.offer").last["side"], true)
reset

# A raid boss's frozen fight on the map, through ui_raid_freeze.rbx, which stands in here: Sonya
# Mazda's, whose boss's stand-in stands on (2, 0), each fight the hotkey resumes noted in
# $freeze_joined.
module MGQ_MpRaidFreezeUi
  # Sonya Mazda's frozen fight with her stand-in's tile.
  def self.join_targets; [[868, "Sonya Mazda", 2, 0]]; end
  # Notes the fight resumed.
  def self.join(troop); ($freeze_joined ||= []) << troop; true; end
end
$freeze_joined = []
$scene_now = Scene_Map.new
MGQ_MpOverworldSync::Peers.all.replace([])
$coop.set("coop.join_frame", "freeze" => [868, "Sonya Mazda"])
map_frame
check("the DLL hears of the map's frozen fights with their bosses' tiles, and the prompt offers to fight the one it picks",
      [join_frame["frozen"], join.prompt_text], [[[868, "Sonya Mazda", 2, 0]], "Press J to fight Sonya Mazda"])
press
check("the hotkey resumes it", $freeze_joined, [868])
join.drop
check("a reset forgets the frozen fight offered", join.instance_variable_get(:@freeze), nil)
reset

check("no hook of joining by choice failed", $log.grep(/join battle.*FAILED/), [])
