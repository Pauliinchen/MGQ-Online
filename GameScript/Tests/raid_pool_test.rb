#----------------------------------------------------------------
#  raid_pool_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Covered the boss fights whose events change the party, which fall back with the party as it was
#                            - Covered the companions that join after the battle, the personas put back without marking them owned and the items a replay gives again
#                            - Created
#
#----------------------------------------------------------------

# Covers battles_raid_pool.rbx with battles_raid_bosses.rbx: which battles count against a raid
# boss's pool, the share of a kill a battle reports, a boss that falls back (its event ends and
# what it set before the battle is put back), one whose pool the battle emptied, a relay that does
# not answer, the last phase of a fight of several, a lost battle and the game's retry, and the
# relay's push, and the autosave a won retry holds. Events run in fibers as the game's interpreter runs them.
# The boss events that put the party together anew (a temporary party, companions added, a persona
# changed, a larger party, split parties joined or split) fall back with the party as it was, and
# without the copies of the items a replay of their event gives again.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$calls = []
$state = ""
$report_result = 1
$chat = []
$notices = []
$routes = {}
$ran = []
$raid = true
$mode = :world

# The DLL: each call is noted, and the pools' state is what $state holds.
module MGQ_Multiplayer
  module Link
    # A function of the DLL, which notes its calls without their null bytes.
    Function = Struct.new(:name) do
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, args.map { |arg| arg.is_a?(String) ? arg.chomp("\0") : arg }]
        $report_result
      end
    end
    def self.function(name); Function.new(name); end
    def self.read(name, size); check_dll_call(name, ["", size]); $state.dup.force_encoding("ASCII-8BIT"); end
    def self.parse(text)
      head, payload = text.force_encoding("UTF-8").split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| key, value = line.split("=", 2); state[key] = value if value }
      state
    end
  end
end
module MGQ_MpOverworldSync
  BOSS_FIELD = "boss_key"
  def self.route(field, &block); $routes[field] = block; end
end
module MGQ_MpCoop; module Scope; def self.raid?; $raid; end; end; end
module MGQ_MpWorldStory
  PROGRESS_VARIABLES = [1001, 1003, 1011, 1141, 1142, 1143]
  PROGRESS_SWITCHES = [2485, 7096]
  def self.active?; $raid; end
  def self.mode; $mode; end
  def self.world_id; "w1"; end
end
module MGQ_MpNotices
  def self.message(_key, text, _frames = 180); $notices << text; end
  def self.drop(_key, _reason = nil); $notices << :dropped; end
end
module MGQ_MpChat; def self.system(text); $chat << text; end; end
module MGQ_MpBattlesSync; def self.guest?; $guest; end; end

# The game's story values, as the game keeps them.
class Game_Switches
  def initialize; @data = []; end
  def [](id); @data[id] || false; end
  def []=(id, value); @data[id] = value; end
end
class Game_Variables
  def initialize; @data = []; end
  def [](id); @data[id] || 0; end
  def []=(id, value); @data[id] = value; end
end
class Game_SelfSwitches
  def initialize; @data = {}; end
  def [](key); @data[key] == true; end
  def []=(key, value); @data[key] = value; end
end

# The enemies of a battle, by troop: their names and max HP, and whether they have not appeared.
Enemy = Struct.new(:name, :mhp, :hp, :hidden) do
  def hidden?; hidden ? true : false; end
end
class Game_Troop
  attr_reader :members
  def setup(troop_id); @members = ($troops[troop_id] || [["Slime", 100]]).map { |name, mhp| Enemy.new(name, mhp, mhp) }; end
end

# The characters' database entries: a main persona (:original) lists its other personas (:sub).
ActorData = Struct.new(:id, :persona_kind, :original_persona_id, :name)
$data_actors = []
(1..8).to_a.concat([41, 53, 683]).each { |id| $data_actors[id] = ActorData.new(id, :none, id, "Actor #{id}") }
{ 9 => [909, "Micaela"], 20 => [21, "Twenty"], 40 => [400, "Forty"] }.each do |id, (sub, name)|
  $data_actors[id] = ActorData.new(id, :original, id, name)
  $data_actors[sub] = ActorData.new(sub, :sub, id, "Other #{name}")
end

# A character, kept under its main persona's id whichever persona it shows, as the game's, with its
# equipment and the stones in it.
class Game_Actor
  attr_accessor :name, :nickname
  attr_reader :character_name, :character_index, :face_name, :face_index
  def initialize(id); @actor_id = id; init_looks; end
  def id; @actor_id; end
  def luca?; @actor_id == 1; end
  def persona_change(persona_id)
    return if $data_actors[persona_id].persona_kind == :none
    @actor_id = persona_id
    init_looks
  end
  def init_looks
    @name = $data_actors[@actor_id].name
    @nickname = ""
    set_graphic(@name.downcase, 0, @name.downcase, 0)
  end
  def set_graphic(character_name, character_index, face_name, face_index)
    @character_name, @character_index, @face_name, @face_index = character_name, character_index, face_name, face_index
  end
  def equips; @equips ||= []; end
  def change_equip(slot_id, item)
    return unless $game_party.trade_item(item, equips[slot_id])
    equips[slot_id] = item
  end
  def change_stone(slot_id, stone_slot_id, stone)
    stones = ((@stones ||= {})[slot_id] ||= [])
    return unless $game_party.trade_item(stone, stones[stone_slot_id])
    stones[stone_slot_id] = stone
  end
end

# The game's items, weapons and armors, each an entry of its own.
ItemData = Struct.new(:kind, :id)
$data_items, $data_weapons, $data_armors = [], [], []
[[$data_weapons, :weapon, [7, 4832]], [$data_armors, :armor, [861]], [$data_items, :item, [2104, 3060]]].each do |data, kind, ids|
  ids.each { |id| data[id] = ItemData.new(kind, id) }
end
class Game_Actors
  def initialize; @data = []; end
  def original_id(id)
    actor = $data_actors[id]
    return nil unless actor
    actor.persona_kind == :sub ? actor.original_persona_id : id
  end
  def [](id); original = original_id(id); original && (@data[original] ||= Game_Actor.new(original)); end
end

# The party's lists of characters, by main persona; the team's lists are cut to the party size.
class Member
  include Enumerable
  def initialize(data = []); @data = []; set(data); end
  def set(ary); @data = ary.map { |id| $game_actors.original_id(id) }.compact.uniq; end
  def push(*ids); set(@data + ids); end
  def delete(*ids); ids.each { |id| @data.delete($game_actors.original_id(id)) }; end
  def each(&block); @data.each(&block); end
  def clear; @data.clear; end
  def empty?; @data.empty?; end
end
class BattleMember < Member
  def set(ary); before = @data.clone; super; refresh if before != @data; end
  def delete(*ids); before = @data.clone; super; refresh if before != @data; end
  def clear; before = @data.clone; super; refresh if before != @data; end
  def refresh; @data = @data.slice(0, $game_party.party_member_max); end
end

# The formation of a Raid World: the team of four while the cap holds, never for a temporary party.
module MGQ_MpCoopSquad
  def self.party_member_max(party, max); $capped && !party.temp_actors_use? ? [max, 4].min : max; end
  def self.fit_team(raid); $fits << raid; $capped = raid && !$game_party.temp_actors_use?; end
end

# The game's split parties, each with its characters, map and place, and the one played.
module MultiParty
  Split = Struct.new(:member, :map_id, :position)
  class Structs
    attr_reader :id
    def initialize; @id = 0; @data = []; end
    def clear(size); @data = Array.new(size) { Split.new([], -1, [0, 0, 2]) }; end
    def data; @data[@id]; end
    def [](id); @data[id]; end
    def reset; @id = 0; end
    def setup(id, pos); return unless @data[id]; @data[id].map_id = pos[0]; @data[id].position = pos[1..-1]; end
    def start
      $game_player.reserve_transfer(data.map_id, *data.position)
      $game_party.reserve_member = data.member
    end
  end
end

# The party, as the game's keeps its team, the companions owned, a story's temporary party, the
# personas that party changed, the split parties and the bag; a persona the party changes to is
# marked owned, as the game's system save marks it.
class Game_Party
  attr_accessor :in_battle, :reserve_member
  def initialize; @actors = BattleMember.new; @temp_actors = BattleMember.new; @include_actors = Member.new; end
  def actors; temp_actors_use? ? @temp_actors : @actors; end
  def temp_actors_use?; !@temp_actors.empty?; end
  def party_member_max; MGQ_MpCoopSquad.party_member_max(self, 8 + $game_variables[56]); end
  def party_member_full?; party_member_max <= actors.to_a.size; end
  def add_actor(id); @include_actors.push(id); @actors.push(id); end
  def remove_actor(id); @include_actors.delete(id); @actors.delete(id); end
  def move_stand_actor(id); @actors.delete(id); end
  def persona_change(persona_id)
    actor = $data_actors[persona_id]
    return if actor.nil? || actor.persona_kind == :none
    $game_actors[actor.original_persona_id].persona_change(persona_id)
    $owned << persona_id
  end
  def bag; @bag ||= Hash.new(0); end
  def item_number(item); bag[item]; end
  def gain_item(item, amount); bag[item] = [bag[item] + amount, 0].max if item; end
  def lose_item(item, amount); gain_item(item, -amount); end
  def trade_item(new_item, old_item)
    return false if new_item && item_number(new_item) == 0
    gain_item(old_item, 1)
    lose_item(new_item, 1)
    true
  end
  def set_temp_actors(ids); load_persona(@temp_actors.to_a); @temp_actors.set(ids); save_persona(ids); end
  def add_temp_actors(ids); @temp_actors.push(*ids); save_persona(ids); end
  def release_temp_actors; @temp_actors.clear; end
  def load_persona(ids)
    return if multi_party? || !@bpersona
    @bpersona.each { |id, persona| persona_change(persona) if ids.include?(id) }
    ids.each { |id| @bpersona.delete(id) }
  end
  def save_persona(ids)
    return if multi_party?
    @bpersona ||= {}
    ids.select { |id| $game_actors[id].id != id }.each { |id| @bpersona[id] = $game_actors[id].id; persona_change(id) }
  end
  def multi_party; @multi_party ||= MultiParty::Structs.new; end
  def multi_party?; @multi_party_flag; end
  def setup_multipartymember(parties); multi_party.clear(parties.size); parties.each_with_index { |ids, i| multi_party[i].member = ids }; end
  def start_multiparty(*places)
    return if multi_party?
    places.each_with_index { |place, i| multi_party.setup(i, place) }
    @multi_party_flag = true
    multi_party.reset
    multi_party.start
  end
  def end_multiparty
    return unless multi_party?
    multi_party.clear(0)
    @multi_party_flag = false
    release_temp_actors
  end
end

# The game's command that adds a companion: a full team sends its last companion but Luka to standby,
# as the player would choose.
def add_actor_ex(id)
  $game_party.persona_change(id)
  return if $game_party.actors.include?(id)
  if $game_party.party_member_full?
    stand = $game_party.actors.to_a.reject { |member| member == 1 }.last
    $game_party.move_stand_actor(stand) if stand
  end
  $game_party.add_actor(id)
end

$troops = { 609 => [["Alma Elma", 1000]], 610 => [["Granberia", 1000]], 1507 => [["Eden", 1000]],
            2017 => [["EX-Kyubi", 500]], 1509 => [["Morrigan", 400], ["Astaroth", 600]] }
$troops[71] = [["Queen Harpy", 800]]

# The battle's start and end as the game's are: the event's battle command sets up a battle and
# hands its result back through event_proc, the retry sets the lost battle up again.
module BattleManager
  def self.setup(troop_id, _can_escape = true, _can_lose = false); $game_troop.setup(troop_id); @troop_id = troop_id; end
  def self.event_proc=(proc); @event_proc = proc; end
  def self.battle_end(result); @event_proc.call(result) if @event_proc; @event_proc = nil; $game_party.in_battle = false; end
  def self.retry_battle; setup(@troop_id); $game_party.in_battle = true; true; end
end
module SceneManager; def self.run; end; end
module DataManager; def self.auto_save_game; $saves += 1; true; end; end

# The sounds playing, as the game's RPG::BGM and RPG::BGS keep the last one played.
module RPG
  class BGM
    class << self; attr_accessor :last; end
    attr_reader :name
    def initialize(name); @name = name; end
    def replay; self.class.last = self; end
  end
  class BGS < BGM; end
end

# How the map looks: the player, the followers, the pictures and the screen.
Game_System = Struct.new(:battle_bgm)
Followers = Struct.new(:visible)
Player = Struct.new(:transparent, :followers, :x, :y, :direction, :transfer) do
  def refresh; $player_refreshed = true; end
  def reserve_transfer(map_id, x, y, direction); self.transfer = [map_id, x, y, direction]; end
end
Picture = Struct.new(:number, :name) do
  def erase; self.name = ""; end
end
class Game_Screen
  attr_accessor :pictures, :tone, :brightness, :weather_type, :weather_power
  def initialize; @pictures = []; @tone = [0, 0, 0]; @brightness = 255; @weather_type = :none; @weather_power = 0; end
  def start_tone_change(tone, _duration); @tone = tone.clone; end
  def clear_fade; @brightness = 255; end
  def change_weather(type, power, _duration); @weather_type = type; @weather_power = power; end
end
class Scene_Title; def start; end; end

# A map event, which the boss's fall back unlocks, and erases when it starts by itself. A page block
# gives the trigger of the page it has once refreshed.
class Game_Event
  attr_reader :id, :trigger, :unlocked, :erased
  def initialize(id, trigger, &page); @id = id; @trigger = trigger; @page = page; end
  def refresh; @trigger = @page.call if @page; end
  def unlock; @unlocked = true; end
  def erase; @erased = true; end
end

# The map, whose interpreter runs as the game's does.
class Game_Map
  attr_accessor :map_id, :need_refresh, :events
  attr_reader :interpreter, :screen
  def initialize; @map_id = 5; @interpreter = Game_Interpreter.new; @events = {}; @screen = Game_Screen.new; end
  def update(main = false); update_interpreter if main; end
  def update_interpreter
    loop do
      @interpreter.update
      return if @interpreter.running?
      if @interpreter.event_id > 0
        unlock_event(@interpreter.event_id)
        @interpreter.clear
      end
      return
    end
  end
  def unlock_event(event_id); @events[event_id].unlock if @events[event_id]; end
end

# The interpreter, with commands of the tests' own: [:sw, id, value], [:var, id, value],
# [:self, key, value], [:battle, troop], [:call, list] for a common event, [:mark, label] and
# [:do, proc], and the game's script calls that give items and equip them at once.
class Game_Interpreter
  attr_reader :map_id, :event_id
  def initialize(depth = 0); @depth = depth; clear; end
  def clear; @map_id = 0; @event_id = 0; @list = nil; @index = 0; @fiber = nil; end
  def setup(list, event_id = 0); clear; @map_id = $game_map.map_id; @event_id = event_id; @list = list; @fiber = Fiber.new { run } if @list; end
  def run
    while @list[@index]
      execute_command
      @index += 1
    end
    Fiber.yield
    @fiber = nil
  end
  def running?; !@fiber.nil?; end
  def update; @fiber.resume if @fiber; end
  def execute_command
    kind, a, b = @list[@index]
    case kind
    when :sw then $game_switches[a] = b
    when :var then $game_variables[a] = b
    when :self then $game_self_switches[a] = b
    when :battle then @params = [0, a, false, false]; command_301
    when :call then child = Game_Interpreter.new(@depth + 1); child.setup(a, @event_id); child.run
    when :mark then $ran << a
    when :do then a.call
    end
  end
  def command_301
    return if $game_party.in_battle

    BattleManager.setup(@params[1], @params[2], @params[3])
    BattleManager.event_proc = Proc.new { |n| $branch = n }
    $game_party.in_battle = true
    Fiber.yield
  end
  def force_change_equip(actor_id, slot_id, equip_type, item_id)
    items = equip_type == 1 ? $data_weapons : $data_armors
    $game_party.gain_item(items[item_id], 1)
    $game_actors[actor_id].change_equip(slot_id - 1, items[item_id])
  end
  def change_actor_equip_stone(actor_id, equip_slot_id, *stone_ids)
    stone_ids.each_with_index do |stone_id, stone_slot_id|
      $game_party.gain_item($data_items[stone_id], 1)
      $game_actors[actor_id].change_stone(equip_slot_id, stone_slot_id, $data_items[stone_id])
    end
  end
end

load_script "battles_raid_bosses"
load_script "battles_raid_pool"

pool = MGQ_MpRaidPool
SceneManager.run

# Starts the game's objects anew and forgets every battle.
def reset
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_self_switches = Game_SelfSwitches.new
  $game_troop = Game_Troop.new
  $game_actors = Game_Actors.new
  $capped = true
  $game_party = Game_Party.new
  [1, 2, 3, 4, 5, 9, 20, 40, 41].each { |id| $game_party.add_actor(id) }
  $game_actors[9].persona_change(909)
  $game_actors[20].name = "Renamed Twenty"
  $game_actors[40].persona_change(400)
  $owned = []
  $fits = []
  $game_map = Game_Map.new
  $game_map.events[7] = Game_Event.new(7, 0)
  $game_system = Game_System.new("battle")
  $game_player = Player.new(false, Followers.new(true), 3, 4, 2, nil)
  RPG::BGM.last = RPG::BGM.new("field")
  RPG::BGS.last = RPG::BGS.new("")
  $player_refreshed = false
  $saves = 0
  MGQ_MpRaidPool.forget
  $calls.clear
  $chat.clear
  $notices.clear
  $ran.clear
  $state = ""
  $report_result = 1
  $raid = true
  $mode = :world
  $guest = false
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

# Wins the battle running: every enemy at 0 HP.
def win
  $game_troop.members.each { |enemy| enemy.hp = 0 }
  BattleManager.battle_end(0)
end

# Loses the battle running as the game's defeat does, which clears the map's interpreter first.
def lose
  $game_map.interpreter.clear
  BattleManager.battle_end(2)
end

# The reports sent: each one's key, battle id and share.
def reports
  $calls.select { |name, _| name == "mp_raid_boss_report" }.map { |_, args| args[1..3] }
end

# Has the relay answer the last report.
#
# @param hp [Numeric] The kills left.
# @param emptied [Boolean] Whether this battle emptied the pool.
# @param defeated [Boolean] Whether the boss is defeated.
def answer(hp, emptied = false, defeated = emptied)
  key, battle = reports.last
  $state = "world=w1\nreport=done\nreport_key=#{key}\nreport_battle=#{battle}\nreport_hp=#{hp}\nreport_dealt=1\n" \
           "report_emptied=#{emptied ? 1 : 0}\nreport_defeated=#{defeated ? 1 : 0}\nreport_repeat=0\n\n#{key}\t#{hp}\t5\t#{defeated ? 1 : 0}\n"
end

# The data.
rows = MGQ_MpRaidBosses::TROOPS.values.map { |row| [row[0], row[1]] }.uniq
check("every milestone has the markers that tell it beaten", rows - pool::BEATEN.keys, [])
check("and no markers name a milestone the boss table lacks", pool::BEATEN.keys - rows, [])
check("every fight of its own and every troop left out is a last phase",
      (pool::FIGHTS.keys + pool::UNPOOLED.keys).reject { |troop| MGQ_MpRaidBosses.at(troop).last }, [])
keys = MGQ_MpRaidBosses::TROOPS.keys.select { |troop| MGQ_MpRaidBosses.at(troop).last }.map { |troop| [pool.key_of(troop), MGQ_MpRaidBosses.at(troop).milestone, MGQ_MpRaidBosses.at(troop).cap] }
check("every last phase has a key the relay takes", keys.select { |key, _, _| key.nil? }, [])
shared = keys.group_by { |key, _, _| key }.select { |_, list| list.map { |_, milestone, cap| [milestone, cap] }.uniq.size > 1 }.keys
check("no two milestones share a pool", shared, [])
check("a name several milestones share carries the cap", [pool.key_of(1502), pool.key_of(1807), pool.key_of(71)], ["Tamamo (cap 61)", "Tamamo (cap 80)", "Queen Harpy"])
check("a fight of a free order has a pool of its own", [pool.key_of(2017), pool.key_of(2099)], ["EX-Kyubi", "Lustful Witch"])
reset
$game_switches[2594] = true
check("all conditions of an alternative must hold", pool.met?("s2594&v1142>=25"), false)
$game_variables[1142] = 25
check("then the test holds", pool.met?("s2594&v1142>=25"), true)
check("any alternative may hold", [pool.met?("v1141>=1|v1142>=1"), pool.met?("v1141>=1|v1143>=1")], [true, false])

# A won battle that leaves kills in the pool: the boss falls back.
reset
$game_switches[50] = true
$game_switches[60] = true
$game_map.interpreter.setup([[:sw, 50, false], [:var, 300, 9], [:self, [5, 7, "A"], true], [:battle, 71], [:mark, :after]], 7)
frames
check("a story boss's last phase counts against its pool", [$game_party.in_battle, pool.instance_variable_get(:@fight).key], [true, "Queen Harpy"])
win
key, battle, share = reports.last
check("the won battle reports a whole kill with its id", [key, share, battle =~ /\A[a-z0-9]{3,64}\z/ ? true : false], ["Queen Harpy", "1.000", true])
check("the report names the world", $calls.last[1][0], "w1")
check("and a notice tells the player the world is asked", $notices.last.start_with?("Telling the world how the battle against Queen Harpy went"), true)
frames(5)
check("the event holds while the relay has not answered", [$game_map.interpreter.running?, $ran], [true, []])
answer(4)
frames(15)
check("the boss falls back: the event ends without running on", [$game_map.interpreter.running?, $ran], [false, []])
check("what the event set before the battle is put back",
      [$game_switches[50], $game_variables[300], $game_self_switches[[5, 7, "A"]], MGQ_MpGame.get($game_self_switches, :data).key?([5, 7, "A"])], [true, 0, false, false])
check("what changed before the event started stays", $game_switches[60], true)
check("the event is unlocked and not erased", [$game_map.events[7].unlocked, $game_map.events[7].erased], [true, nil])
check("the player reads how much is left", [$notices.last, $chat.last], ["Queen Harpy falls back. Raid HP left: 4/5.", "Queen Harpy falls back. Raid HP left: 4/5."])
check("the map looks at its events again", $game_map.need_refresh, true)

# The same event again, whose battle empties the pool: the story goes on.
$calls.clear
start([[:sw, 50, false], [:battle, 71], [:mark, :after]])
win
answer(0, true)
frames(15)
check("the battle that empties the pool lets the event run on", [$ran, $game_switches[50], $game_map.interpreter.running?], [[:after], false, false])
check("and tells the world defeated the boss", $chat.last, "Queen Harpy is defeated for the whole world.")
check("the waiting notice goes", $notices.last, :dropped)

# A pool another battle emptied first lets the story go on too.
reset
start([[:battle, 71], [:mark, :after]])
win
answer(0, false, true)
frames(15)
check("a boss the world defeated already lets the event run on", [$ran, $chat.last], [[:after], "The world defeated Queen Harpy already."])

# A relay that does not answer never blocks the story.
reset
$report_result = 0
start([[:sw, 50, true], [:battle, 71], [:mark, :after]])
win
frames
check("a report the DLL did not start lets the event run on at once", [$ran, $game_switches[50]], [[:after], true])
reset
start([[:battle, 71], [:mark, :after]])
win
$state = "world=w1\nreport=failed\nreport_code=\nreport_error=The relay could not be reached.\nreport_key=Queen Harpy\nreport_battle=#{reports.last[1]}\n\n"
frames(15)
check("a report that failed lets the event run on", $ran, [:after])
reset
start([[:battle, 71], [:mark, :after]])
win
$state = "world=w1\nreport=busy\nreport_key=Queen Harpy\nreport_battle=#{reports.last[1]}\n\n"
frames(pool::WAIT_FRAMES - 5)
check("a report still running holds the event a while", $ran, [])
frames(10)
check("then the event runs on", $ran, [:after])
reset
start([[:battle, 71], [:mark, :after]])
win
$state = "world=w1\nreport=done\nreport_key=Queen Harpy\nreport_battle=someone-else\nreport_hp=3\nreport_emptied=0\nreport_defeated=0\n\n"
frames(20)
check("another battle's answer is not this one's", $game_map.interpreter.running?, true)

# Battles that never count.
reset
$raid = false
start([[:battle, 71], [:mark, :after]])
win
frames
check("a Classic world's battle reports nothing and runs on", [reports, $ran, pool.instance_variable_get(:@snapshot)], [[], [:after], nil])
{
  "a player whose story is in an earlier part" => proc { $mode = :own },
  "a Hades rematch" => proc { $game_switches[97] = true },
  "a Colosseum battle" => proc { $game_switches[87] = true },
  "a boss the story beat" => proc { $game_variables[1011] = 4 },
}.each do |label, set|
  reset
  set.call
  start([[:battle, 71], [:mark, :after]])
  win
  frames
  check("#{label} counts against no pool", [reports, $ran], [[], [:after]])
end
reset
start([[:var, 1001, 40], [:battle, 71], [:mark, :after]])
check("an event that moved the story's progress before the battle counts against no pool", pool.instance_variable_get(:@fight), nil)
reset
start([[:battle, 1507], [:mark, :after]])
check("the Great Decision counts against no pool", pool.instance_variable_get(:@fight), nil)
reset
start([[:battle, 71], [:mark, :after]], 0)
check("a common event of its own counts against no pool", pool.instance_variable_get(:@fight), nil)
reset
BattleManager.setup(71)
check("a battle no event command started, such as a co-op guest's, counts against no pool", pool.instance_variable_get(:@fight), nil)
reset
start([[:battle, 31], [:mark, :after]])
check("a troop that is no story boss counts against no pool", pool.instance_variable_get(:@fight), nil)
reset
start([[:battle, 71], [:mark, :after]])
$guest = true
win
frames
check("a battle whose starter became a guest of another player's reports nothing and runs on", [reports, $ran], [[], [:after]])

# A fight of several phases counts on its last.
reset
start([[:sw, 51, true], [:battle, 609], [:sw, 52, true], [:battle, 610], [:mark, :after]])
check("an earlier phase counts against no pool", pool.instance_variable_get(:@fight), nil)
win
frames
check("the last phase does", pool.instance_variable_get(:@fight).key, "Alma Elma, then Granberia")
win
answer(3.5)
frames(15)
check("a boss that falls back takes back what every phase's event set", [$game_switches[51], $game_switches[52], $ran], [false, false, []])
check("the kills left read as the player reads them", $chat.last, "Granberia falls back. Raid HP left: 3.5/5.")

# A battle in a common event ends the event that called it.
reset
start([[:sw, 53, true], [:call, [[:battle, 71], [:mark, :in_common_event]]], [:mark, :after]])
win
answer(2)
frames(15)
check("a boss in a common event ends the whole event", [$ran, $game_switches[53], $game_map.interpreter.running?], [[], false, false])

# An event that starts by itself would start again at once, so it is erased.
reset
$game_map.events[7] = Game_Event.new(7, pool::AUTORUN)
start([[:battle, 71], [:mark, :after]])
win
answer(4)
frames(15)
check("an event that starts by itself is erased until the map is entered again", $game_map.events[7].erased, true)
reset
$game_map.events[7] = Game_Event.new(7, 0) { $game_self_switches[[5, 7, "A"]] ? 0 : pool::AUTORUN }
start([[:self, [5, 7, "A"], true], [:battle, 71], [:mark, :after]])
win
answer(4)
frames(15)
check("an event whose page starts by itself once the story is put back is erased too", $game_map.events[7].erased, true)
reset
$game_map.events[7] = Game_Event.new(7, pool::AUTORUN) { $game_self_switches[[5, 7, "A"]] ? pool::AUTORUN : 0 }
start([[:self, [5, 7, "A"], true], [:battle, 71], [:mark, :after]])
win
answer(4)
frames(15)
check("and one whose page then waits for the player is not", $game_map.events[7].erased, nil)

# How the map looked as the event started comes back with the story.
reset
$game_map.screen.pictures << Picture.new(1, "map_sign")
stage = proc do
  $game_player.transparent = true
  $game_player.followers.visible = false
  $game_map.screen.pictures << Picture.new(5, "boss_cg")
  $game_map.screen.tone = [68, 0, 0]
  $game_map.screen.brightness = 0
  $game_map.screen.change_weather(:rain, 5, 0)
  $game_system.battle_bgm = RPG::BGM.new("boss_battle")
  RPG::BGM.last = RPG::BGM.new("boss_theme")
end
start([[:do, stage], [:battle, 71], [:mark, :after]])
win
answer(4)
frames(15)
screen = $game_map.screen
check("a boss that falls back shows the player and the followers again",
      [$game_player.transparent, $game_player.followers.visible, $player_refreshed], [false, true, true])
check("erases the pictures its event showed and keeps the others",
      screen.pictures.map { |picture| [picture.number, picture.name] }, [[1, "map_sign"], [5, ""]])
check("puts the screen back", [screen.tone, screen.brightness, screen.weather_type, screen.weather_power], [[0, 0, 0], 255, :none, 0])
check("and the music", [$game_system.battle_bgm, RPG::BGM.last.name], ["battle", "field"])

# The share of a kill a battle dealt.
reset
$game_troop.setup(71)
$game_troop.members[0].hp = 600
check("a boss with a quarter of its HP gone is a quarter of a kill", pool.dealt, 0.25)
$game_troop.setup(1509)
$game_troop.members[0].hp = 200
$game_troop.members[1].hp = 600
check("the enemies' HP lost counts as a share of the troop's HP", pool.dealt, 0.2)
$game_troop.members[1].hp = 0
check("so a helper that falls is no whole kill", pool.dealt, 0.8)
$game_troop.members[0].hp = 0
check("and a troop that falls is one", pool.dealt, 1.0)
$game_troop.members[0].hp = 200
$game_troop.members[1].hp = 600
$game_troop.members[1].hidden = true
check("an enemy that never appeared counts not", pool.dealt, 0.5)
check("an answer of 0 kills that defeated nothing holds",
      pool.outcome_of("report" => "done", "report_hp" => "0", "report_emptied" => "0", "report_defeated" => "0"), :holds)

# A lost battle reports what it dealt, and the game's retry counts again.
reset
start([[:sw, 54, true], [:battle, 71], [:mark, :after]])
$game_troop.members[0].hp = 400
lose
first = reports.last
check("a lost battle reports its share and holds nothing", [first[0], first[2], pool.instance_variable_get(:@pending)], ["Queen Harpy", "0.500", nil])
answer(4.5)
frames(15)
check("the chat tells how much the loss took", $chat.last, "Queen Harpy holds on. Raid HP left: 4.5/5.")
BattleManager.retry_battle
retried = pool.instance_variable_get(:@fight)
check("the retry counts again with an id of its own", [retried.key, retried.battle == first[1], retried.writes[0].key?(54)], ["Queen Harpy", false, true])
win
DataManager.auto_save_game
check("the autosave of a won retry waits for the relay", $saves, 0)
# The retry puts the interpreter back as the save at the battle's start had it, after the battle.
$game_map.interpreter.setup([[:mark, :after]], 7)
answer(4)
frames(15)
check("and is made once the boss fell back", $saves, 1)
check("a retried battle that leaves kills has the boss fall back too", [$ran, $game_switches[54], $chat.last], [[], false, "Queen Harpy falls back. Raid HP left: 4/5."])

# The relay's push.
reset
$routes["boss_key"].call(nil, { "boss_key" => "Queen Harpy", "hp" => "3", :relay => true })
check("a push of another battle tells the chat", $chat.last, "A raid battle against Queen Harpy ended. Raid HP left: 3/5.")
$routes["boss_key"].call(nil, { "boss_key" => "Queen Harpy", "hp" => "0", :relay => true })
check("a push of an empty pool tells the boss is defeated", $chat.last, "Queen Harpy is defeated for the whole world.")
$routes["boss_key"].call(nil, { "boss_key" => "Queen Harpy", "hp" => "5", :relay => true })
check("a push of a full pool, as an admin's reset sends, tells the boss stands again", $chat.last, "Queen Harpy stands again. Raid HP: 5/5.")
$chat.clear
$routes["boss_key"].call(nil, { "boss_key" => "Queen Harpy", "hp" => "1", "relay" => true })
check("a push no relay sent says nothing", $chat, [])
start([[:battle, 71], [:mark, :after]])
win
$routes["boss_key"].call(nil, { "boss_key" => "Queen Harpy", "hp" => "2", :relay => true })
check("the push of the player's own report says nothing new", $chat, [])

# Boss events that put the party together anew for their fight count, and their boss falls back
# with the party as the event found it.
check("only the Great Decision is left out of the pools", pool::UNPOOLED.keys, [1507, 1509])

# The party as the tests read it: the team, the companions owned, the temporary party and the personas.
def party_line
  party = $game_party
  [MGQ_MpGame.get(party, :actors).to_a, MGQ_MpGame.get(party, :include_actors).to_a, MGQ_MpGame.get(party, :temp_actors).to_a,
   [9, 20, 40].map { |id| $game_actors[id].id }]
end

# Starts a boss event, wins its battle and has the boss fall back.
#
# @param list [Array] The event's commands.
def fall_back(list)
  start(list)
  win
  frames
  win if $game_party.in_battle
  answer(4)
  frames(15)
end

reset
before = party_line
check("the team holds four, the other companions on standby, two of them showing another persona",
      before, [[1, 2, 3, 4], [1, 2, 3, 4, 5, 9, 20, 40, 41], [], [909, 20, 400]])
start([[:do, proc { $game_party.set_temp_actors([9]) }], [:battle, 1725], [:mark, :after]])
check("a temporary party plays the fight with the persona the game gives it",
      [pool.instance_variable_get(:@fight).key, $game_party.actors.to_a, $game_actors[9].id], ["Chaos Ilias", [9], 9])
win
answer(4)
frames(15)
check("a boss whose event set a temporary party falls back with the party as it was",
      [party_line, MGQ_MpGame.get($game_party, :temp_personas), $game_party.temp_actors_use?, $ran], [before, nil, false, []])
check("the formation of the Raid World holds again", [$fits, $capped, $game_party.party_member_max], [[true], true, 4])
check("and the chat tells how much is left", $chat.last, "Slime falls back. Raid HP left: 4/5.")

reset
fall_back([[:do, proc { $game_party.add_temp_actors([53]) }], [:battle, 1975], [:mark, :after]])
check("companions added for the fight alone are gone again", [party_line, $ran], [before, []])

reset
fall_back([[:do, proc { $game_party.persona_change(21) }], [:battle, 2001], [:mark, :after]])
actor = $game_actors[20]
check("a persona the event changed comes back with the name and looks the character had",
      [actor.id, actor.name, actor.character_name, party_line], [20, "Renamed Twenty", "twenty", before])
check("and is not marked owned in the system save, which only the event's own change marks", $owned, [21])

reset
start([[:var, 56, 14], [:do, proc { add_actor_ex(683); $game_party.persona_change(9) }], [:battle, 2188], [:mark, :after]])
check("a larger party and a companion added to a full team send one to standby",
      [$game_party.actors.to_a, $game_party.party_member_max], [[1, 2, 3, 683], 4])
win
frames
win
answer(4)
frames(15)
check("the party size, the team, the companions owned and the persona come back",
      [$game_variables[56], party_line], [0, before])

# The last phase of a fight of several counts, and the boss falls back to the party before the first.
reset
star_eater = proc do
  $game_party.remove_actor(41)
  $game_party.persona_change(40)
  add_actor_ex(40)
end
start([[:do, star_eater], [:sw, 7027, true], [:var, 1339, 2], [:battle, 2157], [:var, 1339, 3], [:battle, 2158], [:mark, :after]])
check("the first phase counts against no pool", pool.instance_variable_get(:@fight), nil)
win
frames
check("the last phase does, its event having changed the party and the story between the phases",
      [pool.instance_variable_get(:@fight).key, $game_variables[1339], $game_party.actors.to_a.include?(41)], ["Star Eater", 3, false])
win
answer(4)
frames(15)
check("the boss falls back to the story and the party before the first phase",
      [$game_variables[1339], $game_switches[7027], party_line, $ran], [0, false, before, []])

reset
fall_back([[:do, proc { $game_party.persona_change(1); $game_party.remove_actor(2) }], [:var, 56, 25], [:battle, 2219], [:mark, :after]])
check("the last fight of Chaos falls back with the party size and the team too", [$game_variables[56], party_line], [0, before])
reset
MGQ_MpGame.get($game_actors, :data)[40] = nil
fall_back([[:do, proc { add_actor_ex(400) }], [:battle, 2095], [:mark, :after]])
check("a character the event made goes back to its main persona", [$game_actors[40].id, $game_party.actors.to_a, MGQ_MpGame.get($game_party, :include_actors).to_a], [40, [1, 2, 3, 4], before[1]])
check("which is not marked owned either", $owned, [400])

# An event that ended with its battle waits for the answer on the map, where the party may change.
reset
start([[:do, proc { $game_party.set_temp_actors([9]); $game_party.remove_actor(41) }], [:battle, 1725]])
win
frames(3)
check("an event whose battle was its last command has ended while the relay answers", $game_map.interpreter.running?, false)
$game_party.add_actor(8)
$game_actors[20].persona_change(21)
answer(4)
frames(15)
check("a companion who joined after the battle stays, and the event's changes are undone",
      [MGQ_MpGame.get($game_party, :include_actors).to_a, $game_party.temp_actors_use?], [before[1] + [8], false])
check("a persona changed after the battle stays too", $game_actors[20].id, 21)

# The items a boss event gives and equips at once come again as the event is played again.
reset
$game_party.gain_item($data_weapons[7], 1)
$game_actors[40].change_equip(0, $data_weapons[7])
gear = proc do
  $game_map.interpreter.force_change_equip(40, 1, 1, 4832)
  $game_map.interpreter.change_actor_equip_stone(40, 0, 2104, 3060)
end
bag = proc { [4832, 7].map { |id| $game_party.item_number($data_weapons[id]) } + [2104, 3060].map { |id| $game_party.item_number($data_items[id]) } }
fall_back([[:do, gear], [:battle, 2158], [:mark, :after]])
check("the event's weapon and stones are worn, the weapon it replaced in the bag", [$game_actors[40].equips[0], bag.call], [$data_weapons[4832], [0, 1, 0, 0]])
start([[:do, gear], [:battle, 2158], [:mark, :after]])
noted = pool.instance_variable_get(:@fight).gifts
win
answer(4)
frames(15)
check("a replay notes the copies it left in the bag", noted, { [:weapon, 4832] => 1, [:item, 2104] => 1, [:item, 3060] => 1 })
check("and the boss that falls back again takes them back out", bag.call, [0, 1, 0, 0])
start([[:do, gear], [:battle, 2158], [:mark, :after]])
win
answer(0, true)
frames(15)
check("a replay whose battle empties the pool keeps what it gave", [$ran, bag.call], [[:after], [1, 1, 1, 1]])
$game_party.lose_item($data_weapons[4832], 1)
start([[:do, gear], [:battle, 71], [:mark, :after]])
win
answer(4)
frames(15)
check("an item already in the bag before the event stays", bag.call, [0, 1, 1, 1])

# A split party that the event joins comes back split, the party played where it stood.
reset
$game_party.setup_multipartymember([[1, 2], [3, 4]])
$game_party.start_multiparty([1402, 5, 6, 8], [1404, 7, 8, 2])
$game_party.set_temp_actors($game_party.reserve_member)
$game_party.reserve_member = nil
$game_player.transfer = nil
$game_map.map_id = 1402
$game_player.x, $game_player.y, $game_player.direction = 5, 6, 8
split = party_line
join = proc do
  $game_party.end_multiparty
  $game_map.map_id = 404
end
fall_back([[:do, join], [:battle, 2133], [:mark, :after]])
parties = (0..1).map { |index| split_party = $game_party.multi_party[index]; [split_party.member, split_party.map_id, split_party.position] }
check("a boss whose event joined the split parties splits them again", [$game_party.multi_party?, parties],
      [true, [[[1, 2], 1402, [5, 6, 8]], [[3, 4], 1404, [7, 8, 2]]]])
check("the party played goes back to where it stood as the event started, with its team",
      [$game_party.multi_party.id, $game_player.transfer, $game_party.reserve_member, party_line], [0, [1402, 5, 6, 8], [1, 2], split])
reset
$game_party.setup_multipartymember([[1, 2], [3, 4]])
$game_party.start_multiparty([1402, 5, 6, 8], [1404, 7, 8, 2])
MGQ_MpGame.set($game_party.multi_party, :party_index, 1)
$game_party.set_temp_actors([3, 4])
$game_map.map_id = 1404
$game_player.x, $game_player.y, $game_player.direction = 9, 9, 4
fall_back([[:do, join], [:battle, 2133], [:mark, :after]])
check("the second party played comes back as the one played, where it stood",
      [$game_party.multi_party.id, $game_player.transfer, $game_party.reserve_member, $game_party.multi_party[0].position], [1, [1404, 9, 9, 4], [3, 4], [5, 6, 8]])
reset
split_up = proc do
  $game_party.setup_multipartymember([[1, 2], [3, 4]])
  $game_party.start_multiparty([1402, 5, 6, 8], [1404, 7, 8, 2])
  $game_party.set_temp_actors([1, 2])
end
fall_back([[:do, split_up], [:battle, 2133], [:mark, :after]])
check("parties an event split are joined again", [$game_party.multi_party?.to_s, party_line], ["false", before])

# What the boss leaves as it is.
reset
start([[:do, proc { $game_party.set_temp_actors([9]) }], [:battle, 1725], [:mark, :after]])
win
answer(0, true)
frames(15)
check("a battle that empties the pool keeps the event's party", [$ran, $game_party.actors.to_a], [[:after], [9]])
reset
start([[:do, proc { $game_party.set_temp_actors([9]) }], [:battle, 1725], [:mark, :after]])
noted = pool.instance_variable_get(:@fight).party
lose
BattleManager.retry_battle
check("the retry of a lost battle keeps the party as the event found it", pool.instance_variable_get(:@fight).party, noted)
reset
$game_party.instance_variable_set(:@temp_actors, nil)
start([[:battle, 71], [:mark, :after]])
check("a battle whose event started without a party noted counts against no pool", pool.instance_variable_get(:@fight), nil)
