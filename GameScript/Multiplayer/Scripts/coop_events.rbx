#----------------------------------------------------------------
#  coop_events.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Kept a member's story events from starting anywhere, since only the leader starts story, and no longer asked the leader's game to play them
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
# not looted it yet gets the same items. A story scene the leader starts first gathers the party,
# see coop_gather.rbx; the Pocket Castle's residents are sorted by coop_castle.rbx.
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

  # Variables that note where the Pocket Castle item was used: the map (21), x (22) and y (23),
  # which the way out of the castle returns to. They tell of a place, not of the story.
  PLACE_VARIABLES = [21, 22, 23]

  # Event commands that show dialogue: text, choices, scrolling text.
  MESSAGE_CODES = [101, 102, 105]

  # Messages of the leader's story kept at most while the player is busy.
  MAX_HEARD = 30

  # Pages of the leader's story a member's game remembers the leader moved past, at most.
  MAX_DONE = 64

  # Frames in which a member hears only once that a story event they started is the leader's,
  # three seconds.
  REFUSE_FRAMES = 180

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

  # Messages about gathering for story scenes, which coop_gather.rbx takes.
  GATHER_MESSAGES = %w(gather come where)

  @common_kinds = {}
  @chest = nil
  @granting = false

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Game_Interpreter.method_defined?(:mgq_mp_coop_events_setup)
  end

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
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

    $data_system.switches[id].to_s =~ TEMPORARY_NAMES || (defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.personal_switch?(id)) ? true : false
  end

  # Reports whether a variable is only scratch, notes a place, or is the player's own, such as affection.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it is.
  def self.temporary_variable?(id)
    return true if PLACE_VARIABLES.include?(id)

    $data_system.variables[id].to_s =~ TEMPORARY_NAMES || (defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.personal_variable?(id)) ? true : false
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
    # A page of the leader's story that a scene change cut short must not hold the player's own.
    @mirrored = nil
    event = event_id > 0 ? $game_map.events[event_id] : nil
    sorted = event ? kind(event) : kind_of(list || [])
    @telling = leading? && sorted == :story
    @may_tell = sorted == :talk && MGQ_MpCoop.in_party? && may_tell?(list || [])
    MGQ_MpCoopGather.hold(interpreter) if @telling && scene?(list) && !MGQ_MpCoopGather.gathered?
    @chest = event && sorted == :chest && MGQ_MpCoop.in_party? ? { :interpreter => interpreter, :key => chest_key(event), :gains => [] } : nil
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
    lead = leader
    if lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)
      # The list ends with an empty command, which ends the event as its last.
      MGQ_MpGame.set(interpreter, :index, list.size - 1)
      MGQ_MpOverworldSync.notice("Only #{lead.state['name']} can move the story on.")
      log("ended a talk where it would move the story on (command #{list[index].code})")
    elsif leading?
      @telling = true
      log("a talk moves the story on (command #{list[index].code}), the party hears it from here")
    end
  rescue => e
    @may_tell = false
    log("watching a talk failed: #{e.class}: #{e.message}")
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

  # Finds the leader of the player's party, through coop.rbx.
  #
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil outside a party.
  def self.leader
    MGQ_MpCoop.in_party? ? MGQ_MpCoop::Party.leader : nil
  end

  # Reports whether the player leads a party with other members in it.
  #
  # @return [Boolean] Whether they do.
  def self.leading?
    leader == :me && !MGQ_MpCoop::Party.members.empty?
  end

  # Sends the party a message about events.
  #
  # @param seat [Integer] A member's seat, -1 for everyone, who ignore it outside the party.
  # @param kind [String] What it is about.
  # @param fields [Hash] Its other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, fields = {})
    MGQ_MpCoop.tell(seat, "pevent", kind, fields)
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

  # Takes a message about the party's events from another member.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take_party(peer, message)
    return MGQ_MpCoopGather.take(peer, message) if GATHER_MESSAGES.include?(message["pevent"])
    return unless leader.equal?(peer)

    case message["pevent"]
    when "say" then hear(peer, message) if message["map"].to_i == $game_map.map_id
    when "done" then heard_done(message)
    end
  rescue => e
    log("taking #{message['pevent']} failed: #{e.class}: #{e.message}")
  end

  # Keeps a member's story event from starting: only the leader starts story, in their own game.
  # Called when the map's main event would start it.
  #
  # An event that runs by itself is left to the leader's own game, which runs it on its map.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it is the leader's, so it must not run here.
  def self.hand_over(event)
    lead = leader
    return false unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && kind(event) == :story
    return true if event.trigger == 3

    refuse_story(event, lead)
    true
  rescue => e
    log("keeping a story event from starting failed: #{e.class}: #{e.message}")
    false
  end

  # Tells the member that only the leader moves the story on, once per event in REFUSE_FRAMES,
  # since an event the player stands on starts again with every step.
  #
  # @param event [Game_Event] The story event.
  # @param lead [MGQ_MpOverworldSync::Peers::Peer] The leader.
  def self.refuse_story(event, lead)
    key = [$game_map.map_id, event.id]
    return if @refused == key && Graphics.frame_count - @refused_at < REFUSE_FRAMES

    @refused = key
    @refused_at = Graphics.frame_count
    away = lead.state["map"].to_i == $game_map.map_id ? "" : " Bring them here to go on."
    MGQ_MpOverworldSync.notice("Only #{lead.state['name']} can move the story on.#{away}")
  end

  # Reports whether a common event that runs by itself is left to the leader's game.
  #
  # @param common [RPG::CommonEvent] The common event.
  # @return [Boolean] Whether it is.
  def self.leave_to_leader?(common)
    leader.is_a?(MGQ_MpOverworldSync::Peers::Peer) && kind_of(common.list || []) == :story
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
    tell(-1, "say", fields)
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
    tell(-1, "done", MGQ_MpCoopGather.place_fields.merge("page" => page_id))
  rescue => e
    log("telling a message's end failed: #{e.class}: #{e.message}")
  end

  # Names the page the leader's story shows now, unique beyond this session, so a member's game
  # never takes a page of an earlier session for one already done.
  #
  # @return [String] The page's id.
  def self.page_id
    @session ||= rand(36**6).to_s(36)
    "#{@session}.#{@page}"
  end

  # Keeps a message of the leader's story to show once the player is free.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param message [Hash] The message's fields.
  def self.hear(peer, message)
    @heard ||= []
    lines = message["lines"].to_s.split(",").map { |line| decode(line) }
    choices = message["choices"].to_s.split(",").map { |choice| decode(choice) }
    lines += ["#{peer.state['name']} chooses: #{choices.join(' / ')}"] unless choices.empty?
    return if lines.empty?

    @heard << { :page => message["page"].to_s, :face => message["face"].to_s, :index => message["index"].to_i,
                :background => message["background"].to_i, :position => message["position"].to_i, :lines => lines }
    @heard.shift while @heard.size > MAX_HEARD
  end

  # Notes that the leader moved past a page of their story.
  #
  # @param message [Hash] The message's fields, the page's id under "page".
  def self.heard_done(message)
    (@done ||= []).push(message["page"].to_s)
    @done.shift while @done.size > MAX_DONE
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

  # Reports whether the page of the leader's story the window shows is over: the leader moved past
  # it, is no longer the player's leader, or stopped telling the story a while ago.
  #
  # The leader's state and their pages travel apart, so a page may arrive before the state that
  # says the story plays.
  #
  # @return [Boolean] Whether it is over.
  def self.page_done?
    return true unless @mirrored
    return true if done?(@mirrored[:page])

    lead = leader
    return true unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)

    lead.state["telling"] != "1" && Graphics.frame_count - @mirrored[:since] >= STALE_FRAMES
  end

  # Notes that the window finished the page of the leader's story.
  def self.page_ended
    @mirrored = nil
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
    return @heard.clear unless MGQ_MpCoop.in_party?

    @heard.shift while !@heard.empty? && done?(@heard.first[:page])
    return if @heard.empty?

    page = @heard.shift
    $game_message.face_name = page[:face]
    $game_message.face_index = page[:index]
    $game_message.background = page[:background]
    $game_message.position = page[:position]
    page[:lines].each { |line| $game_message.add(line) }
    @mirrored = { :page => page[:page], :since => Graphics.frame_count }
  end

  # Shows the leader's messages once the player is free. Called after the map's update.
  def self.update
    show_heard
  rescue => e
    log("updating the party's events failed: #{e.class}: #{e.message}")
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

  # Keeps an item or gold a chest gives.
  #
  # @param kind [String] "i", "w", "a", or "g" for gold.
  # @param id [Integer] The item, 0 for gold.
  # @param amount [Integer] How many.
  def self.gained(kind, id, amount)
    @chest[:gains] << [kind, id, amount] if @chest && !@granting && amount > 0
  end

  # Tells the party about a chest the player opened, once its event ended.
  #
  # @param interpreter [Game_Interpreter] The interpreter that ended.
  def self.finished(interpreter)
    return unless @chest && @chest[:interpreter].equal?(interpreter)

    chest = @chest
    @chest = nil
    return unless chest[:key] && MGQ_MpCoop.in_party?

    MGQ_MpCoopStory.keep_own_self_switch(chest[:key], true) if defined?(MGQ_MpCoopStory)
    gains = chest[:gains].map { |kind, id, amount| "#{kind}#{id}x#{amount}" }.join(",")
    MGQ_MpCoop.tell(-1, "chest", chest[:key].join("."), "gains" => gains)
  rescue => e
    log("telling a chest failed: #{e.class}: #{e.message}")
  end

  # Takes a message about chests or the party's events. Called by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    message["chest"] ? take_chest(peer, message) : take_party(peer, message)
  end

  # Takes a chest another member opened: gives its items, unless the player looted it already.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who opened it.
  # @param message [Hash] The message's fields.
  def self.take_chest(peer, message)
    return unless MGQ_MpCoop::Party.member?(peer.state)

    map_id, event_id, letter = message["chest"].to_s.split(".")
    key = [map_id.to_i, event_id.to_i, letter]
    return if own_self_switch(key)

    names = grant(message["gains"].to_s)
    MGQ_MpCoopStory.keep_own_self_switch(key, true) if defined?(MGQ_MpCoopStory)
    text = names.empty? ? "#{peer.state['name']} opened a chest for the party." : "#{peer.state['name']} opened a chest for the party: #{names.join(', ')}."
    MGQ_MpOverworldSync.notice(text)
  rescue => e
    log("taking a chest failed: #{e.class}: #{e.message}")
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
    @granting = true
    gains.split(",").map do |entry|
      next unless entry =~ /\A([iwag])(\d+)x(\d+)\z/

      kind, id, amount = Regexp.last_match(1), Regexp.last_match(2).to_i, Regexp.last_match(3).to_i
      if kind == "g"
        $game_party.gain_gold(amount)
        "#{amount} #{Vocab.currency_unit}"
      else
        item = { "i" => $data_items, "w" => $data_weapons, "a" => $data_armors }[kind][id]
        next unless item

        $game_party.gain_item(item, amount)
        amount > 1 ? "#{item.name} x#{amount}" : item.name
      end
    end.compact
  ensure
    @granting = false
  end
end

# What this script takes part in of the party's messages, through coop.rbx.

begin
  MGQ_MpCoop.route("chest") { |peer, message| MGQ_MpCoopEvents.take(peer, message) }
  MGQ_MpCoop.route("pevent") { |peer, message| MGQ_MpCoopEvents.take(peer, message) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoopEvents.state_fields }
rescue => e
  MGQ_MpCoopEvents.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the leader's story pages show once the player is free.
  MGQ_MpHooks.after(Game_Map, :update, "coop_events") { MGQ_MpCoopEvents.update }

  # Before an event command runs, a talk that may turn into story is watched.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "coop_events") { MGQ_MpCoopEvents.guard(self) }
rescue => e
  MGQ_MpCoopEvents.log("hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpCoopEvents.hookable?
  begin
    class Game_Interpreter
      alias mgq_mp_coop_events_setup setup
      alias mgq_mp_coop_events_run run

      # Sets up a list of commands, noticing a chest the map's main event opens.
      #
      # @param list [Array<RPG::EventCommand>] The commands.
      # @param event_id [Integer] The event, 0 for none.
      def setup(list, event_id = 0)
        mgq_mp_coop_events_setup(list, event_id)
        MGQ_MpCoopEvents.started(self, list, event_id) rescue nil
      end

      # Runs the commands, then tells the party about a chest they opened.
      def run
        mgq_mp_coop_events_run
        MGQ_MpCoopEvents.finished(self) rescue nil
      end

      alias mgq_mp_coop_events_wait_for_message wait_for_message

      # Tells the party members the message the leader's story shows, then waits for it.
      #
      # The Yanfly plugin, which loads after the Patch folder, writes its own command_101, so the
      # message is caught here, where every message waits once its text is set.
      def wait_for_message
        MGQ_MpCoopEvents.show(self)
        mgq_mp_coop_events_wait_for_message
        MGQ_MpCoopEvents.shown(self)
      end
    end

    class Game_Map
      alias mgq_mp_coop_events_setup_starting_map_event setup_starting_map_event
      alias mgq_mp_coop_events_setup_autorun_common_event setup_autorun_common_event

      # Starts the event that is starting, leaving out every one that is story the leader's game
      # plays.
      #
      # @return [Game_Event, nil] The event started.
      def setup_starting_map_event
        @events.values.each do |event|
          next unless event.starting && MGQ_MpCoopEvents.hand_over(event)

          event.clear_starting_flag
          event.unlock
        end
        mgq_mp_coop_events_setup_starting_map_event
      end

      # Starts a common event that runs by itself, unless it is story the leader's game plays. The
      # original does not run then.
      #
      # @return [RPG::CommonEvent, nil] The common event started.
      def setup_autorun_common_event
        common = $data_common_events.find { |c| c && c.autorun? && $game_switches[c.switch_id] }
        return nil if common && MGQ_MpCoopEvents.leave_to_leader?(common)

        mgq_mp_coop_events_setup_autorun_common_event
      end
    end
  rescue => e
    MGQ_MpCoopEvents.log("interpreter hooks FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Window_Message
      alias mgq_mp_coop_events_process_input process_input
      alias mgq_mp_coop_events_input_pause input_pause

      # Waits for the input that ends a page, noting that its pause is the page's end.
      def process_input
        @mgq_mp_coop_events_page_end = true
        mgq_mp_coop_events_process_input
      ensure
        @mgq_mp_coop_events_page_end = false
      end

      # Waits for the player to move the message on, but on a page of the leader's story for the
      # leader instead: the player can neither move it on nor close it, nor skip it with the
      # game's skip key. A page too long for the window shows its rest after OVERFLOW_FRAMES.
      def input_pause
        return mgq_mp_coop_events_input_pause unless MGQ_MpCoopEvents.mirroring?

        page_end = @mgq_mp_coop_events_page_end
        self.pause = true
        frames = 0
        until MGQ_MpCoopEvents.page_done? || (!page_end && frames >= MGQ_MpCoopEvents::OVERFLOW_FRAMES)
          Fiber.yield
          frames += 1
        end
        self.pause = false
        MGQ_MpCoopEvents.page_ended if page_end
      end
    end
  rescue => e
    MGQ_MpCoopEvents.log("message hooks FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Game_Party
      alias mgq_mp_coop_events_gain_item gain_item
      alias mgq_mp_coop_events_gain_gold gain_gold

      # Gives an item, keeping it for the party when a chest or the leader's story gives it.
      #
      # The game gives an enchanted item by calling this again for each copy it makes, so only the
      # outermost call counts.
      #
      # @param item [RPG::BaseItem] The item.
      # @param amount [Integer] How many.
      # @param rest [Array] The original's other arguments: include_equip, and keep_flag, set when
      #   the item only moves to or from the item storage.
      def gain_item(item, amount, *rest)
        outermost = MGQ_MpCoopEvents.enter_gain
        begin
          mgq_mp_coop_events_gain_item(item, amount, *rest)
        ensure
          MGQ_MpCoopEvents.leave_gain
        end
        MGQ_MpCoopEvents.gained_item(item, amount, rest[1] ? true : false) if outermost
      end

      # Gives gold, keeping it for the party when a chest or the leader's story gives it.
      #
      # @param amount [Integer] How much.
      def gain_gold(amount)
        mgq_mp_coop_events_gain_gold(amount)
        MGQ_MpCoopEvents.gained_gold(amount)
      end
    end
  rescue => e
    MGQ_MpCoopEvents.log("party hooks FAILED: #{e.class}: #{e.message}")
  end
end
