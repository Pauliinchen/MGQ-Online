#----------------------------------------------------------------
#  online.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Stood in for the battle channel's and the world room's ports of the scripts in place of the DLL's exports, the core writing and reading the messages
#                            - Handed the core's ledger the pools' word as the core read it from the relay's lines, and the reports to the relay as their texts
#      Paulinchen  2026-10-31: Started the game first, where the Mod Framework loads MGQ Online's title part, then entered it, which loads the rest
#                            - Dropped the stand-in for the deleted mp_raid_boss_report export
#      Paulinchen  2026-10-30: Named the seats that came onto and left the battle channel in its state, as the DLL's state does
#                            - Sent the reports of the core's outbox through the relay's connection
#                            - Handed the relay's word of the boss pools and the server's own reports to the core's ledger
#      Paulinchen  2026-10-15: Stood in for the boss pool exports
#                            - Sent the world room's messages through the battle's starter
#                            - Created
#
#----------------------------------------------------------------

# MGQ Online on the battle server: its scripts load from the game folder's Patch folder through the
# Mod Framework it ships inside, as in the game (see boot.rb), but without either DLL. This takes
# the DLL's place for the battle channel, the world room's sending and a Raid World's boss pools,
# which the relay carries to the server and the core's ledger keeps, and makes MGQ Online's log
# the server's. The core writes and reads the battle channel's messages (topics message.write and
# message.read), as the DLL does in the game.
module Online
  # Bytes of a log line MGQ Online writes that the server's log keeps.
  LOG_LINE_BYTES = 2_000

  # The core's topic that writes a message from its fields and body.
  WRITE_TOPIC = "message.write"

  # The core's topic that reads a message into its fields and body.
  READ_TOPIC = "message.read"

  class << self
    # The battle channel's other end: the relay, or a test's stand-in.
    attr_reader :bridge

    # Starts the game, where the Mod Framework loads MGQ Online's title part, enters the game
    # through the framework, which loads the rest of MGQ Online and runs the hooks its scripts
    # install as the game starts (a server never enters a game otherwise), and puts the server's
    # stand-ins in place.
    #
    # @param log [IO] Where MGQ Online's log goes.
    def install(log = $stderr)
      @log = log
      start_game
      raise "MGQ Online did not load: the game folder's Patch folder has no Multiplayer.rb or no Mod Framework" unless defined?(MGQ_Multiplayer::Bridge)

      MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| Online.write_log(line) }
      MGQ_Multiplayer::Log.define_singleton_method(:flush) { nil }
      MGQ_Multiplayer.define_singleton_method(:available?) { true }
      ::Mod_Framework::Mods.enter("the battle server")
      raise "MGQ Online did not load its battle scripts: the game folder's Patch folder holds an older MGQ Online" unless defined?(MGQ_MpBattlesServed::Port)

      stand_in_ports
    end

    # Hands the battle channel to a bridge: what the server sends goes there, what it takes comes
    # from there.
    #
    # @param bridge [#send_to, #next_entry, #close] The other end, see Bridge.
    def connect(bridge)
      @bridge = bridge
      @seats_in = []
      @seats_out = []
    end

    # Writes a line of MGQ Online's log.
    #
    # @param line [String] The line.
    def write_log(line)
      @log.puts("[mgq] #{line.to_s.byteslice(0, LOG_LINE_BYTES)}")
    end

    # Sends a message of the battle to players over the channel, written by the core.
    #
    # @param seats [Array<Integer>] Their world seats, -1 for every player.
    # @param kind [String] What it is.
    # @param battle_id [String] The battle's id.
    # @param body [String] The rest.
    # @return [Array<Integer>] The seats it went out to.
    def send_to(seats, kind, battle_id, body)
      text = MGQ_Multiplayer::Bridge.call(WRITE_TOPIC, "fields" => { "battle" => kind, "bid" => battle_id }, "body" => body)
      return [] unless @bridge && text.is_a?(String)

      seats.select { |seat| @bridge.send_to(seat, text) }
    end

    # Takes what came over the channel, each message read by the core, as the DLL hands it.
    #
    # @return [Array<Hash>] The entries, oldest first: "kind" ("in", "out", "message" or
    #   "closed"), "seat", "code" for closed, and a message's "fields" and "body".
    def entries
      taken = []
      while @bridge && (entry = @bridge.next_entry)
        note_seat(entry)
        taken << read_message(entry)
      end
      taken
    end

    # Tells how the channel stands, as the DLL's state does.
    #
    # @return [Hash] "state" ("open" or "closed"), and the seats that came onto the channel
    #   ("in") and left it ("out").
    def state
      { "state" => @bridge && !@bridge.closed? ? "open" : "closed", "in" => @seats_in.to_a.dup, "out" => @seats_out.to_a.dup }
    end

    # Hands the core's ledger what the relay told of the pools since, before the scripts read them.
    def flush_pools
      @bridge&.bosses&.flush(world_id)
    end

    # Sends the reports the core's fight left in its outbox (MGQOnline.Game's PoolOutbox), which
    # counted them in its ledger already, through the relay's connection.
    def send_reports
      return unless @bridge

      Array(MGQ_Multiplayer::Bridge.call(BossPools::REPORTS_TOPIC)).each do |_world, key, battle, text|
        @bridge.report(key.to_s, battle.to_s, text.to_s)
      end
    end

    private

    # Puts the scripts' ports of the battle channel and the world room's sending on the server's
    # stand-ins: the server opens no channel itself and sits in no world room, so the battle's
    # starter passes its messages for the world room on.
    def stand_in_ports
      port = MGQ_MpBattlesServed::Port
      port.define_singleton_method(:serve) { |*| false }
      port.define_singleton_method(:open) { |_world, _battle_id| true }
      port.define_singleton_method(:send_to) { |seats, kind, battle_id, body| Online.send_to(seats, kind, battle_id, body) }
      port.define_singleton_method(:entries) { Online.entries }
      port.define_singleton_method(:state) { Online.state }
      port.define_singleton_method(:close) { Online.bridge && Online.bridge.close }
      MGQ_MpOverworldSync::Port.define_singleton_method(:send_to) { |seat, fields, body| MGQ_MpBattlesServed.front_out(seat, fields, body) }
    end

    # Notes the seat of a player who came onto the battle channel or left it, as its entry passes
    # to the scripts: those who came stay named, those who left only until they come back.
    #
    # @param entry [Hash] The entry.
    def note_seat(entry)
      kind = entry["kind"]
      return unless kind == "in" || kind == "out"

      seat = entry["seat"].to_i
      (@seats_in ||= []) << seat if kind == "in" && !@seats_in.to_a.include?(seat)
      @seats_out = @seats_out.to_a - [seat]
      @seats_out << seat if kind == "out"
    end

    # Reads a message's text into its fields and body through the core, as the DLL hands an entry
    # to the scripts.
    #
    # @param entry [Hash] The entry, a message's "text" with it.
    # @return [Hash] The entry, a message's "fields" and "body" in place of its text.
    def read_message(entry)
      taken = entry.reject { |key, _| key == "text" }
      return taken unless entry["kind"] == "message"

      read = MGQ_Multiplayer::Bridge.call(READ_TOPIC, entry["text"].to_s)
      taken.merge("fields" => read.is_a?(Hash) ? read["fields"] : {}, "body" => read.is_a?(Hash) ? read["body"].to_s : "")
    end

    # Names the world as MGQ Online's raid pools read it on the server, which the pools' state
    # must name for them to take it.
    #
    # @return [String] The world's id, empty on the server.
    def world_id
      defined?(MGQ_MpWorldStory) ? MGQ_MpWorldStory.world_id.to_s : ""
    end

    # Starts MGQ Online as the game's start would: runs SceneManager.run with the hooks the
    # scripts put on it, such as the battle scripts' installs, but no title screen.
    def start_game
      first = SceneManager.method(:first_scene_class)
      none = Class.new { def main; SceneManager.instance_variable_set(:@scene, nil); end }
      SceneManager.define_singleton_method(:first_scene_class) { none }
      SceneManager.run
    ensure
      SceneManager.define_singleton_method(:first_scene_class, first) if first
    end
  end

  # What the relay tells the server of a Raid World's boss pools while it hosts a battle that
  # fights them, as the core read the relay's lines: it waits here until the scripts read the pools,
  # then goes to the core's ledger (MGQOnline.Game's PoolTopics), which the scripts read as the DLL's.
  class BossPools
    # The core's topic that takes what the relay told of a pool.
    HEARD_TOPIC = "raid.pool.heard"

    # The core's topic that hands out the reports its fight left for the relay.
    REPORTS_TOPIC = "raid.pool.reports"

    # Starts with nothing told.
    def initialize
      @told = Queue.new
    end

    # Keeps what the relay told of a pool for the next flush: the answer to one of the server's
    # reports, or another battle's change.
    #
    # @param entry [Hash] The boss entry the core read of the relay's line (RelayLineTopics.Read):
    #   "key", "left", "max", "defeated", "by" and "answer", as HEARD_TOPIC takes them.
    def take(entry)
      @told << entry
    end

    # Hands the core's ledger what the relay told since the last flush, oldest first.
    #
    # @param world [String] The world's id the game's scripts expect.
    def flush(world)
      while (entry = next_told)
        MGQ_Multiplayer::Bridge.call(HEARD_TOPIC, entry.reject { |key, _| key == "kind" }.merge("world" => world))
      end
    end

    private

    # Takes the oldest word told and not handed on yet.
    #
    # @return [Hash, nil] The word, nil while none waits.
    def next_told
      @told.pop(true)
    rescue ThreadError
      nil
    end
  end

  # The battle channel's other end inside the server's process, which a test fills: the entries the
  # server takes, what it sends, the boss reports, and whether it closed.
  class Bridge
    # What the server sent, each [seat, text], oldest first.
    attr_reader :sent

    # The boss reports the server made, each [key, battle, report], oldest first.
    attr_reader :reports

    # What the relay told of the boss pools, which a test tells as the relay would.
    attr_reader :bosses

    # The world seats the server let onto the channel late, oldest first.
    attr_reader :admitted

    # Starts an empty bridge.
    def initialize
      @entries = Queue.new
      @sent = Queue.new
      @reports = Queue.new
      @bosses = BossPools.new
      @admitted = []
      @closed = false
    end

    # Lets players the battle takes in late onto the channel.
    #
    # @param seats [Array<Integer>] Their world seats.
    # @return [Boolean] Whether the channel is open.
    def admit(seats)
      @admitted.concat(seats)
      !@closed
    end

    # Takes a boss report of the server.
    #
    # @param key [String] The pool's key.
    # @param battle [String] The battle's id the report counts under.
    # @param text [String] The report as the core's fight left it.
    # @return [Boolean] true.
    def report(key, battle, text)
      @reports << [key, battle, text]
      true
    end

    # Hands the server an entry, as the relay would: a player's message, coming or going, or the
    # channel's end.
    #
    # @param kind [String] "message", "in", "out" or "closed".
    # @param seat [Integer] The player's world seat.
    # @param payload [String] A message's text.
    def push(kind, seat, payload = nil)
      @entries << { "kind" => kind, "seat" => seat, "text" => payload.to_s }
    end

    # Takes the next entry, see push.
    #
    # @return [Hash, nil] The entry: "kind", "seat", "code" for closed and a message's "text"; nil
    #   while none waits.
    def next_entry
      @entries.pop(true)
    rescue ThreadError
      nil
    end

    # Takes what the server sends.
    #
    # @param seat [Integer] The seat it goes to, -1 for everyone.
    # @param text [String] The message.
    # @return [Boolean] true while open.
    def send_to(seat, text)
      return false if @closed

      @sent << [seat, text]
      true
    end

    # Ends the channel.
    def close
      @closed = true
    end

    # Tells whether the channel ended.
    #
    # @return [Boolean] Whether it did.
    def closed?
      @closed
    end
  end
end
