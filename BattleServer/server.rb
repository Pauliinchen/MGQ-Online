#----------------------------------------------------------------
#  server.rb
#
#  Changelog:
#      Paulinchen  2026-11-12: Ended a co-op battle's child that runs past the time the relay keeps its battle
#      Paulinchen  2026-11-11: Removed the battles by request, which no client sends, and ended at once in a game folder without MGQ Online
#      Paulinchen  2026-11-08: Downloaded a co-op battle's mods from the website's catalog instead of the relay's
#      Paulinchen  2026-11-05: Read a co-op battle's mods through ServedMods, which reads them without the game's scripts
#                            - Had the core write the lines of a hosted battle to the relay, and wrote the line of a battle out of CPU time before it can run out
#      Paulinchen  2026-10-31: Told a server of MGQ Online's battles by MGQ Online's file, which the Mod Framework loads only as the game runs
#      Paulinchen  2026-10-30: Read a co-op battle's mods without the core library before its child's sandbox
#      Paulinchen  2026-10-23: Refused MGQ Online's battles without the core library, telling the relay why
#                            - Derived the story mapping's index for the relay
#                            - Loaded MGQ Online's core library in each battle child before its sandbox and shook hands after it
#                            - Answered a battle whose sandbox could not drop root as one that could not be sandboxed
#                            - Let a co-op battle use CPU time for as long as the relay keeps it and ended it as failed past that
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
require_relative "lib/sandbox"
require_relative "lib/served"
require_relative "lib/relay_bridge"
require_relative "lib/mods"
require_relative "lib/core"
require_relative "lib/story_index"

# The battle server: it loads the game with MGQ Online once and then hosts the co-op battles the
# relay hands over, over TCP, one JSON object per line each way. Requests:
#   {"op":"serve", "bid":"<battle id>", "setup":"<base64>"}
#       hosts a co-op battle over the relay's connection to its end, see host.
#   {"op":"story_index", "rowsRev":3, "keys":[...], "events":[...]}
#       derives the story mapping's index for the relay, see StoryIndex.
#   {"op":"ping"}
# Every answer holds "ok", and "error" when it is false. The game's globals hold one battle per
# process: where the system can fork (Linux), each connection gets a child process of its own,
# which shares the loaded game with the others, is sandboxed when the server runs as root, and
# ends with the connection; elsewhere (Windows) the server hosts one battle at a time and turns
# others away as busy.
module BattleServer
  # The port the server listens on unless BATTLE_PORT names another.
  DEFAULT_PORT = 8095

  # How long each request may be, in bytes.
  MAX_REQUEST = 8 * 1024 * 1024

  # Child processes at once unless BATTLE_CHILDREN names another number.
  DEFAULT_CHILDREN = 64

  # CPU seconds a child that hosts an MGQ Online co-op battle may use, so a battle caught in a loop
  # ends instead of taking a core: as long as the relay keeps such a battle (BATTLE_LIMITS.lifetimeMs in Relay/core/battles.js), since it runs at the game's
  # pace while its players choose.
  SERVED_CPU_SECONDS = 2 * 60 * 60

  # Seconds a child that hosts an MGQ Online co-op battle may run: as long as the relay keeps such a
  # battle (BATTLE_LIMITS.lifetimeMs in Relay/core/battles.js) plus 10 minutes, so a battle the relay
  # never closed still ends while it sleeps out its frames or waits for its players.
  SERVED_SECONDS = 2 * 60 * 60 + 10 * 60

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
    # Loads the game, then serves clients until stopped; ends at once when the game folder holds no
    # MGQ Online, whose battles are all the server hosts.
    def run
      # The Mod Framework loads MGQ Online only as the game runs, so its file tells.
      unless Boot.served_game?
        $stderr.puts("the game folder holds no MGQ Online (Patch/Multiplayer.rb): this server serves nothing")
        return
      end

      boot_seconds = Boot.run
      ServedBattle.install
      @core_library = Core.library
      # Forked children each load the core themselves; it must never run before a fork.
      Core.open(Core.load(@core_library)) unless forking?
      @boot_seconds = boot_seconds
      port = (ENV["BATTLE_PORT"] || DEFAULT_PORT).to_i
      server = TCPServer.new("127.0.0.1", port)
      @mode = "MGQ Online co-op battles, " + (forking? ? "fork" : "thread")
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
          # The parent never calls the core, see Core.
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
          limit_cpu(SERVED_CPU_SECONDS)
          limit_time(SERVED_SECONDS)
          # A co-op battle's mods come before the sandbox, which reaches neither the network nor
          # the cache.
          first = client.gets(MAX_REQUEST)
          mods = mods_for(first)
          Process.exit!(1) unless enter_child(client)
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
      @cpu_seconds = seconds
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
      @bridge.put(@out_of_cpu_line) if @bridge && @out_of_cpu_line
    ensure
      Process.exit!(1)
    end

    # Limits how long the calling child runs: past the limit it ends its battle as failed and exits,
    # whatever the battle waits for.
    #
    # @param seconds [Numeric] The seconds it may run.
    # @return [Thread] The thread that ends it.
    def limit_time(seconds)
      @time_seconds = seconds
      Thread.new do
        sleep(seconds)
        $stderr.puts("battle #{@battle_id || 'none'} ran past its #{seconds} seconds and ends")
        @bridge.put(@out_of_time_line) if @bridge && @out_of_time_line
      ensure
        Process.exit!(1)
      end
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

    # Prepares a battle's child before it plays: loads MGQ Online's core library, closes the child
    # in where the system can, then shakes hands with the core. The sandbox's chroot hides the
    # library's path, so it loads before; its runtime starts at the first call, after, under the
    # sandbox's limits.
    #
    # @param client [TCPSocket] The child's client, which hears why when it cannot be closed in.
    # @return [Boolean] Whether the child may play; a child the sandbox could not close in never
    #   plays.
    def enter_child(client)
      core = Core.load(@core_library)
      begin
        Sandbox.enter(Boot::GAME_DIR) if Sandbox.available?
      rescue StandardError, SecurityError => e
        # The core opens only inside the sandbox, so this answer is written here.
        client.puts(JSON.generate(ok: false, error: "the battle could not be sandboxed: #{e.message}"))
        return false
      end
      Core.open(core)
      true
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
      while (line = first || client.gets(MAX_REQUEST))
        first = nil
        reply = begin
          request = JSON.parse(line)
          # A co-op battle takes the relay's connection over to its end.
          return host(client, request, mods) if request["op"] == "serve"

          handle(request)
        rescue JSON::ParserError => e
          { ok: false, error: "not JSON: #{e.message}" }
        end
        client.puts(JSON.generate(reply))
      end
    rescue IOError, SystemCallError
      nil
    ensure
      client.close unless client.closed?
    end

    # Hosts a co-op battle MGQ Online's starter handed to the relay, over the relay's connection
    # (see RelayBridge): {"op":"serve","bid":"<battle id>","setup":"<base64>"}. Answers serving
    # once the battle is set up, refused when it cannot be, such as without the core library (see
    # Core.ready?), and end once it is over. The core writes these lines, but for the refusals sent
    # while this thread may not call it (RelayBridge#refuse_without_core).
    #
    # @param client [TCPSocket] The relay's connection.
    # @param request [Hash] The serve.
    # @param mods [Array, ServedMods::Unavailable, nil] The battle's mods as the child got them
    #   before its sandbox, see mods_for; nil to get them now.
    def host(client, request, mods = nil)
      bridge = RelayBridge.new(client)
      refused = lambda do |code, error, by_core = true|
        by_core ? bridge.tell("op" => "refused", "code" => code, "error" => error) : bridge.refuse_without_core(code, error)
        $stderr.puts("refused battle #{request['bid'].to_s[0, 32]}: #{code}: #{error}")
      end
      return refused.call("core", Core.why_missing, false) unless Core.ready?

      slotted = !forking? && take_slot
      # The battle that holds the slot calls the core on its own thread.
      return refused.call("busy", "another battle runs on this server", false) unless forking? || slotted

      battle_id = request["bid"].to_s
      return refused.call("setup", "the battle id is no id") unless battle_id.match?(/\A[0-9a-z]{1,32}\z/)

      setup = request["setup"].to_s.unpack1("m").force_encoding("UTF-8")
      wanted = Array(ServedBattle.check(setup)[:mods])
      mods ||= fetch_mods(wanted)
      raise ServedBattle::Refused.new("mods", mods.message) if mods.is_a?(ServedMods::Unavailable)

      @battles += 1
      started = clock
      bridge.tell("op" => "serving")
      @battle_id = battle_id
      @bridge = bridge
      # The threads the limits start may not call the core, so their lines are written now.
      @out_of_cpu_line = bridge.line_of("op" => "end", "result" => "failed", "error" => "the battle used up its #{@cpu_seconds} CPU seconds") if @cpu_seconds
      @out_of_time_line = bridge.line_of("op" => "end", "result" => "failed", "error" => "the battle ran past its #{@time_seconds} seconds") if @time_seconds
      $stderr.puts("battle #{battle_id} started")
      outcome = ServedBattle.run(bridge, battle_id, setup, mods)
      $stderr.puts(format("battle %s: %s after %d turns, %.0f s, %.0f CPU s", battle_id, outcome[:result], outcome[:turns], clock - started, cpu_seconds))
      bridge.tell("op" => "end", "result" => outcome[:result].to_s, "turns" => outcome[:turns])
    rescue ServedBattle::Refused => e
      refused.call(e.code, e.message)
    rescue StandardError => e
      $stderr.puts("battle #{battle_id} failed: #{e.class}: #{e.message} at #{e.backtrace&.first(3)&.join(' < ')}")
      bridge.tell("op" => "end", "result" => "failed", "error" => "#{e.class}: #{e.message}")
    ensure
      free_slot if slotted
      client.close unless client.closed?
    end

    # Gets the mods of a co-op battle a child is handed before it enters its sandbox: from the
    # cache, else downloaded from the website's catalog (ServedMods::SITE).
    #
    # @param line [String, nil] The child's first request.
    # @return [Array, ServedMods::Unavailable, nil] The mods, see ServedMods.fetch; why they could
    #   not be had; nil for a request that is no co-op battle's or a setup the server cannot read.
    def mods_for(line)
      request = line && JSON.parse(line)
      return nil unless request.is_a?(Hash) && request["op"] == "serve"

      # The core's runtime must start under the sandbox's limits (see enter_child), and the sandbox
      # reaches neither the network nor the cache the mods come from, so the request and the
      # setup's mods are read without the core.
      mods = ServedMods.named_in(request["setup"].to_s.unpack1("m").force_encoding("UTF-8"))
      mods && fetch_mods(mods)
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
      ServedMods.fetch(wanted, ServedMods::SITE)
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

    # Answers one request but a co-op battle's.
    #
    # @param request [Hash] The request.
    # @return [Hash] The answer.
    def handle(request)
      case request["op"]
      when "story_index"
        StoryIndex.answer(request)
      when "ping"
        { ok: true, boot_seconds: @boot_seconds.round(1), battles: @battles, busy: @busy, mode: @mode, pid: Process.pid }
      else
        { ok: false, error: "unknown op #{request["op"].inspect}" }
      end
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
  end
end

BattleServer.run if $PROGRAM_NAME == __FILE__
