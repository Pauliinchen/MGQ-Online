#----------------------------------------------------------------
#  support.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Loaded MGQ Online's bridge to C# out of Multiplayer.rb for the core's tests
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# What every test file of the battle server shares: checks that count and report. Each test file
# runs in a Ruby process of its own (see run.rb), since the server's libraries change Ruby itself.

# The battle server's libraries.
LIB_DIR = File.expand_path("../lib", __dir__)

# The recorded data the tests compare with.
FIXTURES_DIR = File.expand_path("fixtures", __dir__)

# MGQ Online's script that holds its bridge to C#.
MULTIPLAYER_RB = File.expand_path("../../GameScript/Multiplayer.rb", __dir__)

# Counts a test file's checks and reports them once the file ends.
module Checks
  @count = 0
  @failures = 0
  @skipped = nil

  class << self
    # Compares a value with the expected one and prints the result.
    #
    # @param label [String] What is checked.
    # @param actual [Object] What came out.
    # @param expected [Object] What should have.
    def check(label, actual, expected)
      @count += 1
      ok = actual == expected
      @failures += 1 unless ok
      puts "#{ok ? 'ok  ' : 'FAIL'} #{label}#{ok ? '' : ": #{actual.inspect} (expected #{expected.inspect})"}"
    end

    # Notes that the file's checks did not run, and why.
    #
    # @param reason [String] Why.
    def skip(reason)
      @skipped = reason
    end

    # Prints how many checks ran and how many failed, and ends the process with 1 when one failed.
    #
    # @param error [Exception, nil] What stopped the file early, nil when it ran to its end.
    def finish(error)
      return puts("skipped: #{@skipped}") if @skipped && @count.zero?

      stopped = error && !error.is_a?(SystemExit) ? ", stopped by #{error.class}: #{error.message}" : ""
      puts "#{@count} checks, #{@failures.zero? ? 'all passed' : "#{@failures} FAILED"}#{stopped}"
      exit(1) unless @failures.zero? && stopped.empty?
    end
  end
end

# Checks a value, see Checks.check.
#
# @param label [String] What is checked.
# @param actual [Object] What came out.
# @param expected [Object] What should have.
def check(label, actual, expected)
  Checks.check(label, actual, expected)
end

# Runs a block and tells what it raised, nil for nothing.
#
# @return [Exception, nil] The error.
def raised
  yield
  nil
rescue Exception => e
  raise if e.is_a?(Interrupt)

  e
end

# The game folder for the tests that play battles, from BATTLE_GAME_DIR, or nil without one.
#
# @return [String, nil] The folder.
def game_dir
  dir = ENV["BATTLE_GAME_DIR"]
  dir && File.directory?(File.join(dir, "Data")) ? dir : nil
end

# Loads MGQ_Multiplayer::Bridge out of Multiplayer.rb, as the game folder's MGQ Online has it, with
# a log that keeps its lines.
#
# @return [Array<String>] The lines MGQ Online's log takes from now on.
def load_mgq_bridge
  lines = []
  log = Module.new
  log.define_singleton_method(:write) { |line| lines << line }
  Object.const_set(:MGQ_Multiplayer, Module.new) unless defined?(MGQ_Multiplayer)
  MGQ_Multiplayer.const_set(:Log, log)
  source = File.read(MULTIPLAYER_RB, encoding: "UTF-8")
  MGQ_Multiplayer.module_eval(source[/  module Bridge\n.*?\n  end\n/m])
  lines
end

at_exit { Checks.finish($!) }
