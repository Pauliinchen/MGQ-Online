#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the NPCs players share on a map next to this file, cases.json, from
# coop_npcs.rbx as it kept them before the Map Owner's sends and the follower's checks moved to C#
# (MGQOnline.Game's Npcs/NpcSync): the Map Owner's whole maps to newcomers, its changes on the beat
# and its resends of a whole map that failed, the follower's checks of the map, the Map Owner and
# the whole map before its parts, and every map starting anew. Each scenario is a list of steps; a
# step's operation runs, then the step records what the script sent, logged and follows. Who the
# Map Owner is stays the scripts' (coop_scope.rbx, coop_castle.rbx), so each step names them, and the
# script's own lines about it, its walking and its placing are left out. MGQOnline.Game.Tests
# replays the cases against the C# machine.
#
# It runs on the coop_npcs.rbx of commit 40f11e4d, which still kept the rules, with the stand-ins
# below, on Ruby 3.3:
#
#   git show 40f11e4d:GameScript/Multiplayer/Scripts/coop_npcs.rbx > old_npcs.rbx
#   ruby fixtures/npcs/make_fixtures.rb old_npcs.rbx

require "json"
require_relative "../../GameScript/Tests/support"

# The log, whose lines the cases record.
$logs = []
module MGQ_Multiplayer::Log; def self.write(line); $logs << line; end; end

# The messages sent, which the cases record; sending fails while $fails.
$sent = []

# An event of the map: where it stands, which way it faces and the page it shows.
class Game_Event
  def initialize(x, y, direction, page); @x = x; @y = y; @direction = direction; @page = page; end
  def mgq_mp_page; @page; end
  def update_self_movement; end
  def collide_with_characters?(_x, _y); false; end
  def near_the_player?; false; end
  def move_toward_player; end
end
# The map, its id and its events.
class Game_Map
  attr_accessor :map_id, :events
  def initialize; @map_id = 3; @events = {}; end
  def update(_main = false); end
end

# The world: messages written as overworld_sync.rbx's Me.encode writes them.
module MGQ_MpOverworldSync
  module Peers; Peer = Struct.new(:seat, :state, :ghost); end
  def self.who(peer); peer == :me ? "the player" : peer ? "#{peer.state['name']} (seat #{peer.seat})" : "an unknown player"; end
  def self.encode(state); state.map { |key, value| "#{key}=#{value.to_s.gsub(/[\r\n]/, ' ')}" }.join("\n") + "\n\n"; end
  def self.tell(seat, fields); $sent << [seat, encode(fields)]; !$fails; end
end

# The party's and the map's sends as coop.rbx's tell and coop_scope.rbx's tell_map and Scope.tell
# of 40f11e4d write them: the party's id $party, a Raid World while $raid, the players present
# $present.
module MGQ_MpCoop
  MAP_PREFIX = "map_"
  def self.route(_field, &_handler); end
  def self.route_map(_field, &_handler); end
  def self.event_name(_id); ""; end
  def self.tell(seat, field, value, fields = {})
    MGQ_MpOverworldSync.tell(seat, { field => value, "party" => $party }.merge(fields))
  end
  def self.tell_map(seat, field, value, fields = {})
    message = { MAP_PREFIX + field => value, "mmap" => $game_map.map_id }.merge(fields)
    return MGQ_MpOverworldSync.tell(seat, message) if seat >= 0
    return true if Scope.peers_on($game_map.map_id).empty?

    MGQ_MpOverworldSync.tell(-1, message)
  end
  module Scope
    def self.tell(seat, field, value, fields = {}); $raid ? MGQ_MpCoop.tell_map(seat, field, value, fields) : MGQ_MpCoop.tell(seat, field, value, fields); end
    def self.peers_on(map_id); $present.select { |peer| peer.state["map"].to_i == map_id }; end
  end
end

script = ARGV[0] || abort("Name the coop_npcs.rbx of commit 40f11e4d, see the header.")
load File.join(SCRIPTS_DIR, "core_log.rbx")
load File.join(SCRIPTS_DIR, "core_hooks.rbx")
load File.join(SCRIPTS_DIR, "core_game_access.rbx")
load File.expand_path(script)
NPCS = MGQ_MpCoopNpcs

# Who shares the map and who its Map Owner is stay the scripts', so the steps name them; the
# script's lines about the Map Owner, its walking and its placing stay the scripts' too, and the
# page turns it logs are recorded as turns.
class << NPCS
  def peers_here; $members; end
  def owner(_members); $owner; end
  def note_owner(_owner, _members); end
  def follow; end
  def following?; false; end
  def note_pages(changed)
    changed.each do |id, state|
      before = @sent[id]
      $turned << [id, before[3], state[3]] if before && before[3] != state[3]
    end
  end
end

$game_map = Game_Map.new

# The other players, by id: their seat, name and when they entered their map.
def peers
  {
    "a" => MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "aaaa0001", "name" => "Anna", "since" => "1000", "map" => "5" }),
    "b" => MGQ_MpOverworldSync::Peers::Peer.new(3, { "id" => "bbbb0002", "name" => "Bert", "since" => "3000", "map" => "5" }),
    "c" => MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "cccc0003", "name" => "Cleo", "since" => "5000", "map" => "5" }),
  }
end

# The scenarios, each its name, whether it plays in a Raid World and its steps.
SCENARIOS = []

# Records a scenario of steps, starting with no part on map 3.
#
# @param name [String] What the scenario shows.
# @param raid [Boolean] Whether it plays in a Raid World, else in Anna's party of a Classic world.
# @param steps [Array<Hash>] The operations, see run_step.
def scenario(name, raid, steps)
  $raid = raid
  $party = raid ? nil : "aaaa0001p1"
  $by_id = peers
  $present = $by_id.values
  $members = []
  $owner = nil
  $fails = false
  $game_map.map_id = 3
  $game_map.events = {}
  NPCS.change_role(nil)
  NPCS.instance_variable_set(:@map_id, nil)
  recorded = steps.map { |step| step.merge("answer" => run_step(step)) }
  SCENARIOS << { "name" => name, "raid" => raid, "steps" => recorded }
end

# Runs one operation and reads what the script answers.
#
# @param step [Hash] "op" and its fields: "update" ("map", "owner" an id, "me" or nil, "members"
#   the ids sharing the map, "events" [[id, x, y, d, page], ...], "times" how many frames, 1 by
#   default), "take" ("from", "map", "full", "events"; through the party's gate in a Classic world,
#   the map's in a Raid World), "since" ("of", "since"), "move" ("of", "map"), "fails" ("fails").
# @return [Hash] What the script answers after the step.
def run_step(step)
  $logs.clear
  $sent.clear
  $turned = []
  case step["op"]
  when "update"
    $game_map.map_id = step["map"]
    $game_map.events = Hash[step["events"].map { |id, x, y, d, page| [id, Game_Event.new(x, y, d, page)] }]
    $members = step["members"].map { |id| $by_id[id] }
    $owner = step["owner"] == "me" ? :me : $by_id[step["owner"]]
    (step["times"] || 1).times { NPCS.update }
  when "take"
    peer = $by_id[step["from"]]
    if $raid
      NPCS.take(peer, { "map_npcs" => step["map"].to_s, "mmap" => step["map"].to_s, "full" => step["full"].to_s, "events" => step["events"], "npcs" => step["map"].to_s })
    else
      NPCS.take(peer, { "npcs" => step["map"].to_s, "party" => $party, "full" => step["full"].to_s, "events" => step["events"] })
    end
  when "since" then $by_id[step["of"]].state["since"] = step["since"]
  when "move" then $by_id[step["of"]].state["map"] = step["map"].to_s
  when "fails" then $fails = step["fails"]
  end
  role = NPCS.instance_variable_get(:@role)
  {
    "sent" => $sent.dup, "logs" => $logs.dup, "turned" => $turned, "role" => role && role.to_s, "whole_map" => NPCS.instance_variable_get(:@whole_map),
    "targets" => NPCS.targets.map { |id, state| [id, state] },
  }
end

EVENTS = [[1, 4, 4, 2, 0], [2, 7, 3, 4, 1], [5, 9, 9, 8, -1]]
MOVED = [[1, 5, 4, 6, 0], [2, 7, 3, 4, 2], [5, 9, 9, 8, -1]]

scenario("the Map Owner sends a newcomer the whole map at once, everyone what changed on its beat, and a whole map that failed again on the beat", false, [
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["a"], "events" => EVENTS },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["a"], "events" => EVENTS, "times" => 14 },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["a"], "events" => MOVED },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["a", "b"], "events" => MOVED },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["a", "b"], "events" => MOVED, "times" => 14 },
  { "op" => "since", "of" => "a", "since" => "1100" },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["a", "b"], "events" => MOVED },
  { "op" => "fails", "fails" => true },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["a", "b", "c"], "events" => EVENTS },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["a", "b", "c"], "events" => EVENTS, "times" => 12 },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["a", "b", "c"], "events" => EVENTS },
  { "op" => "fails", "fails" => false },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["a", "b", "c"], "events" => EVENTS, "times" => 15 },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["b", "c"], "events" => EVENTS, "times" => 15 },
  { "op" => "update", "map" => 5, "owner" => "a", "members" => ["a", "b", "c"], "events" => EVENTS },
])

scenario("a follower takes only the Map Owner's events of their map, nothing of a map before its whole, and starts anew on every map", false, [
  { "op" => "update", "map" => 5, "owner" => "a", "members" => ["a", "b"], "events" => EVENTS },
  { "op" => "take", "from" => "a", "map" => 5, "full" => 0, "events" => "1:5,4,6,0" },
  { "op" => "take", "from" => "b", "map" => 5, "full" => 1, "events" => "1:4,4,2,0;2:7,3,4,1" },
  { "op" => "take", "from" => "a", "map" => 6, "full" => 1, "events" => "1:4,4,2,0" },
  { "op" => "take", "from" => "a", "map" => 5, "full" => 1, "events" => "1:4,4,2,0;2:7,3,4,1;5:9,9,8,-1" },
  { "op" => "take", "from" => "a", "map" => 5, "full" => 0, "events" => "2:7,3,4,2;1:5,4,6,0" },
  { "op" => "take", "from" => "a", "map" => 5, "full" => 1, "events" => "2:1,1,2,0" },
  { "op" => "move", "of" => "a", "map" => 7 },
  { "op" => "update", "map" => 7, "owner" => "a", "members" => ["a"], "events" => [[1, 2, 2, 2, 0]] },
  { "op" => "take", "from" => "a", "map" => 7, "full" => 0, "events" => "1:3,2,6,0" },
  { "op" => "take", "from" => "a", "map" => 7, "full" => 1, "events" => "1:3,2,6,0" },
  { "op" => "update", "map" => 7, "owner" => nil, "members" => [], "events" => [[1, 2, 2, 2, 0]] },
  { "op" => "take", "from" => "a", "map" => 7, "full" => 1, "events" => "1:3,2,6,0" },
])

scenario("in a Raid World the Map Owner sends through the map's gate, and a follower takes the events through it", true, [
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["c"], "events" => EVENTS },
  { "op" => "update", "map" => 5, "owner" => "me", "members" => ["c"], "events" => MOVED, "times" => 15 },
  { "op" => "update", "map" => 5, "owner" => "a", "members" => ["a", "c"], "events" => MOVED },
  { "op" => "take", "from" => "a", "map" => 5, "full" => 1, "events" => "1:4,4,2,0;2:7,3,4,1" },
  { "op" => "take", "from" => "a", "map" => 5, "full" => 0, "events" => "1:5,4,6,0" },
])

lines = SCENARIOS.map { |entry| "    " + JSON.generate(entry) }
constants = { "send_frames" => NPCS::SEND_FRAMES }
text = "{\n  \"source\": \"coop_npcs.rbx at 40f11e4d, Ruby #{RUBY_VERSION}\",\n  \"constants\": #{JSON.generate(constants)},\n  \"scenarios\": [\n#{lines.join(",\n")}\n  ]\n}\n"
File.write(File.join(__dir__, "cases.json"), text)
puts "wrote #{SCENARIOS.size} scenarios"
