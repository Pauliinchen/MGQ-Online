#----------------------------------------------------------------
#  wire_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Wrote the lines as JSON of their values instead of through a copy of the codec
#                            - Created
#
#----------------------------------------------------------------

# A fake transport of battle lines for the script tests: the topics that write and read battle
# lines (MGQOnline.Game's WireTopics) answered with the plain values as JSON behind "fake:", which
# no game writes. The C# tests own the real line format.

require "json"

# Writes and reads the fake lines.
module FakeLines
  # What every fake line starts with.
  PREFIX = "fake:"

  # Writes plain values as a fake line.
  #
  # @param values [Array] The plain values (see MGQ_MpBattlesSync::Wire.plain).
  # @return [String] The line.
  def self.line(values)
    PREFIX + JSON.generate(values)
  end

  # Reads a fake line back.
  #
  # @param line [String] The line.
  # @return [Array, nil] The plain values, nil for anything that is no fake line of values.
  def self.parse(line)
    text = line.to_s
    return nil unless text.start_with?(PREFIX)

    values = JSON.parse(text[PREFIX.size..-1])
    values.is_a?(Array) ? values : nil
  rescue JSON::ParserError
    nil
  end
end

# Writes a fake line of values, game objects among them as the scripts have them.
#
# @param values [Array] The values.
# @return [String] The line.
def wire_line(values)
  FakeLines.line(MGQ_MpBattlesSync::Wire.plain(values))
end

# Reads a fake line into this game's objects, as the scripts read what the DLL hands back.
#
# @param line [String] The line.
# @yieldparam ref [String] A battler's reference.
# @return [Array, nil] The values, nil when the line does not read.
def wire_values(line, &battler)
  values = FakeLines.parse(line)
  values && MGQ_MpBattlesSync::Wire.objects(values, &battler)
end

# Answers the topics that write and read battle lines with fake lines.
#
# @param fake [FakeBridge] The test's bridge.
def answer_wire(fake)
  fake.answer("wire.write") { |values| FakeLines.line(values) }
  fake.answer("wire.read") { |line| FakeLines.parse(line) }
end
