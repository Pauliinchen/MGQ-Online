#----------------------------------------------------------------
#  battle.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require "stringio"
require_relative "save"

# Runs one battle of the game's own Scene_Battle without a screen: the commands come from the
# caller instead of the command windows, every message is confirmed at once, and the battle log's
# lines are kept.
module HeadlessBattle
  # Frames one turn may take before the battle counts as stuck, 5 minutes at 60 frames a second;
  # a battle of many turns may take as long as it needs.
  TURN_FRAME_LIMIT = 60 * 60 * 5

  # Escape codes the battle log's lines carry, such as \C[2] and \I[15].
  ESCAPE_CODE = /\\[A-Za-z]+(\[[^\]]*\])?|\e[A-Za-z]+(\[[^\]]*\])?/

  # The game's common event that turns the difficulty into the enemies' stat variables; enemies
  # made before it ran have 1 HP.
  DIFFICULTY_EVENT = 112

  # Frames a common event run outside a battle may take.
  EVENT_FRAME_LIMIT = 600

  # The key the game skips messages with while it is held.
  SKIP_KEY = :X

  # The game's three levels of an actor: its own, its job's and its race's.
  LEVEL_KINDS = %i[base class tribe].freeze

  # Turns a battle may last; some fights cannot be won by the commands given, such as Chrome Doll
  # Mk.I against auto battle, and would hold their process forever.
  TURN_LIMIT = 300

  # Raised when a turn takes more frames than TURN_FRAME_LIMIT.
  class Stuck < StandardError; end

  # Raised when a battle reaches TURN_LIMIT.
  class TurnLimit < StandardError; end

  class << self
    # The battle log's lines so far.
    attr_reader :log

    # Runs a battle.
    #
    # @param troop_id [Integer] The troop to fight.
    # @param party [Array<Array(Integer, Integer)>] Each actor's id and level, for a fresh game.
    # @param save [String, nil] A save file's bytes: the battle starts from its party, inventory,
    #   switches and variables instead of a fresh game with the party.
    # @param system [String, nil] The player's system save's bytes: its library's lifetime counts
    #   raise some damage; nil fights with a fresh library, as on a new install.
    # @param seed [Integer] The random seed, so a battle replays the same.
    # @param commander [#call, nil] Gets the actors whose commands are due and the turn, and fills
    #   their actions; nil lets the game's auto battle choose.
    # @param chooser [#call, nil] Gets the names of choices the battle offers, such as an ero
    #   offer, and answers the index picked; nil always picks the first.
    # @param switches [Hash{Integer => Boolean}] The game switches the battle runs with.
    # @param variables [Hash{Integer => Integer}] The game variables the battle runs with.
    # @return [Hash] The outcome: result (:victory, :defeat, :escape or :turn_limit), turns,
    #   frames, the log and the battlers.
    def run(troop_id:, party: [], save: nil, system: nil, seed: 1, commander: nil, chooser: nil,
            switches: {}, variables: {})
      check(troop_id, save ? nil : party)
      @log = []
      @commander = commander || method(:auto_command)
      @chooser = chooser || ->(_names) { 0 }
      @turn = 0
      @seed = seed
      SaveFile.extract_system(system)
      save ? load_save(save) : setup_party(party)
      switches.each { |id, value| $game_switches[id] = value }
      variables.each { |id, value| $game_variables[id] = value }
      # A save's variables are as the game left them, the Chaos Labyrinth's own difficulty too.
      run_common_event(DIFFICULTY_EVENT) unless save
      # Seeded right before the troop and again as the battle scene starts (SceneHooks#start), the
      # only two points the real game can match: it draws random numbers in its other scenes.
      srand(seed)
      BattleManager.setup(troop_id, true, true)
      # The map saves its music before a battle, and the victory plays it again.
      BattleManager.save_bgm_and_bgs
      result = begin
        drive
      rescue TurnLimit
        :turn_limit
      end
      { result: result, turns: @turn, frames: Graphics.frame_count, log: @log,
        party: @end_party || $game_party.battle_members.map { |actor| battler_line(actor) },
        troop: @end_troop || $game_troop.members.map { |enemy| battler_line(enemy) } }
    end

    # The seed the battle scene starts with: the battle's seed plus one.
    #
    # @return [Integer] The seed.
    def scene_seed
      @seed.to_i + 1
    end

    # Hands the actors whose commands are due to the commander, then starts the turn.
    #
    # @param scene [Scene_Battle] The battle.
    def command_turn(scene)
      raise TurnLimit if @turn >= TURN_LIMIT

      @turn += 1
      @commander.call($game_party.battle_members.select(&:inputable?), @turn)
      @turn_started = Graphics.frame_count
      scene.send(:turn_start)
    end

    # Asks the chooser to pick one of the choices the battle offers, and logs the pick.
    #
    # @param names [Array<String>] The choices' names.
    # @return [Integer] The index picked.
    def choose(names)
      index = @chooser.call(names).to_i.clamp(0, [names.size - 1, 0].max)
      @log << "[choice] #{names[index]} (of #{names.join(" / ")})"
      index
    end

    # Keeps a line of the battle log, without its escape codes.
    #
    # @param text [String] The line.
    def take_line(text)
      line = text.to_s.gsub(ESCAPE_CODE, "").strip
      @log << line unless line.empty? || @log.last == line
    end

    # Whether a message waiting for a key is confirmed this frame: every other frame, so a
    # window sees the key go down and up again.
    #
    # @return [Boolean] Whether it is.
    def confirm_frame?
      Graphics.frame_count.odd?
    end

    private

    # Lets the game choose the actors' actions, as its auto battle does.
    #
    # @param actors [Array<Game_Actor>] The actors.
    # @param _turn [Integer] The turn.
    def auto_command(actors, _turn)
      actors.each(&:make_auto_battle_actions)
    end

    # Refuses a troop without enemies and a party without actors of the database, before the game
    # meets them halfway through a battle.
    #
    # @param troop_id [Integer] The troop.
    # @param party [Array<Array(Integer, Integer)>, nil] Each actor's id and level; nil when the
    #   party comes from a save.
    def check(troop_id, party)
      troop = troop_id.positive? ? $data_troops[troop_id] : nil
      raise ArgumentError, "troop #{troop_id} has no enemies" if troop.nil? || troop.members.empty?
      return unless party
      raise ArgumentError, "the party has no actors" if party.empty?

      party.each do |id, _level|
        raise ArgumentError, "actor #{id} is not in the database" unless id.positive? && $data_actors[id]
      end
    end

    # Runs a common event to its end at once, as the map would over several frames.
    #
    # @param id [Integer] The common event.
    def run_common_event(id)
      interpreter = Game_Interpreter.new
      interpreter.setup($data_common_events[id].list)
      EVENT_FRAME_LIMIT.times do
        break unless interpreter.running?

        interpreter.update
      end
    end

    # Puts a save's state in place, as loading it from the title does, and refuses a save
    # without anyone to fight.
    #
    # @param bytes [String] The save file's bytes.
    def load_save(bytes)
      DataManager.create_game_objects
      SaveFile.extract(SaveFile.read(bytes)[1])
      raise ArgumentError, "the save's party has nobody to fight" if $game_party.battle_members.empty?
    end

    # Makes a fresh game on the starting map whose party is the given actors at their levels,
    # healed.
    #
    # @param party [Array<Array(Integer, Integer)>] Each actor's id and level.
    def setup_party(party)
      DataManager.setup_new_game
      $game_party.members.map(&:id).each { |id| $game_party.remove_actor(id) }
      party.each do |id, level|
        actor = $game_actors[id]
        LEVEL_KINDS.each { |kind| actor.change_level(level, false, kind) }
        $game_party.add_actor(id)
        actor.recover_all
      end
    end

    # Runs the battle scene until it ends.
    #
    # @return [Symbol] :victory, :defeat, :escape or the scene the battle left for.
    def drive
      Graphics.frame_count = 0
      @turn_started = 0
      SceneManager.instance_variable_set(:@stack, [])
      SceneManager.instance_variable_set(:@scene, Scene_Battle.new)
      @result = @end_party = @end_troop = nil
      while (scene = SceneManager.scene).is_a?(Scene_Battle)
        scene.main
      end
      @result || (scene ? scene.class.name.to_sym : :ended)
    end

    public

    # Notes how the battle ended, as BattleManager tells it.
    #
    # @param result [Integer] 0 for a victory, 1 for an escape, 2 for a defeat.
    def take_result(result)
      @result = { 0 => :victory, 1 => :escape, 2 => :defeat }[result] || result
      # As the battle ends, before it clears the battlers' states.
      @end_party = $game_party.battle_members.map { |actor| battler_line(actor) }
      @end_troop = $game_troop.members.map { |enemy| battler_line(enemy) }
    end

    # Counts a frame, and stops a battle whose turn went on too long.
    def tick
      return if Graphics.frame_count - @turn_started.to_i <= TURN_FRAME_LIMIT

      message = $game_message
      raise Stuck, "turn #{@turn} took more than #{TURN_FRAME_LIMIT} frames; message: " \
                   "texts #{message.texts.inspect[0, 160]}, choices #{message.choices.inspect[0, 160]}, " \
                   "number input #{message.num_input_variable_id}, item choice #{message.item_choice_variable_id}"
    end

    private

    public

    # A battler's name, HP and states, for the outcome.
    #
    # @param battler [Game_Battler] The battler.
    # @return [String] The line.
    def battler_line(battler)
      states = battler.states.map(&:name).reject(&:empty?)
      "#{battler.name} #{battler.hp}/#{battler.mhp} HP#{states.empty? ? "" : " [#{states.join(", ")}]"}"
    end
  end

  # The battle scene's changes: commands from the commander instead of the party and actor
  # command windows.
  module SceneHooks
    # Starts the battle scene, seeded anew so it plays the same as in the game.
    def start
      srand(HeadlessBattle.scene_seed)
      super
    end

    # Starts the commands of a turn: the commander's, or none when the party cannot act.
    def start_party_command_selection
      return if scene_changing?

      refresh_status
      if BattleManager.input_start
        HeadlessBattle.command_turn(self)
      else
        turn_start
      end
    end
  end

  # The battle scene's waits: a pause of any length takes one frame, since nobody watches the
  # battle log on a server. The one frame still updates the troop and the timer as a wait does.
  module WaitHooks
    # Waits one frame instead of the pause.
    def wait(_duration)
      update_for_wait
    end

    # Waits one frame instead of the pause the game never shortens.
    def abs_wait(_duration)
      update_for_wait
    end
  end

  # The battle log's change: it keeps every line it shows.
  module LogHooks
    # Shows a line, and keeps it.
    #
    # @param text [String] The line.
    def add_text(text)
      HeadlessBattle.take_line(text)
      super
    end

    # Replaces the last line, and keeps the new one.
    #
    # @param text [String] The line.
    def replace_text(text)
      HeadlessBattle.take_line(text)
      super
    end
  end

  # The message window's change: the chooser picks a choice at once, instead of the player with
  # the keys.
  module ChoiceHooks
    # Lets the chooser pick one of the game's choices.
    def input_choice
      pick(@choice_window)
    end

    # Lets the chooser pick one of the extended choices.
    def input_ex_choice
      pick(@ex_choice_window)
    end

    private

    # Opens a choice window and confirms the chooser's pick in it.
    #
    # @param window [Window_ChoiceList] The window.
    def pick(window)
      window.start
      return unless window.active

      names = window.instance_variable_get(:@list).map { |command| command[:name].to_s.gsub(ESCAPE_CODE, "") }
      window.select(HeadlessBattle.choose(names))
      window.call_ok_handler
      window.deactivate
    end
  end

  # BattleManager's change: it tells how the battle ended.
  module ManagerHooks
    # Ends the battle, noting how.
    #
    # @param result [Integer] 0 for a victory, 1 for an escape, 2 for a defeat.
    def battle_end(result)
      HeadlessBattle.take_result(result)
      super
    end
  end

  # The keys' change: the game's message skip key is held for good, so messages and waits pass
  # at once, and confirm counts as pressed every other frame for anything else that waits.
  module InputHooks
    # Tells whether a key was pressed this frame.
    #
    # @param key [Symbol] The key.
    # @return [Boolean] Whether it was.
    def trigger?(key)
      case key
      when SKIP_KEY then true
      when :C then HeadlessBattle.confirm_frame?
      else super
      end
    end

    # Tells whether a key is held.
    #
    # @param key [Symbol] The key.
    # @return [Boolean] Whether it is.
    def press?(key)
      case key
      when SKIP_KEY then true
      when :C then HeadlessBattle.confirm_frame?
      else super
      end
    end
  end

  # The screen's change: every frame checks the battle's frame limit.
  module GraphicsHooks
    # Counts a frame and checks the limit.
    def update
      super
      HeadlessBattle.tick
    end
  end

  # Puts the changes in place, once the game's scripts are loaded.
  def self.install
    Scene_Battle.prepend(SceneHooks)
    # BATTLE_FULL_WAITS=1 keeps the game's pauses, to compare a battle with them and without.
    Scene_Battle.prepend(WaitHooks) unless ENV["BATTLE_FULL_WAITS"] == "1"
    Window_BattleLog.prepend(LogHooks)
    Window_Message.prepend(ChoiceHooks)
    BattleManager.singleton_class.prepend(ManagerHooks)
    Input.singleton_class.prepend(InputHooks)
    Graphics.singleton_class.prepend(GraphicsHooks)
  end
end
