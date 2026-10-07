#----------------------------------------------------------------
#  pvp_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-07: Created
#
#----------------------------------------------------------------

# Covers the PvP battle itself, battles_pvp.rbx with battles_pvp_mirror.rbx: the snapshot taken
# as the battle starts, which every save written meanwhile gets instead of the battle, the game put
# back as the map starts again with the game's Retry dropped, the troop's totals other mods read,
# the action without a target, the mirror match's report at the first turn and a reset.

require_relative "support"

$log = []
module MGQ_Multiplayer
  module Log; def self.write(m); $log << m; end; end
  module Discord; def self.available?; false; end; end
  def self.clean(text); text.to_s; end
end
module Graphics; def self.width; 640; end; def self.height; 480; end; end
module SceneManager
  def self.run; end
  def self.call(scene); $called = scene; end
  def self.goto(scene); $went_to = scene; end
  def self.scene; nil; end
end
class Scene_Map; def start; $map_started = true; end; def update_scene; end; end
class Scene_Title; def start; end; def update; end; end
class Scene_Battle
  attr_accessor :subject, :log_window
  def use_item; $used = true; :used; end
end
# The battle log, which notes the action it says finds no target.
class BattleLog; attr_reader :empty; def display_target_empty(subject); (@empty ||= []) << subject; end; end
# The game's data: the troops the battle adds its own to.
module RPG
  class Troop; attr_accessor :id, :name, :members; end
end
$data_troops = [nil, RPG::Troop.new, RPG::Troop.new]
# A character of the player's own, and the rebuilt kind the PvP battle builds its opponents on.
class Game_Actor
  attr_reader :id, :name
  def initialize(id); @id = id; @name = "Actor#{@id}"; end
  def recover_all; $recovered << @id; end
  def dead?; false; end
end
class Game_MpActor < Game_Actor
  def initialize(member, player); @id = member.actor_id; @name = "Actor#{@id} (#{player})"; end
  def differences; []; end
end
module MGQ_MpActors
  module Builds
    Member = Struct.new(:actor_id)
    def self.game; "game-1"; end
    def self.write(actors); actors.map(&:id).join(","); end
    def self.parse(text, count); text.to_s.split(",").first(count).map { |id| Member.new(id.to_i) }; end
  end
end
module MGQ_MpCoopSquad; FRONTLINE = 4; FACE_COLUMNS = 4; end
class Game_Party
  attr_accessor :battle_members, :bench_members
  def initialize; @battle_members = [Game_Actor.new(1), Game_Actor.new(2)]; @bench_members = [Game_Actor.new(3)]; end
end
class Game_Troop
  def members; @enemies || []; end
  def turn_count; 1; end
  def exp_total; 500; end
  def gold_total; 300; end
  def make_drop_items; [:drop]; end
end
class Game_Temp
  attr_accessor :in_memory_battle
  def initialize; @gain_medals = [:old_medal]; end
  def clear_common_event; $common_cleared = true; end
end
class Game_Player; def refresh; $player_refreshed = true; end; def x; 4; end; def y; 6; end; end
class Game_Map; attr_accessor :need_refresh; def map_id; 12; end; end
class Game_Message; attr_reader :texts; def initialize; @texts = []; end; def add(text); @texts << text; end; end
class Sprite_Battler; def update_bitmap; end; def update; end; end
# The game's saves: the variables are what a save holds, and the Library what every save shares.
module DataManager
  def self.make_save_contents; { :variables => $game_variables.dup }; end
  def self.extract_save_contents(contents); $game_variables = contents[:variables]; end
  def self.save_system; $system_written << $game_library.dup; end
  def self.save_game_without_rescue(index); $saves_written << [index, make_save_contents, $game_library.dup]; true; end
  def self.auto_save_game_without_rescue; $saves_written << [:auto, make_save_contents, $game_library.dup]; end
end
module BattleManager
  class << self; attr_accessor :event_proc; end
  def self.setup(troop_id, can_escape = true, can_lose = false); $setup << [troop_id, can_escape, can_lose]; end
  def self._auto_skill_per(skills, battler); :original; end
  def self.set_auto_skill(&skills); @action_game_masters = [:queued]; end
  def self.turn_start; $turns += 1; end
end
# Stand-ins for the scripts the PvP battle builds on: the rules, the balance, the Backline and the
# live battle.
module MGQ_MpBattles
  def self.begin(kind, backline = kind != :pvp); $rules << [kind, backline]; end
  def self.finish; $rules << :finished; end
end
module MGQ_MpBalancePvp
  def self.begin(battlers); $balanced = battlers.size; end
  def self.finish; $balance_finished = true; end
end
module MGQ_MpBattlesPvp
  module Backline
    def self.wanted?; false; end
    def self.begin(opponents); $backline_began = opponents.size; end
    def self.finish; $backline_finished = true; end
  end
end
module MGQ_MpBattlesSync
  def self.record_to_file; $recording = true; end
  def self.battle_started; $battle_started = true; end
  def self.finish; $sync_finished = true; end
  def self.broken?; false; end
  def self.named_list(battlers); battlers.map { |battler| "#{battler.name} (#{battler.id})" }.join(", "); end
end
module MGQ_MpWorld; def self.open?; false; end; end
$setup = []
$rules = []
$recovered = []
$saves_written = []
$system_written = []
$turns = 0

load_script "battles_pvp"
load_script "battles_pvp_mirror"
# The mirror report's sections, written nowhere.
module MGQ_MpBattlesPvp::MirrorReport
  def self.write(mode, title); ($reports ||= []) << [mode, title]; end
end
SceneManager.run

pvp = MGQ_MpBattlesPvp
battle = pvp::Battle
member = MGQ_MpActors::Builds::Member
$game_party = Game_Party.new
$game_troop = Game_Troop.new
$game_temp = Game_Temp.new
$game_player = Game_Player.new
$game_map = Game_Map.new
$game_message = Game_Message.new
$game_variables = [0, 5]
$game_library = "library before"
$game_system_switches = "switches before"
$game_global_system = "affection before"

# The battle starts with a snapshot of the game.
check("outside a battle the troop's totals are the game's", [$game_troop.exp_total, $game_troop.make_drop_items], [500, [:drop]])
battle.start("Friend", [member.new(7), member.new(8), member.new(9)], false, false)
check("a PvP battle runs, its troop the friend's Frontline rebuilt, stood side by side", [battle.running?, battle.mirror?, $game_troop.members.map(&:name), $game_troop.members.map(&:screen_x)],
      [true, false, ["Actor7 (Friend)", "Actor8 (Friend)", "Actor9 (Friend)"], [106, 320, 533]])
check("in a troop of its own, in the game's battle replay mode with the PvP rules", [$data_troops.size, $data_troops.last.name, $setup.last, $game_temp.in_memory_battle, $rules.last],
      [4, "PvP battle", [3, true, true], true, [:pvp, false]])
check("the player's Frontline recovered and balanced with the other side", [$recovered, $balanced], [[1, 2], 5])
check("and nothing failed", $log.grep(/could not start/), [])
check("while it runs, the troop's totals are nothing, which other mods read", [$game_troop.exp_total, $game_troop.gold_total, $game_troop.make_drop_items], [0, 0, []])

# Every save written meanwhile gets the game as it was before the battle.
$game_variables[1] = 99
$game_library = "library changed"
DataManager.save_game_without_rescue(3)
DataManager.auto_save_game_without_rescue
DataManager.save_system
check("a save written during the battle holds the save and the shared data as they were before it",
      $saves_written.map { |index, contents, library| [index, contents[:variables], library] }, [[3, [0, 5], "library before"], [:auto, [0, 5], "library before"]])
check("as does the system save", $system_written, ["library before"])
check("and the game goes on with the battle's state after the write", [$game_variables, $game_library], [[0, 99], "library changed"])

# The automatic skills fire from the friend's side for the friend's characters.
class << $game_troop.members[0]
  def firing_auto_skills(skills); [:fired] + skills; end
end
check("a friend's character picks its automatic skills itself, the player's as the game does",
      [BattleManager._auto_skill_per([:skill], $game_troop.members[0]), BattleManager._auto_skill_per([:skill], $game_party.battle_members[0])], [[:fired, :skill], :original])
BattleManager.set_auto_skill { |member| [] }
check("the queued skills are ordered by speed without failing", [BattleManager.instance_variable_get(:@action_game_masters), $log.grep(/ordering the automatic skills failed/).size], [[:queued], 1])

# An action without a target is left out, once the game runs and the hook is in.
scene = Scene_Battle.new
scene.log_window = BattleLog.new
Targetless = Struct.new(:item) do
  def current_action; self; end
  def make_targets; []; end
end
Aimed = Struct.new(:for_opponent?, :for_friend?)
scene.subject = Targetless.new(Aimed.new(true, false))
$used = false
check("an action that finds no target is left out, the battle log saying so", [scene.use_item, $used, scene.log_window.empty], [true, false, [scene.subject]])
scene.subject = Targetless.new(nil)
check("an action without a skill runs as the game runs it", [scene.use_item, $used], [:used, true])

# The map puts the game back and drops the game's Retry.
BattleManager.instance_variable_set(:@retry_data, :retry)
battle.finished(0)
BattleManager.event_proc.call(2)
Scene_Map.new.start
check("as the map starts again the battle is over, the save and the shared data as before it", [battle.running?, $game_variables, $game_library, $game_system_switches, $map_started],
      [false, [0, 5], "library before", "switches before", true])
check("the replay mode, the troop, the Retry and the medals of the battle are gone", [$game_temp.in_memory_battle, $data_troops.size, BattleManager.instance_variable_get(:@retry_data), $game_temp.instance_variable_get(:@gain_medals)],
      [false, 3, nil, [:old_medal]])
check("the map is drawn anew and told the result the game ended with", [$player_refreshed, $game_map.need_refresh, $game_message.texts.last], [true, true, "Friend's team won."])
check("the rules, the balance, the Backline and the live battle are finished", [$rules.last, $balance_finished, $backline_finished, $sync_finished], [:finished, true, true, true])
check("the troop's totals are the game's again", [$game_troop.exp_total, $game_troop.make_drop_items], [500, [:drop]])
scene.subject = Targetless.new(Aimed.new(true, false))
check("and an action without a target runs as the game runs it", scene.use_item, :used)

# A mirror match writes its report once the first turn starts.
$reports = []
pvp.begin_mirror
check("a mirror match fights the player's own whole team, recorded, and starts its report", [battle.mirror?, $game_troop.members.map(&:name), $recording, $reports.map(&:first)],
      [true, ["Actor1 (Mirror)", "Actor2 (Mirror)", "Actor3 (Mirror)"], true, ["wb"]])
BattleManager.turn_start
BattleManager.turn_start
check("the first turn adds to the report once, since the hook is in once the game runs", [$turns, $reports.map(&:first)], [2, ["wb", "ab"]])

# A reset drops the battle and puts the shared data back.
$game_library = "library changed"
Scene_Title.new.start
check("a reset drops the battle, the shared data put back", [battle.running?, $game_library, $game_temp.in_memory_battle], [false, "library before", false])
check("nothing failed", $log.grep(/FAILED|could not/).size, 0)
