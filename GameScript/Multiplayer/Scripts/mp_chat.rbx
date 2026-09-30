#----------------------------------------------------------------
#  mp_chat.rbx
#
#  Changelog:
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# The chat: a line typed on the keyboard goes to every player of the world, shows in a bubble
# above the sender while they are on the same map, and in the chat log at the bottom left. T or
# the action wheel of mp_actions.rbx opens the chat box. It builds on mp_overworld_sync.rbx, which
# knows the other players and their messages.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpChat
  # Windows' code of the key that opens the chat: T, which neither the game's Input nor its gamepad
  # plugin reads.
  CHAT_KEY = 0x54

  # Characters a chat line may have.
  MAX_LENGTH = 120

  # Chat lines kept for the log.
  KEPT = 50

  # Frames a chat line stays in the log, ten seconds, unless the chat box is open.
  LOG_FRAMES = 600

  # Frames a bubble stays, six seconds.
  BUBBLE_FRAMES = 360

  # Frames the cursor stays shown, then hidden, while it blinks.
  BLINK_FRAMES = 30

  # Windows' codes of the keys that move the cursor to the start or the end, and that remove the
  # character after it. None of them types a character.
  HOME_KEY = 0x24
  END_KEY = 0x23
  DELETE_KEY = 0x2E

  @log = []
  @bubbles = {}
  @typed = nil
  @cursor = 0
  @blink = 0

  # Reports whether the keyboard reaches the game, which only happens once its window is hooked.
  #
  # @return [Boolean] Whether it does.
  def self.available?
    MGQ_Multiplayer::Background.running?
  end

  # Reports whether the chat box is open.
  #
  # @return [Boolean] Whether it is.
  def self.typing?
    !@typed.nil?
  end

  # The text in the chat box.
  #
  # @return [String, nil] The text, nil while the box is closed.
  def self.typed
    @typed
  end

  # Where the cursor stands in the chat box's text.
  #
  # @return [Integer] The characters before it.
  def self.cursor
    @cursor
  end

  # Reports whether the blinking cursor shows this frame.
  #
  # @return [Boolean] Whether it does.
  def self.cursor_shown?
    (@blink / BLINK_FRAMES).even?
  end

  # Opens the chat box, which holds the buttons, so keys that type move nobody.
  def self.start_typing
    @typed = ""
    @cursor = 0
    @blink = 0
    MGQ_Multiplayer::Link.typing(true)
    MGQ_Multiplayer::Capture.start(:chat)
  end

  # Closes the chat box, if it is open, and gives the buttons back.
  def self.stop_typing
    return unless typing?

    @typed = nil
    MGQ_Multiplayer::Link.typing(false)
    MGQ_Multiplayer::Capture.stop(:chat)
  end

  # Types what came from the keyboard since the last frame, then moves the cursor with the arrow
  # keys, Home and End, and removes the character after it with Delete. The cursor blinks, and
  # shows at once after anything moved it.
  def self.update_typing
    @blink += 1
    text, _keys = MGQ_Multiplayer::Link.take_typed
    text.each_char do |char|
      type(char)
      return unless typing?
    end

    keys = MGQ_Multiplayer::Key
    move_to(@cursor - 1) if MGQ_Multiplayer::Capture.repeat?(:LEFT)
    move_to(@cursor + 1) if MGQ_Multiplayer::Capture.repeat?(:RIGHT)
    move_to(0) if keys.pressed?(HOME_KEY)
    move_to(@typed.length) if keys.pressed?(END_KEY)
    edit(@typed[0, @cursor] + @typed[@cursor + 1..-1].to_s, @cursor) if keys.pressed?(DELETE_KEY) && @cursor < @typed.length
  end

  # Types one character at the cursor: Enter sends, Escape closes, Backspace removes the character
  # before the cursor.
  #
  # @param char [String] The character.
  def self.type(char)
    case char
    when "\r"
      send_typed
    when "\e"
      stop_typing
      Sound.play_cancel
    when "\b"
      edit(@typed[0, @cursor - 1] + @typed[@cursor..-1], @cursor - 1) if @cursor > 0
    else
      return if char =~ /[[:cntrl:]]/
      return Sound.play_buzzer if @typed.length >= MAX_LENGTH

      edit(@typed[0, @cursor] + char + @typed[@cursor..-1], @cursor + 1)
    end
  end

  # Changes the chat box's text and puts the cursor where it goes.
  #
  # The text is always a new string, never changed in place, so the chat box sees it changed.
  #
  # @param text [String] The new text.
  # @param cursor [Integer] The cursor's new place.
  def self.edit(text, cursor)
    @typed = text
    move_to(cursor)
  end

  # Moves the cursor, within the text, and shows it at once.
  #
  # @param cursor [Integer] The place.
  def self.move_to(cursor)
    @cursor = [[cursor, 0].max, @typed.length].min
    @blink = 0
  end

  # Sends the chat box's text, closing the box; an empty box just closes.
  def self.send_typed
    text = @typed.strip
    stop_typing
    return if text.empty?

    if MGQ_MpChat.tell("chat" => text, "name" => MGQ_Multiplayer::Player.name.to_s)
      add(:me, MGQ_Multiplayer::Player.name.to_s, text)
    else
      Sound.play_buzzer
      MGQ_MpChat.notice("The message could not be sent.")
    end
  end

  # Takes another player's chat line.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it, nil before their first state.
  # @param message [Hash] The message, the line under "chat".
  def self.receive(peer, message)
    text = message["chat"].to_s.gsub(/[[:cntrl:]]/, "").strip[0, MAX_LENGTH]
    return if text.empty?

    add(peer ? peer.seat : nil, peer ? peer.state["name"] : message["name"], text)
  end

  # Adds a chat line to the log, and to the sender's bubble.
  #
  # @param sender [Integer, Symbol, nil] The sender's seat, :me for the player, nil for no bubble.
  # @param name [String] The sender's name.
  # @param text [String] The line.
  def self.add(sender, name, text)
    @log.push(["#{name}: #{text}", LOG_FRAMES])
    @log.shift while @log.size > KEPT
    @bubbles[sender] = [text, BUBBLE_FRAMES] unless sender.nil?
  end

  # Lets log lines and bubbles run out. Called every frame.
  def self.count_down
    @log.each { |entry| entry[1] -= 1 if entry[1] > 0 }
    @bubbles.each_value { |bubble| bubble[1] -= 1 }
    @bubbles.reject! { |_, bubble| bubble[1] <= 0 }
  end

  # Forgets the log and the bubbles and closes the box, as when the world closes.
  def self.reset
    stop_typing
    @log.clear
    @bubbles.clear
  end

  # Lists the log's lines to show: all kept while the chat box is open, else the recent ones.
  #
  # @return [Array<String>] The lines, oldest first.
  def self.log_lines
    @log.select { |_, left| typing? || left > 0 }.map { |line, _| line }
  end

  # Tells what a sender's bubble says.
  #
  # @param sender [Integer, Symbol] The sender's seat, :me for the player.
  # @return [String, nil] The line, nil for no bubble.
  def self.bubble(sender)
    @bubbles[sender] && @bubbles[sender][0]
  end

  # Lists who has a bubble now.
  #
  # @return [Array<Integer, Symbol>] Their seats, :me for the player.
  def self.senders
    @bubbles.keys
  end

  # Breaks a text into lines that fit a width.
  #
  # @param bitmap [Bitmap] A bitmap with the font the lines are drawn in.
  # @param text [String] The text.
  # @param width [Integer] The width in pixels.
  # @return [Array<String>] The lines.
  def self.wrap(bitmap, text, width)
    lines = [""]
    text.split(" ").each do |word|
      candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
      if bitmap.text_size(candidate).width <= width
        lines[-1] = candidate
        next
      end

      lines.push("") unless lines.last.empty?
      word.each_char do |char|
        lines.push("") if bitmap.text_size(lines.last + char).width > width && !lines.last.empty?
        lines[-1] += char
      end
    end
    lines
  end

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Spriteset_Map.method_defined?(:mgq_mp_chat_update)
  end

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("chat: #{message}")
  rescue
  end

  # Reports whether a world is open, through mp_overworld_sync.rbx.
  #
  # @return [Boolean] Whether it is.
  def self.in_world?
    MGQ_MpOverworldSync.in_world?
  end

  # Tells every other game of the world something, through mp_overworld_sync.rbx.
  #
  # @param fields [Hash] The message's fields, which must leave out "map", since that marks a state.
  # @return [Boolean] Whether it went out.
  def self.tell(fields)
    MGQ_MpOverworldSync::Link.send_to(-1, MGQ_MpOverworldSync::Me.encode(fields))
  end

  # Shows a notice at the bottom left of the map, through mp_overworld_sync.rbx.
  #
  # @param text [String] The notice.
  def self.notice(text)
    MGQ_MpOverworldSync::Status.notice(text)
  end

  # Lets bubbles and chat lines run out, closes the chat box once the map is left, and forgets the
  # chat once no world is open. Called by mp_overworld_sync.rbx every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    stop_typing unless in_world && SceneManager.scene.is_a?(Scene_Map)
    in_world ? count_down : reset
  end

  # Tells what the player does while the chat box is open. Called by mp_overworld_sync.rbx.
  #
  # @return [String, nil] "typing" while the chat box is open, else nil.
  def self.scene
    typing? ? "typing" : nil
  end

  # Opens the chat box with T, and types into it while it is open. Called by the map every frame,
  # so a press of the key is seen once.
  def self.on_map
    chat_key = MGQ_Multiplayer::Key.pressed?(CHAT_KEY)
    unless in_world? && !$game_map.interpreter.running? && !$game_message.busy?
      stop_typing
      return
    end

    if typing?
      update_typing
    elsif chat_key && available? && !MGQ_MpActions::Wheel.open?
      Sound.play_ok
      start_typing
    end
  rescue => e
    log("chat failed: #{e.class}: #{e.message}")
    stop_typing
  end
end

# A chat bubble above a player's head: their last chat line, cut after three lines.
class Sprite_MpChatBubble < Sprite
  # Widest the bubble gets.
  WIDTH = 240

  # Height of one line.
  LINE = 20

  # Lines the bubble shows at most.
  MAX_LINES = 3

  # Room between the text and the bubble's edge.
  PAD = 6

  # Pixels above a ghost's feet that its bubble points at: over its name and the line above it.
  GHOST_LIFT = 92

  # Pixels above the player's feet that their bubble points at: over their ping and the line above it.
  OWN_LIFT = 88

  # Height of the tail below the bubble.
  TAIL = 5

  # The bubble's fill.
  FILL = Color.new(255, 255, 255, 230)

  # The bubble's edge.
  EDGE = Color.new(40, 40, 40, 230)

  # The text's color.
  INK = Color.new(20, 20, 20)

  # Creates the bubble, hidden.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, LINE * MAX_LINES + PAD * 2 + TAIL)
    self.ox = WIDTH / 2
    self.oy = bitmap.height
    self.z = 260
    self.visible = false
    @shown = nil
  end

  # Draws the bubble, if its line changed, with its tail at a point above a character.
  #
  # @param text [String, nil] The line, nil to hide the bubble.
  # @param x [Integer] Where the tail points, across the screen.
  # @param y [Integer] Where the tail points, down the screen.
  def show(text, x, y)
    self.visible = !text.nil?
    return unless visible

    self.x = x
    self.y = y
    return if text == @shown

    @shown = text
    draw(text)
  end

  # Draws the bubble around a line, bottom-aligned so the tail stays put.
  #
  # @param text [String] The line.
  def draw(text)
    bitmap.clear
    bitmap.font.size = 16
    bitmap.font.outline = false
    bitmap.font.color = INK
    lines = MGQ_MpChat.wrap(bitmap, text, WIDTH - PAD * 2)
    lines = lines[0, MAX_LINES - 1] + ["#{lines[MAX_LINES - 1]} . . ."] if lines.size > MAX_LINES
    width = [lines.map { |line| bitmap.text_size(line).width }.max + PAD * 2, 24].max
    width = [width, WIDTH].min
    height = lines.size * LINE + PAD * 2
    left = (WIDTH - width) / 2
    top = bitmap.height - TAIL - height

    bitmap.fill_rect(left, top, width, height, EDGE)
    bitmap.fill_rect(left + 1, top + 1, width - 2, height - 2, FILL)
    TAIL.times { |row| bitmap.fill_rect(WIDTH / 2 - (TAIL - row), top + height - 1 + row, (TAIL - row) * 2, 1, row == 0 ? FILL : EDGE) }
    lines.each_with_index { |line, row| bitmap.draw_text(left + PAD, top + PAD + row * LINE, width - PAD * 2, LINE, line, 1) }
  end

  # Frees the bubble's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The chat log at the bottom left, above the world's status line, with the chat box below it while
# the player types.
class Sprite_MpChatLog < Sprite
  # Width of the log.
  WIDTH = 400

  # Height of one row.
  ROW = 22

  # Rows of chat lines.
  ROWS = 6

  # Room the world's status line keeps at the bottom of the screen.
  STATUS_ROOM = 96

  # Background while the chat box is open.
  BACK = Color.new(0, 0, 0, 120)

  # Color of the chat box's hint.
  HINT = Color.new(180, 180, 180)

  # Background of the chat box's row, over the log's.
  BOX_BACK = Color.new(0, 0, 0, 110)

  # Room left of the chat box's text.
  TEXT_LEFT = 4

  # Width of the chat box's cursor.
  CURSOR_WIDTH = 2

  # Creates the log, empty.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, ROW * (ROWS + 1))
    self.x = 8
    self.y = Graphics.height - STATUS_ROOM - bitmap.height
    self.z = 200
    @shown = nil
  end

  # Draws the log and the chat box, if they changed.
  def update
    super
    chat = MGQ_MpChat
    lines = MGQ_MpChat.in_world? ? chat.log_lines.last(ROWS) : []
    drawn = [lines, chat.typed, chat.cursor, chat.typing? && chat.cursor_shown?]
    return if drawn == @shown

    @shown = drawn
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    bitmap.fill_rect(bitmap.rect, BACK) if chat.typing?
    rows = lines.map { |line| chat.wrap(bitmap, line, WIDTH - 8) }.flatten.last(ROWS)
    rows.each_with_index { |row, index| bitmap.draw_text(4, (ROWS - rows.size + index) * ROW, WIDTH - 8, ROW, row) }
    draw_box(chat.typed, chat.cursor, chat.cursor_shown?) if chat.typing?
  end

  # Draws the chat box on the bottom row: the text, moved left as far as the cursor needs to stay
  # in sight, and the cursor; or a hint while the text is empty.
  #
  # @param text [String] The text typed.
  # @param cursor [Integer] The characters before the cursor.
  # @param cursor_shown [Boolean] Whether the blinking cursor shows.
  def draw_box(text, cursor, cursor_shown)
    y = ROWS * ROW
    bitmap.fill_rect(0, y, WIDTH, ROW, BOX_BACK)

    if text.empty?
      bitmap.font.color = HINT
      bitmap.draw_text(TEXT_LEFT + CURSOR_WIDTH + 2, y, WIDTH - TEXT_LEFT * 2, ROW, "Type a message. Enter sends, Esc closes.")
      bitmap.font.color = Color.new(255, 255, 255)
    end

    before = bitmap.text_size(text[0, cursor]).width
    left = TEXT_LEFT - [before - (WIDTH - TEXT_LEFT * 2 - CURSOR_WIDTH), 0].max
    # Drawn as wide as the text is, since draw_text squeezes a text into a narrower rectangle.
    bitmap.draw_text(left, y, bitmap.text_size(text).width + 8, ROW, text) unless text.empty?
    bitmap.fill_rect(left + before, y + 3, CURSOR_WIDTH, ROW - 6, Color.new(255, 255, 255)) if cursor_shown
  end

  # Frees the log's picture.
  def dispose
    bitmap.dispose
    super
  end
end


# What this script takes part in of the world's messages, through mp_overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route("chat") { |peer, message| MGQ_MpChat.receive(peer, message) }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpChat.tick(in_world) }
  MGQ_MpOverworldSync.busy_scene { MGQ_MpChat.scene }
rescue => e
  MGQ_MpChat.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks.
#
# Each wraps a game method: the original runs first, and the mod's part never raises.

if MGQ_MpChat.hookable?
  begin
    class Scene_Map
      alias mgq_mp_chat_update_scene update_scene

      # Updates the map, then the chat box.
      #
      # The game checks its own keys here too, only while no scene change is in the way.
      def update_scene
        mgq_mp_chat_update_scene
        MGQ_MpChat.on_map unless scene_changing?
      end
    end
  rescue => e
    MGQ_MpChat.log("map key hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Spriteset_Map
      alias mgq_mp_chat_update update
      alias mgq_mp_chat_dispose dispose

      # Updates the map's sprites, then the chat log and the chat bubbles.
      def update
        mgq_mp_chat_update
        mgq_mp_chat_update_sprites
      end

      # Keeps the chat log and a bubble per player with a recent chat line.
      def mgq_mp_chat_update_sprites
        @mgq_mp_chat_log ||= Sprite_MpChatLog.new(@viewport3)
        @mgq_mp_chat_log.update
        mgq_mp_chat_update_bubbles
      rescue => e
        MGQ_MpChat.log("chat sprites failed: #{e.class}: #{e.message}") unless @mgq_mp_chat_failed
        @mgq_mp_chat_failed = true
      end

      # Keeps a bubble per player with a recent chat line, above them while they are on this map.
      def mgq_mp_chat_update_bubbles
        @mgq_mp_bubbles ||= {}
        chat = MGQ_MpChat
        senders = MGQ_MpChat.in_world? ? chat.senders : []
        (@mgq_mp_bubbles.keys - senders).each { |sender| @mgq_mp_bubbles.delete(sender).dispose }

        senders.each do |sender|
          bubble = @mgq_mp_bubbles[sender] ||= Sprite_MpChatBubble.new(@viewport1)
          if sender == :me
            character, lift = $game_player, Sprite_MpChatBubble::OWN_LIFT
            character = nil if MGQ_MpActions::Wheel.open?
          else
            peer = MGQ_MpOverworldSync::Peers.at(sender)
            character, lift = peer && peer.ghost, Sprite_MpChatBubble::GHOST_LIFT
          end

          shown = character && !character.transparent
          bubble.show(shown ? chat.bubble(sender) : nil, shown ? character.screen_x : 0, shown ? character.screen_y - lift : 0)
        end
      end


      # Frees the chat log and the bubbles, then the map's sprites.
      def dispose
        @mgq_mp_chat_log.dispose if @mgq_mp_chat_log
        (@mgq_mp_bubbles || {}).each_value { |sprite| sprite.dispose }
        @mgq_mp_chat_log = @mgq_mp_bubbles = nil
        mgq_mp_chat_dispose
      end
    end
  rescue => e
    MGQ_MpChat.log("sprite hooks FAILED: #{e.class}: #{e.message}")
  end
end
