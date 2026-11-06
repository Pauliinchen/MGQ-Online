#----------------------------------------------------------------
#  overworld.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Read the colors of a follower's outline in the player's look through UI.color_now
#                            - Drew the ghosts' labels, the own ping, the own line and the world status as huds of the Mod Framework's UI layer
#                            - Named a ping's color by its name in the player's look
#      Paulinchen  2026-11-05: Read a ghost's followers as values
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#                            - Built the ghosts' labels, the own ping, the own line and the world status on the Mod Framework's components
#      Paulinchen  2026-10-31: Placed the world status through the Mod Framework's layout
#      Paulinchen  2026-10-23: Kept the status line off the live map behind menus
#      Paulinchen  2026-10-12: Read the map's viewports and character sprites through MGQ_MpGame
#      Paulinchen  2026-10-11: Made the line at the bottom left movable and widenable with the left Alt held
#                            - Drew the outline standing in for a follower in the shared style's colors
#                            - Named a ghost above its head in its player's color
#                            - Showed a keyboard above a ghost whose player types
#                            - Took the colors and font sizes from the shared style and drew icons through it
#                            - Showed a ping past 999 ms as "999+ ms" and sized the shared ping column here
#                            - Wrote a party's title with its size here
#      Paulinchen  2026-10-09: Drew every other player's ghost solid in a Raid World
#      Paulinchen  2026-10-08: Found the players on this map through MGQ_MpOverworldSync::Peers.on_this_map?
#                            - Showed a follower whose sprite this game lacks as the outline of Luka's sprite
#                            - Remembered the graphics this game lacks for the last 64 names only
#                            - Read Luka's sprite of the game's data once as the script loads
#                            - Compared a ghost's and a follower's sprite without building a pair every frame
#                            - Named a ghost above its head as the chat names its player
#      Paulinchen  2026-10-07: Showed Luka's sprite for a ghost whose sprite this game lacks
#                            - Took icons, white and the depths from MGQ_MpUi
#                            - Logged each ghost shown and hidden, with the map and why
#                            - Broke a notice longer than the status line into rows
#      Paulinchen  2026-10-04: Stacked the labels of characters on one tile upwards
#                            - Drew a notice's icon before its text
#                            - Renamed from mp_overworld.rbx
#      Paulinchen  2026-10-03: Sent messages and read the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Hid the ghost of a player whose connection is down
#      Paulinchen  2026-10-02: Followed the map and its sprites through core_hooks.rbx
#      Paulinchen  2026-10-01: Showed a party member's followers behind their ghost
#                            - Showed the size of a player's party and a crown for its leader
#      Paulinchen  2026-09-30: Left the world's messages to overworld_sync.rbx
#                            - Moved into Patch/Multiplayer/Scripts as overworld.rbx
#                            - Called the battle and party scripts by their new names
#                            - Kept a script's message's body
#                            - Told scripts' messages apart before states
#                            - Handed co-op battle messages to battles_coop.rbx and battles_sync.rbx
#                            - Handed party event messages to coop_events.rbx
#                            - Handed chest messages to coop_events.rbx
#                            - Handed story messages to coop_story.rbx through one routing table
#                            - Told when the player entered their map, and handed NPC messages to coop_npcs.rbx
#      Paulinchen  2026-09-29: Told the others while the player types in the chat
#                            - Showed each player's ping
#                            - Left parties to ui_actions.rbx
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
  # Icon of the game's icon set next to the name of a ghost whose player types in the chat: a
  # keyboard. The icon set's only speech-like icons are the "..." bubbles 4, the event's, and 20,
  # the same bubble on a state tile, which would not tell typing from an event at a glance.
  TYPING_ICON = 3930

  # Icons of the game's icon set next to a ghost's name, by what its player does. Walking the map
  # shows none.
  STATE_ICONS = {
    "battle" => 451,
    "event" => 4,
    "typing" => TYPING_ICON,
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

  # Opacity of the ghost of a player outside the party, in a Classic world.
  STRANGER_OPACITY = 150

  # Opacity of a ghost drawn solid.
  SOLID_OPACITY = 255

  # Colors of a ping, by the most milliseconds each stands for; above them all, the last.
  PING_COLORS = [[100, :success], [200, :warning], [nil, :error]]

  # Most milliseconds a ping shows; past them it shows as these with PING_PAST.
  PING_MOST = 999

  # What follows a ping past PING_MOST.
  PING_PAST = "+"

  # What a party's title starts with in a box, see party_title.
  PARTY_TITLE = "Party"

  # Icon of the game's icon set before the name of a party's leader: a crown.
  CROWN_ICON = 226

  # Graphics another player's game named that graphic keeps whether this game has at most, the
  # longest unused forgotten first, so a game naming ever new files cannot grow the list.
  MOST_GRAPHICS_KEPT = 64

  # Color names of the outline that stands in for a follower whose sprite this game lacks: the
  # look's ally color while its player is in the player's party, its text color otherwise.
  OUTLINE_COLORS = { :member => :ally, :stranger => :text }

  # Whether this game has each graphic another player's game named, by its folder and file, the
  # longest unused first.
  @graphics ||= {}

  # Tells how opaque another player's ghost is drawn: solid for a party member, and for everyone in
  # a Raid World, where every player on the map shares it; see-through a little otherwise.
  #
  # @param member [Boolean] Whether the player is in the player's party.
  # @return [Integer] The opacity.
  def self.ghost_opacity(member)
    member || raid? ? SOLID_OPACITY : STRANGER_OPACITY
  end

  # Reports whether a Raid World is open, through coop_scope.rbx.
  #
  # @return [Boolean] Whether one is.
  def self.raid?
    defined?(MGQ_MpCoop::Scope) && MGQ_MpCoop::Scope.raid? ? true : false
  end

  # Tells what marks a player's party: its size, and whether they lead it.
  #
  # @param player [MGQ_MpOverworldSync::Peers::Peer, Symbol] The player, :me for the player.
  # @return [Array, nil] The size as "2 / 4" and whether they lead, nil outside a party of two or
  #   more.
  def self.party_badge(player)
    return nil unless defined?(MGQ_MpCoop)

    id = player == :me ? MGQ_MpCoop::Party.id : player.state["party"]
    size = MGQ_MpCoop.size_of(id)
    size >= 2 ? ["#{size} / #{MGQ_MpCoop::MAX_PLAYERS}", MGQ_MpCoop.leads?(player)] : nil
  end

  # Writes a party's title for a box, with its size, which the party box and the World overview
  # share.
  #
  # @param badge [Array, nil] The party's size and whether the player leads it, see party_badge.
  # @return [String] Such as "Party 2 / 4", PARTY_TITLE alone without a badge.
  def self.party_title(badge)
    badge ? "#{PARTY_TITLE} #{badge[0]}" : PARTY_TITLE
  end

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "overworld"

  # Writes a ping as it shows, such as "80 ms" or "999+ ms", with the name of the color that says
  # how good it is.
  #
  # @param ping [String, Integer, nil] The milliseconds.
  # @return [Array, nil] The text and its color, nil for no ping.
  def self.ping_label(ping)
    return nil if ping.to_s.empty?

    milliseconds = ping.to_i
    text = "#{[milliseconds, PING_MOST].min}#{milliseconds > PING_MOST ? PING_PAST : ''} ms"
    [text, PING_COLORS.find { |most, _| most.nil? || milliseconds <= most }[1]]
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

  # Loads a graphic another player's game named, see graphic?.
  #
  # @param folder [Symbol] The Cache method of the graphic's folder, such as :character or :face.
  # @param name [String] The file.
  # @return [Bitmap, nil] The graphic, nil while this game lacks it.
  def self.graphic(folder, name)
    graphic?(folder, name) ? Cache.send(folder, name) : nil
  rescue => e
    log_once(:graphic, "loading the #{folder} graphic #{name} failed: #{e.class}: #{e.message}")
    nil
  end

  # Tells whether this game has a graphic another player's game named, such as a hero another mod
  # added there, remembering the files it lacks, so a missing one is neither tried nor logged
  # again every frame.
  #
  # @param folder [Symbol] The Cache method of the graphic's folder, such as :character or :face.
  # @param name [String] The file.
  # @return [Boolean] Whether it has it.
  def self.graphic?(folder, name)
    key = "#{folder}/#{name}"
    known = @graphics.delete(key)
    @graphics.shift while @graphics.size >= MOST_GRAPHICS_KEPT
    @graphics[key] = false
    return false if known == false

    Cache.send(folder, name)
    @graphics[key] = true
  rescue => e
    log("this game has no #{folder} graphic #{name} (#{e.class}: #{e.message}), a stand-in shows instead") if known.nil?
    false
  end

  # Tells which sprite a ghost shows for one its player's game sent: that one, or Luka's of the
  # game's data while this game lacks its file.
  #
  # A missing file raises in the map's sprites every frame, which keeps the ghosts after it and the
  # status line from drawing.
  #
  # @param name [String] The sprite's file.
  # @param index [Integer] The sprite's index in the file.
  # @return [Array] The file and the index to show.
  def self.sprite(name, index)
    graphic?(:character, name) ? [name, index] : stand_in
  end

  # Tells which sprite a ghost's follower shows for one its player's game sent: that one, or the
  # outline alone of Luka's of the game's data while this game lacks its file, so a party member's
  # companions do not show as copies of Luka.
  #
  # @param name [String] The sprite's file.
  # @param index [Integer] The sprite's index in the file.
  # @return [Array] The file and the index to show, and whether only the outline shows.
  def self.follower_sprite(name, index)
    graphic?(:character, name) ? [name, index, false] : stand_in + [true]
  end

  # Tells Luka's sprite as the game's data has it, see read_stand_in.
  #
  # @return [Array] The file and the index.
  def self.stand_in
    @stand_in || ["", 0]
  end

  # Reads Luka's sprite from the game's data file, once as the script loads: a mod may change the
  # actor in the database later, and the file is too large to read mid-frame.
  #
  # @return [Array] The file and the index.
  def self.read_stand_in
    luka = load_data("Data/Actors.rvdata2")[1]
    @stand_in = [luka.character_name.to_s, luka.character_index.to_i]
  rescue => e
    log("reading Luka's sprite failed: #{e.class}: #{e.message}")
    @stand_in = ["", 0]
  end

  # Draws the outline of Luka's sprite once per color: a sheet the size of Luka's, transparent but
  # for the visible pixels on the edge of each of Luka's frames.
  #
  # The outline drawn in an earlier look stays kept, since a follower shown before the look changed
  # still holds it as its bitmap.
  #
  # @param kind [Symbol] The color's key of OUTLINE_COLORS, :member or :stranger.
  # @return [Bitmap, nil] The outline, nil when it cannot be drawn.
  def self.outline(kind)
    @outlines ||= {}
    color = Mod_Framework::UI.color_now(OUTLINE_COLORS.fetch(kind))
    key = [kind, color.red, color.green, color.blue, color.alpha]
    known = @outlines[key]
    return known if known && !known.disposed?

    name, index = stand_in
    sheet = Cache.character(name)
    single = name[/^[\!\$]./].to_s.include?("$")
    width = sheet.width / (single ? 3 : 12)
    height = sheet.height / (single ? 4 : 8)
    left = index % 4 * 3 * width
    top = index / 4 * 4 * height
    outline = Bitmap.new(sheet.width, sheet.height)
    12.times { |frame| outline_frame(sheet, outline, Rect.new(left + frame % 3 * width, top + frame / 3 * height, width, height), color) }
    @outlines[key] = outline
  rescue => e
    log_once([:outline, kind], "drawing the #{kind} outline of Luka's sprite failed: #{e.class}: #{e.message}")
    nil
  end

  # Marks the visible pixels of one frame of a sprite sheet that border a transparent one or the
  # frame's edge.
  #
  # @param sheet [Bitmap] The sprite sheet.
  # @param outline [Bitmap] Where the marks go, the size of the sheet.
  # @param frame [Rect] The frame on the sheet.
  # @param color [Color] The marks' color.
  def self.outline_frame(sheet, outline, frame, color)
    visible = Array.new(frame.height) { |y| Array.new(frame.width) { |x| sheet.get_pixel(frame.x + x, frame.y + y).alpha > 0 } }
    last_x = frame.width - 1
    last_y = frame.height - 1
    visible.each_with_index do |row, y|
      row.each_with_index do |shown, x|
        next unless shown
        next unless x == 0 || y == 0 || x == last_x || y == last_y ||
                    !row[x - 1] || !row[x + 1] || !visible[y - 1][x] || !visible[y + 1][x]

        outline.set_pixel(frame.x + x, frame.y + y, color)
      end
    end
  end

  # Tells the name above a ghost's head: the one the chat tells its player apart by, such as
  # "Name (2)" for the second of two players who share a name, else the name they told.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  # @return [String] The name.
  def self.name_tag(peer)
    MGQ_MpOverworldSync::Peers.label_of(peer) || peer.state["name"].to_s
  end

  # Lists the players whose ghosts are on this map.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.ghosts
    MGQ_MpOverworldSync.in_world? ? MGQ_MpOverworldSync::Peers.all.select { |peer| peer.ghost } : []
  end

  read_stand_in
end

# Another player of the world on this map: it walks where they walk, looks like their party
# leader, and walks through everything without triggering anything. A party member's ghost has the
# followers they show behind it.
class Game_MpGhost < Game_Character
  # The followers behind the ghost.
  #
  # @return [Array<Game_MpGhostFollower>] The followers, none outside the player's party.
  attr_reader :followers

  # Tells whether the ghost's player is in the player's party, as last followed.
  #
  # @return [Boolean] Whether they are.
  attr_reader :member

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
  # little while they are outside the player's party in a Classic world (see
  # MGQ_MpOverworld.ghost_opacity), with their followers while inside it.
  #
  # @param state [Hash] What the player last told.
  # @param member [Boolean] Whether they are in the player's party.
  def follow(state, member)
    @member = member ? true : false
    look_like(state)
    @opacity = MGQ_MpOverworld.ghost_opacity(@member)
    update
    trail(member && defined?(MGQ_MpCoopSquad) ? MGQ_MpCoopSquad.followers_of(state["trail"]) : [])
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
    name = state["sprite"].to_s
    index = state["index"].to_i
    unless name == @sent_name && index == @sent_index
      set_graphic(*MGQ_MpOverworld.sprite(name, index))
      @sent_name = name
      @sent_index = index
    end
    @move_speed = [[state["speed"].to_i, 1].max, 6].min
    @transparent = state["hidden"].to_i == 1
  end
end

# A follower behind a party member's ghost: it steps where the one before it stood, as the game's
# own followers do.
class Game_MpGhostFollower < Game_Character
  # Tells which outline the follower shows in place of its sprite, see
  # MGQ_MpOverworld.follower_sprite.
  #
  # @return [Symbol, nil] The key of MGQ_MpOverworld::OUTLINE_COLORS, nil while it shows its own
  #   sprite.
  attr_reader :outline

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

  # Takes the follower's look and the ghost's speed, opacity and visibility, and the outline's
  # color by whether the ghost's player is in the player's party, which may change any time.
  #
  # @param name [String] The sprite's file.
  # @param index [Integer] The sprite's index in the file.
  # @param ghost [Game_MpGhost] The ghost it follows.
  def look_like(name, index, ghost)
    unless name == @sent_name && index == @sent_index
      shown_name, shown_index, @outlined = MGQ_MpOverworld.follower_sprite(name, index)
      set_graphic(shown_name, shown_index)
      @sent_name = name
      @sent_index = index
    end
    @outline = @outlined ? (ghost.member ? :member : :stranger) : nil
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

# The sprite of a ghost's follower: the game's sprite of a character, or the outline alone of
# Luka's while this game lacks the follower's own.
class Sprite_MpGhostFollower < Sprite_Character
  # Tells whether the follower's look changed, its outline and the outline's color too.
  #
  # @return [Boolean] Whether it did.
  def graphic_changed?
    super || @mgq_mp_outline != @character.outline
  end

  # Takes the follower's sprite as the game does, and the outline in its place while the follower
  # shows only that, which keeps the frames' size, since it is drawn on a sheet the size of Luka's.
  def set_character_bitmap
    super
    @mgq_mp_outline = @character.outline
    outline = @mgq_mp_outline ? MGQ_MpOverworld.outline(@mgq_mp_outline) : nil
    self.bitmap = outline if outline
  end
end

# What MGQ Online shows over the characters on the map and at its bottom left, on the Mod
# Framework's UI layer: the labels over the ghosts, the player's own ping and own line over their
# head, and the world status. The parts that follow a character stack upward by the framework's
# rule and show over a CG.
module MGQ_MpOverworld
  # The Mod Framework's interface.
  UI = Mod_Framework::UI

  # The most characters the line over the player's head keeps its seconds in: half the screen's
  # width at about 9 pixels a character.
  OWN_LINE_CHARS = 36

  # A ghost's label over its head: the line a script gives through overworld_sync.rbx, such as an
  # invite, over the icon of what its player does, a crown for a party leader, the name the chat
  # uses in its player's color (see MGQ_MpPlayerColor), the party's size and the ping. It hides
  # while its player hides.
  class GhostLabel < UI::Component
    # The ghost's player.
    param :peer

    # The ghost the label follows.
    param :ghost

    # Renders it anew once what it shows changed.
    watch(:every => 6) { MGQ_MpOverworld.label_of(peer) }

    # Describes the label.
    def render
      shown = MGQ_MpOverworld.label_of(peer)
      above, icon, crown, name, color, badge, ping = shown
      hud follow: ghost, side: :top, movable: false, mouse: :none, frame: false, shown_in: [Scene_Map, Scene_MenuBase],
          hide_while: -> { peer.state["hidden"].to_i == 1 } do
        text(above[0].to_s, align: :center, color: above[1]) if above
        stack row: true, justify: :center, spacing: 1 do
          text("\\I[#{icon}]", escapes: true) if icon
          text("\\I[#{MGQ_MpOverworld::CROWN_ICON}]", escapes: true) if crown
          text name, color: color
          text(badge, typo: :overline, color: peer.member ? :mgq_online_member : :dim) if badge
          text(ping[0], typo: :overline, color: ping[1]) if ping
        end
      end
    end
  end

  # The player's own ping right over their head, after their party's size and a crown while they
  # lead it, also on the map behind a menu.
  class OwnPing < UI::Component
    # Renders it anew once the ping, the party's size or the lead changed.
    watch(:every => 6) { MGQ_MpOverworld.own_ping }

    # Describes the line.
    def render
      ping, size, crown = MGQ_MpOverworld.own_ping
      hud follow: :player, side: :top, movable: false, mouse: :none, frame: false, shown_in: [Scene_Map, Scene_MenuBase],
          hide_while: -> { MGQ_MpOverworld.own_ping == [nil, nil, nil] } do
        stack row: true, justify: :center, spacing: 1.5 do
          text("\\I[#{MGQ_MpOverworld::CROWN_ICON}]", escapes: true) if crown
          text(size, typo: :overline, color: :mgq_online_member) if size
          text(ping[0], typo: :overline, color: ping[1]) if ping
        end
      end
    end
  end

  # The line over the player's own ping: what the scripts say there, such as an invite to a party,
  # a trade offer or the wait for the party's story (see MGQ_MpActions.own_lines), with its seconds
  # while they fit, cut to half the screen's width, in the own color. Never on the map behind a
  # menu.
  class OwnLine < UI::Component
    # Describes the line.
    def render
      hud follow: :player, side: :top, movable: false, mouse: :none, frame: false, shown_in: [Scene_Map], width: Graphics.width / 2,
          hide_while: -> { MGQ_MpActions.own_lines.nil? } do
        text -> { MGQ_MpOverworld.own_line_text }, align: :center, color: :mgq_online_own
      end
    end
  end

  # The world status at the bottom left of the map, until the player moves it: the connection's
  # problem and the notices of the world, each with its icon before it, wrapped, the newest at the
  # bottom, the oldest going out at the top. Empty while there is nothing to tell, so the player
  # still finds it with Alt.
  class WorldStatus < UI::Component
    # The status's place id, which names its place in the Mod Framework's settings.
    ID = :world_status

    # The status's name while the player arranges the boxes.
    PLACE_NAME = "World status"

    # Rows it shows at most.
    ROWS = 4

    # Its least width.
    MIN_WIDTH = 266

    # Renders it anew once the notices changed.
    watch(:every => 6) { MGQ_MpOverworld.status_lines }

    # Describes the status.
    def render
      hud id: ID, place_name: PLACE_NAME, anchor: :bottom_left, shown_in: [Scene_Map], mouse: :none, frame: false, resizable: :width,
          min_size: [MIN_WIDTH, 0], hide_while: -> { !MGQ_MpOverworldSync.in_world? } do
        stack tail: true, spacing: 0.5 do
          MGQ_MpOverworld.status_lines.each_with_index do |(text, icon), index|
            stack row: true, spacing: 1, key: index do
              text("\\I[#{icon}]", escapes: true) if icon
              text text.to_s, wrap: true, grow: 1
            end
          end
        end
      end
    end
  end

  # Tells what a ghost's label shows: the line above, the icon of what its player does, whether
  # they lead their party, their name and its color, the party's size and the ping.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  # @return [Array] The label's parts, the same object while they stay.
  def self.label_of(peer)
    state = peer.state
    badge = party_badge(peer)
    shown = [MGQ_MpOverworldSync.label_line_of(peer), STATE_ICONS[state["scene"]], badge && badge[1] ? true : false, name_tag(peer),
             MGQ_MpPlayerColor.role(peer), badge && badge[0], ping_label(state["ping"])]
    @labels ||= {}
    kept = @labels[peer]
    kept == shown ? kept : (@labels[peer] = shown)
  end

  # Tells what the player's own ping shows: the ping, the party's size and whether they lead it.
  #
  # @return [Array] The ping (text and color), the size and the crown, each nil for none; the same
  #   object while they stay.
  def self.own_ping
    in_world = MGQ_MpOverworldSync.in_world?
    ping = in_world ? ping_label(MGQ_MpOverworldSync::Ping.measured) : nil
    badge = in_world ? party_badge(:me) : nil
    shown = [ping, badge && badge[0], badge && badge[1] ? true : nil]
    @own_ping = shown unless @own_ping == shown
    @own_ping
  end

  # Tells what the line over the player's head says: with the seconds while that fits half the
  # screen's width, else without them, so a cut only ever loses the end of a text, never a
  # countdown that fits.
  #
  # @return [String] The line, "" for none.
  def self.own_line_text
    lines = MGQ_MpActions.own_lines
    return "" unless lines

    lines[0].size <= OWN_LINE_CHARS ? lines[0] : lines[1]
  end

  # Tells the world status's lines.
  #
  # @return [Array<Array>] Each line's text and icon, the newest last, at most WorldStatus::ROWS;
  #   the same object while they stay.
  def self.status_lines
    lines = MGQ_MpOverworldSync::Status.shown.last(WorldStatus::ROWS)
    @status_lines = lines unless @status_lines == lines
    @status_lines
  end

  # Shows the labels of the ghosts on the player's map and takes those of the others away, and
  # keeps the player's own ping, own line and world status shown. Called by the map's sprites
  # every frame.
  #
  # @param hud [Boolean] Whether the map shows the mod's HUD, not behind a menu.
  def self.keep_labels(hud)
    peers = ghosts
    MGQ_MpShown.keys_of(:ghost_label).each do |key|
      MGQ_MpShown.drop(key) unless peers.any? { |peer| peer.ghost.equal?(key[1]) }
    end
    peers.each { |peer| MGQ_MpShown.keep([:ghost_label, peer.ghost], GhostLabel, peer: peer, ghost: peer.ghost) }
    (@labels || {}).delete_if { |peer, _| !peers.include?(peer) }
    MGQ_MpShown.keep(:own_ping, OwnPing)
    return unless hud

    MGQ_MpShown.keep(:own_line, OwnLine)
    MGQ_MpShown.keep(WorldStatus::ID, WorldStatus)
  end
end

# Game hooks, through core_hooks.rbx.

begin
  MGQ_MpHooks.after(Game_Map, :update, "overworld") { MGQ_MpOverworld.update_ghosts }

  # After the map's sprites, a sprite per ghost on this map and per ghost's follower, the labels over
  # the ghosts and the player's own ping and, unless the map shows behind a menu, the line over it
  # and the world status.
  MGQ_MpHooks.after(Spriteset_Map, :update, "overworld") do
    @mgq_mp_ghosts ||= {}
    @mgq_mp_followers ||= {}
    viewport = MGQ_MpGame.get(self, :viewport1)
    begin
      MGQ_MpOverworld.keep_labels(mgq_mp_hud?)
    rescue => e
      MGQ_MpOverworld.log_once(:labels, "showing the labels, the lines over the player or the world status failed: #{e.class}: #{e.message}")
    end
    peers = MGQ_MpOverworld.ghosts

    @mgq_mp_ghosts.keys.each do |ghost|
      @mgq_mp_ghosts.delete(ghost).dispose unless peers.any? { |peer| peer.ghost.equal?(ghost) }
    end

    followers = peers.map { |peer| peer.ghost.followers }.flatten
    @mgq_mp_followers.keys.each do |follower|
      @mgq_mp_followers.delete(follower).dispose unless followers.any? { |shown| shown.equal?(follower) }
    end

    # Followers first, so a ghost's sprite draws over its followers on the same tile.
    followers.each do |follower|
      (@mgq_mp_followers[follower] ||= Sprite_MpGhostFollower.new(viewport, follower)).update
    end

    peers.each { |peer| (@mgq_mp_ghosts[peer.ghost] ||= Sprite_Character.new(viewport, peer.ghost)).update }
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "overworld") do
    (@mgq_mp_ghosts || {}).each_value { |sprite| sprite.dispose }
    (@mgq_mp_followers || {}).each_value { |sprite| sprite.dispose }
    @mgq_mp_ghosts = @mgq_mp_followers = nil
  end
rescue => e
  MGQ_MpOverworld.log("hooks FAILED: #{e.class}: #{e.message}")
end
