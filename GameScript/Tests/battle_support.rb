#----------------------------------------------------------------
#  battle_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Stood in for the gold a co-op turn sends, which none of the battle tests use
#      Paulinchen  2026-11-08: Dropped the status window's name drawing, which the scripts no longer hook
#      Paulinchen  2026-11-06: Stood in for UI.confirm and read the waiting box's lines from the wait
#      Paulinchen  2026-11-05: Kept each message sent as the scripts hand it instead of as a copy of the DLL's codec writes it
#                            - Answered the live battle's topics and the battlers' plans with the values each test sets
#                            - Answered the topics that write and read battle lines
#                            - Stood in for the world room's sending through its port, keeping each message as the DLL writes it
#                            - Answered the plans of the battlers the scripts build and loaded their factory
#                            - Stood in for the game's start of a battler, of the party, of the troop and of the battle, and for a state's counts
#                            - Read the scripts' clock from $frames and stood in for the grace the DLL's Sessions tells
#                            - Stood in for the chat box being open by $typing
#      Paulinchen  2026-11-01: Gave the pictures a font, which the Mod Framework measures texts in
#                            - Read the waiting box's lines from its box of the Mod Framework
#                            - Stopped loading the deleted ui_boxes.rbx
#      Paulinchen  2026-10-31: Stood in for the Mod Framework's question box, answered at the battle's waits as the framework collects it
#      Paulinchen  2026-10-30: Answered the co-op battles' topics
#                            - Stood in for the enemies of the database as a list, whose size the troop's repair reads
#                            - Answered the live battle's topics
#                            - Dropped the stand-in of the link's cancel
#      Paulinchen  2026-10-28: Gave the stand-in of the color its parts
#      Paulinchen  2026-10-23: Opened the stand-in of the interface's models, which places the boxes
#                            - Answered the rules' topics through the bridge, such as the squad math
#                            - Stood in for the confirm box
#                            - Stood in for the world's grace
#                            - Stood in for finding a player by id and following presence
#      Paulinchen  2026-10-20: Stood in for skills chained after an action
#      Paulinchen  2026-10-12: Stood in for the battle log's popup
#                            - Stood in for a troop whose enemies all fell and for a battle that ended
#                            - Stood in for the leader's call and dropping it
#      Paulinchen  2026-10-11: Stood in for whether a character stands and the party takes commands
#                            - Loaded ui_layout.rbx and stood in for Player.ini and a window's width
#                            - Let the real waiting box run
#                            - Gave the rebuilt character stand-in its owner and its own name
#                            - Let the battle status window stand-in draw a character's name
#                            - Kept every window opened
#      Paulinchen  2026-10-10: Stood in for the encounter step count and for being in a party
#      Paulinchen  2026-10-09: Let an enemy appear, transform and be eaten
#                            - Stood in for the game's variables
#                            - Lettered only living enemies without a letter and counted the death state
#      Paulinchen  2026-10-08: Stood in for the faces this game has
#                            - Loaded coop_scope.rbx and counted the Frontline from max_battle_members
#                            - Stood in for connected players, map entry, the tile, the leader and troop setup
#                            - Loaded battles_raid_bosses.rbx and battles_coop_hotjoin.rbx and let enemies fall
#      Paulinchen  2026-10-07: Stood in for the shared helpers who, random_id and the pictures' count
#                            - Let the characters clear their actions and named the party
#      Paulinchen  2026-10-06: Gave the party a skill's Backline targets and the Library's counts
#      Paulinchen  2026-10-04: Kept the chat's system lines, counted the troop's actions and cleared the actor
#                            - Stood in for battles_coop_level_sync.rbx
#                            - Stood in for coop_gather.rbx
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#                            - Added stand-ins for the party's events and the chat
#                            - Gave the world stand-in tell, notice and the own id and seat
#                            - Gave the characters a battle start and a turn start
#                            - Let the map's player refresh
#                            - Gave the map's player a random encounter and a menu call, and added the title screen
#                            - Gave the characters skills and the database skills and items
#      Paulinchen  2026-10-02: Gave the rebuilt character stand-in its owner's seat and place
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# What the tests of live battles in a world share: stand-ins for the game, the world room and the
# party, the scripts every one of them builds on (coop_squad.rbx, battles.rbx,
# battles_coop.rbx and battles_sync.rbx), and the game's objects on map 5.

require_relative "rules_support"
require_relative "live_support"


$sent = []
$log = []
# Stands in for the loader's log and Player.ini, keeping the log's lines in $log.
module MGQ_Multiplayer
  module Log; def self.write(m); $log << m; end; end
  module Player; def self.name; "Me"; end; def self.setting(key); ($player_ini ||= {})[key]; end; end
end
# The graphics this game has, of which it lacks only one face.
module MGQ_MpOverworld; def self.graphic?(_folder, name); name != "MissingFace"; end; end
# Stands in for the world room: its players, the own state and the link, keeping what is sent in
# $sent.
module MGQ_MpOverworldSync
  # The grace a player away is kept for, as the DLL's Sessions tells it.
  def self.grace_frames; 900; end
  def self.in_world?; true; end
  def self.notice(text); Status.notice(text); end
  def self.tell(seat, fields, body = ""); Port.send_to(seat, fields, body); end
  def self.who(peer); peer == :me ? "the player" : (peer ? "#{peer.state['name']} (seat #{peer.seat})" : "an unknown player"); end
  module Peers
    # A player in the room.
    Peer = Struct.new(:seat, :state, :ghost, :member, :away)
    @all = []
    def self.all; @all; end
    def self.at(seat); @all.find { |p| p.seat == seat }; end
    def self.present; @all; end
    def self.kept_with_id(id); @all.find { |p| p.state["id"].to_s == id.to_s }; end
    def self.on_this_map?(peer); peer.state["map"].to_i == $game_map.map_id; end
  end
  module Me
    def self.identity; ["id-me", "Me"]; end
    def self.id; identity[0]; end
    def self.seat; $my_seat.to_i; end
    def self.map_since; $my_since.to_i; end
  end
  module Status; def self.notice(text); ($notices ||= []) << text; end; end
  # Stands in for the world room's sending, keeping each message in $sent as the scripts hand it.
  module Port
    def self.send_to(seat, fields, body); $sent << [seat, sent_message(fields, body)]; true; end
  end
end
# The leader's call, which coop_gather_test.rb covers: $gather_call is the calling player's seat and
# the map the call leads to while one stands, and the reason it was dropped is kept.
module MGQ_MpCoopGather
  def self.coming?; !$gather_call.nil?; end
  def self.calling_battle?(peer, map_id); $gather_call == [peer.seat, map_id]; end
  def self.drop_call(reason); $gather_dropped = reason; $gather_call = nil; end
end
# Stands in for coop_scene.rbx's count of pictures.
module MGQ_MpCoopScene; MAX_PICTURE = 100; end
# The level sync, which level_sync_test.rb covers: the battle's level is $sync_level, and what the
# co-op battle asks of it is kept.
module MGQ_MpCoopLevelSync
  def self.level_for(_players); $sync_level; end
  def self.begin(level); $sync_began = level; end
  def self.sync(actor); ($synced ||= []) << actor; end
  def self.finish; $sync_finished = true; end
end
# Stands in for the chat, keeping its system lines in $chat, its box open while $typing is set.
unless defined?(MGQ_MpChat)
  module MGQ_MpChat
    def self.system(text); ($chat ||= []) << text; end
    def self.typing?; $typing ? true : false; end
  end
end
# Stands in for coop.rbx: the party of the players marked member, led by $leader.
module MGQ_MpCoop
  module Party
    def self.id; "p1"; end
    def self.members; MGQ_MpOverworldSync::Peers.all.select(&:member); end
    def self.leader; $leader; end
  end
  def self.in_party?; !Party.members.empty?; end
  def self.leads?(player); player == :me ? $leader == :me : ($leader.equal?(player) || Array($leaders).any? { |l| l.equal?(player) }); end
  def self.random_id(length); rand(36**length).to_s(36); end
  def self.party_leader; Party.members.empty? ? nil : $leader; end
end
# Stands in for the game's database items and skills.
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
# Stands in for the game's color, with its parts the battle line writes.
class Color
  attr_reader :red, :green, :blue, :alpha
  def initialize(red = 0, green = 0, blue = 0, alpha = 255); @red = red; @green = green; @blue = blue; @alpha = alpha; end
end
# Stands in for the game's tone.
class Tone; end
# Stands in for the game's result of an action.
class Game_ActionResult; end
# Stands in for the game's item of an action.
class Game_BaseItem; end
# Stands in for the base of characters and enemies: the game's start of a battler counts its
# starts in $battle_starts and gives it the counters, and a state's counts and erase keep
# the counters the game keeps per state.
class Game_Battler
  attr_reader :counters_set
  def on_battle_start; @counters_set = true; ($battle_starts ||= []) << self; end
  def set_counter; @counters_set = true; end
  def reset_state_counts(id); (@state_turns ||= {})[id] = 9; (@state_turn_counts ||= {})[id] = 0; (@state_steps ||= {})[id] = 0; end
  def erase_state(id); [@state_turns, @state_turn_counts, @state_steps].each { |counts| counts.delete(id) if counts }; end
end
# Stands in for a character's action, its item kept as [kind, id], and the skill chained after it.
class Game_Action
  attr_accessor :item, :target_index, :chain_action
  attr_reader :symbol
  def initialize(battler); @battler = battler; end
  def set_symbol(symbol); @symbol = symbol; self; end
  def set_skill(id); @item = [:skill, id]; end
  def set_item(id); @item = [:item, id]; end
  # Cuts the chain before its first skill in $unchained, as the game cuts what the character's
  # skill types do not chain.
  def check_chain_action
    link = self
    link = link.chain_action while link.chain_action && !Array($unchained).include?(link.chain_action.item[1])
    link.chain_action = nil
  end
end
# Stands in for a character with 100 HP, 10 MP and the skills below KNOWN_SKILLS.
class Game_Actor < Game_Battler
  attr_accessor :id, :hp, :mp, :actions, :turn_hit_damage_count
  def initialize(id); @id = id; @hp = 100; @mp = 10; @actions = []; end
  def on_battle_start; super; @turn_hit_damage_count = 0; @start_hp = @hp; clear_actions; end
  # The HP the character had as the game started it, which a trait's states for low HP read.
  attr_reader :start_hp
  def on_turn_start; end
  def name; "Actor#{@id}"; end
  def exist?; true; end
  def all_dead?; @hp == 0; end
  def alive?; @hp > 0; end
  def inputable?; true; end
  def luca?; false; end
  def make_actions; @actions = [Game_Action.new(self)]; end
  def clear_actions; @actions = []; end
  def attack_skill_id; 1; end
  def guard_skill_id; 2; end
  def skills; $data_skills[3...KNOWN_SKILLS]; end
  def make_auto_battle_actions; @actions = [:auto]; end
end
# Stands in for another player's rebuilt character, named after its owner.
class Game_MpActor < Game_Actor
  attr_accessor :mp_seat, :mp_place
  def initialize(member, player); super(member.actor_id); @player = player; end
  def name; "#{base_name} (#{@player})"; end
  def owner; @player; end
  def base_name; "Actor#{@id}"; end
end
# Stands in for an enemy of the troop, named by its kind and letter.
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
  # Fallen, told by the death state (1), which a live battle's values set.
  def dead?; exist? && death_state?; end
  def death_state?; @dead || Array(@states).include?(1) ? true : false; end
end
# Stands in for core_actors.rbx, whose builds are the characters' ids, and whose turns never send
# the party's gold.
module MGQ_MpActors
  def self.gold_used?; false; end
  def self.hold_gold(_seat, _gold); end
  def self.forget_gold; end
  module Builds
    # A character of a build.
    Member = Struct.new(:actor_id)
    def self.write(actors); actors.map(&:id).join(","); end
    def self.parse(text, count); text.to_s.split(",").first(count).map { |id| Member.new(id.to_i) }; end
  end
end
# Stands in for the party, its characters in @own and the first four its Frontline.
class Game_Party
  attr_accessor :own, :party_member_max, :in_battle
  def initialize; @party_member_max = 8; end
  def all_members; @own; end
  def members; @in_battle ? battle_members : all_members; end
  def on_battle_start; members.each(&:on_battle_start); @in_battle = true; end
  def max_battle_members; 4; end
  def battle_members; @own.first(max_battle_members); end
  def bench_members; @own[max_battle_members..-1] || []; end
  def swap_order(a, b); @own[a], @own[b] = @own[b], @own[a]; end
  def inputable?; battle_members.any?(&:inputable?); end
  def item_target_members(item); item.include_bench? ? all_members : battle_members; end
  def name; "#{battle_members.first.name}'s party"; end
end
# Stands in for the game's name of a party.
module Vocab; PartyName = "%s's party"; end
# The Library all saves share, which counts each character's deeds by its id.
class Game_Library
  def count_up_actor_data(id, symbol); ($counted ||= []) << [id, symbol]; end
end
$game_library = Game_Library.new
# Stands in for the troop, counting its new actions in $troop_actions.
class Game_Troop
  def members; @enemies; end
  def members=(enemies); @enemies = enemies; end
  def make_actions; $troop_actions = ($troop_actions || 0) + 1; end
  # Starts the enemies as the game does, which reads a random one's defeat scene and so fails for
  # an empty troop.
  def on_battle_start; members.each(&:on_battle_start); members.sample.enemy_id; end
  def all_dead?; Array(members).all? { |enemy| enemy.hidden? || enemy.dead? }; end
  def setup(troop_id); @troop_id = troop_id; @enemies = [Game_Enemy.new(0, troop_id)]; end
  attr_reader :troop_id
  # The enemies whose EXP, gold and drops a victory pays out, as the game counts them.
  def defeated_members; members.select { |m| m.predationed? || m.exist? }.select(&:death_state?); end
  # Letters the living enemies that have no letter yet, counting on per kind of enemy.
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
# Stands in for the battle's sprites, which draw the enemies in reverse.
class Spriteset_Battle
  attr_reader :enemies
  def dispose_enemies; @enemies = nil; end
  def create_enemies; @enemies = $game_troop.members.reverse; end
end
# Stands in for the game's temporary state.
class Game_Temp; attr_accessor :in_memory_battle; end
# Stands in for the message window, keeping its texts in $game_message_texts.
class Game_Message; def clear; $cleared = true; end; def add(text); ($game_message_texts ||= []) << text; end; end
# Stands in for the map's event interpreter, running while busy.
class Interpreter; attr_accessor :busy; def running?; @busy; end; end
# Stands in for the map.
class Game_Map; attr_accessor :map_id, :interpreter; end
# Stands in for the map's player.
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
  attr_reader :encounter_count
  # The game's draw of the steps to the next random encounter, always 100 here.
  def make_encounter_count; @encounter_count = 100.0; end
end
# Stands in for the title screen.
class Scene_Title; def start; end; end
# Stands in for the game's switches.
class Game_Switches; def initialize; @d = {}; end; def [](i); @d[i] || false; end; def []=(i, v); @d[i] = v; end; end
# Stands in for the game's variables.
class Game_Variables; def initialize; @d = {}; end; def [](i); @d[i] || 0; end; def []=(i, v); @d[i] = v; end; end
# The system database, of which the switches' names are read.
System = Struct.new(:switches)
$data_system = System.new(Array.new(100, ""))
# The game's switch that forbids swapping the Backline in.
module NWConst; module Sw; FORBID_BATTLE_SHIFT_CHANGE = 27; end; end
# Stands in for the game's battle manager, keeping each setup in $setup.
module BattleManager
  def self.setup(troop_id, can_escape = true, can_lose = false); $setup << [troop_id, can_escape, can_lose]; end
  def self.can_giveup?; true; end
  def self.turn_end; $turn_ends = ($turn_ends || 0) + 1; end
  def self.process_abort; $aborted = true; end
  def self.clear_actor; $actor_cleared = true; end
  def self.shift_change?; $shift; end
  def self.bind?; false; end
  def self.battle_start; $battle_started = true; $game_party.on_battle_start; $game_troop.on_battle_start; end
  def self.battle_end?; $ending ? true : false; end
  def self.battle_end(_result); $game_party.battle_members.each { |actor| $game_library.count_up_actor_data(actor.id, :battle) }; end
end
$setup = []
# Every character has the skills below KNOWN_SKILLS; of those from there on, only the last has no
# skill type.
KNOWN_SKILLS = 150
# The items from FIELD_ITEMS on are none a battle allows.
FIELD_ITEMS = 40
$data_skills = [nil] + (1...200).map { |id| RPG::Skill.new(id, id == 199 ? 0 : 1) }
$data_items = [nil] + (1...50).map { |id| RPG::Item.new(id, id < FIELD_ITEMS) }
# Stands in for the game's scene manager, keeping the scene called in $called.
module SceneManager
  def self.run; end
  def self.call(scene); $called = scene; end
  def self.scene; $scene_now; end
end
# The battle log's popup at the top, keeping each line it shows in $popups; like the game's, it
# shows one popup of a mark at a time.
class StubPopups
  def initialize; @marks = []; end
  # Shows a line unless a popup of its mark was shown.
  def push(text, mark = nil)
    return if mark && @marks.include?(mark)

    @marks << mark if mark
    ($popups ||= []) << text
  end
end
# The battle log, of which only the popup is used.
StubBattleLog = Struct.new(:popup)

# Gives a battle a log whose popups land in $popups.
#
# @param scene [Scene_Battle] The battle.
def popups_on(scene)
  $popups = []
  scene.instance_variable_set(:@log_window, StubBattleLog.new(StubPopups.new))
end

# Stands in for the battle scene.
class Scene_Battle
  def terminate; end
  def refresh_status; $refreshed = true; end
  def start_party_command_selection; $commands_phase = true; end
  attr_accessor :changing
  def scene_changing?; @changing; end
  # A wait that never ends fails the test instead of hanging it.
  def update_for_wait; $frames += 1; raise "a wait ran past #{WAIT_LIMIT} frames" if $frames > WAIT_LIMIT; $inject.call($frames) if $inject; QuestionStandIn.collect; end
  def no_change_all_dead_on_bench?; :original; end
  def bench_member_ok; :original; end
  def bench_member_cancel; $bench_cancelled = true; end
  # Counts a defeat in the Library: the subject's, and the target's going down.
  def count_up_defeat(subject, target, _item = nil)
    $game_library.count_up_actor_data(subject.id, :defeat)
    $game_library.count_up_actor_data(target.id, :down)
  end
end
# Stands in for the battle status window, whose own answers are :original.
class Window_BattleStatus
  attr_accessor :index
  def current_item_enabled?; :original; end
end
# Stands in for the map scene, telling whether the menu was called.
class Scene_Map; def update_scene; end; def scene_changing?; false; end; def update_call_menu; @menu_calling = true; end; attr_reader :menu_calling; end
# Stands in for the scenes' base.
class Scene_Base; def update; end; def start; end; end
# Frames a wait may last in a test before it fails.
WAIT_LIMIT = 10_000
# Stands in for the screen, its frame count kept in $frames.
module Graphics; def self.width; 640; end; def self.height; 480; end; def self.update; end; end
clock_from { $frames }
# Stands in for the game's rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# Stands in for the game's sprite.
class Sprite; def initialize(*); end; end
# A window's contents: the texts drawn by line, each line's drawings counted, in a font the Mod
# Framework measures texts in. The records are made as needed, since a test may open the class anew
# with an initialize of its own.
class Bitmap
  # The picture's font.
  Font = Struct.new(:size, :color, :bold, :outline, :out_color, :name, :italic)
  attr_reader :width, :height
  def initialize(width = 1, height = 1); @width = width; @height = height; end
  def font; @font ||= Font.new(24); end
  def rect; Rect.new(0, 0, @width, @height); end
  def lines; @lines ||= {}; end
  def draws; @draws ||= Hash.new(0); end
  def text_size(text); Rect.new(0, 0, text.to_s.size * 8, 24); end
  def draw_text(x, y, width, height, text, align = 0); lines[y / 24] = text; draws[y / 24] += 1; end
  def clear_rect(x, y, width, height); lines.delete(y / 24); end
  def clear; lines.clear; end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
end
# Stands in for the windows' base, its contents a Bitmap stand-in.
class Window_Base
  attr_reader :width, :height, :contents
  attr_accessor :x, :y, :z
  # Every window opened, newest last.
  def initialize(x = 0, y = 0, width = 0, height = 0); @x, @y, @width, @height = x, y, width, height; @contents = Bitmap.new(width - 24, height - 24); ($windows ||= []) << self; end
  def line_height; 24; end
  def width=(width); @width = width; end
  def create_contents; @contents = Bitmap.new(@width - 24, @height - 24); end
  def update; end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
end
# Reads the open waiting box's lines by their place, as its box of the Mod Framework shows them:
# the text, the names, then the seconds or the leave offer, the empty ones left out.
#
# @return [Hash{Integer => String}] The lines by place, none while no waiting box is open.
def waiting_lines
  waiting = MGQ_MpBattlesSync::Waiting
  return {} unless waiting.instance_variable_get(:@box)

  lines = {}
  [:text, :names, :time].each_with_index { |which, index| lines[index] = waiting.line(which) unless waiting.line(which).empty? }
  lines
end
# The cancel button, which $leave presses.
module Input; def self.trigger?(button); button == :B && $leave ? true : false; end; end

# coop.rbx's tell, sending through the world room stand-in.
module MGQ_MpCoop
  def self.tell(seat, field, value, fields = {})
    MGQ_MpOverworldSync::Port.send_to(seat, { field => value, "party" => Party.id }.merge(fields), "")
  end
  def self.route(*); end
end
# The world room's routes and hooks the scripts register, ignored here.
module MGQ_MpOverworldSync
  def self.route(*); end
  def self.on_tick(*); end
  def self.state_fields(*); end
  def self.busy_scene(*); end
  def self.on_observe(*); end
  def self.on_leave(*); end
  def self.on_presence(*); end
  def self.label_line(*); end
end
# The DLL's side of the bridge, answering the rules' topics, such as the squad math, the live
# battle's with the values each test sets, kept in $live, and the battle lines' with fake lines.
open_rules_bridge
answer_live($world_bridge)
answer_wire($world_bridge)
load_script "ui_online"
# Stands in for the Mod Framework's question box: each question lands in $asked with its yes and no,
# and $confirm answers the open one at the next wait, as the framework answers it at every frame,
# true for yes, false for no, nil to keep it open.
module QuestionStandIn
  # The question's handle: whether it waits, and its close from outside, which answers no.
  Handle = Struct.new(:waiting) do
    def open?; QuestionStandIn.open?; end
    def close(_reason = nil); QuestionStandIn.close; end
  end
  def self.ask(answer); @block = answer; Handle.new(true); end
  def self.open?; !@block.nil?; end
  def self.collect; return if @block.nil? || $confirm.nil?; block = @block; @block = nil; block.call($confirm); end
  def self.close; block = @block; @block = nil; block.call(false) if block; end
end
load_script "coop_scope"
load_script "coop_squad"
load_script "battles"
load_script "battles_battlers"
load_script "battles_raid_bosses"
load_script "battles_coop"
load_script "battles_coop_hotjoin"

# The fake models of the interface on the same bridge, which place the boxes in the layout.
open_fake_ui { ["", 0] }
# UI.confirm asks the stand-in above, in place of the fake interface's.
Mod_Framework::UI.define_singleton_method(:confirm) do |question, params = {}, &answer|
  ($asked ||= []) << [question, [params[:yes], params[:no]]]
  QuestionStandIn.ask(answer)
end
%w[battles_sync battles_sync_wire battles_sync_recorder battles_sync_playback battles_sync_live].each { |name| load_script name }
SceneManager.run
MGQ_MpBattlesCoop.install

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
$data_enemies = [nil] + Array.new(99) { Object.new }

# The co-op battles' rules in C# on the same bridge.
require_relative "coop_support"
answer_coop($world_bridge)
# The plans of the battlers the scripts build, with the values each test sets, kept in $battlers.
answer_battlers($world_bridge)
