#----------------------------------------------------------------
#  mp_overworld.rbx
#
#  Changelog:
#      Paulinchen  2026-09-30: Left the world's messages to mp_overworld_sync.rbx, keeping what the player sees of the others
#                            - Moved into Patch/Multiplayer as mp_overworld.rbx, which Multiplayer.rb loads
#                            - Called the battle and party scripts by their new names
#                            - Kept a script's message's body, which co-op battles carry their data in
#                            - Told scripts' messages apart before states, since some name a map too
#                            - Handed co-op battle messages to mp_battle_coop.rbx and mp_battle_sync.rbx
#                            - Handed party event messages to mp_coop_events.rbx
#                            - Handed chest messages to mp_coop_events.rbx
#                            - Handed story messages to mp_coop_story.rbx, routing scripts' messages through one table
#                            - Told when the player entered their map, and handed NPC messages to mp_coop_npcs.rbx
#      Paulinchen  2026-09-29: Told the others while the player types in the chat
#                            - Showed each player's ping, the own above the player's head and the others' beside their names
#                            - Left parties to mp_actions.rbx, which it asks through Actions
#                            - Created
#
#----------------------------------------------------------------

# What the player sees of the other players of the open world: their ghosts on the same map, which
# walk through everything and trigger nothing, with their names, what they do and their ping, the
# player's own ping, and the line at the bottom left. What the games tell each other is
# mp_overworld_sync.rbx's.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpOverworld
  # Icons of the game's icon set next to a ghost's name, by what its player does. Walking the map shows none.
  STATE_ICONS = {
    "battle" => 451,
    "event" => 4,
    "typing" => 4,
    "menu" => 183,
    "items" => 3059,
    "equip" => 3905,
    "shop" => 3874,
    "casino" => 220,
    "library" => 3240,
    "sailing" => 4069,
    "flying" => 3836,
    "away" => 6,
  }

  # Tiles a ghost walks to catch up; farther away, it moves there at once.
  CATCH_UP_TILES = 3

  # Opacity of the ghost of a player outside the party.
  STRANGER_OPACITY = 150

  # Colors of a ping, by the most milliseconds each stands for; above them all, the last.
  PING_COLORS = [[100, Color.new(128, 255, 128)], [200, Color.new(255, 224, 96)], [nil, Color.new(255, 112, 96)]]

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Spriteset_Map.method_defined?(:mgq_mp_overworld_update)
  end

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("overworld: #{message}")
  rescue
  end

  # Reports whether a world is open.
  #
  # @return [Boolean] Whether mp_world.rbx has a world open.
  def self.in_world?
    MGQ_MpOverworldSync.in_world?
  end

  # Writes a ping as it shows, with the color that says how good it is.
  #
  # @param ping [String, Integer, nil] The milliseconds.
  # @return [Array, nil] The text and its color, nil for no ping.
  def self.ping_label(ping)
    return nil if ping.to_s.empty?

    milliseconds = ping.to_i
    ["#{milliseconds} ms", PING_COLORS.find { |most, _| most.nil? || milliseconds <= most }[1]]
  end

  # Moves the ghosts of the players on this map. Called by the map every frame.
  def self.update_ghosts
    return unless in_world?

    map = $game_map.map_id
    MGQ_MpOverworldSync::Peers.all.each do |peer|
      here = peer.state["map"].to_i == map

      if here
        peer.ghost ||= Game_MpGhost.new(peer.state)
        peer.ghost.follow(peer.state, peer.member)
      else
        peer.ghost = nil
      end
    end
  rescue => e
    log("ghost update failed: #{e.class}: #{e.message}") unless @ghosts_failed
    @ghosts_failed = true
  end

  # Lists the players whose ghosts are on this map.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.ghosts
    in_world? ? MGQ_MpOverworldSync::Peers.all.select { |peer| peer.ghost } : []
  end
end

# Another player of the world on this map: it walks where they walk, looks like their party
# leader, and walks through everything without triggering anything.
class Game_MpGhost < Game_Character
  # Creates the ghost where its player stands.
  #
  # @param state [Hash] What the player last told.
  def initialize(state)
    super()
    @through = true
    @priority_type = 1
    @step_anime = false
    @walk_anime = true
    moveto(state["x"].to_i, state["y"].to_i)
    follow(state, false)
  end

  # Walks toward where the player stands, at their speed, and looks like them: see-through a
  # little while they are outside the player's party.
  #
  # @param state [Hash] What the player last told.
  # @param member [Boolean] Whether they are in the player's party.
  def follow(state, member)
    look_like(state)
    @opacity = member ? 255 : MGQ_MpOverworld::STRANGER_OPACITY
    update
    return if moving?

    dx = state["x"].to_i - @x
    dy = state["y"].to_i - @y

    if dx == 0 && dy == 0
      set_direction(state["d"].to_i) if state["d"].to_i > 0
    elsif dx.abs + dy.abs > MGQ_MpOverworld::CATCH_UP_TILES
      moveto(state["x"].to_i, state["y"].to_i)
      set_direction(state["d"].to_i) if state["d"].to_i > 0
    else
      move_straight(dx.abs >= dy.abs ? (dx > 0 ? 6 : 4) : (dy > 0 ? 2 : 8))
    end
  end

  # Takes the player's sprite, speed and visibility.
  #
  # @param state [Hash] What the player last told.
  def look_like(state)
    set_graphic(state["sprite"].to_s, state["index"].to_i) if @character_name != state["sprite"].to_s || @character_index != state["index"].to_i
    @move_speed = [[state["speed"].to_i, 1].max, 6].min
    @transparent = state["hidden"].to_i == 1
  end
end

# A ghost's name above its head, with an icon for what its player does, green for a party member,
# and above it the line a script gives through mp_overworld_sync.rbx, such as an invite.
class Sprite_MpGhostLabel < Sprite
  # Width of the label.
  WIDTH = 240

  # Height of one line.
  LINE = 24

  # Color of a party member's name.
  MEMBER_COLOR = Color.new(128, 255, 128)

  # Font size of the ping after the name.
  PING_SIZE = 14

  # Room between the name and the ping.
  PING_GAP = 6

  # Creates the label, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, LINE * 2)
    self.ox = WIDTH / 2
    self.z = 250
    @shown = nil
  end

  # Draws the label, if it changed, and follows the ghost's sprite.
  #
  # @param sprite [Sprite_Character] The ghost's sprite.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  def show(sprite, peer)
    state = peer.state
    self.x = sprite.x
    self.y = sprite.y - sprite.height - LINE * 2 + 4
    self.visible = sprite.visible && sprite.opacity > 0 && state["hidden"].to_i != 1
    above = MGQ_MpOverworldSync.label_line_of(peer)
    drawn = [state["name"], state["scene"], state["ping"], peer.member, above]
    return if drawn == @shown

    @shown = drawn
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    line(0, above[0], above[1]) if above
    draw_name(state["name"].to_s, MGQ_MpOverworld::STATE_ICONS[state["scene"]], peer.member ? MEMBER_COLOR : Color.new(255, 255, 255),
              MGQ_MpOverworld.ping_label(state["ping"]))
  end

  # Draws a centered line of text.
  #
  # @param row [Integer] The line, 0 above the name.
  # @param text [String] The text.
  # @param color [Color] Its color.
  def line(row, text, color)
    bitmap.font.color = color
    bitmap.draw_text(0, row * LINE, WIDTH, LINE, text, 1)
  end

  # Draws the name on the lower line, the icon before it and the ping after it.
  #
  # @param name [String] The player's name.
  # @param icon [Integer, nil] The icon's index in the game's icon set, nil for none.
  # @param color [Color] The name's color.
  # @param ping [Array, nil] The ping's text and color, nil for none.
  def draw_name(name, icon, color, ping)
    ping_width = 0
    if ping
      bitmap.font.size = PING_SIZE
      ping_width = bitmap.text_size(ping[0]).width
      bitmap.font.size = 18
    end

    after = ping ? PING_GAP + ping_width : 0
    width = [bitmap.text_size(name).width, WIDTH - 28 - after].min
    left = (WIDTH - width - (icon ? 26 : 0) - after) / 2

    if icon
      iconset = Cache.system("Iconset")
      bitmap.blt(left, LINE, iconset, Rect.new(icon % 16 * 24, icon / 16 * 24, 24, 24))
      left += 26
    end

    bitmap.font.color = color
    bitmap.draw_text(left, LINE, width, LINE, name)
    return unless ping

    bitmap.font.size = PING_SIZE
    bitmap.font.color = ping[1]
    bitmap.draw_text(left + width + PING_GAP, LINE, ping_width, LINE, ping[0])
  end

  # Frees the label's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The player's own ping, right above their head.
class Sprite_MpOwnPing < Sprite
  # Width of the ping.
  WIDTH = 80

  # Height of the ping, the room it takes above the head.
  HEIGHT = 16

  # Creates the ping, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, HEIGHT)
    self.ox = WIDTH / 2
    self.z = 250
    @shown = nil
  end

  # Draws the ping, if it changed, above the player's sprite.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    ping = MGQ_MpOverworld.in_world? ? MGQ_MpOverworld.ping_label(MGQ_MpOverworldSync::Ping.measured) : nil
    self.visible = !ping.nil? && !sprite.nil? && sprite.visible && sprite.opacity > 0
    return unless visible

    self.x = sprite.x
    self.y = sprite.y - sprite.height - HEIGHT
    return if ping[0] == @shown

    @shown = ping[0]
    bitmap.clear
    bitmap.font.size = Sprite_MpGhostLabel::PING_SIZE
    bitmap.font.outline = true
    bitmap.font.color = ping[1]
    bitmap.draw_text(0, 0, WIDTH, HEIGHT, ping[0], 1)
  end

  # Frees the ping's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The line at the bottom left of the map.
class Sprite_MpWorldStatus < Sprite
  # Width of the line.
  WIDTH = 400

  # Height of one row.
  ROW = 22

  # Rows the line has room for.
  ROWS = 4

  # Creates the line, empty.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, ROW * ROWS)
    self.x = 8
    self.y = Graphics.height - ROW * ROWS - 8
    self.z = 200
    @shown = []
  end

  # Draws what the line shows now, if it changed.
  def update
    super
    lines = MGQ_MpOverworld.in_world? ? MGQ_MpOverworldSync::Status.lines.last(ROWS) : []
    return if lines == @shown

    @shown = lines
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    lines.each_with_index do |line, row|
      bitmap.draw_text(0, (ROWS - lines.size + row) * ROW, WIDTH, ROW, line)
    end
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

if MGQ_MpOverworld.hookable?
  begin
    class Game_Map
      alias mgq_mp_overworld_update update

      # Updates the map, then moves the ghosts on it.
      #
      # @param args [Array] The original's arguments.
      def update(*args)
        mgq_mp_overworld_update(*args)
        MGQ_MpOverworld.update_ghosts
      end
    end
  rescue => e
    MGQ_MpOverworld.log("map hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Spriteset_Map
      alias mgq_mp_overworld_update update

      # Updates the map's sprites, then the ghosts', their labels, the player's own ping and the status line.
      def update
        mgq_mp_overworld_update
        mgq_mp_overworld_update_ghosts
      end

      # Keeps a sprite and label per ghost on this map, the player's own ping and the status line.
      def mgq_mp_overworld_update_ghosts
        @mgq_mp_ghosts ||= {}
        @mgq_mp_status ||= Sprite_MpWorldStatus.new(@viewport3)
        @mgq_mp_own_ping ||= Sprite_MpOwnPing.new(@viewport1)
        @mgq_mp_own_ping.show(@character_sprites.find { |sprite| sprite.character.equal?($game_player) })
        peers = MGQ_MpOverworld.ghosts

        @mgq_mp_ghosts.keys.each do |ghost|
          next if peers.any? { |peer| peer.ghost.equal?(ghost) }

          sprite, label = @mgq_mp_ghosts.delete(ghost)
          sprite.dispose
          label.dispose
        end

        peers.each do |peer|
          @mgq_mp_ghosts[peer.ghost] ||= [Sprite_Character.new(@viewport1, peer.ghost), Sprite_MpGhostLabel.new(@viewport1)]
          sprite, label = @mgq_mp_ghosts[peer.ghost]
          sprite.update
          label.show(sprite, peer)
        end

        @mgq_mp_status.update
      rescue => e
        MGQ_MpOverworld.log("ghost sprites failed: #{e.class}: #{e.message}") unless @mgq_mp_failed
        @mgq_mp_failed = true
      end

      alias mgq_mp_overworld_dispose dispose

      # Frees the ghosts' sprites, the player's own ping and the status line, then the map's.
      def dispose
        (@mgq_mp_ghosts || {}).values.flatten.each { |sprite| sprite.dispose }
        @mgq_mp_ghosts = nil
        [@mgq_mp_status, @mgq_mp_own_ping].compact.each { |sprite| sprite.dispose }
        @mgq_mp_status = @mgq_mp_own_ping = nil
        mgq_mp_overworld_dispose
      end
    end
  rescue => e
    MGQ_MpOverworld.log("sprite hooks FAILED: #{e.class}: #{e.message}")
  end
end
