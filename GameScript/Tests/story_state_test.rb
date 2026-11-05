#----------------------------------------------------------------
#  story_state_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Dropped the checks of unpacking a story, which the DLL does
#                            - Answered the side the player took along with fixed values and checked what goes to the DLL and what the scripts note
#                            - Answered what a Classic member takes of a joined story by the DLL's rule
#                            - Dropped the stand-in of the game's frame counter, which no script reads
#      Paulinchen  2026-11-01: Covered the side the save notes the player took along in Iliasville
#      Paulinchen  2026-10-31: Covered a Classic party's join of stories by the reviewed list's scopes
#                            - Covered the one-time repair of a save the 0.6.9.2 chest path left stuck
#      Paulinchen  2026-10-24: Covered the second accessory slot a story written past the game turns on
#      Paulinchen  2026-10-12: Covered unpacking a packed story and its refusals
#      Paulinchen  2026-10-10: Created
#
#----------------------------------------------------------------

# Covers story_state.rbx: mixing a story with the player's own chests, the skills and companions a
# story grants, the one-time repair of a stuck save, and the side the save notes the player took
# along in Iliasville.

require_relative "support"

# Stands in for the mod's log: records each line in $log and answers with a byte count, as
# File#write does.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; 87; end; end; end
$log = []
# Stands in for the battle scope: a Raid World unless $classic.
module MGQ_MpCoop; module Scope; def self.raid?; !$classic; end; end; end
# Stands in for the shared events: no event is a chest.
module MGQ_MpCoopEvents; def self.chest_keys; []; end; def self.chest_key?(_key); false; end; end
# Stands in for RPG::Actor.
ActorData = Struct.new(:id, :name)
# Stands in for RPG::Skill.
SkillData = Struct.new(:id, :name)
$data_actors = Array.new(100)
[[1, "Luka"], [16, "Granberia"], [45, "Tamamo"]].each { |id, name| $data_actors[id] = ActorData.new(id, name) }
$data_skills = Array.new(1000)
[[930, "Angel Dance"], [937, "Demon Decapitation"]].each { |id, name| $data_skills[id] = SkillData.new(id, name) }

# Stands in for an actor, whose learned skills the game keeps in @skills.
class Game_Actor
  attr_reader :id
  # Starts the actor with no skills.
  def initialize(id); @id = id; @skills = []; end
  # Records a learned skill.
  def learn_skill(id); @skills |= [id]; end
end
# Stands in for the game's actors by id.
class Game_Actors
  # Starts with no actor made.
  def initialize; @data = {}; end
  # Answers the actor of an id, made on first use, or nil for one $data_actors lacks.
  def [](id); $data_actors[id] ? (@data[id] ||= Game_Actor.new(id)) : nil; end
end
# Stands in for the party: its own companions in @include_actors, the team of up to two in @actors.
class Game_Party
  # Starts the party empty.
  def initialize; @include_actors = []; @actors = []; end
  # Adds a companion to the roster and the team.
  def add_actor(id); add_stand_actor(id); @actors |= [id]; end
  # Adds a companion to the roster only.
  def add_stand_actor(id); @include_actors |= [id]; end
  # Answers whether the team holds two.
  def party_member_full?; @actors.size >= 2; end
  # Answers the team's actors.
  def all_members; @actors.map { |id| $game_actors[id] }; end
end

load_script "story_state"
state = MGQ_MpStoryState
$game_actors = Game_Actors.new
$game_party = Game_Party.new
$game_party.add_actor(1)
$game_party.add_actor(16)
$game_actors[1].learn_skill(937)

# Mixing a story with the player's own takes the chests from the player's story and drops those
# it lacks.
chests = (1..5100).map { |event| [100 + event / 100, event, "A"] }
opened = chests[7]
shut_by_story = chests[8]
others = chests[9]
kept_shut = chests[10]
story = [[], [], { [3, 1, "A"] => true, others => true, shut_by_story => false, kept_shut => true }]
personal = [[], [], { opened => true, shut_by_story => true, kept_shut => false }]
mixed = state.mix(story, personal, chests)
check("a chest the player opened stays open, also one the story has shut, and the story's own self switches stay",
      [mixed[2][opened], mixed[2][shut_by_story], mixed[2][[3, 1, "A"]]], [true, true, true])
check("a chest the player holds shut stays shut, as a key of its own", [mixed[2].key?(kept_shut), mixed[2][kept_shut]], [true, false])
check("and a chest the player never opened is left out, not written as an empty key", [mixed[2].key?(others), mixed[2].size], [false, 4])

# In a Classic party the DLL's rule of what a member takes of the leader's story decides what a
# join of stories keeps (ClassicMerge.Follows, which stands in here by the keys the leader's story
# holds): the leader's world keys come, while the rest stays the player's.
require_relative "bridge_support"
fake = FakeBridge.new
MGQ_Multiplayer::Bridge.open(fake)
$data_system = Struct.new(:switches, :variables).new(Array.new(5000), Array.new(5000))
world_keys = { [1, 1001] => true, [2, [3, 1, "A"]] => true }
$follow_asks = []
fake.answer("story.classic_follow") do |request|
  $follow_asks << request["keys"]
  request["keys"].map { |kind, key| world_keys[[kind, key]] ? true : false }
end
$classic = true
leaders = [[], [nil, nil], { [3, 1, "A"] => true, [3, 2, "B"] => true }]
leaders[1][1001] = 30
leaders[1][1050] = 7
members = [[], [nil, nil], { [3, 3, "C"] => true }]
members[1][1001] = 20
members[1][1050] = 2
joined = state.mix(leaders, members, [])
check("a Classic member joining the leader's story gets its world keys and keeps their own: values, and self switches set or never set",
      [joined[1][1001], joined[1][1050], joined[2]], [30, 2, { [3, 1, "A"] => true, [3, 3, "C"] => true }])
check("asking the DLL once for every key either story holds", [$follow_asks.size, $follow_asks[0].size], [1, 5])
$classic = false

# A skipped grant answers nil whatever writing the log returns, and a granted one answers its name.
check("a log line gives nothing back, the first time and every time after", [state.log("a line"), state.log_once(:key, "once"), state.log_once(:key, "once")], [nil, nil, nil])
check("a skill Luka knows or the game lacks is learned by nobody", [state.learn(937), state.learn(999)], [nil, nil])
check("a companion in the roster or missing from the game joins nobody", [state.join(16), state.join(99), state.bring(16), state.bring(99)], [nil, nil, nil, nil])
check("and the log tells why", $log.grep(/skipped/).size, 6)
check("a skill Luka lacks is learned under its name", [state.learn(930), state.knows?($game_actors[1], 930)], ["Angel Dance", true])
check("a companion joins the roster, or the party while it has room, under their name",
      [state.join(45), state.roster_ids], ["Tamamo", [1, 16, 45]])

# A story written past the game's setter of switches gives the characters the second accessory
# slot as that setter does, once it turns the slot's switch on, and not again while it stays on.
# Stands in for the game's switches, variables and self switches, the story as their data.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id]; end; end
class Game_Variables; def initialize; @data = []; end; end
class Game_SelfSwitches; def initialize; @data = {}; end; end
class Game_Actor; attr_reader :refits; def change_slot; @refits = refits.to_i + 1; end; end
class Game_Actors; def each(&block); @data.each_value(&block); end; end
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_self_switches = Game_SelfSwitches.new
[1, 16].each { |id| $game_actors[id] }
slot_on = []
slot_on[state::EXTRA_ACCESSORY_SLOT] = true
state.set_raw(slot_on, [], {})
state.set_raw(slot_on.dup, [], {})
check("a story that turns the second accessory slot on refits every character once", [$game_actors[1].refits, $game_actors[16].refits], [1, 1])

# The one-time repair of a save the 0.6.9.2 chest path left stuck: the DLL names the switches to
# turn on (StoryTopics.Repair), which the script turns on once per save.
# Stands in for the replay's asking of the DLL: each ask in $repair_asks, the answer $repair_answer.
module MGQ_MpStoryReplay; def self.ask_with_values(topic, request); $repair_asks << [topic, request]; $repair_answer; end; end
class Game_Switches; def []=(id, value); @data[id] = value; end; end
$repair_asks = []
$game_system = Object.new
$repair_answer = { "switches" => [2045] }
state.repair_check(false)
state.repair
check("a stuck save gets the switch its shut chest proves, asked of the DLL with the world it plays in",
      [$game_switches[2045], $repair_asks, $game_system.instance_variable_get(state::REPAIRED_FIELD)],
      [true, [["story.repair", { "world" => true, "raid" => true }]], true])
state.repair_check(false)
state.repair
check("the repair runs once per save", $repair_asks.size, 1)
$game_system = Object.new
$game_switches = Game_Switches.new
$repair_answer = { "unknown" => true }
state.repair_check(false)
state.repair
unknown = [$repair_asks.size, $game_system.instance_variable_get(state::REPAIRED_FIELD)]
$repair_answer = { "switches" => [] }
state.instance_variable_set(:@repair_at, nil)
state.repair
check("a save the DLL cannot decide yet is asked again, and a plain save stays as it is",
      [unknown, $game_switches[2045], $game_system.instance_variable_get(state::REPAIRED_FIELD)], [[2, nil], nil, true])
$game_system = Object.new
state.repair_check(true)
state.repair
check("a new game needs no repair", [$repair_asks.size, $game_system.instance_variable_get(state::REPAIRED_FIELD)], [3, true])

# The side the player took along in Iliasville, which the DLL's rule of the side decides
# (SidePickTests): the scripts hand it the story's side switches and markers with the save's note,
# note the side it says to note and take the side it answers.
side_asks = []
fake.answer("catchup.side") { |request| side_asks << request; $side_answer }
ilias = []
ilias[5] = true
$game_system = Object.new
$side_answer = { "side" => "ilias", "note" => "ilias" }
picked = state.own_pick(ilias, [])
check("the scripts hand the DLL the story's side switches and markers with the save's note, none yet",
      [side_asks.last["own"]["s"], side_asks.last["own"]["v"].assoc(1001), side_asks.last.key?("note"), side_asks.last["note"]], [[5], [1001, 0], true, nil])
check("and take the side it answers, noting the one it names in the save", [picked, state.pick_note], [:ilias, "ilias"])
$side_answer = { "side" => "ilias", "note" => nil }
state.own_pick([], [])
check("the next ask hands the DLL the save's note", side_asks.last["note"], "ilias")
$side_answer = { "side" => nil, "note" => nil }
check("a side the DLL does not know is none, the note kept", [state.own_pick([], []), state.pick_note], [nil, "ilias"])
$side_answer = nil
check("as while the DLL answers nothing", [state.own_pick([], []), state.pick_note], [nil, "ilias"])
$game_system = Object.new
$game_switches = Game_Switches.new
$game_switches[4] = true
state.note_other_start
check("a save of another player's starting save with that player's side notes that the player has not picked", state.pick_note, "")
