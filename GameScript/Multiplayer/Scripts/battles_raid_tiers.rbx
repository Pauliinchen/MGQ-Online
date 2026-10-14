#----------------------------------------------------------------
#  battles_raid_tiers.rbx
#
#  Changelog:
#      Paulinchen  2026-10-13: Created
#
#----------------------------------------------------------------

# The raid bosses outside Raid Worlds: in a Classic world whose creator ticked Raid Bosses, and in
# single player while the player turned Raid Bosses on in the Mod Config (MGQ Online SP), each story
# boss fights with the stat factors of its tier (MGQ_MpRaidBosses::TIERS), in every battle anew:
# no relay keeps its HP and nothing regenerates. The same fights count as in a Raid World (see
# MGQ_MpRaidPool.refusal): the last phase of a boss the player's story has not beaten, started by
# its map event, never a Hades rematch, a Colosseum battle or a Great Decision fight. ui_raid_bar.rbx
# draws its bars.
#
# In a co-op battle the host decides and its invite carries INVITE_FIELD, so every guest raises the
# same enemies. A Raid World never reaches this script's battles: active? and kind_of refuse there.
#
# It must work without any connection, so it asks the DLL nothing at all.
module MGQ_MpRaidTiers
  # The setting in Player.ini that turns the raid bosses on in single player with 1.
  SETTING = "sp_raid_bosses"

  # The key of the Mod Config row that turns the raid bosses on and off in single player, which
  # ui_single_player.rbx adds.
  OPTION = :mp_sp_raid_bosses

  # The name of the Mod Config row that turns the raid bosses on and off in single player.
  OPTION_NAME = "Raid Bosses"

  # The help of the Mod Config row that turns the raid bosses on and off in single player.
  OPTION_HELP = "On: outside a world, story bosses fight as raid bosses of their tier, with far more HP\n" \
                "and defense, and show an HP bar. A Classic world decides this for itself."

  # The field an invite, or a request to lead, adds with 1 when its battle fights its boss at its
  # tier, see invite_fields.
  INVITE_FIELD = "tiers"

  # A battle whose boss fights at its tier.
  #
  # @!attribute troop [Integer] The troop.
  # @!attribute own [Integer] How many enemies the troop's setup made, which come first in the troop.
  # @!attribute tier [Integer] The boss's tier, see MGQ_MpRaidBosses::TIERS.
  Fight = Struct.new(:troop, :own, :tier)

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "raid tiers"

  # Forgets every battle, as at the title screen.
  def self.forget
    @fight = nil
    @lost = nil
    @invited = nil
    @at_command = false
    @retrying = false
    @scaled = []
    @scaled_tier = nil
  end

  # Reports whether the story bosses fight as raid bosses now: never in a Raid World, whose pools
  # are battles_raid_pool.rbx's; in a Classic world as its creator set it; else as the player set it
  # for single player.
  #
  # @return [Boolean] Whether they do.
  def self.active?
    return false if MGQ_MpCoop::Scope.raid?

    MGQ_MpOverworldSync.in_world? ? MGQ_MpWorld.raid_bosses? : single_player?
  rescue
    false
  end

  # Reports whether the player turned the raid bosses on for single player, as Player.ini keeps it,
  # off until they turn it on.
  #
  # @return [Boolean] Whether they did.
  def self.single_player?
    @single_player = MGQ_Multiplayer::Player.setting(SETTING).to_s == "1" if @single_player.nil?
    @single_player
  end

  # Turns the raid bosses on or off for single player and keeps the choice in Player.ini.
  #
  # @param on [Boolean] Whether they are on.
  def self.choose(on)
    @single_player = on ? true : false
    MGQ_Multiplayer::Player.store(SETTING, @single_player ? 1 : 0)
    log("raid bosses in single player are #{@single_player ? 'on' : 'off'}")
  rescue => e
    log("keeping whether raid bosses are on in single player FAILED: #{e.class}: #{e.message}")
  end

  # Tells the battle whose boss fights at its tier now.
  #
  # @return [Fight, nil] The battle, nil for none.
  def self.fight
    @fight
  end

  # Runs the map's interpreter, noting that its commands run, which are the story's.
  #
  # @return [Object] What the block returns.
  def self.in_map
    was = @in_map
    @in_map = true
    yield
  ensure
    @in_map = was
  end

  # Runs an event's battle command, noting that the battle set up next is the event's.
  #
  # @return [Object] What the block returns.
  def self.at_command
    @at_command = true
    yield
  ensure
    @at_command = false
  end

  # Runs the game's retry of a lost battle, noting that the battle set up next is a retry.
  #
  # @return [Object] What the block returns.
  def self.retrying
    @retrying = true
    yield
  ensure
    @retrying = false
  end

  # Tells how a battle about to be set up, or just set up, fights its boss at its tier.
  #
  # @param troop_id [Integer, String] The battle's troop.
  # @return [Symbol, nil] :retry for the game's retry of such a battle that was lost, :invited for
  #   one a host's invite or a member's request marked, :event for a story boss's battle its map
  #   event started; nil for none, always in a Raid World.
  def self.kind_of(troop_id)
    troop = troop_id.to_i
    return nil if MGQ_MpCoop::Scope.raid?
    return :retry if @retrying && @lost && @lost.troop == troop
    return :invited if @invited == troop
    return nil unless @at_command && @in_map && active? && MGQ_MpRaidBosses.boss?(troop)
    return nil unless $game_map.interpreter.event_id > 0

    refusal(troop) ? nil : :event
  end

  # Finds why a story boss battle keeps the boss as the game has it, by the rules of a Raid World's
  # pools.
  #
  # @param troop [Integer] The troop.
  # @return [String, nil] Why, nil when the boss fights at its tier.
  def self.refusal(troop)
    pool = MGQ_MpRaidPool
    boss = MGQ_MpRaidBosses.at(troop)
    return "it is no raid boss" unless boss
    return "an earlier phase of its fight" unless MGQ_MpRaidBosses.last_phase?(troop)
    return "a fight raid bosses leave out: #{pool::UNPOOLED[troop]}" if pool::UNPOOLED.key?(troop)
    return "a Hades rematch" if pool.hades?
    return "a Colosseum battle" if $game_switches[pool::COLOSSEUM_SWITCH]
    return "the story beat #{boss.milestone} already" if pool.beaten?(boss)

    MGQ_MpRaidBosses.tier(troop) ? nil : "it has no tier"
  end

  # Reports whether a troop's battle shows a bar on the map: raid bosses are on, and it is the last
  # phase of a boss the player's story has not beaten, outside the Hades rematches and the Colosseum.
  #
  # @param troop [Integer] The troop.
  # @return [Boolean] Whether it does.
  def self.shown_troop?(troop)
    active? && refusal(troop.to_i).nil?
  end

  # Decides whether the battle just set up fights its boss at its tier, and raises its enemies.
  # Called after BattleManager.setup.
  #
  # @param troop_id [Integer] The battle's troop.
  def self.set_up(troop_id)
    troop = troop_id.to_i
    kind = kind_of(troop)
    explain = kind.nil? && @at_command && @in_map && MGQ_MpRaidBosses.boss?(troop) && active?
    lost = @lost
    @at_command = false
    @invited = nil
    @fight = nil
    @lost = nil
    @scaled = []
    @scaled_tier = nil
    unless kind
      reason = explain ? refusal(troop) || ($game_map.interpreter.event_id > 0 ? nil : "a common event of its own started it") : nil
      return reason ? log("troop #{troop} keeps its boss as the game has it: #{reason}") : nil
    end

    own = kind == :retry ? lost.own : MGQ_MpRaidPool.own_count(troop)
    @fight = Fight.new(troop, own, MGQ_MpRaidBosses.tier(troop))
    scale(@fight)
    log("battle against troop #{troop} (#{kind}) fights its boss at tier #{@fight.tier}: " \
        "#{MGQ_MpRaidPool.own_enemies(own).compact.map { |enemy| "#{enemy.name} #{enemy.hp}/#{enemy.mhp}" }.join(', ')}")
  rescue => e
    @fight = nil
    log("deciding on troop #{troop_id} failed: #{e.class}: #{e.message}")
  end

  # Gives a battle's own enemies their tier's stats (see stat), each new one keeping the share of
  # its max HP it had.
  #
  # @param fight [Fight] The battle.
  def self.scale(fight)
    enemies = MGQ_MpRaidPool.own_enemies(fight.own).compact
    fresh = enemies.reject { |enemy| scaled?(enemy) }
    shares = fresh.map { |enemy| enemy.mhp.to_i > 0 ? enemy.hp.to_f / enemy.mhp : 1.0 }
    @scaled = enemies
    @scaled_tier = fight.tier
    fresh.each_with_index { |enemy, index| enemy.hp = MGQ_MpRaidPool.hp_of(shares[index], enemy.mhp) unless enemy.dead? }
  end

  # Gives the enemies of a troop a guest built anew from its host's their tier's stats before the
  # host's HP reaches them, which their own max HP would cut. Called by
  # MGQ_MpBattlesCoop.take_troop.
  def self.rescale
    fight = @fight
    scale(fight) if fight
  rescue => e
    log("raising the troop built anew failed: #{e.class}: #{e.message}")
  end

  # Reports whether an enemy has its tier's stats.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @return [Boolean] Whether it has.
  def self.scaled?(enemy)
    @scaled.any? { |scaled| scaled.equal?(enemy) }
  end

  # Finds one of an enemy's stats: for an enemy of a battle whose boss fights at its tier, its own
  # times the tier's factor (MGQ_MpRaidBosses::TIERS), applied on every call since the game computes
  # the stat anew each time.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @param stat [Symbol] The stat, such as :mhp.
  # @param own [Integer] The stat as the game computes it.
  # @return [Integer] The stat.
  def self.stat(enemy, stat, own)
    return own if @scaled.empty? || !scaled?(enemy)

    factor = MGQ_MpRaidBosses::TIERS.fetch(@scaled_tier, {}).fetch(stat, 1)
    factor == 1 ? own : (own * factor).round
  end

  # Ends the battle whose boss fights at its tier, keeping a lost one for the game's retry. Called
  # as BattleManager.battle_end starts.
  #
  # @param result [Integer] The game's result: 0 won, 1 escaped, 2 lost.
  def self.battle_ended(result)
    fight = @fight
    @fight = nil
    return unless fight

    @lost = fight if result == 2
    log("battle against troop #{fight.troop} at tier #{fight.tier} ended #{{ 0 => 'won', 1 => 'escaped', 2 => 'lost' }.fetch(result, result.inspect)}")
  end

  # Writes the field an invite to the player's battle, or a request to the party's leader to lead
  # it, adds when its boss fights at its tier, so the other games raise the same enemies.
  #
  # Only in the battle scene does the decision taken count: there a member hosts its battle at its
  # start once the party's leader would not lead it, while a battle set up on the map comes before
  # set_up, where a fight a refused lead left behind would mislabel it.
  #
  # @param troop_id [Integer] The troop of the battle just set up, before set_up decides on it,
  #   since battles_coop.rbx's hook on BattleManager.setup runs first; or of the battle running.
  # @return [Hash] The field, none for a battle whose boss keeps the game's stats.
  def self.invite_fields(troop_id)
    fight = @fight
    running = fight && fight.troop == troop_id.to_i && SceneManager.scene.is_a?(Scene_Battle)
    tiered = running || kind_of(troop_id)
    tiered ? { INVITE_FIELD => 1 } : {}
  rescue => e
    log("writing the invite's tier failed: #{e.class}: #{e.message}")
    {}
  end

  # Notes whether the battle of an invite the player accepts, or of a member's request the player
  # leads, fights its boss at its tier, as its INVITE_FIELD says. Called by MGQ_MpBattlesCoop.accept
  # and lead before they set the battle up.
  #
  # @param message [Hash] The invite or the request: "troop" and INVITE_FIELD.
  def self.note_invite(message)
    @invited = !MGQ_MpCoop::Scope.raid? && message[INVITE_FIELD].to_s == "1" ? message["troop"].to_i : nil
  end

  # Takes the relay's word that the open Classic world's creator or an admin changed whether its
  # story bosses fight as raid bosses, from the next boss battle on.
  #
  # @param message [Hash] The push: MGQ_MpOverworldSync::RAID_BOSSES_FIELD with "1" or "0", marked
  #   :relay by overworld_sync.rbx.
  def self.pushed(message)
    return log("ignored a raid bosses push not from the relay") unless message[:relay]

    value = message[MGQ_MpOverworldSync::RAID_BOSSES_FIELD].to_s
    return log("ignored the relay's raid bosses #{value.inspect}") unless %w[0 1].include?(value)

    on = value == "1"
    return if on == MGQ_MpWorld.raid_bosses?
    return log("ignored the relay's raid bosses outside a Classic world") unless MGQ_MpWorld.take_raid_bosses(on)

    log("the relay tells the world's raid bosses are #{on ? 'on' : 'off'} now")
    MGQ_MpOverworldSync.notice(on ? "The world's story bosses fight as raid bosses now." : "The world's story bosses fight as usual now.")
  rescue => e
    log("taking the relay's raid bosses failed: #{e.class}: #{e.message}")
  end

  # Installs the stat hooks on methods the game's plugins may define anew, as the game starts
  # running.
  def self.install
    ([:mhp] + MGQ_MpRaidBosses.tier_stats).each do |stat|
      next log("tiers change #{stat}, which the game's enemies lack") unless Game_Enemy.method_defined?(stat)

      MGQ_MpHooks.around(Game_Enemy, stat, "battles_raid_tiers") { |enemy, _args, original| MGQ_MpRaidTiers.stat(enemy, stat, original.call) }
    end

    MGQ_MpHooks.before(BattleManager.singleton_class, :battle_end, "battles_raid_tiers") { |result| MGQ_MpRaidTiers.battle_ended(result) }

    return unless BattleManager.respond_to?(:retry_battle)

    MGQ_MpHooks.around(BattleManager.singleton_class, :retry_battle, "battles_raid_tiers") do |_manager, _args, original|
      MGQ_MpRaidTiers.retrying { original.call }
    end
  rescue => e
    log("battle hooks FAILED: #{e.class}: #{e.message}")
  end

  forget
end

# The relay's push, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::RAID_BOSSES_FIELD) { |_peer, message| MGQ_MpRaidTiers.pushed(message) }
rescue => e
  MGQ_MpRaidTiers.log("push route FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_raid_tiers") { MGQ_MpRaidTiers.install }
  MGQ_MpHooks.before(Scene_Title, :start, "battles_raid_tiers") { MGQ_MpRaidTiers.forget }
  MGQ_MpHooks.after(BattleManager.singleton_class, :setup, "battles_raid_tiers") { |troop_id, *_rest| MGQ_MpRaidTiers.set_up(troop_id) }
  MGQ_MpHooks.around(Game_Map, :update_interpreter, "battles_raid_tiers") { |_map, _args, original| MGQ_MpRaidTiers.in_map { original.call } }
  MGQ_MpHooks.around(Game_Interpreter, :command_301, "battles_raid_tiers") { |_interpreter, _args, original| MGQ_MpRaidTiers.at_command { original.call } }
rescue => e
  MGQ_MpRaidTiers.log("hooks FAILED: #{e.class}: #{e.message}")
end
