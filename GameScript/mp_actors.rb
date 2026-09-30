#----------------------------------------------------------------
#  mp_actors.rb
#
#  Changelog:
#      Paulinchen  2026-09-30: Cleared a rebuilt character's actions, so a pre-battle spell finds its chain input set
#                            - Created
#
#----------------------------------------------------------------

# Characters of another game: their builds written as plain numbers, and rebuilt from those as real
# characters of this game. PvP battles rebuild a friend's team with them; co-op battles will rebuild
# the party members' characters, so balancing them happens in one place.
module MGQ_MpActors
  # Writes a line to the Multiplayer mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("actors: #{message}")
  rescue
  end

  # Characters' builds as plain numbers, which another game turns back into the characters from its
  # own data. Nothing of the save format leaves the game, since loading someone else's save data can
  # run code.
  module Builds
    # Starts every member line.
    PREFIX = "member="

    # Fields of a member line.
    FIELD_COUNT = 14

    # The counters of field 12: battles fought in the save, then the character's own count of
    # carries, defeated enemies, times down, orgasms and steals in the Library, then its affection.
    COUNTERS = [:battle_count, :actor_carry, :actor_defeat, :actor_down, :actor_orgasm, :actor_steal, :love]

    # Entries a list of a member takes at most.
    MAX_ENTRIES = 3000

    # Equipment slots a member takes at most.
    MAX_SLOTS = 8

    # Highest job or race level taken from another game.
    MAX_LEVEL = 999

    # Stats the game counts, max HP to luck.
    PARAM_COUNT = 8

    # Rates compared: hit, evasion and critical.
    RATE_COUNT = 3

    # A whole number, ids and levels included.
    NUMBER = /\A-?\d{1,15}\z/

    # A character's build: its make-up, the stats and rates its owner's game showed, and what of
    # the owner's save the character reads.
    Member = Struct.new(:actor_id, :base_level, :class_id, :tribe_id, :level_list, :param_plus, :skill_ids,
                        :abilities, :equip_abilities, :equips, :params, :rates, :counters, :switches_on)

    # The build format, which both games must share.
    FORMAT = 3

    # Tells this game version's data from another's by the size of its databases, which differ
    # between versions, and this mod's build format from another's. Only equal ones may swap builds,
    # since the ids and fields must mean the same things.
    #
    # @return [String] The fingerprint.
    def self.game
      sizes = [$data_actors, $data_classes, $data_skills, $data_items, $data_enemies, $data_states].map(&:size)
      "#{FORMAT}:#{sizes.join(',')}"
    end

    # Writes characters' builds.
    #
    # @param actors [Array<Game_Actor>] The characters.
    # @return [String] A member line per character.
    def self.write(actors)
      actors.map { |actor| line_of(actor) }.join("\n")
    end

    # Writes a member as PREFIX and its fields, split by ";": 0 actor id, 1 personal level, 2 job,
    # 3 race, 4 every job and race level as id:level, 5 the stat growths from items, 6 the skills
    # learned, 7 the abilities learned and 8 set as skill type:id.id, 9 the equipment per slot (see
    # Items), 10 the stats and 11 the rates in per mille as the sender sees them, 12 the COUNTERS and
    # 13 the switches on that the character's battle start states wait for.
    #
    # Fields 12 and 13 come from the sender's save, which the receiver's save would stand in for.
    #
    # @param actor [Game_Actor] The character.
    # @return [String] The member line.
    def self.line_of(actor)
      fields = [
        actor.id,
        actor.base_level,
        actor.class_id,
        actor.tribe_id,
        actor.level_list.map { |id, level| "#{id}:#{level}" }.join(","),
        Array(actor.instance_variable_get(:@param_plus)).map(&:to_i).join(","),
        Array(actor.instance_variable_get(:@skills)).join(","),
        groups(actor.instance_variable_get(:@abilities)),
        groups(actor.instance_variable_get(:@equip_abilities)),
        Array(actor.instance_variable_get(:@equips)).map { |slot| Items.write(slot && slot.object) }.join(","),
        (0...PARAM_COUNT).map { |id| actor.param(id).to_i }.join(","),
        (0...RATE_COUNT).map { |id| (actor.xparam(id) * 1000).round }.join(","),
        COUNTERS.map { |counter| counter_of(actor, counter) }.join(","),
        switches_on(actor).join(","),
      ]
      PREFIX + fields.join(";")
    end

    # Reads a save counter of a party member.
    #
    # @param actor [Game_Actor] The party member.
    # @param counter [Symbol] One of COUNTERS.
    # @return [Integer] The counter in this save, 0 where the game lacks it.
    def self.counter_of(actor, counter)
      case counter
      when :battle_count then $game_system.battle_count.to_i
      when :love then actor.love.to_i
      else $game_library.respond_to?(counter) ? $game_library.send(counter, actor.id).to_i : 0
      end
    rescue
      0
    end

    # Lists the switches a party member's battle start states wait for.
    #
    # @param actor [Game_Actor] The party member.
    # @return [Array<Integer>] The switches its battle start states wait for that are on in this save.
    def self.switches_on(actor)
      actor.send(:auto_state_with_switch).keys.select { |switch_id| $game_switches[switch_id] }
    rescue
      []
    end

    # Writes an ability table.
    #
    # @param table [Hash, nil] Ability ids by skill type.
    # @return [String] The table as skill type:id.id, joined by ",".
    def self.groups(table)
      (table || {}).map { |stype_id, ids| "#{stype_id}:#{Array(ids).compact.join('.')}" }.join(",")
    end

    # Reads builds another game wrote, taking only what this game's data knows.
    #
    # @param text [String] The builds, see write.
    # @param limit [Integer] How many to take at most.
    # @return [Array<Member>] The members, none when nothing was readable.
    def self.parse(text, limit)
      members = []

      text.to_s.split("\n").each do |line|
        break if members.size >= limit

        member = parse_member(line.strip)
        if member
          members.push(member)
        else
          MGQ_MpActors.log("left out an unreadable member: #{line[0, 120]}")
        end
      end

      members
    end

    # Reads a member line.
    #
    # @param line [String] The line, see PREFIX.
    # @return [Member, nil] The member, nil when the line is none or names no actor of this game.
    def self.parse_member(line)
      return nil unless line.start_with?(PREFIX)

      fields = line[PREFIX.size..-1].split(";", -1)
      actor_id = number(fields[0])
      return nil unless fields.size == FIELD_COUNT && actor_id && actor_id > 0 && $data_actors[actor_id]

      Member.new(
        actor_id,
        [[number(fields[1]) || 1, 1].max, max_base_level].min,
        known_class(number(fields[2])),
        known_class(number(fields[3])),
        level_list(fields[4]),
        (numbers(fields[5]) + [0] * PARAM_COUNT).first(PARAM_COUNT),
        numbers(fields[6]).select { |id| known_skill?(id) }.uniq,
        ability_table(fields[7]),
        ability_table(fields[8]),
        fields[9].split(",", -1).first(MAX_SLOTS).map { |text| Items.read(text) },
        numbers(fields[10]),
        numbers(fields[11]).map { |value| value / 1000.0 },
        (numbers(fields[12]) + [0] * COUNTERS.size).first(COUNTERS.size).map { |value| [value, 0].max },
        numbers(fields[13]).select { |id| id > 0 })
    end

    # Reads the highest personal level of this game.
    #
    # @return [Integer] The highest personal level of this game.
    def self.max_base_level
      defined?(NWConst::Actor::MAX_BASE_LEVEL) ? NWConst::Actor::MAX_BASE_LEVEL : 9999
    end

    # Reads a number field.
    #
    # @param text [String, nil] A field.
    # @return [Integer, nil] Its number, nil when it is none.
    def self.number(text)
      text.to_s =~ NUMBER ? text.to_i : nil
    end

    # Reads a list of numbers.
    #
    # @param text [String] Numbers joined by ",".
    # @return [Array<Integer>] The numbers, at most MAX_ENTRIES.
    def self.numbers(text)
      text.to_s.split(",").first(MAX_ENTRIES).map { |value| number(value) }.compact
    end

    # Checks a job or race id against this game's data.
    #
    # @param id [Integer, nil] A job or race id.
    # @return [Integer, nil] The id, nil when this game's data lacks it.
    def self.known_class(id)
      id && id > 0 && $data_classes[id] ? id : nil
    end

    # Checks a skill id against this game's data.
    #
    # @param id [Integer] A skill id.
    # @return [Boolean] Whether this game's data has that skill.
    def self.known_skill?(id)
      skill = id > 0 && $data_skills[id]
      skill && !skill.name.empty? ? true : false
    end

    # Reads a list of job or race levels.
    #
    # @param text [String] id:level pairs joined by ",".
    # @return [Hash] The levels by job or race id.
    def self.level_list(text)
      text.to_s.split(",").first(MAX_ENTRIES).each_with_object({}) do |pair, levels|
        id, level = pair.split(":").map { |value| number(value) }
        levels[id] = [[level, 1].max, MAX_LEVEL].min if known_class(id) && level
      end
    end

    # Reads an ability table.
    #
    # @param text [String] Skill type:id.id groups joined by ",".
    # @return [Hash] The ability ids by skill type.
    def self.ability_table(text)
      text.to_s.split(",").first(MAX_ENTRIES).each_with_object({}) do |group, table|
        stype, ids = group.split(":", 2)
        stype_id = number(stype)
        next unless stype_id && ids

        table[stype_id] = ids.split(".").map { |value| number(value) }.compact.select { |id| known_skill?(id) }
      end
    end
  end

  # Equipment as text and back.
  #
  # Socket and enchanted items are one of a kind, so the receiver makes its own copy from the text,
  # the way the game remakes an enchanted item's traits from its rolls when a save loads.
  module Items
    # A weapon or armor of the database.
    PLAIN = /\A([wa])(\d{1,6})\z/

    # A socket item and its gems.
    SOCKET = /\As([wa])(\d{1,6})\.([\d+]*)\z/

    # An enchanted item and its rolls.
    ENCHANTED = /\Ae([wa])(\d{1,6})\.(\d{1,6})\.(\d{1,4})\.(\d{1,3})\.(\d{1,6})\.([\d+]*)\.([\d+]*)\.([-\d:+]*)\.([\d+]*)\z/

    # Stat rolls an enchanted item has, one per stat.
    STAT_ROLLS = 8

    # Trait rolls an enchanted item takes at most.
    MAX_ROLLS = 500

    # Writes an equipped item: "" for an empty slot, w<id> or a<id> for a weapon or armor, s in front
    # for a socket item followed by .<gems>, e in front for an enchanted item followed by
    # .<rarity>.<upgrade>.<sockets>.<variance>.<enchantments>.<stat rolls>.<trait rolls>.<gems>,
    # lists joined by "+", rolls in per mille and a trait roll as enchantment:formula:roll:value.
    #
    # @param item [RPG::EquipItem, nil] An equipped item.
    # @return [String] The item as text.
    def self.write(item)
      return "" unless item

      kind = item.is_a?(RPG::Weapon) ? "w" : "a"
      return enchanted_text(item, kind) if item.enchant_item?
      return "s#{kind}#{item.base_data.id}.#{gems_text(item)}" if item.socket_item?

      "#{kind}#{item.id}"
    end

    # Writes an enchanted item.
    #
    # @param item [Enchant_Item] An enchanted item.
    # @param kind [String] "w" or "a".
    # @return [String] The item as text.
    def self.enchanted_text(item, kind)
      rolls = []
      (item.enchants_variance || {}).each do |enchant_id, formulas|
        formulas.each do |formula_id, variances|
          variances.each { |variance_id, value| rolls.push("#{enchant_id}:#{formula_id}:#{variance_id}:#{(value * 1000).round}") }
        end
      end

      ["e#{kind}#{item.base_data.id}",
       item.rarity_num.to_i,
       item.plus_num.to_i,
       item.socket_num.to_i,
       item.enchant_variance_base.to_i,
       Array(item.instance_variable_get(:@enchants)).join("+"),
       Array(item.params_variance).map { |value| (value * 1000).round }.join("+"),
       rolls.join("+"),
       gems_text(item)].join(".")
    end

    # Writes the gems of an item.
    #
    # @param item [RPG::EquipItem] A socket or enchanted item.
    # @return [String] Its gems' item ids joined by "+", 0 for an empty socket.
    def self.gems_text(item)
      Array(item.instance_variable_get(:@stones)).map(&:to_i).join("+")
    end

    # Makes an item from its text.
    #
    # @param text [String] The item as text, see write.
    # @return [RPG::EquipItem, nil] The item, nil for an empty slot or one this game's data lacks.
    def self.read(text)
      if (match = PLAIN.match(text))
        base(match[1], match[2].to_i)
      elsif (match = SOCKET.match(text))
        socket_item(base(match[1], match[2].to_i), match[3])
      elsif (match = ENCHANTED.match(text))
        enchanted_item(base(match[1], match[2].to_i), match)
      end
    rescue => e
      MGQ_MpActors.log("left out equipment #{text[0, 40]}: #{e.class}: #{e.message}")
      nil
    end

    # Finds a database item.
    #
    # @param kind [String] "w" or "a".
    # @param id [Integer] The item's id in the database.
    # @return [RPG::EquipItem, nil] The item, nil when this game's data lacks it.
    def self.base(kind, id)
      table = kind == "w" ? $data_weapons : $data_armors
      return nil unless id > 0 && id < table.size

      item = table[id]
      item && !item.name.empty? ? item : nil
    end

    # Makes this game's copy of a socket item.
    #
    # @param base [RPG::EquipItem, nil] The item the socket item is made of.
    # @param gems [String] Its gems' item ids.
    # @return [RPG::EquipItem, nil] The socket item, the base itself when it has no sockets.
    def self.socket_item(base, gems)
      return base unless base && base.socket?

      item = base.create_socket_item
      item.instance_variable_set(:@stones, gem_list(gems, item.socket_num))
      item
    end

    # Makes this game's copy of an enchanted item.
    #
    # @param base [RPG::EquipItem, nil] The item the enchanted item is made of.
    # @param match [MatchData] Its text, see ENCHANTED.
    # @return [RPG::EquipItem, nil] The enchanted item, the base itself when it cannot be enchanted.
    def self.enchanted_item(base, match)
      return base unless base && base.need_enchant?

      item = base.enchant_item
      socket_num = match[5].to_i
      stat_rolls = match[8].split("+").map { |value| value.to_i / 1000.0 }
      item.rarity_num = match[3].to_i
      item.instance_variable_set(:@plus_num, match[4].to_i)
      item.instance_variable_set(:@socket_num, socket_num)
      item.enchant_variance_base = match[6].to_i
      item.instance_variable_set(:@enchants, match[7].split("+").map(&:to_i).select { |id| id > 0 && $data_classes[id] })
      item.params_variance = stat_rolls.size == STAT_ROLLS ? stat_rolls : [1.0] * STAT_ROLLS
      item.enchants_variance = trait_rolls(match[9])
      item.instance_variable_set(:@stones, gem_list(match[10], socket_num))
      item.instance_variable_set(:@prefix, "")
      item.reset_data
      item
    end

    # Reads the trait rolls of an enchanted item.
    #
    # @param text [String] enchantment:formula:roll:value entries joined by "+".
    # @return [Hash] The rolls by enchantment, formula and roll.
    def self.trait_rolls(text)
      text.split("+").first(MAX_ROLLS).each_with_object({}) do |entry, rolls|
        enchant_id, formula_id, variance_id, value = entry.split(":").map(&:to_i)
        next unless value

        ((rolls[enchant_id] ||= {})[formula_id] ||= {})[variance_id] = value / 1000.0
      end
    end

    # Reads the gems of an item.
    #
    # @param text [String] Item ids joined by "+", 0 for an empty socket.
    # @param count [Integer] The item's sockets.
    # @return [Array<Integer, nil>] A gem id or nil per socket.
    def self.gem_list(text, count)
      ids = text.split("+").first(count).map { |value| id = value.to_i; id > 0 && $data_items[id] ? id : nil }
      ids + [nil] * (count - ids.size)
    end
  end
end

# A character of another game, rebuilt from its build as a real character of this game: with its
# job, race and levels, stat growth, skills, abilities and equipment, and what of its owner's save
# it reads. What side it fights on is for the class built on it.
#
# A character rather than a monster gets all the traits of its equipment, gems, abilities, job and
# race, such as pre-battle spells, passives and the stat boosts only a battle applies.
class Game_MpActor < Game_Actor
  # Equipment slots without the extra accessory slot.
  BASIC_SLOT_COUNT = 5

  # The damage boost of each counter of MGQ_MpActors::Builds::COUNTERS, in NWFeature::Booster.
  COUNTER_BOOSTERS = {
    :battle_count => :BATTLE_COUNT,
    :actor_carry => :ACTOR_CARRY,
    :actor_defeat => :ACTOR_DEFEAT,
    :actor_down => :ACTOR_DOWN,
    :actor_orgasm => :ACTOR_ORGASM,
    :actor_steal => :ACTOR_STEAL,
    :love => :ACTOR_LOVE,
  }

  # Rebuilds a character of another game.
  #
  # @param member [MGQ_MpActors::Builds::Member] The character's build.
  # @param player [String] Who the character belongs to.
  def initialize(member, player)
    super(member.actor_id)
    @member = member
    @player = player
    rebuild
  end

  # Names the character with its owner.
  #
  # @return [String] The character's name with its owner's, like "Alice (<player>)".
  def name
    "#{actor.name} (#{@player})"
  end

  # Has the extra accessory slot when the owner's game had it. The game reads a switch of the
  # save for it, which the player's game may not have turned on yet.
  #
  # @return [Boolean] Whether the character has the extra accessory slot.
  def extra_accessory_slot?
    @member ? @member.equips.size > BASIC_SLOT_COUNT : super
  end

  # Allows enchanted equipment, which the game takes off while the player's save has enchanting
  # off (NWConst::Sw::ENCHANT_OFF). The owner's game let the character wear it.
  #
  # @param item [RPG::BaseItem] The item.
  # @return [Boolean] Whether the character may wear it.
  def equippable?(item)
    switch_id = defined?(NWConst::Sw::ENCHANT_OFF) && NWConst::Sw::ENCHANT_OFF
    return super unless switch_id && $game_switches[switch_id] && item.is_a?(RPG::EquipItem) && item.enchant_item?

    begin
      $game_switches[switch_id] = false
      super
    ensure
      $game_switches[switch_id] = true
    end
  end

  # Takes items from the owner's bag, which this game cannot see: in a live battle the owner
  # chooses them, and their own game counts what they have.
  #
  # @param item [RPG::Item] The item.
  # @return [Boolean] Whether the character may use it now.
  def item_conditions_met?(item)
    usable_item_conditions_met?(item)
  end

  # Uses up nothing of the player's bag for an item of the owner's.
  #
  # @param _item [RPG::Item] The item.
  def consume_item(_item)
  end

  # Returns the character's affection.
  #
  # @return [Integer] Its affection in the owner's save, which skill formulas and damage boosts read.
  def love
    @member ? @member.counters[MGQ_MpActors::Builds::COUNTERS.index(:love)] : super
  end

  # Multiplies damage by the counters of the owner's save, where the game reads the player's.
  #
  # @return [Float] The boost.
  def booster_ex_count
    return super unless @member

    MGQ_MpActors::Builds::COUNTERS.each_with_index.inject(1.0) do |value, (counter, index)|
      booster = (NWFeature::Booster.const_get(COUNTER_BOOSTERS[counter]) rescue nil)
      booster ? value * ex_count_boost(booster, @member.counters[index]) : value
    end
  end

  # Starts the battle, with the battle start states that wait for a switch following the owner's
  # save instead of the player's.
  def on_battle_start
    super
    return unless @member

    auto_state_with_switch.each do |switch_id, state_ids|
      on_there = @member.switches_on.include?(switch_id)
      next if on_there == ($game_switches[switch_id] ? true : false)

      state_ids.each { |state_id| on_there ? add_state(state_id) : remove_state(state_id) }
    end
  end

  # Compares the rebuild with what the owner's game showed of the character.
  #
  # @return [Array<String>] The stats and rates that differ, none when the rebuild matches.
  def differences
    stats = (0...MGQ_MpActors::Builds::PARAM_COUNT).map { |id| [Vocab.param(id), param(id).to_i, @member.params[id]] }
    rates = (0...MGQ_MpActors::Builds::RATE_COUNT).map do |id|
      [%w(hit evasion critical)[id], (xparam(id) * 1000).round, @member.rates[id] && (@member.rates[id] * 1000).round]
    end
    (stats + rates).select { |_, mine, theirs| theirs && mine != theirs }.map { |label, mine, theirs| "#{label} #{mine} (sent #{theirs})" }
  end

  private

  # Gives the character the build: job, race and levels, stat growth, skills, abilities and
  # equipment, then lets the game settle it the way it settles any character.
  def rebuild
    @class_id = @member.class_id if @member.class_id
    @tribe_id = @member.tribe_id if @member.tribe_id
    @level_list.update(@member.level_list)
    @level_list[@class_id] ||= 1
    @level_list[@tribe_id] ||= 1
    @level = { :base => @member.base_level, :class => @level_list[@class_id], :tribe => @level_list[@tribe_id] }
    @exp = {}
    init_exp
    @param_plus = @member.param_plus.dup
    @skills = @member.skill_ids.sort
    stypes = (@abilities || {}).keys | (@equip_abilities || {}).keys | @member.abilities.keys | @member.equip_abilities.keys
    @abilities = ability_table(stypes, @member.abilities)
    @equip_abilities = ability_table(stypes, @member.equip_abilities)
    @equips = Array.new(basic_equip_slots.size) { Game_BaseItem.new }
    @member.equips.first(@equips.size).each_with_index { |item, slot| @equips[slot].object = item if item }
    refresh
    recover_all
    # Only clearing the actions sets the chain input, which a pre-battle spell reads before the
    # first turn would clear them.
    clear_actions
  end

  # Completes an ability table for every skill type.
  #
  # @param stypes [Array<Integer>] Every skill type of abilities.
  # @param sent [Hash] The build's ability ids by skill type.
  # @return [Hash] Ability ids for every skill type, none where the build has none.
  def ability_table(stypes, sent)
    stypes.each_with_object({}) { |stype_id, table| table[stype_id] = (sent[stype_id] || []).dup }
  end
end
