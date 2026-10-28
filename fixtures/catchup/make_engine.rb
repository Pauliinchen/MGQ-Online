#----------------------------------------------------------------
#  make_engine.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the catch-up's decisions next to this file, engine.json: every call of
# the DLL's catch-up topics the script tests make (GameScript/Tests/world_catchup_test.rb), each
# once, with the tables and the save's notes the engine of engine.rb answered it over and its
# answer. A table that holds the generated rows of fixtures/catchup/generated is named by "generated"
# alone. MGQOnline.Game.Tests replays them against CatchupEngine. Run it again after a rule of the
# engine or a test of the catch-up changed:
#
#   ruby fixtures/catchup/make_engine.rb

require "json"

# Writes a plain value as JSON takes it: a Hash with a key that is no String as {"#pairs" => [[key,
# value], ...]}.
#
# @param value [Object] The value.
# @return [Object] The value JSON writes.
def plain_json(value)
  case value
  when Hash
    return Hash[value.map { |key, item| [key, plain_json(item)] }] if value.keys.all? { |key| key.is_a?(String) }

    { "#pairs" => value.map { |key, item| [plain_json(key), plain_json(item)] } }
  when Array then value.map { |item| plain_json(item) }
  else value
  end
end

$catchup_record = []
load File.expand_path("../../GameScript/Tests/world_catchup_test.rb", __dir__)

generated = {}
Dir[File.join(__dir__, "generated", "*.json")].each { |file| generated[File.basename(file, ".json")] = JSON.parse(File.read(file, :encoding => "UTF-8"))["rows"] }
sets = []
seen = {}
cases = []
$catchup_record.each do |call|
  tables = Hash[call["tables"].sort.map { |table, rows| [table, generated[table] == rows ? "generated" : rows] }]
  set = sets.index(tables) || (sets << tables).size - 1
  entry = { "topic" => call["topic"], "tables" => set, "ledger" => plain_json(call["ledger"]), "request" => plain_json(call["request"]), "answer" => plain_json(call["answer"]) }
  key = JSON.generate(entry)
  next if seen[key]

  seen[key] = true
  cases << entry
end

lines = []
lines << "{"
lines << "  \"source\": #{JSON.generate("fixtures/catchup/engine.rb over GameScript/Tests/world_catchup_test.rb, Ruby #{RUBY_VERSION}")},"
lines << "  \"tables\": [\n#{sets.map { |set| "    #{JSON.generate(set)}" }.join(",\n")}\n  ],"
lines << "  \"cases\": [\n#{cases.map { |entry| "    #{JSON.generate(entry)}" }.join(",\n")}\n  ]"
lines << "}"
File.write(File.join(__dir__, "engine.json"), lines.join("\n") + "\n")
puts "#{cases.size} cases over #{sets.size} table sets"
