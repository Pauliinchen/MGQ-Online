#----------------------------------------------------------------
#  ui_party_box.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Kept and read its switch in Player.ini as true or false, which the DLL writes as 1 or 0
#      Paulinchen  2026-11-01: Built the box on the Mod Framework's components, docked at the top right under the game's windows
#                            - Changed the size by a click on the size hint too
#                            - Asked the wheels of the Mod Framework whether one is open
#      Paulinchen  2026-10-31: Placed its box through the Mod Framework's layout
#      Paulinchen  2026-10-23: Kept the box off the live map behind menus
#      Paulinchen  2026-10-12: Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Read the map's viewport through MGQ_MpGame
#      Paulinchen  2026-10-11: Listed a Raid World's party in the box with the other players on the map below it
#                            - Made the box movable and widenable with the left Alt held
#                            - Framed the box in the preset's colors
#                            - Drew the box in the shared style with fades and named its size hotkey in its title
#                            - Kept the level and the ping apart in their own columns and cut a long name to its column
#                            - Left placing the box to its motion
#                            - Drew the icon of what each player does before their name
#                            - Named each line in its player's color through MGQ_MpPlayerColor
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

  # What starts this script's lines in the log.
  LOG_TAG = "party box"

  # The Mod Framework's interface.
  UI = Mod_Framework::UI

  # Reports whether the box shows small, as the player last chose.
  #
  # @return [Boolean] Whether it does.
  def self.small?
    @small = MGQ_Multiplayer::Player.setting(SMALL_SETTING) == true if @small.nil?
    @small
  end

  # Makes the box small or full, keeping the choice in Player.ini.
  def self.toggle
    @small = !small?
    MGQ_Multiplayer::Player.store(SMALL_SETTING, @small)
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
    return "the action wheel is open" if MGQ_MpActions.wheel.open?
    return "the emote wheel is open" if MGQ_MpEmotes.wheel.open?

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
    shown, more = UI.capped(rows, MAP_LINES)
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

  # Picks the color of a player's name in the box: dim while their connection is down, else their
  # own, a party member's, and in the map box plain text for anyone else, as MGQ_MpPlayerColor
  # names them.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @return [Symbol] :dim, :own, :ally or :text.
  def self.color_of(row)
    away?(row) ? :dim : MGQ_MpPlayerColor.role(row.player, row.member)
  end

  # Names the color of a player's name for the log, see color_of.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @return [String] The name: "own", "member", "plain" or AWAY_LABEL.
  def self.color_label(row)
    away?(row) ? AWAY_LABEL : MGQ_MpPlayerColor.label(row.player, row.member)
  end

  # Reports whether the box hides: while the World overview is open or it lists nobody, as it last
  # read the players.
  #
  # @return [Boolean] Whether it does.
  def self.hidden?
    @hidden ? true : false
  end

  # Notes whether the box hides, see hidden?.
  #
  # @param hidden [Boolean] Whether it does.
  def self.hidden=(hidden)
    @hidden = hidden ? true : false
  end

  # Changes the box's size on a click on the size hint of its title, as its hotkey does, with the
  # same refusals.
  def self.click_size
    reason = busy_reason
    return MGQ_MpHotkeys.log_refusal(:party_box, reason) if reason

    toggle
  rescue => e
    log("changing the box's size by a click failed: #{e.class}: #{e.message}")
  end

  # The box at the top right of the map, until the player moves it, that lists the player's party:
  # the leader first with a crown, then the others by name, each with the icon of what they do,
  # their formation's highest level and ping, and where they are on a smaller line below. Small, it
  # lists only each player's icon, name and ping, at the right edge of the box's place. The title
  # names the hotkey that changes the size at its right, which a click on it does too. A root of the
  # Mod Framework docked at the top right under the game's windows; a wider box gives the names and
  # the places more room, and its height follows the players.
  #
  # In a Raid World the party's members show with their Frontline's highest level, and the other
  # players on the player's map follow below the party under the map's title, a line each. Outside a
  # party it is the map box instead: everyone on the player's map, the party's members first, each
  # with their Frontline's highest level and ping, and no place, since all share the player's.
  class View
    # The box's id, which names its place in the Mod Framework's settings; the map box shares it.
    ID = :party_box

    # The box's name while the player arranges the boxes.
    PLACE_NAME = "Party box"

    # Its place among the boxes docked at the top right.
    DOCK_ORDER = 10

    # Height of one line.
    ROW = 22

    # Height of the line with where a player is.
    PLACE_ROW = 16

    # Room between the box's side edges and its columns.
    EDGE = 6

    # Room above the first line and below the last, inside the box's frame.
    SPACING = 2

    # Widths of a line's columns: the crown, the state icon, the name (what is left), the level and
    # the ping, which "999+ ms" fits.
    COLUMNS = [22, 24, nil, 52, MGQ_MpOverworld::PING_WIDTH]

    # Widths of a line's columns in the small box, which has no level.
    SMALL_COLUMNS = [22, 24, nil, MGQ_MpOverworld::PING_WIDTH]

    # Room before the name, where the place below it starts.
    NAME_LEFT = COLUMNS[0] + COLUMNS[1]

    # Width of the box at its default, and the least: the columns up to the level, the level, a gap,
    # the ping and the edges, so the level and the ping never meet.
    WIDTH = 296

    # Width of the small box, at the right edge of the box's place.
    SMALL_WIDTH = 198

    # Least height of the box: one line.
    MIN_HEIGHT = ROW + 2 * SPACING

    # Frames between two readings of the party, a quarter of a second.
    READ_FRAMES = 15

    # What the title says at its right, with the hotkey that changes the box's size.
    SIZE_HINT = "%s: size"

    # How the map's title reads, with how many are on it.
    MAP_TITLE = "Map %d"

    # @return [Mod_Framework::UI::Box] The box.
    attr_reader :root

    # Makes the box and opens it, hidden until it reads the players.
    def initialize
      MGQ_MpPartyBox.hidden = true
      @root = UI::Box.new(:id => ID, :place_name => PLACE_NAME, :frame => false, :under_windows => true, :z => UI::Z[:labels], :dock => :top_right,
                          :dock_order => DOCK_ORDER, :movable => true, :resizable => :width, :min_size => [WIDTH, MIN_HEIGHT], :width => WIDTH,
                          :mouse => :parts, :fade => true, :hide_while => lambda { MGQ_MpPartyBox.hidden? })
      @frames = 0
      @overview = nil
      @drawn = nil
      @root.open
    end

    # Reads the players every READ_FRAMES, and at once when the World overview opens or closes.
    # Called by the map every frame.
    def update
      overview = MGQ_MpWorldOverview.open?
      @frames -= 1
      refresh(overview) if @frames <= 0 || overview != @overview
    end

    # Closes the box, with the map's sprites.
    def close
      @root.close
    end

    # Reads the players, see MGQ_MpPartyBox.sections, and builds the box anew if they, its size,
    # its width or the hotkey's key changed; hides it while the World overview is open or there is
    # nobody to list, keeping what it showed while it fades out.
    #
    # @param overview [Boolean] Whether the World overview is open.
    def refresh(overview)
      @frames = READ_FRAMES
      @overview = overview
      party, others = overview ? [[], []] : MGQ_MpPartyBox.sections
      rows = party + others
      MGQ_MpPartyBox.note_rows(rows, party.empty? && MGQ_MpPartyBox.map_box?) unless overview
      MGQ_MpPartyBox.hidden = rows.empty?
      return if rows.empty?

      small = MGQ_MpPartyBox.small?
      drawn = [small, party.size, width, MGQ_MpHotkeys.label(:party_box)] +
              rows.map { |row| [row.name, row.level, row.ping && row.ping[0], row.badge, row.place, row.member, row.icon, MGQ_MpPartyBox.away?(row)] }
      return if drawn == @drawn

      @drawn = drawn
      build(party, others, small)
    end

    private

    # Tells how wide the box is: as the player left it, WIDTH before it was laid out.
    #
    # @return [Integer] The width.
    def width
      @root.rect ? @root.rect.width : WIDTH
    end

    # Builds the box's panel: small, full with the party and the others on the map below it, or
    # the map box outside a party.
    #
    # @param party [Array<MGQ_MpWorldOverview::Row>] The party, see MGQ_MpPartyBox.sections.
    # @param others [Array<MGQ_MpWorldOverview::Row>] The others on the map, see MGQ_MpPartyBox.sections.
    # @param small [Boolean] Whether the box is small.
    def build(party, others, small)
      @root.clear
      panel = @root.add_box(:frame => true, :padding => [SPACING, EDGE, SPACING, EDGE], :gap => 0, :align => small ? :end : :stretch,
                            :width => small ? SMALL_WIDTH : nil)
      if small
        listed, more = MGQ_MpPartyBox.capped(others)
        (party + listed).each { |row| add_line(panel, row, false) }
        add_more(panel, more)
      elsif party.empty?
        add_title(panel, format(MAP_TITLE, others.size), :text)
        add_map(panel, others)
      else
        add_title(panel, MGQ_MpOverworld.party_title(MGQ_MpOverworld.party_badge(:me)), :ally)
        party.each do |row|
          add_line(panel, row, true)
          add_place(panel, row.place)
        end
        return if others.empty?

        panel.add_label(format(MAP_TITLE, others.size), :font_size => :small, :height => ROW)
        add_map(panel, others)
      end
    end

    # Adds the title line of the full box: the title at the left, cut to its room, and at the right
    # the hint that names the hotkey that changes the box's size, which a click on it does too.
    #
    # @param panel [Mod_Framework::UI::Box] The panel.
    # @param title [String] The title.
    # @param color [Symbol] The title's color.
    def add_title(panel, title, color)
      line = panel.add_row(:height => ROW)
      line.add_label(title, :grow => 1, :shrink => true, :font_size => :small, :color => color)
      hint = line.add_button(format(SIZE_HINT, MGQ_MpHotkeys.label(:party_box)), :flat => true, :quiet => true, :font_size => :small, :color => :dim)
      hint.on(:click) { MGQ_MpPartyBox.click_size }
    end

    # Adds the lines of the players on the map, up to MGQ_MpPartyBox::MAP_LINES, the last saying how
    # many more there are.
    #
    # @param panel [Mod_Framework::UI::Box] The panel.
    # @param rows [Array<MGQ_MpWorldOverview::Row>] The players.
    def add_map(panel, rows)
      shown, more = MGQ_MpPartyBox.capped(rows)
      shown.each { |row| add_line(panel, row, true) }
      add_more(panel, more)
    end

    # Adds a player's line: the crown, the icon of what they do (the away icon while their
    # connection is down), the name in their color, the level and the ping.
    #
    # @param panel [Mod_Framework::UI::Box] The panel.
    # @param row [MGQ_MpWorldOverview::Row] The player.
    # @param level [Boolean] Whether the line shows the level.
    def add_line(panel, row, level)
      line = panel.add_grid(level ? COLUMNS : SMALL_COLUMNS, :height => ROW)
      add_icon(line, row.badge && row.badge[1] ? MGQ_MpOverworld::CROWN_ICON : nil)
      add_icon(line, MGQ_MpPartyBox.away?(row) ? MGQ_MpPartyBox::AWAY_ICON : row.icon)
      line.add_label(row.name.to_s, :font_size => :small, :color => MGQ_MpPartyBox.color_of(row))
      line.add_label(row.level.to_s, :font_size => :small) if level
      if row.ping
        line.add_label(row.ping[0], :font_size => :small, :align => :end, :color => row.ping[1])
      else
        line.add_column
      end
    end

    # Adds an icon of the game's icon set to a line's cell, or an empty cell for none.
    #
    # @param line [Mod_Framework::UI::Grid] The line.
    # @param icon [Integer, nil] The icon's index, nil for none.
    def add_icon(line, icon)
      icon ? line.add_icon(icon) : line.add_column
    end

    # Adds where a player is, under their name, shortened to fit the box.
    #
    # @param panel [Mod_Framework::UI::Box] The panel.
    # @param place [String] Where they are.
    def add_place(panel, place)
      room = width - 2 * EDGE - NAME_LEFT
      text = MGQ_MpWorldOverview.fit_place(place, room, UI.font_bitmap(UI::Style::TINY_SIZE))
      panel.add_label(text, :font_size => :tiny, :color => :heading, :height => PLACE_ROW, :padding => [0, 0, 0, NAME_LEFT])
    end

    # Adds the line that says how many more players are on the map than the box lists.
    #
    # @param panel [Mod_Framework::UI::Box] The panel.
    # @param more [Integer] How many more, 0 for none and no line.
    def add_more(panel, more)
      panel.add_label(format(UI::MORE_TEXT, more), :font_size => :small, :color => :dim, :height => ROW, :padding => [0, 0, 0, NAME_LEFT]) if more > 0
    end
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the box's hotkey. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_party_box") { MGQ_MpPartyBox.on_map unless scene_changing? }

  # After the map's sprites, the party's box, never on the map behind a menu.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_party_box") do
    next unless mgq_mp_hud?

    begin
      (@mgq_mp_party_box ||= MGQ_MpPartyBox::View.new).update
    rescue => e
      MGQ_MpPartyBox.log_once(:draw, "showing the party box failed: #{e.class}: #{e.message}")
    end
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_party_box") do
    @mgq_mp_party_box.close if @mgq_mp_party_box
    @mgq_mp_party_box = nil
  end
rescue => e
  MGQ_MpPartyBox.log("hooks FAILED: #{e.class}: #{e.message}")
end
