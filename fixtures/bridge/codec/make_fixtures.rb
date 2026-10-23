#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Wrote Integer Hash keys as plain values and an Array key as a refused one
#                            - Created
#
#----------------------------------------------------------------

# Writes the bridge codec's golden Marshal dumps next to this file, one <case>.marshal per case,
# which MGQOnline.Bridge.Tests reads. Run it again only when a case changes:
#
#   ruby fixtures/bridge/codec/make_fixtures.rb
#
# Ruby 3.3 on Windows: its 32-bit long writes integers outside the 31-bit Fixnum range of RGSS3's
# Ruby 1.9.2 as Bignums, as the bridge's writer does. A 64-bit long writes them as Fixnums.

if Marshal.dump(2**30)[2] != "l"
  abort "Run this on Ruby for Windows, whose Marshal writes 2**30 as a Bignum."
end

# Stand-ins for the game's classes, only so their dumps carry the real class names.
module RPG
  # An item of the database.
  class Item
    # Creates the item.
    # @param id [Integer] the item's id.
    # @param name [String] the item's name.
    def initialize(id, name)
      @id = id
      @name = name
    end
  end

  # A map event with its pages.
  class Event
    # Creates the event.
    # @param pages [Array<RPG::Event::Page>] the pages.
    def initialize(pages)
      @id = 7
      @name = "Chest"
      @x = 3
      @y = 4
      @pages = pages
    end

    # One page of an event.
    class Page
      # Creates the page.
      # @param list [Array<RPG::EventCommand>] the commands.
      def initialize(list)
        @trigger = 0
        @move_speed = 0.5
        @graphic = { :mode => :auto }
        @list = list
      end
    end
  end

  # One command of an event page.
  class EventCommand
    # Creates the command.
    # @param code [Integer] the command's code.
    # @param parameters [Array] the command's parameters.
    def initialize(code, parameters)
      @code = code
      @indent = 0
      @parameters = parameters
    end
  end
end

# The game's Table, which dumps itself as bytes.
class Table
  # Creates the table.
  # @param values [Array<Integer>] the numbers of a one-dimensional table.
  def initialize(values)
    @values = values
  end

  # Dumps the table as RGSS3 does.
  # @param _level [Integer] unused.
  # @return [String] the dimensions, sizes, count and the numbers, as RGSS3 writes them.
  def _dump(_level)
    [1, @values.size, 1, 1, @values.size].pack("l<5") + @values.pack("s<*")
  end
end

# A point, for a Struct in game data.
Point = Struct.new(:x, :y)

shared = "same"
holds_itself = []
holds_itself << holds_itself
with_default = Hash.new(0)
with_default["a"] = 1
page = RPG::Event::Page.new([RPG::EventCommand.new(101, ["face", 0]), RPG::EventCommand.new(0, [])])

PLAIN = {
  "scalars" => [nil, true, false],
  "integers" => [0, 1, -1, 122, 123, -123, -124, 255, 256, -256, -257, 65535, 65536, -65536, -65537, 2**24],
  "fixnum_borders" => [2**30 - 1, 2**30, -(2**30), -(2**30) - 1],
  "bignums" => [2**31, -(2**31), 2**32, 2**62, 2**64, -(2**64) - 1, 2**100],
  "strings" => ["Luka", "ルカ é", "", 42.to_s, "\x00\xFF raw".b],
  "nested" => { "ok" => true, "value" => { "seat" => 2, "names" => ["Alice", "Ilias"], "empty" => {}, "list" => [[1, [2, []]]] } },
  "repeated_keys" => [{ "id" => 1, "name" => "a" }, { "id" => 2, "name" => "b" }],
  "integer_keys" => { 1 => "one", "id" => 2, 2**31 => "big" },
}

OTHERS = {
  "shared_value" => [shared, shared],
  "object" => RPG::Item.new(1, "Herb"),
  "symbol" => [:seat],
  "float" => [1.5],
  "user_data" => Table.new([1, 2]),
  "shift_jis" => "ルカ".encode("Shift_JIS"),
  "array_key" => { [1] => "one" },
  "holds_itself" => holds_itself,
  "hash_default" => with_default,
  "game_data" => [RPG::Event.new([page, page]), Point.new(1, 2), "ルカ".encode("Shift_JIS")],
}

PLAIN.each do |name, value|
  dump = Marshal.dump(value)
  abort "#{name} does not load back the same" unless Marshal.load(dump) == value
  File.binwrite(File.join(__dir__, "#{name}.marshal"), dump)
end

OTHERS.each do |name, value|
  File.binwrite(File.join(__dir__, "#{name}.marshal"), Marshal.dump(value))
end

puts "Wrote #{PLAIN.size + OTHERS.size} fixtures."
