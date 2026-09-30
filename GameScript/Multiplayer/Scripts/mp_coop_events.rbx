#----------------------------------------------------------------
#  mp_coop_events.rbx
#
#  Changelog:
#      Paulinchen  2026-09-30: Sent and took the party's messages through mp_coop.rbx, which drops those of another party
#                            - Registered with mp_overworld_sync.rbx for its messages instead of being asked by mp_overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as mp_coop_events.rbx, which Multiplayer.rb loads
#                            - Renamed from mp_events.rbx, with the module MGQ_MpCoopEvents
#                            - Played a party's story events in the leader's game and showed its messages to the members
#                            - Took the party along where the leader goes, and gathered it for story scenes
#                            - Created
#
#----------------------------------------------------------------

# The events of a party. Every event page is sorted by what its commands do, before it ever runs:
# a talk (conversations, shops, the job change menu), travel (a transfer), a chest (items and its
# own self switch), a battle without dialogue, or story (everything that moves the story on).
# Chests are the player's own, and opening one opens it for the whole party: every member who has
# not looted it yet gets the same items.
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

  # Messages of the leader's story kept at most while the player is busy.
  MAX_HEARD = 30

  # How deep called common events are followed.
  MAX_DEPTH = 5

  # The kinds of item a chest gives, by the letter a message writes them with.
  ITEM_KINDS = ["i", "w", "a"]

  # The class of each kind of item.
  ITEM_CLASSES = { "i" => RPG::Item, "w" => RPG::Weapon, "a" => RPG::Armor }

  @kinds = {}
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

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("co-op events: #{message}")
  rescue
  end

  # Reports whether the player is in a party of an open world.
  #
  # @return [Boolean] Whether they are.
  def self.in_party?
    defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.in_world? && defined?(MGQ_MpCoop) && !MGQ_MpCoop::Party.id.nil?
  end

  # Sorts an event's current page.
  #
  # @param event [Game_Event] The event.
  # @return [Symbol] :talk, :travel, :chest, :battle or :story; :talk for an event without a page.
  def self.kind(event)
    page = event.mgq_mp_coop_events_page
    return :talk if page < 0

    @kinds[[$game_map.map_id, event.id, page]] ||= kind_of(event.list || [])
  end

  # Sorts a list of event commands.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Symbol] :talk, :travel, :chest, :battle or :story.
  def self.kind_of(list)
    # Wandering monsters call the game's common events before and after their battle, which set
    # variables, so a battle is told apart by the page itself: a fight without its own dialogue.
    return :battle if list.any? { |c| c.code == 301 } && list.none? { |c| MESSAGE_CODES.include?(c.code) }

    marks = marks_of(list, 0)
    return :story if marks[:story]
    return :chest if marks[:gives] && marks[:own_switch]
    return :story if marks[:own_switch] || marks[:battle]

    marks[:travel] ? :travel : :talk
  end

  # Finds what a list of event commands does.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param depth [Integer] How many common events deep the list is.
  # @return [Hash] :story, :gives, :own_switch, :battle and :travel, each true when found.
  def self.marks_of(list, depth)
    marks = {}
    list.each_with_index do |command, index|
      params = command.parameters
      case command.code
      when 121 then marks[:story] ||= !(params[0]..params[1]).all? { |id| temporary_switch?(id) }
      when 122 then marks[:story] ||= !(params[0]..params[1]).all? { |id| temporary_variable?(id) }
      when 123 then marks[:own_switch] = true
      when 125, 126, 127, 128 then marks[:gives] = true
      when 201 then marks[:travel] = true
      when 301 then marks[:battle] = true
      when 355 then mark_script(marks, script_at(list, index))
      when 117 then merge(marks, common_marks(params[0], depth + 1))
      else marks[:story] = true if STORY_CODES.include?(command.code)
      end
    end
    marks
  end

  # Adds what a common event does, sorted once per common event.
  #
  # @param id [Integer] The common event.
  # @param depth [Integer] How deep it is called.
  # @return [Hash] What it does, see marks_of; a common event too deep counts as story.
  def self.common_marks(id, depth)
    return { :story => true } if depth > MAX_DEPTH

    @common_kinds[id] ||= begin
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

    @telling = leading? && kind_of(list || []) == :story
    gather if @telling && scene?(list)
    event = event_id > 0 ? $game_map.events[event_id] : nil
    @chest = event && kind(event) == :chest && in_party? ? { :interpreter => interpreter, :key => chest_key(event), :gains => [] } : nil
  end

  # Reports whether a list of commands is a story scene: story with its own dialogue or novel scene.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Boolean] Whether it is.
  def self.scene?(list)
    return false unless list

    list.any? { |c| MESSAGE_CODES.include?(c.code) || (c.code == 355 && c.parameters[0].to_s =~ /\A\s*call_novel_scene/) } && kind_of(list) == :story
  end

  # Reports whether the leader's main event plays story now, whose companions join the members too.
  #
  # @return [Boolean] Whether it does.
  def self.telling?
    @telling && $game_map && $game_map.interpreter.running? ? true : false
  end

  # Finds the leader of the player's party, through mp_actions.rbx.
  #
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil outside a party.
  def self.leader
    in_party? ? MGQ_MpCoop::Party.leader : nil
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

  # As leader, brings the party members on the map to where the player stands.
  def self.gather
    tell(-1, "gather", place_fields)
  end

  # As leader, takes the party along to where the player was just transferred. Called after a transfer.
  def self.transferred
    tell(-1, "travel", place_fields) if leading?
  rescue => e
    log("telling a transfer failed: #{e.class}: #{e.message}")
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
    when "travel" then @travel = place
    when "gather" then @gather = place if place[0] == $game_map.map_id
    when "say" then hear(peer, message) if place[0] == $game_map.map_id
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
    fields = place_fields.merge(
      "face" => message.face_name.to_s, "index" => message.face_index.to_i,
      "background" => message.background.to_i, "position" => message.position.to_i,
      "lines" => page[0].map { |line| [line.to_s].pack('m0') }.join(","),
      "choices" => page[1].map { |choice| [choice.to_s].pack('m0') }.join(","))
    tell(-1, "say", fields)
  rescue => e
    log("telling a message failed: #{e.class}: #{e.message}")
  end

  # Keeps a message of the leader's story to show once the player is free.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param message [Hash] The message's fields.
  def self.hear(peer, message)
    @heard ||= []
    lines = message["lines"].to_s.split(",").map { |line| decode(line) }
    choices = message["choices"].to_s.split(",").map { |choice| decode(choice) }
    @heard << [message["face"].to_s, message["index"].to_i, message["background"].to_i, message["position"].to_i, lines] unless lines.empty?
    @heard << ["", 0, message["background"].to_i, message["position"].to_i, ["#{peer.state['name']} chooses:"] + choices.first(3)] unless choices.empty?
    @heard.shift while @heard.size > MAX_HEARD
  end

  # Reads a line written for a message.
  #
  # @param text [String] The line, Base64.
  # @return [String] The line.
  def self.decode(text)
    text.unpack('m0')[0].to_s.force_encoding("UTF-8")
  end

  # Shows the next message of the leader's story, once the player is free.
  def self.show_heard
    return if @heard.nil? || @heard.empty? || !free?

    face, index, background, position, lines = @heard.shift
    $game_message.face_name = face
    $game_message.face_index = index
    $game_message.background = background
    $game_message.position = position
    lines.each { |line| $game_message.add(line) }
  end

  # Moves the player where the leader went or gathers the party, once the player is free: on the
  # map, with no event, message or transfer of their own in the way. As leader, starts the story
  # events members asked for. Shows the leader's messages. Called after the map's update.
  def self.update
    start_requested
    show_heard
    return unless @travel || @gather
    return unless free?

    map_id, x, y, direction = @gather || @travel
    @travel = @gather = nil
    return unless in_party?

    if map_id == $game_map.map_id
      $game_player.moveto(x, y)
      $game_player.set_direction(direction) if direction > 0
    else
      $game_player.reserve_transfer(map_id, x, y, direction > 0 ? direction : 2)
    end
  rescue => e
    log("following the leader failed: #{e.class}: #{e.message}")
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
    kind = ITEM_KINDS.find { |letter| item.is_a?(ITEM_CLASSES[letter]) }
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
    return unless chest[:key] && in_party?

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
rescue => e
  MGQ_MpCoopEvents.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpCoopEvents.hookable?
  begin
    class Game_Event
      # Tells which page the event shows.
      #
      # @return [Integer] The page's index, -1 for none.
      def mgq_mp_coop_events_page
        @page ? @event.pages.index(@page).to_i : -1
      end
    end

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
    class Game_Player
      alias mgq_mp_coop_events_perform_transfer perform_transfer

      # Carries out a reserved transfer, then as leader takes the party along.
      def perform_transfer
        moving = transfer?
        mgq_mp_coop_events_perform_transfer
        MGQ_MpCoopEvents.transferred if moving
      end
    end

    class Game_Map
      alias mgq_mp_coop_events_update update

      # Updates the map, then moves the player after the leader when they are free.
      #
      # @param args [Array] The original's arguments.
      def update(*args)
        mgq_mp_coop_events_update(*args)
        MGQ_MpCoopEvents.update
      end
    end
  rescue => e
    MGQ_MpCoopEvents.log("travel hooks FAILED: #{e.class}: #{e.message}")
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
