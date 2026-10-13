#----------------------------------------------------------------
#  ui_party_box.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Read the map's viewport through MGQ_MpGame
#      Paulinchen  2026-10-11: Listed a Raid World's party in the box with the other players on the map below it
#                            - Made the box movable and widenable with the left Alt held
#                            - Framed the box in the preset's colors
#                            - Drew the box in the shared style with fades and named its size hotkey in its title
#                            - Kept the level and the ping apart in their own columns and cut a long name to its column
#                            - Left placing the box to its motion
#                            - Drew the icon of what each player does before their name
#                            - Named each line in its player's color through MGQ_MpUi::PlayerColor
#                            - Marked a member whose connection is down
#                            - Logged each listed player's color and whether they are away
#                            - Capped the map box's lines through MGQ_MpUi.capped, keeping the player's own line
#      Paulinchen  2026-10-10: Moved the box below a strip of the mod at the top of the screen
#      Paulinchen  2026-10-08: Made the box a map box in a Raid World
#      Paulinchen  2026-10-07: Took the icon rect, white and the depth from MGQ_MpUi, and measured places with the box's picture
#                            - Logged the box's size changes, refused size hotkeys and who the box lists
#      Paulinchen  2026-10-06: Logged a box that fails to draw under the party box's own tag
#      Paulinchen  2026-10-04: Made the box small with its hotkey and kept the choice in Player.ini
#                            - Created
#
#----------------------------------------------------------------

# The party box's size: its hotkey (Tab unless the player binds another, see core_hotkeys.rbx) makes
# it small, with only each player's icon, name and ping, and full again. The choice holds in every
# world, and for the map box that replaces the party box in a Raid World.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpPartyBox
  # The setting in Player.ini that keeps the box small.
  SMALL_SETTING = "party_box_small"

  # Most lines of players the map box shows; past them its last line says how many more there are.
  MAP_LINES = 10

  # Icon of the game's icon set before the name of a member whose connection is down: the one a
  # player away from their game shows above their head.
  AWAY_ICON = MGQ_MpOverworld::STATE_ICONS["away"]

  # What the log calls the color of a member whose connection is down.
  AWAY_LABEL = "dim, away"

  # What the log calls a party's leader.
  LEADER_LABEL = "leader"

  # The box's kind and the players it listed when last logged, see note_rows.
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

  # Changes the box's size with its hotkey, on the map of a world with no screen of the mod over
  # it. Called by the map every frame, so a press of the hotkey is seen once.
  def self.on_map
    pressed = MGQ_MpHotkeys.pressed?(:party_box)
    return unless pressed

    reason = busy_reason
    return MGQ_MpHotkeys.log_refusal(:party_box, reason) if reason

    toggle
  rescue => e
    log("changing the box's size failed: #{e.class}: #{e.message}")
  end

  # Tells why the box's hotkey does nothing now.
  #
  # @return [String, nil] The first reason that holds, nil when the hotkey may change the box.
  def self.busy_reason
    return "no world is open" unless MGQ_MpOverworldSync.in_world?
    if map_box?
      return "nobody else is on the map" if MGQ_MpCoop::Scope.peers_here.empty? && !MGQ_MpCoop.in_party?
    else
      return "the player is in no party" unless MGQ_MpCoop.in_party?
    end
    return "the chat box is open" if MGQ_MpChat.typing?
    return "the action wheel is open" if MGQ_MpActions::Wheel.open?
    return "the emote wheel is open" if MGQ_MpEmotes.open?

    MGQ_MpWorldOverview.open? ? "the World overview is open" : nil
  end

  # Splits the players the box lists into the party and the others on the map: in a Classic world
  # the party alone; in a Raid World the party wherever its members are (as raid_party_rows), then
  # the players on the map outside it, or outside a party everyone on the map (as map_rows).
  #
  # @return [Array(Array, Array)] The party's rows and the others', each empty while there are none.
  def self.sections
    overview = MGQ_MpWorldOverview
    return [overview.party_rows, []] unless map_box?

    party = overview.raid_party_rows
    others = overview.map_rows
    return [[], others] if party.empty?

    [party, others.reject { |row| row.member || row.player == :me }]
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
    shown, more = MGQ_MpUi.capped(rows, MAP_LINES)
    own = rows.find { |row| row.player == :me }
    shown[-1] = own if own && more > 0 && shown.none? { |row| row.player == :me }
    [shown, more]
  end

  # Logs who the box lists whenever that changes: the names in their order, each with whether
  # they lead the party and the color they are named in, such as "<Player> (leader, member)".
  #
  # @param rows [Array<MGQ_MpWorldOverview::Row>] The players, none while the box is hidden.
  # @param map [Boolean] Whether it is the map box.
  def self.note_rows(rows, map = false)
    box = map ? "map box" : "party box"
    names = [box] + rows.map { |row| "#{row.name} (#{[row.badge && row.badge[1] ? LEADER_LABEL : nil, color_label(row)].compact.join(', ')})" }
    return if names == @names

    log(names.size == 1 ? "#{box} hidden" : "#{box} lists #{names[1..-1].join(', ')}")
    @names = names
  rescue
  end

  # Reports whether a listed player's connection is down, which the box marks; the player's own
  # line never is.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @return [Boolean] Whether it is.
  def self.away?(row)
    peer = row.player
    peer.respond_to?(:away) && !peer.away.nil? ? true : false
  end

  # Picks the color of a player's name in the box: MGQ_MpUi::Style::DIM while their connection is
  # down, else the one MGQ_MpUi::PlayerColor gives: the player's own, a party member's, and in the
  # map box plain text for anyone else.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @return [Color] The color.
  def self.color_of(row)
    away?(row) ? MGQ_MpUi::Style::DIM : MGQ_MpUi::PlayerColor.of(row.player, row.member)
  end

  # Names the color of a player's name for the log, see color_of.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @return [String] The name: "own", "member", "plain" or AWAY_LABEL.
  def self.color_label(row)
    away?(row) ? AWAY_LABEL : MGQ_MpUi::PlayerColor.label(row.player, row.member)
  end
end

# The box at the top right of the map, until the player moves it, that lists the player's party:
# the leader first with a crown, then the others by name, each with the icon of what they do, their
# formation's highest level and ping, and where they are on a smaller line below. The player's own
# line, a party member's and anyone else's are named in the colors MGQ_MpUi::PlayerColor gives, a
# member whose connection is down dim with the away icon. Small, it lists only each player's icon,
# name and ping, at the right edge of the box's place. The title names the hotkey that changes the
# size at its right. Drawn in the shared style, the box fades in and out. A wider box gives the
# names, the levels and the places more room; its height follows the players.
#
# In a Raid World the party's members show with their Frontline's highest level, and the other
# players on the player's map follow below the party under the map's title, a line each. Outside a
# party it is the map box instead: everyone on the player's map, the party's members first, each
# with their Frontline's highest level and ping, and no place, since all share the player's.
class Sprite_MpPartyBox < Sprite
  # The box's id in the layout, which names its setting in Player.ini; the map box shares it.
  LAYOUT = :party_box

  # The box's name while the player arranges the boxes.
  LAYOUT_NAME = "Party box"

  # Height of one line.
  ROW = 22

  # Height of the line with where a player is.
  PLACE_ROW = 16

  # Height of one player: their line and where they are.
  PLAYER_ROW = ROW + PLACE_ROW

  # Room between the box and the top and right edges of the screen at its default, below a strip
  # of the mod at the top (see MGQ_MpUi.top_room).
  MARGIN = 8

  # Room between the box's side edges and its columns.
  EDGE = 6

  # Room above the first line and below the last, inside the box's frame.
  SPACING = 2

  # Side of the crown and the state icon, which fit a line.
  ICON_SIDE = ROW - 2

  # Width of the level column, which "Lv 100" fits.
  LEVEL_WIDTH = 52

  # Left edge of each column at the box's default width: the crown, the state icon, the name the
  # style's gap after the icon, and the level. The name runs up to the level less the gap, 116
  # pixels, about 14 letters of the small font; the ping lies right of the level, see ping_left.
  # In a wider box the level keeps its distance to the right edge, see level_left.
  COLUMNS = { :crown => 4, :icon => 26, :name => 50, :level => 170 }

  # Width of the box at its default, and the least: the columns up to the level, the level, the
  # ping (MGQ_MpOverworld::PING_WIDTH, which "999+ ms" fits) and the edge, so the level and the ping
  # never meet.
  WIDTH = COLUMNS[:level] + LEVEL_WIDTH + MGQ_MpUi::Style::GAP + MGQ_MpOverworld::PING_WIDTH + EDGE

  # Width of the small box, which has no level column: what lies between the name and the ping
  # is the name's, 74 pixels.
  SMALL_WIDTH = 198

  # Least height of the box: one line.
  MIN_HEIGHT = ROW + 2 * SPACING

  # Frames between two readings of the party, a quarter of a second.
  READ_FRAMES = 15

  # What the title says at its right, with the hotkey that changes the box's size.
  SIZE_HINT = "%s: size"

  # Creates the box, hidden.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    @width = WIDTH
    @height = 0
    @small = false
    fit_bitmap(WIDTH)
    rect = layout_rect
    self.x = @left = rect.x
    self.y = rect.y
    self.z = MGQ_MpUi::Z[:labels]
    @motion = MGQ_MpUi::Motion.new(self)
    @shown = nil
    @frames = 0
    @overview = nil
  end

  # Reads the players every READ_FRAMES, at once when the World overview opens or closes, and
  # when the box's width changes, and moves the fade a frame on, the box where the layout puts it.
  def update
    super
    overview = MGQ_MpWorldOverview.open?
    width = layout_rect.width
    @frames -= 1
    refresh(overview, width) if @frames <= 0 || overview != @overview || width != @width
    rect = layout_rect
    @left = left_of(rect)
    @motion.place(@left, rect.y)
    @motion.update
    MGQ_MpUi::Layout.offer(LAYOUT, rect.x, rect.y, rect.width, @height, z) if @motion.shown?
  rescue => e
    MGQ_MpPartyBox.log_once(:draw, "drawing the party box failed: #{e.class}: #{e.message}")
  end

  # Tells where the box draws: where the player left it, else at the top right below a strip of
  # the mod, as tall as it was last drawn.
  #
  # @return [Rect] The place, see MGQ_MpUi::Layout.rect.
  def layout_rect
    default = Rect.new(Graphics.width - WIDTH - MARGIN, MARGIN + MGQ_MpUi.top_room, WIDTH, @height.to_i)
    MGQ_MpUi::Layout.rect(LAYOUT, default)
  end

  # Tells where the box's picture starts on the screen: at the place's left, or SMALL_WIDTH before
  # its right edge for the small box.
  #
  # @param rect [Rect] The box's place, see layout_rect.
  # @return [Integer] The left.
  def left_of(rect)
    @small ? rect.x + rect.width - SMALL_WIDTH : rect.x
  end

  # Tells how wide the full box draws: as the layout last said, WIDTH before.
  #
  # @return [Integer] The width.
  def box_width
    @width || WIDTH
  end

  # Sizes the picture to a width, as tall as the most players or lines the box lists, making it
  # anew once the width changed.
  #
  # @param width [Integer] The box's width.
  def fit_bitmap(width)
    return if bitmap && !bitmap.disposed? && bitmap.width == width

    bitmap.dispose if bitmap && !bitmap.disposed?
    self.bitmap = Bitmap.new(width, ROW + PLAYER_ROW * MGQ_MpCoop::MAX_PLAYERS + ROW + ROW * MGQ_MpPartyBox::MAP_LINES + 2 * SPACING)
  end

  # Reads the players, see MGQ_MpPartyBox.sections, and draws them if they, the width or the preset
  # changed, fading the box in; fades it out while the World overview is open or there is nobody
  # to list, keeping its picture until it is gone.
  #
  # @param overview [Boolean] Whether the World overview is open.
  # @param width [Integer] The box's width, see layout_rect.
  def refresh(overview, width = box_width)
    @frames = READ_FRAMES
    @overview = overview
    @width = width
    party, others = overview ? [[], []] : MGQ_MpPartyBox.sections
    map = party.empty?
    rows = party + others
    MGQ_MpPartyBox.note_rows(rows, map && MGQ_MpPartyBox.map_box?) unless overview
    return @motion.hide if rows.empty?

    @motion.show
    small = MGQ_MpPartyBox.small?
    drawn = [small, party.size, width, MGQ_MpUi::Theme.serial] +
            rows.map { |row| [row.name, row.level, row.ping && row.ping[0], row.badge, row.place, row.member, row.icon, MGQ_MpPartyBox.away?(row)] }
    return if drawn == @shown

    @shown = drawn
    fit_bitmap(width)
    if small
      draw_small(party, others)
    else
      map ? draw_map(others) : draw(party, others)
    end
  end

  # Draws the box, as wide as the layout says and as tall as the party needs, and in a Raid World
  # the others on the map below it under the map's title, a line each, up to
  # MGQ_MpPartyBox::MAP_LINES.
  #
  # @param rows [Array<MGQ_MpWorldOverview::Row>] The party, see MGQ_MpPartyBox.sections.
  # @param others [Array<MGQ_MpWorldOverview::Row>] The others on the map, see MGQ_MpPartyBox.sections.
  def draw(rows, others = [])
    width = box_width
    shown, more = MGQ_MpPartyBox.capped(others)
    party_height = ROW + PLAYER_ROW * rows.size + SPACING
    map_height = others.empty? ? 0 : ROW * (1 + shown.size + (more > 0 ? 1 : 0))
    start(width, party_height + map_height + SPACING, false)
    draw_title(MGQ_MpOverworld.party_title(MGQ_MpOverworld.party_badge(:me)), MGQ_MpUi::Style::MEMBER, width)
    rows.each_with_index { |row, index| draw_row(row, ROW + PLAYER_ROW * index + SPACING, width) }
    return if others.empty?

    draw_heading("Map #{others.size}", party_height, width)
    shown.each_with_index { |row, index| draw_line(row, party_height + ROW * (index + 1), width) }
    draw_more(more, party_height + ROW * (shown.size + 1), width) if more > 0
  end

  # Draws the title of the others on the map below the party, without the size hint.
  #
  # @param title [String] The title.
  # @param y [Integer] The line's top.
  # @param width [Integer] The box's width.
  def draw_heading(title, y, width)
    MGQ_MpUi::Style.use_font(bitmap, MGQ_MpUi::Style::SMALL_SIZE, MGQ_MpUi::Style::TEXT)
    bitmap.draw_text(EDGE, y, width - 2 * EDGE, ROW, MGQ_MpUi.cut(bitmap, title, width - 2 * EDGE))
  end

  # Draws the map box, as wide as the layout says and as tall as its players need up to
  # MGQ_MpPartyBox::MAP_LINES: how many are on the map, then a line per player with no place below.
  #
  # @param rows [Array<MGQ_MpWorldOverview::Row>] The players, see MGQ_MpWorldOverview.map_rows.
  def draw_map(rows)
    shown, more = MGQ_MpPartyBox.capped(rows)
    lines = shown.size + (more > 0 ? 1 : 0)
    width = box_width
    start(width, ROW + ROW * lines + 2 * SPACING, false)
    draw_title("Map #{rows.size}", MGQ_MpUi::Style::TEXT, width)
    shown.each_with_index { |row, index| draw_line(row, ROW * (index + 1) + SPACING, width) }
    draw_more(more, ROW * (shown.size + 1) + SPACING, width) if more > 0
  end

  # Draws the small box, SMALL_WIDTH wide at the right edge of the box's place: a row per player
  # with the crown, the icon, the name and the ping, and no title; the party first, then as many of
  # the others on the map as fit.
  #
  # @param party [Array<MGQ_MpWorldOverview::Row>] The party, see MGQ_MpPartyBox.sections.
  # @param others [Array<MGQ_MpWorldOverview::Row>] The others on the map, or everyone on it
  #   outside a party, see MGQ_MpPartyBox.sections.
  def draw_small(party, others = [])
    listed, more = MGQ_MpPartyBox.capped(others)
    shown = party + listed
    start(SMALL_WIDTH, ROW * (shown.size + (more > 0 ? 1 : 0)) + 2 * SPACING, true)
    shown.each_with_index { |row, index| draw_line(row, ROW * index + SPACING, SMALL_WIDTH, false) }
    draw_more(more, ROW * shown.size + SPACING, SMALL_WIDTH) if more > 0
  end

  # Starts a drawing: keeps the box's height and whether it is small, places its left, clears the
  # picture and draws the framed box.
  #
  # @param width [Integer] The box's width.
  # @param height [Integer] The box's height.
  # @param small [Boolean] Whether it is the small box.
  def start(width, height, small)
    @height = height
    @small = small
    @left = left_of(layout_rect)
    bitmap.clear
    MGQ_MpUi::Style.draw_box(bitmap, 0, 0, width, height)
  end

  # Draws the title line of the full box: the title at the left, cut to the room before the hint,
  # and at the right the hotkey that changes the box's size.
  #
  # @param title [String] The title.
  # @param color [Color] The title's color.
  # @param width [Integer] The box's width.
  def draw_title(title, color, width = box_width)
    style = MGQ_MpUi::Style
    hint = SIZE_HINT % MGQ_MpHotkeys.label(:party_box)
    style.use_font(bitmap, style::SMALL_SIZE, color)
    room = width - 2 * EDGE - bitmap.text_size(hint).width - style::GAP
    bitmap.draw_text(EDGE, SPACING, room, ROW, MGQ_MpUi.cut(bitmap, title, room))
    style.use_font(bitmap, style::SMALL_SIZE, style::DIM)
    bitmap.draw_text(EDGE, SPACING, width - 2 * EDGE, ROW, hint, 2)
  end

  # Tells where the ping column starts in a box: MGQ_MpOverworld::PING_WIDTH before its right edge.
  #
  # @param width [Integer] The box's width.
  # @return [Integer] The column's left.
  def ping_left(width)
    width - EDGE - MGQ_MpOverworld::PING_WIDTH
  end

  # Tells where the level column starts in a box: as far from its right edge as at WIDTH, so a
  # wider box gives the extra room to the name.
  #
  # @param width [Integer] The box's width.
  # @return [Integer] The column's left.
  def level_left(width)
    COLUMNS[:level] + width - WIDTH
  end

  # Tells how wide the name column is in a box: up to the level, or up to the ping in a box
  # without levels, less the style's gap.
  #
  # @param width [Integer] The box's width.
  # @param level [Boolean] Whether the box shows levels.
  # @return [Integer] The width.
  def name_width(width, level)
    (level ? level_left(width) : ping_left(width)) - COLUMNS[:name] - MGQ_MpUi::Style::GAP
  end

  # Draws the line that says how many more players are on the map than the box lists.
  #
  # @param count [Integer] How many more.
  # @param y [Integer] The line's top.
  # @param width [Integer] The box's width.
  def draw_more(count, y, width)
    MGQ_MpUi::Style.use_font(bitmap, MGQ_MpUi::Style::SMALL_SIZE, MGQ_MpUi::Style::DIM)
    bitmap.draw_text(COLUMNS[:name], y, width - COLUMNS[:name] - EDGE, ROW, MGQ_MpUi::MORE_TEXT % count)
  end

  # Draws an icon of the game's icon set in a line, ICON_SIDE wide.
  #
  # @param icon [Integer, nil] The icon's index, nil for none.
  # @param x [Integer] The icon's left.
  # @param y [Integer] The line's top.
  def draw_icon(icon, x, y)
    MGQ_MpUi.draw_icon(bitmap, icon, x, y + 1, ICON_SIDE)
  end

  # Draws the leader's crown before a name.
  #
  # @param y [Integer] The row's top.
  def draw_crown(y)
    draw_icon(MGQ_MpOverworld::CROWN_ICON, COLUMNS[:crown], y)
  end

  # Draws one player of the party, with where they are below.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @param y [Integer] The player's top.
  # @param width [Integer] The box's width.
  def draw_row(row, y, width = box_width)
    draw_line(row, y, width)
    draw_place(row.place, y + ROW - 3, width)
  end

  # Draws a player's line: the crown, the icon of what they do (the away icon while their
  # connection is down), the name cut to its column in the player's color, the level and the ping.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @param y [Integer] The line's top.
  # @param width [Integer] The box's width.
  # @param level [Boolean] Whether the line shows the level.
  def draw_line(row, y, width = box_width, level = true)
    style = MGQ_MpUi::Style
    draw_crown(y) if row.badge && row.badge[1]
    draw_icon(MGQ_MpPartyBox.away?(row) ? MGQ_MpPartyBox::AWAY_ICON : row.icon, COLUMNS[:icon], y)
    names = name_width(width, level)
    style.use_font(bitmap, style::SMALL_SIZE, MGQ_MpPartyBox.color_of(row))
    bitmap.draw_text(COLUMNS[:name], y, names, ROW, MGQ_MpUi.cut(bitmap, row.name, names))
    if level
      style.use_font(bitmap, style::SMALL_SIZE, style::TEXT)
      bitmap.draw_text(level_left(width), y, LEVEL_WIDTH, ROW, row.level)
    end
    MGQ_MpOverworld.draw_ping(bitmap, row.ping, ping_left(width), y, ROW) if row.ping
  end

  # Draws where a player is, under their name, shortened to fit the box.
  #
  # @param place [String] Where they are.
  # @param y [Integer] The line's top.
  # @param width [Integer] The box's width.
  def draw_place(place, y, width = box_width)
    room = width - COLUMNS[:name] - EDGE
    MGQ_MpUi::Style.use_font(bitmap, MGQ_MpUi::Style::TINY_SIZE, MGQ_MpUi::Style::HEADING)
    text = MGQ_MpWorldOverview.fit_place(place, room, bitmap)
    bitmap.draw_text(COLUMNS[:name], y, room, PLACE_ROW, text)
  end

  # Frees the box's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# Where the box lies, which the player changes with the left Alt held, through ui_layout.rbx.

begin
  MGQ_MpUi::Layout.register(Sprite_MpPartyBox::LAYOUT, Sprite_MpPartyBox::LAYOUT_NAME, Sprite_MpPartyBox::WIDTH, Sprite_MpPartyBox::MIN_HEIGHT, :width)
rescue => e
  MGQ_MpPartyBox.log("layout FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the box's hotkey. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_party_box") { MGQ_MpPartyBox.on_map unless scene_changing? }

  # After the map's sprites, the party's box.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_party_box") { (@mgq_mp_party_box ||= Sprite_MpPartyBox.new(MGQ_MpGame.get(self, :viewport3))).update }

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_party_box") do
    @mgq_mp_party_box.dispose if @mgq_mp_party_box
    @mgq_mp_party_box = nil
  end
rescue => e
  MGQ_MpPartyBox.log("hooks FAILED: #{e.class}: #{e.message}")
end
