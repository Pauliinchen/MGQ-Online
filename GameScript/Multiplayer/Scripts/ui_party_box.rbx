#----------------------------------------------------------------
#  ui_party_box.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Made the box a map box in a Raid World: everyone on the map, the party first in green, each with their Frontline's level and ping, as many as fit and how many more
#      Paulinchen  2026-10-07: Took the icon rect, white and the depth from MGQ_MpUi, and measured places with the box's picture
#                            - Logged the box's size changes, a size key that does nothing and why, and who the box lists whenever that changes
#      Paulinchen  2026-10-06: Logged a box that fails to draw under the party box's own tag
#      Paulinchen  2026-10-04: Made the box small with its key, only names and pings, and kept the choice in Player.ini
#                            - Created
#
#----------------------------------------------------------------

# The party box's size: its key (Tab unless the player binds another, see core_hotkeys.rbx) makes
# it small, with only each player's name and ping, and full again. The choice holds in every world,
# and for the map box that replaces the party box in a Raid World.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpPartyBox
  # The setting in Player.ini that keeps the box small.
  SMALL_SETTING = "party_box_small"

  # Most lines of players the map box shows; past them its last line says how many more there are.
  MAP_LINES = 10

  @names = []

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "party box"

  # Reports whether the box shows small, as the player last chose.
  #
  # @return [Boolean] Whether it does.
  def self.small?
    @small = MGQ_Multiplayer::Player.setting(SMALL_SETTING).to_s == "1" if @small.nil?
    @small
  end

  # Makes the box small or full, keeping the choice in Player.ini.
  def self.toggle
    @small = !small?
    MGQ_Multiplayer::Player.store(SMALL_SETTING, @small ? 1 : 0)
    log("party box made #{@small ? 'small: names and pings only' : 'full'}")
    Sound.play_cursor
  end

  # Changes the box's size with its key, on the map of a world with no screen of the mod over it.
  # Called by the map every frame, so a press of the key is seen once.
  def self.on_map
    pressed = MGQ_MpHotkeys.pressed?(:party_box)
    return unless pressed

    reason = busy_reason
    return log("party box size key ignored: #{reason}") if reason

    toggle
  rescue => e
    log("changing the box's size failed: #{e.class}: #{e.message}")
  end

  # Tells why the box's key does nothing now.
  #
  # @return [String, nil] The first reason that holds, nil when the key may change the box.
  def self.busy_reason
    return "no world is open" unless MGQ_MpOverworldSync.in_world?
    if map_box?
      return "nobody else is on the map" if MGQ_MpCoop::Scope.peers_here.empty?
    else
      return "the player is in no party" unless MGQ_MpCoop.in_party?
    end
    return "the chat box is open" if MGQ_MpChat.typing?
    return "the action wheel is open" if MGQ_MpActions::Wheel.open?
    return "the emote wheel is open" if MGQ_MpEmotes.open?

    MGQ_MpWorldOverview.open? ? "the World overview is open" : nil
  end

  # Reports whether the box lists everyone on the map instead of the party: in a Raid World.
  #
  # @return [Boolean] Whether it does.
  def self.map_box?
    MGQ_MpCoop::Scope.raid?
  end

  # Splits the map box's players into those it lists and how many more there are, so the box
  # never grows past MAP_LINES lines. The player's own line always stays, in place of the last
  # listed one when it sorts past them.
  #
  # @param rows [Array<MGQ_MpWorldOverview::Row>] The players.
  # @return [Array] The players listed, and how many more there are, 0 when all fit.
  def self.capped(rows)
    return [rows, 0] if rows.size <= MAP_LINES

    shown = rows.first(MAP_LINES - 1)
    own = rows.find { |row| row.player == :me }
    shown[-1] = own if own && shown.none? { |row| row.player == :me }
    [shown, rows.size - MAP_LINES + 1]
  end

  # Logs who the box lists whenever that changes: the names in their order, the leader marked.
  #
  # @param rows [Array<MGQ_MpWorldOverview::Row>] The players, none while the box is hidden.
  # @param map [Boolean] Whether it is the map box.
  def self.note_rows(rows, map = false)
    box = map ? "map box" : "party box"
    names = [box] + rows.map { |row| "#{row.name}#{row.badge && row.badge[1] ? ' (leader)' : ''}" }
    return if names == @names

    log(names.size == 1 ? "#{box} hidden" : "#{box} lists #{names[1..-1].join(', ')}")
    @names = names
  rescue
  end
end

# The box at the top right of the map that lists the player's party: the leader first with a crown,
# then the others by name, each with their highest companion level and ping, and where they are on
# a smaller line below. Small, it lists only each player's name and ping.
#
# In a Raid World it is the map box instead: everyone on the player's map, the party's members
# first and green, the others white, each with their Frontline's highest level and ping, and no
# place, since all share the player's.
class Sprite_MpPartyBox < Sprite
  # Width of the box.
  WIDTH = 230

  # Width of the small box.
  SMALL_WIDTH = 150

  # Height of one line.
  ROW = 22

  # Height of the line with where a player is.
  PLACE_ROW = 16

  # Height of one player: their line and where they are.
  PLAYER_ROW = ROW + PLACE_ROW

  # Room between the box and the top and right edges of the screen.
  MARGIN = 8

  # Left edge of each column: the crown, the name and the level, and the ping's right edge.
  COLUMNS = { :crown => 4, :name => 26, :level => 146, :ping_right => WIDTH - 6 }

  # Background of the box, the chat box's.
  BACK = Color.new(0, 0, 0, 140)

  # Frames between two readings of the party, a quarter of a second.
  READ_FRAMES = 15

  # Creates the box, hidden.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, [ROW + PLAYER_ROW * MGQ_MpCoop::MAX_PLAYERS, ROW + ROW * MGQ_MpPartyBox::MAP_LINES].max + 4)
    self.x = Graphics.width - WIDTH - MARGIN
    self.z = MGQ_MpUi::Z[:labels]
    self.visible = false
    @shown = nil
    @frames = 0
    @overview = nil
  end

  # Draws the party while the player is in one, or in a Raid World everyone on the map while
  # someone else is on it, and the World overview is closed, if it changed. Reads the players every
  # READ_FRAMES, and at once when the overview opens or closes.
  def update
    super
    overview = MGQ_MpWorldOverview.open?
    @frames -= 1
    return if @frames > 0 && overview == @overview

    @frames = READ_FRAMES
    @overview = overview
    map = MGQ_MpPartyBox.map_box?
    rows = overview ? [] : map ? MGQ_MpWorldOverview.map_rows : MGQ_MpWorldOverview.party_rows
    MGQ_MpPartyBox.note_rows(rows, map) unless overview
    self.visible = !rows.empty?
    return unless visible

    small = MGQ_MpPartyBox.small?
    drawn = [small, map] + rows.map { |row| [row.name, row.level, row.ping && row.ping[0], row.badge, row.place, row.member] }
    return if drawn == @shown

    @shown = drawn
    if small
      draw_small(rows, map)
    else
      map ? draw_map(rows) : draw(rows)
    end
  rescue => e
    MGQ_MpPartyBox.log_once(:draw, "drawing the party box failed: #{e.class}: #{e.message}")
  end

  # Draws the box, as tall as the party needs, in the top right corner.
  #
  # @param rows [Array<MGQ_MpWorldOverview::Row>] The party, see MGQ_MpWorldOverview.party_rows.
  def draw(rows)
    height = ROW + PLAYER_ROW * rows.size + 4
    self.x = Graphics.width - WIDTH - MARGIN
    self.y = MARGIN
    bitmap.clear
    bitmap.fill_rect(0, 0, WIDTH, height, BACK)
    bitmap.font.outline = true
    bitmap.font.size = 16
    bitmap.font.color = Sprite_MpWorldOverview::MEMBER_COLOR
    badge = MGQ_MpOverworld.party_badge(:me)
    bitmap.draw_text(6, 2, WIDTH - 12, ROW, badge ? "Party #{badge[0]}" : "Party")
    rows.each_with_index { |row, index| draw_row(row, ROW + PLAYER_ROW * index + 2) }
  end

  # Draws the map box, as tall as its players need up to MGQ_MpPartyBox::MAP_LINES, in the top right
  # corner: how many are on the map, then a line per player with no place below.
  #
  # @param rows [Array<MGQ_MpWorldOverview::Row>] The players, see MGQ_MpWorldOverview.map_rows.
  def draw_map(rows)
    shown, more = MGQ_MpPartyBox.capped(rows)
    lines = shown.size + (more > 0 ? 1 : 0)
    self.x = Graphics.width - WIDTH - MARGIN
    self.y = MARGIN
    bitmap.clear
    bitmap.fill_rect(0, 0, WIDTH, ROW + ROW * lines + 4, BACK)
    bitmap.font.outline = true
    bitmap.font.size = 16
    bitmap.font.color = MGQ_MpUi::WHITE
    bitmap.draw_text(6, 2, WIDTH - 12, ROW, "Map #{rows.size}")
    shown.each_with_index { |row, index| draw_line(row, ROW * (index + 1) + 2, name_color(row, true)) }
    draw_more(more, ROW * (shown.size + 1) + 2, WIDTH) if more > 0
  end

  # Draws the small box: a row per player with the crown, the name and the ping, and no title.
  #
  # @param rows [Array<MGQ_MpWorldOverview::Row>] The players, see MGQ_MpWorldOverview.party_rows
  #   and map_rows.
  # @param map [Boolean] Whether it is the map box, which lists only as many as fit.
  def draw_small(rows, map = false)
    shown, more = map ? MGQ_MpPartyBox.capped(rows) : [rows, 0]
    self.x = Graphics.width - SMALL_WIDTH - MARGIN
    self.y = MARGIN
    bitmap.clear
    bitmap.fill_rect(0, 0, SMALL_WIDTH, ROW * (shown.size + (more > 0 ? 1 : 0)) + 4, BACK)
    bitmap.font.outline = true
    bitmap.font.size = 16
    shown.each_with_index do |row, index|
      y = ROW * index + 2
      draw_crown(y) if row.badge && row.badge[1]
      bitmap.font.color = name_color(row, map)
      bitmap.draw_text(COLUMNS[:name], y, SMALL_WIDTH - COLUMNS[:name] - 50, ROW, row.name)
      next unless row.ping

      bitmap.font.color = row.ping[1]
      bitmap.draw_text(SMALL_WIDTH - 54, y, 48, ROW, row.ping[0], 2)
    end
    draw_more(more, ROW * shown.size + 2, SMALL_WIDTH) if more > 0
  end

  # Picks the color of a player's name: the party box's are all green, the map box's only for the
  # party's members.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @param map [Boolean] Whether it is the map box.
  # @return [Color] The color.
  def name_color(row, map)
    !map || row.member ? Sprite_MpWorldOverview::MEMBER_COLOR : MGQ_MpUi::WHITE
  end

  # Draws the line that says how many more players are on the map than the box lists.
  #
  # @param count [Integer] How many more.
  # @param y [Integer] The line's top.
  # @param width [Integer] The box's width.
  def draw_more(count, y, width)
    bitmap.font.color = Sprite_MpWorldOverview::GREY
    bitmap.draw_text(COLUMNS[:name], y, width - COLUMNS[:name] - 6, ROW, "+#{count} more")
  end

  # Draws the leader's crown before a name.
  #
  # @param y [Integer] The row's top.
  def draw_crown(y)
    icon = MGQ_MpOverworld::CROWN_ICON
    bitmap.stretch_blt(Rect.new(COLUMNS[:crown], y + 1, ROW - 2, ROW - 2), Cache.system("Iconset"), MGQ_MpUi.icon_rect(icon))
  end

  # Draws one player of the party, with where they are below.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @param y [Integer] The player's top.
  def draw_row(row, y)
    draw_line(row, y, Sprite_MpWorldOverview::MEMBER_COLOR)
    draw_place(row.place, y + ROW - 3)
  end

  # Draws a player's line: the crown, the name, the level and the ping.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @param y [Integer] The line's top.
  # @param color [Color] The name's color.
  def draw_line(row, y, color)
    draw_crown(y) if row.badge && row.badge[1]
    bitmap.font.color = color
    bitmap.draw_text(COLUMNS[:name], y, COLUMNS[:level] - COLUMNS[:name] - 4, ROW, row.name)
    bitmap.font.color = MGQ_MpUi::WHITE
    bitmap.draw_text(COLUMNS[:level], y, 44, ROW, row.level)
    return unless row.ping

    bitmap.font.color = row.ping[1]
    bitmap.draw_text(COLUMNS[:ping_right] - 56, y, 56, ROW, row.ping[0], 2)
  end

  # Draws where a player is, under their name, shortened to fit the box.
  #
  # @param place [String] Where they are.
  # @param y [Integer] The line's top.
  def draw_place(place, y)
    width = WIDTH - COLUMNS[:name] - 6
    bitmap.font.size = 14
    bitmap.font.color = Sprite_MpWorldOverview::PLACE_COLOR
    text = MGQ_MpWorldOverview.fit_place(place, width, bitmap)
    bitmap.draw_text(COLUMNS[:name], y, width, PLACE_ROW, text)
    bitmap.font.size = 16
  end

  # Frees the box's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the box's key. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_party_box") { MGQ_MpPartyBox.on_map unless scene_changing? }

  # After the map's sprites, the party's box.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_party_box") { (@mgq_mp_party_box ||= Sprite_MpPartyBox.new(@viewport3)).update }

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_party_box") do
    @mgq_mp_party_box.dispose if @mgq_mp_party_box
    @mgq_mp_party_box = nil
  end
rescue => e
  MGQ_MpPartyBox.log("hooks FAILED: #{e.class}: #{e.message}")
end
