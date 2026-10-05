#----------------------------------------------------------------
#  ui_chat.rbx
#
#  Changelog:
#      Paulinchen  2026-10-05: Took the typing of an open chat box while the map shows a message, which left both stuck
#      Paulinchen  2026-10-04: Named the party tag by its module inside the log line, as Ruby 1.9 finds it
#                            - Sent a line typed with /p to the party only, and colored the senders' names: own yellow, the party's green, others white
#                            - Opened the chat box while the player waits for the party's story, and kept an open box once an event starts
#                            - Left out the character of the key that opened the chat box, which arrived after it opened
#                            - Removed BLINK_FRAMES, which MGQ_MpUi::TextEdit holds
#                            - Renamed from mp_chat.rbx
#                            - Drew the chat box through MGQ_MpUi::TextBox, which every text box shares
#                            - Typed through MGQ_MpUi::TextEdit, which every text box shares
#      Paulinchen  2026-10-03: Broke lines through MGQ_MpUi.wrap, which the windows share
#                            - Filled the wheel's chat choice and told the wheel while the chat box is open
#                            - Asked MGQ_MpOverworldSync whether the map is quiet or the player free on it
#                            - Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Read the bound keys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#      Paulinchen  2026-10-02: Opened the chat box with the key the player bound
#                            - Followed the map and its sprites through core_hooks.rbx
#      Paulinchen  2026-10-01: Let the chat box and the chat log work in battles, above the battle's windows
#                            - Showed the game's own lines in the chat log, such as a player leaving a battle
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# The chat: a line typed on the keyboard goes to every player of the world, shows in a bubble
# above the sender while they are on the same map, and in the chat log at the bottom left. Its key
# (T unless the player binds another, see core_hotkeys.rbx) or the action wheel of ui_actions.rbx opens
# the chat box. It builds on overworld_sync.rbx, which knows the other players and their messages.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpChat
  # Characters a chat line may have.
  MAX_LENGTH = 120

  # Chat lines kept for the log.
  KEPT = 50

  # Frames a chat line stays in the log, ten seconds, unless the chat box is open.
  LOG_FRAMES = 600

  # Frames a bubble stays, six seconds.
  BUBBLE_FRAMES = 360

  # Frames after the chat key opened the box in which the key's own character may still arrive.
  KEY_ECHO_FRAMES = 10

  # What starts a line of the party chat, which only the player's party hears.
  PARTY_PREFIX = /\A\/p(\s|\z)/i

  # What the log shows before a line of the party chat.
  PARTY_TAG = "[Party] "

  # A line of the chat log.
  #
  # @!attribute name [String, nil] The sender's name, nil for a line of the game's own.
  # @!attribute text [String] The line.
  # @!attribute who [Symbol] Whose it is, which colors the name: :me, :member (of the player's
  #   party), :other or :system.
  # @!attribute party [Boolean] Whether it is a line of the party chat.
  # @!attribute left [Integer] Frames it still shows while the chat box is closed.
  Line = Struct.new(:name, :text, :who, :party, :left) do
    # Writes what comes before the line itself: the party tag and the sender's name.
    #
    # @return [String] The head, "* " for a line of the game's own.
    def head
      return "* " if who == :system

      "#{party ? MGQ_MpChat::PARTY_TAG : ''}#{name}: "
    end

    # Writes the whole line, as the log shows it.
    #
    # @return [String] The line.
    def to_s
      head + text
    end
  end

  @log = []
  @bubbles = {}
  @edit = nil

  # Reports whether the keyboard reaches the game, which only happens once its window is hooked.
  #
  # @return [Boolean] Whether it does.
  def self.available?
    MGQ_Multiplayer::Background.running?
  end

  # The action wheel's chat choice.
  #
  # @return [MGQ_MpActions::Option] The choice.
  def self.wheel_option
    MGQ_MpActions::Option.new("Chat (#{MGQ_MpHotkeys.label(:chat)})", available? ? lambda { start_typing } : nil,
                              "Chat needs the keyboard, which cannot reach the game.")
  end

  # Reports whether the chat box is open.
  #
  # @return [Boolean] Whether it is.
  def self.typing?
    !@edit.nil?
  end

  # The editor of the chat box.
  #
  # @return [MGQ_MpUi::TextEdit, nil] The editor, nil while the box is closed.
  def self.editor
    @edit
  end

  # The text in the chat box.
  #
  # @return [String, nil] The text, nil while the box is closed.
  def self.typed
    @edit && @edit.text
  end

  # Where the cursor stands in the chat box's text.
  #
  # @return [Integer] The characters before it.
  def self.cursor
    @edit ? @edit.cursor : 0
  end

  # Reports whether the blinking cursor shows this frame.
  #
  # @return [Boolean] Whether it does.
  def self.cursor_shown?
    @edit ? @edit.cursor_shown? : false
  end

  # Opens the chat box, which holds the buttons, so keys that type move nobody.
  #
  # @param key [Integer, nil] Windows' code of the key that opened it, nil when the wheel did.
  def self.start_typing(key = nil)
    @edit = MGQ_MpUi::TextEdit.new("", :max_chars => MAX_LENGTH)
    @echo = key ? { :key => key, :frames => KEY_ECHO_FRAMES } : nil
    MGQ_Multiplayer::Link.typing(true)
    MGQ_Multiplayer::Capture.start(:chat)
  end

  # Leaves out the character of the key that opened the chat box.
  #
  # The key is seen going down before the game's window gets the character it types, which then
  # reaches the box that just opened.
  #
  # @param text [String] What was typed since the last frame.
  # @return [String] The same, without the key's own character.
  def self.without_echo(text)
    echo = @echo
    return text unless echo

    echo[:frames] -= 1
    @echo = nil if echo[:frames] <= 0 || !text.empty?
    !text.empty? && text[0, 1].upcase.ord == echo[:key] ? text[1..-1] : text
  end

  # Closes the chat box, if it is open, and gives the buttons back.
  def self.stop_typing
    return unless typing?

    @edit = nil
    MGQ_Multiplayer::Link.typing(false)
    MGQ_Multiplayer::Capture.stop(:chat)
  end

  # Types what came from the keyboard since the last frame, then lets the editor follow the keys
  # that type nothing.
  def self.update_typing
    text, _keys = MGQ_Multiplayer::Link.take_typed
    without_echo(text.to_s).each_char do |char|
      type(char)
      return unless typing?
    end
    @edit.update_keys
  end

  # Types one character at the cursor: Enter sends, Escape closes.
  #
  # @param char [String] The character.
  def self.type(char)
    case @edit.type(char)
    when :enter
      send_typed
    when :escape
      stop_typing
      Sound.play_cancel
    when :refused
      Sound.play_buzzer
    end
  end

  # Sends the chat box's text, closing the box; an empty box just closes. A line that starts with
  # PARTY_PREFIX goes to the player's party only.
  def self.send_typed
    text = @edit.text.strip
    stop_typing
    party = text =~ PARTY_PREFIX ? true : false
    text = text.sub(PARTY_PREFIX, "").strip if party
    return if text.empty?
    return refuse("You are in no party, so nobody hears the party chat.") if party && !(defined?(MGQ_MpCoop) && MGQ_MpCoop.in_party?)

    name = MGQ_Multiplayer::Player.name.to_s
    sent = party ? MGQ_MpCoop.tell(-1, "pchat", text, "name" => name) : MGQ_MpChat.tell("chat" => text, "name" => name)
    return refuse("The message could not be sent.") unless sent

    add(:me, name, text, party)
  end

  # Turns a line down that cannot be sent.
  #
  # @param text [String] Why, as a notice.
  def self.refuse(text)
    Sound.play_buzzer
    MGQ_MpOverworldSync.notice(text)
  end

  # Takes another player's chat line.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it, nil before their first state.
  # @param message [Hash] The message, the line under "chat".
  def self.receive(peer, message)
    take_line(peer, message["chat"], message["name"], false)
  end

  # Takes a party member's line of the party chat. Called by coop.rbx, which drops another party's.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message, the line under "pchat".
  def self.receive_party(peer, message)
    take_line(peer, message["pchat"], message["name"], true)
  end

  # Adds another player's line, without control characters and cut to MAX_LENGTH.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param text [String, nil] The line.
  # @param name [String, nil] The name the message carries, for a sender without a state yet.
  # @param party [Boolean] Whether it is a line of the party chat.
  def self.take_line(peer, text, name, party)
    text = text.to_s.gsub(/[[:cntrl:]]/, "").strip[0, MAX_LENGTH]
    return if text.empty?

    add(peer ? peer.seat : nil, peer ? peer.state["name"] : name, text, party, peer && member?(peer))
  end

  # Reports whether another player is in the player's party, whose name the log shows green.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @return [Boolean] Whether they are.
  def self.member?(peer)
    defined?(MGQ_MpCoop) && MGQ_MpCoop.in_party? && MGQ_MpCoop::Party.member?(peer.state) ? true : false
  end

  # Adds a chat line to the log, and to the sender's bubble.
  #
  # @param sender [Integer, Symbol, nil] The sender's seat, :me for the player, nil for no bubble.
  # @param name [String] The sender's name.
  # @param text [String] The line.
  # @param party [Boolean] Whether it is a line of the party chat.
  # @param member [Boolean] Whether another sender is in the player's party.
  def self.add(sender, name, text, party = false, member = false)
    who = sender == :me ? :me : (member ? :member : :other)
    push(Line.new(name.to_s, text, who, party))
    @bubbles[sender] = [text, BUBBLE_FRAMES] unless sender.nil?
  end

  # Adds a line of the game's own to the log, such as a player leaving a battle, which shows in
  # battles too, where the world's status line does not.
  #
  # @param text [String] The line.
  def self.system(text)
    push(Line.new(nil, text, :system, false))
  end

  # Adds a line to the log, forgetting the oldest beyond KEPT.
  #
  # @param line [Line] The line.
  def self.push(line)
    line.left = LOG_FRAMES
    @log.push(line)
    @log.shift while @log.size > KEPT
  end

  # Lets log lines and bubbles run out. Called every frame.
  def self.count_down
    @log.each { |line| line.left -= 1 if line.left > 0 }
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
  # @return [Array<Line>] The lines, oldest first.
  def self.log_entries
    @log.select { |line| typing? || line.left > 0 }
  end

  # Writes the log's lines to show as text.
  #
  # @return [Array<String>] The lines, oldest first.
  def self.log_lines
    log_entries.map(&:to_s)
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

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Scene_Battle.method_defined?(:mgq_mp_chat_update_basic)
  end

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "chat"

  # Tells every other game of the world something, through overworld_sync.rbx.
  #
  # @param fields [Hash] The message's fields, which must leave out MGQ_MpOverworldSync::STATE_FIELD,
  #   since that marks a state.
  # @return [Boolean] Whether it went out.
  def self.tell(fields)
    MGQ_MpOverworldSync.tell(-1, fields)
  end

  # Lets bubbles and chat lines run out, closes the chat box once neither the map nor a battle
  # shows, and forgets the chat once no world is open. Called by overworld_sync.rbx every frame
  # in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    scene = SceneManager.scene
    stop_typing unless in_world && (scene.is_a?(Scene_Map) || scene.is_a?(Scene_Battle))
    in_world ? count_down : reset
  end

  # Tells what the player does while the chat box is open. Called by overworld_sync.rbx.
  #
  # @return [String, nil] "typing" while the chat box is open, else nil.
  def self.scene
    typing? ? "typing" : nil
  end

  # Reports whether the map lets the player chat: quiet, or busy only with the party's story, which
  # the player waits for, through coop_gather.rbx.
  #
  # @return [Boolean] Whether it does.
  def self.map_open?
    MGQ_MpOverworldSync.map_quiet? || (defined?(MGQ_MpCoopGather) && MGQ_MpCoopGather.waiting?) ? true : false
  end

  # Opens the chat box with its key, and types into it while it is open. Called by the map every
  # frame, so a press of the key is seen once.
  def self.on_map
    chat_key = MGQ_MpHotkeys.pressed?(:chat)
    return stop_typing unless MGQ_MpOverworldSync.in_world?

    # A box already open stays, so a story that starts meanwhile never throws the line away; the
    # box holds the buttons, so the story's messages wait for it, and on_message takes the typing.
    if typing?
      update_typing
    elsif chat_key && available? && !MGQ_MpActions::Wheel.open? && map_open?
      Sound.play_ok
      start_typing(MGQ_MpHotkeys.code(:chat))
    end
  rescue => e
    log("chat failed: #{e.class}: #{e.message}")
    stop_typing
  end

  # Types into an open chat box while the map shows a message, which stops the map's own update
  # that on_map follows. The box holds the buttons, so without this neither the box nor the message
  # could go on. Called by the map every frame.
  #
  # @param scene [Scene_Map] The map.
  def self.on_message(scene)
    on_map if typing? && !scene.scene_change_ok?
  rescue => e
    log("chat failed: #{e.class}: #{e.message}")
    stop_typing
  end

  # Opens the chat box with its key in a battle of a world, and types into it while it is open.
  # Called by the battle every frame, its waits included, so the player chats while the battle plays on.
  def self.on_battle
    chat_key = MGQ_MpHotkeys.pressed?(:chat)
    return stop_typing unless MGQ_MpOverworldSync.in_world?

    if typing?
      update_typing
    elsif chat_key && available?
      Sound.play_ok
      start_typing(MGQ_MpHotkeys.code(:chat))
    end
  rescue => e
    log("battle chat failed: #{e.class}: #{e.message}")
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
    lines = MGQ_MpUi.wrap(bitmap, text, WIDTH - PAD * 2)
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

  # Room a battle's command and status windows keep at the bottom of the screen.
  BATTLE_ROOM = 200

  # Background while the chat box is open.
  BACK = Color.new(0, 0, 0, 120)

  # Color of the lines' text.
  TEXT_COLOR = Color.new(255, 255, 255)

  # Colors of the senders' names: the player's own yellow, the party's members green as their
  # labels on the map, everyone else's white, and the game's own lines grey.
  NAME_COLORS = { :me => Color.new(255, 225, 110), :member => Color.new(128, 255, 128), :other => TEXT_COLOR,
                  :system => Color.new(200, 200, 200) }

  # Color of the tag before a line of the party chat.
  PARTY_TAG_COLOR = Color.new(190, 170, 255)

  # Color of the chat box's hint.
  HINT = Color.new(180, 180, 180)

  # Background of the chat box's row, over the log's.
  BOX_BACK = Color.new(0, 0, 0, 110)

  # Room left of the chat box's text.
  TEXT_LEFT = 4

  # What the chat box says while it is empty.
  BOX_HINT = "Enter sends, /p first for the party only, Esc closes."

  # Creates the log, empty.
  #
  # @param viewport [Viewport] The map's topmost viewport, or the battle's chat viewport.
  # @param bottom_room [Integer] Room kept free below it: STATUS_ROOM on the map, BATTLE_ROOM in battle.
  def initialize(viewport, bottom_room = STATUS_ROOM)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, ROW * (ROWS + 1))
    self.x = 8
    self.y = Graphics.height - bottom_room - bitmap.height
    self.z = 200
    @shown = nil
  end

  # Draws the log and the chat box, if they changed.
  def update
    super
    chat = MGQ_MpChat
    lines = MGQ_MpOverworldSync.in_world? ? chat.log_entries.last(ROWS) : []
    drawn = [lines.map { |line| [line.to_s, line.who] }, chat.typed, chat.cursor, chat.typing? && chat.cursor_shown?]
    return if drawn == @shown

    @shown = drawn
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    bitmap.fill_rect(bitmap.rect, BACK) if chat.typing?
    rows = lines.map { |line| MGQ_MpUi.wrap(bitmap, line.to_s, WIDTH - 8).each_with_index.map { |row, index| [row, index == 0 ? line : nil] } }
    rows = rows.flatten(1).last(ROWS)
    rows.each_with_index { |(row, line), index| draw_row(row, line, (ROWS - rows.size + index) * ROW) }
    draw_box(chat.editor) if chat.typing?
  end

  # Draws one row of the log; a line's first row with its head in the sender's colors.
  #
  # @param row [String] The row's text.
  # @param line [MGQ_MpChat::Line, nil] The line the row starts, nil for a row that goes on a line.
  # @param y [Integer] The row's top.
  def draw_row(row, line, y)
    x = 4
    if line && row.start_with?(line.head)
      x = draw_part(x, y, MGQ_MpChat::PARTY_TAG, PARTY_TAG_COLOR) if line.party
      x = draw_part(x, y, line.head.sub(MGQ_MpChat::PARTY_TAG, ""), NAME_COLORS.fetch(line.who, TEXT_COLOR))
      row = row[line.head.size..-1]
    end
    draw_part(x, y, row, TEXT_COLOR)
  end

  # Draws a part of a row in a color.
  #
  # @param x [Integer] Where it starts.
  # @param y [Integer] The row's top.
  # @param text [String] The part.
  # @param color [Color] Its color.
  # @return [Integer] Where the next part starts.
  def draw_part(x, y, text, color)
    width = bitmap.text_size(text).width
    bitmap.font.color = color
    bitmap.draw_text(x, y, width + 2, ROW, text)
    bitmap.font.color = TEXT_COLOR
    x + width
  end

  # Draws the chat box on the bottom row: the text around the cursor and the cursor, with a hint
  # behind them while the text is empty.
  #
  # @param editor [MGQ_MpUi::TextEdit] The chat box's editor.
  def draw_box(editor)
    y = ROWS * ROW
    bitmap.fill_rect(0, y, WIDTH, ROW, BOX_BACK)

    if editor.text.empty?
      bitmap.font.color = HINT
      bitmap.draw_text(TEXT_LEFT + MGQ_MpUi::TextBox::CURSOR_WIDTH + 2, y, WIDTH - TEXT_LEFT * 2, ROW, BOX_HINT)
      bitmap.font.color = Color.new(255, 255, 255)
    end

    MGQ_MpUi::TextBox.draw_line(bitmap, Rect.new(TEXT_LEFT, y, WIDTH - TEXT_LEFT * 2, ROW), editor)
  end

  # Frees the log's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# What this script takes part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route("chat") { |peer, message| MGQ_MpChat.receive(peer, message) }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpChat.tick(in_world) }
  MGQ_MpOverworldSync.busy_scene { MGQ_MpChat.scene }
rescue => e
  MGQ_MpChat.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What the chat adds to the action wheel, through ui_actions.rbx.

begin
  MGQ_MpActions.wheel_slot(:LEFT) { MGQ_MpChat.wheel_option }
  MGQ_MpActions.cover { |_wheel_key| MGQ_MpChat.typing? }
rescue => e
  MGQ_MpChat.log("action wheel FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the chat box. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_chat") { MGQ_MpChat.on_map unless scene_changing? }

  # After the map's sprites, the chat log and a bubble per player with a recent chat line, above
  # them while they are on this map.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_chat") do
    @mgq_mp_chat_log ||= Sprite_MpChatLog.new(@viewport3)
    @mgq_mp_chat_log.update
    @mgq_mp_bubbles ||= {}
    chat = MGQ_MpChat
    senders = MGQ_MpOverworldSync.in_world? ? chat.senders : []
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

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_chat") do
    @mgq_mp_chat_log.dispose if @mgq_mp_chat_log
    (@mgq_mp_bubbles || {}).each_value { |sprite| sprite.dispose }
    @mgq_mp_chat_log = @mgq_mp_bubbles = nil
  end
rescue => e
  MGQ_MpChat.log("hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone.
#
# Each wraps a game method: the original runs first, and the mod's part never raises.

if MGQ_MpChat.hookable?
  begin
    class Scene_Map
      alias mgq_mp_chat_update update

      # Updates the map, then an open chat box while a message stops the map's own update.
      def update
        mgq_mp_chat_update
        MGQ_MpChat.on_message(self)
      end
    end
  rescue => e
    MGQ_MpChat.log("map hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Scene_Battle
      alias mgq_mp_chat_update_basic update_basic

      # Updates the battle, then the chat box.
      #
      # update_basic runs in the battle's waits too, so the chat box takes typing while the battle
      # plays on.
      def update_basic
        mgq_mp_chat_update_basic
        MGQ_MpChat.on_battle
      end
    end

    class Spriteset_Battle
      alias mgq_mp_chat_update update
      alias mgq_mp_chat_dispose dispose

      # Updates the battle's sprites, then the chat log.
      def update
        mgq_mp_chat_update
        mgq_mp_chat_update_log
      end

      # Keeps the chat log above the battle's windows while a world is open.
      def mgq_mp_chat_update_log
        return unless @mgq_mp_chat_log || MGQ_MpOverworldSync.in_world?

        # The battle's windows lie above every viewport of the spriteset, so the log gets its own.
        @mgq_mp_chat_viewport ||= Viewport.new.tap { |viewport| viewport.z = 300 }
        @mgq_mp_chat_log ||= Sprite_MpChatLog.new(@mgq_mp_chat_viewport, Sprite_MpChatLog::BATTLE_ROOM)
        @mgq_mp_chat_log.update
      rescue => e
        MGQ_MpChat.log_once(:battle_log, "battle chat log failed: #{e.class}: #{e.message}")
      end

      # Frees the chat log, then the battle's sprites.
      def dispose
        @mgq_mp_chat_log.dispose if @mgq_mp_chat_log
        @mgq_mp_chat_viewport.dispose if @mgq_mp_chat_viewport
        @mgq_mp_chat_log = @mgq_mp_chat_viewport = nil
        mgq_mp_chat_dispose
      end
    end
  rescue => e
    MGQ_MpChat.log("battle hooks FAILED: #{e.class}: #{e.message}")
  end
end
