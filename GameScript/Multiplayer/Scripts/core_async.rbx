#----------------------------------------------------------------
#  core_async.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Read an interpreter's event and map through MGQ_MpGame
#                            - Logged when the world starts and stops running behind a screen, each event command held and let run, the map refreshes that wait, the instant switches and the live map shown
#      Paulinchen  2026-10-06: Wrapped the screens, the screen's freeze and transition and the menus' backgrounds through core_hooks.rbx instead of wraps of its own
#                            - Read the command an interpreter runs through MGQ_MpGame
#      Paulinchen  2026-10-04: Renamed from mp_async.rbx
#      Paulinchen  2026-10-03: Read and wrote the game's private fields and called its private methods through MGQ_MpGame
#                            - Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Held event commands through core_hooks.rbx
#                            - Asked behind? directly where the live map is decided
#      Paulinchen  2026-09-30: Moved into Patch/Multiplayer/Scripts as core_async.rbx, which Multiplayer.rb loads
#                            - Skipped the screen's freeze between the map and menus, since even a transition of no frames took seven
#                            - Switched between the map and menus at once, since a fade froze the world behind them
#                            - Created
#
#----------------------------------------------------------------

# Keeps the world running while a world is open: behind a menu, a shop, a battle or a story scene,
# the map goes on as if the player stood on it. Other players walk on, NPCs move, background events
# and the timer run, and a menu shows the live map behind it. What needs the player, such as a
# message, a battle, a transfer or an event they touched, waits until they are back on the map.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpAsync
  # Event commands that need the player, or that would reach into the screen in front, and so wait
  # until the player is back on the map: messages, choices and inputs; transfers and vehicles;
  # music, sounds of the map and movies; party changes; everything from battles to the title
  # screen, and actors' changes, which would reach into a running battle; and scripts, which may
  # do any of these.
  HELD_CODES = [101, 102, 103, 104, 105, 129, 201, 206, 241, 242, 243, 244, 245, 246, 249, 261, 355] + (301..399).to_a

  # Screens the world does not run behind, since they leave it.
  LEAVING_SCENES = [:Scene_Title, :Scene_Gameover]

  @ticking = false

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "async"

  # Reports whether the world runs behind a screen: a world is open, and the player left the map
  # for a screen that returns to it.
  #
  # @param scene [Scene_Base] The screen in front.
  # @return [Boolean] Whether it runs.
  def self.behind?(scene)
    return false if scene.is_a?(Scene_Map) || LEAVING_SCENES.any? { |name| Object.const_defined?(name) && scene.is_a?(Object.const_get(name)) }
    return false unless defined?(MGQ_MpWorld) && MGQ_MpWorld.open?
    return false unless $game_map && $game_map.map_id > 0

    map_waiting?
  end

  # Reports whether a map waits for the player to come back, as it does below a screen it called.
  #
  # The map clears the scene stack whenever it starts, so a map on it is the one left last.
  #
  # @return [Boolean] Whether one waits.
  def self.map_waiting?
    stack = MGQ_MpGame.get(SceneManager, :stack)
    stack.is_a?(Array) && stack.any? { |scene| scene.is_a?(Scene_Map) }
  end

  # Runs the map for one frame behind a screen, as the map itself would, but without the player
  # and without the map's main event, which waits for the player. Called every frame of every screen.
  #
  # @param scene [Scene_Base] The screen in front.
  def self.tick(scene)
    behind = behind?(scene)
    note_behind(behind ? scene.class.name : nil)
    return unless behind

    map = $game_map
    # The game's map refresh plays the field's music when a switch changed it, which would cut
    # into a battle's, so that refresh waits for the map.
    deferred = map.need_refresh && field_music_pending?(map)
    log_once([:deferred, map.map_id], "map #{map.map_id}'s refresh waits for the player, since it would play the field's music over #{scene.class.name}") if deferred
    map.need_refresh = false if deferred
    @ticking = true
    map.update(false)
    # A battle runs the timer itself.
    $game_timer.update unless scene.is_a?(Scene_Battle)
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  ensure
    @ticking = false
    map.need_refresh = true if deferred
  end

  # Logs when the world starts or stops running behind a screen, and behind which.
  #
  # @param scene [String, nil] The screen's class the world runs behind, nil while it does not.
  def self.note_behind(scene)
    return if scene == @behind

    if scene
      log("the world runs on behind #{scene} (map #{$game_map.map_id})")
    else
      log("the world stopped running behind #{@behind}")
    end
    @behind = scene
  rescue
  end

  # Logs an event command that waits for the player to be back on the map, and lets it wait.
  #
  # @param interpreter [Game_Interpreter] The interpreter that runs it.
  # @param command [RPG::EventCommand] The command.
  # @yield The wait, until the player is back.
  def self.hold(interpreter, command)
    event = MGQ_MpGame.get(interpreter, :event_id)
    map = MGQ_MpGame.get(interpreter, :map_id)
    log("held command #{command.code} of event #{event} on map #{map} until the player is back on the map")
    yield
    log("let command #{command.code} of event #{event} on map #{map} run, the player is back")
  rescue FiberError
    # An interpreter run outside a fiber cannot wait, so its command runs at once.
    log("could not hold command #{command.code} of event #{event} on map #{map}: its interpreter runs outside a fiber, so it runs at once")
  end

  # Reports whether the map's next refresh would play the field's music.
  #
  # @param map [Game_Map] The map.
  # @return [Boolean] Whether it would.
  def self.field_music_pending?(map)
    map.respond_to?(:need_refresh_autoplay_field) && map.need_refresh_autoplay_field ? true : false
  end

  # Reports whether an event command has to wait for the player to be back on the map.
  #
  # Only the map's events run behind a screen, and only during tick, so a battle's own events and
  # everything on the map never wait.
  #
  # @param command [RPG::EventCommand, nil] The command.
  # @return [Boolean] Whether it waits.
  def self.hold?(command)
    @ticking && !command.nil? && HELD_CODES.include?(command.code)
  end

  # Reports whether leaving a screen for another switches at once: between the map and menus while
  # a world is open.
  #
  # @param from [Scene_Base] The screen left.
  # @param to [Scene_Base, nil] The screen next, nil when the game ends.
  # @return [Boolean] Whether it switches at once.
  def self.instant_switch?(from, to)
    return false unless defined?(MGQ_MpWorld) && MGQ_MpWorld.open?
    return false unless [from, to].all? { |scene| scene.is_a?(Scene_Map) || scene.is_a?(Scene_MenuBase) }

    to.is_a?(Scene_Map) || map_waiting?
  end

  # Leaves a screen, skipping the freeze of the screen when the next one comes in at once. The
  # engine's transition from a frozen screen takes about seven frames even when it lasts none,
  # during which nothing moves; without a freeze, the screen keeps its last picture until the next
  # one draws its first.
  #
  # @param from [Scene_Base] The screen left.
  # @yield The screen's own leaving, which freezes the screen.
  def self.leave(from)
    @skip_freeze = instant_switch?(from, SceneManager.scene)
    log("switching from #{from.class.name} to #{SceneManager.scene.class.name} at once, without freezing the screen") if @skip_freeze
    yield
  ensure
    @skip_freeze = false
  end

  # Reports whether to skip a freeze of the screen, and remembers it was skipped. Called by Graphics.freeze.
  #
  # @return [Boolean] Whether to skip it.
  def self.skip_freeze?
    # A freeze that happens belongs to its own transition, which must not be skipped.
    @unfrozen = @skip_freeze ? true : false
  end

  # Reports whether to skip a transition, as after a skipped freeze, and forgets the skip. Called
  # by Graphics.transition.
  #
  # @return [Boolean] Whether to skip it.
  def self.skip_transition?
    skipped = @unfrozen ? true : false
    @unfrozen = false
    skipped
  end

  # Makes the live map a menu shows in place of its picture of the map, for menus whose background
  # is that picture while the world runs; menus with a background of their own keep it.
  #
  # @param scene [Scene_MenuBase] The menu.
  # @param background [Sprite, nil] The menu's background.
  # @return [Spriteset_MpLiveMap, nil] The live map, nil where the menu keeps its background.
  def self.live_map_for(scene, background)
    return nil unless background && background.bitmap.equal?(SceneManager.background_bitmap)
    return nil unless behind?(scene)

    live_map = Spriteset_MpLiveMap.new
    background.visible = false
    log("showed the live map behind #{scene.class.name} in place of its picture of the map")
    live_map
  rescue => e
    log("live map failed: #{e.class}: #{e.message}")
    nil
  end

  # Updates the live map behind a menu, showing the menu's picture again when it fails.
  #
  # @param live_map [Spriteset_MpLiveMap] The live map.
  # @param background [Sprite, nil] The menu's background.
  # @return [Spriteset_MpLiveMap, nil] The live map, nil once it failed and was freed.
  def self.update_live_map(live_map, background)
    live_map.update
    live_map
  rescue => e
    log("live map update failed: #{e.class}: #{e.message}")
    dispose_live_map(live_map)
    background.visible = true if background
    nil
  end

  # Frees the live map behind a menu.
  #
  # @param live_map [Spriteset_MpLiveMap, nil] The live map.
  def self.dispose_live_map(live_map)
    live_map.dispose if live_map
  rescue => e
    log("live map dispose failed: #{e.class}: #{e.message}")
  end
end

# The live map behind a menu: the map's sprites, below everything the menu draws and dimmed as the
# menu's picture of the map is.
class Spriteset_MpLiveMap < Spriteset_Map
  # Depths of the map's three viewports, below the menu's windows and sprites.
  DEPTHS = [-300, -250, -200]

  # The dimming over the map.
  DIM = Color.new(16, 16, 16, 128)

  # Creates the map's sprites and the dimming over them.
  def initialize
    super
    @mgq_mp_dim = Sprite.new(@viewport3)
    @mgq_mp_dim.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    @mgq_mp_dim.bitmap.fill_rect(@mgq_mp_dim.bitmap.rect, DIM)
    @mgq_mp_dim.z = 10_000
  end

  # Creates the map's viewports, below the menu.
  def create_viewports
    super
    [@viewport1, @viewport2, @viewport3].zip(DEPTHS).each { |viewport, depth| viewport.z = depth }
  end

  # Frees the dimming, then the map's sprites.
  def dispose
    if @mgq_mp_dim
      @mgq_mp_dim.bitmap.dispose
      @mgq_mp_dim.dispose
    end
    super
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After a screen's basics, the world behind it and the live map behind a menu.
  MGQ_MpHooks.after(Scene_Base, :update_basic, "core_async") do
    MGQ_MpAsync.tick(self)
    @mgq_mp_live_map = MGQ_MpAsync.update_live_map(@mgq_mp_live_map, @background_sprite) if @mgq_mp_live_map
  end

  # Leaving a screen, without freezing it when the next one comes in at once.
  MGQ_MpHooks.around(Scene_Base, :terminate, "core_async") { |scene, _args, original| MGQ_MpAsync.leave(scene) { original.call } }
rescue => e
  MGQ_MpAsync.log("scene hook FAILED: #{e.class}: #{e.message}")
end

begin
  # Freezing the screen, unless the screen being left switches to the next at once, and the
  # transition from the frozen screen, unless the freeze was skipped.
  MGQ_MpHooks.around(Graphics.singleton_class, :freeze, "core_async") { |_graphics, _args, original| MGQ_MpAsync.skip_freeze? ? nil : original.call }
  MGQ_MpHooks.around(Graphics.singleton_class, :transition, "core_async") { |_graphics, _args, original| MGQ_MpAsync.skip_transition? ? nil : original.call }
rescue => e
  MGQ_MpAsync.log("screen hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # After a menu's picture of the map, the live map in its place while the world runs.
  MGQ_MpHooks.after(Scene_MenuBase, :create_background, "core_async") do
    @mgq_mp_live_map = MGQ_MpAsync.live_map_for(self, @background_sprite)
  end

  # Before the menu's picture of the map is freed, the live map.
  MGQ_MpHooks.before(Scene_MenuBase, :dispose_background, "core_async") do
    MGQ_MpAsync.dispose_live_map(@mgq_mp_live_map)
    @mgq_mp_live_map = nil
  end
rescue => e
  MGQ_MpAsync.log("menu hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # Before an event command runs, its interpreter waits until the player is back on the map when
  # the command needs them and the map runs behind another screen.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "core_async") do
    command = MGQ_MpGame.get(self, :list)[MGQ_MpGame.get(self, :index)]
    if MGQ_MpAsync.hold?(command)
      MGQ_MpAsync.hold(self, command) { Fiber.yield while MGQ_MpAsync.hold?(MGQ_MpGame.get(self, :list)[MGQ_MpGame.get(self, :index)]) }
    end
  end
rescue => e
  MGQ_MpAsync.log("event hook FAILED: #{e.class}: #{e.message}")
end
