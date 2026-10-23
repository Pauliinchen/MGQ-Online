#----------------------------------------------------------------
#  ui_text_box.rbx
#
#  Changelog:
#      Paulinchen  2026-10-23: Kept the text being typed in C#, which takes what is typed straight from the keyboard
#                            - Broke texts keeping each character's place in C#
#      Paulinchen  2026-10-12: Scrolled a box of several lines with the cursor kept in sight
#                            - Drew a scrollbar beside a box of several lines that holds more than it shows
#      Paulinchen  2026-10-04: Split a long word into its characters the way Ruby 1.9 can count
#                            - Broke a word longer than a line of a box of several lines inside the word
#                            - Created
#
#----------------------------------------------------------------

# The text boxes of the mod, such as the chat box, the boxes of the world screen's forms and the
# text screen: the text being typed, kept by C# (EditModel in MGQOnline.Game's Ui/Text) with what is
# typed taken straight from the DLL's keyboard, breaking a text into lines that keep each
# character's place, and drawing a box being typed into. It builds on ui.rbx.
module MGQ_MpUi
  # A text being typed into a box: what C# keeps of it (the text, the cursor, the blinking and the
  # part the box shows), mirrored from the box's events. One box is typed into at a time; opening
  # one closes the one before. Its owner hands the frame's keys over with follow where it read the
  # keys before, acts on what typing did with take a frame later, and draws it through TextBox.
  class TextEdit
    # Opens a box in C#, EditModel.OpenTopic.
    OPEN = "ui.edit.open"

    # Closes a box, EditModel.CloseTopic.
    CLOSE = "ui.edit.close"

    # Changes a box, EditModel.SetTopic.
    SET = "ui.edit.set"

    # Tells a box where it is drawn, EditModel.ViewTopic.
    VIEW = "ui.edit.view"

    # Types into a box at once, EditModel.TypeTopic.
    TYPE = "ui.edit.type"

    # The box's event, EditModel.EventTopic.
    EVENT = "ui.edit"

    # The box's name in the frame's tick.
    MODEL = "edit"

    # Windows' code of the Home key, which moves the cursor to the start.
    HOME_KEY = 0x24

    # Windows' code of the End key, which moves the cursor to the end.
    END_KEY = 0x23

    # Windows' code of the Delete key, which removes the character after the cursor.
    DELETE_KEY = 0x2E

    # Windows' code of the left Alt, while which a box that drops Alt codes drops what is typed; the
    # right Alt is AltGr, which types.
    ALT_KEY = 0xA4

    # The bits of the keys that type nothing, EditKeys in C#: left and right as the game's buttons
    # that repeat while held, then Home, End and Delete from Windows.
    ARROW_BITS = { :LEFT => 1, :RIGHT => 2 }

    # The bits of up and down, which only a box of several lines reads, so a box of one line leaves
    # them to its owner, such as the chat's list of names.
    LINE_BITS = { :UP => 4, :DOWN => 8 }

    # The bits of every arrow, which a box of several lines reads.
    AREA_BITS = ARROW_BITS.merge(LINE_BITS)

    # The bits of Home, End and Delete, by Windows' codes.
    KEY_BITS = { HOME_KEY => 16, END_KEY => 32, DELETE_KEY => 64 }

    # What typing did, as a box's event names it.
    OUTCOMES = { "enter" => :enter, "escape" => :escape, "tab" => :tab, "typed" => :typed, "erased" => :erased, "refused" => :refused }

    # What take hands out: what typing did since the last take, in order (:enter, :escape, :tab,
    # :typed, :erased, :refused), how many keys went down and characters came, and whether the box
    # changed.
    Taken = Struct.new(:outcomes, :keys, :chars, :changed)

    # The box open now, which takes the events.
    @open = nil

    # The text.
    attr_reader :text

    # The characters before the cursor.
    attr_reader :cursor

    # The box's id in C#, nil while the bridge is closed.
    attr_reader :id

    # Opens a box in C#, the cursor at the text's end.
    #
    # @param text [String] The text.
    # @param options [Hash] Whichever of :max_chars (the most characters it takes), :allowed (a
    #   pattern of one character every typed character must match), :mask (the character shown for
    #   each, such as "*"), :echo ([Windows' code of the key that opened it, frames], whose character
    #   it leaves out once) and :alt_codes (frames after the left Alt in which typing is dropped) apply.
    def initialize(text = "", options = {})
      @text = text.to_s
      @cursor = @text.length
      @shown = true
      @view = nil
      @drawn = nil
      @taken = Taken.new([], 0, 0, false)
      @alt_codes = !options[:alt_codes].nil?
      request = { "text" => @text }
      request["max_chars"] = options[:max_chars] if options[:max_chars]
      request["allowed"] = [options[:allowed].source, options[:allowed].casefold?] if options[:allowed]
      { :mask => "mask", :echo => "echo", :alt_codes => "alt_codes" }.each { |option, key| request[key] = options[option] if options[option] }
      @id = MGQ_Multiplayer::Bridge.call(OPEN, request)
      TextEdit.open = self
      # What is typed from now on reaches the box in this frame already.
      follow(false)
    end

    # Hands a box the events from now on.
    #
    # @param editor [TextEdit] The box opened.
    def self.open=(editor)
      @open = editor
    end

    # Stops handing a box the events once it closed, unless another opened since.
    #
    # @param editor [TextEdit] The box closed.
    def self.release(editor)
      @open = nil if @open.equal?(editor)
    end

    # Hands a box's event to the box open, unless it is of a box closed since.
    #
    # @param event [Hash] The event, see EditModel.EventTopic.
    def self.take_event(event)
      editor = @open
      editor.take_event(event) if editor && editor.id == event["id"]
    end

    # Closes the box in C#, dropping what was typed and not taken.
    def close
      MGQ_Multiplayer::Bridge.call(CLOSE, @id) if @id
      TextEdit.release(self)
    end

    # Reports whether the blinking cursor shows.
    #
    # @return [Boolean] Whether it does.
    def cursor_shown?
      @shown
    end

    # Hands C# the box's input of this frame, where its owner reads the keys: what was typed
    # (taken straight from the keyboard), and the keys that type nothing unless the owner keeps
    # them, such as while Alt picks the chat's tabs.
    #
    # @param keys [Boolean] Whether the arrows, Home, End and Delete reach the box.
    # @param scroll [Integer] Lines to scroll a box of several lines, such as by the mouse wheel.
    def follow(keys = true, scroll = 0)
      return unless @id

      held = @alt_codes && MGQ_Multiplayer::Key.down?(ALT_KEY) ? 1 : 0
      Tick.put(MODEL, [@id, keys ? key_bits : -1, 1, scroll.to_i, held])
    end

    # Takes what typing did since the last take.
    #
    # @return [Taken] What typing did, the keys and characters that came, and whether the box changed.
    def take
      taken = @taken
      @taken = Taken.new([], 0, 0, false)
      taken
    end

    # Replaces the text and puts the cursor at once, as the owner sees it, and in C# with the
    # frame's batch, before what is typed next.
    #
    # @param text [String] The new text.
    # @param cursor [Integer] The cursor's new place.
    def edit(text, cursor)
      @text = text.to_s
      @cursor = [[cursor, 0].max, @text.length].min
      @shown = true
      MGQ_Multiplayer::Bridge.stage(SET, "id" => @id, "text" => @text, "cursor" => @cursor) if @id
    end

    # Locks the box, which then takes no typing but Escape, or unlocks it.
    #
    # @param locked [Boolean] Whether it is locked.
    def lock(locked)
      MGQ_Multiplayer::Bridge.stage(SET, "id" => @id, "locked" => locked) if @id
    end

    # Leaves out the character of a key once more, which arrives a frame or two after the key.
    #
    # @param key [Integer] Windows' code of the key.
    # @param frames [Integer] The frames its character may come in.
    def echo(key, frames)
      MGQ_Multiplayer::Bridge.stage(SET, "id" => @id, "echo" => [key, frames]) if @id
    end

    # Types characters at once, for the game's letters a gamepad picks.
    #
    # @param chars [String] The characters, "\b" for Backspace.
    # @return [Array<Symbol>] What typing did, see Taken; none while the bridge is closed.
    def type_now(chars)
      answer = @id ? MGQ_Multiplayer::Bridge.call(TYPE, "id" => @id, "text" => chars.to_s) : nil
      return [] unless answer

      @text = answer["text"]
      @cursor = answer["cursor"]
      answer["outcomes"].map { |outcome| OUTCOMES[outcome] }.compact
    end

    # Tells what the box shows where it is drawn, telling C# first when that changed.
    #
    # @param bitmap [Bitmap] The picture drawn on, in the font the box draws in.
    # @param width [Integer] The width its text may take.
    # @param rows [Integer] The lines a box of several lines shows, 0 for a box of one line.
    # @return [Hash, nil] {"line" => [first, count, cursor x]} or {"area" => [spans, first line,
    #   cursor's line, cursor x]}; nil while the bridge is closed or the font is measured here.
    def view_for(bitmap, width, rows)
      font = Glyphs.font_key(bitmap)
      drawn = [font, width, rows]
      return @view if drawn == @drawn
      return nil unless @id && font

      state = MGQ_Multiplayer::Bridge.call(VIEW, "id" => @id, "font" => font, "width" => width, "rows" => rows)
      return nil unless state

      apply(state)
      @drawn = drawn
      @view
    end

    # Takes the box's event: the text, the cursor and what the box shows, and what typing did.
    #
    # @param event [Hash] The event, see EditModel.EventTopic.
    def take_event(event)
      apply(event)
      taken = @taken
      Array(event["outcomes"]).each { |outcome| taken.outcomes << OUTCOMES[outcome] if OUTCOMES[outcome] }
      taken.keys += event["keys"].to_i
      taken.chars += event["chars"].to_i
      taken.changed = true
    end

    # Reads the frame's keys that type nothing.
    #
    # @return [Integer] The bits, see ARROW_BITS, AREA_BITS and KEY_BITS.
    def key_bits
      capture = MGQ_Multiplayer::Capture
      keys = MGQ_Multiplayer::Key
      bits = 0
      arrows = @drawn && @drawn[2] > 0 ? AREA_BITS : ARROW_BITS
      arrows.each { |button, bit| bits |= bit if capture.repeat?(button) }
      KEY_BITS.each { |code, bit| bits |= bit if keys.pressed?(code) }
      bits
    end

    private

    # Takes the box's state from C#.
    #
    # @param state [Hash] "text", "cursor", "shown" and "view".
    def apply(state)
      @text = state["text"]
      @cursor = state["cursor"]
      @shown = state["shown"]
      @view = state["view"] if state["view"]
    end
  end

  # Draws a text box being typed into: the part of the text C# picked around the cursor, and the
  # cursor, in the font and the color the picture is set to. Whoever owns the box draws its
  # background, and what it shows while nobody types into it.
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
      view = editor.view_for(bitmap, rect.width - CURSOR_WIDTH, 0)
      line = view && view["line"]
      return bitmap.draw_text(rect.x, rect.y, rect.width, rect.height, display) unless line

      first, count, x = line
      bitmap.draw_text(rect.x, rect.y, rect.width, rect.height, display[first, count].to_s)
      draw_cursor(bitmap, rect.x + x, rect.y + CURSOR_INSET, rect.height - CURSOR_INSET * 2) if editor.cursor_shown?
    end

    # Draws a box of several lines, and a scrollbar right of the text while it has more lines than
    # the box shows; whoever owns the box leaves Style::SCROLLBAR_WIDTH free there.
    #
    # @param bitmap [Bitmap] The picture drawn on.
    # @param rect [Rect] Where the text goes.
    # @param editor [TextEdit] The box's editor.
    # @param line_height [Integer] The height of one line.
    def self.draw_area(bitmap, rect, editor, line_height)
      rows = rect.height / line_height
      view = editor.view_for(bitmap, rect.width, rows)
      area = view && view["area"]
      return bitmap.draw_text(rect.x, rect.y, rect.width, line_height, editor.text) unless area

      spans, top, cursor_line, x = area
      spans[top, rows].each_with_index do |(start, length), row|
        y = rect.y + row * line_height
        bitmap.draw_text(rect.x, y, rect.width, line_height, editor.text[start, length].to_s)
        draw_cursor(bitmap, rect.x + x, y + LINE_CURSOR_INSET, line_height - LINE_CURSOR_INSET * 2) if top + row == cursor_line && editor.cursor_shown?
      end
      Style.draw_scrollbar(bitmap, rect.x + rect.width, rect.y, rows * line_height, top, rows, spans.size)
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

  # Breaks a text into lines that keep every character's place, as wrap_spans does: in C# by the
  # characters' widths (see MGQ_MpUi::Glyphs), else, while the bridge is closed or for a font whose
  # widths do not add up, measuring here.
  #
  # @param measure [Bitmap, Window_Base, nil] What measures a text with the font the lines are drawn
  #   in, nil for a box that counts characters, each one cell wide.
  # @param text [String] The text.
  # @param width [Integer] The width in pixels, or in characters without a measure.
  # @return [Array<Array<Integer>>] Each line's first character and length, one empty line for an empty text.
  def self.spans(measure, text, width)
    text = text.to_s
    spans = Glyphs.ask(Glyphs::SPANS, measure, text) { |key| [key, width, text] }
    return spans if spans.is_a?(Array)

    measure ? wrap_spans(text, width) { |part| measure.text_size(part).width } : wrap_spans(text, width) { |part| part.length }
  end

  # Breaks a text into lines that fit a width without changing a character of it, so a place in
  # the text is a place in a line: each line is a stretch of the text, broken before a word, and
  # inside a word longer than the width, measuring each part with a block.
  #
  # @param text [String] The text.
  # @param width [Integer] The width in pixels.
  # @yieldparam part [String] A word, a run of spaces, or a character of a word longer than the width.
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

      pieces = part =~ /\S/ && part_width > width ? part.each_char.to_a : [part]
      pieces.each do |piece|
        piece_width = pieces.size > 1 ? yield(piece) : part_width

        if pieces.size > 1 && used + piece_width > width && at > start
          spans.push([start, at - start])
          start = at
          used = 0
        end

        used += piece_width
        at += piece.length
      end
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

# What the box being typed into reports, through the bridge.

begin
  MGQ_Multiplayer::Bridge.on(MGQ_MpUi::TextEdit::EVENT) { |event| MGQ_MpUi::TextEdit.take_event(event) }
rescue => e
  MGQ_MpUi.log("text box: registering FAILED: #{e.class}: #{e.message}")
end
