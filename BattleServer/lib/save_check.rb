#----------------------------------------------------------------
#  save_check.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# Walks a Marshal stream without building anything and names every class and module it would
# make, so a save from a player can be refused before Marshal.load runs code of Ruby's own
# classes, such as the gadgets of rubygems and ERB.
class SaveCheck
  # Raised for a stream that is not Marshal or names something the server does not admit.
  class Refused < StandardError; end

  # The Marshal version every stream starts with.
  VERSION = "\x04\x08".b.freeze

  # How deep objects may nest; the game's saves stay far below.
  MAX_DEPTH = 500

  # Ruby's own classes a save may hold: plain values without code of their own.
  CORE = %w[Object String Array Hash Range Float Integer Symbol Time Regexp Rational Complex].freeze

  # The modules and classes defined before the game's scripts load: Ruby's own and the
  # libraries the server uses. Anything else a save names must come from the game.
  @before = nil

  class << self
    # Notes Ruby's own modules and classes; called before the game's scripts load.
    def snapshot
      @before = ObjectSpace.each_object(Module).to_a
    end

    # The modules and classes the game's scripts and the RGSS stand-ins define, by name.
    #
    # @return [Set<String>] Their names.
    def game_names
      @game_names ||= begin
        raise "SaveCheck.snapshot must run before the game's scripts" unless @before

        before = @before.to_h { |mod| [mod, true] }
        # Some of the game's modules define a name method of their own.
        name_of = Module.instance_method(:name)
        ObjectSpace.each_object(Module).reject { |mod| before[mod] }.filter_map { |mod| name_of.bind_call(mod) }.to_set
      end
    end
  end

  # The class names the stream names, with how often.
  attr_reader :names

  # Starts a check of a byte stream.
  #
  # @param bytes [String] One or more Marshal streams one after another, as a save file is.
  def initialize(bytes)
    @bytes = bytes.b
    @pos = 0
    @names = Hash.new(0)
  end

  # Walks every stream in the bytes and refuses one that names a class the server does not
  # admit or uses a kind of entry no save needs.
  #
  # @param admitted [#include?] The class names admitted besides CORE.
  # @return [SaveCheck] The check, with the names it met.
  def check(admitted)
    @admitted = admitted
    until @pos >= @bytes.bytesize
      refuse("not a Marshal stream") unless @bytes.byteslice(@pos, 2) == VERSION
      @pos += 2
      @symbols = []
      entry(0)
    end
    self
  end

  private

  # Reads one entry and everything inside it.
  #
  # @param depth [Integer] How deep it nests.
  def entry(depth)
    refuse("nested too deep") if depth > MAX_DEPTH
    type = byte.chr
    case type
    when "0", "T", "F" then nil
    when "i" then long
    when ":" then @symbols << bytes
    when ";" then symbol_at(long)
    when "@" then long
    when "I"
      entry(depth + 1)
      long.times { symbol; entry(depth + 1) }
    when "e"
      admit(symbol, "extended by")
      entry(depth + 1)
    when "[" then long.times { entry(depth + 1) }
    when "l"
      byte
      # The length comes first: "@pos += long * 2" would add it to the position before it.
      shorts = long
      refuse("a length past the end") if shorts.negative? || @pos + shorts * 2 > @bytes.bytesize
      @pos += shorts * 2
    when "c", "m", "M" then admit(bytes, "class reference")
    when "f", '"' then bytes
    when "/"
      bytes
      byte
    when "{", "}"
      (long * 2).times { entry(depth + 1) }
      entry(depth + 1) if type == "}"
    when "S", "o"
      admit(symbol, type == "S" ? "struct" : "object")
      long.times { symbol; entry(depth + 1) }
    when "C"
      admit(symbol, "subclass")
      entry(depth + 1)
    when "u"
      admit(symbol, "_load")
      bytes
    when "U"
      admit(symbol, "marshal_load")
      entry(depth + 1)
    else
      refuse("an entry of kind #{type.inspect}, which no save holds")
    end
  end

  # Refuses a class the server does not admit, and counts the others.
  #
  # @param name [String] The class's name.
  # @param kind [String] What the stream does with it.
  def admit(name, kind)
    name = name.dup.force_encoding("UTF-8")
    refuse("#{kind} of #{name}, which is not the game's") unless CORE.include?(name) || @admitted.include?(name)
    @names[name] += 1
  end

  # Reads a symbol or a link to an earlier one.
  #
  # @return [String] The symbol's name.
  def symbol
    case byte.chr
    when ":" then bytes.tap { |name| @symbols << name }
    when ";" then symbol_at(long)
    else refuse("a symbol where one belongs")
    end
  end

  # An earlier symbol by its index.
  #
  # @param index [Integer] The index.
  # @return [String] The symbol's name.
  def symbol_at(index)
    @symbols[index] || refuse("a link to symbol #{index}, which does not exist")
  end

  # Reads a length and that many bytes.
  #
  # @return [String] The bytes.
  def bytes
    length = long
    refuse("a length past the end") if length.negative? || @pos + length > @bytes.bytesize
    @bytes.byteslice(@pos, length).tap { @pos += length }
  end

  # Reads one of Marshal's packed integers.
  #
  # @return [Integer] The integer.
  def long
    first = byte
    first -= 256 if first > 127
    return 0 if first.zero?
    return first - 5 if first > 4
    return first + 5 if first < -4

    count = first.abs
    value = 0
    count.times { |i| value |= byte << (8 * i) }
    first.negative? ? value - (1 << (8 * count)) : value
  end

  # Reads one byte.
  #
  # @return [Integer] The byte.
  def byte
    refuse("the stream ends early") if @pos >= @bytes.bytesize
    @bytes.getbyte(@pos).tap { @pos += 1 }
  end

  # Refuses the save.
  #
  # @param reason [String] Why.
  def refuse(reason)
    raise Refused, "the save was refused: #{reason} (at byte #{@pos})"
  end
end
