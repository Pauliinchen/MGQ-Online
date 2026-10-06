#----------------------------------------------------------------
#  battles_duel.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Added the duel's choice to the action wheel's ring by order instead of to its right
#      Paulinchen  2026-10-04: Renamed from mp_battles_duel.rbx
#      Paulinchen  2026-10-03: Started a duel with the Backline when the challenger's duels have it, and said so in the challenge
#                            - Kept a duel waiting to start as a Pending record, and the sides' players as MGQ_MpBattlesCoop::Player records
#                            - Offered the duel's choices and challenges to the wheel, the World overview and the notification box through MGQ_MpActions
#                            - Asked MGQ_MpOverworldSync whether the map is quiet or the player free on it
#                            - Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Took a call to a team duel only from the challenger the player accepted or through the leader of the player's party
#                            - Read the bound keys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#                            - Told the challenger that a player declined, whom the challenge then stops naming
#      Paulinchen  2026-10-02: Named the key the player bound to the action wheel in the challenge line above a ghost
#                            - Followed the map through core_hooks.rbx
#                            - Sent the battle's break-off and leaving through MGQ_MpBattlesSync.tell
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Duels: PvP battles between two players of a world, the same battle as the PvP battle screen's (battles_pvp.rbx)
# carried over the world's room (battles_sync.rbx). A player challenges like a party invite: the
# players nearby, or one player anywhere picked in the World overview, for fifteen seconds. The
# challenged player accepts and sends their team; the challenger answers with theirs, hosts, and
# both battles start from the map.
#
# A duel a party's leader takes part in becomes a team duel (battles_team.rbx): the challenger
# calls their own party and the player who accepted, who calls their party in turn. Each answers
# once free on the map, and the duel starts with those ready after ten seconds at the latest.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesDuel
  # Frames an accepted challenge waits for the challenger's answer, six seconds.
  ANSWER_FRAMES = 360

  # Frames a team duel waits for its players to get ready, ten seconds.
  READY_FRAMES = 600

  # Color of the challenge line above a ghost's name and above the player's own head.
  CHALLENGE_COLOR = Color.new(255, 160, 128)

  # Why a duel could not start, by the reason a decline carries.
  REASONS = {
    "busy" => "is busy",
    "gone" => "stopped challenging",
    "data" => "plays another version of the game",
    "team" => "could not read your team",
    "off" => "called the duel off",
    "late" => "started the duel without you",
    "no" => "declined your challenge",
  }

  # A duel waiting to start from the map.
  #
  # @!attribute role [Symbol] :host or :guest of a duel between two players, :team for a team duel.
  # @!attribute battle_id [String] The duel's id.
  # @!attribute peer [MGQ_MpOverworldSync::Peers::Peer, nil] The other player; of a team duel its
  #   host, nil when the player hosts it.
  # @!attribute members [Array<MGQ_MpActors::Builds::Member>, nil] The other player's team, nil for a team duel.
  # @!attribute own [Array<MGQ_MpBattlesCoop::Player>, nil] The players of the player's side of a team duel.
  # @!attribute other [Array<MGQ_MpBattlesCoop::Player>, nil] The players of the other side of a team duel.
  # @!attribute same_side [Boolean, nil] Whether the player stands on the host's side of a team duel.
  # @!attribute backline [Boolean, nil] Whether a duel between two players has the Backline.
  Pending = Struct.new(:role, :battle_id, :peer, :members, :own, :other, :same_side, :backline) do
    # Lists the seats of a team duel's players.
    #
    # @return [Array<Integer>] The seats of both sides.
    def seats
      (Array(own) + Array(other)).map(&:seat)
    end
  end

  @challenge = MGQ_MpCoop::Invite.new
  @accepted = nil
  @pending = nil
  @gathering = nil
  @called = nil

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "duel"

  # Reports whether duels can run: PvP battles are on and up to date, and a world is open.
  #
  # @return [Boolean] Whether they can.
  def self.available?
    MGQ_MpBattlesPvp::ENABLED && MGQ_Multiplayer.available? && !MGQ_Multiplayer.outdated? && MGQ_MpOverworldSync.in_world?
  end

  # Reports whether the player challenges to a duel now.
  #
  # @return [Boolean] Whether they do.
  def self.inviting?
    @challenge.inviting?
  end

  # The ids of the players the challenge reaches wherever they are, besides those nearby.
  #
  # @return [Array<String>] The ids, none while the player does not challenge.
  def self.targets
    @challenge.targets
  end

  # Reports whether another player's challenge reaches the player: standing near, or naming them.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param anywhere [Boolean] Whether a challenge naming the player counts wherever the challenger stands.
  # @return [Boolean] Whether it does.
  def self.challenged_by?(peer, anywhere = true)
    MGQ_MpCoop::Invite.reaches_me?(peer.state, "challenge", "challenge_to", anywhere)
  end

  # Reports whether the player may start a duel: on the map, with no event, message, transfer,
  # menu or other multiplayer battle of their own.
  #
  # @return [Boolean] Whether they may.
  def self.free?
    MGQ_MpOverworldSync.map_free? && MGQ_MpBattlesSync.role.nil? && !MGQ_MpBattles.running? && !MGQ_MpBattlesPvp::Battle.running?
  end

  # Challenges the players nearby, and a player anywhere in the world when named.
  #
  # @param target_id [String, nil] The id of a player the challenge reaches wherever they are.
  def self.invite(target_id = nil)
    @challenge.invite(target_id)
  end

  # Stops challenging.
  def self.stop
    @challenge.stop
  end

  # Forgets every challenge and answer, as when the world closes.
  def self.reset
    stop
    @accepted = nil
    @pending = nil
    @gathering = nil
    @called = nil
  end

  # Lets a challenge run out, and an accepted one that the challenger never answered. Called every
  # frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    return reset unless in_world

    @challenge.count_down
    tick_gathering if @gathering
    tick_called if @called
    return unless @accepted && (@accepted[:frames] += 1) > ANSWER_FRAMES

    MGQ_MpOverworldSync.notice("#{@accepted[:name]} did not answer the duel.")
    @accepted = nil
  end

  # The fields the duel adds to the state the player's game tells the others. They are not named
  # "duel", which marks the messages this script takes.
  #
  # @return [Hash] The fields.
  def self.state_fields
    { "challenge" => inviting? ? 1 : 0, "challenge_to" => targets.join(","), "challenge_backline" => MGQ_MpBattlesPvp::Backline.wanted? ? 1 : 0 }
  end

  # Words another player's challenge, with the Backline when their duels have it, which a team
  # duel never does.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The challenger.
  # @param start [String] How the line starts, up to the duel.
  # @return [String] The line.
  def self.challenge_text(peer, start)
    "#{start} to a duel#{' with Backline' if peer.state['challenge_backline'].to_i == 1 && !team_duel?(peer)}"
  end

  # Tells what the line above a ghost's name says: their challenge, when it reaches the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  # @return [Array, nil] The text and its color, nil for none.
  def self.label_line(peer)
    challenged_by?(peer) ? ["Challenges you to a duel (#{MGQ_MpHotkeys.label(:wheel)})", CHALLENGE_COLOR] : nil
  end

  # Accepts a challenge: sends the challenger the player's team, and waits for theirs.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The challenger.
  def self.accept(peer)
    return MGQ_MpOverworldSync.notice("Finish what you are doing first.") unless free?

    MGQ_MpOverworldSync.tell(peer.seat, { "duel" => "accept" }, team_line)
    @accepted = { :seat => peer.seat, :name => peer.state["name"].to_s, :frames => 0 }
    MGQ_MpOverworldSync.notice("You accepted #{peer.state['name']}'s duel.")
  end

  # Takes a duel message. Called by overworld_sync.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields, its body under :payload.
  def self.take(peer, message)
    return unless peer

    case message["duel"]
    when "accept" then take_accept(peer, message[:payload])
    when "start"
      message["team"] == "1" ? take_team_start(peer, message["bid"].to_s, message[:payload]) : take_start(peer, message["bid"].to_s, message[:payload])
    when "decline" then take_decline(peer, message["reason"].to_s)
    when "team" then take_call(peer, message["bid"].to_s)
    when "side" then take_side(peer, message["bid"].to_s, message["seats"].to_s)
    when "ready" then take_ready(peer, message["bid"].to_s, message[:payload])
    when "cancel" then take_cancel(peer, message["bid"].to_s, message["reason"].to_s)
    end
  rescue => e
    log("taking a duel message failed: #{e.class}: #{e.message}")
  end

  # As challenger, starts the duel a player accepted, answering with the player's own team.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who accepted.
  # @param body [String] Their game's fingerprint and their team.
  def self.take_accept(peer, body)
    return decline(peer, "gone") unless @challenge.covers?(peer.state)
    return decline(peer, "busy") unless free?

    members = read_team(peer, body)
    return unless members

    battle_id = rand(36**8).to_s(36)
    stop
    return gather(peer, battle_id) if team_duel?(peer)

    MGQ_MpOverworldSync.tell(peer.seat, { "duel" => "start", "bid" => battle_id }, team_line)
    @pending = Pending.new(:host, battle_id, peer, members)
    @pending.backline = MGQ_MpBattlesPvp::Team.sent_backline?
  end

  # As challenged player, starts the duel the challenger answered.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The challenger.
  # @param battle_id [String] The duel's id.
  # @param body [String] Their game's fingerprint and their team.
  def self.take_start(peer, battle_id, body)
    # The challenger already waits in their battle, so every refusal calls it off.
    return call_off(peer.seat, battle_id, "busy") unless @accepted && @accepted[:seat] == peer.seat

    @accepted = nil
    unless free?
      call_off(peer.seat, battle_id, "busy")
      return MGQ_MpOverworldSync.notice("The duel with #{peer.state['name']} could not start.")
    end

    members = read_team(peer, body)
    return call_off(peer.seat, battle_id) unless members

    @pending = Pending.new(:guest, battle_id, peer, members)
    # The challenger hosts, so the rule their team brought holds.
    @pending.backline = MGQ_MpBattlesPvp::Team.backline?(MGQ_MpBattlesSync::Wire.parse(body.to_s)[1])
  end

  # Calls off a duel the other player started or is about to start: their battle breaks off, or
  # their duel waiting to start is dropped.
  #
  # @param seat [Integer] The other player's world seat.
  # @param battle_id [String] The duel's id.
  # @param reason [String] A key of REASONS.
  def self.call_off(seat, battle_id, reason = "off")
    MGQ_MpOverworldSync.tell(seat, { "duel" => "cancel", "bid" => battle_id, "reason" => reason })
    MGQ_MpBattlesSync.tell(seat, "broken", battle_id)
  end

  # Tells why the other player could not duel.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param reason [String] A key of REASONS.
  def self.take_decline(peer, reason)
    @accepted = nil if @accepted && @accepted[:seat] == peer.seat
    # A player who declined the challenge is no longer named by it.
    @challenge.drop(peer.state["id"]) if reason == "no"
    MGQ_MpOverworldSync.notice("#{peer.state['name']} #{REASONS.fetch(reason, 'cannot duel now')}.")
  end

  # Reads the other player's team, declining when it is from another game or unreadable.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param body [String] Their game's fingerprint and their team.
  # @return [Array<MGQ_MpActors::Builds::Member>, nil] The team, nil when declined.
  def self.read_team(peer, body)
    game, team = MGQ_MpBattlesSync::Wire.parse(body.to_s)
    return decline(peer, "data") unless game.to_s == MGQ_MpBattlesPvp::Team.game

    members = MGQ_MpBattlesPvp::Team.parse(team.to_s)
    members.empty? ? decline(peer, "team") : members
  end

  # Turns the other player down, telling them why.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param reason [String] A key of REASONS.
  # @return [nil] Nothing.
  def self.decline(peer, reason)
    MGQ_MpOverworldSync.tell(peer.seat, { "duel" => "decline", "reason" => reason })
    log("declined #{peer.state['name']}: #{reason}")
    nil
  end

  # Reports whether a duel becomes a team duel: when either player leads a party of two or more,
  # unless both play in the same party.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @return [Boolean] Whether it does.
  def self.team_duel?(peer)
    return false if MGQ_MpCoop::Party.member?(peer.state)

    MGQ_MpCoop.leads?(:me) || MGQ_MpCoop.leads?(peer)
  end

  # As challenger, calls the players of a team duel: the player's party when they lead it, and the
  # player who accepted, who calls their own party and tells whom, see take_side.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who accepted.
  # @param battle_id [String] The duel's id.
  def self.gather(peer, battle_id)
    sides = {}
    MGQ_MpCoop::Party.members.each { |member| sides[member.seat] = :own } if MGQ_MpCoop.leads?(:me)
    sides[peer.seat] = :other

    @gathering = { :battle_id => battle_id, :frames => 0, :sides => sides, :ready => {}, :early => {},
                   :other => peer.seat, :name => peer.state["name"].to_s }
    sides.each_key { |seat| MGQ_MpOverworldSync.tell(seat, { "duel" => "team", "bid" => battle_id }) }
    MGQ_MpOverworldSync.notice("Getting both sides ready for the duel . . .")
    log("team duel #{battle_id}: calling #{sides.inspect}")
  end

  # As challenger, starts the team duel once every player called is ready, or ten seconds passed,
  # or calls it off once the player is busy. Called every frame.
  def self.tick_gathering
    gathering = @gathering
    return cancel_gathering("off") unless free?

    gathering[:frames] += 1
    return unless gathering[:ready].size == gathering[:sides].size || gathering[:frames] > READY_FRAMES

    @gathering = nil
    ready = gathering[:ready]
    others = ready.keys.select { |seat| gathering[:sides][seat] == :other }
    if others.empty?
      MGQ_MpOverworldSync.notice("Nobody of #{gathering[:name]}'s side was ready, the duel is off.")
      return gathering[:sides].each_key { |seat| MGQ_MpOverworldSync.tell(seat, { "duel" => "cancel", "reason" => "off" }) }
    end

    own = [[MGQ_MpOverworldSync::Me.seat, MGQ_Multiplayer::Player.name.to_s] + MGQ_MpBattlesCoop.team_build]
    own += (ready.keys - others).map { |seat| entry(seat, ready[seat]) }
    own = MGQ_MpBattlesCoop.arrange(own.map { |seat, name, builds, max| [seat, name, builds, [], max] })
    other = MGQ_MpBattlesCoop.arrange(others.map { |seat| entry(seat, ready[seat]) }.map { |seat, name, builds, max| [seat, name, builds, [], max] })
    body = MGQ_MpBattlesSync::Wire.line([own.map(&:to_a), other.map(&:to_a)])
    ready.each_key { |seat| MGQ_MpOverworldSync.tell(seat, { "duel" => "start", "bid" => gathering[:battle_id], "team" => 1 }, body) }
    (gathering[:sides].keys - ready.keys).each { |seat| MGQ_MpOverworldSync.tell(seat, { "duel" => "cancel", "reason" => "late" }) }
    @pending = Pending.new(:team, gathering[:battle_id], nil, nil, own, other, true)
  end

  # Writes a player who got ready as a side's player before its shares are counted.
  #
  # @param seat [Integer] The player's world seat.
  # @param answer [Array] Their builds and party_member_max.
  # @return [Array] The seat, name, builds and party_member_max.
  def self.entry(seat, answer)
    peer = MGQ_MpOverworldSync::Peers.at(seat)
    [seat, peer ? peer.state["name"].to_s : "?"] + answer
  end

  # As challenger, calls the team duel off, telling every player called.
  #
  # @param reason [String] A key of REASONS.
  def self.cancel_gathering(reason)
    gathering = @gathering
    @gathering = nil
    gathering[:sides].each_key { |seat| MGQ_MpOverworldSync.tell(seat, { "duel" => "cancel", "reason" => reason }) }
    MGQ_MpOverworldSync.notice("The duel is off.")
  end

  # As challenger, takes a player's answer that they are ready, with their game's fingerprint,
  # their Frontline and their party_member_max.
  #
  # An answer of a player the other side's leader has not named yet is kept until they are.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @param battle_id [String] The duel's id.
  # @param body [String] The answer.
  def self.take_ready(peer, battle_id, body)
    return unless @gathering && @gathering[:battle_id] == battle_id

    game, builds, max = MGQ_MpBattlesSync::Wire.parse(body.to_s)
    return decline(peer, "data") unless game.to_s == MGQ_MpBattlesPvp::Team.game

    answers = @gathering[:sides].key?(peer.seat) ? @gathering[:ready] : @gathering[:early]
    answers[peer.seat] = [builds.to_s, max.to_i]
  end

  # As challenger, takes whom the player who accepted called of their party, who join the other side.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who accepted.
  # @param battle_id [String] The duel's id.
  # @param seats [String] The world seats of the players they called, joined by commas.
  def self.take_side(peer, battle_id, seats)
    gathering = @gathering
    return unless gathering && gathering[:battle_id] == battle_id && gathering[:other] == peer.seat
    return if peer.state["party"].to_s.empty?

    seats.split(",").map(&:to_i).first(MGQ_MpCoop::MAX_PLAYERS - 1).each do |seat|
      other = MGQ_MpOverworldSync::Peers.at(seat)
      next if gathering[:sides].key?(seat) || other.nil? || other.state["party"] != peer.state["party"]

      gathering[:sides][seat] = :other
      gathering[:ready][seat] = gathering[:early].delete(seat) if gathering[:early].key?(seat)
    end
  end

  # Takes the challenger's call to a team duel, from the challenger the player accepted, or from
  # the leader of the player's party. As the leader of a party who accepted, calls the party too.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The challenger.
  # @param battle_id [String] The duel's id.
  def self.take_call(peer, battle_id)
    accepted = @accepted && @accepted[:seat] == peer.seat
    return unless accepted || led_by?(peer)

    answer_call(peer, battle_id)
    call_party(peer, battle_id) if accepted
  end

  # Takes the call to a team duel the leader of the player's party passes on, having accepted it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param message [Hash] The message's fields: the duel's id under "duel_call", the challenger's world seat under "seat".
  def self.take_passed_call(peer, message)
    return unless led_by?(peer)

    challenger = MGQ_MpOverworldSync::Peers.at(message["seat"].to_i)
    answer_call(challenger, message["duel_call"].to_s) if challenger
  end

  # Reports whether another player leads the party the player is in.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @return [Boolean] Whether they do.
  def self.led_by?(peer)
    MGQ_MpCoop.in_party? && MGQ_MpCoop::Party.leader.equal?(peer)
  end

  # Notes a call to a team duel: the player answers once free on the map.
  #
  # @param challenger [MGQ_MpOverworldSync::Peers::Peer] The challenger.
  # @param battle_id [String] The duel's id.
  def self.answer_call(challenger, battle_id)
    @accepted = nil
    @called = { :seat => challenger.seat, :name => challenger.state["name"].to_s, :battle_id => battle_id, :frames => 0, :sent => false }
    MGQ_MpOverworldSync.notice("#{challenger.state['name']}'s duel is a team duel. Get ready on the map.")
  end

  # As the leader of a party who accepted a duel, passes the challenger's call on to the party,
  # and tells the challenger whom.
  #
  # @param challenger [MGQ_MpOverworldSync::Peers::Peer] The challenger.
  # @param battle_id [String] The duel's id.
  def self.call_party(challenger, battle_id)
    return unless MGQ_MpCoop.leads?(:me)

    members = MGQ_MpCoop::Party.members
    members.each { |member| MGQ_MpCoop.tell(member.seat, "duel_call", battle_id, "seat" => challenger.seat) }
    MGQ_MpOverworldSync.tell(challenger.seat, { "duel" => "side", "bid" => battle_id, "seats" => members.map { |member| member.seat }.join(",") })
  end

  # Answers the challenger's call once the player is free, and forgets a call never answered.
  # Called every frame.
  def self.tick_called
    called = @called
    called[:frames] += 1
    return @called = nil if called[:frames] > READY_FRAMES + ANSWER_FRAMES
    return if called[:sent] || !free?

    builds, max = MGQ_MpBattlesCoop.team_build
    MGQ_MpOverworldSync.tell(called[:seat], { "duel" => "ready", "bid" => called[:battle_id] },
            MGQ_MpBattlesSync::Wire.line([MGQ_MpBattlesPvp::Team.game, builds, max]))
    called[:sent] = true
    MGQ_MpOverworldSync.notice("Ready for the duel. Waiting for the others . . .")
  end

  # Takes the start of a team duel the player answered, with both sides.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The challenger, who hosts.
  # @param battle_id [String] The duel's id.
  # @param body [String] The challenger's side and the other side, see MGQ_MpBattlesCoop.arrange.
  def self.take_team_start(peer, battle_id, body)
    return unless @called && @called[:seat] == peer.seat && @called[:battle_id] == battle_id

    @called = nil
    unless free?
      # The duel counts the player in already; leaving hands their characters to their side.
      MGQ_MpBattlesSync.tell(peer.seat, "leave", battle_id)
      return MGQ_MpOverworldSync.notice("The duel with #{peer.state['name']} started without you.")
    end

    hosts, others = MGQ_MpBattlesSync::Wire.parse(body.to_s).first(2).map do |side|
      Array(side).map { |fields| MGQ_MpBattlesCoop::Player.read(fields) }
    end
    same = hosts.any? { |player| player.seat == MGQ_MpOverworldSync::Me.seat }
    @pending = Pending.new(:team, battle_id, peer, nil, same ? hosts : others, same ? others : hosts, same)
  end

  # Takes the other player's word that the duel is off: a team duel the player was called to, or a
  # duel of theirs waiting to start.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param battle_id [String] The duel's id, empty for a call to a team duel.
  # @param reason [String] A key of REASONS.
  def self.take_cancel(peer, battle_id, reason)
    if @pending && @pending.battle_id == battle_id && @pending.peer && @pending.peer.seat == peer.seat
      @pending = nil
    elsif @called && @called[:seat] == peer.seat
      @called = nil
    else
      return
    end
    MGQ_MpOverworldSync.notice("#{peer.state['name']} #{REASONS.fetch(reason, 'called the duel off')}.")
  end

  # Starts a team duel from the map: as host with every other player as a guest, else as a guest
  # of the challenger.
  #
  # @param pending [Pending] The team duel.
  def self.start_team(pending)
    host = pending.peer
    if host
      MGQ_MpBattlesSync.join_world(:guest, pending.battle_id, [host.seat], host.state["name"].to_s, :pvp, true)
    else
      MGQ_MpBattlesSync.join_world(:host, pending.battle_id, pending.seats - [MGQ_MpOverworldSync::Me.seat], "the duel", :pvp, true)
    end
    MGQ_MpBattlesTeam.prepare(pending.own, pending.other, pending.same_side)
    MGQ_MpBattlesPvp::Battle.start(MGQ_MpBattlesTeam.opponent_name, [], false) { MGQ_MpBattlesTeam.opponents }
    log("team duel #{pending.battle_id} as #{host ? 'guest' : 'host'}, #{pending.own.size} against #{pending.other.size}")
  end

  # Calls off a duel waiting to start, telling the other players: a team duel's guest leaves it, so
  # their side takes their characters; anyone else calls it off.
  #
  # @param pending [Pending] The duel.
  def self.give_up(pending)
    role, battle_id, peer = pending.role, pending.battle_id, pending.peer
    if role == :team && peer
      MGQ_MpBattlesSync.tell(peer.seat, "leave", battle_id)
    elsif role == :team
      (pending.seats - [MGQ_MpOverworldSync::Me.seat]).each { |seat| call_off(seat, battle_id) }
    else
      call_off(peer.seat, battle_id, "busy")
    end
    MGQ_MpOverworldSync.notice("The duel could not start.")
    log("duel #{battle_id} given up, the player got busy")
  end

  # Writes the player's game fingerprint and team, which the other player's game rebuilds.
  #
  # @return [String] The line.
  def self.team_line
    MGQ_MpBattlesSync::Wire.line([MGQ_MpBattlesPvp::Team.game, MGQ_MpBattlesPvp::Team.build])
  end

  # Starts a duel waiting to start, from the map, as an encounter starts, or calls it off once an
  # event, a transfer or a menu came first. Called by the map every frame.
  def self.on_map
    return unless @pending

    pending = @pending
    @pending = nil
    return give_up(pending) unless free?
    return start_team(pending) if pending.role == :team

    role, battle_id, peer, members = pending.role, pending.battle_id, pending.peer, pending.members
    name = peer.state["name"].to_s
    MGQ_MpBattlesSync.join_world(role, battle_id, [peer.seat], name, :pvp)
    MGQ_MpBattlesPvp::Battle.start(name, members, false, pending.backline)
    log("duel #{battle_id} with #{name} as #{role}#{' with the Backline' if pending.backline}")
  rescue => e
    @pending = nil
    log("starting a duel failed: #{e.class}: #{e.message}")
  end

  # What duels offer between two players, through ui_actions.rbx: their choices on the action wheel
  # and in the World overview, and challenges in the overview and the notification box.
  module Offers
    # The choice wherever duels cannot run.
    UNAVAILABLE = MGQ_MpActions::Option.new("Duel", nil, "Duels need PvP battles, which are off or out of date.")

    # The wheel's duel choice: accepting the challenge of a player nearby, else challenging the
    # players nearby.
    #
    # @return [MGQ_MpActions::Option] The choice.
    def self.wheel_option
      duel = MGQ_MpBattlesDuel
      return UNAVAILABLE unless duel.available?

      option = MGQ_MpActions::Option
      near = MGQ_MpOverworldSync::Peers.all.select { |peer| MGQ_MpCoop::Party.near?(peer.state) }
      challenger = near.find { |peer| duel.challenged_by?(peer, false) }
      return option.new("Accept #{challenger.state['name']}'s duel", lambda { duel.accept(challenger) }, nil) if challenger
      return own_options.first if duel.inviting?

      option.new("Challenge to a duel", near.empty? ? nil : lambda { duel.invite }, "Nobody is near enough to challenge.")
    end

    # The duel choice for another player in the World overview: accepting their challenge, which
    # closes the overview, else challenging them.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @return [MGQ_MpActions::Option] The choice.
    def self.peer_option(peer)
      duel = MGQ_MpBattlesDuel
      return UNAVAILABLE unless duel.available?

      option = MGQ_MpActions::Option
      return option.new("Accept duel", lambda { duel.accept(peer) }, nil, nil, true) if duel.challenged_by?(peer)
      return option.new("Challenged to a duel", nil, "Your challenge to #{peer.state['name']} stands.") if duel.targets.include?(peer.state["id"].to_s)

      option.new("Challenge to a duel", lambda { duel.invite(peer.state["id"]) }, nil)
    end

    # The duel choice on the player's own row of the World overview: stopping a challenge.
    #
    # @return [Array<MGQ_MpActions::Option>] The choice, none while the player does not challenge.
    def self.own_options
      MGQ_MpBattlesDuel.inviting? ? [MGQ_MpActions::Option.new("Stop challenging", lambda { MGQ_MpBattlesDuel.stop }, nil)] : []
    end

    # Tells another player's challenge, when it reaches the player.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [Array, nil] The text and its color, nil for none.
    def self.call_of(peer)
      MGQ_MpBattlesDuel.challenged_by?(peer) ? [MGQ_MpBattlesDuel.challenge_text(peer, "Challenges you"), CHALLENGE_COLOR] : nil
    end

    # Tells another player's challenge for the notification box, while it reaches the player and
    # duels can run. A duel starts only from the map, so in a menu the challenge stands without the
    # key that accepts it.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Notice, nil] The challenge, nil for none.
    def self.notice_of(peer)
      duel = MGQ_MpBattlesDuel
      return nil unless duel.available? && duel.challenged_by?(peer)

      on_map = SceneManager.scene.is_a?(Scene_Map)
      MGQ_MpActions::Notice.new([:duel, peer.seat], duel.challenge_text(peer, "#{peer.state['name']} challenges you"), CHALLENGE_COLOR, on_map ? "Accept" : nil,
                                on_map ? lambda { duel.accept(peer) } : nil, lambda { duel.decline(peer, "no") }, peer.state["id"])
    end

    # Names what the player is doing for the line above their own head.
    #
    # @return [String, nil] That they challenge, nil while they do not.
    def self.own_doing
      MGQ_MpBattlesDuel.inviting? ? "Challenging to a duel" : nil
    end
  end
end

# What duels take part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route("duel") { |peer, message| MGQ_MpBattlesDuel.take(peer, message) }
  MGQ_MpCoop.route("duel_call") { |peer, message| MGQ_MpBattlesDuel.take_passed_call(peer, message) }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpBattlesDuel.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpBattlesDuel.state_fields }
  MGQ_MpOverworldSync.label_line { |peer| MGQ_MpBattlesDuel.label_line(peer) }
rescue => e
  MGQ_MpBattlesDuel.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What duels add to the action wheel, the World overview and the notification box, through
# ui_actions.rbx.

begin
  MGQ_MpActions.offer(MGQ_MpBattlesDuel::Offers)
  MGQ_MpActions.wheel_choice(20) { MGQ_MpBattlesDuel::Offers.wheel_option }
  MGQ_MpActions.own_doing_from { MGQ_MpBattlesDuel::Offers.own_doing }
rescue => e
  MGQ_MpBattlesDuel.log("actions FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, a duel waiting to start starts.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "battles_duel") { MGQ_MpBattlesDuel.on_map unless scene_changing? }
rescue => e
  MGQ_MpBattlesDuel.log("map hook FAILED: #{e.class}: #{e.message}")
end
