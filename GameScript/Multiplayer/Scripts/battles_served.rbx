#----------------------------------------------------------------
#  battles_served.rbx
#
#  Changelog:
#      Paulinchen  2026-10-15: Handed the battle server how the battle's boss fights, by pools or by tier
#                            - Stood in for the battle server in the world's room as its starter, for players who join late
#                            - Sent a guest's messages to the server alone and passed a player's leave on to the others
#                            - Created
#
#----------------------------------------------------------------

# Co-op battles the battle server hosts. The player who starts a battle gathers its players as
# ever, then hands them to the server instead of hosting it; every player, the starter too, plays
# it back as a guest. The battle's messages travel over a battle channel of its own through the
# relay, which only that battle's players and the server share, instead of the world's room: the
# world stays end to end encrypted, and the server reads that one battle. The same script runs on
# the battle server, which hosts with it (see server?).
#
# Without a battle server, such as on a relay that has none, the starter hosts as it always did.
# It builds on battles_sync.rbx, battles_sync_live.rbx and battles_coop.rbx.

module MGQ_MpBattlesServed
  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "served battle"

  # The battle server's seat on a battle channel, which no world seat reaches.
  SERVER_SEAT = 250

  # The seat a message to everyone on the battle channel names.
  EVERYONE = -1

  # What the starter tells the server, see setup_text; a server answers a setup of another format
  # with a refusal, and the starter hosts.
  FORMAT = 1

  # Frames the starter waits for the relay to start the battle on its server, five seconds; past
  # them it hosts the battle itself.
  SERVE_FRAMES = 300

  # Frames a player waits for the battle channel to open before the battle counts as gone.
  OPEN_FRAMES = 600

  # Frames the battle server waits for every player to come onto the battle channel before the
  # battle starts without those who did not.
  ARRIVE_FRAMES = 600

  # Bytes the DLL may write an entry of the battle channel into at first.
  ENTRY_SIZE = 4_096

  # Bytes the DLL may write the battle channel's state into at first.
  STATE_SIZE = 1_024

  # The relay's answers that end every later try in this game session: it has no battle server,
  # serves no battles of this mod's version, or its server's MGQ Online or game data differ from
  # this game's. Others, such as a busy server, end only this try.
  LASTING_REFUSALS = %w(no_server update unsupported scripts data)

  # The co-op messages the starter of a served battle passes on to the battle server, being its
  # front in the world's room: other players' requests to join the battle with an encounter (hot)
  # or by choice (pick), and their taking one back (off).
  FRONT_KINDS = %w(hot off pick)

  # The battle channel's message the starter passes such a request on in, with its player's state.
  FRONT_IN = "front_in"

  # The battle channel's message the server sends the world's room a message in, which the starter
  # passes on.
  FRONT_OUT = "front_out"

  # The battle channel's message the server tells the fields of its state in that the world's
  # players read to join it, which the starter tells as its own.
  FRONT_STATE = "front_state"

  # The battle channel's message the starter tells the server a player left the world in.
  FRONT_LEFT = "front_left"

  # The fields of the server's state the starter tells as its own, see FRONT_STATE.
  FRONT_FIELDS = %w(rbn)

  # Frames between two looks at the server's state for the front, half a second.
  FRONT_STATE_FRAMES = 30

  # The fields of a player's state the starter passes on with a request, which the server's co-op
  # battles read of a player: their id and name.
  FRONT_STATE_KEYS = %w(id name)

  # The battle channel's message the server tells the other players in that one left the battle,
  # since a player's leave reaches the server alone.
  DEPARTED = "departed"

  class << self
    # The battle channel's state on this game: nil, :opening, :open or :closed.
    attr_reader :channel
  end

  # Reports whether a battle the player starts may go to the battle server: a world is open, the
  # DLL is there, and the relay has not said it has none.
  #
  # @return [Boolean] Whether it may.
  def self.available?
    return false if server? || @lasting_refusal

    MGQ_Multiplayer.available? && MGQ_MpOverworldSync.in_world?
  rescue
    false
  end

  # Reports whether this game is the battle server, which hosts the battles it is handed.
  #
  # @return [Boolean] Whether it is.
  def self.server?
    @server ? true : false
  end

  # Reports whether this game started the served battle it plays back: its players' builds went to
  # the server with the battle, so it sends no join of its own.
  #
  # @return [Boolean] Whether it did.
  def self.starter?
    @starter ? true : false
  end

  # As starter, hands a gathered battle to the battle server, tells the guests to follow it and
  # becomes a guest of it. Called by MGQ_MpBattlesCoop.gather once the players are arranged.
  #
  # @param scene [Scene_Battle] The battle.
  # @param players [Array<MGQ_MpBattlesCoop::Player>] The players, the starter among them.
  # @param level [Integer, nil] The battle's level, see MGQ_MpCoopLevelSync.level_for.
  # @return [Boolean] Whether the server took the battle; false when the starter hosts it.
  def self.serve(scene, players, level)
    return false unless available?

    battle_id = MGQ_MpBattlesSync.battle_id
    seats = players.map(&:seat)
    unless Link.serve(world_id, battle_id, seats, setup_text(players, level))
      log("the DLL did not start battle #{battle_id} on the server: the starter hosts it")
      return false
    end

    frames = 0
    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Starting the battle on the server...") do
      frames += 1
      state = Link.state
      if state["state"] == "served" then true
      elsif state["state"] == "refused" then [:refused, state["code"].to_s]
      elsif frames >= SERVE_FRAMES then [:refused, "timeout"]
      end
    end
    unless answer == true
      code = answer.is_a?(Array) ? answer[1] : answer.to_s
      @lasting_refusal = code if LASTING_REFUSALS.include?(code)
      log("the server did not take battle #{battle_id} (#{code}): the starter hosts it" +
          (@lasting_refusal ? ", and every later battle of this session" : ""))
      Link.close
      return false
    end

    MGQ_MpBattlesSync::Channel.post("serve", MGQ_MpBattlesSync::Wire.line([battle_id]))
    @starter = true
    become_guest(battle_id)
    log("battle #{battle_id} went to the server with #{players.size} players: the starter plays it back as a guest")
    true
  end

  # As guest, follows the battle to the server the host handed it to: the battle's messages come
  # over the battle channel from then on. Called by MGQ_MpBattlesCoop.join when the host's serve
  # came instead of its roster.
  #
  # @param body [String] The serve's body: the battle's id.
  def self.follow(body)
    battle_id = MGQ_MpBattlesSync::Wire.parse(body.to_s)[0].to_s
    return log("ignored a serve for battle #{battle_id}: this game is in battle #{MGQ_MpBattlesSync.battle_id}") unless battle_id == MGQ_MpBattlesSync.battle_id

    @starter = false
    become_guest(battle_id)
    log("the host handed battle #{battle_id} to the server: following it there")
  end

  # Makes the live battle a guest's of the server, over the battle channel.
  #
  # @param battle_id [String] The battle's id.
  def self.become_guest(battle_id)
    MGQ_MpBattlesSync.serve_over_channel(:guest, battle_id, [SERVER_SEAT], "the server")
    open(battle_id)
  end

  # Opens the battle channel of a battle.
  #
  # @param battle_id [String] The battle's id.
  def self.open(battle_id)
    @in = []
    @out = []
    @opened = 0
    @channel = Link.open(world_id, battle_id) ? :opening : :closed
    log(@channel == :opening ? "opening the battle channel of battle #{battle_id}" : "the DLL did not open the battle channel of battle #{battle_id}")
  end

  # Closes the battle channel, as the live battle finishes; also one that ended, which the DLL then
  # forgets.
  def self.close
    return unless @channel

    Link.close
    log("closed the battle channel")
    @channel = nil
    @starter = false
    @front_state = nil
    @told_state = nil
  end

  # Sends a message of the battle over the battle channel: a guest's to the server alone, whatever
  # seats it names, since the relay closes the channel of a player who sends to another; the
  # server's to the battle's players.
  #
  # @param seats [Array<Integer>] The seats it goes to.
  # @param kind [String] What it is.
  # @param body [String] The rest.
  # @return [Array<Integer>] The seats it reached.
  def self.post(seats, kind, body)
    seats = [SERVER_SEAT] unless server?
    text = MGQ_MpOverworldSync::Me.encode({ "battle" => kind, "bid" => MGQ_MpBattlesSync.battle_id }) + body.to_s
    seats.select { |seat| Link.send_to(seat, text) }
  end

  # Takes a player's leave on the battle server, and tells the battle's other players. Called by
  # MGQ_MpBattlesSync.take_served.
  #
  # @param seat [Integer] The player's world seat.
  def self.pass_departure(seat)
    others = MGQ_MpBattlesSync.player_seats - [seat]
    post(others, DEPARTED, MGQ_MpBattlesSync::Wire.line([seat])) unless others.empty?
  end

  # Takes the server's word that a player left the battle, as their own leave would tell. Called
  # by MGQ_MpBattlesSync.take_served.
  #
  # @param body [String] The player's world seat.
  def self.take_departure(body)
    seat = MGQ_MpBattlesSync::Wire.parse(body.to_s)[0]
    peer = world_seat?(seat) && MGQ_MpOverworldSync::Peers.at(seat)
    MGQ_MpBattlesSync::Departures.left(peer) if peer
  end

  # Moves what came over the battle channel to the battle: messages, players coming and going, and
  # the channel's end. Called as the battle's messages are taken.
  def self.drain
    return unless @channel

    while (entry = Link.next_entry)
      take(entry)
    end
    return unless @channel == :opening

    @opened += 1
    if Link.state["state"] == "open"
      @channel = :open
      log("the battle channel is open")
    elsif @opened >= OPEN_FRAMES
      @channel = :closed
      log("the battle channel did not open within #{OPEN_FRAMES / 60} s")
    end
  end

  # Takes one entry of the battle channel.
  #
  # @param entry [Hash] The entry: "kind" ("seat", "in", "out", "message" or "closed"), "seat",
  #   "code" for closed, and the message under :payload.
  def self.take(entry)
    seat = entry["seat"].to_i
    case entry["kind"]
    when "seat"
      @channel = :open
      log("on the battle channel as seat #{seat}")
    when "in"
      @in << seat unless @in.include?(seat)
      @out.delete(seat)
      log("seat #{seat} came onto the battle channel")
    when "out"
      @out << seat unless @out.include?(seat)
      log("seat #{seat} left the battle channel")
    when "closed"
      @channel = :closed
      log("the battle channel closed: #{entry['code']}")
    when "message"
      message = MGQ_Multiplayer::Link.parse(entry[:payload].to_s.dup)
      return take_front(seat, message) if front_message?(message)

      MGQ_MpBattlesSync.take_served(seat, message)
    end
  end

  # The front: the starter of a served battle stands in for the battle server in the world's room,
  # where the other players find the battle to join it, since the server sits in no world room.

  # Reports whether a battle channel message is one of the front's, for this battle.
  #
  # @param message [Hash] The message.
  # @return [Boolean] Whether it is.
  def self.front_message?(message)
    [FRONT_IN, FRONT_OUT, FRONT_STATE, FRONT_LEFT].include?(message["battle"]) && message["bid"].to_s == MGQ_MpBattlesSync.battle_id.to_s
  end

  # Takes a message of the front: on the server, a request the starter passed on or a player who
  # left the world; on the starter, a message for the world's room or the server's state.
  #
  # @param seat [Integer] Its sender's seat on the battle channel.
  # @param message [Hash] The message.
  def self.take_front(seat, message)
    if server?
      return log("ignored #{message['battle']} from seat #{seat}: only the starter is the front") unless seat == @setup[:starter]

      return front_in(message[:payload]) if message["battle"] == FRONT_IN
      return front_left(message[:payload]) if message["battle"] == FRONT_LEFT
    elsif starter? && seat == SERVER_SEAT
      return take_front_out(message[:payload]) if message["battle"] == FRONT_OUT
      return take_front_state(message[:payload]) if message["battle"] == FRONT_STATE
    end
    log("ignored #{message['battle']} from seat #{seat}")
  rescue => e
    log("taking #{message['battle']} failed: #{e.class}: #{e.message}")
  end

  # Reports whether the starter passes a co-op message on to the battle server: a request to join
  # its served battle while its channel is open. Called by MGQ_MpBattlesCoop.take.
  #
  # @param message [Hash] The message.
  # @return [Boolean] Whether it does.
  def self.fronts?(message)
    starter? && @channel == :open && FRONT_KINDS.include?(message["coop"].to_s) && message["bid"].to_s == MGQ_MpBattlesSync.battle_id.to_s
  end

  # As starter, passes a request to join the served battle on to the battle server, with the
  # states of its player and of the players it brings along, as the world's room told them.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asked.
  # @param message [Hash] The request.
  def self.forward(peer, message)
    seats = [peer.seat] + message["seats"].to_s.split(",").map(&:to_i)
    states = seats.uniq.map { |seat| MGQ_MpOverworldSync::Peers.at(seat) }.compact.map do |known|
      [known.seat, pairs(known.state.select { |key, _| FRONT_STATE_KEYS.include?(key) })]
    end
    fields = pairs(message.reject { |key, _| key.is_a?(Symbol) })
    reached = post([SERVER_SEAT], FRONT_IN, MGQ_MpBattlesSync::Wire.line([peer.seat, states, fields]))
    log("passed #{message['coop']} of #{MGQ_MpOverworldSync.who(peer)} on to the battle server#{reached.empty? ? ' (not sent)' : ''}")
  end

  # As starter, tells the battle server a player left the world, whom it may have taken in.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  def self.peer_left(peer)
    return unless starter? && @channel == :open

    post([SERVER_SEAT], FRONT_LEFT, MGQ_MpBattlesSync::Wire.line([peer.seat]))
  end

  # As the battle server, takes a request the starter passed on as the world's room would have
  # handed it over: its players become known players of the world, then the co-op battles take it.
  #
  # @param body [String] The players' seat and states, and the request's fields, see forward.
  def self.front_in(body)
    seat, states, fields = MGQ_MpBattlesSync::Wire.parse(body.to_s)
    return log("ignored a request the starter passed on: its seat #{seat.inspect} is no world seat") unless world_seat?(seat)

    Array(states).each do |known, state|
      remember_peer(known, hash_of(state)) if world_seat?(known) && state.is_a?(Array)
    end
    peer = MGQ_MpOverworldSync::Peers.at(seat)
    return log("ignored a request the starter passed on: it names no state of seat #{seat}") unless peer

    MGQ_MpBattlesCoop.take(peer, hash_of(fields))
  end

  # As the battle server, forgets a player who left the world, as the world's room would.
  #
  # @param body [String] The player's seat.
  def self.front_left(body)
    seat = MGQ_MpBattlesSync::Wire.parse(body.to_s)[0]
    MGQ_MpOverworldSync::Peers.remove(seat, "left the world, the starter tells") if world_seat?(seat)
  end

  # As the battle server, sends a message to the world's room through the starter. Called by the
  # battle server's stand-in for the DLL's mp_world_send.
  #
  # @param seat [Integer] The seat it goes to, -1 for everyone.
  # @param text [String] The message.
  # @return [Boolean] Whether it went out.
  def self.front_out(seat, text)
    return false unless server? && @setup

    !post([@setup[:starter]], FRONT_OUT, MGQ_MpBattlesSync::Wire.line([seat, text])).empty?
  end

  # As starter, passes a message of the battle server on to the world's room: a co-op message only.
  #
  # @param body [String] The seat it goes to and the message, see front_out.
  def self.take_front_out(body)
    seat, text = MGQ_MpBattlesSync::Wire.parse(body.to_s)
    fields = MGQ_Multiplayer::Link.parse(text.to_s.dup)
    coop = fields["coop"] || fields[MGQ_MpCoop::MAP_PREFIX + "coop"]
    return log("dropped a message of the battle server for the world's room: it is no co-op message") unless seat.is_a?(Integer) && coop

    MGQ_MpOverworldSync::Link.send_to(seat, text.to_s)
    log("passed the battle server's #{coop} on to #{seat < 0 ? 'everyone' : MGQ_MpBattlesSync.who(seat)}")
  end

  # As the battle server, tells the starter the fields of its state that the world's players read
  # to join the battle, whenever they changed. Called every FRONT_STATE_FRAMES frames.
  def self.tell_front_state
    return unless server? && @setup

    fields = defined?(MGQ_MpBattlesJoin) ? MGQ_MpBattlesJoin.state_fields.select { |key, _| FRONT_FIELDS.include?(key) } : {}
    return if fields == @told_state

    @told_state = fields
    post([@setup[:starter]], FRONT_STATE, MGQ_MpBattlesSync::Wire.line([pairs(fields)]))
  end

  # As starter, keeps the fields of the battle server's state the starter tells as its own.
  #
  # @param body [String] The fields, see tell_front_state.
  def self.take_front_state(body)
    @front_state = hash_of(MGQ_MpBattlesSync::Wire.parse(body.to_s)[0]).select { |key, _| FRONT_FIELDS.include?(key) }
  end

  # Tells the fields the starter of a served battle tells as its own in place of a script's, so
  # the world's players find the battle and join it through the starter.
  #
  # @param keys [Array<String>] The script's fields: "rb" and "rbh" of MGQ_MpBattlesHotjoin, or
  #   FRONT_FIELDS of MGQ_MpBattlesJoin.
  # @return [Hash, nil] The fields, nil unless the player is the starter of a served battle.
  def self.front_fields(keys)
    return nil unless starter? && @channel == :open

    fields = { "rb" => MGQ_MpBattlesSync.battle_id.to_s, "rbh" => MGQ_MpOverworldSync::Me.seat.to_s }.merge(@front_state || { "rbn" => 0 })
    fields.select { |key, _| keys.include?(key) }
  end

  # Makes a player known to the battle server as the world's room would, by the state the starter
  # passed on.
  #
  # @param seat [Integer] Their world seat.
  # @param state [Hash] Their state.
  def self.remember_peer(seat, state)
    MGQ_MpOverworldSync::Peers.take(seat, state)
  rescue => e
    log("remembering seat #{seat} failed: #{e.class}: #{e.message}")
  end

  # Reports whether a value is a seat of a world's room.
  #
  # @param seat [Object] The value.
  # @return [Boolean] Whether it is.
  def self.world_seat?(seat)
    seat.is_a?(Integer) && seat >= 0 && seat < SERVER_SEAT
  end

  # Writes a hash of texts as Wire can carry it.
  #
  # @param hash [Hash] The hash.
  # @return [Array<Array(String, String)>] Its keys and values as texts.
  def self.pairs(hash)
    hash.map { |key, value| [key.to_s, value.to_s] }
  end

  # Reads a hash pairs wrote, leaving out what is no pair of texts.
  #
  # @param list [Object] The pairs.
  # @return [Hash{String => String}] The hash.
  def self.hash_of(list)
    Array(list).each_with_object({}) do |pair, hash|
      hash[pair[0]] = pair[1] if pair.is_a?(Array) && pair.size == 2 && pair.all? { |item| item.is_a?(String) }
    end
  end

  # Reports whether the battle channel ended, which ends the battle for a guest.
  #
  # @return [Boolean] Whether it did.
  def self.closed?
    drain
    @channel == :closed
  end

  # Reports whether a player left the battle channel. Asked by the server.
  #
  # @param seat [Integer] The player's world seat.
  # @return [Boolean] Whether they did.
  def self.out?(seat)
    Array(@out).include?(seat)
  end

  # Lists the players who came onto the battle channel. Asked by the server.
  #
  # @return [Array<Integer>] Their world seats.
  def self.arrived
    Array(@in)
  end

  # Names the world the game is in, whose players alone may come onto its battles' channels.
  #
  # @return [String] The world's directory id, empty outside a world, such as on the battle server.
  def self.world_id
    MGQ_MpWorld.world.directory_id.to_s
  rescue
    ""
  end

  # Writes what the server needs to host a battle the starter gathered: what its MGQ Online and
  # its game data are, the troop, how it ends, the map, the enemies' rates, the enemies as the
  # starter set them up, the arranged players and the level, the switches and variables the
  # troop's events read, how its boss fights (a Raid World's pools or a tier), the starter's seat,
  # the battle's front in the world's room, and a Raid World's squad rules for the players who join
  # late.
  #
  # @param players [Array<MGQ_MpBattlesCoop::Player>] The arranged players.
  # @param level [Integer, nil] The battle's level.
  # @return [String] The setup, a Wire line.
  def self.setup_text(players, level)
    switches = []
    $game_switches.instance_variable_get(:@data).each_with_index { |on, id| switches << id if on == true }
    variables = []
    $game_variables.instance_variable_get(:@data).each_with_index do |value, id|
      variables << [id, value] if value.is_a?(Integer) && value != 0
    end
    MGQ_MpBattlesSync::Wire.line([FORMAT, scripts_fingerprint, MGQ_MpWorld::GameData.fingerprint, $game_troop.troop.id,
                                  MGQ_MpGame.get(BattleManager, :can_escape) ? 1 : 0, MGQ_MpGame.get(BattleManager, :can_lose) ? 1 : 0,
                                  $game_map.map_id, MGQ_MpBattlesCoop.rates_text, MGQ_MpBattlesCoop.troop_entries,
                                  players.map(&:to_a), level.to_i, switches, variables, MGQ_MpBattlesCoop.raid? ? 1 : 0,
                                  defined?(MGQ_MpRaidPool) ? MGQ_MpRaidPool.served_fields : nil,
                                  defined?(MGQ_MpRaidTiers) && MGQ_MpRaidTiers.fight ? 1 : 0, MGQ_MpOverworldSync::Me.seat,
                                  (MGQ_MpWorld.squad || {}).map { |key, value| [key.to_s, value] }])
  end

  # Finds what this game's MGQ Online scripts are, once per session: a checksum of every script in
  # Multiplayer.rb's order, the line ends left out, which a server with other scripts would host
  # by another protocol.
  #
  # @return [String] The checksum, empty when a script could not be read.
  def self.scripts_fingerprint
    return @scripts_fingerprint if @scripts_fingerprint

    sum = 0
    MGQ_Multiplayer::SCRIPTS.each do |name|
      text = File.open(MGQ_Multiplayer.path("#{MGQ_Multiplayer::SCRIPTS_DIR}\\#{name}#{MGQ_Multiplayer::SCRIPT_EXTENSION}"), "rb") { |file| file.read }
      sum = Zlib.crc32(name + "\n" + text.delete("\r"), sum)
    end
    @scripts_fingerprint = format("%08x", sum)
  rescue => e
    log_once(:scripts_fingerprint, "reading the scripts failed: #{e.class}: #{e.message}")
    @scripts_fingerprint = ""
  end

  # Reads a setup as setup_text wrote it.
  #
  # @param text [String] The setup.
  # @return [Hash, nil] :scripts and :data (the starter's fingerprints), :troop, :escape, :lose,
  #   :map, :rates, :enemies, :players, :level, :switches, :variables, :raid, :pool (see
  #   MGQ_MpRaidPool.served_fields), :tiers, :starter and :squad (see MGQ_MpWorld.squad); nil for
  #   a setup of another format.
  def self.read_setup(text)
    format, scripts, data, troop, escape, lose, map, rates, enemies, players, level, switches, variables, raid, pool, tiers, starter, squad = MGQ_MpBattlesSync::Wire.parse(text.to_s)
    return nil unless format == FORMAT && troop.is_a?(Integer)

    { :scripts => scripts.to_s, :data => data.to_s,
      :troop => troop, :escape => escape == 1, :lose => lose == 1, :map => map.to_i, :rates => rates.to_s,
      :enemies => Array(enemies), :players => MGQ_MpBattlesCoop::Player.read_all(Array(players)),
      :level => level.is_a?(Integer) && level > 0 ? level : nil,
      :switches => Array(switches).select { |id| id.is_a?(Integer) && id > 0 },
      :variables => Array(variables).select { |pair| pair.is_a?(Array) && pair.size == 2 && pair.all? { |value| value.is_a?(Integer) } },
      :raid => raid == 1, :pool => pool.is_a?(Array) ? pool : nil, :tiers => tiers == 1, :starter => starter.is_a?(Integer) ? starter : nil,
      :squad => squad_of(squad) }
  end

  # Reads a Raid World's squad rules a setup carries, those of MGQ_MpWorld::DEFAULT_SQUAD's keys
  # alone.
  #
  # @param list [Object] The rules, as setup_text writes them.
  # @return [Hash, nil] The rules, nil for none.
  def self.squad_of(list)
    rules = {}
    Array(list).each do |key, value|
      symbol = MGQ_MpWorld::DEFAULT_SQUAD.keys.find { |known| known.to_s == key.to_s }
      rules[symbol] = value if symbol && (value.is_a?(Integer) || value == true || value == false)
    end
    rules.empty? ? nil : MGQ_MpWorld::DEFAULT_SQUAD.merge(rules)
  end

  # As the battle server, takes a battle to host: the game's state as the starter's for the troop's
  # events, the troop with its boss as the starter fights it, the live battle as host of the
  # players over the battle channel. Called by the battle server before it starts the battle scene.
  #
  # @param battle_id [String] The battle's id.
  # @param setup [Hash] The setup, see read_setup.
  def self.host(battle_id, setup)
    @server = true
    @setup = setup
    MGQ_MpOverworldSync::Me.take_seat(SERVER_SEAT)
    setup[:players].each { |player| remember_peer(player.seat, "name" => player.name) }
    setup[:switches].each { |id| $game_switches[id] = true }
    setup[:variables].each { |id, value| $game_variables[id] = value }
    $game_map.setup(setup[:map]) if setup[:map] > 0
    MGQ_MpBattlesCoop.borrow_rates({ "rates" => setup[:rates] })
    MGQ_MpRaidTiers.note_invite({ "troop" => setup[:troop], MGQ_MpRaidTiers::INVITE_FIELD => "1" }) if setup[:tiers] && defined?(MGQ_MpRaidTiers)
    BattleManager.setup(setup[:troop], setup[:escape], setup[:lose])
    MGQ_MpRaidPool.serve_fight(setup[:troop], setup[:pool]) if setup[:pool] && defined?(MGQ_MpRaidPool)
    seats = setup[:players].map(&:seat)
    MGQ_MpBattlesSync.serve_over_channel(:host, battle_id, seats, "the players")
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    open(battle_id)
    log("hosts battle #{battle_id} against troop #{setup[:troop]} for #{seats.size} players on seats #{seats.join(', ')}")
  end

  # As the battle server, waits for the players to come onto the battle channel, then starts the
  # battle the starter gathered: the roster, the level and the party, as the starter would have.
  # Called by MGQ_MpBattlesCoop.gather in place of its own wait for the players.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of battles_sync's Channel.ending, nil once the battle may start.
  def self.host_gather(scene)
    seats = @setup[:players].map(&:seat)
    frames = 0
    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Waiting for the players...") do
      frames += 1
      drain
      (seats - arrived).empty? || frames >= ARRIVE_FRAMES ? true : nil
    end
    return answer if answer.is_a?(Symbol)

    missing = seats - arrived
    log("#{arrived.size} of #{seats.size} players came onto the battle channel#{missing.empty? ? '' : ", not seats #{missing.join(', ')}"}")
    MGQ_MpBattlesSync.keep_seats(seats - missing)
    MGQ_MpBattlesCoop.take_troop(scene, @setup[:enemies])
    MGQ_MpBattlesCoop.start_battle(scene, @setup[:players], @setup[:level])
    nil
  end

  # The battle channel through the DLL; on the battle server, through its stand-in for the DLL.
  module Link
    # Asks the relay to start a battle on its battle server.
    #
    # @param world [String] The world's directory id.
    # @param battle_id [String] The battle's id.
    # @param seats [Array<Integer>] The world seats of its players, who alone may come onto its channel.
    # @param setup [String] What the server needs to host it, see setup_text.
    # @return [Boolean] Whether the DLL started asking.
    def self.serve(world, battle_id, seats, setup)
      MGQ_Multiplayer::Link.function('mp_battle_serve').call(world + "\0", battle_id + "\0", seats.join(",") + "\0", setup + "\0") == 1
    end

    # Opens the battle channel of a battle the relay started.
    #
    # @param world [String] The world's directory id.
    # @param battle_id [String] The battle's id.
    # @return [Boolean] Whether the DLL started opening it.
    def self.open(world, battle_id)
      MGQ_Multiplayer::Link.function('mp_battle_open').call(world + "\0", battle_id + "\0") == 1
    end

    # Sends a message over the battle channel.
    #
    # @param seat [Integer] The seat it goes to, EVERYONE for every other one.
    # @param text [String] The message.
    # @return [Boolean] Whether it went out.
    def self.send_to(seat, text)
      MGQ_Multiplayer::Link.function('mp_battle_send').call(seat, text + "\0") == 1
    end

    # Hands out the oldest entry of the battle channel.
    #
    # @return [Hash, nil] The entry, see MGQ_MpBattlesServed.take; nil while none waits.
    def self.next_entry
      text = MGQ_Multiplayer::Link.read('mp_battle_receive', ENTRY_SIZE)
      text.empty? ? nil : MGQ_Multiplayer::Link.parse(text)
    end

    # Reads how the battle stands on the relay and its channel.
    #
    # @return [Hash] "state" ("idle", "serving", "served", "refused", "opening", "open" or
    #   "closed"), "code" for a refusal or a close.
    def self.state
      text = MGQ_Multiplayer::Link.read('mp_battle_state', STATE_SIZE)
      text.empty? ? { "state" => "idle" } : MGQ_Multiplayer::Link.parse(text)
    end

    # Closes the battle channel.
    def self.close
      MGQ_Multiplayer::Link.function('mp_battle_close').call
    end
  end
end

# What this script takes part in of the world, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_leave { |peer| MGQ_MpBattlesServed.peer_left(peer) }
rescue => e
  MGQ_MpBattlesServed.log("overworld sync FAILED: #{e.class}: #{e.message}")
end
