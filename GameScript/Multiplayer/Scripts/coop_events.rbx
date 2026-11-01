#----------------------------------------------------------------
#  coop_events.rbx
#
#  Changelog:
#      Paulinchen  2026-11-01: Hashed a list's shape through story_replay.rbx, which names the places of the kept commands by the same codes
#      Paulinchen  2026-10-31: Stopped telling whether warping is banned where the story plays
#                            - Stopped telling the party the items and gold the leader's story gives, which the leader's runs bring by replay
#                            - Worded what the player reads plainly, leaving causes and internals to the log
#                            - Handed the leader's runs of the story to every member who follows it, as entries of the leader's story, which each member's game replays
#                            - Sent a member's runs of the leader's story to the leader with their requests, and handed the party those the leader's story kept, named by the member
#                            - Handed a party chest to the party as its run, which each member's game replays
#                            - Took the runs other members handed over
#      Paulinchen  2026-10-28: Read the chests of a map, the flags of its pages and what pages do through common events from the DLL's events database
#                            - Named a map event's page and a common event to the DLL with the length and shape of its list
#                            - Handed the DLL the game data's fingerprint before the first question about events
#                            - Sorted the pages of a map the DLL's database holds otherwise from their commands in one more call
#                            - Named the running map and event with a common event's list and a list handed over
#                            - Asked the DLL whether a teller's page is over only once what it reads changed or its time came
#                            - Held only the story events and talks that would move a player behind past the end of their part
#                            - Held a Raid World's story event at its first command for the relay's telling lock in place of the tie hold
#                            - Kept the pages a teller tells and a viewer shows, with their pace and reading times, in the DLL
#                            - Told a refused story event once per event in one place
#                            - Left how a story event goes on with the telling to the DLL's telling machine
#                            - Ended a Raid World teller's page with the relay's word that the telling ended, and told no story progress in the state
#      Paulinchen  2026-10-24: Played every battlefuck in the player's own game alone
#                            - Named the game's own common event that starts in the log
#                            - Noted the teller whose story event that runs by itself the player's game keeps from starting
#                            - Let that event start once nothing came for thirty seconds of a telling outside battle
#      Paulinchen  2026-10-23: Sorted event pages in the DLL over the game's own data and deleted the script's sorter
#                            - Took back what a talk or story event changed once it ends early
#                            - Noted the values that move the world's story on as a telling starts
#                            - Faded the screen in once it stayed dark for ten seconds while nothing of a watched scene reached it
#      Paulinchen  2026-10-17: Sorted a resumed raid boss fight's event as story
#      Paulinchen  2026-10-15: Faded the screen in once it stayed dark with nothing running that could fade it in
#      Paulinchen  2026-10-12: Faded the screen in once per arrival on a map whose self-running story another game runs
#                            - Let a leader's page that fails to hold wait as the game's own pages do
#                            - Told the viewers at most one page every ten frames while the teller skips
#                            - Told a Classic party's members the story's pages in one message
#      Paulinchen  2026-10-11: Sorted a page with story behind a choice as no chest
#                            - Kept a new game's opening from starting in a Raid World past it
#                            - Told the party the dialogue of common events the story calls
#                            - Left a leader's page a moment to read and kept at most three pages waiting
#                            - Kept a leader's page the game's transfer process starts under
#                            - Watched travel with story behind a choice as a talk is watched
#                            - Kept a Raid World's story events from starting until the world's story came
#                            - Counted branches on an unlimited_choices variable as a choice's branches
#                            - Sorted a scene that runs by itself with story behind such a choice as story
#                            - Sorted a page of dialogue and its own self switch alone as a talk
#                            - Let a talk run the cosmetic scripts
#      Paulinchen  2026-10-10: Went on with a telling that moved the player only at a story event that runs by itself
#                            - Told world_story.rbx that the telling may go on after a move
#                            - Went on with a Raid World's telling at the story's next event on the new map
#                            - Kept a story event from starting while the player follows a teller's move
#                            - Kept the map display, Pocket Castle call and post-battle processing to the player's own game
#                            - Left the teleport to the leader to coop_teleport.rbx
#                            - Told the player why a story event waits for the world's story
#                            - Sorted an event that calls the player's own common events by the rest of its list
#                            - Held a Raid World's story event a second for a tie
#      Paulinchen  2026-10-09: Asked story_state.rbx which switches and variables are the player's own
#                            - Kept story events from starting while the player's story is behind a Raid World's
#                            - Kept a Raid World's telling through the story's next event in the same frame
#                            - Held a Raid World's story event at its start while someone who entered the map first may tie
#                            - Told the story's pages to a Raid World's viewers in one message
#      Paulinchen  2026-10-08: Took the teller, the viewers and the story's gate from MGQ_MpCoop::Scope
#                            - Stopped a Raid World's story event on a tie with a player who entered the map first
#                            - Told the story's progress and the warp ban at the start of a Raid World's telling
#                            - Kept chests personal in a Raid World
#                            - Kept the Library's replays and the transfer process to the player's own game
#                            - Showed a leader's page without its face while the face file is missing
#                            - Kept a Raid World's story event from starting until a watched telling's story arrived
#      Paulinchen  2026-10-07: Took a common event's setup, which passes the list alone
#                            - Registered the hooks through core_hooks.rbx
#                            - Let a leader's page outside a fiber move on at once
#                            - Used the shared helpers of coop.rbx and overworld_sync.rbx
#                            - Blocked, watched and mirrored the leader's story only for synced members
#                            - Logged event sorting, messages, the leader's pages and shared chests
#                            - Ended the telling of the leader's story with its event
#      Paulinchen  2026-10-06: Took sound names that hold dots
#                            - Asked coop.rbx for the party's leader
#                            - Forgot a former leader's pages once another member leads
#                            - Took a time from before a save the player loaded as long past
#                            - Gave a chest's items with the gifts kept apart
#                            - Found a chest's items through MGQ_MpGame.item
#                            - Kept a chest the player leaves shut closed for the party
#      Paulinchen  2026-10-04: Held back chests opened during a PvP battle and kept gifts out of chests
#                            - Sent a chest's sound with its items and showed members its first item's icon
#                            - Read where the Pocket Castle's way out returns as the player's own variables
#                            - Kept the leader's pages of the map a member follows the leader to
#                            - Kept a member's story events from starting anywhere
#                            - Sorted called common events, shops with a goods script and story behind a choice
#                            - Moved gathering the party for story scenes into coop_gather.rbx
#                            - Moved the Pocket Castle's residents into coop_castle.rbx
#                            - Renamed from mp_coop_events.rbx
#      Paulinchen  2026-10-03: Sorted the Pocket Castle item as travel
#                            - Let a member teleport to the party's leader on their own
#                            - Took over the warp ban of the leader's place when a story scene brings the player over
#                            - Said the story's line above the player's own head through MGQ_MpActions
#                            - Held the player through MGQ_MpHooks.hold_player
#                            - Asked MGQ_MpOverworldSync whether the map is quiet or the player free on it
#                            - Sent messages and read the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Left every starting story event to the leader
#                            - Knew a chest by any of its pages
#      Paulinchen  2026-10-02: Told coop_story.rbx the items and gold the leader's story gives or takes
#                            - Sorted a common event once per depth
#                            - Held event commands and followed the map's update through core_hooks.rbx
#                            - Took whether the player plays in a party, and an event's page, from coop.rbx
#                            - Told the kinds of item a chest gives by their class alone
#                            - Started no random encounter for a member the leader's story scene brings over
#      Paulinchen  2026-10-01: Sorted event pages by the branches that can run now
#                            - Let exits that only note a flag on the way stay travel
#                            - Shortened a member's time before the leader's story scene brings them over to five seconds
#                            - Moved the leader's pages on in a member's game only when the leader moves on
#                            - Sorted the Pocket Castle's companions, merchants, inn and maids as talks
#                            - Held the leader's story scene until every member stands near
#                            - Kept members on the leader's map from moving or opening the menu during its story scene
#                            - Stopped taking the members along to every map the leader goes to
#      Paulinchen  2026-09-30: Sent and took the party's messages through coop.rbx
#                            - Registered with overworld_sync.rbx for its messages
#                            - Moved into Patch/Multiplayer/Scripts as coop_events.rbx
#                            - Renamed from mp_events.rb, with the module MGQ_MpCoopEvents
#                            - Played a party's story events in the leader's game and showed its messages to the members
#                            - Took the party along where the leader goes, and gathered it for story scenes
#                            - Created
#
#----------------------------------------------------------------

# The events of a party. Every event page is sorted by what its commands that can run now do, before
# it runs, in the DLL (MGQOnline.Game's EventSorter, over the events database the mod ships):
# a talk (conversations, shops, the job change menu), travel (a transfer), a chest (items and its
# own self switch), a battle without dialogue, or story (everything that moves the story on).
# Chests are the player's own, and opening one opens it for the whole party: the run that opened it
# goes to every member, whose own game plays the chest again (story_keys.rbx, story_replay.rbx),
# synced with the leader's story or not. Story is the
# leader's alone for the members who follow it (see MGQ_MpCoopStory.follows_leader?); a member who
# does not plays their own. A story scene the leader starts first gathers the members who follow it,
# see coop_gather.rbx; the Pocket Castle's residents are sorted by coop_castle.rbx. In a Raid World
# the story is told by whoever tells it on the map, to everyone there whose story matches, see
# MGQ_MpCoop::Scope. The pages of a story, which page a teller tells when and which page a viewer
# shows when and for how long, are the DLL's (MGQOnline.Game's Telling/StoryPages, behind the
# topics of PageTopics); this script reads and fills the message window and sends the messages.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopEvents
  # The DLL's topic that sorts one list of event commands, see EventTopics.Sort.
  SORT_TOPIC = "events.sort"

  # The DLL's topic that sorts every page of the map's events at once, see EventTopics.Kinds.
  KINDS_TOPIC = "events.kinds"

  # The DLL's topic that takes the game data's fingerprint, which its events database is checked
  # against, see EventTopics.Open.
  OPEN_TOPIC = "events.open"

  # The DLL's topic that tells which pages of a map are chests, see EventTableTopics.Chests.
  CHESTS_TOPIC = "events.chests"

  # The DLL's topic that tells what its events database found in pages of a map, see
  # EventTableTopics.Pages.
  PAGES_TOPIC = "events.pages"

  # The DLL's topic that tells the troops and the writes of lists through the common events they
  # call, see EventTopics.Index.
  INDEX_TOPIC = "events.index"

  # How often a sort hands over the values the DLL names it needs, at most: a branch the values
  # open may read more.
  MAX_SORT_ROUNDS = 8

  # Sorts kept with the values they read, at most, before they are all forgotten.
  MAX_KEPT_SORTS = 4000

  # What a sort answers when the DLL cannot sort: the page plays as the player's own talk.
  UNSORTED = { :kind => :talk, :list_kind => :talk, :may_tell => false, :scene => false, :marks => [] }

  # Kinds of page that may turn into story behind one of their choices, which guard watches: a
  # talk, and travel whose transfer lies behind the choice with the story, as the Great Decision's.
  WATCHED_KINDS = [:talk, :travel]

  # Frames in which a member hears only once that a story event they started is the leader's,
  # three seconds.
  REFUSE_FRAMES = 180

  # Frames the screen takes to fade in for a player who came in the middle of another player's
  # story, half a second, as the game's own fade.
  LATE_FADEIN_FRAMES = 30

  # Frames the screen may stay dark while nothing runs that could fade it in, five seconds.
  DARK_SCREEN_FRAMES = 300

  # Frames the screen may stay dark while the player watches another player's scene on the map and
  # nothing of it reaches the player's screen, ten seconds.
  WATCHED_DARK_FRAMES = 600

  # Frames after the player's game last kept its own copy of a teller's story event that runs by
  # itself from starting in which it still counts as kept, one second, see keeps_autorun_of?.
  KEPT_AUTORUN_FRAMES = 60

  # The trigger of an event that runs alongside the map, and the command that fades the screen in.
  PARALLEL_TRIGGER = 4
  FADEIN_CODE = 222

  # The DLL's topics of the telling machine (StoryTopics in the DLL, MGQOnline.Game's
  # TellingMachine): an event of the map's interpreter starting, a command of a telling whose
  # first waits for the relay's telling lock, the telling's event ending, the telling moving the
  # player onto another map and its transfer landing there.
  TELLING_START_TOPIC = "telling.start"
  TELLING_COMMAND_TOPIC = "telling.command"
  TELLING_END_TOPIC = "telling.end"
  TELLING_MOVING_TOPIC = "telling.moving"
  TELLING_ARRIVED_TOPIC = "telling.arrived"

  # What the player reads when the relay refused the telling's lock to a game it cannot name.
  LOCK_REFUSAL_TEXT = "Another player is telling the story here."

  # The DLL's topics of a story's pages (PageTopics in MGQOnline.Game, its Telling/StoryPages): as
  # teller, a page shown, passed, kept while the player skips and told once due, and a new telling
  # starting; as viewer, a page heard, one the teller moved past, the pages of a former teller
  # forgotten, the next page to show once the player is free, whether the page shown is over, and
  # its end.
  PAGE_SHOW_TOPIC = "pages.show"
  PAGE_PASSED_TOPIC = "pages.passed"
  PAGE_FLUSH_TOPIC = "pages.flush"
  PAGE_TELLING_TOPIC = "pages.telling_starts"
  PAGE_HEAR_TOPIC = "pages.hear"
  PAGE_DONE_TOPIC = "pages.done"
  PAGE_FORGET_TOPIC = "pages.forget"
  PAGE_NEXT_TOPIC = "pages.next"
  PAGE_OVER_TOPIC = "pages.over"
  PAGE_ENDED_TOPIC = "pages.ended"

  # The game's message skip, held: its message window passes every page while it is down (the
  # keyboard's A key).
  SKIP_BUTTON = :X

  # Frames a member's game shows the part of a long page that fits the window before it shows the
  # rest, two and a half seconds, as the leader's game shows the whole page at once.
  OVERFLOW_FRAMES = 150

  # Messages about gathering for story scenes, which coop_gather.rbx takes.
  GATHER_MESSAGES = %w(gather follow)

  # Common events that run only in the player's own game, never as the party's story: the game's map
  # display, its Pocket Castle call, its processing after every battle (which turns Luka Solo on)
  # and its transfer process, which runs by itself after a transfer.
  OWN_COMMON_EVENTS = [2, 3, 5, 114]

  # What a player whose story event waits for the world's story of a telling they watched reads.
  AWAIT_TOLD_TEXT = "Waiting for %s's story . . ."

  # The game's switch that is on while the Library replays a scene, by its id in 3.06.
  LIBRARY_REPLAY_SWITCH = 443

  # The DLL's topic that tells whether a story event would move the player's story past the end of
  # their part, see StoryTopics.LeavesPartTopic.
  LEAVES_PART_TOPIC = "story.leaves_part"

  # The values the DLL named a sort's list needs, by the list's key (see site_key) and kind.
  @needs = {}
  # The last sort of each list, with the values it read, see sorting.
  @answers = {}
  # Why each list would leave the part of a player behind, nil for one that stays, with the values
  # it was told for, see leaving_part.
  @leaving = {}
  # The values the DLL named the chain of a list reads, by the list's key (see site_key) and kind.
  @part_needs = {}
  # The checks of what waits for the player to be free, see give_way_to.
  @waits = []
  # Whether the message window waits for the input that ends a page, see page_end_input.
  @page_end = false
  # The DLL's last answer that the page the window holds is not over, see page_held?.
  @page_asked = nil

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "co-op events"

  # Sorts an event's current page by what of it can run now, in the DLL (MGQOnline.Game's
  # EventSorter): a talk, travel, a chest, a battle or story.
  #
  # @param event [Game_Event] The event.
  # @return [Symbol] :talk, :travel, :chest, :battle, :story or :own, see kind_of; :talk for an
  #   event without a page.
  def self.kind(event)
    return :talk if event.mgq_mp_page < 0

    sorting(event.list || [], event)[:kind]
  end

  # Sorts a list of event commands by what of it can run now, see kind; no page's trigger counts.
  #
  # @param list [Array<RPG::EventCommand>] The commands, such as a common event's.
  # @param event [Game_Event, nil] The event whose page the list may be, nil for none.
  # @return [Symbol] :talk, :travel, :chest, :battle or :story.
  def self.kind_of(list, event = nil)
    sorting(list || [], event)[:list_kind]
  end

  # Reports whether a talk turns into story behind one of its choices.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param event [Game_Event, nil] The event whose page the list may be, nil for none.
  # @return [Boolean] Whether it does.
  def self.may_tell?(list, event = nil)
    sorting(list || [], event)[:may_tell]
  end

  # Reports whether a list of commands is a story scene: story with its own dialogue or novel scene.
  #
  # @param list [Array<RPG::EventCommand>, nil] The commands.
  # @param event [Game_Event, nil] The event whose page the list may be, nil for none.
  # @return [Boolean] Whether it is.
  def self.scene?(list, event = nil)
    list ? sorting(list, event)[:scene] : false
  end

  # Reports whether an event command moves the story on, whatever branch it stands in.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The command's place.
  # @param event [Game_Event, nil] The event whose page the list may be, nil for none.
  # @return [Boolean] Whether it does.
  def self.story_command?(list, index, event = nil)
    sorting(list, event, index)[:story]
  end

  # Sorts a list in the DLL, or takes its last answer while the values the sort read stay as they
  # were. The DLL names the switches, variables and personal checks a sort reads the first time
  # (needs), which are kept per list and sent with every later sort, so a sort is one call.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param event [Game_Event, nil] The event whose page the list may be, nil for none.
  # @param index [Integer, nil] The command whose story alone is asked, see story_command?.
  # @return [Hash] :kind, :list_kind, :may_tell and :scene, or :story for an index; UNSORTED when
  #   the DLL does not answer.
  def self.sorting(list, event = nil, index = nil)
    request = request_for(list, event)
    request["index"] = index if index
    key = [site_key(request, list), index]
    needs = (@needs[key[0]] ||= {})
    kept = @answers[key]
    return kept[1] if kept && kept[2].equal?(list) && kept[0] == values_of(needs)

    answer = ask(SORT_TOPIC, request, needs)
    if answer && answer["unknown"] && !request["list"]
      request = inline_request(list, event).merge(request.select { |field, _value| %w(index resident).include?(field) })
      answer = ask(SORT_TOPIC, request, needs)
    end
    found = answer && !answer["unknown"] ? answer_of(answer) : unsorted(key, index)
    @answers.clear if @answers.size >= MAX_KEPT_SORTS
    @answers[key] = [values_of(needs), found, list]
    found
  end

  # Names the list a sort asks for: a map event's page or a common event, which the DLL reads from
  # its events database while the database holds the list with the same length and shape, or the
  # commands themselves for any other list. A common event's list and a list handed over name the
  # running map and event too, inside whose map folder the transfers of an event's list lead.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param event [Game_Event, nil] The event whose page the list may be, or that runs it; nil for none.
  # @return [Hash] The request.
  def self.request_for(list, event)
    page = event && $game_map ? event.mgq_mp_pages.index { |candidate| candidate.list.equal?(list) } : nil
    id = page ? nil : common_id(list)
    request = if page
                { "map" => $game_map.map_id, "event" => event.id, "page" => page }.merge(size_and_shape(list))
              elsif id
                running(event).merge("common" => id).merge(size_and_shape(list))
              else
                inline_request(list, event)
              end
    request["resident"] = true if defined?(MGQ_MpCoopCastle) && MGQ_MpCoopCastle.resident?(list)
    request
  end

  # Hands a list to the DLL whole, for a list its events database does not hold as the game shows
  # it: each command's parameters as plain values, anything else as nil.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param event [Game_Event, nil] The event whose current page the list may be, whose trigger counts
  #   then, or that runs it; nil for none.
  # @return [Hash] The request.
  def self.inline_request(list, event)
    running(event).merge("list" => rows_of(list), "trigger" => event && list.equal?(event.list) ? event.trigger : nil)
  end

  # Names the map and the event that run a list, as a request's fields.
  #
  # @param event [Game_Event, nil] The event, nil for none.
  # @return [Hash] "map" and "event" (0 for none); empty outside a map.
  def self.running(event)
    $game_map ? { "map" => $game_map.map_id, "event" => event ? event.id : 0 } : {}
  end

  # Writes a list's commands as the DLL reads them: [code, indent, plain parameters].
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Array<Array>] The rows.
  def self.rows_of(list)
    list.map { |command| [command.code, command.indent, plain(command.parameters)] }
  end

  # Finds a list's length and shape, which the DLL compares with its events database's: kept per
  # list object while its length stays, so a list is hashed once.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Hash] "size" and "shape".
  def self.size_and_shape(list)
    @shapes ||= {}.compare_by_identity
    kept = @shapes[list]
    return kept if kept && kept["size"] == list.size

    @shapes.clear if @shapes.size >= MAX_KEPT_SORTS
    @shapes[list] = { "size" => list.size, "shape" => shape(list) }
  end

  # Hashes a list's commands as MGQOnline.Data's ListShape does, see MGQ_MpStoryReplay.list_shape.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Integer] The shape.
  def self.shape(list)
    MGQ_MpStoryReplay.list_shape(list)
  end

  # Turns a parameter into a value that crosses the bridge.
  #
  # @param value [Object] The parameter.
  # @return [Object] It, an Array of its plain values, or nil.
  def self.plain(value)
    case value
    when nil, true, false, Integer then value
    when String then value.valid_encoding? ? value : nil
    when Array then value.map { |item| plain(item) }
    end
  end

  # Names a sort's list for the kept needs and answers.
  #
  # @param request [Hash] The request.
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Array] The key.
  def self.site_key(request, list)
    return [:page, request["map"], request["event"], request["page"]] if request["page"]
    return [:common, request["common"]] if request["common"]

    [:list, list.object_id]
  end

  # Finds a common event by its commands, as the game sets one up with its list alone.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Integer, nil] The common event, nil for none.
  def self.common_id(list)
    return nil unless $data_common_events

    unless @common_ids && @common_ids_of.equal?($data_common_events)
      @common_ids_of = $data_common_events
      @common_ids = {}.compare_by_identity
      $data_common_events.each_with_index { |common, id| @common_ids[common.list] = id if common && common.list }
    end
    @common_ids[list]
  end

  # Asks a topic of the sorter, handing over the values it names it needs until it has them all.
  #
  # @param topic [String] SORT_TOPIC, KINDS_TOPIC or LEAVES_PART_TOPIC.
  # @param request [Hash] The request, which takes the values.
  # @param needs [Hash] The values the DLL named for this list, by kind, kept and grown here.
  # @return [Hash, nil] The answer, nil when the DLL did not give one.
  def self.ask(topic, request, needs)
    open_events
    MAX_SORT_ROUNDS.times do
      request["values"] = values_of(needs)
      answer = MGQ_Multiplayer::Bridge.call(topic, request)
      return nil unless answer.is_a?(Hash)
      return answer unless answer["needs"]
      return nil unless add_needs(needs, answer["needs"])
    end
    nil
  end

  # Hands the DLL the game data's fingerprint once per session, before its first question about
  # events, so it reads only the tables of its events database that match this game's data; logs
  # what the DLL found.
  def self.open_events
    return if @events_opened

    @events_opened = true
    fingerprint = defined?(MGQ_MpWorld::GameData) ? MGQ_MpWorld::GameData.fingerprint : ""
    answer = MGQ_Multiplayer::Bridge.call(OPEN_TOPIC, "fingerprint" => fingerprint)
    return log("the DLL did not take the game data's fingerprint") unless answer.is_a?(Hash)
    return log("the DLL reads no events database: #{answer['problem']}; every list is handed over") unless answer["usable"]

    differing = Array(answer["differing"])
    log(differing.empty? ? "the DLL's events database matches this game's data" : "the DLL's events database differs from this game's data in #{differing.join(', ')}")
  end

  # Adds what the DLL named it needs to the kept needs.
  #
  # @param needs [Hash] The kept needs: each kind's ids as Hash keys.
  # @param wanted [Hash] The DLL's needs: each kind's ids.
  # @return [Boolean] Whether any is new.
  def self.add_needs(needs, wanted)
    grew = false
    wanted.each do |kind, ids|
      known = (needs[kind] ||= {})
      ids.each { |id| grew = known[id] = true unless known[id] }
    end
    grew
  end

  # Reads the values the DLL named: switches, variables (their whole numbers, nil for none), self
  # switches and whether switches and variables are the player's own.
  #
  # @param needs [Hash] The kept needs, see add_needs.
  # @return [Hash] The values, by kind and id.
  def self.values_of(needs)
    values = {}
    needs.each do |kind, ids|
      values[kind] = Hash[ids.keys.map { |id| [id, value_of(kind, id)] }]
    end
    values
  end

  # Reads one value the DLL named.
  #
  # @param kind [String] "s", "v", "ss", "ps" or "pv".
  # @param id [Integer, String] The switch or variable, or the self switch as "map.event.letter".
  # @return [Boolean, Integer, nil] The value.
  def self.value_of(kind, id)
    case kind
    when "s" then $game_switches ? $game_switches[id] == true : false
    when "ss" then $game_self_switches ? $game_self_switches[self_switch_key(id)] == true : false
    when "v" then $game_variables ? number($game_variables[id]) : 0
    when "ps" then defined?(MGQ_MpStoryState) && MGQ_MpStoryState.personal_switch?(id) ? true : false
    when "pv" then defined?(MGQ_MpStoryState) && MGQ_MpStoryState.personal_variable?(id) ? true : false
    end
  end

  # Reads a self switch's key from the name the DLL gives it.
  #
  # @param name [String] Such as "750.12.A".
  # @return [Array] Its map, event and letter.
  def self.self_switch_key(name)
    map_id, event_id, letter = name.to_s.split(".")
    [map_id.to_i, event_id.to_i, letter]
  end

  # Reads a variable as a branch does, its to_i, nil for a value without a number.
  #
  # @param value [Object] The variable's value.
  # @return [Integer, nil] Its number.
  def self.number(value)
    value.to_i
  rescue NoMethodError
    nil
  end

  # Takes the DLL's sort.
  #
  # @param answer [Hash] The answer.
  # @return [Hash] :kind, :list_kind, :may_tell, :scene and :marks, or :story.
  def self.answer_of(answer)
    return { :story => answer["story"] == true } if answer.key?("story")

    { :kind => answer["kind"].to_s.to_sym, :list_kind => answer["list_kind"].to_s.to_sym,
      :may_tell => answer["may_tell"] == true, :scene => answer["scene"] == true, :marks => Array(answer["marks"]) }
  end

  # The answer of a sort the DLL could not give, logged once per list: the list plays as the
  # player's own talk, as it would without the mod.
  #
  # @param key [Array] The list's key, see site_key.
  # @param index [Integer, nil] The command asked for.
  # @return [Hash] UNSORTED, or no story for a command.
  def self.unsorted(key, index)
    log_once([:unsorted, key[0]], "the DLL could not sort #{key[0].inspect}: it plays as a talk")
    index ? { :story => false } : UNSORTED
  end

  # Lists the self switches of the chests on the map: the map's chests among every chest of the game
  # the relay keeps (MGQ_MpStoryState.all_chest_keys); before the relay's rewards came, the chests
  # the DLL's events database names and, among the pages it holds otherwise, those the DLL sorts as
  # chests. Kept per map until the relay's rewards come in another revision.
  #
  # The relay's reviewed rows alone decide once they came, since they drop pages the database names
  # as chests on purpose, such as a world chest every player shares.
  #
  # @return [Array<Array>] Their keys: map, event and letter.
  def self.chest_keys
    relay = defined?(MGQ_MpStoryState) ? MGQ_MpStoryState.rewards : nil
    stamp = [$game_map.map_id, relay ? relay.rev : nil]
    return @chest_keys if @chest_keys_map == stamp

    @chest_keys_map = stamp
    return @chest_keys = relay.chests.select { |key| key[0] == $game_map.map_id } if relay

    events = $game_map.events.values
    letters = chest_letters(page_lists(events))
    held_otherwise = events.select { |event| (0...event.mgq_mp_pages.size).any? { |place| letters[[event.id, place]].nil? } }
    kinds = held_otherwise.empty? ? {} : page_kinds(held_otherwise)
    @chest_keys = events.map { |event| chest_key_of_pages(event, letters, kinds) }.compact
  end

  # Finds the self switch an event sets as a chest, on whichever of its pages gives the chest's
  # items, since a chest the player opened shows another page.
  #
  # @param event [Game_Event] The event.
  # @param letters [Hash] The chest letters of the map's pages, see chest_letters.
  # @param kinds [Hash] The kinds of the map's pages the DLL sorted at once, see page_kinds.
  # @return [Array, nil] Its key, nil when no page is a chest's.
  def self.chest_key_of_pages(event, letters = {}, kinds = {})
    pages = event.mgq_mp_pages
    pages.each_index do |place|
      letter = letters[[event.id, place]]
      return [$game_map.map_id, event.id, letter] if letter.is_a?(String)
      next if letter == false
      return chest_key(event, pages[place].list) if (kinds[[event.id, place]] || kind_of(pages[place].list || [])) == :chest
    end
    nil
  end

  # Lists the pages of events by their place.
  #
  # @param events [Array<Game_Event>] Events of the map.
  # @return [Hash{Array => Array<RPG::EventCommand>}] Each page's commands by [event, page].
  def self.page_lists(events)
    lists = {}
    events.each { |event| event.mgq_mp_pages.each_with_index { |page, place| lists[[event.id, place]] = page.list || [] } }
    lists
  end

  # Writes pages as a map's question to the DLL names them: [event, page, size, shape].
  #
  # @param lists [Hash{Array => Array<RPG::EventCommand>}] The pages, see page_lists.
  # @return [Array<Array>] The rows.
  def self.page_rows(lists)
    lists.keys.map { |site| site + size_and_shape(lists[site]).values_at("size", "shape") }
  end

  # Asks the DLL which pages of the map are chests by its events database.
  #
  # @param lists [Hash{Array => Array<RPG::EventCommand>}] The pages, see page_lists.
  # @return [Hash] By [event, page] the letter of the self switch a chest page turns on, or false for
  #   a page that is no chest; a page the database lacks or holds otherwise is left out.
  def self.chest_letters(lists)
    rows = page_rows(lists)
    answer = map_question(CHESTS_TOPIC, "rows" => rows)
    letters = {}
    Array(answer && answer["letters"]).each_with_index { |letter, place| letters[rows[place][0, 2]] = letter if letter.is_a?(String) || letter == false }
    letters
  end

  # Reads what the DLL's events database found in a page of the map's events: kept per map, asked
  # for every page of the map in one call.
  #
  # @param event [Game_Event] The event.
  # @param place [Integer] The page's place.
  # @return [Hash, nil] "scene_page", "runs_nothing", "fades_in" and "sets_encounters"; nil for a page
  #   the database lacks or holds otherwise.
  def self.page_flags(event, place)
    unless @page_flags_map == $game_map.map_id
      @page_flags_map = $game_map.map_id
      lists = page_lists($game_map.events.values)
      rows = page_rows(lists)
      answer = map_question(PAGES_TOPIC, "rows" => rows)
      @page_flags = {}
      Array(answer && answer["pages"]).each_with_index { |flags, row| @page_flags[rows[row][0, 2]] = flags if flags.is_a?(Hash) }
    end
    @page_flags[[event.id, place]]
  end

  # Lists the troops whose battles the pages events show start, directly or in the common events
  # they call, every branch counted, from the DLL's command index: the pages its events database
  # holds in one call, the others handed over in one more.
  #
  # @param events [Array<Game_Event>] Events of the map.
  # @param skip [Integer, nil] A switch whose common events' troops are left out, such as the
  #   Colosseum's.
  # @return [Hash{Integer => Array<Integer>}] Each event's troops, in their order, by its id; an
  #   event without a page has none.
  def self.page_troops(events, skip = nil)
    lists = {}
    events.each { |event| lists[[event.id, event.mgq_mp_page]] = event.list if event.mgq_mp_page >= 0 && event.list }
    indexes = page_indexes(lists, skip)
    troops = {}
    lists.each_key { |site| troops[site[0]] = indexes[site] ? Array(indexes[site]["troops"]) : [] }
    troops
  end

  # Lists what the page an event shows writes, directly or in the common events it calls, every
  # branch counted, from the DLL's command index.
  #
  # @param event [Game_Event] The event.
  # @return [Array<Array>] Each write: 0 or 1 with the switches' or variables' range, or 2 with the
  #   self switch's letter; none when the DLL cannot tell.
  def self.page_writes(event)
    place = event.mgq_mp_page
    return [] unless place >= 0 && event.list

    found = page_indexes({ [event.id, place] => event.list }, nil)[[event.id, place]]
    writes = found ? found["writes"] : nil
    return [] unless writes.is_a?(Hash)

    ranges = lambda { |kind| Array(writes[kind == 0 ? "s" : "v"]).map { |first, last| [kind, first.to_i..last.to_i] } }
    ranges.call(0) + ranges.call(1) + Array(writes["ss"]).map { |letter| [2, letter.to_s] }
  end

  # Asks the DLL's command index of pages of the map, see page_troops.
  #
  # @param lists [Hash{Array => Array<RPG::EventCommand>}] The pages, see page_lists.
  # @param skip [Integer, nil] See page_troops.
  # @return [Hash] Each answer by [event, page]: "troops" and "writes"; a page the DLL cannot tell of
  #   is left out.
  def self.page_indexes(lists, skip)
    indexes = {}
    index_pages(page_rows(lists), skip, indexes)
    held_otherwise = lists.keys.reject { |site| indexes.key?(site) }
    index_pages(held_otherwise.map { |site| site + [rows_of(lists[site])] }, skip, indexes) unless held_otherwise.empty?
    indexes
  end

  # Asks the DLL's command index of pages of the map in one call, see page_indexes.
  #
  # @param rows [Array<Array>] The pages: [event, page, size, shape] or [event, page, commands].
  # @param skip [Integer, nil] See page_troops.
  # @param indexes [Hash] The answers by [event, page], which takes those of these pages.
  def self.index_pages(rows, skip, indexes)
    question = { "pages" => rows }
    question["skip_turning_on"] = skip if skip
    answer = map_question(INDEX_TOPIC, question)
    Array(answer && answer["indexes"]).each_with_index { |found, place| indexes[rows[place][0, 2]] = found if found.is_a?(Hash) }
  end

  # Asks the DLL a question about pages of the map.
  #
  # @param topic [String] CHESTS_TOPIC, PAGES_TOPIC or INDEX_TOPIC.
  # @param fields [Hash] The question's fields besides the map.
  # @return [Hash, nil] The answer, nil when the DLL did not give one.
  def self.map_question(topic, fields)
    open_events
    answer = MGQ_Multiplayer::Bridge.call(topic, { "map" => $game_map.map_id }.merge(fields))
    answer.is_a?(Hash) ? answer : nil
  end

  # Sorts every page of the map's events in one call to the DLL, by its events database, and the
  # pages the database does not hold as the game shows them from their commands in one more call;
  # a page neither sorts is left to kind_of.
  #
  # @param events [Array<Game_Event>] The map's events.
  # @return [Hash] Each page's kind by [event, page].
  def self.page_kinds(events)
    lists = {}
    residents = []
    events.each do |event|
      event.mgq_mp_pages.each_with_index do |page, place|
        list = page.list || []
        lists[[event.id, place]] = list
        residents << [event.id, place] if defined?(MGQ_MpCoopCastle) && MGQ_MpCoopCastle.resident?(list)
      end
    end
    kinds = {}
    sort_pages(lists.keys.map { |site| site + size_and_shape(lists[site]).values_at("size", "shape") }, residents, kinds)
    held_otherwise = lists.keys.reject { |site| kinds.key?(site) }
    sort_pages(held_otherwise.map { |site| site + [rows_of(lists[site])] }, residents, kinds) unless held_otherwise.empty?
    kinds
  end

  # Sorts pages of the map in one call to the DLL, see page_kinds.
  #
  # @param rows [Array<Array>] The pages: [event, page, size, shape] or [event, page, commands].
  # @param residents [Array<Array>] The Pocket Castle residents' pages, each [event, page].
  # @param kinds [Hash] The kinds sorted, by [event, page], which takes those of these pages.
  def self.sort_pages(rows, residents, kinds)
    request = { "map" => $game_map.map_id, "pages" => rows }
    request["residents"] = residents unless residents.empty?
    answer = ask(KINDS_TOPIC, request, @needs[[:map, $game_map.map_id]] ||= {})
    Array(answer && answer["kinds"]).each_with_index { |kind, place| kinds[rows[place][0, 2]] = kind.to_s.to_sym if kind }
  end

  # Reports whether a self switch belongs to a chest on the map, which makes it the player's own.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @return [Boolean] Whether it does.
  def self.chest_key?(key)
    key[0] == $game_map.map_id && chest_keys.include?(key)
  end

  # Finds the self switch a chest sets.
  #
  # @param event [Game_Event] The chest.
  # @param list [Array<RPG::EventCommand>, nil] The commands of the chest's page, those of the page it shows by default.
  # @return [Array, nil] Its key, nil when the page sets none.
  def self.chest_key(event, list = event.list)
    command = (list || []).find { |c| c.code == 123 && c.parameters[1] == 0 }
    command ? [$game_map.map_id, event.id, command.parameters[0]] : nil
  end

  # Runs a block that sets up an event whose page counts as story, whatever page the event shows: a
  # frozen raid boss fight's resume runs the page of its battle while the event may show a later one
  # (see battles_raid_freeze.rbx).
  #
  # @return [Object] What the block returns.
  def self.as_story
    was = @as_story
    @as_story = true
    yield
  ensure
    @as_story = was
  end

  # Notices the map's main event starting: as leader brings the party together for a story scene.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @param list [Array<RPG::EventCommand>] Its commands.
  # @param event_id [Integer] The event, 0 for a common event.
  def self.started(interpreter, list, event_id)
    return unless $game_map && interpreter.equal?($game_map.interpreter)

    MGQ_MpCoopGather.drop_hold
    @lock_hold = nil
    event = event_id > 0 ? $game_map.events[event_id] : nil
    sorted = own?(event ? nil : list) ? :own : (event ? kind(event) : kind_of(list || []))
    sorted = :story if @as_story
    # A page of the leader's story that a scene change cut short must not hold the player's own; the
    # game's transfer process after a battle or a transfer shows nothing and leaves it.
    cut_page unless sorted == :own
    @telling = leading_story? && sorted == :story
    start_telling(interpreter, by_itself?(event))
    @may_tell = WATCHED_KINDS.include?(sorted) && (following? || leading_story?) && may_tell?(list || [], event)
    hold = @telling && scene?(list, event) && !MGQ_MpCoopGather.gathered?
    MGQ_MpCoopGather.hold(interpreter) if hold
    log_start(event, sorted, hold, list) if MGQ_MpCoop::Scope.sharing?
  end

  # Tells the DLL's telling machine of an event of the map's interpreter starting, which answers
  # how it goes on: with the telling whose last event ended in the same frame, with the one that
  # moved the player onto this map (an event that runs by itself within its frames), or as a new
  # telling, which in a Raid World takes the relay's telling lock of the map and waits at its first
  # command for the answer (see lock_holding?).
  #
  # @param interpreter [Game_Interpreter] The map's interpreter.
  # @param by_itself [Boolean] Whether the event runs by itself.
  def self.start_telling(interpreter, by_itself)
    site = defined?(MGQ_MpStoryKeys) ? MGQ_MpStoryKeys.site_of(interpreter) : nil
    answer = MGQ_Multiplayer::Bridge.call(TELLING_START_TOPIC, "telling" => @telling, "by_itself" => by_itself, "map" => $game_map.map_id, "site" => site)
    return unless @telling

    case answer && answer["continued"]
    when "frame" then log("the story's next event goes on with the telling that started on map #{answer['from']}")
    when "moved" then log("the story's next event goes on with the telling that moved the player from map #{answer['from']}")
    else
      note_telling_start
      return unless answer

      @lock_hold = interpreter if answer["hold"]
      log("holding the story event at its first command until the relay answers for the telling's lock on map #{$game_map.map_id}") if @lock_hold
      log_once([:telling_site, $game_map.map_id], "the relay hears no telling on map #{$game_map.map_id}: no event of the map or common event tells it (#{site})") if !answer["locked"] && MGQ_MpCoop::Scope.raid?
    end
  rescue => e
    log("starting the telling failed: #{e.class}: #{e.message}")
  end

  # Notes that a new telling of the player starts: those an earlier telling took along no longer
  # see it, and in a Raid World the values that move the world's story on are noted.
  def self.note_telling_start
    MGQ_Multiplayer::Bridge.call(PAGE_TELLING_TOPIC)
    MGQ_MpCoopGather.forget_taken_along if defined?(MGQ_MpCoopGather)
    MGQ_MpCoopGather.note_story_progress if defined?(MGQ_MpCoopGather)
  rescue => e
    log("noting the story's progress failed: #{e.class}: #{e.message}")
  end

  # Reports whether an event starts by itself, as the story's next event after its transfer does: a
  # map event that runs by itself, or a common event a switch starts. One the player starts is no
  # part of the telling that moved them.
  #
  # @param event [Game_Event, nil] The event, nil for a common event.
  # @return [Boolean] Whether it does.
  def self.by_itself?(event)
    event.nil? || event.trigger == 3
  end

  # Tells the DLL's telling machine that the player's telling moves them onto another map, as the
  # story's transfer does, so the story's next event there, one that runs by itself, goes on with
  # the telling (see start_telling). Called before Game_Player#perform_transfer.
  #
  # @param player [Game_Player] The player.
  def self.moving(player)
    return unless player.transfer? && telling?

    @moving = true
    MGQ_Multiplayer::Bridge.call(TELLING_MOVING_TOPIC, "map" => $game_map.map_id)
  rescue => e
    log("noting the story's move failed: #{e.class}: #{e.message}")
  end

  # Tells the DLL's telling machine that the player's telling landed them on the new map, while its
  # event still runs, so the relay's telling lock moves there at once and no other game tells the
  # story there meanwhile. Called after Game_Player#perform_transfer.
  def self.arrived
    return unless @moving

    @moving = false
    MGQ_Multiplayer::Bridge.call(TELLING_ARRIVED_TOPIC, "map" => $game_map.map_id)
  rescue => e
    log("noting the story's arrival failed: #{e.class}: #{e.message}")
  end

  # Reports whether a story event still waits at its first command for the relay's answer for the
  # telling's lock (see start_telling): once the relay refused it, another player tells the story
  # on the map, and the event ends before its first command. A refusal that names nobody, or no
  # answer in time, lets the event run without the lock. Asked before each of the interpreter's
  # commands.
  #
  # @param interpreter [Game_Interpreter] The interpreter about to run a command.
  # @return [Boolean] Whether it waits.
  def self.lock_holding?(interpreter)
    return false unless @lock_hold && @lock_hold.equal?(interpreter)

    answer = MGQ_Multiplayer::Bridge.call(TELLING_COMMAND_TOPIC)
    command = answer ? answer["command"] : "go"
    return true if command == "hold"

    @lock_hold = nil
    log("the story event on map #{$game_map.map_id} runs without the telling's lock: the relay named no teller there or gave no answer in time") if command == "unlocked"
    return false unless command == "end"

    @telling = false
    holder = peer_at(answer["holder"])
    log("stopped the player's story event: the relay refused the telling's lock, #{holder ? MGQ_MpOverworldSync.who(holder) : 'another player'} tells the story on map #{$game_map.map_id}")
    list = MGQ_MpGame.get(interpreter, :list)
    end_event(interpreter, list, "another player tells the story here") if list
    MGQ_MpOverworldSync.notice(holder ? refusal_text(holder) : LOCK_REFUSAL_TEXT)
    false
  rescue => e
    @lock_hold = nil
    log("holding a story event for the telling's lock failed: #{e.class}: #{e.message}")
    false
  end

  # Finds another player by their seat.
  #
  # @param seat [Integer, nil] The seat, nil for none.
  # @return [MGQ_MpOverworldSync::Peers::Peer, nil] The player, nil for none known.
  def self.peer_at(seat)
    return nil if seat.nil? || !MGQ_MpOverworldSync::Peers.respond_to?(:all)

    MGQ_MpOverworldSync::Peers.all.find { |peer| peer.seat == seat }
  end

  # Logs how an event starting on the map is sorted and what the party does with it.
  #
  # @param event [Game_Event, nil] The event, nil for a common event.
  # @param sorted [Symbol] How it is sorted, see kind.
  # @param hold [Boolean] Whether the leader's game holds it for the party to gather.
  # @param list [Array<RPG::EventCommand>, nil] A common event's commands, nil for a map event.
  def self.log_start(event, sorted, hold, list = nil)
    common = own_common_id(list)
    what = event ? "event #{event.id} (page #{event.mgq_mp_page + 1})" : (common ? "common event #{common}" : "a common event")
    what += " on map #{$game_map.map_id}"
    notes = []
    notes << "runs only in the player's own game#{library_replay? ? ": the Library's replay of a scene" : ''}" if sorted == :own
    notes << "resumed as story" if @as_story
    notes << "the leader tells the party this story" if @telling
    notes << "the player plays their own story, not synced with the leader or leading no member who follows it" unless following? || leading_story?
    notes << "held until the party gathers" if hold
    notes << "may turn into story behind a choice, watched" if @may_tell
    log("#{what} starts as #{sorted}#{notes.empty? ? '' : ": #{notes.join(', ')}"}")
  rescue => e
    log("logging an event's start failed: #{e.class}: #{e.message}")
  end

  # Watches a talk or travel that may turn into story (see WATCHED_KINDS), before each of its
  # commands: once it reaches a command that moves the story on, a member's game ends it there,
  # since only the leader moves the story on, and the leader's game tells the party the story from
  # there.
  #
  # @param interpreter [Game_Interpreter] The interpreter about to run a command.
  def self.guard(interpreter)
    return unless @may_tell && interpreter.equal?($game_map.interpreter)

    list = MGQ_MpGame.get(interpreter, :list)
    index = MGQ_MpGame.get(interpreter, :index).to_i
    event_id = MGQ_MpGame.get(interpreter, :event_id).to_i
    return unless list && list[index] && story_command?(list, index, event_id > 0 ? $game_map.events[event_id] : nil)

    @may_tell = false
    lead = MGQ_MpCoop::Scope.teller
    why = behind? ? leaving_part(list, event_id > 0 ? $game_map.events[event_id] : nil) : nil
    if why
      log("ended a talk where it would move the story on (command #{list[index].code}): the player's story is behind the world's and #{why}")
      end_event(interpreter, list, "a talk ended where it would move the story on")
      MGQ_MpOverworldSync.notice(MGQ_MpWorldCatchup.refusal_text)
    elsif lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && following?
      log("ended a talk where it would move the story on (command #{list[index].code})")
      end_event(interpreter, list, "a talk ended where it would move the story on")
      MGQ_MpOverworldSync.notice(refusal_text(lead))
    elsif leading_story?
      @telling = true
      start_telling(interpreter, false)
      log("a talk moves the story on (command #{list[index].code}), the party hears it from here")
    end
  rescue => e
    @may_tell = false
    log("watching a talk failed: #{e.class}: #{e.message}")
  end

  # Ends the event an interpreter runs before its next command, and takes back what the event
  # changed of the screen, the player's character and the party, see MGQ_MpCoopScene::Own.cut.
  #
  # @param interpreter [Game_Interpreter] The map's interpreter.
  # @param list [Array<RPG::EventCommand>] The commands it runs.
  # @param reason [String] Why, for the log.
  def self.end_event(interpreter, list, reason)
    # The list ends with an empty command, which ends the event as its last.
    MGQ_MpGame.set(interpreter, :index, list.size - 1)
    MGQ_MpCoopScene::Own.cut(reason) if defined?(MGQ_MpCoopScene::Own)
  end

  # Tells the player that another player's story keeps theirs from moving on.
  #
  # @param lead [MGQ_MpOverworldSync::Peers::Peer] Who tells the story: the party's leader, or the
  #   player telling it on the map in a Raid World.
  # @return [String] The notice.
  def self.refusal_text(lead)
    MGQ_MpCoop::Scope.raid? ? "#{lead.state['name']} is telling the story here." : "Only #{lead.state['name']} can move the story on."
  end

  # Reports whether the leader's main event plays story now, whose companions join the members too.
  #
  # @return [Boolean] Whether it does.
  def self.telling?
    @telling && $game_map && $game_map.interpreter.running? ? true : false
  end

  # Sends the party, or the map in a Raid World, a message about events, see MGQ_MpCoop::Scope.tell.
  #
  # @param seat [Integer] A player's seat, -1 for everyone, who ignore it outside the scope.
  # @param kind [String] What it is about.
  # @param fields [Hash] Its other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, fields = {})
    sent = MGQ_MpCoop::Scope.tell(seat, "pevent", kind, fields)
    log("#{sent ? 'sent' : 'could not send'} #{kind} to #{seat < 0 ? 'the party' : "seat #{seat}"} (#{MGQ_MpCoop.bytes_of(fields)} bytes)")
    sent
  end

  # Sends several players of the party, or of the map in a Raid World, one message about events,
  # see MGQ_MpCoop::Scope.tell_each.
  #
  # @param peers [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  # @param kind [String] What it is about.
  # @param fields [Hash] Its other fields.
  # @return [Boolean] Whether it went out to every one.
  def self.tell_each(peers, kind, fields = {})
    sent = MGQ_MpCoop::Scope.tell_each(peers, "pevent", kind, fields)
    log("#{sent ? 'sent' : 'could not send'} #{kind} to #{peers.map { |peer| MGQ_MpOverworldSync.who(peer) }.join(', ')} (#{MGQ_MpCoop.bytes_of(fields)} bytes)")
    sent
  end

  # As teller, sends a message about the story to those who see it, in one message.
  #
  # @param kind [String] What it is about.
  # @param fields [Hash] Its other fields.
  # @param followers [Array<MGQ_MpOverworldSync::Peers::Peer>] Those who see it, see
  #   MGQ_MpCoop::Scope.viewers.
  def self.tell_followers(kind, fields, followers = MGQ_MpCoop::Scope.viewers)
    return log("told nobody #{kind}: nobody follows the player's story") if followers.empty?

    tell_each(followers, kind, fields)
  end

  # Reports whether the player's story is another player's to move on: their leader's they follow,
  # or in a Raid World the one telling it on the map, see MGQ_MpCoop::Scope.follows_teller?.
  #
  # @return [Boolean] Whether it is.
  def self.following?
    MGQ_MpCoop::Scope.follows_teller?
  end

  # Reports whether the player tells their story to others: as a leader with members who follow
  # it, or in a Raid World while nobody else tells it on the map, see MGQ_MpCoop::Scope.leads_story?.
  #
  # @return [Boolean] Whether they do.
  def self.leading_story?
    MGQ_MpCoop::Scope.leads_story?
  end

  # Reports whether the leader's story scene plays now, held no more, which keeps the members still.
  #
  # @return [Boolean] Whether it does.
  def self.story_playing?
    telling? && !MGQ_MpCoopGather.holding_story?
  end

  # The fields the party's events add to the state the player's game tells the others.
  #
  # @return [Hash] "telling": 1 while the player's story scene plays for the party.
  def self.state_fields
    { "telling" => story_playing? ? 1 : 0 }
  end

  # Reports whether the player shares the chests they open: with their party in a Classic world.
  # A Raid World's parties share no loot.
  #
  # @return [Boolean] Whether they do.
  def self.shares_chests?
    MGQ_MpCoop.in_party? && !MGQ_MpCoop::Scope.raid?
  end

  # Takes a message about the party's events from another member.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take_party(peer, message)
    kind = message["pevent"]
    return MGQ_MpCoopGather.take(peer, message) if GATHER_MESSAGES.include?(kind)

    scope = MGQ_MpCoop::Scope
    unless scope.story_from?(peer)
      return log("ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: not from #{scope.raid? ? 'the player telling the story here' : "the party's leader"} (#{MGQ_MpOverworldSync.who(scope.teller)})")
    end
    scope.heard_from(peer)
    unless scope.watches?(peer)
      return log_once([:not_watching, kind, peer ? peer.state["id"].to_s : nil], "ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: #{scope.raid? ? 'the relay told of no telling of theirs on the player\'s track' : 'not synced with the leader, the player plays their own story'}")
    end

    case kind
    when "say"
      if MGQ_MpCoopGather.story_map?(message["map"].to_i)
        hear(peer, message)
      else
        log("dropped page #{message['page']} of #{MGQ_MpOverworldSync.who(peer)}'s story: told on map #{message['map']}, not the story's map for the player (on map #{$game_map ? $game_map.map_id : '?'})")
      end
    when "done" then heard_done(message, peer)
    else log("ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: unknown kind")
    end
  rescue => e
    log("taking #{message['pevent']} failed: #{e.class}: #{e.message}")
  end

  # Keeps a member's story event from starting: only the leader starts story, in their own game.
  # In a Raid World only while another player tells the story on the map, while the player follows
  # a teller's story to where it moved them (held_following), while the player's story is behind
  # the world's and the event would end their part (held_behind?), or until the world's story came
  # (awaits_world_story). Called when the map's main event would start it. A new game's opening never starts while world_opening.rbx runs
  # its setup without its scene.
  #
  # An event that runs by itself is left to the teller's own game, which runs it on its map.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it is the teller's, so it must not run here.
  def self.hand_over(event)
    return true if defined?(MGQ_MpWorldOpening) && MGQ_MpWorldOpening.holds?(event)
    return awaits_world_story(event) if defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.awaits_world? && !own? && kind(event) == :story
    return true if behind? && !own? && kind(event) == :story && held_behind?(event)

    follow = MGQ_MpCoopGather.follow_taken
    return held_following(event, follow) if follow && !own? && kind(event) == :story

    lead = MGQ_MpCoop::Scope.teller
    return awaits_told_story?(event) unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)
    return false unless !own? && kind(event) == :story
    unless following?
      log_once([:own_story, $game_map.map_id, event.id, lead.state["id"].to_s], "story event #{event.id} on map #{$game_map.map_id} runs in the player's own game: not synced with #{MGQ_MpOverworldSync.who(lead)}, the player plays their own story")
      return false
    end
    if event.trigger == 3
      return false if MGQ_MpCoop::Scope.telling?(lead) && lead.state["scene"] != "battle" && MGQ_MpCoop::Scope.silent?(lead)

      log_once([:autorun, $game_map.map_id, event.id, lead.state["id"].to_s],
               "kept event #{event.id} on map #{$game_map.map_id} that runs by itself from starting: it is story, which #{MGQ_MpOverworldSync.who(lead)}'s game runs")
      @kept_autorun = { :teller => lead.state["id"].to_s, :map => $game_map.map_id, :frame => Graphics.frame_count }
      fade_in_late(event, lead)
      return true
    end

    refuse_story(event, lead)
    true
  rescue => e
    log("keeping a story event from starting failed: #{e.class}: #{e.message}")
    false
  end

  # Reports whether the player's game keeps its own copy of a teller's story event that runs by
  # itself from starting on the player's map, which starts the moment the teller leaves it (see
  # hand_over).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  # @return [Boolean] Whether it does.
  def self.keeps_autorun_of?(peer)
    kept = @kept_autorun
    return false unless kept && $game_map && kept[:map] == $game_map.map_id && kept[:teller] == peer.state["id"].to_s

    elapsed = Graphics.frame_count - kept[:frame]
    elapsed >= 0 && elapsed <= KEPT_AUTORUN_FRAMES
  end

  # Fades the screen in once per arrival on a map whose story event that runs by itself another
  # player's game runs, while the screen is dark.
  #
  # The game's scenes fade out, move the player without a fade and fade in with that event, so a
  # player who came while its teller fought, as at Morrigan, would see black until the story ended.
  #
  # @param event [Game_Event] The story event kept from starting.
  # @param lead [MGQ_MpOverworldSync::Peers::Peer] The teller whose game runs it.
  def self.fade_in_late(event, lead)
    screen = $game_map.screen
    arrival = [$game_map.map_id, MGQ_MpOverworldSync::Me.map_since]
    return if screen.brightness > 0 || @faded_in_arrival == arrival

    @faded_in_arrival = arrival
    screen.start_fadein(LATE_FADEIN_FRAMES)
    log("faded the screen in on map #{$game_map.map_id}: the player came in the middle of #{MGQ_MpOverworldSync.who(lead)}'s story, whose event #{event.id} would have faded it in")
  rescue => e
    log("fading the screen in for a story under way failed: #{e.class}: #{e.message}")
  end

  # Fades the screen in once it stayed dark for DARK_SCREEN_FRAMES while nothing could fade it in,
  # or for WATCHED_DARK_FRAMES while the player watches another player's scene that shows nothing.
  #
  # A story event whose fade-in another game's story already ran, as an arrival after a game over
  # returned the player to an earlier point, leaves the screen black for good.
  def self.lift_dark_screen
    return @dark_frames = 0 unless stuck_dark?

    watching = MGQ_MpCoopScene.watching?
    limit = watching ? WATCHED_DARK_FRAMES : DARK_SCREEN_FRAMES
    @dark_frames = @dark_frames.to_i + 1
    return if @dark_frames < limit

    @dark_frames = 0
    $game_map.screen.start_fadein(LATE_FADEIN_FRAMES)
    log("faded the screen in on map #{$game_map.map_id}: it stayed dark for #{limit} frames with no event running that could fade it in" \
        "#{watching ? ", and nothing of the scene the player watches reached the screen" : ''}")
  rescue => e
    log_once(:dark_screen, "fading in a screen left dark failed: #{e.class}: #{e.message}")
  end

  # Reports whether the screen is dark in a world while the player stands free on the map: no
  # event runs or starts, no message shows, no transfer waits, no change of another player's scene
  # the player watches reached the screen a moment ago and no opening's setup runs.
  #
  # @return [Boolean] Whether it is.
  def self.stuck_dark?
    return false unless MGQ_MpOverworldSync.in_world? && SceneManager.scene_is?(Scene_Map) && $game_map.screen.brightness == 0
    return false if $game_map.interpreter.running? || $game_message.busy? || $game_player.transfer?
    return false if $game_map.events.values.any? { |event| event.starting }
    return false if (MGQ_MpCoopScene.watching? && MGQ_MpCoopScene.just_changed?) || (defined?(MGQ_MpWorldOpening) && MGQ_MpWorldOpening.running?)

    !parallel_fade_in?
  end

  # Reports whether an event running alongside the map, of the map or a common one, fades the
  # screen in itself, as the game's dark transitions do.
  #
  # @return [Boolean] Whether one does.
  def self.parallel_fade_in?
    lists = $game_map.events.values.select { |event| event.trigger == PARALLEL_TRIGGER }.map(&:list)
    lists += $game_map.parallel_common_events.select { |common| $game_switches[common.switch_id] }.map(&:list)
    lists.any? { |list| list && list.any? { |command| command.code == FADEIN_CODE } }
  end

  # Reports whether the player's story is behind a Raid World's, which keeps their story events that
  # would end their part from starting, see MGQ_MpWorldCatchup.holds_story?.
  #
  # @return [Boolean] Whether it is.
  def self.behind?
    defined?(MGQ_MpWorldCatchup) && MGQ_MpWorldCatchup.holds_story? ? true : false
  end

  # Finds whether a story event would move the player's story past the end of the part they play
  # while behind the world's, as the DLL reads from the keys it and the chain it starts across maps
  # write (issue #48); every other story event runs. The DLL names the switches, variables and self
  # switches the pages of the chain check (needs, as for sorting), and the answer is kept per list,
  # the map and event that run it and the part while those stay as they were, since an event that
  # runs by itself starts again every frame.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param event [Game_Event, nil] The event whose page the list may be, or that runs it; nil for none.
  # @return [String, nil] Why it would leave the part, nil when it stays in it; an event the DLL
  #   cannot tell of leaves it.
  def self.leaving_part(list, event = nil)
    request = request_for(list, event)
    table = defined?(MGQ_MpStoryKeys) ? MGQ_MpStoryKeys.raid_table : nil
    key = [site_key(request, list), list.size, request["map"], request["event"], defined?(MGQ_MpWorldStory) ? MGQ_MpWorldStory.part : nil, table ? table.rev : nil]
    needs = (@part_needs[key[0]] ||= {})
    kept = @leaving[key]
    return kept[1] if kept && kept[0] == values_of(needs)

    answer = ask(LEAVES_PART_TOPIC, request, needs)
    answer = ask(LEAVES_PART_TOPIC, inline_request(list, event), needs) if answer && answer["unknown"] && !request["list"]
    return "the DLL could not tell what it writes" unless answer && !answer["unknown"]

    @leaving.clear if @leaving.size >= MAX_KEPT_SORTS
    why = answer["leaves"] ? answer["why"].to_s : nil
    @leaving[key] = [values_of(needs), why]
    why
  end

  # Keeps a story event from starting while the player's story is behind the world's and the event
  # would move it past the end of their part (see leaving_part): one they start tells the level that
  # moves them on, once per event in REFUSE_FRAMES, and one that runs by itself waits silently, so a
  # teleport onto its map cannot loop.
  #
  # @param event [Game_Event] The story event.
  # @return [Boolean] Whether it must not run.
  def self.held_behind?(event)
    why = leaving_part(event.list || [], event)
    unless why
      log_once([:behind_runs, $game_map.map_id, event.id], "story event #{event.id} on map #{$game_map.map_id} may start while the player's story is behind the world's: it moves nothing past the end of their part")
      return false
    end
    if event.trigger == 3
      log_once([:behind_autorun, $game_map.map_id, event.id], "kept event #{event.id} on map #{$game_map.map_id} that runs by itself from starting: the player's story is behind the world's and #{why}")
      return true
    end

    return true if refused_lately?([$game_map.map_id, event.id])

    log("kept story event #{event.id} on map #{$game_map.map_id} from starting: the player's story is behind the world's and #{why}")
    MGQ_MpOverworldSync.notice(MGQ_MpWorldCatchup.refusal_text)
    true
  end

  # Keeps a story event from starting in a Raid World while the world's story has not come since
  # the world opened or a save loaded, see MGQ_MpWorldStory.awaits_world?. Logged once per event and
  # never noticed, since it lasts a moment.
  #
  # @param event [Game_Event] The story event.
  # @return [Boolean] Always true: it must not run yet.
  def self.awaits_world_story(event)
    log_once([:await_world, $game_map.map_id, event.id], "kept event #{event.id} on map #{$game_map.map_id} from starting: the world's story has not come yet")
    true
  end

  # Keeps a story event from starting while the player follows a teller's story to where it moved
  # them, see MGQ_MpCoopGather.follow_taken: the player's own copy of that story would otherwise
  # start while the teller's state says they tell nothing, as it does between the story's events.
  # Logged once per event and never noticed, since the line above the player's head says whom they
  # join.
  #
  # @param event [Game_Event] The story event.
  # @param follow [Hash] The follow, see MGQ_MpCoopGather.follow_taken.
  # @return [Boolean] Always true: it must not run.
  def self.held_following(event, follow)
    log_once([:following, $game_map.map_id, event.id],
             "kept event #{event.id} on map #{$game_map.map_id} from starting: the player follows #{follow[:name]}'s story to map #{follow[:place][0]}")
    true
  end

  # Keeps a story event from starting in a Raid World while the world's story of a telling the
  # player watched on the map has not arrived yet, see MGQ_MpWorldStory.awaits_teller?.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it must not run yet.
  def self.awaits_told_story?(event)
    return false unless defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.awaits_teller? && !own? && kind(event) == :story

    tell_await(event)
    true
  end

  # Tells the player that their story event waits for the world's story of a telling they watched,
  # once per event in REFUSE_FRAMES, since an event the player stands on starts again with every
  # step.
  #
  # @param event [Game_Event] The story event.
  def self.tell_await(event)
    return if refused_lately?([:await, $game_map.map_id, event.id])

    teller = MGQ_MpWorldStory.watched_teller
    log("kept story event #{event.id} on map #{$game_map.map_id} from starting: the world's story of the telling the player watched#{teller ? " (#{teller})" : ''} has not arrived yet")
    MGQ_MpOverworldSync.notice(format(AWAIT_TOLD_TEXT, teller || "another player"))
  end

  # Tells the member that only the teller moves the story on, once per event in REFUSE_FRAMES,
  # since an event the player stands on starts again with every step.
  #
  # @param event [Game_Event] The story event.
  # @param lead [MGQ_MpOverworldSync::Peers::Peer] The teller.
  def self.refuse_story(event, lead)
    return if refused_lately?([$game_map.map_id, event.id])

    log("kept story event #{event.id} on map #{$game_map.map_id} from starting: only #{MGQ_MpOverworldSync.who(lead)} starts story (on map #{lead.state['map']})")
    away = lead.state["map"].to_i == $game_map.map_id || MGQ_MpCoop::Scope.raid? ? "" : " Bring them here to go on."
    MGQ_MpOverworldSync.notice("#{refusal_text(lead)}#{away}")
  end

  # Reports whether the player heard of a refused story event within REFUSE_FRAMES, else notes that
  # they hear of it now, so an event the player stands on, which starts again with every step,
  # tells its refusal once.
  #
  # @param key [Array] The refusal's kind and event.
  # @return [Boolean] Whether they heard of it lately.
  def self.refused_lately?(key)
    return true if @refused == key && !past?(@refused_at, REFUSE_FRAMES)

    @refused = key
    @refused_at = Graphics.frame_count
    false
  end

  # Reports whether some frames have passed since a frame.
  #
  # A loaded save sets the frame count back, so a frame ahead of it is long past.
  #
  # @param since [Integer] The frame.
  # @param frames [Integer] How many frames.
  # @return [Boolean] Whether they have.
  def self.past?(since, frames)
    elapsed = Graphics.frame_count - since.to_i
    elapsed < 0 || elapsed >= frames
  end

  # Reports whether what starts runs only in the player's own game, never as the party's story:
  # anything while the Library replays a scene, whose replay the leader's game would otherwise
  # bring the members over to, and the common events of OWN_COMMON_EVENTS.
  #
  # The game sets a common event up with its list alone, so the list is compared with each one's.
  #
  # @param list [Array<RPG::EventCommand>, nil] The common event's commands, nil for a map event.
  # @return [Boolean] Whether it does.
  def self.own?(list = nil)
    return true if library_replay?
    return false unless list

    own_common_id(list) ? true : false
  rescue => e
    log_once(:own, "telling the player's own events apart failed: #{e.class}: #{e.message}")
    false
  end

  # Finds which of OWN_COMMON_EVENTS a list is.
  #
  # @param list [Array<RPG::EventCommand>, nil] The common event's commands, nil for a map event.
  # @return [Integer, nil] Its id, nil for none of them.
  def self.own_common_id(list)
    list && OWN_COMMON_EVENTS.find { |id| (common = $data_common_events[id]) && list.equal?(common.list) }
  end

  # Reports whether the Library replays a scene now.
  #
  # @return [Boolean] Whether it does.
  def self.library_replay?
    switch = defined?(NWConst::Sw::LIBRARY_H_MEMORY) ? NWConst::Sw::LIBRARY_H_MEMORY : LIBRARY_REPLAY_SWITCH
    $game_switches[switch] ? true : false
  end

  # Reports whether a common event that runs by itself is left to the teller's game, or held while
  # the player's story is behind a Raid World's.
  #
  # @param common [RPG::CommonEvent] The common event.
  # @return [Boolean] Whether it is.
  def self.leave_to_leader?(common)
    if defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.awaits_world? && !own?(common.list) && kind_of(common.list || []) == :story
      log_once([:await_world_common, common.respond_to?(:id) ? common.id : "?"], "kept common event #{common.respond_to?(:id) ? common.id : '?'} that runs by itself from starting: the world's story has not come yet")
      return true
    end
    why = behind? && !own?(common.list) && kind_of(common.list || []) == :story ? leaving_part(common.list || []) : nil
    if why
      log_once([:behind_common, common.respond_to?(:id) ? common.id : "?"], "kept common event #{common.respond_to?(:id) ? common.id : '?'} that runs by itself from starting: the player's story is behind the world's and #{why}")
      return true
    end

    lead = MGQ_MpCoop::Scope.teller
    left = lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && following? && !own?(common.list) && kind_of(common.list || []) == :story
    if left
      id = common.respond_to?(:id) ? common.id : "?"
      log_once([:common, id, lead.state["id"].to_s], "kept common event #{id} that runs by itself from starting: it is story, which #{MGQ_MpOverworldSync.who(lead)}'s game runs")
    end
    left
  rescue
    false
  end

  # As teller, hands the DLL the message the player's story shows now, which names it and tells it
  # to those who see the story at once, or while the player holds the game's skip within a few
  # frames of the last page told keeps it instead, replacing the one kept before; flush_say tells
  # it. Called before an interpreter waits for a message.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.show(interpreter)
    return unless @telling && main_event?(interpreter)

    message = $game_message
    answer = MGQ_Multiplayer::Bridge.call(PAGE_SHOW_TOPIC, "lines" => message.texts.map { |line| line.to_s }, "choices" => message.choices.map { |choice| choice.to_s },
                                                           "face" => message.face_name.to_s, "index" => message.face_index.to_i, "background" => message.background.to_i,
                                                           "position" => message.position.to_i, "skip" => skip_held?)
    @page_open = true
    return unless answer

    page = { :id => answer["id"], :fields => MGQ_MpCoopGather.place_fields.merge(answer["fields"]), :note => answer["note"], :viewers => MGQ_MpCoop::Scope.viewers }
    @kept_say = answer["told"] ? nil : page
    tell_say(page, answer["skipped"]) if answer["told"]
  rescue => e
    log("telling a message failed: #{e.class}: #{e.message}")
  end

  # Reports whether the player holds the game's message skip (SKIP_BUTTON).
  #
  # @return [Boolean] Whether they do.
  def self.skip_held?
    Input.press?(SKIP_BUTTON) ? true : false
  rescue
    false
  end

  # As teller, tells a page of the player's story to those who see it.
  #
  # @param page [Hash] The page: :id, :fields, :note (what the log says of it) and :viewers, those
  #   who saw the story as it showed.
  # @param skipped [Integer] The pages kept before it the player skipped past, which never went out.
  def self.tell_say(page, skipped)
    log("telling the party page #{page[:id]} of the story: #{page[:note]}#{skipped.to_i > 0 ? ", left out the #{skipped} page(s) before it the player skipped past" : ''}")
    tell_followers("say", page[:fields], page[:viewers])
  end

  # As teller, tells those who see the story that the player moved past a page told.
  #
  # @param id [String] The page's id.
  # @param viewers [Array<MGQ_MpOverworldSync::Peers::Peer>] Those who see the story.
  def self.tell_done(id, viewers = MGQ_MpCoop::Scope.viewers)
    log("the leader moved past page #{id}, telling the party")
    tell_followers("done", MGQ_MpCoopGather.place_fields.merge("page" => id), viewers)
  end

  # As teller, tells the page kept while the player holds the game's skip, and that the player
  # moved past it if they did, once the DLL finds it due: a few frames after the last page told,
  # once the skip is let go, the telling ended or another scene was called, so the viewers end on
  # the last page. Called after the map's update, after the frame's pages.
  #
  # It goes to those who saw the story as the page showed, since a Raid World's viewers are nobody
  # once its telling ended.
  def self.flush_say
    return unless @kept_say

    answer = MGQ_Multiplayer::Bridge.call(PAGE_FLUSH_TOPIC, "skip" => skip_held?, "telling" => @telling ? true : false, "map" => SceneManager.scene.is_a?(Scene_Map))
    return unless answer

    page = @kept_say
    @kept_say = nil
    tell_say(page, answer["skipped"])
    tell_done(page[:id], page[:viewers]) if answer["passed"]
  rescue => e
    @kept_say = nil
    log_once(:flush_say, "telling a page kept while the player skips failed: #{e.class}: #{e.message}")
  end

  # Reports whether an interpreter runs the map's main event: the map's own, or a common event it
  # calls, which the game runs in a child interpreter (command 117), so the dialogue of the common
  # events a story calls, such as the companions' lines, reaches the party too.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @return [Boolean] Whether it does.
  def self.main_event?(interpreter)
    interpreter.equal?($game_map.interpreter) || (defined?(MGQ_MpCoopScene) && MGQ_MpCoopScene.map_turn?) ? true : false
  end

  # As teller, tells those who see the story that the player moved past the message their story
  # showed, which moves the viewers' window on, once the DLL names a page told whose end goes out;
  # the end of the page kept while the player skips goes with it, see flush_say. Called once an
  # interpreter waited for a message.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.shown(interpreter)
    return unless @page_open && main_event?(interpreter)

    @page_open = false
    id = MGQ_Multiplayer::Bridge.call(PAGE_PASSED_TOPIC)
    tell_done(id) if id
  rescue => e
    log("telling a message's end failed: #{e.class}: #{e.message}")
  end

  # Hands the DLL a page of the teller's story to show once the player is free.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  # @param message [Hash] The message's fields.
  def self.hear(peer, message)
    forget_former_leader(peer)
    @page_asked = nil
    answer = MGQ_Multiplayer::Bridge.call(PAGE_HEAR_TOPIC, "page" => message["page"].to_s, "name" => peer.state["name"].to_s, "face" => message["face"].to_s,
                                                           "index" => message["index"].to_i, "background" => message["background"].to_i,
                                                           "position" => message["position"].to_i, "lines" => message["lines"].to_s, "choices" => message["choices"].to_s)
    unless answer && !answer["refused"]
      return log("dropped page #{message['page']} of #{MGQ_MpOverworldSync.who(peer)}'s story: #{answer ? answer['refused'] : 'the DLL did not keep it'}")
    end

    @waiting = answer["waiting"].to_i
    dropped = answer["dropped"].to_i
    log("heard page #{message['page']} of #{MGQ_MpOverworldSync.who(peer)}'s story: #{answer['lines']} lines, #{answer['choices']} choices, " \
        "#{@waiting} waiting to show#{dropped > 0 ? ", dropped the #{dropped} oldest" : ''}")
  end

  # Tells the DLL that the teller moved past a page of their story.
  #
  # @param message [Hash] The message's fields, the page's id under "page".
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] The teller, nil when unknown.
  def self.heard_done(message, peer = nil)
    forget_former_leader(peer)
    @page_asked = nil
    MGQ_Multiplayer::Bridge.call(PAGE_DONE_TOPIC, "page" => message["page"].to_s)
    log("the leader moved past page #{message['page']}")
  end

  # Reports whether the message window shows a page of the leader's story, which only the leader
  # moves on.
  #
  # @return [Boolean] Whether it does.
  def self.mirroring?
    @mirroring ? true : false
  end

  # Reports whether the page of the teller's story the window shows is over, as the DLL finds it:
  # the teller moved past it and the player had the time to read it, read on or skips, something
  # waits for the player to be free (giving_way?) or more pages wait behind it; the teller is no
  # longer the player's leader or gone; the relay ended their telling; or a Classic leader's state
  # stopped saying they tell the story a while ago. One the DLL does not answer for is over, so a
  # page never holds the player for good. The DLL is asked again only once what it reads changed,
  # see page_held?, since the window asks every frame.
  #
  # @return [Boolean] Whether it is over.
  def self.page_done?
    return true unless @mirroring

    lead = page_teller
    known = lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)
    asked = [known ? MGQ_MpOverworldSync.who(lead) : nil, known && MGQ_MpCoop::Scope.telling?(lead) ? true : false, MGQ_MpCoop::Scope.raid?,
             giving_way?, Input.trigger?(:C) ? true : false, Input.press?(SKIP_BUTTON) ? true : false]
    return false if page_held?(asked)

    @page_asked = nil
    answer = MGQ_Multiplayer::Bridge.call(PAGE_OVER_TOPIC, "teller" => asked[0], "telling" => asked[1], "raid" => asked[2],
                                                           "giving_way" => asked[3], "confirm" => asked[4], "skip" => asked[5])
    return true unless answer

    log("the page of the leader's story the window shows is over: #{answer['reason']}") if answer["reason"]
    return true if answer["over"]

    now = Graphics.frame_count
    @page_asked = { :asked => asked, :at => now, :until => answer["wait"] ? now + answer["wait"].to_i : nil }
    false
  end

  # Reports whether the DLL's last answer that the page the window holds is not over still stands:
  # it was asked with the same teller, telling, raid, wait and input, no page was heard, passed or
  # shown since, and the frames after which time alone may end the page have not passed. A loaded
  # save sets the frame count back, which asks anew.
  #
  # @param asked [Array] What page_done? hands the DLL now.
  # @return [Boolean] Whether it stands.
  def self.page_held?(asked)
    kept = @page_asked
    return false unless kept && kept[:asked] == asked

    now = Graphics.frame_count
    now >= kept[:at] && (kept[:until].nil? || now < kept[:until])
  end

  # Finds who told the pages the player follows: the party's leader, or in a Raid World the player
  # they came from, whose state says whether the story still plays.
  #
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The teller, :me for the player, nil for none.
  def self.page_teller
    return MGQ_MpCoop::Scope.teller unless MGQ_MpCoop::Scope.raid?

    MGQ_MpOverworldSync::Peers.all.find { |peer| peer.state["id"].to_s == @heard_from.to_s }
  end

  # Names the teller whose story pages the player follows, see forget_former_leader.
  #
  # @return [String, nil] Their id, nil for nobody or the player.
  def self.heard_from
    @heard_from
  end

  # Notes that the window finished the page of the leader's story.
  def self.page_ended
    @mirroring = false
    MGQ_Multiplayer::Bridge.call(PAGE_ENDED_TOPIC)
  end

  # Notes that an event starting cut short the page of the leader's story the window shows.
  def self.cut_page
    return unless @mirroring

    @mirroring = false
    page = MGQ_Multiplayer::Bridge.call(PAGE_ENDED_TOPIC)
    log("the page #{page} of the leader's story was cut short by an event starting")
  end

  # Notes whether the message window waits for the input that ends a page, which tells a pause at
  # a page's end from one before the rest of a page too long for the window.
  #
  # @param at_end [Boolean] Whether it does.
  def self.page_end_input(at_end)
    @page_end = at_end
  end

  # Holds a page of the leader's story in the message window for the leader: the player can
  # neither move it on nor close it, nor skip it with the game's skip key, until the leader moved
  # past it, see page_done?. A page too long for the window shows its rest after OVERFLOW_FRAMES. A page
  # that fails to hold waits for the player as the game's own pages do.
  #
  # It runs inside the message window's wait, where an error would end the game.
  #
  # @param window [Window_Message] The message window.
  # @param original [Proc] The game's own wait for the player to move the page on.
  def self.hold_page(window, original)
    page_end = @page_end
    window.pause = true
    frames = 0
    begin
      until page_done? || (!page_end && frames >= OVERFLOW_FRAMES)
        Fiber.yield
        frames += 1
      end
    rescue FiberError
      log_once(:page_fiber, "could not hold a page of the leader's story: the message window runs outside a fiber, so it moves on at once")
    rescue => e
      log_once(:hold_page, "holding a page of the leader's story failed, the player moves it on instead: #{e.class}: #{e.message}")
      original.call
    end
    window.pause = false
    page_ended if page_end
  end

  # Shows the next page of the leader's story the DLL hands out once the player is free; the DLL
  # leaves out the oldest pages the leader moved past while more than a few wait. While something
  # waits for the player to be free (see give_way_to), no page starts and those the leader moved
  # past are left out, so the player is free for it; the others show after.
  def self.show_heard
    return unless @waiting.to_i > 0 && MGQ_MpOverworldSync.map_free?

    waits = giving_way?
    answer = MGQ_Multiplayer::Bridge.call(PAGE_NEXT_TOPIC, "giving_way" => waits, "sharing" => MGQ_MpCoop::Scope.sharing? ? true : false)
    @waiting = answer ? answer["waiting"].to_i : 0
    return unless answer

    log("skipped pages #{answer['passed'].join(', ')} of the leader's story: #{waits} waits for the player, #{@waiting} still to show after") unless answer["passed"].empty?
    log("dropped #{answer['dropped']} waiting pages of the leader's story: no longer in a party") if answer["dropped"].to_i > 0
    log("skipped pages #{answer['skipped'].join(', ')} of the leader's story: the leader moved past them while the player was busy") unless answer["skipped"].empty?
    show_page(answer["show"]) if answer["show"]
  end

  # Shows a page of the leader's story in the message window, which holds it (see hold_page).
  #
  # @param page [Hash] The page: "page", "face", "index", "background", "position" and "lines".
  def self.show_page(page)
    @page_asked = nil
    log("showing page #{page['page']} of the leader's story, #{@waiting} more waiting")
    $game_message.face_name = MGQ_MpOverworld.graphic?(:face, page["face"].to_s) ? page["face"] : ""
    $game_message.face_index = page["index"]
    $game_message.background = page["background"]
    $game_message.position = page["position"]
    page["lines"].each { |line| $game_message.add(line) }
    @mirroring = true
  end

  # Registers something that waits for the player to be free on the map and lapses meanwhile, such
  # as the story's follow or a battle's invite, which the pages of the leader's story give way to: a
  # member kept busy reading them would miss it, and the story would go on without them.
  #
  # @yieldreturn [String, nil] What waits, for the log, nil while nothing does.
  def self.give_way_to(&wait)
    @waits.push(wait)
  end

  # Names what waits for the player to be free, see give_way_to.
  #
  # @return [String, nil] What waits, nil while nothing does.
  def self.giving_way?
    @waits.each do |wait|
      what = (wait.call rescue nil)
      return what if what
    end
    nil
  end

  # Forgets the pages of the story a former teller told and moved past, once the teller changed,
  # so they never show after the story they belong to: another member leads or the party is over,
  # or in a Raid World another player tells the story, or the player does.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who just told a page, nil for none.
  def self.forget_former_leader(peer = nil)
    id = page_source_id(peer)
    return if id == @heard_from

    waiting = MGQ_Multiplayer::Bridge.call(PAGE_FORGET_TOPIC).to_i
    @waiting = 0
    @page_asked = nil
    log("the teller whose story pages the player follows is #{id ? MGQ_MpOverworldSync.who(peer || MGQ_MpCoop::Scope.teller) : 'nobody'} now#{waiting > 0 ? ", forgot #{waiting} waiting pages of the former teller" : ''}")
    @heard_from = id
  end

  # Finds the id of the teller whose pages the player follows now: the party's leader; in a Raid
  # World the player who just told a page, else the teller on the map, or still the last one while
  # nobody tells, so the pages told before a telling ended still show.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who just told a page, nil for none.
  # @return [String, nil] The id, nil for nobody or the player.
  def self.page_source_id(peer)
    raid = MGQ_MpCoop::Scope.raid?
    return peer.state["id"].to_s if raid && peer

    lead = MGQ_MpCoop::Scope.teller
    return lead.state["id"].to_s if lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)

    raid && lead.nil? ? @heard_from : nil
  end

  # Tells the page kept while the player skips once it is due, shows the leader's messages once the
  # player is free. Called after the map's update.
  def self.update
    end_stale_telling
    flush_say
    forget_former_leader
    show_heard
    lift_dark_screen
  rescue => e
    log("updating the party's events failed: #{e.class}: #{e.message}")
  end

  # Ends the telling whose interpreter no longer runs an event without having ended it, as the game
  # put back after a PvP battle leaves it, so the DLL's telling machine gives the lock back.
  def self.end_stale_telling
    return unless @telling && !($game_map && $game_map.interpreter.running?)

    @telling = false
    @lock_hold = nil
    MGQ_Multiplayer::Bridge.call(TELLING_END_TOPIC)
  end

  # Gives what the block gives. The party hears of no gift, since the leader's runs bring what the
  # story gives by replay; trade.rbx and world_catchup.rbx still give through it.
  #
  # @yield The giving, such as a trade's.
  # @return [Object] What the block returns.
  def self.granting
    yield
  end

  # Ends the telling of the map's main event once it ended, which the DLL's telling machine hears
  # (the telling may still go on at the story's next event, see start_telling).
  #
  # @param interpreter [Game_Interpreter] The interpreter that ended.
  def self.finished(interpreter)
    if $game_map && interpreter.equal?($game_map.interpreter)
      @lock_hold = nil
      MGQ_Multiplayer::Bridge.call(TELLING_END_TOPIC) if @telling
      @telling = false
    end
  end

  # Takes a message about the party's events. Called by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    what = "#{message['pevent']}#{message['page'] ? " page #{message['page']}" : ''}"
    log("got #{what} from #{MGQ_MpOverworldSync.who(peer)} (#{MGQ_MpCoop.bytes_of(message)} bytes)")
    take_party(peer, message)
  end

  # Reports whether a PvP battle, such as a duel, runs.
  #
  # @return [Boolean] Whether one does.
  def self.pvp_running?
    defined?(MGQ_MpBattlesPvp) && MGQ_MpBattlesPvp::Battle.running? ? true : false
  end

  # Hands the party a run of the player's own game as its entry, which each member's game plays
  # again: one that changed a party key alone, such as a chest it opened, and as leader one that
  # changed a world key, which every member who follows the player's story takes (see take_entry);
  # never in a Raid World, whose parties share no chests and whose story is the world's. A member's
  # run of the leader's story goes to the leader with their requests, whose story keeps it when it
  # changed it (MGQ_MpCoopStory.keep_runs). Called by story_keys.rbx once the DLL logged the run.
  #
  # @param entry [Hash] The run's entry, see ReplayEntry.Write in the DLL.
  def self.hand_entry(entry)
    return unless shares_chests?
    return MGQ_MpCoopStory.request_run(entry) if entry["scope"] == "world" && MGQ_MpCoopStory.guest?
    return unless entry["scope"] == "party" || (entry["scope"] == "world" && MGQ_MpCoopStory.leading_synced?)

    text = MGQ_MpStoryReplay.wire(entry)
    return log("could not write entry #{entry['id']} of #{entry['site']} for the party") unless text

    sent = MGQ_MpCoop.tell(-1, "replay", text)
    log("#{sent ? 'handed' : 'could not hand'} the party entry #{entry['id']} of #{entry['site']} (#{text.bytesize} bytes)")
  rescue => e
    log("handing a run to the party failed: #{e.class}: #{e.message}")
  end

  # As leader, hands the party a member's run the player's story kept, named by the member who ran
  # it, and plays it in the player's own game too, see MGQ_MpCoopStory.keep_runs.
  #
  # @param entry [Hash] The run's entry, in the stream of the player's story.
  def self.hand_kept(entry)
    text = MGQ_MpStoryReplay.wire(entry)
    return log("could not write entry #{entry['id']} of #{entry['site']} for the party") unless text

    sent = MGQ_MpCoop.tell(-1, "replay", text, "opener" => entry["opener"])
    log("#{sent ? 'handed' : 'could not hand'} the party #{entry['opener']}'s entry #{entry['id']} of #{entry['site']} the player's story kept")
    MGQ_MpStoryReplay.receive(entry)
  end

  # Takes a run another member's game handed the party, which waits for the player to stand free
  # and then plays in their own game, see MGQ_MpStoryReplay.receive; never in a Raid World. A run of
  # the story is the leader's, which every member who follows the leader's story takes, behind,
  # level or ahead, in the stream of the leader's story, so a step of the player's own story counts
  # once there too; one the leader kept of a member's game names that member.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who ran it.
  # @param message [Hash] The message's fields.
  def self.take_entry(peer, message)
    return log("ignored a run from #{MGQ_MpOverworldSync.who(peer)}: a Raid World's parties share no chests") if MGQ_MpCoop::Scope.raid?
    return log("ignored a run from #{MGQ_MpOverworldSync.who(peer)}: not a member of the party") unless peer && MGQ_MpCoop::Party.member?(peer.state)

    entry = MGQ_MpStoryReplay.unwire(message["replay"].to_s)
    return log("ignored a run from #{MGQ_MpOverworldSync.who(peer)}: it does not read") unless entry.is_a?(Hash)

    if entry["scope"] == "world"
      lead = MGQ_MpCoop.party_leader
      unless MGQ_MpCoopStory.follows_leader? && lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && lead.state["id"].to_s == peer.state["id"].to_s
        return log("ignored a run of the story from #{MGQ_MpOverworldSync.who(peer)}: not the leader whose story the player follows")
      end

      entry["stream"] = "story:#{peer.state['id']}"
    end
    entry["opener"] = (message["opener"] || peer.state["name"]).to_s
    log("got entry #{entry['id']} of #{entry['site']} from #{MGQ_MpOverworldSync.who(peer)}")
    MGQ_MpStoryReplay.receive(entry)
  rescue => e
    log("taking a run failed: #{e.class}: #{e.message}")
  end
end

# What this script takes part in of the party's messages, through coop.rbx.

begin
  MGQ_MpCoop.route("replay") { |peer, message| MGQ_MpCoopEvents.take_entry(peer, message) }
  MGQ_MpCoop.route("pevent") { |peer, message| MGQ_MpCoopEvents.take(peer, message) }
  MGQ_MpCoop.route_map("pevent") { |peer, message| MGQ_MpCoopEvents.take(peer, message) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoopEvents.state_fields }
rescue => e
  MGQ_MpCoopEvents.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the leader's story pages show once the player is free.
  MGQ_MpHooks.after(Game_Map, :update, "coop_events") { MGQ_MpCoopEvents.update }

  # Before an event command runs, a talk that may turn into story is watched, and a new telling's
  # story event waits at its first command for the relay's telling lock. The watch goes first: a
  # talk that turns into story at this command starts a telling whose lock this command waits for.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "coop_events") do
    MGQ_MpCoopEvents.guard(self)
    begin
      Fiber.yield while MGQ_MpCoopEvents.lock_holding?(self)
    rescue FiberError
      # An interpreter run outside a fiber cannot wait, so its command runs at once.
    end
  end

  # Before the player's transfer, a telling that moves them is noted, so the story's next event on
  # the new map goes on with it, and after it the telling's lock moves to the new map.
  MGQ_MpHooks.before(Game_Player, :perform_transfer, "coop_events") { MGQ_MpCoopEvents.moving(self) }
  MGQ_MpHooks.after(Game_Player, :perform_transfer, "coop_events") { MGQ_MpCoopEvents.arrived }
rescue => e
  MGQ_MpCoopEvents.log("hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # After a list of commands is set up, a chest the map's main event opens is noticed. A common
  # event passes the list alone, which a block of two parameters would spread over both.
  MGQ_MpHooks.after(Game_Interpreter, :setup, "coop_events") { |*args| MGQ_MpCoopEvents.started(self, args[0], args[1] || 0) }

  # After the commands ran, the party hears of a chest they opened.
  MGQ_MpHooks.after(Game_Interpreter, :run, "coop_events") { MGQ_MpCoopEvents.finished(self) }

  # Around an interpreter's wait for a message, the party members hear the message the leader's
  # story shows, then that the leader moved past it. The Yanfly plugin, which loads after the Patch
  # folder, writes its own command_101, so the message is caught here, where every message waits
  # once its text is set.
  MGQ_MpHooks.before(Game_Interpreter, :wait_for_message, "coop_events") { MGQ_MpCoopEvents.show(self) }
  MGQ_MpHooks.after(Game_Interpreter, :wait_for_message, "coop_events") { MGQ_MpCoopEvents.shown(self) }

  # Before the map starts the event that is starting, every one that is story the leader's game
  # plays is left out.
  MGQ_MpHooks.before(Game_Map, :setup_starting_map_event, "coop_events") do
    @events.values.each do |event|
      next unless event.starting && MGQ_MpCoopEvents.hand_over(event)

      event.clear_starting_flag
      event.unlock
    end
  end

  # A common event that runs by itself starts, unless it is story the leader's game plays.
  MGQ_MpHooks.around(Game_Map, :setup_autorun_common_event, "coop_events") do |_map, _args, original|
    common = $data_common_events.find { |c| c && c.autorun? && $game_switches[c.switch_id] }
    common && MGQ_MpCoopEvents.leave_to_leader?(common) ? nil : original.call
  end
rescue => e
  MGQ_MpCoopEvents.log("interpreter hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # Around the message window's wait for the input that ends a page, its pause is the page's end.
  MGQ_MpHooks.before(Window_Message, :process_input, "coop_events") { MGQ_MpCoopEvents.page_end_input(true) }
  MGQ_MpHooks.after(Window_Message, :process_input, "coop_events") { MGQ_MpCoopEvents.page_end_input(false) }

  # The wait for the player to move the message on, but on a page of the leader's story for the
  # leader instead.
  MGQ_MpHooks.around(Window_Message, :input_pause, "coop_events") do |window, _args, original|
    MGQ_MpCoopEvents.mirroring? ? MGQ_MpCoopEvents.hold_page(window, original) : original.call
  end
rescue => e
  MGQ_MpCoopEvents.log("message hooks FAILED: #{e.class}: #{e.message}")
end
