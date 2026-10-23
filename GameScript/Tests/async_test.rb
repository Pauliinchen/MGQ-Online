#----------------------------------------------------------------
#  async_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Checked that the live map shows none of the HUD the map shows
#                            - Checked that the save and load screens keep their picture of the map
#                            - Checked the memory the game uses in the log of a switch of screens
#      Paulinchen  2026-10-06: Checked that a live map that fails is freed and the menu's picture shows again
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers core_async.rbx: the world running on behind menus, battles and story scenes.

require_relative "support"

# Stands in for the game's color.
class Color; def initialize(*); end; end
# Stands in for the game's rectangle.
class Rect; end
# Stands in for a picture, telling when it is freed.
class Bitmap
  def initialize(*); end
  def rect; Rect.new; end
  def fill_rect(*); end
  def dispose; @disposed = true; end
end
# Stands in for a viewport, of which only the depth is read.
class Viewport; attr_accessor :z; def initialize; @z = 0; end; end
# Stands in for a sprite, telling whether it shows and when it is freed.
class Sprite
  attr_accessor :bitmap, :z, :visible
  def initialize(viewport = nil); @visible = true; end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
end
# Stands in for the screen, keeping its freezes and transitions in $screen.
module Graphics
  def self.width; 640; end
  def self.height; 480; end
  def self.freeze; $screen << :freeze; end
  def self.transition(*); $screen << :transition; end
end
$screen = []
# Stands in for the loader's log, printing its lines.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
# Stands in for the DLL, which describes the memory the game uses as $memory_usage says.
module MGQ_Multiplayer; module Link; def self.read(_name, _size); $memory_usage; end; end; end
$memory_usage = ""
# Stands in for world.rbx, a world open while $open is.
module MGQ_MpWorld; def self.open?; $open; end; end

# Stands in for the game's scene manager, its stack set by each test and its picture in $snapshot.
module SceneManager
  @stack = []
  class << self; attr_accessor :scene; end
  def self.background_bitmap; $snapshot; end
end
$snapshot = Bitmap.new

# Stands in for the scenes' base, counting its basic updates in $basic and fading as it ends and starts.
class Scene_Base
  def update_basic; $basic += 1; end
  def terminate; Graphics.freeze; end
  def post_start; Graphics.transition(10); end
end
# Stands in for the map scene.
class Scene_Map < Scene_Base; end
# Stands in for the battle scene.
class Scene_Battle < Scene_Base; end
# Stands in for the title screen.
class Scene_Title < Scene_Base; end
# Stands in for the game over screen.
class Scene_Gameover < Scene_Base; end
# Stands in for a story scene.
class Scene_Novel < Scene_Base; end
# Stands in for the menus' base, whose background is the picture of the screen left.
class Scene_MenuBase < Scene_Base
  attr_reader :background_sprite
  def create_background
    @background_sprite = Sprite.new
    @background_sprite.bitmap = SceneManager.background_bitmap
  end
  def dispose_background; @background_sprite.dispose; end
end
# Stands in for the main menu.
class Scene_Menu < Scene_MenuBase; end
# Stands in for the save and load screens' base.
class Scene_File < Scene_MenuBase; end
# Stands in for the save screen.
class Scene_Save < Scene_File; end
# Stands in for a menu with a background of its own.
class Scene_Poker < Scene_MenuBase
  def create_background; @background_sprite = Sprite.new; @background_sprite.bitmap = Bitmap.new; end
end

# Stands in for the map's sprites, counting their updates.
class Spriteset_Map
  attr_reader :viewport1, :viewport2, :viewport3, :updates
  def initialize; create_viewports; @updates = 0; end
  def create_viewports; @viewport1, @viewport2, @viewport3 = Viewport.new, Viewport.new, Viewport.new; end
  def update; @updates += 1; end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
end

# Stands in for the map, keeping each update's main flag and running its parallel event.
class Game_Map
  attr_accessor :need_refresh, :need_refresh_autoplay_field, :map_id, :updates, :refreshed_with_music, :parallel
  def initialize; @map_id = 5; @updates = []; @need_refresh = false; end
  def update(main = false)
    @updates << main
    @refreshed_with_music = @need_refresh_autoplay_field if @need_refresh
    @need_refresh = false
    @parallel.update if @parallel
  end
end
# Stands in for the game's timer, counting its ticks.
class Game_Timer; attr_reader :ticks; def initialize; @ticks = 0; end; def update; @ticks += 1; end; end

# An event command, of which only the code is read.
Command = Struct.new(:code)
# Stands in for the event interpreter, running its list in a fiber and keeping each code run in
# @done.
class Game_Interpreter
  attr_reader :done
  def initialize(list); @list = list; @done = []; end
  def running?; !@fiber.nil?; end
  def update
    @fiber ||= Fiber.new { run }
    @fiber.resume if @fiber
  end
  def run
    @index = 0
    while @list[@index]
      execute_command
      @index += 1
    end
    @fiber = nil
  end
  def execute_command; @done << @list[@index].code; end
  # Runs the first command outside a fiber.
  def run_outside_fiber; @index = 0; execute_command; end
end

# Stands in for coop.rbx's tell and routes.
module MGQ_MpCoop
  def self.tell(seat, field, value, fields = {})
    MGQ_MpOverworldSync::Link.send_to(seat, MGQ_MpOverworldSync::Me.encode({ field => value, "party" => Party.id }.merge(fields)))
  end
  def self.route(*); end
end
# Stands in for the world room's routes and hooks, ignored here.
module MGQ_MpOverworldSync
  def self.route(*); end
  def self.on_tick(*); end
  def self.state_fields(*); end
  def self.busy_scene(*); end
  def self.on_observe(*); end
  def self.on_leave(*); end
  def self.label_line(*); end
end
load_script "core_async"

$basic = 0
$open = true
$game_map = Game_Map.new
$game_timer = Game_Timer.new
map_scene = Scene_Map.new
SceneManager.instance_variable_set(:@stack, [])

# Where the world runs.
check("not on the map itself", MGQ_MpAsync.behind?(map_scene), false)
menu = Scene_Menu.new
check("not without a map to go back to", MGQ_MpAsync.behind?(menu), false)
SceneManager.instance_variable_set(:@stack, [map_scene])
check("behind a menu called from the map", MGQ_MpAsync.behind?(menu), true)
check("behind a battle", MGQ_MpAsync.behind?(Scene_Battle.new), true)
check("behind a story scene", MGQ_MpAsync.behind?(Scene_Novel.new), true)
check("not behind the title or game over", [MGQ_MpAsync.behind?(Scene_Title.new), MGQ_MpAsync.behind?(Scene_Gameover.new)], [false, false])
$open = false
check("not outside a world", MGQ_MpAsync.behind?(menu), false)
$open = true

# The tick.
menu.update_basic
check("the screen's basics still run", $basic, 1)
check("the map runs without its main event", $game_map.updates, [false])
check("the timer runs behind a menu", $game_timer.ticks, 1)
Scene_Battle.new.update_basic
check("the battle runs the timer itself", [$game_map.updates.size, $game_timer.ticks], [2, 1])
map_scene.update_basic
check("the map's own frame is left alone", $game_map.updates.size, 2)

$game_map.need_refresh = true
$game_map.need_refresh_autoplay_field = true
menu.update_basic
check("a refresh that plays field music waits", [$game_map.refreshed_with_music, $game_map.need_refresh], [nil, true])
$game_map.need_refresh_autoplay_field = false
menu.update_basic
check("other refreshes happen behind the screen", [$game_map.refreshed_with_music, $game_map.need_refresh], [false, false])

# Held commands.
parallel = Game_Interpreter.new([Command.new(122), Command.new(101), Command.new(123)])
$game_map.parallel = parallel
3.times { menu.update_basic }
check("a background event runs up to what needs the player", parallel.done, [122])
check("and waits there", parallel.running?, true)
check("hold only while the world runs behind a screen", MGQ_MpAsync.hold?(Command.new(101)), false)
parallel.update
check("back on the map it goes on", parallel.done, [122, 101, 123])
battle_event = Game_Interpreter.new([Command.new(301), Command.new(355)])
battle_event.update
check("events outside the tick never wait", battle_event.done, [301, 355])
check("every command that needs the player is held", [101, 102, 103, 104, 105, 129, 201, 206, 241, 249, 261, 301, 302, 351, 353, 354, 355].all? { |code| MGQ_MpAsync::HELD_CODES.include?(code) }, true)
check("moving, waiting and switches are not", [121, 122, 205, 230, 111, 117].none? { |code| MGQ_MpAsync::HELD_CODES.include?(code) }, true)
root = Game_Interpreter.new([Command.new(101)])
MGQ_MpAsync.instance_variable_set(:@ticking, true)
root.run_outside_fiber
MGQ_MpAsync.instance_variable_set(:@ticking, false)
check("an interpreter outside a fiber runs at once", root.done, [101])

# The live map behind menus.
SceneManager.scene = menu
menu.create_background
live = menu.instance_variable_get(:@mgq_mp_live_map)
check("a menu shows the live map", live.is_a?(Spriteset_MpLiveMap), true)
check("in place of its picture", menu.background_sprite.visible, false)
check("below the menu", [live.viewport1.z, live.viewport2.z, live.viewport3.z].all? { |z| z < 0 }, true)
check("without the HUD the map shows", [live.mgq_mp_hud?, Spriteset_Map.new.mgq_mp_hud?], [false, true])
menu.update_basic
check("the live map moves every frame", live.updates, 1)
menu.dispose_background
check("closing frees the live map and the picture", [live.disposed?, menu.background_sprite.disposed?, menu.instance_variable_get(:@mgq_mp_live_map)], [true, true, nil])
menu.create_background
broken = menu.instance_variable_get(:@mgq_mp_live_map)
def broken.update; raise "broken"; end
menu.update_basic
check("a live map that fails is freed, and the picture shows again", [broken.disposed?, menu.instance_variable_get(:@mgq_mp_live_map), menu.background_sprite.visible], [true, nil, true])
menu.dispose_background
poker = Scene_Poker.new
poker.create_background
check("a menu with its own background keeps it", [poker.instance_variable_get(:@mgq_mp_live_map), poker.background_sprite.visible], [nil, true])
save = Scene_Save.new
save.create_background
check("the save screen keeps its picture of the map (issue 42)", [save.instance_variable_get(:@mgq_mp_live_map), save.background_sprite.visible], [nil, true])
SceneManager.instance_variable_set(:@stack, [])
title_menu = Scene_Menu.new
title_menu.create_background
check("no live map without a map to go back to", [title_menu.instance_variable_get(:@mgq_mp_live_map), title_menu.background_sprite.visible], [nil, true])

# Switching screens.
# Switches from one screen to another as SceneManager does, and tells what the screen did meanwhile.
#
# @param from [Object] The screen left.
# @param to [Object] The screen entered.
# @param stack [Array] SceneManager's stack while entering it.
# @return [Array<Symbol>] The freezes and transitions of the switch.
def switch(from, to, stack)
  SceneManager.instance_variable_set(:@stack, stack)
  SceneManager.scene = to
  $screen.clear
  from.terminate
  to.post_start
  $screen.dup
end
menu_scene = Scene_Menu.new
check("the map to a menu switches at once", switch(map_scene, menu_scene, [map_scene]), [])
check("a menu back to the map too", switch(menu_scene, map_scene, []), [])
check("a menu to another menu too", switch(menu_scene, Scene_Menu.new, [map_scene]), [])
check("the map to a battle keeps its fade", switch(map_scene, Scene_Battle.new, [map_scene]), [:freeze, :transition])
check("a menu to the title keeps its fade", switch(menu_scene, Scene_Title.new, [map_scene]), [:freeze, :transition])
$open = false
check("outside a world everything fades as ever", switch(map_scene, menu_scene, [map_scene]), [:freeze, :transition])
$memory_usage = "private 812 MB, 320 GDI and 150 USER handles"
check("every switch logs the memory the game uses", logged_lines { switch(menu_scene, Scene_Battle.new, [map_scene]) },
      ["async: switching from Scene_Menu to Scene_Battle; private 812 MB, 320 GDI and 150 USER handles"])
$memory_usage = ""
$open = true
SceneManager.scene = menu_scene
$screen.clear
MGQ_MpAsync.leave(map_scene) { Graphics.freeze }
Graphics.freeze
Graphics.transition(10)
check("a real freeze after a skipped one keeps its transition", $screen, [:freeze, :transition])
