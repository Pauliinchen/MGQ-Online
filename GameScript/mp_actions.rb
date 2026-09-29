#----------------------------------------------------------------
#  mp_actions.rb
#
#  Changelog:
#      Paulinchen  2026-09-29: Opened an action wheel with B, which invites, accepts, leaves the party, and holds chat and duels
#                            - Created
#
#----------------------------------------------------------------

# What players of a world do together on the map: the action wheel, and parties so far. It builds
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

  # Tiles another player may be away, on the same map, to be invited or to accept.
  NEAR_TILES = 2

  # Frames an invite stands, fifteen seconds at 60 frames per second.
  INVITE_FRAMES = 900

  # Color of the invite line above a ghost's name and above the player's own head.
  INVITE_COLOR = Color.new(255, 224, 128)

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

  # Lets an invite run out, closes the wheel once the map is left, and forgets everything once no
  # world is open. Called by mp_overworld.rb every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    Wheel.close unless in_world && SceneManager.scene.is_a?(Scene_Map)
    in_world ? Party.count_down : Party.reset
  end

  # Takes a message of another game that is no state. Called by mp_overworld.rb.
  #
  # @param peer [MGQ_MpOverworld::Peers::Peer, nil] Who sent it, nil before their first state.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
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
      :LEFT => Option.new("Chat", nil, "Chat comes in a later version."),
    }
  end

  # Opens, steers or closes the action wheel on the map. Called by the map every frame, so a press
  # of the wheel key is seen once.
  def self.on_map
    pressed = MGQ_Multiplayer::Key.pressed?(WHEEL_KEY)
    unless in_world? && !$game_map.interpreter.running? && !$game_message.busy?
      Wheel.close
      return
    end

    if Wheel.open?
      Wheel.update(pressed)
    elsif pressed
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
    self.y = sprite.y - sprite.height - HEIGHT
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
  FEET = BOX_HEIGHT + GAP + PLAYER_HEIGHT

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
