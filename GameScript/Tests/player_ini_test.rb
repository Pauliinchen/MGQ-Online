#----------------------------------------------------------------
#  player_ini_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Created
#
#----------------------------------------------------------------

# Covers Player.ini (Multiplayer.rb's Ini and Player) and the world lists world.rbx keeps in it:
# reading it in any encoding Notepad saves, writing it in one step, leaving one that cannot be read
# as it is, and moving Favourites.ini and Added.ini into it.

require_relative "support"
require "tmpdir"

source = File.read(File.expand_path("../Multiplayer.rb", __dir__), encoding: "UTF-8").gsub("\r\n", "\n")
world_source = File.read(File.join(SCRIPTS_DIR, "world.rbx"), encoding: "UTF-8").gsub("\r\n", "\n")

$log = []
$new_ids = 0
# Stands in for Multiplayer.rb, around the Ini and Player modules taken from it.
module MGQ_Multiplayer
  # Answers the file name as it is, so files land in the current folder.
  def self.path(name); name; end
  # Answers the name as it is.
  def self.clean(name, _fallback = nil); name; end
  # Stands in for the mod's log: records each line in $log.
  module Log; def self.write(message); $log << message; end; end
  # Stands in for the Discord bridge: the player's name on Discord is $discord_name.
  module Discord; def self.player_name; $discord_name; end; end
  # Stands in for the DLL link.
  module Link
    # Counts the call in $new_ids and answers the key "newkey".
    def self.new_id; $new_ids += 1; "newkey"; end
    # Takes any key and name.
    def self.set_player(_key, _name); true; end
  end
end
MGQ_Multiplayer.module_eval(source[/  module Ini\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  module Player\n.*?\n  end\n/m])

# Stands in for world.rbx, around the settings and list modules taken from it.
module MGQ_MpWorld
  # Records the line in $log, tagged "world: ".
  def self.log(message); $log << "world: #{message}"; end
  # Answers the id as it is.
  def self.short(id); id; end
end
%w[FAVOURITE_SETTING ADDED_SETTING OLD_LIST_FILES].each do |name|
  MGQ_MpWorld.module_eval(world_source[/^  #{name} = .*$/])
end
%w[OldLists Added Favourites].each do |name|
  MGQ_MpWorld.module_eval(world_source[/  module #{name}\n.*?\n  end\n/m])
end

player = MGQ_Multiplayer::Player
ini = MGQ_Multiplayer::Ini

# Starts Player and the old lists afresh, as a new session does, and clears the log.
fresh = lambda do
  [:@values, :@unreadable_at, :@refused, :@noticed].each { |name| player.instance_variable_set(name, nil) }
  [:@merged, :@tried_at].each { |name| MGQ_MpWorld::OldLists.instance_variable_set(name, nil) }
  $log.clear
  $new_ids = 0
end
# Reads a file's bytes.
#
# @param path [String] The file.
# @return [String] Its bytes.
bytes = lambda { |path| File.open(path, "rb") { |file| file.read } }
# Counts the log lines that hold a text.
#
# @param text [String] The text.
# @return [Integer] How many lines hold it.
logged = lambda { |text| $log.count { |line| line.include?(text) } }

Dir.mktmpdir do |root|
  Dir.chdir(root) do
    # A byte order mark is skipped.
    fresh.call
    File.binwrite("Player.ini", "\xEF\xBB\xBFid=abc\r\nname=X\r\n")
    check("a Player.ini with a byte order mark keeps its key and makes no new one", [player.id, player.setting("name"), $new_ids], ["abc", "X", 0])

    # Notepad's other encodings read too.
    fresh.call
    File.binwrite("Player.ini", "id=abc\nname=J\xF6rg\n")
    check("one saved as ANSI reads as Latin-1, so the key and the name with an umlaut stay", [player.id, player.setting("name"), $new_ids], ["abc", "Jörg", 0])
    fresh.call
    File.binwrite("Player.ini", "\xFF\xFE".b + "id=abc\r\nname=Jö😀\r\n".encode("UTF-16LE").b)
    check("one saved as UTF-16 keeps its key and its name, an emoji too", [player.id, player.setting("name")], ["abc", "Jö😀"])
    fresh.call
    File.binwrite("Player.ini", "\xFE\xFF".b + "id=abc\n".encode("UTF-16BE").b)
    check("big-endian too", player.id, "abc")
    player.store("k", "v")
    check("and the next write saves it as UTF-8", bytes.call("Player.ini"), "id=abc\nk=v\n")

    # A Player.ini that exists but cannot be read is left as it is.
    fresh.call
    File.delete("Player.ini")
    Dir.mkdir("Player.ini")
    $discord_name = "Disco"
    results = [player.id, player.store("k", "v"), player.forget("k"), player.change("a" => "1"), player.id]
    check("one that cannot be read gets no new key and takes no setting", [results, $new_ids], [["", false, false, false, ""], 0])
    check("it stays as it is, with no file left next to it", [File.directory?("Player.ini"), File.exist?("Player.ini.tmp")], [true, false])
    3.times { player.name }
    check("the name on Discord stands, and is not logged as kept", [player.name, logged.call("kept the name Discord told")], ["Disco", 0])
    check("the failed read and the refusal are logged once", [logged.call("could not read Player.ini"), logged.call("not writing it")], [1, 1])
    check("the notice is taken once a session", [player.take_notice, player.take_notice], [MGQ_Multiplayer::Player::UNREADABLE_NOTICE, nil])
    Dir.rmdir("Player.ini")
    File.binwrite("Player.ini", "id=abc\n")
    check("within a second it is not read again", [player.id, player.readable?], ["", false])
    player.instance_variable_set(:@unreadable_at, Time.now - 2)
    check("after it, it is read again and its key holds", [player.id, $new_ids, logged.call("read Player.ini again")], ["abc", 0, 1])

    # Writing replaces the file in one step.
    check("a setting kept leaves the key and no file next to it", [player.store("k", "v"), bytes.call("Player.ini"), File.exist?("Player.ini.tmp")],
          [true, "id=abc\nk=v\n", false])
    player.change("z" => "1", "k" => "w", "gone" => nil)
    check("several settings change in one write, a setting kept moving to the end", bytes.call("Player.ini"), "id=abc\nz=1\nk=w\n")
    check("a prefix lists its settings in the file's order", [player.store("p.b", 1), player.store("p.a", 2), player.keys_under("p.")], [true, true, ["b", "a"]])
    Dir.mkdir("Blocked")
    check("a write that cannot replace its file fails and leaves no file next to it",
          [ini.write("Blocked", "a" => "1"), File.directory?("Blocked"), File.exist?("Blocked.tmp")], [false, true, false])
    fresh.call
    File.delete("Player.ini")
    check("a missing Player.ini gets a new key", [player.id, bytes.call("Player.ini"), $new_ids], ["newkey", "id=newkey\n", 1])

    # Favourites.ini and Added.ini move into Player.ini.
    fresh.call
    File.binwrite("Player.ini", "id=abc\nfavourite.w1=1\n")
    File.binwrite("Favourites.ini", "w1=1\nw2=1\n")
    File.binwrite("Added.ini", "a1=1\na2=1\n")
    check("the old files move into Player.ini, which keeps what it held", [MGQ_MpWorld::Favourites.all, MGQ_MpWorld::Added.all], [["w1", "w2"], ["a1", "a2"]])
    check("and are deleted", [bytes.call("Player.ini"), File.exist?("Favourites.ini"), File.exist?("Added.ini")],
          ["id=abc\nfavourite.w1=1\nfavourite.w2=1\nadded.a1=1\nadded.a2=1\n", false, false])

    fresh.call
    File.binwrite("Player.ini", "id=abc\n")
    Dir.mkdir("Favourites.ini")
    File.binwrite("Added.ini", "a1=1\n")
    check("while one old file cannot be read, nothing moves and nothing is deleted",
          [MGQ_MpWorld::Added.all, bytes.call("Player.ini"), File.exist?("Added.ini")], [[], "id=abc\n", true])
    Dir.rmdir("Favourites.ini")
    File.binwrite("Favourites.ini", "w1=1\n")
    MGQ_MpWorld::Added.all
    check("nor within a second after", File.exist?("Added.ini"), true)
    MGQ_MpWorld::OldLists.instance_variable_set(:@tried_at, Time.now - 2)
    check("then it is tried again", [MGQ_MpWorld::Favourites.all, MGQ_MpWorld::Added.all, File.exist?("Added.ini")], [["w1"], ["a1"], false])

    fresh.call
    File.delete("Player.ini")
    Dir.mkdir("Player.ini")
    File.binwrite("Favourites.ini", "w9=1\n")
    check("while Player.ini cannot be read, nothing moves, and a world stays as it was",
          [MGQ_MpWorld::Favourites.all, MGQ_MpWorld::Favourites.toggle("w9"), File.exist?("Favourites.ini"), File.directory?("Player.ini")], [[], nil, true, true])
    Dir.rmdir("Player.ini")
    File.delete("Favourites.ini")

    # The favourites and hidden worlds kept in Player.ini.
    fresh.call
    File.binwrite("Player.ini", "id=abc\n")
    check("a world marked is a favourite, and no longer once unmarked",
          [MGQ_MpWorld::Favourites.toggle("w1"), MGQ_MpWorld::Favourites.all, MGQ_MpWorld::Favourites.toggle("w1"), MGQ_MpWorld::Favourites.all], [true, ["w1"], false, []])
    (1..MGQ_MpWorld::Added::MAX).each { |n| MGQ_MpWorld::Added.add("h#{n}") }
    MGQ_MpWorld::Added.add("h1")
    MGQ_MpWorld::Added.add("new")
    check("a hidden world added again moves to the end, and the oldest goes beyond the limit",
          [MGQ_MpWorld::Added.all.size, MGQ_MpWorld::Added.all.first, MGQ_MpWorld::Added.all.last(2), MGQ_MpWorld::Added.all.include?("h2")],
          [MGQ_MpWorld::Added::MAX, "h3", ["h1", "new"], false])
    MGQ_MpWorld::Added.remove("new")
    check("and one removed is gone", MGQ_MpWorld::Added.all.include?("new"), false)
  end
end
