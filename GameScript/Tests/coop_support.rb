#----------------------------------------------------------------
#  coop_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Stood in for the joins the live session holds
#                            - Stood in for asking a running battle and joining one by choice
#                            - Handed co-op messages over as the DLL's routes do
#                            - Stood in for the matchmaking over the tests' world
#                            - Stood in for the widths a request tells, kept for its battle
#                            - Stood in for the battle's level, the roster's lines, the troop's repair and the departures
#                            - Created
#
#----------------------------------------------------------------

# What the tests of the co-op battles share, which battle_support.rb loads: the DLL's and the
# battle server core's side of the co-op battles (MGQOnline.Game's Coop folder, behind CoopTopics)
# on the test's one stand-in bridge. CoopStandIn answers the topics as C# does and is checked
# against the golden cases of fixtures/coop, which battles_coop*.rbx played before the rules left
# them, as this file loads; the roster's lines are written and read with the battle line codec of
# battles_sync_wire.rbx, which a test loads before it asks.

require "json"

# Folder of the co-op battles' golden cases.
COOP_FIXTURES = File.expand_path("../../fixtures/coop", __dir__)

# Reads a golden file of the co-op battles.
#
# @param name [String] The file, such as "placement.json".
# @return [Hash] Its content.
def coop_cases(name)
  JSON.parse(File.read(File.join(COOP_FIXTURES, name), :encoding => "UTF-8"))
end

# Stands in for the co-op battles' rules in C#, each topic's request in, its reply out.
module CoopStandIn
  # The enemies a troop holds at most.
  TROOP_LIMIT = 8

  # The share of the narrower of two pictures that may hide behind the other.
  MAX_OVERLAP = 0.5

  # The pixels between two places an added enemy may stand at.
  PLACE_STEP = 8

  # The players a battle holds at most.
  PLAYERS = 4

  # The widest picture a request may tell.
  MAX_WIDTH = 65535

  # The widths the requests to join a battle told, by enemy id, and that battle's id.
  @widths = {}
  @battle = nil

  # Answers a topic.
  #
  # @param topic [String] The topic, such as "coop.place".
  # @param request [Object] The request.
  # @return [Object] The reply.
  def self.answer(topic, request)
    case topic
    when "coop.place" then place_first(request)
    when "coop.write_widths" then request.map { |id, width| "#{id}:#{width}" }.join(";")
    when "coop.read_entries" then read_entries(request)
    when "coop.write_entries" then request.map { |entry| entry.first(4).join(":") }.join(";")
    when "coop.intake" then intake(request)
    when "coop.room" then closed(request) ? 0 : players_in(request)
    when "coop.level" then level(request)
    when "coop.write_roster" then wire.line(request.key?("turn") ? request.values_at("enemies", "players", "level", "turn") : request.values_at("enemies", "players", "level"))
    when "coop.write_party" then wire.line([request])
    when "coop.read_roster" then read_roster(request)
    when "coop.read_party" then read_players(Array(wire.parse(request.to_s))[0])
    when "coop.read_troop" then read_troop(request)
    when "coop.repair" then repair(request["enemies"], request)
    when "coop.settle" then settle(request)
    end
  end

  # The battle line codec.
  #
  # @return [Module] MGQ_MpBattlesSync::Wire.
  def self.wire
    MGQ_MpBattlesSync::Wire
  end

  # Answers coop.level.
  #
  # @param request [Hash] The request.
  # @return [Hash] The level and its log line.
  def self.level(request)
    return { "level" => nil, "log" => "no level: a Raid World's battles sync none" } if request["raid"]

    leader = request["players"].find { |player| player[1] }
    return { "level" => nil, "log" => "no level: the party leader is not among the battle's players (seats #{request['players'].map(&:first).join(', ')})" } unless leader

    levels = leader[2].map { |place| leader[3][place] }.compact
    { "level" => levels.max, "log" => "level #{levels.max.inspect}: the highest of the leader's (seat #{leader[0]}) characters in the battle, at levels #{levels.join(', ')}" }
  end

  # Answers coop.read_roster.
  #
  # @param request [Hash] The request.
  # @return [Hash] The roster.
  def self.read_roster(request)
    enemies, players, level, turn = Array(wire.parse(request["line"].to_s))
    read_players(players).merge(repair(plain_enemies(enemies), request)).merge(
      "size" => Array(enemies).size, "level" => level.is_a?(Integer) ? level : nil, "turn" => turn.is_a?(Integer) ? turn : nil)
  end

  # Answers coop.read_troop.
  #
  # @param request [Hash] The request.
  # @return [Hash] The troop.
  def self.read_troop(request)
    entries, names = Array(wire.parse(request["line"].to_s))
    repair(plain_enemies(entries), request).merge("names" => names.is_a?(String) ? names : nil)
  end

  # Reads the players of a line, noting their fields of the wrong kind.
  #
  # @param list [Object] The players.
  # @return [Hash] "players" and "dropped".
  def self.read_players(list)
    dropped = []
    players = Array(list).map do |fields|
      seat, name, builds, vitals, max, order, front, bench = Array(fields).first(8)
      unless seat.is_a?(Integer)
        dropped << ["seat", seat.class.name, "a player's"]
        next nil
      end

      dropped << ["vitals", vitals.class.name, "a player's"] unless vitals.is_a?(Array)
      vitals = vitals.is_a?(Array) ? vitals.map { |entry| vitals_of(entry) } : []
      counts = { "max" => max, "order" => order, "front" => front, "bench" => bench }.map do |field, value|
        fits = field == "order" ? value.is_a?(Array) && value.all? { |place| place.is_a?(Integer) && place >= 0 } : value.is_a?(Integer) && value >= 0
        next value if value.nil? || fits

        dropped << [field, value.class.name, "a player's"]
        nil
      end
      [seat, name.to_s, builds.to_s, vitals] + counts
    end
    { "players" => players.compact, "dropped" => dropped }
  end

  # Reads a character's HP and MP as the battle takes them.
  #
  # @param entry [Object] The HP and MP.
  # @return [Array, nil] The numbers, others as nil; nil for none.
  def self.vitals_of(entry)
    return entry.map { |value| value.is_a?(Integer) ? value : nil } if entry.is_a?(Array)

    entry.is_a?(Integer) ? [entry] : nil
  end

  # Writes the host's enemies as the scripts hand them over, see MGQ_MpBattlesCoop.plain_enemies.
  #
  # @param enemies [Object] The enemies.
  # @return [Array] The enemies.
  def self.plain_enemies(enemies)
    Array(enemies).map { |entry| entry.is_a?(Array) ? Array.new(4) { |index| entry[index].is_a?(Integer) ? entry[index] : entry[index].class.name } : entry.class.name }
  end

  # Repairs the host's enemies against this game's troop.
  #
  # @param enemies [Array] The enemies, plain.
  # @param request [Hash] "own" and "count".
  # @return [Hash] "enemies", "enemy_dropped" and "lacking".
  def self.repair(enemies, request)
    dropped = []
    repaired = []
    enemies.each_with_index do |entry, index|
      return { "enemies" => nil, "enemy_dropped" => dropped << ["enemy", entry, "the host's troop for its"], "lacking" => [] } unless entry.is_a?(Array)
      return { "enemies" => nil, "enemy_dropped" => dropped << ["id", entry[0], "the host's troop for its enemy"], "lacking" => [] } unless entry[0].is_a?(Integer)

      x, y = request["own"][index] || [0, 0]
      fields = { "x" => x, "y" => y, "mark" => 0 }.each_with_index.map do |(field, fallback), offset|
        value = entry[offset + 1]
        next value if value.is_a?(Integer)

        dropped << [field, value, "the host's enemy"]
        fallback
      end
      repaired << [entry[0]] + fields
    end
    lacking = repaired.map(&:first).reject { |id| id > 0 && id < request["count"] }
    { "enemies" => lacking.empty? ? repaired : nil, "enemy_dropped" => dropped, "lacking" => lacking }
  end

  # Answers coop.settle.
  #
  # @param request [Hash] The request.
  # @return [Hash] Who stays, who left and what the host does.
  def self.settle(request)
    staying = request["players"].select { |seat| seat == request["own"] || request["in"].include?(seat) }
    outcome = if staying.size == request["players"].size then "none"
              elsif request["served"] && staying.empty? then "abandon"
              elsif !request["served"] && staying.size == 1 then "solo"
              else "reform"
              end
    { "staying" => staying, "left" => request["players"] - staying, "outcome" => outcome }
  end

  # Places the first of an encounter's enemies that still find a place, by the widths the battle
  # kept where it has them.
  #
  # @param request [Hash] The request of coop.place.
  # @return [Array<Array>] The enemies placed, [id, x, y] each.
  def self.place_first(request)
    bid = request["bid"].to_s
    note_widths(bid, request["widths"]) if request.key?("widths")
    width = lambda { |id, measured| bid == @battle && @widths.key?(id) ? @widths[id] : measured }
    request = { "screen" => request["screen"],
                "troop" => request["troop"].map { |id, x, measured, hidden, fallen| [x, width.call(id, measured), hidden, fallen] },
                "queued" => request["queued"].map { |id, x, measured| [x, width.call(id, measured)] },
                "entries" => request["entries"].map { |id, y, measured| [id, y, width.call(id, measured)] } }
    count = request["entries"].size
    count -= 1 until place(request, request["entries"].first(count)) || count == 0
    place(request, request["entries"].first(count)) || []
  end

  # Keeps the widths a request tells for its battle, forgetting those of another battle.
  #
  # @param bid [String] The battle's id.
  # @param text [String, nil] The widths, such as "31:160;32:600".
  def self.note_widths(bid, text)
    @widths = {} unless bid == @battle
    @battle = bid
    text.to_s.split(";").each do |entry|
      id, width = fields = entry.split(":").map(&:to_i)
      @widths[id] = width if fields.size == 2 && id > 0 && width > 0 && width <= MAX_WIDTH
    end
  end

  # Places every one of some enemies.
  #
  # @param request [Hash] The request of coop.place.
  # @param entries [Array<Array>] The enemies, [id, y, width] each.
  # @return [Array<Array>, nil] The enemies placed, nil when one finds none.
  def self.place(request, entries)
    screen = request["screen"]
    return nil if request["troop"].size + request["queued"].size + entries.size > TROOP_LIMIT

    taken = request["troop"].reject { |_, _, hidden, fallen| hidden || fallen }.map { |x, width| span(x, width) }
    taken.concat(request["queued"].map { |x, width| span(x, width) })
    taken.reject! { |left, right| right - left >= screen }
    entries.map do |id, y, width|
      next [id, screen / 2, y] if width >= screen

      x = free_x(width, taken, screen)
      return nil unless x

      taken << span(x, width)
      [id, x, y]
    end
  end

  # Finds the place where a picture hides least, the nearest to the middle among equals.
  #
  # @param width [Integer] The picture's width.
  # @param taken [Array<Array<Integer>>] The others' edges.
  # @param screen [Integer] The screen's width.
  # @return [Integer, nil] The picture's middle, nil when every place hides too much.
  def self.free_x(width, taken, screen)
    half = width / 2
    best = (half..(screen - half)).step(PLACE_STEP).to_a.min_by { |x| [crowding(x - half, x + half, taken), (x - screen / 2).abs] }
    best && crowding(best - half, best + half, taken) <= MAX_OVERLAP ? best : nil
  end

  # Measures how much a picture hides behind others, or they behind it.
  #
  # @param left [Integer] Its left edge.
  # @param right [Integer] Its right edge.
  # @param taken [Array<Array<Integer>>] The others' edges.
  # @return [Float] The largest share covered.
  def self.crowding(left, right, taken)
    taken.map do |other_left, other_right|
      overlap = [right, other_right].min - [left, other_left].max
      overlap > 0 ? overlap.to_f / [[right - left, other_right - other_left].min, 1].max : 0.0
    end.max || 0.0
  end

  # Tells a picture's edges.
  #
  # @param x [Integer] Its middle.
  # @param width [Integer] Its width.
  # @return [Array<Integer>] The edges.
  def self.span(x, width)
    [x - width / 2, x + width / 2]
  end

  # Reads the enemies a request carries.
  #
  # @param text [String] The enemies.
  # @return [Array<Array<Integer>>] Each enemy's fields.
  def self.read_entries(text)
    text.to_s.split(";").map { |entry| entry.split(":").map(&:to_i) }.select { |entry| entry.size == 4 && entry[0] > 0 }.first(TROOP_LIMIT)
  end

  # Counts the battle's players with those taken in.
  #
  # @param facts [Hash] The facts.
  # @return [Integer] The count.
  def self.players_in(facts)
    facts["players"] + facts["pending"].size
  end

  # Tells why the battle takes nobody in now.
  #
  # @param facts [Hash] The facts.
  # @return [Array<String>, nil] [code, reason], nil when it takes players in.
  def self.closed(facts)
    return ["pvp", "a PvP battle runs"] if facts["pvp"]

    running(facts, "choice", nil) || full(facts)
  end

  # Tells why the battle the player fights takes nobody in for what it is now.
  #
  # @param facts [Hash] The facts.
  # @param kind [String] "encounter" or "choice".
  # @param bid [String, nil] The battle a request with an encounter names.
  # @return [Array<String>, nil] [code, reason], nil when it takes players in.
  def self.running(facts, kind, bid)
    return ["closed", "the player fights no battle others may join"] unless facts["bid"]
    return ["closed", "the player is a guest of battle #{facts['bid']}"] unless facts["host"] == facts["own_seat"]
    return ["closed", "it asks for battle #{bid}, the player's is #{facts['bid']}"] if kind == "encounter" && bid.to_s != facts["bid"]
    return ["gathering", kind == "encounter" ? "the player's battle still gathers its players" : "the battle still gathers its players"] if facts["live"] && !facts["active"]
    return ["closed", "the computer plays on for those who left"] if facts["live"] && facts["solo"]

    facts["ending"] ? ["ending", "the battle ends"] : nil
  end

  # Tells whether the battle is full.
  #
  # @param facts [Hash] The facts.
  # @return [Array<String>, nil] [code, reason], nil while it has room.
  def self.full(facts)
    count = players_in(facts)
    count >= PLAYERS ? ["full", "#{count} players fight, as many as a battle takes"] : nil
  end

  # Tells why the battle cannot take in a player it knows.
  #
  # @param facts [Hash] The facts.
  # @param seat [Integer] The player's seat.
  # @param pending [String] The reason for one taken in already.
  # @return [Array<String>, nil] [code, reason], nil for one it does not know.
  def self.known(facts, seat, pending)
    return ["closed", "its player was in this battle before"] if facts["role"] && facts["seats"].include?(seat)

    facts["pending"].include?(seat) ? ["closed", pending] : nil
  end

  # Answers coop.intake.
  #
  # @param request [Hash] The request.
  # @return [Hash] The refusal, and for an encounter the players kept and left out and the room.
  def self.intake(request)
    facts = request["facts"]
    seat = request["seat"]
    return { "refusal" => choice_refusal(facts, seat, request) } if request["kind"] == "choice"

    refusal = running(facts, "encounter", request["bid"]) ||
              (facts["boss"] ? ["closed", "the player's battle is a boss battle"] : nil) ||
              (request["boss_troop"] ? ["closed", "the encounter's troop #{request['troop']} is a boss"] : nil) ||
              known(facts, seat, "its player is already taken in with another encounter") || full(facts)
    known_seats = (facts["role"] ? facts["seats"] : []) + facts["pending"] + [facts["own_seat"], seat]
    seats = [seat] + (request["seats"].to_s.split(",").map(&:to_i) - known_seats)
    room = PLAYERS - players_in(facts)
    kept = seats.first([room, 1].max)
    { "refusal" => refusal, "kept" => kept, "left" => seats - kept, "room" => room }
  end

  # Tells why the battle cannot take in a player who asks by choice.
  #
  # @param facts [Hash] The facts.
  # @param seat [Integer] The player's seat.
  # @param request [Hash] The request.
  # @return [Array<String>, nil] [code, reason], nil when it can.
  def self.choice_refusal(facts, seat, request)
    found = closed(facts)
    return found if found
    return ["closed", "it asks for battle #{request['bid']}, the player's is #{facts['bid']}"] unless request["bid"].to_s == facts["bid"]
    return ["closed", "it asks from map #{request['map']}, the player's is #{facts['map']}"] unless request["map"].to_i == facts["map"]

    known(facts, seat, "its player is taken in already")
  end
end

coop_cases("placement.json")["cases"].each do |entry|
  request = { "bid" => "golden", "troop" => entry["troop"].map { |spot| [0] + spot }, "queued" => entry["queued"], "entries" => entry["entries"], "screen" => entry["screen"] }
  raise "the placement stand-in differs at #{entry['name']}" unless CoopStandIn.place_first(request) == entry["placed"]
end
coop_cases("entries.json").tap do |cases|
  cases["reads"].each { |entry| raise "the entries stand-in reads #{entry['text'].inspect} otherwise" unless CoopStandIn.read_entries(entry["text"]) == entry["entries"] }
  cases["writes"].each { |entry| raise "the entries stand-in writes #{entry['entries'].inspect} otherwise" unless CoopStandIn.answer("coop.write_entries", entry["entries"]) == entry["text"] }
end
coop_cases("intake.json")["cases"].each do |entry|
  asked = entry["request"].merge("facts" => entry["facts"])
  encounter = CoopStandIn.intake(asked.merge("kind" => "encounter"))
  found = [encounter["refusal"] && encounter["refusal"][1], encounter["kept"], encounter["left"], encounter["room"],
           CoopStandIn.intake(asked.merge("kind" => "choice"))["refusal"], CoopStandIn.answer("coop.room", entry["facts"])]
  raise "the intake stand-in differs at #{entry['name']}" unless found == [entry["hot"], entry["kept"], entry["left"], entry["room"], entry["pick"], entry["rbn"]]
end

# Writes the log lines of fields left out as the scripts write them, each field and kind once, and
# the line of the enemies this game lacks.
#
# @param answer [Hash] The answer.
# @param key [String] The field of the notes, "dropped" or "enemy_dropped".
# @return [Array<String>] The lines.
def coop_logged(answer, key)
  lines = answer[key].uniq { |field, kind, _| [field, kind] }.map { |field, kind, owner| "co-op battle: dropped #{owner} #{field} another game sent as #{kind}" }
  lacking = Array(answer["lacking"])
  key == "enemy_dropped" && !lacking.empty? ? lines + ["co-op battle: the host's troop holds enemies this game lacks (#{lacking.join(', ')}); it keeps its own"] : lines
end

# Checks the roster's stand-ins against their golden cases; needs the battle line codec.
def check_roster_stand_in
  cases = coop_cases("roster.json")
  cases["levels"].each do |entry|
    players = entry["players"].map { |seat, leads, levels, places| [seat, leads, places, levels] }
    answer = CoopStandIn.answer("coop.level", "raid" => entry["raid"], "players" => players)
    raise "the level stand-in differs at #{entry['name']}" unless [answer["level"], "level sync: #{answer['log']}"] == [entry["level"], entry["logs"][0]]
  end
  cases["rosters"].each do |entry|
    answer = CoopStandIn.answer("coop.read_roster", entry)
    players = entry["players"].map { |player| player.each_with_index.map { |field, index| index == 3 ? field.map { |vitals| CoopStandIn.vitals_of(vitals) } : field } }
    found = [answer["players"], coop_logged(answer, "dropped"), answer["enemies"], coop_logged(answer, "enemy_dropped"), answer["level"], answer["turn"], answer["size"]]
    raise "the roster stand-in differs at #{entry['name']}" unless found == [players, entry["player_logs"], entry["repaired"], entry["repair_logs"], entry["level"], entry["turn"], entry["enemies_size"]]
  end
  cases["troops"].each do |entry|
    answer = CoopStandIn.answer("coop.read_troop", entry)
    raise "the troop stand-in differs at #{entry['name']}" unless [answer["enemies"], coop_logged(answer, "enemy_dropped"), answer["names"]] == [entry["repaired"], entry["repair_logs"], entry["names"]]
  end
  cases["writes"].each do |entry|
    written = entry["kind"] == "party" ? CoopStandIn.answer("coop.write_party", entry["players"]) : CoopStandIn.answer("coop.write_roster", entry.reject { |key, _| %w(kind line).include?(key) })
    raise "the line stand-in differs at #{entry['kind']}" unless written == entry["line"]
  end
end

# The co-op topics CoopStandIn answers.
COOP_TOPICS = %w(coop.place coop.write_widths coop.read_entries coop.write_entries coop.intake coop.room coop.level coop.write_roster coop.write_party coop.read_roster
                 coop.read_party coop.read_troop coop.repair coop.settle)

require_relative "match_support"
require_relative "ask_support"

# Stands in for the joins of a co-op battle the DLL takes from the live battle's session
# (MGQOnline.Game's CoopJoins, behind CoopTopics): the host's gathering, a guest's wait for the
# roster and the host's players taken into its running battle, over the live session's stand-in.
class CoopJoinsStandIn
  # Seconds the host keeps the players it took in waiting for them to join.
  WAIT_SECONDS = 60

  # The topics the stand-in answers.
  TOPICS = %w(coop.gather coop.roster_wait coop.pending)

  # The encounters and players taken in who have not all joined yet: :requester, :seats, :enemies,
  # :at and :added each.
  attr_reader :entries

  # Makes the joins over a live session's stand-in.
  #
  # @param session [LiveSessionStandIn, nil] The session, whose messages hold the joins; nil for a
  #   test without live battles, whose session holds none.
  def initialize(session)
    @session = session
    @entries = []
    @gathering = nil
    @roster_frames = 0
    @roster_limit = 0
  end

  # Answers a topic.
  #
  # @param topic [String] The topic.
  # @param request [Hash] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    case topic
    when "coop.gather" then gather(request)
    when "coop.roster_wait" then roster_wait(request)
    when "coop.pending" then pending(request)
    end
  end

  # @return [Array<Integer>] The seats of the players taken in who have not joined yet.
  def pending_seats
    seats
  end

  private

  # Takes the oldest message of a kind from a sender.
  #
  # @param kind [String] The kind.
  # @param seat [Integer, nil] The sender, nil for any.
  # @return [Array, nil] The message.
  def take(kind, seat = nil)
    @session && @session.taken([kind], seat)
  end

  # Answers a step of the gathering, as CoopJoins' gathering does.
  #
  # @param request [Hash] The step.
  # @return [Object] The answer.
  def gather(request)
    case request["op"]
    when "start"
      @gathering = { :invited => Array(request["seats"]), :limit => request["limit"], :joined => [], :outcomes => {}, :frames => 0 }
      nil
    when "frame"
      gather = @gathering
      return true unless gather

      gather[:invited].each do |seat|
        next if gather[:outcomes].key?(seat)

        if (joined = take("join", seat))
          gather[:joined] << [seat, joined[1]]
          gather[:outcomes][seat] = "joined (#{joined[1].to_s.size} bytes)"
        elsif take("decline", seat)
          gather[:outcomes][seat] = "declined"
        elsif Array(request["gone"]).include?(seat)
          gather[:outcomes][seat] = "left the world"
        end
      end
      gather[:frames] += 1
      gather[:outcomes].size == gather[:invited].size || gather[:frames] >= gather[:limit]
    else
      gather = @gathering || { :invited => [], :joined => [], :outcomes => {}, :frames => 0 }
      @gathering = nil
      { "joined" => gather[:joined], "outcomes" => gather[:invited].map { |seat| [seat, gather[:outcomes][seat]] }, "frames" => gather[:frames] }
    end
  end

  # Answers a step of a guest's wait for the roster, as CoopJoins.RosterFrame does.
  #
  # @param request [Hash] The step.
  # @return [Hash, nil] The answer.
  def roster_wait(request)
    if request["op"] == "start"
      @roster_frames = 0
      @roster_limit = request["limit"]
      return nil
    end

    @roster_frames += 1
    if request["restart"]
      @roster_frames = 0
      @roster_limit = request["restart"]
    end
    roster = take("roster")
    { "roster" => roster && roster[1], "late" => roster.nil? && @roster_frames >= @roster_limit, "frames" => @roster_frames }
  end

  # Answers a step of the list of the players taken in, as CoopJoins does.
  #
  # @param request [Hash] The step.
  # @return [Object] The answer.
  def pending(request)
    case request["op"]
    when "take_in"
      @entries << { :requester => request["requester"], :seats => Array(request["seats"]).dup, :enemies => Array(request["enemies"]).dup, :at => Time.now,
                    :added => false }
      nil
    when "release"
      seat = request["seat"]
      dropped = []
      @entries.each do |entry|
        next if entry[:requester] == seat || !entry[:seats].include?(seat)

        drop(entry, seat)
        dropped << [seat, "they ask with their own encounter"]
      end
      @entries.reject! { |entry| entry[:seats].empty? }
      dropped
    when "expire" then expire(Array(request["gone"]))
    when "joins" then seats.map { |seat| (joined = take("join", seat)) && [seat, joined[1]] }.compact
    when "next_added"
      entry = @entries.find { |candidate| !candidate[:added] && Array(request["seats"]).include?(candidate[:requester]) }
      entry && (entry[:added] = true) && entry[:enemies]
    when "remove"
      @entries.each { |entry| entry[:seats] -= Array(request["seats"]) }
      @entries.reject! { |entry| entry[:seats].empty? }
      nil
    when "take_off"
      entry = @entries.find { |candidate| candidate[:requester] == request["seat"] && candidate[:seats].include?(request["seat"]) }
      return false unless entry

      drop(entry, request["seat"])
      @entries.reject! { |candidate| candidate[:seats].empty? }
      true
    when "call_off"
      called = seats
      @entries = []
      called
    when "queued" then @entries.reject { |entry| entry[:added] }.map { |entry| entry[:enemies] }.flatten(1)
    when "count" then @entries.size
    else seats
    end
  end

  # @return [Array<Integer>] The seats of the players taken in who have not joined yet.
  def seats
    @entries.map { |entry| entry[:seats] }.flatten
  end

  # Forgets the players taken in who are done, as CoopJoins.Expire does.
  #
  # @param gone [Array<Integer>] The players the world no longer knows.
  # @return [Array<Array>] Each forgotten seat, why, and whether they are told it is off.
  def expire(gone)
    dropped = []
    @entries.each do |entry|
      entry[:seats].dup.each do |seat|
        reason = if take("decline", seat) then "turned the invite down or stopped waiting"
                 elsif take("leave", seat) then "left the battle"
                 elsif gone.include?(seat) then "left the world"
                 elsif Time.now - entry[:at] > WAIT_SECONDS then "did not join within #{WAIT_SECONDS} s"
                 end
        next unless reason

        drop(entry, seat)
        dropped << [seat, reason, reason.start_with?("did not")]
      end
    end
    @entries.reject! { |entry| entry[:seats].empty? }
    dropped
  end

  # Forgets a player taken in and their join.
  #
  # @param entry [Hash] The encounter they came with.
  # @param seat [Integer] Their seat.
  def drop(entry, seat)
    entry[:seats].delete(seat)
    entry[:enemies] = [] if seat == entry[:requester]
    take("join", seat)
  end
end

# The world of the script tests as the matchmaking stand-in reads it: the world room's stand-ins,
# their sends and log, the notification box's messages as the DLL's events on the stand-in bridge,
# and the time and randomness of the process.
class TestMatchWorld
  # @return [Boolean] Whether a world is open.
  def in_world?; MGQ_MpOverworldSync.in_world?; end
  # @return [Boolean] Whether it is a Raid World.
  def raid?; MGQ_MpCoop::Scope.raid?; end
  # @return [Integer] The player's seat.
  def own_seat; MGQ_MpOverworldSync::Me.seat; end
  # @return [Integer] When the player entered the map.
  def own_since; MGQ_MpOverworldSync::Me.map_since.to_i; end
  # @return [String] The player's id.
  def own_id; MGQ_MpOverworldSync::Me.id.to_s; end
  # @return [Array] The other players.
  def peers; MGQ_MpOverworldSync::Peers.all; end
  # @return [String, nil] The party's id.
  def party_id; MGQ_MpCoop::Party.id; end
  # @return [Array] The party's other members.
  def members; MGQ_MpCoop::Party.members; end
  # @return [Boolean] Whether the player plays in a party with someone else.
  def in_party?; MGQ_MpCoop.in_party?; end
  # @return [Object] The party's leader: :me, a player or nil.
  def leader; MGQ_MpCoop::Party.leader; end
  # Finds a player by seat.
  def at(seat); MGQ_MpOverworldSync::Peers.at(seat); end
  # Sends a message of the world room.
  def send(seat, fields); MGQ_MpOverworldSync.tell(seat, Hash[fields]); end
  # Writes a log line.
  def log(line); MGQ_Multiplayer::Log.write(line); end
  # Posts a message for the notification box, which the next frame hands to the scripts.
  def notice(key, seat, text, frames); $world_bridge.post("coop.notice", "key" => key, "seat" => seat, "text" => text, "frames" => frames); end
  # Posts a message taken away, which the next frame hands to the scripts.
  def drop_notice(key, seat, reason); $world_bridge.post("coop.drop_notice", "key" => key, "seat" => seat, "reason" => reason); end
  # @return [Float] The clock in seconds.
  def now; Time.now.to_f; end
  # @return [Float] A number of 0 to below 1.
  def rand; Kernel.rand; end
  # @return [String] A new battle id.
  def new_id; MGQ_MpCoop.random_id(8); end
end

# Answers the co-op topics with CoopStandIn, its roster checked once the battle line codec is there,
# the matchmaking's with a MatchStandIn over the tests' world, kept in $coop_match, the asking and
# joining sides' with an AskStandIn beside it, kept in $coop_ask, and the joins with a
# CoopJoinsStandIn over the live session's stand-in in $live, kept in $coop_joins.
#
# @param fake [FakeBridge] The bridge.
def answer_coop(fake)
  check_roster_stand_in if defined?(MGQ_MpBattlesSync::Wire)
  COOP_TOPICS.each { |topic| fake.answer(topic) { |request| CoopStandIn.answer(topic, with_pending(topic, request)) } }
  $coop_match = MatchStandIn.new(TestMatchWorld.new)
  $coop_ask = AskStandIn.new($coop_match)
  $coop_match.asks = $coop_ask
  MatchStandIn::TOPICS.each { |topic| fake.answer(topic) { |request| $coop_match.answer(topic, request) } }
  AskStandIn::TOPICS.each { |topic| fake.answer(topic) { |request| $coop_ask.answer(topic, request) } }
  $coop_joins = CoopJoinsStandIn.new($live && $live.session)
  CoopJoinsStandIn::TOPICS.each { |topic| fake.answer(topic) { |request| $coop_joins.answer(topic, request) } }
end

# Adds the players taken in, which the DLL's intake reads from its joins, to the battle's facts of a
# request that leaves them out, as the scripts' facts do.
#
# @param topic [String] The topic.
# @param request [Object] The request.
# @return [Object] The request, with the players taken in.
def with_pending(topic, request)
  pending = $coop_joins ? $coop_joins.pending_seats : []
  case topic
  when "coop.room" then request.key?("pending") ? request : request.merge("pending" => pending)
  when "coop.intake" then request["facts"].key?("pending") ? request : request.merge("facts" => request["facts"].merge("pending" => pending))
  else request
  end
end

# Hands a co-op message over as the DLL's routes do: the matchmaking's own kinds and the asking and
# joining sides' to the stand-ins, which read the player's facts of the frame, and whose status the
# scripts then take as the coop.status event brings it; the rest to the scripts' take, as the
# coop.message event does.
#
# @param peer [Object] Who sent it.
# @param message [Hash] The message, its kind under "coop".
# @param map [Boolean] Whether it came through the map's gate.
def coop_deliver(peer, message, map = false)
  $coop_match.answer("coop.frame", MGQ_MpBattlesCoop.facts)
  if AskStandIn::KINDS.include?(message["coop"].to_s) && (!map || $coop_match.instance_variable_get(:@world).raid?)
    $coop_ask.take_message(peer, message)
  elsif !$coop_match.route(peer, message, map)
    return MGQ_MpBattlesCoop.take(peer, message)
  end

  MGQ_MpBattlesCoop.take_status($coop_match.state)
  # The DLL's messages for the box reach the scripts as events of the next frame.
  MGQ_Multiplayer::Bridge.frame
end

# Hands a co-op message over that came through the map's gate, see coop_deliver.
#
# @param peer [Object] Who sent it.
# @param message [Hash] The message, its kind under "coop".
def coop_deliver_map(peer, message)
  coop_deliver(peer, message, true)
end
