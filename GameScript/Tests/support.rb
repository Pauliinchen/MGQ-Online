#----------------------------------------------------------------
#  support.rb
#
#  Changelog:
#      Paulinchen  2026-10-07: Read each DLL export's signature from the table in Multiplayer.rb, as Link does, so a stand-in refuses an export the table lacks
#      Paulinchen  2026-10-06: Refused a DLL call whose arguments differ from its signature, as RGSS does
#                            - Loaded Zlib, which RGSS has built in
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Loaded core_game_access.rbx before the first script too
#                            - Loaded core_log.rbx before the first script too
#      Paulinchen  2026-10-02: Loaded core_hooks.rbx before the first script, as Multiplayer.rb does
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# What every test file shares: checks that count and report, and loading the mod's scripts outside
# RGSS. Each test file runs in a Ruby process of its own (see run.rb), since each brings its own
# stand-ins for the game.

# RGSS has Zlib built in, which the scripts use as it is.
require "zlib"

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

# The DLL's exports and their Win32API signatures, as Multiplayer.rb's Link names them.
DLL_EXPORTS = begin
  source = File.read(File.expand_path("../Multiplayer.rb", __dir__), :encoding => "UTF-8")
  eval(source[/    READ_ARGUMENTS = '.*?'\n/] + source[/    EXPORTS = \{.*?\n    \}\n/m])
end

# Finds a DLL export's signature in the table of Multiplayer.rb, failing the test for an export
# the table lacks, as Link.function would.
#
# @param name [String] The export.
# @return [String] Its arguments in Win32API notation, "v" for none.
def dll_signature(name)
  DLL_EXPORTS.fetch(name) do
    check("#{name} is an export the table in Multiplayer.rb names", DLL_EXPORTS.key?(name), true)
    raise KeyError, "key not found: #{name}"
  end
end

# Refuses a call to a DLL function whose arguments differ in number from its Win32API signature,
# as RGSS does, so a stand-in for Win32API fails the test where the game would fail.
#
# @param name [String] The function.
# @param args [Array] The arguments of the call.
def check_dll_call(name, args)
  signature = dll_signature(name)
  expected = signature == "v" ? 0 : signature.size
  return if args.size == expected

  check("#{name} gets the #{expected} argument(s) its signature #{signature} names", args.size, expected)
  raise "wrong number of parameters: expected #{expected}, got #{args.size}"
end

# Loads one of the mod's scripts as Multiplayer.rb does, from GameScript/Multiplayer/Scripts, after
# core_log.rbx, which gives the scripts their log, and core_hooks.rbx, which they register their hooks
# with.
#
# @param name [String] The script's name without its extension, such as "coop".
def load_script(name)
  load File.join(SCRIPTS_DIR, "core_log.rbx") unless defined?(MGQ_MpLog)
  load File.join(SCRIPTS_DIR, "core_hooks.rbx") unless defined?(MGQ_MpHooks) || name == "core_log"
  load File.join(SCRIPTS_DIR, "core_game_access.rbx") unless defined?(MGQ_MpGame) || name == "core_log"
  load File.join(SCRIPTS_DIR, "#{name}.rbx")
end

at_exit { Checks.finish($!) }
