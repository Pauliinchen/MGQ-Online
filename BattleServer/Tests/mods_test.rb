#----------------------------------------------------------------
#  mods_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Tests of mods.rb without the game: the catalog's hashes, the zips it reads, fetching a world's
# mods from a stand-in relay into the cache, and loading them with their files read from memory.

require "json"
require "socket"
require "tmpdir"
require "zlib"
require_relative "support"

cache = Dir.mktmpdir("battle-mods")
ENV["BATTLE_MOD_CACHE"] = cache
require_relative File.join(LIB_DIR, "mods")

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

check("a script hashes without its carriage returns, another file with them",
      [ServedMods.hash_of("A.rb", "x = 1\r\n"), ServedMods.hash_of("a.txt", "x = 1\r\n") == Digest::SHA256.hexdigest("x = 1\r\n")],
      [Digest::SHA256.hexdigest("x = 1\n"), true])

files = { "Patch/Test/test.rb" => "TEST_DATA = File.read(\"Patch/Test/data.txt\")\n", "Patch/Test/data.txt" => "アリス\r\n", "Patch/Test/" => "" }
check("a zip's files read by their paths inside Patch, deflated or plain",
      [ServedMods.unzip(zip_of(files)), ServedMods.unzip(zip_of(files, deflate: false))].map { |read| read.transform_values { |bytes| bytes.force_encoding("UTF-8") } },
      [{ "Test/test.rb" => files["Patch/Test/test.rb"], "Test/data.txt" => "アリス\r\n" }] * 2)
check("a zip with a path outside Patch is refused", raised { ServedMods.unzip(zip_of({ "../evil.rb" => "x" })) }&.message.to_s.include?("no path inside Patch"), true)
check("as is one past the files the catalog takes", raised { ServedMods.unzip(zip_of((0..ServedMods::MAX_FILES).to_h { |n| ["f#{n}.txt", "x"] })) }.class, ServedMods::Unavailable)
check("and anything that is no zip", raised { ServedMods.unzip("not a zip") }.class, ServedMods::Unavailable)

# A relay that serves a catalog of one uploaded mod and its zip.
upload = { "Test/test.rb" => files["Patch/Test/test.rb"], "Test/data.txt" => "アリス\r\n" }
hashes = upload.to_h { |path, bytes| [path, ServedMods.hash_of(path, bytes)] }
catalog = { "mods" => [{ "key" => "test", "name" => "Test", "kind" => "upload", "version" => "1.0", "files" => hashes },
                       { "key" => "elsewhere", "kind" => "link", "version" => "2", "files" => { "E.rb" => "0" * 64 }, "fileUrl" => "https://example.com/E.rb" }] }
requests = []
relay = TCPServer.new("127.0.0.1", 0)
Thread.new do
  loop do
    client = relay.accept
    path = client.gets.to_s.split(" ")[1]
    requests << path
    nil while (line = client.gets) && line != "\r\n"
    body = case path
           when "/v1/mods" then JSON.generate(catalog)
           when "/v1/mods/test/file" then zip_of(upload.transform_keys { |name| "Patch/#{name}" })
           end
    client.write("HTTP/1.1 #{body ? '200 OK' : '404 Not Found'}\r\nContent-Length: #{body.to_s.bytesize}\r\nConnection: close\r\n\r\n#{body}")
    client.close
  end
end
address = "http://127.0.0.1:#{relay.addr[1]}"
wanted = [["test", "upload", "1.0", hashes]]

fetched = ServedMods.fetch(wanted, address, StringIO.new)
check("a world's mod comes from the relay's catalog, its files checked against the starter's hashes",
      [fetched.map { |key, mod_files| [key, mod_files.keys.sort] }, requests], [[["test", ["Test/data.txt", "Test/test.rb"]]], ["/v1/mods", "/v1/mods/test/file"]])
requests.clear
check("and from the cache the next time, without a relay", ServedMods.fetch(wanted, nil, StringIO.new) == fetched && requests.empty?, true)
check("a copy the catalog cannot serve is refused",
      raised { ServedMods.fetch([["test", "", "0.9", {}]], address) }&.message.to_s.include?("is none the catalog serves"), true)
check("as is another version than the catalog's",
      raised { ServedMods.fetch([["test", "upload", "0.9", { "Test/test.rb" => "1" * 64 }]], address) }&.message.to_s.include?("not the starter's version"), true)
check("and a release file outside GitHub's releases",
      raised { ServedMods.fetch([["elsewhere", "link", "2", { "E.rb" => "0" * 64 }]], address) }&.message.to_s.include?("outside GitHub's releases"), true)
check("a mod the cache lacks with no relay to ask is refused",
      raised { ServedMods.fetch([["other", "upload", "1", { "O.rb" => "2" * 64 }]], nil) }&.message.to_s.include?("knows no relay"), true)

loaded = ServedMods.load(fetched, StringIO.new)
check("the mod's scripts load and read its other files from memory as if they lay in Patch",
      [loaded, TEST_DATA.force_encoding("UTF-8"), File.exist?("Patch/Test/data.txt"), File.open("Patch\\Test\\data.txt", &:read).force_encoding("UTF-8"), File.size("Patch/Test/data.txt")],
      [1, "アリス\r\n", true, "アリス\r\n", 11])
check("files outside the mods read as ever", [File.exist?("Patch/Test/none.txt"), File.exist?(__FILE__)], [false, true])
check("the same mods load once in a process that hosts one battle after another", ServedMods.load(fetched, StringIO.new), 0)
FileUtils.rm_rf(cache)
