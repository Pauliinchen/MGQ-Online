#----------------------------------------------------------------
#  story_ids.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# The story's ids as the DLL hands them from its one table (StoryIds in MGQOnline.Game, topic
# story.ids): the variables and switches the story's progress, sides and routes are told by, the
# steps of the parts and the Great Decision, the routes' events and places, and the variables the
# game uses as a place. The scripts read every story id here and write none of their own.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpStoryIds
  # The DLL's topic of the table.
  TOPIC = "story.ids"

  # The ids that are one whole number each, 0 while the DLL does not answer, which no switch,
  # variable or common event is.
  NUMBERS = %w(main_progress game_over_return playthrough decision_progress part_two part_three before_decision great_decision
               decision_event final_reset_event reset_event reaper_event)

  # The ids that are a list each, empty while the DLL does not answer.
  LISTS = %w(story_switches side_switches routes route_variables clear_switches markers castle_bosses area_progress return_events
             return_points decision_maps decision_place chaos_start place_variables)

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "story ids"

  # The table the DLL handed, see table.
  @table = nil

  # Reads the table once the DLL answers, and nothing before.
  #
  # @return [Hash] The ids by their names; empty while the DLL does not answer.
  def self.table
    return @table if @table

    answer = MGQ_Multiplayer::Bridge.open? ? MGQ_Multiplayer::Bridge.call(TOPIC) : nil
    unless answer.is_a?(Hash)
      log_once(:none, "the DLL hands no story ids yet")
      return {}
    end

    answer.each_value { |value| value.freeze }
    @table = answer.freeze
  rescue => e
    log_once(:table, "reading the story ids failed: #{e.class}: #{e.message}")
    {}
  end

  # One reader per id, such as MGQ_MpStoryIds.main_progress or MGQ_MpStoryIds.route_variables.
  NUMBERS.each { |name| define_singleton_method(name) { table[name] || 0 } }
  LISTS.each { |name| define_singleton_method(name) { table[name] || [] } }

  # The switch that tells the player took Alice along.
  #
  # @return [Integer] The switch, 0 while the DLL does not answer.
  def self.alice_chosen
    side_switches[0] || 0
  end

  # The switch that tells the player took Ilias along.
  #
  # @return [Integer] The switch, 0 while the DLL does not answer.
  def self.ilias_chosen
    side_switches[1] || 0
  end

  # Reports whether the game uses a variable as a place, which stays each player's own.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it does.
  def self.place?(id)
    place_variables.include?(id)
  end
end
