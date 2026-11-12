#----------------------------------------------------------------
#  hooks_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-12: Checked skip, its nesting with around and its refusal of a method with arguments
#      Paulinchen  2026-10-31: Checked that the game's own method of a hooked one runs without the hooks
#      Paulinchen  2026-10-30: Checked that the hooks stand aside while the mod sleeps
#      Paulinchen  2026-10-12: Checked around with other arguments
#      Paulinchen  2026-10-08: Checked the hook report and a wrap of a method defined later
#                            - Checked that the hooks are logged as one line per script, once
#      Paulinchen  2026-10-07: Checked that who holds the player is logged when it changes
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked around and holding the player
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Covers core_hooks.rbx: the blocks run on the object with the method's arguments, in the order
# nested wraps would run them, the method's result and visibility stay, a failing block is logged
# once and keeps the others running, a second registration replaces the first, and the game's own
# method of a hooked one runs without any hook.

require_relative "support"

$calls = []
$log = []

# Stands in for the loader's log, keeping its lines in $log.
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
# A game class whose method takes two arguments.
class Scene_Arguments
  def add(a, b); a + b; end
end
MGQ_MpHooks.around(Scene_Arguments, :add, "args") { |_scene, args, original| args[0] > 5 ? original.call(args[0] * 10, args[1]) : original.call }
check("a wrap runs the original with arguments of its own, or with the method's", [Scene_Arguments.new.add(9, 1), Scene_Arguments.new.add(2, 1)], [91, 3])
$log.clear
MGQ_MpHooks.report
check("the hooks are logged as one line per script with how many methods it follows and wraps, not one per method",
      $log.grep(/: follows \d+, wraps \d+ game method\(s\): /).size == $log.size && $log.grep(/hooks: one: follows 0, wraps 2 game method/).size, 1)
check("a method followed before and after counts once, and the line names it",
      $log.grep(/hooks: first: follows 1, wraps 0 game method\(s\): follows Scene_Test#update\z/).size, 1)
check("the line names the methods a script wraps", $log.grep(/hooks: one: .*: wraps Scene_Around#double, Scene_Around#hidden\z/).size, 1)
$log.clear
MGQ_MpHooks.report
check("and once only", $log, [])

# A method the game defines only later, as a plugin does: the first try fails and keeps nothing.
# A game class whose method is defined only after the first wrap.
class Scene_Late; end
failed = begin
  MGQ_MpHooks.around(Scene_Late, :value, "late") { |_scene, _args, original| original.call + 1 }
  false
rescue NameError
  true
end
class Scene_Late; def value; 1; end; end
MGQ_MpHooks.around(Scene_Late, :value, "late") { |_scene, _args, original| original.call + 1 }
check("a wrap of a method not defined yet fails, and the next try wraps it", [failed, Scene_Late.new.value], [true, 2])
$log.clear
MGQ_MpHooks.report
check("and counts it once", $log.grep(/hooks: late: follows 0, wraps 1 game method\(s\): wraps Scene_Late#value\z/).size, 1)

# A hook that only skips a method without arguments, such as an event's own movement.
# A game class whose method a hook skips and wraps.
class Scene_Skip
  def step; $calls << :step; :stepped; end
  def walk(steps); steps; end
end
$skipping = false
MGQ_MpHooks.skip(Scene_Skip, :step, "first", :stood) { |_scene| $skipping }
MGQ_MpHooks.around(Scene_Skip, :step, "second") { |_scene, _args, original| [original.call] }
$calls.clear
ran = Scene_Skip.new.step
$skipping = true
check("skip runs the game's method while its block says no and returns the fallback while it says yes, inside an around registered later",
      [ran, Scene_Skip.new.step, $calls], [[:stepped], [:stood], [:step]])
MGQ_MpHooks.skip(Scene_Skip, :step, "first", :stood) { |_scene| !$skipping }
check("a script registering again replaces its block, and the game's own method stays plain",
      [Scene_Skip.new.step, Scene_Skip.new.send(MGQ_MpHooks.plain(Scene_Skip, :step))], [[:stepped], :stepped])
MGQ_MpHooks.skip(Scene_Skip, :walk, "first") { true }
check("a method with arguments is refused and logged",
      [Scene_Skip.new.walk(3), $log.grep(/first could not skip Scene_Skip#walk: it takes arguments/).size], [3, 1])

# Holding the player: no moving, no menu, while any script says so.
# Stands in for the map's player, always movable.
class Game_Player; def movable?; true; end; end
# Stands in for the map scene, telling whether the menu was called.
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

# Asleep: the player entered the game without the mod, whose title part hooked the game already.
$calls.clear
$asleep = true
MGQ_MpHooks.sleep_while { $asleep }
check("while asleep a before and after hook, an around and a skip stand aside, the methods run as the game's",
      [Scene_Test.new.update(2), Scene_Late.new.value, Scene_Skip.new.step, $calls], [4, 1, :stepped, [[:update, 2], :step]])
$asleep = false
$calls.clear
check("awake they run again", [Scene_Test.new.update(2), Scene_Late.new.value, $calls.size], [4, 2, 5])

# The game's own method of a hooked one, which the story replay runs without the hooks.
$calls.clear
plain = [Scene_Test.new.send(MGQ_MpHooks.plain(Scene_Test, :update), 3), Scene_Around.new.send(MGQ_MpHooks.plain(Scene_Around, :double), 2)]
check("the game's own method of a followed and of a wrapped method runs without their hooks", [plain, $calls], [[6, 4], [[:update, 3]]])
check("a method no hook wraps is its own plain method, and the hooked methods of a class are listed",
      [MGQ_MpHooks.plain(Scene_Test, :to_s), MGQ_MpHooks.hooked(Scene_Around).sort], [:to_s, [:double, :hidden]])
