#----------------------------------------------------------------
#  world_catchup.rbx
#
#  Changelog:
#      Paulinchen  2026-10-09: Read and wrote the story and granted its skills and companions through the state model of story_state.rbx instead of coop_story.rbx
#                            - Gave a key item whose event is only there to play up to its amount once the world's story is past it, and played the orbs' event for a player the catch-up gave every orb
#                            - Held the story from a save's load until the world's story came while the save notes the player behind in their part
#                            - Kept a shared companion away whose join the player's story passed
#                            - Moved a player behind in the world's part on to the world's story instead of a route it finished
#                            - Created
#
#----------------------------------------------------------------

# A Raid World's catch-up, on the story of world_story.rbx and the tables of world_catchup_data.rbx.
#
# A player whose story is in an earlier part than the world's is behind (MGQ_MpWorldStory.mode
# :behind): they get the checkpoint the relay keeps of their part, the world as it was right before
# that part's ending, laid over their own values, and play no story while behind (coop_events.rbx
# asks holds_story?). Once the highest base level of their characters reaches their part's gate,
# they move straight into the next part: its checkpoint while the world is past it, else the
# world's own story. A player whom another mod caps below the gate is moved on once at that cap.
#
# What the story gives goes by its place in the story, never by what another player holds. A
# row of the tables counts once the player's story is past it (passed?), and once per save, which
# keeps what it did in its notes (ledger). A row the player's own game played gives nothing here,
# since the game gave it; a row a story laid over theirs carried them past gives its skills and
# items, takes the companions a first playthrough loses for good, and lets its companions join,
# as long as its marks tell that its event ran: one only there to play stays the player's own.
# The world's key items and the chests that hold them are the whole world's: once the world's story
# is past one, every player gets it, whatever their part, and a key item whose event is only there
# to play up to its amount. A player who then holds every orb of Part 2 plays the event that moves
# the story on, which only an orb's own event calls.
#
# A companion joins once the player's story is past the join and their highest base level reaches
# the join's gate, and comes at least at that level unless it is a first join at the companion's
# start level. A story event that would hand a companion out before then waits for the gate
# instead. With the world's companion sharing on, every companion a player of the world got joins
# the others on reaching its gate: the story's companions, and with battle recruits shared too
# every companion, at its start level.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldCatchup
  # The tables this catch-up follows.
  DATA = MGQ_MpWorldCatchupData

  # Frames between two looks at the player's story, half a second.
  CHECK_FRAMES = 30

  # Frames between two reads of the DLL's state while a request runs, a quarter of a second.
  STATE_FRAMES = 15

  # Frames before a request that failed is tried again, thirty seconds.
  RETRY_FRAMES = 1800

  # Frames before a request the DLL did not start is tried again, a second.
  START_FRAMES = 60

  # Frames between two additions to the world's shared companions, ten seconds, so a few new
  # companions go in one write: the relay is on Cloudflare's free plan.
  SHARE_FRAMES = 600

  # Shared companions one addition names at most, as the relay takes them.
  SHARE_BATCH = 500

  # Bytes the DLL may write a checkpoint into at first; a larger one asks for a larger buffer.
  STATE_SIZE = 4096

  # Frames a notice of the catch-up shows, five seconds.
  NOTICE_FRAMES = 300

  # Luka, who never joins nor leaves.
  HERO = 1

  # The variable that counts the playthroughs, at 0 on the first, which alone loses companions for
  # good.
  PLAYTHROUGH = 912

  # Part 2's orbs the game keeps as items, all of which ORB_EVENT asks for before it moves the story
  # on.
  ORBS = [537, 538, 540, 541, 542]

  # The common event that moves the story on to the Holy Wings Shrine once the player holds every
  # orb, which each orb's event calls only for the player who plays it.
  ORB_EVENT = 330

  # The main story's progress ORB_EVENT sets.
  ORBS_GATHERED = 32

  # Where each part stands in the story's order; the routes stand side by side.
  RANKS = { "1" => 0, "2" => 1, "3" => 2, "ad" => 3, "mr" => 3, "chaos" => 3 }

  # The parts before the Great Decision, whose sides the player chose themselves.
  SIDED_PARTS = %w(1 2 3)

  # The rule of a join whose gate is the companion's start level, which a companion new to the
  # player has anyway.
  START_RULE = :start

  # The field of $game_system the save keeps the notes in, see ledger.
  LEDGER = :@mgq_mp_catchup

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "catch-up"

  # Forgets what this session knew of the world: the requests, the world's story and the companions
  # noted. The notes in the save stay.
  def self.forget
    @world_id = nil
    @want = nil
    @fetching = nil
    @fetch_at = 0
    @ready = nil
    @joins_world = false
    @world_told = nil
    @known_roster = nil
    @share_queue = []
    @adding = nil
    @share_at = 0
    @orbs_due = false
    @orbs_played = false
    @clock ||= 0
    @checked = @clock
    @state_read = @clock
  end

  forget

  # Reports whether the catch-up applies: a Raid World's story is followed, see
  # MGQ_MpWorldStory.active?.
  #
  # @return [Boolean] Whether it does.
  def self.active?
    MGQ_MpWorldStory.active?
  end

  # Reports whether the player's story events are held: their story is behind the world's, or
  # their save noted them behind in their part while the world's story has not come since the save
  # loaded or the world opened, so a part's ending held on the map never starts before the relay
  # answers. Called by coop_events.rbx.
  #
  # @return [Boolean] Whether they are.
  def self.holds_story?
    return false unless active?

    mode = MGQ_MpWorldStory.mode
    mode == :behind || (mode.nil? && noted_behind?)
  rescue
    false
  end

  # Reports whether the save notes the player behind in the part their story is in: they took its
  # checkpoint, or keep their own story there for want of one.
  #
  # @return [Boolean] Whether it does.
  def self.noted_behind?
    noted = ledger["checkpoint"]
    !noted.nil? && noted == own_part
  end

  # Reports whether a player behind stays behind though the world's story is in their part again,
  # as after the world's return from a route to the Great Decision: their level has not reached
  # their part's gate yet. Called by world_story.rbx.
  #
  # @return [Boolean] Whether they do.
  def self.keeps_behind?
    holds_story? && !@joins_world && !gate_reached?
  rescue
    false
  end

  # Reports whether the player moves into the world's own story, which world_story.rbx then lays
  # over theirs whatever its part.
  #
  # @return [Boolean] Whether they do.
  def self.joins_world?
    @joins_world ? true : false
  end

  # Tells the player why their story event did not start.
  #
  # @return [String] The notice.
  def self.refusal_text
    "Reach level #{gate_of(own_part)} to continue the story."
  end

  # Tells the player they are behind the world's story.
  #
  # @param own [Hash] The player's counters, see MGQ_MpWorldStory.local_counters.
  # @return [String] The notice.
  def self.behind_text(own)
    part = MGQ_MpWorldStory.part_of(own)
    "The world's story is further than yours. You see the world as it was before the end of #{part_name(part)}; reach level #{gate_of(part)} to move on."
  end

  # Follows the catch-up for one frame: the relay's answers, the checkpoint and the orbs' event that
  # wait, then every CHECK_FRAMES while the player is free the story's rows, the level gate, the
  # shared companions and the orbs. Called after the map's update.
  def self.tick
    @clock += 1
    return close unless active?

    note_world
    read_requests if (@fetching || @adding) && @clock - @state_read >= STATE_FRAMES
    start_fetch if @want && !@fetching && !@ready && @clock >= @fetch_at
    play_orb_event if @orbs_due
    return if @clock - @checked < CHECK_FRAMES || !MGQ_MpWorldStory.quiet?

    @checked = @clock
    # The personal half of a return to the Great Decision plays first, since it clears the route.
    return (MGQ_MpWorldStory.queued? ? nil : take_checkpoint) if @ready
    return if MGQ_MpWorldStory.mode.nil?

    looking do
      review(story_now, false)
      move_on if MGQ_MpWorldStory.mode == :behind && !@want && !@joins_world && gate_reached?
      note_roster
      check_orbs
    end
    send_shared
  rescue => e
    log_once(:tick, "following the catch-up failed: #{e.class}: #{e.message}")
  end

  # Forgets the world's catch-up once the world closed or is no Raid World.
  def self.close
    return unless @world_id

    log("the Raid World closed: forgetting its catch-up")
    forget
  end

  # Notes the open world, forgetting what this session knew of another.
  def self.note_world
    id = MGQ_MpWorldStory.world_id
    return if id == @world_id

    forget
    @world_id = id
  end

  # Forgets what this session knew, as a loaded save or a new game bring their own story and notes.
  def self.loaded
    id = @world_id
    forget
    @world_id = id
  end

  # The story the game keeps now, read in place.
  #
  # @return [Array] The switches, variables and self switches, the game's own data.
  def self.story_now
    [MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables), MGQ_MpStoryState.data_of($game_self_switches)]
  end

  # The notes the save keeps: the rows done ("done", a row's key to true, or to "c" or "o" for a
  # join waiting for its gate that a story carried the player past or that their own event held
  # back), the companions their own event held back whose join the story has not passed yet
  # ("held"), the part whose checkpoint the player got ("checkpoint") and the side they chose
  # before the Great Decision ("side"). Notes of another world start anew.
  #
  # @return [Hash] The notes.
  def self.ledger
    notes = $game_system.instance_variable_get(LEDGER)
    id = MGQ_MpWorldStory.world_id
    unless notes.is_a?(Hash) && notes["world"] == id && notes["done"].is_a?(Hash)
      notes = { "world" => id, "done" => {}, "held" => {}, "checkpoint" => nil, "side" => nil }
      $game_system.instance_variable_set(LEDGER, notes)
    end
    notes["held"] ||= {}
    notes
  end

  # The part the player's story is in.
  #
  # @return [String] See MGQ_MpWorldStory.part_of.
  def self.own_part
    part_of(story_now)
  end

  # The part a story is in.
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [String] See MGQ_MpWorldStory.part_of.
  def self.part_of(story)
    MGQ_MpWorldStory.part_of(MGQ_MpWorldStory.local_counters(story))
  end

  # Finds a part of the tables.
  #
  # @param id [String] The part, as the relay names it.
  # @return [MGQ_MpWorldCatchupData::Part, nil] The part, nil for none.
  def self.part(id)
    DATA::PARTS.find { |entry| entry.id == id }
  end

  # The level that moves a player on from a part.
  #
  # @param id [String] The part.
  # @return [Integer] Its gate.
  def self.gate_of(id)
    entry = part(id)
    entry ? entry.gate : DATA::PARTS.last.gate
  end

  # What the notices call a part.
  #
  # @param id [String] The part.
  # @return [String] Its name.
  def self.part_name(id)
    entry = part(id)
    entry ? entry.name : "Part #{id}"
  end

  # Takes the player behind the world's story, in an earlier part (see world_story.rbx): their
  # part's checkpoint is fetched unless their save holds it already, and the world's story is kept
  # for its key items and chests. A player on a route the world never took moves on into the
  # world's story at once. Called by world_story.rbx.
  #
  # @param world [Hash] The world's counters, see MGQ_MpWorldStory.counters_of.
  # @param own [Hash] The player's counters.
  # @param told [Array] The world's story: switches, variables and self switches.
  def self.behind(world, own, told)
    @world_told = told
    part = MGQ_MpWorldStory.part_of(own)
    return if @want || @joins_world
    # A route the world never took has no checkpoint, and the world's route goes on without it.
    return join_world unless world_parts(world).include?(part)
    return if ledger["checkpoint"] == part

    if world["checkpoints"].to_a.include?(part)
      want(part, "the player's story is behind the world's, in #{part_name(part)}")
    else
      log_once([:no_checkpoint, part], "the world keeps no checkpoint of #{part_name(part)}: the player keeps their own story there until their level moves them on")
    end
  end

  # Notes the world's story laid over the player's, for the key items and chests it gave; the save
  # no longer notes the player behind, see noted_behind?. Called by world_story.rbx.
  #
  # @param told [Array] The world's story.
  def self.world_told(told)
    @world_told = told
    ledger["checkpoint"] = nil if active?
  end

  # Asks for a part's checkpoint.
  #
  # @param part [String] The part.
  # @param reason [String] Why, for the log.
  def self.want(part, reason)
    @want = part
    @fetch_at = @clock
    log("#{reason}: fetching the checkpoint of #{part_name(part)}")
  end

  # Starts fetching the checkpoint asked for.
  def self.start_fetch
    unless Relay.fetch(MGQ_MpWorldStory.world_id, @want)
      @fetch_at = @clock + START_FRAMES
      return log_once([:fetch_start, @want], "the DLL did not start fetching the checkpoint of #{part_name(@want)}, trying again")
    end

    @fetching = @want
  end

  # Reads how the checkpoint fetch and the addition of shared companions stand.
  def self.read_requests
    @state_read = @clock
    read_checkpoint if @fetching
    read_shared if @adding
  end

  # Takes the checkpoint fetch once it ended: kept for the next quiet moment when done, else the
  # player moves on without it or tries again. A failed fetch may name no part, or the last one
  # fetched, as the DLL names it only once the relay answered.
  def self.read_checkpoint
    state = Relay.state
    return if state.empty? || state["state"] == "busy"
    return if state["state"] != "failed" && state["part"] != @fetching

    part = @fetching
    @fetching = nil
    case state["state"]
    when "done"
      @ready = { :part => part, :text => state[:payload].to_s, :wrev => state["wrev"].to_i }
      log("fetched the checkpoint of #{part_name(part)} (revision #{state['wrev']}, #{state[:payload].to_s.size} characters)")
    when "none"
      without_checkpoint(part, "the world keeps no checkpoint of #{part_name(part)} after all")
    else
      @fetch_at = @clock + RETRY_FRAMES
      log("fetching the checkpoint of #{part_name(part)} failed: #{state['error']}; trying again later")
    end
  end

  # Goes on without a part's checkpoint: a player in that part keeps their own story there, one
  # moving on to it moves on to the world's story.
  #
  # @param part [String] The part.
  # @param reason [String] Why, for the log.
  def self.without_checkpoint(part, reason)
    @want = nil
    if part == own_part
      ledger["checkpoint"] = part
      return log("#{reason}: the player keeps their own story there")
    end

    log("#{reason}: moving on to the world's story")
    join_world
  end

  # Lays the checkpoint fetched over the player's story, keeping their own values (see
  # MGQ_MpStoryState.mix): the world as it was right before that part's ending. Only a player still
  # behind takes it.
  def self.take_checkpoint
    ready = @ready
    @ready = nil
    @want = nil
    return log("dropped the checkpoint of #{part_name(ready[:part])}: the player is no longer behind") unless MGQ_MpWorldStory.mode == :behind

    local = MGQ_MpStoryState.raw_state
    own = MGQ_MpWorldStory.local_counters(local)
    told = read_story(ready[:text])
    return without_checkpoint(ready[:part], "the checkpoint of #{part_name(ready[:part])} holds no story this game can read") unless told

    applied = MGQ_MpStoryState.mix(told, local, MGQ_MpWorldStory.chest_list)
    MGQ_MpWorldStory.keep_unsent(applied, told, local)
    MGQ_MpWorldStory.keep_open_chests(applied, local)
    MGQ_MpStoryState.set_raw(*applied)
    ledger["checkpoint"] = ready[:part]
    after = MGQ_MpWorldStory.local_counters(applied)
    log("took the checkpoint of #{part_name(ready[:part])} (revision #{ready[:wrev]}): #{MGQ_MpWorldStory.counters_text(own)} -> #{MGQ_MpWorldStory.counters_text(after)}")
    carried(local)
    MGQ_MpWorldStory.followed(own, after)
  rescue => e
    @want = ready[:part] if ready && ledger["checkpoint"] != ready[:part]
    @fetch_at = @clock + RETRY_FRAMES
    log("taking the checkpoint failed: #{e.class}: #{e.message}; trying again later")
  end

  # Reads a story the relay keeps, packed.
  #
  # @param text [String] The story.
  # @return [Array, nil] The switches, variables and self switches, nil when this game cannot read
  #   it.
  def self.read_story(text)
    return nil if text.empty?

    MGQ_MpStoryState.decode_full(MGQ_MpStoryState.unpack(text))
  rescue => e
    log("reading a checkpoint failed: #{e.class}: #{e.message}")
    nil
  end

  # Follows a story laid over the player's: what their own game played before counts as theirs,
  # then what the story carried them past gives what it gives. Called by world_story.rbx and after
  # a checkpoint.
  #
  # @param before [Array] The player's story before: switches, variables and self switches.
  def self.carried(before)
    return unless active?

    looking do
      review(before, false)
      review(story_now, true)
    end
    return unless @joins_world

    @joins_world = false
    ledger["checkpoint"] = nil
    log("the player plays the world's story now")
  rescue => e
    log("following a story laid over the player's failed: #{e.class}: #{e.message}")
  end

  # Reports whether the player's highest base level reaches their part's gate, or the cap another
  # mod holds them at below it.
  #
  # @return [Boolean] Whether it does.
  def self.gate_reached?
    reached?(gate_of(own_part))
  end

  # Reports whether the player's highest base level among their characters reaches a level, or
  # whether that character is at the highest level the game lets them reach (Game_Actor#max_level,
  # which another mod may cap) below it, so a cap can never hold the player back.
  #
  # @param level [Integer] The level.
  # @return [Boolean] Whether it does.
  def self.reached?(level)
    view = roster_view
    return false unless view[:best]
    return true if view[:best] >= level

    cap = view[:cap]
    cap.is_a?(Integer) && cap < level && view[:best] >= cap
  rescue
    false
  end

  # Reports whether a companion is in the player's own roster, in any of their personas.
  #
  # @param id [Integer] The companion.
  # @return [Boolean] Whether they are.
  def self.in_roster?(id)
    roster_view[:ids][MGQ_MpStoryState.main_id(id)] ? true : false
  end

  # What the rows ask of the player's roster: its companions, and the highest base level among
  # them with that character's own highest level. Kept for one look at the rows, see looking, as
  # it copies the roster.
  #
  # @return [Hash] :ids (each companion's main persona to true), :best and :cap (nil without one).
  def self.roster_view
    return @roster_view if @roster_view

    ids = {}
    MGQ_MpStoryState.roster_ids.each { |id| ids[id] = true }
    best = MGQ_MpStoryState.roster.max_by { |actor| actor.base_level }
    view = { :ids => ids, :best => best && best.base_level, :cap => best && best.max_level(:base) }
    @looking ? @roster_view = view : view
  end

  # Runs a look at the rows with the roster read once, see roster_view.
  def self.looking
    outer = @looking
    @looking = true
    yield
  ensure
    @looking = outer
    @roster_view = nil unless outer
  end

  # Forgets the roster read for this look, as a companion joined or left.
  def self.roster_changed
    @roster_view = nil
  end

  # Moves the player on from their part, see the module: into the next part's checkpoint while the
  # world is past that part, else into the world's own story.
  def self.move_on
    world = MGQ_MpWorldStory.world
    return unless world

    from = own_part
    target = next_part(from, world)
    gate = gate_of(from)
    name = target == :world ? "the world's story" : part_name(target)
    log("level #{gate} reached in #{part_name(from)}: moving on to #{name}")
    notice(:gate, "Level #{gate} reached: catching up to #{name}.")
    return_from_route(from, world)
    target == :world ? join_world : want(target, "moving on from #{part_name(from)}")
  end

  # Moves the player into the world's own story, which world_story.rbx fetches and lays over
  # theirs whatever its part.
  def self.join_world
    @joins_world = true
    MGQ_MpWorldStory.refetch(:caught_up)
  end

  # Gives a player on a route the world finished the personal half of the world's return to the
  # Great Decision before they move on, see MGQ_MpWorldStory.returned.
  #
  # @param from [String] The player's part.
  # @param world [Hash] The world's counters.
  def self.return_from_route(from, world)
    return unless MGQ_MpWorldStory::ROUTES.include?(from) && world["done"].to_a.include?(from)

    MGQ_MpWorldStory.returned(MGQ_MpWorldStory.local_counters(story_now))
  end

  # Lists the world's parts in the order the world played them: Parts 1 to 3, the routes it
  # finished, and the route under way.
  #
  # @param world [Hash] The world's counters.
  # @return [Array<String>] The parts.
  def self.world_parts(world)
    parts = %w(1 2 3) + world["done"].to_a
    current = world["part"].to_s
    parts << current if MGQ_MpWorldStory::ROUTES.include?(current) && !parts.include?(current)
    parts
  end

  # Finds where a player moves on to from a part: the next part the world played that has a
  # checkpoint, or the world's own story once that is the world's part or none is left. A player in
  # the world's part, as after its return from a route to the Great Decision, goes to its story.
  #
  # @param from [String] The player's part.
  # @param world [Hash] The world's counters.
  # @return [String, Symbol] The part, or :world.
  def self.next_part(from, world)
    return :world if from == world["part"].to_s

    parts = world_parts(world)
    at = parts.index(from)
    return :world unless at

    parts[(at + 1)..-1].each do |candidate|
      return :world if candidate == world["part"].to_s
      return candidate if world["checkpoints"].to_a.include?(candidate)
    end
    :world
  end

  # Reports whether a mark holds in a story.
  #
  # @param mark [Array] [:s, switch], [:v, variable, at least] or [:ss, map, event, letter].
  # @param story [Array] The switches, variables and self switches.
  # @return [Boolean] Whether it holds.
  def self.mark_holds?(mark, story)
    case mark[0]
    when :s then story[0][mark[1]] ? true : false
    when :v
      value = story[1][mark[1]]
      value.is_a?(Numeric) && value >= mark[2]
    when :ss then story[2][[mark[1], mark[2], mark[3]]] ? true : false
    else false
    end
  end

  # Reports whether a mark is a choice's outcome, which only the player's own story holds.
  #
  # @param mark [Array] The mark.
  # @return [Boolean] Whether it is.
  def self.choice_mark?(mark)
    return false if mark[0] == :ss

    @choice_marks ||= {}
    key = mark[1] * 2 + (mark[0] == :s ? 0 : 1)
    known = @choice_marks[key]
    return known unless known.nil?

    @choice_marks[key] = defined?(MGQ_MpCoopChoices) && MGQ_MpCoopChoices.personal?(mark[0], mark[1]) ? true : false
  end

  # The side a row asks for in the player's story: before the Great Decision the side they chose
  # then, which the save notes, since the route sets it anew.
  #
  # @param row [Struct] The row.
  # @param own [Array] The player's story.
  # @return [Symbol, nil] :alice, :ilias or nil.
  def self.side_for(row, own)
    side = MGQ_MpStoryState.side_of(own[0])
    return side unless SIDED_PARTS.include?(row.part)

    @noted_side = ledger["side"] || false if @noted_side.nil?
    @noted_side ? @noted_side.to_sym : side
  end

  # Notes the side the player chose before the Great Decision, which the route sets anew.
  #
  # @param story [Array] The player's story.
  def self.note_side(story)
    side = MGQ_MpStoryState.side_of(story[0])
    return unless side && SIDED_PARTS.include?(story_part(story))

    ledger["side"] = @noted_side = side.to_s
  end

  # The part a story is in, kept for the look at the rows under way, see review.
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [String] See MGQ_MpWorldStory.part_of.
  def self.story_part(story)
    @story_parts ||= {}
    @story_parts[story.object_id] ||= part_of(story)
  end

  # Forgets what one look at the rows kept, as the stories it read change.
  def self.new_look
    @story_parts = {}
    @noted_side = nil
    @choice_marks = {}
  end

  # Reports whether a story is past a row: the row's part is the story's or an earlier one, and its
  # marks hold, so an optional event nobody played is never past; a route's rows also once the
  # route is finished, whose return clears its marks. Side content counts by its marks alone. The
  # row's side and the choices' outcomes among its marks are the player's own, always read from
  # their story.
  #
  # @param row [Struct] A row of the tables, with part, side and marks.
  # @param story [Array] The story: switches, variables and self switches.
  # @param own [Array] The player's own story, the same unless the story is the world's.
  # @return [Boolean] Whether it is.
  def self.passed?(row, story, own = story)
    finished = false
    unless row.part.nil?
      current = story_part(story)
      rank = RANKS[row.part]
      finished = rank == RANKS["ad"] && cleared?(row.part, story)
      return false unless finished || rank < RANKS[current].to_i || current == row.part
    end
    return false if row.side && row.side != side_for(row, own)
    return false unless row.marks.all? { |mark| !choice_mark?(mark) || mark_holds?(mark, own) }
    return true if finished

    !row.marks.empty? && row.marks.all? { |mark| mark_holds?(mark, choice_mark?(mark) ? own : story) }
  end

  # Reports whether a story laid over the player's gives what a row gives: only when its marks tell
  # that its event ran (the row's ran, see world_catchup_data.rbx). An event they only tell is there
  # to play, as a town's companion who joins on a talk, stays the player's own to play.
  #
  # @param row [Struct] The row.
  # @return [Boolean] Whether it does.
  def self.carries?(row)
    row.ran != false
  end

  # Reports whether a story finished a route.
  #
  # @param route [String] The route.
  # @param story [Array] The story.
  # @return [Boolean] Whether it did.
  def self.cleared?(route, story)
    story[0][MGQ_MpWorldStory::CLEAR_SWITCHES[MGQ_MpWorldStory::ROUTES.index(route)]] ? true : false
  end

  # Orders two rows by their places in the story: part, then step.
  #
  # @param row [Struct] The one.
  # @return [Array<Integer>] Its order, compared left to right.
  def self.place_of(row)
    [RANKS[row.part].to_i, row.step.to_i]
  end

  # Reports whether a row comes after another in the story: at a later place, or later in the same
  # event's list.
  #
  # @param row [Struct] The one, with its site and index.
  # @param other [Struct] The other.
  # @return [Boolean] Whether it does.
  def self.after?(row, other)
    order = place_of(row) <=> place_of(other)
    return order > 0 unless order == 0

    row.site == other.site && row.index.to_i > other.index.to_i
  end

  # Names a row in the notes.
  #
  # @param kind [String] "j" join, "r" removal, "k" key item, "c" chest, "g" reward.
  # @param row [Struct] The row.
  # @return [String] Its key.
  def self.key_of(kind, row)
    @row_keys ||= {}.compare_by_identity
    @row_keys[row] ||= case kind
                       when "j", "r" then "#{kind}:#{row.site}:#{row.persona}"
                       when "k" then "k:#{row.site}:#{row.item}:#{row.amount}"
                       when "c" then "c:#{row.key.join('.')}"
                       else "g:#{row.site}:#{row.kind}#{row.id}"
                       end
  end

  # Looks at every row of the tables against the player's story, see the module: rows the
  # player's own game played are noted done, those a story carried them past give their rewards
  # and take their companions, the world's key items and chests come to everyone, and companions
  # whose gate the player reached join.
  #
  # @param story [Array] The player's story: switches, variables and self switches.
  # @param carried [Boolean] Whether a story laid over theirs just carried them past what is new.
  def self.review(story, carried)
    new_look
    note_side(story)
    done = ledger["done"]
    gifts = []
    DATA::REWARDS.each do |row|
      key = key_of("g", row)
      next if done[key] || (carried && !carries?(row)) || !passed?(row, story)

      done[key] = true
      gifts << give(row.kind == :skill ? :skill : row.kind.to_s, row.id, row.amount, key) if carried
    end
    gifts.concat(world_items(story, carried, done))
    companions(story, carried, done)
    tell_gifts(gifts.compact)
  end

  # Gives the world's key items and the items of its story chests, see the module.
  #
  # @param story [Array] The player's story.
  # @param carried [Boolean] Whether a story laid over theirs just carried them past what is new.
  # @param done [Hash] The rows done.
  # @return [Array<String>] What was given, as shown.
  def self.world_items(story, carried, done)
    gifts = []
    told = @world_told
    DATA::KEY_ITEMS.each do |row|
      key = key_of("k", row)
      next if done[key]
      next gifts << top_up(row, story, told, done, key) unless carries?(row)

      mine = passed?(row, story)
      next unless mine || (told && passed?(row, told, story))

      done[key] = true
      gifts << give("i", row.item, row.amount, key) if carried || !mine
    end
    DATA::CHESTS.each do |row|
      key = key_of("c", row)
      next if done[key]

      mine = story[2][row.key] ? true : false
      next unless mine || (told && told[2][row.key])

      done[key] = true
      next unless carried || !mine

      row.items.each { |id| gifts << give("i", id, 1, key) }
      open_chest(row.key) unless mine
    end
    gifts
  end

  # Gives a key item whose row's marks only tell that its event is there to play, once the world's
  # story is past the row: what the player lacks of its amount, unless the world's story took the
  # item since.
  #
  # A global flag often uses such an event up for the whole world, as switch 2039 the Key to Hades,
  # so only the player whose game played it would hold the item otherwise.
  #
  # @param row [MGQ_MpWorldCatchupData::KeyItem] The row.
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came.
  # @param done [Hash] The rows done.
  # @param key [String] The row's key.
  # @return [String, nil] What was given, as shown, nil for nothing.
  def self.top_up(row, story, told, done, key)
    return nil unless row.amount > 0 && told && passed?(row, told, story)

    done[key] = true
    item = MGQ_MpGame.item("i", row.item)
    missing = item && !taken_since?(row, told, story) ? row.amount - $game_party.item_number(item) : 0
    missing > 0 ? give("i", row.item, missing, key) : nil
  end

  # Reports whether a story took a key item after a row gave it: a later row of the same part, or a
  # row of a later part, that takes it.
  #
  # @param row [MGQ_MpWorldCatchupData::KeyItem] The row that gives it.
  # @param told [Array] The story.
  # @param story [Array] The player's own story.
  # @return [Boolean] Whether it did.
  def self.taken_since?(row, told, story)
    DATA::KEY_ITEMS.any? do |other|
      next false unless other.item == row.item && other.amount < 0 && other.part && row.part
      later = other.part == row.part ? after?(other, row) : RANKS[other.part] > RANKS[row.part]
      later && passed?(other, told, story)
    end
  end

  # Gives or takes what a row of the tables names.
  #
  # @param kind [Symbol, String] :skill, or "i", "w" or "a" for an item.
  # @param id [Integer] The skill or item.
  # @param amount [Integer] How many, below 0 to take.
  # @param key [String] The row, for the log.
  # @return [String, nil] What was given, as shown, nil for nothing.
  def self.give(kind, id, amount, key)
    if kind == :skill
      name = MGQ_MpStoryState.learn(id)
      return name.is_a?(String) ? name : nil
    end

    item = MGQ_MpGame.item(kind, id)
    unless item
      log("skipped #{kind}#{id} of #{key}: not in the game")
      return nil
    end

    if amount < 0
      $game_party.lose_item(item, -amount)
      log("took #{item.name} x#{-amount} (#{key})")
      return nil
    end
    MGQ_MpCoopEvents.granting { $game_party.gain_item(item, amount) }
    log("gave #{item.name} x#{amount} (#{key})")
    amount > 1 ? "#{item.name} x#{amount}" : item.name
  end

  # Shows a world-wide chest the world opened as open in the player's story too, so it gives
  # nothing twice.
  #
  # @param key [Array] Its self switch: map, event and letter.
  def self.open_chest(key)
    MGQ_MpStoryState.data_of($game_self_switches)[key] = true
    $game_map.need_refresh = true if $game_map
  end

  # Tells the player what the story gave them.
  #
  # @param gifts [Array<String>] What was given, as shown.
  def self.tell_gifts(gifts)
    return if gifts.empty?

    shown = gifts.first(4).join(", ")
    notice(:gifts, "The story gave you #{shown}#{gifts.size > 4 ? " and #{gifts.size - 4} more" : ''}.")
  end

  # Notes that ORB_EVENT waits to play once the player holds every orb before the story moved on,
  # once per session: the orbs the catch-up gave came without the call of an orb's event.
  def self.check_orbs
    return if @orbs_due || @orbs_played || MGQ_MpWorldStory.mode != :world || !orbs_due?

    @orbs_due = true
    log("the player holds every orb of Part 2 at #{$game_variables[MGQ_MpWorldStory::MAIN_PROGRESS]}: common event #{ORB_EVENT} waits to play once the player is free")
  end

  # Reports whether the story waits for ORB_EVENT: the player holds every orb, and the main story
  # has not reached ORBS_GATHERED.
  #
  # @return [Boolean] Whether it does.
  def self.orbs_due?
    return false unless $game_variables[MGQ_MpWorldStory::MAIN_PROGRESS].to_i < ORBS_GATHERED

    ORBS.all? do |id|
      item = MGQ_MpGame.item("i", id)
      item && $game_party.item_number(item) > 0
    end
  end

  # Plays ORB_EVENT once the player is free on the map, unless the story moved on meanwhile.
  def self.play_orb_event
    return unless MGQ_MpOverworldSync.map_free? && !MGQ_MpWorldStory.queued?

    @orbs_due = false
    return unless MGQ_MpWorldStory.mode == :world && orbs_due?

    @orbs_played = true
    log("playing common event #{ORB_EVENT} now")
    $game_map.interpreter.setup([MGQ_MpWorldStory.command(117, [ORB_EVENT]), MGQ_MpWorldStory.command(0, [])], 0)
  end

  # Follows the story's companions, see the module: the removals and joins the player's story is
  # past, and the joins waiting for their gate.
  #
  # @param story [Array] The player's story.
  # @param carried [Boolean] Whether a story laid over theirs just carried them past what is new.
  # @param done [Hash] The rows done.
  def self.companions(story, carried, done)
    removed = {}
    DATA::REMOVALS.each do |row|
      key = key_of("r", row)
      next if done[key] || !passed?(row, story)

      done[key] = true
      (removed[row.actor] ||= []) << row
    end
    fresh = []
    DATA::JOINS.each do |row|
      key = key_of("j", row)
      state = done[key]
      if state.nil?
        next if carried && !carries?(row)
        next unless passed?(row, story)
        next done[key] = true if row.part.nil?

        fresh << row
      elsif state != true && removed[row.actor]
        # A removal passed after this join waited, so it came later in the story.
        done[key] = true
        log("dropped the waiting join of #{actor_label(row.persona)} at #{row.site}: the story took them away since")
      end
    end
    fresh.each { |row| note_join(row, carried, removed, done) }
    take_away(removed, fresh) if carried
    bring_waiting(done)
  end

  # Notes a join the player's story just got past: done when its companion is there or the
  # player's own game left them out, else waiting for its gate; dropped when the same look passed a
  # later removal of the companion.
  #
  # @param row [MGQ_MpWorldCatchupData::Join] The join.
  # @param carried [Boolean] Whether a story laid over theirs carried them past it.
  # @param removed [Hash{Integer => Array}] The removals passed in the same look, by companion.
  # @param done [Hash] The rows done.
  def self.note_join(row, carried, removed, done)
    key = key_of("j", row)
    later = (removed[row.actor] || []).any? { |removal| after?(removal, row) }
    return done[key] = true if later

    present = in_roster?(row.actor)
    done[key] = if present
                  carried && row.rule != START_RULE ? "c" : true
                elsif carried
                  "c"
                else
                  ledger["held"].delete(row.actor) ? "o" : true
                end
  end

  # Takes away the companions a story carried the player past the lasting removal of, as a first
  # playthrough loses them, unless a join of the same look comes after each of those removals or at
  # the same place.
  #
  # @param removed [Hash{Integer => Array}] The removals passed, by companion.
  # @param fresh [Array] The joins passed in the same look.
  def self.take_away(removed, fresh)
    return unless $game_variables[PLAYTHROUGH].to_i == 0

    removed.each do |actor, rows|
      lasting = rows.select { |row| row.first }
      next if lasting.empty? || actor == HERO || !in_roster?(actor)

      next if fresh.any? { |row| row.actor == actor && lasting.none? { |removal| after?(removal, row) } }

      $game_party.remove_actor(actor)
      roster_changed
      log("#{actor_label(actor)} left the player's roster: the story carried them past #{lasting.map { |row| row.site }.join(', ')}")
      notice([:left, actor], "#{actor_name(actor)} left with the story.")
    end
  end

  # Lets the joins that wait for their gate in: the companion joins, or one already there is
  # raised to the join's level, once the player's level reaches the gate.
  #
  # @param done [Hash] The rows done.
  def self.bring_waiting(done)
    DATA::JOINS.each do |row|
      key = key_of("j", row)
      state = done[key]
      next if state.nil? || state == true

      present = in_roster?(row.actor)
      next done[key] = true if present && state == "o"
      next unless reached?(row.gate)

      done[key] = true
      level = row.rule == START_RULE ? nil : row.gate
      present ? raise_level(row.persona, level) : bring_in(row.persona, level, "level #{row.gate} reached")
    end
  end

  # Brings a companion into the player's roster as the game's own join does: the persona, recovered,
  # into the team, or on standby through the game's own cut when it is full or a story's temporary
  # party plays; then raised to the join's level.
  #
  # @param persona [Integer] The persona that joins.
  # @param level [Integer, nil] The level they come at least at, nil for their own.
  # @param reason [String] Why, for the notice.
  # @return [Boolean] Whether they joined.
  def self.bring_in(persona, level, reason)
    return false unless $data_actors[persona]
    return false if in_roster?(persona)

    @granting = true
    begin
      $game_party.persona_change(persona) if $game_party.respond_to?(:persona_change)
      actor = $game_actors[persona]
      actor.recover_all if actor && actor.respond_to?(:recover_all)
      temp = $game_party.respond_to?(:temp_actors_use?) && $game_party.temp_actors_use?
      temp ? $game_party.add_stand_actor(persona) : $game_party.add_actor(persona)
    ensure
      @granting = false
      roster_changed
    end
    raise_level(persona, level)
    log("#{actor_label(persona)} joined the player's roster (#{reason})")
    notice([:joined, persona], "#{actor_name(persona)} joined: #{reason}.")
    true
  end

  # Raises a companion to a level, as the story's level floors do; never lowers them.
  #
  # @param persona [Integer] The companion, in any persona.
  # @param level [Integer, nil] The level, nil for none.
  def self.raise_level(persona, level)
    actor = level && $game_actors[persona]
    return unless actor && actor.base_level < level

    actor.change_level(level, false, :base)
    log("raised #{actor_label(persona)} to level #{actor.base_level}")
  end

  # Holds back a companion a story event of the player's own hands out in a Raid World before the
  # player's level reaches the join's gate: the join waits for it instead, see bring_waiting.
  # Called before the game adds a companion to the party.
  #
  # @param actor_id [Integer] The companion, in any persona.
  # @return [Boolean] Whether the game's own join is left out.
  def self.hold_join?(actor_id)
    return false if @granting || !active? || MGQ_MpWorldStory.mode != :world
    return false unless defined?(MGQ_MpCoopEvents) && MGQ_MpCoopEvents.telling?

    main = MGQ_MpStoryState.main_id(actor_id)
    return false if in_roster?(main)

    part = own_part
    done = ledger["done"]
    rows = joins_of(main).select { |row| row.part == part && done[key_of("j", row)] != true }
    return false if rows.empty?

    gate = rows.map { |row| row.gate }.min
    return false if reached?(gate)

    ledger["held"][main] = true
    log("held back #{actor_label(actor_id)}, whom the player's story event hands out: they join once the player's level reaches #{gate}")
    notice([:held, main], "#{actor_name(actor_id)} joins you once you reach level #{gate}.")
    true
  rescue => e
    log("holding back a companion failed: #{e.class}: #{e.message}")
    false
  end

  # Lists the story's joins of a companion.
  #
  # @param actor [Integer] The companion's main persona.
  # @return [Array<MGQ_MpWorldCatchupData::Join>] The joins, in the story's order.
  def self.joins_of(actor)
    unless @joins_by_actor
      @joins_by_actor = {}
      DATA::JOINS.each { |row| (@joins_by_actor[row.actor] ||= []) << row if row.part }
    end
    @joins_by_actor[actor] || []
  end

  # Reports whether a companion is one of the story's.
  #
  # @param actor [Integer] The companion's main persona.
  # @return [Boolean] Whether they are.
  def self.story_companion?(actor)
    !joins_of(actor).empty?
  end

  # Notes the companions new in the player's roster, which the world's shared list takes once
  # sharing is on: the story's companions, every one with battle recruits shared too.
  def self.note_roster
    ids = MGQ_MpStoryState.roster_ids
    fresh = ids - (@known_roster || [])
    @known_roster = ids
    sharing = MGQ_MpWorld.companion_sharing
    world = MGQ_MpWorldStory.world
    return if sharing == :off || world.nil?

    shared = world["comps"].to_a
    fresh.each do |id|
      next if id == HERO || shared.include?(id) || @share_queue.include?(id)
      next unless sharing == :all || story_companion?(id)

      @share_queue << id
    end
    share_in(sharing, shared)
  end

  # Writes the companions noted to the world's shared list, a few together.
  def self.send_shared
    return if @share_queue.empty? || @adding || @clock < @share_at

    ids = @share_queue.first(SHARE_BATCH)
    unless Relay.add(MGQ_MpWorldStory.world_id, ids.join(","))
      @share_at = @clock + START_FRAMES
      return log_once([:share_start, ids.size], "the DLL did not start adding #{ids.size} shared companions, trying again")
    end

    @adding = ids
    @share_queue -= ids
    @share_at = @clock + SHARE_FRAMES
    log("sharing #{ids.size} companions with the world: #{ids.join(', ')}")
  end

  # Takes the addition to the world's shared companions once it ended: failed, it goes again later.
  def self.read_shared
    outcome = MGQ_MpWorldStory::Relay.headers["companions"]
    return if outcome.nil? || outcome == "busy"

    ids = @adding
    @adding = nil
    return if outcome == "done"

    @share_queue = (ids + @share_queue).uniq
    @share_at = @clock + RETRY_FRAMES
    log("sharing companions with the world failed (#{outcome}): trying again later")
  end

  # Lets the companions the world shares join the player once their level reaches each one's gate:
  # a story companion at their first join's, a battle recruit at their start level. A companion the
  # player had is never brought back this way, in their roster or past one of their joins in the
  # player's story, nor one their story took away for good.
  #
  # @param sharing [Symbol] :story or :all, see MGQ_MpWorld.companion_sharing.
  # @param shared [Array<Integer>] The world's shared companions.
  def self.share_in(sharing, shared)
    done = ledger["done"]
    lost = nil
    shared.each do |id|
      key = "s:#{id}"
      next if id == HERO || done[key]

      lost ||= taken_for_good(done)
      next done[key] = true if in_roster?(id) || lost[id] || joined?(id, done)

      first = joins_of(id).first
      next unless first || sharing == :all

      gate = first ? first.gate : start_level(id)
      next unless reached?(gate)

      done[key] = true
      bring_in(first ? first.persona : id, first && first.rule != START_RULE ? gate : nil, "shared by the world")
    end
  end

  # Reports whether the player's story got past a join of a companion, which gave them the companion
  # whether or not they are in the roster now: a temporary removal of the story or the player may have
  # let them go since.
  #
  # @param id [Integer] The companion's main persona.
  # @param done [Hash] The rows done.
  # @return [Boolean] Whether it did.
  def self.joined?(id, done)
    joins_of(id).any? { |row| done[key_of("j", row)] == true }
  end

  # Lists the companions the player's story took away for good: past a removal that lasts, on a
  # first playthrough, which alone loses companions so.
  #
  # @param done [Hash] The rows done.
  # @return [Hash{Integer => Boolean}] The companions' main personas to true.
  def self.taken_for_good(done)
    lost = {}
    return lost unless $game_variables[PLAYTHROUGH].to_i == 0

    DATA::REMOVALS.each { |row| lost[row.actor] = true if row.first && done[key_of("r", row)] }
    lost
  end

  # Finds a companion's start level, the database's.
  #
  # @param id [Integer] The companion.
  # @return [Integer] The level.
  def self.start_level(id)
    data = $data_actors[id]
    data && data.respond_to?(:initial_level) ? data.initial_level.to_i : 1
  end

  # Names a companion for the log.
  #
  # @param id [Integer] The companion, in any persona.
  # @return [String] Such as "525 Sonya".
  def self.actor_label(id)
    MGQ_MpLog.named($data_actors, id)
  end

  # Names a companion for a notice.
  #
  # @param id [Integer] The companion, in any persona.
  # @return [String] Their name.
  def self.actor_name(id)
    data = $data_actors[id]
    data ? data.name.to_s : "A companion"
  end

  # Shows a notice of the catch-up in the mod's notification box.
  #
  # @param key [Object] What it is about, which a newer one replaces.
  # @param text [String] What it says.
  def self.notice(key, text)
    return MGQ_MpNotices.message([:catch_up, key], text, NOTICE_FRAMES) if defined?(MGQ_MpNotices)

    MGQ_MpOverworldSync.notice(text)
  end

  # Patch/Multiplayer/Multiplayer.dll's checkpoints and shared companions of the world at the relay.
  module Relay
    # Starts fetching a part's checkpoint.
    #
    # @param world [String] The world's id.
    # @param part [String] The part.
    # @return [Boolean] Whether it started.
    def self.fetch(world, part)
      MGQ_Multiplayer::Link.function('mp_raid_checkpoint_fetch').call(world + "\0", part + "\0") == 1
    rescue => e
      MGQ_MpWorldCatchup.log("fetching a checkpoint failed: #{e.class}: #{e.message}")
      false
    end

    # Reads the last checkpoint fetched and how its fetch stands.
    #
    # @return [Hash] The headers (see docs/DEVELOPER.md), the story under :payload; empty before
    #   any fetch.
    def self.state
      text = MGQ_Multiplayer::Link.read('mp_raid_checkpoint_state', STATE_SIZE)
      text.empty? ? {} : MGQ_Multiplayer::Link.parse(text)
    rescue => e
      MGQ_MpWorldCatchup.log_once([:state, e.class], "reading the checkpoint failed: #{e.class}: #{e.message}")
      {}
    end

    # Starts adding companions to the world's shared list.
    #
    # @param world [String] The world's id.
    # @param ids [String] The companions' actor ids, separated by commas.
    # @return [Boolean] Whether it started.
    def self.add(world, ids)
      MGQ_Multiplayer::Link.function('mp_raid_companions_add').call(world + "\0", ids + "\0") == 1
    rescue => e
      MGQ_MpWorldCatchup.log("sharing companions failed: #{e.class}: #{e.message}")
      false
    end
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the catch-up.
  MGQ_MpHooks.after(Game_Map, :update, "world_catchup") { MGQ_MpWorldCatchup.tick }

  # A loaded save or a new game bring their own story and notes. Not after extract_save_contents,
  # which a duel's end calls too to put the game back.
  MGQ_MpHooks.after(DataManager.singleton_class, :load_game_without_rescue, "world_catchup") { |_index| MGQ_MpWorldCatchup.loaded }
  MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "world_catchup") { MGQ_MpWorldCatchup.loaded }
rescue => e
  MGQ_MpWorldCatchup.log("hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # A companion a story event of the player's own hands out before the join's gate waits for it.
  MGQ_MpHooks.around(Game_Party, :add_actor, "world_catchup") do |_party, args, original|
    MGQ_MpWorldCatchup.hold_join?(args[0]) ? nil : original.call
  end
  MGQ_MpHooks.around(Game_Party, :add_stand_actor, "world_catchup") do |_party, args, original|
    MGQ_MpWorldCatchup.hold_join?(args[0]) ? nil : original.call
  end
rescue => e
  MGQ_MpWorldCatchup.log("party hooks FAILED: #{e.class}: #{e.message}")
end
