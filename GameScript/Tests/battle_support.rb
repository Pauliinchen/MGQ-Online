#----------------------------------------------------------------
#  battle_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-03: Gave the characters a battle start and a turn start, which set their hit count
#                            - Let the map's player refresh, telling which leader it shows
#                            - Gave the characters skills and the database skills and items, which a guest's commands are checked against
#      Paulinchen  2026-10-02: Gave the rebuilt character stand-in its owner's seat and place
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# What the tests of live battles in a world share: stand-ins for the game, the world room and the
# party, the scripts every one of them builds on (mp_coop_squad.rbx, mp_battles.rbx,
# mp_battles_coop.rbx and mp_battles_sync.rbx), fields_of, and the game's objects on map 5.

require_relative "support"


$sent = []
$log = []
module MGQ_Multiplayer
  module Log; def self.write(m); $log << m; end; end
  module Player; def self.name; "Me"; end; end
  module Link; def self.cancel; $cancelled = true; end; end
end
module MGQ_MpOverworldSync
  def self.in_world?; true; end
  module Peers
    Peer = Struct.new(:seat, :state, :ghost, :member)
    @all = []
    def self.all; @all; end
    def self.at(seat); @all.find { |p| p.seat == seat }; end
  end
  module Me
    def self.encode(state); state.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n\n"; end
    def self.identity; ["id-me", "Me"]; end
  end
  module Status; def self.notice(text); ($notices ||= []) << text; end; end
  module Link
    def self.send_to(seat, text); $sent << [seat, text]; true; end
    def self.status; { "seat" => $my_seat.to_s }; end
  end
end
module MGQ_MpCoop
  module Party
    def self.id; "p1"; end
    def self.members; MGQ_MpOverworldSync::Peers.all.select(&:member); end
    def self.leader; $leader; end
  end
  def self.leads?(player); player == :me ? $leader == :me : ($leader.equal?(player) || Array($leaders).any? { |l| l.equal?(player) }); end
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
  def hidden?; @hidden ? true : false; end
end
module MGQ_MpActors
  module Builds
    Member = Struct.new(:actor_id)
    def self.write(actors); actors.map(&:id).join(","); end
    def self.parse(text, count); text.to_s.split(",").first(count).map { |id| Member.new(id.to_i) }; end
  end
end
class Game_Party
  attr_accessor :own, :party_member_max
  def initialize; @party_member_max = 8; end
  def all_members; @own; end
  def battle_members; @own.first(4); end
  def bench_members; @own[4..-1] || []; end
  def swap_order(a, b); @own[a], @own[b] = @own[b], @own[a]; end
end
class Game_Troop
  def members; @enemies; end
  def members=(enemies); @enemies = enemies; end
  def make_unique_names
    @names_count ||= {}
    @enemies.each do |enemy|
      next if enemy.hidden?
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
  def transfer?; false; end
  def moving?; @moving; end
  def refresh; @leader_shown = $game_party.battle_members.first; end
end
class Game_Switches; def initialize; @d = {}; end; def [](i); @d[i] || false; end; def []=(i, v); @d[i] = v; end; end
System = Struct.new(:switches)
$data_system = System.new(Array.new(100, ""))
module NWConst; module Sw; FORBID_BATTLE_SHIFT_CHANGE = 27; end; end
module BattleManager
  def self.setup(troop_id, can_escape = true, can_lose = false); $setup << [troop_id, can_escape, can_lose]; end
  def self.can_giveup?; true; end
  def self.turn_end; $turn_ends = ($turn_ends || 0) + 1; end
  def self.process_abort; $aborted = true; end
  def self.shift_change?; $shift; end
  def self.bind?; false; end
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
end
class Window_BattleStatus
  attr_accessor :index
  def current_item_enabled?; :original; end
end
class Scene_Map; def update_scene; end; def scene_changing?; false; end; end
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
load_script "mp_coop_squad"
load_script "mp_battles"
load_script "mp_battles_coop"
load_script "mp_battles_sync"
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
