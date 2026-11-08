#----------------------------------------------------------------
#  mods_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Fetched a world's mod from a stand-in website's catalog, its package and files checked against the hashes
#                            - Fetched a version the starter names without files, as a pinned world does
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Tests of mods.rb without the game: the zips it reads, fetching a world's mods from a stand-in
# website into the cache, and loading them with their files read from memory.

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

files = { "Patch/Test/test.rb" => "TEST_DATA = File.read(\"Patch/Test/data.txt\")\n", "Patch/Test/data.txt" => "アリス\r\n", "Patch/Test/" => "" }
check("a zip's files read by their paths inside Patch, deflated or plain",
      [ServedMods.unzip(zip_of(files)), ServedMods.unzip(zip_of(files, deflate: false))].map { |read| read.transform_values { |bytes| bytes.force_encoding("UTF-8") } },
      [{ "Test/test.rb" => files["Patch/Test/test.rb"], "Test/data.txt" => "アリス\r\n" }] * 2)
check("a zip with a path outside Patch is refused", raised { ServedMods.unzip(zip_of({ "../evil.rb" => "x" })) }&.message.to_s.include?("no path inside Patch"), true)
check("as is one past the files the server takes", raised { ServedMods.unzip(zip_of((0..ServedMods::MAX_FILES).to_h { |n| ["f#{n}.txt", "x"] })) }.class, ServedMods::Unavailable)
check("and anything that is no zip", raised { ServedMods.unzip("not a zip") }.class, ServedMods::Unavailable)

# A website that lists one mod, Test 1.0, with a package per platform, and serves the PC's.
upload = { "Test/test.rb" => files["Patch/Test/test.rb"], "Test/data.txt" => "アリス\r\n" }
hashes = upload.to_h { |path, bytes| [path, ServedMods.hash_of(bytes)] }
package = zip_of(upload.transform_keys { |name| "Patch/#{name}" })
listed = upload.map { |path, bytes| { "path" => "Patch/#{path}", "sha256" => ServedMods.hash_of(bytes).upcase } }
requests = []
site = TCPServer.new("127.0.0.1", 0)
address = "http://127.0.0.1:#{site.addr[1]}"
served = package
details = { "mod" => { "slug" => "test", "versions" => [{ "version" => "1.0", "packages" => [
  { "platform" => "android", "url" => "#{address}/files/android.zip", "sha256" => "0" * 64, "files" => [] },
  { "platform" => "pc", "url" => "#{address}/files/pc.zip", "sha256" => Digest::SHA256.hexdigest(package), "files" => listed },
] }] } }
Thread.new do
  loop do
    client = site.accept
    path = client.gets.to_s.split(" ")[1]
    requests << path
    nil while (line = client.gets) && line != "\r\n"
    body = case path
           when "/api/mods/test?schema=3" then JSON.generate(details)
           when "/files/pc.zip" then served
           end
    client.write("HTTP/1.1 #{body ? '200 OK' : '404 Not Found'}\r\nContent-Length: #{body.to_s.bytesize}\r\nConnection: close\r\n\r\n#{body}")
    client.close
  end
end
wanted = [["test", "site", "1.0", hashes]]

served = package + "x".b
check("a package that differs from the website's hash is refused",
      raised { ServedMods.fetch(wanted, address, StringIO.new) }&.message.to_s.include?("package differs from the website's hash"), true)
served = package
requests.clear
fetched = ServedMods.fetch(wanted, address, StringIO.new)
check("a world's mod comes from the website's PC package, its files checked against the starter's hashes",
      [fetched.map { |key, mod_files| [key, mod_files.keys.sort] }, requests], [[["test", ["Test/data.txt", "Test/test.rb"]]], ["/api/mods/test?schema=3", "/files/pc.zip"]])
requests.clear
check("and from the cache the next time, without a website", ServedMods.fetch(wanted, nil, StringIO.new) == fetched && requests.empty?, true)
FileUtils.rm_rf(Dir.glob(File.join(cache, "*")))
check("a world pinned to a version the starter's list lacks gets it with the files the website's details list",
      [ServedMods.fetch([["test", "site", "1.0", {}]], address, StringIO.new) == fetched, requests], [true, ["/api/mods/test?schema=3", "/files/pc.zip"]])
check("a copy the website does not serve is refused",
      raised { ServedMods.fetch([["own", "", "0.9", {}]], address) }&.message.to_s.include?("is none the website serves"), true)
check("as is a version the website does not list",
      raised { ServedMods.fetch([["test", "site", "0.9", { "Test/test.rb" => "1" * 64 }]], address) }&.message.to_s.include?("does not list test 0.9"), true)
check("and a starter's copy whose files are not the website's",
      raised { ServedMods.fetch([["test", "site", "1.0", { "Test/test.rb" => "1" * 64 }]], address) }&.message.to_s.include?("other files than the starter's"), true)
check("a mod the cache lacks with no website to ask is refused",
      raised { ServedMods.fetch([["other", "site", "1", { "O.rb" => "2" * 64 }]], nil) }&.message.to_s.include?("knows no website"), true)

loaded = ServedMods.load(fetched, StringIO.new)
check("the mod's scripts load and read its other files from memory as if they lay in Patch",
      [loaded, TEST_DATA.force_encoding("UTF-8"), File.exist?("Patch/Test/data.txt"), File.open("Patch\\Test\\data.txt", &:read).force_encoding("UTF-8"), File.size("Patch/Test/data.txt")],
      [1, "アリス\r\n", true, "アリス\r\n", 11])
check("files outside the mods read as ever", [File.exist?("Patch/Test/none.txt"), File.exist?(__FILE__)], [false, true])
check("the same mods load once in a process that hosts one battle after another", ServedMods.load(fetched, StringIO.new), 0)
FileUtils.rm_rf(cache)
