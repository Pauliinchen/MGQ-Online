#----------------------------------------------------------------
#  raid_pool_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the pools and the fight with fixed values per case and checked what the script hands C# and does with its answers
#                            - Answered the raid bosses' rules with fixed values per case and dropped the checks of the tables, markers and refusals, which the DLL keeps
#                            - Told the boss battle, the rates and the invite's pool as values
#                            - Stood in for the DLL's fetch of the pools through its topic
#                            - Checked that a boss takes its pool's HP once the game's own events before the battle ran
#                            - Started a battle's events and start skills as the game's battle scene does
#                            - Checked that a boss whose pool is below a phase's share switches phase before anyone acts
#                            - Moved the scripts' clock with the world's frames and the seconds a test lets pass
#      Paulinchen  2026-10-30: Ran the fights' turns through the stand-in of the fight in C#
#                            - Told the pools through the stand-in of the pools' ledger in C#, which counts the own reports
#                            - Checked that the stats' factors are kept per battle
#      Paulinchen  2026-10-23: Stood in for the ids coop.rbx makes up
#                            - Dropped the check of the removed retrying?
#                            - Checked that a refight of a boss the story beat is won at once
#                            - Checked that a boss built anew at full HP heals no pool
#      Paulinchen  2026-10-20: Checked that a max HP lowered under the boss's HP heals no pool
#      Paulinchen  2026-10-17: Checked in_map?, retrying? and set_up_kind, and the rewards of a resumed frozen fight
#      Paulinchen  2026-10-15: Checked the pools a starter hands the battle server and the server fights
#      Paulinchen  2026-10-12: Checked the level caps of the milestones a story beat
#                            - Checked a pool emptied while a live battle's host waits for commands
#      Paulinchen  2026-10-11: Checked a boss outside the Level Cap milestones and the Vampire Castle's Carmilla and Elizabeth
#                            - Checked that a side battle's defeat is the game's
#                            - Covered the pool readers of the World overview
#      Paulinchen  2026-10-10: Checked that the keys of the Three Nobles of Black carry their caps
#                            - Covered takeovers the co-op battles tell as they happen
#                            - Covered guest takeovers and guests that never kill the boss alone
#                            - Covered changing boss max HP, small changes of the DLL's line and the Hades rematch hall
#                            - Covered the side battles' rewards, troop pages and guests, and side_battle?
#                            - Covered the pools' HP while a battle waits for commands
#                            - Covered the bosses' titles
#                            - Covered the reports at the end of a battle's actions
#                            - Covered the boss tiers and their factors
#                            - Covered the one-time Chaos Domain bosses
#                            - Covered the shared fight against a raid boss's pools
#      Paulinchen  2026-10-09: Covered the share of a kill and the boss's name counting only the troop's own enemies
#                            - Covered boss fights whose events change the party
#                            - Covered companions joining after the battle, personas put back and items given again
#                            - Created
#
#----------------------------------------------------------------

# Covers battles_raid_pool.rbx with battles_raid_bosses.rbx: what the DLL's rules hear of a battle
# and how the kind they answer fights a raid boss's pools and with what max HP, what each moment of
# the battle hands C# and how the enemies take the HP it hands back, bosses of several enemies,
# guests and takeovers, the game's retry, the side battles, the invite's and the state's fields, the
# defeats told and fetching the pools. The rules, the pools and the fight answer fixed values per
# case (raid_support.rb), whose rules the C# tests cover; events run in fibers as the game's
# interpreter runs them.

require_relative "bridge_support"

# Stands in for the mod's base script, whose log prints each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$chat = []
$notices = []
$ticks = []
$state_fields = []
$ran = []
$raid = true
$mode = :world
$role = nil
$borrowed = []
$given_back = 0
$collapsed = []
$won = []
$called = []

$now = Time.at(1_000_000)
# Stands in for the clock: answers $now, which stands still unless a test moves it, so the pools
# regain nothing meanwhile.
def Time.now; $now; end
# The scripts' clock, the bridge's frame: the frames the world ran (see ticks) and the seconds the
# test let pass.
$ticked = 0
clock_from { $ticked + (($now - Time.at(1_000_000)) * MGQ_Multiplayer::Bridge::FRAMES_PER_SECOND).round }

# Stands in for the world's sync, keeping its frame blocks in $ticks and the state's blocks in
# $state_fields.
module MGQ_MpOverworldSync
  # Keeps a block to run each frame in $ticks.
  def self.on_tick(&block); $ticks << block; end
  # Keeps a block of the player's state fields in $state_fields.
  def self.state_fields(&block); $state_fields << block; end
end
# Stands in for coop.rbx: its scope, in a Raid World while $raid is set, and the ids it makes up.
module MGQ_MpCoop
  module Scope; def self.raid?; $raid; end; end
  # Makes up an id as the DLL does, its digits counted up.
  def self.random_id(length, radix = 36); ($ids = $ids.to_i + 1).to_s(radix).rjust(length, "0"); end
end
# Stands in for the story of world w1, active while $raid is set.
module MGQ_MpWorldStory
  # Answers whether the world's story is active: $raid.
  def self.active?; $raid; end
  # Answers how the player plays the world's story: $mode, :world while they play it.
  def self.mode; $mode; end
  # Answers the world's id.
  def self.world_id; "w1"; end
end
# Stands in for the chat log, noting its system lines in $chat.
module MGQ_MpChat; def self.system(text); $chat << text; end; end
# Stands in for the notification box, noting its messages in $notices.
module MGQ_MpNotices; def self.message(_key, text, _frames); $notices << text; end; end
# Stands in for the live battle, the player's role in it in $role.
module MGQ_MpBattlesSync
  # Answers the player's role in the live battle: $role.
  def self.role; $role; end
  # Stands in for the host's wait for the other players' commands, waiting while $waiting is set.
  module Waiting; def self.active?; $waiting; end; end
end
# Stands in for the co-op battles' enemy rates, noting those borrowed in $borrowed and counting
# those given back in $given_back.
module MGQ_MpBattlesCoop
  # Answers the player's enemy rates.
  def self.rates; [100, 100, 0]; end
  # Notes the host's rates borrowed in $borrowed.
  def self.borrow_rates(message); $borrowed << message["rates"]; end
  # Counts the rates given back in $given_back.
  def self.give_back_rates; $given_back += 1; end
end

# The game's switches, as the game keeps them.
class Game_Switches
  # Makes the switches, all off.
  def initialize; @data = []; end
  # Answers a switch, off unless set.
  def [](id); @data[id] || false; end
  # Sets a switch.
  def []=(id, value); @data[id] = value; end
end
# The game's variables, as the game keeps them.
class Game_Variables
  # Makes the variables, all 0.
  def initialize; @data = []; end
  # Answers a variable, 0 unless set.
  def [](id); @data[id] || 0; end
  # Sets a variable.
  def []=(id, value); @data[id] = value; end
end

# The save's system object, where scripts keep notes of their own.
class Game_System; end

# An enemy of the database, its max HP first in its params.
EnemyData = Struct.new(:name, :params)
# An enemy of a troop of the database.
TroopMember = Struct.new(:enemy_id)
# A troop of the database, with its battle event pages.
TroopData = Struct.new(:members, :pages)
$data_enemies = []
{ 1 => ["Queen Harpy", 800], 2 => ["Alma Elma", 1000], 3 => ["Granberia", 1000], 4 => ["Metatronne", 2000], 5 => ["Sandalphone", 3000],
  6 => ["Slime", 100], 7 => ["Eden", 1000], 8 => ["EX-Kyubi", 500] }.each { |id, (name, hp)| $data_enemies[id] = EnemyData.new(name, [hp]) }
$data_troops = []
{ 71 => [1], 609 => [2], 610 => [3], 1599 => [4, 5, 99], 31 => [6], 1507 => [7], 2017 => [8], 3127 => [7] }.each do |id, enemies|
  $data_troops[id] = TroopData.new(enemies.map { |enemy| TroopMember.new(enemy) }, [])
end
$data_troops[71].pages = [:harpy_taunts]
$pages_run = []

# An enemy, whose HP the game keeps between 0 and its max and which dies at 0.
class Game_Enemy
  attr_reader :hp
  # Makes an enemy of the database with all its HP.
  def initialize(_index, enemy_id); @enemy_id = enemy_id; @dead = false; @hp = mhp; end
  # Answers the enemy's name in the database.
  def name; $data_enemies[@enemy_id].name; end
  # Answers the enemy's name before any change.
  def original_name; name; end
  # Answers the enemy's max HP in the database.
  def mhp; $data_enemies[@enemy_id].params[0]; end
  # Sets the HP, kept between 0 and the max, and kills the enemy at 0.
  def hp=(value); @hp = [[value, mhp].min, 0].max; @dead = @hp == 0; end
  # Answers whether the enemy is dead.
  def dead?; @dead; end
  # Notes the enemy's fall in $collapsed.
  def perform_collapse_effect; $collapsed << name; end
end
# The battle's troop, made from the database's troop, or a Slime for a troop it lacks.
class Game_Troop
  attr_reader :members
  # Makes the troop's enemies, leaving out those the database lacks.
  #
  # @param troop_id [Integer] The troop.
  def setup(troop_id)
    @troop_id = troop_id
    data = $data_troops[troop_id] || TroopData.new([TroopMember.new(6)], [])
    @members = data.members.select { |member| $data_enemies[member.enemy_id] }.each_with_index.map { |member, index| Game_Enemy.new(index, member.enemy_id) }
  end
  # Answers the troop of the database.
  def troop; $data_troops[@troop_id]; end
  # Runs the troop's battle event pages the battle meets the conditions of, each once a battle as
  # the game's span "battle" does, noting each in $pages_run: a page [name, share] once the first
  # enemy's HP is at most that share of its max, any other at once.
  def setup_battle_event(_timing = nil)
    return unless troop

    @ran = [] unless @ran && @ran_of == @troop_id
    @ran_of = @troop_id
    troop.pages.each do |page|
      next if @ran.include?(page) || (page.is_a?(Array) && @members.first.hp > @members.first.mhp * page[1])

      @ran << page
      $pages_run << page
    end
  end
  # Answers whether every enemy is dead.
  def all_dead?; @members.all? { |enemy| enemy.dead? }; end
end
# The player's party, as far as it is in a battle.
class Game_Party; attr_accessor :in_battle; end

# The battle's start and end as the game's are: the event's battle command sets up a battle and
# hands its result back through event_proc, the retry sets the lost battle up again, and a troop
# whose enemies are all dead wins.
module BattleManager
  # Sets a battle up, noting it in $setups and, while $side_at_setup is a list, whether it is a
  # side battle as it is set up.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the player may escape.
  # @param can_lose [Boolean] Whether the event goes on after a defeat.
  def self.setup(troop_id, can_escape = true, can_lose = false)
    $side_at_setup << MGQ_MpRaidPool.side_battle?(troop_id) if $side_at_setup
    $game_troop.setup(troop_id)
    @troop_id = troop_id
    $setups << [troop_id, can_escape, can_lose]
  end
  # Answers whether the victory gives EXP: yes, as the game's does.
  def self.enable_get_exp?; true; end
  # Answers whether the victory gives gold: yes, as the game's does.
  def self.enable_get_gold?; true; end
  # Answers whether the victory gives drops: yes, as the game's does.
  def self.enable_get_drop?; true; end
  # Takes the handler the battle's result goes to.
  def self.event_proc=(proc); @event_proc = proc; end
  # Ends the battle, handing its result to the event.
  def self.battle_end(result); @event_proc.call(result) if @event_proc; @event_proc = nil; $game_party.in_battle = false; end
  # Sets the lost battle up again, and starts it as the game's battle scene does.
  def self.retry_battle; setup(@troop_id); start_battle; $game_party.in_battle = true; true; end
  # Runs the skills of the battle's start, $start_skills, which the game runs once the events
  # before the battle ran.
  def self.set_battle_start_skill; $start_skills.call if $start_skills; end
  # Starts the battle as the game's battle scene does: its events, $battle_start_events, then its
  # start skills.
  def self.start_battle; $battle_start_events.call if $battle_start_events; set_battle_start_skill; end
  # Wins the battle once its troop is all dead, noting the troop in $won.
  #
  # @return [Boolean] Whether it won.
  def self.judge_win_loss
    return false unless $game_troop.all_dead?
    $won << @troop_id
    battle_end(0)
    true
  end
end
# The battle's scene, whose command phases, turn ends, actions and frames the pools hook into.
class Scene_Battle
  # Answers whether the scene changes: never.
  def scene_changing?; false; end
  # Opens a command phase, noting the enemies' HP in $phases.
  def start_party_command_selection; $phases << $game_troop.members.map(&:hp); end
  # Ends the turn, running $turn_end for damage dealt then.
  def turn_end; $turn_end.call if $turn_end; end
  # Stands in for running an action, doing nothing.
  def process_action; end
  # Stands in for a frame of the battle, doing nothing.
  def update_basic; end
  # Checks the troop's pages as the game does between its events and its actions.
  def process_event; $game_troop.setup_battle_event; end
end
# Stands in for the game's scenes, the running one in $scene and those called in $called.
module SceneManager
  # Stands in for starting the game, doing nothing.
  def self.run; end
  # Answers the running scene: $scene.
  def self.scene; $scene; end
  # Notes the scene called in $called, a battle scene starting its battle as the game's does.
  def self.call(klass); $called << klass; BattleManager.start_battle if klass == Scene_Battle; end
end
# Stands in for the title screen.
class Scene_Title; def start; end; end

# The map, whose interpreter runs as the game's does.
class Game_Map
  attr_accessor :map_id
  attr_reader :interpreter
  # Makes map 5 with its interpreter.
  def initialize; @map_id = 5; @interpreter = Game_Interpreter.new; end
  # Runs a frame of the map, its interpreter only in the main update.
  def update(main = false); update_interpreter if main; end
  # Runs the interpreter and forgets a map event once it ended.
  def update_interpreter
    @interpreter.update
    @interpreter.clear if !@interpreter.running? && @interpreter.event_id > 0
  end
end

# The interpreter, with commands of the tests' own: [:sw, id, value], [:var, id, value],
# [:battle, troop], [:call, list] for a common event and [:mark, label].
class Game_Interpreter
  attr_reader :map_id, :event_id
  # Makes an interpreter.
  #
  # @param depth [Integer] How deep in common event calls it runs.
  def initialize(depth = 0); @depth = depth; clear; end
  # Forgets the event.
  def clear; @map_id = 0; @event_id = 0; @list = nil; @index = 0; @fiber = nil; end
  # Starts an event on the map in a fiber of its own.
  #
  # @param list [Array] Its commands.
  # @param event_id [Integer] The event, 0 for a common event.
  def setup(list, event_id = 0); clear; @map_id = $game_map.map_id; @event_id = event_id; @list = list; @fiber = Fiber.new { run } if @list; end
  # Runs the commands to the end, then waits a frame before it ends.
  def run
    while @list[@index]
      execute_command
      @index += 1
    end
    Fiber.yield
    @fiber = nil
  end
  # Answers whether an event runs.
  def running?; !@fiber.nil?; end
  # Runs the event on to its next wait.
  def update; @fiber.resume if @fiber; end
  # Runs the command at the event's place.
  def execute_command
    kind, a, b = @list[@index]
    case kind
    when :sw then $game_switches[a] = b
    when :var then $game_variables[a] = b
    when :battle then @params = [0, a, false, false]; command_301
    when :call then child = Game_Interpreter.new(@depth + 1); child.setup(a, @event_id); child.run
    when :mark then $ran << a
    end
  end
  # Starts the battle of a battle command and waits for it, as the game's command 301 does.
  def command_301
    return if $game_party.in_battle

    BattleManager.setup(@params[1], @params[2], @params[3])
    BattleManager.start_battle
    BattleManager.event_proc = Proc.new { |n| $branch = n }
    $game_party.in_battle = true
    Fiber.yield
  end
end

load_script "battles_raid_bosses"
load_script "battles_raid_pool"
require_relative "raid_support"

# The DLL's raid bosses' rules, pools and fight behind the bridge, answering fixed values per case.
$fake = FakeBridge.new
answer_raid_rules($fake)
answer_raid_pools($fake)
MGQ_Multiplayer::Bridge.open($fake)
# What the rules answer of a Queen Harpy battle that fights her pool, an event's unless a case
# answers otherwise.
HARPY = { "kind" => "event", "keys" => ["Queen Harpy"], "tier" => 9, "defeated" => false, "milestone" => "Queen Harpy" }
# The battles below count on 7.5 times the max HP in every tier.
MGQ_MpRaidBosses.tiers.keys.each { |tier| MGQ_MpRaidBosses.tiers[tier] = { :mhp => 7.5 } }

pool = MGQ_MpRaidPool
answers = $pool_answers
SceneManager.run

# Starts the game's objects anew and forgets every battle and pool.
def reset
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_troop = Game_Troop.new
  $game_party = Game_Party.new
  $game_map = Game_Map.new
  $game_system = Game_System.new
  $scene = Scene_Battle.new
  MGQ_MpRaidPool.forget
  [$chat, $notices, $ran, $borrowed, $collapsed, $won, $called, $pages_run].each(&:clear)
  $side_at_setup = nil
  $setups = []
  $phases = []
  $given_back = 0
  $raid = true
  $mode = :world
  $role = nil
  $turn_end = nil
  $raid_answers.clear
  $pool_answers.clear
  harpy({})
  $raid_answers.troops[71] = { "pooled" => true, "keys" => ["Queen Harpy"] }
end

# Sets what the rules answer of a Queen Harpy battle, HARPY's fields kept unless named.
#
# @param fields [Hash] The fields that differ.
def harpy(fields)
  $raid_answers.pool_kinds[71] = HARPY.merge(fields)
end

# Runs frames of the map, as Scene_Map does.
#
# @param count [Integer] How many.
def frames(count = 1)
  count.times { $game_map.update(true) }
end

# Starts a map event and runs it up to its battle.
#
# @param list [Array] Its commands.
# @param event_id [Integer] The event, 0 for a common event.
def start(list, event_id = 7)
  $game_map.interpreter.setup(list, event_id)
  frames
end

# Finds the enemy of the battle at a place in its troop.
#
# @param index [Integer] The place.
# @return [Game_Enemy] The enemy.
def enemy(index = 0)
  $game_troop.members[index]
end

# Ends the turn and opens the next command phase, as the battle's scene does.
def next_turn
  $scene.turn_end
  $scene.start_party_command_selection
end

# Has the DLL tell a pool, which the scripts read at once.
#
# @param key [String] The pool's key.
# @param left [String] The share of its max left.
# @param max [Integer] Its max HP.
# @param defeated [Boolean] Whether it is empty for good.
def told(key, left, max = 6000, defeated = false)
  $pool_answers.pool(key, left, max, defeated, defeated ? "Someone" : "")
  MGQ_MpRaidPool.read_state
end

# Lets some seconds pass.
#
# @param seconds [Numeric] The seconds.
def pass(seconds)
  $now += seconds
end

# Runs the frames of the world in which the pools are read, see MGQ_MpRaidPool.tick.
#
# @param count [Integer] How many.
def ticks(count = MGQ_MpRaidPool::STATE_FRAMES)
  count.times do
    $ticked += 1
    $ticks.each { |tick| tick.call(true) }
  end
end

# Lists the fetches of the pools the scripts started.
#
# @return [Array<String>] Each fetch's world.
def fetches
  $pool_answers.asked("raid.pools.fetch")
end

# A one-time boss outside the story fights a pool of its own under its name.
reset
$raid_answers.pool_kinds[3127] = { "kind" => "event", "keys" => ["Void Image of Paradise"], "tier" => 1 }
start([[:battle, 3127], [:mark, :after]])
check("its event battle fights that pool with 7.5 times the max HP", [pool.fight && pool.fight.key, enemy.mhp], ["Void Image of Paradise", 7500])

# A story boss's last phase fights its pool with its tier's factor of the max HP.
reset
start([[:var, 1001, 40], [:battle, 71], [:mark, :after]])
fight = pool.fight
check("a story boss's last phase fights its pool, even after the event moved the story", [$game_party.in_battle, fight && fight.key, fight && fight.own], [true, "Queen Harpy", 1])
check("its enemy has 7.5 times its max HP, all of it", [enemy.mhp, enemy.hp], [6000, 6000])
check("the battle opens in C# with the world, its id, its pools and who reports",
      answers.asked("raid.fight.open"), [{ "world" => "w1", "battle" => fight.battle, "keys" => ["Queen Harpy"], "own" => 1, "guest" => false, "side" => false }])
check("its id is one the relay takes", fight.battle =~ /\A[a-z0-9]{3,64}\z/ ? true : false, true)

# A tier's stat factors are the battle's.
bosses = MGQ_MpRaidBosses
kept = bosses.tiers[9]
bosses.tiers[9] = kept.merge(:atk => 2)
check("the factors are the battle's: a tier changed meanwhile counts from the next battle on", pool::Stats.stat(enemy, :atk, 101), 101)
pool::Stats.forget
pool.scale_enemies(fight)
check("another stat a tier names takes its factor after the game computed it", [pool::Stats.stat(enemy, :atk, 101), pool::Stats.stat(Game_Enemy.new(0, 6), :atk, 101)], [202, 101])
check("and the max HP its own", pool::Stats.stat(enemy, :mhp, 800), 6000)
bosses.tiers[9] = kept

# Each moment of the battle hands C# the own enemies, and the enemies take the HP it hands back.
enemy.hp = 4500
answers.turn = { "actions" => [[0, 3000]] }
next_turn
check("the turn's end and the next command phase hand C# each own enemy's place, HP, max HP and death, as the battle's reporter",
      answers.asked("raid.fight.turn").last(2).map { |request| [request["moment"], request["reporter"], request["enemies"].map { |each| each[0, 4] }] },
      [["turn_end", true, [[0, 4500, 6000, false]]], ["phase", true, [[0, 3000, 6000, false]]]])
check("the enemy takes the HP C# hands back", enemy.hp, 3000)

# An empty pool kills its enemy with its collapse, and the battle wins.
answers.turn = lambda { |request| request["moment"] == "phase" ? { "actions" => [[0, 0]], "killed" => true } : {} }
$scene.start_party_command_selection
check("an enemy whose pool C# tells empty falls at the command phase, and the battle wins", [enemy.dead?, $collapsed, $won], [true, ["Queen Harpy"], [71]])
check("the battle's end goes to C# and closes the fight", [answers.moments.last, pool.fight], ["end", nil])
frames
check("the event goes on at once", [$ran, $branch], [[:after], 0])

# The relay's word of a pool's defeat tells the chat log and the notification box once.
reset
told("Queen Harpy", "0", 6000, true)
answers.push("Queen Harpy", true)
check("the push that empties the pool tells the chat log and the notification box", [$chat.last, $notices.last], ["Queen Harpy is defeated for the whole world."] * 2)
answers.push("Queen Harpy", true)
check("only once", $chat.size, 1)

# A boss the battle kills: its end goes to C# and the story goes on without waiting.
reset
start([[:battle, 71], [:mark, :after]])
enemy.hp = 0
BattleManager.battle_end(0)
check("the battle's last blow goes to C# as it ends", [answers.moments.last, answers.asked("raid.fight.turn").last["enemies"][0][1, 3]], ["end", [0, 6000, true]])
frames
check("the event runs on at once", $ran, [:after])

# A battle against pools the rules call empty is won already.
reset
harpy("defeated" => true)
$game_map.interpreter.instance_variable_set(:@event_id, 7)
pool.in_map { pool.at_command { check("a battle about to fight pools the rules call empty is won already", pool.won_already?(71), true) } }
start([[:battle, 71], [:mark, :after]])
check("its battle tells the player it is won at once", $notices.last, "The world already beat Queen Harpy. This battle is won at once.")

# The rules hear of the battle and the story values they read, and a battle they give no kind
# fights no pool, the log saying why.
reset
$mode = :own
$game_map.map_id = 576
$game_switches[97] = true
$game_variables[1011] = 4
harpy("kind" => nil, "why" => "the rules refuse it")
lines = logged_lines { start([[:battle, 71], [:mark, :after]]) }
asked = $raid_answers.asked("raid.kind").first
check("the rules hear of an event's battle, the player's place in the world's story and the values they read",
      asked.values_at("troop", "mode", "active", "at_command", "in_map", "event", "facts"),
      [71, "pools", false, true, true, true, { "map" => 576, "s" => [false, true], "v" => [0, 4] }])
check("a battle the rules give no kind fights no pool, its enemy keeps its max HP, and the log says why",
      [pool.fight, enemy.mhp, lines.include?("raid pool: troop 71 fights no pool: the rules refuse it")], [nil, 800, true])
$scene.turn_end
BattleManager.battle_end(0)
frames
check("and hands C# nothing", [answers.moments, $ran], [[], [:after]])
reset
start([[:battle, 71], [:mark, :after]], 0)
common = $raid_answers.asked("raid.kind").first.values_at("at_command", "in_map", "event")
reset
BattleManager.setup(71)
check("a common event of its own, and a battle no event command started, are told as such",
      [common, $raid_answers.asked("raid.kind").first.values_at("at_command", "in_map", "event")], [[true, true, false], [false, false, false]])
reset
start([[:call, [[:battle, 71]]], [:mark, :after]])
check("a boss battle in a common event the event calls is the event's",
      [$raid_answers.asked("raid.kind").first["event"], pool.fight && pool.fight.key], [true, "Queen Harpy"])

# A refight of a boss the world's story beat already fights no pool and is won at once, as against
# empty pools (issue #57).
reset
harpy("kind" => nil, "won" => true)
$game_map.interpreter.instance_variable_set(:@event_id, 7)
pool.in_map { pool.at_command { check("a refight of a boss the story beat is won already, so it invites nobody", pool.won_already?(71), true) } }
start([[:battle, 71], [:mark, :after]])
check("it fights no pool, its boss starts dead", [pool.fight, enemy.dead?], [nil, true])
$scene.start_party_command_selection
check("and its first command phase wins it", $won, [71])
frames
check("the event goes on", $ran, [:after])

# A boss of several enemies has a pool per enemy, and falls once every one is empty.
reset
nobles = ["Metatronne and Sandalphone#0", "Metatronne and Sandalphone#1"]
$raid_answers.pool_kinds[1599] = { "kind" => "event", "keys" => nobles, "tier" => 4 }
$raid_answers.troops[1599] = { "keys" => nobles }
start([[:battle, 1599], [:mark, :after]])
fight = pool.fight
check("a pool per own enemy of the troop, the troop's other enemies left out", [fight.members.map(&:key), answers.asked("raid.fight.open").last["keys"]], [nobles, nobles])
check("each with 7.5 times its own max HP", [enemy(0).mhp, enemy(1).mhp], [15000, 22500])
told(nobles[1], "0", 22500, true)
answers.push(nobles[1], true)
check("one enemy's empty pool is no defeat of the boss yet", $chat, [])
answers.turn = { "actions" => [[1, 0]], "killed" => true }
$scene.start_party_command_selection
check("it kills only that enemy, so the battle goes on", [enemy(0).dead?, enemy(1).dead?, $won], [false, true, []])
told(nobles[0], "0", 15000, true)
answers.push(nobles[0], true)
check("once every enemy's pool is empty, the boss is defeated", $chat, ["Metatronne and Sandalphone is defeated for the whole world."])
told(nobles[0], "1", 15000)
answers.push(nobles[0], false)
told(nobles[0], "0", 15000, true)
answers.push(nobles[0], true)
check("an admin's reset lets the boss be defeated again", $chat.size, 2)

# A guest fights the pools the invite names; C# hears whether the player reports.
reset
check("an invite's pool is none outside a battle that fights one", pool.invite_fields(31), {})
harpy("kind" => "guest")
pool.note_invite("troop" => "71", "pool" => 1, "boss" => true)
$role = :guest
answers.turn = { "guest" => true }
BattleManager.setup(71)
check("the guest's battle tells the rules of the invite and fights its pool as a guest",
      [$raid_answers.asked("raid.kind").find { |each| each["troop"] == 71 }["invited"], pool.fight && pool.fight.key, enemy.mhp, answers.asked("raid.fight.open").last["guest"]],
      [[71, false], "Queen Harpy", 6000, true])
$scene.start_party_command_selection
check("its moments tell C# it does not report, and it stays a guest while C# says so", [answers.asked("raid.fight.turn").last.values_at("moment", "reporter"), pool.fight.guest], [["phase", false], true])
BattleManager.instance_variable_set(:@phase, :input)
pass(10)
$scene.update_basic
check("a guest never takes the pools' HP while it waits for commands, its host's stream does", answers.moments.include?("wait"), false)
$role = nil
answers.turn = { "guest" => false, "took_over" => true }
$scene.update_basic
check("a guest that becomes the battle's reporter tells C# its role at once",
      [answers.asked("raid.fight.turn").find { |request| request["moment"] == "role" }["reporter"], pool.fight.guest], [true, false])
BattleManager.instance_variable_set(:@phase, nil)
pool.taken_over
check("a takeover told as it happens hands C# the enemies' HP then", answers.moments.last, "take_over")
reset
pool.taken_over
check("a takeover outside a pooled battle does nothing", [pool.fight, answers.moments], [nil, []])
reset
pool.note_invite("troop" => "71")
BattleManager.setup(71)
check("an invite without pools tells the rules of none", $raid_answers.asked("raid.kind").first["invited"], nil)

# The game's retry of a lost battle fights the pool again.
reset
start([[:battle, 71], [:mark, :after]])
first = pool.fight.battle
enemy.hp = 3000
$game_map.interpreter.clear
BattleManager.battle_end(2)
check("a lost battle hands C# what it dealt", [answers.moments.last, answers.asked("raid.fight.turn").last["enemies"][0][1]], ["end", 3000])
answers.turn = { "actions" => [[0, 3000]] }
BattleManager.retry_battle
check("the retry fights the pool as a battle of its own", [pool.fight && pool.fight.battle != first, enemy.mhp, pool.set_up_kind], [true, 6000, :event])
check("the map's interpreter runs its commands inside in_map only", [pool.in_map?, pool.in_map { pool.in_map? }, pool.in_map?], [false, true, false])
check("with the HP C# hands back as its battle starts", [answers.moments.last, enemy.hp], ["start", 3000])

# The invite and the player's state name the battle that fights a pool.
check("the invite of a battle that fights a pool names how many enemies it has", pool.invite_fields, { "pool" => 1 })
check("the state names the troop and the enemy rates while the player hosts it", pool.state_fields, { "rpb" => [71, [100, 100, 0]] })
$role = :guest
check("never while a guest", pool.state_fields, { "rpb" => nil })
$role = nil
$scene = nil
check("nor outside the battle", pool.state_fields, { "rpb" => nil })
$raid = false
check("and not at all in a Classic world", pool.state_fields, {})

# A host's boss battle offers a side battle against the same pool.
reset
# Another player as far as their state goes.
Host = Struct.new(:state)
check("a host's boss battle offers a side battle", pool.side_of(Host.new({ "rpb" => [71, [90, 100, 0]] })), [71, [90, 100, 0]])
check("one without a boss battle none", [pool.side_of(Host.new({ "rpb" => nil })), pool.side_of(Host.new({}))], [nil, nil])
check("nor one whose boss the rules give no pools", [pool.side_of(Host.new({ "rpb" => [609, [1, 2]] })), pool.side_of(Host.new({ "rpb" => [1507, [1, 2]] }))], [nil, nil])
harpy("kind" => "side")
check("the side battle starts", pool.start_side(71, [90, 100, 0]), true)
check("with the host's rates, the same troop, no escape, and the game's defeat", [$borrowed, $setups.last, $called], [[[90, 100, 0]], [71, false, false], [Scene_Battle]])
check("it fights the same pool, marked a side battle", [pool.fight.key, pool.fight.side, enemy.mhp, answers.asked("raid.fight.open").last["side"]], ["Queen Harpy", true, 6000, true])
reset
$raid_answers.troops[71] = { "pooled" => true, "defeated" => true }
check("a side battle never starts against pools the rules call empty", [pool.side_of(Host.new({ "rpb" => [71, [1, 2]] })), pool.start_side(71, [1, 2]), $setups], [nil, false, []])
reset
$mode = :own
check("nor for a player behind the world's story", pool.start_side(71, "1,2"), false)

# The pools are fetched as the player enters the world and each map, and read every few frames.
reset
ticks(1)
check("the pools are fetched as the player enters the world", fetches, ["w1"])
ticks(5)
check("once per map", fetches.size, 1)
$game_map.map_id = 6
ticks(1)
check("and again on another map", fetches.size, 2)
reset
ticks(1)
$pool_answers.pool("EX-Kyubi", "0.25", 3750)
ticks
check("what C# tells of a pool counts at the next read", [pool.pool("EX-Kyubi").left, pool.pool("EX-Kyubi").max, pool.pool("EX-Kyubi").defeated], [0.25, 3750, false])
told("EX-Kyubi", "0", 3750, true)
answers.push("EX-Kyubi", true)
check("an empty pool of a fight of its own tells its boss's name", [$chat.last, pool.pool("EX-Kyubi").by], ["EX-Kyubi is defeated for the whole world.", "Someone"])
answers.state = { "world" => "w2", "pools" => [["Queen Harpy", "0.2", 6000, false, ""]] }
ticks
check("the pools of another world are ignored", [pool.pool("Queen Harpy"), pool.pool("EX-Kyubi").defeated], [nil, true])

# The fetch the DLL did not start is tried again.
reset
answers.fetch = false
ticks(1)
ticks(pool::FETCH_RETRY_FRAMES - 1)
check("not before a while", fetches.size, 1)
answers.fetch = true
ticks(2)
check("then again until it starts", fetches.size, 2)
ticks(pool::FETCH_RETRY_FRAMES * 2)
check("and no more once it did", fetches.size, 2)

# The battle's moments in their order: its start once the game's own events before it ran, then
# its command phases, actions and turn ends, as often as C# allows.
reset
$battle_start_events = lambda { $data_enemies[1].params[0] = 400 }
$start_skills = lambda { enemy.hp -= 300 }
answers.turn = lambda { |request| request["moment"] == "start" ? { "actions" => [[0, 1500]] } : { "report_in" => 2000 } }
start([[:battle, 71], [:mark, :after]])
$battle_start_events = $start_skills = nil
first = answers.asked("raid.fight.turn").first
check("the boss takes its pool's HP of the max HP the events before the battle left, before the party's start skills",
      [first["moment"], first["enemies"][0][2], enemy.mhp, enemy.hp], ["start", 3000, 3000, 1200])
$data_enemies[1].params[0] = 800
$scene.start_party_command_selection
$scene.process_action
check("an action hands C# nothing until the time C# named for the next report passed", answers.moments, ["start", "phase"])
pass(2)
$scene.process_action
$scene.process_action
check("then once, and waits again", answers.moments, ["start", "phase", "action"])

# A boss whose pool is below a phase's share of its HP switches phase before anyone acts: the
# troop's pages are checked once more right after the pool's HP, before the start skills, where the
# game would check them next at the first turn's end (user decision 2026-11-05).
reset
$data_troops[71].pages = [:harpy_taunts, [:harpy_rages, 0.5]]
$battle_start_events = lambda { $game_troop.setup_battle_event }
phases = nil
$start_skills = lambda { phases = $pages_run.dup }
answers.turn = lambda { |request| request["moment"] == "start" ? { "actions" => [[0, 2000]] } : { "report_in" => 2000 } }
start([[:battle, 71], [:mark, :after]])
$battle_start_events = $start_skills = nil
$data_troops[71].pages = [:harpy_taunts]
check("a boss whose pool is below a phase's share switches phase before the start skills", [enemy.hp, phases], [2000, [:harpy_taunts, [:harpy_rages, 0.5]]])
reset
start([[:battle, 71]])
pool.forget
$scene.process_action
check("a battle whose pool is forgotten keeps its enemy's max HP and hands C# nothing", [enemy.mhp, answers.moments], [800, ["start"]])

# While the battle waits for commands, its enemies take the pools' HP as often as C# allows.
reset
start([[:var, 1001, 40], [:battle, 71], [:mark, :after]])
answers.turn = { "actions" => [[0, 3015]], "sync_in" => 5000 }
$scene.start_party_command_selection
BattleManager.instance_variable_set(:@phase, :input)
$scene.update_basic
pass(4)
$scene.update_basic
check("while the battle waits for commands, the enemy takes the pools' HP, then waits the time C# named",
      [answers.moments.count("wait"), enemy.hp], [0, 3015])
pass(1)
$scene.update_basic
check("and takes them again once it passed", answers.moments.count("wait"), 1)
BattleManager.instance_variable_set(:@phase, :turn)
pass(5)
$scene.update_basic
check("never while a turn runs", answers.moments.count("wait"), 1)
BattleManager.instance_variable_set(:@phase, :input)
answers.turn = { "actions" => [[0, 0]], "killed" => true }
$scene.update_basic
check("a pool emptied meanwhile fells the boss and wins the battle", [enemy.dead?, $won], [true, [71]])
reset
start([[:var, 1001, 40], [:battle, 71], [:mark, :after]])
$scene.start_party_command_selection
BattleManager.instance_variable_set(:@phase, :input)
$waiting = true
answers.turn = { "actions" => [[0, 0]], "killed" => true }
$scene.update_basic
check("a pool emptied while a live battle's host waits for commands fells the boss, the wait winning the battle", [enemy.dead?, $won], [true, []])
$waiting = false
BattleManager.instance_variable_set(:@phase, nil)

# A guest's troop built anew from its host's gets the raised max HP at once.
reset
harpy("kind" => "guest")
pool.note_invite("troop" => "71", "pool" => 1, "boss" => true)
$role = :guest
BattleManager.setup(71)
rebuilt = [Game_Enemy.new(0, 1)]
rebuilt[0].hp = 400
$game_troop.instance_variable_set(:@members, rebuilt)
pool.rescale
check("gets the raised max HP at once, keeping its share, and hands C# the troop built anew", [enemy.mhp, enemy.hp, answers.moments.last], [6000, 3000, "start"])

# The game's retry invites as a battle that fights the pool.
reset
start([[:battle, 71], [:mark, :after]])
$game_map.interpreter.clear
BattleManager.battle_end(2)
check("the retry's invite names the pool", pool.retrying { pool.invite_fields(71) }, { "pool" => 1 })
harpy("defeated" => true)
check("and is won already once the rules call the pool empty", pool.retrying { pool.won_already?(71) }, true)

# A side battle runs none of its troop's battle events and gives its boss's rewards only once.
reset
start([[:battle, 71], [:mark, :after]])
$game_troop.setup_battle_event
check("an event's boss battle runs its troop's pages", $pages_run, [:harpy_taunts])
check("and is no side battle", pool.side_battle?(71), false)
enemy.hp = 0
BattleManager.battle_end(0)
reset
$side_at_setup = []
harpy("kind" => "side")
pool.start_side(71, "100,100,0")
check("a side battle is one while it is set up and while it runs, of its troop alone",
      [$side_at_setup, pool.side_battle?(71), pool.side_battle?("71"), pool.side_battle?(609), pool.set_up_kind], [[true], true, true, false, :side])
$game_troop.setup_battle_event
$game_troop.setup_battle_event(:victory)
check("it runs none of its troop's pages", $pages_run, [])
check("and keeps them in the database", $data_troops[71].pages, [:harpy_taunts])
check("its first victory gives the boss's EXP, gold and drops", [BattleManager.enable_get_exp?, BattleManager.enable_get_gold?, BattleManager.enable_get_drop?], [true, true, true])
enemy.hp = 0
BattleManager.battle_end(0)
check("which the save notes, by the boss's key", $game_system.instance_variable_get(:@mgq_mp_raid_rewards), { "world" => "w1", "keys" => { "Queen Harpy" => true } })
check("once it is over, it is a side battle no more", pool.side_battle?(71), false)
pool.start_side(71, "100,100,0")
check("another side battle of that boss gives none", [BattleManager.enable_get_exp?, BattleManager.enable_get_gold?, BattleManager.enable_get_drop?], [false, false, false])
$game_map.interpreter.clear
BattleManager.battle_end(2)
BattleManager.retry_battle
check("nor does its retry, which is a side battle too", [pool.side_battle?(71), BattleManager.enable_get_exp?], [true, false])
BattleManager.battle_end(1)
harpy({})
start([[:battle, 71], [:mark, :after]])
check("the boss's event battle still gives them", [BattleManager.enable_get_exp?, pool.set_up_kind], [true, :event])
# Stands in for battles_raid_freeze.rbx, resuming the frozen fight of troop $resuming.
module MGQ_MpRaidFreeze; def self.resuming?(troop = nil); !$resuming.nil? && (troop.nil? || troop.to_i == $resuming); end; end
$resuming = 71
check("but not the resume of its frozen fight, whose side battle gave them", [BattleManager.enable_get_exp?, BattleManager.enable_get_drop?], [false, false])
$resuming = 609
check("while another boss's fight resumes it still does", BattleManager.enable_get_exp?, true)
$resuming = nil
BattleManager.battle_end(1)
$game_system.instance_variable_set(:@mgq_mp_raid_rewards, { "world" => "w2", "keys" => { "Queen Harpy" => true } })
harpy("kind" => "side")
pool.start_side(71, "100,100,0")
check("the notes of another world count for nothing", BattleManager.enable_get_exp?, true)
check("a side battle's invite tells it is one", pool.invite_fields, { "pool" => 1, "side" => true })
BattleManager.battle_end(1)
pool.note_rewarded("Queen Harpy")
harpy("kind" => "guest")
pool.note_invite("troop" => "71", "pool" => 1, "side" => true)
$role = :guest
$pages_run.clear
BattleManager.setup(71)
$game_troop.setup_battle_event
check("a guest of a side battle fights a side battle too: no troop pages, no rewards again",
      [pool.fight.side, pool.side_battle?(71), $pages_run, BattleManager.enable_get_exp?], [true, true, [], false])
BattleManager.battle_end(1)
pool.note_invite("troop" => "71", "pool" => 1)
BattleManager.setup(71)
check("a guest of a boss's event battle does not", [pool.fight.side, BattleManager.enable_get_exp?], [false, true])

# The World overview reads the pools as a copy, and their shares, labels and boss keys.
reset
told("Queen Harpy", "0.4")
pools = pool.pools
check("pools lists what C# told, by key", [pools.keys, pools["Queen Harpy"].left, pools["Queen Harpy"].max], [["Queen Harpy"], 0.4, 6000])
pools["Other"] = :nothing
check("as a copy, so a reader changes nothing", pool.pools.keys, ["Queen Harpy"])
check("the share left, a troop's label and a pool's boss key stay readable from outside",
      [pools["Queen Harpy"].left, pool.troop_label(71), pool.boss_key("Metatronne and Sandalphone#1")], [0.4, "Queen Harpy", "Metatronne and Sandalphone"])

# The battle server: the starter hands it the battle's fight and pools, and it fights them as host.
reset
start([[:battle, 71], [:mark, :after]])
answers.export = [1, 0, [["Queen Harpy", "0.5", 6000, 0, ""]]]
check("the starter hands the battle server what C# writes of its fight", pool.served_fields, [1, 0, [["Queen Harpy", "0.5", 6000, 0, ""]]])
BattleManager.battle_end(1)
check("a battle that fights no pool hands it nothing, without asking C#", [pool.served_fields, answers.asked("raid.fight.export").size], [nil, 1])
reset
harpy("kind" => nil)
answers.import = [1, false]
answers.turn = { "actions" => [[0, 3000]] }
BattleManager.setup(71)
pool.serve_fight(71, [1, 0, [["Queen Harpy", "0.5", 6000, 0, ""]]])
BattleManager.start_battle
check("the server hands C# the starter's fields and fights its pools as host, its enemy at the pool's HP once its battle started",
      [answers.asked("raid.fight.import").last, pool.fight.key, pool.fight.guest, enemy.mhp, enemy.hp],
      [{ "world" => "w1", "fields" => [1, 0, [["Queen Harpy", "0.5", 6000, 0, ""]]] }, "Queen Harpy", false, 6000, 3000])
BattleManager.battle_end(1)
reset
harpy("kind" => nil)
BattleManager.setup(71)
pool.serve_fight(71, ["1", 0, []])
check("fields C# takes none of fight no pool", pool.fight, nil)
