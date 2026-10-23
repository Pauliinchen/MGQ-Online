#----------------------------------------------------------------
#  ui_text_fixtures_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Checks the scripts' text rules (cut_measured, wrap_measured, wrap_spans) against the golden cases
# in fixtures/ui/text.json, which MGQOnline.Game.Tests checks the C# rules against too, so the two
# never drift apart. A case that fails here means a rule changed: write the cases again
# (fixtures/ui/make_fixtures.rb) and change the C# rule to match.

require_relative "support"
require_relative "../../fixtures/ui/text_harness"

fixture = JSON.parse(File.read(File.expand_path("../../fixtures/ui/text.json", __dir__), :encoding => "UTF-8"))
fixture["cut"].each { |entry| check("cut_measured cuts #{entry['name']} as the fixture says", TextHarness.cut(entry), entry["result"]) }
fixture["wrap"].each { |entry| check("wrap_measured breaks #{entry['name']} as the fixture says", TextHarness.wrap(entry), entry["lines"]) }
fixture["spans"].each { |entry| check("wrap_spans breaks #{entry['name']} as the fixture says", TextHarness.spans(entry), entry["spans"]) }
cases = { "cut" => fixture["cut"], "wrap" => fixture["wrap"], "spans" => fixture["spans"] }
check("the fixture lists the width of every character of its cases", TextHarness.widths(cases), fixture["widths"])
