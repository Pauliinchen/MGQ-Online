#----------------------------------------------------------------
#  ui_raid_bar.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Kept the troops of a common event only when its walk missed none, so a cycle or a common event called twice no longer hides troops for the session
#                            - Logged a refused hotkey through MGQ_MpHotkeys.log_refusal, not while the player types
#                            - Read the map's viewports and character sprites through MGQ_MpGame
#      Paulinchen  2026-10-11: Drew the gauges' edge, empty part and the title in the interface preset's colors, drawing anew once the preset changes
#                            - Made the strip a box the player moves and resizes in width with Alt, never narrower than a boss of three enemies and its title line need
#                            - Cropped the battle's strip to its gauges in small mode instead of sliding it up, so it stays where the player put it
#                            - Made room at the top for the strip and pushed the game's own boss bar down only while the strip lies at the top of the screen
#                            - Took the font, the outline and the plate from the shared style instead of copies of them, with the style's outline, plate and slide timing, and the slide's step from the motion
#                            - Named the hotkey that makes the battle's strip small at the right of its title, and kept the title out of its room
#      Paulinchen  2026-10-10: Showed a boss of several enemies with a name and a gauge per enemy, sharing the gauge's width
#                            - Kept a shortened HP from reading above the max
#                            - Showed no bars in the Hades rematch hall
#                            - Created
#
#----------------------------------------------------------------

# The HP bars of a Raid World's bosses (see battles_raid_pool.rbx): in a battle that fights a boss's
# pools, a strip across the top of the screen with the boss's title and, for each of its enemies, its
# name over a gauge with its HP and how much is left inside (Sprite_MpRaidBar); on the map, a bar
# above each event that starts a boss battle, or the same strip at the top of the screen while no
# such event shows, which the notification and party boxes then make room for (see
# MGQ_MpUi.top_room). The player moves the strip and resizes it in width with Alt (see
# MGQ_MpUi::Layout), one place for the map's and the battle's. A bar shows while the relay keeps the boss's pool, or the story has not beaten
# it; the relay's max HP once it told one, else the boss's own at the player's difficulty.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpRaidBar
  # Fewest digits a bar's max HP keeps once its numbers are shortened, see short_numbers.
  MIN_DIGITS = 7

  # The units a bar's numbers are shortened by, each a thousand times the one before.
  UNITS = ["", "K", "M", "B", "T", "Qa", "Qi"]

  # Frames between two drawings of a bar whose numbers changed, since the HP the pool gains back
  # changes them every frame.
  REDRAW_FRAMES = 6

  # Frames between two looks at the map's events for the bosses' battles.
  SCAN_FRAMES = 30

  # Height of the strip across the top of the screen: its title, the names and the gauges, see
  # Sprite_MpRaidBar::STRIP_LAYOUT.
  STRIP_HEIGHT = 86

  # Height of the battle's strip that shows while it shows its gauges alone, see small?: the strip
  # is cropped from its top by the rest, its title and the names.
  SMALL_STRIP_HEIGHT = 36

  # The strip's box in MGQ_MpUi::Layout and its name there.
  STRIP_BOX = :raid_bar
  STRIP_BOX_NAME = "Raid boss bar"

  # Pixels from the screen's top within which the strip counts as lying at the top, where the boxes
  # there make room for it and the game's own boss bar moves below it.
  TOP_REACH = 4

  # The setting in Player.ini that keeps the battle's strip to its gauges alone.
  SMALL_SETTING = "raid_bar_small"

  # Depth of the strip in battle: under the game's windows, which start at 100 and so cover it while
  # they show, and over the battlers and pictures.
  BATTLE_Z = 90

  # Where the game's own HP bar of a boss lies (Basic Enemy HP Bars Lite), which the strip pushes down.
  GAME_BOSS_BAR_Y = -12

  # The event command that starts a battle.
  BATTLE_CODE = 301

  # The battle command's designation of its troop by id, rather than by a variable or at random.
  DIRECT_TROOP = 0

  # The game's variable of the share of their own HP enemies have at the player's difficulty.
  DIFFICULTY_VARIABLE = 41

  # The event command that calls a common event.
  CALL_CODE = 117

  # Steps to a boss's event when the map shows none.
  FAR = 9999

  # A bar's content.
  #
  # @!attribute title [String, nil] What shows above the names, see MGQ_MpRaidBosses.title.
  # @!attribute gauges [Array<Gauge>] One gauge per enemy of the boss, in the troop's order.
  Bar = Struct.new(:title, :gauges)

  # One enemy's gauge of a bar.
  #
  # @!attribute name [String] The enemy's name, lettered as the game letters repeated names.
  # @!attribute hp [Integer] Its HP.
  # @!attribute max [Integer] Its max HP.
  Gauge = Struct.new(:name, :hp, :max)

  @scanned = nil
  @event_troops = {}
  @common_troops = {}
  @base_hp = {}
  @battle_shown = false

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "raid bar"

  # Finds the bar of the battle running when it fights a boss's pools: a gauge per own enemy with
  # its HP as the battle has it, against its pool's max HP once the relay told it.
  #
  # @return [Bar, nil] The bar, nil for none.
  def self.battle_bar
    fight = MGQ_MpRaidPool.fight
    return nil unless fight

    gauges = fight.members.map do |member|
      enemy = $game_troop.members[member.index]
      next nil unless enemy

      local = enemy.mhp.to_i
      next nil unless local > 0

      pool = MGQ_MpRaidPool.pool(member.key)
      shown = pool && pool.max.to_i > 0 ? pool.max.to_i : local
      Gauge.new(enemy.name.to_s, MGQ_MpRaidPool.hp_of(enemy.dead? ? 0.0 : enemy.hp.to_f / local, shown), shown)
    end.compact
    gauges.empty? ? nil : Bar.new(MGQ_MpRaidBosses.title(fight.troop), gauges)
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
  # @param bottom [Integer, nil] The bottom of what shows of the strip, nil while the strip lies
  #   elsewhere, which leaves the game's bar where the game draws it.
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
  # battle every frame while its strip shows, so a press of the key is seen once.
  def self.on_battle
    return unless defined?(MGQ_MpHotkeys) && MGQ_MpHotkeys.pressed?(:party_box)
    return MGQ_MpHotkeys.log_refusal(:party_box, "the chat box is open") if defined?(MGQ_MpChat) && MGQ_MpChat.typing?

    @small = !small?
    MGQ_Multiplayer::Player.store(SMALL_SETTING, @small ? 1 : 0)
    log("the battle's boss bar shows #{@small ? 'its gauges alone' : 'the title and the names again'}")
    Sound.play_cursor
  rescue => e
    log_once(:on_battle, "changing the battle's boss bar failed: #{e.class}: #{e.message}")
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
  # shown_troop?), looking anew every SCAN_FRAMES and on another map.
  #
  # @return [Array<Array>] Each event with its troop.
  def self.boss_events
    return [] unless $game_map && MGQ_MpRaidPool.active?

    stamp = [$game_map.map_id, Graphics.frame_count / SCAN_FRAMES]
    return @scanned[1] if @scanned && @scanned[0] == stamp

    @event_troops = {} unless @scanned && @scanned[0][0] == stamp[0]

    found = $game_map.events.values.map do |event|
      troop = troops_of(event).find { |id| shown_troop?(id) }
      troop ? [event, troop] : nil
    end.compact
    @scanned = [stamp, found]
    found
  end

  # Lists the troops whose battles an event's page starts, through common events too, kept until
  # its page changes.
  #
  # @param event [Game_Event] The event.
  # @return [Array<Integer>] The troops, in their order; none for an erased event.
  def self.troops_of(event)
    list = event.list
    return [] unless list

    kept = @event_troops[event]
    return kept[1] if kept && kept[0].equal?(list)

    troops = troops_in(list, {})
    @event_troops[event] = [list, troops]
    troops
  end

  # Lists the troops whose battles a list of event commands starts, directly or in the common
  # events it calls.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param seen [Hash] The common events looked at already, by id, which a call back to one skips.
  # @return [Array<Integer>] The troops.
  def self.troops_in(list, seen)
    list.each_with_object([]) do |command, troops|
      params = command.parameters
      if command.code == BATTLE_CODE && params[0] == DIRECT_TROOP
        troops << params[1].to_i
      elsif command.code == CALL_CODE
        troops.concat(common_troops(params[0].to_i, seen))
      end
    end.uniq
  end

  # Lists the troops whose battles a common event starts, kept since the database never changes.
  #
  # A walk that skipped a common event looked at but not kept yet lacks that event's troops, so
  # only a list that skipped none is kept, or the walk's first, which gathers them all.
  #
  # @param id [Integer] The common event.
  # @param seen [Hash] See troops_in; its :cut entry marks a walk that skipped such an event.
  # @return [Array<Integer>] The troops.
  def self.common_troops(id, seen)
    return @common_troops[id] if @common_troops.key?(id)
    if seen[id]
      seen[:cut] = true
      return []
    end

    root = seen.empty?
    outer = seen.delete(:cut)
    seen[id] = true
    common = $data_common_events[id]
    troops = common && common.list ? troops_in(common.list, seen) : []
    @common_troops[id] = troops if root || !seen[:cut]
    seen[:cut] = true if outer
    troops
  end

  # Reports whether a troop's battle shows a bar: the last phase of a raid boss with pools whose
  # relay keeps a pool of it, or whose milestone the story has not beaten, outside the Hades
  # rematches, which fight no pool.
  #
  # @param troop [Integer] The troop.
  # @return [Boolean] Whether it does.
  def self.shown_troop?(troop)
    pool = MGQ_MpRaidPool
    return false unless MGQ_MpRaidBosses.last_phase?(troop) && !pool::UNPOOLED[troop] && !pool.hades?

    keys = pool.troop_keys(troop)
    return false if keys.empty?

    pool.pooled_troop?(troop) || keys.any? { |key| pool.pool(key) }
  end

  # Finds a troop's bar on the map: a gauge per pool of the troop with its HP now, the HP the pool
  # gained back since included, the enemy's own max HP for a pool the relay told nothing of.
  #
  # @param troop [Integer] The troop.
  # @return [Bar] The bar.
  def self.map_bar(troop)
    pool = MGQ_MpRaidPool
    enemies = troop_enemies(troop)
    names = map_names(enemies)
    now = Time.now
    gauges = pool.troop_keys(troop).each_with_index.map do |key, index|
      known = pool.pool(key)
      if known && known.max.to_i > 0
        max = known.max.to_i
        hp = pool.hp_of(pool.left_now(known, now), max)
      else
        max = raid_max(enemies[index], troop)
        hp = known ? pool.hp_of(pool.left_now(known, now), max) : max
      end
      Gauge.new(names[index].to_s, hp, max)
    end
    Bar.new(MGQ_MpRaidBosses.title(troop), gauges)
  end

  # Names a troop's enemies for the map's bar, by the database, a name that repeats within the troop
  # lettered as the game letters it in battle.
  #
  # @param enemy_ids [Array<Integer>] The enemies.
  # @return [Array<String>] Their names, such as "Metatronne A" and "Metatronne B".
  def self.map_names(enemy_ids)
    names = enemy_ids.map { |id| $data_enemies[id].name.to_s }
    counts = names.each_with_object(Hash.new(0)) { |name, seen| seen[name] += 1 }
    lettered = Hash.new(0)
    names.map do |name|
      next name if counts[name] < 2

      letter = letter(lettered[name])
      lettered[name] += 1
      name + letter
    end
  end

  # Finds the letter the game appends to the nth enemy of a repeated name.
  #
  # @param n [Integer] The enemy's number among those of its name, from 0.
  # @return [String] Such as " A".
  def self.letter(n)
    table = $game_troop && $game_troop.respond_to?(:letter_table) ? $game_troop.letter_table : nil
    table && !table.empty? ? table[n % table.size].to_s : " #{(65 + n % 26).chr}"
  end

  # Lists the enemies a troop's setup makes, by the database.
  #
  # @param troop [Integer] The troop.
  # @return [Array<Integer>] Their ids.
  def self.troop_enemies(troop)
    data = $data_troops && $data_troops[troop]
    data ? data.members.map { |member| member.enemy_id }.select { |id| $data_enemies[id] } : []
  end

  # Finds the max HP an enemy has in a battle that fights its pool: its own at the player's
  # difficulty, kept while the difficulty stays, times the factor of its boss's tier.
  #
  # @param enemy_id [Integer, nil] The enemy.
  # @param troop [Integer] The boss's troop.
  # @return [Integer] The max HP, 0 for none.
  def self.raid_max(enemy_id, troop)
    return 0 unless enemy_id

    key = [enemy_id, $game_variables[DIFFICULTY_VARIABLE]]
    @base_hp[key] ||= own_max(enemy_id)
    (@base_hp[key] * MGQ_MpRaidBosses.factor(troop, :mhp)).round
  end

  # Writes a gauge's HP and max HP, both in the largest unit of UNITS that leaves the max at least
  # MIN_DIGITS digits, such as "236,167 B / 1,009,500 B".
  #
  # The HP rounds up, so a boss with any HP left never reads 0, but never past the max, which
  # rounds down.
  #
  # @param hp [Integer] The HP.
  # @param max [Integer] The max HP.
  # @return [String] The numbers.
  def self.short_numbers(hp, max)
    power = 0
    power += 1 while power + 1 < UNITS.size && max.to_i / 1000**(power + 1) >= 10**(MIN_DIGITS - 1)
    unit = 1000**power
    suffix = power > 0 ? " #{UNITS[power]}" : ""
    shown_max = max.to_i / unit
    shown_hp = [(hp.to_i + unit - 1) / unit, shown_max].min
    "#{MGQ_MpUi.grouped(shown_hp)}#{suffix} / #{MGQ_MpUi.grouped(shown_max)}#{suffix}"
  end

  # Finds an enemy's own max HP at the player's difficulty, as the game computes it in battle, or
  # its database value when that fails.
  #
  # @param enemy_id [Integer] The enemy.
  # @return [Integer] The max HP.
  def self.own_max(enemy_id)
    Game_Enemy.new(0, enemy_id).mhp.to_i
  rescue => e
    log_once([:own_max, enemy_id], "computing the max HP of enemy #{enemy_id} failed (#{e.class}: #{e.message}), its database value stands in")
    $data_enemies[enemy_id].params[0].to_i
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

  # The bars on the map: one above each boss's event that shows, else the strip at the top.
  class MapBars
    # Creates the bars, none shown.
    #
    # @param characters [Viewport] The map's viewport of characters.
    # @param top [Viewport] The map's topmost viewport.
    def initialize(characters, top)
      @characters = characters
      @top = top
      @overhead = {}
      @strip = nil
    end

    # Shows a bar above each boss's event that shows on the map, else the strip with the first
    # boss's bar, and tells the boxes at the top the room the strip takes while it lies there.
    #
    # @param sprites [Array<Sprite_Character>] The map's character sprites.
    def update(sprites)
      pairs = MGQ_MpRaidBar.boss_events
      shown = pairs.map do |event, troop|
        sprite = sprites.find { |candidate| candidate.character.equal?(event) }
        MGQ_MpRaidBar.shows?(event, sprite) ? [event, troop, sprite] : nil
      end.compact
      update_overhead(shown)
      rect = update_strip(shown.empty? && !pairs.empty? ? pairs.first[1] : nil)
      MGQ_MpUi.top_room = rect && MGQ_MpRaidBar.at_top?(rect) ? rect.y + STRIP_HEIGHT : 0
    rescue => e
      MGQ_MpUi.top_room = 0
      MGQ_MpRaidBar.log_once(:map, "drawing the boss bars failed: #{e.class}: #{e.message}")
    end

    # Shows a bar above each boss's event that shows, freeing those of events that no longer do.
    #
    # @param shown [Array<Array>] Each event with its troop and sprite.
    def update_overhead(shown)
      events = shown.map { |event, _troop, _sprite| event }
      @overhead.keys.reject { |event| events.any? { |kept| kept.equal?(event) } }.each { |event| @overhead.delete(event).dispose }
      shown.each do |event, troop, sprite|
        bar = (@overhead[event] ||= Sprite_MpRaidBar.new(@characters, true))
        bar.show(MGQ_MpRaidBar.map_bar(troop))
        bar.place_over(sprite)
      end
    end

    # Shows the strip with a troop's bar where the player put it, or hides it.
    #
    # @param troop [Integer, nil] The troop, nil to hide it.
    # @return [Rect, nil] Where the strip lies, nil while it is hidden.
    def update_strip(troop)
      unless troop
        @strip.visible = false if @strip
        return nil
      end

      @strip ||= Sprite_MpRaidBar.new(@top, false)
      @strip.z = MGQ_MpUi::Z[:labels]
      rect = @strip.place_strip
      @strip.show(MGQ_MpRaidBar.map_bar(troop))
      MGQ_MpUi::Layout.offer(STRIP_BOX, rect.x, rect.y, rect.width, STRIP_HEIGHT, @strip.z)
      rect
    end

    # Frees every bar.
    def dispose
      @overhead.each_value { |bar| bar.dispose }
      @overhead.clear
      @strip.dispose if @strip
      @strip = nil
    end
  end
end

# A raid boss's HP bar: its title and, below it, each enemy's name over a big gauge with the HP
# inside, a boss of several enemies sharing the gauge's width among them, centered, as the strip
# across the top of the screen or the smaller bar above its event on the map.
class Sprite_MpRaidBar < Sprite
  # The sizes of a bar's parts: the fonts of its title and names, the gauges' height and the font of
  # the numbers inside the gauges, 0 for gauges without numbers.
  Layout = Struct.new(:title, :name, :gauge, :numbers)

  # The damage trail of one gauge, see follow_trail.
  #
  # @!attribute shown [Float] The share of the max HP the trail reaches now.
  # @!attribute left [Float] The share left when the gauge was last followed.
  # @!attribute history [Array<Array>] Each change of the share left, with its frame and the share
  #   before it.
  Trail = Struct.new(:shown, :left, :history)

  # The strip's parts, which take MGQ_MpRaidBar::STRIP_HEIGHT.
  STRIP_LAYOUT = Layout.new(20, 24, 30, 21)

  # The parts of the bar above an event, which take OVERHEAD_HEIGHT: thin gauges without numbers.
  OVERHEAD_LAYOUT = Layout.new(16, 18, 8, 0)

  # Room above the strip's title.
  STRIP_TOP = 2

  # Pixels a line of text takes beyond its font's size.
  LINE_EXTRA = 4

  # Width of the bar above an event, for a boss of one enemy.
  OVERHEAD_WIDTH = 240

  # Width of the bar above an event for a boss of several enemies, so their names still read.
  OVERHEAD_WIDE_WIDTH = 480

  # Height of the bar above an event.
  OVERHEAD_HEIGHT = 52

  # Share of the screen's width the strip's row of gauges takes, at most the strip's width less
  # STRIP_MARGIN and the gauges' frames on each side, see strip_row_width.
  STRIP_GAUGE_SHARE = 0.65

  # Pixels the strip's row of gauges keeps from the strip's sides beyond the gauges' frames.
  STRIP_MARGIN = 4

  # Most enemies a boss has, whose gauges the narrowest strip still shows, see min_strip_width.
  MAX_GAUGES = 3

  # The longest texts a gauge shows how much is left with, see percent, which the narrowest strip's
  # gauges still fit.
  PERCENT_SAMPLES = ["100.0%", "<0.1%"]

  # Pixels between the gauges of a boss of several enemies.
  GAUGE_GAP = 6

  # Smallest font size the names of a boss of several enemies shrink to, so each fits its gauge.
  MIN_NAME_SIZE = 14

  # Pixels the gauge's frame takes on each side.
  FRAME_WIDTH = 2

  # Pixels between the top of an event's sprite and its bar.
  GAP = 4

  # The thin edge inside the gauge's outer frame, which is the style's outline: the preset's edge.
  EDGE = MGQ_MpUi::Style::EDGE

  # The gauge's empty part: the preset's well.
  EMPTY = MGQ_MpUi::Style::WELL

  # The filled part: a maroon gradient, lighter at its top, deep at its bottom.
  FILL_TOP = Color.new(156, 32, 50)
  FILL_MIDDLE = Color.new(110, 16, 30)
  FILL_BOTTOM = Color.new(70, 8, 18)

  # The damage trail past the filled part: the HP the enemy had within the last TRAIL_FRAMES, in a
  # maroon between the filled and the empty part's.
  TRAIL_TOP = Color.new(96, 28, 40)
  TRAIL_BOTTOM = Color.new(50, 12, 18)

  # Frames a loss of HP stays in the damage trail, two seconds.
  TRAIL_FRAMES = 120

  # Share of the trail's way down to the HP left it drains each frame, and the least it drains.
  TRAIL_EASE = 0.12
  TRAIL_MIN_STEP = 0.002

  # Frames between two drawings while a damage trail drains.
  TRAIL_REDRAW_FRAMES = 2

  # The title's color: the preset's title.
  TITLE_COLOR = MGQ_MpUi::Style::TITLE

  # Room the numbers and the names keep from the gauge's ends.
  NUMBERS_MARGIN = 4

  # What the battle's strip says at the right of its title, with the hotkey that makes it small.
  BARS_HINT = "%s: bars"

  # Creates the bar, hidden.
  #
  # @param viewport [Viewport, nil] Its viewport: the map's characters' for a bar above an event,
  #   nil in battle.
  # @param overhead [Boolean] Whether it is the bar above an event, else the strip.
  def initialize(viewport, overhead)
    super(viewport)
    @overhead = overhead
    width = overhead ? OVERHEAD_WIDTH : Graphics.width
    self.bitmap = Bitmap.new(width, overhead ? OVERHEAD_HEIGHT : MGQ_MpRaidBar::STRIP_HEIGHT)
    self.ox = overhead ? width / 2 : 0
    self.z = overhead ? MGQ_MpUi::Z[:labels] : MGQ_MpRaidBar::BATTLE_Z
    self.visible = false
    @drawn = nil
    @drawn_at = nil
    @trails = nil
    @trail_names = nil
  end

  # Shows a bar, drawing it again when its numbers changed, at most every
  # MGQ_MpRaidBar::REDRAW_FRAMES.
  #
  # @param bar [MGQ_MpRaidBar::Bar, nil] The bar, nil to hide it.
  def show(bar)
    self.visible = !bar.nil?
    return unless bar

    fit(bar) if @overhead
    now = Graphics.frame_count
    follow_trails(bar, now)
    content = [bar.title, bar.gauges.map { |gauge| gauge.to_a }, @trails.map { |trail| trail.shown }, MGQ_MpUi::Theme.serial]
    return if content == @drawn
    # Numbers wait a few frames, a draining trail only two, so it moves smoothly.
    if @drawn && @drawn[1].map { |gauge| gauge[0] } == @trail_names
      wait = @drawn[2] == content[2] ? MGQ_MpRaidBar::REDRAW_FRAMES : TRAIL_REDRAW_FRAMES
      return if now - @drawn_at < wait
    end

    @drawn = content
    @drawn_at = now
    @overhead ? draw_bar(bar, OVERHEAD_LAYOUT, 0, bitmap.width - FRAME_WIDTH * 2) : draw_bar(bar, STRIP_LAYOUT, STRIP_TOP, strip_row_width)
  end

  # Finds the width of the strip's row of gauges: STRIP_GAUGE_SHARE of the screen's width, as the
  # strip across the whole screen has it, but never past STRIP_MARGIN and the gauges' frames from a
  # narrower strip's sides.
  #
  # @return [Integer] The width, inside the gauges' frames.
  def strip_row_width
    [(Graphics.width * STRIP_GAUGE_SHARE).round, bitmap.width - (FRAME_WIDTH + STRIP_MARGIN) * 2].min
  end

  # Finds the narrowest the strip gets while it still shows all it has: its title line with the
  # hint at either side of the longest title, and the gauges of a boss of MAX_GAUGES enemies, each
  # still showing how much is left; the names shrink and are cut, as on the whole screen.
  #
  # The hint is measured with the hotkey's name as the script loads.
  #
  # @return [Integer] The width, the screen's when measuring fails.
  def self.min_strip_width
    bitmap = Bitmap.new(1, 1)
    style = MGQ_MpUi::Style
    style.use_font(bitmap, style::TINY_SIZE, style::DIM)
    hint_room = bitmap.text_size(BARS_HINT % MGQ_MpHotkeys.label(:party_box)).width + NUMBERS_MARGIN
    style.use_font(bitmap, STRIP_LAYOUT.title, TITLE_COLOR)
    title = strip_titles.map { |text| bitmap.text_size(text).width }.max
    style.use_font(bitmap, STRIP_LAYOUT.numbers, style::TEXT)
    gauge = PERCENT_SAMPLES.map { |text| bitmap.text_size(text).width }.max + NUMBERS_MARGIN * 2
    row = gauge * MAX_GAUGES + GAUGE_GAP * (MAX_GAUGES - 1) + (FRAME_WIDTH + STRIP_MARGIN) * 2
    [hint_room * 2 + title + NUMBERS_MARGIN * 2, row].max
  rescue => e
    MGQ_MpRaidBar.log("measuring the narrowest strip FAILED (#{e.class}: #{e.message}), it keeps the screen's width")
    Graphics.width
  ensure
    bitmap.dispose if bitmap
  end

  # Lists the titles a strip shows: those of MGQ_MpRaidBosses::TITLES and one per tier, as
  # MGQ_MpRaidBosses.title names a boss without one of them.
  #
  # @return [Array<String>] The titles.
  def self.strip_titles
    MGQ_MpRaidBosses::TITLES.keys + MGQ_MpRaidBosses::TIERS.keys.map { |tier| "Tier #{tier} Raid Boss" }
  end

  # Puts the strip where the player left it (see MGQ_MpUi::Layout), across the top of the screen
  # until they move it, remaking its picture once its width changes.
  #
  # @return [Rect] Where it lies, MGQ_MpRaidBar::STRIP_HEIGHT high.
  def place_strip
    height = MGQ_MpRaidBar::STRIP_HEIGHT
    rect = MGQ_MpUi::Layout.rect(MGQ_MpRaidBar::STRIP_BOX, Rect.new(0, 0, Graphics.width, height))
    if bitmap.width != rect.width
      bitmap.dispose
      self.bitmap = Bitmap.new(rect.width, height)
      @drawn = nil
    end
    self.x = rect.x
    self.y = rect.y
    rect
  end

  # Gives the bar above an event the width its bar needs, OVERHEAD_WIDE_WIDTH for a boss of several
  # enemies, remaking its picture when that differs.
  #
  # @param bar [MGQ_MpRaidBar::Bar] The bar.
  def fit(bar)
    width = bar.gauges.size > 1 ? OVERHEAD_WIDE_WIDTH : OVERHEAD_WIDTH
    return if bitmap.width == width

    bitmap.dispose
    self.bitmap = Bitmap.new(width, OVERHEAD_HEIGHT)
    self.ox = width / 2
    @drawn = nil
  end

  # Follows the damage trail of each gauge, see follow_trail. A bar of other names starts every
  # trail anew.
  #
  # @param bar [MGQ_MpRaidBar::Bar] The bar.
  # @param now [Integer] The frame.
  def follow_trails(bar, now)
    names = bar.gauges.map { |gauge| gauge.name }
    if @trails.nil? || @trail_names != names
      @trail_names = names
      @trails = bar.gauges.map { |gauge| Trail.new(share(gauge), share(gauge), []) }
      return
    end

    bar.gauges.each_with_index { |gauge, index| follow_trail(@trails[index], share(gauge), now) }
  end

  # Follows a gauge's damage trail: the most of the max HP the enemy had within the last
  # TRAIL_FRAMES, which the trail drains down to by TRAIL_EASE a frame, and rises to at once.
  #
  # @param trail [Trail] The trail.
  # @param left [Float] The share of the max HP left now.
  # @param now [Integer] The frame.
  def follow_trail(trail, left, now)
    # Each change notes until when the enemy had the HP before it.
    trail.history << [now, trail.left] if left != trail.left
    trail.left = left
    trail.history.reject! { |frame, _share| now - frame > TRAIL_FRAMES }
    target = ([left] + trail.history.map { |_frame, share| share }).max
    return trail.shown = target if target >= trail.shown

    trail.shown = [trail.shown - [(trail.shown - target) * TRAIL_EASE, TRAIL_MIN_STEP].max, target].max
  end

  # Shows the battle's bar where the player put the strip while the battle fights a boss's pools
  # and the game's top message does not show.
  def update_battle
    bar = MGQ_MpRaidBar.top_message? ? nil : MGQ_MpRaidBar.battle_bar
    MGQ_MpRaidBar.on_battle if bar
    rect = place_strip
    shown_height = crop(MGQ_MpRaidBar.small?)
    show(bar)
    MGQ_MpUi::Layout.offer(MGQ_MpRaidBar::STRIP_BOX, rect.x, rect.y, rect.width, shown_height, z) if bar
    MGQ_MpRaidBar.battle_shown = !bar.nil?
    MGQ_MpRaidBar.battle_bottom = MGQ_MpRaidBar.at_top?(rect) ? rect.y + shown_height : nil
  rescue => e
    self.visible = false
    MGQ_MpRaidBar.battle_shown = false
    MGQ_MpRaidBar.log_once(:battle, "drawing the battle's boss bar failed: #{e.class}: #{e.message}")
  end

  # Crops the battle's strip from its top a step of MGQ_MpUi::Style::SLIDE_FRAMES towards its size:
  # until only its gauges show, or back to in full. A new strip starts at its size, without
  # cropping step by step.
  #
  # The strip keeps its own crop instead of MGQ_MpUi::Motion, since its showing and hiding follow
  # the game's top message at once and the game's own boss bar follows its bottom.
  #
  # @param small [Boolean] Whether only its gauges show.
  # @return [Integer] The height of what shows.
  def crop(small)
    height = MGQ_MpRaidBar::STRIP_HEIGHT
    room = height - MGQ_MpRaidBar::SMALL_STRIP_HEIGHT
    target = small ? room : 0
    @crop = target.to_f if @crop.nil?
    @crop = MGQ_MpUi::Motion.step_towards(@crop, target.to_f, room.to_f / MGQ_MpUi::Style::SLIDE_FRAMES)
    cut = @crop.round
    src_rect.set(0, cut, bitmap.width, height - cut)
    height - cut
  end

  # Puts the bar above an event's sprite, or under its feet when the screen has no room above.
  #
  # @param sprite [Sprite_Character] The event's sprite.
  def place_over(sprite)
    self.x = sprite.x
    above = sprite.y - sprite.height - OVERHEAD_HEIGHT - GAP
    self.y = above < 0 ? sprite.y + 2 : above
  end

  # Finds the share of a gauge's max HP left.
  #
  # @param gauge [MGQ_MpRaidBar::Gauge] The gauge.
  # @return [Float] The share, 0 to 1.
  def share(gauge)
    gauge.max > 0 ? [[gauge.hp.to_f / gauge.max, 0.0].max, 1.0].min : 0.0
  end

  # Writes a gauge's HP, such as "3,412,880 / 5,000,000", see MGQ_MpRaidBar.short_numbers.
  #
  # @param gauge [MGQ_MpRaidBar::Gauge] The gauge.
  # @return [String] The HP.
  def numbers(gauge)
    MGQ_MpRaidBar.short_numbers(gauge.hp, gauge.max)
  end

  # Writes how much of a gauge's HP is left, never 0% while any is.
  #
  # @param gauge [MGQ_MpRaidBar::Gauge] The gauge.
  # @return [String] Such as "68.3%".
  def percent(gauge)
    left = share(gauge) * 100
    left > 0 && left < 0.1 ? "<0.1%" : format("%.1f%%", left)
  end

  # Draws a bar: its title centered across the bar and below it the row of gauges, centered, each
  # with its name centered over it and the HP inside, the row's width shared among them with
  # GAUGE_GAP between; the strip's title line names the hotkey that makes it small at its right,
  # and keeps the title out of the hint's room on either side, so it stays centered.
  #
  # @param bar [MGQ_MpRaidBar::Bar] The bar.
  # @param layout [Layout] The sizes of its parts.
  # @param top [Integer] Room above the title.
  # @param row_width [Integer] The width of the row of gauges, inside their frames.
  def draw_bar(bar, layout, top, row_width)
    style = MGQ_MpUi::Style
    gauges = bar.gauges
    count = [gauges.size, 1].max
    gauge_width = (row_width - GAUGE_GAP * (count - 1)) / count
    left = (bitmap.width - row_width) / 2
    name_top = top + layout.title + LINE_EXTRA
    gauge_top = name_top + layout.name + LINE_EXTRA
    size = name_size(gauges, layout.name, gauge_width)
    bitmap.clear
    hint_room = 0
    unless @overhead
      hint = BARS_HINT % MGQ_MpHotkeys.label(:party_box)
      use_font(style::TINY_SIZE, style::DIM)
      hint_room = bitmap.text_size(hint).width + NUMBERS_MARGIN
      draw_outlined(0, top, bitmap.width - NUMBERS_MARGIN, layout.title + LINE_EXTRA, hint, 2)
    end
    draw_plate(bar.title.to_s, layout.title, hint_room, bitmap.width - 2 * hint_room, 0, name_top)
    gauges.each_with_index do |gauge, index|
      x, width = name_box(count, left, gauge_width, index)
      draw_plate(gauge.name.to_s, size, x, width, name_top, gauge_top - FRAME_WIDTH - name_top)
    end
    draw_line(bar.title.to_s, layout.title, TITLE_COLOR, hint_room, top, bitmap.width - 2 * hint_room)
    gauges.each_with_index do |gauge, index|
      x, width = name_box(count, left, gauge_width, index)
      draw_line(gauge.name.to_s, size, style::TEXT, x, name_top, width, gauge_top - name_top)
    end
    gauges.each_with_index do |gauge, index|
      x = left + (gauge_width + GAUGE_GAP) * index
      trail = @trails && @trails[index] ? @trails[index].shown : 0.0
      draw_gauge(x, gauge_top, gauge_width, layout.gauge, share(gauge), [trail, share(gauge)].max)
      draw_numbers(gauge, layout.numbers, x, gauge_top, gauge_width, layout.gauge) if layout.numbers > 0
    end
  end

  # Finds the box a gauge's name and plate are centered in: the whole bar for a boss of one enemy,
  # as its title, else its gauge.
  #
  # @param count [Integer] How many gauges the bar has.
  # @param left [Integer] The row's left.
  # @param gauge_width [Integer] Each gauge's width.
  # @param index [Integer] The gauge's place in the row.
  # @return [Array(Integer, Integer)] The box's left and width.
  def name_box(count, left, gauge_width, index)
    count > 1 ? [left + (gauge_width + GAUGE_GAP) * index, gauge_width] : [0, bitmap.width]
  end

  # Finds the font size the names of a bar share: the layout's for one gauge, else the largest from
  # it down to MIN_NAME_SIZE at which every name fits its gauge.
  #
  # @param gauges [Array<MGQ_MpRaidBar::Gauge>] The gauges.
  # @param size [Integer] The layout's font size of a name.
  # @param gauge_width [Integer] Each gauge's width.
  # @return [Integer] The size.
  def name_size(gauges, size, gauge_width)
    return size if gauges.size <= 1

    room = gauge_width - NUMBERS_MARGIN * 2
    fitting = (MIN_NAME_SIZE..size).to_a.reverse.find do |candidate|
      use_font(candidate, MGQ_MpUi::Style::TEXT)
      gauges.all? { |gauge| bitmap.text_size(gauge.name.to_s).width <= room }
    end
    fitting || [MIN_NAME_SIZE, size].min
  end

  # Draws the plate behind a line of text, centered in its box and as wide as the text, so it never
  # stands on the busy picture behind the bar; none for an empty line. The plates stack onto each
  # other and onto the gauge's frame without a gap.
  #
  # @param text [String] The line's text.
  # @param size [Integer] Its font's size.
  # @param x [Integer] The box's left.
  # @param box_width [Integer] The box's width, which caps the plate.
  # @param y [Integer] The plate's top.
  # @param height [Integer] The plate's height.
  def draw_plate(text, size, x, box_width, y, height)
    use_font(size, MGQ_MpUi::Style::TEXT)
    MGQ_MpUi::Style.draw_plate(bitmap, x, y, box_width, height, text)
  end

  # Draws a line of text centered in its box, cut to fit.
  #
  # @param text [String] The text.
  # @param size [Integer] Its font's size.
  # @param color [Color] Its color.
  # @param x [Integer] The box's left.
  # @param y [Integer] Its top.
  # @param width [Integer] The box's width.
  # @param height [Integer] The box's height, the font's line for one of its own; a shrunken name
  #   keeps its row's, so it stays centered over its gauge.
  def draw_line(text, size, color, x, y, width, height = size + LINE_EXTRA)
    use_font(size, color)
    draw_outlined(x, y, width, height, MGQ_MpUi.cut(bitmap, text, width - NUMBERS_MARGIN * 2, ""))
  end

  # Draws a text in a box in the style's solid outline, in the font's color.
  #
  # @param x [Integer] The box's left.
  # @param y [Integer] The box's top.
  # @param width [Integer] The box's width.
  # @param height [Integer] The box's height.
  # @param text [String] The text.
  # @param align [Integer] 1 for centered, 2 for right, as Bitmap#draw_text takes it.
  def draw_outlined(x, y, width, height, text, align = 1)
    MGQ_MpUi::Style.draw_outlined(bitmap, x, y, width, height, text, align)
  end

  # Sets the font of what is drawn next, in the style's way: never bold, with the solid outline.
  #
  # @param size [Integer] Its size.
  # @param color [Color] Its color.
  def use_font(size, color)
    MGQ_MpUi::Style.use_font(bitmap, size, color)
  end

  # Draws a gauge in its frame, filled by the share left.
  #
  # @param x [Integer] Its left, inside the frame.
  # @param y [Integer] Its top, inside the frame.
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  # @param left [Float] The share left.
  # @param trail [Float] The share the damage trail reaches, at least the share left.
  def draw_gauge(x, y, width, height, left, trail = left)
    bitmap.fill_rect(x - FRAME_WIDTH, y - FRAME_WIDTH, width + FRAME_WIDTH * 2, height + FRAME_WIDTH * 2, MGQ_MpUi::Style::OUTLINE)
    bitmap.fill_rect(x - 1, y - 1, width + 2, height + 2, EDGE)
    bitmap.fill_rect(x, y, width, height, EMPTY)
    filled = (width * left).ceil
    trailing = (width * trail).ceil - filled
    bitmap.gradient_fill_rect(x + filled, y, trailing, height, TRAIL_TOP, TRAIL_BOTTOM, true) if trailing > 0
    draw_fill(x, y, filled, height) if filled > 0
  end

  # Draws a gauge's filled part: its upper half from FILL_TOP to FILL_MIDDLE, its lower half on to
  # FILL_BOTTOM.
  #
  # @param x [Integer] Its left.
  # @param y [Integer] Its top.
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  def draw_fill(x, y, width, height)
    upper = height / 2
    bitmap.gradient_fill_rect(x, y, width, upper, FILL_TOP, FILL_MIDDLE, true)
    bitmap.gradient_fill_rect(x, y + upper, width, height - upper, FILL_MIDDLE, FILL_BOTTOM, true)
  end

  # Draws the HP inside a gauge, centered: with how much is left, the HP alone when that does not
  # fit, and how much is left alone when even the HP does not.
  #
  # @param gauge [MGQ_MpRaidBar::Gauge] The gauge.
  # @param size [Integer] The numbers' font size.
  # @param x [Integer] The gauge's left.
  # @param y [Integer] The gauge's top.
  # @param width [Integer] The gauge's width.
  # @param height [Integer] The gauge's height.
  def draw_numbers(gauge, size, x, y, width, height)
    use_font(size, MGQ_MpUi::Style::TEXT)
    room = width - NUMBERS_MARGIN * 2
    texts = ["#{numbers(gauge)}  (#{percent(gauge)})", numbers(gauge), percent(gauge)]
    text = texts.find { |candidate| bitmap.text_size(candidate).width <= room } || texts.last
    draw_outlined(x, y, width, height, text)
  end

  # Frees the bar's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The strip's box, and the game hooks, through core_hooks.rbx.

begin
  MGQ_MpUi::Layout.register(MGQ_MpRaidBar::STRIP_BOX, MGQ_MpRaidBar::STRIP_BOX_NAME, Sprite_MpRaidBar.min_strip_width, MGQ_MpRaidBar::STRIP_HEIGHT, :width)

  # After the battle's sprites, the strip of a battle that fights a boss's pools.
  MGQ_MpHooks.after(Spriteset_Battle, :update, "ui_raid_bar") { (@mgq_mp_raid_bar ||= Sprite_MpRaidBar.new(nil, false)).update_battle }

  MGQ_MpHooks.before(Spriteset_Battle, :dispose, "ui_raid_bar") do
    @mgq_mp_raid_bar.dispose if @mgq_mp_raid_bar
    @mgq_mp_raid_bar = nil
    MGQ_MpRaidBar.battle_shown = false
  end

  # After the map's sprites, the bosses' bars.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_raid_bar") do
    @mgq_mp_raid_bars ||= MGQ_MpRaidBar::MapBars.new(MGQ_MpGame.get(self, :viewport1), MGQ_MpGame.get(self, :viewport3))
    @mgq_mp_raid_bars.update(MGQ_MpGame.get(self, :character_sprites))
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_raid_bar") do
    @mgq_mp_raid_bars.dispose if @mgq_mp_raid_bars
    @mgq_mp_raid_bars = nil
    MGQ_MpUi.top_room = 0
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
