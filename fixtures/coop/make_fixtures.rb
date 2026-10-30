#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Recorded the invites, the requests to lead and the rivals
#                            - Wrote the golden scenarios of the matchmaking: offers, holds, the stand-still and the encounter's steps
#                            - Wrote the golden cases of the battle's level, the roster's lines and the troop's repair
#                            - Created
#
#----------------------------------------------------------------

# Writes the golden cases of the co-op battles' rules next to this file from the scripts of commit
# e2a51fe5, the last that kept them in Ruby (battles_coop*.rbx), which MGQOnline.Game.Tests replays
# against MGQOnline.Game's Coop folder and GameScript/Tests/coop_support.rb checks its stand-ins
# against:
#
# - placement.json: the places battles_coop_hotjoin.rbx's place_anew found for an encounter's
#   enemies in a troop, each enemy's width as the game measured it.
# - entries.json: the troop's enemies a request carries, written and read.
# - intake.json: what a host told of a request to join its running battle, by hotjoin (refusal and
#   fitting_players) and by choice (battles_coop_join.rbx's closed_reason and refusal), and the "rbn"
#   its state told, for the facts of its battle.
# - roster.json: the battle's level, the roster and party lines read and written, and the host's
#   troop repaired on a guest.
# - match.json: scenarios of the matchmaking (offers, held encounters, the stand-still and the
#   encounter's steps), each step with the world as the script saw it and what it sent, showed,
#   logged and had the scripts do; GameScript/Tests/match_support.rb replays them on its stand-in.
#
# It runs on the old scripts with their own test support, on Ruby 3.3:
#
#   git archive e2a51fe5 GameScript fixtures Relay/seed | tar -x -C <old>
#   ruby fixtures/coop/make_fixtures.rb <old>

require "json"

OLD = File.expand_path(ARGV.shift || abort("usage: make_fixtures.rb <old tree>"))
HERE = __dir__

Dir.chdir(File.join(OLD, "GameScript", "Tests"))
require File.join(OLD, "GameScript", "Tests", "battle_support")
# The line color battles_coop_join.rbx's prompt draws in, and the battle's end, while $ending is set.
module MGQ_MpActions; LINE_COLOR = MGQ_MpUi::Style::OWN; end
module BattleManager; def self.battle_end?; $ending ? true : false; end; end
# The world, a Raid World while $raid is set.
module MGQ_MpWorld; def self.raid?; $raid; end; end
load_script "battles_coop_join"

HOTJOIN = MGQ_MpBattlesHotjoin
JOIN = MGQ_MpBattlesJoin

# Writes a golden file.
#
# @param name [String] The file.
# @param content [Hash] Its content.
def write_cases(name, content)
  File.write(File.join(HERE, name), JSON.generate({ "source" => "battles_coop*.rbx at e2a51fe5, Ruby #{RUBY_VERSION}" }.merge(content)) + "\n")
  puts "wrote #{name}"
end

# Replaces a module's method for the cases, as the facts of a case tell it.
#
# @param owner [Module] The module.
# @param name [Symbol] The method.
# @yield What the method answers.
def stand(owner, name, &body)
  owner.define_singleton_method(name, &body)
end

# Placement: the troop's enemies, those queued and the new ones, each with its width.

# An enemy of the troop: its place, width and whether it is hidden or fallen.
PlaceEnemy = Struct.new(:screen_x, :screen_y, :width, :hidden, :fallen) do
  def hidden?; hidden; end
  def dead?; fallen; end
  def death_state?; fallen; end
end

# Finds the places of a case's new enemies as the old place_anew did.
#
# @param entry [Hash] The case: "troop" ([x, width, hidden, fallen] each), "queued" ([id, x, width]
#   each), "entries" ([id, y, width] each) and "screen".
# @return [Array<Array>] Each enemy placed as [id, x, y].
def placed(entry)
  widths = {}
  entry["queued"].each { |id, _, width| widths[id] = width }
  entry["entries"].each { |id, _, width| widths[id] = width }
  troop = entry["troop"].map { |x, width, hidden, fallen| PlaceEnemy.new(x, 300, width, hidden, fallen) }
  $game_troop.members = troop
  stand(HOTJOIN, :enemy_width) { |enemy| enemy.width }
  stand(HOTJOIN, :id_width) { |id| widths.fetch(id) }
  stand(HOTJOIN, :screen_width) { entry["screen"] }
  HOTJOIN.instance_variable_set(:@pending, [{ :requester => 9, :seats => [9], :enemies => entry["queued"].map { |id, x, _| [id, x, 280, 0] }, :added => false }])
  HOTJOIN.place_anew(entry["entries"].map { |id, y, _| [id, 0, y, 0] }).map { |id, x, y, _| [id, x, y] }
end

# Makes a placement case.
#
# @param name [String] What it shows.
# @param troop [Array<Array>] The troop's enemies.
# @param entries [Array<Array>] The new enemies.
# @param queued [Array<Array>] The enemies queued before.
# @param screen [Integer] The screen's width.
# @return [Hash] The case.
def placement(name, troop, entries, queued = [], screen = 640)
  entry = { "name" => name, "troop" => troop, "queued" => queued, "entries" => entries, "screen" => screen }
  entry.merge("placed" => placed(entry))
end

PLACEMENT = [
  placement("one enemy beside one in the middle", [[320, 160, false, false]], [[40, 290, 160]]),
  placement("two enemies beside one in the middle", [[320, 160, false, false]], [[40, 290, 160], [41, 295, 160]]),
  placement("a picture as wide as the screen stands in its middle", [[320, 160, false, false]], [[61, 280, 640]]),
  placement("a wider picture than the screen too", [[320, 160, false, false]], [[61, 280, 700]]),
  placement("a full-width enemy of the troop hides nothing", [[320, 640, false, false]], [[40, 290, 160]]),
  placement("a fallen enemy's place is free", [[320, 160, false, true]], [[40, 290, 160]]),
  placement("a hidden enemy's place is free", [[320, 160, true, false]], [[40, 290, 160]]),
  placement("a wide enemy leaves room at its sides only", [[320, 600, false, false]], [[40, 290, 160]]),
  placement("no place hides at most half", [[320, 600, false, false]], [[60, 290, 600]]),
  placement("only the enemies that still find a place", [[100, 200, false, false], [540, 200, false, false]], [[40, 290, 200], [41, 290, 200], [42, 290, 200]]),
  placement("queued enemies keep their places", [[320, 160, false, false]], [[40, 290, 160]], [[50, 160, 160]]),
  placement("the troop limit counts the fallen and the queued", Array.new(5) { |i| [80 + i * 120, 100, false, i < 2] }, [[40, 290, 100], [41, 290, 100]], [[50, 600, 100]]),
  placement("a full troop takes none", Array.new(8) { |i| [40 + i * 80, 60, false, false] }, [[40, 290, 60]]),
  placement("odd widths lose a pixel at each side", [[321, 161, false, false]], [[40, 290, 163], [41, 291, 99]]),
  placement("a narrower screen", [[272, 160, false, false]], [[40, 290, 160], [41, 290, 160]], [], 544),
  placement("an enemy wider than half the screen beside nothing", [], [[40, 290, 400]]),
  placement("no enemy at all", [[320, 160, false, false]], []),
  placement("an enemy off the screen", [[900, 160, false, false]], [[40, 290, 160]]),
]

write_cases("placement.json", "constants" => { "troop_limit" => HOTJOIN::TROOP_LIMIT, "max_overlap" => HOTJOIN::MAX_OVERLAP, "place_step" => HOTJOIN::PLACE_STEP },
                              "cases" => PLACEMENT)

# The troop's enemies a request carries.

READS = ["31:320:300:0;32:160:300:1", "", "31:320:300", "31:320:300:0:9", "0:1:2:3;-4:1:2:3;5:1:2:3", "a:b:c:d;7:x:9:1",
         " 12:1:2:0;13:-5:+6:0", "1:1:1:0;2:1:1:0;3:1:1:0;4:1:1:0;5:1:1:0;6:1:1:0;7:1:1:0;8:1:1:0;9:1:1:0",
         "31:320:300:0;", ";31:320:300:0", "31::300:0", "31:320:300:0;;32:1:2:3", "1e3:1:2:3", "0x1F:1:2:3", "2_0:1:2:3"]
WRITES = [[[31, 320, 300, 0], [32, 160, 300, 1]], [], [[31, 320, 300, 0, 9]], [[31, 320, 300]], [[31, -5, 300, 2]]]

write_cases("entries.json", "reads" => READS.map { |text| { "text" => text, "entries" => HOTJOIN.parse_entries(text) } },
                            "writes" => WRITES.map { |entries| { "entries" => entries, "text" => HOTJOIN.entries_text(entries) } })

# The intake of a host: the facts of its battle, then what it tells of requests.

# The facts of a battle the player hosts alone with nothing in the way.
BASE_FACTS = { "bid" => "b1", "host" => 0, "own_seat" => 0, "role" => "host", "seats" => [], "live" => false, "active" => false, "solo" => false,
               "ending" => false, "boss" => false, "pvp" => false, "players" => 1, "pending" => [], "map" => 5 }

# Sets the old scripts' facts as a case tells them.
#
# @param facts [Hash] The facts.
def set_facts(facts)
  sync = MGQ_MpBattlesSync
  stand(HOTJOIN, :running_battle) { facts["bid"] ? [facts["bid"], facts["host"]] : nil }
  stand(MGQ_MpOverworldSync::Me, :seat) { facts["own_seat"] }
  stand(sync, :role) { facts["role"] && facts["role"].to_sym }
  stand(sync, :seats) { facts["seats"] }
  stand(sync, :live?) { facts["live"] }
  stand(sync, :solo?) { facts["solo"] }
  stand(MGQ_MpBattlesCoop, :active?) { facts["active"] }
  $ending = facts["ending"]
  stand(HOTJOIN, :boss_battle?) { facts["boss"] }
  stand(MGQ_MpBattles, :kind) { facts["pvp"] ? :pvp : :coop }
  stand(HOTJOIN, :players_count) { facts["players"] }
  stand(HOTJOIN, :pending_seats) { facts["pending"] }
  $game_map.map_id = facts["map"]
  $raid = true
end

# Makes an intake case.
#
# @param name [String] What it shows.
# @param change [Hash] The facts that differ from BASE_FACTS.
# @param request [Hash] The request: "seat", "bid", "troop", "boss_troop", "map" and "seats".
# @return [Hash] The case.
def intake(name, change, request = {})
  facts = BASE_FACTS.merge(change)
  request = { "seat" => 3, "bid" => "b1", "troop" => "40", "boss_troop" => false, "map" => "5", "seats" => "" }.merge(request)
  set_facts(facts)
  stand(MGQ_MpRaidBosses, :boss?) { |_troop| request["boss_troop"] }
  message = { "bid" => request["bid"], "troop" => request["troop"], "map" => request["map"], "seats" => request["seats"] }
  known = (facts["role"] ? facts["seats"] : []) + facts["pending"] + [facts["own_seat"], request["seat"]]
  others = request["seats"].to_s.split(",").map(&:to_i) - known
  seats = [request["seat"]] + others
  fitting = HOTJOIN.fitting_players(seats)
  room = MGQ_MpBattlesCoop::RAID_PLAYERS - facts["players"] - facts["pending"].size
  { "name" => name, "facts" => facts, "request" => request, "hot" => HOTJOIN.refusal(message, request["seat"]),
    "kept" => fitting, "left" => seats - fitting, "room" => room, "pick" => JOIN.refusal(request["seat"], message), "rbn" => JOIN.state_fields["rbn"] }
end

INTAKE = [
  intake("a battle fought alone takes a player in", {}),
  intake("no battle", "bid" => nil, "host" => nil),
  intake("a guest's battle", "host" => 7, "role" => "guest", "seats" => [7]),
  intake("a request for another battle", {}, "bid" => "b2"),
  intake("a request without a battle's id", {}, "bid" => nil),
  intake("a battle that still gathers", "live" => true, "active" => false),
  intake("a battle the computer plays on", "live" => true, "active" => true, "solo" => true),
  intake("a battle that ends", "ending" => true),
  intake("a boss battle", "boss" => true),
  intake("an encounter of a boss troop", {}, "boss_troop" => true),
  intake("a player who was in the battle before", "seats" => [3], "players" => 1),
  intake("a player taken in already", "pending" => [3]),
  intake("a full battle", "players" => 3, "pending" => [8]),
  intake("a PvP battle", "pvp" => true),
  intake("a request from another map", {}, "map" => "6"),
  intake("a request from a map that is no number", {}, "map" => "x"),
  intake("a live battle of two taking two more", { "live" => true, "active" => true, "players" => 2, "seats" => [4] }, "seats" => "5,6"),
  intake("a request bringing more players than the battle takes", { "players" => 2, "pending" => [8] }, "seats" => "5,6,7"),
  intake("a request bringing players known already", { "role" => "host", "seats" => [4], "pending" => [8] }, "seats" => "0,3,4,8,5,5"),
  intake("a request bringing seats that are no numbers", {}, "seats" => "x, 5,,6,"),
  intake("a full battle still keeps its asking player", { "players" => 4 }, "seats" => "5"),
]

write_cases("intake.json", "constants" => { "players" => MGQ_MpBattlesCoop::RAID_PLAYERS }, "cases" => INTAKE)

# The roster: the battle's level, the roster and party lines, and the host's troop repaired.

load File.join(OLD, "GameScript", "Multiplayer", "Scripts", "battles_coop_level_sync.rbx")
COOP = MGQ_MpBattlesCoop
WIRE = MGQ_MpBattlesSync::Wire

# A character of the builds the level cases read: only its personal level.
LevelMember = Struct.new(:base_level)

# Reads the log lines a block writes, every line logged once before forgotten.
#
# @return [Array] What the block returns and the lines.
def logged
  $log.clear
  MGQ_MpLog.instance_variables.each { |name| MGQ_MpLog.instance_variable_set(name, {}) if MGQ_MpLog.instance_variable_get(name).is_a?(Hash) }
  value = yield
  [value, $log.dup]
end

# Makes a level case.
#
# @param name [String] What it shows.
# @param raid [Boolean] Whether a Raid World is open.
# @param players [Array<Array>] Each player's seat, whether they lead, the personal levels of their
#   builds by place (nil for a member the builds lack), order, front and bench; the case keeps each
#   player's places on the Frontline and the Backline in place of the last three.
# @return [Hash] The case.
def level(name, raid, players)
  $raid = raid
  leaders = players.select { |player| player[1] }.map(&:first)
  stand(COOP, :leads?) { |seat| leaders.include?(seat) }
  builds = {}
  read = players.map do |seat, _, levels, order, front, bench|
    builds[seat.to_s] = levels
    COOP::Player.new(seat, "P#{seat}", seat.to_s, [], 8, order, front, bench)
  end
  stand(MGQ_MpActors::Builds, :parse) { |text, _count| builds.fetch(text).map { |found| found && LevelMember.new(found) } }
  found, lines = logged { MGQ_MpCoopLevelSync.level_for(read) }
  places = read.map { |player| player.lines.flatten }
  { "name" => name, "raid" => raid, "players" => players.zip(places).map { |(seat, leads, levels), at| [seat, leads, levels, at] }, "level" => found, "logs" => lines }
end

LEVELS = [
  level("the highest of the leader's characters on both lines", false, [[0, true, [30, 42, 25, 50], [3, 0, 1, 2], 2, 1], [2, false, [70, 80], [0, 1], 2, 0]]),
  level("the leader may be a guest", false, [[0, false, [99], [0], 1, 0], [2, true, [12, 15], [1, 0], 1, 1]]),
  level("a Raid World has none", true, [[0, true, [30], [0], 1, 0]]),
  level("no leader among the players", false, [[0, false, [30], [0], 1, 0], [5, false, [40], [0], 1, 0]]),
  level("a place the builds lack is left out", false, [[0, true, [30, nil], [1, 0], 1, 1]]),
  level("places beyond the order", false, [[0, true, [30, 31], [0, 1], 4, 4]]),
  level("no place at all", false, [[0, true, [30], [], 0, 0]]),
  level("no order", false, [[0, true, [30], nil, 2, 0]]),
  level("the first leader counts", false, [[0, true, [10], [0], 1, 0], [2, true, [90], [0], 1, 0]]),
]

# Sets this game's troop and database of enemies up for a repair.
#
# @param own [Array<Array>] This game's troop, [x, y] each.
# @param count [Integer] The enemies this game's database holds, id 0 included.
def set_troop(own, count)
  $data_enemies = Array.new(count) { |id| id > 0 ? Object.new : nil }
  $game_troop.members = own.each_with_index.map { |(x, y), index| Game_Enemy.new(index, 31).tap { |enemy| enemy.screen_x = x; enemy.screen_y = y } }
end

# Reads a roster line as the old join did: its players read with the notes of what was dropped, and
# its enemies repaired against this game's troop.
#
# @param line [String] The roster.
# @param own [Array<Array>] This game's troop, [x, y] each.
# @param count [Integer] The enemies this game's database holds, id 0 included.
# @return [Hash] What the old script read.
def read_roster(line, own, count)
  set_troop(own, count)
  enemies, players, level, turn = WIRE.parse(line)
  read, player_logs = logged { COOP::Player.read_all(players).map(&:to_a) }
  repaired, repair_logs = logged { COOP.repaired_enemies(Array(enemies)) }
  { "line" => line, "own" => own, "count" => count, "enemies_size" => Array(enemies).size, "players" => read, "player_logs" => player_logs,
    "repaired" => repaired, "repair_logs" => repair_logs, "level" => level.is_a?(Integer) ? level : nil, "turn" => turn.is_a?(Integer) ? turn : nil }
end

# A player's fields as a roster carries them. A roster never carries a symbol, which a game reads
# only when it has it, so the cases take other kinds of the wrong kind.
GOOD = [2, "Friend", "7,8,9", [[50, 5], [60, 6]], 8, [0, 1, 2], 2, 1]

ROSTERS = [
  ["a roster of two players and the battle's level", WIRE.line([[[31, 320, 300, 0], [32, 160, 300, 1]], [[0, "Me", "1,2,3", [[100, 10]], 8, [0, 1, 2], 2, 1], GOOD], 30]), [[320, 300], [160, 300]], 100],
  ["a late roster with the turn and fallen enemies", WIRE.line([[[31, 320, 300, 2], [33, 480, 300, 0]], [GOOD], nil, 4]), [[320, 300]], 100],
  ["a player whose seat is no number is left out", WIRE.line([[], [["2", "X", "", [], 8, nil, nil, nil], GOOD], 0]), [], 100],
  ["fields of the wrong kind are dropped", WIRE.line([[], [[3, 1.5, 7, "hp", -1, [0, -1], 1.5, "b"], [4, "Y", "1", [[1, 2], 5, "s", nil], nil, nil, nil, nil]], 0]), [], 100],
  ["a player's fields shorter or longer", WIRE.line([[], [[5], [6, "Z", "1", [], 8, [0], 1, 0, "more"]], 0]), [], 100],
  ["a player that is no list", WIRE.line([[], [7, "x", nil], 0]), [], 100],
  ["an enemy whose place or mark is no number takes this game's place", WIRE.line([[[31, "a", 300, 0], [32, 160, nil, 1.5], [33, 1, 2]], [], 0]), [[320, 300], [160, 290]], 100],
  ["an enemy beyond this game's troop takes place 0", WIRE.line([[[31, nil, nil, 0], [32, 2.5, true, 0]], [], 0]), [[11, 22]], 100],
  ["an enemy whose id is no number keeps this game's troop", WIRE.line([[[31, 1, 2, 0], ["32", 1, 2, 0], [nil, 1, 2, 0]], [], 0]), [[320, 300]], 100],
  ["an enemy that is no list keeps this game's troop", WIRE.line([[[31, 1, 2, 0], 5], [], 0]), [], 100],
  ["enemies this game lacks keep its own troop", WIRE.line([[[31, 1, 2, 0], [150, 1, 2, 0], [0, 1, 2, 0]], [], 0]), [], 100],
  ["no enemies", WIRE.line([nil, nil, nil]), [], 100],
  ["a line that does not read", "[\tbroken", [], 100],
  ["a level and turn of the wrong kind", WIRE.line([[], [], "30", 2.5]), [], 100],
].map { |name, line, own, count| { "name" => name }.merge(read_roster(line, own, count)) }

# The troop a host tells its guests once it changed, see MGQ_MpBattlesHotjoin.take_troop.
TROOPS = [
  ["a changed troop and the host's names", WIRE.line([[[31, 320, 300, 0], [52, 100, 300, 1]], "names\tline"]), [[320, 300]], 100],
  ["a troop without names", WIRE.line([[[31, 320, 300, 2]]]), [[320, 300]], 100],
  ["names that are no text", WIRE.line([[[31, 320, 300, 0]], 5]), [[320, 300]], 100],
].map do |name, line, own, count|
  set_troop(own, count)
  entries, names = WIRE.parse(line)
  repaired, logs = logged { COOP.repaired_enemies(entries) }
  { "name" => name, "line" => line, "own" => own, "count" => count, "repaired" => repaired, "repair_logs" => logs, "names" => names.is_a?(String) ? names : nil }
end

# Lines the host writes: the roster, a late roster and the party.
PLAYERS = [[0, "Me", "1,2,3", [[100, 10], [90, 0]], 8, [1, 0, 2], 2, 1], [2, "Frénd \"x\"", "", [], 0, nil, nil, nil]]
WRITES = [
  { "kind" => "roster", "enemies" => [[31, 320, 300, 0], [32, -5, 300, 1]], "players" => PLAYERS, "level" => 30, "line" => WIRE.line([[[31, 320, 300, 0], [32, -5, 300, 1]], PLAYERS, 30]) },
  { "kind" => "roster", "enemies" => [], "players" => [], "level" => 0, "line" => WIRE.line([[], [], 0]) },
  { "kind" => "late", "enemies" => [[31, 320, 300, 2]], "players" => PLAYERS, "turn" => 3, "line" => WIRE.line([[[31, 320, 300, 2]], PLAYERS, nil, 3]) },
  { "kind" => "party", "players" => PLAYERS, "line" => WIRE.line([PLAYERS]) },
]

write_cases("roster.json", "levels" => LEVELS, "rosters" => ROSTERS, "troops" => TROOPS, "writes" => WRITES)

# The matchmaking: offers, holds, the stand-still and the encounter's steps, played as scenarios.
# Each step records the world as the old scripts saw it (the players, the party, the facts of the
# game), runs one operation and records what was sent, what the notification box was told, the
# co-op battle's log lines and the steps only the game can take (the actions).

# The notification box, each message and drop noted in $box.
module MGQ_MpNotices
  def self.message(key, text, frames = 180); $box << ["message", *box_key(key), text, frames]; end
  def self.drop(key, reason = nil); $box << ["drop", *box_key(key), reason]; end
  # Writes a key as the DLL names it: its name and the seat it names, nil for none.
  def self.box_key(key); key.is_a?(Array) ? [key[0].to_s, key[1]] : [key.to_s, nil]; end
end
# The PvP battles, running while $pvp is set.
module MGQ_MpBattlesPvp; module Battle; def self.running?; $pvp ? true : false; end; end; end
# The raid boss pools of the scenario: $side (a side battle), $won (pools all empty), $pool_fields.
module MGQ_MpRaidPool
  def self.side_battle?(_troop); $side ? true : false; end
  def self.won_already?(_troop); $won ? true : false; end
  def self.invite_fields(_troop = nil); $pool_fields || {}; end
end
# The raid tiers of a Classic world, whose invite fields are $tier_fields.
module MGQ_MpRaidTiers; def self.invite_fields(_troop); $tier_fields || {}; end; end

# The live battle and the battles' rules as the scenario sets them in $live and $rules.
sync = MGQ_MpBattlesSync
stand(sync, :role) { $live[:role] }
stand(sync, :battle_id) { $live[:bid] }
stand(sync, :seats) { $live[:seats] }
stand(sync, :coop?) { $live[:role] ? true : false }
stand(sync, :live?) { $live[:role] ? true : false }
stand(sync, :join_world) do |role, bid, seats, label, *_|
  $actions << ["join", role.to_s, bid, seats, label]
  $live = { :role => role, :bid => bid, :seats => seats, :player => label }
end
stand(sync, :player) { $live[:player].to_s }
stand(sync, :battle_started) {}
stand(MGQ_MpBattles, :begin) { |*_| $rules = :coop }
stand(MGQ_MpBattles, :running?) { !$rules.nil? }
stand(MGQ_MpBattles, :kind) { $rules }
stand(MGQ_MpBattles, :finish) { $rules = nil }

# The steps the matchmaking hands to other scripts, noted as actions.
HOTJOIN = MGQ_MpBattlesHotjoin unless defined?(HOTJOIN)
stand(HOTJOIN, :ask) { |*_| $actions << ["ask_hot"]; $hot_answer }
stand(HOTJOIN, :fight_alone) { |*_| $actions << ["fight_alone"] unless sync.role }
stand(HOTJOIN, :stays_out?) { |seat| Array($stays_out).include?(seat) }
stand(HOTJOIN, :asked_seats) { Array($asked) }
stand(COOP, :new_battle_id) { $ids = $ids.to_i + 1; "b#{$ids}" }
stand(COOP, :rand) { $rand }
stand(SceneManager, :call) { |scene| $actions << ["call", scene.to_s] }
stand(MGQ_MpCoop::Scope, :viewers) { MGQ_MpOverworldSync::Peers.all.select { |peer| Array($viewers).include?(peer.seat) } }
stand(MGQ_MpRaidBosses, :battle?) { |_troop| $boss ? true : false }
# The battle the player's party stands in for, the running battles' requests and the steps the
# scripts take for an invite.
stand(COOP, :active?) { $active ? true : false }
stand(HOTJOIN, :late?) { $late ? true : false }
stand(HOTJOIN, :own_troop?) { $own_troop ? true : false }
stand(HOTJOIN, :asks?) { |peer, message| !$hot_ask.nil? && peer.seat == $hot_ask[0] && message["bid"].to_s == $hot_ask[1] && message["hot"] == "1" }
stand(JOIN, :gave_up?) { |peer, message| !$gave_up.nil? && peer && peer.seat == $gave_up[0] && message["bid"].to_s == $gave_up[1] && message["hot"].to_s == "1" }
stand(HOTJOIN, :take_off) { |*_| false }
stand(HOTJOIN, :note_invite) { |*_| }
stand(HOTJOIN, :call_off_own) { |text = nil| $actions << ["call_off_own", text] }
stand(COOP, :accept) { |peer, message| $actions << ["accept", peer.seat, message["bid"]] }
stand(COOP, :lead) { |peer, message| $actions << ["lead", peer.seat, message["bid"]] }
stand(COOP, :adopt_troop) { |_scene, message| $actions << ["adopt", message["troop"].to_i] }
stand(COOP, :take_pool) { |*_| }
stand(MGQ_MpCoopGather, :drop_call) { |_reason| $actions << ["drop_call"] }
stand(sync, :miss) { |text| $actions << ["miss", text] }
stand(sync, :break_off) { |reason, *_| $actions << ["break_off", reason] }
stand(sync, :finish) { $actions << ["finish"] if $live[:role]; $live = { :seats => [] } }
# The players whose connection stands, as the world room tells them.
stand(MGQ_MpOverworldSync::Peers, :present) { all.select { |peer| peer.away.nil? } }

# The clock the stand-still runs by, in seconds, $now.
class << Time
  alias_method :real_now, :now
  def now; $now ? Time.at($now) : real_now; end
end

# Makes another player.
#
# @param seat [Integer] Their seat.
# @param state [Hash] What their state says besides the defaults.
# @param member [Boolean] Whether they are in the player's party.
# @param away [Boolean] Whether their connection dropped.
# @return [MGQ_MpOverworldSync::Peers::Peer] The player.
def peer(seat, state = {}, member = false, away = false)
  MGQ_MpOverworldSync::Peers::Peer.new(seat, { "id" => "id-#{seat}", "name" => "P#{seat}", "map" => "5", "scene" => "map", "x" => "0", "y" => "0", "since" => "300" }.merge(state),
                                       nil, member, away ? 1 : nil)
end

# Tells the world the old scripts see now.
#
# @return [Hash] The players, the party's leader, the Raid World and the player's facts.
def world_now
  leader = $leader == :me ? "me" : ($leader ? $leader.seat : nil)
  { "peers" => MGQ_MpOverworldSync::Peers.all.map { |p| { "seat" => p.seat, "state" => p.state.dup, "member" => p.member ? true : false, "away" => !p.away.nil? } },
    "leader" => leader, "raid" => $raid ? true : false, "own_seat" => $my_seat.to_i, "since" => $my_since.to_i, "now" => ($now * 1000).round,
    "facts" => { "map" => $game_map.map_id, "x" => $game_player.x, "y" => $game_player.y, "role" => $live[:role] && $live[:role].to_s, "bid" => $live[:bid],
                 "seats" => Array($live[:seats]), "coop" => $live[:role] ? true : false, "running" => !$rules.nil?, "kind" => $rules && $rules.to_s,
                 "pvp" => $pvp ? true : false, "memory" => $game_temp.in_memory_battle ? true : false, "battle_scene" => SceneManager.scene.is_a?(Scene_Battle),
                 "interpreter" => $game_map.interpreter.running? ? true : false, "trading" => $trading_now ? true : false, "coming" => !$gather_call.nil?,
                 "transfer" => false, "moving" => $game_player.moving ? true : false, "active" => $active ? true : false, "late" => $late ? true : false,
                 "own_troop" => $own_troop ? true : false, "hot_ask" => $hot_ask, "gave_up" => $gave_up, "story" => story_now } }
end

# Tells whether the invite that waits belongs to the story that calls the player over.
#
# @return [Boolean] Whether it does.
def story_now
  invite = COOP.instance_variable_get(:@invite)
  invite ? MGQ_MpCoopGather.calling_battle?(invite[:peer], invite[:message]["map"].to_i) : false
end

# The facts of a battle the old scripts read beside the matchmaking's own.
#
# @param troop [Integer] The battle's troop.
# @return [Hash] The facts.
def offer_facts(troop)
  invite = COOP.instance_variable_get(:@invite)
  waiting = invite && { "seat" => invite[:peer].seat, "hot" => invite[:message]["hot"] == "1", "expired" => COOP.expired?(invite), "rival" => COOP.waiting_rival? }
  fields = $raid ? MGQ_MpRaidPool.invite_fields(troop) : MGQ_MpRaidTiers.invite_fields(troop)
  { "joining" => COOP.instance_variable_get(:@joining) ? true : false, "encountering" => COOP.instance_variable_get(:@encountering) ? true : false,
    "side" => $side ? true : false, "pools_won" => $won ? true : false, "boss" => $boss ? true : false, "rates" => COOP.rates_text,
    "invite_fields" => fields.map { |key, value| [key.to_s, value.to_s] }, "viewers" => Array($viewers), "leading" => COOP.instance_variable_get(:@leading),
    "waiting" => waiting, "stays_out" => Array($stays_out), "hot_answer" => $hot_answer ? true : false }
end

# Runs one operation of a scenario and records it.
#
# @param steps [Array<Hash>] The scenario's steps.
# @param op [String] The operation: "offer", "poll", "steps", "freeze", "soon", "unfreeze" or "wait".
# @param args [Hash] Its arguments.
# @yield Runs it on the old scripts.
def step(steps, op, args = {})
  before = world_now
  # A frame on the map may start a held encounter, which reads the battle's facts as an offer does.
  extra = %w(offer poll).include?(op) ? offer_facts(args["troop"]) : {}
  $sent.clear
  $log.clear
  $box = []
  $actions = []
  yield
  steps << { "op" => op, "args" => args.merge(extra), "world" => before,
             "outcome" => { "sent" => $sent.map { |seat, text| [seat, text] }, "box" => $box, "actions" => $actions,
                            "logs" => $log.select { |line| line.start_with?("co-op battle: ") }, "waits" => COOP.waiting_for_player } }
end

# Starts a scenario on a fresh world: map 5, the player at (10, 10) in seat 0, no battle.
#
# @param name [String] What it shows.
# @param raid [Boolean] Whether it is a Raid World.
# @param leader [Symbol, Integer, nil] The party's leader: :me, a seat, or nil for none.
# @param peers [Array<MGQ_MpOverworldSync::Peers::Peer>] The other players.
# @yield [steps] Runs the scenario's steps.
# @return [Hash] The scenario.
def scenario(name, raid, leader, peers)
  $box = []
  COOP.drop
  COOP.instance_variable_set(:@leading, nil)
  COOP.instance_variable_set(:@joining, false)
  COOP.instance_variable_set(:@encountering, false)
  MGQ_MpLog.instance_variables.each { |ivar| MGQ_MpLog.instance_variable_set(ivar, {}) if MGQ_MpLog.instance_variable_get(ivar).is_a?(Hash) }
  $raid = raid
  $live = { :seats => [] }
  $rules = nil
  $pvp = $side = $won = $boss = false
  $pool_fields = $tier_fields = nil
  $viewers = $stays_out = $asked = []
  $hot_answer = false
  $gather_call = nil
  $trading_now = false
  $active = $late = $own_troop = false
  $hot_ask = $gave_up = nil
  $scene_now = nil
  $ids = 0
  $now = 1000.0
  $rand = 0.5
  $my_seat = 0
  $my_since = 200
  $game_temp.in_memory_battle = false
  $game_map.map_id = 5
  $game_map.interpreter.busy = false
  $game_player.x = 10
  $game_player.y = 10
  $game_variables = Game_Variables.new
  [41, 42, 43, 44, 45, 48].each_with_index { |id, index| $game_variables[id] = 100 + index }
  MGQ_MpOverworldSync::Peers.all.replace(peers)
  $leader = leader.is_a?(Integer) ? peers.find { |p| p.seat == leader } : leader
  steps = []
  yield steps
  { "name" => name, "steps" => steps }
end

# Offers a battle as BattleManager.setup does.
#
# @param steps [Array<Hash>] The scenario's steps.
# @param troop [Integer] The troop.
# @param encounter [Boolean] Whether it is a random encounter set up just now.
def offer(steps, troop, encounter = false)
  # The game's random encounter sets its battle up inside Game_Player#encounter.
  COOP.instance_variable_set(:@encountering, encounter)
  step(steps, "offer", "troop" => troop, "escape" => true, "lose" => false, "encounter" => encounter) { COOP.offer(troop, true, false) }
  COOP.instance_variable_set(:@encountering, false)
end

# Takes a co-op message as the routes of coop.rbx and coop_scope.rbx hand it over.
#
# @param steps [Array<Hash>] The scenario's steps.
# @param seat [Integer] The sender's seat.
# @param message [Hash] The message's fields.
def take(steps, seat, message)
  step(steps, "take", "seat" => seat, "message" => message) { COOP.take(MGQ_MpOverworldSync::Peers.at(seat), message) }
end

# Writes an invite as it comes through the map's gate.
#
# @param kind [String] The co-op message's kind.
# @param fields [Hash] Its fields.
# @return [Hash] The message, its kind under "coop" too.
def map_message(kind, fields)
  { "map_coop" => kind, "mmap" => "5" }.merge(fields).merge("coop" => kind)
end

# Writes a message as it comes through the party's gate.
#
# @param kind [String] The co-op message's kind.
# @param fields [Hash] Its fields.
# @return [Hash] The message.
def party_message(kind, fields)
  { "coop" => kind, "party" => "p1" }.merge(fields)
end

# Runs frames on the map as Scene_Map#update_scene does.
#
# @param steps [Array<Hash>] The scenario's steps.
# @param count [Integer] The frames.
def poll(steps, count = 1)
  step(steps, "poll", "count" => count, "asked" => Array($asked)) do
    count.times do
      # The player's hold, which the map asks each frame, lets the stand-still run out.
      COOP.holding? || COOP.frozen?
      COOP.on_map
    end
  end
end

MATCH = []

classic = lambda do
  [peer(2, { "name" => "Friend" }, true), peer(3, { "name" => "Busy", "scene" => "menu" }, true), peer(4, { "name" => "Away", "map" => "9" }, true),
   peer(6, { "name" => "Stranger" })]
end

MATCH << scenario("a battle invites the party members playing on the map", false, :me, classic.call) { |s| offer(s, 40) }
MATCH << scenario("a member asks the leader to lead", false, 2, classic.call) { |s| offer(s, 40) }
MATCH << scenario("a member whose leader is elsewhere hosts", false, 4, classic.call) { |s| offer(s, 41) }
MATCH << scenario("a party without a leader", false, nil, classic.call) { |s| offer(s, 41) }
MATCH << scenario("the leader leads a member's battle with its id", false, :me, classic.call) do |s|
  COOP.instance_variable_set(:@leading, [3, "lb1"])
  $tier_fields = { "tier" => 1 }
  offer(s, 42)
end
MATCH << scenario("nobody to invite", false, :me, [peer(4, { "name" => "Away", "map" => "9" }, true)]) { |s| offer(s, 40) }
MATCH << scenario("no co-op battle while another runs", false, :me, classic.call) do |s|
  $live = { :role => :guest, :bid => "x", :seats => [2] }
  $rules = :coop
  offer(s, 40)
  $live = { :seats => [] }
  $rules = nil
  $pvp = true
  offer(s, 40)
  $pvp = false
  $game_temp.in_memory_battle = true
  offer(s, 40)
end
MATCH << scenario("a battle the player joins becomes no co-op battle", false, :me, classic.call) do |s|
  COOP.instance_variable_set(:@joining, true)
  offer(s, 40)
end
MATCH << scenario("a random encounter waits for the busy members and starts once they are back", false, :me, classic.call) do |s|
  offer(s, 50, true)
  poll(s, 3)
  MGQ_MpOverworldSync::Peers.at(3).state["scene"] = "map"
  poll(s)
end
MATCH << scenario("a held encounter starts once its wait ran out", false, :me, classic.call) do |s|
  offer(s, 50, true)
  poll(s, 179)
  poll(s)
end
MATCH << scenario("an event drops the held encounter", false, :me, classic.call) do |s|
  offer(s, 50, true)
  $game_map.interpreter.busy = true
  MGQ_MpOverworldSync::Peers.at(3).state["scene"] = "map"
  poll(s)
end
MATCH << scenario("the steps to the next encounter stretch while a member stands near", false, :me, classic.call) do |s|
  step(s, "steps", "steps" => 10_000, "rand" => 0.5) { $steps = COOP.party_encounter_steps(100.0) }
  s.last["outcome"]["steps"] = ($steps * 100).round
  $rand = 0.9
  step(s, "steps", "steps" => 4_321, "rand" => 0.9) { $steps = COOP.party_encounter_steps(43.21) }
  s.last["outcome"]["steps"] = ($steps * 100).round
  MGQ_MpOverworldSync::Peers.at(2).state["x"] = "40"
  step(s, "steps", "steps" => 10_000, "rand" => 0.9) { $steps = COOP.party_encounter_steps(100.0) }
  s.last["outcome"]["steps"] = ($steps * 100).round
end
MATCH << scenario("a member stands still for another's battle until it is called off or the time runs out", false, :me, classic.call) do |s|
  friend = MGQ_MpOverworldSync::Peers.at(2)
  busy = MGQ_MpOverworldSync::Peers.at(3)
  step(s, "soon", "seat" => 2) { COOP.take_soon(friend) }
  step(s, "freeze", "seat" => 2, "map" => "9") { COOP.take_freeze(friend, "map" => "9") }
  step(s, "freeze", "seat" => 2, "map" => "5") { COOP.take_freeze(friend, "map" => "5") }
  step(s, "freeze", "seat" => 3, "map" => "5") { COOP.take_freeze(busy, "map" => "5") }
  step(s, "unfreeze", "seat" => 2, "other_invite" => false) { COOP.unfreeze_for(friend) }
  $now = 1005.0
  poll(s)
  step(s, "unfreeze", "seat" => 3, "other_invite" => false) { COOP.unfreeze_for(busy) }
  step(s, "freeze", "seat" => 2, "map" => "5") { COOP.take_freeze(friend, "map" => "5") }
  $now = 1015.5
  poll(s)
  step(s, "freeze", "seat" => 2, "map" => "5") { COOP.take_freeze(friend, "map" => "5") }
  offer(s, 40)
end
MATCH << scenario("a player in a battle never stands still", false, :me, classic.call) do |s|
  $live = { :role => :host, :bid => "x", :seats => [2] }
  step(s, "freeze", "seat" => 2, "map" => "5") { COOP.take_freeze(MGQ_MpOverworldSync::Peers.at(2), "map" => "5") }
end

raid = lambda do
  [peer(2, { "name" => "Near", "x" => "12", "y" => "9", "since" => "250" }), peer(3, { "name" => "Far", "x" => "40" }),
   peer(4, { "name" => "Member", "x" => "20", "y" => "20" }, true), peer(5, { "name" => "Busy", "busy" => "1" }),
   peer(6, { "name" => "Fighting", "scene" => "battle", "rb" => "zz", "rbh" => "6" }), peer(7, { "name" => "Reading", "scene" => "event", "x" => "11", "y" => "10" }),
   peer(8, { "name" => "Background", "scene" => "away", "x" => "9", "y" => "11" }), peer(9, { "name" => "Elsewhere", "map" => "6" }),
   peer(10, { "name" => "Gone", "x" => "10" }, false, true)]
end

MATCH << scenario("a Raid World's event battle invites the free players near, the party first", true, :me, raid.call) do |s|
  $pool_fields = { "pool" => 2 }
  offer(s, 70)
end
MATCH << scenario("a Raid World's boss battle invites the players reading the story too", true, nil, raid.call) do |s|
  $boss = true
  $viewers = [7]
  offer(s, 71)
end
MATCH << scenario("a Raid World's encounter asks a running battle first", true, nil, raid.call) do |s|
  $hot_answer = true
  offer(s, 72, true)
end
MATCH << scenario("a Raid World's encounter no running battle takes hosts", true, nil, raid.call) do |s|
  $stays_out = [4]
  offer(s, 72, true)
end
MATCH << scenario("a Raid World's side battle invites nobody", true, nil, raid.call) do |s|
  $side = true
  offer(s, 73)
end
MATCH << scenario("a Raid World's battle whose pools are all empty invites nobody", true, nil, raid.call) do |s|
  $won = true
  offer(s, 74)
end
MATCH << scenario("a Raid World's battle invites the host of a waiting invite first", true, nil, raid.call) do |s|
  take(s, 3, map_message("invite", "bid" => "w1", "troop" => "40", "map" => "5", "enc" => "1", "seats" => "0"))
  offer(s, 70)
end
MATCH << scenario("a Raid World's held encounter holds the players it takes and lets the others walk on", true, nil,
                  raid.call + [peer(11, { "name" => "Menu", "scene" => "menu" }, true)]) do |s|
  offer(s, 75, true)
  MGQ_MpOverworldSync::Peers.at(11).state["scene"] = "map"
  poll(s)
end
MATCH << scenario("a Raid World stretches the steps per player near, four at most", true, nil, raid.call) do |s|
  step(s, "steps", "steps" => 10_000, "rand" => 0.5) { $steps = COOP.party_encounter_steps(100.0) }
  s.last["outcome"]["steps"] = ($steps * 100).round
end
MATCH << scenario("outside a party and a Raid World the steps stay", false, nil, [peer(2)]) do |s|
  step(s, "steps", "steps" => 10_000, "rand" => 0.5) { $steps = COOP.party_encounter_steps(100.0) }
  s.last["outcome"]["steps"] = ($steps * 100).round
end

write_cases("match.json", "scenarios" => MATCH)

# The invites, the lead requests and the rivals, played as scenarios as the matchmaking's were. The
# scripts' own steps (joining an invite, leading a request, following another battle, ending a
# wait) are noted as actions, with what the old script kept of them.

stand(COOP, :trading?) { $trading_now ? true : false }
stand(COOP, :accept) do |peer, message|
  $actions << ["accept", peer.seat, message["bid"]]
  COOP.thaw("the player joins the battle")
  COOP.instance_variable_set(:@awaited, { :peer => peer, :message => message })
end

# Waits for the party's leader as await_leader does, the leader's message coming at a frame and the
# wait ending at a frame with an ending of its own.
#
# @param steps [Array<Hash>] The scenario's steps.
# @param inject_at [Integer, nil] The frame the message comes at.
# @param seat [Integer, nil] Who sends it.
# @param message [Hash, nil] The message.
# @param end_at [Integer, nil] The frame the wait ends at by itself.
# @param ending [String, nil] How it ends then, such as "gone".
def leader_wait(steps, inject_at = nil, seat = nil, message = nil, end_at = nil, ending = nil)
  args = { "inject_at" => inject_at, "seat" => seat, "message" => message, "end_at" => end_at, "ending" => ending }
  step(steps, "leader_wait", args) do
    stand(MGQ_MpBattlesSync::Waiting, :wait_for) do |*_args, &block|
      frame = 0
      loop do
        frame += 1
        COOP.take(MGQ_MpOverworldSync::Peers.at(seat), message) if inject_at == frame
        break ending.to_sym if end_at == frame

        found = block.call
        break found if found
      end
    end
    COOP.await_leader(Scene_Battle.new)
  end
end

INVITES = []

party = lambda do
  [peer(2, { "name" => "Mate" }, true), peer(3, { "name" => "Pal" }, true), peer(6, { "name" => "Stranger" })]
end

INVITES << scenario("an invite waits until the player is free, then joins it", false, :me, party.call) do |s|
  take(s, 2, party_message("invite", "bid" => "i1", "troop" => "40", "escape" => "1", "lose" => "0", "seats" => "0", "map" => "5"))
  $game_player.moving = true
  poll(s)
  $game_player.moving = false
  poll(s)
end
INVITES << scenario("invites the player cannot take", false, :me, party.call) do |s|
  take(s, 2, party_message("invite", "bid" => "o1", "troop" => "40", "seats" => "3", "map" => "5"))
  $live = { :role => :host, :bid => "own", :seats => [3] }
  take(s, 2, party_message("invite", "bid" => "i2", "troop" => "40", "seats" => "0", "map" => "5"))
  $live = { :seats => [] }
  $scene_now = Scene_Battle.new
  take(s, 2, party_message("invite", "bid" => "i3", "troop" => "40", "seats" => "0", "map" => "5"))
  $scene_now = nil
  take(s, 2, party_message("invite", "bid" => "i4", "troop" => "40", "seats" => "0", "map" => "9"))
  poll(s)
  take(s, 2, party_message("invite", "bid" => "i5", "troop" => "40", "seats" => "0", "map" => "5"))
  $now += 3.5
  poll(s)
end
INVITES << scenario("a newer invite takes the waiting one's place, and the story's call turns another's down", false, :me, party.call) do |s|
  take(s, 2, party_message("invite", "bid" => "i6", "troop" => "40", "seats" => "0", "map" => "5"))
  take(s, 3, party_message("invite", "bid" => "i7", "troop" => "41", "seats" => "0", "map" => "5"))
  $gather_call = [7, 5]
  poll(s)
  take(s, 2, party_message("invite", "bid" => "i8", "troop" => "40", "seats" => "0", "map" => "5"))
  $gather_call = [2, 5]
  poll(s)
end
INVITES << scenario("a member's request to lead waits for the leader, who leads it or refuses it", false, :me, party.call) do |s|
  take(s, 2, party_message("lead", "bid" => "m1", "troop" => "64", "escape" => "0", "lose" => "1", "map" => "5"))
  poll(s)
  take(s, 2, party_message("lead", "bid" => "m2", "troop" => "64", "map" => "9"))
  poll(s)
  take(s, 2, party_message("lead", "bid" => "m3", "troop" => "64", "map" => "5"))
  take(s, 3, party_message("lead", "bid" => "m4", "troop" => "64", "map" => "5"))
  $now += 3.5
  poll(s)
  take(s, 2, party_message("lead", "bid" => "m5", "troop" => "64", "map" => "5"))
  $leader = MGQ_MpOverworldSync::Peers.at(3)
  poll(s)
end
INVITES << scenario("a member asks the leader, who leads with an invite", false, 2, party.call) do |s|
  offer(s, 62)
  take(s, 2, party_message("invite", "bid" => "other", "troop" => "62", "seats" => "0", "map" => "5"))
  take(s, 3, party_message("no_lead", "bid" => "b1"))
  leader_wait(s, 2, 2, party_message("invite", "bid" => "b1", "troop" => "62", "seats" => "0,3", "map" => "5"))
end
INVITES << scenario("a leader who refuses leaves the battle to the member, whose late invite is turned down", false, 2, party.call) do |s|
  offer(s, 61)
  leader_wait(s, 3, 2, party_message("no_lead", "bid" => "b1"))
  take(s, 2, party_message("invite", "bid" => "b1", "troop" => "61", "seats" => "0", "map" => "5"))
end
INVITES << scenario("a silent leader leaves the battle to the member after the wait", false, 2, party.call) do |s|
  offer(s, 63)
  leader_wait(s)
end
INVITES << scenario("a wait for the leader that the battle ends", false, 2, party.call) do |s|
  offer(s, 63)
  leader_wait(s, nil, nil, nil, 4, "gone")
end
INVITES << scenario("a Raid World refuses a request to lead and takes no message through a Classic map's gate", true, :me, party.call) do |s|
  take(s, 2, map_message("lead", "bid" => "l1", "troop" => "64", "map" => "5"))
  $raid = false
  step(s, "take_map", "seat" => 2, "message" => map_message("invite", "bid" => "x1")) { COOP.take_map(MGQ_MpOverworldSync::Peers.at(2), map_message("invite", "bid" => "x1")) }
  step(s, "take_map", "seat" => 2, "message" => map_message("invite", "bid" => "x2")) { COOP.take_map(MGQ_MpOverworldSync::Peers.at(2), map_message("invite", "bid" => "x2")) }
end

raiders = lambda do
  [peer(3, { "name" => "Comrade", "x" => "12", "y" => "10" }, true), peer(6, { "name" => "Near", "x" => "11", "y" => "10", "since" => "250" }),
   peer(13, { "name" => "Rival", "x" => "10", "y" => "12", "since" => "100" }), peer(14, { "name" => "Eventful", "x" => "9", "y" => "9", "since" => "400" }),
   peer(15, { "name" => "Late", "x" => "9", "y" => "12", "since" => "500" })]
end

INVITES << scenario("two battles started at the same moment: the player joins the rival who entered the map first", true, :me, raiders.call) do |s|
  offer(s, 81, true)
  take(s, 13, map_message("invite", "bid" => "rv1", "troop" => "90", "escape" => "0", "lose" => "1", "seats" => "0,3", "map" => "5", "enc" => "1", "boss" => "1"))
  take(s, 13, map_message("invite", "bid" => "rv1", "troop" => "90", "escape" => "0", "lose" => "1", "seats" => "0,3", "map" => "5", "enc" => "1"))
  take(s, 14, map_message("invite", "bid" => "ev1", "troop" => "91", "seats" => "0", "map" => "5", "enc" => "0"))
  take(s, 15, map_message("invite", "bid" => "lt1", "troop" => "92", "seats" => "0", "map" => "5", "enc" => "1"))
  step(s, "yield", {}) { COOP.yield_to_rival(Scene_Battle.new) }
end
INVITES << scenario("a rival's battle that is off lets the player's own go on", true, :me, raiders.call) do |s|
  offer(s, 81, true)
  take(s, 13, map_message("invite", "bid" => "rv2", "troop" => "90", "seats" => "0", "map" => "5", "enc" => "1"))
  take(s, 13, map_message("off", "bid" => "rv2"))
end
INVITES << scenario("of two invites that wait in a Raid World the one whose host hosts first stays", true, nil, raiders.call) do |s|
  take(s, 15, map_message("invite", "bid" => "w1", "troop" => "40", "seats" => "0", "map" => "5", "enc" => "1"))
  take(s, 13, map_message("invite", "bid" => "w2", "troop" => "40", "seats" => "0", "map" => "5", "enc" => "1"))
  take(s, 14, map_message("invite", "bid" => "w3", "troop" => "40", "seats" => "0", "map" => "5", "enc" => "1"))
  $now += 3.5
  take(s, 14, map_message("invite", "bid" => "w4", "troop" => "40", "seats" => "0", "map" => "5", "enc" => "1"))
  $game_player.moving = true
  offer(s, 82, true)
  $game_player.moving = false
end
INVITES << scenario("a guest whose host yields follows to the battle it yields to", true, nil, raiders.call) do |s|
  take(s, 15, map_message("invite", "bid" => "g1", "troop" => "40", "seats" => "0", "map" => "5", "enc" => "1"))
  poll(s)
  $live = { :role => :guest, :bid => "g1", :seats => [15] }
  take(s, 13, map_message("invite", "bid" => "f1", "troop" => "93", "seats" => "15", "map" => "5", "enc" => "0"))
  take(s, 13, map_message("invite", "bid" => "f1", "troop" => "93", "seats" => "0,15", "map" => "5", "enc" => "0"))
  take(s, 15, map_message("off", "bid" => "g1"))
end
INVITES << scenario("a guest whose host calls their battle off goes back or breaks it off", true, nil, raiders.call) do |s|
  $live = { :role => :guest, :bid => "g2", :seats => [6] }
  take(s, 6, map_message("off", "bid" => "g2", "why" => "over"))
  take(s, 6, map_message("off", "bid" => "g2", "why" => "closed"))
  take(s, 6, map_message("off", "bid" => "g2"))
  $own_troop = true
  take(s, 6, map_message("off", "bid" => "g2", "why" => "closed"))
  $own_troop = false
  $active = true
  take(s, 6, map_message("off", "bid" => "g2"))
end
INVITES << scenario("an invite that is off is forgotten, and its host's freeze ends", true, nil, raiders.call) do |s|
  take(s, 6, map_message("freeze", "map" => "5"))
  take(s, 6, map_message("invite", "bid" => "q1", "troop" => "40", "seats" => "0", "map" => "5", "enc" => "1"))
  take(s, 6, map_message("off", "bid" => "q1"))
  take(s, 13, map_message("freeze", "map" => "5"))
  take(s, 3, map_message("invite", "bid" => "q2", "troop" => "40", "seats" => "0", "map" => "5", "enc" => "1"))
  take(s, 13, map_message("off", "map" => "5"))
end
INVITES << scenario("invites the running battles' requests cover", true, nil, raiders.call) do |s|
  $hot_ask = [6, "h1"]
  take(s, 6, map_message("invite", "bid" => "h1", "troop" => "40", "seats" => "0", "map" => "5", "hot" => "1"))
  $hot_ask = nil
  $gave_up = [6, "h2"]
  take(s, 6, map_message("invite", "bid" => "h2", "troop" => "40", "seats" => "0", "map" => "5", "hot" => "1"))
  $gave_up = nil
  take(s, 6, map_message("invite", "bid" => "h3", "troop" => "40", "seats" => "0", "map" => "5"))
  $trading_now = true
  poll(s)
  $trading_now = false
  take(s, 6, map_message("invite", "bid" => "h4", "troop" => "40", "seats" => "0", "map" => "5"))
  step(s, "decline_waiting", "reason" => "the player's battle b9 began") { COOP.decline(COOP.instance_variable_get(:@invite)[:peer], COOP.instance_variable_get(:@invite)[:message], "the player's battle b9 began") }
end

write_cases("invites.json", "scenarios" => INVITES)
