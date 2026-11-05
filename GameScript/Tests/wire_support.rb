#----------------------------------------------------------------
#  wire_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# The DLL's battle line codec (MGQOnline.Game's WireWriter and WireReader, behind WireTopics) for the
# script tests: WireStandIn writes the plain values the scripts hand over as a line and reads a line
# back to them, as the DLL does; wire_fixtures_test.rb holds it against the golden cases of
# fixtures/wire, which battles_sync_wire.rbx wrote and read before the codec moved to C#.

# Writes and reads battle lines of plain values (see MGQ_MpBattlesSync::Wire.plain).
module WireStandIn
  # The escapes of a text or symbol.
  ESCAPES = { "\\" => "\\\\", "\t" => "\\t", "\n" => "\\n", "\r" => "\\r" }.freeze

  # The escapes turned back.
  UNESCAPES = ESCAPES.invert.freeze

  # The text of a symbol another game may send.
  SYMBOL_PATTERN = /\A\w{1,40}\z/

  # The deepest nesting a line may have.
  MAX_DEPTH = 8

  # The longest line read.
  MAX_LINE_BYTES = 512 * 1024

  # The token of each kind of the database's entries.
  ENTRY_TOKENS = { "skill" => "k", "item" => "t", "state" => "z", "weapon" => "w", "armor" => "a" }.freeze

  # The table size the DLL reads every entry's id against, as WireGame.Any: the script finds the
  # entry in its own table.
  ANY_TABLE = 2**31 - 1

  # Writes values as a line.
  #
  # @param values [Array] Plain values.
  # @return [String] The line.
  def self.line(values)
    values.flat_map { |value| tokens(value) }.join("\t")
  end

  # Reads a line as the DLL reads it for the scripts, taking every symbol, action result field and
  # entry, which the script finds among its own game's.
  #
  # @param line [String] The line.
  # @return [Array, nil] The plain values, nil when the line does not read.
  def self.parse(line)
    text = line.to_s.dup.force_encoding("UTF-8")
    return nil if text.bytesize > MAX_LINE_BYTES || !text.valid_encoding?

    stack = [[]]
    text.split("\t").each do |token|
      case token
      when "[", "{"
        return nil if stack.size > MAX_DEPTH

        stack.push([])
      when "]", "}"
        return nil if stack.size < 2

        inner = stack.pop
        stack.last << (token == "]" ? inner : result(inner))
      else stack.last << value(token[0, 1], token[1..-1].to_s)
      end
    end
    stack.size == 1 ? stack[0] : nil
  end

  # Turns a plain value into tokens.
  #
  # @param value [Object] The value.
  # @return [Array<String>] Its tokens.
  def self.tokens(value)
    case value
    when nil then ["~"]
    when true then ["+"]
    when false then ["-"]
    when Integer then ["i#{value}"]
    when String then ["s#{escape(value)}"]
    when Array then ["["] + value.flat_map { |item| tokens(item) } + ["]"]
    when Hash then kinded_tokens(value.keys[0], value.values[0])
    else raise ArgumentError, "#{value.class} is no plain value of a line"
    end
  end

  # Turns a value of one kind into tokens.
  #
  # @param kind [String] The kind.
  # @param content [Object] What it holds.
  # @return [Array<String>] Its tokens.
  def self.kinded_tokens(kind, content)
    return ["#{ENTRY_TOKENS[kind]}#{content}"] if ENTRY_TOKENS.key?(kind)

    case kind
    when "float" then ["f#{content}"]
    when "symbol" then [":#{escape(content)}"]
    when "battler" then ["@#{content}"]
    when "action" then ["x#{content}"]
    when "base_item" then ["g#{tokens(content)[0]}"]
    when "color" then ["c#{content.map { |channel| number(channel).to_i }.join(',')}"]
    when "tone" then ["n#{content.map { |channel| number(channel).to_i }.join(',')}"]
    when "result" then ["{"] + content.flat_map { |name, field| [":#{escape(name)}"] + tokens(field) } + ["}"]
    else raise ArgumentError, "a line carries no value of the kind #{kind}"
    end
  end

  # Reads a value back from a token.
  #
  # @param kind [String] The token's first character.
  # @param rest [String] The rest.
  # @return [Object] The plain value, nil for anything unknown.
  def self.value(kind, rest)
    return entry(ENTRY_TOKENS.key(kind), rest) if ENTRY_TOKENS.value?(kind)

    case kind
    when "+" then true
    when "-" then false
    when "i" then rest.to_i
    when "f" then { "float" => rest.to_f.to_s }
    when ":" then (text = symbol(unescape(rest))) && { "symbol" => text }
    when "s" then unescape(rest)
    when "@" then { "battler" => rest }
    when "x" then { "action" => symbol(rest) }
    when "g" then (item = ENTRY_TOKENS.value?(rest[0, 1]) && entry(ENTRY_TOKENS.key(rest[0, 1]), rest[1..-1].to_s)) ? { "base_item" => item } : nil
    when "c" then { "color" => channels(rest) }
    when "n" then { "tone" => channels(rest) }
    end
  end

  # Makes an action result of its names and values, a name that is no symbol left out.
  #
  # @param fields [Array] Names and values, taking turns.
  # @return [Hash] The result.
  def self.result(fields)
    taken = fields.each_slice(2).select { |name, _| name.is_a?(Hash) && name.key?("symbol") }
    { "result" => taken.map { |name, field| [name["symbol"], field] } }
  end

  # Takes a symbol's text.
  #
  # @param text [String] Its text.
  # @return [String, nil] The text, nil for one that may name no symbol.
  def self.symbol(text)
    text =~ SYMBOL_PATTERN ? text : nil
  end

  # Takes an entry of the database by its id.
  #
  # @param kind [String] Its kind.
  # @param rest [String] The id as text.
  # @return [Hash, nil] The entry, nil for an id no table holds.
  def self.entry(kind, rest)
    id = rest.to_i
    id > 0 && id < ANY_TABLE ? { kind => id } : nil
  end

  # Reads the four channels of a color or tone, as plain numbers.
  #
  # @param text [String] Numbers joined by ",".
  # @return [Array] Each a whole number as an Integer, any other as a Float of its kind.
  def self.channels(text)
    numbers = text.split(",").first(4).map(&:to_f)
    (numbers + [0.0] * (4 - numbers.size)).map { |channel| channel.finite? && channel == channel.truncate && channel.abs < 1e15 ? channel.to_i : { "float" => channel.to_s } }
  end

  # Reads a plain number.
  #
  # @param value [Integer, Hash] An Integer or a Float of its kind.
  # @return [Numeric] The number.
  def self.number(value)
    value.is_a?(Hash) ? value["float"].to_f : value
  end

  # Escapes a text for a token.
  #
  # @param text [String] The text.
  # @return [String] The text without tabs or line breaks.
  def self.escape(text)
    text.to_s.gsub(/[\\\t\n\r]/) { |character| ESCAPES[character] }
  end

  # Reads an escaped text back.
  #
  # @param text [String] The escaped text.
  # @return [String] The text.
  def self.unescape(text)
    text.gsub(/\\[\\tnr]/) { |escape| UNESCAPES[escape] }
  end
end

# Writes a battle line of values as the DLL writes what the scripts hand over.
#
# @param values [Array] The values, game objects among them as the scripts have them.
# @return [String] The line.
def wire_line(values)
  WireStandIn.line(MGQ_MpBattlesSync::Wire.plain(values))
end

# Reads a battle line into this game's objects, as the scripts read what the DLL hands back.
#
# @param line [String] The line.
# @yieldparam ref [String] A battler's reference.
# @return [Array, nil] The values, nil when the line does not read.
def wire_values(line, &battler)
  values = WireStandIn.parse(line)
  values && MGQ_MpBattlesSync::Wire.objects(values, &battler)
end

# Answers the topics that write and read battle lines from WireStandIn.
#
# @param fake [FakeBridge] The test's bridge.
def answer_wire(fake)
  fake.answer("wire.write") { |values| WireStandIn.line(values) }
  fake.answer("wire.read") { |line| WireStandIn.parse(line) }
end
