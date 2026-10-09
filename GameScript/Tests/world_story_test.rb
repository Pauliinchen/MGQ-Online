#----------------------------------------------------------------
#  world_story_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Followed a player in an earlier part, who is behind the world's story now instead of playing their own
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# Covers world_story.rbx with coop_story.rbx and coop_choices.rbx: a Raid World's story fetched,
# laid over the player's own values or kept apart, written back with its counters, refused writes
# and routes, the relay's push and the poll, the Great Decision's choice and the world's return to
# it, and the choices each player keeps their own.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$calls = []
$reads = []
$state = ""
$notices = []
$raid = true

# The DLL: each call is noted and starts, and the story's state is what $state holds.
module MGQ_Multiplayer
  module Link
    # The requests of the story's exports, whose header says busy once one starts, as the DLL's does.
    KINDS = { "mp_raid_story_fetch" => "fetch", "mp_raid_story_post" => "post", "mp_raid_route_lock" => "lock" }

    # A function of the DLL, which notes its calls.
    Function = Struct.new(:name) do
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, args]
        kind = KINDS[name]
        $state = "#{kind}=busy\n" + $state.gsub(/^#{kind}(_\w+)?=.*\n/, "") if kind
        1
      end
    end
    def self.function(name); Function.new(name); end
    # The headers leave the story's text out, as the DLL's do.
    def self.read(name, size)
      check_dll_call(name, ["", size])
      head = $state.split("\n\n", 2)[0].to_s
      text = { "mp_raid_story_state" => $state, "mp_raid_story_headers" => head.empty? ? "" : head + "\n\n" }[name].to_s
      $reads << [name, text.size]
      text.dup.force_encoding("ASCII-8BIT")
    end
    def self.parse(text)
      head, payload = text.force_encoding("UTF-8").split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| key, value = line.split("=", 2); state[key] = value if value }
      state
    end
  end
end
module MGQ_MpOverworldSync
  STORY_FIELD = "story_rev"
  module Peers; Peer = Struct.new(:seat, :state); def self.present; []; end; end
  module Me; def self.id; "me"; end; end
  def self.in_world?; true; end
  def self.notice(text, icon = nil); $notices << text; end
  def self.map_free?; SceneManager.scene.is_a?(Scene_Map) && !$game_map.interpreter.running?; end
  def self.who(peer); peer == :me ? "the player" : peer.to_s; end
  def self.route(field, &block); ($routes ||= {})[field] = block; end
  def self.on_tick(&block); ($ticks ||= []) << block; end
  def self.state_fields(*); end
end
module MGQ_MpCoop
  module Party; def self.members; []; end; def self.leader; nil; end; end
  module Scope; def self.raid?; $raid; end; def self.teller; $teller; end; def self.watches?(_peer); true; end; end
  def self.route(*); end
  def self.party_leader; nil; end
end
module MGQ_MpCoopEvents
  def self.telling?; $telling ? true : false; end
  def self.pvp_running?; false; end
  def self.chest_keys; []; end
  def self.chest_key?(_key); false; end
end
module MGQ_MpCoopGather; def self.join_story; ($joined ||= 0); $joined += 1; end; end
# The rewards table's chests, of which one is in the checks.
module MGQ_MpCoopStoryRewards
  CHESTS = [[12, 3, "A"]]
  GROUPS = []
  ACTORS = []
  SIDED = { :skills => [], :actors => [] }
  ROUTE = { :skills => [], :actors => [] }
end
module MGQ_MpActions
  LINE_COLOR = :line_color
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)
  def self.offer(*); end
end
module MGQ_MpWorld
  World = Struct.new(:directory_id)
  class << self; attr_accessor :world; end
  def self.raid?; $raid; end
  # The world screen's form, which the screen of choices draws with, stood in by its fields alone.
  class Form
    Field = Struct.new(:key, :kind, :label, :row, :hint, :options) do
      def choices; options[:choices] || []; end
    end
    attr_reader :title, :fields
    def initialize(title, fields, values); @title = title; @fields = fields; @values = values; end
    def [](key); @values[key]; end
  end
end
MGQ_MpWorld.world = MGQ_MpWorld::World.new("w1")
class Window_MpWorldForm; def initialize(*); end; end
class Scene_MenuBase; end
class Scene_Map; end
module SceneManager
  class << self; attr_accessor :scene; end
  def self.call(scene); ($scenes ||= []) << scene; end
end
module Graphics; def self.frame_count; 0; end; end
module RPG
  EventCommand = Struct.new(:code, :indent, :parameters)
  CommonEvent = Struct.new(:list)
end
# Makes an event command.
#
# @param code [Integer] Its code.
# @param params [Array] Its parameters.
# @param indent [Integer] Its indent.
# @return [RPG::EventCommand] The command.
def c(code, params = [], indent = 0); RPG::EventCommand.new(code, indent, params); end
System = Struct.new(:switches, :variables)
$data_system = System.new(Array.new(8000, ""), Array.new(4000, ""))
$data_actors = Array.new(600)
$data_items = [nil]
$data_common_events = Array.new(400)

class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
class Game_SelfSwitches; def initialize; @data = {}; end; def [](key); @data[key] == true; end; def []=(key, value); @data[key] = value; end; end
class Game_Party
  attr_accessor :in_battle
  def initialize; @include_actors = []; end
  def add_stand_actor(id); @include_actors |= [id]; end
  def remove_actor(id); @include_actors.delete(id); end
end
class Game_Actor; def learn_skill(id); end; end
class Game_Interpreter
  attr_reader :list, :index
  attr_accessor :busy
  def setup(list, event_id = 0); @list = list; @index = 0; ($setups ||= []) << list; end
  def running?; @busy ? true : false; end
  def execute_command; end
  def ssw(key); $game_system_switches[key]; end
end
class Game_Map
  attr_accessor :map_id, :interpreter, :need_refresh
  def initialize; @map_id = 3; @interpreter = Game_Interpreter.new; end
  def setup(map_id); @map_id = map_id; end
  def update(main = false); end
end
class Game_Player
  attr_reader :x, :y
  def initialize; @x = 1; @y = 1; end
  def transfer?; false; end
  def perform_transfer; end
end
module DataManager
  def self.make_save_contents; {}; end
  def self.extract_save_contents(contents); end
  def self.load_game_without_rescue(index); end
  def self.create_game_objects; end
  def self.setup_new_game; end
end

load_script "coop_story"
load_script "coop_choices"
load_script "world_story"
story = MGQ_MpWorldStory
choices = MGQ_MpCoopChoices

# Makes a new game's story with some values.
#
# @param variables [Hash] Variables by id.
# @param switches [Array<Integer>] Switches on.
# @param selfs [Hash] Self switches by key.
def new_story(variables = {}, switches = [], selfs = {})
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_self_switches = Game_SelfSwitches.new
  variables.each { |id, value| $game_variables[id] = value }
  switches.each { |id| $game_switches[id] = true }
  selfs.each { |key, value| $game_self_switches[key] = value }
end

# Packs a story the way a game writes it to the relay.
#
# @param variables [Hash] Variables by id.
# @param switches [Array<Integer>] Switches on.
# @param selfs [Hash] Self switches by key.
# @return [String] The packed story.
def packed(variables = {}, switches = [], selfs = {})
  s = []
  v = []
  switches.each { |id| s[id] = true }
  variables.each { |id, value| v[id] = value }
  MGQ_MpCoopStory.pack(MGQ_MpCoopStory.story_lists([s, v, selfs], true))
end

# Sets what the DLL tells of the world's story and the requests.
#
# @param fields [Hash] The headers that differ from an empty story.
# @param text [String] The story.
def relay(fields, text = "")
  head = { "world" => "w1", "rev" => 0, "wrev" => 0, "p" => 0, "r1141" => 0, "r1142" => 0, "r1143" => 0, "clear" => "", "part" => "1",
           "route" => "none", "done" => "", "comps" => "", "checkpoints" => "" }.merge(fields)
  $state = head.map { |key, value| "#{key}=#{value}" }.join("\n") + "\n\n" + text
end

# Runs frames of the map.
#
# @param count [Integer] How many.
def frames(count); count.times { MGQ_MpWorldStory.tick }; end

# The DLL calls of one export since the checks began.
#
# @param name [String] The export.
# @return [Array<Array>] Each call's arguments.
def calls_of(name); $calls.select { |call| call[0] == name }.map { |call| call[1] }; end

# Reads the lists of a story written to the relay.
#
# @param text [String] The story as written.
# @return [Hash{String => String}] Its lists.
def lists_of(text); MGQ_MpCoopStory.unpack(text.chomp("\0")); end

$game_map = Game_Map.new
$game_player = Game_Player.new
$game_party = Game_Party.new
$game_system_switches = {}
SceneManager.scene = Scene_Map.new
$telling = false

# Entering a world nobody wrote a story for: the player's story becomes the world's.
new_story({ 1001 => 12, 3001 => 50, 1029 => 6, 151 => 4 }, [300, 1005, 7016, 4], { [12, 3, "A"] => true, [5, 1, "B"] => true })
frames(1)
check("entering a Raid World fetches its story", calls_of("mp_raid_story_fetch"), [["w1\0"]])
relay("fetch" => "done")
frames(16)
post = calls_of("mp_raid_story_post").last
check("a world without a story takes the player's, built on revision 0", [post && post[0], post && post[1], post && post[2]], ["w1\0", 0, "p=12;r1141=0;r1142=0;r1143=0;clear=\0"])
lists = lists_of(post[3])
check("which leaves out the player's own switches, variables and chests",
      [lists["s"].split(","), lists["v"].split(",").map { |entry| entry.split(":")[0] }.sort, lists["ss"]], [["300"], ["1001", "151"], "5.1.B"])
relay("rev" => 1, "wrev" => 1, "p" => 12, "part" => "1", "post" => "accepted", "post_rev" => 1)
frames(16)
check("an accepted write is the story the player builds on", [story.mode, story.instance_variable_get(:@wrev)], [:world, 1])

# What a write takes and when.
$calls.clear
$game_variables[3001] = 60
$game_switches[1006] = true
$game_self_switches[[12, 3, "A"]] = false
frames(400)
check("the player's own values and chests changing write nothing", calls_of("mp_raid_story_post"), [])
$game_variables[1001] = 13
frames(20)
check("the story moving on waits a moment for the rest of its step", calls_of("mp_raid_story_post"), [])
frames(60)
check("then goes out on the revision it built on", calls_of("mp_raid_story_post").map { |args| [args[1], args[2]] }, [[1, "p=13;r1141=0;r1142=0;r1143=0;clear=\0"]])
$reads.clear
frames(60)
check("while the write runs only the headers are read", $reads.map { |read| read[0] }.uniq, ["mp_raid_story_headers"])
relay("rev" => 2, "wrev" => 2, "p" => 13, "post" => "accepted", "post_rev" => 2)
frames(16)
$calls.clear
$telling = true
$game_switches[301] = true
frames(250)
check("another change of the player's telling waits until the story rests", calls_of("mp_raid_story_post"), [])
$telling = false
frames(200)
check("then goes out in one write", calls_of("mp_raid_story_post").map { |args| [args[1], lists_of(args[3])["s"]] }, [[2, "300,301"]])
relay("rev" => 3, "wrev" => 3, "p" => 13, "post" => "accepted", "post_rev" => 3)
frames(16)

# A write the relay refused for another write since: the world's story comes, and the player's
# changes it lacks stay and go again on the new revision.
$calls.clear
$telling = true
$game_switches[302] = true
frames(400)
check("nothing goes out while the player tells the story", calls_of("mp_raid_story_post"), [])
$telling = false
frames(40)
check("a write goes out on revision 3 soon after the telling", calls_of("mp_raid_story_post").map { |args| args[1] }, [3])
relay({ "rev" => 4, "wrev" => 4, "p" => 13, "post" => "conflict", "post_code" => "rev" }, packed({ 1001 => 13, 151 => 9 }, [300, 301, 303]))
frames(16)
check("refused, it takes the world's story and keeps the player's own change the world lacks",
      [$game_switches[303], $game_variables[151], $game_switches[302], $game_variables[3001], $game_switches[1006]], [true, 9, true, 60, true])
frames(400)
check("which goes out again on the world's revision", calls_of("mp_raid_story_post").map { |args| [args[1], lists_of(args[3])["s"]] }.last, [4, "300,301,302,303"])
relay("rev" => 5, "wrev" => 5, "p" => 13, "post" => "accepted", "post_rev" => 5)
frames(16)

# A write behind the world's: the player's step goes.
$calls.clear
$game_variables[1001] = 14
frames(80)
relay({ "rev" => 6, "wrev" => 6, "p" => 15, "post" => "conflict", "post_code" => "behind" }, packed({ 1001 => 15, 151 => 9 }, [300, 301, 302, 303]))
frames(16)
check("a write behind the world's takes the world's progress", [$game_variables[1001], story.instance_variable_get(:@wrev)], [15, 6])
frames(400)
check("and writes nothing more", calls_of("mp_raid_story_post").size, 1)

# The relay's push and the poll.
$calls.clear
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "6")
frames(1)
check("a push of a revision the player knows fetches nothing", calls_of("mp_raid_story_fetch"), [])
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "9")
frames(1)
check("nor does a message only a player sent", calls_of("mp_raid_story_fetch"), [])
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "9", :relay => true)
frames(1)
check("a newer one fetches the world's story", calls_of("mp_raid_story_fetch").size, 1)
relay({ "rev" => 9, "wrev" => 9, "p" => 15, "fetch" => "done", "end" => "40,7,8" }, packed({ 1001 => 15, 151 => 9 }, [300, 301, 302, 303, 304]))
frames(16)
check("whose changes reach the player", [$game_switches[304], story.endpoint], [true, [40, 7, 8, 2]])
$calls.clear
frames(3600)
check("without a push the story is fetched once a minute", calls_of("mp_raid_story_fetch").size, 1)
relay("rev" => 9, "wrev" => 9, "p" => 15, "fetch" => "done", "end" => "40,7,8")
frames(16)

# A story's transfer is the story's endpoint, written with the next write.
$calls.clear
$telling = true
frames(1)
$game_map.map_id = 41
story.story_transfer
frames(80)
check("the story's transfer waits for the telling to end", calls_of("mp_raid_story_post"), [])
$telling = false
frames(40)
check("the story's transfer writes soon, with the endpoint", calls_of("mp_raid_story_post").map { |args| args[2] }, ["p=15;r1141=0;r1142=0;r1143=0;clear=;end=41,1,1\0"])
relay("rev" => 10, "wrev" => 10, "p" => 15, "end" => "41,1,1", "post" => "accepted", "post_rev" => 10)
frames(16)
$game_map.map_id = 3

# The relay's push of the player's own write comes about as fast as the write's answer.
$calls.clear
$game_variables[1001] = 16
frames(80)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "11", :relay => true)
relay("rev" => 11, "wrev" => 11, "p" => 16, "end" => "41,1,1", "post" => "accepted", "post_rev" => 11)
frames(20)
check("the push of the player's own write fetches nothing", [calls_of("mp_raid_story_post").size, calls_of("mp_raid_story_fetch")], [1, []])
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "12", :relay => true)
frames(1)
check("a later one does", calls_of("mp_raid_story_fetch").size, 1)
relay("rev" => 12, "wrev" => 11, "p" => 16, "end" => "41,1,1", "fetch" => "done")
frames(16)

# Shared changes outside a telling that move no progress: those of an event of the player's own go
# out once it ended, those of parallel events after a while.
$calls.clear
$game_map.interpreter.busy = true
frames(5)
$game_switches[305] = true
$game_map.interpreter.busy = false
frames(400)
check("a shared change of the player's own event goes out once the event ended",
      calls_of("mp_raid_story_post").map { |args| [args[1], lists_of(args[3])["s"]] }, [[11, "300,301,302,303,304,305"]])
relay("rev" => 13, "wrev" => 13, "p" => 16, "end" => "50,2,2", "post" => "accepted", "post_rev" => 13)
frames(16)
$calls.clear
$game_switches[306] = true
frames(300)
check("a change no event of the player's made waits", calls_of("mp_raid_story_post"), [])
frames(700)
check("then goes out too, without the endpoint the player's write set before another player moved it",
      calls_of("mp_raid_story_post").map { |args| [args[1], args[2], lists_of(args[3])["s"]] }, [[13, "p=16;r1141=0;r1142=0;r1143=0;clear=\0", "300,301,302,303,304,305,306"]])
relay("rev" => 14, "wrev" => 14, "p" => 16, "end" => "50,2,2", "post" => "accepted", "post_rev" => 14)
frames(16)

# A write that failed goes again, but not while the player tells the story.
$calls.clear
$game_variables[1001] = 17
frames(80)
relay("rev" => 14, "wrev" => 14, "p" => 16, "end" => "50,2,2", "post" => "failed", "post_error" => "offline")
frames(16)
$telling = true
frames(1900)
check("a write going again waits for the telling to end", calls_of("mp_raid_story_post").size, 1)
$telling = false
frames(5)
check("and goes once it ended", calls_of("mp_raid_story_post").size, 2)
relay("rev" => 15, "wrev" => 15, "p" => 17, "end" => "3,1,1", "post" => "accepted", "post_rev" => 15)
frames(16)

# The player's story events wait for the world's story of a telling they watched on the map.
$teller = MGQ_MpOverworldSync::Peers::Peer.new(2, { "telling" => "1" })
frames(2)
$teller = nil
frames(2)
check("the player's story events wait once a telling they watched ended", story.awaits_teller?, true)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "16", :relay => true)
frames(1)
relay({ "rev" => 16, "wrev" => 16, "p" => 18, "end" => "3,1,1", "fetch" => "done" }, packed({ 1001 => 18 }, [300, 301, 302, 303, 304, 305, 306]))
frames(16)
check("until its story arrived", story.awaits_teller?, false)
$teller = MGQ_MpOverworldSync::Peers::Peer.new(2, { "telling" => "1" })
frames(2)
$teller = nil
frames(601)
check("or for AWAIT_TELLER_FRAMES at most", story.awaits_teller?, false)

# A loaded save in the world's current part: the world's story is laid over it, the player's own
# values kept.
$calls.clear
new_story({ 1001 => 19, 3001 => 70, 1029 => 1, 151 => 2 }, [1010, 7016, 4, 310], { [12, 3, "A"] => true })
story.loaded(:load)
frames(1)
relay({ "rev" => 12, "wrev" => 12, "p" => 20, "part" => "2", "fetch" => "done" }, packed({ 1001 => 20, 151 => 5, 1029 => 9 }, [5, 7017, 311], { [12, 3, "A"] => false, [6, 1, "A"] => true }))
frames(16)
check("a loaded save takes the world's story", [story.mode, $game_variables[1001], $game_variables[151], $game_switches[311], $game_switches[310], $game_self_switches[[6, 1, "A"]]],
      [:world, 20, 5, true, false, true])
check("keeping the player's affection, companions, chests, choices and side",
      [$game_variables[3001], $game_switches[1010], $game_self_switches[[12, 3, "A"]], $game_variables[1029], $game_switches[7016], $game_switches[7017], $game_switches[4], $game_switches[5]],
      [70, true, true, 1, true, false, true, false])
check("and tells the player once", $notices.count("You play the world's story."), 1)

# A loaded save in an earlier part: the player is behind, writes nothing and fetches the world's story
# again once theirs reaches its part.
$calls.clear
$notices.clear
new_story({ 1001 => 10, 151 => 2 }, [310])
story.loaded(:load)
frames(1)
relay({ "rev" => 12, "wrev" => 12, "p" => 25, "part" => "2", "fetch" => "done" }, packed({ 1001 => 25, 151 => 5 }, [311]))
frames(16)
check("a player in an earlier part is behind, keeping their own story without a checkpoint", [story.mode, $game_variables[1001], $game_switches[310], $game_switches[311]], [:behind, 10, true, false])
check("and is told so", $notices, ["The world's story is further than yours."])
$game_variables[1001] = 11
frames(400)
check("and writes nothing", calls_of("mp_raid_story_post"), [])
$game_variables[1001] = 19
frames(31)
check("reaching the world's part fetches its story again", calls_of("mp_raid_story_fetch").size, 2)
relay({ "rev" => 12, "wrev" => 12, "p" => 25, "part" => "2", "fetch" => "done" }, packed({ 1001 => 25, 151 => 5 }, [311]))
frames(16)
check("which the player then plays", [story.mode, $game_variables[1001]], [:world, 25])

# A loaded save further than the world's story: the furthest story wins.
$calls.clear
new_story({ 1001 => 30, 151 => 2 }, [310])
story.loaded(:load)
frames(1)
relay({ "rev" => 14, "wrev" => 13, "p" => 25, "part" => "2", "fetch" => "done" }, packed({ 1001 => 25, 151 => 5 }, [311]))
frames(16)
check("a player further than the world writes their story as the world's", calls_of("mp_raid_story_post").map { |args| [args[1], args[2]] }, [[13, "p=30;r1141=0;r1142=0;r1143=0;clear=\0"]])
relay("rev" => 15, "wrev" => 15, "p" => 30, "part" => "2", "post" => "accepted", "post_rev" => 15)
frames(16)

# The Great Decision: the first route locks the world's.
$calls.clear
new_story({ 1001 => 39 }, [4])
story.loaded(:load)
frames(1)
relay({ "rev" => 20, "wrev" => 20, "p" => 39, "part" => "3", "fetch" => "done" }, packed({ 1001 => 39 }))
frames(16)
$game_variables[1001] = 40
$game_variables[1141] = 1
frames(80)
check("a route the world has not taken is locked before the write", [calls_of("mp_raid_route_lock"), calls_of("mp_raid_story_post")], [[["w1\0", "ad\0"]], []])
class << MGQ_MpCoopStory; alias_method :bring_before_check, :bring; def bring(id); ($brought ||= []) << id; end; end
story.instance_variable_set(:@decision_roster, [5, 45])
$game_party.instance_variable_set(:@include_actors, [45])
relay({ "rev" => 21, "wrev" => 20, "p" => 39, "part" => "3", "route" => "mr", "lock" => "taken", "lock_code" => "route" }, packed({ 1001 => 39 }))
$notices.clear
frames(16)
check("one another player took first gives the player the world's story back", [$game_variables[1001], $game_variables[1141]], [39, 0])
check("and the companions their own decision took away", $brought, [5])
class << MGQ_MpCoopStory; alias_method :bring, :bring_before_check; end
check("and says so", $notices, ["The world took the Monster Realm route first."])
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "22", :relay => true)
frames(1)
relay({ "rev" => 22, "wrev" => 20, "p" => 39, "part" => "3", "route" => "none", "fetch" => "done" }, packed({ 1001 => 39 }))
frames(16)
$calls.clear
$game_variables[1001] = 40
$game_variables[1141] = 1
frames(80)
relay("rev" => 23, "wrev" => 20, "p" => 39, "part" => "3", "route" => "ad", "lock" => "locked")
frames(20)
check("a route locked goes out with the write", calls_of("mp_raid_story_post").map { |args| args[2] }, ["p=40;r1141=1;r1142=0;r1143=0;clear=\0"])
relay("rev" => 24, "wrev" => 24, "p" => 40, "r1141" => 1, "part" => "ad", "route" => "ad", "post" => "accepted", "post_rev" => 24)
frames(16)

# The Great Decision's choice in the game's own event offers only the routes the world may still take.
labels = ["Side with the Dark Goddess", "Side with the Goddess Ilias", "Search for a third way"]
decision = [c(101, ["", 0, 0, 2]), c(102, [labels, 0]), c(402, [0, labels[0]]), c(122, [1002, 1002, 0, 0, 111], 1), c(0, [], 1),
            c(402, [1, labels[1]]), c(122, [1002, 1002, 0, 0, 112], 1), c(0, [], 1), c(402, [2, labels[2]]), c(119, ["decision"], 1), c(0, [], 1), c(404), c(0)]
$data_common_events[380] = RPG::CommonEvent.new(decision)
interpreter = Game_Interpreter.new
# Shows the choice of a fresh Great Decision to the hook, as the world tells its routes.
#
# @param world [Hash] The world's route and finished routes.
# @return [Array<RPG::EventCommand>] The interpreter's commands afterwards.
def offered(interpreter, world)
  interpreter.setup($data_common_events[380].list)
  interpreter.instance_variable_set(:@index, 1)
  MGQ_MpWorldStory.instance_variable_get(:@world).merge!(world)
  MGQ_MpWorldStory.before_command(interpreter)
  interpreter.list
end
list = offered(interpreter, "route" => "none", "done" => ["ad"])
check("after the Angelic Dominion only the Goddess Ilias's side is offered",
      [list[1].parameters[0], list.select { |entry| entry.code == 402 }.map { |entry| entry.parameters }, list.count { |entry| entry.code == 122 }],
      [[labels[1]], [[0, labels[1]]], 1])
check("its branch plays as before", list.find { |entry| entry.code == 122 }.parameters[4], 112)
check("the game's own commands stay as they are", $data_common_events[380].list.size, decision.size)
list = offered(interpreter, "route" => "none", "done" => ["ad", "mr"])
check("after both routes only the third way", [list[1].parameters[0], list.select { |entry| entry.code == 402 }.map { |entry| entry.parameters[0] }], [[labels[2]], [0]])
list = offered(interpreter, "route" => "none", "done" => [])
check("before any route the third way is left out", list[1].parameters[0], labels[0, 2])
list = offered(interpreter, "route" => "mr", "done" => [])
check("a route the world locked is the only one", list[1].parameters[0], [labels[1]])
list = offered(interpreter, "route" => "ad", "done" => ["ad"])
check("but not once the world finished it, before its return", list[1].parameters[0], [labels[1]])
before_route = { "p" => 39, "r1141" => 0, "r1142" => 0, "r1143" => 0, "clear" => [] }
check("a story with no route under way goes on while the world has not started the locked route, not after",
      [story.continues?(before_route, before_route.merge("route" => "ad", "done" => [])), story.continues?(before_route, before_route.merge("p" => 40, "r1141" => 3, "route" => "ad", "done" => []))], [true, false])
$raid = false
list = offered(interpreter, "route" => "none", "done" => ["ad"])
check("a Classic world offers the game's own choice", list.equal?($data_common_events[380].list), true)
$raid = true

# The game's endings in a Raid World are the world's clears.
$game_system_switches = { :ed1 => true, :ed2 => false, :op1 => true }
check("the endings read the world's clear switches", [interpreter.ssw(:ed1), interpreter.ssw(:ed2), interpreter.ssw(:op1)], [false, false, true])
$game_switches[7096] = true
$game_switches[7097] = true
check("which open the third way for the world", [interpreter.ssw(:ed1), interpreter.ssw(:ed2), choices.both_endings?], [true, true, true])
$raid = false
check("a Classic world reads the install's", [interpreter.ssw(:ed2), choices.both_endings?], [false, false])
$raid = true
$game_switches[7096] = $game_switches[7097] = false

# A finished route's credits go back to the Great Decision instead of the Reaper's menu.
$data_common_events[267] = RPG::CommonEvent.new([c(101, ["", 0, 0, 2]), c(117, [154]), c(122, [1002, 1002, 0, 0, 111]), c(122, [1001, 1001, 0, 0, 39]),
                                                 c(121, [4, 4, 0]), c(355, ["add_actor_ex_nc(5)"]), c(111, [0, 1709, 1]), c(355, ["add_actor_ex_nc(45)"], 1), c(0, [], 1), c(412),
                                                 c(122, [57, 57, 0, 0, 407]), c(201, [0, 544, 25, 25, 8, 2]), c(222), c(115), c(0)])
credits = [c(355, ["release_temp_actors"]), c(117, [265]), c(115), c(0)]
$game_variables[1141] = 76
$game_switches[7096] = true
interpreter.setup(credits)
interpreter.instance_variable_set(:@index, 1)
story.before_command(interpreter)
codes = interpreter.list.map { |entry| entry.code }
check("the Reaper's menu becomes the game's return to the Great Decision", [codes.include?(117) && interpreter.list[2].parameters, codes.count(201), interpreter.list.find { |entry| entry.code == 201 }.parameters[1]],
      [[154], 1, 544])
check("without the companions it adds", [interpreter.list.count { |entry| entry.code == 355 }, interpreter.list.any? { |entry| entry.code == 117 && entry.parameters[0] == 265 }], [1, false])
$raid = false
interpreter.setup(credits)
interpreter.instance_variable_set(:@index, 1)
story.before_command(interpreter)
check("a Classic world keeps the Reaper's menu", interpreter.list.equal?(credits), true)
$raid = true

# Anywhere else the Reaper's menu is left out, so one player cannot take the world back.
$game_variables[1141] = 0
$game_variables[1143] = 20
$game_switches[7097] = true
$notices.clear
$joined = 0
story.world["end"] = "40,7,8"
interpreter.setup(credits)
interpreter.instance_variable_set(:@index, 1)
story.before_command(interpreter)
check("the Chaos route's bad end fades in again instead of the Reaper's menu, its event erased, and the player teleports to the story",
      [interpreter.list.map { |entry| entry.code }, $notices, $joined], [[355, 222, 214, 115, 0], ["Time cannot be reset in a Raid World."], 1])
$game_variables[1143] = 25
$game_switches[7039] = true
reaper = [c(221), c(230, [60]), c(117, [265]), c(115), c(0)]
$data_common_events[149] = RPG::CommonEvent.new(reaper)
interpreter.setup(reaper)
interpreter.instance_variable_set(:@index, 2)
story.before_command(interpreter)
check("as is the Reaper's offer in Hades after the Chaos route, where the player stays",
      [interpreter.list.map { |entry| entry.code }, $joined], [[221, 230, 222, 115, 0], 1])
$game_variables[1143] = 0
$game_variables[1141] = 1
$game_switches[7039] = $game_switches[7096] = $game_switches[7097] = false

# The world's story carrying the player past the Great Decision asks the route the world took.
choices.forget("next check")
$calls.clear
new_story({ 1001 => 39 }, [5])
story.loaded(:load)
frames(1)
relay({ "rev" => 30, "wrev" => 30, "p" => 39, "part" => "3", "fetch" => "done" }, packed({ 1001 => 39 }))
frames(16)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "31", :relay => true)
frames(1)
relay({ "rev" => 31, "wrev" => 31, "p" => 40, "r1141" => 2, "part" => "ad", "route" => "ad", "fetch" => "done" }, packed({ 1001 => 40, 1141 => 2 }, [4]))
frames(16)
check("the world's route reaches the player, their side their own", [$game_variables[1141], $game_switches[4], $game_switches[5]], [2, false, true])
check("who confirms it on the screen of choices with that route alone", [choices.instance_variable_get(:@prompts), choices.labels(:decision)], [[:decision], ["Side with the Dark Goddess (World Breaker)"]])
$data_common_events[380] = RPG::CommonEvent.new([c(122, [1002, 1002, 0, 0, 111]), c(111, [0, 5, 0]), c(221, [], 1), c(355, ["delete_actor_ex(26)"], 1), c(201, [0, 430, 25, 19, 8, 2], 1), c(0, [], 1), c(412), c(0)])
$scenes = []
choices.update
screen = choices.take_screen
check("titled as the world's route", [$scenes, screen[:title], screen[:keys]], [[Scene_MpStoryChoices], "The world's route", [:decision]])
screen[:done].call(:decision => 0)
queued = choices.instance_variable_get(:@queued)
check("confirmed, only the player's own half waits: the companions and the side, and the screen faded in again",
      queued.map { |entry| entry.code }, [122, 111, 221, 355, 121, 121, 222, 0])
check("never the Final Chapter's reset, the route's progress or the transfer",
      queued.any? { |entry| (entry.code == 117) || (entry.code == 122 && entry.parameters[0] == 1141) || entry.code == 201 }, false)
choices.forget("next check")

# The world going back to the Great Decision.
$notices.clear
$setups = []
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "33", :relay => true)
frames(1)
relay({ "rev" => 33, "wrev" => 33, "p" => 39, "part" => "3", "clear" => "ad", "done" => "ad", "fetch" => "done", "end" => "407,25,25" }, packed({ 1001 => 39 }, [7096]))
frames(16)
check("the world's return to the Great Decision reaches the player", [$game_variables[1001], $game_variables[1141], $game_switches[7096], story.endpoint], [39, 0, true, [407, 25, 25, 2]])
check("and says so", $notices, ["The world's story went back to the Great Decision."])
check("whose own half plays once the player is free: the Final Chapter's reset, where a game over returns them and the transfer to the Great Decision",
      ($setups.last || []).map { |entry| [entry.code, entry.parameters] }, [[117, [154]], [122, [1002, 1002, 0, 0, 112]], [122, [57, 57, 0, 0, 407]], [201, [0, 544, 25, 25, 8, 2]], [0, []]])
check("the Great Decision then offers the route left", choices.labels(:decision), ["Side with the Goddess Ilias (Judgement)"])

# The choices each player keeps their own in a Raid World.
check("every choice's outcome is the player's own in a Raid World",
      [choices.personal?(:s, 7016), choices.personal?(:s, 7002), choices.personal?(:v, 1029), choices.personal?(:v, 1065), choices.personal?(:s, 151)], [true, true, true, true, false])
$game_variables[1141] = 5
check("and the side, after the Great Decision too", [MGQ_MpCoopStory.personal_switch?(4), MGQ_MpCoopStory.personal_switch?(5)], [true, true])
check("as the story sync, whose story is the world's", MGQ_MpCoopChoices::Offers.peer_option(MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "f" })), nil)
contents = { :switches => $game_switches }
check("a save holds the story as it is", MGQ_MpCoopStory.save_contents(contents).equal?(contents) && contents[:switches].equal?($game_switches), true)
$raid = false
check("a Classic world keeps them the leader's while the player plays their own story", [choices.personal?(:s, 7016), MGQ_MpCoopStory.personal_switch?(4)], [false, false])
$raid = true

# A choice the world's story carries the player past asks their own outcome, their side included.
choices.forget("next check")
$calls.clear
new_story({ 1001 => 5 })
story.loaded(:load)
frames(1)
relay({ "rev" => 40, "wrev" => 40, "p" => 5, "part" => "1", "fetch" => "done" }, packed({ 1001 => 5 }))
frames(16)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "41", :relay => true)
frames(1)
relay({ "rev" => 41, "wrev" => 41, "p" => 10, "part" => "1", "fetch" => "done" }, packed({ 1001 => 10 }))
frames(16)
check("the world's story passing Iliasville and Iliasburg asks the side and Amira", choices.instance_variable_get(:@prompts), [:side, :amira])
choices.forget("test")

# A player further than the world, but on another route than the one it locked, takes the world's story.
$calls.clear
new_story({ 1001 => 40, 1141 => 50 })
story.loaded(:load)
frames(1)
relay({ "rev" => 50, "wrev" => 50, "p" => 40, "r1142" => 10, "part" => "mr", "route" => "mr", "fetch" => "done" }, packed({ 1001 => 40, 1142 => 10 }))
frames(400)
check("a player further on another route than the world's locked one takes the world's story and writes nothing",
      [story.mode, $game_variables[1141], $game_variables[1142], calls_of("mp_raid_story_post"), calls_of("mp_raid_route_lock")], [:world, 0, 10, [], []])
choices.forget("test")

# A step the relay refused is never written again as it was.
$calls.clear
new_story({ 1001 => 30 })
story.loaded(:load)
frames(1)
relay({ "rev" => 51, "wrev" => 51, "p" => 25, "part" => "2", "fetch" => "done" }, packed({ 1001 => 25 }))
frames(16)
relay({ "rev" => 51, "wrev" => 51, "p" => 25, "part" => "2", "post" => "conflict", "post_code" => "behind" }, packed({ 1001 => 25 }))
frames(400)
check("a refused write of a player further than the world takes the world's story instead of writing again",
      [calls_of("mp_raid_story_post").size, story.mode, $game_variables[1001]], [1, :world, 25])

# A world with another route locked but no story yet waits for it.
$calls.clear
new_story({ 1001 => 40, 1141 => 5 })
story.loaded(:load)
frames(1)
relay("rev" => 1, "route" => "mr", "fetch" => "done")
frames(400)
check("a world with another route locked and no story yet is waited for",
      [story.mode, calls_of("mp_raid_story_post"), calls_of("mp_raid_route_lock"), calls_of("mp_raid_story_fetch").size], [nil, [], [], 1])

# The DLL still telling another world's story.
$calls.clear
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "2", :relay => true)
frames(1)
relay({ "world" => "w0", "rev" => 90, "wrev" => 90, "p" => 60, "fetch" => "done" }, packed({ 1001 => 60 }))
frames(16)
check("another world's story is not taken, and the fetch goes again",
      [$game_variables[1001], story.world["rev"], calls_of("mp_raid_story_fetch").size], [40, 1, 2])

# Only a loaded save fetches the world's story anew, not a duel putting the game back.
$calls.clear
DataManager.extract_save_contents({})
frames(1)
check("a duel putting the game back fetches nothing", calls_of("mp_raid_story_fetch"), [])
DataManager.load_game_without_rescue(0)
frames(1)
check("a loaded save fetches the world's story", calls_of("mp_raid_story_fetch").size, 1)

# The world finishing the player's route and starting the next before the player took its story.
choices.forget("next check")
new_story({ 1001 => 40, 1141 => 30 })
story.loaded(:load)
frames(1)
relay({ "rev" => 60, "wrev" => 60, "p" => 40, "r1141" => 30, "part" => "ad", "route" => "ad", "fetch" => "done" }, packed({ 1001 => 40, 1141 => 30 }))
frames(16)
$setups = []
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "62", :relay => true)
frames(1)
relay({ "rev" => 62, "wrev" => 62, "p" => 40, "r1142" => 2, "clear" => "ad", "part" => "mr", "route" => "mr", "done" => "ad", "fetch" => "done" }, packed({ 1001 => 40, 1142 => 2 }, [7096]))
frames(16)
check("plays the return's own half first, then the world's next route",
      [($setups.first || []).map { |entry| entry.code }, $game_variables[1141], $game_variables[1142], choices.instance_variable_get(:@prompts)], [[117, 122, 122, 201, 0], 0, 2, [:decision]])
choices.forget("test")

# Progress made before the world's story first came stays where the world's did not change it.
$calls.clear
new_story({ 1001 => 5, 1019 => 1 })
story.loaded(:load)
frames(1)
relay("fetch" => "failed", "fetch_error" => "offline")
frames(16)
$game_variables[1019] = 4
frames(1800)
check("a fetch that failed goes again", calls_of("mp_raid_story_fetch").size, 2)
relay({ "rev" => 70, "wrev" => 70, "p" => 6, "part" => "1", "fetch" => "done" }, packed({ 1001 => 6, 1019 => 1 }))
frames(16)
check("the player's progress before the world's story came stays", [story.mode, $game_variables[1001], $game_variables[1019]], [:world, 6, 4])

# Closing the world forgets its story.
MGQ_MpWorld.world = nil
frames(1)
check("closing the world forgets its story", [story.mode, story.world, story.endpoint], [nil, nil, nil])
