#----------------------------------------------------------------
#  battles_sync_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-08: Checked that a command phase the battle ended in closes as the live battle finishes
#      Paulinchen  2026-10-07: Checked the counters a state new to the guest gets
#                            - Checked a whole turn's way from the host's recorder over the wire to the guest's playback
#      Paulinchen  2026-10-06: Created
#
#----------------------------------------------------------------

# Covers the live battle's own parts, battles_sync.rbx with its recorder, playback and live steps:
# the host's settings, where messages go, a host left alone, what the guest takes of the host's
# stream, and a whole turn recorded on the host and played back on the guest.

require_relative "battle_support"

sync = MGQ_MpBattlesSync
playback = sync::Playback
recorder = sync::Recorder
scene = Scene_Battle.new
$scene_now = scene
$my_seat = 0

# Stand-ins for what the tests below ask of the game.
class Game_System
  attr_reader :conf
  def initialize; @conf = { :bt_skip => true, :bt_skip_cutin => 1, :skip_skill_effect => false }; end
end
StateStub = Struct.new(:id)
class Game_Actor
  attr_accessor :tp, :state_list, :result
  def actor?; true; end
  def states; @state_list || []; end
  def defence_wall; 2; end
  def refresh; end
end
class Game_Enemy
  attr_accessor :sprite_effect_type, :hp, :mp, :tp
  def actor?; false; end
  def states; []; end
end
class Game_Party
  attr_accessor :od_turn, :od_user
  def name; "Party"; end
  def consume_item(item); ($consumed ||= []) << item.id; end
end
class Game_ActionResult
  attr_accessor :hp_damage
  def initialize(battler = nil); end
end
class Game_Message
  attr_accessor :face_name, :face_index, :background, :position
  def has_text?; !($game_message_texts || []).empty?; end
end
# The guest's battle log, whose line draws a random number as the host's call did.
class BattleLog
  attr_reader :lines
  def display_damage(target); (@lines ||= []) << [target, rand(1000)]; end
end
class Game_Troop; def enemy_names; ["Slime"]; end; end
class Scene_Battle
  def battle_start; end
  def turn_start; $turns_started += 1; end
  def update; end
  def command_escape; end
  def wait_for_message; end
end
module BattleManager; def self.judge_win_loss; true; end; end
module Vocab
  Emerge = "%s appears!"
  Preemptive = "%s struck first!"
  Surprise = "%s was surprised!"
end
$game_system = Game_System.new
$data_states = [nil] + (1..10).map { |id| StateStub.new(id) }

# The host's settings that leave parts of a battle unshown.
sync.join_world(:host, "s1", [2], "the party")
sync.show_everything
check("a live battle's host shows everything", $game_system.conf, { :bt_skip => false, :bt_skip_cutin => false, :skip_skill_effect => false })
sync.show_everything
sync.finish
check("and gets its own settings back once the battle ends", $game_system.conf, { :bt_skip => true, :bt_skip_cutin => 1, :skip_skill_effect => false })

# A battle's messages go to its players alone.
sync.join_world(:host, "s2", [2, 3], "the party")
$sent.clear
sync::Channel.post("ready", "x")
check("a battle's message goes to each of its players, not to the whole world", $sent.map(&:first), [2, 3])
sync.finish

# A host whose guests all left plays on and closes the command phase.
sync::Hooks.live
sync.join_world(:host, "s3", [2], "the party")
sync.battle_started
sync::Live.instance_variable_set(:@phase_open, true)
sync.instance_variable_set(:@solo, true)
$turns_started = 0
scene.turn_start
check("a host left alone plays its turn and closes the phase, so the next one settles who fights on", [$turns_started, sync::Live.instance_variable_get(:@phase_open)], [1, false])
sync::Live.instance_variable_set(:@phase_open, true)
sync::Live.instance_variable_set(:@answered, [2])
sync.finish
check("a command phase the battle ended in closes as the battle finishes, its answers forgotten",
      [sync::Live.instance_variable_get(:@phase_open), sync::Live.instance_variable_get(:@answered), $log.grep(/command phase of turn \d+ closed: the battle ended in it/).size], [false, [], 1])

# A defeat's sprite effect.
monster = $game_troop.members[0]
sync.join_world(:guest, "s4", [0], "Host")
playback.sprite_effect(monster, :collapse)
check("a co-op monster the host's battle defeats falls on the guest too", monster.sprite_effect_type, :collapse)
sync.finish
sync.join_world(:guest, "s5", [0], "Host", :pvp)
playback.sprite_effect(monster, :collapse)
check("a PvP opponent stays as a silhouette", monster.sprite_effect_type, :whiten)
sync.finish

# Items the host's battle used up of the guest's bag.
$consumed = []
playback.use_up(Game_Actor.new(1), $data_items[3])
playback.use_up(Game_MpActor.new(MGQ_MpActors::Builds::Member.new(2), "Friend"), $data_items[4])
playback.use_up(Game_Actor.new(1), $data_skills[3])
playback.use_up(nil, $data_items[5])
check("the guest uses up the items its own characters used, and nothing else", $consumed, [3])

# The host's calls the guest makes.
sync::Hooks.instance_variable_set(:@log_calls, ["display_damage"])
check("the guest makes only the calls the hooks list",
      [playback.callable?("log", "display_damage"), playback.callable?("log", "display_unheard_of"), playback.callable?("scene", "process_skill_word"), playback.callable?("scene", "exit")],
      [true, false, true, false])
check("never making a symbol of the host's text", Symbol.all_symbols.map(&:to_s).include?("display_unheard_of"), false)

# How the battle began.
sync.join_world(:guest, "s6", [0], "Host")
playback.reset
$game_message_texts = []
playback.emerge(scene, false, true)
check("a co-op guest shows the host's party surprised", $game_message_texts, ["Slime appears!", "Party was surprised!"])
playback.take_encounter
check("and its first command phase takes the surprise", [BattleManager.instance_variable_get(:@preemptive), BattleManager.instance_variable_get(:@surprise)], [false, true])
sync.finish
sync.join_world(:guest, "s7", [0], "Host", :pvp)
$game_message_texts = []
playback.emerge(scene, false, true)
check("in a PvP battle the host's surprise is the guest's first strike", $game_message_texts, ["Slime appears!", "Party struck first!"])
sync.finish

# The battlers' values.
fighter = Game_Actor.new(5)
fighter.tp = 30.0
fighter.state_list = [StateStub.new(9), StateStub.new(4)]
fighter.instance_variable_set(:@state_turns, { 4 => 2, 9 => -1 })
fighter.instance_variable_set(:@buffs, [0] * 8)
check("the host records HP, MP, SP, the states with the turns they have left, buffs and barriers", recorder.value_fields(fighter), [100, 10, 30, [4, 9], [2, -1], [0] * 8, 2])
target = Game_Actor.new(6)
target.instance_variable_set(:@cnt, { :defense_wall => [] })
playback.values(target, 50, 5, 0, [4], [3], [0] * 8, 2)
check("the guest takes them", [target.hp, MGQ_MpGame.get(target, :states), MGQ_MpGame.get(target, :state_turns)], [50, [4], { 4 => 3 }])
check("with the counters the game keeps per state, which a turn's end on the map reads", [target.instance_variable_get(:@state_turn_counts), target.instance_variable_get(:@state_steps)], [{ 4 => 0 }, { 4 => 0 }])
check("with the barriers", target.instance_variable_get(:@cnt)[:defense_wall], [true, true])

# The battle's end stays on file.
recorder.start(:link)
recorder.event("battle_end", 0)
check("the battle's end is no guest's to play", recorder.instance_variable_get(:@events), [])
recorder.event("turn", 1)
check("a turn is", recorder.instance_variable_get(:@events).size, 1)
recorder.stop

# The host's HP above this game's own maximum, which the game's refresh holds a character below.
class ClampingActor < Game_Actor
  def mhp; 100; end
  def refresh; @hp = [@hp, mhp].min; end
end
strong = ClampingActor.new(8)
$log.clear
playback.values(strong, 500, 5, 0, [4], [1], [0] * 8, 0)
check("the guest keeps the host's HP even above its own maximum, after the game read the features anew", strong.hp, 500)
check("and logs the difference once", $log.grep(/Actor8 has 500 HP on the host, above this game's maximum of 100/).size, 1)

# A whole turn goes from the host's recorder over the wire to the guest's playback: the battlers'
# values, a call with its seed, a message, who appears and the end.
hero = Game_Actor.new(11)
hero.instance_variable_set(:@buffs, [0] * 8)
hero.state_list = [StateStub.new(4)]
hero.instance_variable_set(:@state_turns, { 4 => 3 })
foe = Game_Actor.new(12)
foe.instance_variable_set(:@buffs, [0] * 8)
$game_party.own = [hero, foe]
$game_troop.members.each { |enemy| enemy.hp = 40; enemy.mp = 4 }
$my_seat = 0
sync.join_world(:host, "r1", [2], "the party")
sync.battle_started
$sent.clear
recorder.start(:link)
recorder.values
foe.result = Game_ActionResult.new
foe.result.hp_damage = 25
recorder.call("log", "display_damage", [foe]) { $host_draw = rand(1000) }
recorder.event("message", nil, "Face", 1, 0, 2, "Take that!")
recorder.instead("emerge", true, false) { $host_emerged = true }
recorder.event("end", "process_victory", 0, 0)
recorder.flush
stream = $sent.map { |seat, text| [seat, fields_of(text)] }.select { |_, f| f["battle"] == "events" }
check("the host streams the turn to its guest", [stream.size, stream[0][0], stream[0][1]["bid"]], [1, 2, "r1"])
check("as lines the wire reads back", stream[0][1][:payload].split("\n").map { |line| sync::Wire.parse(line) { |ref| ref }[0] },
      ["values", "values", "values", "values", "time_stop", "call", "message", "emerge", "end"])
sync.finish

# The guest plays it: the values arrive before the call, the call draws the host's random number,
# the message and the appearance show, and the end comes back.
$my_seat = 2
sync.join_world(:guest, "r1", [0], "Host")
sync.battle_started
sync::Hooks.instance_variable_set(:@log_calls, ["display_damage"])
scene.instance_variable_set(:@log_window, BattleLog.new)
hero.hp = 1
hero.state_list = []
foe.result = nil
$game_message_texts = []
$game_message.speaker = nil
playback.reset
sync::Channel.receive(0, "events", stream[0][1][:payload])
outcome = playback.run(scene)
check("the guest plays the turn up to the host's end", outcome, ["end", "process_victory", 0, 0])
check("the battlers have the host's values", [hero.hp, MGQ_MpGame.get(hero, :states), MGQ_MpGame.get(hero, :state_turns), $game_troop.members.map(&:hp)], [100, [4], { 4 => 3 }, [40, 40]])
check("the guest's own call draws the host's random number, with the host's action result", [scene.instance_variable_get(:@log_window).lines, foe.result.hp_damage], [[[foe, $host_draw]], 25])
check("the message and who appears show in the guest's language", $game_message_texts, ["Take that!", "Slime appears!", "Party struck first!"])
check("and the host's party struck first for the guest's command phase too", [$game_message.face_name, $game_message.face_index, playback.instance_variable_get(:@encounter)], ["Face", 1, [true, false]])
sync.finish
