#----------------------------------------------------------------
#  ui.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Renamed from mp_ui.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# What the mod's screens and boxes share: breaking a text into lines that fit, and the window of
# lines across the top of a screen.
module MGQ_MpUi
  # Breaks a text into lines that fit a width, at its spaces, and inside a word longer than the
  # width.
  #
  # @param measure [Bitmap, Window_Base] What measures a text with the font the lines are drawn in.
  # @param text [String] The text.
  # @param width [Integer] The width in pixels.
  # @return [Array<String>] The lines.
  def self.wrap(measure, text, width)
    lines = [""]
    text.split(" ").each do |word|
      candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
      if measure.text_size(candidate).width <= width
        lines[-1] = candidate
        next
      end

      lines.push("") unless lines.last.empty?
      word.each_char do |char|
        lines.push("") if measure.text_size(lines.last + char).width > width && !lines.last.empty?
        lines[-1] += char
      end
    end
    lines
  end
end

# The lines across the top of a screen of the mod, such as the world screen's.
class Window_MpInfo < Window_Base
  # Lines the window has room for unless told otherwise.
  LINES = 3

  # Creates the window across the top of the screen, empty.
  #
  # @param rows [Integer] The lines it has room for.
  def initialize(rows = LINES)
    super(0, 0, Graphics.width, fitting_height(rows))
    @rows = rows
    @lines = []
  end

  # Draws the lines, if they changed, wrapping long ones.
  #
  # @param lines [Array<String, nil>] The lines, nil ones left out.
  def show(lines)
    wrapped = lines.compact.map { |line| MGQ_MpUi.wrap(self, line, contents_width) }.flatten
    return if wrapped == @lines

    @lines = wrapped
    contents.clear
    wrapped.first(@rows).each_with_index do |line, index|
      draw_text(0, index * line_height, contents_width, line_height, line)
    end
  end
end
