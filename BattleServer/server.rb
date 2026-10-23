#----------------------------------------------------------------
#  server.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Let a co-op battle use CPU time for as long as the relay keeps it and ended it as failed past that
#                            - Logged how each child ended, with its battle
#      Paulinchen  2026-10-15: Refused battles by request while it hosts MGQ Online's battles
#                            - Hosted the co-op battles the relay hands over
#                            - Kept up to 1 MB of a child's output
#                            - Got a co-op battle's mods before its child's sandbox
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
require_relative "lib/mods"

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

  # CPU seconds a child that hosts an MGQ Online co-op battle may use: as long as the relay keeps
  # such a battle (BATTLE_LIMITS.lifetimeMs in Relay/core/battles.js), since it runs at the game's
  # pace while its players choose.
  SERVED_CPU_SECONDS = 2 * 60 * 60

  # CPU seconds past its limit a child has to end its battle before the system kills it.
  CPU_GRACE_SECONDS = 10

  # The line of a child's output that names its battle, see host.
  CHILD_BATTLE = /\Abattle ([0-9a-z]{1,32}) started\z/

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
          limit_cpu(@served ? SERVED_CPU_SECONDS : CHILD_CPU_SECONDS)
          # A co-op battle's mods come before the sandbox, which reaches neither the network nor
          # the cache.
          first = client.gets(MAX_REQUEST)
          mods = mods_for(first)
          begin
            Sandbox.enter(Boot::GAME_DIR) if Sandbox.available?
          rescue StandardError => e
            # A child the sandbox could not close in never plays.
            client.puts(JSON.generate(ok: false, error: "the battle could not be sandboxed: #{e.message}"))
            Process.exit!(1)
          end
          serve(client, first, mods)
          # The game's scripts never get to run exit handlers meant for Game.exe.
          Process.exit!(0)
        end
        child_output.close
        children << watch_child(pid, copy_output(output, pid))
        client.close
      end
    end

    # Limits the CPU time of the calling child. Past the limit the child ends its battle as failed,
    # see end_out_of_cpu, and the system kills it CPU_GRACE_SECONDS later.
    #
    # @param seconds [Integer] The CPU seconds it may use.
    def limit_cpu(seconds)
      Process.setrlimit(:CPU, seconds, seconds + CPU_GRACE_SECONDS)
      # A game script takes Kernel's trap away. A trap handler may lock no mutex, which the
      # relay's connection needs, and the system repeats the signal every second past the limit.
      Signal.trap("XCPU") { @out_of_cpu ||= Thread.new { end_out_of_cpu(seconds) } }
    end

    # Ends the child once it used up its CPU time: tells the relay its battle failed, so its
    # players learn it ended, and exits.
    #
    # @param seconds [Integer] The CPU seconds it had.
    def end_out_of_cpu(seconds)
      $stderr.puts("battle #{@battle_id || 'none'} used up its #{seconds} CPU seconds and ends")
      @bridge&.tell(op: "end", result: "failed", error: "the battle used up its #{seconds} CPU seconds")
    ensure
      Process.exit!(1)
    end

    # Logs how a child ended, with its battle, once it did.
    #
    # @param pid [Integer] The child.
    # @param copier [Thread] The thread that copies its output, see copy_output.
    # @return [Thread] The thread that waits for the child, alive while it runs.
    def watch_child(pid, copier)
      started = clock
      Thread.new do
        _, status = Process.wait2(pid)
        battle = begin
          copier.value
        rescue StandardError
          nil
        end
        $stderr.puts(format("[%d] ended after %.0f s, battle %s: %s", pid, clock - started, battle || "none", ended(status)))
      end
    end

    # Tells how a process ended.
    #
    # @param status [Process::Status] Its status.
    # @return [String] Such as "exit 0" or "killed by SIGXCPU".
    def ended(status)
      status.signaled? ? "killed by SIG#{Signal.signame(status.termsig)}" : "exit #{status.exitstatus}"
    end

    # Copies a child's output into the server's log, each line marked with the child, up to
    # CHILD_OUTPUT bytes so a child cannot fill the disk.
    #
    # @param output [IO] The pipe's end the child's output comes out of.
    # @param pid [Integer] The child.
    # @return [Thread] The copying thread, whose value is the id of the battle the child named, see
    #   CHILD_BATTLE, nil for none.
    def copy_output(output, pid)
      Thread.new do
        battle = nil
        left = CHILD_OUTPUT
        output.each_line do |line|
          # As bytes, since a line need not be valid UTF-8.
          battle ||= line.b.chomp[CHILD_BATTLE, 1]
          next if left <= 0

          left -= line.bytesize
          $stderr.write("[#{pid}] #{line}")
          $stderr.write("[#{pid}] output past #{CHILD_OUTPUT} bytes is dropped\n") if left <= 0
        end
        battle
      ensure
        output.close
      end
    end

    # Answers one client's requests until it goes away, giving its battle up then.
    #
    # @param client [TCPSocket] The client.
    # @param first [String, nil] The client's first request when it was read already.
    # @param mods [Array, ServedMods::Unavailable, nil] The mods of a co-op battle in the first
    #   request, see mods_for; nil to get them as the battle starts.
    def serve(client, first = nil, mods = nil)
      session = nil
      while (line = first || client.gets(MAX_REQUEST))
        first = nil
        reply = begin
          request = JSON.parse(line)
          # A co-op battle takes the relay's connection over to its end.
          return host(client, request, mods) if request["op"] == "serve"

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
    # @param mods [Array, ServedMods::Unavailable, nil] The battle's mods as the child got them
    #   before its sandbox, see mods_for; nil to get them now.
    def host(client, request, mods = nil)
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
      wanted = Array(ServedBattle.check(setup)[:mods])
      mods ||= fetch_mods(wanted)
      raise ServedBattle::Refused.new("mods", mods.message) if mods.is_a?(ServedMods::Unavailable)

      @battles += 1
      started = clock
      bridge.tell(op: "serving")
      @battle_id = battle_id
      @bridge = bridge
      $stderr.puts("battle #{battle_id} started")
      outcome = ServedBattle.run(bridge, battle_id, setup, mods)
      $stderr.puts(format("battle %s: %s after %d turns, %.0f s, %.0f CPU s", battle_id, outcome[:result], outcome[:turns], clock - started, cpu_seconds))
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

    # Gets the mods of a co-op battle a child is handed before it enters its sandbox: from the
    # cache, else downloaded from the relay BATTLE_RELAY_URL names.
    #
    # @param line [String, nil] The child's first request.
    # @return [Array, ServedMods::Unavailable, nil] The mods, see ServedMods.fetch; why they could
    #   not be had; nil for a request that is no co-op battle's or a setup the server cannot read.
    def mods_for(line)
      request = line && JSON.parse(line)
      return nil unless @served && request.is_a?(Hash) && request["op"] == "serve"

      setup = MGQ_MpBattlesServed.read_setup(request["setup"].to_s.unpack1("m").force_encoding("UTF-8"))
      setup && fetch_mods(setup[:mods])
    rescue JSON::ParserError
      nil
    end

    # Gets a battle's mods. Where one process hosts every battle (thread mode), mods stay loaded,
    # so it hosts only battles of the mods it loaded first.
    #
    # @param wanted [Array<Array>] The mods the starter runs, see MGQ_MpBattlesServed.mods_of.
    # @return [Array, ServedMods::Unavailable] The mods, see ServedMods.fetch, or why not.
    def fetch_mods(wanted)
      unless forking?
        @thread_mods ||= wanted
        return ServedMods::Unavailable.new("this server hosts one battle at a time and keeps the mods of its first; restart it for others") unless @thread_mods == wanted
      end
      ServedMods.fetch(wanted, ENV["BATTLE_RELAY_URL"])
    rescue ServedMods::Unavailable => e
      $stderr.puts("the battle's mods cannot be had: #{e.message}")
      e
    end

    # The time in seconds.
    #
    # @return [Float] The time.
    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # The CPU time the process used so far, which a child's limit counts.
    #
    # @return [Float] The seconds.
    def cpu_seconds
      times = Process.times
      times.utime + times.stime
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
