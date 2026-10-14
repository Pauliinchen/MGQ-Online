#----------------------------------------------------------------
#  make_setup.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Fought a raid boss's pools with RAID_POOL=1
#                            - Created
#
#----------------------------------------------------------------

require "json"
require "stringio"
require_relative "../lib/boot"
require_relative "../lib/save"
require_relative "../lib/served"

# Writes what a starter's game hands the relay for a served co-op battle, the party built from a
# save's characters for every player, and the guests' answers as the battle channel carries them,
# as JSON for relay_e2e.mjs. With RAID_POOL=1 the troop's boss fights its Raid World pools, full
# as the starter knows them.
#   ruby make_setup.rb <save> <troop> <battle id> <seat>...
save = File.binread(ARGV[0])
troop = ARGV[1].to_i
battle_id = ARGV[2]
seats = ARGV[3..].map(&:to_i)
Boot.run(StringIO.new)
ServedBattle.install(StringIO.new)
DataManager.create_game_objects
SaveFile.extract(SaveFile.read(save)[1])
BattleManager.setup(troop, true, true)
MGQ_MpRaidPool.start(troop, MGQ_MpRaidPool.own_count(troop), :event, false) if ENV["RAID_POOL"] == "1"
build = MGQ_MpBattlesCoop.own_build
players = seats.each_with_index.map do |seat, index|
  MGQ_MpBattlesCoop::Player.new(seat, "Player #{index + 1}", build[0], build[1], build[2], [0, 1, 2, 3], 4 / seats.size, 0)
end
message = ->(kind, body = "") { MGQ_MpOverworldSync::Me.encode({ "battle" => kind, "bid" => battle_id }) + body }
attacks = Array.new(16) { [["skill", 1, -1]] }
puts JSON.generate(setup: [MGQ_MpBattlesServed.setup_text(players, nil)].pack("m0"), ready: message.("ready"),
                   commands: message.("commands", MGQ_MpBattlesSync::Wire.line([attacks])))
