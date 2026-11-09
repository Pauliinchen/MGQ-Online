#----------------------------------------------------------------
#  ui_raid_bar.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Framed the gauges by the Mod Framework's border: :theme two pixels thick, which replaced framed:
#      Paulinchen  2026-11-08: Listed the tiles of a boss's events in place of counting the steps to them
#                            - Gave its UI ids the mgq_online_ prefix
#      Paulinchen  2026-11-06: Read the room at the top through the Mod Framework's UI.room
#                            - Drew the strip and the bars over the bosses as huds of the Mod Framework's UI layer, the strip docked at the top in battle too
#      Paulinchen  2026-11-05: Asked the DLL in one call per scan which troops' battles show a bar, and read the titles and tiers from its table
#                            - Kept and read its switches in Player.ini as true or false, which the DLL writes as 1 or 0
#                            - Counted its scans and redraws by the bridge's frame
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
# name over a gauge with its HP and how much is left inside (RaidStrip); on the map, a bar above
# each event that starts a boss battle and each boss's stand-in of a frozen fight (see
# ui_raid_freeze.rbx, BossBar), or the same strip docked at the top of the screen while no such
# event shows, which the parts at the top corners make room for. The player moves the strip
# and resizes it in width with Alt, one place for the map's and the battle's. A bar shows while the
# relay keeps the boss's pool, or the story has not beaten it. The DLL works the bars out
# (hud.battle_bar, hud.map_bar): the max HP is the relay's once it told one, else the boss's own at
# the player's difficulty, scaled by its tier; the scripts find the boss's events and enemies and
# draw the bars as huds of the Mod Framework's UI layer.
#
# The raid bosses of a Classic world or of single player (see battles_raid_tiers.rbx) show the same
# bars: in battle each enemy's own HP, on the map the boss's full HP, since nothing keeps it between
# battles. The player turns either bar off for them in Options > Mods (MGQ Online SP); a Raid World
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
  STRIP_BOX = :mgq_online_raid_bar

  # The strip's name while the player arranges the boxes.
  STRIP_BOX_NAME = "Raid boss bar"

  # The setting in Player.ini that keeps the battle's strip to its gauges alone.
  SMALL_SETTING = "raid_bar_small"

  # Where the game's own HP bar of a boss lies (Basic Enemy HP Bars Lite), which the strip pushes down.
  GAME_BOSS_BAR_Y = -12

  # The game's variable of the share of their own HP enemies have at the player's difficulty.
  DIFFICULTY_VARIABLE = 41

  # The steps of a gauge's value, so a gauge of any max fills smoothly.
  STEPS = 1000

  # A gauge's fill from its top down, a maroon gradient.
  FILL_COLORS = [:mgq_online_raid_top, :mgq_online_raid_middle, :mgq_online_raid_bottom]

  # How a gauge's HP reads with how much is left.
  LONG_TEXT = "%s  (%s)"

  # The settings in Player.ini that turn off the raid bosses' bars outside Raid Worlds with 0, on
  # the map and in battle.
  SHOWN_SETTINGS = { :map => "raid_bar_map", :battle => "raid_bar_battle" }

  # The keys of the Options > Mods rows that turn the bars outside Raid Worlds on and off, which
  # ui_single_player.rbx adds.
  OPTIONS = { :map => :mp_sp_raid_bar_map, :battle => :mp_sp_raid_bar_battle }

  # The names of the Options > Mods rows that turn the bars outside Raid Worlds on and off.
  OPTION_NAMES = { :map => "Raid Bar on Map", :battle => "Raid Bar in Battle" }

  # The help of the Options > Mods rows that turn the bars outside Raid Worlds on and off.
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

  # The strip's bar and the frame it was set, nil while it shows none.
  @strip = nil

  # The bar over each boss's event and the frame it was set, by the event.
  @overhead = {}

  # What renders each bar over an event anew, by the event, see overhead_shape.
  @overhead_shapes = {}

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
    @shown[where] = MGQ_Multiplayer::Player.setting(SHOWN_SETTINGS[where]) != false unless @shown.key?(where)
    @shown[where]
  end

  # Shows or hides a bar of the raid bosses outside Raid Worlds and keeps the choice in Player.ini.
  #
  # @param where [Symbol] :map or :battle.
  # @param shown [Boolean] Whether it shows.
  def self.show_bar(where, shown)
    @shown[where] = shown ? true : false
    MGQ_Multiplayer::Player.store(SHOWN_SETTINGS[where], @shown[where])
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

  # Notes where the battle's strip ends while it lies docked at the top of the screen, which the
  # game's own bar of a boss moves below.
  #
  # @param bottom [Integer, nil] The bottom of the strip, nil while it lies elsewhere, which leaves
  #   the game's bar where the game draws it.
  def self.battle_bottom=(bottom)
    @battle_bottom = bottom
  end

  # Reports whether the battle's strip shows its gauges alone, without the boss's title and the
  # names, as the player last chose.
  #
  # @return [Boolean] Whether it does.
  def self.small?
    @small = MGQ_Multiplayer::Player.setting(SMALL_SETTING) == true if @small.nil?
    @small
  end

  # Shows the battle's strip with or without the boss's title and the names on the party box's
  # hotkey (M unless the player binds another), keeping the choice in Player.ini. Called by the
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
    MGQ_Multiplayer::Player.store(SMALL_SETTING, @small)
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
  # shown_troops), looking anew every SCAN_FRAMES and on another map, and the stand-ins of the
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

    targets = MGQ_MpRaidFreezeUi.bar_targets
    shown = shown_troops(targets.map { |_standin, troop| troop })
    targets.select { |_standin, troop| shown.include?(troop) }
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
    shown = shown_troops(events.map { |event| troops_of(event) }.flatten.uniq)
    found = events.map do |event|
      troop = troops_of(event).find { |id| shown.include?(id) }
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

  # Lists the troops whose battles show a bar, as the DLL's rules tell in one call: in a Raid World
  # the last phase of a raid boss with pools the relay keeps, or whose milestone the story has not
  # beaten, outside the Hades rematches; outside one those that fight at their tier while raid
  # bosses are on.
  #
  # @param troops [Array<Integer>] The troops.
  # @return [Array<Integer>] Those that show one.
  def self.shown_troops(troops)
    return [] if troops.empty?

    raid = MGQ_MpRaidPool.active?
    active = !raid && defined?(MGQ_MpRaidTiers) && MGQ_MpRaidTiers.active?
    found = MGQ_MpRaidPool.troop_facts(troops, raid ? "pools" : "tiers", active)
    troops.select { |troop| found.fetch(troop.to_i, {})["shown"] }
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

  # Lists the tiles of the map's events that start a troop's battle, see boss_events.
  #
  # @param troop [Integer] The troop.
  # @return [Array<Array(Integer, Integer)>] Each event's x and y; none when the map has none.
  def self.boss_tiles(troop)
    boss_events.select { |_event, id| id == troop }.map { |event, _id| [event.x, event.y] }
  rescue => e
    log_once(:boss_tiles, "finding the boss's event failed: #{e.class}: #{e.message}")
    []
  end

  # The bars shown, as huds of the Mod Framework's UI layer: the strip's bar, the bar over each
  # boss's event or stand-in, and when each was last set, so the numbers that the HP the pool
  # gains back changes every frame are set at most every REDRAW_FRAMES.

  # Notes the strip's bar, or none, see settled.
  #
  # @param bar [Bar, nil] The bar.
  def self.strip_bar=(bar)
    @strip = settled(@strip, bar)
  end

  # Tells the strip's bar.
  #
  # @return [Bar, nil] The bar, nil while the strip shows none.
  def self.strip_bar
    @strip && @strip[0]
  end

  # Tells what renders the strip anew: the title, the enemies' names, whether it is the battle's
  # and whether it is small.
  #
  # @return [Array] Its shape, the same object while it stays.
  def self.strip_shape
    bar = strip_bar
    battle = SceneManager.scene.is_a?(Scene_Battle)
    shape = [bar ? bar.title : "", bar ? bar.gauges.map { |gauge| gauge.name } : [], battle, battle && small?]
    @strip_shape = shape unless @strip_shape == shape
    @strip_shape
  end

  # Reports whether the strip shows: it has a bar and the game's top message does not show.
  #
  # @return [Boolean] Whether it does.
  def self.strip_shown?
    !strip_bar.nil? && !top_message?
  end

  # Notes the bar over a boss's event, or none.
  #
  # @param event [Game_Event] The event.
  # @param bar [Bar, nil] The bar.
  def self.set_overhead(event, bar)
    @overhead[event] = settled(@overhead[event], bar)
  end

  # Tells the bar over a boss's event.
  #
  # @param event [Game_Event] The event.
  # @return [Bar, nil] The bar, nil for none.
  def self.overhead_bar(event)
    kept = @overhead[event]
    kept && kept[0]
  end

  # Tells what renders a bar over an event anew: its title and the enemies' names.
  #
  # @param event [Game_Event] The event.
  # @return [Array] Its shape, the same object while it stays.
  def self.overhead_shape(event)
    bar = overhead_bar(event)
    shape = [bar ? bar.title : "", bar ? bar.gauges.map { |gauge| gauge.name } : []]
    @overhead_shapes[event] = shape unless @overhead_shapes[event] == shape
    @overhead_shapes[event]
  end

  # Takes the place of a bar shown with a new one: at once for another boss or title, else at most
  # every REDRAW_FRAMES.
  #
  # @param kept [Array, nil] The bar shown and the frame it was set, nil for none.
  # @param bar [Bar, nil] The new bar.
  # @return [Array, nil] The bar to show and the frame it was set.
  def self.settled(kept, bar)
    return nil unless bar

    now = MGQ_Multiplayer::Bridge.frame_number
    shown = kept && kept[0]
    same = shown && shown.title == bar.title && shown.gauges.map { |gauge| gauge.name } == bar.gauges.map { |gauge| gauge.name }
    return kept if same && now - kept[1] < REDRAW_FRAMES && now >= kept[1]

    [bar, now]
  end

  # Tells how full a gauge of a bar is.
  #
  # @param bar [Bar, nil] The bar.
  # @param index [Integer] The gauge's place.
  # @return [Integer] The share in STEPS, 0 for no gauge.
  def self.fill(bar, index)
    gauge = bar && bar.gauges[index]
    return 0 unless gauge && gauge.max > 0

    ([[gauge.hp.to_f / gauge.max, 0.0].max, 1.0].min * STEPS).round
  end

  # Writes what a gauge of the strip says inside it, the longest text that fits first.
  #
  # @param index [Integer] The gauge's place.
  # @return [Array<String>] Its HP and share, its HP, its share.
  def self.gauge_texts(index)
    bar = strip_bar
    gauge = bar && bar.gauges[index]
    gauge ? [format(LONG_TEXT, gauge.numbers, gauge.percent), gauge.numbers, gauge.percent] : [""]
  end

  # Shows the battle's bar while the battle fights a boss's pools, reads the hotkey that makes it
  # small, and tells the game's own boss bar where the strip ends. Called by the battle every frame.
  def self.update_battle
    bar = battle_bar
    on_battle if bar
    self.strip_bar = bar
    self.battle_shown = strip_shown?
    room = UI.room(:top)
    self.battle_bottom = room > 0 ? room : nil
  rescue => e
    self.strip_bar = nil
    self.battle_shown = false
    log_once(:battle, "showing the battle's boss bar failed: #{e.class}: #{e.message}")
  end

  # Takes the battle's bar away as the battle's sprites go.
  def self.end_battle
    self.strip_bar = nil
    self.battle_shown = false
  end

  # Shows a bar over each boss's event that shows on the map, else the strip with the first boss's
  # bar. Called by the map's sprites every frame.
  #
  # @param sprites [Array<Sprite_Character>] The map's character sprites.
  # @param standins [Array<Sprite_Character>] The sprites of the bosses' stand-ins.
  def self.update_map(sprites, standins = [])
    pairs = boss_events
    shown = pairs.map do |event, troop|
      sprite = sprites.find { |candidate| candidate.character.equal?(event) }
      standin = sprite ? nil : standins.find { |candidate| candidate.character.equal?(event) }
      shows?(event, sprite || standin) ? [event, troop, standin || event] : nil
    end.compact
    update_overhead(shown)
    keep_strip
    self.strip_bar = shown.empty? && !pairs.empty? ? map_bar(pairs.first[1]) : nil
  rescue => e
    log_once(:map, "showing the boss bars failed: #{e.class}: #{e.message}")
  end

  # Shows a bar over each boss's event that shows, taking away those of events that no longer do.
  #
  # @param shown [Array<Array>] Each event with its troop and what its bar follows.
  def self.update_overhead(shown)
    events = shown.map { |event, _troop, _target| event }
    MGQ_MpShown.keys_of(:raid_overhead).each do |key|
      next if events.any? { |event| event.equal?(key[1]) }

      MGQ_MpShown.drop(key)
      @overhead.delete(key[1])
      @overhead_shapes.delete(key[1])
    end
    shown.each do |event, troop, target|
      set_overhead(event, map_bar(troop))
      MGQ_MpShown.keep([:raid_overhead, event], BossBar, event: event, target: target) if overhead_bar(event)
    end
  end

  # Takes every bar of the map away, with the map's sprites.
  def self.end_map
    MGQ_MpShown.keys_of(:raid_overhead).each { |key| MGQ_MpShown.drop(key) }
    @overhead.clear
    @overhead_shapes.clear
    self.strip_bar = nil unless SceneManager.scene.is_a?(Scene_Battle)
  end

  # Shows the strip as a map or a battle first shows, and again once F12 took it away.
  def self.keep_strip
    MGQ_MpShown.keep(RaidStrip::ID, RaidStrip)
  end

  # The strip across the top of the screen, one place for the map's and the battle's: the boss's
  # title and, for each of its enemies, its name over a gauge with its HP and how much is left
  # inside, the gauges sharing GAUGE_SHARE of the screen's width. In battle the hint at the right
  # of the title names the hotkey that makes it small, which a click does too; small it shows the
  # gauges alone, the title and the names giving way as its height eases down.
  class RaidStrip < UI::Component
    # The strip's place id, which names its place in the Mod Framework's settings.
    ID = STRIP_BOX

    # Share of the screen's width the strip's names and gauges take.
    GAUGE_SHARE = 0.65

    # The narrowest the strip gets: the gauges of a boss of three enemies still showing how much
    # is left.
    MIN_WIDTH = 320

    # Height of a gauge.
    GAUGE_HEIGHT = 30

    # What the battle's strip says at the right of its title, with the hotkey that makes it small.
    BARS_HINT = "%s: bars"

    # Renders it anew for another boss, title or size.
    watch { MGQ_MpRaidBar.strip_shape }

    # Describes the strip.
    def render
      title, names, battle, small = MGQ_MpRaidBar.strip_shape
      width = (Graphics.width * GAUGE_SHARE).round
      hud id: ID, place_name: STRIP_BOX_NAME, dock: :top, shown_in: [Scene_Map, Scene_Battle], resizable: :width, frame: false,
          min_size: [MIN_WIDTH, SMALL_STRIP_HEIGHT], hide_while: -> { !MGQ_MpRaidBar.strip_shown? } do
        stack tail: true, spacing: 0, height: (small ? SMALL_STRIP_HEIGHT : STRIP_HEIGHT) do
          stack row: true do
            text title, typo: :subtitle1, color: :title, plate: true, align: :center, grow: 1
            if battle
              button format(BARS_HINT, MGQ_MpHotkeys.label(:party_box)), variant: :text, color: :dim, on_click: -> { MGQ_MpRaidBar.toggle_small }
            end
          end
          stack row: true, spacing: 1.5, width: width, align_self: :center do
            names.each_with_index { |name, index| text name, plate: true, min_font_size: 14, align: :center, grow: 1, key: index }
          end
          stack row: true, spacing: 1.5, width: width, align_self: :center do
            names.each_index do |index|
              progress value: -> { MGQ_MpRaidBar.fill(MGQ_MpRaidBar.strip_bar, index) }, max: STEPS, colors: FILL_COLORS, vertical: true, border: :theme, border_width: 2,
                       trail: true, height: GAUGE_HEIGHT, text: -> { MGQ_MpRaidBar.gauge_texts(index) }, grow: 1, key: index
            end
          end
        end
      end
    end
  end

  # The bar over a boss's event or its stand-in on the map: its title, the enemies' names and thin
  # gauges without numbers, 240 wide, 480 for a boss of several enemies, under the boss's feet
  # where the screen has no room over its head.
  class BossBar < UI::Component
    # The boss's event, whose bar it shows.
    param :event

    # What it follows: the event, or the stand-in's sprite of a frozen fight.
    param :target

    # Width of the bar for a boss of one enemy.
    WIDTH = 240

    # Width of the bar for a boss of several enemies, so their names still read.
    WIDE_WIDTH = 480

    # Height of a gauge.
    GAUGE_HEIGHT = 8

    # Renders it anew for another boss or title.
    watch { MGQ_MpRaidBar.overhead_shape(event) }

    # Describes the bar.
    def render
      title, names = MGQ_MpRaidBar.overhead_shape(event)
      hud follow: target, side: :top, flip: true, movable: false, mouse: :none, frame: false, width: names.size > 1 ? WIDE_WIDTH : WIDTH do
        text title, typo: :body2, color: :title, plate: true, align: :center
        stack row: true, spacing: 1.5 do
          names.each_with_index { |name, index| text name, typo: :caption, plate: true, min_font_size: 14, align: :center, grow: 1, key: index }
        end
        stack row: true, spacing: 1.5 do
          names.each_index do |index|
            progress value: -> { MGQ_MpRaidBar.fill(MGQ_MpRaidBar.overhead_bar(event), index) }, max: STEPS, colors: FILL_COLORS, vertical: true,
                     border: :theme, border_width: 2, trail: true, height: GAUGE_HEIGHT, grow: 1, key: index
          end
        end
      end
    end
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After the battle's sprites, the strip of a battle that fights a boss's pools.
  MGQ_MpHooks.after(Spriteset_Battle, :update, "ui_raid_bar") do
    MGQ_MpRaidBar.keep_strip
    MGQ_MpRaidBar.update_battle
  end

  MGQ_MpHooks.before(Spriteset_Battle, :dispose, "ui_raid_bar") { MGQ_MpRaidBar.end_battle }

  # After the map's sprites, the bosses' bars, also over the stand-ins of frozen fights, never on
  # the map behind a menu.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_raid_bar") do
    next unless mgq_mp_hud?

    standins = defined?(MGQ_MpRaidFreezeUi) ? MGQ_MpRaidFreezeUi.sprites_of(self) : []
    MGQ_MpRaidBar.update_map(MGQ_MpGame.get(self, :character_sprites), standins)
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_raid_bar") { MGQ_MpRaidBar.end_map if mgq_mp_hud? }

  # The game's own HP bar of a boss moves below the battle's strip, as the game draws it.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "ui_raid_bar") do
    if Sprite_Battler.method_defined?(:update_hp_bar)
      MGQ_MpHooks.after(Sprite_Battler, :update_hp_bar, "ui_raid_bar") { MGQ_MpRaidBar.push_down(self) }
    end
  end
rescue => e
  MGQ_MpRaidBar.log("hooks FAILED: #{e.class}: #{e.message}")
end
