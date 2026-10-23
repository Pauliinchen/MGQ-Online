#----------------------------------------------------------------
#  world_catchup.rbx
#
#  Changelog:
#      Paulinchen  2026-10-23: Gave job and race items another player found to every player of the world at once
#                            - Told the level a cap of another mod opens the gate at in the gate's notices
#                            - Set the game over's return point of the story only on the map of the event that sets it
#      Paulinchen  2026-10-17: Listed no companion on the Unlocks page whom a removal of the story took away
#                            - Held the catch-up while a lost raid boss battle's defeat runs
#                            - Ordered the key items one event gives and takes back by their rows, which no longer fails the catch-up
#                            - Kept the catch-up's other checks running when one fails
#                            - Gave job and race items of one-time gifts by the story's place
#                            - Gave once the rewards notes of an earlier version noted done without giving them
#                            - Gave found job and race items once a story reached where the story gives them
#                            - Asked a player whose story went past the choice of a side without one whom they take along
#      Paulinchen  2026-10-15: Held a lasting join on another page of a visit's event back until the level gate
#      Paulinchen  2026-10-14: Let a visit's own event bring its companion along before the level gate
#      Paulinchen  2026-10-13: Left the joins the story takes back in the same step out of the catch-up
#                            - Counted no companion on such a visit, nor a story's temporary party, toward the player's level
#                            - Listed and gave a Makina only once a player of the world got or held it
#      Paulinchen  2026-10-12: Gave every player's characters the classes and races the story and its quests give
#                            - Taught every player's companions the skills the story and its quests teach them
#                            - Brought a shared companion whose talk the player's story only walked past
#                            - Noted the job and race unlock items a player holds on every look
#                            - Gave every job and race unlock item any player of the world got to every other player
#                            - Logged what the catch-up gave instead of telling it
#                            - Listed what moving on from a part brings along, and each companion's and Makina's id
#                            - Left the random encounters to a map only while its current page sets them the other way
#                            - Let the story's rewards wait after a move on at a level cap only for the first story laid over the player
#                            - Put a vehicle the story gave that stands on no map back at its start
#                            - Gave companions and Makina only once the player's real level reaches theirs
#                            - Held the story's skills and items past a move on at a level cap until the real level reaches the gate
#                            - Taught a player behind the world's story no skill of it before they move on
#                            - Took a vehicle off its map while no event that gives it is behind the player's story or the world's
#                            - Turned on the chest flags of a world-wide chest with its items
#                            - Kept the Randolphs found at the number of Randolph switches on
#                            - Settled the game over's return point by the route under way and the world's story only while the player plays it
#                            - Took a vehicle off its map for a player behind the world's story whose own story has not given it yet
#                            - Kept the parts of one look by the story itself and looked anew at every audit
#      Paulinchen  2026-10-11: Listed what the catch-up hands out by level for the World overview
#                            - Gave every Makina by the area level of its easiest place and took back extra copies
#                            - Followed the story values of a watched telling as a story laid over the player's once they are free
#                            - Took a key item as taken when a row of the same step whose marks lie further takes it
#                            - Raised Amira's information network to 2 for a player who has her
#                            - Checked the story's skills, key items, companions and own values once on entering, after a load and on every level up
#                            - Moved the player's own story values on to the latest step their story passed, and lifted a leftover warp ban
#                            - Handed out every key item the story's place owes the player and they lack, whoever's game played its event
#      Paulinchen  2026-10-10: Kept what a player behind changed under a checkpoint, and took it as the story they stand on
#                            - Moved a player behind past the routes the world finished on to the world's story
#      Paulinchen  2026-10-09: Read and wrote the story and granted its rewards through story_state.rbx instead of coop_story.rbx
#                            - Gave a key item whose event is only there to play once the world's story is past it, and played the orbs' event
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
# the story on, which only an orb's own event calls. Every item unlocking a job or a race that any
# player of the world got comes to every other player. Every Makina comes once the player's level
# reaches the area level of its easiest place, one of each.
#
# Companions, Makina and the story's skills and items go by the player's real level alone: a cap
# of another mod lets the player move on in the story, and what that move carries them past waits
# in the save until their real level reaches the gate. A player behind learns no skill of the
# world's story past their part's checkpoint before moving on. Every look while the player is free
# hands out what their level reached, so entering the world or loading a save brings everything
# pending at once.
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

  # The event command that turns random encounters off (its parameter 0) or on.
  ENCOUNTER_CODE = 136

  # The switch that bans warping, as Harpy Feathers do, each player's own.
  WARP_BAN = defined?(NWConst::Sw::WARP_BAN) ? NWConst::Sw::WARP_BAN : 100

  # The game's vehicles by the number its events and DATA::VEHICLES name them.
  VEHICLE_TYPES = [:boat, :ship, :airship]

  # Frames between two looks at the player's story, half a second.
  CHECK_FRAMES = 30

  # Looks between two looks at the skills, classes and races the story gave the roster's
  # characters (check_growth), five seconds, as the tables hold thousands of rows.
  GROWTH_CHECKS = 10

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

  # The companions none of whose joins is temporary, however the story takes them away again (see
  # temporary?): Alice, and Ilias with her later selves, who travel with Luka.
  LASTING_COMPANIONS = [5, 26, 29, 30]

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

  # Variables that count switches, by variable: the Randolphs found (1354), one switch each (3101 to
  # 3180). The game adds 1 as it turns one on, so two players finding a Randolph each before either
  # story reached the other kept one addition alone.
  COUNTS = { 1354 => 3101..3180 }

  # Where each part stands in the story's order; the routes stand side by side.
  RANKS = { "1" => 0, "2" => 1, "3" => 2, "ad" => 3, "mr" => 3, "chaos" => 3 }

  # The parts before the Great Decision, whose sides the player chose themselves.
  SIDED_PARTS = %w(1 2 3)

  # What the notes keep for a companion the world shares once it joined or never will.
  #
  # A value of its own rather than true, so a note of true that another build wrote is looked at
  # again.
  SHARE_SETTLED = "settled"

  # The rule of a join whose gate is the companion's start level, which a companion new to the
  # player has anyway.
  START_RULE = :start

  # The kinds of what the catch-up hands out by level, in the order the World overview lists them
  # within a level.
  UNLOCK_KINDS = [:story, :companion, :makina]

  # What the catch-up hands out at a level, for the World overview's Unlocks page.
  #
  # @!attribute level [Integer] The level.
  # @!attribute kind [Symbol] :story (moving on from a part), :companion or :makina.
  # @!attribute name [String] What it is: the part moved on from, the companion's or the Makina's name.
  # @!attribute icon [Integer, nil] The Makina's icon, nil for the others.
  # @!attribute got [Boolean] Whether the player has it already.
  # @!attribute due [Boolean] Whether the player's level reached it, so it comes at the next check.
  # @!attribute id [Integer, nil] The companion's actor or the Makina's item.
  # @!attribute gains [Array<Gain>] What moving on from a part brings along.
  Unlock = Struct.new(:level, :kind, :name, :icon, :got, :due, :id, :gains)

  # Something moving on from a part brings along.
  #
  # @!attribute kind [Symbol] :key (a key item), :unlock (an item that unlocks a job or race),
  #   :skill or :item.
  # @!attribute id [Integer] The item or skill.
  # @!attribute item_kind [String, nil] "i", "w" or "a" for an item, nil for a skill.
  # @!attribute amount [Integer] How many.
  # @!attribute name [String] Its name.
  # @!attribute icon [Integer] Its icon.
  Gain = Struct.new(:kind, :id, :item_kind, :amount, :name, :icon)

  # The tag at the start of an item's description that tells it unlocks a job or a race, in the
  # translation and the untranslated game.
  UNLOCK_ITEM_TAG = /\A\s*[\[［](Job|Race|職業|種族)/

  # The story values a companion's own join stands for, by companion: each variable with the least
  # it holds once they joined. A companion the world shared, or the catch-up brought, comes without
  # them: Amira joins only once her information network ("Pornof Rabbit Events") reached 2, and her
  # information in the Pocket Castle stays shut below it.
  COMPANION_VALUES = { 540 => { 1009 => 2 } }

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
    @growth_count = 0
    @growth_roster = nil
    @share_queue = []
    @adding = nil
    @share_at = 0
    @orbs_due = false
    @orbs_played = false
    @asking_side = false
    @audit_due = true
    @riding_early = false
    @vehicles_due = false
    @watched = nil
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

  # Reports whether a lost raid boss battle's defeat runs, which takes items its undo gives back (see
  # battles_raid_freeze.rbx): a restock meanwhile would give them twice. Logs once as a hold starts
  # and as it ends.
  #
  # @return [Boolean] Whether one runs.
  def self.holding?
    holding = defined?(MGQ_MpRaidFreeze) && MGQ_MpRaidFreeze.holding_writes? ? true : false
    if holding != (@holding ? true : false)
      log(holding ? "a lost raid boss battle's defeat runs: the catch-up waits until its undo ran" : "the lost raid boss battle's defeat ended: the catch-up goes on")
    end
    @holding = holding
  rescue => e
    log_once(:holding, "looking whether a lost raid boss battle holds the catch-up failed: #{e.class}: #{e.message}")
    false
  end

  # Tells the player why their story event did not start.
  #
  # @return [String] The notice.
  def self.refusal_text
    "Reach level #{level_to_reach(own_part)} to continue the story."
  end

  # Tells the player they are behind the world's story.
  #
  # @param own [Hash] The player's counters, see MGQ_MpWorldStory.local_counters.
  # @return [String] The notice.
  def self.behind_text(own)
    part = MGQ_MpWorldStory.part_of(own)
    "The world's story is further than yours. You see the world as it was before the end of #{part_name(part)}; reach level #{level_to_reach(part)} to move on."
  end

  # Follows the catch-up for one frame: the relay's answers, the checkpoint and the orbs' event that
  # wait, then every CHECK_FRAMES while the player is free the rewards waiting for their gate, the
  # story's rows, the level gate, the shared companions, the orbs and the Makina, and the vehicles
  # after a story laid over the player's. Called after the map's update. Nothing goes on while a
  # lost raid boss battle's defeat runs (see holding?).
  def self.tick
    @clock += 1
    return close unless active?
    return if holding?

    note_world
    read_requests if (@fetching || @adding) && @clock - @state_read >= STATE_FRAMES
    start_fetch if @want && !@fetching && !@ready && @clock >= @fetch_at
    play_orb_event if @orbs_due
    return if @clock - @checked < CHECK_FRAMES || !MGQ_MpWorldStory.quiet?

    @checked = @clock
    # The personal half of a return to the Great Decision plays first, since it clears the route.
    return (MGQ_MpWorldStory.queued? ? nil : take_checkpoint) if @ready
    return if MGQ_MpWorldStory.mode.nil?

    carry_watched
    @audit_due = true if got_off_early?
    looking do
      if @audit_due
        audit(story_now)
      elsif @vehicles_due
        guarded(:vehicles) { check_vehicles(story_now, played_world_story) }
      end
      guarded(:waiting_rewards) { give_waiting_rewards }
      review(story_now, false)
      guarded(:side) { ask_side }
      guarded(:growth) { check_growth }
      guarded(:move_on) { move_on if MGQ_MpWorldStory.mode == :behind && !@want && !@joins_world && gate_reached? }
      guarded(:roster) { note_roster }
      guarded(:orbs) { check_orbs }
      guarded(:makina) { check_makina }
      guarded(:found_items) { check_found_items }
      guarded(:counts) { check_counts }
    end
    send_shared
  rescue => e
    log_once(:tick, "following the catch-up failed: #{e.class}: #{e.message}")
  end

  # Runs one check of the catch-up and logs it failing once, so a failing check leaves the ones
  # after it running.
  #
  # @param name [Symbol] The check, for the log.
  # @return [Object, nil] What the check returned, nil when it failed.
  def self.guarded(name)
    yield
  rescue => e
    log_once([:check, name], "the #{name} check failed: #{e.class}: #{e.message}")
    nil
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
  # ("held"), the part whose checkpoint the player got ("checkpoint"), the side they chose before
  # the Great Decision ("side"), the gate of a move on a cap of another mod opened until its story
  # is laid over theirs ("capped"), and the rewards that move carried them past, waiting for their
  # gate ("waits", a row's key to its gate), and whether repair_rewards ran ("rewards_repaired",
  # true from the start for notes it never needs to repair). Notes of another world start anew.
  #
  # @return [Hash] The notes.
  def self.ledger
    notes = $game_system.instance_variable_get(LEDGER)
    id = MGQ_MpWorldStory.world_id
    unless notes.is_a?(Hash) && notes["world"] == id && notes["done"].is_a?(Hash)
      notes = { "world" => id, "done" => {}, "held" => {}, "checkpoint" => nil, "side" => nil, "capped" => nil, "waits" => {}, "rewards_repaired" => true }
      $game_system.instance_variable_set(LEDGER, notes)
    end
    notes["held"] ||= {}
    notes["waits"] ||= {}
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

  # The level a part's gate asks of the player: the gate, or the cap another mod holds them at
  # below it, which opens the gate too (see gate_open?).
  #
  # @param id [String] The part.
  # @return [Integer] The level.
  def self.level_to_reach(id)
    gate = gate_of(id)
    cap = roster_view[:cap]
    cap.is_a?(Integer) && cap < gate ? cap : gate
  rescue
    gate_of(id)
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

  # Notes the world's story laid over the player's, for the key items and chests it gave, and clears
  # the save's note that the player is behind, see noted_behind?. Called by world_story.rbx.
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
  # MGQ_MpStoryState.mix) and what they changed while behind where the checkpoint did not change it
  # (see MGQ_MpWorldStory.keep_own): the world as it was right before that part's ending, which is
  # the story they stand on from then. Only a player still behind takes it.
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
    base = MGQ_MpStoryState.deep_copy(applied)
    kept, dropped = MGQ_MpWorldStory.keep_own(applied, told, local, MGQ_MpWorldStory.base, false)
    MGQ_MpWorldStory.keep_open_chests(applied, local)
    MGQ_MpStoryState.set_raw(*applied)
    MGQ_MpWorldStory.stand_on(base)
    ledger["checkpoint"] = ready[:part]
    after = MGQ_MpWorldStory.local_counters(applied)
    log("took the checkpoint of #{part_name(ready[:part])} (revision #{ready[:wrev]}): #{MGQ_MpWorldStory.counters_text(own)} -> #{MGQ_MpWorldStory.counters_text(after)}; " \
        "kept #{kept.size} own changes, dropped #{dropped.size}")
    carried(local)
    ledger["capped"] = nil
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
  # then what the story carried them past gives what it gives, and the next check looks at the
  # vehicles (check_vehicles). Called by world_story.rbx and after a checkpoint.
  #
  # The first story laid over a player no longer behind is the one a move on at a level cap led to,
  # even when its checkpoint was dropped, so its rewards still wait (see note_capped); later ones
  # give as usual.
  #
  # @param before [Array] The player's story before: switches, variables and self switches.
  def self.carried(before)
    return unless active?

    drop_capped("the player plays the world's story already") if MGQ_MpWorldStory.mode == :world
    # The story before a telling the player watched is older, and the telling's values count as laid
    # over too, see watched.
    before = @watched || before
    @watched = nil
    @vehicles_due = true
    looking do
      review(before, false)
      review(story_now, true)
    end
    drop_capped("the story the move led to is laid over the player's") unless MGQ_MpWorldStory.mode == :behind
    return unless @joins_world

    @joins_world = false
    ledger["checkpoint"] = nil
    ledger["capped"] = nil
    log("the player plays the world's story now")
  rescue => e
    log("following a story laid over the player's failed: #{e.class}: #{e.message}")
  end

  # Keeps the player's story from before a teller's story values first moved it while they watch a
  # telling, until the player is free again (see carry_watched). Called before the values are
  # written, see MGQ_MpCoopScene.apply_values.
  #
  # @yieldreturn [Array] A copy of the player's story now.
  def self.watched
    @watched ||= yield if active?
  end

  # Follows the story values a watched telling laid over the player's as a story laid over theirs,
  # since only the teller's game ran the scene's commands: what the scene gave comes, and the key
  # items it took go. Its rows would otherwise count as played by the player's own game.
  def self.carry_watched
    return unless @watched

    log("following the story values of a telling the player watched")
    carried(@watched)
  end

  # Reports whether the player's highest base level reaches their part's gate, or the cap another
  # mod holds them at below it.
  #
  # @return [Boolean] Whether it does.
  def self.gate_reached?
    gate_open?(gate_of(own_part))
  end

  # Reports whether a part's gate lets the player move on: their level reached it, or the character
  # of their highest base level is at the highest level the game lets them reach (Game_Actor#max_level,
  # which another mod may cap) below it.
  #
  # A cap that rises with the story's bosses would otherwise hold a player behind for good, as their
  # story plays no boss while behind.
  #
  # @param level [Integer] The gate.
  # @return [Boolean] Whether it does.
  def self.gate_open?(level)
    return true if reached?(level)

    view = roster_view
    cap = view[:cap]
    view[:best] && cap.is_a?(Integer) && cap < level && view[:best] >= cap
  rescue
    false
  end

  # Reports whether the player's highest base level among their characters reaches a level, which
  # every companion and Makina the catch-up hands out waits for, whatever cap another mod holds the
  # player at.
  #
  # @param level [Integer] The level.
  # @return [Boolean] Whether it does.
  def self.reached?(level)
    best = roster_view[:best]
    best ? best >= level : false
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
  # them, those on a visit aside (see visiting?), with that character's own highest level. Kept for one look at the rows, see looking, as
  # it copies the roster.
  #
  # @return [Hash] :ids (each companion's main persona to true), :best and :cap (nil without one).
  def self.roster_view
    return @roster_view if @roster_view

    ids = {}
    MGQ_MpStoryState.roster_ids.each { |id| ids[id] = true }
    story = story_now
    best = MGQ_MpStoryState.roster.reject { |actor| visiting?(MGQ_MpStoryState.main_id(actor.id), story) }.max_by { |actor| actor.base_level }
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
    notice(:gate, "Level #{level_to_reach(from)} reached: catching up to #{name}.")
    note_capped(gate)
    return_from_route(from, world)
    target == :world ? join_world : want(target, "moving on from #{part_name(from)}")
  end

  # Notes the gate the player moves on at while only a cap of another mod opened it, so the story's
  # rewards the move carries them past wait for their real level (see rewards_wait?). The story the
  # move lays over theirs clears it, see carried, drop_capped and take_checkpoint.
  #
  # @param gate [Integer] The gate.
  def self.note_capped(gate)
    notes = ledger
    notes["capped"] = reached?(gate) ? nil : gate
    log("moved on at a level cap below #{gate}: the story's rewards wait for level #{gate}") if notes["capped"]
  end

  # Forgets the gate a move on at a level cap noted, so the story's rewards give as usual again.
  #
  # @param reason [String] Why, for the log.
  def self.drop_capped(reason)
    gate = ledger["capped"]
    return unless gate

    ledger["capped"] = nil
    log("the story's rewards no longer wait for level #{gate}: #{reason}")
  end

  # Reports whether the story's rewards a story laid over the player's carries them past wait: it is
  # the move a cap of another mod opened (note_capped), and their real level has not reached that
  # gate yet.
  #
  # @return [Boolean] Whether they do.
  def self.rewards_wait?
    gate = ledger["capped"]
    gate.is_a?(Integer) && !reached?(gate)
  end

  # Gives the story's rewards that wait for a gate (rewards_wait?) once the player's real level
  # reaches it.
  def self.give_waiting_rewards
    waits = ledger["waits"]
    return if waits.empty?

    gifts = DATA::REWARDS.map do |row|
      key = key_of("g", row)
      gate = waits[key]
      next unless gate && reached?(gate)

      waits.delete(key)
      give(reward_kind(row), row.id, row.amount, key)
    end
    tell_gifts(gifts.compact)
  end

  # The kind give takes for a reward row.
  #
  # @param row [MGQ_MpWorldCatchupData::Reward] The row.
  # @return [Symbol, String] :skill, or the item's kind.
  def self.reward_kind(row)
    row.kind == :skill ? :skill : row.kind.to_s
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

  # Finds where a player moves on to from a part: the next of Parts 1 to 3 the world played that has
  # a checkpoint, or the world's own story once that is the world's part or none is left. A route
  # the world finished is never a next part, as the routes stand side by side: the world's story
  # laid over theirs gives the finished route's rows too (see passed?). A player in the world's
  # part, as after its return from a route to the Great Decision, goes to its story.
  #
  # @param from [String] The player's part.
  # @param world [Hash] The world's counters.
  # @return [String, Symbol] The part, or :world.
  def self.next_part(from, world)
    current = world["part"].to_s
    return :world if from == current

    parts = world_parts(world)
    at = parts.index(from)
    return :world unless at

    parts[(at + 1)..-1].each do |candidate|
      return :world if candidate == current
      next if MGQ_MpWorldStory::ROUTES.include?(candidate)
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

  # The main story's step the choice of a side in Iliasville leaves (map 6, events 30 and 31).
  SIDE_STEP = 7

  # The companion each side brings along.
  SIDE_COMPANIONS = { :alice => 5, :ilias => 26 }

  # Asks the player whom they take along once they are free, when their story went past the choice
  # of a side before the Great Decision without one, until they chose.
  #
  # A teller's scene ends the player's own choice before it sets the side when both play it at once,
  # and the side switches are each player's own in a Raid World, so the teller's choice is no help.
  def self.ask_side
    # A battle's invite clears the message window, and the question with it.
    @asking_side = false if @asking_side && !$game_message.busy?
    return if @asking_side || !lost_side? || !MGQ_MpOverworldSync.map_free? || MGQ_MpCoopEvents.mirroring? || $game_message.busy?

    @asking_side = true
    log("asking the player whom they take along: their story went past the choice of a side without one")
    $game_message.add("Your story went past the choice of whom you take along. Whom do you take along on your journey?")
    $game_message.choices.push("Alice", "Ilias")
    $game_message.choice_cancel_type = 0
    $game_message.choice_proc = Proc.new { |index| take_side(index == 0 ? :alice : :ilias) }
  end

  # Reports whether the player's story went past the choice of a side without one, before the Great
  # Decision.
  #
  # @return [Boolean] Whether it did.
  def self.lost_side?
    story = story_now
    MGQ_MpStoryState.side_of(story[0]).nil? && SIDED_PARTS.include?(part_of(story)) &&
      story[1][MGQ_MpWorldStory::MAIN_PROGRESS].to_i.between?(SIDE_STEP, MGQ_MpWorldStory::BEFORE_DECISION)
  end

  # Keeps the side the player chose and brings its companion along, as the choice in Iliasville
  # does; the next look gives what the side's rows owe, as the Pocket Castle.
  #
  # @param side [Symbol] :alice or :ilias.
  def self.take_side(side)
    @asking_side = false
    MGQ_MpStoryState::SIDE_SWITCHES.each { |id| $game_switches[id] = id == (side == :alice ? MGQ_MpStoryState::ALICE_CHOSEN : MGQ_MpStoryState::ILIAS_CHOSEN) }
    name = side == :alice ? "Alice" : "Ilias"
    log("the player took #{name} along")
    bring_in(SIDE_COMPANIONS[side], nil, "you took #{name} along")
    @audit_due = true
  rescue => e
    log("taking a side failed: #{e.class}: #{e.message}")
  end

  # The part a story is in, kept for the look at the rows under way, see review.
  #
  # The part is kept by the story itself, as an object id comes back once its story is collected
  # and would hand a later story the part of an earlier one.
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [String] See MGQ_MpWorldStory.part_of.
  def self.story_part(story)
    @story_parts ||= {}.compare_by_identity
    @story_parts[story] ||= part_of(story)
  end

  # Forgets what one look at the rows kept, as the stories it read change.
  def self.new_look
    @story_parts = {}.compare_by_identity
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

  # Reports whether the player's story or the world's is past a row, see passed?.
  #
  # @param row [Struct] A row of the tables.
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil when it does not count.
  # @return [Boolean] Whether one is.
  def self.passed_any?(row, story, told)
    passed?(row, story) || (told && passed?(row, told, story)) ? true : false
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

  # Asks for one look at everything once the player is free again, see audit: as their level rose.
  def self.level_up
    @audit_due = true if active?
  end

  # Looks at everything the player's story owes them once, whatever the rows' notes say, as on
  # entering the world, after a load and on a level up: the story's skills Luka lacks, the key
  # items (restock_key_items), the story's companions missing from the roster, who join at their
  # gate, the player's own values the story sets (settle), with a warp ban left where warping is
  # free (lift_warp_ban), and the vehicles by what the story gave (check_vehicles). The world's
  # story counts for the skills, the values and the vehicles only while the player plays it, never
  # while they are behind it.
  #
  # @param story [Array] The player's story.
  def self.audit(story)
    @audit_due = false
    new_look
    told = @world_told
    world = played_world_story
    done = ledger["done"]
    gifts = guarded(:skills) { missing_skills(story, world) } || []
    gifts.concat(guarded(:key_items) { restock_key_items(story, told) } || [])
    gifts.concat(guarded(:unlock_items) { restock_unlock_items(story, told) } || [])
    gifts.concat(guarded(:repair) { repair_rewards(story) } || [])
    guarded(:companions) { missing_companions(story, told, done) }
    guarded(:companion_values) { companion_values }
    guarded(:settle) { settle(story, world) }
    guarded(:warp_ban) { lift_warp_ban }
    guarded(:vehicles) { check_vehicles(story, world) }
    guarded(:held_items) { note_held_items }
    log("looked at everything the story owes the player once")
    tell_gifts(gifts.compact)
  end

  # The world's story while the player plays it, see audit.
  #
  # @return [Array, nil] The world's story, nil before it came or while the player is behind it.
  def self.played_world_story
    MGQ_MpWorldStory.mode == :world ? @world_told : nil
  end

  # Teaches Luka the story's skills he lacks, of the rows the player's story or the world's is past,
  # unless the row waits for its gate (rewards_wait?).
  #
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came or while the player is behind it,
  #   whose skills come as they move on.
  # @return [Array<String>] What was given, as shown.
  def self.missing_skills(story, told)
    hero = $game_actors[MGQ_MpStoryState::HERO]
    waits = ledger["waits"]
    DATA::REWARDS.map do |row|
      next unless row.kind == :skill && carries?(row) && !MGQ_MpStoryState.knows?(hero, row.id)
      next if waits[key_of("g", row)]
      next unless passed_any?(row, story, told)

      give(:skill, row.id, 1, key_of("g", row))
    end
  end

  # Looks at the skills, classes and races the story and its quests gave the roster's characters
  # every GROWTH_CHECKS looks, and at the next look after the roster changed, see missing_lessons
  # and missing_class_levels.
  def self.check_growth
    ids = MGQ_MpStoryState.roster_ids
    @growth_count += 1
    return unless @growth_count >= GROWTH_CHECKS || ids != @growth_roster

    @growth_count = 0
    @growth_roster = ids.dup
    story = story_now
    told = played_world_story
    tell_gifts((missing_lessons(story, told) + missing_class_levels(story, told)).compact)
  end

  # Teaches the companions of the player's roster the skills the story and its quests taught them,
  # of the rows the player's story or the world's is past. It goes by what each companion knows, so
  # a step passed before the world's last look, or a companion who joins after it, still counts.
  #
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came or while the player is behind it.
  # @return [Array<String>] What was taught, as shown.
  def self.missing_lessons(story, told)
    DATA::LESSONS.map do |row|
      next unless carries?(row) && in_roster?(row.actor)

      actor = $game_actors[row.actor]
      next if actor.nil? || MGQ_MpStoryState.knows?(actor, row.skill)
      next unless passed_any?(row, story, told)

      MGQ_MpStoryState.teach(row.actor, row.skill)
    end
  end

  # Gives the characters of the player's roster the classes and races the story and its quests gave
  # them, at their levels, of the rows the player's story or the world's is past, keeping the class
  # and race each plays now. It goes by each character's levels, so a step passed before the
  # world's last look, or a companion who joins after it, still counts.
  #
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came or while the player is behind it.
  # @return [Array<String>] What was given, as shown.
  def self.missing_class_levels(story, told)
    DATA::CLASS_LEVELS.map do |row|
      next unless carries?(row) && (row.actor == HERO || in_roster?(row.actor))

      actor = $game_actors[row.actor]
      next if actor.nil? || MGQ_MpStoryState.class_level(actor, row.class_id) >= row.level
      next unless passed_any?(row, story, told)

      MGQ_MpStoryState.give_class(row.actor, row.class_id, row.level)
    end
  end

  # Lets the story's companions the roster lacks join at their gate: of the joins the player's
  # story or the world's is past and whose event the rows tell ran, those no later removal of the
  # story took away, which the notes took as done.
  #
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came.
  # @param done [Hash] The rows done.
  def self.missing_companions(story, told, done)
    passes = lambda { |row| passed_any?(row, story, told) }
    story_joins.each do |row|
      key = key_of("j", row)
      next unless done[key] == true && row.part && carries?(row) && !in_roster?(row.actor) && passes.call(row)
      next if taken_away_since?(row, story, told)

      done[key] = "c"
      log("#{actor_label(row.persona)} of #{row.site} is missing from the roster: joins at level #{row.gate}")
    end
    bring_waiting(done)
  end

  # Reports whether a removal of the story after a join, which the player's story or the world's
  # got past, took the companion away again, for good or until a later join.
  #
  # @param row [MGQ_MpWorldCatchupData::Join] The join.
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came.
  # @return [Boolean] Whether one did.
  def self.taken_away_since?(row, story, told)
    DATA::REMOVALS.any? { |removal| removal.actor == row.actor && after?(removal, row) && passed_any?(removal, story, told) }
  end

  # Raises the story values of the companions in the player's roster to what their joins stand for
  # (COMPANION_VALUES), which a companion the world shared or the catch-up brought comes without.
  # The raised values reach the world's story like any change of the player's.
  def self.companion_values
    COMPANION_VALUES.each do |actor, values|
      next unless in_roster?(actor)

      values.each do |id, least|
        now = $game_variables[id].to_i
        next if now >= least

        $game_variables[id] = least
        log("raised variable #{id} from #{now} to #{least}: #{actor_label(actor)} is in the roster, whose join stands for it")
      end
    end
  end

  # Moves the player's own values the story's events set (DATA::SETTINGS: the game over's return
  # point, the random encounters) to what the latest step their story or the world's passed set,
  # where they still hold what an earlier step set: a story laid over theirs, or the opening's
  # setup, skipped the events. A value of their own making, such as a church they prayed at, stays,
  # and so do the encounters on a map whose events set them the other way now, and a variable of
  # the player's own away from the map of the event that sets it (see at_site?). Of the routes
  # only the rows of the route under way count, none at the Great Decision: a finished route's
  # rows, which passed? counts for its rewards, would set its last return point.
  #
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came or while the player is behind it.
  def self.settle(story, told)
    part = story_part(story)
    latest = {}
    earlier = Hash.new { |hash, key| hash[key] = [] }
    DATA::SETTINGS.each do |row|
      next if MGQ_MpWorldStory::ROUTES.include?(row.part) && row.part != part
      next unless passed_any?(row, story, told)

      key = [row.kind, row.id]
      earlier[key] << latest[key].value if latest[key]
      latest[key] = row
    end
    latest.each do |key, row|
      now = setting_now(row)
      next if now == row.value || !earlier[key].include?(now)
      next log_once([:own_encounters, $game_map.map_id], "left the random encounters to map #{$game_map.map_id}, whose event sets them the other way now") if row.kind == :encounters && map_sets_encounters?(row.value)
      next log_once([:elsewhere, row.site, $game_map.map_id], "left #{setting_label(row)} at #{now.inspect}: #{row.site} sets it where the player does not stand") unless at_site?(row)

      row.kind == :encounters ? $game_system.encounter_disabled = !row.value : $game_variables[row.id] = row.value
      log("set #{setting_label(row)} from #{now.inspect} to #{row.value.inspect}, as #{row.site} of the story left it")
    end
  end

  # Reports whether a setting of settle may apply where the player stands: the random encounters
  # anywhere, a variable of the player's own only on the map of the event that sets it.
  #
  # Such a variable tells a place, as where a game over returns the player, so a value the world's
  # story set elsewhere could send them into another player's scene with no way out.
  #
  # @param row [Struct] A row of DATA::SETTINGS.
  # @return [Boolean] Whether it may.
  def self.at_site?(row)
    return true unless row.kind == :v && MGQ_MpStoryState.personal_variable?(row.id)

    row.site.to_s =~ /\Amap:(\d+):/ && $1.to_i == $game_map.map_id ? true : false
  end

  # Reads a value of the player's own that the story sets, see settle.
  #
  # @param row [Struct] A row of DATA::SETTINGS.
  # @return [Object] Its value now: whether random encounters are on, or the variable's.
  def self.setting_now(row)
    row.kind == :encounters ? !$game_system.encounter_disabled : $game_variables[row.id]
  end

  # Names a value of the player's own that the story sets, for the log.
  #
  # @param row [Struct] A row of DATA::SETTINGS.
  # @return [String] Its name.
  def self.setting_label(row)
    row.kind == :encounters ? "the random encounters" : "variable #{row.id}"
  end

  # Reports whether an event of the player's map sets random encounters the other way: on the page
  # that applies now, as the story's values stand.
  #
  # Pages of an earlier step, such as the opening's, would otherwise keep the story's value away
  # for good.
  #
  # @param on [Boolean] Whether the story turns them on.
  # @return [Boolean] Whether one does.
  def self.map_sets_encounters?(on)
    $game_map.events.values.any? do |event|
      page = MGQ_MpGame.call(event, :find_proper_page)
      page && (page.list || []).any? { |command| command.code == ENCOUNTER_CODE && (command.parameters[0] != 0) != on }
    end
  end

  # Lifts the warp ban left on where the game lets the player warp (DATA::WARP_FREE_MAPS, as the
  # field), as a skipped event or a game over under an earlier return point left it.
  def self.lift_warp_ban
    return unless $game_switches[WARP_BAN] && DATA::WARP_FREE_MAPS.include?($game_map.map_id)

    $game_switches[WARP_BAN] = false
    log("lifted the warp ban: map #{$game_map.map_id} lets the player warp")
  end

  # Keeps the vehicles to the story: one that no event that gives it (DATA::VEHICLES) is behind the
  # player's story or the world's leaves its map (park_vehicle), one the story gave that stands on
  # no map comes back to its start (return_vehicle).
  #
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came or while the player is behind it.
  def self.check_vehicles(story, told)
    @vehicles_due = false
    VEHICLE_TYPES.each_with_index do |type, id|
      vehicle = $game_map.vehicle(type)
      next unless vehicle

      map_id = MGQ_MpGame.get(vehicle, :map_id).to_i
      given = DATA::VEHICLES.any? { |row| row.vehicle == id && passed_any?(row, story, told) }
      if given
        return_vehicle(type, vehicle) if map_id == 0
      elsif map_id != 0
        park_vehicle(type, vehicle, map_id)
      end
    end
  end

  # Takes a vehicle the story has not given yet off its map. A new game whose setup never ran keeps
  # the ship and Galda where the database parks them, on the field, and Galda flies anywhere. A
  # vehicle the player rides stays until they got off (got_off_early?), since taking it away midair
  # strands them.
  #
  # @param type [Symbol] The vehicle's type.
  # @param vehicle [Game_Vehicle] The vehicle.
  # @param map_id [Integer] The map it stands on.
  def self.park_vehicle(type, vehicle, map_id)
    if $game_player.vehicle.equal?(vehicle)
      @riding_early = true
      return log_once([:riding_early, type], "left the #{type} the story has not given yet while the player rides it")
    end
    vehicle.set_location(0, 0, 0)
    log("took the #{type} off map #{map_id}: no event that gives it is behind the story")
  end

  # Puts a vehicle the story gave that stands on no map where a new game parks it, the start the
  # database names for it, as a story laid over the player's gives Galda without the event that
  # lands the player on it.
  #
  # @param type [Symbol] The vehicle's type.
  # @param vehicle [Game_Vehicle] The vehicle.
  def self.return_vehicle(type, vehicle)
    return if $game_player.vehicle.equal?(vehicle)

    start = $data_system.send(type)
    map_id = start ? start.start_map_id.to_i : 0
    return log_once([:no_start, type], "left the #{type} the story gave on no map: the game names no start for it") if map_id == 0

    vehicle.set_location(map_id, start.start_x, start.start_y)
    log("put the #{type} back at its start on map #{map_id} (#{start.start_x},#{start.start_y}): the story gave it and it stood on no map")
  end

  # Reports whether the player got off a vehicle that park_vehicle left while they rode it, which
  # it then takes away at the next look.
  #
  # @return [Boolean] Whether they did.
  def self.got_off_early?
    return false unless @riding_early && !$game_player.vehicle

    @riding_early = false
    true
  end

  # Looks at every row of the tables against the player's story, see the module: rows the
  # player's own game played are noted done, those a story carried them past give their rewards,
  # or note them waiting for their gate after a move a cap opened (rewards_wait?), and take their
  # companions, the world's key items and chests come to everyone, and companions
  # whose gate the player reached join.
  #
  # @param story [Array] The player's story: switches, variables and self switches.
  # @param carried [Boolean] Whether a story laid over theirs just carried them past what is new.
  def self.review(story, carried)
    new_look
    note_side(story)
    done = ledger["done"]
    gifts = []
    waits = carried && rewards_wait? ? ledger["waits"] : nil
    DATA::REWARDS.each do |row|
      key = key_of("g", row)
      next if done[key] || (carried && !carries?(row)) || !passed?(row, story)

      done[key] = true
      next unless carried

      if waits
        waits[key] = ledger["capped"]
      else
        gifts << give(reward_kind(row), row.id, row.amount, key)
      end
    end
    gifts.concat(guarded(:world_items) { world_items(story, carried, done) } || [])
    guarded(:companions) { companions(story, carried, done) }
    guarded(:settle) { settle(story, played_world_story) } if carried
    tell_gifts(gifts.compact)
  end

  # Gives the world's key items and the items of its story chests, see the module. A key item row
  # the story passed only takes what it takes; what the rows give comes through
  # restock_key_items, which gives only what the player lacks, so nothing comes twice.
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
      mine = passed?(row, story)
      next unless mine || (told && passed?(row, told, story))

      done[key] = true
      give("i", row.item, row.amount, key) if row.amount < 0 && carries?(row) && (carried || !mine)
    end
    DATA::CHESTS.each do |row|
      key = key_of("c", row)
      next if done[key]

      mine = story[2][row.key] ? true : false
      next unless mine || (told && told[2][row.key])

      done[key] = true
      next unless carried || !mine

      row.items.each { |id| gifts << give("i", id, 1, key) }
      turn_on_flags(row, key)
      open_chest(row.key) unless mine
    end
    gifts.concat(restock_key_items(story, told))
    gifts.concat(restock_unlock_items(story, told))
  end

  # Hands out every key item the story owes the player by now and they hold fewer of: one a key
  # item row gives that the player's story or the world's is past, on the player's side, and that
  # no later row took back, up to the most such a row gives. Unlike the rows' ledger it goes by the
  # story's place alone, so a row added after the player's story passed it, or an event a story
  # laid over theirs skipped, as the Pocket Castle's handover, still gives the item.
  #
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came.
  # @return [Array<String>] What was given, as shown.
  def self.restock_key_items(story, told)
    owed = Hash.new(0)
    DATA::KEY_ITEMS.each do |row|
      next unless row.amount > 0 && passed_any?(row, story, told)
      next if taken_since?(row, story, story) || (told && taken_since?(row, told, story))

      owed[row.item] = [owed[row.item], row.amount].max
    end
    owed.map do |id, amount|
      item = MGQ_MpGame.item("i", id)
      missing = item ? amount - $game_party.item_number(item) : 0
      missing > 0 ? give("i", id, missing, "k:owed:#{id}") : nil
    end
  end

  # Hands out every item unlocking a job or a race a reward row gives whose own self switch tells
  # that the player's story or the world's ran its event, and that the player lacks. Like
  # restock_key_items it goes by the story's place alone, so a gift the rows' ledger noted done
  # without giving it, as the King of Remina's, still comes.
  #
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came.
  # @return [Array<String>] What was given, as shown.
  def self.restock_unlock_items(story, told)
    unlock_rows.map do |row|
      next unless passed_any?(row, story, told)

      item = MGQ_MpGame.item("i", row.id)
      item && $game_party.item_number(item) == 0 ? give("i", row.id, 1, "#{key_of('g', row)}:owed") : nil
    end
  end

  # The reward rows restock_unlock_items looks at: items unlocking a job or a race, given by an
  # event whose own self switch is among the row's marks.
  #
  # @return [Array<MGQ_MpWorldCatchupData::Reward>] The rows.
  def self.unlock_rows
    return [] unless $data_items

    @unlock_rows ||= DATA::REWARDS.select do |row|
      row.kind == :i && carries?(row) && own_switch_mark?(row) && unlock_item?(MGQ_MpGame.item("i", row.id))
    end
  end

  # Reports whether a row's marks hold a self switch of its own map event.
  #
  # @param row [Struct] The row.
  # @return [Boolean] Whether they do.
  def self.own_switch_mark?(row)
    kind, map, event = row.site.to_s.split(":")
    kind == "map" && row.marks.any? { |mark| mark[0] == :ss && mark[1] == map.to_i && mark[2] == event.to_i }
  end

  # The rewards the story trades away again, which repair_rewards never gives: the Fallen Sword
  # Angel Halo, which map 1075 event 35 takes for the weapon it gives.
  TRADED_REWARDS = [[:w, 4112]]

  # Gives once per save every item of a map event's reward row the player's story is past and the
  # rows' ledger noted done that the player holds none of, items unlocking a job or a race and
  # TRADED_REWARDS aside.
  #
  # Before 0.6.7.2 the catch-up failed between noting the rewards a story carried the player past
  # and giving them, so the ledger kept them noted done.
  #
  # @param story [Array] The player's story.
  # @return [Array<String>] What was given, as shown.
  def self.repair_rewards(story)
    notes = ledger
    return [] if notes["rewards_repaired"]

    notes["rewards_repaired"] = true
    DATA::REWARDS.map do |row|
      key = key_of("g", row)
      next unless row.kind != :skill && notes["done"][key] && !notes["waits"].key?(key) && carries?(row)
      next if TRADED_REWARDS.include?([row.kind, row.id])
      next unless row.site.to_s.start_with?("map:") && passed?(row, story)

      item = MGQ_MpGame.item(reward_kind(row), row.id)
      next if item.nil? || unlock_item?(item) || held?(item)

      give(reward_kind(row), row.id, row.amount, "#{key}:repaired")
    end
  end

  # Reports whether the party holds an item, in the bag or worn.
  #
  # @param item [RPG::BaseItem] The item.
  # @return [Boolean] Whether it does.
  def self.held?(item)
    return true if $game_party.item_number(item) > 0

    $game_party.all_members.any? { |actor| actor.respond_to?(:equips) && actor.equips.include?(item) }
  end

  # Reports whether a story took a key item after a row gave it: a row of a later part, a later row
  # of the same part, one of the same step whose marks lie further (see marks_beyond?), or one of the
  # same event and marks listed after it, that takes it. The routes share a rank, so a row of another
  # route never counts as later.
  #
  # @param row [MGQ_MpWorldCatchupData::KeyItem] The row that gives it.
  # @param told [Array] The story.
  # @param story [Array] The player's own story.
  # @return [Boolean] Whether it did.
  def self.taken_since?(row, told, story)
    DATA::KEY_ITEMS.any? do |other|
      next false unless other.item == row.item && other.amount < 0 && other.part && row.part
      later = if other.part != row.part then RANKS[other.part] > RANKS[row.part]
              elsif other.step.to_i != row.step.to_i then other.step.to_i > row.step.to_i
              elsif other.site == row.site && same_marks?(other, row) then listed_after?(other, row)
              else marks_beyond?(other, row)
              end
      later && passed?(other, told, story)
    end
  end

  # Reports whether two rows hold the same marks, in any order.
  #
  # @param row [Struct] The one.
  # @param other [Struct] The other.
  # @return [Boolean] Whether they do.
  def self.same_marks?(row, other)
    row.marks.sort_by(&:inspect) == other.marks.sort_by(&:inspect)
  end

  # Reports whether a key item row comes after another in KEY_ITEMS, which lists the rows that give
  # before those that take at one place.
  #
  # @param row [MGQ_MpWorldCatchupData::KeyItem] The one.
  # @param other [MGQ_MpWorldCatchupData::KeyItem] The other.
  # @return [Boolean] Whether it does.
  def self.listed_after?(row, other)
    DATA::KEY_ITEMS.index { |listed| listed.equal?(row) } > DATA::KEY_ITEMS.index { |listed| listed.equal?(other) }
  end

  # Reports whether a row's marks lie further than another's of the same step: each of the other's
  # marks is the row's too, a variable's at least as high, and they differ. Rows of one step, as
  # the Yggdrasil Fruit Nero gives and the Queen Harpy event takes, tell their order by them alone.
  #
  # @param row [Struct] The one.
  # @param other [Struct] The other.
  # @return [Boolean] Whether they do.
  def self.marks_beyond?(row, other)
    return false if same_marks?(row, other)

    other.marks.all? do |mark|
      row.marks.any? { |own| own == mark || (own[0] == :v && mark[0] == :v && own[1] == mark[1] && own[2] >= mark[2]) }
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

  # Lists what the catch-up hands out by level that the world already unlocked, for the World
  # overview's Unlocks page: moving on from each part the world is past, the companions the world's
  # story got past or the world shares, and every Makina, which only a level unlocks.
  #
  # @return [Array<Unlock>] By level, then kind and name; none outside a Raid World.
  def self.unlocks
    return [] unless active?

    list = []
    looking do
      new_look
      story = story_now
      list.concat(story_unlocks)
      list.concat(companion_unlocks(story, @world_told))
      list.concat(makina_unlocks)
    end
    list.sort_by { |unlock| [unlock.level, UNLOCK_KINDS.index(unlock.kind), unlock.name] }
  rescue => e
    log_once(:unlocks, "listing what the catch-up hands out failed: #{e.class}: #{e.message}")
    []
  end

  # Reads the level the catch-up counts: the highest base level among the player's characters.
  #
  # @return [Integer, nil] The level, nil without characters.
  def self.counted_level
    roster_view[:best]
  rescue
    nil
  end

  # Lists moving on from the parts before the world's, at each part's gate, and from a route the
  # world finished while the player is on it.
  #
  # @return [Array<Unlock>] The unlocks.
  def self.story_unlocks
    world = MGQ_MpWorldStory.world
    return [] unless world

    order = world_parts(world)
    current = world["part"].to_s
    own = own_part
    own_at = order.index(own)
    parts = order.take_while { |part| part != current }
    parts.select { |part| !MGQ_MpWorldStory::ROUTES.include?(part) || part == own }.map do |part|
      got = own_at.nil? || own_at > order.index(part)
      into = next_part(part, world)
      gains = gains_of(part, into == :world ? current : into, part == own)
      Unlock.new(gate_of(part), :story, part_name(part), nil, got, !got && gate_open?(gate_of(part)), nil, gains)
    end
  end

  # Lists what moving on from a part brings along: the key items and the story's and side quests'
  # rewards of the next part the world's story passed, and of the player's own part those their
  # story has not passed yet.
  #
  # @param part [String] The part moved on from.
  # @param into [String, nil] The part moved on to.
  # @param own [Boolean] Whether it is the player's part.
  # @return [Array<Gain>] Key items and unlocks first, then skills and items, each once with its amount.
  def self.gains_of(part, into, own)
    story = story_now
    told = @world_told
    carried = lambda do |row|
      next false unless carries?(row) && told

      (row.part == into && passed?(row, told, story)) || (own && row.part == part && passed?(row, told, story) && !passed?(row, story))
    end
    gains = {}
    add = lambda do |kind, id, amount|
      return if amount.to_i <= 0

      gain = gain_of(kind, id)
      return unless gain

      key = [gain.kind, gain.item_kind, id]
      gains[key] ? gains[key].amount += amount : gains[key] = gain.tap { |found| found.amount = amount }
    end
    DATA::KEY_ITEMS.each { |row| add.call("i", row.item, row.amount) if carried.call(row) }
    DATA::REWARDS.each { |row| add.call(row.kind == :skill ? :skill : row.kind.to_s, row.id, row.amount) if carried.call(row) }
    order = [:key, :unlock, :skill, :item]
    gains.values.sort_by { |gain| [order.index(gain.kind), gain.name] }
  end

  # Reads what an item or skill is, for gains_of.
  #
  # @param kind [Symbol, String] :skill, or the item's kind "i", "w" or "a".
  # @param id [Integer] The item or skill.
  # @return [Gain, nil] Without its amount; nil for one the game lacks.
  def self.gain_of(kind, id)
    if kind == :skill
      skill = $data_skills && $data_skills[id]
      return skill ? Gain.new(:skill, id, nil, 0, skill.name.to_s, skill.icon_index.to_i) : nil
    end

    item = MGQ_MpGame.item(kind, id)
    return nil unless item

    sort = if kind == "i" && item.respond_to?(:key_item?) && item.key_item?
             :key
           elsif item.description.to_s =~ UNLOCK_ITEM_TAG
             :unlock
           else
             :item
           end
    Gain.new(sort, id, kind, 0, item.name.to_s, item.icon_index.to_i)
  end

  # Lists the companions the catch-up brings at their gate: those of the joins the world's story
  # got past, at their earliest gate, unless a removal took them away since (see
  # missing_companions), and those the world shares that share_in still brings.
  #
  # @param story [Array] The player's story.
  # @param told [Array, nil] The world's story, nil before it came.
  # @return [Array<Unlock>] The unlocks.
  def self.companion_unlocks(story, told)
    gates = {}
    if told
      story_joins.each do |row|
        next unless row.part && carries?(row) && passed?(row, told, story) && !taken_away_since?(row, story, told)

        gates[row.actor] = [gates[row.actor], row.gate].compact.min
      end
    end
    sharing = MGQ_MpWorld.companion_sharing
    world = MGQ_MpWorldStory.world
    if sharing != :off && world
      done = ledger["done"]
      lost = taken_for_good(done)
      world["comps"].to_a.each do |id|
        next if !in_roster?(id) && (done["s:#{id}"] == SHARE_SETTLED || lost[id] || joined?(id, done))

        first = joins_of(id).first
        gate = first ? first.gate : (sharing == :all ? start_level(id) : nil)
        gates[id] = [gates[id], gate].compact.min if gate && id != HERO
      end
    end
    gates.map do |id, gate|
      got = in_roster?(id)
      Unlock.new(gate, :companion, actor_name(id), nil, got, !got && reached?(gate), id, [])
    end
  end

  # Lists every Makina a player of the world got at its level, see check_makina.
  #
  # @return [Array<Unlock>] The unlocks.
  def self.makina_unlocks
    DATA::MAKINA.map do |row|
      item = MGQ_MpGame.item("i", row.item)
      next unless item && found?(row.item)

      got = $game_party.item_number(item) > 0
      Unlock.new(row.level, :makina, item.name, item.respond_to?(:icon_index) ? item.icon_index : nil, got, !got && reached?(row.level), row.item, [])
    end.compact
  end

  # Hands out every Makina a player of the world got (see found?) whose level the player reached and
  # they lack (DATA::MAKINA), and takes back every copy of one beyond the first, which the game never
  # uses: a Raid World gives Makina by level, since a chest of one another player's story closed
  # again gave it twice.
  def self.check_makina
    DATA::MAKINA.each do |row|
      item = MGQ_MpGame.item("i", row.item)
      next unless item && !trim_copies(item)
      next unless $game_party.item_number(item) == 0 && found?(row.item) && reached?(row.level)

      @handing_makina = true
      begin
        give("i", row.item, 1, "makina:#{row.item} at level #{row.level}")
      ensure
        @handing_makina = false
      end
    end
  end

  # Reports whether a player of the world got an item, as gained notes it.
  #
  # @param id [Integer] The item.
  # @return [Boolean] Whether one did.
  def self.found?(id)
    $game_self_switches[[FOUND_MAP, id, FOUND_LETTER]] ? true : false
  end

  # Reports whether an item is a Makina, see DATA::MAKINA.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @return [Boolean] Whether it is.
  def self.makina?(item)
    @makina_ids ||= DATA::MAKINA.map { |row| row.item }
    item.is_a?(RPG::Item) && @makina_ids.include?(item.id)
  end

  # Takes back every copy of an item beyond the first, as a Makina or an item unlocking a job or a
  # race counts once.
  #
  # @param item [RPG::Item] The item.
  # @return [Boolean] Whether there were more.
  def self.trim_copies(item)
    held = $game_party.item_number(item)
    return false unless held > 1

    $game_party.lose_item(item, held - 1)
    log("took #{item.name} x#{held - 1}: it counts once")
    true
  end

  # The map of the self switches [FOUND_MAP, item, FOUND_LETTER] that tell which items unlocking a
  # job or a race, and which Makina, a player of the world got.
  #
  # No map has the id 0, so no event reads them, and they go with the world's story as any other
  # self switch.
  FOUND_MAP = 0

  # The letter of the self switches that tell which items unlocking a job or a race a player of the
  # world got, see FOUND_MAP.
  FOUND_LETTER = "F"

  # Notes an item unlocking a job or a race, or a Makina, the player gained as found for the world, so
  # every other player gets it too; a Makina only by level, and not one the catch-up hands out
  # itself.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @param amount [Integer] How many.
  def self.gained(item, amount)
    return unless amount.to_i > 0 && active? && (unlock_item?(item) || (makina?(item) && !@handing_makina))

    key = [FOUND_MAP, item.id, FOUND_LETTER]
    return if $game_self_switches[key]

    $game_self_switches[key] = true
    log("noted #{item.name} as found for the world")
  rescue => e
    log_once(:found, "noting a found item failed: #{e.class}: #{e.message}")
  end

  # Notes every item unlocking a job or a race and every Makina the player holds as found for the
  # world, as gained does for one they get, so one got before the world noted it still reaches the
  # other players.
  def self.note_held_items
    @unlock_items ||= ($data_items || []).select { |item| unlock_item?(item) || makina?(item) }
    @unlock_items.each { |item| gained(item, 1) if $game_party.item_number(item) > 0 }
  end

  # Reports whether an item unlocks a job or a race.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @return [Boolean] Whether it does.
  def self.unlock_item?(item)
    item.is_a?(RPG::Item) && item.description.to_s =~ UNLOCK_ITEM_TAG ? true : false
  end

  # Hands out every item unlocking a job or a race a player of the world found that the player
  # lacks, at once, wherever their story is, and takes back copies beyond the first, as a chest of
  # one gives a second.
  def self.check_found_items
    found_ids.each do |id|
      item = MGQ_MpGame.item("i", id)
      next unless item && !makina?(item) && !trim_copies(item) && $game_party.item_number(item) == 0

      give("i", id, 1, "found:#{id}")
    end
  end

  # Lists the items the world found: those noted in the player's story and in the world's, which a
  # player behind it does not play.
  #
  # @return [Array<Integer>] The items.
  def self.found_ids
    stories = [MGQ_MpStoryState.data_of($game_self_switches)]
    stories << @world_told[2] if @world_told
    keys = stories.flat_map { |selfs| selfs.keys.select { |key| selfs[key] && key[0] == FOUND_MAP && key[2] == FOUND_LETTER } }
    keys.map { |key| key[1] }.uniq
  end

  # Turns on the chest flags a world-wide chest turns on, which are each player's own: the Chaos
  # forge asks for "Carrying Moonbow Crystal" (7102) rather than the ore it gave.
  #
  # @param row [MGQ_MpWorldCatchupData::Chest] The chest.
  # @param key [String] Its row, for the log.
  def self.turn_on_flags(row, key)
    Array(row.flags).each do |id|
      next if $game_switches[id]

      $game_switches[id] = true
      log("turned on s#{id} of #{key}")
    end
  end

  # Sets each variable of COUNTS to how many of its switches are on.
  def self.check_counts
    COUNTS.each do |variable, switches|
      count = switches.count { |id| $game_switches[id] }
      next if $game_variables[variable] == count

      log("set v#{variable} from #{$game_variables[variable].inspect} to #{count}, the switches it counts")
      $game_variables[variable] = count
    end
  end

  # Shows a world-wide chest the world opened as open in the player's story too, so it gives
  # nothing twice.
  #
  # @param key [Array] Its self switch: map, event and letter.
  def self.open_chest(key)
    MGQ_MpStoryState.data_of($game_self_switches)[key] = true
    $game_map.need_refresh = true if $game_map
  end

  # Logs what the story gave the player at once.
  #
  # No notice tells it, as one look can give more than a notice lists.
  #
  # @param gifts [Array<String>] What was given, as shown.
  def self.tell_gifts(gifts)
    log("the story gave the player #{gifts.join(', ')}") unless gifts.empty?
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
    story_joins.each do |row|
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
    story_joins.each do |row|
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
    companion_values
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
    return false if in_roster?(main) || visit_running?(main)

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

  # Reports whether the map event page running brings a companion along on a visit only (see
  # temporary?), which the catch-up never holds back: such an event may insist on them, as the
  # Arena's final (map 483, event 86) adds Alma Elma again until she is in the party.
  #
  # Only the running page counts: Red Mountain's Queen Bee (map 134, event 34) brings Miria along on
  # page 2 and recruits her for good on page 4.
  #
  # @param main [Integer] The companion's main persona.
  # @return [Boolean] Whether it does.
  def self.visit_running?(main)
    site = running_page_site
    site ? DATA::JOINS.any? { |row| row.actor == main && row.site == site && temporary?(row) } : false
  end

  # Names the map event page the map's interpreter runs as the catch-up data's sites do.
  #
  # The page is found by its list, which the interpreter keeps while the event's shown page changes.
  #
  # @return [String, nil] The site, such as "map:134:34:4", nil while no map event runs.
  def self.running_page_site
    interpreter = $game_map && $game_map.interpreter
    event_id = interpreter ? interpreter.event_id.to_i : 0
    event = event_id > 0 ? $game_map.events[event_id] : nil
    return nil unless event

    list = MGQ_MpGame.get(interpreter, :list)
    page = event.mgq_mp_pages.index { |candidate| candidate.list.equal?(list) }
    page ? "map:#{$game_map.map_id}:#{event_id}:#{page + 1}" : nil
  end

  # Lists the story's joins the catch-up goes by: those that last, see temporary?.
  #
  # @return [Array<MGQ_MpWorldCatchupData::Join>] The joins, in the story's order.
  def self.story_joins
    @story_joins ||= DATA::JOINS.reject { |row| temporary?(row) }
  end

  # Reports whether a join only brings its companion along for a visit: a removal of the story takes
  # them away again in the same step (see takes_back?), unless they are one of LASTING_COMPANIONS.
  # The catch-up neither lists nor gives such a companion, and they count toward no level.
  #
  # @param row [MGQ_MpWorldCatchupData::Join] The join.
  # @return [Boolean] Whether it does.
  def self.temporary?(row)
    !taking_back(row).empty?
  end

  # Lists the removals that take a join's companion away again, see takes_back?.
  #
  # @param row [MGQ_MpWorldCatchupData::Join] The join.
  # @return [Array<MGQ_MpWorldCatchupData::Removal>] The removals; none for one of LASTING_COMPANIONS.
  def self.taking_back(row)
    @taking_back ||= {}.compare_by_identity
    @taking_back[row] ||= LASTING_COMPANIONS.include?(row.actor) ? [] : DATA::REMOVALS.select { |removal| takes_back?(removal, row) }
  end

  # Reports whether a removal takes a join's companion away again in the same step of the story:
  # later in the same event, or in an event whose marks lie further, on the same side.
  #
  # @param removal [MGQ_MpWorldCatchupData::Removal] The removal.
  # @param row [MGQ_MpWorldCatchupData::Join] The join.
  # @return [Boolean] Whether it does.
  def self.takes_back?(removal, row)
    return false unless removal.actor == row.actor && removal.part == row.part && removal.step == row.step
    return false if removal.side && row.side && removal.side != row.side

    removal.site == row.site ? removal.index.to_i > row.index.to_i : marks_beyond?(removal, row)
  end

  # Reports whether a companion is in the player's roster on a visit only: their own story passed a
  # temporary join of theirs (see temporary?) and none of the removals that take them away again yet.
  #
  # @param id [Integer] The companion's main persona.
  # @param story [Array] The player's story.
  # @return [Boolean] Whether they are.
  def self.visiting?(id, story)
    @visits ||= DATA::JOINS.select { |row| row.part && temporary?(row) }.group_by { |row| row.actor }
    Array(@visits[id]).any? { |row| passed?(row, story) && taking_back(row).none? { |removal| passed?(removal, story) } }
  end

  # Reports whether a character counts in the catch-up, toward the player's level and in the
  # catch-up experience: one of their own roster, not a story's temporary party, and not on a visit
  # (see visiting?).
  #
  # @param actor [Game_Actor] The character.
  # @return [Boolean] Whether they do.
  def self.counts?(actor)
    main = MGQ_MpStoryState.main_id(actor.id)
    MGQ_MpStoryState.roster_ids.include?(main) && !visiting?(main, story_now)
  rescue
    true
  end

  # Lists the story's joins of a companion.
  #
  # @param actor [Integer] The companion's main persona.
  # @return [Array<MGQ_MpWorldCatchupData::Join>] The joins that last, in the story's order.
  def self.joins_of(actor)
    unless @joins_by_actor
      @joins_by_actor = {}
      story_joins.each { |row| (@joins_by_actor[row.actor] ||= []) << row if row.part }
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
  # sharing is on: the story's companions, every one with battle recruits shared too. A companion
  # on a visit (see visiting?) is noted only once they stay.
  def self.note_roster
    story = story_now
    ids = MGQ_MpStoryState.roster_ids.reject { |id| visiting?(id, story) }
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
      next if id == HERO || done[key] == SHARE_SETTLED

      lost ||= taken_for_good(done)
      next done[key] = SHARE_SETTLED if in_roster?(id) || lost[id] || joined?(id, done)

      first = joins_of(id).first
      next unless first || sharing == :all

      gate = first ? first.gate : start_level(id)
      next unless reached?(gate)

      done[key] = SHARE_SETTLED
      bring_in(first ? first.persona : id, first && first.rule != START_RULE ? gate : nil, "shared by the world")
    end
  end

  # Reports whether the player's story got past a join of a companion, which gave them the companion
  # whether or not they are in the roster now: a temporary removal of the story or the player may have
  # let them go since. A join whose marks never tell that it ran, as a talk the player may decline,
  # gave nothing by being walked past.
  #
  # @param id [Integer] The companion's main persona.
  # @param done [Hash] The rows done.
  # @return [Boolean] Whether it did.
  def self.joined?(id, done)
    joins_of(id).any? { |row| carries?(row) && done[key_of("j", row)] == true }
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

  # A level up may reach a gate: the catch-up looks at everything once.
  MGQ_MpHooks.after(Game_Actor, :level_up, "world_catchup") { MGQ_MpWorldCatchup.level_up }
rescue => e
  MGQ_MpWorldCatchup.log("hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # An item unlocking a job or a race the player gets is the world's.
  MGQ_MpHooks.after(Game_Party, :gain_item, "world_catchup") { |item, amount, *_| MGQ_MpWorldCatchup.gained(item, amount) }

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
