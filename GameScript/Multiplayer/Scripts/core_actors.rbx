#----------------------------------------------------------------
#  core_actors.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Dropped writing and reading an item as text, which a trade's tokens in the DLL do
#                            - Handed the characters' and items' facts to C#, which writes and reads their text
#      Paulinchen  2026-10-31: Compared a rebuild with its owner's game outside of battle, as that game measured it
#      Paulinchen  2026-10-11: Named a rebuilt character's owner and its own name
#      Paulinchen  2026-10-07: Logged once when a hero, a counter or switches cannot be read
#                            - Logged the builds written, what they lack and each character rebuilt
#      Paulinchen  2026-10-06: Left the player's affection alone after a won battle
#                            - Checked enchanted equipment past the switch's setter
#                            - Told the weapons' and armors' databases apart in the fingerprint
#                            - Found a database item through MGQ_MpGame.item
#      Paulinchen  2026-10-04: Sent and rebuilt the hero of a replaced Luka
#                            - Sent and compared a character's magic reflection and counter rate too
#                            - Renamed from mp_actors.rbx
#      Paulinchen  2026-10-03: Reached the game's private fields and methods through MGQ_MpGame
#                            - Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Kept the owner's seat and place and the Luka check in Game_MpActor
#      Paulinchen  2026-09-30: Moved into Patch/Multiplayer/Scripts as core_actors.rbx
#                            - Cleared a rebuilt character's actions
#                            - Created
#
#----------------------------------------------------------------

# Characters of another game: their builds, which C# writes and reads as text, rebuilt as real
# characters of this game. PvP battles rebuild a friend's team with them, and co-op battles the
# party members' characters, so balancing them happens in one place.
module MGQ_MpActors
  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "actors"

  # Describes characters for the log.
  #
  # @param actors [Array<Game_Actor>] The characters.
  # @return [String] Each character's id, name and personal level.
  def self.actors_text(actors)
    actors.map { |actor| "#{MGQ_MpLog.named($data_actors, actor.id)} Lv#{actor.base_level rescue '?'}" }.join(", ")
  rescue
    "?"
  end

  # Runs a block with the party out of battle, where the game leaves its battle boosters out of the
  # stats, such as the boost at full HP, as a build's stats are measured on the map.
  #
  # @yieldreturn [Object] What the block returns.
  # @return [Object] What the block returned.
  def self.outside_battle
    party = $game_party
    held = party && MGQ_MpGame.get(party, :in_battle)
    MGQ_MpGame.set(party, :in_battle, false) if held
    yield
  ensure
    MGQ_MpGame.set(party, :in_battle, held) if held
  end

  # Turns a game's value into what the bridge carries: a Float as a Hash of one key, as a battle
  # line's values are (MGQOnline.Game's WirePlain), since the bridge carries no Floats.
  #
  # @param value [Object] nil, true, false, an Integer, a Float, a String, or an Array or Hash of these.
  # @return [Object] The value, each Float in it tagged.
  def self.plain(value)
    case value
    when Float then { "float" => value.to_s }
    when Array then value.map { |item| plain(item) }
    when Hash then value.each_with_object({}) { |(key, item), tagged| tagged[key] = plain(item) }
    else value
    end
  end

  # Takes a Float C# handed back, see plain.
  #
  # @param value [Hash, Numeric] The tagged Float, or a number.
  # @return [Float] The number.
  def self.float(value)
    value.is_a?(Hash) ? value["float"].to_s.to_f : value.to_f
  end

  # Characters' builds, which another game turns back into the characters from its own data. C#
  # (MGQOnline.Game's BuildTopics) writes and reads their text; the scripts hand over each
  # character's facts and leave out what this game's data lacks of those they get back.
  module Builds
    # The topic that writes builds.
    WRITE_TOPIC = "builds.write"

    # The topic that reads builds.
    READ_TOPIC = "builds.read"

    # The topic that writes the fingerprint of the game's data and the build format.
    GAME_TOPIC = "builds.game"

    # The counters a build carries: battles fought in the save, then the character's own count of
    # carries, defeated enemies, times down, orgasms and steals in the Library, then its affection.
    COUNTERS = [:battle_count, :actor_carry, :actor_defeat, :actor_down, :actor_orgasm, :actor_steal, :love]

    # Stats the game counts, max HP to luck.
    PARAM_COUNT = 8

    # Rates compared, by the game's extra rate ids and the names a log shows: hit, evasion,
    # critical, magic reflection and counter.
    RATES = { 0 => "hit", 1 => "evasion", 2 => "critical", 5 => "magic reflection", 6 => "counter" }

    # Texts whose reading is kept, since a battle's start reads each player's builds several times.
    KEPT_READINGS = 16

    # A character's build: its make-up, the stats and rates its owner's game showed, what of the
    # owner's save the character reads, and the hero the owner's game plays in Luka's place.
    Member = Struct.new(:actor_id, :base_level, :class_id, :tribe_id, :level_list, :param_plus, :skill_ids,
                        :abilities, :equip_abilities, :equips, :params, :rates, :counters, :switches_on, :hero)

    # The facts C# read of the texts read last, by text and limit.
    @readings = {}

    # The databases' sizes and the fingerprint C# wrote of them.
    @game = nil

    # Fingerprints this game's data by the sizes of its databases, which differ between versions,
    # and the build format.
    #
    # Only games with equal fingerprints may swap builds, since the ids and fields must mean the same
    # things. Asked every frame of the map, so C# writes it only when a size changed.
    #
    # @return [String] The fingerprint, empty while the DLL does not answer.
    def self.game
      sizes = [$data_actors, $data_classes, $data_skills, $data_items, $data_weapons, $data_armors, $data_enemies, $data_states].map(&:size)
      return @game[1] if @game && @game[0] == sizes

      fingerprint = MGQ_Multiplayer::Bridge.call(GAME_TOPIC, sizes).to_s
      return fingerprint if fingerprint.empty?

      @game = [sizes, fingerprint]
      MGQ_MpActors.log_once([:game, fingerprint], "this game's data fingerprint (build format, then actors, classes, skills, items, weapons, armors, enemies, states): #{fingerprint}")
      fingerprint
    end

    # Writes characters' builds.
    #
    # @param actors [Array<Game_Actor>] The characters.
    # @param backline [Boolean, nil] For a PvP team, whether the player's battles have the
    #   Backline; nil for builds alone.
    # @return [String] The builds, empty while the DLL does not answer.
    def self.write(actors, backline = nil)
      request = { "actors" => actors.map { |actor| facts_of(actor) } }
      request["backline"] = backline unless backline.nil?
      text = MGQ_Multiplayer::Bridge.call(WRITE_TOPIC, request).to_s
      MGQ_MpActors.log("wrote the builds of #{actors.size} characters (#{text.bytesize} bytes): #{MGQ_MpActors.actors_text(actors)}")
      text
    end

    # Lists a character's facts, as the game keeps them.
    #
    # The counters, the switches and the hero come from the player's save, which the receiver's
    # save would stand in for.
    #
    # @param actor [Game_Actor] The character.
    # @return [Hash] The facts by name, see MGQOnline.Game's BuildPlain.
    def self.facts_of(actor)
      MGQ_MpActors.plain(
        "actor" => actor.id,
        "level" => actor.base_level,
        "class" => actor.class_id,
        "tribe" => actor.tribe_id,
        "levels" => actor.level_list.to_a,
        "param_plus" => Array(MGQ_MpGame.get(actor, :param_plus)),
        "skills" => Array(MGQ_MpGame.get(actor, :skills)),
        "abilities" => groups(MGQ_MpGame.get(actor, :abilities)),
        "equip_abilities" => groups(MGQ_MpGame.get(actor, :equip_abilities)),
        "equips" => Array(MGQ_MpGame.get(actor, :equips)).map { |slot| Items.facts(slot && slot.object) },
        "params" => (0...PARAM_COUNT).map { |id| actor.param(id) },
        "rates" => RATES.keys.map { |id| actor.xparam(id) },
        "counters" => COUNTERS.map { |counter| counter_of(actor, counter) },
        "switches" => switches_on(actor),
        "hero" => hero_of(actor))
    end

    # Reads the hero a character shows.
    #
    # @param actor [Game_Actor] The character.
    # @return [String] The hero's key, empty without Luka Replacer or for any character but Luka.
    def self.hero_of(actor)
      defined?(MGQ_LukaReplacer) ? MGQ_LukaReplacer.hero_key(actor).to_s : ""
    rescue => e
      MGQ_MpActors.log_once(:hero_of, "could not read a character's hero, writing none: #{e.class}: #{e.message}")
      ""
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
    rescue => e
      MGQ_MpActors.log_once([:counter_of, counter], "could not read the #{counter} counter, writing 0: #{e.class}: #{e.message}")
      0
    end

    # Lists the switches a party member's battle start states wait for.
    #
    # @param actor [Game_Actor] The party member.
    # @return [Array<Integer>] The switches its battle start states wait for that are on in this save.
    def self.switches_on(actor)
      MGQ_MpGame.call(actor, :auto_state_with_switch).keys.select { |switch_id| $game_switches[switch_id] }
    rescue => e
      MGQ_MpActors.log_once(:switches_on, "could not read the switches a character's battle start states wait for, writing none: #{e.class}: #{e.message}")
      []
    end

    # Lists an ability table's groups.
    #
    # @param table [Hash, nil] Ability ids by skill type.
    # @return [Array<Array(Integer, Array)>] Each skill type and its ability ids.
    def self.groups(table)
      (table || {}).map { |stype_id, ids| [stype_id, Array(ids)] }
    end

    # Reads builds another game wrote, taking only what this game's data knows.
    #
    # @param text [String] The builds, see write.
    # @param limit [Integer] How many C# reads at most; those this game's data lacks the actor of
    #   are left out after.
    # @return [Array<Member>] The members, none when nothing was readable.
    def self.parse(text, limit)
      reading(text.to_s, limit).map { |facts| member_of(facts) }.compact
    end

    # Reads builds through C#, the facts of a text read lately kept.
    #
    # @param text [String] The builds.
    # @param limit [Integer] How many to read at most.
    # @return [Array<Hash>] Each character's facts, none while the DLL does not answer.
    def self.reading(text, limit)
      key = [text, limit]
      return @readings[key] if @readings.key?(key)

      facts = MGQ_Multiplayer::Bridge.call(READ_TOPIC, "text" => text, "limit" => limit)
      return [] unless facts.is_a?(Array)

      @readings.clear if @readings.size >= KEPT_READINGS
      @readings[key] = facts
    end

    # Makes a member of the facts C# read, taking only what this game's data knows.
    #
    # @param facts [Hash] The character's facts, see MGQOnline.Game's BuildPlain.
    # @return [Member, nil] The member, nil when this game's data lacks its actor.
    def self.member_of(facts)
      actor_id = facts["actor"]
      unless $data_actors[actor_id]
        MGQ_MpActors.log_once([:actor, actor_id], "left out a member of actor #{actor_id}, which this game's data lacks")
        return nil
      end

      member = Member.new(
        actor_id,
        [facts["level"], max_base_level].min,
        known_class(facts["class"]),
        known_class(facts["tribe"]),
        level_list(facts["levels"]),
        facts["param_plus"],
        facts["skills"].select { |id| known_skill?(id) },
        ability_table(facts["abilities"]),
        ability_table(facts["equip_abilities"]),
        facts["equips"].map { |item| Items.make(item) },
        facts["params"],
        facts["rates"].map { |rate| MGQ_MpActors.float(rate) },
        facts["counters"],
        facts["switches"],
        facts["hero"].to_s)
      log_left_out(member, facts)
      member
    end

    # Logs, once per character and what was left out, what of a build this game's data lacks.
    #
    # @param member [Member] The character as made.
    # @param facts [Hash] Its facts as C# read them.
    def self.log_left_out(member, facts)
      left_out = []
      left_out << "job #{facts['class']}" if facts["class"] && member.class_id.nil?
      left_out << "race #{facts['tribe']}" if facts["tribe"] && member.tribe_id.nil?
      skills = facts["skills"].size - member.skill_ids.size
      left_out << "#{skills} skills" if skills > 0
      equips = facts["equips"].compact.size - member.equips.compact.size
      left_out << "#{equips} pieces of equipment" if equips > 0
      return if left_out.empty?

      name = MGQ_MpLog.named($data_actors, member.actor_id)
      MGQ_MpActors.log_once([:left_out, member.actor_id, left_out], "left out of #{name}'s build what this game lacks: #{left_out.join(', ')}")
    rescue
    end

    # Reads the highest personal level of this game.
    #
    # @return [Integer] The highest personal level of this game.
    def self.max_base_level
      defined?(NWConst::Actor::MAX_BASE_LEVEL) ? NWConst::Actor::MAX_BASE_LEVEL : 9999
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

    # Takes the job and race levels this game's data knows.
    #
    # @param pairs [Array<Array(Integer, Integer)>] Each job's or race's id and level.
    # @return [Hash] The levels by job or race id.
    def self.level_list(pairs)
      pairs.each_with_object({}) { |(id, level), levels| levels[id] = level if known_class(id) }
    end

    # Takes the abilities this game's data knows.
    #
    # @param groups [Array<Array(Integer, Array<Integer>)>] Each skill type and its ability ids.
    # @return [Hash] The ability ids by skill type.
    def self.ability_table(groups)
      groups.each_with_object({}) { |(stype_id, ids), table| table[stype_id] = ids.select { |id| known_skill?(id) } }
    end
  end

  # Equipped items as facts, which C# writes and reads as text for a build (BuildTopics) and for a
  # trade's enchanted or socketed copy (TradeTopics).
  #
  # Socket and enchanted items are one of a kind, so the receiver makes its own copy of the facts,
  # the way the game remakes an enchanted item's traits from its rolls when a save loads.
  module Items
    # Lists an equipped item's facts, as the game keeps them.
    #
    # @param item [RPG::EquipItem, nil] An equipped item.
    # @return [Hash, nil] The facts, see MGQOnline.Game's BuildPlain; nil for an empty slot.
    def self.facts(item)
      return nil unless item

      kind = item.is_a?(RPG::Weapon) ? "weapon" : "armor"
      unique = item.enchant_item? || item.socket_item?
      facts = { "base" => { kind => unique ? item.base_data.id : item.id } }
      return facts unless unique

      facts["gems"] = Array(MGQ_MpGame.get(item, :stones))
      facts["enchant"] = enchant_facts(item) if item.enchant_item?
      facts
    end

    # Lists an enchanted item's rolls.
    #
    # @param item [Enchant_Item] An enchanted item.
    # @return [Hash] The rolls.
    def self.enchant_facts(item)
      rolls = []
      (item.enchants_variance || {}).each do |enchant_id, formulas|
        formulas.each do |formula_id, variances|
          variances.each { |variance_id, value| rolls.push([enchant_id, formula_id, variance_id, value]) }
        end
      end

      { "rarity" => item.rarity_num, "plus" => item.plus_num, "sockets" => item.socket_num, "variance" => item.enchant_variance_base,
        "enchants" => Array(MGQ_MpGame.get(item, :enchants)), "stats" => Array(item.params_variance), "traits" => rolls }
    end

    # Makes an item of the facts C# read.
    #
    # @param facts [Hash, nil] The item's facts, nil for an empty slot.
    # @return [RPG::EquipItem, nil] The item, nil for an empty slot or one this game's data lacks.
    def self.make(facts)
      return nil unless facts.is_a?(Hash)

      kind, id = facts["base"].to_a.first
      base = MGQ_MpGame.item(kind == "weapon" ? "w" : "a", id)
      item =
        if facts["enchant"]
          enchanted_item(base, facts["enchant"], facts["gems"])
        elsif facts["gems"]
          socket_item(base, facts["gems"])
        else
          base
        end
      MGQ_MpActors.log_once([:equipment, kind, id], "left out equipment #{kind} #{id}: this game's data has no such item") unless item
      item
    rescue => e
      MGQ_MpActors.log("left out equipment #{facts['base'].inspect[0, 40]}: #{e.class}: #{e.message}")
      nil
    end

    # Makes this game's copy of a socket item.
    #
    # @param base [RPG::EquipItem, nil] The item the socket item is made of.
    # @param gems [Array<Integer>] Its gems' item ids.
    # @return [RPG::EquipItem, nil] The socket item, the base itself when it has no sockets.
    def self.socket_item(base, gems)
      return base unless base && base.socket?

      item = base.create_socket_item
      MGQ_MpGame.set(item, :stones, gem_list(gems, item.socket_num))
      item
    end

    # Makes this game's copy of an enchanted item.
    #
    # @param base [RPG::EquipItem, nil] The item the enchanted item is made of.
    # @param enchant [Hash] Its rolls, see enchant_facts.
    # @param gems [Array<Integer>] Its gems' item ids.
    # @return [RPG::EquipItem, nil] The enchanted item, the base itself when it cannot be enchanted.
    def self.enchanted_item(base, enchant, gems)
      return base unless base && base.need_enchant?

      item = base.enchant_item
      socket_num = enchant["sockets"]
      item.rarity_num = enchant["rarity"]
      MGQ_MpGame.set(item, :plus_num, enchant["plus"])
      MGQ_MpGame.set(item, :socket_num, socket_num)
      item.enchant_variance_base = enchant["variance"]
      MGQ_MpGame.set(item, :enchants, enchant["enchants"].select { |id| id > 0 && $data_classes[id] })
      item.params_variance = enchant["stats"].map { |roll| MGQ_MpActors.float(roll) }
      item.enchants_variance = trait_rolls(enchant["traits"])
      MGQ_MpGame.set(item, :stones, gem_list(gems, socket_num))
      MGQ_MpGame.set(item, :prefix, "")
      item.reset_data
      item
    end

    # Takes the trait rolls of an enchanted item.
    #
    # @param rolls [Array<Array>] Each roll's enchantment, formula, roll and value.
    # @return [Hash] The rolls by enchantment, formula and roll.
    def self.trait_rolls(rolls)
      rolls.each_with_object({}) do |(enchant_id, formula_id, variance_id, value), table|
        ((table[enchant_id] ||= {})[formula_id] ||= {})[variance_id] = MGQ_MpActors.float(value)
      end
    end

    # Takes the gems this game's data knows, one per socket.
    #
    # @param ids [Array<Integer>, nil] The gems' item ids, 0 for an empty socket.
    # @param count [Integer] The item's sockets.
    # @return [Array<Integer, nil>] A gem id or nil per socket.
    def self.gem_list(ids, count)
      ids = Array(ids).first(count).map { |id| id > 0 && $data_items[id] ? id : nil }
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

  # The world seat of the player who owns the character, in a battle over the world's room.
  #
  # @return [Integer, nil] The seat, nil elsewhere.
  attr_accessor :mp_seat

  # The character's place among its owner's characters, in a battle over the world's room.
  #
  # @return [Integer, nil] The place, nil elsewhere.
  attr_accessor :mp_place

  # Rebuilds a character of another game, Luka as the hero its owner's game plays when this game
  # has Luka Replacer too.
  #
  # @param member [MGQ_MpActors::Builds::Member] The character's build.
  # @param player [String] Who the character belongs to.
  def initialize(member, player)
    super(member.actor_id)
    @member = member
    @player = player
    MGQ_LukaReplacer.dress(self, member.hero) if defined?(MGQ_LukaReplacer)
    rebuild
    log_rebuild
  end

  # Names the character with its id and its owner, for the log.
  #
  # @return [String] The character's id, name and owner, like "2 Alice (<player>)".
  def log_name
    "#{MGQ_MpLog.named($data_actors, @actor_id)} (#{@player})"
  end

  # Logs what the rebuild made of the character.
  def log_rebuild
    hero = @member.hero.empty? ? "" : ", hero #{@member.hero}#{defined?(MGQ_LukaReplacer) ? '' : ' (no Luka Replacer here, plays as Luka)'}"
    MGQ_MpActors.log("rebuilt #{@player}'s #{MGQ_MpLog.named($data_actors, @member.actor_id)}: Lv#{@member.base_level}, " \
                     "job #{MGQ_MpLog.named($data_classes, @class_id)} Lv#{@level_list[@class_id]}, race #{MGQ_MpLog.named($data_classes, @tribe_id)} Lv#{@level_list[@tribe_id]}, " \
                     "#{@skills.size} skills, #{@equips.count { |slot| slot.object }} of #{@equips.size} slots equipped#{hero}, #{mhp} HP")
  rescue
  end

  # Names the character with its owner.
  #
  # @return [String] The character's name with its owner's, like "Alice (<player>)".
  def name
    "#{actor.name} (#{@player})"
  end

  # Names the player the character belongs to, whom name adds in parentheses.
  #
  # @return [String] The owner.
  def owner
    @player
  end

  # Names the character alone, without its owner: "Alice" of "Alice (<player>)".
  #
  # @return [String] The character's own name.
  def base_name
    actor.name
  end

  # Tells whether the character is Luka, which no rebuilt character is.
  #
  # Luka's mechanics, binding and giving up, belong to the player's own Luka.
  #
  # @return [Boolean] Always false.
  def luca?
    false
  end

  # Has the extra accessory slot when the owner's game had it.
  #
  # The game reads a switch of the save for it, which the player's game may not have turned on yet.
  #
  # @return [Boolean] Whether the character has the extra accessory slot.
  def extra_accessory_slot?
    @member ? @member.equips.size > BASIC_SLOT_COUNT : super
  end

  # Allows the enchanted equipment the owner's game let the character wear, even while the player's
  # save has enchanting off (NWConst::Sw::ENCHANT_OFF).
  #
  # The switch is turned off for the check in the switches' own entries, since the game's setter
  # takes every enchanted item off the player's party and refreshes it when the switch turns on.
  #
  # @param item [RPG::BaseItem] The item.
  # @return [Boolean] Whether the character may wear it.
  def equippable?(item)
    switch_id = defined?(NWConst::Sw::ENCHANT_OFF) && NWConst::Sw::ENCHANT_OFF
    return super unless switch_id && $game_switches[switch_id] && item.is_a?(RPG::EquipItem) && item.enchant_item?

    MGQ_MpActors.log_once([:enchanted, @actor_id], "#{log_name} may wear enchanted equipment, which this save has turned off")
    switches = MGQ_MpGame.get($game_switches, :data)
    begin
      switches[switch_id] = false
      super
    ensure
      switches[switch_id] = true
    end
  end

  # Checks whether the character may use an item, without the player's bag.
  #
  # The items come from the owner's bag, which this game cannot see: in a live battle the owner
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

  # Leaves the affection alone, which belongs to the owner's save: the game keeps it in a variable
  # per character of the player's save, and raises it after a won battle for every battle member.
  #
  # @param value [Integer] The affection the game would set.
  def love=(value)
    return super unless @member

    MGQ_MpActors.log("left #{log_name}'s affection at #{love}, the game would set #{value}: the owner's save keeps it") if value != love
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
      MGQ_MpActors.log("#{log_name} starts the battle as the owner's save says (switch #{switch_id} #{on_there ? 'on' : 'off'} there): " \
                       "#{on_there ? 'added' : 'removed'} #{state_ids.map { |state_id| MGQ_MpLog.named($data_states, state_id) }.join(', ')}")
    end
  end

  # Compares the rebuild with what the owner's game showed of the character, measured as that game
  # measured it: outside of battle.
  #
  # @return [Array<String>] The stats and rates that differ, none when the rebuild matches.
  def differences
    MGQ_MpActors.outside_battle do
      stats = (0...MGQ_MpActors::Builds::PARAM_COUNT).map { |id| [Vocab.param(id), param(id).to_i, @member.params[id]] }
      rates = MGQ_MpActors::Builds::RATES.each_with_index.map do |(id, label), index|
        [label, (xparam(id) * 1000).round, @member.rates[index] && (@member.rates[index] * 1000).round]
      end
      (stats + rates).select { |_, mine, theirs| theirs && mine != theirs }.map { |label, mine, theirs| "#{label} #{mine} (sent #{theirs})" }
    end
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
