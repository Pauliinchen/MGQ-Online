#----------------------------------------------------------------
#  world_freeze_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers world_freeze.rbx with story_state.rbx, story_keys.rbx and battles_raid_bosses.rbx against
# fixed answers of the DLL's frozen fights (FreezeTopics), whose rules the C# tests cover: a fight
# noted and its held keys handed as plain values, the list taken back as the game's values and read
# by kind of key, an answer of an unchanged list, and the world's story told for the end rule.

require_relative "support"
require_relative "raid_support"

# Stands in for the mod's log: records each line in $log.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end
$log = []

# The scripts' clock, which the checks move with $frame.
clock_from { $frame }
$frame = 0

# Stands in for the title scene, whose start forgets the frozen fights.
class Scene_Title; def start; end; end

# Stands in for the game's switches, off unless set.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's variables, 0 unless set.
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end

# Stands in for the world's story: the open world's id, and the fights' keys asked of the relay kept
# in $written.
module MGQ_MpWorldStory
  # Answers the open world's id.
  def self.world_id; "w1"; end
  # Keeps a fight's key asked of the relay.
  def self.write_freeze(troop, entry); $written << [troop, entry]; true; end
end
$written = []

$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
load_script "story_state"
load_script "battles_raid_bosses"
load_script "world_freeze"

fake = FakeBridge.new
answer_raid_rules(fake)
MGQ_Multiplayer::Bridge.open(fake)
freeze = MGQ_MpWorldFreeze

# Sonya Mazda's frozen fight as the DLL hands it back: the switch, the variable, the self switch and
# the float it holds, as plain values.
FIGHT = { "troop" => 868, "site" => ["map", 138, 13, 1], "outer" => ["map", 138, 13, 1], "scene" => false, "tableau" => [138, [], [13]], "spot" => [138, 32, 9, 8],
          "held" => [[0, 31, true], [1, 1075, 14], [2, [138, 13, "A"], false], [1, 1077, { "float" => "1.5" }]] }
$state = { "version" => 1, "entries" => [FIGHT], "held" => FIGHT["held"], "writes" => [] }
fake.answer("freeze.fights.note") { |_request| { "held" => true, "writes" => [[868, FIGHT]] } }
fake.answer("freeze.fights.state") { |_request| $state }
fake.answer("freeze.fights.told") { |_request| { "writes" => [[868, false]] } }

# A fight noted: its held keys go as plain values, a list the story cannot carry left out and
# logged once, and the fight's key goes to the relay as the DLL asks.
held = [[0, 31, true], [1, 1075, 14], [2, [138, 13, "A"], false], [1, 1077, 1.5], [1, 1078, [1, 2]]]
noted = freeze.note(FIGHT.merge("held" => held))
check("a noted fight hands its held keys as plain values, a float as its text, a list left out and logged",
      [noted, fake.calls.select { |topic, _| topic == "freeze.fights.note" }.map { |_, bytes| Marshal.load(bytes)["entry"]["held"] }.last,
       $log.grep(/left the held v1078 out: its value is no kind the story carries/).size],
      [true, [[0, 31, true], [1, 1075, 14], [2, [138, 13, "A"], false], [1, 1077, { "float" => "1.5" }]], 1])
freeze.note(FIGHT.merge("held" => held))
check("the list's refusal is logged once", $log.grep(/left the held v1078 out/).size, 1)
check("and the fight's key goes to the relay", $written.first, [868, FIGHT])

# The list taken back: each kind of key reads as the game's value.
check("the list holds the fight", freeze.entries.map { |entry| entry["troop"] }, [868])
check("a switch, a variable, a self switch and a float read as the game's values, a key no fight holds as none",
      [freeze.held_value(0, 31), freeze.held_value(1, 1075), freeze.held_value(2, [138, 13, "A"]), freeze.held_value(1, 1077), freeze.held_value(1, 1076)],
      [[true, true], [true, 14], [true, false], [true, 1.5], nil])

# An answer of an unchanged list keeps the list read before.
$state = $state.merge("held" => [[1, 1075, 20]])
$frame += MGQ_MpWorldFreeze::CHECK_FRAMES
check("an answer whose version did not change keeps the held values read before", freeze.held_value(1, 1075), [true, 14])
$state = $state.merge("version" => 2)
$frame += MGQ_MpWorldFreeze::CHECK_FRAMES
check("a new version's are read", freeze.held_value(1, 1075), [true, 20])

# The world's story told for the end rule: its values as the rules read them, the end the DLL asks
# of the relay sent.
switches = []
switches[97] = true
variables = []
variables[1001] = 34
freeze.world_told([switches, variables, {}])
told = Marshal.load(fake.calls.select { |topic, _| topic == "freeze.fights.told" }.last[1])
check("the world's story goes to the DLL as the values the rules read, and the end it asks goes to the relay",
      [told["told"], $written.last], [{ "map" => 0, "s" => [false, true], "v" => [34, 0] }, [868, false]])
