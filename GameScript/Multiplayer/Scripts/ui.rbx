#----------------------------------------------------------------
#  ui.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Renamed from mp_ui.rbx
#                            - Drew a list box's item in gold when asked
#                            - Broke the top lines anew only when they changed, and made the list box darker, so the windows behind it show through only a little
#                            - Added the list box, a large box of headings and items drawn like the World overview
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# What the mod's screens and boxes share: breaking a text into lines that fit, the window of lines
# across the top of a screen, and the list box. The text boxes are in ui_text_box.rbx.
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
    return if lines == @given

    @given = lines.dup
    wrapped = lines.compact.map { |line| MGQ_MpUi.wrap(self, line, contents_width) }.flatten
    @lines = wrapped
    contents.clear
    wrapped.first(@rows).each_with_index do |line, index|
      draw_text(0, index * line_height, contents_width, line_height, line)
    end
  end
end

# A large box over a screen that lists lines under a title, as the World overview does: headings
# and items, one of which is picked, with a hint at the bottom. Whoever opens it moves the pick and
# closes it; the box only draws.
class Sprite_MpListBox < Sprite
  # Where the box sits on the screen.
  BOX = Rect.new(40, 32, 560, 404)

  # Height of one line of the list.
  ROW = 24

  # Height of the title.
  TITLE = 30

  # Height of the hint at the bottom.
  HINT_HEIGHT = 22

  # Lines of the list the box shows at once.
  LIST_ROWS = (BOX.height - TITLE - HINT_HEIGHT - 8) / ROW

  # Left edge of an item's text.
  ITEM_LEFT = 24

  # Font size of an item's text.
  ITEM_SIZE = 18

  # Width kept at the right of an item for what it says there.
  RIGHT_WIDTH = 120

  # Background of the box.
  BACK = Color.new(0, 0, 0, 228)

  # Background of the item picked.
  PICKED_BACK = Color.new(48, 96, 176, 220)

  # Color of a heading.
  HEAD_COLOR = Color.new(160, 200, 255)

  # Color of an item that is fine, such as a player online.
  GOOD_COLOR = Color.new(128, 255, 128)

  # Color of an item that stands out, such as an essential mod.
  GOLD_COLOR = Color.new(255, 200, 64)

  # Color of an item that is wrong, such as an essential mod that is missing.
  BAD_COLOR = Color.new(255, 96, 96)

  # Color of the hint and of an item that is away.
  GREY = Color.new(150, 150, 150)

  # What the hint says.
  HINT = "Up and down: move    Esc or a click outside: close"

  # What the box lists.
  #
  # @!attribute title [String] The title at the top left.
  # @!attribute note [String, nil] What the top right says.
  # @!attribute lines [Array<Array>] [:head, text] for a heading, [:item, text, color, right] for an item: color is :plain, :good, :gold, :bad or :grey, right what its right end says or nil.
  # @!attribute selected [Integer, nil] The line of the item picked, nil without items.
  # @!attribute scroll [Integer] The first line in sight.
  View = Struct.new(:title, :note, :lines, :selected, :scroll) do
    # Makes a list with its first item picked.
    #
    # @param title [String] The title.
    # @param note [String, nil] What the top right says.
    # @param lines [Array<Array>] The lines.
    # @return [View] The list.
    def self.of(title, note, lines)
      new(title, note, lines, (0...lines.size).find { |line| lines[line][0] == :item }, 0)
    end

    # Lists the lines that are items.
    #
    # @return [Array<Integer>] The lines.
    def items
      (0...lines.size).select { |line| lines[line][0] == :item }
    end

    # Picks the item a number of items further, stopping at the first and the last.
    #
    # @param step [Integer] 1 for the next, -1 for the one before.
    def move(step)
      at = items.index(selected)
      pick(items[[[at + step, 0].max, items.size - 1].min]) if at
    end

    # Picks an item and scrolls it into sight, with the heading right above it.
    #
    # @param line [Integer] The item's line.
    def pick(line)
      self.selected = line
      top = line > 0 && lines[line - 1][0] == :head ? line - 1 : line
      self.scroll = top if top < scroll
      self.scroll = line - LIST_ROWS + 1 if line >= scroll + LIST_ROWS
    end
  end

  # Creates the box, hidden, above every window.
  def initialize
    super(nil)
    self.bitmap = Bitmap.new(BOX.width, BOX.height)
    self.x = BOX.x
    self.y = BOX.y
    self.z = 1000
    self.visible = false
    @shown = nil
  end

  # Reports whether a point of the screen lies in the box.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @return [Boolean] Whether it does.
  def self.inside?(x, y)
    x >= BOX.x && x < BOX.x + BOX.width && y >= BOX.y && y < BOX.y + BOX.height
  end

  # Finds the line of the list under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param view [View] What the box lists.
  # @return [Integer, nil] The line, nil outside the list.
  def self.line_at(x, y, view)
    return nil unless inside?(x, y) && y >= BOX.y + TITLE

    row = (y - BOX.y - TITLE) / ROW
    line = view.scroll + row
    row < LIST_ROWS && line < view.lines.size ? line : nil
  end

  # Shows a list, drawing it if it changed.
  #
  # @param view [View] What the box lists.
  def show(view)
    self.visible = true
    drawn = view.to_a
    return if drawn == @shown

    @shown = drawn.map { |part| part.is_a?(Array) ? part.dup : part }
    draw(view)
  end

  # Hides the box.
  def hide
    self.visible = false
    @shown = nil
  end

  # Draws the whole box.
  #
  # @param view [View] What the box lists.
  def draw(view)
    bitmap.clear
    bitmap.fill_rect(bitmap.rect, BACK)
    bitmap.font.outline = true
    bitmap.font.size = 20
    bitmap.font.color = Color.new(255, 255, 255)
    bitmap.draw_text(10, 2, BOX.width - 20, TITLE - 4, view.title)
    bitmap.font.color = GOOD_COLOR
    bitmap.draw_text(10, 2, BOX.width - 20, TITLE - 4, view.note, 2) if view.note
    lines = view.lines[view.scroll, LIST_ROWS] || []
    lines.each_with_index { |line, index| draw_line(line, TITLE + index * ROW, view.scroll + index == view.selected) }
    bitmap.font.size = 16
    bitmap.font.color = GREY
    bitmap.draw_text(8, BOX.height - HINT_HEIGHT, BOX.width - 16, HINT_HEIGHT, HINT, 1)
  end

  # Draws one line of the list: a heading or an item.
  #
  # @param line [Array] The line, see View.
  # @param y [Integer] The line's top.
  # @param picked [Boolean] Whether it is the item picked.
  def draw_line(line, y, picked)
    kind, text, color, right = line
    bitmap.font.size = ITEM_SIZE

    if kind == :head
      bitmap.font.color = HEAD_COLOR
      bitmap.draw_text(8, y, BOX.width - 16, ROW, text)
      return
    end

    bitmap.fill_rect(4, y, BOX.width - 8, ROW, PICKED_BACK) if picked
    bitmap.font.color = { :good => GOOD_COLOR, :gold => GOLD_COLOR, :bad => BAD_COLOR, :grey => GREY }[color] || Color.new(255, 255, 255)
    bitmap.draw_text(ITEM_LEFT, y, BOX.width - ITEM_LEFT - 16 - (right ? RIGHT_WIDTH : 0), ROW, text)
    return unless right

    bitmap.font.size = 16
    bitmap.draw_text(BOX.width - RIGHT_WIDTH - 10, y, RIGHT_WIDTH, ROW, right, 2)
  end

  # Frees the box's picture.
  def dispose
    bitmap.dispose
    super
  end
end
