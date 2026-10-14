#----------------------------------------------------------------
#  compat.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# What Ruby 1.9.2, which RGSS3 runs, has and Ruby 3.3 dropped, so the game's scripts load unchanged.

# The integer classes Ruby 2.4 merged into Integer and Ruby 3.2 removed.
Fixnum = Integer unless Object.const_defined?(:Fixnum)
Bignum = Integer unless Object.const_defined?(:Bignum)

# Restores Object#=~, which Ruby 3.2 removed; it never matched anything.
class Object
  # Matches nothing, as Object#=~ did.
  #
  # @param _other [Object] The pattern.
  # @return [nil]
  def =~(_other)
    nil
  end

  # Does nothing, as tainting is gone since Ruby 3.2.
  #
  # @return [Object] The object itself.
  def taint
    self
  end

  # Does nothing, as tainting is gone since Ruby 3.2.
  #
  # @return [Object] The object itself.
  def untaint
    self
  end

  # Tells that no object is tainted, as tainting is gone since Ruby 3.2.
  #
  # @return [Boolean] Always false.
  def tainted?
    false
  end
end

class << File
  # Restores File.exists?, which Ruby 3.2 removed.
  #
  # @param path [String] The path.
  # @return [Boolean] Whether it exists.
  def exists?(path)
    exist?(path)
  end
end

class << Dir
  # Restores Dir.exists?, which Ruby 3.2 removed.
  #
  # @param path [String] The path.
  # @return [Boolean] Whether it is a folder.
  def exists?(path)
    exist?(path)
  end
end

# Ruby 1.9.2's define_method: the method is public even after a "private" in the class body,
# where later Rubies make it private. The game's damage formulas read a.atk through such methods
# (DamageEvalBattler); private, they fall through to method_missing and skip the skill's stat
# additions. Once this loads, every define_method is public, as in 1.9.2: the call now comes from
# here, where no private is in effect. The libraries the server uses load before it.
module RgssDefineMethod
  # Defines the method, public.
  #
  # @param name [Symbol] The method's name.
  # @return [Symbol] The name.
  def define_method(name, *args, &block)
    super.tap { public(name) }
  end
end
Module.prepend(RgssDefineMethod)

# Ruby 1.9.2's shuffle and sample. Both Rubies draw the same numbers from a seed, but later ones
# turn them into picks differently, so the game's random targets and drops would differ from
# Game.exe's for the same seed. These pick as 1.9.2's array.c does, from Kernel#rand's floats.
class Array
  # Shuffles the array in place.
  #
  # @return [Array] The array.
  def shuffle!(*)
    i = size
    while i.positive?
      j = rgss_rand_upto(i)
      i -= 1
      self[i], self[j] = self[j], self[i]
    end
    self
  end

  # A shuffled copy.
  #
  # @return [Array] The copy.
  def shuffle(*)
    dup.shuffle!
  end

  # One element at random, or count distinct ones.
  #
  # @param count [Integer, nil] How many; nil for one element itself.
  # @return [Object, Array] The element, or the elements.
  def sample(count = nil, *)
    length = size
    if count.nil?
      return nil if length.zero?

      return self[length == 1 ? 0 : rgss_rand_upto(length)]
    end
    raise ArgumentError, "negative sample number" if count.negative?

    count = [count, length].min
    case count
    when 0 then []
    when 1 then [self[rgss_rand_upto(length)]]
    when 2
      i = rgss_rand_upto(length)
      j = rgss_rand_upto(length - 1)
      j += 1 if j >= i
      [self[i], self[j]]
    when 3
      i = rgss_rand_upto(length)
      j = rgss_rand_upto(length - 1)
      k = rgss_rand_upto(length - 2)
      low, high = j, i
      if j >= i
        low = i
        high = (j += 1)
      end
      k += 1 if k >= low && (k += 1) >= high
      [self[i], self[j], self[k]]
    else
      count < 10 ? rgss_sample_sorted(count, length) : rgss_sample_swapped(count, length)
    end
  end

  private

  # A whole number from 0 below a bound, as 1.9.2's RAND_UPTO makes it from a float.
  #
  # @param bound [Integer] The bound.
  # @return [Integer] The number.
  def rgss_rand_upto(bound)
    (Kernel.rand * bound).to_i
  end

  # 1.9.2's sample of 4 to 9 elements: each index drawn from those left, kept in order.
  #
  # @param count [Integer] How many.
  # @param length [Integer] The array's size.
  # @return [Array] The elements.
  def rgss_sample_sorted(count, length)
    sorted = [rgss_rand_upto(length)]
    picked = [sorted[0]]
    (1...count).each do
      length -= 1
      k = rgss_rand_upto(length)
      at = sorted.index { |taken| k < taken ? true : (k += 1; false) } || sorted.size
      sorted.insert(at, k)
      picked << k
    end
    picked.map { |index| self[index] }
  end

  # 1.9.2's sample of 10 or more elements: a partial shuffle of a copy.
  #
  # @param count [Integer] How many.
  # @param length [Integer] The array's size.
  # @return [Array] The elements.
  def rgss_sample_swapped(count, length)
    copy = dup
    count.times do |i|
      j = rgss_rand_upto(length - i) + i
      copy[i], copy[j] = copy[j], copy[i]
    end
    copy.first(count)
  end
end

class Hash
  # Restores Hash#index, which Ruby 3.0 removed.
  #
  # @param value [Object] The value.
  # @return [Object, nil] The first key holding it.
  def index(value)
    key(value)
  end
end
