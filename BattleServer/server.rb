#----------------------------------------------------------------
#  server.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Refused battles by request while it hosts MGQ Online's battles
#                            - Hosted the co-op battles the relay hands over
#                            - Kept up to 1 MB of a child's output
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require "json"
require "socket"
require_relative "lib/boot"
require_relative "lib/session"
require_relative "lib/sandbox"
require_relative "lib/served"
require_relative "lib/relay_bridge"

# The battle server: it loads the game once and then plays battles for its clients over TCP, one
# JSON object per line each way. Requests:
#   {"op":"ping"}
#   {"op":"battle", "troop":1, "party":[[1,10]], "seed":1, "switches":{}, "variables":{}}
#       plays the battle to its end with the game's auto battle and answers the outcome; "save"
#       (a save file in base64) in place of "party" fights with the save's party and state.
#   {"op":"start", ...the same fields}
#       starts a battle played turn by turn and answers its first event.
#   {"op":"answer", "commands":{"1":[{"skill":23,"target":0}]}} or {"op":"answer", "choice":0}
#       answers the event the battle waits on and answers its next event.
# Every answer holds "ok", and "error" when it is false. The game's globals hold one battle per
# process: where the system can fork (Linux), each connection gets a child process of its own,
# which shares the loaded game with the others, is sandboxed when the server runs as root, and
# ends with the connection; elsewhere (Windows) the server plays one battle at a time and turns
# others away as busy. Saves from clients are checked before they are read (SaveCheck).
module BattleServer
  # The port the server listens on unless BATTLE_PORT names another.
  DEFAULT_PORT = 8095

  # How long each request may be, in bytes: a late game's save is about 3 MB, 4 MB in base64.
  MAX_REQUEST = 8 * 1024 * 1024

  # Child processes at once unless BATTLE_CHILDREN names another number.
  DEFAULT_CHILDREN = 64

  # CPU seconds a child may use, so a battle caught in a loop ends instead of taking a core.
  CHILD_CPU_SECONDS = 120

  # Bytes of a child's output the server's log takes: MGQ Online logs a co-op battle in detail.
  CHILD_OUTPUT = 1024 * 1024

  @slot = Mutex.new
  @busy = false
  @battles = 0

  class << self
    # Loads the game, then serves clients until stopped.
    def run
      boot_seconds = Boot.run
      # MGQ Online in the game folder makes this a server of its co-op battles; without it the
      # server plays the battles its requests describe. Their hooks never meet in one process.
      @served = defined?(MGQ_Multiplayer::Link) ? true : false
      @served ? ServedBattle.install : HeadlessBattle.install
      @boot_seconds = boot_seconds
      port = (ENV["BATTLE_PORT"] || DEFAULT_PORT).to_i
      server = TCPServer.new("127.0.0.1", port)
      # Worked out once here, so the children share it instead of each walking every class.
      SaveCheck.game_names
      @mode = (@served ? "MGQ Online co-op battles, " : "battles by request, ") + (forking? ? "fork" : "thread")
      @mode += Sandbox.available? ? ", sandboxed" : ", NOT sandboxed: for tests only" if forking?
      $stderr.puts(format("battle server ready on 127.0.0.1:%d after %.1f s (%s)", port, boot_seconds, @mode))
      if Sandbox.available? && !(open = Sandbox.writable_by_others(Boot::GAME_DIR)).empty?
        $stderr.puts("warning: battles could write into the game folder, which others than root may write to: " \
                     "#{open.join(", ")}; fix it with chmod -R go-w")
      end
      if forking?
        serve_forking(server)
      else
        loop { Thread.new(server.accept) { |client| serve(client) } }
      end
    end

    private

    # Tells whether each connection gets a child process of its own.
    #
    # @return [Boolean] Whether it does: where the system can fork, unless BATTLE_FORK is 0.
    def forking?
      Process.respond_to?(:fork) && ENV["BATTLE_FORK"] != "0"
    end

    # Hands each connection to a child process of its own, which plays its battles and ends with
    # it; past the most children at once, a connection is turned away as busy.
    #
    # @param server [TCPServer] The listening socket.
    def serve_forking(server)
      # Packs the loaded game tightly before the first fork, so more of it stays shared.
      Process.warmup
      # One waiting thread per child, which collects it the moment it ends.
      children = []
      most = (ENV["BATTLE_CHILDREN"] || DEFAULT_CHILDREN).to_i
      loop do
        client = server.accept
        children.select!(&:alive?)
        if children.size >= most
          client.puts(JSON.generate(busy))
          client.close
          next
        end
        output, child_output = IO.pipe
        # A game script takes Kernel's fork and exit! away, as it does the backtick.
        pid = Process.fork do
          server.close
          output.close
          # A sandboxed child may write no file, the server's log included, so its output goes
          # through a pipe the parent copies into the log.
          $stdout.reopen(child_output)
          $stderr.reopen(child_output)
          Process.setrlimit(:CPU, CHILD_CPU_SECONDS)
          begin
            Sandbox.enter(Boot::GAME_DIR) if Sandbox.available?
          rescue StandardError => e
            # A child the sandbox could not close in never plays.
            client.puts(JSON.generate(ok: false, error: "the battle could not be sandboxed: #{e.message}"))
            Process.exit!(1)
          end
          serve(client)
          # The game's scripts never get to run exit handlers meant for Game.exe.
          Process.exit!(0)
        end
        child_output.close
        copy_output(output, pid)
        children << Process.detach(pid)
        client.close
      end
    end

    # Copies a child's output into the server's log, each line marked with the child, up to
    # CHILD_OUTPUT bytes so a child cannot fill the disk.
    #
    # @param output [IO] The pipe's end the child's output comes out of.
    # @param pid [Integer] The child.
    def copy_output(output, pid)
      Thread.new do
        left = CHILD_OUTPUT
        output.each_line do |line|
          next if left <= 0

          left -= line.bytesize
          $stderr.write("[#{pid}] #{line}")
          $stderr.write("[#{pid}] output past #{CHILD_OUTPUT} bytes is dropped\n") if left <= 0
        end
      ensure
        output.close
      end
    end

    # Answers one client's requests until it goes away, giving its battle up then.
    #
    # @param client [TCPSocket] The client.
    def serve(client)
      session = nil
      while (line = client.gets(MAX_REQUEST))
        reply = begin
          request = JSON.parse(line)
          # A co-op battle takes the relay's connection over to its end.
          return host(client, request) if request["op"] == "serve"

          reply, session = handle(request, session)
          reply
        rescue JSON::ParserError => e
          { ok: false, error: "not JSON: #{e.message}" }
        end
        client.puts(JSON.generate(reply))
      end
    rescue IOError, SystemCallError
      nil
    ensure
      release(session) if session
      client.close unless client.closed?
    end

    # Hosts a co-op battle MGQ Online's starter handed to the relay, over the relay's connection
    # (see RelayBridge): {"op":"serve","bid":"<battle id>","setup":"<base64>"}. Answers serving
    # once the battle is set up, refused when it cannot be, and end once it is over.
    #
    # @param client [TCPSocket] The relay's connection.
    # @param request [Hash] The serve.
    def host(client, request)
      bridge = RelayBridge.new(client)
      refused = lambda do |code, error|
        bridge.tell(op: "refused", code: code, error: error)
        $stderr.puts("refused battle #{request['bid'].to_s[0, 32]}: #{code}: #{error}")
      end
      return refused.call("no_mgq_online", "this battle server hosts no MGQ Online battles") unless @served

      slotted = !forking? && take_slot
      return refused.call("busy", "another battle runs on this server") unless forking? || slotted

      battle_id = request["bid"].to_s
      return refused.call("setup", "the battle id is no id") unless battle_id.match?(/\A[0-9a-z]{1,32}\z/)

      setup = request["setup"].to_s.unpack1("m").force_encoding("UTF-8")
      ServedBattle.check(setup)
      @battles += 1
      started = clock
      bridge.tell(op: "serving")
      outcome = ServedBattle.run(bridge, battle_id, setup)
      $stderr.puts(format("battle %s: %s after %d turns, %.0f s", battle_id, outcome[:result], outcome[:turns], clock - started))
      bridge.tell(op: "end", result: outcome[:result].to_s, turns: outcome[:turns])
    rescue ServedBattle::Refused => e
      refused.call(e.code, e.message)
    rescue StandardError => e
      $stderr.puts("battle #{battle_id} failed: #{e.class}: #{e.message} at #{e.backtrace&.first(3)&.join(' < ')}")
      bridge.tell(op: "end", result: "failed", error: "#{e.class}: #{e.message}")
    ensure
      free_slot if slotted
      client.close unless client.closed?
    end

    # The time in seconds.
    #
    # @return [Float] The time.
    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # Answers one request.
    #
    # @param request [Hash] The request.
    # @param session [BattleSession, nil] The client's battle played turn by turn.
    # @return [Array(Hash, BattleSession)] The answer and the client's battle afterwards.
    def handle(request, session)
      # With MGQ Online loaded, a battle by request waits for players' commands that never come,
      # spinning until the child's CPU limit ends it.
      if @served && %w[battle start].include?(request["op"])
        return [{ ok: false, error: "this battle server hosts MGQ Online's co-op battles only, which the relay hands over" }, session]
      end

      case request["op"]
      when "ping"
        [{ ok: true, boot_seconds: @boot_seconds.round(1), battles: @battles, busy: @busy,
           mode: @mode, pid: Process.pid }, session]
      when "battle"
        timed { play_to_end(request) }.then { |reply| [reply, session] }
      when "start"
        return [{ ok: false, error: "a battle is already running for this client" }, session] if session
        return [busy, nil] unless take_slot

        @battles += 1
        session = BattleSession.new(request)
        settle(timed { { ok: true }.merge(session.next_event) }, session)
      when "answer"
        return [{ ok: false, error: "no battle is running for this client" }, nil] unless session

        session.answer(request.key?("choice") ? request["choice"].to_i : request["commands"] || {})
        settle(timed { { ok: true }.merge(session.next_event) }, session)
      else
        [{ ok: false, error: "unknown op #{request["op"].inspect}" }, session]
      end
    end

    # Plays a battle to its end with the game's auto battle.
    #
    # @param request [Hash] The battle's request.
    # @return [Hash] The answer.
    def play_to_end(request)
      return busy unless take_slot

      begin
        @battles += 1
        session = BattleSession.new(request)
        events = []
        loop do
          event = session.next_event
          events << event
          case event[:event]
          when "commands" then session.answer({})
          when "choice" then session.answer(0)
          else break
          end
        end
        last = events.last
        { ok: last[:event] == "end" }.merge(last).merge(log: events.flat_map { |e| e[:log] })
      ensure
        free_slot
      end
    end

    # Keeps a battle played turn by turn while it runs, and frees the server once it ended.
    #
    # @param reply [Hash] The answer to the client.
    # @param session [BattleSession] The battle.
    # @return [Array(Hash, BattleSession)] The answer and the battle, nil once it ended.
    def settle(reply, session)
      return [reply, session] unless %w[end error].include?(reply[:event])

      free_slot
      [reply, nil]
    end

    # Gives a client's running battle up and frees the server.
    #
    # @param session [BattleSession] The battle.
    def release(session)
      session.give_up
      free_slot
    end

    # Takes the server for a battle, unless another battle has it.
    #
    # @return [Boolean] Whether the battle got it.
    def take_slot
      @slot.synchronize { @busy ? false : (@busy = true) }
    end

    # Frees the server for the next battle.
    def free_slot
      @slot.synchronize { @busy = false }
    end

    # The answer for a request while another battle runs.
    #
    # @return [Hash] The answer.
    def busy
      { ok: false, error: "busy: another battle is running" }
    end

    # Runs a block and adds how long it took to its answer.
    #
    # @return [Hash] The block's answer with ms.
    def timed
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      reply = yield
      reply.merge(ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round)
    end
  end
end

BattleServer.run if $PROGRAM_NAME == __FILE__
