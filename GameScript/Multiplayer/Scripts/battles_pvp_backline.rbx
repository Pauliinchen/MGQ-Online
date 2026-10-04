#----------------------------------------------------------------
#  battles_pvp_backline.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Renamed from mp_battles_pvp_backline.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The Backline in a PvP battle: both players swap their Backline in with the battle's Party
# command. A swap is chosen with the round's commands and stands from the round's start, and the
# character swapped in gives no commands that round. It builds on battles_pvp.rbx.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesPvp
  # The other side's characters outside its Frontline, the player's own swaps and what they cost,
  # and the option of the player who hosts.
  module Backline
    # The option of the Backline in PvP battles, its key in $game_system.conf.
    OPTION = :mp_pvp_backline

    # The option's value that lets both players swap their Backline in.
    WITH_BACKLINE = 0

    # The option's value that leaves the Backline out.
    FRONTLINE_ONLY = 1

    # The option's values by their name and help in the Mod Config. The first one is the default.
    OPTION_VALUES = {
      WITH_BACKLINE => ["With Backline", "Both players swap their Backline in with the battle's Party command."],
      FRONTLINE_ONLY => ["Frontline Only", "Only the Frontline fights."],
    }

    # The kind of the message that tells the guest the host's Frontline, inside the host's stream.
    FRONT_MESSAGE = "pvp_front"

    # A reference to a character outside both Frontlines, see MGQ_MpBattlesSync::Recorder.ref.
    RESERVE_REF = /\A([br])(\d{1,4})\z/

    # Reports whether the battles the player hosts and the duels they challenge to have the Backline.
    #
    # @return [Boolean] Whether they do.
    def self.wanted?
      value = $game_system.conf[OPTION] rescue nil
      value.to_i != FRONTLINE_ONLY
    end

    # Adds the option to the Mod Config, or to the game's options without it.
    def self.register
      config = NWConst::Config
      menu = config.const_defined?(:MOD_CONTENTS) ? config::MOD_CONTENTS : config::CONTENTS
      menu.insert(-2, :key => OPTION, :name => "[Monster Girl Quest! Online] PvP Backline", :sub => true,
                      :help => "Whether the PvP battles you host and the duels you challenge to have the Backline.\r\n←/→ Toggle")
      config::DATA[OPTION] = OPTION_VALUES.keys
      config::DATA_TEXT[OPTION] = {}
      OPTION_VALUES.each { |value, (label, text)| config::DATA_TEXT[OPTION][value] = { :name => label, :help => text } }
      config::DEFAULT[OPTION] = OPTION_VALUES.keys.first
    end

    # Reports whether the running PvP battle has the Backline.
    #
    # @return [Boolean] Whether it does.
    def self.on?
      @all ? true : false
    end

    # Starts the Backline for a PvP battle.
    #
    # @param opponents [Array<Opponent>] Every character of the other side, its Frontline first.
    def self.begin(opponents)
      @all = {}
      opponents.each { |opponent| @all[opponent.id] = opponent }
      @round = nil
      @round_front = nil
      @swapped_in = []
      @told_front = front_ids
    end

    # Ends the Backline with its battle.
    def self.finish
      @all = nil
      @round = nil
      @round_front = nil
      @swapped_in = []
      @told_front = nil
    end

    # Finds a character of the other side.
    #
    # @param actor_id [Integer] Its actor id.
    # @return [Opponent, nil] The character, nil outside a battle with the Backline.
    def self.opponent(actor_id)
      @all && @all[actor_id]
    end

    # Lists the other side's characters outside its Frontline.
    #
    # @return [Array<Opponent>] The characters, none outside a battle with the Backline.
    def self.reserve
      on? ? @all.values - $game_troop.members : []
    end

    # Lists the player's own characters outside their Frontline.
    #
    # @return [Array<Game_Actor>] The characters, none outside a battle with the Backline.
    def self.own_reserve
      on? ? $game_party.bench_members : []
    end

    # Lists who stands on the player's Frontline.
    #
    # @return [Array<Integer>] Their actor ids, by place.
    def self.front_ids
      $game_party.battle_members.map(&:id)
    end

    # Reads who stood on the player's Frontline when the round's command phase began.
    #
    # The turn count only changes as a turn starts, so the first look of a command phase reads the
    # Frontline before any swap of that round.
    #
    # @return [Array<Integer>] Their actor ids, by place.
    def self.round_front
      turn = $game_troop.turn_count
      if @round != turn
        @round = turn
        @round_front = front_ids
      end
      @round_front
    end

    # Reports whether a character of the player's was swapped in this round, which costs its commands.
    #
    # @param actor [Game_Actor] The character.
    # @return [Boolean] Whether it was.
    def self.swapped_in?(actor)
      return false unless @all

      place = $game_party.battle_members.index(actor)
      !place.nil? && round_front[place] != actor.id
    rescue => e
      MGQ_MpBattlesPvp.log_once(:swapped_in, "swap check failed: #{e.class}: #{e.message}")
      false
    end

    # Puts the other side's Frontline in the troop as the other game tells it. A character swapped in
    # loses the actions it had left from an earlier round.
    #
    # @param ids [Array<Integer>, nil] The actor ids on the other side's Frontline, by place.
    def self.take_front(ids)
      return unless on? && ids.is_a?(Array)

      current = $game_troop.members
      front = ids.map { |id| @all[id] }
      unless front.size == current.size && !front.include?(nil) && front.uniq.size == front.size
        return MGQ_MpBattlesPvp.log("left out a Frontline that does not fit the other side's team: #{ids.inspect}")
      end
      return if front == current

      @swapped_in = front - current
      @swapped_in.each(&:clear_actions)
      MGQ_MpGame.set($game_troop, :enemies, front)
      Opponents.stand(front)
      redraw
      MGQ_MpBattlesPvp.log("the other side's Frontline is now #{front.map(&:name).join(', ')}")
    rescue => e
      MGQ_MpBattlesPvp.log("taking the other side's Frontline failed: #{e.class}: #{e.message}")
    end

    # Draws the troop's pictures anew, each in its new place.
    def self.redraw
      scene = SceneManager.scene
      return unless scene.is_a?(Scene_Battle)

      spriteset = MGQ_MpGame.get(scene, :spriteset)
      return unless spriteset

      spriteset.dispose_enemies
      spriteset.create_enemies
    end

    # As host, takes away the commands a guest sent for characters swapped in, then tells the guest
    # the host's own Frontline once it changed, before the turn's events. Called once the guest's
    # commands came.
    def self.settle_round
      return unless on?

      Array(@swapped_in).each(&:clear_actions)
      @swapped_in = []
      ids = front_ids
      return if ids == @told_front

      @told_front = ids
      MGQ_MpBattlesSync::Recorder.flush if MGQ_MpBattlesSync::Recorder.active?
      MGQ_MpBattlesSync::Channel.post(FRONT_MESSAGE, MGQ_MpBattlesSync::Wire.line([ids]))
    rescue => e
      MGQ_MpBattlesPvp.log("telling the Frontline failed: #{e.class}: #{e.message}")
    end

    # Lists whom a skill or item of the other side reaches on its own side, with its characters
    # outside the Frontline where the game reaches the player's.
    #
    # @param item [RPG::UsableItem, nil] The skill or item.
    # @param members [Array<Game_Battler>] The troop's members.
    # @return [Array<Game_Battler>] Whom it reaches.
    def self.troop_targets(item, members)
      return members unless on? && item
      return members + reserve if item.respond_to?(:include_bench?) && item.include_bench?
      return reserve if item.respond_to?(:bench_only?) && item.bench_only?

      members
    end

    # Installs the hooks on methods the game's plugins may define anew. Called once the first scene starts.
    def self.install
      return if @installed

      @installed = true
      MGQ_MpHooks.around(Game_Actor, :inputable?) do |actor, _args, original|
        original.call && !MGQ_MpBattlesPvp::Backline.swapped_in?(actor)
      end
      MGQ_MpHooks.around(Game_Actor, :make_actions) do |actor, _args, original|
        result = original.call
        actor.clear_actions if MGQ_MpBattlesPvp::Backline.swapped_in?(actor)
        result
      end
      # The round's Frontline must be read before the first swap changes it.
      MGQ_MpHooks.around(Scene_Battle, :bench_member_ok) do |_scene, _args, original|
        MGQ_MpBattlesPvp::Backline.round_front if MGQ_MpBattlesPvp::Backline.on?
        original.call
      end
      MGQ_MpHooks.around(Game_Troop, :item_target_members) do |_troop, args, original|
        MGQ_MpBattlesPvp::Backline.troop_targets(args[0], original.call)
      end
    rescue => e
      MGQ_MpBattlesPvp.log("Backline hooks FAILED: #{e.class}: #{e.message}")
    end

    # What a PvP battle between two players does differently in a live battle while it has the
    # Backline: each game tells the other its Frontline, and the stream names the characters outside
    # both.
    module Mode
      extend MGQ_MpBattles::Mode

      # (see MGQ_MpBattles::Mode#own_order)
      def self.own_order
        Backline.on? ? Backline.front_ids : nil
      end

      # (see MGQ_MpBattles::Mode#take_order)
      def self.take_order(_seat, order)
        Backline.take_front(order)
      end

      # (see MGQ_MpBattles::Mode#share_order)
      def self.share_order
        Backline.settle_round
      end

      # (see MGQ_MpBattles::Mode#stream_kinds)
      def self.stream_kinds
        Backline.on? ? [FRONT_MESSAGE] : []
      end

      # (see MGQ_MpBattles::Mode#take)
      def self.take(_kind, _scene, body)
        values = MGQ_MpBattlesSync::Wire.parse(body.to_s)
        Backline.take_front(values && values[0])
      end

      # (see MGQ_MpBattles::Mode#own_reserve)
      def self.own_reserve
        Backline.own_reserve
      end

      # (see MGQ_MpBattles::Mode#other_reserve)
      def self.other_reserve
        Backline.reserve
      end

      # (see MGQ_MpBattles::Mode#reserve_ref)
      def self.reserve_ref(battler)
        return nil unless Backline.on?
        return "b#{battler.id}" if Backline.own_reserve.include?(battler)

        Backline.reserve.include?(battler) ? "r#{battler.id}" : nil
      end

      # (see MGQ_MpBattles::Mode#reserve)
      def self.reserve(ref)
        return nil unless Backline.on? && ref =~ RESERVE_REF

        id = $2.to_i
        # The host's own characters are this game's other side, and the host's other side this game's own.
        $1 == "b" ? Backline.opponent(id) : $game_party.all_members.find { |actor| actor.id == id }
      end
    end
  end
end

begin
  MGQ_MpBattles.mode(:duel, MGQ_MpBattlesPvp::Backline::Mode)
rescue => e
  MGQ_MpBattlesPvp.log("Backline mode FAILED: #{e.class}: #{e.message}")
end

begin
  MGQ_MpBattlesPvp::Backline.register
rescue => e
  MGQ_MpBattlesPvp.log("Backline option FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # Installs the hooks as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_pvp_backline") { MGQ_MpBattlesPvp::Backline.install }
rescue => e
  MGQ_MpBattlesPvp.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
end
