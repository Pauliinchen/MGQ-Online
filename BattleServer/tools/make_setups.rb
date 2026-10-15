#----------------------------------------------------------------
#  make_setups.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Writes one served battle setup per seat pair (0-1, 2-3, ...) for the load test, as make_setup.rb
# does for one, in a single boot of the game:
#   ruby make_setups.rb <save> <troop> <pairs> > setups.json
require "json"
require "stringio"
require_relative "../lib/boot"
require_relative "../lib/save"
require_relative "../lib/served"

save = File.binread(ARGV[0])
troop = ARGV[1].to_i
pairs = ARGV[2].to_i
Boot.run(StringIO.new)
ServedBattle.install(StringIO.new)
DataManager.create_game_objects
SaveFile.extract(SaveFile.read(save)[1])
BattleManager.setup(troop, true, true)
build = MGQ_MpBattlesCoop.own_build
attacks = Array.new(16) { [["skill", 1, -1]] }
setups = (0...pairs).map do |pair|
  seats = [pair * 2, pair * 2 + 1]
  battle_id = "load#{pair}"
  players = seats.each_with_index.map do |seat, index|
    MGQ_MpBattlesCoop::Player.new(seat, "Player #{index + 1}", build[0], build[1], build[2], [0, 1, 2, 3], 2, 0)
  end
  MGQ_MpOverworldSync::Me.take_seat(seats.first)
  message = ->(kind, body = "") { MGQ_MpOverworldSync::Me.encode({ "battle" => kind, "bid" => battle_id }) + body }
  { battle: battle_id, seats: seats, setup: [MGQ_MpBattlesServed.setup_text(players, nil)].pack("m0"),
    ready: message.("ready"), commands: message.("commands", MGQ_MpBattlesSync::Wire.line([attacks])) }
end
$stdout.puts JSON.generate(setups)
