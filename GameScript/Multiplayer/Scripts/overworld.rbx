#----------------------------------------------------------------
#  overworld.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Found the players on this map through MGQ_MpOverworldSync::Peers.on_this_map?, which the chat shares
#      Paulinchen  2026-10-07: Showed Luka's sprite of the game's data for a ghost whose sprite this game lacks, which kept the map's sprites from drawing
#                            - Took icons, white and the depths from MGQ_MpUi
#                            - Logged each ghost shown and hidden, with the map and why
#                            - Broke a notice longer than the status line into rows instead of cutting it off
#      Paulinchen  2026-10-04: Stacked the labels of characters on one tile upwards, above the player's own ping
#                            - Drew a notice's icon before its text
#                            - Renamed from mp_overworld.rbx
#      Paulinchen  2026-10-03: Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Hid the ghost of a player whose connection is down
#      Paulinchen  2026-10-02: Followed the map and its sprites through core_hooks.rbx
#      Paulinchen  2026-10-01: Showed a party member's followers behind their ghost
#                            - Showed the size of a player's party after their name and above the player's own head, and a crown for its leader
#      Paulinchen  2026-09-30: Left the world's messages to overworld_sync.rbx, keeping what the player sees of the others
#                            - Moved into Patch/Multiplayer/Scripts as overworld.rbx, which Multiplayer.rb loads
#                            - Called the battle and party scripts by their new names
#                            - Kept a script's message's body, which co-op battles carry their data in
#                            - Told scripts' messages apart before states, since some name a map too
#                            - Handed co-op battle messages to battles_coop.rbx and battles_sync.rbx
#                            - Handed party event messages to coop_events.rbx
#                            - Handed chest messages to coop_events.rbx
#                            - Handed story messages to coop_story.rbx, routing scripts' messages through one table
#                            - Told when the player entered their map, and handed NPC messages to coop_npcs.rbx
#      Paulinchen  2026-09-29: Told the others while the player types in the chat
#                            - Showed each player's ping, the own above the player's head and the others' beside their names
#                            - Left parties to ui_actions.rbx, which it asks through Actions
#                            - Created
#
#----------------------------------------------------------------

# What the player sees of the other players of the open world: their ghosts on the same map, which
# walk through everything and trigger nothing, with their names, what they do and their ping, the
# player's own ping, and the line at the bottom left. What the games tell each other is
# overworld_sync.rbx's.
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

  # Icon of the game's icon set before the name of a party's leader: a crown.
  CROWN_ICON = 226

  # Tells what marks a player's party: its size, and whether they lead it.
  #
  # @param player [MGQ_MpOverworldSync::Peers::Peer, Symbol] The player, :me for the player.
  # @return [Array, nil] The size as "2 / 4" and whether they lead, nil outside a party of two or more.
  def self.party_badge(player)
    return nil unless defined?(MGQ_MpCoop)

    id = player == :me ? MGQ_MpCoop::Party.id : player.state["party"]
    size = MGQ_MpCoop.size_of(id)
    size >= 2 ? ["#{size} / #{MGQ_MpCoop::MAX_PLAYERS}", MGQ_MpCoop.leads?(player)] : nil
  end

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "overworld"

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
    return unless MGQ_MpOverworldSync.in_world?

    map = $game_map.map_id
    MGQ_MpOverworldSync::Peers.all.each do |peer|
      here = MGQ_MpOverworldSync::Peers.on_this_map?(peer)

      if here
        unless peer.ghost
          peer.ghost = Game_MpGhost.new(peer.state)
          log("showing the ghost of #{MGQ_MpOverworldSync.who(peer)} on map #{map} at #{peer.state['x']},#{peer.state['y']}#{peer.member ? ', a party member' : ''}")
        end
        peer.ghost.follow(peer.state, peer.member)
      elsif peer.ghost
        peer.ghost = nil
        log("hid the ghost of #{MGQ_MpOverworldSync.who(peer)}: #{peer.away ? 'their connection is down' : "they are on map #{peer.state['map']}, the player on #{map}"}")
      end
    end
  rescue => e
    log_once(:ghosts, "ghost update failed: #{e.class}: #{e.message}")
  end

  # Tells which sprite a ghost or its follower shows for one its player's game sent: that one, or
  # Luka's of the game's data while this game lacks its file, such as a hero another mod added
  # there. A missing file raised in the map's sprites every frame, which kept the ghosts after it
  # and the status line from drawing.
  #
  # @param name [String] The sprite's file.
  # @param index [Integer] The sprite's index in the file.
  # @return [Array] The file and the index to show.
  def self.sprite(name, index)
    @sprites ||= {}
    unless @sprites.key?(name)
      @sprites[name] = begin
        Cache.character(name)
        true
      rescue => e
        log("this game has no sprite #{name} (#{e.class}), ghosts showing it show #{stand_in[0]} instead")
        false
      end
    end
    @sprites[name] ? [name, index] : stand_in
  end

  # Tells Luka's sprite as the game's data has it, read from the file itself, since a mod may have
  # changed the actor in the database meanwhile.
  #
  # @return [Array] The file and the index.
  def self.stand_in
    @stand_in ||= begin
      luka = load_data("Data/Actors.rvdata2")[1]
      [luka.character_name.to_s, luka.character_index.to_i]
    rescue => e
      log("reading Luka's sprite failed: #{e.class}: #{e.message}")
      ["", 0]
    end
  end

  # Lists the players whose ghosts are on this map.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.ghosts
    MGQ_MpOverworldSync.in_world? ? MGQ_MpOverworldSync::Peers.all.select { |peer| peer.ghost } : []
  end
end

# Another player of the world on this map: it walks where they walk, looks like their party
# leader, and walks through everything without triggering anything. A party member's ghost has the
# followers they show behind it.
class Game_MpGhost < Game_Character
  # The followers behind the ghost.
  #
  # @return [Array<Game_MpGhostFollower>] The followers, none outside the player's party.
  attr_reader :followers

  # Creates the ghost where its player stands.
  #
  # @param state [Hash] What the player last told.
  def initialize(state)
    super()
    @through = true
    @priority_type = 1
    @step_anime = false
    @walk_anime = true
    @followers = []
    moveto(state["x"].to_i, state["y"].to_i)
    follow(state, false)
  end

  # Walks toward where the player stands, at their speed, and looks like them: see-through a
  # little while they are outside the player's party, with their followers while inside it.
  #
  # @param state [Hash] What the player last told.
  # @param member [Boolean] Whether they are in the player's party.
  def follow(state, member)
    look_like(state)
    @opacity = member ? 255 : MGQ_MpOverworld::STRANGER_OPACITY
    update
    trail(member && defined?(MGQ_MpCoopSquad) ? MGQ_MpCoopSquad.parse_trail(state["trail"]) : [])
    @followers.each(&:update)
    return if moving?

    dx = state["x"].to_i - @x
    dy = state["y"].to_i - @y

    if dx == 0 && dy == 0
      set_direction(state["d"].to_i) if state["d"].to_i > 0
    elsif dx.abs + dy.abs > MGQ_MpOverworld::CATCH_UP_TILES
      moveto(state["x"].to_i, state["y"].to_i)
      set_direction(state["d"].to_i) if state["d"].to_i > 0
      @followers.each { |follower| follower.gather(self) }
    else
      # The followers step first, each onto where the one before it stands, as the game's do.
      @followers.reverse_each(&:chase)
      move_straight(dx.abs >= dy.abs ? (dx > 0 ? 6 : 4) : (dy > 0 ? 2 : 8))
    end
  end

  # Keeps a follower per look the player's followers have, in their order.
  #
  # @param looks [Array<Array>] Each follower's sprite and index.
  def trail(looks)
    @followers = @followers.first(looks.size)
    @followers << Game_MpGhostFollower.new(@followers.last || self) while @followers.size < looks.size
    @followers.each_with_index { |follower, index| follower.look_like(*looks[index], self) }
  end

  # Takes the player's sprite, speed and visibility.
  #
  # @param state [Hash] What the player last told.
  def look_like(state)
    look = [state["sprite"].to_s, state["index"].to_i]
    set_graphic(*MGQ_MpOverworld.sprite(*look)) if look != @sent_look
    @sent_look = look
    @move_speed = [[state["speed"].to_i, 1].max, 6].min
    @transparent = state["hidden"].to_i == 1
  end
end

# A follower behind a party member's ghost: it steps where the one before it stood, as the game's
# own followers do.
class Game_MpGhostFollower < Game_Character
  # Creates the follower where the one before it stands.
  #
  # @param preceding [Game_Character] The ghost or the follower before it.
  def initialize(preceding)
    super()
    @preceding = preceding
    @through = true
    @priority_type = 1
    @step_anime = false
    @walk_anime = true
    moveto(preceding.x, preceding.y)
  end

  # Takes the follower's look and the ghost's speed, opacity and visibility.
  #
  # @param name [String] The sprite's file.
  # @param index [Integer] The sprite's index in the file.
  # @param ghost [Game_MpGhost] The ghost it follows.
  def look_like(name, index, ghost)
    set_graphic(*MGQ_MpOverworld.sprite(name, index)) if [name, index] != @sent_look
    @sent_look = [name, index]
    @move_speed = ghost.move_speed
    @opacity = ghost.opacity
    @transparent = ghost.transparent
  end

  # Steps toward the one before it, unless it stands on the same tile.
  def chase
    return if moving?

    sx = distance_x_from(@preceding.x)
    sy = distance_y_from(@preceding.y)
    if sx != 0 && sy != 0
      move_diagonal(sx > 0 ? 4 : 6, sy > 0 ? 8 : 2)
    elsif sx != 0
      move_straight(sx > 0 ? 4 : 6)
    elsif sy != 0
      move_straight(sy > 0 ? 8 : 2)
    end
  end

  # Moves at once onto the ghost, as when the ghost jumped to its player.
  #
  # @param ghost [Game_MpGhost] The ghost.
  def gather(ghost)
    moveto(ghost.x, ghost.y)
    set_direction(ghost.direction)
  end
end

# A ghost's name above its head, with an icon for what its player does, green for a party member,
# and above it the line a script gives through overworld_sync.rbx, such as an invite.
class Sprite_MpGhostLabel < Sprite
  # Width of the label.
  WIDTH = 240

  # Height of one line.
  LINE = 24

  # Color of a party member's name.
  MEMBER_COLOR = Color.new(128, 255, 128)

  # Font size of the ping after the name.
  PING_SIZE = 14

  # Room between the name and each small text after it.
  PING_GAP = 6

  # Color of the size of a party the player is not in.
  SIZE_COLOR = Color.new(220, 220, 220)

  # Creates the label, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, LINE * 2)
    self.ox = WIDTH / 2
    self.z = MGQ_MpUi::Z[:labels]
    @shown = nil
  end

  # Draws the label, if it changed, and follows the ghost's sprite, lifted over the labels already
  # on its tile.
  #
  # @param sprite [Sprite_Character] The ghost's sprite.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  # @param lift [Integer] Pixels the labels already on the ghost's tile take, which it goes above.
  # @return [Integer] Pixels the label takes, for the next label on the tile.
  def show(sprite, peer, lift = 0)
    state = peer.state
    self.x = sprite.x
    self.y = sprite.y - sprite.height - LINE * 2 + 4 - lift
    self.visible = sprite.visible && sprite.opacity > 0 && state["hidden"].to_i != 1
    above = MGQ_MpOverworldSync.label_line_of(peer)
    taken = visible ? LINE * (above ? 2 : 1) : 0
    badge = MGQ_MpOverworld.party_badge(peer)
    drawn = [state["name"], state["scene"], state["ping"], peer.member, above, badge]
    return taken if drawn == @shown

    @shown = drawn
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    line(0, above[0], above[1]) if above
    icons = [MGQ_MpOverworld::STATE_ICONS[state["scene"]], badge && badge[1] ? MGQ_MpOverworld::CROWN_ICON : nil].compact
    extras = [badge && [badge[0], peer.member ? MEMBER_COLOR : SIZE_COLOR], MGQ_MpOverworld.ping_label(state["ping"])].compact
    draw_name(state["name"].to_s, icons, peer.member ? MEMBER_COLOR : MGQ_MpUi::WHITE, extras)
    taken
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

  # Draws the name on the lower line, the icons before it and the small texts after it, such as
  # the party's size and the ping.
  #
  # @param name [String] The player's name.
  # @param icons [Array<Integer>] The icons' indexes in the game's icon set.
  # @param color [Color] The name's color.
  # @param extras [Array<Array>] Each small text and its color.
  def draw_name(name, icons, color, extras)
    bitmap.font.size = PING_SIZE
    widths = extras.map { |text, _| bitmap.text_size(text).width }
    bitmap.font.size = 18
    after = widths.inject(0) { |sum, extra| sum + PING_GAP + extra }
    width = [bitmap.text_size(name).width, WIDTH - 26 * icons.size - 2 - after].min
    left = (WIDTH - width - 26 * icons.size - after) / 2

    iconset = Cache.system("Iconset") unless icons.empty?
    icons.each do |icon|
      bitmap.blt(left, LINE, iconset, MGQ_MpUi.icon_rect(icon))
      left += 26
    end

    bitmap.font.color = color
    bitmap.draw_text(left, LINE, width, LINE, name)
    left += width
    bitmap.font.size = PING_SIZE
    extras.each_with_index do |(text, extra_color), index|
      left += PING_GAP
      bitmap.font.color = extra_color
      bitmap.draw_text(left, LINE, widths[index], LINE, text)
      left += widths[index]
    end
  end

  # Frees the label's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The player's own ping, right above their head, after their party's size and a crown while they
# lead it.
class Sprite_MpOwnPing < Sprite
  # Width of the line.
  WIDTH = 200

  # Height of the ping, the room it takes above the head.
  HEIGHT = 16

  # Creates the ping, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, HEIGHT)
    self.ox = WIDTH / 2
    self.z = MGQ_MpUi::Z[:labels]
    @shown = nil
  end

  # Draws the line, if it changed, above the player's sprite.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    in_world = MGQ_MpOverworldSync.in_world?
    ping = in_world ? MGQ_MpOverworld.ping_label(MGQ_MpOverworldSync::Ping.measured) : nil
    badge = in_world ? MGQ_MpOverworld.party_badge(:me) : nil
    self.visible = !(ping.nil? && badge.nil?) && !sprite.nil? && sprite.visible && sprite.opacity > 0
    return unless visible

    self.x = sprite.x
    self.y = sprite.y - sprite.height - HEIGHT
    drawn = [ping, badge].map { |part| part && part[0] } + [badge && badge[1]]
    return if drawn == @shown

    @shown = drawn
    bitmap.clear
    bitmap.font.size = Sprite_MpGhostLabel::PING_SIZE
    bitmap.font.outline = true
    parts = [badge && [badge[0], Sprite_MpGhostLabel::MEMBER_COLOR], ping].compact
    widths = parts.map { |text, _| bitmap.text_size(text).width }
    crown = badge && badge[1] ? HEIGHT : 0
    left = (WIDTH - crown - widths.inject(0) { |sum, width| sum + width } - Sprite_MpGhostLabel::PING_GAP * (parts.size - 1)) / 2
    if crown > 0
      icon = MGQ_MpOverworld::CROWN_ICON
      bitmap.stretch_blt(Rect.new(left, 0, HEIGHT, HEIGHT), Cache.system("Iconset"), MGQ_MpUi.icon_rect(icon))
      left += crown
    end
    parts.each_with_index do |(text, color), index|
      bitmap.font.color = color
      bitmap.draw_text(left, 0, widths[index], HEIGHT, text)
      left += widths[index] + Sprite_MpGhostLabel::PING_GAP
    end
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
    self.z = MGQ_MpUi::Z[:lines]
    @shown = []
  end

  # Draws what the line shows now, if it changed: each notice broken into rows that fit, with its
  # icon before its first row, the newest rows at the bottom.
  def update
    super
    notices = MGQ_MpOverworldSync.in_world? ? MGQ_MpOverworldSync::Status.shown.last(ROWS) : []
    return if notices == @shown

    @shown = notices
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    rows = rows_of(notices)
    rows.each_with_index do |(text, icon, left), row|
      y = (ROWS - rows.size + row) * ROW
      bitmap.stretch_blt(Rect.new(0, y, ROW, ROW), Cache.system("Iconset"), MGQ_MpUi.icon_rect(icon)) if icon
      bitmap.draw_text(left, y, WIDTH - left, ROW, text)
    end
  end

  # Breaks notices into the rows the line shows, measured in the font set.
  #
  # @param notices [Array<Array>] Each notice's text and icon, the icon nil for none.
  # @return [Array<Array>] The last ROWS rows: each one's text, the icon before it (on a notice's
  #   first row only) and its left edge.
  def rows_of(notices)
    rows = []
    notices.each do |text, icon|
      left = icon ? ROW + 2 : 0
      MGQ_MpUi.wrap(bitmap, text.to_s, WIDTH - left).each_with_index { |part, index| rows << [part, index == 0 ? icon : nil, left] }
    end
    rows.last(ROWS)
  end

  # Frees the line's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the ghosts on it move.
  MGQ_MpHooks.after(Game_Map, :update, "overworld") { MGQ_MpOverworld.update_ghosts }

  # After the map's sprites, a sprite and label per ghost on this map, a sprite per ghost's
  # follower, the player's own ping and the status line.
  MGQ_MpHooks.after(Spriteset_Map, :update, "overworld") do
    @mgq_mp_ghosts ||= {}
    @mgq_mp_followers ||= {}
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

    followers = peers.map { |peer| peer.ghost.followers }.flatten
    @mgq_mp_followers.keys.each do |follower|
      @mgq_mp_followers.delete(follower).dispose unless followers.any? { |shown| shown.equal?(follower) }
    end

    # Followers first, so a ghost's sprite and label draw over its followers on the same tile.
    followers.each do |follower|
      (@mgq_mp_followers[follower] ||= Sprite_Character.new(@viewport1, follower)).update
    end

    # Labels on one tile stack upwards, above the player's own ping on the player's tile.
    taken = { [$game_player.x, $game_player.y] => Sprite_MpOwnPing::HEIGHT }
    peers.each do |peer|
      @mgq_mp_ghosts[peer.ghost] ||= [Sprite_Character.new(@viewport1, peer.ghost), Sprite_MpGhostLabel.new(@viewport1)]
      sprite, label = @mgq_mp_ghosts[peer.ghost]
      sprite.update
      tile = [peer.ghost.x, peer.ghost.y]
      taken[tile] = taken[tile].to_i + label.show(sprite, peer, taken[tile].to_i)
    end

    @mgq_mp_status.update
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "overworld") do
    ((@mgq_mp_ghosts || {}).values.flatten + (@mgq_mp_followers || {}).values).each { |sprite| sprite.dispose }
    @mgq_mp_ghosts = @mgq_mp_followers = nil
    [@mgq_mp_status, @mgq_mp_own_ping].compact.each { |sprite| sprite.dispose }
    @mgq_mp_status = @mgq_mp_own_ping = nil
  end
rescue => e
  MGQ_MpOverworld.log("hooks FAILED: #{e.class}: #{e.message}")
end
