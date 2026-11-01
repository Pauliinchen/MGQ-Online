#----------------------------------------------------------------
#  world_overview.rbx
#
#  Changelog:
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#                            - Built the overview on the Mod Framework's window, tabs, list, page views and menus
#                            - Closed with the action wheel's hotkey itself and asked the Mod Framework's wheels whether one is open
#                            - Read the lists of players and kept what the player tells the others in the DLL
#      Paulinchen  2026-10-31: Read the keys and the mouse, named the cancel key and placed its box through the Mod Framework
#      Paulinchen  2026-10-28: Read the progress, the routes and the sides by their ids in place of their names
#      Paulinchen  2026-10-24: Listed the pages of other mods after the own pages and made room for two of their tabs
#                            - Placed the menu of a page with a head, a list and a pane over the pane or under its buttons
#                            - Opened the overview outside a world too, as Single player with the Quests page
#      Paulinchen  2026-10-23: Asked the DLL for the story's texts and the title
#                            - Asked the world story for the part the player is in
#                            - Read the world's part from the relay's summary of its story tracks
#                            - Removed the unused EXP_VALUE, BOSSES_HEADING and World page labels, and the repeated page hints
#                            - Kept the overview off the live map behind menus
#      Paulinchen  2026-10-13: Removed the unused YOUR_LEVEL
#      Paulinchen  2026-10-12: Moved the World, Quests and Unlocks pages into world_overview_pages.rbx
#                            - Renamed the Levels page Unlocks
#                            - Drew the Players page's scrollbar and moved its pick with the mouse wheel
#                            - Added the Quests page with a Quest Portraits setting
#                            - Kept Amira's side quests out of the objective
#                            - Narrowed the tabs
#                            - Showed the catch-up experience on the Levels page
#                            - Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Counted Part 2 from progress 19 and Part 3 from 34
#                            - Read the map's viewport through MGQ_MpGame
#      Paulinchen  2026-10-11: Added the Levels page of a Raid World
#                            - Told the others the highest level of the player's formation, Luka included
#                            - Showed a Raid World's objective on the World page under the story
#                            - Listed a Raid World's party for the party box with each member's Frontline level
#                            - Made the box movable and resizable with the left Alt held as the World overview
#                            - Gave a larger box's extra width and height to the longer texts and more lines
#                            - Read the box's place for the clicks on its lines, tabs and menu and for a click outside it
#                            - Drew the box and its menu in the interface preset's colors
#                            - Kept the menu inside the box when neither below nor above the picked player has room
#                            - Drew the hint whole through the shared style
#                            - Grouped the World page's raid bosses by the story's sections
#                            - Took the box's place, the title's insets and the picked row's from the list box
#                            - Added the World page with the world's name, type, difficulty, players, story and raid bosses
#                            - Marked the Players tab in gold while a player's call waits there and the World page shows
#                            - Showed the world's type and difficulty after its name in the title
#                            - Named Left and Right in the hint, shortened the Players page's hint, and named the close keys
#                            - Skipped the keys while the confirm box asks over the overview
#                            - Took the colors, font sizes, column gap, players' colors, ping column, party title and icons from the shared UI scripts
#      Paulinchen  2026-10-08: Listed everyone on the player's map for the map box of a Raid World, and told the others the Frontline's highest level there
#                            - Forgot the level and story told the others when the world closes
#                            - Closed with the numpad's 0 through MGQ_MpUi.cancel?
#                            - Took the choices of a player's menu from MGQ_MpActions
#                            - Named the numpad's 0 in the hint of how to close
#      Paulinchen  2026-10-07: Logged once when the game has no variable or switch of a name
#                            - Named players through MGQ_MpOverworldSync.who, cut places through MGQ_MpUi.cut, and took icons, white and the depth from MGQ_MpUi
#                            - Logged the overview opening and closing, each menu, the choice taken or refused, and the level and story told to the others
#                            - Left the place of a map the game names nowhere empty, and headed it Unnamed place in the list
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
#                            - Read the bound hotkeys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#      Paulinchen  2026-10-02: Opened and closed the overview with the hotkey the player bound, which its hint names
#                            - Followed the map and its sprites through core_hooks.rbx
#                            - Dropped the unused scroll reader and the wrapper around another player's choices
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------
# The World overview: a framework Window over the map, opened with its hotkey (F11 unless the player
# binds another, see core_hotkeys.rbx) or the action wheel's middle, moved and resized with the
# left Alt held, its place kept under LAYOUT_ID, with its pages on tabs turned with Left and Right
# or a click. The Players page lists every player of the world online, grouped by where they are,
# with their formation's highest level, their place in the story and their ping; a player picked
# opens a menu of what the scripts offer, such as party invites, duels and trades. The other pages
# are page views, see world_overview_pages.rbx and world_overview_mods.rbx. It also lists the
# player's party for the party box of ui_party_box.rbx and, in a Raid World, everyone on the
# player's map for the map box, and tells the others where the player is, their levels and their
# place in the story in the state overworld_sync.rbx sends.
module MGQ_MpWorldOverview
  # The framework's components, short.
  UI = Mod_Framework::UI

  # Frames between two readings of a page's model, three seconds.
  READ_FRAMES = 180

  # The DLL's event that has the game read the player's levels and story, see tell.
  READ_EVENT = "overview.read"

  # The topic that keeps what the game read of the player's levels and story, and says what changed.
  TELL_TOPIC = "overview.tell"

  # The topic that keeps where the player is and answers the fields of the state the player tells.
  FIELDS_TOPIC = "overview.fields"

  # The topic that hands out the lists of players: the Players page, the party, a Raid World's party
  # and the players on the map, each row [seat, name, place, level, story, ping, scene, member,
  # badge], the lines ["place", heading] or ["player", place among the players]; nil while the lists
  # are the same as by the serial held.
  ROWS_TOPIC = "overview.rows"

  # The seat a row of the DLL's lists names the player by.
  ME_SEAT = -1

  # The lists while the DLL told none.
  NO_LISTS = { "players" => [], "lines" => [], "party" => [], "raid_party" => [], "map" => [] }

  # The story's progress variable ("Overall Events Progress").
  PROGRESS = 1001

  # The side chosen, by the switch that records the choice ("Ilias Chosen", "Alice Chosen").
  SIDES = { "ilias" => 5, "alice" => 4 }

  # Route of the final chapter, by the variable that counts its progress; the route not being
  # played holds 0.
  ROUTES = { "chaos" => 1143, "destroyer" => 1141, "judgment" => 1142 }

  # The topic that writes what the title and the World page say of the world's type and difficulty.
  TITLE_TOPIC = "overview.title"

  # Texts the story's and the title's caches keep before they forget them all.
  TEXTS_KEPT = 256

  # The overview's pages in the order Left and Right pass through them, each with its tab's title:
  # the players online, the world itself, the quests under way, and in a Raid World what the
  # catch-up hands out by level.
  PAGES = [[:players, "Players"], [:world, "World"], [:quests, "Quests"], [:unlocks, "Unlocks"]]

  # The pages only a Raid World shows.
  RAID_PAGES = [:unlocks]

  # The pages the overview shows outside a world, the only ones that work there, with the pages of
  # other mods after them.
  SOLO_PAGES = [:quests]

  # What the title says outside a world.
  SOLO_TITLE = "Single player"

  # The most pages of other mods the overview shows, see world_overview_mods.rbx.
  MOD_TABS = 2

  # How the Unlocks page heads what comes at a level.
  LEVEL_HEADING = "Level %d"

  # What the Unlocks page says of an unlock the player has.
  DONE = "Done"

  # What the Unlocks page says of an unlock whose level the player reached, which comes at the
  # catch-up's next check.
  DUE = "Due"

  # What the title says while no world is open.
  NO_WORLD = "World"

  # The common event of Amira the Informant, whose words on the information asked for name the
  # story's current objective (see main_quest).
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

  # The Chaos route's variable.
  CHAOS_ROUTE = 1143

  # The Chaos route's step from which Amira tells the second list of SIDE_EVENTS.
  CHAOS_SIDE_STEP = 21

  # The map of the Pocket Castle's bulletin board, where companions leave their requests.
  BOARD_MAP = 228

  # The event of the Pocket Castle's bulletin board.
  BOARD_EVENT = 37

  # The variable Amira's lists and the board set to 1 before each entry they tell, which marks
  # where an entry starts.
  QUEST_COUNT = 11

  # Amira's actor, whose Library picture shows faintly behind the Quests page.
  AMIRA = 540

  # How opaque that picture is, out of 255.
  BACKDROP_OPACITY = 36

  # How the reading pane joins a quest's title and who tells it.
  TITLE_JOIN = " · "

  # The setting in Player.ini that keeps how the Quests page shows Amira and the companions.
  PORTRAIT_SETTING = "quest_portraits"

  # The choice that shows them by their map sprite.
  SPRITES = "Sprites"

  # The choice that shows them by their face.
  FACES = "Faces"

  # The setting's choices, the first the one until the player picks another.
  PORTRAITS = [SPRITES, FACES]

  # The key of the setting's Mod Config row.
  PORTRAIT_OPTION = :mp_quest_portraits

  # The name of the setting's Mod Config row.
  PORTRAIT_OPTION_NAME = "Quest Portraits"

  # The help of the setting's Mod Config row.
  PORTRAIT_OPTION_HELP = "How the Quests page of the World overview shows Amira and the companions asking for help:\n" \
                         "Sprites by their map sprite, Faces by their face."

  # How a character looks: their map sprite's sheet and place, and their face's sheet and place.
  Looks = Struct.new(:character_name, :character_index, :face_name, :face_index)

  # A quest as the game tells it now: its kind (:main, :side or :companion), who tells it, each
  # message as plain text, a side quest's number, and how a companion asking for help looks.
  Quest = Struct.new(:kind, :speaker, :texts, :number, :looks)

  # A speaker's name at a message's start: the translation's "\n<Name>" and the untranslated
  # game's "【Name】".
  SPEAKER = /\\n<[^>]*>|\A\s*【[^】]*】/

  # The text codes of a message, which the World page leaves out: a code with its argument, such as
  # "\C[3]", one of letters, such as "\fb", and one of a sign, such as "\*".
  TEXT_CODES = [/\\[A-Za-z]+\[[^\]]*\]/, /\\[A-Za-z]+/, /\\./]

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

  # The window's id among those the player moves and resizes, which keeps the place stored before.
  LAYOUT_ID = :overview

  # The window's name while the player arranges the boxes.
  LAYOUT_NAME = "World overview"

  # Where the window starts.
  DEFAULT_AT = [40, 32]

  # The room the window leaves beside and under it at its start, see DEFAULT_AT.
  DEFAULT_ROOM = [80, 76]

  # The least size: the Players page's columns, and a page's head over three rows of its list.
  MIN_SIZE = [560, 232]

  # Room between the window's edge and what it holds.
  MARGIN = 8

  # Room between the world's name and the party in the title.
  TITLE_GAP = 12

  # The widths of the Players page's columns: the icons, the name, the party, the level, the place
  # in the story (the rest) and the ping.
  PLAYER_CELLS = [52, 172, 52, 56, nil, 64]

  # Width of a player's menu.
  MENU_WIDTH = 210

  # Why the overview closes while it may no longer stay open, see stay_reason.
  TAKEN_OVER = "an event, a message or the chat box took over"

  # Why the overview closed, by the framework's reason, for the log.
  CLOSE_REASONS = { :cancel => "cancel", :outside => "a click outside the box", :scene => "the map was left", :script => "closed from outside" }

  # The page shown, see PAGES.
  @page = :players

  # The game's globe icon, which stands for the overview in the action wheel's middle.
  WORLD_ICON = 3988

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "overview"

  # Reports whether the overview is open.
  #
  # @return [Boolean] Whether it is.
  def self.open?
    @window ? @window.open? : false
  end

  # The action wheel's middle choice, which opens the overview.
  #
  # @return [MGQ_MpActions::Option] The choice.
  def self.wheel_option
    MGQ_MpActions::Option.new("World (#{MGQ_MpHotkeys.label(:overview)})", lambda { open("the action wheel") }, nil, WORLD_ICON)
  end

  # Opens the overview on the Players page, on the player's own row; outside a world on its first
  # page.
  #
  # @param via [String] What opened it, for the log.
  def self.open(via = "the action wheel")
    return if open?

    @in_world = MGQ_MpOverworldSync.in_world?
    window
    sync_tabs
    show_page(pages.assoc(:players) ? :players : pages.first[0])
    refresh
    @window.open
    return log("did not open through #{via}, see the Mod Framework's log") unless open?

    own = @players.rows.index { |row| row.is_a?(Hash) && row[:key] == :me }
    @players.index = own if own
    focus_page
    players = @players.rows.count { |row| row.is_a?(Hash) && row.key?(:cells) }
    log("opened through #{via}, #{@in_world ? "#{players} player(s) online" : 'outside a world'}")
  end

  # Closes the overview, if it is open, and gives the buttons back.
  #
  # @param reason [String] Why, for the log.
  def self.close(reason = "closed from outside")
    return unless open?

    @close_reason = reason
    @window.close
  end

  # Reports whether the overview may open: on the map, in a world or outside one, with no event,
  # message, chat box, action wheel or emote wheel open.
  #
  # @return [Boolean] Whether it may.
  def self.openable?
    SceneManager.scene.is_a?(Scene_Map) && MGQ_MpOverworldSync.map_quiet? &&
      !MGQ_MpChat.typing? && !MGQ_MpActions.wheel.open? && !MGQ_MpEmotes.wheel.open?
  end

  # Opens or closes the overview with its hotkey, closes it with the action wheel's, and keeps it
  # up to date while it is open. Called by the map every frame.
  def self.on_map
    return close("the action wheel's hotkey") if open? && MGQ_MpHotkeys.pressed?(:wheel)

    if MGQ_MpHotkeys.pressed?(:overview)
      return close("its hotkey") if open?
      return MGQ_MpHotkeys.log_refusal(:overview, "not on a quiet map, or the chat or a wheel is open") unless openable?

      Sound.play_ok
      open("its hotkey")
    end
    return unless open?

    refresh
  rescue => e
    log("overview failed: #{e.class}: #{e.message}")
    close("it failed")
  end

  # Tells whether the open overview may stay: still in a world, or still outside one, as it opened,
  # with no event or message, nor the chat box, which its hotkey opens over it.
  #
  # @return [Boolean, String] true while it may, else why not.
  def self.stay_reason
    stays = MGQ_MpOverworldSync.in_world? == @in_world && MGQ_MpOverworldSync.map_quiet? && !MGQ_MpChat.typing?
    stays ? true : TAKEN_OVER
  end

  # The page shown.
  #
  # @return [Symbol] :players, :world, :quests, :unlocks or a mod's page, see pages.
  def self.page
    @page
  end

  # Lists the pages the overview shows: outside a world those of SOLO_PAGES; in a world every page in
  # a Raid World, else those of RAID_PAGES left out; after them the pages of other mods, see
  # mod_tabs.
  #
  # @return [Array<Array>] The pages with their tabs' titles, see PAGES.
  def self.pages
    own = if !MGQ_MpOverworldSync.in_world? then PAGES.select { |key, _| SOLO_PAGES.include?(key) }
          elsif MGQ_MpCoop::Scope.raid? then PAGES
          else PAGES.reject { |key, _| RAID_PAGES.include?(key) }
          end
    own + mod_tabs
  end

  # Turns to a page, as a click on its tab does. Nothing for the page shown already or one the
  # world does not show.
  #
  # @param page [Symbol] The page, see pages.
  # @param via [String] What turned it, for the log.
  def self.turn_to(page, via)
    return unless open? && pages.assoc(page) && page != @page

    sync_tabs
    @tabs.index = @tab_keys.index(page)
    turned(via)
  end

  # The open world's name, for the title and the World page.
  #
  # @return [String] The name; SOLO_TITLE outside a world, NO_WORLD while one opens.
  def self.world_name
    return SOLO_TITLE unless MGQ_MpOverworldSync.in_world?

    world = MGQ_MpWorld.world
    world ? world.name.to_s : NO_WORLD
  end

  # What follows the world's name in the title: its type, and its difficulty when it sets one.
  #
  # @return [String] Such as " | Raid | Hard"; empty outside a world.
  def self.title_tail
    return "" unless MGQ_MpOverworldSync.in_world?

    title["tail"]
  end

  # What the World page notes of the world: its type, and its difficulty or that each player keeps
  # their own.
  #
  # @return [String] Such as "Raid | Per player".
  def self.world_note
    title["note"]
  end

  # Writes the title's and the note's texts through the DLL (OverviewText in MGQOnline.Game), once
  # per type and difficulty, since the title is drawn every frame.
  #
  # @return [Hash] "tail" and "note", both empty when the DLL did not answer.
  def self.title
    request = { "raid" => MGQ_MpCoop::Scope.raid? ? true : false, "difficulty" => MGQ_MpWorldDifficulty.value }
    cached(:title, request) { MGQ_Multiplayer::Bridge.call(TITLE_TOPIC, request) } || { "tail" => "", "note" => "" }
  end

  # Keeps what the DLL answered for a request, so a text drawn every frame is asked once; an
  # answer of nil is asked again.
  #
  # @param kind [Symbol] What is cached, such as :title.
  # @param key [Object] The request.
  # @return [Object, nil] The answer.
  def self.cached(kind, key)
    @texts ||= {}
    kept = (@texts[kind] ||= {})
    return kept[key] if kept.key?(key)

    answer = yield
    return nil if answer.nil?

    kept.clear if kept.size >= TEXTS_KEPT
    kept[key] = answer
  end

  # Closes the overview once the map is left, or a world opens or closes under it. Called by
  # overworld_sync.rbx every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    if !SceneManager.scene.is_a?(Scene_Map)
      close("the map was left")
    elsif in_world != @in_world
      close(in_world ? "a world opened" : "the world closed")
    end
  end

  # Reads the formation's highest level, in a Raid World the Frontline's too, and the place in the
  # story, and hands them to the DLL, which keeps what the player tells the others and says what
  # changed. Called on the DLL's READ_EVENT, every three seconds in a world.
  def self.tell
    raid = MGQ_MpCoop::Scope.raid?
    battle = defined?(MGQ_MpBattlesCoop) && MGQ_MpBattlesCoop.active? ? true : false
    told = MGQ_Multiplayer::Bridge.call(TELL_TOPIC, "lv" => formation_level, "flv" => raid ? front_level : nil, "story" => story_request, "battle" => battle)
    log(told) if told
  rescue => e
    log("telling the others failed: #{e.class}: #{e.message}")
  end

  # The fields the overview adds to the state the player's game tells the others, as the DLL keeps
  # them, where the player is handed over each time.
  #
  # @return [Hash] Where the player is, their formation's highest level and their place in the story,
  #   and in a Raid World their Frontline's highest level; the place alone while the DLL does not answer.
  def self.state_fields
    here = place
    MGQ_Multiplayer::Bridge.call(FIELDS_TOPIC, here) || { "place" => here }
  rescue => e
    log_once(:fields, "telling where the player is failed: #{e.class}: #{e.message}")
    { "place" => here }
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
    Mod_Framework::UI.cut(measure, text[0, text.length - floor.length], width, floor)
  end

  # Reads the highest base level of the player's formation, Luka included; during a co-op battle
  # the DLL keeps the level read before it.
  #
  # @return [Integer] The level, 0 without characters.
  def self.formation_level
    $game_party.battle_members.map { |actor| base_level_of(actor) }.max.to_i
  rescue => e
    log("reading the level failed: #{e.class}: #{e.message}")
    0
  end

  # Reads the highest base level of the player's share of the Frontline, Luka included: the squad's
  # share through coop_squad.rbx, else the first character; during a co-op battle the DLL keeps the
  # level read before it.
  #
  # @return [Integer] The level, 0 without characters.
  def self.front_level
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

  # Reads what the DLL finds the player's place in the story from: the progress, the routes'
  # variables and the sides' switches.
  #
  # @return [Hash] "p", "routes" and "sides", see ROUTES and SIDES.
  def self.story_request
    routes = {}
    ROUTES.each { |key, id| routes[key] = $game_variables[id].to_i }
    sides = {}
    SIDES.each { |key, id| sides[key] = $game_switches[id] == true }
    { "p" => $game_variables[PROGRESS].to_i, "routes" => routes, "sides" => sides }
  end

  # The lists of players as the DLL last built them, which it hands over only once they changed
  # (see ROWS_TOPIC) and builds once a frame however often it is asked.
  #
  # @return [Hash] "players", "lines", "party", "raid_party" and "map" as the DLL wrote them; empty
  #   lists while the DLL told none.
  def self.lists
    answer = MGQ_Multiplayer::Bridge.call(ROWS_TOPIC, "serial" => @serial, "name" => MGQ_Multiplayer::Player.name.to_s)
    if answer
      @serial = answer["serial"]
      @lists = answer
    end
    @lists ||= NO_LISTS
  rescue => e
    log_once(:lists, "reading the players failed: #{e.class}: #{e.message}")
    @lists ||= NO_LISTS
  end

  # Builds a row of a list the DLL wrote: the player behind its seat, the ping and the icon of what
  # they do as the overworld shows them, and the call another player makes to the player.
  #
  # @param told [Array] [seat (ME_SEAT for the player), name, place, level, story, ping, scene,
  #   member, badge], see ROWS_TOPIC.
  # @return [Row, nil] The row; nil for a player who left since.
  def self.row_from(told)
    seat, name, place, level, story, ping, scene, member, badge = told
    player = seat == ME_SEAT ? :me : MGQ_MpOverworldSync::Peers.at(seat)
    return nil unless player

    Row.new(player, name.to_s, place.to_s, level.to_s, story.to_s, MGQ_MpOverworld.ping_label(ping), MGQ_MpOverworld::STATE_ICONS[scene.to_s],
            member ? true : false, badge, player == :me ? nil : call_of(player))
  end

  # Builds the rows of a list the DLL wrote.
  #
  # @param name [String] The list, such as "players".
  # @return [Array<Row>] The rows, without players who left since.
  def self.rows_of(name)
    Array(lists[name]).map { |told| row_from(told) }.compact
  end

  # Lists the player's party for the box at the top right of the map: the leader first, then the
  # others by name.
  #
  # @return [Array<Row>] The players, the player included; none outside a party of two or more.
  def self.party_rows
    rows_of("party")
  end

  # Lists the player's party for the party box of a Raid World, as party_rows does, but with each
  # player's Frontline's highest level, as the map box shows it.
  #
  # @return [Array<Row>] The players, the player included; none outside a party of two or more.
  def self.raid_party_rows
    rows_of("raid_party")
  end

  # Lists everyone on the player's map for the map box of a Raid World: the party's members first,
  # its leader before the others by name, then the other players by name, each with their
  # Frontline's highest level. Only the party's leader keeps a crown.
  #
  # @return [Array<Row>] The players, the player included; none while nobody else is on the map.
  def self.map_rows
    rows_of("map")
  end

  # Lists the players of the world online, the player first.
  #
  # @return [Array<Row>] The players.
  def self.rows
    rows_of("players")
  end

  # Tells what another player calls the player to, such as their party invite or their duel
  # challenge, when it reaches the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @return [Array, nil] The text and its color, nil for none.
  def self.call_of(peer)
    MGQ_MpActions.offers.map { |offers| offers.call_of(peer) }.compact.first
  end

  # Lays the Players page out as the DLL did: a heading per place, the player's own first and the
  # others by name, each followed by its players by name, the player first.
  #
  # @param rows [Array<Row>] The players, see rows.
  # @return [Array<Array>] Each line: [:place, name] or [:player, row].
  def self.lines(rows)
    players = Array(lists["players"])
    by_seat = {}
    rows.each { |row| by_seat[key_of(row)] = row }
    Array(lists["lines"]).map do |kind, value|
      next [:place, value.to_s] if kind == "place"

      told = players[value.to_i]
      row = told && by_seat[told[0] == ME_SEAT ? :me : told[0]]
      row ? [:player, row] : nil
    end.compact
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

  # Builds the overview's window once, closed: the title row, the tabs with the Players page's list
  # and the other pages' views, and the key help.
  #
  # @return [Mod_Framework::UI::Window] The window.
  def self.window
    return @window if @window

    @window = UI::Window.new(:id => LAYOUT_ID, :place_name => LAYOUT_NAME, :movable => true, :resizable => true, :close_outside => true,
                             :if => lambda { stay_reason }, :at => DEFAULT_AT, :size => [Graphics.width - DEFAULT_ROOM[0], Graphics.height - DEFAULT_ROOM[1]],
                             :min_size => MIN_SIZE, :padding => MARGIN, :log => self)
    @window.on(:close) { |why| closed(why) }
    title = @window.add_row(:gap => TITLE_GAP)
    @name_label = title.add_label("", :font_size => :large, :color => :title, :shrink => true)
    @tail_label = title.add_label("", :font_size => :large, :color => :title)
    title.add_column(:grow => 1)
    @party_label = title.add_label("", :font_size => :large, :color => UI::Style::MEMBER, :visible => false)
    @tabs = @window.add_tabs(:arrows => true, :grow => 1)
    @tabs.on(:change) { |_index| turned("its tab or the arrows") }
    @tab_keys = []
    @views = {}
    @players = add_page_tab(:players, PAGES.assoc(:players)[1]).add_list(:cells => PLAYER_CELLS, :round => true, :rows_shown => :fill, :grow => 1)
    @players.on(:submit) { |row, index| open_menu(row, index) }
    SPLIT_PAGES.each { |key| @views[key] = own_view(key, add_page_tab(key, PAGES.assoc(key)[1])) }
    @help = @window.add_key_help([], :font_size => :small)
    @window
  end

  # Adds a tab with its page.
  #
  # @param key [Symbol] The page, see pages.
  # @param title [String] The tab's title.
  # @return [Mod_Framework::UI::Stack] The tab's page.
  def self.add_page_tab(key, title)
    page = @tabs.add_tab(title, :grow => 1)
    @tab_keys << key
    page
  end

  # Shows the tabs of the pages shown now, adding the tab of a mod's page the first time it shows,
  # and follows the tabs to the page they show once the page shown left, which stays the page shown
  # when the one that left comes back.
  def self.sync_tabs
    shown = pages
    shown.each { |key, title| @views[key] ||= mod_view(key, add_page_tab(key, title)) if mod_page?(key) }
    @tab_keys.each_with_index do |key, index|
      tab = @tabs.tab(index)
      title = shown.assoc(key)
      tab.visible = title ? true : false unless tab.visible? == (title ? true : false)
      tab.text = title[1] if title && tab.text != title[1]
    end
    return if @tab_keys[@tabs.index.to_i] == @page

    @tabs.index = @tabs.index
    turned("its page leaving") if open?
  end

  # Picks a page without telling anyone, such as the first page as the overview opens.
  #
  # @param page [Symbol] The page, see pages.
  def self.show_page(page)
    @tabs.index = @tab_keys.index(page)
    @page = page
  end

  # Follows the tabs to the page they show now: the menu closes, an own page reads its model
  # afresh, and the focus goes onto the page.
  #
  # @param via [String] What turned it, for the log.
  def self.turned(via)
    page = @tab_keys[@tabs.index.to_i]
    return if page == @page

    @page = page
    close_menu
    forget_model(page) if SPLIT_PAGES.include?(page)
    refresh
    focus_page
    title = pages.assoc(page)
    log("turned to the #{title ? title[1] : page} page through #{via}")
  end

  # Gives the focus to the page shown: the Players page's list, or a page view's head or list.
  def self.focus_page
    @page == :players ? @players.focus : @views[@page] && @views[@page].focus
  end

  # Brings what the overview shows up to date: the tabs, the title, the players, the gold mark of a
  # call waiting on the Players page, the page shown and the key help. Each part is set only once
  # it changed.
  def self.refresh
    sync_tabs
    all = rows
    show_title
    show_players(all)
    calls = all.any? { |row| row.call } && @page != :players
    @tabs.tab(0).badge = calls unless @tabs.tab(0).badge == calls
    show_split(@page) if SPLIT_PAGES.include?(@page)
    show_help
  end

  # Shows the world's name, its type and difficulty, and the player's party in the title row.
  def self.show_title
    show_text(@name_label, world_name)
    show_text(@tail_label, title_tail)
    badge = MGQ_MpOverworld.party_badge(:me)
    show_text(@party_label, badge ? MGQ_MpOverworld.party_title(badge) : "")
    @party_label.visible = badge ? true : false unless @party_label.visible? == (badge ? true : false)
  end

  # Sets a label's text once it changed.
  #
  # @param label [Mod_Framework::UI::Label] The label.
  # @param text [String] The text.
  def self.show_text(label, text)
    label.text = text unless label.text == text
  end

  # Shows the players in the Players page's list, once they changed: a heading per place and a row
  # per player, the cursor kept on the same player.
  #
  # @param all [Array<Row>] The players, see rows.
  def self.show_players(all)
    shown = lines(all).map { |kind, value| kind == :place ? { :heading => value } : player_row(value) }
    return if shown == @shown_players

    @shown_players = shown
    @players.rows = shown
  end

  # Makes a player's row of the list: the icon of what they do and a party leader's crown, their
  # name in their color, their party's size, their level, their place in the story or their call
  # in its color, and their ping in its color at the right.
  #
  # @param row [Row] The player.
  # @return [Hash] The row, keyed by the player, see key_of.
  def self.player_row(row)
    color = MGQ_MpPlayerColor.of(row.player, row.member)
    icons = [row.icon, row.badge && row.badge[1] ? MGQ_MpOverworld::CROWN_ICON : nil].compact
    text, text_color = row.call || [row.story, :text]
    ping, ping_color = row.ping
    cells = [{ :icons => icons }, { :text => row.name, :color => color }, { :text => row.badge ? row.badge[0] : "", :font_size => :small, :color => color },
             { :text => row.level, :font_size => :small }, { :text => text.to_s, :font_size => :small, :color => text_color },
             { :text => ping.to_s, :font_size => :small, :color => ping_color, :align => :end }]
    { :key => key_of(row), :data => row, :cells => cells }
  end

  # Opens the menu of the player in a row of the list beside it, its choices from what the scripts
  # offer, those that cannot be taken now greyed.
  #
  # @param row [Hash, String] The list's row.
  # @param index [Integer] Its place in the list.
  def self.open_menu(row, index)
    player = row.is_a?(Hash) ? row[:data] : nil
    return unless player.is_a?(Row)

    options = menu_options(player)
    log("menu of #{who(player)}: #{options.map { |option| option.run ? option.text : "#{option.text} (refused: #{option.refusal})" }.join(', ')}")
    choices = options.map { |option| { :text => option.text.to_s, :enabled => option.run ? true : false } }
    @menu = UI::Menu.open(choices, :beside => @players, :row => index, :width => MENU_WIDTH) do |picked, _choice|
      @menu = nil
      picked ? choose(options[picked], player) : log("menu closed")
    end || nil
    @menu.on(:refuse) { |choice| refused(options[choices.index { |each| each.equal?(choice) }], player) } if @menu
  end

  # Closes the menu of a player, if it is open.
  def self.close_menu
    @menu.close if @menu && @menu.open?
    @menu = nil
  end

  # Tells why a greyed choice of a player's menu cannot be taken; the menu buzzed already.
  #
  # @param option [MGQ_MpActions::Option, nil] The choice.
  # @param row [Row] The player whose menu it is.
  def self.refused(option, row)
    return unless option

    log("#{option.text} for #{who(row)} refused: #{option.refusal || 'no reason given'}")
    MGQ_MpOverworldSync.notice(option.refusal) if option.refusal
  end

  # Names a player of the list for the log.
  #
  # @param row [Row, nil] The player.
  # @return [String] Their name and seat, or "the player" for the player.
  def self.who(row)
    return "nobody" unless row

    MGQ_MpOverworldSync.who(row.player)
  end

  # Takes a choice of a player's menu; a choice that leaves, such as a teleport, closes the
  # overview.
  #
  # @param option [MGQ_MpActions::Option] The choice.
  # @param row [Row] The player whose menu it is.
  def self.choose(option, row)
    log("chose #{option.text} for #{who(row)}")
    MGQ_MpActions.choose(option) { close("the choice leaves it") if option.leaves }
  end

  # Follows the window closing: its menu closes too, and the log says why.
  #
  # @param why [Symbol, String] The framework's reason, or the gate's text, see stay_reason.
  def self.closed(why)
    reason = @close_reason || CLOSE_REASONS.fetch(why, why.to_s)
    @close_reason = nil
    close_menu
    log("closed: #{reason}")
  end


  # Shows the key help of what the keys do now, once it changed.
  def self.show_help
    entries = help_entries
    @help.entries = entries unless entries == @help.entries
  end

  # Lists the key help's entries: the Players page's, an own page's, a mod's page's in its list or in
  # its pane; the keys that close name the cancel keys as the player bound them and the overview's
  # hotkey.
  #
  # @return [Array<Hash>] The entries, see Mod_Framework::UI::KeyHelp.
  def self.help_entries
    turn = { :key => "Left or right", :text => "page" }
    pick = { :key => "Up or down", :text => "pick" }
    close = { :button => :B, :key => MGQ_MpHotkeys.label(:overview), :text => "close" }
    return [turn, { :button => :C, :text => "invite, duel or trade" }, close] if @page == :players
    return [turn, pick, { :button => [:L, :R], :text => "read on" }, close] unless mod_page?(@page)
    return [turn, pick, { :button => :C, :text => "select" }, close] unless @views[@page] && @views[@page].in_pane?

    [pick, { :key => "Left or right", :text => "change" }, { :button => :C, :text => "press" }, { :button => :B, :key => "Ctrl", :text => "back" }]
  end
end

# What the overview takes part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpWorldOverview.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpWorldOverview.state_fields }
  MGQ_Multiplayer::Bridge.on(MGQ_MpWorldOverview::READ_EVENT) { |_read| MGQ_MpWorldOverview.tell }
rescue => e
  MGQ_MpWorldOverview.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What the overview adds to the action wheel, through ui_actions.rbx.

begin
  MGQ_MpActions.wheel_center { MGQ_MpWorldOverview.wheel_option }
rescue => e
  MGQ_MpWorldOverview.log("action wheel FAILED: #{e.class}: #{e.message}")
end

# The overview's window among those the player moves and resizes, listed before it first opens.

begin
  Mod_Framework::UI::Layout.register(MGQ_MpWorldOverview::LAYOUT_ID, MGQ_MpWorldOverview::LAYOUT_NAME, :min_size => MGQ_MpWorldOverview::MIN_SIZE)
rescue => e
  MGQ_MpWorldOverview.log("layout FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the overview's hotkey and what it shows.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "world_overview") { MGQ_MpWorldOverview.on_map unless scene_changing? }
rescue => e
  MGQ_MpWorldOverview.log("hooks FAILED: #{e.class}: #{e.message}")
end
