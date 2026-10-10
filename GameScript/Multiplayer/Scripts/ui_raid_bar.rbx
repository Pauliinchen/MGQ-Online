#----------------------------------------------------------------
#  ui_raid_bar.rbx
#
#  Changelog:
#      Paulinchen  2026-10-10: Created
#
#----------------------------------------------------------------

# The HP bars of a Raid World's bosses (see battles_raid_pool.rbx): in a battle that fights a boss's
# pools, a strip across the top of the screen with the boss's HP, its name and how much is left;
# on the map, a bar above each event that starts a boss battle, or the same strip at the top of the
# screen while no such event shows, which the notification and party boxes then make room for (see
# MGQ_MpUi.top_room). A bar shows while the relay keeps the boss's pool, or the story has not beaten
# it; the relay's max HP once it told one, else the boss's own at the player's difficulty.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpRaidBar
  # Frames between two drawings of a bar whose numbers changed, since the HP the pool gains back
  # changes them every frame.
  REDRAW_FRAMES = 6

  # Frames between two looks at the map's events for the bosses' battles.
  SCAN_FRAMES = 30

  # Height of the strip across the top of the screen.
  STRIP_HEIGHT = 24

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
  # @!attribute name [String] The boss's name.
  # @!attribute hp [Integer] Its HP.
  # @!attribute max [Integer] Its max HP.
  Bar = Struct.new(:name, :hp, :max)

  @scanned = nil
  @event_troops = {}
  @common_troops = {}
  @base_hp = {}
  @battle_shown = false

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "raid bar"

  # Finds the bar of the battle running when it fights a boss's pools: its own enemies' HP together,
  # as the battle has them, against the pools' max HP once the relay told it.
  #
  # @return [Bar, nil] The bar, nil for none.
  def self.battle_bar
    fight = MGQ_MpRaidPool.fight
    return nil unless fight

    hp = 0
    max = 0
    fight.members.each do |member|
      enemy = $game_troop.members[member.index]
      next unless enemy

      local = enemy.mhp.to_i
      next unless local > 0

      pool = MGQ_MpRaidPool.pool(member.key)
      shown = pool && pool.max.to_i > 0 ? pool.max.to_i : local
      hp += MGQ_MpRaidPool.hp_of(enemy.dead? ? 0.0 : enemy.hp.to_f / local, shown)
      max += shown
    end
    max > 0 ? Bar.new(fight.name, hp, max) : nil
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

  # Moves the game's own HP bar of a boss below the strip while the strip shows. Called after
  # Sprite_Battler#update_hp_bar, which puts it back at the top every frame.
  #
  # @param sprite [Sprite_Battler] The battler's sprite.
  def self.push_down(sprite)
    return unless @battle_shown

    battler = sprite.battler
    return unless battler.respond_to?(:boss?) && battler.boss?

    bar = MGQ_MpGame.get(sprite, :hp_bar)
    bar.y = GAME_BOSS_BAR_Y + STRIP_HEIGHT if bar && bar.visible
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
  # @param id [Integer] The common event.
  # @param seen [Hash] See troops_in.
  # @return [Array<Integer>] The troops.
  def self.common_troops(id, seen)
    return @common_troops[id] if @common_troops.key?(id)
    return [] if seen[id]

    seen[id] = true
    common = $data_common_events[id]
    troops = common && common.list ? troops_in(common.list, seen) : []
    @common_troops[id] = troops
  end

  # Reports whether a troop's battle shows a bar: the last phase of a raid boss with pools whose
  # relay keeps a pool of it, or whose milestone the story has not beaten.
  #
  # @param troop [Integer] The troop.
  # @return [Boolean] Whether it does.
  def self.shown_troop?(troop)
    pool = MGQ_MpRaidPool
    return false unless MGQ_MpRaidBosses.last_phase?(troop) && !pool::UNPOOLED[troop]

    keys = pool.troop_keys(troop)
    return false if keys.empty?

    pool.pooled_troop?(troop) || keys.any? { |key| pool.pool(key) }
  end

  # Finds a troop's bar on the map: its pools' HP now, the HP the pool gained back since included,
  # the boss's own max HP for a pool the relay told nothing of.
  #
  # @param troop [Integer] The troop.
  # @return [Bar] The bar.
  def self.map_bar(troop)
    pool = MGQ_MpRaidPool
    enemies = troop_enemies(troop)
    now = Time.now
    hp = 0
    max = 0
    pool.troop_keys(troop).each_with_index do |key, index|
      known = pool.pool(key)
      if known && known.max.to_i > 0
        hp += pool.hp_of(pool.left_now(known, now), known.max.to_i)
        max += known.max.to_i
      else
        full = raid_max(enemies[index], troop)
        hp += known ? pool.hp_of(pool.left_now(known, now), full) : full
        max += full
      end
    end
    Bar.new(pool.troop_label(troop), hp, max)
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
    # boss's bar, and tells the boxes at the top the room the strip takes.
    #
    # @param sprites [Array<Sprite_Character>] The map's character sprites.
    def update(sprites)
      pairs = MGQ_MpRaidBar.boss_events
      shown = pairs.map do |event, troop|
        sprite = sprites.find { |candidate| candidate.character.equal?(event) }
        MGQ_MpRaidBar.shows?(event, sprite) ? [event, troop, sprite] : nil
      end.compact
      update_overhead(shown)
      strip = shown.empty? && !pairs.empty? ? pairs.first[1] : nil
      update_strip(strip)
      MGQ_MpUi.top_room = strip ? STRIP_HEIGHT : 0
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

    # Shows the strip with a troop's bar, or hides it.
    #
    # @param troop [Integer, nil] The troop, nil to hide it.
    def update_strip(troop)
      unless troop
        @strip.visible = false if @strip
        return
      end

      @strip ||= Sprite_MpRaidBar.new(@top, false)
      @strip.z = MGQ_MpUi::Z[:labels]
      @strip.show(MGQ_MpRaidBar.map_bar(troop))
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

# A raid boss's HP bar: the strip across the top of the screen, with the HP on the left and the
# boss's name with how much is left on the right, or the small bar above its event on the map.
class Sprite_MpRaidBar < Sprite
  # Width of the bar above an event.
  OVERHEAD_WIDTH = 200

  # Height of the bar above an event.
  OVERHEAD_HEIGHT = 30

  # Pixels between the top of an event's sprite and its bar.
  GAP = 4

  # Background of the strip.
  BACK = Color.new(0, 0, 0, 150)

  # Background of the gauge.
  GAUGE_BACK = Color.new(32, 32, 32, 220)

  # Border of the gauge above an event.
  BORDER = Color.new(0, 0, 0, 220)

  # Colors of the gauge's two ends, by the share left at least: healthy, hurt and nearly beaten.
  GAUGE_COLORS = [[0.5, Color.new(64, 192, 64), Color.new(160, 240, 96)], [0.2, Color.new(224, 160, 32), Color.new(255, 224, 96)],
                  [0.0, Color.new(192, 40, 40), Color.new(255, 112, 80)]]

  # Room between the strip's edges and its texts.
  TEXT_MARGIN = 8

  # Room between the strip's numbers and the boss's name.
  TEXT_GAP = 16

  # Size of the strip's font.
  STRIP_FONT = 16

  # Size of the font of the bar above an event.
  OVERHEAD_FONT = 14

  # Size of the font the long numbers of the bar above an event take.
  SMALL_FONT = 12

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
  end

  # Shows a bar, drawing it again when its numbers changed, at most every
  # MGQ_MpRaidBar::REDRAW_FRAMES.
  #
  # @param bar [MGQ_MpRaidBar::Bar, nil] The bar, nil to hide it.
  def show(bar)
    self.visible = !bar.nil?
    return unless bar

    content = [bar.name, bar.hp, bar.max]
    now = Graphics.frame_count
    return if content == @drawn || (@drawn && @drawn[0] == bar.name && now - @drawn_at < MGQ_MpRaidBar::REDRAW_FRAMES)

    @drawn = content
    @drawn_at = now
    @overhead ? draw_overhead(bar) : draw_strip(bar)
  end

  # Shows the battle's bar while the battle fights a boss's pools and the game's top message does
  # not show.
  def update_battle
    bar = MGQ_MpRaidBar.top_message? ? nil : MGQ_MpRaidBar.battle_bar
    show(bar)
    MGQ_MpRaidBar.battle_shown = !bar.nil?
  rescue => e
    self.visible = false
    MGQ_MpRaidBar.battle_shown = false
    MGQ_MpRaidBar.log_once(:battle, "drawing the battle's boss bar failed: #{e.class}: #{e.message}")
  end

  # Puts the bar above an event's sprite, or under its feet when the screen has no room above.
  #
  # @param sprite [Sprite_Character] The event's sprite.
  def place_over(sprite)
    self.x = sprite.x
    above = sprite.y - sprite.height - OVERHEAD_HEIGHT - GAP
    self.y = above < 0 ? sprite.y + 2 : above
  end

  # Finds the share of a bar's max HP left.
  #
  # @param bar [MGQ_MpRaidBar::Bar] The bar.
  # @return [Float] The share, 0 to 1.
  def share(bar)
    bar.max > 0 ? [[bar.hp.to_f / bar.max, 0.0].max, 1.0].min : 0.0
  end

  # Writes a bar's HP, such as "3,412,880 / 5,000,000".
  #
  # @param bar [MGQ_MpRaidBar::Bar] The bar.
  # @return [String] The HP.
  def numbers(bar)
    "#{MGQ_MpUi.grouped(bar.hp)} / #{MGQ_MpUi.grouped(bar.max)}"
  end

  # Writes how much of a bar's HP is left, never 0% while any is.
  #
  # @param bar [MGQ_MpRaidBar::Bar] The bar.
  # @return [String] Such as "68.3%".
  def percent(bar)
    left = share(bar) * 100
    left > 0 && left < 0.1 ? "<0.1%" : format("%.1f%%", left)
  end

  # Draws the gauge, filled by the share left in the colors of GAUGE_COLORS.
  #
  # @param x [Integer] Its left.
  # @param y [Integer] Its top.
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  # @param left [Float] The share left.
  def draw_gauge(x, y, width, height, left)
    bitmap.fill_rect(x, y, width, height, GAUGE_BACK)
    filled = (width * left).ceil
    return unless filled > 0

    _, from, to = GAUGE_COLORS.find { |least, _from, _to| left >= least }
    bitmap.gradient_fill_rect(x, y, filled, height, from, to)
  end

  # Draws the strip: the gauge, the HP on the left, the boss's name and how much is left on the right.
  #
  # @param bar [MGQ_MpRaidBar::Bar] The bar.
  def draw_strip(bar)
    width = bitmap.width
    height = bitmap.height
    bitmap.clear
    bitmap.fill_rect(0, 0, width, height, BACK)
    draw_gauge(4, 3, width - 8, height - 6, share(bar))
    bitmap.font.size = STRIP_FONT
    bitmap.font.outline = true
    bitmap.font.color = MGQ_MpUi::WHITE
    text = numbers(bar)
    bitmap.draw_text(TEXT_MARGIN, 0, width - TEXT_MARGIN * 2, height, text)
    room = width - TEXT_MARGIN * 2 - bitmap.text_size(text).width - TEXT_GAP
    bitmap.draw_text(TEXT_MARGIN, 0, width - TEXT_MARGIN * 2, height, MGQ_MpUi.cut(bitmap, bar.name, room, "  #{percent(bar)}"), 2)
  end

  # Draws the bar above an event: the HP over a thin gauge, the HP alone with how much is left when
  # the numbers are too long even in the smaller font.
  #
  # @param bar [MGQ_MpRaidBar::Bar] The bar.
  def draw_overhead(bar)
    width = bitmap.width
    bitmap.clear
    bitmap.font.outline = true
    bitmap.font.color = MGQ_MpUi::WHITE
    bitmap.font.size = OVERHEAD_FONT
    text = numbers(bar)
    bitmap.font.size = SMALL_FONT if bitmap.text_size(text).width > width
    text = "#{MGQ_MpUi.grouped(bar.hp)} (#{percent(bar)})" if bitmap.text_size(text).width > width
    bitmap.draw_text(0, 0, width, 16, text, 1)
    bitmap.fill_rect(0, 18, width, 8, BORDER)
    draw_gauge(1, 19, width - 2, 6, share(bar))
  end

  # Frees the bar's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After the battle's sprites, the strip of a battle that fights a boss's pools.
  MGQ_MpHooks.after(Spriteset_Battle, :update, "ui_raid_bar") { (@mgq_mp_raid_bar ||= Sprite_MpRaidBar.new(nil, false)).update_battle }

  MGQ_MpHooks.before(Spriteset_Battle, :dispose, "ui_raid_bar") do
    @mgq_mp_raid_bar.dispose if @mgq_mp_raid_bar
    @mgq_mp_raid_bar = nil
    MGQ_MpRaidBar.battle_shown = false
  end

  # After the map's sprites, the bosses' bars.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_raid_bar") do
    (@mgq_mp_raid_bars ||= MGQ_MpRaidBar::MapBars.new(@viewport1, @viewport3)).update(@character_sprites)
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
