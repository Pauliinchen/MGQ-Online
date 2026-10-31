#----------------------------------------------------------------
#  catchup_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Told the place where the world's log starts with the world's summary
#      Paulinchen  2026-10-28: Read the generated tables from fixtures/catchup/generated in place of the deleted world_catchup_data.rbx
#                            - Answered the DLL's catch-up topics from the catch-up engine over the tests' tables, and recorded its answers
#                            - Created
#
#----------------------------------------------------------------

# The game a Raid World's catch-up runs in, for the script tests and the recorder of the catch-up's
# golden cases (fixtures/catchup/make_engine.rb): stand-ins of the game's objects, the players, the
# world and the message window, the real story_state.rbx, coop_story.rbx, coop_choices.rbx,
# world_story.rbx and world_catchup.rbx on a stand-in of the DLL's story topics (story_support.rb)
# and of its catch-up (fixtures/catchup/engine.rb, over the generated tables of
# fixtures/catchup/generated_tables.rb, which the tests replace with rows of their own), and helpers that start a game, hand the relay's
# tracks over and run frames.

require_relative "support"
require_relative "story_support"
require_relative "../../fixtures/catchup/relay_rows"
require_relative "../../fixtures/catchup/engine"
require_relative "../../fixtures/catchup/generated_tables"

$logs = []
# Stands in for the mod's log: records each line in $logs and prints it.
module MGQ_Multiplayer; module Log; def self.write(m); $logs << m; puts "  log: #{m}"; end; end; end
$calls = []
$state = ""
$notices = []
$messages = []
$raid = true
$sharing = :off
$telling = false

# Stands in for Multiplayer.rb around the DLL link.
module MGQ_Multiplayer
  # Stands in for the DLL link of the shared companions: each call is noted and starts, and the
  # state is what $state holds.
  module Link
    # The requests of the exports, whose header says busy once one starts, as the DLL's does.
    KINDS = { "mp_raid_story_fetch" => "fetch", "mp_raid_companions_add" => "companions" }

    # A function of the DLL, which notes its calls.
    Function = Struct.new(:name) do
      # Notes the call, marks its request busy in $state, and answers that it started.
      #
      # @param args [Array] The arguments of the call.
      # @return [Integer] 1.
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, args]
        kind = KINDS[name]
        $state = "#{kind}=busy\n" + $state.gsub(/^#{kind}(_\w+)?=.*\n/, "") if kind
        1
      end
    end
    # Answers a function of the DLL that notes its calls.
    def self.function(name); Function.new(name); end
    # Reads the shared companions' state as the DLL hands it over.
    #
    # @param name [String] The export.
    # @param size [Integer] The buffer's size.
    # @return [String] The text, in binary.
    def self.read(name, size)
      check_dll_call(name, ["", size])
      head = $state.split("\n\n", 2)[0].to_s
      (head.empty? ? "" : head + "\n\n").dup.force_encoding("ASCII-8BIT")
    end
    # Reads a state the DLL describes, as Link.parse does.
    #
    # @param text [String] The description.
    # @return [Hash] The values by key, the payload under :payload.
    def self.parse(text)
      head, payload = text.force_encoding("UTF-8").split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| key, value = line.split("=", 2); state[key] = value if value }
      state
    end
  end
end
# Stands in for the overworld sync: the player is in a world with nobody else.
module MGQ_MpOverworldSync
  # The state field that carries the story's revision.
  STORY_FIELD = "story_rev"
  # Stands in for the other players: nobody is present.
  module Peers; Peer = Struct.new(:seat, :state); def self.present; []; end; end
  # Stands in for the player: their id is always "me".
  module Me; def self.id; "me"; end; end
  # Answers that the player is in a world.
  def self.in_world?; true; end
  # Records a notice's text in $notices.
  def self.notice(text, icon = nil); $notices << text; end
  # Answers whether the map shows and runs no event.
  def self.map_free?; SceneManager.scene.is_a?(Scene_Map) && !$game_map.interpreter.running?; end
  # Names a player for the log.
  def self.who(peer); peer == :me ? "the player" : peer.to_s; end
  # Records a message route in $routes.
  def self.route(field, &block); ($routes ||= {})[field] = block; end
  # Records a tick in $ticks.
  def self.on_tick(&block); ($ticks ||= []) << block; end
  # Takes state fields and sends none.
  def self.state_fields(*); end
end
# Stands in for the notification box: records each message's text in $messages.
module MGQ_MpNotices; def self.message(key, text, frames = 180); $messages << text; end; end
# Stands in for co-op: no party, the world's kind from $raid, no teller.
module MGQ_MpCoop
  # Stands in for the party: it has no members and no leader.
  module Party; def self.members; []; end; def self.leader; nil; end; end
  # Stands in for the scope: a Raid World while $raid holds, nobody telling, everyone watched.
  module Scope; def self.raid?; $raid; end; def self.teller; nil; end; def self.watches?(_peer); true; end; end
  # Takes a message route.
  def self.route(*); end
  # Answers that there is no party leader.
  def self.party_leader; nil; end
end
# Stands in for the shared events.
module MGQ_MpCoopEvents
  # Answers whether the player tells a story event, as $telling says.
  def self.telling?; $telling ? true : false; end
  # Answers that no PvP battle runs.
  def self.pvp_running?; false; end
  # Answers that no event is a chest.
  def self.chest_keys; []; end
  # Answers that no key is a chest's.
  def self.chest_key?(_key); false; end
  # Runs the block.
  def self.granting; yield; end
  # Answers that no teller's scene plays.
  def self.mirroring?; false; end
end
# Stands in for the message window: keeps the text, the choices and what a choice calls.
class Game_Message
  attr_accessor :texts, :choices, :choice_cancel_type, :choice_proc
  # Starts empty.
  def initialize; @texts = []; @choices = []; end
  # Keeps a line.
  def add(text); @texts << text; end
  # Answers whether a message shows.
  def busy?; !@texts.empty?; end
end
$game_message = Game_Message.new
# Stands in for the gathering: joining the story does nothing.
module MGQ_MpCoopGather; def self.join_story; end; end
# Stands in for the story's reward tables, two chests and one chest flag in all.
module MGQ_MpCoopStoryRewards
  # The self switches of the chests.
  CHESTS = [[12, 3, "A"], [30, 4, "A"]]
  # The switches only chests turn on.
  CHEST_FLAGS = [7102]
  # The story's event groups, none.
  GROUPS = []
  # The companions who join in events, none.
  ACTORS = []
  # The skills and companions only the events where the sides differ give, none.
  SIDED = { :skills => [], :actors => [] }
  # The skills and companions of SIDED the Final Chapter gives too, none.
  ROUTE = { :skills => [], :actors => [] }
end
# Stands in for the player's actions.
module MGQ_MpActions
  # The color of the player's own line.
  LINE_COLOR = :line_color
  # Stands in for an option of a wheel.
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  # Stands in for a notice of the notification box.
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)
  # Takes an offer and shows nothing.
  def self.offer(*); end
end
# Stands in for the world screen: world w1, a Raid World while $raid holds.
module MGQ_MpWorld
  # Stands in for a world, with its id only.
  World = Struct.new(:directory_id)
  class << self; attr_accessor :world; end
  # Answers whether the world is a Raid World, as $raid says.
  def self.raid?; $raid; end
  # Answers the companion sharing $sharing names, off outside a Raid World.
  def self.companion_sharing; $raid ? $sharing : :off; end
  # The world screen's form, which the screen of choices draws with, stood in by its fields alone.
  class Form
    # Stands in for a field of the form.
    Field = Struct.new(:key, :kind, :label, :row, :hint, :options) do
      # Answers the field's choices, none when it names none.
      def choices; options[:choices] || []; end
    end
    attr_reader :title, :fields
    # Takes the form's title, fields and values.
    def initialize(title, fields, values); @title = title; @fields = fields; @values = values; end
    # Answers a field's value.
    def [](key); @values[key]; end
  end
end
MGQ_MpWorld.world = MGQ_MpWorld::World.new("w1")
# Stands in for the window that draws a form.
class Window_MpWorldForm; def initialize(*); end; end
# Stands in for the base of menu screens.
class Scene_MenuBase; end
# Stands in for the map screen.
class Scene_Map; end
# Stands in for the scene manager, whose scene the test sets.
module SceneManager
  class << self; attr_accessor :scene; end
  # Records a scene called in $scenes.
  def self.call(scene); ($scenes ||= []) << scene; end
end
# Stands in for the graphics: the frame count stays 0.
module Graphics; def self.frame_count; 0; end; end
# Stands in for RPG's database classes.
module RPG
  # Stands in for an event command.
  EventCommand = Struct.new(:code, :indent, :parameters)
  # Stands in for a common event.
  CommonEvent = Struct.new(:list)
  # An item of the database.
  class Item
    attr_reader :id, :name, :description
    # Takes the item's id, name and description.
    def initialize(id, name, description = ""); @id = id; @name = name; @description = description; end
    # Answers that the item is a key item.
    def key_item?; true; end
  end
  # Stands in for a skill.
  Skill = Struct.new(:id, :name)
end
# Stands in for RPG::Actor, with the level a companion joins at.
ActorData = Struct.new(:id, :name, :initial_level)
# Stands in for RPG::System: the switches' and variables' names and each vehicle's start.
System = Struct.new(:switches, :variables, :boat, :ship, :airship)
# Where a new game parks a vehicle, as the game's data names it: the boat nowhere, the ship and
# Galda on the field.
VehicleStart = Struct.new(:start_map_id, :start_x, :start_y)
$data_system = System.new(Array.new(8000, ""), Array.new(4000, ""), VehicleStart.new(0, 0, 0), VehicleStart.new(2, 306, 2), VehicleStart.new(2, 186, 1))
$data_actors = Array.new(1000)
[[1, "Luka", 1], [5, "Alice", 1], [16, "Granberia", 20], [45, "Tamamo", 12], [77, "Slime", 7], [80, "Harpy", 9], [525, "Sonya", 2], [841, "Sonya", 1], [842, "Sonya", 1]].each do |id, name, level|
  $data_actors[id] = ActorData.new(id, name, level)
end
$data_items = Array.new(730)
[[501, "Purple Orb"], [502, "Pass"], [503, "Key"], [504, "Medal"], [505, "Key to Hades"], [537, "Red Orb"], [538, "Blue Orb"], [540, "Yellow Orb"],
 [541, "Green Orb"], [542, "Silver Orb"], [557, "Remina Key Card"], [600, "Herb"], [700, "Auto Crossbow"], [701, "Bio Blaster"]].each { |id, name| $data_items[id] = RPG::Item.new(id, name) }
$data_items[616] = RPG::Item.new(616, "Chef's License", "[Job] Allows access to the Cook job.")
$data_weapons = Array.new(10)
$data_armors = Array.new(10)
$data_skills = Array.new(3000)
$data_skills[930] = RPG::Skill.new(930, "Angel Dance")
$data_skills[937] = RPG::Skill.new(937, "Demon Decapitation")
$data_common_events = Array.new(400)

# Stands in for the game's switches, which start off.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's variables, which start at 0.
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's self switches, which start off.
class Game_SelfSwitches; def initialize; @data = {}; end; def [](key); @data[key] == true; end; def []=(key, value); @data[key] = value; end; end
# A companion with the levels the catch-up reads and raises.
class Game_Actor
  attr_reader :base_level, :persona
  attr_accessor :cap
  # Starts the companion at their join level, with no skills and no level cap of another mod.
  def initialize(id); @id = id; @persona = id; @base_level = $data_actors[id].initial_level; @skills = []; @cap = 9999; end
  # Answers the persona the companion is in, as the game's id does.
  def id; @persona; end
  # Answers that the companion wears nothing.
  def equips; []; end
  # Answers the companion's name.
  def name; $data_actors[@id].name; end
  # Answers the levels of the companion's classes and races by id.
  def level_list; @level_list ||= {}; end
  # Answers the cap another mod holds the companion at.
  def max_level(_kind); @cap; end
  # Changes the level, within 1 and the cap.
  def change_level(level, _show, _kind); @base_level = [[level, @cap].min, 1].max; end
  # Sets the level past any cap.
  def level=(level); @base_level = level; end
  # Recovers nothing.
  def recover_all; end
  # Records a learned skill.
  def learn_skill(id); @skills |= [id]; end
  # Records the persona.
  def persona_change(persona); @persona = persona; end
end
# The game's actors: every persona of a companion is the main persona's object.
class Game_Actors
  # The main persona of each other persona.
  PERSONAS = { 841 => 525, 842 => 525 }
  # Starts with no actor made.
  def initialize; @data = {}; end
  # Answers the main persona of a persona.
  def original_id(id); PERSONAS[id] || id; end
  # Answers the main persona's actor, made on first use, or nil for one $data_actors lacks.
  def [](id); main = original_id(id); $data_actors[main] ? (@data[main] ||= Game_Actor.new(main)) : nil; end
end
# The party: every companion by their main persona, the team and the items.
class Game_Party
  attr_accessor :in_battle
  attr_reader :items
  # Starts the party with nobody and no items.
  def initialize; @include_actors = []; @actors = []; @items = Hash.new(0); end
  # Adds a companion to the roster and the team.
  def add_actor(id); add_stand_actor(id); main = $game_actors.original_id(id); @actors << main unless @actors.include?(main); end
  # Adds a companion to the roster only.
  def add_stand_actor(id); main = $game_actors.original_id(id); @include_actors << main unless @include_actors.include?(main); end
  # Takes a companion from the roster and the team.
  def remove_actor(id); main = $game_actors.original_id(id); @include_actors.delete(main); @actors.delete(main); end
  # Changes a companion's persona.
  def persona_change(persona); $game_actors[persona].persona_change(persona); end
  # Answers that no story's temporary party plays.
  def temp_actors_use?; false; end
  # Adds an item.
  def gain_item(item, amount); @items[item.id] += amount; end
  # Takes an item, down to none.
  def lose_item(item, amount); @items[item.id] = [@items[item.id] - amount, 0].max; end
  # Answers how many of an item the party holds.
  def item_number(item); @items[item.id]; end
  # Answers the team's actors.
  def all_members; @actors.map { |id| $game_actors[id] }; end
end
# Stands in for the interpreter: it runs nothing and runs while busy is set.
class Game_Interpreter
  attr_reader :list, :index
  attr_accessor :busy, :event_id
  # Takes a list and records it in $setups.
  def setup(list, event_id = 0); @list = list; @index = 0; ($setups ||= []) << list; end
  # Answers whether busy is set.
  def running?; @busy ? true : false; end
  # Runs nothing.
  def execute_command; end
  # Answers that the self switch is off.
  def ssw(key); false; end
  # Raises a class's or race's level, never lowering it.
  def set_class_level(actor_id, id, level, _show, _change); levels = $game_actors[actor_id].level_list; levels[id] = [levels[id].to_i, level].max; end
  # Changes a companion's persona through the party, as the game's does.
  def persona_change(persona); $game_party.persona_change(persona); end
  # Raises a companion's level, never lowering it.
  def level_adjust(actor_id, level); actor = $game_actors[actor_id]; actor.change_level(level, false, :base) if actor.base_level < level; end
  # Records a worn item the call puts on in $worn.
  def force_change_equip(actor_id, slot_id, _kind, item_id); ($worn ||= []) << [actor_id, slot_id, item_id]; end
  # Records the personas the compendium counts as owned in $had.
  def set_actor_had(*ids); ($had ||= []).concat(ids); end
end
# A vehicle: the map it stands on, 0 for none, and its tile.
class Game_Vehicle
  # Starts the vehicle on no map.
  def initialize; @map_id = 0; end
  # Moves the vehicle.
  def set_location(map_id, x, y); @map_id = map_id; @x = x; @y = y; end
  # Answers the map and the tile.
  def spot; [@map_id, @x, @y]; end
end
# Stands in for the map: map 3, its events and its vehicles.
class Game_Map
  attr_accessor :map_id, :interpreter, :need_refresh
  # Starts on map 3 with an interpreter.
  def initialize; @map_id = 3; @interpreter = Game_Interpreter.new; end
  # Answers the map's events by id.
  def events; @events ||= {}; end
  # Answers a vehicle by type, made on first use.
  def vehicle(type); (@vehicles ||= {})[type] ||= Game_Vehicle.new; end
  # Updates nothing.
  def update(main = false); end
end
# Stands in for the player, at 1,1 with no transfer reserved.
class Game_Player
  attr_reader :x, :y
  attr_accessor :vehicle
  # Starts the player at 1,1.
  def initialize; @x = 1; @y = 1; end
  # Answers that no transfer is reserved.
  def transfer?; false; end
  # Transfers nowhere.
  def perform_transfer; end
end
# Stands in for the system, with whether random encounters are off only.
class Game_System; attr_accessor :encounter_disabled; end
# Stands in for the data manager, whose saving, loading and new game the scripts hook.
module DataManager
  # Answers empty save contents.
  def self.make_save_contents; {}; end
  # Takes save contents.
  def self.extract_save_contents(contents); end
  # Loads nothing.
  def self.load_game_without_rescue(index); end
  # Makes nothing.
  def self.create_game_objects; end
  # Sets nothing up.
  def self.setup_new_game; end
end

$fake = open_rules_bridge
answer_story($fake)
load_script "story_state"
load_script "coop_story"
load_script "coop_choices"
load_script "world_story"
load_script "world_catchup"
# The world's story mapping: what the Raid personal lists of earlier builds shared, the chest flags
# each player's own.
$classes = listed_raid_table_hash("switches" => 8000, "variables" => 4000, "companions" => 1000, "chest_flags" => MGQ_MpStoryState.chest_flags)
# The catch-up's tables, which the tests replace with rows of their own.
DATA = GeneratedCatchupTables
# The generated joins, kept before the tests replace them.
REAL_JOINS = DATA::JOINS
# The generated removals, kept before the tests replace them.
REAL_REMOVALS = DATA::REMOVALS
# The generated settings, kept before the tests replace them.
REAL_SETTINGS = DATA::SETTINGS
# The generated key items, kept before the tests replace them.
REAL_KEY_ITEMS = DATA::KEY_ITEMS
# The generated actor changes, kept before the tests replace them.
REAL_ACTOR_CHANGES = DATA::ACTOR_CHANGES

# Puts tables of rows in place of the generated ones.
#
# @param tables [Hash{Symbol => Array}] The rows by table, the others empty.
def tables(tables = {})
  [:JOINS, :REMOVALS, :KEY_ITEMS, :CHESTS, :REWARDS, :LESSONS, :CLASS_LEVELS, :ACTOR_CHANGES, :SETTINGS, :VEHICLES, :WARP_FREE_MAPS, :MAKINA].each do |name|
    DATA.send(:remove_const, name)
    DATA.const_set(name, tables[name] || [])
  end
  $catchup_rows = nil
  [:@keys, :@tested, :@unlock_ids].each { |name| MGQ_MpWorldCatchup.instance_variable_set(name, nil) }
end

# The DLL's catch-up, as the script decided it (fixtures/catchup/engine.rb), with the save's notes
# the DLL holds.
$catchup = CatchupEngine::Host.new

# The catch-up's tables as the relay hands them with the story mapping: the rows the tests put in
# place, and the relay's seed rows of the rules, the counts
# and the companion values.
#
# @return [Array(Hash, CatchupEngine::Tables)] The relay's rows by table, and the tables read.
def catchup_tables
  $catchup_rows ||= begin
    rows = CatchupRelayRows.tables(Hash[CatchupRelayRows::TABLES.keys.map { |name| [name, DATA.const_get(name)] }])
    %w(rules counts companion_values).each { |table| rows[table] = seed_rows(table) }
    [rows, CatchupEngine.read(rows)]
  end
end

# The answers of the catch-up's topics make_engine.rb records, each with the tables and the notes
# they were answered over; nil while nothing records.
$catchup_record ||= nil

# Answers a topic of the DLL's catch-up from the engine, recording it while a recorder runs.
#
# @param topic [String] The topic.
# @yieldparam tables [CatchupEngine::Tables] The tables.
# @yieldreturn [Hash] The answer.
def answer_catchup_topic(topic)
  $fake.answer(topic) do |request|
    rows, read = catchup_tables
    # The engine takes the notes a request hands and changes them in place, so the record copies
    # the request and the notes before the call and the answer right after it.
    asked = Marshal.load(Marshal.dump("ledger" => $catchup.ledger, "request" => request))
    answer = yield(read, request)
    $catchup_record << asked.merge("topic" => topic, "tables" => rows, "answer" => Marshal.load(Marshal.dump(answer))) if $catchup_record
    answer
  end
end

$fake.answer("catchup.keys") { CatchupEngine.keys(catchup_tables[1]) }
answer_catchup_topic("catchup.check") { |read, request| $catchup.check(read, request) }
answer_catchup_topic("catchup.note") { |read, request| $catchup.note(read, request) }
answer_catchup_topic("catchup.hold_join") { |read, request| $catchup.hold_join(read, request) }
answer_catchup_topic("catchup.unlocks") { |read, request| $catchup.unlocks(read, request) }

# Starts a game: a new story with some values, a party of Luka at a level and the save's notes, with
# nothing recorded yet.
#
# @param variables [Hash] Variables by id.
# @param switches [Array<Integer>] Switches on.
# @param level [Integer] Luka's level.
def new_game(variables = {}, switches = [], level = 10)
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_self_switches = Game_SelfSwitches.new
  variables.each { |id, value| $game_variables[id] = value }
  switches.each { |id| $game_switches[id] = true }
  $game_actors = Game_Actors.new
  $game_party = Game_Party.new
  $game_party.add_actor(1)
  $game_actors[1].level = level
  $game_system = Game_System.new
  $calls.clear
  $notices.clear
  $messages.clear
  $logs.clear
  MGQ_MpCoopChoices.forget("next check")
  MGQ_MpWorldStory.loaded(:load)
  MGQ_MpWorldCatchup.loaded
end

# Writes a story's keys as the relay's tracks keep them.
#
# @param variables [Hash] Variables by id.
# @param switches [Array<Integer>] Switches on.
# @param selfs [Hash] Self switches by key.
# @return [Hash{String => String}] The keys and their values.
def packed(variables = {}, switches = [], selfs = {})
  keys = {}
  switches.each { |id| keys["s#{id}"] = "1" }
  variables.each { |id, value| keys["v#{id}"] = MGQ_MpStoryState.encode_value(value) }
  selfs.each { |key, value| keys["ss#{key.join('.')}"] = value ? "1" : "0" }
  keys
end

# Hands the game the world's track as the DLL does after the relay sent it, with the world's
# summary, and the shared companions the DLL's state names.
#
# @param fields [Hash] The world's summary and companions that differ from an empty story: "rev",
#   "part", "route", "done" and "checkpoints" (each separated by commas), "comps", "start" (the
#   story markers where the world's log starts) and "log" (the keys where it starts that differ
#   from the track's).
# @param keys [Hash{String => String}] The track's keys, see packed.
def relay(fields, keys = {})
  world = { "rev" => 1, "part" => "1", "route" => "none", "done" => "", "checkpoints" => "", "comps" => "" }.merge(fields)
  hand_track(world, keys, "track" => "world", "part" => world["part"].to_s)
end

# Hands the game the track of their own the relay put a player behind on: their part's checkpoint.
#
# @param part [String] The part.
# @param keys [Hash{String => String}] The checkpoint's keys, see packed.
# @param fields [Hash] The world's summary, as relay takes it.
def checkpoint(part, keys, fields = {})
  world = { "rev" => 1, "part" => "2", "route" => "none", "done" => "", "checkpoints" => part, "comps" => "" }.merge(fields)
  hand_track(world, keys, "why" => "behind", "track" => "t1", "part" => part, "gate" => MGQ_MpWorldCatchup.gate_of(part))
end

# Hands the game the track the relay moved a player behind on to by their level.
#
# @param from [String] The part they leave.
# @param to [String] The part they move to, or "world".
# @param keys [Hash{String => String}] The track's keys, see packed.
# @param fields [Hash] The world's summary, as relay takes it.
# @param by [String] "level", or "cap" when another mod's cap opened the gate.
def moved(from, to, keys, fields = {}, by = "level")
  world = { "rev" => 1, "part" => to == "world" ? "2" : to, "route" => "none", "done" => "", "checkpoints" => "", "comps" => "" }.merge(fields)
  state = { "why" => "moved", "track" => to == "world" ? "world" : "t2", "part" => to == "world" ? world["part"].to_s : to,
            "move" => { "from" => from, "to" => to, "gate" => MGQ_MpWorldCatchup.gate_of(from), "by" => by } }
  state["gate"] = MGQ_MpWorldCatchup.gate_of(to) unless to == "world"
  hand_track(world, keys, state)
end

# Hands the game a whole track and the world's summary, and names the world's shared companions.
#
# @param world [Hash] The summary and companions, see relay.
# @param keys [Hash{String => String}] The track's keys.
# @param state [Hash] The state's fields that differ, see track_take.
def hand_track(world, keys, state)
  list = lambda { |text| text.to_s.split(",") }
  summary = { "rev" => world["rev"], "part" => world["part"].to_s, "route" => world["route"].to_s, "done" => list.call(world["done"]), "checkpoints" => list.call(world["checkpoints"]),
              "start" => world["start"] }
  $takes << track_take(keys, world["log"] ? state.merge("log" => world["log"]) : state, world["rev"])
  $fake.post("story.status", story_status("track" => state["track"], "part" => state["part"], "gate" => state["gate"], "rev" => world["rev"], "world" => summary, "pending" => true))
  $state = "world=w1\nrev=#{world['rev']}\ncomps=#{world['comps']}\nfetch=done#{world['companions'] ? "\ncompanions=#{world['companions']}" : ''}\n\n"
end

# Runs frames as the game does: the map's update, then the scripts' writes and the bridge's batch
# and drain at the frame's Graphics.update.
#
# @param count [Integer] How many.
def frames(count)
  count.times do
    MGQ_MpWorldStory.tick
    MGQ_MpWorldCatchup.tick
    MGQ_MpStoryKeys.flush
    MGQ_Multiplayer::Bridge.frame
  end
end

# Lists the DLL calls of one export since the game started.
#
# @param name [String] The export.
# @return [Array<Array>] Each call's arguments.
def calls_of(name); $calls.select { |call| call[0] == name }.map { |call| call[1] }; end

# Lists the player's companions.
#
# @return [Array<Integer>] Their main personas.
def roster; MGQ_MpStoryState.roster_ids.sort; end
