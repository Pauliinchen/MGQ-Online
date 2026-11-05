#----------------------------------------------------------------
#  story_keys.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Handed the DLL every key as [kind, key], every value as itself and every site as [kind, ...], and looked self switches up in the rows of rules it hands, so only the DLL writes and reads the tracks' texts
#                            - Read the story markers from story_ids.rbx
#                            - Noted the found items a run gave or used up, but none a story reset takes, so a run that changed no shared key is handed over too
#                            - Dropped the names of the commands running, which only the found items' rule read
#                            - Handed the found items a battle's drops gave to the DLL, and their entry on like a run's
#                            - Counted its timers by the bridge's frame
#      Paulinchen  2026-11-01: Noted a run's checks of what the party holds and of the event's own self switches as inputs, which a replay follows
#                            - Named every command running now, which tells one use of an item from another
#                            - Told whether a command runs inside a story reset, whose losses use nothing up
#                            - Noted a choice at its Show Choices command, and every input by its command's place among the kept commands
#                            - Noted an extended choice at the script command that shows it
#      Paulinchen  2026-10-31: Bracketed each run of the player's own game with its shared writes, start values, inputs and resets
#                            - Logged each run that changed a party or world key with the DLL
#                            - Told whether a run belongs to a party chest's page
#                            - Handed every run that changed a shared key to the DLL, and its entry on to the world's or the party's story
#      Paulinchen  2026-10-28: Asked the DLL for a Classic party's table, which it builds from the events database and the story mapping
#                            - Built a Classic party's table anew once the chest flags came with the story mapping
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# The story's keys as the multiplayer shares them: the table that tells how each switch, variable
# and self switch is shared (a Raid World's story mapping, or a Classic party's table, both built by
# the DLL), the one hook on the game's writes that the telling's scene mirroring and the story's
# requests share, which names the event that wrote, and the guard that keeps the values the
# multiplayer writes itself from counting as the player's own.
#
# Each write is looked up in the table in Ruby, a byte per switch and per variable, so a frame of
# thousands of writes (the Final Chapter's reset) costs no call of the DLL per write; the writes a
# story records go out once a frame, before Graphics.update.
#
# A key goes to the DLL as [kind, key], a value as itself, a Float tagged, and a site as ["map", map,
# event, page], ["ce", id], ["game"] or ["game", what] (StoryPlain in the DLL, which alone writes and
# reads the texts the relay's tracks and the save's log keep).
#
# Each run of the player's own game, one start of a map page or of a common event that runs by
# itself with every common event it calls, is bracketed ("Issue 73 chest effects.md", "General
# model"): the party and world keys it changed with their values before, the start values of the
# world and work keys it read, the inputs of its player and the resets it made. A run that changed a
# party or world key is logged with the DLL, which answers the entry to hand over when it gives,
# see run_ended.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpStoryKeys
  # A class's bit: kept on a track, so every write of the key is a request.
  KEPT = 1

  # A class's bit: kept, and only ever goes up.
  ONE_WAY = 2

  # A class's bit: on only while a scene runs, shown to viewers and never kept.
  SCENE = 4

  # A class's bit: a chest's, each player's own, kept with the player on the relay.
  CHEST = 8

  # A class's bit: a count the relay keeps itself.
  COUNT = 16

  # A class's bit: kept for the whole world, players behind included.
  WHOLE_WORLD = 32

  # A class's bit: the post-defeat processing writes it.
  DEFEAT_WRITE = 64

  # A class's bit: a Classic world's side switch, each player's own while the sides still differ.
  SIDE = 128

  # The bits of a key whose writes a Raid World's story sends as requests.
  REQUESTED = KEPT | CHEST

  # The topic that hands out the story mapping's table.
  CLASSES_TOPIC = "story.classes"

  # The topic that builds a Classic party's table.
  CLASSIC_TOPIC = "story.classic_table"

  # The topic a frame's writes go to the DLL by.
  WRITES_TOPIC = "story.writes"

  # The topics of runs handed over by replay, see StoryTopics.Replay.cs in the DLL: who keeps each
  # key, the keys whose start values a run carries, a run's end, the resets of the player's runs and
  # a battle's drops.
  SCOPES_TOPIC = "story.replay_scopes"
  READS_TOPIC = "story.replay_reads"
  RAN_TOPIC = "story.replay_ran"
  RESET_TOPIC = "story.replay_reset"
  DROP_TOPIC = "story.replay_drop"

  # Who keeps a key, as story.replay_scopes names it: each player, the game's work, the Classic
  # party, the world's story, or the whole world.
  SCOPE_PLAYER = 0
  SCOPE_WORK = 1
  SCOPE_PARTY = 2
  SCOPE_WORLD = 3
  SCOPE_WHOLE_WORLD = 4

  # The scopes whose keys a replay reads at the run's start values: the work's and the world's.
  VIEWED = [SCOPE_WORK, SCOPE_WORLD, SCOPE_WHOLE_WORLD]

  # Frames between two asks for the scopes while the DLL has none, and between two tries of a run's
  # end the DLL could not log yet: half a second and a second.
  SCOPES_ASK_FRAMES = 30
  UNSENT_FRAMES = 60

  # Every map, as a reset of self switches by Game_SelfSwitches.new covers them.
  ALL_MAPS = 999_999

  # A run of the player's own game: its site and place; the party, world and work keys it wrote,
  # each with its scope and value before its first write; the world and work keys anything wrote
  # while it ran, each with its value before; its inputs, counted by command and kind; the keys
  # scripts read during it; its resets; the self switches object it started with; and how many of
  # each found item it gave or used up, by the item's id.
  Run = Struct.new(:site, :place, :before, :starts, :inputs, :counts, :reads, :resets, :self_switches, :found)

  # The tag at the start of the description of an item the game files with the key items but tags as
  # a plain item, in the translation and the untranslated game: the Small and Large Medals, which stay
  # each player's own.
  PLAIN_ITEM_TAG = /\A\s*(\[Item\]|【道具】)/

  # What an event's place in a table's index is made of: map * EVENT_SPAN + event.
  EVENT_SPAN = 1_000_000

  # The writes one frame keeps at most, past the largest frame the game was seen to write (the
  # Final Chapter's reset, about 1,900), so a runaway parallel event cannot fill the memory.
  MAX_BATCH = 8000

  # A table: its revision, the class of each switch and variable as bytes, the self switch rules (see
  # rules_of), the indexed events, the local steps by variable, the parts' gates, the class of a self
  # switch no rule names, and the ids of the switches and variables kept on a track.
  Table = Struct.new(:rev, :switches, :variables, :self_rules, :index, :local_steps, :gates, :self_default, :kept_switches, :kept_variables)

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "story keys"

  # The story mapping's table, nil before it came.
  @raid = nil

  # A Classic party's table, built once it is first needed.
  @classic = nil

  # Whether the DLL was asked for the Classic party's table.
  @classic_asked = false

  # The serial of the rewards a party member catches up with that the Classic party's table was
  # asked at.
  @classic_serial = nil

  # Where the writes recorded go: :raid, :classic or nil for nowhere.
  @recording = nil

  # The writes recorded this frame, each [kind, key, value, site].
  @batch = []

  # The writes of a Raid World's story made before its mapping came, each [kind, key, value, site],
  # which the mapping sorts once it comes.
  @unsorted = []

  # How deep the multiplayer's own writes go, which are no writes of the player's.
  @applying = 0

  # The interpreters running a command, innermost last, of the interpreter being updated.
  @running = []

  # The place each of those commands started at, in the same order.
  @indexes = []

  # The running interpreters and their places of each interpreter whose update a wait left, by its
  # object id.
  @stacks = {}

  # The runs open, by their interpreter's object id.
  @runs = {}

  # What holds each interpreter of the map that set up a list, by the interpreter's object id: the
  # map for its own, a map event or a parallel common event.
  @holders = {}

  # The scopes the DLL handed, with what they were asked for; nil before.
  @scopes = nil

  # The run whose script runs now, whose reads it notes; nil while none does.
  @script_run = nil

  # The run and command of a present the player chooses now; nil while none is chosen.
  @present_at = nil

  # The run, command, kind and variable of a number or item input the message waits for; nil while
  # it waits for none.
  @message_input = nil

  # The ends of runs the DLL could not log yet, as they were asked, oldest first.
  @unsent = []

  # What a write outside every interpreter is told as, nil for the game itself.
  @origin = nil

  # The found items a battle's drops gave, by the item's id, while the game hands the drops out; nil
  # otherwise.
  @drops = nil

  # Reads a table the DLL built.
  #
  # @param hash [Hash] The table, see StoryTopics.TableOf in the DLL.
  # @return [Table] The table.
  def self.table_of(hash)
    index = {}
    hash["index"].each { |code| index[code] = true }
    local = {}
    hash["local_steps"].each { |variable, steps, shared_as, places| local[variable] = [steps, shared_as, places] }
    switches = hash["switches"].to_s
    variables = hash["variables"].to_s
    Table.new(hash["rev"].to_i, switches, variables, rules_of(hash), index, local, hash["gates"] || {}, hash["self_default"].to_i,
              kept_ids(switches), kept_ids(variables))
  end

  # Reads the self switch rules the DLL hands with a table or the scopes, see StoryPlain.SelfRules in
  # the DLL.
  #
  # @param hash [Hash] "self" ([map, event, letter, what] each) and "common" ([common event, letter,
  #   what] each), nil standing for every event or letter.
  # @return [Array<Hash>] What each rule names: the map's rules by [map, event, letter] and the
  #   common events' by [common event, letter].
  def self.rules_of(hash)
    maps = {}
    Array(hash["self"]).each { |map, event, letter, what| maps[[map, event, letter]] = what }
    commons = {}
    Array(hash["common"]).each { |common, letter, what| commons[[common, letter]] = what }
    [maps, commons]
  end

  # Finds the most fitting self switch rule: its own, its event's, the common event's that wrote it,
  # its map's letter's, its map's.
  #
  # @param rules [Array<Hash>] The rules, see rules_of.
  # @param key [Array] The self switch's map, event and letter.
  # @param site [Array, nil] Where the write came from, which a common event's rule reads.
  # @return [Object, nil] What the rule names, nil for none.
  def self.rule_of(rules, key, site)
    maps, commons = rules
    return nil if maps.empty? && commons.empty?

    map, event, letter = key
    common = site && site[0] == "ce" ? site[1] : nil
    maps[[map, event, letter]] || maps[[map, event, nil]] || (common && (commons[[common, letter]] || commons[[common, nil]])) ||
      maps[[map, nil, letter]] || maps[[map, nil, nil]]
  end

  # Lists the ids whose class keeps them on a track.
  #
  # @param bytes [String] The classes by id.
  # @return [Array<Integer>] The ids.
  def self.kept_ids(bytes)
    ids = []
    bytes.bytesize.times { |id| ids << id if bytes.getbyte(id) & KEPT != 0 }
    ids
  end

  # Takes the story mapping's table the DLL holds now.
  #
  # @return [Boolean] Whether it came.
  def self.load_raid
    hash = MGQ_Multiplayer::Bridge.call(CLASSES_TOPIC)
    return false unless hash

    @raid = table_of(hash)
    log("read the story mapping at revision #{@raid.rev}: #{@raid.kept_switches.size} switches and #{@raid.kept_variables.size} variables kept, " \
        "#{@raid.self_rules[0].size + @raid.self_rules[1].size} self switch rules, #{@raid.index.size} events indexed")
    sort_unsorted
    true
  rescue => e
    log("reading the story mapping failed: #{e.class}: #{e.message}")
    false
  end

  # The story mapping's table.
  #
  # @return [Table, nil] The table, nil before it came.
  def self.raid_table
    @raid
  end

  # Forgets the story mapping's table, as the world closed.
  def self.forget_raid
    @raid = nil
    @unsorted = []
  end

  # Records the writes a Raid World's story made before its mapping came, by the mapping now.
  def self.sort_unsorted
    unsorted = @unsorted
    @unsorted = []
    kept = unsorted.select { |kind, key, _value, site| class_of(kind, key, site, @raid) & REQUESTED != 0 }
    kept.each { |kind, key, value, site| add(kind, key, value, site) }
    log("recorded #{kept.size} of the #{unsorted.size} writes made before the story mapping came") unless unsorted.empty?
  end

  # A Classic party's table, built by the DLL from the game's counts in its events database and the
  # chest flags of the story mapping it holds (its events database's before one came), asked once
  # the bridge is open and again once the rewards a party member catches up with changed.
  #
  # @return [Table, nil] The table, nil while the DLL builds none.
  def self.classic_table
    serial = MGQ_MpStoryState.rewards_serial
    return @classic if @classic_asked && @classic_serial == serial
    return nil unless MGQ_Multiplayer::Bridge.open?

    hash = MGQ_Multiplayer::Bridge.call(CLASSIC_TOPIC)
    @classic_asked = true
    @classic_serial = serial
    @classic = hash ? table_of(hash) : nil
    log("the DLL builds no Classic party's table, so a Classic party shares no story") unless @classic
    @classic
  rescue => e
    log_once(:classic_table, "building the Classic party's table failed: #{e.class}: #{e.message}")
    nil
  end

  # The table the open world shares its story by: a Raid World's story mapping, a Classic party's
  # table elsewhere and in a Raid World until its mapping came, so the events still sort as story
  # meanwhile.
  #
  # @return [Table, nil] The table, nil while the DLL builds none.
  def self.table
    MGQ_MpCoop::Scope.raid? && @raid ? @raid : classic_table
  end

  # Finds a key's class in a table: a switch's or variable's byte, a self switch's most fitting
  # rule (its own, its event's, the common event's that wrote it, its map's letter's, its map's),
  # else the class of its indexed event or the table's default.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
  # @param site [Array, nil] Where the write came from, which a common event's rule reads.
  # @param table [Table, nil] The table, the open world's by default.
  # @return [Integer] The class, 0 for each player's own and while no table came.
  def self.class_of(kind, key, site = nil, table = self.table)
    return 0 unless table
    return (kind == 0 ? table.switches : table.variables).getbyte(key).to_i if kind < 2 && key.is_a?(Integer) && key >= 0

    return 0 unless key.is_a?(Array) && key.size == 3

    found = rule_of(table.self_rules, key, site)
    return found if found

    table.index[key[0].to_i * EVENT_SPAN + key[1].to_i] ? KEPT : table.self_default
  rescue
    0
  end

  # Reports whether a key is shared by the open world's table: kept on a track, a side switch only
  # once the sides no longer differ.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @param variables [Array, nil] The variables of the story it belongs to, for the sides' rule.
  # @return [Boolean] Whether it is.
  def self.shared?(kind, key, variables = nil)
    found = class_of(kind, key)
    return false if found & KEPT == 0

    found & SIDE == 0 || !MGQ_MpStoryState.sides_differ?(variables)
  end

  # Reports whether a key has a bit in the open world's table.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @param bit [Integer] The bit, such as SCENE.
  # @return [Boolean] Whether it has.
  def self.bit?(kind, key, bit)
    class_of(kind, key) & bit != 0
  end

  # Sets where the writes recorded go: a Raid World's story, a Classic party leader's, or nowhere.
  #
  # @param mode [Symbol, nil] :raid, :classic or nil.
  def self.recording=(mode)
    return if mode == @recording

    @batch = [] if mode.nil? || !@recording.nil?
    @recording = mode
  end

  # Where the writes recorded go.
  #
  # @return [Symbol, nil] :raid, :classic or nil.
  def self.recording
    @recording
  end

  # Writes the multiplayer's own values, such as the relay's pushes or a teller's scene, which never
  # count as the player's writes.
  #
  # @yield Writes the values.
  # @return [Object] What the block returns.
  def self.applying
    @applying += 1
    yield
  ensure
    @applying -= 1
  end

  # Reports whether the multiplayer writes its own values now.
  #
  # @return [Boolean] Whether it does.
  def self.applying?
    @applying > 0
  end

  # Tells writes outside every interpreter as made by a part of the game, such as the catch-up.
  #
  # @param what [String] What writes, of a-z and _, such as "catchup".
  # @yield Writes the values.
  # @return [Object] What the block returns.
  def self.as(what)
    outer = @origin
    @origin = ["game", what]
    yield
  ensure
    @origin = outer
  end

  # Keeps the stack of running interpreters of the interpreter whose update runs, apart from those of
  # the others: a wait inside a command leaves the update with the command still running.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @yield The update.
  def self.updating(interpreter)
    outer = [@running, @indexes]
    @running, @indexes = @stacks.delete(interpreter.object_id) || [[], []]
    yield
  ensure
    @stacks[interpreter.object_id] = [@running, @indexes] unless @running.empty?
    @running, @indexes = outer
  end

  # Notes the interpreter that starts a command and the command's place, so a write it makes names
  # its event and an input its command.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.executing(interpreter)
    @running.push(interpreter)
    @indexes.push(MGQ_MpGame.get(interpreter, :index).to_i)
  end

  # Notes that an interpreter's command ended.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.executed(interpreter)
    return unless @running.last.equal?(interpreter)

    @running.pop
    @indexes.pop
  end

  # Takes a write of the game's switches, variables or self switches: the scene a teller shows takes
  # it, and the story that records takes a write of a key it shares, with the event that wrote it; a
  # Raid World's at the value a frozen raid boss fight holds it at (MGQ_MpWorldStory.held_value).
  # Nothing is recorded of the multiplayer's own writes (applying?), nor of a lost battle's defeat
  # scene, which sets back what its event set before the battle.
  #
  # @param object [Game_Switches, Game_Variables, Game_SelfSwitches] What was written to.
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
  # @param value [Object] The value written.
  def self.written(object, kind, key, value)
    return unless object.equal?(kind == 0 ? $game_switches : kind == 1 ? $game_variables : $game_self_switches)

    MGQ_MpCoopScene.story_value(kind, key, value) if defined?(MGQ_MpCoopScene)
    return if @recording.nil? || @applying > 0 || defeat_running?

    site = site_of(@running.last)
    if @recording == :classic
      return if MGQ_MpStoryState.personal_key?(kind, key)
    else
      value = MGQ_MpWorldStory.held_value(kind, key, value) if defined?(MGQ_MpWorldStory)
      return @unsorted << [kind, key, value, site] if @raid.nil? && @unsorted.size < MAX_BATCH
      return if @raid.nil? || class_of(kind, key, site, @raid) & REQUESTED == 0
    end
    add(kind, key, value, site)
  rescue => e
    log_once([:written, e.class], "recording a story write failed: #{e.class}: #{e.message}")
  end

  # Adds a write to the frame's writes.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
  # @param value [Object] The value written.
  # @param site [Array] Where it came from, see site_of.
  def self.add(kind, key, value, site)
    if @batch.size >= MAX_BATCH
      return log_once([:batch_full, MGQ_Multiplayer::Bridge.frame_number / 600], "dropped writes past #{MAX_BATCH} in one frame")
    end

    plain = plain_of(kind, value)
    @batch << [kind, key, plain, site] unless plain.nil?
  end

  # Reports whether a lost battle's defeat runs: a novel scene, as after a lost story battle, or a
  # lost raid boss battle's defeat (battles_raid_freeze.rbx), whose writes go nowhere.
  #
  # @return [Boolean] Whether one runs.
  def self.defeat_running?
    (defined?(Scene_Novel) && SceneManager.scene.is_a?(Scene_Novel)) || (defined?(MGQ_MpRaidFreeze) && MGQ_MpRaidFreeze.holding_writes?) ? true : false
  rescue
    false
  end

  # Turns a value into what the DLL takes, see StoryPlain in the DLL: a switch's or self switch's as
  # true or false, a variable's as MGQ_MpStoryState.plain_variable hands it, nil as 0.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param value [Object] The value.
  # @return [Object] The value, nil for a variable whose value no story carries, such as a list.
  def self.plain_of(kind, value)
    return value ? true : false unless kind == 1

    MGQ_MpStoryState.plain_variable(value.nil? ? 0 : value)
  end

  # Turns a value the DLL handed back into the game's, see plain_of.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param value [Object] The value.
  # @return [Object] The value.
  def self.game_value(kind, value)
    kind == 1 ? MGQ_MpStoryState.variable_value(value) : value == true
  end

  # Names where a write comes from: the common event whose commands run, the page of the map event
  # whose commands run, the troop's battle event, or the game itself.
  #
  # @param interpreter [Game_Interpreter, nil] The interpreter running a command, nil for none.
  # @return [Array] Such as ["map", 7, 39, 1], ["ce", 154], ["game", "troop"] or ["game"].
  def self.site_of(interpreter)
    return @origin || ["game"] unless interpreter

    list = MGQ_MpGame.get(interpreter, :list)
    common = common_event_of(list)
    return ["ce", common] if common

    event_id = MGQ_MpGame.get(interpreter, :event_id).to_i
    map_id = MGQ_MpGame.get(interpreter, :map_id).to_i
    return ["game", "troop"] if $game_troop && interpreter.equal?($game_troop.interpreter)
    return ["game", "event"] unless event_id > 0 && map_id > 0

    ["map", map_id, event_id, page_of(map_id, event_id, list)]
  rescue
    ["game"]
  end

  # Finds the common event whose commands a list is.
  #
  # @param list [Array, nil] The commands.
  # @return [Integer, nil] The common event, nil for another list.
  def self.common_event_of(list)
    return nil unless list && $data_common_events

    unless @common_lists && @common_lists_of.equal?($data_common_events)
      lists = {}
      $data_common_events.each_with_index { |event, id| lists[event.list.object_id] = id if event && event.list }
      @common_lists_of = $data_common_events
      @common_lists = lists
    end
    @common_lists[list.object_id]
  end

  # Finds the page of a map event whose commands a list is, counted from 1.
  #
  # @param map_id [Integer] The map.
  # @param event_id [Integer] The event.
  # @param list [Array, nil] The commands.
  # @return [Integer] The page, 1 when it cannot be told.
  def self.page_of(map_id, event_id, list)
    event = $game_map && $game_map.map_id == map_id ? $game_map.events[event_id] : nil
    index = event && list ? event.mgq_mp_pages.index { |page| page.list.equal?(list) } : nil
    index ? index + 1 : 1
  rescue
    1
  end

  # Takes the writes recorded this frame, which their story sends: a Raid World's to the DLL, a
  # Classic leader's to the party (coop_story.rbx). Called before every frame's Graphics.update.
  def self.flush
    send_unsent
    return if @batch.empty?

    batch = @batch
    @batch = []
    case @recording
    when :raid then MGQ_Multiplayer::Bridge.stage(WRITES_TOPIC, batch)
    when :classic then MGQ_MpCoopStory.recorded(batch) if defined?(MGQ_MpCoopStory)
    end
  rescue => e
    log_once(:flush, "handing over the story's writes failed: #{e.class}: #{e.message}")
  end

  # Asks the relay for a value of the player's own outside the game's writes, such as a frozen raid
  # boss fight or a value the relay handed lower, with the frame's writes.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch, 3 for a frozen fight.
  # @param key [Integer, Array] Its id, a self switch's map, event and letter, or a frozen fight's troop.
  # @param value [Object] Its value: a frozen fight's text, any other as the game holds it.
  # @param site [Array] Where it comes from, ["game"] or ["game", what].
  # @return [Boolean] Whether it goes with the frame's writes: false unless a Raid World's story records.
  def self.request(kind, key, value, site)
    plain = kind == 3 ? value : plain_of(kind, value)
    return false unless @recording == :raid && !plain.nil?

    @batch << [kind, key, plain, site]
    true
  end

  # Drops the writes recorded this frame and the runs open, as a loaded save or a new game bring
  # their own story.
  def self.drop
    @batch = []
    @unsorted = []
    @runs.clear
  end

  # The scopes the open world keeps its keys by, from the one reviewed list (story.replay_scopes):
  # a Raid World's, or a Classic world's, where a chest's keys are a party's. Asked again once the
  # world, its table or the rewards changed.
  #
  # @return [Hash, nil] :switches and :variables (a scope byte per id), :keys (self switches by
  #   key), :self (self switch rules, see rules_of), :index (indexed events) and :default; nil
  #   outside a world and before the list came.
  def self.scopes
    raid = defined?(MGQ_MpCoop::Scope) && MGQ_MpCoop::Scope.raid?
    return nil unless raid || (defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.in_world?)

    held = table
    stamp = [raid, held && held.rev, MGQ_MpStoryState.rewards_serial]
    return @scopes[1] if @scopes && @scopes[0] == stamp && @scopes[1]
    return nil if @scopes && @scopes[0] == stamp && MGQ_Multiplayer::Bridge.frame_number - @scopes[2] < SCOPES_ASK_FRAMES

    hash = MGQ_Multiplayer::Bridge.call(SCOPES_TOPIC, "party" => !raid)
    found = hash ? scopes_of(hash) : nil
    @scopes = [stamp, found, MGQ_Multiplayer::Bridge.frame_number]
    log("read who keeps each key: #{found[:keys].size} chest self switches, #{found[:self][0].size + found[:self][1].size} self switch rules") if found
    found
  rescue => e
    log_once(:scopes, "reading who keeps each key failed: #{e.class}: #{e.message}")
    nil
  end

  # Reads the scopes the DLL handed.
  #
  # @param hash [Hash] The scopes, see StoryTopics.ScopeTableOf in the DLL.
  # @return [Hash] The scopes, see scopes.
  def self.scopes_of(hash)
    index = {}
    Array(hash["index"]).each { |code| index[code] = true }
    keys = {}
    Array(hash["keys"]).each { |map, event, letter, scope| keys[[map, event, letter]] = scope }
    { :switches => hash["switches"].to_s, :variables => hash["variables"].to_s, :keys => keys, :self => rules_of(hash),
      :index => index, :default => hash["self_default"].to_i }
  end

  # Finds who keeps a key: a switch's or variable's byte, a chest's self switch by name, else a self
  # switch's most fitting rule as class_of finds it, its indexed event's (the world's) or the default.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
  # @param site [Array, nil] Where the write came from, which a common event's rule reads.
  # @return [Integer, nil] The scope, nil outside a world and before the list came.
  def self.scope_of(kind, key, site = nil)
    found = scopes
    return nil unless found
    return (kind == 0 ? found[:switches] : found[:variables]).getbyte(key).to_i if kind < 2

    return found[:keys][key] if found[:keys].key?(key)

    rule = rule_of(found[:self], key, site)
    return rule if rule

    found[:index][key[0].to_i * EVENT_SPAN + key[1].to_i] ? SCOPE_WORLD : found[:default]
  end

  # Reports whether a key is read at a run's start value in a replay: a work or world key.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Boolean] Whether it is.
  def self.viewed?(kind, key)
    VIEWED.include?(scope_of(kind, key))
  end

  # The run whose interpreter runs a command now, the outermost one being updated.
  #
  # @return [Run, nil] The run, nil outside every run.
  def self.current_run
    @running.empty? || @runs.empty? ? nil : @runs[@running.first.object_id]
  end

  # Reports whether the run whose command runs now is of a page that a party's chest key closes, which
  # its party gets by playing it, so the leader's story tells nothing of what it gives.
  #
  # @return [Boolean] Whether it is.
  def self.party_run?
    run = current_run
    return false unless run && run.site[0] == "map"

    map, event = run.site[1], run.site[2]
    found = scopes
    found ? %w(A B C D).any? { |letter| found[:keys][[map, event, letter]] == SCOPE_PARTY } : false
  end

  # Opens a run as the game sets up a list at the top, outside every command: a map event's page or
  # a common event's, never a troop's nor a list a script makes. Called after an interpreter's setup.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @param list [Array, nil] Its commands.
  def self.run_set_up(interpreter, list)
    @runs.delete(interpreter.object_id)
    hold(interpreter)
    return if list.nil? || !@running.empty? || replaying? || ($game_troop && interpreter.equal?($game_troop.interpreter)) || scopes.nil?

    site = site_of(interpreter)
    return unless site[0] == "map" || site[0] == "ce"

    place = MGQ_MpStoryIds.markers.map { |id| $game_variables[id].to_i }
    @runs[interpreter.object_id] = Run.new(site, place, {}, {}, [], Hash.new(0), {}, [], $game_self_switches, Hash.new(0))
  rescue => e
    log_once([:run_set_up, e.class], "opening a run failed: #{e.class}: #{e.message}")
  end

  # Notes what holds an interpreter that sets up a list, when the map does: the map for its own
  # interpreter, else the map event or parallel common event whose interpreter it is.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.hold(interpreter)
    id = interpreter.object_id
    @holders.delete(id)
    map = $game_map
    return unless map
    return @holders[id] = map if interpreter.equal?(map.interpreter)

    event = map.events ? map.events[MGQ_MpGame.get(interpreter, :event_id).to_i] : nil
    return @holders[id] = event if event && MGQ_MpGame.get(event, :interpreter).equal?(interpreter)

    common = Array(MGQ_MpGame.get(map, :common_events)).find { |held| MGQ_MpGame.get(held, :interpreter).equal?(interpreter) }
    @holders[id] = common if common
  rescue => e
    log_once([:hold, e.class], "noting what holds an interpreter failed: #{e.class}: #{e.message}")
  end

  # Closes the runs and forgets the waits of the interpreters the map let go: a loaded save brings
  # a map of its own, a transfer makes the map's events and parallel common events anew, and an
  # event's new page or a common event's switch turned off drops its interpreter. Their lists never
  # go on, so their runs would never end. Called after the map's update.
  def self.let_go
    return if @holders.empty?

    @holders.delete_if do |id, holder|
      next false if held?(holder, id)

      @runs.delete(id)
      @stacks.delete(id)
      true
    end
  rescue => e
    log_once([:let_go, e.class], "closing the runs the map let go failed: #{e.class}: #{e.message}")
  end

  # Reports whether a holder still holds an interpreter: the map is the game's, an event or common
  # event is still the map's, and it still has that interpreter.
  #
  # @param holder [Game_Map, Game_Event, Game_CommonEvent] The holder.
  # @param id [Integer] The interpreter's object id.
  # @return [Boolean] Whether it does.
  def self.held?(holder, id)
    map = $game_map
    return false unless map
    return holder.equal?(map) && map.interpreter.object_id == id if holder.is_a?(Game_Map)

    kept = holder.is_a?(Game_Event) ? map.events[holder.id].equal?(holder) : Array(MGQ_MpGame.get(map, :common_events)).any? { |held| held.equal?(holder) }
    interpreter = kept ? MGQ_MpGame.get(holder, :interpreter) : nil
    interpreter ? interpreter.object_id == id : false
  end

  # Reports whether a replay of another player's run plays, whose writes and inputs are no run of
  # the player's.
  #
  # @return [Boolean] Whether one does.
  def self.replaying?
    defined?(MGQ_MpStoryReplay) && MGQ_MpStoryReplay.running? ? true : false
  end

  # Notes a key's value before a run's first write of it, for a party, world or work key; and a
  # work or world key's value before anything wrote it while runs are open, such as a value the
  # relay brought, which keeps their start values. Called before a write of the game's switches,
  # variables or self switches.
  #
  # @param object [Game_Switches, Game_Variables, Game_SelfSwitches] What is written to.
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
  def self.before_write(object, kind, key)
    return if @runs.empty? || !object.equal?(kind == 0 ? $game_switches : kind == 1 ? $game_variables : $game_self_switches)

    run = current_run
    name = [kind, kind == 2 ? key.dup : key]
    return if run && run.before.key?(name)

    scope = scope_of(kind, key, run && kind == 2 ? site_of(@running.last) : nil)
    return if scope.nil? || scope == SCOPE_PLAYER

    value = plain_of(kind, object[key])
    run.before[name] = [scope, value] if run
    @runs.each_value { |open| open.starts[name] = value unless open.starts.key?(name) } if VIEWED.include?(scope)
  rescue => e
    log_once([:before_write, e.class], "noting a key before a run wrote it failed: #{e.class}: #{e.message}")
  end

  # Notes a key a script read during a run, whose start value the run's entry carries. Called after
  # a read of the game's switches, variables or self switches.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  def self.script_read(kind, key)
    @script_run.reads[[kind, kind == 2 ? key.dup : key]] = true if @script_run
  end

  # Runs a script of a run, noting the keys it reads.
  #
  # @yield Runs the script.
  # @return [Object] What the block returns.
  def self.reading_script
    outer = @script_run
    @script_run = current_run
    yield
  ensure
    @script_run = outer
  end

  # Notes an input of a run's player: what the command running now read, by its place and kind,
  # see MGQ_MpStoryReplay.input_at.
  #
  # @param kind [String] What it read, such as "choice" or "rand".
  # @param value [Integer, Boolean, nil] What it read; a yes or no is 1 or 0; anything else is no input.
  # @param at [Array, nil] The command, the one running now by default.
  # @param run [Run, nil] The run, the one whose command runs now by default.
  def self.input(kind, value, at = nil, run = current_run)
    return unless run

    number = value == true ? 1 : value == false ? 0 : value
    at ||= input_place
    return unless number.is_a?(Integer) && at

    occurrence = run.counts[[at, kind]]
    run.counts[[at, kind]] += 1
    run.inputs << [at, occurrence, kind, number]
  rescue => e
    log_once([:input, e.class], "noting an input failed: #{e.class}: #{e.message}")
  end

  # Names the command running now, as the replay names an input's command.
  #
  # @return [Array, nil] Such as [["map", 1994, 42, 1], 12], nil outside every command.
  def self.input_place
    @running.empty? ? nil : place_of(@running.last, @indexes.last)
  end

  # Names the choice the command running now sets up, as the replay names it: the Show Choices its
  # interpreter stands at, after a text's lines too, or the script command of an extended choice.
  #
  # @return [Array, nil] Such as [["map", 6, 30, 2], 1], nil outside every command.
  def self.choice_place
    return nil if @running.empty?

    interpreter = @running.last
    MGQ_MpStoryReplay.choice_at(site_of(interpreter), MGQ_MpGame.get(interpreter, :list), MGQ_MpGame.get(interpreter, :index).to_i)
  end

  # Reports whether a command runs inside a story reset: one of the lists running now writes a range
  # of switches or variables at once, as the returns to an earlier part do (common events 153 to
  # 155), which also clear the key items the player held.
  #
  # @return [Boolean] Whether it does.
  def self.resetting?
    @running.any? { |interpreter| reset_list?(MGQ_MpGame.get(interpreter, :list)) }
  end

  # Reports whether a list writes a range of switches or variables at once.
  #
  # @param list [Array, nil] The commands.
  # @return [Boolean] Whether it does.
  def self.reset_list?(list)
    list.is_a?(Array) && list.any? { |command| command.respond_to?(:code) && range_write?(command.code, command.parameters) }
  end

  # Reports whether a command writes a range of switches or variables at once: Control Switches over
  # more than one id, or Control Variables setting more than one.
  #
  # @param code [Integer] The command's code.
  # @param params [Array] Its parameters.
  # @return [Boolean] Whether it does.
  def self.range_write?(code, params)
    case code
    when 121 then params[1] > params[0]
    when 122 then params[1] > params[0] && params[2] == 0
    else false
    end
  end

  # Names a command of an interpreter's list, see MGQ_MpStoryReplay.input_at.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @param index [Integer] The command's place in its list.
  # @return [Array] Such as [["map", 1994, 42, 1], 12].
  def self.place_of(interpreter, index)
    MGQ_MpStoryReplay.input_at(site_of(interpreter), MGQ_MpGame.get(interpreter, :list), index)
  end

  # Wraps a choice's handler so the answer is noted as an input of the choice that showed it.
  #
  # @param handler [Proc, nil] The game's handler of the answer.
  # @return [Proc, nil] The handler to keep.
  def self.noted_choice(handler)
    run = replaying? ? nil : current_run
    return handler unless run && handler

    at = choice_place
    lambda do |answer|
      MGQ_MpStoryKeys.input("choice", answer, at, run)
      handler.call(answer)
    end
  end

  # Wraps a battle's handler of its outcome so the outcome is noted as an input of the command that
  # started the battle, which waits inside itself until the battle's end calls the handler.
  #
  # @param handler [Proc, nil] The game's handler of the outcome.
  # @return [Proc, nil] The handler to keep.
  def self.noted_battle(handler)
    run = replaying? ? nil : current_run
    return handler unless run && handler

    at = input_place
    lambda do |outcome|
      MGQ_MpStoryKeys.input("battle", outcome, at, run)
      handler.call(outcome)
    end
  end

  # Notes the number or item input a message waits for, by the command that set it up: the input
  # itself, or the text it follows.
  #
  # @param kind [String] "number" or "item".
  # @param variable [Integer] The variable the answer goes to, 0 for none.
  def self.message_input(kind, variable)
    run = replaying? ? nil : current_run
    @message_input = run && variable.to_i > 0 ? [run, input_place, kind, variable.to_i] : nil
  end

  # Notes the answer of the number or item input the message waited for, which the input's window
  # wrote to its variable, once the message closes. Called before a message is cleared.
  #
  # @param message [Game_Message] The message.
  def self.message_closing(message)
    return unless @message_input && message.equal?($game_message) && !replaying?

    run, at, kind, variable = @message_input
    @message_input = nil
    input(kind, $game_variables[variable], at, run)
  end

  # Notes the keys the game found pressed while it read keys (script 167's input_keys), each by its
  # place in MGQ_MpStoryReplay::KEY_SYMBOLS, then their end.
  #
  # @param keys [Array<Symbol>] The keys, in the order pressed.
  def self.keys_pressed(keys)
    keys.each { |key| input("keys", MGQ_MpStoryReplay::KEY_SYMBOLS.index(key)) }
    input("keys", -1)
  end

  # Notes the run and command of a present the player starts to choose. Called around an
  # interpreter's present_start.
  #
  # @param starting [Boolean] Whether the choosing starts, else it ended.
  def self.present_choosing(starting)
    run = starting && !replaying? ? current_run : nil
    @present_at = run ? [run, input_place] : nil
  end

  # Notes the present the player chose. Called after the present window sets it.
  #
  # @param item_id [Integer] The present, below 1 for none.
  def self.present_chosen(item_id)
    input("present", item_id, @present_at[1], @present_at[0]) if @present_at
  end

  # Notes what a command reads of the player, an event, the timer or what the party holds before it
  # runs: a conditional branch on the timer or a character's direction, a variable set from the
  # timer, a character or a count of what the party holds.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @param code [Integer] The command's code.
  # @param params [Array] Its parameters.
  def self.note_reads(interpreter, code, params)
    return if current_run.nil? || replaying?

    if code == 111 && params[0] == 3
      input("timer.working?", $game_timer.working?)
      input("timer.sec", $game_timer.sec) if $game_timer.working?
    elsif code == 111 && params[0] == 6
      note_character(interpreter, params[1], :direction)
    elsif code == 122 && params[3] == 3 && params[4] == 5
      read = [:x, :y, :direction, :screen_x, :screen_y][params[6]]
      note_character(interpreter, params[5], read) if read
    elsif code == 122 && params[3] == 3 && params[4] == 7 && params[5] == 5
      input("timer.sec", $game_timer.sec)
    elsif code == 122 && params[3] == 3 && MGQ_MpStoryReplay.holding_read?(params[4], params[5])
      input("holding", interpreter.game_data_operand(params[4], params[5], params[6]))
    end
  rescue => e
    log_once([:note_reads, e.class], "noting what a command reads failed: #{e.class}: #{e.message}")
  end

  # Notes a conditional branch's result as an input once it ran: a key held, and the checks a
  # replay follows the opener through (MGQ_MpStoryReplay::BRANCH_INPUTS).
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @param type [Integer] The branch's type.
  def self.note_branch(interpreter, type)
    kind = MGQ_MpStoryReplay::BRANCH_INPUTS[type]
    input(kind, MGQ_MpGame.get(interpreter, :branch)[MGQ_MpGame.get(interpreter, :indent)]) if kind
  rescue => e
    log_once([:note_branch, e.class], "noting a branch's result failed: #{e.class}: #{e.message}")
  end

  # Notes a read of a character as an input: the player's or an event's.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @param param [Integer] -1 for the player, 0 for the interpreter's event, else an event's id.
  # @param read [Symbol] The read, such as :x.
  def self.note_character(interpreter, param, read)
    character = interpreter.get_character(param)
    return unless character

    who = param < 0 ? "player" : "event#{param > 0 ? param : MGQ_MpGame.get(interpreter, :event_id).to_i}"
    input("#{who}.#{read}", character.send(read))
  end

  # Notes a reset of a run of the player's game: a command that writes a range of keys at once.
  #
  # @param kind [Integer] 0 for switches, 1 for variables, 2 for self switches (by maps).
  # @param from [Integer] The first id or map.
  # @param to [Integer] The last one.
  # @param value [Object] The value written, as the game holds it.
  def self.reset(kind, from, to, value)
    run = replaying? ? nil : current_run
    plain = plain_of(kind, value)
    run.resets << [kind, from, to, plain] if run && !plain.nil?
  end

  # Closes a run once its list ended: its resets go to the DLL, and a run that changed a party or
  # world key is logged there, which answers its entry to hand over when it gives (rule 1); its keys
  # go on by value as ever. Called after an interpreter's run.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.run_ended(interpreter)
    run = @runs.delete(interpreter.object_id)
    return unless run

    run.resets << [2, 0, ALL_MAPS, false] unless $game_self_switches.equal?(run.self_switches)
    MGQ_Multiplayer::Bridge.call(RESET_TOPIC, run.resets) unless run.resets.empty?
    changed = changed_keys(run)
    return if changed.empty? && run.found.values.all? { |change| change == 0 }

    party = changed.select { |kind, key, _before, _after| run.before[[kind, key]][0] == SCOPE_PARTY }.map { |kind, key, _, _| [kind, key] }
    hand_over(run, party, ran_request(run, changed))
  rescue => e
    log_once([:run_ended, e.class], "closing a run failed: #{e.class}: #{e.message}")
  end

  # Lists the party and world keys a run changed: those whose value at its end differs from the one
  # before its first write.
  #
  # @param run [Run] The run.
  # @return [Array<Array>] Each key's kind, key and its values before and after.
  def self.changed_keys(run)
    changed = []
    run.before.each do |(kind, key), (scope, before)|
      next unless scope == SCOPE_PARTY || scope == SCOPE_WORLD

      after = plain_of(kind, value_of(kind, key))
      changed << [kind, key, before, after] unless after == before
    end
    changed
  end

  # Writes the request that logs a run's end, see StoryTopics.ReplayRan in the DLL: a run that
  # changed a world key goes to its story's stream, whose owner keeps it: the player while they lead
  # their Classic story, else the leader or the relay's track; one that changed only party keys to
  # the party's stream, whose entry claims the player's own step at once. One that only gave or used
  # up a found item goes to a Raid World's track or a Classic party's stream.
  #
  # @param run [Run] The run.
  # @param changed [Hash] The keys it changed, see changed_keys.
  # @return [Hash] The request.
  def self.ran_request(run, changed)
    classic = !(defined?(MGQ_MpCoop::Scope) && MGQ_MpCoop::Scope.raid?)
    party_id = classic && defined?(MGQ_MpCoop) && MGQ_MpCoop.in_party? ? MGQ_MpCoop::Party.id : nil
    leader = classic ? story_leader : nil
    stream = classic ? story_stream(leader) : raid_track
    world = changed.any? { |kind, key, _before, _after| run.before[[kind, key]][0] == SCOPE_WORLD }
    found = run.found.select { |_id, change| change != 0 }.to_a
    sent = world || (changed.empty? && !classic) ? stream : party_id
    { "site" => run.site, "party" => classic, "stream" => stream, "party_stream" => party_id ? "party:#{party_id}" : nil,
      "owner" => classic && !leader.respond_to?(:state), "changed" => changed, "found" => found.empty? ? nil : found,
      "start" => sent ? start_values(run, classic) : [], "place" => run.place, "inputs" => run.inputs, "opener" => nil }
  end

  # Finds the leader whose story the player keeps in a Classic world.
  #
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me or nil for the player's own story.
  def self.story_leader
    defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.respond_to?(:leader) ? MGQ_MpCoopStory.leader : nil
  end

  # Names the stream of a Classic story: the leader's, or the player's own while they lead it.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, see story_leader.
  # @return [String, nil] Such as "story:<id>", nil outside a world.
  def self.story_stream(leader)
    return nil unless defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.in_world?

    id = leader.respond_to?(:state) ? leader.state["id"] : defined?(MGQ_MpOverworldSync::Me) && MGQ_MpOverworldSync::Me.id
    id.to_s.empty? ? nil : "story:#{id}"
  end

  # Names the track of a Raid World the player plays, the stream of its story.
  #
  # @return [String, nil] "world" or the player's own "t<n>", nil before the relay placed them.
  def self.raid_track
    defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.respond_to?(:track) ? MGQ_MpWorldStory.track : nil
  end

  # Reads the start values a run's entry carries: every work and world key any page of its event can
  # read, as the DLL names them, and those a script read during it; a key the run wrote at its value
  # before, any other at its value now, which the run left as it found it.
  #
  # @param run [Run] The run.
  # @param classic [Boolean] Whether the world is a Classic world.
  # @return [Array<Array>] Each key's kind, key and value.
  def self.start_values(run, classic)
    names = Array(MGQ_Multiplayer::Bridge.call(READS_TOPIC, "site" => run.site, "party" => classic))
    run.reads.each_key { |kind, key| names << [kind, key] if viewed?(kind, key) }
    start = []
    names.uniq.each do |kind, key|
      name = [kind, key]
      value = run.starts.key?(name) ? run.starts[name] : run.before.key?(name) ? run.before[name][1] : plain_of(kind, value_of(kind, key))
      start << [kind, key, value] unless value.nil?
    end
    start
  end

  # Logs a run's end with the DLL and hands its entry on: a borrowing guest keeps the party keys it
  # changed in their own story too, and the entry goes to the players who keep its stream, see
  # hand_entry. A run the DLL cannot log yet, before the list came, is tried again.
  #
  # @param run [Run] The run.
  # @param own [Array<Array>] The party keys it changed, each [kind, key].
  # @param request [Hash] The request, see ran_request.
  def self.hand_over(run, own, request)
    own.each do |kind, key|
      MGQ_MpCoopStory.keep_own(kind, key, value_of(kind, key)) if defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.guest?
    end
    answer = MGQ_Multiplayer::Bridge.call(RAN_TOPIC, request)
    return @unsent << [MGQ_Multiplayer::Bridge.frame_number, request] if answer.is_a?(Hash) && answer["unknown"]

    log("the run of #{run.site} changed #{request['changed'].size} shared keys#{request['found'] ? " and #{request['found'].size} found items" : ''}#{answer.is_a?(Hash) ? ", its entry #{answer['id']} goes to #{answer['stream']}" : ''}")
    hand_entry(answer, request["party"])
  end

  # Hands an entry the DLL made on to the players who keep its stream: a Raid World's story entry to
  # the world's story (world_story.rbx), a party's or a Classic story's to the co-op events.
  #
  # @param entry [Hash, nil] The entry, see ReplayEntry.Write in the DLL; nil for none.
  # @param classic [Boolean] Whether the world is a Classic world.
  def self.hand_entry(entry, classic)
    return unless entry.is_a?(Hash) && entry["id"]

    if entry["scope"] == "world" && !classic
      MGQ_MpWorldStory.hand_entry(entry) if defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.respond_to?(:hand_entry)
    elsif defined?(MGQ_MpCoopEvents) && MGQ_MpCoopEvents.respond_to?(:hand_entry)
      MGQ_MpCoopEvents.hand_entry(entry)
    end
  end

  # Tries again the ends of runs the DLL could not log yet, once a second.
  def self.send_unsent
    return if @unsent.empty? || MGQ_Multiplayer::Bridge.frame_number - @unsent.first[0] < UNSENT_FRAMES

    unsent = @unsent
    @unsent = []
    unsent.each do |_frame, request|
      answer = MGQ_Multiplayer::Bridge.call(RAN_TOPIC, request)
      next @unsent << [MGQ_Multiplayer::Bridge.frame_number, request] if answer.is_a?(Hash) && answer["unknown"]

      hand_entry(answer, request["party"])
    end
  rescue => e
    log_once([:send_unsent, e.class], "logging a run again failed: #{e.class}: #{e.message}")
  end

  # Lets the game hand out a battle's drops, and hands the found items they gave to the DLL, whose
  # entry reaches every player as a found item's run does (user decision 2026-11-05).
  #
  # @yield The game's handing out of the drops.
  # @return [Object] What it returns.
  def self.dropping
    @drops = Hash.new(0)
    result = yield
    hand_drops(@drops.select { |_id, change| change != 0 }.to_a)
    result
  ensure
    @drops = nil
  end

  # Hands the found items a battle's drops gave to the DLL, and their entry on to the players who
  # keep its stream, as hand_over does a run's.
  #
  # @param found [Array<Array>] Each item's id and how many the drops gave.
  def self.hand_drops(found)
    return if found.empty?

    classic = !(defined?(MGQ_MpCoop::Scope) && MGQ_MpCoop::Scope.raid?)
    party_id = classic && defined?(MGQ_MpCoop) && MGQ_MpCoop.in_party? ? MGQ_MpCoop::Party.id : nil
    entry = MGQ_Multiplayer::Bridge.call(DROP_TOPIC, "party" => classic, "stream" => classic ? nil : raid_track,
                                                     "party_stream" => party_id ? "party:#{party_id}" : nil, "found" => found, "opener" => nil)
    log("a battle's drops gave #{found.size} found items#{entry.is_a?(Hash) ? ", their entry #{entry['id']} goes to #{entry['stream']}" : ''}")
    hand_entry(entry, classic)
  rescue => e
    log_once([:hand_drops, e.class], "handing a battle's drops over failed: #{e.class}: #{e.message}")
  end

  # Reports whether an item is a found item, which a run that gives or uses it up hands over even
  # where it changed no shared key: a key item the game does not tag as a plain item, ores and CDs
  # among them, or an item unlocking a job or a race.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @return [Boolean] Whether it is.
  def self.found_item?(item)
    return false unless defined?(RPG::Item) && item.is_a?(RPG::Item)

    described = item.respond_to?(:description) ? item.description.to_s : ""
    (item.key_item? && described !~ PLAIN_ITEM_TAG) || (defined?(MGQ_MpWorldCatchup) && MGQ_MpWorldCatchup.unlock_item?(item)) ? true : false
  end

  # Lets a change of what the party holds happen, and notes how many of a found item it gave or used
  # up: in a battle's drops while the game hands them out, else in the run of the player's own game
  # that makes it; never in a replay, nor in what the multiplayer gives, lends or writes itself, nor
  # in a story reset, which clears only the player's own items and uses none up.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @param amount [Integer] The change, below 0 for a loss.
  # @yield The change.
  # @return [Object] What the change returns.
  def self.item_changing(item, amount)
    run = current_run
    noted = @drops || (run && run.found)
    lending = defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.respond_to?(:lending?) && MGQ_MpCoopStory.lending?
    return yield unless noted && amount.to_i != 0 && !replaying? && !applying? && !lending && !resetting? && found_item?(item)

    before = $game_party.item_number(item)
    result = yield
    noted[item.id] += $game_party.item_number(item) - before
    result
  end

  # Reads a key the player's game holds.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Object] Its value.
  def self.value_of(kind, key)
    (kind == 0 ? $game_switches : kind == 1 ? $game_variables : $game_self_switches)[key]
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # Every write of the game's story, which the telling's scene and the story's requests share.
  MGQ_MpHooks.after(Game_Switches, :[]=, "story_keys") { |id, value| MGQ_MpStoryKeys.written(self, 0, id, value) }
  MGQ_MpHooks.after(Game_Variables, :[]=, "story_keys") { |id, value| MGQ_MpStoryKeys.written(self, 1, id, value) }
  MGQ_MpHooks.after(Game_SelfSwitches, :[]=, "story_keys") { |key, value| MGQ_MpStoryKeys.written(self, 2, key, value) }
rescue => e
  MGQ_MpStoryKeys.log("write hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # Which interpreter runs a command, so a write names its event.
  MGQ_MpHooks.around(Game_Interpreter, :update, "story_keys") { |interpreter, _args, original| MGQ_MpStoryKeys.updating(interpreter) { original.call } }
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "story_keys") { MGQ_MpStoryKeys.executing(self) }
  MGQ_MpHooks.after(Game_Interpreter, :execute_command, "story_keys") { MGQ_MpStoryKeys.executed(self) }

rescue => e
  MGQ_MpStoryKeys.log("interpreter hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # Hooks a method only where the game has it, as an older copy or a plugin may not.
  has = lambda { |owner, name| owner.method_defined?(name) || owner.private_method_defined?(name) }

  # Each run of the player's own game: it opens as a list is set up and closes once it ran, notes
  # the shared keys before it writes them and the keys its scripts read.
  MGQ_MpHooks.after(Game_Interpreter, :setup, "story_keys") { |*args| MGQ_MpStoryKeys.run_set_up(self, args[0]) }
  MGQ_MpHooks.after(Game_Interpreter, :run, "story_keys") { MGQ_MpStoryKeys.run_ended(self) }
  MGQ_MpHooks.before(Game_Switches, :[]=, "story_keys") { |id, _value| MGQ_MpStoryKeys.before_write(self, 0, id) }
  MGQ_MpHooks.before(Game_Variables, :[]=, "story_keys") { |id, _value| MGQ_MpStoryKeys.before_write(self, 1, id) }
  MGQ_MpHooks.before(Game_SelfSwitches, :[]=, "story_keys") { |key, _value| MGQ_MpStoryKeys.before_write(self, 2, key) }
  MGQ_MpHooks.after(Game_Switches, :[], "story_keys") { |id| MGQ_MpStoryKeys.script_read(0, id) }
  MGQ_MpHooks.after(Game_Variables, :[], "story_keys") { |id| MGQ_MpStoryKeys.script_read(1, id) }
  MGQ_MpHooks.after(Game_SelfSwitches, :[], "story_keys") { |key| MGQ_MpStoryKeys.script_read(2, key) }
  if has.call(Game_Interpreter, :command_355)
    MGQ_MpHooks.around(Game_Interpreter, :command_355, "story_keys") { |_interpreter, _args, original| MGQ_MpStoryKeys.reading_script { original.call } }
  end

  # A conditional branch: what it reads of the timer or a character before it runs, a script's
  # reads while it runs, the key it found pressed and its check of what the party holds or of the
  # event's own self switch.
  if has.call(Game_Interpreter, :command_111)
    MGQ_MpHooks.around(Game_Interpreter, :command_111, "story_keys") do |interpreter, _args, original|
      params = interpreter.instance_variable_get(:@params)
      MGQ_MpStoryKeys.note_reads(interpreter, 111, params)
      result = params[0] == 12 ? MGQ_MpStoryKeys.reading_script { original.call } : original.call
      MGQ_MpStoryKeys.note_branch(interpreter, params[0])
      result
    end
  end

  # The inputs of a run's player, each noted with its command.
  MGQ_MpHooks.before(Game_Interpreter, :command_122, "story_keys") { MGQ_MpStoryKeys.note_reads(self, 122, @params) } if has.call(Game_Interpreter, :command_122)
  MGQ_MpHooks.after(Game_Interpreter, :command_285, "story_keys") { MGQ_MpStoryKeys.input("location", $game_variables[@params[0]]) } if has.call(Game_Interpreter, :command_285)
  # A battle's handler is wrapped where the command sets it, before the command waits for the battle.
  if defined?(BattleManager) && has.call(BattleManager.singleton_class, :event_proc=)
    MGQ_MpHooks.around(BattleManager.singleton_class, :event_proc=, "story_keys") { |_manager, args, original| original.call(MGQ_MpStoryKeys.noted_battle(args[0])) }
  end
  # A number or item input is noted where the message is set up to wait for it, by a text before it
  # too, and its answer once the message closes.
  if defined?(Game_Message)
    MGQ_MpHooks.after(Game_Message, :num_input_variable_id=, "story_keys") { |id| MGQ_MpStoryKeys.message_input("number", id) } if has.call(Game_Message, :num_input_variable_id=)
    MGQ_MpHooks.after(Game_Message, :item_choice_variable_id=, "story_keys") { |id| MGQ_MpStoryKeys.message_input("item", id) } if has.call(Game_Message, :item_choice_variable_id=)
    MGQ_MpHooks.before(Game_Message, :clear, "story_keys") { MGQ_MpStoryKeys.message_closing(self) } if has.call(Game_Message, :clear)
  end
  MGQ_MpHooks.around(Game_Interpreter, :rand, "story_keys") do |_interpreter, _args, original|
    drawn = original.call
    MGQ_MpStoryKeys.input("rand", drawn) unless MGQ_MpStoryKeys.replaying?
    drawn
  end
  if defined?(Game_Message) && has.call(Game_Message, :choice_proc=)
    MGQ_MpHooks.around(Game_Message, :choice_proc=, "story_keys") { |_message, args, original| original.call(MGQ_MpStoryKeys.noted_choice(args[0])) }
  end
  if has.call(Game_Interpreter, :ex_choice_show) && defined?(NWConst::Var::EX_CHOICE_RESULT)
    MGQ_MpHooks.after(Game_Interpreter, :ex_choice_show, "story_keys") { MGQ_MpStoryKeys.input("choice", $game_variables[NWConst::Var::EX_CHOICE_RESULT], MGQ_MpStoryKeys.choice_place) }
  end
  if has.call(Game_Interpreter, :input_keys)
    MGQ_MpHooks.after(Game_Interpreter, :input_keys, "story_keys") { MGQ_MpStoryKeys.keys_pressed(Array($game_temp.keys_stack)) }
  end
  if has.call(Game_Interpreter, :present_start) && defined?(Game_Temp) && has.call(Game_Temp, :choice_present_id=)
    MGQ_MpHooks.around(Game_Interpreter, :present_start, "story_keys") do |_interpreter, _args, original|
      MGQ_MpStoryKeys.present_choosing(true)
      begin
        original.call
      ensure
        MGQ_MpStoryKeys.present_choosing(false)
      end
    end
    MGQ_MpHooks.after(Game_Temp, :choice_present_id=, "story_keys") { |item_id| MGQ_MpStoryKeys.present_chosen(item_id) }
  end

  # The resets of a run: a range of switches or variables written at once, the self switches of maps
  # reset (script 167's reset_selfswitch_map), or made anew (see run_ended).
  if has.call(Game_Interpreter, :command_121)
    MGQ_MpHooks.after(Game_Interpreter, :command_121, "story_keys") do
      MGQ_MpStoryKeys.reset(0, @params[0], @params[1], @params[2] == 0) if MGQ_MpStoryKeys.range_write?(121, @params)
    end
  end
  if has.call(Game_Interpreter, :command_122)
    MGQ_MpHooks.after(Game_Interpreter, :command_122, "story_keys") do
      MGQ_MpStoryKeys.reset(1, @params[0], @params[1], $game_variables[@params[0]]) if MGQ_MpStoryKeys.range_write?(122, @params)
    end
  end
  if has.call(Game_SelfSwitches, :delete)
    MGQ_MpHooks.before(Game_SelfSwitches, :delete, "story_keys") do |map_ids|
      Array(map_ids).each { |map| MGQ_MpStoryKeys.reset(2, map.to_i, map.to_i, false) } if equal?($game_self_switches)
    end
  end
rescue => e
  MGQ_MpStoryKeys.log("run hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # The frame's writes go before the frame's batch of the bridge.
  MGQ_MpHooks.before(Graphics.singleton_class, :update, "story_keys") { MGQ_MpStoryKeys.flush }
  # After the map's update, the runs of the interpreters it let go close.
  MGQ_MpHooks.after(Game_Map, :update, "story_keys") { |*_args| MGQ_MpStoryKeys.let_go }
rescue => e
  MGQ_MpStoryKeys.log("frame hook FAILED: #{e.class}: #{e.message}")
end

begin
  # The found items a run of the player's own game gives or uses up, which hand the run over.
  MGQ_MpHooks.around(Game_Party, :gain_item, "story_keys") do |_party, args, original|
    MGQ_MpStoryKeys.item_changing(args[0], args[1]) { original.call }
  end
rescue => e
  MGQ_MpStoryKeys.log("party hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # The found items a battle's drops give, which reach every player. The game's plugins load after
  # the Patch folder and a victory screen defines the drops anew, so the hook goes in once every
  # plugin is in.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "story_keys") do
    if defined?(BattleManager) && BattleManager.respond_to?(:gain_drop_items)
      MGQ_MpHooks.around(BattleManager.singleton_class, :gain_drop_items, "story_keys") { |_manager, _args, original| MGQ_MpStoryKeys.dropping { original.call } }
    end
  end
rescue => e
  MGQ_MpStoryKeys.log("drop hooks FAILED: #{e.class}: #{e.message}")
end
