#----------------------------------------------------------------
#  world_catchup_exp.rbx
#
#  Changelog:
#      Paulinchen  2026-10-23: Asked the DLL for the target, the factor and the grown experience
#      Paulinchen  2026-10-13: Grew the experience of no story companion on a visit nor of a story's temporary party
#      Paulinchen  2026-10-12: Created
#
#----------------------------------------------------------------

# Catch-up experience in a Raid World: characters below the cap the world's story unlocked before
# its latest one gain more base, job and race experience the further below it they are. The DLL
# owns the rule (CatchupExperience in MGQOnline.Game); this script hands it the levels and the
# experience and gives what comes back.
module MGQ_MpWorldCatchupExp
  # The topic that finds the level characters catch up to from the world story's caps.
  TARGET_TOPIC = "catchup.target"

  # The topic that grows a battle's experience for a character below the target.
  GROW_TOPIC = "catchup.grow"

  # The topic that writes a character's factor as the Unlocks page shows it.
  FACTOR_TOPIC = "catchup.factor"

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "catch-up exp"

  # Finds the level up to which characters catch up: the cap the world's story unlocked before its
  # latest one.
  #
  # @return [Integer, nil] The level; nil outside a Raid World's story.
  def self.target
    return nil unless MGQ_MpWorldStory.active? && MGQ_MpWorldStory.world

    MGQ_Multiplayer::Bridge.call(TARGET_TOPIC, Array(MGQ_MpWorldStory.world["caps"]))
  end

  # Writes the factor a character's experience grows by, as the World overview's Unlocks page
  # shows it.
  #
  # @param level [Integer] The character's base level.
  # @param target [Integer, nil] The level up to which characters catch up, see target.
  # @return [String] Such as "x3.5" or "x10"; empty when the DLL did not answer.
  def self.factor_text(level, target)
    MGQ_Multiplayer::Bridge.call(FACTOR_TOPIC, "target" => target, "level" => level) || ""
  end

  # Grows the experience a character gains from a battle: not for one the catch-up does not count
  # (see MGQ_MpWorldCatchup.counts?).
  #
  # @param actor [Game_Actor] The character.
  # @param exp [Integer] The base experience.
  # @param cexp [Integer] The job and race experience.
  # @return [Array<Integer>] The experience to gain.
  def self.grown(actor, exp, cexp)
    target = MGQ_MpWorldCatchup.counts?(actor) ? self.target : nil
    return [exp, cexp] unless target

    grown = MGQ_Multiplayer::Bridge.call(GROW_TOPIC, "target" => target, "level" => actor.base_level, "exp" => exp, "cexp" => cexp)
    return [exp, cexp] unless grown

    log("#{actor.name} (level #{actor.base_level}, catching up to #{target}): #{grown['factor']} EXP, #{exp} -> #{grown['exp']}, job and race #{cexp} -> #{grown['cexp']}")
    [grown["exp"], grown["cexp"]]
  rescue => e
    log_once(:grown, "growing the experience failed: #{e.class}: #{e.message}")
    [exp, cexp]
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # A battle's experience, which every game gives its own characters, also after the EXP mods
  # that work out each character's share through this method.
  MGQ_MpHooks.around(Game_Actor, :gain_exp, "world_catchup_exp") do |actor, args, original|
    args.size == 2 ? original.call(*MGQ_MpWorldCatchupExp.grown(actor, args[0], args[1])) : original.call
  end
rescue => e
  MGQ_MpWorldCatchupExp.log("hooks FAILED: #{e.class}: #{e.message}")
end
