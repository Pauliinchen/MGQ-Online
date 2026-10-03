#----------------------------------------------------------------
#  mp_async.rbx
#
#  Changelog:
#      Paulinchen  2026-10-03: Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Held event commands through mp_hooks.rbx
#                            - Asked behind? directly where the live map is decided
#      Paulinchen  2026-09-30: Moved into Patch/Multiplayer/Scripts as mp_async.rbx, which Multiplayer.rb loads
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

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Scene_Base.method_defined?(:mgq_mp_async_update_basic)
  end

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
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
    stack = SceneManager.instance_variable_get(:@stack)
    stack.is_a?(Array) && stack.any? { |scene| scene.is_a?(Scene_Map) }
  end

  # Runs the map for one frame behind a screen, as the map itself would, but without the player
  # and without the map's main event, which waits for the player. Called every frame of every screen.
  #
  # @param scene [Scene_Base] The screen in front.
  def self.tick(scene)
    return unless behind?(scene)

    map = $game_map
    # The game's map refresh plays the field's music when a switch changed it, which would cut
    # into a battle's, so that refresh waits for the map.
    deferred = map.need_refresh && field_music_pending?(map)
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

# Game hooks.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpAsync.hookable?
  begin
    class Scene_Base
      alias mgq_mp_async_update_basic update_basic

      # Updates the screen's basics, then runs the world behind it and the live map behind a menu.
      def update_basic
        mgq_mp_async_update_basic
        MGQ_MpAsync.tick(self)
        mgq_mp_async_update_live_map
      end

      alias mgq_mp_async_terminate terminate

      # Leaves the screen, without freezing it when the next one comes in at once.
      def terminate
        MGQ_MpAsync.leave(self) { mgq_mp_async_terminate }
      end

      # Updates the live map behind a menu, if the menu shows one.
      def mgq_mp_async_update_live_map
        @mgq_mp_live_map.update if @mgq_mp_live_map
      rescue => e
        MGQ_MpAsync.log("live map update failed: #{e.class}: #{e.message}")
        @mgq_mp_live_map.dispose rescue nil
        @mgq_mp_live_map = nil
        @background_sprite.visible = true if @background_sprite
      end
    end
  rescue => e
    MGQ_MpAsync.log("scene hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class << Graphics
      alias mgq_mp_async_freeze freeze
      alias mgq_mp_async_transition transition

      # Freezes the screen, unless the screen being left switches to the next at once.
      def freeze
        MGQ_MpAsync.skip_freeze? ? nil : mgq_mp_async_freeze
      end

      # Carries out the transition from the frozen screen, unless the freeze was skipped.
      #
      # @param args [Array] The original's arguments.
      def transition(*args)
        MGQ_MpAsync.skip_transition? ? nil : mgq_mp_async_transition(*args)
      end
    end
  rescue => e
    MGQ_MpAsync.log("screen hooks FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Scene_MenuBase
      alias mgq_mp_async_create_background create_background
      alias mgq_mp_async_dispose_background dispose_background

      # Creates the menu's picture of the map, then shows the live map in its place while the world
      # runs.
      def create_background
        mgq_mp_async_create_background
        mgq_mp_async_show_live_map
      end

      # Shows the live map in place of the picture, for menus whose background is that picture;
      # menus with a background of their own keep it.
      def mgq_mp_async_show_live_map
        return unless @background_sprite && @background_sprite.bitmap.equal?(SceneManager.background_bitmap)
        return unless MGQ_MpAsync.behind?(self)

        @mgq_mp_live_map = Spriteset_MpLiveMap.new
        @background_sprite.visible = false
      rescue => e
        MGQ_MpAsync.log("live map failed: #{e.class}: #{e.message}")
        @mgq_mp_live_map = nil
      end

      # Frees the live map, then the menu's picture of the map.
      def dispose_background
        if @mgq_mp_live_map
          @mgq_mp_live_map.dispose rescue nil
          @mgq_mp_live_map = nil
        end
        mgq_mp_async_dispose_background
      end
    end
  rescue => e
    MGQ_MpAsync.log("menu hooks FAILED: #{e.class}: #{e.message}")
  end
end

# Game hooks shared with other scripts, through mp_hooks.rbx.

begin
  # Before an event command runs, its interpreter waits until the player is back on the map when
  # the command needs them and the map runs behind another screen.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "mp_async") do
    begin
      Fiber.yield while MGQ_MpAsync.hold?(@list[@index])
    rescue FiberError
      # An interpreter run outside a fiber cannot wait, so its command runs at once.
    end
  end
rescue => e
  MGQ_MpAsync.log("event hook FAILED: #{e.class}: #{e.message}")
end
