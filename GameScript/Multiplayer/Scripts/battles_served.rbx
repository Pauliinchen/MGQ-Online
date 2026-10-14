#----------------------------------------------------------------
#  battles_served.rbx
#
#  Changelog:
#      Paulinchen  2026-10-15: Handed the battle server how the battle's boss fights, by pools or by tier
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
  end

  # Sends a message of the battle over the battle channel: a guest's to the server, the server's
  # to the battle's players.
  #
  # @param seats [Array<Integer>] The seats it goes to.
  # @param kind [String] What it is.
  # @param body [String] The rest.
  # @return [Array<Integer>] The seats it reached.
  def self.post(seats, kind, body)
    text = MGQ_MpOverworldSync::Me.encode({ "battle" => kind, "bid" => MGQ_MpBattlesSync.battle_id }) + body.to_s
    seats.select { |seat| Link.send_to(seat, text) }
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
      MGQ_MpBattlesSync.take_served(seat, message)
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
  # troop's events read, and how its boss fights: a Raid World's pools or a tier.
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
                                  defined?(MGQ_MpRaidTiers) && MGQ_MpRaidTiers.fight ? 1 : 0])
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
  #   MGQ_MpRaidPool.served_fields) and :tiers; nil for a setup of another format.
  def self.read_setup(text)
    format, scripts, data, troop, escape, lose, map, rates, enemies, players, level, switches, variables, raid, pool, tiers = MGQ_MpBattlesSync::Wire.parse(text.to_s)
    return nil unless format == FORMAT && troop.is_a?(Integer)

    { :scripts => scripts.to_s, :data => data.to_s,
      :troop => troop, :escape => escape == 1, :lose => lose == 1, :map => map.to_i, :rates => rates.to_s,
      :enemies => Array(enemies), :players => MGQ_MpBattlesCoop::Player.read_all(Array(players)),
      :level => level.is_a?(Integer) && level > 0 ? level : nil,
      :switches => Array(switches).select { |id| id.is_a?(Integer) && id > 0 },
      :variables => Array(variables).select { |pair| pair.is_a?(Array) && pair.size == 2 && pair.all? { |value| value.is_a?(Integer) } },
      :raid => raid == 1, :pool => pool.is_a?(Array) ? pool : nil, :tiers => tiers == 1 }
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
