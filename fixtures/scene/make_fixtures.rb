#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the story scene's queue and checks next to this file, cases.json,
# from coop_scene.rbx as it kept them before they moved to C# (MGQOnline.Game's Scene folder): how
# a teller's changes of a frame are merged and split into the messages they go out in, and which
# changes a viewer refuses before the game's own facts are asked. Each queue scenario is a list of
# steps, a change kept or a flush with the messages it sent; each check case is one change and the
# refusal the viewer logged, nil for one taken. MGQOnline.Game.Tests replays them against the C#
# classes, and the script tests' stand-in (GameScript/Tests/scene_support.rb) is checked against
# them.
#
# It runs on the coop_scene.rbx of commit d7bc93af, which still kept the rules, with the
# stand-ins below, on Ruby 3.3:
#
#   git show d7bc93af:GameScript/Multiplayer/Scripts/coop_scene.rbx > old_scene.rbx
#   ruby fixtures/scene/make_fixtures.rb old_scene.rbx

require "json"
require_relative "../../GameScript/Tests/support"

# The log, whose lines the check cases read the refusals from.
$log = []
module MGQ_Multiplayer::Log; def self.write(line); $log << line; end; end

# The frame counter the script reads.
$frame = 1000
module Graphics; def self.frame_count; $frame; end; end

# The classes the battle line codec writes and reads.
class Game_Battler; end
class Game_Action; end
class Game_ActionResult; end
class Game_BaseItem; end
module RPG
  class BaseItem; end
  class Skill < BaseItem; end
  class Item < BaseItem; end
  class State < BaseItem; end
  class Weapon < BaseItem; end
  class Armor < BaseItem; end
  class MoveRoute
    attr_accessor :repeat, :skippable, :wait, :list
    def initialize; @repeat = true; @skippable = false; @wait = false; @list = [MoveCommand.new]; end
  end
  class MoveCommand
    attr_accessor :code, :parameters
    def initialize(code = 0, parameters = []); @code = code; @parameters = parameters; end
  end
  class SE
    def initialize(name = "", volume = 100, pitch = 100); end
    def play(*pos); end
    def self.stop; end
    def self.fade(time); end
  end
  class BGM < SE; end
  class BGS < SE; end
  class ME < SE; end
end
Tone = Struct.new(:red, :green, :blue, :gray)
Color = Struct.new(:red, :green, :blue, :alpha)

# A picture, a screen and the map, which take every change.
class Game_Picture
  attr_reader :name
  def initialize; @name = ""; end
  def show(name, *rest); @name = name; end
  def move(*args); end
  def rotate(speed); end
  def start_tone_change(tone, duration); end
  def erase; @name = ""; end
end
class Game_Screen
  attr_reader :pictures, :brightness, :tone
  def initialize; @pictures = Hash.new { |all, number| all[number] = Game_Picture.new }; @brightness = 255; @tone = Tone.new(0, 0, 0, 0); end
  def start_fadeout(duration); end
  def start_fadein(duration); end
  def start_tone_change(tone, duration); @tone = tone; end
  def start_flash(color, duration); end
  def start_shake(power, speed, duration); end
  def od_fadein; end
  def od_fadeout; end
end
class Game_Interpreter; def update; end; def setup(list, _event_id = 0); end; end
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id]; end; def []=(id, value); @data[id] = value; end; end
class Game_Variables < Game_Switches; end
class Game_SelfSwitches; def initialize; @data = {}; end; def [](key); @data[key]; end; def []=(key, value); @data[key] = value; end; end
class Game_CharacterBase; attr_accessor :animation_id, :balloon_id; end
class Game_Character < Game_CharacterBase; def force_move_route(route); end; def restore_move_route; end; end
class Game_Event < Game_Character; attr_reader :id; def initialize(id); @id = id; end; def erase; end; end
class Game_Player < Game_Character
  attr_accessor :transparent
  def id; -1; end
  def move_route_forcing; false; end
  def x; 3; end
  def y; 4; end
  def center(x, y); end
end
class Game_System; attr_accessor :zoom_mode; def initialize; @zoom_mode = 100; end; end
class Game_Map
  attr_accessor :map_id, :interpreter, :events
  attr_reader :screen
  def initialize; @map_id = 7; @screen = Game_Screen.new; @interpreter = Game_Interpreter.new; @events = { 1 => Game_Event.new(1), 2 => Game_Event.new(2) }; end
  def update(main = false); end
  def change_tileset(id); end
  def change_battleback(one, two); end
  def change_parallax(*args); end
  def display_x; 0.0; end
  def display_y; 0.0; end
end
class Scene_Map; end
module Audio
  %w(bgm_play bgm_stop bgm_fade bgs_play bgs_stop bgs_fade me_play me_stop me_fade se_play se_stop).each { |call| define_singleton_method(call) { |*_args| } }
end
module SceneManager; class << self; attr_accessor :scene; end; end
module DataManager; def self.extract_save_contents(contents); end; def self.setup_new_game; end; end

# The world: one viewer, who tells the story the player watches, and the messages sent.
$sent = []
module MGQ_MpOverworldSync
  module Peers; Peer = Struct.new(:seat, :state); end
  def self.route(field, _gate = nil, &handler); end
  def self.who(peer); "#{peer.state['name']} (seat #{peer.seat})"; end
end
VIEWER = MGQ_MpOverworldSync::Peers::Peer.new(4, { "name" => "Friend", "id" => "f", "map" => "7", "telling" => "1" })
module MGQ_MpCoop
  MAP_PREFIX = "m:"
  def self.route(field, &handler); end
  def self.route_map(field, &handler); end
  module Scope
    def self.raid?; $raid; end
    def self.viewers; [VIEWER]; end
    def self.teller; VIEWER; end
    def self.telling?(_peer); true; end
    def self.story_from?(_peer); true; end
    def self.watches?(_peer); true; end
    def self.heard_from(_peer); end
    def self.tell_each(_peers, field, value, fields = {}); $sent << { "map" => fields["map"], "pscene" => value, "args" => fields["args"] }; true; end
  end
end
# The story plays for the party, skipped while $skipping is.
module MGQ_MpCoopEvents
  SKIP_SEND_FRAMES = 10
  def self.story_playing?; true; end
  def self.skip_held?; $skipping ? true : false; end
  def self.leading_story?; true; end
end
# Gathering: the story's map is the player's, and nobody is taken along.
module MGQ_MpCoopGather
  def self.story_map?(map_id); map_id == $game_map.map_id; end
  def self.taken_along; []; end
  def self.take_place_ban(id, banned, map); end
end
# Every story value is the world's and known, and no scene switch or ban.
module MGQ_MpWorldStory; def self.personal?(_kind, _key); false; end; end
module MGQ_MpStoryState
  PLACE_BANS = []
  def self.scene_switch?(_id); false; end
  def self.known_id?(_kind, _id); true; end
  def self.deep_copy(value); value; end
end
module MGQ_MpStoryKeys; def self.applying; yield; end; end
# This game has every picture.
module MGQ_MpOverworld; def self.graphic?(_folder, _name); true; end; end

script = ARGV[0] || abort("Name the coop_scene.rbx of commit d7bc93af, see the header.")
load File.join(SCRIPTS_DIR, "core_log.rbx")
load File.join(SCRIPTS_DIR, "core_hooks.rbx")
load File.join(SCRIPTS_DIR, "core_game_access.rbx")
load File.join(SCRIPTS_DIR, "battles_sync_wire.rbx")
load File.expand_path(script)
SCENE = MGQ_MpCoopScene
WIRE = MGQ_MpBattlesSync::Wire

$game_map = Game_Map.new
$game_player = Game_Player.new
$game_system = Game_System.new
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_self_switches = Game_SelfSwitches.new
$data_animations = Array.new(200)
$data_tilesets = Array.new(10, :tileset)
SceneManager.scene = Scene_Map.new
$raid = true
$skipping = false

# The queue scenarios, each its name and steps.
SCENARIOS = []

# Records a queue scenario: each change kept with its line, and each flush with the messages sent.
#
# @param name [String] The scenario.
# @param steps [Array<Hash>] The steps: "change" with "kind", "args", "map", "logged" and "skip", or "flush".
def scenario(name, steps)
  SCENE.forget
  $skipping = false
  $game_map.map_id = 7
  recorded = steps.map do |step|
    $sent.clear
    if step["op"] == "change"
      $skipping = step["skip"] ? true : false
      $game_map.map_id = step["map"]
      SCENE.send_change(step["kind"], step["args"], step["logged"] != false)
      { "op" => "change", "kind" => step["kind"], "line" => WIRE.line(step["args"]), "map" => step["map"], "logged" => step["logged"] != false, "skip" => $skipping }
    else
      SCENE.flush_changes
      { "op" => "flush", "messages" => $sent.dup }
    end
  end
  SCENARIOS << { "name" => name, "steps" => recorded }
end

PICTURE_ARGS = [0, 0, 0, 100, 100, 255, 0]
MOVE_ARGS = [0, 10, 10, 100, 100, 255, 0, 30]

scenario("the changes of a frame go out in one message, in their order, a lone one as itself", [
  { "op" => "change", "kind" => "picture.show", "args" => [3, "story_cg"] + PICTURE_ARGS, "map" => 7 },
  { "op" => "change", "kind" => "screen.start_tone_change", "args" => [Tone.new(-68, -68, 0, 0), 30], "map" => 7 },
  { "op" => "change", "kind" => "player.transparent", "args" => [true], "map" => 7 },
  { "op" => "change", "kind" => "map.camera", "args" => [6.0, 5.5], "map" => 7, "logged" => false },
  { "op" => "flush" },
  { "op" => "flush" },
  { "op" => "change", "kind" => "picture.erase", "args" => [3], "map" => 7 },
  { "op" => "flush" },
])

scenario("a picture's move replaces its last move that nothing else of the picture followed", [
  { "op" => "change", "kind" => "picture.move", "args" => [3] + MOVE_ARGS, "map" => 7 },
  { "op" => "change", "kind" => "picture.move", "args" => [3, 0, 20] + MOVE_ARGS[2..-1], "map" => 7 },
  { "op" => "change", "kind" => "picture.move", "args" => [4] + MOVE_ARGS, "map" => 7 },
  { "op" => "change", "kind" => "picture.rotate", "args" => [4, 2], "map" => 7 },
  { "op" => "change", "kind" => "picture.move", "args" => [4, 0, 0, 6] + MOVE_ARGS[3..-1], "map" => 7 },
  { "op" => "change", "kind" => "picture.move", "args" => [3, 0, 30] + MOVE_ARGS[2..-1], "map" => 7 },
  { "op" => "flush" },
])

scenario("the camera keeps its last place, a sound effect only while the skip is held, and a move route always", [
  { "op" => "change", "kind" => "map.camera", "args" => [1.0, 1.0], "map" => 7, "logged" => false },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["Door", 80, 100], "map" => 7 },
  { "op" => "change", "kind" => "event.route", "args" => [-1, true, false, [[4], [0]]], "map" => 7 },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["Knock", 80, 100], "map" => 7 },
  { "op" => "change", "kind" => "event.route", "args" => [-1, true, false, [[16], [0]]], "map" => 7 },
  { "op" => "change", "kind" => "map.camera", "args" => [2.0, 1.0], "map" => 7, "logged" => false },
  { "op" => "flush" },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["Door", 80, 100], "map" => 7, "skip" => true },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["Knock", 80, 100], "map" => 7, "skip" => true },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["Bell", 80, 100], "map" => 7, "skip" => true },
  { "op" => "flush" },
])

scenario("the story values waiting merge into the newer ones, each key once, the older first", [
  { "op" => "change", "kind" => "story.values", "args" => [[0, 5, true], [1, 1001, 30], [2, [7, 1, "A"], true]], "map" => 7 },
  { "op" => "change", "kind" => "picture.show", "args" => [3, "cg"] + PICTURE_ARGS, "map" => 7 },
  { "op" => "change", "kind" => "story.values", "args" => [[1, 1001, 31], [0, 6, false]], "map" => 7 },
  { "op" => "change", "kind" => "story.values", "args" => [[2, [7, 1, "A"], false]], "map" => 7 },
  { "op" => "flush" },
])

scenario("the changes of each map go out apart, in their order", [
  { "op" => "change", "kind" => "picture.show", "args" => [3, "cg"] + PICTURE_ARGS, "map" => 7 },
  { "op" => "change", "kind" => "screen.start_fadeout", "args" => [30], "map" => 7 },
  { "op" => "change", "kind" => "screen.start_fadein", "args" => [30], "map" => 8 },
  { "op" => "change", "kind" => "picture.erase", "args" => [3], "map" => 7 },
  { "op" => "flush" },
])

scenario("changes past MAX_BATCH_BYTES go out in several messages, a lone long one alone", [
  { "op" => "change", "kind" => "audio.se_play", "args" => ["x" * 100_000, 80, 0], "map" => 7, "logged" => false },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["x" * 100_000, 80, 1], "map" => 7, "logged" => false },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["x" * 100_000, 80, 2], "map" => 7, "logged" => false },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["x" * 100_000, 80, 3], "map" => 7, "logged" => false },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["x" * 100_000, 80, 4], "map" => 7, "logged" => false },
  { "op" => "flush" },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["y" * 100_000, 80, 0], "map" => 7, "logged" => false },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["y" * 300_000, 80, 100], "map" => 7, "logged" => false },
  { "op" => "change", "kind" => "audio.se_play", "args" => ["y" * 100_000, 80, 1], "map" => 7, "logged" => false },
  { "op" => "flush" },
])

scenario("more than MAX_BATCH changes go out in several messages", (0...300).map { |n| { "op" => "change", "kind" => "picture.rotate", "args" => [n % 100 + 1, n], "map" => 7, "logged" => false } } + [{ "op" => "flush" }])

# The check cases: each change, the map it happened on, the player's map and the refusal.
CHECKS = []

# Records a check case from the refusal the viewer logs, the arguments read back from their line
# as a viewer reads them.
#
# @param kind [String] What changes.
# @param args [Array] Its arguments.
# @param map [Integer] The teller's map.
# @param here [Integer] The player's map.
def check(kind, args, map = 7, here = 7)
  $game_map.map_id = here
  $log.clear
  MGQ_MpLog.instance_variable_set(:@logged, {})
  SCENE.take_change(VIEWER, kind, WIRE.parse(WIRE.line(args)), map)
  failed = $log.find { |line| line =~ /failed:/ }
  raise "#{kind} #{args.inspect[0, 60]}: #{failed}" if failed

  refusals = $log.map { |line| line[/\Aco-op scene: ignored [^:]*: (.*)\z/m, 1] }.compact
  raise "#{kind} #{args.inspect[0, 60]} logged #{refusals.size} refusals" if refusals.size > 1

  CHECKS << { "kind" => kind, "line" => WIRE.line(args), "map" => map, "here" => here, "refusal" => refusals[0] }
end

check("picture.show", [3, "story_cg"] + PICTURE_ARGS)
check("picture.show", [3.5, "story_cg"] + PICTURE_ARGS)
check("picture.show", ["3", "story_cg"] + PICTURE_ARGS)
check("picture.show", [10, "ev_aguni._hb1"] + PICTURE_ARGS)
check("picture.show", [5, "../../evil"] + PICTURE_ARGS)
check("picture.show", [9, "a..b"] + PICTURE_ARGS)
check("picture.show", [9, "a/b"] + PICTURE_ARGS)
check("picture.show", [9, ""] + PICTURE_ARGS)
check("picture.show", [9, "x" * 60 + "/"] + PICTURE_ARGS)
check("picture.show", [101, "story_cg"] + PICTURE_ARGS)
check("picture.show", [0, "story_cg"] + PICTURE_ARGS)
check("picture.show", [nil, "story_cg"] + PICTURE_ARGS)
check("picture.show", [3, "story_cg"] + PICTURE_ARGS[0, 6])
check("picture.show", [3, "story_cg"] + PICTURE_ARGS + [1])
check("picture.show", [3, "story_cg", 0, 0, 0, 100, 100, 255, 3])
check("picture.show", [3, "story_cg", 0.5, 0, 0, 100, 100, 255, 0])
check("picture.show", [3, 7] + PICTURE_ARGS)
check("picture.exit", [3])
check("picture", [3])
check("picture.erase", [3])
check("picture.erase", [3, 1])
check("picture.start_tone_change", [10, Tone.new(-68, -68, 0, 0), 30])
check("picture.start_tone_change", [10, "dark", 30])
check("picture.start_tone_change", [10, Color.new(0, 0, 0, 0), 30])
check("picture.move", [12] + MOVE_ARGS)
check("picture.move", [12, 0, Float::INFINITY, 0, 100, 100, 255, 0, 30])
check("picture.move", [12, 0, 0, 0, 100, 100, 255, 0, -1])
check("picture.move", [12, 0, 0, 0, 100, 100, 255, 0, 2.5])
check("picture.move", [12, 0, 10.5, -20, 100, 100, 255, 0, 30.0])
check("picture.move", [12, 0, 100_000, -100_000, 100, 100, 255, 0, 36_000])
check("picture.move", [12, 0, 100_001, 0, 100, 100, 255, 0, 30])
check("picture.move", [12, 0, 0, 0, 100, 100, 255, 0, 36_001])
check("picture.move", [12, 1.0, 0, 0, 100, 100, 255, 0, 30])
check("picture.move", [12, 0, 0, 0, 100, 100, 255, -1, 30])
check("picture.rotate", [12, 1_000_000_000])
check("picture.rotate", [12, -5])
check("picture.rotate", [12, 2.5])
check("picture.rotate", [12, nil])
check("screen.start_fadeout", [30])
check("screen.start_fadeout", [30, 1])
check("screen.start_fadeout", [])
check("screen.start_fadeout", ["30"])
check("screen.start_fadein", [0])
check("screen.exit", [])
check("screen", [])
check("screen.start_tone_change", [Tone.new(-68, -68, 0, 0), 30])
check("screen.start_tone_change", ["dark", 30])
check("screen.start_flash", [Color.new(255, 255, 255, 170), 20])
check("screen.start_flash", [Color.new(255, 255, 255, 170), 20.0])
check("screen.start_flash", [Color.new(255, 255, 255, 170), 20.5])
check("screen.start_flash", ["white", 20])
check("screen.start_flash", [Tone.new(255, 255, 255, 170), 20])
check("screen.start_shake", [10, 5, 30])
check("screen.start_shake", [5, 9, 30])
check("screen.start_shake", [-1, 9, 30])
check("screen.start_shake", [0.5, 9, 30])
check("screen.od_fadein", [])
check("screen.od_fadeout", [1])
check("player.transparent", [true])
check("player.transparent", [])
check("player.hide", [])
check("story.values", [[0, 5, true]])
check("story.values", [])
check("story.other", [])
check("event.route", [-1, true, false, [[4], [0]]])
check("event.route", [-1, true, false, [[4], [0]]], 7, 8)
check("event.balloon", [1, 3])
check("event.animation", [1, 3], 8, 7)
check("event.erase", [2])
check("event.explode", [1])
check("audio.se_play", ["Door", 80, 100])
check("audio.se_play", ["../x", 80, 100])
check("audio.se_play", ["x:y", 80, 100])
check("audio.se_play", ["", 80, 100])
check("audio.se_play", ["x" * 101, 80, 100])
check("audio.se_play", ["x" * 100, 80, 100])
check("audio.se_play", ["Door", 80, 100], 8, 7)
check("audio.me_play", ["Fanfare", 80, 100], 8, 7)
check("audio.bgm_play", ["Theme", 100, 100, 0])
check("audio.bgm_play", ["Theme", 100, 100, 0], 8, 7)
check("audio.bgm_play", ["../Theme", 100, 100, 0])
check("audio.bgm_stop", [])
check("audio.bgs_fade", [30])
check("audio.foo", [])
check("audio.se_stop", [])
check("map.camera", [6.0, 5.0])
check("map.camera", [6, 5])
check("map.camera", [1])
check("map.camera", ["a", "b"])
check("map.camera", [1.0, nil])
check("map.camera", [6.0, 5.0], 8, 7)
check("map.tileset", [2])
check("map.tileset", [2], 8, 7)
check("map.battleback", ["a", "b"])
check("map.parallax", ["a", true, false, 1, 2])
check("map.zoom", [150])
check("map.fly", [])
check("nothing", [])
check("", [])
check("picture.show.more", [3, "story_cg"] + PICTURE_ARGS)

# The batch cases: each a message's changes and whether the viewer refuses it whole.
BATCHES = []

# Records a batch case from the refusal the viewer logs.
#
# @param name [String] The case.
# @param entries [Array] The message's changes.
def batch(name, entries)
  $game_map.map_id = 7
  $log.clear
  MGQ_MpLog.instance_variable_set(:@logged, {})
  SCENE.take_batch(VIEWER, WIRE.parse(WIRE.line(entries)), 7)
  refusal = $log.map { |line| line[/\Aco-op scene: ignored \d+ changes from [^:]*: (.*)\z/m, 1] }.compact[0]
  BATCHES << { "name" => name, "line" => WIRE.line(entries), "refusal" => refusal }
end

batch("three changes", [["picture.show", [14, "ahead"] + PICTURE_ARGS], ["event.balloon", [1, 3]], ["picture.move", [14] + MOVE_ARGS]])
batch("none", [])
batch("MAX_BATCH changes", Array.new(SCENE::MAX_BATCH) { ["picture.rotate", [15, 1]] })
batch("one more", Array.new(SCENE::MAX_BATCH + 1) { ["picture.rotate", [15, 1]] })
batch("a text among them", [["picture.rotate", [15, 1]], "picture.rotate"])
batch("arguments that are no list", [["picture.rotate", [15, 1]], ["picture.rotate", 1]])
batch("a kind that is no text", [[7, [15, 1]]])
batch("a change with a third part", [["picture.rotate", [15, 1], 1]])

File.write(File.join(__dir__, "cases.json"),
           JSON.pretty_generate({ "source" => "coop_scene.rbx at d7bc93af", "max_batch" => SCENE::MAX_BATCH, "max_batch_bytes" => SCENE::MAX_BATCH_BYTES,
                                  "max_picture" => SCENE::MAX_PICTURE, "most_amount" => SCENE::MOST_AMOUNT, "most_frames" => SCENE::MOST_FRAMES, "most_shake" => SCENE::MOST_SHAKE,
                                  "queue" => SCENARIOS, "checks" => CHECKS, "batches" => BATCHES }) + "\n")
puts "wrote #{SCENARIOS.size} queue scenarios, #{CHECKS.size} check cases and #{BATCHES.size} batch cases"
