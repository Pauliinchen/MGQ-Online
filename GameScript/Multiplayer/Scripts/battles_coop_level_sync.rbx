#----------------------------------------------------------------
#  battles_coop_level_sync.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Synced no level in a Raid World
#      Paulinchen  2026-10-07: Logged the battle's level and why, and each character's level and stats before and after the sync
#      Paulinchen  2026-10-06: Dropped level, which only the tests read
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# The level sync of a co-op battle: a character above the battle's level, the highest of the party
# leader's characters in it, fights with the stats of that level, and its equipment loses half as
# much as the level takes. Its levels, experience and skills stay its own, and its stats come back
# once the battle is won, before its rewards, or ends.
#
# Every game of the battle syncs the same characters to the level the host sent, since the host's
# game works the battle out and the others show it.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopLevelSync
  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "level sync"

  # Turns the level sync off without uninstalling it.
  ENABLED = true

  # The share of what the level takes off a stat that the character's equipment loses too.
  EQUIPMENT_SHARE = 0.5

  # Stats the game counts, max HP to luck.
  PARAM_COUNT = 8

  # What a synced character fights with: the stats of the battle's level, and the share of each
  # stat its equipment keeps.
  Sync = Struct.new(:bases, :equipment)

  @level = nil
  @synced = {}
  @told = false
  @noted = {}

  # Works out the level of a co-op battle: the highest of the party leader's characters in it, on
  # its Frontline and Backline. A Raid World's battles have none.
  #
  # @param players [Array<MGQ_MpBattlesCoop::Player>] The battle's players, as
  #   MGQ_MpBattlesCoop.arrange gives them.
  # @return [Integer, nil] The level, nil in a Raid World or when the leader is not among the players.
  def self.level_for(players)
    if MGQ_MpCoop::Scope.raid?
      log("no level: a Raid World's battles sync none")
      return nil
    end

    leader = players.find { |player| MGQ_MpBattlesCoop.leads?(player.seat) }
    unless leader
      log("no level: the party leader is not among the battle's players (seats #{players.map(&:seat).join(', ')})")
      return nil
    end

    builds = MGQ_MpActors::Builds.parse(leader.builds.to_s, MGQ_MpBattlesCoop::MOST_CHARACTERS)
    levels = leader.lines.flatten.map { |place| builds[place] && builds[place].base_level }.compact
    log("level #{levels.max.inspect}: the highest of the leader's (seat #{leader.seat}) characters in the battle, at levels #{levels.join(', ')}")
    levels.max
  rescue => e
    log("working the level out failed: #{e.class}: #{e.message}")
    nil
  end

  # Starts the level sync of a co-op battle, giving back what a battle before kept synced.
  #
  # @param level [Integer, nil] The battle's level, nil or 0 for none.
  def self.begin(level)
    finish
    @level = ENABLED && level.is_a?(Integer) && level > 0 ? level : nil
    return log("battle at level #{@level}, characters above it fight at it") if @level

    log("no level sync this battle: #{ENABLED ? "no level (#{level.inspect})" : 'the level sync is off'}")
  end

  # Syncs a character of the co-op party when it is above the battle's level, keeping its share of
  # HP and MP. A character synced already stays as it is.
  #
  # @param actor [Game_Actor] The character, the player's own or a rebuilt one.
  def self.sync(actor)
    return unless @level && !@synced.key?(actor)
    return note(actor, "not synced in a #{MGQ_MpBattles.kind.inspect} battle") unless MGQ_MpBattles.kind == :coop
    return note(actor, "not synced: level #{actor.base_level} is at or below #{@level}") unless actor.base_level > @level

    before = vitals_text(actor)
    keep_vitals(actor) { @synced[actor] = sync_of(actor) }
    log("synced #{label(actor)} from level #{actor.base_level} to #{@level}: #{before} -> #{vitals_text(actor)}")
    tell unless actor.is_a?(Game_MpActor)
  rescue => e
    @synced.delete(actor)
    log("syncing #{actor.name rescue '?'} failed: #{e.class}: #{e.message}")
  end

  # Finds what a character fights with. The game reads stats many times a frame.
  #
  # @param actor [Game_Actor] The character.
  # @return [Sync, nil] Its sync, nil when it fights with its own stats.
  def self.of(actor)
    @synced.empty? ? nil : @synced[actor]
  end

  # Counts the characters fighting synced.
  #
  # @return [Integer] The count.
  def self.synced_count
    @synced.size
  end

  # Logs once a battle why a character fights with its own stats.
  #
  # @param actor [Game_Actor] The character.
  # @param reason [String] Why.
  def self.note(actor, reason)
    return if @noted[actor]

    @noted[actor] = true
    log("#{label(actor)} #{reason}")
  end

  # Names a character by its id and name, for Multiplayer InGame.log.
  #
  # @param actor [Game_Actor] The character.
  # @return [String] Its id and name.
  def self.label(actor)
    "#{actor.id rescue '?'} #{actor.name rescue '?'}"
  end

  # Describes a character's max HP, HP and MP, for Multiplayer InGame.log.
  #
  # @param actor [Game_Actor] The character.
  # @return [String] Its max HP, HP and MP.
  def self.vitals_text(actor)
    "max HP #{actor.mhp}, HP #{actor.hp}, MP #{actor.mp}/#{actor.mmp}"
  rescue
    "?"
  end

  # Works out a stat's growth from items and equipment while the character is synced.
  #
  # @param actor [Game_Actor] The character.
  # @param sync [Sync] Its sync.
  # @param param_id [Integer] The stat's id.
  # @param value [Numeric] The growth as the game works it out.
  # @return [Numeric] The growth in the battle.
  def self.plus(actor, sync, param_id, value)
    equipment = actor.equip_params[param_id]
    value - equipment + equipment * sync.equipment[param_id]
  end

  # Ends the level sync, giving every synced character its own stats back with its share of HP and
  # MP.
  def self.finish
    @synced.keys.each do |actor|
      begin
        before = vitals_text(actor)
        keep_vitals(actor) { @synced.delete(actor) }
        log("gave #{label(actor)} its own stats back at level #{actor.base_level rescue '?'}: #{before} -> #{vitals_text(actor)}")
      rescue => e
        @synced.delete(actor)
        log("giving #{actor.name rescue '?'} its stats back failed: #{e.class}: #{e.message}")
      end
    end
  ensure
    @synced = {}
    @level = nil
    @told = false
    @noted = {}
  end

  # Forgets the level sync without touching any character, whose save a reset dropped.
  def self.drop
    log("forgot the sync of #{@synced.size} characters after a reset, leaving their stats alone") unless @synced.empty?
    @synced = {}
    @level = nil
    @told = false
    @noted = {}
  end

  # Works out a character's sync for the battle's level.
  #
  # @param actor [Game_Actor] The character, not synced yet.
  # @return [Sync] Its sync.
  def self.sync_of(actor)
    own = (0...PARAM_COUNT).map { |id| actor.param_base(id) }
    bases = at_level(actor, @level) { (0...PARAM_COUNT).map { |id| actor.param_base(id) } }
    equipment = own.zip(bases).map do |was, now|
      kept = was > 0 ? [[now.to_f / was, 0.0].max, 1.0].min : 1.0
      1.0 - EQUIPMENT_SHARE * (1.0 - kept)
    end
    Sync.new(bases, equipment)
  end

  # Lets the game work something out as if a character had another personal level, through its
  # own stat curves.
  #
  # @param actor [Game_Actor] The character.
  # @param level [Integer] The personal level.
  # @return [Object] What the block returns.
  def self.at_level(actor, level)
    levels = MGQ_MpGame.get(actor, :level)
    own = levels[:base]
    levels[:base] = level
    begin
      yield
    ensure
      levels[:base] = own
    end
  end

  # Changes a character's stats, keeping its share of HP and MP. A fallen character stays fallen and
  # a standing one keeps at least 1 HP.
  #
  # @param actor [Game_Actor] The character.
  def self.keep_vitals(actor)
    hp_share = actor.mhp > 0 ? actor.hp.to_f / actor.mhp : 0.0
    mp_share = actor.mmp > 0 ? actor.mp.to_f / actor.mmp : 0.0
    yield
    actor.hp = [[(hp_share * actor.mhp).round, 1].max, actor.mhp].min if actor.hp > 0
    actor.mp = [(mp_share * actor.mmp).round, actor.mmp].min
  end

  # Tells the player once a battle that their characters fight at its level.
  def self.tell
    return if @told

    @told = true
    MGQ_MpChat.system("Level Sync: your characters fight at level #{@level}, the party leader's.")
    log("told the player in the chat that their characters fight at level #{@level}")
  end

  # Installs the stat and victory hooks. The game's plugins load after the Patch folder and define
  # the stats anew, so the hooks go in once every plugin is in.
  def self.install
    return if @installed

    @installed = true
    install_stats
    # The rewards come with the stats back, so the victory and its level-ups show them in full.
    MGQ_MpHooks.around(BattleManager.singleton_class, :process_victory, "battles_coop_level_sync") do |_manager, _args, original|
      MGQ_MpCoopLevelSync.log("victory: #{MGQ_MpCoopLevelSync.synced_count} synced characters get their own stats back before the rewards") if MGQ_MpCoopLevelSync.synced_count > 0
      finish
      original.call
    end
  rescue => e
    log("stat hooks FAILED: #{e.class}: #{e.message}")
  end

  # Wraps the game's stats. The game reads them many times a frame, so the wraps are plain aliases.
  def self.install_stats
    Game_Actor.class_eval do
      alias_method :mgq_mp_level_sync_param_base, :param_base
      alias_method :mgq_mp_level_sync_param_plus, :param_plus

      # Works a stat's personal level part out, that of the battle's level while synced.
      #
      # @param param_id [Integer] The stat's id.
      # @return [Integer] The stat's personal level part.
      def param_base(param_id)
        sync = MGQ_MpCoopLevelSync.of(self)
        sync ? sync.bases[param_id] : mgq_mp_level_sync_param_base(param_id)
      end

      # Works a stat's growth from items and equipment out, the equipment's lowered while synced.
      # The equipment is lowered here rather than in equip_params, which the game's feature cache
      # calls through itself and would lower twice.
      #
      # @param param_id [Integer] The stat's id.
      # @return [Numeric] The stat's growth.
      def param_plus(param_id)
        value = mgq_mp_level_sync_param_plus(param_id)
        sync = MGQ_MpCoopLevelSync.of(self)
        sync ? MGQ_MpCoopLevelSync.plus(self, sync, param_id, value) : value
      end
    end
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # Installs the stat hooks as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_coop_level_sync") { MGQ_MpCoopLevelSync.install }

  # Before the title screen starts, a sync a reset interrupted is forgotten.
  MGQ_MpHooks.before(Scene_Title, :start, "battles_coop_level_sync") { MGQ_MpCoopLevelSync.drop }
rescue => e
  MGQ_MpCoopLevelSync.log("hooks FAILED: #{e.class}: #{e.message}")
end
