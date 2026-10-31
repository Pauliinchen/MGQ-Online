#----------------------------------------------------------------
#  world_story_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Checked that the Great Decision offers the routes the relay grants
#                            - Checked that a run goes to the relay after its writes and that the track's runs reach the replay one at a time while the player is free
#      Paulinchen  2026-10-28: Left the player's telling to the DLL's telling machine
#                            - Let the DLL name whose ended telling the player's story events wait for
#                            - Checked that a Classic world has the DLL fetch the story mapping
#                            - Checked that the relay's values are written outside the frozen fights' write journal
#                            - Checked that the world's close sends the frame's writes first
#      Paulinchen  2026-10-24: Checked that an unlock the player holds stays on when the relay hands it off
#      Paulinchen  2026-10-23: Answered the rules the DLL owns through the bridge from the golden cases
#                            - Checked the world's story on the relay's tracks through the DLL's story topics, in place of the fetches, merges and writes
#                            - Checked that the return to the Great Decision takes the player out of their own scene first
#                            - Checked which event commands may move the world's story on
#      Paulinchen  2026-10-18: Checked the Sonya scene's step in the world's story
#                            - Checked that a story lists no switch or variable 0
#      Paulinchen  2026-10-17: Checked that the story waits while a lost raid boss battle's defeat runs
#                            - Checked the keys a frozen raid boss fight holds in the world's story
#                            - Checked that the write after a frozen raid boss fight ended ends it for the world
#      Paulinchen  2026-10-15: Checked that the Pocket Castle's tour is each Raid World player's own
#                            - Checked that the refusal of recruits is each Raid World player's own and goes once Lime joined
#                            - Checked that no route under way before the Great Decision is read, written or kept
#                            - Checked that the steps before a boss battle stay out of the world's story
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

# Covers world_story.rbx with story_keys.rbx, story_state.rbx, coop_story.rbx and coop_choices.rbx
# on a stand-in of the DLL's story topics (story_support.rb): entering a Raid World, its story
# mapping, the player's story the relay asks for, the relay's track written straight into the
# player's story once they are free (each player's own keys, the local steps and a higher value of a
# key the whole world keeps going only up left theirs), the route another player took first and the
# world's return to the Great Decision, the player's tellings, the teller they watch and their
# level, the Great Decision's choice and the world's return to it, and the shared companions.

require_relative "support"
require_relative "story_support"

# Stands in for the mod's log: prints each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$calls = []
$notices = []
$raid = true
$comps = ""

# Stands in for the DLL's shared companions: each call is noted and starts, and the state names the
# world's companions from $comps.
module MGQ_Multiplayer
  module Link
    # A function of the DLL, which notes its calls.
    Function = Struct.new(:name) do
      # Notes the call.
      #
      # @param args [Array] The call's arguments.
      # @return [Integer] 1, started.
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, args]
        1
      end
    end

    # Gives the DLL function of a name, which notes its calls.
    def self.function(name); Function.new(name); end

    # Reads the shared companions' state as the DLL writes it.
    #
    # @param name [String] The export.
    # @param size [Integer] The buffer's size.
    # @return [String] The text.
    def self.read(name, size)
      check_dll_call(name, ["", size])
      "world=w1\nrev=1\ncomps=#{$comps}\nfetch=done\n\n".dup.force_encoding("ASCII-8BIT")
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

  # Stands in for the players present, of whom there are none, and those known, from $peers.
  module Peers; Peer = Struct.new(:seat, :state); def self.present; []; end; def self.all; $peers || []; end; end

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

# Stands in for the co-op events, which tell nothing here.
module MGQ_MpCoopEvents
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
# Stands in for the title screen, which starts with nothing to show.
class Scene_Title; def start; end; end
# Stands in for the game's system data, which a save keeps.
class Game_System; end

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

# Stands in for the game's actors, who level up as the checks set them.
class Game_Actor
  # The level and the highest the game lets the actor reach.
  attr_accessor :base_level, :cap

  # Makes an actor at a level, without a cap.
  def initialize(level = 1); @base_level = level; @cap = 9999; end

  # Answers the highest level the game lets the actor reach.
  def max_level(_kind); @cap; end
end
# Stands in for a map event, whose pages' lists name the page a write came from.
class Game_Event; def initialize(lists); @lists = lists; end; def mgq_mp_pages; @lists.map { |list| Struct.new(:list).new(list) }; end; def start; end; end
# Stands in for the novel scene of a lost battle's defeat.
class Scene_Novel; end
# Lets the map stand-in hold its events.
class Game_Map; attr_accessor :events; end

fake = open_rules_bridge
answer_story(fake)
load_script "story_state"
load_script "coop_story"
load_script "coop_choices"
load_script "world_story"
story = MGQ_MpWorldStory
choices = MGQ_MpCoopChoices
keys = MGQ_MpStoryKeys
# The world's story mapping: what the Raid personal lists of earlier builds shared, the Queen's
# Cup's steps local where it plays, and a companion's affection the whole world keeps going only up.
mapping = listed_raid_table_hash({ "switches" => 8000, "variables" => 4000, "companions" => 600, "chest_flags" => [7102] }, [2029])
variables = mapping["variables"].unpack("C*")
variables[3005] = 35
variables[1144] = 3
switches = mapping["switches"].unpack("C*")
switches[445] = 1
mapping = mapping.merge("rev" => 1, "switches" => switches.pack("C*"), "variables" => variables.pack("C*"), "local_steps" => [[1052, [3, 4, 5], 2, [[484, 30]]]])

# Makes a new game's story with some values, the party of one actor at a level.
#
# @param variables [Hash] Variables by id.
# @param switches [Array<Integer>] Switches on.
# @param level [Integer] The actor's level.
def new_story(variables = {}, switches = [], level = 10)
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_self_switches = Game_SelfSwitches.new
  variables.each { |id, value| $game_variables[id] = value }
  switches.each { |id| $game_switches[id] = true }
  $game_party = Game_Party.new
  $game_party.add_stand_actor(1)
  $game_actors = [nil, Game_Actor.new(level)]
end

# Runs frames as the game does: the map's update, then the scripts' writes and the bridge's batch
# and drain at the frame's Graphics.update.
#
# @param count [Integer] How many.
def frames(count)
  count.times do
    MGQ_MpWorldStory.tick
    MGQ_MpStoryKeys.flush
    MGQ_Multiplayer::Bridge.frame
  end
end

# Hands the scripts the DLL's status with the next frame's drain.
#
# @param fake [FakeBridge] The bridge.
# @param fields [Hash] The fields that differ, see story_status.
def tell_status(fake, fields = {})
  fake.post("story.status", story_status(fields))
end

$game_map = Game_Map.new
$game_player = Game_Player.new
SceneManager.scene = Scene_Map.new
new_story({ 1001 => 5, 3001 => 40 }, [4, 7096], 12)

# Entering a Raid World: the relay places the player, the mapping comes, the player's story events wait.
frames(1)
check("entering the world asks the DLL to place the player, with their level", staged("story.enter"),
      [{ "world" => "w1", "fresh" => false, "level" => { "best" => 12, "cap" => 9999 } }])
check("whose story events wait for the world's story", story.awaits_world?, true)
$classes = mapping
tell_status(fake, "synced" => false, "need_seed" => true, "world" => nil)
frames(2)
check("the mapping's table is read once the DLL tells its revision", keys.raid_table.rev, 1)
seed = staged("story.seed").first
check("the player's story the relay asks for holds what the mapping keeps or a chest's, never each player's own",
      [seed["v1001"], seed["s7096"], seed["s4"], seed["v3001"], seed.size], ["n5", "1", nil, nil, 2])
frames(1)
check("once", staged("story.seed").size, 1)

# The relay's track is written straight into the player's story.
$game_variables[1062] = 3
$game_switches[600] = true
frames(1)
$story_staged.clear
$takes << track_take({ "v1001" => "n9", "s500" => "1", "ss12.3.A" => "1", "v1062" => "n4" }, "held" => ["v1062"], "chests" => { "s7102" => "1" })
tell_status(fake, "pending" => true)
frames(2)
check("a whole track is written over every key the mapping keeps, those it never wrote off",
      [$game_variables[1001], $game_switches[500], $game_self_switches[[12, 3, "A"]], $game_switches[7096], $game_switches[600]], [9, true, true, false, false])
check("each player's own keys and those the player's own unanswered requests wrote stay, the chest flags are the player's",
      [$game_switches[4], $game_variables[3001], $game_variables[1062], $game_switches[7102]], [true, 40, 3, true])
check("the player plays the world's story now, told so, and their story events no longer wait",
      [story.mode, $notices, story.awaits_world?], [:world, ["You play the world's story."], false])
check("none of it goes to the relay as the player's", staged("story.writes"), [])

# The player's own writes go to the relay; what the relay hands waits while an event of theirs runs.
$game_map.interpreter.busy = true
$game_variables[1001] = 10
$takes << keys_take([["v1001", "n11"], ["s501", "1"]])
tell_status(fake, "pending" => true)
frames(2)
check("the player's own write goes to the relay", staged("story.writes").last, [["v1001", "n10", "game"]])
check("what the relay hands waits while an event of the player's runs", [$game_variables[1001], $game_switches[501], $takes.size], [10, false, 1])
$game_map.interpreter.busy = false
frames(1)
check("and is written once they are free", [$game_variables[1001], $game_switches[501]], [11, true])

# The Queen's Cup's tournament steps stay the player's where it plays; the companions' affection
# the whole world keeps never goes below the player's own, which goes to the relay again.
$game_map.map_id = 484
$game_player.instance_variable_set(:@x, 31)
$game_variables[1052] = 3
$game_variables[3005] = 40
$story_staged.clear
frames(1)
$story_staged.clear
$takes << keys_take([["v1052", "n2"], ["v3005", "n30"]], 3)
tell_status(fake, "pending" => true)
frames(2)
check("a Queen's Cup step stays the player's in its waiting room", $game_variables[1052], 3)
check("the affection the world keeps stays at the player's higher value, which goes to the relay again", [$game_variables[3005], staged("story.writes")], [40, [[["v3005", "n40", "game"]]]])
$game_map.map_id = 3
$takes << keys_take([["v1052", "n2"]], 4)
tell_status(fake, "pending" => true)
frames(2)
check("elsewhere the world's value of it comes", $game_variables[1052], 2)

# The second accessory slot (445), which the game turns on for good, stays on when the relay hands
# it off, as in a world an earlier build kept it each player's own, and goes to the relay.
$game_switches[445] = true
frames(1)
$story_staged.clear
$takes << keys_take([["s445", "0"]], 5)
tell_status(fake, "pending" => true)
frames(2)
check("an unlock the player holds that the relay hands off stays on and goes to the relay", [$game_switches[445], staged("story.writes")], [true, [[["s445", "1", "game"]]]])

# The teller the player watches: the relay hears of them, and the player's story events wait until
# the track's revision the telling ended at was written into their story.
teller = MGQ_MpOverworldSync::Peers::Peer.new(2, { "name" => "Friend" })
$peers = [teller]
$teller = teller
frames(1)
$teller = nil
frames(1)
check("the relay hears whose telling the player watches, and that they watch none once it stopped", staged("story.watch"), [2, nil])
tell_status(fake, "await" => 2)
frames(2)
check("the player's story events wait while the DLL holds the world's story of a telling that ended, which names the teller",
      [story.awaits_teller?, story.watched_teller], [true, "Friend"])
tell_status(fake, "await" => nil)
frames(2)
check("and no longer once it was written into theirs", story.awaits_teller?, false)
tell_status(fake, "await" => 2, "told" => { 2 => 9 })
frames(story::AWAIT_TELLER_FRAMES)
waited = story.awaits_teller?
frames(1)
check("a take that stays held keeps them waiting AWAIT_TELLER_FRAMES at most", [waited, story.awaits_teller?], [true, false])
tell_status(fake, "await" => 2, "told" => { 2 => 10 })
frames(1)
check("while a later end of a telling waits anew", story.awaits_teller?, true)
tell_status(fake, "await" => nil)
frames(1)
$story_staged.clear
check("the player's state tells their track", story.state_fields, { "trk" => "world" })

# The player's level, which the relay's level gates read.
$game_actors[1].base_level = 14
frames(story::CHECK_FRAMES)
check("the relay hears the player's level once it changed", staged("story.level"), [{ "best" => 14, "cap" => 9999 }])

# A route the world took first: the relay keeps the world's value of the player's route variable.
$notices.clear
$joined = 0
$game_variables[1001] = 40
$game_variables[1141] = 1
story.instance_variable_set(:@decision_roster, [1, 26])
fake.post("story.refused", [["v1141", "route", "n0"]])
$takes << keys_take([["v1141", "n0"], ["v1142", "n1"]], 7)
tell_status(fake, "pending" => true, "world" => { "rev" => 7, "part" => "mr", "route" => "mr", "done" => [], "open" => ["mr"], "checkpoints" => ["1", "2", "3"] })
$brought = []
# Brings companions back as story_state.rbx does, noted in $brought.
def MGQ_MpStoryState.bring(id); $brought << id; end
frames(2)
check("the world's route comes, the companions the player's own decision took away come back, and the player is told and goes to the story",
      [$game_variables[1141], $game_variables[1142], $brought, $notices, $joined], [0, 1, [26], ["The world took the Monster Realm route first."], 1])

# The world going back to the Great Decision from the route the player is on.
$notices.clear
$setups = []
world_back = { "rev" => 8, "part" => "3", "route" => "none", "done" => ["mr"], "open" => ["ad"], "checkpoints" => ["1", "2", "3", "mr"] }
tell_status(fake, "world" => world_back)
frames(1)
$takes << keys_take([["v1142", "n0"], ["v1001", "n39"], ["s7097", "1"]], 8)
tell_status(fake, "pending" => true, "world" => world_back)
# Stands in for the co-op scene: nothing of a teller's scene waits to be put back, and each time the
# player is taken out of their own scene, whether wholly and how many lists were set up by then, is
# noted in $left.
module MGQ_MpCoopScene
  def self.pending?; false; end
  # Takes a story write for a teller's scene, which no scene of this test shows.
  def self.story_value(*); end
  module Own; def self.leave(_reason, whole = false); ($left ||= []) << [whole, $setups.size]; end; end
end
frames(3)
check("the world's return to the Great Decision reaches the player, and says so", [$game_variables[1001], $game_variables[1142], $notices],
      [39, 0, ["The world's story went back to the Great Decision."]])
check("whose own half plays once the player is free: the Final Chapter's reset, where a game over returns them and the transfer",
      ($setups.last || []).map { |entry| entry.code }, [117, 122, 122, 201, 0])
check("after taking the player wholly out of a scene of their own, such as their route's ending walked in a temporary party",
      $left, [[true, $setups.size - 1]])
check("the Great Decision then offers the routes the relay grants", story.decision_routes, [0])

# Event commands may move the world's story on when they set a value that tells how far it is or a
# variable the mapping keeps going only up, themselves or in a common event they call.
$data_common_events[390] = RPG::CommonEvent.new([c(122, [1144, 1144, 0, 0, 2])])
minigame = [c(122, [845, 845, 0, 0, 1]), c(201, [0, 1886, 55, 11, 2, 0]), c(121, [96, 96, 0])]
scene = [c(201, [0, 430, 5, 5, 2, 0]), c(117, [390])]
check("a scene that moves its teller first and moves the story on in a common event after may move it on, a minigame setting values of its own does not",
      [story.progress_ahead?(scene, 0), story.progress_ahead?(minigame, 0)], [true, false])
check("nor does a scene whose progress lies behind the place read from", story.progress_ahead?([c(122, [1001, 1001, 0, 0, 40]), c(201, [0, 430, 5, 5, 2, 0])], 1), false)
$data_common_events[390] = nil

# The shared companions, which the world's state names.
$comps = "77,80"
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "3", :relay => true)
frames(story::STATE_FRAMES + 2)
check("the relay's push fetches the shared companions, which the world's story names", story.world["comps"], [77, 80])
$game_switches[7097] = false

# The Great Decision's choice in the game's own event offers only the routes the relay grants.
labels = ["Side with the Dark Goddess", "Side with the Goddess Ilias", "Search for a third way"]
decision = [c(101, ["", 0, 0, 2]), c(102, [labels, 0]), c(402, [0, labels[0]]), c(122, [1002, 1002, 0, 0, 111], 1), c(0, [], 1),
            c(402, [1, labels[1]]), c(122, [1002, 1002, 0, 0, 112], 1), c(0, [], 1), c(402, [2, labels[2]]), c(119, ["decision"], 1), c(0, [], 1), c(404), c(0)]
$data_common_events[380] = RPG::CommonEvent.new(decision)
interpreter = Game_Interpreter.new
# Shows the choice of a fresh Great Decision to the hook, as the world tells its routes.
#
# @param interpreter [Game_Interpreter] The interpreter that runs the decision.
# @param world [Hash] The routes the relay grants, under "open".
# @return [Array<RPG::EventCommand>] The interpreter's commands afterwards.
def offered(interpreter, world)
  interpreter.setup($data_common_events[380].list)
  interpreter.instance_variable_set(:@index, 1)
  MGQ_MpWorldStory.status = story_status("world" => { "rev" => 1, "part" => "3", "route" => "none", "done" => [], "checkpoints" => [] }.merge(world))
  MGQ_MpWorldStory.before_command(interpreter)
  interpreter.list
end
list = offered(interpreter, "open" => ["mr"])
check("a route granted alone is the only side offered",
      [list[1].parameters[0], list.select { |entry| entry.code == 402 }.map { |entry| entry.parameters }, list.count { |entry| entry.code == 122 }],
      [[labels[1]], [[0, labels[1]]], 1])
check("its branch plays as before", list.find { |entry| entry.code == 122 }.parameters[4], 112)
check("the game's own commands stay as they are", $data_common_events[380].list.size, decision.size)
list = offered(interpreter, "open" => ["chaos"])
check("the third way alone", [list[1].parameters[0], list.select { |entry| entry.code == 402 }.map { |entry| entry.parameters[0] }], [[labels[2]], [0]])
list = offered(interpreter, "open" => ["ad", "mr"])
check("a route the relay does not grant is left out", list[1].parameters[0], labels[0, 2])
check("every route granted offers the game's own choice", offered(interpreter, "open" => ["ad", "mr", "chaos"]).equal?($data_common_events[380].list), true)
$raid = false
list = offered(interpreter, "open" => ["mr"])
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


# A lost battle's defeat scene and a frozen fight's undo: nothing is written meanwhile.
# Stands in for the freeze engine: a lost raid boss battle's defeat runs while $holding, and the
# values written while its journal looks away are noted in $unjournaled.
module MGQ_MpRaidFreeze
  def self.holding_writes?; $holding ? true : false; end
  def self.unjournaled; $looking_away = true; yield; ensure; $looking_away = false; end
end
$unjournaled = []
$holding = true
$takes << keys_take([["v1001", "n41"]], 9)
tell_status(fake, "pending" => true)
frames(2)
check("nothing the relay hands is written while a lost raid boss battle's defeat runs", $game_variables[1001], 39)
$holding = false
MGQ_MpHooks.before(Game_Variables, :[]=, "world_story_test") { |id, _value| $unjournaled << id if $looking_away }
frames(1)
check("but once it ended", $game_variables[1001], 41)
check("outside the frozen fights' write journal", $unjournaled, [1001])

# A loaded save and a new game: the relay places the player again, a new game anew by its story.
$story_staged.clear
story.loaded(:load)
story.loaded(:new_game)
frames(1)
check("a loaded save or a new game asks the relay to place the player again, a new game anew",
      staged("story.enter").map { |entry| entry["fresh"] }, [false, true])
check("and their story events wait for the world's story again", story.awaits_world?, true)

# A run of the player's own goes to the relay after the writes recorded before it, and the runs of
# their track reach the replay one at a time, only while the player stands free.
# Stands in for the replay: the runs handed to it wait in $replay_waiting, and $free tells whether
# the player stands free.
module MGQ_MpStoryReplay
  def self.waiting; $replay_waiting; end
  def self.free?; $free; end
  def self.receive(entry); $replay_waiting << entry; end
end
$replay_waiting = []
$free = false
$walks = []
fake.answer("story.hand_entry") { |entry| $story_staged << ["story.hand_entry", entry]; nil }
fake.answer("story.stream") { |request| $walks << request; request["free"] && request["waiting"].empty? ? { "id" => "gift" } : nil }
$story_staged.clear
$game_variables[1001] = 43
check("a run goes in a Raid World", story.hand_entry("id" => "mine"), true)
frames(1)
check("after the writes recorded before it", $story_staged.map { |topic, _| topic } & ["story.writes", "story.hand_entry"], ["story.writes", "story.hand_entry"])
check("nothing reaches the replay while the player is not free", [$replay_waiting, $walks.last["free"]], [[], false])
$free = true
frames(2)
check("once free, the next run reaches the replay, and none more while it waits there", [$replay_waiting, $walks.last["waiting"]], [[{ "id" => "gift" }], ["gift"]])

# Closing the world: the frame's writes go to the DLL ahead of the close, as a world left for the
# title screen closes its room before the frame ends.
$story_staged.clear
$game_variables[1001] = 42
$raid = false
frames(1)
check("closing the world sends the frame's writes first, then tells the DLL and forgets the mapping",
      [$story_staged.map { |topic, _| topic }, staged("story.writes").last, keys.raid_table, keys.recording],
      [["story.writes", "story.close"], [["v1001", "n42", "game"]], nil, nil])

# A Classic world has the DLL fetch the story mapping, for the rewards a party member catches up
# with, and no longer once it closed.
fetches = []
fake.answer("story.mapping") { |world| fetches << world; nil }
MGQ_MpWorld.world = MGQ_MpWorld::World.new("c1")
frames(1)
MGQ_MpWorld.world = nil
frames(1)
check("a Classic world has the DLL fetch the story mapping, and no longer once it closed", fetches, ["c1", nil])
