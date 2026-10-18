#----------------------------------------------------------------
#  raid_freeze_data_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-17: Created
#
#----------------------------------------------------------------

# Covers battles_raid_freeze_data.rbx, which raid_freeze_data.rb of MGQ-Paradox-Event-Checker writes
# from the game's data, with battles_raid_bosses.rbx: the story's boss battle sites of every raid
# boss, the Hades halls and the Colosseum left out, the preambles, the cutscene fights and their
# ways in, the callers of the common events and what the post-defeat processing writes. Also covers
# the generator's rules that need no game data.

require_relative "support"

load File.join(SCRIPTS_DIR, "battles_raid_bosses.rbx")
load File.join(SCRIPTS_DIR, "battles_raid_freeze_data.rbx")
# The freeze data under test.
DATA = MGQ_MpRaidFreezeData
# The story's boss troops.
BOSSES = MGQ_MpRaidBosses

# The Great Decision's fights, which fight no pool (battles_raid_pool.rbx UNPOOLED).
UNPOOLED = [1507, 1509]

# The Colosseum's common events, which only the Colosseum (common event 158) reaches.
COLOSSEUM_EVENTS = [160, 164, 165, 166, 167, 177, 183]

# Finds a site row of a troop.
#
# @param troop [Integer] The troop.
# @param key [String] The site key.
# @return [Array, nil] The row.
def site(troop, key)
  (DATA::SITES[troop] || []).find { |row| row[0] == key }
end

rows = DATA::SITES.values.flatten(1)
check("every troop of the sites is a story boss", DATA::SITES.keys.all? { |troop| BOSSES.boss?(troop) }, true)
pooled = BOSSES::TROOPS.keys.select { |troop| BOSSES::TROOPS[troop][2] != false && !UNPOOLED.include?(troop) } + BOSSES::OPTIONAL.keys
check("every last phase of a pooled fight and every optional boss has a site", pooled - DATA::SITES.keys, [])
check("and so do the earlier phases and the Great Decision's fights", BOSSES::TROOPS.keys - DATA::SITES.keys, [])
check("every row has a site key, an index, an indent, a preamble start and the cutscene flag",
      rows.all? { |row| row.size == 5 && row[0] =~ /\A(map:\d+:\d+:\d+|ce:\d+)\z/ && row[1..3].all? { |n| n.is_a?(Integer) } && [true, false].include?(row[4]) }, true)
check("no site lies on a Hades hall", rows.select { |row| row[0] =~ /\Amap:(\d+):/ && DATA::EXCLUDED_MAPS.include?($1.to_i) }, [])
check("the Hades halls are the rematch hall and the hall of the defeated", DATA::EXCLUDED_MAPS, [154, 576])
check("no site is a Colosseum fight", rows.select { |row| row[0] =~ /\Ace:(\d+)\z/ && COLOSSEUM_EVENTS.include?($1.to_i) }, [])
check("Heaven's Gate under the Tartarus folder stays a story site", site(1517, "map:405:2:1").nil?, false)
check("every preamble starts at most three commands before its battle", rows.all? { |row| row[3] <= row[1] && row[1] - row[3] <= 3 }, true)
check("the rows of a troop are sorted by key, common events first", DATA::SITES.values.all? do |list|
  sort_keys = list.map { |row| [row[0].start_with?("ce:") ? 0 : 1] + row[0].scan(/\d+/).map(&:to_i) + [row[1]] }
  sort_keys == sort_keys.sort
end, true)
check("the troops come in order", DATA::SITES.keys, DATA::SITES.keys.sort)

check("the four bandits' last fight", DATA::SITES[29], [["map:290:7:1", 24, 0, 23, false]])
check("the Sphinx fights without a preamble, on two pages, in branches", DATA::SITES[247],
      [["map:117:6:1", 261, 1, 261, false], ["map:117:6:2", 30, 3, 30, false]])
check("the Spider Princess fights in a common event and on a map page", DATA::SITES[807],
      [["ce:347", 270, 1, 268, false], ["map:214:42:1", 48, 2, 46, false]])
check("Sonya Mazda fights at the Ilias Temple Ruins in Alice's branch", DATA::SITES[868], [["map:138:13:1", 666, 1, 663, false]])
check("Mainyu on Ilias's side of the same page", DATA::SITES[869], [["map:138:13:1", 752, 1, 749, false]])
check("Sonya Chaos fights on a cutscene map of each side", DATA::SITES[870],
      [["map:728:12:1", 53, 0, 51, true], ["map:749:13:1", 49, 0, 47, true]])
check("a common event without its leading mark in the file counts the mark the game adds", DATA::SITES[1590], [["ce:409", 124, 0, 122, false]])
check("a site on a map from 1000 on", site(1544, "map:1869:27:1"), ["map:1869:27:1", 190, 0, 188, false])
check("sites from 1000 on are many, as the Final Chapter's", rows.count { |row| row[0] =~ /\Amap:(\d+):/ && $1.to_i >= 1000 } > 50, true)

scene_keys = rows.select { |row| row[4] }.map(&:first).uniq.sort
check("the cutscene sites", scene_keys, %w[map:587:5:1 map:616:4:1 map:722:263:2 map:723:56:1 map:728:12:1 map:742:53:1 map:749:13:1])
check("every cutscene site has its way in, and only those", DATA::SCENES.keys.sort, scene_keys)
check("no common event's site counts as a cutscene site", rows.none? { |row| row[0].start_with?("ce:") && row[4] }, true)
check("every way in has field pages, a side switch or none, and a spot", DATA::SCENES.values.all? do |sources, switch, entry|
  !sources.empty? && sources.all? { |source| source.size == 4 && source.all? { |n| n.is_a?(Integer) } && !DATA::SCENE_MAPS.include?(source[0]) } &&
    (switch.nil? || switch.is_a?(Integer)) && entry.size == 4 && entry.all? { |n| n.is_a?(Integer) }
end, true)
check("each way in lands on its site's map", DATA::SCENES.all? { |key, (_, _, entry)| key.split(":")[1].to_i == entry[0] }, true)
check("Sonya Chaos on Alice's side: from the Ilias Temple Ruins in the branch of switch 4", DATA::SCENES["map:728:12:1"], [[[138, 13, 32, 8]], 4, [728, 0, 0, 0]])
check("and on Ilias's side in the branch of switch 5", DATA::SCENES["map:749:13:1"], [[[138, 13, 32, 8]], 5, [749, 1, 0, 0]])
check("Morrigan from Iliasport", DATA::SCENES["map:587:5:1"], [[[139, 37, 10, 6]], nil, [587, 1, 1, 0]])
check("Astaroth from the world map, through the Luddite Village's first cutscene", DATA::SCENES["map:616:4:1"][0].first, [2, 39, 257, 249])
check("and into its second", DATA::SCENES["map:616:4:1"][1..2], [nil, [616, 9, 14, 8]])
check("the Queen Fairy from the world map and through a common event from the Succubus Village",
      DATA::SCENES["map:742:53:1"], [[[2, 282, 328, 186], [2, 284, 329, 186], [515, 29, 28, 11], [515, 30, 30, 10]], nil, [742, 38, 58, 8]])

check("every common event of a site names its callers, and only those",
      DATA::CALLERS.keys.sort, rows.map(&:first).grep(/\Ace:/).map { |key| key[3..].to_i }.uniq.sort)
check("every caller is a map page", DATA::CALLERS.values.flatten.all? { |key| key =~ /\Amap:\d+:\d+:\d+\z/ }, true)
check("the Queen Ant's common event from the four pages of its map", DATA::CALLERS[338], ["map:177:18:1", "map:177:19:1", "map:177:20:1", "map:177:25:1"])
check("the Spider Princess's from her page", DATA::CALLERS[347], ["map:214:42:1"])
check("no caller lies on a Hades hall", DATA::CALLERS.values.flatten.none? { |key| DATA::EXCLUDED_MAPS.include?(key.split(":")[1].to_i) }, true)

check("the fights each side plays in the other's stead: Gnosis and Zion, Sonya Mazda and Mainyu",
      DATA::ALTERNATIVES, { 672 => [673], 673 => [672], 868 => [869], 869 => [868] })
check("fights one after the other on one page are no alternatives, as Black Alice and Idea Lukas",
      [DATA::ALTERNATIVES[2176], DATA::ALTERNATIVES[871], DATA::ALTERNATIVES[837]], [nil, nil, nil])

check("the cutscene maps hold Sonya Chaos's chain", [728, 746, 747, 749].all? { |map| DATA::SCENE_MAPS.include?(map) }, true)
check("but not the Ilias Temple Ruins", DATA::SCENE_MAPS.include?(138), false)
check("and the cutscene maps from 1000 on", DATA::SCENE_MAPS.include?(1544), true)
check("the cutscene maps come in order", DATA::SCENE_MAPS, DATA::SCENE_MAPS.sort.uniq)

check("the post-defeat processing's common events", DATA::DEFEAT_EVENTS, [11, 112, 900, 902, 3000])
expected_switches = [22, 23, 27, *31..39, 41, 52, 54, *61..72, *81..87, 97, 100, *427..441, 505, 507, 509, 2333, 2335]
check("the switches it writes", DATA::DEFEAT_WRITES[:switches], expected_switches)
check("the variables it writes", DATA::DEFEAT_WRITES[:variables], [11, 14, *41..49, 121, 122, 131, 156, 157, 902])
check("it leaves the story's own values alone", [DATA::DEFEAT_WRITES[:variables].include?(1075), DATA::DEFEAT_WRITES[:switches].include?(2307)], [false, false])
check("the preamble's codes", DATA::PREAMBLE_CODES, [132, 133, 283])

# The generator's rules, read without the game's data. The generator lives in
# MGQ-Paradox-Event-Checker next to this repository; without it, its rules go unchecked here.
generator = File.expand_path("../../../MGQ-Paradox-Event-Checker/Tools/raid_freeze_data.rb", __dir__)
if File.exist?(generator)
  load generator
  tool = RaidFreezeData.allocate
  command = lambda { |code, indent, *params| RaidFreezeData::Command.new(code, indent, params) }
  list = [command.call(241, 0), command.call(132, 1), command.call(121, 1, 22, 22, 0), command.call(283, 1), command.call(301, 1, 0, 868, false, false)]
  check("the preamble takes the battle BGM, the boss switch and the battleback at the battle's indent", tool.send(:preamble, list, 4), 1)
  list = [command.call(132, 0), command.call(121, 1, 22, 22, 1), command.call(301, 1, 0, 868, false, false)]
  check("but not the boss switch turned off, nor a command of another indent", tool.send(:preamble, list, 2), 2)
  list = [command.call(121, 0, 20, 25, 0), command.call(301, 0, 0, 868, false, false)]
  check("a range of switches turned on that holds the boss switch counts", tool.send(:preamble, list, 1), 0)

  list = [command.call(111, 0, 0, 4, 0), command.call(111, 1, 1, 1075, 0, 16, 1), command.call(201, 2, 0, 746, 0, 0, 0, 2),
          command.call(0, 2), command.call(412, 1), command.call(0, 1), command.call(411, 0), command.call(201, 1, 0, 747, 0, 0, 0, 2)]
  check("a transfer's side switch is the innermost switch branch around it", tool.send(:enclosing_switch, list, 2), 4)
  check("but none in a switch branch's else", tool.send(:enclosing_switch, list, 7), nil)

  list = [command.call(111, 0, 0, 4, 0), command.call(111, 1, 0, 31, 0), command.call(301, 2, 0, 868, false, false), command.call(0, 2),
          command.call(412, 1), command.call(0, 1), command.call(412, 0), command.call(301, 0, 0, 870, false, false),
          command.call(111, 0, 0, 5, 0), command.call(301, 1, 0, 869, false, false)]
  tool.instance_variable_set(:@runs, { "map:138:13:1" => RaidFreezeData::Run.new("map:138:13:1", list, 138, 13, 32, 8, 0) })
  tool.instance_variable_set(:@sites, { 868 => [["map:138:13:1", 2]], 869 => [["map:138:13:1", 9]], 870 => [["map:138:13:1", 7]] })
  check("a battle's side is the side switch branch around it, past other branches",
        [2, 7, 9].map { |index| tool.send(:enclosing_side, list, index) }, [4, nil, 5])
  check("the fights of the two sides on one page are alternatives, the fight after them none",
        tool.send(:find_alternatives), { 868 => [869], 869 => [868] })

  run = RaidFreezeData::Run.new("map:1200:5:1", [command.call(201, 0, 0, 88, 3, 4, 2, 0), command.call(355, 0, "forced_transfer(154, 9, 12)")], 1200, 5, 0, 0, 0)
  check("a transfer from a map from 1000 on lands in that map's folder, a forced transfer where it names",
        tool.send(:transfers_of, run, 1200).map { |transfer| transfer.to_a[2..] }, [[1088, 3, 4, 2], [154, 9, 12, 0]])
  check("and from a map below 1000 where it names", tool.send(:transfers_of, run, 138).map(&:target), [88, 154])

  check("site keys sort common events first, then by their numbers",
        %w[map:290:7:1 ce:409 map:1869:27:1 map:117:6:2 map:117:6:1].sort_by { |key| tool.send(:natural, key) },
        %w[ce:409 map:117:6:1 map:117:6:2 map:290:7:1 map:1869:27:1])
end
