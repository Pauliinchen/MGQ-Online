#----------------------------------------------------------------
#  make_turn_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Read the ledger's stand-in from the last commit that kept it, the script tests no longer having one
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Writes the golden cases of a raid boss fight's turns next to this file, turns.json, from
# battles_raid_pool.rbx as it reported and synced its fights before that moved to C# (commit
# e2d9fc67, which this generator reads through git, so it runs again on later commits), with the
# pools of the ledger's stand-in (GameScript/Tests/pool_support.rb as commit 9e078f28 kept it, read
# the same way). A recording tool: no test runs against it. Each scenario opens a fight and
# runs steps on it: the enemies as the battle has them, the player's role, time passing, the DLL
# refusing reports, the relay's word of a pool, and a moment of the battle (its start, a command
# phase, an action's end, the wait for commands, a turn's end, its end, a takeover). Each step
# records the reports sent, the enemies' HP and deaths after it, the enemies killed by an empty
# pool, whether the battle was judged, and the fight's state. MGQOnline.Game.Tests replays them.
#
#   ruby fixtures/pool/make_turn_fixtures.rb

require "json"
require "tempfile"
require_relative "../../GameScript/Tests/bridge_support"

# The commit whose battles_raid_pool.rbx kept the turns.
SOURCE_COMMIT = "e2d9fc67"

# The last commit whose script tests kept the ledger's stand-in.
STAND_IN_COMMIT = "9e078f28"

# Loads the ledger's stand-in of the stand-in commit.
def load_stand_in
  source = `git -C "#{File.expand_path('../..', __dir__)}" show #{STAND_IN_COMMIT}:GameScript/Tests/pool_support.rb`
  raise "git could not read pool_support.rb of #{STAND_IN_COMMIT}" if source.empty?

  stand_in = Tempfile.new(["pool_support", ".rb"])
  stand_in.write(source.sub(/^require_relative "bridge_support"
/, ""))
  stand_in.close
  load stand_in.path
end
load_stand_in

# The log stays quiet; the cases record what the rules did, not their lines.
module MGQ_Multiplayer; module Log; def self.write(_line); end; end; end

# The clock, which stands still unless a step moves it.
$now = Time.at(1_000_000)
# Stands in for the clock: answers $now.
def Time.now; $now; end

# Stands in for the world's sync, which the script registers with as it loads.
module MGQ_MpOverworldSync
  # Takes a block to run each frame.
  def self.on_tick(&_block); end
  # Takes a block of the player's state fields.
  def self.state_fields(&_block); end
end
# Stands in for a Raid World and the ids coop.rbx makes up.
module MGQ_MpCoop
  # The scope of a Raid World.
  module Scope; def self.raid?; true; end; end
  # Makes up an id, the same each time.
  def self.random_id(length, _radix = 36); "1".rjust(length, "0"); end
end
# Stands in for the world's story.
module MGQ_MpWorldStory; def self.active?; true; end; def self.mode; :world; end; def self.world_id; "w1"; end; end
# Stands in for the chat log.
module MGQ_MpChat; def self.system(_text); end; end
# Stands in for the live battle: the player's role in $role, and no wait for commands.
module MGQ_MpBattlesSync
  # Answers the player's role.
  def self.role; $role; end
  # The wait for the players' commands, never open here.
  module Waiting; def self.active?; false; end; end
end
# Stands in for the battle's scene.
class Scene_Battle; end
# Stands in for the scenes, the battle's running.
module SceneManager; def self.run; end; def self.scene; Scene_Battle.new; end; end
# Stands in for the title screen.
class Scene_Title; def start; end; end
# Stands in for the battles: their phase waits for commands, and a judged battle is counted.
module BattleManager
  @phase = :input
  # Counts a judged battle.
  def self.judge_win_loss; $judged += 1; end
  # Sets a battle up.
  def self.setup(*_args); end
end
# Stands in for the map, which the script hooks.
class Game_Map; def update_interpreter; end; end
# Stands in for the interpreter, which the script hooks.
class Game_Interpreter; def command_301; end; end

# An enemy of the battle, with an id of its own that tells a rebuilt one apart.
class Game_Enemy
  # Its HP, max HP and id.
  attr_reader :hp, :mhp, :id
  # Makes an enemy.
  def initialize(hp, mhp, dead, id); @hp, @mhp, @dead, @id = hp, mhp, dead, id; end
  # Sets the HP; 0 kills.
  def hp=(value); @hp = value; @dead = value <= 0; end
  # Whether it is dead.
  def dead?; @dead; end
  # Its name.
  def name; "Boss #{@id}"; end
  # Its name before any change.
  def original_name; name; end
  # Counts a collapse.
  def perform_collapse_effect; $collapsed << @id; end
end
# The battle's troop.
class Game_Troop
  # The enemies.
  attr_accessor :members
  # Whether every enemy is dead.
  def all_dead?; @members.all? { |enemy| enemy.dead? }; end
end

# The DLL: the reports it takes count in the ledger's stand-in at once, as the DLL's do.
module MGQ_Multiplayer
  # Stands in for the DLL link.
  module Link
    # Answers a function of the DLL.
    def self.function(name)
      lambda do |*args|
        args = args.map { |arg| arg.to_s.chomp("\0") }
        next 1 unless name == "mp_raid_boss_report"
        next 0 unless $taking

        $reports << args[1..3]
        _seq, delta, max, killed = args[3].split("\t")
        $pools.enter(args[0])
        $pools.own(args[1], delta.to_f, max.to_f, killed == "1")
        1
      end
    end
  end
end

# Loads a script of the source commit.
#
# @param name [String] The script's name without its extension.
def load_old(name)
  source = `git -C "#{File.expand_path('../..', __dir__)}" show #{SOURCE_COMMIT}:GameScript/Multiplayer/Scripts/#{name}.rbx`
  raise "git could not read #{name}.rbx of #{SOURCE_COMMIT}" if source.empty?

  script = Tempfile.new([name, ".rbx"])
  script.write(source)
  script.close
  %w(core_log core_hooks core_game_access).each { |core| load File.join(SCRIPTS_DIR, "#{core}.rbx") } unless defined?(MGQ_MpGame)
  load_bridge unless defined?(MGQ_Multiplayer::Bridge)
  load script.path
end

load_old("battles_raid_bosses")
load_old("battles_raid_pool")
POOL = MGQ_MpRaidPool
$fake = FakeBridge.new
MGQ_Multiplayer::Bridge.open($fake)
$pools = PoolLedgerStandIn.new($fake) { (Time.now.to_f * 1000).round }
$game_troop = Game_Troop.new

# The moments a step runs, by name.
MOMENTS = {
  "phase" => -> { POOL.command_phase },
  "action" => -> { POOL.action_done },
  "wait" => -> { POOL.waiting_for_commands },
  "turn_end" => -> { POOL.turn_ended },
  "rescale" => -> { POOL.rescale },
  "take_over" => -> { POOL.taken_over },
  "end_won" => -> { POOL.battle_ended(0) },
  "end_lost" => -> { POOL.battle_ended(2) },
}

# Runs one step on the fight.
#
# @param step [Hash] The step: "enemies" ([hp, max HP, dead, id] each, an id not seen before for
#   an enemy built anew), "role" ("guest" or "host"), "ms" (time passing), "taking" (whether the
#   DLL takes reports), "push" ([key, share, max, defeated]) and "moment" (see MOMENTS).
def run(step)
  if (enemies = step["enemies"])
    $game_troop.members = enemies.map do |hp, mhp, dead, id|
      kept = $game_troop.members.to_a.find { |enemy| enemy.id == id }
      enemy = kept || Game_Enemy.new(hp, mhp, dead, id)
      enemy.instance_variable_set(:@hp, hp)
      enemy.instance_variable_set(:@mhp, mhp)
      enemy.instance_variable_set(:@dead, dead)
      enemy
    end
  end
  $role = step["role"] == "guest" ? :guest : nil if step.key?("role")
  $now += step["ms"] / 1000.0 if step["ms"]
  $taking = step["taking"] if step.key?("taking")
  if (push = step["push"])
    key, left, max, defeated = push
    $pools.hear(key, left, max, defeated, "", :pushed)
  end
  POOL.read_state
  MOMENTS.fetch(step["moment"]).call if step["moment"]
end

# Describes the fight as it stands.
#
# @return [Hash, nil] Its number, whether a host governs it, and each member's base, kill, hold
#   and enemy id; nil once it ended.
def fight_state
  fight = POOL.fight
  fight && { "seq" => fight.seq, "guest" => fight.guest ? true : false,
             "members" => fight.members.map { |member| [member.base, member.killed ? true : false, member.held ? true : false, member.enemy && member.enemy.id] } }
end

# Plays a scenario on a fresh fight.
#
# @param name [String] What it shows.
# @param troop [Integer] The troop.
# @param start [Hash] The step that opens the fight: its enemies and the player's role.
# @param steps [Array<Hash>] The steps after, see run.
# @return [Hash] The scenario with what each step did.
def scenario(name, troop, start, steps)
  POOL.forget
  $pools.reset
  $pools.enter("w1")
  $now = Time.at(1_000_000)
  $taking = true
  $role = nil
  $game_troop.members = []
  opened = nil
  played = ([start.merge("moment" => "start")] + steps).map do |step|
    $reports = []
    $collapsed = []
    $judged = 0
    if step["moment"] == "start"
      run(step.merge("moment" => nil))
      POOL.start(troop, $game_troop.members.size, step["role"] == "guest" ? :guest : :event, false)
      opened = { "battle" => POOL.fight.battle, "keys" => POOL.fight.members.map(&:key), "guest" => POOL.fight.guest ? true : false }
    else
      run(step)
    end
    step.merge("reports" => $reports, "after" => $game_troop.members.map { |enemy| [enemy.hp, enemy.dead? ? true : false] },
               "collapsed" => $collapsed, "judged" => $judged, "fight" => fight_state)
  end
  { "name" => name, "open" => opened, "steps" => played }
end

SCENARIOS = [
  scenario("a fight reports what each turn dealt at the command phase and takes its pool's HP", 71,
           { "enemies" => [[6000, 6000, false, 11]], "push" => ["Queen Harpy", 0.5, 6000, false] },
           [{ "moment" => "phase" },
            { "enemies" => [[2400, 6000, false, 11]], "moment" => "phase" },
            { "moment" => "phase" },
            { "enemies" => [[2700, 6000, false, 11]], "moment" => "phase" },
            { "ms" => 60_000, "moment" => "phase" },
            { "push" => ["Queen Harpy", 0.25, 6000, false], "moment" => "phase" },
            { "enemies" => [[0, 6000, true, 11]], "moment" => "end_won" }]),
  scenario("an action reports at most every two seconds", 71,
           { "enemies" => [[6000, 6000, false, 11]] },
           [{ "moment" => "phase" },
            { "enemies" => [[5400, 6000, false, 11]], "moment" => "action" },
            { "enemies" => [[4800, 6000, false, 11]], "ms" => 1000, "moment" => "action" },
            { "ms" => 1000, "moment" => "action" },
            { "enemies" => [[4200, 6000, false, 11]], "ms" => 500, "moment" => "action" }]),
  scenario("the wait for commands takes the pool's HP every five seconds", 71,
           { "enemies" => [[6000, 6000, false, 11]], "push" => ["Queen Harpy", 0.8, 6000, false] },
           [{ "moment" => "phase" },
            { "push" => ["Queen Harpy", 0.5, 6000, false], "ms" => 4000, "moment" => "wait" },
            { "ms" => 1000, "moment" => "wait" },
            { "push" => ["Queen Harpy", 0, 6000, true], "ms" => 2000, "moment" => "wait" },
            { "ms" => 3000, "moment" => "wait" }]),
  scenario("an empty pool kills its enemy at a turn's end, and nothing else changes there", 1599,
           { "enemies" => [[15000, 15000, false, 21], [22500, 22500, false, 22]] },
           [{ "moment" => "phase" },
            { "enemies" => [[7500, 15000, false, 21], [22500, 22500, false, 22]], "push" => ["Metatronne and Sandalphone#1", 0, 22500, true], "moment" => "turn_end" },
            { "moment" => "phase" },
            { "push" => ["Metatronne and Sandalphone#0", 0, 15000, true], "moment" => "phase" }]),
  scenario("a refused report holds the enemy's HP until the next goes with both turns", 71,
           { "enemies" => [[6000, 6000, false, 11]], "push" => ["Queen Harpy", 0.5, 6000, false] },
           [{ "taking" => false, "enemies" => [[2400, 6000, false, 11]], "moment" => "phase" },
            { "push" => ["Queen Harpy", 0.6, 6000, false], "moment" => "phase" },
            { "taking" => true, "enemies" => [[1800, 6000, false, 11]], "moment" => "phase" }]),
  scenario("a guest reports nothing until it takes the battle over, then from its enemies' HP then", 71,
           { "role" => "guest", "enemies" => [[6000, 6000, false, 11]], "push" => ["Queen Harpy", 0.5, 6000, false] },
           [{ "enemies" => [[5000, 6000, false, 11]], "moment" => "phase" },
            { "moment" => "wait" },
            { "moment" => "turn_end" },
            { "role" => "host", "enemies" => [[4000, 6000, false, 11]], "moment" => "take_over" },
            { "enemies" => [[3400, 6000, false, 11]], "moment" => "phase" },
            { "role" => "guest", "moment" => "end_lost" }]),
  scenario("an enemy built anew reports nothing and takes its pool's HP", 71,
           { "enemies" => [[6000, 6000, false, 11]], "push" => ["Queen Harpy", 0.1, 6000, false] },
           [{ "enemies" => [[6000, 6000, false, 12]], "moment" => "phase" },
            { "enemies" => [[300, 6000, false, 12]], "moment" => "phase" },
            { "enemies" => [[6000, 6000, false, 13]], "moment" => "rescale" }]),
  scenario("a max HP lowered under the HP reports nothing, and a raised one counts against the new max", 71,
           { "enemies" => [[6000, 6000, false, 11]], "push" => ["Queen Harpy", 0.75, 6000, false] },
           [{ "moment" => "phase" },
            { "enemies" => [[4500, 3000, false, 11]], "moment" => "phase" },
            { "enemies" => [[1500, 3000, false, 11]], "moment" => "phase" },
            { "enemies" => [[1500, 6000, false, 11]], "moment" => "phase" }]),
  scenario("a pool the relay keeps standing never kills its enemy", 71,
           { "enemies" => [[6000, 6000, false, 11]], "push" => ["Queen Harpy", 0, 18_000_000_000_000, false] },
           [{ "moment" => "phase" }]),
].freeze

File.write(File.join(__dir__, "turns.json"), JSON.pretty_generate("source" => SOURCE_COMMIT, "world" => "w1", "scenarios" => SCENARIOS) + "\n")
puts "wrote turns.json"
