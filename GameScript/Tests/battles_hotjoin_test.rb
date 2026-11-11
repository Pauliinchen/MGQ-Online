#----------------------------------------------------------------
#  battles_hotjoin_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Dropped the check of the late guest's wait limit, which only restated the request, and read the box's seconds from the DLL's answer
#      Paulinchen  2026-11-05: Answered the squad math with fixed values per case
#                            - Read the messages sent as the scripts hand them and handed those of other games as the DLL reads them
#                            - Answered the co-op topics with the values each case sets and checked what the scripts ask and do with the answers
#                            - Answered the live battle's topics and the battlers' plans with the values the file sets instead of a copy of the C# rules
#                            - Dropped the checks of the boss table, whose rules the DLL keeps
#                            - Noted invites with their flags as true, as the DLL hands them
#                            - Wrote and read the battle lines through the codec's stand-in
#                            - Told every host's battle state in rbs beside its players in rbn
#                            - Checked that a guest enters its own troop in the Library as its battle starts
#                            - Checked that a guest builds the enemies it adds through the one factory, started once as the game starts them
#                            - Expected a Classic world's player to tell the battle it fights too
#      Paulinchen  2026-11-01: Read the waiting box's lines from its box of the Mod Framework
#      Paulinchen  2026-10-30: Checked that the battle server places joining enemies by the widths of the troop its setup carried
#                            - Read the players taken in from the joins stand-in
#                            - Found the running battle an encounter asks through the asking stand-in
#                            - Handed invites over through the matchmaking's routes
#                            - Placed enemies through the rules in C#, whose troop limit the stand-in names
#                            - Checked the widths of the encounter's pictures a request tells
#      Paulinchen  2026-10-23: Checked that a late guest whose battle ended before its roster goes back to the map, told why
#      Paulinchen  2026-10-12: Read who joined the battle from its popup instead of the chat
#                            - Checked that a live host has its skip settings back as the battle ends
#                            - Checked that a guest drops a host's enemy whose fields are no numbers
#                            - Checked the guest's troop against host enemies with odd places, marks or ids
#      Paulinchen  2026-10-11: Checked party members' offers, closed battles and a host's room for joiners
#                            - Checked that an encounter joins no running battle whose host stands far
#                            - Checked the join notice, the host's waiting list and a late guest's box
#                            - Read the opened windows from battle_support.rb
#      Paulinchen  2026-10-10: Checked a requester whose battle broke off and a guest's rates at the end
#                            - Checked that players a failed request brought along walk on
#                            - Checked that a battle under the Library or Config still takes encounters in
#                            - Checked that an encounter finds a battle under the Library or Config
#                            - Checked the troop limit with fallen enemies and a guest's added enemies
#      Paulinchen  2026-10-09: Checked how a host tells a grown or changed troop and a guest takes it
#                            - Checked eaten enemies for guests and the places of encounters joining in turn
#                            - Checked that an encounter without room adds only the enemies that fit
#                            - Checked that guests fight with the host's enemy rates and get their own back
#                            - Checked that an encounter brings along a player whose window is in the background
#                            - Checked that an encounter's enemies fill the place of a fallen enemy
#                            - Checked an all-foes skill after a hotjoin and a joining guest's enemy names
#                            - Checked that a battle that calls the Library or Config ends nothing
#                            - Checked two crossing requests and that an encounter brings along no fighter
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# Covers hotjoining in a Raid World, battles_coop_hotjoin.rbx with battles_coop.rbx and
# battles_sync.rbx, and the story's boss troops of battles_raid_bosses.rbx: the state a battle
# tells, the encounter that asks a running battle, the host that takes it in or refuses it, the
# command phase that adds the new players and enemies, and the guests that take the grown troop.
# The DLL's asking side, intake, places and list of the players taken in answer with the fixed
# values each case sets; their rules are the C# tests'.

require_relative "battle_support"

# The DLL's arrangement of the battles' players below, by the players
# handed over, each [id, first, party_member_max, characters], answered as [index, Frontline,
# Backline] of each in their order.
$rule_answers.cases("squad.arrange", {
  [["id-me", true, 8, 3]] => [[0, 1, 2]],
  [["id-me", true, 8, 3], ["id-8", false, 4, 3]] => [[0, 1, 2], [1, 1, 2]],
  [["id-me", true, 8, 3], ["id-8", false, 4, 1]] => [[0, 1, 2], [1, 1, 0]],
  [["id-me", true, 8, 3], ["id-11", false, 4, 1]] => [[0, 1, 2], [1, 1, 0]],
  [["id-me", true, 8, 3], ["id-8", false, 4, 3], ["id-11", false, 4, 1]] => [[0, 1, 2], [2, 1, 0], [1, 1, 2]],
  [["id-me", true, 8, 3], ["id-8", false, 4, 1], ["id-11", false, 4, 1]] => [[0, 1, 2], [2, 1, 0], [1, 1, 0]]
}) { |request| request["players"] }
$rule_answers.set("squad.raid", { "regular" => [1, 2], "raid" => [1, 2], "largest" => 3 })

# As the DLL tells: a co-op battle's guests stand on the host's side, the host's stream carries the
# party's and the troop's changes, a flush of the host's recording lets one send go once anything
# was recorded since the last, and an enemy the host marks 1 is hidden, one it marks 2 fallen.
$live.set("live.mode same_side", true)
$live.set("live.mode kinds", ["coop_party", "coop_troop"])
recorded = false
$live.set("live.record") do |request|
  case request["op"]
  when "event", "values" then (recorded = true) && { "sends" => [] }
  when "flush" then { "sends" => recorded ? ["a send"] : [] }.tap { recorded = false }
  end
end
$battlers.plans["enemy"] = lambda { |request| { "hide" => request["mark"] == 1, "lay_down" => request["mark"] == 2 } }

sync = MGQ_MpBattlesSync
hotjoin = MGQ_MpBattlesHotjoin
coop = MGQ_MpBattlesCoop
scene = Scene_Battle.new
spriteset = Spriteset_Battle.new
scene.instance_variable_set(:@spriteset, spriteset)

# The game's settings, whose skip settings a live battle's host turns off.
class Game_System
  attr_reader :conf
  def initialize; @conf = {}; end
end
# An actor with the values the recorder reads.
class Game_Actor
  attr_accessor :tp
  def states; []; end
end
# An enemy with the values the recorder reads.
class Game_Enemy
  attr_accessor :hp, :mp, :tp
  def states; []; end
  def actor?; false; end
  def death_state_id; 1; end
end
$data_states = [nil, :death]
# The party with the game's time stop fields.
class Game_Party; attr_accessor :od_turn, :od_user; end
# The troop with the game's turn count.
class Game_Troop; def turn_count; @turn_count.to_i; end; end
# Stands in for the world, a Raid World while $raid is set.
module MGQ_MpWorld; def self.raid?; $raid; end; end
# Stands in for trading, with no trade running.
module MGQ_MpTrade; def self.session; nil; end; end
# An enemy's database entry, naming its picture.
EnemyData = Struct.new(:battler_name, :battler_hue)
# An enemy's picture, of which only the width is read.
Picture = Struct.new(:width)
# Enemy pictures: those named in $widths are as wide as told, the rest raise KeyError.
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
# battles_sync_live.rbx's, whose hooks need game classes the tests leave out.
#
# @param scene [Scene_Battle] The battle.
def open_phase(scene)
  scene.start_party_command_selection
  return unless MGQ_MpBattlesSync.host?

  MGQ_MpBattlesSync::Live.open_phase(scene)
  MGQ_MpBattlesSync::Recorder.command_phase
end

# Forgets every battle, invite and hotjoin, as after a reset, and gives the scripts a DLL with
# nothing to say.
def reset
  MGQ_MpBattlesCoop.drop
  MGQ_MpBattlesSync.finish
  MGQ_MpBattles.drop
  answer_coop($world_bridge)
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

# Has a co-op topic's step answer a value once, then nil, as a DLL with nothing more to say.
#
# @param key [String] The topic and its step, such as "coop.pending joins".
# @param value [Object] The answer.
def once(key, value)
  answers = [value]
  $coop.set(key) { |_request| answers.shift }
end

# Has the DLL's list of the players taken in hand the host the joins that came at the next command
# phase, while the given number of players taken in has yet to join.
#
# @param count [Integer] The players taken in who have not joined.
# @param joins [Array<Array>] Each joining player's seat and join.
def joins_at_phase(count, *joins)
  $coop.set("coop.pending count", count)
  once("coop.pending joins", joins)
end

# Has a random encounter of troop 50 on the map ask the running battle hb1 of player 5, as the
# DLL's matchmaking and asking side answer, the player becoming that battle's guest until its host
# answers.
#
# @param status [Hash] What the asking side's status says besides that the player asks.
def ask_running(status = {})
  $coop.set("coop.offer", "actions" => [coop_step("ask_hot")])
  $coop.set("coop.ask", { "actions" => [coop_step("join", "role" => "guest", "bid" => "hb1", "seats" => [5], "label" => "P5")], "ask" => true }.merge(status))
  $scene_now = Scene_Map.new
  $game_troop.setup(50)
  $encounter_troop = 50
  $game_player.encounter
  $coop.set("coop.offer", nil)
  $coop.set("coop.ask", nil)
end

# Has the DLL end the wait for the running battle's host with an answer and the request's outcome.
#
# @param wait [String] What the wait answers, such as "accepted".
# @param outcome [Hash, nil] How the request ended, nil when nothing follows.
def answered(wait, outcome)
  $coop.set("coop.ask_wait", wait)
  $coop.set("coop.ask_end", outcome)
end

# Makes the outcome of a request the host took in: the encounter's own escape and lose, and the
# host's with its enemy rates.
#
# @param fields [Hash] What else it says, such as "release", and the host's "rates".
# @return [Hash] The outcome.
def taken_in(fields = {})
  host = { "escape" => false, "lose" => true, "rates" => fields["rates"] }
  { "late" => true, "escape" => true, "lose" => false, "host" => host, "release" => [], "stays_out" => [] }.merge(fields.reject { |key, _| key == "rates" })
end

# Makes the outcome of a request whose encounter starts on its own: its troop, escape and lose.
#
# @param fields [Hash] What else it says, such as "release" or "stays_out".
# @return [Hash] The outcome.
def on_its_own(fields = {})
  { "troop" => 50, "escape" => true, "lose" => false, "release" => [], "stays_out" => [] }.merge(fields)
end

# The game's events mark a boss battle the table lacks.
bosses = MGQ_MpRaidBosses
check("a random troop is no boss", [bosses.boss?(31), bosses.battle?(31)], [false, false])
$game_switches[22] = true
check("but its battle is one while the game's events say so", bosses.battle?(31), true)
$game_switches[22] = false

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
check("so does a Classic world's player, so a party member who missed the battle finds it", hotjoin.state_fields, { "rb" => "g1", "rbh" => "4" })
$raid = true
reset

# An encounter the DLL has ask a running battle.
host = player(5, { "scene" => "battle", "rb" => "hb1", "rbh" => "5", "rbn" => "1", "rbs" => "open", "since" => "100" })
guest = player(6, { "scene" => "battle", "rb" => "hb1", "rbh" => "5" })
free = player(7)
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free])
ask_running
asked = $coop.asked("coop.ask").last
check("a random encounter the DLL has ask a running battle goes to its asking side with the troop, escape, lose and enemies",
      asked.values_at("troop", "escape", "lose", "boss", "entries", "stays_out"), [50, true, false, false, [[50, 0, 0, 0]], []])
check("telling the widths of its enemies' pictures as this game measures them", asked["widths"], [[50, 160]])
check("it waits as that battle's guest", [sync.role, sync.battle_id, sync.seats, coop.asking_hot?], [:guest, "hb1", [5], true])
answered("accepted", taken_in("release" => [7]))
MGQ_MpGame.set(BattleManager, :preemptive, true)
$scene_now = scene
coop::Mode.before_start(scene)
check("taken in, it joins as a guest with the host's escape and lose and no first strike",
      [$coop.asked("coop.ask_end").last, sync.role, hotjoin.own_troop?, MGQ_MpGame.get(BattleManager, :can_escape), MGQ_MpGame.get(BattleManager, :can_lose),
       MGQ_MpGame.get(BattleManager, :preemptive)],
      ["accepted", :guest, true, false, true, false])
check("letting the players it brought along whom the host left out walk on", $coop.asked("coop.ask_release").map { |request| request["seats"] }, [[7]])
$sent.clear
$notices = []
told = "P5's battle ended before you could join."
$coop.set("coop.take_off", "actions" => [coop_step("call_off_own", "label" => told)])
$inject = lambda { |frame| $coop.message(host, { "coop" => "off", "bid" => "hb1", "why" => "over" }) if frame == 3 }
check("the DLL calling it off for the host before the roster starts the encounter on its own, telling the player why",
      [coop.join(scene), $notices], [:gone, [told]])
check("having handed the host's word to the DLL", $coop.asked("coop.take_off").last.values_at("seat", "fields"), [5, { "coop" => "off", "bid" => "hb1", "why" => "over" }])
check("with its own escape and lose back", [MGQ_MpGame.get(BattleManager, :can_escape), MGQ_MpGame.get(BattleManager, :can_lose)], [true, false])
check("having sent its join to the host", battle_sent("join").map(&:first), [5])
reset

ask_running
answered("accepted", taken_in)
$scene_now = scene
coop::Mode.before_start(scene)
$frames = 0
$coop.set("coop.roster_wait frame") { |_request| { "roster" => nil, "late" => $frames >= 3, "frames" => $frames } }
# The waiting box's lines while it waits.
box_lines = nil
$inject = lambda { |frame| box_lines = waiting_lines if frame == 2 }
check("a late guest whose roster runs late fights its encounter alone, telling the host", [coop.join(scene), battle_sent("decline").map(&:first)], [:gone, [5]])
$inject = nil
check("having read how long the wait may last, and the seconds, in its box",
      box_lines, { 0 => "Joining P5's battle at its next turn...", 1 => "Up to #{CoopAnswers::LATE_ROSTER_FRAMES / 60} s", 2 => "0 s" })
reset

ask_running
$sent.clear
answered("refused", on_its_own("release" => [7]))
$coop.set("coop.host", "actions" => [coop_step("join", "role" => "host", "bid" => "x1", "seats" => [7], "label" => "the players")])
$scene_now = scene
coop::Mode.before_start(scene)
check("refused, the player hosts the encounter as the DLL hosts it",
      [$coop.asked("coop.ask_end").last, $coop.asked("coop.host").last.values_at("troop", "escape", "lose"), sync.role, sync.battle_id], ["refused", [50, true, false], :host, "x1"])
check("letting the players it brought along walk on", $coop.asked("coop.ask_release").map { |request| request["seats"] }, [[7]])
reset

ask_running
hotjoin.undo_ask
check("a request taken back ends the player's side of the running battle and goes to the DLL", [sync.role, $coop.asked("coop.ask_undo").size], [nil, 1])
reset

# A party member near, for whom the running battle has no room along with the player: the DLL asks
# the member first whether they start a battle with the player.
member = player(9)
member.member = true
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free, member])
ask_running("ask_party" => true)
$coop.set("coop.ask_party_end", on_its_own)
$coop.set("coop.host", "actions" => [coop_step("join", "role" => "host", "bid" => "x2", "seats" => [9, 7], "label" => "the players")])
$scene_now = scene
coop::Mode.before_start(scene)
check("the member starting one, the encounter starts on its own, the running battle's host never waited for",
      [sync.role, sync.battle_id, $coop.asked("coop.ask_party_wait").size, $coop.asked("coop.ask_wait")], [:host, "x2", 1, []])
reset

ask_running("ask_party" => true)
answered("accepted", taken_in)
$scene_now = scene
coop::Mode.before_start(scene)
check("the member saying no, the player waits for the running battle's host and joins it", [$coop.asked("coop.ask_wait").size, sync.role, sync.battle_id, hotjoin.own_troop?],
      [1, :guest, "hb1", true])
reset

ask_running("ask_party" => true)
answered("refused", on_its_own("stays_out" => [9]))
$scene_now = scene
coop::Mode.before_start(scene)
check("refused then, the encounter starts on its own, leaving out the member who said no", $coop.asked("coop.host").last["stays_out"], [9])
reset
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free])

# The host who fights alone takes an encounter in.
$scene_now = scene
own_troop
MGQ_MpGame.set(BattleManager, :can_escape, true)
MGQ_MpGame.set(BattleManager, :can_lose, false)
coop::RATE_VARIABLES.each { |id| $game_variables[id] = 75 }
hotjoin.fight_alone("own7")
asker = player(8, { "scene" => "battle", "rb" => "own7", "rbh" => "0" })
comrade = player(9)
latecomer = player(10, { "scene" => "battle" })
MGQ_MpOverworldSync::Peers.all.replace([asker, comrade, latecomer])
request = { "coop" => "hot", "bid" => "own7", "troop" => "50", "enemies" => "50:320:300:0", "seats" => [9], "map" => "5" }
$coop.set("coop.intake", "refusal" => nil, "kept" => [8, 9], "left" => [], "room" => 3)
$coop.set("coop.read_entries", [[50, 320, 300, 0]])
$coop.set("coop.place", [[50, 160, 300]])
$coop.message(asker, request)
intake = $coop.asked("coop.intake").last
check("a host's request goes to the DLL's intake as an encounter, with the battle's facts",
      [intake.values_at("kind", "seat", "bid", "troop", "boss_troop", "seats"), intake["facts"].values_at("bid", "host", "role", "players", "boss")],
      [["encounter", 8, "own7", "50", false, [9]], ["own7", 0, nil, 1, false]])
check("taken in, its player hears the battle's escape and lose", map_sent("hot_ok").map { |seat, f| [seat, f["bid"], f["escape"], f["lose"], f["seats"]] }, [[8, "own7", true, false, [8, 9]]])
check("and the player who comes along gets an invite to the running battle with its enemy rates",
      map_sent("invite").map { |seat, f| [seat, f["bid"], f["troop"], f["seats"], f["hot"], f["rates"]] }, [[9, "own7", 31, [9], true, [75, 75, 75, 75, 75, 75]]])
check("the battle becomes the host's, not live until someone joins", [sync.role, sync.live?, sync.expected], [:host, false, [8, 9]])
check("the encounter's enemies are placed where the DLL places them, kept for the next command phase",
      [$coop.asked("coop.read_entries").last, $coop.asked("coop.pending").last], ["50:320:300:0", { "op" => "take_in", "requester" => 8, "seats" => [8, 9], "enemies" => [[50, 160, 300, 0]] }])
place = $coop.asked("coop.place").last
check("asking with the troop, each enemy's id, place, picture width and whether hidden or fallen, the screen's width",
      place.values_at("bid", "troop", "queued", "entries", "screen", "widths"), ["own7", [[31, 320, 160, false, false]], [], [[50, 300, 160]], 640, nil])

$sent.clear
$log.clear
$coop.set("coop.intake", "refusal" => nil, "kept" => [10], "left" => [11], "room" => 1)
$coop.message(latecomer, request.merge("seats" => [11]))
check("a player the DLL leaves out of the request gets no invite", [map_sent("hot_ok").map { |seat, f| [seat, f["seats"]] }, map_sent("invite")], [[[10, [10]]], []])
check("and is named in the log", $log.grep(/left seat 11 out of the request: the battle takes 1 more players/).size, 1)
$sent.clear
$coop.set("coop.intake", "refusal" => ["full", "the battle is full"], "kept" => [], "left" => [], "room" => 0)
refused = player(12, { "scene" => "battle" })
MGQ_MpOverworldSync::Peers.all.push(refused)
$coop.message(refused, request.merge("seats" => [], "troop" => "29"))
check("a request the DLL refuses is told so", map_sent("hot_no").map { |seat, f| [seat, f["bid"]] }, [[12, "own7"]])
check("the intake told the encounter is a boss's", $coop.asked("coop.intake").last["boss_troop"], true)
$coop.set("coop.intake", nil)

$sent.clear
$log.clear
$coop.set("coop.read_entries", [[50, 320, 300, 0], [51, 0, 0, 1], [500, 0, 0, 0]])
$coop.set("coop.place", [])
$coop.message(latecomer, request.merge("enemies" => "50:320:300:0;51:0:0:1;500:0:0:0", "widths" => "50:600", "seats" => []))
check("an encounter's hidden enemies and those this game lacks are never placed, the widths its player measured handed on",
      $coop.asked("coop.place").last.values_at("entries", "widths"), [[[50, 300, 160]], "50:600"])
check("the missing ones logged", $log.grep(/left out the encounter's enemies 500: they are missing from this game/).size, 1)
check("an encounter whose enemies the DLL finds no place for joins without them", [map_sent("hot_ok").map(&:first), $coop.asked("coop.pending").last["enemies"]], [[10], []])
hotjoin.keep_widths("own7", "31:400")
hotjoin.place_anew([[50, 0, 300, 0]], "own7")
check("the widths a served battle's starter measured go to the DLL, which places by them when a placement names none",
      [$coop.asked("coop.keep_widths").last, $coop.asked("coop.place").last.key?("widths")], [{ "bid" => "own7", "widths" => "31:400" }, false])
$coop.set("coop.read_entries", nil)
$coop.set("coop.place", nil)

# The command phase turns the battle live and takes in who joined.
sync::Hooks.ending
$game_system.conf.replace(:bt_skip => true, :skip_skill_effect => 1)
$sent.clear
$chat = []
$notices = []
popups_on(scene)
sync.take(asker, { "battle" => "join", "bid" => "own7", :payload => wire_line(["5,6,7", [[50, 5], [60, 6], [70, 7]], 4]) })
joins_at_phase(2, [8, wire_line(["5,6,7", [[50, 5], [60, 6], [70, 7]], 4])])
once("coop.pending next_added", [[50, 160, 300, 0]])
$coop.set("coop.place", [[50, 160, 300]])
open_phase(scene)
check("the command phase still opens", $commands_phase, true)
check("the host reads in the battle's popup who joined, once, and nothing in the chat", [$popups, $notices, $chat], [["P8 joined the battle."], ["P8 joined the battle."], []])
sync::Departures.joined(asker)
sync::Departures.left(asker)
check("and still reads when they leave later", $popups, ["P8 joined the battle.", "P8 left the battle."])
check("the battle turned live, the player hosting it", [sync.host?, sync.coop?, MGQ_MpBattles.kind, sync::Recorder.active?], [true, true, :coop, true])
check("its skip settings off", $game_system.conf, { :bt_skip => false, :skip_skill_effect => false })
check("with the player who joined as its guest, the others taken in still expected", [sync.guests_in, sync.expected], [[8], [9, 10]])
check("whose first character joins the party", $game_party.battle_members.map(&:name), ["Actor1", "Actor5 (P8)"])
check("and the encounter's enemies the troop, where the DLL places them anew",
      [$game_troop.members.map { |enemy| [enemy.enemy_id, enemy.screen_x, enemy.letter] }, $coop.asked("coop.place").last["entries"]], [[[31, 320, " A"], [50, 160, " A"]], [[50, 300, 160]]])
check("drawn anew", spriteset.enemies.size, 2)
check("the DLL forgetting the players who joined", $coop.asked("coop.pending").select { |r| r["op"] == "remove" }.last, { "op" => "remove", "seats" => [8] })
roster = battle_sent("roster")
check("the player who joined gets the roster", roster.map(&:first), [8])
roster_values = wire_values(roster[0][1][:payload])
check("with the whole troop and both players", [roster_values[0].map(&:first), roster_values[1].map(&:first)], [[31, 50], [0, 8]])
check("and the battle's names, ready", battle_sent("ready").map(&:first), [8])
check("then the command phase's stream", battle_sent("events").map(&:first), [8])

# A second encounter joins the live battle: the guest hears of the new party and troop.
$sent.clear
third = player(11, { "scene" => "battle", "rb" => "own7", "rbh" => "0" })
MGQ_MpOverworldSync::Peers.all.replace([asker, comrade, latecomer, third])
$coop.message(third, request.merge("seats" => [], "enemies" => "51:300:300:0"))
check("a live battle takes another encounter in", map_sent("hot_ok").map(&:first), [11])
sync.take(third, { "battle" => "join", "bid" => "own7", :payload => wire_line(["8", [[40, 4]], 4]) })
sync.take(asker, { "battle" => "ready", "bid" => "own7", :payload => "" })
sync::Live.close_phase
sync::Recorder.turn_started
$sent.clear
$log.clear
joins_at_phase(2, [11, wire_line(["8", [[40, 4]], 4])])
once("coop.pending expire", [[9, "turned the invite down", false], [10, "stopped waiting", false]])
once("coop.pending next_added", [[51, 300, 300, 0]])
$coop.set("coop.place", [[51, 480, 300]])
open_phase(scene)
check("the guest gets the new party and troop before the phase's stream, and whom the host waits for",
      $sent.select { |seat, _| seat == 8 }.map { |_, message| message["battle"] }, ["coop_party", "coop_troop", "waiting", "events"])
check("which is everyone, the host itself included", battle_sent("waiting").map { |seat, fields| [seat, fields[:payload]] }, [[8, "0,8,11"], [11, "0,8,11"]])
check("the new player gets the roster", battle_sent("roster").map(&:first), [11])
check("three players fight, the host first, then by their ids", $game_party.battle_members.map(&:name), ["Actor1", "Actor8 (P11)", "Actor5 (P8)"])
check("the word of the late guest that it is ready is dropped", sync::Channel.pending("ready"), 0)
check("the players the DLL forgot are expected no more, the log saying why",
      [sync.expected, $log.grep(/forgot P9 \(seat 9\), taken into battle own7: turned the invite down/).size], [[], 1])
$coop.set("coop.pending count", nil)
$coop.set("coop.place", nil)

# The guest takes the grown troop.
troop_body = battle_sent("coop_troop").find { |seat, _| seat == 8 }[1][:payload]
BattleManager.battle_end(0)
check("the host has its skip settings back as the battle ends, before the victory autosave writes them", $game_system.conf, { :bt_skip => true, :skip_skill_effect => 1 })
$game_system.conf.clear
reset
sync.join_world(:guest, "own7", [0], "Me")
own_troop
$game_troop.members.push(Game_Enemy.new(1, 50))
coop::Mode.take("coop_troop", scene, troop_body)
check("a guest adds the host's new enemies after its own", $game_troop.members.map { |enemy| [enemy.enemy_id, enemy.screen_x] }, [[31, 320], [50, 0], [51, 480]])
check("drawing them", spriteset.enemies.size, 3)
$game_troop.setup(77)
coop::Mode.take("coop_troop", scene, troop_body)
check("a guest whose enemy differs transforms it as the host's", $game_troop.members.map(&:enemy_id), [31, 50, 51])
$game_troop.members.push(Game_Enemy.new(3, 77))
coop::Mode.take("coop_troop", scene, troop_body)
check("a guest whose troop is longer than the host's takes the host's whole troop", $game_troop.members.map(&:enemy_id), [31, 50, 51])
check("the DLL reading the host's troop against this game's places", $coop.asked("coop.read_troop").last.values_at("own", "count"),
      [[[320, 300], [160, 300], [480, 300], [0, 0]], $data_enemies.size])
kept = $game_troop.members.dup
$log.clear
$coop.set("coop.read_troop", "enemies" => nil, "enemy_dropped" => [], "lacking" => [500], "names" => nil)
coop::Mode.take("coop_troop", scene, troop_body)
$coop.set("coop.read_troop", nil)
check("a host's troop the DLL finds enemies this game lacks in keeps the guest's own, naming them in the log",
      [$game_troop.members, $log.grep(/lacks \(500\)/).size], [kept, 1])
reset

# A late guest takes the battle's turn and waits for its next command phase.
hotjoin.note_invite({ "hot" => true })
sync.join_world(:guest, "lt1", [5], "P5")
sync.battle_started
MGQ_MpOverworldSync::Peers.all.replace([host])
$coop.roster(wire_line([[[31, 320, 300, 0], [50, 160, 300, 1]], [[5, "P5", "1,2,3", [], 4, [0, 1, 2], 1, 2], [0, "Me", "1,2,3", [], 4, [0, 1, 2], 1, 2]], nil, 3]))
check("a late guest takes the roster", coop.join(scene), nil)
check("with the battle's turn", $game_troop.instance_variable_get(:@turn_count), 3)
check("and a hidden enemy hidden", $game_troop.members.map(&:hidden?), [false, true])
reset
hotjoin.note_invite({ "hot" => true })
sync.join_world(:guest, "lt3", [5], "P5")
sync.battle_started
$coop.roster(wire_line([[[31, 320, 300, 0], [50, 160, 300, hotjoin::FALLEN]], [[5, "P5", "1,2,3", [], 4, [0, 1, 2], 1, 2], [0, "Me", "1,2,3", [], 4, [0, 1, 2], 1, 2]], nil, 3]))
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

# A late guest whose host's battle is over before the roster came goes back to the map, told why,
# instead of the battle breaking off; one whose host is gone the same, never fighting it alone.
missed = lambda do |inject, ending_of|
  hotjoin.note_invite({ "hot" => true })
  sync.join_world(:guest, "lt3", [5], "P5")
  sync.battle_started
  $aborted = false
  $notices = []
  $game_message_texts = []
  $inject = inject
  $live.set("live.tick ending", &ending_of)
  ending = coop.join(scene)
  $live.set("live.tick ending", nil)
  $inject = nil
  $live.set("live.end early", "process" => "process_abort", "message" => "The battle broke off.")
  sync::Live.end_early(scene, ending)
  $live.set("live.end early", nil)
  result = [ending, $aborted, $notices, $game_message_texts]
  reset
  result
end
# The DLL tells the battle broke off once the script broke it off, and the other side gone once the
# script told it the host is gone.
broken = lambda { |_request| $live.view["broken"] ? { "ending" => "broken" } : {} }
gone = false
host_gone = lambda { |request| (gone ||= request["gone"].include?(5)) ? { "ending" => "gone" } : {} }
# Hands the scripts the host's word that their battle is over at the wait's second frame.
over = lambda { |frame| $coop.message(host, { "coop" => "off", "bid" => "lt3", "why" => "over" }) if frame == 2 }
$coop.set("coop.take_off", "actions" => [coop_step("miss", "label" => told)])
check("a late guest the DLL tells missed its host's battle goes back to the map, told why", missed.call(over, broken), [:broken, true, [told], []])
check("as does one whose host is gone before the roster came",
      missed.call(lambda { |frame| sync::Seats.presence(host, :gone) if frame == 2 }, host_gone), [:broken, true, [told], []])

# The battle's end tells those taken in who did not join.
$scene_now = scene
own_troop
hotjoin.fight_alone("own8")
MGQ_MpOverworldSync::Peers.all.replace([asker, comrade])
$coop.set("coop.intake", "refusal" => nil, "kept" => [8, 9], "left" => [], "room" => 3)
$coop.message(asker, request.merge("bid" => "own8"))
$sent.clear
SceneManager.instance_variable_set(:@stack, [Scene_Map.new, scene])
scene.terminate
check("a battle that calls the Library or Config ends nothing", [map_sent("off"), hotjoin.state_fields["rb"], sync.role], [[], "own8", :host])
SceneManager.instance_variable_set(:@stack, [Scene_Map.new])
$coop.set("coop.pending count", 2)
$coop.set("coop.pending call_off", [8, 9])
coop.ended
check("the end of the battle calls joining off for those the DLL lists, saying it is over",
      map_sent("off").map { |seat, f| [seat, f["bid"], f["why"]] }, [[8, "own8", "over"], [9, "own8", "over"]])
check("and forgets the player's own battle", [hotjoin.state_fields, sync.role], [{ "rb" => "", "rbh" => "" }, nil])
reset

# A battle whose party command called the Library or Config, which waits on the scene stack.

# Stands in for the game's Library scene.
class Scene_Library; end
$scene_now = scene
own_troop
hotjoin.fight_alone("own21")
SceneManager.instance_variable_set(:@stack, [Scene_Map.new, scene])
$scene_now = Scene_Library.new
check("a battle under the Library or Config still tells itself, as a battle",
      [hotjoin.state_fields, hotjoin.busy_scene], [{ "rb" => "own21", "rbh" => "0" }, "battle"])
MGQ_MpOverworldSync::Peers.all.replace([asker])
$coop.message(asker, request.merge("bid" => "own21", "seats" => []))
check("and takes an encounter in, telling the DLL its battle", [$coop.asked("coop.intake").last["facts"]["bid"], map_sent("hot_ok").map(&:first)], ["own21", [8]])
SceneManager.instance_variable_set(:@stack, [])
$scene_now = Scene_Map.new
check("back on the map no battle is told", [hotjoin.running_battle, hotjoin.busy_scene], [nil, nil])
reset
$scene_now = scene

own_troop
hotjoin.fight_alone("own9")
$coop.message(asker, request.merge("bid" => "own9", "seats" => []))
$coop.set("coop.pending take_off", true)
$coop.message(asker, { "coop" => "off", "bid" => "own9" })
check("a player taken in whose encounter starts on its own after all is forgotten as the DLL settles it, the matchmaking never asked",
      [$coop.asked("coop.pending").select { |r| r["op"] == "take_off" }, sync.expected, $coop.asked("coop.take_off")], [[{ "op" => "take_off", "seat" => 8 }], [], []])
check("and with nobody left to join the battle stays the player's own", [sync.role, sync.live?, hotjoin.state_fields["rb"]], [nil, false, "own9"])
reset

# A late guest who stops waiting without the roster tells the host.
MGQ_MpOverworldSync::Peers.all.replace([host, guest, free])
ask_running
answered("accepted", taken_in)
$scene_now = scene
coop::Mode.before_start(scene)
$sent.clear
$inject = lambda { |frame| $live.set("live.tick ending", "ending" => "broken") if frame == 2 }
check("a requester whose running battle breaks off before the roster stops waiting and fights its encounter on its own", coop.join(scene), :gone)
$live.set("live.tick ending", nil)
check("telling the host", battle_sent("decline").map(&:first), [5])
check("with its encounter's own escape and lose back", [MGQ_MpGame.get(BattleManager, :can_escape), MGQ_MpGame.get(BattleManager, :can_lose)], [true, false])
$battle_started = false
coop.take_over(scene)
check("which starts from its start as the player's own", [$battle_started, sync.role, hotjoin.state_fields["rb"].empty?], [true, nil, false])
reset

# The host forgets the players taken in the DLL finds gone.
$scene_now = scene
own_troop
hotjoin.fight_alone("own10")
MGQ_MpOverworldSync::Peers.all.replace([asker, comrade])
$coop.set("coop.intake", "refusal" => nil, "kept" => [8, 9], "left" => [], "room" => 3)
$coop.message(asker, request.merge("bid" => "own10"))
$coop.set("coop.pending seats", [8, 9, 77])
$coop.set("coop.pending expire", [[8, "left the battle", false], [77, "did not join within 60 s", true]])
$sent.clear
hotjoin.expire
check("a host asks the DLL to forget the players taken in, naming those the world no longer knows", $coop.asked("coop.pending").last, { "op" => "expire", "gone" => [77] })
check("and expects those it forgot no more, telling the one who waited too long that it is off",
      [sync.expected, map_sent("off").map { |seat, f| [seat, f["bid"]] }], [[9], [[77, "own10"]]])
$coop.set("coop.pending expire", nil)
$coop.set("coop.pending count", 1)
$coop.set("coop.pending call_off", [9])
$sent.clear
coop.stand_alone(scene)
check("a battle that goes on alone calls joining off for those who did not join, as it takes nobody more",
      map_sent("off").map { |seat, f| [seat, f["bid"], f["why"]] }, [[9, "own10", "closed"]])
reset

own_troop
hotjoin.fight_alone("own11")
$coop.message(asker, request.merge("bid" => "own11", "seats" => []))
MGQ_MpGame.set(BattleManager, :retry_data, "snapshot")
coop.ended
check("a battle that ends before anyone it took in joined keeps the game's Retry", [MGQ_MpGame.get(BattleManager, :retry_data), sync.role], ["snapshot", nil])
MGQ_MpGame.set(BattleManager, :retry_data, nil)
reset

hotjoin.note_invite({ "boss" => true })
own_troop
hotjoin.fight_alone("own12")
$coop.message(asker, request.merge("bid" => "own12", "seats" => []))
check("a boss battle taken over from its host tells the DLL's intake it is one", $coop.asked("coop.intake").last["facts"]["boss"], true)
reset

# An enemy that falls before the encounter's player joins leaves its place to the encounter's
# enemies.
$scene_now = scene
$game_troop.members = [Game_Enemy.new(0, 31), Game_Enemy.new(1, 32)]
$game_troop.members.zip([240, 400]).each { |enemy, x| enemy.screen_x = x; enemy.screen_y = 300 }
hotjoin.fight_alone("own14")
MGQ_MpOverworldSync::Peers.all.replace([asker])
$coop.message(asker, request.merge("bid" => "own14", "seats" => [], "enemies" => "50:0:300:0"))
$game_troop.members[1].dead = true
sync.take(asker, { "battle" => "join", "bid" => "own14", :payload => wire_line(["5", [[50, 5]], 4]) })
joins_at_phase(1, [8, wire_line(["5", [[50, 5]], 4])])
once("coop.pending next_added", [[50, 80, 300, 0]])
$coop.set("coop.place", [[50, 400, 300]])
$sent.clear
open_phase(scene)
check("an encounter's enemies are placed anew as its player joins, a fallen enemy's place free",
      $coop.asked("coop.place").last["troop"], [[31, 240, 160, false, false], [32, 400, 0, false, true]])
check("and stand where the DLL places them", $game_troop.members.map { |enemy| [enemy.enemy_id, enemy.screen_x] }, [[31, 240], [32, 400], [50, 400]])
check("which the roster of the player who joined tells, the fallen enemy fallen",
      wire_values(battle_sent("roster")[0][1][:payload])[0], [[31, 240, 300, 0], [32, 400, 300, hotjoin::FALLEN], [50, 400, 300, 0]])
reset

# An all-foes skill in a battle that took an encounter in after one of its enemies fell: the host
# aims it at every enemy standing, and the guest who joined names and finds them as the host does.
$scene_now = scene
$game_troop.members = [Game_Enemy.new(0, 1), Game_Enemy.new(1, 1)]
$game_troop.members.zip([218, 421]).each { |enemy, x| enemy.screen_x = x; enemy.screen_y = 332 }
$game_troop.instance_variable_set(:@names_count, {})
MGQ_MpGame.call($game_troop, :make_unique_names)
hotjoin.fight_alone("own15")
MGQ_MpOverworldSync::Peers.all.replace([asker])
$coop.message(asker, request.merge("bid" => "own15", "seats" => []))
$game_troop.members[0].dead = true
sync.take(asker, { "battle" => "join", "bid" => "own15", :payload => wire_line(["5", [[50, 5]], 4]) })
joins_at_phase(1, [8, wire_line(["5", [[50, 5]], 4])])
once("coop.pending next_added", [[1, 218, 332, 0], [1, 421, 332, 0]])
$coop.set("coop.place", [[1, 100, 332], [1, 540, 332]])
$sent.clear
open_phase(scene)
host_troop = $game_troop.members.map { |enemy| [enemy.name, enemy.screen_x, enemy.dead?] }
check("the host letters the added enemies after its own, its fallen one keeping its letter",
      host_troop.map(&:first), ["Enemy1 A", "Enemy1 B", "Enemy1 C", "Enemy1 D"])
# The game aims an all-foes skill at target_members(item).select(&:alive?), its troop's members.
aimed = $game_troop.members.reject { |enemy| enemy.dead? || enemy.hidden? }
check("an all-foes skill on the host reaches every enemy standing, the added ones too",
      aimed.map { |enemy| sync::Recorder.ref(enemy) }, ["e1", "e2", "e3"])
host_entries = wire_values(battle_sent("roster")[0][1][:payload])[0]
host_names = battle_sent("ready")[0][1][:payload]
reset
hotjoin.note_invite({ "hot" => true })
sync.join_world(:guest, "own15", [5], "P5")
sync.battle_started
MGQ_MpOverworldSync::Peers.all.replace([host])
own_troop
players = [[5, "P5", "1,2,3", [], 4, [0, 1, 2], 1, 2], [0, "Me", "1,2,3", [], 4, [0, 1, 2], 1, 2]]
$coop.roster(wire_line([host_entries, players, nil, 3]))
coop.join(scene)
check("a guest who joins rebuilds the troop with the host's places, the fallen enemy fallen",
      $game_troop.members.map { |enemy| [enemy.name, enemy.screen_x, enemy.dead?] }, host_troop)
sync::Names.setup(host_names)
check("so the host's names in its stream need no swapping", sync::Names.swap("Enemy1 B, Enemy1 C and Enemy1 D"), "Enemy1 B, Enemy1 C and Enemy1 D")
check("and the stream's references find the same enemies",
      %w(e1 e2 e3).map { |ref| sync::Playback.battler(ref) }, $game_troop.members[1, 3])
sync::Playback.values(sync::Playback.battler("e3"), 0, 0, 0, [1], [0], [0] * 8, 0)
check("where the hit of the last one added lands", $game_troop.members.map(&:dead?), [true, false, false, true])
reset

# Two encounters that ask at once, each bringing the other's player along.
$scene_now = scene
own_troop
hotjoin.fight_alone("own13")
MGQ_MpOverworldSync::Peers.all.replace([asker, comrade])
$coop.set("coop.intake", "refusal" => nil, "kept" => [8, 9], "left" => [], "room" => 3)
$coop.message(asker, request.merge("bid" => "own13"))
$coop.set("coop.intake", nil)
$coop.set("coop.pending release", [[9, "asks with their own encounter"]])
$sent.clear
$log.clear
$coop.message(comrade, request.merge("bid" => "own13", "seats" => [8], "enemies" => "51:320:300:0"))
taken = $coop.asked("coop.pending").select { |r| %w(release take_in).include?(r["op"]) }.last(2)
check("a player another request brought along has the DLL take them out of it first, then is taken in with their own encounter",
      [taken.map { |r| r.values_at("op", "seat", "requester", "seats") }, map_sent("hot_ok").map(&:first)], [[["release", 9, nil, nil], ["take_in", nil, 9, [9]]], [9]])
check("logged as forgotten from the other request", $log.grep(/forgot P9 \(seat 9\), taken into battle own13: asks with their own encounter/).size, 1)
reset

# The enemy rates: every game of a battle fights with its host's, each player's own back after it.
rates = coop::RATE_VARIABLES
own_rates = lambda { rates.map { |id| $game_variables[id] } }
rates.each { |id| $game_variables[id] = 75 }
$scene_now = Scene_Map.new
MGQ_MpOverworldSync::Peers.all.replace([host])
invite = { "coop" => "invite", "bid" => "rt1", "troop" => "31", "escape" => true, "lose" => false, "seats" => [0], "map" => "5", "rates" => [100, 100, 100, 90, 100, 100] }
$coop.set("coop.poll", "actions" => [coop_step("accept", "seat" => 5, "fields" => invite)])
coop.on_map
$coop.set("coop.poll", nil)
check("a guest fights with its host's enemy rates, such as a special boss's NORMAL on the guest's EASY", [sync.role, own_rates.call], [:guest, [100, 100, 100, 90, 100, 100]])
SceneManager.instance_variable_set(:@stack, [Scene_Map.new])
BattleManager.battle_end(0)
check("and has its own back as the battle ends, before the game's victory saves its autosave", own_rates.call, [75] * 6)
$game_variables[41] = 60
coop.ended
check("which the end of the battle's scene puts back no second time", $game_variables[41], 60)
$game_variables[41] = 75
reset

MGQ_MpOverworldSync::Peers.all.replace([host, guest, free])
ask_running
answered("accepted", taken_in("rates" => [120] * 6))
$scene_now = scene
coop::Mode.before_start(scene)
check("an encounter a running battle takes in fights with that battle's enemy rates", own_rates.call, [120] * 6)
$coop.set("coop.take_off", "actions" => [coop_step("call_off_own")])
$inject = lambda { |frame| $coop.message(host, { "coop" => "off", "bid" => "hb1" }) if frame == 3 }
coop.join(scene)
check("and with its own again once the host called it off", own_rates.call, [75] * 6)
reset

ask_running
answered("accepted", taken_in("rates" => [120] * 6))
$scene_now = scene
coop::Mode.before_start(scene)
$inject = lambda { |frame| $live.set("live.tick ending", "ending" => "broken") if frame == 2 }
coop.join(scene)
$live.set("live.tick ending", nil)
check("and when the running battle broke off before its roster came", own_rates.call, [75] * 6)
reset
coop.borrow_rates("rates" => [1, 2])
coop.borrow_rates("rates" => nil)
check("an invite without the host's enemy rates leaves the player's own", own_rates.call, [75] * 6)
reset

# Lists the kinds of the battle messages one player got.
#
# @param seat [Integer] The player's seat.
# @return [Array<String>] The kinds, in the order sent.
def kinds_to(seat)
  $sent.select { |to, _| to == seat }.map { |_, message| message["battle"] }.compact
end

# Reads the troops a player got in coop_troop messages.
#
# @param seat [Integer] The player's seat.
# @return [Array<Array>] Each message's troop, see MGQ_MpBattlesHotjoin.late_entries.
def troops_to(seat)
  battle_sent("coop_troop").select { |to, _| to == seat }.map { |_, f| wire_values(f[:payload])[0] }
end

# Adds an enemy to the running troop, as another mod may mid-battle: a picture as wide as the
# screen, which leaves every place free.
#
# @param hidden [Boolean] Whether it starts hidden.
# @return [Game_Enemy] The enemy.
def add_wide_enemy(hidden = false)
  enemy = Game_Enemy.new($game_troop.members.size, 61)
  enemy.screen_x = 320
  enemy.screen_y = 280
  enemy.hide if hidden
  $game_troop.members.push(enemy)
  enemy
end

# Enemies added mid-battle by another mod: the host tells its guests once, before the stream that
# names them.
$scene_now = scene
own_troop
hotjoin.fight_alone("own16")
MGQ_MpOverworldSync::Peers.all.replace([asker])
$coop.message(asker, request.merge("bid" => "own16", "seats" => []))
sync.take(asker, { "battle" => "join", "bid" => "own16", :payload => wire_line(["5", [[50, 5]], 4]) })
joins_at_phase(1, [8, wire_line(["5", [[50, 5]], 4])])
once("coop.pending next_added", [[50, 0, 300, 0]])
$coop.set("coop.place", [[50, 160, 300]])
open_phase(scene)
$coop.set("coop.pending count", nil)
$sent.clear
added_enemy = add_wide_enemy
sync::Recorder.event("battler.sprite_effect_type", added_enemy, "appear")
sync::Recorder.flush
check("a host whose troop grew tells its guest the troop before the send that names the new enemy",
      kinds_to(8), ["coop_troop", "events"])
check("the whole troop, the new enemy after the others", troops_to(8).map { |troop| troop.map(&:first) }, [[31, 50, 61]])
$sent.clear
sync::Recorder.event("turn", 2)
sync::Recorder.flush
check("the next send tells the troop no more", kinds_to(8), ["events"])
$sent.clear

hidden_one = add_wide_enemy(true)
sync::Recorder.event("turn", 2)
sync::Recorder.flush
hidden_one.appear
sync::Recorder.event("battler.sprite_effect_type", hidden_one, "appear")
sync::Recorder.flush
check("a hidden enemy added, then appearing, is told twice, each before its send",
      kinds_to(8), ["coop_troop", "events", "coop_troop", "events"])
check("hidden first, then shown", troops_to(8).map { |troop| troop.last.last }, [1, 0])
troop_bodies = battle_sent("coop_troop").map { |_, f| f[:payload] }
$sent.clear
add_wide_enemy
sync::Live.close_phase
sync::Recorder.turn_started
open_phase(scene)
check("an enemy added right before a command phase is told once as it opens, before its stream",
      kinds_to(8) - ["waiting"], ["coop_troop", "events"])

# An encounter taken in at a command phase that another mod's enemies join too: one troop for both.
$sent.clear
newcomer = player(11, { "scene" => "battle", "rb" => "own16", "rbh" => "0" })
MGQ_MpOverworldSync::Peers.all.replace([asker, newcomer])
$coop.message(newcomer, request.merge("bid" => "own16", "seats" => [], "enemies" => "51:300:300:0"))
sync.take(newcomer, { "battle" => "join", "bid" => "own16", :payload => wire_line(["8", [[40, 4]], 4]) })
sync::Live.close_phase
sync::Recorder.turn_started
add_wide_enemy
$sent.clear
joins_at_phase(1, [11, wire_line(["8", [[40, 4]], 4])])
once("coop.pending next_added", [[51, 300, 300, 0]])
$coop.set("coop.place", [[51, 480, 300]])
open_phase(scene)
check("the guest hears of the encounter's enemies and the other mod's in one troop, before the phase's stream",
      [kinds_to(8), troops_to(8).map { |troop| troop.map(&:first) }], [["coop_party", "coop_troop", "waiting", "events"], [[31, 50, 61, 61, 61, 61, 51]]])
check("and the new player of the troop in the roster alone", [kinds_to(11).first, kinds_to(11).count("coop_troop")], ["roster", 0])
reset

# A guest takes the troop that grew by a hidden enemy, then the troop where it appeared.
sync.join_world(:guest, "own16", [0], "Me")
own_troop
$game_troop.members.push(Game_Enemy.new(1, 50), Game_Enemy.new(2, 61))
first = $game_troop.members[0]
coop::Mode.take("coop_troop", scene, troop_bodies[0])
check("a guest adds the host's hidden enemy hidden", $game_troop.members.map(&:hidden?), [false, false, false, true])
coop::Mode.take("coop_troop", scene, troop_bodies[1])
appeared = $game_troop.members[3]
check("and shows it once it appeared on the host, keeping its own enemies",
      [appeared.hidden?, appeared.letter.empty?, $game_troop.members[0].equal?(first), $game_troop.members.size], [false, false, true, 4])
reset

# An encounter whose enemies find less room once another mod added enemies after its request.
$scene_now = scene
own_troop
hotjoin.fight_alone("own17")
MGQ_MpOverworldSync::Peers.all.replace([asker])
$coop.message(asker, request.merge("bid" => "own17", "seats" => []))
6.times { add_wide_enemy }
sync.take(asker, { "battle" => "join", "bid" => "own17", :payload => wire_line(["5", [[50, 5]], 4]) })
joins_at_phase(1, [8, wire_line(["5", [[50, 5]], 4])])
once("coop.pending next_added", [[50, 0, 300, 0], [52, 0, 300, 0]])
$coop.set("coop.place", [[50, 160, 300]])
$log.clear
open_phase(scene)
check("only the enemies the DLL still finds a place for join, the player all the same",
      [$coop.asked("coop.place").last["troop"].size, $game_troop.members.map(&:enemy_id).last(2), $game_party.battle_members.map(&:name)], [7, [61, 50], ["Actor1", "Actor5 (P8)"]])
check("the one left out is logged", $log.grep(/left out 1 of the encounter's 2 enemies \(52\): the troop of 7 has no place left for them/).size, 1)
reset

# Two encounters taken in whose players join in turn: the first to join keeps clear of the place the
# other was given.
$scene_now = scene
own_troop
hotjoin.fight_alone("own19")
late_asker = player(11, { "scene" => "battle", "rb" => "own19", "rbh" => "0" })
MGQ_MpOverworldSync::Peers.all.replace([asker, late_asker])
$coop.message(late_asker, request.merge("bid" => "own19", "seats" => [], "enemies" => "52:0:300:0"))
sync.take(late_asker, { "battle" => "join", "bid" => "own19", :payload => wire_line(["8", [[40, 4]], 4]) })
joins_at_phase(1, [11, wire_line(["8", [[40, 4]], 4])])
once("coop.pending next_added", [[52, 0, 300, 0]])
$coop.set("coop.pending queued", [[50, 480, 300, 0]])
$coop.set("coop.place", [[52, 160, 300]])
open_phase(scene)
check("an encounter whose player joins first is placed around the enemies of one still to join, as the DLL lists them",
      $coop.asked("coop.place").last["queued"], [[50, 480, 160]])
reset

# An enemy the host's party ate, which the game hides, and one that transformed.
$scene_now = scene
own_troop
hotjoin.fight_alone("own20")
MGQ_MpOverworldSync::Peers.all.replace([asker])
$coop.message(asker, request.merge("bid" => "own20", "seats" => []))
sync.take(asker, { "battle" => "join", "bid" => "own20", :payload => wire_line(["5", [[50, 5]], 4]) })
joins_at_phase(1, [8, wire_line(["5", [[50, 5]], 4])])
once("coop.pending next_added", [[50, 0, 300, 0]])
$coop.set("coop.place", [[50, 160, 300]])
open_phase(scene)
$coop.set("coop.pending count", nil)
eaten = $game_troop.members[1]
eaten.dead = true
eaten.hide
eaten.instance_variable_set(:@predationed, true)
$sent.clear
sync::Recorder.event("turn", 2)
sync::Recorder.flush
check("an enemy the host's party ate tells the guests no troop", kinds_to(8), ["events"])
check("and counts as fallen, not hidden, for a late guest", hotjoin.late_entries.map(&:last), [0, hotjoin::FALLEN])
$game_troop.members[0].transform(52)
$sent.clear
sync::Recorder.event("turn", 2)
sync::Recorder.flush
check("an enemy that transformed is told before the send", kinds_to(8), ["coop_troop", "events"])
changed_body = battle_sent("coop_troop")[0][1][:payload]
reset

sync.join_world(:guest, "own20", [0], "Me")
own_troop
$game_troop.members.push(Game_Enemy.new(1, 50))
$game_troop.members[1].screen_x = 160
kept = $game_troop.members[0]
kept.hp = 40
coop::Mode.take("coop_troop", scene, changed_body)
check("a guest transforms its own enemy as the host's, keeping it and its HP",
      [$game_troop.members.map(&:enemy_id), $game_troop.members[0].equal?(kept), kept.hp], [[52, 50], true, 40])
eaten_copy = $game_troop.members[1]
eaten_copy.dead = true
check("and keeps the enemy the host's party ate shown, so its defeat pays out",
      [eaten_copy.hidden?, $game_troop.defeated_members.include?(eaten_copy)], [false, true])
reset

# A guest enters its own troop in the Library as its battle starts, as the game's start enters the
# host's (user decision 2026-11-05), and adds the host's new enemies through the one factory, as the
# host's add_enemies does: the game's own start of each, since the guest's start already ran, and
# the game's Library.

# The Library's enemy entries, noting the ids found.
Discovery = Struct.new(:found) do
  def set_discovery(ids); found.concat(ids); end
end
# The game's Library.
Library = Struct.new(:enemy)
# Stands in for the raid boss's pools, which a guest's grown troop leaves alone.
module MGQ_MpRaidPool
  def self.note_invite(_message); end
  def self.invite_fields(_troop_id = nil); {}; end
  def self.won_already?(_troop_id); false; end
end
library = $game_library
$game_library = Library.new(Discovery.new([]))
sync.join_world(:guest, "own22", [0], "Me")
own_troop
$game_party.in_battle = false
$battle_starts = []
MGQ_MpBattlers.start_guest
coop::Mode.take("coop_troop", scene, wire_line([[[31, 320, 300, 0], [50, 160, 300, 0]], nil]))
grown = $game_troop.members.last
check("a guest enters its own troop in the Library as it starts, and an enemy it adds too, with the game's own start, every enemy started once",
      [grown.enemy_id, $game_troop.members.map { |enemy| $battle_starts.count(enemy) }, $game_library.enemy.found], [50, [1, 1], [31, 50]])
$game_party.in_battle = false
$game_library = library
reset

$raid = false
$coop.message(asker, request)
check("a Classic world takes no request through the party's gate", [map_sent("hot_no"), $coop.asked("coop.intake")], [[], []])
$scene_now = scene
check("no hook of hotjoining failed", $log.grep(/hotjoin.*FAILED/), [])
