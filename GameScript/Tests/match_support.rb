#----------------------------------------------------------------
#  match_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Wrote the scripts' rates and invite fields and read the messages it hands them by their kinds, as CoopRoomTopics does
#                            - Invited a busy party member too in a Classic world, as Sessions in C# names them
#                            - Kept a Classic battle nobody joined open for a party member on the map who missed it
#                            - Kept an invite waiting while the player types in the chat box
#      Paulinchen  2026-10-30: Shared the world, the facts and the status with the asking and joining sides
#                            - Stood in for the invites, the requests to lead and the rivals, and for the routes of their messages
#                            - Created
#
#----------------------------------------------------------------

# The DLL's co-op matchmaking (MGQOnline.Game's CoopMatchmaking, behind CoopRoomTopics) for the
# script tests: MatchStandIn answers the matchmaking's topics as the DLL does, over a world that
# tells the players, the party and the time, and sends, logs and shows what the DLL would; it takes
# the co-op messages CoopRoomTopics' routes take (see MatchStandIn#route). check_match_stand_in
# replays the golden scenarios of fixtures/coop/match.json and invites.json, which battles_coop.rbx
# played before the rules left it, on the stand-in, so it cannot drift from what C# answers.

require "json"

# Stands in for the matchmaking, each topic's request in, its reply out.
class MatchStandIn
  # Frames a random encounter waits for the party members on the map who are busy.
  HOLD_FRAMES = 180

  # Seconds a party member on the map stands still at most once another member met enemies.
  FREEZE_SECONDS = 10

  # Tiles within which another player on the map counts as near.
  NEARBY_TILES = 20

  # The players of a battle in a Raid World at most.
  RAID_PLAYERS = 4

  # What another player does, by their state's scene, while they may be invited.
  FREE_SCENES = %w(map event away)

  # What another player in a Raid World does, by their state's scene, while they may be invited.
  RAID_FREE_SCENES = %w(map away)

  # What another player in a Raid World does, by their state's scene, while they fight a battle.
  RAID_BATTLE_SCENES = %w(battle away)

  # Seconds an invite or a request to lead waits for the player at most.
  ACCEPT_SECONDS = 3

  # Frames a member waits for the party's leader to lead their battle.
  LEADER_FRAMES = 360

  # The reason of an "off" whose battle is over.
  OFF_OVER = "over"

  # What a guest whose battle ended before they joined is told.
  MISSED_TEXT = "%s's battle ended before you could join."

  # What a guest whose battle could not take them in is told.
  CLOSED_TEXT = "%s's battle could not take you in."

  # The co-op messages the matchmaking takes itself.
  OWN_KINDS = %w(invite lead no_lead soon freeze)

  # What starts the matchmaking's log lines.
  TAG = "co-op battle: "

  # The topics the stand-in answers.
  TOPICS = %w(coop.offer coop.host coop.poll coop.frame coop.release coop.steps coop.freeze_party coop.raid_candidates coop.take_off coop.leader_wait
              coop.leader_end coop.yield coop.decline_waiting coop.refuse_lead coop.clear coop.drop)

  # The asking and joining sides beside the matchmaking (AskStandIn), nil without them: they tell
  # the running battle the player asks and the one they gave up on, bring their part of the status,
  # and settle the request to join with each frame on the map.
  attr_accessor :asks

  # Makes the matchmaking of a world.
  #
  # @param world [Object] The world: in_world?, raid?, own_seat, own_since, own_id, peers, party_id, members,
  #   leader (:me, a peer or nil), in_party?, at(seat), send(seat, fields), log(line), notice(key,
  #   seat, text, frames), drop_notice(key, seat, reason), now (seconds), rand and new_id.
  def initialize(world)
    @world = world
    @facts = {}
    @hold = nil
    @frozen_at = nil
    @freezers = []
    @frozen = false
    @random_encounter = false
    @requester = nil
    @invite = nil
    @request = nil
    @asking = nil
    @rival = nil
    @awaited = nil
    @dropped_bid = nil
    @logged_once = []
  end

  # Answers a topic.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    take_facts(request["facts"]) if request.is_a?(Hash) && request["facts"]
    case topic
    when "coop.offer" then status(offer(request))
    when "coop.host" then status(host(request, request["bid"]))
    when "coop.poll" then status(poll_and_settle(asked_of(request)))
    when "coop.frame" then take_facts(request) && nil
    when "coop.release" then release(Array(request["seats"]), asked_of(request)) && status([])
    when "coop.steps" then steps(request["steps"])
    when "coop.freeze_party" then freeze_party(Array(request["seats"])) && nil
    when "coop.raid_candidates" then raid_candidates(Array(request["viewers"]), Array(request["stays_out"])).map(&:seat)
    when "coop.take_off" then status((peer = @world.at(request["seat"])) ? take_off(peer, fields_written(request["fields"])) : [])
    when "coop.leader_wait" then leader_wait
    when "coop.leader_end" then leader_end(request.to_s)
    when "coop.yield" then status(yield_battle)
    when "coop.decline_waiting" then decline_waiting(request.to_s) && status([])
    when "coop.refuse_lead" then (peer = @world.at(request["seat"])) && refuse_lead(peer, request["bid"], request["reason"]) && nil
    when "coop.clear" then clear && status([])
    when "coop.drop" then drop && status([])
    end
  end

  # Takes the facts the game tells, with the running battle the player asks and the one they gave up
  # on, which the asking and joining sides know themselves.
  #
  # @param facts [Hash] The facts.
  # @return [true] Always.
  def take_facts(facts)
    @facts = @asks ? facts.merge("hot_ask" => @asks.battle, "gave_up" => @asks.gave_up) : facts
    true
  end

  # Tells the players a request to join a running battle brings along.
  #
  # @param request [Hash] The request, whose "asked" counts without the asking side.
  # @return [Array<Integer>] The seats.
  def asked_of(request)
    @asks ? @asks.asked_seats : Array(request["asked"])
  end

  # Runs a frame on the map and settles the request to join by choice, as coop.poll does.
  #
  # @param asked [Array<Integer>] The seats a request to join a running battle brings along.
  # @return [Array<Hash>] The actions.
  def poll_and_settle(asked)
    actions = poll(asked)
    @asks.settle if @asks
    actions
  end

  # Writes the status the scripts keep, with the actions they take.
  #
  # @param actions [Array<Hash>] The actions.
  # @return [Hash] "actions" and the status.
  def status(actions)
    { "actions" => actions }.merge(state)
  end

  # Writes the status the scripts keep, as CoopRoomTopics' coop.status event carries it.
  #
  # @return [Hash] "holding", "frozen", "busy", "waiting", "rival", "asking", "requested" and "waits".
  def state
    waiting = @invite && { "seat" => @invite[:peer].seat, "bid" => @invite[:message]["bid"].to_s, "map" => @invite[:message]["map"].to_s }
    status = { "holding" => !@hold.nil?, "frozen" => @frozen, "busy" => @world.raid? && (@facts["trading"] || @facts["coming"]) ? true : false, "waiting" => waiting,
               "rival" => !@rival.nil?, "asking" => !@asking.nil?, "requested" => !@request.nil?, "waits" => waits_for_player }
    @asks ? status.merge(@asks.state) : status
  end

  # Makes an action for the scripts.
  #
  # @param kind [String] What.
  # @param fields [Hash] Its other fields.
  # @return [Hash] The action.
  def action(kind, fields = {})
    made = { "kind" => kind, "role" => nil, "bid" => nil, "seats" => nil, "label" => nil, "seat" => nil, "troop" => nil, "escape" => false, "lose" => false,
             "fields" => nil }.merge(fields)
    made["fields"] = fields_read(made["fields"]) if made["fields"]
    made
  end

  # Decides a battle the game set up, as CoopMatchmaking.Offer does.
  #
  # @param offer [Hash] The battle.
  # @return [Array<Hash>] The actions.
  def offer(offer)
    actions = []
    thaw("the player's own battle begins")
    @rival = nil
    return actions if offer["joining"] || !host_possible?(offer["troop"])
    if offer["encountering"] && !busy_members.empty?
      hold(offer)
      return actions << action("held")
    end

    @random_encounter = offer["encounter"] ? true : false
    leading = offer["leading"]
    @requester = leading && leading[0]
    if @world.raid?
      return actions << action("ask_hot") if offer["encounter"] && @invite.nil? && !offer["asked_hot"]

      if offer["side"]
        log("fights the side battle against troop #{offer['troop']} as the player's own, inviting nobody: others may join it by choice")
      else
        log("hosts the battle against troop #{offer['troop']}: the player started it in a Raid World")
        actions.concat(host(offer, nil))
      end
      actions << action("fight_alone")
      answer_waiting_invite
      return actions
    end

    leader = @world.leader
    return ask_leader(leader, offer) if @requester.nil? && leader.respond_to?(:seat) && candidates.any? { |peer| peer.equal?(leader) }

    log("hosts the battle against troop #{offer['troop']}: #{host_reason(leader)}")
    actions.concat(host(offer, leading && leading[1]))
    return actions if actions.any? { |step| step["kind"] == "join" } || @world.members.none? { |peer| on_map?(peer) }

    log("keeps the battle against troop #{offer['troop']} open as the player's own: a party member on the map who missed it may join it late")
    actions << action("fight_alone")
  end

  # Hosts a battle, as CoopMatchmaking.Host does.
  #
  # @param offer [Hash] The battle.
  # @param battle_id [String, nil] The id the member who asked chose.
  # @return [Array<Hash>] The actions.
  def host(offer, battle_id)
    raid = @world.raid?
    if raid && offer["pools_won"]
      log("invites nobody to the battle against troop #{offer['troop']}: the raid boss's pools are all empty, so it is won at once")
      return []
    end

    seats = invitees(offer).map(&:seat)
    seats |= [@requester] if @requester
    waiting = @invite && { "seat" => @invite[:peer].seat, "hot" => @invite[:message]["hot"] == "1", "expired" => expired?(@invite), "rival" => waiting_rival? }
    seats = with_waiting_host(seats, waiting) if raid
    if seats.empty? && !(raid && waiting && waiting["rival"])
      log("nobody to invite on map #{@facts['map']}: #{nobody_text}")
      return []
    end

    id = battle_id || @world.new_id
    join = action("join", "role" => "host", "bid" => id, "seats" => seats, "label" => raid ? "the players" : "the party")
    @facts = @facts.merge("role" => "host", "bid" => id, "seats" => seats, "coop" => true, "running" => true, "kind" => "coop")
    freeze_party(seats)
    fields = [["bid", id], ["troop", offer["troop"].to_s], ["escape", offer["escape"] ? "1" : "0"], ["lose", offer["lose"] ? "1" : "0"],
              ["seats", seats.join(",")], ["map", @facts["map"].to_s]]
    if raid
      fields << ["enc", @random_encounter ? "1" : "0"]
      fields << ["boss", "1"] if offer["boss"]
      fields << ["rates", field_text("rates", offer["rates"])]
    end
    fields = merged(fields, offer["invite_fields"])
    raid ? tell_map(seats, "invite", fields) : tell(-1, "invite", fields)
    log("invited #{seats.size} #{raid ? 'player' : 'member'}(s) to battle #{id} against troop #{offer['troop']} on map #{@facts['map']}: #{seats.map { |seat| who_seat(seat) }.join(', ')}")
    [join]
  end

  # Runs a frame on the map, as CoopMatchmaking.Poll does.
  #
  # @param asked [Array<Integer>] The seats a request to join a running battle brings along.
  # @return [Array<Hash>] The actions.
  def poll(asked)
    if @hold.nil?
      @frozen = still_frozen
      return serve
    end

    @hold[:frames] -= 1
    waiting = busy_members.select { |peer| @hold[:seats].include?(peer.seat) }
    return [] unless waiting.empty? || @hold[:frames] <= 0

    held = @hold
    drop_hold
    offer = held[:offer]
    if @facts["interpreter"]
      release(Array(held[:frozen]), asked)
      log("dropped the held encounter with troop #{offer['troop']} for an event")
      return []
    end

    log("starts the held encounter with troop #{offer['troop']}: #{waiting.empty? ? 'every busy member is back on the map' : "the wait ran out, #{waiting.map { |peer| who(peer) }.join(', ')} still busy"}")
    [action("start_held", "seats" => held[:frozen], "troop" => offer["troop"], "escape" => offer["escape"] ? true : false, "lose" => offer["lose"] ? true : false)]
  end

  # Leads a member's battle or joins an invite once the player is free.
  #
  # @return [Array<Hash>] The actions.
  def serve
    if @request
      lead = serve_request
      return lead unless lead.empty?
    end
    @invite ? serve_invite : []
  rescue => e
    @invite = nil
    @request = nil
    log("joining a co-op battle failed: #{e.class}: #{e.message}")
    []
  end

  # Lets the players a held encounter froze walk on, those its battle does not invite.
  #
  # @param seats [Array<Integer>] The seats it froze.
  # @param asked [Array<Integer>] The seats a request to join a running battle brings along.
  # @return [true] Always.
  def release(seats, asked)
    invited = @facts["role"] == "host" && @facts["coop"] ? Array(@facts["seats"]) : asked
    left = (seats - invited).uniq
    tell_map(left, "off", [["map", @facts["map"].to_s]]) unless left.empty?
    true
  end

  # Stretches the steps to the next random encounter, as CoopMatchmaking.Steps does.
  #
  # @param hundredths [Integer] The steps the game drew, in hundredths.
  # @return [Integer] The steps the player takes, in hundredths.
  def steps(hundredths)
    return hundredths unless @world.raid? || @world.in_party?

    players = @world.raid? ? [peers_on_map.count { |peer| near?(peer) } + 1, RAID_PLAYERS].min : @world.members.count { |peer| near?(peer) } + 1
    return hundredths if players < 2

    steps = hundredths / 100.0
    stretched = steps * 1.5 * (0.75 + @world.rand * 0.5)
    log("drew #{stretched.round} steps to the next random encounter instead of #{steps.round}: #{players} #{@world.raid? ? 'players' : 'party members'} near on the map")
    (stretched * 100).round
  end

  # Tells the player for a moment that a member's battle waits for them.
  #
  # @param peer [Object] The member.
  # @return [nil] Nothing.
  def take_soon(peer)
    @world.notice("soon", peer.seat, "#{peer.state['name']} is in a battle!", HOLD_FRAMES) if peer
    nil
  end

  # Holds the player for a member's battle on their map, as CoopMatchmaking.TakeFreeze does.
  #
  # @param peer [Object] The member.
  # @param map [String] The member's map.
  # @return [true] Always.
  def take_freeze(peer, map)
    return true unless peer
    return log("not standing still for #{who(peer)}: their map #{map} is not the player's #{@facts['map']}") || true unless map.to_i == @facts["map"]
    return log("not standing still for #{who(peer)}: the player is in a battle") || true if @facts["role"] || @facts["battle_scene"]

    @freezers = [] unless @frozen_at
    @freezers |= [peer.seat]
    @frozen_at = @world.now
    @frozen = true
    @world.notice("soon", peer.seat, "Enemies! #{peer.state['name']} is in a battle.", FREEZE_SECONDS * 60)
    log("stands still up to #{FREEZE_SECONDS} s: #{who(peer)} met enemies on map #{@facts['map']}")
    true
  end

  # Lets the player walk on.
  #
  # @param reason [String] Why.
  # @return [true] Always.
  def thaw(reason)
    seats = @freezers
    @frozen_at = nil
    @frozen = false
    @freezers = []
    seats.each { |seat| @world.drop_notice("soon", seat, reason) }
    true
  end

  # Lets the player walk on once a host called their battle off, unless another holds them.
  #
  # @param peer [Object] The host.
  # @param other_invite [Boolean] Whether another host's invite waits.
  # @return [true] Always.
  def unfreeze_for(peer, other_invite)
    return true unless peer

    @freezers -= [peer.seat]
    @world.drop_notice("soon", peer.seat, "the battle was called off")
    return log("still stands still after #{who(peer)} called their battle off: another battle holds the player") || true if (!@freezers.empty? || other_invite) && @frozen_at

    thaw("#{who(peer)} called their battle off")
  end

  # Forgets the held encounter, the stand-still, the battle set up and what waits, as a reset does.
  #
  # @return [true] Always.
  def drop
    drop_hold
    clear
    @asking = nil
    @invite = nil
    @request = nil
    @asks.drop if @asks
    thaw("a reset forgets it")
  end

  # Tells the party, or the players a Raid World's battle takes, to stand still.
  #
  # @param seats [Array<Integer>] The players a Raid World's battle takes.
  # @return [true] Always.
  def freeze_party(seats)
    fields = [["map", @facts["map"].to_s]]
    @world.raid? ? tell_map(seats, "freeze", fields) : tell(-1, "freeze", fields)
    true
  end

  # Lists the players a battle in a Raid World takes, as CoopMatchmaking.RaidCandidates does.
  #
  # @param viewers [Array<Integer>] The seats of the players reading the player's story.
  # @param stays_out [Array<Integer>] The seats of the members who stay out.
  # @return [Array] The players.
  def raid_candidates(viewers, stays_out)
    members = @world.members
    x, y = raid_center
    free = peers_on_map.select { |peer| (raid_free?(peer) && near?(peer)) || watching?(peer, viewers) }.reject { |peer| stays_out.include?(peer.seat) }
    free.sort_by { |peer| [members.any? { |member| member.equal?(peer) } ? 0 : 1, distance(peer, x, y), peer.state["id"].to_s] }.first(RAID_PLAYERS - 1)
  end

  # Ages the stand-still, as if seconds passed since it began.
  #
  # @param seconds [Numeric] The seconds.
  def age_freeze(seconds)
    @frozen_at -= seconds if @frozen_at
  end

  # Ages the invite and the request that wait, as if seconds passed since they came.
  #
  # @param seconds [Numeric] The seconds.
  def age_waits(seconds)
    @invite[:at] -= seconds if @invite
    @request[:at] -= seconds if @request
  end

  # @return [String, nil] The battle id of the invite that waits.
  def waiting_bid
    @invite && @invite[:message]["bid"]
  end

  # @return [String, nil] The battle id of the rival's invite kept.
  def rival_bid
    @rival && @rival[:message]["bid"]
  end

  # @return [Integer, nil] The seat of the rival kept.
  def rival_seat
    @rival && @rival[:peer].seat
  end

  # @return [String, nil] The battle id of the request to lead that waits.
  def request_bid
    @request && @request[:message]["bid"]
  end

  # Takes a co-op message as CoopRoomTopics' routes do: the matchmaking's own kinds itself, the rest
  # left to the scripts; one through the map's gate outside a Raid World is dropped.
  #
  # @param peer [Object] Who sent it.
  # @param message [Hash] Its fields, its kind under "coop" (and "map_coop" through the map's gate).
  # @param map [Boolean] Whether it came through the map's gate.
  # @return [Boolean] Whether the matchmaking took it, so the scripts do not.
  def route(peer, message, map = false)
    if map && !@world.raid? && !(peer.member && late_join?(message))
      drop_map(peer, (message["map_coop"] || message["coop"]).to_s)
      return true
    end
    return false unless OWN_KINDS.include?(message["coop"].to_s)

    take_message(peer, message)
    true
  end

  # Reports whether a co-op message belongs to a party member's late join by choice in a Classic
  # world, as CoopRoomTopics.LateJoin does.
  #
  # @param message [Hash] The message.
  # @return [Boolean] Whether it does.
  def late_join?(message)
    kind = (message["map_coop"] || message["coop"]).to_s
    %w(pick pick_no off).include?(kind) || (kind == "invite" && message["hot"].to_s == "1")
  end

  # Takes a co-op message the matchmaking handles, as CoopMatchmaking.TakeMessage does.
  #
  # @param peer [Object] Who sent it.
  # @param message [Hash] Its fields, its kind under "coop".
  def take_message(peer, message)
    kind = message["coop"].to_s
    log("took #{kind} from #{who(peer)}: #{message.reject { |key, _| key == 'coop' }.map { |key, value| "#{key}=#{value}" }.join(' ')}")
    case kind
    when "invite" then take_invite(peer, message)
    when "lead" then take_request(peer, message)
    when "no_lead" then answer_of(peer, message, "refused")
    when "soon" then take_soon(peer)
    when "freeze" then take_freeze(peer, message["map"])
    end
  rescue => e
    log("taking a co-op message failed: #{e.class}: #{e.message}")
  end

  # Logs once per kind and player a co-op message through the map's gate outside a Raid World.
  #
  # @param peer [Object, nil] Who sent it.
  # @param kind [String] Its kind.
  def drop_map(peer, kind)
    key = ["map_gate", kind, peer && peer.state["id"].to_s]
    return if @logged_once.include?(key)

    @logged_once << key
    log("dropped #{kind} from #{who(peer)} through the map's gate: not a Raid World")
  end

  # Takes a host's word that their battle is off, as CoopMatchmaking.TakeOff does.
  #
  # @param peer [Object] The host.
  # @param message [Hash] The message.
  # @return [Array<Hash>] The actions.
  def take_off(peer, message)
    bid = message["bid"].to_s
    unfreeze_for(peer, !@invite.nil? && !same?(@invite[:peer], peer))
    if @invite && same?(@invite[:peer], peer) && @invite[:message]["bid"] == bid
      @invite = nil
      log("forgot #{who(peer)}'s invite to battle #{bid}: it is off")
      return []
    end
    if @rival && same?(@rival[:peer], peer) && @rival[:message]["bid"] == bid
      @rival = nil
      log("forgot #{who(peer)}'s rival battle #{bid}: it is off, the player's own goes on")
      return []
    end
    return [] unless @facts["role"] == "guest" && @facts["bid"] == bid && !@facts["active"]

    text = off_text(peer, message)
    return [action("call_off_own", "label" => text)] if @facts["own_troop"]
    return follow if @invite

    text ? [action("miss", "label" => text)] : [action("break_off", "label" => "#{who(peer)} gave battle #{bid} up for another")]
  end

  # Counts a frame of the wait for the party's leader, as CoopMatchmaking.LeaderWait does.
  #
  # @return [String, nil] The answer, nil while the wait lasts.
  def leader_wait
    return "silent" unless @asking

    @asking[:frames] += 1
    @asking[:answer] || (@asking[:frames] >= LEADER_FRAMES ? "silent" : nil)
  end

  # Ends the wait for the party's leader, as CoopMatchmaking.LeaderEnd does.
  #
  # @param answer [String] How it ended.
  # @return [Hash, nil] The battle the player hosts instead, nil for none.
  def leader_end(answer)
    ask = @asking
    return nil unless ask

    @asking = nil
    return log("#{ask[:name]} leads battle #{ask[:bid]}") if answer == "leads"

    @dropped_bid = ask[:bid]
    log("#{ask[:name]} does not lead battle #{ask[:bid]} (#{answer}), the player hosts it")
    { "troop" => ask[:offer]["troop"], "escape" => ask[:offer]["escape"] ? true : false, "lose" => ask[:offer]["lose"] ? true : false }
  end

  # Gives the player's battle up for the rival's, as CoopMatchmaking.Yield does.
  #
  # @return [Array<Hash>] The actions.
  def yield_battle
    kept = @rival
    return [] unless kept

    @rival = nil
    own_bid = @facts["bid"].to_s
    tell_map(Array(@facts["seats"]), "off", [["bid", own_bid]])
    @awaited = kept
    log("gave battle #{own_bid} up and joins #{who(kept[:peer])}'s battle #{kept[:message]['bid']} against troop #{kept[:message]['troop']} as a guest")
    [action("yield", "seat" => kept[:peer].seat, "label" => kept[:peer].state["name"].to_s, "fields" => kept[:message])]
  end

  # Turns down the invite that waits, as CoopMatchmaking.DeclineWaiting does.
  #
  # @param reason [String] Why.
  # @return [true] Always.
  def decline_waiting(reason)
    decline(@invite[:peer], @invite[:message], reason) if @invite
    true
  end

  # Refuses to lead a member's battle, as CoopMatchmaking.RefuseLead does.
  #
  # @param peer [Object] The member.
  # @param bid [String] The battle's id.
  # @param reason [String] Why.
  def refuse_lead(peer, bid, reason)
    @request = nil
    tell(peer.seat, "no_lead", [["bid", bid.to_s]])
    log("could not lead #{peer.state['name']}'s battle #{bid}: #{reason}")
  end

  # Forgets the battle that ended, as CoopMatchmaking.Clear does.
  #
  # @return [true] Always.
  def clear
    @rival = nil
    @awaited = nil
    @random_encounter = false
    @requester = nil
    true
  end

  # Names what waits for the player, as CoopMatchmaking.WaitsForPlayer does.
  #
  # @return [String, nil] What waits.
  def waits_for_player
    return "#{who(@invite[:peer])}'s battle invite" if @invite && @facts["role"].nil?

    @request ? "#{who(@request[:peer])}'s request to lead a battle" : nil
  end

  private

  # Reports whether two players are the same one.
  #
  # @param peer [Object] A player.
  # @param other [Object] Another.
  # @return [Boolean] Whether they are.
  def same?(peer, other)
    peer.seat == other.seat && peer.state["id"].to_s == other.state["id"].to_s
  end

  # Merges the fields the raid bosses add into an invite's.
  #
  # @param fields [Array<Array>] The fields.
  # @param added [Array<Array>, nil] The added fields.
  # @return [Array<Array>] The fields.
  def merged(fields, added)
    Array(added).each do |key, value|
      at = fields.index { |field| field[0] == key }
      at ? fields[at] = [key, field_text(key, value)] : fields << [key, field_text(key, value)]
    end
    fields
  end

  # Sends a battle message, such as a decline, as CoopMatchmaking.TellBattle does.
  #
  # @param seat [Integer] The game's seat.
  # @param kind [String] What it is.
  # @param bid [String] The battle's id.
  def tell_battle(seat, kind, bid)
    @world.send(seat, [["battle", kind], ["bid", bid.to_s]])
  end

  # Reports whether an invite or a request waited too long.
  #
  # @param kept [Hash] The invite or request, :at when it came.
  # @return [Boolean] Whether it did.
  def expired?(kept)
    @world.now - kept[:at] > ACCEPT_SECONDS
  end

  # Reports whether the player may join a battle.
  #
  # @return [Boolean] Whether they may.
  def free?
    !@facts["interpreter"] && !@facts["transfer"] && !@facts["moving"] && !@facts["typing"]
  end

  # Reports whether a battle hosts first, see CoopMatchmaking.HostsFirst.
  #
  # @param peer [Object] The first battle's host.
  # @param message [Hash] The first battle's invite.
  # @param other [Object] The other battle's host.
  # @param other_message [Hash] The other battle's invite.
  # @return [Boolean] Whether it does.
  def hosts_first?(peer, message, other, other_message)
    event = message["enc"] == "0"
    return event if event != (other_message["enc"] == "0")

    earlier?(peer, other)
  end

  # Reports whether a player entered the map first.
  #
  # @param player [Object, nil] The player, nil for the player of this game.
  # @param other [Object, nil] The other, nil for the player of this game.
  # @return [Boolean] Whether they did.
  def earlier?(player, other)
    key = lambda { |who| who.nil? ? [@world.own_since, @world.own_id] : [who.state["since"].to_i, who.state["id"].to_s] }
    (key.call(player) <=> key.call(other)) < 0
  end

  # Reports whether a gathering battle yields to another, see CoopMatchmaking.YieldsTo.
  #
  # @param random [Boolean] Whether the battle is a random encounter.
  # @param holder [Object, nil] The battle's host, nil for the player.
  # @param peer [Object] The other battle's host.
  # @param message [Hash] The other battle's invite.
  # @return [Boolean] Whether it does.
  def yields_to?(random, holder, peer, message)
    return false unless random && message["hot"] != "1"
    return false unless message["map"].to_i == @facts["map"] && message["seats"].to_s.split(",").size < RAID_PLAYERS

    message["enc"] == "0" || earlier?(peer, holder)
  end

  # Reports whether an invite comes from a rival, whether or not the player hosts yet.
  #
  # @param peer [Object] Who invites.
  # @param message [Hash] The invite.
  # @return [Boolean] Whether it does.
  def rival_battle?(peer, message)
    @world.raid? && !@facts["active"] && yields_to?(@random_encounter, nil, peer, message)
  end

  # Reports whether an invite comes from a rival the player's hosted battle yields to.
  #
  # @param peer [Object] Who invites.
  # @param message [Hash] The invite.
  # @return [Boolean] Whether it does.
  def rival?(peer, message)
    @facts["role"] == "host" && @facts["coop"] && message["bid"].to_s != @facts["bid"].to_s && rival_battle?(peer, message)
  end

  # Reports whether the invite that waits comes from a rival.
  #
  # @return [Boolean] Whether it does.
  def waiting_rival?
    @world.raid? && !@invite.nil? && rival_battle?(@invite[:peer], @invite[:message])
  end

  # Answers the invite that waited as the player's battle began: keeps a rival's, turns others down.
  def answer_waiting_invite
    invite = @invite
    return unless invite

    @invite = nil
    return keep_rival(invite[:peer], invite[:message]) if rival?(invite[:peer], invite[:message])

    decline(invite[:peer], invite[:message], "the player began a battle of their own")
  end

  # Keeps a rival's invite, of two the one who hosts first.
  #
  # @param peer [Object] The rival.
  # @param message [Hash] The invite.
  def keep_rival(peer, message)
    kept = @rival
    bid = message["bid"].to_s
    if kept && same?(kept[:peer], peer) && kept[:message]["bid"].to_s == bid
      return log("kept #{who(peer)}'s invite to battle #{message['bid']} once: it came again")
    end
    if kept && hosts_first?(kept[:peer], kept[:message], peer, message)
      log("declined #{who(peer)}'s invite to battle #{message['bid']}: an earlier rival or an event's hosts first")
      return tell_battle(peer.seat, "decline", bid)
    end
    if kept
      log("declined #{who(kept[:peer])}'s invite to battle #{kept[:message]['bid']}: #{who(peer)} hosts first")
      tell_battle(kept[:peer].seat, "decline", kept[:message]["bid"].to_s)
    end

    @rival = { :peer => peer, :message => message, :at => @world.now }
    log("#{who(peer)}'s battle #{message['bid']} started at the same moment as the player's battle #{@facts['bid']}, and #{message['enc'] == '0' ? "it is an event's" : 'they entered the map first'}: the player joins theirs")
  end

  # Reports whether a guest keeps another host's invite to follow it, see CoopMatchmaking.Follows.
  #
  # @param peer [Object] Who invites.
  # @param message [Hash] The invite.
  # @return [Boolean] Whether they do.
  def follows?(peer, message)
    awaited = @awaited
    return false unless @world.raid? && awaited && @facts["role"] == "guest" && @facts["coop"] && !@facts["active"] && !@facts["late"]
    return false unless awaited[:message]["bid"].to_s == @facts["bid"].to_s && !same?(awaited[:peer], peer)

    yields_to?(awaited[:message]["enc"] == "1", awaited[:peer], peer, message)
  end

  # Moves the player to the battle of the invite they kept.
  #
  # @return [Array<Hash>] The actions.
  def follow
    kept = @invite
    @invite = nil
    @awaited = kept
    log("follows to #{who(kept[:peer])}'s battle #{kept[:message]['bid']} against troop #{kept[:message]['troop']}, which the player's host yielded to")
    [action("follow", "seat" => kept[:peer].seat, "label" => kept[:peer].state["name"].to_s, "fields" => kept[:message])]
  end

  # Tells the player why a running battle called their joining off.
  #
  # @param peer [Object] The host.
  # @param message [Hash] The "off", its reason under "why".
  # @return [String, nil] The text, nil without a reason.
  def off_text(peer, message)
    why = message["why"].to_s
    return nil if why.empty?

    (why == OFF_OVER ? MISSED_TEXT : CLOSED_TEXT) % peer.state["name"].to_s
  end

  # Takes an invite, as CoopMatchmaking.TakeInvite does.
  #
  # @param peer [Object] The host.
  # @param message [Hash] The invite.
  def take_invite(peer, message)
    bid = message["bid"].to_s
    return log("invite to battle #{message['bid']} ignored: it is for seats #{message['seats']}, not the player's") unless message["seats"].to_s.split(",").map(&:to_i).include?(@world.own_seat)
    return answer_of(peer, message, "leads") if asked?(peer, message)

    hot = @facts["hot_ask"]
    return log("ignored #{who(peer)}'s invite to battle #{message['bid']}: the player's own request to join it brings them") if hot && hot[0] == peer.seat && hot[1] == bid && message["hot"] == "1"

    gave_up = @facts["gave_up"]
    return log("ignored #{who(peer)}'s late invite to battle #{message['bid']}: the player stopped waiting for it") if gave_up && gave_up[0] == peer.seat && gave_up[1] == bid && message["hot"] == "1"
    return keep_rival(peer, message) if rival?(peer, message)

    reason = if @asking then "the player waits for the leader to lead battle #{@asking[:bid]}"
             elsif message["bid"] == @dropped_bid then "a late invite to a battle the player hosts instead"
             elsif follows?(peer, message) then nil
             elsif @facts["role"] then "the player is in a multiplayer battle (#{@facts['role']})"
             elsif @facts["battle_scene"] then "the player is in a battle"
             end
    if reason
      log("declined #{who(peer)}'s invite to battle #{message['bid']} at once: #{reason}")
      return tell_battle(peer.seat, "decline", bid)
    end
    return if @world.raid? && keeps_waiting_invite?(peer, message)

    log("replaced the waiting invite to battle #{@invite[:message]['bid']} with #{who(peer)}'s") if @invite
    @invite = { :peer => peer, :message => message, :at => @world.now }
    until_text = @facts["role"] ? "until the player's host gives battle #{@facts['bid']} up" : "until the player is free, #{ACCEPT_SECONDS} s at most"
    log("keeps #{who(peer)}'s invite to battle #{message['bid']} against troop #{message['troop']} on map #{message['map']} #{until_text}")
  end

  # Keeps of two invites in a Raid World the one whose host hosts first.
  #
  # @param peer [Object] The new invite's host.
  # @param message [Hash] The new invite.
  # @return [Boolean] Whether the waiting one stays.
  def keeps_waiting_invite?(peer, message)
    waiting = @invite
    return false if waiting.nil? || waiting[:message]["bid"] == message["bid"]

    if !expired?(waiting) && hosts_first?(waiting[:peer], waiting[:message], peer, message)
      log("declined #{who(peer)}'s invite to battle #{message['bid']}: #{who(waiting[:peer])}'s waits, which hosts first")
      tell_battle(peer.seat, "decline", message["bid"].to_s)
      return true
    end
    log("declined #{who(waiting[:peer])}'s waiting invite to battle #{waiting[:message]['bid']}: #{who(peer)}'s came, which hosts first, or it waited too long")
    tell_battle(waiting[:peer].seat, "decline", waiting[:message]["bid"].to_s)
    false
  end

  # Keeps a member's request to lead their battle.
  #
  # @param peer [Object] The member.
  # @param message [Hash] The request.
  def take_request(peer, message)
    return refuse_lead(peer, message["bid"].to_s, "the player who starts a battle in a Raid World hosts it") if @world.raid?

    waiting = @request
    if waiting && !(same?(waiting[:peer], peer) && waiting[:message]["bid"] == message["bid"])
      refuse_lead(waiting[:peer], waiting[:message]["bid"].to_s, "a newer request from #{who(peer)} came")
    end
    @request = { :peer => peer, :message => message, :at => @world.now }
    log("keeps #{who(peer)}'s request to lead battle #{message['bid']} against troop #{message['troop']} on map #{message['map']} until the player is free, #{ACCEPT_SECONDS} s at most")
  end

  # Notes the leader's answer.
  #
  # @param peer [Object] Who answered.
  # @param message [Hash] The answer.
  # @param answer [String] "leads" or "refused".
  def answer_of(peer, message, answer)
    return log("#{answer} answer for battle #{message['bid']} from #{who(peer)} ignored: not the battle the player asked about") unless asked?(peer, message)

    @asking[:answer] = answer
    log("the leader #{who(peer)} answered for battle #{message['bid']}: #{answer}")
  end

  # Reports whether a message answers the player's request to lead.
  #
  # @param peer [Object] Who sent it.
  # @param message [Hash] The message.
  # @return [Boolean] Whether it does.
  def asked?(peer, message)
    !@asking.nil? && peer.seat == @asking[:seat] && message["bid"] == @asking[:bid]
  end

  # Asks the party's leader to lead the battle, as CoopMatchmaking.AskLeader does.
  #
  # @param leader [Object] The leader.
  # @param offer [Hash] The battle.
  # @return [Array<Hash>] The actions.
  def ask_leader(leader, offer)
    bid = @world.new_id
    name = leader.state["name"].to_s
    @asking = { :seat => leader.seat, :bid => bid, :name => name, :offer => offer, :answer => nil, :frames => 0 }
    join = action("join", "role" => "guest", "bid" => bid, "seats" => [leader.seat], "label" => name)
    @facts = @facts.merge("role" => "guest", "bid" => bid, "seats" => [leader.seat], "coop" => true, "running" => true, "kind" => "coop")
    freeze_party([])
    fields = [["bid", bid], ["troop", offer["troop"].to_s], ["escape", offer["escape"] ? "1" : "0"], ["lose", offer["lose"] ? "1" : "0"], ["map", @facts["map"].to_s]]
    tell(leader.seat, "lead", merged(fields, offer["invite_fields"]))
    log("asked the leader #{who(leader)} to lead battle #{bid} against troop #{offer['troop']} on map #{@facts['map']}, waiting up to #{LEADER_FRAMES / 60} s")
    [join]
  end

  # Leads a member's battle once the player is free, refusing it otherwise.
  #
  # @return [Array<Hash>] The actions.
  def serve_request
    asked = @request
    message = asked[:message]
    reason = if message["map"].to_i != @facts["map"] then "the player is on map #{@facts['map']}, not #{message['map']}"
             elsif @facts["role"] then "the player is in a multiplayer battle (#{@facts['role']})"
             elsif @world.leader != :me then "the player no longer leads the party"
             elsif expired?(asked) then "the player stayed busy for #{ACCEPT_SECONDS} s"
             elsif @facts["coming"] then "the player's story is about to bring them over"
             end
    if reason
      refuse_lead(asked[:peer], message["bid"].to_s, reason)
      return []
    end
    return [] unless free?

    @request = nil
    [action("lead", "seat" => asked[:peer].seat, "fields" => message)]
  end

  # Joins the invite that waits once the player is free, turning it down otherwise.
  #
  # @return [Array<Hash>] The actions.
  def serve_invite
    waiting = @invite
    message = waiting[:message]
    reason = if message["map"].to_i != @facts["map"] then "the player is on map #{@facts['map']}, not #{message['map']}"
             elsif @facts["role"] then "the player is in a multiplayer battle (#{@facts['role']})"
             elsif expired?(waiting) then "the player stayed busy for #{ACCEPT_SECONDS} s"
             elsif @facts["coming"] && !@facts["story"] then "the leader's story is about to bring the player over"
             elsif @world.raid? && @facts["trading"] then "the player trades"
             end
    if reason
      decline(waiting[:peer], message, reason)
      return []
    end
    return [] unless free?

    @invite = nil
    thaw("the player joins the battle")
    @awaited = waiting
    [action("accept", "seat" => waiting[:peer].seat, "label" => @facts["story"] ? "story" : nil, "fields" => message)]
  end

  # Turns an invite down.
  #
  # @param peer [Object] The host.
  # @param message [Hash] The invite.
  # @param reason [String] Why.
  def decline(peer, message, reason)
    @invite = nil
    thaw("the invite was turned down")
    log("declined #{who(peer)}'s invite to battle #{message['bid']}: #{reason}")
    tell_battle(peer.seat, "decline", message["bid"].to_s)
  end

  # Writes a line into the log, marked as the co-op battles'.
  #
  # @param line [String] The line.
  # @return [nil] Nothing.
  def log(line)
    @world.log(TAG + line)
    nil
  end

  # Names another player for the log.
  #
  # @param peer [Object, nil] The player.
  # @return [String] Their name and seat.
  def who(peer)
    peer ? "#{peer.state['name']} (seat #{peer.seat})" : "an unknown player"
  end

  # Names a player by their seat for the log.
  #
  # @param seat [Integer] The seat.
  # @return [String] Their name and seat.
  def who_seat(seat)
    return "the player (seat #{seat})" if seat == @world.own_seat

    peer = @world.at(seat)
    name = peer && peer.state["name"]
    name ? "#{name} (seat #{seat})" : "seat #{seat}"
  end

  # Sends a co-op message to one game or the party.
  #
  # @param seat [Integer] The game's seat, -1 for everyone.
  # @param kind [String] What it is.
  # @param fields [Array<Array>] Its other fields.
  def tell(seat, kind, fields)
    sent = @world.send(seat, [["coop", kind], ["party", @world.party_id.to_s]] + fields)
    log("sent #{kind} to #{seat == -1 ? 'the party' : who_seat(seat)}: #{fields.map { |key, value| "#{key}=#{value}" }.join(' ')}#{' (not sent)' unless sent}")
  end

  # Sends a co-op message to some players through the map's gate.
  #
  # @param seats [Array<Integer>] The players' seats.
  # @param kind [String] What it is.
  # @param fields [Array<Array>] Its other fields.
  def tell_map(seats, kind, fields)
    seats.each do |seat|
      sent = @world.send(seat, [["map_coop", kind], ["mmap", @facts["map"].to_s]] + fields)
      log("sent #{kind} through the map's gate to #{who_seat(seat)}: #{fields.map { |key, value| "#{key}=#{value}" }.join(' ')}#{' (not sent)' unless sent}")
    end
  end

  # Reports whether a battle starting now may become a co-op battle.
  #
  # @param troop [Integer] The troop.
  # @return [Boolean] Whether it may.
  def host_possible?(troop)
    return false unless @world.in_world?

    reason = if @world.party_id.nil? && !@world.raid? then "not in a party"
             elsif @facts["memory"] then "a Library replay"
             elsif @facts["pvp"] then "a PvP battle runs"
             elsif @facts["role"] || @facts["running"]
               "another multiplayer battle still runs (#{@facts['role'] ? ":#{@facts['role']}" : 'nil'}, #{@facts['kind'] ? ":#{@facts['kind']}" : 'nil'})"
             end
    log("no co-op battle against troop #{troop}: #{reason}") if reason
    reason.nil?
  end

  # Lists the players a battle the player hosts invites.
  #
  # @param offer [Hash] The battle.
  # @return [Array] The players.
  def invitees(offer)
    return @world.members.select { |peer| on_map?(peer) && peer.state["scene"] != "battle" } unless @world.raid?
    return [] if offer["pools_won"]

    raid_candidates(offer["boss"] ? Array(offer["viewers"]) : [], Array(offer["stays_out"]))
  end

  # Adds the host of a waiting invite to a Raid World's invites.
  #
  # @param seats [Array<Integer>] The seats.
  # @param waiting [Hash, nil] The invite that waits.
  # @return [Array<Integer>] The seats.
  def with_waiting_host(seats, waiting)
    return seats if waiting.nil? || waiting["hot"] || waiting["expired"] || waiting["rival"]

    ([waiting["seat"]] | seats).first(RAID_PLAYERS - 1)
  end

  # Tells what the others do while a battle invites nobody.
  #
  # @return [String] The text.
  def nobody_text
    others = @world.raid? ? peers_on_map : @world.members
    return @world.raid? ? "no other player on the map" : "no other party member" if others.empty?

    others.map { |peer| "#{peer.state['name']} on map #{peer.state['map']} (#{peer.state['scene']}#{', busy' if peer.state['busy'] == '1'})" }.join(", ")
  end

  # Tells why the player hosts instead of asking the leader.
  #
  # @param leader [Object] The leader.
  # @return [String] The reason.
  def host_reason(leader)
    return "the leader, asked by #{who_seat(@requester)}" if @requester
    return "the player leads the party" if leader == :me
    return "no party leader" unless leader

    "the leader #{who(leader)} is on map #{leader.state['map']} (#{leader.state['scene']})"
  end

  # Lists the party members on the map playing on it.
  #
  # @return [Array] The members.
  def candidates
    @world.members.select { |peer| on_map?(peer) && FREE_SCENES.include?(peer.state["scene"]) }
  end

  # Lists the party members on the map who could join once back on it.
  #
  # @return [Array] The members.
  def busy_members
    @world.members.select { |peer| on_map?(peer) && !FREE_SCENES.include?(peer.state["scene"]) && peer.state["scene"] != "battle" }
  end

  # Holds a random encounter for busy members.
  #
  # @param offer [Hash] The encounter.
  def hold(offer)
    busy = busy_members
    frozen = @world.raid? ? (raid_candidates([], Array(offer["stays_out"])) + busy).map(&:seat).uniq : nil
    @hold = { :offer => offer, :frames => HOLD_FRAMES, :seats => busy.map(&:seat), :frozen => frozen }
    busy.each { |peer| tell(peer.seat, "soon", [["map", @facts["map"].to_s]]) }
    freeze_party(Array(frozen))
    @world.notice("hold", nil, "Enemies! Waiting for #{busy.map { |peer| peer.state['name'].to_s }.join(', ')}", HOLD_FRAMES)
    log("held an encounter with troop #{offer['troop']} up to #{HOLD_FRAMES / 60} s for the busy members #{busy.map { |peer| "#{who(peer)} (#{peer.state['scene']})" }.join(', ')}")
  end

  # Forgets the held encounter.
  def drop_hold
    @hold = nil
    @world.drop_notice("hold", nil, nil)
  end

  # Tells whether the player still stands still, letting them walk on once the time ran out.
  #
  # @return [Boolean] Whether they do.
  def still_frozen
    return false unless @frozen_at
    return true if @world.now - @frozen_at < FREEZE_SECONDS

    reason = "no invite came within #{FREEZE_SECONDS} s"
    thaw(reason)
    log("stands still no more: #{reason}")
    false
  end

  # Tells the tile a Raid World's battle counts distances from.
  #
  # @return [Array<Integer>] The x and y.
  def raid_center
    leader = @world.in_party? ? @world.leader : nil
    return [leader.state["x"].to_i, leader.state["y"].to_i] if leader.respond_to?(:state) && on_map?(leader)

    [@facts["x"], @facts["y"]]
  end

  # Reports whether another player in a Raid World may be invited.
  #
  # @param peer [Object] The player.
  # @return [Boolean] Whether they may.
  def raid_free?(peer)
    RAID_FREE_SCENES.include?(peer.state["scene"]) && peer.state["busy"] != "1" && !(!peer.state["rb"].to_s.empty? && RAID_BATTLE_SCENES.include?(peer.state["scene"]))
  end

  # Reports whether another player reads the story the player tells.
  #
  # @param peer [Object] The player.
  # @param viewers [Array<Integer>] The seats of the readers.
  # @return [Boolean] Whether they do.
  def watching?(peer, viewers)
    peer.state["scene"] == "event" && peer.state["busy"] != "1" && viewers.include?(peer.seat)
  end

  # Lists the other players on the player's map whose connection stands.
  #
  # @return [Array] The players.
  def peers_on_map
    @world.peers.select { |peer| peer.away.nil? && on_map?(peer) }
  end

  # Reports whether another player stands on the player's map.
  #
  # @param peer [Object] The player.
  # @return [Boolean] Whether they do.
  def on_map?(peer)
    peer.state["map"].to_i == @facts["map"]
  end

  # Reports whether another player stands near the player.
  #
  # @param peer [Object] The player.
  # @return [Boolean] Whether they do.
  def near?(peer)
    on_map?(peer) && distance(peer, @facts["x"], @facts["y"]) <= NEARBY_TILES
  end

  # Counts the steps between another player and a tile.
  #
  # @param peer [Object] The player.
  # @param x [Integer] The tile's x.
  # @param y [Integer] The tile's y.
  # @return [Integer] The steps.
  def distance(peer, x, y)
    [(peer.state["x"].to_i - x).abs, (peer.state["y"].to_i - y).abs].max
  end

  # The asking and joining sides send, log and measure as the matchmaking does.
  public :tell_map, :who, :who_seat, :near?, :raid_free?, :distance
end

# The world of a golden scenario's step, as the old scripts saw it, noting what the stand-in sent,
# showed and logged.
class GoldenMatchWorld
  # A player of the step.
  Player = Struct.new(:seat, :state, :member, :away)

  attr_reader :sent, :box, :logs
  attr_accessor :rand

  # Makes the world of a step.
  #
  # @param world [Hash] The step's world.
  # @param ids [Array<Integer>] The battle ids made up so far, counted on.
  def initialize(world, ids)
    @world = world
    @ids = ids
    @peers = world["peers"].map { |peer| Player.new(peer["seat"], peer["state"], peer["member"], peer["away"] ? 1 : nil) }
    @sent = []
    @box = []
    @logs = []
  end

  # @return [Boolean] Whether a world is open.
  def in_world?; true; end
  # @return [Boolean] Whether it is a Raid World.
  def raid?; @world["raid"]; end
  # @return [Integer] The player's seat.
  def own_seat; @world["own_seat"]; end
  # @return [Integer] When the player entered the map.
  def own_since; @world["since"]; end
  # @return [String] The player's id.
  def own_id; "id-me"; end
  # @return [Array] The players.
  def peers; @peers; end
  # @return [String] The party's id.
  def party_id; "p1"; end
  # @return [Array] The party's other members.
  def members; @peers.select(&:member); end
  # @return [Boolean] Whether the player plays in a party with someone else.
  def in_party?; !members.empty?; end
  # @return [Object] The party's leader.
  def leader
    leader = @world["leader"]
    leader == "me" ? :me : (leader && at(leader))
  end
  # Finds a player by seat.
  def at(seat); @peers.find { |peer| peer.seat == seat }; end
  # Notes a message sent.
  def send(seat, fields); @sent << [seat, fields.map { |key, value| "#{key}=#{value}" }.join("\n") + "\n\n"]; true; end
  # Notes a log line.
  def log(line); @logs << line; end
  # Notes a message for the notification box.
  def notice(key, seat, text, frames); @box << ["message", key, seat, text, frames]; end
  # Notes a message taken away.
  def drop_notice(key, seat, reason); @box << ["drop", key, seat, reason]; end
  # @return [Float] The clock in seconds.
  def now; @world["now"] / 1000.0; end
  # @return [String] A new battle id.
  def new_id; @ids[0] += 1; "b#{@ids[0]}"; end
end

# Replays a golden scenario's steps on the stand-in as the scripts take them, as
# MGQOnline.Game.Tests' MatchHarness replays them on C#.
class MatchReplay
  # Makes the replay of a scenario.
  def initialize
    @ids = [0]
    @stand_in = MatchStandIn.new(Object.new)
  end

  # Runs a step and tells what it sent, showed, did and logged.
  #
  # @param step [Hash] The step.
  # @return [Hash] The outcome.
  def run(step)
    @world = GoldenMatchWorld.new(step["world"], @ids)
    @stand_in.instance_variable_set(:@world, @world)
    @facts = step["world"]["facts"].dup
    @args = step["args"]
    @actions = []
    outcome = {}
    @stand_in.answer("coop.frame", @facts)
    case step["op"]
    when "offer" then offer(@args["troop"], @args["encounter"], false)
    when "poll" then poll
    when "steps"
      @world.rand = @args["rand"]
      outcome["steps"] = @stand_in.answer("coop.steps", "facts" => @facts, "steps" => @args["steps"])
    when "soon" then @stand_in.take_soon(@world.at(@args["seat"]))
    when "freeze" then @stand_in.take_freeze(@world.at(@args["seat"]), @args["map"])
    when "unfreeze" then @stand_in.unfreeze_for(@world.at(@args["seat"]), @args["other_invite"])
    when "take" then take(@world.at(@args["seat"]), @args["message"])
    when "take_map" then @stand_in.route(@world.at(@args["seat"]), @args["message"], true)
    when "leader_wait" then leader_wait
    when "yield" then apply(@stand_in.answer("coop.yield", nil)["actions"])
    when "decline_waiting" then @stand_in.answer("coop.decline_waiting", @args["reason"])
    end
    { "sent" => @world.sent, "box" => @world.box, "actions" => @actions, "logs" => @world.logs }.merge(outcome).merge("waits" => @stand_in.waits_for_player)
  end

  private

  # Offers a battle as the scripts' offer does.
  #
  # @param troop [Integer] The troop.
  # @param encounter [Boolean] Whether it is a random encounter.
  # @param asked_hot [Boolean] Whether a running battle did not take it in.
  # @param overrides [Hash] The request's fields the step does not hold.
  def offer(troop, encounter, asked_hot, overrides = {})
    request = @args.merge("facts" => @facts, "troop" => troop, "encounter" => encounter, "asked_hot" => asked_hot, "escape" => true, "lose" => false).merge(overrides)
    @stand_in.answer("coop.offer", request)["actions"].each do |taken|
      next apply([taken]) unless taken["kind"] == "ask_hot"

      @actions << ["ask_hot"]
      offer(troop, encounter, true, overrides) unless @args["hot_answer"]
      break
    end
  end

  # Takes the steps the stand-in asks for, as the scripts take them.
  #
  # @param actions [Array<Hash>] The steps.
  def apply(actions)
    actions.each do |taken|
      case taken["kind"]
      when "join" then join(taken["role"], taken["bid"], taken["seats"], taken["label"])
      when "fight_alone" then @actions << ["fight_alone"] unless @facts["role"]
      when "accept"
        @actions << ["drop_call"] if taken["label"] == "story"
        @actions << ["accept", taken["seat"], taken["fields"]["bid"]]
      when "lead" then @actions << ["lead", taken["seat"], taken["fields"]["bid"]]
      when "yield"
        finish
        follow(taken)
      when "follow" then follow(taken)
      when "miss", "break_off", "call_off_own" then @actions << [taken["kind"], taken["label"]]
      end
    end
  end

  # Becomes the guest of another battle.
  #
  # @param taken [Hash] The step, the battle's invite under "fields".
  def follow(taken)
    @actions << ["adopt", taken["fields"]["troop"].to_i]
    join("guest", taken["fields"]["bid"].to_s, [taken["seat"]], taken["label"])
  end

  # Makes the battle live.
  #
  # @param role [String] The role.
  # @param bid [String] The battle's id.
  # @param seats [Array<Integer>] The other games' seats.
  # @param label [String] Who the waits name.
  def join(role, bid, seats, label)
    @actions << ["join", role, bid, seats, label]
    @facts = @facts.merge("role" => role, "bid" => bid, "seats" => seats, "coop" => true, "running" => true, "kind" => "coop")
  end

  # Ends the live battle.
  def finish
    @actions << ["finish"] if @facts["role"]
    @facts = @facts.merge("role" => nil, "bid" => nil, "seats" => [], "coop" => false, "running" => false, "kind" => nil)
  end

  # Takes a co-op message as the routes and the scripts' take do.
  #
  # @param peer [Object] Who sent it.
  # @param message [Hash] The message.
  def take(peer, message)
    @stand_in.answer("coop.frame", @facts)
    return if @stand_in.route(peer, message)

    @world.log("co-op battle: took #{message['coop']} from #{@stand_in.send(:who, peer)}: #{message.reject { |key, _| key == 'coop' }.map { |key, value| "#{key}=#{value}" }.join(' ')}")
    apply(@stand_in.answer("coop.take_off", "facts" => @facts, "seat" => peer.seat, "fields" => message)["actions"]) if message["coop"] == "off"
  end

  # Waits for the party's leader as the scripts' await_leader does.
  def leader_wait
    answer = nil
    frame = 0
    until answer
      frame += 1
      take(@world.at(@args["seat"]), @args["message"]) if frame == @args["inject_at"]
      answer = frame == @args["end_at"] ? @args["ending"] : @stand_in.answer("coop.leader_wait", nil)
    end
    offer = @stand_in.instance_variable_get(:@asking)[:offer]
    hosted = @stand_in.answer("coop.leader_end", answer)
    return unless hosted

    finish
    apply(@stand_in.answer("coop.host", offer.merge("facts" => @facts, "bid" => nil))["actions"])
  end

  # Runs frames on the map as the scripts' on_map does.
  def poll
    @args["count"].times do
      @stand_in.answer("coop.poll", "facts" => @facts, "asked" => @args["asked"])["actions"].each do |taken|
        next apply([taken]) unless taken["kind"] == "start_held"

        offer(taken["troop"], true, false, "encountering" => false, "escape" => taken["escape"], "lose" => taken["lose"])
        @stand_in.answer("coop.release", "facts" => @facts, "seats" => Array(taken["seats"]), "asked" => @args["asked"])
        @actions << ["call", "Scene_Battle"]
      end
    end
  end
end

# Replays the golden scenarios of the matchmaking on the stand-in.
def check_match_stand_in
  %w(match.json invites.json).each do |file|
    JSON.parse(File.read(File.join(COOP_FIXTURES, file), :encoding => "UTF-8"))["scenarios"].each do |scenario|
      replay = MatchReplay.new
      scenario["steps"].each_with_index do |step, index|
        found = replay.run(step)
        raise "the matchmaking stand-in differs at step #{index} of #{scenario['name']} (#{file}): #{found.inspect}\nexpected #{step['outcome'].inspect}" unless found == step["outcome"]
      end
    end
  end
end

check_match_stand_in
