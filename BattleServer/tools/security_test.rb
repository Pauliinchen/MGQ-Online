#----------------------------------------------------------------
#  security_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require "socket"
require_relative "../lib/boot"
require_relative "../lib/save"
require_relative "../lib/sandbox"

# Tries what a crafted save or code inside a battle could do: saves naming Ruby's own classes
# must be refused, and a sandboxed child must reach nothing (Linux as root for the sandbox part):
#   ruby security_test.rb <a real save>
# Read before the boot, which moves into the game folder.
real = File.binread(ARGV[0])
Boot.run
failures = 0

# Notes one check's outcome.
#
# @param name [String] What was checked.
# @param passed [Boolean] Whether it held.
# @param detail [String] What happened.
define_method(:expect) do |name, passed, detail|
  failures += 1 unless passed
  puts format("%-4s %-58s %s", passed ? "ok" : "FAIL", name, detail.to_s[0, 110])
end

# Builds a Marshal stream of one object of a class with no fields, by name.
#
# @param name [String] The class's name.
# @return [String] The stream.
def object_of(name)
  "\x04\x08o:".b + [name.bytesize + 5].pack("C") + name.b + "\x00".b
end

# Reads bytes as a save and tells how it went.
#
# @param bytes [String] The bytes.
# @return [Array(Boolean, String)] Whether it was refused, and why or what came out.
def refused(bytes)
  SaveFile.read(bytes + bytes)
  [false, "read"]
rescue SaveCheck::Refused => e
  [true, e.message]
rescue StandardError => e
  [false, "#{e.class}: #{e.message}"]
end

puts "== saves"
header, = SaveFile.read(real)
expect("a real save is read", header.is_a?(Hash), header.keys.inspect)
gem = "\x04\x08U:\x15Gem::Requirement[\x00".b
expect("Gem::Requirement (a known gadget) is refused", *refused(gem))
expect("Set (Ruby's library) is refused", *refused(Marshal.dump(Set.new([1]))))
expect("a struct of Ruby's own (Process::Tms) is refused", *refused(Marshal.dump(Process.times)))
expect("a new class inside Kernel is refused", *refused(object_of("Kernel::Evil")))
expect("a new class inside Process is refused", *refused(object_of("Process::Evil")))
result = refused(object_of("Unknown_Mod::Thing"))
expect("an unknown mod's class becomes an empty stand-in", !result[0] && Unknown_Mod::Thing.instance_methods(false).empty?, result[1])
expect("a cut save is refused", *refused(real.byteslice(0, real.bytesize / 2)))
expect("bytes that are not Marshal are refused", *refused("not a save at all"))
deep = "\x04\x08".b + "[\x06".b * 2000 + "0".b
expect("nesting 2000 deep is refused", *refused(deep))

puts "== sandbox"
if Sandbox.available?
  reader, writer = UNIXSocket.pair
  errors, child_errors = IO.pipe
  # Looked up outside, since the sandbox cannot see /etc/passwd.
  nobody = Etc.getpwnam(Sandbox::USER).uid
  pid = Process.fork do
    reader.close
    errors.close
    # Writing to a file is forbidden in the sandbox, and the test's output may be one.
    $stdout.reopen(child_errors)
    $stderr.reopen(child_errors)
    begin
      Sandbox.enter(Boot::GAME_DIR)
    rescue Exception => e
      writer.write(Marshal.dump([["enter the sandbox", false, "#{e.class}: #{e.message} at #{e.backtrace&.first}"]]))
      Process.exit!(1)
    end
    tries = {
      "connect to this machine (127.0.0.1:22)" => -> { TCPSocket.new("127.0.0.1", 22) },
      "connect out (1.1.1.1:443)" => -> { TCPSocket.new("1.1.1.1", 443) },
      # IO.sysopen goes past the server's discarding of writes, as code a save smuggled in could.
      "write a file into the game folder" => -> { IO.sysopen("/Server/written.txt", "w") },
      "read a file outside the game folder" => -> { File.read("/etc/passwd") },
      "start a program" => -> { Process.spawn("/bin/sh", "-c", "true") },
      "become root again" => -> { Process::UID.change_privilege(0) }
    }
    report = tries.map do |name, action|
      action.call
      [name, false, "it worked"]
    rescue Exception => e
      [name, true, "#{e.class}: #{e.message}"]
    end
    report << ["runs as nobody", Process.uid == nobody, "uid #{Process.uid}"]
    report << ["sees only the game folder", (Dir.children("/") - %w[Data Patch Server]).empty?, Dir.children("/").sort.join(", ")]
    report << ["still reads the game's maps", (load_data("Data/Map001.rvdata2").is_a?(RPG::Map) rescue false), "Data/Map001.rvdata2"]
    writer.write(Marshal.dump(report))
    writer.close
    Process.exit!(0)
  end
  writer.close
  child_errors.close
  answer = reader.read
  said = errors.read
  Process.wait(pid)
  report = answer.empty? ? [["the child reports back", false, "it ended without a report: #{$?.inspect}"]] : Marshal.load(answer)
  puts "the child's own output:\n#{said.lines.last(8).join}" unless said.strip.empty?
  report.each { |name, passed, detail| expect(name, passed, detail) }
  expect("its own connection keeps working", true, "this report came through it")
else
  puts "skipped: the sandbox needs Linux and root"
end
puts failures.zero? ? "all held" : "#{failures} FAILED"
exit(failures.zero? ? 0 : 1)
