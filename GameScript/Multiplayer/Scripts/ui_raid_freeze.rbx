#----------------------------------------------------------------
#  ui_raid_freeze.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Asked the DLL which frozen fight keeps an event from starting and whether the start resumes it
#                            - Listed the frozen fights with their bosses' tiles in place of picking the one within reach
#      Paulinchen  2026-11-06: Asked the freeze whether a page runs nothing, as the DLL tells it
#                            - Logged each kept start once, without the frame in its key, and compared the sources by their hash instead of a deep copy
#      Paulinchen  2026-11-05: Read whether the teller tells the story as true or false
#                            - Handed a frozen fight's event kept from starting to the one guard of the game's flow
#                            - Counted its scans and refusals by the bridge's frame
#      Paulinchen  2026-10-28: Read what a page writes from the DLL's command index and the post-defeat processing's writes from the freeze's tables
#      Paulinchen  2026-10-17: Created
#
#----------------------------------------------------------------

# The frozen fights of a Raid World's bosses on the map (see battles_raid_freeze.rbx): where a
# player lost to a raid boss, the scene stands as it stood at the battle command, drawn by stand-ins
# (Game_MpFreezeStandIn) from the player's own record or, for a player without one, from the
# world's entry (see world_freeze.rbx). The stand-ins are sprites alone: no event of the map, nothing
# in the save, made anew on every map and after every load. A tableau holds only the boss and the
# characters the fight's scene brought out, so the map's own people stay live. The live events a
# stand-in stands for hide meanwhile, the boss's always, any other only while its page runs
# nothing, so a shop or a villager to talk to never hides; and neither the frozen event nor an
# event whose page writes a story value the fight holds can start, as the DLL tells (topic
# freeze.blocker). The stand-ins step aside while
# the scene plays live: another player tells the story on the map, or an event the fight blocks
# runs. The action button facing the boss's stand-in, or the Join Battle hotkey near it (see
# battles_coop_join.rbx), resumes the fight, whose HP bar ui_raid_bar.rbx draws above the stand-in;
# so does the player pressing or touching an event of the fight's own, such as the field event that
# leads into its cutscene or another caller of its common event.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpRaidFreezeUi
  # Frames between two looks at the frozen fights the player's record and the world keep.
  SCAN_FRAMES = 30

  # Most stand-ins one frozen fight shows, as the world's entries carry at most.
  MAX_ROWS = 64

  # The directions a stand-in may face; another faces down.
  DIRECTIONS = [2, 4, 6, 8]

  # The trigger of an event that runs by itself.
  AUTORUN_TRIGGER = 3

  # The DLL's topic that tells which frozen fight keeps an event from starting, see FreezeBlocker.
  BLOCKER_TOPIC = "freeze.blocker"

  # Frames between two log lines of a refused start of the same event, two seconds.
  REFUSE_FRAMES = 120

  # One stand-in as a frozen fight keeps it: the event it stands for, where it stands and how it
  # looks, and whether it is the boss and whether the live event hides meanwhile.
  #
  # @!attribute boss [Integer] 1 for the boss's stand-in, which takes the press and carries the bar.
  # @!attribute hide [Integer] 1 when it stands for the live event of its id on the same map.
  Row = Struct.new(:event_id, :x, :y, :direction, :pattern, :character_name, :character_index, :tile_id,
                   :opacity, :blend_type, :priority_type, :boss, :hide)

  # The place of a row's only text, the character's picture, among its values.
  NAME_INDEX = Row.members.index(:character_name)

  # One frozen fight's stand-ins on the current map.
  #
  # @!attribute troop [Integer] The boss's troop.
  # @!attribute name [String] The boss's name, see MGQ_MpRaidPool.troop_label.
  # @!attribute own [Boolean] Whether it comes from the player's own record, else the world's entry.
  # @!attribute standins [Array<Game_MpFreezeStandIn>] Its stand-ins.
  # @!attribute boss [Game_MpFreezeStandIn, nil] The boss's stand-in.
  # @!attribute hidden [Hash{Integer => Row}] The rows that stand for live events of the map, by
  #   the event's id, see hidden?.
  # @!attribute blocked [Array<Integer>] The live events that cannot start while it shows.
  # @!attribute held [Array<Array>] The story values it holds, each as kind and key, whose writers
  #   cannot start while it shows.
  Tableau = Struct.new(:troop, :name, :own, :standins, :boss, :hidden, :blocked, :held)

  # The frozen fights of the map as last built: its map id, the hash of the sources they were built
  # from and the tableaux, nil until built.
  @built = nil

  # The SCAN_FRAMES step of the last look at the sources.
  @checked = nil

  # The tableaux shown in a frame: the frame and the tableaux.
  @shown = nil

  # The tableaux that block starts in a frame, those that step aside included: the frame and the
  # tableaux.
  @blocking = nil

  # The frame whose starts looked at the sources afresh.
  @fresh_at = nil

  # Why each frozen fight steps aside, by troop, see played_reason.
  @played = {}

  # The writes of each list of commands the start of an event looked at, by the list's object id.
  @writes = {}


  # The frame of the last refused start of each event the player started, by map and event.
  @refused = {}

  # The first and the last frame of the player's ongoing touch of each event that leads into a
  # frozen fight, by map and event, see lead_in.
  @contact = {}

  # The frame in which such a start resumed its fight.
  @resumed_at = nil

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "raid freeze ui"

  # Lists the frozen fights the map shows: those that block starts (see blocking), unless their
  # scene plays live, see stepped_aside?.
  #
  # @return [Array<Tableau>] The tableaux.
  def self.tableaux
    now = MGQ_Multiplayer::Bridge.frame_number
    return @shown[1] if @shown && @shown[0] == now

    found = blocking
    played = found.empty? ? nil : played_reason
    shown = found.reject { |tableau| stepped_aside?(tableau, played) }
    @shown = [now, shown]
    shown
  rescue => e
    log_once(:tableaux, "finding the frozen fights failed: #{e.class}: #{e.message}")
    []
  end

  # Lists the frozen fights that keep events from starting: those whose tableau lies on this map,
  # while the player plays a Raid World's story, no battle runs and the fight's own resume does not
  # run.
  #
  # A start looks at the sources afresh, once a frame, since a world's entry arrives together with
  # the held values that turn the frozen event's page back on.
  #
  # @param fresh [Boolean] Whether to look at the sources afresh rather than every SCAN_FRAMES.
  # @return [Array<Tableau>] The tableaux.
  def self.blocking(fresh = false)
    now = MGQ_Multiplayer::Bridge.frame_number
    if fresh && @fresh_at != now
      @fresh_at = now
      @checked = nil
      @blocking = nil
      @shown = nil
    end
    return @blocking[1] if @blocking && @blocking[0] == now

    found = showing? ? built.reject { |tableau| resuming?(tableau.troop) } : []
    @blocking = [now, found]
    found
  end

  # Finds why the scenes of the frozen fights play live on the map: the player watches another
  # player's story scene, or another player tells the story here, whose game plays the fight.
  #
  # @return [String, nil] Why, nil when they do not.
  def self.played_reason
    return "the player watches another player's story scene" if defined?(MGQ_MpCoopScene) && MGQ_MpCoopScene.respond_to?(:watching?) && MGQ_MpCoopScene.watching?
    return nil unless defined?(MGQ_MpCoop::Scope) && defined?(MGQ_MpOverworldSync::Peers::Peer)

    teller = MGQ_MpCoop::Scope.teller
    return nil unless teller.is_a?(MGQ_MpOverworldSync::Peers::Peer)
    return nil unless teller.state["telling"] == true && teller.state["map"].to_i == $game_map.map_id

    name = teller.state["name"].to_s
    "#{name.empty? ? 'another player' : name} tells the story here"
  end

  # Reports whether a frozen fight's stand-ins step aside, logging when that changes: its scene
  # plays live (see played_reason), or an event it blocks runs all the same.
  #
  # @param tableau [Tableau] The fight.
  # @param played [String, nil] Why every scene of the map plays live, see played_reason.
  # @return [Boolean] Whether they step aside.
  def self.stepped_aside?(tableau, played)
    interpreter = $game_map.interpreter
    running = interpreter.running? && tableau.blocked.include?(interpreter.event_id.to_i)
    reason = played || (running ? "event #{interpreter.event_id} it blocks runs" : nil)
    was = @played[tableau.troop]
    if reason != was
      @played[tableau.troop] = reason
      where = "the frozen fight against #{tableau.name} (troop #{tableau.troop}) on map #{$game_map.map_id}"
      log(reason ? "hides the stand-ins of #{where}: #{reason}" : "shows the stand-ins of #{where} again")
    end
    reason ? true : false
  end

  # Reports whether frozen fights may show now: on the map of a Raid World's story outside battle.
  #
  # @return [Boolean] Whether they may.
  def self.showing?
    return false unless $game_map && defined?(MGQ_MpRaidPool) && MGQ_MpRaidPool.active?

    !($game_party && $game_party.in_battle)
  end

  # Reports whether a fight's resume runs, during which its scene plays as the live events.
  #
  # @param troop [Integer] The boss's troop.
  # @return [Boolean] Whether it does.
  def self.resuming?(troop)
    defined?(MGQ_MpRaidFreeze) && MGQ_MpRaidFreeze.resuming?(troop) ? true : false
  end

  # Finds the frozen fights of the current map, building them anew on another map or once their
  # sources changed, looked at every SCAN_FRAMES.
  #
  # @return [Array<Tableau>] The tableaux.
  def self.built
    map_id = $game_map.map_id
    step = MGQ_Multiplayer::Bridge.frame_number / SCAN_FRAMES
    same_map = @built && @built[0] == map_id
    return @built[2] if same_map && @checked == step

    @checked = step
    found = sources
    # The hash of the sources' contents, so a record changed in place reads as a change.
    return @built[2] if same_map && @built[1] == found.hash

    tableaux = found.map { |troop, own, data, held| data[0].to_i == map_id ? tableau_of(troop, own, data, held) : nil }.compact
    note_built(map_id, tableaux)
    @built = [map_id, found.hash, tableaux]
    tableaux
  end

  # Lists the frozen fights the player's game knows: the player's own records, then the world's
  # entries of the bosses the player keeps no record of, an own record winning.
  #
  # @return [Array<Array>] Each fight's troop, whether it is the player's own, its tableau and the
  #   story values it holds.
  def self.sources
    own = defined?(MGQ_MpRaidFreeze) ? Array(MGQ_MpRaidFreeze.records) : []
    found = own.map { |record| source_of(record, true) }.compact
    return found unless defined?(MGQ_MpWorldFreeze)

    Array(MGQ_MpWorldFreeze.entries).each do |entry|
      source = source_of(entry, false)
      next unless source
      next if found.any? { |troop, _own, _data| troop == source[0] }
      next if defined?(MGQ_MpRaidFreeze) && MGQ_MpRaidFreeze.record_for(source[0])

      found << source
    end
    found
  end

  # Reads the troop, the tableau and the held story values of a record or a world's entry; a record
  # holds what its world's entry would, see MGQ_MpRaidFreeze.entry_of.
  #
  # @param kept [Hash] The record or entry.
  # @param own [Boolean] Whether it is the player's own record.
  # @return [Array, nil] Its troop, own, tableau and held values, nil when it carries no tableau.
  def self.source_of(kept, own)
    return nil unless kept.is_a?(Hash)

    data = kept["tableau"]
    troop = kept["troop"].to_i
    return nil unless troop > 0 && data.is_a?(Array) && data[1].is_a?(Array)

    held = kept["held"]
    held = MGQ_MpRaidFreeze.entry_of(kept)["held"] if held.nil? && own && defined?(MGQ_MpRaidFreeze) && MGQ_MpRaidFreeze.respond_to?(:entry_of)
    [troop, own, data, Array(held)]
  end

  # Builds a frozen fight's stand-ins from its tableau.
  #
  # @param troop [Integer] The boss's troop.
  # @param own [Boolean] Whether it comes from the player's own record.
  # @param data [Array] The tableau: its map, its rows and the events it blocks.
  # @param held [Array<Array>] The story values it holds, each as kind, key and value.
  # @return [Tableau, nil] The tableau, nil when no row is whole.
  def self.tableau_of(troop, own, data, held = [])
    rows = data[1].first(MAX_ROWS).map { |entry| row_of(entry) }.compact
    return nil if rows.empty?

    standins = rows.map { |row| Game_MpFreezeStandIn.new(troop, row) }
    hidden = rows.each_with_object({}) { |row, ids| ids[row.event_id] = row if row.hide == 1 && row.event_id > 0 }
    blocked = Array(data[2]).map { |id| id.to_i }.select { |id| id > 0 }
    boss = standins.find { |standin| standin.boss? } || standins.first
    keys = Array(held).select { |kind, _key, _value| [0, 1, 2].include?(kind) }.map { |kind, key, _value| [kind, key] }
    Tableau.new(troop, MGQ_MpRaidPool.troop_label(troop), own, standins, boss, hidden, blocked, keys)
  end

  # Reads a row of a tableau, its values made the types the stand-in takes.
  #
  # @param entry [Array] The row's 13 values, see Row.
  # @return [Row, nil] The row, nil when it lacks values.
  def self.row_of(entry)
    return nil unless entry.is_a?(Array) && entry.size >= Row.members.size

    values = entry.first(Row.members.size)
    name = values[NAME_INDEX].to_s
    numbers = values.each_with_index.map do |value, index|
      next name if index == NAME_INDEX

      value.is_a?(Numeric) ? value.to_i : value.to_s.to_i
    end
    Row.new(*numbers)
  end

  # Logs the frozen fights a map shows anew and those it shows no more once they are built anew.
  #
  # @param map_id [Integer] The map.
  # @param tableaux [Array<Tableau>] The tableaux.
  def self.note_built(map_id, tableaux)
    was = @built && @built[0] == map_id ? @built[2] : []
    was.each do |tableau|
      next if tableaux.any? { |kept| kept.troop == tableau.troop && kept.own == tableau.own }

      log("no longer shows the frozen fight against #{tableau.name} (troop #{tableau.troop}) on map #{map_id}")
    end
    tableaux.each do |tableau|
      next if was.any? { |kept| kept.troop == tableau.troop && kept.own == tableau.own }

      boss = tableau.boss
      log("shows the frozen fight against #{tableau.name} (troop #{tableau.troop}) on map #{map_id} from " \
          "#{tableau.own ? "the player's own record" : "the world's entry"}: #{tableau.standins.size} stand-in(s), " \
          "the boss at (#{boss.x}, #{boss.y}), hiding events #{tableau.hidden.keys.sort.inspect}, blocking #{tableau.blocked.inspect}")
    end
  end

  # Finds the frozen fight whose boss's stand-in the action button faces: on the tile in front of the
  # player, across a counter, or under the player, as the game finds the event it starts.
  #
  # @return [Tableau, nil] The tableau, nil for none.
  def self.press_target
    shown = tableaux
    return nil if shown.empty?

    player = $game_player
    found = boss_at(shown, player.x, player.y)
    return found if found

    x2 = $game_map.round_x_with_direction(player.x, player.direction)
    y2 = $game_map.round_y_with_direction(player.y, player.direction)
    found = boss_at(shown, x2, y2)
    return found if found || !$game_map.counter?(x2, y2)

    boss_at(shown, $game_map.round_x_with_direction(x2, player.direction), $game_map.round_y_with_direction(y2, player.direction))
  end

  # Finds the frozen fight whose boss's stand-in stands on a tile.
  #
  # @param shown [Array<Tableau>] The tableaux.
  # @param x [Integer] The tile's x.
  # @param y [Integer] The tile's y.
  # @return [Tableau, nil] The tableau, nil for none.
  def self.boss_at(shown, x, y)
    shown.find { |tableau| tableau.boss && tableau.boss.x == x && tableau.boss.y == y }
  end

  # Resumes the frozen fight whose boss's stand-in the action button faces, see press_target.
  #
  # @return [Boolean] Whether a stand-in took the press, also when the fight did not start.
  def self.press
    target = press_target
    return false unless target

    log("the action button faces the stand-in of #{target.name} (troop #{target.troop}): resuming its fight")
    resume(target)
    true
  rescue => e
    log("pressing a frozen fight's stand-in failed: #{e.class}: #{e.message}")
    false
  end

  # Lists the frozen fights the Join Battle hotkey may offer, of which the DLL's JoinChoice picks the
  # one within its reach: those whose boss's stand-in shows, only the boss counting, not the
  # stand-ins around it.
  #
  # @return [Array<Array>] Each fight's troop, its boss's name and its boss's stand-in's x and y.
  def self.join_targets
    tableaux.map do |tableau|
      boss = tableau.boss
      boss ? [tableau.troop, tableau.name, boss.x, boss.y] : nil
    end.compact
  rescue => e
    log_once(:join_targets, "finding the frozen fights near the player failed: #{e.class}: #{e.message}")
    []
  end

  # Resumes a frozen fight of the map on the Join Battle hotkey.
  #
  # @param troop [Integer] The boss's troop.
  # @return [Boolean] Whether the fight started.
  def self.join(troop)
    target = tableaux.find { |tableau| tableau.troop == troop }
    unless target
      log("the Join Battle hotkey found no frozen fight of troop #{troop} on the map")
      return false
    end

    log("the Join Battle hotkey resumes the frozen fight against #{target.name} (troop #{troop})")
    resume(target)
  rescue => e
    log("joining a frozen fight failed: #{e.class}: #{e.message}")
    false
  end

  # Asks battles_raid_freeze.rbx to resume a frozen fight, which tells the player when it refuses.
  #
  # @param tableau [Tableau] The fight.
  # @return [Boolean] Whether it started.
  def self.resume(tableau)
    unless defined?(MGQ_MpRaidFreeze)
      log("cannot resume the fight against #{tableau.name}: battles_raid_freeze.rbx is not loaded")
      return false
    end

    started = MGQ_MpRaidFreeze.resume(tableau.troop) ? true : false
    log("the fight against #{tableau.name} (troop #{tableau.troop}) did not start") unless started
    started
  end

  # Lists the stand-ins of the bosses, which carry the bosses' HP bars, see ui_raid_bar.rbx.
  #
  # @return [Array<Array>] Each boss's stand-in with its troop.
  def self.bar_targets
    tableaux.map { |tableau| tableau.boss ? [tableau.boss, tableau.troop] : nil }.compact
  end

  # Lists the sprites of the stand-ins a spriteset of the map shows.
  #
  # @param spriteset [Spriteset_Map] The spriteset.
  # @return [Array<Sprite_Character>] The sprites.
  def self.sprites_of(spriteset)
    sprites = spriteset.instance_variable_get(:@mgq_mp_raid_freeze)
    sprites ? sprites.values : []
  end

  # Keeps a sprite per stand-in the map shows in a spriteset, freeing those of stand-ins that went.
  # Called after the spriteset's update.
  #
  # @param spriteset [Spriteset_Map] The spriteset.
  # @param sprites [Hash{Game_MpFreezeStandIn => Sprite_Character}] Its sprites of stand-ins.
  def self.update_sprites(spriteset, sprites)
    standins = tableaux.map { |tableau| tableau.standins }.flatten
    sprites.keys.each do |standin|
      sprites.delete(standin).dispose unless standins.any? { |shown| shown.equal?(standin) }
    end
    standins.each { |standin| (sprites[standin] ||= Sprite_Character.new(MGQ_MpGame.get(spriteset, :viewport1), standin)).update }
  rescue => e
    log_once(:sprites, "drawing the frozen fights' stand-ins failed: #{e.class}: #{e.message}")
  end

  # Reports whether a character's sprite hides: a live event a shown frozen fight stands in for,
  # the boss always, any other only while its page runs nothing.
  #
  # A row's live event may show another page of its own since the battle, such as a villager's
  # again, which serves on unhidden.
  #
  # @param character [Game_Character, nil] The sprite's character.
  # @return [Boolean] Whether it hides.
  def self.hidden?(character)
    return false unless character.is_a?(Game_Event)

    id = character.id
    rows = tableaux.map { |tableau| tableau.hidden[id] }.compact
    return false if rows.empty?

    rows.any? { |row| row.boss == 1 } || MGQ_MpRaidFreeze.runs_nothing?(character)
  rescue => e
    log_once(:hidden, "hiding the events of a frozen fight failed: #{e.class}: #{e.message}")
    false
  end

  # Keeps an event from starting while a frozen fight of the map holds (see blocker_of), so the
  # frozen scene does not run again and no earlier scene moves the held story values back; an event
  # of the fight's own the player starts resumes the fight instead, as the DLL tells. Called around
  # Game_Event#start, which an event that runs by itself calls every frame.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether it must not start.
  def self.refuse_start?(event)
    return false unless $game_map && event.is_a?(Game_Event)
    return after_resume(event) if @resumed_at == MGQ_Multiplayer::Bridge.frame_number

    shown = blocking(true)
    return false if shown.empty?

    tableau, reason, leads_in = blocker_of(event, shown)
    return false unless tableau
    return lead_in(event, tableau) if leads_in

    refused(event, tableau, reason)
    true
  rescue => e
    log_once(:refuse_start, "looking whether a frozen fight keeps an event from starting failed: #{e.class}: #{e.message}")
    false
  end

  # Resumes a frozen fight from an event of its own the player started, as its boss's stand-in
  # does, see press.
  #
  # A touch the player keeps up, such as walking against the event, starts it every frame, so only
  # its first frame resumes.
  #
  # @param event [Game_Event] The event.
  # @param tableau [Tableau] The fight.
  # @return [Boolean] true, since the event itself never starts.
  def self.lead_in(event, tableau)
    map_id = $game_map.map_id
    key = [map_id, event.id]
    now = MGQ_Multiplayer::Bridge.frame_number
    first, last = @contact[key]
    held = last && now - last <= 1
    @contact[key] = [held ? first : now, now]
    if held
      log_once([:contact, map_id, event.id], "kept event #{event.id} on map #{map_id} from starting: the player keeps touching it")
      return true
    end

    log("the player started event #{event.id} on map #{map_id}, which leads into the frozen fight against #{tableau.name} " \
        "(troop #{tableau.troop}): resuming its fight")
    @resumed_at = now if resume(tableau)
    true
  end

  # Keeps an event from starting in the frame a start of another resumed its frozen fight, so it
  # cannot run once the resume's event ends.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] true.
  def self.after_resume(event)
    map_id = $game_map.map_id
    log_once([:after_resume, map_id, event.id], "kept event #{event.id} on map #{map_id} from starting: a frozen fight resumed this frame")
    true
  end

  # Asks the DLL which frozen fight keeps an event from starting (FreezeBlocker.Find): one that
  # blocks the event itself, else one that holds a story value the event's page writes; and whether
  # the player's start resumes that fight instead, as pressing or touching one of the fight's own
  # events does while its stand-ins show.
  #
  # @param event [Game_Event] The event.
  # @param shown [Array<Tableau>] The fights, see blocking.
  # @return [Array(Tableau, String, Boolean), nil] The fight, why and whether the start resumes it;
  #   nil for none.
  def self.blocker_of(event, shown)
    visible = tableaux
    rows = shown.map { |tableau| [tableau.troop, tableau.blocked, tableau.held, visible.any? { |each| each.equal?(tableau) }] }
    answer = MGQ_Multiplayer::Bridge.call(BLOCKER_TOPIC, "map" => $game_map.map_id, "event" => event.id, "trigger" => event.trigger.to_i,
                                                         "writes" => page_writes(event), "tableaux" => rows)
    tableau = answer.is_a?(Hash) ? shown.find { |each| each.troop == answer["troop"] } : nil
    tableau ? [tableau, answer["reason"].to_s, answer["leads_in"] ? true : false] : nil
  end

  # Lists what the page an event shows writes, through the common events it calls too, as the DLL's
  # command index tells it (MGQ_MpCoopEvents.page_writes), kept per list of commands.
  #
  # @param event [Game_Event] The event.
  # @return [Array<Array>] Each write: 0 or 1 with the first and last switch or variable, or 2 with
  #   the self switch's letter.
  def self.page_writes(event)
    list = event.list
    return [] unless list

    @writes[list.object_id] ||= MGQ_MpCoopEvents.page_writes(event).map { |kind, target| kind == 2 ? [2, target.to_s] : [kind, target.first, target.last] }
  end

  # Logs a refused start once in REFUSE_FRAMES per event; an event that runs by itself is logged once.
  #
  # @param event [Game_Event] The event.
  # @param tableau [Tableau] The fight that keeps it from starting.
  # @param reason [String] Why, for the log.
  def self.refused(event, tableau, reason)
    map_id = $game_map.map_id
    playing = @played[tableau.troop] ? ", and its scene plays" : ""
    text = "kept event #{event.id} on map #{map_id} from starting: #{reason}; the fight against #{tableau.name} (troop #{tableau.troop}) waits frozen there#{playing}"
    return log_once([:refused, map_id, event.id, tableau.troop], text) if event.trigger == AUTORUN_TRIGGER

    key = [map_id, event.id]
    now = MGQ_Multiplayer::Bridge.frame_number
    return if @refused[key] && now - @refused[key] < REFUSE_FRAMES

    @refused[key] = now
    log(text)
  end

  # Keeps the events a frozen fight blocks from starting should one be starting all the same, past
  # Game_Event#start. Called before the map starts its starting event.
  #
  # @param map [Game_Map] The map.
  def self.block_starts(map)
    starting = map.events.values.select { |event| event.starting }
    return if starting.empty?

    shown = blocking(true)
    starting.each do |event|
      tableau, reason = blocker_of(event, shown)
      next unless tableau

      event.clear_starting_flag
      event.unlock
      MGQ_MpFlowGuard.skipped(event.list, "event #{event.id} on map #{map.map_id}") if defined?(MGQ_MpFlowGuard)
      log_once([:blocked, map.map_id, event.id], "kept starting event #{event.id} on map #{map.map_id} from running: #{reason}; " \
               "the fight against #{tableau.name} (troop #{tableau.troop}) waits frozen there")
    end
  rescue => e
    log_once(:block_starts, "blocking a frozen fight's events failed: #{e.class}: #{e.message}")
  end

  # Drops the frozen fights built, which the next look builds anew.
  #
  # @param reason [String] Why, for the log.
  def self.forget(reason = "another script asked")
    log("forgot the frozen fights' stand-ins: #{reason}") if @built && !@built[2].empty?
    @built = nil
    @checked = nil
    @shown = nil
    @blocking = nil
    @fresh_at = nil
    @played = {}
    @writes = {}
    @refused = {}
    @contact = {}
    @resumed_at = nil
  end
end

# A stand-in of a frozen fight: looks and stands as the character it stands for did at the battle
# command, walks through everything and starts nothing, since it is no event of the map.
class Game_MpFreezeStandIn < Game_Character
  # The boss's troop of its fight.
  attr_reader :troop

  # The event it stands for, 0 for none.
  attr_reader :event_id

  # Creates the stand-in where its row stands, with the row's look.
  #
  # @param troop [Integer] The boss's troop.
  # @param row [MGQ_MpRaidFreezeUi::Row] The row.
  def initialize(troop, row)
    super()
    @troop = troop
    @event_id = row.event_id
    @boss = row.boss == 1
    @character_name = row.character_name
    @character_index = row.character_index
    @tile_id = row.tile_id
    @original_pattern = @pattern = row.pattern
    @direction = MGQ_MpRaidFreezeUi::DIRECTIONS.include?(row.direction) ? row.direction : 2
    @opacity = row.opacity
    @blend_type = row.blend_type
    @priority_type = row.priority_type
    @through = true
    @walk_anime = false
    @step_anime = false
    moveto(row.x, row.y)
  end

  # Reports whether it is the boss's stand-in.
  #
  # @return [Boolean] Whether it is.
  def boss?
    @boss
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # A new map shows its own frozen fights.
  MGQ_MpHooks.after(Game_Map, :setup, "ui_raid_freeze") { |_map_id| MGQ_MpRaidFreezeUi.forget("a map was set up") }

  # After the map's sprites, a sprite per stand-in.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_raid_freeze") do
    @mgq_mp_raid_freeze ||= {}
    MGQ_MpRaidFreezeUi.update_sprites(self, @mgq_mp_raid_freeze)
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_raid_freeze") do
    (@mgq_mp_raid_freeze || {}).each_value { |sprite| sprite.dispose }
    @mgq_mp_raid_freeze = nil
  end

  # The live events a frozen fight stands in for hide while it shows.
  MGQ_MpHooks.after(Sprite_Character, :update, "ui_raid_freeze") { self.visible = false if MGQ_MpRaidFreezeUi.hidden?(character) }

  # The action button facing a boss's stand-in resumes its fight.
  MGQ_MpHooks.around(Game_Player, :check_action_event, "ui_raid_freeze") do |_player, _args, original|
    !$game_map.interpreter.running? && MGQ_MpRaidFreezeUi.press ? true : original.call
  end

  # An event a frozen fight keeps from starting never counts as starting, so nothing waits for it,
  # such as the fade-in of a screen left dark (see coop_events.rbx).
  MGQ_MpHooks.around(Game_Event, :start, "ui_raid_freeze") { |event, _args, original| MGQ_MpRaidFreezeUi.refuse_start?(event) ? nil : original.call }

  # Before the map starts the event that is starting, a frozen fight's own events are left out;
  # registered after coop_events.rbx's, so it runs first.
  MGQ_MpHooks.before(Game_Map, :setup_starting_map_event, "ui_raid_freeze") { MGQ_MpRaidFreezeUi.block_starts(self) }

  MGQ_MpHooks.before(Scene_Title, :start, "ui_raid_freeze") { MGQ_MpRaidFreezeUi.forget("the title screen") }

  # A loaded save brings its own records and map.
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "ui_raid_freeze") { |_contents| MGQ_MpRaidFreezeUi.forget("a save was loaded") }
rescue => e
  MGQ_MpRaidFreezeUi.log("hooks FAILED: #{e.class}: #{e.message}")
end
