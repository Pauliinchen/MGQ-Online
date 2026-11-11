#----------------------------------------------------------------
#  save_distribution_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Held the client's check to its own verdicts, since the battle server no longer checks saves
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Checks a fetched starting save before the game loads it (world_save_distribution.rbx): a save
# from another player may name only the game's classes and Ruby's plain values.

require_relative "support"
require "set"
require "tmpdir"

# Stands in for the mod's log: records each line in $log.
module MGQ_Multiplayer; module Log; def self.write(message); $log << message; end; end; end
$log = []
# The game's load screen, which the save screen builds on.
class Scene_Load; end

load_script "world_save_distribution"

# Stand-ins for the game's classes a save holds.
class Game_Actor
  attr_accessor :name, :skills
end

# The game's database classes.
module RPG
  # A skill of the database.
  class Skill
    attr_accessor :id
  end
end

# A class of the game that counts in $built how often Marshal built one.
class Game_Built
  # Dumps nothing of its own.
  #
  # @return [Integer] A stand-in value.
  def marshal_dump
    1
  end

  # Counts the build.
  #
  # @param _value [Integer] What marshal_dump gave.
  def marshal_load(_value)
    $built += 1
  end
end

# A world on this PC, as check and discard read it.
SaveWorld = Struct.new(:id, :save_folder)

# Writes a fetched starting save into a world's folder, checks it and tells what came of it.
#
# @param save [String] The save's bytes.
# @param system [String, nil] The system save's bytes, nil for none.
# @return [Array] The text for the player (nil when it loads), the files left and the Game_Built
#   objects Marshal built.
def fetched(save, system = nil)
  $built = 0
  Dir.mktmpdir do |folder|
    world = SaveWorld.new("w1", folder)
    File.open("#{folder}/Save01.rvdata2", "wb") { |file| file.write(save) }
    File.open("#{folder}/SystemSave.rvdata2", "wb") { |file| file.write(system) } if system
    text = MGQ_MpSaveDistribution.check(world)
    [text, Dir.children(folder).sort, $built]
  end
end

actor = Game_Actor.new
actor.name = "Hero"
actor.skills = [RPG::Skill.new.tap { |skill| skill.id = 1 }, :symbol, 1.5, (1..3), { "k" => [nil, true] }]
save = Marshal.dump({ :header => Game_Built.new }) + Marshal.dump({ :actors => [actor, actor] })
check("a save of the game's classes and plain values loads", fetched(save, Marshal.dump([1, "two"])),
      [nil, ["Save01.rvdata2", "SystemSave.rvdata2"], 1])

gadget = "\x04\x08U:\x15Gem::Requirement[\x00".force_encoding("ASCII-8BIT")
check("a save holding a known gadget is thrown away before Marshal reads any of it", fetched(save + gadget),
      [MGQ_MpSaveDistribution::REFUSED_TEXT, [], 0])
check("and the log says why", $log.grep(/refused: marshal_load of Gem::Requirement, which is not the game's/).size, 1)
check("a system save naming one of Ruby's own classes stops the save beside it from loading too",
      fetched(save, Marshal.dump(Process.times)), [MGQ_MpSaveDistribution::REFUSED_TEXT, [], 0])
check("a save naming a class this game lacks still names the mod it needs",
      fetched("\x04\x08o:\x12Unknown_Thing\x00".force_encoding("ASCII-8BIT"))[0],
      "The starting save needs a mod you do not have.")

# Tells what the client's check says of a stream.
#
# @param bytes [String] One or more Marshal streams.
# @return [String] Its refusal, "passed" when it passed.
def verdict(bytes)
  MGQ_MpSaveDistribution::ClassCheck.new(bytes).check
  "passed"
rescue MGQ_MpSaveDistribution::ClassCheck::Refused => e
  e.message
end

refused = "the save was refused: "
[
  ["a save", save, "passed"],
  ["a known gadget", gadget, "#{refused}marshal_load of Gem::Requirement, which is not the game's (at byte 21)"],
  ["Ruby's Set", Marshal.dump(Set.new([1])), "#{refused}object of Set, which is not the game's (at byte 8)"],
  ["a new class inside Kernel", "\x04\x08o:\x11Kernel::Evil\x00", "#{refused}object of Kernel::Evil, which is not the game's (at byte 17)"],
  ["a cut save", save[0, save.bytesize / 2], "#{refused}the stream ends early (at byte 83)"],
  ["bytes that are not Marshal", "not a save at all", "#{refused}not a Marshal stream (at byte 0)"],
  ["nesting 2000 deep", "\x04\x08" + "[\x06" * 2000 + "0", "#{refused}nested too deep (at byte 1004)"],
  ["a length past the end", "\x04\x08\"\x7f", "#{refused}a length past the end (at byte 4)"],
  ["a link to a symbol that does not exist", "\x04\x08o;\x09\x00", "#{refused}a link to symbol 4, which does not exist (at byte 5)"],
].each do |label, bytes, expected|
  check("the check's verdict on #{label}", verdict(bytes.dup.force_encoding("ASCII-8BIT")), expected)
end
