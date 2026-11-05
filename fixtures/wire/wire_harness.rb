#----------------------------------------------------------------
#  wire_harness.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Left loading the codec to its users, the old script's for the cases and the scripts' values for the check
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Runs battles_sync_wire.rbx outside the game for the battle line codec's golden cases: stand-ins
# for the game classes it writes and reads, the game facts the cases share, and the description of
# a value both the fixtures and MGQOnline.Game.Tests use. make_fixtures.rb writes the cases with it
# from the script that still kept the codec, GameScript/Tests/wire_fixtures_test.rb checks the
# values the scripts hand over and take back against them. Each loads its script, then calls
# WireHarness.prepare.
#
# A value's description is JSON: nil, true and false as themselves, {"i" => "42"},
# {"f" => <the double's 16 hex digits>}, {"sym" => text}, {"s" => text}, {"ref" => "a0"},
# {"x" => kind or nil}, {"k" => id} (and "t", "z", "w", "a"), {"g" => entry or nil},
# {"c" => [4 doubles]}, {"n" => [4 doubles]}, an Array, and {"result" => [[field, value], ...]}.

require "json"

# What the reading game knows in every decode case.
WIRE_GAME = {
  # The symbols the game has; two of them may never come from the other game.
  "symbols" => %w(count chain_action hp_damage mp_damage critical missed battler used added_states) + ["a" * 40, "a" * 41, "a-b"],
  # The fields of the game's action results.
  "result_fields" => %w(used missed critical hp_damage mp_damage added_states battler),
  # The size of each database table, its entry 0 counted; the armors are missing.
  "tables" => { "k" => 20, "t" => 10, "z" => 5, "w" => 3 },
}.freeze

# The script's log and its recorder, which the codec calls.
module MGQ_MpBattlesSync
  # Keeps what the codec logs.
  #
  # @param _key [Object] The log's key.
  # @param text [String] The line.
  def self.log_once(_key, text)
    (@logged ||= []) << text
  end

  # Names battlers by the reference they hold.
  module Recorder
    # Gives a battler's reference.
    #
    # @param battler [Game_Battler] The battler.
    # @return [String] Its reference.
    def self.ref(battler)
      battler.ref
    end
  end
end

# A battler of the battle, by its reference.
class Game_Battler
  # @return [String] The reference, such as "a0".
  attr_reader :ref

  # Creates the battler.
  #
  # @param ref [String] The reference.
  def initialize(ref)
    @ref = ref
  end
end

# An action of a battler, by its kind.
class Game_Action
  # @return [Symbol, nil] The kind.
  attr_reader :symbol

  # Creates the action.
  #
  # @param symbol [Symbol, nil] The kind.
  def initialize(symbol)
    @symbol = symbol
  end
end

# The game's action result, which notes every field the codec sets on it.
class Game_ActionResult
  # The fields each set field of a result, by the result.
  SETS = {}.compare_by_identity

  # Creates the result with the fields of WIRE_GAME, which the codec reads as this game's.
  #
  # @param _battler [Game_Battler, nil] The battler.
  def initialize(_battler)
    WIRE_GAME["result_fields"].each { |name| Object.instance_method(:instance_variable_set).bind_call(self, "@#{name}", nil) }
  end

  # Sets a field and notes it.
  #
  # @param name [Symbol] The field.
  # @param value [Object] Its value.
  # @return [Object] The value.
  def instance_variable_set(name, value)
    (SETS[self] ||= []) << [name.to_s.delete("@"), value]
    super
  end
end

# The game's equipped or stolen item.
class Game_BaseItem
  # @return [RPG::BaseItem, nil] The entry it holds.
  attr_accessor :object
end

# The game's database entries, by their ids.
module RPG
  # An entry of the database.
  class BaseItem
    # @return [Integer] The id.
    attr_reader :id

    # Creates the entry.
    #
    # @param id [Integer] The id.
    def initialize(id)
      @id = id
    end
  end

  # A skill.
  class Skill < BaseItem; end

  # An item.
  class Item < BaseItem; end

  # A state.
  class State < BaseItem; end

  # A weapon.
  class Weapon < BaseItem; end

  # An armor.
  class Armor < BaseItem; end
end

# RGSS's Color, keeping its channels as given.
class Color
  # @return [Float] The channels.
  attr_reader :red, :green, :blue, :alpha

  # Creates the color.
  #
  # @param red [Numeric] The red channel.
  # @param green [Numeric] The green channel.
  # @param blue [Numeric] The blue channel.
  # @param alpha [Numeric] The opacity.
  def initialize(red, green, blue, alpha)
    @red, @green, @blue, @alpha = red, green, blue, alpha
  end
end

# RGSS's Tone, keeping its channels as given.
class Tone
  # @return [Float] The channels.
  attr_reader :red, :green, :blue, :gray

  # Creates the tone.
  #
  # @param red [Numeric] The red channel.
  # @param green [Numeric] The green channel.
  # @param blue [Numeric] The blue channel.
  # @param gray [Numeric] The gray level.
  def initialize(red, green, blue, gray)
    @red, @green, @blue, @gray = red, green, blue, gray
  end
end

# The database classes by their token kinds.
WIRE_ENTRIES = { "k" => RPG::Skill, "t" => RPG::Item, "z" => RPG::State, "w" => RPG::Weapon, "a" => RPG::Armor }.freeze

$data_skills, $data_items, $data_states, $data_weapons, $data_armors = WIRE_ENTRIES.map do |kind, entry|
  size = WIRE_GAME["tables"][kind]
  size && [nil] + (1...size).map { |id| entry.new(id) }
end

# Builds the golden cases' values and describes what the codec read.
module WireHarness
  # Gives the loaded script the symbols of WIRE_GAME as the game's own.
  def self.prepare
    MGQ_MpBattlesSync::Wire.instance_variable_set(:@symbols, WIRE_GAME["symbols"].each_with_object({}) { |text, all| all[text] = text.to_sym })
  end

  # Gives a case's line.
  #
  # @param entry [Hash] The case: "line" or "line_hex", repeated "repeat" times.
  # @return [String] The line, marked UTF-8.
  def self.line_of(entry)
    line = entry["line_hex"] ? [entry["line_hex"]].pack("H*") : entry["line"].dup
    (line * (entry["repeat"] || 1)).force_encoding("UTF-8")
  end

  # Makes the value a description stands for.
  #
  # @param value [Object] The description.
  # @return [Object] The value.
  def self.build(value)
    return value.map { |item| build(item) } if value.is_a?(Array)
    return value unless value.is_a?(Hash)

    kind, content = value.first
    case kind
    when "i" then Integer(content)
    when "f" then double(content)
    when "sym" then content.to_sym
    when "s" then content
    when "ref" then Game_Battler.new(content)
    when "x" then Game_Action.new(content && content.to_sym)
    when "g" then Game_BaseItem.new.tap { |item| item.object = build(content) }
    when "c" then Color.new(*content.map { |channel| double(channel) })
    when "n" then Tone.new(*content.map { |channel| double(channel) })
    when "result" then result(content)
    else WIRE_ENTRIES.fetch(kind).new(content)
    end
  end

  # Makes an action result of described fields, in their order.
  #
  # @param fields [Array<Array>] Each field's name and described value.
  # @return [Game_ActionResult] The result.
  def self.result(fields)
    result = Game_ActionResult.allocate
    fields.each { |name, field| Object.instance_method(:instance_variable_set).bind_call(result, "@#{name}", build(field)) }
    result
  end

  # Describes a value the codec read.
  #
  # @param value [Object] The value.
  # @return [Object] Its description.
  def self.describe(value)
    case value
    when nil, true, false then value
    when Integer then { "i" => value.to_s }
    when Float then { "f" => bits(value) }
    when Symbol then { "sym" => value.to_s }
    when String then { "s" => value }
    when Game_Battler then { "ref" => value.ref }
    when MGQ_MpBattlesSync::Wire::ActionKind then { "x" => value.symbol && value.symbol.to_s }
    when Game_BaseItem then { "g" => describe(value.object) }
    when RPG::BaseItem then { WIRE_ENTRIES.key(value.class) => value.id }
    when Color then { "c" => [value.red, value.green, value.blue, value.alpha].map { |channel| bits(channel) } }
    when Tone then { "n" => [value.red, value.green, value.blue, value.gray].map { |channel| bits(channel) } }
    when Array then value.map { |item| describe(item) }
    when Game_ActionResult then { "result" => (Game_ActionResult::SETS[value] || []).map { |name, field| [name, describe(field)] } }
    else raise ArgumentError, "the codec read a #{value.class}, which has no description"
    end
  end

  # Gives a double's bits.
  #
  # @param value [Float] The double.
  # @return [String] Its 16 hex digits, big-endian.
  def self.bits(value)
    [value].pack("G").unpack1("H*")
  end

  # Makes a double of its bits.
  #
  # @param bits [String] The 16 hex digits, big-endian.
  # @return [Float] The double.
  def self.double(bits)
    [bits].pack("H*").unpack1("G")
  end
end
