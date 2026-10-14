#----------------------------------------------------------------
#  shuffle_sample_cases.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# Draws shuffle and sample results for many seeds and sizes, in a format both Rubies print alike.
lines = []
(1..25).each do |seed|
  [1, 2, 3, 4, 5, 8, 10, 11, 12, 17].each do |size|
    array = (1..size).to_a
    srand(seed); lines << "s#{seed} n#{size} shuffle #{array.shuffle.join(",")}"
    srand(seed); copy = array.dup; copy.shuffle!; lines << "s#{seed} n#{size} shuffle! #{copy.join(",")}"
    srand(seed); lines << "s#{seed} n#{size} sample #{array.sample}"
    [0, 1, 2, 3, 4, 5, 9, 10, 11, 20].each do |count|
      srand(seed); lines << "s#{seed} n#{size} sample(#{count}) #{array.sample(count).join(",")}"
    end
    srand(seed); array.sample; array.shuffle; lines << "s#{seed} n#{size} after #{rand}"
  end
end
srand(4); lines << "empty sample #{[].sample.inspect}"
lines.join("\n")
