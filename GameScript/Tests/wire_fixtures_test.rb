#----------------------------------------------------------------
#  wire_fixtures_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Checked the values the script hands over and the objects it makes, through the codec's stand-in
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Checks the way of a battle line through the scripts against the golden cases in fixtures/wire,
# which battles_sync_wire.rbx wrote before the codec moved to C# and MGQOnline.Game.Tests checks the
# C# codec against: the game's values the script hands over, written by the codec's stand-in
# (wire_support.rb), give the line the old script wrote, and a line the stand-in reads, which takes
# every symbol, field and entry as the DLL does for the scripts, gives the script the objects the
# old script read against the game the cases share.

require_relative "support"
require_relative "wire_support"
require_relative "../../fixtures/wire/wire_harness"

load File.join(SCRIPTS_DIR, "battles_sync_wire.rbx")
WireHarness.prepare

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
  plain = WireStandIn.parse(WireHarness.line_of(entry))
  read = plain && MGQ_MpBattlesSync::Wire.objects(plain) { |ref| Game_Battler.new(ref) }
  check("the script takes #{entry['name']} as the fixture says", read && read.map { |value| WireHarness.describe(value) }, entry["values"])
end

wire_cases("encode.json")["cases"].each do |entry|
  values = MGQ_MpBattlesSync::Wire.plain(entry["values"].map { |value| WireHarness.build(value) })
  check("the script hands over #{entry['name']} as the fixture's line", WireStandIn.line(values), entry["line"])
end
