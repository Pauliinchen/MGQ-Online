#----------------------------------------------------------------
#  coop_events.rbx
#
#  Changelog:
#      Paulinchen  2026-10-28: Held only the story events and talks that would move a player behind past the end of their part
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
# it runs, in the DLL (MGQOnline.Game's EventSorter, over the game's event data it reads itself):
# a talk (conversations, shops, the job change menu), travel (a transfer), a chest (items and its
# own self switch), a battle without dialogue, or story (everything that moves the story on).
# Chests are the player's own, and opening one opens it for the whole party: every member who has
# not looted it yet gets the same items, synced with the leader's story or not. Story is the
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

  # The class of each kind of item a chest gives, by the letter a message writes it with.
  ITEM_CLASSES = { "i" => RPG::Item, "w" => RPG::Weapon, "a" => RPG::Armor }

  # The sound a chest plays when the player opens it, which a member who gets its items hears too
  # when the chest's own is unknown.
  CHEST_SOUND = "Chest"

  # A sound's file name, which may hold dots, but is never a path.
  SOUND_NAME = /\A[\w\- ]+(\.[\w\- ]+)*\z/

  # Messages about gathering for story scenes, which coop_gather.rbx takes.
  GATHER_MESSAGES = %w(gather follow)

  # Common events that run only in the player's own game, never as the party's story: the game's map
  # display, its Pocket Castle call, its processing after every battle (which turns Luka Solo on)
  # and its transfer process, which runs by itself after a transfer.
  OWN_COMMON_EVENTS = [2, 3, 5, 114]

  # What a player whose story event waits for the world's story of a telling they watched reads.
  AWAIT_TOLD_TEXT = "Waiting a moment for the story %s told to arrive."

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
  # The chest the player opens: its interpreter, self switch, gains and sound.
  @chest = nil
  # Whether a gift runs that neither a chest nor the leader's story gives, see granting.
  @granting = false
  # Whether the message window waits for the input that ends a page, see page_end_input.
  @page_end = false

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
  # the game's data, or the commands themselves for any other list.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param event [Game_Event, nil] The event whose page the list may be, nil for none.
  # @return [Hash] The request.
  def self.request_for(list, event)
    page = event && $game_map ? event.mgq_mp_pages.index { |candidate| candidate.list.equal?(list) } : nil
    id = page ? nil : common_id(list)
    request = if page
                { "map" => $game_map.map_id, "event" => event.id, "page" => page, "size" => list.size }
              elsif id
                { "common" => id, "size" => list.size }
              else
                inline_request(list, event)
              end
    request["resident"] = true if defined?(MGQ_MpCoopCastle) && MGQ_MpCoopCastle.resident?(list)
    request
  end

  # Hands a list to the DLL whole, for a list the game's data does not hold as the game shows it:
  # each command's parameters as plain values, anything else as nil.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param event [Game_Event, nil] The event whose current page the list may be, whose trigger counts then.
  # @return [Hash] The request.
  def self.inline_request(list, event)
    rows = list.map { |command| [command.code, command.indent, plain(command.parameters)] }
    { "list" => rows, "trigger" => event && list.equal?(event.list) ? event.trigger : nil }
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
  # @param topic [String] SORT_TOPIC or KINDS_TOPIC.
  # @param request [Hash] The request, which takes the values.
  # @param needs [Hash] The values the DLL named for this list, by kind, kept and grown here.
  # @return [Hash, nil] The answer, nil when the DLL did not give one.
  def self.ask(topic, request, needs)
    MAX_SORT_ROUNDS.times do
      request["values"] = values_of(needs)
      answer = MGQ_Multiplayer::Bridge.call(topic, request)
      return nil unless answer.is_a?(Hash)
      return answer unless answer["needs"]
      return nil unless add_needs(needs, answer["needs"])
    end
    nil
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

  # Lists the self switches of the chests on the map.
  #
  # @return [Array<Array>] Their keys: map, event and letter.
  def self.chest_keys
    return @chest_keys if @chest_keys_map == $game_map.map_id

    @chest_keys_map = $game_map.map_id
    events = $game_map.events.values
    kinds = page_kinds(events)
    @chest_keys = events.map { |event| chest_key_of_pages(event, kinds) }.compact
  end

  # Finds the self switch an event sets as a chest, on whichever of its pages gives the chest's
  # items, since a chest the player opened shows another page.
  #
  # @param event [Game_Event] The event.
  # @param kinds [Hash] The kinds of the map's pages the DLL sorted at once, see page_kinds.
  # @return [Array, nil] Its key, nil when no page is a chest's.
  def self.chest_key_of_pages(event, kinds = {})
    pages = event.mgq_mp_pages
    index = (0...pages.size).find { |place| (kinds[[event.id, place]] || kind_of(pages[place].list || [])) == :chest }
    index ? chest_key(event, pages[index].list) : nil
  end

  # Sorts every page of the map's events in one call to the DLL, by the game's data; a page the
  # data does not hold as the game shows it is left to kind_of.
  #
  # @param events [Array<Game_Event>] The map's events.
  # @return [Hash] Each page's kind by [event, page].
  def self.page_kinds(events)
    pages = []
    residents = []
    events.each do |event|
      event.mgq_mp_pages.each_with_index do |page, place|
        list = page.list || []
        pages << [event.id, place, list.size]
        residents << [event.id, place] if defined?(MGQ_MpCoopCastle) && MGQ_MpCoopCastle.resident?(list)
      end
    end
    request = { "map" => $game_map.map_id, "pages" => pages }
    request["residents"] = residents unless residents.empty?
    answer = ask(KINDS_TOPIC, request, @needs[[:map, $game_map.map_id]] ||= {})
    kinds = {}
    Array(answer && answer["kinds"]).each_with_index { |kind, place| kinds[pages[place][0, 2]] = kind.to_s.to_sym if kind }
    kinds
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

  # Notices the map's main event starting: keeps track of a chest's items, and as leader brings the
  # party together for a story scene.
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
    @chest = event && sorted == :chest && shares_chests? ? { :interpreter => interpreter, :key => chest_key(event), :gains => [] } : nil
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
    notes << "a chest, #{@chest[:key] ? "self switch #{@chest[:key].join('.')}" : 'without a self switch'}" if @chest
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
  # @return [Hash] "telling": 1 while the player's story scene plays for the party; in a Raid World
  #   "twb" too while it plays, whether warping is banned where the player stands, see
  #   MGQ_MpCoopGather.warp_ban?.
  def self.state_fields
    playing = story_playing?
    fields = { "telling" => playing ? 1 : 0 }
    fields["twb"] = MGQ_MpCoopGather.warp_ban? ? 1 : 0 if playing && MGQ_MpCoop::Scope.raid? && defined?(MGQ_MpCoopGather)
    fields
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
  # switches the pages of the chain check (needs, as for sorting), and the answer is kept per list
  # and part while those stay as they were, since an event that runs by itself starts again every
  # frame.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param event [Game_Event, nil] The event whose page the list may be, nil for none.
  # @return [String, nil] Why it would leave the part, nil when it stays in it; an event the DLL
  #   cannot tell of leaves it.
  def self.leaving_part(list, event = nil)
    request = request_for(list, event)
    table = defined?(MGQ_MpStoryKeys) ? MGQ_MpStoryKeys.raid_table : nil
    key = [site_key(request, list), list.size, defined?(MGQ_MpWorldStory) ? MGQ_MpWorldStory.part : nil, table ? table.rev : nil]
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
  # page never holds the player for good.
  #
  # @return [Boolean] Whether it is over.
  def self.page_done?
    return true unless @mirroring

    lead = page_teller
    known = lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)
    answer = MGQ_Multiplayer::Bridge.call(PAGE_OVER_TOPIC, "teller" => known ? MGQ_MpOverworldSync.who(lead) : nil,
                                                           "telling" => known && MGQ_MpCoop::Scope.telling?(lead) ? true : false, "raid" => MGQ_MpCoop::Scope.raid?,
                                                           "giving_way" => giving_way?, "confirm" => Input.trigger?(:C) ? true : false,
                                                           "skip" => Input.press?(SKIP_BUTTON) ? true : false)
    return true unless answer

    log("the page of the leader's story the window shows is over: #{answer['reason']}") if answer["reason"]
    answer["over"] ? true : false
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
  # player is free, and chests other members opened. Called after the map's update.
  def self.update
    end_stale_telling
    flush_say
    forget_former_leader
    show_heard
    take_held_chests
    tell_chest_news
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

  # Gives what the block gives without counting it as what a chest the player opens gives, nor as
  # what the leader's story gives the party.
  #
  # @yield The giving, such as a chest's items or a trade's.
  # @return [Object] What the block returns.
  def self.granting
    granting = @granting
    @granting = true
    yield
  ensure
    @granting = granting
  end

  # Notes that an item is being given, and whether it is the outermost of nested gifts.
  #
  # @return [Boolean] Whether it is the outermost.
  def self.enter_gain
    @gain_depth = @gain_depth.to_i + 1
    @gain_depth == 1
  end

  # Notes that giving an item ended.
  def self.leave_gain
    @gain_depth = @gain_depth.to_i - 1
  end

  # Keeps an item a chest gives, and tells the party about one the leader's story gives or takes,
  # through coop_story.rbx.
  #
  # An enchanted copy is left out of the story's, since it exists only in the game that made it.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @param amount [Integer] How many, below zero for a loss.
  # @param stored [Boolean] Whether it only moves between the bag and the item storage.
  def self.gained_item(item, amount, stored = false)
    kind = ITEM_CLASSES.keys.find { |letter| item.is_a?(ITEM_CLASSES[letter]) }
    return unless kind

    gained(kind, item.id, amount)
    story_gave(kind, item.id, amount) unless stored || (item.respond_to?(:uniq_item?) && item.uniq_item?)
  rescue => e
    log("keeping an item failed: #{e.class}: #{e.message}")
  end

  # Keeps gold a chest gives, and tells the party about gold the leader's story gives or takes.
  #
  # @param amount [Integer] How much, below zero for a loss.
  def self.gained_gold(amount)
    gained("g", 0, amount)
    story_gave("g", 0, amount)
  end

  # Tells the party about items or gold the leader's story gave or took, through coop_story.rbx;
  # never what a member's chest gives the player.
  #
  # @param kind [String] "i", "w", "a", or "g" for gold.
  # @param id [Integer] The item, 0 for gold.
  # @param amount [Integer] How many.
  def self.story_gave(kind, id, amount)
    MGQ_MpCoopStory.gave(kind, id, amount) if defined?(MGQ_MpCoopStory) && !@granting
  end

  # Notes the first sound the chest the player opens plays, which the members who get its items
  # hear too. Called after a sound effect plays.
  #
  # @param sound [RPG::SE] The sound.
  def self.played_sound(sound)
    @chest[:sound] ||= [sound.name.to_s, sound.volume.to_i, sound.pitch.to_i] if @chest && !@granting
  end

  # Keeps an item or gold a chest gives.
  #
  # @param kind [String] "i", "w", "a", or "g" for gold.
  # @param id [Integer] The item, 0 for gold.
  # @param amount [Integer] How many.
  def self.gained(kind, id, amount)
    @chest[:gains] << [kind, id, amount] if @chest && !@granting && amount > 0
  end

  # Ends the telling of the map's main event once it ended, which the DLL's telling machine hears
  # (the telling may still go on at the story's next event, see start_telling), and tells the party
  # about a chest the player opened; a chest left shut, such as a locked one, tells nothing.
  #
  # A loaded save, or the game put back after a PvP battle, runs the map's last event's list once
  # more from its end, which would tell the party whatever message waits, such as the battle's result.
  #
  # @param interpreter [Game_Interpreter] The interpreter that ended.
  def self.finished(interpreter)
    if $game_map && interpreter.equal?($game_map.interpreter)
      @lock_hold = nil
      MGQ_Multiplayer::Bridge.call(TELLING_END_TOPIC) if @telling
      @telling = false
    end
    return unless @chest && @chest[:interpreter].equal?(interpreter)

    chest = @chest
    @chest = nil
    unless chest[:key] && $game_self_switches[chest[:key]] && shares_chests?
      reason = !chest[:key] ? "it sets no self switch" : (shares_chests? ? "it stayed shut, such as a locked one" : "no longer in a party of a Classic world")
      return log("the chest #{chest[:key] ? chest[:key].join('.') : ''} tells the party nothing: #{reason}")
    end

    MGQ_MpCoopStory.keep_own_self_switch(chest[:key], true) if defined?(MGQ_MpCoopStory)
    gains = chest[:gains].map { |kind, id, amount| "#{kind}#{id}x#{amount}" }.join(",")
    sound = chest[:sound] || [CHEST_SOUND, 80, 100]
    sent = MGQ_MpCoop.tell(-1, "chest", chest[:key].join("."), "gains" => gains, "se" => sound.join(","))
    log("#{sent ? 'told' : 'could not tell'} the party about chest #{chest[:key].join('.')}: gave #{gains.empty? ? 'nothing' : gains}, sound #{sound.join(',')}")
  rescue => e
    log("telling a chest failed: #{e.class}: #{e.message}")
  end

  # Takes a message about chests or the party's events. Called by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    what = message["chest"] ? "chest #{message['chest']} (gains #{message['gains']})" : "#{message['pevent']}#{message['page'] ? " page #{message['page']}" : ''}"
    log("got #{what} from #{MGQ_MpOverworldSync.who(peer)} (#{MGQ_MpCoop.bytes_of(message)} bytes)")
    message["chest"] ? take_chest(peer, message) : take_party(peer, message)
  end

  # Takes a chest another member opened: gives its items, unless the player looted it already or it
  # gave nothing; never in a Raid World, whose chests are personal.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who opened it.
  # @param message [Hash] The message's fields.
  def self.take_chest(peer, message)
    return log("ignored chest #{message['chest']} from #{MGQ_MpOverworldSync.who(peer)}: a Raid World's chests are personal") if MGQ_MpCoop::Scope.raid?
    return log("ignored chest #{message['chest']} from #{MGQ_MpOverworldSync.who(peer)}: not a member of the party") unless MGQ_MpCoop::Party.member?(peer.state)
    # A PvP battle puts the game back as it was before it, which would take the items again.
    if pvp_running?
      (@held_chests ||= []) << [peer, message]
      return log("holding chest #{message['chest']} from #{MGQ_MpOverworldSync.who(peer)} until the PvP battle put the game back (#{@held_chests.size} waiting)")
    end

    map_id, event_id, letter = message["chest"].to_s.split(".")
    key = [map_id.to_i, event_id.to_i, letter]
    return log("ignored chest #{message['chest']} from #{MGQ_MpOverworldSync.who(peer)}: the player looted it already") if own_self_switch(key)
    return log("ignored chest #{message['chest']} from #{MGQ_MpOverworldSync.who(peer)}: it gave nothing") if message["gains"].to_s.empty?

    names = grant(message["gains"].to_s)
    log("took chest #{key.join('.')} #{MGQ_MpOverworldSync.who(peer)} opened for the party: #{names.empty? ? 'nothing known' : names.join(', ')}")
    MGQ_MpCoopStory.keep_own_self_switch(key, true) if defined?(MGQ_MpCoopStory)
    text = names.empty? ? "#{peer.state['name']} opened a chest for the party." : "#{peer.state['name']} opened a chest for the party: #{names.join(', ')}."
    (@chest_news ||= []) << [text, first_icon(message["gains"].to_s), message["se"].to_s]
    tell_chest_news
  rescue => e
    log("taking a chest failed: #{e.class}: #{e.message}")
  end

  # Opens the chests other members opened during a PvP battle, once it put the game back.
  def self.take_held_chests
    return if @held_chests.nil? || @held_chests.empty? || pvp_running?

    held = @held_chests
    @held_chests = nil
    log("the PvP battle is over, taking the #{held.size} chests other members opened meanwhile")
    held.each { |peer, message| take_chest(peer, message) }
  end

  # Reports whether a PvP battle, such as a duel, runs.
  #
  # @return [Boolean] Whether one does.
  def self.pvp_running?
    defined?(MGQ_MpBattlesPvp) && MGQ_MpBattlesPvp::Battle.running? ? true : false
  end

  # Tells the player about chests other members opened, with the chest's sound and the first item's
  # icon, once the player is on the map; a battle keeps it until it ends.
  def self.tell_chest_news
    return if @chest_news.nil? || @chest_news.empty? || !SceneManager.scene.is_a?(Scene_Map)

    @chest_news.each_with_index do |(text, icon, sound), index|
      play_sound(sound) if index == 0
      MGQ_MpOverworldSync.notice(text, icon)
    end
    @chest_news.clear
  end

  # Plays a chest's sound as another member's game wrote it.
  #
  # @param text [String] The sound: file name, volume and pitch, comma separated.
  def self.play_sound(text)
    name, volume, pitch = text.split(",")
    name = CHEST_SOUND unless name.to_s =~ SOUND_NAME
    RPG::SE.new(name, [[volume.to_i, 0].max, 100].min.nonzero? || 80, [[pitch.to_i, 50].max, 150].min).play
  rescue => e
    log_once(:chest_sound, "playing a chest's sound failed: #{e.class}: #{e.message}")
  end

  # Finds the icon of the first item a chest gave.
  #
  # @param gains [String] The items as written: kind, id, "x", amount, comma separated.
  # @return [Integer, nil] The icon, nil for gold alone or nothing known.
  def self.first_icon(gains)
    gains.split(",").each do |entry|
      next unless entry =~ /\A([iwa])(\d+)x\d+\z/

      item = MGQ_MpGame.item(Regexp.last_match(1), Regexp.last_match(2).to_i)
      return item.icon_index if item && item.respond_to?(:icon_index)
    end
    nil
  end

  # Reads a self switch as it is the player's own, whether or not they play the leader's story.
  #
  # @param key [Array] The self switch.
  # @return [Boolean] Its value.
  def self.own_self_switch(key)
    defined?(MGQ_MpCoopStory) ? MGQ_MpCoopStory.own_self_switch(key) : $game_self_switches[key]
  end

  # Gives the items of a chest.
  #
  # @param gains [String] The items as written: kind, id, "x", amount, comma separated.
  # @return [Array<String>] What was given, as shown.
  def self.grant(gains)
    granting do
      gains.split(",").map do |entry|
        unless entry =~ /\A([iwag])(\d+)x(\d+)\z/
          log("skipped #{entry.inspect} of a chest: unreadable")
          next
        end

        kind, id, amount = Regexp.last_match(1), Regexp.last_match(2).to_i, Regexp.last_match(3).to_i
        if kind == "g"
          $game_party.gain_gold(amount)
          "#{amount} #{Vocab.currency_unit}"
        else
          item = MGQ_MpGame.item(kind, id)
          unless item
            log("skipped #{entry} of a chest: not in the game")
            next
          end

          $game_party.gain_item(item, amount)
          amount > 1 ? "#{item.name} x#{amount}" : item.name
        end
      end.compact
    end
  end
end

# What this script takes part in of the party's messages, through coop.rbx.

begin
  MGQ_MpCoop.route("chest") { |peer, message| MGQ_MpCoopEvents.take(peer, message) }
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

begin
  # After a sound effect plays, a chest the player opens notes it for the party.
  MGQ_MpHooks.after(RPG::SE, :play, "coop_events") { MGQ_MpCoopEvents.played_sound(self) }
rescue => e
  MGQ_MpCoopEvents.log("sound hook FAILED: #{e.class}: #{e.message}")
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

begin
  # Around giving an item, which is kept for the party when a chest or the leader's story gives it.
  # The game gives an enchanted item by calling this again for each copy it makes, so only the
  # outermost call counts; the fourth argument is the game's keep_flag, set when the item only moves
  # to or from the item storage.
  MGQ_MpHooks.around(Game_Party, :gain_item, "coop_events") do |_party, args, original|
    outermost = MGQ_MpCoopEvents.enter_gain
    begin
      result = original.call
    ensure
      MGQ_MpCoopEvents.leave_gain
    end
    MGQ_MpCoopEvents.gained_item(args[0], args[1], args[3] ? true : false) if outermost
    result
  end

  # After gold is given, it is kept for the party when a chest or the leader's story gives it.
  MGQ_MpHooks.after(Game_Party, :gain_gold, "coop_events") { |amount| MGQ_MpCoopEvents.gained_gold(amount) }
rescue => e
  MGQ_MpCoopEvents.log("party hooks FAILED: #{e.class}: #{e.message}")
end
