#----------------------------------------------------------------
#  balance_pvp_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# Covers mp_balance_pvp.rbx: the skills' formulas for monsters, more HP, an action's damage kept
# below a share of max HP, a lowest share of a hit every character takes, limited evasion, reflection and element rates, and defense
# walls that take a share of a hit, all only while a PvP battle runs with the balance.

require_relative "support"

$log = []
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end
module SceneManager; def self.run; end; end
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

Item = Struct.new(:opponent) do
  def for_opponent?; opponent; end
end
attack = Item.new(true)
heal = Item.new(false)

load_script "mp_balance_pvp"
SceneManager.run
balance = MGQ_MpBalancePvp

fighter = Game_Battler.new([7500, 500, 490], 7500)
fallen = Game_Battler.new([6000, 400, 300], 0)
fighter.evasion = 1.0
fighter.reflection = 1.0
fighter.element = 0.0
fighter.walls = 2

check("outside a PvP battle the stats are the game's", [balance.active?, fighter.mhp, fighter.param(2)], [false, 7500, 490])
check("outside a PvP battle a character's skills use the formulas for players", fighter.enemy_calculation?, false)
check("outside a PvP battle a hit deals what the game works out", fighter.apply_guard(52_000_000_000_000), 52_000_000_000_000)
check("outside a PvP battle evasion, reflection and elements are the game's",
      [fighter.item_eva(nil, attack), fighter.item_mrf(nil, attack), fighter.item_element_rate(nil, attack)], [1.0, 1.0, 0.0])
check("outside a PvP battle a defense wall takes the whole hit", [fighter.apply_defense_wall(90_000, attack), fighter.walls], [0, 1])

balance.begin([fighter, fallen])
check("the balance raises max HP and no other stat", [balance.active?, fighter.mhp, fighter.param(2)], [true, 30_000, 490])
check("a character's skills use the formulas for monsters", fighter.enemy_calculation?, true)
check("the added HP is filled, except for a dead character", [fighter.hp, fallen.hp], [30_000, 0])
check("a damage formula reads max HP as it is without the balance", [DamageEvalBattler.new(fighter).mhp, DamageEvalBattler.new(fighter).atk], [7500, 490])
check("a hit up to the knee deals its damage", fighter.apply_guard(3000).round, 3000)
scene.use_item
check("a hit of the whole max HP takes about a third of it", fighter.apply_guard(30_000).round, 10_937)
scene.use_item
huge = fighter.apply_guard(52_000_000_000_000 * 4)
check("a hit of millions of times the max HP stays below the limit", [huge < 18_000, huge > 16_000], [true, true])
scene.use_item
hits = [fighter.apply_guard(30_000), fighter.apply_guard(30_000), fighter.apply_guard(30_000)]
check("an action's hits on one target count together", [hits[0].round, hits[1] < hits[0] / 4, hits.inject(:+) < 18_000], [10_937, true, true])
check("another target of the same action is counted by itself", fallen.apply_guard(24_000).round, 8750)
scene.use_item
check("the next action counts anew", fighter.apply_guard(30_000).round, 10_937)
check("healing is kept below the limit the same way", fighter.apply_guard(-30_000).round, -10_937)
fighter.taken = 0.0
check("a character that takes no damage at all takes the floor", [fighter.pdr, fighter.mdr, fighter.certain_damage_rate], [0.25, 0.25, 0.25])
fighter.taken = 0.5
check("a share above the floor stays", fighter.pdr, 0.5)
fighter.taken = 0.0
check("evasion and reflection stop at the ceiling", [fighter.item_eva(nil, attack), fighter.item_mrf(nil, attack)], [0.75, 0.75])
fighter.evasion = 0.4
check("evasion below the ceiling stays", fighter.item_eva(nil, attack), 0.4)
check("an attack on a character that takes none of its element deals the floor", fighter.item_element_rate(nil, attack), 0.25)
fighter.element = -1.0
check("an absorbed attack deals the floor too", fighter.item_element_rate(nil, attack), 0.25)
check("a skill for the own team keeps its rate", fighter.item_element_rate(nil, heal), -1.0)
fighter.element = 0.5
check("a rate above the floor stays", fighter.item_element_rate(nil, attack), 0.5)
check("a defense wall takes a share of max HP off a hit and is used up", [fighter.apply_defense_wall(90_000, attack), fighter.walls], [82_500, 0])
check("without a wall the hit stays", fighter.apply_defense_wall(90_000, attack), 90_000)
fighter.walls = 1
check("a hit smaller than the wall's share deals nothing", fighter.apply_defense_wall(7000, attack), 0)

balance.finish
check("after the battle the stats are the game's again", [balance.active?, fighter.mhp, DamageEvalBattler.new(fighter).mhp, fighter.enemy_calculation?], [false, 7500, 7500, false])
check("after the battle a hit deals what the game works out again", fighter.apply_guard(30_000), 30_000)
check("after the battle a character takes no damage again where the game says so", fighter.mdr, 0.0)
check("after the battle evasion and elements are the game's again", [fighter.tap { |f| f.evasion = 1.0 }.item_eva(nil, attack), fighter.tap { |f| f.element = 0.0 }.item_element_rate(nil, attack)], [1.0, 0.0])
check("starting the balance is logged, and nothing failed", [$log.grep(/pvp balance: on for 2 characters/).size, $log.grep(/FAILED|could not/).size], [1, 0])
