#----------------------------------------------------------------
#  mp_story.rb
#
#  Changelog:
#      Paulinchen  2026-09-30: Kept chests the player's own while they play the leader's story
#                            - Created
#
#----------------------------------------------------------------

# The story a party plays. Outside a party every player plays their own story. In a party, the
# members borrow the leader's story, the switches, variables and self switches the game's events
# read, and get their own back when they leave or the leader goes. What is the player's own, their
# party, their companions' awakening and their affection, stays theirs throughout, and every save a
# member makes holds their own story.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpStory
  # Frames between two messages of the leader, a quarter of a second at 60 frames per second.
  SEND_FRAMES = 15

  # Frames between two requests for the leader's story, two seconds, until it came.
  ASK_FRAMES = 120

  # Switches that are the player's own: configuration mirrored in switches (95, 445-447, 502) and
  # the switches that tell whether a companion is in the party (1001-2000).
  PERSONAL_SWITCHES = [95, 445, 446, 447, 502, 1001..2000]

  # First switch that tells whether a companion awakened, one per companion.
  AWAKENING_SWITCHES = 6000

  # Variables that are the player's own: where a game over returns them (1002) and monsters'
  # friendliness (2000-2999).
  PERSONAL_VARIABLES = [1002, 2000...3000]

  # First variable that holds a companion's affection, one per companion.
  AFFECTION_VARIABLES = 3000

  @own = nil
  @leader_id = nil
  @sent = nil
  @frames = 0
  @ask_frames = 0

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Game_Switches.method_defined?(:mgq_mp_data)
  end

  # Writes a line to the Multiplayer mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("story: #{message}")
  rescue
  end

  # Shows a notice at the bottom left of the map, through mp_overworld.rb.
  #
  # @param text [String] The notice.
  def self.notice(text)
    MGQ_MpOverworld::Status.notice(text) if defined?(MGQ_MpOverworld)
  end

  # Reports whether the player plays the leader's story now.
  #
  # @return [Boolean] Whether they do.
  def self.guest?
    !@own.nil?
  end

  # Finds the leader of the player's party, through mp_actions.rb.
  #
  # @return [MGQ_MpOverworld::Peers::Peer, Symbol, nil] The leader, :me for the player, nil outside a party.
  def self.leader
    return nil unless defined?(MGQ_MpOverworld) && MGQ_MpOverworld.in_world? && defined?(MGQ_MpActions)

    MGQ_MpActions::Party.leader
  end

  # Follows the party for one frame: the leader tells what changed, a member borrows the leader's
  # story, and a player who left the party gets their own back. Called after the map's update.
  def self.update
    leader = self.leader
    restore if guest? && !leader.is_a?(MGQ_MpOverworld::Peers::Peer)
    if leader == :me
      lead
    else
      @sent = nil
      follow(leader) if leader
    end
  rescue => e
    log("update failed: #{e.class}: #{e.message}") unless @update_failed
    @update_failed = true
  end

  # As leader, tells the members what of the story changed since the last time.
  def self.lead
    if MGQ_MpActions::Party.members.empty?
      @sent = nil
      return
    end

    @frames += 1
    return if @frames < SEND_FRAMES

    @frames = 0
    now = raw_state
    changes = @sent ? delta(@sent, now) : nil
    @sent = now if changes.nil? || changes.values.all?(&:empty?) || tell(-1, "delta", changes)
  end

  # As member, asks the leader for their story until it came, again whenever the leader changes.
  #
  # @param leader [MGQ_MpOverworld::Peers::Peer] The leader.
  def self.follow(leader)
    id = leader.state["id"].to_s
    if id != @leader_id
      @leader_id = id
      @waiting = true
      @ask_frames = ASK_FRAMES
    end
    return unless @waiting

    @ask_frames += 1
    return if @ask_frames < ASK_FRAMES

    @ask_frames = 0
    tell(leader.seat, "ask", {})
  end

  # Takes a message about the story. Called by mp_overworld.rb.
  #
  # @param peer [MGQ_MpOverworld::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    return unless peer && message["party"] == MGQ_MpActions::Party.id

    case message["story"]
    when "ask"
      tell(peer.seat, "full", full(raw_state)) if leader == :me && MGQ_MpActions::Party.member?(peer.state)
    when "full"
      borrow(peer, decode_full(message)) if leader.equal?(peer)
    when "delta"
      apply(decode_delta(message)) if leader.equal?(peer) && guest? && !@waiting
    end
  rescue => e
    log("taking #{message['story']} failed: #{e.class}: #{e.message}")
  end

  # Sends a message about the story to one member or to the whole party.
  #
  # @param seat [Integer] The member's seat, -1 for everyone, who ignore it outside the party.
  # @param kind [String] "ask", "full" or "delta".
  # @param fields [Hash] The message's other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, fields)
    message = { "story" => kind, "party" => MGQ_MpActions::Party.id }.merge(fields)
    MGQ_MpOverworld::Link.send_to(seat, MGQ_MpOverworld::Me.encode(message))
  end

  # Starts playing the leader's story, keeping the player's own aside the first time.
  #
  # @param leader [MGQ_MpOverworld::Peers::Peer] The leader.
  # @param story [Array] The leader's switches, variables and self switches.
  def self.borrow(leader, story)
    first = !guest?
    @own = deep_copy(raw_state) if first
    set_raw(*mix(story, raw_state))
    @waiting = false
    notice("You follow #{leader.state['name']}'s story while in the party.") if first
  end

  # Takes what of the leader's story changed.
  #
  # @param changes [Array] The changed switches, variables and self switches, each by key.
  def self.apply(changes)
    switches, variables, self_switches = raw_state
    changes[0].each { |id, value| switches[id] = value unless personal_switch?(id) }
    changes[1].each { |id, value| variables[id] = value unless personal_variable?(id) }
    changes[2].each { |key, value| self_switches[key] = value unless personal_self_switch?(key) }
    set_raw(switches, variables, self_switches)
  end

  # Reads a self switch as it is the player's own, whether or not they play the leader's story.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @return [Boolean] Its value.
  def self.own_self_switch(key)
    (guest? ? @own[2][key] : $game_self_switches.mgq_mp_data[key]) == true
  end

  # Sets a self switch of the player's own, such as a chest's, in their own story and in the one
  # they play.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @param value [Boolean] Its value.
  def self.keep_own_self_switch(key, value)
    @own[2][key] = value if guest?
    $game_self_switches.mgq_mp_data[key] = value
    $game_map.need_refresh = true if $game_map
  end

  # Shows the player's own chests on a map they enter while playing the leader's story. Called
  # after a map is set up.
  def self.map_entered
    return unless guest?

    data = $game_self_switches.mgq_mp_data
    chest_keys.each { |key| data[key] = @own[2][key] }
    $game_map.need_refresh = true
  rescue => e
    log("showing own chests failed: #{e.class}: #{e.message}")
  end

  # Reports whether a self switch is the player's own: a chest's on the map, through mp_events.rb.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @return [Boolean] Whether it is.
  def self.personal_self_switch?(key)
    defined?(MGQ_MpEvents) && $game_map ? MGQ_MpEvents.chest_key?(key) : false
  end

  # Lists the self switches of the chests on the map, through mp_events.rb.
  #
  # @return [Array<Array>] Their keys.
  def self.chest_keys
    defined?(MGQ_MpEvents) && $game_map ? MGQ_MpEvents.chest_keys : []
  end

  # Gives the player their own story back, keeping what of their own changed meanwhile.
  def self.restore
    set_raw(*mix(@own, raw_state))
    @own = nil
    @leader_id = nil
    @waiting = false
    notice("You are back in your own story.")
  end

  # Forgets the story kept aside, as when a save is loaded or a new game starts, which bring their
  # own story. A member then asks the leader again.
  def self.forget
    @own = nil
    @leader_id = nil
    @waiting = false
  end

  # The story a save holds: the member's own while they play the leader's.
  #
  # @param contents [Hash] What the game saves.
  # @return [Hash] The same, with the member's own story.
  def self.save_contents(contents)
    return contents unless guest?

    switches, variables, self_switches = mix(@own, raw_state)
    contents[:switches] = with_data(contents[:switches], switches)
    contents[:variables] = with_data(contents[:variables], variables)
    contents[:self_switches] = with_data(contents[:self_switches], self_switches)
    contents
  end

  # Reads the story as the game keeps it, past the game's own handling of single switches and variables.
  #
  # @return [Array] Copies of the switches, variables and self switches.
  def self.raw_state
    [$game_switches.mgq_mp_data.dup, $game_variables.mgq_mp_data.dup, $game_self_switches.mgq_mp_data.dup]
  end

  # Replaces the story as the game keeps it, past the game's own handling, which would add or remove
  # companions, and has the map's events look at it again.
  #
  # @param switches [Array] The switches.
  # @param variables [Array] The variables.
  # @param self_switches [Hash] The self switches.
  def self.set_raw(switches, variables, self_switches)
    $game_switches.mgq_mp_data = switches
    $game_variables.mgq_mp_data = variables
    $game_self_switches.mgq_mp_data = self_switches
    $game_map.need_refresh = true if $game_map
  end

  # Joins one story with the player's own values.
  #
  # @param story [Array] The switches, variables and self switches of the story.
  # @param personal [Array] Those of the player, whose own values win.
  # @return [Array] The joined switches, variables and self switches.
  def self.mix(story, personal)
    switches = story[0].dup
    variables = story[1].dup
    [personal[0].size, switches.size].max.times { |id| switches[id] = personal[0][id] if personal_switch?(id) }
    [personal[1].size, variables.size].max.times { |id| variables[id] = personal[1][id] if personal_variable?(id) }
    self_switches = story[2].dup
    chest_keys.each { |key| self_switches[key] = personal[2][key] }
    [switches, variables, self_switches]
  end

  # Reports whether a switch is the player's own.
  #
  # @param id [Integer] The switch.
  # @return [Boolean] Whether it is.
  def self.personal_switch?(id)
    PERSONAL_SWITCHES.any? { |range| range === id } || (id >= AWAKENING_SWITCHES && id <= AWAKENING_SWITCHES + companions)
  end

  # Reports whether a variable is the player's own.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it is.
  def self.personal_variable?(id)
    PERSONAL_VARIABLES.any? { |range| range === id } || (id >= AFFECTION_VARIABLES && id < AFFECTION_VARIABLES + companions)
  end

  # Counts the game's companions, one awakening switch and one affection variable each.
  #
  # @return [Integer] How many.
  def self.companions
    $data_actors ? $data_actors.size : 1000
  end

  # Lists what changed between two stories, leaving out what is the player's own.
  #
  # @param before [Array] The switches, variables and self switches before.
  # @param after [Array] The same after.
  # @return [Hash] Changed switches, variables and self switches by key, under "s", "v" and "ss".
  def self.delta(before, after)
    switches = changed(before[0], after[0]).reject { |id, _| personal_switch?(id) }
    variables = changed(before[1], after[1]).reject { |id, _| personal_variable?(id) }
    self_switches = (before[2].keys | after[2].keys).reject { |key| before[2][key] == after[2][key] }.map { |key| [key, after[2][key]] }
    {
      "s" => switches.map { |id, value| "#{id}:#{value ? 1 : 0}" }.join(","),
      "v" => variables.map { |id, value| "#{id}:#{encode_value(value)}" }.join(","),
      "ss" => self_switches.map { |key, value| "#{key.join('.')}:#{value ? 1 : 0}" }.join(","),
    }
  end

  # Lists the entries of two arrays that differ.
  #
  # @param before [Array] The array before.
  # @param after [Array] The array after.
  # @return [Array<Array>] Each changed index with its value after.
  def self.changed(before, after)
    (0...[before.size, after.size].max).select { |id| before[id] != after[id] }.map { |id| [id, after[id]] }
  end

  # Writes a whole story, leaving out what is the player's own.
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [Hash] The switches on, the variables set and the self switches on, under "s", "v" and "ss".
  def self.full(story)
    switches = (0...story[0].size).select { |id| story[0][id] && !personal_switch?(id) }
    variables = (0...story[1].size).reject { |id| story[1][id].nil? || story[1][id] == 0 || personal_variable?(id) }
    {
      "s" => switches.join(","),
      "v" => variables.map { |id| "#{id}:#{encode_value(story[1][id])}" }.join(","),
      "ss" => story[2].select { |_, value| value }.keys.map { |key| key.join(".") }.join(","),
    }
  end

  # Reads a whole story a leader wrote.
  #
  # @param message [Hash] The message.
  # @return [Array] The switches, variables and self switches.
  def self.decode_full(message)
    switches = []
    message["s"].to_s.split(",").each { |id| switches[id.to_i] = true }
    variables = []
    entries(message["v"]).each { |id, value| variables[id.to_i] = decode_value(value) }
    self_switches = {}
    message["ss"].to_s.split(",").each { |key| self_switches[decode_key(key)] = true }
    [switches, variables, self_switches]
  end

  # Reads what of a story changed.
  #
  # @param message [Hash] The message.
  # @return [Array<Array>] The changed switches, variables and self switches, each by key.
  def self.decode_delta(message)
    [
      entries(message["s"]).map { |id, value| [id.to_i, value == "1"] },
      entries(message["v"]).map { |id, value| [id.to_i, decode_value(value)] },
      entries(message["ss"]).map { |key, value| [decode_key(key), value == "1"] },
    ]
  end

  # Splits a list of key:value entries.
  #
  # @param text [String, nil] The list.
  # @return [Array<Array<String>>] Each entry's key and value.
  def self.entries(text)
    text.to_s.split(",").map { |entry| entry.split(":", 2) }
  end

  # Writes a variable's value; only the kinds a message can carry safely.
  #
  # @param value [Object] The value.
  # @return [String] The value, empty for none or a kind no message carries.
  def self.encode_value(value)
    case value
    when Integer then "n#{value}"
    when Float then "f#{value}"
    when String then "s#{[value].pack('m0')}"
    when true then "T"
    when false then "F"
    else ""
    end
  end

  # Reads a variable's value.
  #
  # @param text [String, nil] The value as written.
  # @return [Object] The value, nil for none.
  def self.decode_value(text)
    text = text.to_s
    case text[0, 1]
    when "n" then text[1..-1].to_i
    when "f" then text[1..-1].to_f
    when "s" then text[1..-1].unpack('m0')[0].force_encoding("UTF-8")
    when "T" then true
    when "F" then false
    end
  end

  # Reads a self switch's key.
  #
  # @param text [String] The key as written: map, event and letter.
  # @return [Array] The key.
  def self.decode_key(text)
    map_id, event_id, letter = text.split(".")
    [map_id.to_i, event_id.to_i, letter]
  end

  # Copies a story, so what the game changes later leaves the copy alone.
  #
  # @param story [Array] The story.
  # @return [Array] The copy.
  def self.deep_copy(story)
    Marshal.load(Marshal.dump(story))
  end

  # Copies one of the game's switches, variables or self switches with other data.
  #
  # @param object [Game_Switches, Game_Variables, Game_SelfSwitches] The object.
  # @param data [Array, Hash] The data.
  # @return [Object] The copy.
  def self.with_data(object, data)
    copy = object.dup
    copy.mgq_mp_data = data
    copy
  end
end

# Game hooks.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpStory.hookable?
  begin
    [Game_Switches, Game_Variables, Game_SelfSwitches].each do |klass|
      klass.class_eval do
        # The data as the game keeps it, past its handling of single entries.
        #
        # @return [Array, Hash] The data.
        def mgq_mp_data
          @data
        end

        # Replaces the data as the game keeps it, past its handling of single entries.
        #
        # @param data [Array, Hash] The data.
        def mgq_mp_data=(data)
          @data = data
        end
      end
    end
  rescue => e
    MGQ_MpStory.log("data access FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Game_Map
      alias mgq_mp_story_update update

      # Updates the map, then the party's story.
      #
      # @param args [Array] The original's arguments.
      def update(*args)
        mgq_mp_story_update(*args)
        MGQ_MpStory.update
      end
    end
  rescue => e
    MGQ_MpStory.log("map hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Game_Map
      alias mgq_mp_story_setup setup

      # Sets up a map, then shows the player's own chests on it.
      #
      # @param map_id [Integer] The map.
      def setup(map_id)
        mgq_mp_story_setup(map_id)
        MGQ_MpStory.map_entered
      end
    end
  rescue => e
    MGQ_MpStory.log("map setup hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class << DataManager
      alias mgq_mp_story_make_save_contents make_save_contents
      alias mgq_mp_story_extract_save_contents extract_save_contents
      alias mgq_mp_story_create_game_objects create_game_objects

      # Gathers what the game saves, with a member's own story in place of the leader's.
      #
      # @return [Hash] What the game saves.
      def make_save_contents
        contents = mgq_mp_story_make_save_contents
        begin
          MGQ_MpStory.save_contents(contents)
        rescue => e
          MGQ_MpStory.log("save guard failed: #{e.class}: #{e.message}")
          contents
        end
      end

      # Takes a loaded save, which brings its own story.
      #
      # @param contents [Hash] The save's contents.
      def extract_save_contents(contents)
        mgq_mp_story_extract_save_contents(contents)
        MGQ_MpStory.forget
      end

      # Makes the game's objects anew, as for a new game, which brings its own story.
      def create_game_objects
        mgq_mp_story_create_game_objects
        MGQ_MpStory.forget
      end
    end
  rescue => e
    MGQ_MpStory.log("save hooks FAILED: #{e.class}: #{e.message}")
  end
end
