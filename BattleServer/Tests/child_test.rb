#----------------------------------------------------------------
#  child_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Covered the battle a child without the core refuses
#                            - Covered which core library a child loads and the order it loads, closes in and shakes hands
#                            - Created
#
#----------------------------------------------------------------

# Tests of how server.rb prepares a battle's child before it plays, with stand-ins for the sandbox
# and the core library: which library it loads, that it loads it before the sandbox and shakes
# hands after it, what the client hears when the child cannot be closed in, the core's log, and the
# relay's refusal of a battle while the core does not answer.

require "fileutils"
require "json"
require "socket"
require "stringio"
require "tmpdir"
require_relative "support"
require_relative File.join(LIB_DIR, "..", "server")

$mgq_log = load_mgq_bridge

# What happened to the child, in order: :load, :sandbox and :handshake.
$steps = []

# Stands in for the sandbox: available, and failing as $sandbox_error says.
module Sandbox
  # Tells that children can be sandboxed.
  #
  # @return [Boolean] true.
  def self.available?
    true
  end

  # Fails with $sandbox_error, or notes that the child was closed in.
  #
  # @param _root [String] The game folder.
  def self.enter(_root)
    raise $sandbox_error if $sandbox_error

    $steps << :sandbox
  end
end

# Stands in for the core library behind MGQ_Multiplayer::Bridge::FiddleBackend: loading it and
# its handshake are noted in $steps, and its first drain hands out a log line.
class FakeCore
  # The handshake's reply.
  HANDSHAKE = Marshal.dump({ "ok" => true, "value" => { "bridge" => 1, "build" => "0.0.0-dev", "context" => 1, "topics" => ["batch"] } })

  # The first drain's events.
  EVENTS = Marshal.dump([["log", "Bridge 1 opened context 1 with 1 topics."]])

  # Loads the library.
  #
  # @param path [String] The library.
  def initialize(path)
    $steps << :load
    @path = path
    @drained = false
  end

  # Shakes hands.
  #
  # @return [Integer] The reply's length.
  def open(_version, reply, _size)
    $steps << :handshake
    reply[0, HANDSHAKE.bytesize] = HANDSHAKE
    HANDSHAKE.bytesize
  end

  # Takes the events, a log line the first time.
  #
  # @return [Integer] The events' length, 0 for none.
  def drain(_context, _frame, buffer, _size)
    return 0 if @drained

    @drained = true
    buffer[0, EVENTS.bytesize] = EVENTS
    EVENTS.bytesize
  end
end

# Prepares a child as server.rb does, over a socket pair, with a core library.
#
# @param library [String, nil] The core library, see Core.library.
# @param backend [Class] What loads it.
# @return [Array(Boolean, String)] Whether the child may play and what its client heard.
def enter_child(library = nil, backend = FakeCore)
  $steps = []
  MGQ_Multiplayer::Bridge.close
  BattleServer.instance_variable_set(:@core_library, library)
  MGQ_Multiplayer::Bridge.send(:remove_const, :FiddleBackend)
  MGQ_Multiplayer::Bridge.const_set(:FiddleBackend, backend)
  client, child = UNIXSocket.pair rescue Socket.pair(:INET, :STREAM, 0)
  may_play = BattleServer.send(:enter_child, child)
  child.close
  [may_play, client.read.to_s]
ensure
  client&.close
end

real_backend = MGQ_Multiplayer::Bridge::FiddleBackend
dir = Dir.mktmpdir("battle-core")
library = File.join(dir, "MGQOnline.ServerCore.so")
File.write(library, "no library")

log = StringIO.new
check("without BATTLE_CORE_LIBRARY there is no core library, said once", [Core.library(log, {}), log.string.lines.size], [nil, 1])
log = StringIO.new
check("one that does not exist counts as none, with a warning",
      [Core.library(log, { "BATTLE_CORE_LIBRARY" => File.join(dir, "missing.so") }), log.string.start_with?("warning:")], [nil, true])
check("one that exists is taken by its full path", Core.library(StringIO.new, { "BATTLE_CORE_LIBRARY" => library }), File.expand_path(library))
bridge = MGQ_Multiplayer.send(:remove_const, :Bridge)
log = StringIO.new
check("and counts as none while the game folder's MGQ Online has no bridge to C#, with a warning",
      [Core.library(log, { "BATTLE_CORE_LIBRARY" => library }), log.string.start_with?("warning:")], [nil, true])
MGQ_Multiplayer.const_set(:Bridge, bridge)

check("without a core library a child is closed in and plays with the bridge closed",
      [enter_child, $steps, MGQ_Multiplayer::Bridge.open?], [[true, ""], [:sandbox], false])
check("with one it loads the library before the sandbox and shakes hands after it",
      [enter_child(library), $steps, MGQ_Multiplayer::Bridge.open?], [[true, ""], %i[load sandbox handshake], true])

$mgq_log.clear
MGQ_Multiplayer::Bridge.frame
check("the core's log lines reach MGQ Online's log in the next frame", $mgq_log, ["core: Bridge 1 opened context 1 with 1 topics."])

$sandbox_error = SecurityError.new("the sandbox could not drop root")
may_play, heard = enter_child(library)
check("a child that cannot drop root does not play and never shakes hands", [may_play, $steps], [false, [:load]])
check("and tells its client so", heard.empty? ? nil : JSON.parse(heard), { "ok" => false, "error" => "the battle could not be sandboxed: the sandbox could not drop root" })
$sandbox_error = nil

check("a file that is no library is not loaded, and the child plays without the core",
      [enter_child(library, real_backend), $steps, MGQ_Multiplayer::Bridge.open?], [[true, ""], [:sandbox], false])

# Hosts a co-op battle as server.rb does when the relay hands one over, over a socket pair.
#
# @return [Array<Hash>] What the relay heard, line by line.
def host_battle
  relay, server = UNIXSocket.pair rescue Socket.pair(:INET, :STREAM, 0)
  BattleServer.instance_variable_set(:@served, true)
  BattleServer.send(:host, server, { "op" => "serve", "bid" => "b1", "setup" => "" })
  relay.read.to_s.lines.map { |line| JSON.parse(line) }
ensure
  relay&.close
end

heard = host_battle
check("a child without the core refuses MGQ Online's battle, telling the relay why",
      [heard.size, heard[0]["op"], heard[0]["code"], heard[0]["error"].start_with?("the battle server's C# core library is missing or did not load: the core library")],
      [1, "refused", "core", true])
enter_child(library)
check("with the core the battle gets past that refusal", host_battle.map { |line| line["code"] }.include?("core"), false)

FileUtils.rm_rf(dir)
