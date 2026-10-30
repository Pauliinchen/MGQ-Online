#----------------------------------------------------------------
#  online.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Named the seats that came onto and left the battle channel in its state, as the DLL's state does
#                            - Sent the reports of the core's outbox through the relay's connection
#                            - Handed the relay's word of the boss pools and the server's own reports to the core's ledger
#      Paulinchen  2026-10-15: Stood in for the boss pool exports
#                            - Sent the world room's messages through the battle's starter
#                            - Created
#
#----------------------------------------------------------------

# MGQ Online on the battle server: its scripts load from the game folder's Patch folder like any
# other mod, as in the game (see boot.rb), but without the DLL. This takes the DLL's place for
# the battle channel and a Raid World's boss pools, which the relay carries to the server and the
# core's ledger keeps, and makes MGQ Online's log the server's.
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
      @seats_in = []
      @seats_out = []
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
      when "mp_battle_receive" then reader { note_seat(@bridge && @bridge.next_entry) }
      when "mp_battle_state" then reader { "state=#{@bridge && !@bridge.closed? ? 'open' : 'closed'}\nin=#{@seats_in.to_a.join(',')}\nout=#{@seats_out.to_a.join(',')}" }
      when "mp_battle_close" then -> { @bridge&.close; 1 }
      # The server sits in no world room: the battle's starter passes its messages on there.
      when "mp_world_send" then ->(seat, text) { MGQ_MpBattlesServed.front_out(seat, text.chomp("\0")) ? 1 : 0 }
      # The starter's setup brings the pools, and the relay tells the server of each change.
      when "mp_raid_bosses_fetch" then ->(_world) { 1 }
      when "mp_raid_boss_report" then ->(_world, key, battle, text) { @bridge && @bridge.report(key.chomp("\0"), battle.chomp("\0"), text.chomp("\0")) ? 1 : 0 }
      else unanswered(name)
      end
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

    # Notes the seat of a player who came onto the battle channel or left it, as its entry passes
    # to the scripts: those who came stay named, those who left only until they come back.
    #
    # @param entry [String, nil] The entry.
    # @return [String, nil] The entry.
    def note_seat(entry)
      kind = entry.to_s[/\Akind=(in|out)\n/, 1]
      seat = entry.to_s[/^seat=(\d+)$/, 1]
      return entry unless kind && seat

      seat = seat.to_i
      (@seats_in ||= []) << seat if kind == "in" && !@seats_in.to_a.include?(seat)
      @seats_out = @seats_out.to_a - [seat]
      @seats_out << seat if kind == "out"
      entry
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

  # What the relay tells the server of a Raid World's boss pools while it hosts a battle that
  # fights them: its lines arrive on the bridge's reading thread and wait here until the game's
  # thread hands them to the core's ledger (MGQOnline.Game's PoolTopics), which the scripts read as
  # the DLL's.
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
    # @param fields [Hash] "key", "left" (the share of its max left), "max", "defeated", "by" and
    #   "answer"; an answer the relay refused names no "left".
    def take(fields)
      @told << fields
    end

    # Hands the core's ledger what the relay told since the last flush, oldest first.
    #
    # @param world [String] The world's id the game's scripts expect.
    def flush(world)
      while (fields = next_told)
        next if fields["key"].to_s.empty?

        MGQ_Multiplayer::Bridge.call(HEARD_TOPIC, request_of(fields, world))
      end
    end

    # Reads a report as MGQ Online's raid pools write it.
    #
    # @param text [String] "seq\tdelta\tmax\tkilled", see MGQ_MpRaidPool.report.
    # @return [Hash, nil] :seq, :delta, :max and :killed, nil for a report of another shape.
    def self.report_of(text)
      seq, delta, max, killed = text.to_s.split("\t")
      return nil unless seq.to_s.match?(/\A\d+\z/) && delta.to_s.match?(/\A-?\d+(\.\d+)?\z/) && max.to_s.match?(/\A\d+\z/)

      { seq: seq.to_i, delta: delta.to_f, max: max.to_i, killed: killed == "1" }
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

    # Writes the core's request of a word the relay told.
    #
    # @param fields [Hash] The word, see take.
    # @param world [String] The world's id.
    # @return [Hash] The request of HEARD_TOPIC.
    def request_of(fields, world)
      left = fields["left"]
      { "world" => world, "key" => fields["key"].to_s, "left" => left.is_a?(Numeric) ? left.to_f.to_s : nil, "max" => fields["max"].to_i,
        "defeated" => fields["defeated"] ? true : false, "by" => fields["by"].to_s, "answer" => fields["answer"] ? true : false }
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
    # @param text [String] The report, see BossPools.report_of.
    # @return [Boolean] Whether it was one.
    def report(key, battle, text)
      report = BossPools.report_of(text)
      return false unless report

      @reports << [key, battle, report]
      true
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
