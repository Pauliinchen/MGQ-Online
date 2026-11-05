#----------------------------------------------------------------
#  make_classic.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Recorded from the script test of the last commit that answered the Classic catch-up from engine.rb
#                            - Wrote every call of that test with its answer and what the catch-up reads over each table set into classic_calls.json
#                            - Created
#
#----------------------------------------------------------------

# Checks and writes the golden cases of a Classic party next to this file, classic.json: every call
# of the DLL's topics of the Classic catch-up, the side, the key item loan and how a member plays the
# leader's story that GameScript/Tests/coop_events_test.rb of the last commit whose tests answered
# them from engine.rb makes (old_tests.rb), each once, with the tables engine.rb answered it over,
# what it read of the party, and its answer; of the side's and the story's calls, one per kind of
# request and answer. MGQOnline.Game.Tests replays them against CatchupEngine, SidePick, KeyItemLoan
# and ClassicStory. It also writes classic_calls.json: every distinct call of that test with its
# answer, and what the catch-up reads over each table set (catchup.keys), which
# GameScript/Tests/coop_events_test.rb looks up as the DLL's fixed answers and MGQOnline.Game.Tests
# replays against the C# rules. A recording tool: no test runs against it.
#
# Each case's answer is the one the user's written answers call for, checked by hand, and its "note"
# names that answer. A case already in classic.json keeps its answer and note: a recorded answer that
# differs from it fails, since then engine.rb, or the C# rule it stands in for, went against the
# answers. A case kept one per kind of request and answer keeps its recorded request too, while a
# call of that kind still gives its answer. A new case is written with the note "UNCHECKED" and
# fails until its answer was checked by hand and its note written. Run it again after a rule of
# these changed:
#
#   ruby fixtures/catchup/make_classic.rb

require "json"
require_relative "old_tests"

# The note of a case nobody checked yet.
UNCHECKED = "UNCHECKED"

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

path = File.join(__dir__, "classic.json")
known = File.file?(path) ? JSON.parse(File.read(path))["cases"] : []
# The topics whose every request is a case of its own; of the others one call per kind of request
# and answer is kept.
EACH_REQUEST = %w(catchup.classic catchup.key_loan)

known_by = {}
kinds_by = {}
known.each do |entry|
  known_by[JSON.generate([entry["topic"], entry["request"], entry["party"]])] = entry
  kinds_by[JSON.generate([entry["topic"], entry["request"].keys.sort, entry["answer"]])] ||= entry unless EACH_REQUEST.include?(entry["topic"])
end

$classic_record = []
OldCatchupTests.run("GameScript/Tests/coop_events_test.rb")

sets = []
seen = {}
cases = []
wrong = []
$classic_record.each do |call|
  set = call["tables"] ? (sets.index(call["tables"]) || (sets << call["tables"]).size - 1) : nil
  entry = { "topic" => call["topic"], "tables" => set, "request" => plain_json(call["request"]) }
  entry["party"] = plain_json(call["party"]) if call["party"]
  entry["answer"] = plain_json(call["answer"])
  key = EACH_REQUEST.include?(call["topic"]) ? JSON.generate([entry["topic"], entry["request"], entry["party"]]) :
        JSON.generate([entry["topic"], entry["request"].keys.sort, entry["answer"]])
  next if seen[key]

  seen[key] = true
  checked = known_by[JSON.generate([entry["topic"], entry["request"], entry["party"]])]
  if checked.nil? && kinds_by[key]
    checked = kinds_by[key]
    entry["request"] = checked["request"]
  end
  if checked
    wrong << "#{entry['topic']} (#{checked['note']}): expected #{JSON.generate(checked['answer'])}, answered #{JSON.generate(entry['answer'])}" if checked["answer"] != entry["answer"]
    entry["answer"] = checked["answer"]
    entry["note"] = checked["note"]
  else
    entry["note"] = UNCHECKED
  end
  cases << entry
end

calls = []
called = {}
$classic_record.each do |call|
  entry = { "topic" => call["topic"], "tables" => call["tables"] ? sets.index(call["tables"]) : nil, "request" => plain_json(call["request"]) }
  entry["party"] = plain_json(call["party"]) if call["party"]
  entry["answer"] = plain_json(call["answer"])
  key = JSON.generate(entry)
  next if called[key]

  called[key] = true
  calls << entry
end
lines = []
lines << "{"
lines << "  \"source\": #{JSON.generate("fixtures/catchup/engine.rb over GameScript/Tests/coop_events_test.rb of #{OldCatchupTests::SOURCE_COMMIT}, Ruby #{RUBY_VERSION}")},"
lines << "  \"tables\": [
#{sets.map { |set| "    #{JSON.generate(set)}" }.join(",
")}
  ],"
lines << "  \"keys\": [
#{sets.map { |set| "    #{JSON.generate(plain_json(CatchupEngine.keys(CatchupEngine.read(set))))}" }.join(",
")}
  ],"
lines << "  \"calls\": [
#{calls.map { |entry| "    #{JSON.generate(entry)}" }.join(",
")}
  ]"
lines << "}"
File.write(File.join(__dir__, "classic_calls.json"), lines.join("
") + "
")

lines = []
lines << "{"
lines << "  \"source\": #{JSON.generate("fixtures/catchup/engine.rb over GameScript/Tests/coop_events_test.rb, Ruby #{RUBY_VERSION}; each answer checked by hand against the user's written answers its note names")},"
lines << "  \"tables\": [\n#{sets.map { |set| "    #{JSON.generate(set)}" }.join(",\n")}\n  ],"
lines << "  \"cases\": [\n#{cases.map { |entry| "    #{JSON.generate(entry)}" }.join(",\n")}\n  ]"
lines << "}"
File.write(path, lines.join("\n") + "\n")
unchecked = cases.count { |entry| entry["note"] == UNCHECKED }
puts "#{cases.size} cases over #{sets.size} table sets, #{unchecked} unchecked; #{calls.size} calls"
wrong.each { |line| puts "differs from its checked answer: #{line}" }
exit(1) unless wrong.empty? && unchecked.zero?
