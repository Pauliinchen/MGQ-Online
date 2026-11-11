#----------------------------------------------------------------
#  mods_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Moved the checks of loading a world's mods into framework_test.rb, which has the real framework
#      Paulinchen  2026-11-08: Fetched a world's mod from a stand-in website's catalog, its package and files checked against the hashes
#                            - Fetched a version the starter names without files, as a pinned world does
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Tests of mods.rb without the game: the zips it reads and fetching a world's mods from a stand-in
# website into the cache. Loading them runs in framework_test.rb, on the real framework.

require "tmpdir"
require_relative "support"

cache = Dir.mktmpdir("battle-mods")
ENV["BATTLE_MOD_CACHE"] = cache
require_relative File.join(LIB_DIR, "mods")

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
routes = {}
address, requests = stand_in_site(routes)
package = list_on_site(routes, address, "test", "1.0", upload)
wanted = [["test", "site", "1.0", hashes]]

routes["/files/test/pc.zip"] = package + "x".b
check("a package that differs from the website's hash is refused",
      raised { ServedMods.fetch(wanted, address, StringIO.new) }&.message.to_s.include?("package differs from the website's hash"), true)
routes["/files/test/pc.zip"] = package
requests.clear
fetched = ServedMods.fetch(wanted, address, StringIO.new)
check("a world's mod comes from the website's PC package, its files checked against the starter's hashes",
      [fetched.map { |key, mod_files| [key, mod_files.keys.sort] }, requests], [[["test", ["Test/data.txt", "Test/test.rb"]]], ["/api/mods/test?schema=3", "/files/test/pc.zip"]])
requests.clear
check("and from the cache the next time, without a website", ServedMods.fetch(wanted, nil, StringIO.new) == fetched && requests.empty?, true)
FileUtils.rm_rf(Dir.glob(File.join(cache, "*")))
check("a world pinned to a version the starter's list lacks gets it with the files the website's details list",
      [ServedMods.fetch([["test", "site", "1.0", {}]], address, StringIO.new) == fetched, requests], [true, ["/api/mods/test?schema=3", "/files/test/pc.zip"]])
check("a copy the website does not serve is refused",
      raised { ServedMods.fetch([["own", "", "0.9", {}]], address) }&.message.to_s.include?("is none the website serves"), true)
check("as is a version the website does not list",
      raised { ServedMods.fetch([["test", "site", "0.9", { "Test/test.rb" => "1" * 64 }]], address) }&.message.to_s.include?("does not list test 0.9"), true)
check("and a starter's copy whose files are not the website's",
      raised { ServedMods.fetch([["test", "site", "1.0", { "Test/test.rb" => "1" * 64 }]], address) }&.message.to_s.include?("other files than the starter's"), true)
check("a mod the cache lacks with no website to ask is refused",
      raised { ServedMods.fetch([["other", "site", "1", { "O.rb" => "2" * 64 }]], nil) }&.message.to_s.include?("knows no website"), true)
FileUtils.rm_rf(cache)
