#----------------------------------------------------------------
#  world_overview.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Added the Quests page with a Quest Portraits setting
#                            - Kept Amira's side quests out of the objective
#                            - Narrowed the tabs
#                            - Showed the catch-up experience on the Levels page
#                            - Logged a refused hotkey through MGQ_MpHotkeys.log_refusal, not while the player types
#                            - Counted Part 2 from progress 19 and Part 3 from 34, as the world's story and the relay do, instead of from 20 and 40
#                            - Read the map's viewport through MGQ_MpGame
#      Paulinchen  2026-10-11: Added the Levels page of a Raid World: the level the catch-up counts and, under a heading per level, what it hands out that the world already unlocked, moving on from a part, companions and Makina, each marked Done or Due
#                            - Told the others the highest level of the player's formation, Luka included, instead of every companion's, keeping the last one read during a co-op battle
#                            - Showed a Raid World's objective on the World page under the story, as Amira tells it asked for information, wrapped over as many lines as it needs
#                            - Listed a Raid World's party for the party box with each member's Frontline level, wherever they are
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
# held (see ui_layout.rbx), with pages turned with Left and Right or a click on their tabs.
# The Players page
# lists every player of the world online, grouped by where they are, with their formation's highest
# level, their place in the story and their ping. A player picked with the arrows and confirm, or
# with the mouse, opens a menu of what the scripts offer, such as party invites, duels and trades;
# a player's row shows their invite, challenge or offer that reaches the player. The World page
# shows the world itself: its name, type, difficulty, players, story and in a Raid World the
# story's objective and every raid boss with how much of its HP the world left it. The Quests page
# shows the main, side and companion quests under way. A Raid World's
# Levels page shows by level what the catch-up hands out that the world already unlocked (see
# world_catchup.rbx). The map keeps running behind it.
#
# It also lists the player's party for the party box of ui_party_box.rbx, and in a Raid World
# everyone on the player's map for the map box that replaces it.
#
# It also tells the others where the player is, their formation's highest level and their place in
# the story, in the state overworld_sync.rbx sends, and in a Raid World their Frontline's highest
# level, which the map box shows.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldOverview
  # Frames between two readings of the formation's highest level and the place in the story, three
  # seconds, since the state is compared every frame.
  READ_FRAMES = 180

  # The story's progress variable, by its name in the translation and in the untranslated game.
  PROGRESS = ["Overall Events Progress", "総合イベント進行度"]

  # First progress of each part, latest first, as MGQ_MpWorldStory.part_of and the relay count them:
  # Part 2 from Tartarus Escape, Part 3 from the Middle Chapter's epilogue, so the Great Decision
  # lies in Part 3.
  PART_STARTS = [[3, MGQ_MpWorldStory::PART_THREE], [2, MGQ_MpWorldStory::PART_TWO], [1, 0]]

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
  # the players online, the world itself, the quests under way, and in a Raid World what the
  # catch-up hands out by level.
  PAGES = [[:players, "Players"], [:world, "World"], [:quests, "Quests"], [:levels, "Levels"]]

  # The pages only a Raid World shows.
  RAID_PAGES = [:levels]

  # The label of the Levels page's first row, the level the catch-up counts.
  YOUR_LEVEL = "Your level"

  # How the Levels page heads what comes at a level.
  LEVEL_HEADING = "Level %d"

  # How the Levels page heads the formation's catch-up experience, with and without a level it
  # holds up to.
  EXP_HEADING = "Catch-up EXP until level %d"
  EXP_HEADING_NONE = "Catch-up EXP"

  # What the Levels page says of a formation member's catch-up experience, and while the world's
  # story has not raised the level cap yet.
  EXP_VALUE = "Level %d, %s EXP"
  NO_CATCH_UP = "Starts once the world's story raises the level cap."

  # What the Levels page says while the world unlocked nothing yet.
  NOTHING_UNLOCKED = "Nothing to catch up with yet."

  # What the Levels page calls each kind of unlock, see MGQ_MpWorldCatchup::Unlock.
  UNLOCK_KINDS = { :story => "Story", :companion => "Companion", :makina => "Makina" }

  # What the Levels page says of an unlock the player has, and of one whose level they reached,
  # which comes at the catch-up's next check.
  DONE = "Done"
  DUE = "Due"

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
  WORLD_LABELS = { :name => "World", :type => "Type", :difficulty => "Difficulty", :players => "Players", :story => "Story", :objective => "Objective" }

  # The common event of Amira the Informant, whose first words on the information asked for name
  # the story's current objective (see objective_text).
  OBJECTIVE_EVENT = 108

  # The variable of Amira's information network ("Pornof Rabbit Events"), whose branch at the top
  # of her event keeps every hint back until the rabbit side quest moved on; the World page passes
  # it, since it shows the story's objective, not whether Amira would tell it.
  NETWORK_VARIABLE = 1009

  # Common events deep the objective follows the calls of Amira's event.
  OBJECTIVE_DEPTH = 3

  # Jumps to a label the objective follows at most, so labels that jump in a circle end.
  OBJECTIVE_JUMPS = 50

  # Amira's lists of side quests, which her event calls after the objective: the first until the
  # Chaos route's step CHAOS_SIDE_STEP, the second from it.
  SIDE_EVENTS = [131, 135]

  # The Chaos route's variable and the step from which Amira tells the second list of SIDE_EVENTS.
  CHAOS_ROUTE = 1143
  CHAOS_SIDE_STEP = 21

  # The Pocket Castle's bulletin board, where companions leave their requests: its map and event.
  BOARD_MAP = 228
  BOARD_EVENT = 37

  # The variable Amira's lists and the board set to 1 before each entry they tell, which marks
  # where an entry starts.
  QUEST_COUNT = 11

  # Amira's actor, whose Library picture shows faintly behind the Quests page.
  AMIRA = 540

  # How opaque that picture is, out of 255.
  BACKDROP_OPACITY = 36

  # The Quests page's list headings with how many quests each holds, and what it says under one
  # with none.
  QUEST_HEADINGS = { :side => "Side quests (%d)", :companion => "Companion quests (%d)" }
  NO_QUESTS = "None right now."

  # The reading pane's title of each kind of quest.
  QUEST_TITLES = { :main => "Main quest", :side => "Side quest %d", :companion => "Request" }

  # How the reading pane joins a quest's title and who tells it.
  TITLE_JOIN = " · "

  # The end of a sentence: marks followed by a space or the text's end, or a Japanese end.
  SENTENCE_END = /[.!?♪…]+["'”’)」』）]*(?=\s|\z)|[。！？]+[」』）]*/

  # Words before a period that end no sentence.
  ABBREVIATIONS = %w[Mt Dr Mr Mrs Ms St]

  # The setting in Player.ini that keeps how the Quests page shows Amira and the companions, and
  # its choices, the first the one until the player picks another.
  PORTRAIT_SETTING = "quest_portraits"
  SPRITES = "Sprites"
  FACES = "Faces"
  PORTRAITS = [SPRITES, FACES]

  # The Mod Config row of that setting: its key, name and help.
  PORTRAIT_OPTION = :mp_quest_portraits
  PORTRAIT_OPTION_NAME = "Quest Portraits"
  PORTRAIT_OPTION_HELP = "How the Quests page of the World overview shows Amira and the companions asking for help:\n" \
                         "Sprites by their map sprite, Faces by their face."

  # How a character looks: their map sprite's sheet and place, and their face's sheet and place.
  Looks = Struct.new(:character_name, :character_index, :face_name, :face_index)

  # A quest: its kind (:main, :side or :companion), who tells it, each message as plain text, a
  # side quest's number, and how a companion asking for help looks.
  Quest = Struct.new(:kind, :speaker, :texts, :number, :looks) do
    # @return [String] The first sentence of its first message.
    def first
      MGQ_MpWorldOverview.first_sentence(texts.first)
    end

    # @return [String] What the reading pane titles it with, such as "Side quest 2 · Amira".
    def title
      name = MGQ_MpWorldOverview::QUEST_TITLES[kind].to_s % number.to_i
      speaker ? "#{name}#{MGQ_MpWorldOverview::TITLE_JOIN}#{speaker}" : name
    end
  end

  # A speaker's name at a message's start: the translation's "\n<Name>" and the untranslated
  # game's "【Name】".
  SPEAKER = /\\n<[^>]*>|\A\s*【[^】]*】/

  # The text codes of a message, which the World page leaves out: a code with its argument, such as
  # "\C[3]", one of letters, such as "\fb", and one of a sign, such as "\*".
  TEXT_CODES = [/\\[A-Za-z]+\[[^\]]*\]/, /\\[A-Za-z]+/, /\\./]

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
  # @!attribute level [String] Their formation's highest level, in the map box their Frontline's, empty
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
      MGQ_MpHotkeys.log_refusal(:overview, "not on a quiet map in a world, or the chat or a wheel is open")
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
  # @return [Symbol] :players, :world or :levels, see PAGES.
  def self.page
    @page
  end

  # Lists the pages the world shows: every page in a Raid World, else those of RAID_PAGES left out.
  #
  # @return [Array<Array>] The pages with their tabs' titles, see PAGES.
  def self.pages
    MGQ_MpCoop::Scope.raid? ? PAGES : PAGES.reject { |key, _| RAID_PAGES.include?(key) }
  end

  # Turns to a page, closing the menu, which belongs to the Players page, and showing the new
  # page from its top. Nothing for the page shown already or one the world does not show.
  #
  # @param page [Symbol] The page, see pages.
  # @param via [String] What turned it, for the log.
  def self.turn_to(page, via)
    title = pages.assoc(page)
    return unless title && page != @page

    @page = page
    @menu = nil
    @world_scroll = 0
    @level_lines_at = nil
    @quests_at = nil
    @quest_pick = 0
    @quest_scroll = 0
    @pane_scroll = 0
    Sound.play_cursor
    log("turned to the #{title[1]} page through #{via}")
  end

  # Turns a page on, or back, round past the ends.
  #
  # @param step [Integer] 1 for the next page, -1 for the one before.
  # @param via [String] What turned it, for the log.
  def self.turn(step, via)
    shown = pages
    index = shown.index { |page, _| page == @page }.to_i
    turn_to(shown[(index + step) % shown.size][0], via)
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
  # its story, the story's objective and its raid bosses under a heading per section of the story.
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
    lines.concat(objective_lines)
    boss_sections.each do |section, bosses|
      lines << [:place, BOSSES_HEADING % section]
      lines.concat(bosses.map { |boss| [:boss, boss] })
    end
    lines
  end

  # Lays the story's objective out under its label, wrapped to the World page's value column; none
  # while no objective is known.
  #
  # @return [Array<Array>] The lines, [:info, label, value], the label on the first alone.
  def self.objective_lines
    text = objective_text
    return [] unless text

    Sprite_MpWorldOverview.value_lines(text).each_with_index.map { |row, index| [:info, index == 0 ? WORLD_LABELS[:objective] : "", row] }
  end

  # Reads the story's current objective as Amira tells it asked for information (OBJECTIVE_EVENT):
  # the first message her event shows in a branch, as the game would run it with the player's
  # story now, a Raid World's laid over it. Her own opening words stand at the event's top, and
  # her network's branch is passed (see NETWORK_VARIABLE). Read every READ_FRAMES.
  #
  # @return [String, nil] The objective, as plain text; nil when her event or a message is missing.
  def self.objective_text
    return @objective if @objective_at && Graphics.frame_count - @objective_at < READ_FRAMES && Graphics.frame_count >= @objective_at

    @objective_at = Graphics.frame_count
    event = $data_common_events && $data_common_events[OBJECTIVE_EVENT]
    @objective = event ? first_message(event.list || [], 0) : nil
  rescue => e
    log_once(:objective, "reading the story's objective failed: #{e.class}: #{e.message}")
    @objective = nil
  end

  # Finds the first message a list of commands shows as the game would run it now: inside a branch
  # of Amira's own event, anywhere in the common events it calls but her side quests' lists (see
  # walk).
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param depth [Integer] How many calls deep the list is, 0 for Amira's event.
  # @return [String, nil] The message, as plain text; nil when it shows none.
  def self.first_message(list, depth)
    found = nil
    walk(list, depth, false) do |kind, text, indent, level, _speaker|
      next SIDE_EVENTS.include?(text) ? :skip : nil if kind == :call
      next unless kind == :message && !text.empty? && (indent > 0 || level > 0)

      found = text
      :stop
    end
    found
  end

  # Runs through a list of commands as the game would run it now, without running any.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param depth [Integer] How many calls deep the list is.
  # @param network [Boolean] Whether the branches on Amira's network hold as the game compares
  #   them, see branch_holds?.
  # @yieldparam kind [Symbol] :message (a message shown), :mark (the start of a quest, see
  #   QUEST_COUNT) or :call (a common event about to be called).
  # @yieldparam value [String, Integer, nil] The message as plain text, or the common event.
  # @yieldparam indent [Integer] The command's indent.
  # @yieldparam level [Integer] How many calls deep it is.
  # @yieldparam speaker [String, nil] The message's speaker.
  # @yieldreturn [Symbol, nil] :stop ends the walk, :skip leaves a call out.
  # @return [Symbol, nil] :stop when a block ended the walk.
  def self.walk(list, depth, network, &block)
    index = 0
    jumps = 0
    skip = nil
    held = {}
    while index < list.size
      command = list[index]
      index += 1
      indent = command.indent
      next if skip && indent > skip

      skip = nil
      params = command.parameters
      case command.code
      when 111
        held[indent] = branch_holds?(params, network)
        skip = indent unless held[indent]
      when 411 then skip = indent if held[indent]
      when 402 then skip = indent unless params[0] == 0
      when 403 then skip = indent
      when 101
        return :stop if block.call(:message, plain_message(list, index), indent, depth, speaker_of(list, index)) == :stop
      when 122
        return :stop if quest_mark?(params) && block.call(:mark, nil, indent, depth, nil) == :stop
      when 117
        called = depth < OBJECTIVE_DEPTH ? $data_common_events[params[0]] : nil
        next unless called

        answer = block.call(:call, params[0], indent, depth, nil)
        return :stop if answer == :stop
        return :stop if answer != :skip && walk(called.list || [], depth + 1, network, &block) == :stop
      when 119
        jumps += 1
        label = jumps <= OBJECTIVE_JUMPS ? list.index { |other| other.code == 118 && other.parameters[0] == params[0] } : nil
        return nil unless label

        index = label + 1
      when 115 then return :stop
      end
    end
    nil
  end

  # Reports whether a command marks the start of a quest (see QUEST_COUNT).
  #
  # @param params [Array] The parameters of a variable's command.
  # @return [Boolean] Whether it does.
  def self.quest_mark?(params)
    params[0] == QUEST_COUNT && params[1] == QUEST_COUNT && params[2] == 0 && params[3] == 0 && params[4] == 1
  end

  # Reports whether a branch holds now: on a switch, a variable, a party member, an item or one of
  # the game's own checks; any other branch does not.
  #
  # Amira's network counts only where asked, since the objective shows whether she would tell it or
  # not.
  #
  # @param params [Array] The branch's parameters.
  # @param network [Boolean] Whether a branch on Amira's network compares as the game does.
  # @return [Boolean] Whether it holds.
  def self.branch_holds?(params, network = false)
    case params[0]
    when 0 then $game_switches[params[1]] == (params[2] == 0)
    when 1
      return false if params[1] == NETWORK_VARIABLE && !network

      value = $game_variables[params[1]].to_i
      other = params[2] == 0 ? params[3].to_i : $game_variables[params[3]].to_i
      [value == other, value >= other, value <= other, value > other, value < other, value != other][params[4]] ? true : false
    when 4 then params[2] == 0 && $game_party.all_members.any? { |actor| actor.id == params[1] }
    when 8
      item = $data_items[params[1]]
      item ? $game_party.has_item?(item) : false
    when 12 then check_holds?(params[1].to_s)
    else false
    end
  end

  # Reports whether one of the game's own checks holds, such as "actor_class_level_over?(1, 151, 10)".
  #
  # Only question methods with whole numbers run, since any other script might change the game.
  #
  # @param script [String] The branch's script.
  # @return [Boolean] Whether it holds; false for any other script.
  def self.check_holds?(script)
    match = script.strip.match(/\A(\w+\?)\(([\d,\s]*)\)\z/)
    return false unless match && Game_Interpreter.method_defined?(match[1])

    Game_Interpreter.new.send(match[1], *match[2].split(",").map { |number| number.to_i }) ? true : false
  rescue => e
    log_once([:check, script], "a quest's check \"#{script}\" failed: #{e.class}: #{e.message}")
    false
  end

  # Reads the message whose lines follow a command as plain text: one line, without the speaker's
  # name and the text codes, a variable's and a companion's code replaced by its value and name.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The place of the message's first line.
  # @return [String] The text.
  def self.plain_message(list, index)
    lines = []
    while list[index] && list[index].code == 401
      lines << list[index].parameters[0].to_s
      index += 1
    end
    text = lines.join(" ").gsub(SPEAKER, "")
    text = text.gsub(/\\V\[(\d+)\]/i) { $game_variables[$1.to_i].to_s }
    text = text.gsub(/\\N\[(\d+)\]/i) { (actor = $game_actors[$1.to_i]) ? actor.name.to_s : "" }
    TEXT_CODES.inject(text) { |plain, code| plain.gsub(code, "") }.gsub(/\s+/, " ").strip
  end

  # Reads the speaker's name at a message's start.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The place of the message's first line.
  # @return [String, nil] The name, without text codes; nil for a message without a speaker.
  def self.speaker_of(list, index)
    line = list[index] && list[index].code == 401 ? list[index].parameters[0].to_s : ""
    name = line[/\\n<([^>]*)>/, 1] || line[/\A\s*【([^】]*)】/, 1]
    name = TEXT_CODES.inject(name) { |plain, code| plain.gsub(code, "") }.strip if name
    name && !name.empty? ? name : nil
  end

  # Reads the quests under way: the main quest, and the list of side and companion quests under a
  # heading each with how many there are. Read every READ_FRAMES.
  #
  # @return [Hash] :main (a Quest or nil), :rows (each [:head, text], [:quest, quest] or [:none,
  #   text]) and :picks (the main quest, if any, then every quest of the rows).
  def self.quests
    return @quests if @quests_at && Graphics.frame_count - @quests_at < READ_FRAMES && Graphics.frame_count >= @quests_at

    @quests_at = Graphics.frame_count
    main = main_quest
    rows = []
    [[:side, side_quests], [:companion, companion_quests]].each do |kind, list|
      rows << [:head, QUEST_HEADINGS[kind] % list.size]
      rows << [:none, NO_QUESTS] if list.empty?
      list.each { |quest| rows << [:quest, quest] }
    end
    picks = (main ? [main] : []) + rows.select { |kind, _| kind == :quest }.map { |_, quest| quest }
    # The same quests read again stay the same objects, which the drawing goes by.
    return @quests if @quests && @quests[:rows] == rows && @quests[:main] == main

    @quests = { :main => main, :rows => rows, :picks => picks }
  rescue => e
    log_once(:quests, "reading the quests failed: #{e.class}: #{e.message}")
    @quests = { :main => nil, :rows => [], :picks => [] }
  end

  # Finds a text's first sentence: up to the first end of a sentence followed by a space or the
  # text's end, or a Japanese one.
  #
  # Abbreviations such as "Mt." end no sentence, so "Mt. Saint Amos" stays whole.
  #
  # @param text [String] The text.
  # @return [String] The sentence; the whole text without an end.
  def self.first_sentence(text)
    text = text.to_s.strip
    offset = 0
    while (match = SENTENCE_END.match(text, offset))
      word = text[0, match.begin(0)][/\S+\z/].to_s
      return text[0, match.end(0)].strip unless ABBREVIATIONS.include?(word)

      offset = match.end(0)
    end
    text
  end

  # Reads the main quest: every message Amira's objective shows now, her side quests left out.
  #
  # @return [Quest, nil] The quest; nil when she tells none.
  def self.main_quest
    event = $data_common_events && $data_common_events[OBJECTIVE_EVENT]
    return nil unless event

    texts = []
    speaker = nil
    walk(event.list || [], 0, false) do |kind, value, indent, level, who|
      if kind == :call
        SIDE_EVENTS.include?(value) ? :skip : nil
      elsif kind == :message && !value.empty? && (indent > 0 || level > 0)
        speaker ||= who
        texts << value
        nil
      end
    end
    texts.empty? ? nil : Quest.new(:main, speaker, texts, nil)
  end

  # Reads the side quests Amira tells now, from her list for the story's place (see SIDE_EVENTS).
  #
  # @return [Array<Quest>] The quests.
  def self.side_quests
    id = SIDE_EVENTS[$game_variables[CHAOS_ROUTE].to_i >= CHAOS_SIDE_STEP ? 1 : 0]
    event = $data_common_events && $data_common_events[id]
    event ? quests_of(event.list || [], :side) : []
  end

  # Reads the companions' requests on the Pocket Castle's board now.
  #
  # @return [Array<Quest>] The requests, each by the companion who left it.
  def self.companion_quests
    quests_of(board_list, :companion)
  end

  # Reads the board's list of commands, once a session.
  #
  # @return [Array<RPG::EventCommand>] The commands; none when the map or the event is missing.
  def self.board_list
    return @board_list if @board_list

    map = load_data(format("Data/Map%03d.rvdata2", BOARD_MAP))
    event = map.events[BOARD_EVENT]
    page = event && event.pages.find { |candidate| candidate.list.any? { |command| command.code == 122 && quest_mark?(command.parameters) } }
    log("the Pocket Castle's board (map #{BOARD_MAP}, event #{BOARD_EVENT}) has no entries to read") unless page
    @board_list = page ? page.list : []
  rescue => e
    log_once(:board, "reading the Pocket Castle's board failed: #{e.class}: #{e.message}")
    @board_list = []
  end

  # Reads the quests a list tells now, each from its mark (see quest_mark?) to the end of its block.
  #
  # Only the first speaker's messages count, so the others' remarks in between stay out.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param kind [Symbol] The quests' kind, :side (numbered) or :companion.
  # @return [Array<Quest>] The entries that say anything.
  def self.quests_of(list, kind)
    entries = []
    entry = nil
    walk(list, 0, true) do |kind, value, indent, level, speaker|
      if kind == :mark
        entry = { :indent => indent, :level => level, :speaker => nil, :texts => [] }
        entries << entry
      elsif kind == :message && entry
        if level < entry[:level] || (level == entry[:level] && indent < entry[:indent])
          entry = nil
        elsif !value.empty?
          entry[:speaker] ||= speaker
          entry[:texts] << value if speaker == entry[:speaker]
        end
      end
      nil
    end
    told = entries.reject { |found| found[:texts].empty? }
    told.each_with_index.map do |found, index|
      Quest.new(kind, found[:speaker], found[:texts], kind == :side ? index + 1 : nil, kind == :companion ? looks_of(found[:speaker]) : nil)
    end
  end

  # Finds how a companion looks by their name: the one of that name in the party, else the first
  # character of the game with that name and a map sprite.
  #
  # Companions with several forms share a name, so the party's form comes first.
  #
  # @param name [String, nil] The companion's name.
  # @return [Looks, nil] How they look; nil for a name no character has.
  def self.looks_of(name)
    return nil if name.to_s.empty?

    members = $game_party.all_members + ($game_party.respond_to?(:stand_members) ? $game_party.stand_members.to_a : [])
    member = members.find { |actor| actor && actor.name.to_s == name && !actor.character_name.to_s.empty? }
    return looks(member) if member

    @looks_by_name ||= ($data_actors || []).compact.reverse.each_with_object({}) do |actor, found|
      found[actor.name.to_s] = actor unless actor.character_name.to_s.empty?
    end
    actor = @looks_by_name[name]
    actor ? looks(actor) : nil
  rescue => e
    log_once([:looks, name], "finding how #{name} looks failed: #{e.class}: #{e.message}")
    nil
  end

  # Reads how a character looks.
  #
  # @param actor [Game_Actor, RPG::Actor] The character.
  # @return [Looks] How they look.
  def self.looks(actor)
    Looks.new(actor.character_name.to_s, actor.character_index.to_i, actor.face_name.to_s, actor.face_index.to_i)
  end

  # Tells how the Quests page shows Amira and the companions, as Player.ini keeps it.
  #
  # @return [String] SPRITES or FACES.
  def self.portraits
    @portraits ||= PORTRAITS.find { |choice| choice.downcase == MGQ_Multiplayer::Player.setting(PORTRAIT_SETTING).to_s.strip.downcase } || PORTRAITS.first
  end

  # Picks how the Quests page shows Amira and the companions and keeps it in Player.ini.
  #
  # @param choice [String] SPRITES or FACES; another keeps the first.
  def self.choose_portraits(choice)
    @portraits = PORTRAITS.include?(choice) ? choice : PORTRAITS.first
    MGQ_Multiplayer::Player.store(PORTRAIT_SETTING, @portraits)
    log("the Quests page shows #{@portraits.downcase}")
  rescue => e
    log("keeping the Quests page's portraits FAILED: #{e.class}: #{e.message}")
  end

  # Offers the Quests page's portraits as a row of the Mod Config, kept in Player.ini.
  def self.add_options
    added = MGQ_MpUi.add_option(PORTRAIT_OPTION, PORTRAIT_OPTION_NAME, PORTRAIT_OPTION_HELP, lambda { PORTRAITS }, lambda { portraits },
                                lambda { |choice| choose_portraits(choice) })
    log(added ? "added the Quest Portraits to the Mod Config" : "no Quest Portraits in the Mod Config: it needs a Mod Config Remake that knows rows the mod keeps")
  end

  # Finds the picture that shows faintly behind the Quests page: Amira's in the Library.
  #
  # @return [Bitmap, nil] The picture; nil when the game has none.
  def self.backdrop
    return @backdrop if @backdrop && !@backdrop.disposed?
    return nil if @backdrop_missing

    image = defined?(NWConst::Library::ACTOR_IMAGE) ? NWConst::Library::ACTOR_IMAGE[AMIRA] : nil
    @backdrop_missing = !image.is_a?(Array)
    @backdrop = @backdrop_missing ? nil : Cache.load_bitmap(image[0].to_s, image[1].to_s)
  rescue => e
    log_once(:backdrop, "loading Amira's picture failed: #{e.class}: #{e.message}")
    @backdrop_missing = true
    @backdrop = nil
  end

  # Lays out the formation's catch-up experience: the level it holds up to, then each member's
  # level and factor (see MGQ_MpWorldCatchupExp).
  #
  # @return [Array<Array>] Each line: [:place, heading] or [:info, label, value].
  def self.exp_lines
    target = MGQ_MpWorldCatchupExp.target
    return [[:place, EXP_HEADING_NONE], [:info, "", NO_CATCH_UP]] unless target

    members = $game_party.battle_members.map do |actor|
      factor = MGQ_MpWorldCatchupExp.factor_for(actor.base_level, target)
      [:info, actor.name, EXP_VALUE % [actor.base_level, MGQ_MpWorldCatchupExp.factor_text(factor)]]
    end
    [[:place, EXP_HEADING % target]] + members
  end

  # Lays the Levels page out: the level the catch-up counts, then by level what it hands out that
  # the world already unlocked, under a heading per level (see MGQ_MpWorldCatchup.unlocks). Read
  # every READ_FRAMES.
  #
  # @return [Array<Array>] Each line: [:info, label, value], [:place, heading] or [:unlock, unlock].
  def self.level_lines
    return @level_lines if @level_lines_at && Graphics.frame_count - @level_lines_at < READ_FRAMES && Graphics.frame_count >= @level_lines_at

    @level_lines_at = Graphics.frame_count
    level = MGQ_MpWorldCatchup.counted_level
    lines = [[:info, YOUR_LEVEL, level ? level.to_s : ""]]
    lines.concat(exp_lines)
    unlocks = MGQ_MpWorldCatchup.unlocks
    lines << [:info, "", NOTHING_UNLOCKED] if unlocks.empty?
    unlocks.chunk { |unlock| unlock.level }.each do |at, group|
      lines << [:place, LEVEL_HEADING % at]
      lines.concat(group.map { |unlock| [:unlock, unlock] })
    end
    @level_lines = lines
  rescue => e
    log_once(:level_lines, "laying out the Levels page failed: #{e.class}: #{e.message}")
    @level_lines = []
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
  # scene; reads the player's formation's highest level and place in the story every READ_FRAMES.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    close(in_world ? "the map was left" : "the world closed") unless in_world && SceneManager.scene.is_a?(Scene_Map)
    return forget unless in_world

    @frames -= 1
    return if @frames > 0

    @frames = READ_FRAMES
    level = formation_level
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
  # @return [Hash] Where the player is, their formation's highest level and their place in the story,
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

  # Reads the highest base level of the player's formation, Luka included.
  #
  # During a co-op battle it keeps the last level read, since the battle's party and its level sync
  # stand in for the player's own characters then.
  #
  # @return [Integer] The level, 0 without characters.
  def self.formation_level
    return @level.to_i if defined?(MGQ_MpBattlesCoop) && MGQ_MpBattlesCoop.active?

    $game_party.battle_members.map { |actor| base_level_of(actor) }.max.to_i
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
    @page = :players unless pages.assoc(@page)
    case @page
    when :world then world_lines(rows.size)
    when :quests then []
    when :levels then level_lines
    else lines(rows)
    end
  end

  # What the overview shows on its page: the World page, or the Players page's list.
  #
  # @param lines [Array<Array>] The page's lines, see page_lines.
  # @param rows [Array<Row>] The players, see rows.
  # @return [Hash] The view, see view.
  def self.page_view(lines, rows)
    return view_of(lines) if @page == :players

    calls = rows.any? { |row| row.call }
    @page == :quests ? quest_view(calls) : world_view(lines, calls)
  end

  # The view of the World or the Levels page: its lines from its scroll, kept within the lines as
  # the box's height changes, nothing picked and no menu, and whether a player's call waits on the
  # Players page, which the notification box hides behind the overview.
  #
  # @param lines [Array<Array>] The page's lines, see world_lines and level_lines.
  # @param calls [Boolean] Whether a player's invite, challenge or offer reaches the player.
  # @return [Hash] The view, see view.
  def self.world_view(lines, calls)
    @world_scroll = MGQ_MpUi.within(@world_scroll, 0, most_scroll(lines))
    { :page => @page, :lines => lines, :selected => nil, :scroll => @world_scroll, :menu => nil, :menu_index => nil, :calls => calls }
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
    elsif page == :quests
      update_quests
    elsif page != :players
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

  # Scrolls the World or the Levels page with the arrows, turns the page, follows the mouse, or
  # closes the overview.
  #
  # @param lines [Array<Array>] The page's lines, see world_lines and level_lines.
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

  # Follows the mouse on the World and the Levels page: a click on a tab turns the page, a click
  # outside the box closes the overview.
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

  # The view of the Quests page: the quests, the one picked, the list's and the reading pane's
  # scroll.
  #
  # @param calls [Boolean] Whether a player's invite, challenge or offer reaches the player.
  # @return [Hash] The view, see view, with :quests (see quests), :pick, :list_scroll and
  #   :pane_scroll.
  def self.quest_view(calls)
    data = quests
    @quest_pick = MGQ_MpUi.within(@quest_pick.to_i, 0, [data[:picks].size - 1, 0].max)
    { :page => :quests, :lines => [], :selected => nil, :scroll => 0, :menu => nil, :menu_index => nil, :calls => calls,
      :quests => data, :pick => @quest_pick, :list_scroll => @quest_scroll.to_i, :pane_scroll => @pane_scroll.to_i }
  end

  # Picks a quest with Up and Down, scrolls its text with Page Up and Page Down, turns the page,
  # follows the mouse, or closes the overview.
  def self.update_quests
    view = quest_view(false)
    mouse_quests(view)
    return unless @open && @page == :quests
    return if closed_by_cancel? || turn_by_keys

    picks = view[:quests][:picks]
    step = axis_step(:UP, :DOWN)
    return pick_quest((view[:pick] + step) % picks.size) if step != 0 && picks.size > 1

    page = axis_step(:L, :R)
    scroll_pane(view, page) if page != 0
  end

  # Picks a quest, showing its text from the top and keeping its row in sight.
  #
  # @param index [Integer] Its place among the quests that can be picked, see quests.
  def self.pick_quest(index)
    return if index == @quest_pick

    @quest_pick = index
    @pane_scroll = 0
    data = quests
    row = Sprite_MpWorldOverview.quest_row(data, index)
    rows = Sprite_MpWorldOverview.quest_list_rows
    if row
      # The heading above a section's first quest shows with it.
      top = row > 0 && data[:rows][row - 1][0] == :head ? row - 1 : row
      @quest_scroll = top if top < @quest_scroll.to_i
      @quest_scroll = row - rows + 1 if row >= @quest_scroll.to_i + rows
    else
      @quest_scroll = 0
    end
    Sound.play_cursor
  end

  # Scrolls the reading pane by a page of its lines, never past its last line.
  #
  # @param view [Hash] The Quests page's view, see quest_view.
  # @param step [Integer] 1 down, -1 up.
  def self.scroll_pane(view, step)
    quest = view[:quests][:picks][view[:pick]]
    return unless quest

    rows = Sprite_MpWorldOverview.pane_rows(Sprite_MpWorldOverview.box.height, quest)
    most = [Sprite_MpWorldOverview.pane_lines(quest).size - rows, 0].max
    scroll = MGQ_MpUi.within(@pane_scroll.to_i + step * [rows - 1, 1].max, 0, most)
    return if scroll == @pane_scroll.to_i

    @pane_scroll = scroll
    Sound.play_cursor
  end

  # Follows the mouse on the Quests page: pointing at a quest or a click picks it, a click on a tab
  # turns the page, a click outside the box closes the overview.
  #
  # @param view [Hash] The Quests page's view, see quest_view.
  def self.mouse_quests(view)
    position = MGQ_Multiplayer::Mouse.position
    clicked = MGQ_Multiplayer::Mouse.clicked?
    moved = position && position != @mouse
    @mouse = position
    return unless position && (moved || clicked)

    x, y = position
    tab = Sprite_MpWorldOverview.tab_at(x, y)
    return turn_to(tab, "a click on its tab") if tab && clicked

    pick = Sprite_MpWorldOverview.quest_at(x, y, view)
    return pick_quest(pick) if pick && clicked
    return unless clicked && !Sprite_MpWorldOverview.inside?(x, y)

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
  TAB_WIDTH = 76

  # The Quests page: the side of Amira's portrait and of a companion's, the gap under and beside a
  # portrait, the gap between the list and the reading pane, the list's share of the width, the
  # height of a line of text, the lines the main quest takes at most, a quest's indent under its
  # heading, and the marks of more above and below with their width.
  PORTRAIT = 64
  PANE_PORTRAIT = 48
  QUEST_GAP = 8
  QUEST_SPLIT = 16
  LIST_SHARE = 0.45
  PANE_LINE = 20
  MAIN_LINES = 2
  QUEST_INDENT = 8
  MORE_WIDTH = 16
  MORE_UP = "▲"
  MORE_DOWN = "▼"

  # The most fitted texts kept at once, see fitted.
  FITTED_MOST = 500

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

  # Left edge of each column of the Levels page: a Makina's icon and the unlock's name; its kind and
  # whether the player has it take the right edge, KIND_WIDTH and STATUS_WIDTH wide.
  LEVEL_COLUMNS = { :icon => 8, :name => 36 }
  KIND_WIDTH = 90
  STATUS_WIDTH = 50

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
    :quests => ["Left or right: page", "Up or down: pick", "Page Up or Down: read on", MGQ_MpUi::Style.close_hint("%s")].join(MGQ_MpUi::Style::HINT_GAP),
    :levels => ["Left or right: page", "Up or down: scroll", MGQ_MpUi::Style.close_hint("%s")].join(MGQ_MpUi::Style::HINT_GAP),
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

  # Breaks a long value of the World page into the lines its value column holds, in the font
  # draw_info writes it in.
  #
  # @param text [String] The value.
  # @return [Array<String>] The lines.
  def self.value_lines(text)
    style = MGQ_MpUi::Style
    @measure = Bitmap.new(1, 1) if @measure.nil? || @measure.disposed?
    style.use_font(@measure, style::TEXT_SIZE, style::TEXT)
    MGQ_MpUi.wrap(@measure, text, box.width - MARGIN - WORLD_COLUMNS[:value])
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
  # @return [Symbol, nil] The page, see MGQ_MpWorldOverview.pages; nil outside the tabs.
  def self.tab_at(x, y)
    box = self.box
    return nil unless y >= box.y + TITLE && y < box.y + LIST_TOP && x >= box.x + MARGIN

    across = x - box.x - MARGIN
    step = TAB_WIDTH + MGQ_MpUi::Style::GAP
    page = MGQ_MpWorldOverview.pages[across / step]
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
      when :unlock then row.to_a
      when :info then [row, value]
      else row
      end
    end
    drawn = [view[:page], view[:calls], overview.world_name, overview.title_tail, MGQ_MpOverworld.party_badge(:me), rows, view[:selected], view[:scroll],
             view[:menu] && view[:menu].map { |option| [option.text, !option.run.nil?] }, view[:menu_index], box.width, box.height, MGQ_MpUi::Theme.serial,
             view[:pick], view[:list_scroll], view[:pane_scroll], view[:quests] && view[:quests].object_id,
             MGQ_MpWorldOverview.portraits]
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
    draw_backdrop if view[:page] == :quests
    draw_title
    draw_tabs(view[:page], view[:calls])
    if view[:page] == :quests
      draw_quests(view)
    else
      lines = view[:lines][view[:scroll], self.class.list_rows(height)] || []
      lines.each_with_index { |line, index| draw_line(line, LIST_TOP + index * ROW, view[:scroll] + index == view[:selected]) }
    end
    style.draw_hint(bitmap, MARGIN, height - HINT_HEIGHT, width - 2 * MARGIN, HINT_HEIGHT, HINTS[view[:page]] % MGQ_MpHotkeys.label(:overview))
    draw_menu(view) if view[:menu]
  end

  # Draws the Quests page: Amira's figure with the main quest at the top, the list of quests at the
  # left and the picked quest's whole text at the right.
  #
  # @param view [Hash] The Quests page's view, see MGQ_MpWorldOverview.quest_view.
  def draw_quests(view)
    data = view[:quests]
    layout = self.class.quest_layout(bitmap.width, bitmap.height)
    picked = data[:picks][view[:pick]]
    draw_quest_head(data[:main], !picked.nil? && picked.equal?(data[:main]), layout)
    draw_quest_list(view, picked, layout)
    bitmap.fill_rect(layout[:pane_x] - QUEST_SPLIT / 2, layout[:body_y], 1, layout[:body_h], MGQ_MpUi::Style::EDGE)
    draw_quest_pane(picked, view[:pane_scroll], layout)
  end

  # Draws Amira's figure in its box and the main quest's first sentence to its right.
  #
  # @param main [MGQ_MpWorldOverview::Quest, nil] The main quest.
  # @param picked [Boolean] Whether it is the quest picked.
  # @param layout [Hash] See quest_layout.
  def draw_quest_head(main, picked, layout)
    style = MGQ_MpUi::Style
    actor = $data_actors && $data_actors[MGQ_MpWorldOverview::AMIRA]
    top = layout[:head_y]
    draw_portrait(MGQ_MpWorldOverview.looks(actor), MARGIN, top, PORTRAIT) if actor
    x = layout[:text_x]
    width = bitmap.width - MARGIN - x
    bitmap.fill_rect(x - style::GAP, top, width + style::GAP, PORTRAIT, style::PICKED) if picked
    style.use_font(bitmap, style::SMALL_SIZE, style::HEADING)
    bitmap.draw_text(x, top, width, PANE_LINE, MGQ_MpWorldOverview::QUEST_TITLES[:main])
    style.use_font(bitmap, style::TEXT_SIZE, main ? style::TEXT : style::DIM)
    text = main ? main.first : MGQ_MpWorldOverview::NO_QUESTS
    shown = self.class.fitted([:main, text, width]) do
      lines = MGQ_MpUi.wrap(bitmap, text, width)
      head = lines.first(MAIN_LINES)
      head[-1] = MGQ_MpUi.cut(bitmap, "#{head[-1]} #{lines[MAIN_LINES]}", width) if lines.size > MAIN_LINES
      head
    end
    shown.each_with_index { |line, index| bitmap.draw_text(x, top + PANE_LINE + index * PANE_LINE, width, PANE_LINE, line) }
  end

  # Draws the list of side and companion quests from its scroll: each quest's first sentence in
  # one line under its section's heading, the picked one on the picked color.
  #
  # @param view [Hash] The Quests page's view.
  # @param picked [MGQ_MpWorldOverview::Quest, nil] The quest picked.
  # @param layout [Hash] See quest_layout.
  def draw_quest_list(view, picked, layout)
    style = MGQ_MpUi::Style
    rows = view[:quests][:rows]
    count = self.class.quest_list_rows(bitmap.height)
    width = layout[:list_w]
    rows[view[:list_scroll], count].to_a.each_with_index do |(kind, value), index|
      y = layout[:body_y] + index * ROW
      case kind
      when :head
        style.use_font(bitmap, style::SMALL_SIZE, style::HEADING)
        bitmap.draw_text(MARGIN, y, width, ROW, value)
      when :none
        style.use_font(bitmap, style::SMALL_SIZE, style::DIM)
        bitmap.draw_text(MARGIN + QUEST_INDENT, y, width - QUEST_INDENT, ROW, value)
      else
        bitmap.fill_rect(MARGIN, y, width, ROW, style::PICKED) if value.equal?(picked)
        draw_quest_row(value, MARGIN + QUEST_INDENT, y, width - QUEST_INDENT - style::GAP)
      end
    end
    draw_more(MARGIN + width - MORE_WIDTH, layout[:body_y], view[:list_scroll] > 0, view[:list_scroll] + count < rows.size, count * ROW)
  end

  # Draws one quest of the list: a side quest's number or a companion's name, then the first
  # sentence cut to the room left.
  #
  # @param quest [MGQ_MpWorldOverview::Quest] The quest.
  # @param x [Integer] The row's left.
  # @param y [Integer] The row's top.
  # @param width [Integer] The row's width.
  def draw_quest_row(quest, x, y, width)
    style = MGQ_MpUi::Style
    label = quest.kind == :side ? "#{quest.number}." : quest.speaker.to_s
    style.use_font(bitmap, style::SMALL_SIZE, quest.kind == :side ? style::DIM : style::HEADING)
    label, used = self.class.fitted([:label, label, width]) do
      cut = MGQ_MpUi.cut(bitmap, label, width / 3)
      [cut, bitmap.text_size(cut).width + style::GAP * 2]
    end
    bitmap.draw_text(x, y, used, ROW, label)
    style.use_font(bitmap, style::SMALL_SIZE, style::TEXT)
    sentence = quest.first
    bitmap.draw_text(x + used, y, width - used, ROW, self.class.fitted([:row, sentence, width - used]) { MGQ_MpUi.cut(bitmap, sentence, width - used) })
  end

  # Draws the picked quest's title and its whole text from the pane's scroll, a paragraph for
  # each message.
  #
  # @param quest [MGQ_MpWorldOverview::Quest, nil] The quest.
  # @param scroll [Integer] The first of its lines in sight.
  # @param layout [Hash] See quest_layout.
  def draw_quest_pane(quest, scroll, layout)
    return unless quest

    style = MGQ_MpUi::Style
    x = layout[:pane_x]
    width = layout[:pane_w]
    top = layout[:body_y]
    head = self.class.pane_head(quest)
    title_x = x
    if quest.looks
      draw_portrait(quest.looks, x, top, PANE_PORTRAIT)
      title_x += PANE_PORTRAIT + QUEST_GAP
    end
    title_width = x + width - MORE_WIDTH - title_x
    style.use_font(bitmap, style::SMALL_SIZE, style::HEADING)
    bitmap.draw_text(title_x, top + (head - ROW) / 2, title_width, ROW, MGQ_MpUi.cut(bitmap, quest.title, title_width))
    lines = self.class.pane_lines(quest)
    rows = self.class.pane_rows(bitmap.height, quest)
    style.use_font(bitmap, style::TEXT_SIZE, style::TEXT)
    lines[scroll, rows].to_a.each_with_index { |line, index| bitmap.draw_text(x, top + head + index * PANE_LINE, width, PANE_LINE, line) }
    draw_more(x + width - MORE_WIDTH, layout[:body_y], scroll > 0, scroll + rows < lines.size, layout[:body_h])
  end

  # Draws how a character looks in a framed square on the box's background, by the player's choice
  # of portraits: their map sprite or their face.
  #
  # @param looks [MGQ_MpWorldOverview::Looks] How they look.
  # @param x [Integer] The square's left.
  # @param y [Integer] The square's top.
  # @param side [Integer] The square's side.
  def draw_portrait(looks, x, y, side)
    return unless defined?(Sprite_MpLeaderHud)

    if MGQ_MpWorldOverview.portraits == MGQ_MpWorldOverview::FACES
      Sprite_MpLeaderHud.draw_face(bitmap, looks.face_name, looks.face_index, x, y, side, MGQ_MpUi::Style::BACK)
    else
      Sprite_MpLeaderHud.draw_figure(bitmap, looks.character_name, looks.character_index, x, y, side, MGQ_MpUi::Style::BACK)
    end
  end

  # Draws the marks that tell more lies above or below, at the top and the bottom of a column.
  #
  # @param x [Integer] The marks' left.
  # @param y [Integer] The column's top.
  # @param above [Boolean] Whether more lies above.
  # @param below [Boolean] Whether more lies below.
  # @param height [Integer] The column's height.
  def draw_more(x, y, above, below, height)
    style = MGQ_MpUi::Style
    style.use_font(bitmap, style::TINY_SIZE, style::DIM)
    bitmap.draw_text(x, y, MORE_WIDTH, ROW, MORE_UP, 1) if above
    bitmap.draw_text(x, y + height - ROW, MORE_WIDTH, ROW, MORE_DOWN, 1) if below
  end

  # Lays the Quests page out in a box of a size.
  #
  # @param width [Integer] The box's width.
  # @param height [Integer] The box's height.
  # @return [Hash] :head_y (the figure's and the main quest's top), :text_x (the main quest's left),
  #   :body_y and :body_h (the list's and the pane's top and height), :list_w, :pane_x and :pane_w.
  def self.quest_layout(width = box.width, height = box.height)
    head_y = LIST_TOP + MGQ_MpUi::Style::GAP
    body_y = head_y + PORTRAIT + QUEST_GAP
    list_w = ((width - 2 * MARGIN - QUEST_SPLIT) * LIST_SHARE).to_i
    pane_x = MARGIN + list_w + QUEST_SPLIT
    { :head_y => head_y, :text_x => MARGIN + PORTRAIT + QUEST_GAP, :body_y => body_y, :body_h => [height - HINT_HEIGHT - MARGIN - body_y, ROW].max,
      :list_w => list_w, :pane_x => pane_x, :pane_w => width - MARGIN - pane_x }
  end

  # Tells how many rows of the list show at once.
  #
  # @param height [Integer] The box's height.
  # @return [Integer] The rows, at least one.
  def self.quest_list_rows(height = box.height)
    [quest_layout(box.width, height)[:body_h] / ROW, 1].max
  end

  # Tells how many lines of the reading pane show at once, under its title.
  #
  # @param height [Integer] The box's height.
  # @param quest [MGQ_MpWorldOverview::Quest, nil] The quest shown.
  # @return [Integer] The lines, at least one.
  def self.pane_rows(height = box.height, quest = nil)
    [(quest_layout(box.width, height)[:body_h] - pane_head(quest)) / PANE_LINE, 1].max
  end

  # Tells how tall the reading pane's head is: the title, beside the companion's portrait if any.
  #
  # @param quest [MGQ_MpWorldOverview::Quest, nil] The quest shown.
  # @return [Integer] The height.
  def self.pane_head(quest)
    quest && quest.looks ? PANE_PORTRAIT + MGQ_MpUi::Style::GAP : ROW
  end

  # Breaks a quest's messages into the reading pane's lines, an empty line between two messages.
  #
  # @param quest [MGQ_MpWorldOverview::Quest] The quest.
  # @return [Array<String>] The lines.
  def self.pane_lines(quest)
    width = quest_layout[:pane_w]
    fitted([:pane, quest.texts, width]) do
      style = MGQ_MpUi::Style
      @measure = Bitmap.new(1, 1) if @measure.nil? || @measure.disposed?
      style.use_font(@measure, style::TEXT_SIZE, style::TEXT)
      quest.texts.each_with_index.inject([]) do |lines, (text, index)|
        lines << "" if index > 0
        lines.concat(MGQ_MpUi.wrap(@measure, text, width))
      end
    end
  end

  # Keeps what fitting a text to a width gave, since measuring texts is slow in the game.
  #
  # @param key [Array] What the result goes by: its use, the text and the width.
  # @yieldreturn [Object] The result, worked out once.
  # @return [Object] The result.
  def self.fitted(key)
    @fitted ||= {}
    @fitted.clear if @fitted.size > FITTED_MOST
    @fitted.key?(key) ? @fitted[key] : @fitted[key] = yield
  end

  # Finds the list's row of a quest.
  #
  # @param data [Hash] The quests, see MGQ_MpWorldOverview.quests.
  # @param pick [Integer] The quest's place among those that can be picked.
  # @return [Integer, nil] Its row; nil for the main quest, which the list leaves out.
  def self.quest_row(data, pick)
    first = data[:main] ? 1 : 0
    return nil if pick < first

    (0...data[:rows].size).select { |row| data[:rows][row][0] == :quest }[pick - first]
  end

  # Finds the quest under a point of the screen: the main quest at the top, or a quest of the list.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param view [Hash] The Quests page's view.
  # @return [Integer, nil] Its place among the quests that can be picked; nil for none.
  def self.quest_at(x, y, view)
    return nil unless inside?(x, y)

    box = self.box
    layout = quest_layout(box.width, box.height)
    data = view[:quests]
    left = x - box.x
    top = y - box.y
    return (data[:main] ? 0 : nil) if top >= layout[:head_y] && top < layout[:head_y] + PORTRAIT
    return nil if left < MARGIN || left >= MARGIN + layout[:list_w] || top < layout[:body_y]

    row = view[:list_scroll] + (top - layout[:body_y]) / ROW
    return nil unless row < view[:list_scroll] + quest_list_rows(box.height) && data[:rows][row] && data[:rows][row][0] == :quest

    (data[:main] ? 1 : 0) + data[:rows][0...row].count { |kind, _| kind == :quest }
  end

  # Draws Amira's picture faintly at the right behind the Quests page's lines.
  def draw_backdrop
    picture = MGQ_MpWorldOverview.backdrop
    return unless picture

    room = bitmap.height - LIST_TOP - HINT_HEIGHT - MARGIN
    scale = [room.to_f / picture.height, 1.0].min
    width = (picture.width * scale).to_i
    height = (picture.height * scale).to_i
    return if width <= 0 || height <= 0

    target = Rect.new(bitmap.width - MARGIN - width, LIST_TOP + room - height, width, height)
    bitmap.stretch_blt(target, picture, picture.rect, MGQ_MpWorldOverview::BACKDROP_OPACITY)
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
    MGQ_MpWorldOverview.pages.each_with_index do |(key, title), index|
      x = MARGIN + index * (TAB_WIDTH + style::GAP)
      shown = key == page
      bitmap.fill_rect(x, TITLE, TAB_WIDTH, TABS, shown ? style::PICKED : style::TAB)
      style.use_font(bitmap, style::SMALL_SIZE, shown ? style::TEXT : style::DIM)
      bitmap.draw_text(x, TITLE, TAB_WIDTH, TABS, title, 1)
      bitmap.fill_rect(x + TAB_WIDTH - CALL_MARK - style::GAP, TITLE + style::GAP, CALL_MARK, CALL_MARK, style::GOLD) if calls && !shown && key == :players
    end
  end

  # Draws one line of a page: a heading, a player, a row of the World page, a raid boss or what
  # the catch-up hands out.
  #
  # @param line [Array] [:place, name], [:player, row], [:info, label, value], [:boss, boss] or
  #   [:unlock, unlock].
  # @param y [Integer] The line's top.
  # @param picked [Boolean] Whether it is the player picked.
  def draw_line(line, y, picked)
    kind, value, extra = line
    case kind
    when :place then draw_heading(value, y)
    when :info then draw_info(value, extra, y)
    when :boss then draw_boss(value, y)
    when :unlock then draw_unlock(value, y)
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

  # Draws what the catch-up hands out at a level: a Makina's icon, its name, dimmed once the player
  # has it, its kind, and Done or, once the player's level reached it, Due at the right edge.
  #
  # @param unlock [MGQ_MpWorldCatchup::Unlock] What it hands out.
  # @param y [Integer] The line's top.
  def draw_unlock(unlock, y)
    style = MGQ_MpUi::Style
    overview = MGQ_MpWorldOverview
    MGQ_MpUi.draw_icon(bitmap, unlock.icon, LEVEL_COLUMNS[:icon], y) if unlock.icon
    status_left = bitmap.width - MARGIN - STATUS_WIDTH
    kind_left = status_left - style::GAP - KIND_WIDTH
    style.use_font(bitmap, style::TEXT_SIZE, unlock.got ? style::DIM : style::TEXT)
    name_width = kind_left - style::GAP - LEVEL_COLUMNS[:name]
    bitmap.draw_text(LEVEL_COLUMNS[:name], y, name_width, ROW, MGQ_MpUi.cut(bitmap, unlock.name, name_width))
    style.use_font(bitmap, style::SMALL_SIZE, style::DIM)
    bitmap.draw_text(kind_left, y, KIND_WIDTH, ROW, overview::UNLOCK_KINDS[unlock.kind].to_s)
    status = unlock.got ? overview::DONE : (unlock.due ? overview::DUE : nil)
    return unless status

    style.use_font(bitmap, style::SMALL_SIZE, unlock.got ? style::DIM : style::GOLD)
    bitmap.draw_text(status_left, y, STATUS_WIDTH, ROW, status, 2)
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

# The Quests page's portraits, a row of the Mod Config.

begin
  MGQ_MpWorldOverview.add_options
rescue => e
  MGQ_MpWorldOverview.log("options FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the overview's keys.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "world_overview") { MGQ_MpWorldOverview.on_map unless scene_changing? }

  # After the map's sprites, the overview's box.
  MGQ_MpHooks.after(Spriteset_Map, :update, "world_overview") do
    (@mgq_mp_overview ||= Sprite_MpWorldOverview.new(MGQ_MpGame.get(self, :viewport3))).update
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "world_overview") do
    @mgq_mp_overview.dispose if @mgq_mp_overview
    @mgq_mp_overview = nil
  end
rescue => e
  MGQ_MpWorldOverview.log("hooks FAILED: #{e.class}: #{e.message}")
end
