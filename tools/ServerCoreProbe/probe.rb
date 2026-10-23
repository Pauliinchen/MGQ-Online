#----------------------------------------------------------------
#  probe.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

require "fiddle"
require "fileutils"
require "json"
require_relative [File.join(__dir__, "sandbox.rb"), File.join(__dir__, "..", "..", "BattleServer", "lib", "sandbox.rb")]
  .find { |path| File.exist?(path) }

# Plays the battle server's battle children with the probe library instead of a battle: forks as
# server.rb does, loads ServerCoreProbe.so through Fiddle, enters the battle server's own Sandbox
# and calls the exports, in the order the refactor plans and in the orders it rules out. The
# parent reads each child's memory from /proc at the marks the child sets, since a sandboxed child
# sees no /proc. Run it as root on Linux:
#   ruby probe.rb ServerCoreProbe.so ServerCoreProbe.baked.so
# PROBE_PARENT_MB sets the parent's address space the children start with (default 1229, the
# game a battle server parent holds), PROBE_ROOT the folder the children are closed into.
module ServerCoreProbe
  # The version core_open answers.
  VERSION = 1

  # The GC heap limit the scenarios with a limit set through the environment use: 256 MB, in the
  # hexadecimal the runtime reads its GC settings in.
  # NativeAOT reads "0x10000000" as no limit at all: the hexadecimal must come without its 0x.
  LIMIT_ENV = { "DOTNET_GCHeapHardLimit" => "10000000" }.freeze

  # The environment variables of the GC a scenario without them clears.
  GC_ENV = /\ADOTNET_gc|\ADOTNET_GC/i

  # Megabytes a stress call allocates and drops, which makes the GC run many times.
  CHURN_MB = 512

  # Megabytes the first stress call keeps alive at once, below the heap limit.
  FITS_MB = 128

  # Megabytes the second stress call tries to keep alive at once, past the heap limit.
  PAST_LIMIT_MB = 1024

  # The battle server's CPU seconds for each child (server.rb).
  CHILD_CPU_SECONDS = 120

  # Seconds the parent waits on a child before it kills it.
  CHILD_SECONDS = 90

  # Seconds a child that forks a child of its own waits on it before it kills it.
  GRANDCHILD_SECONDS = 20

  # Bytes of the buffers the exports write into.
  BUFFER = 64 * 1024

  # The parent's address space in megabytes unless PROBE_PARENT_MB names another: about the game
  # the battle server's parent holds (sandbox.rb).
  DEFAULT_PARENT_MB = 1229

  # mmap's flags for address space that takes no memory: MAP_PRIVATE, MAP_ANONYMOUS, MAP_NORESERVE.
  RESERVE_FLAGS = 0x02 | 0x20 | 0x4000

  # The keys of core_info's answer the report prints.
  INFO_KEYS = %w[framework latency server_gc processors total_available gc.ConcurrentGC gc.GCHeapHardLimit gc.GCRegionRange].freeze

  # A way to load and call the library in a child.
  #
  # name: what the report calls it; lib: :plain, :baked or :inside_root (the plain library copied
  # into the sandbox's folder); limit: whether LIMIT_ENV is set; load and start: :before or :after
  # the sandbox, start being the first call, which starts the runtime; parent: nil, or :loaded or
  # :started when a child of the parent loads (and starts) the library and forks the child that
  # calls it, as the battle server's parent would if it loaded the library once for all; children:
  # how many run at once.
  Scenario = Struct.new(:name, :lib, :limit, :load, :start, :parent, :children, keyword_init: true)

  # Every scenario, the planned order first.
  SCENARIOS = [
    Scenario.new(name: "planned: load before the sandbox, call after", lib: :plain, limit: true, load: :before, start: :after, children: 1),
    Scenario.new(name: "planned, two children at once", lib: :plain, limit: true, load: :before, start: :after, children: 2),
    Scenario.new(name: "baked heap limit, no environment", lib: :baked, limit: false, load: :before, start: :after, children: 1),
    Scenario.new(name: "no heap limit", lib: :plain, limit: false, load: :before, start: :after, children: 1),
    Scenario.new(name: "runtime started before the sandbox", lib: :plain, limit: true, load: :before, start: :before, children: 1),
    Scenario.new(name: "loaded after the sandbox", lib: :plain, limit: true, load: :after, start: :after, children: 1),
    Scenario.new(name: "loaded after the sandbox from inside its folder", lib: :inside_root, limit: true, load: :after, start: :after, children: 1),
    Scenario.new(name: "loaded in a parent, started in its child", lib: :plain, limit: true, load: :before, start: :after, parent: :loaded, children: 1),
    Scenario.new(name: "started in a parent, called in its child", lib: :plain, limit: true, load: :before, start: :after, parent: :started, children: 1)
  ].freeze

  # The library's exports through Fiddle.
  class Core
    # Binds the exports.
    #
    # @param handle [Fiddle::Handle] The loaded library.
    def initialize(handle)
      int = Fiddle::TYPE_INT
      pointer = Fiddle::TYPE_VOIDP
      @open = Fiddle::Function.new(handle["core_open"], [], int)
      @echo = Fiddle::Function.new(handle["core_echo"], [pointer, int, pointer, int], int)
      @info = Fiddle::Function.new(handle["core_info"], [pointer, int], int)
      @stress = Fiddle::Function.new(handle["core_stress"], [int, int, pointer, int], int)
    end

    # The handshake.
    #
    # @return [Integer] The library's version.
    def open
      @open.call
    end

    # Copies bytes through the library.
    #
    # @param bytes [String] The bytes.
    # @param capacity [Integer] The output buffer's size.
    # @return [String, Integer] The copy, or the negative length the library answers when the
    #   buffer is too small.
    def echo(bytes, capacity)
      output = "\0".b * capacity
      length = @echo.call(bytes, bytes.bytesize, output, capacity)
      length.negative? ? length : output.byteslice(0, length)
    end

    # The runtime's description.
    #
    # @return [Hash{String => String}] Its keys and values.
    def info
      text { |output| @info.call(output, BUFFER) }
    end

    # Makes the GC run and keeps memory alive.
    #
    # @param churn [Integer] Megabytes allocated and dropped.
    # @param keep [Integer] Megabytes kept alive at once.
    # @return [Hash{String => String}] The outcome's keys and values.
    def stress(churn, keep)
      text { |output| @stress.call(churn, keep, output, BUFFER) }
    end

    private

    # Calls an export that writes "key=value" lines into a buffer.
    #
    # @yieldparam output [String] The buffer.
    # @yieldreturn [Integer] The length the export answers.
    # @return [Hash{String => String}] The lines' keys and values.
    def text
      output = "\0".b * BUFFER
      length = yield(output)
      raise "the answer is #{-length} bytes, more than the buffer's #{BUFFER}" if length.negative?

      output.byteslice(0, length).force_encoding("UTF-8").lines.to_h { |line| line.chomp.split("=", 2) }
    end
  end

  # One forked child of the parent, with the pipes it reports through.
  class Child
    # The child's process.
    attr_reader :pid

    # The pipe its marks and results come out of.
    attr_reader :report

    # The pipe the parent acknowledges each mark through.
    attr_reader :ack

    # The pipe its standard streams go into.
    attr_reader :output

    # Forks the child, which runs the block.
    #
    # @yieldparam report [IO] Where the child writes its marks and results.
    # @yieldparam ack [IO] Where it waits for the parent after a mark.
    def initialize
      @report, report_out = IO.pipe
      ack_in, @ack = IO.pipe
      @output, child_output = IO.pipe
      @pid = Process.fork do
        [@report, @ack, @output].each(&:close)
        # As server.rb: a sandboxed child may write no file, so its streams go through a pipe.
        $stdout.reopen(child_output)
        $stderr.reopen(child_output)
        Process.setrlimit(:CPU, CHILD_CPU_SECONDS)
        yield(report_out, ack_in)
        Process.exit!(0)
      end
      [report_out, ack_in, child_output].each(&:close)
    end
  end

  # Runs in a child: loads and calls the library as its scenario says, and reports.
  class Run
    # Prepares a run.
    #
    # @param scenario [Scenario] The scenario.
    # @param path [String] The library's path as the child names it when it loads it.
    # @param root [String] The folder the sandbox closes the child into.
    # @param report [IO] Where marks and results go.
    # @param ack [IO] Where the parent acknowledges each mark.
    def initialize(scenario, path, root, report, ack)
      @scenario = scenario
      @path = path
      @root = root
      @report = report
      @ack = ack
      @result = { pid: Process.pid }
    end

    # Sets the scenario's environment, as the battle server would before it loads the library.
    def environment
      ENV.each_key { |key| ENV.delete(key) if key.match?(GC_ENV) }
      LIMIT_ENV.each { |key, value| ENV[key] = value } if @scenario.limit
    end

    # Loads the library, timed.
    #
    # @return [Fiddle::Handle] The library.
    def load
      handle = timed(:load_ms) { Fiddle.dlopen(@path) }
      mark("loaded")
      handle
    end

    # Makes the first call, which starts the runtime, timed.
    #
    # @param core [Core] The exports.
    def start(core)
      @result[:version] = timed(:start_ms) { core.open }
      mark("started")
    end

    # Plays the scenario from the fork on.
    #
    # @param handle [Fiddle::Handle, nil] The library when the child's parent loaded it.
    # @param started [Boolean] Whether the parent started its runtime too.
    def play(handle = nil, started: false)
      @result[:pid] = Process.pid
      mark("forked")
      environment unless handle
      handle ||= load if @scenario.load == :before
      core = handle && Core.new(handle)
      start(core) if @scenario.start == :before && !started
      begin
        timed(:sandbox_ms) { Sandbox.enter(@root) }
      rescue StandardError, SecurityError => e
        return finish(error: "the sandbox failed: #{e.class}: #{e.message}")
      end
      mark("sandboxed")
      if @scenario.load == :after
        begin
          handle = load
        rescue Fiddle::DLError => e
          return finish(error: "dlopen failed: #{e.message}")
        end
        core = Core.new(handle)
      end
      start(core) if @scenario.start == :after
      call(core)
      finish
    end

    # Calls every export, the stress call twice: within the heap limit and past it.
    #
    # @param core [Core] The exports.
    def call(core)
      @result[:echo] = echo_works?(core)
      @result[:info] = core.info
      mark("info")
      @result[:fits] = timed(:fits_ms) { core.stress(CHURN_MB, FITS_MB) }
      mark("stressed")
      @result[:past_limit] = timed(:past_limit_ms) { core.stress(0, PAST_LIMIT_MB) }
      mark("past the limit")
      @result[:alive] = core.open == VERSION
    end

    # Tells whether the echo copies small and large buffers and refuses a buffer too small.
    #
    # @param core [Core] The exports.
    # @return [Boolean] Whether it does.
    def echo_works?(core)
      small = Random.new(1).bytes(1024)
      large = Random.new(2).bytes(60_000)
      core.echo(small, 1024) == small && core.echo(large, BUFFER) == large && core.echo(small, 10) == -1024
    end

    # Sets a mark: the parent reads the child's memory, and the child goes on once it did.
    #
    # @param label [String] The mark.
    def mark(label)
      @report.puts(JSON.generate(mark: label, pid: Process.pid))
      @report.flush
      @ack.gets
    end

    # Reports the result.
    #
    # @param fields [Hash] What to add to it.
    # @return [nil]
    def finish(**fields)
      @report.puts(JSON.generate(result: @result.merge(fields)))
      @report.flush
      nil
    end

    private

    # Runs a block and keeps how long it took.
    #
    # @param key [Symbol] The result's key for the milliseconds.
    # @return [Object] The block's value.
    def timed(key)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      value = yield
      @result[key] = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)
      value
    end
  end

  class << self
    # Runs every scenario and prints what each did.
    #
    # @param plain [String] The library without a baked heap limit.
    # @param baked [String] The library with one.
    def run(plain, baked)
      abort "run it as root on Linux, as the battle server runs" unless Sandbox.available?
      @root = ENV["PROBE_ROOT"] || "/tmp/server-core-probe-root"
      FileUtils.mkdir_p(@root)
      File.chmod(0o755, @root)
      FileUtils.cp(plain, File.join(@root, "core.so"))
      @paths = { plain: File.expand_path(plain), baked: File.expand_path(baked), inside_root: "/core.so" }
      reserve_parent
      puts("parent: #{format_memory(memory(Process.pid))}")
      rows = SCENARIOS.map { |scenario| report(scenario, play(scenario)) }
      puts
      puts("| Scenario | Outcome | Load ms | Start ms | VmSize MB | Private MB | Threads | Heap limit | Latency |")
      puts("|---|---|---|---|---|---|---|---|---|")
      rows.each { |row| puts("| #{row.join(' | ')} |") }
    ensure
      FileUtils.rm_rf(@root) if @root
    end

    private

    # Grows the parent's address space to PROBE_PARENT_MB with address space that takes no memory,
    # so the children start with the battle server parent's.
    def reserve_parent
      wanted = (ENV["PROBE_PARENT_MB"] || DEFAULT_PARENT_MB).to_i * 1024**2
      missing = wanted - memory(Process.pid)[:VmSize] * 1024
      return unless missing.positive?

      mmap = Fiddle::Function.new(Fiddle.dlopen(nil)["mmap"], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_LONG], Fiddle::TYPE_VOIDP)
      address = mmap.call(nil, missing, 0, RESERVE_FLAGS, -1, 0).to_i
      raise "mmap of #{missing} bytes failed" if address == -1 || address == 2**64 - 1
    end

    # Plays a scenario in its children.
    #
    # @param scenario [Scenario] The scenario.
    # @return [Array<Hash>] What each child reported: :results, :marks, :output, :status.
    def play(scenario)
      path = @paths.fetch(scenario.lib)
      children = Array.new(scenario.children) { fork_child(scenario, path) }
      children.map { |child| Thread.new { watch(child) } }.map(&:value)
    end

    # Forks a child that plays the scenario, or, with a parent in it, a child that loads the
    # library and forks the child that plays it.
    #
    # @param scenario [Scenario] The scenario.
    # @param path [String] The library.
    # @return [Child] The child.
    def fork_child(scenario, path)
      Child.new do |report, ack|
        run = Run.new(scenario, path, @root, report, ack)
        next run.play unless scenario.parent

        run.environment
        handle = run.load
        run.start(Core.new(handle)) if scenario.parent == :started
        grandchild = Process.fork { run.play(handle, started: scenario.parent == :started) || Process.exit!(0) }
        run.finish(grandchild: wait(grandchild, GRANDCHILD_SECONDS))
      end
    end

    # Waits on a process, killing it after a time.
    #
    # @param pid [Integer] The process.
    # @param seconds [Integer] How long to wait.
    # @return [String] How it ended.
    def wait(pid, seconds)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      loop do
        _, status = Process.wait2(pid, Process::WNOHANG)
        return describe(status) if status

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          Process.kill(:KILL, pid)
          Process.wait(pid)
          return "hung, killed after #{seconds} s"
        end
        sleep(0.1)
      end
    end

    # Follows a child: measures it at each mark, collects its results and output, and waits on it.
    #
    # @param child [Child] The child.
    # @return [Hash] :results, :marks, :output and :status.
    def watch(child)
      output = Thread.new { child.output.each_line.to_a }
      seen = { results: [], marks: [] }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + CHILD_SECONDS
      while (line = next_line(child.report, deadline))
        message = JSON.parse(line)
        if message["mark"]
          seen[:marks] << [message["mark"], memory(message["pid"])]
          child.ack.puts
        else
          seen[:results] << message["result"]
        end
      end
      seen[:status] = line == false ? kill(child.pid) : describe(Process.wait2(child.pid).last)
      seen.merge(output: output.value)
    end

    # Reads a line from a pipe until a deadline.
    #
    # @param pipe [IO] The pipe.
    # @param deadline [Float] The monotonic clock's time.
    # @return [String, nil, false] The line, nil at its end, false past the deadline.
    def next_line(pipe, deadline)
      left = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return false unless left.positive? && IO.select([pipe], nil, nil, left)

      pipe.gets
    end

    # Kills a child that took too long.
    #
    # @param pid [Integer] The child.
    # @return [String] How it ended.
    def kill(pid)
      Process.kill(:KILL, pid)
      Process.wait(pid)
      "timed out, killed after #{CHILD_SECONDS} s"
    end

    # Describes how a process ended.
    #
    # @param status [Process::Status] Its status.
    # @return [String] The description.
    def describe(status)
      status.signaled? ? "killed by signal #{Signal.signame(status.termsig)}" : "exit #{status.exitstatus}"
    end

    # Prints a scenario's details and makes its row of the summary.
    #
    # @param scenario [Scenario] The scenario.
    # @param children [Array<Hash>] What its children reported.
    # @return [Array<String>] The row.
    def report(scenario, children)
      puts
      puts("== #{scenario.name}")
      children.each_with_index do |child, index|
        puts("child #{index + 1}: #{child[:status]}")
        child[:marks].each { |label, memory| puts("  #{label.ljust(16)} #{format_memory(memory)}") }
        child[:results].each do |result|
          result = result.merge("info" => result["info"].slice(*INFO_KEYS)) if result["info"]
          puts("  result: #{JSON.generate(result)}")
        end
        child[:output].first(20).each { |line| puts("  output: #{line}") }
      end
      row(scenario, children.first)
    end

    # Makes a scenario's row of the summary from its first child.
    #
    # @param scenario [Scenario] The scenario.
    # @param child [Hash] What the child reported.
    # @return [Array<String>] The row.
    def row(scenario, child)
      result = child[:results].find { |found| found.key?("echo") || found.key?("error") } || child[:results].last || {}
      last = child[:marks].last&.last || {}
      info = result["info"] || {}
      [scenario.name, outcome(child, result), result["load_ms"], result["start_ms"], mb(last[:VmSize]),
       mb(last[:Private]), last[:Threads], info["gc.GCHeapHardLimit"], info["latency"]].map { |cell| cell.nil? ? "-" : cell.to_s }
    end

    # Sums a child's run up in a few words.
    #
    # @param child [Hash] What the child reported.
    # @param result [Hash] The result of the child that called the library.
    # @return [String] The outcome.
    def outcome(child, result)
      return result["error"] if result["error"]

      grandchild = child[:results].map { |found| found["grandchild"] }.compact.first
      unless result["alive"]
        stuck = child[:marks].last&.first
        return "#{grandchild || child[:status]} after the mark #{stuck.inspect}"
      end

      fits = result["fits"] || {}
      past = result["past_limit"] || {}
      works = result["echo"] && fits["oom"] == "0" && fits["finalized"] == "100" && fits["thread"] == "499999500000"
      "#{works ? 'works' : 'FAILS'}; past the limit: #{past['oom'] == '1' ? "out of memory at #{past['kept_mb']} MB, caught" : "kept #{past['kept_mb']} MB"}"
    end

    # Reads a process's memory and threads.
    #
    # @param pid [Integer] The process.
    # @return [Hash{Symbol => Integer}] :VmSize, :VmRSS, :VmHWM, :Private (kB) and :Threads.
    def memory(pid)
      status = File.read("/proc/#{pid}/status")
      found = %i[VmSize VmRSS VmHWM Threads].to_h { |key| [key, status[/^#{key}:\s+(\d+)/, 1].to_i] }
      rollup = File.read("/proc/#{pid}/smaps_rollup")
      found[:Private] = %w[Private_Clean Private_Dirty].sum { |key| rollup[/^#{key}:\s+(\d+)/, 1].to_i }
      found
    rescue SystemCallError
      {}
    end

    # Writes memory in megabytes.
    #
    # @param memory [Hash] See memory.
    # @return [String] The text.
    def format_memory(memory)
      return "gone" if memory.empty?

      "VmSize #{mb(memory[:VmSize])} MB, RSS #{mb(memory[:VmRSS])} MB, private #{mb(memory[:Private])} MB, " \
        "peak RSS #{mb(memory[:VmHWM])} MB, threads #{memory[:Threads]}"
    end

    # Turns kilobytes into megabytes.
    #
    # @param kilobytes [Integer, nil] The kilobytes.
    # @return [Integer, nil] The megabytes.
    def mb(kilobytes)
      kilobytes && (kilobytes / 1024.0).round
    end
  end
end

ServerCoreProbe.run(*ARGV.first(2)) if $PROGRAM_NAME == __FILE__ && ARGV.size == 2
