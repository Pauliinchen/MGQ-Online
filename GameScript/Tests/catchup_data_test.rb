#----------------------------------------------------------------
#  catchup_data_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Checked that a story variable named after a temple is no scratch and that the Silver Orb comes to every player of the world
#                            - Created
#
#----------------------------------------------------------------

# Covers world_catchup_data.rbx, which GameScript/Tools/raid_data.rb writes from the game's data: the
# shape of its tables, the parts and their gates as the relay splits the story, and key rows such as
# Sonya's and Nuruko's Chaos returns. Also covers the generator's rules that need no game data: the
# order of places and the Level Cap's cap a given-back companion joins at.

require_relative "support"

load File.join(SCRIPTS_DIR, "world_catchup_data.rbx")
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
check("a town's companion who joins on a talk only shows the event there to play, a story join that it ran",
      [joins_at(553, "map:140:25:1")[0].ran, sonya[0].ran, DATA::REWARDS.find { |row| row.id == 930 && row.site =~ /\Amap:406:/ }.ran], [false, true, true])
granberia = [DATA::JOINS, DATA::REMOVALS].map { |rows| rows.find { |row| row.actor == 19 && row.site == "map:483:86:1" }.index }
check("Granberia joins and then leaves in one event at Part 2's step 24, in that order", granberia[0] < granberia[1], true)
orb = DATA::KEY_ITEMS.select { |row| row.item == 596 && row.part.nil? }.map(&:amount)
check("an item given and taken with no step between comes first, then goes", orb, [1, -1])

check("the chests that hold key items are the story's 25", DATA::CHESTS.size, 25)
check("the Ghost Ship's Purple Orb chest is one of them", DATA::CHESTS.find { |chest| chest.key == [371, 12, "A"] }.items, [541])
check("every key item has an amount and marks", DATA::KEY_ITEMS.all? { |row| row.item.is_a?(Integer) && row.amount != 0 && marks_shaped?(row.marks) }, true)
check("Marcellus' Letter comes with the main story's step 11", DATA::KEY_ITEMS.find { |row| row.item == 510 }.values_at(2, 3, 4), ["map:311:7:1", "1", 11])

skills = DATA::REWARDS.select { |row| row.kind == :skill }
check("the rewards hold every story skill once at least", skills.map(&:id).uniq.size, 43)
camps = skills.select { |row| row.site =~ /\Amap:(406|523|604|711|736|741):7:/ }
check("the six camps' skills have explicit marks", [camps.map { |row| row.site[/\Amap:\d+/] }.uniq.size, camps.all? { |row| !row.marks.empty? }], [6, true])
check("such as the first camp's Angel Dance for Ilias's side",
      camps.find { |row| row.id == 930 }.values_at(4, 6, 7), ["1", :ilias, [[:v, 1001, 8], [:s, 2023]]])

# The generator's rules, read without the game's data.
load File.expand_path("../Tools/raid_data.rb", __dir__)
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
