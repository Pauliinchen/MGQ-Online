#----------------------------------------------------------------
#  world_difficulty.rbx
#
#  Changelog:
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# A Raid World's difficulty, which its creator sets for every player: each game in the world plays
# on it from entering, loading a save and a new game on, and from the moment the creator or an
# admin changes it. The game's own choice of the difficulty, at the start of a new game and at the
# Reaper in Hades, which calls that choice, sets the world's instead.
#
# The Labyrinth of Chaos, the Colosseum, the special bosses and the final battles set values of
# their own for their fights, the same for every player, and keep the difficulty they replace to
# put it back afterwards. While any of them has its values set, nothing here writes the difficulty
# or works its enemy rates out again; the world's comes back once the game put its own back.
module MGQ_MpWorldDifficulty
  # The game's difficulty, from -2 (VERY EASY) to 4 (PARADOX).
  VARIABLE = defined?(NWConst::Var::CURRENT_DIFFICULTY) ? NWConst::Var::CURRENT_DIFFICULTY : 902

  # The common event that works the enemies' rates out from the difficulty.
  APPLY_EVENT = 112

  # The common event of the game's own difficulty choice, which the start of a new game, the choice
  # after a defeat and the Reaper's difficulty change in Hades (common event 146) call.
  CHOICE_EVENT = 110

  # The switches the game turns on while it sets values of its own for a fight: a special boss's
  # NORMAL on EASY and below (23), the Labyrinth of Chaos, whose rates come from its level (41), and
  # the final battles' fixed NORMAL (507).
  OWN_VALUE_SWITCHES = [23, 41, 507]

  # The switch the Colosseum turns on while it plays its fights on NORMAL.
  COLOSSEUM = 28

  # The switch of a Colosseum match under way, which ends with a win and with a defeat.
  COLOSSEUM_MATCH = 87

  # Frames between two looks whether the game plays on the world's difficulty.
  CHECK_FRAMES = 30

  # How often the enemy rates' common event is stepped at most, which runs to its end in one step.
  MAX_STEPS = 4

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "world difficulty"

  @frames = 0

  # Tells the difficulty the open Raid World sets for every player.
  #
  # @return [Integer, nil] The difficulty; nil outside Raid Worlds and in one that sets none.
  def self.value
    MGQ_MpWorld.difficulty
  end

  # Tells whether the game has values of its own set for a fight, which the world's difficulty
  # never writes over: in the Labyrinth of Chaos, the Colosseum, a special boss's or the final
  # battles' fixed NORMAL.
  #
  # The Colosseum counts only during a match: a defeat there puts the difficulty back but leaves
  # COLOSSEUM on, which the game turns off only at its next win or leave.
  #
  # @return [Boolean] Whether it has.
  def self.own_values?
    OWN_VALUE_SWITCHES.any? { |id| $game_switches[id] } || ($game_switches[COLOSSEUM] && $game_switches[COLOSSEUM_MATCH]) ? true : false
  end

  # Tells whether the game plays on another difficulty than the world's and may be put on it now: a
  # Raid World with a difficulty, no fight with values of its own, no battle, and no event or
  # message running on the map, since an event may be one that sets those values.
  #
  # @return [Boolean] Whether it may.
  def self.due?
    world = value
    !world.nil? && $game_variables[VARIABLE] != world && !own_values? && !$game_party.in_battle && MGQ_MpOverworldSync.map_quiet?
  end

  # Puts the game on the world's difficulty, unless a fight has values of its own set, and works the
  # enemies' rates out at once, since a battle's enemies are made before its start works them out.
  #
  # @param reason [String] Why, for the log.
  # @return [Boolean] Whether it did.
  def self.apply(reason)
    world = value
    return false if world.nil?

    if own_values?
      log_once([:own_values, reason], "#{reason}: the game has a fight's own values set, the world's difficulty waits until it put its own back")
      return false
    end

    before = $game_variables[VARIABLE]
    $game_variables[VARIABLE] = world
    work_out_rates
    log("#{reason}: playing on #{MGQ_MpWorld.difficulty_name(world)}#{before == world ? '' : " instead of #{MGQ_MpWorld.difficulty_name(before) || before.inspect}"}")
    true
  rescue => e
    log("putting the game on the world's difficulty failed (#{reason}): #{e.class}: #{e.message}")
    false
  end

  # Runs the game's own common event that works the enemies' rates out from the difficulty, as its
  # own difficulty choice does right after setting it.
  def self.work_out_rates
    event = $data_common_events && $data_common_events[APPLY_EVENT]
    return unless event

    interpreter = Game_Interpreter.new
    interpreter.setup(event.list)
    steps = 0
    while interpreter.running? && steps < MAX_STEPS
      interpreter.update
      steps += 1
    end
  end

  # Puts the game on the world's difficulty after a save was loaded or a new game started, which
  # bring their own.
  #
  # @param reason [Symbol] :load or :new_game.
  def self.loaded(reason)
    apply(reason == :load ? "a save was loaded" : "a new game started") unless value.nil?
  end

  # Looks every few frames on the map whether the game plays on the world's difficulty, which it
  # does not after the creator changed it or once a fight put back what it kept.
  def self.tick
    @frames += 1
    return if @frames < CHECK_FRAMES

    @frames = 0
    apply("the game played on another difficulty") if due?
  rescue => e
    log_once([:tick, e.class], "looking at the difficulty failed: #{e.class}: #{e.message}")
  end

  # Takes the relay's word that the open Raid World's creator or an admin changed its difficulty,
  # which the next look puts the game on.
  #
  # @param message [Hash] The push: MGQ_MpOverworldSync::DIFFICULTY_FIELD with the difficulty,
  #   marked :relay by overworld_sync.rbx.
  def self.pushed(message)
    return log("ignored a difficulty push not from the relay") unless message[:relay]

    world = MGQ_MpWorld.difficulty_of(message[MGQ_MpOverworldSync::DIFFICULTY_FIELD])
    return log("ignored the relay's difficulty #{message[MGQ_MpOverworldSync::DIFFICULTY_FIELD].inspect}") if world.nil?
    return if world == value
    return log("ignored the relay's difficulty outside a Raid World") unless MGQ_MpWorld.take_difficulty(world)

    log("the relay tells the world plays on #{MGQ_MpWorld.difficulty_name(world)} now")
    MGQ_MpOverworldSync.notice("The world plays on #{MGQ_MpWorld.difficulty_name(world)} now.")
    @frames = CHECK_FRAMES
  rescue => e
    log("taking the relay's difficulty failed: #{e.class}: #{e.message}")
  end

  # Changes the command an interpreter is about to run in a Raid World with a difficulty: the
  # game's own difficulty choice sets the world's instead. Called before every event command.
  #
  # The Reaper's change in Hades runs as the game has it, since only it erases the Reaper's picture
  # afterwards; its own call of the choice comes here too.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.before_command(interpreter)
    list = MGQ_MpGame.get(interpreter, :list)
    index = MGQ_MpGame.get(interpreter, :index)
    command = list && index ? list[index] : nil
    return unless command && command.code == 117 && command.parameters[0] == CHOICE_EVENT

    world = value
    return if world.nil?

    log("the game's own difficulty choice was called: #{own_values? ? 'left out while a fight has its own values set' : "the world sets #{MGQ_MpWorld.difficulty_name(world)} instead"}")
    MGQ_MpOverworldSync.notice("The world sets the difficulty: #{MGQ_MpWorld.difficulty_name(world)}.")
    MGQ_MpGame.set(interpreter, :list, replaced_list(list, index, world))
  rescue => e
    log("changing the difficulty's command failed: #{e.class}: #{e.message}")
  end

  # Copies an event's commands with the call of the game's difficulty choice replaced: by
  # the world's difficulty and the enemies' rates worked out from it while no fight has values of
  # its own set, else by nothing.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] Where the call is.
  # @param world [Integer] The world's difficulty.
  # @return [Array<RPG::EventCommand>] The commands.
  def self.replaced_list(list, index, world)
    call = list[index]
    instead = if own_values?
                [command(108, ["The world sets the difficulty."], call.indent)]
              else
                [command(122, [VARIABLE, VARIABLE, 0, 0, world], call.indent), command(117, [APPLY_EVENT], call.indent)]
              end
    list[0...index] + instead + list[(index + 1)..-1]
  end

  # Makes an event command.
  #
  # @param code [Integer] Its code.
  # @param parameters [Array] Its parameters.
  # @param indent [Integer] Its indent.
  # @return [RPG::EventCommand] The command.
  def self.command(code, parameters, indent)
    RPG::EventCommand.new(code, indent, parameters)
  end
end

# What this script takes part in of the world, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::DIFFICULTY_FIELD) { |_peer, message| MGQ_MpWorldDifficulty.pushed(message) }
rescue => e
  MGQ_MpWorldDifficulty.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # After the map's update, whether the game plays on the world's difficulty.
  MGQ_MpHooks.after(Game_Map, :update, "world_difficulty") { MGQ_MpWorldDifficulty.tick }

  # Before an event command runs, the game's own difficulty choice and change follow the world.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "world_difficulty") { MGQ_MpWorldDifficulty.before_command(self) }

  # A loaded save or a new game bring their own difficulty. Not after extract_save_contents, which a
  # duel's end calls too to put the game back.
  MGQ_MpHooks.after(DataManager.singleton_class, :load_game_without_rescue, "world_difficulty") { |_index| MGQ_MpWorldDifficulty.loaded(:load) }
  MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "world_difficulty") { MGQ_MpWorldDifficulty.loaded(:new_game) }
rescue => e
  MGQ_MpWorldDifficulty.log("hooks FAILED: #{e.class}: #{e.message}")
end
