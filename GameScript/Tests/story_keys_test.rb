#----------------------------------------------------------------
#  story_keys_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Checked that a talk that gives a key item goes to the DLL with it, though it changed no shared key
#                            - Checked that a story reset that takes the route's key items notes none of them
#                            - Dropped the stand-in of the game's frame counter, which no script reads
#                            - Checked that a battle's drop of a key item goes to the DLL with it, and its entry on to the world's story
#      Paulinchen  2026-11-01: Checked which commands run inside a story reset
#      Paulinchen  2026-10-31: Kept a Classic leader's writes by the scopes of the reviewed list
#                            - Checked that a run that changed a world key goes to its story's stream, and its entry to the world's or the party's story
#      Paulinchen  2026-10-28: Checked that a Classic party's table is asked of the DLL with nothing of the scripts' own
#                            - Checked that a Classic party's table is built anew once the chest flags came
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Covers story_keys.rbx with story_state.rbx: the story mapping's table as the DLL hands it, looked
# up as the relay's tracks look keys up (fixtures/story/classes.json), and the one hook on the
# game's writes: which writes a story records, with the event that wrote them, which it never
# records (the multiplayer's own, a lost battle's defeat scene, another object's), one batch a
# frame for the DLL, the commands that run inside a story reset, the writes before the mapping
# came, a Classic leader's writes, a Classic party's table built anew once the chest flags came, the
# stream a run that changed a world key goes to with where its entry is handed, and a battle's drops.

require_relative "support"
require_relative "story_support"

# Stands in for the mod's log: prints each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$raid = true

# Stands in for co-op: a Raid World while $raid.
module MGQ_MpCoop; module Scope; def self.raid?; $raid; end; end; end
# Stands in for the co-op events: no chest on the map.
module MGQ_MpCoopEvents; def self.chest_key?(_key); false; end; def self.chest_keys; []; end; end
# Stands in for the world's story: no frozen fight holds a key.
module MGQ_MpWorldStory; def self.held_value(_kind, _key, value); value; end; end
# Stands in for the party's story: the Classic leader's writes handed over, in $recorded.
module MGQ_MpCoopStory; def self.recorded(batch); ($recorded ||= []) << batch; end; end

# Stands in for the game's switches, off unless set.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's variables, 0 unless set.
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's self switches, off unless set on.
class Game_SelfSwitches; def initialize; @data = {}; end; def [](key); @data[key] == true; end; def []=(key, value); @data[key] = value; end; end

# Stands in for the event interpreter: its update runs the block it was set up with, each command
# the block runs goes through execute_command.
class Game_Interpreter
  # Sets up commands for a map event or a common event.
  def setup(list, event_id = 0, map_id = 7); @list = list; @event_id = event_id; @map_id = map_id; end

  # Runs the block given as the interpreter's frame.
  def update; @frame.call(self) if @frame; end

  # Takes the block of the next frame.
  def frame=(block); @frame = block; end

  # Runs a command's block.
  def execute_command; @command.call; end

  # Runs a block as one command.
  def run(&block); @command = block; execute_command; end
end
# Stands in for a map event and its pages.
class Game_Event
  # Makes an event with its pages' lists.
  def initialize(lists); @lists = lists; end

  # Lists the event's pages.
  def mgq_mp_pages; @lists.map { |list| Struct.new(:list).new(list) }; end
end
# Stands in for the map, map 7 with event 39.
class Game_Map; attr_accessor :map_id, :events; end
# Stands in for the troop, with its interpreter.
class Game_Troop; attr_accessor :interpreter; end
# Stands in for the scene manager and the novel scene of a lost battle's defeat; its run starts the game.
module SceneManager; class << self; attr_accessor :scene; def run; end; end; end
# Stands in for the battle manager: its drops run the block in $drop_items.
module BattleManager; def self.gain_drop_items; $drop_items.call; end; end
class Scene_Novel; end
# Stands in for the frame counter.
# A common event of the database.
CommonEvent = Struct.new(:id, :list)
# The game's system data, with the names of the switches and variables.
System = Struct.new(:switches, :variables)
$data_system = System.new(Array.new(8000, ""), Array.new(4000, ""))
$data_actors = Array.new(600)
$data_common_events = []
$data_common_events[1] = CommonEvent.new(1, [:ce1])
$data_common_events[154] = CommonEvent.new(154, [:ce154])

load_script "story_state"
fake = open_rules_bridge
answer_story(fake)
keys = MGQ_MpStoryKeys

# The story mapping's table as the DLL hands it: each key the kind the relay's tracks give it.
names = lambda do |kind, found|
  next "freeze" if kind == 3
  next "count" if found & keys::COUNT != 0
  next "one_way" if found & keys::ONE_WAY != 0
  next "shared" if found & keys::KEPT != 0
  next "scene" if found & keys::SCENE != 0

  found & keys::CHEST != 0 ? "chest" : "personal"
end
table = keys.table_of(classes_fixture_table)
cases = JSON.parse(File.read(File.join(STORY_FIXTURES, "classes.json")))["cases"]
found = cases.map do |entry|
  kind, key = keys.key_of(entry["key"])
  [entry["key"], entry["site"], names.call(kind, kind == 3 ? 0 : keys.class_of(kind, key, entry["site"], table))]
end
check("each key of the mapping's table is shared as the relay's tracks share it", found, cases.map { |entry| [entry["key"], entry["site"], entry["kind"]] })
check("the table lists the switches and variables kept and the local steps", [table.kept_switches, table.kept_variables, table.local_steps[1052]],
      [[31, 7096], [1001, 1052, 1062, 1141, 1354, 3005], [[3, 4, 5], 2, [[484, 30], [483, 0]]]])

# A Raid World's story records the writes of the keys its mapping keeps, with the event that wrote
# them, and nothing else.
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_self_switches = Game_SelfSwitches.new
$game_map = Game_Map.new
$game_map.map_id = 7
pages = [[:first], [:second]]
$game_map.events = { 39 => Game_Event.new(pages) }
$game_troop = Game_Troop.new
$game_troop.interpreter = Game_Interpreter.new
$game_troop.interpreter.setup([:troop])
keys.instance_variable_set(:@raid, table)
keys.recording = :raid
event = Game_Interpreter.new
event.setup(pages[1], 39)
common = Game_Interpreter.new
common.setup($data_common_events[154].list, 0)
event.frame = lambda do |interpreter|
  interpreter.run do
    $game_switches[7096] = true
    $game_switches[8] = true
    $game_variables[1001] = 12
    $game_self_switches[[7, 39, "A"]] = true
    $game_self_switches[[7, 40, "A"]] = true
  end
end
event.update
common.frame = lambda { |interpreter| interpreter.run { $game_variables[1141] = 0 } }
common.update
$game_troop.interpreter.frame = lambda { |interpreter| interpreter.run { $game_variables[1052] = 3 } }
$game_troop.interpreter.update
$game_variables[3005] = 40
keys.as("catchup") { $game_switches[7102] = true }
keys.flush
MGQ_Multiplayer::Bridge.frame
check("the frame's writes go to the DLL as one batch, each with where it came from: the map event's page, the common event, the troop or the game",
      staged("story.writes"),
      [[["s7096", "1", "map:7:39:2"], ["v1001", "n12", "map:7:39:2"], ["ss7.39.A", "1", "map:7:39:2"], ["v1141", "n0", "ce:154"],
        ["v1052", "n3", "game:troop"], ["v3005", "n40", "game"], ["s7102", "1", "game:catchup"]]])

# What the story never records: the multiplayer's own writes, a lost battle's defeat scene, the
# writes of another object than the game's own.
$story_staged.clear
keys.applying { $game_variables[1001] = 13 }
SceneManager.scene = Scene_Novel.new
$game_variables[1001] = 3
SceneManager.scene = nil
Game_Variables.new[1001] = 14
keys.flush
MGQ_Multiplayer::Bridge.frame
check("nor the multiplayer's own writes, a lost battle's defeat scene's or another object's", [staged("story.writes"), keys.applying?], [[], false])

# The Final Chapter's reset writes about 1,900 keys in one frame: one batch takes them.
reset = keys.table_of(story_table_hash([[0, 5200, 1]], [[0, 1500, 1]], 0, "rev" => 2))
keys.instance_variable_set(:@raid, reset)
common.frame = lambda do |interpreter|
  interpreter.run do
    (2444..4047).each { |id| $game_switches[id] = false }
    (839..1119).each { |id| $game_variables[id] = 0 }
  end
end
common.update
keys.flush
MGQ_Multiplayer::Bridge.frame
check("the Final Chapter's reset of 1,885 writes goes as one batch", [staged("story.writes").size, staged("story.writes")[0].size, staged("story.writes")[0][0][2]], [1, 1885, "ce:154"])

# A wait inside a command leaves the update with the command running: another interpreter's write
# meanwhile names that one, the rest of the command its own.
$story_staged.clear
waiting = Game_Interpreter.new
waiting.setup(pages[0], 39)
waiting.frame = lambda { |interpreter| MGQ_MpStoryKeys.executing(interpreter) }
waiting.update
common.frame = lambda { |interpreter| interpreter.run { $game_switches[30] = true } }
common.update
waiting.frame = lambda do |interpreter|
  $game_switches[31] = true
  MGQ_MpStoryKeys.executed(interpreter)
end
waiting.update
keys.flush
MGQ_Multiplayer::Bridge.frame
check("a command a wait left running names its own event once it goes on, another's write meanwhile names that one",
      staged("story.writes"), [[["s30", "1", "ce:154"], ["s31", "1", "map:7:39:1"]]])

# The writes before the mapping came wait, and the mapping sorts them once it comes.
$story_staged.clear
keys.forget_raid
event.update
keys.flush
MGQ_Multiplayer::Bridge.frame
before = staged("story.writes")
$classes = classes_fixture_table
keys.load_raid
keys.flush
MGQ_Multiplayer::Bridge.frame
check("the writes before the story mapping came wait, and go by the mapping once it came",
      [before, staged("story.writes")], [[], [[["s7096", "1", "map:7:39:2"], ["v1001", "n12", "map:7:39:2"], ["ss7.39.A", "1", "map:7:39:2"]]]])

# A Classic party's leader hands the party's story the writes the reviewed list makes the world's,
# by the scopes the DLL builds of it.
$raid = false
module MGQ_MpOverworldSync; def self.in_world?; true; end; end
fake.answer("story.replay_scopes") do |_request|
  switches = "\0" * 8000
  switches.setbyte(7096, keys::SCOPE_WORLD)
  variables = "\0" * 4000
  variables.setbyte(1001, keys::SCOPE_WORLD)
  { "switches" => switches, "variables" => variables, "keys" => {}, "self" => {}, "index" => [], "self_default" => keys::SCOPE_WORLD }
end
$story_staged.clear
keys.recording = :classic
event.frame = lambda do |interpreter|
  interpreter.run do
    $game_switches[100] = true
    $game_switches[7096] = true
    $game_variables[3001] = 20
    $game_variables[1001] = 15
    $game_self_switches[[7, 39, "B"]] = true
  end
end
event.update
keys.flush
check("a Classic leader's writes go to the party's story, those each player keeps their own left out",
      [$recorded, staged("story.writes")], [[[["s7096", "1", "map:7:39:2"], ["v1001", "n15", "map:7:39:2"], ["ss7.39.B", "1", "map:7:39:2"]]], []])
keys.recording = nil
$game_switches[7096] = false
keys.flush
check("and none once the party's story records no more", $recorded.size, 1)

# A Classic party's table is the DLL's, built with the chest flags of the mapping it holds: asked
# with nothing of the scripts' own, kept while the rewards a party member catches up with stay, and
# asked again once they changed, since the DLL then holds another mapping.
requests = []
flags = [2045]
fake.answer("story.classic_table") { |request| requests << request; classic_table_hash(classic_request.merge("chest_flags" => flags)) }
keys.instance_variable_set(:@classic, nil)
keys.instance_variable_set(:@classic_asked, false)
first = keys.bridge_classic_table
kept = keys.bridge_classic_table
flags = [7102]
fake.answer("story.rewards") { |_known| CatchupRelayRows.party_rewards(nil).merge("chest_flags" => flags, "rev" => 1) }
rewards_changed
MGQ_MpStoryState.rewards
later = keys.bridge_classic_table
check("a Classic party's table is asked of the DLL with no request, kept while the rewards stay and asked again once they changed",
      [requests, first.switches.getbyte(2045), kept.equal?(first), later.switches.getbyte(2045), later.switches.getbyte(7102)], [[nil, nil], 8, true, 1, 8])

# A run of the player's own game that changed a world key is logged with the DLL, which decides by
# the events database whether it gives, and its entry goes on by its story: a Raid World's to the
# world's story, on the track the player plays; a Classic world's to the co-op events, on the
# leader's story or the player's own while they lead it.
module MGQ_MpWorldStory; def self.track; $track; end; def self.hand_entry(entry); $world_handed << entry; end; end
module MGQ_MpCoopEvents; def self.hand_entry(entry); $coop_handed << entry; end; end
module MGQ_MpCoopStory; def self.leader; $leader; end; def self.guest?; false; end; end
module MGQ_MpCoop; def self.in_party?; false; end; end
module MGQ_MpOverworldSync; def self.in_world?; true; end; module Me; def self.id; "me1"; end; end; end
Peer = Struct.new(:state)
$world_handed = []
$coop_handed = []
world_switches = "\0" * 8000
world_switches.setbyte(300, keys::SCOPE_WORLD)
fake.answer("story.replay_scopes") { |_request| { "switches" => world_switches, "variables" => "\0" * 4000, "keys" => {}, "self" => {}, "index" => [], "self_default" => 0 } }
fake.answer("story.replay_reads") { |_request| [] }
fake.answer("story.replay_reset") { |_request| nil }
ran = []
fake.answer("story.replay_ran") { |request| ran << request; { "id" => "e#{ran.size}", "site" => request["site"], "scope" => "world", "stream" => request["stream"] } }
story_run = lambda do
  keys.instance_variable_set(:@scopes, nil)
  story = Game_Interpreter.new
  story.setup(pages[0], 39)
  story.run { $game_switches[300] = !$game_switches[300] }
end
$raid = true
$track = "t2"
story_run.call
$raid = false
$leader = Peer.new({ "id" => "lead1" })
story_run.call
$leader = :me
story_run.call
check("a run that changed a world key goes to its story's stream: the player's own track in a Raid World, the leader's story in a Classic party, their own while they lead",
      ran.map { |request| [request["site"], request["stream"], request["owner"], request["changed"].keys] },
      [["map:7:39:1", "t2", false, ["s300"]], ["map:7:39:1", "story:lead1", false, ["s300"]], ["map:7:39:1", "story:me1", true, ["s300"]]])
check("and its entry is handed on: a Raid World's to the world's story, a Classic world's to the co-op events",
      [$world_handed.map { |entry| entry["id"] }, $coop_handed.map { |entry| entry["id"] }], [["e1"], ["e2", "e3"]])

# A run that gives a key item and changed no shared key still goes to the DLL with the found item,
# so the replay hands it to every player (user decision 2026-11-04); a Small Medal, which the game
# tags as a plain item, makes no run of its own.
module RPG; class Item < Struct.new(:id, :key, :description); def key_item?; key; end; end; end
$game_party = Object.new
def $game_party.item_number(item); ($held ||= Hash.new(0))[item.id]; end
pass = RPG::Item.new(613, true, "[Key Item] A pass to the Colosseum.")
medal = RPG::Item.new(32, true, "[Item] Small medals are scattered all over the world.")
$raid = true
ran.clear
[pass, medal].each do |item|
  keys.instance_variable_set(:@scopes, nil)
  talk = Game_Interpreter.new
  talk.setup(pages[0], 39)
  talk.run { keys.executing(talk); keys.item_changing(item, 1) { $held[item.id] += 1 }; keys.executed(talk) }
end
check("a talk that gives a key item goes to the DLL with it and no shared key, one that gives a Small Medal not",
      ran.map { |request| [request["site"], request["stream"], request["changed"], request["found"]] }, [["map:7:39:1", "t2", {}, [[613, 1]]]])

# The return to the Great Decision runs the Final Chapter's reset (common event 154, which turns
# switches 2444 to 2484 off and takes the route's key items, as the Warp Stone): the player's own
# stone goes, but the run notes no found item, so it uses up no other player's.
command = Struct.new(:code, :indent, :parameters)
stone = RPG::Item.new(568, true, "[Key Item] Teleports to a place.")
$held[568] = 1
ran.clear
keys.instance_variable_set(:@scopes, nil)
great = Game_Interpreter.new
great.setup(pages[0], 39)
great.run do
  final = Game_Interpreter.new
  final.setup([command.new(121, 0, [2444, 2484, 1]), command.new(126, 0, [568, 1, 0, 1])], 0)
  final.run { keys.item_changing(stone, -1) { $held[568] -= 1 } }
end
check("a story reset that takes a route key item notes no found item", [$held[568], ran], [0, []])

# A battle's drop of a key item reaches every player too (user decision 2026-11-05): once the game
# runs, the drops go to the DLL with the found items alone, the Small Medal left out, and their
# entry is handed on to the world's story as a run's is.
drops = []
fake.answer("story.replay_drop") { |request| drops << request; { "id" => "d1", "site" => "game:drop", "scope" => "world", "stream" => request["stream"] } }
$raid = true
$world_handed.clear
SceneManager.run
$drop_items = lambda { [pass, medal].each { |item| keys.item_changing(item, 1) { $held[item.id] += 1 } } }
BattleManager.gain_drop_items
check("a battle's drop of a key item goes to the DLL with it alone, and its entry to the world's story",
      [drops.map { |request| [request["party"], request["stream"], request["found"]] }, $world_handed.map { |entry| entry["id"] }], [[[false, "t2", [[613, 1]]]], ["d1"]])
