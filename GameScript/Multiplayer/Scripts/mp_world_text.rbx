#----------------------------------------------------------------
#  mp_world_text.rbx
#
#  Changelog:
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The text screen of the world screen: where the player types a name or a password, with the
# keyboard, or with the game's letters on a gamepad. It builds on mp_world.rbx, which takes what
# was typed.

# The text screen, for names and passwords, and for a form's text boxes once a gamepad is used: the
# typed text in a box, with its purpose where a character's face would be. The keyboard types into
# it; the game's own letters appear below once a gamepad is used, or from the start when the
# keyboard cannot reach the game.
class Scene_MpText < Scene_MenuBase
  # Sets what the text is for and how it looks.
  #
  # @param kind [Symbol, Array] What the text is for, handed back with it.
  # @param caption [String] What the screen says it is for.
  # @param default [String] The text it starts with.
  # @param options [Hash] :max_chars, how long the text may be; and whichever of :masked (shown as
  #   stars), :allowed (the characters it takes) and :letters (the letters shown at once) apply.
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
  end

  # Types what came from the keyboard, then lets the letters take a gamepad's buttons, showing
  # them once a button is pressed that did not come from the keyboard.
  #
  # A key that types also moves the game's own buttons, such as Z for OK, so the letters ignore
  # the buttons in a frame the keyboard was used.
  def update
    text, keys = MGQ_Multiplayer::Link.take_typed
    keyboard = keys > 0 || !text.empty?
    @input_window.keyboard_used = keyboard

    if !keyboard && !@input_window.visible && MGQ_MpWorld.gamepad_pressed?
      show_letters
      # The press that showed the letters picks nothing.
      @input_window.keyboard_used = true
    end

    text.each_char do |char|
      type(char)
      break if scene_changing?
    end
    super
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
  def type(char)
    case char
    when "\r"
      @edit_window.name.empty? ? Sound.play_buzzer : on_input_ok
    when "\e"
      on_input_cancel
    when "\b"
      Sound.play_cancel if @edit_window.back
    else
      return if char =~ /[[:cntrl:]]/

      @edit_window.add(char) ? Sound.play_cursor : Sound.play_buzzer
    end
  end

  # Stops taking what is typed.
  def terminate
    MGQ_Multiplayer::Link.typing(false)
    super
  end

  # Hands the text back.
  def on_input_ok
    MGQ_MpWorld.text_result = [@kind, @edit_window.name]
    return_scene
  end

  # Leaves without a text.
  def on_input_cancel
    MGQ_MpWorld.text_result = [@kind, nil]
    return_scene
  end
end

# The text being typed, with its purpose where the game shows a character's face, as stars for a
# password, taking only the characters it allows.
class Window_MpTextEdit < Window_NameEdit
  # Stands in for the character whose name Window_NameEdit expects.
  Holder = Struct.new(:name)

  # Creates the window.
  #
  # @param caption [String] What the text is for.
  # @param text [String] The text it starts with.
  # @param options [Hash] See Scene_MpText#prepare.
  def initialize(caption, text, options)
    @caption = caption
    @masked = options[:masked]
    @allowed = options[:allowed]
    super(Holder.new(text.to_s), options[:max_chars])
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
