#----------------------------------------------------------------
#  mp_battle.rbx
#
#  Changelog:
#      Paulinchen  2026-09-30: Moved into Patch/Multiplayer/Scripts as mp_battle.rbx, which Multiplayer.rb loads
#                            - Renamed from mp_battles.rbx, with the module MGQ_MpBattle
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# The rules of every multiplayer battle, PvP battles and co-op battles alike: no ero offers, no
# Give Up, and no swapping the backline in during the battle, since every game has to fight with
# the same characters. The game's own settings come back once the battle ends.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattle
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

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !SceneManager.respond_to?(:mgq_mp_battle_run)
  end

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("battle: #{message}")
  rescue
  end

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
    switch_rules.each do |id, value|
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
  # @return [Hash{Integer => Boolean}] Each switch's value during the battle.
  def self.switch_rules
    rules = { ($data_system.switches.index(ERO_OFFERS_OFF) || ERO_OFFERS_OFF_ID) => true }
    rules[NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE] = true if defined?(NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE)
    rules
  end

  # Installs the battle hooks. The game's plugins load after the Patch folder and define battle
  # methods anew, so the hooks go in once every plugin is in.
  def self.install
    return if @installed

    @installed = true
    BattleManager.singleton_class.class_eval do
      alias_method :mgq_mp_battle_can_giveup?, :can_giveup?

      # Offers Give Up, except in a multiplayer battle, where it would end the battle for everyone.
      #
      # @return [Boolean] Whether Give Up is offered.
      def can_giveup?
        MGQ_MpBattle.running? ? false : mgq_mp_battle_can_giveup?
      end
    end
  rescue => e
    log("battle hooks FAILED: #{e.class}: #{e.message}")
  end
end

# Game hooks.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpBattle.hookable?
  begin
    class << SceneManager
      alias mgq_mp_battle_run run

      # Installs the battle hooks, then runs the game.
      def run
        MGQ_MpBattle.install
        mgq_mp_battle_run
      end
    end
  rescue => e
    MGQ_MpBattle.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
  end
end
