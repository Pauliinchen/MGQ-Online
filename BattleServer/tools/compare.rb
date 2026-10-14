#----------------------------------------------------------------
#  compare.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require_relative "../lib/boot"
require_relative "../lib/battle"

# Plays battles the real game played through its test driver's compare.rb, and compares the
# logs line by line: ruby compare.rb <the game's TestDriver/out folder> <save:troop:seed:name>...
OUT = ARGV.shift
# The system save the game ran with, which its TestDriver wrote out; its library counts raise
# some damage.
# BATTLE_SAVES names the folder of the saves and the system save, default saves; paths are taken
# before the boot, which moves into the game folder.
SAVES = File.expand_path(ENV["BATTLE_SAVES"] || "saves")
OUT_DIR = File.expand_path(OUT)
SYSTEM_FILE = File.join(SAVES, "SystemSave.rvdata2")
SYSTEM = File.exist?(SYSTEM_FILE) ? File.binread(SYSTEM_FILE) : nil
Boot.run
HeadlessBattle.install
# TRACE=1 also holds every random draw against the game's TestDriver/out/trace_<name>.txt.
if ENV["TRACE"]
  require_relative "rng_trace"
  RngTrace.install
end

# Holds the server's draws against the game's and shows where they part.
#
# @param name [String] The battle's name.
# @param draws [Array<String>] The server's draws.
def compare_draws(name, draws)
  game_file = File.join(OUT_DIR, "trace_#{name}.txt")
  return puts("  no game trace for #{name}") unless File.exist?(game_file)

  game = File.read(game_file, encoding: "UTF-8").lines.map(&:chomp)
  # A draw's kind and value must match; the caller's method may be named differently for srand.
  # Objects print with their address, which differs from process to process.
  key = ->(line) { line.gsub(/#<([\w:]+):0x\h+[^>]*>/, '#<\1>').split(" ").then { |parts| [parts[0], parts[3..]] } }
  first = (0...[game.size, draws.size].max).find { |i| game[i].nil? || draws[i].nil? || key.(game[i]) != key.(draws[i]) }
  if first.nil?
    puts "  draws: all #{game.size} the same"
  else
    puts "  draws: the same up to #{first} of #{game.size} (game) / #{draws.size} (server); then"
    puts "    game:   #{game[[first - 2, 0].max, 5].join("\n            ")}"
    puts "    server: #{draws[[first - 2, 0].max, 5].join("\n            ")}"
  end
end

# The battle's outcome in the lines the game's compare.rb writes.
#
# @param outcome [Hash] HeadlessBattle.run's outcome.
# @return [Array<String>] The lines.
def lines_of(outcome)
  ["result #{outcome[:result]}", "turns #{outcome[:turns]}", *outcome[:log]] +
    outcome[:party].map { |line| "party: #{line}" } + outcome[:troop].map { |line| "troop: #{line}" }
end

same = 0
ARGV.each do |spec|
  save, troop, seed, name = spec.split(":")
  game_file = File.join(OUT_DIR, "battle_#{name}.txt")
  unless File.exist?(game_file)
    puts "#{name}: the game has no log yet"
    next
  end
  game = File.read(game_file, encoding: "UTF-8").lines.map(&:chomp)
  # The game lists its party after the battle, which may be only those who fought.
  game_party = game.grep(/\Aparty: /)
  RngTrace.lines = [] if ENV["TRACE"]
  bytes = File.binread(File.join(SAVES, "#{save}.rvdata2"))
  # Some saves keep the enchantment rarity at 0, which no drop table covers, and an enchanted
  # drop then crashes the game; the game's comparison sets the same.
  rarity = SaveFile.read(bytes)[1][:variables][150]
  outcome = HeadlessBattle.run(troop_id: troop.to_i, save: bytes, system: SYSTEM, seed: seed.to_i,
                               variables: rarity.zero? ? { 150 => 1 } : {})
  if ENV["TRACE"]
    draws = RngTrace.lines
    RngTrace.lines = nil
  end
  server = lines_of(outcome).reject { |line| line.start_with?("party: ") } + game_party.select { |line| lines_of(outcome).include?(line) }
  server_party = lines_of(outcome).grep(/\Aparty: /)
  game_rest = game - game_party
  server_rest = server.reject { |line| line.start_with?("party: ") }
  first = (0...[game_rest.size, server_rest.size].max).find { |i| game_rest[i] != server_rest[i] }
  party_same = game_party.all? { |line| server_party.include?(line) }
  if first.nil? && party_same
    same += 1
    puts format("%-14s IDENTICAL: %s, %s, %d log lines, party HP the same", name, game_rest[0], game_rest[1], game_rest.size - 2)
  else
    puts format("%-14s DIFFERENT%s", name, first ? " from line #{first + 1}" : " in the party's HP")
    if first
      puts "  game:   #{game_rest[[first - 2, 0].max, 5].join("\n          ")}"
      puts "  server: #{server_rest[[first - 2, 0].max, 5].join("\n          ")}"
    end
    (game_party - server_party).each { |line| puts "  game #{line} | server has #{server_party.join(", ")[0, 200]}" }
  end
  compare_draws(name, draws) if draws
end
puts "#{same} of #{ARGV.size} identical"
