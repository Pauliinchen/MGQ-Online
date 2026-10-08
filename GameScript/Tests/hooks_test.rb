#----------------------------------------------------------------
#  hooks_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-07: Checked that the hooks are logged as one line per script, once
#                            - Checked that who holds the player is logged when it changes
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked around and holding the player
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Covers core_hooks.rbx: the blocks run on the object with the method's arguments, in the order nested
# wraps would run them, the method's result and visibility stay, a failing block is logged once and
# keeps the others running, and a second registration replaces the first.

require_relative "support"

$calls = []
$log = []

module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end

# A stand-in for a game class.
class Scene_Test
  def initialize; @name = "scene"; end
  def update(value); $calls << [:update, value]; value * 2; end
  def secret; :secret; end
  private :secret
end

# A subclass with a method of the same name, wrapped too.
class Scene_TestChild < Scene_Test
  def update(value); $calls << [:child_update, value]; super; end
end

# A stand-in for a module's method, such as Graphics.update.
module Frames; def self.update; $calls << :frame; end; end

load_script "core_hooks"

MGQ_MpHooks.before(Scene_Test, :update, "first") { |value| $calls << [:first_before, @name, value] }
MGQ_MpHooks.after(Scene_Test, :update, "first") { |value| $calls << [:first_after, value] }
MGQ_MpHooks.before(Scene_Test, :update, "second") { |_value| $calls << :second_before }
MGQ_MpHooks.after(Scene_Test, :update, "second") { |_value| $calls << :second_after }

result = Scene_Test.new.update(3)
check("the method's result stays", result, 6)
check("before blocks run last registered first, after blocks first registered first, on the object with the arguments",
      $calls, [:second_before, [:first_before, "scene", 3], [:update, 3], [:first_after, 3], :second_after])

$calls.clear
MGQ_MpHooks.after(Scene_Test, :update, "first") { |_value| $calls << :first_again }
Scene_Test.new.update(1)
check("a second registration replaces the first in its place",
      $calls, [:second_before, [:first_before, "scene", 1], [:update, 1], :first_again, :second_after])

$calls.clear
MGQ_MpHooks.before(Scene_Test, :update, "broken") { |_value| raise "boom" }
2.times { Scene_Test.new.update(1) }
check("a failing block leaves the method and the other blocks running", $calls.count([:update, 1]), 2)
check("a failing block is logged once", $log.grep(/broken failed before Scene_Test#update: RuntimeError: boom/).size, 1)

$calls.clear
MGQ_MpHooks.after(Scene_TestChild, :update, "child") { |_value| $calls << :child_after }
Scene_TestChild.new.update(5)
check("a subclass's method wraps apart from its superclass's",
      $calls.include?(:child_after) && $calls.include?([:update, 5]) && $calls.count(:child_after) == 1, true)

MGQ_MpHooks.after(Scene_Test, :secret, "private") { $calls << :secret_after }
check("a private method stays private", Scene_Test.private_method_defined?(:secret), true)

$calls.clear
MGQ_MpHooks.after(Frames.singleton_class, :update, "frames") { $calls << [:after_frame, self] }
Frames.update
check("a module's method runs its blocks on the module", $calls, [:frame, [:after_frame, Frames]])

# A wrap that decides when the original runs and what the method returns.
class Scene_Around
  def double(value); value * 2; end
  def hidden; :hidden; end
  private :hidden
end
MGQ_MpHooks.around(Scene_Around, :double, "one") { |_scene, args, original| args[0] > 5 ? :refused : original.call + 1 }
MGQ_MpHooks.around(Scene_Around, :double, "two") { |_scene, _args, original| [original.call] }
MGQ_MpHooks.around(Scene_Around, :hidden, "one") { |_scene, _args, original| original.call }
check("around decides what the method returns, and wraps stack", [Scene_Around.new.double(2), Scene_Around.new.double(9)], [[5], [:refused]])
check("a private method stays private around too", Scene_Around.private_method_defined?(:hidden), true)
MGQ_MpHooks.around(Scene_Around, :double, "two") { |_scene, _args, original| [original.call, :again] }
check("a script registering again replaces its wrap instead of wrapping once more", Scene_Around.new.double(2), [5, :again])
check("and the replacement is logged", $log.grep(/two wrapped Scene_Around#double again/).size, 1)
$log.clear
MGQ_MpHooks.report
check("the hooks are logged as one line per script with how many methods it follows and wraps, not one per method",
      $log.grep(/: follows \d+, wraps \d+ game method\(s\)\z/).size == $log.size && $log.grep(/hooks: one: follows 0, wraps 2 game method/).size, 1)
$log.clear
MGQ_MpHooks.report
check("and once only", $log, [])

# Holding the player: no moving, no menu, while any script says so.
class Game_Player; def movable?; true; end; end
class Scene_Map; attr_reader :menu_calling; def update_call_menu; @menu_calling = true; end; end
$held = false
MGQ_MpHooks.hold_player("one") { $held }
MGQ_MpHooks.hold_player("two") { raise "boom" }
map = Scene_Map.new
map.update_call_menu
check("a player nobody holds moves and opens the menu", [Game_Player.new.movable?, map.menu_calling], [true, true])
$held = true
map.update_call_menu
check("a held player stands still and opens no menu", [Game_Player.new.movable?, map.menu_calling], [false, false])
check("a failing hold is logged once and holds nobody", $log.grep(/two failed holding the player: RuntimeError: boom/).size, 1)
check("who holds the player is logged once when it changes", $log.grep(/player held by one/).size, 1)
$held = false
Game_Player.new.movable?
check("and the release too", $log.grep(/player free again, released by one/).size, 1)
