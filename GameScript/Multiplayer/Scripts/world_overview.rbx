#----------------------------------------------------------------
#  world_overview.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Listed a Raid World's party for the party box with each member's Frontline level, wherever they are
#                            - Made the box movable and resizable with the left Alt held as the World overview, starting at the list box's place, never smaller than what shows every column, the tabs, the hint and three lines or the longest menu
#                            - Gave the extra width to the story, the World page's values and the raid bosses' names, the ping keeping the right edge, and the extra height to more lines, the picked player kept in sight
#                            - Read the box's place for the clicks on its lines, tabs and menu and for a click outside it
#                            - Drew the box and its menu framed in the interface preset's colors, the tabs not shown on the tab color, the world's name in the title color and the raid bosses' gauges in the edge and well colors, drawing anew once the preset changes
#                            - Kept the menu inside the box when neither below nor above the picked player has room
#                            - Drew the hint whole through the shared style, smaller where it does not fit
#                            - Grouped the World page's raid bosses by the story's sections under a heading each, showing only the sections the world's story reached and those holding a boss someone fought
#                            - Took the box's place, the title's insets and the picked row's from the list box, whose lazy rectangle reads the screen's size once asked
#                            - Added the World page, turned with Left and Right or a click on its tab, with the page's lines laid out once a frame: the world's name, type, difficulty, players, story and in a Raid World every raid boss with a thin gauge, its share left rounded, Defeated and who last hurt it
#                            - Marked the Players tab in gold while a player's call waits there and the World page shows, where the notification box hides
#                            - Showed the world's type and difficulty after its name in the title, joined with a bar, and cut a long name before the party's size
#                            - Named Left and Right in the hint, shortened the Players page's hint to fit the box, and named the close keys as every screen does
#                            - Skipped the keys while the confirm box asks over the overview
#                            - Took the colors, font sizes and column gap from the shared style, the players' colors from MGQ_MpUi::PlayerColor, the ping column and the party's title from MGQ_MpOverworld and the icons from MGQ_MpUi.draw_icon, dropping the colors the party box read here once
#      Paulinchen  2026-10-08: Listed everyone on the player's map for the map box of a Raid World, the party first, and told the others the Frontline's highest level there
#                            - Forgot the level and story told the others when the world closes, so the next world tells its own at once
#                            - Closed with the numpad's 0 through MGQ_MpUi.cancel?, also with Num Lock off
#                            - Took the choices of a player's menu from MGQ_MpActions, which the chat shares
#                            - Named the numpad's 0 in the hint of how to close
#      Paulinchen  2026-10-07: Logged once when the game has no variable or switch of a name, reading 0 or off
#                            - Named players through MGQ_MpOverworldSync.who, cut places through MGQ_MpUi.cut with what measures them, and took icons, white and the depth from MGQ_MpUi
#                            - Logged the overview opening and closing with why, each menu with its choices, the choice taken or refused, and the level and story told to the others
#                            - Left the place of a map the game names nowhere empty instead of its untranslated editor name, and headed it Unnamed place in the list
#      Paulinchen  2026-10-06: Kept the overview shut while the emote wheel is open
#                            - Left out what a script offers as nothing, and said Nothing to do in an empty menu of another player
#                            - Took the box's measures, its headings' color and its background from the list box and the action wheel
#                            - Named trades in the hint
#                            - Dropped the menu reader only the tests used
#                            - Filled the action wheel's middle through wheel_center
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
# another, see core_hotkeys.rbx) or the action wheel's middle, moved and resized with the left Alt
# held (see ui_layout.rbx), with two pages turned with Left and Right or a click on their tabs.
# The Players page
# lists every player of the world online, grouped by where they are, with their highest companion
# level, their place in the story and their ping. A player picked with the arrows and confirm, or
# with the mouse, opens a menu of what the scripts offer, such as party invites, duels and trades;
# a player's row shows their invite, challenge or offer that reaches the player. The World page
# shows the world itself: its name, type, difficulty, players, story and in a Raid World every
# raid boss with how much of its HP the world left it. The map keeps running behind it.
#
# It also lists the player's party for the party box of ui_party_box.rbx, and in a Raid World
# everyone on the player's map for the map box that replaces it.
#
# It also tells the others where the player is, their highest companion level and their place in
# the story, in the state overworld_sync.rbx sends, and in a Raid World their Frontline's highest
# level, which the map box shows.
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

  # The overview's pages in the order Left and Right pass through them, each with its tab's title:
  # the players online, and the world itself.
  PAGES = [[:players, "Players"], [:world, "World"]]

  # What the overview calls each kind of world, by whether it is a Raid World.
  WORLD_TYPES = { true => "Raid", false => "Classic" }

  # What joins the world's name, its type and its difficulty in the title.
  TITLE_JOINT = " | "

  # What the title says while no world is open.
  NO_WORLD = "World"

  # What the World page says of a world that sets no difficulty, whose players keep their own.
  PER_PLAYER = "Per player"

  # What the World page says of the world's story before the relay told it.
  STORY_UNTOLD = "Not told yet"

  # The labels of the World page's rows.
  WORLD_LABELS = { :name => "World", :type => "Type", :difficulty => "Difficulty", :players => "Players", :story => "Story" }

  # How the World page writes the players online and the world's seats.
  PLAYERS_OF = "%d / %d"

  # How the World page heads the raid bosses of a section of the story, see
  # MGQ_MpRaidBosses.sections.
  BOSSES_HEADING = "Raid bosses: %s"

  # The section the World page lists the pools under whose bosses the tables lack.
  OTHER_SECTION = "Other"

  # The parts and routes of the world's story (see MGQ_MpWorldStory.part_of) from which on the
  # World page lists a section's raid bosses, by the section's name; a route the world finished
  # counts too. A section left out, Part 1, shows once the story is told.
  SECTION_REACH = {
    "Part 2" => %w(2 3 ad mr chaos), "Part 3" => %w(3 ad mr chaos), "Angelic Dominion" => %w(ad chaos),
    "Monster Realm" => %w(mr chaos), "Chaos route" => %w(chaos), "Chaos Domain" => %w(chaos),
  }

  # What the World page says of a raid boss the world defeated.
  DEFEATED = "Defeated"

  # How the World page names who last hurt a raid boss.
  LAST_HURT_BY = "last hurt by %s"

  # How the World page writes a raid boss's tier.
  TIER = "Tier %d"

  # How the World page writes the share of a raid boss's HP left, in percent.
  SHARE_LEFT = "%d%%"

  # Percent of a share, for SHARE_LEFT.
  PERCENT = 100

  # The share of its HP a raid boss has while the relay told no pool of it: all of it.
  UNTOUCHED = 1.0

  # The part of the story every route belongs to, see story_code.
  ROUTE_PART = "3"

  # A raid boss of the World page.
  #
  # @!attribute name [String] Its milestone's name, such as "Tamamo (cap 61)", or its pool's key.
  # @!attribute tier [Integer, nil] Its tier, see MGQ_MpRaidBosses::TIERS; nil for a pool whose
  #   boss the tables lack.
  # @!attribute left [Float] The share of its HP left, 0 to 1, over its pools; UNTOUCHED while the
  #   relay told none.
  # @!attribute defeated [Boolean] Whether the world defeated it.
  # @!attribute by [String, nil] Who last hurt it, nil while no pool of it knows.
  Boss = Struct.new(:name, :tier, :left, :defeated, :by)

  # What the list's heading says for the maps the game names nowhere.
  UNNAMED_PLACE = "Unnamed place"

  # Parts of places' names the party box writes shorter: the game's own name for the Pocket Castle.
  SHORT_PLACES = { "Pocket Monster Lord's Castle" => "Pocket Castle" }

  # A floor, layer or area that ends a place's name, which a shortened name keeps.
  PLACE_FLOOR = /\s+(B?\d+F\S*|(?:Layer|Area)\s+\d+)\z/

  # A player of the list.
  #
  # @!attribute player [MGQ_MpOverworldSync::Peers::Peer, Symbol] The player, :me for the player.
  # @!attribute name [String] Their name.
  # @!attribute place [String] Where they are.
  # @!attribute level [String] Their highest companion level, in the map box their Frontline's, empty
  #   while unknown.
  # @!attribute story [String] Their place in the story.
  # @!attribute ping [Array, nil] Their ping's text and color.
  # @!attribute icon [Integer, nil] The icon of what they do.
  # @!attribute member [Boolean] Whether they are in the player's party; for the player, whether
  #   they are in a party at all.
  # @!attribute badge [Array, nil] Their party's size and whether they lead it.
  # @!attribute call [Array, nil] Their invite, challenge or offer that reaches the player, as text
  #   and color, shown in place of their place in the story.
  Row = Struct.new(:player, :name, :place, :level, :story, :ping, :icon, :member, :badge, :call)

  @open = false
  @menu = nil
  @selected = :me
  @scroll = 0
  @frames = 0
  @page = :players
  @world_scroll = 0

  # The game's globe icon, which stands for the overview in the action wheel's middle.
  WORLD_ICON = 3988

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "overview"

  # Reports whether the overview is open.
  #
  # @return [Boolean] Whether it is.
  def self.open?
    @open
  end

  # The action wheel's middle choice, which opens the overview.
  #
  # @return [MGQ_MpActions::Option] The choice.
  def self.wheel_option
    MGQ_MpActions::Option.new("World (#{MGQ_MpHotkeys.label(:overview)})", lambda { open("the action wheel") }, nil, WORLD_ICON)
  end

  # Tells the action wheel whether the overview lies over the map, closing it on the wheel's key.
  #
  # @param wheel_key [Boolean] Whether the wheel key went down this frame.
  # @return [Boolean] Whether the overview was open.
  def self.cover(wheel_key)
    return false unless @open

    close("the wheel key") if wheel_key
    true
  end

  # Opens the overview on the Players page, on the player's own row.
  #
  # @param via [String] What opened it, for the log.
  def self.open(via = "the action wheel")
    return if @open
    @open = true
    @fresh = true
    @menu = nil
    @selected = :me
    @scroll = 0
    @page = :players
    @world_scroll = 0
    @mouse = nil
    @view = view
    log("opened through #{via}, #{@view[:lines].count { |kind, _| kind == :player }} player(s) online")
    MGQ_Multiplayer::Capture.start(:overview)
  end

  # Closes the overview, if it is open, and gives the buttons back.
  #
  # @param reason [String] Why, for the log.
  def self.close(reason = "closed from outside")
    return unless @open

    log("closed: #{reason}")
    @open = false
    @menu = nil
    @view = nil
    MGQ_Multiplayer::Capture.stop(:overview)
  end

  # Reports whether the overview may open: in a world, on the map, with no event, message, chat
  # box, action wheel or emote wheel open.
  #
  # @return [Boolean] Whether it may.
  def self.openable?
    MGQ_MpOverworldSync.in_world? && SceneManager.scene.is_a?(Scene_Map) && MGQ_MpOverworldSync.map_quiet? &&
      !MGQ_MpChat.typing? && !MGQ_MpActions::Wheel.open? && !MGQ_MpEmotes.open?
  end

  # Opens or closes the overview with its key, and steers it while open. Called by the map every frame.
  def self.on_map
    pressed = MGQ_MpHotkeys.pressed?(:overview)
    return close(pressed ? "its hotkey" : "an event, a message or the chat box took over") if @open && (pressed || !openable_while_open?)
    return unless pressed || @open

    if @open
      update
    elsif openable?
      Sound.play_ok
      open("its hotkey")
    else
      log("hotkey ignored: not on a quiet map in a world, or the chat or a wheel is open")
    end
  rescue => e
    log("overview failed: #{e.class}: #{e.message}")
    close("it failed")
  end

  # Reports whether the open overview may stay: still in a world and on the map, with no event or
  # message, nor the chat box, which its key opens over it.
  #
  # @return [Boolean] Whether it may.
  def self.openable_while_open?
    MGQ_MpOverworldSync.in_world? && MGQ_MpOverworldSync.map_quiet? && !MGQ_MpChat.typing?
  end

  # The page shown.
  #
  # @return [Symbol] :players or :world, see PAGES.
  def self.page
    @page
  end

  # Turns to a page, closing the menu, which belongs to the Players page. Nothing for the page
  # shown already.
  #
  # @param page [Symbol] The page, see PAGES.
  # @param via [String] What turned it, for the log.
  def self.turn_to(page, via)
    title = PAGES.assoc(page)
    return unless title && page != @page

    @page = page
    @menu = nil
    Sound.play_cursor
    log("turned to the #{title[1]} page through #{via}")
  end

  # Turns a page on, or back, round past the ends.
  #
  # @param step [Integer] 1 for the next page, -1 for the one before.
  # @param via [String] What turned it, for the log.
  def self.turn(step, via)
    index = PAGES.index { |page, _| page == @page }.to_i
    turn_to(PAGES[(index + step) % PAGES.size][0], via)
  end

  # Turns the page with Left and Right.
  #
  # @return [Boolean] Whether a page turned.
  def self.turn_by_keys
    step = axis_step(:LEFT, :RIGHT)
    return false if step == 0

    turn(step, "the arrows")
    true
  end

  # Reads two arrows held or repeating as a step along their axis.
  #
  # @param back [Symbol] The arrow that steps back, :UP or :LEFT.
  # @param forth [Symbol] The arrow that steps on, :DOWN or :RIGHT.
  # @return [Integer] 1 on, -1 back, 0 while neither repeats.
  def self.axis_step(back, forth)
    capture = MGQ_Multiplayer::Capture
    capture.repeat?(forth) ? 1 : capture.repeat?(back) ? -1 : 0
  end

  # Closes the overview with the cancel sound once cancel went down.
  #
  # @return [Boolean] Whether it closed.
  def self.closed_by_cancel?
    return false unless MGQ_MpUi.cancel?

    Sound.play_cancel
    close("cancel")
    true
  end

  # The open world's name, for the title and the World page.
  #
  # @return [String] The name, NO_WORLD while none is open.
  def self.world_name
    world = MGQ_MpWorld.world
    world ? world.name.to_s : NO_WORLD
  end

  # What follows the world's name in the title: its type, and its difficulty when it sets one.
  #
  # @return [String] Such as " | Raid | Hard".
  def self.title_tail
    [WORLD_TYPES[MGQ_MpCoop::Scope.raid?], difficulty_name].compact.map { |part| "#{TITLE_JOINT}#{part}" }.join
  end

  # Names the difficulty the world sets for every player, as the game's own difficulty choice
  # names it, in plain case.
  #
  # @return [String, nil] Such as "Hard"; nil while the players keep their own.
  def self.difficulty_name
    name = MGQ_MpWorld.difficulty_name(MGQ_MpWorldDifficulty.value)
    name ? name.capitalize : nil
  end

  # Reads the world's place in the story as the relay told it: its part, and on a route of the
  # final chapter the route, found through the variable that counts it (see ROUTES), since the
  # world's story names routes as the relay does. The side is each player's own, so the world
  # has none.
  #
  # @return [String] "part" or "part:route", see story_code; empty before the relay told the story.
  def self.world_story_code
    counters = MGQ_MpWorldStory.world
    return "" unless counters

    part = MGQ_MpWorldStory.part_of(counters)
    index = MGQ_MpWorldStory::ROUTES.index(part)
    return part.to_s unless index

    id = MGQ_MpWorldStory::ROUTE_VARIABLES[index]
    route = ROUTES.keys.find { |key| ROUTES[key].any? { |name| $data_system.variables.index(name) == id } }
    log_once([:world_route, part], "no variable of the game counts the world's #{part} route, telling the part alone") unless route
    route ? "#{ROUTE_PART}:#{route}" : ROUTE_PART
  rescue => e
    log("reading the world's story failed: #{e.class}: #{e.message}")
    ""
  end

  # Writes the world's place in the story the way the overview shows it.
  #
  # @return [String] Such as "Part 3: Chaos route", STORY_UNTOLD before the relay told the story.
  def self.world_story_text
    code = world_story_code
    code.empty? ? STORY_UNTOLD : story_text(code)
  end

  # Lays the World page out: the world's name, type, difficulty and players, then in a Raid World
  # its story and its raid bosses under a heading per section of the story.
  #
  # @param online [Integer] The players online, the player included.
  # @return [Array<Array>] Each line: [:info, label, value], [:place, heading] or [:boss, boss].
  def self.world_lines(online)
    world = MGQ_MpWorld.world
    raid = MGQ_MpCoop::Scope.raid?
    seats = world ? world.seats.to_i : 0
    lines = [[:info, WORLD_LABELS[:name], world_name], [:info, WORLD_LABELS[:type], WORLD_TYPES[raid]],
             [:info, WORLD_LABELS[:difficulty], difficulty_name || PER_PLAYER],
             [:info, WORLD_LABELS[:players], seats > 0 ? PLAYERS_OF % [online, seats] : online.to_s]]
    return lines unless raid

    lines << [:info, WORLD_LABELS[:story], world_story_text]
    boss_sections.each do |section, bosses|
      lines << [:place, BOSSES_HEADING % section]
      lines.concat(bosses.map { |boss| [:boss, boss] })
    end
    lines
  end

  # Lists the raid bosses for the World page by the story's sections in story order: each section
  # the world's story reached (see reached?) or holding a boss the relay told a pool of, its bosses
  # in the order the story meets them, then the pools of its fights that take their own name, such
  # as Sisel's; last, under OTHER_SECTION, the pools whose bosses the tables lack, by name.
  #
  # @return [Array<Array(String, Array<Boss>)>] Each section's name with its bosses.
  def self.boss_sections
    pools = MGQ_MpRaidPool.pools.group_by { |key, _| MGQ_MpRaidPool.boss_key(key) }
    counters = MGQ_MpWorldStory.world
    listed = MGQ_MpRaidBosses.sections.map do |section, keys|
      names = keys + pools.keys.select { |name| !keys.include?(name) && section_of(name) == section }.sort
      next unless reached?(section, counters) || names.any? { |name| pools.key?(name) }

      [section, names.map { |name| boss_of(name, tier_of(name), pools.delete(name)) }]
    end
    others = pools.keys.sort.map { |name| boss_of(name, nil, pools[name]) }
    listed.compact + (others.empty? ? [] : [[OTHER_SECTION, others]])
  end

  # Reports whether the world's story reached a section of raid bosses, see SECTION_REACH.
  #
  # @param section [String] The section's name.
  # @param counters [Hash, nil] The world's story, see MGQ_MpWorldStory.world; nil before the relay
  #   told it, which reaches no section.
  # @return [Boolean] Whether it did.
  def self.reached?(section, counters)
    return false unless counters

    reach = SECTION_REACH[section]
    reach.nil? || !(reach & ([MGQ_MpWorldStory.part_of(counters).to_s] + Array(counters["done"]))).empty?
  rescue => e
    log_once(:boss_sections, "reading the world's story for the raid bosses failed: #{e.class}: #{e.message}")
    false
  end

  # Finds the section of a pool's boss: its milestone's or OPTIONAL's, else that of the troop a
  # fight with its own name belongs to.
  #
  # @param name [String] The pool's boss, see MGQ_MpRaidPool.boss_key.
  # @return [String, nil] The section, nil for a boss the tables lack.
  def self.section_of(name)
    MGQ_MpRaidBosses.section(name) || MGQ_MpRaidBosses.section(MGQ_MpRaidPool.troop_of_key(name))
  end

  # Finds the tier of a raid boss by its name, as section_of finds its section.
  #
  # @param name [String] The boss's name.
  # @return [Integer, nil] Its tier, nil for a name the tables lack.
  def self.tier_of(name)
    MGQ_MpRaidBosses.key_tier(name) || MGQ_MpRaidBosses.tier(MGQ_MpRaidPool.troop_of_key(name))
  end

  # Sums a raid boss up from its pools: the share left over them, whether every one is empty for
  # good, and who hurt the one last told of.
  #
  # @param name [String] The boss's name, see Boss.
  # @param tier [Integer, nil] Its tier.
  # @param entries [Array<Array>, nil] Its pools, each with its key; nil while the relay told none.
  # @return [Boss] The boss.
  def self.boss_of(name, tier, entries)
    pools = (entries || []).map { |_, pool| pool }
    return Boss.new(name, tier, UNTOUCHED, false, nil) if pools.empty?

    now = Time.now
    left = pools.inject(0.0) { |sum, pool| sum + MGQ_MpRaidPool.left_now(pool, now) } / pools.size
    hurt = pools.select { |pool| !pool.by.to_s.empty? }.max_by { |pool| pool.at.to_f }
    Boss.new(name, tier, left, pools.all? { |pool| pool.defeated }, hurt && hurt.by.to_s)
  end

  # Writes the share of a raid boss's HP left, never 0% while any is.
  #
  # @param left [Float] The share, 0 to 1.
  # @return [String] Such as "68%".
  def self.share_text(left)
    SHARE_LEFT % [(left * PERCENT).round, left > 0 ? 1 : 0].max
  end

  # Closes the overview once the map is left. Called by overworld_sync.rbx every frame in every
  # scene; reads the player's highest companion level and place in the story every READ_FRAMES.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    close(in_world ? "the map was left" : "the world closed") unless in_world && SceneManager.scene.is_a?(Scene_Map)
    return forget unless in_world

    @frames -= 1
    return if @frames > 0

    @frames = READ_FRAMES
    level = top_level
    story = story_code
    front = MGQ_MpCoop::Scope.raid? ? front_level : nil
    if [level, story, front] != [@level, @story, @front]
      log("told the others: level #{@level.inspect} -> #{level}, story #{@story.inspect} -> #{story.inspect}#{front ? ", Frontline level #{@front.inspect} -> #{front}" : ''}")
    end
    @level = level
    @story = story
    @front = front
  end

  # Forgets what the player told the others, so the next world reads it afresh at once instead of
  # telling the last world's.
  def self.forget
    @level = @story = @front = nil
    @frames = 0
  end

  # The fields the overview adds to the state the player's game tells the others.
  #
  # @return [Hash] Where the player is, their highest companion level and their place in the story,
  #   and in a Raid World their Frontline's highest level.
  def self.state_fields
    fields = { "place" => place, "lv" => @level.to_i, "progress" => @story.to_s }
    fields["flv"] = @front.to_i if MGQ_MpCoop::Scope.raid?
    fields
  end

  # Names where the player is: the map's name as the game shows it, empty on a map the game names
  # nowhere, since the editor's names are internal and untranslated.
  #
  # @return [String] The name.
  def self.place
    $game_map.display_name.to_s
  end

  # Shortens a place's name to fit a width: the Pocket Castle's short name first, then without the
  # part in brackets, then cut before its floor with "...".
  #
  # @param place [String] The name.
  # @param width [Integer] The room for it.
  # @param measure [Bitmap, Window_Base] What measures a text with the font it is drawn in.
  # @return [String] The name as it fits.
  def self.fit_place(place, width, measure)
    text = SHORT_PLACES.inject(place.to_s) { |name, (long, short)| name.sub(long, short) }
    return text if measure.text_size(text).width <= width

    text = text.sub(/\s*\([^)]*\)/, "")
    return text if measure.text_size(text).width <= width

    floor = text[PLACE_FLOOR].to_s
    MGQ_MpUi.cut(measure, text[0, text.length - floor.length], width, floor)
  end

  # Reads the highest base level of the player's companions, in the party and waiting, Luka left out.
  #
  # @return [Integer] The level, 0 without companions.
  def self.top_level
    companions = $game_party.all_members.dup
    companions.concat($game_party.stand_members) if $game_party.respond_to?(:stand_members)
    companions = companions.compact.reject { |actor| actor.respond_to?(:luca?) && actor.luca? }
    companions.map { |actor| base_level_of(actor) }.max.to_i
  rescue => e
    log("reading the level failed: #{e.class}: #{e.message}")
    0
  end

  # Reads the highest base level of the player's share of the Frontline, Luka included: the squad's
  # share through coop_squad.rbx, else the first character.
  #
  # During a co-op battle it keeps the last level read, since the battle's party and its level sync
  # stand in for the player's own characters then.
  #
  # @return [Integer] The level, 0 without characters.
  def self.front_level
    return @front.to_i if defined?(MGQ_MpBattlesCoop) && MGQ_MpBattlesCoop.active?

    share = MGQ_MpCoopSquad.own_share
    front = MGQ_MpCoopSquad.own_order.first(share ? share[0] : 1)
    front.map { |actor| base_level_of(actor) }.max.to_i
  rescue => e
    log("reading the Frontline's level failed: #{e.class}: #{e.message}")
    0
  end

  # Reads a character's base level.
  #
  # @param actor [Game_Actor] The character.
  # @return [Integer] The level.
  def self.base_level_of(actor)
    # The game keeps a character's levels as a Hash of base, class and race level.
    actor.respond_to?(:base_level) ? actor.base_level : actor.level
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
    log_once([:variable, names], "no variable of the game is named #{names.join(' or ')}, reading 0") unless id
    id ? $game_variables[id].to_i : 0
  end

  # Reads a switch by its names in the translation and the untranslated game.
  #
  # @param names [Array<String>] The names.
  # @return [Boolean] Whether it is on, false when the game has none of these names.
  def self.switch?(names)
    id = names.map { |name| $data_system.switches.index(name) }.compact.first
    log_once([:switch, names], "no switch of the game is named #{names.join(' or ')}, reading off") unless id
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
    Row.new(peer, state["name"].to_s, state["place"].to_s,
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

  # Lists the player's party for the party box of a Raid World, as party_rows does, but with each
  # player's Frontline's highest level, as the map box shows it.
  #
  # @return [Array<Row>] The players, the player included; none outside a party of two or more.
  def self.raid_party_rows
    party_rows.each { |row| row.level = level_text(row.player == :me ? @front : row.player.state["flv"]) }
  end

  # Lists everyone on the player's map for the map box of a Raid World: the party's members first,
  # its leader before the others by name, then the other players by name, each with their
  # Frontline's highest level. Only the party's leader keeps a crown.
  #
  # @return [Array<Row>] The players, the player included; none while nobody else is on the map.
  def self.map_rows
    return [] unless MGQ_MpOverworldSync.in_world?

    peers = MGQ_MpCoop::Scope.peers_here.select { |peer| peer.state["name"] }
    return [] if peers.empty?

    own = own_row(MGQ_Multiplayer::Player.name.to_s)
    own.level = level_text(@front)
    rows = [own] + peers.map do |peer|
      row = row_of(peer)
      row.level = level_text(peer.state["flv"])
      row
    end
    rows.each { |row| row.badge = nil unless row.member }
    rows.sort_by { |row| [row.member ? 0 : 1, row.badge && row.badge[1] ? 0 : 1, row.name.downcase] }
  end

  # Writes a level the way the lists show it.
  #
  # @param level [Integer, String, nil] The level.
  # @return [String] Such as "Lv 30", empty while unknown.
  def self.level_text(level)
    level.to_i > 0 ? "Lv #{level.to_i}" : ""
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
      [[:place, name.empty? ? UNNAMED_PLACE : name]] + players.sort_by { |row| [row.player == :me ? 0 : 1, row.name.downcase] }.map { |row| [:player, row] }
    end.flatten(1)
  end

  # Tells which player a row is, which keeps the selection on them while the list changes.
  #
  # @param row [Row] The row.
  # @return [Object] :me, or the other player's seat.
  def self.key_of(row)
    row.player == :me ? :me : row.player.seat
  end

  # The menu's choices for a player: what every script offers with them, see MGQ_MpActions.offer,
  # or a choice that says there is nothing to do.
  #
  # @param row [Row] The player.
  # @return [Array<MGQ_MpActions::Option>] The choices, at least one.
  def self.menu_options(row)
    if row.player == :me
      options = MGQ_MpActions.own_options
      refusal = "Pick another player to invite them."
    else
      options = MGQ_MpActions.peer_options(row.player)
      refusal = "Nothing can be done with #{row.name} right now."
    end
    options.empty? ? [MGQ_MpActions::Option.new("Nothing to do", nil, refusal)] : options
  end

  # What the overview shows now, on its page.
  #
  # @return [Hash] :page, :lines, :selected (a line), :scroll, :menu (the choices), :menu_index,
  #   and on the World page :calls, whether a player's call waits on the Players page.
  def self.view
    all = rows
    page_view(page_lines(all), all)
  end

  # Lays the page out that is open: the World page's lines, or the Players page's list.
  #
  # @param rows [Array<Row>] The players, see rows.
  # @return [Array<Array>] The lines, see world_lines and lines.
  def self.page_lines(rows)
    @page == :world ? world_lines(rows.size) : lines(rows)
  end

  # What the overview shows on its page: the World page, or the Players page's list.
  #
  # @param lines [Array<Array>] The page's lines, see page_lines.
  # @param rows [Array<Row>] The players, see rows.
  # @return [Hash] The view, see view.
  def self.page_view(lines, rows)
    @page == :world ? world_view(lines, rows.any? { |row| row.call }) : view_of(lines)
  end

  # The World page's view: its lines from its scroll, kept within the lines as the box's height
  # changes, nothing picked and no menu, and whether a player's call waits on the Players page,
  # which the notification box hides behind the overview.
  #
  # @param lines [Array<Array>] The World page's lines, see world_lines.
  # @param calls [Boolean] Whether a player's invite, challenge or offer reaches the player.
  # @return [Hash] The view, see view.
  def self.world_view(lines, calls)
    @world_scroll = MGQ_MpUi.within(@world_scroll, 0, most_scroll(lines))
    { :page => :world, :lines => lines, :selected => nil, :scroll => @world_scroll, :menu => nil, :menu_index => nil, :calls => calls }
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
    { :page => :players, :lines => lines, :selected => selected, :scroll => @scroll, :menu => menu, :menu_index => @menu }
  end

  # Finds the line of the player picked.
  #
  # @param lines [Array<Array>] The list, see lines.
  # @return [Integer] The line, the player's own while the one picked is gone.
  def self.selected_line(lines)
    lines.index { |kind, row| kind == :player && key_of(row) == @selected } || 1
  end

  # Follows the arrows, confirm, cancel and the mouse while the overview is open; nothing while
  # the confirm box asks over it, whose answer would reach the menu otherwise. The page's lines
  # are laid out once a frame, again only once the page turned.
  def self.update
    return if MGQ_MpUi::Confirm.open?

    all = rows
    page = @page
    lines = page_lines(all)
    # The press that opened the overview from the wheel is still down this frame.
    if @fresh
      @fresh = false
    elsif page == :world
      update_world(lines)
    else
      update_players(lines)
    end
    lines = page_lines(all) if @page != page
    @view = @open ? page_view(lines, all) : nil
  end

  # Follows the mouse, the arrows, confirm and cancel on the Players page; the keys only while
  # a click did not turn the page, else a key held with the click would reach the page left.
  #
  # @param lines [Array<Array>] The Players page's list, see lines.
  def self.update_players(lines)
    view = view_of(lines)
    players = (0...lines.size).select { |index| lines[index][0] == :player }
    mouse(view, players)
    return unless @page == :players

    view[:menu] ? update_menu(view) : update_list(view, players)
    keep_in_sight(lines, players)
  end

  # Scrolls the World page with the arrows, turns the page, follows the mouse, or closes the
  # overview.
  #
  # @param lines [Array<Array>] The World page's lines, see world_lines.
  def self.update_world(lines)
    mouse_world
    return unless @open
    return if closed_by_cancel? || turn_by_keys

    step = axis_step(:UP, :DOWN)
    return if step == 0

    scroll = MGQ_MpUi.within(@world_scroll + step, 0, most_scroll(lines))
    return if scroll == @world_scroll

    @world_scroll = scroll
    Sound.play_cursor
  end

  # Tells the furthest a page scrolls: until its last line is the last in sight.
  #
  # @param lines [Array<Array>] The page's lines, see page_lines.
  # @return [Integer] The first line in sight then, 0 while every line fits.
  def self.most_scroll(lines)
    [lines.size - Sprite_MpWorldOverview.list_rows, 0].max
  end

  # Moves through the list, opens the menu of the player picked, turns the page, or closes the
  # overview.
  #
  # @param view [Hash] What the overview shows, see view.
  # @param players [Array<Integer>] The lines that are players.
  def self.update_list(view, players)
    return if closed_by_cancel?
    return open_menu(view[:lines][view[:selected]][1]) if MGQ_Multiplayer::Capture.trigger?(:C)
    return if turn_by_keys

    step = axis_step(:UP, :DOWN)
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
    return (Sound.play_cancel; log("menu closed with cancel"); @menu = nil) if MGQ_MpUi.cancel?
    return choose(view[:menu][@menu], view[:lines][view[:selected]][1]) if MGQ_Multiplayer::Capture.trigger?(:C)

    step = axis_step(:UP, :DOWN)
    return if step == 0

    @menu = (@menu + step) % view[:menu].size
    Sound.play_cursor
  end

  # Opens the menu of the player picked.
  #
  # @param row [Row] The player.
  def self.open_menu(row)
    Sound.play_ok
    @menu = 0
    options = menu_options(row).map { |option| option.run ? option.text : "#{option.text} (refused: #{option.refusal})" }
    log("menu of #{who(row)}: #{options.join(', ')}")
  end

  # Names a player of the list for the log.
  #
  # @param row [Row, nil] The player.
  # @return [String] Their name and seat, or "the player" for the player.
  def self.who(row)
    return "nobody" unless row

    MGQ_MpOverworldSync.who(row.player)
  end

  # Takes a choice of the menu, closing the menu, or tells why it cannot be taken.
  #
  # @param option [MGQ_MpActions::Option, nil] The choice.
  # @param row [Row, nil] The player whose menu it is.
  def self.choose(option, row = nil)
    log(option.run ? "chose #{option.text} for #{who(row)}" : "#{option.text} for #{who(row)} refused: #{option.refusal || 'no reason given'}") if option
    MGQ_MpActions.choose(option) do
      @menu = nil
      close("the choice leaves it") if option.leaves
    end
  end

  # Follows the mouse on the Players page: pointing picks a player or a choice, a click opens the
  # player's menu or takes the choice, a click on a tab turns the page, and a click outside the
  # menu closes it, outside the box the overview.
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
    tab = Sprite_MpWorldOverview.tab_at(x, y)
    if tab
      return unless clicked

      log("menu closed with a click on a tab") if view[:menu]
      @menu = nil
      return turn_to(tab, "a click on its tab")
    end
    if view[:menu]
      choice = Sprite_MpWorldOverview.choice_at(x, y, view)
      @menu = choice if choice && moved
      return unless clicked
      return choose(view[:menu][choice], view[:lines][view[:selected]][1]) if choice

      log("menu closed with a click outside it")
      @menu = nil
    end

    line = Sprite_MpWorldOverview.line_at(x, y, view)
    if line && players.include?(line)
      @selected = key_of(view[:lines][line][1]) if moved || clicked
      open_menu(view[:lines][line][1]) if clicked
    elsif clicked && !Sprite_MpWorldOverview.inside?(x, y)
      Sound.play_cancel
      close("a click outside the box")
    end
  end

  # Follows the mouse on the World page: a click on a tab turns the page, a click outside the box
  # closes the overview.
  def self.mouse_world
    position = MGQ_Multiplayer::Mouse.position
    clicked = MGQ_Multiplayer::Mouse.clicked?
    @mouse = position
    return unless position && clicked

    x, y = position
    tab = Sprite_MpWorldOverview.tab_at(x, y)
    return turn_to(tab, "a click on its tab") if tab
    return if Sprite_MpWorldOverview.inside?(x, y)

    Sound.play_cancel
    close("a click outside the box")
  end

  # Scrolls so the player picked stays in sight and no room is left below the last line, also once
  # the box's height changed.
  #
  # @param lines [Array<Array>] The list, see lines.
  # @param players [Array<Integer>] The lines that are players.
  def self.keep_in_sight(lines, players)
    selected = selected_line(lines)
    rows = Sprite_MpWorldOverview.list_rows
    @scroll = MGQ_MpUi.within(@scroll, 0, most_scroll(lines))
    # The place heading above the first player shows with them.
    top = players.first == selected ? 0 : selected
    @scroll = top if top < @scroll
    @scroll = selected - rows + 1 if selected >= @scroll + rows
  end
end

# The overview's box over the map: the world's name, type and difficulty and the player's party at
# the top, the pages' tabs under them, the page's lines, and on the Players page the menu of the
# player picked.
class Sprite_MpWorldOverview < Sprite
  # The box's id among those the player moves and resizes, see MGQ_MpUi::Layout.
  LAYOUT_ID = :overview

  # The box's name while the player arranges the boxes.
  LAYOUT_NAME = "World overview"

  # Height of one line of the list, the list box's.
  ROW = Sprite_MpListBox::ROW

  # Height of the title, the list box's.
  TITLE = Sprite_MpListBox::TITLE

  # Height of the row of tabs under the title.
  TABS = ROW

  # Top of the page's lines, under the title and the tabs.
  LIST_TOP = TITLE + TABS

  # Height of the hint at the bottom, the list box's.
  HINT_HEIGHT = Sprite_MpListBox::HINT_HEIGHT

  # Room between the box's edge and its texts and lines.
  MARGIN = 8

  # Lines of a page the box shows at least.
  MIN_ROWS = 3

  # The most choices a player's menu holds: one for each of the six scripts that offer something
  # between players, see MGQ_MpActions.offer.
  MENU_ROWS = 6

  # Width of a page's tab; the style's gap lies between two tabs.
  TAB_WIDTH = 100

  # Side of the mark at the Players tab's corner while a player's call waits there and the World
  # page shows.
  CALL_MARK = 6

  # Room between the world's name and the party's size in the title.
  TITLE_GAP = 12

  # Left edge of each column: icons, name, party size, level and story; the story takes the room up
  # to the ping column, which is MGQ_MpOverworld::PING_WIDTH wide at the right edge.
  COLUMNS = { :icons => 8, :name => 60, :party => 232, :level => 284, :story => 340 }

  # Room between the ping column's right edge and the box's.
  PING_INSET = 10

  # Least room of the story column, into which the game squeezes the longest place in the story or
  # call.
  STORY_WIDTH = 142

  # Left edge of each column of the World page: a row's label and value; a raid boss's name
  # (at the label's), tier, gauge, share with its right edge, and who last hurt it. The boss's name
  # takes the room the box has past its least width, which moves the columns right of it along.
  WORLD_COLUMNS = { :label => 8, :value => 140, :tier => 192, :gauge => 240, :share => 334, :share_right => 394, :by => 400 }

  # Least room of who last hurt a raid boss.
  BY_WIDTH = 152

  # Width and height of a raid boss's gauge, and the pixels its frame takes on each side.
  GAUGE_WIDTH = 90
  GAUGE_HEIGHT = 6
  GAUGE_FRAME = 1

  # Width of the menu beside the player picked.
  MENU_WIDTH = 210

  # Width the Players page's columns need, the story column at its least.
  PLAYERS_WIDTH = COLUMNS[:story] + STORY_WIDTH + MGQ_MpUi::Style::GAP + MGQ_MpOverworld::PING_WIDTH + PING_INSET

  # Width the World page's columns need, who last hurt a raid boss at its least.
  WORLD_WIDTH = WORLD_COLUMNS[:by] + BY_WIDTH + MARGIN

  # Width the pages' tabs need.
  TABS_WIDTH = 2 * MARGIN + MGQ_MpWorldOverview::PAGES.size * (TAB_WIDTH + MGQ_MpUi::Style::GAP) - MGQ_MpUi::Style::GAP

  # Narrowest the box gets: what both pages' columns, the tabs and the menu need.
  MIN_WIDTH = [PLAYERS_WIDTH, WORLD_WIDTH, TABS_WIDTH, MENU_WIDTH + 2 * MARGIN].max

  # Lowest the box gets: the title, the tabs, MIN_ROWS lines and the hint, or the longest menu over
  # the hint, which may cover the title then.
  MIN_HEIGHT = [LIST_TOP + MIN_ROWS * ROW + MARGIN + HINT_HEIGHT, MENU_ROWS * ROW + HINT_HEIGHT].max

  # The hint at the bottom of each page, with the overview's hotkey.
  HINTS = {
    :players => ["Left or right: page", "Enter: invite, duel or trade", MGQ_MpUi::Style.close_hint("%s")].join(MGQ_MpUi::Style::HINT_GAP),
    :world => ["Left or right: page", "Up or down: scroll", MGQ_MpUi::Style.close_hint("%s")].join(MGQ_MpUi::Style::HINT_GAP),
  }

  # Tells where the box starts on the screen: the list box's place.
  #
  # @return [Rect] The box.
  def self.default_box
    box = Sprite_MpListBox.box
    Rect.new(box.x, box.y, box.width, box.height)
  end

  # Tells where the box lies on the screen and how large it is: where the player moved and sized
  # it, else where it starts.
  #
  # @return [Rect] The box.
  def self.box
    MGQ_MpUi::Layout.rect(LAYOUT_ID, default_box)
  end

  # Tells how many lines of a page a box of a height shows at once.
  #
  # @param height [Integer] The box's height, the box's own by default.
  # @return [Integer] The lines, at least one.
  def self.list_rows(height = box.height)
    [(height - LIST_TOP - HINT_HEIGHT - MARGIN) / ROW, 1].max
  end

  # Creates the box, hidden.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    box = self.class.box
    self.bitmap = Bitmap.new(box.width, box.height)
    self.x = box.x
    self.y = box.y
    self.z = MGQ_MpUi::Z[:overview]
    self.visible = false
    @shown = nil
  end

  # Reports whether a point of the screen lies in the box.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @return [Boolean] Whether it does.
  def self.inside?(x, y)
    box = self.box
    x >= box.x && x < box.x + box.width && y >= box.y && y < box.y + box.height
  end

  # Finds the line of the list under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  # @return [Integer, nil] The line, nil outside the list.
  def self.line_at(x, y, view)
    return nil unless inside?(x, y)

    box = self.box
    row = (y - box.y - LIST_TOP) / ROW
    return nil if y < box.y + LIST_TOP || row >= list_rows(box.height)

    line = view[:scroll] + row
    line < view[:lines].size ? line : nil
  end

  # Finds the page's tab under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @return [Symbol, nil] The page, see MGQ_MpWorldOverview::PAGES; nil outside the tabs.
  def self.tab_at(x, y)
    box = self.box
    return nil unless y >= box.y + TITLE && y < box.y + LIST_TOP && x >= box.x + MARGIN

    across = x - box.x - MARGIN
    step = TAB_WIDTH + MGQ_MpUi::Style::GAP
    page = MGQ_MpWorldOverview::PAGES[across / step]
    page && across % step < TAB_WIDTH ? page[0] : nil
  end

  # Finds the menu's choice under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  # @return [Integer, nil] The choice, nil outside the menu.
  def self.choice_at(x, y, view)
    box = self.box
    left, top = menu_origin(view, box.width, box.height)
    left += box.x
    top += box.y
    return nil unless x >= left && x < left + MENU_WIDTH && y >= top

    choice = (y - top) / ROW
    choice < view[:menu].size ? choice : nil
  end

  # Tells where the menu sits in the box: right of the list, under the player picked, or above
  # them when it would leave the box; in a box too low for either, as low as it stays whole above
  # the hint.
  #
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  # @param width [Integer] The box's width, the box's own by default.
  # @param height [Integer] The box's height, the box's own by default.
  # @return [Array<Integer>] The menu's left and top edge in the box.
  def self.menu_origin(view, width = box.width, height = box.height)
    row_top = LIST_TOP + (view[:selected] - view[:scroll]) * ROW
    menu_height = view[:menu].size * ROW
    bottom = height - HINT_HEIGHT
    top = row_top + ROW
    top = row_top - menu_height if top + menu_height > bottom
    [width - MENU_WIDTH - MARGIN, [[top, bottom - menu_height].min, 0].max]
  end

  # Places the box where it lies, offers it to the layout and draws the overview while it is open,
  # if it changed.
  def update
    super
    view = MGQ_MpWorldOverview.shown_view
    self.visible = MGQ_MpWorldOverview.open? && !view.nil?
    return unless visible

    box = self.class.box
    place(box)
    MGQ_MpUi::Layout.offer(LAYOUT_ID, box.x, box.y, box.width, box.height, z)
    overview = MGQ_MpWorldOverview
    rows = view[:lines].map do |kind, row, value|
      case kind
      when :player then [row.name, row.level, row.story, row.ping && row.ping[0], row.icon, row.member, row.badge, row.call && row.call[0]]
      when :boss then [row.name, row.tier, overview.share_text(row.left), (row.left * GAUGE_WIDTH).round, row.defeated, row.by]
      when :info then [row, value]
      else row
      end
    end
    drawn = [view[:page], view[:calls], overview.world_name, overview.title_tail, MGQ_MpOverworld.party_badge(:me), rows, view[:selected], view[:scroll],
             view[:menu] && view[:menu].map { |option| [option.text, !option.run.nil?] }, view[:menu_index], box.width, box.height, MGQ_MpUi::Theme.serial]
    return if drawn == @shown

    @shown = drawn
    draw(view)
  rescue => e
    MGQ_MpWorldOverview.log_once(:drawing, "drawing failed: #{e.class}: #{e.message}")
  end

  # Moves the box to where it lies and makes its picture anew once its size changed.
  #
  # @param box [Rect] Where the box lies, see box.
  def place(box)
    self.x = box.x
    self.y = box.y
    return if bitmap.width == box.width && bitmap.height == box.height

    bitmap.dispose
    self.bitmap = Bitmap.new(box.width, box.height)
  end

  # Draws the whole box, as large as its picture.
  #
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  def draw(view)
    style = MGQ_MpUi::Style
    width = bitmap.width
    height = bitmap.height
    bitmap.clear
    style.draw_box(bitmap, 0, 0, width, height)
    draw_title
    draw_tabs(view[:page], view[:calls])
    lines = view[:lines][view[:scroll], self.class.list_rows(height)] || []
    lines.each_with_index { |line, index| draw_line(line, LIST_TOP + index * ROW, view[:scroll] + index == view[:selected]) }
    style.draw_hint(bitmap, MARGIN, height - HINT_HEIGHT, width - 2 * MARGIN, HINT_HEIGHT, HINTS[view[:page]] % MGQ_MpHotkeys.label(:overview))
    draw_menu(view) if view[:menu]
  end

  # Draws the world's name with its type and difficulty, the name cut before the player's party,
  # which keeps the right.
  def draw_title
    style = MGQ_MpUi::Style
    overview = MGQ_MpWorldOverview
    badge = MGQ_MpOverworld.party_badge(:me)
    inset = Sprite_MpListBox::TITLE_INSET
    left = MARGIN + inset
    room = bitmap.width - 2 * left
    if badge
      party = MGQ_MpOverworld.party_title(badge)
      style.use_font(bitmap, style::TITLE_SIZE, style::MEMBER)
      bitmap.draw_text(left, inset, room, TITLE - 2 * inset, party, 2)
      room -= bitmap.text_size(party).width + TITLE_GAP
    end
    style.use_font(bitmap, style::TITLE_SIZE, style::TITLE)
    bitmap.draw_text(left, inset, room, TITLE - 2 * inset, MGQ_MpUi.cut(bitmap, overview.world_name, room, overview.title_tail))
  end

  # Draws the pages' tabs under the title, the page shown on the picked plate and the others on the
  # tab plate, and on the World page a gold mark at the Players tab's corner while a player's call
  # waits there.
  #
  # @param page [Symbol] The page shown.
  # @param calls [Boolean] Whether a player's call waits on the Players page.
  def draw_tabs(page, calls = false)
    style = MGQ_MpUi::Style
    MGQ_MpWorldOverview::PAGES.each_with_index do |(key, title), index|
      x = MARGIN + index * (TAB_WIDTH + style::GAP)
      shown = key == page
      bitmap.fill_rect(x, TITLE, TAB_WIDTH, TABS, shown ? style::PICKED : style::TAB)
      style.use_font(bitmap, style::SMALL_SIZE, shown ? style::TEXT : style::DIM)
      bitmap.draw_text(x, TITLE, TAB_WIDTH, TABS, title, 1)
      bitmap.fill_rect(x + TAB_WIDTH - CALL_MARK - style::GAP, TITLE + style::GAP, CALL_MARK, CALL_MARK, style::GOLD) if calls && !shown && key == :players
    end
  end

  # Draws one line of a page: a heading, a player, a row of the World page or a raid boss.
  #
  # @param line [Array] [:place, name], [:player, row], [:info, label, value] or [:boss, boss].
  # @param y [Integer] The line's top.
  # @param picked [Boolean] Whether it is the player picked.
  def draw_line(line, y, picked)
    kind, value, extra = line
    case kind
    when :place then draw_heading(value, y)
    when :info then draw_info(value, extra, y)
    when :boss then draw_boss(value, y)
    else draw_player(value, y, picked)
    end
  end

  # Draws a heading: a place's, or the raid bosses'.
  #
  # @param text [String] The heading.
  # @param y [Integer] The line's top.
  def draw_heading(text, y)
    style = MGQ_MpUi::Style
    style.use_font(bitmap, style::TEXT_SIZE, style::HEADING)
    bitmap.draw_text(MARGIN, y, bitmap.width - 2 * MARGIN, ROW, text)
  end

  # Draws a player: their icons, their name in their color, their party's size, their level, their
  # place in the story or their call, which takes the room up to the ping, and their ping at the
  # right edge.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @param y [Integer] The line's top.
  # @param picked [Boolean] Whether they are picked.
  def draw_player(row, y, picked)
    style = MGQ_MpUi::Style
    inset = Sprite_MpListBox::PICK_INSET
    bitmap.fill_rect(inset, y, bitmap.width - 2 * inset, ROW, style::PICKED) if picked
    draw_icons(row, y)
    color = MGQ_MpUi::PlayerColor.of(row.player, row.member)
    style.use_font(bitmap, style::TEXT_SIZE, color)
    name_width = COLUMNS[:party] - COLUMNS[:name] - style::GAP
    bitmap.draw_text(COLUMNS[:name], y, name_width, ROW, MGQ_MpUi.cut(bitmap, row.name, name_width))
    style.use_font(bitmap, style::SMALL_SIZE, color)
    bitmap.draw_text(COLUMNS[:party], y, COLUMNS[:level] - COLUMNS[:party], ROW, row.badge[0]) if row.badge
    style.use_font(bitmap, style::SMALL_SIZE, style::TEXT)
    bitmap.draw_text(COLUMNS[:level], y, COLUMNS[:story] - COLUMNS[:level], ROW, row.level)
    text, text_color = row.call || [row.story, style::TEXT]
    style.use_font(bitmap, style::SMALL_SIZE, text_color)
    ping_left = bitmap.width - PING_INSET - MGQ_MpOverworld::PING_WIDTH
    bitmap.draw_text(COLUMNS[:story], y, ping_left - style::GAP - COLUMNS[:story], ROW, text)
    MGQ_MpOverworld.draw_ping(bitmap, row.ping, ping_left, y, ROW) if row.ping
  end

  # Draws a row of the World page: its label and its value, which takes the room up to the right
  # edge.
  #
  # @param label [String] The label.
  # @param value [String] The value.
  # @param y [Integer] The line's top.
  def draw_info(label, value, y)
    style = MGQ_MpUi::Style
    columns = WORLD_COLUMNS
    style.use_font(bitmap, style::TEXT_SIZE, style::HEADING)
    bitmap.draw_text(columns[:label], y, columns[:value] - columns[:label] - style::GAP, ROW, label)
    style.use_font(bitmap, style::TEXT_SIZE, style::TEXT)
    width = bitmap.width - MARGIN - columns[:value]
    bitmap.draw_text(columns[:value], y, width, ROW, MGQ_MpUi.cut(bitmap, value, width))
  end

  # Draws a raid boss: its name, dimmed once defeated, its tier, its gauge, its share left or
  # Defeated, and who last hurt it; the name takes the room the box has past WORLD_WIDTH.
  #
  # @param boss [MGQ_MpWorldOverview::Boss] The boss.
  # @param y [Integer] The line's top.
  def draw_boss(boss, y)
    style = MGQ_MpUi::Style
    overview = MGQ_MpWorldOverview
    extra = [bitmap.width - WORLD_WIDTH, 0].max
    columns = Hash[WORLD_COLUMNS.map { |key, left| [key, key == :label ? left : left + extra] }]
    style.use_font(bitmap, style::TEXT_SIZE, boss.defeated ? style::DIM : style::TEXT)
    name_width = columns[:tier] - columns[:label] - style::GAP
    bitmap.draw_text(columns[:label], y, name_width, ROW, MGQ_MpUi.cut(bitmap, boss.name, name_width))
    style.use_font(bitmap, style::TINY_SIZE, style::DIM)
    bitmap.draw_text(columns[:tier], y, columns[:gauge] - columns[:tier] - style::GAP, ROW, overview::TIER % boss.tier) if boss.tier
    draw_gauge(columns[:gauge], y + (ROW - GAUGE_HEIGHT) / 2, boss.defeated ? 0.0 : boss.left)
    style.use_font(bitmap, style::TINY_SIZE, boss.defeated ? style::BAD : style::TEXT)
    bitmap.draw_text(columns[:share], y, columns[:share_right] - columns[:share], ROW, boss.defeated ? overview::DEFEATED : overview.share_text(boss.left), 2)
    return unless boss.by

    style.use_font(bitmap, style::TINY_SIZE, style::DIM)
    by_width = bitmap.width - MARGIN - columns[:by]
    bitmap.draw_text(columns[:by], y, by_width, ROW, MGQ_MpUi.cut(bitmap, overview::LAST_HURT_BY % boss.by, by_width))
  end

  # Draws a thin gauge of a raid boss's HP: its frame in the edge color, its empty part in the well
  # color, the share left in the bad color.
  #
  # @param x [Integer] Its left.
  # @param y [Integer] Its top.
  # @param left [Float] The share of the HP left, 0 to 1.
  def draw_gauge(x, y, left)
    style = MGQ_MpUi::Style
    inner_width = GAUGE_WIDTH - 2 * GAUGE_FRAME
    inner_height = GAUGE_HEIGHT - 2 * GAUGE_FRAME
    bitmap.fill_rect(x, y, GAUGE_WIDTH, GAUGE_HEIGHT, style::EDGE)
    bitmap.fill_rect(x + GAUGE_FRAME, y + GAUGE_FRAME, inner_width, inner_height, style::WELL)
    filled = (inner_width * MGQ_MpUi.within(left.to_f, 0.0, 1.0)).round
    bitmap.fill_rect(x + GAUGE_FRAME, y + GAUGE_FRAME, filled, inner_height, style::BAD) if filled > 0
  end

  # Draws the icon of what a player does and the crown of a party's leader.
  #
  # @param row [MGQ_MpWorldOverview::Row] The player.
  # @param y [Integer] The line's top.
  def draw_icons(row, y)
    icons = [row.icon, row.badge && row.badge[1] ? MGQ_MpOverworld::CROWN_ICON : nil].compact
    icons.each_with_index { |icon, index| MGQ_MpUi.draw_icon(bitmap, icon, COLUMNS[:icons] + index * MGQ_MpUi::ICON_STEP, y) }
  end

  # Draws the menu beside the player picked, in its own framed box over the overview's, the choice
  # picked on the picked plate inside the frame.
  #
  # @param view [Hash] What the overview shows, see MGQ_MpWorldOverview.view.
  def draw_menu(view)
    style = MGQ_MpUi::Style
    left, top = self.class.menu_origin(view, bitmap.width, bitmap.height)
    height = view[:menu].size * ROW
    frame = style.frame_width
    style.draw_box(bitmap, left, top, MENU_WIDTH, height)
    view[:menu].each_with_index do |option, index|
      y = top + index * ROW
      if index == view[:menu_index]
        plate_top = [y, top + frame].max
        bitmap.fill_rect(left + frame, plate_top, MENU_WIDTH - 2 * frame, [y + ROW, top + height - frame].min - plate_top, style::PICKED)
      end
      style.use_font(bitmap, style::TEXT_SIZE, option.run ? style::TEXT : style::DIM)
      bitmap.draw_text(left + MARGIN, y, MENU_WIDTH - 2 * MARGIN, ROW, option.text)
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

# The overview's box among those the player moves and resizes, through ui_layout.rbx.

begin
  MGQ_MpUi::Layout.register(Sprite_MpWorldOverview::LAYOUT_ID, Sprite_MpWorldOverview::LAYOUT_NAME, Sprite_MpWorldOverview::MIN_WIDTH,
                            Sprite_MpWorldOverview::MIN_HEIGHT, :both)
rescue => e
  MGQ_MpWorldOverview.log("layout FAILED: #{e.class}: #{e.message}")
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
