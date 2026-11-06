#----------------------------------------------------------------
#  balance_pvp_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Answered the balance's values, hits and walls with fixed values and checked what the script asks and applies
#      Paulinchen  2026-10-07: Checked that the log tells each character's changes, the hits the balance lowers and its end
#      Paulinchen  2026-10-06: Checked that a check reads the stats without the balance, and the balance by the stats alone
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# Covers battles_balance_pvp.rbx: the balance's values, hits and defense walls as the DLL answers
# them, applied only while a PvP battle runs with the balance. PvpBalanceTests own the rules.

require_relative "support"
require_relative "bridge_support"

$log = []
# Stands in for the loader's log, keeping its lines in $log.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end
# Stands in for the game's scene manager.
module SceneManager; def self.run; end; end
# Stands in for the battle scene, whose use_item is one action.
class Scene_Battle; def use_item; end; end
scene = Scene_Battle.new

# The game's battler, as far as the balance wraps it.
class Game_BattlerBase
  attr_accessor :hp, :stats
  def param(param_id); @stats[param_id]; end
  def mhp; param(0); end
  def dead?; @hp == 0; end
  attr_accessor :taken
  def pdr; @taken; end
  def mdr; @taken; end
  def certain_damage_rate; @taken; end
end
# Stands in for a character with the stats, evasion, reflection, element rate and defense walls a
# test sets.
class Game_Battler < Game_BattlerBase
  attr_accessor :evasion, :reflection, :element, :walls
  def initialize(stats, hp = stats[0])
    @stats = stats
    @hp = hp
    @evasion = 0.0
    @reflection = 0.0
    @element = 1.0
    @walls = 0
    @taken = 1.0
  end
  def enemy_calculation?; false; end
  def apply_guard(damage); damage; end
  def item_eva(_user, _item); @evasion; end
  def item_mrf(_user, _item); @reflection; end
  def item_element_rate(_user, _item); @element; end
  # Uses up a wall, which takes the whole hit.
  def apply_defense_wall(damage, _item)
    return damage if @walls == 0

    @walls -= 1
    0
  end
end

# The game's view of a battler inside a damage formula.
class DamageEvalBattler < BasicObject
  def initialize(battler); @battler = battler; @battler_param = []; end
  def mhp; __battler_param(0); end
  def atk; __battler_param(2); end

  private

  def __battler_param(param_id); @battler_param[param_id] ||= @battler.param(param_id); end
end

# A skill or item, aimed at the opponent or not.
Item = Struct.new(:opponent) do
  def for_opponent?; opponent; end
end
attack = Item.new(true)
heal = Item.new(false)

load_script "battles_balance_pvp"
# The DLL's side of the bridge, answering the balance's values, and a hit and a wall with what each
# test sets in $hit and $wall.
bridge = FakeBridge.new
asked = []
bridge.answer("pvp.rules") do
  { "hp_rate" => 4, "monster_formulas" => true, "avoid_ceiling" => "0.75", "element_floor" => "0.25", "taken_floor" => "0.25" }
end
bridge.answer("pvp.hit") { |request| asked << request; $hit }
bridge.answer("pvp.wall") { |request| asked << request; $wall }
MGQ_Multiplayer::Bridge.open(bridge)
SceneManager.run
balance = MGQ_MpBalancePvp

fighter = Game_Battler.new([7500, 500, 490], 7500)
fallen = Game_Battler.new([6000, 400, 300], 0)
fighter.evasion = 1.0
fighter.reflection = 1.0
fighter.element = 0.0
fighter.walls = 2

check("outside a PvP battle the stats are the game's", [fighter.mhp, fighter.param(2)], [7500, 490])
check("outside a PvP battle a character's skills use the formulas for players", fighter.enemy_calculation?, false)
check("outside a PvP battle a hit deals what the game works out, unasked", [fighter.apply_guard(52_000_000_000_000), asked], [52_000_000_000_000, []])
check("outside a PvP battle evasion, reflection and elements are the game's",
      [fighter.item_eva(nil, attack), fighter.item_mrf(nil, attack), fighter.item_element_rate(nil, attack)], [1.0, 1.0, 0.0])
check("outside a PvP battle a defense wall takes the whole hit", [fighter.apply_defense_wall(90_000, attack), fighter.walls], [0, 1])

balance.begin([fighter, fallen])
check("the balance raises max HP by the DLL's rate and no other stat", [fighter.mhp, fighter.param(2)], [30_000, 490])
check("a character's skills use the formulas for monsters", fighter.enemy_calculation?, true)
check("the added HP is filled, except for a dead character", [fighter.hp, fallen.hp], [30_000, 0])
check("a check reads the stats as they are without the balance, which then holds again", [balance.unbalanced { [fighter.mhp, fighter.enemy_calculation?] }, fighter.mhp], [[7500, false], 30_000])
check("a damage formula reads max HP as it is without the balance", [DamageEvalBattler.new(fighter).mhp, DamageEvalBattler.new(fighter).atk], [7500, 490])
scene.use_item
$hit = "10937.5"
first = fighter.apply_guard(30_000)
$hit = "1200.25"
second = fighter.apply_guard(30_000)
check("a hit deals what the DLL leaves of it", [first, second], [10_937.5, 1200.25])
check("asked with the target's max HP and what the action dealt it before",
      asked, [{ "max_hp" => 30_000, "before" => "0.0", "value" => "30000" }, { "max_hp" => 30_000, "before" => "30000.0", "value" => "30000" }])
fallen.apply_guard(24_000)
check("another target of the same action is counted by itself", asked.last["before"], "0.0")
check("healing keeps its sign and is counted apart from damage", [fighter.apply_guard(-30_000), asked.last["before"]], [-1200.25, "0.0"])
scene.use_item
fighter.apply_guard(30_000)
check("the next action counts anew", asked.last["before"], "0.0")
fighter.taken = 0.0
check("a character that takes no damage at all takes the floor", [fighter.pdr, fighter.mdr, fighter.certain_damage_rate], [0.25, 0.25, 0.25])
fighter.taken = 0.5
check("a share above the floor stays", fighter.pdr, 0.5)
fighter.taken = 0.0
check("evasion and reflection stop at the ceiling", [fighter.item_eva(nil, attack), fighter.item_mrf(nil, attack)], [0.75, 0.75])
check("an attack on a character that takes none of its element deals the floor", fighter.item_element_rate(nil, attack), 0.25)
fighter.element = -1.0
check("a skill for the own team keeps its rate", fighter.item_element_rate(nil, heal), -1.0)
$wall = "82500.0"
check("a defense wall leaves what the DLL lets through and is used up", [fighter.apply_defense_wall(90_000, attack), fighter.walls, asked.last], [82_500, 0, { "max_hp" => 30_000, "damage" => "90000" }])
check("without a wall the hit stays", fighter.apply_defense_wall(90_000, attack), 90_000)

balance.finish
check("after the battle the stats are the game's again", [fighter.mhp, DamageEvalBattler.new(fighter).mhp, fighter.enemy_calculation?], [7500, 7500, false])
check("after the battle a hit deals what the game works out again", fighter.apply_guard(30_000), 30_000)
check("after the battle a character takes no damage again where the game says so", fighter.mdr, 0.0)
check("starting the balance is logged, and nothing failed", [$log.grep(/pvp balance: on for 2 characters: HP x4, monster formulas/).size, $log.grep(/FAILED|could not/).size], [1, 0])
check("so are each character's changes, the hits it lowers and its end",
      [$log.grep(/pvp balance: \?: max HP 7500 -> 30000/).size, $log.grep(/pvp balance: hit on .* lowered from 30000 -> 10938 of 30000 max HP/).size, $log.grep(/pvp balance: off/).size], [1, 1, 1])
