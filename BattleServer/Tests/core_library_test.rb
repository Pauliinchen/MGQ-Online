#----------------------------------------------------------------
#  core_library_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Tests of the real core library, MGQOnline.ServerCore built for this system, through MGQ Online's
# bridge as the battle server loads it: the handshake, a call, a batch and the core's log lines
# coming out of the drain. They run only when BATTLE_CORE_LIBRARY names a built library (the .so,
# or the win-x64 .dll on Windows, see docs/DEVELOPER.md).

require "stringio"
require_relative "support"
require_relative File.join(LIB_DIR, "core")

mgq_log = load_mgq_bridge
path = Core.library(StringIO.new)
unless path
  Checks.skip("BATTLE_CORE_LIBRARY names no built core library")
  exit
end

bridge = MGQ_Multiplayer::Bridge
backend = Core.load(path)

check("the library loads", backend.nil?, false)
check("and shakes hands", Core.open(backend), true)
check("naming the batch and core.runtime", %w[batch core.runtime].all? { |topic| bridge.has?(topic) }, true)
check("its GC runs with the baked heap limit of 256 MB, workstation and not concurrent",
      bridge.call("core.runtime"), { "heap_limit" => 256 * 1024**2, "server_gc" => false, "latency" => "Batch" })
check("a batch runs each entry and answers the ones that failed",
      bridge.call("batch", [["core.missing", 1], ["core.runtime", nil]]),
      [{ "topic" => "core.missing", "error" => "unknown_topic", "text" => "There is no topic core.missing." }])

mgq_log.clear
bridge.frame
check("the core's log lines come out of the next frame's drain into MGQ Online's log",
      mgq_log, ["core: Bridge 1 opened context 1 with 2 topics.", "core: Bridge topic core.missing answered unknown_topic: There is no topic core.missing."])
