#----------------------------------------------------------------
#  relay_bridge_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Tests of relay_bridge.rb and online.rb's boss pools over a socket pair: the relay's lines become
# the entries the DLL would write, the server's messages and boss reports become lines, and the
# pools the relay tells read as the DLL's state.

require "json"
require "socket"
require_relative "support"
require_relative File.join(LIB_DIR, "relay_bridge")

relay, server = UNIXSocket.pair rescue Socket.pair(:INET, :STREAM, 0)
bridge = RelayBridge.new(server)

# Takes the next entry, waiting a moment for the bridge's reader.
#
# @return [String, nil] The entry.
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
check("a player coming onto the channel is an in entry", next_of(bridge), "kind=in\nseat=3\n\n")
check("a player's message is a message entry with its text", next_of(bridge), "kind=message\nseat=3\n\nbattle=ready\n\nアリス")

check("a message to a player goes out", bridge.send_to(3, "battle=events\n\n"), true)
check("as a send line in base64", JSON.parse(relay.gets), { "op" => "send", "seat" => 3, "text" => ["battle=events\n\n"].pack("m0") })

check("a boss report of another shape does not go out", bridge.report("Sara", "rp1", "x\t0.5\t900\t0"), false)
check("a boss report goes out", bridge.report("Sara", "rp1", "2\t0.2500000000\t900\t1"), true)
check("as a boss_report line", JSON.parse(relay.gets),
      { "op" => "boss_report", "key" => "Sara", "battle" => "rp1", "seq" => 2, "delta" => 0.25, "max" => 900, "killed" => true })
check("and waits for its answer", bridge.bosses.state("w1"), "world=w1\nreport_queued=1\n\n")

relay.puts(JSON.generate(op: "boss", key: "Sara", left: 0.0, max: 900, defeated: true, by: "Player\t2", answer: true))
relay.puts(JSON.generate(op: "boss", key: "Ilias", left: 0.5, max: 4000, defeated: false, by: "", answer: false))
sleep(0.05)
state = bridge.bosses.state("w1")
check("the relay's answer and another battle's change read as the DLL's state, a standing pool regaining its share",
      [state.sub(/0\.5000\d\d/, "0.5000.."), state[/0\.5\d+/].to_f.between?(0.5, 0.5001)],
      ["world=w1\nreport_queued=0\n\nSara\t0.000000\t900\t1\tPlayer 2\nIlias\t0.5000..\t4000\t0\t\n", true])
relay.puts(JSON.generate(op: "boss", key: "Sara", answer: true))
sleep(0.05)
check("a refused report's answer changes no pool and no count below 0", bridge.bosses.state("w1").lines.first(2), ["world=w1\n", "report_queued=0\n"])

relay.puts(JSON.generate(op: "close"))
check("the relay's close ends the channel", next_of(bridge), "kind=closed\nseat=0\ncode=relay\n\n")
check("after which nothing goes to the players", [bridge.closed?, bridge.send_to(3, "late")], [true, false])
check("but the battle's end still reaches the relay", bridge.tell(op: "end", result: "victory"), true)
check("as an end line", JSON.parse(relay.gets), { "op" => "end", "result" => "victory" })

pools = Online::BossPools.new
check("a report reads as its number, share, max and death",
      [Online::BossPools.report_of("3\t-0.0100000000\t900\t0"), Online::BossPools.report_of("3\t1e5\t900\t0"), Online::BossPools.report_of("")],
      [{ seq: 3, delta: -0.01, max: 900, killed: false }, nil, nil])
pools.take("key" => "Sara", "left" => 1.0, "max" => 900, "defeated" => false, "by" => "")
check("a full pool regains nothing beyond its max", pools.state("").split("\n").last.split("\t")[1], "1.000000")
