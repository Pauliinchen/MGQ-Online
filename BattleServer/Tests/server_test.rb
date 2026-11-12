#----------------------------------------------------------------
#  server_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-12: Covered the child that ends its battle once it runs past its time
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Tests of server.rb's log of its children: their output marked with the child, the battle a child
# names, and how a child ended; and of the time a child may run.

require "rbconfig"
require "stringio"
require_relative "support"
require_relative File.expand_path("../server", __dir__)

reader, writer = IO.pipe
writer.write("[mgq] the battle channel opened\n\xFF\xFE not UTF-8\nbattle k3x9 started\nbattle k3x9: victory after 4 turns\n".b)
writer.close
log = StringIO.new
$stderr = log
battle = BattleServer.send(:copy_output, reader, 42).value
$stderr = STDERR
check("the battle a child names is taken from its output, past a line that is not UTF-8", battle, "k3x9")
check("every line of a child's output goes into the log, marked with the child",
      log.string.b.lines.map { |line| line.split(" ", 2)[0] }.uniq, ["[42]"])

reader, writer = IO.pipe
writer.write("refused battle k3x9: setup: a setup of another format\n")
writer.close
$stderr = StringIO.new
battle = BattleServer.send(:copy_output, reader, 43).value
$stderr = STDERR
check("a child that started no battle names none", battle, nil)

_, status = Process.wait2(Process.spawn(RbConfig.ruby, "-e", "exit 3"))
check("a child that exited tells its exit code", BattleServer.send(:ended, status), "exit 3")

# A child whose battle waits for good, as one the relay never closed, runs past its time: it tells
# the relay its battle failed, with the line the battle's start wrote, and exits.
relay = TCPServer.new("127.0.0.1", 0)
ended_line = JSON.generate("op" => "end", "result" => "failed", "error" => "the battle ran past its 1 seconds")
child = <<~CHILD
  require #{File.expand_path("../server", __dir__).inspect}
  BattleServer.instance_variable_set(:@battle_id, "k3x9")
  BattleServer.instance_variable_set(:@bridge, RelayBridge.new(TCPSocket.new("127.0.0.1", #{relay.addr[1]})))
  BattleServer.instance_variable_set(:@out_of_time_line, #{ended_line.inspect})
  BattleServer.send(:limit_time, 1)
  sleep
CHILD
output, child_output = IO.pipe
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
pid = Process.spawn(RbConfig.ruby, "-e", child, err: child_output)
child_output.close
connection = relay.accept
# The child's exit resets the connection, so its line is read as it comes.
heard = Thread.new { connection.gets&.chomp rescue nil }
waiter = Process.detach(pid)
Process.kill("KILL", pid) unless waiter.join(10)
took = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
check("a child past its time tells the relay its battle failed and exits within seconds",
      [heard.value, BattleServer.send(:ended, waiter.value), took < 10], [ended_line, "exit 1", true])
check("and logs it with its battle", output.read.lines.grep(/\Abattle k3x9 ran past its 1 seconds and ends/).size, 1)
connection.close
relay.close
