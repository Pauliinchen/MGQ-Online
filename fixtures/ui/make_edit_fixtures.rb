#----------------------------------------------------------------
#  make_edit_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes edit.json next to this file: the text box editor's golden cases, played through
# MGQ_MpUi::TextEdit as ui_text_box.rbx had it before the editor moved to C# (TextEditor in
# MGQOnline.Game), which MGQOnline.Game.Tests replays. The scripts no longer hold the editor, so
# hand it the script of commit b20ddf0 to write the cases again:
#
#   git show b20ddf0:GameScript/Multiplayer/Scripts/ui_text_box.rbx > old_text_box.rbx
#   ruby fixtures/ui/make_edit_fixtures.rb old_text_box.rbx

require_relative "text_harness"

# The keys a step holds, read by the editor through the stand-ins below.
$edit_keys = []

# Stand-ins for the mod's base script: the game's buttons and Windows' keys a step holds.
module MGQ_Multiplayer
  # The buttons past the capture.
  module Capture
    # Whether a step holds an arrow.
    #
    # @param button [Symbol] The button.
    # @return [Boolean] Whether it does.
    def self.repeat?(button)
      $edit_keys.include?(button.to_s)
    end
  end

  # Windows' keys.
  module Key
    # Windows' codes of Home, End and Delete by their names in the cases.
    NAMES = { 0x24 => "HOME", 0x23 => "END", 0x2E => "DELETE" }

    # Whether a step holds a key.
    #
    # @param code [Integer] The key's code.
    # @return [Boolean] Whether it does.
    def self.pressed?(code)
      $edit_keys.include?(NAMES[code])
    end
  end
end

# The editor and the line breaking it builds on, read out of the script.
module MGQ_MpUi
  source = File.read(ARGV[0] || abort("Name the ui_text_box.rbx of commit b20ddf0, see the header."), :encoding => "UTF-8")
  module_eval(source[/^  class TextEdit\n.*?^  end\n/m] || abort("TextEdit is missing from #{ARGV[0]}"))
  module_eval(source[/^  def self\.wrap_spans\(.*?^  end\n/m])
  module_eval(source[/^  def self\.span_of\(.*?^  end\n/m])
end

# The cases: a text and the box's options, and the steps typed, keys held and scrolls.
CASES = [
  { "name" => "typing", "text" => "", "steps" => [{ "type" => "Hi there" }, { "type" => "\b\b" }, { "type" => "\t\x01!" }, { "type" => "\r" }, { "type" => "\e" }] },
  { "name" => "most_characters", "text" => "abc", "max_chars" => 5, "steps" => [{ "type" => "defg" }, { "type" => "\b" }, { "type" => "x" }] },
  { "name" => "allowed_digits", "text" => "1", "max_chars" => 2, "allowed" => ["\\A\\d\\z", false], "steps" => [{ "type" => "a5" }, { "type" => "7" }] },
  { "name" => "allowed_hex_ignoring_case", "text" => "", "allowed" => ["\\A[0-9a-f]\\z", true], "steps" => [{ "type" => "aFg9" }] },
  { "name" => "cursor_keys", "text" => "world", "steps" => [{ "keys" => ["LEFT"] }, { "keys" => ["LEFT", "LEFT"] }, { "type" => "X" }, { "keys" => ["HOME"] }, { "keys" => ["DELETE"] }, { "keys" => ["END"] }, { "keys" => ["RIGHT"] }, { "keys" => ["DELETE"] }, { "type" => "\b" }] },
  { "name" => "blink", "text" => "a", "steps" => [{ "keys" => [] }] * 31 + [{ "keys" => ["LEFT"] }] },
  { "name" => "line_scrolls", "text" => "", "width" => 30, "steps" => [{ "type" => "abcdefghij" }, { "keys" => ["HOME"] }, { "keys" => ["RIGHT"] }, { "keys" => ["END"] }, { "type" => "\b\b\b\b\b\b\b" }] },
  { "name" => "line_masked", "text" => "secret", "width" => 20, "mask" => true, "steps" => [{ "keys" => ["LEFT"] }, { "keys" => ["HOME"] }] },
  { "name" => "line_wide_characters", "text" => "日本語日本語", "width" => 30, "steps" => [{ "keys" => [] }, { "keys" => ["HOME"] }, { "keys" => ["RIGHT"] }, { "keys" => ["RIGHT"] }, { "keys" => ["RIGHT"] }] },
  { "name" => "area_lines", "text" => "one two three four five six seven", "width" => 40, "rows" => 2,
    "steps" => [{ "keys" => [] }, { "keys" => ["UP"] }, { "keys" => ["UP"] }, { "keys" => ["UP"] }, { "keys" => ["DOWN"] }, { "keys" => ["HOME"] }, { "keys" => ["DOWN"] }, { "keys" => ["DOWN"] }, { "keys" => ["END"] }] },
  { "name" => "area_scrolls", "text" => "one two three four five six seven eight nine", "width" => 40, "rows" => 2,
    "steps" => [{ "scroll" => -1 }, { "scroll" => -10 }, { "scroll" => 1 }, { "scroll" => 10 }, { "keys" => ["UP"] }] },
]

# Plays a case's steps through the editor.
#
# @param entry [Hash] The case.
# @return [Array<Hash>] After each step: the text, the cursor, whether the cursor shows, what typing
#   did, and in a box with a width what it shows (one line: the part and the characters before the
#   cursor; several lines: the first line shown).
def play(entry)
  allowed = entry["allowed"] && Regexp.new(entry["allowed"][0], entry["allowed"][1] ? Regexp::IGNORECASE : nil)
  editor = MGQ_MpUi::TextEdit.new(entry["text"], :max_chars => entry["max_chars"], :allowed => allowed)
  measure = lambda { |part| TEXT_MEASURE.text_size(part).width }
  entry["steps"].map do |step|
    $edit_keys = step["keys"] || []
    spans = entry["rows"] ? MGQ_MpUi.wrap_spans(editor.text, entry["width"], &measure) : nil
    outcomes = step["type"].to_s.each_char.map { |char| editor.type(char) }.compact.map(&:to_s)
    editor.update_keys(spans) if step["keys"]
    spans = entry["rows"] ? MGQ_MpUi.wrap_spans(editor.text, entry["width"], &measure) : nil
    editor.scroll_lines(spans, entry["rows"], step["scroll"]) if step["scroll"]
    state = { "text" => editor.text, "cursor" => editor.cursor, "shown" => editor.cursor_shown?, "outcomes" => outcomes }
    if entry["rows"]
      state["top"] = editor.first_line(spans, entry["rows"])
    elsif entry["width"]
      display = entry["mask"] ? "*" * editor.text.size : editor.text
      state["visible"] = editor.visible(TEXT_MEASURE, entry["width"], display)
    end
    state
  end
end

cases = CASES.map { |entry| entry.merge("states" => play(entry)) }
texts = CASES.map { |entry| ([entry["text"], "*"] + entry["steps"].map { |step| step["type"].to_s }).join }
widths = TextHarness.widths("texts" => texts.map { |text| { "text" => text } })
File.write(File.join(__dir__, "edit.json"), JSON.pretty_generate("widths" => widths, "cases" => cases) + "\n")
puts "wrote edit.json: #{cases.size} cases"
