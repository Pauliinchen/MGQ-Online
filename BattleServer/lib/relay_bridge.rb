#----------------------------------------------------------------
#  relay_bridge.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Handed the relay's entries over as values, which the core reads the messages of
#                            - Had the core write and read the channel's lines, the reading thread only queuing them
#      Paulinchen  2026-10-30: Kept what the relay told of the boss pools for the core's ledger
#      Paulinchen  2026-10-15: Reported boss pools to the relay and kept what it told of them
#                            - Let the players a battle takes in late onto its channel
#                            - Created
#
#----------------------------------------------------------------

require "json"
require_relative "online"

# The battle channel's other end over the relay's connection to the battle server: one JSON object
# per line each way, which the core writes and reads (MGQOnline.ServerCore's RelayLineTopics). The
# relay sends who comes and goes, the players' messages, its word of the boss pools and the
# channel's close; the server sends its messages to the players, that it serves or refuses the
# battle, its boss reports, the players it takes in late and the battle's end.
#
# The core may be called from one Ruby thread only (its calls release the GVL and the bridge keeps
# one reply buffer), so the reading thread only queues the relay's lines and the game's thread reads
# them through the core as it takes the entries.
class RelayBridge
  # Bytes a line from the relay may take, a player's largest message in base64 with room to spare.
  MAX_LINE = 1024 * 1024

  # The core's topic that writes a line of the server.
  WRITE_TOPIC = "relay.line.write"

  # The core's topic that reads a line of the relay into an entry.
  READ_TOPIC = "relay.line.read"

  # What the reading thread queues once the connection ended.
  LINES_END = :end

  # The entry of the channel's end once the connection ended.
  CLOSED = { "kind" => "closed", "seat" => 0, "code" => "relay" }.freeze

  # Starts the bridge on the relay's connection, reading it on a thread of its own.
  #
  # @param socket [IO] The connection.
  def initialize(socket)
    @socket = socket
    @lines = Queue.new
    @entries = []
    @lock = Mutex.new
    @closed = false
    @ended = false
    @bosses = Online::BossPools.new
    @reader = Thread.new { read }
  end

  # What the relay told of the boss pools, for the core's ledger, see Online::BossPools; its lines
  # read up to now.
  #
  # @return [Online::BossPools] The pools' word.
  def bosses
    take_lines
    @bosses
  end

  # Lets players the battle takes in late onto the channel: the relay admits whoever sits on those
  # seats of the world room now.
  #
  # @param seats [Array<Integer>] Their world seats.
  # @return [Boolean] Whether it went out.
  def admit(seats)
    return false if @closed || seats.empty?

    tell("op" => "admit", "seats" => seats)
  end

  # Reports what the battle did to a Raid World's boss pool; the relay answers with the pool.
  #
  # @param key [String] The pool's key.
  # @param battle [String] The battle's id the report counts under.
  # @param text [String] The report as the core's fight left it.
  # @return [Boolean] Whether it went out; a report the core cannot read does not.
  def report(key, battle, text)
    tell("op" => "boss_report", "key" => key, "battle" => battle, "report" => text)
  end

  # Takes the next entry, see Online::Bridge#next_entry.
  #
  # @return [Hash, nil] The entry, nil while none waits.
  def next_entry
    take_lines
    @entries.shift
  end

  # Sends a message to a player, or to every player with -1.
  #
  # @param seat [Integer] The seat.
  # @param text [String] The message.
  # @return [Boolean] Whether it went out.
  def send_to(seat, text)
    return false if @closed

    tell("op" => "send", "seat" => seat, "text" => text)
  end

  # Tells the relay something of the battle, such as that it is served or how it ended; also once
  # the channel closed, until the connection does.
  #
  # @param fields [Hash] "op" and the line's fields, see RelayLineTopics.Write.
  # @return [Boolean] Whether it went out.
  def tell(fields)
    line = line_of(fields)
    line ? put(line) : false
  end

  # Writes a line through the core without sending it, for a thread that may not call the core.
  #
  # @param fields [Hash] "op" and the line's fields.
  # @return [String, nil] The line, nil when the core wrote none.
  def line_of(fields)
    line = MGQ_Multiplayer::Bridge.call(WRITE_TOPIC, fields)
    line.is_a?(String) ? line : nil
  end

  # Refuses the battle while this thread may not call the core: the server has none or no MGQ
  # Online, or another thread's battle holds it. The line is written here, the one Ruby writes.
  #
  # @param code [String] Why, such as "core".
  # @param error [String] Why, for the battle's starter.
  # @return [Boolean] Whether it went out.
  def refuse_without_core(code, error)
    put(JSON.generate("op" => "refused", "code" => code, "error" => error))
  end

  # Sends a line written already.
  #
  # @param line [String] The line.
  # @return [Boolean] Whether it went out.
  def put(line)
    return false if @socket.closed?

    @lock.synchronize { @socket.puts(line) }
    true
  rescue IOError, SystemCallError
    @closed = true
    false
  end

  # Ends the channel; the relay closes the players' ends.
  def close
    @closed = true
  end

  # Tells whether the channel ended, from either side.
  #
  # @return [Boolean] Whether it did.
  def closed?
    @closed
  end

  private

  # Queues the relay's lines until the connection ends.
  def read
    while (line = @socket.gets(MAX_LINE))
      @lines << line
    end
  rescue IOError, SystemCallError
    nil
  ensure
    @lines << LINES_END
  end

  # Reads the queued lines through the core into entries and the pools' word, up to the channel's
  # end.
  def take_lines
    while !@ended && (line = next_line)
      entry = line.equal?(LINES_END) ? CLOSED : MGQ_Multiplayer::Bridge.call(READ_TOPIC, line)
      next unless entry.is_a?(Hash)

      case entry["kind"]
      when "boss" then @bosses.take(entry)
      when "closed" then end_channel(entry)
      else @entries << entry
      end
    end
  end

  # Takes the oldest line the reading thread queued.
  #
  # @return [String, Symbol, nil] The line, LINES_END, or nil while none waits.
  def next_line
    @lines.pop(true)
  rescue ThreadError
    nil
  end

  # Ends the channel from the relay's side.
  #
  # @param entry [Hash] The closed entry, which the scripts take last.
  def end_channel(entry)
    @entries << entry
    @ended = true
    @closed = true
  end
end
