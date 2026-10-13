#----------------------------------------------------------------
#  actors_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-13: Used a placeholder hero key
#      Paulinchen  2026-10-11: Checked a rebuilt character's owner and its own name
#      Paulinchen  2026-10-07: Checked that a hero that cannot be read is logged once
#      Paulinchen  2026-10-06: Checked the fingerprint's databases and a rebuilt character's equipment and affection
#      Paulinchen  2026-10-05: Created
#
#----------------------------------------------------------------

# Covers how core_actors.rbx writes and reads a character's build: the hero of a replaced Luka,
# lines without a hero, the fingerprint of the databases builds name, and what a rebuilt character
# leaves of the player's save alone.

require_relative "support"

$log = []
# Stands in for the loader's log, keeping its lines in $log.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end
# Stands in for the game's character.
class Game_Actor; end
# A database entry, of which only the name is read.
Named = Struct.new(:name)
$data_actors = [nil, Named.new("Luka"), Named.new("Alice")]
$data_classes = [nil] + Array.new(200) { Named.new("Class") }
$data_skills = [nil] + Array.new(100) { Named.new("Skill") }
$data_items = [nil]

load_script "core_actors"
builds = MGQ_MpActors::Builds

# A member line of 0.4.1: its fourteen fields.
OLD = "member=1;5;92;151;92:1,151:1;0,0,0,0,0,0,0,0;10,11;;;;100,10,20,20,20,20,20,20;950,50,40,0,0,0,0;;"

check("a line of 0.4.1 reads, with no hero", [builds.parse(OLD, 4).size, builds.parse(OLD, 4)[0].hero], [1, ""])
check("a line with a hero reads it", builds.parse(OLD + ";sample_hero", 4)[0].hero, "sample_hero")
check("a hero that is no key is left out", builds.parse(OLD + ";../x", 4)[0].hero, "")
check("a line with a field too many is unreadable", builds.parse(OLD + ";sample_hero;more", 4), [])

# Stands in for Luka Replacer, which names the hero of a replaced Luka.
module MGQ_LukaReplacer; def self.hero_key(actor); actor == :luka ? "sample_hero" : ""; end; end
check("Luka Replacer names the replaced Luka's hero", [builds.hero_of(:luka), builds.hero_of(:alice)], ["sample_hero", ""])
$log.clear
MGQ_LukaReplacer.define_singleton_method(:hero_key) { |_actor| raise "broken" }
check("a hero that cannot be read is written as none, logged once", [builds.hero_of(:luka), builds.hero_of(:luka), $log],
      ["", "", ["actors: could not read a character's hero, writing none: RuntimeError: broken"]])

# The fingerprint tells the weapons' and armors' databases apart too, since builds carry their ids.
$data_weapons = [nil, Named.new("Sword")]
$data_armors = [nil]
$data_enemies = [nil]
$data_states = [nil]
check("the fingerprint counts every database a build names", builds.game, "#{builds::FORMAT}:3,201,101,1,2,1,1,1")

# A rebuilt character: enchanted equipment past the player's switch, and the player's affection.
# The game's switch that turns enchanted equipment off.
module NWConst; module Sw; ENCHANT_OFF = 502; end; end
# Stands in for a piece of enchanted equipment.
module RPG; class EquipItem; def enchant_item?; true; end; end; end
# Stands in for the game's switches, counting each time the enchantment switch is turned on.
class Game_Switches
  attr_reader :unequipped
  def initialize; @data = []; @unequipped = 0; end
  def [](id); @data[id]; end
  def []=(id, value); @data[id] = value; @unequipped += 1 if value && id == NWConst::Sw::ENCHANT_OFF; end
end
# A character equips enchanted equipment while the switch is off and keeps its affection in
# $affection.
class Game_Actor
  def equippable?(_item); !$game_switches[NWConst::Sw::ENCHANT_OFF]; end
  def love=(value); $affection = value; end
end
$game_switches = Game_Switches.new
$game_switches[NWConst::Sw::ENCHANT_OFF] = true
rebuilt = Game_MpActor.allocate
rebuilt.instance_variable_set(:@member, builds.parse(OLD, 4)[0])
check("enchanted equipment is allowed without the switch's setter, which takes the party's off",
      [rebuilt.equippable?(RPG::EquipItem.new), $game_switches[NWConst::Sw::ENCHANT_OFF], $game_switches.unequipped], [true, true, 1])
$affection = 7
rebuilt.love = 9
check("a won battle leaves the player's affection alone", $affection, 7)

# A rebuilt character's owner and its own name, which the battle status window colors by player.
rebuilt.instance_variable_set(:@player, "Player A")
rebuilt.define_singleton_method(:actor) { Named.new("Alice") }
check("a rebuilt character names its owner, its own name and both", [rebuilt.owner, rebuilt.base_name, rebuilt.name], ["Player A", "Alice", "Alice (Player A)"])
