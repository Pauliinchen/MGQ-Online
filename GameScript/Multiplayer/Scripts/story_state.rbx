#----------------------------------------------------------------
#  story_state.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Left the lists' place 0 out of the keys a Classic party member asks about, which the DLL refuses
#      Paulinchen  2026-11-05: Left writing and reading the tracks' texts of a variable's value to the DLL
#                            - Handed the whole story and what of it changed to the DLL as values, which writes and reads them
#                            - Asked the DLL's one rule which side the player took along in Iliasville
#                            - Asked the DLL's rule which keys of the leader's story a Classic party member takes as stories are joined
#                            - Read the story's ids from story_ids.rbx
#                            - Left the self switches of the Navy's and the Pirates' lines to the reviewed key list
#                            - Counted its asks by the bridge's frame
#      Paulinchen  2026-11-01: Noted in the save the side the player took along in Iliasville, which the route's side switches no longer tell
#                            - Noted that a save came from another player's starting save, whose side is not the player's
#      Paulinchen  2026-10-31: Kept the warp ban from stopping a player in a world
#                            - Read what is each player's own in a Classic party from the reviewed list's scopes instead of the Classic story's ranges
#                            - Kept the player's own self switches when a story is joined with theirs
#                            - Kept every party chest's self switch the player's own in a Classic party, not only those of the map
#                            - Repaired a save the 0.6.9.2 chest path left stuck, once, at its first load
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
  # The switch that bans warping and the Pocket Castle ("Warp OFF Switch"), which a world keeps
  # off, see lift_warp_ban.
  WARP_BAN = defined?(NWConst::Sw::WARP_BAN) ? NWConst::Sw::WARP_BAN : 100

  # The switch that bans the escape spell ("Riremito OFF Switch"), which a few scenes turn on and
  # the Head Priest of Ilias Temple turns off as he changes jobs: it tells of the player's place,
  # not of the story.
  ESCAPE_BAN = 94

  # The bans of the place a player stands in.
  PLACE_BANS = [ESCAPE_BAN]

  # The switch of the second accessory slot, which Fallen Micaela's blessing turns on for good. The
  # game's setter of the switch gives every character the slot.
  EXTRA_ACCESSORY_SLOT = defined?(NWConst::Sw::EXTRA_ACCESSORY_SLOT) ? NWConst::Sw::EXTRA_ACCESSORY_SLOT : 445

  # Switches the game turns on for good and never off, which a track written over the player's
  # story keeps on (see MGQ_MpWorldStory.kept_unlock?).
  UNLOCK_SWITCHES = [EXTRA_ACCESSORY_SLOT]

  # First variable that holds a companion's affection, one per companion.
  AFFECTION_VARIABLES = 3000

  # The character whose story skills count, Luka.
  HERO = 1

  extend MGQ_MpLog

  # What starts this script's lines in the log, the same as coop_story.rbx's.
  LOG_TAG = "co-op story"

  # The topic that hands the rewards a party member catches up with, see PartyRewards in the DLL.
  REWARDS_TOPIC = "story.rewards"

  # The topic of the one-time repair of a save the 0.6.9.2 chest path left stuck, see StoryTopics.Repair in the DLL.
  REPAIR_TOPIC = "story.repair"

  # The topic of the side a player takes along in Iliasville, see SidePick in the DLL.
  SIDE_TOPIC = "catchup.side"

  # The topic of which of the leader's keys a Classic party member takes, see ClassicMerge.Follows
  # in the DLL.
  FOLLOW_TOPIC = "story.classic_follow"

  # The topic that writes the fields of a whole story, see ClassicStoryLists.Full in the DLL.
  FULL_TOPIC = "story.classic_full"

  # The variables' values a story carries; others are left out.
  CARRIED_VALUES = [Integer, Float, String, TrueClass, FalseClass]

  # The field of $game_system that keeps the side the player took along in Iliasville, which the
  # route sets anew in the side switches past the Great Decision: "alice" or "ilias"; "" while the
  # save holds the side of another player's starting save, so the player has not picked; nil while
  # unknown.
  PICK_FIELD = :@mgq_mp_pick

  # The field of $game_system that tells the save was found to come from another player's starting
  # save (note_other_start).
  OTHER_START_FIELD = :@mgq_mp_other_start

  # The field of $game_system that tells the save was repaired, or needs no repair.
  REPAIRED_FIELD = :@mgq_mp_repaired

  # Frames between two tries of the repair while the DLL cannot decide it yet, a second.
  REPAIR_FRAMES = 60

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

    # Reports whether a self switch is a chest's.
    #
    # @param key [Array] The self switch: map, event and letter.
    # @return [Boolean] Whether it is.
    def chest?(key)
      @chest_set ||= Hash[@chests.map { |chest| [chest, true] }]
      @chest_set.key?(key)
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
  #   on the map by default; a self switch of the player's own the player never set is left out.
  # @return [Array] The joined switches, variables and self switches.
  def self.mix(story, personal, chests = chest_keys)
    own = own_rule(story, personal)
    switches = story[0].dup
    variables = story[1].dup
    [personal[0].size, switches.size].max.times { |id| switches[id] = personal[0][id] if own.call(0, id) }
    [personal[1].size, variables.size].max.times { |id| variables[id] = personal[1][id] if own.call(1, id) }
    self_switches = story[2].dup
    (chests | (story[2].keys | personal[2].keys).select { |key| own.call(2, key) }).each do |key|
      if personal[2].key?(key)
        self_switches[key] = personal[2][key]
      else
        self_switches.delete(key)
      end
    end
    [switches, variables, self_switches]
  end

  # Finds which keys of two stories being joined stay the player's own: in a Raid World by the story
  # mapping, see personal_switch?; in a Classic party every key the DLL's rule of what a member takes
  # of the leader's story leaves out (classic_follows), asked once for every key either story holds.
  #
  # The game's lists may hold a value at 0, which names no switch or variable and makes the DLL
  # refuse the whole question.
  #
  # @param story [Array] The switches, variables and self switches of the story.
  # @param personal [Array] Those of the player.
  # @return [Proc] Takes a kind (0 switch, 1 variable, 2 self switch) and a key; answers whether it
  #   stays the player's own.
  def self.own_rule(story, personal)
    return lambda { |kind, key| kind == 0 ? personal_switch?(key, story[1]) : personal_key?(kind, key) } if MGQ_MpCoop::Scope.raid?

    keys = []
    2.times do |kind|
      (1...[story[kind].size, personal[kind].size].max).each { |id| keys << [kind, id] unless story[kind][id].nil? && personal[kind][id].nil? }
    end
    (story[2].keys | personal[2].keys).each { |key| keys << [2, key] }
    taken = {}
    classic_follows(keys).each_with_index { |follows, index| taken[keys[index]] = true if follows }
    lambda { |kind, key| !taken[[kind, key]] }
  end

  # Asks the DLL which of the leader's keys a Classic party member takes (ClassicMerge.Follows): those
  # of the leader's story, but the outcomes of the choices the player's own story keeps and what
  # this game's data lacks.
  #
  # @param keys [Array<Array>] [kind, key] each: 0 for a switch, 1 for a variable, 2 for a self switch.
  # @return [Array<Boolean>] Whether the player takes each; none while the DLL answers nothing.
  def self.classic_follows(keys)
    return [] if keys.empty?

    choices = defined?(MGQ_MpCoopChoices) ? MGQ_MpCoopChoices.personal_keys : { "s" => {}, "v" => {} }
    answer = MGQ_Multiplayer::Bridge.call(FOLLOW_TOPIC, "keys" => keys, "choices" => { "s" => choices["s"].keys, "v" => choices["v"].keys },
                                                        "sizes" => [$data_system.switches.size, $data_system.variables.size])
    answer.is_a?(Array) ? answer : []
  end

  # Reports whether a switch is the player's own: in a Raid World by its story mapping
  # (MGQ_MpStoryKeys), whose side switches are the player's own until the Great Decision; in a
  # Classic party unless the reviewed list makes it the leader's story (classic_world?), and also
  # the outcomes of the member's own choices.
  #
  # @param id [Integer] The switch.
  # @param variables [Array, nil] The variables of the story it belongs to, nil for the one played.
  # @return [Boolean] Whether it is.
  def self.personal_switch?(id, variables = nil)
    return !MGQ_MpStoryKeys.shared?(0, id, variables) if MGQ_MpCoop::Scope.raid?

    !classic_world?(0, id) || choice_key?(:s, id)
  end

  # Reports whether a key is the leader's story in a Classic party: a world key by the scopes of
  # the reviewed list (MGQ_MpStoryKeys.scope_of), which the leader's story mirrors to every member
  # who follows it. Every other key, a chest's too, is each member's own.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Boolean] Whether it is; false before the list came.
  def self.classic_world?(kind, key)
    MGQ_MpStoryKeys.scope_of(kind, key) == MGQ_MpStoryKeys::SCOPE_WORLD
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
    now = MGQ_Multiplayer::Bridge.frame_number
    return @rewards if @rewards_at && now - @rewards_at < (@rewards ? REWARDS_FRAMES : MISSING_FRAMES)

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

  # Reports whether a variable is the player's own, see personal_switch?.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it is.
  def self.personal_variable?(id)
    return !MGQ_MpStoryKeys.shared?(1, id) if MGQ_MpCoop::Scope.raid?

    !classic_world?(1, id) || choice_key?(:v, id)
  end

  # Reports whether a self switch is the player's own, see personal_switch?; in a Classic party
  # also one of a choice's lines, through coop_choices.rbx.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @return [Boolean] Whether it is.
  def self.personal_self_switch?(key)
    return !MGQ_MpStoryKeys.shared?(2, key) if MGQ_MpCoop::Scope.raid?

    !classic_world?(2, key)
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
    MGQ_MpStoryIds.route_variables.all? { |id| variables[id].to_i == 0 }
  end

  # The side some switches tell.
  #
  # @param switches [Array] The switches.
  # @return [Symbol, nil] :alice, :ilias, or nil for none.
  def self.side_of(switches)
    return :alice if switches[MGQ_MpStoryIds.alice_chosen]
    return :ilias if switches[MGQ_MpStoryIds.ilias_chosen]

    nil
  end

  # Reads the side the save notes the player took along in Iliasville, see PICK_FIELD.
  #
  # @return [String, nil] "alice", "ilias", "" or nil.
  def self.pick_note
    $game_system ? $game_system.instance_variable_get(PICK_FIELD) : nil
  end

  # Notes the side the player took along in Iliasville.
  #
  # @param side [Symbol] :alice or :ilias.
  def self.note_pick(side)
    return unless $game_system && side

    $game_system.instance_variable_set(PICK_FIELD, side.to_s)
    log("noted in the save that the player took #{side} along in Iliasville")
  end

  # Finds the side the player took along in Iliasville by their own story, as the DLL decides it,
  # and notes it in the save when the DLL says so.
  #
  # @param switches [Array] The player's own switches.
  # @param variables [Array] The player's own variables.
  # @return [Symbol, nil] :alice, :ilias, or nil while it is unknown or the DLL answers nothing.
  def self.own_pick(switches, variables)
    answer = side_answer("own" => side_story(switches, variables))
    return nil unless answer

    note_pick(answer["note"].to_sym) if answer["note"]
    answer["side"] ? answer["side"].to_sym : nil
  end

  # Asks the DLL about the side the player takes along, with the save's note.
  #
  # @param fields [Hash] "own" (see side_story) and what else SidePick in the DLL reads: "played",
  #   "leader" and "chose".
  # @return [Hash, nil] The answer, nil while the DLL answers none.
  def self.side_answer(fields)
    answer = MGQ_Multiplayer::Bridge.call(SIDE_TOPIC, { "note" => pick_note }.merge(fields))
    answer.is_a?(Hash) ? answer : nil
  end

  # Reads what the side's rule reads of a story: the side switches, the routes' clear switches and
  # how far the story is, as the catch-up's snapshot holds a story.
  #
  # @param switches [Array] The story's switches.
  # @param variables [Array] The story's variables.
  # @return [Hash] "s", "v" and "ss".
  def self.side_story(switches, variables)
    ids = MGQ_MpStoryIds
    { "s" => (ids.side_switches + ids.clear_switches).select { |id| switches[id] }, "v" => ids.markers.map { |id| [id, variables[id].to_i] }, "ss" => [] }
  end

  # Notes the side the player took along from the story they play, while it is their own: never
  # while a Classic member plays the leader's. Called after each transfer, so a save played alone
  # notes it before the Great Decision too.
  def self.note_live_pick
    return if !$game_switches || !$game_variables || (defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.guest?)

    own_pick(data_of($game_switches), data_of($game_variables))
  rescue => e
    log_once(:note_live_pick, "noting the side the player took along failed: #{e.class}: #{e.message}")
  end

  # Notes, once per save, that it came from another player's starting save: the side its switches
  # hold is that player's, so the player is asked whom they take along instead.
  def self.note_other_start
    return if !$game_system || $game_system.instance_variable_get(OTHER_START_FIELD)

    $game_system.instance_variable_set(OTHER_START_FIELD, true)
    side = $game_switches ? side_of(data_of($game_switches)) : nil
    $game_system.instance_variable_set(PICK_FIELD, side ? "" : nil)
    log(side ? "the save came from another player's starting save with their side: the player has not picked" : "the save came from another player's starting save before the choice of a side")
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
  # own, see MGQ_MpCoopStory.own_with_values. The DLL packs the lists, and one too large for a
  # message leaves out what the story turned off or set to zero, and says so.
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [Hash] The message's fields: the lists under "z", and "part" true for a story that
  #   leaves out what it turned off.
  # @raise [RuntimeError] When the DLL wrote none.
  def self.full(story)
    fields = MGQ_Multiplayer::Bridge.call(FULL_TOPIC, story_lists(story))
    raise "the DLL wrote no whole story" unless fields.is_a?(Hash)

    log_once(:full_size, "the whole story was too large for a message, so it leaves out what the story turned off") if fields["part"]
    fields
  end

  # Lists a story for a message: the switches on and off under "s" and "sf", the variables set
  # under "v", and the self switches on and off under "ss" and "ssf".
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [Hash{String => Array}] The lists: ids, [id, value] pairs and self switches' keys.
  def self.story_lists(story)
    switches = (0...story[0].size).reject { |id| story[0][id].nil? || personal_switch?(id) }
    variables = (0...story[1].size).reject { |id| story[1][id].nil? || personal_variable?(id) || !carried?(story[1][id]) }
    self_switches = story[2].keys.reject { |key| story[2][key].nil? }
    switches_on, switches_off = switches.partition { |id| story[0][id] }
    self_on, self_off = self_switches.partition { |key| story[2][key] }
    { "s" => switches_on, "sf" => switches_off, "v" => variables.map { |id| [id, plain_variable(story[1][id])] }, "ss" => self_on, "ssf" => self_off }
  end

  # Reports whether a story carries a variable's value: only the kinds a message carries safely, so
  # no message can make objects in the other game.
  #
  # @param value [Object] The value.
  # @return [Boolean] Whether it does.
  def self.carried?(value)
    CARRIED_VALUES.any? { |kind| value.is_a?(kind) }
  end

  # Reads a whole story another game wrote.
  #
  # @param message [Hash] The message, its lists under "z".
  # @return [Array] The switches, variables and self switches.
  def self.decode_full(message)
    lists = message["z"].is_a?(Hash) ? message["z"] : {}
    switches = []
    Array(lists["s"]).each { |id| switches[id] = true if story_id?(:switches, id) }
    Array(lists["sf"]).each { |id| switches[id] = false if story_id?(:switches, id) }
    variables = []
    entries(lists["v"]).each { |id, value| variables[id] = variable_value(value) if story_id?(:variables, id) }
    self_switches = {}
    Array(lists["ss"]).each { |key| self_switches[key] = true if self_switch_key?(key) }
    Array(lists["ssf"]).each { |key| self_switches[key] = false if self_switch_key?(key) }
    [switches, variables, self_switches]
  end

  # Reads what of a story changed, see ClassicStoryLists.Delta in the DLL.
  #
  # @param message [Hash] The message.
  # @return [Array<Array>] The changed switches, variables and self switches, each by key.
  def self.decode_delta(message)
    [
      entries(message["s"]).select { |id, _| story_id?(:switches, id) }.map { |id, on| [id, on == true] },
      entries(message["v"]).select { |id, _| story_id?(:variables, id) }.map { |id, value| [id, variable_value(value)] },
      entries(message["ss"]).select { |key, _| self_switch_key?(key) }.map { |key, on| [key, on == true] },
    ]
  end

  # Lists the pairs of a list another game sent, leaving out what is no pair.
  #
  # @param list [Object] The list.
  # @return [Array<Array>] The pairs.
  def self.entries(list)
    list.is_a?(Array) ? list.select { |entry| entry.is_a?(Array) && entry.size == 2 } : []
  end

  # Reports whether a value another game sent is the id of one of this game's switches, variables
  # or items, see known_id?.
  #
  # @param kind [Symbol] :switches, :variables or :items.
  # @param id [Object] The value.
  # @return [Boolean] Whether it is.
  def self.story_id?(kind, id)
    id.is_a?(Integer) && known_id?(kind, id)
  end

  # Reports whether a value another game sent is a self switch's key: map, event and letter.
  #
  # @param key [Object] The value.
  # @return [Boolean] Whether it is.
  def self.self_switch_key?(key)
    key.is_a?(Array) && key.size == 3 && key[0].is_a?(Integer) && key[1].is_a?(Integer) && key[2].is_a?(String)
  end

  # Reads a variable's value another game sent: a Float comes as the DLL's Hash of its text, since
  # the bridge hands the scripts no Floats (MessageFields.FloatKey in the DLL).
  #
  # @param value [Object] The value.
  # @return [Object] The value, nil for one no story carries.
  def self.variable_value(value)
    return value["float"].to_s.to_f if value.is_a?(Hash)

    carried?(value) ? value : nil
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

  # Turns a variable's value into what the bridge carries for the DLL, which writes it as the tracks
  # keep it (StoryPlain in the DLL): a Float as a Hash of its text, since the bridge carries no Floats.
  #
  # @param value [Object] The value.
  # @return [Object] The value, nil for a kind no story carries.
  def self.plain_variable(value)
    return { "float" => value.to_s } if value.is_a?(Float)

    carried?(value) ? value : nil
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

  # Repairs a save the 0.6.9.2 chest path left stuck, once per save ("Issue 73 chest effects.md",
  # E2): the DLL names the switches its chests prove on that the save holds off, the player's own
  # alone in a world, and they are turned on, a log line each and no notice. A save the plain game
  # made holds none. Tried after the map's update until the DLL could decide it.
  def self.repair
    return unless @repair_due && $game_system && MGQ_Multiplayer::Bridge.open? && defined?(MGQ_MpStoryReplay)
    return if @repair_at && MGQ_Multiplayer::Bridge.frame_number - @repair_at < REPAIR_FRAMES

    @repair_at = MGQ_Multiplayer::Bridge.frame_number
    raid = defined?(MGQ_MpCoop::Scope) && MGQ_MpCoop::Scope.raid? ? true : false
    world = raid || (defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.in_world?) ? true : false
    answer = MGQ_MpStoryReplay.ask_with_values(REPAIR_TOPIC, "world" => world, "raid" => raid)
    return unless answer.is_a?(Hash) && answer["switches"]

    MGQ_MpStoryKeys.as("repair") do
      answer["switches"].each do |id|
        $game_switches[id] = true
        log("repaired the save: turned switch #{id} on, which a chest the save holds shut turns on")
      end
    end
    $game_system.instance_variable_set(REPAIRED_FIELD, true)
    @repair_due = false
  rescue => e
    log_once([:repair, e.class], "repairing the save failed: #{e.class}: #{e.message}")
  end

  # Turns the warp ban off again while a world is open, past the game's own handling, so the write
  # reaches no hook. Called after a write of a switch and after a save loaded.
  #
  # A world moves players past the events that set and lift the ban, and the teleport to the story
  # brings back a player whom a warp took away from it.
  #
  # @param switches [Game_Switches] The switches written to or loaded.
  # @param reason [String] How the ban came on, for the log, which names it once per map.
  def self.lift_warp_ban(switches, reason)
    return unless defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.in_world?

    data = data_of(switches)
    return unless data[WARP_BAN]

    data[WARP_BAN] = false
    map = $game_map ? $game_map.map_id : 0
    log_once([:warp_ban, reason, map], "turned the warp ban off on map #{map}: #{reason}")
  end

  # Notes whether a save loaded or a new game still needs the repair: a new game never does.
  #
  # @param new_game [Boolean] Whether a new game started.
  def self.repair_check(new_game)
    $game_system.instance_variable_set(REPAIRED_FIELD, true) if new_game && $game_system
    @repair_due = $game_system && !$game_system.instance_variable_get(REPAIRED_FIELD) ? true : false
    @repair_at = nil
  end

  # Says how far a story is for the log: the main story and the three routes' progress.
  #
  # @param variables [Array] The story's variables.
  # @return [String] Such as "main story 12, routes 0/0/0".
  def self.progress_text(variables)
    "main story #{variables[MGQ_MpStoryIds.main_progress].to_i}, routes #{MGQ_MpStoryIds.route_variables.map { |id| variables[id].to_i }.join('/')}"
  rescue
    "unknown progress"
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # A save's first load in this build repairs it once the player is on the map; a new game needs
  # none. A save loaded in a world holds no warp ban there, while a new game starts without one.
  if defined?(DataManager)
    MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "story_state") do |_contents|
      MGQ_MpStoryState.repair_check(false)
      MGQ_MpStoryState.lift_warp_ban($game_switches, "the loaded save held it")
    end
    MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "story_state") { MGQ_MpStoryState.repair_check(true) }
  end
  MGQ_MpHooks.after(Game_Map, :update, "story_state") { |*_args| MGQ_MpStoryState.repair }
  MGQ_MpHooks.after(Game_Player, :perform_transfer, "story_state") { |*_args| MGQ_MpStoryState.note_live_pick } if defined?(Game_Player)
rescue => e
  MGQ_MpStoryState.log("repair hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # A world never bans warping, whatever writes the ban, a replay's commit too.
  MGQ_MpHooks.after(Game_Switches, :[]=, "story_state") { |id, _value| MGQ_MpStoryState.lift_warp_ban(self, "a write turned it on") if id == MGQ_MpStoryState::WARP_BAN }
rescue => e
  MGQ_MpStoryState.log("warp ban hook FAILED: #{e.class}: #{e.message}")
end
