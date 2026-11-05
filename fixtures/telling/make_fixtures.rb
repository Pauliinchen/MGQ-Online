#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Writes the golden cases of a telling's continuity next to this file, cases.json, from
# coop_events.rbx as it kept them before they moved to C# (MGQOnline.Game's Telling/TellingMachine):
# whether a story event that starts tells, goes on with the telling that ended in the same frame or
# that moved the player onto its map, or starts a telling anew, and whether the telling still goes
# on after its event ended. Each scenario is a list of steps; a step's operation runs, then the
# step records what the script answered. MGQOnline.Game.Tests replays them against the C# machine.
#
# It runs on the coop_events.rbx of commit c2e63c81, which still kept the rules, with the
# stand-ins below, on Ruby 3.3:
#
#   git show c2e63c81:GameScript/Multiplayer/Scripts/coop_events.rbx > old_events.rbx
#   ruby fixtures/telling/make_fixtures.rb old_events.rbx

require "json"
require_relative "../../GameScript/Tests/support"

# The log, whose lines tell how a telling went on.
$log = []
module MGQ_Multiplayer::Log; def self.write(line); $log << line; end; end

# The frame counter the script reads.
$frame = 0
module Graphics; def self.frame_count; $frame; end; end

# The game's switches, none on, so the Library replays nothing.
$game_switches = {}
# The game's common events, none of them the player's own.
$data_common_events = []

# The map's interpreter: its commands and whether it runs an event.
class Game_Interpreter
  attr_accessor :busy, :list
  def running?; @busy ? true : false; end
end

# An event of the map: its id, trigger and the list of its one page.
class Game_Event
  attr_reader :id, :trigger, :list
  def initialize(id, trigger, list); @id, @trigger, @list = id, trigger, list; end
  def mgq_mp_page; 0; end
  def mgq_mp_pages; [Struct.new(:list).new(@list)]; end
end

# The map: its id, its interpreter and its events.
class Game_Map
  attr_accessor :map_id, :interpreter, :events
  def initialize; @map_id = 3; @interpreter = Game_Interpreter.new; @events = {}; end
end

# The player, who reserved a transfer while $transfer is set.
class Game_Player; def transfer?; $transfer ? true : false; end; end

# The world: notices and names, no messages.
module MGQ_MpOverworldSync
  def self.notice(*); end
  def self.who(peer); peer == :me ? "the player" : peer.to_s; end
  def self.state_fields(*); end
  def self.route(*); end
  def self.on_tick(*); end
  module Me; def self.id; "me"; end; def self.map_since; 1000; end; end
  module Peers; Peer = Struct.new(:seat, :state); def self.all; []; end; def self.present; []; end; end
end

# The party and the scope: a Raid World where the player alone tells.
module MGQ_MpCoop
  def self.route(*); end
  def self.route_map(*); end
  def self.in_party?; false; end
  def self.party_leader; nil; end
  def self.bytes_of(_fields); 0; end
  module Scope
    def self.raid?; true; end
    def self.sharing?; true; end
    def self.teller; MGQ_MpCoopEvents.telling? ? :me : nil; end
    def self.viewers; []; end
    def self.follows_teller?; false; end
    def self.leads_story?; true; end
    def self.peers_here; []; end
    def self.story_map?(map_id); map_id == $game_map.map_id; end
    def self.tell(*); true; end
    def self.tell_each(*); true; end
    def self.key_of(_player); [1000, "me"]; end
    module Raid; def self.first_teller_here; :me; end; end
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
  def self.place_fields; {}; end
end

# The party's story: how far the player's is, from $progress.
module MGQ_MpCoopStory; def self.own_markers; [$progress, 0, 0, 0]; end; end

# Where a write comes from, which the script does not read here.
module MGQ_MpStoryKeys; def self.site_of(_interpreter); "map:3:1:1"; end; end

# The game classes the script hooks, enough for the hooks to register.
class Game_Interpreter; def execute_command; end; def setup(*); end; def run; end; def wait_for_message; end; end
class Game_Map; def update; end; def setup_starting_map_event; end; def setup_autorun_common_event; end; end
class Game_Player; def perform_transfer; end; end
class Game_Party; def gain_item(*); end; def gain_gold(*); end; end
class Window_Message; def process_input; end; def input_pause; end; end
module RPG; class SE; def play; end; end; class Item; end; class Weapon; end; class Armor; end; end

script = ARGV[0] || abort("Name the coop_events.rbx of commit c2e63c81, see the header.")
load File.join(SCRIPTS_DIR, "core_log.rbx")
load File.join(SCRIPTS_DIR, "core_hooks.rbx")
load File.join(SCRIPTS_DIR, "core_game_access.rbx")
load File.expand_path(script)
EVENTS = MGQ_MpCoopEvents

# The kind every page sorts as, set by each step.
$kind = :story
class << EVENTS
  # Answers the kind of the step instead of sorting.
  def sorting(_list, _event = nil, index = nil)
    index ? { :story => false } : { :kind => $kind, :list_kind => $kind, :may_tell => false, :scene => false, :marks => [] }
  end
end

$game_map = Game_Map.new
$game_player = Game_Player.new
$progress = 12
$transfer = false

# The scenarios, each its name and steps.
SCENARIOS = []

# Records a scenario of steps: each step's operation and what the script answered after it.
#
# @param name [String] What the scenario shows.
# @param steps [Array<Hash>] The operations, see run_step.
def scenario(name, steps)
  $frame = 0
  $game_map = Game_Map.new
  $transfer = false
  EVENTS.instance_variable_set(:@telling, false)
  EVENTS.instance_variable_set(:@told_last_frame, nil)
  EVENTS.instance_variable_set(:@moved_by_story_at, nil)
  EVENTS.instance_variable_set(:@pending_say, nil)
  recorded = steps.map { |step| step.merge("answer" => run_step(step)) }
  SCENARIOS << { "name" => name, "steps" => recorded }
end

# Runs one operation and reads what the script answers.
#
# @param step [Hash] "op": "start" (a map event, "story" whether it sorts as story, "by_itself"
#   whether it runs by itself), "common" (a common event, "story"), "end", "frame" (the map's
#   update ends and a frame passes), "wait" ("frames"), "transfer" ("to", during the event that
#   runs) or "progress" ("p", the story moving on).
# @return [Hash] "telling" and "or_moved" after the step; for a start also "continued" ("frame",
#   "moved" or nil) and "tsm".
def run_step(step)
  continued = nil
  case step["op"]
  when "start", "common"
    $kind = step["story"] ? :story : :talk
    $log.clear
    interpreter = $game_map.interpreter
    if step["op"] == "start"
      event = Game_Event.new(step["event"] || 1, step["by_itself"] ? 3 : 0, [])
      $game_map.events = { event.id => event }
      interpreter.list = event.list
      EVENTS.started(interpreter, event.list, event.id)
    else
      interpreter.list = []
      EVENTS.started(interpreter, interpreter.list, 0)
    end
    interpreter.busy = true
    continued = $log.any? { |line| line.include?("goes on with the telling that started") } ? "frame" : $log.any? { |line| line.include?("goes on with the telling that moved") } ? "moved" : nil
  when "end"
    EVENTS.finished($game_map.interpreter)
    $game_map.interpreter.busy = false
  when "frame"
    EVENTS.note_told_frame
    $frame += 1
  when "wait"
    step["frames"].times { EVENTS.note_told_frame; $frame += 1 }
  when "transfer"
    $transfer = true
    EVENTS.moving($game_player)
    $transfer = false
    $game_map.map_id = step["to"]
  when "progress"
    $progress = step["p"]
  end
  answer = { "telling" => EVENTS.telling?, "or_moved" => EVENTS.telling_or_moved? }
  if %w(start common).include?(step["op"])
    answer["continued"] = continued
    answer["tsm"] = EVENTS.state_fields["tsm"]
  end
  answer
end

scenario("the story's next event in the frame its last one ended goes on with the telling; one after a frame without starts anew", [
  { "op" => "progress", "p" => 12 },
  { "op" => "start", "story" => true, "event" => 52 },
  { "op" => "frame" },
  { "op" => "progress", "p" => 13 },
  { "op" => "end" },
  { "op" => "start", "story" => true, "event" => 52 },
  { "op" => "end" },
  { "op" => "frame" },
  { "op" => "start", "story" => true, "event" => 52 },
  { "op" => "end" },
  { "op" => "frame" },
])

scenario("a telling that moves the player goes on at the story's next event that runs by itself on the new map, through the game's transfer process", [
  { "op" => "progress", "p" => 12 },
  { "op" => "start", "story" => true, "event" => 52 },
  { "op" => "transfer", "to" => 432 },
  { "op" => "end" },
  { "op" => "frame" },
  { "op" => "common", "story" => false },
  { "op" => "end" },
  { "op" => "frame" },
  { "op" => "progress", "p" => 13 },
  { "op" => "start", "story" => true, "by_itself" => true, "event" => 53 },
  { "op" => "transfer", "to" => 433 },
  { "op" => "end" },
  { "op" => "frame" },
  { "op" => "wait", "frames" => 300 },
  { "op" => "start", "story" => true, "by_itself" => true, "event" => 54 },
  { "op" => "end" },
  { "op" => "frame" },
])

scenario("a transfer outside a telling goes on with none, a story event the player starts on the new map is a new telling, one that runs by itself goes on with the move", [
  { "op" => "progress", "p" => 14 },
  { "op" => "transfer", "to" => 434 },
  { "op" => "frame" },
  { "op" => "start", "story" => true, "by_itself" => true, "event" => 55 },
  { "op" => "transfer", "to" => 435 },
  { "op" => "end" },
  { "op" => "frame" },
  { "op" => "progress", "p" => 15 },
  { "op" => "start", "story" => true, "event" => 56 },
  { "op" => "transfer", "to" => 436 },
  { "op" => "end" },
  { "op" => "frame" },
  { "op" => "progress", "p" => 16 },
  { "op" => "start", "story" => true, "by_itself" => true, "event" => 57 },
  { "op" => "end" },
  { "op" => "frame" },
])

scenario("a talk tells nothing, and a story event one frame after a telling's event ended in a frame of its own starts anew", [
  { "op" => "progress", "p" => 12 },
  { "op" => "start", "story" => false, "event" => 60 },
  { "op" => "end" },
  { "op" => "frame" },
  { "op" => "start", "story" => true, "event" => 61 },
  { "op" => "end" },
  { "op" => "start", "story" => false, "event" => 60 },
  { "op" => "end" },
  { "op" => "start", "story" => true, "event" => 61 },
  { "op" => "end" },
  { "op" => "frame" },
  { "op" => "frame" },
  { "op" => "start", "story" => true, "event" => 61 },
  { "op" => "frame" },
  { "op" => "end" },
  { "op" => "frame" },
])

scenario("a telling that moved the player ends once the story's next event there is one the player starts, or once CONTINUE_FRAMES passed", [
  { "op" => "progress", "p" => 12 },
  { "op" => "start", "story" => true, "event" => 52 },
  { "op" => "transfer", "to" => 432 },
  { "op" => "end" },
  { "op" => "frame" },
  { "op" => "wait", "frames" => 299 },
  { "op" => "start", "story" => true, "by_itself" => true, "event" => 53 },
  { "op" => "transfer", "to" => 433 },
  { "op" => "end" },
  { "op" => "frame" },
  { "op" => "start", "story" => true, "event" => 56 },
  { "op" => "end" },
  { "op" => "frame" },
])

lines = SCENARIOS.map { |entry| "    " + JSON.generate(entry) }
text = "{\n  \"source\": \"coop_events.rbx at c2e63c81, Ruby #{RUBY_VERSION}\",\n  \"continue_frames\": #{EVENTS::CONTINUE_FRAMES},\n  \"scenarios\": [\n#{lines.join(",\n")}\n  ]\n}\n"
File.write(File.join(__dir__, "cases.json"), text)
puts "wrote #{SCENARIOS.size} scenarios"
