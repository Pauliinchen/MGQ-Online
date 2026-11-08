#----------------------------------------------------------------
#  ui_party_box.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Widened the crown's column to a whole icon so the leader's crown shows
#                            - Gave its UI ids the mgq_online_ prefix
#                            - Kept the box at its own or the player's width, a long place or name cut to fit
#      Paulinchen  2026-11-06: Drew the box as a hud of the Mod Framework's UI layer, its players as rows of a list in columns
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

# The party box's size: its hotkey (M unless the player binds another, see core_hotkeys.rbx) makes
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

  # Frames between two readings of the party, a quarter of a second.
  READ_FRAMES = 15

  # How the map's title reads, with how many are on it.
  MAP_TITLE = "Map %d"

  # The row that says how many more players are on the map than the box lists.
  MORE_TEXT = "+%d more"

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
    return [rows, 0] if rows.size <= MAP_LINES

    shown = rows.first(MAP_LINES - 1)
    more = rows.size - shown.size
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

  # Reads the players every READ_FRAMES, and at once when the World overview opens or closes, and
  # tells what the box shows: a new object once the players, its size or the hotkey's key changed.
  #
  # @return [Array] What the box shows.
  def self.serial
    overview = MGQ_MpWorldOverview.open?
    now = MGQ_Multiplayer::Bridge.frame_number
    read(overview) if @read_at.nil? || now - @read_at >= READ_FRAMES || now < @read_at || overview != @overview
    @shown
  rescue => e
    log_once(:read, "reading the players of the box failed: #{e.class}: #{e.message}")
    @shown
  end

  # Reads the players, see sections, and notes what the box shows; it hides while the World
  # overview is open or there is nobody to list, keeping what it showed while it fades out.
  #
  # @param overview [Boolean] Whether the World overview is open.
  def self.read(overview)
    @read_at = MGQ_Multiplayer::Bridge.frame_number
    @overview = overview
    party, others = overview ? [[], []] : sections
    rows = party + others
    note_rows(rows, party.empty? && map_box?) unless overview
    self.hidden = rows.empty?
    return if rows.empty?

    shown = [small?, MGQ_MpHotkeys.label(:party_box), party.size] +
            rows.map { |row| [row.name, row.level, row.ping, row.badge, row.place, row.member, row.icon, away?(row)] }
    return if @shown == shown

    @shown = shown
    @party = party
    @others = others
  end

  # Lists the box's rows as it shows them now, each a row of the list: small, the party and the
  # first others on the map; full, the party's members each over the place they are, then a heading
  # "Map 5" over the others on the map, or the map box's players alone.
  #
  # @return [Array<Hash>] The rows.
  def self.rows
    party = @party || []
    others = @others || []
    small = small?
    rows = []
    if small
      listed, more = capped(others)
      (party + listed).each { |row| rows << player_row(row, false) }
      rows << more_row(more) if more > 0
    else
      party.each do |row|
        rows << player_row(row, true)
        rows << { :cells => ["", "", { :text => row.place.to_s, :typo => :overline, :color => :heading }] }
      end
      rows << { :heading => format(MAP_TITLE, others.size) } unless party.empty? || others.empty?
      listed, more = capped(others)
      listed.each { |row| rows << player_row(row, true) }
      rows << more_row(more) if more > 0
    end
    rows
  end

  # Writes the box's title: the party's with its size, or the map box's with how many are on the
  # map.
  #
  # @return [String] Such as "Party 2 / 4" or "Map 5".
  def self.title
    return format(MAP_TITLE, (@others || []).size) if (@party || []).empty?

    MGQ_MpOverworld.party_title(MGQ_MpOverworld.party_badge(:me))
  end

  # Tells the color of the box's title: the party's in the member's color, the map's in the text's.
  #
  # @return [Symbol] The color's name.
  def self.title_color
    (@party || []).empty? ? :text : :mgq_online_member
  end

  # Makes a player's row: the crown, the icon of what they do (the away icon while their
  # connection is down), the name in their color, the level and the ping.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @param level [Boolean] Whether the row shows the level.
  # @return [Hash] The row.
  def self.player_row(row, level)
    crown = row.badge && row.badge[1] ? { :icons => [MGQ_MpOverworld::CROWN_ICON] } : ""
    icon = away?(row) ? AWAY_ICON : row.icon
    ping = row.ping ? { :text => row.ping[0], :color => row.ping[1], :typo => :caption, :align => :end } : ""
    cells = [crown, icon ? { :icons => [icon] } : "", { :text => row.name.to_s, :color => color_of(row), :typo => :caption }]
    cells << { :text => row.level.to_s, :typo => :caption } if level
    { :cells => cells << ping }
  end

  # Makes the row that says how many more players are on the map than the box lists.
  #
  # @param more [Integer] How many more.
  # @return [Hash] The row.
  def self.more_row(more)
    { :cells => ["", "", { :text => format(MORE_TEXT, more), :color => :dim, :typo => :caption }] }
  end

  # Shows the box as the map is first seen, and again once F12 took it away.
  def self.keep_shown
    MGQ_MpShown.keep(PartyBox::ID, PartyBox)
  end

  # The box at the top right of the map, until the player moves it, that lists the player's party
  # or, in a Raid World, everyone on the map (see rows): a hud of the Mod Framework's UI layer under
  # the game's windows. The full box's title names the hotkey that changes the size at its right,
  # which a click on it does too. The box keeps its width, its own or the player's, and cuts a long
  # name or place to fit; a wider box gives them more room.
  class PartyBox < UI::Component
    # The box's place id, which names its place in the Mod Framework's settings; the map box shares it.
    ID = :mgq_online_party_box

    # The box's name while the player arranges the boxes.
    PLACE_NAME = "Party box"

    # Its place among the parts at the top right.
    ORDER = 10

    # Widths of a row's columns: the crown, the state icon, the name (what is left), the level and
    # the ping, which "999+ ms" fits. An icon column needs a whole icon's 24 pixels, or the list
    # leaves its icon out.
    COLUMNS = [24, 24, nil, 52, 64]

    # Widths of a row's columns in the small box, which has no level.
    SMALL_COLUMNS = [24, 24, nil, 64]

    # Width of the box at its default, and the least.
    WIDTH = 304

    # Width of the small box at its default, and the least.
    SMALL_WIDTH = 210

    # What the title says at its right, with the hotkey that changes the box's size.
    SIZE_HINT = "%s: size"

    # Renders it anew once the players, its size or the hotkey's key changed.
    watch { MGQ_MpPartyBox.serial }

    # Describes the box: the title with the size hint while full, then the rows.
    def render
      small = MGQ_MpPartyBox.small?
      rows = MGQ_MpPartyBox.rows
      width = small ? SMALL_WIDTH : WIDTH
      hud id: ID, place_name: PLACE_NAME, anchor: :top_right, order: ORDER, shown_in: [Scene_Map], resizable: :width,
          width: width, min_size: [width, 0], hide_while: -> { MGQ_MpPartyBox.hidden? } do
        unless small
          stack row: true do
            text MGQ_MpPartyBox.title, typo: :caption, color: MGQ_MpPartyBox.title_color, grow: 1
            button format(SIZE_HINT, MGQ_MpHotkeys.label(:party_box)), variant: :text, color: :dim, on_click: -> { MGQ_MpPartyBox.click_size }
          end
        end
        list rows, cells: (small ? SMALL_COLUMNS : COLUMNS), dense: true, most_rows: [rows.size, 1].max
      end
    end
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the box's hotkey. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_party_box") { MGQ_MpPartyBox.on_map unless scene_changing? }

  # After the map's sprites, the party's box, never on the map behind a menu.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_party_box") { MGQ_MpPartyBox.keep_shown if mgq_mp_hud? }
rescue => e
  MGQ_MpPartyBox.log("hooks FAILED: #{e.class}: #{e.message}")
end
