#----------------------------------------------------------------
#  hooks_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Covers mp_hooks.rbx: the blocks run on the object with the method's arguments, in the order nested
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

load_script "mp_hooks"

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
