#----------------------------------------------------------------
#  ui_boxes.rbx
#
#  Changelog:
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# The boxes of MGQ Online's old screens, until each screen is rebuilt on the Mod Framework's
# components: a list window that scrolls by the mouse wheel, the lines across the top of a screen,
# the list box and the message box, drawn in the framework's style and placed by its layout.

# Lets a list window of the mod scroll with the mouse wheel while the mouse points at it, and
# shows a scrollbar in its right padding while its rows outgrow it. Included into a
# Window_Selectable.
module MGQ_MpScrollingWindow
  # Rows one notch of the wheel scrolls.
  WHEEL_ROWS = 1

  # Updates the window as its class does, then scrolls it with the wheel and keeps the
  # scrollbar where its rows stand.
  def update
    super
    scroll_by_wheel
    update_scrollbar
  end

  # Hides the scrollbar with the window, also when the window is not updated any more.
  #
  # @param visible [Boolean] Whether the window shows.
  def visible=(visible)
    super
    @mgq_mp_scrollbar.visible = false if @mgq_mp_scrollbar && !visible
  end

  # Scrolls the rows by the wheel's notches while the mouse points at the window, moving the
  # cursor along into sight.
  #
  # @return [Boolean] Whether it scrolled.
  def scroll_by_wheel
    notches = Mod_Framework::UI::Mouse.wheel
    return false if notches == 0 || !wheel_ready? || !pointed_at?

    before = top_row
    self.top_row = top_row - notches * WHEEL_ROWS
    return false if top_row == before

    keep_cursor_in_sight
    true
  end

  # Tells whether the window takes the wheel: shown, open, with more rows than fit, and free to
  # scroll.
  #
  # @return [Boolean] Whether it does.
  def wheel_ready?
    visible && open? && row_max > page_row_max && takes_wheel?
  end

  # Tells whether the window is free to scroll: while it takes the input, or has no cursor to
  # keep in sight. A window may narrow it.
  #
  # @return [Boolean] Whether it is.
  def takes_wheel?
    active || index < 0
  end

  # Tells whether the mouse points at the window.
  #
  # @return [Boolean] Whether it does.
  def pointed_at?
    position = Mod_Framework::UI::Mouse.position
    return false unless position

    left = x + (viewport ? viewport.rect.x - viewport.ox : 0)
    top = y + (viewport ? viewport.rect.y - viewport.oy : 0)
    position[0] >= left && position[0] < left + width && position[1] >= top && position[1] < top + height
  end

  # Moves the cursor onto the nearest row in sight once the rows scrolled it out of sight, and
  # draws it where its row lies now.
  def keep_cursor_in_sight
    return update_cursor if index < 0

    first = top_row * col_max
    last = [(top_row + page_row_max) * col_max, item_max].min - 1
    kept = [[index, first].max, last].min
    kept == index ? update_cursor : select(kept)
  end

  # Draws the scrollbar if the rows moved or changed, the window's size or the interface look
  # changed, and shows it beside the rows while the window shows, open, with more rows than fit.
  def update_scrollbar
    bar = scrollbar
    shown = visible && open? && row_max > page_row_max
    bar.visible = shown
    return unless shown

    height = self.height - padding - padding_bottom
    bar.viewport = viewport unless bar.viewport == viewport
    bar.x = x + width - (padding + Mod_Framework::UI::Style::SCROLLBAR_WIDTH) / 2
    bar.y = y + padding
    bar.z = z + 1
    drawn = [height, row_max, page_row_max, top_row, Mod_Framework::UI::Theme.serial]
    return if drawn == @mgq_mp_scrollbar_drawn

    @mgq_mp_scrollbar_drawn = drawn
    unless bar.bitmap && bar.bitmap.height == height
      bar.bitmap.dispose if bar.bitmap
      bar.bitmap = Bitmap.new(Mod_Framework::UI::Style::SCROLLBAR_WIDTH, [height, 1].max)
    end
    bar.bitmap.clear
    Mod_Framework::UI::Style.draw_scrollbar(bar.bitmap, 0, 0, height, top_row, page_row_max, row_max)
  end

  # Returns the scrollbar's sprite, made at first ask.
  #
  # @return [Sprite] The sprite.
  def scrollbar
    @mgq_mp_scrollbar ||= Sprite.new(viewport)
  end

  # Frees the scrollbar with the window.
  def dispose
    if @mgq_mp_scrollbar
      @mgq_mp_scrollbar.bitmap.dispose if @mgq_mp_scrollbar.bitmap
      @mgq_mp_scrollbar.dispose
      @mgq_mp_scrollbar = nil
    end
    super
  end
end

# The lines across the top of a screen of the mod, such as the world screen's.
class Window_MpInfo < Window_Base
  include Mod_Framework::UI::Themed

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
    wrapped = lines.compact.map { |line| Mod_Framework::UI.wrap(self, line, contents_width) }.flatten
    contents.clear
    wrapped.first(@rows).each_with_index do |line, index|
      draw_text(0, index * line_height, contents_width, line_height, line)
    end
  end
end

# A large box over a screen that lists lines under a title, as the World overview does: headings
# and items, one of which is picked, with a hint at the bottom. Whoever opens it moves the pick and
# closes it; the box only draws. The player moves and resizes it with Alt (Mod_Framework::UI::Layout): the
# items take the width the fixed columns at their right leave, and the list as many lines as fit.
class Sprite_MpListBox < Sprite
  # Room between the box and either side of the screen where it starts.
  SIDE = 40

  # Room between the box and the top of the screen where it starts.
  TOP = 32

  # Room between the box and the bottom of the screen where it starts.
  BOTTOM = 44

  # How far above the screen's windows the box lies.
  Z = Mod_Framework::UI::Z[:boxes]

  # Height of one line of the list.
  ROW = 24

  # Height of the title.
  TITLE = 30

  # Height of the hint at the bottom.
  HINT_HEIGHT = 22

  # Room between the last line in sight and the hint.
  LIST_ROOM = 8

  # Room between the box's side edges and its title, its headings and its hint.
  EDGE = 10

  # Left edge of an item's text.
  ITEM_LEFT = 24

  # Room between an item's text and what lies right of it.
  ITEM_GAP = 16

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

  # The colors a button may have, by name.
  BUTTON_COLORS = { :red => Color.new(230, 50, 50), :orange => Color.new(255, 150, 20) }

  # Pixels the title keeps from the box's top and bottom edges of its row.
  TITLE_INSET = 2

  # Pixels the picked row's plate keeps from the box's side edges.
  PICK_INSET = 4

  # Pixels the scrollbar keeps from the box's right edge.
  SCROLLBAR_INSET = 4

  # Lines one notch of the mouse wheel scrolls unless the list's owner says another.
  WHEEL_LINES = 1

  # The box's place in the layout.
  LAYOUT_ID = :list_box

  # The box's name in the outlines.
  LAYOUT_NAME = "List box"

  # Least width of an item's text and of the title's start, so a name stays readable.
  ITEM_MIN = 144

  # Most columns of buttons an item has, the mod picker's two.
  MOST_BUTTONS = 2

  # Fewest lines of the list the box shows.
  MIN_ROWS = 3

  # Least width of the box: an item's text at ITEM_MIN with what its right end says and the most
  # buttons beside it.
  MIN_WIDTH = ITEM_LEFT + ITEM_MIN + ITEM_GAP + RIGHT_WIDTH + EDGE + MOST_BUTTONS * BUTTON_COLUMN + BUTTON_MARGIN

  # Least height of the box: the title, MIN_ROWS lines and the hint.
  MIN_HEIGHT = TITLE + MIN_ROWS * ROW + LIST_ROOM + HINT_HEIGHT

  # Tells what the hint says unless the list says another, naming the cancel key as the player
  # bound it.
  #
  # @return [String] The hint.
  def self.hint
    ["Up and down: move", Mod_Framework::UI.close_hint("a click outside")].join(Mod_Framework::UI::Style::HINT_GAP)
  end

  # Tells where the box starts on the screen: SIDE from either side, TOP from the top and BOTTOM
  # from the bottom, read from the screen once it is first asked.
  #
  # @return [Rect] The box.
  def self.box
    @box ||= Rect.new(SIDE, TOP, Graphics.width - 2 * SIDE, Graphics.height - TOP - BOTTOM)
  end

  # Tells where the box lies now: where the player left it, else where it starts.
  #
  # @return [Rect] The box.
  def self.rect
    register_layout
    Mod_Framework::UI::Layout.rect(LAYOUT_ID, box)
  end

  # Makes the box movable with its least size, or another least width once a list needs more;
  # nothing while the least width stays.
  #
  # @param min_width [Integer, nil] The least width, nil for the one registered, MIN_WIDTH at first.
  def self.register_layout(min_width = nil)
    least = min_width || @least || MIN_WIDTH
    return if least == @least

    @least = least
    Mod_Framework::UI::Layout.register(LAYOUT_ID, LAYOUT_NAME, :min_size => [least, MIN_HEIGHT])
  end

  # Tells the least width a list needs: MIN_WIDTH, its note whole after ITEM_MIN of the title, and
  # its hint whole at the smaller size, as far as the box's width where it starts gives it, since a
  # longer hint is squeezed there already.
  #
  # @param view [View] What the box lists.
  # @return [Integer] The width.
  def self.least_width(view)
    style = Mod_Framework::UI::Style
    title = 2 * EDGE + ITEM_MIN + (view.note ? measure(view.note, style::TITLE_SIZE) + style::PAD : 0)
    hint = [measure(view.hint || self.hint, style::TINY_SIZE) + 2 * EDGE, box.width].min
    [MIN_WIDTH, title, hint].max
  end

  # Measures a text in the style's font at a size, which the boxes of this script share.
  #
  # @param text [String] The text.
  # @param size [Integer] The font's size.
  # @return [Integer] Its width in pixels.
  def self.measure(text, size)
    @measure = Bitmap.new(1, 1) if @measure.nil? || @measure.disposed?
    Mod_Framework::UI::Style.use_font(@measure, size, Mod_Framework::UI::Style::TEXT)
    @measure.text_size(text.to_s).width
  end

  # Tells how many lines of the list the box shows at once.
  #
  # @param height [Integer] The box's height, the height it has now by default.
  # @return [Integer] The lines.
  def self.list_rows(height = rect.height)
    (height - TITLE - HINT_HEIGHT - LIST_ROOM) / ROW
  end

  # What the box lists.
  #
  # @!attribute title [String] The title at the top left.
  # @!attribute note [String, nil] What the top right says.
  # @!attribute lines [Array<Array>] [:head, text, titles] for a heading, titles nil or those of the
  #   button columns below it; [:item, text, color, right, buttons] for an item: color is :plain,
  #   :good, :gold, :bad or :grey, right what its right end says or nil, buttons nil or each
  #   button's mark, color (:red or :orange) and whether it is on. An item being typed into adds
  #   [editor, text, cursor, cursor shown], its text the box's label.
  # @!attribute selected [Integer, nil] The line of the item picked, nil without items.
  # @!attribute scroll [Integer] The first line in sight.
  # @!attribute hint [String, nil] What the bottom says, nil for Sprite_MpListBox.hint.
  # @!attribute column [Integer, nil] The button of the picked item the cursor is on, from 1; nil or
  #   0 for the item itself.
  View = Struct.new(:title, :note, :lines, :selected, :scroll, :hint, :column) do
    # Makes a list with its first item picked.
    #
    # @param title [String] The title.
    # @param note [String, nil] What the top right says.
    # @param lines [Array<Array>] The lines.
    # @param hint [String, nil] What the bottom says, nil for Sprite_MpListBox.hint.
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
      rows = Sprite_MpListBox.list_rows
      self.scroll = top if top < scroll
      self.scroll = line - rows + 1 if line >= scroll + rows
    end

    # Tells whether the item picked lies outside the lines in sight.
    #
    # @param rows [Integer] The lines the box shows.
    # @return [Boolean] Whether it does; false without an item picked.
    def out_of_sight?(rows)
      !selected.nil? && (selected < scroll || selected >= scroll + rows)
    end

    # Scrolls the lines, within the list, and moves the pick along onto the nearest item in sight
    # once it left the lines in sight.
    #
    # @param step [Integer] Lines to scroll down, a negative number to scroll up.
    # @param rows [Integer] The lines the box shows.
    # @return [Boolean] Whether it scrolled.
    def scroll_by(step, rows)
      top = [[scroll + step, lines.size - rows].min, 0].max
      return false if top == scroll

      self.scroll = top
      in_sight = items.select { |line| line >= top && line < top + rows }
      self.selected = selected < top ? in_sight.first : in_sight.last if out_of_sight?(rows) && !in_sight.empty?
      true
    end
  end

  # Scrolls a list the box shows by the mouse wheel's notches while the mouse points at the box.
  #
  # @param view [View] What the box lists.
  # @param step [Integer] Lines one notch scrolls.
  # @return [Boolean] Whether it scrolled.
  def self.scroll_by_wheel(view, step = WHEEL_LINES)
    notches = Mod_Framework::UI::Mouse.wheel
    return false if notches == 0

    position = Mod_Framework::UI::Mouse.position
    position && inside?(position[0], position[1]) ? view.scroll_by(-notches * step, list_rows) : false
  end

  # Creates the box, hidden, above every window, where it lies now.
  def initialize
    super(nil)
    rect = self.class.rect
    self.bitmap = Bitmap.new(rect.width, rect.height)
    self.x = rect.x
    self.y = rect.y
    self.z = Z
    @motion = Mod_Framework::UI::Motion.new(self)
    @shown = nil
    @view = nil
  end

  # Reports whether a point of the screen lies in the box.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param place [Rect] The box, where it lies now by default.
  # @return [Boolean] Whether it does.
  def self.inside?(x, y, place = rect)
    x >= place.x && x < place.x + place.width && y >= place.y && y < place.y + place.height
  end

  # Finds the button of an item under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param count [Integer] How many buttons the item has.
  # @return [Integer, nil] The button, from 1 at the left; nil outside them.
  def self.button_at(x, count)
    place = rect
    (1..count).find do |button|
      left = place.x + column_left(button, count, place.width)
      x >= left && x < left + BUTTON_COLUMN
    end
  end

  # Tells where a column of buttons starts, inside the box.
  #
  # @param button [Integer] The column, from 1 at the left.
  # @param count [Integer] How many columns there are.
  # @param width [Integer] The box's width, the width it has now by default.
  # @return [Integer] Its left edge.
  def self.column_left(button, count, width = rect.width)
    width - BUTTON_MARGIN - (count - button + 1) * BUTTON_COLUMN
  end

  # Tells where a button of an item starts, inside the box: in the middle of its column.
  #
  # @param button [Integer] The button, from 1 at the left.
  # @param count [Integer] How many buttons the item has.
  # @param width [Integer] The box's width, the width it has now by default.
  # @return [Integer] Its left edge.
  def self.button_left(button, count, width = rect.width)
    column_left(button, count, width) + (BUTTON_COLUMN - BUTTON_SIZE) / 2
  end

  # Finds the line of the list under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param view [View] What the box lists.
  # @return [Integer, nil] The line, nil outside the list.
  def self.line_at(x, y, view)
    place = rect
    return nil unless inside?(x, y, place) && y >= place.y + TITLE

    row = (y - place.y - TITLE) / ROW
    line = view.scroll + row
    row < list_rows(place.height) && line < view.lines.size ? line : nil
  end

  # Shows a list, fading it in, drawing it if it, the box's size or the interface look changed;
  # the item picked is scrolled into sight once a smaller box hides it.
  #
  # @param view [View] What the box lists.
  def show(view)
    @motion.show
    needs = [view.note, view.hint]
    if needs != @needs
      @needs = needs
      self.class.register_layout(self.class.least_width(view))
    end
    @view = view
    follow_layout
    view.pick(view.selected) if view.out_of_sight?(self.class.list_rows(bitmap.height))
    drawn = view.to_a + [bitmap.width, bitmap.height, Mod_Framework::UI::Theme.serial]
    return if drawn == @shown

    @shown = drawn.map { |part| part.is_a?(Array) ? part.dup : part }
    draw(view)
  end

  # Fades the box out, keeping its picture until it is gone.
  def hide
    @motion.hide
    @shown = nil
  end

  # Follows the layout and moves the fade a frame on, and offers the box to the layout while it
  # shows. Called every frame by the screen that owns the box.
  def update
    super
    follow_layout
    @motion.update
    Mod_Framework::UI::Layout.offer(LAYOUT_ID, x, y, bitmap.width, bitmap.height, z) if @motion.shown?
  end

  # Takes the place the layout gives: a picture of the new size, with the list drawn anew, once the
  # size changed, and the place without a slide.
  def follow_layout
    rect = self.class.rect
    if rect.width != bitmap.width || rect.height != bitmap.height
      bitmap.dispose
      self.bitmap = Bitmap.new(rect.width, rect.height)
      @shown = nil
      draw(@view) if @view
    end
    @motion.place(rect.x, rect.y)
  end

  # Draws the whole box: its back in its frame, the title with its note at the right, the lines in
  # sight with a scrollbar at their right while not all fit, the hint.
  #
  # @param view [View] What the box lists.
  def draw(view)
    style = Mod_Framework::UI::Style
    width = bitmap.width
    bitmap.clear
    style.draw_box(bitmap, 0, 0, width, bitmap.height)
    style.use_font(bitmap, style::TITLE_SIZE, style::GOOD)
    note_width = view.note ? bitmap.text_size(view.note).width + style::PAD : 0
    bitmap.draw_text(EDGE, TITLE_INSET, width - 2 * EDGE, TITLE - 2 * TITLE_INSET, view.note, 2) if view.note
    style.use_font(bitmap, style::TITLE_SIZE, style::TEXT)
    bitmap.draw_text(EDGE, TITLE_INSET, width - 2 * EDGE, TITLE - 2 * TITLE_INSET, Mod_Framework::UI.cut(bitmap, view.title, width - 2 * EDGE - note_width))
    rows = self.class.list_rows(bitmap.height)
    lines = view.lines[view.scroll, rows] || []
    lines.each_with_index { |line, index| draw_line(line, TITLE + index * ROW, view.scroll + index == view.selected, view.column.to_i) }
    style.draw_scrollbar(bitmap, width - SCROLLBAR_INSET - style::SCROLLBAR_WIDTH, TITLE, rows * ROW, view.scroll, rows, view.lines.size)
    style.draw_hint(bitmap, EDGE, bitmap.height - HINT_HEIGHT, width - 2 * EDGE, HINT_HEIGHT, view.hint || self.class.hint)
  end

  # Draws one line of the list: a heading, with the titles of the button columns below it, or an
  # item, its text cut to the room before what lies at its right.
  #
  # @param line [Array] The line, see View.
  # @param y [Integer] The line's top.
  # @param picked [Boolean] Whether it is the item picked.
  # @param column [Integer] The button the cursor is on while it is picked, 0 for the item itself.
  def draw_line(line, y, picked, column = 0)
    kind, text, color, right, buttons, typing = line
    style = Mod_Framework::UI::Style
    width = bitmap.width

    if kind == :head
      draw_heading(text, color, y)
      return
    end

    bitmap.fill_rect(PICK_INSET, y, width - 2 * PICK_INSET, ROW, style::PICKED) if picked
    style.use_font(bitmap, style::TEXT_SIZE, { :good => style::GOOD, :gold => style::GOLD, :bad => style::BAD, :grey => style::DIM }[color] || style::TEXT)
    return draw_typing(text, typing[0], y) if typing

    buttons_width = buttons ? buttons.size * BUTTON_COLUMN + BUTTON_MARGIN : 0
    room = width - ITEM_LEFT - ITEM_GAP - (right ? RIGHT_WIDTH : 0) - buttons_width
    bitmap.draw_text(ITEM_LEFT, y, room, ROW, Mod_Framework::UI.cut(bitmap, text, room))

    if right
      bitmap.font.size = style::SMALL_SIZE
      bitmap.draw_text(width - RIGHT_WIDTH - EDGE - buttons_width, y, RIGHT_WIDTH, ROW, Mod_Framework::UI.cut(bitmap, right, RIGHT_WIDTH), 2)
    end

    (buttons || []).each_with_index do |(glyph, tint, on), index|
      x = self.class.button_left(index + 1, buttons.size, width)
      draw_button(glyph, BUTTON_COLORS[tint] || style::DIM, on, x, y + (ROW - BUTTON_SIZE) / 2, picked && column == index + 1)
    end
  end

  # Draws an item being typed into: its label, then a text box with the text and the cursor.
  #
  # @param label [String] What the text is for.
  # @param editor [Mod_Framework::UI::TextEdit] The text box's editor.
  # @param y [Integer] The line's top.
  def draw_typing(label, editor, y)
    style = Mod_Framework::UI::Style
    bitmap.draw_text(ITEM_LEFT, y, TYPING_LABEL, ROW, Mod_Framework::UI.cut(bitmap, label, TYPING_LABEL))
    box = Rect.new(ITEM_LEFT + TYPING_LABEL, y + 2, bitmap.width - ITEM_LEFT - TYPING_LABEL - ITEM_GAP, ROW - 4)
    bitmap.fill_rect(box, style::FIELD)
    bitmap.font.color = style::TEXT
    Mod_Framework::UI::TextBox.draw_line(bitmap, Rect.new(box.x + 4, y, box.width - 8, ROW), editor)
  end

  # Draws a heading, and the titles of the button columns of the items below it at its right.
  #
  # @param text [String] The heading.
  # @param titles [Array<String>, nil] The columns' titles, from the left; nil for none.
  # @param y [Integer] The line's top.
  def draw_heading(text, titles, y)
    style = Mod_Framework::UI::Style
    style.use_font(bitmap, style::TEXT_SIZE, style::HEADING)
    bitmap.draw_text(EDGE, y, bitmap.width - 2 * EDGE, ROW, Mod_Framework::UI.cut(bitmap, text, bitmap.width - 2 * EDGE))
    bitmap.font.size = style::TINY_SIZE

    (titles || []).each_with_index do |title, index|
      left = self.class.column_left(index + 1, titles.size, bitmap.width)
      bitmap.draw_text(left, y, BUTTON_COLUMN, ROW, title, 1)
    end
  end

  # Draws a button: its mark in a square outlined in its color while off, filled while on, and
  # framed in the text's color while the cursor is on it.
  #
  # @param glyph [String] Its mark, such as "!".
  # @param color [Color] Its color.
  # @param on [Boolean] Whether it is on.
  # @param x [Integer] Its left edge.
  # @param y [Integer] Its top edge.
  # @param focused [Boolean] Whether the cursor is on it.
  def draw_button(glyph, color, on, x, y, focused)
    style = Mod_Framework::UI::Style
    draw_frame(x - 3, y - 3, BUTTON_SIZE + 6, style::TEXT) if focused

    if on
      bitmap.fill_rect(x, y, BUTTON_SIZE, BUTTON_SIZE, color)
    else
      draw_frame(x, y, BUTTON_SIZE, color)
      draw_frame(x + 1, y + 1, BUTTON_SIZE - 2, color)
    end

    style.use_font(bitmap, style::SMALL_SIZE, on ? style::TEXT : color)
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
# The player moves it and changes its width with Alt (Mod_Framework::UI::Layout); its height follows
# the lines the text breaks into.
class Sprite_MpMessageBox < Sprite
  extend MGQ_MpLog

  # What starts this class's lines in the log.
  LOG_TAG = "ui"

  # Room between the box and either side of the screen where it starts.
  SIDE = 80

  # Room between the box's edges and its text.
  PADDING = 2 * Mod_Framework::UI::Style::PAD

  # Height of one line of the text.
  ROW = 24

  # The box's place in the layout.
  LAYOUT_ID = :message_box

  # The box's name in the outlines.
  LAYOUT_NAME = "Message box"

  # Least width of the box: the text's room as wide as the list box's least item.
  MIN_WIDTH = Sprite_MpListBox::ITEM_MIN + 2 * PADDING

  # Least height of the box: the title, a line and the hint.
  MIN_HEIGHT = Sprite_MpListBox::TITLE + ROW + Sprite_MpListBox::HINT_HEIGHT + PADDING

  # The boxes made and not freed, see boxes.
  @boxes = []

  # Lists the boxes made and not freed, which follow the layout once a frame.
  #
  # @return [Array<Sprite_MpMessageBox>] The boxes.
  def self.boxes
    @boxes
  end

  # Has every box that shows follow the layout. Called after every Graphics.update, since whoever
  # shows a box only closes it.
  def self.follow_layouts
    @boxes.each { |box| box.follow_layout if box.visible && !box.disposed? }
  end

  # Makes the box movable with its least size, or another least width once a hint needs more;
  # nothing while the least width stays.
  #
  # @param min_width [Integer, nil] The least width, nil for the one registered, MIN_WIDTH at first.
  def self.register_layout(min_width = nil)
    least = min_width || @least || MIN_WIDTH
    return if least == @least

    @least = least
    Mod_Framework::UI::Layout.register(LAYOUT_ID, LAYOUT_NAME, :min_size => [least, MIN_HEIGHT], :resizable => :width)
  end

  # Tells the least width a hint needs: MIN_WIDTH, and the hint whole at the smaller size, as far as
  # the box's width where it starts gives it.
  #
  # @param hint [String] The hint.
  # @return [Integer] The width.
  def self.least_width(hint)
    hint_width = Sprite_MpListBox.measure(hint, Mod_Framework::UI::Style::TINY_SIZE) + 2 * PADDING
    [MIN_WIDTH, [hint_width, Graphics.width - 2 * SIDE].min].max
  end

  # Creates the box, hidden, above every window.
  def initialize
    super(nil)
    self.z = Mod_Framework::UI::Z[:boxes]
    self.visible = false
    self.class.boxes.push(self)
  end

  # Shows a message, as wide as the screen leaves between SIDE on either side and as high as its
  # lines need, in the middle of the screen unless the player moved it.
  #
  # @param title [String] The title at the top.
  # @param text [String] The text.
  # @param hint [String] What the hint at the bottom says.
  def show(title, text, hint)
    @title = title.to_s
    @text = text.to_s
    @hint = hint.to_s
    @lines = nil
    @drawn = nil
    self.class.register_layout(self.class.least_width(@hint))
    width = Graphics.width - 2 * SIDE
    height = height_of(lines_at(width))
    @default = Rect.new((Graphics.width - width) / 2, (Graphics.height - height) / 2, width, height)
    follow_layout
    self.visible = true
    self.class.log("message box: #{title}: #{MGQ_MpLog.short(text, 160)}")
  end

  # Takes the place the layout gives: the text broken anew and the box drawn anew once its width or
  # the interface look changed, as high as the lines need and wholly on the screen, and offers the
  # box to the layout.
  def follow_layout
    return unless @default

    rect = Mod_Framework::UI::Layout.rect(LAYOUT_ID, @default)
    lines = lines_at(rect.width)
    height = height_of(lines)
    drawn = [rect.width, height, Mod_Framework::UI::Theme.serial]
    if drawn != @drawn
      @drawn = drawn
      bitmap.dispose if bitmap
      self.bitmap = Bitmap.new(rect.width, height)
      draw(@title, lines, @hint)
    end
    self.x = rect.x
    self.y = Mod_Framework::UI.within(rect.y, 0, [Graphics.height - height, 0].max)
    Mod_Framework::UI::Layout.offer(LAYOUT_ID, x, y, rect.width, height, z)
  end

  # Breaks the text into the lines that fit a width, kept for the last width asked.
  #
  # @param width [Integer] The box's width.
  # @return [Array<String>] The lines.
  def lines_at(width)
    return @lines if @lines && @lines_width == width

    style = Mod_Framework::UI::Style
    measure = Bitmap.new(1, 1)
    style.use_font(measure, style::TEXT_SIZE, style::TEXT)
    @lines = Mod_Framework::UI.wrap(measure, @text, width - 2 * PADDING)
    @lines_width = width
    measure.dispose
    @lines
  end

  # Tells how high the box is with a number of lines.
  #
  # @param lines [Array<String>] The lines.
  # @return [Integer] The height.
  def height_of(lines)
    Sprite_MpListBox::TITLE + lines.size * ROW + Sprite_MpListBox::HINT_HEIGHT + PADDING
  end

  # Draws the whole box, its back in its frame, the title cut to its width and the hint drawn whole.
  #
  # @param title [String] The title.
  # @param lines [Array<String>] The text's lines.
  # @param hint [String] The hint.
  def draw(title, lines, hint)
    style = Mod_Framework::UI::Style
    text_width = bitmap.width - 2 * PADDING
    style.draw_box(bitmap, 0, 0, bitmap.width, bitmap.height)
    style.use_font(bitmap, style::TITLE_SIZE, style::TEXT)
    inset = Sprite_MpListBox::TITLE_INSET
    bitmap.draw_text(PADDING, inset, text_width, Sprite_MpListBox::TITLE - 2 * inset, Mod_Framework::UI.cut(bitmap, title, text_width))
    bitmap.font.size = style::TEXT_SIZE
    lines.each_with_index { |line, index| bitmap.draw_text(PADDING, Sprite_MpListBox::TITLE + index * ROW, text_width, ROW, line) }
    style.draw_hint(bitmap, PADDING, bitmap.height - Sprite_MpListBox::HINT_HEIGHT - 4, text_width, Sprite_MpListBox::HINT_HEIGHT, hint)
  end

  # Frees the box's picture.
  def dispose
    self.class.boxes.delete(self)
    bitmap.dispose if bitmap
    super
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After every frame, the message boxes follow the layout, which the player changes with Alt,
  # before the frame's tick hands the layout their places: the title screen's update never calls
  # Scene_Base's.
  MGQ_MpHooks.after(Graphics.singleton_class, :update, "ui") { Sprite_MpMessageBox.follow_layouts }

  # After every scene's start the boxes become known to the layout, so putting every box back in
  # Options > Mods reaches them before they first show.
  MGQ_MpHooks.after(Scene_Base, :start, "ui") { [Sprite_MpListBox, Sprite_MpMessageBox].each { |box| box.register_layout } }
rescue => e
  Sprite_MpMessageBox.log("hooks FAILED: #{e.class}: #{e.message}")
end
