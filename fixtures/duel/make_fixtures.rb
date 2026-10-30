#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the duel handshake next to this file, cases.json, from the script that
# kept it before it moved to C#: battles_duel.rbx (challenges, accepting, the start on both sides,
# declines and call-offs, and a team duel's gathering). Each scenario is a list of steps; a step's
# operations run, then one frame of the duel's tick, after "wait" frames more, and the step records
# the messages sent, the notices, the duel's log lines, the duel waiting to start, the duel started
# last and what the player's state and the lines above the heads read. MGQOnline.Game.Tests replays
# them against the C# handshake.
#
# The parts of the game the handshake hands to the scripts stand in with plain rules, which the
# replay applies too: a team's members are its lines that start with "member=", a free player is
# $free, the player's own team and Frontline are set by the operations, and battle ids are counted.
#
# It runs on the scripts of the commit that added it, with the stand-ins of
# GameScript/Tests/world_support.rb, on Ruby 3.3:
#
#   ruby fixtures/duel/make_fixtures.rb

require "json"
require_relative "../../GameScript/Tests/world_support"

# The lines of the duel and its notices, as the log takes them.
$logs = []
module MGQ_Multiplayer::Log
  # Keeps the duel's lines and the notices' lines.
  def self.write(line)
    $logs << line if line.start_with?("duel: ", "overworld sync: notice: ")
  end
end

# The notices shown.
$notices = []
module MGQ_MpOverworldSync::Status
  class << self
    alias_method :harness_notice, :notice
    # Records the notice, then shows it.
    def notice(text, icon = nil); $notices << text; harness_notice(text, icon); end
  end
end

# The player, in seat 0.
module MGQ_MpOverworldSync::Me
  # Answers the player's seat.
  def self.seat; 0; end
end

# A doing's lapse as the frames left, so the step records them.
module MGQ_MpActions
  # Answers the frames themselves.
  def self.lapse_in(frames); frames; end
end

# The mod, available and up to date.
module MGQ_Multiplayer
  # Answers that the mod is installed.
  def self.available?; true; end
  # Answers that the mod is up to date.
  def self.outdated?; false; end
end

# Stands in for the battles, with none running.
module MGQ_MpBattles
  # Answers that no battle runs.
  def self.running?; false; end
end

# Stands in for the game's objects the wire's codec names, of which a duel sends none.
class Game_Battler; end
# Stands in for an action.
class Game_Action; end
# Stands in for an action's result.
class Game_ActionResult
  # Creates an empty result.
  def initialize(_battler); end
end
# Stands in for an item slot.
class Game_BaseItem; end
# Stands in for a tone.
class Tone; end
# Stands in for the database's entries.
module RPG; class Skill; end; class Item; end; class State; end; class Weapon; end; class Armor; end; end

# The live battle, as far as a duel reaches it outside a battle.
module MGQ_MpBattlesSync
  # Logs nothing of the codec's.
  def self.log_once(_key, _text); end
  # Knows no live battle.
  def self.role; nil; end
  # Records a battle joined.
  def self.join_world(*args); $joined << args; end
  # Names a seat's player by name and seat, as the live battle does outside a battle.
  def self.who(seat)
    return "the player (seat #{seat})" if seat == MGQ_MpOverworldSync::Me.seat

    peer = MGQ_MpOverworldSync::Peers.at(seat)
    name = peer && peer.state && peer.state["name"]
    name ? "#{name} (seat #{seat})" : "seat #{seat}"
  end
  # Sends a message of the live battle, as outside a battle served by the battle server.
  def self.tell(seat, kind, battle_id, body = "")
    MGQ_MpOverworldSync.tell(seat, { "battle" => kind, "bid" => battle_id }, body)
  end
end
load File.expand_path("../../GameScript/Multiplayer/Scripts/battles_sync_wire.rbx", __dir__)

# Reads a text's members as the stand-in rule has them: its lines that start with "member=".
#
# @param text [String] The text.
# @param limit [Integer] The most members read.
# @return [Array<String>] The members.
def member_lines(text, limit)
  text.to_s.split("\n").map(&:strip).select { |line| line.start_with?("member=") }.first(limit)
end

# Stands in for the PvP battles.
module MGQ_MpBattlesPvp
  # The player's team: the game's fingerprint in $game_print, the members in $team, the Backline in
  # $backline_wanted.
  module Team
    # A team's first line, as the real one.
    RULE_LINE = /\Abackline=([01])\r?\n/
    # Answers the game's fingerprint.
    def self.game; $game_print; end
    # Writes the player's team below its rule's line, noting the rule it carries.
    def self.build; @sent = $backline_wanted; "backline=#{$backline_wanted ? 1 : 0}\n#{$team}"; end
    # Answers whether the team sent last carried the Backline.
    def self.sent_backline?; @sent ? true : false; end
    # Answers whether a team carries the Backline, as the real one.
    def self.backline?(text); text.to_s[RULE_LINE, 1] == "1"; end
    # Reads a team's members by the stand-in rule.
    def self.parse(text); member_lines(text.to_s.sub(RULE_LINE, ""), 20); end
  end
  # The player's rule of the Backline, kept in $backline_wanted.
  module Backline
    # Answers the rule.
    def self.wanted?; $backline_wanted; end
  end
  # The PvP battle, which fails to start while $start_fails is set.
  module Battle
    # Answers whether the battle started.
    def self.running?; !$start_fails; end
    # Starts nothing.
    def self.start(*_args); end
  end
end

# Stands in for the co-op battles: the player's Frontline in $coop, the battle ids counted, and the
# squad math of a team duel, whose places only the players' order and count decide.
module MGQ_MpBattlesCoop
  # A player of a battle, as the real one.
  Player = Struct.new(:seat, :name, :builds, :vitals, :max, :order, :front, :bench) do
    # Reads a player from their fields.
    def self.read(fields); fields.is_a?(self) ? fields : new(*fields); end
    # Reads players from their fields.
    def self.read_all(list); Array(list).map { |fields| read(fields) }; end
  end
  # Answers the player's Frontline and party_member_max.
  def self.team_build; $coop.dup; end
  # Counts a battle id.
  def self.new_battle_id; "b#{$ids += 1}"; end
  # Arranges a team duel's players as the real arrange does through SquadMath: the leader first,
  # then by id; the Frontline's four places split between them, none more than their characters.
  def self.arrange(players, _backline = true)
    players = Player.read_all(players)
    counts = players.map { |player| member_lines(player.builds, 14).size }
    ids = players.map { |player| player.seat == 0 ? MGQ_MpOverworldSync::Me.id : (peer = MGQ_MpOverworldSync::Peers.at(player.seat)) ? peer.state["id"].to_s : "" }
    firsts = players.map { |player| (who = player.seat == 0 ? :me : MGQ_MpOverworldSync::Peers.at(player.seat)) ? MGQ_MpCoop.leads?(who) : false }
    order = (0...players.size).sort_by { |index| [firsts[index] ? 0 : 1, ids[index].bytes, index] }
    fronts = (0...players.size).map { |position| 4 / players.size + (position < 4 % players.size ? 1 : 0) }
    order.each_with_index.map do |index, position|
      player = players[index]
      Player.new(player.seat, player.name, player.builds, player.vitals, player.max, (0...counts[index]).to_a, [fronts[position], counts[index]].min, 0)
    end
  end
end

# Stands in for the team battles.
module MGQ_MpBattlesTeam
  # Prepares nothing.
  def self.prepare(*_args); end
  # Names the other side.
  def self.opponent_name; "Side leader"; end
  # Lists no opponents.
  def self.opponents; []; end
end

load_script "battles_duel"

# The player is free on the map while $free is set.
module MGQ_MpBattlesDuel
  # Answers $free.
  def self.free?; $free; end
end

# Forgets everything the scripts keep, as a game that just started.
def fresh
  duel = MGQ_MpBattlesDuel
  duel.instance_variable_set(:@challenge, MGQ_MpCoop::Invite.new)
  %i[@accepted @pending @gathering @called @started].each { |name| duel.instance_variable_set(name, nil) }
  MGQ_MpOverworldSync::Peers.clear
  take_party(nil)
  MGQ_MpLog.instance_variable_set(:@logged, {})
  $open = true
  $free = true
  $game_print = "game-1"
  $team = "member=1;me"
  $coop = ["member=1;me\nmember=2;me", 8]
  $backline_wanted = false
  $start_fails = false
  $ids = 0
  $joined = []
end

# Writes fields and a body as the scripts receive a message.
#
# @param op [Array] ["message", seat, fields, body].
def deliver(op)
  message_from(op[1], op[2], op[3].to_s)
end

# Runs one operation of a step.
#
# @param op [Array] The operation and its arguments.
def run(op)
  duel = MGQ_MpBattlesDuel
  peers = MGQ_MpOverworldSync::Peers
  case op[0]
  when "state" then peer_told(op[1], op[2])
  when "gone" then peers.remove(op[1])
  when "party" then take_party(op[1], op[2].map { |seat| peers.at(seat) }, op[3], op[4] || {})
  when "free" then $free = op[1]
  when "game" then $game_print = op[1]
  when "team" then $team = op[1]
  when "coop" then $coop = [op[1], op[2]]
  when "backline" then $backline_wanted = op[1]
  when "message" then deliver(op)
  when "invite" then duel.invite(op[1])
  when "stop" then duel.stop
  when "accept" then duel.accept(peers.at(op[1]))
  when "decline" then duel.decline(peers.at(op[1]), op[2])
  when "world" then $open = op[1]
  when "on_map" then $start_fails = op[1]; duel.on_map
  else raise "unknown operation #{op[0]}"
  end
end

# Describes the duel waiting to start.
#
# @param pending [MGQ_MpBattlesDuel::Pending, nil] The duel.
# @return [Hash, nil] Its role, id, the other player's seat, their members, the Backline, and a team
#   duel's sides; nil for none.
def pending_of(pending)
  return nil unless pending

  {
    "role" => pending.role.to_s, "bid" => pending.battle_id, "seat" => pending.peer && pending.peer.seat,
    "members" => pending.members, "backline" => pending.backline ? true : false,
    "own" => pending.own && pending.own.map(&:to_a), "other" => pending.other && pending.other.map(&:to_a),
    "same_side" => pending.same_side,
  }
end

# Tells what a step did and how things stand after it.
#
# @return [Hash] The step's outcome.
def outcome
  duel = MGQ_MpBattlesDuel
  fields = duel.state_fields
  challengers = MGQ_MpOverworldSync::Peers.all.select { |peer| peer.state["challenge"].to_s == "1" }.sort_by(&:seat)
  {
    "sent" => $sent.select { |_, text| text.start_with?("duel=", "duel_call=", "battle=") },
    "notices" => $notices.dup,
    "logs" => $logs.dup,
    "pending" => pending_of(duel.instance_variable_get(:@pending)),
    "started" => duel.instance_variable_get(:@started),
    "challenge" => [fields["challenge"], fields["challenge_to"]],
    "doing" => duel.own_doing,
    "challengers" => challengers.map { |peer| [peer.seat, duel.challenged_by?(peer), duel.challenged_by?(peer, false), duel.team_duel?(peer)] },
  }
end

# Plays a scenario's steps.
#
# @param steps [Array<Array>] Each step's operations.
# @return [Array<Hash>] Each step's operations and outcome.
def play(steps)
  fresh
  steps.map do |ops|
    waits = ops.select { |op| op[0] == "wait" }.map { |op| op[1] }.sum
    $sent.clear
    $notices.clear
    $logs.clear
    ops.reject { |op| op[0] == "wait" }.each { |op| run(op) }
    (waits + 1).times { MGQ_MpBattlesDuel.tick($open) }
    # Through JSON at once, since the scripts change the lists they hand out later on.
    { "ops" => ops, "outcome" => JSON.parse(JSON.generate(outcome)) }
  end
end

# A player's state as their game tells it, standing next to the player.
#
# @param id [String] Their id.
# @param name [String] Their name.
# @param more [Hash] Other fields, such as "challenge".
# @return [Hash] The state's fields.
def player(id, name, more = {})
  { "id" => id, "name" => name, "map" => 5, "x" => 4, "y" => 4, "d" => 2, "scene" => "map" }.merge(more)
end

# Writes a team as another game sends it with its accept or its start.
#
# @param team [String] The members.
# @param game [String] The game's fingerprint.
# @param backline [Integer] 1 when the sender's battles have the Backline.
# @return [String] The body.
def team_body(team, game = "game-1", backline = 0)
  MGQ_MpBattlesSync::Wire.line([game, "backline=#{backline}\n#{team}"])
end

# Writes a called player's answer that they are ready.
#
# @param builds [String] Their Frontline.
# @param max [Object] Their party_member_max.
# @param game [String] The game's fingerprint.
# @return [String] The body.
def ready_body(builds, max = 8, game = "game-1")
  MGQ_MpBattlesSync::Wire.line([game, builds, max])
end

# Writes a team duel's sides as its host sends them with the start.
#
# @param hosts [Array<Array>] The host's side, each player's fields.
# @param others [Array<Array>] The other side.
# @return [String] The body.
def sides_body(hosts, others)
  MGQ_MpBattlesSync::Wire.line([hosts, others])
end

FRIEND = player("friend", "Friend")
FAR = FRIEND.merge("x" => 40)
PAL = player("pal", "Pal", "x" => 30, "y" => 30)
MATE = player("mate", "Mate", "x" => 31, "y" => 31, "party" => "friend-p")
FRIEND_TEAM = "member=7;friend\nmember=8;friend"
HOSTS = [[2, "Friend", "member=7;friend", [], 8, [0], 4, 0]]
OTHERS = [[0, "Me", "member=1;me", [], 8, [0], 2, 0], [3, "Pal", "member=3;pal", [], 8, [0], 2, 0]]

SCENARIOS = {
  # A challenge to the players nearby stands for fifteen seconds; one named stands for a minute.
  "challenge runs out" => [
    [["state", 2, FRIEND], ["invite", nil]],
    [["wait", 897]],
    [],
    [["invite", "friend"], ["wait", 2]],
    [["stop"]],
  ],
  # As challenger: an accept starts the duel, which waits on the map as host.
  "accepted as challenger" => [
    [["state", 2, FAR], ["invite", "friend"]],
    [["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["on_map", false]],
  ],
  # As challenged player: accepting waits for the challenger's start, which waits on the map as guest.
  "accepted as challenged" => [
    [["state", 2, FRIEND.merge("challenge" => 1)]],
    [["accept", 2], ["wait", 119]],
    [["message", 2, { "duel" => "start", "bid" => "c1" }, team_body(FRIEND_TEAM, "game-1", 1)]],
    [["on_map", false]],
  ],
  # Challenges reach from afar only when they name the player, and say when a duel has the Backline.
  "challenge lines" => [
    [["state", 2, FAR.merge("challenge" => 1, "challenge_to" => "someone")]],
    [["state", 2, FAR.merge("challenge" => 1, "challenge_to" => "someone,me")]],
    [["state", 2, FRIEND.merge("challenge" => 1, "challenge_backline" => 1)]],
  ],
  # The challenger's Backline holds on both sides.
  "backline" => [
    [["backline", true], ["state", 2, FRIEND], ["invite", nil]],
    [["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["on_map", false]],
  ],
  # Declining: the challenged player tells why; the challenger stops naming them.
  "declined" => [
    [["state", 2, FAR.merge("challenge" => 1, "challenge_to" => "me")], ["decline", 2, "no"]],
    [["invite", "friend"], ["message", 2, { "duel" => "decline", "reason" => "no" }]],
    [["message", 2, { "duel" => "decline", "reason" => "busy" }], ["message", 2, { "duel" => "decline", "reason" => "odd" }]],
  ],
  # An accepted challenge the challenger never answers runs out after six seconds.
  "unanswered" => [
    [["state", 2, FRIEND.merge("challenge" => 1)], ["invite", nil], ["accept", 2]],
    [["wait", 358]],
    [],
  ],
  # Why a duel does not start: busy players, a start nobody accepted, an accept without a challenge.
  "busy" => [
    [["state", 2, FRIEND.merge("challenge" => 1)], ["free", false], ["accept", 2]],
    [["invite", nil], ["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["free", true], ["stop"], ["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["message", 2, { "duel" => "start", "bid" => "s1" }, team_body(FRIEND_TEAM)]],
    [["accept", 2], ["free", false], ["message", 2, { "duel" => "start", "bid" => "s2" }, team_body(FRIEND_TEAM)]],
  ],
  # Another version of the game, or a team that does not read, ends the duel at once.
  "fingerprint and team" => [
    [["state", 2, FRIEND.merge("challenge" => 1)], ["invite", nil], ["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM, "game-2")]],
    [["message", 2, { "duel" => "accept" }, team_body("nobody")]],
    [["message", 2, { "duel" => "accept" }, "?broken\t["]],
    [["accept", 2], ["message", 2, { "duel" => "start", "bid" => "s3" }, team_body(FRIEND_TEAM, "game-2")]],
    [["accept", 2], ["message", 2, { "duel" => "start", "bid" => "s4" }, team_body("")]],
  ],
  # A duel waiting to start is called off when the player got busy or its battle could not start.
  "withdrawn" => [
    [["state", 2, FRIEND.merge("challenge" => 1)], ["accept", 2], ["message", 2, { "duel" => "start", "bid" => "w1" }, team_body(FRIEND_TEAM)]],
    [["free", false], ["on_map", false]],
    [["free", true], ["accept", 2], ["message", 2, { "duel" => "start", "bid" => "w2" }, team_body(FRIEND_TEAM)]],
    [["on_map", true]],
  ],
  # Call-offs: of a duel waiting to start, of one started, and of another duel.
  "call-offs" => [
    [["state", 2, FRIEND.merge("challenge" => 1)], ["accept", 2], ["message", 2, { "duel" => "start", "bid" => "x1" }, team_body(FRIEND_TEAM)],
     ["message", 2, { "duel" => "cancel", "bid" => "x1", "reason" => "off" }]],
    [["on_map", false]],
    [["accept", 2], ["message", 2, { "duel" => "start", "bid" => "x2" }, team_body(FRIEND_TEAM)]],
    [["on_map", false]],
    [["message", 2, { "duel" => "cancel", "bid" => "x2", "reason" => "busy" }], ["message", 2, { "duel" => "cancel", "bid" => "x0", "reason" => "team" }]],
    [["message", 2, { "duel" => "cancel", "bid" => "", "reason" => "late" }]],
  ],
  # A challenger who leaves never answers; a message from a game without a state is dropped.
  "challenger leaves" => [
    [["state", 2, FRIEND.merge("challenge" => 1)], ["accept", 2]],
    [["gone", 2], ["message", 7, { "duel" => "start", "bid" => "g1" }, team_body(FRIEND_TEAM)], ["wait", 359]],
  ],
  # The world closing forgets every challenge and answer; a start that comes after is called off.
  "world closes" => [
    [["state", 2, FRIEND.merge("challenge" => 1)], ["accept", 2], ["invite", "friend"]],
    [["world", false]],
    [["world", true], ["message", 2, { "duel" => "start", "bid" => "z1" }, team_body(FRIEND_TEAM)]],
  ],
  # As a party's leader: both sides are called, and the duel starts once all are ready.
  "team duel" => [
    [["state", 2, FRIEND], ["state", 3, PAL], ["party", "me-p", [3], -1], ["state", 3, PAL.merge("party" => "me-p")], ["invite", nil]],
    [["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["message", 3, { "duel" => "ready", "bid" => "b1" }, ready_body("member=3;pal")], ["wait", 10]],
    [["message", 2, { "duel" => "ready", "bid" => "b1" }, ready_body("member=7;friend\nmember=8;friend")]],
    [["on_map", false]],
  ],
  # A player not ready in ten seconds is left out; nobody of the other side ready calls it off.
  "team duel runs out" => [
    [["state", 2, FRIEND], ["state", 3, PAL], ["party", "me-p", [3], -1], ["state", 3, PAL.merge("party" => "me-p")], ["invite", nil]],
    [["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["message", 2, { "duel" => "ready", "bid" => "b1" }, ready_body("member=7;friend")], ["message", 2, { "duel" => "ready", "bid" => "b1" }, ready_body("member=7;friend", [8])],
     ["message", 2, { "duel" => "ready", "bid" => "b1" }, ready_body("member=7;friend", "8")], ["message", 3, { "duel" => "ready", "bid" => "b9" }, ready_body("member=3;pal")]],
    [["wait", 598]],
    [["invite", nil], ["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)], ["wait", 600]],
  ],
  # Players leaving while their sides gather, and a challenger who gets busy, which calls it off.
  "team duel players leave" => [
    [["state", 2, FRIEND], ["state", 3, PAL], ["party", "me-p", [3], -1], ["state", 3, PAL.merge("party" => "me-p")], ["invite", nil]],
    [["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["message", 3, { "duel" => "ready", "bid" => "b1" }, ready_body("member=3;pal")], ["message", 2, { "duel" => "ready", "bid" => "b1" }, ready_body("member=7;friend")],
     ["gone", 3], ["party", "me-p", [], -1]],
    [["state", 3, PAL], ["party", "me-p", [3], -1], ["state", 3, PAL.merge("party" => "me-p")], ["invite", nil], ["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["message", 3, { "duel" => "ready", "bid" => "b2" }, ready_body("member=3;pal")], ["gone", 2], ["wait", 600]],
    [["state", 2, FRIEND], ["invite", nil], ["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["free", false]],
  ],
  # Another game's answer that it is ready, from another version of the game, is declined.
  "team duel fingerprint" => [
    [["state", 2, FRIEND], ["state", 3, PAL], ["party", "me-p", [3], -1], ["state", 3, PAL.merge("party" => "me-p")], ["invite", nil]],
    [["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["message", 3, { "duel" => "ready", "bid" => "b1" }, ready_body("member=3;pal", 8, "game-2")]],
  ],
  # The player who accepted leads a party too: whom they call joins their side, also ready earlier.
  "team duel other party" => [
    [["state", 2, FRIEND.merge("party" => "friend-p")], ["state", 3, PAL], ["state", 4, MATE], ["party", "me-p", [3], -1, { "parties" => { "me-p" => [2, -1], "friend-p" => [2, 2] } }],
     ["state", 3, PAL.merge("party" => "me-p")], ["invite", nil]],
    [["message", 2, { "duel" => "accept" }, team_body(FRIEND_TEAM)]],
    [["message", 4, { "duel" => "ready", "bid" => "b1" }, ready_body("member=9;mate")], ["message", 3, { "duel" => "side", "bid" => "b1", "seats" => "4" }],
     ["message", 2, { "duel" => "side", "bid" => "b1", "seats" => "4,9,3,4" }], ["message", 2, { "duel" => "side", "bid" => "b7", "seats" => "4" }]],
    [["message", 2, { "duel" => "ready", "bid" => "b1" }, ready_body(FRIEND_TEAM)], ["message", 3, { "duel" => "ready", "bid" => "b1" }, ready_body("member=3;pal")]],
    [["on_map", false]],
  ],
  # Called to a team duel: only by the challenger the player accepted; as leader, the player passes
  # the call on; once free, they answer, and the host's start waits on the map.
  "team duel called" => [
    [["state", 2, FRIEND.merge("challenge" => 1)], ["state", 3, PAL], ["party", "me-p", [3], -1], ["state", 3, PAL.merge("party" => "me-p")],
     ["message", 2, { "duel" => "team", "bid" => "g8" }]],
    [["accept", 2], ["free", false], ["message", 2, { "duel" => "team", "bid" => "g9" }], ["wait", 5]],
    [["free", true]],
    [["message", 3, { "duel" => "start", "bid" => "g9", "team" => "1" }, sides_body(HOSTS, OTHERS)], ["message", 2, { "duel" => "start", "bid" => "g7", "team" => "1" }, sides_body(HOSTS, OTHERS)],
     ["message", 2, { "duel" => "start", "bid" => "g9", "team" => "1" }, sides_body(HOSTS, OTHERS)]],
    [["on_map", false]],
  ],
  # A team duel's start the player cannot take: busy, or sides that do not read.
  "team duel start refused" => [
    [["state", 2, FRIEND.merge("challenge" => 1)], ["accept", 2], ["message", 2, { "duel" => "team", "bid" => "g10" }]],
    [["free", false], ["message", 2, { "duel" => "start", "bid" => "g10", "team" => "1" }, sides_body(HOSTS, OTHERS)]],
    [["free", true], ["accept", 2], ["message", 2, { "duel" => "team", "bid" => "g11" }]],
    [["message", 2, { "duel" => "start", "bid" => "g11", "team" => "1" }, "?too long\t]"]],
    [["accept", 2], ["message", 2, { "duel" => "team", "bid" => "g12" }]],
    [["message", 2, { "duel" => "start", "bid" => "g12", "team" => "1" }, ""]],
  ],
  # A call nobody starts is forgotten; a call-off drops it.
  "team duel call lapses" => [
    [["state", 2, FRIEND.merge("challenge" => 1)], ["accept", 2], ["free", false], ["message", 2, { "duel" => "team", "bid" => "g13" }]],
    [["wait", 958]],
    [],
    [["free", true], ["accept", 2], ["message", 2, { "duel" => "team", "bid" => "g14" }]],
    [["message", 2, { "duel" => "cancel", "reason" => "off" }]],
  ],
  # A party's member is called through their leader, never by the challenger alone.
  "team duel passed call" => [
    [["state", 2, FRIEND.merge("party" => "friend-p")], ["state", 3, PAL.merge("party" => "friend-p")], ["party", "friend-p", [2, 3], 2]],
    [["message", 3, { "duel" => "team", "bid" => "g20" }], ["message", 3, { "duel_call" => "g21", "party" => "friend-p", "seat" => "2" }]],
    [["message", 2, { "duel_call" => "g22", "party" => "friend-p", "seat" => "9" }]],
    [["message", 2, { "duel_call" => "g23", "party" => "friend-p", "seat" => "3" }]],
  ],
}.freeze

cases = { "scenarios" => SCENARIOS.map { |name, steps| { "name" => name, "steps" => play(steps) } } }
File.write(File.join(__dir__, "cases.json"), JSON.pretty_generate(cases) + "\n")
puts "wrote #{cases['scenarios'].size} scenarios to #{File.join(__dir__, 'cases.json')}"
