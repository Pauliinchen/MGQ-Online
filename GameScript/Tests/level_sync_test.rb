#----------------------------------------------------------------
#  level_sync_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Checked that the end syncs nothing more by a character's stats instead of the sync's level
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# Covers battles_coop_level_sync.rbx: the battle's level from the leader's characters in it, the
# stats of a character above it, its equipment lowered by less, its share of HP and MP kept, and
# its own stats back once the battle ends.

require_relative "support"

$log = []
$chat = []
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end
module SceneManager; def self.run; end; end
class Scene_Title; def start; end; end
module MGQ_MpChat; def self.system(text); $chat << text; end; end
module MGQ_MpBattles; def self.kind; $kind; end; end
module BattleManager; def self.process_victory; $victory_mhp = $victor.mhp; end; end

# The co-op battle, as far as the level sync asks it.
module MGQ_MpBattlesCoop
  MOST_CHARACTERS = 14
  Player = Struct.new(:seat, :builds, :places) do
    def lines; places; end
  end
  def self.leads?(seat); seat == $leader_seat; end
end

# Builds as personal levels joined by ",".
module MGQ_MpActors
  module Builds
    Member = Struct.new(:base_level)
    def self.parse(text, count); text.to_s.split(",").first(count).map { |level| Member.new(level.to_i) }; end
  end
end

# The game's character: ten points of each stat per personal level, seeds and equipment on top.
class Game_Actor
  attr_reader :hp, :mp
  def initialize(level, equipment = 200, seeds = 5)
    @level = { :base => level, :class => 1, :tribe => 1 }
    @equipment = equipment
    @seeds = seeds
    @hp = mhp
    @mp = mmp
  end
  def name; "Actor"; end
  def base_level; @level[:base]; end
  def param_base(param_id); @level[:base] * 10 + param_id * 0; end
  def equip_params; [@equipment] * 8; end
  def param_plus(param_id); @seeds + equip_params[param_id]; end
  def param(param_id); (param_base(param_id) + param_plus(param_id)).to_i; end
  def mhp; param(0); end
  def mmp; param(1); end
  def hp=(value); @hp = [[value, 0].max, mhp].min; end
  def mp=(value); @mp = [[value, 0].max, mmp].min; end
end
class Game_MpActor < Game_Actor; end
# A character whose HP cannot be set once $brittle is on.
class Brittle < Game_Actor
  def hp=(value); raise "broken" if $brittle; super; end
end

load_script "battles_coop_level_sync"
SceneManager.run
sync = MGQ_MpCoopLevelSync

# The battle's level.
$leader_seat = 0
leader = MGQ_MpBattlesCoop::Player.new(0, "50,80,12", [[0], [2]])
member = MGQ_MpBattlesCoop::Player.new(2, "90,95", [[0], [1]])
check("the battle's level is the highest of the leader's characters in it", sync.level_for([member, leader]), 50)
$leader_seat = 5
check("without the leader in the battle there is none", sync.level_for([member, leader]), nil)

# Syncing.
$kind = :coop
sync.begin(10)
high = Game_Actor.new(50)
high.hp = 470
high.mp = 705
low = Game_Actor.new(8)
fallen = Game_Actor.new(40)
fallen.hp = 0
ally = Game_MpActor.new(30)
[high, low, fallen, ally].each { |actor| sync.sync(actor) }
check("a character above the level fights with that level's stats and its equipment lowered by half as much",
      [high.param_base(0), high.param_plus(0), high.mhp], [100, 125, 225])
check("its personal level stays its own", high.base_level, 50)
check("its share of HP and MP stays", [high.hp, high.mp], [150, 225])
check("a character at or below the level keeps its stats", [low.mhp, sync.of(low)], [285, nil])
check("a fallen character stays fallen", fallen.hp, 0)
check("a rebuilt character of another player is synced too", ally.mhp, 238)
check("the player is told once, for their own characters", $chat, ["Level Sync: your characters fight at level 10, the party leader's."])
sync.sync(high)
check("syncing a character again changes nothing", [high.mhp, high.hp], [225, 150])

# The end.
sync.finish
check("the end gives the stats back with the share of HP and MP", [high.mhp, high.hp, high.mp], [705, 470, 705])
check("and leaves a fallen character fallen", [fallen.mhp, fallen.hp], [605, 0])
sync.sync(high)
check("and syncs nothing more", [high.mhp, sync.of(high)], [705, nil])

# Other battles.
$kind = :pvp
sync.begin(10)
sync.sync(high)
check("a team duel syncs nobody", high.mhp, 705)
sync.finish
$kind = :coop
sync.begin(nil)
sync.sync(high)
check("a battle without the leader syncs nobody", high.mhp, 705)
sync.begin(10)
sync.sync(high)
Scene_Title.new.start
check("a reset forgets the sync", sync.of(high), nil)
check("starting a sync is logged, and nothing failed", [$log.grep(/level sync: battle at level 10/).size, $log.grep(/FAILED|failed/).size], [3, 0])

# The end of a won battle, and a character that cannot take its stats back.
sync.begin(10)
sync.sync(high)
$victor = high
BattleManager.process_victory
check("a victory gives the stats back before its rewards", [$victory_mhp, sync.of(high)], [705, nil])
brittle = Brittle.new(50)
high.hp = 470
sync.begin(10)
sync.sync(brittle)
sync.sync(high)
$brittle = true
sync.finish
$brittle = false
check("the others get their stats back when one character fails", [high.mhp, high.hp, sync.of(brittle)], [705, 470, nil])
check("and the failure is logged", $log.grep(/giving Actor its stats back failed: RuntimeError: broken/).size, 1)
