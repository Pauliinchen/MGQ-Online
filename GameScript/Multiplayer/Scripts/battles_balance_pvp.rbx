#----------------------------------------------------------------
#  battles_balance_pvp.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Took the balance's values and what a hit and a defense wall leave from the rules in C#
#      Paulinchen  2026-10-23: Deleted the switch that never turned the balance off
#      Paulinchen  2026-10-07: Logged the balance's changes per character, its lowered hits and its end
#      Paulinchen  2026-10-06: Added unbalanced and dropped active?
#      Paulinchen  2026-10-04: Renamed from mp_balance_pvp.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The balance of a PvP battle, as the rules in C# work it out (PvpBalance): while it runs, skills
# deal what they deal in a monster's hands, every character has more HP, one action takes only a
# part of a character's HP however strong it is, and what kept a character from all harm keeps it
# from most of it.
#
# The host's game works the battle out and the other game only shows it.
module MGQ_MpBalancePvp
  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "pvp balance"

  # The topic of the balance's values, which the stat hooks apply many times a frame.
  RULES_TOPIC = "pvp.rules"

  # The topic that works out what a hit deals or heals.
  HIT_TOPIC = "pvp.hit"

  # The topic that works out what gets through a defense wall.
  WALL_TOPIC = "pvp.wall"

  # The id of max HP among the game's stats.
  MAX_HP = 0

  # Runs a block with the stats as the game works them out, such as a check of a character against
  # what its owner's game measured outside a battle.
  #
  # @yield The reading of the stats.
  # @return [Object] What the block returns.
  def self.unbalanced
    was = @active
    @active = false
    yield
  ensure
    @active = was
  end

  # Starts the balance for a PvP battle with the values the rules in C# tell (topic pvp.rules) and
  # fills the HP it adds.
  #
  # @param battlers [Array<Game_Battler>] The characters of both teams.
  def self.begin(battlers)
    rules = MGQ_Multiplayer::Bridge.call!(RULES_TOPIC)
    @hp_rate = rules["hp_rate"]
    @monster_formulas = rules["monster_formulas"]
    @avoid_ceiling = rules["avoid_ceiling"].to_f
    @element_floor = rules["element_floor"].to_f
    @taken_floor = rules["taken_floor"].to_f
    @active = true
    @taken = {}
    battlers.each { |battler| battler.hp = battler.mhp unless battler.dead? }
    log("on for #{battlers.size} characters: HP x#{@hp_rate}#{', monster formulas' if @monster_formulas}")
    battlers.each { |battler| log_changes(battler) }
  rescue => e
    @active = false
    log("could not start: #{e.class}: #{e.message}")
  end

  # Logs what the balance changes of a character as it starts: its max HP, and the rates the
  # balance holds to its floors and ceilings.
  #
  # @param battler [Game_Battler] The character.
  def self.log_changes(battler)
    own = unbalanced { rates_of(battler) }
    now = rates_of(battler)
    changes = own.keys.reject { |name| own[name] == now[name] }.map { |name| "#{name} #{own[name]} -> #{now[name]}" }
    changes << "evasion #{own['evasion']} held to #{@avoid_ceiling}" if own["evasion"].to_f > @avoid_ceiling
    changes << "magic reflection #{own['magic reflection']} held to #{@avoid_ceiling}" if own["magic reflection"].to_f > @avoid_ceiling
    log("#{battler.name rescue '?'}#{" (#{battler.id})" if battler.respond_to?(:id)}: #{changes.join(', ')}, #{battler.hp} HP")
  rescue => e
    log("#{battler.name rescue '?'}: changes unknown (#{e.class})")
  end

  # Reads the values of a character the balance changes, for the log.
  #
  # @param battler [Game_Battler] The character.
  # @return [Hash{String => Numeric}] Each value by its name.
  def self.rates_of(battler)
    rates = { "max HP" => battler.mhp }
    { "physical damage taken" => :pdr, "magical damage taken" => :mdr, "sure-hit damage taken" => :certain_damage_rate,
      "evasion" => :eva, "magic reflection" => :mrf }.each do |name, method|
      rates[name] = battler.send(method).to_f.round(2) if battler.respond_to?(method)
    end
    rates
  end

  # Ends the balance.
  def self.finish
    log("off") if @active
    @active = false
    @taken = {}
  end

  # Notes that a new action starts, which counts its damage and healing anew.
  def self.action_started
    @taken = {}
  end

  # Lowers what a hit deals or heals while the balance applies, as the rules in C# work it out
  # (topic pvp.hit) from what the same action dealt or healed the target before.
  #
  # @param battler [Game_Battler] The target.
  # @param value [Numeric] The damage as the game works it out, negative for healing.
  # @return [Numeric] The damage in the battle.
  def self.damage(battler, value)
    return value unless @active && value != 0

    mhp = battler.mhp
    return value unless mhp > 0

    key = [battler.__id__, value < 0]
    before = @taken[key] || 0.0
    @taken[key] = before + value.abs
    left = MGQ_Multiplayer::Bridge.call(HIT_TOPIC, "max_hp" => mhp, "before" => before.to_s, "value" => value.abs.to_s)
    return value unless left

    left = left.to_f
    note_hit(battler, value, left) if left.round < value.abs
    value < 0 ? -left : left
  end

  # Logs a hit or healing the balance lowered.
  #
  # @param battler [Game_Battler] The target.
  # @param value [Numeric] The damage as the game works it out, negative for healing.
  # @param left [Numeric] What the balance leaves of it.
  def self.note_hit(battler, value, left)
    log("#{value < 0 ? 'healing' : 'hit'} on #{battler.name rescue '?'} lowered from #{value.abs.round} -> #{left.round} of #{battler.mhp} max HP")
  rescue
  end

  # Raises a stat of a character while the balance applies.
  #
  # @param param_id [Integer] The stat's id.
  # @param value [Integer] The stat as the game works it out.
  # @return [Integer] The stat in the battle.
  def self.stat(param_id, value)
    @active && param_id == MAX_HP ? value * @hp_rate : value
  end

  # Lowers a stat a damage formula reads while the balance applies.
  #
  # A skill that deals a share of max HP would otherwise grow with the HP the balance adds.
  #
  # @param param_id [Integer] The stat's id.
  # @param value [Integer] The stat in the battle.
  # @return [Integer] The stat the formula works with.
  def self.formula_stat(param_id, value)
    @active && param_id == MAX_HP ? value / @hp_rate : value
  end

  # Reports whether a character's skills use their formulas for monsters.
  #
  # @param monster [Boolean] Whether they do as the game works it out.
  # @return [Boolean] Whether they do in the battle.
  def self.monster_formulas?(monster)
    monster || (@active && @monster_formulas ? true : false)
  end

  # Limits how little of a hit a character takes while the balance applies.
  #
  # @param rate [Float] The share of physical, magical or sure-hit damage it takes as the game works it out.
  # @return [Float] The share in the battle.
  def self.taken_rate(rate)
    @active && rate < @taken_floor ? @taken_floor : rate
  end

  # Limits the chance a character evades or reflects a hit with while the balance applies.
  #
  # @param chance [Float] The chance as the game works it out.
  # @return [Float] The chance in the battle.
  def self.avoidance(chance)
    @active && chance > @avoid_ceiling ? @avoid_ceiling : chance
  end

  # Limits how much of an attack's damage its elements take away while the balance applies.
  #
  # @param item [RPG::UsableItem] The skill or item.
  # @param rate [Float] The rate as the game works it out, negative for an absorbed element.
  # @return [Float] The rate in the battle.
  def self.element_rate(item, rate)
    @active && item.for_opponent? && rate < @element_floor ? @element_floor : rate
  end

  # Works out what a defense wall leaves of a hit while the balance applies, as the rules in C#
  # work it out (topic pvp.wall).
  #
  # @param battler [Game_Battler] The character behind the wall.
  # @param damage [Numeric] The hit before the wall.
  # @param left [Numeric] The hit after the wall as the game works it out.
  # @return [Numeric] The hit after the wall in the battle.
  def self.wall(battler, damage, left)
    return left unless @active && left == 0 && damage > 0

    through = MGQ_Multiplayer::Bridge.call(WALL_TOPIC, "max_hp" => battler.mhp, "damage" => damage.to_s)
    return left unless through

    through = damage.is_a?(Integer) ? through.to_f.to_i : through.to_f
    note_wall(battler, damage, through)
    through
  end

  # Logs a hit a defense wall took only a share of.
  #
  # @param battler [Game_Battler] The character behind the wall.
  # @param damage [Numeric] The hit before the wall.
  # @param through [Numeric] What gets through.
  def self.note_wall(battler, damage, through)
    log("#{battler.name rescue '?'}'s defense wall held back #{damage - through} of a hit of #{damage} instead of all of it, #{through} gets through")
  rescue
  end

  # Installs the battle hooks.
  #
  # The game's plugins load after the Patch folder and define battle methods anew, so the hooks go
  # in once every plugin is in.
  def self.install
    return if @installed

    @installed = true
    install_stats
    install_formulas
    MGQ_MpHooks.around(Game_Battler, :enemy_calculation?, "battles_balance_pvp") { |_battler, _args, original| MGQ_MpBalancePvp.monster_formulas?(original.call) }
    MGQ_MpHooks.before(Scene_Battle, :use_item, "battles_balance_pvp") { MGQ_MpBalancePvp.action_started }
    [:pdr, :mdr, :certain_damage_rate].each do |name|
      MGQ_MpHooks.around(Game_BattlerBase, name, "battles_balance_pvp") { |_battler, _args, original| MGQ_MpBalancePvp.taken_rate(original.call) }
    end
    MGQ_MpHooks.around(Game_Battler, :apply_guard, "battles_balance_pvp") { |battler, _args, original| MGQ_MpBalancePvp.damage(battler, original.call) }
    MGQ_MpHooks.around(Game_Battler, :item_eva, "battles_balance_pvp") { |_battler, _args, original| MGQ_MpBalancePvp.avoidance(original.call) }
    MGQ_MpHooks.around(Game_Battler, :item_mrf, "battles_balance_pvp") { |_battler, _args, original| MGQ_MpBalancePvp.avoidance(original.call) }
    MGQ_MpHooks.around(Game_Battler, :item_element_rate, "battles_balance_pvp") { |_battler, args, original| MGQ_MpBalancePvp.element_rate(args[1], original.call) }
    MGQ_MpHooks.around(Game_Battler, :apply_defense_wall, "battles_balance_pvp") { |battler, args, original| MGQ_MpBalancePvp.wall(battler, args[0], original.call) }
  rescue => e
    log("battle hooks FAILED: #{e.class}: #{e.message}")
  end

  # Wraps the game's stats.
  #
  # The game reads them many times a frame, so the wrap is a plain alias.
  def self.install_stats
    Game_BattlerBase.class_eval do
      alias_method :mgq_mp_balance_pvp_param, :param

      # Works a stat out, raised while the PvP balance applies.
      #
      # @param param_id [Integer] The stat's id.
      # @return [Integer] The stat.
      def param(param_id)
        MGQ_MpBalancePvp.stat(param_id, mgq_mp_balance_pvp_param(param_id))
      end
    end
  end

  # Wraps the stats a damage formula reads of the two characters.
  def self.install_formulas
    return log("the game has no DamageEvalBattler, so skills dealing a share of max HP grow with the HP") unless defined?(DamageEvalBattler)

    # The class builds on BasicObject, so the constants need their full path and the wrap cannot
    # go through send.
    DamageEvalBattler.class_eval do
      alias_method :mgq_mp_balance_pvp_battler_param, :__battler_param

      # Reads a stat of the character for a damage formula, as it is without the PvP balance.
      #
      # @param param_id [Integer] The stat's id.
      # @return [Integer] The stat.
      def __battler_param(param_id)
        ::MGQ_MpBalancePvp.formula_stat(param_id, mgq_mp_balance_pvp_battler_param(param_id))
      end
      private :__battler_param
    end
  end
end

# Game hooks, through core_hooks.rbx.

begin
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_balance_pvp") { MGQ_MpBalancePvp.install }
rescue => e
  MGQ_MpBalancePvp.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
end
