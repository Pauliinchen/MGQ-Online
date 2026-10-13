#----------------------------------------------------------------
#  world_catchup_exp.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Created
#
#----------------------------------------------------------------

# Catch-up experience in a Raid World: characters below the cap the world's story unlocked before
# its latest one gain more base, job and race experience the further below it they are.
#
# The latest cap is left out, so players who just reached the world's story do not race past the
# others.
module MGQ_MpWorldCatchupExp
  # The cap every story starts with, before its first milestone.
  BASE_CAP = 5

  # The most the experience grows.
  MAX_FACTOR = 10.0

  # The share of the levels up to the target, counted from level 0, that gains the most.
  FULL_SHARE = 0.25

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "catch-up exp"

  # Finds the level up to which characters catch up: the cap the world's story unlocked before its
  # latest one.
  #
  # @return [Integer, nil] The level; nil outside a Raid World's story.
  def self.target
    return nil unless MGQ_MpWorldStory.active? && MGQ_MpWorldStory.world

    caps = ([BASE_CAP] + Array(MGQ_MpWorldStory.world["caps"])).uniq.sort
    caps.size >= 2 ? caps[-2] : nil
  end

  # Works out the factor a character's experience grows by.
  #
  # @param level [Integer] The character's base level.
  # @param target [Integer, nil] The level up to which characters catch up, see target.
  # @return [Float] The factor: MAX_FACTOR up to FULL_SHARE of the target, falling evenly to 1.0 at
  #   the target and above.
  def self.factor_for(level, target)
    return 1.0 unless target && level < target

    fade = (1.0 - FULL_SHARE) * target
    [1.0 + (MAX_FACTOR - 1.0) * (target - level) / fade, MAX_FACTOR].min
  end

  # Works out the factor a character's experience grows by now.
  #
  # @param actor [Game_Actor] The character.
  # @return [Float] The factor.
  def self.factor(actor)
    factor_for(actor.base_level, target)
  end

  # Grows the experience a character gains from a battle by its factor.
  #
  # @param actor [Game_Actor] The character.
  # @param exp [Integer] The base experience.
  # @param cexp [Integer] The job and race experience.
  # @return [Array<Integer>] The experience to gain.
  def self.grown(actor, exp, cexp)
    factor = factor(actor)
    return [exp, cexp] if factor <= 1.0

    grown = [(exp * factor).round, (cexp * factor).round]
    log("#{actor.name} (level #{actor.base_level}, catching up to #{target}): #{factor_text(factor)} EXP, #{exp} -> #{grown[0]}, job and race #{cexp} -> #{grown[1]}")
    grown
  rescue => e
    log_once(:grown, "growing the experience failed: #{e.class}: #{e.message}")
    [exp, cexp]
  end

  # Writes a factor as the World overview's Unlocks page shows it.
  #
  # @param factor [Float] The factor.
  # @return [String] Such as "x3.5" or "x10".
  def self.factor_text(factor)
    shown = factor.round(2)
    "x#{shown == shown.round ? shown.round : shown}"
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
