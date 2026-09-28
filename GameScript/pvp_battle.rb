#----------------------------------------------------------------
#  pvp_battle.rb
#
#  Changelog:
#      Paulinchen  2026-09-28: Created
#
#----------------------------------------------------------------

# Fights a friend's team: two games swap their Frontline's builds once, through a Discord invite or
# a join code on the clipboard, then each fights the other's team, rebuilt as real characters and
# played by the computer. A mirror match fights the player's own team the same way. The battle
# changes nothing, the game is put back as it was once it ends. Needs Multiplayer.rb for the
# connection and mp_sync.rb for the live battle, which the mod loader loads first. It must never
# interrupt the game, so every entry point rescues.
module MGQ_PvpBattle
  # Turns friend battles off without uninstalling them.
  ENABLED = true

  # Windows' code of the key on the map that opens the friend battle screen, F11. The game's own
  # keys F5 to F9 are all taken, F8 by the game's message hiding.
  KEY_CODE = 0x7A

  # Frames between two looks at the exchange, a third of a second at 60 frames per second.
  POLL_INTERVAL = 20

  # Party members a team holds, the Frontline.
  TEAM_SIZE = 4

  # Who the player's own team belongs to in a mirror match.
  MIRROR_NAME = "Mirror"

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already
  def self.hookable?
    !Scene_Map.method_defined?(:mgq_pvp_battle_update_scene)
  end

  # @return [Boolean] whether friend battles are on and the Multiplayer mod's DLL is installed
  def self.available?
    ENABLED && MGQ_Multiplayer.available?
  end

  # Writes a line to the Multiplayer mod's InGame.log.
  #
  # @param message [String] the line
  def self.log(message)
    MGQ_Multiplayer::Log.write("pvp battle: #{message}")
  rescue
  end

  # Has the map start a mirror match against the player's own team, once the screen closed.
  def self.request_mirror
    @mirror_requested = true
  end

  # Opens the friend battle screen when the key is pressed, starts a requested mirror match, starts
  # the battle once the friend's team arrived, and opens the screen for a Discord invite. Called by
  # the map while nothing else runs.
  def self.on_map
    return unless available?

    pressed = MGQ_Multiplayer::Key.pressed?(KEY_CODE)
    return if $game_map.interpreter.running? || $game_player.moving?

    if pressed
      SceneManager.call(Scene_FriendLobby)
      return
    end

    if @mirror_requested
      @mirror_requested = false
      begin_mirror
      return
    end

    @frames = (@frames || 0) + 1
    return if @frames < POLL_INTERVAL

    @frames = 0
    look_at(MGQ_Multiplayer::Link.state)
  rescue => e
    @frames = 0
    log("map check failed: #{e.class}: #{e.message}")
  end

  # Acts on how the exchange stands, seen from the map.
  #
  # @param state [Hash] the state, see MGQ_Multiplayer::Link.state
  def self.look_at(state)
    case state["state"]
    when "received"
      live = defined?(MGQ_MpSync) && MGQ_MpSync.join(state)
      MGQ_Multiplayer::Link.cancel unless live
      begin_battle(state)
    when "failed"
      MGQ_Multiplayer::Link.cancel
      $game_message.add("Friend battle: #{state['error']}")
    else
      invited = state["invite"] == "1"
      SceneManager.call(Scene_FriendLobby) if invited && !@invite_shown
      @invite_shown = invited
    end
  end

  # Starts the battle against the friend's team that arrived.
  #
  # @param state [Hash] the state, see MGQ_Multiplayer::Link.state
  def self.begin_battle(state)
    opponent = MGQ_Multiplayer.clean(state["opponent"])
    members = Team.parse(state[:payload])

    if members.empty?
      $game_message.add("#{opponent}'s team could not be read.")
      MGQ_MpSync.finish if defined?(MGQ_MpSync)
      MGQ_Multiplayer::Link.cancel
      return
    end

    Battle.start(opponent, members, false)
  end

  # Starts a mirror match: the player's own team, sent through the same build as a friend's would
  # be, so it fights exactly as a friend would meet it.
  def self.begin_mirror
    Battle.start(MIRROR_NAME, Team.parse(Team.build), true)
  end

  # The fields the Discord mod publishes about friend battles, through its bridge. The Discord mod
  # hears of hosting and the connection with the friend from Multiplayer.rb.
  #
  # @param scene [String] what the game is showing, see MGQ_Discord::GameState.scene
  # @return [Hash] the fields, none outside a friend battle
  def self.status_fields(scene)
    return {} unless Battle.running? && scene == "battle"

    Battle.mirror? ? { "friend_battle" => "mirror" } : { "friend_battle_with" => Battle.opponent }
  end

  # The team two games swap: each Frontline member's build as plain numbers, which the other game
  # turns back into the character from its own data. Nothing of the save format leaves the game,
  # since loading someone else's save data can run code.
  module Team
    # Starts every member line. The fields after it, split by ";":
    #   0 actor id, 1 personal level, 2 job, 3 race,
    #   4 the levels of every job and race as id:level,
    #   5 the eight stat growths from items,
    #   6 the skills learned,
    #   7 the abilities learned and 8 the abilities set, as skill type:id.id,
    #   9 the equipment per slot, see Items,
    #   10 the eight stats and 11 the hit, evasion and critical rates in per mille, as the sender
    #   sees them, which the receiver compares its rebuild with,
    #   12 the counters some abilities multiply damage by (see COUNTERS),
    #   13 the switches, on in the sender's save, that the character's battle start states wait for.
    # Fields 12 and 13 are the sender's save, not the character, which the receiver's save would
    # otherwise stand in for.
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

    # Highest job or race level taken from a friend.
    MAX_LEVEL = 999

    # Stats the game counts, max HP to luck.
    PARAM_COUNT = 8

    # Rates compared: hit, evasion and critical.
    RATE_COUNT = 3

    # A whole number, ids and levels included.
    NUMBER = /\A-?\d{1,15}\z/

    # A member of a friend's team: the build, the stats and rates the friend's game showed, and what
    # of the friend's save the character reads.
    Member = Struct.new(:actor_id, :base_level, :class_id, :tribe_id, :level_list, :param_plus, :skill_ids,
                        :abilities, :equip_abilities, :equips, :params, :rates, :counters, :switches_on)

    # The team format, which both games must share.
    FORMAT = 3

    # Tells this game version's data from another's by the size of its databases, which differ
    # between versions, and this mod's team format from another's. Only equal ones may swap teams,
    # since the ids and fields must mean the same things.
    #
    # @return [String] the fingerprint
    def self.game
      sizes = [$data_actors, $data_classes, $data_skills, $data_items, $data_enemies, $data_states].map(&:size)
      "#{FORMAT}:#{sizes.join(',')}"
    end

    # Writes the player's Frontline.
    #
    # @return [String] a member line per party member
    def self.build
      $game_party.battle_members.first(TEAM_SIZE).map { |actor| line_of(actor) }.join("\n")
    end

    # Writes a member.
    #
    # @param actor [Game_Actor] the party member
    # @return [String] the member line, see PREFIX
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

    # @param actor [Game_Actor] the party member
    # @param counter [Symbol] one of COUNTERS
    # @return [Integer] the counter in this save, 0 where the game lacks it
    def self.counter_of(actor, counter)
      case counter
      when :battle_count then $game_system.battle_count.to_i
      when :love then actor.love.to_i
      else $game_library.respond_to?(counter) ? $game_library.send(counter, actor.id).to_i : 0
      end
    rescue
      0
    end

    # @param actor [Game_Actor] the party member
    # @return [Array<Integer>] the switches its battle start states wait for that are on in this save
    def self.switches_on(actor)
      actor.send(:auto_state_with_switch).keys.select { |switch_id| $game_switches[switch_id] }
    rescue
      []
    end

    # @param table [Hash, nil] ability ids by skill type
    # @return [String] the table as skill type:id.id, joined by ","
    def self.groups(table)
      (table || {}).map { |stype_id, ids| "#{stype_id}:#{Array(ids).compact.join('.')}" }.join(",")
    end

    # Reads a friend's team, taking only what this game's data knows.
    #
    # @param text [String] the team, see build
    # @return [Array<Member>] the members, none when nothing was readable
    def self.parse(text)
      members = []

      text.to_s.split("\n").each do |line|
        break if members.size >= TEAM_SIZE

        member = parse_member(line.strip)
        if member
          members.push(member)
        else
          MGQ_PvpBattle.log("left out an unreadable member: #{line[0, 120]}")
        end
      end

      members
    end

    # Reads a member line.
    #
    # @param line [String] the line, see PREFIX
    # @return [Member, nil] the member, nil when the line is none or names no actor of this game
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

    # @return [Integer] the highest personal level of this game
    def self.max_base_level
      defined?(NWConst::Actor::MAX_BASE_LEVEL) ? NWConst::Actor::MAX_BASE_LEVEL : 9999
    end

    # @param text [String, nil] a field
    # @return [Integer, nil] its number, nil when it is none
    def self.number(text)
      text.to_s =~ NUMBER ? text.to_i : nil
    end

    # @param text [String] numbers joined by ","
    # @return [Array<Integer>] the numbers, at most MAX_ENTRIES
    def self.numbers(text)
      text.to_s.split(",").first(MAX_ENTRIES).map { |value| number(value) }.compact
    end

    # @param id [Integer, nil] a job or race id
    # @return [Integer, nil] the id, nil when this game's data lacks it
    def self.known_class(id)
      id && id > 0 && $data_classes[id] ? id : nil
    end

    # @param id [Integer] a skill id
    # @return [Boolean] whether this game's data has that skill
    def self.known_skill?(id)
      skill = id > 0 && $data_skills[id]
      skill && !skill.name.empty? ? true : false
    end

    # @param text [String] id:level pairs joined by ","
    # @return [Hash] the levels by job or race id
    def self.level_list(text)
      text.to_s.split(",").first(MAX_ENTRIES).each_with_object({}) do |pair, levels|
        id, level = pair.split(":").map { |value| number(value) }
        levels[id] = [[level, 1].max, MAX_LEVEL].min if known_class(id) && level
      end
    end

    # @param text [String] skill type:id.id groups joined by ","
    # @return [Hash] the ability ids by skill type
    def self.ability_table(text)
      text.to_s.split(",").first(MAX_ENTRIES).each_with_object({}) do |group, table|
        stype, ids = group.split(":", 2)
        stype_id = number(stype)
        next unless stype_id && ids

        table[stype_id] = ids.split(".").map { |value| number(value) }.compact.select { |id| known_skill?(id) }
      end
    end
  end

  # Equipment as text and back: "" for an empty slot, w<id> or a<id> for a weapon or armor, s in
  # front for a socket item followed by .<gems>, e in front for an enchanted item followed by
  # .<rarity>.<upgrade>.<sockets>.<variance>.<enchantments>.<stat rolls>.<trait rolls>.<gems>. Lists
  # inside are joined by "+", rolls in per mille, a trait roll as enchantment:formula:roll:value.
  #
  # Socket and enchanted items are one of a kind, so the receiver makes its own copy from these,
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

    # @param item [RPG::EquipItem, nil] an equipped item
    # @return [String] the item as text
    def self.write(item)
      return "" unless item

      kind = item.is_a?(RPG::Weapon) ? "w" : "a"
      return enchanted_text(item, kind) if item.enchant_item?
      return "s#{kind}#{item.base_data.id}.#{gems_text(item)}" if item.socket_item?

      "#{kind}#{item.id}"
    end

    # @param item [Enchant_Item] an enchanted item
    # @param kind [String] "w" or "a"
    # @return [String] the item as text
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

    # @param item [RPG::EquipItem] a socket or enchanted item
    # @return [String] its gems' item ids joined by "+", 0 for an empty socket
    def self.gems_text(item)
      Array(item.instance_variable_get(:@stones)).map(&:to_i).join("+")
    end

    # Makes an item from its text.
    #
    # @param text [String] the item as text, see write
    # @return [RPG::EquipItem, nil] the item, nil for an empty slot or one this game's data lacks
    def self.read(text)
      if (match = PLAIN.match(text))
        base(match[1], match[2].to_i)
      elsif (match = SOCKET.match(text))
        socket_item(base(match[1], match[2].to_i), match[3])
      elsif (match = ENCHANTED.match(text))
        enchanted_item(base(match[1], match[2].to_i), match)
      end
    rescue => e
      MGQ_PvpBattle.log("left out equipment #{text[0, 40]}: #{e.class}: #{e.message}")
      nil
    end

    # @param kind [String] "w" or "a"
    # @param id [Integer] the item's id in the database
    # @return [RPG::EquipItem, nil] the item, nil when this game's data lacks it
    def self.base(kind, id)
      table = kind == "w" ? $data_weapons : $data_armors
      return nil unless id > 0 && id < table.size

      item = table[id]
      item && !item.name.empty? ? item : nil
    end

    # @param base [RPG::EquipItem, nil] the item the socket item is made of
    # @param gems [String] its gems' item ids
    # @return [RPG::EquipItem, nil] the socket item, the base itself when it has no sockets
    def self.socket_item(base, gems)
      return base unless base && base.socket?

      item = base.create_socket_item
      item.instance_variable_set(:@stones, gem_list(gems, item.socket_num))
      item
    end

    # @param base [RPG::EquipItem, nil] the item the enchanted item is made of
    # @param match [MatchData] its text, see ENCHANTED
    # @return [RPG::EquipItem, nil] the enchanted item, the base itself when it cannot be enchanted
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

    # @param text [String] enchantment:formula:roll:value entries joined by "+"
    # @return [Hash] the rolls by enchantment, formula and roll
    def self.trait_rolls(text)
      text.split("+").first(MAX_ROLLS).each_with_object({}) do |entry, rolls|
        enchant_id, formula_id, variance_id, value = entry.split(":").map(&:to_i)
        next unless value

        ((rolls[enchant_id] ||= {})[formula_id] ||= {})[variance_id] = value / 1000.0
      end
    end

    # @param text [String] item ids joined by "+", 0 for an empty socket
    # @param count [Integer] the item's sockets
    # @return [Array<Integer, nil>] a gem id or nil per socket
    def self.gem_list(text, count)
      ids = text.split("+").first(count).map { |value| id = value.to_i; id > 0 && $data_items[id] ? id : nil }
      ids + [nil] * (count - ids.size)
    end
  end

  # One of the friend's characters, rebuilt from its build as a real character of this game, fighting
  # on the enemy side and played by the game's own auto-battle.
  #
  # A character rather than a monster, so its equipment, gems, abilities, job and race give it all
  # their traits: pre-battle spells, passives, counters and the stat boosts only a battle applies.
  # The battle's code takes every character for the player's own, so it answers for the enemy side
  # where that matters: its allies and enemies, its place in the troop, its picture, party-wide
  # boosts, and Luka's own mechanics, which only the player's Luka has.
  class Opponent < Game_Actor
    # Equipment slots without the extra accessory slot.
    BASIC_SLOT_COUNT = 5

    # The damage boost of each counter of Team::COUNTERS, in NWFeature::Booster.
    COUNTER_BOOSTERS = {
      :battle_count => :BATTLE_COUNT,
      :actor_carry => :ACTOR_CARRY,
      :actor_defeat => :ACTOR_DEFEAT,
      :actor_down => :ACTOR_DOWN,
      :actor_orgasm => :ACTOR_ORGASM,
      :actor_steal => :ACTOR_STEAL,
      :love => :ACTOR_LOVE,
    }

    # How grey the picture turns while the character is dead, from 0 to the fully grey 255.
    SILHOUETTE_GRAY = 255

    # How opaque the picture is while the character is dead, from 0 to the fully opaque 255.
    SILHOUETTE_OPACITY = 160

    # Where the picture stands, at its bottom edge.
    attr_accessor :screen_x, :screen_y

    # The letter and plural mark the game gives monsters of the same name.
    attr_accessor :letter, :plural

    # @param member [Team::Member] the character's build
    # @param player [String] who the character belongs to
    def initialize(member, player)
      super(member.actor_id)
      @member = member
      @player = player
      @letter = ""
      @plural = false
      @screen_x = 0
      @screen_y = 0
      rebuild
    end

    # @return [String] the character's name with its owner's, like "Alice (<player>)"
    def name
      "#{actor.name} (#{@player})"
    end

    # @return [String] the name, which the battle's "X appears!" lines read
    def original_name
      name
    end

    # @return [Game_Troop] the friend's team
    def friends_unit
      $game_troop
    end

    # @return [Game_Party] the player's party
    def opponents_unit
      $game_party
    end

    # @return [Integer, nil] the place in the troop, which targeting uses
    def index
      $game_troop.members.index(self)
    end

    # @return [Boolean] always, the troop is all it fights in
    def battle_member?
      true
    end

    # @return [Boolean] always, it is drawn like a monster
    def use_sprite?
      true
    end

    # @return [Integer] how far in front its picture is drawn
    def screen_z
      100
    end

    # @return [String] no battle picture of its own, Pictures draws the Library's
    def battler_name
      ""
    end

    # @return [Integer] no hue change
    def battler_hue
      0
    end

    # @return [Boolean] never, Luka's mechanics (binding, giving up) belong to the player's Luka
    def luca?
      false
    end

    # A stand-in for the monster data the battle's code reads of the enemy side.
    #
    # @return [RPG::Enemy] a monster without rewards, notes or recruiting
    def enemy
      @enemy ||= Opponents.enemy_data(name)
    end

    # @return [Integer] the character's actor id, which enemy HP bars and the Library read
    def enemy_id
      id
    end

    # @return [Integer] no affection, which the target window shows for monsters
    def friend
      0
    end

    # @return [Integer] no defeat scene
    def lose_event_id
      0
    end

    # @return [Boolean] always, running from a friend battle counts as no escape
    def escape_not_count?
      true
    end

    # @return [Hash] nothing to steal
    def steal_list
      { 1 => [], 2 => [], 3 => [], 4 => [] }
    end

    # @return [Integer] how hard it is to run from, which the escape chance reads of every enemy
    def escape_level
      enemy.escape_level
    end

    # Has the extra accessory slot when the friend's game had it. The game reads a switch of the
    # save for it, which the player's game may not have turned on yet.
    #
    # @return [Boolean]
    def extra_accessory_slot?
      @member ? @member.equips.size > BASIC_SLOT_COUNT : super
    end

    # Allows enchanted equipment, which the game takes off while the player's save has enchanting
    # off (NWConst::Sw::ENCHANT_OFF). The friend's game let the character wear it.
    #
    # @param item [RPG::BaseItem] the item
    # @return [Boolean] whether the character may wear it
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

    # Takes items from the friend's bag, which this game cannot see: in a live battle the friend
    # chooses them, and their own game counts what they have.
    #
    # @param item [RPG::Item] the item
    # @return [Boolean] whether the character may use it now
    def item_conditions_met?(item)
      usable_item_conditions_met?(item)
    end

    # Uses up nothing of the player's bag for an item of the friend's.
    #
    # @param _item [RPG::Item] the item
    def consume_item(_item)
    end

    # @return [Integer] its affection in the friend's save, which skill formulas and damage boosts read
    def love
      @member ? @member.counters[Team::COUNTERS.index(:love)] : super
    end

    # Multiplies damage by the counters of the friend's save, where the game reads the player's.
    #
    # @return [Float] the boost
    def booster_ex_count
      return super unless @member

      Team::COUNTERS.each_with_index.inject(1.0) do |value, (counter, index)|
        booster = (NWFeature::Booster.const_get(COUNTER_BOOSTERS[counter]) rescue nil)
        booster ? value * ex_count_boost(booster, @member.counters[index]) : value
      end
    end

    # Starts the battle, with the battle start states that wait for a switch following the
    # friend's save instead of the player's.
    def on_battle_start
      super
      return unless @member

      auto_state_with_switch.each do |switch_id, state_ids|
        on_there = @member.switches_on.include?(switch_id)
        next if on_there == ($game_switches[switch_id] ? true : false)

        state_ids.each { |state_id| on_there ? add_state(state_id) : remove_state(state_id) }
      end
    end

    # Answers what the battle's code asks only monsters, from the monster stand-in, and logs it
    # once. A question the audit missed would otherwise end the game in the middle of a battle.
    #
    # @param name [Symbol] the method
    # @param args [Array] its arguments
    # @return [Object] the stand-in's answer
    def method_missing(name, *args, &block)
      return super unless Game_Enemy.method_defined?(name) && enemy.respond_to?(name)

      @forwarded ||= {}
      MGQ_PvpBattle.log("#{name} answered by the monster stand-in") unless @forwarded[name]
      @forwarded[name] = true
      enemy.send(name, *args, &block)
    end

    # @param name [Symbol] the method
    # @param include_private [Boolean] whether private methods count
    # @return [Boolean] whether method_missing answers it
    def respond_to_missing?(name, include_private = false)
      (Game_Enemy.method_defined?(name) && enemy.respond_to?(name)) || super
    end

    # @return [Boolean] never a boss, which the enemy HP bars read
    def boss?
      false
    end

    # @return [Boolean] never hides its name, which the enemy HP bars read
    def hide_name
      false
    end

    # @return [Integer] no shift of its HP bar
    def lefx
      0
    end

    # Boosts a stat for each character on its own side, where the game counts the player's party.
    #
    # @param param_id [Integer] the stat
    # @return [Float] the boost
    def booster_actor_exist_param(param_id)
      return 1.0 unless (2..7).include?(param_id)

      friends_unit.members.inject(1.0) { |rate, member| rate + features_sum_booster(ACTOR_EXIST_PARAM, member.id) }
    end

    # Flashes and sounds like a hit monster instead of shaking the screen.
    def perform_damage_effect
      @sprite_effect_type = :blink
      Sound.play_enemy_damage
    end

    # Flashes and sounds like a defeated monster, but stays on the battlefield as a silhouette, since
    # the friend's team can still bring it back.
    def perform_collapse_effect
      @sprite_effect_type = :whiten
      Sound.play_enemy_collapse
    end

    # Picks the automatic skills (pre-battle spells, counters, turn start and end) whose condition
    # holds and whose chance comes up, like the game does, with "ally" and "enemy" seen from the
    # friend's side. The game checks the player's party for allies.
    #
    # @param skills [Array<Hash>] the automatic skills, with :condition_type, :condition_ids and :per
    # @return [Array<Hash>] those that fire
    def firing_auto_skills(skills)
      own = $game_troop.members
      skills.select do |skill|
        if skill[:condition_type]
          next false unless skill_race_ok?($data_skills[skill[:id]])
          next false unless auto_skill_condition_met?(skill[:condition_type], skill[:condition_ids], own)
        end
        rand < skill[:per]
      end
    end

    # Makes the turn's actions with the game's own auto-battle.
    def make_actions
      super
      make_auto_battle_actions unless @actions.empty?
    end

    # Uses a skill or item, and logs the first ones of the battle, which tells what the computer
    # picks for the character.
    #
    # @param item [RPG::UsableItem] the skill or item
    def use_item(item)
      super
      Battle.log_action(self, item)
    end

    # Compares the rebuild with what the friend's game showed of the character.
    #
    # @return [Array<String>] the stats and rates that differ, none when the rebuild matches
    def differences
      stats = (0...Team::PARAM_COUNT).map { |id| [Vocab.param(id), param(id).to_i, @member.params[id]] }
      rates = (0...Team::RATE_COUNT).map do |id|
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
    end

    # The condition of an automatic skill, seen from the friend's side: 1 an ally of these ids
    # fights along, 2 an enemy of these monster ids is there, which a friend battle has none of,
    # 3 an ally has one of these states, 4 an enemy has one, 5 the character itself has one.
    #
    # @param type [Integer] the condition
    # @param ids [Array<Integer>] the actor, monster or state ids it names
    # @param own [Array<Game_Battler>] the friend's team
    # @return [Boolean] whether it holds
    def auto_skill_condition_met?(type, ids, own)
      case type
      when 1
        own_ids = own.map(&:id)
        ids.any? { |id| own_ids.include?($game_actors.original_id(id)) }
      when 2
        false
      when 3
        ids.any? { |id| own.any? { |member| member.state?(id) } }
      when 4
        ids.any? { |id| $game_party.battle_members.any? { |member| member.state?(id) } }
      when 5
        ids.any? { |id| state?(id) }
      else
        true
      end
    end

    # @param stypes [Array<Integer>] every skill type of abilities
    # @param sent [Hash] the build's ability ids by skill type
    # @return [Hash] ability ids for every skill type, none where the build has none
    def ability_table(stypes, sent)
      stypes.each_with_object({}) { |stype_id, table| table[stype_id] = (sent[stype_id] || []).dup }
    end
  end

  # The friend's team in the game's data: an empty troop of its own for the length of the battle,
  # which the rebuilt characters are put into.
  module Opponents
    # The troop's name.
    TROOP_NAME = "Friend battle"

    # Adds the troop.
    #
    # @return [Integer] its troop id
    def self.add_troop
      remove
      @troops_size = $data_troops.size
      troop = RPG::Troop.new
      troop.id = @troops_size
      troop.name = TROOP_NAME
      troop.members = []
      $data_troops[@troops_size] = troop
      @troops_size
    end

    # Takes the troop out of the game's data again, and the pictures drawn for the battle.
    def self.remove
      return unless @troops_size

      $data_troops.slice!(@troops_size..-1)
      @troops_size = nil
      Pictures.clear
    end

    # Rebuilds the friend's characters and stands them side by side at the screen's bottom, where
    # the game stands its own full-size monsters.
    #
    # @param members [Array<Team::Member>] the friend's team
    # @param player [String] the friend's name
    # @return [Array<Opponent>] the characters, without those that could not be rebuilt
    def self.build(members, player)
      opponents = members.map do |member|
        begin
          Opponent.new(member, player)
        rescue => e
          MGQ_PvpBattle.log("could not rebuild actor #{member.actor_id}: #{e.class}: #{e.message}")
          nil
        end
      end.compact

      opponents.each_with_index do |opponent, index|
        opponent.screen_x = Graphics.width * (2 * index + 1) / (2 * opponents.size)
        opponent.screen_y = Graphics.height
      end
      opponents
    end

    # A monster without rewards, notes or recruiting, for the code that reads a monster's data of
    # anything on the enemy side.
    #
    # A copy of a monster of the game's own, so every field that code reads is present.
    #
    # @param name [String] the character's name
    # @return [RPG::Enemy] the monster
    def self.enemy_data(name)
      enemy = $data_enemies.find { |candidate| candidate && !candidate.name.empty? }.dup
      enemy.id = 0
      enemy.name = name
      enemy.exp = 0
      enemy.gold = 0
      enemy.instance_variable_set(:@data_ex, { :no_difficulty => true, :lib_exclude? => true })
      enemy
    end
  end

  # The pictures of the friend's characters: the full picture the Library shows of each, at full
  # size and cut to the character, or the face when there is none.
  #
  # The Library's pictures are the same files as the monsters' battle pictures, 640 x 480, and the
  # game has no larger ones. Shrunk, they turn jagged, since the game scales without smoothing.
  module Pictures
    # Pixels skipped between two looked at when finding where a picture's character is. Looking at
    # every pixel of a Library picture takes too long in the game.
    SCAN_STEP = 4

    # How much a face is enlarged when it stands in for a picture.
    FACE_ZOOM = 2

    # Faces in a row of a face file, and rows.
    FACE_COLUMNS = 4
    FACE_ROWS = 2

    # The picture of one of the friend's characters.
    #
    # @param battler [Game_Battler] a battler of the battle
    # @return [Bitmap, nil] the picture, nil for every other battler
    def self.stand_in_for(battler)
      return nil unless battler.is_a?(MGQ_PvpBattle::Opponent)

      @pictures ||= {}
      picture = @pictures[battler.id]
      return picture if picture && !picture.disposed?

      @pictures[battler.id] = library_picture(battler.id) || face(battler.id)
    rescue => e
      MGQ_PvpBattle.log("no picture for actor #{battler.id rescue '?'}: #{e.class}: #{e.message}")
      nil
    end

    # Cuts the character out of the picture the Library shows of it, down to the picture's bottom
    # edge, so it stands where the game stands its own full-size monsters.
    #
    # @param actor_id [Integer] the character
    # @return [Bitmap, nil] the picture, nil when the Library has none
    def self.library_picture(actor_id)
      image = defined?(NWConst::Library::ACTOR_IMAGE) && NWConst::Library::ACTOR_IMAGE[actor_id]
      return nil unless image.is_a?(Array)

      sheet = Cache.load_bitmap(image[0], image[1], image[2] || 0)
      area = character_area(sheet)
      area.height = sheet.height - area.y
      bitmap = Bitmap.new(area.width, area.height)
      bitmap.blt(0, 0, sheet, area)
      bitmap
    end

    # Finds where the character is on a picture: the box around its visible pixels.
    #
    # @param sheet [Bitmap] the picture
    # @return [Rect] the box, the whole picture when nothing on it is visible
    def self.character_area(sheet)
      left, top, right, bottom = sheet.width, sheet.height, -1, -1

      (0...sheet.height).step(SCAN_STEP) do |y|
        (0...sheet.width).step(SCAN_STEP) do |x|
          next if sheet.get_pixel(x, y).alpha == 0

          left = x if x < left
          right = x if x > right
          top = y if y < top
          bottom = y if y > bottom
        end
      end

      return sheet.rect if right < 0

      left = [left - SCAN_STEP, 0].max
      top = [top - SCAN_STEP, 0].max
      Rect.new(left, top, [right + SCAN_STEP, sheet.width].min - left, [bottom + SCAN_STEP, sheet.height].min - top)
    end

    # Cuts a character's face out of its face file and enlarges it.
    #
    # @param actor_id [Integer] the character
    # @return [Bitmap, nil] the face, nil without a face file
    def self.face(actor_id)
      actor = $data_actors[actor_id]
      return nil if actor.face_name.to_s.empty?

      sheet = Cache.face(actor.face_name)
      width = sheet.width / FACE_COLUMNS
      height = sheet.height / FACE_ROWS
      source = Rect.new(actor.face_index % FACE_COLUMNS * width, actor.face_index / FACE_COLUMNS * height, width, height)
      bitmap = Bitmap.new(width * FACE_ZOOM, height * FACE_ZOOM)
      bitmap.stretch_blt(bitmap.rect, sheet, source)
      bitmap
    end

    # Disposes the pictures drawn for the battle.
    def self.clear
      (@pictures || {}).each_value { |bitmap| bitmap.dispose if bitmap && !bitmap.disposed? }
      @pictures = {}
    end
  end

  # Multiplayer/Mirror Match.log: each character of a mirror match next to its rebuild, outside of
  # battle and at the first turn, every value that differs marked. Written anew for every match.
  module MirrorReport
    # File inside the Discord folder.
    FILE = "Mirror Match.log"

    # Names of the extra rates, in the game's order.
    XPARAM_NAMES = ["Hit", "Evasion", "Critical", "Critical evasion", "Magic evasion", "Magic reflection",
                    "Counter", "HP regeneration", "MP regeneration", "TP regeneration"]

    # Names of the special rates, in the game's order.
    SPARAM_NAMES = ["Target rate", "Guard", "Recovery", "Pharmacology", "MP cost", "TP charge",
                    "Physical damage taken", "Magical damage taken", "Floor damage", "EXP"]

    # Ends a row whose two values differ.
    MARK = "  <-- differs"

    # Width of a row's label and of each value.
    LABEL_WIDTH = 26
    VALUE_WIDTH = 20

    # Writes the first section, outside of battle, over the last match's report.
    #
    # @param opponents [Array<Opponent>] the rebuilt characters, already in the troop
    def self.start(opponents)
      @pairs = opponents.map { |rebuilt| [$game_party.battle_members.find { |actor| actor.id == rebuilt.id }, rebuilt] }
      @pairs.reject! { |yours, _| yours.nil? }
      @turn_written = false
      write("wb", "Outside of battle (#{Time.now.strftime('%Y-%m-%d %H:%M:%S')})")
    end

    # Adds the section at the first turn, once pre-battle spells and battle-only boosts apply.
    # Called at every turn's start.
    def self.turn_started
      return if @turn_written || @pairs.nil? || !Battle.mirror?

      @turn_written = true
      write("ab", "In battle, turn #{$game_troop.turn_count}")
    end

    # Writes a section: every character next to its rebuild.
    #
    # @param mode [String] "wb" to start the file anew, "ab" to add to it
    # @param title [String] the section's title
    def self.write(mode, title)
      blocks = @pairs.map { |yours, rebuilt| block(yours, rebuilt) }
      differences = blocks.inject(0) { |sum, (_, count)| sum + count }
      lines = ["=" * 70, "#{title}: #{differences} value(s) differ", "=" * 70, ""] + blocks.map(&:first).flatten
      File.open(MGQ_Multiplayer.path(FILE), mode) { |file| file.write(lines.join("\n") + "\n") }
    rescue => e
      MGQ_PvpBattle.log("mirror report failed: #{e.class}: #{e.message}")
    end

    # Compares a character with its rebuild.
    #
    # @param yours [Game_Actor] the player's character
    # @param rebuilt [Opponent] its rebuild
    # @return [Array] the lines, and how many values differ
    def self.block(yours, rebuilt)
      rows = rows_for(yours, rebuilt)
      lines = ["-- #{yours.name} (actor #{yours.id})", row("", "yours", "rebuilt", false)]
      lines += rows.map { |label, mine, theirs| row(label, mine, theirs, mine != theirs) }
      [lines + [""], rows.count { |_, mine, theirs| mine != theirs }]
    end

    # @param yours [Game_Actor] the player's character
    # @param rebuilt [Opponent] its rebuild
    # @return [Array<Array>] a label and both values per row
    def self.rows_for(yours, rebuilt)
      rows = (0...8).map { |id| [Vocab.param(id), yours.param(id).to_i, rebuilt.param(id).to_i] }
      rows += XPARAM_NAMES.each_with_index.map { |name, id| [name, percent(yours.xparam(id)), percent(rebuilt.xparam(id))] }
      rows += SPARAM_NAMES.each_with_index.map { |name, id| [name, percent(yours.sparam(id)), percent(rebuilt.sparam(id))] }
      rows.push(["Max SP", yours.max_tp.to_i, rebuilt.max_tp.to_i])
      rows.push(["Level (personal/job/race)", levels(yours), levels(rebuilt)])
      rows.push(["Job / race", "#{yours.class_id} / #{yours.tribe_id}", "#{rebuilt.class_id} / #{rebuilt.tribe_id}"])
      rows += element_rows(yours, rebuilt) + state_rows(yours, rebuilt)
      rows.push(["States now", state_names(yours), state_names(rebuilt)])
      skills = [yours.skills.map(&:id), rebuilt.skills.map(&:id)]
      abilities = [yours.all_equip_abilities.compact, rebuilt.all_equip_abilities.compact]
      rows.push(["Skills", skills[0].size, skills[1].size])
      rows.push(["Skills only yours / rebuilt", ids_text(skills[0] - skills[1]), ids_text(skills[1] - skills[0])])
      rows.push(["Abilities set", abilities[0].size, abilities[1].size])
      rows.push(["Abilities only yours / rebuilt", ids_text(abilities[0] - abilities[1]), ids_text(abilities[1] - abilities[0])])
      rows + equipment_rows(yours, rebuilt)
    end

    # @return [Array<Array>] the element rates either of the two has other than 100%
    def self.element_rows(yours, rebuilt)
      (1...$data_system.elements.size).map do |id|
        mine = percent(yours.element_rate(id))
        theirs = percent(rebuilt.element_rate(id))
        ["Element #{$data_system.elements[id]}", mine, theirs] unless mine == percent(1.0) && theirs == percent(1.0)
      end.compact
    end

    # @return [Array<Array>] how many states each resists, and each state whose rate differs
    def self.state_rows(yours, rebuilt)
      ids = (1...$data_states.size).select { |id| $data_states[id] }
      rows = [["States resisted", ids.count { |id| yours.state_resist?(id) }, ids.count { |id| rebuilt.state_resist?(id) }]]
      ids.each do |id|
        mine = state_value(yours, id)
        theirs = state_value(rebuilt, id)
        rows.push(["State #{$data_states[id].name}", mine, theirs]) unless mine == theirs
      end
      rows
    end

    # @return [Array<Array>] each equipment slot's item, with its gems
    def self.equipment_rows(yours, rebuilt)
      [yours.equips.size, rebuilt.equips.size].max.times.map do |slot|
        ["Slot #{slot}", item_text(yours.equips[slot]), item_text(rebuilt.equips[slot])]
      end
    end

    # @return [String] the item's base name, then its gems' ids, "-" for an empty slot
    def self.item_text(item)
      return "-" unless item

      base = item.respond_to?(:base_data) ? item.base_data : item
      gems = Array(item.instance_variable_get(:@stones)).compact
      gems.empty? ? base.name : "#{base.name} [#{gems.join(' ')}]"
    end

    # @return [String] the state's rate, "resisted" when resisted
    def self.state_value(battler, id)
      battler.state_resist?(id) ? "resisted" : percent(battler.state_rate(id))
    end

    # @return [String] the states on the battler right now, by name
    def self.state_names(battler)
      names = battler.states.map(&:name)
      names.empty? ? "-" : names.join(", ")
    end

    # @return [String] personal, job and race level
    def self.levels(battler)
      "#{battler.base_level}/#{battler.class_level}/#{battler.tribe_level}"
    end

    # @param ids [Array<Integer>] skill or ability ids
    # @return [String] the first of them, "-" for none
    def self.ids_text(ids)
      ids.empty? ? "-" : ids.first(8).join(" ")
    end

    # @return [String] a rate as a percentage
    def self.percent(rate)
      format("%.1f%%", rate.to_f * 100)
    end

    # @return [String] one row: label and both values, marked when they differ
    def self.row(label, mine, theirs, differs)
      label.to_s.ljust(LABEL_WIDTH) + mine.to_s.rjust(VALUE_WIDTH) + "  " + theirs.to_s.rjust(VALUE_WIDTH) + (differs ? MARK : "")
    end
  end

  # The battle against the friend's team, and putting the game back afterwards.
  #
  # The game's own battle replay mode keeps EXP, gold, drops, recruiting and the autosave out, and
  # losing only returns to the map. What the battle still changes, the snapshot taken before it
  # undoes: the save's contents and the Library, affection and switches all saves share. Rebuilding
  # the friend's characters touches the player's party and characters too, which the snapshot
  # undoes as well.
  module Battle
    # What the map says after the battle, by the game's battle result.
    RESULTS = {
      0 => "You beat %s's team!",
      1 => "You left the friend battle against %s's team.",
      2 => "%s's team won.",
    }

    # What the map says when the battle could not start.
    FAILED = "The battle could not start, Multiplayer\\InGame.log says why."

    # What the map says after a mirror match, by the game's battle result.
    MIRROR_RESULTS = {
      0 => "You beat your own team!",
      1 => "You left the mirror match.",
      2 => "Your own team won.",
    }

    # The switch that turns off ero offers, a low-HP monster's offer of an H-scene for giving up,
    # and monsters opening conversations, by its name in the editor. They run the common event of
    # the enemy's id (2000 + id), which the friend's characters have none of.
    ERO_OFFERS_OFF = "No Seduction"

    # The switch's id in 3.06, for a translation that names it otherwise.
    ERO_OFFERS_OFF_ID = 86

    # Actions of the friend's characters logged per battle, the log holds few lines per session.
    LOGGED_ACTIONS = 12

    class << self
      # @return [String] the friend whose team is fought
      attr_reader :opponent
    end

    # @return [Boolean] whether a friend battle runs, until the map put the game back
    def self.running?
      @snapshot ? true : false
    end

    # @return [Boolean] whether the running battle is a mirror match
    def self.mirror?
      @mirror ? true : false
    end

    # Starts the battle from the map.
    #
    # @param opponent [String] the friend's name
    # @param members [Array<Team::Member>] the friend's team
    # @param mirror [Boolean] whether it is the player's own team
    def self.start(opponent, members, mirror)
      @snapshot = Marshal.dump(DataManager.make_save_contents)
      @globals = Marshal.dump(globals)
      @medals = Array($game_temp.instance_variable_get(:@gain_medals)).dup
      @opponent = opponent
      @mirror = mirror
      @failed = false
      @result = nil
      @logged_actions = 0

      troop_id = Opponents.add_troop
      $game_party.battle_members.each { |actor| actor.recover_all }
      $game_switches[$data_system.switches.index(ERO_OFFERS_OFF) || ERO_OFFERS_OFF_ID] = true
      $game_switches[NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE] = true if defined?(NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE)
      $game_temp.in_memory_battle = true
      BattleManager.setup(troop_id, true, true)

      opponents = Opponents.build(members, opponent)
      raise "nobody of #{opponent}'s team could be rebuilt" if opponents.empty?

      $game_troop.instance_variable_set(:@enemies, opponents)
      BattleManager.make_escape_ratio if BattleManager.respond_to?(:make_escape_ratio)
      check(opponents)
      MirrorReport.start(opponents) if mirror
      BattleManager.event_proc = Proc.new { |result| MGQ_PvpBattle::Battle.finished(result) }
      MGQ_MpSync.record_to_file if mirror && defined?(MGQ_MpSync)
      MGQ_MpSync.battle_started if defined?(MGQ_MpSync)
      SceneManager.call(Scene_Battle)
      MGQ_PvpBattle.log("started against #{opponent}'s team of #{opponents.size}")
    rescue => e
      MGQ_PvpBattle.log("could not start: #{e.class}: #{e.message}")
      @failed = true
      # The map would go on drawing the objects the snapshot replaces, so it is built anew.
      SceneManager.goto(Scene_Map) if running?
      restore
    end

    # Logs where a rebuilt character's stats or rates differ from what the friend's game showed.
    #
    # Both sides measure outside of battle, so only a difference in the rebuild shows.
    #
    # @param opponents [Array<Opponent>] the rebuilt characters, already in the troop
    def self.check(opponents)
      opponents.each do |opponent|
        differences = opponent.differences
        MGQ_PvpBattle.log("#{opponent.name} differs: #{differences.join(', ')}") unless differences.empty?
      end
    rescue => e
      MGQ_PvpBattle.log("could not check the rebuild: #{e.class}: #{e.message}")
    end

    # Reports whether a battler's action needs a target but finds none.
    #
    # Some skills aim only at one sex or, when they bind, only at Luka, which the game only ever
    # lets monsters use on the player's party. A team without such a target leaves them with
    # none, and the battle log would name a target that is not there.
    #
    # @param subject [Game_Battler] the battler about to act
    # @return [Boolean]
    def self.targetless?(subject)
      action = subject && subject.current_action
      item = action && action.item
      return false unless item && (item.for_opponent? || item.for_friend?)

      action.make_targets.compact.empty?
    rescue => e
      MGQ_PvpBattle.log("target check failed: #{e.class}: #{e.message}")
      false
    end

    # Logs an action of one of the friend's characters, with its HP, the first LOGGED_ACTIONS of a battle.
    #
    # @param battler [Opponent] the character
    # @param item [RPG::UsableItem] the skill or item it used
    def self.log_action(battler, item)
      @logged_actions = (@logged_actions || 0) + 1
      return if @logged_actions > LOGGED_ACTIONS

      MGQ_PvpBattle.log("#{battler.name} used #{item.id} #{item.name} at #{battler.hp}/#{battler.mhp} HP")
    rescue
    end

    # Notes how the battle ended. Called by the game when it does.
    #
    # @param result [Integer] 0 won, 1 left, 2 lost
    def self.finished(result)
      @result = result
    end

    # Puts the game back as it was before the battle and says how it went. Called when the map
    # starts again.
    def self.restore
      MGQ_MpSync.finish if defined?(MGQ_MpSync)
      return unless @snapshot

      contents = Marshal.load(@snapshot)
      saved_globals = Marshal.load(@globals)
      @snapshot = nil
      @globals = nil
      DataManager.extract_save_contents(contents)
      self.globals = saved_globals
      $game_temp.in_memory_battle = false
      $game_temp.clear_common_event
      # Medals earned in the battle are gone with the Library's, so their notices are too.
      $game_temp.instance_variable_set(:@gain_medals, @medals || [])
      # The game's Retry would start the friend battle again from its own snapshot.
      BattleManager.instance_variable_set(:@retry_data, nil)
      Opponents.remove
      $game_player.refresh
      $game_map.need_refresh = true
      $game_message.add(result_text)
    rescue => e
      MGQ_PvpBattle.log("could not put the game back: #{e.class}: #{e.message}")
    end

    # @return [String] what the map says about how the battle went
    def self.result_text
      return FAILED if @failed
      return MIRROR_RESULTS.fetch(@result, "The mirror match ended.") if @mirror

      format(RESULTS.fetch(@result, "The friend battle against %s's team ended."), @opponent)
    end

    # Drops a battle a reset interrupted. The title screen makes the save's objects anew, but keeps
    # the Library, system switches and affection all saves share, so those are put back.
    def self.forget
      self.globals = Marshal.load(@globals) if @globals
    rescue => e
      MGQ_PvpBattle.log("could not put the shared data back after a reset: #{e.class}: #{e.message}")
    ensure
      @snapshot = nil
      @globals = nil
      $game_temp.in_memory_battle = false if $game_temp
    end

    # @return [Array] the data all saves share: the Library, the system switches and the global
    #   system, which holds the affection
    def self.globals
      [$game_library, $game_system_switches, $game_global_system]
    end

    # @param values [Array] the data all saves share, see globals
    def self.globals=(values)
      $game_library, $game_system_switches, $game_global_system = values
    end

    # Runs a write of the system save with the shared data as it was before the battle, while a
    # friend battle runs. The game writes it at every scene change and when it closes.
    def self.as_before_for_system
      return yield unless running?

      current = globals
      begin
        self.globals = Marshal.load(@globals)
        yield
      ensure
        self.globals = current
      end
    end

    # Runs a write of a save file with the save and the shared data as they were before the
    # battle, while a friend battle runs, so nothing of the friend's team or the battle reaches it.
    def self.as_before_for_save
      return yield unless running?

      current = [DataManager.make_save_contents, globals]
      begin
        DataManager.extract_save_contents(Marshal.load(@snapshot))
        self.globals = Marshal.load(@globals)
        yield
      ensure
        DataManager.extract_save_contents(current[0])
        self.globals = current[1]
      end
    end
  end

  # What the friend battle screen says about the exchange.
  module Lobby
    # What the screen says before anything started.
    INTRO = [
      "Fight a friend's Frontline, each of you against the other's team.",
      "Host: invite a friend through the + in a Discord chat, or send",
      "them the join code. Join: copy their join code, then join with it.",
      "Or fight your own team in a mirror match.",
    ]

    # @param state [Hash] the exchange, see MGQ_Multiplayer::Link.state
    # @return [Array<String>] the lines to show
    def self.lines_for(state)
      lines = case state["state"]
              when "hosting"
                if state["code"]
                  ["Hosting, waiting for a friend . . .",
                   "Invite them through the + in a Discord chat, or send them the",
                   "join code, which is on your clipboard. Port #{MGQ_Multiplayer::PORT} has to be open."]
                else
                  ["Hosting . . . finding this PC's addresses."]
                end
              when "joining"
                ["Joining . . . swapping teams with your friend."]
              when "received"
                ["Your friend's team arrived."]
              when "failed"
                ["The friend battle broke off:", state["error"].to_s]
              else
                INTRO
              end
      state["invite"] == "1" ? ["A Discord invite to a friend battle is waiting."] + lines : lines
    end

    # The commands the screen offers.
    #
    # @param state [Hash] the exchange, see MGQ_Multiplayer::Link.state
    # @return [Array<Array>] a name and a symbol per command
    def self.commands_for(state)
      commands = []
      commands.push(["Accept the Discord invite", :join_invite]) if state["invite"] == "1"

      case state["state"]
      when "hosting"
        commands.push(["Copy the join code again", :copy], ["Stop hosting", :stop])
      when "joining"
        commands.push(["Stop joining", :stop])
      else
        commands.push(["Host a friend battle", :host], ["Join with the copied code", :join_clipboard])
        commands.push(["Fight your own team", :mirror])
      end

      commands.push(["Close", :cancel])
    end
  end
end

# The friend battle screen, opened from the map with F11 (MGQ_PvpBattle::KEY_CODE) or by a
# Discord invite.
#
# Named without "Battle", which the Discord mod reads as being in a fight.
class Scene_FriendLobby < Scene_MenuBase
  # Creates the windows and reads the exchange.
  def start
    super
    @info_window = Window_FriendLobbyInfo.new
    @command_window = Window_FriendLobbyCommand.new(@info_window.height)
    @command_window.set_handler(:host, method(:on_host))
    @command_window.set_handler(:join_clipboard, method(:on_join_clipboard))
    @command_window.set_handler(:join_invite, method(:on_join_invite))
    @command_window.set_handler(:copy, method(:on_copy))
    @command_window.set_handler(:stop, method(:on_stop))
    @command_window.set_handler(:mirror, method(:on_mirror))
    @command_window.set_handler(:cancel, method(:on_close))
    @frames = 0
    refresh_state
  end

  # Looks at the exchange every MGQ_PvpBattle::POLL_INTERVAL frames.
  def update
    super
    @frames += 1
    return if @frames < MGQ_PvpBattle::POLL_INTERVAL

    @frames = 0
    refresh_state
  end

  # Shows how the exchange stands, and goes back to the map once the friend's team arrived, which
  # starts the battle there.
  def refresh_state
    @state = MGQ_Multiplayer::Link.state
    @info_window.show(MGQ_PvpBattle::Lobby.lines_for(@state))
    @command_window.state = @state
    return_scene if @state["state"] == "received"
  rescue => e
    MGQ_PvpBattle.log("screen failed: #{e.class}: #{e.message}")
    return_scene
  end

  # Starts hosting.
  def on_host
    MGQ_Multiplayer::Link.host(MGQ_PvpBattle::Team.game, MGQ_PvpBattle::Team.build)
    after_command
  end

  # Joins with the join code on the clipboard.
  def on_join_clipboard
    MGQ_Multiplayer::Link.join_clipboard(MGQ_PvpBattle::Team.game, MGQ_PvpBattle::Team.build)
    after_command
  end

  # Joins the host of the Discord invite.
  def on_join_invite
    MGQ_Multiplayer::Link.join_invite(MGQ_PvpBattle::Team.game, MGQ_PvpBattle::Team.build)
    after_command
  end

  # Puts the join code on the clipboard again.
  def on_copy
    MGQ_Multiplayer::Link.copy_code ? Sound.play_ok : Sound.play_buzzer
    after_command
  end

  # Stops hosting or joining.
  def on_stop
    MGQ_Multiplayer::Link.cancel
    after_command
  end

  # Goes back to the map, which starts the mirror match there.
  def on_mirror
    MGQ_PvpBattle.request_mirror
    return_scene
  end

  # Closes the screen. Hosting and joining go on meanwhile, a failure is cleared.
  def on_close
    MGQ_Multiplayer::Link.cancel if @state && @state["state"] == "failed"
    return_scene
  end

  # Shows the result of a command right away and takes the next one.
  def after_command
    refresh_state
    @command_window.activate
  end
end

# The lines above the friend battle screen's commands.
class Window_FriendLobbyInfo < Window_Base
  # Lines the window has room for.
  LINES = 4

  # Creates the window across the top of the screen, empty.
  def initialize
    super(0, 0, Graphics.width, fitting_height(LINES))
    @lines = []
  end

  # Draws the lines, if they changed.
  #
  # @param lines [Array<String>] the lines
  def show(lines)
    return if lines == @lines

    @lines = lines
    contents.clear
    lines.first(LINES).each_with_index do |line, index|
      draw_text(0, index * line_height, contents_width, line_height, line)
    end
  end
end

# The friend battle screen's commands, which follow how the exchange stands.
class Window_FriendLobbyCommand < Window_Command
  # Width of the window.
  WIDTH = 360

  # @param y [Integer] the top edge, below the lines
  def initialize(y)
    @state = { "state" => "idle" }
    super(0, y)
    self.x = (Graphics.width - width) / 2
  end

  # @return [Integer] the window's width
  def window_width
    WIDTH
  end

  # Offers the commands of a state, if they changed.
  #
  # @param state [Hash] the exchange, see MGQ_Multiplayer::Link.state
  def state=(state)
    commands = MGQ_PvpBattle::Lobby.commands_for(state)
    return if commands == @commands

    @state = state
    clear_command_list
    make_command_list
    self.height = window_height
    refresh
    select(0) if index >= item_max
  end

  # Lists the commands of the state.
  def make_command_list
    @commands = MGQ_PvpBattle::Lobby.commands_for(@state)
    @commands.each { |name, symbol| add_command(name, symbol) }
  end
end

# Game hooks.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_PvpBattle.hookable?
  # The map checks for the key and the exchange where the game checks its own keys: only while no
  # event, message or scene change is in the way.
  begin
    class Scene_Map
      alias mgq_pvp_battle_update_scene update_scene
      def update_scene
        mgq_pvp_battle_update_scene
        MGQ_PvpBattle.on_map unless scene_changing?
      end

      # The map starts again after a friend battle, and the game is put back first, so the map is
      # built from what it was before.
      alias mgq_pvp_battle_start start
      def start
        MGQ_PvpBattle::Battle.restore if MGQ_PvpBattle::Battle.running?
        mgq_pvp_battle_start
      end
    end
  rescue => e
    MGQ_PvpBattle.log("map hooks FAILED: #{e.class}: #{e.message}")
  end

  # The title screen interrupts a battle only through a reset, which loads the game data anew.
  begin
    class Scene_Title
      alias mgq_pvp_battle_start start
      def start
        MGQ_PvpBattle::Battle.forget
        mgq_pvp_battle_start
      end
    end
  rescue => e
    MGQ_PvpBattle.log("title hook FAILED: #{e.class}: #{e.message}")
  end

  # An action without a target is left out the way the game leaves out one without a skill.
  begin
    class Scene_Battle
      alias mgq_pvp_battle_use_item use_item
      def use_item
        if MGQ_PvpBattle::Battle.running? && MGQ_PvpBattle::Battle.targetless?(@subject)
          @log_window.display_target_empty(@subject)
          return true
        end
        mgq_pvp_battle_use_item
      end
    end
  rescue => e
    MGQ_PvpBattle.log("use_item hook FAILED: #{e.class}: #{e.message}")
  end

  # A friend battle gives no EXP, gold or drops. The game already skips them, but other mods, such
  # as a victory screen, read the troop's totals anyway, which the friend's characters cannot give.
  begin
    class Game_Troop
      [:exp_total, :class_exp_total, :gold_total].select { |name| method_defined?(name) }.each do |name|
        alias_method "mgq_pvp_battle_#{name}", name
        define_method(name) do
          MGQ_PvpBattle::Battle.running? ? 0 : send("mgq_pvp_battle_#{name}")
        end
      end

      alias mgq_pvp_battle_make_drop_items make_drop_items
      def make_drop_items
        MGQ_PvpBattle::Battle.running? ? [] : mgq_pvp_battle_make_drop_items
      end
    end
  rescue => e
    MGQ_PvpBattle.log("troop hooks FAILED: #{e.class}: #{e.message}")
  end

  # The friend's characters show the Library's picture. The original runs only for other battlers.
  begin
    class Sprite_Battler
      alias mgq_pvp_battle_update_bitmap update_bitmap
      def update_bitmap
        stand_in = MGQ_PvpBattle::Pictures.stand_in_for(@battler)
        return mgq_pvp_battle_update_bitmap unless stand_in

        self.bitmap = stand_in if bitmap != stand_in
      end

      # The game's enemy HP bars only draw for monsters, so the friend's characters get theirs here.
      # A dead one turns into a grey, see-through silhouette once its defeat flash ends, and back
      # once it is revived. The game marks it dead when the hit lands, before the battle log tells
      # of the defeat, so the flash rather than death starts the silhouette. Every sprite effect
      # makes the picture opaque again when it starts, so the silhouette's opacity is set every frame.
      alias mgq_pvp_battle_update update
      def update
        mgq_pvp_battle_update
        return unless @battler.is_a?(MGQ_PvpBattle::Opponent)

        begin
          update_hp_bar if respond_to?(:update_hp_bar, true)
        rescue => e
          MGQ_PvpBattle.log("HP bar failed: #{e.class}: #{e.message}") unless @mgq_pvp_battle_bar_failed
          @mgq_pvp_battle_bar_failed = true
        end

        begin
          dead = @battler.dead?
          @mgq_pvp_battle_defeat_shown = dead && (@mgq_pvp_battle_defeat_shown || @effect_type == :whiten)
          silhouette = @mgq_pvp_battle_defeat_shown && @effect_type != :whiten
          if silhouette != @mgq_pvp_battle_silhouette
            @mgq_pvp_battle_silhouette = silhouette
            self.tone = Tone.new(0, 0, 0, silhouette ? MGQ_PvpBattle::Opponent::SILHOUETTE_GRAY : 0)
            self.opacity = 255 unless silhouette
          end
          self.opacity = MGQ_PvpBattle::Opponent::SILHOUETTE_OPACITY if silhouette
        rescue => e
          MGQ_PvpBattle.log("silhouette failed: #{e.class}: #{e.message}") unless @mgq_pvp_battle_silhouette_failed
          @mgq_pvp_battle_silhouette_failed = true
        end
      end
    end
  rescue => e
    MGQ_PvpBattle.log("battler picture hooks FAILED: #{e.class}: #{e.message}")
  end

  # Nothing of a friend battle reaches the disk: while one runs, every save write gets the save
  # and the shared data as they were before it. The system save is written at every scene change
  # and when the game closes, the others only if something saves in the middle of a battle.
  begin
    class << DataManager
      alias mgq_pvp_battle_save_system save_system
      def save_system
        MGQ_PvpBattle::Battle.as_before_for_system { mgq_pvp_battle_save_system }
      end

      [:save_game_without_rescue, :auto_save_game_without_rescue, :save_game_backup_without_rescue].each do |name|
        next unless method_defined?(name)

        alias_method "mgq_pvp_battle_#{name}", name
        define_method(name) do |*args|
          MGQ_PvpBattle::Battle.as_before_for_save { send("mgq_pvp_battle_#{name}", *args) }
        end
      end
    end
  rescue => e
    MGQ_PvpBattle.log("save hooks FAILED: #{e.class}: #{e.message}")
  end

  # The friend's characters check the conditions of their automatic skills from their own side. The
  # original runs only for other battlers.
  begin
    class << BattleManager
      alias mgq_pvp_battle_auto_skill_per _auto_skill_per
      def _auto_skill_per(skills, battler)
        return mgq_pvp_battle_auto_skill_per(skills, battler) unless battler.is_a?(MGQ_PvpBattle::Opponent)

        battler.firing_auto_skills(skills)
      end
    end
  rescue => e
    MGQ_PvpBattle.log("automatic skill hook FAILED: #{e.class}: #{e.message}")
  end

  # A mirror match's report adds how both teams look once the first turn starts.
  begin
    class << BattleManager
      alias mgq_pvp_battle_turn_start turn_start
      def turn_start
        mgq_pvp_battle_turn_start
        MGQ_PvpBattle::MirrorReport.turn_started if MGQ_PvpBattle::Battle.running?
      end
    end
  rescue => e
    MGQ_PvpBattle.log("turn hook FAILED: #{e.class}: #{e.message}")
  end

  # Discord shows whose team the player fights, through the Discord mod's bridge when it is installed.
  begin
    MGQ_Discord::Bridge.add_status { |scene| MGQ_PvpBattle.status_fields(scene) } if MGQ_Multiplayer::Discord.available?
  rescue => e
    MGQ_PvpBattle.log("status source FAILED: #{e.class}: #{e.message}")
  end
end
