#----------------------------------------------------------------
#  world_freeze.rbx
#
#  Changelog:
#      Paulinchen  2026-10-17: Created
#
#----------------------------------------------------------------

# A Raid World's frozen boss fights: a player who lost a raid boss's story battle keeps the story at
# that battle (see battles_raid_freeze.rbx), and the world's story keeps it there for every player
# until the boss's pools are defeated or its BEATEN marker is met, its own or that of the fight the
# other side plays in its stead. Each frozen fight is an entry of
# a list the world's story carries beside the story (LIST), merged as a union by troop; the DLL and
# the relay keep each entry as one key of its troop (f<troop>), and a fight that ended as ENDED, which
# replaces it for every game. An end is final for the world: the boss dies once, so no game freezes
# that troop or the one the other side fights in its stead again. An entry's held keys are the switches, variables and self switches the
# world's story shares at their value from before the fight's event ran (see
# MGQ_MpWorldStory.shared_value), so nobody's story moves past the fight while it is frozen.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldFreeze
  # The list of the story's text that holds the frozen fights.
  LIST = "f"

  # Frozen fights the list holds at most.
  MAX_ENTRIES = 32

  # Sprite rows one frozen fight's stand-ins have at most.
  MAX_ROWS = 64

  # Held keys one frozen fight has at most.
  MAX_HELD = 512

  # Fields of a sprite row, see the entry's "tableau".
  ROW_SIZE = 13

  # The place of the character name among a sprite row's fields, the only text among them.
  ROW_NAME = 5

  # The places of a sprite row's boss and hide flags, each 1 or 0.
  ROW_FLAGS = [11, 12]

  # Fields of an entry in the list's text.
  ENTRY_FIELDS = 9

  # What an entry's fields after its troop are once the fight ended: the list's text carries
  # "<troop>|0", which the relay keeps in place of the fight.
  ENDED = "0"

  # The longest entry the relay keeps (maxFreezeLength of Relay/core/story.js), past which it would
  # refuse the whole write.
  MAX_ENTRY_LENGTH = 65_536

  # The largest integer an entry's text carries, which keeps a broken text from making huge numbers.
  MAX_INTEGER = 2_147_483_647

  # Frames between two looks whether a frozen fight ended, a second.
  CHECK_FRAMES = 60

  # What a site key looks like, see battles_raid_freeze_data.rbx.
  SITE_KEY = /\A(map:\d+:\d+:\d+|ce:\d+)\z/

  # The bytes of a free text written as they are; every other byte is escaped as %XX.
  PLAIN_BYTE = /[^A-Za-z0-9_$!\-]/n

  # What an escaped text looks like.
  ESCAPED = /\A(?:[A-Za-z0-9_$!\-]|%[0-9A-Fa-f]{2})*\z/

  # What an integer of the list's text looks like.
  INTEGER = /\A-?\d{1,10}\z/

  # The letters of the held keys' kinds in the list's text: a switch, a variable, a self switch.
  KIND_LETTERS = ["s", "v", "x"]

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
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
    @unshared = false
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

  # The game's frame counter.
  #
  # @return [Integer] The frame, 0 before the game counts any.
  def self.frame
    defined?(Graphics) ? Graphics.frame_count.to_i : 0
  rescue
    0
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

  # Notes the player's own frozen fight and asks for a write of their story, which carries it.
  # Called by battles_raid_freeze.rbx once a lost fight's undo ran.
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

    @unshared = true
    asked = defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.request_post
    log("the world's story carries the frozen fight against troop #{clean['troop']} #{asked ? 'with the next write' : 'once the player plays it'}")
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

  # Adds the frozen fights to the lists of a story the player writes, and as ENDED every fight that
  # ended for the world, which ends them for every game of the world.
  #
  # @param lists [Hash{String => String}] The story's lists, see MGQ_MpStoryState.story_lists.
  # @return [Hash{String => String}] The lists with LIST.
  def self.add(lists)
    note_world
    drop_ended
    ended = @ended.keys.sort.map { |troop| "#{troop}|#{ENDED}" }
    lists[LIST] = [encode(@entries), *ended].reject(&:empty?).join(";")
    @unshared = false
    lists
  rescue => e
    log_once(:add, "writing the frozen fights failed: #{e.class}: #{e.message}")
    lists
  end

  # Merges the frozen fights a world's story came with, whatever the player's part, and drops those
  # it carries as ended, for good.
  #
  # A story without LIST, as an earlier version writes it, takes nothing and marks nothing unshared,
  # since a write cannot make it carry the list and every take would ask for another write.
  #
  # @param text [String] The world's story, packed.
  def self.take(text)
    note_world
    lists = MGQ_MpStoryState.unpack(text)
    unless lists.key?(LIST)
      log_once([:no_list, @world_id], "the world's story carries no list of frozen fights: they stay this game's own")
      return
    end

    list = lists[LIST].to_s
    told = list.empty? ? [] : decode(list)
    ended = list.split(";").map { |part| ended_troop(part) }.compact
    changed = take_ended(ended)
    told.each do |entry|
      reason = end_reason(entry)
      next note_ended(entry, reason) if reason

      changed = true if merge(entry, "the world's")
    end
    rebuild if changed
    @unshared = true if lacks?(told, ended)
  rescue => e
    log_once(:take, "taking the world's frozen fights failed: #{e.class}: #{e.message}")
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

  # Reports whether the player knows a frozen fight, a held key or the end of a fight the world's
  # story lacks, which the player's next write must carry: set by note, by an end this game saw and
  # by a take of a story that lacks one, cleared once a write carried the list. Called by
  # world_story.rbx after a take.
  #
  # @return [Boolean] Whether they do.
  def self.unshared?
    @unshared && !(@entries.empty? && @ended.empty?) ? true : false
  end

  # Reports whether the frozen fights of a world's story lack one the player knows, a held key of
  # one, or the end of one this game saw.
  #
  # @param told [Array<Hash>] The world's entries.
  # @param ended [Array<Integer>] The troops of the fights the world's story carries as ended.
  # @return [Boolean] Whether they do.
  def self.lacks?(told, ended = [])
    keys = {}
    told.each { |entry| entry["held"].each { |kind, key, _| keys[[entry["troop"], kind, key]] = true } }
    return true if @ended.keys.any? { |troop| !ended.include?(troop) }

    @entries.any? { |entry| entry["held"].any? { |kind, key, _| !keys[[entry["troop"], kind, key]] } || told.none? { |other| other["troop"] == entry["troop"] } }
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
  # MGQ_MpRaidFreezeData::ALTERNATIVES.
  #
  # @param troop [Integer] The troop.
  # @return [Array<Integer>] The troops, none for a fight both sides play.
  def self.alternatives(troop)
    return [] unless defined?(MGQ_MpRaidFreezeData) && MGQ_MpRaidFreezeData.const_defined?(:ALTERNATIVES)

    MGQ_MpRaidFreezeData::ALTERNATIVES[troop] || []
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
  # fights the other side plays in its stead, and a write is asked for that ends them for every game
  # of the world.
  #
  # @param entry [Hash] The entry.
  # @param reason [String] Why it ended.
  def self.note_ended(entry, reason)
    troop = entry["troop"]
    log_once([:ended, @world_id, troop, reason], "the frozen fight against troop #{troop} ended: #{reason}")
    added = mark_ended(troop)
    return if added.empty?

    @unshared = true
    asked = defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.request_post
    log("the world's story ends the fight against troop #{added.join(' and ')} for good #{asked ? 'with the next write' : 'once the player plays it'}")
  end

  # Merges a frozen fight into the list: a fight already known keeps its fields and gains the held
  # keys it lacks, its own value winning a key both hold; a fight that ended for the world is refused.
  #
  # @param entry [Hash] The entry, read by decode.
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

    names = held.first(10).map { |kind, key, value| "#{kind == 2 ? "ss#{key.join('.')}" : "#{KIND_LETTERS[kind]}#{key}"} #{value.inspect}" }
    names.join(", ") + (held.size > 10 ? ", ..." : "")
  end

  # Reads an entry as the list's text would carry it, the fields of the player's own record and
  # what the text cannot carry left out.
  #
  # @param entry [Hash] The entry.
  # @return [Hash, nil] The entry, nil for one that is none.
  def self.clean(entry)
    return nil unless entry.is_a?(Hash)

    text = encode_entry(entry)
    text ? decode_entry(text) : nil
  end

  # Writes frozen fights as the list's text: the entries split by ";", each entry's fields by "|".
  #
  # @param entries [Array<Hash>] The entries.
  # @return [String] The text.
  def self.encode(entries)
    entries.map { |entry| encode_entry(entry) }.compact.join(";")
  end

  # Reads the troop of an entry of the list's text that tells its fight ended, see ENDED.
  #
  # @param text [String] The entry.
  # @return [Integer, nil] The troop, nil for an entry that tells no end.
  def self.ended_troop(text)
    return nil unless text =~ /\A(\d{1,10})\|#{ENDED}\z/

    troop = read_integer($1)
    troop && troop > 0 ? troop : nil
  end

  # Writes one frozen fight: troop, site, outer site, scene, the tableau's map, rows and blocked
  # events, the starter's spot and the held keys.
  #
  # @param entry [Hash] The entry.
  # @return [String, nil] The text, nil for an entry that is none or longer than the relay keeps.
  def self.encode_entry(entry)
    site = entry["site"].to_s
    outer = entry["outer"].to_s
    return nil unless site =~ SITE_KEY && outer =~ SITE_KEY

    map, rows, blocked = entry["tableau"]
    rows = rows.map { |row| encode_row(row) }
    return nil if rows.include?(nil)

    spot = entry["spot"].map { |value| written_integer(value) }
    held = entry["held"].map { |item| encode_held(item) }.compact
    fields = [site, outer, entry["scene"] ? 1 : 0, written_integer(map), rows.join(","),
              blocked.map { |id| written_integer(id) }.join("."), spot.join("."), held.join(",")].join("|")
    if fields.size > MAX_ENTRY_LENGTH
      return log_once([:long, entry["troop"]], "left the frozen fight against troop #{entry['troop']} out: #{fields.size} characters, more than the relay keeps")
    end

    "#{written_integer(entry['troop'])}|#{fields}"
  rescue => e
    log_once([:encode, e.class], "writing a frozen fight failed: #{e.class}: #{e.message}")
    nil
  end

  # Writes a sprite row, its character name escaped.
  #
  # @param row [Array] The row, see battles_raid_freeze.rbx.
  # @return [String, nil] The text, nil for a row that is none.
  def self.encode_row(row)
    return nil unless row.is_a?(Array) && row.size == ROW_SIZE

    row.each_with_index.map { |value, place| place == ROW_NAME ? escape(value.to_s) : written_integer(value).to_s }.join(":")
  end

  # Writes a held key: a switch as s<id>~T or ~F, a variable as v<id>~ and its escaped value, a self
  # switch as x<map>.<event>.<escaped letter>~T or ~F.
  #
  # @param item [Array] The key as kind, key and value.
  # @return [String, nil] The text, nil for a variable whose value no story carries, such as a list.
  def self.encode_held(item)
    kind, key, value = item
    case kind
    when 0 then "s#{written_integer(key)}~#{value ? 'T' : 'F'}"
    when 1
      written = MGQ_MpStoryState.encode_value(value.nil? ? 0 : value)
      return log_once([:unsent, key], "left the held variable v#{key} out: its value is no kind the story carries") if written.empty?

      "v#{written_integer(key)}~#{escape(written)}"
    when 2 then "x#{written_integer(key[0])}.#{written_integer(key[1])}.#{escape(key[2].to_s)}~#{value ? 'T' : 'F'}"
    end
  end

  # Writes an integer for the list's text.
  #
  # @param value [Object] The value.
  # @return [Integer] The integer.
  # @raise [ArgumentError] For a value that is no integer within MAX_INTEGER.
  def self.written_integer(value)
    raise ArgumentError, "#{value.inspect} is no integer the list carries" unless value.is_a?(Integer) && value.abs <= MAX_INTEGER

    value
  end

  # Escapes a free text: each byte outside PLAIN_BYTE as %XX, so no separator of the list's text
  # appears in it.
  #
  # @param text [String] The text.
  # @return [String] The escaped text, of plain ASCII.
  def self.escape(text)
    text.dup.force_encoding("ASCII-8BIT").gsub(PLAIN_BYTE) { |byte| format("%%%02X", byte.ord) }.force_encoding("UTF-8")
  end

  # Reads an escaped text, see escape.
  #
  # @param text [String] The escaped text.
  # @return [String, nil] The text, nil for a text that is not escaped so or no valid UTF-8.
  def self.unescape(text)
    return nil unless text =~ ESCAPED

    plain = text.dup.force_encoding("ASCII-8BIT").gsub(/%([0-9A-Fa-f]{2})/n) { [$1.hex].pack("C") }.force_encoding("UTF-8")
    plain.valid_encoding? ? plain : nil
  end

  # Reads frozen fights of the list's text, see encode, dropping and logging those it cannot read
  # and those past MAX_ENTRIES, and leaving out those that ended (see ended_troop).
  #
  # @param text [String] The text.
  # @return [Array<Hash>] The entries.
  def self.decode(text)
    entries = []
    text.to_s.split(";").each do |part|
      next if ended_troop(part)

      if entries.size >= MAX_ENTRIES
        log_once([:too_many, part[0, 40]], "dropped the frozen fights past the first #{MAX_ENTRIES} the world's story carries")
        break
      end

      entry = decode_entry(part)
      next entries << entry if entry

      log_once([:broken, part.hash], "dropped a frozen fight the world's story carries that this game cannot read: #{MGQ_MpLog.short(part, 120)}")
    end
    entries
  end

  # Reads one frozen fight, see encode_entry.
  #
  # @param text [String] The text.
  # @return [Hash, nil] The entry, nil for a text that is none or a troop that is no boss.
  def self.decode_entry(text)
    fields = text.split("|", -1)
    return nil unless fields.size == ENTRY_FIELDS

    troop = read_integer(fields[0])
    return nil unless troop && troop > 0 && defined?(MGQ_MpRaidBosses) && MGQ_MpRaidBosses.boss?(troop)
    return nil unless fields[1] =~ SITE_KEY && fields[2] =~ SITE_KEY && %w(0 1).include?(fields[3])

    map = read_integer(fields[4])
    rows = fields[5].split(",", -1).map { |row| decode_row(row) }
    return nil unless map && rows.size.between?(1, MAX_ROWS) && !rows.include?(nil) && rows.count { |row| row[ROW_FLAGS[0]] == 1 } == 1

    blocked = fields[6].split(".", -1).map { |id| read_integer(id) }
    spot = fields[7].split(".", -1).map { |value| read_integer(value) }
    held = fields[8].split(",", -1).map { |item| decode_held(item) }
    return nil if blocked.include?(nil) || spot.size != 4 || spot.include?(nil) || held.size > MAX_HELD || held.include?(nil)

    { "troop" => troop, "site" => fields[1], "outer" => fields[2], "scene" => fields[3] == "1", "tableau" => [map, rows, blocked], "spot" => spot, "held" => held }
  rescue
    nil
  end

  # Reads a sprite row, see encode_row.
  #
  # @param text [String] The text.
  # @return [Array, nil] The row, nil for a text that is none.
  def self.decode_row(text)
    fields = text.split(":", -1)
    return nil unless fields.size == ROW_SIZE

    row = fields.each_with_index.map { |field, place| place == ROW_NAME ? unescape(field) : read_integer(field) }
    return nil if row.include?(nil) || ROW_FLAGS.any? { |place| row[place] != 0 && row[place] != 1 }

    row
  end

  # Reads a held key, see encode_held.
  #
  # @param text [String] The text.
  # @return [Array, nil] The key as kind, key and value, nil for a text that is none.
  def self.decode_held(text)
    return nil unless text =~ /\A([svx])([^~]*)~(.*)\z/

    letter = $1
    key = $2
    value = $3
    case letter
    when "s"
      id = read_integer(key)
      id && id > 0 && %w(T F).include?(value) ? [0, id, value == "T"] : nil
    when "v"
      id = read_integer(key)
      written = unescape(value)
      read = written && !written.empty? ? MGQ_MpStoryState.decode_value(written) : nil
      id && id > 0 && !read.nil? && (!read.is_a?(String) || read.valid_encoding?) ? [1, id, read] : nil
    when "x"
      parts = key.split(".", -1)
      return nil unless parts.size == 3 && %w(T F).include?(value)

      map = read_integer(parts[0])
      event = read_integer(parts[1])
      self_letter = unescape(parts[2])
      map && event && self_letter && !self_letter.empty? ? [2, [map, event, self_letter], value == "T"] : nil
    end
  end

  # Reads an integer of the list's text.
  #
  # @param text [String] The text.
  # @return [Integer, nil] The integer, nil for a text that is none or past MAX_INTEGER.
  def self.read_integer(text)
    return nil unless text =~ INTEGER

    value = text.to_i
    value.abs <= MAX_INTEGER ? value : nil
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  MGQ_MpHooks.before(Scene_Title, :start, "world_freeze") { MGQ_MpWorldFreeze.forget }
rescue => e
  MGQ_MpWorldFreeze.log("hooks FAILED: #{e.class}: #{e.message}")
end
