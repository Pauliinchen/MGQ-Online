#----------------------------------------------------------------
#  mp_actions.rb
#
#  Changelog:
#      Paulinchen  2026-09-29: Created
#
#----------------------------------------------------------------

# What players of a world do together on the map: parties so far. It builds on mp_overworld.rb,
# which knows the other players and their messages, and which asks this script, through the
# functions at the top of MGQ_MpActions, what to add to the player's state, what to show above a
# ghost's name, and to take the messages that are not states.
#
# mp_overworld.rb loads after this script, so both only reach each other while the game runs.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpActions
  # Windows' code of the key that invites to a party, accepts an invite or leaves the party: B,
  # which neither the game's Input nor its gamepad plugin reads.
  PARTY_KEY = 0x42

  # Tiles another player may be away, on the same map, to be invited or to accept.
  NEAR_TILES = 2

  # Frames an invite stands, fifteen seconds at 60 frames per second.
  INVITE_FRAMES = 900

  # Frames the second press that leaves the party may take, three seconds.
  LEAVE_FRAMES = 180

  # Color of the invite line above a ghost's name and above the player's own head.
  INVITE_COLOR = Color.new(255, 224, 128)

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

  # Lets an invite and a waiting leave run out, or forgets everything once no world is open.
  # Called by mp_overworld.rb every frame.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
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
    return nil unless in_world?
    return "Inviting to a party . . ." if Party.inviting?

    Party.leaving? ? "Press B again to leave the party" : nil
  end

  # Takes the party key on the map, while no event, message or scene change is in the way.
  # Called by the map every frame, so a press is seen once.
  def self.on_map
    pressed = MGQ_Multiplayer::Key.pressed?(PARTY_KEY)
    return unless pressed && in_world?
    return if $game_map.interpreter.running? || $game_message.busy?

    Party.press
  rescue => e
    log("party key failed: #{e.class}: #{e.message}")
  end

  # The player's party: the others who share its id. Every game says its party's id and whether it
  # invites in the state it sends anyway, so joining needs no message of its own: a player who
  # accepts takes the inviter's id, and the inviter sees them join by it.
  module Party
    @id = nil
    @invite_frames = 0
    @leave_frames = 0

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

    # Reports whether the player waits for a second press to leave the party.
    #
    # @return [Boolean] Whether they do.
    def self.leaving?
      @leave_frames > 0
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
      @leave_frames = 0
    end

    # Lets an invite and a waiting leave run out, and forgets a party nobody joined. Called every frame.
    def self.count_down
      @leave_frames -= 1 if @leave_frames > 0
      return unless @invite_frames > 0

      @invite_frames -= 1
      @id = nil if @invite_frames == 0 && members.empty?
    end

    # Acts on the party key, pressed on the map: accepts an invite nearby, invites the players
    # nearby, or leaves the party with a second press when nobody is near.
    def self.press
      near = MGQ_MpActions.peers.select { |peer| near?(peer.state) }
      inviter = near.find { |peer| peer.state["invite"] == "1" && !member?(peer.state) }

      if inviter
        join(inviter)
      elsif near.any? { |peer| !member?(peer.state) }
        invite
      elsif @id && !members.empty?
        leaving? ? leave : ask_to_leave
      else
        MGQ_MpActions.notice("Nobody is near enough to form a party.")
      end
    end

    # Invites the players nearby, making a party of one for them to join.
    def self.invite
      @id ||= "#{MGQ_Multiplayer::Link.player_id[0, 8]}#{rand(36**6).to_s(36)}"
      @invite_frames = INVITE_FRAMES
      @leave_frames = 0
    end

    # Joins the party of a player who invites.
    #
    # @param inviter [MGQ_MpOverworld::Peers::Peer] The player.
    def self.join(inviter)
      left = @id && !members.empty?
      @id = inviter.state["party"]
      @invite_frames = 0
      @leave_frames = 0
      MGQ_MpActions.notice("#{left ? 'You left your party and joined' : 'You joined'} #{inviter.state['name']}'s party.")
      MGQ_MpActions.peers.each { |peer| peer.member = member?(peer.state) }
    end

    # Asks for a second press before leaving the party.
    def self.ask_to_leave
      @leave_frames = LEAVE_FRAMES
      MGQ_MpActions.notice("Press B again to leave the party.")
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

# The line above the player's own head while they invite to a party or are about to leave it.
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

# Game hooks.
#
# Each wraps a game method: the original runs first, and the mod's part never raises.

if MGQ_MpActions.hookable?
  begin
    class Scene_Map
      alias mgq_mp_actions_update_scene update_scene

      # Updates the map, then takes the party key.
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

      # Updates the map's sprites, then the line above the player's own head.
      def update
        mgq_mp_actions_update
        mgq_mp_actions_update_sprites
      end

      # Keeps the line above the player's own head.
      def mgq_mp_actions_update_sprites
        @mgq_mp_own_line ||= Sprite_MpOwnLine.new(@viewport1)
        @mgq_mp_own_line.show(@character_sprites.find { |sprite| sprite.character.equal?($game_player) })
      rescue => e
        MGQ_MpActions.log("action sprites failed: #{e.class}: #{e.message}") unless @mgq_mp_actions_failed
        @mgq_mp_actions_failed = true
      end

      alias mgq_mp_actions_dispose dispose

      # Frees the line above the player's own head, then the map's sprites.
      def dispose
        @mgq_mp_own_line.dispose if @mgq_mp_own_line
        @mgq_mp_own_line = nil
        mgq_mp_actions_dispose
      end
    end
  rescue => e
    MGQ_MpActions.log("sprite hooks FAILED: #{e.class}: #{e.message}")
  end
end
