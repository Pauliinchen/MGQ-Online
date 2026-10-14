#----------------------------------------------------------------
#  try_served.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Named the first scripted guest the battle's starter
#                            - Let a third player join late through the starter with HOTJOIN=1
#                            - Loaded the game folder's mods as a world's with MODS
#                            - Created
#
#----------------------------------------------------------------

require "stringio"
require_relative "../lib/boot"
require_relative "../lib/save"
require_relative "../lib/served"

# Hosts a served co-op battle in this process for two scripted guests, which answer ready and send
# attacks whenever the server waits for them, the party built from a save's characters. With
# HOTJOIN=1 it is a Raid World's battle, and at its first command phase a third player asks to
# join it through the starter and joins once taken in:
#   ruby try_served.rb <save> <troop> [players]
# The game folder's Patch folder needs MGQ Online (Multiplayer.rb and Multiplayer/Scripts).

# The scripted guests' seats.
SEATS = [1, 2].freeze

# The seat of the player who joins late with HOTJOIN=1.
LATE_SEAT = 3

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
# The first scripted guest started the battle, which makes it the battle's front.
MGQ_MpOverworldSync::Me.take_seat(players.first.seat)
hotjoin = ENV["HOTJOIN"] == "1"
ServedBattle.instance_variable_set(:@raid, true) if hotjoin
setup = MGQ_MpBattlesServed.setup_text(players, nil)
ServedBattle.instance_variable_set(:@raid, nil)
battle_id = "b" + "0" * 15
puts "setup #{setup.bytesize} bytes, #{players.size} players with #{MGQ_MpActors::Builds.parse(build[0], 14).size} characters each"

bridge = Online::Bridge.new
seats = players.map(&:seat)
seats.each { |seat| bridge.push("in", seat) }
# Writes a guest's message as the battle channel carries it.
message = ->(kind, body = "") { MGQ_MpOverworldSync::Me.encode({ "battle" => kind, "bid" => battle_id }) + body }
seen = Hash.new(0)
passed = []
asked = false
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
      if hotjoin && !asked
        asked = true
        request = [["coop", "hot"], ["bid", battle_id], ["troop", troop.to_s], ["enemies", ""], ["seats", ""], ["map", $game_map.map_id.to_s]]
        bridge.push("message", players.first.seat,
                    message.("front_in", MGQ_MpBattlesSync::Wire.line([LATE_SEAT, [[LATE_SEAT, [["id", "id-late"], ["name", "Late"]]]], request])))
      end
    when "front_out"
      target, world_text = MGQ_MpBattlesSync::Wire.parse(fields[:payload].to_s)
      passed << [target, MGQ_Multiplayer::Link.parse(world_text.to_s.dup).reject { |key, _| key.is_a?(Symbol) }]
      # Taken in, the late player comes onto the channel and joins with the same characters.
      if passed.last[1]["map_coop"] == "hot_ok" && bridge.admitted.include?(LATE_SEAT)
        seats << LATE_SEAT
        bridge.push("in", LATE_SEAT)
        bridge.push("message", LATE_SEAT, message.("join", MGQ_MpBattlesSync::Wire.line(build)))
      end
    end
  end
end

# With MODS, scripts of the game folder's Patch folder separated by commas, the battle loads them
# as a world's mods, as the server does once it got them.
mods = ENV["MODS"].to_s.split(",").map { |name| [name, { name => File.binread(File.join(Boot::PATCH_DIR, name)) }] }
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
outcome = ServedBattle.run(bridge, battle_id, setup, mods)
guests.join(2)
seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
puts "result #{outcome[:result]}, turns #{outcome[:turns]}, frames #{outcome[:frames]}, #{format('%.1f', seconds)} s"
puts "the server sent: #{seen.sort.map { |kind, n| "#{kind} x#{n}" }.join(', ')}"
puts "the server let seats #{bridge.admitted.inspect} onto the channel and passed on: #{passed.inspect}" if hotjoin
puts "the server's log, last lines:", quiet.string.lines.last(12) unless ENV["VERBOSE"]
