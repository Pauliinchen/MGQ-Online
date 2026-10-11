#----------------------------------------------------------------
#  world_opening.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Left the random encounters to world_catchup.rbx, which moves every value of the player's own that the story sets on to the story's place
#                            - Turned random encounters on again as the world's story is laid over, where it is past the talk that turns them on and the map does not turn them off itself
#                            - Created
#
#----------------------------------------------------------------

# A new game's opening in a Raid World whose story is past it. The game's start map runs one event
# by itself that sets the new game up (the story's progress back to 0, the starting switches, the
# difficulty) and then plays the opening scene, which ends in Luka's house. Played after the world's
# story was laid over the new game, it put the story back to its start and told the opening to
# everyone on the map whose story matched the world's.
#
# Here, once the world's story came and is past the start, that event's commands run in an
# interpreter of their own, which leaves out the scene (messages, pictures, waits, sounds, routes)
# and keeps the game's own transfer to where it ends; the world's story is laid over afterwards. A
# world whose story is still at the start plays the opening as the game has it.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldOpening
  # The commands of the opening's scene that are left out: messages and choices, move routes and
  # the waits for them, animations and balloons, the follower gathering, the screen's fades, tints,
  # flashes and shakes, the map's scroll, waits, pictures and weather, the music and sounds, movies,
  # battles, shops and name inputs, and the menu, save, game over and title calls.
  SKIPPED_CODES = [101, 102, 103, 104, 105, 204, 205, 210, 212, 213, 217, 221, 222, 223, 224, 225,
                   230, 231, 232, 233, 234, 235, 236, 241, 242, 243, 244, 245, 246, 249, 250, 251,
                   261, 301, 302, 303, 351, 352, 353, 354]

  # The trigger of an event that runs by itself.
  AUTORUN = 3

  @state = nil

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "world opening"

  # Notes a new game, whose opening waits for the world's story to tell whether it plays.
  def self.new_game
    forget
    @state = :new
  end

  # Forgets the opening, as a loaded save brings a game past it.
  def self.forget
    @state = nil
    @interpreter = nil
  end

  # Decides what the world's story waiting to be laid over the player's does: wait while the
  # opening's setup runs, which starts here when the world's story is past the start; note that it
  # ran, so the story it set up is where the player's own changes start; else nothing. Called by
  # world_story.rbx before it lays the world's story over the player's.
  #
  # @param world [Hash] The world's counters, see MGQ_MpWorldStory.counters_of.
  # @return [Symbol, nil] :wait while the world's story waits, :opened right after the setup ran,
  #   nil for nothing to do.
  def self.before_take(world)
    case @state
    when :new then start_or_play(world)
    when :running then :wait
    when :done
      @state = nil
      :opened
    end
  rescue => e
    give_up("deciding on the opening failed: #{e.class}: #{e.message}")
  end

  # Starts the opening's setup when the world's story is past the start, else leaves the opening to
  # the game. Waits while another screen lies over the map.
  #
  # @param world [Hash] The world's counters.
  # @return [Symbol, nil] :wait while the setup runs or waits for the map, nil when the game plays it.
  def self.start_or_play(world)
    if world["p"].to_i <= 0
      @state = nil
      log("the world's story is at its start: the new game plays the opening")
      return nil
    end
    event = opening_event
    unless event
      @state = nil
      log("the world's story is past the opening, but no opening runs here (map #{$game_map.map_id}): nothing to leave out")
      return nil
    end
    return :wait unless SceneManager.scene_is?(Scene_Map)

    start(event, world)
    :wait
  end

  # Finds the event that sets a new game up on the game's start map: the one there that runs by
  # itself.
  #
  # @return [Game_Event, nil] The event, nil off the start map or without one.
  def self.opening_event
    return nil unless $game_map.map_id == $data_system.start_map_id

    $game_map.events.keys.sort.map { |id| $game_map.events[id] }.find { |event| event.trigger == AUTORUN && event.list }
  end

  # Runs the opening's setup in an interpreter of its own, from the next map update on, until it
  # ended, its transfer to where the opening ends included.
  #
  # @param event [Game_Event] The opening's event.
  # @param world [Hash] The world's counters.
  def self.start(event, world)
    @interpreter = Game_MpOpeningInterpreter.new
    @interpreter.setup(event.list, event.id)
    @state = :running
    log("a new game in a world whose story is past the opening (progress #{world['p']}): running event #{event.id}'s setup on map #{$game_map.map_id} without its scene")
  end

  # Reports whether the map's main event must not start the opening's event, which runs here.
  #
  # @param event [Game_Event] The event about to start.
  # @return [Boolean] Whether it must not.
  def self.holds?(event)
    return false unless @state == :running && event.trigger == AUTORUN && $game_map.map_id == $data_system.start_map_id

    log_once([:held, event.id], "kept event #{event.id} on map #{$game_map.map_id} from starting: its setup runs without its scene")
    true
  rescue => e
    give_up("holding the opening's event failed: #{e.class}: #{e.message}")
    false
  end

  # Runs the opening's setup on, which is done once its commands ended. Called after the map's
  # update.
  def self.tick
    return unless @state == :running

    @interpreter.update
    return if @interpreter.running?

    @interpreter = nil
    @state = :done
    log("ran the opening's setup: the player is on map #{$game_map.map_id} #{$game_player.x},#{$game_player.y}")
  rescue => e
    give_up("running the opening's setup failed: #{e.class}: #{e.message}")
  end

  # Gives up on leaving the opening out after a failure: the game plays it as it has it.
  #
  # @param message [String] What failed, for the log.
  # @return [nil] Nothing to do.
  def self.give_up(message)
    log("#{message}; the game plays the opening as it has it")
    forget
    nil
  end
end

# An interpreter that runs an event's commands without its scene, see
# MGQ_MpWorldOpening::SKIPPED_CODES; the common events it calls run the same way.
class Game_MpOpeningInterpreter < Game_Interpreter
  # Runs the command at the interpreter's place, unless it belongs to the scene.
  def execute_command
    command = @list[@index]
    return super unless command
    return if MGQ_MpWorldOpening::SKIPPED_CODES.include?(command.code)

    super
  end

  # Calls a common event, in an interpreter that leaves its scene out too.
  def command_117
    common_event = $data_common_events[@params[0]]
    return unless common_event

    child = self.class.new(@depth + 1)
    child.setup(common_event.list, same_map? ? @event_id : 0)
    child.run
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # After the map's update, the opening's setup runs on.
  MGQ_MpHooks.after(Game_Map, :update, "world_opening") { MGQ_MpWorldOpening.tick }

  # A new game brings the opening, a loaded save a game past it.
  MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "world_opening") { MGQ_MpWorldOpening.new_game }
  MGQ_MpHooks.after(DataManager.singleton_class, :load_game_without_rescue, "world_opening") { |_index| MGQ_MpWorldOpening.forget }
rescue => e
  MGQ_MpWorldOpening.log("hooks FAILED: #{e.class}: #{e.message}")
end
