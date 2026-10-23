#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes the text rules' golden cases next to this file from the real scripts (see
# text_harness.rb): text.json, each case with what ui.rbx and ui_text_box.rbx make of it, and the
# width of every character the cases hold, which MGQOnline.Game.Tests and
# GameScript/Tests/ui_text_fixtures_test.rb check. Run it again only when a case or a rule changes:
#
#   ruby fixtures/ui/make_fixtures.rb

require_relative "text_harness"

# The cut cases: a text, the width and the tail that stays whole.
CUT = [
  { "name" => "fits", "text" => "Alice", "width" => 40, "tail" => "" },
  { "name" => "fits_exactly", "text" => "Alice", "width" => 31, "tail" => "" },
  { "name" => "cut", "text" => "Alice the Monster Lord", "width" => 60, "tail" => "" },
  { "name" => "cut_before_tail", "text" => "Ilias Village", "width" => 70, "tail" => " (2F)" },
  { "name" => "spaces_before_the_ellipsis", "text" => "ab      cdefgh", "width" => 40, "tail" => "" },
  { "name" => "nothing_fits", "text" => "Alice", "width" => 5, "tail" => "" },
  { "name" => "tail_alone_too_wide", "text" => "Luka", "width" => 10, "tail" => " 12/12" },
  { "name" => "full_width", "text" => "日本語日本語", "width" => 50, "tail" => "" },
  { "name" => "emoji", "text" => "😀😀😀 hi", "width" => 40, "tail" => "" },
  { "name" => "empty", "text" => "", "width" => 0, "tail" => "" },
]

# The wrap cases: a text and the width.
WRAP = [
  { "name" => "one_line", "text" => "Leave the party?", "width" => 200 },
  { "name" => "at_words", "text" => "Leave the party and go back to your own world?", "width" => 90 },
  { "name" => "long_word", "text" => "a Wwwwwwwwwwwwwwwwwwwwwwwww word", "width" => 60 },
  { "name" => "spaces_collapse", "text" => "  many    spaces\tand\na line  ", "width" => 60 },
  { "name" => "full_width_without_spaces", "text" => "日本語日本語日本語", "width" => 40 },
  { "name" => "wider_than_any_character", "text" => "mm mm", "width" => 5 },
  { "name" => "empty", "text" => "", "width" => 50 },
]

# The span cases: a text, the width, and whether characters count as cells.
SPANS = [
  { "name" => "empty", "text" => "", "width" => 50, "cells" => false },
  { "name" => "at_words", "text" => "What you did and what happened", "width" => 60, "cells" => false },
  { "name" => "spaces_stay_whole", "text" => "ab          cd", "width" => 20, "cells" => false },
  { "name" => "long_word", "text" => "Wwwwwwwwwwwwwwwww and more", "width" => 40, "cells" => false },
  { "name" => "one_wide_character", "text" => "a 😀 b", "width" => 10, "cells" => false },
  { "name" => "lines_kept", "text" => "first\nsecond line", "width" => 60, "cells" => false },
  { "name" => "cells", "text" => "a description of the world, typed", "width" => 10, "cells" => true },
  { "name" => "cells_long_word", "text" => "abcdefghijklmnop qr", "width" => 6, "cells" => true },
]

cases = { "cut" => CUT, "wrap" => WRAP, "spans" => SPANS }
fixture = {
  "widths" => TextHarness.widths(cases),
  "cut" => CUT.map { |entry| entry.merge("result" => TextHarness.cut(entry)) },
  "wrap" => WRAP.map { |entry| entry.merge("lines" => TextHarness.wrap(entry)) },
  "spans" => SPANS.map { |entry| entry.merge("spans" => TextHarness.spans(entry)) },
}
File.write(File.join(__dir__, "text.json"), JSON.pretty_generate(fixture) + "\n")
puts "wrote text.json: #{CUT.size} cut, #{WRAP.size} wrap and #{SPANS.size} span cases"
