#----------------------------------------------------------------
#  ui_raid_bar.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Counted its scans and redraws by the bridge's frame
#      Paulinchen  2026-11-01: Built the bars on the Mod Framework's components and took them from the DLL's bars
#                            - Docked the map's strip at the top and made the battle's small by a click on its hint too
#      Paulinchen  2026-10-31: Placed its strip through the Mod Framework's layout
#      Paulinchen  2026-10-28: Asked the DLL for the troops the map's pages fight in one call
#      Paulinchen  2026-10-23: Kept the bars off the live map behind menus
#      Paulinchen  2026-10-17: Showed the bars above the bosses' stand-ins of frozen fights
#      Paulinchen  2026-10-15: Showed no bars over the Colosseum receptionist
#      Paulinchen  2026-10-13: Showed the bars of the raid bosses in Classic worlds and single player, each turned on and off in the Mod Config
#      Paulinchen  2026-10-12: Kept the troops of a common event only when its walk missed none
#                            - Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Read the map's viewports and character sprites through MGQ_MpGame
#      Paulinchen  2026-10-11: Drew the gauges' edge, empty part and the title in the interface preset's colors
#                            - Made the strip a box the player moves and resizes in width with Alt
#                            - Cropped the battle's strip to its gauges in small mode
#                            - Made room at the top for the strip and pushed the game's own boss bar down only while the strip lies there
#                            - Took the font, the outline, the plate and the slide timing from the shared style
#                            - Named the hotkey that makes the battle's strip small in its title
#      Paulinchen  2026-10-10: Showed a boss of several enemies with a name and a gauge per enemy, sharing the gauge's width
#                            - Kept a shortened HP from reading above the max
#                            - Showed no bars in the Hades rematch hall
#                            - Created
#
#----------------------------------------------------------------

# The HP bars of a Raid World's bosses (see battles_raid_pool.rbx): in a battle that fights a boss's
# pools, a strip across the top of the screen with the boss's title and, for each of its enemies, its
# name over a gauge with its HP and how much is left inside (StripView); on the map, a bar above
# each event that starts a boss battle and each boss's stand-in of a frozen fight (see
# ui_raid_freeze.rbx, OverheadView), or the same strip docked at the top of the screen while no such
# event shows, which the boxes docked at the top corners make room for. The player moves the strip
# and resizes it in width with Alt, one place for the map's and the battle's. A bar shows while the
# relay keeps the boss's pool, or the story has not beaten it. The DLL works the bars out
# (hud.battle_bar, hud.map_bar): the max HP is the relay's once it told one, else the boss's own at
# the player's difficulty, scaled by its tier; the scripts find the boss's events and enemies and
# draw the bars on the Mod Framework's components.
#
# The raid bosses of a Classic world or of single player (see battles_raid_tiers.rbx) show the same
# bars: in battle each enemy's own HP, on the map the boss's full HP, since nothing keeps it between
# battles. The player turns either bar off for them in the Mod Config (MGQ Online SP); a Raid World
# always shows both.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpRaidBar
  # The topic that works out the bar of the battle running, HudTopics.BattleBarTopic.
  BATTLE_BAR_TOPIC = "hud.battle_bar"

  # The topic that works out a troop's bar on the map, HudTopics.MapBarTopic.
  MAP_BAR_TOPIC = "hud.map_bar"

  # Frames between two settings of a bar whose numbers changed, since the HP the pool gains back
  # changes them every frame.
  REDRAW_FRAMES = 6

  # Frames between two looks at the map's events for the bosses' battles.
  SCAN_FRAMES = 30

  # Height of the strip across the top of the screen: its title, the names and the gauges.
  STRIP_HEIGHT = 86

  # Height of the battle's strip while it shows its gauges alone, see small?.
  SMALL_STRIP_HEIGHT = 36

  # The strip's place id, which names its place in the Mod Framework's settings.
  STRIP_BOX = :raid_bar

  # The strip's name while the player arranges the boxes.
  STRIP_BOX_NAME = "Raid boss bar"

  # Pixels from the screen's top within which the strip counts as lying at the top, where the game's
  # own boss bar moves below it.
  TOP_REACH = 4

  # The setting in Player.ini that keeps the battle's strip to its gauges alone.
  SMALL_SETTING = "raid_bar_small"

  # Depth of the strip in battle among the roots under the game's windows: over the battlers and
  # pictures.
  BATTLE_Z = 90

  # Where the game's own HP bar of a boss lies (Basic Enemy HP Bars Lite), which the strip pushes down.
  GAME_BOSS_BAR_Y = -12

  # The game's variable of the share of their own HP enemies have at the player's difficulty.
  DIFFICULTY_VARIABLE = 41

  # Steps to a boss's event when the map shows none.
  FAR = 9999

  # The settings in Player.ini that turn off the raid bosses' bars outside Raid Worlds with 0, on
  # the map and in battle.
  SHOWN_SETTINGS = { :map => "raid_bar_map", :battle => "raid_bar_battle" }

  # The keys of the Mod Config rows that turn the bars outside Raid Worlds on and off, which
  # ui_single_player.rbx adds.
  OPTIONS = { :map => :mp_sp_raid_bar_map, :battle => :mp_sp_raid_bar_battle }

  # The names of the Mod Config rows that turn the bars outside Raid Worlds on and off.
  OPTION_NAMES = { :map => "Raid Bar on Map", :battle => "Raid Bar in Battle" }

  # The help of the Mod Config rows that turn the bars outside Raid Worlds on and off.
  OPTION_HELPS = {
    :map => "Shows a raid boss's HP bar above it on the map, or at the top while it stands out of sight.\n" \
            "Outside Raid Worlds only: single player and Classic worlds with raid bosses.",
    :battle => "Shows a raid boss's HP bar at the top of the battle; the Party Box hotkey shows its gauges alone.\n" \
               "Outside Raid Worlds only: single player and Classic worlds with raid bosses.",
  }

  # A bar's content, as the DLL works it out.
  #
  # @!attribute title [String] What shows above the names, see MGQ_MpRaidBosses.title.
  # @!attribute gauges [Array<Gauge>] One gauge per enemy of the boss, in the troop's order.
  Bar = Struct.new(:title, :gauges)

  # One enemy's gauge of a bar.
  #
  # @!attribute name [String] The enemy's name, lettered as the game letters repeated names.
  # @!attribute hp [Integer] Its HP.
  # @!attribute max [Integer] Its max HP.
  # @!attribute numbers [String] Its HP and max HP shortened, such as "236,167 B / 1,009,500 B".
  # @!attribute percent [String] How much is left, such as "23.4%", never "0.0%" while any is.
  Gauge = Struct.new(:name, :hp, :max, :numbers, :percent)

  # The last look at the map's events: its map id and SCAN_FRAMES step, and the events found.
  @scanned = nil

  # Each event's command list with the troops it starts, by the event, see troops_of.
  @event_troops = {}

  # Enemies' own max HP, by the enemy and the difficulty, see own_hp.
  @own_hp = {}

  # Whether the strip shows in battle.
  @battle_shown = false

  # Whether each bar outside Raid Worlds shows, by :map and :battle, as Player.ini keeps it.
  @shown = {}

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "raid bar"

  # The Mod Framework's interface.
  UI = Mod_Framework::UI

  # Reports whether the player wants a bar of the raid bosses outside Raid Worlds, as Player.ini
  # keeps it, on until they turn it off.
  #
  # @param where [Symbol] :map or :battle.
  # @return [Boolean] Whether it shows.
  def self.shown?(where)
    @shown[where] = MGQ_Multiplayer::Player.setting(SHOWN_SETTINGS[where]).to_s != "0" unless @shown.key?(where)
    @shown[where]
  end

  # Shows or hides a bar of the raid bosses outside Raid Worlds and keeps the choice in Player.ini.
  #
  # @param where [Symbol] :map or :battle.
  # @param shown [Boolean] Whether it shows.
  def self.show_bar(where, shown)
    @shown[where] = shown ? true : false
    MGQ_Multiplayer::Player.store(SHOWN_SETTINGS[where], @shown[where] ? 1 : 0)
    log("the raid boss bar #{where == :map ? 'on the map' : 'in battle'} is #{@shown[where] ? 'on' : 'off'} outside Raid Worlds")
  rescue => e
    log("keeping whether the raid boss bar shows FAILED: #{e.class}: #{e.message}")
  end

  # Finds the bar of the battle running when it fights a boss's pools, or its boss fights at its
  # tier outside a Raid World while the player shows that bar: the DLL's gauge per own enemy with
  # its HP as the battle has it, against its pool's max HP once the relay told it.
  #
  # @return [Bar, nil] The bar, nil for none.
  def self.battle_bar
    fight = MGQ_MpRaidPool.fight
    if fight
      enemies = fight.members.map do |member|
        enemy = $game_troop.members[member.index]
        enemy ? [enemy.name.to_s, enemy.hp.to_i, enemy.mhp.to_i, enemy.dead? ? true : false, member.key.to_s] : nil
      end
    else
      fight = defined?(MGQ_MpRaidTiers) ? MGQ_MpRaidTiers.fight : nil
      return nil unless fight && shown?(:battle)

      enemies = MGQ_MpRaidPool.own_enemies(fight.own).map { |enemy| enemy ? [enemy.name.to_s, enemy.hp.to_i, enemy.mhp.to_i, enemy.dead? ? true : false, nil] : nil }
    end
    bar_of(MGQ_Multiplayer::Bridge.call(BATTLE_BAR_TOPIC, "title" => MGQ_MpRaidBosses.title(fight.troop).to_s, "enemies" => enemies.compact))
  end

  # Reads a bar as the DLL answers it.
  #
  # @param answer [Array, nil] [title, [[name, hp, max, numbers, percent], ...]], nil for none.
  # @return [Bar, nil] The bar, nil for none.
  def self.bar_of(answer)
    return nil unless answer.is_a?(Array) && answer[1].is_a?(Array) && !answer[1].empty?

    Bar.new(answer[0].to_s, answer[1].map { |name, hp, max, numbers, percent| Gauge.new(name.to_s, hp.to_i, max.to_i, numbers.to_s, percent.to_s) })
  end

  # Reports whether the map shows the bars of the raid bosses outside a Raid World: they fight at
  # their tier and the player shows their map bar.
  #
  # @return [Boolean] Whether it does.
  def self.tier_map?
    defined?(MGQ_MpRaidTiers) && MGQ_MpRaidTiers.active? && shown?(:map) ? true : false
  end

  # Reports whether the game's own top message shows in battle, which draws its text straight over
  # the strip.
  #
  # @return [Boolean] Whether it does.
  def self.top_message?
    $game_message && $game_message.visible && $game_message.position == 0 ? true : false
  end

  # Notes whether the strip shows in battle, which moves the game's own bar of a boss down.
  #
  # @param shown [Boolean] Whether it does.
  def self.battle_shown=(shown)
    @battle_shown = shown
  end

  # Notes where the battle's strip ends while it lies at the top of the screen, which the game's own
  # bar of a boss moves below.
  #
  # @param bottom [Integer, nil] The bottom of the strip, nil while it lies elsewhere, which leaves
  #   the game's bar where the game draws it.
  def self.battle_bottom=(bottom)
    @battle_bottom = bottom
  end

  # Reports whether the strip lies at the top of the screen, within TOP_REACH.
  #
  # @param rect [Rect] Where the strip lies.
  # @return [Boolean] Whether it does.
  def self.at_top?(rect)
    rect.y <= TOP_REACH
  end

  # Reports whether the battle's strip shows its gauges alone, without the boss's title and the
  # names, as the player last chose.
  #
  # @return [Boolean] Whether it does.
  def self.small?
    @small = MGQ_Multiplayer::Player.setting(SMALL_SETTING).to_s == "1" if @small.nil?
    @small
  end

  # Shows the battle's strip with or without the boss's title and the names on the party box's
  # hotkey (Tab unless the player binds another), keeping the choice in Player.ini. Called by the
  # battle every frame while its strip shows, so a press of the hotkey is seen once.
  def self.on_battle
    return unless defined?(MGQ_MpHotkeys) && MGQ_MpHotkeys.pressed?(:party_box)
    return MGQ_MpHotkeys.log_refusal(:party_box, "the chat box is open") if defined?(MGQ_MpChat) && MGQ_MpChat.typing?

    toggle_small
  rescue => e
    log_once(:on_battle, "changing the battle's boss bar failed: #{e.class}: #{e.message}")
  end

  # Shows the battle's strip with or without the boss's title and the names, keeping the choice in
  # Player.ini, as its hotkey and a click on its hint do.
  def self.toggle_small
    @small = !small?
    MGQ_Multiplayer::Player.store(SMALL_SETTING, @small ? 1 : 0)
    log("the battle's boss bar shows #{@small ? 'its gauges alone' : 'the title and the names again'}")
    Sound.play_cursor
  rescue => e
    log("changing the battle's boss bar FAILED: #{e.class}: #{e.message}")
  end

  # Moves the game's own HP bar of a boss below the strip while the strip shows at the top of the
  # screen. Called after Sprite_Battler#update_hp_bar, which puts it back at the top every frame.
  #
  # @param sprite [Sprite_Battler] The battler's sprite.
  def self.push_down(sprite)
    return unless @battle_shown && @battle_bottom

    battler = sprite.battler
    return unless battler.respond_to?(:boss?) && battler.boss?

    bar = MGQ_MpGame.get(sprite, :hp_bar)
    bar.y = GAME_BOSS_BAR_Y + @battle_bottom if bar && bar.visible
  rescue => e
    log_once(:push_down, "moving the game's boss bar failed: #{e.class}: #{e.message}")
  end

  # The map.

  # Lists the events of the map whose page starts a raid boss's battle that shows a bar (see
  # shown_troop?), looking anew every SCAN_FRAMES and on another map, and the stand-ins of the
  # bosses of frozen fights (see ui_raid_freeze.rbx).
  #
  # @return [Array<Array>] Each event or stand-in with its troop.
  def self.boss_events
    return [] unless $game_map && (MGQ_MpRaidPool.active? || tier_map?)

    scanned_events + freeze_targets
  end

  # Lists the stand-ins of the bosses of the map's frozen fights whose battles show a bar.
  #
  # @return [Array<Array>] Each stand-in with its troop.
  def self.freeze_targets
    return [] unless defined?(MGQ_MpRaidFreezeUi)

    MGQ_MpRaidFreezeUi.bar_targets.select { |_standin, troop| shown_troop?(troop) }
  end

  # Lists the events of the map whose page starts a raid boss's battle that shows a bar, see
  # boss_events.
  #
  # @return [Array<Array>] Each event with its troop.
  def self.scanned_events
    stamp = [$game_map.map_id, MGQ_Multiplayer::Bridge.frame_number / SCAN_FRAMES]
    return @scanned[1] if @scanned && @scanned[0] == stamp

    @event_troops = {} unless @scanned && @scanned[0][0] == stamp[0]

    events = $game_map.events.values
    look_up_troops(events)
    found = events.map do |event|
      troop = troops_of(event).find { |id| shown_troop?(id) }
      troop ? [event, troop] : nil
    end.compact
    @scanned = [stamp, found]
    found
  end

  # Asks the DLL in one call for the troops of the events whose page changed since it last told
  # them (MGQ_MpCoopEvents.page_troops), the common events that turn the Colosseum's switch on left
  # out, since their fights reuse the bosses' troops but are no raids.
  #
  # @param events [Array<Game_Event>] The map's events.
  def self.look_up_troops(events)
    changed = events.select do |event|
      kept = @event_troops[event]
      event.list && !(kept && kept[0].equal?(event.list))
    end
    return if changed.empty?

    troops = MGQ_MpCoopEvents.page_troops(changed, MGQ_MpRaidPool::COLOSSEUM_SWITCH)
    changed.each { |event| @event_troops[event] = [event.list, troops[event.id] || []] }
  end

  # Lists the troops whose battles an event's page starts, through common events too, as the DLL
  # last told them for its page (see look_up_troops).
  #
  # @param event [Game_Event] The event.
  # @return [Array<Integer>] The troops, in their order; none for an erased event or one not looked up.
  def self.troops_of(event)
    kept = @event_troops[event]
    kept && event.list && kept[0].equal?(event.list) ? kept[1] : []
  end

  # Reports whether a troop's battle shows a bar: the last phase of a raid boss with pools whose
  # relay keeps a pool of it, or whose milestone the story has not beaten, outside the Hades
  # rematches, which fight no pool; outside a Raid World as MGQ_MpRaidTiers.shown_troop? says.
  #
  # @param troop [Integer] The troop.
  # @return [Boolean] Whether it does.
  def self.shown_troop?(troop)
    pool = MGQ_MpRaidPool
    return MGQ_MpRaidTiers.shown_troop?(troop) unless pool.active?

    return false unless MGQ_MpRaidBosses.last_phase?(troop) && !pool::UNPOOLED[troop] && !pool.hades?

    keys = pool.troop_keys(troop)
    return false if keys.empty?

    pool.pooled_troop?(troop) || keys.any? { |key| pool.pool(key) }
  end

  # Finds a troop's bar on the map, as the DLL works it out: in a Raid World a gauge per pool of the
  # troop with its HP now, the HP the pool gained back since included, the enemy's own max HP times
  # its tier's factor for a pool the relay told nothing of; outside a Raid World a full gauge per
  # enemy at its max HP in battle, since every battle fights the boss anew. Names that repeat
  # within the troop are lettered as the game letters them in battle.
  #
  # @param troop [Integer] The troop.
  # @return [Bar, nil] The bar, nil for none.
  def self.map_bar(troop)
    pool = MGQ_MpRaidPool
    enemies = troop_enemies(troop).map { |id| [$data_enemies[id].name.to_s, own_hp(id)] }
    table = $game_troop && $game_troop.respond_to?(:letter_table) ? Array($game_troop.letter_table) : []
    request = { "title" => MGQ_MpRaidBosses.title(troop).to_s, "keys" => pool.active? ? pool.troop_keys(troop).map { |key| key.to_s } : nil, "enemies" => enemies,
                "factor" => MGQ_MpRaidBosses.factor(troop, :mhp).to_i, "letters" => table.empty? ? nil : table.map { |letter| letter.to_s } }
    bar_of(MGQ_Multiplayer::Bridge.call(MAP_BAR_TOPIC, request))
  end

  # Lists the enemies a troop's setup makes, by the database.
  #
  # @param troop [Integer] The troop.
  # @return [Array<Integer>] Their ids.
  def self.troop_enemies(troop)
    data = $data_troops && $data_troops[troop]
    data ? data.members.map { |member| member.enemy_id }.select { |id| $data_enemies[id] } : []
  end

  # Finds an enemy's own max HP at the player's difficulty, as the game computes it in battle, kept
  # while the difficulty stays, or its database value when that fails.
  #
  # @param enemy_id [Integer] The enemy.
  # @return [Integer] The max HP.
  def self.own_hp(enemy_id)
    @own_hp[[enemy_id, $game_variables[DIFFICULTY_VARIABLE]]] ||= begin
      Game_Enemy.new(0, enemy_id).mhp.to_i
    rescue => e
      log_once([:own_hp, enemy_id], "computing the max HP of enemy #{enemy_id} failed (#{e.class}: #{e.message}), its database value stands in")
      $data_enemies[enemy_id].params[0].to_i
    end
  end

  # Reports whether an event shows on the map, a marker such as a flame or a tile counting as its
  # boss.
  #
  # @param event [Game_Event] The event.
  # @param sprite [Sprite_Character, nil] Its sprite.
  # @return [Boolean] Whether it shows.
  def self.shows?(event, sprite)
    looks = !event.character_name.to_s.empty? || event.tile_id.to_i > 0
    looks && !event.transparent && event.opacity > 0 && !sprite.nil? && sprite.visible
  end

  # Counts the steps from a tile to the nearest event of the map that starts a troop's battle, see
  # boss_events.
  #
  # @param troop [Integer] The troop.
  # @param x [Integer] The tile's x.
  # @param y [Integer] The tile's y.
  # @return [Integer] The steps, diagonal steps counted as one; FAR when the map has none.
  def self.distance_to_boss(troop, x, y)
    events = boss_events.select { |_event, id| id == troop }.map { |event, _id| event }
    events.map { |event| [(event.x - x).abs, (event.y - y).abs].max }.min || FAR
  rescue => e
    log_once(:distance, "finding the boss's event failed: #{e.class}: #{e.message}")
    FAR
  end

  # A raid boss's bar on the Mod Framework's components: its title and, below it, each enemy's name
  # over a gauge with the HP inside, the gauges sharing the row's width; the strip at the top or the
  # smaller bar above its event (Look). The parts are built anew for a boss of other enemies, so
  # their damage trails start anew, and their numbers are set at most every REDRAW_FRAMES.
  class BarParts
    # The sizes of a bar's parts: the fonts of its title and names, the height of the title's line,
    # the gauges' height and the font of the numbers inside them, nil for gauges without numbers.
    Look = Struct.new(:title, :name, :title_height, :gauge, :numbers)

    # The strip's parts, which take STRIP_HEIGHT.
    STRIP_LOOK = Look.new(20, 24, 24, 30, 21)

    # The parts of the bar above an event: thin gauges without numbers.
    OVERHEAD_LOOK = Look.new(16, 18, 20, 8, nil)

    # Pixels between the gauges and the names of a boss of several enemies.
    GAUGE_GAP = 6

    # Smallest font size the names of a boss of several enemies shrink to, so each fits its gauge.
    MIN_NAME_SIZE = 14

    # The filled part's colors from its top down, a maroon gradient.
    FILL_COLORS = [Color.new(156, 32, 50), Color.new(110, 16, 30), Color.new(70, 8, 18)]

    # How a gauge's HP reads with how much is left.
    LONG_TEXT = "%s  (%s)"

    # Makes the parts, empty until the first bar: the title as the first part of where it goes, the
    # names and the gauges each in a row added after the parts already there.
    #
    # @param look [Look] The sizes of the parts.
    # @param title_parent [Mod_Framework::UI::Component] Where the title goes.
    # @param names_parent [Mod_Framework::UI::Component] Where the row of names goes.
    # @param gauges_parent [Mod_Framework::UI::Component] Where the row of gauges goes.
    # @param row_width [Integer, nil] The width of the names' and gauges' rows, nil for their
    #   parent's.
    def initialize(look, title_parent, names_parent, gauges_parent, row_width = nil)
      @look = look
      @names_parent = names_parent
      @gauges_parent = gauges_parent
      @row_width = row_width
      row = title_parent.layout == :row
      @title = title_parent.add_label("", :height => look.title_height, :align => :center, :font_size => look.title, :color => :title, :plate => :text,
                                      :grow => row ? 1 : 0)
      @names = nil
      @set = nil
      @set_at = nil
    end

    # Shows a bar: builds the names and gauges anew for other enemies, and sets the title, the rates
    # and the numbers once they changed, the numbers at most every REDRAW_FRAMES.
    #
    # @param bar [Bar] The bar.
    def show(bar)
      names = bar.gauges.map { |gauge| gauge.name }
      build(names) unless names == @names
      content = [bar.title, bar.gauges.map { |gauge| [gauge.hp, gauge.max, gauge.numbers, gauge.percent] }]
      return if content == @set

      now = MGQ_Multiplayer::Bridge.frame_number
      return if @set && @set[0] == bar.title && @set_at && now - @set_at < REDRAW_FRAMES

      @set = content
      @set_at = now
      @title.text = bar.title
      bar.gauges.each_with_index do |gauge, index|
        @gauges[index].rate = gauge.max > 0 ? UI.within(gauge.hp.to_f / gauge.max, 0.0, 1.0) : 0.0
        @gauges[index].text = [format(LONG_TEXT, gauge.numbers, gauge.percent), gauge.numbers, gauge.percent] if @look.numbers
      end
    end

    # Sets the width of the names' and gauges' rows.
    #
    # @param width [Integer] The width.
    def row_width=(width)
      return if width == @row_width

      @row_width = width
      [@name_row, @gauge_row].compact.each { |row| row.width = width }
    end

    # Lists the gauges, for the tests.
    #
    # @return [Array<Mod_Framework::UI::Gauge>] The gauges, one per enemy.
    def gauges
      @gauges || []
    end

    private

    # Builds a name and a gauge per enemy of a boss, in place of those of another.
    #
    # @param names [Array<String>] The enemies' names.
    def build(names)
      @names = names
      @set = nil
      @names_parent.remove(@name_row) if @name_row
      @gauges_parent.remove(@gauge_row) if @gauge_row
      @name_row = @names_parent.add_row(:gap => GAUGE_GAP, :align => :center, :width => @row_width)
      names.each do |name|
        @name_row.add_label(name, :grow => 1, :align => :center, :font_size => @look.name, :min_font_size => MIN_NAME_SIZE, :plate => :text)
      end
      @gauge_row = @gauges_parent.add_row(:gap => GAUGE_GAP, :align => :center, :width => @row_width)
      options = { :grow => 1, :height => @look.gauge, :framed => true, :colors => FILL_COLORS, :vertical => true, :trail => true }
      options[:font_size] = @look.numbers if @look.numbers
      @gauges = names.map { @gauge_row.add_gauge(options.dup) }
    end
  end

  # The strip across the top of the screen: in battle where the player put it, over the battlers
  # and under the battle's windows, hidden while the game's message shows at the top; on the map
  # docked at the top while no boss event shows, which the boxes docked at the top corners make
  # room for. Small in battle (the party box's hotkey, or a click on its hint), it shows the gauges
  # alone, the title and the names sliding away as its height eases down.
  class StripView
    # Share of the screen's width the strip's row of gauges takes, at most the strip's width less
    # MARGIN on each side.
    GAUGE_SHARE = 0.65

    # Pixels the strip's rows keep from its sides at least.
    MARGIN = 6

    # Most enemies a boss has, whose gauges the narrowest strip still shows, see min_width.
    MAX_GAUGES = 3

    # The longest texts a gauge shows how much is left with, which the narrowest strip's gauges
    # still fit.
    PERCENT_SAMPLES = ["100.0%", "<0.1%"]

    # What the battle's strip says at the right of its title, with the hotkey that makes it small.
    BARS_HINT = "%s: bars"

    # Frames the strip's height eases over as it turns small or full.
    SLIDE_FRAMES = 8

    # @return [Mod_Framework::UI::Box] The strip's box.
    attr_reader :root

    # @return [BarParts] The strip's title, names and gauges.
    attr_reader :parts

    # Makes the strip and opens it, hidden until it shows a bar.
    #
    # @param battle [Boolean] Whether it is the battle's, else the map's.
    def initialize(battle)
      @battle = battle
      @bar = nil
      @small = battle && MGQ_MpRaidBar.small?
      options = { :id => STRIP_BOX, :place_name => STRIP_BOX_NAME, :frame => false, :under_windows => true, :z => battle ? BATTLE_Z : UI::Z[:labels],
                  :movable => true, :resizable => :width, :min_size => [StripView.min_width, SMALL_STRIP_HEIGHT], :width => Graphics.width,
                  :height => @small ? SMALL_STRIP_HEIGHT : STRIP_HEIGHT, :mouse => :parts, :tail => true, :gap => 0, :fade => !battle,
                  :hide_while => lambda { @bar.nil? } }
      options[battle ? :at : :dock] = battle ? [0, 0] : :top
      @root = UI::Box.new(options)
      head = @root.add_column(:gap => 0)
      title_row = head.add_row(:height => BarParts::STRIP_LOOK.title_height)
      @parts = BarParts.new(BarParts::STRIP_LOOK, title_row, head, @root, row_width)
      add_hint(title_row) if battle
      @root.open
    end

    # Finds the narrowest the strip gets while it still shows all it has: its title line with the
    # hint at either side of the longest title, and the gauges of a boss of MAX_GAUGES enemies, each
    # still showing how much is left; the names shrink and are cut, as on the whole screen.
    #
    # @return [Integer] The width, the screen's when measuring fails.
    def self.min_width
      hint = UI.font_bitmap(UI::Style::TINY_SIZE).text_size(format(BARS_HINT, MGQ_MpHotkeys.label(:party_box))).width
      title = UI.font_bitmap(BarParts::STRIP_LOOK.title)
      titles = MGQ_MpRaidBosses::TITLES.keys + MGQ_MpRaidBosses::TIERS.keys.map { |tier| "Tier #{tier} Raid Boss" }
      widest = titles.map { |text| title.text_size(text).width }.max.to_i
      percent = UI.font_bitmap(BarParts::STRIP_LOOK.numbers)
      gauge = PERCENT_SAMPLES.map { |text| percent.text_size(text).width }.max + 2 * MARGIN
      [hint * 2 + widest + 2 * MARGIN, gauge * MAX_GAUGES + BarParts::GAUGE_GAP * (MAX_GAUGES - 1) + 2 * MARGIN].max
    rescue => e
      MGQ_MpRaidBar.log("measuring the narrowest strip FAILED (#{e.class}: #{e.message}), it keeps the screen's width")
      Graphics.width
    end

    # Shows a bar, or hides the strip for none.
    #
    # @param bar [Bar, nil] The bar.
    def show(bar)
      @bar = bar
      return unless bar

      @parts.row_width = row_width
      @parts.show(bar)
      follow_small if @battle
    end

    # Shows the battle's bar while the battle fights a boss's pools and the game's top message does
    # not show, and tells the game's own boss bar where the strip ends. Called by the battle every
    # frame.
    def update_battle
      bar = MGQ_MpRaidBar.top_message? ? nil : MGQ_MpRaidBar.battle_bar
      MGQ_MpRaidBar.on_battle if bar
      show(bar)
      rect = @root.rect
      MGQ_MpRaidBar.battle_shown = !bar.nil?
      MGQ_MpRaidBar.battle_bottom = rect && MGQ_MpRaidBar.at_top?(rect) ? rect.y + rect.height : nil
    rescue => e
      @bar = nil
      MGQ_MpRaidBar.battle_shown = false
      MGQ_MpRaidBar.log_once(:battle, "showing the battle's boss bar failed: #{e.class}: #{e.message}")
    end

    # Closes the strip, with the scene's sprites.
    def close
      @root.close
    end

    private

    # Tells the width of the strip's rows: GAUGE_SHARE of the screen's width, but never past MARGIN
    # from a narrower strip's sides.
    #
    # @return [Integer] The width.
    def row_width
      strip = @root && @root.rect ? @root.rect.width : Graphics.width
      [(Graphics.width * GAUGE_SHARE).round, strip - 2 * MARGIN].min
    end

    # Adds the hint that names the hotkey that makes the battle's strip small at the right of the
    # title's line, which a click on it does too.
    #
    # @param title_row [Mod_Framework::UI::Component] The title's line.
    def add_hint(title_row)
      hint = title_row.add_button(format(BARS_HINT, MGQ_MpHotkeys.label(:party_box)), :flat => true, :quiet => true, :font_size => :tiny, :color => :dim)
      hint.on(:click) { MGQ_MpRaidBar.toggle_small }
    end

    # Eases the strip's height to its gauges alone or back to whole once the player changed it.
    def follow_small
      small = MGQ_MpRaidBar.small?
      return if small == @small

      @small = small
      @root.animate({ :size => [nil, small ? SMALL_STRIP_HEIGHT : STRIP_HEIGHT] }, :frames => SLIDE_FRAMES)
    end
  end

  # The bar above a boss's event or its stand-in on the map: 240 wide, 480 for a boss of several
  # enemies, following the event or the stand-in's sprite, under its feet where the screen has no
  # room above.
  class OverheadView
    # Width of the bar for a boss of one enemy.
    WIDTH = 240

    # Width of the bar for a boss of several enemies, so their names still read.
    WIDE_WIDTH = 480

    # Pixels between the sprite and its bar.
    GAP = 4

    # @return [Mod_Framework::UI::Box] The bar's box.
    attr_reader :root

    # @return [BarParts] The bar's title, names and gauges.
    attr_reader :parts

    # Makes the bar over a boss and opens it.
    #
    # The map rebuilds the sprites of its events on a transfer, so the bar follows the event itself,
    # whose sprite the framework finds anew; a stand-in's sprite is the mod's own and stays.
    #
    # @param target [Game_Event, Sprite] The event, or the stand-in's sprite.
    def initialize(target)
      @root = UI::Box.new(:frame => false, :follow => target, :side => :above, :follow_gap => GAP, :flip => true, :width => WIDTH, :mouse => false, :gap => 0)
      @parts = BarParts.new(BarParts::OVERHEAD_LOOK, @root, @root, @root)
      @root.open
    end

    # Shows a bar, as wide as its enemies need.
    #
    # @param bar [Bar] The bar.
    def show(bar)
      width = bar.gauges.size > 1 ? WIDE_WIDTH : WIDTH
      @root.width = width unless @root.width == width
      @parts.show(bar)
    end

    # Closes the bar.
    def close
      @root.close
    end
  end

  # The bars on the map: one above each boss's event that shows, else the strip at the top.
  class MapBars
    # Creates the bars, none shown.
    def initialize
      @overhead = {}
      @strip = nil
    end

    # Shows a bar above each boss's event that shows on the map, else the strip with the first
    # boss's bar.
    #
    # @param sprites [Array<Sprite_Character>] The map's character sprites.
    # @param standins [Array<Sprite_Character>] The sprites of the bosses' stand-ins.
    def update(sprites, standins = [])
      pairs = MGQ_MpRaidBar.boss_events
      shown = pairs.map do |event, troop|
        sprite = sprites.find { |candidate| candidate.character.equal?(event) }
        standin = sprite ? nil : standins.find { |candidate| candidate.character.equal?(event) }
        MGQ_MpRaidBar.shows?(event, sprite || standin) ? [event, troop, standin || event] : nil
      end.compact
      update_overhead(shown)
      update_strip(shown.empty? && !pairs.empty? ? pairs.first[1] : nil)
    rescue => e
      MGQ_MpRaidBar.log_once(:map, "showing the boss bars failed: #{e.class}: #{e.message}")
    end

    # Hands out the bars above events, for the tests.
    #
    # @return [Hash{Game_Event => OverheadView}] The bars by event.
    def overhead
      @overhead
    end

    # Hands out the strip, for the tests.
    #
    # @return [StripView, nil] The strip, nil before the first.
    def strip
      @strip
    end

    # Closes every bar.
    def dispose
      @overhead.each_value { |bar| bar.close }
      @overhead.clear
      @strip.close if @strip
      @strip = nil
    end

    private

    # Shows a bar above each boss's event that shows, closing those of events that no longer do.
    #
    # @param shown [Array<Array>] Each event with its troop and what its bar follows.
    def update_overhead(shown)
      events = shown.map { |event, _troop, _target| event }
      @overhead.keys.reject { |event| events.any? { |kept| kept.equal?(event) } }.each { |event| @overhead.delete(event).close }
      shown.each do |event, troop, target|
        bar = MGQ_MpRaidBar.map_bar(troop)
        (@overhead[event] ||= OverheadView.new(target)).show(bar) if bar
      end
    end

    # Shows the strip with a troop's bar, or hides it.
    #
    # @param troop [Integer, nil] The troop, nil to hide it.
    def update_strip(troop)
      return @strip.show(nil) if troop.nil? && @strip
      return unless troop

      (@strip ||= StripView.new(false)).show(MGQ_MpRaidBar.map_bar(troop))
    end
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After the battle's sprites, the strip of a battle that fights a boss's pools.
  MGQ_MpHooks.after(Spriteset_Battle, :update, "ui_raid_bar") { (@mgq_mp_raid_bar ||= MGQ_MpRaidBar::StripView.new(true)).update_battle }

  MGQ_MpHooks.before(Spriteset_Battle, :dispose, "ui_raid_bar") do
    @mgq_mp_raid_bar.close if @mgq_mp_raid_bar
    @mgq_mp_raid_bar = nil
    MGQ_MpRaidBar.battle_shown = false
  end

  # After the map's sprites, the bosses' bars, also above the stand-ins of frozen fights, never on
  # the map behind a menu.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_raid_bar") do
    next unless mgq_mp_hud?

    @mgq_mp_raid_bars ||= MGQ_MpRaidBar::MapBars.new
    standins = defined?(MGQ_MpRaidFreezeUi) ? MGQ_MpRaidFreezeUi.sprites_of(self) : []
    @mgq_mp_raid_bars.update(MGQ_MpGame.get(self, :character_sprites), standins)
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_raid_bar") do
    @mgq_mp_raid_bars.dispose if @mgq_mp_raid_bars
    @mgq_mp_raid_bars = nil
  end

  # The game's own HP bar of a boss moves below the battle's strip, as the game draws it.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "ui_raid_bar") do
    if Sprite_Battler.method_defined?(:update_hp_bar)
      MGQ_MpHooks.after(Sprite_Battler, :update_hp_bar, "ui_raid_bar") { MGQ_MpRaidBar.push_down(self) }
    end
  end
rescue => e
  MGQ_MpRaidBar.log("hooks FAILED: #{e.class}: #{e.message}")
end
