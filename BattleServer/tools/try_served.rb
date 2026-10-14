#----------------------------------------------------------------
#  try_served.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

require "stringio"
require_relative "../lib/boot"
require_relative "../lib/save"
require_relative "../lib/served"

# Hosts a served co-op battle in this process for two scripted guests, which answer ready and send
# attacks whenever the server waits for them, the party built from a save's characters:
#   ruby try_served.rb <save> <troop> [players]
# The game folder's Patch folder needs MGQ Online (Multiplayer.rb and Multiplayer/Scripts).

# The scripted guests' seats.
SEATS = [1, 2].freeze

save = File.binread(ARGV[0])
troop = (ARGV[1] || 101).to_i
count = (ARGV[2] || 2).to_i
quiet = StringIO.new
Boot.run
ServedBattle.install(ENV["VERBOSE"] ? $stderr : quiet)
ServedBattle.paced = false

# Builds what the starter's game sends: the save's party as every player's characters.
DataManager.create_game_objects
SaveFile.extract(SaveFile.read(save)[1])
BattleManager.setup(troop, true, true)
build = MGQ_MpBattlesCoop.own_build
players = SEATS.first(count).each_with_index.map do |seat, index|
  MGQ_MpBattlesCoop::Player.new(seat, "Player #{index + 1}", build[0], build[1], build[2], [0, 1, 2, 3], 4 / count, 0)
end
setup = MGQ_MpBattlesServed.setup_text(players, nil)
battle_id = "b" + "0" * 15
puts "setup #{setup.bytesize} bytes, #{players.size} players with #{MGQ_MpActors::Builds.parse(build[0], 14).size} characters each"

bridge = Online::Bridge.new
seats = players.map(&:seat)
seats.each { |seat| bridge.push("in", seat) }
# Writes a guest's message as the battle channel carries it.
message = ->(kind, body = "") { MGQ_MpOverworldSync::Me.encode({ "battle" => kind, "bid" => battle_id }) + body }
seen = Hash.new(0)
guests = Thread.new do
  until bridge.closed?
    seat, text = begin
      bridge.sent.pop(true)
    rescue ThreadError
      sleep 0.001
      next
    end
    fields = MGQ_Multiplayer::Link.parse(text.dup)
    kind = fields["battle"].to_s
    seen[kind] += 1
    targets = seat == -1 ? seats : [seat]
    case kind
    when "ready"
      targets.each { |guest| bridge.push("message", guest, message.("ready")) }
    when "waiting"
      waiting = fields[:payload].to_s.split(",").map(&:to_i)
      attacks = Array.new(16) { [["skill", 1, -1]] }
      (waiting & targets).each { |guest| bridge.push("message", guest, message.("commands", MGQ_MpBattlesSync::Wire.line([attacks]))) }
    end
  end
end

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
outcome = ServedBattle.run(bridge, battle_id, setup)
guests.join(2)
seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
puts "result #{outcome[:result]}, turns #{outcome[:turns]}, frames #{outcome[:frames]}, #{format('%.1f', seconds)} s"
puts "the server sent: #{seen.sort.map { |kind, n| "#{kind} x#{n}" }.join(', ')}"
puts "the server's log, last lines:", quiet.string.lines.last(12) unless ENV["VERBOSE"]
