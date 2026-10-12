#----------------------------------------------------------------
#  world_text.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Scrolled a text longer than its box, showing its end and the cursor with a dim "..." before it, instead of drawing it past the window
#                            - Scrolled the description with the mouse wheel and drew its scrollbar
#                            - Broke the description over four lines at words in a taller box, showing its last lines
#                            - Drew the box once per frame and played one sound for what was typed in it, so a pasted text no longer stalls the game
#      Paulinchen  2026-10-07: Logged the text screen opening, showing its letters for a gamepad, and how it was left, never the text
#      Paulinchen  2026-10-04: Renamed from mp_world_text.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The text screen of the world screen: where the player types into a form's text box with the
# game's letters on a gamepad, or when the keyboard cannot reach the game. It hands what was typed
# to MGQ_MpWorld.text_result, which world_screen.rbx takes.

# The text screen, for a form's text boxes once a gamepad is used: the typed text in a box, with its
# purpose where a character's face would be. The keyboard types into it; the game's own letters
# appear below once a gamepad is used, or from the start when the keyboard cannot reach the game.
class Scene_MpText < Scene_MenuBase
  # Sets what the text is for and how it looks.
  #
  # @param kind [Symbol, Array] What the text is for, handed back with it.
  # @param caption [String] What the screen says it is for.
  # @param default [String] The text it starts with.
  # @param options [Hash] :max_chars, how long the text may be; and whichever of :masked (shown as
  #   stars), :allowed (the characters it takes), :letters (the letters shown at once) and :area
  #   (broken over several lines) apply.
  def prepare(kind, caption, default, options)
    @kind = kind
    @caption = caption
    @default = default
    @options = options
  end

  # Creates the windows and starts taking what is typed, the letters hidden while the keyboard
  # works, unless they were asked for.
  def start
    super
    @edit_window = Window_MpTextEdit.new(@caption, @default, @options)
    @input_window = Window_MpTextInput.new(@edit_window)
    @input_window.set_handler(:ok, method(:on_input_ok))
    @input_window.set_handler(:cancel, method(:on_input_cancel))
    MGQ_Multiplayer::Link.typing(true)
    MGQ_Multiplayer::Background.running? && !@options[:letters] ? hide_letters : show_letters
    MGQ_MpWorld.log("text screen opened for #{@caption}, #{@input_window.visible ? 'with the letters for a gamepad' : 'typed on the keyboard'}")
  end

  # Types what came from the keyboard and scrolls the box with the mouse wheel, then lets the
  # letters take a gamepad's buttons, showing them once a button is pressed that did not come from
  # the keyboard.
  #
  # A key that types also moves the game's own buttons, such as Z for OK, so the letters ignore
  # the buttons in a frame the keyboard was used.
  def update
    text, keys = MGQ_Multiplayer::Link.take_typed
    keyboard = keys > 0 || !text.empty?
    @input_window.keyboard_used = keyboard

    if !keyboard && !@input_window.visible && MGQ_MpWorld.gamepad_pressed?
      show_letters
      MGQ_MpWorld.log("text screen: a gamepad button showed the letters")
      # The press that showed the letters picks nothing.
      @input_window.keyboard_used = true
    end

    type_text(text)
    @edit_window.scroll_by_wheel unless scene_changing?
    super
  end

  # Types a frame's characters, drawing the box once and playing one sound for all of them, so a
  # pasted text costs one drawing instead of one per character.
  #
  # @param text [String] The characters typed this frame.
  def type_text(text)
    sounds = []
    @edit_window.hold_refresh do
      text.each_char do |char|
        sounds << type(char)
        break if scene_changing?
      end
    end
    play(sounds.include?(:buzzer) ? :buzzer : sounds.compact.last)
  end

  # Hides the letters and puts the box in the middle of the screen.
  def hide_letters
    @input_window.hide
    @input_window.deactivate
    @edit_window.hint = "Type on the keyboard. Enter confirms, Esc goes back."
    @edit_window.y = (Graphics.height - @edit_window.height) / 2
  end

  # Shows the letters below the box, for a gamepad.
  def show_letters
    @edit_window.hint = nil
    @edit_window.y = @input_window.y - @edit_window.height - 8
    @input_window.show
    @input_window.activate
  end

  # Types one character: Enter confirms, Escape leaves, Backspace removes the last one.
  #
  # @param char [String] The character.
  # @return [Symbol, nil] The sound it calls for: :cursor, :cancel or :buzzer, nil for none.
  def type(char)
    case char
    when "\r"
      return :buzzer if @edit_window.name.empty?

      on_input_ok
      nil
    when "\e"
      on_input_cancel
      nil
    when "\b"
      @edit_window.back ? :cancel : nil
    else
      return nil if char =~ /[[:cntrl:]]/

      @edit_window.add(char) ? :cursor : :buzzer
    end
  end

  # Plays a sound typing called for.
  #
  # @param sound [Symbol, nil] :cursor, :cancel or :buzzer, nil for none.
  def play(sound)
    case sound
    when :cursor then Sound.play_cursor
    when :cancel then Sound.play_cancel
    when :buzzer then Sound.play_buzzer
    end
  end

  # Stops taking what is typed.
  def terminate
    MGQ_Multiplayer::Link.typing(false)
    super
  end

  # Hands the text back.
  def on_input_ok
    MGQ_MpWorld.log("text screen confirmed for #{@caption} (#{@edit_window.name.size} characters)")
    MGQ_MpWorld.text_result = [@kind, @edit_window.name]
    return_scene
  end

  # Leaves without a text.
  def on_input_cancel
    MGQ_MpWorld.log("text screen left without a text for #{@caption}")
    MGQ_MpWorld.text_result = [@kind, nil]
    return_scene
  end
end

# The text being typed, with its purpose where the game shows a character's face, as stars for a
# password, taking only the characters it allows. A text longer than the box scrolls, showing its
# end and the cursor with a dim "..." before it; a box of several lines, such as the description,
# breaks the text at words and shows its last lines, which the mouse wheel scrolls back.
class Window_MpTextEdit < Window_NameEdit
  # Stands in for the character whose name Window_NameEdit expects.
  Holder = Struct.new(:name)

  # Lines of text a box of several lines shows.
  AREA_ROWS = 4

  # Lines of the window besides the text's: the caption, the room below it and the hint.
  FRAME_LINES = 3

  # What shows before the text while its start is out of sight.
  MORE = "..."

  # Top of the text's first line, where the game draws a name.
  TEXT_TOP = 36

  # Lines of a box of several lines one notch of the mouse wheel scrolls.
  WHEEL_LINES = 1

  # Creates the window, taller for a box of several lines, which keeps it in the middle of the
  # screen with the game's letters below it.
  #
  # @param caption [String] What the text is for.
  # @param text [String] The text it starts with.
  # @param options [Hash] See Scene_MpText#prepare.
  def initialize(caption, text, options)
    @caption = caption
    @masked = options[:masked]
    @allowed = options[:allowed]
    @rows = options[:area] ? AREA_ROWS : 1
    @scrolled_up = 0
    super(Holder.new(text.to_s), options[:max_chars])
    return unless area?

    grown = fitting_height(@rows + FRAME_LINES) - height
    self.height += grown
    self.y -= grown / 2
    create_contents
    refresh
  end

  # Holds the drawing while a block types, then draws once if anything changed.
  #
  # @yield Types into the box.
  def hold_refresh
    @held = true
    yield
  ensure
    @held = false
    refresh if @stale
  end

  # Draws the caption, the underlines, the characters in sight and the cursor while its line is in
  # sight, or only notes that it has to while the drawing is held. A changed text shows the
  # cursor's line again.
  def refresh
    return @stale = true if @held

    @stale = false
    @scrolled_up = 0 unless @name == @scrolled_text
    @scrolled_text = @name
    contents.clear
    draw_actor_face(@actor, 0, 0)
    area? ? draw_area : draw_line
    row = cell_of(@index)[0]
    row >= 0 && row < @rows ? cursor_rect.set(item_rect(@index)) : cursor_rect.empty
  end

  # Scrolls a box of several lines by the mouse wheel's notches while the mouse points at the
  # window, from the lines that keep the cursor's line the last up to the first line.
  #
  # @return [Boolean] Whether it scrolled.
  def scroll_by_wheel
    return false unless area?

    notches = MGQ_Multiplayer::Mouse.wheel
    return false if notches == 0 || !pointed_at?

    scrolled = [[@scrolled_up + notches * WHEEL_LINES, 0].max, following_top].min
    return false if scrolled == @scrolled_up

    @scrolled_up = scrolled
    refresh
    true
  end

  # Tells whether the mouse points at the window.
  #
  # @return [Boolean] Whether it does.
  def pointed_at?
    position = MGQ_Multiplayer::Mouse.position
    position ? position[0] >= x && position[0] < x + width && position[1] >= y && position[1] < y + height : false
  end

  # Tells whether the text breaks over several lines.
  #
  # @return [Boolean] Whether it does.
  def area?
    @rows > 1
  end

  # The width of a character's cell, never 0.
  #
  # The box keeps one font, so the width is measured once instead of for every cell drawn.
  #
  # @return [Integer] The width.
  def cell_width
    @cell_width ||= [char_width, 1].max
  end

  # The characters' places a box of one line underlines: its most characters, or as many as fit
  # with a cell left for the cursor.
  #
  # @return [Integer] The places.
  def shown
    [[@max_char, contents_width / cell_width - 1].min, 1].max
  end

  # Tells whether the start of the text in a box of one line is out of sight.
  #
  # @return [Boolean] Whether it is.
  def scrolled?
    !area? && @index > shown
  end

  # The first character a box of one line shows.
  #
  # @return [Integer] Its place in the text.
  def first_shown
    scrolled? ? @index - shown + 1 : 0
  end

  # The characters a line of a box of several lines takes, past the cell for MORE at its left and
  # the cursor's cell at its right.
  #
  # @return [Integer] The characters.
  def line_chars
    [contents_width / cell_width - 2, 1].max
  end

  # The text broken into the lines of a box of several lines, at words, and inside a word or a run
  # of spaces longer than a line.
  #
  # @return [Array<Array<Integer>>] Each line's first character and length, see MGQ_MpUi.wrap_spans.
  def lines
    return @lines if @lines && @lines_text == @name

    width = line_chars
    spans = MGQ_MpUi.wrap_spans(@name, width) { |part| part.length }
    @lines_text = @name
    @lines = spans.map do |start, length|
      (0...[length, 1].max).step(width).map { |offset| [start + offset, [length - offset, width].min] }
    end.flatten(1)
  end

  # The first line a box of several lines shows: as late as keeps the cursor's line the last, less
  # the lines the wheel scrolled up.
  #
  # @return [Integer] The line.
  def top_line
    [following_top - @scrolled_up, 0].max
  end

  # The first line that keeps the cursor's line the last of a box of several lines.
  #
  # @return [Integer] The line.
  def following_top
    [MGQ_MpUi.span_of(lines, @index) - @rows + 1, 0].max
  end

  # Finds the line and the cell a character's place takes: in a box of one line its cell past the
  # start out of sight and MORE, in a box of several lines its cell in its line past MORE.
  #
  # @param index [Integer] The place in the text.
  # @return [Array<Integer>] The line, counted from the first shown, and the cell.
  def cell_of(index)
    return [0, index - first_shown + (scrolled? ? 1 : 0)] unless area?

    line = MGQ_MpUi.span_of(lines, index)
    [line - top_line, index - lines[line][0] + 1]
  end

  # Finds the rectangle of a cell.
  #
  # @param row [Integer] The line, counted from the first shown.
  # @param cell [Integer] The cell in the line.
  # @return [Rect] The rectangle.
  def cell_rect(row, cell)
    Rect.new(left + cell * cell_width, TEXT_TOP + row * line_height, cell_width, line_height)
  end

  # Puts the text and the cursor where the game puts a name of as many characters as the box
  # shows, so a short text sits where the game puts it.
  #
  # @return [Integer] The left edge of the first cell.
  def left
    width = ((area? ? line_chars + 1 : shown) + 1) * cell_width
    [(contents_width + face_width) / 2 - width / 2, contents_width - width].min
  end

  # Finds the rectangle a character's place is drawn in.
  #
  # @param index [Integer] The place in the text.
  # @return [Rect] The rectangle.
  def item_rect(index)
    cell_rect(*cell_of(index))
  end

  # Finds the underline of a character's place.
  #
  # @param index [Integer] The place in the text.
  # @return [Rect] The rectangle.
  def underline_rect(index)
    underline_of(item_rect(index))
  end

  # Turns a cell's rectangle into its underline, as the game draws one.
  #
  # @param rect [Rect] The cell's rectangle.
  # @return [Rect] The underline.
  def underline_of(rect)
    rect.x += 1
    rect.y += rect.height - 4
    rect.width -= 2
    rect.height = 2
    rect
  end

  # Draws a box of one line: MORE while its start is out of sight, then the places in sight
  # underlined and the characters in them.
  def draw_line
    first = first_shown
    draw_more if scrolled?
    (first...first + shown - (scrolled? ? 1 : 0)).each { |index| draw_underline(index) }
    (first...@name.size).each { |index| draw_char(index) }
  end

  # Draws a box of several lines: MORE while lines above are out of sight, then every line it
  # shows underlined and the characters of the text's lines in them, and a scrollbar at the right
  # while the text has more lines than the box.
  def draw_area
    top = top_line
    draw_more if top > 0
    @rows.times do |row|
      (1..line_chars).each { |cell| contents.fill_rect(underline_of(cell_rect(row, cell)), underline_color) }
    end
    lines[top, @rows].each do |start, length|
      (start...start + length).each { |index| draw_char(index) }
    end
    style = MGQ_MpUi::Style
    style.draw_scrollbar(contents, contents_width - style::SCROLLBAR_WIDTH, TEXT_TOP, @rows * line_height, top, @rows, lines.size)
  end

  # Draws MORE, dim, in the first cell of the first line.
  def draw_more
    change_color(normal_color, false)
    draw_text(cell_rect(0, 0), MORE, 1)
    change_color(normal_color)
  end

  # Adds a character, if the text takes it and has room.
  #
  # @param char [String] The character.
  # @return [Boolean] Whether it was added.
  def add(char)
    return false if @allowed && char !~ @allowed

    super
  end

  # Leaves no room for a face, so the text sits in the middle.
  #
  # @return [Integer] 0.
  def face_width
    0
  end

  # Shows a hint below the text, or none.
  #
  # @param hint [String, nil] The hint.
  def hint=(hint)
    @hint = hint
    refresh
  end

  # Draws the caption where the game draws a character's face, and the hint at the bottom.
  def draw_actor_face(*)
    draw_text(0, 0, contents_width, line_height, @caption, 1)
    return unless @hint

    change_color(normal_color, false)
    draw_text(0, contents_height - line_height, contents_width, line_height, @hint, 1)
    change_color(normal_color)
  end

  # Draws one character, as a star for a password.
  #
  # @param index [Integer] Its place.
  def draw_char(index)
    return super unless @masked

    rect = item_rect(index)
    rect.x -= 1
    rect.width += 4
    change_color(normal_color)
    draw_text(rect, "*")
  end
end

# The game's letters, for gamepads: they leave the text screen when Cancel is pressed with nothing
# typed, and ignore the buttons in a frame the keyboard was used.
class Window_MpTextInput < Window_NameInput
  # Whether the keyboard was used this frame.
  attr_accessor :keyboard_used

  # Moves the cursor, unless the keyboard was used this frame.
  def process_cursor_move
    super unless @keyboard_used
  end

  # Takes the buttons, unless the keyboard was used this frame.
  def process_handling
    super unless @keyboard_used
  end

  # Removes the last letter, or leaves when there is none.
  def process_back
    return super unless @edit_window.name.empty? && Input.trigger?(:B)

    Sound.play_cancel
    call_handler(:cancel)
  end
end
