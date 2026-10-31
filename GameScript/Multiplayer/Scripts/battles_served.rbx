#----------------------------------------------------------------
#  battles_served.rbx
#
#  Changelog:
#      Paulinchen  2026-10-31: Told the starter the front state again once a player comes onto the battle channel
#                            - Handed the setup's Strings to C# as text
#                            - Worded what the player reads plainly, leaving causes and internals to the log
#      Paulinchen  2026-10-30: Carried the widths of the troop's pictures in the setup, which the battle server places joining enemies by
#                            - Wrote, read and checked the setup and the scripts' fingerprint through C#
#                            - Read a setup's mods without C# for the battle server's child before its core opens
#                            - Left the serve's time-out, the refusals that last the session, the channel's opening and the starter's front to the DLL
#      Paulinchen  2026-10-23: Asked no battle server again in a session once one lacked its core library
#                            - Read a setup's squad rules and their defaults through the DLL or the core library
#                            - Kept the squad rules of a Raid World that names none for the battle server itself
#                            - Handed a player's drop from the battle channel to the presence of the players on the server
#      Paulinchen  2026-10-15: Handed the battle server how the battle's boss fights, by pools or by tier
#                            - Stood in for the battle server in the world's room as its starter, for players who join late
#                            - Named the world's mods the starter runs and its options of them in the setup
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

  # What starts this script's lines in the log.
  LOG_TAG = "served battle"

  # The battle server's seat on a battle channel, which no world seat reaches.
  SERVER_SEAT = 250

  # The seat a message to everyone on the battle channel names.
  EVERYONE = -1

  # The setup's format, as C# writes it (MGQOnline.Game's ServedSetup.Format), which mods_in reads
  # without C#.
  FORMAT = 1

  # The place of the world's mods among a setup's fields.
  MODS_FIELD = 18

  # The topic that writes the setup from the starter's facts (MGQOnline.Game's ServedSetup).
  SETUP_WRITE_TOPIC = "served.setup.write"

  # The topic that reads a setup back; a setup of another format reads as none.
  SETUP_READ_TOPIC = "served.setup.read"

  # The topic that tells why the battle server refuses a setup.
  SETUP_CHECK_TOPIC = "served.setup.check"

  # The topic that finds the scripts' fingerprint.
  FINGERPRINT_TOPIC = "served.fingerprint"

  # The topic that reads the squad rules a setup carries, with the defaults for those it lacks;
  # the DLL answers it in the game, the core library on the battle server.
  SQUAD_SERVED_TOPIC = "squad.served"

  # The topic that tells the squad rules of a Raid World that names none.
  SQUAD_DEFAULT_TOPIC = "squad.default"

  # Frames the battle server waits for every player to come onto the battle channel before the
  # battle starts without those who did not.
  ARRIVE_FRAMES = 600

  # Bytes the DLL may write an entry of the battle channel into at first.
  ENTRY_SIZE = 4_096

  # Bytes the DLL may write the battle channel's state into at first.
  STATE_SIZE = 1_024

  # The code of the channel's end the DLL gives a channel that did not open in time.
  OPEN_TIMEOUT_CODE = "open_timeout"

  # The DLL's topic that tells whether the starter passes a co-op message on to the battle server,
  # being its front in the world's room: other players' requests to join the battle with an
  # encounter (hot) or by choice (pick), and their taking one back (off).
  FRONTS_TOPIC = "served.fronts"

  # The DLL's topic that passes such a request on to the battle server.
  FORWARD_TOPIC = "served.forward"

  # The DLL's topic that tells the battle server a player left the world.
  LEFT_TOPIC = "served.left"

  # The DLL's topic that hands out the fields of the server's state the starter tells as its own.
  FRONT_STATE_TOPIC = "served.front_state"

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
  # DLL is there, and the relay has not refused in a way that lasts the session (the DLL's
  # "lasting").
  #
  # @return [Boolean] Whether it may.
  def self.available?
    return false if server?

    MGQ_Multiplayer.available? && MGQ_MpOverworldSync.in_world? && Link.state["lasting"].to_s.empty?
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

    # The DLL refuses a serve the relay does not answer within five seconds itself.
    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Starting the battle...") do
      state = Link.state
      if state["state"] == "served" then true
      elsif state["state"] == "refused" then [:refused, state["code"].to_s]
      end
    end
    unless answer == true
      code = answer.is_a?(Array) ? answer[1] : answer.to_s
      lasting = !Link.state["lasting"].to_s.empty?
      log("the server did not take battle #{battle_id} (#{code}): the starter hosts it" + (lasting ? ", and every later battle of this session" : ""))
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
    peer = world_seat?(seat) && MGQ_MpBattlesSync.peer_at(seat)
    MGQ_MpBattlesSync::Departures.left(peer) if peer
  end

  # Moves what came over the battle channel to the battle: messages, players coming and going, and
  # the channel's end, which the DLL also gives a channel that did not open in time. Called as the
  # battle's messages are taken.
  def self.drain
    return unless @channel

    while (entry = Link.next_entry)
      take(entry)
    end
    return unless @channel == :opening && Link.state["state"] == "open"

    @channel = :open
    log("the battle channel is open")
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
      log("seat #{seat} came onto the battle channel")
      return unless server?

      MGQ_MpOverworldSync::Peers.come_back(seat)
      # The relay drops a send to a seat not yet on the channel, so the starter may have missed
      # the last front state; tell it again.
      @told_state = nil
    when "out"
      log("seat #{seat} left the battle channel")
      # On the server, which sits in no world's room, the channel tells the players' presence: away
      # for the world's grace, gone once it runs out (see MGQ_MpBattlesSync::Seats.presence).
      MGQ_MpOverworldSync::Peers.wait_for(seat) if server?
    when "closed"
      @channel = :closed
      log(entry["code"] == OPEN_TIMEOUT_CODE ? "the battle channel did not open within 10 s" : "the battle channel closed: #{entry['code']}")
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

  # Takes a message of the front on the server: a request the starter passed on or a player who
  # left the world. The starter's DLL takes the server's messages for the world's room and its
  # state itself.
  #
  # @param seat [Integer] Its sender's seat on the battle channel.
  # @param message [Hash] The message.
  def self.take_front(seat, message)
    if server?
      return log("ignored #{message['battle']} from seat #{seat}: only the starter is the front") unless seat == @setup[:starter]

      return front_in(message[:payload]) if message["battle"] == FRONT_IN
      return front_left(message[:payload]) if message["battle"] == FRONT_LEFT
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
    return false unless starter? && @channel == :open

    MGQ_Multiplayer::Bridge.call(FRONTS_TOPIC, "coop" => message["coop"].to_s, "bid" => message["bid"].to_s) == true
  end

  # As starter, passes a request to join the served battle on to the battle server through the
  # DLL, with the states of its player and of the players it brings along, as the world's room
  # told them.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asked.
  # @param message [Hash] The request.
  def self.forward(peer, message)
    seats = [peer.seat] + message["seats"].to_s.split(",").map(&:to_i)
    states = seats.uniq.map { |seat| MGQ_MpOverworldSync::Peers.at(seat) }.compact.map do |known|
      [known.seat, pairs(known.state.select { |key, _| FRONT_STATE_KEYS.include?(key) })]
    end
    fields = pairs(message.reject { |key, _| key.is_a?(Symbol) })
    reached = MGQ_Multiplayer::Bridge.call(FORWARD_TOPIC, "seat" => peer.seat, "states" => states, "fields" => fields) == true
    log("passed #{message['coop']} of #{MGQ_MpOverworldSync.who(peer)} on to the battle server#{reached ? '' : ' (not sent)'}")
  end

  # As starter, tells the battle server a player left the world, whom it may have taken in.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  def self.peer_left(peer)
    return unless starter? && @channel == :open

    MGQ_Multiplayer::Bridge.call(LEFT_TOPIC, "seat" => peer.seat)
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

  # As the battle server, tells the starter the fields of its state that the world's players read
  # to join the battle, whenever they changed. Called every FRONT_STATE_FRAMES frames.
  def self.tell_front_state
    return unless server? && @setup

    fields = defined?(MGQ_MpBattlesJoin) ? MGQ_MpBattlesJoin.state_fields.select { |key, _| FRONT_FIELDS.include?(key) } : {}
    return if fields == @told_state

    @told_state = fields
    post([@setup[:starter]], FRONT_STATE, MGQ_MpBattlesSync::Wire.line([pairs(fields)]))
  end

  # Tells the fields the starter of a served battle tells as its own in place of a script's, so
  # the world's players find the battle and join it through the starter.
  #
  # @param keys [Array<String>] The script's fields: "rb" and "rbh" of MGQ_MpBattlesHotjoin, or
  #   FRONT_FIELDS of MGQ_MpBattlesJoin.
  # @return [Hash, nil] The fields, nil unless the player is the starter of a served battle.
  def self.front_fields(keys)
    return nil unless starter? && @channel == :open

    told = MGQ_Multiplayer::Bridge.call(FRONT_STATE_TOPIC)
    fields = { "rb" => MGQ_MpBattlesSync.battle_id.to_s, "rbh" => MGQ_MpOverworldSync::Me.seat.to_s }.merge(told.is_a?(Hash) ? told : { "rbn" => 0 })
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

  # Lists the players who came onto the battle channel, as its state names them ("in"). Asked by
  # the server.
  #
  # @return [Array<Integer>] Their world seats.
  def self.arrived
    Link.state["in"].to_s.split(",").map(&:to_i)
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
  # the battle's front in the world's room, a Raid World's squad rules for the players who join
  # late, the world's mods the starter runs with their options, which the server runs too, and the
  # widths of the troop's pictures, which the server has none of to measure. The script collects
  # them, C# writes the line (SETUP_WRITE_TOPIC).
  #
  # @param players [Array<MGQ_MpBattlesCoop::Player>] The arranged players.
  # @param level [Integer, nil] The battle's level.
  # @return [String] The setup, a battle line; empty while the bridge does not answer.
  def self.setup_text(players, level)
    switches = []
    $game_switches.instance_variable_get(:@data).each_with_index { |on, id| switches << id if on == true }
    variables = []
    $game_variables.instance_variable_get(:@data).each_with_index do |value, id|
      variables << [id, value] if value.is_a?(Integer) && value != 0
    end
    squad = MGQ_MpWorld.squad
    entries = MGQ_MpBattlesCoop.troop_entries
    facts = { "scripts" => scripts_fingerprint, "data" => MGQ_MpWorld::GameData.fingerprint, "troop" => $game_troop.troop.id,
              "escape" => MGQ_MpGame.get(BattleManager, :can_escape) ? true : false, "lose" => MGQ_MpGame.get(BattleManager, :can_lose) ? true : false,
              "map" => $game_map.map_id, "rates" => MGQ_MpBattlesCoop.rates_text, "enemies" => entries,
              "players" => players.map(&:to_a), "level" => level, "switches" => switches, "variables" => variables, "raid" => MGQ_MpBattlesCoop.raid? ? true : false,
              "pool" => defined?(MGQ_MpRaidPool) ? MGQ_MpRaidPool.served_fields : nil, "tiers" => defined?(MGQ_MpRaidTiers) && MGQ_MpRaidTiers.fight ? true : false,
              "starter" => MGQ_MpOverworldSync::Me.seat, "squad" => squad && squad.map { |key, value| [key.to_s, value] },
              "mods" => defined?(MGQ_MpWorldMods) ? MGQ_MpWorldMods.served_mods : [], "settings" => defined?(MGQ_MpWorldMods) ? MGQ_MpWorldMods.served_settings : "",
              "widths" => defined?(MGQ_MpBattlesHotjoin) ? MGQ_MpBattlesHotjoin.widths_of(entries) : nil }
    MGQ_Multiplayer::Bridge.call(SETUP_WRITE_TOPIC, Hash[facts.map { |name, value| [name, plain_fact(value)] }]).to_s
  end

  # Turns a fact into values the bridge carries, which has no Floats or Symbols: each of those as a
  # one-key Hash C# writes back as one, a String as text, any other object as its text, as the
  # battle line wrote it.
  #
  # The game's Ruby leaves some Strings as bytes, such as an empty join, which C# refuses where it
  # reads a text.
  #
  # @param value [Object] The fact.
  # @return [Object] nil, true, false, an Integer, a String, {"float" => its text}, {"symbol" =>
  #   its name} or an Array of these.
  def self.plain_fact(value)
    case value
    when nil, true, false, Integer then value
    when String then value.dup.force_encoding("UTF-8")
    when Float then { "float" => value.to_s }
    when Symbol then { "symbol" => value.to_s }
    when Array then value.map { |item| plain_fact(item) }
    else value.to_s
    end
  end

  # Finds what this game's MGQ Online scripts are, once per session: a checksum of every script in
  # Multiplayer.rb's order, the line ends left out, which a server with other scripts would host
  # by another protocol. C# sums them (FINGERPRINT_TOPIC).
  #
  # @return [String] The checksum, empty when a script could not be read.
  def self.scripts_fingerprint
    return @scripts_fingerprint if @scripts_fingerprint

    scripts = MGQ_Multiplayer::SCRIPTS.map do |name|
      [name, File.open(MGQ_Multiplayer.path("#{MGQ_Multiplayer::SCRIPTS_DIR}\\#{name}#{MGQ_Multiplayer::SCRIPT_EXTENSION}"), "rb") { |file| file.read }]
    end
    @scripts_fingerprint = MGQ_Multiplayer::Bridge.call(FINGERPRINT_TOPIC, scripts).to_s
  rescue => e
    log_once(:scripts_fingerprint, "reading the scripts failed: #{e.class}: #{e.message}")
    @scripts_fingerprint = ""
  end

  # Reads a setup as setup_text wrote it, through C# (SETUP_READ_TOPIC).
  #
  # @param text [String] The setup.
  # @return [Hash, nil] :scripts and :data (the starter's fingerprints), :troop, :escape, :lose,
  #   :map, :rates, :enemies, :players, :level, :switches, :variables, :raid, :pool (see
  #   MGQ_MpRaidPool.served_fields), :tiers, :starter, :squad (see MGQ_MpWorld.squad), :mods
  #   (each mod's key, kind, version and its files' hashes by path), :settings and :widths (the
  #   troop's, see setup_text; missing when the starter measured none); nil for a setup of another
  #   format.
  def self.read_setup(text)
    setup = MGQ_Multiplayer::Bridge.call(SETUP_READ_TOPIC, text.to_s)
    return nil unless setup.is_a?(Hash)

    read = {}
    setup.each { |key, value| read[key.to_sym] = value }
    read[:players] = MGQ_MpBattlesCoop::Player.read_all(read[:players])
    read[:squad] = squad_of(read[:squad])
    read
  end

  # Reads the world's mods a setup names without C#, for the battle server's child, which gets them
  # before its sandbox and so before it opens its core library.
  #
  # @param text [String] The setup.
  # @return [Array<Array>, nil] Each mod's key, kind (empty for one the server cannot get), version
  #   and files' hashes by path, those of another shape left out; nil for a setup of another format.
  def self.mods_in(text)
    fields = MGQ_MpBattlesSync::Wire.parse(text.to_s)
    return nil unless fields && fields[0] == FORMAT && fields[3].is_a?(Integer)

    Array(fields[MODS_FIELD]).map do |key, kind, version, files|
      next unless key.is_a?(String) && !key.empty? && kind.is_a?(String) && version.is_a?(String) && files.is_a?(Array)

      hashes = {}
      files.each { |path, hash| hashes[path] = hash if path.is_a?(String) && hash.is_a?(String) && hash =~ /\A[0-9a-f]{64}\z/ }
      [key, kind, version, hashes]
    end.compact
  end

  # Tells why the battle server refuses a setup, as C# checks it (SETUP_CHECK_TOPIC) against the
  # server's own scripts and game data.
  #
  # @param text [String] The setup.
  # @param troop_enemies [Boolean] Whether the setup's troop has enemies in the server's database.
  # @return [Array(String, String), nil] The refusal's code (setup, scripts or data) and why; nil
  #   for a setup the server hosts.
  def self.refusal_of(text, troop_enemies)
    refusal = MGQ_Multiplayer::Bridge.call(SETUP_CHECK_TOPIC, "text" => text.to_s, "scripts" => scripts_fingerprint,
                                                             "data" => MGQ_MpWorld::GameData.fingerprint, "troop_enemies" => troop_enemies ? true : false)
    refusal.is_a?(Array) ? refusal : nil
  end

  # Reads a Raid World's squad rules a setup carries, the defaults for those it lacks (see
  # default_squad).
  #
  # @param pairs [Array] The rules' [name, value] pairs a setup reads with.
  # @return [Hash, nil] The rules, as MGQ_MpWorld.squad tells them; nil for none, for rules out of
  #   range and while the bridge is closed, as on the battle server before its child's sandbox.
  def self.squad_of(pairs)
    MGQ_MpWorld.squad_from(MGQ_Multiplayer::Bridge.call(SQUAD_SERVED_TOPIC, Array(pairs)))
  end

  # Tells the squad rules of a Raid World that names none, which the battle server plays a Raid
  # World's battle by whose setup carries no rules.
  #
  # @return [Hash, nil] The rules, as MGQ_MpWorld.squad tells them; nil while the bridge does not
  #   answer.
  def self.default_squad
    MGQ_MpWorld.squad_from(MGQ_Multiplayer::Bridge.call(SQUAD_DEFAULT_TOPIC))
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
    MGQ_MpBattlesHotjoin.keep_widths(battle_id, setup[:widths]) if setup[:widths] && defined?(MGQ_MpBattlesHotjoin)
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
    #   "closed"), "code" for a refusal or a close, "lasting" once a refusal ended every later
    #   serve of the session, and on the battle server "in", the seats that came onto the channel.
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
