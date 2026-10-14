#----------------------------------------------------------------
#  compat_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Tests of compat.rb: Ruby 1.9.2's shuffle and sample against picks recorded in Game.exe,
# define_method's visibility for the game's code, and what Ruby 3.3 dropped.

require_relative "support"
require_relative File.join(LIB_DIR, "compat")

# shuffle and sample pick as Game.exe's Ruby 1.9.2 does: the cases recorded in the game itself.
recorded = File.read(File.join(FIXTURES_DIR, "shuffle_sample_1_9_2.txt"), encoding: "UTF-8").lines.map(&:chomp)
ours = eval(File.read(File.join(FIXTURES_DIR, "shuffle_sample_cases.rb"), encoding: "UTF-8")).lines.map(&:chomp)
check("every shuffle and sample case was recorded", ours.size, recorded.size)
differing = recorded.each_index.reject { |i| recorded[i] == ours[i] }
check("shuffle and sample pick as in Game.exe in all #{recorded.size} cases", differing.first(3).map { |i| ours[i] }, [])

# The numbers they draw stay those of Kernel#rand, so a seed gives the same rand after them.
srand(5)
[1, 2, 3].shuffle
after_shuffle = rand
srand(5)
rand
rand
rand
check("a shuffle of 3 draws 3 numbers, as 1.9.2's does", after_shuffle, rand)
check("a sample of an empty array is nil", [].sample, nil)
check("a sample of 0 is empty", [1, 2].sample(0), [])
check("a sample of more than the array holds takes them all", [1, 2, 3].sample(10).sort, [1, 2, 3])
check("a negative sample is refused", raised { [1].sample(-1) }.class, ArgumentError)

# define_method keeps a method public after private, as 1.9.2 does, also in a loop over names, as
# the game's DamageEvalBattler defines its stats.
eval(<<~RUBY, TOPLEVEL_BINDING, "258 15/eval_battler", 1)
  class GameWrapper < BasicObject
    private

    [:atk, :mat].each { |name| define_method(name) { 1 } }
  end
RUBY
check("a method defined after private stays public", GameWrapper.public_method_defined?(:atk), true)
check("so do the others of the loop", GameWrapper.public_method_defined?(:mat), true)
check("an ordinary def after private stays private", Class.new { private; def hidden; end }.private_method_defined?(:hidden), true)

# What Ruby 1.9.2 had and later Rubies dropped.
check("Fixnum is Integer", Fixnum, Integer)
check("Object#=~ matches nothing", Object.new =~ /x/, nil)
check("Hash#index finds a key by its value", { a: 1, b: 2 }.index(2), :b)
check("File.exists? is back", File.exists?(__FILE__), true)
check("taint does nothing", "x".taint, "x")
