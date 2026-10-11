#----------------------------------------------------------------
#  battles_sync_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-11: Checked the waiting box: its lines, the names still waited for, the seconds drawn once a second, the leave offer, a battle's ending, a details that fails, the seat names and the playback's path
#                            - Checked that the host's wait for the commands names who still chooses and tells the guests, and that a guest's box names them while the host's stream stalls
#                            - Read the windows opened from battle_support.rb instead of keeping them itself
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

# The waiting box: what the game waits for, whom it still waits for and for how long, the leave
# offer, and the battle's windows held meanwhile.
waiting = sync::Waiting
$windows = []
class Window_Selectable < Window_Base
  attr_reader :active
  def initialize(*args); super; @active = true; end
  def activate; @active = true; end
  def deactivate; @active = false; end
end
command = Window_Selectable.new(0, 0, 100, 100)
scene.instance_variable_set(:@mp_command, command)
$my_seat = 0
peers = MGQ_MpOverworldSync::Peers
peers.all.replace([peers::Peer.new(2, { "name" => "Player A" }, nil, false)])
sync.join_world(:host, "w1", [2], "the party")
$frames = 0
$leave = false
$inject = nil

check("a wait answered at once opens no box", [waiting.wait_for(scene, "Now") { :now }, $windows.size], [:now, 1])

turns = 0
held = nil
answer = waiting.wait_for(scene, "Waiting for the party...") do
  turns += 1
  held = command.active if turns == 2
  turns == 3 ? :ready : nil
end
box = $windows.last
check("the box opens centred below the top with the text and the seconds, and closes once answered",
      [answer, [box.x, box.y, box.width, box.height, box.z], box.contents.lines, $frames, box.disposed?],
      [:ready, [140, 120, 360, 96, 250], { 0 => "Waiting for the party...", 2 => "0 s" }, 2, true])
check("the battle's windows are held during the wait and given back after", [held, command.active], [false, true])

names = ["A", "B"]
turns = 0
seen = []
waiting.wait_for(scene, "Waiting for the party's commands...", lambda { names }, "Still choosing: ") do
  turns += 1
  seen << $windows.last.contents.lines[1] if turns > 1
  names = ["B"] if turns == 2
  names = nil if turns == 3
  turns == 4 ? :done : nil
end
check("the names line says whom the wait is for, redrawn as they shrink and cleared once nobody is left",
      [seen, $windows.last.contents.draws[1]], [["Still choosing: A, B", "Still choosing: B", nil], 2])

$frames = 0
$log.clear
turns = 0
seen = []
answer = waiting.wait_for(scene, "Slow") do
  turns += 1
  seen << $windows.last.contents.lines[2] if [2, 61, 62, 122, waiting::LEAVE_FRAMES + 2].include?(turns)
  $leave = true if turns == waiting::LEAVE_FRAMES + 2
  nil
end
check("the seconds are drawn once a second until the leave offer takes the line, and cancel then leaves",
      [answer, seen, $windows.last.contents.draws[2]], [:left, ["0 s", "0 s", "1 s", "2 s", waiting::LEAVE_TEXT], waiting::LEAVE_FRAMES / MGQ_MpUi::FRAMES_PER_SECOND + 1])
check("the offer and the leave are logged once",
      [$log.grep(/still waiting after 10 s \(Slow\), Cancel now leaves the battle/).size, $log.grep(/the player left the battle during the wait \(Slow\)/).size], [1, 1])
$leave = false

sync::Channel.receive(2, "forfeit", "")
check("a battle's ending ends the wait and closes the box", [waiting.wait_for(scene, "Ending") { nil }, $windows.last.disposed?], [:forfeit, true])

sync.finish
sync.join_world(:host, "w2", [2], "the party")
$log.clear
turns = 0
waiting.wait_for(scene, "Odd", lambda { raise "boom" }) { (turns += 1) == 3 ? :ok : nil }
check("a details that fails is logged once and the names line stays empty, the wait going on",
      [$log.grep(/the waiting box could not name whom it waits for: RuntimeError: boom/).size, $windows.last.contents.lines[1], turns], [1, nil, 3])
sync.finish

# Who the box names by seat.
check("seat_name names the player, a known peer and an unknown seat", [sync.seat_name(0), sync.seat_name(2), sync.seat_name(7)], ["you", "Player A", "seat 7"])
at = peers.method(:at)
peers.define_singleton_method(:at) { |_seat| raise "gone" }
check("and the seat alone when the peers cannot be read", sync.seat_name(2), "seat 2")
peers.define_singleton_method(:at, at)

# The playback's path: open, leave? and close without a wait.
box = waiting.open("Waiting for Host...", lambda { ["A"] }, "Still choosing: ")
waiting.refresh(box, -1)
check("the three-argument open draws the text and names, and frames below 0 draw no seconds", box.window.contents.lines, { 0 => "Waiting for Host...", 1 => "Still choosing: A" })
check("leave? before the offer says no", waiting.leave?(box, 5), false)
check("close disposes the box and returns nil, also for none", [waiting.close(box), box.window.disposed?, waiting.close(nil)], [nil, true, nil])

# The host's wait for the commands names who still chooses, and tells the guests, whose boxes
# name them too.
live = sync::Live
peers.all.replace([peers::Peer.new(2, { "name" => "Player A" }, nil, false), peers::Peer.new(3, { "name" => "Player B" }, nil, false)])
$my_seat = 0
sync.join_world(:host, "w4", [2, 3], "the party")
sync.battle_started
live.instance_variable_set(:@answered, [])
live.forget_waiting
$sent.clear
$frames = 0
seen = []
commands = sync::Wire.line([[]])
$inject = lambda do |frame|
  seen << $windows.last.contents.lines[1] if [2, 5].include?(frame)
  sync::Channel.receive(2, "commands", commands) if frame == 3
  sync::Channel.receive(3, "commands", commands) if frame == 6
end
answer = live.host_guests_commands(scene)
$inject = nil
check("the host's wait for the commands names who still chooses", [answer, seen], [true, ["Still choosing: Player A, Player B", "Still choosing: Player B"]])
check("and tells the guests whom it waits for as that changes, nobody once answered",
      $sent.map { |seat, text| [seat, fields_of(text)] }.select { |_, f| f["battle"] == "waiting" }.map { |seat, f| [seat, f[:payload]] },
      [[2, "2,3"], [3, "2,3"], [2, "3"], [3, "3"], [2, ""], [3, ""]])
sync.finish

# A guest names whom the host waits for, as the host last told, itself left out.
$my_seat = 2
peers.all.replace([peers::Peer.new(0, { "name" => "Host" }, nil, false), peers::Peer.new(3, { "name" => "Player B" }, nil, false)])
sync.join_world(:guest, "w5", [0], "Host")
sync.battle_started
live.forget_waiting
check("a guest names nobody before the host told", live.host_waits_for, [])
sync::Channel.receive(0, "waiting", "0,2,3")
sync::Channel.receive(0, "waiting", "2,3")
check("then whom the host last told, itself left out", [live.host_waits_for, sync::Channel.pending("waiting")], [["Player B"], 0])
sync::Channel.receive(0, "waiting", "")
check("and nobody once the host answered everyone", live.host_waits_for, [])

# The guest's box while the host's stream stalls names them too.
playback.reset
sync::Channel.receive(0, "waiting", "0,3")
$frames = 0
$leave = false
seen = nil
$inject = lambda do |frame|
  seen = $windows.last.contents.lines.dup if frame == sync::QUIET_FRAMES + 2
  $leave = true if frame == sync::QUIET_FRAMES + waiting::LEAVE_FRAMES + 2
end
outcome = playback.run(scene)
$inject = nil
$leave = false
check("the guest's box while the host's stream stalls names whom the host waits for, with the seconds",
      [outcome, seen, sync::Channel.pending("waiting")], [[:left], { 0 => "Waiting for Host...", 1 => "Still choosing: Host, Player B", 2 => "0 s" }, 0])
sync.finish
