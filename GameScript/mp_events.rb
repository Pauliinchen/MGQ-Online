#----------------------------------------------------------------
#  mp_events.rb
#
#  Changelog:
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# The events of a party. Every event page is sorted by what its commands do, before it ever runs:
# a talk (conversations, shops, the job change menu), travel (a transfer), a chest (items and its
# own self switch), a battle without dialogue, or story (everything that moves the story on).
# Chests are the player's own, and opening one opens it for the whole party: every member who has
# not looted it yet gets the same items.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpEvents
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
    !Game_Interpreter.method_defined?(:mgq_mp_events_setup)
  end

  # Writes a line to the Multiplayer mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("events: #{message}")
  rescue
  end

  # Reports whether the player is in a party of an open world.
  #
  # @return [Boolean] Whether they are.
  def self.in_party?
    defined?(MGQ_MpOverworld) && MGQ_MpOverworld.in_world? && defined?(MGQ_MpActions) && !MGQ_MpActions::Party.id.nil?
  end

  # Sorts an event's current page.
  #
  # @param event [Game_Event] The event.
  # @return [Symbol] :talk, :travel, :chest, :battle or :story; :talk for an event without a page.
  def self.kind(event)
    page = event.mgq_mp_events_page
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

    $data_system.switches[id].to_s =~ TEMPORARY_NAMES || (defined?(MGQ_MpStory) && MGQ_MpStory.personal_switch?(id)) ? true : false
  end

  # Reports whether a variable is only scratch, or the player's own, such as affection.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it is.
  def self.temporary_variable?(id)
    $data_system.variables[id].to_s =~ TEMPORARY_NAMES || (defined?(MGQ_MpStory) && MGQ_MpStory.personal_variable?(id)) ? true : false
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

  # Notices the map's main event starting, and keeps track of a chest's items.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @param event_id [Integer] The event, 0 for a common event.
  def self.started(interpreter, event_id)
    return unless interpreter.equal?($game_map.interpreter) && event_id > 0

    event = $game_map.events[event_id]
    @chest = event && kind(event) == :chest && in_party? ? { :interpreter => interpreter, :key => chest_key(event), :gains => [] } : nil
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

    MGQ_MpStory.keep_own_self_switch(chest[:key], true) if defined?(MGQ_MpStory)
    gains = chest[:gains].map { |kind, id, amount| "#{kind}#{id}x#{amount}" }.join(",")
    fields = { "chest" => chest[:key].join("."), "party" => MGQ_MpActions::Party.id, "gains" => gains }
    MGQ_MpOverworld::Link.send_to(-1, MGQ_MpOverworld::Me.encode(fields))
  rescue => e
    log("telling a chest failed: #{e.class}: #{e.message}")
  end

  # Takes a chest another member opened: gives its items, unless the player looted it already.
  # Called by mp_overworld.rb.
  #
  # @param peer [MGQ_MpOverworld::Peers::Peer, nil] Who opened it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    return unless peer && in_party? && message["party"] == MGQ_MpActions::Party.id && MGQ_MpActions::Party.member?(peer.state)

    map_id, event_id, letter = message["chest"].to_s.split(".")
    key = [map_id.to_i, event_id.to_i, letter]
    return if own_self_switch(key)

    names = grant(message["gains"].to_s)
    MGQ_MpStory.keep_own_self_switch(key, true) if defined?(MGQ_MpStory)
    text = names.empty? ? "#{peer.state['name']} opened a chest for the party." : "#{peer.state['name']} opened a chest for the party: #{names.join(', ')}."
    MGQ_MpOverworld::Status.notice(text)
  rescue => e
    log("taking a chest failed: #{e.class}: #{e.message}")
  end

  # Reads a self switch as it is the player's own, whether or not they play the leader's story.
  #
  # @param key [Array] The self switch.
  # @return [Boolean] Its value.
  def self.own_self_switch(key)
    defined?(MGQ_MpStory) ? MGQ_MpStory.own_self_switch(key) : $game_self_switches[key]
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

# Game hooks.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpEvents.hookable?
  begin
    class Game_Event
      # Tells which page the event shows.
      #
      # @return [Integer] The page's index, -1 for none.
      def mgq_mp_events_page
        @page ? @event.pages.index(@page).to_i : -1
      end
    end

    class Game_Interpreter
      alias mgq_mp_events_setup setup
      alias mgq_mp_events_run run

      # Sets up a list of commands, noticing a chest the map's main event opens.
      #
      # @param list [Array<RPG::EventCommand>] The commands.
      # @param event_id [Integer] The event, 0 for none.
      def setup(list, event_id = 0)
        mgq_mp_events_setup(list, event_id)
        MGQ_MpEvents.started(self, event_id) rescue nil
      end

      # Runs the commands, then tells the party about a chest they opened.
      def run
        mgq_mp_events_run
        MGQ_MpEvents.finished(self) rescue nil
      end
    end
  rescue => e
    MGQ_MpEvents.log("interpreter hooks FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Game_Party
      alias mgq_mp_events_gain_item gain_item
      alias mgq_mp_events_gain_gold gain_gold

      # Gives an item, keeping it for the party when a chest gives it.
      #
      # The game gives an enchanted item by calling this again for each copy it makes, so only the
      # outermost call counts.
      #
      # @param item [RPG::BaseItem] The item.
      # @param amount [Integer] How many.
      # @param rest [Array] The original's other arguments.
      def gain_item(item, amount, *rest)
        outermost = MGQ_MpEvents.enter_gain
        begin
          mgq_mp_events_gain_item(item, amount, *rest)
        ensure
          MGQ_MpEvents.leave_gain
        end
        MGQ_MpEvents.gained_item(item, amount) if outermost
      end

      # Gives gold, keeping it for the party when a chest gives it.
      #
      # @param amount [Integer] How much.
      def gain_gold(amount)
        mgq_mp_events_gain_gold(amount)
        MGQ_MpEvents.gained("g", 0, amount)
      end
    end
  rescue => e
    MGQ_MpEvents.log("party hooks FAILED: #{e.class}: #{e.message}")
  end
end
