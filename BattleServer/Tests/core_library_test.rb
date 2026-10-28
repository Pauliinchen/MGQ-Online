#----------------------------------------------------------------
#  core_library_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Checked the core runs the SQLite of the checked-in amalgamation
#      Paulinchen  2026-10-23: Checked the ids the core makes up
#                            - Counted the core's topic that derives the story mapping's index
#                            - Created
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
check("and makes up the ids of the battle server's scripts", bridge.call("id.random", { "length" => 8, "radix" => 36 }).to_s =~ /\A[0-9a-z]{8}\z/ ? true : false, true)
runtime = bridge.call("core.runtime")
check("its GC runs with the baked heap limit of 256 MB, workstation and not concurrent",
      runtime.reject { |key, _| key == "sqlite" }, { "heap_limit" => 256 * 1024**2, "server_gc" => false, "latency" => "Batch" })
check("and it runs the SQLite of the checked-in amalgamation", runtime["sqlite"],
      File.read(File.expand_path("../../MGQOnline.Data/native/sqlite/sqlite3.h", __dir__))[/^#define SQLITE_VERSION\s+"([^"]+)"/, 1])
check("a batch runs each entry and answers the ones that failed",
      bridge.call("batch", [["core.missing", 1], ["core.runtime", nil]]),
      [{ "topic" => "core.missing", "error" => "unknown_topic", "text" => "There is no topic core.missing." }])

mgq_log.clear
bridge.frame
check("the core's log lines come out of the next frame's drain into MGQ Online's log",
      mgq_log, ["core: Bridge 1 opened context 1 with #{bridge.instance_variable_get(:@topics).size} topics.","core: Bridge topic core.missing answered unknown_topic: There is no topic core.missing."])
