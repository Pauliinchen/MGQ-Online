#----------------------------------------------------------------
#  support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Kept a message sent as the scripts hand it instead of writing and reading it as a copy of the DLL's codec
#                            - Handed the Classic party's table recorded in fixtures/story/classic.json instead of building it as a copy of the C# one
#                            - Handed the story tables' self switch rules as the DLL's rows
#                            - Wrote and read each message field by its kind, as the DLL's MessageFields does
#                            - Dropped the export table's checks and wrote messages as the DLL does for the stand-ins of the world room and the battle channel
#                            - Loaded the story's ids with the table the DLL hands
#                            - Let a test move the scripts' clock, the bridge's frame, by hand
#      Paulinchen  2026-11-01: Stood in for a wheel of the Mod Framework
#      Paulinchen  2026-10-31: Loaded the Mod Framework's scripts before the mod's, as the game does
#      Paulinchen  2026-10-28: Stood in for the game's sizes and chest flags the DLL reads from its events database
#                            - Kept the script's own Classic party's table for the test that builds it
#      Paulinchen  2026-10-24: Counted the key frames as the tests count the game's
#      Paulinchen  2026-10-23: Loaded the bridge, closed, with the first script
#                            - Loaded story_keys.rbx after story_state.rbx, with the Classic party's table the DLL builds
#                            - Stood in for a Raid World's story mapping with a table of the earlier Raid personal lists
#      Paulinchen  2026-10-13: Named the mod folder as Multiplayer.rb does
#      Paulinchen  2026-10-12: Collected the log lines a block writes
#      Paulinchen  2026-10-08: Stood in for watching keys
#      Paulinchen  2026-10-07: Read each DLL export's signature from the table in Multiplayer.rb
#      Paulinchen  2026-10-06: Refused a DLL call whose arguments differ from its signature
#                            - Loaded Zlib
#      Paulinchen  2026-10-04: Followed the scripts to their new names
#      Paulinchen  2026-10-03: Loaded core_game_access.rbx before the first script too
#                            - Loaded core_log.rbx before the first script too
#      Paulinchen  2026-10-02: Loaded core_hooks.rbx before the first script
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# What every test file shares: checks that count and report, and loading the mod's scripts outside
# RGSS. Each test file runs in a Ruby process of its own (see run.rb), since each brings its own
# stand-ins for the game.

# RGSS has Zlib built in, which the scripts use as it is.
require "zlib"
require "json"

# Folder of the mod's scripts in the repository.
SCRIPTS_DIR = File.expand_path("../Multiplayer/Scripts", __dir__)

# The Mod Framework, whose keys, look and boxes the mod's scripts use as they load.
require_relative "framework_support"

# The mod folder as Multiplayer.rb names it, which the scripts build their files' paths on.
module MGQ_Multiplayer; MOD_DIR = "Patch\\Multiplayer"; end

# Stands in for a wheel of the Mod Framework, for a test that loads no wheel: open while its block
# answers true.
StandInWheel = Struct.new(:block) do
  # Answers whether the wheel is open.
  def open?; block.call ? true : false; end
end

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

# A message as the scripts hand it to the DLL to send (world.send, served.send and the like), for the
# stand-ins of the world room and the battle channel: its fields by name as handed, its body under
# :payload. The C# tests own how the DLL writes and reads a message.
#
# @param fields [Hash] The fields.
# @param body [String] The body.
# @return [Hash] The message.
def sent_message(fields, body = "")
  message = {}
  fields.each { |key, value| message[key.to_s] = value }
  message[:payload] = body.to_s
  message
end

# Collects the log lines a block writes, then lets the log write as before.
#
# @yield The block whose log lines are collected.
# @return [Array<String>] The lines.
def logged_lines
  lines = []
  writer = MGQ_Multiplayer::Log.method(:write)
  MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| lines << line }
  begin
    yield
  ensure
    MGQ_Multiplayer::Log.define_singleton_method(:write, writer)
  end
  lines
end

# Loads MGQ_Multiplayer::Bridge out of Multiplayer.rb, as the game has it, closed until a test opens
# it with a FakeBridge (bridge_support.rb).
def load_bridge
  source = File.read(File.expand_path("../Multiplayer.rb", __dir__), :encoding => "UTF-8")
  MGQ_Multiplayer.module_eval(source[/  module Bridge\n.*?\n  end\n/m])
end

# Makes the scripts' clock, the bridge's frame, read a test's own count, for a test that moves
# time by hand.
#
# @yieldreturn [Integer] The frame.
def clock_from(&count)
  load_bridge unless defined?(MGQ_Multiplayer::Bridge)
  MGQ_Multiplayer::Bridge.define_singleton_method(:frame_number) { count.call.to_i }
end

# Loads one of the mod's scripts as Multiplayer.rb does, from GameScript/Multiplayer/Scripts, after
# core_log.rbx, core_hooks.rbx and core_game_access.rbx, which every script builds on, and with the
# bridge, closed, and the story's ids (see load_story_ids).
#
# @param name [String] The script's name without its extension, such as "coop".
def load_script(name)
  load_bridge unless defined?(MGQ_Multiplayer::Bridge)
  load File.join(SCRIPTS_DIR, "core_log.rbx") unless defined?(MGQ_MpLog)
  load File.join(SCRIPTS_DIR, "core_hooks.rbx") unless defined?(MGQ_MpHooks) || name == "core_log"
  load File.join(SCRIPTS_DIR, "core_game_access.rbx") unless defined?(MGQ_MpGame) || name == "core_log"
  load_story_ids unless defined?(MGQ_MpStoryIds) || name.start_with?("core_")
  load File.join(SCRIPTS_DIR, "#{name}.rbx")
  load_story_keys if name == "story_state"
end

# The story's ids as the DLL hands them (topic story.ids): the relay's copy, which the generator
# writes from MGQOnline.Game's StoryIds and MGQOnline.Game.Tests holds to it.
STORY_IDS_FILE = File.expand_path("../../Relay/core/story_ids.json", __dir__)

# Loads story_ids.rbx with the table the DLL would hand, so no test needs the DLL for the story's ids.
def load_story_ids
  require "json"
  load File.join(SCRIPTS_DIR, "story_ids.rbx")
  MGQ_MpStoryIds.instance_variable_set(:@table, JSON.parse(File.read(STORY_IDS_FILE)).freeze)
end

# Folder of the story's golden cases, which MGQOnline.Game.Tests checks too.
STORY_FIXTURES = File.expand_path("../../fixtures/story", __dir__)

# Loads story_keys.rbx, which Multiplayer.rb loads right after story_state.rbx, with the recorded
# Classic party's table the DLL hands (see classic_table_hash), so no test needs the DLL to tell
# what a party shares; the script's own fetch stays as bridge_classic_table for the test that
# checks it.
def load_story_keys
  load File.join(SCRIPTS_DIR, "story_keys.rbx")
  MGQ_MpStoryKeys.singleton_class.send(:alias_method, :bridge_classic_table, :classic_table)
  MGQ_MpStoryKeys.define_singleton_method(:classic_table) { @classic ||= table_of(classic_table_hash) }
end

# The Classic party's table the DLL hands (topic story.classic_table) as fixtures/story/classic.json
# recorded it for the game's sizes, with the chest flags 7102 to 7104; StoryTableTests holds the C#
# to that recording.
#
# @return [Hash] The table, see story_table_hash.
def classic_table_hash
  fixture = JSON.parse(File.read(File.join(STORY_FIXTURES, "classic.json")))
  story_table_hash(fixture["switches"], fixture["variables"], fixture["self_default"])
end

# Builds a story table as the DLL hands it (StoryTopics.TableOf).
#
# @param switches [Array<Array>] The switches' classes as runs, each [from, to, class].
# @param variables [Array<Array>] The variables' classes alike.
# @param self_default [Integer] The class of a self switch no rule names.
# @param rest [Hash] The table's other fields, such as "self" and "common" (the self switch rules'
#   rows), "index" or "rev".
# @return [Hash] The table.
def story_table_hash(switches, variables, self_default = 0, rest = {})
  bytes = lambda do |runs|
    text = "".force_encoding("ASCII-8BIT")
    runs.each { |from, to, found| text << ([found].pack("C") * (to - from + 1)) }
    text
  end
  { "rev" => 0, "switches" => bytes.call(switches), "variables" => bytes.call(variables), "self" => [], "common" => [], "index" => [], "local_steps" => [],
    "gates" => {}, "self_default" => self_default }.merge(rest)
end

at_exit { Checks.finish($!) }

# The switches the Raid personal lists of earlier builds kept each player's own, beside a Classic
# party's: the refusal of recruits, a special boss's NORMAL, the Colosseum and its match, the
# Labyrinth, the collab's hidden key items, the final battles' NORMAL and the castle's tour.
LISTED_RAID_SWITCHES = [3, 23, 28, 41, 87, 504, 507, 2013, 2015]

# The variables alike: the difficulty's rates, the Ruler Ruler's, the Labyrinth's, the difficulty
# and its records.
LISTED_RAID_VARIABLES = [[41, 45], [49, 49], [92, 99], [121, 121], [123, 123], [149, 149], [151, 151], [902, 903], [906, 906], [908, 908]]

# Builds a story mapping's table that keeps what the Raid personal lists of earlier builds shared,
# for the checks of a Raid World whose events must still sort as story: the recorded Classic
# party's table with the side switches, LISTED_RAID_SWITCHES and LISTED_RAID_VARIABLES each
# player's own.
#
# @param scene [Array<Integer>] The scene switches.
# @return [Hash] The table, see story_table_hash.
def listed_raid_table_hash(scene = [])
  table = classic_table_hash
  switches = table["switches"].unpack("C*")
  variables = table["variables"].unpack("C*")
  ([4, 5] + LISTED_RAID_SWITCHES).each { |id| switches[id] = 0 if id < switches.size }
  scene.each { |id| switches[id] = 4 if id < switches.size }
  LISTED_RAID_VARIABLES.each { |from, to| (from..to).each { |id| variables[id] = 0 if id < variables.size } }
  table.merge("rev" => 1, "switches" => switches.pack("C*"), "variables" => variables.pack("C*"))
end

# Gives story_keys.rbx a Raid World's story mapping, see listed_raid_table_hash.
#
# @param scene [Array<Integer>] The scene switches.
def use_listed_raid_table(scene = [])
  MGQ_MpStoryKeys.instance_variable_set(:@raid, MGQ_MpStoryKeys.table_of(listed_raid_table_hash(scene)))
end

