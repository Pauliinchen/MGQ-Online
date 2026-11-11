#----------------------------------------------------------------
#  battles_sync.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Sent a co-op guest's gold with the commands of a turn that converts damage into gold, and kept it on the host for that turn
#      Paulinchen  2026-11-08: Gave its UI ids the mgq_online_ prefix
#      Paulinchen  2026-11-06: Showed the waiting box as a hud of the Mod Framework's UI layer above the battle's windows and asked to leave through UI.confirm
#      Paulinchen  2026-11-05: Read a message's number as a number and sent the last number taken in its field
#                            - Had C# write the names and the commands and read the commands
#                            - Asked every player of the battle who came back for what they sent, every game numbering its messages
#                            - Held a player's missing messages for the grace the DLL's Sessions counts, by the bridge's frame
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#                            - Built the waiting box on the Mod Framework's components, its leave offer naming the bound cancel key and taking a click
#      Paulinchen  2026-10-31: Took the question box, the look and the places from the Mod Framework
#                            - Offered to leave the waiting box with the Mod Framework's cancel and named its keys
#      Paulinchen  2026-10-30: Left the frames between two sends of the host's stream to the DLL
#                            - Planned a guest's commands in the DLL
#                            - Kept the live battle's session, its seats, messages and endings in the DLL
#                            - Swapped the host's names in the DLL
#                            - Deleted the live battle over the PvP link
#      Paulinchen  2026-10-23: Deleted the recording on file of the mirror match
#                            - Deleted the unused DROPOUT switch
#                            - Asked the player before they leave the battle from a wait
#                            - Told a guest who never got into the battle why, on the map, instead of the battle breaking off
#                            - Numbered the battle's messages and sent those lost over a reconnect again
#                            - Kept the battle's players by the seats they held at its start, taking one out only once gone
#      Paulinchen  2026-10-20: Sent the skills a guest chains after an action and chained them on the host
#      Paulinchen  2026-10-15: Carried a battle the battle server hosts over its battle channel
#                            - Sent a served battle's messages to single players over its battle channel too
#                            - Told every player of a served battle of one who leaves it
#      Paulinchen  2026-10-12: Told a player joining or leaving the battle in the battle's popup instead of the chat
#                            - Told a player leaving the battle only when they are one of its players
#                            - Kept the computer's actions for unreadable commands and checked a command's ids and target
#                            - Showed the host's names unswapped when they fail to read
#                            - Told whether a wait for the players is open
#                            - Put the host's skip settings back as the battle ends
#      Paulinchen  2026-10-11: Let the player move and resize the waiting box with Alt and dressed it in the interface look
#                            - Let the waiting box name the players still waited for and count the seconds
#                            - Named the wait for a player once
#                            - Named a player of the world by their seat for the waiting box
#                            - Told in the waiting box's leave offer that leaving a story's battle loses it
#                            - Told of a player who joined the running battle
#      Paulinchen  2026-10-08: Closed a command phase the live battle ended in as it finishes
#                            - Took the messages of players expected to join a running co-op battle
#      Paulinchen  2026-10-07: Named players by name and seat and listed characters with their ids
#                            - Logged the live battle's players, messages, commands and departures
#                            - Told the battle's mode on the host when a guest leaves
#      Paulinchen  2026-10-06: Put the host's skip settings back once the live battle ends
#                            - Sent a battle's messages to its players alone instead of the whole world
#                            - Stopped streaming once the computer plays on for the guests who left
#                            - Let a guest's empty commands take its characters' actions away
#                            - Took no more of a guest's commands than the host's game gave the character actions
#                            - Dropped the reader of the battle's kind
#      Paulinchen  2026-10-04: Renamed from mp_battles_sync.rbx
#      Paulinchen  2026-10-03: Named the characters outside the battle to the guest too
#                            - Asked the running battle's mode instead of naming co-op battles and team duels
#                            - Reached the game's private fields and methods through MGQ_MpGame
#                            - Read the sides' players as MGQ_MpBattlesCoop::Player records
#                            - Moved the wire, recorder, playback and live steps into scripts of their own
#                            - Built the battle hooks with MGQ_MpHooks.around
#                            - Called the scripts that load before this one without asking whether they loaded
#                            - Reached the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Took from a guest only skills their character has and items a battle allows
#                            - Waited at a member's battle start for the party's leader to lead it
#                            - Streamed animations once and kept actions and turn ends to the file recording
#      Paulinchen  2026-10-02: Installed the battle hooks through core_hooks.rbx
#                            - Sent every message of a battle over the world's room through tell
#                            - Played back only the picture, screen and audio methods the hooks record
#                            - Ended a guest's co-op battle and a team duel on the host's side through one method
#                            - Started every wait for the guests with nobody ready
#      Paulinchen  2026-10-01: Told every player of a live battle at once when another leaves it or the world
#                            - Carried a co-op guest's swaps with their commands
#                            - Carried duels over the world's room
#                            - Carried team duels
#      Paulinchen  2026-09-30: Registered with overworld_sync.rbx for its messages
#                            - Moved into Patch/Multiplayer/Scripts as battles_sync.rbx
#                            - Renamed from mp_sync.rb, with the module MGQ_MpBattlesSync
#                            - Let a co-op player who got away leave the battle
#                            - Held the battle's menus while waiting
#                            - Carried co-op battles over the world's room
#                            - Left turning Give Up off to battles.rbx
#      Paulinchen  2026-09-29: Sent the start of a command phase before the host's own
#                            - Streamed the battle's lines as calls the guest makes in its own language
#                            - Kept speaker lines out of the name swap and showed name boxes on an untranslated guest
#                            - Offered to leave the battle when a wait drags on
#                            - Broke a live battle off for both players when the host's recording stops
#                            - Stopped a recording when the live battle finishes
#                            - Recorded the hit and defeat effects the game starts without the setter
#                            - Ended the guest's turn, so every command phase chooses anew
#                            - Checked the link without the friend's team
#      Paulinchen  2026-09-28: Created
#
#----------------------------------------------------------------

# Live battles: the host's game computes the battle and streams what it shows, every guest's game
# plays that back and sends its own characters' commands. Co-op battles, duels and team duels run
# over the world's room, co-op battles and team duels with several guests.
#
# Each game sees its own team as the party, so the two would draw their random numbers in a
# different order if both computed.
module MGQ_MpBattlesSync
  # Frames a battle message stays before it moves on by itself, so neither player holds the
  # battle up for the other.
  MESSAGE_FRAMES = 90

  # Frames the guest waits for the host's stream before it says it is waiting.
  QUIET_FRAMES = 20

  # The DLL's topics of the live battle's session (MGQOnline.Game's LiveSession, behind LiveTopics),
  # which keeps its players, its messages and its verdicts; this script carries the messages and
  # acts on the verdicts.
  JOIN_TOPIC = "live.join"

  # See JOIN_TOPIC: changes the session as it starts, finishes, breaks off or loses its other side.
  CHANGE_TOPIC = "live.change"

  # See JOIN_TOPIC: changes the battle's players.
  PLAYERS_TOPIC = "live.players"

  # See JOIN_TOPIC: checks a battle message before its sender is known.
  ADMIT_TOPIC = "live.admit"

  # See JOIN_TOPIC: takes a message that arrived.
  RECEIVE_TOPIC = "live.receive"

  # See JOIN_TOPIC: takes the oldest message of some kinds.
  TAKE_TOPIC = "live.take"

  # See JOIN_TOPIC: counts the waiting messages of a kind.
  PENDING_TOPIC = "live.pending"

  # See JOIN_TOPIC: checks whether the battle ends or its other side is gone.
  TICK_TOPIC = "live.tick"

  # See JOIN_TOPIC: tells how the battle ends.
  END_TOPIC = "live.end"

  # See JOIN_TOPIC: the host's waits for its guests.
  PHASE_TOPIC = "live.phase"

  # See JOIN_TOPIC: tells a departure or a join once.
  DEPARTURE_TOPIC = "live.departure"

  # See JOIN_TOPIC: plans a guest's commands.
  PLAN_TOPIC = "live.plan"

  # The roles the DLL names, as this script's symbols.
  ROLES = { "host" => :host, "guest" => :guest }

  # The kinds the DLL names, as this script's symbols.
  KINDS = { "coop" => :coop, "pvp" => :pvp }

  # The game's endings the DLL names.
  PROCESSES = { "process_victory" => :process_victory, "process_defeat" => :process_defeat, "process_abort" => :process_abort }

  # The host's settings that leave parts of a battle unshown, which the host turns off for a live
  # battle and puts back as BattleManager.battle_end ends.
  #
  # The guest sees only what the host's battle shows, and the victory autosave would write them off.
  SKIP_SETTINGS = [:bt_skip, :bt_skip_cutin, :bt_skip_enemy_cutin, :bt_skip_chain_action_cutin,
                   :skip_battle_start_skill_effect, :skip_skill_effect]

  class << self
    # The side this game plays in a live battle.
    #
    # @return [Symbol, nil] :host or :guest during a live battle, nil otherwise.
    attr_reader :role

    # Who the waits name: the friend who plays the other side, a world battle's host, or "the party".
    #
    # @return [String] The name.
    attr_reader :player

    # The world seats of the other games of a co-op battle: the guests for the host, the host for a
    # guest.
    #
    # @return [Array<Integer>] The seats.
    attr_reader :seats

    # The co-op battle's id, which its messages carry.
    #
    # @return [String, nil] The id.
    attr_reader :battle_id
  end

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "battle sync"

  # Logs the lines the DLL's rules of the live battle hand over, each [key, text]: a line with a key
  # once per key, one without every time.
  #
  # @param lines [Array<Array>, nil] The lines.
  def self.log_lines(lines)
    Array(lines).each { |key, text| key ? log_once(key, text) : log(text) }
  end

  # Asks the DLL's session a topic and keeps the session's view it answers with, which the battle's
  # hooks read every frame.
  #
  # @param topic [String] The topic, such as JOIN_TOPIC.
  # @param request [Object] The request.
  # @return [Object, nil] The reply, nil while the DLL does not answer.
  def self.session(topic, request = nil)
    reply = MGQ_Multiplayer::Bridge.call(topic, request)
    take_view(reply) if reply.is_a?(Hash) && reply.key?("role")
    reply
  end

  # Keeps the session's view: the role, who the waits name, the kind, the seats of the other
  # games, those who left and those expected, the battle's id, and whether the host plays on
  # alone, the battle broke off, the server hosts it and its scene runs.
  #
  # @param view [Hash] The view, as the DLL writes it.
  def self.take_view(view)
    @role = ROLES[view["role"]]
    @player = view["player"].to_s
    @kind = KINDS[view["kind"]]
    @team = view["team"] ? true : false
    @transport = @role ? :world : nil
    @seats = Array(view["seats"])
    @left = Array(view["left"])
    @expected = Array(view["expected"])
    @battle_id = view["bid"]
    @solo = view["solo"] ? true : false
    @broken = view["broken"] ? true : false
    @served = view["served"] ? true : false
    @battle_running = view["running"] ? true : false
    @behind = view["behind"] ? true : false
  end

  # Keeps whether the guest fell behind the host's stream, as the DLL tells with a message taken in
  # or out.
  #
  # @param behind [Boolean, nil] Whether it did, nil to keep what it last told.
  def self.behind=(behind)
    @behind = behind ? true : false unless behind.nil?
  end

  # Tells whether the guest fell behind the host's stream: four or more of its sends wait, so the
  # guest skips waits to catch up, as the DLL last told.
  #
  # @return [Boolean] Whether it did.
  def self.behind?
    @behind ? true : false
  end

  # Makes the next battle a live battle over the world's room: a co-op battle, or a duel, which is
  # a PvP battle between two players of the world.
  #
  # @param role [Symbol] :host or :guest.
  # @param battle_id [String] The battle's id, which its messages carry.
  # @param seats [Array<Integer>] The other games' seats: the invited guests, or the host.
  # @param player [String] Who the waits name: the host's name, or "the party" for the host.
  # @param mode [Symbol] :coop, or :pvp for a duel.
  # @param team [Boolean] Whether the duel is a team duel, see battles_team.rbx.
  def self.join_world(role, battle_id, seats, player, mode = :coop, team = false)
    session(JOIN_TOPIC, "role" => role.to_s, "bid" => battle_id.to_s, "seats" => seats, "player" => player.to_s, "kind" => mode.to_s,
                        "team" => team ? true : false, "served" => false)
    joined(role, battle_id, seats, mode, team)
  end

  # Readies this game's side of a battle the DLL's session joined: no word of a missed battle, the
  # room's seats named and the messages numbered anew.
  #
  # @param role [Symbol] :host or :guest.
  # @param battle_id [String] The battle's id.
  # @param seats [Array<Integer>] The other games' seats.
  # @param mode [Symbol] :coop or :pvp.
  # @param team [Boolean] Whether the duel is a team duel.
  def self.joined(role, battle_id, seats, mode, team)
    @missed = nil
    Seats.pin_room
    Channel.reset
    kind = mode == :pvp ? (team ? 'team duel' : 'duel') : 'co-op battle'
    log("#{kind} #{battle_id} as #{role}, with #{seats.empty? ? 'nobody yet' : seats.map { |seat| who(seat) }.join(', ')}")
  end

  # Makes the live battle a co-op battle the battle server hosts, whose messages go over the battle
  # channel (see battles_served.rbx): the server hosts it, every player plays it back as a guest.
  # A battle already running keeps its turn and whether its scene started.
  #
  # @param role [Symbol] :host on the battle server, else :guest.
  # @param battle_id [String] The battle's id.
  # @param seats [Array<Integer>] The other seats: the players' for the server, the server's for a guest.
  # @param player [String] Who the waits name.
  def self.serve_over_channel(role, battle_id, seats, player)
    session(JOIN_TOPIC, "role" => role.to_s, "bid" => battle_id.to_s, "seats" => seats, "player" => player.to_s, "kind" => "coop",
                        "team" => false, "served" => true)
    joined(role, battle_id, seats, :coop, false)
    log("battle #{battle_id} goes over the battle channel, as #{role}")
  end

  # Reports whether the live battle is one the battle server hosts, see serve_over_channel.
  #
  # @return [Boolean] Whether it is.
  def self.served?
    @served && @role ? true : false
  end

  # Takes a message of a battle the server hosts from the battle channel. Called by
  # battles_served.rbx.
  #
  # @param seat [Integer] The sender's seat on the battle channel: their world seat, or the server's.
  # @param message [Hash] The message: "battle" its kind, "bid" the battle's id, and the body.
  def self.take_served(seat, message)
    kind = message["battle"].to_s
    return unless admitted?(true, message["bid"], kind, nil)
    return MGQ_MpBattlesServed.take_departure(message[:payload]) if kind == MGQ_MpBattlesServed::DEPARTED && seat == MGQ_MpBattlesServed::SERVER_SEAT

    # Every player of the battle hears of one who leaves, through the server.
    MGQ_MpBattlesServed.pass_departure(seat) if kind == "leave" && host?
    Channel.receive(seat, kind, message[:payload].to_s)
  end

  # Names a player of the world by their seat for the log.
  #
  # @param seat [Integer, nil] Their world seat, nil for the other player of a duel.
  # @return [String] Their name and seat, such as "Name (seat 2)", "the player (seat 0)" for the
  #   player, the seat alone for a player the game does not know.
  def self.who(seat)
    return @player.to_s if seat.nil?
    return "the player (seat #{seat})" if seat == own_seat

    name = peer_name(seat)
    name ? "#{name} (seat #{seat})" : "seat #{seat}"
  rescue
    "seat #{seat}"
  end

  # Names a player of the world by their seat for the waiting box: "you" for the player, the name
  # of the peer at the seat, the seat alone for a player the game does not know.
  #
  # @param seat [Integer] Their world seat.
  # @return [String] The name.
  def self.seat_name(seat)
    return Waiting::OWN_NAME if seat == own_seat

    peer_name(seat) || "seat #{seat}"
  end

  # Names the peer at a seat of the world.
  #
  # @param seat [Integer] The world seat.
  # @return [String, nil] The name, nil for a seat the game does not know or cannot read, as on a
  #   guest whose world closed during the battle.
  def self.peer_name(seat)
    peer = peer_at(seat)
    name = peer && peer.state && peer.state["name"]
    name ? name.to_s : nil
  rescue
    nil
  end

  # Tells the player's own seat in the live battle, see Seats.
  #
  # @return [Integer] The seat the battle knows the player by, the world seat outside a battle.
  def self.own_seat
    Seats.own
  end

  # Finds the player the live battle knows by a seat, see Seats.
  #
  # @param seat [Integer] The seat the battle knows them by.
  # @return [MGQ_MpOverworldSync::Peers::Peer, nil] The player, also while away; nil once gone.
  def self.peer_at(seat)
    Seats.peer(seat)
  end

  # Tells the seat the live battle knows a player by, see Seats.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @return [Integer, nil] The seat, nil when it names another player of the battle.
  def self.seat_of(peer)
    Seats.of(peer)
  end

  # Tells the world seat a message to a player of the live battle goes to, see Seats.
  #
  # @param seat [Integer] The seat the battle knows them by.
  # @return [Integer, nil] Their world seat, nil while they are away or once gone.
  def self.world_seat_of(seat)
    Seats.world(seat)
  end

  # Names a battler with its id for the log.
  #
  # @param battler [Game_Battler, nil] The battler.
  # @return [String] Its name and actor or monster id, such as "Alice (2)".
  def self.named(battler)
    return "nobody" unless battler

    id = battler.respond_to?(:id) ? battler.id : (battler.respond_to?(:enemy_id) ? battler.enemy_id : nil)
    id ? "#{battler.name} (#{id})" : battler.name.to_s
  rescue
    "?"
  end

  # Names battlers with their ids for the log, see named.
  #
  # @param battlers [Array<Game_Battler>] The battlers.
  # @return [String] Their names and ids, "nobody" for none.
  def self.named_list(battlers)
    battlers.empty? ? "nobody" : battlers.map { |battler| named(battler) }.join(", ")
  rescue
    "?"
  end

  # Reads the battle's turn count for the log.
  #
  # @return [Integer] The turns that started, 0 before the first.
  def self.turn
    $game_troop.turn_count.to_i
  rescue
    0
  end

  # Reports whether the live battle is a co-op battle.
  #
  # @return [Boolean] Whether it is.
  def self.coop?
    @role && @kind == :coop ? true : false
  end

  # Reports whether the live battle is a team duel, two parties fighting each other.
  #
  # @return [Boolean] Whether it is.
  def self.team?
    @role && @kind == :pvp && @team ? true : false
  end

  # Reports whether this game's party is the host's party: in a co-op battle, and on the host's
  # side of a team duel. Otherwise the host's party is this game's troop.
  #
  # @return [Boolean] Whether it is.
  def self.same_side?
    mode.same_side?
  end

  # What the running battle's kind does differently: a co-op battle's or a team duel's
  # MGQ_MpBattles::Mode, else a duel's.
  #
  # @return [MGQ_MpBattles::Mode] The mode.
  def self.mode
    MGQ_MpBattles.mode_of(coop? ? :coop : team? ? :team : :duel)
  end

  # Reports whether the host takes commands from several guests: in a co-op battle and a team duel.
  #
  # @return [Boolean] Whether it does.
  def self.several?
    coop? || team?
  end

  # Reports whether the live battle runs over the world's room.
  #
  # @return [Boolean] Whether it does.
  def self.world?
    @transport == :world
  end

  # Lets in the messages of players who are to join the running co-op battle late, before they are
  # among its guests (see battles_coop_hotjoin.rbx).
  #
  # @param seats [Array<Integer>] Their world seats, which the battle knows them by from then on.
  def self.expect(seats)
    seats.each { |seat| peer_at(seat) }
    session(PLAYERS_TOPIC, "op" => "expect", "seats" => seats)
  end

  # Stops letting in the messages of players expected to join, once they joined or gave up.
  #
  # @param seats [Array<Integer>] Their world seats.
  def self.unexpect(seats)
    session(PLAYERS_TOPIC, "op" => "unexpect", "seats" => seats)
  end

  # Lists the players expected to join the running co-op battle late, see expect.
  #
  # @return [Array<Integer>] Their world seats.
  def self.expected
    Array(@expected)
  end

  # Narrows a co-op battle's guests to those who joined.
  #
  # @param seats [Array<Integer>] Their world seats.
  def self.keep_seats(seats)
    dropped = Array((session(PLAYERS_TOPIC, "op" => "keep", "seats" => seats) || {})["dropped"])
    log("guests who joined battle #{@battle_id}: #{seats.empty? ? 'nobody' : seats.map { |seat| who(seat) }.join(', ')}" +
        (dropped.empty? ? "" : "; not joined: #{dropped.map { |seat| who(seat) }.join(', ')}"))
  end

  # Lists the guests of a co-op battle who are still in it.
  #
  # @return [Array<Integer>] Their seats.
  def self.guests_in
    @seats - (@left || [])
  end

  # Notes that a guest left a co-op battle, and on the host tells the battle's mode, see
  # MGQ_MpBattles::Mode#left. In a co-op battle their characters do nothing more; the next command
  # phase takes them out of the party (see MGQ_MpBattlesCoop.settle).
  #
  # @param seat [Integer] The guest's seat.
  def self.guest_left(seat)
    reply = session(PLAYERS_TOPIC, "op" => "left", "seat" => seat)
    departed(seat, reply["still_in"]) if reply && reply["left_now"]
  end

  # Tells the battle's mode on the host that a guest left, and logs it.
  #
  # @param seat [Integer] The guest's seat.
  # @param still_in [Integer] The guests still in after them.
  def self.departed(seat, still_in)
    mode.left(seat) if host?
    log("#{who(seat)} left battle #{@battle_id} in turn #{turn}, their characters leave at the next command phase; " \
        "#{still_in} of #{Array(@seats).size} other players still in")
  end

  # Takes a message of a co-op battle or a duel from the world's room. Called by overworld_sync.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message: "battle" its kind, "bid" the battle's id, and the body.
  def self.take(peer, message)
    kind = message["battle"].to_s
    return unless peer

    return unless admitted?(false, message["bid"], kind, who(peer.seat))

    seat = seat_of(peer)
    return dropped(kind, peer, "its seat names another player of the battle") unless seat

    # Every player of the battle hears of one who leaves, not only the host who takes them out.
    Departures.left(peer) if kind == "leave"
    number = message[Sequence::NUMBER_FIELD]
    return Sequence.resend(seat, number.to_i) if kind == Sequence::RESYNC_KIND
    return Channel.receive(seat, kind, message[:payload].to_s) unless number.is_a?(Integer) && number.between?(0, Sequence::MAX_NUMBER)

    Sequence.take(seat, number, kind, message[:payload].to_s)
  end

  # Asks the DLL whether a battle message is one of the running live battle's, and logs why not.
  #
  # @param channel [Boolean] Whether it came over the battle channel of a battle the server hosts.
  # @param bid [Object] The battle id it carries.
  # @param kind [String] The message's kind.
  # @param who [String, nil] Who sent it, nil over the battle channel.
  # @return [Boolean] Whether to take it; one the DLL does not check is left out.
  def self.admitted?(channel, bid, kind, who)
    refusal = MGQ_Multiplayer::Bridge.call(ADMIT_TOPIC, "channel" => channel, "bid" => bid, "kind" => kind, "who" => who)
    return true if refusal == false

    refusal ? log_lines([refusal]) : log_once([:unchecked, kind[0, 40]], "ignored a battle message #{kind[0, 40]}: the DLL did not check it")
    false
  end

  # Logs a battle message from the world's room that is left untaken, once per kind, reason and
  # battle.
  #
  # @param kind [String] The message's kind.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param reason [String] Why it is left untaken.
  def self.dropped(kind, peer, reason)
    log_once([:dropped, kind[0, 40], reason, @battle_id], "ignored a battle message #{kind[0, 40]} from #{who(peer.seat)}: #{reason}")
  end

  # Lists the other players of a live battle over the world's room: the host or the guests, and in
  # a co-op battle or a team duel everyone else in it.
  #
  # @return [Array<Integer>] Their world seats.
  def self.player_seats
    seats = Array(@seats)
    seats |= mode.player_seats
    seats - [own_seat]
  end

  # Marks the live battle as started. Called by the mode once its battle scene is on the way.
  def self.battle_started
    session(CHANGE_TOPIC, "op" => "start") if @role
  end

  # Ends the live battle, stops a recording and puts the host's settings back when the battle's end
  # has not, such as after a reset or an early end. Called by the mode when it puts the game back,
  # and after a reset. The world's room stays open.
  def self.finish
    Recorder.stop
    Live.end_phase
    restore_settings
    return unless @role

    log("live battle #{@battle_id} finished as #{@role} after #{turn} turns" +
        "#{@broken ? ', broken off' : ''}#{@solo ? ', the computer playing for those who left' : ''}")
    served = @served
    finished = session(CHANGE_TOPIC, "op" => "finish")
    # Without the DLL the battle still ends here.
    @role = @transport = nil unless finished
    Seats.forget
    MGQ_MpBattlesServed.close if served && defined?(MGQ_MpBattlesServed)
  rescue => e
    log("finish failed: #{e.class}: #{e.message}")
  end

  # Breaks the live battle off without a winner, once something went wrong on either side.
  #
  # @param reason [String] What went wrong, for the log.
  # @param tell_friend [Boolean] Whether the friend's game still has to hear of it.
  def self.break_off(reason, tell_friend = true)
    return if @broken || !@role

    broke = session(CHANGE_TOPIC, "op" => "break")
    return unless broke && broke["done"]

    log("the live battle broke off: #{reason}")
    Channel.post("broken") if tell_friend
  rescue => e
    log("break-off failed: #{e.class}: #{e.message}")
  end

  # Ends the live battle of a guest who never got into it, such as one that ended before its roster
  # came: it breaks off, and the player is told why on the map instead of the battle breaking off.
  #
  # @param text [String] What the player is told, such as "Name's battle ended before you could join."
  def self.miss(text)
    @missed = text
    break_off("the player never got into it: #{text}", false)
  end

  # Takes what the player is told of a live battle they never got into, see miss.
  #
  # @return [String, nil] The text, nil when the battle broke off otherwise.
  def self.take_missed
    text = @missed
    @missed = nil
    text
  end

  # Tells whether the live battle broke off.
  #
  # @return [Boolean] Whether either game broke the live battle off.
  def self.broken?
    @broken ? true : false
  end

  # Tells whether a live battle runs.
  #
  # @return [Boolean] Whether a live battle runs.
  def self.live?
    @role && @battle_running ? true : false
  end

  # Tells whether this game is the host.
  #
  # @return [Boolean] Whether this game computes the live battle.
  def self.host?
    live? && @role == :host
  end

  # Tells whether this game is the guest.
  #
  # @return [Boolean] Whether this game plays the live battle back.
  def self.guest?
    live? && @role == :guest
  end

  # Tells whether the computer took over the friend's team.
  #
  # @return [Boolean] Whether the friend left and the computer plays their team instead.
  def self.solo?
    @solo ? true : false
  end

  # Turns off the host's settings that would keep parts of the battle from the guest, keeping their
  # values for restore_settings.
  def self.show_everything
    @kept_settings ||= {}
    SKIP_SETTINGS.each do |key|
      next unless $game_system.conf.key?(key)

      @kept_settings[key] = $game_system.conf[key] unless @kept_settings.key?(key)
      $game_system.conf[key] = false
    end
    log("turned the skip settings off for the live battle, kept to put back: #{settings_text(@kept_settings)}")
  end

  # Puts back the settings show_everything turned off, once: called as the battle ends and again
  # by finish, which then finds nothing kept.
  def self.restore_settings
    kept = @kept_settings
    @kept_settings = nil
    return unless kept && $game_system

    kept.each { |key, value| $game_system.conf[key] = value }
    log("put the skip settings back: #{settings_text(kept)}")
  rescue => e
    log("putting the skip settings back failed: #{e.class}: #{e.message}")
  end

  # Writes settings for the log.
  #
  # @param settings [Hash] The settings by their key.
  # @return [String] Each key with its value, "none" without any.
  def self.settings_text(settings)
    settings.empty? ? "none" : settings.map { |key, value| "#{key}=#{value.inspect}" }.join(", ")
  end

  # Lists the names the guest swaps.
  #
  # @return [String] The names of this game's party and troop, each with its characters outside the
  #   battle, which the guest swaps for its own.
  def self.names
    Wire.write([party_side.map(&:name), troop_side.map(&:name)])
  end

  # Lists the party's characters the stream names: those in the battle, then those outside it.
  #
  # @return [Array<Game_Battler>] The characters.
  def self.party_side
    $game_party.battle_members + mode.own_reserve
  end

  # Lists the troop's characters the stream names: those in the battle, then those outside it.
  #
  # @return [Array<Game_Battler>] The characters.
  def self.troop_side
    $game_troop.members + mode.other_reserve
  end

  # Sends a message of a battle over the world's room, or over the battle channel for the battle
  # the server hosts: from its players to the server, from the server to the players.
  #
  # @param seat [Integer] The game's seat, -1 for everyone.
  # @param kind [String] What it is.
  # @param battle_id [String] The battle's id.
  # @param body [String] The rest.
  # @param number [Integer, nil] The message's number to that game, see Sequence; nil for none.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, battle_id, body = "", number = nil)
    if served? && battle_id.to_s == @battle_id.to_s
      return !MGQ_MpBattlesServed.post([host? ? seat : MGQ_MpBattlesServed::SERVER_SEAT], kind, body).empty?
    end

    fields = { "battle" => kind, "bid" => battle_id }
    fields[Sequence::NUMBER_FIELD] = number if number
    MGQ_MpOverworldSync.tell(seat, fields, body)
  end

  # Ends the battle once the other side is gone, as the DLL decides: in a co-op battle played on by
  # the computer on the host, taken over by a guest's mode where it can, else won, or without a
  # winner on the host's side of a team duel whose host left.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Boolean] true when the battle goes on with the computer.
  def self.friend_gone(scene)
    log("the link to #{@player} ended")
    verdict = MGQ_Multiplayer::Bridge.call(END_TOPIC, "of" => "gone", "side" => same_side? ? true : false)
    return false unless verdict.is_a?(Hash)

    # A co-op battle plays on on the host once every guest is gone, the host's own full team again
    # from the next command phase (see MGQ_MpBattlesCoop.settle); a guest whose host is gone fights on
    # alone.
    if verdict["process"] == "solo"
      @solo = true
      Recorder.stop
      log("the host plays on alone, the computer playing for the guests who left, streaming stopped")
      return true
    end

    if mode.take_over(scene)
      log("this game takes the battle over and fights on alone")
      return false
    end

    end_with(verdict["otherwise"])
    false
  end

  # Ends the battle as the DLL decided: logs why, adds its message and calls the game's ending.
  #
  # @param verdict [Hash, nil] "process" (such as "process_victory"), "log" and "message".
  def self.end_with(verdict)
    return unless verdict.is_a?(Hash)

    log(verdict["log"]) if verdict["log"]
    $game_message.add(verdict["message"]) if verdict["message"]
    process = PROCESSES[verdict["process"]]
    BattleManager.send(process) if process
  end

  # The messages between the games during a live battle: a kind, the rest and the sender's world
  # seat, over the world's room or the battle channel, marked with the battle's id. The DLL's
  # session keeps those that arrived until they are taken.
  module Channel
    # The endings the DLL names.
    ENDINGS = { "forfeit" => :forfeit, "broken" => :broken, "gone" => :gone }

    # Forgets the numbers of an earlier battle's messages, as a battle joins; the DLL forgets its
    # messages.
    def self.reset
      Sequence.reset
    end

    # Sends a message over the world's room to each of the battle's other players, see
    # MGQ_MpBattlesSync.player_seats, or over the battle channel.
    #
    # @param kind [String] What it is.
    # @param body [String] The rest.
    # @return [Boolean] Whether it went out to anyone, false without a live battle.
    def self.post(kind, body = "")
      unless MGQ_MpBattlesSync.world?
        noted_post(kind, body, nil)
        return false
      end

      if MGQ_MpBattlesSync.served?
        reached = MGQ_MpBattlesServed.post(MGQ_MpBattlesSync.player_seats, kind, body)
        noted_post(kind, body, reached.empty? ? nil : "over the battle channel to #{reached.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')}")
        return !reached.empty?
      end

      post_to(MGQ_MpBattlesSync.player_seats, kind, body)
    end

    # Sends a message over the world's room to some players of the battle, numbered for each (see
    # Sequence), so a player away gets it once they are back.
    #
    # @param seats [Array<Integer>] The seats the battle knows them by.
    # @param kind [String] What it is.
    # @param body [String] The rest.
    # @return [Boolean] Whether it went out to anyone now.
    def self.post_to(seats, kind, body = "")
      reached = seats.select { |seat| Sequence.deliver(seat, kind, body) }
      noted_post(kind, body, reached.empty? ? nil : "to #{reached.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')}")
      !reached.empty?
    end

    # Logs a message sent, except the host's stream, which the recorder sums up per turn.
    #
    # @param kind [String] What it is.
    # @param body [String] The rest.
    # @param whereto [String, nil] Whom it reached, nil when it reached nobody.
    def self.noted_post(kind, body, whereto)
      if kind == "events"
        return if whereto

        return MGQ_MpBattlesSync.log_once([:unsent, MGQ_MpBattlesSync.battle_id], "could not send the stream: it reached nobody")
      end

      MGQ_MpBattlesSync.log(whereto ? "sent #{kind} (#{body.to_s.size} bytes) #{whereto}" : "could not send #{kind}: it reached nobody")
    end

    # Hands a message that arrived over the world's room or the battle channel to the DLL's
    # session, which takes a guest only the host's, the host only its guests' and those of the
    # players it expects to join (see expect), and logs it.
    #
    # @param seat [Integer] The sender's world seat.
    # @param kind [String] What it is.
    # @param body [String] The rest.
    def self.receive(seat, kind, body)
      reply = MGQ_Multiplayer::Bridge.call(RECEIVE_TOPIC, "seat" => seat, "kind" => kind.to_s, "body" => body.to_s, "who" => MGQ_MpBattlesSync.who(seat))
      return unless reply

      MGQ_MpBattlesSync.log_lines(reply["logs"])
      MGQ_MpBattlesSync.behind = reply["behind"]
    end

    # Takes the oldest message of a kind that arrived.
    #
    # @param kind [String] The kind.
    # @return [String, nil] Its body, nil while none arrived.
    def self.take(kind)
      message = taken([kind])
      message && message[1]
    end

    # Takes the oldest message of any of some kinds, which keeps their order among each other.
    #
    # @param kinds [Array<String>] The kinds.
    # @return [Array<String>, nil] Its kind and body, nil while none arrived.
    def self.take_first(kinds)
      taken(kinds)
    end

    # Takes the oldest message of a kind one game sent.
    #
    # @param kind [String] The kind.
    # @param seat [Integer] The sender's world seat.
    # @return [String, nil] Its body, nil while none arrived.
    def self.take_from(kind, seat)
      message = taken([kind], seat)
      message && message[1]
    end

    # Takes the oldest message of some kinds from the DLL's session, once the messages that came
    # meanwhile are in.
    #
    # @param kinds [Array<String>] The kinds.
    # @param seat [Integer, nil] The sender's world seat, nil for any.
    # @return [Array<String>, nil] Its kind and body, nil while none arrived.
    def self.taken(kinds, seat = nil)
      poll
      reply = MGQ_Multiplayer::Bridge.call(TAKE_TOPIC, "kinds" => kinds, "seat" => seat)
      return nil unless reply

      MGQ_MpBattlesSync.behind = reply["behind"]
      reply["message"]
    end

    # Reports whether the other side of the battle is gone, looking every 60 checks: the host
    # notes each guest who left and counts the other side as gone once none is left; a guest
    # counts it as gone once the host is.
    #
    # @return [Boolean] Whether the other side is gone, true without a live battle.
    def self.gone?
      checked("gone") == :gone
    end

    # Looks at who of a co-op battle or a duel is still in it: the players who said they leave and
    # those the world told are gone (see Seats.presence). A player away is still in it.
    #
    # @return [Boolean] Whether the other side is gone: every guest for the host, the host for a guest.
    def self.world_gone?
      checked("world") == :gone
    end

    # Looks at who of a battle the server hosts is still in it: the server notes each player who
    # said they leave or whom the presence of its players tells gone (see MGQ_MpBattlesServed.take),
    # a guest counts the battle as gone once the channel closed.
    #
    # @return [Boolean] Whether the other side is gone.
    def self.served_gone?
      checked("served") == :gone
    end

    # Takes the players who left the battle out of it: those who said they leave, and those the
    # presence of the players tells gone.
    def self.take_departures
      checked("departures")
    end

    # Reports why the other games will send nothing more for the battle, taking a forfeit or
    # break-off that arrived.
    #
    # @return [Symbol, nil] :forfeit when the other side forfeited, :broken when either game broke
    #   the battle off, :gone when the other side is gone, nil while the battle goes on.
    def self.ending
      checked("ending")
    end

    # Runs one of the DLL's checks of whether the battle ends, with what this game knows of the
    # world, tells the battle's mode of the guests it took out and lets the mode decide, as the
    # host, whether every opponent left.
    #
    # @param check [String] "ending", "gone", "world", "served" or "departures".
    # @return [Symbol, nil] :forfeit, :broken or :gone, nil while the battle goes on.
    def self.checked(check)
      poll
      sync = MGQ_MpBattlesSync
      reply = sync.session(TICK_TOPIC, "check" => check, "in_world" => MGQ_MpOverworldSync.in_world? ? true : false,
                                       "served_closed" => sync.served? && MGQ_MpBattlesServed.closed? ? true : false, "gone" => Seats.take_gone)
      return nil unless reply

      Array(reply["departed"]).each { |seat, still_in| sync.departed(seat, still_in) }
      sync.log_lines(reply["logs"])
      return ENDINGS[reply["ending"]] unless reply["ask"] && sync.host? && sync.mode.other_side_gone?
      return :gone if check == "world"

      gone = sync.session(CHANGE_TOPIC, "op" => "gone")
      sync.log_lines(gone && gone["logs"])
      :gone
    end

    # Counts the waiting messages of a kind.
    #
    # @param kind [String] A kind of message.
    # @return [Integer] How many of that kind arrived and wait.
    def self.pending(kind)
      poll
      MGQ_Multiplayer::Bridge.call(PENDING_TOPIC, kind).to_i
    end

    # Moves the messages of a battle the server hosts into the DLL's session and hands on the held
    # ones whose gap never closed. The world's arrive through receive.
    def self.poll
      MGQ_MpBattlesServed.drain if MGQ_MpBattlesSync.served?
      Sequence.let_gaps_go if MGQ_MpBattlesSync.world?
    end
  end

  # The guest's commands: its characters' actions, which the host gives the rebuilt characters of
  # that guest. In a PvP battle the troop of one game is the party of the other in the same order;
  # in a co-op battle every game has the same party in the same order. Either way a target's index
  # means the same battler on both sides.
  module Commands
    # Most skills chained after one action, far more than any skill type's chain of the game allows.
    MAX_CHAIN = 16

    # Writes the guest's commands: for every party member, its actions, an empty list when it has
    # none, such as after a failed escape, and nil for the other players' characters in a co-op
    # battle; then the order of the guest's places, which a swap with their Backline changed; then,
    # in a co-op battle whose turn uses it (see MGQ_MpActors.gold_used?), the party's gold.
    #
    # @return [String] The commands.
    def self.build
      commands = $game_party.battle_members.map do |actor|
        # Others' characters send nothing, but those this player took over from a player who left.
        next nil if actor.is_a?(Game_MpActor) && !actor.inputable?

        actor.actions.select(&:item).map { |action| chained_command(action) }
      end
      order = MGQ_MpBattlesSync.mode.own_order
      gold = MGQ_MpBattlesSync.coop? && MGQ_MpActors.gold_used? ? $game_party.gold : nil
      @built = "#{summary($game_party.battle_members, commands)}#{order ? "; order #{order.join(', ')}" : ''}#{gold ? "; gold #{gold}" : ''}"
      Wire.write(gold ? [commands, order, gold] : order ? [commands, order] : [commands])
    end

    # Writes an action as a command, followed by the skills chained after it when it has any.
    #
    # @param action [Game_Action] The action.
    # @return [Array] "skill" or "item", the id and the target's index, then the chain's commands.
    def self.chained_command(action)
      chain = []
      link = action.respond_to?(:chain_action) ? action.chain_action : nil
      while link && link.item && chain.size < MAX_CHAIN
        chain << plain_command(link)
        link = link.chain_action
      end
      chain.empty? ? plain_command(action) : plain_command(action) + [chain]
    end

    # Writes an action as a command, without its chain.
    #
    # @param action [Game_Action] The action.
    # @return [Array] "skill" or "item", the id and the target's index.
    def self.plain_command(action)
      [action.item.is_a?(RPG::Item) ? "item" : "skill", action.item.id, action.target_index]
    end

    # Sums up the commands build wrote last, for the log.
    #
    # @return [String] Each own character with its commands, and the order of places.
    def self.built
      @built.to_s
    end

    # Sums up commands for the log.
    #
    # @param battlers [Array<Game_Battler>] The characters, by place.
    # @param commands [Array<Array, nil>] The commands of each, nil for one commanded elsewhere.
    # @return [String] Each commanded character with its commands, "none" for an empty list.
    def self.summary(battlers, commands)
      lines = []
      battlers.each_with_index do |battler, index|
        list = commands[index]
        next unless list.is_a?(Array)

        lines << "#{MGQ_MpBattlesSync.named(battler)}: #{list.empty? ? 'none' : list.map { |command| command_text(command) }.join(', ')}"
      end
      lines.empty? ? "no characters" : lines.join("; ")
    end

    # Writes a command for the log.
    #
    # @param command [Array] "skill" or "item", the id and the target's index, then its chain's commands.
    # @return [String] Its kind, id and name, and the target's index, then each chained command after ">".
    def self.command_text(command)
      kind, id, target, chain = command
      item = { "skill" => $data_skills, "item" => $data_items }.fetch(kind, [])[id.to_i] if id.is_a?(Integer)
      name = item.respond_to?(:name) ? " #{item.name}" : ""
      text = "#{kind} #{id}#{name} at #{target.inspect}"
      chain.is_a?(Array) ? ([text] + chain.map { |link| command_text(link) }).join(" > ") : text
    rescue
      command.inspect
    end

    # Gives a guest's characters on the host the guest's commands, see command, as the DLL plans
    # them (MGQOnline.Game's CommandPlan): which places the guest commands, their own or in a team
    # duel those of a player who left, which they took over, and which commands name a skill or item
    # and a target the host's turn reads. A character the guest named none for keeps what the
    # computer chose. In a co-op battle the guest's swaps come first, so the commands find the
    # characters the guest sees, and the gold the guest sent is kept for the turn (see
    # MGQ_MpActors.hold_gold).
    #
    # @param body [String] The commands.
    # @param seat [Integer, nil] The guest's world seat in a co-op battle, whose characters take them.
    def self.apply(body, seat = nil)
      values = Wire.read(body)
      commands = values && values[0]
      return MGQ_MpBattlesSync.log("unreadable commands from #{MGQ_MpBattlesSync.who(seat)} (#{body.to_s.size} bytes), the computer's kept") unless commands.is_a?(Array)

      MGQ_MpBattlesSync.mode.take_order(seat, values[1])

      # The guest's party is the host's party in a co-op battle and on the host's side of a team
      # duel, else the host's troop, in the same order.
      same = MGQ_MpBattlesSync.mode.same_side_as_host?(seat)
      battlers = same ? $game_party.battle_members : $game_troop.members
      plan = MGQ_Multiplayer::Bridge.call(PLAN_TOPIC, "body" => body.to_s, "seat" => seat, "several" => MGQ_MpBattlesSync.several?,
                                                      "owners" => battlers.map { |battler| battler.respond_to?(:mp_seat) && battler.mp_seat.is_a?(Integer) ? battler.mp_seat : nil },
                                                      "skills" => $data_skills.size, "items" => $data_items.size)
      places = plan.is_a?(Hash) ? Array(plan["places"]) : []
      gold = MGQ_MpBattlesSync.coop? && plan.is_a?(Hash) ? plan["gold"] : nil
      MGQ_MpActors.hold_gold(seat, gold) if gold
      given = []
      battlers.each_with_index do |battler, index|
        entries = places[index]
        given << "#{MGQ_MpBattlesSync.named(battler)}: #{command(battler, commands[index], entries)}" if entries
      end
      MGQ_MpBattlesSync.log("gave the commands of #{MGQ_MpBattlesSync.who(seat)} for turn #{MGQ_MpBattlesSync.turn + 1}: " \
                            "#{given.empty? ? 'none for their characters' : given.join('; ')}" +
                            (values[1] ? "; order #{Array(values[1]).join(', ')}" : "") + (gold ? "; gold #{gold}" : ""))
    rescue => e
      MGQ_MpBattlesSync.log_once([:commands, e.class.name], "could not give the commands of #{MGQ_MpBattlesSync.who(seat)}: #{e.class}: #{e.message}; the computer's kept")
    end

    # Gives a character its owner's commands: an empty list takes its actions away, as its owner's
    # game did; of a list, as many as the host's game gave it actions, the computer's staying when
    # the character may give none of them.
    #
    # The host rolls a character's extra actions, so the owner's game never decides how often it acts.
    #
    # @param battler [Game_Battler] The character.
    # @param list [Array<Array>] Its commands as the guest sent them, for the log.
    # @param entries [Array<Array, nil>] Its commands as the DLL read them, see action; nil for one
    #   the host cannot read.
    def self.command(battler, list, entries)
      if entries.empty?
        MGQ_MpGame.set(battler, :actions, [])
        return "none, its actions taken away"
      end

      count = action_count(battler)
      actions = entries.first(count).map { |entry| entry && chained_action(battler, entry) }.compact
      MGQ_MpGame.set(battler, :actions, actions) unless actions.empty?
      taken = list.first(count)
      given = actions.empty? ? "none it may give, the computer's actions kept" : taken.map { |command| command_text(command) }.join(", ")
      given += " (#{taken.size - actions.size} left out)" unless actions.empty? || actions.size == taken.size
      list.size > count ? "#{given} (took #{count} of #{list.size}: the host's game gives it #{count} actions)" : given
    end

    # Counts the actions the host's game gives a character this turn, making them first for one that
    # has none yet, such as one a swap just brought into the battle.
    #
    # @param battler [Game_Battler] The character.
    # @return [Integer] How many actions it takes.
    def self.action_count(battler)
      battler.make_actions if Array(MGQ_MpGame.get(battler, :actions)).empty?
      Array(MGQ_MpGame.get(battler, :actions)).size
    end

    # Turns a command the DLL read into an action with the skills chained after it. The chain ends
    # at its first skill the character may not give, and the game's own check cuts what the
    # character's skill types do not chain.
    #
    # @param battler [Game_Battler] The character.
    # @param entry [Array] "skill" or "item", the id, the target's index and its chain's commands.
    # @return [Game_Action, nil] The action, nil for one the character may not give.
    def self.chained_action(battler, entry)
      first = action(battler, entry)
      return first unless first && entry[3].is_a?(Array) && first.respond_to?(:chain_action=)

      last = first
      entry[3].each do |link|
        child = action(battler, link, :chain_action)
        break unless child

        last.chain_action = child
        last = child
      end
      first.check_chain_action if first.respond_to?(:check_chain_action)
      first
    end

    # Turns a command the DLL read into an action, without its chain.
    #
    # @param battler [Game_Battler] The character.
    # @param entry [Array] "skill" or "item", the id within its table and the target's index.
    # @param symbol [Symbol] The action's kind: :count for one of the character's actions,
    #   :chain_action for a skill chained after one.
    # @return [Game_Action, nil] The action, nil for one the character may not give.
    def self.action(battler, entry, symbol = :count)
      kind, id, target = entry
      item = (kind == "item" ? $data_items : $data_skills)[id]
      return nil unless item
      return refuse(battler, item) unless allowed?(battler, item)

      action = Game_Action.new(battler)
      action.set_symbol(symbol) if action.respond_to?(:set_symbol)
      item.is_a?(RPG::Item) ? action.set_item(id) : action.set_skill(id)
      action.target_index = target
      action
    end


    # Reports whether a character may be commanded to use a skill or an item: a skill it has, or
    # one of no skill type, as attacking, guarding and struggling are, and an item a battle allows.
    #
    # The owner's bag is not known here, so their own game uses an item up as the host's stream's
    # "bag" event tells it, see Playback.bag.
    #
    # @param battler [Game_Battler] The character.
    # @param item [RPG::UsableItem] The skill or item.
    # @return [Boolean] Whether it may.
    def self.allowed?(battler, item)
      return item.battle_ok? if item.is_a?(RPG::Item)

      item.stype_id == 0 || [battler.attack_skill_id, battler.guard_skill_id].include?(item.id) ||
        (battler.respond_to?(:skills) && battler.skills.include?(item))
    end

    # Leaves out a command the character may not give, and logs it.
    #
    # @param battler [Game_Battler] The character.
    # @param item [RPG::UsableItem] The skill or item.
    # @return [nil] Always.
    def self.refuse(battler, item)
      name = item.name rescue nil
      MGQ_MpBattlesSync.log("left out #{item.class.name.split('::').last.downcase} #{item.id} #{name} for #{MGQ_MpBattlesSync.named(battler)}, who may not use it")
      nil
    end
  end

  # The host's names the DLL turns into the guest's in what the host's battle wrote (see
  # Playback.set_up): the host's own characters are the guest's enemies, named with their owner,
  # and the guest's characters are its own, named without.
  module Names
    # Hands the DLL the names of the host's side, with this game's battlers of the same places.
    #
    # @param body [String] The host's party and troop names, see MGQ_MpBattlesSync.names.
    def self.setup(body)
      # A co-op battle's party and troop stand on the same side on every game, with each
      # player's own characters named without their owner.
      sides = [MGQ_MpBattlesSync.party_side, MGQ_MpBattlesSync.troop_side]
      own = MGQ_MpBattlesSync.same_side? ? sides : sides.reverse
      Playback.set_up(body.to_s, own.map { |battlers| battlers.map { |battler| battler.name.to_s } })
    rescue => e
      Playback.set_up
      MGQ_MpBattlesSync.log_once(:names, "could not read the host's names, showing them unswapped: #{e.class}: #{e.message}")
    end

    # Swaps the host's names in a text, as the DLL swaps them in the stream.
    #
    # @param text [String] The host's text.
    # @return [String] The guest's text, the host's when the DLL does not answer.
    def self.swap(text)
      swapped = MGQ_Multiplayer::Bridge.call(Playback::SWAP_TOPIC, text.to_s)
      swapped.is_a?(String) ? swapped : text
    end
  end

  # Carries a live battle's messages over the world's room across a reconnect, in which messages
  # may be lost and the relay keeps none. Each message to a player carries its number to them; the
  # sender keeps the last KEPT_SENDS it sent each player; whoever sees a player of the battle come
  # back asks them for what came after the last number taken (RESYNC_KIND); the receiver takes
  # each number once and in order.
  module Sequence
    # The message's field that carries its number.
    NUMBER_FIELD = "sq"

    # The highest number a message carries.
    MAX_NUMBER = 999_999_999

    # The message that asks a player for what they sent after a number, in its NUMBER_FIELD.
    RESYNC_KIND = "resync"

    # Messages kept per player to send again, about fifty seconds of the host's stream.
    KEPT_SENDS = 300

    # Forgets the numbers of an earlier battle.
    def self.reset
      @sent = {}
      @taken = {}
      @held = {}
      @held_since = {}
    end

    # Numbers a message to a player, keeps it, and sends it unless the player is away.
    #
    # @param seat [Integer] The seat the battle knows them by.
    # @param kind [String] What it is.
    # @param body [String] The rest.
    # @return [Boolean] Whether it went out now.
    def self.deliver(seat, kind, body)
      reset unless @sent
      counter = @sent[seat] ||= [0, []]
      counter[0] += 1
      entry = [counter[0], kind, body]
      counter[1] << entry
      counter[1].shift while counter[1].size > KEPT_SENDS
      transmit(seat, entry)
    end

    # Sends a kept message to the world seat its player holds now.
    #
    # @param seat [Integer] The seat the battle knows them by.
    # @param entry [Array] The message's number, kind and body.
    # @return [Boolean] Whether it went out.
    def self.transmit(seat, entry)
      world = MGQ_MpBattlesSync.world_seat_of(seat)
      world ? MGQ_MpBattlesSync.tell(world, entry[1], MGQ_MpBattlesSync.battle_id, entry[2], entry[0]) : false
    end

    # Takes a numbered message: the next one at once with those held after it, a later one held
    # until the ones before came, one taken before left out.
    #
    # @param seat [Integer] The seat the battle knows the sender by.
    # @param number [Integer] Its number.
    # @param kind [String] What it is.
    # @param body [String] The rest.
    def self.take(seat, number, kind, body)
      reset unless @taken
      last = @taken[seat]
      if last && number <= last
        return MGQ_MpBattlesSync.log_once([:taken_before, seat, MGQ_MpBattlesSync.battle_id], "left out #{kind[0, 40]} from #{MGQ_MpBattlesSync.who(seat)}, taken before")
      end
      if last && number > last + 1
        (@held[seat] ||= {})[number] = [kind, body]
        @held_since[seat] ||= MGQ_Multiplayer::Bridge.frame_number
        return MGQ_MpBattlesSync.log_once([:held, seat, last, MGQ_MpBattlesSync.battle_id], "holds #{kind[0, 40]} from #{MGQ_MpBattlesSync.who(seat)} until those after #{last} came")
      end

      @taken[seat] = number
      Channel.receive(seat, kind, body)
      release(seat)
    end

    # Hands on the held messages that follow the last one taken from a player.
    #
    # @param seat [Integer] The seat the battle knows the sender by.
    def self.release(seat)
      held = @held[seat]
      return unless held

      while (entry = held.delete(@taken[seat] + 1))
        @taken[seat] += 1
        Channel.receive(seat, *entry)
      end
      @held_since.delete(seat) if held.empty?
    end

    # Hands on the held messages of a player whose missing ones never came within the world's
    # grace, so the battle goes on without them.
    def self.let_gaps_go
      return unless @held_since && (grace = MGQ_MpOverworldSync.grace_frames)

      @held_since.keys.each do |seat|
        next if MGQ_Multiplayer::Bridge.frame_number - @held_since[seat] < grace

        first = @held[seat].keys.min
        MGQ_MpBattlesSync.log("messages #{@taken[seat] + 1} to #{first - 1} from #{MGQ_MpBattlesSync.who(seat)} never came, going on without them")
        @taken[seat] = first - 1
        @held_since.delete(seat)
        release(seat)
      end
    end

    # Asks a player of the battle who came back for what they sent after the last message taken.
    # Called by overworld_sync.rbx for each change of a player's presence.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @param change [Symbol] :away, :back, :moved or :gone.
    def self.presence(peer, change)
      return unless [:back, :moved].include?(change) && peer.away.nil?
      return unless MGQ_MpBattlesSync.role && MGQ_MpBattlesSync.world? && !MGQ_MpBattlesSync.served?

      seat = Seats.of_kept(peer)
      return unless seat

      reset unless @taken
      last = @taken[seat].to_i
      MGQ_MpBattlesSync.tell(peer.seat, RESYNC_KIND, MGQ_MpBattlesSync.battle_id, "", last)
      MGQ_MpBattlesSync.log("#{MGQ_MpBattlesSync.who(seat)} is back: asked for what they sent after message #{last}")
    end

    # Sends a player who came back the kept messages after the last one they took, forgetting
    # those before.
    #
    # @param seat [Integer] The seat the battle knows them by.
    # @param last [Integer] The number of the last message they took.
    def self.resend(seat, last)
      return unless (MGQ_MpBattlesSync.player_seats | MGQ_MpBattlesSync.expected).include?(seat)

      counter = (@sent || {})[seat]
      return MGQ_MpBattlesSync.log("#{MGQ_MpBattlesSync.who(seat)} asked for messages again, none kept for them") unless counter

      counter[1].reject! { |entry| entry[0] <= last }
      sent = counter[1].select { |entry| transmit(seat, entry) }
      MGQ_MpBattlesSync.log("#{MGQ_MpBattlesSync.who(seat)} asked for what came after message #{last}: sent #{sent.size} of #{counter[1].size} again")
    end
  end

  # The live battle's names for its players: the world seats they held as the battle began, which
  # its structures and the messages between its games carry. A reconnect may deal the world's seats
  # anew, so each name stays with its player's id. Where a player is, and whether they are present,
  # away or gone, only MGQ_MpOverworldSync::Peers knows; it is asked at every send and receive, and
  # its gone event alone takes a player out (see presence).
  module Seats
    # Names the room as it is at the battle's start: the player's own seat and every known player's.
    def self.pin_room
      @own = MGQ_MpOverworldSync::Me.seat
      @ids = {}
      @gone = []
      MGQ_MpOverworldSync::Peers.all.each { |peer| pin(peer.seat, peer) }
    end

    # Forgets the names, as the live battle finishes.
    def self.forget
      @own = nil
      @ids = {}
      @gone = []
    end

    # Tells the player's own seat in the battle.
    #
    # @return [Integer] The world seat they held at its start, their world seat outside a battle.
    def self.own
      @own || MGQ_MpOverworldSync::Me.seat
    end

    # Tells the seat the battle knows a player by: the one named for their id, else, for a player
    # new to the battle, their world seat, named for them from then on.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @return [Integer, nil] The seat, nil when their world seat names another player still kept.
    def self.of(peer)
      id = peer.state["id"].to_s
      return peer.seat if @own.nil? || id.empty?

      named = @ids.key(id)
      return named if named

      holder = @ids[peer.seat]
      return nil if holder && MGQ_MpOverworldSync::Peers.kept_with_id(holder)

      pin(peer.seat, peer)
    end

    # Finds the player the battle knows by a seat, on whatever world seat they hold now.
    #
    # @param seat [Integer] The seat the battle knows them by.
    # @return [MGQ_MpOverworldSync::Peers::Peer, nil] The player, also while away; nil once gone.
    def self.peer(seat)
      return MGQ_MpOverworldSync::Peers.at(seat) unless @own

      id = @ids[seat]
      return MGQ_MpOverworldSync::Peers.kept_with_id(id) if id

      peer = MGQ_MpOverworldSync::Peers.at(seat)
      peer && of(peer) == seat ? peer : nil
    end

    # Tells the world seat a message to a player of the battle goes to.
    #
    # @param seat [Integer] The seat the battle knows them by.
    # @return [Integer, nil] Their world seat now, the seat itself for a player the world never told
    #   of; nil while they are away, since their old seat may be another player's, or once gone.
    def self.world(seat)
      found = peer(seat)
      return found.away.nil? ? found.seat : nil if found

      @own && @ids[seat] ? nil : seat
    end

    # Names a seat for a player's id.
    #
    # @param seat [Integer] The seat.
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @return [Integer] The seat.
    def self.pin(seat, peer)
      id = peer.state["id"].to_s
      @ids[seat] = id unless id.empty? || seat == @own
      seat
    end

    # Notes a player of the battle the world tells is gone, whom the battle's next look takes out
    # (see take_gone). Called by overworld_sync.rbx for each change of a player's presence.
    #
    # Away is a pause: the battle sends them nothing meanwhile and waits for them.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @param change [Symbol] :away, :back, :moved or :gone.
    def self.presence(peer, change)
      return unless @own && change == :gone

      seat = of_kept(peer)
      @gone << seat if seat && !@gone.include?(seat)
    end

    # Tells the seat the battle knows a player by, without naming one for a player new to it.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @return [Integer, nil] The seat, nil for a player the battle never named.
    def self.of_kept(peer)
      id = peer.state["id"].to_s
      id.empty? ? peer.seat : @ids.key(id)
    end

    # Takes the players the world told are gone since the last look.
    #
    # @return [Array<Integer>] The seats the battle knows them by.
    def self.take_gone
      gone = Array(@gone)
      @gone = []
      gone
    end
  end

  # Tells the player at once when another player leaves the live battle or joins it while it runs,
  # in the battle's popup at the top and in a notice at the bottom left of the map.
  #
  # The battle itself takes a player who left out only at its next command phase.
  module Departures
    # What marks the popup of a join or a departure, with its kind and seat: the game shows one popup
    # of a mark at a time, so the host's, which a guest's battle plays back, and the guest's own
    # show once.
    POPUP_MARK = :mgq_mp_departure

    # Tells that a player of the battle left it, as their "leave" says; a "leave" of a player not in
    # it tells nothing.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.left(peer)
      return unless MGQ_MpBattlesSync.player_seats.include?(MGQ_MpBattlesSync.seat_of(peer))

      tell(peer, "#{peer.state['name']} left the battle.")
    end

    # Tells the player something of the battle at once, in the battle's popup and in a notice on the
  # map, such as why they never got into a battle.
  #
  # @param text [String] What the player sees.
  def self.say(text)
    MGQ_MpBattlesSync.log("told the player: #{text}")
    popup(text, [POPUP_MARK, :said])
    MGQ_MpOverworldSync.notice(text)
  rescue => e
    MGQ_MpBattlesSync.log("telling the player failed: #{e.class}: #{e.message}")
  end

  # Tells that a player of the battle left the world. Called by overworld_sync.rbx.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.gone(peer)
      return unless MGQ_MpBattlesSync.role && MGQ_MpBattlesSync.world? && MGQ_MpBattlesSync.player_seats.include?(Seats.of_kept(peer))

      tell(peer, "#{peer.state['name']} left the world, and the battle.")
    end

    # Tells that a player joined the running battle, as the host took them in. Called by
    # battles_coop.rbx.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.joined(peer)
      tell(peer, "#{peer.state['name']} joined the battle.", :joined)
    end

    # Tells of a player leaving or joining, once per battle and player, as the DLL's session
    # remembers the last ones told.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @param text [String] What the player sees.
    # @param kind [Symbol] :left for a departure, :joined for a join, told apart since a player may
    #   join and then leave.
    def self.tell(peer, text, kind = :left)
      seat = Seats.of_kept(peer) || peer.seat
      return unless MGQ_Multiplayer::Bridge.call(DEPARTURE_TOPIC, "seat" => seat, "kind" => kind.to_s)

      MGQ_MpBattlesSync.log("told the player: #{text}")
      popup(text, [POPUP_MARK, kind, seat])
      MGQ_MpOverworldSync.notice(text)
    rescue => e
      MGQ_MpBattlesSync.log("telling of a departure failed: #{e.class}: #{e.message}")
    end

    # Shows a line in the battle's popup at the top, as the game shows a skill's name.
    #
    # @param text [String] The line.
    # @param mark [Array] What marks it, see POPUP_MARK.
    def self.popup(text, mark)
      scene = SceneManager.scene
      return unless scene.is_a?(Scene_Battle)

      log = MGQ_MpGame.get(scene, :log_window)
      log.popup.push(text, mark) if log && log.respond_to?(:popup)
    end
  end

  # The box that says what the game waits for, whom it still waits for and for how long, and offers
  # to leave the battle when the wait drags on, asking first: a hud of the Mod Framework's UI layer
  # at the top, above the battle's windows, which the player moves and widens with Alt. It never
  # takes the keys; the wait reads cancel itself.
  module Waiting
    # Width of the box where it starts.
    WIDTH = 360

    # The box's least width.
    MIN_WIDTH = 260

    # The box's place id, which names its place in the Mod Framework's settings.
    LAYOUT_ID = :mgq_online_waiting_box

    # The box's name while the player arranges the boxes.
    LAYOUT_NAME = "Waiting box"

    # Frames a wait lasts before the box offers to leave the battle, ten seconds. Offered later, the
    # key that moved the last message on never leaves by chance.
    LEAVE_FRAMES = 600

    # What the box says once it offers to leave, the cancel key as the player bound it filled in.
    LEAVE_TEXT = "Press %s to leave the battle."

    # What the box says once it offers to leave a story's battle, which the player then loses, the
    # cancel key filled in.
    LEAVE_LOSES_TEXT = "Press %s to leave and lose the battle."

    # What the box says once it offers to leave while the host waits for the commands, where cancel
    # before goes back to the host's own commands, the cancel key filled in.
    BACK_TEXT = "Press %s to choose again or leave."

    # What the player is asked before they leave the battle.
    LEAVE_QUESTION = "Leave the battle?"

    # What the player is asked before they leave a story's battle, which they then lose.
    LEAVE_LOSES_QUESTION = "Leave the battle? You lose it, and the others fight on."

    # The answer to the leave question that leaves.
    LEAVE_CHOICE = "Leave"

    # The answer that stays during a wait.
    STAY_CHOICE = "Stay"

    # The answer that chooses the host's own commands again while the host waits for them.
    BACK_CHOICE = "Choose again"

    # What starts the names line unless the caller passes another.
    WAITING_PREFIX = "Waiting for: "

    # What the box says while the game waits for a player, with their name.
    WAITING_FOR = "Waiting for %s..."

    # What the names line calls the player.
    OWN_NAME = "you"

    # Frames in a second, by which the seconds line counts.
    FRAMES_PER_SECOND = 60

    # How the seconds line reads.
    SECONDS_TEXT = "%d s"

    # An open box.
    #
    # @!attribute handle [Object] The hud's handle.
    # @!attribute text [String] What the game waits for.
    # @!attribute details [Proc, nil] Names the players still waited for.
    # @!attribute prefix [String] What starts the names line.
    # @!attribute names [Array<String>, nil] The names last shown, nil before the first.
    # @!attribute seconds [Integer, nil] The seconds last shown, nil before the first.
    # @!attribute time [String] What the last line says, the seconds or the leave offer, "" before
    #   the first.
    # @!attribute offering [Boolean] Whether the last line offers to leave the battle.
    Box = Struct.new(:handle, :text, :details, :prefix, :names, :seconds, :time, :offering)

    # The box: what the game waits for, the players still waited for, and the seconds or, from
    # LEAVE_FRAMES on, the leave offer, which a click asks as cancel does.
    class WaitingBox < Mod_Framework::UI::Component
      # Describes the box.
      def render
        hud id: LAYOUT_ID, place_name: LAYOUT_NAME, anchor: :top, layer: :over, shown_in: [Scene_Battle], resizable: :width, width: WIDTH,
            min_size: [MIN_WIDTH, 0] do
          text -> { Waiting.line(:text) }, align: :center
          text -> { Waiting.line(:names) }, align: :center
          text -> { Waiting.line(:time) }, align: :center, visible: -> { !Waiting.offering? }
          button -> { Waiting.line(:time) }, variant: :text, align_self: :center, visible: -> { Waiting.offering? }, on_click: -> { Waiting.click_leave }
        end
      end
    end

    # Opens the box with its first line set, the others empty, where the player left it.
    #
    # @param text [String] What the game waits for.
    # @param details [Proc, nil] Returns an Array<String> of the names still waited for, or nil or
    #   an empty Array for none; asked every frame, so it must be cheap. One that raises is logged
    #   once and the line stays empty.
    # @param prefix [String] What starts the names line, such as "Still choosing: ".
    # @return [Box] The box.
    def self.open(text, details = nil, prefix = WAITING_PREFIX)
      @leave_clicked = false
      @box = Box.new(nil, text, details, prefix, nil, nil, "", false)
      @box.handle = Mod_Framework::UI.show(WaitingBox)
      @box
    end

    # Tells a line of the open box.
    #
    # @param which [Symbol] :text, :names or :time.
    # @return [String] The line, "" without a box.
    def self.line(which)
      box = @box
      return "" unless box

      { :text => box.text.to_s, :names => names_line(box), :time => box.time.to_s }[which]
    end

    # Reports whether the open box offers to leave the battle in its last line.
    #
    # @return [Boolean] Whether it does.
    def self.offering?
      @box && @box.offering ? true : false
    end

    # Takes a click on the leave offer, which the wait asks as cancel.
    def self.click_leave
      @leave_clicked = true
    end

    # Writes the leave offers with the cancel key as the player bound it.
    #
    # @return [Array<String>] LEAVE_TEXT, LEAVE_LOSES_TEXT and BACK_TEXT, filled in.
    def self.offers
      [LEAVE_TEXT, LEAVE_LOSES_TEXT, BACK_TEXT].map { |text| offer(text) }
    end

    # Writes a leave offer with the cancel key as the player bound it in F1.
    #
    # @param text [String] LEAVE_TEXT, LEAVE_LOSES_TEXT or BACK_TEXT.
    # @return [String] The offer, such as "Press X to leave the battle.".
    def self.offer(text)
      format(text, Mod_Framework::UI::Game.key_name(:B))
    end

    # Writes the names line: the prefix and the names last shown, which the line cuts to its width.
    #
    # @param box [Box] The box.
    # @return [String] The line, "" for no names.
    def self.names_line(box)
      names = box.names || []
      names.empty? ? "" : "#{box.prefix}#{names.join(', ')}"
    end

    # Notes what changed: the names when they differ from those shown, the seconds once every
    # second, or the leave offer at LEAVE_FRAMES, which stays. Frames below 0 set no seconds.
    #
    # @param box [Box] The box.
    # @param frames [Integer] Frames the box has been open, 0 in the frame it opened.
    # @param back [Boolean] Whether cancel goes back to the host's own commands, see wait_for.
    def self.refresh(box, frames, back = false)
      names = names_of(box)
      box.names = names if names != box.names
      if frames == LEAVE_FRAMES
        box.time = offer(back ? BACK_TEXT : (Live.leaving_loses? ? LEAVE_LOSES_TEXT : LEAVE_TEXT))
        box.offering = true
      elsif frames >= 0 && frames < LEAVE_FRAMES && frames % FRAMES_PER_SECOND == 0
        box.seconds = frames / FRAMES_PER_SECOND
        box.time = format(SECONDS_TEXT, box.seconds)
      end
    end

    # Asks a box's details for the names still waited for.
    #
    # @param box [Box] The box.
    # @return [Array<String>] The names, none without details or when they fail.
    def self.names_of(box)
      return [] unless box.details

      Array(box.details.call).map { |name| name.to_s }
    rescue => e
      MGQ_MpBattlesSync.log_once(box.details, "the waiting box could not name whom it waits for: #{e.class}: #{e.message}")
      []
    end

    # Sets what changed, offers to leave the battle once the wait lasted LEAVE_FRAMES, and tells
    # whether the player confirmed leaving.
    #
    # @param box [Box] The box.
    # @param frames [Integer] Frames the box has been open.
    # @return [Boolean] Whether the player leaves the battle.
    def self.leave?(box, frames)
      choice(box, frames) == :left
    end

    # Sets what changed and reads the player's cancel, the game's own as bound and the numpad's 0,
    # and a click on the leave offer: with back, cancel goes back to the host's own commands at
    # once; once the wait lasted LEAVE_FRAMES it asks whether the player leaves the battle, a no
    # answer then going back or waiting on.
    #
    # A single cancel never leaves, since players press it to go back and choose again.
    #
    # @param box [Box] The box.
    # @param frames [Integer] Frames the box has been open.
    # @param back [Boolean] Whether cancel goes back to the host's own commands.
    # @return [Symbol, nil] :left once the player confirmed leaving, :back to choose again, nil to
    #   wait on.
    def self.choice(box, frames, back = false)
      refresh(box, frames, back)
      return answer_to_leave if @leave_asked
      if frames == LEAVE_FRAMES
        MGQ_MpBattlesSync.log("still waiting after #{LEAVE_FRAMES / FRAMES_PER_SECOND} s (#{box.text}), cancel now asks whether to leave the battle")
      end
      clicked = @leave_clicked
      @leave_clicked = false
      return nil unless Mod_Framework::UI.cancel? || clicked
      return :back if back && frames < LEAVE_FRAMES
      return nil if frames < LEAVE_FRAMES

      ask_to_leave(back)
      nil
    end

    # Asks the player whether they leave the battle, "no" lit first.
    #
    # @param back [Boolean] Whether "no" goes back to the host's own commands instead of waiting on.
    def self.ask_to_leave(back)
      question = Live.leaving_loses? ? LEAVE_LOSES_QUESTION : LEAVE_QUESTION
      token = Object.new
      @leave_asked = token
      @leave_answer = nil
      @leave_question = Mod_Framework::UI.confirm(question, yes: LEAVE_CHOICE, no: back ? BACK_CHOICE : STAY_CHOICE) do |yes|
        # A question the wait closed answers later, after the wait is gone.
        @leave_answer = yes ? :left : (back ? :back : :stay) if @leave_asked.equal?(token)
      end
      @leave_asked = nil unless @leave_question
      MGQ_MpBattlesSync.log(@leave_question ? "asked the player whether to leave the battle" : "could not ask the player whether to leave the battle")
    end

    # Takes the leave question's answer once given; the Mod Framework answers the question at every
    # Input.update, the battle's waits' too.
    #
    # @return [Symbol, nil] :left or :back once answered so, nil while open or answered "Stay".
    def self.answer_to_leave
      answer = @leave_answer
      return nil unless answer

      @leave_asked = nil
      @leave_answer = nil
      @leave_question = nil
      MGQ_MpBattlesSync.log(answer == :left ? "the player confirmed leaving the battle" : "the player stays in the battle")
      answer == :stay ? nil : answer
    end

    # Closes the leave question a wait leaves open, which then answers nothing.
    def self.drop_leave_question
      return unless @leave_asked

      question = @leave_question
      @leave_asked = nil
      @leave_answer = nil
      @leave_question = nil
      question.close("the wait ended") if question && question.open?
    end

    # Closes a box, and the leave question it asked.
    #
    # @param box [Box, nil] The box.
    # @return [nil] Always, so the caller's box is gone.
    def self.close(box)
      drop_leave_question
      if box
        box.handle.hide if box.handle && box.handle.shown?
        @box = nil if @box.equal?(box)
      end
      nil
    end

    # Waits, with the box open, until the block has an answer, the battle ended early, the player
    # left it or, with back, went back to choose their commands again.
    #
    # @param scene [Scene_Battle] The battle.
    # @param text [String] What the game waits for.
    # @param details [Proc, nil] Names the players still waited for, see open.
    # @param prefix [String] What starts the names line, see open.
    # @param back [Boolean] Whether Cancel goes back to the host's own commands, see choice.
    # @yieldreturn [Object, nil] The answer, nil to wait on.
    # @return [Object, Symbol] The answer, an ending of Channel.ending, :left when the player left,
    #   or :back when they go back to their commands.
    def self.wait_for(scene, text, details = nil, prefix = WAITING_PREFIX, back = false)
      box = nil
      frames = 0
      was_active = @active
      @active = true
      held = hold_input(scene)
      loop do
        answer = yield
        return answer if answer

        ending = Channel.ending
        return ending if ending

        box ||= open(text, details, prefix)
        choice = choice(box, frames, back)
        if choice
          MGQ_MpBattlesSync.log(choice == :left ? "the player left the battle during the wait (#{text})" : "the player went back to their commands during the wait (#{text})")
          return choice
        end

        frames += 1
        MGQ_MpGame.call(scene, :update_for_wait)
      end
    ensure
      @active = was_active
      close(box)
      release_input(held)
    end

    # Reports whether a wait of wait_for is open, during which the battle updates without its course
    # going on.
    #
    # The raid pool leaves the victory over enemies it kills meanwhile to the wait's answer, since
    # the turn the host waits in would start on the finished battle.
    #
    # @return [Boolean] Whether one is.
    def self.active?
      @active ? true : false
    end

    # Deactivates the battle's windows that take input for a wait, since the battle keeps updating
    # them while it waits.
    #
    # The game's auto battle activates the hidden party command right before the turn the host
    # waits in, where its presses started a second command phase.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Array<Window_Selectable>] The windows it deactivated.
    def self.hold_input(scene)
      windows = scene.instance_variables.map { |name| scene.instance_variable_get(name) }
      windows.select { |window| window.is_a?(Window_Selectable) && !window.disposed? && window.active }.each(&:deactivate)
    rescue => e
      MGQ_MpBattlesSync.log("could not hold the battle's input: #{e.class}: #{e.message}")
      []
    end

    # Hands the windows a wait deactivated back as they were.
    #
    # @param windows [Array<Window_Selectable>, nil] The windows.
    def self.release_input(windows)
      Array(windows).each { |window| window.activate unless window.disposed? }
    end
  end

end

# What this script takes part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route("battle") { |peer, message| MGQ_MpBattlesSync.take(peer, message) }
  MGQ_MpOverworldSync.on_leave { |peer| MGQ_MpBattlesSync::Departures.gone(peer) }
  MGQ_MpOverworldSync.on_presence do |peer, change|
    MGQ_MpBattlesSync::Seats.presence(peer, change)
    MGQ_MpBattlesSync::Sequence.presence(peer, change)
  end
rescue => e
  MGQ_MpBattlesSync.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # Installs the battle hooks as the game starts running, see MGQ_MpBattlesSync::Hooks.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_sync") { MGQ_MpBattlesSync::Hooks.install }
rescue => e
  MGQ_MpBattlesSync.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
end
