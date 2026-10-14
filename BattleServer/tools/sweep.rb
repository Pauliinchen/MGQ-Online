#----------------------------------------------------------------
#  sweep.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require "digest"
require_relative "../lib/boot"
require_relative "../lib/battle"

# Fights every STEP-th troop with one party after a single boot, and reports outcomes, errors,
# time and memory: ruby sweep.rb <step> <level> <actor ids...>
step = (ARGV[0] || 100).to_i
level = (ARGV[1] || 50).to_i
actors = (ARGV[2..].empty? ? ["1"] : ARGV[2..]).map(&:to_i)

# The process's memory in MB, from /proc on Linux and from tasklist on Windows.
def rss_mb
  return File.read("/proc/self/status")[/^VmRSS:\s+(\d+)/, 1].to_i / 1024 if File.exist?("/proc/self/status")

  # A game script takes Kernel's backtick away.
  line = IO.popen(["tasklist", "/FI", "PID eq #{Process.pid}", "/FO", "CSV", "/NH"], &:read)
  line.split('","')[4].to_s.delete("^0-9").to_i / 1024
end

# SAVE=<save file> fights every troop with that save's party instead of the actors given; read before
# the boot, which moves into the game folder.
save = ENV["SAVE"] && File.binread(ENV["SAVE"])
boot_seconds = Boot.run
HeadlessBattle.install
puts format("boot %.1f s, %d MB", boot_seconds, rss_mb)

troops = (1...$data_troops.size).step(step).select { |id| $data_troops[id] && !$data_troops[id].members.empty? }
outcomes = Hash.new(0)
errors = []
times = []
troops.each do |id|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  begin
    outcome = HeadlessBattle.run(troop_id: id, party: actors.map { |a| [a, level] }, save: save, seed: id,
                                 variables: save ? {} : { NWConst::Var::ENCHANT_RARELITY_ID => 1 })
    outcomes[outcome[:result]] += 1
    times << [Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, outcome[:turns], id]
    if ENV["VERBOSE"]
      puts format("troop %4d %-20s %-8s turns %2d %.2f s | %s", id, $data_troops[id].name[0, 20],
                  outcome[:result], outcome[:turns], times.last[0], outcome[:log].last(2).join(" / ")[0, 140])
    end
    # One line per battle with a hash of its whole log, to tell two runs of the same seeds apart.
    if ENV["DIGEST"]
      puts format("digest %4d %s %d %s", id, outcome[:result], outcome[:turns],
                  Digest::SHA256.hexdigest(outcome[:log].join("\n"))[0, 16])
    end
  rescue Exception => e
    raise if e.is_a?(Interrupt)
    outcomes[:error] += 1
    errors << "troop #{id} #{$data_troops[id].name}: #{e.class}: #{e.message.lines.first&.strip} at #{e.backtrace&.first}"
  end
end
puts "troops #{troops.size}: #{outcomes.inspect}"
unless times.empty?
  total = times.sum(&:first)
  turns = times.sum { |t| t[1] }
  slowest = times.max_by(&:first)
  puts format("battle time: average %.3f s, per turn %.4f s, slowest %.2f s (troop %d, %d turns)",
              total / times.size, total / [turns, 1].max, slowest[0], slowest[2], slowest[1])
end
puts "memory after #{rss_mb} MB"
puts errors.first(25)
