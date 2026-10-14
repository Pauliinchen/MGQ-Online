#----------------------------------------------------------------
#  save_check_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Tests of save_check.rb and save.rb: a save may name only the game's classes and Ruby's plain
# values, and Marshal never meets anything else.

require "set"
require "stringio"
require_relative "support"
require_relative File.join(LIB_DIR, "save_check")
SaveCheck.snapshot
require_relative File.join(LIB_DIR, "save")

# Stand-ins for the game's classes, defined after the snapshot as the game's scripts are.
class Game_Actor
  attr_accessor :name, :level, :skills
end

module RPG
  class Skill
    attr_accessor :id
  end
end

GameStruct = Struct.new(:a, :b)

# Tells whether bytes pass the check, and why not.
#
# @param bytes [String] One or more Marshal streams.
# @return [String] "passed", or the refusal.
def verdict(bytes)
  SaveCheck.new(bytes).check(SaveFile::Admitted.new)
  "passed"
rescue SaveCheck::Refused => e
  e.message[/refused: (.*?) \(at byte/, 1] || e.message
end

actor = Game_Actor.new
actor.name = "Luka"
actor.level = 2**70
actor.skills = [RPG::Skill.new.tap { |s| s.id = 1 }, :symbol, 1.5, (1..3), { "k" => [nil, true] }, Rational(1, 3)]
save = Marshal.dump({ characters: [actor, actor] }) + Marshal.dump(actor)
check("a save of the game's classes and plain values passes, links and big numbers included", verdict(save), "passed")
check("a struct of the game passes", verdict(Marshal.dump(GameStruct.new(1, "x"))), "passed")
_header, contents = SaveFile.read(save)
check("a save that passed reads as Marshal reads it", [contents.name, contents.level], ["Luka", 2**70])

check("Gem::Requirement, a known gadget, is refused", verdict("\x04\x08U:\x15Gem::Requirement[\x00".b),
      "marshal_load of Gem::Requirement, which is not the game's")
check("Set, from Ruby's library, is refused", verdict(Marshal.dump(Set.new([1]))), "object of Set, which is not the game's")
check("a struct of Ruby's own is refused", verdict(Marshal.dump(Process.times)), "struct of Process::Tms, which is not the game's")

# An object of a class by name, with no fields.
object_of = ->(name) { "\x04\x08o:".b + [name.bytesize + 5].pack("C") + name.b + "\x00".b }
check("an unknown mod's class is admitted, to become a stand-in", verdict(object_of.("Unknown_Mod::Thing")), "passed")
check("a new class inside Kernel is refused", verdict(object_of.("Kernel::Evil")), "object of Kernel::Evil, which is not the game's")
check("a new class inside the game's own constant is admitted only by its game name", verdict(object_of.("Game_Actor")), "passed")
check("a lowercase name never becomes a stand-in", verdict(object_of.("lower")), "object of lower, which is not the game's")
SaveFile.read(object_of.("Unknown_Mod::Thing") * 2)
check("the stand-in is an empty class", Unknown_Mod::Thing.instance_methods(false), [])

check("a cut save is refused", verdict(save.byteslice(0, save.bytesize / 2)) != "passed", true)
check("bytes that are not Marshal are refused", verdict("not a save at all"), "not a Marshal stream")
check("nesting 2000 deep is refused", verdict("\x04\x08".b + "[\x06".b * 2000 + "0".b), "nested too deep")
check("a length past the end is refused", verdict("\x04\x08\"\x7f".b), "a length past the end")
check("a link to a symbol that does not exist is refused", verdict("\x04\x08o;\x09\x00".b), "a link to symbol 4, which does not exist")
