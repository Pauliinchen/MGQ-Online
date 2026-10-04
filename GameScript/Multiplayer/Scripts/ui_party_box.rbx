#----------------------------------------------------------------
#  ui_party_box.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# The box at the top right of the map that lists the player's party: the leader first with a crown,
# then the others by name, each with their highest companion level and ping, and where they are on
# a smaller line below.
class Sprite_MpPartyBox < Sprite
  # Width of the box.
  WIDTH = 230

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
    self.bitmap = Bitmap.new(WIDTH, ROW + PLAYER_ROW * MGQ_MpCoop::MAX_PLAYERS + 4)
    self.x = Graphics.width - WIDTH - MARGIN
    self.z = 250
    self.visible = false
    @shown = nil
    @frames = 0
    @overview = nil
  end

  # Draws the party while the player is in one and the World overview is closed, if it changed.
  # Reads the party every READ_FRAMES, and at once when the overview opens or closes.
  def update
    super
    overview = MGQ_MpWorldOverview.open?
    @frames -= 1
    return if @frames > 0 && overview == @overview

    @frames = READ_FRAMES
    @overview = overview
    rows = overview ? [] : MGQ_MpWorldOverview.party_rows
    self.visible = !rows.empty?
    return unless visible

    drawn = rows.map { |row| [row.name, row.level, row.ping && row.ping[0], row.badge, row.place] }
    return if drawn == @shown

    @shown = drawn
    draw(rows)
  rescue => e
    MGQ_MpWorldOverview.log_once(:party_box, "drawing the party box failed: #{e.class}: #{e.message}")
  end

  # Draws the box, as tall as the party needs, in the top right corner.
  #
  # @param rows [Array<MGQ_MpWorldOverview::Row>] The party, see MGQ_MpWorldOverview.party_rows.
  def draw(rows)
    height = ROW + PLAYER_ROW * rows.size + 4
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

  # Draws one player of the party, with where they are below.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @param y [Integer] The player's top.
  def draw_row(row, y)
    if row.badge && row.badge[1]
      icon = MGQ_MpOverworld::CROWN_ICON
      bitmap.stretch_blt(Rect.new(COLUMNS[:crown], y + 1, ROW - 2, ROW - 2), Cache.system("Iconset"), Rect.new(icon % 16 * 24, icon / 16 * 24, 24, 24))
    end
    bitmap.font.color = Sprite_MpWorldOverview::MEMBER_COLOR
    bitmap.draw_text(COLUMNS[:name], y, COLUMNS[:level] - COLUMNS[:name] - 4, ROW, row.name)
    bitmap.font.color = Color.new(255, 255, 255)
    bitmap.draw_text(COLUMNS[:level], y, 44, ROW, row.level)
    if row.ping
      bitmap.font.color = row.ping[1]
      bitmap.draw_text(COLUMNS[:ping_right] - 56, y, 56, ROW, row.ping[0], 2)
    end
    draw_place(row.place, y + ROW - 3)
  end

  # Draws where a player is, under their name, shortened to fit the box.
  #
  # @param place [String] Where they are.
  # @param y [Integer] The line's top.
  def draw_place(place, y)
    width = WIDTH - COLUMNS[:name] - 6
    bitmap.font.size = 14
    bitmap.font.color = Sprite_MpWorldOverview::PLACE_COLOR
    text = MGQ_MpWorldOverview.fit_place(place, width) { |part| bitmap.text_size(part).width }
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
  # After the map's sprites, the party's box.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_party_box") { (@mgq_mp_party_box ||= Sprite_MpPartyBox.new(@viewport3)).update }

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_party_box") do
    @mgq_mp_party_box.dispose if @mgq_mp_party_box
    @mgq_mp_party_box = nil
  end
rescue => e
  MGQ_MpWorldOverview.log("party box hooks FAILED: #{e.class}: #{e.message}")
end
