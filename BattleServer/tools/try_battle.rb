#----------------------------------------------------------------
#  try_battle.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require_relative "../lib/boot"
require_relative "../lib/battle"

# Runs one battle given on the command line: troop id, seed, then actor:level pairs.
troop_id = (ARGV[0] || 1).to_i
seed = (ARGV[1] || 1).to_i
party = (ARGV[2..].empty? ? ["1:10"] : ARGV[2..]).map { |pair| pair.split(":").map(&:to_i) }

# SAVE=<save file> fights with that save's party instead of the actors given; read before the boot,
# which moves into the game folder.
save = ENV["SAVE"] && File.binread(ENV["SAVE"])
Boot.run
HeadlessBattle.install
puts "troop #{troop_id}: #{$data_troops[troop_id].name}, enemies " +
     $data_troops[troop_id].members.map { |m| $data_enemies[m.enemy_id].name }.join(", ")
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
begin
  outcome = HeadlessBattle.run(troop_id: troop_id, party: party, save: save, seed: seed,
                               variables: save ? {} : { 150 => 1 })
rescue HeadlessBattle::Stuck => e
  log = HeadlessBattle.log
  puts "#{e.message}\n#{log.size} log lines, the last ones:"
  puts log.last(25)
  exit 1
end
seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
puts outcome[:log].first(60)
puts "...(#{outcome[:log].size} lines)" if outcome[:log].size > 60
puts "result #{outcome[:result]}, turns #{outcome[:turns]}, frames #{outcome[:frames]}, #{format("%.2f", seconds)} s"
puts "party: #{outcome[:party].join(" | ")}"
puts "troop: #{outcome[:troop].join(" | ")}"
