#----------------------------------------------------------------
#  relay_bridge_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Checked that the reports of the core's outbox reach the relay
#                            - Checked that the relay's word of the pools reaches the core's ledger in order
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Tests of relay_bridge.rb and online.rb's boss pools over a socket pair: the relay's lines become
# the entries the DLL would write, the server's messages and boss reports become lines, and what
# the relay tells of the pools reaches the core's ledger.

require "json"
require "socket"
require_relative "support"
require_relative File.join(LIB_DIR, "relay_bridge")

# Stands in for MGQ Online's bridge to the core, keeping each call.
module MGQ_Multiplayer
  # The bridge.
  module Bridge
    @calls = []
    @outbox = []

    class << self
      # @return [Array<Array>] Each call's topic and request.
      attr_reader :calls

      # @return [Array<Array>] The reports the core's outbox hands out next.
      attr_reader :outbox

      # Keeps a call and answers the outbox for its topic, else true.
      #
      # @param topic [String] The topic.
      # @param request [Object] The request.
      # @return [Object] The answer.
      def call(topic, request = nil)
        @calls << [topic, request]
        return true unless topic == "raid.pool.reports"

        taken = @outbox.dup
        @outbox.clear
        taken
      end
    end
  end
end

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
relay.puts(JSON.generate(op: "boss", key: "Sara", left: 0.0, max: 900, defeated: true, by: "Player\t2", answer: true))
relay.puts(JSON.generate(op: "boss", key: "Ilias", left: 0.5, max: 4000, defeated: false, by: "", answer: false))
sleep(0.05)
check("nothing reaches the core before the scripts read the pools", MGQ_Multiplayer::Bridge.calls, [])
bridge.bosses.flush("w1")
check("then the relay's answer and another battle's change, in order",
      MGQ_Multiplayer::Bridge.calls,
      [["raid.pool.heard", { "world" => "w1", "key" => "Sara", "left" => "0.0", "max" => 900, "defeated" => true, "by" => "Player\t2", "answer" => true }],
       ["raid.pool.heard", { "world" => "w1", "key" => "Ilias", "left" => "0.5", "max" => 4000, "defeated" => false, "by" => "", "answer" => false }]])
MGQ_Multiplayer::Bridge.calls.clear
relay.puts(JSON.generate(op: "boss", key: "Sara", answer: true))
sleep(0.05)
bridge.bosses.flush("w1")
check("a refused report's answer goes without a share", MGQ_Multiplayer::Bridge.calls.map { |_, request| request["left"] }, [nil])
Online.connect(bridge)
MGQ_Multiplayer::Bridge.outbox << ["w1", "Sara", "rp1", "3\t0.1000000000\t900\t0"]
Online.send_reports
check("the reports the core's fight left go to the relay", JSON.parse(relay.gets),
      { "op" => "boss_report", "key" => "Sara", "battle" => "rp1", "seq" => 3, "delta" => 0.1, "max" => 900, "killed" => false })

relay.puts(JSON.generate(op: "close"))
check("the relay's close ends the channel", next_of(bridge), "kind=closed\nseat=0\ncode=relay\n\n")
check("after which nothing goes to the players", [bridge.closed?, bridge.send_to(3, "late")], [true, false])
check("but the battle's end still reaches the relay", bridge.tell(op: "end", result: "victory"), true)
check("as an end line", JSON.parse(relay.gets), { "op" => "end", "result" => "victory" })

check("a report reads as its number, share, max and death",
      [Online::BossPools.report_of("3\t-0.0100000000\t900\t0"), Online::BossPools.report_of("3\t1e5\t900\t0"), Online::BossPools.report_of("")],
      [{ seq: 3, delta: -0.01, max: 900, killed: false }, nil, nil])
