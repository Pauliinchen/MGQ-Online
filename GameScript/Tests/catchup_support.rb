#----------------------------------------------------------------
#  catchup_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Dropped the stand-in of the base form, which no screen builds
#      Paulinchen  2026-11-05: Answered the DLL's catch-up topics with the fixed values each test sets instead of from the catch-up engine of engine.rb, and dropped the tables of rows
#                            - Gave the items and skills an icon, which the Unlocks page reads
#                            - Answered the rewards tables with fixed fields instead of a stand-in of their constants
#                            - Took the recorded Classic party's table for the world's story mapping
#                            - Wrote a story's keys as the rows the DLL hands the scripts
#                            - Stood in for the shared companions through the DLL's topics
#                            - Answered the side a player takes along by engine.rb's rule of the side
#                            - Let a test put the Medal King's switches and the items an event takes away in place
#                            - Stopped loading story_found.rbx, whose items the story replay hands over
#                            - Dropped the stand-in of the game's frame counter, which no script reads
#      Paulinchen  2026-11-01: Dropped the stand-in of the form window no script draws with any more
#                            - Made the herb no key item and loaded story_found.rbx
#                            - Answered that the player plays in no party
#                            - Took an item through its gain of less than none, as the game does
#      Paulinchen  2026-10-31: Dropped the maps where warping is free
#                            - Told the place where the world's log starts with the world's summary
#      Paulinchen  2026-10-28: Read the generated tables from fixtures/catchup/generated in place of the deleted world_catchup_data.rbx
#                            - Answered the DLL's catch-up topics from the catch-up engine over the tests' tables, and recorded its answers
#                            - Created
#
#----------------------------------------------------------------

# The game a Raid World's catch-up runs in, for the script tests: stand-ins of the game's objects,
# the players, the world and the message window, the real story_state.rbx, coop_story.rbx,
# coop_choices.rbx, world_story.rbx and world_catchup.rbx on the DLL's story topics
# (story_support.rb) and its catch-up topics answered with the fixed values each test sets
# (CatchupAnswers), and helpers that start a game, hand the relay's tracks over and run frames.

require_relative "support"
require_relative "story_support"

$logs = []
# Stands in for the mod's log: records each line in $logs and prints it.
module MGQ_Multiplayer; module Log; def self.write(m); $logs << m; puts "  log: #{m}"; end; end; end
$calls = []
$raid_story = {}
$notices = []
$messages = []
$raid = true
$sharing = :off
$telling = false

# Stands in for Multiplayer.rb around the DLL link.
module MGQ_Multiplayer
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
  # Answers that the player plays in no party.
  def self.in_party?; false; end
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
end
MGQ_MpWorld.world = MGQ_MpWorld::World.new("w1")
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
# Stands in for RPG's database classes.
module RPG
  # Stands in for an event command.
  EventCommand = Struct.new(:code, :indent, :parameters)
  # Stands in for a common event.
  CommonEvent = Struct.new(:list)
  # An item of the database.
  class Item
    attr_reader :id, :name, :description
    # Takes the item's id, name, description and whether it is a key item.
    def initialize(id, name, description = "", key = true); @id = id; @name = name; @description = description; @key = key; end
    # Answers whether the item is a key item.
    def key_item?; @key; end
    # Answers the item's icon, the first.
    def icon_index; 0; end
  end
  # Stands in for a skill, with the first icon.
  Skill = Struct.new(:id, :name) { def icon_index; 0; end }
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
 [541, "Green Orb"], [542, "Silver Orb"], [557, "Remina Key Card"], [700, "Auto Crossbow"], [701, "Bio Blaster"]].each { |id, name| $data_items[id] = RPG::Item.new(id, name) }
$data_items[600] = RPG::Item.new(600, "Herb", "[Item] Restores HP.", false)
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
  # Adds an item, or takes it down to none for an amount below 0.
  def gain_item(item, amount); @items[item.id] = [@items[item.id] + amount, 0].max; end
  # Takes an item through its gain, as the game does.
  def lose_item(item, amount); gain_item(item, -amount); end
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

# Answers the DLL's catch-up topics with the values a test sets, noting each request.
class CatchupAnswers
  include NotedRequests

  # The topics answered.
  TOPICS = %w(catchup.keys catchup.check catchup.note catchup.hold_join catchup.unlocks catchup.side).freeze

  # What the catch-up reads, as catchup.keys answers it while a test sets nothing: some keys of the
  # story, three items, two Makina, three parts with their gates and the orbs' common event.
  KEYS = {
    "switches" => [4, 5, 500, 2023, 7096], "variables" => [1001, 1002, 1009, 1032], "selves" => [[30, 4, "A"]], "items" => %w(i501 i502 i600), "makina" => [700, 701],
    "parts" => [["1", "Part 1", 25], ["2", "Part 2", 55], ["3", "Part 3", 65]], "orb_event" => 330,
  }.freeze

  # What a topic answers while a test sets nothing: nothing to carry out, a join that goes, no unlock.
  DEFAULTS = {
    "catchup.keys" => KEYS, "catchup.check" => { "actions" => [] }, "catchup.note" => { "actions" => [] }, "catchup.hold_join" => { "actions" => [] },
    "catchup.unlocks" => { "unlocks" => [] }, "catchup.side" => nil,
  }.freeze

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @asked = []
    @answers = {}
    @queued = Hash.new { |queues, topic| queues[topic] = [] }
    TOPICS.each { |topic| fake.answer(topic) { |request| note(topic, request) && answer(topic, request) } }
  end

  # Sets what a topic answers from now on.
  #
  # @param topic [String] The topic.
  # @param value [Object] The answer, unless a block gives it.
  # @yieldparam request [Object] The request.
  # @yieldreturn [Object] The answer.
  def set(topic, value = nil, &block)
    @answers[topic] = block || value
  end

  # Sets what the next calls of a topic answer, each once, before what set gives.
  #
  # @param topic [String] The topic.
  # @param answers [Array<Object>] The answers, in order.
  def queue(topic, *answers)
    @queued[topic].concat(answers)
  end

  # Forgets the answers set and the requests noted.
  def clear
    @asked.clear
    @answers.clear
    @queued.clear
  end

  private

  # Answers a request.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Object] The answer.
  def answer(topic, request)
    return @queued[topic].shift unless @queued[topic].empty?

    found = @answers.key?(topic) ? @answers[topic] : DEFAULTS[topic]
    found.respond_to?(:call) ? found.call(request) : found
  end
end

$fake = open_rules_bridge
answer_story($fake)
# The rewards tables: two chests and one chest flag.
answer_party_rewards($fake, "chests" => [[12, 3, "A"], [30, 4, "A"]], "chest_flags" => [7102])
load_script "story_state"
load_script "coop_story"
load_script "coop_choices"
load_script "world_story"
load_script "world_catchup"
# The world's story mapping: what the Raid personal lists of earlier builds shared, the chest flags
# each player's own.
$classes = listed_raid_table_hash
# The DLL's catch-up topics.
$answers = CatchupAnswers.new($fake)

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
  $answers.clear
  MGQ_MpCoopChoices.forget("next check")
  MGQ_MpWorldStory.loaded(:load)
  MGQ_MpWorldCatchup.loaded
end

# Writes a story's keys as the DLL hands the scripts the relay's track (StoryPlain).
#
# @param variables [Hash] Variables by id.
# @param switches [Array<Integer>] Switches on.
# @param selfs [Hash] Self switches by key.
# @return [Array<Array>] Each key's kind, key and value.
def packed(variables = {}, switches = [], selfs = {})
  switches.map { |id| [0, id, true] } + variables.map { |id, value| [1, id, MGQ_MpStoryState.plain_variable(value)] } +
    selfs.map { |key, value| [2, key, value ? true : false] }
end

# Hands the game the world's track as the DLL does after the relay sent it, with the world's
# summary, and the shared companions the DLL's state names.
#
# @param fields [Hash] The world's summary and companions that differ from an empty story: "rev",
#   "part", "route", "done" and "checkpoints" (each separated by commas), "comps", "start" (the
#   story markers where the world's log starts) and "log" (the keys where it starts that differ
#   from the track's).
# @param keys [Array<Array>] The track's keys, see packed.
def relay(fields, keys = {})
  world = { "rev" => 1, "part" => "1", "route" => "none", "done" => "", "checkpoints" => "", "comps" => "" }.merge(fields)
  hand_track(world, keys, "track" => "world", "part" => world["part"].to_s)
end

# Hands the game the track of their own the relay put a player behind on: their part's checkpoint.
#
# @param part [String] The part.
# @param keys [Array<Array>] The checkpoint's keys, see packed.
# @param fields [Hash] The world's summary, as relay takes it.
def checkpoint(part, keys, fields = {})
  world = { "rev" => 1, "part" => "2", "route" => "none", "done" => "", "checkpoints" => part, "comps" => "" }.merge(fields)
  hand_track(world, keys, "why" => "behind", "track" => "t1", "part" => part, "gate" => MGQ_MpWorldCatchup.gate_of(part))
end

# Hands the game the track the relay moved a player behind on to by their level.
#
# @param from [String] The part they leave.
# @param to [String] The part they move to, or "world".
# @param keys [Array<Array>] The track's keys, see packed.
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
# @param keys [Array<Array>] The track's keys, see packed.
# @param state [Hash] The state's fields that differ, see track_take.
def hand_track(world, keys, state)
  list = lambda { |text| text.to_s.split(",") }
  summary = { "rev" => world["rev"], "part" => world["part"].to_s, "route" => world["route"].to_s, "done" => list.call(world["done"]), "checkpoints" => list.call(world["checkpoints"]),
              "start" => world["start"] }
  $takes << track_take(keys, world["log"] ? state.merge("log" => world["log"]) : state, world["rev"])
  $fake.post("story.status", story_status("track" => state["track"], "part" => state["part"], "gate" => state["gate"], "rev" => world["rev"], "world" => summary, "pending" => true))
  $raid_story = { "world" => "w1", "rev" => world["rev"], "comps" => list.call(world["comps"]).map(&:to_i), "fetch" => "done", "companions" => world["companions"] }
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
