#----------------------------------------------------------------
#  live_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Read and wrote lines with the codec's stand-in, took the recording's events and values and the Backline's Frontline as values and gave the stream's lines as values
#      Paulinchen  2026-10-30: Stood in for a co-op battle's side and stream kinds
#                            - Stood in for what every kind of live battle decides the same way
#                            - Stood in for the host's recording, held against its golden steps
#                            - Stood in for the command plan, a team duel's sides and the Backline's Frontlines
#                            - Stood in for the live battle's session, held against its golden cases
#                            - Created
#
#----------------------------------------------------------------

# The DLL's side of the live battle (MGQOnline.Game's Battles/Live folder, behind LiveTopics) for the
# script tests: LiveStandIn answers the live battle's topics as the DLL does, and
# check_live_stand_in holds it against the golden cases of fixtures/live, which battles_sync*.rbx
# played before the rules left them. It reads and writes lines with the codec's stand-in.

require "json"
require_relative "wire_support"

# Folder of the live battle's golden cases.
LIVE_FIXTURES = File.expand_path("../../fixtures/live", __dir__)

# Reads a golden file of the live battle.
#
# @param name [String] The file, such as "stream.json".
# @return [Hash] Its content.
def live_cases(name)
  JSON.parse(File.read(File.join(LIVE_FIXTURES, name), :encoding => "UTF-8"))
end

# Stands in for the live battle's session in the DLL (LiveSession and LiveVerdicts), each topic's
# request in, its reply out.
class LiveSessionStandIn
  # The ending checks between two looks at whether the other side is gone.
  GONE_CHECK_EVERY = 60

  # How many departures and joins told are kept.
  KEPT = 32

  # Why a live battle ends early, for the log.
  END_REASONS = { "left" => "this player left it", "forfeit" => "the other side forfeited", "broken" => "it broke off",
                  "gone" => "the other side is gone", "won" => "its enemies fell while it waited for commands" }

  # Makes a session without a battle.
  def initialize
    @role = nil
    @player = ""
    @kind = ""
    @team = false
    @seats = []
    @left = []
    @expected = []
    @bid = nil
    @solo = @broken = @served = @running = false
    @messages = []
    @gone_seats = []
    @told = []
    @ready = []
    @answered = []
    @checked = 0
    @gone = false
    @phase_open = false
    @told_waiting = nil
    @host_waiting = nil
  end

  # Answers a topic of the session.
  #
  # @param topic [String] The topic, such as "live.join".
  # @param request [Object] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    case topic
    when "live.join" then join(request)
    when "live.change" then change(request)
    when "live.players" then players(request)
    when "live.admit" then admit(request)
    when "live.receive" then receive(request)
    when "live.take" then take(request)
    when "live.pending" then @messages.count { |message| message[0] == request }
    when "live.tick" then tick(request)
    when "live.end" then ending(request)
    when "live.phase" then phase(request)
    when "live.departure" then tell(request)
    when "live.plan" then plan(request)
    when "live.team" then team(request)
    when "live.backline" then backline(request)
    when "live.record" then record(request)
    when "live.mode" then decided(request)
    else raise "no stand-in for #{topic}"
    end
  end

  # Answers what the kinds of live battle decide the same way.
  #
  # @param request [Hash] "op" with what it needs.
  # @return [Object] The answer.
  def decided(request)
    team = team?
    case request["op"]
    when "same_side" then coop? || (team && Array(@own).include?(request["seat"]))
    when "players" then team ? Array(@own) + Array(@other) : []
    when "heir" then team ? heir_of(request["seat"]) : nil
    when "gone" then team && !request["host"].nil? && staying(@other, request["host"]).empty?
    when "kinds" then coop? ? ["coop_party", "coop_troop"] : team ? ["team_heirs"] : @team_ids ? ["pvp_front"] : []
    end
  end

  # Answers a step of the host's recording, as RecorderBuffer does.
  #
  # @param request [Hash] "op" with what it needs.
  # @return [Hash] "sends", and the counts asked for.
  def record(request)
    case request["op"]
    when "start"
      @events, @values, @frame, @counts, @totals = [], {}, 0, [0, 0], [0, 0]
      { "sends" => [] }
    when "stop"
      left = Array(@events).size
      @events = []
      { "sends" => [], "events" => left }
    when "event" then { "sends" => recorded(wire.line(request["values"])) }
    when "values"
      @values = {} if request["full"]
      sends = request["battlers"].flat_map do |key, ref, values|
        line = wire.line(values)
        next [] if @values[key] == line

        @values[key] = line
        recorded(line.empty? ? "svalues\t@#{ref}" : "svalues\t@#{ref}\t#{line}")
      end
      { "sends" => sends }
    when "flush" then { "sends" => [flushed].compact }
    when "counts"
      counts = @counts
      @counts = [0, 0]
      { "sends" => [], "events" => counts[0], "sends_counted" => counts[1] }
    when "totals" then { "sends" => [], "events" => @totals[0], "sends_counted" => @totals[1] }
    end
  end

  # Records an event, letting what waits go once 200 do.
  #
  # @param line [String] The event.
  # @return [Array<String>] The sends due.
  def recorded(line)
    @events << line
    @counts[0] += 1
    @events.size >= 200 ? [flushed] : []
  end

  # Takes what waits as one send.
  #
  # @return [String, nil] The send, nil while nothing waits.
  def flushed
    return nil if Array(@events).empty?

    @counts[1] += 1
    @totals[0] += @events.size
    @totals[1] += 1
    send = @events.join("\n")
    @events = []
    send
  end

  # The battle line codec's stand-in.
  #
  # @return [Module] WireStandIn.
  def wire
    WireStandIn
  end

  # Plans a guest's commands, as CommandPlan does.
  #
  # @param request [Hash] "body", "seat", "several", "owners", "skills" and "items".
  # @return [Hash, nil] "places", nil for commands that do not read.
  def plan(request)
    values = wire.parse(request["body"])
    commands = values && values[0]
    return nil unless commands.is_a?(Array)

    places = request["owners"].each_with_index.map do |owner, place|
      seat = request["seat"]
      commanded = !request["several"] || (owner.is_a?(Integer) && seat && (owner == seat || (team? && heir_of(owner) == seat)))
      list = commands[place]
      commanded && list.is_a?(Array) ? list.map { |command| checked(command, request) } : nil
    end
    { "places" => places }
  end

  # Checks a command and the skills chained after it.
  #
  # @param command [Object] The command.
  # @param request [Hash] The tables' sizes.
  # @return [Array, nil] [kind, id, target, chain], nil for one the host cannot read.
  def checked(command, request)
    first = plain(command, request)
    return nil unless first
    return first + [nil] unless command.size > 3 && command[3].is_a?(Array)

    chain = []
    command[3].first(16).each do |link|
      break unless link.is_a?(Array) && link[0] == "skill" && (taken = plain(link, request))

      chain << taken + [nil]
    end
    first + [chain]
  end

  # Checks a command without its chain.
  #
  # @param command [Object] The command.
  # @param request [Hash] The tables' sizes.
  # @return [Array, nil] [kind, id, target], nil for one the host cannot read.
  def plain(command, request)
    return nil unless command.is_a?(Array)

    kind, id, target = command
    return nil unless id.is_a?(Integer) && target.is_a?(Integer) && target.between?(-1, 255)

    size = { "skill" => request["skills"], "item" => request["items"] }.fetch(kind, 0)
    id > 0 && id < size ? [kind, id, target] : nil
  end

  # Finds who commands the characters of a player who left.
  #
  # @param seat [Integer] The seat of who left.
  # @return [Integer, nil] Who took them over.
  def heir_of(seat)
    pair = Array(@heirs).find { |left, _| left == seat }
    pair && pair[1]
  end

  # Answers a step of a team duel's sides, as TeamSides does.
  #
  # @param request [Hash] "op" with what it needs.
  # @return [Hash] "heirs", "post", "broken" and "gone".
  def team(request)
    @heirs ||= []
    post = nil
    broken = false
    gone = false
    case request["op"]
    when "prepare"
      @own, @other, @same_team_side = request["own"], request["other"], request["same_side"]
      @heirs = []
    when "settle"
      changed = false
      [@own, @other].each do |side|
        staying = staying(side, request["host"])
        heir = staying.first
        side.each do |seat|
          known = @heirs.index { |left, _| left == seat }
          next if staying.include?(seat) || (known ? @heirs[known][1] : nil) == heir

          known ? @heirs[known] = [seat, heir] : @heirs << [seat, heir]
          changed = true
        end
      end
      post = wire.line([@heirs.reject { |_, heir| heir.nil? }.flatten]) if changed
    when "take"
      values = wire.parse(request["body"])
      pairs = Array(values && values[0]).each_slice(2).select { |pair| pair.size == 2 }
      seats, odd = pairs.partition { |pair| pair.all? { |seat| seat.is_a?(Integer) } }
      broken = values.nil? || !odd.empty?
      @heirs = Hash[seats].to_a
    when "gone" then gone = staying(@other, request["host"]).empty?
    end
    { "heirs" => @heirs.map(&:dup), "post" => post, "broken" => broken, "gone" => gone }
  end

  # Lists the players of a side still in the duel.
  #
  # @param side [Array<Integer>] The side's seats.
  # @param host [Integer] The host's seat.
  # @return [Array<Integer>] Their seats.
  def staying(side, host)
    Array(side).select { |seat| seat == host || guests_in.include?(seat) }
  end

  # Answers a step of the Backline's Frontlines, as BacklineFront does.
  #
  # @param request [Hash] "op" with what it needs.
  # @return [Hash] "front" and "unfit".
  def backline(request)
    case request["op"]
    when "begin"
      @team_ids = request["team"].dup
      @told_front = request["front"].dup
      { "front" => nil, "unfit" => nil }
    when "finish"
      @team_ids = @told_front = nil
      { "front" => nil, "unfit" => nil }
    when "take"
      ids = request["ids"]
      return { "front" => nil, "unfit" => nil } unless @team_ids && ids.is_a?(Array)

      front = ids.map { |id| id.is_a?(Integer) && @team_ids.include?(id) ? id : nil }
      unless front.size == request["troop"].size && !front.include?(nil) && front.uniq.size == front.size
        return { "front" => nil, "unfit" => "left out a Frontline that does not fit the other side's team: #{ids.inspect}" }
      end

      { "front" => front == request["troop"] ? nil : front, "unfit" => nil }
    when "settle"
      return { "front" => nil, "unfit" => nil } if @team_ids.nil? || request["front"] == @told_front

      @told_front = request["front"].dup
      { "front" => @told_front.dup, "unfit" => nil }
    end
  end

  # Writes the session as the scripts cache it.
  #
  # @return [Hash] The view.
  def view
    { "role" => @role, "player" => @player, "kind" => @kind, "team" => @team, "seats" => @seats.dup, "left" => @left.dup,
      "expected" => @expected.dup, "bid" => @bid, "solo" => @solo, "broken" => @broken, "served" => @served,
      "running" => @running, "behind" => pending_sends >= 4 }
  end

  # Counts the sends of the host's stream waiting.
  #
  # @return [Integer] The sends.
  def pending_sends
    @messages.count { |message| message[0] == "events" }
  end

  # Reports whether this game hosts the running battle.
  #
  # @return [Boolean] Whether it does.
  def host?
    !@role.nil? && @running && @role == "host"
  end

  # Reports whether the battle is a co-op battle.
  #
  # @return [Boolean] Whether it is.
  def coop?
    !@role.nil? && @kind == "coop"
  end

  # Reports whether the battle is a team duel.
  #
  # @return [Boolean] Whether it is.
  def team?
    !@role.nil? && @kind == "pvp" && @team
  end

  # Lists the guests still in the battle.
  #
  # @return [Array<Integer>] Their seats.
  def guests_in
    @seats - @left
  end

  # Makes the next battle live.
  #
  # @param request [Hash] The battle.
  # @return [Hash] The view.
  def join(request)
    running = @running
    @role, @player, @kind, @team = request["role"], request["player"], request["kind"], request["team"]
    @seats = request["seats"].dup
    @left = []
    @expected = []
    @bid = request["bid"]
    @solo = @broken = false
    @running = request["served"] && running
    @served = request["served"]
    @messages = []
    @checked = 0
    @gone = false
    @gone_seats = []
    view
  end

  # Changes the session.
  #
  # @param request [Hash] "op".
  # @return [Hash] The view with "done" and "logs".
  def change(request)
    logs = []
    done =
      case request["op"]
      when "start" then @running = !@role.nil?; true
      when "finish"
        if @role
          @gone_seats = []
          @role = nil
          @team = @broken = @running = @served = false
          true
        else
          false
        end
      when "break" then break_off
      when "gone" then @gone = true; logs << [nil, "the other side of the battle is gone"]; true
      end
    view.merge("done" => done, "logs" => logs)
  end

  # Breaks the battle off.
  #
  # @return [Boolean] Whether it broke off now.
  def break_off
    return false if @broken || @role.nil?

    @broken = true
  end

  # Changes the battle's players.
  #
  # @param request [Hash] "op" with "seats" or "seat".
  # @return [Hash] The view with "dropped", "left_now" and "still_in".
  def players(request)
    dropped = nil
    left = false
    case request["op"]
    when "expect" then @expected |= request["seats"]
    when "unexpect" then @expected -= request["seats"]
    when "keep"
      dropped = @seats - request["seats"]
      @seats = request["seats"].dup
    when "left" then left = guest_left(request["seat"])
    when "gone" then @gone_seats.concat(request["seats"])
    end
    view.merge("dropped" => dropped, "left_now" => left, "still_in" => guests_in.size)
  end

  # Notes a guest who left.
  #
  # @param seat [Integer] Their seat.
  # @return [Boolean] Whether they left now.
  def guest_left(seat)
    return false if @left.include?(seat)

    @left << seat
    true
  end

  # Checks a battle message before its sender is known.
  #
  # @param request [Hash] "channel", "bid", "kind" and "who".
  # @return [Array, false] The reason to leave it out, false to take it.
  def admit(request)
    shown = request["kind"][0, 40]
    if request["channel"]
      key = "served_dropped\t#{shown}\t#{@bid}"
      return [key, "ignored #{shown} from the battle channel: no served battle runs"] unless @served && @role
      return [key, "ignored #{shown} from the battle channel: it is for another battle"] unless request["bid"] == @bid

      return false
    end
    reason = @role.nil? ? "no live battle over the world runs" : request["bid"] != @bid ? "it is for another battle" : nil
    reason ? ["dropped\t#{shown}\t#{reason}\t#{@bid}", "ignored a battle message #{shown} from #{request['who']}: #{reason}"] : false
  end

  # Takes a message that arrived.
  #
  # @param request [Hash] "seat", "kind", "body" and "who".
  # @return [Hash] "logs" and "pending".
  def receive(request)
    seat, kind, body = request["seat"], request["kind"], request["body"]
    unless @seats.include?(seat) || @expected.include?(seat)
      return { "logs" => [["not_taken\t#{kind[0, 40]}\t#{seat}\t#{@bid}", "ignored #{kind[0, 40]} from #{request['who']}: #{@role == 'host' ? 'not a guest of this battle' : 'not the host'}"]],
               "behind" => pending_sends >= 4 }
    end

    @messages << [kind, body, seat]
    { "logs" => kind == "events" ? [] : [[nil, "received #{kind[0, 40]} (#{body.size} bytes) from #{request['who']}"]], "behind" => pending_sends >= 4 }
  end

  # Takes the oldest message of some kinds.
  #
  # @param request [Hash] "kinds" and "seat".
  # @return [Hash] "message" and "pending".
  def take(request)
    message = taken(request["kinds"], request["seat"])
    { "message" => message && message[0, 2], "behind" => pending_sends >= 4 }
  end

  # Takes the oldest message of some kinds, from one sender or any.
  #
  # @param kinds [Array<String>] The kinds.
  # @param seat [Integer, nil] The sender, nil for any.
  # @return [Array, nil] The message, nil for none.
  def taken(kinds, seat = nil)
    index = @messages.index { |message| kinds.include?(message[0]) && (seat.nil? || message[2] == seat) }
    index && @messages.delete_at(index)
  end

  # Checks whether the battle ends.
  #
  # @param request [Hash] "check", "in_world", "served_closed" and "gone".
  # @return [Hash] The view with "ending", "departed", "ask" and "logs".
  def tick(request)
    if request["check"] == "frame"
      @frame = @frame.to_i + 1
      return { "sends" => @frame % 10 == 0 ? [flushed].compact : [] }
    end

    @gone_seats.concat(request["gone"])
    departed = []
    logs = []
    ask = false
    ending =
      case request["check"]
      when "ending"
        if taken(["forfeit"])
          "forfeit"
        else
          logs << [nil, "the live battle broke off: #{@player}'s game broke it off"] if taken(["broken"]) && break_off
          if @broken
            "broken"
          else
            gone, ask = gone(request, departed, logs)
            gone
          end
        end
      when "gone" then gone, ask = gone(request, departed, logs); gone
      when "world" then gone, ask = world_gone(request, departed); gone ? "gone" : nil
      when "served" then served_gone(request, departed) ? "gone" : nil
      when "departures" then take_departures(departed); nil
      end
    view.merge("ending" => ending, "departed" => departed, "ask" => ask, "logs" => logs)
  end

  # Tells whether the other side is gone, looking every GONE_CHECK_EVERY checks.
  #
  # @param request [Hash] The facts.
  # @param departed [Array<Array>] Where the guests taken out go.
  # @param logs [Array<Array>] Where the lines logged go.
  # @return [Array] "gone" or nil, and whether the mode decides yet.
  def gone(request, departed, logs)
    return ["gone", false] if @gone

    @checked += 1
    return [nil, false] if @checked < GONE_CHECK_EVERY

    @checked = 0
    ask = false
    @gone = @role.nil? || (gone, ask = world_gone(request, departed); gone)
    logs << [nil, "the other side of the battle is gone"] if @gone
    [@gone ? "gone" : nil, ask && !@gone]
  end

  # Looks at who of a battle over the world's room is still in it.
  #
  # @param request [Hash] The facts.
  # @param departed [Array<Array>] Where the guests taken out go.
  # @return [Array] Whether the other side is gone, and whether the mode decides yet.
  def world_gone(request, departed)
    return [served_gone(request, departed), false] if @served && @role
    return [true, false] unless request["in_world"]

    take_departures(departed)
    [guests_in.empty?, host?]
  end

  # Looks at who of a battle the server hosts is still in it.
  #
  # @param request [Hash] The facts.
  # @param departed [Array<Array>] Where the guests taken out go.
  # @return [Boolean] Whether the other side is gone.
  def served_gone(request, departed)
    return true if request["served_closed"]
    return false unless host?

    take_departures(departed)
    guests_in.empty?
  end

  # Takes the guests who left out of the battle.
  #
  # @param departed [Array<Array>] Where they go, with the guests still in after each.
  def take_departures(departed)
    gone = @gone_seats
    @gone_seats = []
    guests_in.each do |seat|
      departed << [seat, guests_in.size] if (gone.include?(seat) || taken(["leave"], seat)) && guest_left(seat)
    end
  end

  # Tells how the battle ends.
  #
  # @param request [Hash] "of", with "reason" or "result", and "side".
  # @return [Hash] The ending.
  def ending(request)
    case request["of"]
    when "early"
      reason = request["reason"]
      verdict =
        case reason
        when "won" then { "process" => "win" }
        when "left" then { "process" => "forfeit" }
        when "forfeit" then { "process" => team? && request["side"] ? "process_defeat" : "process_victory", "message" => "#{@player} forfeited." }
        when "broken" then { "process" => "process_abort", "message" => "The battle broke off." }
        else { "process" => "gone" }
        end
      end_value(verdict).merge("reason" => END_REASONS.fetch(reason, reason))
    when "guest"
      result = request["result"]
      first = "the host's battle ended (#{result}), this game fought #{request['side'] ? "on the host's side" : 'against the host'}"
      verdict =
        if request["side"]
          %w(process_victory process_defeat).include?(result) ? { "process" => result } : { "process" => "take_over", "otherwise" =>
            end_value("process" => "process_abort", "log" => "the host left the team duel: it ends without a winner", "message" => "#{@player} left the duel.") }
        else
          case result
          when "process_victory" then { "process" => "process_defeat" }
          when "process_defeat" then { "process" => "process_victory" }
          else { "process" => "process_victory", "log" => "#{@player} gave up or left: this game wins", "message" => "#{@player} forfeited." }
          end
        end
      end_value(verdict).merge("first" => first)
    when "gone"
      if host? && coop?
        @solo = true
        return end_value("process" => "solo")
      end
      otherwise =
        if team? && (host? || request["side"])
          host? ? { "process" => "process_victory", "log" => "everyone on the other side left: the host's side wins", "message" => "Everyone on the other side left." } :
                  { "process" => "process_abort", "log" => "the host left the team duel: it ends without a winner", "message" => "#{@player} left the duel." }
        else
          { "process" => "process_victory", "log" => "#{@player} left: this game wins", "message" => "#{@player} left the battle." }
        end
      end_value("process" => "take_over", "otherwise" => end_value(otherwise))
    end
  end

  # Writes an ending with every field.
  #
  # @param fields [Hash] Its fields.
  # @return [Hash] "process", "log", "message" and "otherwise".
  def end_value(fields)
    { "process" => nil, "log" => nil, "message" => nil, "otherwise" => nil }.merge(fields)
  end

  # Answers a step of the host's waits.
  #
  # @param request [Hash] "op", with "seat" or "seats".
  # @return [Object] What the step answers.
  def phase(request)
    case request["op"]
    when "ready_reset" then @ready = []; nil
    when "ready" then { "all" => all_ready?, "not_ready" => guests_in - @ready, "behind" => pending_sends >= 4 }
    when "not_ready" then guests_in - @ready
    when "open"
      return false if @phase_open

      @phase_open = true
      @answered = []
      true
    when "close"
      open = @phase_open
      @phase_open = false
      @answered = []
      open
    when "unanswered" then guests_in - @answered
    when "answer" then @answered << request["seat"]; guests_in - @answered
    when "unanswer" then @answered -= request["seats"]; guests_in - @answered
    when "tell"
      seats = request["seats"].sort
      return nil if seats == @told_waiting

      @told_waiting = seats
      seats.join(",")
    when "forget" then @told_waiting = @host_waiting = nil
    when "host_waiting"
      taken = []
      while (message = taken(["waiting"]))
        @host_waiting = message[1].split(",").map(&:to_i)
        taken << @host_waiting
      end
      { "taken" => taken, "seats" => @host_waiting || [] }
    end
  end

  # Takes the guests' ready words.
  #
  # @return [Boolean] Whether every guest is ready.
  def all_ready?
    return !taken(["ready"]).nil? unless coop? || team?

    guests_in.each { |seat| @ready << seat if !@ready.include?(seat) && taken(["ready"], seat) }
    (guests_in - @ready).empty?
  end

  # Tells a departure or a join once.
  #
  # @param request [Hash] "seat" and "kind".
  # @return [Boolean] Whether to tell it.
  def tell(request)
    key = [@bid, request["seat"], request["kind"]]
    return false if @told.include?(key)

    @told << key
    @told.shift while @told.size > KEPT
    true
  end
end

# Stands in for the live battle's rules in the DLL, each topic's request in, its reply out.
class LiveStandIn
  # The longest wait taken from the host, in frames.
  MAX_WAIT = 600

  # The longest fade of music taken from the host, in milliseconds.
  MAX_FADE = 10_000

  # The scene's waits with a duration.
  TIMED_WAITS = %w(wait abs_wait)

  # The scene's waits until something ends.
  OPEN_WAITS = %w(wait_for_animation wait_for_effect wait_for_message)

  # The kinds the intake leaves as they are.
  PLAIN_KINDS = %w(commands end emerge item_used values time_stop turn battler.sprite_effect_type battler.animation_mirror choose_again)

  # A sound file of the Audio folder, its parts plain names.
  AUDIO_FILE = %r{\AAudio/(?:[A-Za-z0-9_\- ]+/)+[A-Za-z0-9_\- ]+(?:\.[A-Za-z0-9_\- ]+)*\z}

  # A speaker's name box of the translation's message system.
  NAME_BOX = /\\n[1-5cr]?<[^>]*>/i

  # The untranslated game's speaker line opening a message.
  NAME_LINE = /\A【[^】]*】/

  # Makes a stand-in of a game that set nothing up.
  def initialize
    @lists = Hash.new([])
    @name_box = true
    @animations = 0
    @swaps = {}
    @session = LiveSessionStandIn.new
  end

  # The stand-in of the live battle's session.
  #
  # @return [LiveSessionStandIn] The session.
  attr_reader :session

  # The battle line codec's stand-in.
  #
  # @return [Module] WireStandIn.
  def wire
    WireStandIn
  end

  # Answers a topic.
  #
  # @param topic [String] The topic, such as "live.take_stream".
  # @param request [Object] The request as the scripts hand it over.
  # @return [Object] The reply.
  def answer(topic, request)
    case topic
    when "live.guest_setup" then setup(request)
    when "live.take_stream" then take_stream(request)
    when "live.swap" then swap(request)
    else @session.answer(topic, request)
    end
  end

  # Sets the guest's intake up.
  #
  # @param request [Hash] "names", "own", "name_box", "lists" and "animations".
  # @return [Array<Array>] The log lines, [key, text] each.
  def setup(request)
    @lists = Hash.new([]).merge(request["lists"])
    @name_box = request["name_box"]
    @animations = request["animations"]
    @swaps = {}
    return [] unless request["names"]

    values = wire.parse(request["names"]) || []
    party, troop = [values[0], values[1]].map { |side| side.nil? ? [] : side.is_a?(Array) ? side : [side] }
    party.each_with_index { |name, place| pair(name, request["own"][0][place]) }
    troop.each_with_index { |name, place| pair(name, request["own"][1][place]) }
    [[nil, "the host names #{party.size} party and #{troop.size} troop characters; swapping " +
           (@swaps.empty? ? "none" : @swaps.map { |from, to| "#{from} -> #{to}" }.join(", "))]]
  end

  # Pairs a host's name with the guest's of the same place.
  #
  # @param name [Object] The host's name.
  # @param own [String, nil] The guest's.
  def pair(name, own)
    @swaps[name] = own if name.is_a?(String) && !name.empty? && own && name != own
  end

  # Takes one send of the host's stream.
  #
  # @param request [Hash] "body" and "seat".
  # @return [Hash] "lines", "events", "unreadable", "others_choose" and "logs".
  def take_stream(request)
    taken = { "lines" => [], "events" => 0, "unreadable" => 0, "others_choose" => 0, "logs" => [] }
    request["body"].split("\n").each do |line|
      values = wire_values(line)
      unless values && values[0].is_a?(String)
        taken["unreadable"] += 1
        taken["logs"] << ["unreadable_event", "left out an unreadable line of the host's stream (#{line.size} characters)"]
        next
      end

      taken["events"] += 1
      kind, *args = values
      if kind == "choose_again" && !Array(args[0]).include?(request["seat"])
        taken["others_choose"] += 1
        next
      end

      kept = checked(kind, args, line, taken["logs"])
      taken["lines"] << wire.parse(kept) if kept
    end
    taken
  end

  # Checks one event of the host's stream and swaps its names.
  #
  # @param kind [String] Its kind.
  # @param args [Array] Its values after the kind.
  # @param line [String] The line.
  # @param logs [Array<Array>] Where the reasons go.
  # @return [String, nil] The line the guest plays, nil to leave it out.
  def checked(kind, args, line, logs)
    return line if PLAIN_KINDS.include?(kind)

    method = kind.split(".", 2)[1].to_s
    case kind
    when "call" then call_checked(args, line, logs)
    when "popup" then replaced(line, 0 => args[0].is_a?(String) ? swap(args[0]) : nil)
    when "message" then args.size == 6 && args[5].is_a?(String) ? replaced(line, 5 => readable(swap_message(args[5]))) : line
    when "skill_name" then replaced(line, 1 => args[1].is_a?(String) ? swap(args[1]) : nil)
    when "animation" then args.size == 3 && (id = to_i(args[2])) && id >= 0 && !animation?(id) ? nil : line
    when "battler.animation_id" then args.size == 2 && (id = to_i(args[1])) && !animation?(id) ? nil : line
    when /\Alog\./
      @lists["log"].include?(method) ? replaced(line, Hash[args.each_index.map { |index| [index, args[index].is_a?(String) ? swap(args[index]) : nil] }]) : nil
    when /\Apicture\./
      refusal = @lists["picture"].include?(method) ? scene_refusal(kind, args) : "no such change"
      refused(logs, "picture\t#{method[0, 40]}\t#{refusal}",
              "left out the host's picture call #{method[0, 40]} with the arguments #{args.inspect[0, 80]}: #{refusal}") if refusal
      refusal ? nil : line
    when /\Ascreen\./
      return nil unless @lists["screen"].include?(method)

      refusal = scene_refusal(kind, args)
      refused(logs, "screen_args\t#{method}\t#{refusal}", "left out the host's screen call #{method} with the arguments #{args.inspect[0, 80]}: #{refusal}") if refusal
      refusal ? nil : line
    when /\Aaudio\./
      return nil unless @lists["audio"].include?(method)
      return line if audio_args?(method, args)

      refused(logs, "audio_args\t#{method}", "left out the host's audio call #{method} with the arguments #{args.inspect[0, 80]}")
    when /\Ascene\./
      return wire.line([kind]) if OPEN_WAITS.include?(method)

      frames = to_i(args[0])
      TIMED_WAITS.include?(method) && frames ? wire.line([kind, [frames, MAX_WAIT].min]) : nil
    else
      refused(logs, "unknown_event\t#{kind[0, 40]}", "left out the host's event #{kind[0, 40]}, which this game does not know")
    end
  end

  # Checks a call the guest makes itself.
  #
  # @param args [Array] The receiver, the method, the seed, who acts, the results, then the arguments.
  # @param line [String] The line.
  # @param logs [Array<Array>] Where the reason goes.
  # @return [String, nil] The line, nil to leave it out.
  def call_checked(args, line, logs)
    return line if args.size < 5

    receiver, name = args
    callable = (receiver == "log" && @lists["log_calls"].include?(name)) || (receiver == "scene" && @lists["scene_calls"].include?(name))
    callable ? line : refused(logs, "left_out\t#{receiver}\t#{name.to_s[0, 40]}", "left out the host's #{receiver} call #{name.to_s[0, 40]}")
  end

  # Notes why a line is left out.
  #
  # @param logs [Array<Array>] Where the reasons go.
  # @param key [String] What tells the reason from others.
  # @param text [String] The reason.
  # @return [nil] Always.
  def refused(logs, key, text)
    logs << [key, text]
    nil
  end

  # Tells what the story's scene refuses of a picture's or the screen's change, as the DLL does.
  #
  # @param kind [String] The change.
  # @param args [Array] Its arguments.
  # @return [String, nil] The refusal.
  def scene_refusal(kind, args)
    SceneStandIn.new.refusal(kind, args)
  end

  # Reports whether the arguments of an audio call read as the game's own.
  #
  # @param method [String] What the host called of Audio.
  # @param args [Array] Its arguments.
  # @return [Boolean] Whether they do.
  def audio_args?(method, args)
    case method
    when /_play\z/
      name, volume, pitch, position = args
      args.size <= 4 && name.is_a?(String) && name =~ AUDIO_FILE && bounded?(volume, 0..100) && bounded?(pitch, 50..150) &&
        (position.nil? || (method =~ /\Abg/ && position.is_a?(Integer) && position >= 0)) ? true : false
    when /_stop\z/ then args.empty?
    when /_fade\z/ then args.size == 1 && bounded?(args[0], 0..MAX_FADE)
    else args.all? { |arg| arg.nil? || arg == true || arg == false || arg.is_a?(Numeric) }
    end
  end

  # Reports whether an optional number lies within a range.
  #
  # @param value [Object, nil] The number.
  # @param range [Range] The range.
  # @return [Boolean] Whether it does.
  def bounded?(value, range)
    value.nil? || (value.is_a?(Integer) && range.include?(value))
  end

  # Reads a value as Ruby's to_i, nil for one without.
  #
  # @param value [Object] The value.
  # @return [Integer, nil] The number.
  def to_i(value)
    [Integer, Float, String, NilClass].any? { |kind| value.is_a?(kind) } ? value.to_i : nil
  end

  # Reports whether the guest has an animation, counting from the end below 0.
  #
  # @param id [Integer] The animation.
  # @return [Boolean] Whether it has.
  def animation?(id)
    (id >= 1 && id < @animations) || (id < 0 && -id <= @animations - 1)
  end

  # Swaps the host's names in a text, longest first.
  #
  # @param text [String] The text.
  # @return [String] The text swapped.
  def swap(text)
    return text if @swaps.empty?

    text.gsub(Regexp.union(@swaps.keys.sort_by { |name| -name.size })) { |name| @swaps[name] }
  end

  # Swaps the names of a message, not in its name box or speaker line.
  #
  # @param text [String] The message line.
  # @return [String] The line swapped.
  def swap_message(text)
    speaker = Regexp.union(NAME_BOX, NAME_LINE)
    text.split(/(#{speaker})/).map { |part| part =~ /\A#{speaker}\z/ ? part : swap(part) }.join
  end

  # Writes a name box as a speaker line for a guest without the name box.
  #
  # @param text [String] The message line.
  # @return [String] The line as the guest shows it.
  def readable(text)
    @name_box ? text : text.sub(NAME_BOX) { |box| "【#{box[/<(.*)>/, 1]}】\n" }
  end

  # Writes a line anew with some of its top-level texts changed, every other token as it came.
  #
  # @param line [String] The line.
  # @param texts [Hash{Integer => String, nil}] The new texts by their place after the kind, nil to
  #   keep one.
  # @return [String] The line.
  def replaced(line, texts)
    value = 0
    depth = 0
    line.split("\t", -1).map do |token|
      text = texts[value - 1] if value > 0 && depth == 0 && token.start_with?("s")
      depth += { "[" => 1, "{" => 1, "]" => -1, "}" => -1 }.fetch(token, 0)
      value += 1 if depth == 0
      text ? "s" + wire.escape(text) : token
    end.join("\t")
  end
end

# Tells what a line the intake kept does on the guest, as the golden cases note it.
#
# @param plain [Array] The line's values as the intake gives them.
# @return [Array<Array>] Its effects.
def live_effects(plain)
  values = MGQ_MpBattlesSync::Wire.objects(plain) { |ref| ref }
  kind, *args = values
  method = kind.split(".", 2)[1]
  describe = lambda do |value|
    case value
    when Integer then { "i" => value.to_s }
    when Float then { "f" => [value].pack("G").unpack1("H*") }
    when String then { "s" => value }
    when Symbol then { "sym" => value.to_s }
    when Array then value.map { |item| describe.call(item) }
    when Color then { "c" => [value.red, value.green, value.blue, value.alpha].map { |channel| [channel.to_f].pack("G").unpack1("H*") } }
    else value
    end
  end
  return [["marker", kind]] if %w(commands end choose_again).include?(kind)
  return [["pass", kind]] if %w(values time_stop turn emerge item_used battler.sprite_effect_type battler.animation_mirror).include?(kind)

  case kind
  when "popup" then [["popup", args[0].to_s, describe.call(args[1])]]
  when "message" then [["message", args[5]]]
  when "skill_name" then [["skill_name", args[0] == "troop" ? "troop" : "party", args[1].is_a?(String) ? args[1] : nil]]
  when "call" then [["call", args[0], args[1]]]
  when "animation" then args[2].to_i < 0 ? [] : Array(args[1]).compact.flat_map { [["animation_id", args[2].to_i], ["animation_mirror", false]] }
  when "battler.animation_id" then [["animation_id", args[1].to_i]]
  when /\Apicture\./ then [["picture", method, [describe.call(args[0].to_i)] + args[1..-1].map { |arg| describe.call(arg) }]]
  else [[kind.split(".", 2)[0], method, args.map { |arg| describe.call(arg) }]]
  end
end

# Holds the stand-in against the golden cases of the guest's intake, which needs
# battles_sync_wire.rbx and the story scene's stand-in loaded.
#
# @raise [RuntimeError] A case the stand-in answers otherwise than the scripts did.
def check_live_stand_in
  golden = live_cases("stream.json")
  golden["cases"].each do |entry|
    stand_in = LiveStandIn.new
    logs = stand_in.answer("live.guest_setup", "names" => entry["names"], "own" => entry["own"], "name_box" => entry["name_box"],
                                               "lists" => golden["lists"].merge("log_calls" => golden["log_calls"]), "animations" => entry["animations"])
    taken = stand_in.answer("live.take_stream", "body" => entry["body"], "seat" => entry["seat"])
    effects = taken["lines"].flat_map { |values| live_effects(values) }
    raise "the live stand-in plays #{entry['name']} otherwise than the scripts: #{effects.inspect[0, 300]}" if effects != entry["effects"]

    counts = [taken["events"], taken["unreadable"], taken["others_choose"]]
    raise "the live stand-in counts #{entry['name']} otherwise than the scripts" if counts != [entry["events"], entry["unreadable"], entry["others_choose"]]

    keys = {}
    texts = (logs + taken["logs"]).select { |key, _| key.nil? || !keys.key?(key) && (keys[key] = true) }.map(&:last)
    raise "the live stand-in logs #{entry['name']} otherwise than the scripts: #{texts.inspect[0, 300]}" if texts.sort != entry["logs"].sort
  end
end

# Holds the session's stand-in against the golden scenario and verdicts of the session.
#
# @raise [RuntimeError] A step or a verdict the stand-in answers otherwise than the scripts did.
def check_live_session_stand_in
  session = LiveSessionStandIn.new
  facts = lambda { |step| { "in_world" => step["in_world"], "served_closed" => false, "gone" => [] } }
  live_cases("session.json")["steps"].each do |step|
    logs = []
    departed = []
    value =
      case step["op"]
      when "join" then session.answer("live.join", step.merge("served" => false)); session.answer("live.phase", "op" => "ready_reset"); nil
      when "start" then session.answer("live.change", "op" => "start"); nil
      when "finish" then session.answer("live.phase", "op" => "close"); session.answer("live.change", "op" => "finish"); nil
      when "expect" then session.answer("live.players", "op" => "expect", "seats" => step["seats"])["expected"]
      when "keep" then session.answer("live.players", "op" => "keep", "seats" => step["seats"])["seats"]
      when "receive" then logs.concat(session.answer("live.receive", step.merge("who" => step["who"][step["seat"].to_s]))["logs"]); nil
      when "pending" then session.answer("live.pending", step["kind"])
      when "take"
        message = session.answer("live.take", "kinds" => step["kinds"], "seat" => step["seat"])["message"]
        message && step["kinds"].size == 1 ? message[1] : message
      when "gone" then session.answer("live.players", "op" => "gone", "seats" => step["seats"]); nil
      when "ticks"
        (1..step["count"]).map do
          tick = session.answer("live.tick", facts.call(step).merge("check" => "ending"))
          logs.concat(tick["logs"])
          departed.concat(tick["departed"])
          tick["ending"]
        end.compact
      when "tell" then session.answer("live.departure", "seat" => step["seat"], "kind" => step["kind"])
      when "admit"
        refusal = session.answer("live.admit", "channel" => step["channel"], "bid" => step["bid"], "kind" => step["kind"], "who" => step["who"][step["who_seat"].to_s])
        logs << refusal if refusal
        nil
      when "ready_reset" then session.answer("live.phase", "op" => "ready_reset")
      when "ready" then session.answer("live.phase", "op" => "ready")["all"] ? true : nil
      when "not_ready" then session.answer("live.phase", "op" => "not_ready")
      when "tell_waiting"
        body = session.answer("live.phase", "op" => "tell", "seats" => step["seats"])
        body && ["waiting", body]
      when "host_waiting"
        names = { 0 => "Host", 2 => "Ann", 3 => "Bea", 4 => "Cid" }
        (session.answer("live.phase", "op" => "host_waiting")["seats"] - [0]).map { |seat| names[seat] }
      end
    keys = {}
    texts = logs.select { |key, _| key.nil? || !keys.key?(key) && (keys[key] = true) }.map(&:last)
    raise "the live session's stand-in answers #{step['op']} #{step.inspect[0, 120]} with #{value.inspect}" if value != step["value"]
    raise "the live session's stand-in takes out #{departed.inspect} at #{step['op']}" if departed != step["departed"]
    raise "the live session's stand-in logs #{texts.inspect} at #{step['op']}" if texts != step["logs"]
  end
  check_live_verdicts_stand_in
end

# Writes the effects of an ending, the take over answered as given, as the golden verdicts note them.
#
# @param verdict [Hash] The ending.
# @param take_over [Boolean] Whether the battle's mode takes over.
# @return [Array<Array>] The effects.
def live_ended(verdict, take_over)
  return [["take_over"]] + (take_over ? [] : live_ended(verdict["otherwise"], false)) if verdict["process"] == "take_over"

  (verdict["message"] ? [["message", verdict["message"]]] : []) + [["process", verdict["process"]]]
end

# Holds the session's stand-in against the golden verdicts of how a battle ends.
#
# @raise [RuntimeError] A verdict the stand-in answers otherwise than the scripts did.
def check_live_verdicts_stand_in
  verdicts = live_cases("verdicts.json")
  verdicts["early"].each do |entry|
    session = LiveSessionStandIn.new
    session.answer("live.join", "role" => "host", "bid" => "v1", "seats" => [2], "player" => "Rival", "kind" => "pvp", "team" => entry["team"], "served" => false)
    verdict = session.answer("live.end", "of" => "early", "reason" => entry["reason"], "side" => entry["side"])
    effects =
      case verdict["process"]
      when "win", "forfeit" then [[verdict["process"]]]
      when "gone" then [["friend_gone"]]
      else entry["missed"] ? [["say", entry["effects"][0][1]], ["process", verdict["process"]]] : live_ended(verdict, false)
      end
    raise "the live session's stand-in ends #{entry['reason']} early with #{effects.inspect}" if effects != entry["effects"]
  end
  verdicts["guest"].each do |entry|
    session = LiveSessionStandIn.new
    session.answer("live.join", "role" => "guest", "bid" => "v2", "seats" => [0], "player" => "Rival", "kind" => "pvp", "team" => true, "served" => false)
    verdict = session.answer("live.end", "of" => "guest", "result" => entry["result"], "side" => entry["side"])
    effects = live_ended(verdict, entry["take_over"])
    raise "the live session's stand-in ends a guest's #{entry['result']} with #{effects.inspect}" if effects != entry["effects"] || entry["logs"][0] != verdict["first"]
  end
  verdicts["gone"].each do |entry|
    session = LiveSessionStandIn.new
    session.answer("live.join", "role" => entry["role"], "bid" => "v3", "seats" => entry["role"] == "host" ? [2] : [0], "player" => "Rival", "kind" => entry["kind"],
                                "team" => entry["team"], "served" => false)
    session.answer("live.change", "op" => "start")
    verdict = session.answer("live.end", "of" => "gone", "side" => entry["side"])
    effects = verdict["process"] == "solo" ? [["solo"]] : live_ended(verdict, entry["take_over"])
    raise "the live session's stand-in ends a gone #{entry['role']} #{entry['kind']} with #{effects.inspect}" if effects != entry["effects"]
  end
end

# Holds the session's stand-in against the golden plans of guests' commands and the team duel's
# sides, with every character taking two actions and using the skills below 150, the skill 199 of no
# type and the items below 40.
#
# @raise [RuntimeError] A plan or a step the stand-in answers otherwise than the scripts did.
def check_live_plan_stand_in
  allowed = lambda { |kind, id| kind == "item" ? id < 40 : id < 150 || id == 199 }
  live_cases("plan.json")["cases"].each do |entry|
    session = LiveSessionStandIn.new
    session.answer("live.join", "role" => "host", "bid" => "b1", "seats" => [], "player" => "Ann", "kind" => "pvp", "team" => true, "served" => false)
    session.answer("live.team", "op" => "prepare", "own" => [], "other" => [], "same_side" => true)
    session.instance_variable_set(:@heirs, entry["heirs"])
    plan = session.answer("live.plan", entry)
    given = entry["owners"].each_index.map do |place|
      entries = plan && plan["places"][place]
      next "kept" if entries.nil?
      next [] if entries.empty?

      actions = entries.first(2).compact.select { |kind, id| allowed.call(kind, id) }.map do |kind, id, target, chain|
        [kind, id, target, Array(chain).take_while { |link| allowed.call(link[0], link[1]) }.map { |link| link.first(3) }]
      end
      actions.empty? ? "kept" : actions
    end
    raise "the live session's stand-in plans #{entry['name']} as #{given.inspect[0, 200]}" if given != entry["places"]
  end

  session = LiveSessionStandIn.new
  host = 0
  live_cases("team.json")["steps"].each do |step|
    reply = nil
    value =
      case step["op"]
      when "join"
        same = step["same_side"]
        host = same ? step["own"][0] : step["other"][0]
        seats = same ? (step["own"] + step["other"]) - [host] : [host]
        session.answer("live.join", "role" => same ? "host" : "guest", "bid" => "t", "seats" => seats, "player" => "the duel", "kind" => "pvp", "team" => true, "served" => false)
        session.answer("live.change", "op" => "start")
        reply = session.answer("live.team", "op" => "prepare", "own" => step["own"], "other" => step["other"], "same_side" => same)
        nil
      when "same_side" then session.instance_variable_get(:@own).include?(step["seat"])
      when "left" then session.answer("live.players", "op" => "left", "seat" => step["seat"]); nil
      when "settle" then reply = session.answer("live.team", "op" => "settle", "host" => host); nil
      when "heir" then session.heir_of(step["seat"])
      when "gone" then (reply = session.answer("live.team", "op" => "gone", "host" => host))["gone"]
      when "take" then reply = session.answer("live.team", "op" => "take", "body" => step["body"]); nil
      end
    heirs = (reply || session.answer("live.team", "op" => "heirs"))["heirs"]
    posted = reply && reply["post"] ? [reply["post"]] : []
    broken = reply ? reply["broken"] : false
    if value != step["value"] || heirs != step["heirs"] || posted != step["posted"] || broken != !step["logs"].empty?
      raise "the live session's stand-in answers the team step #{step['op']} #{step.inspect[0, 120]} with #{[value, heirs, posted, broken].inspect}"
    end
  end
end

# Holds the session's stand-in of the host's recording against its golden steps.
#
# @raise [RuntimeError] A step the stand-in sends or counts otherwise than the scripts did.
def check_live_recorder_stand_in
  session = LiveSessionStandIn.new
  record = lambda { |op, fields = {}| session.answer("live.record", fields.merge("op" => op)) }
  # The steps note each battler's values as their line; the scripts hand them over as values.
  battlers = lambda { |step| step["battlers"].map { |key, ref, line| [key, ref, WireStandIn.parse(line)] } }
  live_cases("recorder.json")["steps"].each_with_index do |step, index|
    logs = []
    sends =
      case step["op"]
      when "start" then logs << "recording the battle for the guests' stream"; record.call("start")["sends"]
      when "values" then record.call("values", "battlers" => battlers.call(step), "full" => step["full"])["sends"]
      when "tick" then session.answer("live.tick", "check" => "frame")["sends"]
      when "event" then record.call("event", "values" => WireStandIn.parse(step["line"]))["sends"]
      when "flush" then record.call("flush")["sends"]
      when "phase"
        sent = record.call("values", "battlers" => battlers.call(step), "full" => true)["sends"] + record.call("event", "values" => WireStandIn.parse(step["line"]))["sends"] +
               record.call("flush")["sends"]
        counts = record.call("counts")
        logs << "streamed the battle's start: #{counts['events']} events in #{counts['sends_counted']} sends, every battler's values anew"
        sent
      when "finish"
        sent = record.call("flush")["sends"]
        totals = record.call("totals")
        logs << "recording finished, battle result 0: #{totals['events']} events in #{totals['sends_counted']} sends"
        sent
      when "stop" then logs << "recording stopped, #{record.call('stop')['events']} events left unsent"; []
      end
    raise "the recording's stand-in sends step #{index} #{step['op']} otherwise than the scripts" if sends.flat_map { |send| ["before_send", send] } != step["sends"]
    raise "the recording's stand-in counts step #{index} #{step['op']} otherwise than the scripts: #{logs.inspect}" if logs != step["logs"]
  end
end

# Answers the live battle's topics from a stand-in.
#
# @param fake [FakeBridge] The test's bridge.
# @return [LiveStandIn] The stand-in.
def answer_live(fake)
  stand_in = LiveStandIn.new
  %w(live.guest_setup live.take_stream live.swap live.join live.change live.players live.admit live.receive live.take live.pending live.tick
     live.end live.phase live.departure live.plan live.team live.backline live.record live.mode).each { |topic| fake.answer(topic) { |request| stand_in.answer(topic, request) } }
  stand_in
end
