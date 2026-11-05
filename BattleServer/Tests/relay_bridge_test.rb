#----------------------------------------------------------------
#  relay_bridge_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Read the channel's entries and state as values, as the scripts' port takes them
#                            - Ran the lines through the real core library, which writes and reads them
#      Paulinchen  2026-10-30: Checked the seats the channel's state names as their entries pass to the scripts
#                            - Checked that the reports of the core's outbox reach the relay
#                            - Checked that the relay's word of the pools reaches the core's ledger in order
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Tests of relay_bridge.rb and online.rb's boss pools over a socket pair and the real core library,
# which writes and reads the lines: the relay's lines become the channel's entries, the server's
# messages and boss reports become lines, and what the relay tells of the pools reaches the core's
# ledger. They run only when BATTLE_CORE_LIBRARY names a built library (see core_library_test.rb).

require "json"
require "socket"
require "stringio"
require_relative "support"
require_relative File.join(LIB_DIR, "core")

load_mgq_bridge
path = Core.library(StringIO.new)
unless path
  Checks.skip("BATTLE_CORE_LIBRARY names no built core library")
  exit
end

require_relative File.join(LIB_DIR, "relay_bridge")
Core.open(Core.load(path))

relay, server = UNIXSocket.pair rescue Socket.pair(:INET, :STREAM, 0)
bridge = RelayBridge.new(server)

# Takes the next entry, waiting a moment for the bridge's reader.
#
# @return [Hash, nil] The entry.
def next_of(bridge)
  50.times do
    entry = bridge.next_entry
    return entry if entry

    sleep(0.01)
  end
  nil
end

relay.puts(JSON.generate(op: "in", seat: 3))
relay.puts(JSON.generate(op: "message", seat: 3, text: ["battle=ready\n\nアリス"].pack("m0")))
check("a player coming onto the channel is an in entry", next_of(bridge), { "kind" => "in", "seat" => 3 })
check("a player's message is a message entry with its text", next_of(bridge), { "kind" => "message", "seat" => 3, "text" => "battle=ready\n\nアリス" })

check("a message to a player goes out", bridge.send_to(3, "battle=events\n\n"), true)
check("as a send line in base64", JSON.parse(relay.gets), { "op" => "send", "seat" => 3, "text" => ["battle=events\n\n"].pack("m0") })

check("a boss report of another shape does not go out", bridge.report("Sara", "rp1", "x\t0.5\t900\t0"), false)
check("a boss report goes out", bridge.report("Sara", "rp1", "2\t0.2500000000\t900\t1"), true)
check("as a boss_report line", JSON.parse(relay.gets),
      { "op" => "boss_report", "key" => "Sara", "battle" => "rp1", "seq" => 2, "delta" => 0.25, "max" => 900, "killed" => true })

relay.puts(JSON.generate(op: "boss", key: "Ilias", left: 0.5, max: 4000, defeated: false, by: "", answer: false))
relay.puts(JSON.generate(op: "boss", key: "Sara", left: 0.0, max: 900, defeated: true, by: "Player\t2", answer: false))
sleep(0.05)
pools = -> { MGQ_Multiplayer::Bridge.call("raid.pools")["pools"].map { |key, left, max, defeated, by| [key, left.to_f.round(3), max, defeated, by] }.sort }
check("nothing reaches the core's ledger before the scripts read the pools", pools.call, [])
bridge.bosses.flush("w1")
check("then the relay's word of each pool does",
      pools.call, [["Ilias", 0.5, 4000, false, ""], ["Sara", 0.0, 900, true, "Player\t2"]])

# Takes the channel's entries as the scripts take them, until a count of them came.
#
# @param count [Integer] How many.
# @return [Array<Hash>] The entries.
def entries_through(count)
  taken = []
  50.times do
    taken.concat(Online.entries)
    return taken if taken.size >= count

    sleep(0.01)
  end
  taken
end

Online.connect(bridge)
relay.puts(JSON.generate(op: "in", seat: 5))
relay.puts(JSON.generate(op: "in", seat: 6))
relay.puts(JSON.generate(op: "out", seat: 5))
entries_through(3)
check("the channel's state names the seats that came onto it and those that left it, as their entries passed",
      Online.state, { "state" => "open", "in" => [5, 6], "out" => [5] })
relay.puts(JSON.generate(op: "in", seat: 5))
entries_through(1)
check("one who comes back is no longer out", Online.state["out"], [])

relay.puts(JSON.generate(op: "close"))
check("the relay's close ends the channel", next_of(bridge), { "kind" => "closed", "seat" => 0, "code" => "relay" })
check("after which nothing goes to the players", [bridge.closed?, bridge.send_to(3, "late")], [true, false])
check("but the battle's end still reaches the relay", bridge.tell("op" => "end", "result" => "victory", "turns" => 4), true)
check("as an end line", JSON.parse(relay.gets), { "op" => "end", "result" => "victory", "turns" => 4 })
