#----------------------------------------------------------------
#  world_difficulty.rbx
#
#  Changelog:
#      Paulinchen  2026-11-12: Worked the enemies' rates out through the game's own call of their common event, which world mods hook
#                            - Logged each boss battle's enemies with their max HP, ATK, DEF and actions per turn once its start ran
#      Paulinchen  2026-11-07: Asked the rules in C# whether a fight has values of its own and whether the game may be put on the world's difficulty
#      Paulinchen  2026-10-23: Worked the enemies' rates out as the multiplayer's own writes, which never go to the relay as the player's
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# A Raid World's difficulty, which its creator sets for every player: each game in the world plays
# on it from entering, loading a save and a new game on, and from the moment the creator or an
# admin changes it. The game's own choice of the difficulty sets the world's instead.
#
# Fights with values of their own keep the difficulty they replace to put it back afterwards, so
# nothing here writes the difficulty while one runs; the rules in C# (RaidDifficulty) tell when.
module MGQ_MpWorldDifficulty
  # The game's difficulty, from -2 (VERY EASY) to 4 (PARADOX).
  VARIABLE = defined?(NWConst::Var::CURRENT_DIFFICULTY) ? NWConst::Var::CURRENT_DIFFICULTY : 902

  # The common event that works the enemies' rates out from the difficulty.
  APPLY_EVENT = 112

  # The common event of the game's own difficulty choice, which the start of a new game, the choice
  # after a defeat and the Reaper's difficulty change in Hades (common event 146) call.
  CHOICE_EVENT = 110

  # The topic that names the switches the difficulty's rules read.
  READS_TOPIC = "difficulty.reads"

  # The topic that tells whether a fight has values of its own set and whether the game may be put
  # on the world's difficulty now.
  STATE_TOPIC = "difficulty.state"

  # Frames between two looks whether the game plays on the world's difficulty.
  CHECK_FRAMES = 30

  # How often the call of the enemy rates' common event is stepped at most: it ends after three
  # steps, four when the common event calls the Labyrinth's common event 900.
  MAX_STEPS = 5

  # The variables the enemy rates' common event writes that a boss battle's line shows: the rates
  # of max HP, ATK, DEF and AGI (41-44), of the states (45) and variable 48.
  RATE_VARIABLES = [41, 42, 43, 44, 45, 48]

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "world difficulty"

  # Frames since the last look whether the game plays on the world's difficulty.
  @frames = 0

  # Whether the battle set up last still waits for its line of the enemies' numbers.
  @battle_unlogged = false

  # Tells the difficulty the open Raid World sets for every player.
  #
  # @return [Integer, nil] The difficulty; nil outside Raid Worlds and in one that sets none.
  def self.value
    MGQ_MpWorld.difficulty
  end

  # Asks the rules in C# (topic difficulty.state) of the game as it stands, in a Raid World with a
  # difficulty.
  #
  # @return [Hash] "own_values", whether a fight has values of its own set, which the world's
  #   difficulty never writes over; "due", whether the game plays on another difficulty than the
  #   world's and may be put on it now.
  def self.state
    @reads ||= MGQ_Multiplayer::Bridge.call!(READS_TOPIC)
    MGQ_Multiplayer::Bridge.call!(STATE_TOPIC, "world" => value, "game" => $game_variables[VARIABLE].to_i, "s" => @reads.map { |id| $game_switches[id] ? true : false },
                                               "battle" => $game_party.in_battle ? true : false, "quiet" => MGQ_MpOverworldSync.map_quiet? ? true : false)
  end

  # Tells whether the game has values of its own set for a fight, as the rules in C# tell.
  #
  # @return [Boolean] Whether it has.
  def self.own_values?
    state["own_values"]
  end

  # Tells whether the game may be put on the world's difficulty now, as the rules in C# tell.
  #
  # @return [Boolean] Whether it may; never outside Raid Worlds and in one that sets none.
  def self.due?
    !value.nil? && state["due"]
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

  # Calls the game's own common event that works the enemies' rates out from the difficulty, as its
  # own difficulty choice does right after setting it; what it writes is the multiplayer's own
  # (MGQ_MpStoryKeys.applying), as every game of the world works its rates out itself.
  #
  # The call goes through the game's interpreter, since a world mod that changes the rates
  # (Difficulty Overhaul) hooks that call and every game of the world must end on the same rates.
  def self.work_out_rates
    return unless $data_common_events && $data_common_events[APPLY_EVENT]

    interpreter = Game_Interpreter.new
    interpreter.setup([command(117, [APPLY_EVENT], 0)])
    steps = 0
    applying do
      while interpreter.running? && steps < MAX_STEPS
        interpreter.update
        steps += 1
      end
    end
  end

  # Runs a block as the multiplayer's own writes, see MGQ_MpStoryKeys.applying.
  #
  # @yield The writes.
  def self.applying
    defined?(MGQ_MpStoryKeys) ? MGQ_MpStoryKeys.applying { yield } : yield
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

  # Notes that a battle was set up, whose line of the enemies' numbers is still to come.
  def self.battle_set_up
    @battle_unlogged = true
  end

  # Logs the enemies' numbers of a boss battle, once per battle as its first command phase opens,
  # after the battle's start ran common event 112 again: the troop, this game's part in the
  # battle, the enemy rates and each enemy's max HP, ATK, DEF and actions per turn.
  #
  # The actions per turn are the game's least and most, never a draw, which would use up the
  # battle's random numbers.
  def self.log_boss_battle
    return unless @battle_unlogged

    @battle_unlogged = false
    troop = MGQ_MpGame.get($game_troop, :troop_id)
    return unless defined?(MGQ_MpRaidBosses) && MGQ_MpRaidBosses.battle?(troop)

    enemies = $game_troop.members.map do |enemy|
      "enemy #{enemy.enemy_id} HP #{enemy.mhp} ATK #{enemy.atk} DEF #{enemy.def} actions #{enemy.min_action_times}-#{enemy.max_action_times}"
    end
    log("boss battle of troop #{troop} (#{battle_role}): rates #{RATE_VARIABLES.join(',')} = #{RATE_VARIABLES.map { |id| $game_variables[id] }.join('/')}; #{enemies.join('; ')}")
  rescue => e
    log("logging the boss battle's enemies failed: #{e.class}: #{e.message}")
  end

  # Tells this game's part in the battle running.
  #
  # @return [String] "served" for a battle the battle server hosts, "host", "guest" or "alone".
  def self.battle_role
    return "alone" unless defined?(MGQ_MpBattlesSync)
    return "served" if MGQ_MpBattlesSync.served?
    return "host" if MGQ_MpBattlesSync.host?

    MGQ_MpBattlesSync.guest? ? "guest" : "alone"
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
    apply("the game's own difficulty choice was called")
    MGQ_MpGame.set(interpreter, :list, replaced_list(list, index))
  rescue => e
    log("changing the difficulty's command failed: #{e.class}: #{e.message}")
  end

  # Copies an event's commands with the call of the game's difficulty choice replaced by a comment,
  # as the world's difficulty is set already.
  #
  # The interpreters that run the opening and a story replay call common events without the game's
  # call, which world mods hook, so the call is never left to them.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] Where the call is.
  # @return [Array<RPG::EventCommand>] The commands.
  def self.replaced_list(list, index)
    list[0...index] + [command(108, ["The world sets the difficulty."], list[index].indent)] + list[(index + 1)..-1]
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

  # A boss battle's enemies are logged as its first command phase opens, which every game of a
  # live battle reaches, the guest too, whose battle start the host's stream replaces.
  MGQ_MpHooks.after(BattleManager.singleton_class, :setup, "world_difficulty") { |*_args| MGQ_MpWorldDifficulty.battle_set_up }
  MGQ_MpHooks.after(Scene_Battle, :start_party_command_selection, "world_difficulty") { MGQ_MpWorldDifficulty.log_boss_battle }
rescue => e
  MGQ_MpWorldDifficulty.log("hooks FAILED: #{e.class}: #{e.message}")
end
