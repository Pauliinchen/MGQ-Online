#----------------------------------------------------------------
#  core_check.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Checks the core library the way the battle server loads it, without the game: forks battle
# children as server.rb does, prepares each with server.rb's own enter_child (the library loaded
# before the sandbox, the handshake after it), then calls core.runtime, runs a batch and drains the
# core's log lines, and prints what each child took. The parent reads each child's memory from
# /proc, since a sandboxed child sees none. Run it as root on Linux (core_check.ps1 runs it in
# Docker):
#   BATTLE_CORE_LIBRARY=MGQOnline.ServerCore.so ruby core_check.rb
# CHECK_CHILDREN sets the children at once (default 2), CHECK_PARENT_MB the parent's address space
# they start with (default 1229, the game a battle server parent holds).

require "fiddle"
require "fileutils"
require "json"
require "tmpdir"

# The folder each child is closed into, the game folder as server.rb names it.
ROOT = Dir.mktmpdir("core-check-root")
File.chmod(0o755, ROOT)
ENV["BATTLE_GAME_DIR"] = ROOT

require_relative "../server"

# MGQ Online's bridge out of Multiplayer.rb, with a log that writes to the child's output.
module MGQ_Multiplayer
  # Writes MGQ Online's log lines, as the battle server's Online does, and counts the core's.
  module Log
    @core_lines = 0

    # Writes a line.
    #
    # @param line [String] The line.
    def self.write(line)
      @core_lines += 1 if line.start_with?("core: ")
      $stdout.puts("[mgq] #{line}")
    end

    # Tells how many lines came from the core.
    #
    # @return [Integer] The lines.
    def self.core_lines
      @core_lines
    end
  end
end
# A checkout on Windows mounted into the container keeps its carriage returns.
multiplayer = File.read(File.expand_path("../../GameScript/Multiplayer.rb", __dir__), encoding: "UTF-8").delete("\r")
MGQ_Multiplayer.module_eval(multiplayer[/  module Bridge\n.*?\n  end\n/m])

# Times the core's load and handshake inside enter_child, by wrapping Core.load and Core.open.
module CoreTimes
  # The milliseconds of each step, by name.
  TIMES = {}

  # Loads the library, timed.
  def load(*args)
    timed(:load_ms) { super }
  end

  # Shakes hands, timed.
  def open(*args)
    timed(:handshake_ms) { super }
  end

  private

  # Runs a block and keeps how long it took.
  #
  # @param key [Symbol] The step.
  # @return [Object] The block's value.
  def timed(key)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
  ensure
    TIMES[key] = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
  end
end
Core.singleton_class.prepend(CoreTimes)

# Plays the battle server's battle children with the core library and reports what they took.
module CoreCheck
  # Entries of the batch each child runs: core.runtime, as many times.
  BATCH_ENTRIES = 1000

  # The battle server's CPU seconds for each child (server.rb).
  CHILD_CPU_SECONDS = BattleServer::CHILD_CPU_SECONDS

  # Seconds the parent waits on a child before it kills it.
  CHILD_SECONDS = 60

  # mmap's flags for address space that takes no memory: MAP_PRIVATE, MAP_ANONYMOUS, MAP_NORESERVE.
  RESERVE_FLAGS = 0x02 | 0x20 | 0x4000

  class << self
    # Forks the children, reports each and prints a table.
    def run
      abort "run it as root on Linux, as the battle server runs" unless Sandbox.available?
      BattleServer.instance_variable_set(:@core_library, Core.library)
      abort "BATTLE_CORE_LIBRARY names no library" unless BattleServer.instance_variable_get(:@core_library)

      reserve_parent
      parent = memory(Process.pid)
      puts("parent: VmSize #{parent[:VmSize] / 1024} MB, VmRSS #{parent[:VmRSS] / 1024} MB, #{parent[:Threads]} threads")
      count = (ENV["CHECK_CHILDREN"] || 2).to_i
      rows = Array.new(count) { fork_child }.map { |child| Thread.new { watch(*child) } }.map(&:value)
      puts
      puts("| Child | Outcome | Load ms | Handshake ms | Batch of #{BATCH_ENTRIES} ms | Drain ms | Log lines | Heap limit MB | VmSize MB | VmRSS MB | Threads |")
      puts("|---|---|---|---|---|---|---|---|---|---|---|")
      rows.each { |row| puts("| #{row.join(' | ')} |") }
      exit(rows.all? { |row| row[1] == "works" } ? 0 : 1)
    ensure
      FileUtils.rm_rf(ROOT)
    end

    private

    # Grows the parent's address space to CHECK_PARENT_MB with address space that takes no memory,
    # so the children start with the battle server parent's.
    def reserve_parent
      wanted = (ENV["CHECK_PARENT_MB"] || 1229).to_i * 1024**2
      missing = wanted - memory(Process.pid)[:VmSize] * 1024
      return unless missing.positive?

      mmap = Fiddle::Function.new(Fiddle.dlopen(nil)["mmap"], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_LONG], Fiddle::TYPE_VOIDP)
      address = mmap.call(nil, missing, 0, RESERVE_FLAGS, -1, 0).to_i
      raise "mmap of #{missing} bytes failed" if address == -1 || address == 2**64 - 1
    end

    # Forks a child that prepares itself as a battle child does and calls the core.
    #
    # @return [Array(Integer, IO, IO, IO)] The child, the pipe its report comes out of, the pipe
    #   the parent acknowledges it through and the pipe its output comes out of.
    def fork_child
      report, report_out = IO.pipe
      ack_in, ack = IO.pipe
      output, child_output = IO.pipe
      pid = Process.fork do
        [report, ack, output].each(&:close)
        $stdout.reopen(child_output)
        $stderr.reopen(child_output)
        Process.setrlimit(:CPU, CHILD_CPU_SECONDS)
        report_out.puts(JSON.generate(play))
        report_out.flush
        ack_in.gets
        Process.exit!(0)
      end
      [report_out, ack_in, child_output].each(&:close)
      [pid, report, ack, output]
    end

    # Runs in a child: enter_child with a socket pair as its client, then the calls.
    #
    # @return [Hash] What the child took.
    def play
      client, served = UNIXSocket.pair
      unless BattleServer.send(:enter_child, served)
        served.close
        return { error: "enter_child refused: #{client.read}" }
      end
      return { error: "the child still runs as root, so the sandbox was not entered" } if Process.euid.zero?
      return { error: "the core did not shake hands" } unless MGQ_Multiplayer::Bridge.open?

      bridge = MGQ_Multiplayer::Bridge
      runtime = bridge.call("core.runtime")
      batch_ms = timed { bridge.call!("batch", Array.new(BATCH_ENTRIES) { ["core.runtime", nil] }) }
      drain_ms = timed { bridge.frame }
      CoreTimes::TIMES.merge(batch_ms: batch_ms, drain_ms: drain_ms, log_lines: MGQ_Multiplayer::Log.core_lines, heap_limit: runtime && runtime["heap_limit"])
    rescue StandardError => e
      { error: "#{e.class}: #{e.message}" }
    end

    # Waits on a child's report, reads its memory and lets it end.
    #
    # @param pid [Integer] The child.
    # @param report [IO] Its report.
    # @param ack [IO] Its acknowledgement.
    # @param output [IO] Its output.
    # @return [Array] Its row of the table.
    def watch(pid, report, ack, output)
      printer = Thread.new { output.each_line { |line| print("[#{pid}] #{line}") } }
      line = report.gets
      result = line ? JSON.parse(line) : { "error" => "the child ended without a report" }
      status = memory(pid)
      ack.puts
      wait(pid)
      printer.join
      outcome = result["error"] || "works"
      [pid, outcome, result["load_ms"], result["handshake_ms"], result["batch_ms"], result["drain_ms"], result["log_lines"],
       result["heap_limit"] && result["heap_limit"] / 1024**2, status[:VmSize] && status[:VmSize] / 1024, status[:VmRSS] && status[:VmRSS] / 1024, status[:Threads]]
    end

    # Waits on a child, killing it after CHILD_SECONDS.
    #
    # @param pid [Integer] The child.
    def wait(pid)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + CHILD_SECONDS
      until Process.wait2(pid, Process::WNOHANG)
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          Process.kill(:KILL, pid)
          Process.wait(pid)
          return
        end
        sleep(0.05)
      end
    end

    # Reads a process's memory and threads from /proc.
    #
    # @param pid [Integer] The process.
    # @return [Hash{Symbol => Integer}] :VmSize and :VmRSS in kB, and :Threads.
    def memory(pid)
      File.readlines("/proc/#{pid}/status").each_with_object({}) do |line, fields|
        key, value = line.split(":", 2)
        fields[key.to_sym] = value.to_i if %w[VmSize VmRSS Threads].include?(key)
      end
    rescue SystemCallError
      {}
    end

    # Runs a block and tells how long it took.
    #
    # @return [Float] The milliseconds.
    def timed
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
    end
  end
end

CoreCheck.run
