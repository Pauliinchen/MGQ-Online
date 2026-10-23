#----------------------------------------------------------------
#  wire_fixtures_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Checks battles_sync_wire.rbx against the golden cases in fixtures/wire, which
# MGQOnline.Game.Tests checks the C# codec against too, so the two never drift apart. A case that
# fails here means the script changed: write the cases again (fixtures/wire/make_fixtures.rb) and
# change the C# codec to match.

require_relative "support"
require_relative "../../fixtures/wire/wire_harness"

# Reads one of the fixture files.
#
# @param name [String] The file's name.
# @return [Hash] Its content.
def wire_cases(name)
  JSON.parse(File.read(File.expand_path("../../fixtures/wire/#{name}", __dir__), :encoding => "UTF-8"))
end

decode = wire_cases("decode.json")
check("the decode cases know what the harness knows", decode["game"], WIRE_GAME)
decode["cases"].each do |entry|
  check("Wire.parse reads #{entry['name']} as the fixture says", WireHarness.decode(WireHarness.line_of(entry)), entry["values"])
end

wire_cases("encode.json")["cases"].each do |entry|
  check("Wire.line writes #{entry['name']} as the fixture says", WireHarness.encode(entry["values"]), entry["line"])
end
