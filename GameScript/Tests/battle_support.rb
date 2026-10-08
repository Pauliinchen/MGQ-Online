#----------------------------------------------------------------
#  battle_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Let an enemy appear and transform, as the game's Enemy Appear and Enemy Transform do, and be eaten, which counts it among the defeated as the game does
#                            - Stood in for the game's variables, which hold the enemy rates a guest takes from the host
#                            - Lettered only the living enemies that have no letter yet, and counted an enemy with the death state as fallen, as the game does
#      Paulinchen  2026-10-08: Stood in for the faces this game has, of overworld.rbx
#                            - Loaded coop_scope.rbx, which tells coop_squad.rbx whether a Raid World is open, and counted the party's Frontline from max_battle_members
#                            - Stood in for the players whose connection stands, when the player entered the map, the player's tile, the party's leader and the troop's setup
#                            - Loaded battles_raid_bosses.rbx and battles_coop_hotjoin.rbx, and let enemies fall
#      Paulinchen  2026-10-07: Stood in for the helpers of coop.rbx, overworld_sync.rbx and coop_scene.rbx the battle scripts share now: who, random_id and the pictures' count
#                            - Let the characters clear their actions, and named the party after its first character
#      Paulinchen  2026-10-06: Gave the party the targets of a skill that reaches the Backline too, and added the Library's counts of the battle's end and of a defeat
#      Paulinchen  2026-10-04: Kept the chat's system lines, counted the troop's new actions and cleared the actor choosing
#                            - Stood in for battles_coop_level_sync.rbx, keeping what the co-op battle asks of it
#                            - Stood in for coop_gather.rbx, which tells whether the player is about to be brought over
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#                            - Added stand-ins for the party's events and the chat, which the battle scripts call
#                            - Gave the world stand-in tell, notice and the own id and seat
#                            - Gave the characters a battle start and a turn start, which set their hit count
#                            - Let the map's player refresh, telling which leader it shows
#                            - Gave the map's player a random encounter and a menu call, and added the title screen
#                            - Gave the characters skills and the database skills and items, which a guest's commands are checked against
#      Paulinchen  2026-10-02: Gave the rebuilt character stand-in its owner's seat and place
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# What the tests of live battles in a world share: stand-ins for the game, the world room and the
# party, the scripts every one of them builds on (coop_squad.rbx, battles.rbx,
# battles_coop.rbx and battles_sync.rbx), fields_of, and the game's objects on map 5.

require_relative "support"


$sent = []
$log = []
module MGQ_Multiplayer
  module Log; def self.write(m); $log << m; end; end
  module Player; def self.name; "Me"; end; end
  module Link; def self.cancel; $cancelled = true; end; end
end
# The graphics this game has, of which it lacks only one face.
module MGQ_MpOverworld; def self.graphic?(_folder, name); name != "MissingFace"; end; end
module MGQ_MpOverworldSync
  def self.in_world?; true; end
  def self.notice(text); Status.notice(text); end
  def self.tell(seat, fields, body = ""); Link.send_to(seat, Me.encode(fields) + body); end
  def self.who(peer); peer == :me ? "the player" : (peer ? "#{peer.state['name']} (seat #{peer.seat})" : "an unknown player"); end
  module Peers
    Peer = Struct.new(:seat, :state, :ghost, :member)
    @all = []
    def self.all; @all; end
    def self.at(seat); @all.find { |p| p.seat == seat }; end
    def self.present; @all; end
    def self.on_this_map?(peer); peer.state["map"].to_i == $game_map.map_id; end
  end
  module Me
    def self.encode(state); state.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n\n"; end
    def self.identity; ["id-me", "Me"]; end
    def self.id; identity[0]; end
    def self.seat; $my_seat.to_i; end
    def self.map_since; $my_since.to_i; end
  end
  module Status; def self.notice(text); ($notices ||= []) << text; end; end
  module Link
    def self.send_to(seat, text); $sent << [seat, text]; true; end
    def self.status; { "seat" => $my_seat.to_s }; end
  end
end
module MGQ_MpCoopGather; def self.coming?; false; end; end
module MGQ_MpCoopScene; MAX_PICTURE = 100; end
# The level sync, which level_sync_test.rb covers: the battle's level is $sync_level, and what the
# co-op battle asks of it is kept.
module MGQ_MpCoopLevelSync
  def self.level_for(_players); $sync_level; end
  def self.begin(level); $sync_began = level; end
  def self.sync(actor); ($synced ||= []) << actor; end
  def self.finish; $sync_finished = true; end
end
module MGQ_MpChat; def self.system(text); ($chat ||= []) << text; end; end unless defined?(MGQ_MpChat)
module MGQ_MpCoop
  module Party
    def self.id; "p1"; end
    def self.members; MGQ_MpOverworldSync::Peers.all.select(&:member); end
    def self.leader; $leader; end
  end
  def self.leads?(player); player == :me ? $leader == :me : ($leader.equal?(player) || Array($leaders).any? { |l| l.equal?(player) }); end
  def self.random_id(length); rand(36**length).to_s(36); end
  def self.party_leader; Party.members.empty? ? nil : $leader; end
end
module RPG
  class Item
    attr_reader :id
    def initialize(id = 0, battle = true); @id = id; @battle = battle; end
    def battle_ok?; @battle; end
  end
  class Skill
    attr_reader :id, :stype_id
    def initialize(id = 0, stype_id = 1); @id = id; @stype_id = stype_id; end
  end
  class State; end; class Weapon; end; class Armor; end
end
class Color; def initialize(*); end; end
class Tone; end
class Game_ActionResult; end
class Game_BaseItem; end
class Game_Battler; end
class Game_Action
  attr_accessor :item, :target_index
  def initialize(battler); @battler = battler; end
  def set_skill(id); @item = [:skill, id]; end
  def set_item(id); @item = [:item, id]; end
end
class Game_Actor < Game_Battler
  attr_accessor :id, :hp, :mp, :actions, :turn_hit_damage_count
  def initialize(id); @id = id; @hp = 100; @mp = 10; @actions = []; end
  def on_battle_start; @turn_hit_damage_count = 0; end
  def on_turn_start; end
  def name; "Actor#{@id}"; end
  def exist?; true; end
  def all_dead?; @hp == 0; end
  def inputable?; true; end
  def luca?; false; end
  def make_actions; @actions = [Game_Action.new(self)]; end
  def clear_actions; @actions = []; end
  def attack_skill_id; 1; end
  def guard_skill_id; 2; end
  def skills; $data_skills[3...KNOWN_SKILLS]; end
  def make_auto_battle_actions; @actions = [:auto]; end
end
class Game_MpActor < Game_Actor
  attr_accessor :mp_seat, :mp_place
  def initialize(member, player); super(member.actor_id); @player = player; end
  def name; "Actor#{@id} (#{@player})"; end
end
class Game_Enemy < Game_Battler
  attr_reader :enemy_id, :index
  attr_accessor :screen_x, :screen_y, :letter
  def initialize(index, enemy_id); @index = index; @enemy_id = enemy_id; @screen_x = @screen_y = 0; @letter = ""; end
  def name; "Enemy#{@enemy_id}#{@letter}"; end
  def hide; @hidden = true; end
  def appear; @hidden = false; end
  def transform(enemy_id); @enemy_id = enemy_id; @letter = ""; end
  def exist?; !hidden?; end
  # Eaten by a predation skill, which the game marks only on the game that ran the skill.
  def predationed?; @predationed ? true : false; end
  def hidden?; @hidden ? true : false; end
  attr_writer :dead
  # Fallen, as the game tells by the death state (1) a live battle's values give it.
  def dead?; exist? && death_state?; end
  def death_state?; @dead || Array(@states).include?(1) ? true : false; end
end
module MGQ_MpActors
  module Builds
    Member = Struct.new(:actor_id)
    def self.write(actors); actors.map(&:id).join(","); end
    def self.parse(text, count); text.to_s.split(",").first(count).map { |id| Member.new(id.to_i) }; end
  end
end
class Game_Party
  attr_accessor :own, :party_member_max, :in_battle
  def initialize; @party_member_max = 8; end
  def all_members; @own; end
  def max_battle_members; 4; end
  def battle_members; @own.first(max_battle_members); end
  def bench_members; @own[max_battle_members..-1] || []; end
  def swap_order(a, b); @own[a], @own[b] = @own[b], @own[a]; end
  def item_target_members(item); item.include_bench? ? all_members : battle_members; end
  def name; "#{battle_members.first.name}'s party"; end
end
module Vocab; PartyName = "%s's party"; end
# The Library all saves share, which counts each character's deeds by its id.
class Game_Library
  def count_up_actor_data(id, symbol); ($counted ||= []) << [id, symbol]; end
end
$game_library = Game_Library.new
class Game_Troop
  def members; @enemies; end
  def members=(enemies); @enemies = enemies; end
  def make_actions; $troop_actions = ($troop_actions || 0) + 1; end
  def setup(troop_id); @troop_id = troop_id; @enemies = [Game_Enemy.new(0, troop_id)]; end
  attr_reader :troop_id
  # The enemies whose EXP, gold and drops a victory pays out, as the game counts them.
  def defeated_members; members.select { |m| m.predationed? || m.exist? }.select(&:death_state?); end
  def make_unique_names
    @names_count ||= {}
    @enemies.each do |enemy|
      next if enemy.hidden? || enemy.dead? || !enemy.letter.empty?
      count = @names_count[enemy.enemy_id] || 0
      enemy.letter = " #{(65 + count).chr}"
      @names_count[enemy.enemy_id] = count + 1
    end
  end
  private :make_unique_names
end
class Spriteset_Battle
  attr_reader :enemies
  def dispose_enemies; @enemies = nil; end
  def create_enemies; @enemies = $game_troop.members.reverse; end
end
class Game_Temp; attr_accessor :in_memory_battle; end
class Game_Message; def clear; $cleared = true; end; def add(text); ($game_message_texts ||= []) << text; end; end
class Interpreter; attr_accessor :busy; def running?; @busy; end; end
class Game_Map; attr_accessor :map_id, :interpreter; end
class Game_Player
  attr_accessor :moving, :leader_shown
  attr_writer :x, :y
  def x; @x.to_i; end
  def y; @y.to_i; end
  def transfer?; false; end
  def moving?; @moving; end
  def refresh; @leader_shown = $game_party.battle_members.first; end
  def movable?; true; end
  # The game's random encounter: the troop set up once the steps ran out.
  def encounter; return false unless $encounter_troop; BattleManager.setup($encounter_troop); $encounter_troop = nil; true; end
end
class Scene_Title; def start; end; end
class Game_Switches; def initialize; @d = {}; end; def [](i); @d[i] || false; end; def []=(i, v); @d[i] = v; end; end
class Game_Variables; def initialize; @d = {}; end; def [](i); @d[i] || 0; end; def []=(i, v); @d[i] = v; end; end
System = Struct.new(:switches)
$data_system = System.new(Array.new(100, ""))
module NWConst; module Sw; FORBID_BATTLE_SHIFT_CHANGE = 27; end; end
module BattleManager
  def self.setup(troop_id, can_escape = true, can_lose = false); $setup << [troop_id, can_escape, can_lose]; end
  def self.can_giveup?; true; end
  def self.turn_end; $turn_ends = ($turn_ends || 0) + 1; end
  def self.process_abort; $aborted = true; end
  def self.clear_actor; $actor_cleared = true; end
  def self.shift_change?; $shift; end
  def self.bind?; false; end
  def self.battle_start; $battle_started = true; end
  def self.battle_end(_result); $game_party.battle_members.each { |actor| $game_library.count_up_actor_data(actor.id, :battle) }; end
end
$setup = []
# Every character has the skills below KNOWN_SKILLS; of those from there on, only the last has no
# skill type. The items from FIELD_ITEMS on are none a battle allows.
KNOWN_SKILLS = 150
FIELD_ITEMS = 40
$data_skills = [nil] + (1...200).map { |id| RPG::Skill.new(id, id == 199 ? 0 : 1) }
$data_items = [nil] + (1...50).map { |id| RPG::Item.new(id, id < FIELD_ITEMS) }
module SceneManager
  def self.run; end
  def self.call(scene); $called = scene; end
  def self.scene; $scene_now; end
end
class Scene_Battle
  def terminate; end
  def refresh_status; $refreshed = true; end
  def start_party_command_selection; $commands_phase = true; end
  attr_accessor :changing
  def scene_changing?; @changing; end
  def update_for_wait; $frames += 1; $inject.call($frames) if $inject; end
  def no_change_all_dead_on_bench?; :original; end
  def bench_member_ok; :original; end
  def bench_member_cancel; $bench_cancelled = true; end
  def count_up_defeat(subject, target, _item = nil)
    $game_library.count_up_actor_data(subject.id, :defeat)
    $game_library.count_up_actor_data(target.id, :down)
  end
end
class Window_BattleStatus
  attr_accessor :index
  def current_item_enabled?; :original; end
end
class Scene_Map; def update_scene; end; def scene_changing?; false; end; def update_call_menu; @menu_calling = true; end; attr_reader :menu_calling; end
class Window_Base; end
module Input; def self.trigger?(*); false; end; end

module MGQ_MpCoop
  def self.tell(seat, field, value, fields = {})
    MGQ_MpOverworldSync::Link.send_to(seat, MGQ_MpOverworldSync::Me.encode({ field => value, "party" => Party.id }.merge(fields)))
  end
  def self.route(*); end
end
module MGQ_MpOverworldSync
  def self.route(*); end
  def self.on_tick(*); end
  def self.state_fields(*); end
  def self.busy_scene(*); end
  def self.on_observe(*); end
  def self.on_leave(*); end
  def self.label_line(*); end
end
load_script "coop_scope"
load_script "coop_squad"
load_script "battles"
load_script "battles_raid_bosses"
load_script "battles_coop"
load_script "battles_coop_hotjoin"
%w[battles_sync battles_sync_wire battles_sync_recorder battles_sync_playback battles_sync_live].each { |name| load_script name }
module MGQ_MpBattlesSync::Waiting
  def self.open(text); :window; end
  def self.close(window); nil; end
  def self.leave?(window, frames); false; end
end
SceneManager.run
MGQ_MpBattlesCoop.install

# Reads a message another game sent into its fields, its body under :payload.
#
# @param text [String] The message.
# @return [Hash] The fields.
def fields_of(text)
  head, payload = text.split("\n\n", 2)
  fields = {}
  head.to_s.split("\n").each { |line| k, v = line.split("=", 2); fields[k] = v if v }
  fields[:payload] = payload.to_s
  fields
end

$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_temp = Game_Temp.new
$game_message = Game_Message.new
$game_map = Game_Map.new
$game_map.map_id = 5
$game_map.interpreter = Interpreter.new
$game_player = Game_Player.new
$game_party = Game_Party.new
$game_troop = Game_Troop.new
$game_troop.members = [Game_Enemy.new(0, 31), Game_Enemy.new(1, 32)]
$data_enemies = Hash.new { |_, id| id.to_i > 0 && id.to_i < 100 ? Object.new : nil }
