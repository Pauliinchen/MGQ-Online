#----------------------------------------------------------------
#  ui.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Added the depth of the chat while the player types, above everything
#                            - Added the cancel of the mod's screens, which takes the numpad's 0 with Num Lock on and off
#                            - Took the numpad's 0 frame by frame, so a press a game window cancelled with never cancels again in the next frame
#                            - Watched the numpad's 0 from the start, so its first press of a session counts
#      Paulinchen  2026-10-07: Added the iconset rect, the cut with one ellipsis, white and the depths of the mod's sprites and windows, which the screens share
#                            - Logged every message box shown, with its title and text
#      Paulinchen  2026-10-06: Dropped the wrapped lines the top window kept but never read
#                            - Let a list box say a hint of its own at the bottom, and named how high it lies
#                            - Drew an item being typed into as a text box with its cursor, and the picked item opaque
#                            - Drew buttons at the right end of an item, each a mark outlined in its color or filled with it, the column titles at the heading above, and the one the cursor is on
#      Paulinchen  2026-10-04: Added the message box, a box in the middle of the screen drawn like the list box
#                            - Renamed from mp_ui.rbx
#                            - Drew a list box's item in gold when asked
#                            - Broke the top lines anew only when they changed, and made the list box darker, so the windows behind it show through only a little
#                            - Added the list box, a large box of headings and items drawn like the World overview
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# What the mod's screens and boxes share: breaking a text into lines that fit, the window of lines
# across the top of a screen, the list box and the message box. The text boxes are in
# ui_text_box.rbx.
module MGQ_MpUi
  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "ui"

  # Side of an icon of the game's iconset, in pixels.
  ICON_SIZE = 24

  # Icons in a row of the game's iconset.
  ICONS_PER_ROW = 16

  # What ends a text cut to fit.
  ELLIPSIS = "..."

  # White, the color most texts of the mod are drawn in.
  WHITE = Color.new(255, 255, 255)

  # The depths of the mod's sprites and windows above the game's, by layer: the lines at the
  # screen's edges, the labels on the map, the bubbles and notices over them, the wheels and what
  # lies above a screen's windows, the World overview, the boxes, and the chat while the player types
  # above everything.
  Z = { :lines => 200, :labels => 250, :bubbles => 260, :wheels => 300, :overview => 400, :boxes => 1000, :typing => 1100 }

  # Windows' codes of the numpad's 0, the game's cancel key, with Num Lock on and off; the second
  # is also the Insert key's.
  NUMPAD_CANCEL_KEYS = [0x60, 0x2D]
  MGQ_Multiplayer::Key.watch(*NUMPAD_CANCEL_KEYS)

  # Reports whether the numpad's 0 went down in this frame, with Num Lock on or off. A text box asks
  # it instead of cancel?, since the game's cancel button is X too, a letter.
  #
  # With Num Lock on it is the game's cancel button as well, so a press a game window took must not
  # count again in the next frame, after the window's cancel opened another screen.
  #
  # @return [Boolean] Whether it did.
  def self.numpad_cancel?
    NUMPAD_CANCEL_KEYS.map { |code| MGQ_Multiplayer::Key.triggered?(code) }.any?
  end

  # Reports whether cancel went down on a screen of the mod: the game's cancel button, past the
  # capture, or the numpad's 0, which the game takes only with Num Lock on.
  #
  # @return [Boolean] Whether it did.
  def self.cancel?
    MGQ_Multiplayer::Capture.trigger?(:B) | numpad_cancel?
  end

  # Finds an icon in the game's iconset.
  #
  # @param icon [Integer] The icon's index.
  # @return [Rect] Where the icon lies in the iconset.
  def self.icon_rect(icon)
    Rect.new(icon % ICONS_PER_ROW * ICON_SIZE, icon / ICONS_PER_ROW * ICON_SIZE, ICON_SIZE, ICON_SIZE)
  end

  # Cuts a text at its end until it fits a width with ELLIPSIS and what follows it.
  #
  # @param measure [Bitmap, Window_Base] What measures a text with the font it is drawn in.
  # @param text [String] The text.
  # @param width [Integer] The width in pixels.
  # @param tail [String] What follows the text and stays whole, such as a count or a floor.
  # @return [String] The text with the tail when they fit, else the text's start, ELLIPSIS and the tail.
  def self.cut(measure, text, width, tail = "")
    text = text.to_s
    return "#{text}#{tail}" if measure.text_size("#{text}#{tail}").width <= width

    head = text
    head = head[0...-1].rstrip while !head.empty? && measure.text_size("#{head}#{ELLIPSIS}#{tail}").width > width
    "#{head}#{ELLIPSIS}#{tail}"
  end

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
  end

  # Draws the lines, if they changed, wrapping long ones.
  #
  # @param lines [Array<String, nil>] The lines, nil ones left out.
  def show(lines)
    return if lines == @given

    @given = lines.dup
    wrapped = lines.compact.map { |line| MGQ_MpUi.wrap(self, line, contents_width) }.flatten
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

  # How far above the screen's windows the box lies.
  Z = MGQ_MpUi::Z[:boxes]

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

  # Side of a button at the right end of an item.
  BUTTON_SIZE = 18

  # Width of a column of buttons, wide enough for the column's title above it.
  BUTTON_COLUMN = 70

  # Room between the last column of buttons and the box's edge.
  BUTTON_MARGIN = 6

  # Width of the label in front of a text box in an item.
  TYPING_LABEL = 60

  # Background of a text box in an item, opaque, so nothing behind the box shows through the text.
  TEXT_BOX_BACK = Color.new(12, 16, 28)

  # The colors a button may have, by name.
  BUTTON_COLORS = { :red => Color.new(230, 50, 50), :orange => Color.new(255, 150, 20) }

  # Background of the box.
  BACK = Color.new(0, 0, 0, 228)

  # Background of the item picked, opaque, so nothing behind the box shows through it.
  PICKED_BACK = Color.new(48, 96, 176)

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

  # What the hint says unless the list says another.
  HINT = "Up and down: move    Esc or a click outside: close"

  # What the box lists.
  #
  # @!attribute title [String] The title at the top left.
  # @!attribute note [String, nil] What the top right says.
  # @!attribute lines [Array<Array>] [:head, text, titles] for a heading, titles nil or those of the button columns below it; [:item, text, color, right, buttons] for an item: color is :plain, :good, :gold, :bad or :grey, right what its right end says or nil, buttons nil or each button's mark, color (:red or :orange) and whether it is on. An item being typed into adds [editor, text, cursor, cursor shown], its text the box's label.
  # @!attribute selected [Integer, nil] The line of the item picked, nil without items.
  # @!attribute scroll [Integer] The first line in sight.
  # @!attribute hint [String, nil] What the bottom says, nil for HINT.
  # @!attribute column [Integer, nil] The button of the picked item the cursor is on, from 1; nil or 0 for the item itself.
  View = Struct.new(:title, :note, :lines, :selected, :scroll, :hint, :column) do
    # Makes a list with its first item picked.
    #
    # @param title [String] The title.
    # @param note [String, nil] What the top right says.
    # @param lines [Array<Array>] The lines.
    # @param hint [String, nil] What the bottom says, nil for HINT.
    # @return [View] The list.
    def self.of(title, note, lines, hint = nil)
      new(title, note, lines, (0...lines.size).find { |line| lines[line][0] == :item }, 0, hint)
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
    self.z = Z
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

  # Finds the button of an item under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param count [Integer] How many buttons the item has.
  # @return [Integer, nil] The button, from 1 at the left; nil outside them.
  def self.button_at(x, count)
    (1..count).find do |button|
      left = BOX.x + column_left(button, count)
      x >= left && x < left + BUTTON_COLUMN
    end
  end

  # Tells where a column of buttons starts, inside the box.
  #
  # @param button [Integer] The column, from 1 at the left.
  # @param count [Integer] How many columns there are.
  # @return [Integer] Its left edge.
  def self.column_left(button, count)
    BOX.width - BUTTON_MARGIN - (count - button + 1) * BUTTON_COLUMN
  end

  # Tells where a button of an item starts, inside the box: in the middle of its column.
  #
  # @param button [Integer] The button, from 1 at the left.
  # @param count [Integer] How many buttons the item has.
  # @return [Integer] Its left edge.
  def self.button_left(button, count)
    column_left(button, count) + (BUTTON_COLUMN - BUTTON_SIZE) / 2
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
    bitmap.font.color = MGQ_MpUi::WHITE
    bitmap.draw_text(10, 2, BOX.width - 20, TITLE - 4, view.title)
    bitmap.font.color = GOOD_COLOR
    bitmap.draw_text(10, 2, BOX.width - 20, TITLE - 4, view.note, 2) if view.note
    lines = view.lines[view.scroll, LIST_ROWS] || []
    lines.each_with_index { |line, index| draw_line(line, TITLE + index * ROW, view.scroll + index == view.selected, view.column.to_i) }
    bitmap.font.size = 16
    bitmap.font.color = GREY
    bitmap.draw_text(8, BOX.height - HINT_HEIGHT, BOX.width - 16, HINT_HEIGHT, view.hint || HINT, 1)
  end

  # Draws one line of the list: a heading, with the titles of the button columns below it, or an
  # item.
  #
  # @param line [Array] The line, see View.
  # @param y [Integer] The line's top.
  # @param picked [Boolean] Whether it is the item picked.
  # @param column [Integer] The button the cursor is on while it is picked, 0 for the item itself.
  def draw_line(line, y, picked, column = 0)
    kind, text, color, right, buttons, typing = line
    bitmap.font.size = ITEM_SIZE

    if kind == :head
      draw_heading(text, color, y)
      return
    end

    bitmap.fill_rect(4, y, BOX.width - 8, ROW, PICKED_BACK) if picked
    bitmap.font.color = { :good => GOOD_COLOR, :gold => GOLD_COLOR, :bad => BAD_COLOR, :grey => GREY }[color] || MGQ_MpUi::WHITE
    return draw_typing(text, typing[0], y) if typing

    buttons_width = buttons ? buttons.size * BUTTON_COLUMN + BUTTON_MARGIN : 0
    bitmap.draw_text(ITEM_LEFT, y, BOX.width - ITEM_LEFT - 16 - (right ? RIGHT_WIDTH : 0) - buttons_width, ROW, text)

    if right
      bitmap.font.size = 16
      bitmap.draw_text(BOX.width - RIGHT_WIDTH - 10 - buttons_width, y, RIGHT_WIDTH, ROW, right, 2)
    end

    (buttons || []).each_with_index do |(glyph, tint, on), index|
      x = self.class.button_left(index + 1, buttons.size)
      draw_button(glyph, BUTTON_COLORS[tint] || GREY, on, x, y + (ROW - BUTTON_SIZE) / 2, picked && column == index + 1)
    end
  end

  # Draws an item being typed into: its label, then a text box with the text and the cursor.
  #
  # @param label [String] What the text is for.
  # @param editor [MGQ_MpUi::TextEdit] The text box's editor.
  # @param y [Integer] The line's top.
  def draw_typing(label, editor, y)
    bitmap.draw_text(ITEM_LEFT, y, TYPING_LABEL, ROW, label)
    box = Rect.new(ITEM_LEFT + TYPING_LABEL, y + 2, BOX.width - ITEM_LEFT - TYPING_LABEL - 16, ROW - 4)
    bitmap.fill_rect(box, TEXT_BOX_BACK)
    bitmap.font.color = MGQ_MpUi::WHITE
    MGQ_MpUi::TextBox.draw_line(bitmap, Rect.new(box.x + 4, y, box.width - 8, ROW), editor)
  end

  # Draws a heading, and the titles of the button columns of the items below it at its right.
  #
  # @param text [String] The heading.
  # @param titles [Array<String>, nil] The columns' titles, from the left; nil for none.
  # @param y [Integer] The line's top.
  def draw_heading(text, titles, y)
    bitmap.font.color = HEAD_COLOR
    bitmap.draw_text(8, y, BOX.width - 16, ROW, text)
    bitmap.font.size = 14

    (titles || []).each_with_index do |title, index|
      left = self.class.column_left(index + 1, titles.size)
      bitmap.draw_text(left, y, BUTTON_COLUMN, ROW, title, 1)
    end
  end

  # Draws a button: its mark in a square outlined in its color while off, filled while on, and
  # framed in white while the cursor is on it.
  #
  # @param glyph [String] Its mark, such as "!".
  # @param color [Color] Its color.
  # @param on [Boolean] Whether it is on.
  # @param x [Integer] Its left edge.
  # @param y [Integer] Its top edge.
  # @param focused [Boolean] Whether the cursor is on it.
  def draw_button(glyph, color, on, x, y, focused)
    draw_frame(x - 3, y - 3, BUTTON_SIZE + 6, MGQ_MpUi::WHITE) if focused

    if on
      bitmap.fill_rect(x, y, BUTTON_SIZE, BUTTON_SIZE, color)
    else
      draw_frame(x, y, BUTTON_SIZE, color)
      draw_frame(x + 1, y + 1, BUTTON_SIZE - 2, color)
    end

    bitmap.font.size = 16
    bitmap.font.color = on ? MGQ_MpUi::WHITE : color
    bitmap.draw_text(x, y, BUTTON_SIZE, BUTTON_SIZE, glyph, 1)
  end

  # Draws a square frame, one pixel wide.
  #
  # @param x [Integer] Its left edge.
  # @param y [Integer] Its top edge.
  # @param size [Integer] Its side.
  # @param color [Color] Its color.
  def draw_frame(x, y, size, color)
    bitmap.fill_rect(x, y, size, 1, color)
    bitmap.fill_rect(x, y + size - 1, size, 1, color)
    bitmap.fill_rect(x, y, 1, size, color)
    bitmap.fill_rect(x + size - 1, y, 1, size, color)
  end
  # Frees the box's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# A box in the middle of the screen that tells the player something, drawn like the list box: a
# title, the text broken into lines that fit, and a hint at the bottom. Whoever shows it closes it.
class Sprite_MpMessageBox < Sprite
  # Width of the box.
  WIDTH = 480

  # Room between the box's edges and its text.
  PADDING = 12

  # Height of one line of the text.
  ROW = 24

  # Creates the box, hidden, above every window.
  def initialize
    super(nil)
    self.z = MGQ_MpUi::Z[:boxes]
    self.visible = false
  end

  # Shows a message in the middle of the screen, as high as its lines need.
  #
  # @param title [String] The title at the top.
  # @param text [String] The text.
  # @param hint [String] What the hint at the bottom says.
  def show(title, text, hint)
    measure = Bitmap.new(1, 1)
    measure.font.size = Sprite_MpListBox::ITEM_SIZE
    lines = MGQ_MpUi.wrap(measure, text, WIDTH - 2 * PADDING)
    measure.dispose

    height = Sprite_MpListBox::TITLE + lines.size * ROW + Sprite_MpListBox::HINT_HEIGHT + PADDING
    bitmap.dispose if bitmap
    self.bitmap = Bitmap.new(WIDTH, height)
    self.x = (Graphics.width - WIDTH) / 2
    self.y = (Graphics.height - height) / 2
    draw(title, lines, hint)
    self.visible = true
    MGQ_MpUi.log("message box: #{title}: #{MGQ_MpLog.short(text, 160)}")
  end

  # Draws the whole box.
  #
  # @param title [String] The title.
  # @param lines [Array<String>] The text's lines.
  # @param hint [String] The hint.
  def draw(title, lines, hint)
    text_width = WIDTH - 2 * PADDING
    bitmap.fill_rect(bitmap.rect, Sprite_MpListBox::BACK)
    bitmap.font.outline = true
    bitmap.font.size = 20
    bitmap.font.color = MGQ_MpUi::WHITE
    bitmap.draw_text(PADDING, 2, text_width, Sprite_MpListBox::TITLE - 4, title)
    bitmap.font.size = Sprite_MpListBox::ITEM_SIZE
    lines.each_with_index { |line, index| bitmap.draw_text(PADDING, Sprite_MpListBox::TITLE + index * ROW, text_width, ROW, line) }
    bitmap.font.size = 16
    bitmap.font.color = Sprite_MpListBox::GREY
    bitmap.draw_text(PADDING, bitmap.height - Sprite_MpListBox::HINT_HEIGHT - 4, text_width, Sprite_MpListBox::HINT_HEIGHT, hint, 1)
  end

  # Frees the box's picture.
  def dispose
    bitmap.dispose if bitmap
    super
  end
end
