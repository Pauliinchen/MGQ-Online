#----------------------------------------------------------------
#  make_rows.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Recorded the cases from the catch-up engine of engine.rb, as the script's decisions moved to it
#                            - Created
#
#----------------------------------------------------------------

# Writes the golden cases of the catch-up's row rules next to this file, rows.json, from the
# catch-up engine as world_catchup.rbx decided it (engine.rb) over the generated tables of
# world_catchup_data.rbx in fixtures/catchup/generated and the relay's seed rules, with the choices'
# outcomes the DLL names a Raid World player's own, as the script tests answer them
# (GameScript/Tests/choices_support.rb): for stories at places of the story, which rows of each
# table the story is past (passed?), alone
# and with the world's story (passed_any?), which key items a later row took back (taken_since?),
# which companions are on a visit (visiting?), which joins a removal takes back (taking_back), which
# removals come after which joins of the same companion (after?), and where a player moves on to
# (next_part). MGQOnline.Game.Tests replays them against StoryRows. Run it again only when a case
# is added or the rules changed:
#
#   ruby fixtures/catchup/make_rows.rb

require "json"
require_relative "../../GameScript/Tests/catchup_support"

# The generated tables and the relay's seed rules, as the DLL reads them with the story mapping.
table_rows = {}
Dir[File.join(__dir__, "generated", "*.json")].each { |file| table_rows[File.basename(file, ".json")] = JSON.parse(File.read(file, :encoding => "UTF-8"))["rows"] }
%w(rules counts companion_values).each { |table| table_rows[table] = seed_rows(table) }
TABLE_SET = CatchupEngine.read(table_rows)

# The choices' outcomes, which only the player's own story holds.
CHOICES = ChoicesStandIn.personal("raid" => true, "own" => nil)

# Builds a story as the game's own data holds it: switches and self switches on, variables set.
#
# @param variables [Hash{Integer => Integer}] The variables set.
# @param switches [Array<Integer>] The switches on.
# @param selfs [Array<Array>] The self switches on, each map, event and letter.
# @return [Array] The switches, variables and self switches.
def story_of(variables, switches, selfs = [])
  switch_data = []
  switches.each { |id| switch_data[id] = true }
  variable_data = []
  variables.each { |id, value| variable_data[id] = value }
  self_data = {}
  selfs.each { |key| self_data[key] = true }
  [switch_data, variable_data, self_data]
end

# Writes a story as the cases hold it.
#
# @param story [Array, nil] The story, nil for none.
# @return [Hash, nil] "s" (the switches on), "v" (each variable set with its value) and "ss" (the
#   self switches on).
def written(story)
  return nil unless story

  switches = []
  story[0].each_with_index { |value, id| switches << id if value }
  variables = []
  story[1].each_with_index { |value, id| variables << [id, value] unless value.nil? }
  { "s" => switches, "v" => variables, "ss" => story[2].keys.select { |key| story[2][key] } }
end

# The tables the cases look at, by the name the relay's seed gives each.
TABLES = {
  "joins" => TABLE_SET.joins, "removals" => TABLE_SET.removals, "key_items" => TABLE_SET.key_items, "rewards" => TABLE_SET.rewards, "lessons" => TABLE_SET.lessons,
  "class_levels" => TABLE_SET.class_levels, "settings" => TABLE_SET.settings, "vehicles" => TABLE_SET.vehicles, "actor_changes" => TABLE_SET.actor_changes,
}

# The stories of the cases: a name, the player's own story, the world's (nil for none) and the
# side the save notes (nil for none).
CASES = [
  ["a new game whose setup ran: the main story at 0", story_of({ 1001 => 0 }, []), nil, nil],
  ["a story with nothing set at all: a mark of a variable at 0 does not hold", story_of({}, [2010]), nil, nil],
  ["Part 1 on Alice's side, Sonya met", story_of({ 1001 => 7, 1043 => 21, 1056 => 5, 1061 => 3 }, [4, 2010, 5001, 2005, 2018, 5002], [[5, 27, "A"]]), nil, nil],
  ["Part 1 on Ilias's side at the same place", story_of({ 1001 => 7, 1043 => 21 }, [5, 2010, 5001]), nil, nil],
  ["Part 1 further on, the save noting Ilias's side while the switches say Alice", story_of({ 1001 => 12, 1041 => 3, 1021 => 2, 1093 => 4 }, [4, 2116]), nil, "ilias"],
  ["Part 2 with the world's story further and a choice the world made", story_of({ 1001 => 24, 1052 => 6, 1062 => 5, 1215 => 3, 1214 => 1 }, [4, 2961]),
   story_of({ 1001 => 33, 1075 => 14, 1052 => 6, 1062 => 5, 1215 => 4, 1214 => 1, 1069 => 8, 1084 => 3 }, [4, 2096, 7017, 2095, 2138, 2961, 2435], [[127, 81, "A"], [2, 286, "A"]]), nil],
  ["a route under way, another route cleared", story_of({ 1001 => 40, 1141 => 18, 1162 => 3, 1142 => 0 }, [4, 2485, 2486, 2487, 7097]), nil, "alice"],
  ["Part 3 with the world on the Chaos route", story_of({ 1001 => 39, 1075 => 14 }, [4, 2485, 2486, 2487]),
   story_of({ 1001 => 40, 1143 => 21, 1302 => 8, 1303 => 1, 1323 => 4, 1312 => 3, 1353 => 15 }, [4, 2485, 2486, 2487, 3206, 3228, 3229, 5131, 3193]), nil],
  ["a first playthrough past Monte Carlo and the Arena", story_of({ 1001 => 24, 1052 => 6 }, [4]), story_of({ 1001 => 30, 1052 => 6, 1070 => 1, 1071 => 1, 1072 => 1, 1073 => 1 }, [4]), nil],
  ["a companion along on a visit, the Arena's final ahead", story_of({ 1001 => 24, 1052 => 5, 1063 => 2 }, [4]), nil, nil],
]

# Starts a look of the engine at a case's stories, with the side the save notes.
#
# @param own [Array] The player's story.
# @param told [Array, nil] The world's story, nil for none.
# @param side [String, nil] The side the save notes.
# @return [CatchupEngine::Look] The look, whose own and told stories are its own copies.
def look_at(own, told, side)
  host = CatchupEngine::Host.new
  host.ledger = { "world" => "", "done" => {}, "side" => side }
  CatchupEngine::Look.new(host, TABLE_SET, "world" => "", "own" => written(own), "told" => written(told))
end

# Lists the indexes of a table's rows a story is past.
#
# @param look [CatchupEngine::Look] The look.
# @param rows [Array<Struct>] The table.
# @param story [Array] The story.
# @param own [Array] The player's own story.
# @return [Array<Integer>] The indexes.
def passed_rows(look, rows, story, own)
  rows.each_index.select { |index| look.send(:passed?, rows[index], story, own) }
end

cases = CASES.map do |name, own_story, told_story, side|
  look = look_at(own_story, told_story, side)
  own = look.instance_variable_get(:@own)
  told = look.instance_variable_get(:@told)
  entry = { "name" => name, "own" => written(own_story), "told" => written(told_story), "side" => side, "part" => look.send(:story_part, own), "told_part" => told && look.send(:story_part, told) }
  entry["passed"] = Hash[TABLES.map { |table, rows| [table, passed_rows(look, rows, own, own)] }]
  entry["passed_told"] = told ? Hash[TABLES.map { |table, rows| [table, passed_rows(look, rows, told, own)] }] : nil
  key_items = TABLE_SET.key_items
  giving = key_items.each_index.select { |index| key_items[index].amount > 0 }
  entry["taken_since"] = giving.select { |index| look.send(:taken_since?, key_items[index], own, own) }
  entry["taken_since_told"] = told ? giving.select { |index| look.send(:taken_since?, key_items[index], told, own) } : nil
  actors = TABLE_SET.joins.map { |row| row.actor }.uniq.sort
  entry["visiting"] = actors.select { |id| look.send(:visiting?, id, own) }
  entry
end

look = look_at([[], [], {}], nil, nil)
joins = TABLE_SET.joins
removals = TABLE_SET.removals
taking_back = joins.each_index.map do |index|
  found = look.send(:taking_back, joins[index]).map { |removal| removals.index { |row| row.equal?(removal) } }
  found.empty? ? nil : [index, found]
end.compact

after = removals.each_index.map do |index|
  [index, joins.each_index.select { |join| joins[join].actor == removals[index].actor && look.send(:after?, removals[index], joins[join]) }]
end

NEXT_PARTS = [
  ["1", { "part" => "3", "done" => [], "checkpoints" => %w(1 2) }],
  ["1", { "part" => "2", "done" => [], "checkpoints" => %w(1) }],
  ["1", { "part" => "3", "done" => [], "checkpoints" => %w(1) }],
  ["2", { "part" => "ad", "done" => %w(mr), "checkpoints" => %w(1 2 3) }],
  ["mr", { "part" => "ad", "done" => %w(mr), "checkpoints" => %w(1 2 3) }],
  ["3", { "part" => "chaos", "done" => %w(ad), "checkpoints" => %w(3) }],
  ["ad", { "part" => "ad", "done" => [], "checkpoints" => [] }],
  ["chaos", { "part" => "3", "done" => [], "checkpoints" => %w(1 2) }],
  ["3", { "part" => "3", "done" => %w(ad), "checkpoints" => %w(1 2 3 ad) }],
  ["3", { "part" => "mr", "done" => %w(ad), "checkpoints" => %w(1 2 3 ad) }],
  ["2", { "part" => "mr", "done" => %w(ad), "checkpoints" => %w(1 2 3 ad) }],
  ["ad", { "part" => "mr", "done" => %w(ad), "checkpoints" => %w(1 2 3 ad) }],
  ["3", { "part" => "chaos", "done" => %w(ad mr), "checkpoints" => %w(1 2 3 ad mr) }],
]
next_parts = NEXT_PARTS.map do |from, world|
  { "from" => from, "world" => world, "parts" => look.send(:world_parts, world), "to" => look.send(:next_part, from, world).to_s }
end

lines = []
lines << "{"
lines << "  \"source\": #{JSON.generate("fixtures/catchup/engine.rb, Ruby #{RUBY_VERSION}")},"
lines << "  \"choice_keys\": #{JSON.generate('switches' => CHOICES["s"].sort, 'variables' => CHOICES["v"].sort)},"
lines << "  \"taking_back\": [\n#{taking_back.map { |entry| "    #{JSON.generate(entry)}" }.join(",\n")}\n  ],"
lines << "  \"after\": [\n#{after.map { |entry| "    #{JSON.generate(entry)}" }.join(",\n")}\n  ],"
lines << "  \"next_parts\": [\n#{next_parts.map { |entry| "    #{JSON.generate(entry)}" }.join(",\n")}\n  ],"
lines << "  \"cases\": [\n#{cases.map { |entry| "    #{JSON.generate(entry)}" }.join(",\n")}\n  ]"
lines << "}"
File.write(File.join(__dir__, "rows.json"), lines.join("\n") + "\n")
puts "#{cases.size} cases, #{taking_back.size} temporary joins, #{after.size} removals, #{next_parts.size} moves"
