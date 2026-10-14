#----------------------------------------------------------------
#  relay_bridge.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

require "json"

# The battle channel's other end over the relay's connection to the battle server: one JSON object
# per line each way. The relay sends who comes and goes and the players' messages, the server sends
# its messages to them; the texts travel in base64.
#
#   relay to server: {"op":"in","seat":3}, {"op":"out","seat":3},
#                    {"op":"message","seat":3,"text":"<base64>"}, {"op":"close"}
#   server to relay: {"op":"send","seat":3,"text":"<base64>"} (seat -1 for every player),
#                    {"op":"serving"}, {"op":"refused","code":"setup","error":"..."},
#                    {"op":"end","result":"victory","turns":4}
class RelayBridge
  # Bytes a line from the relay may take, a player's largest message in base64 with room to spare.
  MAX_LINE = 1024 * 1024

  # Starts the bridge on the relay's connection, reading it on a thread of its own.
  #
  # @param socket [IO] The connection.
  def initialize(socket)
    @socket = socket
    @entries = Queue.new
    @lock = Mutex.new
    @closed = false
    @reader = Thread.new { read }
  end

  # Takes the next entry, as the DLL writes it, see Online::Bridge#push.
  #
  # @return [String, nil] The entry, nil while none waits.
  def next_entry
    @entries.pop(true)
  rescue ThreadError
    nil
  end

  # Sends a message to a player, or to every player with -1.
  #
  # @param seat [Integer] The seat.
  # @param text [String] The message.
  # @return [Boolean] Whether it went out.
  def send_to(seat, text)
    return false if @closed

    tell(op: "send", seat: seat, text: [text].pack("m0"))
  end

  # Tells the relay something of the battle, such as that it is served or how it ended; also once
  # the channel closed, until the connection does.
  #
  # @param fields [Hash] The line's fields.
  # @return [Boolean] Whether it went out.
  def tell(fields)
    return false if @socket.closed?

    @lock.synchronize { @socket.puts(JSON.generate(fields)) }
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

  # Reads the relay's lines into entries until the connection or the channel ends.
  def read
    while (line = @socket.gets(MAX_LINE))
      fields = JSON.parse(line)
      seat = fields["seat"].to_i
      case fields["op"]
      when "in", "out" then @entries << "kind=#{fields['op']}\nseat=#{seat}\n\n"
      when "message" then @entries << "kind=message\nseat=#{seat}\n\n" + fields["text"].to_s.unpack1("m").force_encoding("UTF-8")
      when "close" then break
      end
    end
  rescue IOError, SystemCallError, JSON::ParserError
    nil
  ensure
    @entries << "kind=closed\nseat=0\ncode=relay\n\n"
    @closed = true
  end
end
