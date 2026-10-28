#----------------------------------------------------------------
#  story_keys.rbx
#
#  Changelog:
#      Paulinchen  2026-10-28: Built a Classic party's table anew once the chest flags came with the story mapping
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

  # What an event's place in a table's index is made of: map * EVENT_SPAN + event.
  EVENT_SPAN = 1_000_000

  # The writes one frame keeps at most, past the largest frame the game was seen to write (the
  # Final Chapter's reset, about 1,900), so a runaway parallel event cannot fill the memory.
  MAX_BATCH = 8000

  # A table: its revision, the class of each switch and variable as bytes, the self switch rules by
  # key, the indexed events, the local steps by variable, the parts' gates, the class of a self
  # switch no rule names, and the ids of the switches and variables kept on a track.
  Table = Struct.new(:rev, :switches, :variables, :self_rules, :index, :local_steps, :gates, :self_default, :kept_switches, :kept_variables)

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "story keys"

  # The story mapping's table, nil before it came.
  @raid = nil

  # A Classic party's table, built once it is first needed.
  @classic = nil

  # Where the writes recorded go: :raid, :classic or nil for nowhere.
  @recording = nil

  # The writes recorded this frame, each [key, value, site].
  @batch = []

  # The writes of a Raid World's story made before its mapping came, each [kind, key, value, site],
  # which the mapping sorts once it comes.
  @unsorted = []

  # How deep the multiplayer's own writes go, which are no writes of the player's.
  @applying = 0

  # The interpreters running a command, innermost last, of the interpreter being updated.
  @running = []

  # The running interpreters of each interpreter whose update a wait left, by its object id.
  @stacks = {}

  # What a write outside every interpreter is told as, nil for the game itself.
  @origin = nil

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
    Table.new(hash["rev"].to_i, switches, variables, hash["self"] || {}, index, local, hash["gates"] || {}, hash["self_default"].to_i,
              kept_ids(switches), kept_ids(variables))
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
        "#{@raid.self_rules.size} self switch rules, #{@raid.index.size} events indexed")
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

  # A Classic party's table, built by the DLL from the game's database and the chest flags that
  # came with the story mapping (MGQ_MpStoryState.rewards), again once other ones came.
  #
  # @return [Table, nil] The table, nil while the DLL builds none.
  def self.classic_table
    return @classic if @classic && @classic_serial == MGQ_MpStoryState.rewards_serial

    flags = MGQ_MpStoryState.chest_flags
    @classic_serial = MGQ_MpStoryState.rewards_serial
    hash = MGQ_Multiplayer::Bridge.call(CLASSIC_TOPIC, "switches" => $data_system.switches.size, "variables" => $data_system.variables.size,
                                                       "companions" => $data_actors ? $data_actors.size : 1000, "chest_flags" => flags)
    @classic = hash ? table_of(hash) : nil
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
  # @param site [String, nil] Where the write came from, which a common event's rule reads.
  # @param table [Table, nil] The table, the open world's by default.
  # @return [Integer] The class, 0 for each player's own and while no table came.
  def self.class_of(kind, key, site = nil, table = self.table)
    return 0 unless table
    return (kind == 0 ? table.switches : table.variables).getbyte(key).to_i if kind < 2 && key.is_a?(Integer) && key >= 0

    return 0 unless key.is_a?(Array) && key.size == 3

    map, event, letter = key
    rules = table.self_rules
    unless rules.empty?
      common = site && site.start_with?("ce:") ? site[3..-1] : nil
      found = rules["ss#{map}.#{event}.#{letter}"] || rules["ss#{map}.#{event}.*"] ||
              (common && (rules["ce#{common}.#{letter}"] || rules["ce#{common}.*"])) || rules["ss#{map}.*.#{letter}"] || rules["ss#{map}.*.*"]
      return found if found
    end
    table.index[map.to_i * EVENT_SPAN + event.to_i] ? KEPT : table.self_default
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
    @origin = "game:#{what}"
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
    outer = @running
    @running = @stacks.delete(interpreter.object_id) || []
    yield
  ensure
    @stacks[interpreter.object_id] = @running unless @running.empty?
    @running = outer
  end

  # Notes the interpreter that starts a command, so a write it makes names its event.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.executing(interpreter)
    @running.push(interpreter)
  end

  # Notes that an interpreter's command ended.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.executed(interpreter)
    @running.pop if @running.last.equal?(interpreter)
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
  # @param site [String] Where it came from.
  def self.add(kind, key, value, site)
    if @batch.size >= MAX_BATCH
      return log_once([:batch_full, Graphics.frame_count / 600], "dropped writes past #{MAX_BATCH} in one frame")
    end

    text = text_of(kind, value)
    @batch << [key_text(kind, key), text, site] if text
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

  # Writes a value as the tracks keep it: a switch or self switch as "1" or "0", a variable as
  # MGQ_MpStoryState.encode_value writes it.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param value [Object] The value.
  # @return [String, nil] The text, nil for a variable whose value no story carries, such as a list.
  def self.text_of(kind, value)
    return value ? "1" : "0" unless kind == 1

    text = MGQ_MpStoryState.encode_value(value.nil? ? 0 : value)
    text.empty? ? nil : text
  end

  # Writes a key as the tracks name it.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
  # @return [String] Such as "s12", "v1001" or "ss7.39.A".
  def self.key_text(kind, key)
    case kind
    when 0 then "s#{key}"
    when 1 then "v#{key}"
    else "ss#{key[0]}.#{key[1]}.#{key[2]}"
    end
  end

  # Reads a key as the tracks name it.
  #
  # @param text [String] The key.
  # @return [Array, nil] Its kind (0 a switch, 1 a variable, 2 a self switch, 3 a frozen fight) and
  #   its id or self switch key; nil for none.
  def self.key_of(text)
    case text
    when /\As(\d+)\z/ then [0, $1.to_i]
    when /\Av(\d+)\z/ then [1, $1.to_i]
    when /\Ass(\d+)\.(\d+)\.(\w+)\z/ then [2, [$1.to_i, $2.to_i, $3]]
    when /\Af(\d+)\z/ then [3, $1.to_i]
    end
  end

  # Names where a write comes from: the common event whose commands run, the page of the map event
  # whose commands run, the troop's battle event, or the game itself.
  #
  # @param interpreter [Game_Interpreter, nil] The interpreter running a command, nil for none.
  # @return [String] Such as "map:7:39:1", "ce:154", "game:troop" or "game".
  def self.site_of(interpreter)
    return @origin || "game" unless interpreter

    list = MGQ_MpGame.get(interpreter, :list)
    common = common_event_of(list)
    return "ce:#{common}" if common

    event_id = MGQ_MpGame.get(interpreter, :event_id).to_i
    map_id = MGQ_MpGame.get(interpreter, :map_id).to_i
    return "game:troop" if $game_troop && interpreter.equal?($game_troop.interpreter)
    return "game:event" unless event_id > 0 && map_id > 0

    "map:#{map_id}:#{event_id}:#{page_of(map_id, event_id, list)}"
  rescue
    "game"
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
  # @param key [String] The key, see key_text.
  # @param text [String] Its value as the tracks keep it.
  # @param site [String] Where it comes from, "game" or "game:<what>".
  # @return [Boolean] Whether it goes with the frame's writes: false unless a Raid World's story records.
  def self.request(key, text, site)
    return false unless @recording == :raid && text

    @batch << [key, text, site]
    true
  end

  # Drops the writes recorded this frame, as a loaded save or a new game bring their own story.
  def self.drop
    @batch = []
    @unsorted = []
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
  # The frame's writes go before the frame's batch of the bridge.
  MGQ_MpHooks.before(Graphics.singleton_class, :update, "story_keys") { MGQ_MpStoryKeys.flush }
rescue => e
  MGQ_MpStoryKeys.log("frame hook FAILED: #{e.class}: #{e.message}")
end
