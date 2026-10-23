#----------------------------------------------------------------
#  raid_pool_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Checked that a refight of a boss the story beat is won at once
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

# Covers battles_raid_pool.rbx with battles_raid_bosses.rbx: which battles fight a raid boss's pools
# and with what max HP, the reports a battle sends and the pools' HP it takes, the kills by the
# relay, bosses of several enemies, guests and takeovers, the game's retry, the side battles, the
# invite's and the state's fields, the pushes and fetching the pools. Events run in fibers as the
# game's interpreter runs them.

require_relative "support"

# Stands in for the mod's base script, whose log prints each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$calls = []
$state = ""
$report_result = 1
$chat = []
$notices = []
$routes = {}
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

# The DLL: each call is noted, and the pools' state is what $state holds.
module MGQ_Multiplayer
  # Stands in for the DLL link.
  module Link
    # A function of the DLL, which notes its calls without their null bytes.
    Function = Struct.new(:name) do
      # Notes the call in $calls, refusing arguments its signature does not name.
      #
      # @param args [Array] The arguments.
      # @return [Integer] $report_result, 1 when the DLL took the call.
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, args.map { |arg| arg.is_a?(String) ? arg.chomp("\0") : arg }]
        $report_result
      end
    end
    # Answers a function of the DLL.
    def self.function(name); Function.new(name); end
    # Answers the pools' state, $state, as the DLL hands it over.
    def self.read(name, size); check_dll_call(name, ["", size]); $state.dup.force_encoding("ASCII-8BIT"); end
    # Reads the DLL's description as Link.parse does: key=value lines, an empty line, the payload.
    #
    # @param text [String] The text.
    # @return [Hash] The fields, with the payload under :payload.
    def self.parse(text)
      head, payload = text.force_encoding("UTF-8").split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| key, value = line.split("=", 2); state[key] = value if value }
      state
    end
  end
end
# Stands in for the world's sync, keeping its routes in $routes, its frame blocks in $ticks and the
# state's blocks in $state_fields.
module MGQ_MpOverworldSync
  # The field of the relay's push of a pool.
  BOSS_FIELD = "boss_key"
  # Keeps a field's handler in $routes.
  def self.route(field, &block); $routes[field] = block; end
  # Keeps a block to run each frame in $ticks.
  def self.on_tick(&block); $ticks << block; end
  # Keeps a block of the player's state fields in $state_fields.
  def self.state_fields(&block); $state_fields << block; end
end
# Stands in for the co-op scope, in a Raid World while $raid is set.
module MGQ_MpCoop; module Scope; def self.raid?; $raid; end; end; end
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
  def self.rates_text; "100,100,0"; end
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
  # Runs the troop's battle event pages, noting each in $pages_run.
  def setup_battle_event(_timing = nil); troop.pages.each { |page| $pages_run << page } if troop; end
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
  # Sets the lost battle up again.
  def self.retry_battle; setup(@troop_id); $game_party.in_battle = true; true; end
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
end
# Stands in for the game's scenes, the running one in $scene and those called in $called.
module SceneManager
  # Stands in for starting the game, doing nothing.
  def self.run; end
  # Answers the running scene: $scene.
  def self.scene; $scene; end
  # Notes the scene called in $called.
  def self.call(klass); $called << klass; end
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
    BattleManager.event_proc = Proc.new { |n| $branch = n }
    $game_party.in_battle = true
    Fiber.yield
  end
end

load_script "battles_raid_bosses"
load_script "battles_raid_pool"
# The real tiers, kept aside while the battles below count on 7.5 times the max HP in every tier.
REAL_TIERS = MGQ_MpRaidBosses::TIERS.dup
MGQ_MpRaidBosses::TIERS.replace(REAL_TIERS.keys.each_with_object({}) { |tier, tiers| tiers[tier] = { :mhp => 7.5 } })

pool = MGQ_MpRaidPool
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
  [$calls, $chat, $notices, $ran, $borrowed, $collapsed, $won, $called, $pages_run].each(&:clear)
  $side_at_setup = nil
  $setups = []
  $phases = []
  $given_back = 0
  $state = ""
  $report_result = 1
  $raid = true
  $mode = :world
  $role = nil
  $turn_end = nil
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

# Lists the reports sent.
#
# @return [Array<Array(String, String, String)>] Each one's key, battle id and text.
def reports
  $calls.select { |name, _| name == "mp_raid_boss_report" }.map { |_, args| args[1..3] }
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

# Has the relay push a pool.
#
# @param key [String] The pool's key.
# @param left [String] The share of its max left.
# @param max [String] Its max HP.
# @param defeated [Boolean] Whether it is empty for good.
def push(key, left, max = "6000", defeated = false)
  $routes[MGQ_MpOverworldSync::BOSS_FIELD].call(nil, { MGQ_MpOverworldSync::BOSS_FIELD => key, "left" => left, "max" => max, "defeated" => defeated ? "1" : "0",
                                                         "by" => defeated ? "Someone" : "", :relay => true })
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
  count.times { $ticks.each { |tick| tick.call(true) } }
end

# The boss tables and the pools' keys hold together.
rows = MGQ_MpRaidBosses::TROOPS.values.map { |row| [row[0], row[1]] }.uniq
check("every milestone has the markers that tell it beaten", rows - pool::BEATEN.keys, [])
check("and no markers name a milestone the boss table lacks", pool::BEATEN.keys - rows, [])
story_switches = []
story_variables = []
story_variables[1003] = 8
story_variables[1011] = 4
check("the caps of the milestones a story beat come from its own values, each once and lowest first",
      [pool.beaten_caps([story_switches, story_variables]), pool.beaten_caps([[], []])], [[10, 15], []])
check("every fight of its own and every troop left out is a last phase",
      (pool::FIGHTS.keys + pool::UNPOOLED.keys).reject { |troop| MGQ_MpRaidBosses.at(troop).last }, [])
keys = MGQ_MpRaidBosses::TROOPS.keys.select { |troop| MGQ_MpRaidBosses.at(troop).last }.map { |troop| [pool.key_of(troop), MGQ_MpRaidBosses.at(troop).milestone, MGQ_MpRaidBosses.at(troop).cap] }
check("every last phase has a key the relay takes, with room for an enemy's place", keys.select { |key, _, _| key.nil? }, [])
shared = keys.group_by { |key, _, _| key }.select { |_, list| list.map { |_, milestone, cap| [milestone, cap] }.uniq.size > 1 }.keys
check("no two milestones share a pool", shared, [])
check("a name several milestones share carries the cap", [pool.key_of(1502), pool.key_of(1807), pool.key_of(71), pool.key_of(836), pool.key_of(1501)],
      ["Tamamo (cap 61)", "Tamamo (cap 80)", "Queen Harpy", "Black Dahlia, Black Mamba and Black Rose (cap 55)", "Black Dahlia, Black Mamba and Black Rose (cap 60)"])
check("a fight of a free order has a pool of its own", [pool.key_of(2017), pool.key_of(2099)], ["EX-Kyubi", "Lustful Witch"])
check("a boss of several enemies has a pool per enemy", pool.troop_keys(1599), ["Metatronne and Sandalphone#0", "Metatronne and Sandalphone#1"])
check("a boss of one enemy has one pool under its key", pool.troop_keys(71), ["Queen Harpy"])
reset
$game_switches[2594] = true
check("all conditions of an alternative must hold", pool.met?("s2594&v1142>=25"), false)
$game_variables[1142] = 25
check("then the test holds", pool.met?("s2594&v1142>=25"), true)
check("any alternative may hold", [pool.met?("v1141>=1|v1142>=1"), pool.met?("v1141>=1|v1143>=1")], [true, false])

# A one-time boss outside the story fights a pool of its own under its name.
reset
check("a one-time Chaos Domain boss is a boss of one phase without a cap", [MGQ_MpRaidBosses.boss?(3127), MGQ_MpRaidBosses.last_phase?(3127), MGQ_MpRaidBosses.at(3127).cap], [true, true, nil])
check("its pool goes by its name", [pool.key_of(3127), pool.pooled_troop?(3127), pool.troop_of_key("Void Image of Paradise")], ["Void Image of Paradise", true, 3127])
check("and no name of the story table or of another boss", (MGQ_MpRaidBosses::OPTIONAL.values.map(&:first) & (MGQ_MpRaidBosses::TROOPS.values.map(&:first) + pool::FIGHTS.values)), [])
start([[:battle, 3127], [:mark, :after]])
check("its event battle fights that pool with 7.5 times the max HP", [pool.fight && pool.fight.key, enemy.mhp], ["Void Image of Paradise", 7500])

# A story boss's last phase fights its pool with its tier's factor of the max HP.
reset
start([[:var, 1001, 40], [:battle, 71], [:mark, :after]])
fight = pool.fight
check("a story boss's last phase fights its pool, even after the event moved the story", [$game_party.in_battle, fight && fight.key, fight && fight.own], [true, "Queen Harpy", 1])
check("its enemy has 7.5 times its max HP, all of it", [enemy.mhp, enemy.hp], [6000, 6000])

# Which troops are bosses, and their tiers, titles and stat factors.
bosses = MGQ_MpRaidBosses
check("each boss has the tier its list names, tier 0 the strongest",
      [bosses.tier(71), bosses.tier(752), bosses.tier(1725), bosses.tier(1807), bosses.tier(2188), bosses.tier(2219), bosses.tier(3127), bosses.tier(31)],
      [9, 7, 3, 4, 1, 0, 1, nil])
check("a shared name tells the milestones apart by their cap", [bosses.milestone_key(1502), bosses.milestone_key(71), bosses.milestone_key(3127)],
      ["Tamamo (cap 61)", "Queen Harpy", "Void Image of Paradise"])
check("a boss outside the Level Cap milestones is one of its own with its tier",
      [bosses.milestone_key(212), bosses.tier(212), bosses.milestone_key(1461), bosses.tier(1461), bosses.tier(868), bosses.tier(327)],
      ["Sylph", 7, "Erubetie (cap 60)", 5, 5, 5])
$game_map.map_id = 723
check("Carmilla and Elizabeth withdraw from the Sabasa Attack as from an earlier phase", [bosses.last_phase?(812), bosses.last_phase?(813), pool.pooled_troop?(812)],
      [false, false, false])
$game_map.map_id = 295
check("and are fought for their pools in the Vampire Castle", [bosses.last_phase?(812), pool.pooled_troop?(812)], [true, true])
$game_map.map_id = 5
check("a boss's title is the group the game names it in, else its tier",
      [bosses.title(1599), bosses.title(3127), bosses.title(2219), bosses.title(71), bosses.title(31)],
      ["Archangel", "Chaos' Phantom", "Tier 0 Raid Boss", "Tier 9 Raid Boss", nil])
titled = bosses::TITLES.values.flatten
check("the titles name each boss once and none the tables lack",
      [titled.size - titled.uniq.size, titled - (bosses::TROOPS.keys + bosses::OPTIONAL.keys).map { |troop| bosses.milestone_key(troop) }], [0, []])
check("every boss has a tier the table holds", (bosses::TROOPS.keys + bosses::OPTIONAL.keys).reject { |troop| bosses::TIERS.key?(bosses.tier(troop)) }, [])
names = bosses::TIER_BOSSES.values.flatten
check("the tier lists name each milestone once and none the table lacks",
      [names.size - names.uniq.size, names - bosses::TROOPS.keys.map { |troop| bosses.milestone_key(troop) }], [0, []])
check("tiers name only stats the game has", bosses::TIERS.values.map(&:keys).flatten.uniq - [:mhp, :mmp, :atk, :def, :mat, :mdf, :agi, :luk], [])
check("a tier gives max HP its factor and leaves the stats it does not name", [bosses.factor(71, :mhp), bosses.factor(71, :atk), bosses.factor(31, :mhp)], [7.5, 1, 1])
kept = bosses::TIERS[9]
bosses::TIERS[9] = kept.merge(:atk => 2)
check("another stat a tier names takes its factor after the game computed it", [pool.stat(enemy, :atk, 101), pool.stat(Game_Enemy.new(0, 6), :atk, 101)], [202, 101])
check("and the max HP its own", pool.stat(enemy, :mhp, 800), 6000)
bosses::TIERS[9] = kept
bosses::TIERS.replace(REAL_TIERS)
check("the real tiers: 50 times the max HP at tier 0, 5 less each tier down to 5 times at tier 9",
      (0..9).map { |tier| bosses::TIERS[tier][:mhp] }, [50, 45, 40, 35, 30, 25, 20, 15, 10, 5])
check("and 5 times the defense and magic defense at tier 0, falling evenly to the game's own from tier 6 on",
      [:def, :mdf].map { |stat| (0..9).map { |tier| bosses::TIERS[tier].fetch(stat, 1) } }, [[5.0, 4.33, 3.67, 3.0, 2.33, 1.67, 1, 1, 1, 1]] * 2)
check("so Chaos, Chaos Ilias and Queen Harpy get these", [[2219, 1725, 71].map { |troop| bosses.factor(troop, :mhp) }, [2219, 1725, 71].map { |troop| bosses.factor(troop, :def) }],
      [[50, 35, 5], [5.0, 3.0, 1]])
check("which wraps both defenses of the game's enemies too", bosses.tier_stats, [:def, :mdf])
bosses::TIERS.replace(REAL_TIERS.keys.each_with_object({}) { |tier, tiers| tiers[tier] = { :mhp => 7.5 } })

# The story boss's battle has an id the relay takes and keeps its HP without word from the relay.
check("its battle id is one the relay takes", fight.battle =~ /\A[a-z0-9]{3,64}\z/ ? true : false, true)
$scene.start_party_command_selection
check("a command phase without word from the relay keeps the HP", enemy.hp, 6000)

# What a turn dealt is reported as the next command phase opens.
enemy.hp = 4500
next_turn
key, battle, text = reports.last
check("the next command phase reports the share of the max HP the boss lost", [key, battle, text], ["Queen Harpy", fight.battle, "1\t0.2500000000\t6000\t0"])
check("the report names the world", $calls.last[1][0], "w1")
next_turn
check("a turn that dealt nothing reports nothing", reports.size, 1)
$scene.start_party_command_selection
check("the next command phase keeps what the battle dealt before the relay answers", enemy.hp, 4500)
enemy.hp = 4800
next_turn
check("healing reports a share lost below 0, numbered on", reports.last[2], "2\t-0.0500000000\t6000\t0")

# The relay's word comes in at the command phase.
push("Queen Harpy", "0.5")
$scene.start_party_command_selection
check("another battle's blows reach the boss at the next command phase", enemy.hp, 3000)
pass(60)
$scene.start_party_command_selection
check("the pool gains 3 % of its max back every minute", enemy.hp, 3180)
pass(6000)
$scene.start_party_command_selection
check("never past its max", enemy.hp, 6000)

# The DLL's state of the pools: a line that tells nothing new never takes back the player's own
# blows the relay has not answered yet.
$state = "world=w1\n\nQueen Harpy\t0.9\t6000\t0\t\n"
ticks
check("the DLL's first line of a pool counts", [pool.pool("Queen Harpy").left, pool.pool("Queen Harpy").max], [0.9, 6000])
$scene.start_party_command_selection
enemy.hp = 4800
$scene.turn_end
ticks
$scene.start_party_command_selection
check("the same line again keeps the player's own report", enemy.hp, 4800)
$state = "world=w1\n\nQueen Harpy\t0.7\t6000\t0\t\n"
ticks
$scene.start_party_command_selection
check("a line that changed counts", enemy.hp, 4200)

# A pool the relay emptied kills the boss, and the battle wins.
push("Queen Harpy", "0", "6000", true)
check("the push that empties the pool tells the chat log and the notification box", [$chat.last, $notices.last], ["Queen Harpy is defeated for the whole world."] * 2)
push("Queen Harpy", "0", "6000", true)
check("only once", $chat.size, 1)
$scene.start_party_command_selection
check("the boss falls at the next command phase", [enemy.dead?, $collapsed, $won], [true, ["Queen Harpy"], [71]])
check("and its death goes to the relay as the battle ends", reports.last[2].split("\t").values_at(2, 3), ["6000", "1"])
check("the battle is over", pool.fight, nil)
frames
check("the event goes on at once", [$ran, $branch], [[:after], 0])

# A boss the battle kills: its death is reported and the story goes on without waiting.
reset
start([[:battle, 71], [:mark, :after]])
battle = pool.fight.battle
enemy.hp = 0
BattleManager.battle_end(0)
check("the battle's last blow reports the kill", reports.last, ["Queen Harpy", battle, "1\t1.0000000000\t6000\t1"])
frames
check("the event runs on at once", $ran, [:after])
check("the pool is empty as the player's game knows it", pool.defeated?(71), true)

# A battle against a pool that is empty already wins at once.
start([[:battle, 71], [:mark, :after_again]])
check("its boss starts dead", [enemy.dead?, enemy.hp], [true, 0])
check("which invites nobody", pool.won_already?(71), false)
reset
push("Queen Harpy", "0", "6000", true)
$game_map.interpreter.instance_variable_set(:@event_id, 7)
pool.in_map { pool.at_command { check("a battle about to fight an empty pool is won already", pool.won_already?(71), true) } }

# Battles that fight no pool.
reset
$raid = false
start([[:battle, 71], [:mark, :after]])
check("a Classic world's battle fights no pool, its enemy keeps its max HP", [pool.fight, enemy.mhp], [nil, 800])
$scene.turn_end
BattleManager.battle_end(0)
frames
check("and reports nothing", [reports, $ran], [[], [:after]])
{
  "a player whose story is in an earlier part" => proc { $mode = :own },
  "a Hades rematch" => proc { $game_switches[97] = true },
  "an event of the Hades rematch hall, before it turns the rematch's switch on" => proc { $game_map.map_id = 576 },
  "a Colosseum battle" => proc { $game_switches[87] = true },
}.each do |label, set|
  reset
  set.call
  start([[:battle, 71], [:mark, :after]])
  check("#{label} fights no pool", pool.fight, nil)
end

# A refight of a boss the world's story beat already fights no pool and is won at once, as against
# empty pools (issue #57).
reset
$game_variables[1011] = 4
$game_map.interpreter.instance_variable_set(:@event_id, 7)
pool.in_map { pool.at_command { check("a refight of a boss the story beat is won already, so it invites nobody", pool.won_already?(71), true) } }
start([[:battle, 71], [:mark, :after]])
check("it fights no pool, its boss starts dead", [pool.fight, enemy.dead?], [nil, true])
$scene.start_party_command_selection
check("and its first command phase wins it", $won, [71])
frames
check("the event goes on", $ran, [:after])
reset
$game_variables[1011] = 4
$game_switches[87] = true
start([[:battle, 71], [:mark, :after]])
$scene.start_party_command_selection
check("a Colosseum battle of the boss is fought as the game fights it", [enemy.dead?, $won], [false, []])
reset
start([[:battle, 1507], [:mark, :after]])
check("the Great Decision fights no pool", pool.fight, nil)
reset
start([[:battle, 71], [:mark, :after]], 0)
check("a common event of its own fights no pool", pool.fight, nil)
reset
BattleManager.setup(71)
check("a battle no event command started fights no pool", pool.fight, nil)
reset
start([[:battle, 31], [:mark, :after]])
check("a troop that is no story boss fights no pool", pool.fight, nil)

# A fight of several phases fights the pool on its last; one in a common event the event calls too.
reset
start([[:battle, 609], [:battle, 610], [:mark, :after]])
check("an earlier phase fights no pool", pool.fight, nil)
BattleManager.battle_end(0)
frames
check("the last phase does", pool.fight.key, "Alma Elma, then Granberia")
reset
start([[:call, [[:battle, 71]]], [:mark, :after]])
check("a boss battle in a common event the event calls fights the pool", pool.fight && pool.fight.key, "Queen Harpy")

# A boss of several enemies has a pool per enemy, and falls once every one is empty.
reset
start([[:battle, 1599], [:mark, :after]])
fight = pool.fight
check("a pool per own enemy of the troop", fight.members.map(&:key), ["Metatronne and Sandalphone#0", "Metatronne and Sandalphone#1"])
check("each with 7.5 times its own max HP", [enemy(0).mhp, enemy(1).mhp], [15000, 22500])
enemy(0).hp = 7500
next_turn
check("each reports its own share", reports.map { |key, _, text| [key, text] }, [["Metatronne and Sandalphone#0", "1\t0.5000000000\t15000\t0"]])
push("Metatronne and Sandalphone#1", "0", "22500", true)
check("one enemy's empty pool is no defeat of the boss yet", $chat, [])
$scene.start_party_command_selection
check("it kills only that enemy, so the battle goes on", [enemy(0).dead?, enemy(1).dead?, $won], [false, true, []])
push("Metatronne and Sandalphone#0", "0", "15000", true)
check("once every enemy's pool is empty, the boss is defeated", $chat, ["Metatronne and Sandalphone is defeated for the whole world."])
$scene.start_party_command_selection
check("and the battle wins", $won, [1599])
push("Metatronne and Sandalphone#0", "1", "15000")
push("Metatronne and Sandalphone#0", "0", "15000", true)
check("an admin's reset lets the boss be defeated again", $chat.size, 2)

# A guest fights the pools the invite names, and reports once it takes the battle over.
reset
check("an invite's pool is none outside a battle that fights one", pool.invite_fields(31), {})
pool.note_invite("troop" => "71", "pool" => "1", "boss" => "1")
$role = :guest
BattleManager.setup(71)
check("the guest's battle fights the invite's pool", [pool.fight && pool.fight.key, enemy.mhp], ["Queen Harpy", 6000])
$scene.start_party_command_selection
# The host's action dealt half the boss's HP, which the host reported as it ended.
enemy.hp = 3000
pass(MGQ_MpRaidPool::REPORT_SECONDS)
$scene.process_action
next_turn
check("a guest reports nothing", reports, [])
$role = nil
$scene.start_party_command_selection
check("a guest who takes the battle over reports nothing of what the host reported", [reports, enemy.hp], [[], 3000])
enemy.hp = 2400
next_turn
check("its first report carries only what it dealt since it took the battle over", reports.map { |_key, _battle, text| text }, ["1\t0.1000000000\t6000\t0"])
reset
pool.note_invite("troop" => "71", "pool" => "1")
$role = :guest
BattleManager.setup(71)
enemy.hp = 4800
$role = nil
pass(MGQ_MpRaidPool::REPORT_SECONDS)
$scene.process_action
check("a takeover seen first as an action ends reports nothing of the host's either", reports, [])
enemy.hp = 4200
$scene.start_party_command_selection
check("only what came after", reports.map { |_key, _battle, text| text }, ["1\t0.1000000000\t6000\t0"])
reset
pool.note_invite("troop" => "71", "pool" => "1")
$role = :guest
BattleManager.setup(71)
$role = nil
pool.taken_over
# The battle the host never formed starts now, its start dealing damage of its own.
enemy.hp = 5400
$scene.start_party_command_selection
check("a takeover told as it happens reports the damage of the battle's start that follows", reports.map { |_key, _battle, text| text }, ["1\t0.1000000000\t6000\t0"])
reset
pool.taken_over
check("a takeover outside a pooled battle does nothing", [pool.fight, reports], [nil, []])
reset
push("Queen Harpy", "0", "6000", true)
pool.note_invite("troop" => "71", "pool" => "1")
$role = :guest
BattleManager.setup(71)
$scene.start_party_command_selection
BattleManager.instance_variable_set(:@phase, :input)
pass(MGQ_MpRaidPool::INPUT_SYNC_SECONDS)
$scene.update_basic
$scene.turn_end
check("a guest never kills the boss by its own view of the pool, its host's stream does", [enemy.dead?, enemy.hp, $won, $collapsed], [false, 6000, [], []])
BattleManager.instance_variable_set(:@phase, nil)
reset
pool.note_invite("troop" => "71")
BattleManager.setup(71)
check("an invite without pools brings none", [pool.fight, pool.set_up_kind], [nil, nil])

# The game's retry of a lost battle fights the pool again, with the pool's HP.
reset
start([[:battle, 71], [:mark, :after]])
first = pool.fight.battle
enemy.hp = 3000
$game_map.interpreter.clear
BattleManager.battle_end(2)
check("a lost battle reports what it dealt", reports.last[2], "1\t0.5000000000\t6000\t0")
BattleManager.retry_battle
check("the retry fights the pool as a battle of its own", [pool.fight && pool.fight.battle != first, enemy.mhp, pool.set_up_kind], [true, 6000, :event])
check("the game's retry runs inside retrying only", [pool.retrying?, pool.retrying { pool.retrying? }, pool.retrying?], [false, true, false])
check("the map's interpreter runs its commands inside in_map only", [pool.in_map?, pool.in_map { pool.in_map? }, pool.in_map?], [false, true, false])
check("with the HP the pool has left", enemy.hp, 3000)

# The invite and the player's state name the battle that fights a pool.
check("the invite of a battle that fights a pool names how many enemies it has", pool.invite_fields, { "pool" => 1 })
check("the state names the troop and the enemy rates while the player hosts it", pool.state_fields, { "rpb" => "71;100,100,0" })
$role = :guest
check("never while a guest", pool.state_fields, { "rpb" => "" })
$role = nil
$scene = nil
check("nor outside the battle", pool.state_fields, { "rpb" => "" })
$raid = false
check("and not at all in a Classic world", pool.state_fields, {})

# A host's boss battle offers a side battle against the same pool.
reset
# Another player as far as their state goes.
Host = Struct.new(:state)
check("a host's boss battle offers a side battle", pool.side_of(Host.new({ "rpb" => "71;90,100,0" })), [71, "90,100,0"])
check("one without a boss battle none", [pool.side_of(Host.new({ "rpb" => "" })), pool.side_of(Host.new({}))], [nil, nil])
check("nor one whose boss is no pooled last phase", [pool.side_of(Host.new({ "rpb" => "609;1,2" })), pool.side_of(Host.new({ "rpb" => "1507;1,2" }))], [nil, nil])
check("the side battle starts", pool.start_side(71, "90,100,0"), true)
check("with the host's rates, the same troop, no escape, and the game's defeat", [$borrowed, $setups.last, $called], [["90,100,0"], [71, false, false], [Scene_Battle]])
check("it fights the same pool, marked a side battle", [pool.fight.key, pool.fight.side, enemy.mhp], ["Queen Harpy", true, 6000])
enemy.hp = 5400
next_turn
check("and reports like any other", reports.last[0..2].values_at(0, 2), ["Queen Harpy", "1\t0.1000000000\t6000\t0"])
reset
push("Queen Harpy", "0", "6000", true)
check("a side battle never starts against an empty pool", [pool.side_of(Host.new({ "rpb" => "71;1,2" })), pool.start_side(71, "1,2"), $setups], [nil, false, []])
reset
$mode = :own
check("nor for a player behind the world's story", pool.start_side(71, "1,2"), false)

# The pools are fetched as the player enters the world and each map.
reset
ticks(1)
check("the pools are fetched as the player enters the world", $calls.select { |name, _| name == "mp_raid_bosses_fetch" }, [["mp_raid_bosses_fetch", ["w1"]]])
ticks(5)
check("once per map", $calls.count { |name, _| name == "mp_raid_bosses_fetch" }, 1)
$game_map.map_id = 6
ticks(1)
check("and again on another map", $calls.count { |name, _| name == "mp_raid_bosses_fetch" }, 2)

# The relay's pushes count, others are ignored.
reset
$routes[MGQ_MpOverworldSync::BOSS_FIELD].call(nil, { MGQ_MpOverworldSync::BOSS_FIELD => "Queen Harpy", "left" => "0", "defeated" => "1" })
check("a push not from the relay is ignored", [pool.pool("Queen Harpy"), $chat], [nil, []])
push("EX-Kyubi", "0.25", "3750")
check("a push counts the pool as told", [pool.pool("EX-Kyubi").left, pool.pool("EX-Kyubi").max, pool.pool("EX-Kyubi").defeated], [0.25, 3750, false])
push("EX-Kyubi", "nonsense")
check("a push without a share is ignored", pool.pool("EX-Kyubi").left, 0.25)
push("EX-Kyubi", "0", "3750", true)
check("an empty pool of a fight of its own tells its boss's name", [$chat.last, pool.pool("EX-Kyubi").by], ["EX-Kyubi is defeated for the whole world.", "Someone"])

# Damage the game's turn end and battle start deal goes to the pool too.
reset
push("Queen Harpy", "0.5")
start([[:battle, 71], [:mark, :after]])
enemy.hp -= 300
$scene.start_party_command_selection
check("a battle start skill's damage is reported at the first command phase", [reports.last[2], enemy.hp], ["1\t0.0500000000\t6000\t0", 2700])
$turn_end = proc { enemy.hp -= 600 }
next_turn
check("slip damage at the turn's end is reported, not undone", [reports.last[2], enemy.hp], ["2\t0.1000000000\t6000\t0", 2100])
reset
start([[:battle, 71], [:mark, :after]])
enemy.hp = 5000
$scene.start_party_command_selection
check("so is damage before the first command phase against a pool the relay told nothing of", reports.last[2], "1\t0.1666666667\t6000\t0")

# A report the DLL refuses keeps the HP until the next goes.
reset
ticks(1)
push("Queen Harpy", "0.5")
start([[:battle, 71], [:mark, :after]])
$report_result = 0
enemy.hp = 2400
$scene.start_party_command_selection
check("a refused report keeps the HP the battle dealt", [reports.size, enemy.hp], [1, 2400])
$report_result = 1
$scene.start_party_command_selection
check("which goes with the next report", [reports.last[2], enemy.hp], ["1\t0.1000000000\t6000\t0", 2400])

# Word of a pool older than the player's own reports the relay has not answered yet is ignored.
push("Queen Harpy", "0.5")
$scene.start_party_command_selection
check("a push older than an unanswered report is ignored", enemy.hp, 2400)
$state = "world=w1\nreport_queued=1\n\nQueen Harpy\t0.5\t6000\t0\t\n"
ticks
$scene.start_party_command_selection
check("so is the DLL's line while the report waits", enemy.hp, 2400)
$state = "world=w1\n\nQueen Harpy\t0.45\t6000\t0\t\n"
ticks
$scene.start_party_command_selection
check("the line counts once the relay answered", enemy.hp, 2700)
enemy.hp = 2100
$scene.start_party_command_selection
push("Queen Harpy", "1")
$scene.start_party_command_selection
check("an admin's reset counts at once", enemy.hp, 6000)

# The DLL's pools of another world are ignored.
reset
$state = "world=w2\n\nQueen Harpy\t0.2\t6000\t0\t\n"
ticks
check("the DLL's pools of another world are ignored", pool.pool("Queen Harpy"), nil)

# A pool whose share rounds to 0 while it stands never kills the boss.
reset
push("Queen Harpy", "0", "18000000000000")
start([[:battle, 71], [:mark, :after]])
check("a pool the relay keeps standing never kills the boss", [enemy.dead?, enemy.hp], [false, 1])

# The game's retry invites as a battle that fights the pool.
reset
start([[:battle, 71], [:mark, :after]])
enemy.hp = 3000
$game_map.interpreter.clear
BattleManager.battle_end(2)
check("the retry's invite names the pool", pool.retrying { pool.invite_fields(71) }, { "pool" => 1 })
push("Queen Harpy", "0", "6000", true)
check("and is won already once the pool is empty", pool.retrying { pool.won_already?(71) }, true)

# A guest's troop built anew from its host's gets the raised max HP at once.
reset
pool.note_invite("troop" => "71", "pool" => "1", "boss" => "1")
$role = :guest
BattleManager.setup(71)
rebuilt = [Game_Enemy.new(0, 1)]
rebuilt[0].hp = 400
$game_troop.instance_variable_set(:@members, rebuilt)
pool.rescale
check("gets the raised max HP at once, keeping its share", [enemy.mhp, enemy.hp], [6000, 3000])

# A boss built anew at full HP, as the battle server rebuilt its troop, heals no pool: it reports
# nothing and takes its pool's HP (the boss healed to full once a second player joined).
reset
push("Queen Harpy", "0.1")
start([[:battle, 71], [:mark, :after]])
check("the boss starts at its pool's HP", enemy.hp, 600)
$game_troop.instance_variable_set(:@members, [Game_Enemy.new(0, 1)])
next_turn
check("one built anew at full HP reports nothing and takes its pool's HP", [reports, enemy.hp], [[], 600])
enemy.hp = 300
next_turn
check("what the battle deals to it after counts", reports.last[2], "1	0.0500000000	6000	0")
$game_troop.instance_variable_set(:@members, [Game_Enemy.new(0, 1)])
pool.rescale
check("one built anew and given its tier's stats takes its pool's HP at once", enemy.hp, 300)

# The fetch the DLL did not start is tried again.
reset
$report_result = 0
ticks(1)
ticks(pool::FETCH_RETRY_FRAMES - 1)
check("not before a while", $calls.count { |name, _| name == "mp_raid_bosses_fetch" }, 1)
$report_result = 1
ticks(2)
check("then again until it starts", $calls.count { |name, _| name == "mp_raid_bosses_fetch" }, 2)
ticks(pool::FETCH_RETRY_FRAMES * 2)
check("and no more once it did", $calls.count { |name, _| name == "mp_raid_bosses_fetch" }, 2)

# A battle whose pool is forgotten keeps its enemy's own max HP.
reset
start([[:battle, 71]])
pool.forget
check("a battle that fights no pool keeps its enemy's max HP", enemy.mhp, 800)

# A long turn reports what its actions dealt, a few seconds apart.
reset
start([[:var, 1001, 40], [:battle, 71], [:mark, :after]])
$scene.start_party_command_selection
pass(MGQ_MpRaidPool::REPORT_SECONDS)
enemy.hp = 5400
$scene.process_action
check("an action reports what it dealt", reports.map { |_key, _battle, text| text }, ["1	0.1000000000	6000	0"])
enemy.hp = 4800
$scene.process_action
check("the next one within REPORT_SECONDS waits", reports.size, 1)
pass(MGQ_MpRaidPool::REPORT_SECONDS)
$scene.process_action
check("and goes out once they passed, with all it dealt since", reports.last[2], "2	0.1000000000	6000	0")
$scene.start_party_command_selection
check("the command phase reports nothing dealt twice, and takes the pool's HP with its regeneration since", [reports.size, enemy.hp], [2, 4806])
enemy.hp = 4506
$scene.start_party_command_selection
check("but still reports at once, however soon", reports.last[2], "3	0.0500000000	6000	0")
pool.forget
enemy.hp = 4000
pass(MGQ_MpRaidPool::REPORT_SECONDS)
$scene.process_action
check("a battle that fights no pool reports nothing", reports.size, 3)

# While the battle waits for commands, its enemies take the pools' HP every few seconds.
reset
start([[:var, 1001, 40], [:battle, 71], [:mark, :after]])
$scene.start_party_command_selection
BattleManager.instance_variable_set(:@phase, :input)
push("Queen Harpy", "0.5")
$scene.update_basic
check("another battle's blows wait while the battle waits for commands", enemy.hp, 6000)
pass(MGQ_MpRaidPool::INPUT_SYNC_SECONDS)
$scene.update_basic
check("until INPUT_SYNC_SECONDS passed, then the enemy takes the pool's HP with its regeneration", enemy.hp, 3015)
BattleManager.instance_variable_set(:@phase, :turn)
push("Queen Harpy", "0.2")
pass(MGQ_MpRaidPool::INPUT_SYNC_SECONDS)
$scene.update_basic
check("never while a turn runs", enemy.hp, 3015)
BattleManager.instance_variable_set(:@phase, :input)
push("Queen Harpy", "0", "6000", true)
pass(MGQ_MpRaidPool::INPUT_SYNC_SECONDS)
$scene.update_basic
check("a pool emptied meanwhile fells the boss and wins the battle", [enemy.dead?, $won], [true, [71]])
BattleManager.instance_variable_set(:@phase, nil)

# While a live battle's host waits for the other players' commands, a pool emptied meanwhile fells
# the boss, and the wait wins the battle.
reset
start([[:var, 1001, 40], [:battle, 71], [:mark, :after]])
$scene.start_party_command_selection
BattleManager.instance_variable_set(:@phase, :input)
$waiting = true
push("Queen Harpy", "0", "6000", true)
pass(MGQ_MpRaidPool::INPUT_SYNC_SECONDS)
$scene.update_basic
check("a pool emptied while the host waits for commands fells the boss, the wait winning the battle", [enemy.dead?, $won], [true, []])
$waiting = false
BattleManager.instance_variable_set(:@phase, nil)

# A change of the boss's max HP, such as a state that lowers it, is no damage.
reset
start([[:battle, 71], [:mark, :after]])
$scene.start_party_command_selection
$data_enemies[1].params[0] = 400
enemy.hp = 3000
next_turn
check("a boss whose max HP halves, taking its HP down with it, reports nothing", [reports, enemy.mhp], [[], 3000])
enemy.hp = 1500
next_turn
check("and what it loses afterwards counts against the new max", reports.map { |_key, _battle, text| text }, ["1\t0.5000000000\t3000\t0"])
$data_enemies[1].params[0] = 800
next_turn
check("a max HP back up reports nothing, and the boss takes the pool's share of it", [reports.size, enemy.hp], [1, 3000])

# A max HP the game lowers without taking the HP down, as the higher difficulties' boss rate the
# battle's start sets, heals no pool.
reset
push("Queen Harpy", "0.75")
start([[:battle, 71], [:mark, :after]])
$scene.start_party_command_selection
$data_enemies[1].params[0] = 400
next_turn
check("a boss whose max HP halves under its HP reports nothing, and takes the pool's share of the new max", [reports, enemy.hp], [[], 2250])
$data_enemies[1].params[0] = 800

# Small changes of the DLL's line in a row count once they add up beyond LINE_TOLERANCE.
reset
$state = "world=w1\n\nQueen Harpy\t0.9\t6000\t0\t\n"
ticks
$state = "world=w1\n\nQueen Harpy\t0.8996\t6000\t0\t\n"
ticks
check("a line within LINE_TOLERANCE of the last one taken tells nothing new", pool.pool("Queen Harpy").left, 0.9)
$state = "world=w1\n\nQueen Harpy\t0.8992\t6000\t0\t\n"
ticks
check("the next small change counts against the last line taken, so the two add up", pool.pool("Queen Harpy").left, 0.8992)

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
push("Queen Harpy", "1")
pool.start_side(71, "100,100,0")
check("another side battle of that boss gives none", [BattleManager.enable_get_exp?, BattleManager.enable_get_gold?, BattleManager.enable_get_drop?], [false, false, false])
$game_map.interpreter.clear
BattleManager.battle_end(2)
BattleManager.retry_battle
check("nor does its retry, which is a side battle too", [pool.side_battle?(71), BattleManager.enable_get_exp?], [true, false])
BattleManager.battle_end(1)
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
pool.start_side(71, "100,100,0")
check("the notes of another world count for nothing", BattleManager.enable_get_exp?, true)
check("a side battle's invite tells it is one", pool.invite_fields, { "pool" => 1, "side" => 1 })
BattleManager.battle_end(1)
pool.note_rewarded("Queen Harpy")
pool.note_invite("troop" => "71", "pool" => "1", "side" => "1")
$role = :guest
BattleManager.setup(71)
$game_troop.setup_battle_event
check("a guest of a side battle fights a side battle too: no troop pages, no rewards again",
      [pool.fight.side, pool.side_battle?(71), $pages_run, BattleManager.enable_get_exp?], [true, true, [], false])
BattleManager.battle_end(1)
pool.note_invite("troop" => "71", "pool" => "1")
BattleManager.setup(71)
check("a guest of a boss's event battle does not", [pool.fight.side, BattleManager.enable_get_exp?], [false, true])

# The World overview reads the pools as a copy, and their shares, labels and boss keys.
reset
push("Queen Harpy", "0.4", "6000")
pools = pool.pools
check("pools lists what the relay told, by key", [pools.keys, pools["Queen Harpy"].left, pools["Queen Harpy"].max], [["Queen Harpy"], 0.4, 6000])
pools["Other"] = :nothing
check("as a copy, so a reader changes nothing", pool.pools.keys, ["Queen Harpy"])
check("the share left now, a troop's label and a pool's boss key stay readable from outside",
      [pool.left_now(pools["Queen Harpy"]), pool.troop_label(71), pool.boss_key("Metatronne and Sandalphone#1")], [0.4, "Queen Harpy", "Metatronne and Sandalphone"])

# The battle server: the starter hands it the battle's fight and pools, and it fights them as host.
reset
push("Queen Harpy", "0.5", "6000")
start([[:battle, 71], [:mark, :after]])
fields = pool.served_fields
check("the starter hands the battle server how many enemies fight, whether it is a side battle, and the pools as it knows them",
      [fields[0], fields[1], fields[2].map { |key, left, max, defeated, by| [key, left.to_f, max, defeated, by] }], [1, 0, [["Queen Harpy", 0.5, 6000, 0, ""]]])
BattleManager.battle_end(1)
check("a battle that fights no pool hands it nothing", pool.served_fields, nil)
reset
BattleManager.setup(71)
check("on the server, a battle no event started fights no pool by itself", pool.fight, nil)
pool.serve_fight(71, fields)
check("the server fights the starter's pools as host, its enemy at the pool's HP",
      [pool.fight.key, pool.fight.guest, enemy.mhp, enemy.hp], ["Queen Harpy", false, 6000, 3000])
$scene.start_party_command_selection
enemy.hp = 2400
next_turn
check("and reports what the battle dealt", reports.map { |key, _battle, text| [key, text] }, [["Queen Harpy", "1\t0.1000000000\t6000\t0"]])
BattleManager.battle_end(1)
reset
BattleManager.setup(71)
pool.serve_fight(71, ["1", 0, []])
check("a count that is no number fights no pool", pool.fight, nil)
