#----------------------------------------------------------------
#  pvp_backline_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# Covers battles_pvp_backline.rbx: the option, the other side's characters outside its
# Frontline, the Frontline each game tells the other, what a swap costs the character swapped in,
# and the characters outside both Frontlines in the host's stream.

require_relative "support"

$log = []
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end
module SceneManager
  def self.run; end
  def self.scene; $scene; end
end
class Spriteset; attr_reader :drawn; def dispose_enemies; end; def create_enemies; @drawn = (@drawn || 0) + 1; end; end
class Scene_Battle
  def initialize; @spriteset = Spriteset.new; end
  def bench_member_ok; $game_party.swap(*$swap); end
end
module NWConst
  module Config
    CONTENTS = [{ :key => :first }, { :key => :last }]
    DATA = {}
    DATA_TEXT = {}
    DEFAULT = {}
  end
end
System = Struct.new(:conf)
$game_system = System.new({})

# The game's characters, as far as the Backline follows them.
class Game_Battler
  attr_reader :id, :name, :actions
  def initialize(id, name); @id = id; @name = name; @actions = []; end
  def clear_actions; @actions = []; end
  def inputable?; true; end
  def make_actions; @actions = [:attack]; end
end
class Game_Actor < Game_Battler; end
class Game_Unit; def item_target_members(_item); members; end; end
class Game_Party < Game_Unit
  attr_reader :all_members
  def initialize(members); @all_members = members; end
  def battle_members; @all_members.first(2); end
  def bench_members; @all_members[2..-1] || []; end
  def members; battle_members; end
  def swap(first, second); @all_members[first], @all_members[second] = @all_members[second], @all_members[first]; end
end
class Game_Troop < Game_Unit
  attr_accessor :turn_count
  def initialize; @enemies = []; @turn_count = 0; end
  def members; @enemies; end
end

# Stand-ins for the PvP battle and the live battle.
module MGQ_MpBattles
  module Mode; def stream_kinds; []; end; end
  def self.mode(name, mode); (@modes ||= {})[name] = mode; end
  def self.mode_of(name); @modes[name]; end
end
module MGQ_MpBattlesPvp
  class Opponent < Game_Actor; end
  module Opponents; def self.stand(opponents); $stood = opponents.map(&:id); opponents; end; end
end
module MGQ_MpBattlesSync
  def self.host?; true; end
  module Recorder; def self.active?; true; end; def self.flush; $posted << [:flush]; end; end
  module Channel; def self.post(kind, body); $posted << [kind, body]; end; end
  module Wire
    def self.line(values); Marshal.dump(values); end
    def self.parse(text); Marshal.load(text); end
  end
end
$posted = []

load File.join(SCRIPTS_DIR, "core_log.rbx")
module MGQ_MpBattlesPvp; extend MGQ_MpLog; LOG_TAG = "pvp battle"; end
load_script "battles_pvp_backline"
SceneManager.run
backline = MGQ_MpBattlesPvp::Backline
mode = MGQ_MpBattles.mode_of(:duel)
item = Struct.new(:bench, :only) do
  def include_bench?; bench; end
  def bench_only?; only; end
end

# The option.
config = NWConst::Config
check("the option goes before the options' last entry", config::CONTENTS.map { |entry| entry[:key] }, [:first, backline::OPTION, :last])
check("with the Backline by default", [config::DEFAULT[backline::OPTION], backline.wanted?], [backline::WITH_BACKLINE, true])
$game_system.conf[backline::OPTION] = backline::FRONTLINE_ONLY
check("the player can leave the Backline out", backline.wanted?, false)

own = [Game_Actor.new(1, "Luka"), Game_Actor.new(2, "Alice"), Game_Actor.new(3, "Ilias"), Game_Actor.new(4, "Sonya")]
$game_party = Game_Party.new(own.dup)
$game_troop = Game_Troop.new
others = [5, 6, 7].map { |id| MGQ_MpBattlesPvp::Opponent.new(id, "Friend #{id}") }
$game_troop.instance_variable_set(:@enemies, others.first(2))
$scene = Scene_Battle.new

# Outside a battle with the Backline.
check("outside a battle nothing is swapped in or kept in reserve", [backline.on?, backline.swapped_in?(own[0]), backline.reserve, mode.own_order, mode.stream_kinds], [false, false, [], nil, []])
check("and a skill of the other side reaches the troop alone", backline.troop_targets(item.new(true, false), others.first(2)), others.first(2))

backline.begin(others)
check("the other side's characters past its Frontline wait in reserve", [backline.on?, backline.reserve, backline.own_reserve.map(&:id)], [true, [others[2]], [3, 4]])
check("a skill that reaches the Backline reaches the other side's too", backline.troop_targets(item.new(true, false), $game_troop.members), others)
check("a skill for the Backline alone reaches only it", backline.troop_targets(item.new(false, true), $game_troop.members), [others[2]])
check("any other skill reaches the troop alone", backline.troop_targets(item.new(false, false), $game_troop.members), others.first(2))

# The player's own swap.
own.each(&:make_actions)
check("before a swap everyone commands", [own.map(&:inputable?), mode.own_order], [[true] * 4, [1, 2]])
$swap = [1, 2]
$scene.bench_member_ok
own.each(&:make_actions)
check("the character swapped in gives no commands that round", [own[2].inputable?, own[2].actions, own[0].inputable?, own[0].actions], [false, [], true, [:attack]])
check("the commands carry the new Frontline", mode.own_order, [1, 3])
$scene.bench_member_ok
own.each(&:make_actions)
check("swapped back in the same round, the character commands again", [own[1].inputable?, own[1].actions], [true, [:attack]])
$scene.bench_member_ok
mode.share_order
check("the host tells the guest its Frontline before the turn's events", $posted, [[:flush], [backline::FRONT_MESSAGE, Marshal.dump([[1, 3]])]])
$posted.clear
$game_troop.turn_count = 1
own.each(&:make_actions)
check("in the next round the character commands", [own[2].inputable?, own[2].actions], [true, [:attack]])
mode.share_order
check("a Frontline that did not change is not told again", $posted, [])

# The other side's swap.
others[1].make_actions
others[2].make_actions
mode.take_order(nil, [5, 7])
check("the other side's Frontline is put in the troop and drawn anew", [$game_troop.members.map(&:id), $stood, $scene.instance_variable_get(:@spriteset).drawn, backline.reserve], [[5, 7], [5, 7], 1, [others[1]]])
check("the character swapped in loses the actions it had left", [others[2].actions, others[0].actions], [[], []])
others[2].make_actions
mode.share_order
check("and the commands a guest sent for it", others[2].actions, [])
mode.take(backline::FRONT_MESSAGE, $scene, Marshal.dump([[6, 7]]))
check("a guest takes the host's Frontline from the stream", $game_troop.members.map(&:id), [6, 7])
[[5, 5], [5, 9], [5], "x", nil].each { |front| mode.take_order(nil, front) }
check("a Frontline that does not fit the team is left out", $game_troop.members.map(&:id), [6, 7])
check("the stream carries the Frontline's message", mode.stream_kinds, [backline::FRONT_MESSAGE])

# The characters outside both Frontlines in the stream.
check("the host names its own Backline and the other side's", [mode.reserve_ref(own[1]), mode.reserve_ref(others[0]), mode.reserve_ref(own[0])], ["b2", "r5", nil])
check("the guest finds the host's as the other side's, and its own", [mode.reserve("b5"), mode.reserve("r2"), mode.reserve("a0"), mode.reserve("b99")], [others[0], own[1], nil, nil])
check("both are listed for the names and values", [mode.own_reserve.map(&:id), mode.other_reserve.map(&:id)], [[2, 4], [5]])

backline.finish
check("after the battle nothing is swapped in or kept in reserve", [backline.on?, backline.swapped_in?(own[2]), backline.reserve, mode.own_order, mode.reserve("b5")], [false, false, [], nil, nil])
check("nothing failed", $log.grep(/FAILED|failed/).size, 0)
