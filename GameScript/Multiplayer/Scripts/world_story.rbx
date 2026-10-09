#----------------------------------------------------------------
#  world_story.rbx
#
#  Changelog:
#      Paulinchen  2026-10-09: Read and wrote the story through the state model of story_state.rbx instead of coop_story.rbx
#                            - Kept a player behind the world's story on the checkpoint of their part and moved them on by their level through world_catchup.rbx, instead of letting them play their own story
#                            - Made the chests that hold the story's key items the whole world's, so each opens once for the world and stays open for a player who opened it
#                            - Kept a player behind until their level moves them on, also once the world returns from a route to their part
#                            - Read the world's shared companions and the parts it keeps checkpoints of from the relay's state
#                            - Brought back the companions the player's own Great Decision took away, with the notice and the teleport to the story, also when the relay refuses their write because another route was locked first
#                            - Asked the choices a story carried the player past also when the same story takes them onto a route
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# A Raid World's story, which the relay keeps for the whole world (see Relay/core/story.js). Every
# game fetches it as the world opens, after a save loaded or a new game, whenever the relay tells
# a newer revision, and once a minute, and lays it over the player's own values (the state model of
# story_state.rbx, `mix`), as long as the player's story is in the world's current part; a player in
# an earlier part is behind, and world_catchup.rbx keeps them on their part's checkpoint until their
# level moves them on. A game whose story moved on writes it back: its counters, which the relay
# reads, and the rest sealed, with the revision it built on. A refused write takes the world's story
# and drops the step that conflicts with it. Chests, the choices' outcomes and the side are each
# player's own, except the chests that hold the story's key items, which are the world's.
#
# The Great Decision: the first route that reaches the relay is the world's; the game's own choice
# offers only the routes the world may still take, and a player the world's story carries past the
# decision picks it on the screen of coop_choices.rbx. A finished route takes the world back to the
# Great Decision in place of the Reaper's reset menu (common event 265), which would drop companions;
# called anywhere else, the menu is left out, since one player must not take the whole world back.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldStory
  # Frames between two fetches while the relay tells nothing, a minute, in case a push was lost.
  POLL_FRAMES = 3600

  # Frames between two reads of the DLL's state while a request runs, a quarter of a second.
  STATE_FRAMES = 15

  # Frames between two looks at the story's progress, half a second.
  CHECK_FRAMES = 30

  # Frames between two comparisons of the whole story while it may have changed, a second.
  SCAN_FRAMES = 60

  # Frames between two comparisons of the whole story while nothing points to a change, ten
  # seconds, for what parallel events change.
  IDLE_SCAN_FRAMES = 600

  # Frames a story event waits at most after a player on the map stopped telling the story, for
  # the world's story they wrote, ten seconds.
  AWAIT_TELLER_FRAMES = 600

  # Frames a write waits after the story's progress moved, so the changes of one step go together.
  SETTLE_FRAMES = 30

  # Frames a write waits after the last other change of the story, five seconds, so a scene's
  # changes go in one write: the relay is on Cloudflare's free plan.
  DEBOUNCE_FRAMES = 300

  # Frames a change of the story waits at most while more keep coming, thirty seconds.
  LONGEST_WAIT_FRAMES = 1800

  # Frames before a request that failed is tried again, thirty seconds.
  RETRY_FRAMES = 1800

  # Frames before a write the relay refused for coming too often is tried again, five seconds.
  RATE_FRAMES = 300

  # Frames before a request the DLL did not start is tried again, a second.
  START_FRAMES = 60

  # Bytes the DLL may write the story's state into at first; a larger story asks for a larger buffer.
  STATE_SIZE = 4096

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

  # Variables whose change moves the story on, written soon after: the main story, the routes, the
  # Great Decision's progress and the areas' progress the parts are ordered by.
  PROGRESS_VARIABLES = [MAIN_PROGRESS] + ROUTE_VARIABLES + [1140, 1003, 1011, 1019, 1021, 1032, 1052, 1063, 1075, 1076, 1136, 1137, 1138, 1139]

  # Switches whose change moves the story on: the bosses of the Monster Lord's Castle and the route
  # clears.
  PROGRESS_SWITCHES = [2485, 2486, 2487] + CLEAR_SWITCHES

  # The main story's progress from which Part 2 runs, set by Tartarus Escape.
  PART_TWO = 19

  # The main story's progress from which Part 3 runs, set by the Middle Chapter's epilogue.
  PART_THREE = 34

  # The main story's progress the Great Decision sets.
  GREAT_DECISION = 40

  # The main story's progress a return to the Great Decision sets.
  BEFORE_DECISION = 39

  # Highest counter the relay takes.
  MAX_COUNTER = 1_000_000

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

  # Where a return to the Great Decision takes the player: the map, x and y.
  DECISION_PLACE = [407, 25, 25]

  # Event commands that run a script, which the returns use to add companions.
  SCRIPT_CODES = [355, 655]

  # The game's own endings of the two first routes, which its system switches keep per install and
  # the world's clear switches stand for in a Raid World.
  SYSTEM_ENDINGS = { :ed1 => 7096, :ed2 => 7097 }

  # Codes of a refused write or route whose own step the game drops: its progress is not the world's.
  DROP_CODES = %w(behind route finished closed)

  # Code of a write the relay refused as another route was locked first.
  ROUTE_REFUSAL = "route"

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "world story"

  # Forgets the world's story, as when the world closes, a save is loaded or a new game starts,
  # which bring their own story.
  #
  # @param reason [Symbol, nil] Why the story is fetched next, nil when none is.
  def self.forget(reason = nil)
    @mode = nil
    @base = nil
    @wrev = 0
    @seen_wrev = nil
    @known_rev = 0
    @world = nil
    @pending = nil
    @busy = {}
    @need_fetch = reason
    @force_post = false
    @marker_at = nil
    @change_at = nil
    @first_change_at = nil
    @change_signature = nil
    @watch = false
    @end_local = nil
    @was_telling = false
    @queued = nil
    @returned_route = nil
    @after_take = nil
    @pushed_rev = nil
    @teller = nil
    @decision_roster = nil
    @was_running = false
    @entry_story = reason ? entry_story : nil
    @retry_at = 0
    @fetch_at = 0
    @clock ||= 0
    @polled = @clock
    @checked = @clock
    @scanned = @clock
    @state_read = @clock
  end

  # Copies the story the player brings into the world, a save's or a new game's, which their changes
  # before the world's story first came are told by.
  #
  # @return [Array, nil] The switches, variables and self switches, nil before the game's exist.
  def self.entry_story
    $game_switches && $game_variables && $game_self_switches ? MGQ_MpStoryState.deep_copy(MGQ_MpStoryState.raw_state) : nil
  rescue
    nil
  end

  forget

  # Forgets the world's story once the world closed or is no Raid World.
  def self.close
    return unless @world_id

    log("the Raid World closed: forgetting its story")
    @world_id = nil
    forget
  end

  # Reports whether the world's story applies: a Raid World is open, which the directory knows.
  #
  # @return [Boolean] Whether it does.
  def self.active?
    MGQ_MpCoop::Scope.raid? && MGQ_MpOverworldSync.in_world? && !world_id.empty?
  end

  # The open world's id, which the DLL's story exports name the world by.
  #
  # @return [String] The id, empty outside a world or for a world the directory does not know.
  def self.world_id
    MGQ_MpWorld.world.directory_id.to_s
  rescue
    ""
  end

  # How the player plays the world's story.
  #
  # @return [Symbol, nil] :world while they play it, :behind while their story is in an earlier
  #   part (see world_catchup.rbx), nil before the world's story came.
  def self.mode
    @mode
  end

  # The counters of the world's story as the relay told them last.
  #
  # @return [Hash, nil] See counters_of, nil before the relay told any.
  def self.world
    @world
  end

  # Finds where a teleport to the story goes: the story's endpoint the relay keeps.
  #
  # @return [Array<Integer>, nil] The map, x, y and the direction to face, nil while the relay keeps none.
  def self.endpoint
    return nil unless active? && @world && !@world["end"].to_s.empty?

    map, x, y = @world["end"].split(",").map { |value| value.to_i }
    map && map > 0 ? [map, x.to_i, y.to_i, 2] : nil
  end

  # Lists the routes the world may still take at the Great Decision: the locked one alone while
  # the world has not finished it, else those not finished, the third way once both others are.
  #
  # @return [Array<Integer>, nil] The routes' places in ROUTES, nil outside a Raid World or before
  #   the relay told the world's story.
  def self.decision_routes
    return nil unless active? && @world

    done = @world["done"]
    locked = ROUTES.index(@world["route"])
    return [locked] if locked && !done.include?(ROUTES[locked])

    routes = [0, 1].reject { |index| done.include?(ROUTES[index]) }
    routes << 2 if done.include?(ROUTES[0]) && done.include?(ROUTES[1]) && !done.include?(ROUTES[2])
    routes.empty? ? nil : routes
  end

  # Takes the relay's push that the world's story changed: fetches it when its revision is newer
  # than the newest this game knows, once the player's own write or lock answered, since the push
  # of the player's own change comes about as fast as the answer. Called by overworld_sync.rbx.
  #
  # @param message [Hash] The push: MGQ_MpOverworldSync::STORY_FIELD with the revision, and
  #   :relay, which no player's message carries.
  def self.pushed(message)
    return log("ignored a story push not from the relay") unless message[:relay]

    rev = message[MGQ_MpOverworldSync::STORY_FIELD].to_i
    return unless active? && rev > @known_rev
    return @pushed_rev = [@pushed_rev.to_i, rev].max if @busy[:post] || @busy[:lock]

    log("the relay tells revision #{rev} of the world's story, this game knows #{@known_rev}: fetching it")
    @need_fetch ||= :push
  rescue => e
    log("taking the relay's push failed: #{e.class}: #{e.message}")
  end

  # Forgets the story this game played, as a loaded save or a new game bring their own, and
  # fetches the world's to lay over it.
  #
  # @param reason [Symbol] :load or :new_game.
  def self.loaded(reason)
    return unless active?

    log("#{reason == :load ? 'a save was loaded' : 'a new game started'}: fetching the world's story to lay over it")
    forget(reason)
  rescue => e
    log("following a #{reason} failed: #{e.class}: #{e.message}")
  end

  # Follows the world's story for one frame: the relay's answers, the fetches, laying the world's
  # story over the player's, and the writes. Called after the map's update.
  def self.tick
    @clock += 1
    return close unless active?

    note_world
    read_state if !@busy.empty? && @clock - @state_read >= STATE_FRAMES
    start_fetch
    note_telling
    note_teller
    take_pending if @pending && quiet?
    play_queued
    check_progress if @clock - @checked >= CHECK_FRAMES
    scan if scan_due?
    send_post if post_due?
  rescue => e
    log_once(:tick, "following the world's story failed: #{e.class}: #{e.message}")
  end

  # Notes the open world, fetching its story when it is another than the last.
  def self.note_world
    id = world_id
    return if id == @world_id

    forget(:entry)
    @world_id = id
    @greeted = false
    @behind_told = false
    log("a Raid World is open (#{id[0, 12]}): fetching its story")
  end

  # Starts a fetch when one is due: asked for, or once a minute.
  def self.start_fetch
    @need_fetch ||= :poll if @clock - @polled >= POLL_FRAMES
    return unless @need_fetch && !@busy[:fetch] && @clock >= @fetch_at

    unless Relay.fetch(world_id)
      @fetch_at = @clock + START_FRAMES
      return log_once([:fetch_start, @world_id], "the DLL did not start a fetch of the world's story, trying again")
    end

    log("fetching the world's story (#{@need_fetch})") unless @need_fetch == :poll
    @busy[:fetch] = true
    @need_fetch = nil
    @polled = @clock
  end

  # Reports whether the world's story may be laid over the player's now: on the map or behind a
  # menu, with no event of the player's own running, outside battles and transfers.
  #
  # @return [Boolean] Whether it may.
  def self.quiet?
    return false if $game_party.in_battle || MGQ_MpCoopEvents.pvp_running?
    return false if $game_player && $game_player.transfer?

    !$game_map.interpreter.running?
  end

  # Reads how the requests stand and takes those that ended, with the story's text only once one did.
  def self.read_state
    @state_read = @clock
    state = Relay.headers
    state = Relay.state if [:post, :lock, :fetch].any? { |kind| @busy[kind] && ended?(state[kind.to_s]) }
    return if state.empty?
    return other_world(state) if state["world"] && state["world"] != world_id

    rev = state["rev"].to_i
    @known_rev = rev if rev > @known_rev
    note_counters(state) if state["rev"]
    text = state[:payload].to_s
    # The player's own write comes first, so a fetch that ended with it takes it as known.
    took_post(state, text) if @busy[:post] && ended?(state["post"])
    took_lock(state, text) if @busy[:lock] && ended?(state["lock"])
    took_fetch(state, text) if @busy[:fetch] && ended?(state["fetch"])
    return unless @pushed_rev && !@busy[:post] && !@busy[:lock]

    @need_fetch ||= :push if @pushed_rev > @known_rev
    @pushed_rev = nil
  end

  # Reports whether a request the DLL tells of ended.
  #
  # @param outcome [String, nil] Its header in the state: "busy", how it ended, or nil while the DLL
  #   tells none.
  # @return [Boolean] Whether it ended.
  def self.ended?(outcome)
    !outcome.nil? && outcome != "busy"
  end

  # Takes the requests that ended while the DLL tells another world's story, which a request of the
  # world before may leave: nothing of it is this world's, so each is asked again.
  #
  # @param state [Hash] The DLL's state.
  def self.other_world(state)
    ended = [:fetch, :post, :lock].select { |kind| @busy[kind] && ended?(state[kind.to_s]) }
    return if ended.empty?

    log("the DLL tells the story of another world (#{state['world'].to_s[0, 12]}): asking again")
    ended.each { |kind| @busy.delete(kind) }
    @need_fetch ||= :retry if ended.include?(:fetch)
    @force_post = true if ended.include?(:post)
  end

  # Keeps the world's counters the relay told, the newest revision alone.
  #
  # @param state [Hash] The DLL's state.
  def self.note_counters(state)
    counters = counters_of(state)
    @world = counters if @world.nil? || counters["rev"] >= @world["rev"]
  end

  # Takes a fetch that ended.
  #
  # @param state [Hash] The DLL's state.
  # @param text [String] The world's story.
  def self.took_fetch(state, text)
    @busy.delete(:fetch)
    return offer(state, text, false, "fetched") if state["fetch"] == "done"

    log("fetching the world's story failed (#{state['fetch_code']}): #{state['fetch_error']}; trying again later")
    @fetch_at = @clock + RETRY_FRAMES
    @need_fetch ||= :retry
  end

  # Takes a write that ended: accepted, it is the story this game builds on; refused, the world's
  # story comes instead, as after a refused route lock when another route was locked first; failed,
  # it goes again later.
  #
  # @param state [Hash] The DLL's state.
  # @param text [String] The world's story, or the one written once accepted.
  def self.took_post(state, text)
    post = @busy.delete(:post)
    case state["post"]
    when "accepted"
      @wrev = state["post_rev"].to_i
      @seen_wrev = @wrev if @seen_wrev.nil? || @wrev > @seen_wrev
      @base = post[:story]
      @mode = :world
      @end_local = nil if post[:end] && post[:end] == @end_local
      # What changed while the write was under way goes out with the next one.
      @watch = true
      log("the relay took the story as revision #{@wrev} (#{post[:counters]})")
      offer(state, text, false, "newer than the write") if state["wrev"].to_i > @wrev
    when "conflict"
      code = state["post_code"].to_s
      log("the relay refused the story written on revision #{post[:base]} (#{code}): taking the world's at revision #{state['wrev']}" \
          "#{DROP_CODES.include?(code) ? ', dropping the own step' : ', keeping the own changes it lacks'}")
      offer(state, text, DROP_CODES.include?(code), "refused write (#{code})", true)
      # The world locked another route after the player's Great Decision offered theirs.
      @after_take = :route_taken if code == ROUTE_REFUSAL
    else
      code = state["post_code"].to_s
      @retry_at = @clock + (code == "rate" ? RATE_FRAMES : RETRY_FRAMES)
      @force_post = true
      log("writing the story failed (#{code}): #{state['post_error']}; trying again in #{(@retry_at - @clock) / 60} s")
    end
  end

  # Takes a route lock that ended: locked, the write follows; taken, the world's story comes instead.
  #
  # @param state [Hash] The DLL's state.
  # @param text [String] The world's story.
  def self.took_lock(state, text)
    route = @busy.delete(:lock)
    case state["lock"]
    when "locked"
      @decision_roster = nil
      log("the world's route is the #{ROUTE_NAMES[ROUTES.index(route).to_i]} route now")
    when "taken"
      log("the relay refused the #{route} route (#{state['lock_code']}): the world's route is #{state['route']}, taking the world's story")
      offer(state, text, true, "route refused (#{state['lock_code']})", true)
      @after_take = :route_taken
    else
      @retry_at = @clock + RETRY_FRAMES
      log("locking the route failed: #{state['lock_error']}; trying again later")
    end
  end

  # Keeps a story the relay told to lay over the player's once quiet: a newer one than the last
  # taken, or any after a refused step.
  #
  # @param state [Hash] The DLL's state.
  # @param text [String] The story.
  # @param drop [Boolean] Whether the player's own progress since the last story goes.
  # @param reason [String] Why, for the log.
  # @param force [Boolean] Whether it is taken however old.
  def self.offer(state, text, drop, reason, force = false)
    wrev = state["wrev"].to_i
    return unless force || @seen_wrev.nil? || wrev > @seen_wrev

    drop ||= @pending && @pending[:drop]
    @pending = { :state => state, :text => text, :drop => drop, :reason => reason }
  end

  # Lays the world's story that waits over the player's, or keeps the player's own, see the module.
  # A step the relay refused (pending[:drop]) is never written again as it was.
  def self.take_pending
    pending = @pending
    state = pending[:state]
    world = counters_of(state)
    local = MGQ_MpStoryState.raw_state
    own = local_counters(local)
    return if wait_for_return(own, world)

    @pending = nil
    after_take = @after_take
    @after_take = nil
    @world = world if @world.nil? || world["rev"] >= @world["rev"]
    @seen_wrev = world["wrev"]
    text = pending[:text].to_s

    # A story that did not open with the world's token comes without its text, and is written over.
    if world["wrev"] == 0 || text.empty?
      return if @mode == :world && @base && world["wrev"] == 0
      return wait_for_world(world, own) if pending[:drop] || !continues?(own, world)

      @mode = :world
      @wrev = world["wrev"]
      @force_post = true
      @entry_story = nil
      return log("the world has #{world['wrev'] == 0 ? 'no story yet' : "no story this game can read at revision #{world['wrev']}"}: writing the player's (#{counters_text(own)})")
    end
    # A player the catch-up moves on into the world's story takes it whatever their part.
    if (@mode != :world || @base.nil?) && !(defined?(MGQ_MpWorldCatchup) && MGQ_MpWorldCatchup.joins_world?)
      order = compare(key_of(own), key_of(world))
      return start_ahead(world, own) if order > 0 && !pending[:drop] && continues?(own, world)
      return fall_behind(world, own, text) if order < 0 && (part_of(own) != part_of(world) || kept_behind?)
    end

    take_world(world, local, own, text, pending, after_take)
  rescue => e
    log("taking the world's story failed: #{e.class}: #{e.message}")
  end

  # Reports whether the relay would take the player's story as the next of the world's: no route is
  # locked, or the player's story is on it or returned from it, or has no route under way while the
  # world's story has not started the locked one, and finishes no other route the world did not play
  # (as refusalOf in Relay/core/story.js).
  #
  # @param own [Hash] The player's counters.
  # @param world [Hash] The world's.
  # @return [Boolean] Whether it would.
  def self.continues?(own, world)
    locked = world["route"]
    return true if locked == "none"

    route = route_index(own)
    started = route_index(world) == ROUTES.index(locked)
    on_it = route ? ROUTES[route] == locked : own["clear"].include?(locked) || !started
    on_it && (own["clear"] - world["done"] - [locked]).empty?
  end

  # Waits for the world's next story, as the world has none yet and the player's cannot start it:
  # another route is locked, or the relay refused the player's step.
  #
  # @param world [Hash] The world's counters.
  # @param own [Hash] The player's.
  def self.wait_for_world(world, own)
    @mode = nil
    @base = nil
    @force_post = false
    log("the world has no story yet, and the player's (#{counters_text(own)}) cannot start it on the #{world['route']} route: waiting for the world's")
  end

  # Gives the player the personal half of the world's return to the Great Decision before the
  # world's story is laid over theirs, when the world finished the route the player is on and left
  # it (see returned); the world's story waits until it played.
  #
  # @param own [Hash] The player's counters.
  # @param world [Hash] The world's.
  # @return [Boolean] Whether the world's story waits.
  def self.wait_for_return(own, world)
    return true if @queued
    return false unless @mode == :world && @base

    left = route_index(own)
    return false unless left && left != @returned_route && left != route_index(world)
    return false unless world["done"].include?(ROUTES[left]) || world["clear"].include?(ROUTES[left])

    @returned_route = left
    returned(own)
    true
  end

  # Starts the world's story from the player's, which is further than the world's: the furthest
  # story wins.
  #
  # @param world [Hash] The world's counters.
  # @param own [Hash] The player's.
  def self.start_ahead(world, own)
    @mode = :world
    @wrev = world["wrev"]
    @base = nil
    @force_post = true
    @entry_story = nil
    log("the player's story (#{counters_text(own)}) is further than the world's (#{counters_text(world)}): writing it as the world's")
  end

  # Keeps the player behind the world's story, as theirs is in an earlier part: they write nothing,
  # and world_catchup.rbx gives them their part's checkpoint and moves them on by their level.
  #
  # @param world [Hash] The world's counters.
  # @param own [Hash] The player's.
  # @param text [String] The world's story, packed.
  def self.fall_behind(world, own, text)
    @mode = :behind
    @base = nil
    @entry_story = nil
    log_once([:behind, part_of(own), world["wrev"]], "the player's story (part #{part_of(own)}, #{counters_text(own)}) is in an earlier part than the world's (part #{part_of(world)}, #{counters_text(world)}): the player is behind")
    catch_up = defined?(MGQ_MpWorldCatchup)
    MGQ_MpWorldCatchup.behind(world, own, MGQ_MpStoryState.decode_full(MGQ_MpStoryState.unpack(text))) if catch_up
    return if @behind_told

    @behind_told = true
    MGQ_MpOverworldSync.notice(catch_up ? MGQ_MpWorldCatchup.behind_text(own) : "The world's story is further than yours.")
  end

  # Reports whether a player behind stays behind though the world's story is in their part again,
  # see MGQ_MpWorldCatchup.keeps_behind?.
  #
  # @return [Boolean] Whether they do.
  def self.kept_behind?
    @mode == :behind && defined?(MGQ_MpWorldCatchup) && MGQ_MpWorldCatchup.keeps_behind? ? true : false
  end

  # Fetches the world's story to lay over the player's whatever its revision, as when the catch-up
  # moves a player behind on into it.
  #
  # @param reason [Symbol] Why, for the log.
  def self.refetch(reason)
    @seen_wrev = nil
    @need_fetch ||= reason
  end

  # Reports whether commands wait to play once the player is free, as the personal half of a
  # return to the Great Decision.
  #
  # @return [Boolean] Whether they do.
  def self.queued?
    @queued ? true : false
  end

  # Lays the world's story over the player's: what is the player's own stays, and what they changed
  # since the story they built on stays too where the world's did not change it, unless their step
  # is dropped.
  #
  # @param world [Hash] The world's counters.
  # @param local [Array] The player's story: switches, variables and self switches.
  # @param own [Hash] The player's counters.
  # @param text [String] The world's story, packed.
  # @param pending [Hash] How it came, see offer.
  # @param after_take [Symbol, nil] :route_taken when the world took another route than the player's.
  def self.take_world(world, local, own, text, pending, after_take = nil)
    first = @mode != :world
    told = MGQ_MpStoryState.decode_full(MGQ_MpStoryState.unpack(text))
    applied = MGQ_MpStoryState.mix(told, local, chest_list)
    keep_unsent(applied, told, local)
    base = MGQ_MpStoryState.deep_copy(applied)
    kept, dropped = keep_own(applied, told, local, @base || @entry_story, pending[:drop])
    opened = keep_open_chests(applied, local)
    kept.concat(opened.map { |key| [2, key] })
    MGQ_MpStoryState.set_raw(*applied)
    if defined?(MGQ_MpWorldCatchup)
      MGQ_MpWorldCatchup.world_told(told)
      MGQ_MpWorldCatchup.carried(local)
    end
    @base = base
    @entry_story = nil
    @end_local = nil if pending[:drop]
    @wrev = world["wrev"]
    @mode = :world
    # What waited to be written is what the player kept now, if anything.
    @force_post = false
    @marker_at = @change_at = @first_change_at = @change_signature = nil
    unless kept.empty?
      @watch = true
      @change_at = @first_change_at = @clock
      @marker_at = @clock if kept.any? { |kind, key| marker?(kind, key) }
    end
    after = local_counters(applied)
    log("took the world's story at revision #{@wrev} (#{pending[:reason]}): #{counters_text(own)} -> #{counters_text(after)}; " \
        "kept #{kept.size} own changes, dropped #{dropped.size}#{dropped.empty? ? '' : " (#{dropped.first(10).map { |kind, key| label(kind, key) }.join(', ')})"}")
    if first && !@greeted
      @greeted = true
      MGQ_MpOverworldSync.notice("You play the world's story.")
    end
    followed(own, after)
    @returned_route = nil
    route_taken if after_take == :route_taken
  end

  # Keeps the variables of the player's whose values no story carries, such as lists, where the
  # world's story has none.
  #
  # @param applied [Array] The story laid over the player's.
  # @param told [Array] The world's story.
  # @param local [Array] The player's.
  def self.keep_unsent(applied, told, local)
    local[1].each_with_index do |value, id|
      applied[1][id] = value if told[1][id].nil? && !value.nil? && MGQ_MpStoryState.encode_value(value).empty?
    end
  end

  # Keeps what the player changed since the story they built on, where the world's story did not
  # change it: the rest of the step they were writing, unless the relay refused that step.
  #
  # @param applied [Array] The story laid over the player's, which takes them.
  # @param told [Array] The world's story.
  # @param local [Array] The player's.
  # @param base [Array, nil] The story they built on: the world's last taken or written, else the
  #   one they brought into the world, see entry_story.
  # @param drop [Boolean] Whether the player's step goes, see DROP_CODES.
  # @return [Array<Array>] The kept and the dropped changes, each as [kind, key].
  def self.keep_own(applied, told, local, base, drop)
    return [[], []] unless base

    kept = []
    dropped = []
    3.times do |kind|
      theirs = {}
      changes(kind, base[kind], told[kind]).each { |key| theirs[key] = true }
      changes(kind, base[kind], local[kind]).each do |key|
        if theirs[key] || drop
          dropped << [kind, key]
        else
          applied[kind][key] = local[kind][key]
          kept << [kind, key]
        end
      end
    end
    [kept, dropped]
  end

  # Follows what the world's story brought: the choices it carried the player past and the Great
  # Decision's route, both when one story carries them past earlier choices onto a route.
  #
  # @param before [Hash] The player's counters before.
  # @param after [Hash] The counters of the story laid over theirs.
  def self.followed(before, after)
    return unless defined?(MGQ_MpCoopChoices)

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

  # Plays the commands that wait, once the player is free on the map.
  def self.play_queued
    return unless @queued && MGQ_MpOverworldSync.map_free?

    commands = @queued
    @queued = nil
    log("playing #{commands.map { |entry| entry.code }.join(' ')} now")
    $game_map.interpreter.setup(commands, 0)
  end

  # Tells the player that the world took another route before theirs reached the relay, and takes
  # them to the story.
  def self.route_taken
    restore_roster
    route = ROUTES.index(@world && @world["route"])
    MGQ_MpOverworldSync.notice(route ? "The world took the #{ROUTE_NAMES[route]} route first." : "The world's story goes on without your route.")
    MGQ_MpCoopGather.join_story if defined?(MGQ_MpCoopGather) && endpoint
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

  # Notes the player's telling, where it ended is the story's endpoint, and the end of any event of
  # the player's own, whose changes are compared soon.
  def self.note_telling
    telling = MGQ_MpCoopEvents.telling?
    running = $game_map.interpreter.running?
    @watch = true if @was_running && !running
    told if @was_telling && !telling && @mode == :world
    @was_telling = telling
    @was_running = running
  end

  # Ends the player's telling: where it ended is the story's endpoint, and what it changed goes out
  # soon, in one write.
  def self.told
    @end_local = place
    @watch = true
    scan
    @marker_at ||= @clock if @change_at
  end

  # Notes a player telling the story on the map whose scene the player watches, and when they stop,
  # see awaits_teller?.
  def self.note_teller
    teller = MGQ_MpCoop::Scope.teller
    if teller.is_a?(MGQ_MpOverworldSync::Peers::Peer)
      @teller = { :wrev => @seen_wrev.to_i } if (@teller.nil? || @teller[:stopped]) && @mode == :world && MGQ_MpCoop::Scope.watches?(teller)
      return
    end
    @teller[:stopped] = @clock if @teller && !@teller[:stopped]
  end

  # Reports whether the player's story events wait for the world's story of a telling they watched
  # on the map that just ended: the teller's write takes seconds to arrive, and the player's game
  # would play the scene again before it did. Called by coop_events.rbx.
  #
  # @return [Boolean] Whether they wait.
  def self.awaits_teller?
    return false unless @teller && @teller[:stopped]
    return true if active? && @clock - @teller[:stopped] < AWAIT_TELLER_FRAMES && @seen_wrev.to_i <= @teller[:wrev]

    @teller = nil
    false
  end

  # Notes where the player's own telling moved them, the story's endpoint, written soon. Called
  # after the player's transfer.
  def self.story_transfer
    return unless active? && @mode == :world && MGQ_MpCoopEvents.telling?

    @end_local = place
    @marker_at ||= @clock
    log("the story moved the player to map #{@end_local.join(',')}, the story's endpoint")
  rescue => e
    log("noting the story's endpoint failed: #{e.class}: #{e.message}")
  end

  # Where the player stands.
  #
  # @return [Array<Integer>] The map, x and y.
  def self.place
    [$game_map.map_id, $game_player.x, $game_player.y]
  end

  # Looks whether the story's progress moved, which is written soon; a player behind whose story
  # reached the world's part fetches it again.
  def self.check_progress
    @checked = @clock
    return if @busy[:post]

    variables = MGQ_MpStoryState.data_of($game_variables)
    switches = MGQ_MpStoryState.data_of($game_switches)
    if @mode == :behind
      own = local_counters([switches, variables, {}])
      if @world && ((part_of(own) == part_of(@world) && !kept_behind?) || compare(key_of(own), key_of(@world)) >= 0)
        log("the player's story reached the world's part (#{counters_text(own)}): fetching the world's")
        @seen_wrev = nil
        @mode = nil
        @need_fetch ||= :caught_up
      end
      return
    end
    return unless @mode == :world && @base

    moved = PROGRESS_VARIABLES.any? { |id| !same?(1, @base[1][id], variables[id]) } || PROGRESS_SWITCHES.any? { |id| !same?(0, @base[0][id], switches[id]) }
    return unless moved && @marker_at.nil?

    @marker_at = @clock
    @watch = true
  end

  # Reports whether the whole story is compared now: every SCAN_FRAMES while it may have changed,
  # else every IDLE_SCAN_FRAMES while no event of the player's runs; never during the player's
  # telling, whose changes are compared once it ended.
  #
  # @return [Boolean] Whether it is.
  def self.scan_due?
    return false if MGQ_MpCoopEvents.telling?
    return @clock - @scanned >= SCAN_FRAMES if @watch

    @clock - @scanned >= IDLE_SCAN_FRAMES && !$game_map.interpreter.running?
  end

  # Compares the whole story with the one the player built on, for the changes a write takes.
  def self.scan
    @scanned = @clock
    return unless @mode == :world && @base && !@busy[:post]

    local = MGQ_MpStoryState.raw_state
    found = []
    3.times { |kind| changes(kind, @base[kind], local[kind]).each { |key| found << [kind, key, local[kind][key]] } }
    if found.empty?
      @marker_at = nil unless end_moved?
      @change_at = @first_change_at = @change_signature = nil
      @watch = false
      return
    end

    signature = found.hash
    return if signature == @change_signature

    @change_signature = signature
    @first_change_at ||= @clock
    @change_at = @clock
  end

  # Reports whether a write is due: the player's story moved on, another change rested for
  # DEBOUNCE_FRAMES or waited LONGEST_WAIT_FRAMES, or a write must go again. While the player tells
  # the story only the route lock goes, since others would take the scene's state half done.
  #
  # @return [Boolean] Whether it is.
  def self.post_due?
    return false unless @mode == :world && @pending.nil? && !@busy[:post] && !@busy[:lock] && @clock >= @retry_at
    return false if MGQ_MpCoopEvents.pvp_running?

    settled = @marker_at && @clock - @marker_at >= SETTLE_FRAMES
    return (settled || @force_post) && lock_route ? true : false if MGQ_MpCoopEvents.telling?
    return true if @force_post || settled

    @change_at && (@clock - @change_at >= DEBOUNCE_FRAMES || @clock - @first_change_at >= LONGEST_WAIT_FRAMES) ? true : false
  end

  # Finds the route the player's story took at the Great Decision that the world has not taken yet
  # and the relay would lock: not finished, and the third way only once both others are.
  #
  # @return [String, nil] The route, see ROUTES; nil for none.
  def self.lock_route
    route = route_index(local_counters([MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables)]))
    return nil unless route && @world && @world["route"] == "none"

    done = @world["done"]
    return nil if done.include?(ROUTES[route])
    return nil if route == ROUTES.size - 1 && !(done.include?(ROUTES[0]) && done.include?(ROUTES[1]))

    ROUTES[route]
  end

  # Writes the player's story as the world's, with the revision it built on; a route the world has
  # not taken yet is locked first.
  def self.send_post
    route = lock_route
    return lock(route) if route

    story = MGQ_MpStoryState.deep_copy(MGQ_MpStoryState.raw_state)
    counters = counters_text(local_counters(story), true)
    text = story_text(story)
    @force_post = false
    @marker_at = @change_at = @first_change_at = @change_signature = nil
    unless text
      @retry_at = @clock + RETRY_FRAMES
      return
    end

    unless Relay.post(world_id, @wrev, counters, text)
      @retry_at = @clock + START_FRAMES
      @force_post = true
      return log_once([:post_start, counters], "the DLL did not start writing the story (#{counters}), trying again")
    end

    @busy[:post] = { :story => story, :counters => counters, :base => @wrev, :end => end_moved? ? @end_local : nil }
    @watch = false
    log("writing the story on revision #{@wrev}: #{counters}, #{text.size} characters")
  rescue => e
    log("writing the story failed: #{e.class}: #{e.message}")
  end

  # Locks the route the player's story took at the Great Decision, before its first write.
  #
  # @param route [String] The route, see ROUTES.
  def self.lock(route)
    unless Relay.lock(world_id, route)
      @retry_at = @clock + START_FRAMES
      return log_once([:lock_start, route], "the DLL did not start locking the #{route} route, trying again")
    end

    @busy[:lock] = route
    log("the player's story took the #{ROUTE_NAMES[ROUTES.index(route)]} route at the Great Decision: locking it for the world")
  end

  # Packs the part of a story the world shares: the player's own switches, variables and chests
  # left out (see MGQ_MpStoryState.story_lists).
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [String, nil] The packed text, nil when it is too large even without what the story turned off.
  def self.story_text(story)
    shared = [story[0], story[1], story[2].reject { |key, _| chest?(key) }]
    text = MGQ_MpStoryState.pack(MGQ_MpStoryState.story_lists(shared, true))
    return text if text.size <= MGQ_MpStoryState::MAX_FULL_BYTES

    log_once(:story_size, "the story took #{text.size} characters, so it leaves out what the story turned off")
    text = MGQ_MpStoryState.pack(MGQ_MpStoryState.story_lists(shared, false))
    return text if text.size <= MGQ_MpStoryState::MAX_FULL_BYTES

    log_once(:story_too_large, "the story took #{text.size} characters even without what it turned off, more than the relay keeps: not written")
    nil
  end

  # Writes counters for the relay: the main story, the route under way alone, the routes cleared,
  # and the endpoint when it moved.
  #
  # @param counters [Hash] The counters, see local_counters.
  # @param with_end [Boolean] Whether the endpoint goes along.
  # @return [String] Such as "p=40;r1141=12;r1142=0;r1143=0;clear=mr;end=1650,30,51".
  def self.counters_text(counters, with_end = false)
    text = "p=#{counters['p']};r1141=#{counters['r1141']};r1142=#{counters['r1142']};r1143=#{counters['r1143']};clear=#{counters['clear'].join(',')}"
    text += ";end=#{@end_local.join(',')}" if with_end && end_moved?
    text
  end

  # Reports whether the story's endpoint moved from the one the relay keeps.
  #
  # @return [Boolean] Whether it did.
  def self.end_moved?
    @end_local && (@world.nil? || @world["end"].to_s != @end_local.join(",")) ? true : false
  end

  # Reads the counters of a story as the relay reads them: the main story, the route under way
  # alone (the first whose variable is above 0), and the routes cleared.
  #
  # @param story [Array] The switches and variables.
  # @return [Hash] "p", "r1141", "r1142", "r1143" and "clear".
  def self.local_counters(story)
    variables = story[1]
    counters = { "p" => bounded(variables[MAIN_PROGRESS]) }
    route = ROUTE_VARIABLES.index { |id| variables[id].to_i > 0 }
    ROUTE_VARIABLES.each_with_index { |id, index| counters["r#{id}"] = index == route ? bounded(variables[id]) : 0 }
    counters["clear"] = ROUTES.select { |name| story[0][CLEAR_SWITCHES[ROUTES.index(name)]] }
    counters
  end

  # Bounds a counter to what the relay takes.
  #
  # @param value [Object] The variable's value.
  # @return [Integer] The counter.
  def self.bounded(value)
    [[value.to_i, 0].max, MAX_COUNTER].min
  end

  # Reads the world's counters from the DLL's state.
  #
  # @param state [Hash] The state's headers.
  # @return [Hash] As local_counters, with "rev", "wrev", "route", "done", "end", "part",
  #   "checkpoints" (the parts the relay keeps a checkpoint of) and "comps" (the shared companions'
  #   actor ids).
  def self.counters_of(state)
    counters = { "rev" => state["rev"].to_i, "wrev" => state["wrev"].to_i, "p" => state["p"].to_i }
    ROUTE_VARIABLES.each { |id| counters["r#{id}"] = state["r#{id}"].to_i }
    counters["clear"] = state["clear"].to_s.split(",")
    counters["done"] = state["done"].to_s.split(",")
    counters["route"] = state["route"].to_s.empty? ? "none" : state["route"].to_s
    counters["end"] = state["end"].to_s
    counters["part"] = state["part"].to_s
    counters["checkpoints"] = state["checkpoints"].to_s.split(",")
    counters["comps"] = state["comps"].to_s.split(",").map { |id| id.to_i }
    counters
  end

  # Finds the route under way.
  #
  # @param counters [Hash] The counters.
  # @return [Integer, nil] Its place in ROUTES, nil before the Great Decision or back at it.
  def self.route_index(counters)
    ROUTE_VARIABLES.index { |id| counters["r#{id}"].to_i > 0 }
  end

  # Finds the part a story is in, as the relay does: the route under way, else Part 1 before
  # Tartarus Escape, Part 2 before the Middle Chapter's epilogue, else Part 3.
  #
  # @param counters [Hash] The counters.
  # @return [String] "1", "2", "3", "ad", "mr" or "chaos".
  def self.part_of(counters)
    route = route_index(counters)
    return ROUTES[route] if route
    return "1" if counters["p"] < PART_TWO

    counters["p"] < PART_THREE ? "2" : "3"
  end

  # Orders stories as the relay does: the routes returned from, the main story, the step of the
  # route under way, the routes cleared.
  #
  # @param counters [Hash] The counters.
  # @return [Array<Integer>] The key, compared left to right.
  def self.key_of(counters)
    route = route_index(counters)
    clear = counters["clear"]
    returned = clear.count { |name| route.nil? || name != ROUTES[route] }
    [returned, counters["p"], route ? counters["r#{ROUTE_VARIABLES[route]}"] : 0, clear.size]
  end

  # Compares two keys of key_of.
  #
  # @param one [Array<Integer>] The one.
  # @param other [Array<Integer>] The other.
  # @return [Integer] Below 0, 0 or above 0.
  def self.compare(one, other)
    one <=> other
  end

  # Lists what differs between two stories, leaving out what is the player's own.
  #
  # @param kind [Integer] 0 for switches, 1 for variables, 2 for self switches.
  # @param before [Array, Hash] The one story's.
  # @param after [Array, Hash] The other's.
  # @return [Array] The keys that differ.
  def self.changes(kind, before, after)
    keys = kind == 2 ? before.keys | after.keys : (0...[before.size, after.size].max).to_a
    keys.reject { |key| same?(kind, before[key], after[key]) || personal?(kind, key) }
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

  # Reports whether a switch, variable or self switch is the player's own.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Boolean] Whether it is.
  def self.personal?(kind, key)
    case kind
    when 0 then MGQ_MpStoryState.personal_switch?(key)
    when 1 then MGQ_MpStoryState.personal_variable?(key)
    else chest?(key)
    end
  end

  # Reports whether a switch or variable tells how far the story is, see PROGRESS_VARIABLES.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Boolean] Whether it does.
  def self.marker?(kind, key)
    (kind == 0 && PROGRESS_SWITCHES.include?(key)) || (kind == 1 && PROGRESS_VARIABLES.include?(key))
  end

  # Names a switch, variable or self switch for the log.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [String] Such as "v1001".
  def self.label(kind, key)
    kind == 2 ? "ss#{key.join('.')}" : "#{kind == 0 ? 's' : 'v'}#{key}"
  end

  # Reports whether a self switch is a chest's, each player's own: of the game's chests (see
  # MGQ_MpCoopStoryRewards::CHESTS), or of the map's; never one that holds the story's key items.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @return [Boolean] Whether it is.
  def self.chest?(key)
    unless @chests
      @chests = {}
      MGQ_MpStoryState.all_chest_keys.each { |chest| @chests[chest] = true }
    end
    return false if world_chest?(key)

    @chests[key] || MGQ_MpStoryState.personal_self_switch?(key) ? true : false
  end

  # Reports whether a chest holds the story's key items, which opens once for the whole world (see
  # MGQ_MpWorldCatchupData::CHESTS).
  #
  # @param key [Array] Its self switch: map, event and letter.
  # @return [Boolean] Whether it does.
  def self.world_chest?(key)
    world_chests[key] ? true : false
  end

  # The chests that hold the story's key items, see world_chest?.
  #
  # @return [Hash{Array => Boolean}] Their keys to true.
  def self.world_chests
    unless @world_chests
      @world_chests = {}
      MGQ_MpWorldCatchupData::CHESTS.each { |chest| @world_chests[chest.key] = true } if defined?(MGQ_MpWorldCatchupData)
    end
    @world_chests
  end

  # Keeps the world's chests the player opened open in a story laid over theirs, as each opens once
  # for the world and the catch-up gave its items already.
  #
  # @param applied [Array] The story laid over the player's, which takes them.
  # @param local [Array] The player's.
  # @return [Array<Array>] The chests it opened, by their keys.
  def self.keep_open_chests(applied, local)
    world_chests.keys.select { |key| local[2][key] && !applied[2][key] }.each { |key| applied[2][key] = true }
  end

  # Lists the chests whose self switches stay the player's own when a story is laid over theirs.
  #
  # @return [Array<Array>] Their keys.
  def self.chest_list
    (MGQ_MpStoryState.all_chest_keys + MGQ_MpStoryState.chest_keys).uniq.reject { |key| world_chest?(key) }
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

  # Patch/Multiplayer/Multiplayer.dll's story of the world at the relay.
  module Relay
    # Starts fetching the world's story.
    #
    # @param world [String] The world's id.
    # @return [Boolean] Whether it started.
    def self.fetch(world)
      MGQ_Multiplayer::Link.function('mp_raid_story_fetch').call(world + "\0") == 1
    rescue => e
      MGQ_MpWorldStory.log("fetching failed: #{e.class}: #{e.message}")
      false
    end

    # Starts writing the world's story.
    #
    # @param world [String] The world's id.
    # @param base [Integer] The revision it built on.
    # @param counters [String] The counters, see MGQ_MpWorldStory.counters_text.
    # @param text [String] The story, see MGQ_MpWorldStory.story_text.
    # @return [Boolean] Whether it started.
    def self.post(world, base, counters, text)
      MGQ_Multiplayer::Link.function('mp_raid_story_post').call(world + "\0", base, counters + "\0", text + "\0") == 1
    rescue => e
      MGQ_MpWorldStory.log("writing failed: #{e.class}: #{e.message}")
      false
    end

    # Starts locking the world's route.
    #
    # @param world [String] The world's id.
    # @param route [String] The route, see ROUTES.
    # @return [Boolean] Whether it started.
    def self.lock(world, route)
      MGQ_Multiplayer::Link.function('mp_raid_route_lock').call(world + "\0", route + "\0") == 1
    rescue => e
      MGQ_MpWorldStory.log("locking failed: #{e.class}: #{e.message}")
      false
    end

    # Reads how each request stands and the newest story's headers, without its text.
    #
    # @return [Hash] The headers, see state; empty before any request.
    def self.headers
      text = MGQ_Multiplayer::Link.read('mp_raid_story_headers', STATE_SIZE)
      text.empty? ? {} : MGQ_Multiplayer::Link.parse(text)
    rescue => e
      MGQ_MpWorldStory.log_once([:headers, e.class], "reading the story's headers failed: #{e.class}: #{e.message}")
      {}
    end

    # Reads the newest story the relay told and how each request stands.
    #
    # @return [Hash] The headers (see docs/DEVELOPER.md), the story under :payload; empty before
    #   any request.
    def self.state
      text = MGQ_Multiplayer::Link.read('mp_raid_story_state', STATE_SIZE)
      text.empty? ? {} : MGQ_Multiplayer::Link.parse(text)
    rescue => e
      MGQ_MpWorldStory.log_once([:state, e.class], "reading the story's state failed: #{e.class}: #{e.message}")
      {}
    end
  end
end

# What this script takes part in of the world, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::STORY_FIELD) { |_peer, message| MGQ_MpWorldStory.pushed(message) }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpWorldStory.close unless in_world }
rescue => e
  MGQ_MpWorldStory.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the world's story.
  MGQ_MpHooks.after(Game_Map, :update, "world_story") { MGQ_MpWorldStory.tick }

  # Before an event command runs, the Great Decision's choice and the Reaper's reset menu follow the world.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "world_story") { MGQ_MpWorldStory.before_command(self) }

  # After the player's transfer, a story's transfer is the story's endpoint.
  MGQ_MpHooks.after(Game_Player, :perform_transfer, "world_story") { MGQ_MpWorldStory.story_transfer }

  # A loaded save or a new game bring their own story, over which the world's is laid. Not after
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
