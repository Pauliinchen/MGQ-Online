#----------------------------------------------------------------
#  battles_raid_freeze.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Found a fight's site row by its battle number in the live list, so fights of a translated game freeze too
#      Paulinchen  2026-11-10: Waited longer and longer between hand-overs of the journal the DLL refuses, instead of handing it over again every frame
#      Paulinchen  2026-11-08: Asked the DLL which records wait, what a record's world entry holds, what becomes of a record as its battle ends, where a tableau stands and what it blocks, how a fresh start begins and which items a defeat gives back
#                            - Dropped the scene switches assumed when the DLL tells nothing of a page, and the tables nothing reads
#      Paulinchen  2026-11-06: Read the preamble's start and whether a page runs nothing from the DLL, and left the Hades halls to its sites
#      Paulinchen  2026-11-05: Asked the DLL whether a frozen fight is over, the one decision every caller asks, and dropped the player's own record once it is
#                            - Asked the DLL whether a lost battle's defeat goes back and which value each key it changed goes back to
#                            - Put nothing back of an event's lost battle whose fight froze no record
#                            - Asked the DLL whether the player's story beat a boss and read the raid bosses' troops from its table
#                            - Handed the journal the values written over as the bridge carries them, keeping copies of other values here, instead of Marshal dumps
#                            - Named sites as plain values, and had the DLL read the sites of an earlier release's records once
#                            - Opened the player's own scene as a resume begins, so what it puts back counts as the scene's
#                            - Counted its timers by the bridge's frame, which never goes back as a save loads
#      Paulinchen  2026-10-28: Read the freeze's tables from the DLL's events database in place of battles_raid_freeze_data.rbx
#                            - Read whether a page shows only during a scene or runs nothing from the DLL's events database
#      Paulinchen  2026-10-23: Kept the story's writes in a DLL journal instead of copying the whole story
#                            - Resumed a frozen fight from a vehicle, putting the vehicles back as at the battle
#      Paulinchen  2026-10-17: Created
#
#----------------------------------------------------------------

# The freeze of a Raid World's story at a lost raid boss fight: a battle against a raid boss's pools
# that the player loses keeps the story at the battle instead of moving it back. The defeat's scene
# and the game's post-defeat processing (common event 3000) play as always and send the player
# away; once they end, everything else the defeat changed of the story is put back, and the boss
# waits where the player lost it (ui_raid_freeze.rbx draws it). Facing it and pressing the action
# button, or the join hotkey near it, puts the player back on the spot they stood on at the battle
# command, with the scene as it stood then, and runs the event on from right before its battle
# command, inside the common events it called too, against the shared pool.
#
# The record of a fight is taken as its battle is set up and kept in the save (FIELD), since the
# game's own interpreter saves no common event it runs inside and resumes after the battle command.
# A player who has no record of their own, such as one who joined late, gets the world's entry of
# the fight (world_freeze.rbx), whose press starts the event from its first command, from the spot
# its trigger starts it on. Which fights freeze and where their bosses wait comes from the DLL's
# events database (the topic raid.sites, see tables).
module MGQ_MpRaidFreeze
  # The field of $game_system the save keeps the player's frozen fights in, see field.
  FIELD = :@mgq_mp_raid_freeze

  # The notification box's key of this script's messages.
  NOTICE_KEY = :raid_freeze

  # Frames a message of this script shows, five seconds.
  NOTICE_FRAMES = 300

  # Frames between two looks at whether the bosses of the player's records are beaten.
  CHECK_FRAMES = 60

  # The DLL's topic that tells why a lost battle's defeat puts nothing back, see FreezeTopics.
  DEFEAT_TOPIC = "freeze.defeat"

  # The DLL's topic that tells which value each key a defeat changed goes back to and which items
  # come back.
  UNDO_TOPIC = "freeze.undo"

  # The DLL's topic that tells which of the player's records wait and whose fight is over, see
  # FreezeRecords.Check.
  RECORDS_TOPIC = "freeze.records.check"

  # The DLL's topic that tells which story values a record's world entry holds.
  HELD_TOPIC = "freeze.records.held"

  # The DLL's topic that tells what becomes of the player's record as a battle ends.
  END_TOPIC = "freeze.records.end"

  # The DLL's topic that tells where a fight's tableau stands and which events it blocks.
  TABLEAU_TOPIC = "freeze.tableau"

  # The DLL's topic that tells how the world's entry of a fight starts afresh.
  FRESH_TOPIC = "freeze.fresh"

  # The event command that calls a common event.
  CALL_CODE = 117

  # The event command that starts a battle.
  BATTLE_CODE = 301

  # The directions of a tile's neighbours.
  NEIGHBOUR_DIRECTIONS = [2, 4, 6, 8]

  # The topic the journal's writes go to the DLL by, see JournalTopics in the DLL.
  JOURNAL_TOPIC = "freeze.journal"

  # The topic that lists the keys written since a mark.
  SINCE_TOPIC = "freeze.since"

  # The writes the journal keeps in the scripts at most before it hands them over, past the
  # largest frame the game was seen to write (the Final Chapter's reset, about 1,900).
  MAX_PENDING = 8000

  # The writes the journal keeps in the scripts at most while the DLL refuses them; the oldest go
  # first, and a mark before them reads as lost.
  MAX_HELD = 4 * MAX_PENDING

  # Frames after a refused hand-over of the journal before the next, doubled with each refusal in a
  # row up to RETRY_MOST_FRAMES; a refused hand-over carries up to MAX_HELD writes each time.
  RETRY_FRAMES = 60

  # The most frames between two hand-overs of the journal while the DLL refuses it, half a minute.
  RETRY_MOST_FRAMES = 1800

  # The DLL's topic that tells where the story fights troops, see EventTableTopics.Sites.
  SITES_TOPIC = "raid.sites"

  # The DLL's topic that reads the sites a save of an earlier release keeps as texts, see
  # StoryTopics.SitesTopic.
  OLD_SITES_TOPIC = "story.sites"

  # Frames between two asks for the freeze's tables while the DLL gives none, a second.
  TABLES_FRAMES = 60

  # What the log names the kinds of story values by.
  KIND_LETTERS = ["s", "v", "self switch "]

  # The game's vehicles, as Game_Map#vehicle names them.
  VEHICLE_TYPES = [:boat, :ship, :airship]

  # Where the frame stack of the common events the map's event runs, the battle command and the
  # rest stand; see forget.
  @stack = []

  # The number of the last write the journal noted, which a mark takes; it never goes back, so a
  # mark of an earlier run never names a later write.
  @seq = 0

  # The writes noted since they last went to the DLL, each [seq, kind, key, before].
  @journal = []

  # Copies of the values written over that the bridge cannot carry, by the write's number, which the
  # journal names in their stead (see plain_value); dropped as the DLL drops their writes.
  @objects = {}

  # The oldest live mark the DLL last heard, :none before the first.
  @kept = :none

  # The number of the last write the scripts dropped while the DLL refused the journal; a mark
  # before it is lost.
  @lost_through = 0

  # How many hand-overs of the journal failed in a row.
  @refusals = 0

  # The frame from which a hand-over of the journal the DLL refused is tried again.
  @retry_at = 0

  # How deep the blocks whose writes the journal leaves out nest, see unjournaled.
  @unjournaled = 0

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "raid freeze"

  # Forgets the run, the frame stack, the pending snapshots and the resume, as at the title screen.
  def self.forget
    @run = nil
    @stack = []
    @at_301 = nil
    @battle = nil
    @pending = nil
    @resume = nil
    @teleport = nil
    @return_to = nil
    @retrying = false
    @own_setup = false
    @checked_at = nil
    @shared = {}
  end

  # Lists the player's own frozen fights of the open world whose fight is not over, as the DLL tells
  # (see checked).
  #
  # @return [Array<Hash>] The records, each with at least the keys of a world entry (see entry_of).
  def self.records
    notes = field
    return [] unless notes

    Array(checked(notes)["listed"]).map { |troop| notes["records"][troop] }.compact
  rescue => e
    log_once(:records, "listing the frozen fights failed: #{e.class}: #{e.message}")
    []
  end

  # Asks the DLL which of the player's records wait and which fights are over (FreezeRecords.Check).
  #
  # @param notes [Hash] The save's notes, see field.
  # @return [Hash] "listed" (the troops of the records that wait) and "dropped" ([troop, why] of each
  #   record whose fight is over); empty without records or an answer.
  def self.checked(notes)
    rows = notes["records"].values.map { |record| [record["troop"].to_i, record["state"].to_s] }
    return {} if rows.empty?

    answer = MGQ_Multiplayer::Bridge.call(RECORDS_TOPIC, "world" => MGQ_MpWorldStory.world_id.to_s, "facts" => MGQ_MpRaidBosses.facts, "records" => rows)
    answer.is_a?(Hash) ? answer : {}
  end

  # Finds the player's own record of a troop's fight in the open world, in any state.
  #
  # @param troop [Integer, String] The troop.
  # @return [Hash, nil] The record, nil for none.
  def self.record_for(troop)
    notes = field
    notes ? notes["records"][troop.to_i] : nil
  rescue => e
    log_once(:record_for, "finding a frozen fight failed: #{e.class}: #{e.message}")
    nil
  end

  # Reports whether a lost raid boss battle's defeat is under way: from its snapshot as the defeat
  # starts until its changes were put back, or the snapshot was dropped.
  #
  # @return [Boolean] Whether it is.
  def self.holding_writes?
    @pending ? true : false
  end

  # Reports whether a resume runs: from its start until the map's interpreter it set up stopped.
  #
  # @param troop [Integer, nil] Only the resume of this troop's fight; nil for any.
  # @return [Boolean] Whether one does.
  def self.resuming?(troop = nil)
    resume = @resume
    resume && (troop.nil? || resume[:troop] == troop.to_i) ? true : false
  end

  # Starts the fight against a troop's boss from its stand-in: the player's own record's resume,
  # else the world entry's event from its first command. Shows a notice and logs on refusal.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boolean] Whether it started.
  def self.resume(troop_id)
    troop = troop_id.to_i
    refusal = resume_refusal(troop)
    return refuse(troop, *refusal) if refusal

    record = record_for(troop)
    return resume_record(troop, record) if record && record["state"] == "frozen"

    entry = world_entry(troop)
    return start_fresh(troop, entry) if entry

    refuse(troop, "Nothing waits to fight here.", "neither a record of the player's own nor the world's entry is known")
  rescue => e
    release_through(@resume) if @resume
    @resume = nil
    log("resuming the fight against troop #{troop_id} failed: #{e.class}: #{e.message}")
    false
  end

  # Builds the world's entry of a record: where the fight is and its boss waits, and the story values
  # the world holds at the fight's start, as the DLL picks them (FreezeRecords.Held).
  #
  # @param record [Hash] The record.
  # @return [Hash] The entry: "troop", "site", "outer", "scene", "tableau", "spot" and "held".
  def self.entry_of(record)
    start = Array(record["start"])
    undone = Array(record["undone"])
    picked = MGQ_Multiplayer::Bridge.call(HELD_TOPIC, "start" => start.map { |kind, key, _| [kind, key, personal?(kind, key)] },
                                                      "undone" => undone.map { |kind, key, _| [kind, key] })
    picked = {} unless picked.is_a?(Hash)
    held = [[start, "start"], [undone, "undone"]].flat_map do |rows, name|
      flags = Array(picked[name])
      rows.each_with_index.select { |_row, index| flags[index] }.map { |row, _index| row }
    end
    {
      "troop" => record["troop"], "site" => record["site"], "outer" => record["outer"], "scene" => record["scene"] ? true : false,
      "tableau" => record["tableau"], "spot" => record["spot"], "held" => held,
    }
  end

  # Reads the save's notes of the player's frozen fights in the open world; those of another world
  # start anew.
  #
  # @return [Hash, nil] "world", "origin" and "records" (by troop); nil outside a world.
  def self.field
    world = MGQ_MpWorldStory.world_id.to_s
    return nil if world.empty? || $game_system.nil?

    notes = MGQ_MpGame.get($game_system, :raid_freeze)
    if notes.is_a?(Hash) && notes["world"] == world && notes["records"].is_a?(Hash)
      read_old_sites(notes["records"])
      return notes
    end

    if notes.is_a?(Hash) && notes["records"].is_a?(Hash) && !notes["records"].empty?
      log("dropped #{notes['records'].size} frozen fight(s) of the story of world #{notes['world'].inspect}: world #{world} plays now")
    end
    notes = { "world" => world, "origin" => nil, "records" => {} }
    MGQ_MpGame.set($game_system, :raid_freeze, notes)
    notes
  end

  # Has the DLL read the sites the records of a save of an earlier release keep as texts, such as
  # "map:138:13:1", once.
  #
  # @param records [Hash] The records by troop, which take the sites.
  def self.read_old_sites(records)
    old = records.values.select { |record| record.is_a?(Hash) && record["site"].is_a?(String) }
    return if old.empty?

    texts = old.flat_map { |record| [record["site"], record["outer"]] + Array(record["frames"]).map { |frame| frame[0] } }.select { |site| site.is_a?(String) }.uniq
    sites = MGQ_Multiplayer::Bridge.call(OLD_SITES_TOPIC, texts)
    return log_once(:old_sites, "the DLL read no sites of the frozen fights a save of an earlier release keeps") unless sites.is_a?(Array) && sites.size == texts.size

    read = Hash[texts.zip(sites)]
    old.each do |record|
      record["site"] = read[record["site"]]
      record["outer"] = read[record["outer"]] if record["outer"].is_a?(String)
      Array(record["frames"]).each { |frame| frame[0] = read[frame[0]] if frame[0].is_a?(String) }
    end
    log("read the sites of #{old.size} frozen fight record(s) a save of an earlier release keeps")
  rescue => e
    log_once(:old_sites, "reading the sites of an earlier release's frozen fights failed: #{e.class}: #{e.message}")
  end

  # Notes the story's journal mark and the events that show as the map's own event starts, with the
  # page it runs and where it stands: a freeze of a fight in it shares the world the values as they
  # were then, and its stand-ins are the events its scene brought out since. Called after
  # Game_Interpreter#setup.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @param list [Array<RPG::EventCommand>] Its commands.
  # @param event_id [Integer] The event, 0 for a common event.
  def self.note_run(interpreter, list, event_id)
    return unless $game_map && interpreter.equal?($game_map.interpreter)

    @stack = []
    return if @own_setup || event_id.to_i <= 0 || list.nil? || !active?

    event = $game_map.events[event_id.to_i]
    page = event ? event.mgq_mp_pages.index { |candidate| candidate.list.equal?(list) } : nil
    @run = { :list => list, :event_id => event_id.to_i, :map => $game_map.map_id, :mark => @seq, :shown => event_states,
             :page => page, :place => event ? [event.x, event.y] : nil }
  rescue => e
    @run = nil
    log_once(:note_run, "noting the story at an event's start failed: #{e.class}: #{e.message}")
  end

  # Runs a common event the map's event calls, keeping its frame on the stack while it runs; a
  # resume's next frame takes the call over (see hand_over). Called around Game_Interpreter#command_117.
  #
  # @param interpreter [Game_Interpreter] The calling interpreter.
  # @param original [Proc] Runs the game's command.
  # @return [Object] What the command returns.
  def self.call_common(interpreter, original)
    frame = push_call(interpreter)
    begin
      frame && frame[5] ? hand_over(interpreter, frame[5], original) : original.call
    ensure
      @stack.pop if frame && @stack.last.equal?(frame)
    end
  end

  # Puts the frame of a common event call of the map's chain on the stack, with the resume's frame
  # it hands over, if any.
  #
  # @param interpreter [Game_Interpreter] The calling interpreter.
  # @return [Array, nil] The frame: interpreter, list, index of the call, branches, common event id
  #   and the resume's frame; nil while no map interpreter runs.
  def self.push_call(interpreter)
    return nil unless MGQ_MpRaidPool.respond_to?(:in_map?) && MGQ_MpRaidPool.in_map?

    list = MGQ_MpGame.get(interpreter, :list)
    index = MGQ_MpGame.get(interpreter, :index).to_i
    id = list[index].parameters[0].to_i
    frame = [interpreter, list, index, (MGQ_MpGame.get(interpreter, :branch) || {}).dup, id, handed_frame(interpreter, id)]
    @stack.push(frame)
    frame
  rescue => e
    log_once(:push_call, "noting a common event call failed: #{e.class}: #{e.message}")
    nil
  end

  # Takes the resume's next frame when the interpreter calling a common event is the previous
  # frame's and calls that frame's common event.
  #
  # @param interpreter [Game_Interpreter] The calling interpreter.
  # @param id [Integer] The common event it calls.
  # @return [Array, nil] The frame: site key, index and branches; nil for none.
  def self.handed_frame(interpreter, id)
    resume = @resume
    return nil unless resume && resume[:stage] == :event && resume[:frames] && !resume[:frames].empty? && interpreter.equal?(resume[:caller])

    frame = resume[:frames][0]
    return nil unless frame[0] == ["ce", id]

    resume[:frames].shift
    frame
  end

  # Runs a common event of the resume's chain from its recorded place instead of its start.
  #
  # @param interpreter [Game_Interpreter] The calling interpreter.
  # @param frame [Array] The resume's frame of the common event: site key, index, branches, and the
  #   map and event its interpreter ran on at the battle.
  # @param original [Proc] Runs the game's command, when the common event is missing.
  # @return [Object] What the call returns.
  def self.hand_over(interpreter, frame, original)
    resume = @resume
    id = frame[0][1].to_i
    common = $data_common_events[id]
    return original.call unless common && common.list

    innermost = resume[:frames].empty?
    record = resume[:record]
    list = common.list
    index = innermost ? found_battle(list, frame[1], record) : found_call(list, frame[1], resume[:frames][0])
    unless index
      log("the resume of #{record['boss']} found no #{innermost ? 'battle command' : 'call'} near command #{frame[1]} of common event #{id}: it runs from its start")
      return original.call
    end

    child = Game_Interpreter.new(MGQ_MpGame.get(interpreter, :depth).to_i + 1)
    map, event_id = frame[3].is_a?(Array) ? frame[3] : [nil, nil]
    child.setup(list, event_id || (interpreter.same_map? ? interpreter.event_id : 0))
    MGQ_MpGame.set(child, :map_id, map) if map.to_i > 0
    start = innermost ? record["resume"].to_i + index - frame[1].to_i : index
    MGQ_MpGame.set(child, :index, start)
    MGQ_MpGame.set(child, :branch, frame[2].dup)
    MGQ_MpGame.set(child, :common_event_id, id)
    resume[:caller] = child
    log("the resume of #{record['boss']} runs common event #{id} from command #{start}#{innermost ? ', right before its battle' : ''}")
    child.run
  end

  # Notes the battle command an interpreter runs, which the battle set up next belongs to. Called
  # around Game_Interpreter#command_301, whose block returns only once the battle ended.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  # @param original [Proc] Runs the game's command.
  # @return [Object] What the command returns.
  def self.battle_command(interpreter, original)
    begin
      @at_301 = [interpreter, MGQ_MpGame.get(interpreter, :index).to_i, MGQ_MpGame.get(interpreter, :indent).to_i,
                 (MGQ_MpGame.get(interpreter, :branch) || {}).dup, MGQ_Multiplayer::Bridge.frame_number]
    rescue => e
      @at_301 = nil
      log_once(:battle_command, "noting a battle command failed: #{e.class}: #{e.message}")
    end
    original.call
  end

  # Takes what a raid boss battle needs should it be lost: its kind, the story's values before it,
  # and for a battle of the map's event that fights a pool, the record of the fight. Called after
  # BattleManager.setup, after MGQ_MpRaidPool.set_up.
  #
  # @param troop_id [Integer] The battle's troop.
  def self.battle_set_up(troop_id)
    troop = troop_id.to_i
    at = @at_301
    @at_301 = nil
    return log("the game's retry of troop #{troop} keeps the first battle's snapshots#{@battle ? '' : ', of which none were taken'}") if @retrying

    @battle = nil
    return unless active? && MGQ_MpRaidBosses.boss?(troop)

    at = nil if at && at[4] != MGQ_Multiplayer::Bridge.frame_number
    kind = MGQ_MpRaidPool.respond_to?(:set_up_kind) ? MGQ_MpRaidPool.set_up_kind : nil
    fight = MGQ_MpRaidPool.fight
    side = fight && fight.troop == troop && fight.side ? true : false
    resume = @resume
    if resume && resume[:troop] == troop && resume[:record]
      resume[:battled] = true
      record = resume[:record]
      record["state"] = "battle"
      @battle = { :troop => troop, :kind => kind, :side => side, :entry => nil, :start => Array(record["start"]), :pre => Array(record["pre"]),
                  :record => true, :undo => true }
      return log("the resumed fight against #{record['boss']} (troop #{troop}) fights as #{kind || 'no pool'}; its record waits for the battle's end")
    end

    resume[:battled] = true if resume && resume[:troop] == troop
    chain = at ? chain_of(at) : nil
    run = @run
    outer_list = at ? outer_list_of(at) : nil
    known = run && outer_list && run[:list].equal?(outer_list) ? true : false
    values = known ? pre_battle(run) : nil
    known &&= !values.nil?
    start, pre = values || [[], []]
    @battle = { :troop => troop, :kind => kind, :side => side, :entry => world_entry(troop), :start => start, :pre => pre,
                :record => false, :undo => at.nil? || known }
    log("a battle against troop #{troop} (#{kind || 'no pool'}#{side ? ', side' : ''}) is set up: #{start.size} story value(s) changed since its event started" \
        "#{@battle[:undo] ? '' : ', which are unknown'}#{@battle[:entry] ? ", the world's entry of the fight is known" : ''}")
    reason = freeze_refusal(troop, kind, side, at, chain, known)
    return log("troop #{troop} freezes nothing: #{reason}") if reason

    take_record(troop, at, chain, start, pre)
    @battle[:record] = true
  rescue => e
    @battle = nil
    log("taking the battle against troop #{troop_id} failed: #{e.class}: #{e.message}")
  end

  # Finds the list the map's interpreter runs outermost in the chain of a battle command.
  #
  # @param at [Array] The battle command: interpreter, index, indent, branches and frame.
  # @return [Array<RPG::EventCommand>, nil] The list, nil when no event of the map runs it.
  def self.outer_list_of(at)
    interpreter = at[0]
    stack = @stack
    outer = stack.empty? ? interpreter : stack[0][0]
    return nil unless outer.equal?($game_map.interpreter)

    stack.empty? ? MGQ_MpGame.get(interpreter, :list) : stack[0][1]
  end

  # Finds the chain of interpreters that runs a battle command: the map's interpreter, then each
  # common event it called down to the command's.
  #
  # An event that moved the player to another map before its battle command runs a page of the map
  # it started on, which the run noted, since the map shown now holds other events.
  #
  # @param at [Array] The battle command: interpreter, index, indent, branches and frame.
  # @return [Hash, String] :frames (site key, index and branches, outermost first; a common
  #   event's frame also with its interpreter's map and event), :outer_list,
  #   :event_id, :event (nil on another map), :map (the event's) and :moved; or why there is no chain.
  def self.chain_of(at)
    interpreter, index, _indent, branch = at
    stack = @stack
    depths = stack.each_with_index.all? { |frame, depth| MGQ_MpGame.get(frame[0], :depth).to_i == depth }
    return "its common event calls are not all known" unless depths && MGQ_MpGame.get(interpreter, :depth).to_i == stack.size

    outer = stack.empty? ? interpreter : stack[0][0]
    return "no event of the map runs it" unless outer.equal?($game_map.interpreter)

    event_id = outer.event_id.to_i
    return "a common event of its own started it" unless event_id > 0

    outer_list = outer_list_of(at)
    map = MGQ_MpGame.get(outer, :map_id).to_i
    map = $game_map.map_id unless map > 0
    moved = map != $game_map.map_id
    event = moved ? nil : $game_map.events[event_id]
    page = moved ? moved_page(map, event_id, outer_list) : (event ? event.mgq_mp_pages.index { |candidate| candidate.list.equal?(outer_list) } : nil)
    return "event #{event_id}#{moved ? " of map #{map}" : ''} runs none of its own pages" unless page

    keys = [["map", map, event_id, page + 1]]
    callees = stack.each_with_index.map do |frame, depth|
      callee = depth + 1 < stack.size ? stack[depth + 1][0] : interpreter
      keys << ["ce", (MGQ_MpGame.get(callee, :common_event_id) || frame[4]).to_i]
      [MGQ_MpGame.get(callee, :map_id).to_i, callee.event_id.to_i]
    end
    frames = stack.each_with_index.map { |frame, depth| [keys[depth], frame[2], frame[3].dup] }
    frames << [keys.last, index, branch.dup]
    callees.each_with_index { |callee, depth| frames[depth + 1] << callee }
    { :frames => frames, :outer_list => outer_list, :event_id => event_id, :event => event,
      :map => map, :moved => moved }
  end

  # Finds the page of an event on the map it started on, which the player left before its battle,
  # as the run noted it.
  #
  # @param map [Integer] The event's map.
  # @param event_id [Integer] The event.
  # @param list [Array<RPG::EventCommand>] The list it runs.
  # @return [Integer, nil] The page's index, nil when the run noted another event or none.
  def self.moved_page(map, event_id, list)
    run = @run
    run && run[:map] == map && run[:event_id] == event_id && run[:list].equal?(list) ? run[:page] : nil
  end

  # Finds why a raid boss battle takes no record.
  #
  # @param troop [Integer] The troop.
  # @param kind [Symbol, nil] How it fights a pool, see MGQ_MpRaidPool.set_up_kind.
  # @param side [Boolean] Whether it is a side battle.
  # @param at [Array, nil] Its battle command.
  # @param chain [Hash, String, nil] Its chain, see chain_of.
  # @param known [Boolean] Whether the story's values at its event's start are known.
  # @return [String, nil] Why, nil when it takes one.
  def self.freeze_refusal(troop, kind, side, at, chain, known)
    return "it fights no pool as an event's battle (#{kind.inspect})" unless kind == :event
    return "it is a side battle" if side
    return "its fight ended for the world, for good" if defined?(MGQ_MpWorldFreeze) && MGQ_MpWorldFreeze.respond_to?(:final?) && MGQ_MpWorldFreeze.final?(troop)
    return "no battle command of the map's event started it" unless at
    return chain if chain.is_a?(String)
    return "the story's values at its event's start are unknown" unless known

    site = chain[:frames].last[0]
    rows = data(:SITES, {})[troop] || []
    return "its site #{site} is not in the data" unless rows.any? { |row| row[0] == site }

    list = MGQ_MpGame.get(at[0], :list)
    return "its battle number #{battle_number(list, at[1])} at #{site} is not in the data" unless site_row(troop, site, list, at[1])

    map = $game_map.map_id
    return "its event moved the player away from the cutscene map #{chain[:map]}, where no stand-in can wait" if chain[:moved] && scene_map?(chain[:map])
    return "no stand-in site for the cutscene #{chain[:frames][0][0]}" if !chain[:moved] && scene_map?(map) && !data(:SCENES, {})[chain[:frames][0][0]]

    nil
  end

  # Lists the story values that changed between an event's start and now, as both had them: the
  # keys written since the run's mark, and for a resumed run the record's start values, which stand
  # for the story at its start.
  #
  # @param run [Hash] The run, see note_run.
  # @return [Array(Array, Array), nil] Each key's start value and its value now: [kind, key, value];
  #   nil when the journal lost the run's start.
  def self.pre_battle(run)
    rows = changed_since(run[:mark], run[:starts])
    unless rows
      log("the journal lost the story at the event's start: its values are unknown")
      return nil
    end

    start = []
    pre = []
    skipped = []
    rows.each do |kind, key, before, after|
      next skipped << value_name(kind, key) unless core?(key) && core?(before) && core?(after)

      start << [kind, key, before]
      pre << [kind, key, after]
    end
    log("left out #{skipped.join(', ')}: values the save field cannot keep") unless skipped.empty?
    [start, pre]
  end

  # Takes the record of a fight as its battle is set up: where it stands in the event and its common
  # events, the scene as it stands, and where its boss waits should it be lost.
  #
  # @param troop [Integer] The troop.
  # @param at [Array] Its battle command: interpreter, index, indent, branches and frame.
  # @param chain [Hash] Its chain, see chain_of.
  # @param start [Array<Array>] The story values the event changed before the battle, at their start values.
  # @param pre [Array<Array>] The same values now.
  def self.take_record(troop, at, chain, start, pre)
    map = $game_map.map_id
    moved = chain[:moved] ? true : false
    scene = !moved && scene_map?(map)
    frames = chain[:frames]
    outer = frames[0][0]
    tableau = tableau_of(chain, scene, @run ? @run[:shown] : nil)
    record = {
      "troop" => troop, "site" => frames.last[0], "outer" => outer, "scene" => scene, "tableau" => tableau,
      "spot" => [map, $game_player.x, $game_player.y, $game_player.direction],
      "state" => "battle", "boss" => MGQ_MpRaidPool.key_of(troop).to_s, "frames" => frames,
      "resume" => preamble_start(troop, frames.last[0], MGQ_MpGame.get(at[0], :list), at[1]), "indent" => at[2], "event_id" => chain[:event_id], "map" => map,
      "player" => player_row, "followers" => followers_row, "camera" => [$game_map.display_x, $game_map.display_y],
      "screen" => dumped($game_map.screen, "the screen"), "look" => look_row, "audio" => audio_row, "events" => event_rows,
      "party" => party_dump, "vehicles" => vehicles_row,
      "start" => start, "pre" => pre, "at" => Time.now.to_i,
    }
    field["records"][troop] = record
    log("took the record of the fight against #{record['boss']} (troop #{troop}) at #{frames.map { |key, index, _| "#{key} ##{index}" }.join(' > ')}, " \
        "resuming at ##{record['resume']}; " \
        "#{scene || moved ? "#{scene ? 'a cutscene' : "its event moved the player here from map #{chain[:map]}"}, its boss waits on map #{tableau[0]}" : 'its boss waits here'}")
  end

  # Finds where a battle command's preamble starts in the live list: as far before it as its row of
  # the freeze's SITES puts the preamble before the battle.
  #
  # @param troop [Integer] The troop.
  # @param site [Array] The site key of the list that holds the battle command.
  # @param list [Array<RPG::EventCommand>] The list that holds it.
  # @param index [Integer] The battle command's index.
  # @return [Integer] The preamble's first index, the battle command's when there is none.
  def self.preamble_start(troop, site, list, index)
    row = site_row(troop, site, list, index)
    index - (row[1] - row[3])
  end

  # Finds the row of the freeze's SITES of a battle command: by its site and its battle number, since
  # the events database's indexes are the untranslated game's, which a translation shifts.
  #
  # @param troop [Integer] The troop.
  # @param site [Array] The site key of the list that holds the battle command.
  # @param list [Array<RPG::EventCommand>] The list that holds it.
  # @param index [Integer] The battle command's index.
  # @return [Array, nil] The row, nil for none.
  def self.site_row(troop, site, list, index)
    number = battle_number(list, index)
    (data(:SITES, {})[troop] || []).find { |row| row[0] == site && row[5] == number }
  end

  # Counts the battle commands of a list before an index, which is the battle number of the one there.
  #
  # @param list [Array<RPG::EventCommand>] The list.
  # @param index [Integer] The index.
  # @return [Integer] The count.
  def self.battle_number(list, index)
    Array(list)[0, index].to_a.count { |command| command.code == 301 }
  end

  # Builds a fight's tableau: the DLL tells where it stands and which events it blocks
  # (FreezeTableau.Place), and the map tells which events stand in, see field_rows and away_row.
  #
  # @param chain [Hash] The fight's chain, see chain_of.
  # @param scene [Boolean] Whether its battle runs on a cutscene map.
  # @param before [Hash, nil] The events as the fight's event started, see event_states.
  # @return [Array] The tableau: map, sprite rows and the events whose start is blocked.
  def self.tableau_of(chain, scene, before)
    run = @run
    moved = chain[:moved] ? true : false
    frames = chain[:frames]
    place = MGQ_Multiplayer::Bridge.call!(TABLEAU_TOPIC, "scene" => scene, "moved" => moved, "map" => moved ? chain[:map] : $game_map.map_id,
                                                         "event" => chain[:event_id], "outer" => frames[0][0], "origin" => field["origin"],
                                                         "place" => moved && run ? run[:place] : nil, "frames" => frames.map { |frame| frame[0] })
    map = place["map"]
    blocked = Array(place["blocked"])
    log("blocks the starts of events #{blocked.inspect} on map #{map}, #{place['callers']} of them other callers of its common events") if place["callers"].to_i > 0
    rows = place["at"] ? [away_row(chain, scene, before, map, place["at"])] : field_rows(chain[:event], before, map)
    [map, rows, blocked]
  end

  # Writes the stand-ins of a fight on a field map: its boss and the events only its scene shows,
  # each standing in for itself. The map's other events stay live, so its shops, inns and villagers
  # serve on while the boss waits.
  #
  # @param outer [Game_Event] The event whose page runs the fight.
  # @param before [Hash, nil] The events as the fight's event started, see event_states.
  # @param map [Integer] The map, for the log.
  # @return [Array<Array>] The sprite rows.
  def self.field_rows(outer, before, map)
    shown = visible_events
    scene = scene_events(shown, before)
    boss = boss_event(outer, shown, scene)
    kept = (scene + [boss]).compact.uniq.sort_by(&:id)
    rows = kept.map { |event| sprite_row(event, event.x, event.y, event.direction, event.equal?(boss), 1) }
    rows << [outer.id, outer.x, outer.y, outer.direction, 0, "", 0, 0, 255, 0, 1, 1, 1] unless boss
    log("the frozen scene of map #{map} keeps #{boss ? "event #{boss.id}" : 'an unseen stand-in'} as its boss and the events its scene shows " \
        "#{scene.map(&:id).inspect}; #{shown.size - kept.size} other event(s) that showed before it stay live")
    rows
  end

  # Writes the stand-in of a fight whose boss waits away from the battle's map: a cutscene's boss,
  # picked among the events of the cutscene as on a field map, or the boss of a fight whose event
  # moved the player away before its battle, picked among the battle map's events alone, since the
  # run's notes of which events showed belong to the map the event started on.
  #
  # @param chain [Hash] The fight's chain, see chain_of.
  # @param scene [Boolean] Whether its battle runs on a cutscene map.
  # @param before [Hash, nil] The events as the fight's event started, see event_states.
  # @param map [Integer] The map the boss waits on, for the log.
  # @param at [Array(Integer, Integer)] Where it waits.
  # @return [Array] The sprite row.
  def self.away_row(chain, scene, before, map, at)
    x, y = at
    shown = visible_events
    boss = scene ? boss_event(chain[:event], shown, scene_events(shown, before)) : boss_event(nil, shown, [])
    log("the fight's event #{chain[:event_id]} moved the player from map #{chain[:map]} to map #{$game_map.map_id} before its battle: " \
        "#{boss ? "event #{boss.id} of the battle's map" : 'an unseen stand-in'} waits at #{x},#{y} on map #{map}") unless scene
    boss ? sprite_row(boss, x, y, 2, true, 0) : [chain[:event_id], x, y, 2, 0, "", 0, 0, 255, 0, 1, 1, 0]
  end

  # Notes each event of the map: the page it shows, whether it shows and where it stands.
  #
  # @return [Hash{Integer => Array(Integer, Boolean, Integer, Integer)}] Each event's page index (-1
  #   for none), whether it shows, and its x and y, by id.
  def self.event_states
    $game_map.events.each_with_object({}) { |(id, event), states| states[id] = [event.mgq_mp_page, shows?(event), event.x, event.y] }
  end

  # Lists the map's events that show: a graphic, not see-through, not erased.
  #
  # @return [Array<Game_Event>] The events by id.
  def self.visible_events
    $game_map.events.keys.sort.map { |id| $game_map.events[id] }.select { |event| shows?(event) }
  end

  # Reports whether an event shows: a graphic, not see-through, not erased.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it does.
  def self.shows?(event)
    (!event.character_name.to_s.empty? || event.tile_id.to_i > 0) && event.opacity.to_i > 0 && !event.transparent && !MGQ_MpGame.get(event, :erased) ? true : false
  end

  # Lists the events that show only because of the fight's scene: those that showed nothing as its
  # event started, those that turned to a page of a scene's switch since (see scene_page?), and
  # those the scene changed in place whose page now runs nothing (see changed_quiet?).
  #
  # An event that showed as the event started and whose page now runs something, such as a shop or
  # a villager to talk to, is one of the map's own people and stays live.
  #
  # @param shown [Array<Game_Event>] The events that show now.
  # @param before [Hash, nil] The events as the fight's event started, see event_states; nil when
  #   unknown, which keeps none.
  # @return [Array<Game_Event>] The events by id.
  def self.scene_events(shown, before)
    return [] unless before.is_a?(Hash)

    shown.select do |event|
      page, showed, x, y = before[event.id]
      now = event.mgq_mp_page
      next false if page.nil?

      !showed || (page != now && now >= 0 && scene_page?(event, now)) || changed_quiet?(event, page, x, y)
    end
  end

  # Reports whether the scene changed an event that showed as the fight's event started: it turned to
  # another page, or it stands elsewhere on a page that does not move by itself; and its page now
  # runs nothing, a figure of the scene rather than one of the map's people.
  #
  # @param event [Game_Event] The event.
  # @param page [Integer] Its page index as the fight's event started.
  # @param x [Integer, nil] Its x then, nil when unknown.
  # @param y [Integer, nil] Its y then.
  # @return [Boolean] Whether it did.
  def self.changed_quiet?(event, page, x, y)
    now = event.mgq_mp_page
    return false unless now >= 0 && runs_nothing?(event)
    return true if page != now

    moved = !x.nil? && (event.x != x || event.y != y)
    moved && event.mgq_mp_pages[now].move_type.to_i == 0
  end

  # Reports whether a page shows only during a scene, as the DLL's events database tells it for a
  # page it holds as the game does (see page_flags).
  #
  # @param event [Game_Event] The event.
  # @param place [Integer] The page's place.
  # @return [Boolean] Whether it does; false for a page the database does not tell of.
  def self.scene_page?(event, place)
    flags = page_flags(event, place)
    flags ? flags["scene_page"] == true : false
  end

  # Reports whether an event's page runs nothing when started, such as a figure only shown, as the
  # DLL's events database tells it for a page it holds as the game does (see page_flags).
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it does; false for a page the database does not tell of.
  def self.runs_nothing?(event)
    place = event.mgq_mp_page
    flags = place >= 0 ? page_flags(event, place) : nil
    flags ? flags["runs_nothing"] == true : false
  end

  # Reads what the DLL's events database found in a page of the map, see
  # MGQ_MpCoopEvents.page_flags.
  #
  # @param event [Game_Event] The event.
  # @param place [Integer] The page's place.
  # @return [Hash, nil] The flags, nil for a page the database does not tell of.
  def self.page_flags(event, place)
    MGQ_MpCoopEvents.respond_to?(:page_flags) ? MGQ_MpCoopEvents.page_flags(event, place) : nil
  end

  # Picks the event that stands in for the boss: the fight's own event when it shows; else among
  # the events only the scene shows; else among the shown figures whose page runs nothing, a shop
  # or a villager to talk to never. See pick.
  #
  # @param outer [Game_Event] The fight's event.
  # @param shown [Array<Game_Event>] The events that show.
  # @param scene [Array<Game_Event>] The events only the scene shows, see scene_events.
  # @return [Game_Event, nil] The event, nil when none fits.
  def self.boss_event(outer, shown, scene)
    return outer if shown.any? { |event| event.equal?(outer) }

    figures = shown.select { |event| runs_nothing?(event) && figure?(event) }
    pick(scene) || pick(figures)
  end

  # Picks the likeliest boss among events: the one with a large sprite ("$") nearest the player,
  # else the nearest character, else the nearest of all, ties to the lower id.
  #
  # @param events [Array<Game_Event>] The events.
  # @return [Game_Event, nil] The event, nil for none.
  def self.pick(events)
    nearest(events.select { |event| event.character_name.to_s.start_with?("$") }) || nearest(events.select { |event| figure?(event) }) || nearest(events)
  end

  # Reports whether an event shows a character rather than a tile or an object ("!" pictures such
  # as chests, doors and flames).
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it does.
  def self.figure?(event)
    name = event.character_name.to_s
    !name.empty? && !name.start_with?("!")
  end

  # Finds the event nearest the player, in steps either way, ties to the lower id.
  #
  # @param events [Array<Game_Event>] The events.
  # @return [Game_Event, nil] The event, nil for none.
  def self.nearest(events)
    events.min_by { |event| [[(event.x - $game_player.x).abs, (event.y - $game_player.y).abs].max, event.id] }
  end

  # Writes a stand-in's sprite row of an event, see the tableau's rows.
  #
  # @param event [Game_Event] The event.
  # @param x [Integer] Where the stand-in stands.
  # @param y [Integer] Where the stand-in stands.
  # @param direction [Integer] Where it faces.
  # @param boss [Boolean] Whether it is the boss.
  # @param hide [Integer] 1 when it stands for the live event of its id, 0 when it stands elsewhere.
  # @return [Array] The row.
  def self.sprite_row(event, x, y, direction, boss, hide)
    [event.id, x, y, direction, event.pattern, event.character_name.to_s, event.character_index, event.tile_id, event.opacity,
     event.blend_type, event.priority_type, boss ? 1 : 0, hide]
  end

  # Writes where the player stands and how they show and move.
  #
  # @return [Array] Map, x, y, direction, transparent, through, move speed and vehicle's name.
  def self.player_row
    player = $game_player
    [$game_map.map_id, player.x, player.y, player.direction, player.transparent ? true : false, player.through ? true : false,
     player.move_speed, (MGQ_MpGame.get(player, :vehicle_type) || :walk).to_s]
  end

  # Writes where each of the game's vehicles stands.
  #
  # @return [Array<Array>] Each vehicle's type, map, x, y and direction.
  def self.vehicles_row
    VEHICLE_TYPES.map do |type|
      vehicle = $game_map.vehicle(type)
      [type.to_s, MGQ_MpGame.get(vehicle, :map_id).to_i, vehicle.x, vehicle.y, vehicle.direction]
    end
  end

  # Writes whether the followers show and where each stands.
  #
  # @return [Array] Whether they show, and each one's x, y and direction.
  def self.followers_row
    places = []
    $game_player.followers.each { |follower| places << [follower.x, follower.y, follower.direction] }
    [$game_player.followers.visible ? true : false, places]
  end

  # Writes the map's tileset, parallax and battle backs.
  #
  # @return [Array] Tileset, parallax name, its loops and scrolls, and both battle backs.
  def self.look_row
    map = $game_map
    [MGQ_MpGame.get(map, :tileset_id), map.parallax_name.to_s, MGQ_MpGame.get(map, :parallax_loop_x) ? true : false,
     MGQ_MpGame.get(map, :parallax_loop_y) ? true : false, MGQ_MpGame.get(map, :parallax_sx).to_i, MGQ_MpGame.get(map, :parallax_sy).to_i,
     map.battleback1_name.to_s, map.battleback2_name.to_s]
  end

  # Writes the music and sounds playing and the battle music.
  #
  # @return [Array] The music's and sound's name, volume, pitch and position, and the battle music's.
  def self.audio_row
    sound = lambda { |audio| audio ? [audio.name.to_s, audio.volume.to_i, audio.pitch.to_i, audio.respond_to?(:pos) ? audio.pos.to_i : 0] : ["", 100, 100, 0] }
    battle = $game_system.battle_bgm
    [sound.call(RPG::BGM.last), sound.call(RPG::BGS.last), battle ? [battle.name.to_s, battle.volume.to_i, battle.pitch.to_i] : ["", 100, 100]]
  rescue => e
    log("noting the music failed: #{e.class}: #{e.message}")
    [["", 100, 100, 0], ["", 100, 100, 0], ["", 100, 100]]
  end

  # Writes every event of the map as it shows and moves.
  #
  # @return [Array<Array>] Each event's row, by id.
  def self.event_rows
    $game_map.events.keys.sort.map do |id|
      e = $game_map.events[id]
      [id, e.x, e.y, e.direction, e.pattern, e.character_name.to_s, e.character_index, e.tile_id, e.opacity, e.blend_type,
       e.transparent ? true : false, own_through(e), MGQ_MpGame.get(e, :erased) ? true : false, e.priority_type,
       e.direction_fix ? true : false, e.walk_anime ? true : false, e.step_anime ? true : false, e.move_speed]
    end
  end

  # Dumps an object of the game into text the save field keeps.
  #
  # @param object [Object] The object.
  # @param what [String] What it is, for the log.
  # @return [String, nil] The dump, nil when it cannot be dumped.
  def self.dumped(object, what)
    Marshal.dump(object)
  rescue => e
    log("could not keep #{what}: #{e.class}: #{e.message}")
    nil
  end

  # Takes the journal's mark as a raid boss battle's defeat starts, which its end puts back what the
  # defeat changed since. Called before BattleManager.process_defeat.
  def self.defeated
    battle = @battle
    return unless battle

    @stack = []
    @at_301 = nil
    troop = battle[:troop]
    reason = defeat_refusal(battle)
    plan = record_end(2, battle, reason ? true : false)
    if reason
      return log("the lost battle against troop #{troop} puts nothing back: #{reason}#{plan['record'] == 'drop' ? '; its record goes' : ''}")
    end

    @pending = { :troop => troop, :kind => battle[:kind], :mark => @seq, :items => item_counts,
                 :start => battle[:start], :pre => battle[:pre], :at => MGQ_Multiplayer::Bridge.frame_number }
    log("lost the battle against #{label(troop)} (troop #{troop}, #{battle[:kind] || 'no pool'}#{battle[:side] ? ', side' : ''}): " \
        "its defeat's changes of the story go back once it ended#{plan['record'] == 'lost' ? ', and the fight waits' : ''}")
  rescue => e
    @pending = nil
    log("taking the story at the defeat failed: #{e.class}: #{e.message}")
  end

  # Asks the DLL why a lost raid boss battle's defeat changes nothing back (FreezeRules.DefeatRefusal):
  # the player left the Raid World's story, another troop fights, the event goes on after a defeat,
  # a replay of the Library, a Hades rematch, a Colosseum battle, a Hades hall, the story at the
  # event's start unknown, or an event's battle whose fight froze no record though it is not over.
  #
  # @param battle [Hash] The battle, see battle_set_up.
  # @return [String, nil] Why, nil when it changes back.
  def self.defeat_refusal(battle)
    MGQ_Multiplayer::Bridge.call(DEFEAT_TOPIC, "troop" => battle[:troop], "troop_now" => MGQ_MpGame.get($game_troop, :troop_id).to_i, "active" => active?,
                                               "can_lose" => MGQ_MpGame.get(BattleManager, :can_lose) ? true : false,
                                               "library" => BattleManager.respond_to?(:memory_battle?) && BattleManager.memory_battle? ? true : false,
                                               "known" => battle[:undo] ? true : false, "kind" => battle[:kind] && battle[:kind].to_s,
                                               "record" => battle[:record] ? true : false,
                                               "over" => defined?(MGQ_MpWorldFreeze) && MGQ_MpWorldFreeze.final?(battle[:troop]) ? true : false,
                                               "facts" => MGQ_MpRaidBosses.facts)
  end

  # Counts the player's items, weapons and armors.
  #
  # @return [Hash{Array => Integer}] How many of each the party has, by letter and id, above 0 only.
  def self.item_counts
    counts = {}
    [["i", $data_items], ["w", $data_weapons], ["a", $data_armors]].each do |letter, table|
      (table || []).each_with_index do |item, id|
        next unless item

        number = $game_party.item_number(item).to_i
        counts[[letter, id]] = number if number > 0
      end
    end
    counts
  end

  # Runs the game's retry of a lost battle, noting it, so the save it loads keeps what the first
  # battle took. Called around BattleManager.retry_battle.
  #
  # @return [Object] What the retry returns.
  def self.retrying
    @retrying = true
    yield
  ensure
    @retrying = false
  end

  # Follows a raid boss battle's end: a fight won or escaped needs its record no longer, and a won
  # joined or side battle ends the joiner's own record of the boss too and brings them onto the
  # starter's spot, else their own record's. Called before BattleManager.battle_end.
  #
  # @param result [Integer] 0 won, 1 escaped, 2 lost.
  def self.battle_ended(result)
    battle = @battle
    return unless battle
    # A lost battle keeps its snapshots for the game's retry, which sets it up again.
    return if result == 2

    @battle = nil
    troop = battle[:troop]
    plan = record_end(result, battle)
    if plan["won"]
      MGQ_MpWorldFreeze.won(troop) if defined?(MGQ_MpWorldFreeze)
      log("won the battle against troop #{troop}: the world's frozen fight against it ends")
    end
    spot = plan["spot"]
    if spot
      @teleport = { :troop => troop, :spot => spot }
      log("the won #{battle[:kind]} battle against troop #{troop} brings the player onto #{plan['whose']} spot #{spot.join(',')}")
    elsif plan["won"] && [:guest, :side].include?(battle[:kind])
      log("the won #{battle[:kind]} battle against troop #{troop} has no spot of the starter nor of an own record")
    end
  rescue => e
    log("following the battle's end failed: #{e.class}: #{e.message}")
  end

  # Asks the DLL what becomes of the player's record of a battle's troop as the battle ends
  # (FreezeRecords.AtEnd), and drops the record or marks it lost as it answers.
  #
  # @param result [Integer] 0 won, 1 escaped, 2 lost.
  # @param battle [Hash] The battle, see battle_set_up.
  # @param refused [Boolean] Whether a lost battle's defeat puts nothing back, see defeat_refusal.
  # @return [Hash] "won", "record", "spot" and "whose".
  def self.record_end(result, battle, refused = false)
    troop = battle[:troop]
    record = record_for(troop)
    entry = battle[:entry]
    plan = MGQ_Multiplayer::Bridge.call!(END_TOPIC, "result" => result, "kind" => battle[:kind] && battle[:kind].to_s, "state" => record && record["state"],
                                                    "refused" => refused, "took" => battle[:record] ? true : false,
                                                    "entry_spot" => entry && entry["spot"], "record_spot" => record && record["spot"])
    case plan["record"]
    when "drop"
      field["records"].delete(troop)
      log(record["state"] == "battle" ? "the fight against #{record['boss']} (troop #{troop}) was #{%w(won escaped lost)[result]}: its record goes" :
          "the boss of troop #{troop} fell in the won #{battle[:kind]} battle: the player's own #{record['state']} record of it goes")
    when "lost"
      record["state"] = "lost"
    end
    plan
  end

  # Notes where the player leaves a field map for a cutscene map, where a fight on the cutscene map
  # puts its boss. Called before Game_Player#perform_transfer.
  #
  # @param player [Game_Player] The player.
  def self.leaving(player)
    return unless player.transfer? && $game_map && active?

    from = $game_map.map_id
    target = MGQ_MpGame.get(player, :new_map_id).to_i
    return if scene_map?(from) || !scene_map?(target)

    notes = field
    return unless notes

    notes["origin"] = [from, player.x, player.y, player.direction]
    log("the player leaves map #{from} at #{player.x},#{player.y} for the cutscene map #{target}")
  rescue => e
    log_once(:leaving, "noting the way into a cutscene failed: #{e.class}: #{e.message}")
  end

  # Keeps the map's events from starting while a resume waits for its transfer, so the frozen
  # event's own start cannot run its first commands before the resume puts the scene back. Called
  # before Game_Map#setup_starting_map_event.
  #
  # @param map [Game_Map] The map.
  def self.hold_starts(map)
    resume = @resume
    return unless resume && resume[:stage] == :transfer

    map.events.each_value do |event|
      next unless event.starting

      event.clear_starting_flag
      event.unlock
      log_once([:held_start, map.map_id, event.id, resume[:troop]],
               "held event #{event.id}'s start on map #{map.map_id}: the resume of troop #{resume[:troop]} waits for its transfer")
    end
  rescue => e
    log_once(:hold_starts, "holding the map's events during a resume failed: #{e.class}: #{e.message}")
  end

  # Readies the resume once the player arrived on its map, off any vehicle, before any other event
  # of the map can start. Called after Game_Player#perform_transfer.
  def self.transferred
    resume = @resume
    return unless resume && resume[:stage] == :transfer && $game_map.map_id == resume[:target]

    resume[:stage] = :arrived
    log("the resume of troop #{resume[:troop]} arrived on map #{$game_map.map_id}")
    leave_vehicle(resume)
    resume[:record] ? restore_and_start(resume) : start_fresh_here(resume)
  rescue => e
    fail_resume(resume, "readying it on arrival failed: #{e.class}: #{e.message}")
  end

  # Puts the scene back as it stood at the battle command and runs the event on from there.
  #
  # @param resume [Hash] The resume.
  def self.restore_and_start(resume)
    record = resume[:record]
    return unless free_interpreter(record["event_id"], resume, site_parts(record["frames"][0][0])[0] == $game_map.map_id)

    write_values(record["pre"])
    $game_map.refresh
    restore_events(record["events"])
    restore_player(record)
    place_vehicles(record["vehicles"], $game_map.map_id)
    resume_screen(record["screen"], resume[:flow])
    restore_look(record["look"])
    restore_audio(record["audio"])
    clear_starts
    log("put the scene of #{record['boss']} back: #{Array(record['pre']).size} story value(s), #{Array(record['events']).size} event(s), the player and the screen")
    start_interpreter(resume, record)
  end

  # Makes sure no event of the map runs as the resume starts one, ending the frozen event's own
  # start that came first.
  #
  # @param event_id [Integer] The frozen event.
  # @param resume [Hash] The resume.
  # @param here [Boolean] Whether the frozen event is one of this map's, which an event that moved
  #   the player away from its own map before its battle is not.
  # @return [Boolean] Whether the interpreter is free.
  def self.free_interpreter(event_id, resume, here = true)
    interpreter = $game_map.interpreter
    return true unless interpreter.running?

    unless here && interpreter.event_id == event_id
      fail_resume(resume, "event #{interpreter.event_id} runs on arrival")
      return false
    end
    $game_map.events[event_id].unlock if $game_map.events[event_id]
    interpreter.clear
    log("ended event #{event_id}'s own start on arrival: the resume runs it")
    true
  end

  # Sets up the map's interpreter at the record's place: the outermost frame's call, or right before
  # the battle command, with each frame's branches. An event that moved the player away from its
  # own map before its battle runs its page from that map's data, its interpreter on that map as at
  # the battle.
  #
  # @param resume [Hash] The resume.
  # @param record [Hash] The record.
  def self.start_interpreter(resume, record)
    frames = record["frames"]
    key, index, branch = frames[0]
    event_id = record["event_id"]
    map = site_parts(key)[0] || $game_map.map_id
    moved = map != $game_map.map_id
    event = moved ? nil : $game_map.events[event_id]
    page = page_number(key)
    list = moved ? page_list(map, event_id, page) : (event && page && event.mgq_mp_pages[page - 1] ? event.mgq_mp_pages[page - 1].list : nil)
    found = list && (frames.size > 1 ? found_call(list, index, frames[1]) : found_battle(list, index, record))
    return fall_back(resume, event, page, "found no #{frames.size > 1 ? 'call' : 'battle command'} near command #{index} of #{key}") unless found

    start = frames.size > 1 ? found : record["resume"].to_i + found - index.to_i
    mark = @seq
    interpreter = $game_map.interpreter
    @own_setup = true
    begin
      as_story { interpreter.setup(list, event_id) }
    ensure
      @own_setup = false
    end
    MGQ_MpGame.set(interpreter, :map_id, map) if moved
    @run = { :list => list, :event_id => event_id, :map => map, :mark => mark, :starts => Array(record["start"]) }
    MGQ_MpGame.set(interpreter, :index, start)
    MGQ_MpGame.set(interpreter, :branch, branch.dup)
    resume[:frames] = frames[1..-1].map { |frame| [frame[0], frame[1], frame[2].dup, frame[3]] }
    resume[:caller] = interpreter
    resume[:stage] = :event
    log("resumes #{key} at command #{start}#{frames.size > 1 ? " through #{frames[1..-1].map(&:first).join(' > ')}" : ', right before its battle'}" \
        "#{moved ? ", its interpreter on map #{map} as at the battle" : ''}")
  end

  # Reads the commands of an event's page from a map's data.
  #
  # @param map [Integer] The map.
  # @param event_id [Integer] The event.
  # @param page [Integer, nil] The page, 1-based.
  # @return [Array<RPG::EventCommand>, nil] The commands, nil when the map lacks the page.
  def self.page_list(map, event_id, page)
    event = page ? load_data(DataManager.map_file_name(map)).events[event_id] : nil
    data_page = event ? event.pages[page - 1] : nil
    data_page ? data_page.list : nil
  rescue => e
    log("reading page #{page} of event #{event_id} of map #{map} failed: #{e.class}: #{e.message}")
    nil
  end

  # Starts the record's event from its first command when its place is not found, if its event shows
  # the page.
  #
  # @param resume [Hash] The resume.
  # @param event [Game_Event, nil] The event.
  # @param page [Integer, nil] The page, 1-based.
  # @param reason [String] Why, for the log.
  def self.fall_back(resume, event, page, reason)
    return fail_resume(resume, "#{reason}, and its event is not on this map") unless event
    return fail_resume(resume, "#{reason}, and the event shows another page") unless page && event.mgq_mp_page == page - 1

    log("the resume #{reason}: the event runs from its first command")
    resume[:record] = nil
    as_story { $game_map.interpreter.setup(event.mgq_mp_pages[page - 1].list, event.id) }
    resume[:stage] = :event
  end

  # Finds the call of the next frame's common event in a list, at its index or the nearest one.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The recorded index.
  # @param next_frame [Array] The next frame: site key, index and branches.
  # @return [Integer, nil] The index, nil for none.
  def self.found_call(list, index, next_frame)
    id = next_frame[0][1].to_i
    found_command(list, index, nil) { |command| command.code == CALL_CODE && command.parameters[0].to_i == id }
  end

  # Finds the battle command of a record's troop in a list, at its index or the nearest one of the
  # same indent.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The recorded index.
  # @param record [Hash] The record.
  # @return [Integer, nil] The index, nil for none.
  def self.found_battle(list, index, record)
    troop = record["troop"].to_i
    found_command(list, index, record["indent"]) { |command| command.code == BATTLE_CODE && command.parameters[0] == 0 && command.parameters[1].to_i == troop }
  end

  # Finds a command at its recorded index, else the nearest that matches, as another build of the
  # game may have moved it.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The recorded index.
  # @param indent [Integer, nil] The indent another index must have; nil for any.
  # @yieldparam command [RPG::EventCommand] A command.
  # @yieldreturn [Boolean] Whether it matches.
  # @return [Integer, nil] The index, nil for none.
  def self.found_command(list, index, indent)
    index = index.to_i
    return index if list[index] && yield(list[index])

    found = (0...list.size).select { |at| yield(list[at]) && (indent.nil? || list[at].indent == indent) }.min_by { |at| [(at - index).abs, at] }
    log("the recorded command #{index} moved to #{found}") if found
    found
  end

  # Starts a world entry's event from its first command on the map the player arrived on: a
  # cutscene's, or a field event's after the transfer onto the spot that starts it.
  #
  # @param resume [Hash] The resume.
  def self.start_fresh_here(resume)
    _map, event_id, page = site_parts(resume[:site])
    event = $game_map.events[event_id]
    return fail_resume(resume, "event #{event_id} shows another page than #{page} here") unless event && event.mgq_mp_page == page - 1
    return unless free_interpreter(event_id, resume)

    clear_starts
    as_story { $game_map.interpreter.setup(event.mgq_mp_pages[page - 1].list, event_id) }
    resume[:stage] = :event
    log("started #{resume[:site]} from its first command for the fight against troop #{resume[:troop]}")
  end

  # Gives up a resume, telling the player, while the record stays frozen; what it put back of the
  # battle's moment goes back as it was before the press, see roll_back.
  #
  # @param resume [Hash, nil] The resume.
  # @param reason [String] Why, for the log.
  def self.fail_resume(resume, reason)
    @resume = nil
    troop = resume ? resume[:troop] : nil
    notice("Could not resume the fight against #{label(troop)}.")
    log("the resume of troop #{troop.inspect} stopped: #{reason}")
    release_through(resume) if resume
    roll_back(resume) if resume && resume[:snapshot] && !resume[:battled]
  end

  # Takes what a resume changes as it starts: the story values its record puts back, the party,
  # the screen, the map's look, the music, the events, and where the player stands.
  #
  # @param record [Hash, nil] The record, nil for a world entry's start, which puts no values back.
  # @return [Hash] The snapshot, with a record's keys of the same things.
  def self.snapshot(record)
    values = Array(record ? record["pre"] : nil).map { |kind, key, _value| [kind, key, read_value(kind, key)] }
    { "values" => values, "party" => party_dump, "player" => player_row, "followers" => followers_row,
      "camera" => [$game_map.display_x, $game_map.display_y], "screen" => dumped($game_map.screen, "the screen"), "look" => look_row,
      "audio" => audio_row, "events" => event_rows, "vehicles" => vehicles_row }
  end

  # Puts back what a resume given up before its battle changed, from its snapshot: the story values,
  # the party, the screen and the music; the events and the map's look on the map it started on;
  # the vehicles; and the player goes back to where they pressed, on the vehicle they drove then,
  # once the map is free (see return_player).
  #
  # @param resume [Hash] The resume.
  def self.roll_back(resume)
    snapshot = resume[:snapshot]
    write_values(snapshot["values"])
    $game_map.refresh
    restore_party(snapshot["party"])
    restore_screen(snapshot["screen"])
    restore_audio(snapshot["audio"])
    spot = snapshot["player"]
    here = $game_map.map_id == spot[0]
    if here
      restore_events(snapshot["events"])
      restore_look(snapshot["look"])
    end
    restore_player(snapshot)
    place_vehicles(snapshot["vehicles"])
    board(snapshot["player"][7])
    log("put back what the resume of troop #{resume[:troop]} changed: #{snapshot['values'].size} story value(s), the party, the screen and the music" \
        "#{here ? ", the map's events and look" : ''}")
    return if here && $game_player.x == spot[1] && $game_player.y == spot[2]

    @return_to = { :troop => resume[:troop], :spot => spot[0, 4] }
    log("the player goes back to map #{spot[0]} at #{spot[1]},#{spot[2]}, where they started the fight, once the map is free")
  rescue => e
    log("putting back what the resume of troop #{resume[:troop]} changed failed: #{e.class}: #{e.message}")
  end

  # Brings the player back to where they started a resume given up, once the map is free.
  def self.return_player
    return unless map_free?

    back = @return_to
    @return_to = nil
    spot = back[:spot]
    $game_player.reserve_transfer(spot[0], spot[1], spot[2], spot[3])
    $game_temp.fade_type = 0
    log("brought the player back to map #{spot[0]} at #{spot[1]},#{spot[2]}, where they started the fight against troop #{back[:troop]}")
  end

  # Reads one story value of the game as it keeps it.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Object] Its value, nil for a self switch that is not set.
  def self.read_value(kind, key)
    [MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables), MGQ_MpStoryState.data_of($game_self_switches)][kind][key]
  end

  # Dumps the party's temporary members and split parties.
  #
  # @return [String, nil] The dump, nil when it cannot be dumped.
  def self.party_dump
    dumped([MGQ_MpGame.get($game_party, :temp_actors), MGQ_MpGame.get($game_party, :multi_party_flag), MGQ_MpGame.get($game_party, :multi_party)], "the party")
  end

  # Finds why the player may not start a frozen fight now.
  #
  # @param troop [Integer] The troop.
  # @return [Array(String, String), nil] The notice and the reason for the log; nil when they may.
  def self.resume_refusal(troop)
    name = label(troop)
    return ["Cannot fight #{name} now.", "the player plays no Raid World's story"] unless active?
    return ["Cannot fight #{name} now.", "the fight against troop #{@resume[:troop]} resumes already"] if @resume
    return ["Cannot fight #{name} now.", "the lost battle's story is still being put back"] if holding_writes?
    return ["Cannot fight #{name} now.", "the player goes back from a fight given up"] if @return_to

    return ["Cannot fight #{name} now.", "the player is not free on the map"] unless map_free?

    teller = teller_name
    teller ? ["#{teller} is telling the story here.", "#{teller} tells the story here"] : nil
  end

  # Refuses a resume, telling the player.
  #
  # @param troop [Integer] The troop.
  # @param text [String] The notice.
  # @param reason [String] Why, for the log.
  # @return [Boolean] false.
  def self.refuse(troop, text, reason)
    notice(text)
    log("refused the fight against troop #{troop}: #{reason}")
    false
  end

  # Starts the resume of the player's own record: the party as at the battle, then the transfer onto
  # the spot they stood on.
  #
  # @param troop [Integer] The troop.
  # @param record [Hash] The record.
  # @return [Boolean] true.
  def self.resume_record(troop, record)
    flow = defined?(MGQ_MpFlowGuard) ? MGQ_MpFlowGuard.resume_begins : nil
    before = snapshot(record)
    restore_party(record["party"])
    player = record["player"]
    $game_player.reserve_transfer(player[0], player[1], player[2], player[3])
    $game_temp.fade_type = 0
    @resume = { :troop => troop, :record => record, :stage => :transfer, :target => player[0], :snapshot => before, :flow => flow }
    log("resumes the fight against #{record['boss']} (troop #{troop}): to map #{player[0]} at #{player[1]},#{player[2]}")
    true
  end

  # Starts a world entry's event from its first command as the DLL plans it (FreezeFresh.Plan): a
  # cutscene's on the cutscene map of the player's side, after a transfer onto its way in; a field
  # page after a transfer onto the spot its trigger starts it from, or where the player stands.
  #
  # @param troop [Integer] The troop.
  # @param entry [Hash] The world entry.
  # @return [Boolean] Whether it started.
  def self.start_fresh(troop, entry)
    map, event_id, _page = site_parts(entry["outer"])
    event = map == $game_map.map_id ? $game_map.events[event_id] : nil
    shown = event ? event.mgq_mp_page : nil
    page = shown && shown >= 0 ? event.mgq_mp_pages[shown] : nil
    plan = MGQ_Multiplayer::Bridge.call!(FRESH_TOPIC, "troop" => troop, "scene" => entry["scene"] ? true : false, "outer" => entry["outer"],
                                                      "map" => $game_map.map_id, "shown" => shown, "trigger" => page ? page.trigger.to_i : nil,
                                                      "switches" => entry["scene"] ? switches_on : [])
    return refuse(troop, "Cannot fight #{label(troop)} here yet.", plan["refusal"]) unless plan["start"]
    return start_fresh_scene(troop, plan) if plan["start"] == "scene"
    return start_fresh_in_place(troop, entry, event, nil) if plan["start"] == "here"

    start_fresh_field(troop, entry, event, plan["start"] == "touch")
  end

  # Lists the switches that are on.
  #
  # @return [Array<Integer>] Their ids.
  def self.switches_on
    data = MGQ_MpStoryState.data_of($game_switches)
    (0...data.size).select { |id| data[id] }
  end

  # Starts a world entry's field event from its first command after a transfer onto the spot that
  # starts it, the tableau's hidden events letting the player through meanwhile; where the player
  # stands when no tile next to it is free.
  #
  # @param troop [Integer] The troop.
  # @param entry [Hash] The world entry.
  # @param event [Game_Event] The entry's event.
  # @param touch [Boolean] Whether a touch starts its page, else the action button.
  # @return [Boolean] Whether it started.
  def self.start_fresh_field(troop, entry, event, touch)
    before = snapshot(nil)
    through = hold_through(entry)
    spot = touch ? touch_spot(event) : front_spot(event)
    return start_fresh_in_place(troop, entry, event, through) unless spot

    $game_player.reserve_transfer(spot[0], spot[1], spot[2], spot[3])
    $game_temp.fade_type = 0
    @resume = { :troop => troop, :record => nil, :fresh => true, :stage => :transfer, :target => spot[0], :site => entry["outer"], :snapshot => before,
                :through => through }
    log("starts #{entry['outer']} from its first command for the fight against troop #{troop}: the player has no record of their own " \
        "and goes onto #{spot[1]},#{spot[2]} facing #{spot[3]} first")
    true
  end

  # Starts a world entry's field event from its first command where the player stands.
  #
  # @param troop [Integer] The troop.
  # @param entry [Hash] The world entry.
  # @param event [Game_Event] The entry's event, showing the entry's page.
  # @param through [Hash, nil] The hidden events let through, see hold_through.
  # @return [Boolean] true.
  def self.start_fresh_in_place(troop, entry, event, through)
    @resume = { :troop => troop, :record => nil, :fresh => true, :stage => :event, :through => through }
    as_story { $game_map.interpreter.setup(event.mgq_mp_pages[event.mgq_mp_page].list, event.id) }
    log("starts #{entry['outer']} from its first command for the fight against troop #{troop}: the player has no record of their own")
    true
  end

  # Finds the spot a touch starts an event from: its own tile and direction.
  #
  # @param event [Game_Event] The event.
  # @return [Array(Integer, Integer, Integer, Integer)] Map, x, y and direction.
  def self.touch_spot(event)
    log("the touch of event #{event.id} starts it on its own tile #{event.x},#{event.y}")
    [$game_map.map_id, event.x, event.y, event.direction]
  end

  # Finds the spot the action button starts an event from: the free tile in front of it, else a
  # free neighbour of it nearest the player, facing it.
  #
  # @param event [Game_Event] The event.
  # @return [Array(Integer, Integer, Integer, Integer), nil] Map, x, y and direction; nil when no
  #   neighbour is free.
  def self.front_spot(event)
    map = $game_map.map_id
    front = NEIGHBOUR_DIRECTIONS.include?(event.direction) ? event.direction : 2
    others = (NEIGHBOUR_DIRECTIONS - [front]).sort_by do |direction|
      x, y = neighbour(event, direction)
      [[(x - $game_player.x).abs, (y - $game_player.y).abs].max, NEIGHBOUR_DIRECTIONS.index(direction)]
    end
    ([front] + others).each do |direction|
      x, y = neighbour(event, direction)
      next unless free_tile?(x, y)

      where = direction == front ? "the tile in front of it" : "its free neighbour, the tile in front of it (facing #{front}) not being free"
      log("the action button starts event #{event.id} from #{where}: #{x},#{y}")
      return [map, x, y, 10 - direction]
    end
    log("no tile around event #{event.id} at #{event.x},#{event.y} is free: it starts where the player stands")
    nil
  rescue => e
    log("finding the tile that starts event #{event.id} failed: #{e.class}: #{e.message}: it starts where the player stands")
    nil
  end

  # Finds the tile next to an event in a direction.
  #
  # @param event [Game_Event] The event.
  # @param direction [Integer] The direction.
  # @return [Array(Integer, Integer)] Its x and y.
  def self.neighbour(event, direction)
    [$game_map.round_x_with_direction(event.x, direction), $game_map.round_y_with_direction(event.y, direction)]
  end

  # Reports whether the player may stand on a tile: on the map, passable and free of every event that
  # blocks.
  #
  # @param x [Integer] The tile's x.
  # @param y [Integer] The tile's y.
  # @return [Boolean] Whether they may.
  def self.free_tile?(x, y)
    return false unless $game_map.valid?(x, y) && NEIGHBOUR_DIRECTIONS.any? { |direction| $game_map.passable?(x, y, direction) }

    $game_map.events_xy_nt(x, y).none? { |other| other.normal_priority? }
  end

  # Lets the live events a world entry's tableau hides on the map pass through, so none blocks the
  # player during the fresh start's run, see keep_through.
  #
  # @param entry [Hash] The world entry.
  # @return [Hash, nil] The map's events, the events and their own values by id; nil for none.
  def self.hold_through(entry)
    tableau = entry["tableau"]
    return nil unless tableau.is_a?(Array) && tableau[0].to_i == $game_map.map_id && tableau[1].is_a?(Array)

    ids = tableau[1].select { |row| row.is_a?(Array) && row[12].to_i == 1 && row[0].to_i > 0 }.map { |row| row[0].to_i }.uniq.sort
    ids &= $game_map.events.keys
    return nil if ids.empty?

    held = { :events => $game_map.events, :ids => ids, :was => {} }
    keep_through(held)
    log("lets the hidden events #{ids.inspect} of the frozen fight pass through while its fresh start runs")
    held
  end

  # Keeps the held events passing through, each frame, since a page the run turns them to brings its
  # own setting; notes each one's own value of the page it shows.
  #
  # @param held [Hash, nil] The held events, see hold_through.
  def self.keep_through(held)
    return unless held && $game_map.events.equal?(held[:events])

    held[:ids].each do |id|
      event = $game_map.events[id]
      next unless event

      page = event.mgq_mp_page
      was = held[:was][id]
      held[:was][id] = [page, event.through ? true : false] unless was && was[0] == page
      MGQ_MpGame.set(event, :through, true)
    end
  end

  # Puts back the own values of the events a fresh start let through, on the pages they noted them
  # for; the events of a map set up anew have their own already.
  #
  # @param resume [Hash] The resume.
  def self.release_through(resume)
    held = resume[:through]
    return unless held

    resume[:through] = nil
    return log("the events let through for troop #{resume[:troop]} went with their map: those of the map now are its own") unless $game_map.events.equal?(held[:events])

    held[:was].each do |id, (page, through)|
      event = $game_map.events[id]
      MGQ_MpGame.set(event, :through, through) if event && event.mgq_mp_page == page
    end
    log("events #{held[:ids].inspect} pass through as their pages say again: the fresh start of troop #{resume[:troop]} ended")
  end

  # Reads whether an event passes through by its own setting, which a fresh start's hold hides, so a
  # record never keeps the hold.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it does.
  def self.own_through(event)
    held = @resume ? @resume[:through] : nil
    was = held && $game_map.events.equal?(held[:events]) ? held[:was][event.id] : nil
    return was[1] if was && was[0] == event.mgq_mp_page

    event.through ? true : false
  end

  # Starts a world entry's cutscene from its first command, the cutscene of the player's side the DLL
  # picked, after a transfer onto the spot the story enters it at, once its event would show its page.
  #
  # @param troop [Integer] The troop.
  # @param plan [Hash] The DLL's plan: "site" and "spot", see start_fresh.
  # @return [Boolean] Whether it started.
  def self.start_fresh_scene(troop, plan)
    site = plan["site"]
    map, event_id, page = site_parts(site)
    shown = probe_page(map, event_id)
    return refuse(troop, "Cannot fight #{label(troop)} here yet.", "#{site.inspect} is not the page the event would show (#{shown.inspect})") unless shown == page - 1

    spot = plan["spot"]
    before = snapshot(nil)
    $game_player.reserve_transfer(spot[0], spot[1], spot[2], spot[3])
    $game_temp.fade_type = 0
    @resume = { :troop => troop, :record => nil, :fresh => true, :stage => :transfer, :target => spot[0], :site => site, :snapshot => before }
    log("starts #{site.inspect} from its first command for the fight against troop #{troop}: to map #{spot[0]} at #{spot[1]},#{spot[2]}")
    true
  end

  # Finds the page an event of another map would show with the player's story.
  #
  # @param map [Integer] The map.
  # @param event_id [Integer] The event.
  # @return [Integer, nil] The page's index, nil for an event the map lacks.
  def self.probe_page(map, event_id)
    data = load_data(DataManager.map_file_name(map))
    event = data.events[event_id]
    event ? Game_Event.new(map, event).mgq_mp_page : nil
  end

  # Follows the map each frame: puts a defeat's changes back once it ended, ends a resume whose event
  # stopped, brings a player back from a resume given up, brings a joiner onto the starter's spot
  # and forgets records of beaten bosses. Called after Scene_Map#update.
  def self.on_map
    return unless SceneManager.scene.is_a?(Scene_Map)

    undo_due if @pending
    follow_resume if @resume
    return_player if @return_to
    teleport_joiner if @teleport
    drop_beaten
  rescue => e
    log_once(:on_map, "following the map failed: #{e.class}: #{e.message}")
  end

  # Puts back what a lost battle's defeat changed once its chain ended: the map is the scene, no
  # event runs, no transfer waits and no message shows.
  def self.undo_due
    pending = @pending
    return if MGQ_Multiplayer::Bridge.frame_number == pending[:at]
    return if $game_map.interpreter.running? || $game_player.transfer? || $game_message.busy?

    @pending = nil
    undo(pending)
  end

  # Puts back what a defeat changed of the story: each value that changed since the defeat started
  # goes back to the value the DLL names (FreezeRules.Undo: none for the post-defeat processing's
  # own and the player's own, the event's start for a key the event changed before the battle, else
  # the defeat's start); and the items it names. A fight with a record then waits.
  #
  # @param pending [Hash] The defeat's snapshot.
  def self.undo(pending)
    rows = changed_since(pending[:mark])
    return lost_undo(pending) unless rows

    starts = {}
    Array(pending[:start]).each { |kind, key, value| starts[[kind, key]] = value }
    asked = rows.map { |kind, key, _was, _now| [kind, kind == 2 ? 0 : key, personal?(kind, key), starts.key?([kind, key])] }
    answer = undo_answer(asked, pending[:items])
    choices = Array(answer["values"])
    undone = []
    texts = []
    rows.each_with_index do |(kind, key, was, now), index|
      choice = choices[index]
      next unless choice

      value = choice == "start" ? starts[[kind, key]] : was
      write_value(kind, key, value)
      undone << [kind, key, value] if core?(key) && core?(value)
      texts << "#{value_name(kind, key)} #{value_text(now)} -> #{value_text(value)}"
    end
    $game_map.need_refresh = true
    texts.concat(give_items_back(answer["items"]))
    log("the defeat by troop #{pending[:troop]} ended: put back #{texts.empty? ? 'nothing' : texts.join(', ')}")
    record = record_for(pending[:troop])
    freeze(record, undone) if record && record["state"] == "lost"
  end

  # Asks the DLL which value each changed key goes back to and which items come back, from the
  # counts at the defeat's start and now.
  #
  # @param rows [Array<Array>] Each changed key: kind, id (0 for a self switch), whether it is the
  #   player's own and whether the event changed it before the battle.
  # @param before [Hash{Array => Integer}] The counts at the defeat's start, see item_counts.
  # @return [Hash] "values" (per row "start", "was" or nil) and "items" ([letter, id, change] each).
  def self.undo_answer(rows, before)
    counts = lambda { |found| found.map { |(letter, id), count| [letter, id, count] } }
    answer = MGQ_Multiplayer::Bridge.call(UNDO_TOPIC, "rows" => rows, "items" => { "before" => counts.call(before), "after" => counts.call(item_counts) })
    answer.is_a?(Hash) ? answer : {}
  end

  # Gives the items the DLL names back.
  #
  # @param items [Array<Array>, nil] Each item's letter, id and how many, see undo_answer.
  # @return [Array<String>] What changed, for the log.
  def self.give_items_back(items)
    Array(items).map do |letter, id, change|
      item = MGQ_MpGame.item(letter, id)
      next unless item

      $game_party.gain_item(item, change)
      "#{{ 'i' => 'item', 'w' => 'weapon', 'a' => 'armor' }[letter]} #{id} #{change > 0 ? '+' : ''}#{change}"
    end.compact
  end

  # Freezes a lost fight: its record waits, and the world hears of it.
  #
  # @param record [Hash] The record.
  # @param undone [Array<Array>] The story values the undo wrote: [kind, key, value].
  def self.freeze(record, undone)
    record["state"] = "frozen"
    record["undone"] = undone
    (@shared ||= {})[record["troop"]] = true
    noted = defined?(MGQ_MpWorldFreeze) && MGQ_MpWorldFreeze.respond_to?(:note) ? MGQ_MpWorldFreeze.note(entry_of(record)) : false
    log("the fight against #{record['boss']} (troop #{record['troop']}) waits frozen#{noted ? ', told to the world' : ', the world was not told'}")
  end

  # Ends a resume once the event it started stopped, or gives it up when its transfer never came.
  def self.follow_resume
    resume = @resume
    keep_through(resume[:through])
    if resume[:stage] == :transfer || resume[:stage] == :arrived
      return if $game_player.transfer?

      return fail_resume(resume, "the transfer to map #{resume[:target]} did not bring the player there")
    end
    return if $game_map.interpreter.running?

    @resume = nil
    return fail_resume(resume, "the event stopped before its battle") unless resume[:battled]

    release_through(resume)

    record = record_for(resume[:troop])
    log("the resumed fight against troop #{resume[:troop]} ended#{record ? ", its record #{record['state']}" : ', its record gone'}")
  end

  # Brings a player who won a joined or side battle onto the spot its end chose, see battle_ended,
  # when they are on its map.
  def self.teleport_joiner
    return unless map_free?

    teleport = @teleport
    @teleport = nil
    spot = teleport[:spot]
    return log("did not bring the player onto the starter's spot of troop #{teleport[:troop]}: map #{$game_map.map_id}, not #{spot[0]}") unless $game_map.map_id == spot[0]

    $game_player.reserve_transfer(spot[0], spot[1], spot[2], spot[3])
    $game_temp.fade_type = 2
    log("brought the player onto the starter's spot of troop #{teleport[:troop]}: #{spot[1]},#{spot[2]}")
  end

  # Forgets the records of fights that are over, as the DLL tells (see checked), and tells the world
  # of frozen fights it lacks, every CHECK_FRAMES.
  def self.drop_beaten
    now = MGQ_Multiplayer::Bridge.frame_number
    return if @checked_at && now - @checked_at < CHECK_FRAMES

    @checked_at = now
    notes = field
    return unless notes

    Array(checked(notes)["dropped"]).each do |troop, reason|
      next unless notes["records"].delete(troop)

      log("dropped the record of troop #{troop}: #{reason}")
    end
    share_records
  end

  # Tells the world once per session of each frozen fight of the save its list lacks.
  #
  # The world's list starts empty at the title, so a fight frozen before a load would hold nothing
  # until a story the world kept carried it, and a write never carried it if none was sent.
  def self.share_records
    return unless defined?(MGQ_MpWorldFreeze) && MGQ_MpWorldFreeze.respond_to?(:note)

    @shared ||= {}
    records.each do |record|
      troop = record["troop"]
      next if @shared[troop] || world_entry(troop)

      @shared[troop] = true
      noted = MGQ_MpWorldFreeze.note(entry_of(record))
      log("told the world of the frozen fight against #{record['boss']} (troop #{troop}) the save keeps: #{noted ? 'its list holds it' : 'it was refused'}")
    end
  end

  # Forgets the run, the stack, the pending snapshot, the battle and the resume as a save loads; the
  # game's retry of a lost battle keeps the run and the battle, so its loss puts back as the first
  # one's would. Called after DataManager.extract_save_contents.
  def self.loaded
    @stack = []
    if @retrying
      log("the game's retry ran: the lost battle's defeat puts nothing back") if @pending
      @pending = nil
      return
    end

    log("a save was loaded: forgot the battle, the defeat under way and the resume") if @battle || @pending || @resume
    release_through(@resume) if @resume
    @run = nil
    @at_301 = nil
    @battle = nil
    @pending = nil
    @resume = nil
    @teleport = nil
    @return_to = nil
  end

  # Puts the party's temporary members and split parties back as they were at the battle.
  #
  # @param text [String, nil] The dump of the record.
  def self.restore_party(text)
    return log("the record keeps no party: it stays as it is") unless text

    temp, flag, multi = Marshal.load(text)
    MGQ_MpGame.set($game_party, :temp_actors, temp)
    MGQ_MpGame.set($game_party, :multi_party_flag, flag)
    MGQ_MpGame.set($game_party, :multi_party, multi)
    $game_player.refresh if $game_player.respond_to?(:refresh)
    $game_map.need_refresh = true
    log("put the party's temporary members back#{flag ? ' and its split parties' : ''}")
  rescue => e
    log("putting the party back failed: #{e.class}: #{e.message}")
  end

  # Puts the map's events back as they showed and moved at the battle.
  #
  # @param rows [Array<Array>] The rows, see event_rows.
  def self.restore_events(rows)
    Array(rows).each do |id, x, y, direction, pattern, name, index, tile, opacity, blend, transparent, through, erased, priority, fix, walk, step, speed|
      event = $game_map.events[id]
      next unless event

      if erased
        event.erase
      elsif MGQ_MpGame.get(event, :erased)
        MGQ_MpGame.set(event, :erased, false)
        event.refresh
      end
      event.moveto(x, y)
      MGQ_MpGame.set(event, :direction_fix, false)
      event.set_direction(direction)
      event.set_graphic(name, index)
      MGQ_MpGame.set(event, :tile_id, tile)
      MGQ_MpGame.set(event, :pattern, pattern)
      MGQ_MpGame.set(event, :original_pattern, pattern)
      MGQ_MpGame.set(event, :opacity, opacity)
      MGQ_MpGame.set(event, :blend_type, blend)
      event.transparent = transparent
      MGQ_MpGame.set(event, :through, through)
      MGQ_MpGame.set(event, :priority_type, priority)
      MGQ_MpGame.set(event, :direction_fix, fix)
      MGQ_MpGame.set(event, :walk_anime, walk)
      MGQ_MpGame.set(event, :step_anime, step)
      MGQ_MpGame.set(event, :move_speed, speed)
    end
  end

  # Puts the player, the followers and the camera back as at the battle; the transfer put the player
  # on the spot.
  #
  # @param record [Hash] The record.
  def self.restore_player(record)
    _map, _x, _y, _direction, transparent, through, speed = record["player"]
    player = $game_player
    player.transparent = transparent
    MGQ_MpGame.set(player, :through, through)
    MGQ_MpGame.set(player, :move_speed, speed)
    visible, places = record["followers"]
    followers = []
    player.followers.each { |follower| followers << follower }
    player.followers.visible = visible
    Array(places).each_with_index do |(x, y, direction), index|
      next unless followers[index]

      followers[index].moveto(x, y)
      followers[index].set_direction(direction)
    end
    $game_map.set_display_pos(*record["camera"]) if record["camera"]
  end

  # Gets the player off the vehicle they drove to a resume, which goes back to where they pressed.
  #
  # The resume runs the event on from right before its battle command, past the commands that got
  # the player off and parked the vehicle on the way there.
  #
  # @param resume [Hash] The resume.
  def self.leave_vehicle(resume)
    type = MGQ_MpGame.get($game_player, :vehicle_type)
    return if type.nil? || type.to_sym == :walk

    $game_player.forced_get_off_vehicle
    place_vehicles(resume[:snapshot]["vehicles"]) if resume[:snapshot]
    log("got the player off the #{type} for the resume of troop #{resume[:troop]}, the #{type} back where they pressed")
  end

  # Puts vehicles back where a record or snapshot has them.
  #
  # @param rows [Array<Array>, nil] The vehicles, see vehicles_row; nil for a record taken before
  #   vehicles were recorded.
  # @param map [Integer, nil] Only those that stood on this map; nil for all.
  def self.place_vehicles(rows, map = nil)
    Array(rows).each do |type, map_id, x, y, direction|
      vehicle = $game_map.vehicle(type.to_s.to_sym)
      next unless vehicle && (map.nil? || map_id == map)

      vehicle.set_location(map_id, x, y)
      vehicle.set_direction(direction)
    end
  end

  # Puts the player back on the vehicle they drove as they pressed, see leave_vehicle, without
  # starting its music anew.
  #
  # @param type [String, nil] The vehicle, see player_row: "walk" or nil for none.
  def self.board(type)
    vehicle = $game_map.vehicle(type.to_s.to_sym)
    return unless vehicle && MGQ_MpGame.get($game_player, :vehicle_type).to_s == "walk"

    MGQ_MpGame.set($game_player, :vehicle_type, type.to_sym)
    MGQ_MpGame.set(vehicle, :driving, true)
    vehicle.refresh
    log("put the player back on the #{type}")
  end

  # Puts the screen back as at the battle as part of the player's own scene, which began as the
  # resume did, before its party and its player were put back: the one guard of the game's flow
  # puts back what the resume put back once the mod moves the player away from it, as the scene's
  # own end would (see MGQ_MpFlowGuard.resuming).
  #
  # @param text [String, nil] The dump of the record.
  # @param before [Hash, nil] The state of the game's flow as the resume began, see
  #   MGQ_MpFlowGuard.state_now.
  def self.resume_screen(text, before = nil)
    return restore_screen(text) unless defined?(MGQ_MpFlowGuard)

    MGQ_MpFlowGuard.resuming(before) { restore_screen(text) }
  end

  # Puts the screen back as at the battle: tone, weather, flashes and pictures, copied into the live
  # objects field by field, whatever fields the game's plugins added.
  #
  # The map's sprites hold the live screen and pictures, so a loaded copy that replaced them would
  # show nothing.
  #
  # @param text [String, nil] The dump of the record.
  def self.restore_screen(text)
    return unless text

    saved = Marshal.load(text)
    live = $game_map.screen
    saved.instance_variables.each { |name| live.instance_variable_set(name, saved.instance_variable_get(name)) unless name == :@pictures }
    saved_pictures = MGQ_MpGame.get(saved.pictures, :data) || []
    live_pictures = MGQ_MpGame.get(live.pictures, :data) || []
    [saved_pictures.size, live_pictures.size].max.times do |number|
      picture = saved_pictures[number]
      if picture
        target = live.pictures[number]
        picture.instance_variables.each { |name| target.instance_variable_set(name, picture.instance_variable_get(name)) }
      elsif live_pictures[number]
        live_pictures[number].erase
      end
    end
  rescue => e
    log("putting the screen back failed: #{e.class}: #{e.message}")
  end

  # Puts the map's tileset, parallax and battle backs back as at the battle.
  #
  # @param row [Array, nil] The record's row, see look_row.
  def self.restore_look(row)
    return unless row

    tileset, name, loop_x, loop_y, sx, sy, back1, back2 = row
    map = $game_map
    map.change_tileset(tileset) if tileset && tileset != MGQ_MpGame.get(map, :tileset_id)
    map.change_parallax(name, loop_x, loop_y, sx, sy)
    map.change_battleback(back1, back2)
  rescue => e
    log("putting the map's look back failed: #{e.class}: #{e.message}")
  end

  # Plays the music and sounds of the battle's moment again and puts its battle music back.
  #
  # @param row [Array, nil] The record's row, see audio_row.
  def self.restore_audio(row)
    return unless row

    bgm, bgs, battle = row
    bgm[0].to_s.empty? ? RPG::BGM.stop : RPG::BGM.new(bgm[0], bgm[1], bgm[2]).play(bgm[3])
    bgs[0].to_s.empty? ? RPG::BGS.stop : RPG::BGS.new(bgs[0], bgs[1], bgs[2]).play(bgs[3])
    $game_system.battle_bgm = RPG::BGM.new(battle[0], battle[1], battle[2]) unless battle[0].to_s.empty?
  rescue => e
    log("putting the music back failed: #{e.class}: #{e.message}")
  end

  # Keeps every event of the map from starting by itself as the resume starts its own.
  def self.clear_starts
    $game_map.events.each_value { |event| event.clear_starting_flag if event.starting }
  end

  # Writes story values, past the game's own handling.
  #
  # @param values [Array<Array>] Each [kind, key, value].
  def self.write_values(values)
    Array(values).each { |kind, key, value| write_value(kind, key, value) }
    $game_map.need_refresh = true
  end

  # Writes one story value into the game, past its own handling.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @param value [Object] Its value.
  def self.write_value(kind, key, value)
    put_value([MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables), MGQ_MpStoryState.data_of($game_self_switches)],
              kind, key, value)
  end

  # Writes one value into a story's switches, variables or self switches.
  #
  # @param story [Array] The story, see MGQ_MpStoryState.raw_state, changed in place.
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @param value [Object] Its value.
  def self.put_value(story, kind, key, value)
    if kind == 2 && value.nil?
      story[2].delete(key)
    else
      story[kind][key] = value
    end
  end

  # Notes a write of the game's switches, variables or self switches into the journal with the
  # key's value before it, while a mark lives: a run's (see note_run) or a defeat's (see
  # defeated). Called before Game_Switches#[]=, Game_Variables#[]= and Game_SelfSwitches#[]=.
  #
  # @param object [Game_Switches, Game_Variables, Game_SelfSwitches] What is written to.
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
  def self.writing(object, kind, key)
    return unless @unjournaled == 0 && ((@run && @run[:mark]) || (@pending && @pending[:mark]))
    return unless object.equal?(kind == 0 ? $game_switches : kind == 1 ? $game_variables : $game_self_switches)

    hand_journal if @journal.size >= MAX_PENDING && @refusals == 0
    trim_journal(MAX_HELD - 1)
    @seq += 1
    @journal << [@seq, kind, kind == 2 ? key.dup : key, plain_value(@seq, MGQ_MpStoryState.data_of(object)[key])]
  rescue => e
    log_once([:writing, e.class], "noting a write in the journal failed: #{e.class}: #{e.message}")
  end

  # Runs a block whose writes the journal leaves out: the world's story the relay handed
  # (world_story.rbx), which is the world's and never an event's or a defeat's to put back.
  #
  # @yieldreturn [Object] What the block returns.
  # @return [Object] What the block returned.
  def self.unjournaled
    @unjournaled += 1
    yield
  ensure
    @unjournaled -= 1
  end

  # Hands the writes noted to the DLL's journal with the oldest live mark, which drops the writes no
  # mark needs, every one once no mark lives. Called before every frame's Graphics.update and before
  # the journal is asked. Writes the DLL refuses stay for the next hand-over (see held_back), which
  # the frames wait for unless the journal is asked.
  #
  # @param asked [Integer, nil] A mark about to be asked, which stays though its run or defeat just
  #   ended.
  # @return [Boolean] Whether the DLL holds every write noted.
  def self.hand_journal(asked = nil)
    keep = [@run && @run[:mark], @pending && @pending[:mark], asked].compact.min
    return true if @journal.empty? && keep == @kept
    return false if asked.nil? && @refusals > 0 && MGQ_Multiplayer::Bridge.frame_number < @retry_at

    MGQ_Multiplayer::Bridge.call!(JOURNAL_TOPIC, "entries" => @journal, "keep" => keep)
    log("the DLL took the journal's #{@journal.size} write(s) after #{@refusals} refusal(s)") if @refusals > 0
    @journal = []
    @kept = keep
    drop_objects(keep)
    @refusals = 0
    true
  rescue => e
    held_back(keep, e)
    false
  end

  # Keeps the writes the DLL refused for the next hand-over, but those no live mark needs, and at
  # most MAX_HELD (see trim_journal), and sets when the frames try again (see RETRY_FRAMES). Logs
  # the first refusal in a row.
  #
  # @param keep [Integer, nil] The oldest live mark, nil for none.
  # @param error [Exception] Why the hand-over failed.
  def self.held_back(keep, error)
    @journal.reject! { |entry| keep.nil? || entry[0] <= keep }
    drop_objects(keep)
    trim_journal(MAX_HELD)
    @refusals += 1
    @retry_at = MGQ_Multiplayer::Bridge.frame_number + [RETRY_FRAMES << [@refusals - 1, 5].min, RETRY_MOST_FRAMES].min
    return unless @refusals == 1

    log("the DLL refused the journal's writes #{@refusals} time(s) in a row (#{error.class}: #{error.message}): " \
        "#{@journal.size} write(s) wait to go again#{@lost_through > 0 ? ", every write up to #{@lost_through} is lost" : ''}")
  end

  # Drops the oldest writes the scripts hold beyond a number, which a mark before them then lacks.
  #
  # @param most [Integer] The number.
  def self.trim_journal(most)
    return if @journal.size <= most

    dropped = @journal.slice!(0, @journal.size - most)
    @lost_through = [@lost_through, dropped.last[0]].max
  end

  # Lists the story values that changed since a mark, as the old whole-story diff did: each key
  # written since, with its value at the mark (or the start value that stands for it), the value
  # now, the same ones left out (MGQ_MpWorldStory.same?), switches and variables by id, self
  # switches in the order the game's own Hash holds them.
  #
  # @param mark [Integer] The mark.
  # @param starts [Array<Array>, nil] Values that stand for the story at the mark, each [kind, key,
  #   value], as a resume's record keeps them; nil for none.
  # @return [Array<Array>, nil] Each [kind, key, value at the mark, value now]; nil when the journal
  #   lost the mark, or the DLL lacks writes since it.
  def self.changed_since(mark, starts = nil)
    return nil unless hand_journal(mark) && mark >= @lost_through

    answer = MGQ_Multiplayer::Bridge.call(SINCE_TOPIC, mark)
    return nil if answer.nil? || answer["overflow"]

    befores = {}
    answer["rows"].each { |kind, key, before| befores[[kind, key]] = value_of(before) }
    Array(starts).each { |kind, key, value| befores[[kind, key]] = value }
    order = {}
    MGQ_MpStoryState.data_of($game_self_switches).each_key { |key| order[key] = order.size }
    rows = befores.map { |(kind, key), before| [kind, key, before, read_value(kind, key)] }
    rows.reject! { |kind, _key, before, now| MGQ_MpWorldStory.same?(kind, before, now) }
    rows.each_with_index.sort_by { |(kind, key, _, _), at| [kind, kind == 2 ? order.fetch(key, order.size + at) : key, at] }.map(&:first)
  end

  # Turns a value written over into what the journal carries: nil and the values the story carries
  # (MGQ_MpStoryState.plain_variable) as the bridge takes them; any other value stays here as a copy
  # in @objects, the journal naming it by its write's number.
  #
  # @param seq [Integer] The write's number.
  # @param value [Object] The value.
  # @return [Object] The plain value.
  def self.plain_value(seq, value)
    return nil if value.nil?

    plain = MGQ_MpStoryState.plain_variable(value)
    return plain unless plain.nil?

    @objects[seq] = (value.dup rescue value)
    { "object" => seq }
  end

  # Reads a value written over back from the journal, see plain_value.
  #
  # @param value [Object] The plain value.
  # @return [Object] The value; a new Object, equal to nothing, for a copy dropped since.
  def self.value_of(value)
    return value unless value.is_a?(Hash)
    return @objects.fetch(value["object"]) { Object.new } if value.key?("object")

    MGQ_MpStoryState.variable_value(value)
  end

  # Drops the copies of values written over whose writes the DLL drops: those no live mark needs.
  #
  # @param keep [Integer, nil] The oldest live mark, nil for none.
  def self.drop_objects(keep)
    @objects.reject! { |seq, _| keep.nil? || seq <= keep }
  end

  # Gives back the items whose count a defeat changed when the journal lost the defeat's start, so
  # nothing of the story goes back, and drops the fight's record, which then cannot wait.
  #
  # @param pending [Hash] The defeat's snapshot.
  def self.lost_undo(pending)
    texts = give_items_back(undo_answer([], pending[:items])["items"])
    record = record_for(pending[:troop])
    field["records"].delete(pending[:troop]) if record && record["state"] == "lost"
    log("the defeat by troop #{pending[:troop]} ended, but the journal lost the story at its start: put back nothing of the story" \
        "#{texts.empty? ? '' : ", #{texts.join(', ')}"}#{record && record['state'] == 'lost' ? '; its record goes' : ''}")
  end

  # Reports whether a story value is the player's own, see MGQ_MpWorldStory.personal?.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Boolean] Whether it is.
  def self.personal?(kind, key)
    MGQ_MpWorldStory.personal?(kind, key) ? true : false
  rescue
    false
  end

  # Reports whether a value is one the save field keeps: core types only, so another game reads it
  # without loading the mod's or the game's classes.
  #
  # @param value [Object] The value.
  # @return [Boolean] Whether it is.
  def self.core?(value)
    case value
    when nil, true, false, Integer, Float, String then true
    when Array then value.all? { |item| core?(item) }
    when Hash then value.all? { |key, item| core?(key) && core?(item) }
    else false
    end
  end

  # Names a story value for the log, such as "v1075".
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [String] The name.
  def self.value_name(kind, key)
    "#{KIND_LETTERS[kind]}#{key.is_a?(Array) ? key.join('.') : key}"
  end

  # Writes a story value for the log.
  #
  # @param value [Object] The value.
  # @return [String] Such as "on", "off" or "12".
  def self.value_text(value)
    return "on" if value == true
    return "off" if value == false || value.nil?

    value.inspect
  end

  # Splits a map page's site key.
  #
  # @param key [Array] Such as ["map", 138, 13, 1].
  # @return [Array(Integer, Integer, Integer), Array] The map, event and page; empty for another key.
  def self.site_parts(key)
    key.is_a?(Array) && key.size == 4 && key[0] == "map" ? key[1, 3] : []
  end

  # Finds the page of a map page's site key.
  #
  # @param key [Array] The key.
  # @return [Integer, nil] The page, 1-based; nil for another key.
  def self.page_number(key)
    site_parts(key)[2]
  end

  # Reports whether a map is a cutscene map, see the freeze's SCENE_MAPS.
  #
  # @param map [Integer] The map.
  # @return [Boolean] Whether it is.
  def self.scene_map?(map)
    data(:SCENE_MAPS, []).include?(map)
  end

  # Reads a table of the freeze's data, see tables.
  #
  # @param name [Symbol] The table: :SITES, :SCENES or :SCENE_MAPS.
  # @param default [Object] What stands in while the data is missing.
  # @return [Object] The table.
  def self.data(name, default)
    found = tables[name]
    found.nil? ? default : found
  end

  # Reads the freeze's tables from the DLL's events database once per session, for every raid boss
  # troop: where the story fights each one (SITES: site key, the battle command's index, its indent,
  # where its preamble starts, whether its map is a cutscene map, and its battle number), how the
  # story enters the fights on cutscene maps (SCENES) and the cutscene maps (SCENE_MAPS). A table
  # the database does not tell is left out; while the DLL gives no answer, it is asked again every
  # TABLES_FRAMES.
  #
  # @return [Hash{Symbol => Object}] The tables.
  def self.tables
    return @tables if @tables
    return {} if @tables_failed_at && MGQ_Multiplayer::Bridge.frame_number - @tables_failed_at < TABLES_FRAMES

    MGQ_MpCoopEvents.open_events if MGQ_MpCoopEvents.respond_to?(:open_events)
    answer = MGQ_Multiplayer::Bridge.call(SITES_TOPIC, "troops" => raid_troops)
    unless answer.is_a?(Hash)
      @tables_failed_at = MGQ_Multiplayer::Bridge.frame_number
      log_once(:no_tables, "the DLL told no sites of the story's raid boss fights: no fight freezes until it does")
      return {}
    end

    @tables = tables_of(answer)
    log(@tables[:SITES] ? "the DLL's events database names #{@tables[:SITES].size} raid boss troop(s) whose story fights freeze" : "the DLL's events database names no sites of the story's raid boss fights: no fight freezes")
    @tables
  end

  # Lists the troops of the raid bosses, the story's and the optional ones.
  #
  # @return [Array<Integer>] The troops, in order.
  def self.raid_troops
    return [] unless defined?(MGQ_MpRaidBosses)

    MGQ_MpRaidBosses.troops.sort
  end

  # Reads the freeze's tables from the DLL's answer, see tables.
  #
  # @param answer [Hash] The answer of SITES_TOPIC.
  # @return [Hash{Symbol => Object}] The tables the answer holds rows of.
  def self.tables_of(answer)
    found = {
      :SITES => answer["sites"], :SCENES => answer["scenes"].is_a?(Array) ? Hash[answer["scenes"]] : nil, :SCENE_MAPS => answer["scene_maps"],
    }
    found.reject { |_name, table| !(table.is_a?(Hash) || table.is_a?(Array)) || table.empty? }
  end

  # Finds the world's entry of a troop's fight, see MGQ_MpWorldFreeze.entry.
  #
  # @param troop [Integer] The troop.
  # @return [Hash, nil] The entry, nil for none.
  def self.world_entry(troop)
    defined?(MGQ_MpWorldFreeze) && MGQ_MpWorldFreeze.respond_to?(:entry) ? MGQ_MpWorldFreeze.entry(troop) : nil
  end

  # Reports whether the player plays a Raid World's story, see MGQ_MpRaidPool.active?.
  #
  # @return [Boolean] Whether they do.
  def self.active?
    MGQ_MpRaidPool.active? ? true : false
  rescue
    false
  end

  # Reports whether the player is free on the map, see MGQ_MpOverworldSync.map_free?.
  #
  # @return [Boolean] Whether they are.
  def self.map_free?
    defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.respond_to?(:map_free?) ? MGQ_MpOverworldSync.map_free? : false
  end

  # Names another player who tells the story the player shares, see MGQ_MpCoop::Scope.teller.
  #
  # @return [String, nil] The name, nil when nobody else does.
  def self.teller_name
    return nil unless defined?(MGQ_MpCoop::Scope) && defined?(MGQ_MpOverworldSync::Peers::Peer)

    teller = MGQ_MpCoop::Scope.teller
    teller.is_a?(MGQ_MpOverworldSync::Peers::Peer) ? (teller.state["name"].to_s.empty? ? "Another player" : teller.state["name"].to_s) : nil
  end

  # Runs a block whose event coop_events.rbx counts as the story's, see MGQ_MpCoopEvents.as_story.
  #
  # @return [Object] What the block returns.
  def self.as_story(&block)
    defined?(MGQ_MpCoopEvents) && MGQ_MpCoopEvents.respond_to?(:as_story) ? MGQ_MpCoopEvents.as_story(&block) : yield
  end

  # Names a troop's boss as the player reads it, see MGQ_MpRaidPool.troop_label.
  #
  # @param troop [Integer, nil] The troop.
  # @return [String] The name.
  def self.label(troop)
    name = troop && MGQ_MpRaidPool.respond_to?(:troop_label) ? MGQ_MpRaidPool.troop_label(troop).to_s : ""
    name.empty? ? "the boss" : name
  rescue
    "the boss"
  end

  # Shows a message in the notification box.
  #
  # @param text [String] The message.
  def self.notice(text)
    MGQ_MpNotices.message(NOTICE_KEY, text, NOTICE_FRAMES) if defined?(MGQ_MpNotices)
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # After a list of commands is set up, the story at the map's event's start is noted, after
  # coop_events.rbx sorted the event.
  MGQ_MpHooks.after(Game_Interpreter, :setup, "battles_raid_freeze") { |*args| MGQ_MpRaidFreeze.note_run(self, args[0], args[1] || 0) }
  MGQ_MpHooks.around(Game_Interpreter, :command_117, "battles_raid_freeze") { |interpreter, _args, original| MGQ_MpRaidFreeze.call_common(interpreter, original) }
  MGQ_MpHooks.around(Game_Interpreter, :command_301, "battles_raid_freeze") { |interpreter, _args, original| MGQ_MpRaidFreeze.battle_command(interpreter, original) }
  # After MGQ_MpRaidPool.set_up, which registered first.
  MGQ_MpHooks.after(BattleManager.singleton_class, :setup, "battles_raid_freeze") { |troop_id, *_rest| MGQ_MpRaidFreeze.battle_set_up(troop_id) }
  MGQ_MpHooks.before(BattleManager.singleton_class, :process_defeat, "battles_raid_freeze") { MGQ_MpRaidFreeze.defeated }
  if BattleManager.respond_to?(:retry_battle)
    MGQ_MpHooks.around(BattleManager.singleton_class, :retry_battle, "battles_raid_freeze") { |_manager, _args, original| MGQ_MpRaidFreeze.retrying { original.call } }
  end
  MGQ_MpHooks.before(BattleManager.singleton_class, :battle_end, "battles_raid_freeze") { |result| MGQ_MpRaidFreeze.battle_ended(result) }
  MGQ_MpHooks.before(Game_Player, :perform_transfer, "battles_raid_freeze") { MGQ_MpRaidFreeze.leaving(self) }
  MGQ_MpHooks.before(Game_Map, :setup_starting_map_event, "battles_raid_freeze") { MGQ_MpRaidFreeze.hold_starts(self) }
  # After coop_gather.rbx's and world_story.rbx's, so the resume's event starts last.
  MGQ_MpHooks.after(Game_Player, :perform_transfer, "battles_raid_freeze") { MGQ_MpRaidFreeze.transferred }
  MGQ_MpHooks.after(Scene_Map, :update, "battles_raid_freeze") { MGQ_MpRaidFreeze.on_map }
  MGQ_MpHooks.before(Scene_Title, :start, "battles_raid_freeze") { MGQ_MpRaidFreeze.forget }
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "battles_raid_freeze") { |_contents| MGQ_MpRaidFreeze.loaded }
  # Every write of the game's story goes into the journal with the value it replaces, and the
  # frame's writes go to the DLL before the frame's batch of the bridge.
  MGQ_MpHooks.before(Game_Switches, :[]=, "battles_raid_freeze") { |id, _value| MGQ_MpRaidFreeze.writing(self, 0, id) }
  MGQ_MpHooks.before(Game_Variables, :[]=, "battles_raid_freeze") { |id, _value| MGQ_MpRaidFreeze.writing(self, 1, id) }
  MGQ_MpHooks.before(Game_SelfSwitches, :[]=, "battles_raid_freeze") { |key, _value| MGQ_MpRaidFreeze.writing(self, 2, key) }
  MGQ_MpHooks.before(Graphics.singleton_class, :update, "battles_raid_freeze") { MGQ_MpRaidFreeze.hand_journal }
rescue => e
  MGQ_MpRaidFreeze.log("hooks FAILED: #{e.class}: #{e.message}")
end
