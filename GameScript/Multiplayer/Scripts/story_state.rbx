#----------------------------------------------------------------
#  story_state.rbx
#
#  Changelog:
#      Paulinchen  2026-10-28: Read the rewards a party member catches up with, every chest and the chest flags from the catch-up tables the DLL holds
#      Paulinchen  2026-10-24: Shared the second accessory slot (445) as a Raid World's story
#                            - Gave the characters the second accessory slot once a story written past the game turned it on
#                            - Listed the bans of the place a player stands in
#      Paulinchen  2026-10-23: Read what is each player's own from the story's table of the DLL, the Raid World's story mapping or the Classic party's
#                            - Dropped the Raid personal lists, which the story mapping replaces, and the leader's whole-story delta
#      Paulinchen  2026-10-18: Kept switch and variable 0 out of the world's story
#                            - Kept the collab's key item switch each Raid World player's own
#      Paulinchen  2026-10-15: Kept the refusal of recruits each Raid World player's own
#                            - Kept the Pocket Castle's tour each Raid World player's own
#      Paulinchen  2026-10-14: Kept the self switches of a choice's line each Raid World player's own
#      Paulinchen  2026-10-12: Gave characters the classes and races the story and its quests give
#                            - Taught companions the skills the story and its quests teach them
#                            - Kept the small and large medals handed in (55, 59) each player's own
#                            - Capped how far a story another game packed is unpacked
#      Paulinchen  2026-10-11: Kept the chest flags each player's own
#                            - Kept the escape spell's ban (94) each player's own
#                            - Kept the switches that only stay on during a scene each Raid World player's own
#                            - Kept the flags the game toggles around its fights (22, 73, 97) each player's own
#                            - Kept the event variant the game picks before calling it (129) each player's own
#      Paulinchen  2026-10-10: Joined the self switches of only the chests the player's own story holds
#      Paulinchen  2026-10-09: Kept the difficulty and the Labyrinth, Colosseum and boss values each Raid player's own
#                            - Created
#
#----------------------------------------------------------------

# The story's state model, which the party's story (coop_story.rbx) and a Raid World's story
# (world_story.rbx, world_catchup.rbx) share: the story as the game keeps it, the switches,
# variables and self switches read and written past the game's own handling; what of it is each
# player's own, which every join of stories keeps; how a story is written for a message and read
# back; and how the story's skills, companions and items are granted.
module MGQ_MpStoryState
  # The switch that bans warping, such as with a Harpy Feather. The game's events turn it on where
  # the player enters a cave or a building and off where they leave it, so it tells of the place a
  # player stands in, not of the story.
  WARP_BAN = defined?(NWConst::Sw::WARP_BAN) ? NWConst::Sw::WARP_BAN : 100

  # The switch that bans the escape spell ("Riremito OFF Switch"), which a few scenes turn on and
  # the Head Priest of Ilias Temple turns off as he changes jobs: like the warp ban, it tells of
  # the player's place, not of the story.
  ESCAPE_BAN = 94

  # The bans of the place a player stands in.
  PLACE_BANS = [WARP_BAN, ESCAPE_BAN]

  # The switch that tells the player took Alice along.
  ALICE_CHOSEN = 4

  # The switch that tells the player took Ilias along.
  ILIAS_CHOSEN = 5

  # The switches of the side the player chose, their own until the Great Decision, which sets the
  # side anew with the route the party takes.
  SIDE_SWITCHES = [ALICE_CHOSEN, ILIAS_CHOSEN]

  # The switch of the second accessory slot, which Fallen Micaela's blessing turns on for good. The
  # game's setter of the switch gives every character the slot.
  EXTRA_ACCESSORY_SLOT = defined?(NWConst::Sw::EXTRA_ACCESSORY_SLOT) ? NWConst::Sw::EXTRA_ACCESSORY_SLOT : 445

  # Switches the game turns on for good and never off, which a track written over the player's
  # story keeps on (see MGQ_MpWorldStory.kept_unlock?). Outside a Raid World they stay each player's
  # own by the Classic party's table: a party's member borrows the leader's story and gets their own
  # back, and the slot coming and going would move their equipment.
  UNLOCK_SWITCHES = [EXTRA_ACCESSORY_SLOT]

  # First variable that holds a companion's affection, one per companion.
  AFFECTION_VARIABLES = 3000

  # Variables of the routes after the Great Decision, where the sides no longer differ in rewards.
  ROUTE_MARKERS = [1141, 1142, 1143]

  # The character whose story skills count, Luka.
  HERO = 1

  # Bytes a whole story takes at most in a message, below the 256 KB one carries.
  MAX_FULL_BYTES = 200_000

  # Bytes of packed text a story another game wrote is read from at most, twice what a whole story
  # takes, since a story too large for a message goes without what it turned off, unchecked.
  MAX_PACKED_BYTES = MAX_FULL_BYTES * 2

  # Bytes a packed story unpacks to at most, far beyond any real story's lists.
  MAX_UNPACKED_BYTES = 8 * 1024 * 1024

  # Bytes of packed text inflated per step, so one step unpacks a few MB at most.
  INFLATE_SLICE = 4096

  extend MGQ_MpLog

  # What starts this script's lines in the log, the same as coop_story.rbx's.
  LOG_TAG = "co-op story"

  # The topic that hands the rewards a party member catches up with, see PartyRewards in the DLL.
  REWARDS_TOPIC = "story.rewards"

  # Frames between two looks whether the DLL holds newer rewards, five seconds.
  REWARDS_FRAMES = 300

  # Frames between two asks for the rewards while none came, half a second, so the callers that ask
  # every frame do not call the DLL every frame when the relay never sends them.
  MISSING_FRAMES = 30

  # The rewards of the game's events a party member of a Classic world catches up with
  # (coop_story.rbx), every chest and the chest flags, as the catch-up tables the relay keeps beside
  # the story mapping hold them, in the shapes the constants of coop_story_rewards.rbx had.
  class Rewards
    # @return [Integer] The story mapping's revision they came with.
    attr_reader :rev

    # @return [Array<Integer>] The skills Luka learns in events.
    attr_reader :skills

    # @return [Array<Integer>] The companions who join in events.
    attr_reader :actors

    # @return [Hash{String => Integer}] How many of each item the events that move the story on give
    #   at most, by its letter and id.
    attr_reader :items

    # @return [Hash{Symbol => Array<Integer>}] The skills and companions only the events where the
    #   sides differ give before the Great Decision (:skills, :actors).
    attr_reader :sided

    # @return [Hash{Symbol => Array<Integer>}] Those of sided the Final Chapter's events give too.
    attr_reader :route

    # @return [Hash{Symbol => Array}] The skills, companions and story items only the Final Chapter's
    #   events give, along one route (:skills, :actors, :items).
    attr_reader :final

    # @return [Array<Hash>] The events that give each side other skills or companions: :alice and
    #   :ilias (each {:skills, :actors}), :choice and :marks (one list per page, each [:s, switch],
    #   [:v, variable, at least] or [:ss, map, event, letter]).
    attr_reader :groups

    # @return [Array<Array>] The self switch of every chest: map, event and letter.
    attr_reader :chests

    # @return [Array<Integer>] The switches only chests turn on.
    attr_reader :chest_flags

    # Reads the rewards the DLL handed.
    #
    # @param answer [Hash] The answer of REWARDS_TOPIC.
    def initialize(answer)
      @rev = answer["rev"]
      @skills = answer["skills"]
      @actors = answer["actors"]
      @items = answer["items"]
      @sided = kinds(answer["sided"])
      @route = kinds(answer["route"])
      @final = kinds(answer["final"])
      @groups = answer["groups"].map do |group|
        { :alice => kinds(group["alice"]), :ilias => kinds(group["ilias"]), :choice => group["choice"] ? true : false,
          :marks => group["marks"].map { |page| page.map { |mark| [mark[0].to_sym] + mark[1..-1] } } }
      end
      @chests = answer["chests"]
      @chest_flags = answer["chest_flags"]
    end

    # Names the lists of a Hash by Symbols, as the constants did.
    #
    # @param lists [Hash{String => Array}] The lists.
    # @return [Hash{Symbol => Array}] The same lists.
    def kinds(lists)
      named = {}
      lists.each { |kind, list| named[kind.to_sym] = list }
      named
    end
  end

  # Reads the story as the game keeps it, past the game's own handling of single switches and
  # variables.
  #
  # @return [Array] Copies of the switches, variables and self switches.
  def self.raw_state
    [data_of($game_switches).dup, data_of($game_variables).dup, data_of($game_self_switches).dup]
  end

  # Replaces the story as the game keeps it, past the game's own handling, which would add or remove
  # companions, and has the map's events look at it again.
  #
  # @param switches [Array] The switches.
  # @param variables [Array] The variables.
  # @param self_switches [Hash] The self switches.
  def self.set_raw(switches, variables, self_switches)
    slot = $game_switches[EXTRA_ACCESSORY_SLOT] ? true : false
    MGQ_MpGame.set($game_switches, :data, switches)
    MGQ_MpGame.set($game_variables, :data, variables)
    MGQ_MpGame.set($game_self_switches, :data, self_switches)
    refit_accessory_slot(slot)
    $game_map.need_refresh = true if $game_map
  end

  # Gives every character the second accessory slot or takes it away, as the game's setter of its
  # switch does, once a story written past that setter changed the switch.
  #
  # @param before [Boolean] Whether the switch was on before.
  def self.refit_accessory_slot(before)
    return if ($game_switches[EXTRA_ACCESSORY_SLOT] ? true : false) == before || !$game_actors.respond_to?(:each)

    $game_actors.each { |actor| actor.change_slot if actor.respond_to?(:change_slot) }
  end

  # Reads the data the game keeps for its switches, variables or self switches, past its handling
  # of single entries.
  #
  # @param object [Game_Switches, Game_Variables, Game_SelfSwitches] The object.
  # @return [Array, Hash] The data itself, not a copy.
  def self.data_of(object)
    MGQ_MpGame.get(object, :data)
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
    MGQ_MpGame.set(copy, :data, data)
    copy
  end

  # Joins one story with the player's own values.
  #
  # @param story [Array] The switches, variables and self switches of the story.
  # @param personal [Array] Those of the player, whose own values win.
  # @param chests [Array<Array>] The self switches of the chests that stay the player's own, those
  #   on the map by default; a chest the player never opened is left out.
  # @return [Array] The joined switches, variables and self switches.
  def self.mix(story, personal, chests = chest_keys)
    switches = story[0].dup
    variables = story[1].dup
    [personal[0].size, switches.size].max.times { |id| switches[id] = personal[0][id] if personal_switch?(id, story[1]) }
    [personal[1].size, variables.size].max.times { |id| variables[id] = personal[1][id] if personal_variable?(id) }
    self_switches = story[2].dup
    (chests | (story[2].keys | personal[2].keys).select { |key| choice_self_switch?(key) }).each do |key|
      if personal[2].key?(key)
        self_switches[key] = personal[2][key]
      else
        self_switches.delete(key)
      end
    end
    [switches, variables, self_switches]
  end

  # Reports whether a switch is the player's own, by the open world's table (MGQ_MpStoryKeys): a
  # Raid World's story mapping, a Classic party's table, whose side switches are the player's own
  # until the Great Decision; in a Classic party also the outcomes of the member's own choices.
  #
  # @param id [Integer] The switch.
  # @param variables [Array, nil] The variables of the story it belongs to, nil for the one played.
  # @return [Boolean] Whether it is.
  def self.personal_switch?(id, variables = nil)
    !MGQ_MpStoryKeys.shared?(0, id, variables) || (!MGQ_MpCoop::Scope.raid? && choice_key?(:s, id))
  end

  # Reports whether a switch is a chest flag, which only chests turn on.
  #
  # @param id [Integer] The switch.
  # @return [Boolean] Whether it is.
  def self.chest_flag?(id)
    chest_flags.include?(id)
  end

  # Lists the chest flags, see Rewards.
  #
  # @return [Array<Integer>] The switches; none before the story mapping came.
  def self.chest_flags
    found = rewards
    found ? found.chest_flags : []
  end

  # The rewards a party member catches up with, every chest and the chest flags, from the DLL: asked
  # every MISSING_FRAMES until they came, then every REWARDS_FRAMES whether newer ones came.
  #
  # @return [Rewards, nil] The rewards; nil before the story mapping came.
  def self.rewards
    now = Graphics.frame_count
    # A loaded save moves the frame count back.
    return @rewards if @rewards_at && now >= @rewards_at && now - @rewards_at < (@rewards ? REWARDS_FRAMES : MISSING_FRAMES)

    @rewards_at = now
    answer = MGQ_Multiplayer::Bridge.call(REWARDS_TOPIC, @rewards ? @rewards.rev : nil)
    return @rewards unless answer.is_a?(Hash)

    @rewards = Rewards.new(answer)
    @rewards_serial = rewards_serial + 1
    log("read the rewards a party member catches up with at revision #{@rewards.rev}: #{@rewards.skills.size} skill(s), #{@rewards.actors.size} companion(s), " \
        "#{@rewards.items.size} item(s), #{@rewards.groups.size} side event(s), #{@rewards.chests.size} chest(s)")
    @rewards
  rescue => e
    log_once(:rewards, "reading the rewards a party member catches up with failed: #{e.class}: #{e.message}")
    @rewards
  end

  # Counts how often other rewards came, which a table built from them compares to know it is old.
  #
  # @return [Integer] The count, 0 before the first.
  def self.rewards_serial
    @rewards_serial.to_i
  end

  # Reports whether a switch only stays on while a scene runs, such as "White Rabbit Emerged" (2029),
  # by the open world's table.
  #
  # @param id [Integer] The switch.
  # @return [Boolean] Whether it does.
  def self.scene_switch?(id)
    MGQ_MpStoryKeys.bit?(0, id, MGQ_MpStoryKeys::SCENE)
  end

  # Reports whether a switch or a variable is the outcome of a story's choice the player made,
  # through coop_choices.rbx.
  #
  # @param kind [Symbol] :s for a switch, :v for a variable.
  # @param id [Integer] The switch or variable.
  # @return [Boolean] Whether it is.
  def self.choice_key?(kind, id)
    defined?(MGQ_MpCoopChoices) && MGQ_MpCoopChoices.personal?(kind, id) ? true : false
  end

  # Reports whether a variable is the player's own, by the open world's table; in a Classic party
  # also the outcomes of the member's own choices.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it is.
  def self.personal_variable?(id)
    !MGQ_MpStoryKeys.shared?(1, id) || (!MGQ_MpCoop::Scope.raid? && choice_key?(:v, id))
  end

  # Reports whether a self switch is the player's own, by the open world's table; in a Classic
  # party also a chest's on the map, through coop_events.rbx, and one of a choice's lines, through
  # coop_choices.rbx.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @return [Boolean] Whether it is.
  def self.personal_self_switch?(key)
    return true unless MGQ_MpStoryKeys.shared?(2, key)
    return false if MGQ_MpCoop::Scope.raid?

    ($game_map && MGQ_MpCoopEvents.chest_key?(key)) || choice_self_switch?(key) ? true : false
  end

  # Reports whether a switch, variable or self switch is the player's own.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Boolean] Whether it is.
  def self.personal_key?(kind, key)
    case kind
    when 0 then personal_switch?(key)
    when 1 then personal_variable?(key)
    else personal_self_switch?(key)
    end
  end

  # Reports whether a self switch is the player's own as one of a choice's lines, see
  # MGQ_MpCoopChoices.personal_self_switch?.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @return [Boolean] Whether it is.
  def self.choice_self_switch?(key)
    defined?(MGQ_MpCoopChoices) && MGQ_MpCoopChoices.personal_self_switch?(key) ? true : false
  end

  # Lists the self switches of the chests on the map, through coop_events.rbx.
  #
  # @return [Array<Array>] Their keys.
  def self.chest_keys
    $game_map ? MGQ_MpCoopEvents.chest_keys : []
  end

  # Lists the self switches of every chest in the game, see Rewards.
  #
  # @return [Array<Array>] Their keys: map, event and letter; none before the story mapping came.
  def self.all_chest_keys
    found = rewards
    found ? found.chests : []
  end

  # Reports whether the sides still get other rewards in a story: before the Great Decision, while
  # no route has progress.
  #
  # @param variables [Array, nil] The story's variables, nil for those of the story played.
  # @return [Boolean] Whether they do.
  def self.sides_differ?(variables = nil)
    variables ||= $game_variables ? data_of($game_variables) : []
    ROUTE_MARKERS.all? { |id| variables[id].to_i == 0 }
  end

  # The side some switches tell.
  #
  # @param switches [Array] The switches.
  # @return [Symbol, nil] :alice, :ilias, or nil for none.
  def self.side_of(switches)
    return :alice if switches[ALICE_CHOSEN]
    return :ilias if switches[ILIAS_CHOSEN]

    nil
  end

  # Lists the switches, variables or self switches that differ between two stories.
  #
  # @param before [Array, Hash] Those of one story.
  # @param after [Array, Hash] Those of the other.
  # @return [Array] The keys that differ.
  def self.changed_keys(before, after)
    keys = before.is_a?(Hash) ? before.keys | after.keys : (0...[before.size, after.size].max).to_a
    keys.reject { |key| before[key] == after[key] }
  end

  # Writes a whole story, leaving out what is the player's own. What the story turned off or set to
  # zero is written too, apart from what it never set, which a member who catches up keeps of their
  # own, see MGQ_MpCoopStory.caught_up_story. The lists are packed, see pack; one still too large
  # for a message leaves out what the story turned off or set to zero, and says so.
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [Hash] The packed lists under "z", see unpack, and "part" 1 for a story that leaves
  #   out what it turned off.
  def self.full(story)
    packed = pack(story_lists(story, true))
    return { "z" => packed } if packed.size <= MAX_FULL_BYTES

    log_once(:full_size, "the whole story took #{packed.size} bytes, so it leaves out what the story turned off")
    { "z" => pack(story_lists(story, false)), "part" => 1 }
  end

  # Lists a story for a message: the switches on and off under "s" and "sf", the variables set
  # under "v", and the self switches on and off under "ss" and "ssf".
  #
  # @param story [Array] The switches, variables and self switches.
  # @param off [Boolean] Whether what the story turned off or set to zero is listed too.
  # @return [Hash{String => String}] The lists.
  def self.story_lists(story, off)
    switches = (0...story[0].size).reject { |id| story[0][id].nil? || personal_switch?(id) || (!off && !story[0][id]) }
    variables = (0...story[1].size).reject { |id| story[1][id].nil? || personal_variable?(id) || (!off && story[1][id] == 0) }
    self_switches = story[2].keys.reject { |key| story[2][key].nil? || (!off && !story[2][key]) }
    switches_on, switches_off = switches.partition { |id| story[0][id] }
    self_on, self_off = self_switches.partition { |key| story[2][key] }
    {
      "s" => switches_on.join(","), "sf" => switches_off.join(","),
      "v" => variables.map { |id| "#{id}:#{encode_value(story[1][id])}" }.join(","),
      "ss" => self_on.map { |key| key.join(".") }.join(","), "ssf" => self_off.map { |key| key.join(".") }.join(","),
    }
  end

  # Packs lists for a message: each as name=list on its own line, deflated and written in Base64,
  # since a late story's lists of ids would pass what one message carries.
  #
  # @param lists [Hash{String => String}] The lists.
  # @return [String] The packed text.
  def self.pack(lists)
    [Zlib::Deflate.deflate(lists.map { |name, list| "#{name}=#{list}" }.join("\n"))].pack("m0")
  end

  # Unpacks lists another game packed, see pack.
  #
  # @param text [String] The packed text.
  # @return [Hash{String => String}] The lists.
  # @raise [ArgumentError] For a text longer than any story, or one that unpacks past
  #   MAX_UNPACKED_BYTES.
  def self.unpack(text)
    raise ArgumentError, "the packed story took #{text.bytesize} bytes, more than any story" if text.bytesize > MAX_PACKED_BYTES

    lists = {}
    inflated(text.unpack("m0")[0].to_s).split("\n").each do |line|
      name, list = line.split("=", 2)
      lists[name] = list.to_s
    end
    lists
  end

  # Inflates packed bytes a step at a time, stopping once they pass MAX_UNPACKED_BYTES.
  #
  # A deflated text unpacks to up to about a thousand times its size, and running out of memory
  # raises an error no rescue of the callers catches.
  #
  # @param data [String] The deflated bytes.
  # @return [String] The inflated bytes.
  # @raise [ArgumentError] For bytes that unpack past MAX_UNPACKED_BYTES.
  def self.inflated(data)
    zstream = Zlib::Inflate.new
    out = ""
    offset = 0
    while offset < data.size
      out << zstream.inflate(data[offset, INFLATE_SLICE])
      offset += INFLATE_SLICE
      raise ArgumentError, "the packed story unpacked past #{MAX_UNPACKED_BYTES} bytes" if out.bytesize > MAX_UNPACKED_BYTES
    end
    out << zstream.finish
    raise ArgumentError, "the packed story unpacked past #{MAX_UNPACKED_BYTES} bytes" if out.bytesize > MAX_UNPACKED_BYTES
    out
  ensure
    zstream.close if zstream && !zstream.closed?
  end

  # Reads a whole story another game wrote.
  #
  # @param message [Hash] The message.
  # @return [Array] The switches, variables and self switches.
  def self.decode_full(message)
    lists = message["z"] ? unpack(message["z"].to_s) : message
    switches = []
    lists["s"].to_s.split(",").each { |id| switches[id.to_i] = true if known_id?(:switches, id.to_i) }
    lists["sf"].to_s.split(",").each { |id| switches[id.to_i] = false if known_id?(:switches, id.to_i) }
    variables = []
    entries(lists["v"]).each { |id, value| variables[id.to_i] = decode_value(value) if known_id?(:variables, id.to_i) }
    self_switches = {}
    lists["ss"].to_s.split(",").each { |key| self_switches[decode_key(key)] = true }
    lists["ssf"].to_s.split(",").each { |key| self_switches[decode_key(key)] = false }
    [switches, variables, self_switches]
  end

  # Reads what of a story changed.
  #
  # @param message [Hash] The message.
  # @return [Array<Array>] The changed switches, variables and self switches, each by key.
  def self.decode_delta(message)
    [
      entries(message["s"]).map { |id, value| [id.to_i, value == "1"] }.select { |id, _| known_id?(:switches, id) },
      entries(message["v"]).map { |id, value| [id.to_i, decode_value(value)] }.select { |id, _| known_id?(:variables, id) },
      entries(message["ss"]).map { |key, value| [decode_key(key), value == "1"] },
    ]
  end

  # Reports whether an id another game sent names one of this game's switches, variables or items,
  # logging once per kind one beyond them, which is dropped.
  #
  # @param kind [Symbol] :switches, :variables or :items.
  # @param id [Integer] The id.
  # @return [Boolean] Whether it does.
  def self.known_id?(kind, id)
    size = { :switches => $data_system.switches, :variables => $data_system.variables, :items => $data_items }[kind].size
    return true if id > 0 && id < size

    log_once([:unknown_id, kind], "dropped #{kind} #{id} of another game's story: this game has #{size}")
    false
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

  # Lists the ids of the player's own companions, those in the party and those waiting at the
  # castle, past a story's temporary party, which the game's own list shows while it plays.
  #
  # @return [Array<Integer>] The ids.
  def self.roster_ids
    own = MGQ_MpGame.get($game_party, :include_actors)
    own = $game_party.include_actors if own.nil? && $game_party.respond_to?(:include_actors)
    own ? own.to_a : $game_party.all_members.compact.map(&:id)
  end

  # Lists the player's own companions, see roster_ids.
  #
  # @return [Array<Game_Actor>] The companions.
  def self.roster
    roster_ids.map { |id| $game_actors[id] }.compact
  end

  # Reports whether a companion is in the player's own roster, in any of their personas, see
  # roster_ids.
  #
  # @param id [Integer] The companion.
  # @return [Boolean] Whether they are.
  def self.in_roster?(id)
    roster_ids.include?(main_id(id))
  end

  # Finds the companion a persona belongs to, by whose id the game's roster keeps every persona.
  #
  # @param id [Integer] The companion or one of their personas.
  # @return [Integer] The companion's main persona.
  def self.main_id(id)
    main = $game_actors.respond_to?(:original_id) ? $game_actors.original_id(id) : nil
    main || id
  end

  # Reports whether a character knows a skill or an ability, which the game keeps apart from their
  # skills.
  #
  # @param actor [Game_Actor] The character, such as Luka.
  # @param id [Integer] The skill.
  # @return [Boolean] Whether they do.
  def self.knows?(actor, id)
    learned = MGQ_MpGame.get(actor, :skills)
    known = learned ? learned.include?(id) : $data_skills[id] && actor.skill_learn?($data_skills[id])
    return true if known

    abilities = MGQ_MpGame.get(actor, :abilities)
    abilities.is_a?(Hash) && abilities.values.flatten.include?(id) ? true : false
  end

  # Teaches Luka a story skill he lacks.
  #
  # @param id [Integer] The skill.
  # @return [String, nil] Its name, nil when he knew it or the game lacks it.
  def self.learn(id)
    skill = $data_skills[id]
    hero = $game_actors[HERO]
    return log("skipped #{skill_label(id)}: not in the game") if skill.nil?
    return log("skipped #{skill_label(id)}: Luka knows it already") if knows?(hero, id)

    hero.learn_skill(id)
    log("Luka learned #{skill_label(id)}")
    skill.name
  end

  # Teaches a companion a skill the story or one of its quests teaches them, which they lack.
  #
  # @param actor_id [Integer] The companion's persona.
  # @param id [Integer] The skill.
  # @return [String, nil] The companion's and the skill's name, nil when they knew it or the game
  #   lacks either.
  def self.teach(actor_id, id)
    skill = $data_skills[id]
    actor = $game_actors[actor_id]
    return log("skipped #{skill_label(id)} for #{actor_label(actor_id)}: not in the game") if skill.nil? || actor.nil?
    return log("skipped #{skill_label(id)}: #{actor_label(actor_id)} knows it already") if knows?(actor, id)

    actor.learn_skill(id)
    log("#{actor_label(actor_id)} learned #{skill_label(id)}")
    "#{actor.name}'s #{skill.name}"
  end

  # Reads the level a character has of a class or a race.
  #
  # @param actor [Game_Actor] The character.
  # @param id [Integer] The class or race.
  # @return [Integer] The level, 0 for one they never had.
  def self.class_level(actor, id)
    list = actor.respond_to?(:level_list) ? actor.level_list : nil
    list ? list[id].to_i : 0
  end

  # Gives a character a class or a race at a level as the story's event does, keeping the class and
  # race they play now.
  #
  # @param actor_id [Integer] The character.
  # @param id [Integer] The class or race.
  # @param level [Integer] The level, never lowered.
  # @return [String, nil] The character's and the class's name, nil when the game lacks either.
  def self.give_class(actor_id, id, level)
    actor = $game_actors[actor_id]
    klass = $data_classes[id]
    return log("skipped class #{id} for #{actor_label(actor_id)}: not in the game") if actor.nil? || klass.nil?

    Game_Interpreter.new.set_class_level(actor_id, id, level, false, false)
    log("#{actor_label(actor_id)} got #{MGQ_MpLog.named($data_classes, id)} at level #{level}")
    "#{actor.name}'s #{klass.name}"
  end

  # Brings a story companion the player lacks into the roster, waiting at the castle.
  #
  # @param id [Integer] The companion.
  # @return [String, nil] Their name, nil when they were there or the game lacks them.
  def self.join(id)
    return log("skipped #{actor_label(id)}: not in the game") unless $data_actors[id]
    return log("skipped #{actor_label(id)}: in the player's roster already") if in_roster?(id)

    $game_party.add_stand_actor(id)
    log("#{actor_label(id)} joined the player's roster, waiting at the castle")
    $data_actors[id].name
  end

  # Brings a companion the player lacks into the party, or into the roster when it is full or a
  # story's temporary party plays.
  #
  # @param id [Integer] The companion.
  # @return [String, nil] Their name, nil when they were there or the game lacks them.
  def self.bring(id)
    return log("skipped #{actor_label(id)}: not in the game") unless $data_actors[id]
    return log("skipped #{actor_label(id)}: in the player's roster already") if in_roster?(id)

    stand = $game_party.party_member_full? || ($game_party.respond_to?(:temp_actors_use?) && $game_party.temp_actors_use?)
    stand ? $game_party.add_stand_actor(id) : $game_party.add_actor(id)
    log("#{actor_label(id)} joined the player's #{stand ? 'roster, waiting at the castle, as the party is full or a story party plays' : 'party'}")
    $data_actors[id].name
  end

  # Finds an item by the letter of its kind and its id, written together.
  #
  # @param key [String] The item, such as "i501".
  # @return [RPG::BaseItem, nil] The item, nil for one the game lacks.
  def self.item_of(key)
    MGQ_MpGame.item(key[0, 1], key[1..-1].to_i)
  end

  # Counts how many of an item the player holds: in the bag, in the item storage and equipped by
  # any of their own companions, those waiting at the castle too.
  #
  # @param item [RPG::BaseItem] The item.
  # @param worn [Hash, nil] How many of each equipment the companions wear, see worn_counts, nil
  #   to count them now.
  # @return [Integer] How many.
  def self.story_count(item, worn = nil)
    count = $game_party.item_number(item)
    count += $game_party.storehouse_item_number(item) if $game_party.respond_to?(:storehouse_item_number)
    return count unless item.is_a?(RPG::EquipItem)

    count + (worn || worn_counts)[[item.class, item.id]].to_i
  end

  # Counts the equipment the player's own companions wear, in one look at the roster.
  #
  # @return [Hash{Array => Integer}] How many of each, by the item's class and id.
  def self.worn_counts
    worn = Hash.new(0)
    roster.each { |actor| actor.equips.each { |equip| worn[[equip.class, equip.id]] += 1 if equip } }
    worn
  end

  # Names a skill for the log, such as "skill 937 Demon Decapitation".
  #
  # @param id [Integer] The skill.
  # @return [String] The name.
  def self.skill_label(id)
    "skill #{MGQ_MpLog.named($data_skills, id)}"
  end

  # Names a companion for the log, such as "companion 517 Puruel".
  #
  # @param id [Integer] The companion.
  # @return [String] The name.
  def self.actor_label(id)
    "companion #{MGQ_MpLog.named($data_actors, id)}"
  end

  # Names an item for the log by the letter of its kind and its id.
  #
  # @param key [String] The item, such as "i501", or "g0" for gold.
  # @return [String] The name.
  def self.item_label(key)
    return "gold" if key.to_s[0, 1] == "g"

    item = item_of(key.to_s)
    item ? "item #{key} #{item.name}" : "item #{key}"
  rescue
    "item #{key}"
  end

  # Says how far a story is for the log: the main story and the three routes' progress.
  #
  # @param variables [Array] The story's variables.
  # @return [String] Such as "1001=12, routes 0/0/0".
  def self.progress_text(variables)
    "1001=#{variables[1001].to_i}, routes #{ROUTE_MARKERS.map { |id| variables[id].to_i }.join('/')}"
  rescue
    "unknown progress"
  end
end
