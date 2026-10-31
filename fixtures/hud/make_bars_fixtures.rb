#----------------------------------------------------------------
#  make_bars_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the raid bars next to this file, bars.json, from ui_raid_bar.rbx as it
# worked the bars out before that moved to C# (MGQOnline.Game's Hud/RaidBars): the short numbers,
# the share left in percent, the names lettered as the game letters them, the bar of a battle that
# fights a boss's pools or its tier, and the map's bar of a troop from the pools or at its tier.
# MGQOnline.Game.Tests replays them, the pools from a ledger that holds what they hold here.
#
# It runs on the scripts of commit 3ee61503, the last that kept these rules in ui_raid_bar.rbx,
# through the script tests' stand-ins, the pools' share and HP read out of battles_raid_pool.rbx,
# on Ruby 3.3, from a checkout of that commit:
#
#   ruby fixtures/hud/make_bars_fixtures.rb

require "json"
require_relative "../../GameScript/Tests/world_support"

# A pool as the player's game knows it, told later than the bars look at it, so none gained HP back.
Pool = Struct.new(:left, :max, :defeated, :at) do
  def initialize(left, max, defeated); super(left, max, defeated, Time.now + 3600); end
end

# The raid pools: the fight, the pools by key, the troops' keys, whether the pools apply; the share
# and the HP taken from battles_raid_pool.rbx itself, without any time passed.
module MGQ_MpRaidPool
  Fight = Struct.new(:troop, :members, :own)
  Member = Struct.new(:index, :key)
  UNPOOLED = {}
  @regen = 0.03
  source = File.read(File.join(SCRIPTS_DIR, "battles_raid_pool.rbx"), :encoding => "UTF-8")
  module_eval(source[/^  def self\.left_now.*?^  end\n/m])
  module_eval(source[/^  def self\.hp_of.*?^  end\n/m])
  def self.active?; $active; end
  def self.fight; $fight; end
  def self.pool(key); $pools[key]; end
  def self.troop_keys(_troop); $keys; end
  def self.own_enemies(_own); $game_troop.members; end
end
# The raid bosses: a troop's title and its tier's factor of max HP.
module MGQ_MpRaidBosses
  def self.title(troop); "Boss #{troop}"; end
  def self.factor(_troop, _stat); $factor; end
end
# The raid bosses at their tier outside Raid Worlds.
module MGQ_MpRaidTiers; def self.fight; $tier_fight; end; end

load_script "ui_raid_bar"
BARS = MGQ_MpRaidBar

# An enemy in battle.
Enemy = Struct.new(:name, :hp, :mhp, :dead) { def dead?; dead; end }
# The battle's troop, its letters as the game's troop has them.
Troop = Struct.new(:members, :letter_table)
# A troop of the database and a member of it.
TroopData = Struct.new(:members)
TroopMember = Struct.new(:enemy_id)
# An enemy of the database.
EnemyData = Struct.new(:name, :params)
# An enemy as the game makes it, its max HP at the difficulty from $own_hp.
class Game_Enemy; def initialize(_index, id); @id = id; end; def mhp; $own_hp[@id]; end; end

$game_variables = Hash.new(0)
$data_enemies = [nil, EnemyData.new("Metatronne", [1]), EnemyData.new("Imp", [1]), EnemyData.new("Seraph", [1])]
$own_hp = { 1 => 123_457, 2 => 900, 3 => 40_000 }

# Writes a bar as the cases record it.
#
# @param bar [MGQ_MpRaidBar::Bar, nil] The bar.
# @return [Array, nil] Its title and gauges.
def bar_of(bar)
  bar && [bar.title, bar.gauges.map { |gauge| [gauge.name, gauge.hp, gauge.max] }]
end

numbers = [[0, 0], [1, 1], [999, 1000], [1_234_567, 9_999_999], [0, 10_000_000], [1, 10_000_000_000], [9_999_999_999, 10_000_000_000],
           [10_000_001_000, 10_000_000_000], [236_167_000_000_123, 1_009_500_000_000_000], [5 * 10**17, 10**18], [1, 9 * 10**18]]
           .map { |hp, max| [hp, max, BARS.short_numbers(hp, max)] }

strip = Sprite_MpRaidBar.allocate
percents = [[0, 100], [1, 10_000], [1, 1000], [9995, 10_000], [99_950, 100_000], [99_949, 100_000], [2, 3], [125, 1000], [1225, 10_000],
            [7, 8], [1, 16], [3, 16], [5, 16], [150, 100], [5, 0]]
           .map { |hp, max| [hp, max, strip.percent(MGQ_MpRaidBar::Gauge.new("", hp, max))] }

$game_troop = Troop.new([], nil)
names = [[%w[Metatronne Metatronne Imp], nil], [%w[Imp Imp Imp Seraph], [" A", " B"]], [%w[Seraph], []]].map do |list, letters|
  $game_troop = Troop.new([], letters)
  [list, letters, BARS.map_names(list.map { |name| $data_enemies.index { |enemy| enemy && enemy.name == name } })]
end

# The battles: the pools' fight with its members and pools, or a tier's fight.
battles = []
$game_troop = Troop.new([Enemy.new("Metatronne A", 61_000, 123_457, false), Enemy.new("Metatronne B", 0, 123_457, true),
                         Enemy.new("Imp", 450, 900, false), Enemy.new("Ghost", 5, 0, false)], nil)
$fight = MGQ_MpRaidPool::Fight.new(77, [MGQ_MpRaidPool::Member.new(0, "77:1"), MGQ_MpRaidPool::Member.new(1, "77:2"),
                                        MGQ_MpRaidPool::Member.new(2, "77:3"), MGQ_MpRaidPool::Member.new(3, "77:4"),
                                        MGQ_MpRaidPool::Member.new(9, "77:9")], nil)
$pools = { "77:1" => Pool.new(0.5, 6_172_850, false), "77:2" => Pool.new(0.0, 6_172_850, true), "77:3" => Pool.new(0.3, 0, false) }
battles << { "kind" => "pools", "title" => "Boss 77", "enemies" => $game_troop.members.each_with_index.map { |enemy, index| [enemy.name, enemy.hp, enemy.mhp, enemy.dead, $fight.members[index].key] },
             "pools" => $pools.map { |key, pool| [key, pool.left, pool.max, pool.defeated] }, "bar" => bar_of(BARS.battle_bar) }
$fight = MGQ_MpRaidPool::Fight.new(78, [MGQ_MpRaidPool::Member.new(3, "78:1")], nil)
battles << { "kind" => "pools", "title" => "Boss 78", "enemies" => [["Ghost", 5, 0, false, "78:1"]], "pools" => [], "bar" => bar_of(BARS.battle_bar) }
$fight = nil
$tier_fight = MGQ_MpRaidPool::Fight.new(79, [], [])
BARS.instance_variable_set(:@shown, { :battle => true })
battles << { "kind" => "tier", "title" => "Boss 79", "enemies" => $game_troop.members.map { |enemy| [enemy.name, enemy.hp, enemy.mhp, enemy.dead, nil] },
             "pools" => [], "bar" => bar_of(BARS.battle_bar) }

# The map's bars: from the pools of a Raid World, or at the tier outside it.
maps = []
$data_troops = [nil] * 90
$data_troops[80] = TroopData.new([TroopMember.new(1), TroopMember.new(1), TroopMember.new(2)])
$factor = 50
$game_troop = Troop.new([], nil)
$active = true
$keys = ["80:1", "80:2", "80:3", "80:4"]
$pools = { "80:1" => Pool.new(0.5, 6_172_850, false), "80:2" => Pool.new(0.25, 0, false), "80:3" => Pool.new(0.9, 0, true) }
maps << { "kind" => "pools", "troop" => 80, "keys" => $keys, "factor" => $factor, "letters" => nil, "pools" => $pools.map { |key, pool| [key, pool.left, pool.max, pool.defeated] },
          "bar" => bar_of(BARS.map_bar(80)) }
$active = false
$factor = 1
maps << { "kind" => "tier", "troop" => 80, "keys" => [], "factor" => $factor, "letters" => nil, "pools" => [], "bar" => bar_of(BARS.map_bar(80)) }

File.write(File.join(__dir__, "bars.json"), JSON.pretty_generate({ "numbers" => numbers, "percents" => percents, "names" => names,
                                                                  "own_hp" => $own_hp.map { |id, hp| [$data_enemies[id].name, hp] },
                                                                  "battles" => battles, "maps" => maps }) + "\n")
puts "wrote #{numbers.size} numbers, #{percents.size} shares, #{battles.size} battles and #{maps.size} map bars"
