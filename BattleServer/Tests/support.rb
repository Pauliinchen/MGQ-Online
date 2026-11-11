#----------------------------------------------------------------
#  support.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Wrote mod zips and served them from a stand-in website for the mod and framework tests
#      Paulinchen  2026-10-23: Loaded MGQ Online's bridge to C# out of Multiplayer.rb for the core's tests
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# What every test file of the battle server shares: checks that count and report. Each test file
# runs in a Ruby process of its own (see run.rb), since the server's libraries change Ruby itself.

require "digest"
require "json"
require "socket"
require "zlib"

# The battle server's libraries.
LIB_DIR = File.expand_path("../lib", __dir__)

# The recorded data the tests compare with.
FIXTURES_DIR = File.expand_path("fixtures", __dir__)

# MGQ Online's script that holds its bridge to C#.
MULTIPLAYER_RB = File.expand_path("../../GameScript/Multiplayer.rb", __dir__)

# Counts a test file's checks and reports them once the file ends.
module Checks
  @count = 0
  @failures = 0
  @skipped = nil

  class << self
    # Compares a value with the expected one and prints the result.
    #
    # @param label [String] What is checked.
    # @param actual [Object] What came out.
    # @param expected [Object] What should have.
    def check(label, actual, expected)
      @count += 1
      ok = actual == expected
      @failures += 1 unless ok
      puts "#{ok ? 'ok  ' : 'FAIL'} #{label}#{ok ? '' : ": #{actual.inspect} (expected #{expected.inspect})"}"
    end

    # Notes that the file's checks did not run, and why.
    #
    # @param reason [String] Why.
    def skip(reason)
      @skipped = reason
    end

    # Prints how many checks ran and how many failed, and ends the process with 1 when one failed.
    #
    # @param error [Exception, nil] What stopped the file early, nil when it ran to its end.
    def finish(error)
      return puts("skipped: #{@skipped}") if @skipped && @count.zero?

      stopped = error && !error.is_a?(SystemExit) ? ", stopped by #{error.class}: #{error.message}" : ""
      puts "#{@count} checks, #{@failures.zero? ? 'all passed' : "#{@failures} FAILED"}#{stopped}"
      exit(1) unless @failures.zero? && stopped.empty?
    end
  end
end

# Checks a value, see Checks.check.
#
# @param label [String] What is checked.
# @param actual [Object] What came out.
# @param expected [Object] What should have.
def check(label, actual, expected)
  Checks.check(label, actual, expected)
end

# Runs a block and tells what it raised, nil for nothing.
#
# @return [Exception, nil] The error.
def raised
  yield
  nil
rescue Exception => e
  raise if e.is_a?(Interrupt)

  e
end

# The game folder for the tests that play battles, from BATTLE_GAME_DIR, or nil without one.
#
# @return [String, nil] The folder.
def game_dir
  dir = ENV["BATTLE_GAME_DIR"]
  dir && File.directory?(File.join(dir, "Data")) ? dir : nil
end

# Loads MGQ_Multiplayer::Bridge out of Multiplayer.rb, as the game folder's MGQ Online has it, with
# a log that keeps its lines.
#
# @return [Array<String>] The lines MGQ Online's log takes from now on.
def load_mgq_bridge
  lines = []
  log = Module.new
  log.define_singleton_method(:write) { |line| lines << line }
  Object.const_set(:MGQ_Multiplayer, Module.new) unless defined?(MGQ_Multiplayer)
  MGQ_Multiplayer.const_set(:Log, log)
  source = File.read(MULTIPLAYER_RB, encoding: "UTF-8")
  MGQ_Multiplayer.module_eval(source[/  module Bridge\n.*?\n  end\n/m])
  lines
end

# Writes a zip of files, the deflated ones as zip tools write them.
#
# @param files [Hash] Each file's bytes by its name in the zip.
# @param deflate [Boolean] Whether the files are deflated.
# @return [String] The zip.
def zip_of(files, deflate: true)
  out = +"".b
  central = +"".b
  files.each do |name, bytes|
    data = deflate ? Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS).then { |d| d.deflate(bytes.b, Zlib::FINISH).tap { d.close } } : bytes.b
    method = deflate ? 8 : 0
    crc = Zlib.crc32(bytes.b)
    offset = out.bytesize
    out << ["PK\x03\x04".b, 20, 0, method, 0, 0, crc, data.bytesize, bytes.bytesize, name.bytesize, 0].pack("a4vvvvvVVVvv") << name.b << data
    central << ["PK\x01\x02".b, 20, 20, 0, method, 0, 0, crc, data.bytesize, bytes.bytesize, name.bytesize, 0, 0, 0, 0, 0, offset].pack("a4vvvvvvVVVvvvvvVV") << name.b
  end
  out + central + ["PK\x05\x06".b, 0, 0, files.size, files.size, central.bytesize, out.bytesize, 0].pack("a4vvvvVVv")
end

# Starts a stand-in of the website on a free local port that answers each path from a table the
# test may change meanwhile, and 404 for any other.
#
# @param routes [Hash{String => String}] Each answer's body by its path with its query.
# @return [Array(String, Array<String>)] The website's address and the paths asked for so far.
def stand_in_site(routes)
  site = TCPServer.new("127.0.0.1", 0)
  requests = []
  Thread.new do
    loop do
      client = site.accept
      path = client.gets.to_s.split(" ")[1]
      requests << path
      nil while (line = client.gets) && line != "\r\n"
      body = routes[path]
      client.write("HTTP/1.1 #{body ? '200 OK' : '404 Not Found'}\r\nContent-Length: #{body.to_s.bytesize}\r\nConnection: close\r\n\r\n#{body}")
      client.close
    end
  end
  ["http://127.0.0.1:#{site.addr[1]}", requests]
end

# Lists one version of a mod as the website's details do, with a package per platform, and puts
# them and its PC package on a stand-in website.
#
# @param routes [Hash] The stand-in website's answers, see stand_in_site.
# @param address [String] The stand-in website's address.
# @param slug [String] The mod's slug.
# @param version [String] Its version.
# @param files [Hash] Its files' bytes by their paths inside Patch.
# @return [String] The PC package, which the website serves at /files/<slug>/pc.zip.
def list_on_site(routes, address, slug, version, files)
  package = zip_of(files.transform_keys { |path| "Patch/#{path}" })
  listed = files.map { |path, bytes| { "path" => "Patch/#{path}", "sha256" => Digest::SHA256.hexdigest(bytes.b).upcase } }
  routes["/api/mods/#{slug}?schema=3"] = JSON.generate("mod" => { "slug" => slug, "versions" => [{ "version" => version, "packages" => [
    { "platform" => "android", "url" => "#{address}/files/#{slug}/android.zip", "sha256" => "0" * 64, "files" => [] },
    { "platform" => "pc", "url" => "#{address}/files/#{slug}/pc.zip", "sha256" => Digest::SHA256.hexdigest(package), "files" => listed },
  ] }] })
  routes["/files/#{slug}/pc.zip"] = package
end

at_exit { Checks.finish($!) }
