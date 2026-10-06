#----------------------------------------------------------------
#  battles.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Let a mode name the players whose commands lost their target to a swap, who choose again
#                            - Renamed from mp_battles.rbx
#      Paulinchen  2026-10-03: Let a PvP battle with the Backline swap it in, and let a mode name the characters outside the battle
#                            - Added Mode, what a kind of live battle does differently from a duel, which the kinds register and the live battle asks
#                            - Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Installed the battle hooks through core_hooks.rbx
#      Paulinchen  2026-10-01: Let co-op battles swap the Backline in, which only PvP battles forbid now
#      Paulinchen  2026-09-30: Moved into Patch/Multiplayer/Scripts as battles.rbx, which Multiplayer.rb loads
#                            - Created
#
#----------------------------------------------------------------

# The rules of every multiplayer battle, PvP battles and co-op battles alike: no ero offers and no
# Give Up. A PvP battle without the Backline also forbids swapping it in; a co-op battle and a PvP
# battle with the Backline tell their swaps to every game. The game's own settings come back once
# the battle ends.
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

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "battle"

  # What a kind of live battle does differently from a duel between two players, such as a co-op
  # battle or a team duel. A kind's module extends this and answers what it changes; mode
  # registers it, and battles_sync.rbx asks the running battle's.
  module Mode
    # Reports whether this game's party is the host's party.
    #
    # @return [Boolean] Whether it is; else the host's party is this game's troop.
    def same_side?
      false
    end

    # Reports whether a guest's characters stand in the host's party. Asked by the host.
    #
    # @param _seat [Integer] The guest's world seat.
    # @return [Boolean] Whether they do; else they stand in the host's troop.
    def same_side_as_host?(_seat)
      false
    end

    # Lists the battle's players the live battle was not started with.
    #
    # @return [Array<Integer>] Their world seats.
    def player_seats
      []
    end

    # Runs before the battle starts, on host and guest, while the game's role may still change.
    #
    # @param _scene [Scene_Battle] The battle.
    def before_start(_scene)
    end

    # Builds the host's battle before it tells the guests it is ready.
    #
    # @param _scene [Scene_Battle] The battle.
    # @return [Symbol, nil] :own when the battle is the host's own after all and no longer live,
    #   another reason when it ends before it began, nil when it goes on.
    def host_start(_scene)
    end

    # Builds the guest's battle before it tells the host it is ready.
    #
    # @param _scene [Scene_Battle] The battle.
    # @return [Symbol, nil] Why the battle ends before it began, nil when it goes on.
    def guest_start(_scene)
    end

    # Settles who fights on, as host, when a command phase starts.
    #
    # @param _scene [Scene_Battle] The battle.
    def settle(_scene)
    end

    # Reports whether the host's opponents all left. Asked by the host.
    #
    # @return [Boolean] Whether they did.
    def other_side_gone?
      false
    end

    # The order of the player's places, which their commands carry to the host.
    #
    # @return [Array<Integer>, nil] The order, nil when the battle has none.
    def own_order
    end

    # Takes the order of a guest's places that came with their commands. Called by the host.
    #
    # @param _seat [Integer] The guest's world seat.
    # @param _order [Array<Integer>, nil] The order.
    def take_order(_seat, _order)
    end

    # Tells the guests an order of places that changed, once the host has every guest's commands.
    def share_order
    end

    # Lists the players a command of whose lost its target to another player's swap during the
    # command phase, once the host has every guest's commands. Asked by the host.
    #
    # @return [Array<Integer>] Their world seats, the host's own and those who left included.
    def lost_targets
      []
    end

    # Gives the other players' characters whose commands lost their target the computer's commands,
    # and shows every game the party a swap changed, before the players still in the battle choose
    # again. Called by the host.
    #
    # @param _seats [Array<Integer>] The world seats of the players whose commands lost their target.
    def choose_again(_seats)
    end

    # Tells who commands the characters of a player who left.
    #
    # @param _seat [Integer] The world seat of the player who left.
    # @return [Integer, nil] The world seat of who commands them, nil for nobody else.
    def heir_of(_seat)
    end

    # The kinds of the battle's own messages inside the host's stream.
    #
    # @return [Array<String>] The kinds.
    def stream_kinds
      []
    end

    # Takes one of the battle's own messages inside the host's stream. Called by the guest.
    #
    # @param _kind [String] One of stream_kinds.
    # @param _scene [Scene_Battle] The battle.
    # @param _body [String] The message's body.
    def take(_kind, _scene, _body)
    end

    # Lists this game's own characters outside the battle that the stream still names.
    #
    # @return [Array<Game_Battler>] The characters.
    def own_reserve
      []
    end

    # Lists the other side's characters outside the battle that the stream still names.
    #
    # @return [Array<Game_Battler>] The characters.
    def other_reserve
      []
    end

    # Names a character outside the battle for the host's stream.
    #
    # @param _battler [Game_Battler] The character.
    # @return [String, nil] The reference, nil for a character the battle does not know.
    def reserve_ref(_battler)
    end

    # Finds the guest's character outside the battle for a reference of the host's stream.
    #
    # @param _ref [String] The reference, see reserve_ref.
    # @return [Game_Battler, nil] The character.
    def reserve(_ref)
    end

    # Fights the battle on alone once the host is gone. Called by the guest.
    #
    # @param _scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the battle goes on; else it ends as a duel does.
    def take_over(_scene)
      false
    end
  end

  # A duel between two players, which changes nothing.
  module Duel
    extend Mode
  end

  @modes = {}

  # Registers what a kind of live battle does differently.
  #
  # @param name [Symbol] The kind, such as :coop.
  # @param mode [Mode] Its module.
  def self.mode(name, mode)
    @modes[name] = mode
  end

  # Finds what a kind of live battle does differently.
  #
  # @param name [Symbol, nil] The kind.
  # @return [Mode] Its module, a duel's when the kind registered none.
  def self.mode_of(name)
    @modes[name] || Duel
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
  # @param backline [Boolean] Whether the Backline may be swapped in.
  def self.begin(kind, backline = kind != :pvp)
    finish if running?
    @kind = kind
    @kept = {}
    switch_rules(kind, backline).each do |id, value|
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
  # @param backline [Boolean] Whether the Backline may be swapped in.
  # @return [Hash{Integer => Boolean}] Each switch's value during the battle.
  def self.switch_rules(kind, backline = kind != :pvp)
    rules = { ($data_system.switches.index(ERO_OFFERS_OFF) || ERO_OFFERS_OFF_ID) => true }
    rules[NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE] = true if !backline && defined?(NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE)
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

# Game hooks, through core_hooks.rbx.

begin
  # Installs the battle hooks as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles") { MGQ_MpBattles.install }
rescue => e
  MGQ_MpBattles.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
end
