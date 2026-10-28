#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Writes the golden cases of a story's pages next to this file, cases.json, from coop_events.rbx as
# it kept them before they moved to C# (MGQOnline.Game's Telling/StoryPages): which pages a teller
# tells, keeps while the player skips and tells the end of, and how a viewer keeps the pages heard,
# shows them once the player is free, leaves out those the teller moved past and holds the page
# shown until it is over. Each scenario is a list of steps; a step's operation runs, then the step
# records what the script did. MGQOnline.Game.Tests replays them against the C# class, and the
# script tests' stand-in (GameScript/Tests/pages_support.rb) is checked against them.
#
# It runs on the coop_events.rbx of commit 68e7b75d, the last that kept the rules, with the
# stand-ins below, on Ruby 3.3:
#
#   git show 68e7b75d:GameScript/Multiplayer/Scripts/coop_events.rbx > old_events.rbx
#   ruby fixtures/pages/make_fixtures.rb old_events.rbx

require "json"
require_relative "../../GameScript/Tests/support"

# The log, which the script writes.
$log = []
module MGQ_Multiplayer::Log; def self.write(line); $log << line; end; end

# The frame counter the script reads.
$frame = 0
module Graphics; def self.frame_count; $frame; end; end

# The game's switches, none on, so the Library replays nothing.
$game_switches = {}
# The game's common events, none of them the player's own.
$data_common_events = []

# The keys the player holds: the game's skip (:X) while $skip is set, confirm (:C) while $confirm is.
module Input
  def self.press?(key); key == :X && $skip ? true : false; end
  def self.trigger?(key); key == :C && $confirm ? true : false; end
end

# The message window's content, which the teller's story shows and a viewer's page fills.
class Game_Message
  attr_accessor :texts, :choices, :face_name, :face_index, :background, :position
  def initialize; clear; end
  def clear; @texts = []; @choices = []; @face_name = ""; @face_index = 0; @background = 0; @position = 2; end
  def add(line); @texts << line; end
end

# The scene shown: the map's while $on_map is set.
class Scene_Map; end
module SceneManager; def self.scene; $on_map ? Scene_Map.new : Object.new; end; end

# The map's interpreter: whether it runs an event.
class Game_Interpreter
  attr_accessor :busy, :list
  def running?; @busy ? true : false; end
end

# The map: its id and its interpreter.
class Game_Map
  attr_accessor :map_id, :interpreter, :events
  def initialize; @map_id = 7; @interpreter = Game_Interpreter.new; @events = {}; end
end

# The world: the player is always free on the map, every face file is known.
module MGQ_MpOverworldSync
  def self.notice(*); end
  def self.who(peer); peer.respond_to?(:state) ? peer.state["name"].to_s : peer.to_s; end
  def self.map_free?; true; end
  def self.state_fields(*); end
  def self.route(*); end
  def self.on_tick(*); end
  module Me; def self.id; "me"; end; def self.map_since; 1000; end; end
  module Peers; Peer = Struct.new(:seat, :state); def self.all; $teller_here ? [$teller] : []; end; def self.present; all; end; end
end
module MGQ_MpOverworld; def self.graphic?(*); true; end; end

# The party and the scope: the teller in $teller while $teller_here is set, whose telling is told
# by $telling, a Raid World while $raid is set, sharing the story while $sharing is set; what goes
# out is kept in $sent.
module MGQ_MpCoop
  def self.route(*); end
  def self.route_map(*); end
  def self.in_party?; true; end
  def self.party_leader; nil; end
  def self.bytes_of(_fields); 0; end
  def self.random_id(_length, _radix = 36); "sess01"; end
  module Scope
    def self.raid?; $raid ? true : false; end
    def self.sharing?; $sharing ? true : false; end
    def self.teller; $teller_here ? $teller : nil; end
    def self.telling?(_peer); $telling ? true : false; end
    def self.viewers; [MGQ_MpOverworldSync::Peers::Peer.new(4, { "name" => "Viewer", "id" => "v" })]; end
    def self.follows_teller?; true; end
    def self.leads_story?; true; end
    def self.peers_here; []; end
    def self.tell(*); true; end
    def self.tell_each(_peers, _field, kind, fields); $sent << [kind, fields]; true; end
  end
end

# Gathering: nobody to gather, nobody taken along.
module MGQ_MpCoopGather
  def self.drop_hold; end
  def self.hold(*); end
  def self.gathered?; true; end
  def self.holding_story?; false; end
  def self.forget_taken_along; end
  def self.note_story_progress; end
  def self.taken_along; []; end
  def self.follow_taken; nil; end
  def self.story_map?(map_id); map_id == $game_map.map_id; end
  def self.warp_ban?; false; end
  def self.place_fields; { "map" => 7 }; end
end

# The game classes the script hooks, enough for the hooks to register.
class Game_Interpreter; def execute_command; end; def setup(*); end; def run; end; def wait_for_message; end; end
class Game_Map; def update; end; def setup_starting_map_event; end; def setup_autorun_common_event; end; end
class Game_Player; def perform_transfer; end; end
class Game_Party; def gain_item(*); end; def gain_gold(*); end; end
class Window_Message; def process_input; end; def input_pause; end; end
module RPG; class SE; def play; end; end; class Item; end; class Weapon; end; class Armor; end; end

script = ARGV[0] || abort("Name the coop_events.rbx of commit 68e7b75d, see the header.")
load File.join(SCRIPTS_DIR, "core_log.rbx")
load File.join(SCRIPTS_DIR, "core_hooks.rbx")
load File.join(SCRIPTS_DIR, "core_game_access.rbx")
load File.expand_path(script)
EVENTS = MGQ_MpCoopEvents
EVENTS.give_way_to { $giving_way }

# The scenarios, each its name and steps.
SCENARIOS = []

# Records a scenario of steps: each step's operation and what the script did after it.
#
# @param name [String] What the scenario shows.
# @param steps [Array<Hash>] The operations, see run_step.
def scenario(name, steps)
  $frame = 0
  $game_map = Game_Map.new
  $game_message = Game_Message.new
  $teller = MGQ_MpOverworldSync::Peers::Peer.new(2, { "name" => "Teller", "id" => "t" })
  $teller_here = true
  $telling = true
  $raid = false
  $sharing = true
  $skip = $confirm = $on_map = false
  $giving_way = nil
  %w(@telling @shown @page @session @pending_say @told_at @told_page @skipped_pages @mirrored).each { |name| EVENTS.instance_variable_set(name, nil) }
  EVENTS.instance_variable_set(:@heard, [])
  EVENTS.instance_variable_set(:@done, [])
  EVENTS.instance_variable_set(:@heard_from, "t")
  recorded = steps.map { |step| step.merge("answer" => run_step(step)) }
  SCENARIOS << { "name" => name, "steps" => recorded }
end

# Decodes a list of lines the wire carries.
#
# @param text [String, nil] The lines, Base64 joined by commas.
# @return [Array<String>] The lines.
def lines_of(text)
  text.to_s.split(",").map { |line| line.unpack("m0")[0].force_encoding("UTF-8") }
end

# Runs one operation and reads what the script did.
#
# @param step [Hash] "op" and its fields, each with "frame", the frame it runs at:
#   - "show": the teller's story shows a page ("lines", "choices", "face", "skip");
#   - "passed": the teller moved past it;
#   - "flush": the frame's end ("skip", "telling", "map");
#   - "telling": a new telling starts;
#   - "hear": a page of the teller comes ("page", "lines", "choices" in Base64, "face", "index",
#     "background", "position");
#   - "done": the teller moved past a page ("page");
#   - "forget": another player tells now;
#   - "next": the player is free ("giving_way", "sharing");
#   - "over": the window asks whether its page is over ("teller", "telling", "raid",
#     "giving_way", "confirm", "skip");
#   - "ended": the window finished its page.
# @return [Hash] "sent" (each message told: kind, page, lines, choices), "waiting", "mirroring",
#   and "show" for "next", "over" for "over".
def run_step(step)
  $frame = step["frame"] || $frame
  $sent = []
  interpreter = $game_map.interpreter
  answer = {}
  case step["op"]
  when "show"
    EVENTS.instance_variable_set(:@telling, true)
    $skip = step["skip"] ? true : false
    $game_message.clear
    $game_message.texts = step["lines"].dup
    $game_message.choices = (step["choices"] || []).dup
    $game_message.face_name = step["face"] || ""
    EVENTS.show(interpreter)
  when "passed"
    EVENTS.shown(interpreter)
  when "flush"
    $skip = step["skip"] ? true : false
    $on_map = step["map"] ? true : false
    EVENTS.instance_variable_set(:@telling, step["telling"] ? true : false)
    EVENTS.flush_say
  when "telling"
    EVENTS.note_telling_start
  when "hear"
    message = step.reject { |key, _| %w(op frame).include?(key) }
    EVENTS.hear($teller, message)
  when "done"
    EVENTS.heard_done({ "page" => step["page"] }, $teller)
  when "forget"
    $teller = MGQ_MpOverworldSync::Peers::Peer.new(3, { "name" => "Another", "id" => "a" })
    EVENTS.forget_former_leader($teller)
  when "next"
    $giving_way = step["giving_way"]
    $sharing = step["sharing"] ? true : false
    $game_message.clear
    EVENTS.show_heard
    mirrored = EVENTS.instance_variable_get(:@mirrored)
    answer["show"] = mirrored && $game_message.texts.any? ? { "page" => mirrored[:page], "face" => $game_message.face_name, "index" => $game_message.face_index,
                                                              "background" => $game_message.background, "position" => $game_message.position,
                                                              "lines" => $game_message.texts.dup } : nil
    $giving_way = nil
  when "over"
    $teller_here = step["teller"] ? true : false
    $telling = step["telling"] ? true : false
    $raid = step["raid"] ? true : false
    $giving_way = step["giving_way"]
    $confirm = step["confirm"] ? true : false
    $skip = step["skip"] ? true : false
    answer["over"] = EVENTS.page_done?
    $teller_here = true
    $raid = false
    $giving_way = nil
    $confirm = $skip = false
  when "ended"
    EVENTS.page_ended
  end
  answer["sent"] = $sent.map { |kind, fields| [kind, fields["page"], kind == "say" ? lines_of(fields["lines"]) : nil, kind == "say" ? lines_of(fields["choices"]) : nil] }
  answer["waiting"] = EVENTS.instance_variable_get(:@heard).size
  answer["mirroring"] = EVENTS.mirroring?
  answer
end

# Writes a list of lines as the wire carries them.
#
# @param lines [Array<String>] The lines.
# @return [String] Each in Base64, joined by commas.
def wire(*lines)
  lines.map { |line| [line].pack("m0") }.join(",")
end

scenario("a teller tells each new page and its end; an empty page or the same page again tells nothing", [
  { "op" => "show", "frame" => 10, "lines" => ["Hello.", "How are you?"], "face" => "alice" },
  { "op" => "show", "frame" => 11, "lines" => ["Hello.", "How are you?"], "face" => "alice" },
  { "op" => "passed", "frame" => 40 },
  { "op" => "passed", "frame" => 41 },
  { "op" => "show", "frame" => 42, "lines" => [], "choices" => [] },
  { "op" => "show", "frame" => 43, "lines" => ["Which way?"], "choices" => ["Left", "Right"] },
  { "op" => "passed", "frame" => 60 },
  { "op" => "show", "frame" => 61, "lines" => ["Ünïcode ✓"] },
])

scenario("holding the skip, a teller tells one page every SKIP_SEND_FRAMES, the last kept and told with its end once due", [
  { "op" => "show", "frame" => 100, "lines" => ["Page 1"], "skip" => true },
  { "op" => "passed", "frame" => 100 },
  { "op" => "show", "frame" => 101, "lines" => ["Page 2"], "skip" => true },
  { "op" => "passed", "frame" => 101 },
  { "op" => "flush", "frame" => 101, "skip" => true, "telling" => true, "map" => true },
  { "op" => "show", "frame" => 102, "lines" => ["Page 3"], "skip" => true },
  { "op" => "passed", "frame" => 102 },
  { "op" => "show", "frame" => 103, "lines" => ["Page 4"], "skip" => true },
  { "op" => "flush", "frame" => 105, "skip" => true, "telling" => true, "map" => true },
  { "op" => "flush", "frame" => 110, "skip" => true, "telling" => true, "map" => true },
  { "op" => "passed", "frame" => 111 },
  { "op" => "show", "frame" => 112, "lines" => ["Page 5"], "skip" => true },
  { "op" => "passed", "frame" => 112 },
  { "op" => "show", "frame" => 113, "lines" => ["Page 6"], "skip" => true },
  { "op" => "flush", "frame" => 114, "skip" => false, "telling" => true, "map" => true },
  { "op" => "passed", "frame" => 115 },
])

scenario("a page kept goes out once the telling ended or another scene shows; a new telling starts the pace anew unless a page is kept", [
  { "op" => "show", "frame" => 200, "lines" => ["First"], "skip" => true },
  { "op" => "show", "frame" => 201, "lines" => ["Kept"], "skip" => true },
  { "op" => "flush", "frame" => 202, "skip" => true, "telling" => false, "map" => true },
  { "op" => "show", "frame" => 203, "lines" => ["Kept again"], "skip" => true },
  { "op" => "flush", "frame" => 204, "skip" => true, "telling" => true, "map" => false },
  { "op" => "telling", "frame" => 205 },
  { "op" => "show", "frame" => 206, "lines" => ["New telling"], "skip" => true },
  { "op" => "show", "frame" => 207, "lines" => ["Kept in the new telling"], "skip" => true },
  { "op" => "telling", "frame" => 208 },
  { "op" => "show", "frame" => 209, "lines" => ["Still paced"], "skip" => true },
  { "op" => "flush", "frame" => 220, "skip" => true, "telling" => true, "map" => true },
])

scenario("a viewer shows the pages heard in turn, holds each until the teller moved past it and the player read it", [
  { "op" => "hear", "frame" => 10, "page" => "s.1", "lines" => wire("Hello.", "Long line of a page"), "face" => "alice", "index" => 2, "background" => 1, "position" => 0 },
  { "op" => "hear", "frame" => 11, "page" => "s.2", "lines" => wire("Which way?"), "choices" => wire("Left", "Right") },
  { "op" => "next", "frame" => 12, "sharing" => true },
  { "op" => "over", "frame" => 13, "teller" => true, "telling" => true },
  { "op" => "done", "frame" => 20, "page" => "s.1" },
  { "op" => "over", "frame" => 21, "teller" => true, "telling" => true },
  { "op" => "over", "frame" => 22, "teller" => true, "telling" => true, "confirm" => true },
  { "op" => "ended", "frame" => 22 },
  { "op" => "next", "frame" => 23, "sharing" => true },
  { "op" => "done", "frame" => 24, "page" => "s.2" },
  { "op" => "over", "frame" => 100, "teller" => true, "telling" => true },
  { "op" => "over", "frame" => 102, "teller" => true, "telling" => true },
  { "op" => "over", "frame" => 103, "teller" => true, "telling" => true },
  { "op" => "ended", "frame" => 103 },
  { "op" => "over", "frame" => 104, "teller" => true, "telling" => true },
])

scenario("a page ends with the skip, with something waiting for the player, without the teller, or once the telling ended", [
  { "op" => "hear", "frame" => 10, "page" => "s.1", "lines" => wire("One") },
  { "op" => "hear", "frame" => 10, "page" => "s.2", "lines" => wire("Two") },
  { "op" => "hear", "frame" => 10, "page" => "s.3", "lines" => wire("Three") },
  { "op" => "hear", "frame" => 10, "page" => "s.4", "lines" => wire("Four") },
  { "op" => "done", "frame" => 10, "page" => "s.1" },
  { "op" => "next", "frame" => 11, "sharing" => true },
  { "op" => "over", "frame" => 12, "teller" => true, "telling" => true, "skip" => true },
  { "op" => "ended", "frame" => 12 },
  { "op" => "next", "frame" => 13, "sharing" => true },
  { "op" => "over", "frame" => 14, "teller" => true, "telling" => true },
  { "op" => "done", "frame" => 14, "page" => "s.2" },
  { "op" => "over", "frame" => 15, "teller" => true, "telling" => true, "giving_way" => "the story's call" },
  { "op" => "ended", "frame" => 15 },
  { "op" => "next", "frame" => 16, "sharing" => true },
  { "op" => "over", "frame" => 17, "teller" => false, "telling" => true },
  { "op" => "ended", "frame" => 17 },
  { "op" => "next", "frame" => 18, "sharing" => true },
  { "op" => "over", "frame" => 19, "teller" => true, "telling" => false, "raid" => true },
  { "op" => "ended", "frame" => 19 },
  { "op" => "hear", "frame" => 20, "page" => "s.5", "lines" => wire("Five") },
  { "op" => "next", "frame" => 21, "sharing" => true },
  { "op" => "over", "frame" => 22, "teller" => true, "telling" => false },
  { "op" => "over", "frame" => 141, "teller" => true, "telling" => false },
  { "op" => "over", "frame" => 142, "teller" => true, "telling" => false },
  { "op" => "ended", "frame" => 142 },
])

scenario("a viewer busy for long leaves out the oldest pages the teller moved past, CATCH_UP_PAGES behind at most, and keeps MAX_HEARD", [
  { "op" => "hear", "frame" => 1, "page" => "s.1", "lines" => wire("Old page 1") },
  { "op" => "hear", "frame" => 1, "page" => "s.2", "lines" => wire("Old page 2") },
  { "op" => "hear", "frame" => 1, "page" => "s.3", "lines" => wire("Old page 3") },
  { "op" => "hear", "frame" => 1, "page" => "s.4", "lines" => wire("Old page 4") },
  { "op" => "hear", "frame" => 1, "page" => "s.5", "lines" => wire("Old page 5") },
  { "op" => "hear", "frame" => 1, "page" => "s.6", "lines" => wire("Old page 6") },
  { "op" => "done", "frame" => 1, "page" => "s.1" },
  { "op" => "done", "frame" => 1, "page" => "s.2" },
  { "op" => "done", "frame" => 1, "page" => "s.3" },
  { "op" => "done", "frame" => 1, "page" => "s.5" },
  { "op" => "next", "frame" => 2, "sharing" => true },
  { "op" => "over", "frame" => 3, "teller" => true, "telling" => true },
  { "op" => "ended", "frame" => 3 },
] + (7..40).map { |number| { "op" => "hear", "frame" => 4, "page" => "s.#{number}", "lines" => wire("Page #{number}") } } + [
  { "op" => "next", "frame" => 5, "sharing" => true },
  { "op" => "ended", "frame" => 5 },
])

scenario("while something waits for the player, no page starts and those the teller moved past go; without sharing the pages go", [
  { "op" => "hear", "frame" => 1, "page" => "s.1", "lines" => wire("Passed") },
  { "op" => "hear", "frame" => 1, "page" => "s.2", "lines" => wire("Not yet passed") },
  { "op" => "done", "frame" => 1, "page" => "s.1" },
  { "op" => "next", "frame" => 2, "sharing" => true, "giving_way" => "the story's call" },
  { "op" => "next", "frame" => 3, "sharing" => false },
  { "op" => "hear", "frame" => 4, "page" => "s.3", "lines" => "", "choices" => "" },
  { "op" => "hear", "frame" => 5, "page" => "s.4", "lines" => wire("Line", "") + "," },
  { "op" => "next", "frame" => 6, "sharing" => true },
  { "op" => "ended", "frame" => 6 },
])

scenario("the pages of a former teller go once another tells", [
  { "op" => "hear", "frame" => 1, "page" => "s.1", "lines" => wire("Former teller") },
  { "op" => "done", "frame" => 1, "page" => "s.1" },
  { "op" => "forget", "frame" => 2 },
  { "op" => "hear", "frame" => 3, "page" => "s.1", "lines" => wire("Same id, new teller") },
  { "op" => "next", "frame" => 4, "sharing" => true },
  { "op" => "over", "frame" => 5, "teller" => true, "telling" => true },
])

lines = SCENARIOS.map { |entry| "    " + JSON.generate(entry) }
text = "{\n  \"source\": \"coop_events.rbx at 68e7b75d, Ruby #{RUBY_VERSION}\",\n" \
       "  \"frames\": {\"skip_send\": #{EVENTS::SKIP_SEND_FRAMES}, \"read\": #{EVENTS::READ_FRAMES}, \"read_per_character\": #{EVENTS::READ_FRAMES_PER_CHARACTER}, " \
       "\"most_read\": #{EVENTS::MOST_READ_FRAMES}, \"stale\": #{EVENTS::STALE_FRAMES}},\n" \
       "  \"max_heard\": #{EVENTS::MAX_HEARD}, \"max_done\": #{EVENTS::MAX_DONE}, \"catch_up_pages\": #{EVENTS::CATCH_UP_PAGES},\n" \
       "  \"scenarios\": [\n#{lines.join(",\n")}\n  ]\n}\n"
File.write(File.join(__dir__, "cases.json"), text)
puts "wrote #{SCENARIOS.size} scenarios"
