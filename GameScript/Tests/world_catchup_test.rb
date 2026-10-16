#----------------------------------------------------------------
#  world_catchup_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-17: Checked a key item one event gives and takes back
#      Paulinchen  2026-10-15: Checked that a lasting join on another page of a visit's event waits for the gate
#      Paulinchen  2026-10-14: Checked that a return point left at Adramelech moves on with the story
#                            - Checked that a visit's own event brings its companion along before the gate
#      Paulinchen  2026-10-13: Checked that a Makina comes and shows only once a player of the world got or held it
#                            - Checked that a join the story takes back in the same step counts nowhere in the catch-up
#      Paulinchen  2026-10-12: Checked that story and quest classes and races reach the roster
#                            - Checked that story and quest skills reach the roster's companions
#                            - Stood in for a companion's name
#                            - Checked that a shared companion whose talk the player's story passed still joins
#                            - Checked that a job or race item held before is noted on entering
#                            - Checked that a job or race item any player got comes to every other player once
#                            - Read the catch-up's gifts from its log
#                            - Checked which pages keep the encounters with the map
#                            - Checked a move on at a level cap whose checkpoint is dropped
#                            - Checked Galda coming back to its start once a story is laid over
#                            - Stood in for the vehicles' start positions and a vehicle's tile
#                            - Checked that another mod's cap brings no Makina or waiting companion
#                            - Checked the story's skills and items held from a player behind or at a cap
#                            - Checked that a vehicle no story event gave yet leaves its map
#                            - Stood in for the map's vehicles and the one the player rides
#                            - Checked a world-wide chest's flags and the Randolphs found
#                            - Checked the game over's return point and a player behind getting none of the world's later part
#                            - Checked a vehicle leaving for a player behind and Galda staying
#                            - Checked that an audit reads the story's part anew
#      Paulinchen  2026-10-11: Checked the Levels page list of the catch-up and the level it counts
#                            - Checked Makina at their area level, one each
#                            - Checked that a watched telling takes its scene's key items
#                            - Checked that Amira in the roster raises her information network to 2
#                            - Checked one look at everything on entering and on a level up
#                            - Stood in for random encounters and the map's events
#                            - Checked a key item the story's place owes
#      Paulinchen  2026-10-10: Stood in for MGQ_MpCoopEvents.telling_or_moved?
#                            - Checked a shared save's own story counting as the player's in a Raid World started from it
#                            - Checked a save noting the player behind staying behind once loaded again
#                            - Checked a player moving on past a finished route to the world's route
#                            - Checked that changes made while behind stay under the checkpoint
#      Paulinchen  2026-10-09: Loaded story_state.rbx before coop_story.rbx and read the story through MGQ_MpStoryState
#                            - Checked key items whose event only plays and the last orb's event
#                            - Checked that a save noting the player behind holds the story until the world's came
#                            - Checked that a shared companion whose join the player's story passed is not brought back
#                            - Checked that a player behind in the world's part moves on to the world's story
#                            - Created
#
#----------------------------------------------------------------

# Covers world_catchup.rbx with world_story.rbx, story_state.rbx, coop_story.rbx and
# coop_choices.rbx: a player behind a Raid World's story, held on their part's checkpoint until the
# level gate moves them on, and what a story laid over the player's gives, takes and sets, from
# rewards and companions to vehicles and Makina, each once.

require_relative "support"

$logs = []
# Stands in for the mod's log: records each line in $logs and prints it.
module MGQ_Multiplayer; module Log; def self.write(m); $logs << m; puts "  log: #{m}"; end; end; end
$calls = []
$state = ""
$checkpoint = ""
$notices = []
$messages = []
$raid = true
$sharing = :off
$telling = false

# Stands in for Multiplayer.rb around the DLL link.
module MGQ_Multiplayer
  # Stands in for the DLL link: each call is noted and starts, the story's state is what $state
  # holds and the last checkpoint's what $checkpoint holds.
  module Link
    # The requests of the story's exports, whose header says busy once one starts, as the DLL's does.
    KINDS = { "mp_raid_story_fetch" => "fetch", "mp_raid_story_post" => "post", "mp_raid_route_lock" => "lock", "mp_raid_companions_add" => "companions" }

    # A function of the DLL, which notes its calls.
    Function = Struct.new(:name) do
      # Notes the call, marks its request busy in $state or the checkpoint fetch in $checkpoint, and
      # answers that it started.
      #
      # @param args [Array] The arguments of the call.
      # @return [Integer] 1.
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, args]
        kind = KINDS[name]
        $state = "#{kind}=busy\n" + $state.gsub(/^#{kind}(_\w+)?=.*\n/, "") if kind
        $checkpoint = "state=busy\npart=#{args[1].chomp("\0")}\n\n" if name == "mp_raid_checkpoint_fetch"
        1
      end
    end
    # Answers a function of the DLL that notes its calls.
    def self.function(name); Function.new(name); end
    # Reads the story's state, its headers or the checkpoint's state, as the DLL hands them over.
    #
    # @param name [String] The export.
    # @param size [Integer] The buffer's size.
    # @return [String] The text, in binary.
    def self.read(name, size)
      check_dll_call(name, ["", size])
      head = $state.split("\n\n", 2)[0].to_s
      text = { "mp_raid_story_state" => $state, "mp_raid_story_headers" => head.empty? ? "" : head + "\n\n", "mp_raid_checkpoint_state" => $checkpoint }[name].to_s
      text.dup.force_encoding("ASCII-8BIT")
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
  # Answers telling?.
  def self.telling_or_moved?; telling?; end
  # Answers that no PvP battle runs.
  def self.pvp_running?; false; end
  # Answers that no event is a chest.
  def self.chest_keys; []; end
  # Answers that no key is a chest's.
  def self.chest_key?(_key); false; end
  # Runs the block.
  def self.granting; yield; end
end
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
 [541, "Green Orb"], [542, "Silver Orb"], [600, "Herb"], [700, "Auto Crossbow"], [701, "Bio Blaster"]].each { |id, name| $data_items[id] = RPG::Item.new(id, name) }
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
  attr_reader :id, :base_level, :persona
  attr_accessor :cap
  # Starts the companion at their join level, with no skills and no level cap of another mod.
  def initialize(id); @id = id; @persona = id; @base_level = $data_actors[id].initial_level; @skills = []; @cap = 9999; end
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

load_script "story_state"
load_script "coop_story"
load_script "coop_choices"
load_script "world_catchup_data"
load_script "world_story"
load_script "world_catchup"
story = MGQ_MpWorldStory
catchup = MGQ_MpWorldCatchup
# The catch-up's tables, which the tests replace with rows of their own.
DATA = MGQ_MpWorldCatchupData
# The generated joins, kept before the tests replace them.
REAL_JOINS = DATA::JOINS
# The generated removals, kept before the tests replace them.
REAL_REMOVALS = DATA::REMOVALS
# The generated settings, kept before the tests replace them.
REAL_SETTINGS = DATA::SETTINGS

# Puts tables of rows in place of the generated ones.
#
# @param tables [Hash{Symbol => Array}] The rows by table, the others empty.
def tables(tables = {})
  [:JOINS, :REMOVALS, :KEY_ITEMS, :CHESTS, :REWARDS, :LESSONS, :CLASS_LEVELS, :SETTINGS, :VEHICLES, :WARP_FREE_MAPS, :MAKINA].each do |name|
    DATA.send(:remove_const, name)
    DATA.const_set(name, tables[name] || [])
  end
  [:@joins_by_actor, :@story_joins, :@taking_back, :@visits, :@makina_ids, :@unlock_items].each { |name| MGQ_MpWorldCatchup.instance_variable_set(name, nil) }
  MGQ_MpWorldStory.instance_variable_set(:@world_chests, nil)
end

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

# Sets what the DLL tells of the world's story.
#
# @param fields [Hash] The headers that differ from an empty story.
# @param text [String] The story.
def relay(fields, text = "")
  head = { "world" => "w1", "rev" => 1, "wrev" => 1, "p" => 0, "r1141" => 0, "r1142" => 0, "r1143" => 0, "clear" => "", "part" => "1",
           "route" => "none", "done" => "", "comps" => "", "checkpoints" => "", "fetch" => "done" }.merge(fields)
  $state = head.map { |key, value| "#{key}=#{value}" }.join("\n") + "\n\n" + text
end

# Sets what the DLL tells of the last checkpoint fetched.
#
# @param part [String] Its part.
# @param text [String] Its story.
def checkpoint(part, text)
  $checkpoint = "state=done\npart=#{part}\nrev=5\nwrev=5\n\n#{text}"
end

# Runs frames of the map.
#
# @param count [Integer] How many.
def frames(count); count.times { MGQ_MpWorldStory.tick; MGQ_MpWorldCatchup.tick }; end

# Lists the DLL calls of one export since the game started.
#
# @param name [String] The export.
# @return [Array<Array>] Each call's arguments.
def calls_of(name); $calls.select { |call| call[0] == name }.map { |call| call[1] }; end

# Lists the player's companions.
#
# @return [Array<Integer>] Their main personas.
def roster; MGQ_MpStoryState.roster_ids.sort; end

join = DATA::Join
removal = DATA::Removal
key_item = DATA::KeyItem
chest = DATA::Chest
reward = DATA::Reward

$game_map = Game_Map.new
$game_player = Game_Player.new
SceneManager.scene = Scene_Map.new

# A player behind gets their part's checkpoint, the world as it was right before that part's ending.
tables(:REWARDS => [reward.new(:skill, 937, 1, "map:406:7:2", "1", 8, :alice, [[:v, 1001, 8], [:s, 2023]]),
                    reward.new(:skill, 930, 1, "map:406:7:3", "1", 8, :ilias, [[:v, 1001, 8], [:s, 2023]]),
                    reward.new(:i, 600, 2, "map:36:17:1", "1", 6, nil, [[:v, 1001, 6]]),
                    reward.new(:i, 600, 5, "map:40:1:1", "1", 12, nil, [[:v, 1001, 12]])],
       :REMOVALS => [removal.new(16, 16, "map:50:1:1", "1", 14, nil, [[:v, 1001, 14]], true),
                     removal.new(45, 45, "map:50:2:1", "1", 14, nil, [[:v, 1001, 14]], false)],
       :JOINS => [join.new(77, 77, "map:20:1:1", "1", 9, nil, [[:v, 1001, 9]], 7, :start),
                  join.new(80, 80, "map:21:1:1", "1", 15, nil, [[:v, 1001, 15], [:s, 2300]], 20, :floor)])
new_game({ 1001 => 7, 3001 => 40 }, [4], 12)
$game_party.add_actor(16)
$game_party.add_actor(45)
$game_party.gain_item($data_items[600], 2)
frames(1)
relay({ "p" => 25, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 25 }, [2300]))
frames(16)
check("a player whose story is in an earlier part than the world's is behind", story.mode, :behind)
check("and fetches the checkpoint of their part", calls_of("mp_raid_checkpoint_fetch"), [["w1\0", "1\0"]])
check("told so with the level that moves them on",
      $notices, ["The world's story is further than yours. You see the world as it was before the end of Part 1; reach level 25 to move on."])
check("whose story events are held", [catchup.holds_story?, catchup.refusal_text], [true, "Reach level 25 to continue the story."])
checkpoint("1", packed({ 1001 => 18, 1032 => 5 }, [2023, 2300, 500]))
frames(70)
check("the checkpoint is laid over the player's story, their own values kept",
      [$game_variables[1001], $game_variables[1032], $game_switches[500], $game_variables[3001], $game_switches[4]], [18, 5, true, 40, true])
check("they write nothing", calls_of("mp_raid_story_post"), [])
check("the rewards it carried them past come by story position, their own side's alone, not those their own game gave",
      [MGQ_MpStoryState.knows?($game_actors[1], 937), MGQ_MpStoryState.knows?($game_actors[1], 930), $game_party.items[600]], [true, false, 7])
check("a removal for good it carried them past takes the companion, a temporary one does not", [roster.include?(16), roster.include?(45)], [false, true])
check("its companions join once the player's level reaches each join's gate", [roster.include?(77), roster.include?(80)], [true, false])
check("the save notes the checkpoint taken", $game_system.instance_variable_get(:@mgq_mp_catchup)["checkpoint"], "1")

# The level gate moves the player on to the next part's checkpoint while the world is past it,
# else into the world's story.
$game_actors[1].level = 20
frames(40)
check("at level 20 the waiting join of level 20 comes, raised to its level", [roster.include?(80), $game_actors[80].base_level], [true, 20])
check("but the player stays behind", [story.mode, calls_of("mp_raid_story_fetch").size], [:behind, 1])
$game_actors[1].level = 25
$messages.clear
frames(40)
check("at the gate's level the player moves on into the world's story, the world being in the next part",
      [$messages, calls_of("mp_raid_story_fetch").size], [["Level 25 reached: catching up to the world's story."], 2])
relay({ "rev" => 2, "wrev" => 2, "p" => 26, "part" => "2", "checkpoints" => "1", "fetch" => "done" }, packed({ 1001 => 26 }, [2300]))
frames(40)
check("which is laid over theirs: they play it now, never the part's ending", [story.mode, $game_variables[1001], catchup.holds_story?], [:world, 26, false])
check("the notes forget the checkpoint", $game_system.instance_variable_get(:@mgq_mp_catchup)["checkpoint"], nil)

# A player far behind moves on a part per gate, Part 2's checkpoint first.
tables
new_game({ 1001 => 7 }, [], 30)
frames(1)
relay({ "rev" => 3, "wrev" => 3, "p" => 36, "part" => "3", "checkpoints" => "1,2" }, packed({ 1001 => 36 }))
frames(16)
checkpoint("1", packed({ 1001 => 18 }))
frames(100)
check("a player past their part's gate moves on to the next part's checkpoint while the world is past it",
      [$game_variables[1001], calls_of("mp_raid_checkpoint_fetch").map { |args| args[1] }], [18, ["1\0", "2\0"]])
checkpoint("2", packed({ 1001 => 33 }))
frames(70)
check("and stays there until that part's gate", [$game_variables[1001], story.mode, catchup.refusal_text], [33, :behind, "Reach level 55 to continue the story."])

# A cap of another mod below the gate holds nobody back.
$game_actors[1].cap = 40
$game_actors[1].level = 40
frames(40)
check("a player capped below the gate is caught up once at their cap", calls_of("mp_raid_story_fetch").size, 2)
$game_actors[1].cap = 9999

# A player behind learns no skill of the world's story, and the story's skills and items a move on
# at another mod's level cap carries them past wait for their real level, also over a load.
tables(:REWARDS => [reward.new(:skill, 930, 1, "map:60:2:1", "2", 24, nil, [[:v, 1001, 24]], true),
                    reward.new(:i, 600, 1, "map:60:3:1", "2", 24, nil, [[:v, 1001, 24]], true),
                    reward.new(:skill, 937, 1, "map:61:1:1", "2", 28, nil, [[:v, 1001, 28]], true)])
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 50, "wrev" => 50, "p" => 26, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 26 }))
frames(16)
checkpoint("1", packed({ 1001 => 18 }))
frames(70)
check("a player behind learns no skill of the world's story", [story.mode, MGQ_MpStoryState.knows?($game_actors[1], 930)], [:behind, false])
$game_actors[1].cap = 20
$game_actors[1].level = 20
frames(40)
relay({ "rev" => 51, "wrev" => 51, "p" => 26, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 26 }))
frames(40)
MGQ_MpWorldCatchup.level_up
frames(40)
check("moved on at a cap below the gate, the skills and items the world's story carried them past wait",
      [story.mode, MGQ_MpStoryState.knows?($game_actors[1], 930), $game_party.items[600].to_i], [:world, false, 0])
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "52", :relay => true)
frames(1)
relay({ "rev" => 52, "wrev" => 52, "p" => 29, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 29 }))
frames(40)
check("but what the world's story carries them past later comes as usual", MGQ_MpStoryState.knows?($game_actors[1], 937), true)
$game_actors[1].cap = 9999
$game_actors[1].level = 25
$messages.clear
$logs.clear
MGQ_MpWorldStory.loaded(:load)
MGQ_MpWorldCatchup.loaded
frames(1)
relay({ "rev" => 53, "wrev" => 53, "p" => 29, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 29 }))
frames(80)
check("and come once a load finds the real level at the gate",
      [MGQ_MpStoryState.knows?($game_actors[1], 930), $game_party.items[600].to_i, $logs.grep(/the story gave the player/).size], [true, 1, 1])
frames(40)
check("once", [$game_party.items[600].to_i, $logs.grep(/the story gave the player/).size], [1, 1])

# A move on at a level cap whose checkpoint is dropped, as the player's story reached the world's
# part before it came: the story laid over next still makes its rewards wait, later ones give as
# usual.
tables(:REWARDS => [reward.new(:i, 600, 1, "map:62:1:1", "1", 16, nil, [[:v, 1001, 16]], true),
                    reward.new(:i, 600, 2, "map:62:2:1", "1", 17, nil, [[:v, 1001, 17]], true),
                    reward.new(:i, 600, 4, "map:62:3:1", "1", 18, nil, [[:v, 1001, 18]], true)])
# Answers the catch-up's notes in the save.
#
# @return [Hash] The notes.
notes = lambda { $game_system.instance_variable_get(:@mgq_mp_catchup) }
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 60, "wrev" => 60, "p" => 36, "part" => "3", "checkpoints" => "1,2" }, packed({ 1001 => 36 }))
frames(16)
checkpoint("1", packed({ 1001 => 15 }))
frames(70)
$game_actors[1].cap = 20
$game_actors[1].level = 20
frames(40)
check("moved on at a cap below the gate, the catch-up asks for the next part's checkpoint and notes the gate",
      [calls_of("mp_raid_checkpoint_fetch").map { |args| args[1] }, notes.call["capped"]], [["1\0", "2\0"], 25])
# The player's story reached the world's part, as check_progress finds it.
story.instance_variable_set(:@mode, nil)
story.refetch(:caught_up)
frames(1)
relay({ "rev" => 61, "wrev" => 61, "p" => 16, "part" => "1", "checkpoints" => "1,2" }, packed({ 1001 => 16 }))
checkpoint("2", packed({ 1001 => 33 }))
frames(80)
check("the world's story is laid over theirs and the checkpoint dropped", [story.mode, $game_variables[1001]], [:world, 16])
check("the rewards that story carried them past still wait for the gate, which then clears",
      [$game_party.items[600].to_i, notes.call["waits"].size, notes.call["capped"]], [0, 1, nil])
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "62", :relay => true)
frames(1)
relay({ "rev" => 62, "wrev" => 62, "p" => 17, "part" => "1", "checkpoints" => "1,2" }, packed({ 1001 => 17 }))
frames(40)
check("a later story gives its rewards as usual, the first still waiting", [$game_party.items[600].to_i, notes.call["waits"].size], [2, 1])
catchup.note_capped(99)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "63", :relay => true)
frames(1)
relay({ "rev" => 63, "wrev" => 63, "p" => 18, "part" => "1", "checkpoints" => "1,2" }, packed({ 1001 => 18 }))
frames(40)
check("and a gate noted while the player plays the world's story holds nothing back", [$game_party.items[600].to_i, notes.call["capped"]], [6, nil])
$game_actors[1].cap = 9999
$game_actors[1].level = 25
frames(40)
check("what waited comes once the real level reaches the gate", [$game_party.items[600].to_i, notes.call["waits"].size], [7, 0])

# Key items are everyone's, and so are the chests that hold them, opened once for the world.
tables(:KEY_ITEMS => [key_item.new(502, 1, "map:6:33:1", "1", 5, nil, [[:v, 1001, 6]]),
                      key_item.new(503, 1, "map:7:24:2", "2", 22, nil, [[:v, 1001, 22]]),
                      key_item.new(503, -1, "map:7:25:1", "2", 24, nil, [[:v, 1001, 24]]),
                      key_item.new(504, 1, "map:8:1:1", "2", 30, nil, [[:v, 1001, 30]])],
       :CHESTS => [chest.new([30, 4, "A"], [501], "2", 22, [7102])])
new_game({ 1001 => 5 }, [], 5)
check("a story chest is the world's: its self switch goes with the story, not kept as the player's",
      [story.chest?([30, 4, "A"]), story.chest?([12, 3, "A"]), story.chest_list.include?([30, 4, "A"])], [false, true, false])
frames(1)
relay({ "rev" => 4, "wrev" => 4, "p" => 26, "part" => "2" }, packed({ 1001 => 26 }, [], { [30, 4, "A"] => true }))
frames(40)
check("a player behind gets every key item the world's story gave, and loses what it took",
      [$game_party.items[502], $game_party.items[503], $game_party.items[504]], [1, 0, 0])
check("and the story chests the world opened, which show open for them too", [$game_party.items[501], $game_self_switches[[30, 4, "A"]]], [1, true])
check("with the chest flags they turn on, such as an ore the Chaos forge asks for", $game_switches[7102], true)
frames(40)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "5", :relay => true)
frames(1)
relay({ "rev" => 5, "wrev" => 5, "p" => 31, "part" => "2" }, packed({ 1001 => 31 }, [], { [30, 4, "A"] => true }))
frames(40)
check("each once, the next only as the world gives it", [$game_party.items[502], $game_party.items[501], $game_party.items[504]], [1, 1, 1])

# Companions join by their gates, Sonya's Chaos return at 300 among them.
sonya = REAL_JOINS.find { |row| row.persona == 842 && row.site == "map:1834:20:1" }
check("Sonya's Chaos return joins as persona 842 at 300", [sonya.actor, sonya.gate, sonya.rule], [525, 300, :floor])
tables(:JOINS => [sonya])
chaos = { 1001 => 40, 1143 => 21 }
sonya.marks.each { |mark| chaos[mark[1]] = mark[2] if mark[0] == :v }
on = sonya.marks.select { |mark| mark[0] == :s }.map { |mark| mark[1] }
new_game({ 1001 => 40, 1143 => 20 }, [], 150)
frames(1)
relay({ "rev" => 6, "wrev" => 6, "p" => 40, "r1143" => 20, "part" => "chaos", "route" => "chaos" }, packed({ 1001 => 40, 1143 => 20 }))
frames(16)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "7", :relay => true)
frames(1)
relay({ "rev" => 7, "wrev" => 7, "p" => 40, "r1143" => 21, "part" => "chaos", "route" => "chaos" }, packed(chaos, on))
frames(40)
check("a join the world's story carried the player past waits for its gate", [story.mode, roster.include?(525)], [:world, false])
$game_actors[1].level = 299
$game_actors[1].cap = 299
frames(40)
check("not at 299, though another mod caps the player there", roster.include?(525), false)
$game_actors[1].cap = 9999
$game_actors[1].level = 300
frames(40)
check("at 300 Sonya joins in her Chaos persona at 300", [roster.include?(525), $game_actors[525].persona, $game_actors[525].base_level], [true, 842, 300])
check("and says so", $messages.last, "Sonya joined: level 300 reached.")
frames(40)
check("never twice", roster.count(525), 1)

# A story event of the player's own hands a companion out before the gate: the join waits for it.
early = join.new(45, 45, "map:60:1:1", "2", 25, nil, [[:v, 1001, 25]], 60, :floor)
tables(:JOINS => [early])
new_game({ 1001 => 24 }, [], 40)
frames(1)
relay({ "rev" => 8, "wrev" => 8, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
$telling = true
$game_party.add_actor(45)
check("the game's own join during the player's telling waits for the gate", [roster.include?(45), $messages.last], [false, "Tamamo joins you once you reach level 60."])
$game_variables[1001] = 25
$telling = false
frames(40)
$game_party.add_actor(77)
check("a companion without a join waiting joins as the game does", roster.include?(77), true)
$game_actors[1].level = 60
frames(40)
check("at the gate the held companion joins at the join's level", [roster.include?(45), $game_actors[45].base_level], [true, 60])

# An event that brings a companion along on a visit only, and insists on them, as the Arena's final
# adds Alma Elma again until she is in the party: the catch-up never holds that join back.
visit = join.new(45, 45, "map:483:86:1", "2", 24, nil, [[:v, 1001, 24]], 60, :kept, 238, true)
lasting = join.new(45, 45, "map:291:23:1", "2", 24, nil, [[:v, 1001, 24]], 60, :kept, 62, true)
tables(:JOINS => [lasting, visit], :REMOVALS => [removal.new(45, 45, "map:483:86:1", "2", 24, nil, [[:v, 1001, 24]], true, 262)])
new_game({ 1001 => 24 }, [], 40)
frames(1)
relay({ "rev" => 9, "wrev" => 9, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
# Stands in for a map event and its pages.
paged_event = Struct.new(:mgq_mp_pages)
event_page = Struct.new(:list)
visit_pages = [event_page.new([RPG::EventCommand.new(129, 0, [45])]), event_page.new([RPG::EventCommand.new(129, 0, [45])])]
$game_map.events[86] = paged_event.new(visit_pages)
$telling = true
$game_map.map_id = 483
$game_map.interpreter.setup(visit_pages[0].list, 86)
$game_map.interpreter.event_id = 86
$messages.clear
$game_party.add_actor(45)
check("a visit's own event brings the companion along though a lasting join waits for its gate", [roster.include?(45), $messages], [true, []])
$game_party.remove_actor(45)
$game_map.interpreter.setup(visit_pages[1].list, 86)
$game_party.add_actor(45)
check("while another page of that event still waits for the gate", [roster.include?(45), $messages.last], [false, "Tamamo joins you once you reach level 60."])
$game_map.interpreter.setup(visit_pages[0].list, 12)
$game_map.interpreter.event_id = 12
$game_party.add_actor(45)
check("as does another event of the player's", [roster.include?(45), $messages.last], [false, "Tamamo joins you once you reach level 60."])
$telling = false
$game_map.interpreter.event_id = 0
$game_map.events.delete(86)
$game_map.map_id = 3

# The world's shared companions join as far as the world shares them.
tables(:JOINS => [join.new(16, 16, "map:70:1:1", "ad", 10, nil, [[:v, 1141, 10]], 50, :start)])
$sharing = :story
new_game({ 1001 => 40, 1142 => 5 }, [], 49)
$game_party.add_actor(77)
frames(1)
relay({ "rev" => 9, "wrev" => 9, "p" => 40, "r1142" => 5, "part" => "mr", "route" => "mr", "comps" => "16,80" }, packed({ 1001 => 40, 1142 => 5 }))
frames(40)
check("a story companion another player got waits for its gate", roster.include?(16), false)
$game_actors[1].level = 50
frames(40)
check("then joins, though the player's story never passed its join", roster.include?(16), true)
check("a battle recruit is not shared with story companions alone", roster.include?(80), false)
check("the player's own battle recruit is no story companion to share", calls_of("mp_raid_companions_add"), [])
$sharing = :all
new_game({ 1001 => 40, 1142 => 5 }, [], 9)
$game_party.add_actor(77)
frames(1)
relay({ "rev" => 9, "wrev" => 9, "p" => 40, "r1142" => 5, "part" => "mr", "route" => "mr", "comps" => "16,80" }, packed({ 1001 => 40, 1142 => 5 }))
frames(700)
check("with battle recruits shared, one joins at its start level", roster.include?(80), true)
check("and the player's own recruit goes to the world's list, once", calls_of("mp_raid_companions_add"), [["w1\0", "77\0"]])
relay({ "rev" => 10, "wrev" => 9, "p" => 40, "r1142" => 5, "part" => "mr", "route" => "mr", "comps" => "16,77,80", "companions" => "done" }, packed({ 1001 => 40, 1142 => 5 }))
frames(700)
check("which the next look sends nothing for", calls_of("mp_raid_companions_add").size, 1)
# A talk join the player's story walked past gave them nothing, so the world's share still brings
# them.
tables(:JOINS => [join.new(45, 45, "map:5:27:1", "1", 6, nil, [[:v, 1001, 6]], 8, :start, 1, false)])
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 12, "wrev" => 12, "p" => 9, "part" => "1", "comps" => "45" }, packed({ 1001 => 9 }))
frames(40)
check("a shared companion whose talk join the player's story only walked past, as its notes say, joins at its gate",
      [MGQ_MpWorldCatchup.send(:ledger)["done"]["j:map:5:27:1:45"], roster.include?(45)], [true, true])
new_game({ 1001 => 9 }, [], 10)
MGQ_MpWorldCatchup.send(:ledger)["done"]["s:45"] = true
frames(1)
relay({ "rev" => 13, "wrev" => 13, "p" => 9, "part" => "1", "comps" => "45" }, packed({ 1001 => 9 }))
frames(40)
check("and one an earlier build left out so is looked at again", [roster.include?(45), MGQ_MpWorldCatchup.send(:ledger)["done"]["s:45"]], [true, "settled"])
$sharing = :off
new_game({ 1001 => 40, 1142 => 5 }, [], 90)
frames(1)
relay({ "rev" => 11, "wrev" => 11, "p" => 40, "r1142" => 5, "part" => "mr", "route" => "mr", "comps" => "16,80" }, packed({ 1001 => 40, 1142 => 5 }))
frames(40)
check("with sharing off nobody joins from the list", [roster.include?(16), roster.include?(80)], [false, false])

# A checkpoint fetch that failed before the relay answered names no part of its own.
tables
$sharing = :off
new_game({ 1001 => 7 }, [], 5)
frames(1)
relay({ "rev" => 12, "wrev" => 12, "p" => 25, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 25 }))
frames(16)
$checkpoint = "state=failed\nerror=unreachable\n\n"
frames(1830)
check("a failed checkpoint fetch is tried again later, though it names no part", calls_of("mp_raid_checkpoint_fetch").size, 2)
checkpoint("1", "")
frames(200)
check("a checkpoint this game cannot read leaves the player on their own story, fetched no more",
      [story.mode, calls_of("mp_raid_checkpoint_fetch").size, $game_system.instance_variable_get(:@mgq_mp_catchup)["checkpoint"]], [:behind, 2, "1"])

# A player behind in Part 3 stays behind when the world returns from a route to the Great Decision.
tables
new_game({ 1001 => 36 }, [], 40)
frames(1)
relay({ "rev" => 13, "wrev" => 13, "p" => 40, "r1141" => 10, "part" => "ad", "route" => "ad", "checkpoints" => "1,2,3" }, packed({ 1001 => 40, 1141 => 10 }))
frames(16)
checkpoint("3", packed({ 1001 => 39 }))
frames(70)
check("a Part 3 player behind the world's route takes Part 3's checkpoint", [story.mode, $game_variables[1001]], [:behind, 39])
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "14", :relay => true)
frames(1)
relay({ "rev" => 14, "wrev" => 14, "p" => 40, "part" => "3", "clear" => "ad", "done" => "ad", "checkpoints" => "1,2,3,ad" }, packed({ 1001 => 40 }, [7096]))
frames(100)
check("and stays behind below the gate once the world is back at the Great Decision", [story.mode, $game_variables[1001], $game_switches[7096]], [:behind, 39, false])
story.loaded(:load)
catchup.loaded
frames(1)
relay({ "rev" => 14, "wrev" => 14, "p" => 40, "part" => "3", "clear" => "ad", "done" => "ad", "checkpoints" => "1,2,3,ad" }, packed({ 1001 => 40 }, [7096]))
frames(100)
check("also once the save noting them behind loaded again and the world's story came",
      [story.mode, $game_variables[1001], $game_switches[7096], calls_of("mp_raid_story_fetch").size > 2], [:behind, 39, false, true])
$game_actors[1].level = 65
frames(40)
relay({ "rev" => 14, "wrev" => 14, "p" => 40, "part" => "3", "clear" => "ad", "done" => "ad", "checkpoints" => "1,2,3,ad" }, packed({ 1001 => 40 }, [7096]))
frames(40)
check("until the gate moves them on into the world's story", [story.mode, $game_variables[1001], $game_switches[7096]], [:world, 40, true])

# Rows by what holds in the story: an optional event nobody played gives nothing, nor one only
# there to play, and a finished route's rows count at the Great Decision.
tables(:REWARDS => [reward.new(:i, 600, 3, "map:36:18:1", "1", 10, nil, [[:v, 1001, 10], [:s, 2400]], true),
                    reward.new(:skill, 930, 1, "map:1697:7:2", "ad", 6, nil, [[:v, 1141, 6]], true)],
       :KEY_ITEMS => [key_item.new(503, 1, "map:6:33:1", "1", 12, nil, [[:v, 1001, 12]], false),
                      key_item.new(504, 1, "map:8:1:1", "1", 12, nil, [[:v, 1001, 12], [:s, 2401]], true)],
       :JOINS => [join.new(77, 77, "map:140:25:1", "2", 25, nil, [[:v, 1001, 25]], 7, :start, 3, false)])
new_game({ 1001 => 24 }, [], 40)
frames(1)
relay({ "rev" => 15, "wrev" => 15, "p" => 26, "part" => "2" }, packed({ 1001 => 26 }, [2401]))
frames(40)
check("an earlier part's row gives only when its marks hold in the story laid over the player's",
      [$game_party.items[600], $game_party.items[504]], [0, 1])
check("a row whose event is only there to play lets its companion join nobody, but its key item comes, being the world's",
      [roster.include?(77), $game_party.items[503]], [false, 1])
new_game({ 1001 => 39 }, [], 70)
frames(1)
relay({ "rev" => 16, "wrev" => 16, "p" => 40, "part" => "3", "clear" => "ad", "done" => "ad" }, packed({ 1001 => 40 }, [7096]))
frames(40)
check("a finished route's rows count while the story is back at the Great Decision", MGQ_MpStoryState.knows?($game_actors[1], 930), true)

# A join and a removal of one event go by their order in its list.
tables(:REMOVALS => [removal.new(16, 16, "map:483:86:1", "2", 24, nil, [[:v, 1001, 24]], true, 262),
                     removal.new(45, 45, "ce:9141", "2", 24, nil, [[:v, 1001, 24]], true, 10)],
       :JOINS => [join.new(16, 16, "map:483:86:1", "2", 24, nil, [[:v, 1001, 24]], 20, :kept, 238, true),
                  join.new(45, 45, "ce:9141", "2", 24, nil, [[:v, 1001, 24]], 12, :kept, 50, true)])
new_game({ 1001 => 23 }, [], 40)
$game_party.add_actor(16)
$game_party.add_actor(45)
frames(1)
relay({ "rev" => 17, "wrev" => 17, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
check("an event that adds a companion and then takes them away for good takes them, one that gives them back keeps them",
      [roster.include?(16), roster.include?(45)], [false, true])

# A world chest the player opened stays open under the world's story, which takes it.
tables(:CHESTS => [chest.new([30, 4, "A"], [501], "2", 22)])
new_game({ 1001 => 23 }, [], 40)
$game_self_switches[[30, 4, "A"]] = true
frames(1)
relay({ "rev" => 18, "wrev" => 18, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
check("a world chest the player opened stays open under the world's story", [story.mode, $game_self_switches[[30, 4, "A"]], $game_party.items[501]], [:world, true, 0])
frames(600)
check("and goes to the world's story with the next write", calls_of("mp_raid_story_post").size > 0, true)

# The Randolphs found follow the Randolph switches on, as two players finding one each at once kept
# one addition.
tables
new_game({ 1001 => 24, 1354 => 1 }, [3101], 40)
frames(1)
relay({ "rev" => 18, "wrev" => 18, "p" => 24, "part" => "2" }, packed({ 1001 => 24, 1354 => 1 }, [3101, 3150]))
frames(40)
check("the Randolphs found count the Randolph switches of the world's story laid over the player's", [story.mode, $game_variables[1354]], [:world, 2])

# What the story could not give shows as nothing given, whatever the log returns.
tables(:REWARDS => [reward.new(:skill, 937, 1, "map:60:2:1", "2", 24, nil, [[:v, 1001, 24]], true),
                    reward.new(:i, 650, 1, "map:60:3:1", "2", 24, nil, [[:v, 1001, 24]], true)])
new_game({ 1001 => 23 }, [], 40)
$game_actors[1].learn_skill(937)
MGQ_Multiplayer::Log.singleton_class.send(:alias_method, :quiet_write, :write)
MGQ_Multiplayer::Log.define_singleton_method(:write) { |message| quiet_write(message); 87 }
frames(1)
relay({ "rev" => 19, "wrev" => 19, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
MGQ_Multiplayer::Log.singleton_class.send(:alias_method, :write, :quiet_write)
check("a skill Luka knows and an item the game lacks are no gifts", $logs.grep(/the story gave the player/), [])

# A key item whose event is only there to play comes up to its amount, unless the story took it
# since.
tables(:KEY_ITEMS => [key_item.new(505, 1, "map:29:35:2", "1", 7, nil, [[:v, 1001, 7]], false),
                      key_item.new(503, 1, "map:6:33:1", "1", 7, nil, [[:v, 1001, 7]], false),
                      key_item.new(503, -1, "map:7:25:1", "1", 9, nil, [[:v, 1001, 9]], true)])
new_game({ 1001 => 6 }, [], 40)
$game_party.gain_item($data_items[505], 1)
frames(1)
relay({ "rev" => 21, "wrev" => 21, "p" => 10, "part" => "1" }, packed({ 1001 => 10 }))
frames(40)
check("a key item only there to play comes up to its amount, never one the world's story took since",
      [$game_party.items[505], $game_party.items[503]], [1, 0])

# A key item the story's place owes comes to a player who lacks it, whatever gave it before.
tables(:KEY_ITEMS => [key_item.new(501, 1, "map:2:5:1", "1", 7, :alice, [[:v, 1001, 7], [:s, 5001]], true),
                      key_item.new(501, 1, "map:2:5:2", "1", 7, :ilias, [[:v, 1001, 7], [:s, 5001]], true),
                      key_item.new(505, 1, "map:29:35:2", "1", 7, nil, [[:v, 1001, 7]], true),
                      key_item.new(505, -1, "map:30:1:1", "1", 8, nil, [[:v, 1001, 8]], true)])
new_game({ 1001 => 9 }, [5001, 5], 40)
frames(1)
relay({ "rev" => 23, "wrev" => 23, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }, [5001]))
frames(40)
check("a player whose own story is past a key item's row but who never got it gets it, on their side once",
      [$game_party.items[501], $game_party.items[505]], [1, 0])
$game_party.items[501] = 0
frames(40)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "24", :relay => true)
frames(1)
relay({ "rev" => 24, "wrev" => 24, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }, [5001]))
frames(40)
check("and gets it again once it is gone, its row long done", $game_party.items[501], 1)

# An event that gives a key item and takes it back in the same run owes nothing, and the other key
# items still come.
tables(:KEY_ITEMS => [key_item.new(556, 1, "map:124:49:1", "1", 7, nil, [[:v, 1001, 7], [:v, 1084, 2]], true),
                      key_item.new(505, 1, "map:29:35:2", "1", 7, nil, [[:v, 1001, 7]], true),
                      key_item.new(556, -1, "map:124:49:1", "1", 7, nil, [[:v, 1001, 7], [:v, 1084, 2]], true)])
new_game({ 1001 => 6 }, [], 40)
frames(1)
relay({ "rev" => 25, "wrev" => 25, "p" => 9, "part" => "1" }, packed({ 1001 => 9, 1084 => 2 }))
frames(40)
check("a key item one event gives and takes back stays away, and the others come",
      [$game_party.items[556], $game_party.items[505], $logs.grep(/failed/)], [0, 1, []])
doll = key_item.new(592, 1, "map:1197:62:1", "chaos", 21, nil, [[:v, 1143, 21]], true)
tables(:KEY_ITEMS => [doll, key_item.new(592, -1, "ce:480", "mr", 34, nil, [[:v, 1142, 34]], true)])
route_story = [[], [], {}]
route_story[1][1142] = 34
check("a row of another route at a later step never takes back what a route gave",
      [catchup.passed?(DATA::KEY_ITEMS[1], route_story), catchup.taken_since?(doll, route_story, route_story)], [true, false])

# The catch-up looks at everything on entering and on a level up: the player's own values the
# story sets, the warp ban, the story's skills and its companions.
setting = DATA::Setting
tables(:SETTINGS => [setting.new(:encounters, 0, false, "map:545:1:1", "1", 0, nil, [[:v, 1001, 0]], true),
                     setting.new(:v, 1002, 1, "map:545:1:1", "1", 0, nil, [[:v, 1001, 0]], true),
                     setting.new(:encounters, 0, true, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], true),
                     setting.new(:v, 1002, 2, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], true)],
       :WARP_FREE_MAPS => [3],
       :REWARDS => [reward.new(:skill, 930, 1, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], true)],
       :JOINS => [join.new(77, 77, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], 1, :start, 1, true)])
new_game({ 1001 => 9, 1002 => 1 }, [100], 40)
$game_system.encounter_disabled = true
frames(1)
relay({ "rev" => 25, "wrev" => 25, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("on entering, the player's own values the story sets move on from an earlier step's to the latest step's, the warp ban lifts where warping is free, and Luka learns the skill he lacks",
      [$game_system.encounter_disabled, $game_variables[1002], $game_switches[100], $game_actors[1].instance_variable_get(:@skills).include?(930)], [false, 2, false, true])
check("and a story companion missing from the roster joins at their gate", $game_party.all_members.map(&:id).include?(77), true)
$game_party.remove_actor(77)
$game_variables[1002] = 9
$game_system.encounter_disabled = true
# Stands in for an event page.
encounter_page = Struct.new(:list)
# Stands in for a map event whose page that applies now is the one it holds.
map_event = Struct.new(:proper) { def find_proper_page; proper; end }
$game_map.events[1] = map_event.new(encounter_page.new([RPG::EventCommand.new(136, 0, [0])]))
$game_switches[100] = true
$game_map.map_id = 4
MGQ_MpWorldCatchup.level_up
frames(40)
check("a level up looks again: a value of the player's own making stays, the encounters stay with a map that sets them, a warp ban off the free maps stays",
      [$game_variables[1002], $game_system.encounter_disabled, $game_switches[100]], [9, true, true])
check("and one gone from the roster joins again", $game_party.all_members.map(&:id).include?(77), true)
[[nil, "no page applies now"], [encounter_page.new([RPG::EventCommand.new(136, 0, [1])]), "the page that applies now turns them on too"],
 [encounter_page.new([RPG::EventCommand.new(101, 0, [])]), "the page that applies now leaves them alone, as an opening's page of an earlier step"]].each do |page, why|
  $game_map.events[1] = map_event.new(page)
  $game_system.encounter_disabled = true
  MGQ_MpWorldCatchup.level_up
  frames(40)
  check("the story turns the encounters on where #{why}", $game_system.encounter_disabled, false)
end
$game_map.events.clear
$game_map.map_id = 3

# The game over's return point goes by the route under way, never a finished route's rows.

# Starts a game, lets the catch-up settle its story and answers the return point.
#
# @param variables [Hash] Variables by id.
# @param switches [Array<Integer>] Switches on.
# @param told [Array, nil] The world's story, nil for none.
# @return [Integer] The return point's variable.
settled = lambda do |variables, switches, told = nil|
  new_game(variables, switches, 40)
  catchup.new_look
  catchup.settle(catchup.story_now, told)
  $game_variables[1002]
end
tables(:SETTINGS => REAL_SETTINGS)
check("a player on Monster Lord after clearing Angel Destruction keeps the return point of their route",
      settled.call({ 1001 => 40, 1142 => 1, 1002 => 112 }, [7096]), 112)
check("also further along it", settled.call({ 1001 => 40, 1142 => 23, 1002 => 81 }, [7096]), 81)
check("as without the cleared route", settled.call({ 1001 => 40, 1142 => 1, 1002 => 112 }, []), 112)
check("back at the Great Decision after a route the return point the decision set stays",
      settled.call({ 1001 => 39, 1069 => 4, 1002 => 3 }, [7096]), 3)
told_on_route = []
told_on_route[1001] = 40
told_on_route[1141] = 70
check("a world's story on another route sets none of its return points",
      settled.call({ 1001 => 40, 1142 => 1, 1002 => 112 }, [7096], [[], told_on_route, {}]), 112)
check("a return point left at Adramelech moves on to Part 2's once the story is past him",
      [settled.call({ 1001 => 19, 1032 => 7, 1002 => 19 }, []), settled.call({ 1001 => 17, 1032 => 7, 1002 => 19 }, [])], [2, 19])

# A player behind keeps the return point of their own part.
new_game({ 1001 => 7, 1002 => 2 }, [], 12)
frames(1)
relay({ "rev" => 60, "wrev" => 60, "p" => 25, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 25, 1050 => 9 }))
frames(40)
check("a player behind gets no return point of the world's later part", [story.mode, $game_variables[1002]], [:behind, 2])
checkpoint("1", packed({ 1001 => 18 }))
frames(70)
check("nor once their part's checkpoint is laid over their story", [$game_variables[1001], $game_variables[1002]], [18, 2])

# The parts of one look are kept by the story itself, and every audit looks anew.
new_game({ 1001 => 10 }, [], 40)
looked = catchup.story_now
catchup.new_look
catchup.story_part(looked)
$game_variables[1001] = 25
catchup.audit(looked)
check("an audit reads the part of a story anew", catchup.story_part(looked), "2")
check("and keeps the parts by the story itself", catchup.instance_variable_get(:@story_parts).compare_by_identity?, true)

# A vehicle no event of the story gave yet leaves its map, as Galda and the ship parked on the
# field by a new game whose setup never ran; one the player rides stays until they got off.

# Answers the map a vehicle stands on.
#
# @param type [Symbol] The vehicle.
# @return [Integer] The map, 0 for none.
vehicle_map = lambda { |type| $game_map.vehicle(type).instance_variable_get(:@map_id) }
tables(:VEHICLES => [DATA::Vehicle.new(2, "map:645:33:1", "3", 37, nil, [[:v, 1001, 37]], true)])
new_game({ 1001 => 9 }, [], 40)
$game_map.vehicle(:airship).set_location(2, 186, 1)
$game_map.vehicle(:ship).set_location(2, 306, 2)
$game_player.vehicle = $game_map.vehicle(:ship)
frames(1)
relay({ "rev" => 26, "wrev" => 26, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("on entering, Galda parked on the field before the story gave it leaves, the ship the player rides stays",
      [vehicle_map.call(:airship), vehicle_map.call(:ship)], [0, 2])
$game_player.vehicle = nil
frames(40)
check("and the ship leaves once the player got off", vehicle_map.call(:ship), 0)
new_game({ 1001 => 34 }, [], 40)
$game_map.vehicle(:airship).set_location(2, 237, 239)
frames(1)
relay({ "rev" => 27, "wrev" => 27, "p" => 37, "part" => "3" }, packed({ 1001 => 37 }))
frames(40)
check("Galda stays once the world's story is past the event that gives it", vehicle_map.call(:airship), 2)
new_game({ 1001 => 9 }, [], 12)
$game_map.vehicle(:airship).set_location(2, 237, 239)
frames(1)
relay({ "rev" => 61, "wrev" => 61, "p" => 37, "part" => "3", "checkpoints" => "1,2" }, packed({ 1001 => 37 }))
frames(40)
check("but leaves for a player behind whose own story has not given it", [story.mode, vehicle_map.call(:airship)], [:behind, 0])

# A vehicle the story gave that stands on no map comes back where a new game parks it, once a
# checkpoint or the world's story past its event is laid over; one on a map stays where it is.
tables(:VEHICLES => [DATA::Vehicle.new(2, "map:645:33:1", "3", 37, nil, [[:v, 1001, 37]], true),
                     DATA::Vehicle.new(0, "map:33:50:1", "2", 24, nil, [[:v, 1001, 24]], true)])
new_game({ 1001 => 36 }, [], 40)
$game_map.vehicle(:airship).set_location(2, 237, 239)
frames(1)
relay({ "rev" => 62, "wrev" => 62, "p" => 40, "r1141" => 10, "part" => "ad", "route" => "ad", "checkpoints" => "1,2,3" }, packed({ 1001 => 40, 1141 => 10 }))
frames(16)
frames(24)
check("a player behind before the event that gives Galda loses the Galda parked on the field", [story.mode, vehicle_map.call(:airship)], [:behind, 0])
checkpoint("3", packed({ 1001 => 39 }))
frames(70)
check("and once a checkpoint past its event is laid over, Galda is back at its start on the field, the boat without one stays off",
      [story.mode, $game_variables[1001], $game_map.vehicle(:airship).spot, vehicle_map.call(:boat)], [:behind, 39, [2, 186, 1], 0])
new_game({ 1001 => 34 }, [], 40)
$game_map.vehicle(:airship).set_location(0, 0, 0)
$game_map.vehicle(:ship).set_location(0, 0, 0)
frames(1)
relay({ "rev" => 63, "wrev" => 63, "p" => 37, "part" => "3" }, packed({ 1001 => 37 }))
frames(40)
check("the world's story past its event laid over brings Galda back to its start, not the ship no event gave",
      [story.mode, $game_map.vehicle(:airship).spot, vehicle_map.call(:ship)], [:world, [2, 186, 1], 0])
$game_map.vehicle(:airship).set_location(2, 237, 239)
MGQ_MpWorldCatchup.level_up
frames(40)
check("a Galda on a map stays where it is", $game_map.vehicle(:airship).spot, [2, 237, 239])
$game_map.vehicle(:airship).set_location(0, 0, 0)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "64", :relay => true)
frames(1)
relay({ "rev" => 64, "wrev" => 64, "p" => 37, "part" => "3" }, packed({ 1001 => 37, 1050 => 10 }))
frames(40)
check("a Galda gone while the player plays the world's story is back with the next story laid over", $game_map.vehicle(:airship).spot, [2, 186, 1])
$game_map.vehicle(:airship).set_location(0, 0, 0)
$game_player.vehicle = $game_map.vehicle(:airship)
MGQ_MpWorldCatchup.level_up
frames(40)
check("and one the player rides is never moved", vehicle_map.call(:airship), 0)
$game_player.vehicle = nil

# A companion the world shared comes with the story values their own join stands for.
$data_actors[540] = ActorData.new(540, "Amira", 6)
$game_variables[1009] = 0
MGQ_MpWorldCatchup.level_up
frames(40)
check("without Amira the rabbit quest stays where it is", $game_variables[1009], 0)
$game_party.add_actor(540)
MGQ_MpWorldCatchup.level_up
frames(40)
check("with Amira in the roster her information network stands at 2, so her information in the Pocket Castle opens", $game_variables[1009], 2)
$game_variables[1009] = 5
MGQ_MpWorldCatchup.level_up
frames(40)
check("and a quest further along stays", $game_variables[1009], 5)
$game_party.remove_actor(540)

# The catch-up completing the orbs plays the event that moves the story on, which only the orbs'
# events call.
tables(:KEY_ITEMS => [key_item.new(542, 1, "map:149:107:1", "2", 30, nil, [[:v, 1001, 30], [:v, 1068, 3]], true)])
new_game({ 1001 => 30 }, [], 40)
[537, 538, 540, 541].each { |id| $game_party.gain_item($data_items[id], 1) }
frames(1)
$setups = []
relay({ "rev" => 22, "wrev" => 22, "p" => 31, "part" => "2" }, packed({ 1001 => 31, 1068 => 3 }))
frames(40)
check("a player the catch-up gives the last orb plays the orbs' event",
      [$game_party.items[542], $setups.map { |list| list.map { |entry| [entry.code, entry.parameters] } }], [1, [[[117, [330]], [0, []]]]])
frames(40)
check("once", $setups.size, 1)

# A shared companion the player's own story gave them and took away for a while stays away.
tables(:REMOVALS => [removal.new(16, 16, "map:50:1:1", "1", 14, nil, [[:v, 1001, 14]], false, 5)],
       :JOINS => [join.new(16, 16, "map:70:1:1", "1", 5, nil, [[:v, 1001, 5]], 10, :start, 3, true)])
$sharing = :story
new_game({ 1001 => 16 }, [], 15)
frames(1)
relay({ "rev" => 23, "wrev" => 23, "p" => 16, "part" => "1", "comps" => "16" }, packed({ 1001 => 16 }))
frames(40)
check("a shared companion whose join the player's story passed is not brought back", roster.include?(16), false)

# A shared companion joins a second playthrough's player whose story took them away on the first.
tables(:REMOVALS => [removal.new(16, 16, "map:50:1:1", "1", 14, nil, [[:v, 1001, 14]], true, 5)],
       :JOINS => [join.new(16, 16, "map:70:1:1", "1", 20, nil, [[:v, 1001, 20]], 10, :start, 3, true)])
[[1, true], [0, false]].each do |playthrough, joins|
  new_game({ 1001 => 16, 912 => playthrough }, [], 15)
  frames(1)
  relay({ "rev" => 20, "wrev" => 20, "p" => 16, "part" => "1", "comps" => "16" }, packed({ 1001 => 16, 912 => playthrough }))
  frames(40)
  check("a shared companion #{joins ? 'joins' : 'never joins'} a player whose story passed their removal on playthrough #{playthrough}", roster.include?(16), joins)
end
$sharing = :off

# A save that noted the player behind holds their story until the world's story came.
tables
new_game({ 1001 => 7 }, [], 5)
check("a fresh game holds nothing before the world's story came", [story.mode, catchup.holds_story?], [nil, false])
frames(1)
relay({ "rev" => 24, "wrev" => 24, "p" => 25, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 25 }))
frames(16)
checkpoint("1", packed({ 1001 => 18 }))
frames(70)
story.loaded(:load)
catchup.loaded
check("a save behind on its part's checkpoint holds the story from the moment it loads", [story.mode, catchup.holds_story?], [nil, true])
$game_variables[1001] = 26
check("but not once its story is in another part", catchup.holds_story?, false)

# A player behind in the world's part goes to its story, not to a route the world finished.
check("a player behind in Part 3 after the world's return to it moves on to the world's story",
      catchup.next_part("3", "part" => "3", "done" => ["ad"], "checkpoints" => %w(1 2 3 ad)), :world)
on_mr = { "part" => "mr", "done" => ["ad"], "checkpoints" => %w(1 2 3 ad) }
check("a player in Part 3 moves on past a finished route to the world's route, an earlier one through Part 3 first",
      [catchup.next_part("3", on_mr), catchup.next_part("2", on_mr), catchup.next_part("ad", on_mr),
       catchup.next_part("3", "part" => "chaos", "done" => %w(ad mr), "checkpoints" => %w(1 2 3 ad mr))], [:world, "3", :world, :world])

# A Part 3 player skips the route the world finished, yet gets its rows as for a part passed.
tables(:REWARDS => [reward.new(:skill, 930, 1, "map:1697:7:2", "ad", 6, nil, [[:v, 1141, 6]], true)],
       :KEY_ITEMS => [key_item.new(504, 1, "map:1193:5:1", "ad", 10, nil, [[:v, 1141, 10]], true)],
       :JOINS => [join.new(80, 80, "map:1193:18:1", "ad", 6, nil, [[:v, 1141, 6]], 60, :floor, 3, true)])
new_game({ 1001 => 36 }, [], 40)
frames(1)
relay({ "rev" => 40, "wrev" => 40, "p" => 40, "r1142" => 5, "part" => "mr", "route" => "mr", "clear" => "ad", "done" => "ad", "checkpoints" => "1,2,3,ad" },
      packed({ 1001 => 40, 1142 => 5 }, [7096]))
frames(16)
checkpoint("3", packed({ 1001 => 39 }))
frames(70)
$game_actors[1].level = 65
$messages.clear
frames(40)
check("at Part 3's gate the player moves on to the world's route, never the finished one's checkpoint",
      [$messages.first, calls_of("mp_raid_checkpoint_fetch").map { |args| args[1] }], ["Level 65 reached: catching up to the world's story.", ["3\0"]])
relay({ "rev" => 40, "wrev" => 40, "p" => 40, "r1142" => 5, "part" => "mr", "route" => "mr", "clear" => "ad", "done" => "ad", "checkpoints" => "1,2,3,ad" },
      packed({ 1001 => 40, 1142 => 5 }, [7096]))
frames(40)
check("and plays the world's route", [story.mode, $game_variables[1142], $game_switches[7096]], [:world, 5, true])
check("with the skill, the key item and the companion of the finished route",
      [MGQ_MpStoryState.knows?($game_actors[1], 930), $game_party.items[504], roster.include?(80), $game_actors[80].base_level], [true, 1, true, 60])

# What a player changes while behind stays theirs under the checkpoint and the world's story, also
# when a newer story of the world comes meanwhile.
tables
new_game({ 1001 => 7 }, [], 5)
frames(1)
relay({ "rev" => 41, "wrev" => 41, "p" => 25, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 25 }))
frames(16)
$game_self_switches[[40, 2, "A"]] = true
checkpoint("1", packed({ 1001 => 18 }))
frames(70)
check("a self switch a player behind set before their checkpoint came stays under it",
      [story.mode, $game_variables[1001], $game_self_switches[[40, 2, "A"]]], [:behind, 18, true])
$game_self_switches[[40, 3, "A"]] = true
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "42", :relay => true)
frames(1)
relay({ "rev" => 42, "wrev" => 42, "p" => 26, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 26 }))
frames(40)
$game_actors[1].level = 25
frames(40)
relay({ "rev" => 42, "wrev" => 42, "p" => 26, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 26 }))
frames(40)
check("and what they set while behind stays under the world's story they move into",
      [story.mode, $game_variables[1001], $game_self_switches[[40, 2, "A"]], $game_self_switches[[40, 3, "A"]]], [:world, 26, true, true])
new_game({ 1001 => 7 }, [], 5)
frames(1)
relay({ "rev" => 43, "wrev" => 43, "p" => 25, "part" => "2" }, packed({ 1001 => 25 }))
frames(40)
$game_self_switches[[40, 4, "A"]] = true
$game_actors[1].level = 25
frames(40)
relay({ "rev" => 43, "wrev" => 43, "p" => 25, "part" => "2" }, packed({ 1001 => 25 }))
frames(40)
check("also for a player behind without a checkpoint", [story.mode, $game_variables[1001], $game_self_switches[[40, 4, "A"]]], [:world, 25, true])

# A Raid World started from a shared save: what the save's own
# story played is the player's, so its rows give nothing, take no companion and hold nothing back,
# whether the world's story starts from the save or is laid over it.
tables(:REWARDS => [reward.new(:i, 600, 2, "map:36:17:1", "1", 6, nil, [[:v, 1001, 6]])],
       :REMOVALS => [removal.new(16, 16, "map:50:1:1", "1", 14, nil, [[:v, 1001, 14]], true)],
       :JOINS => [join.new(77, 77, "map:20:1:1", "1", 9, nil, [[:v, 1001, 9]], 7, :start),
                  join.new(80, 80, "map:21:1:1", "2", 22, nil, [[:v, 1001, 22]], 20, :floor)])

# Starts a game from the shared save: its story at 25, with the Slime and the Harpy in the party.
from_save = lambda do
  new_game({ 1001 => 25 }, [4], 30)
  [77, 80].each { |id| $game_party.add_actor(id) }
end
from_save.call
frames(1)
relay({ "rev" => 0, "wrev" => 0, "p" => 0, "part" => "1" })
frames(40)
check("the first player from the save starts the world's story with it, held by nothing",
      [story.mode, $game_variables[1001], catchup.holds_story?, calls_of("mp_raid_story_post").map { |args| args[2] }], [:world, 25, false, ["p=25;r1141=0;r1142=0;r1143=0;clear=\0"]])
check("and the rows the save played give nothing, take nobody and bring nobody back",
      [$game_party.items[600].to_i, roster, $logs.grep(/the story gave the player/)], [0, [1, 77, 80], []])
from_save.call
frames(1)
relay({ "rev" => 1, "wrev" => 1, "p" => 25, "part" => "2" }, packed({ 1001 => 25 }, [4]))
frames(40)
check("the next player from the save plays the world's story at once, the save's rows still theirs",
      [story.mode, catchup.holds_story?, $game_party.items[600].to_i, roster, $logs.grep(/the story gave the player/)], [:world, false, 0, [1, 77, 80], []])

# A telling the player watched takes the key items its scene took, which only the teller's game
# ran, and one the player's own event took stays taken.
tables(:KEY_ITEMS => [key_item.new(600, 1, "map:340:23:1", "2", 29, nil, [[:v, 1001, 29], [:v, 1011, 2]], true),
                      key_item.new(600, -1, "map:88:4:1", "2", 29, nil, [[:v, 1001, 29], [:v, 1011, 4]], true)])

# Starts a game holding the key item, lets the player's story take a teller's value as watched and
# answers how many of the item the player holds then.
#
# @param value [Integer] The value of variable 1011 the teller's scene sets.
# @param before [Proc, nil] What happens before the value comes.
# @return [Integer] The items held.
watch = lambda do |value, before = nil|
  new_game({ 1001 => 29, 1011 => 3 }, [], 40)
  $game_party.gain_item($data_items[600], 1)
  frames(1)
  relay({ "rev" => 22, "wrev" => 22, "p" => 29, "part" => "2" }, packed({ 1001 => 29, 1011 => 3 }))
  frames(40)
  before.call if before
  $game_variables[1011] = value
  story.mirrored(1, 1011, value)
  frames(40)
  $game_party.items[600].to_i
end
check("a telling the player watched takes the key item its scene took, once the player is free",
      watch.call(4, lambda { catchup.watched { MGQ_MpStoryState.deep_copy(catchup.story_now) } }), 0)
check("the player's own event taking it gets nothing back from the catch-up, though the same step gave it",
      watch.call(4, lambda { $game_party.lose_item($data_items[600], 1) }), 0)

# Makina come by level, one of each, whatever chest gave them, once a player of the world got them.
makina = DATA::Makina
tables(:MAKINA => [makina.new(700, 6, "map:215:23:1"), makina.new(701, 30, "map:218:21:1")])
new_game({ 1001 => 9 }, [], 10)
$game_party.gain_item($data_items[701], 3)
frames(1)
relay({ "rev" => 30, "wrev" => 30, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("a Makina no player of the world got stays away, and copies beyond the first of one the player got go",
      [$game_party.items[700], $game_party.items[701], $game_self_switches[[0, 701, "F"]], $messages.grep(/Makina/)], [0, 1, true, []])
$game_self_switches[[0, 700, "F"]] = true
frames(40)
check("once another player got it, it comes as the player's level reaches its area level, without a notice", [$game_party.items[700], $messages.grep(/Makina/)], [1, []])
$game_self_switches[[0, 701, "F"]] = nil
$game_party.items[701] = 1
catchup.instance_variable_set(:@audit_due, true)
frames(40)
check("a Makina the player held before the world noted it counts as found on the next look, as on entering or after a load", $game_self_switches[[0, 701, "F"]], true)
$game_party.gain_item($data_items[700], 1)
frames(40)
check("a chest giving one held already leaves one", $game_party.items[700], 1)
$game_party.lose_item($data_items[701], 1)
frames(40)
check("one above the player's level does not come", $game_party.items[701], 0)
$game_actors[1].cap = 10
frames(40)
check("nor one above a cap of another mod the player is held at", $game_party.items[701], 0)
$game_actors[1].cap = 9999

# An item unlocking a job or a race any player got is the whole world's.
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 30, "wrev" => 30, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
$game_party.gain_item($data_items[600], 1)
$game_party.gain_item($data_items[616], 1)
check("a job item the player gains is noted for the world's story, another item not",
      [$game_self_switches[[0, 616, "F"]], $game_self_switches[[0, 600, "F"]], MGQ_MpStoryState.story_lists([[], [], MGQ_MpStoryState.data_of($game_self_switches)], false)["ss"]],
      [true, false, "0.616.F"])
new_game({ 1001 => 9 }, [], 1)
frames(1)
relay({ "rev" => 31, "wrev" => 31, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }, [], { [0, 616, "F"] => true }))
frames(40)
check("another player gets it with the world's story, whatever their level, without a notice",
      [$game_party.items[616], $messages], [1, []])
$game_party.gain_item($data_items[616], 1)
frames(40)
check("its chest opened afterwards leaves one", $game_party.items[616], 1)
new_game({ 1001 => 9 }, [], 10)
$game_party.items[616] = 1
MGQ_MpWorldCatchup.instance_variable_set(:@unlock_items, nil)
frames(1)
relay({ "rev" => 32, "wrev" => 32, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("one the player held before, as from an earlier version, is noted for the world on entering", $game_self_switches[[0, 616, "F"]], true)

# The skills the story and its quests teach companions reach every player's companions.
lesson = DATA::Lesson
$data_skills[544] = RPG::Skill.new(544, "Defense +10%")
$data_skills[545] = RPG::Skill.new(545, "Defense +20%")
$data_skills[592] = RPG::Skill.new(592, "Flight")
tables(:LESSONS => [lesson.new(16, 544, "map:12:64:1", "1", 12, nil, [[:v, 1001, 12], [:v, 1041, 2]], true),
                    lesson.new(16, 545, "map:645:26:1", "1", 12, nil, [[:v, 1001, 12], [:v, 1041, 3]], true),
                    lesson.new(16, 592, "map:1848:15:1", "1", 12, nil, [[:v, 1001, 12], [:v, 1041, 5]], true),
                    lesson.new(45, 544, "map:12:64:1", "1", 12, nil, [[:v, 1001, 12], [:v, 1041, 2]], true)])
new_game({ 1001 => 12 }, [], 40)
$game_party.add_actor(16)
frames(1)
relay({ "rev" => 33, "wrev" => 33, "p" => 12, "part" => "1" }, packed({ 1001 => 12, 1041 => 3 }))
frames(40)
# Lists the skills a companion learned.
#
# @param id [Integer] The companion.
# @return [Array<Integer>] The skills, sorted.
taught = lambda { |id| $game_actors[id].instance_variable_get(:@skills).sort }
check("a companion in the roster learns the skills of the quest steps the world passed before the player came, never those of a step ahead",
      taught.call(16), [544, 545])
check("one outside the roster learns nothing", taught.call(45), [])
$game_party.add_actor(45)
frames(40)
check("and learns them once they join", taught.call(45), [544])

# The classes and races the story and its quests give reach every player's characters.
class_level = DATA::ClassLevel
# Stands in for RPG::Class, a class or a race.
ClassData = Struct.new(:id, :name)
$data_classes = Array.new(400)
$data_classes[362] = ClassData.new(362, "Lowly Angel")
$data_classes[184] = ClassData.new(184, "Vampire")
$data_classes[301] = ClassData.new(301, "Fighter")
tables(:CLASS_LEVELS => [class_level.new(1, 362, 1, "map:128:59:1", "1", 17, nil, [[:v, 1001, 17]], true),
                         class_level.new(1, 184, 1, "map:477:162:1", "1", 20, nil, [[:v, 1001, 20]], true),
                         class_level.new(45, 301, 10, "map:835:6:1", "1", 13, nil, [[:v, 1001, 13]], true)])
new_game({ 1001 => 17 }, [], 40)
$game_actors[45].level_list[301] = 3
frames(1)
relay({ "rev" => 34, "wrev" => 34, "p" => 17, "part" => "1" }, packed({ 1001 => 17 }))
frames(40)
check("Luka gets the race of a story step the world passed before the player came, never one of a step ahead",
      [$game_actors[1].level_list[362], $game_actors[1].level_list[184]], [1, nil])
check("a companion outside the roster gets nothing", $game_actors[45].level_list[301], 3)
$game_party.add_actor(45)
frames(40)
check("and gets the class at its level once they join", $game_actors[45].level_list[301], 10)

# The World overview's Unlocks page lists what the catch-up hands out by level that the world
# unlocked.
tables(:JOINS => [join.new(77, 77, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], 7, :start, 1, true),
                  join.new(16, 16, "map:9:1:1", "1", 15, nil, [[:v, 1001, 15]], 20, :floor, 1, true)],
       :MAKINA => [makina.new(700, 6, "map:215:23:1"), makina.new(701, 30, "map:218:21:1")])
$sharing = :all
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 31, "wrev" => 31, "p" => 9, "part" => "1", "comps" => "80" }, packed({ 1001 => 9 }))
$game_self_switches[[0, 700, "F"]] = true
frames(40)
check("the Levels page lists by level the Makina a player of the world got, the companions of joins the world's story got past and those it shares, never a join it has not reached",
      catchup.unlocks.map { |unlock| [unlock.level, unlock.kind, unlock.name, unlock.got, unlock.due] },
      [[6, :makina, "Auto Crossbow", true, false], [7, :companion, "Slime", true, false], [9, :companion, "Harpy", true, false]])
check("with the level the catch-up counts", catchup.counted_level, 10)
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 32, "wrev" => 32, "p" => 25, "part" => "2", "comps" => "80" }, packed({ 1001 => 25 }))
frames(40)
check("a world past the player's part lists moving on from it at its gate",
      catchup.unlocks.select { |unlock| unlock.kind == :story }.map { |unlock| [unlock.level, unlock.name, unlock.got, unlock.due] }, [[25, "Part 1", false, false]])
$sharing = :off

# A join the story takes back in the same step only brings its companion along for a visit, in the
# generated tables as in rows of the tests' own.
tables(:JOINS => REAL_JOINS, :REMOVALS => REAL_REMOVALS)
visit = lambda { |actor, site| catchup.temporary?(REAL_JOINS.find { |row| row.actor == actor && row.site == site }) }
check("Alma Elma's Part 2 visits are temporary, her Part 1 join and her return in Part 2 last",
      [visit.call(19, "map:483:86:1"), visit.call(19, "map:735:18:1"), visit.call(19, "map:111:21:3"), visit.call(19, "map:291:23:1")], [true, true, false, false])
check("as are a guest of one event and the Chaos route's final lineup, while Granberia's last Chaos join lasts",
      [visit.call(523, "map:1063:77:1"), visit.call(713, "map:1752:37:1"), visit.call(16, "ce:9106")], [true, true, false])
check("Ilias and Alice last wherever they join", [visit.call(26, "map:6:31:2"), visit.call(29, "map:1752:37:1"), visit.call(5, "map:6:30:2")], [false, false, false])
tables(:JOINS => [join.new(77, 77, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], 7, :start, 1, true),
                  join.new(16, 16, "map:6:40:1", "1", 7, nil, [[:v, 1001, 7], [:v, 1050, 1]], 8, :start, 5, true)],
       :REMOVALS => [removal.new(16, 16, "map:6:41:1", "1", 7, nil, [[:v, 1001, 7], [:v, 1050, 2]], true, 3)])
new_game({ 1001 => 9, 1050 => 1 }, [], 10)
$game_party.add_actor(16)
$game_actors[16].level = 50
frames(1)
relay({ "rev" => 33, "wrev" => 33, "p" => 9, "part" => "1" }, packed({ 1001 => 9, 1050 => 1 }))
frames(40)
check("a companion on a visit is not listed, nor counted toward the player's level",
      [catchup.unlocks.map { |unlock| [unlock.kind, unlock.name] }, catchup.counted_level], [[[:companion, "Slime"]], 10])
check("nor counted in the catch-up", [catchup.counts?($game_actors[16]), catchup.counts?($game_actors[1])], [false, true])
$game_party.remove_actor(16)
new_game({ 1001 => 9, 1050 => 1 }, [], 10)
frames(1)
relay({ "rev" => 34, "wrev" => 34, "p" => 9, "part" => "1" }, packed({ 1001 => 9, 1050 => 2 }))
frames(40)
check("and a player the world's story carried past the visit does not get the companion", roster.include?(16), false)

# Classic worlds have no catch-up.
$raid = false
new_game({ 1001 => 3 }, [], 99)
frames(40)
check("a Classic world holds no story and fetches no checkpoint", [catchup.holds_story?, calls_of("mp_raid_checkpoint_fetch")], [false, []])
