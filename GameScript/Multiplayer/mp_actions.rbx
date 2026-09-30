#----------------------------------------------------------------
#  mp_actions.rbx
#
#  Changelog:
#      Paulinchen  2026-09-30: Left the chat to mp_chat.rbx, keeping the wheel's chat choice
#                            - Left the party to mp_coop.rbx, keeping the wheel's party choices
#                            - Registered with mp_overworld_sync.rbx for its messages instead of being asked by mp_overworld.rbx
#                            - Moved into Patch/Multiplayer as mp_actions.rbx, which Multiplayer.rb loads
#                            - Found the party's leader, the member who made the party
#                            - Gave the chat box a blinking cursor, moved with the arrows, Home and End, with Delete
#      Paulinchen  2026-09-29: Told mp_overworld.rbx while the player types in the chat
#                            - Showed the chat box's text as it is typed
#                            - Left room right above the player's head for their ping
#                            - Added chat, opened with T or the wheel: a bubble above the sender and a log at the bottom left
#                            - Opened an action wheel with B, which invites, accepts, leaves the party, and holds chat and duels
#                            - Created
#
#----------------------------------------------------------------

# The action wheel on the map: B opens it around the player, its party choices go to mp_coop.rbx
# and its chat choice to mp_chat.rbx. It builds on mp_overworld_sync.rbx, which knows the other
# players.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpActions
  # Windows' code of the key that opens and closes the action wheel: B, which neither the game's
  # Input nor its gamepad plugin reads.
  WHEEL_KEY = 0x42

  # Pixels kept free right above the player's head, where mp_overworld.rbx shows their ping.
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

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("actions: #{message}")
  rescue
  end

  # Reports whether a world is open, through mp_overworld_sync.rbx.
  #
  # @return [Boolean] Whether it is.
  def self.in_world?
    defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.in_world? ? true : false
  end

  # Shows a notice at the bottom left of the map, through mp_overworld_sync.rbx.
  #
  # @param text [String] The notice.
  def self.notice(text)
    MGQ_MpOverworldSync::Status.notice(text) if defined?(MGQ_MpOverworldSync)
  end

  # Lists the other players of the world, through mp_overworld_sync.rbx.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.peers
    defined?(MGQ_MpOverworldSync) ? MGQ_MpOverworldSync::Peers.all : []
  end

  # Closes the wheel once the map is left. Called by mp_overworld_sync.rbx every frame in every
  # scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    Wheel.close unless in_world && SceneManager.scene.is_a?(Scene_Map)
  end

  # Tells what the line above the player's own head says, if anything.
  #
  # @return [String, nil] The line.
  def self.own_line
    in_world? && MGQ_MpCoop::Party.inviting? && !Wheel.open? ? "Inviting to a party . . ." : nil
  end

  # The action wheel's choices, by the direction that picks them.
  #
  # @return [Hash{Symbol => Option}] The choices under :UP, :RIGHT, :DOWN and :LEFT.
  def self.wheel_options
    {
      :UP => join_or_invite_option,
      :RIGHT => Option.new("Duel", nil, "Duels come in a later version."),
      :DOWN => leave_option,
      :LEFT => Option.new("Chat (T)", MGQ_MpChat.available? ? lambda { MGQ_MpChat.start_typing } : nil, "Chat needs the keyboard, which cannot reach the game."),
    }
  end

  # The wheel's party choice: accepting the invite of a player nearby, else inviting the players
  # nearby who are outside the party.
  #
  # @return [Option] The choice.
  def self.join_or_invite_option
    party = MGQ_MpCoop::Party
    near = peers.select { |peer| party.near?(peer.state) && !party.member?(peer.state) }
    inviter = near.find { |peer| peer.state["invite"] == "1" }
    return Option.new("Accept #{inviter.state['name']}'s invite", lambda { party.join(inviter) }, nil) if inviter

    Option.new("Invite to a party", near.empty? ? nil : lambda { party.invite }, "Nobody is near enough to invite.")
  end

  # The wheel's choice that leaves the party, or stops an invite nobody took.
  #
  # @return [Option] The choice.
  def self.leave_option
    party = MGQ_MpCoop::Party
    return Option.new("Leave the party", lambda { party.leave }, nil) unless party.members.empty?
    return Option.new("Stop inviting", lambda { party.stop_inviting }, nil) if party.inviting?

    Option.new("Leave the party", nil, "You are in no party.")
  end

  # Opens, steers or closes the action wheel on the map, but leaves the keys to the chat box while
  # it is open. Called by the map every frame, so a press of the key is seen once.
  def self.on_map
    wheel_key = MGQ_Multiplayer::Key.pressed?(WHEEL_KEY)
    unless in_world? && !$game_map.interpreter.running? && !$game_message.busy?
      Wheel.close
      return
    end
    return if MGQ_MpChat.typing?

    if Wheel.open?
      Wheel.update(wheel_key)
    elsif wheel_key
      Wheel.open
    end
  rescue => e
    log("action wheel failed: #{e.class}: #{e.message}")
    Wheel.close
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
    bitmap.font.color = MGQ_MpCoop::INVITE_COLOR
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

# What this script takes part in of the world's messages, through mp_overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpActions.tick(in_world) }
rescue => e
  MGQ_MpActions.log("overworld sync FAILED: #{e.class}: #{e.message}")
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

      # Updates the map's sprites, then the line above the player's own head and the wheel.
      def update
        mgq_mp_actions_update
        mgq_mp_actions_update_sprites
      end

      # Keeps the line above the player's own head and the action wheel around them.
      def mgq_mp_actions_update_sprites
        @mgq_mp_own_line ||= Sprite_MpOwnLine.new(@viewport1)
        @mgq_mp_wheel ||= Sprite_MpActionWheel.new(@viewport3)
        player = @character_sprites.find { |sprite| sprite.character.equal?($game_player) }
        @mgq_mp_own_line.show(player)
        @mgq_mp_wheel.show(player)
      rescue => e
        MGQ_MpActions.log("action sprites failed: #{e.class}: #{e.message}") unless @mgq_mp_actions_failed
        @mgq_mp_actions_failed = true
      end

      # Frees the line above the player's own head and the wheel, then the map's sprites.
      def dispose
        [@mgq_mp_own_line, @mgq_mp_wheel].compact.each { |sprite| sprite.dispose }
        @mgq_mp_own_line = @mgq_mp_wheel = nil
        mgq_mp_actions_dispose
      end
    end
  rescue => e
    MGQ_MpActions.log("sprite hooks FAILED: #{e.class}: #{e.message}")
  end
end
