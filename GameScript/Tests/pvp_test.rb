#----------------------------------------------------------------
#  pvp_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Checked hit messages left out without a target outside multiplayer battles too
#      Paulinchen  2026-10-08: Checked messages shown as the game shows them and a missing picture not tried again
#                            - Checked that a duel in a Raid World takes only the squad's Frontline
#                            - Checked hit messages left out once no target is left
#      Paulinchen  2026-10-07: Created
#
#----------------------------------------------------------------

# Covers the PvP battle, battles_pvp.rbx with battles_pvp_mirror.rbx: the snapshot taken as the
# battle starts, which every save written meanwhile gets instead of the battle, the game put back as
# the map starts again without the game's Retry, the troop's totals other mods read, actions and
# messages without a target, the mirror match's report, a reset and a Raid World duel.

require_relative "support"

$log = []
# Stands in for the mod's base script.
module MGQ_Multiplayer
  # Stands in for the log, which notes each line in $log.
  module Log; def self.write(m); $log << m; end; end
  # Stands in for Discord, which is not running.
  module Discord; def self.available?; false; end; end
  # Stands in for cleaning a text for the screen, keeping it as it is.
  def self.clean(text); text.to_s; end
end
# Stands in for the screen, 640 by 480.
module Graphics; def self.width; 640; end; def self.height; 480; end; end
# Stands in for the game's scenes, noting the scene called in $called and gone to in $went_to.
module SceneManager
  # Stands in for starting the game, doing nothing.
  def self.run; end
  # Notes the scene called in $called.
  def self.call(scene); $called = scene; end
  # Notes the scene gone to in $went_to.
  def self.goto(scene); $went_to = scene; end
  # Stands in for the running scene: there is none.
  def self.scene; nil; end
end
# Stands in for the map's scene, noting in $map_started that it started.
class Scene_Map; def start; $map_started = true; end; def update_scene; end; end
# Stands in for the title screen.
class Scene_Title; def start; end; def update; end; end
# Stands in for the battle's scene.
class Scene_Battle
  attr_accessor :subject, :log_window
  # Stands in for the game's use of an item, noting in $used that it ran.
  def use_item; $used = true; :used; end
  # Stands in for showing an item's message, noting its name in $shown_messages.
  def display_use_item(_action, item); ($shown_messages ||= []) << item.name; end
end
# An action the game works the targets of a message out with, finding those $targets lists.
class Game_Action
  attr_accessor :target_index
  # Makes the action of a battler.
  def initialize(subject); @subject = subject; end
  # Sets the action's skill.
  def set_skill(id); @skill_id = id; end
  # Answers the targets $targets lists.
  def make_targets; $targets; end
end
# A skill and its messages.
Skill = Struct.new(:id, :name, :message1, :message2) { def is_skill?; true; end }
# The battle log, which notes the action it says finds no target.
class BattleLog; attr_reader :empty; def display_target_empty(subject); (@empty ||= []) << subject; end; end
# The game's data: the troops the battle adds its own to.
module RPG
  # A troop of the database.
  class Troop; attr_accessor :id, :name, :members; end
end
$data_troops = [nil, RPG::Troop.new, RPG::Troop.new]
# A character of the player's own.
class Game_Actor
  attr_reader :id, :name
  # Makes the character, named after its id.
  def initialize(id); @id = id; @name = "Actor#{@id}"; end
  # Notes the character's id in $recovered.
  def recover_all; $recovered << @id; end
  # Answers whether the character is dead: never.
  def dead?; false; end
end
# The rebuilt character the PvP battle builds its opponents on.
class Game_MpActor < Game_Actor
  # Rebuilds a member of another player's team, named after its id and the player.
  def initialize(member, player); @id = member.actor_id; @name = "Actor#{@id} (#{player})"; end
  # Answers what differs from the build: nothing.
  def differences; []; end
end
# Stands in for the rebuilt characters.
module MGQ_MpActors
  # Stands in for the builds, which are lists of actor ids here.
  module Builds
    # A character of a build.
    Member = Struct.new(:actor_id)
    # Answers the game's fingerprint.
    def self.game; "game-1"; end
    # Writes characters as their ids.
    def self.write(actors); actors.map(&:id).join(","); end
    # Reads a build's first characters back.
    #
    # @param text [String] The ids.
    # @param count [Integer] How many characters to read.
    # @return [Array<Member>] The characters.
    def self.parse(text, count); text.to_s.split(",").first(count).map { |id| Member.new(id.to_i) }; end
  end
end
# The squads, in a Raid World while $raid is set: one character on the Frontline, three in the squad.
module MGQ_MpCoopSquad
  # The places of the Frontline outside a Raid World.
  FRONTLINE = 4
  # The faces in a row of a face file.
  FACE_COLUMNS = 4
  # Answers whether the player is in a Raid World: $raid.
  def self.raid?; $raid; end
  # Answers the size of a PvP battle's Frontline.
  def self.pvp_front; $raid ? 1 : FRONTLINE; end
  # Answers the player's squad, or its Frontline alone without the Backline.
  def self.raid_team(backline = true); $game_party.battle_members.first(backline ? 3 : 1); end
end
# The player's party: two characters on the Frontline, one on the Backline.
class Game_Party
  attr_accessor :battle_members, :bench_members
  # Makes the party.
  def initialize; @battle_members = [Game_Actor.new(1), Game_Actor.new(2)]; @bench_members = [Game_Actor.new(3)]; end
end
# The troop and the totals of its rewards.
class Game_Troop
  # Answers the troop's enemies.
  def members; @enemies || []; end
  # Answers the turn: the first.
  def turn_count; 1; end
  # Answers the troop's EXP.
  def exp_total; 500; end
  # Answers the troop's gold.
  def gold_total; 300; end
  # Answers the troop's drops.
  def make_drop_items; [:drop]; end
end
# The game's passing values, with the medals of a battle.
class Game_Temp
  attr_accessor :in_memory_battle
  # Makes the values with a medal from before the battle.
  def initialize; @gain_medals = [:old_medal]; end
  # Notes in $common_cleared that the queued common event went.
  def clear_common_event; $common_cleared = true; end
end
# Stands in for the player on the map, noting in $player_refreshed that it was drawn anew.
class Game_Player; def refresh; $player_refreshed = true; end; def x; 4; end; def y; 6; end; end
# Stands in for the map, map 12.
class Game_Map; attr_accessor :need_refresh; def map_id; 12; end; end
# Stands in for the game's messages, keeping the texts added in texts.
class Game_Message; attr_reader :texts; def initialize; @texts = []; end; def add(text); @texts << text; end; end
# Stands in for a battler's sprite.
class Sprite_Battler; def update_bitmap; end; def update; end; end
# The game's saves: the variables are what a save holds, and the Library what every save shares.
module DataManager
  # Answers a save's contents: the variables.
  def self.make_save_contents; { :variables => $game_variables.dup }; end
  # Puts a save's variables back.
  def self.extract_save_contents(contents); $game_variables = contents[:variables]; end
  # Notes the Library written in $system_written.
  def self.save_system; $system_written << $game_library.dup; end
  # Notes the save written to a slot in $saves_written, with the Library.
  def self.save_game_without_rescue(index); $saves_written << [index, make_save_contents, $game_library.dup]; true; end
  # Notes the autosave in $saves_written, with the Library.
  def self.auto_save_game_without_rescue; $saves_written << [:auto, make_save_contents, $game_library.dup]; end
end
# Stands in for the game's battle manager, noting each setup in $setup and each turn in $turns.
module BattleManager
  # The handler the battle's result goes to.
  class << self; attr_accessor :event_proc; end
  # Notes the battle's setup in $setup.
  def self.setup(troop_id, can_escape = true, can_lose = false); $setup << [troop_id, can_escape, can_lose]; end
  # Stands in for the game's choice of a battler's automatic skills: answers :original.
  def self._auto_skill_per(skills, battler); :original; end
  # Stands in for queuing the automatic skills.
  def self.set_auto_skill(&skills); @action_game_masters = [:queued]; end
  # Counts the turn in $turns.
  def self.turn_start; $turns += 1; end
end
# Stands in for the battles' rules, noting each begin and finish in $rules.
module MGQ_MpBattles
  # Notes the rules' begin in $rules.
  def self.begin(kind, backline = kind != :pvp); $rules << [kind, backline]; end
  # Notes the rules' finish in $rules.
  def self.finish; $rules << :finished; end
  # Answers whether a battle runs, by the last note in $rules.
  def self.running?; !$rules.empty? && $rules.last != :finished; end
end
# Stands in for the PvP balance, noting in $balanced how many battlers it balanced.
module MGQ_MpBalancePvp
  # Notes in $balanced how many battlers it balances.
  def self.begin(battlers); $balanced = battlers.size; end
  # Notes in $balance_finished that it finished.
  def self.finish; $balance_finished = true; end
end
# Stands in for the parts of the PvP battle that other scripts hold.
module MGQ_MpBattlesPvp
  # Stands in for the Backline, which the player leaves out.
  module Backline
    # Answers whether the player wants the Backline: no.
    def self.wanted?; false; end
    # Notes in $backline_began how many opponents it began with.
    def self.begin(opponents); $backline_began = opponents.size; end
    # Notes in $backline_finished that it finished.
    def self.finish; $backline_finished = true; end
  end
end
# Stands in for the live battle.
module MGQ_MpBattlesSync
  # Notes in $recording that the battle is recorded.
  def self.record_to_file; $recording = true; end
  # Notes in $battle_started that the battle started.
  def self.battle_started; $battle_started = true; end
  # Notes in $sync_finished that it finished.
  def self.finish; $sync_finished = true; end
  # Answers whether the live battle broke: never.
  def self.broken?; false; end
  # Names battlers by name and id, as the live battle does.
  #
  # @param battlers [Array<Game_Actor>] The battlers.
  # @return [String] Their names.
  def self.named_list(battlers); battlers.map { |battler| "#{battler.name} (#{battler.id})" }.join(", "); end
end
# Stands in for the worlds, none of which is open.
module MGQ_MpWorld; def self.open?; false; end; end
$setup = []
$rules = []
$recovered = []
$saves_written = []
$system_written = []
$turns = 0

load_script "battles_pvp"
load_script "battles_pvp_mirror"
# The mirror report, whose sections go into $reports instead of a file.
module MGQ_MpBattlesPvp::MirrorReport
  # Notes a section in $reports.
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

# A friend's character whose face this game lacks gets no picture, and is not tried again.

# Stands in for the world's graphics, which lack every face asked for in $graphics_asked.
module MGQ_MpOverworld; def self.graphic(folder, name); ($graphics_asked ||= []) << [folder, name]; nil; end; end
faceless = $game_troop.members[0]
faceless.define_singleton_method(:face_name) { "MissingFace" }
2.times { pvp::Pictures.stand_in_for(faceless) }
check("a character whose face this game lacks shows the game's own sprite, its face asked for once",
      [pvp::Pictures.stand_in_for(faceless), $graphics_asked], [nil, [[:face, "MissingFace"]]])

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
  # Fires its own automatic skill first.
  def firing_auto_skills(skills); [:fired] + skills; end
end
check("a friend's character picks its automatic skills itself, the player's as the game does",
      [BattleManager._auto_skill_per([:skill], $game_troop.members[0]), BattleManager._auto_skill_per([:skill], $game_party.battle_members[0])], [[:fired, :skill], :original])
BattleManager.set_auto_skill { |member| [] }
check("the queued skills are ordered by speed without failing", [BattleManager.instance_variable_get(:@action_game_masters), $log.grep(/ordering the automatic skills failed/).size], [[:queued], 1])

# An action without a target is left out in a PvP battle, a hit's message without one in any
# battle.
scene = Scene_Battle.new
scene.log_window = BattleLog.new
# A battler whose action of an item finds no target.
Targetless = Struct.new(:item) do
  # Answers the battler as its own action.
  def current_action; self; end
  # Answers the action's targets: none.
  def make_targets; []; end
end
# An item's aim at the other side or at the own.
Aimed = Struct.new(:for_opponent?, :for_friend?)
scene.subject = Targetless.new(Aimed.new(true, false))
$used = false
check("an action that finds no target is left out, the battle log saying so", [scene.use_item, $used, scene.log_window.empty], [true, false, [scene.subject]])
scene.subject = Targetless.new(nil)
check("an action without a skill runs as the game runs it", [scene.use_item, $used], [:used, true])
named = Skill.new(9022, "Sword of Heaven's Army", '\u strikes \e!', "")
$targets = [nil]
scene.display_use_item(Struct.new(:target_index).new(0), named)
$targets = [:foe]
scene.display_use_item(Struct.new(:target_index).new(0), named)
scene.display_use_item(Struct.new(:target_index).new(0), Skill.new(1, "Plain", " attacks!", ""))
check("a hit whose message names a target leaves the message out once none is left, as when the Frontline fell before it",
      $shown_messages, ["Sword of Heaven's Army", "Plain"])
$targets = [nil]
$rules << :finished
scene.display_use_item(Struct.new(:target_index).new(0), named)
$rules << [:coop, true]
scene.display_use_item(Struct.new(:target_index).new(0), named)
check("outside a multiplayer battle, such as a Raid World battle of the player's own whose squad cut the Frontline (issue #41), and in a co-op battle it is left out too",
      $shown_messages, ["Sword of Heaven's Army", "Plain"])
battle_module = MGQ_MpBattlesPvp::Battle
battle_module.singleton_class.send(:alias_method, :checked_message_without_target?, :message_without_target?)
battle_module.define_singleton_method(:message_without_target?) { |*_| raise ArgumentError, "other arguments" }
scene.display_use_item(Struct.new(:target_index).new(0), named)
check("a failing check shows the message as the game does", [$shown_messages.size, $log.grep(/message target check failed, the message shows: ArgumentError/).size], [3, 1])
battle_module.singleton_class.send(:alias_method, :message_without_target?, :checked_message_without_target?)
$targets = [:foe]
$rules << [:pvp, false]

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

# In a Raid World a duel takes the player's squad, and only its Frontline without the Backline.
$raid = true
$recovered = []
$game_party.battle_members = (1..4).map { |id| Game_Actor.new(id) }
pvp.begin_mirror
check("a duel in a Raid World without the Backline fights the squad's Frontline alone", [$game_troop.members.map(&:name), $recovered], [["Actor1 (Mirror)"], [1]])
Scene_Title.new.start
$raid = false
check("nothing failed", $log.grep(/FAILED|could not/).size, 0)
