#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the local worlds as world.rbx kept them before the rules moved to
# MGQOnline.Game and the DLL: the world screen's entries and their order (entries.json), a
# world.ini read and written (ini.json), a world's latest save (saves.json), the game data compared
# (data.json) and the mod picker (modpick.json). Run it on the world.rbx of the version to record:
#
#   git show 2a2c2159:GameScript/Multiplayer/Scripts/world.rbx > world_old.rbx
#   ruby fixtures/worlds/make_fixtures.rb world_old.rbx
#
# The scripts' mods text and mod keys stand in as fixtures/mods/text.json and keys.json show them,
# for plain ASCII names.

require "json"

# The world.rbx recorded.
SOURCE = File.read(ARGV[0] || raise("name the world.rbx to record"), :encoding => "UTF-8")

# Cuts a piece of the source out.
#
# @param pattern [Regexp] The piece.
# @return [String] It.
def piece(pattern)
  SOURCE[pattern] or raise "world.rbx lacks #{pattern.inspect}"
end

# The parts of MGQ_Multiplayer the recorded code calls.
module MGQ_Multiplayer
  # As Multiplayer.rb cleans names.
  MAX_NAME_LENGTH = 32

  # Cleans a name as Multiplayer.rb does.
  #
  # @param name [String] The name.
  # @param fallback [String] What stands in for nothing.
  # @return [String] The name.
  def self.clean(name, fallback = "A friend")
    cleaned = name.to_s.gsub(/[\x00-\x1f\\]/, "").strip[0, MAX_NAME_LENGTH]
    cleaned.empty? ? fallback : cleaned
  end
end

# The recorded module, with stand-ins for what it asks the DLL.
module MGQ_MpWorld
  RAID = "raid"
  SHARING_SYMBOLS = { "off" => :off, "story" => :story, "all" => :all }
  MAX_MODS_CHARS = 16_000
  SQUAD_NAMES = { :luka => "luka", :formation => "formation", :front => "front", :raid_front => "raid_front" }

  # The difficulties of fixtures/world/rules.json.
  #
  # @return [Array<Integer>] They.
  def self.difficulties
    (-2..4).to_a
  end

  # Reads squad rules as fixtures/world/rules.json shows them.
  #
  # @param text [String, nil] The text.
  # @return [Hash, nil] The rules.
  def self.squad_of(text)
    parts = text.to_s.split(" ", -1)
    return nil unless parts.size == 4 && parts.all? { |part| part =~ /\A\d+\z/ }

    luka, formation, front, raid_front = parts.map { |part| part.to_i }
    return nil unless luka <= 1 && (formation == 0 || (4..8).include?(formation)) && (1..4).include?(front) && (1..4).include?(raid_front)

    { :luka => luka == 1, :formation => formation, :front => front, :raid_front => raid_front }
  end

  # Writes squad rules.
  #
  # @param squad [Hash] The rules.
  # @return [String] The text.
  def self.squad_text(squad)
    [squad[:luka] ? 1 : 0, squad[:formation], squad[:front], squad[:raid_front]].join(" ")
  end

  # Reads a mods text as fixtures/mods/text.json shows it.
  def self.mods_of(text)
    names = text.to_s.split(";").map { |mod| mod.strip.sub(/\A[!?]\s*/, "") }.reject { |mod| mod.empty? }
    (names & required_mods(text)) + (names & essential_mods(text)) + (names - required_mods(text) - essential_mods(text))
  end

  # Reads the required mods of a mods text.
  def self.required_mods(text)
    text.to_s.split(";").map { |mod| mod.strip[/\A!\s*(\S.*)\z/, 1] }.compact
  end

  # Reads the essential mods of a mods text.
  def self.essential_mods(text)
    text.to_s.split(";").map { |mod| mod.strip[/\A\?\s*(\S.*)\z/, 1] }.compact
  end

  # Makes the key of a plain ASCII name as fixtures/mods/keys.json shows it.
  def self.mod_key(name)
    name.to_s.downcase.sub(/\.rb\z/, "").delete(" \t\n\v\f\r_-")
  end

  module_eval(piece(/^  def self\.difficulty_of\(text\).*?\n  end\n/m))
  module_eval(piece(/^  def self\.entries\(listed, complete\).*?\n  end\n/m))
  module_eval(piece(/^  Entry = Struct\.new.*?\n  end\n/m))
  module_eval(piece(/^  module GameData\n.*?\n  end\n/m).sub(/^    FILE = .*\n/, ""))
  module_eval(piece(/^  class ModPick\n.*?\n  end\n/m))
end

# A world.ini as World kept it: World's own methods that read, write and find the latest save,
# with its files standing in.
class RecordedWorld
  attr_reader :values_written

  class_eval(piece(/^    def initialize\(id, values\)\n.*?\n    end\n/m))
  class_eval(piece(/^    def write\n.*?\n    end\n/m).sub("World.forget\n", "").sub(/MGQ_Multiplayer::Ini\.write\(.*\)/, "@values_written = values"))
  class_eval(piece(/^    def latest_save_entry\n.*?\n    end\n/m))

  # Gives the recorded code's MGQ_MpWorld calls their module.
  MGQ_MpWorld = ::MGQ_MpWorld

  # Gives the files' names and times.
  #
  # @param files [Array<Array>] [name, mtime] each.
  def files=(files)
    @files = files
  end

  # The world's Save folder, standing in.
  def save_folder
    "Save"
  end

  # Tells what the fields read came to.
  #
  # @return [Hash] The fields.
  def fields
    { "name" => @name, "code" => @code, "world" => @directory_id, "created" => @created, "played" => @played_at && @played_at.to_i, "type" => @type, "share" => @share,
      "difficulty" => @difficulty, "squad" => @squad && MGQ_MpWorld.squad_text(@squad), "raid_bosses" => @raid_bosses }
  end
end

# Stands in for the files of a world's Save folder while latest_save_entry looks at them.
module SaveFiles
  # The [name, mtime] of each file.
  def self.files=(files)
    @files = files
  end

  # @return [Array<Array>] The files.
  def self.files
    @files
  end
end

class << File
  alias_method :recorded_directory?, :directory?
  alias_method :recorded_mtime, :mtime

  # Tells the stand-in Save folder is there.
  def directory?(path)
    path == "Save" ? true : recorded_directory?(path)
  end

  # Tells a stand-in file's time.
  def mtime(path)
    found = SaveFiles.files && SaveFiles.files.find { |name, _| "Save/#{name}" == path }
    found ? Time.at(found[1]) : recorded_mtime(path)
  end
end

class << Dir
  alias_method :recorded_entries, :entries

  # Lists the stand-in Save folder.
  def entries(path, *rest)
    path == "Save" ? [".", ".."] + SaveFiles.files.map { |name, _| name } : recorded_entries(path, *rest)
  end
end

# A listed world, with what entries reads of it.
Listed = Struct.new(:id, :name, :raid, :featured) do
  # @return [Boolean] Whether it is a Raid World.
  def raid?
    raid
  end
end

# A local world, with what entries reads of it.
Local = Struct.new(:id, :name, :directory_id, :raid, :played) do
  # @return [Boolean] Whether it is a Raid World.
  def raid?
    raid
  end

  # @return [Time, nil] When it was played.
  def played_at
    played && Time.at(played)
  end
end

# The worlds of one entries case.
module Recorded
  class << self
    attr_accessor :locals, :favourites
  end
end
MGQ_MpWorld::World = Class.new { def self.all; Recorded.locals; end } unless defined?(MGQ_MpWorld::World)
MGQ_MpWorld::Favourites = Module.new { def self.all; Recorded.favourites; end }

# Writes a fixture.
#
# @param name [String] The file.
# @param value [Object] What it holds.
def write_fixture(name, value)
  File.write(File.join(__dir__, name), JSON.pretty_generate(value) + "\n")
end

ENTRY_CASES = [
  { "listed" => [["a1", "Beta", false, false], ["a2", "alpha", false, false], ["a3", "Raid", true, false], ["a4", "Gold", false, true], ["a5", "Fav", false, false]],
    "local" => [["f1", "Beta here", "a1", false, 300], ["f5", "Fav", "a5", false, 100], ["f9", "Old one", "a9", true, 50], ["f8", "No id", nil, false, nil]],
    "favourites" => ["a5", "a9"], "complete" => true },
  { "listed" => [["b1", "Same", false, false], ["b2", "same", false, false], ["b3", "Same", false, false]],
    "local" => [["g1", "Gone", "b9", false, 10]], "favourites" => [], "complete" => false },
  { "listed" => [["c1", "Zed", true, true], ["c2", "Émile", false, false], ["c3", "emile", false, false], ["c4", "B", false, false]],
    "local" => [["h3", "x", "c3", false, 999], ["h4", "y", "c4", false, 1000]], "favourites" => ["c4", "c1"], "complete" => true },
  { "listed" => [], "local" => [], "favourites" => [], "complete" => true },
]

entries = ENTRY_CASES.map do |entry|
  listed = entry["listed"].map { |fields| Listed.new(*fields) }
  Recorded.locals = entry["local"].map { |fields| Local.new(*fields) }
  Recorded.favourites = entry["favourites"]
  made = MGQ_MpWorld.entries(listed, entry["complete"])
  entry.merge("entries" => made.map { |item| [item.id, item.name, item.listed && item.listed.id, item.local && item.local.id, item.favourite, item.gone] },
              "keys" => made.map { |item| [item.gone ? 1 : 0, item.raid? ? 0 : 1, item.favourite ? 0 : 1, item.featured? ? 0 : 1, -(item.local ? item.local.played_at.to_i : 0), item.name.downcase] })
end
write_fixture("entries.json", { "cases" => entries })

INI_CASES = [
  { "name" => "My World", "code" => "mgqmp2;abc;r1;8", "world" => "d1", "created" => "100", "played" => "200", "type" => "raid", "share" => "story", "difficulty" => "2", "squad" => "1 6 2 1", "raid_bosses" => "0" },
  { "name" => "  \\Back\\slash\tname that is far longer than thirty-two characters  ", "code" => "c", "created" => "x" },
  { "name" => "   ", "code" => "c", "difficulty" => "9", "squad" => "1 3 1 1", "raid_bosses" => "1", "type" => "classic" },
  { "name" => "\\\\", "code" => "c", "difficulty" => "-2", "squad" => "0 0 4 4" },
  { "code" => "c", "difficulty" => " 1", "played" => "abc" },
]

ini = INI_CASES.map do |values|
  world = RecordedWorld.new("id", values)
  world.write
  { "values" => values, "fields" => world.fields, "written" => world.values_written.map { |key, value| [key, value.to_s] } }
end
write_fixture("ini.json", { "cases" => ini })

SAVE_CASES = [
  [],
  [["Save01.rvdata2", 100], ["Save02.rvdata2", 300], ["AutoSave01.rvdata2", 200]],
  [["Save03.rvdata2", 100], ["AutoSave02.rvdata2", 500], ["notes.txt", 900], ["Save1.rvdata2", 950], ["Save001.rvdata2", 960], ["save04.RVDATA2", 400]],
  [["AutoSave01.rvdata2", 700], ["Save05.rvdata2", 700]],
  [["Save12.rvdata2", 10], ["SaveSystem.rvdata2", 9000], ["Save12.png", 20]],
]

saves = SAVE_CASES.map do |files|
  SaveFiles.files = files
  world = RecordedWorld.new("id", "code" => "c")
  { "files" => files, "latest" => world.latest_save_entry }
end
write_fixture("saves.json", { "cases" => saves })

MINE = "1:" + (1..11).map { |part| format("%08x", part) }.join(".")
THEIRS = ["", nil, MINE, "2:" + MINE[2..-1], "1:" + (1..11).map { |part| format("%08x", part == 3 || part == 9 ? 0 : part) }.join("."),
          "1:" + (1..11).map { |part| format("%08x", part + 100) }.join("."), "1:00000001.00000002", "garbage", "1:"]

data = THEIRS.map do |other|
  MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, MINE)
  { "mine" => MINE, "other" => other, "differing" => MGQ_MpWorld::GameData.differing(other) }
end
mine_empty = ["", MINE].map do |other|
  MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, "")
  { "mine" => "", "other" => other, "differing" => MGQ_MpWorld::GameData.differing(other) }
end
texts = [[[], 4], [["skills"], 4], [["skills", "items"], 4], [%w(actors classes skills items), 4], [%w(actors classes skills items weapons armors), 4], [%w(actors classes skills), 2]].map do |parts, named|
  { "parts" => parts, "named" => named, "text" => MGQ_MpWorld::GameData.text(parts, named) }
end
write_fixture("data.json", { "parts" => MGQ_MpWorld::GameData::PARTS, "differing" => data + mine_empty, "texts" => texts })

# Each mod picker case: the mods text, the installed names, then steps of [operation, arguments...],
# with the picker after each step.
PICK_CASES = [
  { "text" => "!Level Cap; ?Data Pack; Party Sheet; Missing Mod", "installed" => ["Invasions", "Level_Cap", "Party_Sheet"],
    "steps" => [["toggle", 0], ["mark", 1, "essential"], ["mark", 1, "essential"], ["mark", 2, "required"], ["set", 3, "unlisted"], ["remove", 3], ["remove", 0],
                ["add", "  ! New Mod "], ["add", "new_mod"], ["add", ""], ["add", "a;b"], ["add", "?"], ["unlist_all"], ["list_all"], ["all_listed"]] },
  { "text" => "", "installed" => [], "steps" => [["all_listed"], ["list_all"], ["add", "Only Added"], ["all_listed"]] },
  { "text" => "Big", "installed" => ["Small"], "steps" => [["add", "<x*15990>"], ["add", "<y*15994>"], ["toggle", 0], ["toggle", 1], ["list_all"]] },
  { "text" => "Ünïcode", "installed" => ["A"], "steps" => [["add", "<é*15990>"], ["toggle", 0]] },
]

# Expands an argument written short: "<x*3>" stands for "xxx".
#
# @param argument [Object] The argument.
# @return [Object] It, expanded.
def expand(argument)
  argument.is_a?(String) && argument =~ /\A<(.)\*(\d+)>\z/ ? $1 * $2.to_i : argument
end

# Describes the picker as a step leaves it.
#
# @param pick [MGQ_MpWorld::ModPick] The picker.
# @return [Hash] Its mods and text.
def pick_view(pick)
  { "entries" => pick.entries.map { |entry| [entry.name.size > 40 ? "#{entry.name[0, 3]}*#{entry.name.size}" : entry.name, entry.state.to_s, entry.installed] }, "text_size" => pick.text.size,
    "text" => pick.text.size > 200 ? nil : pick.text, "all_listed" => pick.all_listed? }
end

picks = PICK_CASES.map do |entry|
  pick = MGQ_MpWorld::ModPick.new(entry["text"], entry["installed"])
  steps = entry["steps"].map do |operation, *arguments|
    given = arguments.map { |argument| %w(listed unlisted required essential).include?(argument) ? argument.to_sym : expand(argument) }
    answer = pick.public_send(operation == "all_listed" ? :all_listed? : operation, *given)
    { "step" => [operation] + arguments, "answer" => answer, "pick" => pick_view(pick) }
  end
  entry.merge("start" => pick_view(MGQ_MpWorld::ModPick.new(entry["text"], entry["installed"])), "steps" => steps)
end
write_fixture("modpick.json", { "cases" => picks })
