#----------------------------------------------------------------
#  world_catchup_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-10: Checked that a look whose question a quiet look answered asks the DLL nothing until the story changes
#      Paulinchen  2026-11-05: Answered the DLL's catch-up topics with fixed values per case instead of from the catch-up engine of engine.rb, and checked what the scripts send and what they do with each action, leaving the engine's decisions to the C# tests
#                            - Answered the story's part with fixed values per progress
#                            - Built the story chest without the flags only older games needed
#                            - Handed and expected the story's keys as [kind, key] with values, and the sites a replay plays as plain values
#                            - Expected the shared companions added through the DLL's topic, their ids as numbers
#                            - Checked that a prize's row gives only as history before the world's log, but the Medal King's free gift
#                            - Checked that the orbs' event plays only as history before the world's log
#                            - Checked that the repair never gives back an item an event takes away, read as the events database lists it
#                            - Checked that a found item's gain notes nothing for the world but a Makina, whose items the story replay hands over
#      Paulinchen  2026-11-01: Checked that a key item another player found comes once, to a player behind too, and its next gain adds nothing
#                            - Checked that a Small Medal the player holds is not noted for the world
#                            - Checked that a key item an event used up leaves every player of the world who holds it, with the Yggdrasil Fruit the Queen Harpy takes
#                            - Stood in for the replay's name of a command
#                            - Checked that a player on a route in a save of another player's starting save is asked, keeps the route's switches and loses the other side's companion once they answered, and one in a save of their own is not asked
#      Paulinchen  2026-10-31: Dropped the warp ban's lift on the maps where warping is free
#                            - Checked that a missed companion's recruit page is played once a route finished
#                            - Expected the plainer texts the player reads
#                            - Checked that the rows give only the history before the world's log
#                            - Checked that a world chest and a Makina by level are played in the player's game
#                            - Stood in for the replay the world's track waits on
#      Paulinchen  2026-10-28: Dropped the stand-in for the telling that may go on after a move
#                            - Checked that the rules of the catch-up come from the DLL once per revision of the mapping
#                            - Checked that the tables built from the rows before the rules came are kept, and built again once
#                            - Checked the catch-up through the DLL's catch-up topics: what it reads asked once per revision of the mapping, the save's notes handed once
#                            - Moved the game's stand-ins and the helpers into catchup_support.rb
#      Paulinchen  2026-10-24: Checked that a prize another player claimed reaches the player
#                            - Checked that Alice's Power-up counts the steps the world did
#                            - Checked that a join's persona waits behind a later change of the story
#                            - Checked that a power-up carried past changes the character once at its level
#                            - Checked that a companion of the roster takes the persona a join brings
#      Paulinchen  2026-10-23: Answered the rules the DLL owns through the bridge from the golden cases
#                            - Followed the relay's tracks through the DLL's story topics: a player behind on their part's checkpoint and moved on by the relay
#                            - Checked that a found job item comes to every player at once
#                            - Checked that the gate's notices name the cap of another mod below it
#                            - Checked that the story sets a return point only on the map of its event
#      Paulinchen  2026-10-17: Checked that the Unlocks page lists no companion the story took away
#                            - Checked that the catch-up waits while a lost raid boss battle's defeat runs
#                            - Checked that a player on Ilias's side gets the Remina Key Card back
#                            - Checked a key item one event gives and takes back
#                            - Checked job items of one-time gifts
#                            - Checked the rewards repair
#                            - Checked found job items by the story
#                            - Checked the question of a side for a player without one
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

# Covers world_catchup.rbx with world_story.rbx, story_keys.rbx, story_state.rbx, coop_story.rbx
# and coop_choices.rbx in the game catchup_support.rb stands in for: what the scripts hand the DLL's
# catch-up (the snapshot of the story, the roster and the items, the save's notes) and what they do
# with each action it answers, set per case as the C# engine would hand it back. What the story
# owes, its gates, removals, sides and audits are the DLL's (CatchupEngineTests over engine.json,
# ClassicCatchupTests, StoryRowsTests, CompanionScopeTests).

require_relative "catchup_support"

# The part of the story the DLL finds by the progress the checks below reach, no route under way
# (StoryPartsTests covers the rule).
$rule_answers.cases("story.part", { 7 => "1", 9 => "1", 18 => "1", 26 => "2", 30 => "2", 31 => "2", 33 => "2" }) { |request| request["p"] }

# Stands in for story_replay.rbx: the pages the catch-up hands the player's game to play, in
# $derived as [fields, why], with no run of the world's track waiting, and a command's name.
module MGQ_MpStoryReplay
  def self.input_at(site, _list, index); "#{site}@#{index}"; end
  def self.derive(fields, why); ($derived ||= []) << [fields, why]; end
  def self.running?; false; end
  def self.waiting; []; end
  def self.free?; false; end
end

story = MGQ_MpWorldStory
catchup = MGQ_MpWorldCatchup
answers = $answers

# Answers the save's catch-up notes.
#
# @return [Hash, nil] The notes.
notes = lambda { $game_system.instance_variable_get(:@mgq_mp_catchup) }

# Lists the requests of a catch-up topic that handed the save's notes.
#
# @return [Array<Hash>] The requests.
ledger_handed = lambda { (answers.asked("catchup.check") + answers.asked("catchup.note")).select { |request| request.key?("ledger") } }

$data_skills[544] = RPG::Skill.new(544, "Defense +10%")
# Stands in for RPG::Class, a class or a race.
ClassData = Struct.new(:id, :name)
$data_classes = Array.new(400)
$data_classes[301] = ClassData.new(301, "Fighter")
$data_actors[7] = ActorData.new(7, "Alice", 1)
Game_Actors::PERSONAS[7] = 5
$data_actors[26] = ActorData.new(26, "Ilias", 1)

$game_map = Game_Map.new
$game_player = Game_Player.new
SceneManager.scene = Scene_Map.new

# A player behind: the relay puts them on their part's checkpoint, and the DLL notes it.
new_game({ 1001 => 7, 3001 => 40 }, [4], 12)
$game_party.add_actor(16)
$game_party.gain_item($data_items[600], 2)
frames(1)
check("before the mapping came, the catch-up asks the DLL nothing", [MGQ_MpStoryKeys.raid_table, answers.asked("catchup.keys") + answers.asked("catchup.check")], [nil, []])
answers.set("catchup.note") { |request| { "actions" => [], "ledger" => { "world" => "w1", "checkpoint" => request["checkpoint"] } } }
checkpoint("1", packed({ 1001 => 18, 1032 => 5 }, [500, 2300]))
frames(70)
noted = answers.asked("catchup.note").first
check("a player the relay puts on a track of their own at their part's checkpoint is behind, told the level of the part's gate",
      [story.mode, $notices], [:behind, ["The world's story is further than yours. You see the world as it was before the end of Part 1; reach level 25 to move on."]])
check("whose story events are held", [catchup.holds_story?, catchup.refusal_text], [true, "Reach level 25 to continue the story."])
check("the DLL notes the checkpoint taken for the open world",
      [noted["checkpoint"], noted["world"], noted["mode"]], ["1", "w1", "behind"])
check("with the story values the catch-up reads, the roster with each base level and cap, and the counts of its items and of every job or race item",
      [noted["own"], noted["roster"], noted["items"], noted["unlocks"]],
      [{ "s" => [4, 500], "v" => [[1001, 18], [1032, 5]], "ss" => [] }, [[1, 1, 12, 9999], [16, 16, 20, 9999]], { "i501" => 0, "i502" => 0, "i600" => 2, "i616" => 0 }, [616]])
check("and the world's summary, its companion sharing and the start levels of its shared companions",
      [noted["summary"]["part"], noted["sharing"], noted["starts"], noted["encounters"]], ["2", "off", [], true])
check("the save keeps the notes the DLL answered", notes.call, { "world" => "w1", "checkpoint" => "1" })
check("what the catch-up reads was asked of the DLL once for the mapping's revision", answers.asked("catchup.keys").size, 1)
check("and the save's notes went to the DLL once, with its first call", ledger_handed.call.size, 1)

# Each look hands the DLL the story and carries out the actions it answers, in order, each with the
# game's own grant; an action that fails is logged and the others still run.
$game_party.add_actor(45)
$game_party.add_actor(5)
$game_party.gain_item($data_items[502], 1)
answers.queue("catchup.check", "actions" => [
  ["give", "i", 600, 3, "g:map:36:17:1:i600", true], ["give", "i", 502, -1, "k:map:7:25:1:502:-1", true], ["give", "skill", 937, 1, "g:map:406:7:2:skill937", true],
  ["give", "i", 650, 1, "g:map:60:3:1:i650", true], ["give", "i", 501, 1, "k:owed:501", false], ["learn", 930, "g:map:1697:7:2:skill930"], ["teach", 16, 544], ["class", 16, 301, 10], ["gifts"],
  ["change", 999, "map:1:1:1", nil], ["join", 77, 9, "level 7 reached"], ["join", 80, nil, "shared"], ["raise", 16, 30], ["leave", 45, "map:50:2:1"], ["dismiss", 5],
  ["set", 1009, 2], ["switch", 3150, true], ["log", "{actor:77} took the lead"], ["replay", { "site" => ["map", 215, 23, 1] }, "makina:700 at level 6"], ["gifts"],
], "growth" => { "seen" => 3 }, "visiting" => [80], "ledger" => { "world" => "w1", "checkpoint" => "1", "done" => { "g:map:36:17:1:i600" => true } })
$logs.clear
seen = answers.asked("catchup.check").size
catchup.level_up
frames(40)
looks = answers.asked("catchup.check")[seen..-1]
check("a level up has the next look look at everything, as a look from a world's track",
      [looks.first["look"], looks.first["audit"], looks.first["vehicles"], looks.first["growth"]], ["tick", true, false, nil])
check("the items given and taken, the skills Luka learns, and a companion's skill and class",
      [$game_party.items[600], $game_party.items[501], $game_party.items[502], MGQ_MpStoryState.knows?($game_actors[1], 937), MGQ_MpStoryState.knows?($game_actors[1], 930),
       MGQ_MpStoryState.knows?($game_actors[16], 544), $game_actors[16].level_list[301]], [5, 1, 0, true, true, true, 10])
check("what the game gave is logged at each tell of the gifts, never an item the game lacks, one taken nor one the DLL counts no gift",
      $logs.grep(/the story gave the player/), ["catch-up: the story gave the player Herb x3, Demon Decapitation, Angel Dance, Granberia's Defense +10%, Granberia's Fighter"])
check("an action that fails is logged once and the others still run", [$logs.grep(/carrying out change failed/).size, roster.include?(77)], [1, true])
check("companions join and are raised to the join's level, leave or are dismissed, each told",
      [roster, $game_actors[77].base_level, $game_actors[80].base_level, $game_actors[16].base_level, $messages],
      [[1, 16, 77, 80], 9, 9, 30, ["Slime joined you.", "Harpy joined you.", "Tamamo left with the story.", "Alice left you."]])
check("the story's variables and switches are set as the DLL answered", [$game_variables[1009], $game_switches[3150]], [2, true])
check("a log line names the companions it names", $logs.grep(/took the lead/), ["catch-up: 77 Slime took the lead"])
check("a page to play goes to the story replay", $derived, [[{ "site" => ["map", 215, 23, 1] }, "makina:700 at level 6"]])
check("the save keeps the notes the look answered", notes.call["done"], { "g:map:36:17:1:i600" => true })
check("a companion on a visit counts neither toward the player's level nor in the catch-up",
      [catchup.counted_level, catchup.counts?($game_actors[80]), catchup.counts?($game_actors[16])], [30, false, true])
frames(40)
looks = answers.asked("catchup.check")[seen..-1]
check("the next look is no audit and hands the DLL the growth it answered", [looks[1]["audit"], looks[1]["growth"]], [false, { "seen" => 3 }])
$derived = nil
answers.set("catchup.check", "actions" => [["gifts"], ["teach", 16, 544]], "growth" => { "count" => 0, "roster" => [1, 16, 77, 80] })
frames(40)
seen = answers.asked("catchup.check").size
frames(120)
held = answers.asked("catchup.check").size - seen
$game_variables[1032] = 6
frames(40)
check("a look whose question a quiet look after the roster's growth answered, teaching a skill held, asks the DLL nothing; a story changed since asks again",
      [held, answers.asked("catchup.check").size - seen], [0, 1])
$game_variables[1032] = 5

# The relay moves the player on by their level: the notice, the gate noted, and the world's story
# written into theirs, which the DLL looks at as a story laid over the player's.
$game_actors[1].level = 25
$messages.clear
answers.clear
frames(40)
check("the relay hears the level that opens the gate", staged("story.level").last, { "best" => 30, "cap" => 9999 })
seen = answers.asked("catchup.check").size
moved("1", "world", packed({ 1001 => 26 }, [2300]), "rev" => 2)
frames(40)
looks = answers.asked("catchup.check")[seen..-1]
carried = looks.find { |request| request["look"] == "carried" }
check("moved on into the world's story, the player is told and plays it",
      [$messages, story.mode, $game_variables[1001], catchup.holds_story?], [["Level 25 reached: catching up to the world's story."], :world, 26, false])
check("the DLL notes the gate the player passed, and that they left the checkpoint",
      answers.asked("catchup.note").map { |request| request.key?("capped") ? ["capped", request["capped"]] : ["checkpoint", request["checkpoint"]] }, [["capped", 25], ["checkpoint", nil]])
check("and looks at the story laid over the player's while they are still behind, with their story from before it and the world's story told",
      [carried["mode"], carried["before"], carried["told"]],
      ["behind", { "s" => [4, 500], "v" => [[1001, 18], [1009, 2], [1032, 5]], "ss" => [] }, { "s" => [4], "v" => [[1001, 26], [1009, 0], [1032, 0]], "ss" => [] }])
check("the next look follows the vehicles", looks.select { |request| request["look"] == "tick" }.map { |request| request["vehicles"] }.first, true)

# A gate a cap of another mod opened names the cap in the notices.
new_game({ 1001 => 7 }, [], 30)
frames(1)
checkpoint("1", packed({ 1001 => 18 }), "part" => "3", "checkpoints" => "1,2")
frames(70)
$game_actors[1].cap = 20
check("a player capped below the gate is told to reach the cap",
      [catchup.refusal_text, catchup.behind_text("1")],
      ["Reach level 20 to continue the story.", "The world's story is further than yours. You see the world as it was before the end of Part 1; reach level 20 to move on."])
$game_actors[1].level = 20
frames(40)
check("and tells the relay their cap with their level", staged("story.level").last, { "best" => 20, "cap" => 20 })
moved("1", "2", packed({ 1001 => 33 }), { "part" => "3", "checkpoints" => "1,2" }, "cap")
frames(70)
check("moved on by the cap, the notice names the cap", [$messages.last, story.mode, catchup.refusal_text], ["Level 20 reached: catching up to Part 2.", :behind, "Reach level 20 to continue the story."])
$game_actors[1].cap = 9999

# A save that noted the player behind holds their story from its load until the world's story came.
new_game({ 1001 => 7 }, [], 5)
check("a fresh game holds nothing before the world's story came", [story.mode, catchup.holds_story?], [nil, false])
frames(1)
answers.set("catchup.note") { |request| { "actions" => [], "ledger" => { "world" => "w1", "checkpoint" => request["checkpoint"] } } }
checkpoint("1", packed({ 1001 => 18 }))
frames(70)
story.loaded(:load)
catchup.loaded
check("a save noting the checkpoint of its own part holds the story from the moment it loads", [story.mode, catchup.holds_story?], [nil, true])
MGQ_MpWorld.world = MGQ_MpWorld::World.new("w2")
check("but not in another world", catchup.holds_story?, false)
MGQ_MpWorld.world = MGQ_MpWorld::World.new("w1")
$game_variables[1001] = 26
check("nor once its story is in another part", catchup.holds_story?, false)

# The vehicles go as the DLL found the story: one no event gave yet leaves its map unless the
# player rides it, one the story gave that stands on no map comes back to its start.
# Answers the map a vehicle stands on.
#
# @param type [Symbol] The vehicle.
# @return [Integer] The map, 0 for none.
vehicle_map = lambda { |type| $game_map.vehicle(type).instance_variable_get(:@map_id) }
new_game({ 1001 => 9 }, [], 40)
$game_map.vehicle(:boat).set_location(0, 0, 0)
$game_map.vehicle(:ship).set_location(2, 306, 2)
$game_map.vehicle(:airship).set_location(0, 0, 0)
$game_player.vehicle = $game_map.vehicle(:ship)
answers.set("catchup.check", "actions" => [["vehicles", [true, false, true]]])
frames(1)
relay({ "rev" => 26, "wrev" => 26, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("Galda the story gave comes back to its start, the ship it has not given stays while the player rides it, the boat without a start stays off",
      [$game_map.vehicle(:airship).spot, vehicle_map.call(:ship), vehicle_map.call(:boat)], [[2, 186, 1], 2, 0])
$game_player.vehicle = nil
frames(40)
check("the ship leaves once the player got off, at the look at everything that follows",
      [vehicle_map.call(:ship), answers.asked("catchup.check").last["audit"]], [0, true])
$game_map.vehicle(:airship).set_location(2, 237, 239)
answers.set("catchup.check", "actions" => [["vehicles", [nil, nil, true]]])
catchup.level_up
frames(40)
check("a Galda on a map stays where it is, and one only the world's log gave stays too", [$game_map.vehicle(:airship).spot, vehicle_map.call(:ship)], [[2, 237, 239], 0])
$game_map.vehicle(:airship).set_location(0, 0, 0)
$game_player.vehicle = $game_map.vehicle(:airship)
catchup.level_up
frames(40)
check("and one the player rides is never moved", vehicle_map.call(:airship), 0)
$game_player.vehicle = nil

# A value the story sets of the player's own: the random encounters unless a page of the map that
# applies now sets them the other way, and a place only on the map of the event that sets it.
new_game({ 1001 => 9, 1002 => 1 }, [], 40)
$game_system.encounter_disabled = true
answers.set("catchup.check", "actions" => [["setting", "encounters", 0, true, ["map", 6, 30, 2]], ["setting", "v", 1002, 2, ["map", 6, 30, 2]], ["setting", "v", 1009, 4, ["map", 6, 30, 2]]])
frames(1)
relay({ "rev" => 25, "wrev" => 25, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("the story turns the encounters on, sets a value, and leaves the return point away from its event's map",
      [$game_system.encounter_disabled, $game_variables[1009], $game_variables[1002]], [false, 4, 1])
$game_map.map_id = 6
catchup.level_up
frames(40)
check("but sets the return point on that map", $game_variables[1002], 2)
# Stands in for an event page.
encounter_page = Struct.new(:list)
# Stands in for a map event whose page that applies now is the one it holds.
map_event = Struct.new(:proper) { def find_proper_page; proper; end }
[[encounter_page.new([RPG::EventCommand.new(136, 0, [0])]), true, "a page that applies now turns them off"],
 [nil, false, "no page applies now"], [encounter_page.new([RPG::EventCommand.new(136, 0, [1])]), false, "the page that applies now turns them on too"]].each do |page, kept, why|
  $game_map.events[1] = map_event.new(page)
  $game_system.encounter_disabled = true
  catchup.level_up
  frames(40)
  check("the encounters #{kept ? 'stay with the map' : 'follow the story'} where #{why}", $game_system.encounter_disabled, kept)
end
$game_map.events.clear
$game_map.map_id = 3

# What a power-up changes of a character runs through the game's own calls: a call only a first
# playthrough runs on a first playthrough alone, and none whose change the character shows.
power_up = ["change", 5, "map:1330:15:1", [["persona_change", [7], false], ["level_adjust", [7, 250], true]]]
[[0, [7, 250]], [1, [7, 1]]].each do |playthrough, expected|
  new_game({ 1001 => 9, 912 => playthrough }, [], 250)
  $game_party.add_actor(5)
  answers.set("catchup.check", "actions" => [power_up])
  frames(1)
  relay({ "rev" => 50, "wrev" => 50, "p" => 9, "part" => "1" }, packed({ 1001 => 9, 912 => playthrough }))
  frames(40)
  check("on playthrough #{playthrough} Alice takes her persona#{playthrough == 0 ? ' and her level' : ', not the level'}", [$game_actors[5].persona, $game_actors[5].base_level], expected)
end
check("and the log tells it", $logs.grep(/took what map:1330:15:1 changes/).size, 1)
$logs.clear
catchup.level_up
frames(40)
check("a character who shows the change already takes nothing", $logs.grep(/shows what map:1330:15:1 changes already/).size, 1)

# A join of a companion's main persona leaves the other persona an actor change gave them, and a
# join in another persona turns a companion of the roster into it.
new_game({ 1001 => 9 }, [], 40)
answers.set("catchup.check", "actions" => [["form", 841, "map:1834:20:1"], ["join", 525, nil, "level 1 reached"]])
frames(1)
relay({ "rev" => 51, "wrev" => 51, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("the persona a join brings turns the companion into it, and a join of the main persona then keeps that persona",
      [roster.include?(525), $game_actors[525].persona], [true, 841])

# A player whose story went past the choice of a side without one is asked once while they are free,
# and the side the DLL's rule answers sets the side switches and brings its companion.
new_game({ 1001 => 9 }, [5001], 40)
$game_message = Game_Message.new
answers.set("catchup.check", "actions" => [], "ask_side" => true)
frames(1)
relay({ "rev" => 26, "wrev" => 26, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }, [5001]))
frames(40)
check("a player whose story went past the choice without one is asked whom they take along, with no way to cancel",
      [$game_message.choices, $game_message.choice_cancel_type], [["Alice", "Ilias"], 0])
frames(40)
check("and asked only once while the question is open", $game_message.choices, ["Alice", "Ilias"])
$game_message = Game_Message.new
frames(40)
check("and again once something cleared the question", $game_message.choices, ["Alice", "Ilias"])
choose = $game_message.choice_proc
$game_message = Game_Message.new
answers.set("catchup.check", "actions" => [])
answers.set("catchup.side", "switches" => [[4, true], [5, false]], "companion" => 5)
choose.call(0)
side = answers.asked("catchup.side").find { |request| request.key?("chose") }
check("taking Alice asks the DLL's rule of the side with the side switches and markers of the player's story",
      [side["chose"], side["own"]["s"], side["own"]["v"].assoc(1001)], ["alice", [], [1001, 9]])
check("sets the side switches it answers and brings the companion it names", [$game_switches[4], $game_switches[5], roster.include?(5)], [true, false, true])
check("and the DLL notes the side in the save's notes", answers.asked("catchup.note").last["side"], "alice")
frames(40)
check("the next look looks at everything", [answers.asked("catchup.check").last["audit"], $game_message.choices], [true, []])
new_game({ 1001 => 40, 1141 => 10 }, [4], 80)
$game_party.add_actor(26)
answers.set("catchup.side", "switches" => [], "companion" => nil)
catchup.take_side(:alice)
check("a player on a route keeps the switches, which tell the route there", [$game_switches[4], $game_switches[5], roster.include?(26)], [true, false, true])

# The companions new in the roster that the DLL finds the world's list takes go to the relay, a few
# together; a failed addition goes again later.
$sharing = :all
new_game({ 1001 => 9 }, [], 40)
$game_party.add_actor(77)
$game_party.add_actor(80)
answers.set("catchup.check", "actions" => [], "sharable" => [77, 80], "visiting" => [80])
frames(1)
relay({ "rev" => 9, "wrev" => 9, "p" => 9, "part" => "1", "comps" => "16" }, packed({ 1001 => 9 }))
frames(40)
check("a companion the world's list takes goes to it, never one on a visit", calls_of("raid.companions.add"), [{ "world" => "w1", "ids" => [77] }])
check("the look hands the DLL the world's sharing and the start level of each shared companion",
      [answers.asked("catchup.check").last["sharing"], answers.asked("catchup.check").last["starts"]], ["all", [[16, 20]]])
$raid_story["companions"] = "failed"
frames(40)
check("a failed addition waits", calls_of("raid.companions.add").size, 1)
$frame_count = MGQ_Multiplayer::Bridge.frame_number
frames(MGQ_MpWorldCatchup::RETRY_FRAMES)
check("and goes again later", calls_of("raid.companions.add").last, { "world" => "w1", "ids" => [77] })
$raid_story["companions"] = "done"
frames(MGQ_MpWorldCatchup::SHARE_FRAMES + 40)
check("one that went through goes once", calls_of("raid.companions.add").size, 2)
$sharing = :off
new_game({ 1001 => 9 }, [], 40)
$game_party.add_actor(77)
answers.set("catchup.check", "actions" => [], "sharable" => [77])
frames(1)
relay({ "rev" => 10, "wrev" => 10, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("with sharing off nothing goes to the world's list", calls_of("raid.companions.add"), [])

# The orbs' event plays once the DLL found it due, once, when the player is free on the map.
new_game({ 1001 => 30 }, [], 40)
answers.set("catchup.check", "actions" => [], "orbs" => true)
frames(1)
$setups = []
relay({ "rev" => 22, "wrev" => 22, "p" => 31, "part" => "2" }, packed({ 1001 => 31 }))
frames(40)
check("the orbs' event plays once the DLL found it due", $setups.map { |list| list.map { |entry| [entry.code, entry.parameters] } }, [[[117, [330]], [0, []]]])
frames(40)
check("once", $setups.size, 1)

# A companion the player's own story event hands out goes through the DLL: it may wait for its gate,
# be refused or join.
new_game({ 1001 => 24 }, [], 40)
frames(1)
relay({ "rev" => 8, "wrev" => 8, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
# Stands in for a map event and its pages.
paged_event = Struct.new(:mgq_mp_pages)
event_page = Struct.new(:list)
pages = [event_page.new([RPG::EventCommand.new(129, 0, [45])])]
$game_map.events[86] = paged_event.new(pages)
$game_map.map_id = 483
$game_map.interpreter.setup(pages[0].list, 86)
$game_map.interpreter.event_id = 86
$telling = true
answers.set("catchup.hold_join", "actions" => [], "gate" => 60)
$game_party.add_actor(45)
held = answers.asked("catchup.hold_join").last
check("the game's own join during the player's telling asks the DLL with the companion, the running page and the player's story",
      [held["actor"], held["site"], held["scope_only"], held["replay"], held["own_way"], held["sharing"], held["start"], held["own"]["v"]],
      [45, ["map", 483, 86, 1], false, false, false, "off", 12, [[1001, 24]]])
check("a join the DLL holds for its gate waits, told so", [roster.include?(45), $messages.last], [false, "Tamamo joins you once you reach level 60."])
$messages.clear
answers.set("catchup.hold_join", "actions" => [["log", "refused {actor:45}"]], "refused" => true)
$game_party.add_actor(45)
check("one it refuses stays out untold, the actions it answers carried out", [roster.include?(45), $messages, $logs.grep(/refused 45/).size], [false, [], 1])
$telling = false
answers.set("catchup.hold_join", "actions" => [])
$game_party.add_actor(45)
check("one it lets go joins, a join of another player's event asked for the world's scope only", [roster.include?(45), answers.asked("catchup.hold_join").last["scope_only"]], [true, true])
$game_map.interpreter.event_id = 0
$game_map.events.clear
$game_map.map_id = 3

# The World overview's Unlocks page lists what the DLL answers, named from the game's data and
# sorted by level, then kind and name.
$data_items[622] = RPG::Item.new(622, "Soul of the Warrior God", "[Job] Allows access to advanced Warrior jobs.", false)
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 31, "wrev" => 31, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
answers.set("catchup.unlocks", "unlocks" => [[30, "makina", 701, nil, false, false, []], [7, "companion", 77, nil, true, false, []], [6, "makina", 700, nil, false, true, []],
                                             [25, "story", nil, "Part 1", false, false, [["i", 600, 2], ["skill", 930, 1], ["i", 502, 1], ["i", 622, 1]]],
                                             [6, "makina", 799, nil, false, true, []]])
unlocks = catchup.unlocks
check("the Unlocks page asks the DLL with the snapshot", answers.asked("catchup.unlocks").last["own"], { "s" => [], "v" => [[1001, 9]], "ss" => [] })
check("and lists what it answers by level, a Makina the game lacks left out",
      unlocks.map { |unlock| [unlock.level, unlock.kind, unlock.name, unlock.got, unlock.due, unlock.id] },
      [[6, :makina, "Auto Crossbow", false, true, 700], [7, :companion, "Slime", true, false, 77], [25, :story, "Part 1", false, false, nil], [30, :makina, "Bio Blaster", false, false, 701]])
check("moving on from a part lists the key items and job items first, then skills and items",
      unlocks[2].gains.map { |gain| [gain.kind, gain.name, gain.amount] }, [[:key, "Pass", 1], [:unlock, "Soul of the Warrior God", 1], [:skill, "Angel Dance", 1], [:item, "Herb", 2]])

# A Makina the player gets is found for the world, so every other player gets it by level; one held
# before is noted at the next look at everything.
new_game({ 1001 => 9 }, [], 10)
$game_party.gain_item($data_items[701], 1)
frames(1)
relay({ "rev" => 30, "wrev" => 30, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("a Makina held before is noted as found on entering, and goes to the DLL with the snapshot",
      [$game_self_switches[[0, 701, "F"]], answers.asked("catchup.check").last["own"]["ss"]], [true, [[0, 701, "F"]]])
$game_party.gain_item($data_items[616], 1)
$game_party.gain_item($data_items[700], 1)
check("a Makina gained is noted, a job item notes nothing", [$game_self_switches[[0, 700, "F"]], $game_self_switches[[0, 616, "F"]]], [true, false])

# A telling the player watched counts as a story laid over theirs once they are free, from their
# story before the teller's values came.
new_game({ 1001 => 29, 1032 => 3 }, [], 40)
frames(1)
relay({ "rev" => 22, "wrev" => 22, "p" => 29, "part" => "2" }, packed({ 1001 => 29, 1032 => 3 }))
frames(40)
answers.clear
catchup.watched { MGQ_MpStoryState.deep_copy(catchup.story_now) }
MGQ_MpStoryKeys.applying { $game_variables[1032] = 4 }
frames(40)
carried = answers.asked("catchup.check").find { |request| request["look"] == "carried" }
check("a telling the player watched is looked at as a story laid over theirs, from the story before it",
      [carried && carried["before"]["v"], carried && carried["own"]["v"]], [[[1001, 29], [1032, 3]], [[1001, 29], [1032, 4]]])

# A lost raid boss battle's defeat takes items its undo gives back, so the catch-up waits meanwhile.
# Stands in for the freeze engine: a lost raid boss battle's defeat runs while $holding.
module MGQ_MpRaidFreeze; def self.holding_writes?; $holding ? true : false; end; def self.unjournaled; yield; end; end
new_game({ 1001 => 26 }, [], 12)
frames(1)
relay({ "rev" => 40, "wrev" => 40, "p" => 26, "part" => "2" }, packed({ 1001 => 26 }))
frames(40)
$holding = true
seen = answers.asked("catchup.check").size
catchup.level_up
relay({ "rev" => 41, "wrev" => 41, "p" => 30, "part" => "2" }, packed({ 1001 => 30 }))
frames(40)
check("nothing the relay hands is written and the DLL is asked nothing while a lost raid boss battle's defeat runs",
      [$game_variables[1001], answers.asked("catchup.check").size], [26, seen])
$holding = false
frames(40)
check("but once it ended", [$game_variables[1001], answers.asked("catchup.check").size > seen], [30, true])

# Classic worlds have no catch-up.
$raid = false
new_game({ 1001 => 3 }, [], 99)
frames(40)
check("a Classic world holds no story and asks the DLL's catch-up nothing", [catchup.holds_story?, answers.asked("catchup.check")], [false, []])
