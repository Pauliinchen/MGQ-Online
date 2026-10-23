#----------------------------------------------------------------
#  battles_coop_hotjoin.rbx
#
#  Changelog:
#      Paulinchen  2026-10-23: Sent to and found the battle's players by the seats they held at its start
#                            - Made added enemies of the kind the troop's battle needs
#      Paulinchen  2026-10-15: Joined a battle the battle server hosts late through its starter and its channel
#      Paulinchen  2026-10-12: Took a joining player's party_member_max only as a number
#                            - Dropped an enemy of the host's changed troop whose id, place or mark is no number
#                            - Kept every enemy of the host's changed troop at its place
#      Paulinchen  2026-10-11: Asked the player's party members near along in the notification box
#                            - Took an encounter in with as many players and enemies as the battle has room for
#                            - Let a random encounter ask only a running battle that takes players in
#                            - Let a random encounter join only a running battle whose host stands near
#                            - Told the host in the battle's chat log of the players it took in
#      Paulinchen  2026-10-10: Named the raid boss's pools in the invite of players who join late
#                            - Told the battle the player fights also under the Library or Config
#                            - Let an encounter join a battle that waits while its player is away
#                            - Let the players an encounter brought along walk on once the running battle did not take it
#                            - Counted every enemy of the troop toward TROOP_LIMIT, the fallen too
#                            - Started the battle of the enemies a guest adds to its troop, as the host does
#      Paulinchen  2026-10-09: Added only the enemies of an encounter taken in that still find a place
#                            - Told the guests the grown troop through battles_coop.rbx
#                            - Noted the troop a battle turned live with
#                            - Let a guest transform, show or hide its enemies as the host's troop does
#                            - Marked an enemy the game hid as it was eaten as fallen for the guests
#                            - Sent the battle's enemy rates to the players it takes in
#                            - Took in a player who asks with their own encounter while another request brought them along
#                            - Took in a player who joins the battle by choice, without enemies
#                            - Marked a boss battle in the invites of the players taken in
#                            - Left the players whose state tells a battle out of those an encounter brings along
#                            - Placed the enemies of an encounter taken in anew as its player joins
#                            - Laid the host's fallen new enemies down only once a guest lettered them
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# Hotjoining in a Raid World: a random encounter that starts on a map where a co-op battle already
# runs joins that battle instead of starting its own. The player who met the enemies asks the
# running battle's host (ask, await); the host takes them in while the players stay at most
# MGQ_MpBattlesCoop::RAID_PLAYERS, neither battle is a boss battle (battles_raid_bosses.rbx) and its
# troop has room for the new enemies (take_request). At the host's next command phase the new
# enemies join its troop and the new players its party, its guests hear of both, and the new
# players get its roster as guests who join late (settle). A host who fights alone turns its battle
# live for them (go_live). A refusal, or no answer within ANSWER_FRAMES, starts the encounter on its
# own as usual. Every game pays for the whole troop it fought, as in any co-op battle.
#
# Every game in a Raid World tells the battle it fights in its state (state_fields), so a player
# who meets enemies knows whom to ask. It must never interrupt the game, so every entry point
# rescues.
module MGQ_MpBattlesHotjoin
  # Frames the player whose encounter asks to join a running battle waits for its host's answer,
  # three seconds.
  ANSWER_FRAMES = 180

  # Frames the player whose encounter would join a running battle without room for their party
  # members near waits for them to answer whether they start a battle with the player instead,
  # eight seconds: they answer in the notification box.
  PARTY_ANSWER_FRAMES = 480

  # Seconds a party member's offer to join a running battle along with the player stands.
  PARTY_OFFER_SECONDS = 20

  # Seconds the host keeps the players it took in waiting for them to join, at its command phases.
  WAIT_SECONDS = 60

  # Frames a player who joins a running battle waits for its roster, which comes only at the host's
  # next command phase: longer than the host keeps them waiting.
  ROSTER_FRAMES = (WAIT_SECONDS + 15) * 60

  # Enemies a troop holds at most, standing, hidden or fallen: the game's own troops hold no more,
  # and its window to pick an enemy shows as many without scrolling.
  TROOP_LIMIT = 8

  # Share of the narrower of two enemies' pictures that may hide behind the other.
  MAX_OVERLAP = 0.5

  # Pixels between two places an added enemy may stand at.
  PLACE_STEP = 8

  # Width of an enemy's picture when this game cannot measure it.
  DEFAULT_WIDTH = 160

  # Width of the battle screen when this game cannot read it.
  SCREEN_WIDTH = 640

  # What marks a fallen enemy where the troop's enemies a message carries mark hidden ones, see
  # late_entries.
  FALLEN = 2

  # The encounters taken in whose players have not all joined yet.
  @pending = []

  # The standing offers of party members to come along to a running battle, by their seat.
  @party_offers = {}

  # The party members who said no to starting a battle with the player.
  @stays_out = []

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "hotjoin"

  # Reports whether a Raid World is open, whose battles may join each other.
  #
  # @return [Boolean] Whether one is.
  def self.raid?
    MGQ_MpCoop::Scope.raid?
  end

  # The fields this script adds to the state the player's game tells the others: in a Raid World
  # "rb", the id of the battle the player fights, and "rbh", the seat of its host, both empty
  # outside a battle.
  #
  # @return [Hash] The fields, none in a Classic world.
  def self.state_fields
    return {} unless raid?

    front = defined?(MGQ_MpBattlesServed) && MGQ_MpBattlesServed.front_fields(%w(rb rbh))
    return front if front

    bid, host = running_battle
    { "rb" => bid.to_s, "rbh" => host.to_s }
  end

  # Tells the battle the player fights in a Raid World: a co-op battle as its host or a guest, or a
  # battle of their own (see fight_alone), also while its party command called the Library or
  # Config (see MGQ_MpBattlesCoop.in_battle_scene?).
  #
  # @return [Array, nil] The battle's id and the seat of its host, nil outside a battle.
  def self.running_battle
    return nil unless MGQ_MpBattlesCoop.in_battle_scene?

    sync = MGQ_MpBattlesSync
    if sync.role && sync.coop?
      return [sync.battle_id, sync.role == :host ? MGQ_MpOverworldSync::Me.seat : host_world_seat]
    end
    @own_bid ? [@own_bid, MGQ_MpOverworldSync::Me.seat] : nil
  end

  # Tells the world seat of the host of the co-op battle the player is a guest of, which the others
  # look the host up by.
  #
  # @return [Integer, nil] The seat, the seat the battle knows the host by while the host is away.
  def self.host_world_seat
    host = Array(MGQ_MpBattlesSync.seats).first
    host && (MGQ_MpBattlesSync.world_seat_of(host) || host)
  end

  # Tells the scene the player's state names while a battle in a Raid World waits on SceneManager's
  # stack under the Library or Config: still the battle, so the others find it to join.
  #
  # @return [String, nil] "battle", nil outside such a screen.
  def self.busy_scene
    return nil unless raid? && !SceneManager.scene.is_a?(Scene_Battle)

    MGQ_MpBattlesCoop.in_battle_scene? ? "battle" : nil
  end

  # Notes that the player's battle in a Raid World goes on as their own, without other players,
  # which another player's encounter may then join.
  #
  # @param bid [String, nil] The battle's id, nil for a new one.
  def self.fight_alone(bid = nil)
    return unless raid?

    @own_bid = bid || MGQ_MpBattlesCoop.new_battle_id
    log("the player's battle #{@own_bid} goes on as their own, which other players' encounters may join")
  end

  # Names a player for Multiplayer InGame.log.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] The player.
  # @return [String] Their name and seat.
  def self.who(peer)
    MGQ_MpOverworldSync.who(peer)
  end

  # Writes a troop's enemies for a message: each one's id, screen x and y, and 1 when hidden.
  #
  # @param entries [Array<Array>] The enemies, see MGQ_MpBattlesCoop.troop_entries.
  # @return [String] The enemies, such as "31:320:300:0;32:160:300:0".
  def self.entries_text(entries)
    entries.map { |entry| Array(entry).first(4).map(&:to_i).join(":") }.join(";")
  end

  # Reads the enemies a message carries, see entries_text.
  #
  # @param text [String, nil] The enemies.
  # @return [Array<Array<Integer>>] Each enemy's id, screen x and y, and 1 when hidden; at most
  #   TROOP_LIMIT.
  def self.parse_entries(text)
    entries = text.to_s.split(";").map { |entry| entry.split(":").map(&:to_i) }
    entries.select { |entry| entry.size == 4 && entry[0] > 0 }.first(TROOP_LIMIT)
  end

  # The joining side.

  # Asks the host of a co-op battle running on the player's map to take in the random encounter the
  # game just set up, with the free players the encounter would invite (see
  # MGQ_MpBattlesCoop.raid_candidates) as far as the battle has room, who stand still meanwhile. The
  # player becomes a guest of that battle, whose start waits for the answer (see await). Called by
  # MGQ_MpBattlesCoop.offer.
  #
  # The player's party members near (see party_near) are asked in the notification box instead of
  # brought along: to join the battle with the player where it has room for them all, else to start
  # a battle with the player, which the player's start then waits for (see await_party).
  #
  # @param troop_id [Integer] The encounter's troop.
  # @param can_escape [Boolean] Whether the party may escape it.
  # @param can_lose [Boolean] Whether losing it goes on without a game over.
  # @return [Boolean] Whether the player asks, false when the encounter starts as usual.
  def self.ask(troop_id, can_escape, can_lose)
    return false unless raid?

    target = target_battle
    return false unless target
    if MGQ_MpRaidBosses.boss?(troop_id)
      log("the encounter with troop #{troop_id} joins no running battle: it is a boss battle")
      return false
    end

    host, bid = target
    coop = MGQ_MpBattlesCoop
    room = room_in(host)
    party = party_near(host).map(&:seat)
    mode = party.empty? ? nil : (room > party.size ? :join : :start)
    free = coop.raid_candidates.select { |peer| peer.state["rb"].to_s.empty? }.map(&:seat) - party
    seats = free.first([room - 1 - (mode == :join ? party.size : 0), 0].max)
    @asking = { :seat => host.seat, :bid => bid, :troop => troop_id, :escape => can_escape, :lose => can_lose, :seats => seats, :answer => nil,
                :party => party, :mode => mode, :answers => {}, :name => host.state["name"].to_s }
    @late = nil
    @boss_battle = false
    @called_off = false
    @stays_out = []
    MGQ_MpBattlesSync.join_world(:guest, bid, [host.seat], host.state["name"].to_s)
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    coop.freeze_party(mode == :start ? seats + party : seats)
    offer_party(party, mode, host, bid) if mode
    tell_host(@asking) unless mode == :start
    true
  rescue => e
    log("asking to join a running battle failed: #{e.class}: #{e.message}")
    undo_ask
    false
  end

  # Sends the request of an encounter to the running battle's host, see ask.
  #
  # @param asking [Hash] The request.
  def self.tell_host(asking)
    coop = MGQ_MpBattlesCoop
    seats = Array(asking[:seats])
    coop.tell_map([asking[:seat]], "hot", "bid" => asking[:bid], "troop" => asking[:troop], "enemies" => entries_text(coop.troop_entries),
                                          "seats" => seats.join(","), "map" => $game_map.map_id)
    log("asked #{MGQ_MpBattlesSync.who(asking[:seat])} to take the encounter with troop #{asking[:troop]} into battle #{asking[:bid]}, " \
        "with #{seats.empty? ? 'no other player' : seats.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')}, waiting up to #{ANSWER_FRAMES / 60} s")
  end

  # Lists the player's party members near and free on the map (see MGQ_MpBattlesCoop.raid_free?
  # and near?), whom a running battle outside the party asks along in the notification box rather
  # than bringing them; none when the battle's host is a member, whose battle is the party's own.
  #
  # @param host [MGQ_MpOverworldSync::Peers::Peer] The running battle's host.
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
  def self.party_near(host)
    members = MGQ_MpCoop::Party.members
    return [] if members.any? { |member| member.equal?(host) }

    coop = MGQ_MpBattlesCoop
    members.select { |peer| coop.raid_free?(peer) && coop.near?(peer) }
  end

  # Counts the players a running battle still takes in, by its host's state (see
  # MGQ_MpBattlesJoin.state_fields), which says 0 while it takes nobody in; a host whose state
  # names no count fights alone.
  #
  # @param host [MGQ_MpOverworldSync::Peers::Peer] The battle's host.
  # @return [Integer] The players it takes.
  def self.room_in(host)
    most = MGQ_MpBattlesCoop::RAID_PLAYERS
    count = host.state.key?("rbn") ? host.state["rbn"].to_i : 1
    count.between?(1, most - 1) ? most - count : 0
  end

  # Takes back a request that failed halfway, so the encounter starts on its own as usual: tells the
  # host it is off, lets the players it brought along walk on, which the encounter's own invite then
  # holds anew, and ends the guest's side of its battle.
  def self.undo_ask
    asking = @asking
    return unless asking

    @asking = nil
    @late = nil
    @called_off = false
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    MGQ_MpBattlesCoop.tell_map([asking[:seat]], "off", "bid" => asking[:bid])
    release_companions(asking)
  rescue => e
    log("taking the request back failed: #{e.class}: #{e.message}")
  end

  # Lets the players a request brought along walk on once the running battle never took it in,
  # unless the encounter that starts on its own invites them anew (see MGQ_MpBattlesCoop.release).
  #
  # @param asking [Hash] The request, with the players' seats under :seats.
  def self.release_companions(asking)
    seats = Array(asking[:seats])
    return if seats.empty?

    MGQ_MpBattlesCoop.release(seats)
    log("let the players the request brought along walk on, unless invited anew: #{seats.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')}")
  rescue => e
    log("letting the players brought along walk on failed: #{e.class}: #{e.message}")
  end

  # Finds the co-op battle running on the player's map that an encounter would join: of the other
  # players on the map who fight one, as their states tell (see MGQ_MpBattlesCoop.fights?), the
  # battle whose host entered the map first, among those whose host stands near
  # (MGQ_MpBattlesCoop.near?) and that take players in (see room_in).
  #
  # @return [Array, nil] The battle's host and its id, nil when none runs.
  def self.target_battle
    map = $game_map.map_id
    battles = MGQ_MpCoop::Scope.peers_on(map).map do |peer|
      bid = peer.state["rb"].to_s
      next if !MGQ_MpBattlesCoop.fights?(peer) || peer.state["rbh"].to_s !~ /\A\d+\z/

      host = MGQ_MpOverworldSync::Peers.at(peer.state["rbh"].to_i)
      next unless host && host.state["map"].to_i == map && host.state["rb"].to_s == bid && MGQ_MpBattlesCoop.near?(host) && room_in(host) > 0

      [host, bid]
    end
    battles.compact.min_by { |host, bid| MGQ_MpCoop::Scope.key_of(host) + [bid] }
  end

  # Waits at the battle's start for the answer of the host the player asked, see ask. Taken in, the
  # player joins that battle as a guest; refused, or without an answer within ANSWER_FRAMES, the
  # player hosts their encounter as usual, and the players the request brought along whom it does
  # not invite walk on. Called at the battle's start, before its live side.
  #
  # @param scene [Scene_Battle] The battle.
  def self.await(scene)
    asking = @asking
    return unless asking
    return if asking[:mode] == :start && await_party(scene, asking)

    frames = 0
    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Asking #{MGQ_MpBattlesSync.player} to join their battle...") do
      frames += 1
      asking[:answer] || (frames >= ANSWER_FRAMES ? :silent : nil)
    end
    @asking = nil
    return join_late(asking) if answer == :accepted

    log("#{MGQ_MpBattlesSync.player} does not take the encounter into battle #{asking[:bid]} (#{answer}), it starts on its own")
    # A host whose late answer took the player in forgets them.
    MGQ_MpBattlesCoop.tell_map([asking[:seat]], "off", "bid" => asking[:bid]) unless answer == :refused
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    MGQ_MpBattlesCoop.host(asking[:troop], asking[:escape], asking[:lose])
    fight_alone unless MGQ_MpBattlesSync.role
    release_companions(asking)
  rescue => e
    @asking = nil
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    release_companions(asking) if asking
    log("waiting for the running battle's host failed: #{e.class}: #{e.message}")
  end

  # Waits for the party members near whom a running battle has no room for along with the player
  # to say whether they start a battle with the player instead (see ask), PARTY_ANSWER_FRAMES at
  # most. Should one say yes, the encounter starts on its own, inviting those who did not say no;
  # else the player asks the running battle alone, and the members walk on.
  #
  # @param scene [Scene_Battle] The battle.
  # @param asking [Hash] The request, the members' seats under :party, their answers under :answers.
  # @return [Boolean] Whether the encounter started on its own.
  def self.await_party(scene, asking)
    party = Array(asking[:party])
    frames = 0
    MGQ_MpBattlesSync::Waiting.wait_for(scene, "Asking your party to start a battle...") do
      frames += 1
      party.all? { |seat| asking[:answers].key?(seat) } || frames >= PARTY_ANSWER_FRAMES ? :done : nil
    end
    starters = party.select { |seat| asking[:answers][seat] }
    @stays_out = party - starters
    names = lambda { |seats| seats.empty? ? "nobody" : seats.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(", ") }
    if starters.empty?
      log("no party member starts a battle with the player (said no or stayed silent: #{names.call(party)}), so the player asks #{asking[:name]}'s battle alone")
      MGQ_MpBattlesCoop.tell_map(party, "off", "map" => $game_map.map_id, "bid" => asking[:bid])
      tell_host(asking)
      return false
    end

    @asking = nil
    log("#{names.call(starters)} start a battle with the player instead of #{asking[:name]}'s, which has no room for them all; staying out: #{names.call(@stays_out)}")
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    MGQ_MpBattlesCoop.host(asking[:troop], asking[:escape], asking[:lose])
    fight_alone unless MGQ_MpBattlesSync.role
    release_companions(:seats => Array(asking[:seats]) + @stays_out)
    true
  end

  # Reports whether a party member said no to starting a battle with the player (see await_party),
  # whom the encounter that starts then leaves out of its invites.
  #
  # @param seat [Integer] The member's seat.
  # @return [Boolean] Whether they did.
  def self.stays_out?(seat)
    Array(@stays_out).include?(seat)
  end

  # Readies the player's battle to join the host's as a guest: its escape, lose and enemy rates, no
  # first strike or surprise, which the game rolled for the encounter. The encounter's own come back
  # should the host call it off (see fight_own).
  #
  # @param asking [Hash] The request, with the host's escape, lose and enemy rates.
  def self.join_late(asking)
    MGQ_MpBattlesCoop.borrow_rates("rates" => asking[:host_rates])
    @late = :requester
    @own_flags = [asking[:escape], asking[:lose]]
    MGQ_MpGame.set(BattleManager, :can_escape, asking[:host_escape] ? true : false)
    MGQ_MpGame.set(BattleManager, :can_lose, asking[:host_lose] ? true : false)
    MGQ_MpGame.set(BattleManager, :preemptive, false)
    MGQ_MpGame.set(BattleManager, :surprise, false)
    MGQ_MpBattlesServed.become_guest(asking[:bid].to_s) if asking[:served] && defined?(MGQ_MpBattlesServed)
    log("joins #{MGQ_MpBattlesSync.player}'s battle #{asking[:bid]} at its next command phase, the encounter's enemies with the player")
    release_companions(:seats => Array(asking[:seats]) - asking[:taken]) if asking[:taken]
  end

  # Takes the answer of the host the player asked, see ask.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who answered.
  # @param message [Hash] The answer, with the battle's escape, lose and enemy rates (see
  #   MGQ_MpBattlesCoop.borrow_rates) when it takes the player in.
  # @param answer [Symbol] :accepted or :refused.
  def self.take_answer(peer, message, answer)
    asking = @asking
    unless asking && peer && peer.seat == asking[:seat] && message["bid"].to_s == asking[:bid].to_s
      return log("#{answer} for battle #{message['bid']} from #{who(peer)} ignored: not the battle the player asked to join")
    end

    asking[:host_escape] = message["escape"] == "1"
    asking[:host_lose] = message["lose"] == "1"
    asking[:host_rates] = message["rates"]
    asking[:served] = message["served"].to_s == "1"
    asking[:taken] = message["seats"].to_s.split(",").map(&:to_i) if message.key?("seats")
    asking[:answer] = answer
    log("#{who(peer)} answered for battle #{message['bid']}: #{answer}")
  end

  # Takes a party member's answer whether they start a battle with the player, see await_party.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The answer: the running battle's id, "ok" 1 for yes.
  def self.take_party_answer(peer, message)
    asking = @asking
    unless asking && peer && Array(asking[:party]).include?(peer.seat) && message["bid"].to_s == asking[:bid].to_s
      return log("party answer for battle #{message['bid']} from #{who(peer)} ignored: the player asks nobody about it")
    end

    asking[:answers][peer.seat] = message["ok"] == "1"
    log("#{who(peer)} #{message['ok'] == '1' ? 'starts' : 'does not start'} a battle with the player")
  end

  # The party member's side.

  # Asks party members in the notification box to come along to a running battle outside the party
  # that the player joins: :join where it has room for them all, which they join by choice then (see
  # accept_party), else :start, whether they start a battle with the player instead.
  #
  # @param seats [Array<Integer>] The members' seats.
  # @param mode [Symbol] :join or :start.
  # @param host [MGQ_MpOverworldSync::Peers::Peer] The running battle's host.
  # @param bid [String] Its id.
  def self.offer_party(seats, mode, host, bid)
    MGQ_MpBattlesCoop.tell_map(seats, "party_hot", "mode" => mode, "host" => host.seat, "bid" => bid, "map" => $game_map.map_id)
    log("asked #{seats.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')} in the notification box to " \
        "#{mode == :join ? 'join' : 'start a battle with the player instead of joining'} #{who(host)}'s battle #{bid}")
  end

  # Asks the player's party members near to join a running battle outside the party along with the
  # player, who asked to join it by choice (see MGQ_MpBattlesJoin.request), where it has room for
  # them all; a battle without that room takes the player alone.
  #
  # @param host [MGQ_MpOverworldSync::Peers::Peer] The battle's host.
  # @param bid [String] Its id.
  def self.offer_party_join(host, bid)
    return unless raid?

    party = party_near(host)
    return if party.empty?

    room = room_in(host)
    return log("asked no party member along to #{who(host)}'s battle #{bid}: it takes #{room} more players, not #{party.size + 1}") unless room > party.size

    offer_party(party.map(&:seat), :join, host, bid)
  rescue => e
    log("asking the party along failed: #{e.class}: #{e.message}")
  end

  # Takes a party member's offer to come along to a running battle, see offer_party, which then
  # stands in the notification box.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member who joins it.
  # @param message [Hash] The offer: "mode", the battle's host seat under "host", its id and map.
  def self.take_party_offer(peer, message)
    return log("party offer from #{who(peer)} ignored: their map #{message['map']} is not the player's") unless message["map"].to_i == $game_map.map_id

    mode = message["mode"] == "start" ? :start : :join
    @party_offers[peer.seat] = { :mode => mode, :host => message["host"].to_i, :bid => message["bid"].to_s, :at => Time.now }
    log("#{who(peer)} asks the player to #{mode == :join ? 'join' : 'start a battle with them instead of'} #{MGQ_MpBattlesSync.who(message['host'].to_i)}'s battle #{message['bid']}")
  end

  # Finds the standing offer of a party member, dropping it once it lapsed: older than its time, the
  # player or the member in another battle, or the running battle over.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @return [Hash, nil] The offer, see take_party_offer, nil for none.
  def self.party_offer(peer)
    offer = @party_offers[peer.seat]
    return nil unless offer

    reason = party_offer_end(peer, offer)
    return offer unless reason

    @party_offers.delete(peer.seat)
    log("dropped #{who(peer)}'s offer to come along to battle #{offer[:bid]}: #{reason}")
    nil
  end

  # Tells why a party member's offer lapsed, see party_offer.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param offer [Hash] The offer.
  # @return [String, nil] The reason, nil while it stands.
  def self.party_offer_end(peer, offer)
    lasts = offer[:mode] == :start ? PARTY_ANSWER_FRAMES / 60 : PARTY_OFFER_SECONDS
    return "it stood #{lasts} s" if Time.now - offer[:at] > lasts
    return "the player is in a battle" if MGQ_MpBattlesSync.role || MGQ_MpBattlesCoop.in_battle_scene?

    fights = peer.state["rb"].to_s
    return "#{peer.state['name']} fights another battle" unless fights.empty? || fights == offer[:bid]

    host = MGQ_MpOverworldSync::Peers.at(offer[:host])
    "the battle is over" unless host && host.state["rb"].to_s == offer[:bid]
  end

  # Writes the notification box's line of a party member's offer.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param offer [Hash] The offer.
  # @return [String] The line.
  def self.party_offer_text(peer, offer)
    "#{offer[:mode] == :join ? 'Join' : 'Start'} battle with #{peer.state['name']}?"
  end

  # Takes up a party member's offer: joins the running battle by choice, or tells the member the
  # player starts a battle with them.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.accept_party(peer)
    offer = party_offer(peer)
    return log("did not come along with #{who(peer)}: the offer no longer stands") unless offer

    @party_offers.delete(peer.seat)
    return answer_party(peer, offer, true) if offer[:mode] == :start

    join = MGQ_MpBattlesJoin
    host = MGQ_MpOverworldSync::Peers.at(offer[:host])
    busy = join.busy_reason
    if busy || host.nil? || join.open_battle(host).nil?
      join.notice("Cannot join that battle now.")
      return log("did not join battle #{offer[:bid]} with #{who(peer)}: #{busy || 'it takes nobody in now'}")
    end

    join.request(host, offer[:bid], false)
  rescue => e
    log("coming along with a party member failed: #{e.class}: #{e.message}")
  end

  # Declines a party member's offer, telling a member who waits for the answer.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.decline_party(peer)
    offer = @party_offers.delete(peer.seat)
    return unless offer

    offer[:mode] == :start ? answer_party(peer, offer, false) : log("does not join battle #{offer[:bid]} with #{who(peer)}")
  end

  # Answers a party member whether the player starts a battle with them, see await_party.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param offer [Hash] Their offer.
  # @param yes [Boolean] Whether the player does.
  def self.answer_party(peer, offer, yes)
    MGQ_MpBattlesCoop.tell_map([peer.seat], "party_ans", "bid" => offer[:bid], "ok" => yes ? 1 : 0)
    log("answered #{who(peer)}: the player #{yes ? 'starts' : 'does not start'} a battle with them")
  end

  # Forgets a party member's offer once they call their request off.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.drop_party_offer(peer)
    offer = peer && @party_offers.delete(peer.seat)
    log("dropped #{who(peer)}'s offer to come along to battle #{offer[:bid]}: they called it off") if offer
  end

  # What a party member's offer adds to the notification box, see offer_party.
  module Offers
    # Tells nothing to the World overview.
    #
    # @param _peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [nil] Always.
    def self.call_of(_peer)
      nil
    end

    # Tells a party member's offer for the notification box.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Notice, nil] The offer, nil for none.
    def self.notice_of(peer)
      hotjoin = MGQ_MpBattlesHotjoin
      offer = hotjoin.party_offer(peer)
      return nil unless offer

      MGQ_MpActions::Notice.new([:party_battle, peer.seat], hotjoin.party_offer_text(peer, offer), MGQ_MpCoop::INVITE_COLOR, offer[:mode] == :join ? "Join" : "Start",
                                lambda { hotjoin.accept_party(peer) }, lambda { hotjoin.decline_party(peer) }, offer[:at])
    end

    # Adds no choice to another player's menu.
    #
    # @param _peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [nil] Always.
    def self.peer_option(_peer)
      nil
    end

    # Adds no choice to the player's own row.
    #
    # @return [Array] None.
    def self.own_options
      []
    end
  end

  # The joining side, again.

  # Lists the players the player's request to join a running battle brings along, who stand still
  # until its host invites them or the encounter starts on its own.
  #
  # @return [Array<Integer>] Their world seats, none without a request.
  def self.asked_seats
    @asking ? Array(@asking[:seats]) : []
  end

  # Reports whether an invite comes from the host the player asks to take their encounter in, to
  # the same battle: another player's request brought the player along, but the player's own
  # request covers them (see release_companion), so the invite needs no answer.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who invites.
  # @param message [Hash] The invite.
  # @return [Boolean] Whether it does.
  def self.asks?(peer, message)
    asking = @asking
    asking && peer && peer.seat == asking[:seat] && message["bid"].to_s == asking[:bid].to_s && message["hot"] == "1" ? true : false
  end

  # Reports whether the player joins a running battle late, for their encounter or invited by its
  # host, which sends its roster only at its next command phase.
  #
  # @return [Boolean] Whether they do.
  def self.late?
    !@late.nil?
  end

  # Reports whether the player joins a running battle late for their own encounter, whose troop the
  # player's game still has until the roster comes.
  #
  # @return [Boolean] Whether they do.
  def self.own_troop?
    @late == :requester
  end

  # Notes whether an invite the player accepts is to a running battle, see late?, whether its host
  # marked it a boss battle, which stays one should the player take it over, and the raid boss's
  # pools it fights (see MGQ_MpRaidPool.note_invite). Called by
  # MGQ_MpBattlesCoop.accept, follow and yield_to_rival.
  #
  # @param message [Hash] The invite, "hot" 1 for a running battle, "boss" 1 for a boss battle.
  def self.note_invite(message)
    @late = message["hot"] == "1" ? :invited : nil
    @boss_battle = message["boss"] == "1"
    @called_off = false
    MGQ_MpRaidPool.note_invite(message) if defined?(MGQ_MpRaidPool)
  end

  # Takes the host's word that it called off the player's joining before its roster came, see
  # MGQ_MpBattlesCoop.join, which then lets the encounter start on its own.
  def self.call_off_own
    @called_off = true
    log("#{MGQ_MpBattlesSync.player} called the player's joining off before its roster came")
  end

  # Reports whether the host called the player's joining off, see call_off_own.
  #
  # @return [Boolean] Whether it did.
  def self.called_off?
    @called_off ? true : false
  end

  # Starts the player's own encounter alone, since the running battle never took them in: its own
  # escape, lose and enemy rates back, from its start (see MGQ_MpBattlesCoop.take_over).
  #
  # @param reason [String] Why, for Multiplayer InGame.log.
  # @return [Symbol] :gone, after which the battle goes on as the player's own.
  def self.fight_own(reason)
    own_flags_back
    MGQ_MpBattlesCoop.give_back_rates
    @late = nil
    @called_off = false
    log("the encounter starts on its own: #{reason}")
    :gone
  end

  # Ends the wait of a player who joins a running battle late without its roster: tells the host
  # the player stopped waiting, so it never takes them in after all, and puts the encounter's own
  # escape and lose back, since any such ending leaves the player fighting it alone or ends it.
  # Called by MGQ_MpBattlesCoop.join.
  #
  # @param ending [Symbol] How the wait ended, see MGQ_MpBattlesSync::Waiting.wait_for.
  def self.give_up(ending)
    return unless late?

    log("stops waiting to join #{MGQ_MpBattlesSync.player}'s battle #{MGQ_MpBattlesSync.battle_id}: #{ending.inspect}")
    MGQ_MpBattlesSync::Channel.post("decline")
    own_flags_back
  rescue => e
    log("giving up joining failed: #{e.class}: #{e.message}")
  end

  # Puts back the escape and lose of the player's own encounter, which join_late replaced with the
  # host's.
  def self.own_flags_back
    return if @own_flags.nil?

    escape, lose = @own_flags
    @own_flags = nil
    MGQ_MpGame.set(BattleManager, :can_escape, escape)
    MGQ_MpGame.set(BattleManager, :can_lose, lose)
  end

  # The host's side.

  # Takes another player's request to take their encounter into the battle the player hosts, or
  # fights alone: takes it in when it can (see refusal), else refuses it. A player another request
  # brought along comes with their own encounter instead (see release_companion).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asks.
  # @param message [Hash] The request: the battle's id, the encounter's troop and enemies, and the
  #   seats of the players who come along.
  def self.take_request(peer, message)
    return log_once([:classic_request, peer && peer.seat], "ignored a request to join from #{who(peer)}: not a Raid World") unless raid?

    sync = MGQ_MpBattlesSync
    release_companion(peer.seat)
    known = (sync.role ? Array(sync.seats) : []) + pending_seats + [MGQ_MpOverworldSync::Me.seat, peer.seat]
    others = message["seats"].to_s.split(",").map(&:to_i) - known
    reason = refusal(message, peer.seat)
    return refuse(peer, message, reason) if reason

    seats = fitting_players([peer.seat] + others)
    take_in_later(peer, seats, fitting_enemies(parse_entries(message["enemies"]).reject { |entry| entry[3] == 1 }))
  rescue => e
    log("taking a request to join failed: #{e.class}: #{e.message}")
  end

  # Keeps of the players a request brings the asking player and as many of the others as the
  # battle still takes, so a crowd near the encounter never keeps its player out.
  #
  # @param seats [Array<Integer>] Their seats, the asking player's first.
  # @return [Array<Integer>] The seats taken in.
  def self.fitting_players(seats)
    room = MGQ_MpBattlesCoop::RAID_PLAYERS - players_count - pending_seats.size
    kept = seats.first([room, 1].max)
    left = seats - kept
    log("left #{left.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')} out of the request: the battle takes #{room} more players") unless left.empty?
    kept
  end

  # Keeps of an encounter's enemies those this game knows and the troop has room for, see
  # place_anew, so a full troop takes its player in all the same, with fewer enemies or none.
  #
  # @param enemies [Array<Array>] The encounter's enemies.
  # @return [Array<Array>] Those taken in, at their places in the troop.
  def self.fitting_enemies(enemies)
    known, missing = enemies.partition { |entry| $data_enemies[entry[0]] }
    log("left out the encounter's enemies #{missing.map(&:first).join(', ')}: they are missing from this game") unless missing.empty?
    place_anew(known)
  end

  # Takes a player who asks with their own encounter out of another encounter that brought them
  # along and has not been taken in for them yet: both requests left at once, each player seeing the
  # other walk the map, and their own request brings them now, or else refuses them.
  #
  # @param seat [Integer] The asking player's seat.
  def self.release_companion(seat)
    @pending.each do |entry|
      next if entry[:requester] == seat || !entry[:seats].include?(seat)

      drop_seat(entry, seat, "they ask with their own encounter")
    end
    @pending.reject! { |entry| entry[:seats].empty? }
  end

  # Tells why the player's battle cannot take another player's encounter in. Players beyond its
  # room and enemies beyond its troop's are left out instead, see fitting_players and
  # fitting_enemies.
  #
  # @param message [Hash] The request.
  # @param seat [Integer] The asking player's seat.
  # @return [String, nil] The reason, nil when it can.
  def self.refusal(message, seat)
    sync = MGQ_MpBattlesSync
    bid, host = running_battle
    return "the player fights no battle others may join" unless bid
    return "the player is a guest of battle #{bid}" unless host == MGQ_MpOverworldSync::Me.seat
    return "it asks for battle #{message['bid']}, the player's is #{bid}" unless message["bid"].to_s == bid.to_s
    return "the player's battle still gathers its players" if sync.live? && !MGQ_MpBattlesCoop.active?
    return "the computer plays on for those who left" if sync.live? && sync.solo?
    return "the battle ends" if BattleManager.respond_to?(:battle_end?) && BattleManager.battle_end?
    return "the player's battle is a boss battle" if boss_battle?
    return "the encounter's troop #{message['troop']} is a boss" if MGQ_MpRaidBosses.boss?(message["troop"])
    # The battle's guests who left stay among its seats, which the next command phase takes out.
    return "its player was in this battle before" if sync.role && Array(sync.seats).include?(seat)
    return "its player is already taken in with another encounter" if pending_seats.include?(seat)

    count = players_count + pending_seats.size
    "#{count} players fight, as many as a battle takes" if count >= MGQ_MpBattlesCoop::RAID_PLAYERS
  end

  # Counts the players of the battle the player hosts, the player included.
  #
  # @return [Integer] The players.
  def self.players_count
    MGQ_MpBattlesSync.role == :host ? MGQ_MpBattlesSync.guests_in.size + 1 : 1
  end

  # Lists the seats of the players taken in who have not joined yet.
  #
  # @return [Array<Integer>] The seats.
  def self.pending_seats
    @pending.map { |entry| entry[:seats] }.flatten
  end

  # Turns another player's request down, so their encounter starts on its own.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asked.
  # @param message [Hash] The request.
  # @param reason [String] Why, for Multiplayer InGame.log.
  def self.refuse(peer, message, reason)
    MGQ_MpBattlesCoop.tell_map([peer.seat], "hot_no", "bid" => message["bid"].to_s)
    log("refused #{who(peer)}'s encounter with troop #{message['troop']} for battle #{message['bid']}: #{reason}")
  end

  # Takes another player's encounter in: keeps its players and enemies for the next command phase
  # (see settle), tells its player, and invites the players who come along. A player who fights
  # alone becomes the host of their battle, which turns live once someone joins (see before_phase).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asked.
  # @param seats [Array<Integer>] The seats of the players who join, the asking player's first.
  # @param placed [Array<Array>] The encounter's enemies where they stand in the player's troop.
  def self.take_in_later(peer, seats, placed)
    sync = MGQ_MpBattlesSync
    bid = running_battle[0]
    sync.join_world(:host, bid, [], "the players") unless sync.role
    @pending << { :requester => peer.seat, :seats => seats.dup, :enemies => placed, :at => Time.now, :added => false }
    sync.expect(seats)
    coop = MGQ_MpBattlesCoop
    fields = invite_fields(seats - [peer.seat])
    coop.tell_map([peer.seat], "hot_ok", "bid" => bid, "escape" => fields["escape"], "lose" => fields["lose"], "rates" => fields["rates"], "seats" => seats.join(","),
                                         "served" => fields["served"])
    coop.tell_map(seats - [peer.seat], "invite", fields) unless fields["seats"].empty?
    log("takes #{who(peer)}'s encounter into battle #{bid} at the next command phase: #{placed.size} enemies at x " \
        "#{placed.map { |entry| entry[1] }.join(', ')}, players #{seats.map { |seat| sync.who(seat) }.join(', ')}")
  end

  # Takes in a player who joins the battle the player hosts, or fights alone, by choice (see
  # battles_coop_join.rbx): as a player another encounter brings along, without enemies, so an
  # event's battle and a boss battle take them too. They join at the next command phase, see settle.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asked.
  def self.take_in_player(peer)
    sync = MGQ_MpBattlesSync
    bid = running_battle[0]
    sync.join_world(:host, bid, [], "the players") unless sync.role
    @pending << { :requester => peer.seat, :seats => [peer.seat], :enemies => [], :at => Time.now, :added => false }
    sync.expect([peer.seat])
    MGQ_MpBattlesCoop.tell_map([peer.seat], "invite", invite_fields([peer.seat]))
    log("takes #{who(peer)} into battle #{bid} at the next command phase: they join by choice, without enemies")
  end

  # Writes the invite to the battle the player hosts for players who join it late: its troop, escape,
  # lose and enemy rates (see MGQ_MpBattlesCoop.borrow_rates), whether it is a boss battle,
  # which stays one should one of them take it over, and the raid boss's pools it fights.
  #
  # @param seats [Array<Integer>] The seats of the players invited.
  # @return [Hash] The invite's fields.
  def self.invite_fields(seats)
    troop = MGQ_MpGame.get($game_troop, :troop_id)
    fields = { "bid" => running_battle[0], "troop" => troop, "escape" => MGQ_MpGame.get(BattleManager, :can_escape) ? 1 : 0,
               "lose" => MGQ_MpGame.get(BattleManager, :can_lose) ? 1 : 0, "seats" => seats.join(","), "map" => $game_map.map_id, "hot" => 1,
               "rates" => MGQ_MpBattlesCoop.rates_text }
    fields["boss"] = 1 if boss_battle?
    # The battle server's players come onto its battle channel.
    fields["served"] = 1 if defined?(MGQ_MpBattlesServed) && MGQ_MpBattlesServed.server?
    fields.update(MGQ_MpRaidPool.invite_fields) if defined?(MGQ_MpRaidPool)
    fields
  end

  # Reports whether the battle the player fights is a boss battle: its troop, or the word of the
  # host whose battle the player took over.
  #
  # @return [Boolean] Whether it is.
  def self.boss_battle?
    @boss_battle || MGQ_MpRaidBosses.battle?(MGQ_MpGame.get($game_troop, :troop_id)) ? true : false
  end

  # Finds places in the troop for an encounter's enemies: within TROOP_LIMIT with every enemy of the
  # troop and those taken in before, and on the screen where at most MAX_OVERLAP of each picture
  # hides behind another. A fallen enemy's place on the screen is free. Pictures as wide as the
  # screen stand in its middle and count for no overlap, as the game's own troops stack them there
  # (Game_Troop#auto_correct_bitmap_xy).
  #
  # The fallen count toward TROOP_LIMIT too, since the troop keeps them among its members.
  #
  # @param entries [Array<Array>] The enemies: each one's id, screen x and y, and 1 when hidden.
  # @param queued [Array<Array>] The enemies of the encounters taken in before that have not joined
  #   the troop yet, which keep their places.
  # @return [Array<Array>, nil] The enemies at their new places, nil when one finds none.
  def self.place(entries, queued = queued_enemies)
    return nil if $game_troop.members.size + queued.size + entries.size > TROOP_LIMIT

    standing = $game_troop.members.reject { |enemy| fallen?(enemy) }

    taken = standing.reject(&:hidden?).map { |enemy| span(enemy.screen_x, enemy_width(enemy)) }
    taken.concat(queued.map { |id, x, _y, _hidden| span(x, id_width(id)) })
    taken.reject! { |left, right| full_width?(right - left) }
    entries.map do |id, _x, y, _hidden|
      width = id_width(id)
      next [id, screen_width / 2, y, 0] if full_width?(width)

      x = free_x(width, taken)
      return nil unless x

      taken << span(x, width)
      [id, x, y, 0]
    end
  end

  # Lists the enemies of the encounters taken in that have not joined the troop yet.
  #
  # @return [Array<Array>] Each enemy's id, screen x and y, and 0.
  def self.queued_enemies
    @pending.reject { |entry| entry[:added] }.map { |entry| entry[:enemies] }.flatten(1)
  end

  # Reports whether an enemy of the troop has fallen, also one hidden after its defeat, so its
  # place is free.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @return [Boolean] Whether it has.
  def self.fallen?(enemy)
    enemy.dead? || (enemy.hidden? && enemy.respond_to?(:death_state?) && enemy.death_state?) ? true : false
  end

  # Reports whether a picture is as wide as the battle screen.
  #
  # @param width [Integer] The picture's width.
  # @return [Boolean] Whether it is.
  def self.full_width?(width)
    width >= screen_width
  end

  # Finds the place on the screen where a picture hides least behind the others, the nearest to the
  # middle among equals.
  #
  # @param width [Integer] The picture's width.
  # @param taken [Array<Array<Integer>>] The others' left and right edges.
  # @return [Integer, nil] The picture's middle, nil when every place hides more than MAX_OVERLAP.
  def self.free_x(width, taken)
    screen = screen_width
    half = width / 2
    spots = (half..(screen - half)).step(PLACE_STEP).to_a
    best = spots.min_by { |x| [crowding(x - half, x + half, taken), (x - screen / 2).abs] }
    best && crowding(best - half, best + half, taken) <= MAX_OVERLAP ? best : nil
  end

  # Measures how much a picture hides behind others, or they behind it.
  #
  # @param left [Integer] The picture's left edge.
  # @param right [Integer] Its right edge.
  # @param taken [Array<Array<Integer>>] The others' left and right edges.
  # @return [Float] The largest share of the narrower of two pictures that the other covers.
  def self.crowding(left, right, taken)
    shares = taken.map do |other_left, other_right|
      overlap = [right, other_right].min - [left, other_left].max
      narrower = [right - left, other_right - other_left].min
      overlap > 0 ? overlap.to_f / [narrower, 1].max : 0.0
    end
    shares.max || 0.0
  end

  # Tells the left and right edges of a picture.
  #
  # @param x [Integer] Its middle, an enemy's screen x.
  # @param width [Integer] Its width.
  # @return [Array<Integer>] The edges.
  def self.span(x, width)
    [x - width / 2, x + width / 2]
  end

  # Measures an enemy's picture.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @return [Integer] Its width, DEFAULT_WIDTH when unknown.
  def self.enemy_width(enemy)
    picture_width(enemy.battler_name, enemy.battler_hue)
  rescue
    DEFAULT_WIDTH
  end

  # Measures the picture of an enemy of the database.
  #
  # @param enemy_id [Integer] The enemy's id.
  # @return [Integer] Its width, DEFAULT_WIDTH when unknown.
  def self.id_width(enemy_id)
    data = $data_enemies[enemy_id]
    picture_width(data.battler_name, data.battler_hue)
  rescue
    DEFAULT_WIDTH
  end

  # Measures a battler's picture through the game's cache, which keeps it for the sprite.
  #
  # @param name [String] The picture's name.
  # @param hue [Integer] Its hue.
  # @return [Integer] Its width, DEFAULT_WIDTH when unknown.
  def self.picture_width(name, hue)
    width = Cache.battler(name, hue).width
    width > 0 ? width : DEFAULT_WIDTH
  rescue
    DEFAULT_WIDTH
  end

  # Reads the battle screen's width.
  #
  # @return [Integer] The width, SCREEN_WIDTH when unknown.
  def self.screen_width
    Graphics.width
  rescue
    SCREEN_WIDTH
  end

  # Turns the battle the player fights alone live for the players taken in, once one of them
  # joined, before the command phase opens: the player hosts it, the multiplayer rules on, the
  # player's squad as the party's first player, the battle streamed. Called as a command phase
  # starts, before battles_sync_live.rbx opens it.
  #
  # @param scene [Scene_Battle] The battle.
  def self.before_phase(scene)
    return unless waiting_alone?
    return if MGQ_MpGame.get(BattleManager, :phase) == :input

    expire
    return stay_alone if @pending.empty?

    go_live(scene) if MGQ_MpBattlesSync::Channel.pending("join") > 0
  rescue => e
    log("readying the battle for the players taken in failed: #{e.class}: #{e.message}")
  end

  # Reports whether the player hosts the battle they fight alone for the players taken in, who have
  # not joined yet (see take_in_later).
  #
  # @return [Boolean] Whether they do.
  def self.waiting_alone?
    sync = MGQ_MpBattlesSync
    sync.role == :host && sync.coop? && !sync.live?
  end

  # Ends hosting the battle the player fights alone once nobody taken in is left to join: it stays
  # the player's own.
  def self.stay_alone
    log("nobody taken into battle #{MGQ_MpBattlesSync.battle_id} joined it, it stays the player's own")
    MGQ_MpBattlesSync.finish
  end

  # Makes the battle the player fights alone a live co-op battle they host, see before_phase.
  #
  # @param scene [Scene_Battle] The battle.
  def self.go_live(scene)
    sync = MGQ_MpBattlesSync
    coop = MGQ_MpBattlesCoop
    sync.battle_started
    MGQ_MpBattles.begin(:coop)
    sync.show_everything
    coop.form(scene, coop.arrange([[MGQ_MpBattlesSync.own_seat, MGQ_Multiplayer::Player.name.to_s] + coop.own_build]))
    coop.note_troop
    sync::Recorder.start(:link)
    log("battle #{sync.battle_id} turns live for the players who join it, the player hosting")
  end

  # As host, takes in the players taken in whose join came, before the command phase is recorded:
  # their characters join the party, the encounter's enemies join the troop once its player
  # joined, the battle's guests get the new party and troop, and the new players the roster.
  # Called by the co-op battle's mode as a command phase opens, before it takes out those who left.
  #
  # @param scene [Scene_Battle] The battle.
  def self.settle(scene)
    sync = MGQ_MpBattlesSync
    return unless sync.host? && sync.coop?

    forget_ready
    return if @pending.empty?
    return call_off("the computer plays on for those who left") if sync.solo?

    # Players kept waiting too long have given up on the roster, even when their join came in time.
    expire
    joined = take_joins
    take_in(scene, joined) unless joined.empty?
  rescue => e
    log("taking players into the battle failed: #{e.class}: #{e.message}")
  end

  # Drops the word of the players who joined late that their battle is ready, which the host never
  # waits for, since it sends them its own at once (see take_in).
  def self.forget_ready
    @readied = Array(@readied).reject { |seat| MGQ_MpBattlesSync::Channel.take_from("ready", seat) }
  end

  # Takes the joins that came from the players taken in.
  #
  # @return [Hash{Integer => String}] Each joining player's seat and join, see
  #   MGQ_MpBattlesCoop.own_build.
  def self.take_joins
    joined = {}
    pending_seats.each do |seat|
      body = MGQ_MpBattlesSync::Channel.take_from("join", seat)
      joined[seat] = body if body
    end
    joined
  end

  # Forgets the players taken in who turned their invite down or stopped waiting, left the battle
  # or the world, or did not join within WAIT_SECONDS; those who waited too long are told it is off.
  def self.expire
    channel = MGQ_MpBattlesSync::Channel
    @pending.each do |entry|
      entry[:seats].dup.each do |seat|
        reason = if channel.take_from("decline", seat) then "turned the invite down or stopped waiting"
                 elsif channel.take_from("leave", seat) then "left the battle"
                 elsif MGQ_MpBattlesSync.peer_at(seat).nil? then "left the world"
                 elsif Time.now - entry[:at] > WAIT_SECONDS then "did not join within #{WAIT_SECONDS} s"
                 end
        next unless reason

        drop_seat(entry, seat, reason)
        MGQ_MpBattlesCoop.tell_map([seat], "off", "bid" => MGQ_MpBattlesSync.battle_id) if reason.start_with?("did not")
      end
    end
    @pending.reject! { |entry| entry[:seats].empty? }
  end

  # Forgets a player taken in, and their join should it have come. Without the player who met
  # them, the encounter's enemies never join the troop.
  #
  # @param entry [Hash] The encounter they came with.
  # @param seat [Integer] Their seat.
  # @param reason [String] Why, for Multiplayer InGame.log.
  def self.drop_seat(entry, seat, reason)
    entry[:seats].delete(seat)
    entry[:enemies] = [] if seat == entry[:requester]
    MGQ_MpBattlesSync::Channel.take_from("join", seat)
    MGQ_MpBattlesSync.unexpect([seat])
    log("forgot #{MGQ_MpBattlesSync.who(seat)}, taken into battle #{MGQ_MpBattlesSync.battle_id}: #{reason}")
  end

  # Takes the players whose join came into the battle, see settle.
  #
  # @param scene [Scene_Battle] The battle.
  # @param joined [Hash{Integer => String}] Each joining player's seat and join.
  def self.take_in(scene, joined)
    sync = MGQ_MpBattlesSync
    coop = MGQ_MpBattlesCoop
    # What the battle showed before goes to its players before, the new ones not among them.
    sync::Recorder.flush if sync::Recorder.active?
    guests = sync.guests_in
    players = coop.players.map(&:to_a)
    joined.each do |seat, body|
      builds, vitals, max = sync::Wire.parse(body.to_s)
      peer = MGQ_MpBattlesSync.peer_at(seat)
      players << [seat, peer ? peer.state["name"].to_s : "?", builds.to_s, Array(vitals), max.is_a?(Integer) ? max : 0]
    end
    players = coop.arrange(players)
    coop.form(scene, players)
    added = add_enemies(scene, joined.keys)
    send_to(guests, "coop_party", sync::Wire.line([players.map(&:to_a)]))
    coop.share_troop(guests)
    sync.keep_seats(Array(sync.seats) | joined.keys)
    sync.unexpect(joined.keys)
    send_to(joined.keys, "roster", sync::Wire.line([late_entries, players.map(&:to_a), nil, $game_troop.turn_count.to_i]))
    send_to(joined.keys, "ready", sync.names)
    @readied = Array(@readied) | joined.keys
    @pending.each { |entry| entry[:seats] -= joined.keys }
    @pending.reject! { |entry| entry[:seats].empty? }
    log("took #{joined.keys.map { |seat| sync.who(seat) }.join(', ')} into battle #{sync.battle_id}#{added.empty? ? '' : ", and #{added.size} enemies"}")
    coop.tell_joined(joined.keys)
  end

  # Adds the enemies of the encounters whose player joined to the troop, as the game's troop setup
  # makes them, and starts their battle. Their places are found anew with the troop as it stands
  # now (see place_anew), since enemies may have fallen or been added after take_request placed
  # them.
  #
  # @param scene [Scene_Battle] The battle.
  # @param seats [Array<Integer>] The seats of the players who joined.
  # @return [Array<Game_Enemy>] The enemies added.
  def self.add_enemies(scene, seats)
    enemies = MGQ_MpGame.get($game_troop, :enemies)
    added = []
    @pending.each do |entry|
      next if entry[:added] || !seats.include?(entry[:requester])

      entry[:added] = true
      place_anew(entry[:enemies]).each do |id, x, y, _hidden|
        enemy = MGQ_MpBattlesCoop.new_enemy(enemies.size, id)
        enemy.screen_x = x
        enemy.screen_y = y
        enemies << enemy
        enemy.on_battle_start if enemy.respond_to?(:on_battle_start)
        added << enemy
      end
    end
    return added if added.empty?

    MGQ_MpGame.call($game_troop, :make_unique_names)
    escape_anew
    discover(added)
    MGQ_MpBattlesCoop.redraw_enemies(scene)
    log("added #{added.map { |enemy| "#{MGQ_MpBattlesSync.named(enemy)} at x #{enemy.screen_x}" }.join(', ')} to the troop")
    added
  end

  # Places an encounter's enemies anew as its player joins, see add_enemies, around the places of
  # the encounters still to join. When the troop has no room for them all any more, such as after
  # enemies added mid-battle, only the first of them that still find a place join it, none when no
  # place is left.
  #
  # The places take_request found are never taken instead, since they may lie past TROOP_LIMIT now.
  #
  # @param entries [Array<Array>] The encounter's enemies where take_request placed them.
  # @return [Array<Array>] The enemies that join, at their new places.
  def self.place_anew(entries)
    count = entries.size
    placed = nil
    count -= 1 until (placed = place(entries.first(count))) || count == 0
    dropped = entries.drop(placed ? count : 0)
    unless dropped.empty?
      log("left out #{dropped.size} of the encounter's #{entries.size} enemies (#{dropped.map(&:first).join(', ')}): " \
          "the troop of #{$game_troop.members.size} has no place left for them")
    end
    placed || []
  end

  # Computes the party's chance to escape anew for the troop that changed, as the game does at a
  # battle's setup from the troop's enemies.
  def self.escape_anew
    BattleManager.make_escape_ratio if BattleManager.respond_to?(:make_escape_ratio)
  rescue => e
    log("computing the chance to escape failed: #{e.class}: #{e.message}")
  end

  # Enters added enemies in the game's monster library, as the game's battle start does for the
  # troop's own.
  #
  # @param enemies [Array<Game_Enemy>] The enemies.
  def self.discover(enemies)
    library = $game_library
    return unless library && library.respond_to?(:enemy) && library.enemy.respond_to?(:set_discovery)

    library.enemy.set_discovery(enemies.map(&:enemy_id))
  rescue => e
    log("entering the added enemies in the library failed: #{e.class}: #{e.message}")
  end

  # Describes the troop's enemies for players who join the battle late, or guests whose troop
  # differs: as the guests rebuild them, the fallen ones fallen (see lay_down).
  #
  # @return [Array<Array>] Each enemy's id, screen x and y, and its mark (see mark).
  def self.late_entries
    $game_troop.members.map { |enemy| [enemy.enemy_id, enemy.screen_x, enemy.screen_y, mark(enemy)] }
  end

  # Marks an enemy of the troop as late_entries carries it.
  #
  # An enemy the game hid as it was eaten counts as fallen, not hidden: a guest's hidden copy would
  # be left out of the defeated that pay out at victory, since only the host's game marks it eaten.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @return [Integer] FALLEN when fallen, else 1 when hidden, else 0.
  def self.mark(enemy)
    return FALLEN if fallen?(enemy)

    enemy.hidden? ? 1 : 0
  end

  # Gives an enemy a guest rebuilds the death it has on the host, before its sprite is made, so it
  # stands invisible as the fallen do and comes back should the host's stream revive it.
  #
  # @param enemy [Game_Enemy] The enemy.
  def self.lay_down(enemy)
    death = enemy.respond_to?(:death_state_id) ? enemy.death_state_id : 1
    MGQ_MpBattlesSync::Playback.values(enemy, 0, MGQ_MpGame.get(enemy, :mp).to_i, MGQ_MpGame.get(enemy, :tp).to_i,
                                       [death], [0], MGQ_MpGame.get(enemy, :buffs), 0)
  rescue => e
    log("laying a fallen enemy down failed: #{e.class}: #{e.message}")
  end

  # Sends a battle message to some of the battle's players alone.
  #
  # @param seats [Array<Integer>] Their world seats.
  # @param kind [String] What it is.
  # @param body [String] The rest.
  def self.send_to(seats, kind, body)
    return if seats.empty?

    sync = MGQ_MpBattlesSync
    seats.each { |seat| (world = sync.world_seat_of(seat)) && sync.tell(world, kind, sync.battle_id, body) }
    log("sent #{kind} (#{body.size} bytes) to #{seats.map { |seat| sync.who(seat) }.join(', ')}")
  end

  # Tells every player taken in who has not joined that it is off, and forgets them.
  #
  # @param reason [String] Why, for Multiplayer InGame.log.
  def self.call_off(reason)
    seats = pending_seats
    @pending = []
    return if seats.empty?

    MGQ_MpBattlesSync.unexpect(seats)
    MGQ_MpBattlesCoop.tell_map(seats, "off", "bid" => MGQ_MpBattlesSync.battle_id.to_s)
    log("called joining battle #{MGQ_MpBattlesSync.battle_id} off for #{seats.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')}: #{reason}")
  end

  # Takes a player's word that hotjoining is off: as the host the player asked, their battle ended
  # before an answer came, which counts as a refusal; as a player taken in, their encounter starts
  # on its own after all. Called by MGQ_MpBattlesCoop.take_off.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @param message [Hash] Their message, the battle's id under "bid".
  # @return [Boolean] Whether it was about hotjoining, which is settled now.
  def self.take_off(peer, message)
    drop_party_offer(peer) if message["bid"].to_s == (@party_offers[peer.seat] || {})[:bid]
    asking = @asking
    if asking && peer.seat == asking[:seat] && message["bid"].to_s == asking[:bid].to_s
      asking[:answer] = :refused
      log("#{who(peer)} called battle #{asking[:bid]} off before answering")
      return true
    end

    entry = @pending.find { |candidate| candidate[:requester] == peer.seat && candidate[:seats].include?(peer.seat) }
    return false unless entry && message["bid"].to_s == MGQ_MpBattlesSync.battle_id.to_s

    drop_seat(entry, peer.seat, "their encounter starts on its own")
    @pending.reject! { |candidate| candidate[:seats].empty? }
    stay_alone if @pending.empty? && waiting_alone?
    true
  end

  # The guest's side, after the roster.

  # As guest, takes the troop the host sent once it changed (see MGQ_MpBattlesCoop.share_troop):
  # transforms, shows or hides this game's enemies as the host's and adds the new ones after them,
  # or rebuilds the whole troop when the host's is shorter (see MGQ_MpBattlesCoop.take_troop), and
  # learns the host's names anew. Keeps every enemy at its place, or this game's own troop when one
  # of them is no enemy this game has (see MGQ_MpBattlesCoop.repaired_enemies).
  #
  # @param scene [Scene_Battle] The battle.
  # @param body [String] The troop, see late_entries, and the host's names.
  def self.take_troop(scene, body)
    entries, names = MGQ_MpBattlesSync::Wire.parse(body.to_s)
    entries = MGQ_MpBattlesCoop.repaired_enemies(entries)
    count = $game_troop.members.size
    if entries && entries.size >= count
      match_enemies(entries.first(count))
      grow_troop(scene, entries[count..-1]) if entries.size > count
    elsif entries
      MGQ_MpBattlesCoop.take_troop(scene, entries)
    end
    escape_anew
    MGQ_MpBattlesSync::Names.setup(names) if names.is_a?(String)
  rescue => e
    log("taking the host's troop failed: #{e.class}: #{e.message}")
  end

  # Transforms, shows or hides this game's enemies as the host's troop has them, such as one an
  # event transformed or let appear, which only the host's game runs. Each keeps its HP and states,
  # a transformed one takes the host's place too, its sprite takes the new picture or fades in or
  # out by itself, and those that change get their letters as the game's own Enemy Transform and
  # Enemy Appear give them.
  #
  # @param entries [Array<Array>] The host's enemies at the places of this game's own: each one's
  #   id, screen x and y, and its mark (see mark).
  def self.match_enemies(entries)
    changed = $game_troop.members.zip(entries).select do |enemy, (id, x, y, mark)|
      transformed = enemy.enemy_id != id.to_i
      if transformed
        enemy.transform(id.to_i)
        enemy.screen_x = x.to_i
        enemy.screen_y = y.to_i
      end
      hidden = mark.to_i == 1
      next transformed if enemy.hidden? == hidden

      hidden ? enemy.hide : enemy.appear
      true
    end
    return if changed.empty?

    MGQ_MpGame.call($game_troop, :make_unique_names)
    log("transformed, showed or hid the enemies as the host's troop has them: " +
        changed.map { |enemy, _| "#{MGQ_MpBattlesSync.named(enemy)} #{enemy.enemy_id}#{' hidden' if enemy.hidden?}" }.join(', '))
  end

  # Adds the host's new enemies after this game's own, see take_troop, starting their battle,
  # entering them in the Library and giving a raid boss's pools their max HP, as the host's
  # add_enemies does.
  #
  # @param scene [Scene_Battle] The battle.
  # @param entries [Array<Array>] The new enemies: each one's id, screen x and y, and 1 when hidden,
  #   FALLEN when fallen.
  def self.grow_troop(scene, entries)
    enemies = MGQ_MpGame.get($game_troop, :enemies)
    added = entries.map do |id, x, y, hidden|
      enemy = MGQ_MpBattlesCoop.new_enemy(enemies.size, id.to_i)
      enemy.screen_x = x.to_i
      enemy.screen_y = y.to_i
      enemy.hide if hidden.to_i == 1
      enemies << enemy
      enemy.on_battle_start if enemy.respond_to?(:on_battle_start)
      enemy
    end
    MGQ_MpGame.call($game_troop, :make_unique_names)
    # The game letters only the living, and the host's fallen got theirs before they fell.
    added.zip(entries) { |enemy, entry| lay_down(enemy) if entry[3].to_i == FALLEN }
    discover(added)
    MGQ_MpRaidPool.rescale if defined?(MGQ_MpRaidPool) && MGQ_MpRaidPool.respond_to?(:rescale)
    MGQ_MpBattlesCoop.redraw_enemies(scene)
    log("added the host's #{entries.size} new enemies to the troop: #{added.map { |enemy| MGQ_MpBattlesSync.named(enemy) }.join(', ')}")
  end

  # Both sides.

  # Ends hotjoining with the battle: tells the players taken in who have not joined that it is off,
  # and forgets the player's own battle and a late join. Called once the battle's scene ended.
  def self.ended
    call_off("the battle is over") unless @pending.empty?
    forget
  rescue => e
    forget
    log("ending hotjoining failed: #{e.class}: #{e.message}")
  end

  # Forgets everything of hotjoining a reset interrupted, telling nobody.
  def self.drop
    log("forgot #{@pending.size} encounters taken in after a reset") unless @pending.empty?
    @pending = []
    @party_offers = {}
    forget
  end

  # Forgets the player's own battle, a request, a late join, the host's word of a boss battle, the
  # late guests' word that they are ready and the party members who stayed out of it.
  def self.forget
    @stays_out = []
    @own_bid = nil
    @boss_battle = false
    @readied = []
    @asking = nil
    @late = nil
    @own_flags = nil
    @called_off = false
  end

  # Installs the hook on a method the game's plugins may define anew. Called as the game starts
  # running.
  def self.install
    return if @installed

    @installed = true
    MGQ_MpHooks.around(Scene_Battle, :start_party_command_selection, "battles_coop_hotjoin") do |scene, _args, original|
      MGQ_MpBattlesHotjoin.before_phase(scene) unless scene.scene_changing?
      original.call
    end
  rescue => e
    log("command phase hook FAILED: #{e.class}: #{e.message}")
  end
end

# What this script tells in the player's state, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.state_fields { MGQ_MpBattlesHotjoin.state_fields }
  MGQ_MpOverworldSync.busy_scene { MGQ_MpBattlesHotjoin.busy_scene }
rescue => e
  MGQ_MpBattlesHotjoin.log("state FAILED: #{e.class}: #{e.message}")
end

# What this script adds to the notification box, through ui_actions.rbx.

begin
  MGQ_MpActions.offer(MGQ_MpBattlesHotjoin::Offers)
rescue => e
  MGQ_MpBattlesHotjoin.log("offers FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # Installs the hook as the game starts running. It wraps battles_sync_live.rbx's hook, which
  # loads later and so installs first, so a battle turns live before its command phase opens.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_coop_hotjoin") { MGQ_MpBattlesHotjoin.install }
rescue => e
  MGQ_MpBattlesHotjoin.log("hooks FAILED: #{e.class}: #{e.message}")
end
