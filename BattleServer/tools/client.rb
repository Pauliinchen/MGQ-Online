#----------------------------------------------------------------
#  client.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require "json"
require "socket"

# Plays against the battle server as a game would: one battle to its end, then one turn by turn
# in which it picks each actor's last usable enemy skill on the weakest enemy and resists every
# offer: ruby client.rb <troop> <actor:level>...
troop = (ARGV[0] || 1481).to_i
party = (ARGV[1..].empty? ? ["1:120"] : ARGV[1..]).map { |pair| pair.split(":").map(&:to_i) }
# SAVE=<save file> sends that save, so the battles use its party and state.
save = ENV["SAVE"] && [File.binread(ENV["SAVE"])].pack("m0")
# A fresh game lacks the enchantment rarity the story sets; a save has its own.
fight = save ? { save: save } : { party: party, variables: { "150" => 1 } }
socket = TCPSocket.new("127.0.0.1", (ENV["BATTLE_PORT"] || 8095).to_i)

# Sends a request and reads the answer, timing the round trip.
#
# @param socket [TCPSocket] The connection.
# @param request [Hash] The request.
# @return [Array(Hash, Float)] The answer and the milliseconds it took.
def call(socket, request)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  socket.puts(JSON.generate(request))
  reply = JSON.parse(socket.gets)
  [reply, (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000]
end

reply, ms = call(socket, op: "ping")
puts "ping #{reply.inspect} (#{ms.round} ms)"

reply, ms = call(socket, op: "battle", troop: troop, **fight, seed: 7)
puts "auto battle: #{reply["result"]} in #{reply["turns"]} turns, #{reply["log"]&.size} log lines, " \
     "server #{reply["ms"]} ms, round trip #{ms.round} ms"
puts "  #{reply["error"]}" unless reply["ok"]

reply, ms = call(socket, op: "start", troop: troop, **fight, seed: 7)
loop do
  reply["log"]&.each { |line| puts "    #{line}" }
  case reply["event"]
  when "commands"
    weakest = reply["enemies"].min_by { |enemy| enemy["hp"] }
    commands = reply["actors"].to_h do |actor|
      skill = actor["skills"].reverse.find { |s| s["target"] == "enemy" }
      picks = Array.new(actor["actions"]) { skill ? { skill: skill["id"], target: weakest["index"] } : { attack: true, target: weakest["index"] } }
      [actor["id"].to_s, picks]
    end
    names = reply["actors"].map { |a| "#{a["name"]} #{a["hp"]}/#{a["mhp"]} (#{a["skills"].size} skills)" }
    puts "  turn #{reply["turn"]}: #{names.join(", ")} vs #{reply["enemies"].map { |e| "#{e["name"]} #{e["hp"]}" }.join(", ")}"
    puts "  -> #{commands.inspect} (server #{reply["ms"]} ms, round trip #{ms.round} ms)"
    reply, ms = call(socket, op: "answer", commands: commands)
  when "choice"
    puts "  choice #{reply["choices"].inspect} -> 0"
    reply, ms = call(socket, op: "answer", choice: 0)
  else
    puts "  #{reply["event"]}: #{reply["result"] || reply["error"]} #{reply["at"]&.first}"
    puts "  party #{reply["party"]&.join(" | ")}"
    break
  end
end
