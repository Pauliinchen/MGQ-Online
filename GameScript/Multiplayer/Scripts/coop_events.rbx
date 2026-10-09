#----------------------------------------------------------------
#  coop_events.rbx
#
#  Changelog:
#      Paulinchen  2026-10-09: Asked story_state.rbx which switches and variables are the player's own instead of coop_story.rbx
#                            - Kept story events from starting while the player's story is behind a Raid World's, telling the level that moves them on, and held those that run by themselves, so a teleport onto their map cannot loop
#                            - Kept a Raid World's telling, how far its story was, where it started and whom it took along, through the story's next event that starts in the frame its last ended, so its viewers see the rest of the story
#                            - Held a Raid World's story event at its start for TIE_HOLD_FRAMES while someone on the map entered it first, so a tie stops it before it changed anything
#                            - Told the story's pages to a Raid World's viewers in one message instead of one per viewer
#      Paulinchen  2026-10-08: Took the teller, the viewers and the gate of the story's messages from MGQ_MpCoop::Scope: the party's leader and synced members in a Classic world, the player telling the story on the map and those whose story matches in a Raid World
#                            - Stopped a story event in a Raid World once a player who entered the map first started telling the story there at the same moment, within TIE_FRAMES of its start and on its map alone
#                            - Told the story's progress and whether warping is banned at the start of the telling in a Raid World, which tells who sees the scene and what a teleport to the story takes
#                            - Kept chests personal in a Raid World, whose parties share no loot
#                            - Kept the Library's replays of scenes and the game's transfer process to the player's own game, never the party's story, so a leader's replay no longer brings the members over
#                            - Showed a page of the leader's story without its face while this game lacks the face file
#                            - Kept a story event in a Raid World from starting until the world's story of a telling the player watched on the map arrived, so they no longer play the scene again
#      Paulinchen  2026-10-07: Took a common event's setup, which passes the list alone, instead of failing on it
#                            - Registered the interpreter, map, message and party hooks through core_hooks.rbx instead of wraps of its own
#                            - Let a page of the leader's story outside a fiber move on at once instead of failing, as the other waits do
#                            - Named players, counted a message's bytes and made up the session's tag through coop.rbx and overworld_sync.rbx instead of copies of their helpers
#                            - Blocked, watched and mirrored the leader's story only for members synced with the leader, whose own story events run otherwise, and told the leader's pages to them alone
#                            - Logged how each event starting is sorted and who may run it, every message, the leader's pages told, shown and dropped and why, and the chests shared
#                            - Ended the telling of the leader's story with its event, so the result of a PvP battle no longer reaches the party
#      Paulinchen  2026-10-06: Took sound names that hold dots, as picture names may
#                            - Asked coop.rbx for the party's leader
#                            - Forgot the pages of the story a former leader told, once another member leads
#                            - Took a time from before a save the player loaded as long past
#                            - Gave a chest's items with the gifts kept apart as every other gift
#                            - Found a chest's items through MGQ_MpGame.item
#                            - Kept a chest the player leaves shut, such as a locked one, closed for them and the party
#      Paulinchen  2026-10-04: Held back chests other members open during a PvP battle, and kept gifts out of a chest the player opens
#                            - Sent the sound a chest played with its items, and let members hear it and see the first item's icon, after a battle once on the map
#                            - Read where the Pocket Castle's way out returns as the player's own variables
#                            - Kept the leader's pages of the map a member follows the leader to
#                            - Kept a member's story events from starting anywhere, since only the leader starts story, and no longer asked the leader's game to play them
#                            - Sorted called common events by what can run now, shops with a goods script as talks, and story behind a choice as a talk watched as it runs
#                            - Moved gathering the party for story scenes into coop_gather.rbx
#                            - Moved the Pocket Castle's residents into coop_castle.rbx
#                            - Renamed from mp_coop_events.rbx
#      Paulinchen  2026-10-03: Sorted the Pocket Castle item as travel, which no longer gathers the party as a story scene
#                            - Let a member teleport to the party's leader on their own
#                            - Took over the warp ban of the leader's place when a story scene brings the player over, so a Harpy Feather works again outside a cave
#                            - Said the story's line above the player's own head through MGQ_MpActions
#                            - Held the player through MGQ_MpHooks.hold_player
#                            - Asked MGQ_MpOverworldSync whether the map is quiet or the player free on it
#                            - Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Left every starting story event to the leader, so one that starts by itself no longer keeps a member's other events from starting
#                            - Knew a chest by any of its pages, so one the player opened stays their own
#      Paulinchen  2026-10-02: Told coop_story.rbx the items and gold the leader's story gives or takes
#                            - Sorted a common event once per depth, so one sorted deep down no longer counts as story when called higher up
#                            - Held event commands and followed the map's update through core_hooks.rbx
#                            - Took whether the player plays in a party, and an event's page, from coop.rbx
#                            - Told the kinds of item a chest gives by their class alone
#                            - Started no random encounter for a member the leader's story scene is about to bring over
#      Paulinchen  2026-10-01: Sorted event pages by the branches that can run now, so an exit counts as story only while its story warning shows
#                            - Let exits that only note a flag on the way stay travel, so a member leaves a town in their own game
#                            - Shortened a member's time before the leader's story scene brings them over to five seconds
#                            - Moved the leader's story pages on in a member's game only when the leader moves on, skipping those already past
#                            - Sorted the Pocket Castle's companions, merchants, inn and maids as talks
#                            - Held the leader's story scene until every member stands near, at most thirty seconds, bringing members over after ten seconds or once out of battle
#                            - Kept members on the leader's map from moving or opening the menu while the leader's story scene plays
#                            - Stopped taking the members along to every map the leader goes to; only story scenes gather them
#      Paulinchen  2026-09-30: Sent and took the party's messages through coop.rbx, which drops those of another party
#                            - Registered with overworld_sync.rbx for its messages instead of being asked by overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as coop_events.rbx, which Multiplayer.rb loads
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

  # Scripts a talk may run: companions' own lines, choices, presents and affection, medals,
  # music, skill names on screen, and the menus of job change, synthesis, the casino and the party.
  # Shops that list their goods in a script, such as the Casino's coin sellers, are talks too.
  TALK_SCRIPTS = /\A\s*(actor_label_jump|unlimited_choices|ex_choice_\w+|present_start|change_friend|gain_medal|gain_coin|play_base_bgm|clear_skill_name|display_skill_name|call_synthesize|call_slot_scene|start_poker|call_party_edit|SceneManager\.call\(Scene_JobChange\)|names = party_members|@?goods\b)/

  # Event commands that start a choice's branch: one choice (402) and the choice of cancelling (403).
  CHOICE_BRANCHES = [402, 403]

  # Scripts that travel.
  TRAVEL_SCRIPTS = /\A\s*(forced_transfer|forced_get_off_vehicle|forced_get_on_airship)/

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

  # Frames after a Raid World's telling starts in which another player who started telling on the
  # same map at the same moment, and entered it first, stops it, three seconds of the state's lag.
  TIE_FRAMES = 180

  # Frames a Raid World's story event waits at its start while someone on the map entered it before
  # the player, half a second, so their state can tell that they started telling at the same moment
  # before the event changed anything.
  TIE_HOLD_FRAMES = 30

  # Frames a page of the leader's story stays after the leader stopped telling the story, two
  # seconds, before a member's game ends it anyway.
  STALE_FRAMES = 120

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
  GATHER_MESSAGES = %w(gather come where follow)

  # Common events that run only in the player's own game, never as the party's story: the game's
  # transfer process, which runs by itself after a transfer.
  OWN_COMMON_EVENTS = [114]

  # The game's switch that is on while the Library replays a scene, by its id in 3.06.
  LIBRARY_REPLAY_SWITCH = 443

  @common_kinds = {}
  @chest = nil
  @granting = false
  @page_end = false

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op events"

  # Sorts an event's current page, by what of it can run now.
  #
  # @param event [Game_Event] The event.
  # @return [Symbol] :talk, :travel, :chest, :battle or :story; :talk for an event without a page.
  def self.kind(event)
    return :talk if event.mgq_mp_page < 0

    exit?(event) ? :travel : kind_of(event.list || [])
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
  # when its condition holds, its else only when it does not; branches on anything else may run.
  #
  # Exits hold the story's warnings in such branches, as Iliasville's do ("I need to be on time for
  # my baptism"), which would make every exit story long after the warnings passed.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Array<RPG::EventCommand>] Those that can run.
  def self.runnable(list)
    held = {}
    skip = nil
    list.select do |command|
      indent = command.indent
      next false if skip && indent > skip

      case command.code
      when 111
        held[indent] = holds?(command.parameters)
        skip = indent if held[indent] == false
      when 411 then skip = held[indent] == true ? indent : nil
      when 412 then skip = nil
      end
      true
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
  # talk, which may turn into story once that choice is taken (see may_tell? and guard).
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Symbol] :talk, :travel, :chest, :battle or :story.
  def self.kind_of(list)
    return :talk if defined?(MGQ_MpCoopCastle) && MGQ_MpCoopCastle.resident?(list)

    list = runnable(list)
    # Wandering monsters call the game's common events before and after their battle, which set
    # variables, so a battle is told apart by the page itself: a fight without its own dialogue.
    return :battle if list.any? { |c| c.code == 301 } && list.none? { |c| MESSAGE_CODES.include?(c.code) }

    marks = marks_of(list, 0)
    return :story if story_marks?(marks)
    return :chest if marks[:gives] && marks[:own_switch]
    return :story if marks[:own_switch] || marks[:battle]

    marks[:travel] ? :travel : :talk
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
    list.each_with_index do |command, index|
      branches.pop while !branches.empty? && command.indent <= branches.last
      next branches.push(command.indent) if CHOICE_BRANCHES.include?(command.code)

      mark_command(branches.empty? ? marks : choice, list, index, depth)
    end
    # A chest asks first whether to open it, so its own switch with items behind a choice keeps it a chest.
    chest = choice[:gives] && choice[:own_switch]
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
  # @return [Hash] What it does, see marks_of; a common event too deep counts as story.
  def self.common_marks(id, depth)
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
    # A page of the leader's story that a scene change cut short must not hold the player's own.
    log("the page #{@mirrored[:page]} of the leader's story was cut short by an event starting") if @mirrored
    @mirrored = nil
    event = event_id > 0 ? $game_map.events[event_id] : nil
    sorted = own?(event ? nil : list) ? :own : (event ? kind(event) : kind_of(list || []))
    @telling = leading_story? && sorted == :story
    if @telling && @told_last_frame
      log("the story's next event goes on with the telling that started on map #{@telling_map}")
    elsif @telling
      note_telling_start
      hold_for_tie(interpreter)
    end
    @may_tell = sorted == :talk && (following? || leading_story?) && may_tell?(list || [])
    hold = @telling && scene?(list) && !MGQ_MpCoopGather.gathered?
    MGQ_MpCoopGather.hold(interpreter) if hold
    @chest = event && sorted == :chest && shares_chests? ? { :interpreter => interpreter, :key => chest_key(event), :gains => [] } : nil
    log_start(event, sorted, hold) if MGQ_MpCoop::Scope.sharing?
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
    @told_markers = MGQ_MpCoop::Scope.raid? && defined?(MGQ_MpCoopStory) ? MGQ_MpCoopStory.own_markers : nil
    MGQ_MpCoopGather.forget_taken_along if defined?(MGQ_MpCoopGather)
  rescue => e
    @told_markers = nil
    log("noting the story's progress failed: #{e.class}: #{e.message}")
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
  def self.log_start(event, sorted, hold)
    what = event ? "event #{event.id} (page #{event.mgq_mp_page + 1}) on map #{$game_map.map_id}" : "a common event on map #{$game_map.map_id}"
    notes = []
    notes << "runs only in the player's own game: #{library_replay? ? "the Library's replay of a scene" : "the game's transfer process"}" if sorted == :own
    notes << "the leader tells the party this story" if @telling
    notes << "the player plays their own story, not synced with the leader or leading no member who follows it" unless following? || leading_story?
    notes << "held until the party gathers" if hold
    notes << "a talk that may turn into story, watched" if @may_tell
    notes << "a chest, #{@chest[:key] ? "self switch #{@chest[:key].join('.')}" : 'without a self switch'}" if @chest
    log("#{what} starts as #{sorted}#{notes.empty? ? '' : ": #{notes.join(', ')}"}")
  rescue => e
    log("logging an event's start failed: #{e.class}: #{e.message}")
  end

  # Watches a talk that may turn into story, before each of its commands: once it reaches a command
  # that moves the story on, a member's game ends the talk there, since only the leader moves the
  # story on, and the leader's game tells the party the story from there.
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
      # The list ends with an empty command, which ends the event as its last.
      MGQ_MpGame.set(interpreter, :index, list.size - 1)
      MGQ_MpOverworldSync.notice(MGQ_MpWorldCatchup.refusal_text)
      log("ended a talk where it would move the story on (command #{list[index].code}): the player's story is behind the world's")
    elsif lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && following?
      # The list ends with an empty command, which ends the event as its last.
      MGQ_MpGame.set(interpreter, :index, list.size - 1)
      MGQ_MpOverworldSync.notice(refusal_text(lead))
      log("ended a talk where it would move the story on (command #{list[index].code})")
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
  # Only within TIE_FRAMES of the start and on the map it started on, since the map's order starts
  # anew with every transfer, so a story moving its teller onto a map where another player tells
  # one would end halfway.
  #
  # @param interpreter [Game_Interpreter] The interpreter about to run a command.
  def self.yield_story(interpreter)
    return unless @telling && $game_map && interpreter.equal?($game_map.interpreter) && MGQ_MpCoop::Scope.raid?
    return if @telling_map != $game_map.map_id || past?(@telling_at, TIE_FRAMES)

    lead = MGQ_MpCoop::Scope::Raid.first_teller_here
    return unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)

    list = MGQ_MpGame.get(interpreter, :list)
    # The list ends with an empty command, which ends the event as its last.
    MGQ_MpGame.set(interpreter, :index, list.size - 1) if list
    @telling = false
    log("stopped the player's story event: #{MGQ_MpOverworldSync.who(lead)} started telling the story on map #{lead.state['map']} at the same moment, having entered it first")
    MGQ_MpOverworldSync.notice(refusal_text(lead))
  rescue => e
    log("stopping a story event told twice failed: #{e.class}: #{e.message}")
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

  # As teller, sends a message about the story to those who see it, see MGQ_MpCoop::Scope.viewers.
  #
  # @param kind [String] What it is about.
  # @param fields [Hash] Its other fields.
  def self.tell_followers(kind, fields)
    followers = MGQ_MpCoop::Scope.viewers
    return log("told nobody #{kind}: nobody follows the player's story") if followers.empty?
    return followers.each { |peer| tell(peer.seat, kind, fields) } unless MGQ_MpCoop::Scope.raid?

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
    unless scope.watches?(peer)
      return log("ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: #{scope.raid? ? "the player's story is not where theirs is" : 'not synced with the leader, the player plays their own story'}")
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
  # In a Raid World only while another player tells the story on the map, or while the player's
  # story is behind the world's (held_behind). Called when the map's main event would start it.
  #
  # An event that runs by itself is left to the teller's own game, which runs it on its map.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it is the teller's, so it must not run here.
  def self.hand_over(event)
    return held_behind(event) if behind? && !own? && kind(event) == :story

    lead = MGQ_MpCoop::Scope.teller
    return awaits_told_story?(event) unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)
    return false unless !own? && kind(event) == :story
    unless following?
      log_once([:own_story, $game_map.map_id, event.id, lead.state["id"].to_s], "story event #{event.id} on map #{$game_map.map_id} runs in the player's own game: not synced with #{MGQ_MpOverworldSync.who(lead)}, the player plays their own story")
      return false
    end
    if event.trigger == 3
      log_once([:autorun, $game_map.map_id, event.id, lead.state["id"].to_s],
               "kept event #{event.id} on map #{$game_map.map_id} that runs by itself from starting: it is story, which #{MGQ_MpOverworldSync.who(lead)}'s game runs")
      return true
    end

    refuse_story(event, lead)
    true
  rescue => e
    log("keeping a story event from starting failed: #{e.class}: #{e.message}")
    false
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

  # Keeps a story event from starting in a Raid World while the world's story of a telling the
  # player watched on the map has not arrived yet, see MGQ_MpWorldStory.awaits_teller?.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it must not run yet.
  def self.awaits_told_story?(event)
    return false unless defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.awaits_teller? && !own? && kind(event) == :story

    log_once([:await_told, $game_map.map_id, event.id], "kept story event #{event.id} on map #{$game_map.map_id} from starting: the world's story of the telling the player watched has not arrived yet")
    true
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

    OWN_COMMON_EVENTS.any? { |id| (common = $data_common_events[id]) && list.equal?(common.list) }
  rescue => e
    log_once(:own, "telling the player's own events apart failed: #{e.class}: #{e.message}")
    false
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

  # As leader, tells the members on the map the message the player's story shows now. Called
  # before an interpreter waits for a message.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.show(interpreter)
    return unless @telling && interpreter.equal?($game_map.interpreter)

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
    log("telling the party page #{page_id} of the story: #{page[0].size} lines, #{page[1].size} choices, face #{message.face_name}, first line #{page[0].first.to_s[0, 60].inspect}")
    tell_followers("say", fields)
  rescue => e
    log("telling a message failed: #{e.class}: #{e.message}")
  end

  # As leader, tells the members on the map that the player moved past the message their story
  # showed, which moves the members' window on. Called once an interpreter waited for a message.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.shown(interpreter)
    return unless @shown && interpreter.equal?($game_map.interpreter)

    @shown = nil
    log("the leader moved past page #{page_id}, telling the party")
    tell_followers("done", MGQ_MpCoopGather.place_fields.merge("page" => page_id))
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
  # it, is no longer the player's leader or gone, or stopped telling the story a while ago.
  #
  # The teller's state and their pages travel apart, so a page may arrive before the state that
  # says the story plays.
  #
  # @return [Boolean] Whether it is over.
  def self.page_done?
    return true unless @mirrored
    return page_over("the leader moved past it") if done?(@mirrored[:page])

    lead = page_teller
    return page_over("#{MGQ_MpOverworldSync.who(lead)} is no longer the player's leader") unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)

    lead.state["telling"] != "1" && past?(@mirrored[:since], STALE_FRAMES) ? page_over("the leader stopped telling the story #{STALE_FRAMES} frames ago") : false
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
  # neither move it on nor close it, nor skip it with the game's skip key. A page too long for the
  # window shows its rest after OVERFLOW_FRAMES.
  #
  # @param window [Window_Message] The message window.
  def self.hold_page(window)
    page_end = @page_end
    window.pause = true
    frames = 0
    begin
      until page_done? || (!page_end && frames >= OVERFLOW_FRAMES)
        Fiber.yield
        frames += 1
      end
    rescue FiberError
      # A message window outside a fiber cannot wait, so the page moves on at once.
      log_once(:page_fiber, "could not hold a page of the leader's story: the message window runs outside a fiber, so it moves on at once")
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

  # Shows the page of the leader's story the leader is on, once the player is free, leaving out the
  # pages the leader moved past meanwhile.
  def self.show_heard
    return if @heard.nil? || @heard.empty? || !MGQ_MpOverworldSync.map_free?
    unless MGQ_MpCoop::Scope.sharing?
      log("dropped #{@heard.size} waiting pages of the leader's story: no longer in a party")
      return @heard.clear
    end

    skipped = []
    skipped << @heard.shift[:page] while !@heard.empty? && done?(@heard.first[:page])
    log("skipped pages #{skipped.join(', ')} of the leader's story: the leader moved past them while the player was busy") unless skipped.empty?
    return if @heard.empty?

    page = @heard.shift
    log("showing page #{page[:page]} of the leader's story, #{@heard.size} more waiting")
    $game_message.face_name = MGQ_MpOverworld.graphic?(:face, page[:face].to_s) ? page[:face] : ""
    $game_message.face_index = page[:index]
    $game_message.background = page[:background]
    $game_message.position = page[:position]
    page[:lines].each { |line| $game_message.add(line) }
    @mirrored = { :page => page[:page], :since => Graphics.frame_count }
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

  # Shows the leader's messages once the player is free, and chests other members opened. Called
  # after the map's update.
  def self.update
    note_told_frame
    forget_former_leader
    show_heard
    take_held_chests
    tell_chest_news
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
  # gave nothing, as a locked chest an earlier build tells about; never in a Raid World, whose
  # chests are personal.
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
    MGQ_MpCoopEvents.mirroring? ? MGQ_MpCoopEvents.hold_page(window) : original.call
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
