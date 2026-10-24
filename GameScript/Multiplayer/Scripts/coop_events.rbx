#----------------------------------------------------------------
#  coop_events.rbx
#
#  Changelog:
#      Paulinchen  2026-10-24: Played every battlefuck in the player's own game alone
#                            - Named the game's own common event that starts in the log
#                            - Noted the teller whose story event that runs by itself the player's game keeps from starting
#                            - Let that event start once nothing came for thirty seconds of a telling outside battle
#      Paulinchen  2026-10-23: Took back what a talk or story event changed once it ends early
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
# it runs:
# a talk (conversations, shops, the job change menu), travel (a transfer), a chest (items and its
# own self switch), a battle without dialogue, or story (everything that moves the story on).
# Chests are the player's own, and opening one opens it for the whole party: every member who has
# not looted it yet gets the same items, synced with the leader's story or not. Story is the
# leader's alone for the members who follow it (see MGQ_MpCoopStory.follows_leader?); a member who
# does not plays their own. A story scene the leader starts first gathers the members who follow it,
# see coop_gather.rbx; the Pocket Castle's residents are sorted by coop_castle.rbx. In a Raid World
# the story is told by whoever tells it on the map, to everyone there whose story matches, see
# MGQ_MpCoop::Scope.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopEvents
  # Event commands that move the story on wherever they appear: party changes (129), vehicles (206),
  # name input (303), game over and title (353, 354).
  STORY_CODES = [129, 206, 303, 353, 354]

  # Scripts a talk may run, such as companions' lines, choices, presents, menus, shops that list
  # their goods in a script, and cosmetic scripts like move routes, waits and zooms.
  TALK_SCRIPTS = /\A\s*(actor_label_jump|unlimited_choices|ex_choice_\w+|present_start|change_friend|gain_medal|gain_coin|play_base_bgm|clear_skill_name|display_skill_name|call_synthesize|call_slot_scene|start_poker|call_party_edit|SceneManager\.call\(Scene_JobChange\)|names = party_members|@?goods\b|\w+ = RPG::MoveRoute\.new|wait\(|set_(angle|zoom|zoom_anime|swing_anime|circle_anime|cycle)\(|map_zoom|input_keys|check_picture_exist)/

  # A script that shows a choice and writes the answer into a variable, which the page then
  # branches on. The variable's id is its first argument.
  CHOICE_SCRIPT = /\A\s*unlimited_choices\(\s*(\d+)/

  # Event commands that start a choice's branch: one choice (402) and the choice of cancelling (403).
  CHOICE_BRANCHES = [402, 403]

  # Scripts that travel.
  TRAVEL_SCRIPTS = /\A\s*(forced_transfer|forced_get_off_vehicle|forced_get_on_airship)/

  # Kinds of page that may turn into story behind one of their choices, which guard watches: a
  # talk, and travel whose transfer lies behind the choice with the story, as the Great Decision's.
  WATCHED_KINDS = [:talk, :travel]

  # Names of switches and variables the game uses as scratch while an event runs.
  TEMPORARY_NAMES = /general|temp|system only|汎用|一時/i

  # Event commands that show dialogue: text, choices, scrolling text.
  MESSAGE_CODES = [101, 102, 105]

  # Messages of the leader's story kept at most while the player is busy.
  MAX_HEARD = 30

  # Pages of the leader's story a member's game remembers the leader moved past, at most.
  MAX_DONE = 64

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

  # Frames after a Raid World's telling starts in which another player who started telling on the
  # same map at the same moment, and entered it first, stops it, three seconds of the state's lag.
  TIE_FRAMES = 180

  # Frames a Raid World's story event waits at its start while someone on the map entered it before
  # the player, one second, so their state can tell that they started telling at the same moment
  # before the event changed anything.
  TIE_HOLD_FRAMES = 60

  # Frames after the player's telling moved them onto another map in which the story's next event
  # there, one that runs by itself, goes on with that telling, five seconds: the game's transfer
  # process runs between them in the player's own game, and the next event may wait for the screen
  # to fade in.
  CONTINUE_FRAMES = 300

  # Frames a page of the leader's story stays after the leader stopped telling the story, two
  # seconds, before a member's game ends it anyway.
  STALE_FRAMES = 120

  # Pages of the leader's story a member's game may fall behind by: past them, the oldest pages the
  # leader moved past are left out, so the member never lags far behind the scene.
  CATCH_UP_PAGES = 3

  # Frames a page of the leader's story stays at least once the leader moved past it, before its
  # characters count; confirm moves on sooner.
  READ_FRAMES = 60

  # Frames a page of the leader's story stays longer per character, see READ_FRAMES.
  READ_FRAMES_PER_CHARACTER = 2

  # Frames a page of the leader's story stays at most once the leader moved past it.
  MOST_READ_FRAMES = 180

  # The game's message skip, held: its message window passes every page while it is down (the
  # keyboard's A key).
  SKIP_BUTTON = :X

  # Frames between two pages of the player's story told while they hold the game's skip, which
  # passes a page every frame: the pages between are left out, so the sends stay far below the
  # relay's limit per connection. coop_scene.rbx sends the scene's changes as seldom meanwhile.
  SKIP_SEND_FRAMES = 10

  # Frames a member's game shows the part of a long page that fits the window before it shows the
  # rest, two and a half seconds, as the leader's game shows the whole page at once.
  OVERFLOW_FRAMES = 150

  # How deep called common events are followed.
  MAX_DEPTH = 5

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

  # What each common event does, by its id and depth, sorted in the frame of @common_frame.
  @common_kinds = {}
  # The checks of what waits for the player to be free, see give_way_to.
  @waits = []
  # The chest the player opens: its interpreter, self switch, gains and sound.
  @chest = nil
  # Whether a gift runs that neither a chest nor the leader's story gives, see granting.
  @granting = false
  # Whether the message window waits for the input that ends a page, see page_end_input.
  @page_end = false

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op events"

  # Sorts an event's current page, by what of it can run now.
  #
  # @param event [Game_Event] The event.
  # @return [Symbol] :talk, :travel, :chest, :battle, :story or :own, see kind_of; :talk for an
  #   event without a page.
  def self.kind(event)
    return :talk if event.mgq_mp_page < 0
    return :travel if exit?(event)

    sorted = kind_of(event.list || [])
    # A scene that runs by itself and hides its story behind a choice, as Alice's recap at the
    # Strategy Conference, plays in the leader's game alone: a member's copy, ended at the story
    # as a talk's would be, would start over and over.
    sorted == :talk && event.trigger == 3 && may_tell?(event.list || []) ? :story : sorted
  end

  # Reports whether an event's page only takes the player elsewhere when they step on it or press a
  # button: a transfer without dialogue, battle, items, self switch or script, which may note a
  # switch or variable on the way, such as the warp and library flags of a town's entrance.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it does.
  def self.exit?(event)
    return false if event.trigger > 2

    marks = marks_of(runnable(event.list || []), 0)
    marks[:travel] && [:story, :says, :battle, :gives, :own_switch].none? { |mark| marks[mark] } ? true : false
  end

  # Lists the commands of a list that can run now: a branch on a switch or a variable runs only
  # when its condition holds, its else only when it does not; branches on anything else may run. A
  # jump that can run makes the commands after its label run too, up to the end of the label's
  # block, also inside a branch that does not hold.
  #
  # Exits hold the story's warnings in such branches, as Iliasville's do, which would make every
  # exit story long after the warnings passed.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Array<RPG::EventCommand>] Those that can run.
  def self.runnable(list)
    variables = choice_variables(list)
    kept = {}.compare_by_identity
    starts = [0]
    jumped = {}
    until starts.empty?
      start = starts.shift
      runnable_from(list, start, variables).each do |command|
        kept[command] = true
        next unless command.code == 119 && !jumped[command.parameters[0]]

        name = jumped[command.parameters[0]] = command.parameters[0]
        label = list.index { |other| other.code == 118 && other.parameters[0] == name }
        starts << label if label
      end
    end
    list.select { |command| kept[command] }
  end

  # Lists the commands that can run from a place in a list, see runnable: to its end from the
  # list's start, else to the end of the block the place stands in.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param start [Integer] The place.
  # @param variables [Array<Integer>] The choice scripts' variables, see choice_variables.
  # @return [Array<RPG::EventCommand>] Those that can run.
  def self.runnable_from(list, start, variables)
    held = {}
    skip = nil
    floor = start > 0 ? list[start].indent : nil
    list[start..-1].take_while { |command| floor.nil? || command.indent >= floor }.select do |command|
      indent = command.indent
      next false if skip && indent > skip

      case command.code
      when 111
        # A branch on a choice's variable may run either way, since the choice is not made yet.
        params = command.parameters
        held[indent] = params[0] == 1 && variables.include?(params[1]) ? nil : holds?(params)
        skip = indent if held[indent] == false
      when 411 then skip = held[indent] == true ? indent : nil
      when 412 then skip = nil
      end
      true
    end
  end

  # Lists the variables the choice scripts of a list write their answers into, see CHOICE_SCRIPT.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Array<Integer>] The variables.
  def self.choice_variables(list)
    list.each_with_object([]) do |command, ids|
      ids.push(Regexp.last_match(1).to_i) if command.code == 355 && command.parameters[0].to_s =~ CHOICE_SCRIPT
    end
  end

  # Reports whether a command starts a branch on a choice script's variable, which counts as a
  # choice's branch: the branch itself (111) and its else (411), until the branch ends (412).
  #
  # @param command [RPG::EventCommand] The command.
  # @param variables [Array<Integer>] The choice scripts' variables, see choice_variables.
  # @param open [Hash] The indents of such branches open now, kept between calls.
  # @return [Boolean] Whether it does.
  def self.choice_branch?(command, variables, open)
    params = command.parameters
    case command.code
    when 111 then open[command.indent] = params[0] == 1 && variables.include?(params[1])
    when 411 then open[command.indent] ? true : false
    when 412
      open.delete(command.indent)
      false
    else false
    end
  end

  # Reports whether a branch's condition on a switch or a variable holds now.
  #
  # @param params [Array] The branch's parameters.
  # @return [Boolean, nil] Whether it holds, nil for a condition on anything else.
  def self.holds?(params)
    return nil unless $game_switches && $game_variables

    case params[0]
    when 0 then $game_switches[params[1]] == (params[2] == 0)
    when 1
      value = $game_variables[params[1]].to_i
      other = params[2] == 0 ? params[3].to_i : $game_variables[params[3]].to_i
      [value == other, value >= other, value <= other, value > other, value < other, value != other][params[4]]
    end
  rescue => e
    log("reading a branch failed: #{e.class}: #{e.message}")
    nil
  end

  # Sorts a list of event commands by what of it can run now.
  #
  # Story only behind a choice, such as a trader's "Talk" that moves a side quest on, leaves a page a
  # talk, or travel when a transfer lies behind the choice too, which may turn into story once that
  # choice is taken (see may_tell? and guard).
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Symbol] :talk, :travel, :chest, :battle or :story; :own for a battlefuck (battlefuck?).
  def self.kind_of(list)
    can_run = runnable(list)
    return :own if battlefuck?(can_run)
    return :talk if defined?(MGQ_MpCoopCastle) && MGQ_MpCoopCastle.resident?(list)

    list = can_run
    # Wandering monsters call the game's common events before and after their battle, which set
    # variables, so a battle is told apart by the page itself: a fight without its own dialogue.
    return :battle if list.any? { |c| c.code == 301 } && list.none? { |c| MESSAGE_CODES.include?(c.code) }

    marks = marks_of(list, 0)
    return :story if story_marks?(marks)
    return :chest if marks[:gives] && marks[:own_switch] && !marks[:choice_story]
    return :talk if one_time_talk?(marks)
    return :story if marks[:own_switch] || marks[:battle]

    marks[:travel] ? :travel : :talk
  end

  # Reports whether a list may start a battlefuck: it calls one of the battlefuck events
  # (MGQ_MpCoopStoryRewards::BATTLEFUCK_EVENTS), which plays in the player's own game alone, with
  # nobody taken along. Only what can run now counts, since a town's quest page may hold its
  # battlefuck in one step's branch and story in the others.
  #
  # @param list [Array<RPG::EventCommand>] The commands that can run now, see runnable.
  # @return [Boolean] Whether it does.
  def self.battlefuck?(list)
    return false unless defined?(MGQ_MpCoopStoryRewards::BATTLEFUCK_EVENTS)

    @battlefuck_events ||= MGQ_MpCoopStoryRewards::BATTLEFUCK_EVENTS.each_with_object({}) { |id, found| found[id] = true }
    list.any? { |command| command.code == 117 && @battlefuck_events[command.parameters[0]] }
  end

  # Reports whether marks are a one-time talk's: dialogue and the page's own self switch, nothing
  # else, as a signpost or a villager who says something once. Each player reads it in their own
  # game; the self switch follows the leader's story like any other and only decides whether the
  # first words show.
  #
  # @param marks [Hash] The marks, see marks_of.
  # @return [Boolean] Whether they are.
  def self.one_time_talk?(marks)
    marks[:own_switch] && marks[:says] && marks.none? { |key, value| value && ![:own_switch, :says].include?(key) } ? true : false
  end

  # Reports whether marks say story, past a choice or not.
  #
  # @param marks [Hash] What a list does, see marks_of.
  # @return [Boolean] Whether they do.
  def self.story_marks?(marks)
    marks[:story] || marks[:sets] ? true : false
  end

  # Reports whether a talk turns into story behind one of its choices.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Boolean] Whether it does.
  def self.may_tell?(list)
    marks_of(runnable(list), 0)[:choice_story] ? true : false
  end

  # Finds what a list of event commands does. What a choice's branch does that would make it story
  # counts as :choice_story instead, since the player may never take that choice.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param depth [Integer] How many common events deep the list is.
  # @return [Hash] :story, :sets (a switch or variable of the story), :says (dialogue), :gives,
  #   :own_switch, :battle, :travel and :choice_story, each true when found.
  def self.marks_of(list, depth)
    marks = {}
    choice = {}
    branches = []
    open = {}
    variables = choice_variables(list)
    list.each_with_index do |command, index|
      branches.pop while !branches.empty? && command.indent <= branches.last
      next branches.push(command.indent) if CHOICE_BRANCHES.include?(command.code) || choice_branch?(command, variables, open)

      mark_command(branches.empty? ? marks : choice, list, index, depth)
    end
    # A chest asks first whether to open it, so its own switch with items behind a choice keeps it a
    # chest, unless story lies behind the choice too, as behind Amira's paid tip in Iliasburg, whose
    # story value a chest kept from the world's story.
    chest = choice[:gives] && choice[:own_switch] && !story_marks?(choice) && !choice[:battle] && !choice[:choice_story]
    marks[:choice_story] = true if story_marks?(choice) || choice[:battle] || choice[:choice_story] || (choice[:own_switch] && !chest)
    [:says, :gives, :travel].each { |key| marks[key] ||= choice[key] if choice[key] }
    marks[:own_switch] ||= true if chest
    marks
  end

  # Marks what one event command does.
  #
  # @param marks [Hash] What the list does so far.
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The command's place.
  # @param depth [Integer] How many common events deep the list is.
  def self.mark_command(marks, list, index, depth)
    command = list[index]
    params = command.parameters
    case command.code
    when 121 then marks[:sets] ||= !(params[0]..params[1]).all? { |id| temporary_switch?(id) }
    when 122 then marks[:sets] ||= !(params[0]..params[1]).all? { |id| temporary_variable?(id) }
    when 123 then marks[:own_switch] = true
    when 125, 126, 127, 128 then marks[:gives] = true
    when 201 then marks[:travel] = true
    when 301 then marks[:battle] = true
    when *MESSAGE_CODES then marks[:says] = true
    when 355 then mark_script(marks, script_at(list, index))
    when 117 then merge(marks, common_marks(params[0], depth + 1))
    else marks[:story] = true if STORY_CODES.include?(command.code)
    end
  end

  # Adds what a common event does, of what can run now, sorted once per common event and depth in
  # a frame, since the game's state decides what can run.
  #
  # The depth is part of the key, since a common event sorted deep down counts the events it calls
  # past MAX_DEPTH as story, which a call from higher up must not take over.
  #
  # @param id [Integer] The common event.
  # @param depth [Integer] How deep it is called.
  # @return [Hash] What it does, see marks_of; nothing for one of OWN_COMMON_EVENTS, which runs in
  #   the player's own game whoever calls it; a common event too deep counts as story.
  def self.common_marks(id, depth)
    return {} if OWN_COMMON_EVENTS.include?(id)
    return { :story => true } if depth > MAX_DEPTH

    unless @common_frame == Graphics.frame_count
      @common_frame = Graphics.frame_count
      @common_kinds = {}
    end
    @common_kinds[[id, depth]] ||= begin
      common = $data_common_events[id]
      common ? marks_of(runnable(common.list || []), depth) : {}
    end
  end

  # Joins what a called common event does into what its caller does.
  #
  # @param marks [Hash] The caller's.
  # @param more [Hash] The common event's.
  def self.merge(marks, more)
    more.each { |key, value| marks[key] ||= value }
  end

  # Marks what a script does: a talk's, travel, or story for any other.
  #
  # @param marks [Hash] What the list does so far.
  # @param script [String] The script.
  def self.mark_script(marks, script)
    if script =~ TRAVEL_SCRIPTS
      marks[:travel] = true
    elsif script !~ TALK_SCRIPTS
      marks[:story] = true
    end
  end

  # Reads a script command with its continuation lines.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The script command's place.
  # @return [String] The script.
  def self.script_at(list, index)
    lines = [list[index].parameters[0].to_s]
    index += 1
    while list[index] && list[index].code == 655
      lines << list[index].parameters[0].to_s
      index += 1
    end
    lines.join("\n")
  end

  # Reports whether a switch is only scratch, or the player's own apart from party membership.
  #
  # @param id [Integer] The switch.
  # @return [Boolean] Whether it is.
  def self.temporary_switch?(id)
    return false if id.between?(1001, 2000)

    $data_system.switches[id].to_s =~ TEMPORARY_NAMES || (defined?(MGQ_MpStoryState) && MGQ_MpStoryState.personal_switch?(id)) ? true : false
  end

  # Reports whether a variable is only scratch, or the player's own, such as affection or where the
  # Pocket Castle's way out returns them.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it is.
  def self.temporary_variable?(id)
    $data_system.variables[id].to_s =~ TEMPORARY_NAMES || (defined?(MGQ_MpStoryState) && MGQ_MpStoryState.personal_variable?(id)) ? true : false
  end

  # Lists the self switches of the chests on the map.
  #
  # @return [Array<Array>] Their keys: map, event and letter.
  def self.chest_keys
    return @chest_keys if @chest_keys_map == $game_map.map_id

    @chest_keys_map = $game_map.map_id
    @chest_keys = $game_map.events.values.map { |event| chest_key_of_pages(event) }.compact
  end

  # Finds the self switch an event sets as a chest, on whichever of its pages gives the chest's
  # items, since a chest the player opened shows another page.
  #
  # @param event [Game_Event] The event.
  # @return [Array, nil] Its key, nil when no page is a chest's.
  def self.chest_key_of_pages(event)
    page = event.mgq_mp_pages.find { |candidate| kind_of(candidate.list || []) == :chest }
    page ? chest_key(event, page.list) : nil
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
    @tie_hold = nil
    event = event_id > 0 ? $game_map.events[event_id] : nil
    sorted = own?(event ? nil : list) ? :own : (event ? kind(event) : kind_of(list || []))
    sorted = :story if @as_story
    # A page of the leader's story that a scene change cut short must not hold the player's own; the
    # game's transfer process after a battle or a transfer shows nothing and leaves it.
    unless sorted == :own
      log("the page #{@mirrored[:page]} of the leader's story was cut short by an event starting") if @mirrored
      @mirrored = nil
    end
    @telling = leading_story? && sorted == :story
    if @telling && @told_last_frame
      log("the story's next event goes on with the telling that started on map #{@telling_map}")
    elsif @telling && moved_by_story? && by_itself?(event)
      continue_telling
    elsif @telling
      note_telling_start
      hold_for_tie(interpreter)
    end
    @moved_by_story_at = nil if @telling
    @may_tell = WATCHED_KINDS.include?(sorted) && (following? || leading_story?) && may_tell?(list || [])
    hold = @telling && scene?(list) && !MGQ_MpCoopGather.gathered?
    MGQ_MpCoopGather.hold(interpreter) if hold
    @chest = event && sorted == :chest && shares_chests? ? { :interpreter => interpreter, :key => chest_key(event), :gains => [] } : nil
    log_start(event, sorted, hold, list) if MGQ_MpCoop::Scope.sharing?
  end

  # Notes when and where the player's telling starts, and in a Raid World how far their story is,
  # which tells who sees the story: those whose story is there too, see
  # MGQ_MpCoop::Scope::Raid.viewers. Those an earlier telling took along no longer see it.
  #
  # Only a telling that starts after a frame without one is new: the story's next event starts in
  # the frame its last one ended, before the world's story of its changes went out, and would
  # otherwise lose the viewers whose story is still where the telling started.
  def self.note_telling_start
    @telling_at = Graphics.frame_count
    @telling_map = $game_map ? $game_map.map_id : nil
    @telling_moved = false
    @told_at = @told_page = nil unless @pending_say
    @told_markers = MGQ_MpCoop::Scope.raid? && defined?(MGQ_MpCoopStory) ? MGQ_MpCoopStory.own_markers : nil
    MGQ_MpCoopGather.forget_taken_along if defined?(MGQ_MpCoopGather)
    MGQ_MpCoopGather.note_story_progress if defined?(MGQ_MpCoopGather)
  rescue => e
    @told_markers = nil
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

  # Goes on with the telling that moved the player onto this map, as the story's next event starts
  # here, see moved_by_story?: when it started, how far the story was then and whom it took along
  # stay, and no tie is held, since the telling is older than any that starts now.
  def self.continue_telling
    @telling_map = $game_map ? $game_map.map_id : nil
    @telling_moved = true
    log("the story's next event goes on with the telling that moved the player from map #{@moved_from}")
  end

  # Notes that the player's telling moves them onto another map, as the story's transfer does, so
  # the story's next event there goes on with the telling, see started. Called before
  # Game_Player#perform_transfer.
  #
  # @param player [Game_Player] The player.
  def self.moving(player)
    return unless player.transfer? && telling?

    @moved_by_story_at = Graphics.frame_count
    @moved_from = $game_map.map_id
  rescue => e
    log("noting the story's move failed: #{e.class}: #{e.message}")
  end

  # Reports whether the player's telling moved them onto another map within CONTINUE_FRAMES, and
  # no story event went on with it yet, see moving.
  #
  # @return [Boolean] Whether it did.
  def self.moved_by_story?
    !@moved_by_story_at.nil? && !past?(@moved_by_story_at, CONTINUE_FRAMES)
  end

  # Reports whether the player's telling goes on: a story event of it runs, or it moved the player
  # onto another map and the story's next event there may still go on with it, see
  # moved_by_story?. world_story.rbx writes nothing meanwhile, since others would take the scene's
  # state half done.
  #
  # @return [Boolean] Whether it does.
  def self.telling_or_moved?
    telling? || moved_by_story?
  end

  # How far the player's story was as their telling started, in a Raid World.
  #
  # @return [Array<Integer>, nil] The values, see MGQ_MpCoopStory.markers_of; nil outside a telling
  #   and in a Classic world.
  def self.told_markers
    @telling ? @told_markers : nil
  end

  # Notes whether the player tells the story as the map's update ends, which tells a story's next
  # event from a new telling, see note_telling_start. Called after the map's update.
  def self.note_told_frame
    @told_last_frame = telling?
  end

  # Holds a Raid World's story event at its first command while someone on the map entered it
  # before the player, who would win a tie of two tellings started at the same moment, see
  # tie_holding?.
  #
  # @param interpreter [Game_Interpreter] The map's interpreter.
  def self.hold_for_tie(interpreter)
    return unless MGQ_MpCoop::Scope.raid?

    mine = MGQ_MpCoop::Scope.key_of(:me)
    earlier = MGQ_MpCoop::Scope.peers_here.select { |peer| (MGQ_MpCoop::Scope.key_of(peer) <=> mine) < 0 }
    return if earlier.empty?

    @tie_hold = interpreter
    log("holding the story event #{TIE_HOLD_FRAMES} frames: #{earlier.map { |peer| MGQ_MpOverworldSync.who(peer) }.join(', ')} entered the map first and may have started telling at the same moment")
  rescue => e
    @tie_hold = nil
    log("holding a story event for a tie failed: #{e.class}: #{e.message}")
  end

  # Reports whether the player's story event still waits at its start, see hold_for_tie: for
  # TIE_HOLD_FRAMES, unless another player turned out to tell the story here first, which
  # yield_story then stops before its first command. Asked before each of the interpreter's commands.
  #
  # @param interpreter [Game_Interpreter] The interpreter about to run a command.
  # @return [Boolean] Whether it waits.
  def self.tie_holding?(interpreter)
    return false unless @tie_hold && @tie_hold.equal?(interpreter)
    return true if @telling && !past?(@telling_at, TIE_HOLD_FRAMES) && !MGQ_MpCoop::Scope::Raid.first_teller_here.is_a?(MGQ_MpOverworldSync::Peers::Peer)

    @tie_hold = nil
    false
  rescue => e
    @tie_hold = nil
    log("holding a story event for a tie failed: #{e.class}: #{e.message}")
    false
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
    return unless list && list[index] && story_command?(list, index)

    @may_tell = false
    lead = MGQ_MpCoop::Scope.teller
    if behind?
      log("ended a talk where it would move the story on (command #{list[index].code}): the player's story is behind the world's")
      end_event(interpreter, list, "a talk ended where it would move the story on")
      MGQ_MpOverworldSync.notice(MGQ_MpWorldCatchup.refusal_text)
    elsif lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && following?
      log("ended a talk where it would move the story on (command #{list[index].code})")
      end_event(interpreter, list, "a talk ended where it would move the story on")
      MGQ_MpOverworldSync.notice(refusal_text(lead))
    elsif leading_story?
      @telling = true
      note_telling_start
      log("a talk moves the story on (command #{list[index].code}), the party hears it from here")
    end
  rescue => e
    @may_tell = false
    log("watching a talk failed: #{e.class}: #{e.message}")
  end

  # Stops the player's story event in a Raid World once another player turns out to tell the story
  # on the map too, having started it at the same moment: the one who entered the map first tells
  # it (MGQ_MpCoop::Scope::Raid.first_teller_here), and the other's event ends at its next command.
  # Called before each of an interpreter's commands.
  #
  # Only within TIE_FRAMES of the start, on the map it started on and never once the telling moved
  # its teller, since the map's order starts anew with every transfer, so a story moving its teller
  # onto a map where another player tells one would end halfway.
  #
  # @param interpreter [Game_Interpreter] The interpreter about to run a command.
  def self.yield_story(interpreter)
    return unless @telling && $game_map && interpreter.equal?($game_map.interpreter) && MGQ_MpCoop::Scope.raid?
    return if @telling_moved || @telling_map != $game_map.map_id || past?(@telling_at, TIE_FRAMES)

    lead = MGQ_MpCoop::Scope::Raid.first_teller_here
    return unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)

    list = MGQ_MpGame.get(interpreter, :list)
    @telling = false
    log("stopped the player's story event: #{MGQ_MpOverworldSync.who(lead)} started telling the story on map #{lead.state['map']} at the same moment, having entered it first")
    end_event(interpreter, list, "another player tells the story here") if list
    MGQ_MpOverworldSync.notice(refusal_text(lead))
  rescue => e
    log("stopping a story event told twice failed: #{e.class}: #{e.message}")
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

  # Reports whether an event command moves the story on, as story_marks? sorts it.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The command's place.
  # @return [Boolean] Whether it does.
  def self.story_command?(list, index)
    marks = {}
    mark_command(marks, list, index, 0)
    story_marks?(marks) || marks[:own_switch] || marks[:battle] || marks[:choice_story] ? true : false
  end

  # Reports whether a list of commands is a story scene: story with its own dialogue or novel scene.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Boolean] Whether it is.
  def self.scene?(list)
    return false unless list

    runnable(list).any? { |c| MESSAGE_CODES.include?(c.code) || (c.code == 355 && c.parameters[0].to_s =~ /\A\s*call_novel_scene/) } && kind_of(list) == :story
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
  #   "tsm" and "twb" too while it plays, how far the player's story was as it started, see
  #   told_markers, and whether warping is banned where the player stands, see
  #   MGQ_MpCoopGather.warp_ban?.
  def self.state_fields
    playing = story_playing?
    fields = { "telling" => playing ? 1 : 0 }
    return fields unless playing && told_markers

    fields["tsm"] = @told_markers.join(",")
    fields["twb"] = MGQ_MpCoopGather.warp_ban? ? 1 : 0 if defined?(MGQ_MpCoopGather)
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
      return log_once([:not_watching, kind, peer ? peer.state["id"].to_s : nil], "ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: #{scope.raid? ? "the player's story is not where theirs is" : 'not synced with the leader, the player plays their own story'}")
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
  # the world's (held_behind), or until the world's story came (awaits_world_story). Called when the
  # map's main event would start it. A new game's opening never starts while world_opening.rbx runs
  # its setup without its scene.
  #
  # An event that runs by itself is left to the teller's own game, which runs it on its map.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it is the teller's, so it must not run here.
  def self.hand_over(event)
    return true if defined?(MGQ_MpWorldOpening) && MGQ_MpWorldOpening.holds?(event)
    return awaits_world_story(event) if defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.awaits_world? && !own? && kind(event) == :story
    return held_behind(event) if behind? && !own? && kind(event) == :story

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
      return false if lead.state["telling"] == "1" && lead.state["scene"] != "battle" && MGQ_MpCoop::Scope.silent?(lead)

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

  # Reports whether the player's story is behind a Raid World's, which keeps their story events from
  # starting, see MGQ_MpWorldCatchup.holds_story?.
  #
  # @return [Boolean] Whether it is.
  def self.behind?
    defined?(MGQ_MpWorldCatchup) && MGQ_MpWorldCatchup.holds_story? ? true : false
  end

  # Keeps a story event from starting while the player's story is behind the world's: one they
  # start tells the level that moves them on, once per event in REFUSE_FRAMES, and one that runs by
  # itself waits silently, so a teleport onto its map cannot loop.
  #
  # @param event [Game_Event] The story event.
  # @return [Boolean] Always true: it must not run.
  def self.held_behind(event)
    if event.trigger == 3
      log_once([:behind_autorun, $game_map.map_id, event.id], "kept event #{event.id} on map #{$game_map.map_id} that runs by itself from starting: it is story, and the player's story is behind the world's")
      return true
    end

    key = [$game_map.map_id, event.id]
    return true if @refused == key && !past?(@refused_at, REFUSE_FRAMES)

    @refused = key
    @refused_at = Graphics.frame_count
    log("kept story event #{event.id} on map #{$game_map.map_id} from starting: the player's story is behind the world's")
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
    key = [:await, $game_map.map_id, event.id]
    return if @refused == key && !past?(@refused_at, REFUSE_FRAMES)

    @refused = key
    @refused_at = Graphics.frame_count
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
    key = [$game_map.map_id, event.id]
    return if @refused == key && !past?(@refused_at, REFUSE_FRAMES)

    @refused = key
    @refused_at = Graphics.frame_count
    log("kept story event #{event.id} on map #{$game_map.map_id} from starting: only #{MGQ_MpOverworldSync.who(lead)} starts story (on map #{lead.state['map']})")
    away = lead.state["map"].to_i == $game_map.map_id || MGQ_MpCoop::Scope.raid? ? "" : " Bring them here to go on."
    MGQ_MpOverworldSync.notice("#{refusal_text(lead)}#{away}")
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
    if behind? && !own?(common.list) && kind_of(common.list || []) == :story
      log_once([:behind_common, common.respond_to?(:id) ? common.id : "?"], "kept common event #{common.respond_to?(:id) ? common.id : '?'} that runs by itself from starting: it is story, and the player's story is behind the world's")
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

  # As leader, tells the members on the map the message the player's story shows now. While the
  # player holds the game's skip, a page within SKIP_SEND_FRAMES of the last one told is kept
  # instead, replacing the one kept before, which is never told; flush_say tells it. Called before
  # an interpreter waits for a message.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.show(interpreter)
    return unless @telling && main_event?(interpreter)

    message = $game_message
    page = [message.texts.dup, message.choices.dup]
    return if page == [[], []] || page == @shown

    @shown = page
    @page = @page.to_i + 1
    fields = MGQ_MpCoopGather.place_fields.merge(
      "page" => page_id, "face" => message.face_name.to_s, "index" => message.face_index.to_i,
      "background" => message.background.to_i, "position" => message.position.to_i,
      "lines" => page[0].map { |line| [line.to_s].pack('m0') }.join(","),
      "choices" => page[1].map { |choice| [choice.to_s].pack('m0') }.join(","))
    note = "#{page[0].size} lines, #{page[1].size} choices, face #{message.face_name}, first line #{page[0].first.to_s[0, 60].inspect}"
    @skipped_pages = @skipped_pages.to_i + 1 if @pending_say
    @pending_say = nil
    if skip_held? && @told_at && !past?(@told_at, SKIP_SEND_FRAMES)
      @pending_say = { :id => page_id, :fields => fields, :note => note, :viewers => MGQ_MpCoop::Scope.viewers, :passed => false }
    else
      tell_say(page_id, fields, note, MGQ_MpCoop::Scope.viewers)
    end
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
  # @param id [String] The page's id, see page_id.
  # @param fields [Hash] The page's fields.
  # @param note [String] What the log says of the page.
  # @param viewers [Array<MGQ_MpOverworldSync::Peers::Peer>] Those who see the story, as the page
  #   showed.
  def self.tell_say(id, fields, note, viewers)
    skipped = @skipped_pages.to_i
    @skipped_pages = 0
    @told_at = Graphics.frame_count
    @told_page = id
    log("telling the party page #{id} of the story: #{note}#{skipped > 0 ? ", left out the #{skipped} page(s) before it the player skipped past" : ''}")
    tell_followers("say", fields, viewers)
  end

  # As teller, tells those who see the story that the player moved past a page told.
  #
  # @param id [String] The page's id, see page_id.
  # @param viewers [Array<MGQ_MpOverworldSync::Peers::Peer>] Those who see the story.
  def self.tell_done(id, viewers = MGQ_MpCoop::Scope.viewers)
    @told_page = nil
    log("the leader moved past page #{id}, telling the party")
    tell_followers("done", MGQ_MpCoopGather.place_fields.merge("page" => id), viewers)
  end

  # As teller, tells the page kept while the player holds the game's skip, and that the player
  # moved past it if they did, once SKIP_SEND_FRAMES passed since the last page told, the skip is
  # let go, the telling ended or another scene was called, so the viewers end on the last page.
  # Called after the map's update, after the frame's pages.
  #
  # It goes to those who saw the story as the page showed, since a Raid World's viewers are nobody
  # once its telling ended.
  def self.flush_say
    pending = @pending_say
    return unless pending
    return if skip_held? && @telling && !past?(@told_at, SKIP_SEND_FRAMES) && SceneManager.scene.is_a?(Scene_Map)

    @pending_say = nil
    tell_say(pending[:id], pending[:fields], pending[:note], pending[:viewers])
    tell_done(pending[:id], pending[:viewers]) if pending[:passed]
  rescue => e
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

  # As leader, tells the members on the map that the player moved past the message their story
  # showed, which moves the members' window on, only for a page told: the page kept while the
  # player skips is noted as passed, which flush_say tells with it. Called once an interpreter
  # waited for a message.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.shown(interpreter)
    return unless @shown && main_event?(interpreter)

    @shown = nil
    if @pending_say && @pending_say[:id] == page_id
      @pending_say[:passed] = true
    elsif @told_page == page_id
      tell_done(page_id)
    end
  rescue => e
    log("telling a message's end failed: #{e.class}: #{e.message}")
  end

  # Names the page the leader's story shows now, unique beyond this session, so a member's game
  # never takes a page of an earlier session for one already done.
  #
  # @return [String] The page's id.
  def self.page_id
    @session ||= MGQ_MpCoop.random_id(6)
    "#{@session}.#{@page}"
  end

  # Keeps a message of the leader's story to show once the player is free.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param message [Hash] The message's fields.
  def self.hear(peer, message)
    forget_former_leader(peer)
    lines = message["lines"].to_s.split(",").map { |line| decode(line) }
    choices = message["choices"].to_s.split(",").map { |choice| decode(choice) }
    lines += ["#{peer.state['name']} chooses: #{choices.join(' / ')}"] unless choices.empty?
    return log("dropped page #{message['page']} of #{MGQ_MpOverworldSync.who(peer)}'s story: no text") if lines.empty?

    @heard << { :page => message["page"].to_s, :face => message["face"].to_s, :index => message["index"].to_i,
                :background => message["background"].to_i, :position => message["position"].to_i, :lines => lines }
    dropped = 0
    while @heard.size > MAX_HEARD
      @heard.shift
      dropped += 1
    end
    log("heard page #{message['page']} of #{MGQ_MpOverworldSync.who(peer)}'s story: #{lines.size} lines, #{choices.size} choices, " \
        "#{@heard.size} waiting to show#{dropped > 0 ? ", dropped the #{dropped} oldest" : ''}")
  end

  # Notes that the teller moved past a page of their story.
  #
  # @param message [Hash] The message's fields, the page's id under "page".
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] The teller, nil when unknown.
  def self.heard_done(message, peer = nil)
    forget_former_leader(peer)
    @done.push(message["page"].to_s)
    @done.shift while @done.size > MAX_DONE
    log("the leader moved past page #{message['page']}")
  end

  # Reports whether the leader moved past a page of their story.
  #
  # @param page [String] The page's id.
  # @return [Boolean] Whether they did.
  def self.done?(page)
    (@done || []).include?(page)
  end

  # Reports whether the message window shows a page of the leader's story, which only the leader
  # moves on.
  #
  # @return [Boolean] Whether it does.
  def self.mirroring?
    !@mirrored.nil?
  end

  # Reports whether the page of the teller's story the window shows is over: the teller moved past
  # it and the player had the time to read it (see read?), the teller is no longer the player's
  # leader or gone, or stopped telling the story a while ago.
  #
  # The teller's state and their pages travel apart, so a page may arrive before the state that
  # says the story plays.
  #
  # @return [Boolean] Whether it is over.
  def self.page_done?
    return true unless @mirrored
    return read? if done?(@mirrored[:page])

    lead = page_teller
    return page_over("#{MGQ_MpOverworldSync.who(lead)} is no longer the player's leader") unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)

    lead.state["telling"] != "1" && past?(@mirrored[:since], STALE_FRAMES) ? page_over("the leader stopped telling the story #{STALE_FRAMES} frames ago") : false
  end

  # Reports whether a page the leader moved past is over for the player: the story is about to
  # take the player elsewhere (giving_way?), its reading time passed (see reading_frames),
  # the player pressed confirm or holds the game's skip (SKIP_BUTTON), or more than CATCH_UP_PAGES
  # wait behind it.
  #
  # @return [Boolean] Whether it is.
  def self.read?
    waiting = giving_way?
    return page_over("the leader moved past it and #{waiting} waits for the player") if waiting
    return page_over("the leader moved past it and #{@heard.size} more pages wait") if @heard.size > CATCH_UP_PAGES
    return page_over("the leader moved past it and the player read it") if past?(@mirrored[:since], @mirrored[:read].to_i)
    return page_over("the leader moved past it and the player read on") if Input.trigger?(:C)
    return page_over("the leader moved past it and the player skips") if Input.press?(SKIP_BUTTON)

    false
  end

  # Tells how long a page of the leader's story stays at least once the leader moved past it.
  #
  # @param lines [Array<String>] The page's lines.
  # @return [Integer] The frames, see READ_FRAMES.
  def self.reading_frames(lines)
    [READ_FRAMES + lines.join.size * READ_FRAMES_PER_CHARACTER, MOST_READ_FRAMES].min
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

  # Logs once why the page of the leader's story the window shows is over.
  #
  # @param reason [String] Why it is.
  # @return [Boolean] true.
  def self.page_over(reason)
    unless @mirrored[:over]
      @mirrored[:over] = true
      log("the page #{@mirrored[:page]} of the leader's story is over: #{reason}")
    end
    true
  end

  # Notes that the window finished the page of the leader's story.
  def self.page_ended
    @mirrored = nil
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
  # past it, see read?. A page too long for the window shows its rest after OVERFLOW_FRAMES. A page
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

  # Reads a line written for a message.
  #
  # @param text [String] The line, Base64.
  # @return [String] The line.
  def self.decode(text)
    text.unpack('m0')[0].to_s.force_encoding("UTF-8")
  end

  # Shows the next page of the leader's story once the player is free, leaving out the oldest pages
  # the leader moved past while more than CATCH_UP_PAGES wait. While something waits for the player
  # to be free (see give_way_to), no page starts and those the leader moved past are left out, so
  # the player is free for it; the others show after.
  def self.show_heard
    return if @heard.nil? || @heard.empty? || !MGQ_MpOverworldSync.map_free?
    return give_way if giving_way?
    unless MGQ_MpCoop::Scope.sharing?
      log("dropped #{@heard.size} waiting pages of the leader's story: no longer in a party")
      return @heard.clear
    end

    skipped = []
    skipped << @heard.shift[:page] while @heard.size > CATCH_UP_PAGES && done?(@heard.first[:page])
    log("skipped pages #{skipped.join(', ')} of the leader's story: the leader moved past them while the player was busy, #{CATCH_UP_PAGES} pages behind at most") unless skipped.empty?
    return if @heard.empty?

    page = @heard.shift
    log("showing page #{page[:page]} of the leader's story, #{@heard.size} more waiting")
    $game_message.face_name = MGQ_MpOverworld.graphic?(:face, page[:face].to_s) ? page[:face] : ""
    $game_message.face_index = page[:index]
    $game_message.background = page[:background]
    $game_message.position = page[:position]
    page[:lines].each { |line| $game_message.add(line) }
    @mirrored = { :page => page[:page], :since => Graphics.frame_count, :read => reading_frames(page[:lines]) }
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

  # Leaves out the waiting pages the leader moved past while something waits for the player to be
  # free, see show_heard.
  def self.give_way
    passed = @heard.select { |page| done?(page[:page]) }.map { |page| page[:page] }
    return if passed.empty?

    @heard.reject! { |page| passed.include?(page[:page]) }
    log("skipped pages #{passed.join(', ')} of the leader's story: #{giving_way?} waits for the player, #{@heard.size} still to show after")
  end

  # Forgets the pages of the story a former teller told and moved past, once the teller changed,
  # so they never show after the story they belong to: another member leads or the party is over,
  # or in a Raid World another player tells the story, or the player does.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who just told a page, nil for none.
  def self.forget_former_leader(peer = nil)
    id = page_source_id(peer)
    return if id == @heard_from

    waiting = (@heard || []).size
    log("the teller whose story pages the player follows is #{id ? MGQ_MpOverworldSync.who(peer || MGQ_MpCoop::Scope.teller) : 'nobody'} now#{waiting > 0 ? ", forgot #{waiting} waiting pages of the former teller" : ''}")
    @heard_from = id
    @heard = []
    @done = []
  end

  # Finds the id of the teller whose pages the player follows now: the party's leader; in a Raid
  # World the player who just told a page, else the teller on the map, or still the last one while
  # nobody's state says they tell, since a teller's state and their pages travel apart.
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
    flush_say
    note_told_frame
    forget_former_leader
    show_heard
    take_held_chests
    tell_chest_news
    lift_dark_screen
  rescue => e
    log("updating the party's events failed: #{e.class}: #{e.message}")
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

  # Ends the telling of the map's main event once it ended, and tells the party about a chest the
  # player opened; a chest left shut, such as a locked one, tells nothing.
  #
  # A loaded save, or the game put back after a PvP battle, runs the map's last event's list once
  # more from its end, which would tell the party whatever message waits, such as the battle's result.
  #
  # @param interpreter [Game_Interpreter] The interpreter that ended.
  def self.finished(interpreter)
    @telling = false if $game_map && interpreter.equal?($game_map.interpreter)
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

  # Before an event command runs, a story event waits a moment at its start for a tie, a story told
  # twice at once ends for the later teller, and a talk that may turn into story is watched.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "coop_events") do
    begin
      Fiber.yield while MGQ_MpCoopEvents.tie_holding?(self)
    rescue FiberError
      # An interpreter run outside a fiber cannot wait, so its command runs at once.
    end
    MGQ_MpCoopEvents.yield_story(self)
    MGQ_MpCoopEvents.guard(self)
  end

  # Before the player's transfer, a telling that moves them is noted, so the story's next event on
  # the new map goes on with it.
  MGQ_MpHooks.before(Game_Player, :perform_transfer, "coop_events") { MGQ_MpCoopEvents.moving(self) }
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
