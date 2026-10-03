#----------------------------------------------------------------
#  mp_battles.rbx
#
#  Changelog:
#      Paulinchen  2026-10-03: Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Installed the battle hooks through mp_hooks.rbx
#      Paulinchen  2026-10-01: Let co-op battles swap the Backline in, which only PvP battles forbid now
#      Paulinchen  2026-09-30: Moved into Patch/Multiplayer/Scripts as mp_battles.rbx, which Multiplayer.rb loads
#                            - Created
#
#----------------------------------------------------------------

# The rules of every multiplayer battle, PvP battles and co-op battles alike: no ero offers and no
# Give Up. A PvP battle also forbids swapping the Backline in, since both games fight with the
# teams they swapped at the start; a co-op battle tells its swaps to every game. The game's own
# settings come back once the battle ends.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattles
  # The switch that turns off ero offers, a low-HP monster's offer of an H-scene for giving up,
  # and monsters opening conversations, by its name in the editor. An offer would stop one game's
  # battle for a scene the others wait through.
  ERO_OFFERS_OFF = "No Seduction"

  # The switch's id in 3.06, for a translation that names it otherwise.
  ERO_OFFERS_OFF_ID = 86

  class << self
    # The kind of multiplayer battle running.
    #
    # @return [Symbol, nil] :pvp or :coop while one runs, nil otherwise.
    attr_reader :kind
  end

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "battle"

  # Reports whether a multiplayer battle runs.
  #
  # @return [Boolean] Whether one does.
  def self.running?
    !@kind.nil?
  end

  # Starts a multiplayer battle's rules, keeping the game's own settings to put back.
  #
  # @param kind [Symbol] :pvp or :coop.
  def self.begin(kind)
    finish if running?
    @kind = kind
    @kept = {}
    switch_rules(kind).each do |id, value|
      @kept[id] = $game_switches[id]
      $game_switches[id] = value
    end
  rescue => e
    log("could not start the rules: #{e.class}: #{e.message}")
  end

  # Ends a multiplayer battle's rules and puts the game's own settings back.
  def self.finish
    return unless running?

    (@kept || {}).each { |id, value| $game_switches[id] = value }
    @kept = nil
    @kind = nil
  rescue => e
    @kind = nil
    log("could not end the rules: #{e.class}: #{e.message}")
  end

  # The switches a multiplayer battle sets.
  #
  # @param kind [Symbol] :pvp or :coop.
  # @return [Hash{Integer => Boolean}] Each switch's value during the battle.
  def self.switch_rules(kind)
    rules = { ($data_system.switches.index(ERO_OFFERS_OFF) || ERO_OFFERS_OFF_ID) => true }
    rules[NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE] = true if kind == :pvp && defined?(NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE)
    rules
  end

  # Installs the battle hooks. The game's plugins load after the Patch folder and define battle
  # methods anew, so the hooks go in once every plugin is in.
  def self.install
    return if @installed

    @installed = true
    BattleManager.singleton_class.class_eval do
      alias_method :mgq_mp_battles_can_giveup?, :can_giveup?

      # Offers Give Up, except in a multiplayer battle, where it would end the battle for everyone.
      #
      # @return [Boolean] Whether Give Up is offered.
      def can_giveup?
        MGQ_MpBattles.running? ? false : mgq_mp_battles_can_giveup?
      end
    end
  rescue => e
    log("battle hooks FAILED: #{e.class}: #{e.message}")
  end
end

# Game hooks, through mp_hooks.rbx.

begin
  # Installs the battle hooks as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "mp_battles") { MGQ_MpBattles.install }
rescue => e
  MGQ_MpBattles.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
end
