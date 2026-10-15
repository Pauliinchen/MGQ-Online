#----------------------------------------------------------------
#  world_story_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Checked that the steps before a boss battle stay out of the world's story
#                            - Checked that no write goes out while a novel scene runs
#                            - Checked that the Queen's Cup's tournament steps stay out of the world's story
#      Paulinchen  2026-10-14: Checked that one-way story variables never go below the world's values
#                            - Checked the Navy or the Pirates as each player's own choice
#      Paulinchen  2026-10-12: Checked the companions' affection coming and going with the stories
#      Paulinchen  2026-10-11: Asked no Amira choice of a player carried past Iliasburg
#                            - Dropped the check of the opening's random encounters
#                            - Checked that a take lets the opening turn random encounters on again
#                            - Checked that scene switches are each Raid World player's own
#                            - Checked that the world's story waits for a new game's opening setup
#      Paulinchen  2026-10-10: Checked that no write goes out between the story's events on another map
#                            - Stood in for MGQ_MpCoopEvents.telling_or_moved?
#                            - Checked a world story before a route the player started themselves
#                            - Checked that the player's own write keeps their story events waiting
#                            - Checked a Raid World started from a shared save
#                            - Checked that the player's story events name the teller they wait for
#                            - Checked a route lock refused before the world had a story
#                            - Checked a player behind whose own story becomes the world's
#      Paulinchen  2026-10-09: Took variable 152 as a story variable
#                            - Loaded story_state.rbx before coop_story.rbx and stood in for MGQ_MpStoryState
#                            - Followed a player in an earlier part as behind the world's story
#                            - Checked a write refused for another route bringing back the companions
#                            - Checked the choices and route one story asks, and a new game forgetting them
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# Covers world_story.rbx with story_state.rbx, coop_story.rbx, coop_choices.rbx and
# world_affection.rbx: a Raid World's story fetched, laid over the player's own values or kept
# apart, written back with its counters, refused writes and routes, the relay's push and the poll,
# the Great Decision's choice and the world's return to it, the choices each player keeps their
# own, and the companions' affection.

require_relative "support"

# Stands in for the mod's log: prints each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$calls = []
$reads = []
$state = ""
$notices = []
$raid = true

# Stands in for the mod's base script with its DLL.
module MGQ_Multiplayer
  # The DLL: each call is noted and starts, and the story's state is what $state holds.
  module Link
    # The requests of the story's exports, whose header says busy once one starts, as the DLL's does.
    KINDS = { "mp_raid_story_fetch" => "fetch", "mp_raid_story_post" => "post", "mp_raid_route_lock" => "lock" }

    # A function of the DLL, which notes its calls.
    Function = Struct.new(:name) do
      # Notes the call and marks a story request busy, as the DLL starts it.
      #
      # @param args [Array] The call's arguments.
      # @return [Integer] 1, started.
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, args]
        kind = KINDS[name]
        $state = "#{kind}=busy\n" + $state.gsub(/^#{kind}(_\w+)?=.*\n/, "") if kind
        1
      end
    end

    # Gives the DLL function of a name, which notes its calls.
    def self.function(name); Function.new(name); end

    # Reads the story's state or its headers, which leave the story's text out, as the DLL's do,
    # and notes the read in $reads.
    #
    # @param name [String] The export.
    # @param size [Integer] The buffer's size.
    # @return [String] The text, as bytes as the DLL hands it.
    def self.read(name, size)
      check_dll_call(name, ["", size])
      head = $state.split("\n\n", 2)[0].to_s
      text = { "mp_raid_story_state" => $state, "mp_raid_story_headers" => head.empty? ? "" : head + "\n\n" }[name].to_s
      $reads << [name, text.size]
      text.dup.force_encoding("ASCII-8BIT")
    end

    # Splits a DLL answer into its header fields and its payload.
    #
    # @param text [String] The answer.
    # @return [Hash] The fields by name, the payload under :payload.
    def self.parse(text)
      head, payload = text.force_encoding("UTF-8").split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| key, value = line.split("=", 2); state[key] = value if value }
      state
    end
  end
end

# Stands in for the overworld sync, whose world is always open.
module MGQ_MpOverworldSync
  # The state field the relay pushes the story's revision in.
  STORY_FIELD = "story_rev"

  # Stands in for the players present, of whom there are none.
  module Peers; Peer = Struct.new(:seat, :state); def self.present; []; end; end

  # Stands in for the player's own id, always me.
  module Me; def self.id; "me"; end; end

  # Answers that the player is in a world.
  def self.in_world?; true; end

  # Records a notice's text in $notices.
  def self.notice(text, icon = nil); $notices << text; end

  # Answers whether the map is free: on the map with no event running.
  def self.map_free?; SceneManager.scene.is_a?(Scene_Map) && !$game_map.interpreter.running?; end

  # Names a player for the log.
  def self.who(peer); peer == :me ? "the player" : peer.to_s; end

  # Records the handler of a relay field in $routes.
  def self.route(field, &block); ($routes ||= {})[field] = block; end

  # Records a handler run every frame in $ticks.
  def self.on_tick(&block); ($ticks ||= []) << block; end

  # Takes the state fields a script shares, keeping none.
  def self.state_fields(*); end
end

# Stands in for co-op: no party, and the Raid World's scope from $raid and $teller.
module MGQ_MpCoop
  # Stands in for the party, which has no members and no leader.
  module Party; def self.members; []; end; def self.leader; nil; end; end

  # Stands in for the scope: a Raid World while $raid, the teller watched from $teller, every player watched.
  module Scope; def self.raid?; $raid; end; def self.teller; $teller; end; def self.watches?(_peer); true; end; end

  # Takes a relay field's handler, keeping none.
  def self.route(*); end

  # Answers that there is no party leader.
  def self.party_leader; nil; end
end

# Stands in for the co-op events, whose telling follows $telling and $moved.
module MGQ_MpCoopEvents
  # Answers whether the player tells the story, from $telling.
  def self.telling?; $telling ? true : false; end

  # Answers whether the player tells the story or its telling just moved them onto another map, from $moved.
  def self.telling_or_moved?; telling? || ($moved ? true : false); end

  # Answers that no PvP battle runs.
  def self.pvp_running?; false; end

  # Answers that the map has no chests.
  def self.chest_keys; []; end

  # Answers that no self switch is a chest's.
  def self.chest_key?(_key); false; end
end

# Stands in for gathering: counts in $joined how often the player teleports to the story.
module MGQ_MpCoopGather; def self.join_story; ($joined ||= 0); $joined += 1; end; end

# Stands in for the rewards table, of which only one chest is in the checks.
module MGQ_MpCoopStoryRewards
  # The chests' self switches: map, event and letter.
  CHESTS = [[12, 3, "A"]]
  # The events where the sides get other rewards, none.
  GROUPS = []
  # The companions who join in events, none.
  ACTORS = []
  # The rewards only the events where the sides differ give, none.
  SIDED = { :skills => [], :actors => [] }
  # The rewards of the Final Chapter, none.
  ROUTE = { :skills => [], :actors => [] }
end

# Stands in for the actions, which offer nothing.
module MGQ_MpActions
  # Color of the line above the player's own head.
  LINE_COLOR = :line_color
  # An option of a wheel.
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  # A notice of the notification box.
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)

  # Takes an offer, keeping none.
  def self.offer(*); end
end

# Stands in for the world: the open world in world, a Raid World while $raid.
module MGQ_MpWorld
  # A world, known by its directory id alone.
  World = Struct.new(:directory_id)

  # The open world, nil outside one.
  class << self; attr_accessor :world; end

  # Answers whether the open world is a Raid World, from $raid.
  def self.raid?; $raid; end

  # The world screen's form, which the screen of choices draws with, stood in by its fields alone.
  class Form
    # A field of the form.
    Field = Struct.new(:key, :kind, :label, :row, :hint, :options) do
      # The outcomes of a switch, none for other fields.
      def choices; options[:choices] || []; end
    end

    # The form's title and fields.
    attr_reader :title, :fields

    # Makes a form with its title, fields and values.
    def initialize(title, fields, values); @title = title; @fields = fields; @values = values; end

    # Gives a field's value.
    def [](key); @values[key]; end
  end
end
MGQ_MpWorld.world = MGQ_MpWorld::World.new("w1")

# Stands in for the world screen's form window, which the screen of choices builds on.
class Window_MpWorldForm; def initialize(*); end; end
# Stands in for the game's menu scenes.
class Scene_MenuBase; end
# Stands in for the map scene.
class Scene_Map; end

# Stands in for the scene manager: the checks set the scene, and scenes called go into $scenes.
module SceneManager
  # The scene running.
  class << self; attr_accessor :scene; end

  # Records a scene called in $scenes.
  def self.call(scene); ($scenes ||= []) << scene; end
end

# Stands in for the frame counter, which stays at 0.
module Graphics; def self.frame_count; 0; end; end

# Stands in for the game's data classes.
module RPG
  # An event command.
  EventCommand = Struct.new(:code, :indent, :parameters)
  # A common event with its commands.
  CommonEvent = Struct.new(:list)
end

# Makes an event command.
#
# @param code [Integer] Its code.
# @param params [Array] Its parameters.
# @param indent [Integer] Its indent.
# @return [RPG::EventCommand] The command.
def c(code, params = [], indent = 0); RPG::EventCommand.new(code, indent, params); end

# The game's system data, with the names of the switches and variables.
System = Struct.new(:switches, :variables)
$data_system = System.new(Array.new(8000, ""), Array.new(4000, ""))
$data_actors = Array.new(600)
# An actor of the database, whose persona kind tells world_affection.rbx a companion's main persona.
AffectionActor = Struct.new(:id, :name, :persona_kind)
$data_actors[56] = AffectionActor.new(56, "Rami", :main)
$data_items = [nil]
$data_common_events = Array.new(400)

# Stands in for the game's switches, off unless set.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's variables, 0 unless set.
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's self switches, off unless set on.
class Game_SelfSwitches; def initialize; @data = {}; end; def [](key); @data[key] == true; end; def []=(key, value); @data[key] = value; end; end

# Stands in for the party, keeping the actors it includes.
class Game_Party
  # Whether a battle runs.
  attr_accessor :in_battle

  # Starts without actors.
  def initialize; @include_actors = []; end

  # Adds an actor.
  def add_stand_actor(id); @include_actors |= [id]; end

  # Removes an actor.
  def remove_actor(id); @include_actors.delete(id); end
end

# Stands in for an actor, who learns skills without keeping them.
class Game_Actor; def learn_skill(id); end; end

# Stands in for the event interpreter, which runs nothing and keeps the commands it was given.
class Game_Interpreter
  # The commands it was given and the one it is at.
  attr_reader :list, :index
  # Whether it runs an event.
  attr_accessor :busy

  # Takes a list of commands at its start, noted in $setups.
  def setup(list, event_id = 0); @list = list; @index = 0; ($setups ||= []) << list; end

  # Answers whether it runs an event.
  def running?; @busy ? true : false; end

  # Runs nothing.
  def execute_command; end

  # Reads a switch of the install's own from $game_system_switches.
  def ssw(key); $game_system_switches[key]; end
end

# Stands in for the map, map 3 at first, with its interpreter.
class Game_Map
  # The map's id, its interpreter and whether it needs a refresh.
  attr_accessor :map_id, :interpreter, :need_refresh

  # Starts on map 3.
  def initialize; @map_id = 3; @interpreter = Game_Interpreter.new; end

  # Moves to a map.
  def setup(map_id); @map_id = map_id; end

  # Updates nothing.
  def update(main = false); end
end

# Stands in for the player on the map, at 1,1.
class Game_Player
  # Where the player stands.
  attr_reader :x, :y

  # Stands at 1,1.
  def initialize; @x = 1; @y = 1; end

  # Answers that no transfer waits.
  def transfer?; false; end

  # Transfers nothing.
  def perform_transfer; end
end

# Stands in for the game's saving and loading, which the scripts hook.
module DataManager
  # Gives empty save contents.
  def self.make_save_contents; {}; end

  # Takes save contents, keeping none.
  def self.extract_save_contents(contents); end

  # Loads nothing.
  def self.load_game_without_rescue(index); end

  # Makes nothing.
  def self.create_game_objects; end

  # Sets nothing up.
  def self.setup_new_game; end
end

# The story switches that only stay on while a scene runs, the story variables that only go up and
# those the route return clears, as world_catchup_data.rbx lists them.
module MGQ_MpWorldCatchupData; SCENE_SWITCHES = [2029]; ONE_WAY_VARIABLES = [1032, 1052, 1144]; DEFEAT_RETURNS = { 1062 => { 4 => 3 } }; RETURN_CLEARED = [1144..1200]; end
load_script "story_state"
load_script "coop_story"
load_script "coop_choices"
load_script "world_story"
load_script "world_affection"
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
  MGQ_MpStoryState.pack(MGQ_MpStoryState.story_lists([s, v, selfs], true))
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
def lists_of(text); MGQ_MpStoryState.unpack(text.chomp("\0")); end

$game_map = Game_Map.new
$game_player = Game_Player.new
$game_party = Game_Party.new
$game_system_switches = {}
SceneManager.scene = Scene_Map.new
$telling = false

# Entering a world nobody wrote a story for: the player's story becomes the world's.
new_story({ 1001 => 12, 3001 => 50, 1029 => 6, 152 => 4 }, [300, 1005, 7016, 4], { [12, 3, "A"] => true, [5, 1, "B"] => true })
frames(1)
check("entering a Raid World fetches its story", calls_of("mp_raid_story_fetch"), [["w1\0"]])
relay("fetch" => "done")
frames(16)
post = calls_of("mp_raid_story_post").last
check("a world without a story takes the player's, built on revision 0", [post && post[0], post && post[1], post && post[2]], ["w1\0", 0, "p=12;r1141=0;r1142=0;r1143=0;clear=\0"])
lists = lists_of(post[3])
check("which leaves out the player's own switches, variables and chests",
      [lists["s"].split(","), lists["v"].split(",").map { |entry| entry.split(":")[0] }.sort, lists["ss"]], [["300"], ["1001", "152"], "5.1.B"])
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
relay({ "rev" => 4, "wrev" => 4, "p" => 13, "post" => "conflict", "post_code" => "rev" }, packed({ 1001 => 13, 152 => 9 }, [300, 301, 303]))
frames(16)
check("refused, it takes the world's story and keeps the player's own change the world lacks",
      [$game_switches[303], $game_variables[152], $game_switches[302], $game_variables[3001], $game_switches[1006]], [true, 9, true, 60, true])
frames(400)
check("which goes out again on the world's revision", calls_of("mp_raid_story_post").map { |args| [args[1], lists_of(args[3])["s"]] }.last, [4, "300,301,302,303"])
relay("rev" => 5, "wrev" => 5, "p" => 13, "post" => "accepted", "post_rev" => 5)
frames(16)

# A write behind the world's: the player's step goes.
$calls.clear
$game_variables[1001] = 14
frames(80)
relay({ "rev" => 6, "wrev" => 6, "p" => 15, "post" => "conflict", "post_code" => "behind" }, packed({ 1001 => 15, 152 => 9 }, [300, 301, 302, 303]))
frames(16)
check("a write behind the world's takes the world's progress", [$game_variables[1001], story.instance_variable_get(:@wrev)], [15, 6])
frames(400)
check("and writes nothing more", calls_of("mp_raid_story_post").size, 1)

# One-way variables: what sets one below the world's story, such as a game over's return to an
# earlier point, never takes the world's back, and a raise stays through a step refused as behind.
# Lays a world's and a player's story beside the one built on for keep_own.
#
# @param base [Hash] The variables built on.
# @param told [Hash] The world's.
# @param local [Hash] The player's.
# @return [Array<Array>] The stories: built on, world's, player's, and the one laid over.
def one_way_stories(base, told, local)
  stories = [base, told, local].map { |variables| v = []; variables.each { |id, value| v[id] = value }; [[], v, {}] }
  stories + [MGQ_MpStoryState.deep_copy(stories[1])]
end
built, told, local, applied = one_way_stories({ 1032 => 7 }, { 1032 => 7 }, { 1032 => 3 })
check("a one-way variable set below the world's value goes", [story.keep_own(applied, told, local, built, false).map(&:size), applied[1][1032]], [[0, 1], 7])
built, told, local, applied = one_way_stories({ 1032 => 5 }, { 1032 => 6 }, { 1032 => 7 })
check("its raise past the world's stays where the world changed it too", [story.keep_own(applied, told, local, built, false).map(&:size), applied[1][1032]], [[1, 0], 7])
built, told, local, applied = one_way_stories({ 1032 => 5, 1001 => 21 }, { 1032 => 5, 1001 => 24 }, { 1032 => 7, 1001 => 22 })
check("and through a step the relay refused as behind, without the step's progress",
      [story.keep_own(applied, told, local, built, true, true).map(&:size), applied[1][1032], applied[1][1001]], [[1, 1], 7, 24])
built, told, local, applied = one_way_stories({ 1032 => 5 }, { 1032 => 5 }, { 1032 => 7 })
check("but not through a step refused for another route", [story.keep_own(applied, told, local, built, true, false).map(&:size), applied[1][1032]], [[0, 1], 5])
built, told, local, applied = one_way_stories({ 1141 => 30, 1144 => 4 }, { 1141 => 30, 1144 => 4 }, { 1141 => 0, 1144 => 0 })
check("the player's own return to the Great Decision clears a route's one-way variables", [story.keep_own(applied, told, local, built, false).map(&:size), applied[1][1144]], [[2, 0], 0])
held = one_way_stories({}, {}, { 1032 => 3 })[2]
check("a write holds a lowered one-way variable at the world's value", [story.hold_one_way(held, one_way_stories({}, { 1032 => 7 }, {})[1]), held[1][1032]], [[[1032, 3]], 7])
$calls.clear
$game_variables[1032] = 7
story.instance_variable_get(:@base)[1][1032] = 7
$game_map.interpreter.busy = true
$game_variables[1032] = 3
frames(400)
check("a one-way variable an event sets back stays while the event runs", $game_variables[1032], 3)
$game_map.interpreter.busy = false
frames(400)
check("and goes back to the world's value after it, without a write", [$game_variables[1032], calls_of("mp_raid_story_post")], [7, []])

# The Queen's Cup: its tournament steps hold only in its waiting room and the Arena, never in the
# world's story, which an older build wrote them to.
# Reads the Queen's Cup's progress a write took.
#
# @param args [Array] The write's arguments.
# @return [Integer, nil] The progress.
def cup_of(args); MGQ_MpStoryState.decode_full(lists_of(args[3]))[1][1052]; end
$game_variables[1052] = 2
frames(400)
relay("rev" => 7, "wrev" => 7, "p" => 15, "post" => "accepted", "post_rev" => 7)
frames(16)
$calls.clear
$game_map.map_id = 484
$game_player.instance_variable_set(:@x, 45)
$game_variables[1052] = 3
frames(400)
check("signing up for the Queen's Cup in its waiting room writes nothing", calls_of("mp_raid_story_post"), [])
$game_switches[305] = true
frames(1000)
check("another change goes out with the sign-up still open", calls_of("mp_raid_story_post").map { |args| cup_of(args) }, [2])
cup_world = packed({ 1001 => 15, 152 => 9, 1052 => 3 }, [300, 301, 302, 303])
relay({ "rev" => 8, "wrev" => 8, "p" => 15, "post" => "conflict", "post_code" => "rev" }, cup_world)
frames(16)
check("a world's tournament step leaves a player in the tournament their own", $game_variables[1052], 3)
frames(400)
check("whose write goes out again with the sign-up open", calls_of("mp_raid_story_post").map { |args| cup_of(args) }, [2, 2])
relay("rev" => 8, "wrev" => 8, "p" => 15, "post" => "accepted", "post_rev" => 8)
frames(16)
$calls.clear
$game_map.map_id = 3
$game_player.instance_variable_set(:@x, 1)
$game_switches[306] = true
frames(1000)
relay({ "rev" => 8, "wrev" => 8, "p" => 15, "post" => "conflict", "post_code" => "rev" }, cup_world)
frames(16)
check("a player outside the tournament reads the world's tournament step as the open sign-up", $game_variables[1052], 2)
frames(400)
relay("rev" => 8, "wrev" => 8, "p" => 15, "post" => "accepted", "post_rev" => 8)
frames(16)
$calls.clear
$game_map.map_id = 483
$game_variables[1052] = 4
story.instance_variable_get(:@base)[1][1052] = 6
frames(400)
check("a later step of the world's leaves the player's tournament step alone in the Arena", [$game_variables[1052], calls_of("mp_raid_story_post")], [4, []])
$game_map.map_id = 3
frames(400)
check("and lays the world's over it once the player is outside", [$game_variables[1052], calls_of("mp_raid_story_post")], [6, []])
# The minute's polls that came due meanwhile.
relay("rev" => 8, "wrev" => 8, "p" => 15, "fetch" => "done")
frames(16)
relay("rev" => 8, "wrev" => 8, "p" => 15, "fetch" => "done")
frames(16)

# A lost story battle's defeat scene sets back what the boss's event set before the battle, as
# Gnosis's at Esta does: nothing of it goes out meanwhile.
# Stands in for the game's novel scene, which plays a defeat scene.
class Scene_Novel; end
$calls.clear
$game_variables[1062] = 4
SceneManager.scene = Scene_Novel.new
frames(1000)
check("a novel scene holds the boss event's changes back", calls_of("mp_raid_story_post"), [])
$game_variables[1062] = 3
frames(1000)
check("whose defeat scene sets one back", calls_of("mp_raid_story_post"), [])
SceneManager.scene = Scene_Map.new
frames(1000)
check("and once it ended, its change goes out", calls_of("mp_raid_story_post").map { |args| MGQ_MpStoryState.decode_full(lists_of(args[3]))[1][1062] }, [3])
relay("rev" => 8, "wrev" => 8, "p" => 15, "post" => "accepted", "post_rev" => 8)
frames(16)

# A step a story event sets before a boss battle, which its defeat sets back, as an older build
# wrote Gnosis's to the world: read and settled as the defeat's value.
told = one_way_stories({}, { 1062 => 4 }, {})[1]
check("a world's step before a boss battle reads as its defeat's value", [story.share_steps(told), told[1][1062]], [[[1062, 4]], 3])
$calls.clear
$game_variables[1062] = 4
frames(700)
check("and one the player's story holds once no event runs settles there, without a write", [$game_variables[1062], calls_of("mp_raid_story_post")], [3, []])
# The minute's poll that came due meanwhile.
relay("rev" => 8, "wrev" => 8, "p" => 15, "fetch" => "done")
frames(16)

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
relay({ "rev" => 9, "wrev" => 9, "p" => 15, "fetch" => "done", "end" => "40,7,8" }, packed({ 1001 => 15, 152 => 9 }, [300, 301, 302, 303, 304]))
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
$moved = true
frames(80)
check("and for the moment between the story's events on the new map, while its next event may go on with the telling", calls_of("mp_raid_story_post"), [])
$moved = false
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
$teller = MGQ_MpOverworldSync::Peers::Peer.new(2, { "telling" => "1", "name" => "Teller" })
frames(2)
$teller = nil
frames(2)
check("the player's story events wait once a telling they watched ended", story.awaits_teller?, true)
check("for the teller, whom it names", story.watched_teller, "Teller")
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
$calls.clear
$teller = MGQ_MpOverworldSync::Peers::Peer.new(2, { "telling" => "1", "name" => "Teller" })
frames(2)
$teller = nil
frames(2)
$game_variables[1001] = 19
frames(80)
relay("rev" => 17, "wrev" => 17, "p" => 19, "end" => "3,1,1", "post" => "accepted", "post_rev" => 17)
frames(16)
check("the player's own write accepted keeps their story events waiting for the teller's story", [calls_of("mp_raid_story_post").size, story.awaits_teller?], [1, true])
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "18", :relay => true)
frames(1)
relay({ "rev" => 18, "wrev" => 18, "p" => 19, "end" => "3,1,1", "fetch" => "done" }, packed({ 1001 => 19 }, [300, 301, 302, 303, 304, 305, 306, 307]))
frames(16)
check("which ends the wait", [story.awaits_teller?, $game_switches[307]], [false, true])

# A loaded save in the world's current part: the world's story is laid over it, the player's own
# values kept.
$calls.clear
new_story({ 1001 => 19, 3001 => 70, 1029 => 1, 152 => 2 }, [1010, 7016, 4, 310], { [12, 3, "A"] => true })
story.loaded(:load)
frames(1)
relay({ "rev" => 12, "wrev" => 12, "p" => 20, "part" => "2", "fetch" => "done" }, packed({ 1001 => 20, 152 => 5, 1029 => 9 }, [5, 7017, 311], { [12, 3, "A"] => false, [6, 1, "A"] => true }))
frames(16)
check("a loaded save takes the world's story", [story.mode, $game_variables[1001], $game_variables[152], $game_switches[311], $game_switches[310], $game_self_switches[[6, 1, "A"]]],
      [:world, 20, 5, true, false, true])
check("keeping the player's affection, companions, chests, choices and side",
      [$game_variables[3001], $game_switches[1010], $game_self_switches[[12, 3, "A"]], $game_variables[1029], $game_switches[7016], $game_switches[7017], $game_switches[4], $game_switches[5]],
      [70, true, true, 1, true, false, true, false])
check("and tells the player once", $notices.count("You play the world's story."), 1)

# A loaded save in an earlier part: the player is behind, writes nothing and fetches the world's story
# again once theirs reaches its part.
$calls.clear
$notices.clear
new_story({ 1001 => 10, 152 => 2 }, [310])
story.loaded(:load)
frames(1)
relay({ "rev" => 12, "wrev" => 12, "p" => 25, "part" => "2", "fetch" => "done" }, packed({ 1001 => 25, 152 => 5 }, [311]))
frames(16)
check("a player in an earlier part is behind, keeping their own story without a checkpoint", [story.mode, $game_variables[1001], $game_switches[310], $game_switches[311]], [:behind, 10, true, false])
check("and is told so", $notices, ["The world's story is further than yours."])
$game_variables[1001] = 11
frames(400)
check("and writes nothing", calls_of("mp_raid_story_post"), [])
$game_variables[1001] = 19
frames(31)
check("reaching the world's part fetches its story again", calls_of("mp_raid_story_fetch").size, 2)
relay({ "rev" => 12, "wrev" => 12, "p" => 25, "part" => "2", "fetch" => "done" }, packed({ 1001 => 25, 152 => 5 }, [311]))
frames(16)
check("which the player then plays", [story.mode, $game_variables[1001]], [:world, 25])

# A loaded save further than the world's story: the furthest story wins.
$calls.clear
new_story({ 1001 => 30, 152 => 2 }, [310])
story.loaded(:load)
frames(1)
relay({ "rev" => 14, "wrev" => 13, "p" => 25, "part" => "2", "fetch" => "done" }, packed({ 1001 => 25, 152 => 5 }, [311]))
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
# Notes the companions brought back in $brought instead of bringing them.
class << MGQ_MpStoryState; alias_method :bring_before_check, :bring; def bring(id); ($brought ||= []) << id; end; end
story.instance_variable_set(:@decision_roster, [5, 45])
$game_party.instance_variable_set(:@include_actors, [45])
relay({ "rev" => 21, "wrev" => 20, "p" => 39, "part" => "3", "route" => "mr", "lock" => "taken", "lock_code" => "route" }, packed({ 1001 => 39 }))
$notices.clear
frames(16)
check("one another player took first gives the player the world's story back", [$game_variables[1001], $game_variables[1141]], [39, 0])
check("and the companions their own decision took away", $brought, [5])
# Brings companions back as story_state.rbx does.
class << MGQ_MpStoryState; alias_method :bring, :bring_before_check; end
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

# Another route locked while the player's Great Decision offered every route: their write is refused.
$calls.clear
new_story({ 1001 => 39 }, [4])
story.loaded(:load)
frames(1)
relay({ "rev" => 25, "wrev" => 25, "p" => 39, "part" => "3", "route" => "mr", "fetch" => "done" }, packed({ 1001 => 39 }))
frames(16)
story.instance_variable_set(:@decision_roster, [5, 45])
$game_party.instance_variable_set(:@include_actors, [45])
$game_variables[1001] = 40
$game_variables[1141] = 1
frames(80)
check("a route the world locked already is not locked again, the story is written", [calls_of("mp_raid_route_lock"), calls_of("mp_raid_story_post").size], [[], 1])
# Notes the companions brought back in $brought instead of bringing them.
class << MGQ_MpStoryState; def bring(id); ($brought ||= []) << id; end; end
$brought = []
$notices.clear
relay({ "rev" => 25, "wrev" => 25, "p" => 39, "part" => "3", "route" => "mr", "post" => "conflict", "post_code" => "route" }, packed({ 1001 => 39 }))
frames(16)
check("the refused write gives the player the world's story and the companions their own decision took away",
      [$game_variables[1001], $game_variables[1141], $brought, $notices], [39, 0, [5], ["The world took the Monster Realm route first."]])
# Brings companions back as story_state.rbx does.
class << MGQ_MpStoryState; alias_method :bring, :bring_before_check; end

# The Great Decision's choice in the game's own event offers only the routes the world may still take.
labels = ["Side with the Dark Goddess", "Side with the Goddess Ilias", "Search for a third way"]
decision = [c(101, ["", 0, 0, 2]), c(102, [labels, 0]), c(402, [0, labels[0]]), c(122, [1002, 1002, 0, 0, 111], 1), c(0, [], 1),
            c(402, [1, labels[1]]), c(122, [1002, 1002, 0, 0, 112], 1), c(0, [], 1), c(402, [2, labels[2]]), c(119, ["decision"], 1), c(0, [], 1), c(404), c(0)]
$data_common_events[380] = RPG::CommonEvent.new(decision)
interpreter = Game_Interpreter.new
# Shows the choice of a fresh Great Decision to the hook, as the world tells its routes.
#
# @param interpreter [Game_Interpreter] The interpreter that runs the decision.
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
new_story({ 1001 => 39, 1050 => 9 }, [5])
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
check("and the side, after the Great Decision too", [MGQ_MpStoryState.personal_switch?(4), MGQ_MpStoryState.personal_switch?(5)], [true, true])
check("and a switch that only stays on while a scene runs, but no other story switch", [MGQ_MpStoryState.personal_switch?(2029), MGQ_MpStoryState.personal_switch?(2030)], [true, false])
check("as the story sync, whose story is the world's", MGQ_MpCoopChoices::Offers.peer_option(MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "f" })), nil)
contents = { :switches => $game_switches }
check("a save holds the story as it is", MGQ_MpCoopStory.save_contents(contents).equal?(contents) && contents[:switches].equal?($game_switches), true)
$raid = false
check("a Classic world keeps them the leader's while the player plays their own story", [choices.personal?(:s, 7016), MGQ_MpStoryState.personal_switch?(4), MGQ_MpStoryState.personal_switch?(2029)], [false, false, false])
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
check("the world's story passing Iliasville and Iliasburg asks the side", choices.instance_variable_get(:@prompts), [:side])
choices.forget("test")
story.followed({ "p" => 25, "r1141" => 0, "r1142" => 0, "r1143" => 0, "clear" => [] }, { "p" => 40, "r1141" => 3, "r1142" => 0, "r1143" => 0, "clear" => [] })
check("a story carrying the player past choices onto a route asks those choices, then the route",
      choices.instance_variable_get(:@prompts), [:succubus, :spider, :sphinx, :decision])
DataManager.setup_new_game
check("a new game forgets the choices and the route waiting to be confirmed", [choices.instance_variable_get(:@prompts), choices.instance_variable_get(:@raid_route)], [[], nil])

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
new_story({ 1001 => 40, 1141 => 30, 1050 => 9 })
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

# A world whose starting save cleared every route names every route as done from the first write
# on: a world story before a route the player started themselves since the world's last story is
# no return to the Great Decision.
$calls.clear
$notices.clear
$setups = []
new_story({ 1001 => 39 }, [4, 7096, 7097, 7039])
story.loaded(:load)
frames(1)
relay({ "rev" => 63, "wrev" => 63, "p" => 39, "part" => "3", "clear" => "ad,mr,chaos", "done" => "ad,mr,chaos", "fetch" => "done" }, packed({ 1001 => 39 }, [7096, 7097, 7039]))
frames(16)
$game_variables[1001] = 40
$game_variables[1141] = 2
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "64", :relay => true)
frames(1)
relay({ "rev" => 64, "wrev" => 64, "p" => 39, "part" => "3", "clear" => "ad,mr,chaos", "done" => "ad,mr,chaos", "fetch" => "done", "end" => "430,25,19" },
      packed({ 1001 => 39 }, [7096, 7097, 7039]))
frames(16)
check("a world story before a route the player started themselves is no return to the Great Decision, though the world finished every route once",
      [$notices, $setups, story.mode, story.endpoint], [[], [], :world, [430, 25, 19, 2]])
check("the story is taken, and the player's own step since the story they built on stays, as the world's story did not change it",
      [$game_variables[1001], $game_variables[1141]], [40, 2])
frames(80)
check("the route, finished before as every route was, is locked again first", [calls_of("mp_raid_route_lock"), calls_of("mp_raid_story_post")], [[["w1\0", "ad\0"]], []])
relay("rev" => 65, "wrev" => 64, "p" => 39, "part" => "3", "clear" => "ad,mr,chaos", "done" => "ad,mr,chaos", "route" => "ad", "lock" => "locked")
frames(20)
check("and goes out on the world's revision", calls_of("mp_raid_story_post").map { |args| [args[1], args[2]] }, [[64, "p=40;r1141=2;r1142=0;r1143=0;clear=ad,mr,chaos\0"]])
relay("rev" => 66, "wrev" => 66, "p" => 40, "r1141" => 2, "clear" => "ad,mr,chaos", "done" => "ad,mr,chaos", "part" => "ad", "route" => "ad", "post" => "accepted", "post_rev" => 66)
frames(16)
choices.forget("test")

# A player who chose a route at the Great Decision before the world's story came, as their save
# from an earlier session holds, is further than the world, though their key ranks below the
# decision once the world finished every route: their story becomes the world's, never behind.
$calls.clear
$notices.clear
new_story({ 1001 => 40, 1141 => 1 }, [4, 7096, 7097, 7039])
story.loaded(:load)
frames(1)
check("the player's story events wait for the world's story after a load", story.awaits_world?, true)
relay({ "rev" => 67, "wrev" => 67, "p" => 40, "part" => "3", "clear" => "ad,mr,chaos", "done" => "ad,mr,chaos", "fetch" => "done" }, packed({ 1001 => 40 }, [7096, 7097, 7039]))
frames(16)
check("a route chosen at the decision the world stands at is further, not behind", [story.mode, $game_variables[1141], story.awaits_world?], [:world, 1, false])
check("which opens every route in a world that finished them all", story.open_routes(story.world), [0, 1, 2])
frames(80)
check("and is locked for the world", calls_of("mp_raid_route_lock"), [["w1\0", "ad\0"]])
relay("rev" => 68, "wrev" => 67, "p" => 40, "part" => "3", "clear" => "ad,mr,chaos", "done" => "ad,mr,chaos", "route" => "ad", "lock" => "locked")
frames(20)
check("then written", calls_of("mp_raid_story_post").map { |args| args[2] }, ["p=40;r1141=1;r1142=0;r1143=0;clear=ad,mr,chaos\0"])
relay("rev" => 69, "wrev" => 69, "p" => 40, "r1141" => 1, "clear" => "ad,mr,chaos", "done" => "ad,mr,chaos", "part" => "ad", "route" => "ad", "post" => "accepted", "post_rev" => 69)
frames(16)
check("a route locked in such a world is the only one offered", story.open_routes(story.world), [0])
choices.forget("test")

# The world's story that does not come keeps the story events waiting AWAIT_WORLD_FRAMES at most.
new_story({ 1001 => 12 })
story.loaded(:load)
frames(1)
relay("fetch" => "failed", "fetch_error" => "offline")
frames(MGQ_MpWorldStory::AWAIT_WORLD_FRAMES - 2)
check("the story events wait while the world's story has not come", story.awaits_world?, true)
frames(2)
check("but no longer than AWAIT_WORLD_FRAMES", story.awaits_world?, false)
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

# A route another player locked while the world had no story yet: the player's lock is refused with
# revision 0, and the world's first story brings back what their own decision took away.
$calls.clear
new_story({ 1001 => 40, 1141 => 1 }, [4])
story.loaded(:load)
frames(1)
relay("rev" => 2, "fetch" => "done")
frames(80)
check("a player on a route in a world without a story locks it first", calls_of("mp_raid_route_lock"), [["w1\0", "ad\0"]])
# Notes the companions brought back in $brought instead of bringing them.
class << MGQ_MpStoryState; def bring(id); ($brought ||= []) << id; end; end
story.instance_variable_set(:@decision_roster, [5, 45])
$game_party.instance_variable_set(:@include_actors, [45])
$brought = []
$notices.clear
relay("rev" => 3, "route" => "mr", "lock" => "taken", "lock_code" => "route")
frames(16)
check("a lock taken with revision 0 waits for the world's first story", [story.mode, $brought, $notices], [nil, [], []])
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "4", :relay => true)
frames(1)
relay({ "rev" => 4, "wrev" => 4, "p" => 40, "r1142" => 1, "part" => "mr", "route" => "mr", "fetch" => "done" }, packed({ 1001 => 40, 1142 => 1 }))
frames(16)
check("which gives the player the world's route and the companions their own decision took away, and says so",
      [story.mode, $game_variables[1141], $game_variables[1142], $brought, $notices.include?("The world took the Monster Realm route first.")], [:world, 0, 1, [5], true])
# Brings companions back as story_state.rbx does.
class << MGQ_MpStoryState; alias_method :bring, :bring_before_check; end

# A player behind whose own story becomes the world's first leaves the story they stood on behind.
$calls.clear
new_story({ 1001 => 10 })
story.loaded(:load)
frames(1)
relay({ "rev" => 5, "wrev" => 5, "p" => 30, "part" => "2", "fetch" => "done" }, packed({ 1001 => 30 }))
frames(16)
stood_on = story.base
$game_variables[1001] = 30
frames(400)
relay({ "rev" => 6, "wrev" => 6, "p" => 30, "part" => "2", "fetch" => "done" })
frames(400)
check("a player behind whose story the world cannot read writes theirs, built on nothing they stood on behind",
      [stood_on.nil?, story.mode, story.base.nil? || !stood_on.equal?(story.base)], [false, :world, true])

# Closing the world forgets its story.
MGQ_MpWorld.world = nil
frames(1)
check("closing the world forgets its story", [story.mode, story.world, story.endpoint], [nil, nil, nil])

# A Raid World started from a shared save: its first game brings
# the save's story, in Part 2, which the relay's empty story never takes back to the beginning.
$calls.clear
$notices.clear
saved = { 1001 => 25, 1029 => 3, 152 => 6 }
new_story(saved, [320, 4], { [12, 3, "A"] => true })
MGQ_MpWorld.world = MGQ_MpWorld::World.new("w2")
frames(1)
check("the first game in a world from a shared save fetches its story", calls_of("mp_raid_story_fetch"), [["w2\0"]])
relay("world" => "w2", "fetch" => "done")
frames(16)
post = calls_of("mp_raid_story_post").last
check("the relay's empty story leaves the save's as it is and takes it as the world's first, on revision 0",
      [$game_variables[1001], $game_switches[320], story.mode, post && post[1], post && post[2]], [25, true, :world, 0, "p=25;r1141=0;r1142=0;r1143=0;clear=\0"])
check("with the save's shared values", [lists_of(post[3])["s"], lists_of(post[3])["v"].split(",").map { |entry| entry.split(":")[0] }.sort], ["320", ["1001", "152"]])
relay("world" => "w2", "rev" => 1, "wrev" => 1, "p" => 25, "part" => "2", "post" => "accepted", "post_rev" => 1)
frames(16)
check("the world's story starts from the save", [story.mode, story.world["p"], story.world["part"]], [:world, 25, "2"])

# The next player starts from the same save: they play the world's story at once, in its part.
$calls.clear
new_story(saved, [320, 4], { [12, 3, "A"] => true })
story.loaded(:load)
frames(1)
relay({ "world" => "w2", "rev" => 1, "wrev" => 1, "p" => 25, "part" => "2", "fetch" => "done" }, packed({ 1001 => 25, 152 => 6 }, [320]))
frames(16)
frames(400)
check("a player from the same save plays the world's story, behind nothing, and writes nothing",
      [story.mode, $game_variables[1001], calls_of("mp_raid_story_post"), $notices.include?("The world's story is further than yours.")], [:world, 25, [], false])

# Once the world moved on in the save's part, a player from the save takes its story.
$calls.clear
new_story(saved, [320, 4], { [12, 3, "A"] => true })
story.loaded(:load)
frames(1)
relay({ "world" => "w2", "rev" => 4, "wrev" => 4, "p" => 28, "part" => "2", "fetch" => "done" }, packed({ 1001 => 28, 152 => 7 }, [320, 321]))
frames(16)
check("a player from the save takes the world's further story in the save's part",
      [story.mode, $game_variables[1001], $game_variables[152], $game_switches[321], $game_variables[1029]], [:world, 28, 7, true, 3])

# A new game in that world starts before the save's part: the player is behind the world's story.
$calls.clear
new_story({ 1001 => 0 })
story.loaded(:new_game)
frames(1)
relay({ "world" => "w2", "rev" => 4, "wrev" => 4, "p" => 28, "part" => "2", "fetch" => "done" }, packed({ 1001 => 28, 152 => 7 }, [320, 321]))
frames(16)
frames(400)
check("a new game in a world started from a save is behind its story and writes nothing",
      [story.mode, $game_variables[1001], calls_of("mp_raid_story_post")], [:behind, 0, []])

# A new game in a world past the opening: the world's story waits while the opening's setup runs
# (world_opening.rbx), then is laid over the story the setup made.
# Stands in for the opening's setup: each take before laying over gets the next answer of $opening.
module MGQ_MpWorldOpening; def self.before_take(_world); $opening.shift; end; end
$opening = [:wait, :wait, :opened]
$calls.clear
new_story({ 1001 => 0 })
story.loaded(:new_game)
frames(1)
relay({ "world" => "w2", "rev" => 5, "wrev" => 5, "p" => 7, "part" => "1", "fetch" => "done" }, packed({ 1001 => 7 }, [320]))
frames(2)
check("the world's story waits while the opening's setup runs", [story.mode, $game_variables[1001]], [nil, 0])
$game_variables[1001] = 0
$game_variables[152] = 5
frames(16)
frames(400)
check("then it is laid over the story the setup made, whose values are no own change of the player's",
      [story.mode, $game_variables[1001], $game_variables[152], calls_of("mp_raid_story_post")], [:world, 7, 0, []])
$opening = []

# A scene switch a world's story written mid-scene left on is the player's own, and a take turns it
# off while no scene runs, but not while the player watches a teller's scene.
# Stands in for the co-op scene: something of a teller's scene waits to be put back while $scene_pending.
module MGQ_MpCoopScene; def self.pending?; $scene_pending; end; end
$scene_pending = true
$game_switches[2029] = true
story.refetch(:test)
frames(1)
relay({ "world" => "w2", "rev" => 6, "wrev" => 6, "p" => 7, "part" => "1", "fetch" => "done" }, packed({ 1001 => 7 }, [320, 2029]))
frames(16)
check("a scene switch the player sees in a teller's scene stays on as the world's story is laid over", [story.instance_variable_get(:@wrev), $game_switches[2029]], [6, true])
$scene_pending = false
story.refetch(:test)
frames(1)
relay({ "world" => "w2", "rev" => 7, "wrev" => 7, "p" => 7, "part" => "1", "fetch" => "done" }, packed({ 1001 => 7 }, [320, 2029]))
frames(16)
check("once no scene runs, the take turns it off, though the world's story has it on", [story.instance_variable_get(:@wrev), $game_switches[2029]], [7, false])

# The companions' affection comes with the world's story and goes out with the player's.
story.refetch(:test)
frames(1)
relay({ "world" => "w2", "rev" => 8, "wrev" => 8, "p" => 7, "part" => "1", "fetch" => "done" },
      MGQ_MpStoryState.pack(MGQ_MpStoryState.unpack(packed({ 1001 => 7 }, [320])).merge("a" => "56:50")))
frames(16)
check("the world's affection raises the player's as the world's story is laid over", [story.instance_variable_get(:@wrev), $game_variables[3056]], [8, 50])
$calls.clear
$game_variables[3056] = 60
story.request_post
frames(5)
check("a write the affection asked for carries the player's", calls_of("mp_raid_story_post").map { |args| lists_of(args[3])["a"] }, ["56:60"])
MGQ_MpWorld.world = nil
frames(1)

# The Navy or the Pirates: each Raid World player's own side, with its ship, its companions and the
# self switches of its line.
# Stands in for a vehicle, keeping where it was put.
class FakeVehicle; attr_reader :place; def set_location(*place); @place = place; end; end
$vehicles = { :ship => FakeVehicle.new }
class Game_Map; def vehicle(type); $vehicles[type]; end; end
class Game_Player; def vehicle; nil; end; end
choices.forget("navy")
new_story({ 1001 => 24, 1050 => 8, 56 => 0 }, [2148])
check("a save past the Navy's ending without its outcome is asked once, the side its own play took alone",
      [(choices.missed(24); choices.instance_variable_get(:@prompts)), choices.labels(:navy)], [[:navy], ["Cooperate with the Navy"]])
choices.apply(:navy, 0)
check("whose outcome finishes the Navy's line, gives two party places and puts the ship where the line leaves it",
      [$game_variables[1050], $game_variables[1051], $game_switches[7001], $game_variables[56], $vehicles[:ship].place], [9, 0, true, 2, [2, 334, 240]])
choices.forget("pirates")
new_story({ 1001 => 24, 56 => 4 }, [2149])
check("a player who took the Pirates is offered the Pirates alone", choices.labels(:navy), ["Aid the Fishy Pirates"])
choices.apply(:navy, 0)
check("and their outcome takes the treasure and Ashel's events for them, keeping their party places",
      [$game_variables[1051], $game_switches[2148], $game_self_switches[[709, 6, "A"]], $game_self_switches[[376, 53, "B"]], $game_variables[56], $vehicles[:ship].place],
      [5, false, true, true, 4, [2, 21, 211]])
choices.forget("both")
new_story({ 1001 => 24, 1050 => 9 })
check("a save that finished a line is asked nothing", [(choices.missed(24); choices.instance_variable_get(:@prompts)), choices.labels(:navy).size], [[], 2])
check("the lines' self switches are each Raid World player's own, other events' are not",
      [MGQ_MpStoryState.personal_self_switch?([709, 6, "A"]), MGQ_MpStoryState.personal_self_switch?([376, 53, "A"]), MGQ_MpStoryState.personal_self_switch?([376, 52, "A"])],
      [true, true, false])
check("so a story laid over the player's keeps theirs", MGQ_MpStoryState.mix([[], [], { [709, 6, "A"] => true }], [[], [], {}], [])[2].key?([709, 6, "A"]), false)
check("and the lines' values are each player's own", [1050, 1051].map { |id| MGQ_MpStoryState.personal_variable?(id) } + [MGQ_MpStoryState.personal_switch?(2148)], [true, true, true])
