#----------------------------------------------------------------
#  text_harness.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Runs the scripts' own text rules outside the game for their golden cases: MGQ_MpUi.cut_measured
# and wrap_measured of ui.rbx and MGQ_MpUi.wrap_spans of ui_text_box.rbx, read out of the scripts,
# with a measure that adds up a table of character widths, as RGSS measures the game's font.
# make_fixtures.rb writes the cases with it, GameScript/Tests/ui_text_fixtures_test.rb checks them
# again, and MGQOnline.Game.Tests checks the C# rules against them.

require "json"

# Where the scripts lie.
TEXT_SCRIPTS = File.expand_path("../../GameScript/Multiplayer/Scripts", __dir__)

# The text rules, as the scripts have them.
module TextRules
  # What ends a text cut to fit, as ui.rbx has it.
  ELLIPSIS = "..."

  ui = File.read(File.join(TEXT_SCRIPTS, "ui.rbx"), :encoding => "UTF-8")
  box = File.read(File.join(TEXT_SCRIPTS, "ui_text_box.rbx"), :encoding => "UTF-8")
  [[ui, "cut_measured"], [ui, "wrap_measured"], [box, "wrap_spans"]].each do |source, name|
    module_eval(source[/^  def self\.#{name}\(.*?^  end\n/m] || raise("#{name} is missing from the scripts"))
  end
end

# A width as Bitmap#text_size answers it.
TextWidth = Struct.new(:width)

# Measures a text as the sum of a table's character widths.
class TableMeasure
  # The widths by character, and the one of a character the table lacks.
  #
  # @param widths [Hash{String => Integer}] The widths.
  # @param other [Integer] The width of any other character.
  def initialize(widths, other)
    @widths = widths
    @other = other
  end

  # Measures a text.
  #
  # @param text [String] The text.
  # @return [TextWidth] Its width.
  def text_size(text)
    TextWidth.new(text.to_s.each_char.inject(0) { |sum, char| sum + width_of(char) })
  end

  # Tells a character's width.
  #
  # @param char [String] The character.
  # @return [Integer] Its width.
  def width_of(char)
    @widths.fetch(char, @other)
  end
end

# The widths the cases are measured by: a proportional font, so a cut or a break falls at a
# character's own width, with full-width characters and an emoji.
TEXT_WIDTHS = { " " => 4, "i" => 3, "l" => 3, "." => 3, "," => 3, "m" => 11, "W" => 12, "M" => 11, "日" => 12, "本" => 12, "語" => 12, "😀" => 16 }.freeze

# The width of every other character of the cases.
TEXT_OTHER = 7

# The measure of the cases.
TEXT_MEASURE = TableMeasure.new(TEXT_WIDTHS, TEXT_OTHER)

# Runs the cases through the scripts' rules.
module TextHarness
  # Cuts a case's text.
  #
  # @param entry [Hash] The case: "text", "width" and "tail".
  # @return [String] The text cut.
  def self.cut(entry)
    TextRules.cut_measured(TEXT_MEASURE, entry["text"], entry["width"], entry["tail"])
  end

  # Breaks a case's text at words.
  #
  # @param entry [Hash] The case: "text" and "width".
  # @return [Array<String>] The lines.
  def self.wrap(entry)
    TextRules.wrap_measured(TEXT_MEASURE, entry["text"], entry["width"])
  end

  # Breaks a case's text keeping each character's place, in pixels, or in cells for a case that
  # counts characters.
  #
  # @param entry [Hash] The case: "text", "width" and "cells".
  # @return [Array<Array<Integer>>] Each line's start and length.
  def self.spans(entry)
    measure = entry["cells"] ? lambda { |part| part.length } : lambda { |part| TEXT_MEASURE.text_size(part).width }
    TextRules.wrap_spans(entry["text"], entry["width"], &measure)
  end

  # Lists every character of the cases with its width, which the C# tests learn.
  #
  # @param cases [Hash] The cases by rule.
  # @return [Hash{String => Integer}] Each code point, as text, and its width.
  def self.widths(cases)
    chars = cases.values.flatten.map { |entry| "#{entry['text']}#{entry['tail']}" }.join.each_char.to_a.uniq.sort
    Hash[(chars + TextRules::ELLIPSIS.chars).uniq.map { |char| [char.ord.to_s, TEXT_MEASURE.width_of(char)] }]
  end
end
