#----------------------------------------------------------------
#  catchup_data_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Checked that the pedestals of job orbs are world chests
#      Paulinchen  2026-10-17: Checked where Remina's Card Key comes from
#                            - Checked that the story first comes to a map before the part ending its lists set a value before
#      Paulinchen  2026-10-14: Checked hide and seek's gifts by the count of Amiras, Adramelech's return point and the one-way variables
#      Paulinchen  2026-10-12: Checked the skills Rami's quest teaches her and that no forgotten skill is a lesson
#                            - Checked that the chests of Amira's side quest job items are world chests
#                            - Checked the vehicle rows and where Galda comes first
#                            - Checked where every ore comes from and the Chaos forge's chest flags
#      Paulinchen  2026-10-11: Checked when a talk join counts
#                            - Read the generator from MGQ-Paradox-Event-Checker next to the repository
#      Paulinchen  2026-10-10: Checked that no row needs a Library Flag
#                            - Checked that the joins of Monte Carlo's evacuation count once it ended
#      Paulinchen  2026-10-09: Checked a temple's story variable and the Silver Orb for every player
#                            - Created
#
#----------------------------------------------------------------

# Covers world_catchup_data.rbx, which raid_data.rb of MGQ-Paradox-Event-Checker writes from the
# game's data: the shape of its tables, the parts and their gates as the relay splits the story, and
# key rows such as Sonya's and Nuruko's Chaos returns. Also covers the generator's rules that need
# no game data: the order of places and the Level Cap's cap a given-back companion joins at.

require_relative "support"

load File.join(SCRIPTS_DIR, "world_catchup_data.rbx")
# The catch-up data under test.
DATA = MGQ_MpWorldCatchupData

# The marks a row may hold: a switch on, a variable at least, a self switch on.
#
# @param marks [Array] The marks.
# @return [Boolean] Whether each is one of those.
def marks_shaped?(marks)
  marks.is_a?(Array) && marks.all? do |mark|
    case mark[0]
    when :s then mark.size == 2 && mark[1].is_a?(Integer)
    when :v then mark.size == 3 && mark[1].is_a?(Integer) && mark[2].is_a?(Integer) && mark[2] > 0
    when :ss then mark.size == 4 && mark[1].is_a?(Integer) && mark[2].is_a?(Integer) && %w[A B C D].include?(mark[3])
    else false
    end
  end
end

# Finds the joins of a persona at a site.
#
# @param persona [Integer] The persona the event adds.
# @param site [String] The event's site.
# @return [Array<MGQ_MpWorldCatchupData::Join>] The joins.
def joins_at(persona, site)
  DATA::JOINS.select { |join| join.persona == persona && join.site == site }
end

parts = DATA::PARTS.map(&:id)
check("the parts are the relay's, in the story's order", parts, %w[1 2 3 ad mr chaos])
check("each part's gate is the cap of its last Level Cap milestone", DATA::PARTS.map(&:gate), [25, 55, 65, 120, 120, 300])
relay = File.read(File.expand_path("../../Relay/core/story.js", __dir__), :encoding => "UTF-8")
ends = relay[/PART_ENDS = Object\.freeze\(\{ one: (\d+), two: (\d+) \}\)/] && [$1.to_i, $2.to_i]
endings = DATA::PARTS[0, 2].map { |part| part.ending.find { |mark| mark[0] == :v && mark[1] == 1001 }[2] }
check("Part 1's and Part 2's endings start before the relay's ends of the parts", [endings[0] < ends[0], endings[1] < ends[1]], [true, true])
check("and every ending holds marks", DATA::PARTS.all? { |part| !part.ending.empty? && marks_shaped?(part.ending) }, true)

check("the joins are many, as the whole story's", DATA::JOINS.size > 500, true)
check("every join has its actor, persona and site",
      DATA::JOINS.all? { |join| join.actor.is_a?(Integer) && join.persona.is_a?(Integer) && join.site =~ /\A(ce|map|troop):[\d:]+\z/ }, true)
check("every join's place is a part or side content, with marks", DATA::JOINS.all? { |join| (join.part.nil? || parts.include?(join.part)) && marks_shaped?(join.marks) }, true)
check("every join of a part names its step there", DATA::JOINS.all? { |join| join.part.nil? || join.part == "ad" || join.part == "mr" || join.step.is_a?(Integer) }, true)
check("every gate is a level of 1 to 300", DATA::JOINS.all? { |join| join.gate.is_a?(Integer) && join.gate.between?(1, 300) }, true)
check("every gate names its rule", DATA::JOINS.map(&:rule).uniq.sort, [:cap, :floor, :kept, :start])
check("the joins come in the story's order", DATA::JOINS.map { |join| parts.index(join.part) || 9 }.each_cons(2).all? { |one, other| one <= other || (one == 3 && other == 4) || (one == 4 && other == 3) }, true)

sonya = joins_at(842, "map:1834:20:1")
check("Sonya's Chaos return joins at her floor of 325, through her persona 842, held at 300",
      sonya.map { |join| [join.actor, join.part, join.gate, join.rule] }, [[525, "chaos", 300, :floor]])
check("and only once the story is past her event", sonya[0].marks.include?([:s, 3443]), true)
check("her first join is at her start level", DATA::JOINS.find { |join| join.actor == 525 }.values_at(2, 7, 8), ["map:7:60:1", 2, :start])
nuruko = joins_at(706, "map:1353:12:1")
check("Nuruko's Chaos return joins at 225, through her persona 706", nuruko.map { |join| [join.actor, join.gate, join.rule] }, [[79, 225, :floor]])
check("and her first join in Part 2 at her start level 7", DATA::JOINS.select { |join| join.actor == 79 && join.part == "2" }.map(&:gate).uniq, [7])
check("Lime's Chaos return takes the floor of her while-only join before it",
      joins_at(53, "ce:9141").map { |join| [join.gate, join.rule] }, [[35, :floor]])
check("Lazarus's two Chaos returns join at 56 and 64", [520, 521].map { |id| joins_at(id, "map:1982:6:1").map(&:gate) }, [[56], [64]])
check("the angels' picks at the Chaos Ilias Temple take the floors set before them",
      [[510, "map:1294:17:1"], [511, "map:1294:16:1"], [512, "map:1294:18:1"]].map { |id, site| joins_at(id, site).map(&:gate) }, [[242], [241], [245]])
check("a give-back without a floor joins at the Level Cap's cap there",
      DATA::JOINS.select { |join| join.rule == :cap }.all? { |join| join.part && DATA::REMOVALS.any? { |removal| removal.actor == join.actor && removal.first } }, true)

revival = DATA::REMOVALS.select { |removal| removal.site == "ce:9141" }
check("the Pocket Castle's revival takes away its companions on the first playthrough",
      [revival.size > 100, revival.all?(&:first), revival.map(&:part).uniq, revival.map(&:actor).include?(79)], [true, true, ["chaos"], true])
check("every removal has its place", DATA::REMOVALS.all? { |removal| parts.include?(removal.part) && marks_shaped?(removal.marks) && [true, false].include?(removal.first) }, true)

check("every join and removal names its command, and every row with a place whether its event ran",
      [DATA::JOINS.all? { |join| join.index.is_a?(Integer) && [true, false].include?(join.ran) }, DATA::REMOVALS.all? { |removal| removal.index.is_a?(Integer) },
       (DATA::KEY_ITEMS + DATA::REWARDS).all? { |row| [true, false].include?(row.ran) }], [true, true, true])
rami = DATA::LESSONS.select { |row| row.actor == 56 }
check("the skills Rami's flying quest teaches her are lessons placed at its steps, and no row of a skill an event takes away again",
      [rami.map(&:skill).uniq.sort, rami.all? { |row| row.ran && marks_shaped?(row.marks) }, DATA::LESSONS.any? { |row| row.actor == 823 && row.skill == 5837 }],
      [[544, 545, 592, 7751, 7766, 7778], true, false])
check("a town's companion who joins on a talk only shows the event there to play, a story join that it ran",
      [joins_at(553, "map:140:25:1")[0].ran, sonya[0].ran, DATA::REWARDS.find { |row| row.id == 930 && row.site =~ /\Amap:406:/ }.ran], [false, true, true])
check("a talk join counts once a story page after it that needs the companion in the party ran, as Lime's by Alice handing over the Pocket Castle, at her start level",
      joins_at(53, "map:7:63:1").map { |join| [join.ran, join.marks, join.gate, join.rule] }, [[true, [[:v, 1001, 7], [:s, 5001]], 1, :start]])
granberia = [DATA::JOINS, DATA::REMOVALS].map { |rows| rows.find { |row| row.actor == 19 && row.site == "map:483:86:1" }.index }
check("Granberia joins and then leaves in one event at Part 2's step 24, in that order", granberia[0] < granberia[1], true)
orb = DATA::KEY_ITEMS.select { |row| row.item == 596 && row.part.nil? }.map(&:amount)
check("an item given and taken with no step between comes first, then goes", orb, [1, -1])

check("the chests that hold key items are the story's 25, 11 of ore and 59 of items that unlock a job or a race", DATA::CHESTS.size, 95)
check("among them the pedestals of job orbs, which hand out a medal by script", DATA::CHESTS.select { |chest| chest.key[0] == 1650 }.map(&:items), [[665], [671]])
check("the Ghost Ship's Purple Orb chest is one of them", DATA::CHESTS.find { |chest| chest.key == [371, 12, "A"] }.items, [541])
ores = (151..158).to_a + (943..947).to_a
check("every ore the blacksmiths ask for comes from a chest or a key item row",
      ores - DATA::CHESTS.flat_map(&:items) - DATA::KEY_ITEMS.map(&:item), [])
check("the Chaos forge's ores turn on the flags it asks for",
      DATA::CHESTS.select { |chest| !chest.flags.empty? }.map { |chest| [chest.items, chest.flags] }.sort, [[[945], [7102]], [[946], [7103]], [[947], [7104]]])
check("every key item has an amount and marks", DATA::KEY_ITEMS.all? { |row| row.item.is_a?(Integer) && row.amount != 0 && marks_shaped?(row.marks) }, true)
check("Marcellus' Letter comes with the main story's step 11", DATA::KEY_ITEMS.find { |row| row.item == 510 }.values_at(2, 3, 4), ["map:311:7:1", "1", 11])
check("Remina's Card Key comes with Part 2's step 33 on either side, which a defeat by Sonya takes back",
      DATA::KEY_ITEMS.select { |row| row.item == 557 }.map { |row| row.values_at(2, 3, 4, 5) },
      [["map:730:19:1", "2", 33, :ilias], ["map:730:19:1", "2", 33, :alice]])
check("and item 501, which an event of map 748 gives on either side, has a row for each side",
      [:alice, :ilias].map { |side| DATA::KEY_ITEMS.count { |row| row.item == 501 && row.site == "map:748:3:1" && row.side == side } }, [1, 1])

skills = DATA::REWARDS.select { |row| row.kind == :skill }
check("the rewards hold every story skill once at least", skills.map(&:id).uniq.size, 43)
camps = skills.select { |row| row.site =~ /\Amap:(406|523|604|711|736|741):7:/ }
check("the six camps' skills have explicit marks", [camps.map { |row| row.site[/\Amap:\d+/] }.uniq.size, camps.all? { |row| !row.marks.empty? }], [6, true])
amira = DATA::REWARDS.select { |row| row.site == "ce:322" }
check("hide and seek's gifts wait for the count of Amiras found, never for the first Amira's self switch",
      [amira.map { |row| [row.id, (row.marks.find { |mark| mark[1] == 1043 } || [])[2]] }.sort_by { |_, count| count.to_i },
       amira.any? { |row| row.marks.any? { |mark| mark[0] == :ss } }],
      [[[40, 2], [44, 4], [36, 6], [41, 9], [45, 12], [37, 15], [42, 17], [46, 19], [38, 23]], false])
check("and its trophy for the 21st", DATA::KEY_ITEMS.find { |row| row.item == 560 }.marks, [[:v, 1001, 6], [:v, 1043, 21]])
check("Adramelech's return point is the story's, so a game over never takes a player past him back into the tower",
      DATA::SETTINGS.find { |row| row.site == "map:619:2:1" }.values_at(0, 1, 2, 7), [:v, 1002, 19, [[:v, 1001, 17], [:v, 1032, 7]]])
check("the one-way variables hold the areas' events, a quest's steps and counters, but no progress counter, return point or variable an event lowers",
      [[1003, 1032, 1043, 1050, 1202, 1323].all? { |id| DATA::ONE_WAY_VARIABLES.include?(id) },
       [1001, 1002, 1099, 1140, 1141, 1353].any? { |id| DATA::ONE_WAY_VARIABLES.include?(id) }], [true, false])
check("the route return clears the routes' and the Chaos route's story variables", DATA::RETURN_CLEARED, [1144..1200, 1301..1500])
check("such as the first camp's Angel Dance for Ilias's side",
      camps.find { |row| row.id == 930 }.values_at(4, 6, 7), ["1", :ilias, [[:v, 1001, 8], [:s, 2023]]])

check("every vehicle row names the boat, the ship or Galda, at a place with marks",
      DATA::VEHICLES.all? { |row| [0, 1, 2].include?(row.vehicle) && (row.part.nil? || parts.include?(row.part)) && !row.marks.empty? && marks_shaped?(row.marks) }, true)
galda = DATA::VEHICLES.select { |row| row.vehicle == 2 }
first = galda.map { |row| [parts.index(row.part), row.step] }.min
check("Galda comes first in Part 3 once the main story reached step 37, with Mt. Saint Amos among the events there",
      [first, galda.select { |row| [parts.index(row.part), row.step] == first }.map(&:site).include?("map:645:33:1")], [[2, 37], true])
check("and the Escape spell's way out of the Chaos Domain onto Galda gives it nowhere", DATA::VEHICLES.none? { |row| row.site == "ce:31" }, true)

# The generator's rules, read without the game's data. The generator lives in
# MGQ-Paradox-Event-Checker next to this repository; without it, its rules go unchecked here.
generator = File.expand_path("../../../MGQ-Paradox-Event-Checker/Tools/raid_data.rb", __dir__)
if File.exist?(generator)
load generator
tool = RaidData.allocate
place = lambda { |part, step, needs = [], marks = []| RaidData::Place.new(part, step, needs, [], marks, nil) }
check("an earlier part comes before a later one, and the two routes in either order",
      [tool.before?([place.call("2", 30), "a", 0], [place.call("3", 35), "b", 0]), tool.before?([place.call("ad", 5), "a", 0], [place.call("mr", 9), "b", 0]),
       tool.before?([place.call("mr", 9), "a", 0], [place.call("ad", 5), "b", 0])], [true, false, false])
check("within a step, a page that needs more of an area's variable comes later",
      tool.before?([place.call("chaos", 19, [[:v, 1311, 5]]), "a", 0], [place.call("chaos", 19, [[:v, 1311, 6]]), "b", 0]), true)
check("the Level Cap's cap in the Chaos route's free order counts the areas the marks tell",
      [tool.cap_at(place.call("chaos", 21)), tool.cap_at(place.call("chaos", 21, [], [[:v, 1304, 5]])), tool.cap_at(place.call("chaos", 24)),
       tool.cap_at(place.call("chaos", 24, [], [[:v, 1348, 5]])), tool.cap_at(place.call("chaos", 25))], [130, 140, 260, 285, 300])
check("and on a route all of the parts before it", tool.cap_at(place.call("ad", 18)), 70)

names = Array.new(1100, "")
names[908] = "Temp Difficulty Adjustment"
names[1022] = "Ancient Temple Events"
names[1068] = "Northern Undersea Temple Event"
names[1075] = "Ilias Temple White Rabbit"
tool.instance_variable_set(:@names, [[], names])
$personal_variables ||= []
check("a story variable named after a temple is no scratch, unlike a temporary one",
      [tool.story_variable?(1022), tool.story_variable?(1068), tool.story_variable?(1075), tool.story_variable?(908)], [true, true, true, false])
check("so the Silver Orb, given once the temple's event ran, comes to every player of the world",
      DATA::KEY_ITEMS.find { |row| row.item == 542 }.values_at(2, 6, 7), ["map:149:107:1", [[:v, 1001, 30], [:v, 1068, 3]], true])

# A map of the White Rabbit chain, which sets v1075 below Part 2's ending, and a town whose list sets it past.
command = lambda do |code, params|
  Object.new.tap do |each|
    each.instance_variable_set(:@code, code)
    each.instance_variable_set(:@indent, 0)
    each.instance_variable_set(:@parameters, params)
  end
end
ruins = RaidData::Site.new("map:9138:1:1", [command.call(122, [1075, 1075, 0, 0, 9]), command.call(0, [])], nil, 9138, 1, nil, 1)
town = RaidData::Site.new("map:9021:1:1", [command.call(122, [1075, 1075, 0, 0, 20]), command.call(0, [])], nil, 9021, 1, nil, 1)
tool.instance_variable_set(:@paths, {})
tool.instance_variable_set(:@one_way, [1075])
tool.instance_variable_set(:@sites_by_map, { 9138 => [ruins], 9021 => [town] })
tool.instance_variable_set(:@map_steps, { 9138 => [["3", 34]], 9021 => [["2", 25]] })
check("where the story first comes to a map in any part is never past the part ending a story value its lists set comes before, and within a part stays",
      [tool.map_first(9138, nil, 2), tool.map_first(9138, "3", 2), tool.map_first(9021, nil, 2)], [["2", 33], ["3", 34], ["2", 25]])

check("the chests of the job items Amira's side quests ask for are the world's, as those of key items",
      [[[57, 31, "A"], 616], [[588, 9, "A"], 606], [[348, 4, "A"], 614]].map { |key, item| DATA::CHESTS.any? { |row| row.key == key && row.items.include?(item) } }, [true] * 3)

# The ids of the reference install's Library Flags, "Library Flag: ..." and the untranslated rest.
library = [201..420, 5201..5600]
rows = DATA::JOINS + DATA::REMOVALS + DATA::KEY_ITEMS + DATA::REWARDS
check("no row and no part's ending needs a Library Flag, which translations differ in setting",
      (rows.map(&:marks) + DATA::PARTS.map(&:ending)).flatten(1).select { |mark| mark[0] == :s && library.any? { |range| range.include?(mark[1]) } }, [])
check("so Himiko's join in the Black Mansion counts on the community translation too, which never turns on 5352",
      joins_at(757, "map:1813:25:1").map { |join| [join.marks.include?([:s, 5352]), join.ran] }, [[false, true]])
check("an event only a Library Flag told ran is marked by the scene after it, as Radio's join by Adramelech's defeat",
      joins_at(185, "map:174:14:1").map { |join| [join.marks, join.ran] }, [[[[:v, 1001, 17], [:v, 1032, 7]], true]])
check("Monte Carlo's evacuation counts once it ended, not once someone walked into Chaos Monte Carlo, and its talks stay talks",
      [[19, "map:1979:49:1"], [556, "map:1979:59:1"], [601, "map:1979:63:1"]].map { |actor, site| joins_at(actor, site).map { |join| [join.marks.include?([:v, 1305, 6]), join.ran] } },
      [[[true, true]], [[true, false]], [[true, false]]])
check("and the Colosseum's Fighter's Badge comes once the world won its first class, not once someone opened it",
      DATA::KEY_ITEMS.find { |row| row.item == 551 && row.site == "ce:158" }.marks.include?([:v, 701, 1]), true)
switch_names = Array.new(5600, "")
switch_names[2922] = "Library Door"
switch_names[5109] = "Warp Flag: Monte Carlo (Chaos)"
switch_names[5352] = "Library Flag: Black Mansion"
switch_names[5588] = [0x56f3, 0x9451, 0x30d5, 0x30e9, 0x30b0, 0xff1a, 0x521d, 0x671f, 0x88c5, 0x5099].pack("U*")
tool.instance_variable_set(:@names, [switch_names, names])
check("a Library Flag is no story switch, by its English or its untranslated name, unlike a story switch named after the library",
      [tool.story_switch?(2922), tool.story_switch?(5109), tool.story_switch?(5352), tool.story_switch?(5588)], [true, true, false, false])
else
  puts "skipped the generator's rules: #{generator} is missing"
end
