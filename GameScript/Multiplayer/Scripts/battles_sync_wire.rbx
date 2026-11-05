#----------------------------------------------------------------
#  battles_sync_wire.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Handed the values to C#, which writes and reads the lines, and made the game's objects of the values it reads
#      Paulinchen  2026-10-12: Limited a line's size and nesting and gave nil for an unreadable line
#                            - Read an item as one database token and an id only within its table
#                            - Took only symbols this game already has
#                            - Set only the fields an action result of this game has
#      Paulinchen  2026-10-04: Renamed from mp_battles_sync_wire.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The values a live battle's messages carry, which C# writes as lines and reads back for both
# games. It builds on battles_sync.rbx.

module MGQ_MpBattlesSync
  # Hands the game's values to C# (MGQOnline.Game's WireTopics), which writes them as a line of a
  # battle message, and makes this game's objects of the values C# reads of another game's line.
  #
  # The bridge carries no Floats, Symbols or game objects, so each of those crosses as a Hash of
  # one key that names its kind (MGQOnline.Game's WirePlain); a line carries no Hash itself. Only
  # plain values travel, never code or Ruby's own formats, since the other game could send anything.
  module Wire
    # The topic that writes values as a line.
    WRITE_TOPIC = "wire.write"

    # The topic that reads a line's values.
    READ_TOPIC = "wire.read"

    # The kinds of the database's entries.
    ENTRY_KINDS = %w(skill item state weapon armor)

    # The Floats whose texts to_f reads as 0.0.
    FLOAT_TEXTS = { "Infinity" => 1.0 / 0, "-Infinity" => -1.0 / 0, "NaN" => 0.0 / 0 }

    # What a decoded action offers: its kind, such as :count or :chain_action, which is all the
    # game's display code reads of it.
    ActionKind = Struct.new(:symbol)

    # Writes values as a line.
    #
    # @param values [Array] See encodable?.
    # @return [String] The line, empty while the DLL does not answer.
    def self.write(values)
      MGQ_Multiplayer::Bridge.call(WRITE_TOPIC, plain(values)).to_s
    end

    # Reads a line another game sent.
    #
    # @param line [String] The line.
    # @yieldparam ref [String] A battler's reference, such as "a0".
    # @yieldreturn [Game_Battler, nil] The battler it names.
    # @return [Array, nil] The values, nil when the line does not read or the DLL does not answer.
    def self.read(line, &battler)
      values = MGQ_Multiplayer::Bridge.call(READ_TOPIC, line.to_s)
      values.is_a?(Array) ? objects(values, &battler) : nil
    rescue StandardError => e
      MGQ_MpBattlesSync.log_once([:wire, e.class.name], "a line did not read: #{e.class}: #{e.message[0, 80]}")
      nil
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

    # Turns a value into what the bridge carries, any other object into its text.
    #
    # @param value [Object] A value, see encodable?.
    # @return [Object] nil, true, false, an Integer, a String, an Array of these, or a Hash of one
    #   key that names the value's kind.
    def self.plain(value)
      case value
      when nil, true, false, Integer, String then value
      when Array then value.map { |item| plain(item) }
      when Float then { "float" => value.to_s }
      when Symbol then { "symbol" => value.to_s }
      when Game_Battler then { "battler" => Recorder.ref(value) }
      when Game_Action then { "action" => value.symbol && value.symbol.to_s }
      when Game_ActionResult then { "result" => result_fields_of(value) }
      when Game_BaseItem then { "base_item" => plain(value.object) }
      when RPG::Skill then { "skill" => value.id }
      when RPG::Item then { "item" => value.id }
      when RPG::State then { "state" => value.id }
      when RPG::Weapon then { "weapon" => value.id }
      when RPG::Armor then { "armor" => value.id }
      when Color then { "color" => [value.red, value.green, value.blue, value.alpha].map(&:to_i) }
      when Tone then { "tone" => [value.red, value.green, value.blue, value.gray].map(&:to_i) }
      else value.to_s
      end
    end

    # Lists the fields of an action result that travel.
    #
    # @param result [Game_ActionResult] The result.
    # @return [Array<Array(String, Object)>] Each field's name without "@" and its plain value.
    def self.result_fields_of(result)
      result.instance_variables.map do |name|
        field = result.instance_variable_get(name)
        encodable?(field) ? [name.to_s.delete("@"), plain(field)] : nil
      end.compact
    end

    # Makes this game's objects of the values C# read.
    #
    # @param value [Object] A plain value, see plain.
    # @yieldparam ref [String] A battler's reference.
    # @return [Object] The value, nil for anything this game lacks.
    def self.objects(value, &battler)
      case value
      when Array then value.map { |item| objects(item, &battler) }
      when Hash then object(value.keys[0], value.values[0], &battler)
      else value
      end
    end

    # Makes this game's object of a value of one kind.
    #
    # @param kind [String] The kind, see plain.
    # @param content [Object] What the kind holds.
    # @yieldparam ref [String] A battler's reference.
    # @return [Object] The object, nil for anything this game lacks.
    def self.object(kind, content, &battler)
      return data(table(kind), content) if ENTRY_KINDS.include?(kind)

      case kind
      when "float" then FLOAT_TEXTS.fetch(content.to_s) { content.to_s.to_f }
      when "symbol" then symbol(content.to_s)
      when "battler" then block_given? ? yield(content.to_s) : nil
      when "action" then ActionKind.new(symbol(content.to_s))
      when "base_item" then base_item(objects(content))
      when "color" then Color.new(*objects(content))
      when "tone" then Tone.new(*objects(content))
      when "result" then result(content, &battler)
      end
    end

    # Makes an action result of its fields, leaving out names this game's results lack.
    #
    # @param fields [Array<Array(String, Object)>] Each field's name and plain value.
    # @yieldparam ref [String] A battler's reference.
    # @return [Game_ActionResult] The result.
    def self.result(fields, &battler)
      result = Game_ActionResult.new(nil)
      fields.each do |name, field|
        ivar = result_fields[name.to_s]
        result.instance_variable_set(ivar, objects(field, &battler)) if ivar
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
      symbols[text]
    end

    # Lists the symbols this game has by their texts, once, at the first symbol read.
    #
    # @return [Hash{String => Symbol}] Each symbol by its text.
    def self.symbols
      @symbols ||= Symbol.all_symbols.each_with_object({}) { |symbol, all| all[symbol.to_s] = symbol }
    end

    # Gives the database a kind of entry names an entry of.
    #
    # @param kind [String] One of ENTRY_KINDS.
    # @return [Array, nil] The database.
    def self.table(kind)
      case kind
      when "skill" then $data_skills
      when "item" then $data_items
      when "state" then $data_states
      when "weapon" then $data_weapons
      when "armor" then $data_armors
      end
    end

    # Finds an entry of the database.
    #
    # @param table [Array, nil] The database.
    # @param id [Object] The entry's id.
    # @return [RPG::BaseItem, nil] The entry, nil for an id the database lacks.
    def self.data(table, id)
      table && id.is_a?(Integer) && id > 0 && id < table.size ? table[id] : nil
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
  end
end
