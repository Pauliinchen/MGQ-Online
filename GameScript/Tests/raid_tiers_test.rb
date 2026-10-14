#----------------------------------------------------------------
#  raid_tiers_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-13: Created
#
#----------------------------------------------------------------

# Covers battles_raid_tiers.rbx with battles_raid_bosses.rbx and battles_raid_pool.rbx: when the
# story bosses fight as raid bosses outside Raid Worlds, which battles fight at their tier and with
# what stats, the game's retry, the invites of co-op battles, the relay's push of a Classic world's
# setting and the setting of single player, whose Mod Config row ui_single_player.rbx adds. Events
# run in fibers as the game's interpreter runs them.

require_relative "support"

# Stands in for the mod's base script, whose log prints each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$calls = []
$routes = {}
$notices = []
$options = []
$takes = []
$settings = {}
$raid = false
$in_world = false
$raid_bosses = false

# The DLL, whose calls are noted in $calls.
module MGQ_Multiplayer
  # Stands in for the DLL link.
  module Link
    # A function of the DLL, which notes its calls.
    Function = Struct.new(:name) do
      # Notes the call in $calls, refusing arguments its signature does not name.
      #
      # @param args [Array] The arguments.
      # @return [Integer] 1, the DLL took the call.
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, args]
        1
      end
    end
    # Answers a function of the DLL.
    def self.function(name); Function.new(name); end
    # Answers that the DLL knows no pools.
    def self.read(_name, _size); ""; end
  end
  # Stands in for Player.ini, its settings in $settings.
  module Player
    # Reads a setting.
    def self.setting(key); $settings[key]; end
    # Keeps a setting as text.
    def self.store(key, value); $settings[key] = value.to_s; true; end
  end
end
# Stands in for the world's sync: its routes in $routes, its notices in $notices, in a world while
# $in_world.
module MGQ_MpOverworldSync
  # The field of the relay's push of a pool.
  BOSS_FIELD = "boss_key"
  # The field of the relay's push of a Classic world's raid bosses.
  RAID_BOSSES_FIELD = "raid_bosses_value"
  # Keeps a field's handler in $routes.
  def self.route(field, &block); $routes[field] = block; end
  # Takes no frame blocks.
  def self.on_tick(&_block); end
  # Takes no state fields.
  def self.state_fields(&_block); end
  # Answers whether the player is in a world: $in_world.
  def self.in_world?; $in_world; end
  # Notes a notice's text in $notices.
  def self.notice(text, _icon = nil); $notices << text; end
end
# Stands in for the open world: a Classic world with raid bosses while $raid_bosses, which takes
# the relay's word only in a Classic world, noting each in $takes.
module MGQ_MpWorld
  # Answers whether the open Classic world fights raid bosses: $raid_bosses.
  def self.raid_bosses?; $raid_bosses; end
  # Takes whether the open Classic world fights raid bosses.
  #
  # @param on [Boolean] Whether it does.
  # @return [Boolean] Whether a Classic world is open to take it.
  def self.take_raid_bosses(on)
    $takes << on
    return false unless $in_world && !$raid

    $raid_bosses = on
    true
  end
end
# Stands in for the Mod Config's rows, noting each in $options.
module MGQ_MpUi
  # The first words of the rows of the single player settings.
  SP_PREFIX = "[MGQ Online SP] "
  # Notes a row with its name after the prefix, its key and its procs.
  def self.add_option(key, name, _help, values, read, write, prefix = "[MGQ Online Settings] ")
    $options << { :key => key, :name => prefix + name, :values => values, :read => read, :write => write }
    true
  end
end
# Stands in for the co-op scope, in a Raid World while $raid is set.
module MGQ_MpCoop; module Scope; def self.raid?; $raid; end; end; end
# Stands in for the story of world w1, active while $raid is set.
module MGQ_MpWorldStory
  # Answers whether the world's story is active: $raid.
  def self.active?; $raid; end
  # Answers that the player plays the world's story.
  def self.mode; :world; end
  # Answers the world's id.
  def self.world_id; "w1"; end
end
# Stands in for the chat log, which keeps nothing.
module MGQ_MpChat; def self.system(_text); end; end
# Stands in for the notification box, which keeps nothing.
module MGQ_MpNotices; def self.message(_key, _text, _frames); end; end
# Stands in for the live battle, the player alone in it.
module MGQ_MpBattlesSync
  # Answers that the player plays no role in a live battle.
  def self.role; nil; end
  # Stands in for the host's wait for the other players' commands, which never waits.
  module Waiting; def self.active?; false; end; end
end
# Stands in for the co-op battles' enemy rates.
module MGQ_MpBattlesCoop; def self.rates_text; "100,100,0"; end; end

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

# An enemy of the database: its max HP, defense and magic defense.
EnemyData = Struct.new(:name, :mhp, :def, :mdf)
# An enemy of a troop of the database.
TroopMember = Struct.new(:enemy_id)
# A troop of the database, without battle event pages.
TroopData = Struct.new(:members, :pages)
$data_enemies = []
{ 1 => ["Queen Harpy", 800, 40], 2 => ["Alma Elma", 1000, 60], 3 => ["Granberia", 1000, 70], 6 => ["Slime", 100, 10], 7 => ["Eden", 1000, 80],
  9 => ["Chaos", 1000, 100] }.each { |id, (name, hp, defense)| $data_enemies[id] = EnemyData.new(name, hp, defense, defense) }
$data_troops = []
{ 71 => [1], 609 => [2], 610 => [3], 31 => [6], 1507 => [7], 2219 => [9] }.each do |id, enemies|
  $data_troops[id] = TroopData.new(enemies.map { |enemy| TroopMember.new(enemy) }, [])
end

# An enemy, whose HP the game keeps between 0 and its max and which dies at 0.
class Game_Enemy
  attr_reader :hp
  # Makes an enemy of the database with all its HP.
  def initialize(_index, enemy_id); @enemy_id = enemy_id; @dead = false; @hp = mhp; end
  # Answers the enemy's name in the database.
  def name; $data_enemies[@enemy_id].name; end
  # Answers the enemy's max HP in the database.
  def mhp; $data_enemies[@enemy_id].mhp; end
  # Answers the enemy's defense in the database.
  define_method(:def) { $data_enemies[@enemy_id].def }
  # Answers the enemy's magic defense in the database.
  def mdf; $data_enemies[@enemy_id].mdf; end
  # Sets the HP, kept between 0 and the max, and kills the enemy at 0.
  def hp=(value); @hp = [[value, mhp].min, 0].max; @dead = @hp == 0; end
  # Answers whether the enemy is dead.
  def dead?; @dead; end
end
# The battle's troop, made from the database's troop.
class Game_Troop
  attr_reader :members
  # Makes the troop's enemies.
  #
  # @param troop_id [Integer] The troop.
  def setup(troop_id)
    @members = $data_troops[troop_id].members.each_with_index.map { |member, index| Game_Enemy.new(index, member.enemy_id) }
  end
  # Answers whether every enemy is dead.
  def all_dead?; @members.all? { |enemy| enemy.dead? }; end
end
# The player's party, as far as it is in a battle.
class Game_Party; attr_accessor :in_battle; end

# The battle's start and end as the game's are: the event's battle command sets up a battle and
# hands its result back through event_proc, and the retry sets the lost battle up again.
module BattleManager
  # Sets a battle up.
  #
  # @param troop_id [Integer] The troop.
  def self.setup(troop_id, _can_escape = true, _can_lose = false)
    $game_troop.setup(troop_id)
    @troop_id = troop_id
  end
  # Takes the handler the battle's result goes to.
  def self.event_proc=(proc); @event_proc = proc; end
  # Ends the battle, handing its result to the event.
  def self.battle_end(result); @event_proc.call(result) if @event_proc; @event_proc = nil; $game_party.in_battle = false; end
  # Sets the lost battle up again.
  def self.retry_battle; setup(@troop_id); $game_party.in_battle = true; true; end
end
# The battle's scene, which the pools hook into.
class Scene_Battle
  # Answers whether the scene changes: never.
  def scene_changing?; false; end
  # Opens a command phase, doing nothing.
  def start_party_command_selection; end
  # Ends the turn, doing nothing.
  def turn_end; end
end
# Stands in for the game's scenes, without a scene.
module SceneManager
  # Stands in for starting the game, doing nothing.
  def self.run; end
  # Answers that no scene runs.
  def self.scene; nil; end
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

# The interpreter, with commands of the tests' own: [:battle, troop], [:call, list] for a common
# event and [:mark, label].
class Game_Interpreter
  attr_reader :event_id
  # Makes an interpreter.
  def initialize; clear; end
  # Forgets the event.
  def clear; @event_id = 0; @list = nil; @index = 0; @fiber = nil; end
  # Starts an event on the map in a fiber of its own.
  #
  # @param list [Array] Its commands.
  # @param event_id [Integer] The event, 0 for a common event.
  def setup(list, event_id = 0); clear; @event_id = event_id; @list = list; @fiber = Fiber.new { run } if @list; end
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
    kind, a = @list[@index]
    case kind
    when :battle then @params = [0, a, false, false]; command_301
    when :call then child = Game_Interpreter.new; child.setup(a, @event_id); child.run
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
load_script "battles_raid_tiers"
SceneManager.run

tiers = MGQ_MpRaidTiers
pool = MGQ_MpRaidPool

# Starts the game's objects anew and forgets every battle, outside a world with the single player
# setting off.
def reset
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_troop = Game_Troop.new
  $game_party = Game_Party.new
  $game_map = Game_Map.new
  $game_system = Game_System.new
  MGQ_MpRaidPool.forget
  MGQ_MpRaidTiers.forget
  MGQ_MpRaidTiers.instance_variable_set(:@single_player, nil)
  [$calls, $notices, $takes].each(&:clear)
  $ran = []
  $settings = {}
  $raid = false
  $in_world = false
  $raid_bosses = false
end

# Runs frames of the map, as Scene_Map does.
def frames
  $game_map.update(true)
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

# Tells the battle whose boss fights at its tier as plain values.
#
# @return [Array, nil] Its troop, own enemies and tier; nil for none.
def tiered
  fight = MGQ_MpRaidTiers.fight
  fight ? fight.to_a : nil
end

# Asks for the invite's fields of a battle about to be set up by an event's battle command.
#
# @param troop [Integer] The troop.
# @return [Hash] The fields.
def event_invite(troop)
  $game_map.interpreter.instance_variable_set(:@event_id, 7)
  MGQ_MpRaidTiers.in_map { MGQ_MpRaidTiers.at_command { MGQ_MpRaidTiers.invite_fields(troop) } }
end

# Has the relay, or someone else, push a Classic world's raid bosses.
#
# @param value [String] "1" or "0".
# @param relay [Boolean] Whether the relay pushes it.
def push(value, relay = true)
  message = { MGQ_MpOverworldSync::RAID_BOSSES_FIELD => value }
  message[:relay] = true if relay
  $routes[MGQ_MpOverworldSync::RAID_BOSSES_FIELD].call(nil, message)
end

# The setting of single player, and the relay's push.
reset
check("single player's raid bosses are off at first", tiers.single_player?, false)
tiers.choose(true)
check("turned on, Player.ini keeps it", [$settings["sp_raid_bosses"], tiers.single_player?], ["1", true])
tiers.choose(false)
check("and off again", [$settings["sp_raid_bosses"], tiers.single_player?], ["0", false])
check("its Mod Config row is left to ui_single_player.rbx", $options.any? { |option| option[:key] == tiers::OPTION }, false)
check("the relay's push of a Classic world's raid bosses has its route", $routes.key?(MGQ_MpOverworldSync::RAID_BOSSES_FIELD), true)

# When the story bosses fight as raid bosses.
reset
check("outside a world they are off until the player turns them on", tiers.active?, false)
$settings["sp_raid_bosses"] = "1"
tiers.instance_variable_set(:@single_player, nil)
check("Player.ini's setting turns them on", tiers.active?, true)
$raid = true
$in_world = true
$raid_bosses = true
check("never in a Raid World, whose pools are its own, whatever the world or single player say", tiers.active?, false)
$raid = false
check("a Classic world with them turns them on", tiers.active?, true)
tiers.choose(false)
check("whatever single player says", tiers.active?, true)
$raid_bosses = false
tiers.choose(true)
check("and one without them keeps them off, whatever single player says", tiers.active?, false)

# A story boss's last phase fights at its tier.
reset
tiers.choose(true)
start([[:battle, 71], [:mark, :after]])
check("an event's battle of a story boss's last phase fights at its tier, its own enemies counted", tiered, [71, 1, 9])
check("its enemy has the tier's factor of its max HP, all of it", [enemy.mhp, enemy.hp], [4000, 4000])
check("and fights no pool", pool.fight, nil)
enemy.hp = 1000
BattleManager.battle_end(0)
frames
check("a won battle is over, and the event goes on", [tiers.fight, $ran, $branch], [nil, [:after], 0])
reset
$in_world = true
$raid_bosses = true
start([[:battle, 71]])
check("a Classic world with raid bosses fights them too", tiered, [71, 1, 9])

# Battles that keep the boss as the game has it.
{
  "with the raid bosses off" => proc { tiers.choose(false) },
  "a Hades rematch" => proc { $game_switches[MGQ_MpRaidPool::HADES_SWITCH] = true },
  "an event of the Hades rematch hall" => proc { $game_map.map_id = MGQ_MpRaidPool::HADES_MAP },
  "a Colosseum battle" => proc { $game_switches[MGQ_MpRaidPool::COLOSSEUM_SWITCH] = true },
  "a boss the story beat" => proc { $game_variables[1011] = 4 },
  "a Raid World's battle" => proc { $raid = true; $in_world = true; $raid_bosses = true },
}.each do |label, set|
  reset
  tiers.choose(true)
  set.call
  start([[:battle, 71]])
  check("#{label} keeps the boss as the game has it", tiered, nil)
end
check("which fights the pool instead", pool.fight && pool.fight.key, "Queen Harpy")
reset
tiers.choose(true)
lines = logged_lines { start([[:battle, 1507]]) }
check("the Great Decision keeps its boss, and the log says why",
      [tiered, lines.any? { |line| line.include?("troop 1507 keeps its boss as the game has it: a fight raid bosses leave out") }], [nil, true])
reset
tiers.choose(true)
start([[:battle, 71]], 0)
check("so does a common event of its own", tiered, nil)
reset
tiers.choose(true)
BattleManager.setup(71)
check("and a battle no event command started", tiered, nil)
reset
tiers.choose(true)
start([[:battle, 31]])
check("a troop that is no story boss keeps its enemies", [tiered, enemy.mhp], [nil, 100])

# A fight of several phases fights at its tier on its last; one in a common event the event calls too.
reset
tiers.choose(true)
start([[:battle, 609], [:battle, 610]])
check("an earlier phase keeps its boss", [tiered, enemy.mhp], [nil, 1000])
BattleManager.battle_end(0)
frames
check("the last phase fights at its tier", [tiered, enemy.mhp], [[610, 1, 7], 15000])
reset
tiers.choose(true)
start([[:call, [[:battle, 71]]]])
check("a boss battle in a common event the event calls fights at its tier", tiered, [71, 1, 9])

# The game's retry of a lost battle fights at the tier again.
reset
tiers.choose(true)
start([[:battle, 71]])
enemy.hp = 100
$game_map.interpreter.clear
BattleManager.battle_end(2)
check("a lost battle is over", tiered, nil)
check("its retry's invite says it fights at its tier", tiers.retrying { tiers.invite_fields(71) }, { "tiers" => 1 })
BattleManager.retry_battle
check("the retry fights at its tier again, the boss at full HP", [tiered, enemy.mhp, enemy.hp], [[71, 1, 9], 4000, 4000])
BattleManager.battle_end(1)
BattleManager.retry_battle
check("but not the retry of a battle escaped from", tiered, nil)

# Stats: the tier's factors apply to the battle's own enemies alone.
reset
tiers.choose(true)
start([[:battle, 2219]])
chaos = enemy
check("a tier 0 boss gets 50 times its max HP and 5 times both defenses", [tiered, chaos.mhp, chaos.hp, chaos.def, chaos.mdf], [[2219, 1, 0], 50000, 50000, 500, 500])
other = Game_Enemy.new(0, 9)
check("an enemy outside the battle keeps its own", [other.mhp, other.def, tiers.stat(other, :def, 100)], [1000, 100, 100])
reset
tiers.choose(true)
start([[:battle, 71]])
check("a tier that names no defense leaves it", [enemy.def, enemy.mdf, tiers.stat(enemy, :def, 40)], [40, 40, 40])

# Co-op battles: the invite says whether the boss fights at its tier, and a guest follows it.
reset
tiers.choose(true)
check("the invite of an event's battle of a boss at its tier says so", event_invite(71), { "tiers" => 1 })
check("one of an earlier phase, a troop that is no boss or a battle no event started says nothing",
      [event_invite(609), event_invite(31), tiers.invite_fields(71)], [{}, {}, {}])
tiers.choose(false)
check("nor while the raid bosses are off", event_invite(71), {})
tiers.choose(true)
$raid = true
check("nor in a Raid World", event_invite(71), {})
reset
tiers.note_invite("troop" => "71", "tiers" => "1")
check("the leader of a battle a member's request marked invites the others with it too", tiers.invite_fields(71), { "tiers" => 1 })
BattleManager.setup(71)
check("a guest of an invite that says so fights at the tier, even with the raid bosses off itself", [tiered, enemy.mhp, enemy.hp], [[71, 1, 9], 4000, 4000])
reset
tiers.note_invite("troop" => "71")
BattleManager.setup(71)
check("an invite that says nothing keeps the boss", tiered, nil)
reset
tiers.choose(true)
start([[:battle, 71]])
check("a fight left over on the map, as a refused lead leaves it, labels no later battle of its troop", tiers.invite_fields(71), {})
battle_scene = Scene_Battle.new
SceneManager.define_singleton_method(:scene) { battle_scene }
check("a member who hosts its battle at its start, once the leader would not lead it, still invites with the tier",
      [tiers.invite_fields(71), tiers.invite_fields(72)], [{ "tiers" => 1 }, {}])
SceneManager.define_singleton_method(:scene) { nil }
reset
tiers.note_invite("troop" => "71", "tiers" => "1")
BattleManager.setup(610)
check("so does one of another troop", tiered, nil)
reset
$raid = true
tiers.note_invite("troop" => "71", "tiers" => "1")
$raid = false
BattleManager.setup(71)
check("an invite noted in a Raid World is ignored", tiered, nil)

# A guest's troop built anew from its host's gets the tier's max HP at once.
reset
tiers.note_invite("troop" => "71", "tiers" => "1")
BattleManager.setup(71)
rebuilt = [Game_Enemy.new(0, 1)]
rebuilt[0].hp = 400
$game_troop.instance_variable_set(:@members, rebuilt)
tiers.rescale
check("a troop built anew gets the tier's max HP, keeping its share", [enemy.mhp, enemy.hp], [4000, 2000])
tiers.forget
tiers.rescale
check("and nothing happens outside such a battle", enemy.mhp, 800)

# The title screen forgets every battle.
reset
tiers.choose(true)
start([[:battle, 71]])
$game_map.interpreter.clear
BattleManager.battle_end(2)
Scene_Title.new.start
BattleManager.retry_battle
check("the title screen forgets the lost battle", tiered, nil)

# The relay's push of a Classic world's raid bosses.
reset
$in_world = true
push("1", false)
check("a push not from the relay is ignored", [$takes, $notices], [[], []])
push("1")
check("the relay's push turns them on in a Classic world and tells the player", [$takes, $raid_bosses, $notices], [[true], true, ["The world's story bosses fight as raid bosses now."]])
push("1")
check("the same value again changes nothing", [$takes.size, $notices.size], [1, 1])
push("0")
check("and off", [$raid_bosses, $notices.last], [false, "The world's story bosses fight as usual now."])
push("2")
push("")
check("a value that is neither is ignored", [$takes.size, $notices.size], [2, 2])
$raid = true
push("1")
check("a Raid World takes none and tells nothing", [$raid_bosses, $notices.size], [false, 2])
