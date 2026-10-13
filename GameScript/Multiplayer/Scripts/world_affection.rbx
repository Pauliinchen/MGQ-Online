#----------------------------------------------------------------
#  world_affection.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Created
#
#----------------------------------------------------------------

# A Raid World's affection: each companion's affection is the highest any player of the world
# reached. The world's story carries it in a list of its own, which each game raises its
# affection to as it takes the story, and each write of the player's story carries theirs.
#
# Affection stays out of the story's variables (MGQ_MpStoryState.personal_variable?) because the
# game keeps it in its system save, and a plain story value would lose one of two players' gains.
module MGQ_MpWorldAffection
  # The list of the story's text that holds the affection, as "companion:affection" entries.
  LIST = "a"

  # The variable before the first companion's affection; companion n's is BASE + n.
  BASE = defined?(NWConst::Var::ACTOR_REL_BASE) ? NWConst::Var::ACTOR_REL_BASE : 3000

  # The companions whose affection the game keeps for every save, from 1 up to below this.
  LIMIT = 1000

  # Frames between two looks whether the player's affection passed the world's.
  CHECK_FRAMES = 120

  # Frames after a write the player's affection asked for before it asks again.
  WRITE_FRAMES = 600

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "world affection"

  # Map frames counted by tick.
  @clock = 0

  # The frame of the last look whether the player's affection passed the world's.
  @checked = 0

  # The frame the player's affection last asked for a write, nil when it has not since the world
  # opened.
  @asked = nil

  # The world's affection by companion id.
  @world = {}

  # The id of the world whose affection @world holds.
  @world_id = nil

  # Lists the companions whose affection the world shares: each companion's main persona, as the
  # game keeps a persona's affection with it.
  #
  # @return [Array<Integer>] Their ids.
  def self.ids
    @ids ||= (1...LIMIT).select { |id| main?(id) }
  end

  # Reports whether an actor is a companion's main persona.
  #
  # @param id [Integer] The actor.
  # @return [Boolean] Whether it is.
  def self.main?(id)
    actor = $data_actors[id]
    actor && !(actor.respond_to?(:persona_kind) && actor.persona_kind == :sub) ? true : false
  end

  # Reads the player's affection of a companion, as the game reads it.
  #
  # @param id [Integer] The companion.
  # @return [Integer] The affection.
  def self.own(id)
    $game_variables[BASE + id].to_i
  end

  # Reads the affection list of a story's text.
  #
  # @param list [String, nil] The list.
  # @return [Hash{Integer => Integer}] Each companion's affection.
  def self.parse(list)
    values = {}
    list.to_s.split(",").each do |entry|
      id, value = entry.split(":", 2).map(&:to_i)
      values[id] = value if id > 0 && id < LIMIT && value > 0
    end
    values
  end

  # Forgets the world's affection once another world opened.
  def self.note_world
    id = MGQ_MpWorldStory.world_id
    return if id == @world_id

    @world_id = id
    @world = {}
    @asked = nil
  end

  # Adds the player's affection to the lists of a story they write: each companion's highest of
  # theirs and the world's.
  #
  # @param lists [Hash{String => String}] The story's lists, see MGQ_MpStoryState.story_lists.
  # @return [Hash{String => String}] The lists with LIST.
  def self.add(lists)
    note_world
    values = {}
    ids.each do |id|
      value = [own(id), @world[id].to_i].max
      values[id] = value if value > 0
    end
    lists[LIST] = values.map { |id, value| "#{id}:#{value}" }.join(",")
    @world = values
    lists
  rescue => e
    log_once(:add, "writing the affection failed: #{e.class}: #{e.message}")
    lists
  end

  # Raises the player's affection to the world's, from a story's text the world's story came with,
  # whatever the player's part.
  #
  # A story without LIST, as an earlier version writes it, leaves the player's affection as it is,
  # and their next write puts it back.
  #
  # @param text [String] The world's story, packed.
  def self.take(text)
    note_world
    world = parse(MGQ_MpStoryState.unpack(text)[LIST])
    raised = []
    world.each do |id, value|
      before = own(id)
      next unless main?(id) && value > before

      $game_variables[BASE + id] = value
      raised << "#{MGQ_MpLog.named($data_actors, id)} #{before} -> #{value}"
    end
    @world = world
    log("raised the affection of #{raised.size} companion(s) to the world's: #{raised.first(10).join(', ')}#{raised.size > 10 ? ', ...' : ''}") unless raised.empty?
  rescue => e
    log_once(:take, "taking the world's affection failed: #{e.class}: #{e.message}")
  end

  # Looks every CHECK_FRAMES whether the player's affection passed the world's, as a gift or a
  # battle raised it, and asks for a write of their story then.
  def self.tick
    @clock += 1
    return if @clock - @checked < CHECK_FRAMES

    @checked = @clock
    return unless MGQ_MpWorldStory.active?
    return if @asked && @clock - @asked < WRITE_FRAMES

    note_world
    rose = ids.select { |id| own(id) > @world[id].to_i }
    return if rose.empty? || !MGQ_MpWorldStory.request_post

    @asked = @clock
    log("the player's affection passed the world's for #{rose.size} companion(s), writing it: " \
        "#{rose.first(10).map { |id| "#{MGQ_MpLog.named($data_actors, id)} #{@world[id].to_i} -> #{own(id)}" }.join(', ')}")
  rescue => e
    log_once(:tick, "looking at the affection failed: #{e.class}: #{e.message}")
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  MGQ_MpHooks.after(Game_Map, :update, "world_affection") { MGQ_MpWorldAffection.tick }
rescue => e
  MGQ_MpWorldAffection.log("hooks FAILED: #{e.class}: #{e.message}")
end
