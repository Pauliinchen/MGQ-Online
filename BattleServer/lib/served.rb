#----------------------------------------------------------------
#  served.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Read the boss pools the relay told and forgot the last battle's boss fight
#                            - Created
#
#----------------------------------------------------------------

require_relative "battle"
require_relative "online"

# Hosts one co-op battle MGQ Online handed to the battle server: the game's own battle scene with
# MGQ Online's live host, which streams it to the players over the battle channel and takes their
# commands. The server has no characters of its own; every player plays the battle back as a
# guest (see the game's battles_served.rbx).
module ServedBattle
  # Seconds a frame takes while a battle is hosted: the players play the stream back in real
  # time and skip ahead once the host runs far ahead, so the host keeps the game's pace.
  FRAME_SECONDS = 1.0 / 60

  # The highest seat of a world's room, which seats 32 games.
  WORLD_SEATS = 31

  # Frames between two reads of the boss pools the relay told, as the game reads the DLL's.
  POOL_FRAMES = 10

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
    # skip key held, the first of every choice, how the battle ended, and each frame lasting
    # FRAME_SECONDS. MGQ Online's live host takes the players' commands and keeps the battle's
    # course. Wrapped as MGQ Online's hooks are (see Boot::Wrap), since they wrap the same methods.
    #
    # @param log [IO] Where MGQ Online's log goes.
    def install(log = $stderr)
      Online.install(log)
      wrap = Boot::Wrap
      %i[trigger? press?].each do |name|
        wrap.around(Input.singleton_class, name, :served) do |_input, original, args, _block|
          key = args[0]
          next true if key == HeadlessBattle::SKIP_KEY
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
      wrap.around(BattleManager.singleton_class, :battle_end, :served) do |_manager, original, args, _block|
        HeadlessBattle.take_result(args[0])
        original.call(*args)
      end
      wrap.around(Graphics.singleton_class, :update, :served) do |_graphics, original, args, _block|
        original.call(*args)
        ServedBattle.read_pools
        ServedBattle.pace
      end
      @paced = true
    end

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
    # @return [Hash] :result (:victory, :defeat, :escape, :abort or the scene the battle left for),
    #   :turns and :frames.
    # @raise [Refused] For a setup the server cannot read.
    def run(bridge, battle_id, setup_text)
      setup = check(setup_text)
      Online.connect(bridge)
      BOSS_SCRIPTS.each { |name| Object.const_get(name).forget if Object.const_defined?(name) }
      DataManager.create_game_objects
      MGQ_MpBattlesServed.host(battle_id, setup)
      # The map saves its music before a battle, and the battle's end plays it again.
      BattleManager.save_bgm_and_bgs
      Graphics.frame_count = 0
      @next_frame = clock
      SceneManager.instance_variable_set(:@stack, [])
      SceneManager.instance_variable_set(:@scene, Scene_Battle.new)
      HeadlessBattle.instance_variable_set(:@result, nil)
      while (scene = SceneManager.scene).is_a?(Scene_Battle)
        scene.main
      end
      MGQ_MpBattlesSync.finish
      result = HeadlessBattle.instance_variable_get(:@result) || (scene ? scene.class.name.to_sym : :ended)
      { result: result, turns: $game_troop.turn_count, frames: Graphics.frame_count }
    ensure
      bridge&.close
    end

    # Reads a setup and refuses one the server cannot host.
    #
    # @param setup_text [String] What the starter sent, see MGQ_MpBattlesServed.setup_text.
    # @return [Hash] The setup, see MGQ_MpBattlesServed.read_setup.
    # @raise [Refused] For a setup of another format, a troop without enemies or no players.
    def check(setup_text)
      setup = MGQ_MpBattlesServed.read_setup(setup_text)
      raise Refused.new("setup", "a setup of another format") unless setup
      # Other scripts would host by another protocol, other game data with other rules.
      raise Refused.new("scripts", "the starter's MGQ Online differs from the server's") unless setup[:scripts] == MGQ_MpBattlesServed.scripts_fingerprint
      raise Refused.new("data", "the starter's game data differs from the server's") unless setup[:data] == MGQ_MpWorld::GameData.fingerprint
      raise Refused.new("setup", "troop #{setup[:troop]} has no enemies") unless setup[:troop].positive? && $data_troops[setup[:troop]]&.members&.any?
      raise Refused.new("setup", "a battle without players") if setup[:players].empty?

      seats = setup[:players].map(&:seat)
      raise Refused.new("setup", "players on seats #{seats.inspect}, not distinct world seats") unless seats.uniq.size == seats.size && seats.all? { |seat| seat.is_a?(Integer) && (0..WORLD_SEATS).cover?(seat) }

      setup
    end

    # Takes the boss pools the relay told every POOL_FRAMES frames while the battle fights a Raid
    # World's pools, as the game takes the DLL's: what the server's reports did and other battles'
    # blows.
    def read_pools
      return unless (Graphics.frame_count % POOL_FRAMES).zero? && defined?(MGQ_MpRaidPool) && MGQ_MpRaidPool.fight

      MGQ_MpRaidPool.read_state
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

    # The time in seconds.
    #
    # @return [Float] The time.
    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
