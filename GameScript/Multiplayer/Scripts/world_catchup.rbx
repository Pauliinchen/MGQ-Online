#----------------------------------------------------------------
#  world_catchup.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Read the story's ids from story_ids.rbx
#                            - Settled a variable the game uses as a place only on the map of the event that sets it, by the one place rule
#                            - Left found key items and their uses to the story replay, and noted only a Makina as found for the world, which Makina by level reads
#                            - Told the DLL whether a replay hands out a companion, with the world's companion sharing and the companion's start level
#                            - Held a companion of a replay that went the player's own way back for the join's gate, as an own event's
#      Paulinchen  2026-11-01: Noted every key item the player gains as found for the world too, and handed the DLL the items the save held
#                            - Noted the found items the catch-up gave, whose next gain adds nothing
#                            - Noted each use of a key item by an event of the player's game for the world, and took a copy of each item another player's event used up
#                            - Left out a join of a companion of the Alice and Ilias choice the player has no right to, in the player's own events and in replays, and in a Classic party through coop_story.rbx
#                            - Took such a companion away once the DLL found the player never had a right to them
#                            - Asked a player on a route whom they take along without setting the side switches, which tell the route there
#                            - Handed the DLL the side the save notes the player took along in Iliasville, which tells a save of another player's starting save
#      Paulinchen  2026-10-31: Waited for a lost raid boss battle's defeat by the world's story's hold
#                            - Stopped handing the DLL the player's map, which only the lift of a warp ban read
#                            - Handed the DLL the world's story where its log starts, and left a vehicle only the log holds in place
#                            - Played a world chest and a Makina by level in the player's game, through story_replay.rbx
#      Paulinchen  2026-10-28: Handed the DLL a snapshot of the story, party and items and carried out the catch-up it decides
#                            - Read the rules, counts and companion values of the catch-up from the story mapping the DLL holds
#                            - Kept the tables built from the rows until the rules come anew
#      Paulinchen  2026-10-24: Gave every player the prizes another player claimed, as the Reaper's Battle Challenge's
#                            - Lifted a warp ban left on where warping is free at every check
#                            - Counted Alice's Power-up from the switches of its steps
#                            - Ran what the power-ups of the story change of the characters for a player a story carried past them
#                            - Turned a companion of the roster into the persona a join of theirs brings, unless a later change of the story set another
#      Paulinchen  2026-10-23: Followed the relay's tracks, which put a player behind on their part's checkpoint and move them on by their level, in place of fetching and laying over checkpoints
#                            - Gave job and race items another player found to every player of the world at once
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

# A Raid World's catch-up, on the story of world_story.rbx. What the story owes a player is decided
# in the DLL (CatchupEngine of MGQOnline.Game, topics catchup.*) over the catch-up's tables the relay
# keeps beside the story mapping; this script hands it a snapshot of the player's story, party and
# items, and carries out the actions it answers with the game's own grants.
#
# A player whose story is in an earlier part than the world's is behind (MGQ_MpWorldStory.mode
# :behind): the relay puts them on a track of their own at the checkpoint of their part, the world
# as it was right before that part's ending, and while behind they start no story event that would
# move them past that ending (coop_events.rbx asks holds_story?). Once the highest base level of
# their characters reaches their part's gate, the relay moves them straight into the next part: its
# checkpoint while the world is past it, else the world's own story. A player whom another mod caps
# below the gate is moved on once at that cap.
#
# What the story gives goes by its place in the story, never by what another player holds, once per
# save, which keeps the notes the DLL writes (ledger): the story's skills and items, its companions
# at their gates, the world's key items and chests, the skills, classes and races the story teaches
# the roster, what its power-ups change of the characters, the player's own values it sets and the
# vehicles it gave. The rows give only the history the world's story was past where its log starts;
# the world's track replays the runs after it. Makina by level and the companions a player missed
# once a route finished come by playing their page in the player's game (story_replay.rbx). A key
# item or an item unlocking a job or a race that any player's event gave or used up comes with the
# replay of that run (story_keys.rbx).
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldCatchup
  # The topic that lists what the snapshot reads, see CatchupTopics in the DLL.
  KEYS_TOPIC = "catchup.keys"

  # The topic of one look at the player's story.
  CHECK_TOPIC = "catchup.check"

  # The topic of a note of the world's story for the save's notes.
  NOTE_TOPIC = "catchup.note"

  # The topic that tells whether a companion the player's own event hands out waits for its gate.
  HOLD_TOPIC = "catchup.hold_join"

  # The topic of what the catch-up hands out by level, for the World overview.
  UNLOCKS_TOPIC = "catchup.unlocks"

  # The event command that turns random encounters off (its parameter 0) or on.
  ENCOUNTER_CODE = 136

  # The game's vehicles by the number the DLL's answers name them.
  VEHICLE_TYPES = [:boat, :ship, :airship]

  # Frames between two looks at the player's story, half a second.
  CHECK_FRAMES = 30

  # Frames between two reads of the DLL's state while an addition of shared companions runs, a
  # quarter of a second.
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

  # Frames a notice of the catch-up shows, five seconds.
  NOTICE_FRAMES = 300

  # Luka, who never joins nor leaves.
  HERO = 1

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

  # The order the gains of a move on are listed in.
  GAIN_ORDER = [:key, :unlock, :skill, :item]

  # The tag at the start of an item's description that tells it unlocks a job or a race, in the
  # translation and the untranslated game.
  UNLOCK_ITEM_TAG = /\A\s*[\[［](Job|Race|職業|種族)/

  # The game's script calls an actor change of the DLL's answers may name, which alone run.
  ACTOR_CALLS = [:persona_change, :level_adjust, :change_actor_ability, :force_change_equip, :change_actor_equip_stone, :set_actor_had]

  # The kinds of worn items force_change_equip names, by its number, as MGQ_MpGame.item names them.
  EQUIP_KINDS = { 1 => "w", 2 => "a" }

  # Whole numbers a call shows at most in the log; the abilities of a power-up run to dozens.
  LOGGED_NUMBERS = 6

  # The field of $game_system the save keeps the DLL's notes in, see ledger.
  LEDGER = :@mgq_mp_catchup

  # The map of the self switches [FOUND_MAP, item, FOUND_LETTER] that tell which Makina a player of
  # the world got, which every player gets by level (check_makina in the DLL).
  #
  # No map has the id 0, so no event reads them, and they go with the world's story as any other
  # self switch.
  FOUND_MAP = 0

  # The letter of the self switches that tell which items a player of the world got, see FOUND_MAP.
  FOUND_LETTER = "F"

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "catch-up"

  # Forgets what this session knew of the world: the shared companions, the world's story and the
  # looks due. The notes in the save stay, and go to the DLL again with the next call.
  def self.forget
    @world_id = nil
    @world_told = nil
    @known_roster = nil
    @growth = nil
    @share_queue = []
    @adding = nil
    @share_at = 0
    @orbs_due = false
    @orbs_now = false
    @orbs_played = false
    @asking_side = false
    @audit_due = true
    @riding_early = false
    @vehicles_due = false
    @watched = nil
    @visiting = []
    @ledger_sent = false
    @clock ||= 0
    @checked = @clock
    @state_read = @clock
  end

  forget

  # Lists what a snapshot reads, as the DLL wrote it from the story mapping's catch-up tables, once
  # per revision of the mapping: "switches", "variables" and "selves" (the keys of the story),
  # "items" (each "i<id>", "w<id>" or "a<id>"), "makina" (their items), "parts" ([id, name, gate]
  # each), "side_companions" ({"alice", "ilias"}) and "orb_event".
  #
  # @return [Hash, nil] The keys; nil before the story mapping came.
  def self.keys
    table = MGQ_MpStoryKeys.raid_table
    return nil unless table
    return @keys if @keys && @keys_rev == table.rev

    found = MGQ_Multiplayer::Bridge.call(KEYS_TOPIC)
    return @keys unless found.is_a?(Hash)

    @keys = found
    @keys_rev = table.rev
    @tested = nil
    log("read what the catch-up reads at revision #{table.rev}: #{found['switches'].size} switch(es), #{found['variables'].size} variable(s), " \
        "#{found['selves'].size} self switch(es), #{found['items'].size} item(s)")
    @keys
  end

  # Reports whether the catch-up applies: a Raid World's story is followed, see
  # MGQ_MpWorldStory.active?.
  #
  # @return [Boolean] Whether it does.
  def self.active?
    MGQ_MpWorldStory.active?
  end

  # Reports whether the player's story is held to their part: their story is behind the world's, or
  # their save noted them behind in their part while the world's story has not come since the save
  # loaded or the world opened, so a part's ending held on the map never starts before the relay
  # answers. coop_events.rbx then keeps every story event that would end the part from starting.
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

  # Tells the player why their story event did not start.
  #
  # @return [String] The notice.
  def self.refusal_text
    "Reach level #{level_to_reach(own_part)} to continue the story."
  end

  # Tells the player they are behind the world's story.
  #
  # @param part [String] The part of their track.
  # @return [String] The notice.
  def self.behind_text(part)
    "The world's story is further than yours. You see the world as it was before the end of #{part_name(part)}; reach level #{level_to_reach(part)} to move on."
  end

  # Follows the catch-up for one frame: the relay's answer to shared companions and the orbs' event
  # that waits, then every CHECK_FRAMES while the player is free one look of the DLL at their story
  # (see look). Called after the map's update. Nothing goes on while a lost raid boss battle's
  # defeat runs, which takes items its undo gives back: a restock meanwhile would give them twice
  # (see MGQ_MpWorldStory.holding?).
  def self.tick
    @clock += 1
    return close unless active?
    return if MGQ_MpWorldStory.holding?

    note_world
    read_shared if @adding && @clock - @state_read >= STATE_FRAMES
    play_orb_event if @orbs_due
    return if @clock - @checked < CHECK_FRAMES || !MGQ_MpWorldStory.quiet?

    @checked = @clock
    return if MGQ_MpWorldStory.mode.nil?
    return log_once(:keys, "the catch-up waits for the story mapping") if keys.nil?

    carry_watched
    @audit_due = true if got_off_early?
    look
    send_shared
  rescue => e
    log_once(:tick, "following the catch-up failed: #{e.class}: #{e.message}")
  end

  # Has the DLL look at the player's story once and carries out its answer: everything the story
  # owes once when an audit is due (on entering, after a load, on a level up), the vehicles after a
  # story written into the player's, else the rows new since, the rewards waiting for their gate,
  # the roster's skills, classes and races, the shared companions, the Makina, the missed companions
  # and the counts.
  def self.look
    note_held_items if @audit_due
    audit = @audit_due
    vehicles = !audit && @vehicles_due
    answer = call(CHECK_TOPIC, snapshot.merge("look" => "tick", "audit" => audit, "vehicles" => vehicles, "growth" => @growth))
    return unless answer

    @audit_due = false
    @vehicles_due = false if audit || vehicles
    @growth = answer["growth"]
    apply(answer)
    ask_side(answer["ask_side"])
    note_roster(Array(answer["sharable"]))
    note_orbs(answer["orbs"])
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

  # Has the save's notes go to the DLL again with its next call, as after a load.
  def self.hand_ledger
    @ledger_sent = false
  end

  # The story the game keeps now, read in place.
  #
  # @return [Array] The switches, variables and self switches, the game's own data.
  def self.story_now
    [MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables), MGQ_MpStoryState.data_of($game_self_switches)]
  end

  # The notes the save keeps of the open world, as the DLL wrote them (CatchupLedger): the rows
  # done, the companions held back, the checkpoint taken, the side chosen before the Great Decision,
  # the gate a cap of another mod opened and the rewards waiting for it.
  #
  # @return [Hash] The notes; empty for none of the open world.
  def self.ledger
    notes = $game_system.instance_variable_get(LEDGER)
    notes.is_a?(Hash) && notes["world"] == MGQ_MpWorldStory.world_id ? notes : {}
  end

  # The part the player's story is in.
  #
  # @return [String] See MGQ_MpWorldStory.part_of.
  def self.own_part
    MGQ_MpWorldStory.part_of(MGQ_MpWorldStory.local_counters(story_now))
  end

  # Finds a part of the story mapping's catch-up tables.
  #
  # @param id [String] The part, as the relay names it.
  # @return [Array, nil] Its id, name and gate; nil for none.
  def self.part(id)
    found = keys
    found ? found["parts"].find { |entry| entry[0] == id } : nil
  end

  # The level that moves a player on from a part.
  #
  # @param id [String] The part.
  # @return [Integer, nil] Its gate, the last part's for one the tables lack; nil before the mapping.
  def self.gate_of(id)
    entry = part(id) || (keys && keys["parts"].last)
    entry && entry[2]
  end

  # The level a part's gate asks of the player: the gate, or the cap another mod holds them at
  # below it, which opens the gate too.
  #
  # @param id [String] The part.
  # @return [Integer] The level.
  def self.level_to_reach(id)
    gate = gate_of(id)
    cap = roster_view[:cap]
    gate && cap.is_a?(Integer) && cap < gate ? cap : gate
  rescue
    gate_of(id)
  end

  # What the notices call a part.
  #
  # @param id [String] The part.
  # @return [String] Its name.
  def self.part_name(id)
    entry = part(id)
    entry ? entry[1] : "Part #{id}"
  end

  # Takes the player behind the world's story, on a track of their own at the checkpoint of their
  # part, which the relay put them on (see world_story.rbx): the save notes it, see noted_behind?.
  #
  # @param part [String] The part of their track.
  # @param gate [Integer, nil] The level gate of that part, as the relay tells it.
  def self.behind(part, gate)
    note("checkpoint" => part)
    log("the player plays a track of their own in #{part_name(part)} until level #{gate || gate_of(part)} moves them on")
  end

  # Keeps the world's story written into the player's, for the key items and chests it gave, and
  # clears the save's note that the player is behind, see noted_behind?. Called by world_story.rbx.
  #
  # @param told [Array, nil] The world's story, nil while the player plays a track of their own.
  def self.world_told(told)
    @world_told = told && keys ? values(told) : nil
    note("checkpoint" => nil) if told && active? && ledger["checkpoint"]
  end

  # Follows the relay moving the player on from their part by their level: the notice, the rewards
  # that wait while only a cap of another mod opened the gate, and the personal half of the world's
  # return to the Great Decision when they leave a route the world finished. Called by
  # world_story.rbx before the track the move led to is followed.
  #
  # @param move [Hash] "from", "to" (a part or "world"), "gate" and "by" ("level" or "cap").
  # @param world [Hash, nil] The world's summary, see MGQ_MpWorldStory.world.
  def self.moved(move, world)
    from = move["from"].to_s
    to = move["to"].to_s
    gate = (move["gate"] || gate_of(from)).to_i
    name = to == MGQ_MpWorldStory::WORLD_TRACK ? "the world's story" : part_name(to)
    log("level #{gate} reached in #{part_name(from)}#{move['by'] == 'cap' ? ' by the level cap' : ''}: the relay moved the player on to #{name}")
    notice(:gate, "Level #{move['by'] == 'cap' ? level_to_reach(from) : gate} reached: catching up to #{name}.")
    note("capped" => gate)
    return_from_route(from, world) if world
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

  # Follows a story written into the player's: the DLL counts what their own game played before as
  # theirs and gives what the story carried them past, and the next look follows the vehicles.
  # Called by world_story.rbx and coop_choices.rbx.
  #
  # @param before [Array] The player's story before: switches, variables and self switches.
  def self.carried(before)
    return unless active? && keys

    # The story before a telling the player watched is older, and the telling's values count as laid
    # over too, see watched.
    before = @watched || values(before)
    @watched = nil
    @vehicles_due = true
    answer = call(CHECK_TOPIC, snapshot.merge("look" => "carried", "before" => before))
    apply(answer) if answer
  rescue => e
    log("following a story laid over the player's failed: #{e.class}: #{e.message}")
  end

  # Keeps the player's story from before a teller's story values first moved it while they watch a
  # telling, until the player is free again (see carry_watched). Called before the values are
  # written, see MGQ_MpCoopScene.apply_values.
  #
  # @yieldreturn [Array] A copy of the player's story now.
  def self.watched
    @watched ||= values(yield) if active? && keys
  end

  # Follows the story values a watched telling laid over the player's as a story laid over theirs,
  # since only the teller's game ran the scene's commands.
  def self.carry_watched
    return unless @watched

    log("following the story values of a telling the player watched")
    carried(nil)
  end

  # What the DLL's catch-up reads of the player's game: the story's values it reads, the world's
  # story laid over theirs, the roster, the items and what the game's data tells of them.
  #
  # @return [Hash] The snapshot, see CatchupTopics in the DLL.
  def self.snapshot
    world = MGQ_MpWorldStory.world
    sharing = MGQ_MpWorld.companion_sharing
    comps = world ? world["comps"].to_a : []
    {
      "mode" => MGQ_MpWorldStory.mode ? MGQ_MpWorldStory.mode.to_s : nil, "own" => keys ? values(story_now) : nil, "told" => @world_told, "roster" => roster_entries,
      "items" => item_counts, "worn" => worn_items, "unlocks" => unlock_ids, "pick" => pick_now,
      "encounters" => !$game_system.encounter_disabled, "summary" => world, "sharing" => sharing.to_s, "starts" => comps.map { |id| [id, start_level(id)] },
      "log" => (log = MGQ_MpWorldStory.log_story) && keys ? values(log) : nil,
    }
  end

  # Reads the side the save notes the player took along in Iliasville, noting it from the story they
  # play first, see MGQ_MpStoryState.own_pick.
  #
  # @return [String, nil] See MGQ_MpStoryState::PICK_FIELD.
  def self.pick_now
    story = story_now
    MGQ_MpStoryState.own_pick(story[0], story[1])
    MGQ_MpStoryState.pick_note
  end

  # Reads the values of a story the DLL's catch-up reads (see keys): the switches and self switches
  # on and the variables set to a number, with the self switches of the Makina found.
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [Hash] "s" (the switches on), "v" ([id, value] each) and "ss" (the self switches on).
  def self.values(story)
    tested = tested_keys
    switches = tested[0].select { |id| story[0][id] }
    # A Float goes as its floor, which holds a mark at a whole number exactly when the Float does.
    variables = tested[1].map { |id| (value = whole(story[1][id])) ? [id, value] : nil }.compact
    selves = tested[2].select { |key| story[2][key] }
    story[2].each { |key, on| selves << key if on && key[0] == FOUND_MAP && !tested[3][key] }
    { "s" => switches, "v" => variables, "ss" => selves }
  end

  # The keys the snapshot reads, kept per revision of the mapping.
  #
  # @return [Array] The switches, the variables, the self switches and the self switches by key.
  def self.tested_keys
    @tested ||= begin
      found = keys
      selves = {}
      found["selves"].each { |key| selves[key] = true }
      [found["switches"], found["variables"], found["selves"], selves]
    end
  end

  # Reads a story value as a whole number for the DLL.
  #
  # @param value [Object] The value.
  # @return [Integer, nil] The number; nil for one that is none.
  def self.whole(value)
    return value if value.is_a?(Integer)

    value.is_a?(Float) && value.finite? ? value.floor : nil
  end

  # Lists the roster as the DLL's catch-up reads it.
  #
  # @return [Array<Array>] Each companion's id, persona, base level and the highest level the game
  #   lets them reach (nil for none).
  def self.roster_entries
    MGQ_MpStoryState.roster_ids.map do |id|
      actor = $game_actors[id]
      next nil unless actor

      cap = actor.respond_to?(:max_level) ? actor.max_level(:base) : nil
      [id, actor.id, actor.base_level, cap.is_a?(Integer) ? cap : nil]
    end.compact
  end

  # Counts the items the DLL's catch-up reads (see keys) and those that unlock a job or a race that
  # the game has.
  #
  # @return [Hash{String => Integer}] The counts by "i<id>", "w<id>" or "a<id>".
  def self.item_counts
    counts = {}
    ((keys ? keys["items"] : []) + unlock_ids.map { |id| "i#{id}" }).each do |key|
      next if counts.key?(key)

      item = MGQ_MpGame.item(key[0, 1], key[1..-1].to_i)
      counts[key] = $game_party.item_number(item) if item
    end
    counts
  end

  # Lists the weapons and armors the party wears.
  #
  # @return [Array<String>] Each "w<id>" or "a<id>".
  def self.worn_items
    $game_party.all_members.flat_map do |actor|
      actor.respond_to?(:equips) ? actor.equips.compact.map { |item| worn_key(item) } : []
    end.compact.uniq
  end

  # Names a worn item as the counts do.
  #
  # @param item [RPG::EquipItem] The item.
  # @return [String, nil] "w<id>" or "a<id>"; nil for neither.
  def self.worn_key(item)
    return "w#{item.id}" if defined?(RPG::Weapon) && item.is_a?(RPG::Weapon)
    return "a#{item.id}" if defined?(RPG::Armor) && item.is_a?(RPG::Armor)

    nil
  end

  # Lists the items of the game that unlock a job or a race, see unlock_item?.
  #
  # @return [Array<Integer>] The items.
  def self.unlock_ids
    @unlock_ids ||= ($data_items || []).select { |item| unlock_item?(item) }.map { |item| item.id }
  end

  # Calls a catch-up topic of the DLL with the open world and, once after a load, the save's notes,
  # and keeps the notes it answers.
  #
  # @param topic [String] The topic.
  # @param request [Hash] The request.
  # @return [Hash, nil] The answer; nil when the DLL failed.
  def self.call(topic, request)
    request = request.merge("world" => MGQ_MpWorldStory.world_id)
    request["ledger"] = $game_system.instance_variable_get(LEDGER) unless @ledger_sent
    answer = MGQ_Multiplayer::Bridge.call(topic, request)
    return nil unless answer.is_a?(Hash)

    @ledger_sent = true
    $game_system.instance_variable_set(LEDGER, answer["ledger"]) if answer["ledger"]
    answer
  end

  # Writes a note of the world's story into the save's notes, through the DLL.
  #
  # @param request [Hash] The note, see CatchupTopics in the DLL.
  def self.note(request)
    answer = call(NOTE_TOPIC, snapshot.merge(request))
    run(answer["actions"]) if answer
  end

  # Carries out what a look answered and keeps the companions on a visit it names.
  #
  # @param answer [Hash] The answer.
  def self.apply(answer)
    run(answer["actions"])
    @visiting = Array(answer["visiting"]) if answer.key?("visiting")
  end

  # Carries out the actions the DLL answered, in their order, each with the game's own grant.
  #
  # @param actions [Array<Array>] The actions, see CatchupTopics in the DLL.
  def self.run(actions)
    gifts = []
    Array(actions).each do |action|
      begin
        gift = act(action)
        gifts << gift if gift.is_a?(String)
        if action[0] == "gifts"
          tell_gifts(gifts)
          gifts = []
        end
      rescue => e
        log_once([:act, action[0], e.class], "carrying out #{action[0]} failed: #{e.class}: #{e.message}")
      end
    end
  end

  # Carries out one action.
  #
  # @param action [Array] The action: its name, then its fields.
  # @return [String, nil] What it gave, as shown, for the next tell of gifts.
  def self.act(action)
    case action[0]
    when "give" then return give_row(action[1], action[2], action[3], action[4], action[5])
    when "learn" then return learn(action[1], action[2])
    when "teach" then return teach(action[1], action[2])
    when "class" then return give_class(action[1], action[2], action[3])
    when "log" then log(action[1].gsub(/\{actor:(\d+)\}/) { actor_label($1.to_i) })
    when "join" then bring_in(action[1], action[2], action[3])
    when "raise" then raise_level(action[1], action[2])
    when "form" then take_form(action[1], action[2])
    when "leave" then take_away(action[1], action[2])
    when "dismiss" then dismiss(action[1])
    when "change" then change_actors(action[1], action[2], action[3])
    when "set" then $game_variables[action[1]] = action[2]
    when "switch" then $game_switches[action[1]] = action[2]
    when "setting" then settle(action[1], action[2], action[3], action[4])
    when "vehicles" then place_vehicles(action[1])
    when "replay" then MGQ_MpStoryReplay.derive(action[1], action[2])
    end
    nil
  end

  # Gives or takes what a row names.
  #
  # @param kind [String] "skill", or "i", "w" or "a" for an item.
  # @param id [Integer] The skill or item.
  # @param amount [Integer] How many, below 0 to take.
  # @param key [String] The row, for the log.
  # @param gift [Boolean] Whether it counts among the gifts the next tell lists.
  # @return [String, nil] What was given, as shown.
  def self.give_row(kind, id, amount, key, gift)
    given = give(kind == "skill" ? :skill : kind, id, amount, key)
    gift ? given : nil
  end

  # Teaches Luka a skill of the story he lacks, leaving one he knows quietly.
  #
  # @param id [Integer] The skill.
  # @param key [String] The row, for the log.
  # @return [String, nil] What was given, as shown.
  def self.learn(id, key)
    MGQ_MpStoryState.knows?($game_actors[HERO], id) ? nil : give(:skill, id, 1, key)
  end

  # Teaches a companion a skill the story taught them, leaving one they know quietly.
  #
  # @param actor_id [Integer] The companion's persona.
  # @param skill [Integer] The skill.
  # @return [String, nil] What was taught, as shown.
  def self.teach(actor_id, skill)
    actor = $game_actors[actor_id]
    return nil if actor.nil? || MGQ_MpStoryState.knows?(actor, skill)

    MGQ_MpStoryState.teach(actor_id, skill)
  end

  # Gives a character a class or race at a level the story gave them, leaving one they hold at that
  # level quietly.
  #
  # @param actor_id [Integer] The character.
  # @param class_id [Integer] The class or race.
  # @param level [Integer] The level.
  # @return [String, nil] What was given, as shown.
  def self.give_class(actor_id, class_id, level)
    actor = $game_actors[actor_id]
    return nil if actor.nil? || MGQ_MpStoryState.class_level(actor, class_id) >= level

    MGQ_MpStoryState.give_class(actor_id, class_id, level)
  end

  # Moves a value of the player's own the story set to what the DLL found the latest step left,
  # unless the map sets the encounters the other way now or the value tells a place elsewhere.
  #
  # @param kind [String] "encounters", "v" or "s".
  # @param id [Integer] The variable, 0 for the encounters.
  # @param value [Object] The value.
  # @param site [String] The event that sets it.
  def self.settle(kind, id, value, site)
    encounters = kind == "encounters"
    now = encounters ? !$game_system.encounter_disabled : $game_variables[id]
    label = encounters ? "the random encounters" : "variable #{id}"
    return log_once([:own_encounters, $game_map.map_id], "left the random encounters to map #{$game_map.map_id}, whose event sets them the other way now") if encounters && map_sets_encounters?(value)
    return log_once([:elsewhere, site, $game_map.map_id], "left #{label} at #{now.inspect}: #{site} sets it where the player does not stand") unless at_site?(kind, id, site)

    encounters ? $game_system.encounter_disabled = !value : $game_variables[id] = value
    log("set #{label} from #{now.inspect} to #{value.inspect}, as #{site} of the story left it")
  end

  # Reports whether a setting may apply where the player stands: the random encounters anywhere, a
  # variable the game uses as a place (MGQ_MpStoryIds.place?) only on the map of the event that
  # sets it.
  #
  # A place the world's story set elsewhere, as where a game over returns the player, could send
  # them into another player's scene with no way out.
  #
  # @param kind [String] "encounters", "v" or "s".
  # @param id [Integer] The variable.
  # @param site [String] The event that sets it.
  # @return [Boolean] Whether it may.
  def self.at_site?(kind, id, site)
    return true unless kind == "v" && MGQ_MpStoryIds.place?(id)

    site.to_s =~ /\Amap:(\d+):/ && $1.to_i == $game_map.map_id ? true : false
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

  # Keeps the vehicles to the story as the DLL found it: one no event that gives it is behind the
  # player's story or the world's leaves its map (park_vehicle), one the story gave before the
  # world's log that stands on no map comes back to its start (return_vehicle), and one only the
  # log gave stays where its replay put it.
  #
  # @param given [Array<Boolean, nil>] Whether the story gave each vehicle, by VEHICLE_TYPES: nil
  #   where only the world's log did.
  def self.place_vehicles(given)
    VEHICLE_TYPES.each_with_index do |type, id|
      vehicle = $game_map.vehicle(type)
      next unless vehicle

      map_id = MGQ_MpGame.get(vehicle, :map_id).to_i
      if given[id]
        return_vehicle(type, vehicle) if map_id == 0
      elsif given[id] == false && map_id != 0
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
  # the next look then takes away.
  #
  # @return [Boolean] Whether they did.
  def self.got_off_early?
    return false unless @riding_early && !$game_player.vehicle

    @riding_early = false
    true
  end

  # Asks for one look at everything once the player is free again: as their level rose.
  def self.level_up
    @audit_due = true if active?
  end

  # Runs an actor change in the player's game as the story's event does, through the game's
  # interpreter: each call in order, one only a first playthrough runs on a first playthrough
  # alone, and none whose change the character shows already (shows?).
  #
  # @param actor_id [Integer] The character's main persona.
  # @param site [String] The event that changes them.
  # @param calls [Array<Array>] Each call's name, whole numbers and whether only a first playthrough
  #   runs it.
  # @return [nil] Nothing to tell among the gifts.
  def self.change_actors(actor_id, site, calls)
    interpreter = Game_Interpreter.new
    first = $game_variables[MGQ_MpStoryIds.playthrough].to_i == 0
    ran = calls.map do |name, ids, once|
      name = name.to_sym
      next if once && !first
      next log("skipped #{name} of #{site}: no call of the game the catch-up runs") unless ACTOR_CALLS.include?(name) && interpreter.respond_to?(name)
      next if shows?(name, ids)

      MGQ_MpCoopEvents.granting { interpreter.public_send(name, *ids) }
      shown = ids.size > LOGGED_NUMBERS ? ids.first(LOGGED_NUMBERS).join(", ") + ", ... (#{ids.size})" : ids.join(", ")
      "#{name}(#{shown})"
    end.compact
    log(ran.empty? ? "#{actor_label(actor_id)} shows what #{site} changes already" : "#{actor_label(actor_id)} took what #{site} changes: #{ran.join(', ')}")
    nil
  end

  # Reports whether a character shows what a call of an actor change does already, so it would
  # change nothing or give its items twice: the persona taken, the level reached, the item worn,
  # the stones set or the abilities equipped. Marks of the compendium never show, as setting one
  # twice changes nothing.
  #
  # @param name [Symbol] The call, one of ACTOR_CALLS.
  # @param ids [Array<Integer>] Its whole numbers, the character's persona first.
  # @return [Boolean] Whether it does; true for a character the game lacks.
  def self.shows?(name, ids)
    actor = $game_actors[ids[0]]
    return true unless actor

    case name
    when :persona_change then actor.id == ids[0]
    when :level_adjust then ids[1] ? actor.base_level >= ids[1] : false
    when :force_change_equip
      item = MGQ_MpGame.item(EQUIP_KINDS[ids[2]], ids[3])
      worn = actor.equips[ids[1] - 1]
      item && worn ? worn.class == item.class && worn.id == item.id : false
    when :change_actor_equip_stone
      worn = (actor.respond_to?(:base_equips) ? actor.base_equips : actor.equips)[ids[1]]
      worn && worn.respond_to?(:stones) ? worn.stones.compact.map(&:id) == ids[2..-1] : false
    when :change_actor_ability
      equipped = MGQ_MpGame.get(actor, :equip_abilities)
      equipped.is_a?(Hash) && equipped.values.flatten.sort == ids[1..-1].sort
    else false
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
    return [] unless active? && keys

    answer = call(UNLOCKS_TOPIC, snapshot)
    return [] unless answer

    list = Array(answer["unlocks"]).map { |level, kind, id, name, got, due, gains| unlock_of(level, kind, id, name, got, due, gains) }.compact
    list.sort_by { |unlock| [unlock.level.to_i, UNLOCK_KINDS.index(unlock.kind), unlock.name] }
  rescue => e
    log_once(:unlocks, "listing what the catch-up hands out failed: #{e.class}: #{e.message}")
    []
  end

  # Names an unlock the DLL listed.
  #
  # @param level [Integer] Its level.
  # @param kind [String] "story", "companion" or "makina".
  # @param id [Integer, nil] The companion or the Makina.
  # @param name [String, nil] The part's name.
  # @param got [Boolean] Whether the player has it.
  # @param due [Boolean] Whether it comes at the next check.
  # @param gains [Array<Array>] What moving on brings along: kind, id and amount each.
  # @return [Unlock, nil] The unlock; nil for a Makina the game lacks.
  def self.unlock_of(level, kind, id, name, got, due, gains)
    case kind
    when "story" then Unlock.new(level, :story, name, nil, got, due, nil, gains_of(gains))
    when "companion" then Unlock.new(level, :companion, actor_name(id), nil, got, due, id, [])
    else
      item = MGQ_MpGame.item("i", id)
      item ? Unlock.new(level, :makina, item.name, item.respond_to?(:icon_index) ? item.icon_index : nil, got, due, id, []) : nil
    end
  end

  # Names what moving on from a part brings along.
  #
  # @param gains [Array<Array>] Each kind ("skill", "i", "w" or "a"), id and amount.
  # @return [Array<Gain>] Key items and unlocks first, then skills and items.
  def self.gains_of(gains)
    found = Array(gains).map do |kind, id, amount|
      gain = gain_of(kind == "skill" ? :skill : kind, id)
      gain && gain.tap { |named| named.amount = amount }
    end
    found.compact.sort_by { |gain| [GAIN_ORDER.index(gain.kind), gain.name] }
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

  # Reads the level the catch-up counts: the highest base level among the player's characters.
  #
  # @return [Integer, nil] The level, nil without characters.
  def self.counted_level
    roster_view[:best]
  rescue
    nil
  end

  # The highest base level among the roster's companions not on a visit (see counts?), with that
  # character's own highest level.
  #
  # @return [Hash] :best and :cap (nil without one).
  def self.roster_view
    best = MGQ_MpStoryState.roster.reject { |actor| visiting?(MGQ_MpStoryState.main_id(actor.id)) }.max_by { |actor| actor.base_level }
    { :best => best && best.base_level, :cap => best && best.max_level(:base) }
  end

  # Reports whether a companion is in the roster on a visit only, as the DLL's last look found.
  #
  # @param id [Integer] The companion's main persona.
  # @return [Boolean] Whether they are.
  def self.visiting?(id)
    @visiting.include?(id)
  end

  # Reports whether a character counts in the catch-up, toward the player's level and in the
  # catch-up experience: one of their own roster, not a story's temporary party, and not on a visit.
  #
  # @param actor [Game_Actor] The character.
  # @return [Boolean] Whether they do.
  def self.counts?(actor)
    main = MGQ_MpStoryState.main_id(actor.id)
    MGQ_MpStoryState.roster_ids.include?(main) && !visiting?(main)
  rescue
    true
  end

  # Reports whether a player of the world got an item, as gained notes it.
  #
  # @param id [Integer] The item.
  # @return [Boolean] Whether one did.
  def self.found?(id)
    $game_self_switches[[FOUND_MAP, id, FOUND_LETTER]] ? true : false
  end

  # Notes a Makina the player gained as found for the world, so every other player gets it by level.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @param amount [Integer] How many.
  def self.gained(item, amount)
    return unless amount.to_i > 0 && active? && item.is_a?(RPG::Item) && keys && keys["makina"].include?(item.id)

    key = [FOUND_MAP, item.id, FOUND_LETTER]
    return if $game_self_switches[key]

    $game_self_switches[key] = true
    log("noted #{item.name} as found for the world")
  rescue => e
    log_once(:found, "noting a found item failed: #{e.class}: #{e.message}")
  end

  # Notes every Makina the player holds as found for the world, as gained does for one they get, so
  # one got before the world noted it still reaches the other players by level. Runs before every
  # look at everything.
  def self.note_held_items
    return unless keys

    keys["makina"].each { |id| gained($data_items[id], 1) if $data_items[id] && $game_party.item_number($data_items[id]) > 0 }
  end

  # Reports whether an item unlocks a job or a race.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @return [Boolean] Whether it does.
  def self.unlock_item?(item)
    item.is_a?(RPG::Item) && item.description.to_s =~ UNLOCK_ITEM_TAG ? true : false
  end

  # Logs what the story gave the player at once.
  #
  # No notice tells it, as one look can give more than a notice lists.
  #
  # @param gifts [Array<String>] What was given, as shown.
  def self.tell_gifts(gifts)
    log("the story gave the player #{gifts.join(', ')}") unless gifts.empty?
  end

  # Asks the player whom they take along once they are free, when the DLL found their story went
  # past the choice of a side before the Great Decision without one, until they chose.
  #
  # A teller's scene ends the player's own choice before it sets the side when both play it at once,
  # and the side switches are each player's own in a Raid World, so the teller's choice is no help.
  #
  # @param lost [Boolean] Whether the story went past the choice without one.
  def self.ask_side(lost)
    # A battle's invite clears the message window, and the question with it.
    @asking_side = false if @asking_side && !$game_message.busy?
    return if @asking_side || !lost || !MGQ_MpOverworldSync.map_free? || MGQ_MpCoopEvents.mirroring? || $game_message.busy?

    @asking_side = true
    log("asking the player whom they take along: their story went past the choice of a side without one")
    $game_message.add("Your story went past the choice of whom you take along. Whom do you take along on your journey?")
    $game_message.choices.push("Alice", "Ilias")
    $game_message.choice_cancel_type = 0
    $game_message.choice_proc = Proc.new { |index| take_side(index == 0 ? :alice : :ilias) }
  end

  # Keeps the side the player chose in the save's notes and, before the Great Decision, sets its
  # switch and brings its companion along, as the choice in Iliasville does; the next look gives
  # what the side's rows owe, as the Pocket Castle. On a route the switches tell the route, so they
  # stay.
  #
  # @param side [Symbol] :alice or :ilias.
  def self.take_side(side)
    @asking_side = false
    name = side == :alice ? "Alice" : "Ilias"
    log("the player took #{name} along")
    MGQ_MpStoryState.note_pick(side)
    note("side" => side.to_s)
    @audit_due = true
    return log("the player's story is on a route, whose side switches stay") if MGQ_MpStoryIds.route_variables.any? { |id| $game_variables[id].to_i > 0 }

    MGQ_MpStoryIds.side_switches.each { |id| $game_switches[id] = id == (side == :alice ? MGQ_MpStoryIds.alice_chosen : MGQ_MpStoryIds.ilias_chosen) }
    companion = keys && (keys["side_companions"] || {})[side.to_s]
    bring_in(companion, nil, "you took #{name} along") if companion
  rescue => e
    log("taking a side failed: #{e.class}: #{e.message}")
  end

  # Notes that the orbs' event waits to play once the DLL found the player holds every orb before
  # the story moved on, once per session: the orbs the catch-up gave came without the call of an
  # orb's event, which only the player who plays it gets.
  #
  # @param due [Boolean] Whether the DLL found it due.
  def self.note_orbs(due)
    @orbs_now = due ? true : false
    return if @orbs_due || @orbs_played || !@orbs_now

    @orbs_due = true
    log("the player holds every orb of Part 2 at #{$game_variables[MGQ_MpStoryIds.main_progress]}: common event #{keys['orb_event']} waits to play once the player is free")
  end

  # Plays the orbs' event once the player is free on the map, unless the story moved on meanwhile.
  def self.play_orb_event
    return unless MGQ_MpOverworldSync.map_free? && !MGQ_MpWorldStory.queued?

    @orbs_due = false
    return unless MGQ_MpWorldStory.mode == :world && @orbs_now && keys && keys["orb_event"]

    @orbs_played = true
    event = keys["orb_event"]
    log("playing common event #{event} now")
    $game_map.interpreter.setup([MGQ_MpWorldStory.command(117, [event]), MGQ_MpWorldStory.command(0, [])], 0)
  end

  # Brings a companion into the player's roster as the game's own join does: the persona (unless
  # keeps_form?), recovered, into the team, or on standby through the game's own cut when it is full
  # or a story's temporary party plays; then raised to the join's level.
  #
  # @param persona [Integer] The persona that joins.
  # @param level [Integer, nil] The level they come at least at, nil for their own.
  # @param reason [String] Why, for the notice.
  # @return [nil] Nothing to tell among the gifts.
  def self.bring_in(persona, level, reason)
    return nil unless $data_actors[persona]
    return nil if MGQ_MpStoryState.in_roster?(persona)

    @granting = true
    begin
      $game_party.persona_change(persona) if $game_party.respond_to?(:persona_change) && !keeps_form?(persona)
      actor = $game_actors[persona]
      actor.recover_all if actor && actor.respond_to?(:recover_all)
      temp = $game_party.respond_to?(:temp_actors_use?) && $game_party.temp_actors_use?
      temp ? $game_party.add_stand_actor(persona) : $game_party.add_actor(persona)
    ensure
      @granting = false
    end
    raise_level(persona, level)
    log("#{actor_label(persona)} joined the player's roster (#{reason})")
    notice([:joined, persona], "#{actor_name(persona)} joined you.")
    nil
  end

  # Raises a companion to a level, as the story's level floors do; never lowers them.
  #
  # @param persona [Integer] The companion, in any persona.
  # @param level [Integer, nil] The level, nil for none.
  # @return [nil] Nothing to tell among the gifts.
  def self.raise_level(persona, level)
    actor = level && $game_actors[persona]
    return nil unless actor && actor.base_level < level

    actor.change_level(level, false, :base)
    log("raised #{actor_label(persona)} to level #{actor.base_level}")
    nil
  end

  # Turns a companion of the roster into the persona a join of theirs brings, as the game's own
  # join does.
  #
  # @param persona [Integer] The persona the join brings.
  # @param site [String] The join's site, for the log.
  # @return [nil] Nothing to tell among the gifts.
  def self.take_form(persona, site)
    $game_party.persona_change(persona)
    log("#{actor_label(persona)} took the persona the join at #{site} brings")
    nil
  end

  # Takes away a companion a story carried the player past the lasting removal of.
  #
  # @param actor [Integer] The companion's main persona.
  # @param sites [String] The removals' sites, for the log.
  # @return [nil] Nothing to tell among the gifts.
  def self.take_away(actor, sites)
    $game_party.remove_actor(actor)
    log("#{actor_label(actor)} left the player's roster: the story carried them past #{sites}")
    notice([:left, actor], "#{actor_name(actor)} left with the story.")
    nil
  end

  # Takes away a companion of the Alice and Ilias choice the player never had a right to, as the DLL
  # found: of the side they did not take along, or of a route they never played.
  #
  # @param actor [Integer] The companion's main persona.
  # @return [nil] Nothing to tell among the gifts.
  def self.dismiss(actor)
    $game_party.remove_actor(actor)
    log("#{actor_label(actor)} left the player's roster: the player never took their side along nor played a route that gives them")
    notice([:left, actor], "#{actor_name(actor)} left you.")
    nil
  end

  # Reports whether a persona is one of a companion's other personas than the main one.
  #
  # @param persona [Integer] The persona.
  # @return [Boolean] Whether it is.
  def self.form?(persona)
    MGQ_MpStoryState.main_id(persona) != persona
  end

  # Reports whether a join of a companion's main persona keeps the other persona they are in, which
  # an actor change gave them before the join's gate let them in.
  #
  # @param persona [Integer] The persona the join brings.
  # @return [Boolean] Whether it does.
  def self.keeps_form?(persona)
    actor = $game_actors[persona]
    actor && !form?(persona) && actor.id != persona ? true : false
  end

  # Leaves out the game's own join of a companion of the Alice and Ilias choice the player has no
  # right to, in a Raid World as the DLL finds it and in a Classic party through coop_story.rbx;
  # and in a Raid World holds back a companion a story event of the player's own hands out before
  # the player's level reaches the join's gate, as the DLL finds it: the join waits for it instead.
  # A replay's join in a Raid World waits for the world's companion sharing and the join's level,
  # which the world's shared companions bring later (the one companion filter in the DLL); one of a
  # replay that went the player's own way is the player's own and waits for its gate.
  # Called before the game adds a companion to the party.
  #
  # @param actor_id [Integer] The companion, in any persona.
  # @return [Boolean] Whether the game's own join is left out.
  def self.hold_join?(actor_id)
    return false if @granting

    main = MGQ_MpStoryState.main_id(actor_id)
    return false if MGQ_MpStoryState.in_roster?(main)
    return defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.refuses_join?(main, joining_site) ? true : false unless active?
    return false if keys.nil?

    replaying = defined?(MGQ_MpStoryReplay) && MGQ_MpStoryReplay.respond_to?(:running?) && MGQ_MpStoryReplay.running?
    own_way = replaying && MGQ_MpStoryReplay.current.respond_to?(:own_way?) && MGQ_MpStoryReplay.current.own_way? ? true : false
    own_event = own_way || (!replaying && MGQ_MpWorldStory.mode == :world && defined?(MGQ_MpCoopEvents) && MGQ_MpCoopEvents.telling?)
    answer = call(HOLD_TOPIC, "actor" => main, "site" => joining_site, "scope_only" => !own_event, "own" => values(story_now), "roster" => roster_entries,
                              "replay" => replaying ? true : false, "own_way" => own_way, "sharing" => MGQ_MpWorld.companion_sharing.to_s, "start" => start_level(main))
    return false unless answer

    run(answer["actions"])
    return true if answer["refused"]

    gate = answer["gate"]
    return false unless gate

    notice([:held, main], "#{actor_name(actor_id)} joins you once you reach level #{gate}.")
    true
  rescue => e
    log("holding back a companion failed: #{e.class}: #{e.message}")
    false
  end

  # Names the list a join comes from: the run a replay plays, else the map's page that runs.
  #
  # @return [String, nil] The site, such as "map:134:34:4" or "ce:380"; nil while none runs.
  def self.joining_site
    replay = defined?(MGQ_MpStoryReplay) && MGQ_MpStoryReplay.respond_to?(:current) ? MGQ_MpStoryReplay.current : nil
    replay ? replay.site : running_page_site
  end

  # Names the map event page the map's interpreter runs as the catch-up tables' sites do.
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

  # Notes the companions new in the player's roster that the world's shared list takes, as the DLL
  # found them: the story's companions, every one with battle recruits shared too. A companion on a
  # visit is noted only once they stay.
  #
  # @param sharable [Array<Integer>] The roster's companions the world's list takes.
  def self.note_roster(sharable)
    ids = MGQ_MpStoryState.roster_ids.reject { |id| visiting?(id) }
    fresh = ids - (@known_roster || [])
    @known_roster = ids
    return if MGQ_MpWorld.companion_sharing == :off || MGQ_MpWorldStory.world.nil?

    fresh.each { |id| @share_queue << id if sharable.include?(id) && !@share_queue.include?(id) }
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

  # Patch/Multiplayer/Multiplayer.dll's shared companions of the world at the relay.
  module Relay
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
  # A Makina the player gets is found for the world.
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
