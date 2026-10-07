#----------------------------------------------------------------
#  battles_balance_pvp.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Logged what the balance changes per character as it starts, each hit it lowers and its end
#      Paulinchen  2026-10-06: Let a check read the stats without the balance, and dropped active?, which only the tests asked
#      Paulinchen  2026-10-04: Renamed from mp_balance_pvp.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The balance of a PvP battle. The game balances a character against monsters: it deals many times
# its own HP in one hit, and stays alive by not being hit at all. Between two players that makes the
# first hit or an untouchable team decide the battle, so while a PvP battle runs, skills deal what
# they deal in a monster's hands, every character has more HP, one action takes only a part of a
# character's HP however strong it is, and what kept a character from all harm keeps it from most
# of it.
#
# Both games must use the same values, since the host's game works the battle out and the other
# game shows it, so they are constants of the release and no setting.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBalancePvp
  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "pvp balance"

  # Turns the balance off without uninstalling it.
  ENABLED = true

  # Whether a skill deals what it deals in a monster's hands. Most skills carry a second formula
  # for monsters, which the game balanced against a character's HP.
  MONSTER_FORMULAS = true

  # How many times its max HP a character has, a whole number.
  HP_RATE = 4

  # The share of a character's max HP up to which one action's damage or healing counts in full.
  DAMAGE_KNEE = 0.2

  # The share of a character's max HP that one action's damage or healing stays below, however
  # large it is. A late-game hit deals millions of times its target's HP, which no amount of added
  # HP makes up for.
  DAMAGE_LIMIT = 0.6

  # The highest chance a character evades or reflects a hit with.
  AVOID_CEILING = 0.75

  # The lowest share of an attack's damage its elements leave, for a character that takes none of
  # an element or absorbs it.
  ELEMENT_FLOOR = 0.25

  # The lowest share of a hit a character takes, for one whose states or abilities let it take no
  # physical, magical or sure-hit damage at all.
  DAMAGE_RATE_FLOOR = 0.25

  # The share of its max HP a character's defense wall takes off one hit.
  WALL_SHARE = 0.25

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

  # Starts the balance for a PvP battle and fills the HP it adds.
  #
  # @param battlers [Array<Game_Battler>] The characters of both teams.
  def self.begin(battlers)
    return unless ENABLED

    @active = true
    @taken = {}
    battlers.each { |battler| battler.hp = battler.mhp unless battler.dead? }
    log("on for #{battlers.size} characters: HP x#{HP_RATE}#{', monster formulas' if MONSTER_FORMULAS}")
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
    changes << "evasion #{own['evasion']} held to #{AVOID_CEILING}" if own["evasion"].to_f > AVOID_CEILING
    changes << "magic reflection #{own['magic reflection']} held to #{AVOID_CEILING}" if own["magic reflection"].to_f > AVOID_CEILING
    log("#{battler.name rescue '?'}#{" (#{battler.id})" if battler.respond_to?(:id)}: #{changes.join(', ')}, #{battler.hp} HP")
  rescue => e
    log("#{battler.name rescue '?'}: changes unknown (#{e.class})")
  end

  # Reads the values of a character the balance changes, for Multiplayer InGame.log.
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

  # Lowers what a hit deals or heals while the balance applies. Up to DAMAGE_KNEE of the target's
  # max HP counts in full, beyond that ever less, and an action's hits on one target count together,
  # so a skill of many hits takes no more than one strong hit.
  #
  # @param battler [Game_Battler] The target.
  # @param value [Numeric] The damage as the game works it out, negative for healing.
  # @return [Numeric] The damage in the battle.
  def self.damage(battler, value)
    return value unless @active && value != 0

    mhp = battler.mhp.to_f
    return value unless mhp > 0

    key = [battler.__id__, value < 0]
    before = @taken[key] || 0.0
    after = before + value.abs
    @taken[key] = after
    left = mhp * (share(after / mhp) - share(before / mhp))
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

  # Works out the share of max HP an action takes or gives for the share it would without the
  # balance.
  #
  # @param raw [Float] The share without the balance, which may be many times the max HP.
  # @return [Float] The share in the battle, below DAMAGE_LIMIT.
  def self.share(raw)
    return raw if raw <= DAMAGE_KNEE

    DAMAGE_KNEE + (DAMAGE_LIMIT - DAMAGE_KNEE) * (1.0 - 1.0 / (1.0 + Math.log10(raw / DAMAGE_KNEE)))
  end

  # Raises a stat of a character while the balance applies.
  #
  # @param param_id [Integer] The stat's id.
  # @param value [Integer] The stat as the game works it out.
  # @return [Integer] The stat in the battle.
  def self.stat(param_id, value)
    @active && param_id == MAX_HP ? value * HP_RATE : value
  end

  # Lowers a stat a damage formula reads while the balance applies.
  # A skill that deals a share of max HP would otherwise grow with the HP the balance adds.
  #
  # @param param_id [Integer] The stat's id.
  # @param value [Integer] The stat in the battle.
  # @return [Integer] The stat the formula works with.
  def self.formula_stat(param_id, value)
    @active && param_id == MAX_HP ? value / HP_RATE : value
  end

  # Reports whether a character's skills use their formulas for monsters.
  #
  # @param monster [Boolean] Whether they do as the game works it out.
  # @return [Boolean] Whether they do in the battle.
  def self.monster_formulas?(monster)
    monster || (@active && MONSTER_FORMULAS ? true : false)
  end

  # Limits how little of a hit a character takes while the balance applies.
  #
  # @param rate [Float] The share of physical, magical or sure-hit damage it takes as the game works it out.
  # @return [Float] The share in the battle.
  def self.taken_rate(rate)
    @active && rate < DAMAGE_RATE_FLOOR ? DAMAGE_RATE_FLOOR : rate
  end

  # Limits the chance a character evades or reflects a hit with while the balance applies.
  #
  # @param chance [Float] The chance as the game works it out.
  # @return [Float] The chance in the battle.
  def self.avoidance(chance)
    @active && chance > AVOID_CEILING ? AVOID_CEILING : chance
  end

  # Limits how much of an attack's damage its elements take away while the balance applies.
  #
  # @param item [RPG::UsableItem] The skill or item.
  # @param rate [Float] The rate as the game works it out, negative for an absorbed element.
  # @return [Float] The rate in the battle.
  def self.element_rate(item, rate)
    @active && item.for_opponent? && rate < ELEMENT_FLOOR ? ELEMENT_FLOOR : rate
  end

  # Works out what a defense wall leaves of a hit while the balance applies.
  #
  # @param battler [Game_Battler] The character behind the wall.
  # @param damage [Numeric] The hit before the wall.
  # @param left [Numeric] The hit after the wall as the game works it out.
  # @return [Numeric] The hit after the wall in the battle.
  def self.wall(battler, damage, left)
    return left unless @active && left == 0 && damage > 0

    through = [damage - (battler.mhp * WALL_SHARE).to_i, 0].max
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

  # Installs the battle hooks. The game's plugins load after the Patch folder and define battle
  # methods anew, so the hooks go in once every plugin is in.
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

  # Wraps the game's stats. The game reads them many times a frame, so the wrap is a plain alias.
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
  # Installs the battle hooks as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_balance_pvp") { MGQ_MpBalancePvp.install }
rescue => e
  MGQ_MpBalancePvp.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
end
