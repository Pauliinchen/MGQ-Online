#----------------------------------------------------------------
#  actors_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Checked the fingerprint's databases, a rebuilt character's enchanted equipment past the switch's setter, and that its affection stays the owner's
#      Paulinchen  2026-10-05: Created
#
#----------------------------------------------------------------

# Covers how core_actors.rbx writes and reads a character's build: the hero of Luka Replacer only
# for a replaced Luka, and lines of 0.4.1 without it read as before; the fingerprint of the data
# builds name; and what a rebuilt character leaves of the player's save alone.

require_relative "support"

$log = []
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end
class Game_Actor; end
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
check("a line with a hero reads it", builds.parse(OLD + ";kazuya", 4)[0].hero, "kazuya")
check("a hero that is no key is left out", builds.parse(OLD + ";../x", 4)[0].hero, "")
check("a line with a field too many is unreadable", builds.parse(OLD + ";kazuya;more", 4), [])

# The hero a character shows, as Luka Replacer names it.
module MGQ_LukaReplacer; def self.hero_key(actor); actor == :luka ? "kazuya" : ""; end; end
check("Luka Replacer names the replaced Luka's hero", [builds.hero_of(:luka), builds.hero_of(:alice)], ["kazuya", ""])

# The fingerprint tells the weapons' and armors' databases apart too, since builds carry their ids.
$data_weapons = [nil, Named.new("Sword")]
$data_armors = [nil]
$data_enemies = [nil]
$data_states = [nil]
check("the fingerprint counts every database a build names", builds.game, "#{builds::FORMAT}:3,201,101,1,2,1,1,1")

# A rebuilt character: enchanted equipment past the player's switch, and the player's affection.
module NWConst; module Sw; ENCHANT_OFF = 502; end; end
module RPG; class EquipItem; def enchant_item?; true; end; end; end
class Game_Switches
  attr_reader :unequipped
  def initialize; @data = []; @unequipped = 0; end
  def [](id); @data[id]; end
  def []=(id, value); @data[id] = value; @unequipped += 1 if value && id == NWConst::Sw::ENCHANT_OFF; end
end
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
