#----------------------------------------------------------------
#  ui_text_box.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# The text boxes of the mod, such as the chat box and the boxes of the world screen's forms: the
# editor of a text being typed, breaking it into lines that keep each character's place, and
# drawing a box being typed into. It builds on ui.rbx.
module MGQ_MpUi
  # A text being typed, as every text box of the mod edits it: the text, the cursor in it, and the
  # keys that type, move the cursor and remove characters. Whoever owns the box feeds it what was
  # typed, once a frame, and draws it through TextBox.
  class TextEdit
    # Frames the cursor stays shown, then hidden, while it blinks.
    BLINK_FRAMES = 30

    # Windows' codes of the keys that move the cursor to the start or the end, and that remove the
    # character after it. None of them types a character.
    HOME_KEY = 0x24
    END_KEY = 0x23
    DELETE_KEY = 0x2E

    # The text.
    attr_reader :text

    # The characters before the cursor.
    attr_reader :cursor

    # Starts editing a text, the cursor at its end.
    #
    # @param text [String] The text.
    # @param options [Hash] Whichever of :max_chars, the most characters it takes, and :allowed, a pattern every typed character must match, apply.
    def initialize(text = "", options = {})
      @text = text.to_s
      @max_chars = options[:max_chars]
      @allowed = options[:allowed]
      @cursor = @text.length
      @blink = 0
      @first = 0
      @top = 0
    end

    # Reports whether the blinking cursor shows this frame.
    #
    # @return [Boolean] Whether it does.
    def cursor_shown?
      (@blink / BLINK_FRAMES).even?
    end

    # Types one character at the cursor. Backspace removes the character before it.
    #
    # @param char [String] The character, "\r" for Enter, "\e" for Escape, "\b" for Backspace.
    # @return [Symbol, nil] :enter or :escape, which the owner acts on, :edited when the text changed, :refused for a character the box does not take, nil when nothing happened.
    def type(char)
      case char
      when "\r" then :enter
      when "\e" then :escape
      when "\b" then @cursor > 0 ? edit(@text[0, @cursor - 1] + @text[@cursor..-1], @cursor - 1) : nil
      else
        return nil if char =~ /[[:cntrl:]]/
        return :refused if (@max_chars && @text.length >= @max_chars) || (@allowed && char !~ @allowed)

        edit(@text[0, @cursor] + char + @text[@cursor..-1], @cursor + 1)
      end
    end

    # Follows a frame's keys that type nothing: left and right move the cursor, Home and End put
    # it at the start or the end, Delete removes the character after it, and in a box of several
    # lines up and down move it a line. The cursor blinks, and shows at once after anything moved
    # it.
    #
    # @param spans [Array<Array<Integer>>, nil] The lines of a box of several lines, see MGQ_MpUi.wrap_spans; nil for a box of one line.
    # @return [Boolean] Whether the text or the cursor changed.
    def update_keys(spans = nil)
      @blink += 1
      before = [@text, @cursor]
      keys = MGQ_Multiplayer::Key
      capture = MGQ_Multiplayer::Capture
      move_to(@cursor - 1) if capture.repeat?(:LEFT)
      move_to(@cursor + 1) if capture.repeat?(:RIGHT)
      move_line(spans, (capture.repeat?(:DOWN) ? 1 : 0) - (capture.repeat?(:UP) ? 1 : 0)) if spans
      move_to(0) if keys.pressed?(HOME_KEY)
      move_to(@text.length) if keys.pressed?(END_KEY)
      edit(@text[0, @cursor] + @text[@cursor + 1..-1].to_s, @cursor) if keys.pressed?(DELETE_KEY) && @cursor < @text.length
      before != [@text, @cursor]
    end

    # Changes the text and puts the cursor where it goes.
    #
    # The text is always a new string, never changed in place, so whoever draws it sees it changed.
    #
    # @param text [String] The new text.
    # @param cursor [Integer] The cursor's new place.
    # @return [Symbol] :edited.
    def edit(text, cursor)
      @text = text
      move_to(cursor)
      :edited
    end

    # Moves the cursor, within the text, and shows it at once.
    #
    # @param cursor [Integer] The place.
    def move_to(cursor)
      @cursor = [[cursor, 0].max, @text.length].min
      @blink = 0
    end

    # Moves the cursor of a box of several lines a line up or down, as far into that line as it is
    # into its own. It stays where it is at the first and the last line.
    #
    # @param spans [Array<Array<Integer>>] The lines, see MGQ_MpUi.wrap_spans.
    # @param step [Integer] 1 for the line below, -1 for the one above, 0 for neither.
    def move_line(spans, step)
      line = MGQ_MpUi.span_of(spans, @cursor)
      target = spans[line + step]
      return if step == 0 || target.nil? || line + step < 0

      # A line that is not the last ends in the space the text was broken at, which the next
      # line's start stands for.
      last = [target[1] - (line + step < spans.size - 1 ? 1 : 0), 0].max
      move_to(target[0] + [@cursor - spans[line][0], last].min)
    end

    # Picks the part of the text a box of one line shows: as much as fits, moved only as far as the
    # cursor needs to stay in sight.
    #
    # @param measure [Bitmap, Window_Base] What measures a text with the font the box draws in.
    # @param width [Integer] The width of the box.
    # @param display [String] What the box shows for the text, as long as it, such as stars for a password.
    # @return [Array] The part shown, and the characters of it before the cursor.
    def visible(measure, width, display = @text)
      @first = @cursor if @cursor < @first
      @first += 1 while @first < @cursor && measure.text_size(display[@first...@cursor]).width > width
      last = display.length
      last -= 1 while last > @cursor && measure.text_size(display[@first...last]).width > width
      [display[@first...last], @cursor - @first]
    end

    # Picks the first line a box of several lines shows: moved only as far as the cursor's line
    # needs to stay in sight.
    #
    # @param spans [Array<Array<Integer>>] The lines, see MGQ_MpUi.wrap_spans.
    # @param rows [Integer] The lines the box shows at once.
    # @return [Integer] The first line shown.
    def first_line(spans, rows)
      line = MGQ_MpUi.span_of(spans, @cursor)
      @top = [[@top, line].min, line - rows + 1].max
    end
  end

  # Draws a text box being typed into: the text around the cursor, and the cursor, in the font and
  # the color the picture is set to. Whoever owns the box draws its background, and what it shows
  # while nobody types into it.
  module TextBox
    # Width of the cursor.
    CURSOR_WIDTH = 2

    # Room the cursor keeps above and below it in a box of one line.
    CURSOR_INSET = 3

    # Room the cursor keeps above and below it on a line of a box of several lines.
    LINE_CURSOR_INSET = 2

    # Draws a box of one line.
    #
    # @param bitmap [Bitmap] The picture drawn on, such as a sprite's or a window's contents.
    # @param rect [Rect] Where the text goes.
    # @param editor [TextEdit] The box's editor.
    # @param display [String] What the box shows for the text, as long as it, such as stars for a password.
    def self.draw_line(bitmap, rect, editor, display = editor.text)
      shown, before = editor.visible(bitmap, rect.width - CURSOR_WIDTH, display)
      bitmap.draw_text(rect.x, rect.y, rect.width, rect.height, shown)
      return unless editor.cursor_shown?

      draw_cursor(bitmap, rect.x + bitmap.text_size(shown[0, before]).width, rect.y + CURSOR_INSET, rect.height - CURSOR_INSET * 2)
    end

    # Draws a box of several lines.
    #
    # @param bitmap [Bitmap] The picture drawn on.
    # @param rect [Rect] Where the text goes.
    # @param editor [TextEdit] The box's editor.
    # @param spans [Array<Array<Integer>>] The text's lines, see MGQ_MpUi.wrap_spans.
    # @param line_height [Integer] The height of one line.
    def self.draw_area(bitmap, rect, editor, spans, line_height)
      rows = rect.height / line_height
      top = editor.first_line(spans, rows)
      cursor_line = MGQ_MpUi.span_of(spans, editor.cursor)

      spans[top, rows].each_with_index do |(start, length), row|
        y = rect.y + row * line_height
        bitmap.draw_text(rect.x, y, rect.width, line_height, editor.text[start, length])
        next unless top + row == cursor_line && editor.cursor_shown?

        before = bitmap.text_size(editor.text[start, editor.cursor - start]).width
        draw_cursor(bitmap, rect.x + before, y + LINE_CURSOR_INSET, line_height - LINE_CURSOR_INSET * 2)
      end
    end

    # Draws the cursor, in the color of the text.
    #
    # @param bitmap [Bitmap] The picture drawn on.
    # @param x [Integer] The left edge.
    # @param y [Integer] The top edge.
    # @param height [Integer] The height.
    def self.draw_cursor(bitmap, x, y, height)
      bitmap.fill_rect(x, y, CURSOR_WIDTH, height, bitmap.font.color)
    end
  end

  # Breaks a text into lines that fit a width without changing a character of it, so a place in
  # the text is a place in a line: each line is a stretch of the text, broken before a word.
  #
  # @param text [String] The text.
  # @param width [Integer] The width in pixels.
  # @yieldparam part [String] A word or a run of spaces.
  # @yieldreturn [Integer] Its width in the font the lines are drawn in.
  # @return [Array<Array<Integer>>] Each line's first character and length, one empty line for an empty text.
  def self.wrap_spans(text, width)
    spans = []
    start = 0
    at = 0
    used = 0

    text.scan(/\S+|\s+/).each do |part|
      part_width = yield(part)

      if part =~ /\S/ && used + part_width > width && at > start
        spans.push([start, at - start])
        start = at
        used = 0
      end

      used += part_width
      at += part.length
    end
    spans.push([start, text.length - start])
  end

  # Finds the line of wrap_spans a place in the text is on: the last one that starts at or before it.
  #
  # @param spans [Array<Array<Integer>>] The lines.
  # @param place [Integer] The characters before the place.
  # @return [Integer] The line.
  def self.span_of(spans, place)
    line = spans.rindex { |start, _length| start <= place }
    line || 0
  end
end
