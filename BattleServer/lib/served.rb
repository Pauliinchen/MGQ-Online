#----------------------------------------------------------------
#  served.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Took the message skip key and the battle's result over from the removed battles by request
#      Paulinchen  2026-11-05: Took the starter's mod options as the values the core read from the setup
#      Paulinchen  2026-10-30: Checked a setup through the core
#                            - Handed the core's ledger what the relay told of the boss pools before the scripts read them
#                            - Sent the reports of a raid boss fight's turns from the core's outbox
#      Paulinchen  2026-10-23: Took the default squad rules from the core through battles_served.rbx
#                            - Took the default squad rules from battles_served.rbx
#                            - Updated the windows and sprites on every sixth frame while the battle waits for its players
#                            - Counted down the grace of the players kept away
#      Paulinchen  2026-10-15: Left recruiting to the players' games
#                            - Read the boss pools the relay told and forgot the last battle's boss fight
#                            - Hosted a Raid World's battle as one, took players in late and told the starter the battle's state
#                            - Loaded the world's mods for the battle and gave it the starter's options of them
#                            - Created
#
#----------------------------------------------------------------

require_relative "online"
require_relative "mods"

# Hosts one co-op battle MGQ Online handed to the battle server: the game's own battle scene with
# MGQ Online's live host, which streams it to the players over the battle channel and takes their
# commands. The server has no characters of its own; every player plays the battle back as a
# guest (see the game's battles_served.rbx).
module ServedBattle
  # Seconds a frame takes while a battle is hosted: the players play the stream back in real
  # time and skip ahead once the host runs far ahead, so the host keeps the game's pace.
  FRAME_SECONDS = 1.0 / 60

  # The key the game skips messages with while it is held.
  SKIP_KEY = :X

  # The battle's results by the code BattleManager.battle_end gets.
  RESULTS = { 0 => :victory, 1 => :escape, 2 => :defeat }.freeze

  # Frames between two reads of the boss pools the relay told, as the game reads the DLL's.
  POOL_FRAMES = 10

  # Frames of a wait for the players in which the battle's windows and sprites update once: nobody
  # sees the server's screen, and they take most of a waiting frame's time.
  WAIT_DRAW_FRAMES = 6

  # MGQ Online's scripts that keep a battle's boss fight from one battle to the next, which a
  # battle on a server that hosts one after another must forget first.
  BOSS_SCRIPTS = %i[MGQ_MpRaidPool MGQ_MpRaidTiers].freeze

  # Raised for a battle the server cannot host, such as a setup of another format.
  class Refused < StandardError
    # Why, as the relay hands it to the starter: setup, scripts or data.
    attr_reader :code

    # Creates the refusal.
    #
    # @param code [String] Why, see code.
    # @param message [String] What went wrong.
    def initialize(code, message)
      super(message)
      @code = code
    end
  end

  class << self
    # Whether frames keep the game's pace; tests turn it off.
    attr_accessor :paced

    # Puts the server's battle hosting in place, once the game and MGQ Online loaded: the message
    # skip key held, the first of every choice, how the battle ended, each frame lasting
    # FRAME_SECONDS, and the windows and sprites updated less while the battle waits for its players. MGQ Online's live host takes the players' commands and keeps the battle's
    # course. Wrapped as MGQ Online's hooks are (see Boot::Wrap), since they wrap the same methods.
    #
    # @param log [IO] Where MGQ Online's log goes.
    def install(log = $stderr)
      Online.install(log)
      wrap = Boot::Wrap
      %i[trigger? press?].each do |name|
        wrap.around(Input.singleton_class, name, :served) do |_input, original, args, _block|
          key = args[0]
          next true if key == SKIP_KEY
          next Graphics.frame_count.odd? if key == :C

          original.call(*args)
        end
      end
      { input_choice: :@choice_window, input_ex_choice: :@ex_choice_window }.each do |name, field|
        next unless Window_Message.method_defined?(name) || Window_Message.private_method_defined?(name)

        wrap.around(Window_Message, name, :served) { |window, _original, _args, _block| ServedBattle.pick(window.instance_variable_get(field)) }
      end
      # The server's party is empty until the roster forms it, and the guests roll their escapes.
      wrap.around(BattleManager.singleton_class, :make_escape_ratio, :served) do |manager, original, args, _block|
        next manager.instance_variable_set(:@escape_ratio, 0.0) if $game_party.all_members.empty?

        original.call(*args)
      end
      # Each player's game offers its own recruit after the battle; one the server rolled would join
      # its party, which nobody keeps.
      if BattleManager.respond_to?(:process_follow, true)
        wrap.around(BattleManager.singleton_class, :process_follow, :served) { nil }
      end
      wrap.around(BattleManager.singleton_class, :battle_end, :served) do |_manager, original, args, _block|
        ServedBattle.take_result(args[0])
        original.call(*args)
      end
      wrap.around(Graphics.singleton_class, :update, :served) do |_graphics, original, args, _block|
        original.call(*args)
        ServedBattle.count_waiting
        ServedBattle.read_pools
        ServedBattle.tell_front
        ServedBattle.pace
        # The world sync tick is left out below, so the players kept away count down their grace here.
        MGQ_MpOverworldSync::Peers.tick if MGQ_MpBattlesServed.server?
      end
      # The battle's course runs every frame; only what it shows waits for the next drawn frame.
      wrap.around(Scene_Base, :update_all_windows, :served) { |_scene, original, args, _block| original.call(*args) if ServedBattle.drawing? }
      wrap.around(Spriteset_Battle, :update, :served) { |_spriteset, original, args, _block| original.call(*args) if ServedBattle.drawing? }
      # The server sits in no world, so the battle's world type comes with its setup.
      wrap.around(MGQ_MpWorld.singleton_class, :raid?, :served) do |_world, original, args, _block|
        ServedBattle.raid.nil? ? original.call(*args) : ServedBattle.raid
      end
      wrap.around(MGQ_MpWorld.singleton_class, :squad, :served) do |_world, original, args, _block|
        next original.call(*args) if ServedBattle.raid.nil?

        ServedBattle.raid ? (ServedBattle.squad || MGQ_MpBattlesServed.default_squad).dup : nil
      end
      # Outside a world the tick forgets every player and the seat, which the server holds for the
      # players its starter passed on and the battle channel.
      wrap.around(MGQ_MpOverworldSync.singleton_class, :tick, :served) { nil }
      # What the relay told of the pools waits on the bridge's reading thread until the scripts read them.
      if defined?(MGQ_MpRaidPool)
        wrap.around(MGQ_MpRaidPool.singleton_class, :read_state, :served) do |_pool, original, args, _block|
          Online.flush_pools
          original.call(*args)
        end
        # The core has no network: a fight's turn leaves its reports in the core's outbox.
        wrap.around(MGQ_MpRaidPool.singleton_class, :turn, :served) do |_pool, original, args, _block|
          reply = original.call(*args)
          Online.send_reports
          reply
        end
      end
      # The players the battle takes in late may come onto its channel from then on.
      wrap.around(MGQ_MpBattlesSync.singleton_class, :expect, :served) do |_sync, original, args, _block|
        original.call(*args)
        Online.bridge&.admit(Array(args[0]))
      end
      @paced = true
    end

    # Whether the battle hosted now is a Raid World's, as its setup says; nil between battles.
    attr_reader :raid

    # The squad rules of the Raid World whose battle is hosted now, as its setup says; nil for none.
    attr_reader :squad

    # Confirms the first choice of a choice window at once, as nobody chooses on the server.
    #
    # @param window [Window_ChoiceList] The window.
    def pick(window)
      window.start
      return unless window.active

      window.select(0)
      window.call_ok_handler
      window.deactivate
    end

    # Hosts a battle to its end.
    #
    # @param bridge [Online::Bridge, #send_to] The battle channel's other end.
    # @param battle_id [String] The battle's id.
    # @param setup_text [String] What the starter sent, see MGQ_MpBattlesServed.setup_text.
    # @param mods [Array] The world's mods the starter runs, see ServedMods.fetch.
    # @return [Hash] :result (:victory, :defeat, :escape, :abort or the scene the battle left for),
    #   :turns and :frames.
    # @raise [Refused] For a setup the server cannot read.
    def run(bridge, battle_id, setup_text, mods = [])
      setup = check(setup_text)
      Online.connect(bridge)
      ServedMods.load(mods) unless mods.empty?
      @raid = setup[:raid]
      @squad = setup[:squad]
      BOSS_SCRIPTS.each { |name| Object.const_get(name).forget if Object.const_defined?(name) }
      DataManager.create_game_objects
      apply_settings(setup[:settings])
      MGQ_MpBattlesServed.host(battle_id, setup)
      # The map saves its music before a battle, and the battle's end plays it again.
      BattleManager.save_bgm_and_bgs
      Graphics.frame_count = 0
      @waiting_frames = 0
      @next_frame = clock
      SceneManager.instance_variable_set(:@stack, [])
      SceneManager.instance_variable_set(:@scene, Scene_Battle.new)
      @result = nil
      while (scene = SceneManager.scene).is_a?(Scene_Battle)
        scene.main
      end
      MGQ_MpBattlesSync.finish
      result = @result || (scene ? scene.class.name.to_sym : :ended)
      { result: result, turns: $game_troop.turn_count, frames: Graphics.frame_count }
    ensure
      @raid = nil
      @squad = nil
      bridge&.close
    end

    # Keeps how the battle ended, as BattleManager.battle_end tells it.
    #
    # @param result [Integer] 0 for a victory, 1 for an escape, 2 for a defeat.
    def take_result(result)
      @result = RESULTS[result] || result
    end

    # Reads a setup and refuses one the server cannot host, as the core checks it
    # (MGQ_MpBattlesServed.refusal_of): other scripts would host by another protocol, other game
    # data with other rules; a troop without enemies, no players or players not on distinct world
    # seats with the starter among them cannot be hosted. Only whether the troop has enemies comes
    # from the server's database here.
    #
    # @param setup_text [String] What the starter sent, see MGQ_MpBattlesServed.setup_text.
    # @return [Hash] The setup, see MGQ_MpBattlesServed.read_setup.
    # @raise [Refused] For a setup the server cannot host.
    def check(setup_text)
      setup = MGQ_MpBattlesServed.read_setup(setup_text)
      raise Refused.new("setup", "a setup of another format") unless setup

      troop = setup[:troop]
      code, why = MGQ_MpBattlesServed.refusal_of(setup_text, troop.positive? && $data_troops[troop]&.members&.any?)
      raise Refused.new(code, why) if code

      setup
    end

    # Tells the starter the server's state for the world's players every
    # MGQ_MpBattlesServed::FRONT_STATE_FRAMES frames, see MGQ_MpBattlesServed.tell_front_state.
    def tell_front
      return unless (Graphics.frame_count % MGQ_MpBattlesServed::FRONT_STATE_FRAMES).zero? && MGQ_MpBattlesServed.server?

      MGQ_MpBattlesServed.tell_front_state
    end

    # Gives the battle's game the starter's options of the world's mods, as a world's shared
    # settings are given (see MGQ_MpWorldMods.apply_values).
    #
    # @param settings [Array<Array(String, Object)>, nil] The options as the core read them from the
    #   setup, see MGQ_MpWorldMods.settings_of.
    def apply_settings(settings)
      return if Array(settings).empty? || !defined?(MGQ_MpWorldMods)

      MGQ_MpWorldMods.apply_values(MGQ_MpWorldMods.settings_of(settings))
    end

    # Reads the boss pools every POOL_FRAMES frames while the battle fights a Raid World's pools, as
    # the game reads them: what the server's reports did and other battles' blows the relay told.
    def read_pools
      return unless (Graphics.frame_count % POOL_FRAMES).zero? && defined?(MGQ_MpRaidPool) && MGQ_MpRaidPool.fight

      MGQ_MpRaidPool.read_state
    end

    # Counts the frames of the wait for the players that is open now, see drawing?.
    def count_waiting
      @waiting_frames = waiting? ? @waiting_frames.to_i + 1 : 0
    end

    # Tells whether the battle's windows and sprites update this frame: on every frame, except while
    # the battle waits for its players, on every WAIT_DRAW_FRAMES-th.
    #
    # @return [Boolean] Whether they do.
    def drawing?
      (@waiting_frames.to_i % WAIT_DRAW_FRAMES).zero?
    end

    # Waits out the rest of a frame's time while a battle is hosted.
    def pace
      return unless @paced && @next_frame

      @next_frame += FRAME_SECONDS
      late = @next_frame - clock
      if late.positive?
        sleep(late)
      elsif late < -1
        # A frame that took far longer, such as a heavy turn, never makes the next ones hurry.
        @next_frame = clock
      end
    end

    private

    # Tells whether the battle waits for its players, see MGQ_MpBattlesSync::Waiting.active?.
    #
    # @return [Boolean] Whether it does; false for an MGQ Online without such waits.
    def waiting?
      waits = defined?(MGQ_MpBattlesSync::Waiting) && MGQ_MpBattlesSync::Waiting
      waits && waits.respond_to?(:active?) && waits.active? ? true : false
    end

    # The time in seconds.
    #
    # @return [Float] The time.
    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
