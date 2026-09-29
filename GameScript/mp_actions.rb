#----------------------------------------------------------------
#  mp_actions.rb
#
#  Changelog:
#      Paulinchen  2026-09-29: Left room right above the player's head for their ping
#                            - Added chat, opened with T or the wheel: a bubble above the sender and a log at the bottom left
#                            - Opened an action wheel with B, which invites, accepts, leaves the party, and holds chat and duels
#                            - Created
#
#----------------------------------------------------------------

# What players of a world do together on the map: the action wheel, parties and chat. It builds
# on mp_overworld.rb, which knows the other players and their messages, and which asks this script,
# through the functions at the top of MGQ_MpActions, what to add to the player's state, what to
# show above a ghost's name, and to take the messages that are not states.
#
# mp_overworld.rb loads after this script, so both only reach each other while the game runs.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpActions
  # Windows' code of the key that opens and closes the action wheel: B, which neither the game's
  # Input nor its gamepad plugin reads.
  WHEEL_KEY = 0x42

  # Windows' code of the key that opens the chat: T, which neither the game's Input nor its gamepad
  # plugin reads.
  CHAT_KEY = 0x54

  # Tiles another player may be away, on the same map, to be invited or to accept.
  NEAR_TILES = 2

  # Frames an invite stands, fifteen seconds at 60 frames per second.
  INVITE_FRAMES = 900

  # Color of the invite line above a ghost's name and above the player's own head.
  INVITE_COLOR = Color.new(255, 224, 128)

  # Pixels kept free right above the player's head, where mp_overworld.rb shows their ping.
  HEAD_ROOM = 16

  # A choice of the action wheel.
  #
  # @!attribute text [String] What the wheel shows.
  # @!attribute run [Proc, nil] What choosing it does, nil while it cannot be chosen.
  # @!attribute refusal [String, nil] The notice for choosing it while it cannot be chosen.
  Option = Struct.new(:text, :run, :refusal)

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Scene_Map.method_defined?(:mgq_mp_actions_update_scene)
  end

  # Writes a line to the Multiplayer mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("actions: #{message}")
  rescue
  end

  # Reports whether a world is open, through mp_overworld.rb.
  #
  # @return [Boolean] Whether it is.
  def self.in_world?
    defined?(MGQ_MpOverworld) && MGQ_MpOverworld.in_world? ? true : false
  end

  # Tells every other game of the world something, through mp_overworld.rb.
  #
  # @param fields [Hash] The message's fields, which must leave out "map", since that marks a state.
  # @return [Boolean] Whether it went out.
  def self.tell(fields)
    return false unless defined?(MGQ_MpOverworld)

    MGQ_MpOverworld::Link.send_to(-1, MGQ_MpOverworld::Me.encode(fields))
  end

  # Shows a notice at the bottom left of the map, through mp_overworld.rb.
  #
  # @param text [String] The notice.
  def self.notice(text)
    MGQ_MpOverworld::Status.notice(text) if defined?(MGQ_MpOverworld)
  end

  # Lists the other players of the world, through mp_overworld.rb.
  #
  # @return [Array<MGQ_MpOverworld::Peers::Peer>] The players.
  def self.peers
    defined?(MGQ_MpOverworld) ? MGQ_MpOverworld::Peers.all : []
  end

  # The fields this script adds to the state the player's game tells the others. Called by mp_overworld.rb.
  #
  # @return [Hash] The fields.
  def self.state_fields
    { "party" => Party.id.to_s, "invite" => Party.inviting? ? 1 : 0 }
  end

  # Lets invites, bubbles and chat lines run out, closes the wheel and the chat box once the map is
  # left, and forgets everything once no world is open. Called by mp_overworld.rb every frame in
  # every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    unless in_world && SceneManager.scene.is_a?(Scene_Map)
      Wheel.close
      Chat.stop_typing
    end

    if in_world
      Party.count_down
      Chat.count_down
    else
      Party.reset
      Chat.reset
    end
  end

  # Takes a message of another game that is no state. Called by mp_overworld.rb.
  #
  # @param peer [MGQ_MpOverworld::Peers::Peer, nil] Who sent it, nil before their first state.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    Chat.receive(peer, message) if message["chat"]
  end

  # Notices what another player's new state means for the party. Called by mp_overworld.rb.
  #
  # @param peer [MGQ_MpOverworld::Peers::Peer] The player, with what they just told.
  def self.observe(peer)
    Party.observe(peer)
  end

  # Notices another player leaving the world. Called by mp_overworld.rb.
  #
  # @param peer [MGQ_MpOverworld::Peers::Peer] The player.
  def self.observe_leaving(peer)
    Party.observe_leaving(peer)
  end

  # Tells what the line above a ghost's name says. Called by mp_overworld.rb.
  #
  # @param peer [MGQ_MpOverworld::Peers::Peer] The ghost's player.
  # @return [Array, nil] The text and its color, nil for none.
  def self.label_line(peer)
    peer.state["invite"] == "1" && !peer.member ? ["Invites to a party (B)", INVITE_COLOR] : nil
  end

  # Tells what the line above the player's own head says, if anything.
  #
  # @return [String, nil] The line.
  def self.own_line
    in_world? && Party.inviting? && !Wheel.open? ? "Inviting to a party . . ." : nil
  end

  # The action wheel's choices, by the direction that picks them.
  #
  # @return [Hash{Symbol => Option}] The choices under :UP, :RIGHT, :DOWN and :LEFT.
  def self.wheel_options
    {
      :UP => Party.join_or_invite_option,
      :RIGHT => Option.new("Duel", nil, "Duels come in a later version."),
      :DOWN => Party.leave_option,
      :LEFT => Option.new("Chat (T)", Chat.available? ? lambda { Chat.start_typing } : nil, "Chat needs the keyboard, which cannot reach the game."),
    }
  end

  # Opens, steers or closes the action wheel and the chat box on the map. Called by the map every
  # frame, so a press of either key is seen once.
  def self.on_map
    wheel_key = MGQ_Multiplayer::Key.pressed?(WHEEL_KEY)
    chat_key = MGQ_Multiplayer::Key.pressed?(CHAT_KEY)
    unless in_world? && !$game_map.interpreter.running? && !$game_message.busy?
      Wheel.close
      Chat.stop_typing
      return
    end

    if Chat.typing?
      Chat.update_typing
    elsif Wheel.open?
      Wheel.update(wheel_key)
    elsif wheel_key
      Wheel.open
    elsif chat_key && Chat.available?
      Sound.play_ok
      Chat.start_typing
    end
  rescue => e
    log("action wheel or chat failed: #{e.class}: #{e.message}")
    Wheel.close
    Chat.stop_typing
  end

  # The chat: a line typed on the keyboard goes to every player of the world, shows in a bubble
  # above the sender while they are on the same map, and in the chat log at the bottom left.
  module Chat
    # Characters a chat line may have.
    MAX_LENGTH = 120

    # Chat lines kept for the log.
    KEPT = 50

    # Frames a chat line stays in the log, ten seconds, unless the chat box is open.
    LOG_FRAMES = 600

    # Frames a bubble stays, six seconds.
    BUBBLE_FRAMES = 360

    @log = []
    @bubbles = {}
    @typed = nil

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

    # Opens the chat box, which holds the buttons, so keys that type move nobody.
    def self.start_typing
      @typed = ""
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

    # Types what came from the keyboard since the last frame.
    def self.update_typing
      text, _keys = MGQ_Multiplayer::Link.take_typed
      text.each_char do |char|
        type(char)
        break unless typing?
      end
    end

    # Types one character: Enter sends, Escape closes, Backspace removes the last one.
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
        @typed = @typed[0...-1]
      else
        return if char =~ /[[:cntrl:]]/

        @typed.length < MAX_LENGTH ? @typed << char : Sound.play_buzzer
      end
    end

    # Sends the chat box's text, closing the box; an empty box just closes.
    def self.send_typed
      text = @typed.strip
      stop_typing
      return if text.empty?

      if MGQ_MpActions.tell("chat" => text, "name" => MGQ_Multiplayer::Player.name.to_s)
        add(:me, MGQ_Multiplayer::Player.name.to_s, text)
      else
        Sound.play_buzzer
        MGQ_MpActions.notice("The message could not be sent.")
      end
    end

    # Takes another player's chat line.
    #
    # @param peer [MGQ_MpOverworld::Peers::Peer, nil] Who sent it, nil before their first state.
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
  end

  # The action wheel: four choices around the player, picked with the arrows and taken with the
  # game's confirm button. It holds the buttons while open, so the player stands still and the
  # game's menu stays shut.
  module Wheel
    # The directions around the player, clockwise from the top.
    DIRECTIONS = [:UP, :RIGHT, :DOWN, :LEFT]

    @open = false
    @selected = :UP

    # Reports whether the wheel is open.
    #
    # @return [Boolean] Whether it is.
    def self.open?
      @open
    end

    # The direction whose choice is picked.
    #
    # @return [Symbol] One of DIRECTIONS.
    def self.selected
      @selected
    end

    # Opens the wheel on the first choice that can be taken.
    def self.open
      options = MGQ_MpActions.wheel_options
      @selected = DIRECTIONS.find { |direction| options[direction].run } || DIRECTIONS[0]
      @open = true
      MGQ_Multiplayer::Capture.start(:wheel)
      Sound.play_cursor
    end

    # Closes the wheel, if it is open, and gives the buttons back.
    def self.close
      return unless @open

      @open = false
      MGQ_Multiplayer::Capture.stop(:wheel)
    end

    # Follows the arrows, takes the picked choice on confirm, and closes on cancel or the wheel key.
    #
    # @param pressed [Boolean] Whether the wheel key went down this frame.
    def self.update(pressed)
      if pressed || MGQ_Multiplayer::Capture.trigger?(:B)
        close
        Sound.play_cancel
        return
      end

      DIRECTIONS.each do |direction|
        next unless MGQ_Multiplayer::Capture.trigger?(direction) && direction != @selected

        @selected = direction
        Sound.play_cursor
      end

      choose(MGQ_MpActions.wheel_options[@selected]) if MGQ_Multiplayer::Capture.trigger?(:C)
    end

    # Takes a choice, or tells why it cannot be taken.
    #
    # @param option [Option] The choice.
    def self.choose(option)
      unless option.run
        Sound.play_buzzer
        MGQ_MpActions.notice(option.refusal) if option.refusal
        return
      end

      Sound.play_ok
      close
      option.run.call
    end
  end

  # The player's party: the others who share its id. Every game says its party's id and whether it
  # invites in the state it sends anyway, so joining needs no message of its own: a player who
  # accepts takes the inviter's id, and the inviter sees them join by it.
  module Party
    @id = nil
    @invite_frames = 0

    # The party's id, nil while the player is in none.
    #
    # @return [String, nil] The id.
    def self.id
      @id
    end

    # Reports whether the player invites to a party now.
    #
    # @return [Boolean] Whether they do.
    def self.inviting?
      @invite_frames > 0
    end

    # Reports whether another player is in the player's party.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether they are.
    def self.member?(state)
      !@id.nil? && state["party"] == @id
    end

    # Lists the other players in the party, whom a battle will take along once co-op battles exist.
    #
    # @return [Array<MGQ_MpOverworld::Peers::Peer>] The members.
    def self.members
      MGQ_MpActions.peers.select { |peer| member?(peer.state) }
    end

    # Leaves the party and forgets any invite, as when the world closes.
    def self.reset
      @id = nil
      @invite_frames = 0
    end

    # Lets an invite run out, and forgets a party nobody joined. Called every frame.
    def self.count_down
      return unless @invite_frames > 0

      @invite_frames -= 1
      @id = nil if @invite_frames == 0 && members.empty?
    end

    # The wheel's party choice: accepting the invite of a player nearby, else inviting the players
    # nearby who are outside the party.
    #
    # @return [Option] The choice.
    def self.join_or_invite_option
      near = MGQ_MpActions.peers.select { |peer| near?(peer.state) && !member?(peer.state) }
      inviter = near.find { |peer| peer.state["invite"] == "1" }
      return Option.new("Accept #{inviter.state['name']}'s invite", lambda { join(inviter) }, nil) if inviter

      Option.new("Invite to a party", near.empty? ? nil : lambda { invite }, "Nobody is near enough to invite.")
    end

    # The wheel's choice that leaves the party, or stops an invite nobody took.
    #
    # @return [Option] The choice.
    def self.leave_option
      return Option.new("Leave the party", lambda { leave }, nil) unless members.empty?
      return Option.new("Stop inviting", lambda { stop_inviting }, nil) if inviting?

      Option.new("Leave the party", nil, "You are in no party.")
    end

    # Invites the players nearby, making a party of one for them to join.
    def self.invite
      @id ||= "#{MGQ_Multiplayer::Link.player_id[0, 8]}#{rand(36**6).to_s(36)}"
      @invite_frames = INVITE_FRAMES
    end

    # Stops inviting, forgetting a party nobody joined.
    def self.stop_inviting
      @invite_frames = 0
      @id = nil if members.empty?
    end

    # Joins the party of a player who invites.
    #
    # @param inviter [MGQ_MpOverworld::Peers::Peer] The player.
    def self.join(inviter)
      left = @id && !members.empty?
      @id = inviter.state["party"]
      @invite_frames = 0
      MGQ_MpActions.notice("#{left ? 'You left your party and joined' : 'You joined'} #{inviter.state['name']}'s party.")
      MGQ_MpActions.peers.each { |peer| peer.member = member?(peer.state) }
    end

    # Leaves the party.
    def self.leave
      reset
      MGQ_MpActions.notice("You left the party.")
      MGQ_MpActions.peers.each { |peer| peer.member = false }
    end

    # Notices a player coming into or going out of the party, and stops inviting once one joined.
    #
    # @param peer [MGQ_MpOverworld::Peers::Peer] The player, with what they just told.
    def self.observe(peer)
      member = member?(peer.state)
      return if member == peer.member

      peer.member = member
      if member
        @invite_frames = 0
        MGQ_MpActions.notice("#{peer.state['name']} joined your party.")
      else
        MGQ_MpActions.notice("#{peer.state['name']} left your party.")
      end
    end

    # Forgets a party nobody is left in once a member left the world.
    #
    # @param peer [MGQ_MpOverworld::Peers::Peer] The player.
    def self.observe_leaving(peer)
      @id = nil if peer.member && members.empty? && !inviting?
    end

    # Reports whether another player stands near the player, on the same map.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether they do.
    def self.near?(state)
      state["map"].to_i == $game_map.map_id &&
        [(state["x"].to_i - $game_player.x).abs, (state["y"].to_i - $game_player.y).abs].max <= NEAR_TILES
    end
  end
end

# The line above the player's own head while they invite to a party.
class Sprite_MpOwnLine < Sprite
  # Width of the line.
  WIDTH = 320

  # Height of the line.
  HEIGHT = 24

  # Creates the line, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, HEIGHT)
    self.ox = WIDTH / 2
    self.z = 250
    @shown = nil
  end

  # Draws the line, if it changed, above the player's sprite.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    text = MGQ_MpActions.own_line
    self.visible = !text.nil? && !sprite.nil?
    return unless visible

    self.x = sprite.x
    self.y = sprite.y - sprite.height - MGQ_MpActions::HEAD_ROOM - HEIGHT
    return if text == @shown

    @shown = text
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    bitmap.font.color = MGQ_MpActions::INVITE_COLOR
    bitmap.draw_text(0, 0, WIDTH, HEIGHT, text, 1)
  end

  # Frees the line's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The action wheel around the player: a box per choice above, right of, below and left of them,
# the picked one lit, those that cannot be taken grey.
class Sprite_MpActionWheel < Sprite
  # Width of a choice's box.
  BOX_WIDTH = 200

  # Height of a choice's box.
  BOX_HEIGHT = 26

  # Room kept free around the player's sprite, which is 32 by 48 pixels.
  GAP = 4

  # Height of the player's sprite.
  PLAYER_HEIGHT = 48

  # Half the width of the player's sprite, plus the gap.
  PLAYER_SIDE = 20

  # Width of the wheel's picture.
  WIDTH = (PLAYER_SIDE + BOX_WIDTH) * 2

  # Row of the wheel's picture at the player's feet.
  FEET = BOX_HEIGHT + GAP + MGQ_MpActions::HEAD_ROOM + PLAYER_HEIGHT

  # Height of the wheel's picture.
  HEIGHT = FEET + GAP + BOX_HEIGHT

  # Where each direction's box sits in the picture.
  BOXES = {
    :UP => [(WIDTH - BOX_WIDTH) / 2, 0],
    :RIGHT => [WIDTH / 2 + PLAYER_SIDE, FEET - (PLAYER_HEIGHT + BOX_HEIGHT) / 2],
    :DOWN => [(WIDTH - BOX_WIDTH) / 2, FEET + GAP],
    :LEFT => [0, FEET - (PLAYER_HEIGHT + BOX_HEIGHT) / 2],
  }

  # Background of a box.
  BACK = Color.new(0, 0, 0, 170)

  # Background of the picked box.
  PICKED_BACK = Color.new(48, 96, 176, 220)

  # Color of a choice that can be taken.
  TEXT = Color.new(255, 255, 255)

  # Color of a choice that cannot be taken.
  GREY = Color.new(150, 150, 150)

  # Creates the wheel, hidden.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, HEIGHT)
    self.ox = WIDTH / 2
    self.oy = FEET
    self.z = 300
    self.visible = false
    @shown = nil
  end

  # Draws the wheel around the player's sprite while it is open, if it changed.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    self.visible = MGQ_MpActions::Wheel.open? && !sprite.nil?
    return unless visible

    self.x = sprite.x
    self.y = sprite.y
    options = MGQ_MpActions.wheel_options
    drawn = [MGQ_MpActions::Wheel.selected] + options.map { |direction, option| [direction, option.text, !option.run.nil?] }
    return if drawn == @shown

    @shown = drawn
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    options.each { |direction, option| draw_box(direction, option) }
  end

  # Draws one choice's box.
  #
  # @param direction [Symbol] The direction that picks it.
  # @param option [MGQ_MpActions::Option] The choice.
  def draw_box(direction, option)
    x, y = BOXES[direction]
    picked = direction == MGQ_MpActions::Wheel.selected
    bitmap.fill_rect(x, y, BOX_WIDTH, BOX_HEIGHT, picked ? PICKED_BACK : BACK)
    bitmap.font.color = option.run ? TEXT : GREY
    bitmap.draw_text(x + 4, y, BOX_WIDTH - 8, BOX_HEIGHT, option.text, 1)
  end

  # Frees the wheel's picture.
  def dispose
    bitmap.dispose
    super
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
    lines = MGQ_MpActions::Chat.wrap(bitmap, text, WIDTH - PAD * 2)
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
    chat = MGQ_MpActions::Chat
    lines = MGQ_MpActions.in_world? ? chat.log_lines.last(ROWS) : []
    drawn = [lines, chat.typed]
    return if drawn == @shown

    @shown = drawn
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    bitmap.fill_rect(bitmap.rect, BACK) if chat.typing?
    rows = lines.map { |line| chat.wrap(bitmap, line, WIDTH - 8) }.flatten.last(ROWS)
    rows.each_with_index { |row, index| bitmap.draw_text(4, (ROWS - rows.size + index) * ROW, WIDTH - 8, ROW, row) }
    draw_box(chat.typed) if chat.typing?
  end

  # Draws the chat box on the bottom row: the text's end with a cursor, or a hint while it is empty.
  #
  # @param text [String] The text typed.
  def draw_box(text)
    y = ROWS * ROW
    if text.empty?
      bitmap.font.color = HINT
      bitmap.draw_text(4, y, WIDTH - 8, ROW, "Type a message. Enter sends, Esc closes.")
      bitmap.font.color = Color.new(255, 255, 255)
      return
    end

    shown = "> #{text}_"
    shown = shown[1..-1] while shown.size > 1 && bitmap.text_size(shown).width > WIDTH - 8
    bitmap.draw_text(4, y, WIDTH - 8, ROW, shown)
  end

  # Frees the log's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# Game hooks.
#
# Each wraps a game method: the original runs first, and the mod's part never raises.

if MGQ_MpActions.hookable?
  begin
    class Scene_Map
      alias mgq_mp_actions_update_scene update_scene

      # Updates the map, then the action wheel.
      #
      # The game checks its own keys here too, only while no scene change is in the way.
      def update_scene
        mgq_mp_actions_update_scene
        MGQ_MpActions.on_map unless scene_changing?
      end
    end
  rescue => e
    MGQ_MpActions.log("map key hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Spriteset_Map
      alias mgq_mp_actions_update update
      alias mgq_mp_actions_dispose dispose

      # Updates the map's sprites, then the line above the player's own head, the wheel and the chat.
      def update
        mgq_mp_actions_update
        mgq_mp_actions_update_sprites
      end

      # Keeps the line above the player's own head, the action wheel around them, the chat bubbles
      # and the chat log.
      def mgq_mp_actions_update_sprites
        @mgq_mp_own_line ||= Sprite_MpOwnLine.new(@viewport1)
        @mgq_mp_wheel ||= Sprite_MpActionWheel.new(@viewport3)
        @mgq_mp_chat_log ||= Sprite_MpChatLog.new(@viewport3)
        player = @character_sprites.find { |sprite| sprite.character.equal?($game_player) }
        @mgq_mp_own_line.show(player)
        @mgq_mp_wheel.show(player)
        @mgq_mp_chat_log.update
        mgq_mp_actions_update_bubbles
      rescue => e
        MGQ_MpActions.log("action sprites failed: #{e.class}: #{e.message}") unless @mgq_mp_actions_failed
        @mgq_mp_actions_failed = true
      end

      # Keeps a bubble per player with a recent chat line, above them while they are on this map.
      def mgq_mp_actions_update_bubbles
        @mgq_mp_bubbles ||= {}
        chat = MGQ_MpActions::Chat
        senders = MGQ_MpActions.in_world? ? chat.senders : []
        (@mgq_mp_bubbles.keys - senders).each { |sender| @mgq_mp_bubbles.delete(sender).dispose }

        senders.each do |sender|
          bubble = @mgq_mp_bubbles[sender] ||= Sprite_MpChatBubble.new(@viewport1)
          if sender == :me
            character, lift = $game_player, Sprite_MpChatBubble::OWN_LIFT
            character = nil if MGQ_MpActions::Wheel.open?
          else
            peer = MGQ_MpOverworld::Peers.at(sender)
            character, lift = peer && peer.ghost, Sprite_MpChatBubble::GHOST_LIFT
          end

          shown = character && !character.transparent
          bubble.show(shown ? chat.bubble(sender) : nil, shown ? character.screen_x : 0, shown ? character.screen_y - lift : 0)
        end
      end

      # Frees the line above the player's own head, the wheel and the chat, then the map's sprites.
      def dispose
        [@mgq_mp_own_line, @mgq_mp_wheel, @mgq_mp_chat_log].compact.each { |sprite| sprite.dispose }
        (@mgq_mp_bubbles || {}).each_value { |sprite| sprite.dispose }
        @mgq_mp_own_line = @mgq_mp_wheel = @mgq_mp_chat_log = @mgq_mp_bubbles = nil
        mgq_mp_actions_dispose
      end
    end
  rescue => e
    MGQ_MpActions.log("sprite hooks FAILED: #{e.class}: #{e.message}")
  end
end
