#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the freeze's write journal next to this file, journal.json, from the
# whole-story diff that battles_raid_freeze.rbx kept before the journal (story_diff at 1708af2c,
# with world_story.rbx's same?). Each case starts from a story, makes writes before and after a
# mark, and records what the journal answers for the mark (each key written since it once, with its
# value before its first write since it, in that order) and what the old diff of the story at the
# mark against the story after found ([kind, key, before, after], in its order).
# MGQOnline.Game.Tests replays the journal; raid_freeze_test.rb replays the diff through the
# journal.
#
#   ruby fixtures/freeze/make_fixtures.rb

require "json"

# The commit whose scripts still diffed whole stories.
SOURCE = "1708af2c"

root = File.expand_path("../..", __dir__)
freeze = `git -C "#{root}" show #{SOURCE}:GameScript/Multiplayer/Scripts/battles_raid_freeze.rbx`
story = `git -C "#{root}" show #{SOURCE}:GameScript/Multiplayer/Scripts/world_story.rbx`
raise "git show failed" if freeze.empty? || story.empty?

# The old story_diff, as the freeze kept it.
module OldFreeze; end
# The old same?, as the world's story kept it.
module MGQ_MpWorldStory; end
OldFreeze.module_eval(freeze[/  def self\.story_diff.*?\n  end\n/m])
MGQ_MpWorldStory.module_eval(story[/  def self\.same\?.*?\n  end\n/m])

# Makes a story: switches, variables and self switches.
#
# @param switches [Array<Array>] Switches, each [id, value].
# @param variables [Array<Array>] Variables, each [id, value].
# @param selves [Array<Array>] Self switches, each [map, event, letter, value], in the hash's order.
# @return [Array] The story.
def story_of(switches, variables, selves)
  one = []
  switches.each { |id, value| one[id] = value }
  two = []
  variables.each { |id, value| two[id] = value }
  three = {}
  selves.each { |map, event, letter, value| three[[map, event, letter]] = value }
  [one, two, three]
end

# Records one case.
#
# @param name [String] What it shows.
# @param start [Hash] The story before every write: "switches" and "variables" ([id, value] each)
#   and "selves" ([map, event, letter, value] each, in the hash's order).
# @param before_mark [Array<Array>] Writes before the mark, each [kind, key, value].
# @param after_mark [Array<Array>] Writes after it.
# @return [Hash] The case: also each write as the journal takes it ([seq, kind, key, value before],
#   numbered from 1), the mark (the number of the last write before it), the journal's rows since
#   the mark and the old diff.
def make_case(name, start, before_mark, after_mark)
  live = story_of(start["switches"], start["variables"], start["selves"])
  at_mark = nil
  entries = []
  (before_mark + [:mark] + after_mark).each do |write|
    next at_mark = Marshal.load(Marshal.dump(live)) if write == :mark

    kind, key, value = write
    entries << [entries.size + 1, kind, key, live[kind][key]]
    live[kind][key] = value
  end
  mark = before_mark.size
  seen = {}
  rows = entries.select { |seq, kind, key, _| seq > mark && !seen[[kind, key]] && (seen[[kind, key]] = true) }.map { |_, kind, key, before| [kind, key, before] }
  {
    "name" => name, "start" => start, "before_mark" => before_mark, "after_mark" => after_mark,
    "entries" => entries, "mark" => mark, "rows" => rows, "diff" => OldFreeze.story_diff(at_mark, live),
  }
end

cases = [
  make_case("a key written twice keeps its first value, a key set back drops out of the diff, a key written only before the mark is none of the journal's",
            { "switches" => [[10, true]], "variables" => [[1075, 12]], "selves" => [] },
            [[1, 1020, 5], [0, 10, false]],
            [[1, 1075, 14], [0, 31, true], [1, 1075, 16], [0, 31, false], [0, 10, true]]),
  make_case("a self switch new to the story comes after those it held, which keep their order",
            { "switches" => [], "variables" => [], "selves" => [[138, 13, "A", true], [138, 14, "A", false], [7, 1, "B", true]] },
            [],
            [[2, [7, 1, "B"], false], [2, [200, 3, "C"], true], [2, [138, 13, "A"], false]]),
  make_case("off and nil are the same for a switch and a self switch, 0 and nil for a variable",
            { "switches" => [[5, nil]], "variables" => [[60, nil]], "selves" => [] },
            [],
            [[0, 5, false], [1, 60, 0], [2, [9, 9, "A"], false], [1, 61, 3]]),
  make_case("a variable holding a float or a text keeps it",
            { "switches" => [], "variables" => [[70, 1.5], [71, "abc"]], "selves" => [] },
            [],
            [[1, 70, 2.25], [1, 71, "def"], [1, 72, 7.5]]),
  make_case("nothing written since the mark",
            { "switches" => [[1, true]], "variables" => [[1, 1]], "selves" => [] },
            [[0, 1, false]],
            []),
]

File.write(File.join(__dir__, "journal.json"), JSON.pretty_generate("source" => "battles_raid_freeze.rbx story_diff at #{SOURCE}, Ruby #{RUBY_VERSION}", "cases" => cases) + "\n")
puts "wrote #{cases.size} cases"
