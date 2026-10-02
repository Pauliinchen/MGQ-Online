#----------------------------------------------------------------
#  mp_coop_events.rbx
#
#  Changelog:
#      Paulinchen  2026-10-02: Sorted a common event once per depth, so one sorted deep down no longer counts as story when called higher up
#                            - Held event commands and followed the map's update through mp_hooks.rbx
#                            - Took whether the player plays in a party, and an event's page, from mp_coop.rbx
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
#      Paulinchen  2026-09-30: Sent and took the party's messages through mp_coop.rbx, which drops those of another party
#                            - Registered with mp_overworld_sync.rbx for its messages instead of being asked by mp_overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as mp_coop_events.rbx, which Multiplayer.rb loads
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
# not looted it yet gets the same items. A story scene the leader starts waits until every member
# stands near them, thirty seconds at most: members get five seconds to finish what they do, then
# are brought over once free, and stand still while the scene plays. It starts without those who
# did not come, who play on.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopEvents
  # Event commands that move the story on wherever they appear: party changes (129), vehicles (206),
  # name input (303), game over and title (353, 354).
  STORY_CODES = [129, 206, 303, 353, 354]

  # Scripts a talk may run: companions' own lines, choices, presents and affection, medals,
  # music, skill names on screen, and the menus of job change, synthesis, the casino and the party.
  TALK_SCRIPTS = /\A\s*(actor_label_jump|unlimited_choices|ex_choice_\w+|present_start|change_friend|gain_medal|gain_coin|play_base_bgm|clear_skill_name|display_skill_name|call_synthesize|call_slot_scene|start_poker|call_party_edit|SceneManager\.call\(Scene_JobChange\)|names = party_members)/

  # Scripts that travel.
  TRAVEL_SCRIPTS = /\A\s*(forced_transfer|forced_get_off_vehicle|forced_get_on_airship)/

  # Names of switches and variables the game uses as scratch while an event runs.
  TEMPORARY_NAMES = /general|temp|system only|汎用|一時/i

  # Event commands that show dialogue: text, choices, scrolling text.
  MESSAGE_CODES = [101, 102, 105]

  # Maps of the Pocket Castle, the home the party returns to, whose companions, merchants, inn and
  # maids each player talks to in their own game. The maps of the castle's side stories stay out.
  POCKET_CASTLE_MAPS = [227, 228, 229, 230] + (268..278).to_a

  # Common events of the Pocket Castle's services: Vanilla's shop (106), Papi's smithy (107), the
  # maids' party saves (111), the item storage (144) and Teeny's inn (270).
  CASTLE_SERVICES = [106, 107, 111, 144, 270]

  # Scripts of the Pocket Castle's coin shop, which lists its goods itself.
  CASTLE_SHOP_SCRIPTS = /\A\s*@goods\b/

  # A variable shown in a speaker's name, which a companion's name shows for their affection.
  SHOWN_VARIABLE = /\\V\[(\d+)\]/i

  # Messages of the leader's story kept at most while the player is busy.
  MAX_HEARD = 30

  # Pages of the leader's story a member's game remembers the leader moved past, at most.
  MAX_DONE = 64

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

  # Frames a member gets to finish what they do before a story scene brings them to the leader,
  # five seconds at 60 frames per second.
  GATHER_FRAMES = 300

  # Tiles a member may stand away from the leader, on the leader's map, to count as gathered.
  GATHER_TILES = 3

  # Frames between two calls of the members while the leader's story scene waits, three seconds.
  CALL_FRAMES = 180

  # Frames the leader's story scene waits for the party at most before it starts without the
  # members who did not come, thirty seconds.
  HOLD_FRAMES = 1800

  # Frames without a call after which a member's call lapses, two calls missed: the leader's story
  # started without them, or the leader left.
  CALL_LAPSE_FRAMES = CALL_FRAMES * 2

  @common_kinds = {}
  @chest = nil
  @granting = false
  @hold = nil
  @gather = nil

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Game_Interpreter.method_defined?(:mgq_mp_coop_events_setup)
  end

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("co-op events: #{message}")
  rescue
  end

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
  # Called common events count whole, since they hold most of the story.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Symbol] :talk, :travel, :chest, :battle or :story.
  def self.kind_of(list)
    return :talk if castle_resident?(list)

    list = runnable(list)
    # Wandering monsters call the game's common events before and after their battle, which set
    # variables, so a battle is told apart by the page itself: a fight without its own dialogue.
    return :battle if list.any? { |c| c.code == 301 } && list.none? { |c| MESSAGE_CODES.include?(c.code) }

    marks = marks_of(list, 0)
    return :story if marks[:story] || marks[:sets]
    return :chest if marks[:gives] && marks[:own_switch]
    return :story if marks[:own_switch] || marks[:battle]

    marks[:travel] ? :travel : :talk
  end

  # Reports whether a page on the Pocket Castle's maps is one of its residents: a companion, a
  # merchant, the inn or a maid, which each player talks to in their own game, whatever the talk
  # sets. The castle's story events show none of these, though they share the companions' scripts.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Boolean] Whether it is.
  def self.castle_resident?(list)
    return false unless $game_map && POCKET_CASTLE_MAPS.include?($game_map.map_id)

    companion_talk?(list) || list.any? do |c|
      (c.code == 117 && CASTLE_SERVICES.include?(c.parameters[0])) || (c.code == 355 && c.parameters[0].to_s =~ CASTLE_SHOP_SCRIPTS)
    end
  end

  # Reports whether a page is a companion's talk: its first speaker's name shows their affection.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Boolean] Whether it is.
  def self.companion_talk?(list)
    first = list.find { |c| c.code == 401 }
    return false unless first && defined?(MGQ_MpCoopStory)

    first.parameters[0].to_s.scan(SHOWN_VARIABLE).any? do |(id)|
      id.to_i >= MGQ_MpCoopStory::AFFECTION_VARIABLES && MGQ_MpCoopStory.personal_variable?(id.to_i)
    end
  end

  # Finds what a list of event commands does.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param depth [Integer] How many common events deep the list is.
  # @return [Hash] :story, :sets (a switch or variable of the story), :says (dialogue), :gives,
  #   :own_switch, :battle and :travel, each true when found.
  def self.marks_of(list, depth)
    marks = {}
    list.each_with_index do |command, index|
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
    marks
  end

  # Adds what a common event does, sorted once per common event and depth.
  #
  # The depth is part of the key, since a common event sorted deep down counts the events it calls
  # past MAX_DEPTH as story, which a call from higher up must not take over.
  #
  # @param id [Integer] The common event.
  # @param depth [Integer] How deep it is called.
  # @return [Hash] What it does, see marks_of; a common event too deep counts as story.
  def self.common_marks(id, depth)
    return { :story => true } if depth > MAX_DEPTH

    @common_kinds[[id, depth]] ||= begin
      common = $data_common_events[id]
      common ? marks_of(common.list || [], depth) : {}
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

  # Reports whether a variable is only scratch, or the player's own, such as affection.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it is.
  def self.temporary_variable?(id)
    $data_system.variables[id].to_s =~ TEMPORARY_NAMES || (defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.personal_variable?(id)) ? true : false
  end

  # Lists the self switches of the chests on the map.
  #
  # @return [Array<Array>] Their keys: map, event and letter.
  def self.chest_keys
    return @chest_keys if @chest_keys_map == $game_map.map_id

    @chest_keys_map = $game_map.map_id
    @chest_keys = $game_map.events.values.select { |event| kind(event) == :chest }.map { |event| chest_key(event) }.compact
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
  # @return [Array, nil] Its key, nil when the page sets none.
  def self.chest_key(event)
    command = (event.list || []).find { |c| c.code == 123 && c.parameters[1] == 0 }
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

    @hold = nil
    # A page of the leader's story that a scene change cut short must not hold the player's own.
    @mirrored = nil
    event = event_id > 0 ? $game_map.events[event_id] : nil
    @telling = leading? && (event ? kind(event) : kind_of(list || [])) == :story
    hold(interpreter) if @telling && scene?(list) && !gathered?
    @chest = event && kind(event) == :chest && MGQ_MpCoop.in_party? ? { :interpreter => interpreter, :key => chest_key(event), :gains => [] } : nil
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

  # Finds the leader of the player's party, through mp_coop.rbx.
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

  # As leader, holds a story scene until every member stands near: calls them now and every few
  # seconds while it waits.
  #
  # @param interpreter [Game_Interpreter] The map's interpreter, which waits at its first command.
  def self.hold(interpreter)
    @hold = { :interpreter => interpreter, :since => Graphics.frame_count, :called => Graphics.frame_count }
    gather
    MGQ_MpOverworldSync::Status.notice("Gathering the party for the story . . .")
  end

  # As leader, calls the party members to where the player stands.
  def self.gather
    tell(-1, "gather", place_fields)
  end

  # Reports whether the leader's story scene still waits for the party, calling the members again
  # every CALL_FRAMES, and starting it without those who did not come after HOLD_FRAMES. Asked
  # before each of the interpreter's commands.
  #
  # @param interpreter [Game_Interpreter] The interpreter about to run a command.
  # @return [Boolean] Whether it waits.
  def self.holding?(interpreter)
    return false unless @hold && @hold[:interpreter].equal?(interpreter)

    if !leading? || gathered?
      @hold = nil
      MGQ_MpOverworldSync::Status.notice("The party is here.") if leading?
      return false
    end

    if Graphics.frame_count - @hold[:since] >= HOLD_FRAMES
      @hold = nil
      MGQ_MpOverworldSync::Status.notice("The story starts without #{missing.join(', ')}.")
      return false
    end

    if Graphics.frame_count - @hold[:called] >= CALL_FRAMES
      @hold[:called] = Graphics.frame_count
      gather
    end
    true
  rescue => e
    @hold = nil
    log("holding the story failed: #{e.class}: #{e.message}")
    false
  end

  # Reports whether every party member stands near the player, on the player's map.
  #
  # @return [Boolean] Whether they do.
  def self.gathered?
    missing.empty?
  end

  # Names the party members who do not stand near the player yet.
  #
  # @return [Array<String>] Their names.
  def self.missing
    here = [$game_map.map_id, $game_player.x, $game_player.y]
    MGQ_MpCoop::Party.members.reject { |peer| near_place?(peer.state, here) }.map { |peer| peer.state["name"].to_s }
  end

  # Reports whether a player stands near a place.
  #
  # @param state [Hash] What the player last told, or the player's own "map", "x" and "y".
  # @param place [Array<Integer>] The place's map, x and y.
  # @return [Boolean] Whether they stand within GATHER_TILES of it.
  def self.near_place?(state, place)
    state["map"].to_i == place[0] && [(state["x"].to_i - place[1]).abs, (state["y"].to_i - place[2]).abs].max <= GATHER_TILES
  end

  # Reports whether the leader's story scene plays now, held no more, which keeps the members still.
  #
  # @return [Boolean] Whether it does.
  def self.story_playing?
    telling? && @hold.nil?
  end

  # The fields the party's events add to the state the player's game tells the others.
  #
  # @return [Hash] "telling": 1 while the player's story scene plays for the party.
  def self.state_fields
    { "telling" => story_playing? ? 1 : 0 }
  end

  # Takes the leader's call to their story scene: the player comes over in GATHER_FRAMES, unless
  # they stand near already.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param place [Array<Integer>] Where the leader stands: map, x, y and direction.
  def self.called(peer, place)
    mine = { "map" => $game_map.map_id, "x" => $game_player.x, "y" => $game_player.y }
    return @gather = nil if near_place?(mine, place)

    unless @gather
      MGQ_MpOverworldSync::Status.notice("#{peer.state['name']}'s story is starting. You join them in #{GATHER_FRAMES / 60} seconds.")
      @gather = { :since => Graphics.frame_count, :name => peer.state["name"].to_s }
    end
    @gather[:place] = place
    @gather[:called] = Graphics.frame_count
  end

  # Reports whether the leader's story scene is about to bring the player over, which keeps random
  # encounters and co-op battles away so no battle holds the player up.
  #
  # @return [Boolean] Whether it is.
  def self.coming?
    !@gather.nil? && Graphics.frame_count - @gather[:called] < CALL_LAPSE_FRAMES
  end

  # Tells where the player comes to for the leader's story scene, once its five seconds passed.
  #
  # @return [Array<Integer>, nil] The leader's map, x, y and direction, nil while none or not yet.
  def self.come?
    gather = pending_call
    gather && Graphics.frame_count - gather[:since] >= GATHER_FRAMES ? gather[:place] : nil
  end

  # The leader's call the player has yet to answer, forgetting it once the calls stopped.
  #
  # @return [Hash, nil] The call: :since, :name, :place and :called; nil for none.
  def self.pending_call
    return nil unless @gather
    return @gather if Graphics.frame_count - @gather[:called] < CALL_LAPSE_FRAMES

    MGQ_MpOverworldSync::Status.notice("#{@gather[:name]}'s story started without you.")
    @gather = nil
  end

  # Tells what the line above the player's own head says about the party's story, if anything:
  # the leader's wait, or a member's time left before coming over.
  #
  # @return [String, nil] The line.
  def self.own_line
    return "Gathering the party . . ." if @hold && leading?

    gather = pending_call
    return nil unless gather

    seconds = (GATHER_FRAMES - (Graphics.frame_count - gather[:since]) + 59) / 60
    seconds > 0 ? "Joining #{gather[:name]} in #{seconds} s . . ." : "Joining #{gather[:name]} once free . . ."
  end

  # Reports whether the player, a member, has to stand still: while their leader's story scene plays
  # on the player's map. A member it started without plays on elsewhere.
  #
  # @return [Boolean] Whether they do.
  def self.blocked?
    lead = leader
    lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && lead.state["telling"] == "1" && lead.state["map"].to_i == $game_map.map_id
  end

  # Writes where the player stands.
  #
  # @return [Hash] "map", "x", "y" and "d".
  def self.place_fields
    { "map" => $game_map.map_id, "x" => $game_player.x, "y" => $game_player.y, "d" => $game_player.direction }
  end

  # Takes a message about the party's events from another member.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take_party(peer, message)
    return take_request(peer, message) if message["pevent"] == "run"
    return unless leader.equal?(peer)

    place = [message["map"].to_i, message["x"].to_i, message["y"].to_i, message["d"].to_i]
    case message["pevent"]
    when "gather" then called(peer, place)
    when "say" then hear(peer, message) if place[0] == $game_map.map_id
    when "done" then heard_done(message)
    end
  rescue => e
    log("taking #{message['pevent']} failed: #{e.class}: #{e.message}")
  end

  # Hands a story event the player started to the leader, whose game plays the story. Called
  # when the map's main event would start it.
  #
  # An event that runs by itself is left to the leader's own game, which runs it on its map.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it was handed over, so it must not run here.
  def self.hand_over(event)
    lead = leader
    return false unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && kind(event) == :story
    return true if event.trigger == 3

    if lead.state["map"].to_i == $game_map.map_id
      tell(lead.seat, "run", "map" => $game_map.map_id, "event" => event.id)
      MGQ_MpOverworldSync::Status.notice("The story goes on in #{lead.state['name']}'s game.")
    else
      MGQ_MpOverworldSync::Status.notice("#{lead.state['name']} leads the party's story. Bring them here to go on.")
    end
    true
  rescue => e
    log("handing over an event failed: #{e.class}: #{e.message}")
    false
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

  # As leader, takes a member's request to play a story event on the leader's map.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The message's fields: "map" and "event".
  def self.take_request(peer, message)
    return unless leader == :me && MGQ_MpCoop::Party.member?(peer.state) && message["map"].to_i == $game_map.map_id

    @requests ||= []
    id = message["event"].to_i
    @requests << id unless @requests.include?(id)
  end

  # As leader, starts the next event a member asked for, once the player is free.
  def self.start_requested
    return if @requests.nil? || @requests.empty? || !free?

    event = $game_map.events[@requests.shift]
    event.start if event && kind(event) == :story
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
    fields = place_fields.merge(
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
    tell(-1, "done", place_fields.merge("page" => page_id))
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
    return if @heard.nil? || @heard.empty? || !free?
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

  # Moves the player to the leader once a story scene's five seconds passed, once the player is
  # free: on the map, with no event, message, transfer or battle of their own in the way. As
  # leader, starts the story events members asked for. Shows the leader's messages. Called after
  # the map's update.
  def self.update
    start_requested
    show_heard
    place = come?
    return unless place && free?

    map_id, x, y, direction = place
    @gather = nil
    return unless MGQ_MpCoop.in_party?

    if map_id == $game_map.map_id
      $game_player.moveto(x, y)
      $game_player.set_direction(direction) if direction > 0
    else
      $game_player.reserve_transfer(map_id, x, y, direction > 0 ? direction : 2)
    end
  rescue => e
    log("coming to the leader failed: #{e.class}: #{e.message}")
  end

  # Reports whether the player is free to be moved: on the map, with no event, message or transfer
  # of their own in the way.
  #
  # @return [Boolean] Whether they are.
  def self.free?
    SceneManager.scene.is_a?(Scene_Map) && !$game_map.interpreter.running? && !$game_message.busy? && !$game_player.transfer?
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

  # Keeps an item a chest gives.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @param amount [Integer] How many.
  def self.gained_item(item, amount)
    kind = ITEM_CLASSES.keys.find { |letter| item.is_a?(ITEM_CLASSES[letter]) }
    gained(kind, item.id, amount) if kind
  rescue => e
    log("keeping an item failed: #{e.class}: #{e.message}")
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

  # Takes a message about chests or the party's events. Called by mp_coop.rbx.
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
    MGQ_MpOverworldSync::Status.notice(text)
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

# What this script takes part in of the party's messages, through mp_coop.rbx.

begin
  MGQ_MpCoop.route("chest") { |peer, message| MGQ_MpCoopEvents.take(peer, message) }
  MGQ_MpCoop.route("pevent") { |peer, message| MGQ_MpCoopEvents.take(peer, message) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoopEvents.state_fields }
rescue => e
  MGQ_MpCoopEvents.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through mp_hooks.rbx.

begin
  # Before an event command runs, its interpreter waits while the leader's story scene waits for
  # the party.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "mp_coop_events") do
    begin
      Fiber.yield while MGQ_MpCoopEvents.holding?(self)
    rescue FiberError
      # An interpreter run outside a fiber cannot wait, so its command runs at once.
    end
  end

  # After the map's update, the player is brought to the leader's story scene when they are free.
  MGQ_MpHooks.after(Game_Map, :update, "mp_coop_events") { MGQ_MpCoopEvents.update }
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

      # Starts the event that is starting, unless it is story the leader's game plays. The original
      # does not run then.
      #
      # @return [Game_Event, nil] The event started.
      def setup_starting_map_event
        event = @events.values.find { |e| e.starting }
        if event && MGQ_MpCoopEvents.hand_over(event)
          event.clear_starting_flag
          event.unlock
          return nil
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
    class Game_Player
      alias mgq_mp_coop_events_movable? movable?

      # Reports whether the player may move: not while their leader's story scene plays.
      #
      # @return [Boolean] Whether they may.
      def movable?
        mgq_mp_coop_events_movable? && !(MGQ_MpCoopEvents.blocked? rescue false)
      end

      alias mgq_mp_coop_events_encounter encounter

      # Starts a random encounter when its steps ran out, but not while the leader's story scene is
      # about to bring the player over.
      #
      # @return [Boolean] Whether a battle starts.
      def encounter
        return mgq_mp_coop_events_encounter unless (MGQ_MpCoopEvents.coming? rescue false)

        # Steps that ran out while called would start a battle the moment the player arrives.
        make_encounter_count if @encounter_count <= 0
        false
      end
    end

    class Scene_Map
      alias mgq_mp_coop_events_update_call_menu update_call_menu

      # Opens the menu when asked, but not while the leader's story scene plays.
      def update_call_menu
        return @menu_calling = false if (MGQ_MpCoopEvents.blocked? rescue false)

        mgq_mp_coop_events_update_call_menu
      end
    end
  rescue => e
    MGQ_MpCoopEvents.log("story block hooks FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Game_Party
      alias mgq_mp_coop_events_gain_item gain_item
      alias mgq_mp_coop_events_gain_gold gain_gold

      # Gives an item, keeping it for the party when a chest gives it.
      #
      # The game gives an enchanted item by calling this again for each copy it makes, so only the
      # outermost call counts.
      #
      # @param item [RPG::BaseItem] The item.
      # @param amount [Integer] How many.
      # @param rest [Array] The original's other arguments.
      def gain_item(item, amount, *rest)
        outermost = MGQ_MpCoopEvents.enter_gain
        begin
          mgq_mp_coop_events_gain_item(item, amount, *rest)
        ensure
          MGQ_MpCoopEvents.leave_gain
        end
        MGQ_MpCoopEvents.gained_item(item, amount) if outermost
      end

      # Gives gold, keeping it for the party when a chest gives it.
      #
      # @param amount [Integer] How much.
      def gain_gold(amount)
        mgq_mp_coop_events_gain_gold(amount)
        MGQ_MpCoopEvents.gained("g", 0, amount)
      end
    end
  rescue => e
    MGQ_MpCoopEvents.log("party hooks FAILED: #{e.class}: #{e.message}")
  end
end
