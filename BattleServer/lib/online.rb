#----------------------------------------------------------------
#  online.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# MGQ Online on the battle server: its scripts load from the game folder's Patch folder like any
# other mod, as in the game (see boot.rb), but without the DLL. This takes the DLL's place for
# the battle channel, which the relay carries to the server, and makes MGQ Online's log the
# server's.
module Online
  # Bytes of a log line MGQ Online writes that the server's log keeps.
  LOG_LINE_BYTES = 2_000

  # Exports that answer nothing on the server, logged the first time each is called.
  @unanswered = {}

  class << self
    # The battle channel's other end: the relay, or a test's stand-in.
    attr_reader :bridge

    # Puts the server's stand-ins in place, once the game's scripts and MGQ Online loaded, and
    # runs the hooks MGQ Online's scripts install as the game starts.
    #
    # @param log [IO] Where MGQ Online's log goes.
    def install(log = $stderr)
      raise "MGQ Online did not load: the game folder's Patch folder has no Multiplayer.rb" unless defined?(MGQ_Multiplayer::Link)

      @log = log
      MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| Online.write_log(line) }
      MGQ_Multiplayer::Log.define_singleton_method(:flush) { nil }
      MGQ_Multiplayer.define_singleton_method(:available?) { true }
      MGQ_Multiplayer::Link.define_singleton_method(:function) { |name| Online.function(name) }
      start_game
    end

    # Hands the battle channel to a bridge: what the server sends goes there, what it takes comes
    # from there.
    #
    # @param bridge [#send_to, #next_entry, #close] The other end, see Bridge.
    def connect(bridge)
      @bridge = bridge
    end

    # Writes a line of MGQ Online's log.
    #
    # @param line [String] The line.
    def write_log(line)
      @log.puts("[mgq] #{line.to_s.byteslice(0, LOG_LINE_BYTES)}")
    end

    # The stand-in for an export of the DLL.
    #
    # @param name [String] The export.
    # @return [#call] What its calls do.
    def function(name)
      case name
      when "mp_battle_open" then ->(_world, _battle_id) { 1 }
      when "mp_battle_send" then ->(seat, text) { @bridge && @bridge.send_to(seat, text.chomp("\0")) ? 1 : 0 }
      when "mp_battle_receive" then reader { @bridge && @bridge.next_entry }
      when "mp_battle_state" then reader { @bridge && !@bridge.closed? ? "state=open" : "state=closed" }
      when "mp_battle_close" then -> { @bridge&.close; 1 }
      else unanswered(name)
      end
    end

    private

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

    # An export that writes a text into the caller's buffer, as the DLL's read exports do: the
    # text's length, its negative length when the buffer is too small, which keeps the text for
    # the next call, or 0 for none.
    #
    # @yieldreturn [String, nil] The next text.
    # @return [#call] The export.
    def reader(&take)
      kept = nil
      lambda do |buffer, size|
        text = kept || take.call
        kept = nil
        return 0 if text.nil? || text.empty?

        bytes = text.b
        if bytes.bytesize > size
          kept = text
          return -bytes.bytesize
        end
        buffer.force_encoding("ASCII-8BIT")[0, bytes.bytesize] = bytes
        bytes.bytesize
      end
    end

    # An export the server does not answer: it does nothing and answers 0, which the scripts take
    # as a call that did nothing, and writes nothing into a buffer.
    #
    # @param name [String] The export.
    # @return [#call] The export.
    def unanswered(name)
      unless @unanswered[name]
        @unanswered[name] = true
        write_log("server: #{name} answers nothing on the battle server")
      end
      ->(*) { 0 }
    end
  end

  # The battle channel's other end inside the server's process, which a test or the relay's
  # connection fills: the entries the server takes, what it sends, and whether it closed.
  class Bridge
    # What the server sent, each [seat, text], oldest first.
    attr_reader :sent

    # Starts an empty bridge.
    def initialize
      @entries = Queue.new
      @sent = Queue.new
      @closed = false
    end

    # Hands the server an entry, as the DLL would: a player's message, coming or going, or the
    # channel's end.
    #
    # @param kind [String] "message", "in", "out" or "closed".
    # @param seat [Integer] The player's world seat.
    # @param payload [String] A message's text.
    def push(kind, seat, payload = nil)
      text = "kind=#{kind}\nseat=#{seat}\n\n"
      text += payload.to_s if payload
      @entries << text
    end

    # Takes the next entry, see push.
    #
    # @return [String, nil] The entry as the DLL writes it, nil while none waits.
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
