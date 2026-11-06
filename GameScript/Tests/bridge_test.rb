#----------------------------------------------------------------
#  bridge_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Took half_loaded? along with available?, which asks it
#                            - Cleared the request it refuses on purpose, which would fail the file at its end
#      Paulinchen  2026-11-05: Checked that the events of a topic no script takes yet are held until one does
#                            - Checked that a DLL that does not load is logged by what happened, never as older
#                            - Started the mod with the bridge alone, the DLL starting as it shakes hands
#      Paulinchen  2026-10-31: Checked that the mod runs only beside a Mod Framework of at least the version it requires, with its DLL
#      Paulinchen  2026-10-23: Stood in for the log's hand-over once the start decided
#                            - Checked that only a handshake turns the mod on
#                            - Created
#                            - Stood in without the deleted mod switch
#
#----------------------------------------------------------------

# Covers MGQ_Multiplayer::Bridge, the scripts' side of the bridge to C#, against FakeBridge: the
# handshake that turns the mod on or keeps it off, calls and their errors, what a frame stages
# going over as one batch, the drain's events reaching their handlers, and the buffers growing.

require_relative "bridge_support"
require "fileutils"
require "tmpdir"

source = File.read(File.expand_path("../Multiplayer.rb", __dir__), :encoding => "UTF-8")
load_bridge
bridge = MGQ_Multiplayer::Bridge

# Stands in for the game's Win32API: the bridge's exports reach $dll through the arguments their
# signatures name; loading one fails while $exports_missing, as with an older DLL, or while
# $dll_broken, as with a DLL Windows cannot load.
class Win32API
  # The export each name reaches on $dll.
  METHODS = { "mp_bridge_open" => :open, "mp_call" => :call, "mp_reply" => :reply, "mp_drain" => :drain }

  # Loads an export.
  #
  # @param _path [String] The DLL.
  # @param name [String] The export.
  # @param arguments [String] Its arguments in Win32API notation.
  # @param _result [String] Its result.
  def initialize(_path, name, arguments, _result)
    raise "GetProcAddress failed for #{name}" if $exports_missing
    raise "LoadLibrary failed for #{_path}" if $dll_broken

    @name = name
    @arguments = arguments
  end

  # Calls the export, refusing arguments its signature does not name, as RGSS does.
  #
  # @param args [Array] The arguments.
  # @return [Integer] What the export answers.
  def call(*args)
    kinds = args.map { |arg| arg.is_a?(Integer) ? "l" : arg.is_a?(String) ? "p" : "?" }.join
    raise "#{@name} takes #{@arguments}, got #{kinds}" if kinds != @arguments

    $dll.public_send(METHODS.fetch(@name), *args)
  end
end

# The start: the mod is on only once the bridge opened, and off with one line otherwise.
module MGQ_Multiplayer
  DLL = "Multiplayer.dll"
  # Builds a path in the mod folder.
  def self.path(name); "#{MOD_DIR}\\#{name}"; end
  # Stands in for the log's hand-over once the start decided.
  module Log; def self.settle(_open); end; end
  # Stands in for the update check, noted in $steps.
  module UpdateCheck; def self.start; $steps << :update_check; end; end
end
MGQ_Multiplayer.module_eval(source[/  MOD_FRAMEWORK_REQUIRED = .*\n/])
MGQ_Multiplayer.module_eval(source[/  def self\.available\?\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  def self\.half_loaded\?\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  def self\.framework_ready\?\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  def self\.framework_gap\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  def self\.start\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  def self\.open_dll\n.*?\n  end\n/m])

# Starts the mod as the game does, once per session.
#
# @param dll [Object] What the DLL's exports reach.
# @return [Array] Whether the mod is available, the log's last line and the steps that ran.
def start_mod(dll)
  $dll = dll
  $steps = []
  MGQ_Multiplayer.instance_variable_set(:@started, nil)
  MGQ_Multiplayer.instance_variable_set(:@available, nil)
  lines = logged_lines { MGQ_Multiplayer.start }
  [MGQ_Multiplayer.available?, lines.last, $steps]
end

# A DLL that answers 0 to everything, as JoiPlay's stand-in does.
stand_in = Class.new { def open(*); 0; end }.new

Dir.mktmpdir do |game|
  Dir.chdir(game) do
    check("a missing DLL keeps the mod off", start_mod(FakeBridge.new), [false, "not started: Patch\\Multiplayer\\Multiplayer.dll is missing", []])
    FileUtils.mkdir_p(File.join("Patch", "Multiplayer"))
    File.write(MGQ_Multiplayer.path(MGQ_Multiplayer::DLL), "")
    $exports_missing = true
    available, line, steps = start_mod(FakeBridge.new)
    check("an older DLL without the bridge keeps the mod off with one line", [available, line[/\Abridge: the mod stays off, could not load .*GetProcAddress.*, so it is older than these scripts\z/] ? true : line, steps], [false, true, []])
    $exports_missing = false
    $dll_broken = true
    available, line, = start_mod(FakeBridge.new)
    check("a DLL that does not load keeps the mod off, logged by what happened",
          [available, line.include?("could not load Patch\\Multiplayer\\Multiplayer.dll or find its bridge exports: RuntimeError: LoadLibrary failed"), line.include?("older")], [false, true, false])
    $dll_broken = false
    check("a stand-in DLL keeps the mod off", start_mod(stand_in), [false, "bridge: the mod stays off, the DLL answered no handshake, as a stand-in DLL does", []])
    check("a DLL of another bridge version keeps the mod off",
          start_mod(FakeBridge.new(MGQ_Multiplayer::Bridge::VERSION + 1)),
          [false, "bridge: the mod stays off, the DLL refused the handshake: The scripts speak bridge version 1, the core version 2.", []])
    Mod_Framework.available = true
    check("a handshake turns the mod on beside the Mod Framework and only then starts the rest",
          start_mod(FakeBridge.new), [true, "started Patch\\Multiplayer\\Multiplayer.dll", [:update_check]])
    Mod_Framework.available = false
    check("without the Mod Framework's DLL the mod stays off", MGQ_Multiplayer.available?, false)
    Mod_Framework.available = true
    at_least = Mod_Framework.method(:at_least?)
    Mod_Framework.define_singleton_method(:at_least?) { |version| version.to_s == "0.0.9" }
    check("so it does beside a Mod Framework older than the one it requires", [MGQ_Multiplayer::MOD_FRAMEWORK_REQUIRED, MGQ_Multiplayer.available?], ["0.1.0", false])
    Mod_Framework.define_singleton_method(:at_least?, at_least)
    Mod_Framework.available = false
  end
end

# Calls: the value as it crossed, nil for none, errors logged once and plain values only.
fake = FakeBridge.new
fake.answer("test.echo") { |request| request }
fake.answer("test.quiet") { |_request| nil }
bridge.open(fake)
request = { "seat" => 2, 1001 => [true, nil, "ルカ", -(2**40)], "raw" => "\xFF".force_encoding("ASCII-8BIT") }
check("a call hands back the topic's value as it crossed, Integer keys and encodings included", bridge.call("test.echo", request), request)
check("a topic that answers nothing gives nil", bridge.call("test.quiet", "x"), nil)
check("the handshake tells which topics the DLL answers", [bridge.has?("test.echo"), bridge.has?("batch"), bridge.has?("story.none")], [true, true, false])
lines = logged_lines { 2.times { bridge.call("no.such.topic", { "seat" => 2 }) } }
check("an error gives nil and is logged once per topic and code", lines, ["bridge: no.such.topic failed with unknown_topic: There is no topic no.such.topic."])
check("the request has the bytes of the contract fixture", fake.calls.last, ["no.such.topic", bridge_fixture("envelope/unknown_topic", "request")])
reply = "\0".b * 256
length = fake.call(bridge.instance_variable_get(:@context), "no.such.topic\0", fake.calls.last[1], fake.calls.last[1].bytesize, reply, reply.bytesize)
check("the stand-in answers in the bytes the core does", reply[0, length], bridge_fixture("envelope/unknown_topic", "reply"))
lines = logged_lines { check("a request the game would refuse gives nil", bridge.call("test.echo", { :seat => 2 }), nil) }
check("and the log names what cannot cross", lines, ["bridge: test.echo failed with bad_request: The Symbol :seat cannot cross the bridge."])
FakeBridge.refused.clear
raised = begin
  bridge.call!("no.such.topic")
rescue MGQ_Multiplayer::Bridge::Error => e
  e.message
end
check("call! raises the error instead", raised, "no.such.topic answered unknown_topic: There is no topic no.such.topic.")

# A frame: what was staged goes over as one batch, in order, and failed entries are logged once.
appended = []
fake.answer("test.append") do |text|
  raise FakeBridge::BadRequest, "Expected a String, found an Integer." unless text.is_a?(String)

  appended << text
  nil
end
calls = fake.calls.size
%w[a b c].each { |text| bridge.stage("test.append", text) }
check("staging calls nothing until the frame", fake.calls.size, calls)
bridge.frame
check("the frame sends everything staged as one batch, in the bytes of the contract fixture",
      [fake.calls.size - calls, fake.calls.last], [1, ["batch", bridge_fixture("batch/in_order", "request")]])
check("whose entries run in order", appended, %w[a b c])
bridge.frame
check("a frame with nothing staged makes no call", fake.calls.size - calls, 1)
fake.answer_bytes("batch", bridge_fixture("batch/failed_entries", "reply"))
# A new handshake forgets the failures logged so far.
bridge.open(fake)
lines = logged_lines { 2.times { bridge.stage("test.append", "x"); bridge.frame } }
check("each failed entry the batch answers is logged once per topic and code", lines,
      ["bridge: no.such.topic failed with unknown_topic: There is no topic no.such.topic.", "bridge: test.append failed with bad_request: Expected a String, found an Integer."])

# The drain: events reach every handler of their topic in order, with the bridge's own frames.
fake = FakeBridge.new
bridge.open(fake)
got = []
bridge.on("test.push") { |payload| got << payload }
bridge.on("test.push") { |payload| got << "second #{payload['n']}" }
fake.post("test.push", { "n" => 1 })
fake.post("test.push", { "n" => 2 })
bridge.frame
check("a frame hands each event to its topic's handlers in order", got, [{ "n" => 1 }, "second 1", { "n" => 2 }, "second 2"])
bridge.on("test.broken") { |_payload| raise "broken handler" }
bridge.on("test.broken") { |payload| got << payload }
lines = logged_lines do
  2.times do
    fake.post("test.nobody", 1)
    fake.post("test.broken", 3)
    bridge.frame
  end
end
check("a failing handler is logged once, and the other handlers still run", [lines, got.last(2)], [["bridge: test.broken failed with handler: RuntimeError: broken handler"], [3, 3]])
late = []
bridge.on("test.nobody") { |payload| late << payload }
bridge.frame
check("the events of a topic nobody took are held until a script takes them, in order", late, [1, 1])
lines = logged_lines do
  (MGQ_Multiplayer::Bridge::HELD_EVENTS + 2).times { |n| fake.post("test.unloaded", n) }
  bridge.frame
end
bridge.on("test.unloaded") { |payload| late << payload }
bridge.frame
check("past the most held, the newest are kept and the drop is logged once",
      [lines, late.size - 2, late.last], [["bridge: test.unloaded failed with no_handler: no script takes its events, so only the newest #{MGQ_Multiplayer::Bridge::HELD_EVENTS} are held"], MGQ_Multiplayer::Bridge::HELD_EVENTS, MGQ_Multiplayer::Bridge::HELD_EVENTS + 1])
check("the drain passes the bridge's own frame count, one more each frame", fake.frames, [1, 2, 3, 4, 5, 6])

# The buffers: a reply or a drain larger than the buffer comes through a grown one, which stays.
big = "x" * 10_000
fake.answer("test.big") { |_request| big }
needed = Marshal.dump({ "ok" => true, "value" => big }).bytesize
sizes = fake.sizes.size
first = bridge.call("test.big")
second = bridge.call("test.big")
check("a reply larger than the buffer comes through a grown buffer, which the next call keeps",
      [first == big, second == big, fake.sizes[sizes..-1]], [true, true, [MGQ_Multiplayer::Bridge::REPLY_SIZE, needed, needed]])
fake.post("test.push", { "n" => "y" * 20_000 })
bridge.frame
check("events larger than the drain buffer come through a grown one in the same frame",
      [got[-2].is_a?(Hash) && got[-2]["n"].size, fake.frames.last(2)], [20_000, [7, 7]])

# Closed: nothing is staged, a frame calls nothing and a call gives nil.
bridge.close
calls = fake.calls.size
bridge.stage("test.append", "late")
bridge.frame
check("a closed bridge stages nothing, its frame calls nothing and a call gives nil", [bridge.call("test.echo", 1), fake.calls.size - calls], [nil, 0])

# The signatures the scripts load the exports with are those of MGQOnline.Bridge.Native.
exports = File.read(File.expand_path("../../MGQOnline.Bridge.Native/BridgeExports.cs", __dir__), :encoding => "UTF-8")
exported = exports.scan(/EntryPoint = "(mp_[a-z_]+)".*?\n\s*public static int \w+\(([^)]*)\)/m).map do |name, parameters|
  [name, parameters.split(",").map { |parameter| parameter.strip.start_with?("int ") ? "l" : "p" }.join]
end
check("the bridge loads each export with the arguments it takes", Hash[exported], MGQ_Multiplayer::Bridge::Win32Backend::SIGNATURES)
