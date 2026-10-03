#----------------------------------------------------------------
#  support.rb
#
#  Changelog:
#      Paulinchen  2026-10-03: Loaded mp_log.rbx before the first script too
#      Paulinchen  2026-10-02: Loaded mp_hooks.rbx before the first script, as Multiplayer.rb does
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# What every test file shares: checks that count and report, and loading the mod's scripts outside
# RGSS. Each test file runs in a Ruby process of its own (see run.rb), since each brings its own
# stand-ins for the game.

# Folder of the mod's scripts in the repository.
SCRIPTS_DIR = File.expand_path("../Multiplayer/Scripts", __dir__)

# Counts a test file's checks and reports them once the file ends.
module Checks
  @count = 0
  @failures = 0

  # Compares a value with the expected one and prints the result.
  #
  # @param label [String] What is checked.
  # @param actual [Object] What came out.
  # @param expected [Object] What should have.
  def self.check(label, actual, expected)
    @count += 1
    ok = actual == expected
    @failures += 1 unless ok
    puts "#{ok ? 'ok  ' : 'FAIL'} #{label}#{ok ? '' : ": #{actual.inspect} (expected #{expected.inspect})"}"
  end

  # Prints how many checks ran and how many failed, and ends the process with 1 when one failed.
  #
  # @param error [Exception, nil] What stopped the file early, nil when it ran to its end.
  def self.finish(error)
    stopped = error && !error.is_a?(SystemExit) ? ", stopped by #{error.class}: #{error.message}" : ""
    puts "#{@count} checks, #{@failures.zero? ? 'all passed' : "#{@failures} FAILED"}#{stopped}"
    exit(1) unless @failures.zero?
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

# Loads one of the mod's scripts as Multiplayer.rb does, from GameScript/Multiplayer/Scripts, after
# mp_log.rbx, which gives the scripts their log, and mp_hooks.rbx, which they register their hooks
# with.
#
# @param name [String] The script's name without its extension, such as "mp_coop".
def load_script(name)
  load File.join(SCRIPTS_DIR, "mp_log.rbx") unless defined?(MGQ_MpLog)
  load File.join(SCRIPTS_DIR, "mp_hooks.rbx") unless defined?(MGQ_MpHooks) || name == "mp_log"
  load File.join(SCRIPTS_DIR, "#{name}.rbx")
end

at_exit { Checks.finish($!) }
