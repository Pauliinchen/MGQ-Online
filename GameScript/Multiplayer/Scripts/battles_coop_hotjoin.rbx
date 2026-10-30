#----------------------------------------------------------------
#  battles_coop_hotjoin.rbx
#
#  Changelog:
#      Paulinchen  2026-10-30: Placed an encounter's enemies and checked requests to join through the rules in C#
#                            - Wrote the roster and the party and read the host's changed troop through the rules in C#
#                            - Told the widths of the encounter's pictures with a request, which the host places them by
#                            - Handed the players who stay out of the player's battle to the matchmaking in the DLL
#                            - Asked a running battle and the party along, and kept the party members' offers, through the DLL
#                            - Kept the list of the players taken in on the live session in the DLL
#      Paulinchen  2026-10-23: Started the recording without the deleted file sink
#                            - Sent to and found the battle's players by the seats they held at its start
#                            - Told the players taken in why their joining was called off
#                            - Numbered the messages to the players taken in
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
# running battle's host (ask, await, which the DLL's CoopAsking decides); the host takes them in while the players stay at most
# MGQ_MpBattlesCoop::RAID_PLAYERS, neither battle is a boss battle (battles_raid_bosses.rbx) and its
# troop has room for the new enemies (take_request), as the rules in C# decide (topics coop.*, which
# the DLL and the battle server's core answer). At the host's next command phase the new
# enemies join its troop and the new players its party, its guests hear of both, and the new
# players get its roster as guests who join late (settle). A host who fights alone turns its battle
# live for them (go_live). A refusal, or no answer within three seconds, starts the encounter on its
# own as usual. Every game pays for the whole troop it fought, as in any co-op battle.
#
# Every game in a Raid World tells the battle it fights in its state (state_fields), so a player
# who meets enemies knows whom to ask. It must never interrupt the game, so every entry point
# rescues.
module MGQ_MpBattlesHotjoin
  # The reason of an "off" whose battle is over, see MGQ_MpBattlesCoop::OFF_WHY_FIELD.
  OFF_OVER = "over"

  # The reason of an "off" whose battle takes no more players, such as one going on alone.
  OFF_CLOSED = "closed"

  # Seconds the host keeps the players it took in waiting for them to join, at its command phases.
  WAIT_SECONDS = 60

  # Frames a player who joins a running battle waits for its roster, which comes only at the host's
  # next command phase: longer than the host keeps them waiting.
  ROSTER_FRAMES = (WAIT_SECONDS + 15) * 60

  # Width of an enemy's picture when this game cannot measure it.
  DEFAULT_WIDTH = 160

  # Width of the battle screen when this game cannot read it.
  SCREEN_WIDTH = 640

  # What marks a fallen enemy where the troop's enemies a message carries mark hidden ones, see
  # late_entries.
  FALLEN = 2

  # The topic that places an encounter's enemies in the troop.
  PLACE_TOPIC = "coop.place"

  # The topic that writes the widths of the encounter's pictures a request tells.
  WRITE_WIDTHS_TOPIC = "coop.write_widths"

  # The topic that writes the troop's enemies a request carries.
  WRITE_ENTRIES_TOPIC = "coop.write_entries"

  # The topic that reads the troop's enemies a request carries.
  READ_ENTRIES_TOPIC = "coop.read_entries"

  # The topic that checks a request to join the running battle.
  INTAKE_TOPIC = "coop.intake"

  # The topic that reads the troop the host tells its guests once it changed.
  READ_TROOP_TOPIC = "coop.read_troop"

  # The topic that asks a running battle near to take the encounter in.
  ASK_TOPIC = "coop.ask"

  # The topic of a frame of the wait for the running battle's answer.
  ASK_WAIT_TOPIC = "coop.ask_wait"

  # The topic of a frame of the wait for the party members' answers.
  ASK_PARTY_WAIT_TOPIC = "coop.ask_party_wait"

  # The topic that ends the wait for the party members' answers.
  ASK_PARTY_END_TOPIC = "coop.ask_party_end"

  # The topic that ends the wait for the running battle's answer.
  ASK_END_TOPIC = "coop.ask_end"

  # The topic that lets the players a request brought along walk on.
  ASK_RELEASE_TOPIC = "coop.ask_release"

  # The topic that takes back a request that failed halfway.
  ASK_UNDO_TOPIC = "coop.ask_undo"

  # The topic that forgets a request whose wait failed.
  ASK_ABANDON_TOPIC = "coop.ask_abandon"

  # The topic that forgets a request once the battle it waits in ended.
  ASK_FORGET_TOPIC = "coop.ask_forget"

  # The topic that lists the party members' offers that stand.
  PARTY_OFFERS_TOPIC = "coop.party_offers"

  # The topic that takes up a party member's offer.
  ACCEPT_PARTY_TOPIC = "coop.accept_party"

  # The topic that declines a party member's offer.
  DECLINE_PARTY_TOPIC = "coop.decline_party"

  # The topic of the players taken into the player's running battle who have not joined yet, whose
  # list the DLL keeps on the live battle's session.
  PENDING_TOPIC = "coop.pending"

  # The standing offers of party members to come along to a running battle, by their seat, as the
  # DLL told them in the frame party_offers read them.
  @party_offers = {}

  # The party members who said no to starting a battle with the player.
  @stays_out = []

  extend MGQ_MpLog

  # What starts this script's lines in the log.
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

  # Names a player for the log.
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
    MGQ_Multiplayer::Bridge.call(WRITE_ENTRIES_TOPIC, entries.map { |entry| Array(entry).map(&:to_i) }).to_s
  end

  # Reads the enemies a message carries, see entries_text.
  #
  # @param text [String, nil] The enemies.
  # @return [Array<Array<Integer>>] Each enemy's id, screen x and y, and 1 when hidden; at most as
  #   many as a troop holds.
  def self.parse_entries(text)
    Array(MGQ_Multiplayer::Bridge.call(READ_ENTRIES_TOPIC, text.to_s))
  end

  # Tells the facts of the battle the player fights that decide whom it takes in, as the rules in C#
  # read them (topic coop.intake).
  #
  # @return [Hash] The facts.
  def self.intake_facts
    sync = MGQ_MpBattlesSync
    bid, host = running_battle
    pvp = MGQ_MpBattles.kind == :pvp || (defined?(MGQ_MpBattlesPvp) && MGQ_MpBattlesPvp::Battle.running?)
    { "bid" => bid && bid.to_s, "host" => host, "own_seat" => MGQ_MpOverworldSync::Me.seat, "role" => sync.role && sync.role.to_s,
      "seats" => Array(sync.seats), "live" => sync.live? ? true : false, "active" => MGQ_MpBattlesCoop.active?,
      "solo" => sync.solo? ? true : false, "ending" => BattleManager.respond_to?(:battle_end?) && BattleManager.battle_end? ? true : false,
      "boss" => boss_battle?, "pvp" => pvp ? true : false, "players" => players_count, "map" => $game_map.map_id }
  end

  # The joining side.

  # Asks the host of a co-op battle running near the player to take in the random encounter the
  # game just set up, as the DLL's asking side decides (topic coop.ask): with the free players the
  # encounter would invite as far as the battle has room, who stand still meanwhile, the player's
  # party members near asked along in the notification box. The player becomes a guest of that
  # battle, whose start waits for the answer (see await). Called by MGQ_MpBattlesCoop.offer.
  #
  # @param troop_id [Integer] The encounter's troop.
  # @param can_escape [Boolean] Whether the party may escape it.
  # @param can_lose [Boolean] Whether losing it goes on without a game over.
  # @return [Boolean] Whether the player asks, false when the encounter starts as usual.
  def self.ask(troop_id, can_escape, can_lose)
    return false unless raid?

    coop = MGQ_MpBattlesCoop
    entries = coop.troop_entries
    request = { "facts" => coop.facts, "troop" => troop_id.to_i, "escape" => can_escape ? true : false, "lose" => can_lose ? true : false,
                "boss" => MGQ_MpRaidBosses.boss?(troop_id) ? true : false, "entries" => entries.map { |entry| Array(entry).map(&:to_i) },
                "widths" => entries.map { |id, *_| [id.to_i, id_width(id)] }, "stays_out" => stays_out_seats }
    answer = MGQ_Multiplayer::Bridge.call(ASK_TOPIC, request)
    coop.take_status(answer)
    join = Array(answer.is_a?(Hash) ? answer["actions"] : nil).find { |action| action["kind"] == "join" }
    return false unless join

    @late = nil
    @boss_battle = false
    @called_off = false
    @stays_out = []
    MGQ_MpBattlesSync.join_world(:guest, join["bid"].to_s, Array(join["seats"]), join["label"].to_s)
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    true
  rescue => e
    log("asking to join a running battle failed: #{e.class}: #{e.message}")
    undo_ask
    false
  end

  # Takes back a request that failed halfway, so the encounter starts on its own as usual: ends the
  # guest's side of its battle, and the DLL tells the host it is off and lets the players it brought
  # along walk on, whom the encounter's own invite then holds anew (topic coop.ask_undo).
  def self.undo_ask
    return unless MGQ_MpBattlesCoop.asking_hot?

    @late = nil
    @called_off = false
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    MGQ_MpBattlesCoop.take_status(MGQ_Multiplayer::Bridge.call(ASK_UNDO_TOPIC, "facts" => MGQ_MpBattlesCoop.facts))
  rescue => e
    log("taking the request back failed: #{e.class}: #{e.message}")
  end

  # Waits at the battle's start for the answer of the host the player asked, see ask, the DLL
  # counting the frames: first, where the battle had no room for the party members near, for their
  # answers whether they start a battle with the player (topics coop.ask_party_wait and
  # coop.ask_party_end), then for the host's (coop.ask_wait and coop.ask_end). Taken in, the player
  # joins that battle as a guest (see join_late); refused, or without an answer, the player hosts
  # their encounter as usual. Called at the battle's start, before its live side.
  #
  # @param scene [Scene_Battle] The battle.
  def self.await(scene)
    coop = MGQ_MpBattlesCoop
    return unless coop.asking_hot?

    bridge = MGQ_Multiplayer::Bridge
    if coop.asking_party?
      MGQ_MpBattlesSync::Waiting.wait_for(scene, "Asking your party to start a battle...") { bridge.open? ? bridge.call(ASK_PARTY_WAIT_TOPIC) : "done" }
      started = bridge.call(ASK_PARTY_END_TOPIC)
      return fight_own_encounter(started) if started.is_a?(Hash)
    end
    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Asking #{MGQ_MpBattlesSync.player} to join their battle...") do
      bridge.open? ? bridge.call(ASK_WAIT_TOPIC) : "silent"
    end
    outcome = bridge.call(ASK_END_TOPIC, answer.to_s)
    return unless outcome.is_a?(Hash)

    outcome["late"] ? join_late(outcome) : fight_own_encounter(outcome)
  rescue => e
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    MGQ_MpBattlesCoop.take_status(MGQ_Multiplayer::Bridge.call(ASK_ABANDON_TOPIC, "facts" => MGQ_MpBattlesCoop.facts))
    log("waiting for the running battle's host failed: #{e.class}: #{e.message}")
  end

  # Starts the encounter on its own once the running battle never took it in, or the party members
  # start a battle with the player: the player hosts it as usual, leaving out the members who said
  # no, and the players the request brought along whom it does not invite walk on.
  #
  # @param outcome [Hash] How the request ended: "troop", "escape", "lose", "release" and "stays_out".
  def self.fight_own_encounter(outcome)
    @stays_out = Array(outcome["stays_out"])
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    MGQ_MpBattlesCoop.host(outcome["troop"], outcome["escape"], outcome["lose"])
    fight_alone unless MGQ_MpBattlesSync.role
    release_companions(outcome["release"])
  end

  # Lets the players a request brought along walk on, unless the encounter that starts on its own
  # invites them anew (topic coop.ask_release).
  #
  # @param seats [Array<Integer>] The players' seats.
  def self.release_companions(seats)
    return if Array(seats).empty?

    MGQ_Multiplayer::Bridge.call(ASK_RELEASE_TOPIC, "facts" => MGQ_MpBattlesCoop.facts, "seats" => Array(seats))
  end

  # Lists the party members who said no to starting a battle with the player (see await), whom the
  # encounter that starts then leaves out of its invites.
  #
  # @return [Array<Integer>] Their seats.
  def self.stays_out_seats
    Array(@stays_out)
  end

  # Readies the player's battle to join the host's as a guest: its escape, lose and enemy rates, no
  # first strike or surprise, which the game rolled for the encounter. The encounter's own come back
  # should the host call it off (see fight_own).
  #
  # @param outcome [Hash] How the request ended: the encounter's "escape" and "lose", the host's
  #   under "host", and the players brought along the host left out under "release".
  def self.join_late(outcome)
    host = outcome["host"] || {}
    @stays_out = Array(outcome["stays_out"])
    MGQ_MpBattlesCoop.borrow_rates("rates" => host["rates"])
    @late = :requester
    @own_flags = [outcome["escape"], outcome["lose"]]
    MGQ_MpGame.set(BattleManager, :can_escape, host["escape"] ? true : false)
    MGQ_MpGame.set(BattleManager, :can_lose, host["lose"] ? true : false)
    MGQ_MpGame.set(BattleManager, :preemptive, false)
    MGQ_MpGame.set(BattleManager, :surprise, false)
    MGQ_MpBattlesServed.become_guest(MGQ_MpBattlesSync.battle_id.to_s) if host["served"] && defined?(MGQ_MpBattlesServed)
    release_companions(outcome["release"])
  end

  # The party member's side.

  # Writes the notification box's line of a party member's offer.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param offer [Hash] The offer, its :mode.
  # @return [String] The line.
  def self.party_offer_text(peer, offer)
    "#{offer[:mode] == :join ? 'Join' : 'Start'} battle with #{peer.state['name']}?"
  end

  # Reads the party members' offers that stand once a bridge frame, which the DLL keeps and drops
  # once they lapsed (topic coop.party_offers), so every member's line in the box reads the same list.
  #
  # @return [Hash] Each offer by its member's seat: :mode, :host, :bid and :at.
  def self.party_offers
    frame = MGQ_Multiplayer::Bridge.frame_number
    return @party_offers if @offers_frame == frame

    @offers_frame = frame
    @party_offers = {}
    Array(MGQ_Multiplayer::Bridge.call(PARTY_OFFERS_TOPIC, MGQ_MpBattlesCoop.facts)).each do |seat, mode, host, bid, at|
      @party_offers[seat] = { :mode => mode.to_s.to_sym, :host => host, :bid => bid.to_s, :at => Time.at(at.to_i / 1000.0) }
    end
    @party_offers
  end

  # Takes up a party member's offer: joins the running battle by choice, or tells the member the
  # player starts a battle with them (topic coop.accept_party).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.accept_party(peer)
    @offers_frame = nil
    join = MGQ_MpBattlesJoin
    MGQ_MpBattlesCoop.take_status(MGQ_Multiplayer::Bridge.call(ACCEPT_PARTY_TOPIC, "facts" => MGQ_MpBattlesCoop.facts, "seat" => peer.seat, "busy" => join.busy_reasons))
  rescue => e
    log("coming along with a party member failed: #{e.class}: #{e.message}")
  end

  # Declines a party member's offer, telling a member who waits for the answer (topic
  # coop.decline_party).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.decline_party(peer)
    @offers_frame = nil
    MGQ_MpBattlesCoop.take_status(MGQ_Multiplayer::Bridge.call(DECLINE_PARTY_TOPIC, "facts" => MGQ_MpBattlesCoop.facts, "seat" => peer.seat))
  rescue => e
    log("declining a party member's offer failed: #{e.class}: #{e.message}")
  end

  # What a party member's offer adds to the notification box, see party_offers.
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
      offer = hotjoin.party_offers[peer.seat]
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
  #
  # @param text [String, nil] What the player is told why, nil when the host told no reason.
  def self.call_off_own(text = nil)
    @called_off = true
    @off_text = text
    log("#{MGQ_MpBattlesSync.player} called the player's joining off before its roster came")
  end

  # Takes what the player is told of why the host called their joining off, see call_off_own.
  #
  # @return [String, nil] The text, nil when the host told no reason.
  def self.take_off_text
    text = @off_text
    @off_text = nil
    text
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
  # @param reason [String] Why, for the log.
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
  # fights alone: takes it in, with as many of the players it brings as the battle still takes, when
  # the rules allow it (topic coop.intake), else refuses it. A player another request brought along
  # comes with their own encounter instead (see release_companion).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asks.
  # @param message [Hash] The request: the battle's id, the encounter's troop and enemies, and the
  #   seats of the players who come along.
  def self.take_request(peer, message)
    return log_once([:classic_request, peer && peer.seat], "ignored a request to join from #{who(peer)}: not a Raid World") unless raid?

    release_companion(peer.seat)
    answer = MGQ_Multiplayer::Bridge.call(INTAKE_TOPIC, "kind" => "encounter", "facts" => intake_facts, "seat" => peer.seat, "bid" => message["bid"],
                                                        "troop" => message["troop"], "boss_troop" => MGQ_MpRaidBosses.boss?(message["troop"]),
                                                        "seats" => message["seats"])
    return refuse(peer, message, "the rules did not answer") unless answer
    return refuse(peer, message, answer["refusal"][1]) if answer["refusal"]

    left = Array(answer["left"])
    log("left #{left.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')} out of the request: the battle takes #{answer['room']} more players") unless left.empty?
    take_in_later(peer, Array(answer["kept"]), fitting_enemies(parse_entries(message["enemies"]).reject { |entry| entry[3] == 1 }, message))
  rescue => e
    log("taking a request to join failed: #{e.class}: #{e.message}")
  end

  # Keeps of an encounter's enemies those this game knows and the troop has room for, see
  # place_anew, so a full troop takes its player in all the same, with fewer enemies or none.
  #
  # @param enemies [Array<Array>] The encounter's enemies.
  # @param message [Hash] The request, the battle's id under "bid" and the widths of the encounter's
  #   pictures its player measured under "widths", which the battle keeps.
  # @return [Array<Array>] Those taken in, at their places in the troop.
  def self.fitting_enemies(enemies, message)
    known, missing = enemies.partition { |entry| $data_enemies[entry[0]] }
    log("left out the encounter's enemies #{missing.map(&:first).join(', ')}: they are missing from this game") unless missing.empty?
    place_anew(known, message["bid"].to_s, message["widths"])
  end

  # Takes a player who asks with their own encounter out of another encounter that brought them
  # along and has not been taken in for them yet: both requests left at once, each player seeing the
  # other walk the map, and their own request brings them now, or else refuses them.
  #
  # @param seat [Integer] The asking player's seat.
  def self.release_companion(seat)
    Array(pending("release", "seat" => seat)).each { |dropped, reason| forgot(dropped, reason) }
  end

  # Asks the DLL's list of the players taken in (topic coop.pending).
  #
  # @param op [String] What, such as "seats".
  # @param fields [Hash] What it needs.
  # @return [Object, nil] The answer, nil while the DLL does not answer.
  def self.pending(op, fields = {})
    MGQ_Multiplayer::Bridge.call(PENDING_TOPIC, { "op" => op }.merge(fields))
  end

  # Reports whether players taken in have yet to join.
  #
  # @return [Boolean] Whether they have.
  def self.pending?
    pending("count").to_i > 0
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
    Array(pending("seats"))
  end

  # Turns another player's request down, so their encounter starts on its own.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asked.
  # @param message [Hash] The request.
  # @param reason [String] Why, for the log.
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
    pending("take_in", "requester" => peer.seat, "seats" => seats, "enemies" => placed)
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
    pending("take_in", "requester" => peer.seat, "seats" => [peer.seat], "enemies" => [])
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

  # Lists the enemies of the encounters taken in whose player has not joined yet, each where it was
  # placed, which keep their places free for them.
  #
  # @return [Array<Array>] The enemies.
  def self.queued_enemies
    Array(pending("queued"))
  end

  # Reports whether an enemy of the troop has fallen, also one hidden after its defeat, so its
  # place is free.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @return [Boolean] Whether it has.
  def self.fallen?(enemy)
    enemy.dead? || (enemy.hidden? && enemy.respond_to?(:death_state?) && enemy.death_state?) ? true : false
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
    return stay_alone unless pending?

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
    sync::Recorder.start
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
    return unless pending?
    return call_off("the computer plays on for those who left", OFF_CLOSED) if sync.solo?

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

  # Takes the joins that came from the players taken in, from the live battle's session.
  #
  # @return [Hash{Integer => String}] Each joining player's seat and join, see
  #   MGQ_MpBattlesCoop.own_build.
  def self.take_joins
    MGQ_MpBattlesSync::Channel.poll
    joined = {}
    Array(pending("joins")).each { |seat, body| joined[seat] = body }
    joined
  end

  # Forgets the players taken in who turned their invite down or stopped waiting, left the battle
  # or the world, or did not join within WAIT_SECONDS, as the DLL finds them; those who waited too
  # long are told it is off.
  def self.expire
    MGQ_MpBattlesSync::Channel.poll
    gone = pending_seats.select { |seat| MGQ_MpBattlesSync.peer_at(seat).nil? }
    Array(pending("expire", "gone" => gone)).each do |seat, reason, tell_off|
      forgot(seat, reason)
      MGQ_MpBattlesCoop.tell_map([seat], "off", "bid" => MGQ_MpBattlesSync.battle_id) if tell_off
    end
  end

  # Notes a player taken in whom the DLL forgot, with their join should it have come: the battle
  # expects their messages no more. Without the player who met them, the encounter's enemies never
  # join the troop.
  #
  # @param seat [Integer] Their seat.
  # @param reason [String] Why, for the log.
  def self.forgot(seat, reason)
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
    send_to(guests, "coop_party", MGQ_Multiplayer::Bridge.call(coop::WRITE_PARTY_TOPIC, players.map(&:to_a)).to_s)
    coop.share_troop(guests)
    sync.keep_seats(Array(sync.seats) | joined.keys)
    sync.unexpect(joined.keys)
    roster = { "enemies" => late_entries, "players" => players.map(&:to_a), "level" => nil, "turn" => $game_troop.turn_count.to_i }
    send_to(joined.keys, "roster", MGQ_Multiplayer::Bridge.call(coop::WRITE_ROSTER_TOPIC, roster).to_s)
    send_to(joined.keys, "ready", sync.names)
    @readied = Array(@readied) | joined.keys
    pending("remove", "seats" => joined.keys)
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
    # One encounter after the other, each placed with those before it in the troop.
    while (entries = pending("next_added", "seats" => seats))
      place_anew(Array(entries), MGQ_MpBattlesSync.battle_id.to_s).each do |id, x, y, _hidden|
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
  # the encounters still to join, as the rules in C# place them (topic coop.place): within the
  # enemies a troop holds, the fallen and those queued counted, with at most half of each picture
  # behind another. When the troop has no room for them all any more, such as after enemies added
  # mid-battle, only the first of them that still find a place join it, none when no place is left.
  # A picture's width is the one the player who asked to join measured, which the battle keeps, else
  # the one this game measures: the battle server measures every picture as 32 pixels wide.
  #
  # The places take_request found are never taken instead, since they may lie past the troop's limit
  # now.
  #
  # @param entries [Array<Array>] The encounter's enemies where take_request placed them.
  # @param bid [String] The battle's id.
  # @param widths [String, nil, Symbol] The widths a request tells, see CoopAsking in the DLL; :kept
  #   to place by those the battle kept.
  # @return [Array<Array>] The enemies that join, at their new places.
  def self.place_anew(entries, bid, widths = :kept)
    troop = $game_troop.members.map do |enemy|
      shown = !fallen?(enemy) && !enemy.hidden?
      [enemy.enemy_id, enemy.screen_x, shown ? enemy_width(enemy) : 0, enemy.hidden? ? true : false, fallen?(enemy)]
    end
    request = { "bid" => bid, "troop" => troop, "queued" => queued_enemies.map { |id, x, _y, _mark| [id, x, id_width(id)] },
                "entries" => entries.map { |id, _x, y, _mark| [id, y, id_width(id)] }, "screen" => screen_width }
    request["widths"] = widths unless widths == :kept
    placed = Array(MGQ_Multiplayer::Bridge.call(PLACE_TOPIC, request)).map { |id, x, y| [id, x, y, 0] }
    dropped = entries.drop(placed.size)
    unless dropped.empty?
      log("left out #{dropped.size} of the encounter's #{entries.size} enemies (#{dropped.map(&:first).join(', ')}): " \
          "the troop of #{$game_troop.members.size} has no place left for them")
    end
    placed
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

  # Sends a battle message to some of the battle's players alone, numbered for each as every message
  # of the battle (see MGQ_MpBattlesSync::Sequence).
  #
  # @param seats [Array<Integer>] The seats the battle knows them by.
  # @param kind [String] What it is.
  # @param body [String] The rest.
  def self.send_to(seats, kind, body)
    return if seats.empty?

    MGQ_MpBattlesSync::Channel.post_to(seats, kind, body)
  end

  # Tells every player taken in who has not joined that it is off, and forgets them.
  #
  # @param reason [String] Why, for the log.
  def self.call_off(reason, why = OFF_CLOSED)
    seats = Array(pending("call_off"))
    return if seats.empty?

    MGQ_MpBattlesSync.unexpect(seats)
    MGQ_MpBattlesCoop.tell_map(seats, "off", "bid" => MGQ_MpBattlesSync.battle_id.to_s, MGQ_MpBattlesCoop::OFF_WHY_FIELD => why)
    log("called joining battle #{MGQ_MpBattlesSync.battle_id} off for #{seats.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')}: #{reason}")
  end

  # Takes a player's word that hotjoining is off as the host: a player taken in, whose encounter
  # starts on its own after all. Called by MGQ_MpBattlesCoop.take_off once the asking side in the DLL
  # had its say.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @param message [Hash] Their message, the battle's id under "bid".
  # @return [Boolean] Whether it was about hotjoining, which is settled now.
  def self.take_off(peer, message)
    return false unless message["bid"].to_s == MGQ_MpBattlesSync.battle_id.to_s && pending("take_off", "seat" => peer.seat) == true

    forgot(peer.seat, "their encounter starts on its own")
    stay_alone if !pending? && waiting_alone?
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
    coop = MGQ_MpBattlesCoop
    read = MGQ_Multiplayer::Bridge.call(READ_TROOP_TOPIC, coop.troop_facts.merge("line" => body.to_s))
    entries = coop.repaired(read)
    names = read && read["names"]
    count = $game_troop.members.size
    if entries && entries.size >= count
      match_enemies(entries.first(count))
      grow_troop(scene, entries[count..-1]) if entries.size > count
    elsif entries
      coop.take_repaired(scene, entries)
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
    call_off("the battle is over", OFF_OVER) if pending?
    forget
  rescue => e
    forget
    log("ending hotjoining failed: #{e.class}: #{e.message}")
  end

  # Forgets everything of hotjoining a reset interrupted, telling nobody; the DLL forgets the request
  # and the offers with the matchmaking.
  def self.drop
    count = pending("count").to_i
    log("forgot #{count} encounters taken in after a reset") if count > 0
    pending("call_off")
    @party_offers = {}
    @offers_frame = nil
    forget
  end

  # Forgets the player's own battle, a late join, the host's word of a boss battle, the late guests'
  # word that they are ready and the party members who stayed out of it, and in the DLL a request
  # whose battle ended before its wait (topic coop.ask_forget).
  def self.forget
    bridge = MGQ_Multiplayer::Bridge
    MGQ_MpBattlesCoop.take_status(bridge.call(ASK_FORGET_TOPIC)) if bridge.has?(ASK_FORGET_TOPIC)
    @stays_out = []
    @own_bid = nil
    @boss_battle = false
    @readied = []
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
