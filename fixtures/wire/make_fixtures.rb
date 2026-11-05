#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Read the codec from a commit that still kept it in the script
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes the battle line codec's golden cases next to this file from battles_sync_wire.rbx as it
# kept the codec before it moved to C# (commit 508f616e, which this generator reads through git,
# so it runs again on later commits; see wire_harness.rb): encode.json (described values and the
# line Wire.line writes) and decode.json (a line and the values Wire.parse reads, nil for a refused
# one), which MGQOnline.Game.Tests checks. A recording tool: no script test runs against it. Run it
# again only when a case changes, on Ruby 3.3:
#
#   ruby fixtures/wire/make_fixtures.rb

require "tempfile"
require_relative "wire_harness"

# The commit whose battles_sync_wire.rbx kept the codec.
SOURCE_COMMIT = "508f616e"

source = `git -C "#{File.expand_path('../..', __dir__)}" show #{SOURCE_COMMIT}:GameScript/Multiplayer/Scripts/battles_sync_wire.rbx`
raise "git could not read battles_sync_wire.rbx of #{SOURCE_COMMIT}" if source.empty?

script = Tempfile.new(["battles_sync_wire", ".rbx"])
script.write(source)
script.close
load script.path
WireHarness.prepare

# Describes an Integer.
#
# @param value [Integer] The number.
# @return [Hash] Its description.
def int(value)
  { "i" => value.to_s }
end

# Describes a Float.
#
# @param value [Float] The number.
# @return [Hash] Its description.
def float(value)
  { "f" => WireHarness.bits(value) }
end

# Each encode case's name and values.
ENCODE = {
  "nothing" => [],
  "scalars" => [nil, true, false, int(0), int(-42)],
  "bignums" => [int(2**31), int(2**70), int(-(2**64) - 1)],
  "floats" => [1.5, 0.0, -0.0, 100.0, 12.25, 1.0 / 3, 2.5e-5, 0.0001, 9.99e-5, 999_999_999_999_999.9, 1e15, 1e16, 1.2345678901234568e17, 5e-324, Float::MAX].map { |value| float(value) },
  "float_specials" => [Float::INFINITY, -Float::INFINITY, Float::NAN].map { |value| float(value) },
  "texts" => ["", "plain", "tab\there", "lines\n\r", "back\\slash", "\\t stays", "日本語 and 😀"].map { |text| { "s" => text } },
  "symbols" => [{ "sym" => "count" }, { "sym" => "with space" }, { "sym" => "tab\tin" }],
  "game_values" => [{ "ref" => "a0" }, { "ref" => "e3" }, { "x" => "count" }, { "x" => nil }, { "k" => 3 }, { "t" => 4 }, { "z" => 5 }, { "w" => 6 }, { "a" => 7 }, { "g" => { "k" => 3 } }, { "g" => nil }],
  "colors" => [{ "c" => [255.0, 128.7, 0.0, 255.0].map { |channel| WireHarness.bits(channel) } }, { "n" => [-255.5, 0.0, 10.0, -0.9].map { |channel| WireHarness.bits(channel) } }],
  "lists" => [[int(1), [int(2), [nil]]], [], { "s" => "after" }],
  "result" => [{ "result" => [["hp_damage", int(30)], ["critical", true], ["added_states", [int(1), int(2)]], ["battler", { "ref" => "e1" }]] }],
}.freeze

# The longest line Wire.parse reads.
MAX_BYTES = MGQ_MpBattlesSync::Wire::MAX_LINE_BYTES

# Each decode case's name and line; a Hash gives the line as hex or repeated.
DECODE = {
  "empty" => "",
  "only_tabs" => "\t\t",
  "scalars" => "~\t+\t-\ti42\ti-7",
  "empty_tokens" => "\ti1\t\ti2\t\t",
  "unknown_kinds" => "q5\t~x\té5\t*",
  "bignums" => "i123456789012345678901234567890\ti-9223372036854775809",
  "integer_texts" => "i\ti 5\ti0d12\ti1_000\ti1__0\ti12abc\ti-\ti+-1\ti0x1F\ti0_0_7\ti_1",
  "floats" => "f1.5\tf1.0e-05\tf-0.0\tf1.0e+16\tf12.25\tf1e400\tf-1e-400\tf2.5e-324",
  "float_texts" => "fInfinity\tfNaN\tf\tf.5\tf5.\tf1.e5\tf 2.5\tf1.5e\tf1.5xyz",
  "float_cleaning" => "f1_000.5\tf1__0.5\tf1._5\tf1.5e3_0\tf1.5.5\tf#{'1' * 100}.5x\tf#{'1' * 100}.5",
  "nul_ends_numbers" => "f1.5\u00005\ti1\u00005\tf1_\u00002\ts\u0000",
  "hex_floats" => "f0x1A\tf-0x1A\tf-0x1.8p1\tf-0x1.8\tf-0x1p-2\tf+0x1_0p0\tf-0x0",
  "texts" => "shello\ts\tsa\\tb\\nc\\rd\\\\e\ts\\\\t\tsend\\\ts\\x\tsé日本😀",
  "symbols" => ":count\t:never_made_qq\t:a-b\t:#{'a' * 40}\t:#{'a' * 41}\t:\t:co\\tunt\t:é",
  "battlers" => "@a0\t@e3\t@\t@\\t",
  "actions" => "xcount\tx\txnever_made_qq\txa-b",
  "database" => "k1\tk19\tk20\tk0\tk-1\tt9\tz4\tw2\ta1\tk 3\tk3abc\tk99999999999999999999",
  "equipped" => "gk5\tgw2\tga1\tg~\tgs5\tgk99\tg\tgi3",
  "colors" => "c255,128,0,255\tc1.5,2\tc\tn-255,0,10,0\tc1,2,3,4,5\tc,,7\tc1,,",
  "lists" => "[\ti1\t[\t]\t]\ti2",
  "result" => "{\t:hp_damage\ti30\t:critical\t+\t:never_made_qq\ti1\tsused\ti2\t:battler\t@a1\t:count\ti3\t}",
  "result_twice_and_odd" => "{\t:hp_damage\ti1\t:hp_damage\ti2\t:missed\t}",
  "result_nested" => "{\t:added_states\t[\tz1\t{\t:used\t+\t}\t]\t}",
  "crossed_brackets" => "[\t:used\t+\t}\t{\ti2\t]",
  "deepest" => (["["] * 8 + ["]"] * 8).join("\t"),
  "too_deep" => (["["] * 9 + ["]"] * 9).join("\t"),
  "unopened" => "i1\t]",
  "unopened_result" => "}",
  "unclosed" => "[\ti1",
  "not_utf8" => { "line_hex" => "73ff" },
  "not_utf8_token" => { "line_hex" => "69310973c3" },
  "surrogate" => { "line_hex" => "73eda080" },
  "longest" => { "line" => "\t", "repeat" => MAX_BYTES },
  "too_long" => { "line" => "\t", "repeat" => MAX_BYTES + 1 },
}.freeze

decode = DECODE.map do |name, line|
  entry = line.is_a?(Hash) ? line : { "line" => line }
  read = MGQ_MpBattlesSync::Wire.parse(WireHarness.line_of(entry)) { |ref| Game_Battler.new(ref) }
  { "name" => name }.merge(entry).merge("values" => read && read.map { |value| WireHarness.describe(value) })
end

encode = ENCODE.map { |name, values| { "name" => name, "values" => values, "line" => MGQ_MpBattlesSync::Wire.line(values.map { |value| WireHarness.build(value) }) } }

# Writes a fixture file with one case per line.
#
# @param name [String] The file's name.
# @param head [Hash] What comes before the cases.
# @param cases [Array<Hash>] The cases.
def write_cases(name, head, cases)
  fields = head.map { |key, value| "  #{JSON.generate(key)}: #{JSON.generate(value)},\n" }.join
  text = "{\n#{fields}  \"cases\": [\n    #{cases.map { |entry| JSON.generate(entry) }.join(",\n    ")}\n  ]\n}\n"
  File.write(File.join(__dir__, name), text, mode: "wb")
end

write_cases("decode.json", { "game" => WIRE_GAME }, decode)
write_cases("encode.json", {}, encode)
puts "Wrote #{decode.size} decode and #{encode.size} encode cases."
