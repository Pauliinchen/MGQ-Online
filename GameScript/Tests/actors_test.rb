#----------------------------------------------------------------
#  actors_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Checked that a rebuild applies the steps C# lists with the game's own changers and settles once
#      Paulinchen  2026-11-07: Dropped the checks of the hero of a replaced Luka
#      Paulinchen  2026-11-05: Checked the facts handed to C# and the members made of those it reads instead of the text's fields
#      Paulinchen  2026-10-31: Checked that a rebuild measured in battle compares as its owner's game measured it
#      Paulinchen  2026-10-13: Used a placeholder hero key
#      Paulinchen  2026-10-11: Checked a rebuilt character's owner and its own name
#      Paulinchen  2026-10-07: Checked that a hero that cannot be read is logged once
#      Paulinchen  2026-10-06: Checked the fingerprint's databases and a rebuilt character's equipment and affection
#      Paulinchen  2026-10-05: Created
#
#----------------------------------------------------------------

# Covers what core_actors.rbx hands C# of a character's build and makes of what C# reads: the
# facts of a character and its enchanted equipment, the members this game's data knows, the
# fingerprint of the databases builds name, what a rebuilt character leaves of the player's save
# alone, how a rebuild compares with its owner's game outside of battle, and how a rebuild applies
# the steps C# lists with the game's own changers.

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
$data_weapons = [nil, Named.new("Sword")]
$data_armors = [nil]
$data_enemies = [nil]
$data_states = [nil]

# Stands in for the DLL, answering the builds' topics with the facts in $read and the requests kept.
require_relative "bridge_support"
load_bridge
$actors_fake = FakeBridge.new
$requests = []
$actors_fake.answer("builds.write") { |request| $requests << request; "text" }
$actors_fake.answer("builds.read") { |request| $requests << request; $read }
$actors_fake.answer("builds.game") { |sizes| $requests << sizes; "3:#{sizes.join(',')}" }
MGQ_Multiplayer::Bridge.open($actors_fake)

load_script "core_actors"
builds = MGQ_MpActors::Builds

# The game's database items and equipment: a sword enchanted as the game keeps its rolls.
module RPG
  # Stands in for a piece of equipment, enchanted when its stats roll.
  class EquipItem
    attr_accessor :id, :base_data, :rarity_num, :plus_num, :socket_num, :enchant_variance_base, :params_variance, :enchants_variance
    def enchant_item?; params_variance ? true : false; end
    def socket_item?; false; end
  end
  # Stands in for a weapon.
  class Weapon < EquipItem; end
end
# Stands in for a slot of equipment.
Slot = Struct.new(:object)
# Stands in for a player's character, its fields as the game keeps them.
class Sample_Actor
  attr_reader :id, :base_level, :class_id, :tribe_id, :level_list
  def initialize
    @id, @base_level, @class_id, @tribe_id, @level_list = 2, 30, 92, 151, { 92 => 5, 151 => 3 }
    @param_plus, @skills, @abilities, @equip_abilities = [1, 0], [10, 11], { 1 => [12, nil] }, nil
    sword = RPG::Weapon.new
    sword.base_data, sword.rarity_num, sword.plus_num, sword.socket_num, sword.enchant_variance_base = Struct.new(:id).new(1), 2, 1, 1, 40
    sword.params_variance = [1.05] + [1.0] * 7
    sword.enchants_variance = { 3 => { 1 => { 2 => 0.5 } } }
    sword.instance_variable_set(:@enchants, [3])
    sword.instance_variable_set(:@stones, [nil])
    @equips = [Slot.new(sword), Slot.new(nil)]
  end
  def param(id); 100 + id; end
  def xparam(id); id * 0.25; end
  def love; 7; end
  def auto_state_with_switch; {}; end
end
$game_system = Struct.new(:battle_count).new(4)
builds.write([Sample_Actor.new])
sword_facts = { "base" => { "weapon" => 1 }, "gems" => [nil],
                "enchant" => { "rarity" => 2, "plus" => 1, "sockets" => 1, "variance" => 40, "enchants" => [3],
                               "stats" => [{ "float" => "1.05" }] + [{ "float" => "1.0" }] * 7, "traits" => [[3, 1, 2, { "float" => "0.5" }]] } }
check("a character's facts go to C# as the game keeps them, its Floats tagged", $requests.last,
      { "actors" => [{ "actor" => 2, "level" => 30, "class" => 92, "tribe" => 151, "levels" => [[92, 5], [151, 3]], "param_plus" => [1, 0],
                       "skills" => [10, 11], "abilities" => [[1, [12, nil]]], "equip_abilities" => [], "equips" => [sword_facts, nil],
                       "params" => (100..107).to_a, "rates" => [0.0, 0.25, 0.5, 1.25, 1.5].map { |rate| { "float" => rate.to_s } },
                       "counters" => [4, 0, 0, 0, 0, 0, 7], "switches" => [] }] })

# What C# read of another game's builds: a character this game knows, with a skill, a race and a
# weapon it lacks, and one of an actor it lacks.
member_facts = { "actor" => 1, "level" => 99_999, "class" => 92, "tribe" => 999, "levels" => [[92, 5], [999, 2]], "param_plus" => [0] * 8,
                 "skills" => [10, 500], "abilities" => [[1, [12, 500]]], "equip_abilities" => [],
                 "equips" => [{ "base" => { "weapon" => 1 } }, { "base" => { "weapon" => 9 } }, nil],
                 "params" => [100, 10, 20, 20, 20, 20, 20, 20], "rates" => [{ "float" => "0.95" }, { "float" => "0.05" }], "counters" => [0] * 7, "switches" => [] }
$read = [member_facts, member_facts.merge("actor" => 50)]
$requests.clear
members = builds.parse("builds", 4)
again = builds.parse("builds", 4)
check("a reading keeps what this game's data knows, asked of C# once for the same text",
      [members.size, members[0].to_a.first(10), members[0].rates, again.size, $requests],
      [1, [1, 9999, 92, nil, { 92 => 5 }, [0] * 8, [10], { 1 => [12] }, {}, [$data_weapons[1], nil, nil]], [0.95, 0.05], 1,
       [{ "text" => "builds", "limit" => 4 }]])

$requests.clear
first = builds.game
check("the fingerprint is written by C# once while the databases' sizes stay, as the map asks it every frame",
      [first, builds.game, $requests], ["3:3,201,101,1,2,1,1,1", first, [[3, 201, 101, 1, 2, 1, 1, 1]]])

# A rebuilt character: enchanted equipment past the player's switch, and the player's affection.
# The game's switch that turns enchanted equipment off.
module NWConst; module Sw; ENCHANT_OFF = 502; end; end
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
sent = builds::Member.new(1, 5, 92, 151, {}, [0] * 8, [], {}, {}, [], [100, 10, 20, 20, 20, 20, 20, 20], [0.95, 0.05, 0.04, 0.0, 0.0], [0] * 7, [])
rebuilt = Game_MpActor.allocate
rebuilt.instance_variable_set(:@member, sent)
enchanted = RPG::Weapon.new
enchanted.params_variance = [1.0]
check("enchanted equipment is allowed without the switch's setter, which takes the party's off",
      [rebuilt.equippable?(enchanted), $game_switches[NWConst::Sw::ENCHANT_OFF], $game_switches.unequipped], [true, true, 1])
$affection = 7
rebuilt.love = 9
check("a won battle leaves the player's affection alone", $affection, 7)

# A rebuilt character's owner and its own name, which the battle status window colors by player.
rebuilt.instance_variable_set(:@player, "Player A")
rebuilt.define_singleton_method(:actor) { Named.new("Alice") }
check("a rebuilt character names its owner, its own name and both", [rebuilt.owner, rebuilt.base_name, rebuilt.name], ["Player A", "Alice", "Alice (Player A)"])

# A rebuilt character in the host's battle, whose stats the game's battle boosters raise, such as
# the boost at full HP: it compares with what its owner's game showed as that game measured it, on
# the map.
# The game's party, which the battle sets in battle.
class Game_Party; def in_battle; @in_battle; end; end
$game_party = Game_Party.new
# The game's names of the stats.
module Vocab; def self.param(id); "Stat#{id}"; end; end
rebuilt.define_singleton_method(:param) { |id| id == 2 && $game_party.in_battle ? sent.params[id] * 1.4 : sent.params[id] }
rebuilt.define_singleton_method(:xparam) { |id| sent.rates[builds::RATES.keys.index(id)] }
MGQ_MpGame.set($game_party, :in_battle, true)
check("a rebuild measured in battle compares as its owner's game measured it, the party still in battle after",
      [rebuilt.differences, $game_party.in_battle], [[], true])
rebuilt.define_singleton_method(:param) { |id| id == 2 ? sent.params[id] * 2 : sent.params[id] }
check("a rebuild that differs outside of battle too still tells", rebuilt.differences, ["Stat2 40 (sent 20)"])

# A rebuild: the game's setup of the actor, then the steps C# lists through the game's changers,
# then the game's settle once, which takes off what the character cannot wear.
# The game's ids of the jobs, the rest being races.
module NWConst; module Class; JOB_RANGE = (1..149).to_a; end; end
# A skill of the database, of which the rebuild reads the skill type.
Skill = Struct.new(:name, :stype_id)
$data_skills = [nil] + Array.new(400) { |index| Skill.new("Skill", index >= 299 ? 4 : 0) }
# The game's character as far as a rebuild reaches it: its setup and changers, each noted in @calls,
# and its settle, which takes off the shield it cannot wear and puts it into the player's bag.
class Game_Actor
  attr_reader :calls, :level_list
  def initialize(actor_id)
    @calls = [[:setup, actor_id, extra_accessory_slot?]]
    @level_list = { 1 => 1, 5 => 1, 151 => 1 }
    @skills = [2, 7]
    @abilities = { 4 => [300, 301] }
    @equip_abilities = { 4 => [301] }
  end
  def all_abilities; @abilities.values.flatten; end
  def change_class(id, kind); @calls << [:change_class, id, kind]; @level_list[id] ||= 1; refresh; end
  def change_level(level, show, kind); @calls << [:change_level, level, show, kind]; refresh; end
  def erase_class(id); @calls << [:erase_class, id]; @level_list.delete(id); end
  def forget_skill(id); @calls << [:forget_skill, id]; @skills.delete(id); @abilities[4].delete(id) if id >= 300; end
  def learn_skill(id); @calls << [:learn_skill, id]; id >= 300 ? @abilities[4] |= [id] : @skills |= [id]; end
  def add_param(id, value); @calls << [:add_param, id, value]; refresh; end
  def remove_ability_all; @calls << [:remove_ability_all]; @equip_abilities.each_value(&:clear); refresh; end
  def force_change_equip(slot, item); @calls << [:force_change_equip, slot, item && item.name]; (@equips ||= [])[slot] = item; refresh; end
  def refresh; release_unequippable_items; refresh_ability_all; end
  def release_unequippable_items(_item_gain = true)
    @calls << [:settle_equipment]
    shield = (@equips || []).index { |item| item && item.name == "Shield" }
    trade_item_with_party(nil, @equips[shield]) if shield
  end
  def refresh_ability_all; @calls << [:settle_abilities]; end
  def trade_item_with_party(_new_item, old_item); $bag << old_item; true; end
  def recover_all; @calls << [:recover_all]; end
  def clear_actions; @calls << [:clear_actions]; end
  def mhp; 100; end
end
$bag = []
shield = Named.new("Shield")
built = builds::Member.new(1, 30, 92, 151, { 10 => 20, 92 => 5, 151 => 3 }, [0, 0, 4, 0, 0, 0, 0, 0], [7, 8], { 4 => [300, 302] }, { 4 => [302, 300] },
                           [Named.new("Sword"), shield, nil, nil, nil, nil], [100] * 8, [0.95] * 5, [0] * 7, [])
$actors_fake.answer("battlers.steps") do |request|
  $requests << request
  [["class", 10, 20], ["job", 92, 5], ["race", 151, 3], ["classes", 10, 92, 151], ["level", 30], ["skills", 7, 8, 300, 302], ["param", 2, 4],
   ["abilities", 302, 300]] + (0...6).map { |slot| ["equip", slot] }
end
$requests.clear
rebuilt = Game_MpActor.new(built, "Player A")
check("a rebuild hands C# what this game's data knows of the build", $requests,
      [{ "class" => 92, "tribe" => 151, "levels" => [[10, 20], [92, 5], [151, 3]], "level" => 30, "skills" => [7, 8], "abilities" => [300, 302],
         "equip_abilities" => [302, 300], "param_plus" => [0, 0, 4, 0, 0, 0, 0, 0], "slots" => 6 }])
check("a rebuild starts from the game's setup with the build's slots, applies the steps with the game's changers and settles once",
      rebuilt.calls,
      [[:setup, 1, true], [:change_class, 10, :class], [:change_level, 20, false, :class], [:change_class, 92, :class], [:change_level, 5, false, :class],
       [:change_class, 151, :tribe], [:change_level, 3, false, :tribe], [:erase_class, 1], [:erase_class, 5], [:change_level, 30, false, :base],
       [:forget_skill, 2], [:forget_skill, 301], [:learn_skill, 7], [:learn_skill, 8], [:learn_skill, 300], [:learn_skill, 302], [:add_param, 2, 4],
       [:remove_ability_all], [:force_change_equip, 0, "Sword"], [:force_change_equip, 1, "Shield"]] +
      (2...6).map { |slot| [:force_change_equip, slot, nil] } + [[:settle_equipment], [:settle_abilities], [:recover_all], [:clear_actions]])
check("the abilities stay set in the build's order, and what the settle takes off stays out of the player's bag",
      [rebuilt.instance_variable_get(:@equip_abilities), $bag], [{ 4 => [302, 300] }, []])
