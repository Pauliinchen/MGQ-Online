#----------------------------------------------------------------
#  server_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Tests of server.rb's log of its children: their output marked with the child, the battle a child
# names, and how a child ended.

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
