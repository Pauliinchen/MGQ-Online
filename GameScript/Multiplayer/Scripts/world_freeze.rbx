#----------------------------------------------------------------
#  world_freeze.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Left writing and reading a frozen fight's text to the DLL, handing it the fight as values
#                            - Read the bridge's frame as its clock
#      Paulinchen  2026-10-28: Read the fights each side plays in the other's stead from the freeze's tables
#      Paulinchen  2026-10-23: Sent and took each frozen fight as a key of the relay's story tracks instead of a list beside the whole story
#      Paulinchen  2026-10-17: Created
#
#----------------------------------------------------------------

# A Raid World's frozen boss fights: a player who lost a raid boss's story battle keeps the story at
# that battle (see battles_raid_freeze.rbx), and the world's story keeps it there for every player
# until the boss's pools are defeated or its BEATEN marker is met, its own or that of the fight the
# other side plays in its stead. Each frozen fight is one key of the relay's story tracks by its
# troop (f<troop>), whose text the DLL writes and reads (FrozenFightText), which the whole world
# keeps, players behind included, merged here as a union by troop; a fight that ended is ENDED,
# which replaces it for every game. An end is final for the world: the boss dies once, so no game
# freezes that troop or the one the other side fights in its stead again. An entry's held keys are
# the switches, variables and self switches the world's story shares at their value from before the
# fight's event ran (see MGQ_MpWorldStory.held_value), so nobody's story moves past the fight while
# it is frozen.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldFreeze
  # Frozen fights the list holds at most.
  MAX_ENTRIES = 32

  # Held keys one frozen fight has at most.
  MAX_HELD = 512

  # What a fight's key holds once the fight ended, which the relay keeps in place of the fight.
  ENDED = false

  # The topic that answers a fight as another game reads it back, see StoryTopics.FrozenEntry in the
  # DLL.
  ENTRY_TOPIC = "story.freeze_entry"

  # Frames between two looks whether a frozen fight ended, a second.
  CHECK_FRAMES = 60

  # The letters the log names the held keys' kinds by: a switch, a variable, a self switch.
  KIND_LETTERS = ["s", "v", "ss"]

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "world freeze"

  # The id of the world whose frozen fights are kept.
  @world_id = nil

  # Forgets the frozen fights, as at the title or once another world opened.
  #
  # @param reason [String] Why, for the log.
  def self.forget(reason = "at the title")
    log("forgot #{@entries.size} frozen fight(s) #{reason}") if @entries && !@entries.empty?
    @entries = []
    @index = [{}, {}, {}]
    @held = []
    @told = nil
    @checked_at = nil
    @ended = {}
  rescue => e
    log("forgetting the frozen fights failed: #{e.class}: #{e.message}")
  end

  forget

  # Forgets the frozen fights once another world opened than the one they are of.
  def self.note_world
    id = world_id
    return if id == @world_id

    forget("of the last world, as another one is open")
    @world_id = id
  end

  # The open world's id.
  #
  # @return [String] The id, empty outside a Raid World.
  def self.world_id
    defined?(MGQ_MpWorldStory) ? MGQ_MpWorldStory.world_id.to_s : ""
  rescue
    ""
  end

  # Looks at most every CHECK_FRAMES whether the world changed or a frozen fight ended.
  def self.check
    now = frame
    return if @checked_at && (now - @checked_at).abs < CHECK_FRAMES

    @checked_at = now
    note_world
    drop_ended
  end

  # Tells the bridge's frame, the clock of every timer, which never goes back as a save loads.
  #
  # @return [Integer] The frame, 0 before the bridge counts any.
  def self.frame
    MGQ_Multiplayer::Bridge.frame_number
  end

  # Lists the open world's frozen fights that have not ended, oldest first.
  #
  # @return [Array<Hash>] The entries, see battles_raid_freeze.rbx; the caller changes none.
  def self.entries
    note_world
    check
    @entries.dup
  rescue => e
    log_once(:entries, "listing the frozen fights failed: #{e.class}: #{e.message}")
    []
  end

  # Finds the frozen fight against a troop.
  #
  # @param troop [Integer] The troop.
  # @return [Hash, nil] The entry, nil while no fight against it is frozen.
  def self.entry(troop)
    entries.find { |entry| entry["troop"] == troop.to_i }
  end

  # Reads the value the world's story holds a switch, variable or self switch at while a fight is
  # frozen.
  #
  # Called for every key of every comparison of the story, so it must stay cheap.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Array, nil] true and the value, nil for a key no frozen fight holds.
  def self.held_value(kind, key)
    return nil if @entries.empty?

    check
    values = @index[kind]
    values && values.key?(key) ? [true, values[key]] : nil
  rescue
    nil
  end

  # Lists every held key of the frozen fights, the oldest fight's value for a key two hold.
  #
  # The fights that ended are dropped first, not every CHECK_FRAMES, since the caller puts these
  # values into a story.
  #
  # @return [Array<Array>] Each key as kind, key and value.
  def self.held
    return [] if @entries.empty?

    note_world
    drop_ended
    @held.dup
  rescue
    []
  end

  # Notes the player's own frozen fight and asks the relay to keep it for the world. Called by
  # battles_raid_freeze.rbx once a lost fight's undo ran.
  #
  # @param entry [Hash] The entry, see battles_raid_freeze.rbx.
  # @return [Boolean] Whether the list holds the fight now.
  def self.note(entry)
    note_world
    clean = clean(entry)
    unless clean
      log("refused to note a frozen fight that is no entry: #{MGQ_MpLog.short(entry.inspect, 200)}")
      return false
    end

    reason = end_reason(clean)
    if reason
      log("refused to note the frozen fight against troop #{clean['troop']}: #{reason}")
      note_ended(clean, reason)
      return false
    end

    merged = merge(clean, "the player's")
    rebuild if merged
    return true unless merged

    asked = defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.write_freeze(clean["troop"], plain_entry(clean))
    log("the frozen fight against troop #{clean['troop']} #{asked ? 'goes to the world' : 'stays this game\'s own: no Raid World story takes it'}")
    true
  rescue => e
    log("noting a frozen fight failed: #{e.class}: #{e.message}")
    false
  end

  # Reports whether the fight against a troop ended for the open world, which is final: no game
  # freezes it again, see end_reason. Called by battles_raid_freeze.rbx as a battle is set up.
  #
  # @param troop [Integer, String] The troop.
  # @return [Boolean] Whether it did.
  def self.final?(troop)
    note_world
    end_reason("troop" => troop.to_i) ? true : false
  rescue => e
    log_once(:final, "looking whether a fight ended for the world failed: #{e.class}: #{e.message}")
    false
  end

  # Takes the frozen fights of the world's story the relay handed: each fight's key by its troop,
  # merged into the list, and the ends, for good, whatever the player's part.
  #
  # @param keys [Hash{Integer => Object}] Each fight's key by troop: the fight as the DLL reads it
  #   (FrozenFightText), ENDED, or nil for a fight it cannot read.
  def self.take_keys(keys)
    note_world
    ended = keys.select { |_troop, value| value == ENDED }.keys
    changed = take_ended(ended)
    keys.each do |troop, value|
      next if value == ENDED

      entry = value.is_a?(Hash) && boss?(troop) ? game_entry(value) : nil
      next log_once([:unread, troop], "dropped the world's frozen fight against troop #{troop}: this game cannot read it") unless entry

      reason = end_reason(entry)
      next note_ended(entry, reason) if reason

      changed = true if merge(entry, "the world's")
    end
    rebuild if changed
  rescue => e
    log_once(:take_keys, "taking the world's frozen fights failed: #{e.class}: #{e.message}")
  end

  # Notes the fights a world's story carries as ended, with the fights the other side plays in their
  # stead, and drops their frozen fights, the player's own too.
  #
  # @param troops [Array<Integer>] The troops of the fights the world's story carries as ended.
  # @return [Boolean] Whether the list changed.
  def self.take_ended(troops)
    troops.each do |troop|
      added = mark_ended(troop)
      log("the world's story ended the fight against troop #{added.join(' and ')} for good") unless added.empty?
    end
    kept = @entries.reject { |entry| @ended[entry["troop"]] }
    return false if kept.size == @entries.size

    (@entries - kept).each { |entry| log("dropped the frozen fight against troop #{entry['troop']}: the world's story ended it") }
    @entries = kept
    true
  end

  # Marks the fight against a troop ended for the world, with the fights the other side plays in its
  # stead, so the end of one ends them all.
  #
  # @param troop [Integer] The troop.
  # @return [Array<Integer>] The troops marked now, none for those marked before.
  def self.mark_ended(troop)
    added = ([troop] + alternatives(troop)).reject { |other| @ended[other] }
    added.each { |other| @ended[other] = true }
    added
  end

  # Keeps the world's story laid over the player's last, for the end rule, and ends the fights it
  # beat. Called by world_story.rbx before its held keys are put.
  #
  # @param told [Array] The world's story: switches, variables and self switches.
  def self.world_told(told)
    note_world
    @told = told
    drop_ended
  rescue => e
    log_once(:world_told, "following the world's story for the frozen fights failed: #{e.class}: #{e.message}")
  end

  # Reports whether a frozen fight ended, see end_reason.
  #
  # @param entry [Hash] The entry.
  # @return [Boolean] Whether it did.
  def self.ended?(entry)
    end_reason(entry) ? true : false
  end

  # Finds why a frozen fight ended: the world ended it before, which is final (see mark_ended), its
  # troop's fight ended (see fight_end), or the fight the other side plays in its stead did (see
  # alternatives).
  #
  # A player of the other side is past the fight without ever meeting its own end, and the world's
  # furthest story wins.
  #
  # @param entry [Hash] The entry.
  # @return [String, nil] Why, nil while it holds.
  def self.end_reason(entry)
    troop = entry["troop"]
    return "the fight ended for the world before, for good" if @ended[troop]
    return nil unless defined?(MGQ_MpRaidPool) && defined?(MGQ_MpRaidBosses)

    reason = fight_end(troop)
    return reason if reason

    alternatives(troop).each do |other|
      reason = fight_end(other)
      return "the other side's fight against troop #{other} ended: #{reason}" if reason
    end
    nil
  rescue => e
    log_once([:end_reason, e.class], "looking whether a frozen fight ended failed: #{e.class}: #{e.message}")
    nil
  end

  # Lists the troops the other side fights in a troop's stead, see
  # the freeze's ALTERNATIVES (MGQ_MpRaidFreeze.tables).
  #
  # @param troop [Integer] The troop.
  # @return [Array<Integer>] The troops, none for a fight both sides play.
  def self.alternatives(troop)
    return [] unless defined?(MGQ_MpRaidFreeze)

    MGQ_MpRaidFreeze.data(:ALTERNATIVES, {})[troop] || []
  end

  # Finds why a troop's fight ended: the player won a battle against its pools (see
  # MGQ_MpRaidFreeze.won?), every pool of its boss is known and defeated, or the boss's BEATEN
  # marker is met by the player's story or the world's last told one.
  #
  # @param troop [Integer] The troop.
  # @return [String, nil] Why, nil while it holds.
  def self.fight_end(troop)
    return "the player won its battle" if defined?(MGQ_MpRaidFreeze) && MGQ_MpRaidFreeze.respond_to?(:won?) && MGQ_MpRaidFreeze.won?(troop)

    keys = MGQ_MpRaidPool.troop_keys(troop)
    return "its pools are defeated" if !keys.empty? && keys.all? { |key| (pool = MGQ_MpRaidPool.pool(key)) && pool.defeated }

    boss = MGQ_MpRaidBosses.at(troop)
    return nil unless boss
    return "the player's story beat it" if MGQ_MpRaidPool.beaten?(boss)

    test = MGQ_MpRaidPool::BEATEN[[boss.milestone, boss.cap]]
    test && @told && MGQ_MpRaidPool.met?(test, @told) ? "the world's story beat it" : nil
  end

  # Drops the frozen fights that ended, see end_reason.
  def self.drop_ended
    return if @entries.empty?

    kept = @entries.reject do |entry|
      reason = end_reason(entry)
      note_ended(entry, reason) if reason
      reason
    end
    return if kept.size == @entries.size

    @entries = kept
    rebuild
  end

  # Notes that a frozen fight ended, for good: it is never written again but as ENDED, with the
  # fights the other side plays in its stead, which the relay is asked to end for every game of the
  # world.
  #
  # @param entry [Hash] The entry.
  # @param reason [String] Why it ended.
  def self.note_ended(entry, reason)
    troop = entry["troop"]
    log_once([:ended, @world_id, troop, reason], "the frozen fight against troop #{troop} ended: #{reason}")
    added = mark_ended(troop)
    return if added.empty?

    asked = defined?(MGQ_MpWorldStory) && added.map { |each| MGQ_MpWorldStory.write_freeze(each, ENDED) }.all?
    log("the world's story ends the fight against troop #{added.join(' and ')} for good#{asked ? '' : ', in this game alone'}")
  end

  # Merges a frozen fight into the list: a fight already known keeps its fields and gains the held
  # keys it lacks, its own value winning a key both hold; a fight that ended for the world is refused.
  #
  # @param entry [Hash] The entry, see clean.
  # @param source [String] Whose it is, for the log.
  # @return [Boolean] Whether the list changed.
  def self.merge(entry, source)
    if @ended[entry["troop"]]
      log_once([:final, @world_id, entry["troop"], source], "refused #{source} frozen fight against troop #{entry['troop']}: the fight ended for the world, for good")
      return false
    end

    known = @entries.find { |other| other["troop"] == entry["troop"] }
    unless known
      if @entries.size >= MAX_ENTRIES
        log_once([:full, entry["troop"]], "dropped #{source} frozen fight against troop #{entry['troop']}: the list holds #{MAX_ENTRIES} already")
        return false
      end

      @entries << entry
      log("took #{source} frozen fight against troop #{entry['troop']} at #{entry['site']}, holding #{held_text(entry['held'])}")
      return true
    end

    have = {}
    known["held"].each { |kind, key, _| have[[kind, key]] = true }
    added = entry["held"].reject { |kind, key, _| have[[kind, key]] }.first([MAX_HELD - known["held"].size, 0].max)
    return false if added.empty?

    known["held"] = known["held"] + added
    log("#{source} frozen fight against troop #{entry['troop']} also holds #{held_text(added)}")
    true
  end

  # Rebuilds the index of the held keys, the oldest fight's value winning a key two hold.
  def self.rebuild
    index = [{}, {}, {}]
    held = []
    @entries.each do |entry|
      entry["held"].each do |kind, key, value|
        next if index[kind].key?(key)

        index[kind][key] = value
        held << [kind, key, value]
      end
    end
    @index = index
    @held = held
  end

  # Names held keys for the log.
  #
  # @param held [Array<Array>] Each key as kind, key and value.
  # @return [String] Such as "v1075 14, s31 false", at most ten.
  def self.held_text(held)
    return "nothing" if held.empty?

    names = held.first(10).map { |kind, key, value| "#{KIND_LETTERS[kind]}#{key.is_a?(Array) ? key.join('.') : key} #{value.inspect}" }
    names.join(", ") + (held.size > 10 ? ", ..." : "")
  end

  # Reads an entry as another game reads it back from the relay's track, the fields of the player's
  # own record and what the track cannot carry left out (the DLL's FrozenFightText).
  #
  # @param entry [Hash] The entry.
  # @return [Hash, nil] The entry, nil for one that is none or longer than the relay keeps.
  def self.clean(entry)
    return nil unless entry.is_a?(Hash)

    read = MGQ_Multiplayer::Bridge.call(ENTRY_TOPIC, plain_entry(entry))
    read.is_a?(Hash) ? game_entry(read) : nil
  end

  # Turns an entry into what the DLL takes: its fields alone, each held value as the DLL takes it
  # (MGQ_MpStoryKeys.plain_of), a variable whose value no story carries left out.
  #
  # @param entry [Hash] The entry.
  # @return [Hash] The entry.
  def self.plain_entry(entry)
    held = Array(entry["held"]).map do |kind, key, value|
      plain = MGQ_MpStoryKeys.plain_of(kind, value)
      next log_once([:unsent, kind, key], "left the held #{KIND_LETTERS[kind]}#{key} out: its value is no kind the story carries") if plain.nil?

      [kind, key, plain]
    end
    { "troop" => entry["troop"], "site" => entry["site"], "outer" => entry["outer"], "scene" => entry["scene"] ? true : false,
      "tableau" => entry["tableau"], "spot" => entry["spot"], "held" => held.compact }
  end

  # Turns an entry the DLL read into the game's values, see plain_entry.
  #
  # @param entry [Hash] The entry.
  # @return [Hash] The entry.
  def self.game_entry(entry)
    entry.merge("held" => Array(entry["held"]).map { |kind, key, value| [kind, key, MGQ_MpStoryKeys.game_value(kind, value)] })
  end

  # Reports whether a troop is a raid boss's, the only fights the list takes.
  #
  # @param troop [Integer] The troop.
  # @return [Boolean] Whether it is.
  def self.boss?(troop)
    troop.is_a?(Integer) && troop > 0 && defined?(MGQ_MpRaidBosses) && MGQ_MpRaidBosses.boss?(troop) ? true : false
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  MGQ_MpHooks.before(Scene_Title, :start, "world_freeze") { MGQ_MpWorldFreeze.forget }
rescue => e
  MGQ_MpWorldFreeze.log("hooks FAILED: #{e.class}: #{e.message}")
end
