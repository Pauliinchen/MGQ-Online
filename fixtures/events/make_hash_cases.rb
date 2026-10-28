#----------------------------------------------------------------
#  make_hash_cases.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Writes hash_cases.json next to this file: lists of event commands as the game holds them and the
# shape of each, the 24-bit hash the events database keeps per list (MGQOnline.Data's ListShape).
# The C# tests and the scripts' tests read the same file, so both sides hash alike.
#
#   ruby fixtures/events/make_hash_cases.rb

require "json"

# The codes whose commands the shape covers, as MGQOnline.Data's EventSchema.KeptCodes lists them.
KEPT_CODES = [
  101, 102, 103, 104, 105, 111, 117, 118, 119, 121, 122, 123, 125, 126, 127, 128, 129, 132, 133, 136, 201, 202, 203,
  206, 222, 282, 283, 285, 301, 303, 353, 354, 355, 402, 403, 404, 411, 412, 999
]

# The bits a shape keeps; 24 keep every step a Fixnum on the game's 32-bit Ruby 1.9.2.
MASK = 0xFFFFFF

# Hashes a list's kept commands: code, indent and every Integer parameter, in order.
#
# @param list [Array<Array>] The commands, each [code, indent, parameters].
# @return [Integer] The shape.
def shape(list)
  kept = {}
  KEPT_CODES.each { |code| kept[code] = true }
  list.inject(0) do |hash, (code, indent, parameters)|
    next hash unless kept[code]

    hash = (hash * 31 + code) & MASK
    hash = (hash * 31 + indent) & MASK
    parameters.each { |value| hash = (hash * 31 + value) & MASK if value.is_a?(Integer) }
    hash
  end
end

# The closing command every list of the game ends with.
CLOSE = [0, 0, []]

TALK = [[101, 0, ["Actor1", 0, 0, 2]], [401, 0, ["Hello."]], [121, 0, [5, 5, 0]], CLOSE]

CASES = [
  ["an empty list", [CLOSE]],
  ["a talk", TALK],
  ["the talk translated, its text split over two lines", [[101, 0, ["Actor1", 0, 0, 2]], [401, 0, ["Good"]], [401, 0, ["day."]], [121, 0, [5, 5, 0]], CLOSE]],
  ["a battle in a branch on switch 4", [[111, 0, [0, 4, 0]], [301, 1, [0, 12, true, false]], [412, 0, []], CLOSE]],
  ["the battle in a branch on switch 5", [[111, 0, [0, 5, 0]], [301, 1, [0, 12, true, false]], [412, 0, []], CLOSE]],
  ["a variable set from variable 113", [[122, 0, [113, 113, 0, 1, 113]], CLOSE]],
  ["the variable set from variable 35", [[122, 0, [113, 113, 0, 1, 35]], CLOSE]],
  ["a script, labels and a self switch", [[355, 0, ["$game_variables[5] += 1"]], [655, 0, ["$game_switches[7] = true"]], [118, 0, ["Start"]], [119, 0, ["Start"]], [123, 0, ["A", 0]], CLOSE]],
  ["negative and large numbers", [[122, 0, [10, 10, 0, 0, -99_999_999]], [126, 0, [3, 0, 0, 99_999_999]], [201, 0, [0, 1012, 8, 9, 2, 0]], CLOSE]],
  ["choices", [[102, 0, [["Yes", "No"], 2]], [402, 0, [0, "Yes"]], [402, 0, [1, "No"]], [404, 0, []], CLOSE]],
  ["a common event's mark and a call", [[999, 0, [3506]], [117, 0, [154]], CLOSE]],
  ["commands the shape leaves out", [[230, 0, [60]], [250, 0, [{ "name" => "Bell" }]], [205, 0, [-1, nil]], CLOSE]],
]

cases = CASES.map { |name, list| { "name" => name, "list" => list, "shape" => shape(list) } }
path = File.join(File.dirname(File.expand_path(__FILE__)), "hash_cases.json")
File.write(path, JSON.pretty_generate("kept_codes" => KEPT_CODES, "cases" => cases) + "\n")
puts "wrote #{cases.size} cases to #{path}"
