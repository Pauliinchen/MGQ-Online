#----------------------------------------------------------------
#  ask_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Read a running battle as Sessions does, offered a side battle only beside a full one and told why a battle near takes nobody in
#                            - Offered a party member's battle in a Classic world too
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# The DLL's asking side of hotjoining and joining side of joining a battle by choice
# (MGQOnline.Game's CoopAsking and JoinChoice, behind CoopRoomTopics) for the script tests:
# AskStandIn answers their topics as the DLL does, beside a MatchStandIn whose world, sends and log
# it shares. check_ask_stand_in replays the golden scenarios of fixtures/coop/asks.json, which
# battles_coop_hotjoin.rbx and battles_coop_join.rbx played before the rules left them, on the
# stand-in, so it cannot drift from what C# answers.

require "json"

# Stands in for the asking and joining sides, each topic's request in, its reply out.
class AskStandIn
  # Frames the player waits for the running battle's host to answer.
  ANSWER_FRAMES = 180

  # Frames the player waits for the party members to answer.
  PARTY_ANSWER_FRAMES = 480

  # Seconds a party member's offer to join a battle along stands.
  PARTY_OFFER_SECONDS = 20

  # Steps another player who fights a battle may be away from the player for its prompt to show.
  JOIN_DISTANCE = 3

  # Seconds the player waits for the answer of a battle's host they asked to join.
  ANSWER_SECONDS = 3

  # Frames the notification box shows a message of joining by choice.
  NOTICE_FRAMES = 240

  # The notification box's key of joining by choice.
  NOTICE_KEY = "join_battle"

  # The co-op messages these sides take.
  KINDS = %w(hot_ok hot_no party_hot party_ans pick_no)

  # The topics the stand-in answers.
  TOPICS = %w(coop.ask coop.ask_wait coop.ask_party_wait coop.ask_party_end coop.ask_end coop.ask_release coop.ask_undo coop.ask_abandon coop.ask_off
              coop.party_offers coop.accept_party coop.decline_party coop.join_frame)

  # The player's request to join a battle by choice, the host and battle they gave up on.
  attr_reader :gave_up

  # Makes the sides beside a matchmaking.
  #
  # @param match [MatchStandIn] The matchmaking, whose world, facts, sends and log these share.
  def initialize(match)
    @match = match
    @asking = nil
    @offers = {}
    @join = nil
    @gave_up = nil
  end

  # Answers a topic.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    @match.answer("coop.frame", request["facts"]) if request.is_a?(Hash) && request["facts"]
    case topic
    when "coop.ask" then @match.status(ask(request))
    when "coop.ask_wait" then wait
    when "coop.ask_party_wait" then party_wait
    when "coop.ask_party_end" then party_end
    when "coop.ask_end" then finish(request.to_s)
    when "coop.ask_release" then release_companions(Array(request["seats"])) && nil
    when "coop.ask_undo" then undo || @match.status([])
    when "coop.ask_abandon" then abandon || @match.status([])
    when "coop.ask_off" then (peer = world.at(request["seat"])) ? take_off(peer, request["fields"]) : false
    when "coop.party_offers" then (@match.answer("coop.frame", request) || true) && offers
    when "coop.accept_party" then ((peer = world.at(request["seat"])) && accept_party(peer, request["busy"])) || @match.status([])
    when "coop.decline_party" then ((peer = world.at(request["seat"])) && decline_party(peer)) || @match.status([])
    when "coop.join_frame" then frame(request)
    end
  end

  # Takes a co-op message of these sides, logged as the scripts' take logged it.
  #
  # @param peer [Object, nil] Who sent it.
  # @param message [Hash] The message, its kind under "coop".
  def take_message(peer, message)
    log_took(peer, message)
    case message["coop"]
    when "hot_ok" then take_answer(peer, message, "accepted")
    when "hot_no" then take_answer(peer, message, "refused")
    when "party_hot" then take_party_offer(peer, message)
    when "party_ans" then take_party_answer(peer, message)
    when "pick_no" then take_refusal(peer, message)
    end
  end

  # @return [Array<Integer>] The players the player's request brings along.
  def asked_seats
    @asking ? @asking[:seats] : []
  end

  # @return [Array, nil] The host's seat and the battle's id the player asks, nil for none.
  def battle
    @asking && [@asking[:seat], @asking[:bid]]
  end

  # Writes these sides' part of the status.
  #
  # @return [Hash] "ask", "ask_party" and "join_waits".
  def state
    { "ask" => !@asking.nil?, "ask_party" => !@asking.nil? && @asking[:mode] == :start, "join_waits" => join_waits? }
  end

  # Ends the wait for a battle's host the player asked to join by choice, as JoinChoice.Settle does.
  def settle
    ask = @join
    return unless ask

    if facts["role"]
      @join = nil
      world.drop_notice(NOTICE_KEY, nil, "the player joins a battle")
      return join_log(facts["bid"].to_s == ask[:bid] ? "joins #{ask[:name]}'s battle #{ask[:bid]} as a late guest"
                      : "joins battle #{facts['bid']} as #{facts['role']} instead of #{ask[:name]}'s battle #{ask[:bid]}")
    end
    return unless join_expired?(ask) && !invited_by?(ask)

    @join = nil
    @gave_up = [ask[:seat], ask[:bid]]
    @match.tell_map([ask[:seat]], "off", [["bid", ask[:bid]]])
    notice("No answer from #{ask[:name]}'s battle.")
    join_log("no answer from #{ask[:name]} for battle #{ask[:bid]} within #{ANSWER_SECONDS} s, told them the player stopped waiting")
  end

  # Forgets the request, the offers and the request to join, as a reset does.
  def drop
    join_log("forgot the request to join #{@join[:name]}'s battle after a reset") if @join
    @asking = nil
    @offers = {}
    @join = nil
    @gave_up = nil
  end

  # Ages the request to join by choice, as if seconds passed since it was sent.
  #
  # @param seconds [Numeric] The seconds.
  def age_join(seconds)
    @join[:at] -= seconds if @join
  end

  # Finds the running battle an encounter would join, as CoopAsking.TargetBattle does.
  #
  # @return [Array, nil] The battle's host and its id, nil when none runs.
  def target_battle
    map = facts["map"]
    battles = world.peers.select { |peer| peer.away.nil? && peer.state["map"].to_i == map }.map do |peer|
      bid = peer.state["rb"].to_s
      next if !fights?(peer) || peer.state["rbh"].to_s !~ /\A\d+\z/

      host = world.at(peer.state["rbh"].to_i)
      next unless host && host.state["map"].to_i == map && host.state["rb"].to_s == bid && @match.near?(host) && room_in(host) > 0

      [host, bid]
    end
    battles.compact.min_by { |host, bid| [host.state["since"].to_i, host.state["id"].to_s, bid] }
  end

  private

  # @return [Object] The world the matchmaking stands in.
  def world
    @match.instance_variable_get(:@world)
  end

  # @return [Hash] The facts the game told last.
  def facts
    @match.instance_variable_get(:@facts)
  end

  # Writes a line of the asking side into the log.
  #
  # @param line [String] The line.
  # @return [nil] Nothing.
  def log(line)
    world.log("hotjoin: " + line)
    nil
  end

  # Writes a line of the joining side into the log.
  #
  # @param line [String] The line.
  # @return [nil] Nothing.
  def join_log(line)
    world.log("join battle: " + line)
    nil
  end

  # Logs a co-op message taken, as the scripts' take did.
  #
  # @param peer [Object, nil] Who sent it.
  # @param message [Hash] The message.
  def log_took(peer, message)
    world.log("co-op battle: took #{message['coop']} from #{@match.who(peer)}: #{message.reject { |key, _| key == 'coop' }.map { |key, value| "#{key}=#{value}" }.join(' ')}")
  end

  # Names players by their seats for the log.
  #
  # @param seats [Array<Integer>] The seats.
  # @return [String] Their names, or "nobody".
  def names(seats)
    seats.empty? ? "nobody" : seats.map { |seat| @match.who_seat(seat) }.join(", ")
  end

  # Reports whether another player fights a battle, by their state.
  #
  # @param peer [Object] The player.
  # @return [Boolean] Whether they do.
  def fights?(peer)
    !peer.state["rb"].to_s.empty? && MatchStandIn::RAID_BATTLE_SCENES.include?(peer.state["scene"])
  end

  # Counts the players a running battle still takes in, as Sessions.Battle tells it.
  #
  # @param host [Object] The battle's host.
  # @return [Integer] The players it takes.
  def room_in(host)
    count, state = battle_of(host)
    state == "open" && count.between?(1, MatchStandIn::RAID_PLAYERS - 1) ? MatchStandIn::RAID_PLAYERS - count : 0
  end

  # Reads the battle a host tells, as Sessions.Battle does: its players and its state, which a
  # state without "rbs" tells by its count alone.
  #
  # @param host [Object] The battle's host.
  # @return [Array(Integer, String)] The players and the state.
  def battle_of(host)
    count = host.state.key?("rbn") ? host.state["rbn"].to_i : 1
    state = host.state["rbs"].to_s
    state = count >= MatchStandIn::RAID_PLAYERS ? "full" : count >= 1 ? "open" : "closed" if state.empty?
    [count, state]
  end

  # Lists the party members near and free, as CoopAsking.PartyNear does.
  #
  # @param host [Object] The running battle's host.
  # @return [Array] The members.
  def party_near(host)
    members = world.members
    return [] if members.any? { |member| member.seat == host.seat && member.state["id"].to_s == host.state["id"].to_s }

    members.select { |peer| @match.raid_free?(peer) && @match.near?(peer) }
  end

  # Asks the running battle near, as CoopAsking.Ask does.
  #
  # @param request [Hash] The encounter.
  # @return [Array<Hash>] The actions.
  def ask(request)
    return [] unless world.raid?

    target = target_battle
    return [] unless target
    return log("the encounter with troop #{request['troop']} joins no running battle: it is a boss battle") || [] if request["boss"]

    host, bid = target
    room = room_in(host)
    party = party_near(host).map(&:seat)
    mode = party.empty? ? :alone : (room > party.size ? :join : :start)
    free = @match.raid_candidates([], Array(request["stays_out"])).select { |peer| peer.state["rb"].to_s.empty? }.map(&:seat) - party
    seats = free.first([room - 1 - (mode == :join ? party.size : 0), 0].max)
    @asking = { :seat => host.seat, :bid => bid, :name => host.state["name"].to_s, :encounter => request, :seats => seats, :party => party, :mode => mode,
                :answer => nil, :frames => 0, :party_frames => 0, :answers => {}, :host => nil, :taken => nil, :stays_out => [] }
    @match.freeze_party(mode == :start ? seats + party : seats)
    offer_party(party, mode.to_s, host, bid) unless mode == :alone
    tell_host(@asking) unless mode == :start
    [@match.action("join", "role" => "guest", "bid" => bid, "seats" => [host.seat], "label" => host.state["name"].to_s)]
  end

  # Sends the request of an encounter to the running battle's host.
  #
  # @param ask [Hash] The request.
  def tell_host(ask)
    encounter = ask[:encounter]
    enemies = Array(encounter["entries"]).map { |entry| entry.join(":") }.join(";")
    widths = Array(encounter["widths"]).map { |id, width| "#{id}:#{width}" }.join(";")
    @match.tell_map([ask[:seat]], "hot", [["bid", ask[:bid]], ["troop", encounter["troop"].to_s], ["enemies", enemies], ["widths", widths],
                                          ["seats", ask[:seats].join(",")], ["map", facts["map"].to_s]])
    log("asked #{@match.who_seat(ask[:seat])} to take the encounter with troop #{encounter['troop']} into battle #{ask[:bid]}, " \
        "with #{ask[:seats].empty? ? 'no other player' : names(ask[:seats])}, waiting up to #{ANSWER_FRAMES / 60} s")
  end

  # Asks party members along in their notification box.
  #
  # @param seats [Array<Integer>] The members' seats.
  # @param mode [String] "join" or "start".
  # @param host [Object] The running battle's host.
  # @param bid [String] Its id.
  def offer_party(seats, mode, host, bid)
    @match.tell_map(seats, "party_hot", [["mode", mode], ["host", host.seat.to_s], ["bid", bid], ["map", facts["map"].to_s]])
    log("asked #{names(seats)} in the notification box to #{mode == 'join' ? 'join' : 'start a battle with the player instead of joining'} #{@match.who(host)}'s battle #{bid}")
  end

  # Counts a frame of the wait for the host's answer.
  #
  # @return [String, nil] The answer, nil while the wait lasts.
  def wait
    return "silent" unless @asking

    @asking[:frames] += 1
    @asking[:answer] || (@asking[:frames] >= ANSWER_FRAMES ? "silent" : nil)
  end

  # Counts a frame of the wait for the party's answers.
  #
  # @return [String, nil] "done" once over, nil while the wait lasts.
  def party_wait
    return "done" unless @asking

    @asking[:party_frames] += 1
    @asking[:party].all? { |seat| @asking[:answers].key?(seat) } || @asking[:party_frames] >= PARTY_ANSWER_FRAMES ? "done" : nil
  end

  # Ends the wait for the party, as CoopAsking.PartyEnd does.
  #
  # @return [Hash, nil] The battle the player hosts instead, nil when the player asks alone.
  def party_end
    ask = @asking
    return nil unless ask

    starters = ask[:party].select { |seat| ask[:answers][seat] }
    stays_out = ask[:party] - starters
    if starters.empty?
      log("no party member starts a battle with the player (said no or stayed silent: #{names(ask[:party])}), so the player asks #{ask[:name]}'s battle alone")
      @match.tell_map(ask[:party], "off", [["map", facts["map"].to_s], ["bid", ask[:bid]]])
      ask[:stays_out] = stays_out
      tell_host(ask)
      return nil
    end

    @asking = nil
    log("#{names(starters)} start a battle with the player instead of #{ask[:name]}'s, which has no room for them all; staying out: #{names(stays_out)}")
    outcome(false, ask, ask[:seats] + stays_out, stays_out)
  end

  # Ends the wait for the host's answer, as CoopAsking.End does.
  #
  # @param answer [String] How it ended.
  # @return [Hash, nil] What the scripts do.
  def finish(answer)
    ask = @asking
    return nil unless ask

    @asking = nil
    if answer == "accepted"
      log("joins #{ask[:name]}'s battle #{ask[:bid]} at its next command phase, the encounter's enemies with the player")
      return outcome(true, ask, ask[:taken] ? ask[:seats] - ask[:taken] : [], ask[:stays_out])
    end

    log("#{ask[:name]} does not take the encounter into battle #{ask[:bid]} (#{answer}), it starts on its own")
    @match.tell_map([ask[:seat]], "off", [["bid", ask[:bid]]]) unless answer == "refused"
    outcome(false, ask, ask[:seats], ask[:stays_out])
  end

  # Writes how a request ended for the scripts.
  #
  # @param late [Boolean] Whether the player joins late.
  # @param ask [Hash] The request.
  # @param release [Array<Integer>] The players who walk on.
  # @param stays_out [Array<Integer>] The members who stay out.
  # @return [Hash] The outcome.
  def outcome(late, ask, release, stays_out)
    encounter = ask[:encounter]
    { "late" => late, "troop" => encounter["troop"], "escape" => encounter["escape"] ? true : false, "lose" => encounter["lose"] ? true : false,
      "release" => release, "stays_out" => stays_out, "host" => late ? ask[:host] : nil }
  end

  # Lets the players a request brought along walk on.
  #
  # @param seats [Array<Integer>] The seats.
  # @return [true] Always.
  def release_companions(seats)
    return true if seats.empty?

    @match.release(seats, asked_seats)
    log("let the players the request brought along walk on, unless invited anew: #{names(seats)}")
    true
  end

  # Takes back a request that failed halfway.
  #
  # @return [nil] Nothing.
  def undo
    ask = @asking
    return nil unless ask

    @asking = nil
    @match.tell_map([ask[:seat]], "off", [["bid", ask[:bid]]])
    release_companions(ask[:seats])
    nil
  end

  # Forgets a request whose wait failed.
  #
  # @return [nil] Nothing.
  def abandon
    ask = @asking
    return nil unless ask

    @asking = nil
    release_companions(ask[:seats])
    nil
  end

  # Takes the host's answer.
  #
  # @param peer [Object] Who answered.
  # @param message [Hash] The answer.
  # @param answer [String] "accepted" or "refused".
  def take_answer(peer, message, answer)
    ask = @asking
    unless ask && peer && peer.seat == ask[:seat] && message["bid"].to_s == ask[:bid]
      return log("#{answer} for battle #{message['bid']} from #{@match.who(peer)} ignored: not the battle the player asked to join")
    end

    ask[:host] = { "escape" => message["escape"] == "1", "lose" => message["lose"] == "1", "rates" => message["rates"].to_s, "served" => message["served"].to_s == "1" }
    ask[:taken] = message["seats"].to_s.split(",").map(&:to_i) if message.key?("seats")
    ask[:answer] = answer
    log("#{@match.who(peer)} answered for battle #{message['bid']}: #{answer}")
  end

  # Takes a party member's answer.
  #
  # @param peer [Object, nil] The member.
  # @param message [Hash] The answer.
  def take_party_answer(peer, message)
    ask = @asking
    unless ask && peer && ask[:party].include?(peer.seat) && message["bid"].to_s == ask[:bid]
      return log("party answer for battle #{message['bid']} from #{@match.who(peer)} ignored: the player asks nobody about it")
    end

    ask[:answers][peer.seat] = message["ok"] == "1"
    log("#{@match.who(peer)} #{message['ok'] == '1' ? 'starts' : 'does not start'} a battle with the player")
  end

  # Takes a player's word that hotjoining is off, the asking side's part.
  #
  # @param peer [Object] The player.
  # @param message [Hash] The message.
  # @return [Boolean] Whether it settled the player's own request.
  def take_off(peer, message)
    bid = message["bid"].to_s
    offer = @offers[peer.seat]
    if offer && offer[:bid] == bid
      @offers.delete(peer.seat)
      log("dropped #{@match.who(peer)}'s offer to come along to battle #{offer[:bid]}: they called it off")
    end
    ask = @asking
    return false unless ask && peer.seat == ask[:seat] && bid == ask[:bid]

    ask[:answer] = "refused"
    log("#{@match.who(peer)} called battle #{ask[:bid]} off before answering")
    true
  end

  # Takes a party member's offer.
  #
  # @param peer [Object] The member.
  # @param message [Hash] The offer.
  def take_party_offer(peer, message)
    return log("party offer from #{@match.who(peer)} ignored: their map #{message['map']} is not the player's") unless message["map"].to_i == facts["map"]

    mode = message["mode"] == "start" ? "start" : "join"
    @offers[peer.seat] = { :mode => mode, :host => message["host"].to_i, :bid => message["bid"].to_s, :at => world.now }
    log("#{@match.who(peer)} asks the player to #{mode == 'join' ? 'join' : 'start a battle with them instead of'} #{@match.who_seat(message['host'].to_i)}'s battle #{message['bid']}")
  end

  # Lists the offers that stand, dropping those that lapsed.
  #
  # @return [Array<Array>] Each offer's seat, mode, host, battle id and when it came in milliseconds.
  def offers
    world.peers.map { |peer| (offer = offer_of(peer)) && [peer.seat, offer[:mode], offer[:host], offer[:bid], (offer[:at] * 1000).round] }.compact
  end

  # Finds a member's standing offer, dropping it once it lapsed.
  #
  # @param peer [Object] The member.
  # @return [Hash, nil] The offer.
  def offer_of(peer)
    offer = @offers[peer.seat]
    return nil unless offer

    reason = offer_end(peer, offer)
    return offer unless reason

    @offers.delete(peer.seat)
    log("dropped #{@match.who(peer)}'s offer to come along to battle #{offer[:bid]}: #{reason}")
    nil
  end

  # Tells why an offer lapsed.
  #
  # @param peer [Object] The member.
  # @param offer [Hash] The offer.
  # @return [String, nil] The reason, nil while it stands.
  def offer_end(peer, offer)
    lasts = offer[:mode] == "start" ? PARTY_ANSWER_FRAMES / 60 : PARTY_OFFER_SECONDS
    return "it stood #{lasts} s" if world.now - offer[:at] > lasts
    return "the player is in a battle" if facts["role"] || facts["in_battle"]

    fights = peer.state["rb"].to_s
    return "#{peer.state['name']} fights another battle" unless fights.empty? || fights == offer[:bid]

    host = world.at(offer[:host])
    "the battle is over" unless host && host.state["rb"].to_s == offer[:bid]
  end

  # Takes up a member's offer.
  #
  # @param peer [Object] The member.
  # @param busy [Array] The scripts' reasons before and after the player's request.
  # @return [nil] Nothing.
  def accept_party(peer, busy)
    offer = offer_of(peer)
    return log("did not come along with #{@match.who(peer)}: the offer no longer stands") unless offer

    @offers.delete(peer.seat)
    return answer_party(peer, offer, true) && nil if offer[:mode] == "start"

    host = world.at(offer[:host])
    reason = busy_reason(busy)
    if reason || host.nil? || open_battle(host).nil?
      notice("Cannot join that battle now.")
      return log("did not join battle #{offer[:bid]} with #{@match.who(peer)}: #{reason || 'it takes nobody in now'}")
    end

    request(host, offer[:bid], false)
    nil
  end

  # Declines a member's offer.
  #
  # @param peer [Object] The member.
  # @return [nil] Nothing.
  def decline_party(peer)
    offer = @offers.delete(peer.seat)
    return nil unless offer

    offer[:mode] == "start" ? answer_party(peer, offer, false) : log("does not join battle #{offer[:bid]} with #{@match.who(peer)}")
    nil
  end

  # Answers a member whether the player starts a battle with them.
  #
  # @param peer [Object] The member.
  # @param offer [Hash] Their offer.
  # @param yes [Boolean] Whether the player does.
  # @return [true] Always.
  def answer_party(peer, offer, yes)
    @match.tell_map([peer.seat], "party_ans", [["bid", offer[:bid]], ["ok", yes ? "1" : "0"]])
    log("answered #{@match.who(peer)}: the player #{yes ? 'starts' : 'does not start'} a battle with them")
    true
  end

  # Asks the party members near along to a battle the player asked to join by choice.
  #
  # @param host [Object] The battle's host.
  # @param bid [String] Its id.
  def offer_party_join(host, bid)
    return unless world.raid?

    party = party_near(host)
    return if party.empty?

    room = room_in(host)
    return log("asked no party member along to #{@match.who(host)}'s battle #{bid}: it takes #{room} more players, not #{party.size + 1}") unless room > party.size

    offer_party(party.map(&:seat), "join", host, bid)
  end

  # Tells why the player may not join a battle by choice now.
  #
  # @param busy [Array] The scripts' reasons before and after the player's request.
  # @return [String, nil] The first that holds.
  def busy_reason(busy)
    before, after = Array(busy)
    before || (@join ? "the player waits for an answer" : nil) || after
  end

  # Runs a frame on the map for the join prompt, as JoinChoice.Frame does.
  #
  # @param told [Hash] The frame.
  # @return [Hash] What the prompt offers, with the status.
  def frame(told)
    settle
    reply = { "target" => nil, "side" => nil, "freeze" => nil, "busy_reason" => nil, "asked" => false }
    return @match.status([]).merge(reply) unless told["reads"]

    busy = busy_reason(told["busy"])
    changing = told["changing"]
    target = changing || busy ? nil : join_target
    side = changing || target || busy || !world.raid? ? nil : side_target(told["sides"])
    freeze = changing || target || side || busy ? nil : told["freeze"]
    if told["pressed"] && !changing && target
      request(target[0], target[1], true)
      return @match.status([]).merge(reply.merge("busy_reason" => busy, "asked" => true))
    end

    not_taken = told["pressed"] && !changing && !busy && !target && !side && !freeze ? not_taken_text : nil
    @match.status([]).merge("target" => target && [target[0].seat, target[1]], "side" => side, "freeze" => freeze, "busy_reason" => busy, "asked" => false,
                            "not_taken" => not_taken)
  end

  # Tells the player why the battle of the nearest player near who fights one takes nobody in, as
  # JoinChoice.NotTaken does.
  #
  # @return [String, nil] The message shown, nil while nobody near fights a battle.
  def not_taken_text
    near = on_map.select { |peer| fights?(peer) && @match.distance(peer, facts["x"], facts["y"]) <= JOIN_DISTANCE }
    near = near.sort_by { |peer| [@match.distance(peer, facts["x"], facts["y"]), peer.state["id"].to_s] }
    host = near.map { |peer| host_of(peer) }.compact.first
    return nil unless host

    state = battle_of(host)[1]
    name = host.state["name"]
    text = { "full" => "#{name}'s battle is full.", "ending" => "#{name}'s battle is ending.",
             "gathering" => "#{name}'s battle is still gathering its players." }[state] || "#{name}'s battle takes nobody in now."
    notice(text)
    join_log("#{@match.who(host)}'s battle #{host.state['rb']} takes nobody in (#{state}): told the player")
    text
  end

  # Finds the battle near that takes the player in.
  #
  # @return [Array, nil] The host and battle id.
  def join_target
    near = on_map.select { |peer| fights?(peer) && @match.distance(peer, facts["x"], facts["y"]) <= JOIN_DISTANCE }
    near = near.sort_by { |peer| [@match.distance(peer, facts["x"], facts["y"]), peer.state["id"].to_s] }
    near.map { |peer| open_battle(peer) }.compact.first
  end

  # Finds the host of a battle another player fights and whether it takes players in.
  #
  # @param peer [Object] The player who fights it.
  # @return [Array, nil] The host and battle id.
  def open_battle(peer)
    host = host_of(peer)
    host && room_in(host) > 0 ? [host, peer.state["rb"].to_s] : nil
  end

  # Finds the host fighting the battle another player fights, unless it is the player's own.
  #
  # @param peer [Object] The player who fights it.
  # @return [Object, nil] The host.
  def host_of(peer)
    bid = peer.state["rb"].to_s
    return nil unless peer.state["rbh"].to_s =~ /\A\d+\z/
    return nil if bid == facts["bid"].to_s

    host = world.at(peer.state["rbh"].to_i)
    host && host.state["map"].to_i == facts["map"] && fights?(host) && host.state["rb"].to_s == bid ? host : nil
  end

  # Finds the side battle near.
  #
  # @param sides [Array, nil] The side battles by their hosts.
  # @return [Array, nil] The troop, rates and name.
  def side_target(sides)
    return nil if sides.nil?

    near = on_map.map do |peer|
      bid = peer.state["rb"].to_s
      next if !fights?(peer) || peer.state["rbh"].to_s !~ /\A\d+\z/

      host = world.at(peer.state["rbh"].to_i)
      next unless host && host.state["map"].to_i == facts["map"] && host.state["rb"].to_s == bid && battle_of(host)[1] == "full"

      side = sides.find { |entry| entry[0] == host.seat }
      next unless side

      steps = @match.distance(peer, facts["x"], facts["y"])
      steps = [steps, side[3]].min if side[3]
      [steps, peer.state["id"].to_s, side]
    end
    best = near.compact.select { |entry| entry[0] <= JOIN_DISTANCE }.min_by { |entry| entry.first(2) }
    best && [best[2][1], best[2][2], best[2][4]]
  end

  # Lists the other players on the player's map whose connection stands.
  #
  # @return [Array] The players.
  def on_map
    world.peers.select { |peer| peer.away.nil? && (world.raid? || peer.member) && peer.state["map"].to_i == facts["map"] }
  end

  # Asks a battle's host to take the player in.
  #
  # @param host [Object] The host.
  # @param bid [String] The battle's id.
  # @param along [Boolean] Whether to ask the party along.
  def request(host, bid, along)
    name = host.state["name"].to_s
    @join = { :seat => host.seat, :bid => bid, :name => name, :at => world.now }
    @gave_up = nil
    @match.tell_map([host.seat], "pick", [["bid", bid], ["map", facts["map"].to_s]])
    notice("Asking #{name} to join their battle...", ANSWER_SECONDS * 60)
    join_log("asked #{@match.who(host)} to join battle #{bid}, waiting up to #{ANSWER_SECONDS} s")
    offer_party_join(host, bid) if along
  end

  # Takes the refusal of the host the player asked to join.
  #
  # @param peer [Object, nil] Who refused.
  # @param message [Hash] The refusal.
  def take_refusal(peer, message)
    ask = @join
    unless ask && peer && peer.seat == ask[:seat] && message["bid"].to_s == ask[:bid]
      return join_log("refusal for battle #{message['bid']} from #{@match.who(peer)} ignored: not the battle the player asked to join")
    end

    @join = nil
    notice("Cannot join #{ask[:name]}'s battle.")
    join_log("#{@match.who(peer)} refused the player for battle #{message['bid']}: #{message['why']}")
  end

  # Reports whether the player waits for the answer of a battle's host they asked.
  #
  # @return [Boolean] Whether they do.
  def join_waits?
    ask = @join
    !ask.nil? && facts["role"].nil? && (!join_expired?(ask) || invited_by?(ask))
  end

  # Reports whether the request's answer time passed.
  #
  # @param ask [Hash] The request.
  # @return [Boolean] Whether it did.
  def join_expired?(ask)
    world.now - ask[:at] > ANSWER_SECONDS
  end

  # Reports whether the asked host's invite waits for the player.
  #
  # @param ask [Hash] The request.
  # @return [Boolean] Whether it does.
  def invited_by?(ask)
    invite = @match.instance_variable_get(:@invite)
    !invite.nil? && invite[:peer].seat == ask[:seat] && invite[:message]["bid"].to_s == ask[:bid]
  end

  # Shows a message of joining by choice.
  #
  # @param text [String] The message.
  # @param frames [Integer] How long it shows.
  def notice(text, frames = NOTICE_FRAMES)
    world.notice(NOTICE_KEY, nil, text, frames)
  end
end

# Replays a golden scenario's steps on the stand-in as the scripts now take them, as
# MGQOnline.Game.Tests' AskHarness replays them on C#.
class AskReplay
  # The scripts' reasons the player may not join a battle that come before the player's request.
  BUSY_BEFORE = ["no world is open", "not a Raid World", "the map is not free: an event, a message or a transfer", "the player is in a multiplayer battle"]

  # Makes the replay of a scenario.
  def initialize
    @ids = [0]
    @match = MatchStandIn.new(Object.new)
    @asks = AskStandIn.new(@match)
    @match.asks = @asks
  end

  # Runs a step and tells what it sent, showed, did, logged and answered.
  #
  # @param step [Hash] The step.
  # @return [Hash] The outcome.
  def run(step)
    @world = GoldenMatchWorld.new(step["world"], @ids)
    @match.instance_variable_set(:@world, @world)
    @told = step["world"]
    @facts = @told["facts"].dup
    @args = step["args"]
    @actions = []
    @result = nil
    @match.answer("coop.frame", @facts)
    case step["op"]
    when "ask" then ask
    when "take" then take(@world.at(@args["seat"]), @args["message"])
    when "await" then await
    when "undo"
      if @asks.state["ask"]
        finish_live
        @asks.answer("coop.ask_undo", "facts" => @facts)
      end
    when "offers"
      @result = @asks.answer("coop.party_offers", @facts).map do |seat, mode, _host, _bid, at|
        [seat, "#{mode == 'join' ? 'Join' : 'Start'} battle with #{@world.at(seat).state['name']}?", mode == "join" ? "Join" : "Start", at]
      end
    when "accept_party" then @asks.answer("coop.accept_party", "facts" => @facts, "seat" => @args["seat"], "busy" => busy)
    when "decline_party" then @asks.answer("coop.decline_party", "facts" => @facts, "seat" => @args["seat"])
    when "prompt" then prompt
    end
    { "sent" => @world.sent, "box" => @world.box, "actions" => @actions, "logs" => @world.logs, "result" => @result }
  end

  private

  # Asks the running battle near as the scripts' ask does.
  def ask
    request = { "facts" => @facts, "troop" => @args["troop"], "escape" => @args["escape"], "lose" => @args["lose"], "boss" => @args["boss"],
                "entries" => @told["entries"], "widths" => @told["widths"], "stays_out" => @told["stays_out"] }
    join = @asks.answer("coop.ask", request)["actions"].find { |action| action["kind"] == "join" }
    if join
      @actions << ["join", join["role"], join["bid"], join["seats"], join["label"]]
      @facts = @facts.merge("role" => "guest", "bid" => join["bid"], "seats" => join["seats"], "coop" => true, "running" => true, "kind" => "coop")
      @match.answer("coop.frame", @facts)
    end
    @result = join ? true : false
  end

  # Takes a co-op message as the routes and the scripts' take do.
  #
  # @param peer [Object, nil] Who sent it.
  # @param message [Hash] The message.
  def take(peer, message)
    return @asks.take_message(peer, message) if AskStandIn::KINDS.include?(message["coop"])

    @world.log("co-op battle: took #{message['coop']} from #{@match.who(peer)}: #{message.reject { |key, _| key == 'coop' }.map { |key, value| "#{key}=#{value}" }.join(' ')}")
    return unless message["coop"] == "off"
    return if @asks.answer("coop.ask_off", "facts" => @facts, "seat" => peer.seat, "fields" => message)

    @match.answer("coop.take_off", "facts" => @facts, "seat" => peer.seat, "fields" => message)
  end

  # Waits at the battle's start as the scripts' await does, a frame counted across both waits.
  def await
    frame = 0
    wait = lambda do |topic|
      frame += 1
      @args["inject"].each { |at, seat, message| take(@world.at(seat), message) if at == frame }
      frame == @args["end_at"] ? @args["ending"] : @asks.answer(topic, nil)
    end
    return unless @asks.state["ask"]

    if @asks.state["ask_party"]
      nil until wait.call("coop.ask_party_wait")
      started = @asks.answer("coop.ask_party_end", nil)
      return own(started) if started
    end
    answer = nil
    answer = wait.call("coop.ask_wait") until answer
    outcome = @asks.answer("coop.ask_end", answer)
    return own(outcome) unless outcome["late"]

    host = outcome["host"]
    @actions.concat([["rates", host["rates"]], ["set", "can_escape", host["escape"]], ["set", "can_lose", host["lose"]], ["set", "preemptive", false],
                     ["set", "surprise", false]])
    @asks.answer("coop.ask_release", "facts" => @facts, "seats" => outcome["release"]) unless outcome["release"].empty?
    @result = { "stays_out" => outcome["stays_out"], "own_troop" => true, "late" => true }
  end

  # Starts the encounter on its own as the scripts do.
  #
  # @param outcome [Hash] How the request ended.
  def own(outcome)
    finish_live
    @actions << ["host", outcome["troop"], outcome["escape"], outcome["lose"]]
    @actions << ["fight_alone"]
    @asks.answer("coop.ask_release", "facts" => @facts, "seats" => outcome["release"]) unless outcome["release"].empty?
    @result = { "stays_out" => outcome["stays_out"], "own_troop" => false, "late" => false }
  end

  # Ends the live battle as the scripts' finish does.
  def finish_live
    @actions << ["finish"] if @facts["role"]
    @facts = @facts.merge("role" => nil, "bid" => nil, "seats" => [], "coop" => false, "running" => false, "kind" => nil)
    @match.answer("coop.frame", @facts)
  end

  # Splits the reason the scripts recorded into the reasons before and after the player's request.
  #
  # @return [Array] The reasons.
  def busy
    reason = @told["prompt"]["busy"]
    return [nil, nil] if reason.nil? || reason == "the player waits for an answer"

    BUSY_BEFORE.include?(reason) ? [reason, nil] : [nil, reason]
  end

  # Runs a frame on the map for the join prompt as the scripts' on_map does.
  def prompt
    prompt = @told["prompt"]
    answer = @asks.answer("coop.join_frame", "facts" => @facts, "reads" => true, "pressed" => @args["pressed"], "changing" => @args["changing"], "busy" => busy,
                                             "sides" => prompt["sides"], "freeze" => prompt["freeze"])
    side = answer["side"]
    if @args["pressed"] && !@args["changing"] && !answer["asked"] && side
      @world.log("join battle: fights #{side[2]} (troop #{side[0]}) in a side battle alongside a full boss battle near the player")
      @actions << ["side", side[0], side[1]]
      side = nil
    elsif @args["pressed"] && !@args["changing"] && !answer["asked"] && answer["target"].nil? && answer["freeze"]
      @actions << ["freeze", answer["freeze"][0]]
    end
    text = if answer["target"] then "Press J to join battle"
           elsif side then "Press J to fight #{side[2]} alongside"
           elsif answer["freeze"] then "Press J to fight #{answer['freeze'][1]}"
           end
    @result = { "text" => text, "asking" => @asks.state["join_waits"] }
  end
end

# Replays the golden scenarios of asking a running battle and joining one by choice on the stand-in.
def check_ask_stand_in
  JSON.parse(File.read(File.join(COOP_FIXTURES, "asks.json"), :encoding => "UTF-8"))["scenarios"].each do |scenario|
    replay = AskReplay.new
    scenario["steps"].each_with_index do |step, index|
      found = replay.run(step)
      raise "the asking stand-in differs at step #{index} of #{scenario['name']}: #{found.inspect}\nexpected #{step['outcome'].inspect}" unless found == step["outcome"]
    end
  end
end

check_ask_stand_in
