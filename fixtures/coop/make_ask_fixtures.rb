#----------------------------------------------------------------
#  make_ask_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#                            - Wrote the texts C# words anew as C# words them
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Writes the golden scenarios of asking a running battle and of joining one by choice
# (fixtures/coop/asks.json) from the scripts of a tree whose battles_coop_hotjoin.rbx and
# battles_coop_join.rbx still ask themselves, as at cac6caba, whose script tests answer the rest of
# the co-op topics by stand-ins checked against their own goldens:
#
#   git archive cac6caba GameScript fixtures | tar -x -C <old tree>
#   ruby fixtures/coop/make_ask_fixtures.rb <old tree>
#
# Each step records the world as the scripts saw it (the players, the party, the facts of the game
# and what only the scripts know of the join prompt), runs one operation and records what was sent,
# what the notification box was told, the log lines of the co-op scripts, the steps only the game
# can take (the actions) and what the operation answered.

require "json"

OLD = File.expand_path(ARGV.shift || abort("usage: make_ask_fixtures.rb <old tree>"))
HERE = __dir__

require File.join(OLD, "GameScript", "Tests", "battle_support")

# The game's settings.
class Game_System
  attr_reader :conf
  def initialize; @conf = {}; end
end
$game_system = Game_System.new
# The world, a Raid World while $raid is set.
module MGQ_MpWorld; def self.raid?; $raid; end; end
# The trading, never running.
module MGQ_MpTrade; def self.session; nil; end; end
# The chat box, typed in while $typing is set.
module MGQ_MpChat; def self.typing?; $typing ? true : false; end; end
# The line color requests and offers share, and the action wheel, never open.
module MGQ_MpActions
  LINE_COLOR = MGQ_MpUi::Style::OWN
  module Wheel; def self.open?; false; end; end
  # A message of the notification box.
  Notice = Struct.new(:key, :text, :color, :label, :accept, :decline, :at)
  def self.offer(_source); end
end
# The emotes, never open.
module MGQ_MpEmotes; def self.open?; false; end; end
# The color of invites in the notification box.
module MGQ_MpCoop; INVITE_COLOR = MGQ_MpUi::Style::OWN; end
# The notification box, each message and drop noted in $box.
module MGQ_MpNotices
  def self.message(key, text, frames = 180); $box << ["message", *box_key(key), text, frames]; end
  def self.drop(key, reason = nil); $box << ["drop", *box_key(key), reason]; end
  # Writes a key as the DLL names it: its name and the seat it names, nil for none.
  def self.box_key(key); key.is_a?(Array) ? [key[0].to_s, key[1]] : [key.to_s, nil]; end
end
# The map, free while the scene is the map and no event runs.
module MGQ_MpOverworldSync
  def self.map_free?; SceneManager.scene.is_a?(Scene_Map) && !$game_map.interpreter.running?; end
end
$down = []
# The hotkeys held in $down.
module MGQ_Multiplayer; module Key; def self.pressed?(code); $down.include?(code); end; end; end
# The raid boss pools: the side battles of $sides by host seat, their labels, and side battles
# started, noted as actions.
module MGQ_MpRaidPool
  def self.side_of(host); ($sides || {})[host.seat]; end
  def self.troop_label(troop); "Boss#{troop}"; end
  def self.start_side(troop, rates); $actions << ["side", troop, rates]; true; end
  def self.note_invite(_message); end
  def self.set_up(_troop); end
  def self.invite_fields(_troop = nil); {}; end
  def self.won_already?(_troop); false; end
  def self.side_battle?(_troop); false; end
end
# The raid boss bar, whose bosses stand $boss_steps away.
module MGQ_MpRaidBar; def self.distance_to_boss(troop, _x, _y); ($boss_steps || {})[troop] || 99; end; end
# The frozen fights, of which $freeze stands near.
module MGQ_MpRaidFreezeUi
  def self.join_target(_x, _y, _distance); $freeze; end
  def self.join(troop); $actions << ["freeze", troop]; end
end

load_script "core_hotkeys"
load_script "battles_coop_join"

COOP = MGQ_MpBattlesCoop
HOTJOIN = MGQ_MpBattlesHotjoin
JOIN = MGQ_MpBattlesJoin
SYNC = MGQ_MpBattlesSync

# Replaces a method of a module for the scenarios.
#
# @param owner [Module] The module.
# @param name [Symbol] The method.
def stand(owner, name, &body)
  owner.singleton_class.send(:define_method, name, &body)
end

# The game's steps the scripts take, noted as actions.
stand(SYNC, :join_world) do |role, bid, seats, label, *_|
  $actions << ["join", role.to_s, bid, seats, label]
  $live = { :role => role, :bid => bid, :seats => seats, :player => label }
end
stand(SYNC, :role) { $live[:role] }
stand(SYNC, :battle_id) { $live[:bid] }
stand(SYNC, :seats) { $live[:seats] }
stand(SYNC, :coop?) { $live[:role] ? true : false }
stand(SYNC, :live?) { $live[:role] ? true : false }
stand(SYNC, :player) { $live[:player].to_s }
stand(SYNC, :battle_started) {}
stand(SYNC, :finish) { $actions << ["finish"] if $live[:role]; $live = { :seats => [] } }
stand(MGQ_MpBattles, :begin) { |*_| $rules = :coop }
stand(MGQ_MpBattles, :running?) { !$rules.nil? }
stand(MGQ_MpBattles, :kind) { $rules }
stand(MGQ_MpBattles, :finish) { $rules = nil }
stand(COOP, :troop_entries) { $entries }
stand(COOP, :borrow_rates) { |message| $actions << ["rates", message["rates"]] }
stand(COOP, :host) { |troop, escape, lose, *_| $actions << ["host", troop, escape ? true : false, lose ? true : false] }
stand(HOTJOIN, :fight_alone) { |*_| $actions << ["fight_alone"] unless SYNC.role }
stand(HOTJOIN, :id_width) { |id| ($id_widths || {})[id] || HOTJOIN::DEFAULT_WIDTH }
stand(MGQ_MpGame, :set) { |owner, name, value| $actions << ["set", name.to_s, value] if owner == BattleManager }
stand(MGQ_MpRaidBosses, :boss?) { |troop| troop == $boss_troop }
stand(SceneManager, :call) { |scene| $actions << ["call", scene.to_s] }

# The clock, in seconds, $now.
class << Time
  alias_method :real_now, :now
  def now; $now ? Time.at($now) : real_now; end
end

# The waits of the battle's start, a frame counted across every wait of a step: $inject runs at
# each frame first, then the wait ends at $end_at with $ending.
module MGQ_MpBattlesSync
  module Waiting
    def self.wait_for(*_args)
      loop do
        $frame += 1
        $inject.call($frame) if $inject
        return $ending.to_sym if $end_at == $frame

        found = yield
        return found if found
      end
    end
  end
end

# The texts C# words anew, each the scripts' wording and the one JoinChoice shows, which names no
# reason.
REWORDED = [[/(Cannot join [^"]*'s battle): [^"]*\./, '\1.']]

# Writes a fixture.
#
# @param name [String] The file's name.
# @param content [Object] What it holds.
def write_cases(name, content)
  text = JSON.pretty_generate(content) + "\n"
  File.write(File.join(HERE, name), REWORDED.inject(text) { |cases, (old, now)| cases.gsub(old, now) })
  puts "wrote #{name}"
end

# Makes another player on map 5.
#
# @param seat [Integer] Their seat.
# @param state [Hash] What their state says besides the defaults.
# @param member [Boolean] Whether they are in the player's party.
# @return [MGQ_MpOverworldSync::Peers::Peer] The player.
def peer(seat, state = {}, member = false)
  MGQ_MpOverworldSync::Peers::Peer.new(seat, { "id" => "id-#{seat}", "name" => "P#{seat}", "map" => "5", "scene" => "map", "x" => "0", "y" => "0", "since" => "300" }.merge(state),
                                       nil, member, nil)
end

# Tells what the scripts know of the join prompt beside the matchmaking's facts: the reasons the
# player may not join a battle now, the side battles the boss battles near offer and the frozen
# fight near.
#
# @return [Hash] "busy", "sides" and "freeze".
def prompt_facts
  sides = MGQ_MpOverworldSync::Peers.all.map do |host|
    side = ($sides || {})[host.seat]
    side && [host.seat, side[0], side[1], MGQ_MpRaidBar.distance_to_boss(side[0], $game_player.x, $game_player.y), MGQ_MpRaidPool.troop_label(side[0])]
  end
  { "busy" => JOIN.busy_reason, "sides" => sides.compact, "freeze" => $freeze, "typing" => $typing ? true : false }
end

# Tells the world the scripts see now.
#
# @return [Hash] The players, the party's leader, the Raid World, the clock and the player's facts.
def world_now
  leader = $leader == :me ? "me" : ($leader ? $leader.seat : nil)
  { "peers" => MGQ_MpOverworldSync::Peers.all.map { |p| { "seat" => p.seat, "state" => p.state.dup, "member" => p.member ? true : false, "away" => false } },
    "leader" => leader, "raid" => $raid ? true : false, "own_seat" => $my_seat.to_i, "since" => $my_since.to_i, "now" => ($now * 1000).round,
    "facts" => COOP.facts.merge("in_battle" => COOP.in_battle_scene?), "prompt" => prompt_facts, "entries" => $entries,
    "widths" => $entries.map { |id, *_| [id, HOTJOIN.id_width(id)] }, "stays_out" => HOTJOIN.stays_out_seats }
end

# Runs one operation of a scenario and records it.
#
# @param steps [Array<Hash>] The scenario's steps.
# @param op [String] The operation.
# @param args [Hash] Its arguments.
# @yield Runs it on the scripts.
def step(steps, op, args = {})
  before = world_now
  $sent.clear
  $log.clear
  $box = []
  $actions = []
  $frame = 0
  result = yield
  # The matchmaking's notices reach the box as the bridge's events of the next frame.
  MGQ_Multiplayer::Bridge.frame
  logs = $log.select { |line| line.start_with?("hotjoin: ", "join battle: ", "co-op battle: ") }
  steps << { "op" => op, "args" => args, "world" => before,
             "outcome" => { "sent" => $sent.map { |seat, text| [seat, text] }, "box" => $box, "actions" => $actions, "logs" => logs, "result" => result } }
end

# Starts a scenario on a fresh Raid World: map 5, the player at (10, 10) in seat 0, no battle.
#
# @param name [String] What it shows.
# @param peers [Array<MGQ_MpOverworldSync::Peers::Peer>] The other players.
# @param leader [Symbol, Integer, nil] The party's leader: :me, a seat, or nil for none.
# @yield [steps] Runs the scenario's steps.
# @return [Hash] The scenario.
def scenario(name, peers, leader = nil)
  $box = []
  $actions = []
  COOP.drop
  HOTJOIN.drop
  JOIN.drop
  MGQ_MpLog.instance_variables.each { |ivar| MGQ_MpLog.instance_variable_set(ivar, {}) if MGQ_MpLog.instance_variable_get(ivar).is_a?(Hash) }
  $raid = true
  $live = { :seats => [] }
  $rules = nil
  $now = 1000.0
  $my_seat = 0
  $my_since = 200
  $typing = false
  $down = []
  $sides = nil
  $boss_steps = nil
  $freeze = nil
  $boss_troop = nil
  $entries = [[50, 320, 300, 0]]
  $id_widths = { 50 => 120 }
  $inject = nil
  $end_at = nil
  $ending = nil
  $scene_now = Scene_Map.new
  $game_map.map_id = 5
  $game_map.interpreter.busy = false
  $game_player.x = 10
  $game_player.y = 10
  $game_variables = Game_Variables.new
  MGQ_MpOverworldSync::Peers.all.replace(peers)
  $leader = leader.is_a?(Integer) ? peers.find { |p| p.seat == leader } : leader
  MGQ_Multiplayer::Bridge.frame
  steps = []
  yield steps
  { "name" => name, "steps" => steps }
end

# Asks the running battle near to take the encounter in, as MGQ_MpBattlesCoop.offer does.
#
# @param steps [Array<Hash>] The scenario's steps.
# @param troop [Integer] The encounter's troop.
def ask(steps, troop = 50)
  step(steps, "ask", "troop" => troop, "escape" => true, "lose" => false, "boss" => troop == $boss_troop) { HOTJOIN.ask(troop, true, false) }
end

# Takes a co-op message as the routes hand it over.
#
# @param steps [Array<Hash>] The scenario's steps.
# @param seat [Integer] The sender's seat.
# @param message [Hash] The message's fields, its kind under "coop".
def take(steps, seat, message)
  step(steps, "take", "seat" => seat, "message" => message) { COOP.take(MGQ_MpOverworldSync::Peers.at(seat), message); nil }
end

# Waits at the battle's start for the answers, as the battle's start does: messages come at frames,
# and the wait may end by itself at a frame.
#
# @param steps [Array<Hash>] The scenario's steps.
# @param inject [Array<Array>] Each message's frame, sender's seat and fields.
# @param end_at [Integer, nil] The frame the wait ends at by itself.
# @param ending [String, nil] How it ends then.
def await(steps, inject = [], end_at = nil, ending = nil)
  step(steps, "await", "inject" => inject, "end_at" => end_at, "ending" => ending) do
    $inject = lambda { |frame| inject.each { |at, seat, message| COOP.take(MGQ_MpOverworldSync::Peers.at(seat), message) if at == frame } }
    $end_at = end_at
    $ending = ending
    HOTJOIN.await(Scene_Battle.new)
    $inject = nil
    $end_at = nil
    { "stays_out" => HOTJOIN.stays_out_seats, "own_troop" => HOTJOIN.own_troop?, "late" => HOTJOIN.late? }
  end
end

# Runs a frame on the map for the join prompt, the hotkey down or not.
#
# @param steps [Array<Hash>] The scenario's steps.
# @param pressed [Boolean] Whether the Join Battle hotkey went down.
# @param changing [Boolean] Whether the map's scene changes.
def prompt(steps, pressed = false, changing = false)
  step(steps, "prompt", "pressed" => pressed, "changing" => changing) do
    $down = pressed ? [MGQ_MpHotkeys.code(:join_battle)] : []
    JOIN.on_map(changing)
    $down = []
    { "text" => JOIN.prompt_text, "asking" => JOIN.asking? }
  end
end

# Reads the party members' offers as the notification box does, each member once.
#
# @param steps [Array<Hash>] The scenario's steps.
def offers(steps)
  step(steps, "offers") do
    MGQ_MpOverworldSync::Peers.all.map { |member| HOTJOIN::Offers.notice_of(member) }.compact.map { |notice| [notice.key[1], notice.text, notice.label, (notice.at.to_f * 1000).round] }
  end
end

# Writes a message as it comes through the map's gate.
#
# @param kind [String] The co-op message's kind.
# @param fields [Hash] Its fields.
# @return [Hash] The message, its kind under "coop" too.
def map_message(kind, fields)
  { "map_coop" => kind, "mmap" => "5" }.merge(fields).merge("coop" => kind)
end

ASKS = []

# A battle near the player on map 5 whose host P5 entered the map first, with the players its
# state tells.
#
# @param count [Integer] The players in it, its "rbn".
# @param state [Hash] What the host's state says besides.
# @return [Array] The host and the guest who fights in it.
def battle_near(count = 2, state = {})
  [peer(5, { "scene" => "battle", "rb" => "hb1", "rbh" => "5", "rbn" => count.to_s, "since" => "100", "x" => "9", "y" => "10" }.merge(state)),
   peer(6, { "scene" => "battle", "rb" => "hb1", "rbh" => "5", "x" => "8", "y" => "10" })]
end

ASKS << scenario("an encounter asks the battle near, bringing the free players it has room for, and joins it late", battle_near + [peer(7, { "x" => "11", "y" => "10" }), peer(8, { "x" => "13", "y" => "10" })]) do |s|
  ask(s)
  await(s, [[2, 5, map_message("hot_ok", "bid" => "hb1", "escape" => "0", "lose" => "1", "rates" => "90,90,90,90,90,90", "seats" => "")]])
end
ASKS << scenario("a refusing host lets the encounter start on its own", battle_near + [peer(7, { "x" => "11", "y" => "10" })]) do |s|
  ask(s)
  take(s, 5, map_message("hot_no", "bid" => "hb1"))
  await(s)
end
ASKS << scenario("a silent host lets the encounter start on its own once the wait ran out", battle_near(1) + [peer(7, { "x" => "11", "y" => "10" })]) do |s|
  ask(s)
  await(s)
end
ASKS << scenario("a wait the battle ends tells the host the encounter starts on its own", battle_near(1)) do |s|
  ask(s)
  await(s, [], 5, "gone")
end
ASKS << scenario("answers of another battle are ignored, the host's word that it is off refuses", battle_near) do |s|
  ask(s)
  take(s, 5, map_message("hot_ok", "bid" => "other"))
  take(s, 6, map_message("hot_ok", "bid" => "hb1"))
  take(s, 5, map_message("off", "bid" => "hb1"))
  await(s)
end
ASKS << scenario("an encounter asks no battle: a boss, a far or full battle, none near", battle_near) do |s|
  $boss_troop = 70
  ask(s, 70)
  $boss_troop = nil
  MGQ_MpOverworldSync::Peers.all.replace(battle_near(2, "x" => "40"))
  ask(s)
  MGQ_MpOverworldSync::Peers.all.replace(battle_near(4))
  ask(s)
  MGQ_MpOverworldSync::Peers.all.replace(battle_near(0))
  ask(s)
  MGQ_MpOverworldSync::Peers.all.replace([peer(7)])
  ask(s)
end
ASKS << scenario("of two battles near the one whose host entered the map first is asked",
                 battle_near + [peer(9, { "scene" => "battle", "rb" => "hb2", "rbh" => "9", "rbn" => "1", "since" => "50", "x" => "11", "y" => "10" })]) do |s|
  ask(s)
end
ASKS << scenario("party members near are asked along where the battle has room for them all",
                 battle_near(1) + [peer(3, { "x" => "10", "y" => "11" }, true), peer(7, { "x" => "11", "y" => "10" }), peer(8, { "x" => "12", "y" => "10" })], 3) do |s|
  ask(s)
end
ASKS << scenario("party members without room are asked to start a battle, and a yes starts it with them",
                 battle_near(3) + [peer(3, { "x" => "10", "y" => "11" }, true), peer(4, { "x" => "10", "y" => "12" }, true), peer(7, { "x" => "11", "y" => "10" })], 3) do |s|
  ask(s)
  await(s, [[3, 3, map_message("party_ans", "bid" => "hb1", "ok" => "1")], [4, 4, map_message("party_ans", "bid" => "hb1", "ok" => "0")]])
end
ASKS << scenario("without a yes the player asks the battle alone, and the members walk on",
                 battle_near(3) + [peer(3, { "x" => "10", "y" => "11" }, true)], 3) do |s|
  ask(s)
  take(s, 4, map_message("party_ans", "bid" => "hb1", "ok" => "1"))
  await(s, [[2, 3, map_message("party_ans", "bid" => "hb1", "ok" => "0")], [6, 5, map_message("hot_no", "bid" => "hb1")]])
end
ASKS << scenario("silent party members count as a no", battle_near(3) + [peer(3, { "x" => "10", "y" => "11" }, true)], 3) do |s|
  ask(s)
  await(s, [[500, 5, map_message("hot_ok", "bid" => "hb1", "escape" => "1", "lose" => "0", "rates" => "", "seats" => "", "served" => "1")]])
end
ASKS << scenario("a request taken back halfway tells its host and lets the players brought along walk on",
                 battle_near + [peer(7, { "x" => "11", "y" => "10" })]) do |s|
  ask(s)
  step(s, "undo") { HOTJOIN.undo_ask; nil }
end

# The party member's side: the offers of the members who join a battle outside the party.
mates = lambda { battle_near + [peer(3, { "x" => "10", "y" => "11" }, true)] }
ASKS << scenario("a member's offers stand in the box until they lapse", mates.call, 3) do |s|
  take(s, 3, map_message("party_hot", "mode" => "join", "host" => "5", "bid" => "hb1", "map" => "9"))
  take(s, 3, map_message("party_hot", "mode" => "join", "host" => "5", "bid" => "hb1", "map" => "5"))
  offers(s)
  $now += 21
  offers(s)
  take(s, 3, map_message("party_hot", "mode" => "start", "host" => "5", "bid" => "hb1", "map" => "5"))
  $now += 7
  offers(s)
  $now += 2
  offers(s)
  take(s, 3, map_message("party_hot", "mode" => "join", "host" => "5", "bid" => "hb1", "map" => "5"))
  MGQ_MpOverworldSync::Peers.at(3).state["rb"] = "other"
  offers(s)
  MGQ_MpOverworldSync::Peers.at(3).state["rb"] = ""
  take(s, 3, map_message("party_hot", "mode" => "join", "host" => "5", "bid" => "hb1", "map" => "5"))
  MGQ_MpOverworldSync::Peers.at(5).state["rb"] = "hb9"
  offers(s)
  MGQ_MpOverworldSync::Peers.at(5).state["rb"] = "hb1"
  take(s, 3, map_message("party_hot", "mode" => "join", "host" => "5", "bid" => "hb1", "map" => "5"))
  $live = { :role => :host, :bid => "own", :seats => [] }
  offers(s)
  $live = { :seats => [] }
end
ASKS << scenario("answering a member's offers", mates.call, 3) do |s|
  take(s, 3, map_message("party_hot", "mode" => "start", "host" => "5", "bid" => "hb1", "map" => "5"))
  step(s, "accept_party", "seat" => 3) { HOTJOIN.accept_party(MGQ_MpOverworldSync::Peers.at(3)); nil }
  take(s, 3, map_message("party_hot", "mode" => "start", "host" => "5", "bid" => "hb1", "map" => "5"))
  step(s, "decline_party", "seat" => 3) { HOTJOIN.decline_party(MGQ_MpOverworldSync::Peers.at(3)); nil }
  take(s, 3, map_message("party_hot", "mode" => "join", "host" => "5", "bid" => "hb1", "map" => "5"))
  step(s, "decline_party", "seat" => 3) { HOTJOIN.decline_party(MGQ_MpOverworldSync::Peers.at(3)); nil }
  take(s, 3, map_message("party_hot", "mode" => "join", "host" => "5", "bid" => "hb1", "map" => "5"))
  take(s, 3, map_message("off", "bid" => "hb1"))
  offers(s)
  step(s, "accept_party", "seat" => 3) { HOTJOIN.accept_party(MGQ_MpOverworldSync::Peers.at(3)); nil }
  take(s, 3, map_message("party_hot", "mode" => "join", "host" => "5", "bid" => "hb1", "map" => "5"))
  step(s, "accept_party", "seat" => 3) { HOTJOIN.accept_party(MGQ_MpOverworldSync::Peers.at(3)); nil }
  take(s, 3, map_message("party_hot", "mode" => "join", "host" => "5", "bid" => "hb1", "map" => "5"))
  $typing = true
  step(s, "accept_party", "seat" => 3) { HOTJOIN.accept_party(MGQ_MpOverworldSync::Peers.at(3)); nil }
  $typing = false
end

# Joining by choice: the prompt and the request.
ASKS << scenario("the prompt offers the nearest battle that takes players in, and a press asks it with the party", mates.call + [peer(7, { "x" => "30" })], 3) do |s|
  prompt(s)
  $typing = true
  prompt(s)
  prompt(s, true)
  $typing = false
  prompt(s, false, true)
  prompt(s, true)
end
ASKS << scenario("a battle near that takes nobody in offers a side battle, else a frozen fight",
                 battle_near(4) + [peer(9, { "scene" => "battle", "rb" => "hb2", "rbh" => "9", "rbn" => "4", "x" => "11", "y" => "11", "since" => "250" })]) do |s|
  $sides = { 5 => [81, "100,100,100,100,100,100"], 9 => [82, "90,90,90,90,90,90"] }
  prompt(s)
  $boss_steps = { 82 => 0 }
  prompt(s)
  prompt(s, true)
  $sides = nil
  $freeze = [83, "Frozen"]
  prompt(s)
  prompt(s, true)
  $freeze = nil
  prompt(s, true)
end
ASKS << scenario("a request waits for the host's answer: a refusal, no answer, an invite", battle_near(1)) do |s|
  prompt(s, true)
  take(s, 5, map_message("pick_no", "bid" => "other", "why" => "full"))
  take(s, 5, map_message("pick_no", "bid" => "hb1", "why" => "full"))
  prompt(s, true)
  $now += 2
  prompt(s)
  $now += 2
  prompt(s)
  prompt(s, true)
  take(s, 5, map_message("pick_no", "bid" => "hb1", "why" => "odd"))
  $live = { :role => :guest, :bid => "hb1", :seats => [5] }
  prompt(s)
  $live = { :seats => [] }
  prompt(s, true)
  $live = { :role => :guest, :bid => "hb7", :seats => [5] }
  prompt(s)
  $live = { :seats => [] }
end

write_cases("asks.json", "scenarios" => ASKS)
