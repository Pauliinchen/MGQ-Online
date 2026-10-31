#----------------------------------------------------------------
#  world_story.rbx
#
#  Changelog:
#      Paulinchen  2026-10-31: Offered at the Great Decision the routes the relay grants, in place of a copy of its route rules
#                            - Told the catch-up whether a lost raid boss battle holds the story
#                            - Dropped the lift of the refusal of recruits that older worlds' story handed over
#                            - Handed the player's runs to their track and the track's entries to the replay in order
#                            - Told the catch-up where the world's log starts, and the world's story there
#      Paulinchen  2026-10-28: Told the part of the player's track
#                            - Left the player's telling to the DLL's telling machine
#                            - Told the player's track in their state and read the tellings on it from the DLL
#                            - Let the DLL say whose ended telling the player's story events wait for, ten seconds at most
#                            - Had the DLL fetch the story mapping in a Classic world too, for the rewards a party member catches up with
#                            - Wrote what the relay handed outside the write journal of the frozen fights
#                            - Sent the frame's writes to the DLL ahead of the world's close
#      Paulinchen  2026-10-24: Kept on the unlocks the player holds that the relay hands off, as the second accessory slot
#      Paulinchen  2026-10-23: Asked the DLL for the part a story is in
#                            - Played the world's story on the relay's tracks: the player's own writes as requests, the relay's values written straight into the story
#                            - Dropped the story's fetches, whole-story writes, merges, scans and holds, which the relay's tracks replace
#                            - Told the relay the player's tellings, the teller they watch and their level
#                            - Took the player out of their own scene before the return to the Great Decision and the end of a cleared collab
#                            - Told whether event commands may move the world's story on and read the values that do
#      Paulinchen  2026-10-18: Shared the Sonya scene's step as its start while none of its fights is frozen or over
#                            - Ended the collab scenario the world's story cleared and gave back its stored items
#                            - Turned the collab scenario's start off in Raid Worlds
#      Paulinchen  2026-10-17: Held the story's takes, comparisons and writes while a lost raid boss battle's defeat runs
#                            - Sent and read the frozen raid boss fights with the world's story
#                            - Shared the keys a frozen raid boss fight holds at their values from before its event
#                            - Put the keys a frozen raid boss fight holds back in the player's story, the world's and the writes
#      Paulinchen  2026-10-15: Turned off the refusal of recruits the world's story had handed over
#                            - Read and wrote no route under way before the Great Decision
#                            - Kept the steps before a boss battle that its defeat sets back out of the world's story
#                            - Held the story's writes while a novel scene runs
#                            - Kept the Queen's Cup's tournament steps out of the world's story
#      Paulinchen  2026-10-14: Kept the one-way story variables from going below the world's values
#                            - Kept the raises of one-way variables through a step the relay refused as behind
#                            - Asked the later builds' choices behind the world's first story that the player's save never made
#      Paulinchen  2026-10-12: Sent and read the companions' affection with the world's story
#                            - Sent and read the level caps the world's story unlocked
#      Paulinchen  2026-10-11: Left the random encounters to world_catchup.rbx
#                            - Turned random encounters on again as the world's story is laid over past the talk that turns them on
#                            - Turned off the scene switches left on while no scene runs as the world's story is laid over
#                            - Laid the world's story over a new game only after its opening's setup ran, and counted own changes from that story
#                            - Took a route the player chose at the world's Great Decision as further than the decision
#                            - Opened every route at the Great Decision again once the world finished all of them
#                            - Kept the player's story events waiting for the world's story for ten seconds at most after the world opened or a save loaded
#                            - Took the story values a teller's scene laid over the player's as the world's
#      Paulinchen  2026-10-10: Held the write between the story's events on another map while its next event may go on with the telling
#                            - Took the world's story as a return to the Great Decision only once it left the route this game's story was on
#                            - Kept the player's own writes from ending the wait for the story of a telling they watched
#                            - Named the player whose telling the player's story events wait for
#                            - Kept a player noted behind below their gate after a load or a new entry into the world, before the world's story came
#                            - Kept the story a player stood on as they fell behind as the base of their own changes
#                            - Brought back the companions of the player's own Great Decision and told the world's route also when another player locked it before the world had a story
#                            - Dropped the story a player behind stood on once their own story becomes the world's first
#      Paulinchen  2026-10-09: Read and wrote the story through story_state.rbx instead of coop_story.rbx
#                            - Kept a player behind the world's story on the checkpoint of their part and moved them on by their level through world_catchup.rbx
#                            - Made the chests that hold the story's key items the whole world's
#                            - Kept a player behind until their level moves them on, also once the world returns from a route to their part
#                            - Read the world's shared companions and the parts it keeps checkpoints of from the relay's state
#                            - Brought back the companions the player's own Great Decision took away, also when the relay refuses their write
#                            - Asked the choices a story carried the player past also when the same story takes them onto a route
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# A Raid World's story, which the relay keeps for the whole world on its tracks (Relay/README.md,
# "Story tracks"): the world's track, and a track of their own for a player behind the world. The
# DLL plays the tracks' protocol (StoryTopics); this script hands it what it needs of the game and
# writes what comes back into the game's story.
#
# Every write the game makes of a key the story mapping keeps goes to the relay as a request
# (story_keys.rbx), applied in the player's own game at once so the event that wrote it reads it.
# What the relay hands back, a whole track as the player enters or moves between tracks, the
# pushes of other games' writes and its own value of a request it did not keep as written, is
# written straight into the game's story once the player is free: no event of their own, battle or
# transfer runs. Nothing is merged; the keys the mapping keeps no row of are the player's own.
#
# The runs of the player's own events that changed the story go to their track after their writes,
# and the track's runs reach the replay (story_replay.rbx) one at a time, in their order, while the
# player stands free; the DLL walks the track from the player's cursor.
#
# The Great Decision: the first route a write takes is the world's; the game's own choice offers
# only the routes the world may still take, and a player the world's story carries past the
# decision picks it on the screen of coop_choices.rbx. A finished route takes the world back to the
# Great Decision in place of the Reaper's reset menu (common event 265), which would drop companions;
# called anywhere else, the menu is left out, since one player must not take the whole world back.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldStory
  # Frames between two fetches of the world's shared companions while the relay tells nothing, a
  # minute, in case a push was lost.
  POLL_FRAMES = 3600

  # Frames between two reads of the DLL's state of the shared companions while a request runs.
  STATE_FRAMES = 15

  # Frames between two looks at the player's level and what the world's story left.
  CHECK_FRAMES = 30

  # Frames the player's story events wait at most for the world's story after the world opened, a
  # save loaded or a new game started, ten seconds, in case the relay does not answer.
  AWAIT_WORLD_FRAMES = 600

  # Frames the player's story events wait at most for the world's story of a telling that ended,
  # ten seconds, in case the take that writes it stays held.
  AWAIT_TELLER_FRAMES = 600

  # Frames before the player's story is handed again while the relay still asks for it, a second.
  SEED_FRAMES = 60

  # Bytes the DLL may write the shared companions' state into at first; a larger one asks for more.
  STATE_SIZE = 4096

  # The highest level the relay's gates take.
  MAX_LEVEL = 99_999

  # The topics of the story on tracks, see StoryTopics in the DLL; the player's own telling goes to
  # the DLL from coop_events.rbx.
  ENTER_TOPIC = "story.enter"
  CLOSE_TOPIC = "story.close"
  LEVEL_TOPIC = "story.level"
  SEED_TOPIC = "story.seed"
  WATCH_TOPIC = "story.watch"
  TAKE_TOPIC = "story.take"
  HAND_TOPIC = "story.hand_entry"
  STREAM_TOPIC = "story.stream"

  # The topic that has the DLL fetch the story mapping of a Classic world's relay, see StoryTopics.
  MAPPING_TOPIC = "story.mapping"

  # The events of the story on tracks.
  STATUS_EVENT = "story.status"
  REFUSED_EVENT = "story.refused"

  # The world's own track.
  WORLD_TRACK = "world"

  # The codes of a route variable's request the relay refused as another route is the world's.
  ROUTE_CODES = %w(route finished closed)

  # The routes as the relay names them, in the order of their variables and of the Great
  # Decision's outcomes.
  ROUTES = %w(ad mr chaos)

  # What the notices call each route.
  ROUTE_NAMES = ["Angelic Dominion", "Monster Realm", "Chaos"]

  # The main story's progress.
  MAIN_PROGRESS = 1001

  # The routes' progress, by route.
  ROUTE_VARIABLES = [1141, 1142, 1143]

  # The switches that tell a route was cleared, by route.
  CLEAR_SWITCHES = [7096, 7097, 7039]

  # Variables whose change moves the story on: the main story, the routes, the Great Decision's
  # progress and the areas' progress the parts are ordered by.
  PROGRESS_VARIABLES = [MAIN_PROGRESS] + ROUTE_VARIABLES + [1140, 1003, 1011, 1019, 1021, 1032, 1052, 1063, 1075, 1076, 1136, 1137, 1138, 1139]

  # Switches whose change moves the story on: the bosses of the Monster Lord's Castle and the route
  # clears.
  PROGRESS_SWITCHES = [2485, 2486, 2487] + CLEAR_SWITCHES

  # How many common events deep progress_ahead? follows the calls of the commands it reads.
  PROGRESS_CALL_DEPTH = 3

  # The topic that finds the part a story is in.
  PART_TOPIC = "story.part"

  # The main story's progress the Great Decision sets.
  GREAT_DECISION = 40

  # The part the Great Decision lies in, as part_of names it.
  DECISION_PART = "3"

  # The main story's progress a return to the Great Decision sets.
  BEFORE_DECISION = 39

  # The common event of the Great Decision, whose choice of the routes the world filters.
  DECISION_EVENT = 380

  # The Reaper's reset menu after a route's credits, which drops companions, never run in a Raid World.
  RESET_EVENT = 265

  # The Reaper's offer in Hades to reset time, which calls RESET_EVENT.
  REAPER_EVENT = 149

  # The game's own reset of the Final Chapter, the global half of a return to the Great Decision.
  FINAL_RESET_EVENT = 154

  # The game's returns to the Great Decision, with Alice's side and with Ilias's.
  RETURN_EVENTS = [267, 268]

  # Where a game over returns the player after each return, by side.
  RETURN_POINTS = [111, 112]

  # The variable where a game over returns the player.
  GAME_OVER_RETURN = 1002

  # The variable a transfer to TRANSFER_RELAY_MAP goes on from, as the game's own returns use it.
  TRANSFER_MAP = 57

  # The map whose transfer goes on to the map in TRANSFER_MAP.
  TRANSFER_RELAY_MAP = 544

  # The game's switch that refuses every recruit ("Ally Rejection"), on from the new game until Lime
  # joins and while the Pocket Castle's collab scenario runs, each player's own in a Raid World.
  ALLY_REJECTION = 3

  # The collab scenario's chapters (Collab:C1 to C12), all 0 before it starts.
  COLLAB_VARIABLES = 1201..1212

  # The first chapter's step once the White Rabbit arrived in the Pocket Castle, whose arrival plays
  # on its own while the chapter is below it.
  COLLAB_ARRIVED = 1

  # The first chapter's step from which the White Rabbit no longer offers the collab's start.
  COLLAB_STARTED = 3

  # The maps the collab scenario plays on, as the game's own collab reset lists them.
  COLLAB_MAPS = [845..936, 949, 953]

  # The switches the collab's start turns on: Ally Rejection, Warp OFF and Hide Important Things.
  COLLAB_SWITCHES = [ALLY_REJECTION, 100, 504]

  # The Pocket Castle's event that starts the collab scenario: the map and the event.
  COLLAB_START = [228, 52]

  # Where a cleared collab returns the player: the Pocket Castle below its start, facing down.
  COLLAB_RETURN = [228, 24, 27, 2]

  # Where a return to the Great Decision takes the player: the map, x and y.
  DECISION_PLACE = [407, 25, 25]

  # Event commands that run a script, which the returns use to add companions.
  SCRIPT_CODES = [355, 655]

  # The game's own endings of the two first routes, which its system switches keep per install and
  # the world's clear switches stand for in a Raid World.
  SYSTEM_ENDINGS = { :ed1 => 7096, :ed2 => 7097 }

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "world story"

  # Forgets what this session knew of the world's story, as when the world closes, a save is loaded
  # or a new game starts, which bring their own story.
  #
  # @param reason [Symbol, nil] Why the story starts anew, nil when the world closed.
  def self.forget(reason = nil)
    @mode = nil
    @waiting = nil
    @watching = nil
    @level_sent = nil
    @seeded_at = nil
    @queued = nil
    @returned_route = nil
    @route_refused = false
    @decision_roster = nil
    @world = nil
    @log_story = nil
    @caps = nil
    @clock ||= 0
    @awaited_since = reason ? @clock : nil
    @awaited_telling = nil
    @checked = @clock
  end

  forget

  # Forgets the world's story once the world closed or is no Raid World, after the frame's writes
  # went to the DLL ahead of the close: a world left for the title screen closes its room before
  # the frame ends, so its last writes must be on their way by then.
  def self.close
    return unless @world_id

    log("the Raid World closed: forgetting its story")
    MGQ_MpStoryKeys.flush
    MGQ_Multiplayer::Bridge.stage(CLOSE_TOPIC)
    MGQ_Multiplayer::Bridge.flush
    MGQ_MpStoryKeys.recording = nil
    MGQ_MpStoryKeys.forget_raid
    @world_id = nil
    @status = nil
    @comps = nil
    @busy = nil
    forget
  end

  # Reports whether the world's story applies: a Raid World is open, which the directory knows.
  #
  # @return [Boolean] Whether it does.
  def self.active?
    MGQ_MpCoop::Scope.raid? && MGQ_MpOverworldSync.in_world? && !world_id.empty?
  end

  # The open world's id, which the DLL's story names the world by.
  #
  # @return [String] The id, empty outside a world or for a world the directory does not know.
  def self.world_id
    MGQ_MpWorld.world.directory_id.to_s
  rescue
    ""
  end

  # Reports whether the player's story events wait for the world's story, which has not come since
  # the world opened, a save loaded or a new game started: the player's own story would play
  # before the world's was written into it. AWAIT_WORLD_FRAMES at most. Called by coop_events.rbx.
  #
  # @return [Boolean] Whether they wait.
  def self.awaits_world?
    return false unless @awaited_since && @mode.nil? && active?
    return true if @clock - @awaited_since < AWAIT_WORLD_FRAMES

    log("the world's story did not come within #{AWAIT_WORLD_FRAMES / 60} s: the player's story events start without it")
    @awaited_since = nil
    false
  end

  # How the player plays the world's story.
  #
  # @return [Symbol, nil] :world while they play the world's track, :behind while they play a track
  #   of their own (see world_catchup.rbx), nil before the relay handed them one.
  def self.mode
    @mode
  end

  # The world's story as the relay tells it, for the catch-up and the World overview.
  #
  # @return [Hash, nil] "rev", "part", "route" ("none" for none), "done", "open" (the routes the
  #   relay grants at the Great Decision) and "checkpoints" as the relay's summary tells them,
  #   "start" (the story markers where the world's log starts, nil for none), "comps" (the
  #   companions the world shares) and "caps" (the level caps the player's story unlocked); nil
  #   before the relay told any.
  def self.world
    summary = @status && @status["world"]
    return nil unless summary

    @world ||= {
      "rev" => summary["rev"].to_i, "part" => summary["part"].to_s, "route" => summary["route"].to_s,
      "done" => summary["done"].to_a, "open" => summary["open"].to_a, "checkpoints" => summary["checkpoints"].to_a, "start" => summary["start"],
      "comps" => @comps.to_a, "caps" => caps,
    }
  end

  # Lists the level caps of the Level Cap milestones the player's story beat, which the catch-up
  # experience reads, worked out once per story written into theirs.
  #
  # @return [Array<Integer>] The caps, lowest first.
  def self.caps
    @caps ||= defined?(MGQ_MpRaidPool) ? MGQ_MpRaidPool.beaten_caps([MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables)]) : []
  rescue => e
    log_once(:caps, "listing the level caps the story unlocked failed: #{e.class}: #{e.message}")
    @caps = []
  end

  # Finds where a teleport to the story goes. The relay's tracks keep no endpoint of the story, so
  # MGQ_MpCoopGather goes where this game last saw the story told.
  #
  # @return [nil] Always nil.
  def self.endpoint
    nil
  end

  # Lists the routes the world may still take at the Great Decision, as the relay's summary names
  # them: the relay keeps the route rules.
  #
  # @return [Array<Integer>, nil] The routes' places in ROUTES, nil outside a Raid World, before
  #   the relay told the world's summary or when none is open.
  def self.decision_routes
    world = active? ? self.world : nil
    routes = world ? world["open"].map { |route| ROUTES.index(route) }.compact : []
    routes.empty? ? nil : routes
  end

  # Takes how the story on tracks stands, which the DLL posts whenever it changed.
  #
  # @param status [Hash] The status, see StoryTopics.StatusOf in the DLL.
  def self.status=(status)
    @status = status
    @world = nil
    note_awaited
  end

  # The track the player plays, which tells the others who views their telling.
  #
  # @return [String, nil] "world" or the player's own track, nil before the relay placed them.
  def self.track
    @status && @status["synced"] ? @status["track"].to_s : nil
  end

  # The part of the track the player plays, which bounds the story events they may start while
  # behind the world's (see MGQ_MpCoopEvents.leaving_part).
  #
  # @return [String, nil] Such as "2", nil before the relay placed them.
  def self.part
    @status && @status["synced"] ? @status["part"].to_s : nil
  end

  # Finds the telling of another player on the player's track, as the relay told of it, see
  # MGQ_MpCoop::Scope::Raid.
  #
  # @param seat [Integer] The player's seat.
  # @return [Array, nil] The telling's id, map and site, nil for none the relay told of.
  def self.telling_of(seat)
    tellings = @status && @status["tellings"]
    tellings ? tellings[seat] : nil
  end

  # The fields the world's story adds to the state the player's game tells the others.
  #
  # @return [Hash] "trk", the player's track, while the relay placed them.
  def self.state_fields
    track = active? ? self.track : nil
    track ? { "trk" => track } : {}
  rescue
    {}
  end

  # Takes the requests of the player the relay did not keep as written: a route variable another
  # route keeps, refused, brings back the companions of the player's own decision once the world's
  # value is written into their story.
  #
  # @param refusals [Array<Array>] Each key, code and the relay's value, nil for none.
  def self.refused(refusals)
    refusals.each do |key, code, value|
      log_once([:refused, key, code], "the relay did not keep #{key} as written (#{code})#{value ? ", it keeps #{value}" : ''}")
      @route_refused = true if ROUTE_CODES.include?(code) && ROUTE_VARIABLES.any? { |id| key == "v#{id}" }
    end
  rescue => e
    log("taking the relay's refusals failed: #{e.class}: #{e.message}")
  end

  # Takes the relay's push that the world's shared companions changed, which this game fetches.
  # Called by overworld_sync.rbx.
  #
  # @param message [Hash] The push: MGQ_MpOverworldSync::STORY_FIELD with the revision, and
  #   :relay, which no player's message carries.
  def self.pushed(message)
    return log("ignored a story push not from the relay") unless message[:relay]

    @fetch_due = true if active?
  rescue => e
    log("taking the relay's push failed: #{e.class}: #{e.message}")
  end

  # Starts the player's story anew on the relay's tracks, as a loaded save or a new game bring their
  # own: a new game is placed anew by its story.
  #
  # @param reason [Symbol] :load or :new_game.
  def self.loaded(reason)
    return unless active?

    log("#{reason == :load ? 'a save was loaded' : 'a new game started'}: the relay places the player on a track again")
    MGQ_MpStoryKeys.drop
    forget(reason)
    @fetch_due = true
    enter(reason == :new_game)
  rescue => e
    log("following a #{reason} failed: #{e.class}: #{e.message}")
  end

  # Follows the world's story for one frame: the mapping, the story the relay asks for, the teller
  # the player watches and their level, and what the relay handed back once the player is free.
  # Called after the map's update.
  def self.tick
    @clock += 1
    follow_classic
    return close unless active?

    note_world
    MGQ_MpStoryKeys.recording = :raid
    load_classes
    send_seed
    note_teller
    take_pending if quiet?
    play_queued
    walk_stream
    if @clock - @checked >= CHECK_FRAMES
      @checked = @clock
      send_level
      restore if quiet?
    end
    follow_comps
  rescue => e
    log_once(:tick, "following the world's story failed: #{e.class}: #{e.message}")
  end

  # Has the DLL fetch the story mapping in a Classic world too, whose catch-up tables hold the
  # rewards a party member catches up with (coop_story.rbx), and looks whether they came.
  def self.follow_classic
    id = MGQ_MpCoop::Scope.raid? || !MGQ_MpOverworldSync.in_world? ? "" : world_id
    MGQ_MpStoryState.rewards unless id.empty?
    return if id == @classic_world_id.to_s

    @classic_world_id = id.empty? ? nil : id
    log(id.empty? ? "the Classic world closed" : "a Classic world is open (#{id[0, 12]}): the DLL fetches the story mapping for the rewards a party member catches up with")
    MGQ_Multiplayer::Bridge.stage(MAPPING_TOPIC, @classic_world_id)
  end

  # Notes the open world, starting its story when it is another than the last.
  def self.note_world
    id = world_id
    return if id == @world_id

    forget(:entry)
    @world_id = id
    @greeted = false
    @behind_told = false
    @comps = nil
    @fetch_due = true
    log("a Raid World is open (#{id[0, 12]}): the relay places the player on a track")
    enter(false)
  end

  # Starts the player's story on the relay's tracks.
  #
  # @param fresh [Boolean] Whether the relay places the player anew by their story, as a new game.
  def self.enter(fresh)
    MGQ_Multiplayer::Bridge.stage(ENTER_TOPIC, "world" => world_id, "fresh" => fresh, "level" => level_now)
  end

  # Takes the story mapping's table once the DLL holds another revision than this script.
  def self.load_classes
    rev = @status && @status["classes"]
    table = MGQ_MpStoryKeys.raid_table
    return if rev.nil? || (table && table.rev == rev)

    MGQ_MpStoryKeys.load_raid
  end

  # Hands the relay the player's story it asks for to place them by: every key the mapping keeps
  # and every chest flag, at its value, those never set left out.
  def self.send_seed
    return unless @status && @status["need_seed"]
    return if @seeded_at && @clock - @seeded_at < SEED_FRAMES

    seed = seed_of(MGQ_MpStoryKeys.raid_table)
    return unless seed

    @seeded_at = @clock
    MGQ_Multiplayer::Bridge.stage(SEED_TOPIC, seed)
    log("handed the relay the player's story to place them by: #{seed.size} key(s)")
  end

  # Lists the player's story as a seed: each key the mapping keeps or a chest's, at its value.
  #
  # @param table [MGQ_MpStoryKeys::Table, nil] The story mapping's table.
  # @return [Hash{String => String}, nil] The keys and their values, nil before the table came.
  def self.seed_of(table)
    return nil unless table

    seed = {}
    switches = MGQ_MpStoryState.data_of($game_switches)
    variables = MGQ_MpStoryState.data_of($game_variables)
    switches.each_with_index do |value, id|
      seed["s#{id}"] = "1" if value && MGQ_MpStoryKeys.class_of(0, id, nil, table) & MGQ_MpStoryKeys::REQUESTED != 0
    end
    table.kept_variables.each do |id|
      text = MGQ_MpStoryKeys.text_of(1, variables[id])
      seed["v#{id}"] = text if text && text != "n0"
    end
    MGQ_MpStoryState.data_of($game_self_switches).each do |key, value|
      seed[MGQ_MpStoryKeys.key_text(2, key)] = "1" if value && MGQ_MpStoryKeys.class_of(2, key, nil, table) & MGQ_MpStoryKeys::REQUESTED != 0
    end
    seed
  end

  # Reports whether what the relay handed may be written into the player's story now: on the map or
  # behind a menu, with no event of the player's own running, outside battles and transfers.
  #
  # @return [Boolean] Whether it may.
  def self.quiet?
    return false if $game_party.in_battle || MGQ_MpCoopEvents.pvp_running?
    return false if $game_player && $game_player.transfer?

    !$game_map.interpreter.running?
  end

  # Writes what the relay handed into the player's story once the story mapping's table came: a new
  # game's opening that the world's story is past runs its setup first (world_opening.rbx). Nothing
  # is written while a lost raid boss battle's defeat runs (see holding?).
  def self.take_pending
    return unless MGQ_MpStoryKeys.raid_table
    return if holding?

    take = @status && @status["pending"] ? MGQ_Multiplayer::Bridge.call(TAKE_TOPIC) : nil
    @waiting = merge_takes(@waiting, take) if take
    return unless @waiting

    state = @waiting["state"]
    if state && defined?(MGQ_MpWorldOpening)
      return if MGQ_MpWorldOpening.before_take("p" => MGQ_MpStoryState.decode_value(state["keys"]["v#{MAIN_PROGRESS}"] || "n0").to_i) == :wait
    end

    waiting = @waiting
    @waiting = nil
    apply(waiting)
  rescue => e
    log("writing the world's story into the player's failed: #{e.class}: #{e.message}")
  end

  # Joins a take with the one that waits: a whole track replaces everything before it, keys follow.
  #
  # @param waiting [Hash, nil] The take that waits.
  # @param take [Hash] The new take, see StoryTopics.TakeOf in the DLL.
  # @return [Hash] The joined take.
  def self.merge_takes(waiting, take)
    return take if waiting.nil? || take["state"]

    waiting.merge("keys" => waiting["keys"] + take["keys"], "rev" => take["rev"])
  end

  # Writes what the relay handed into the player's story: a whole track over every key the mapping
  # keeps, then the keys pushed or answered; then follows what it brought: the player's track, the
  # world's story where its log starts, the frozen fights, the scene switches left on, the catch-up,
  # the choices and routes it carried them past. The frozen fights' write journal leaves every kind
  # of these writes out.
  #
  # @param take [Hash] The take, see StoryTopics.TakeOf in the DLL.
  def self.apply(take)
    state = take["state"]
    @log_story = story_of_keys(state["log"]) if state
    before = MGQ_MpStoryState.deep_copy(MGQ_MpStoryState.raw_state)
    own = local_counters(before)
    first = @mode.nil?
    freezes = {}
    written = 0
    unjournaled do
      MGQ_MpStoryKeys.applying do
        written += lay_over(state, freezes) if state
        take["keys"].each { |key, value| written += 1 if put_key(key, value, freezes) }
      end
    end
    MGQ_MpWorldFreeze.take_keys(freezes) if defined?(MGQ_MpWorldFreeze) && !freezes.empty?
    $game_map.need_refresh = true if written > 0
    @caps = nil
    @world = nil
    after = local_counters(MGQ_MpStoryState.raw_state)
    log("wrote the relay's #{state ? "#{state['track']} track (#{state['why']}) and " : ''}#{take['keys'].size} key(s) at revision #{take['rev']}: " \
        "#{written} changed, #{counters_text(own)} -> #{counters_text(after)}")
    # The catch-up follows a move on and what the story carried the player past while the mode
    # is still the one they came from, as a move at a level cap holds that story's rewards back.
    MGQ_MpWorldCatchup.moved(state["move"], world) if state && state["move"] && defined?(MGQ_MpWorldCatchup)
    follow_catchup(before, written > 0 || state, state ? mode_of(state) : @mode)
    took_state(state) if state
    unjournaled { end_left_scenes }
    followed(own, after, first && state ? true : false, state && state["move"] ? true : false)
    @returned_route = nil
    route_taken if @route_refused
  end

  # The world's story where its log starts, as the last whole track handed it, for the catch-up.
  #
  # @return [Array, nil] The switches, variables and self switches, each by key; nil while the
  #   relay named none.
  def self.log_story
    @log_story
  end

  # Reads a story from keys as the tracks name them.
  #
  # @param keys [Hash{String => String}, nil] Each key with its value, nil for none.
  # @return [Array, nil] The switches on, the variables and the self switches on, each by key; nil
  #   for none.
  def self.story_of_keys(keys)
    return nil unless keys

    story = [{}, {}, {}]
    keys.each do |name, value|
      kind, key = MGQ_MpStoryKeys.key_of(name)
      if kind == 1
        story[1][key] = MGQ_MpStoryState.decode_value(value)
      elsif kind && kind < 3 && value == "1"
        story[kind][key] = true
      end
    end
    story
  end

  # Writes a whole track into the player's story: every key the mapping keeps at the track's value,
  # one the track never wrote off, but those the player's own unanswered requests wrote, and the
  # player's chest flags.
  #
  # @param state [Hash] The track, see StoryTopics.TakeOf in the DLL.
  # @param freezes [Hash{Integer => String}] Takes the frozen fights by troop.
  # @return [Integer] How many keys changed.
  def self.lay_over(state, freezes)
    table = MGQ_MpStoryKeys.raid_table
    keys = state["keys"]
    held = {}
    state["held"].each { |key| held[key] = true }
    written = 0
    table.kept_switches.each do |id|
      key = "s#{id}"
      written += 1 if !held[key] && put_key(key, keys[key] || "0", freezes)
    end
    table.kept_variables.each do |id|
      key = "v#{id}"
      written += 1 if !held[key] && put_key(key, keys[key] || "n0", freezes)
    end
    selves = MGQ_MpStoryState.data_of($game_self_switches).keys.map { |key| MGQ_MpStoryKeys.key_text(2, key) } | keys.keys.select { |key| key.start_with?("ss") }
    selves.each do |key|
      kind, self_key = MGQ_MpStoryKeys.key_of(key)
      next unless kind == 2 && !held[key] && MGQ_MpStoryKeys.class_of(2, self_key, nil, table) & MGQ_MpStoryKeys::KEPT != 0

      written += 1 if put_key(key, keys[key] || "0", freezes)
    end
    keys.each { |key, value| freezes[key[1..-1].to_i] = value if key.start_with?("f") }
    state["chests"].each { |key, value| written += 1 if put_key(key, value, freezes) }
    written
  end

  # Writes one key the relay handed into the player's story: a switch or self switch past the
  # game's own handling, a variable through it (the game keeps some in its global system); a frozen
  # fight goes to world_freeze.rbx. A key a frozen raid boss fight holds takes its held value; a
  # local step the player plays where it stays theirs, a value below the player's own of a key the
  # whole world keeps going only up, such as affection, and an unlock the player holds, such as the
  # second accessory slot, stay the player's (the latter two asked of the relay again).
  #
  # @param key [String] The key, see MGQ_MpStoryKeys.key_of.
  # @param text [String] Its value as the tracks keep it.
  # @param freezes [Hash{Integer => String}] Takes the frozen fights by troop.
  # @return [Boolean] Whether the player's story changed.
  def self.put_key(key, text, freezes)
    kind, id = MGQ_MpStoryKeys.key_of(key)
    return false unless kind
    return (freezes[id] = text) && false if kind == 3

    value = kind == 1 ? MGQ_MpStoryState.decode_value(text) : text == "1"
    held = defined?(MGQ_MpWorldFreeze) ? MGQ_MpWorldFreeze.held_value(kind, id) : nil
    value = held[1] if held
    return false if kind == 1 && (local_step?(id) || kept_higher?(id, value))
    return false if kind == 0 && kept_unlock?(id, value)

    put(kind, id, value)
  end

  # Writes a value into the player's story when it differs.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @param value [Object] The value.
  # @return [Boolean] Whether it changed.
  def self.put(kind, key, value)
    if kind == 1
      return false if same?(1, $game_variables[key], value)

      $game_variables[key] = value
      return true
    end

    data = MGQ_MpStoryState.data_of(kind == 0 ? $game_switches : $game_self_switches)
    return false if same?(kind, data[key], value)

    data[key] = value ? true : false
    true
  end

  # Reports whether a variable's step stays the player's own where they stand, as the Queen's Cup's
  # tournament steps where it plays (the story mapping's local steps).
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it does.
  def self.local_step?(id)
    steps, _shared_as, places = MGQ_MpStoryKeys.raid_table.local_steps[id]
    return false unless steps && steps.include?($game_variables[id].to_i) && $game_player

    places.any? { |map, from_x| $game_map.map_id == map && $game_player.x >= from_x }
  end

  # Reports whether a variable the whole world keeps going only up, such as affection, holds a
  # higher value in the player's story than the relay handed, which stays and is asked of the relay
  # again: the relay keeps the highest.
  #
  # @param id [Integer] The variable.
  # @param value [Object] The value the relay handed.
  # @return [Boolean] Whether it does.
  def self.kept_higher?(id, value)
    found = MGQ_MpStoryKeys.class_of(1, id, nil, MGQ_MpStoryKeys.raid_table)
    whole_one_way = MGQ_MpStoryKeys::ONE_WAY | MGQ_MpStoryKeys::WHOLE_WORLD
    own = $game_variables[id]
    return false unless found & whole_one_way == whole_one_way && own.is_a?(Integer) && value.is_a?(Integer) && own > value

    MGQ_MpStoryKeys.request("v#{id}", MGQ_MpStoryKeys.text_of(1, own), "game")
    true
  end

  # Reports whether a switch the game turns on for good and never off, such as the second accessory
  # slot (MGQ_MpStoryState::UNLOCK_SWITCHES), is on in the player's story while the relay handed it
  # off, which stays and goes to the relay: an earlier build kept it each player's own and never
  # wrote it for the world.
  #
  # @param id [Integer] The switch.
  # @param value [Boolean] The value the relay handed.
  # @return [Boolean] Whether it does.
  def self.kept_unlock?(id, value)
    return false if value || !MGQ_MpStoryState::UNLOCK_SWITCHES.include?(id) || !$game_switches[id]

    MGQ_MpStoryKeys.request("s#{id}", "1", "game")
    true
  end

  # Tells how the player plays the track the relay handed whole.
  #
  # @param state [Hash] The track.
  # @return [Symbol] :world on the world's track, :behind on a track of their own.
  def self.mode_of(state)
    state["track"] == WORLD_TRACK ? :world : :behind
  end

  # Follows the track the relay handed whole: the player plays the world's or their own, and the
  # catch-up hears of a fall behind.
  #
  # @param state [Hash] The track.
  def self.took_state(state)
    was = @mode
    @mode = mode_of(state)
    @awaited_since = nil
    if @mode == :world && !@greeted
      @greeted = true
      MGQ_MpOverworldSync.notice("You play the world's story.")
    end
    return unless defined?(MGQ_MpWorldCatchup)
    return unless @mode == :behind && (was != :behind || state["why"] == "behind")

    MGQ_MpWorldCatchup.behind(state["part"].to_s, state["gate"])
    return if @behind_told

    @behind_told = true
    MGQ_MpOverworldSync.notice(MGQ_MpWorldCatchup.behind_text(state["part"].to_s))
  end

  # Hands the catch-up the story written into the player's: the world's while they play it, and what
  # it carried them past.
  #
  # @param before [Array] The player's story before.
  # @param changed [Boolean] Whether it changed.
  # @param mode [Symbol, nil] How the player plays the story now, see mode.
  def self.follow_catchup(before, changed, mode)
    return unless defined?(MGQ_MpWorldCatchup) && changed

    MGQ_MpWorldCatchup.world_told(mode == :world ? MGQ_MpStoryState.raw_state : nil)
    MGQ_MpWorldCatchup.carried(before)
  end

  # Turns off the scene switches still on while no scene runs, as a story written mid-scene may
  # carry them: the story mapping's scene switches. Not while the player watches a teller's scene,
  # which shows them.
  def self.end_left_scenes
    return if defined?(MGQ_MpCoopScene) && MGQ_MpCoopScene.pending?

    table = MGQ_MpStoryKeys.raid_table
    return unless table

    left = (0...table.switches.bytesize).select { |id| table.switches.getbyte(id) & MGQ_MpStoryKeys::SCENE != 0 && $game_switches[id] }
    return if left.empty?

    MGQ_MpStoryKeys.applying { left.each { |id| $game_switches[id] = false } }
    log("turned off scene switch(es) #{left.join(', ')}, which no scene runs for")
  end

  # Reads the value a frozen raid boss fight holds a key at, which the player's writes of it carry
  # instead (see world_freeze.rbx). Called by story_keys.rbx for each write.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @param value [Object] The value written.
  # @return [Object] The value the write carries.
  def self.held_value(kind, key, value)
    held = defined?(MGQ_MpWorldFreeze) ? MGQ_MpWorldFreeze.held_value(kind, key) : nil
    held ? held[1] : value
  end

  # Writes a frozen raid boss fight as the player's request, or "0" once it ended, for the whole
  # world. Called by world_freeze.rbx.
  #
  # @param troop [Integer] The fight's troop.
  # @param text [String] The fight as world_freeze.rbx writes it after its troop, or "0".
  # @return [Boolean] Whether it goes to the relay: false unless the world's story applies.
  def self.write_freeze(troop, text)
    return false unless active?

    MGQ_MpStoryKeys.request("f#{troop}", text, "game:freeze")
  end

  # Reports whether the world's story and the catch-up wait while a lost raid boss battle's defeat
  # runs, which sets back what the battle's undo puts again and takes the items it gives back (see
  # battles_raid_freeze.rbx). Logs once as a hold starts and as it ends.
  #
  # @return [Boolean] Whether they wait.
  def self.holding?
    holding = defined?(MGQ_MpRaidFreeze) && MGQ_MpRaidFreeze.holding_writes? ? true : false
    if holding != (@holding ? true : false)
      log(holding ? "a lost raid boss battle's defeat runs: the world's story and the catch-up wait until its undo ran" : "the lost raid boss battle's defeat ended: the world's story and the catch-up go on")
    end
    @holding = holding
  rescue => e
    log_once(:holding, "looking whether a lost raid boss battle holds the story failed: #{e.class}: #{e.message}")
    false
  end

  # Runs a block whose writes the frozen fights' write journal leaves out (see
  # MGQ_MpRaidFreeze.unjournaled): the world's story is no event's or defeat's to put back.
  #
  # @yieldreturn [Object] What the block returns.
  # @return [Object] What the block returned.
  def self.unjournaled
    defined?(MGQ_MpRaidFreeze) ? MGQ_MpRaidFreeze.unjournaled { yield } : yield
  end

  # Ends a collab the world's story cleared, once no event of the player's runs.
  def self.restore
    return if holding? || !leave_cleared_collab

    $game_map.need_refresh = true
    log("left the collab scenario the world's story cleared: gave back the stored items and equipment and returned to the Pocket Castle")
  end

  # Refuses the Pocket Castle's event that starts the collab scenario in a Raid World, telling the
  # player why: one player's collab would put the whole world into it.
  #
  # @param event [Game_Event] The event that starts.
  # @return [Boolean] Whether it refused it.
  def self.collab_refused?(event)
    return false unless active? && $game_map.map_id == COLLAB_START[0] && event.id == COLLAB_START[1] && $game_variables[COLLAB_VARIABLES.first].to_i < COLLAB_STARTED

    MGQ_MpOverworldSync.notice("The collab scenario is turned off in Raid Worlds.")
    true
  end

  # Ends the Pocket Castle's collab scenario for a player still on its maps once the world's story
  # cleared its progress, as its own exit does: the collab party goes, the items and equipment its
  # start stored come back, its switches go off and the player returns to the castle, out of the
  # scenario's scene (see MGQ_MpCoopScene::Own.leave).
  #
  # @return [Boolean] Whether it ended it.
  def self.leave_cleared_collab
    return false unless COLLAB_MAPS.any? { |maps| maps === $game_map.map_id }
    return false unless COLLAB_VARIABLES.all? { |id| $game_variables[id].to_i <= (id == COLLAB_VARIABLES.first ? COLLAB_ARRIVED : 0) }

    interpreter = $game_map.interpreter
    interpreter.release_temp_actors if $game_party.respond_to?(:temp_actors_use?) && $game_party.temp_actors_use?
    MGQ_MpCoopScene::Own.leave("the world's story cleared the collab scenario", true) if defined?(MGQ_MpCoopScene::Own)
    interpreter.take_all_item
    COLLAB_SWITCHES.each { |id| $game_switches[id] = false }
    $game_player.reserve_transfer(*COLLAB_RETURN)
    true
  end

  # Follows what the world's story brought: the choices it carried the player past and the Great
  # Decision's route, both when one story carries them past earlier choices onto a route; and the
  # personal half of the world's return to the Great Decision when the world left the route the
  # player was on. The first track handed after entering, a load or a new game also asks the choices
  # a later build added that the player's save is past without having made them, see
  # MGQ_MpCoopChoices.missed.
  #
  # @param before [Hash] The player's counters before.
  # @param after [Hash] The counters of the story written into theirs.
  # @param first [Boolean] Whether it is the first track since entering, a load or a new game.
  # @param moved [Boolean] Whether the relay moved a player behind on, whose return the catch-up plays.
  def self.followed(before, after, first = false, moved = false)
    left = route_index(before)
    done = world ? world["done"] : []
    if left && left != route_index(after) && left != @returned_route && !first && !moved && done.include?(ROUTES[left])
      @returned_route = left
      returned(before)
    end
    return unless defined?(MGQ_MpCoopChoices)

    MGQ_MpCoopChoices.missed(after["p"]) if first
    MGQ_MpCoopChoices.story_passed(before["p"], after["p"]) if after["p"] > before["p"]
    route = route_index(after)
    MGQ_MpCoopChoices.raid_decision(route) if route && route_index(before) != route && after["p"] >= GREAT_DECISION
  end

  # Gives the player the personal half of the world's return to the Great Decision, which the game
  # of the player who finished the route played: the Final Chapter's reset (common event 154), which
  # takes the route's passes, resets its maps' chests and the route's progress, where a game over
  # returns them, and the transfer to the Great Decision's hall, as the route's maps hold nothing more.
  #
  # @param before [Hash] The player's counters before.
  def self.returned(before)
    side = MGQ_MpStoryState.data_of($game_switches)[MGQ_MpStoryState::ILIAS_CHOSEN] ? 1 : 0
    @queued = [command(117, [FINAL_RESET_EVENT]), command(122, [GAME_OVER_RETURN, GAME_OVER_RETURN, 0, 0, RETURN_POINTS[side]]),
               command(122, [TRANSFER_MAP, TRANSFER_MAP, 0, 0, DECISION_PLACE[0]]), command(201, [0, TRANSFER_RELAY_MAP, DECISION_PLACE[1], DECISION_PLACE[2], 8, 2]), command(0, [])]
    log("the world went back to the Great Decision from the #{ROUTE_NAMES[route_index(before)]} route: the Final Chapter's reset waits to play once the player is free")
    MGQ_MpOverworldSync.notice("The world's story went back to the Great Decision.")
  end

  # Reports whether commands wait to play once the player is free, as the personal half of a
  # return to the Great Decision.
  #
  # @return [Boolean] Whether they do.
  def self.queued?
    @queued ? true : false
  end

  # Plays the commands that wait, once the player is free on the map, taking the player out of a
  # scene of their own first (see MGQ_MpCoopScene::Own.leave), such as their route's ending walked
  # in a temporary party, whose own end the return would cut off.
  #
  # The return plays whether or not such a scene runs: nothing tells an ending's walk from a long
  # part played in a temporary party, so waiting for it might keep the player off the world's story.
  def self.play_queued
    return unless @queued && MGQ_MpOverworldSync.map_free?

    commands = @queued
    @queued = nil
    MGQ_MpCoopScene::Own.leave("the world went back to the Great Decision", true) if defined?(MGQ_MpCoopScene::Own)
    log("playing #{commands.map { |entry| entry.code }.join(' ')} now")
    $game_map.interpreter.setup(commands, 0)
  end

  # Hands a run of the player's own game that changed the world's story to the relay, after the
  # writes recorded before it. Called by story_keys.rbx with the entry the DLL answered for the run.
  #
  # @param entry [Hash] The run's entry, see ReplayEntry.Write in the DLL.
  # @return [Boolean] Whether it went: false outside a Raid World's story.
  def self.hand_entry(entry)
    return false unless active?

    MGQ_MpStoryKeys.flush
    MGQ_Multiplayer::Bridge.stage(HAND_TOPIC, entry)
    true
  rescue => e
    log_once([:hand_entry, e.class], "handing a run over failed: #{e.class}: #{e.message}")
    false
  end

  # Hands the replay the next run of the player's track, which the DLL gives once the replay took
  # the one before and while the player stands free.
  def self.walk_stream
    return unless defined?(MGQ_MpStoryReplay)

    waiting = MGQ_MpStoryReplay.waiting.map { |entry| entry["id"] }
    entry = MGQ_Multiplayer::Bridge.call(STREAM_TOPIC, "free" => MGQ_MpStoryReplay.free?, "waiting" => waiting)
    MGQ_MpStoryReplay.receive(entry) if entry.is_a?(Hash)
  end

  # Tells the player that the world took another route before theirs reached the relay, and takes
  # them to the story.
  def self.route_taken
    @route_refused = false
    restore_roster
    world = self.world
    route = ROUTES.index(world && world["route"])
    MGQ_MpOverworldSync.notice(route ? "The world took the #{ROUTE_NAMES[route]} route first." : "The world's story goes on without your route.")
    MGQ_MpCoopGather.join_story if defined?(MGQ_MpCoopGather)
  end

  # Brings back the companions the player's own branch of the Great Decision took away, once the
  # world took another route first, whose own half then plays (see followed) as for any player the
  # world's story carries past the decision.
  def self.restore_roster
    roster = @decision_roster
    @decision_roster = nil
    return unless roster

    missing = roster - MGQ_MpStoryState.roster_ids
    log("the world took another route: bringing back the companions the player's own decision took away (#{missing.join(', ')})") unless missing.empty?
    missing.each { |id| MGQ_MpStoryState.bring(id) }
  end

  # Notes a player telling the story on the map whose scene the player watches, which the relay
  # hears, and when they stop.
  def self.note_teller
    teller = MGQ_MpCoop::Scope.teller
    seat = teller.is_a?(MGQ_MpOverworldSync::Peers::Peer) && @mode && MGQ_MpCoop::Scope.watches?(teller) ? teller.seat : nil
    return if seat == @watching

    @watching = seat
    MGQ_Multiplayer::Bridge.stage(WATCH_TOPIC, seat)
  end

  # Reports whether the player's story events wait for the world's story of a telling on their
  # track that ended, until the DLL's take wrote the track's revision it ended at into the player's
  # story (the status's "await"), AWAIT_TELLER_FRAMES at most: the player's game would play the
  # scene again before. Called by coop_events.rbx.
  #
  # @return [Boolean] Whether they wait.
  def self.awaits_teller?
    awaited = @awaited_telling
    return false unless awaited && active?
    return true if @clock - awaited[:since] < AWAIT_TELLER_FRAMES
    return false if awaited[:lapsed]

    log("the world's story of the telling seat #{awaited[:telling][0]} ended did not come within #{AWAIT_TELLER_FRAMES / 60} s: the player's story events start without it")
    awaited[:lapsed] = true
    false
  end

  # Notes the ended telling whose world's story the player's story events wait for, and since
  # when, as the status names a new one, see awaits_teller?.
  def self.note_awaited
    seat = @status && @status["await"]
    return @awaited_telling = nil if seat.nil?

    told = @status["told"]
    telling = [seat, told ? told[seat] : nil]
    @awaited_telling = { :telling => telling, :since => @clock } unless @awaited_telling && @awaited_telling[:telling] == telling
  end

  # Names the player whose telling ended, whose world's story the player's story events wait for,
  # see awaits_teller?.
  #
  # @return [String, nil] Their name, nil when the player waits for nobody's or the DLL names a
  #   seat this game knows nobody on.
  def self.watched_teller
    seat = @status && @status["await"]
    peer = seat.nil? || !MGQ_MpOverworldSync::Peers.respond_to?(:all) ? nil : MGQ_MpOverworldSync::Peers.all.find { |each| each.seat == seat }
    name = peer && peer.state["name"].to_s
    name && !name.empty? ? name : nil
  end

  # Tells the relay the player's level once it changed, which its level gates read.
  def self.send_level
    level = level_now
    return if level.nil? || level == @level_sent

    @level_sent = level
    MGQ_Multiplayer::Bridge.stage(LEVEL_TOPIC, level)
  end

  # Reads the player's level as the relay's gates read it: the highest base level among their
  # characters, and the highest level the game lets that character reach.
  #
  # @return [Hash, nil] "best" and "cap" (nil without one), nil before the party has members.
  def self.level_now
    best = MGQ_MpStoryState.roster.max_by { |actor| actor.base_level }
    return nil unless best

    cap = best.respond_to?(:max_level) ? best.max_level(:base) : nil
    { "best" => bounded_level(best.base_level), "cap" => cap.is_a?(Integer) ? bounded_level(cap) : nil }
  rescue
    nil
  end

  # Bounds a level to what the relay's gates take.
  #
  # @param level [Integer] The level.
  # @return [Integer] The level, 1 to MAX_LEVEL.
  def self.bounded_level(level)
    [[level.to_i, 1].max, MAX_LEVEL].min
  end

  # Fetches the world's shared companions when due: on entering the world, once a minute and on the
  # relay's push; and takes them once a fetch ended.
  def self.follow_comps
    if @busy
      return unless @clock - @busy >= STATE_FRAMES

      @busy = @clock
      state = Relay.headers
      return if state["fetch"].nil? || state["fetch"] == "busy"

      @busy = nil
      return unless state["world"] == world_id && state["fetch"] == "done"

      @comps = state["comps"].to_s.split(",").map { |id| id.to_i }
      @world = nil
      return
    end
    @fetch_due = true if @polled.nil? || @clock - @polled >= POLL_FRAMES
    return unless @fetch_due

    @fetch_due = false
    @polled = @clock
    @busy = @clock if Relay.fetch(world_id)
  end

  # Reads the counters of a story: the main story, the route under way alone (the first whose
  # variable is above 0), and the routes cleared.
  #
  # @param story [Array] The switches and variables.
  # @return [Hash] "p", "r1141", "r1142", "r1143" and "clear".
  def self.local_counters(story)
    variables = story[1]
    counters = { "p" => [variables[MAIN_PROGRESS].to_i, 0].max }
    route = ROUTE_VARIABLES.index { |id| variables[id].to_i > 0 }
    ROUTE_VARIABLES.each_with_index { |id, index| counters["r#{id}"] = index == route ? variables[id].to_i : 0 }
    counters["clear"] = ROUTES.select { |name| story[0][CLEAR_SWITCHES[ROUTES.index(name)]] }
    counters
  end

  # Writes counters for the log.
  #
  # @param counters [Hash] The counters, see local_counters.
  # @return [String] Such as "p=40;r1141=12;r1142=0;r1143=0;clear=mr".
  def self.counters_text(counters)
    "p=#{counters['p']};r1141=#{counters['r1141']};r1142=#{counters['r1142']};r1143=#{counters['r1143']};clear=#{counters['clear'].join(',')}"
  end

  # Finds the route under way.
  #
  # @param counters [Hash] The counters.
  # @return [Integer, nil] Its place in ROUTES, nil before the Great Decision or back at it.
  def self.route_index(counters)
    ROUTE_VARIABLES.index { |id| counters["r#{id}"].to_i > 0 }
  end

  # Finds the part a story is in, as the DLL and the relay count it (StoryParts in MGQOnline.Game):
  # the route under way, else Part 1 before Tartarus Escape, Part 2 before the Middle Chapter's
  # epilogue, else Part 3. Each place in the story is asked once.
  #
  # @param counters [Hash] The counters; those of the routes may be left out.
  # @return [String] "1", "2", "3", "ad", "mr" or "chaos"; empty when the DLL did not answer.
  def self.part_of(counters)
    request = { "p" => counters["p"].to_i, "routes" => ROUTE_VARIABLES.map { |id| counters["r#{id}"].to_i } }
    key = [request["p"]] + request["routes"]
    @parts ||= {}
    @parts[key] ||= MGQ_Multiplayer::Bridge.call(PART_TOPIC, request)
    @parts[key] || ""
  end

  # Compares two values of a story, a switch or self switch never set as off and a variable never
  # set as 0, as the game reads them.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param one [Object] The one value.
  # @param other [Object] The other.
  # @return [Boolean] Whether they are the same.
  def self.same?(kind, one, other)
    return (one.nil? ? 0 : one) == (other.nil? ? 0 : other) if kind == 1

    (one ? true : false) == (other ? true : false)
  end

  # Reports whether a switch, variable or self switch is the player's own, by the story mapping.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Boolean] Whether it is.
  def self.personal?(kind, key)
    !MGQ_MpStoryKeys.shared?(kind, key)
  end

  # Reports whether a switch or variable moves the world's story on as it changes: one that tells
  # how far the story is (PROGRESS_SWITCHES, PROGRESS_VARIABLES) or a variable the story mapping
  # keeps going only up, as a boss beaten or a quest's step.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable.
  # @param id [Integer] Its id.
  # @return [Boolean] Whether it does.
  def self.moves_on?(kind, id)
    return PROGRESS_SWITCHES.include?(id) if kind == 0

    PROGRESS_VARIABLES.include?(id) || MGQ_MpStoryKeys.bit?(1, id, MGQ_MpStoryKeys::ONE_WAY)
  end

  # Reads the values of the switches and variables that move the world's story on, see moves_on?.
  #
  # @return [Array] Their values, in an order that stays the same.
  def self.progress_now
    variables = MGQ_MpStoryState.data_of($game_variables)
    switches = MGQ_MpStoryState.data_of($game_switches)
    table = MGQ_MpStoryKeys.raid_table
    one_way = table ? table.kept_variables.select { |id| MGQ_MpStoryKeys.class_of(1, id, nil, table) & MGQ_MpStoryKeys::ONE_WAY != 0 } : []
    (PROGRESS_VARIABLES | one_way).map { |id| variables[id].to_i } + PROGRESS_SWITCHES.map { |id| switches[id] ? true : false }
  end

  # Reports whether event commands from a place on may move the world's story on: they set a
  # switch or variable that does (see moves_on?), themselves or in a common event they call, up to
  # PROGRESS_CALL_DEPTH deep, behind a branch taken or not.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param from [Integer] The place to read from.
  # @param depth [Integer] How many common events deep the list is.
  # @return [Boolean] Whether they may.
  def self.progress_ahead?(list, from, depth = 0)
    list[from..-1].to_a.any? do |entry|
      params = entry.parameters
      case entry.code
      when 121 then (params[0]..params[1]).any? { |id| moves_on?(0, id) }
      when 122 then (params[0]..params[1]).any? { |id| moves_on?(1, id) }
      when 117
        common = depth < PROGRESS_CALL_DEPTH && $data_common_events[params[0]]
        common ? progress_ahead?(common.list || [], 0, depth + 1) : false
      else false
      end
    end
  end

  # Makes an event command.
  #
  # @param code [Integer] Its code.
  # @param parameters [Array] Its parameters.
  # @param indent [Integer] Its indent.
  # @return [RPG::EventCommand] The command.
  def self.command(code, parameters, indent = 0)
    RPG::EventCommand.new(code, indent, parameters)
  end

  # Changes the command an interpreter is about to run in a Raid World: the Great Decision's choice
  # offers only the routes the world may still take, and the Reaper's reset menu becomes the return
  # to the Great Decision. Called before every event command.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.before_command(interpreter)
    list = MGQ_MpGame.get(interpreter, :list)
    index = MGQ_MpGame.get(interpreter, :index)
    command = list && index ? list[index] : nil
    return unless command && (command.code == 117 || command.code == 102)
    return unless MGQ_MpCoop::Scope.raid?

    changed = if command.code == 117 && command.parameters[0] == RESET_EVENT
                reset_list(list, index)
              elsif decision_choice?(list, command)
                decision_list(list, index)
              end
    MGQ_MpGame.set(interpreter, :list, changed) if changed
  rescue => e
    log("changing an event command failed: #{e.class}: #{e.message}")
  end

  # Reports whether a command is the Great Decision's choice of the routes.
  #
  # @param list [Array<RPG::EventCommand>] The commands it is in.
  # @param command [RPG::EventCommand] The command.
  # @return [Boolean] Whether it is.
  def self.decision_choice?(list, command)
    event = $data_common_events[DECISION_EVENT]
    command.code == 102 && command.parameters[0].is_a?(Array) && command.parameters[0].size == ROUTES.size && event && list.equal?(event.list) ? true : false
  end

  # Copies the Great Decision's commands with its choice of the routes cut down to those the world
  # may still take, see decision_routes. Notes the player's companions before their branch plays,
  # see restore_roster.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] Where the choice is.
  # @return [Array<RPG::EventCommand>, nil] The commands, nil when every route may still be taken.
  def self.decision_list(list, index)
    @decision_roster = MGQ_MpStoryState.roster_ids.dup
    routes = decision_routes
    return nil unless routes && routes.size < ROUTES.size

    choice = list[index]
    branches = []
    rest = list.size
    ((index + 1)...list.size).each do |at|
      entry = list[at]
      if entry.indent == choice.indent && entry.code == 404
        rest = at
        break
      end
      branches << { :route => entry.code == 402 ? entry.parameters[0] : nil, :commands => [] } if entry.indent == choice.indent
      branches.last[:commands] << entry if branches.last
    end
    kept = []
    branches.each do |branch|
      next kept.concat(branch[:commands]) if branch[:route].nil?
      next unless routes.include?(branch[:route])

      head = branch[:commands].first
      kept << command(402, [routes.index(branch[:route]), head.parameters[1]], head.indent)
      kept.concat(branch[:commands][1..-1])
    end
    labels = routes.map { |route| choice.parameters[0][route] }
    log("the Great Decision offers #{labels.join(' / ')}: the world may take no other route")
    list[0...index] + [command(102, [labels, cancel_type(choice.parameters[1], routes)] + choice.parameters[2..-1].to_a, choice.indent)] + kept + list[rest..-1]
  end

  # Moves a choice's cancel to the place its outcome has among the routes offered.
  #
  # @param type [Integer] The choice's cancel: 0 none, 1 to 4 an outcome, 5 its own branch.
  # @param routes [Array<Integer>] The routes offered.
  # @return [Integer] The cancel.
  def self.cancel_type(type, routes)
    return type unless type.to_i.between?(1, ROUTES.size)

    place = routes.index(type - 1)
    place ? place + 1 : 0
  end

  # Copies an event's commands with the call of the Reaper's reset menu replaced: at a finished
  # route's credits by the return to the Great Decision; at the Reaper's offer in Hades by the screen
  # faded in again, as the world's story goes on; anywhere else, such as the Chaos route's bad end,
  # by the screen faded in, the calling event erased and a teleport to the story.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] Where the call is.
  # @return [Array<RPG::EventCommand>] The commands.
  def self.reset_list(list, index)
    if route_credits?
      log("the route's credits call the Reaper's reset menu: the world goes back to the Great Decision instead")
      return return_list(list, index)
    end

    log("the Reaper's reset menu was called away from a route's credits: left out, the world's story goes on")
    MGQ_MpOverworldSync.notice("Time cannot be reset in a Raid World.")
    reaper = $data_common_events[REAPER_EVENT]
    call = list[index]
    return list[0...index] + [command(222, [], call.indent)] + list[(index + 1)..-1] if reaper && list.equal?(reaper.list)

    # The bad end's event on map 1889 runs by itself, and only the reset menu took the player away.
    MGQ_MpCoopGather.join_story if defined?(MGQ_MpCoopGather)
    list[0...index] + [command(222, [], call.indent), command(214, [], call.indent)] + list[(index + 1)..-1]
  end

  # Reports whether the Reaper's reset menu is called at a finished route's credits: the Angelic
  # Dominion or Monster Realm route under way with its clear switch on, which the credits set right
  # before. The Chaos route's ending calls no reset.
  #
  # @return [Boolean] Whether it is.
  def self.route_credits?
    counters = local_counters([MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables)])
    route = route_index(counters)
    route && route < ROUTES.size - 1 && counters["clear"].include?(ROUTES[route]) ? true : false
  end

  # Copies an event's commands with the call of the Reaper's reset menu replaced by the return to
  # the Great Decision.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] Where the call is.
  # @return [Array<RPG::EventCommand>] The commands.
  def self.return_list(list, index)
    call = list[index]
    list[0...index] + return_commands.map { |entry| command(entry.code, entry.parameters, entry.indent + call.indent) } + list[(index + 1)..-1]
  end

  # The world's return to the Great Decision: the game's own return of the player's side (common
  # event 267 or 268: the Final Chapter's reset, 1001 at 39, the warps of the castle, and the
  # transfer to the Great Decision's hall), without the companions it adds.
  #
  # @return [Array<RPG::EventCommand>] The commands.
  def self.return_commands
    side = MGQ_MpStoryState.data_of($game_switches)[MGQ_MpStoryState::ILIAS_CHOSEN] ? 1 : 0
    event = $data_common_events[RETURN_EVENTS[side]]
    list = event && event.list
    if list && list.any? { |entry| entry.code == 117 && entry.parameters[0] == FINAL_RESET_EVENT } && list.any? { |entry| entry.code == 201 }
      return list.reject { |entry| SCRIPT_CODES.include?(entry.code) }
    end

    log("the game's return to the Great Decision differs from the one known, so the world goes back without its scene")
    [command(117, [FINAL_RESET_EVENT]), command(122, [GAME_OVER_RETURN, GAME_OVER_RETURN, 0, 0, RETURN_POINTS[side]]),
     command(122, [MAIN_PROGRESS, MAIN_PROGRESS, 0, 0, BEFORE_DECISION]), command(122, [TRANSFER_MAP, TRANSFER_MAP, 0, 0, DECISION_PLACE[0]]),
     command(201, [0, TRANSFER_RELAY_MAP, DECISION_PLACE[1], DECISION_PLACE[2], 8, 2])]
  end

  # Reads a system switch of the game's endings in a Raid World: the world's clear switch of that
  # route, not the install's, so the third way opens for the world.
  #
  # @param key [Symbol] The system switch, such as :ed1.
  # @return [Boolean, nil] Whether the world cleared that route, nil for another switch or world.
  def self.world_ending(key)
    id = SYSTEM_ENDINGS[key]
    return nil unless id && MGQ_MpCoop::Scope.raid? && $game_switches

    MGQ_MpStoryState.data_of($game_switches)[id] ? true : false
  rescue
    nil
  end

  # Patch/Multiplayer/Multiplayer.dll's state of the world's shared companions at the relay.
  module Relay
    # Starts fetching the world's state with its shared companions.
    #
    # @param world [String] The world's id.
    # @return [Boolean] Whether it started.
    def self.fetch(world)
      MGQ_Multiplayer::Link.function('mp_raid_story_fetch').call(world + "\0") == 1
    rescue => e
      MGQ_MpWorldStory.log("fetching the shared companions failed: #{e.class}: #{e.message}")
      false
    end

    # Reads how each request stands and the newest state, with the shared companions.
    #
    # @return [Hash] The headers, see docs/DEVELOPER.md; empty before any request.
    def self.headers
      text = MGQ_Multiplayer::Link.read('mp_raid_story_headers', STATE_SIZE)
      text.empty? ? {} : MGQ_Multiplayer::Link.parse(text)
    rescue => e
      MGQ_MpWorldStory.log_once([:headers, e.class], "reading the shared companions failed: #{e.class}: #{e.message}")
      {}
    end
  end
end

# What this script takes part in of the world, through overworld_sync.rbx, and of the DLL's story
# on tracks, through the bridge.

begin
  MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::STORY_FIELD) { |_peer, message| MGQ_MpWorldStory.pushed(message) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpWorldStory.state_fields }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpWorldStory.close unless in_world }
  MGQ_Multiplayer::Bridge.on(MGQ_MpWorldStory::STATUS_EVENT) { |status| MGQ_MpWorldStory.status = status }
  MGQ_Multiplayer::Bridge.on(MGQ_MpWorldStory::REFUSED_EVENT) { |refusals| MGQ_MpWorldStory.refused(refusals) }
rescue => e
  MGQ_MpWorldStory.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the world's story.
  MGQ_MpHooks.after(Game_Map, :update, "world_story") { MGQ_MpWorldStory.tick }
  # The collab scenario's start, which a Raid World turns off.
  MGQ_MpHooks.around(Game_Event, :start, "world_story") { |event, _args, original| original.call unless MGQ_MpWorldStory.collab_refused?(event) } if defined?(Game_Event)

  # Before an event command runs, the Great Decision's choice and the Reaper's reset menu follow the world.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "world_story") { MGQ_MpWorldStory.before_command(self) }

  # A loaded save or a new game bring their own story, over which the world's is written. Not after
  # extract_save_contents, which a duel's end calls too to put the game back.
  MGQ_MpHooks.after(DataManager.singleton_class, :load_game_without_rescue, "world_story") { |_index| MGQ_MpWorldStory.loaded(:load) }
  MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "world_story") { MGQ_MpWorldStory.loaded(:new_game) }
rescue => e
  MGQ_MpWorldStory.log("hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # The game's endings read from the world's story in a Raid World, see world_ending.
  MGQ_MpHooks.around(Game_Interpreter, :ssw, "world_story") do |_interpreter, args, original|
    ended = MGQ_MpWorldStory.world_ending(args[0])
    ended.nil? ? original.call : ended
  end
rescue => e
  MGQ_MpWorldStory.log("ending hook FAILED: #{e.class}: #{e.message}")
end
