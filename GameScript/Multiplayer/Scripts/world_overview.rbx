#----------------------------------------------------------------
#  world_overview.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Filled the action wheel's middle through wheel_center
#      Paulinchen  2026-10-04: Moved the party box into ui_party_box.rbx
#                            - Renamed from mp_world_overview.rbx
#      Paulinchen  2026-10-03: Filled the wheel's middle, and built the menus and calls from what the scripts offer through MGQ_MpActions
#                            - Called the scripts that load before this one without asking whether they loaded
#                            - Asked MGQ_MpOverworldSync whether the map is quiet or the player free on it
#                            - Logged through MGQ_MpLog
#                            - Read the bound keys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#      Paulinchen  2026-10-02: Opened and closed the overview with the key the player bound, which its hint names
#                            - Followed the map and its sprites through core_hooks.rbx
#                            - Dropped the unused scroll reader and the wrapper around another player's choices
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# The World overview: a large box over the map, opened with its key (F11 unless the player binds
# another, see core_hotkeys.rbx) or the action wheel's middle, that
# lists every player of the world online, grouped by where they are, with their highest companion
# level, their place in the story and their ping. A player picked with the arrows and confirm, or
# with the mouse, opens a menu of party and duel invites; a player's row shows their invite or
# challenge that reaches the player. The map keeps running behind it.
#
# While the player is in a party, a box at the top right of the map lists its players, the leader
# first, each with their highest companion level, ping, and where they are.
#
# It also tells the others where the player is, their highest companion level and their place in
# the story, in the state overworld_sync.rbx sends.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldOverview
  # Frames between two readings of the highest companion level and the place in the story, three
  # seconds, since the state is compared every frame.
  READ_FRAMES = 180

  # The story's progress variable, by its name in the translation and in the untranslated game.
  PROGRESS = ["Overall Events Progress", "総合イベント進行度"]

  # First progress of each part, latest first: the escape from Tartarus ends Part 1, the Great
  # Decision ends Part 2.
  PART_STARTS = [[3, 40], [2, 20], [1, 0]]

  # The side chosen, by the switch that records the choice, in the translation and in the
  # untranslated game.
  SIDES = {
    "ilias" => ["Ilias Chosen", "イリアス選択"],
    "alice" => ["Alice Chosen", "アリス選択"],
  }

  # Route of the final chapter, by the variable that counts its progress; the route not being
  # played holds 0.
  ROUTES = {
    "chaos" => ["混沌ルート進行度"],
    "destroyer" => ["天界ルート進行度"],
    "judgment" => ["魔界ルート進行度"],
  }

  # What the overview calls each side and route.
  STORY_NAMES = {
    "ilias" => "Ilias side",
    "alice" => "Alice side",
    "chaos" => "Chaos route",
    "destroyer" => "Destroyer route",
    "judgment" => "Judgment route",
  }

  # Parts of places' names the party box writes shorter: the game's own name for the Pocket Castle.
  SHORT_PLACES = { "Pocket Monster Lord's Castle" => "Pocket Castle" }

  # A floor, layer or area that ends a place's name, which a shortened name keeps.
  PLACE_FLOOR = /\s+(B?\d+F\S*|(?:Layer|Area)\s+\d+)\z/

  # A player of the list.
  #
  # @!attribute player [MGQ_MpOverworldSync::Peers::Peer, Symbol] The player, :me for the player.
  # @!attribute name [String] Their name.
  # @!attribute place [String] Where they are.
  # @!attribute level [String] Their highest companion level, empty while unknown.
  # @!attribute story [String] Their place in the story.
  # @!attribute ping [Array, nil] Their ping's text and color.
  # @!attribute icon [Integer, nil] The icon of what they do.
  # @!attribute member [Boolean] Whether they are in the player's party; for the player, whether
  #   they are in a party at all.
  # @!attribute badge [Array, nil] Their party's size and whether they lead it.
  # @!attribute call [Array, nil] Their party invite or duel challenge that reaches the player, as
  #   text and color, shown in place of their place in the story.
  Row = Struct.new(:player, :name, :place, :level, :story, :ping, :icon, :member, :badge, :call)

  @open = false
  @menu = nil
  @selected = :me
  @scroll = 0
  @frames = 0

  # The game's globe icon, which stands for the overview in the action wheel's middle.
  WORLD_ICON = 3988

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "overview"

  # Reports whether the overview is open.
  #
  # @return [Boolean] Whether it is.
  def self.open?
    @open
  end

  # The menu of the player picked, while it is open.
  #
  # @return [Integer, nil] The choice picked in it, nil while it is closed.
  def self.menu
    @menu
  end

  # The action wheel's middle choice, which opens the overview.
  #
  # @return [MGQ_MpActions::Option] The choice.
  def self.wheel_option
    MGQ_MpActions::Option.new("World (#{MGQ_MpHotkeys.label(:overview)})", lambda { open }, nil, WORLD_ICON)
  end

  # Tells the action wheel whether the overview lies over the map, closing it on the wheel's key.
  #
  # @param wheel_key [Boolean] Whether the wheel key went down this frame.
  # @return [Boolean] Whether the overview was open.
  def self.cover(wheel_key)
    return false unless @open

    close if wheel_key
    true
  end

  # Opens the overview on the player's own row.
  def self.open
    return if @open

    @open = true
    @fresh = true
    @menu = nil
    @selected = :me
    @scroll = 0
    @mouse = nil
    @view = view
    MGQ_Multiplayer::Capture.start(:overview)
  end

  # Closes the overview, if it is open, and gives the buttons back.
  def self.close
    return unless @open

    @open = false
    @menu = nil
    @view = nil
    MGQ_Multiplayer::Capture.stop(:overview)
  end

  # Reports whether the overview may open: in a world, on the map, with no event, message, chat
  # box or action wheel open.
  #
  # @return [Boolean] Whether it may.
  def self.openable?
    MGQ_MpOverworldSync.in_world? && SceneManager.scene.is_a?(Scene_Map) && MGQ_MpOverworldSync.map_quiet? &&
      !MGQ_MpChat.typing? && !MGQ_MpActions::Wheel.open?
  end

  # Opens or closes the overview with its key, and steers it while open. Called by the map every frame.
  def self.on_map
    pressed = MGQ_MpHotkeys.pressed?(:overview)
    return close if @open && (pressed || !openable_while_open?)
    return unless pressed || @open

    if @open
      update
    elsif openable?
      Sound.play_ok
      open
    end
  rescue => e
    log("overview failed: #{e.class}: #{e.message}")
    close
  end

  # Reports whether the open overview may stay: still in a world and on the map, with no event or
  # message, nor the chat box, which its key opens over it.
  #
  # @return [Boolean] Whether it may.
  def self.openable_while_open?
    MGQ_MpOverworldSync.in_world? && MGQ_MpOverworldSync.map_quiet? && !MGQ_MpChat.typing?
  end

  # Closes the overview once the map is left. Called by overworld_sync.rbx every frame in every
  # scene; reads the player's highest companion level and place in the story every READ_FRAMES.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    close unless in_world && SceneManager.scene.is_a?(Scene_Map)
    return unless in_world

    @frames -= 1
    return if @frames > 0

    @frames = READ_FRAMES
    @level = top_level
    @story = story_code
  end

  # The fields the overview adds to the state the player's game tells the others.
  #
  # @return [Hash] Where the player is, their highest companion level and their place in the story.
  def self.state_fields
    { "place" => place, "lv" => @level.to_i, "progress" => @story.to_s }
  end

  # Names where the player is: the map's name as the game shows it, or its name in the editor.
  #
  # @return [String] The name.
  def self.place
    name = $game_map.display_name.to_s
    return name unless name.empty?

    info = $data_mapinfos && $data_mapinfos[$game_map.map_id]
    info ? info.name.to_s : "Map #{$game_map.map_id}"
  end

  # Shortens a place's name to fit a width: the Pocket Castle's short name first, then without the
  # part in brackets, then cut before its floor with "...".
  #
  # @param place [String] The name.
  # @param width [Integer] The room for it.
  # @yieldparam text [String] A text to measure.
  # @yieldreturn [Integer] Its width.
  # @return [String] The name as it fits.
  def self.fit_place(place, width)
    text = SHORT_PLACES.inject(place.to_s) { |name, (long, short)| name.sub(long, short) }
    return text if yield(text) <= width

    text = text.sub(/\s*\([^)]*\)/, "")
    return text if yield(text) <= width

    floor = text[PLACE_FLOOR].to_s
    head = text[0, text.length - floor.length]
    head = head[0...-1].rstrip while !head.empty? && yield("#{head}...#{floor}") > width
    "#{head}...#{floor}"
  end

  # Reads the highest base level of the player's companions, in the party and waiting, Luka left out.
  #
  # @return [Integer] The level, 0 without companions.
  def self.top_level
    companions = $game_party.all_members.dup
    companions.concat($game_party.stand_members) if $game_party.respond_to?(:stand_members)
    companions = companions.compact.reject { |actor| actor.respond_to?(:luca?) && actor.luca? }
    # The game keeps a character's levels as a Hash of base, class and race level.
    companions.map { |actor| actor.respond_to?(:base_level) ? actor.base_level : actor.level }.max.to_i
  rescue => e
    log("reading the level failed: #{e.class}: #{e.message}")
    0
  end

  # Reads the player's place in the story: the part, and the side chosen or the route played.
  #
  # @return [String] "part", "part:side" or "part:route", such as "2:alice" or "3:destroyer".
  def self.story_code
    progress = variable(PROGRESS)
    part = PART_STARTS.find { |_, start| progress >= start }[0]
    route = ROUTES.keys.find { |key| variable(ROUTES[key]) > 0 } if part == 3
    side = SIDES.keys.find { |key| switch?(SIDES[key]) }
    chosen = route || side
    chosen ? "#{part}:#{chosen}" : part.to_s
  rescue => e
    log("reading the story failed: #{e.class}: #{e.message}")
    ""
  end

  # Writes a place in the story the way the overview shows it.
  #
  # @param code [String, nil] The place, see story_code.
  # @return [String] Such as "Part 2: Alice side", empty while unknown.
  def self.story_text(code)
    part, chosen = code.to_s.split(":", 2)
    return "" if part.to_s.empty?

    name = STORY_NAMES[chosen.to_s]
    name ? "Part #{part}: #{name}" : "Part #{part}"
  end

  # Reads a variable by its names in the translation and the untranslated game.
  #
  # @param names [Array<String>] The names.
  # @return [Integer] Its value, 0 when the game has none of these names.
  def self.variable(names)
    id = names.map { |name| $data_system.variables.index(name) }.compact.first
    id ? $game_variables[id].to_i : 0
  end

  # Reads a switch by its names in the translation and the untranslated game.
  #
  # @param names [Array<String>] The names.
  # @return [Boolean] Whether it is on, false when the game has none of these names.
  def self.switch?(names)
    id = names.map { |name| $data_system.switches.index(name) }.compact.first
    id ? $game_switches[id] == true : false
  end

  # Lists the players of the world online, the player first.
  #
  # @return [Array<Row>] The players.
  def self.rows
    [own_row("#{MGQ_Multiplayer::Player.name} (you)")] + MGQ_MpOverworldSync::Peers.all.select { |peer| peer.state["name"] }.map { |peer| row_of(peer) }
  end

  # Builds the player's own row.
  #
  # @param name [String] The name it shows.
  # @return [Row] The row.
  def self.own_row(name)
    Row.new(:me, name, place, @level.to_i > 0 ? "Lv #{@level}" : "", story_text(@story), MGQ_MpOverworld.ping_label(MGQ_MpOverworldSync::Ping.measured),
            nil, !MGQ_MpCoop::Party.members.empty?, MGQ_MpOverworld.party_badge(:me), nil)
  end

  # Builds another player's row from what they last told.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @return [Row] The row.
  def self.row_of(peer)
    state = peer.state
    level = state["lv"].to_i
    Row.new(peer, state["name"].to_s, state["place"].to_s.empty? ? "Map #{state['map']}" : state["place"].to_s,
            level > 0 ? "Lv #{level}" : "", story_text(state["progress"]), MGQ_MpOverworld.ping_label(state["ping"]),
            MGQ_MpOverworld::STATE_ICONS[state["scene"]], peer.member ? true : false, MGQ_MpOverworld.party_badge(peer), call_of(peer))
  end

  # Lists the player's party for the box at the top right of the map: the leader first, then the others
  # by name.
  #
  # @return [Array<Row>] The players, the player included; none outside a party of two or more.
  def self.party_rows
    return [] unless MGQ_MpOverworldSync.in_world? && MGQ_MpCoop.size_of(MGQ_MpCoop::Party.id) >= 2

    party = [own_row(MGQ_Multiplayer::Player.name.to_s)] + MGQ_MpCoop::Party.members.map { |peer| row_of(peer) }
    party.sort_by { |row| [row.badge && row.badge[1] ? 0 : 1, row.name.downcase] }
  end

  # Tells what another player calls the player to, such as their party invite or their duel
  # challenge, when it reaches the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @return [Array, nil] The text and its color, nil for none.
  def self.call_of(peer)
    MGQ_MpActions.offers.map { |offers| offers.call_of(peer) }.compact.first
  end

  # Lays the list out: a heading per place, the player's own first and the others by name, each
  # followed by its players by name, the player first.
  #
  # @param rows [Array<Row>] The players, see rows.
  # @return [Array<Array>] Each line: [:place, name] or [:player, row].
  def self.lines(rows)
    own_place = rows.first.place
    groups = rows.group_by(&:place).sort_by { |name, _| [name == own_place ? 0 : 1, name.downcase] }
    groups.map do |name, players|
      [[:place, name]] + players.sort_by { |row| [row.player == :me ? 0 : 1, row.name.downcase] }.map { |row| [:player, row] }
    end.flatten(1)
  end

  # Tells which player a row is, which keeps the selection on them while the list changes.
  #
  # @param row [Row] The row.
  # @return [Object] :me, or the other player's seat.
  def self.key_of(row)
    row.player == :me ? :me : row.player.seat
  end

  # The menu's choices for a player: what every script offers with them, see MGQ_MpActions.offer.
  #
  # @param row [Row] The player.
  # @return [Array<MGQ_MpActions::Option>] The choices.
  def self.menu_options(row)
    return MGQ_MpActions.offers.map { |offers| offers.peer_option(row.player) } unless row.player == :me

    own = MGQ_MpActions.offers.map(&:own_options).flatten
    own.empty? ? [MGQ_MpActions::Option.new("Nothing to do", nil, "Pick another player to invite them.")] : own
  end

  # What the overview shows now.
  #
  # @return [Hash] :lines, :selected (a line), :scroll, :menu (the choices) and :menu_index.
  def self.view
    view_of(lines(rows))
  end

  # What the overview shows, as update last saw it, which its picture draws.
  #
  # @return [Hash, nil] The view, see view; nil while the overview is closed.
  def self.shown_view
    @view
  end

  # Picks the player and the menu's choice out of the list, keeping the choice inside a menu that
  # shrank, such as when an invite ran out.
  #
  # @param lines [Array<Array>] The list, see lines.
  # @return [Hash] The view, see view.
  def self.view_of(lines)
    selected = selected_line(lines)
    row = lines[selected] && lines[selected][1]
    menu = @menu && row ? menu_options(row) : nil
    @menu = [[@menu, menu.size - 1].min, 0].max if menu
    { :lines => lines, :selected => selected, :scroll => @scroll, :menu => menu, :menu_index => @menu }
  end

  # Finds the line of the player picked.
  #
  # @param lines [Array<Array>] The list, see lines.
  # @return [Integer] The line, the player's own while the one picked is gone.
  def self.selected_line(lines)
    lines.index { |kind, row| kind == :player && key_of(row) == @selected } || 1
  end

  # Follows the arrows, confirm, cancel and the mouse while the overview is open.
  def self.update
    lines = lines(rows)
    view = view_of(lines)
    players = (0...lines.size).select { |index| lines[index][0] == :player }
    # The press that opened the overview from the wheel is still down this frame.
    if @fresh
      @fresh = false
    else
      mouse(view, players)
      view[:menu] ? update_menu(view) : update_list(view, players)
      keep_in_sight(lines, players)
    end
    @view = @open ? view_of(lines) : nil
  end

  # Moves through the list, opens the menu of the player picked, or closes the overview.
  #
  # @param view [Hash] What the overview shows, see view.
  # @param players [Array<Integer>] The lines that are players.
  def self.update_list(view, players)
    capture = MGQ_Multiplayer::Capture
    return (Sound.play_cancel; close) if capture.trigger?(:B)
    return open_menu if capture.trigger?(:C)

    step = capture.repeat?(:DOWN) ? 1 : capture.repeat?(:UP) ? -1 : 0
    return if step == 0

    at = players.index(view[:selected]).to_i
    target = players[(at + step) % players.size]
    @selected = key_of(view[:lines][target][1])
    Sound.play_cursor
  end

  # Moves through the menu, takes a choice, or closes the menu.
  #
  # @param view [Hash] What the overview shows, see view.
  def self.update_menu(view)
    capture = MGQ_Multiplayer::Capture
    return (Sound.play_cancel; @menu = nil) if capture.trigger?(:B)
    return choose(view[:menu][@menu]) if capture.trigger?(:C)

    step = capture.repeat?(:DOWN) ? 1 : capture.repeat?(:UP) ? -1 : 0
    return if step == 0

    @menu = (@menu + step) % view[:menu].size
    Sound.play_cursor
  end

  # Opens the menu of the player picked.
  def self.open_menu
    Sound.play_ok
    @menu = 0
  end

  # Takes a choice of the menu, closing the menu, or tells why it cannot be taken.
  #
  # @param option [MGQ_MpActions::Option, nil] The choice.
  def self.choose(option)
    MGQ_MpActions.choose(option) do
      @menu = nil
      close if option.leaves
    end
  end

  # Follows the mouse: pointing picks a player or a choice, a click opens the player's menu or takes
  # the choice, and a click outside the menu closes it, outside the box the overview.
  #
  # @param view [Hash] What the overview shows, see view.
  # @param players [Array<Integer>] The lines that are players.
  def self.mouse(view, players)
    position = MGQ_Multiplayer::Mouse.position
    clicked = MGQ_Multiplayer::Mouse.clicked?
    moved = position && position != @mouse
    @mouse = position
    return unless position

    x, y = position
    if view[:menu]
      choice = Sprite_MpWorldOverview.choice_at(x, y, view)
      @menu = choice if choice && moved
      return unless clicked
      return choose(view[:menu][choice]) if choice

      @menu = nil
    end

    line = Sprite_MpWorldOverview.line_at(x, y, view)
    if line && players.include?(line)
      @selected = key_of(view[:lines][line][1]) if moved || clicked
      open_menu if clicked
    elsif clicked && !Sprite_MpWorldOverview.inside?(x, y)
      Sound.play_cancel
      close
    end
  end

  # Scrolls so the player picked stays in sight.
  #
  # @param lines [Array<Array>] The list, see lines.
  # @param players [Array<Integer>] The lines that are players.
  def self.keep_in_sight(lines, players)
    selected = selected_line(lines)
    rows = Sprite_MpWorldOverview::LIST_ROWS
    # The place heading above the first player shows with them.
    top = players.first == selected ? 0 : selected
    @scroll = top if top < @scroll
    @scroll = selected - rows + 1 if selected >= @scroll + rows
  end
end

# The overview's box over the map: the world's name and the player's party at the top, the list of
# players by place, and the menu of the player picked.
class Sprite_MpWorldOverview < Sprite
  # Where the box sits on the screen.
  BOX = Rect.new(40, 32, 560, 404)

  # Height of one line of the list.
  ROW = 24

  # Height of the title.
  TITLE = 30

  # Height of the hint at the bottom.
  HINT_HEIGHT = 22

  # Lines of the list the box shows at once.
  LIST_ROWS = (BOX.height - TITLE - HINT_HEIGHT - 8) / ROW

  # Left edge of each column: icons, name, party size, level, story, and the ping's right edge.
  COLUMNS = { :icons => 8, :name => 60, :party => 232, :level => 284, :story => 340, :ping_right => BOX.width - 10 }

  # Width of the menu beside the player picked.
  MENU_WIDTH = 210

  # Background of the box, the chat box's.
  BACK = Color.new(0, 0, 0, 170)

  # Background of the player picked and the menu's choice picked, the action wheel's.
  PICKED_BACK = Sprite_MpActionWheel::PICKED_BACK

  # Background of the menu.
  MENU_BACK = Color.new(16, 16, 24, 235)

  # Color of a place's heading.
  PLACE_COLOR = Color.new(160, 200, 255)

  # Color of a party member's name, the ghost label's.
  MEMBER_COLOR = Sprite_MpGhostLabel::MEMBER_COLOR

  # Color of the hint and of a choice that cannot be taken, the action wheel's.
  GREY = Sprite_MpActionWheel::GREY

  # Creates the box, hidden.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(BOX.width, BOX.height)
    self.x = BOX.x
    self.y = BOX.y
    self.z = 400
    self.visible = false
    @shown = nil
  end

  # Reports whether a point of the screen lies in the box.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @return [Boolean] Whether it does.
  def self.inside?(x, y)
    x >= BOX.x && x < BOX.x + BOX.width && y >= BOX.y && y < BOX.y + BOX.height
  end

  # Finds the line of the list under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  # @return [Integer, nil] The line, nil outside the list.
  def self.line_at(x, y, view)
    return nil unless inside?(x, y)

    row = (y - BOX.y - TITLE) / ROW
    return nil if y < BOX.y + TITLE || row >= LIST_ROWS

    line = view[:scroll] + row
    line < view[:lines].size ? line : nil
  end

  # Finds the menu's choice under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  # @return [Integer, nil] The choice, nil outside the menu.
  def self.choice_at(x, y, view)
    left, top = menu_origin(view)
    left += BOX.x
    top += BOX.y
    return nil unless x >= left && x < left + MENU_WIDTH && y >= top

    choice = (y - top) / ROW
    choice < view[:menu].size ? choice : nil
  end

  # Tells where the menu sits in the box: right of the list, under the player picked, or above
  # them when it would leave the box.
  #
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  # @return [Array<Integer>] The menu's left and top edge in the box.
  def self.menu_origin(view)
    row_top = TITLE + (view[:selected] - view[:scroll]) * ROW
    height = view[:menu].size * ROW
    top = row_top + ROW
    top = row_top - height if top + height > BOX.height - HINT_HEIGHT
    [BOX.width - MENU_WIDTH - 8, top]
  end

  # Draws the overview while it is open, if it changed.
  def update
    super
    view = MGQ_MpWorldOverview.shown_view
    self.visible = MGQ_MpWorldOverview.open? && !view.nil?
    return unless visible

    rows = view[:lines].map do |kind, row|
      kind == :player ? [row.name, row.level, row.story, row.ping && row.ping[0], row.icon, row.member, row.badge, row.call && row.call[0]] : row
    end
    drawn = [rows, view[:selected], view[:scroll],
             view[:menu] && view[:menu].map { |option| [option.text, !option.run.nil?] }, view[:menu_index]]
    return if drawn == @shown

    @shown = drawn
    draw(view)
  rescue => e
    MGQ_MpWorldOverview.log_once(:drawing, "drawing failed: #{e.class}: #{e.message}")
  end

  # Draws the whole box.
  #
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  def draw(view)
    bitmap.clear
    bitmap.fill_rect(bitmap.rect, BACK)
    bitmap.font.outline = true
    draw_title(view)
    lines = view[:lines][view[:scroll], LIST_ROWS] || []
    lines.each_with_index { |line, index| draw_line(line, TITLE + index * ROW, view[:scroll] + index == view[:selected]) }
    bitmap.font.size = 16
    bitmap.font.color = GREY
    bitmap.draw_text(8, BOX.height - HINT_HEIGHT, BOX.width - 16, HINT_HEIGHT, "Enter or click: invite or duel    Esc or #{MGQ_MpHotkeys.label(:overview)}: close", 1)
    draw_menu(view) if view[:menu]
  end

  # Draws the world's name and the player's party.
  #
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  def draw_title(view)
    world = MGQ_MpWorld.world
    badge = MGQ_MpOverworld.party_badge(:me)
    bitmap.font.size = 20
    bitmap.font.color = Color.new(255, 255, 255)
    bitmap.draw_text(10, 2, BOX.width - 20, TITLE - 4, world ? world.name.to_s : "World")
    return unless badge

    bitmap.font.color = MEMBER_COLOR
    bitmap.draw_text(10, 2, BOX.width - 20, TITLE - 4, "Party #{badge[0]}", 2)
  end

  # Draws one line of the list: a place's heading or a player.
  #
  # @param line [Array] [:place, name] or [:player, row].
  # @param y [Integer] The line's top.
  # @param picked [Boolean] Whether it is the player picked.
  def draw_line(line, y, picked)
    kind, value = line
    bitmap.font.size = 18
    if kind == :place
      bitmap.font.color = PLACE_COLOR
      bitmap.draw_text(8, y, BOX.width - 16, ROW, value)
      return
    end

    bitmap.fill_rect(4, y, BOX.width - 8, ROW, PICKED_BACK) if picked
    draw_icons(value, y)
    bitmap.font.color = value.member ? MEMBER_COLOR : Color.new(255, 255, 255)
    bitmap.draw_text(COLUMNS[:name], y, COLUMNS[:party] - COLUMNS[:name] - 4, ROW, value.name)
    bitmap.font.size = 16
    bitmap.draw_text(COLUMNS[:party], y, COLUMNS[:level] - COLUMNS[:party], ROW, value.badge[0]) if value.badge
    bitmap.font.color = Color.new(255, 255, 255)
    bitmap.draw_text(COLUMNS[:level], y, COLUMNS[:story] - COLUMNS[:level], ROW, value.level)
    text, color = value.call || [value.story, Color.new(255, 255, 255)]
    bitmap.font.color = color
    bitmap.draw_text(COLUMNS[:story], y, COLUMNS[:ping_right] - 60 - COLUMNS[:story], ROW, text)
    return unless value.ping

    bitmap.font.color = value.ping[1]
    bitmap.draw_text(COLUMNS[:ping_right] - 56, y, 56, ROW, value.ping[0], 2)
  end

  # Draws the icon of what a player does and the crown of a party's leader.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @param y [Integer] The line's top.
  def draw_icons(row, y)
    icons = [row.icon, row.badge && row.badge[1] ? MGQ_MpOverworld::CROWN_ICON : nil].compact
    return if icons.empty?

    iconset = Cache.system("Iconset")
    icons.each_with_index do |icon, index|
      bitmap.blt(COLUMNS[:icons] + index * 26, y, iconset, Rect.new(icon % 16 * 24, icon / 16 * 24, 24, 24))
    end
  end

  # Draws the menu beside the player picked.
  #
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  def draw_menu(view)
    left, top = self.class.menu_origin(view)
    bitmap.fill_rect(left, top, MENU_WIDTH, view[:menu].size * ROW, MENU_BACK)
    bitmap.font.size = 18
    view[:menu].each_with_index do |option, index|
      y = top + index * ROW
      bitmap.fill_rect(left, y, MENU_WIDTH, ROW, PICKED_BACK) if index == view[:menu_index]
      bitmap.font.color = option.run ? Color.new(255, 255, 255) : GREY
      bitmap.draw_text(left + 8, y, MENU_WIDTH - 16, ROW, option.text)
    end
  end

  # Frees the box's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# What the overview takes part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpWorldOverview.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpWorldOverview.state_fields }
rescue => e
  MGQ_MpWorldOverview.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What the overview adds to the action wheel, through ui_actions.rbx.

begin
  MGQ_MpActions.wheel_center { MGQ_MpWorldOverview.wheel_option }
  MGQ_MpActions.cover { |wheel_key| MGQ_MpWorldOverview.cover(wheel_key) }
rescue => e
  MGQ_MpWorldOverview.log("action wheel FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the overview's keys.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "world_overview") { MGQ_MpWorldOverview.on_map unless scene_changing? }

  # After the map's sprites, the overview's box.
  MGQ_MpHooks.after(Spriteset_Map, :update, "world_overview") do
    (@mgq_mp_overview ||= Sprite_MpWorldOverview.new(@viewport3)).update
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "world_overview") do
    @mgq_mp_overview.dispose if @mgq_mp_overview
    @mgq_mp_overview = nil
  end
rescue => e
  MGQ_MpWorldOverview.log("hooks FAILED: #{e.class}: #{e.message}")
end
