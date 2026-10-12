#----------------------------------------------------------------
#  battles_sync_wire.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Read a line no longer than 512 KB and nested at most 8 deep, and gave nil for a line that fails to read instead of raising
#                            - Read an item of the other game as exactly one skill, item, state, weapon or armor token, and a database id only within its table
#                            - Took a symbol only as one this game already has, never making one of the other game's text
#                            - Set only the fields an action result of this game has
#      Paulinchen  2026-10-04: Renamed from mp_battles_sync_wire.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# How a live battle's messages are written: values as tab-separated tokens, which both games
# read back the same. It builds on battles_sync.rbx.

module MGQ_MpBattlesSync
  # Writes values as one line of tab-separated tokens and reads them back, for the messages
  # between the two games. Only plain values travel, never code or Ruby's own formats, since
  # the other game could send anything.
  module Wire
    # Characters a text escapes, which would otherwise end a token or a line.
    ESCAPES = { "\\" => "\\\\", "\t" => "\\t", "\n" => "\\n", "\r" => "\\r" }

    # The escapes turned back.
    UNESCAPES = ESCAPES.invert

    # The text of a symbol taken from the other game: word characters, at most 40.
    SYMBOL_PATTERN = /\A\w{1,40}\z/

    # Deepest nesting of lists and action results a line may have. The game's own lines nest 5 deep
    # at most.
    MAX_DEPTH = 8

    # Longest line read, the most the relay delivers in one message.
    MAX_LINE_BYTES = 512 * 1024

    # The token kinds an item of the database takes: skill, item, state, weapon and armor.
    ITEM_KINDS = %w(k t z w a)

    # What a decoded action offers: its kind, such as :count or :chain_action, which is all the
    # game's display code reads of it.
    ActionKind = Struct.new(:symbol)

    # Writes values.
    #
    # @param values [Array] See encodable?.
    # @return [String] The line.
    def self.line(values)
      values.map { |value| tokens(value) }.flatten.join("\t")
    end

    # Tells whether a value travels as itself rather than as its text.
    #
    # @param value [Object] A value.
    # @return [Boolean] Whether it is nil, true, false, a number, a symbol, a text, a battler, a
    #   skill, item, state, weapon or armor of the database, an equipped item, an action, an action
    #   result, a color, a tone, or an array of these.
    def self.encodable?(value)
      case value
      when nil, true, false, Integer, Float, Symbol, String, Game_Battler, Game_Action, Game_ActionResult,
           RPG::Skill, RPG::Item, RPG::State, RPG::Weapon, RPG::Armor, Color, Tone
        true
      when Game_BaseItem then encodable?(value.object)
      when Array then value.all? { |item| encodable?(item) }
      else false
      end
    end

    # Reads a line.
    #
    # @param line [String] The line.
    # @yieldparam ref [String] A battler's reference, such as "a0".
    # @yieldreturn [Game_Battler, nil] The battler it names.
    # @return [Array, nil] The values, nil when the line is broken, too long or too deep, or fails
    #   to read.
    def self.parse(line, &battler)
      return nil if line.to_s.bytesize > MAX_LINE_BYTES

      stack = [[]]
      line.split("\t").each do |token|
        case token
        when "[", "{"
          return nil if stack.size > MAX_DEPTH

          stack.push([])
        when "]"
          return nil if stack.size < 2

          inner = stack.pop
          stack.last << inner
        when "}"
          return nil if stack.size < 2

          fields = stack.pop
          stack.last << result(fields)
        else
          stack.last << value(token[0, 1], token[1..-1].to_s, &battler)
        end
      end
      stack.size == 1 ? stack[0] : nil
    rescue StandardError, SystemStackError => e
      MGQ_MpBattlesSync.log_once([:wire, e.class.name], "a line did not read: #{e.class}: #{e.message[0, 80]}")
      nil
    end

    # Turns a value into tokens.
    #
    # @param value [Object] A value.
    # @return [Array<String>] Its tokens.
    def self.tokens(value)
      case value
      when nil then ["~"]
      when true then ["+"]
      when false then ["-"]
      when Integer then ["i#{value}"]
      when Float then ["f#{value}"]
      when Symbol then [":#{escape(value.to_s)}"]
      when Game_Battler then ["@#{Recorder.ref(value)}"]
      when Game_Action then ["x#{value.symbol}"]
      when Game_ActionResult then result_tokens(value)
      when Game_BaseItem then ["g#{tokens(value.object)[0]}"]
      when RPG::Skill then ["k#{value.id}"]
      when RPG::Item then ["t#{value.id}"]
      when RPG::State then ["z#{value.id}"]
      when RPG::Weapon then ["w#{value.id}"]
      when RPG::Armor then ["a#{value.id}"]
      when Color then ["c#{[value.red, value.green, value.blue, value.alpha].map(&:to_i).join(',')}"]
      when Tone then ["n#{[value.red, value.green, value.blue, value.gray].map(&:to_i).join(',')}"]
      when Array then ["["] + value.map { |item| tokens(item) }.flatten + ["]"]
      else ["s#{escape(value.to_s)}"]
      end
    end

    # Turns an action result into tokens: its fields as name and value, those that travel.
    #
    # @param result [Game_ActionResult] The result.
    # @return [Array<String>] Its tokens.
    def self.result_tokens(result)
      fields = result.instance_variables.map do |name|
        field = result.instance_variable_get(name)
        encodable?(field) ? tokens(name.to_s.delete("@").to_sym) + tokens(field) : []
      end
      ["{"] + fields.flatten + ["}"]
    end

    # Makes an action result of its fields, leaving out names this game's results lack.
    #
    # @param fields [Array] Names and values, taking turns.
    # @return [Game_ActionResult] The result.
    def self.result(fields)
      result = Game_ActionResult.new(nil)
      fields.each_slice(2) do |name, field|
        ivar = result_fields[name.to_s] if name.is_a?(Symbol)
        result.instance_variable_set(ivar, field) if ivar
      end
      result
    end

    # Names the fields an action result of this game has, its battler among them, which the damage
    # texts read.
    #
    # Listed at the first result read, since the game's scripts load after this one.
    #
    # @return [Hash{String => Symbol}] Each field's name without "@", and the field.
    def self.result_fields
      @result_fields ||= Game_ActionResult.new(nil).instance_variables.each_with_object({}) do |ivar, fields|
        fields[ivar.to_s.delete("@")] = ivar
      end
    rescue => e
      MGQ_MpBattlesSync.log_once(:result_fields, "could not list the fields of an action result, results arrive empty: #{e.class}: #{e.message}")
      {}
    end

    # Finds a symbol this game already has by its text.
    #
    # Symbols are never freed, so the other game's text is only looked up, never made a symbol. Both
    # games run the same scripts, so a symbol the other game sends exists here too.
    #
    # @param text [String] The symbol's text.
    # @return [Symbol, nil] The symbol, nil for a text no symbol of this game has.
    def self.symbol(text)
      return nil unless text =~ SYMBOL_PATTERN

      symbols[text]
    end

    # Lists the symbols this game has by their texts, once, at the first symbol read.
    #
    # @return [Hash{String => Symbol}] Each symbol by its text.
    def self.symbols
      @symbols ||= Symbol.all_symbols.each_with_object({}) { |symbol, all| all[symbol.to_s] = symbol }
    end

    # Reads a value back from a token.
    #
    # @param kind [String] The token's first character.
    # @param rest [String] The rest of the token.
    # @yieldparam ref [String] A battler's reference.
    # @return [Object] The value, nil for anything unknown.
    def self.value(kind, rest, &battler)
      case kind
      when "+" then true
      when "-" then false
      when "i" then rest.to_i
      when "f" then rest.to_f
      when ":" then symbol(unescape(rest))
      when "s" then unescape(rest)
      when "@" then block_given? ? yield(rest) : nil
      when "x" then ActionKind.new(symbol(rest))
      when "g" then base_item(item(rest))
      when "k" then data($data_skills, rest)
      when "t" then data($data_items, rest)
      when "z" then data($data_states, rest)
      when "w" then data($data_weapons, rest)
      when "a" then data($data_armors, rest)
      when "c" then Color.new(*numbers(rest, 4))
      when "n" then Tone.new(*numbers(rest, 4))
      end
    end

    # Finds an entry of the database.
    #
    # @param table [Array, nil] The database.
    # @param rest [String] The entry's id.
    # @return [RPG::BaseItem, nil] The entry, nil for an id the database lacks.
    def self.data(table, rest)
      id = rest.to_i
      table && id > 0 && id < table.size ? table[id] : nil
    end

    # Reads the database entry an equipped or stolen item's token holds: one skill, item, state,
    # weapon or armor token, never another kind.
    #
    # @param rest [String] The token after its "g".
    # @return [RPG::BaseItem, nil] The entry, nil for anything else.
    def self.item(rest)
      kind = rest[0, 1]
      ITEM_KINDS.include?(kind) ? value(kind, rest[1..-1].to_s) : nil
    end

    # Wraps a database entry the way the game keeps an equipped or stolen item.
    #
    # @param item [RPG::BaseItem, nil] The entry.
    # @return [Game_BaseItem, nil] The wrapped entry, nil without one.
    def self.base_item(item)
      return nil unless item

      wrapped = Game_BaseItem.new
      wrapped.object = item
      wrapped
    end

    # Reads a list of numbers.
    #
    # @param text [String] Numbers joined by ",".
    # @param count [Integer] How many are needed.
    # @return [Array<Float>] The numbers, 0 for those missing.
    def self.numbers(text, count)
      values = text.split(",").first(count).map(&:to_f)
      values + [0.0] * (count - values.size)
    end

    # Escapes a text for a token.
    #
    # @param text [String] A text.
    # @return [String] The text without tabs or line breaks.
    def self.escape(text)
      text.gsub(/[\\\t\n\r]/) { |character| ESCAPES[character] }
    end

    # Reads an escaped text back.
    #
    # @param text [String] An escaped text.
    # @return [String] The text.
    def self.unescape(text)
      text.gsub(/\\[\\tnr]/) { |escape| UNESCAPES[escape] }
    end
  end
end
