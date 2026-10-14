#----------------------------------------------------------------
#  load_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require "json"
require "socket"

# Plays many battles against a forking battle server at once, each on its own connection with
# think time between turns, and samples the server's memory from /proc (Linux only):
#   ruby load_test.rb <battles> <think seconds> <level>
BATTLES = (ARGV[0] || 16).to_i
THINK = (ARGV[1] || 1.0).to_f
LEVEL = (ARGV[2] || 120).to_i
PORT = (ENV["BATTLE_PORT"] || 8095).to_i

# Troops spread over the game, so the battles differ; the ids past about 3400 are empty.
TROOPS = (1..3400).step(3400 / BATTLES).first(BATTLES)

# Reads a process's memory from smaps_rollup, in MB.
#
# @param pid [Integer] The process.
# @return [Hash{Symbol => Float}] Rss, Pss and Private (clean and dirty) in MB.
def memory(pid)
  fields = File.read("/proc/#{pid}/smaps_rollup").scan(/^(\w+):\s+(\d+) kB/).to_h { |k, v| [k, v.to_i] }
  { rss: fields["Rss"] / 1024.0, pss: fields["Pss"] / 1024.0,
    private: (fields["Private_Clean"] + fields["Private_Dirty"]) / 1024.0 }
rescue Errno::ENOENT, Errno::ESRCH
  nil
end

# The server's children now.
#
# @param parent [Integer] The server's process.
# @return [Array<Integer>] The children's processes.
def children(parent)
  File.read("/proc/#{parent}/task/#{parent}/children").split.map(&:to_i)
rescue Errno::ENOENT
  []
end

# Sends a request and reads the answer.
#
# @param socket [TCPSocket] The connection.
# @param request [Hash] The request.
# @return [Hash] The answer.
def call(socket, request)
  socket.puts(JSON.generate(request))
  JSON.parse(socket.gets)
end

probe = TCPSocket.new("127.0.0.1", PORT)
child = call(probe, op: "ping")["pid"]
parent = File.read("/proc/#{child}/status")[/^PPid:\s+(\d+)/, 1].to_i
probe.close
sleep 0.5
base = memory(parent)
puts format("server %d: rss %.0f MB, pss %.0f MB before the battles", parent, base[:rss], base[:pss])

samples = []
sampler = Thread.new do
  loop do
    kids = children(parent)
    stats = kids.filter_map { |pid| memory(pid) }
    top = memory(parent)
    samples << { kids: stats.size, pss: top[:pss] + stats.sum { |s| s[:pss] },
                 private: stats.map { |s| s[:private] } }
    sleep 0.5
  end
end

results = Queue.new
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
threads = TROOPS.each_with_index.map do |troop, index|
  Thread.new do
    socket = TCPSocket.new("127.0.0.1", PORT)
    asked = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    reply = nil
    # Some troop ids are empty in the database; the next one usually is not.
    20.times do
      reply = call(socket, op: "start", troop: troop, party: [[1, LEVEL]], seed: index, variables: { "150" => 1 })
      break unless reply["error"].to_s.include?("has no enemies")

      troop += 1
    end
    first = Process.clock_gettime(Process::CLOCK_MONOTONIC) - asked
    turns = 0
    answer_ms = []
    loop do
      case reply["event"]
      when "commands"
        turns += 1
        sleep THINK
        reply = call(socket, op: "answer", commands: {})
        answer_ms << reply["ms"]
      when "choice"
        sleep THINK
        reply = call(socket, op: "answer", choice: 0)
      else
        break
      end
    end
    socket.close
    results << { troop: troop, result: reply["result"] || reply["error"], turns: turns, first: first, answer_ms: answer_ms }
  rescue StandardError => e
    results << { troop: troop, result: "connection lost (#{e.class})", turns: 0, first: 0, answer_ms: [] }
  end
end
if ENV["KILL_ONE"]
  # Kills one child mid-battle, as a crash would, to show the other battles go on.
  sleep 2
  victim = children(parent).first
  puts "killing child #{victim} mid-battle"
  Process.kill(:KILL, victim) if victim
end
threads.each(&:join)
seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
sleep 0.6
sampler.kill

all = Array.new(results.size) { results.pop }
peak = samples.max_by { |s| s[:pss] }
privates = samples.flat_map { |s| s[:private] }
answers = all.flat_map { |r| r[:answer_ms] }.compact.sort
puts format("%d battles at once, think %.1f s: %.1f s in all", BATTLES, THINK, seconds)
puts "results: #{all.group_by { |r| r[:result] }.transform_values(&:size)}"
puts format("first event after: average %.0f ms, slowest %.0f ms (fork + new game + battle start)",
            all.sum { |r| r[:first] } / all.size * 1000, all.map { |r| r[:first] }.max * 1000)
puts format("server answer per turn: median %d ms, 95%% %d ms, slowest %d ms", answers[answers.size / 2] || 0,
            answers[(answers.size * 0.95).floor] || 0, answers.last || 0) unless answers.empty?
puts format("peak: %d children, server + children pss %.0f MB (parent alone %.0f MB)",
            peak[:kids], peak[:pss], base[:pss])
puts format("memory of a child of its own: average %.0f MB, most %.0f MB", privates.sum / [privates.size, 1].max,
            privates.max || 0)
all.reject { |r| %w[victory defeat escape].include?(r[:result]) }.first(5).each { |r| puts "  troop #{r[:troop]}: #{r[:result]}" }
puts format("children left after the test: %d", children(parent).size)
