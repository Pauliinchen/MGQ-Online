#----------------------------------------------------------------
#  battles_sync_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Expected the messages sent as the scripts hand them
#                            - Answered the live battle's topics with the values each case sets and checked what the scripts ask instead of a copy of the C# rules
#                            - Numbered the messages and asked again with the number in its field
#                            - Checked what the script makes of another game's values and left out a send the DLL did not check, through the codec's stand-in
#                            - Checked that the guest gives a state the host added or took away its counters through the game's own reset and erase
#      Paulinchen  2026-11-01: Read the waiting box from its box of the Mod Framework, its leave offer naming the bound cancel key and taking a click
#      Paulinchen  2026-10-31: Answered the leave question a frame later, as the Mod Framework collects it at the wait's frame
#                            - Checked that the numpad's 0 with Num Lock off asks before leaving, the offer naming the keys that cancel
#      Paulinchen  2026-10-30: Checked the recording's stand-in against its golden steps
#                            - Checked the stand-in of the command plan and the team duel's sides against their golden cases
#                            - Checked the session's stand-in against its golden cases and the host's waits on it
#                            - Checked the host's stream through the stand-in of the DLL's intake, held against its golden cases
#      Paulinchen  2026-10-28: Checked the host's picture and screen calls through the stand-in of the DLL
#      Paulinchen  2026-10-23: Dropped the check of the battle end kept on file
#                            - Checked that Cancel during a wait goes back or asks before leaving
#                            - Checked that messages lost over a reconnect come again, once and in order
#                            - Checked that a battle keeps its players through seats dealt anew and while away
#      Paulinchen  2026-10-15: Checked that a co-op enemy the host defeats counts as fallen on the guest for its recruit
#      Paulinchen  2026-10-12: Checked that the wire reads hostile lines safely
#                            - Checked failing names, stream lines and mode messages, and a time stop without a battler
#                            - Checked the host's cut-ins and picture and screen calls on the guest
#                            - Checked that enemies falling during the wait for commands win the battle once
#                            - Checked the host's skip settings at the battle's end and a held message skip
#      Paulinchen  2026-10-11: Checked the waiting box in the layout
#                            - Checked the waiting box's lines, leave offer, seat names and the playback's path
#                            - Checked that the wait for commands names who still chooses, on host and guests
#                            - Read the opened windows from battle_support.rb
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

# The game's settings, with the skip settings a live battle's host turns off.
class Game_System
  attr_reader :conf
  def initialize; @conf = { :bt_skip => true, :bt_skip_cutin => 1, :skip_skill_effect => false }; end
end
# A state of the database, known by its id alone.
StateStub = Struct.new(:id)
# An actor with the values the recorder reads and the playback sets.
class Game_Actor
  attr_accessor :tp, :state_list, :result
  def actor?; true; end
  def states; @state_list || []; end
  def defence_wall; 2; end
  def refresh; end
end
# An enemy with the values the recorder reads and the playback sets.
class Game_Enemy
  attr_accessor :sprite_effect_type, :hp, :mp, :tp
  def actor?; false; end
  def states; []; end
end
# The party, noting the ids of the items it uses up in $consumed.
class Game_Party
  attr_accessor :od_turn, :od_user
  def name; "Party"; end
  def consume_item(item); ($consumed ||= []) << item.id; end
end
# A battler's action result, with the damage it took.
class Game_ActionResult
  attr_accessor :hp_damage
  def initialize(battler = nil); @battler = battler; @hp_damage = 0; end
end
# A wrapped database item, as the game's equipment and actions hold one.
class Game_BaseItem; attr_accessor :object; end
# The game's message, which has text while $game_message_texts holds any.
class Game_Message
  attr_accessor :face_name, :face_index, :background, :position
  def has_text?; !($game_message_texts || []).empty?; end
end
# The guest's battle log, whose line draws a random number as the host's call did.
class BattleLog
  attr_reader :lines
  def display_damage(target); (@lines ||= []) << [target, rand(1000)]; end
end
# The troop, whose one enemy name is Slime.
class Game_Troop; def enemy_names; ["Slime"]; end; end
# The battle scene, counting the turns started in $turns_started.
class Scene_Battle
  def battle_start; end
  def turn_start; $turns_started += 1; end
  def update; end
  def command_escape; end
  def wait_for_message; end
end
# The input, holding the button in $held.
module Input
  def self.press?(button); $held == button; end
  def self.update; end
end
# The plain message window.
class PlainMessageWindow; attr_accessor :pause; end
# The newer translation's message window, with its result skip setting.
class SkipMessageWindow < PlainMessageWindow
  attr_accessor :message_skip_mode
  def initialize(mode); @message_skip_mode = mode; end
  # Tells whether a key passes the message: the skip counts held from Slow on, tapped below.
  def message_pause_input
    Input.trigger?(:B) || Input.trigger?(:C) || (message_skip_mode >= 1 ? Input.press?(:X) : Input.trigger?(:X))
  end
end
# Counts judgements in $judged, each ending the battle once every enemy fell, as the game's victory
# does.
module BattleManager; def self.judge_win_loss; $judged = $judged.to_i + 1; $ending = true if $game_troop.all_dead?; true; end; end
# The game's messages of how a battle begins.
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
sync::Hooks.ending
sync.join_world(:host, "s1b", [2], "the party")
sync.show_everything
$log.clear
$game_party.own = []
BattleManager.battle_end(0)
$game_party.own = nil
check("the host has its own settings back as the battle ends, before the victory autosave writes them",
      $game_system.conf, { :bt_skip => true, :bt_skip_cutin => 1, :skip_skill_effect => false })
sync.finish
check("which the end of the live battle puts back no second time", $log.grep(/put the skip settings back/).size, 1)

# A held message skip passes a live battle's message.
sync.join_world(:host, "s1c", [2], "the party")
sync.battle_started
# Waits out a message as the game's message window does.
#
# @param window [PlainMessageWindow] The message window.
# @param frames [Integer] The frames to run at most.
# @return [Array] The frames the message stayed, nil while it still waits, and whether it pauses.
pass = lambda do |window, frames|
  fiber = Fiber.new { sync::Live.pass_message(window) }
  waited = (0..frames).find { fiber.resume; !fiber.alive? }
  [waited, window.pause]
end
$held = :X
check("a held message skip passes a battle message at once", pass.call(PlainMessageWindow.new, 0), [0, nil])
check("during the victory results too when the result skip is Instant", pass.call(SkipMessageWindow.new(3), 0), [0, nil])
check("after the game's 10 frames when it is Slow or Fast", [pass.call(SkipMessageWindow.new(1), 20), pass.call(SkipMessageWindow.new(2), 20)], [[10, false], [10, false]])
check("and never while it is No Skip", pass.call(SkipMessageWindow.new(0), 20), [nil, true])
$held = nil
check("without the skip a message stays", pass.call(PlainMessageWindow.new, 20), [nil, true])
check("until it moves on by itself", pass.call(PlainMessageWindow.new, sync::MESSAGE_FRAMES), [sync::MESSAGE_FRAMES, false])
window = PlainMessageWindow.new
fiber = Fiber.new { sync::Live.pass_message(window) }
fiber.resume
$held = :X
fiber.resume
check("or the skip is held while it waits", [fiber.alive?, window.pause], [false, false])
broken = SkipMessageWindow.new(nil)
check("a message whose window fails to tell its skip moves on", [pass.call(broken, 0), $log.grep(/could not hold a battle message, it moves on: NoMethodError/).size], [[0, false], 1])
$held = nil
sync.finish

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
$live.change_view("solo" => true)
$live.set("live.phase close", true)
$turns_started = 0
$log.clear
scene.turn_start
check("a host left alone plays its turn and closes the phase, so the next one settles who fights on",
      [$turns_started, $live.asked("live.phase").last, $log.grep(/command phase closed, turn \d+ starts, the computer playing for those who left/).size], [1, { "op" => "close" }, 1])
sync.finish
check("a command phase the battle ended in closes as the battle finishes", $log.grep(/command phase of turn \d+ closed: the battle ended in it/).size, 1)
$live.set("live.phase close", nil)

# A defeat's sprite effect.
class Game_Troop; attr_accessor :dead_enemies; end
$game_troop.dead_enemies = []
monster = $game_troop.members[0]
sync.join_world(:guest, "s4", [0], "Host")
playback.sprite_effect(monster, :collapse)
check("a co-op monster the host's battle defeats falls on the guest too", monster.sprite_effect_type, :collapse)
check("and counts as fallen there, so the player's own victory offers her as a recruit", $game_troop.dead_enemies, [monster])
sync.finish
sync.join_world(:guest, "s5", [0], "Host", :pvp)
playback.sprite_effect(monster, :collapse)
check("a PvP opponent stays as a silhouette", monster.sprite_effect_type, :whiten)
check("and no player of the other side is offered as a recruit", $game_troop.dead_enemies, [monster])
sync.finish

# Items the host's battle used up of the guest's bag.
$consumed = []
playback.use_up(Game_Actor.new(1), $data_items[3])
playback.use_up(Game_MpActor.new(MGQ_MpActors::Builds::Member.new(2), "Friend"), $data_items[4])
playback.use_up(Game_Actor.new(1), $data_skills[3])
playback.use_up(nil, $data_items[5])
check("the guest uses up the items its own characters used, and nothing else", $consumed, [3])

# Takes events through the DLL's intake of the host's stream, as one send.
#
# @param events [Array<Array>] The events.
# @return [Array<Array>] The events the guest plays.
taken = lambda do |*events|
  playback.reset
  playback.take_send(events.map { |event| wire_line(event) }.join("\n"))
  kept = playback.instance_variable_get(:@events)
  playback.instance_variable_set(:@events, [])
  kept
end

# The host's calls the guest makes, which the DLL's intake keeps from the lists the guest hands it.
sync::Hooks.instance_variable_set(:@log_calls, ["display_damage"])
calls = taken.call(["call", "log", "display_damage", 1, nil, []], ["call", "log", "display_unheard_of", 1, nil, []])
lists = $live.asked("live.guest_setup").last["lists"]
check("the guest hands the DLL's intake the battle log calls the hooks list and the scene calls it makes itself",
      [lists["log_calls"], lists["scene_calls"].include?("process_skill_word")], [["display_damage"], true])
check("never making a symbol of the host's text", [calls.map { |event| event[2] }, Symbol.all_symbols.map(&:to_s).include?("display_unheard_of")], [["display_damage", "display_unheard_of"], false])

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
# A state without the counters the game keeps per state ended a guest's game at a turn's end on
# the map (the crash of 2026-10-07): the game's own reset of a state's counts gives them.
check("with the counters the game keeps per state, which a turn's end on the map reads", [target.instance_variable_get(:@state_turn_counts), target.instance_variable_get(:@state_steps)], [{ 4 => 0 }, { 4 => 0 }])
check("with the barriers", target.instance_variable_get(:@cnt)[:defense_wall], [true, true])
playback.values(target, 50, 5, 0, [], [], [0] * 8, 2)
check("a state the host took away loses its counters through the game's own erase",
      [MGQ_MpGame.get(target, :states), target.instance_variable_get(:@state_turn_counts), target.instance_variable_get(:@state_steps)], [[], {}, {}])

# The host's HP above this game's own maximum, which the game's refresh holds a character below.

# An actor whose refresh holds its HP at its maximum of 100, as the game's does.
class ClampingActor < Game_Actor
  def mhp; 100; end
  def refresh; @hp = [@hp, mhp].min; end
end
strong = ClampingActor.new(8)
$log.clear
playback.values(strong, 500, 5, 0, [4], [1], [0] * 8, 0)
check("the guest keeps the host's HP even above its own maximum, after the game read the features anew", strong.hp, 500)
check("and logs the difference once", $log.grep(/Actor8 has 500 HP on the host, above this game's maximum of 100/).size, 1)

# A whole turn goes from the host's recorder through the DLL to the guest's playback: the
# battlers' values, a call with its seed, a message, who appears and the end.
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
$live.set("live.record flush", "sends" => ["the turn"])
recorder.start
recorder.values
foe.result = Game_ActionResult.new
foe.result.hp_damage = 25
recorder.call("log", "display_damage", [foe]) { $host_draw = rand(1000) }
recorder.event("message", nil, "Face", 1, 0, 2, "Take that!")
recorder.instead("emerge", true, false) { $host_emerged = true }
recorder.event("end", "process_victory", 0, 0)
recorder.flush
$live.set("live.record flush", nil)
recorded = $live.asked("live.record").drop_while { |request| request["op"] != "start" }
stream = $sent.select { |_, f| f["battle"] == "events" }
check("the host hands the DLL's recording every battler's values and each event as values",
      [recorded.map { |request| request["op"] == "event" ? request["values"][0] : request["op"] }, recorded[1]["battlers"].map { |_key, ref, values| [ref, values[0]] }],
      [["start", "values", "time_stop", "values", "call", "message", "emerge", "end", "flush"],
       [["a0", 100], ["a1", 100], ["e0", 40], ["e1", 40]]])
check("and streams the send the DLL lets go to its guest", stream.map { |seat, f| [seat, f["bid"], f[:payload]] }, [[2, "r1", "the turn"]])
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
# The DLL hands the guest the host's events as recorded, each battler's values a line of its own.
lines = recorded.flat_map do |request|
  case request["op"]
  when "values" then request["battlers"].map { |_key, ref, values| ["values", { "battler" => ref }] + values }
  when "event" then [request["values"]]
  else []
  end
end
$live.set("live.take_stream", "lines" => lines, "events" => lines.size, "unreadable" => 0, "others_choose" => 0, "logs" => [])
sync::Channel.receive(0, "events", "the turn")
outcome = playback.run(scene)
$live.set("live.take_stream", nil)
check("the guest hands the DLL the host's send with its own seat", $live.asked("live.take_stream").last, { "body" => "the turn", "seat" => 2 })
check("and plays the turn up to the host's end", outcome, ["end", "process_victory", 0, 0])
check("the battlers have the host's values", [hero.hp, MGQ_MpGame.get(hero, :states), MGQ_MpGame.get(hero, :state_turns), $game_troop.members.map(&:hp)], [100, [4], { 4 => 3 }, [40, 40]])
check("the guest's own call draws the host's random number, with the host's action result", [scene.instance_variable_get(:@log_window).lines, foe.result.hp_damage], [[[foe, $host_draw]], 25])
check("the message and who appears show in the guest's language", $game_message_texts, ["Take that!", "Slime appears!", "Party struck first!"])
check("and the host's party struck first for the guest's command phase too", [$game_message.face_name, $game_message.face_index, playback.instance_variable_get(:@encounter)], ["Face", 1, [true, false]])
sync.finish

# The waiting box: what the game waits for, whom it still waits for and for how long, the leave
# offer, and the battle's windows held meanwhile.
waiting = sync::Waiting
# A battle window that notes whether it is active.
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

# The waiting box's root of the Mod Framework, nil while none is open.
waiting_root = lambda { Mod_Framework::UI::Tree.roots.find { |root| root.id == :waiting_box } }
check("a wait answered at once opens no box", [waiting.wait_for(scene, "Now") { :now }, waiting_root.call], [:now, nil])

turns = 0
held = nil
shown = nil
opened = nil
answer = waiting.wait_for(scene, "Waiting for the party...") do
  turns += 1
  held = command.active if turns == 2
  if turns == 3
    opened = waiting_root.call
    shown = waiting_lines
  end
  turns == 3 ? :ready : nil
end
check("the box opens framed, centred below the top, movable and widened only, with the text and the seconds, and closes once answered",
      [answer, opened.frame, opened.at, opened.size, opened.movable, opened.resizable, shown, $frames, opened.open?],
      [:ready, true, [140, 120], [360, 96], true, :width, { 0 => "Waiting for the party...", 2 => "0 s" }, 2, false])
check("the battle's windows are held during the wait and given back after", [held, command.active], [false, true])

names = ["A", "B"]
turns = 0
seen = []
waiting.wait_for(scene, "Waiting for the party's commands...", lambda { names }, "Still choosing: ") do
  turns += 1
  seen << waiting_lines[1] if turns > 1
  names = ["B"] if turns == 2
  names = nil if turns == 3
  turns == 4 ? :done : nil
end
check("the names line says whom the wait is for, set anew as they shrink and cleared once nobody is left",
      seen, ["Still choosing: A, B", "Still choosing: B", nil])

$frames = 0
$log.clear
turns = 0
seen = []
$asked = []
$confirm = nil
offer_turn = waiting::LEAVE_FRAMES + 2
leave_button = nil
answer = waiting.wait_for(scene, "Slow") do
  turns += 1
  seen << waiting_lines[2] if [2, 61, 62, 122, offer_turn].include?(turns)
  leave_button ||= waiting_root.call.children[3] if turns == offer_turn
  # Cancel before the offer, then at the offer answered "Stay", then a click on the offer answered
  # "Leave"; an answer reaches the wait at its next frame.
  $leave = [5, offer_turn].include?(turns)
  leave_button.send(:emit, :click) if turns == offer_turn + 4
  $confirm = { offer_turn + 2 => false, offer_turn + 5 => true }[turns]
  nil
end
check("the seconds are set once a second until the leave offer takes the line, naming the cancel key as bound, and only a confirmed leave leaves",
      [answer, seen, $asked], [:left, ["0 s", "0 s", "1 s", "2 s", "Press X to leave the battle."], [[waiting::LEAVE_QUESTION, waiting::LEAVE_CHOICES]] * 2])
check("the leave offer is a button, which a click asks as cancel does", [leave_button.class, leave_button.text], [Mod_Framework::UI::Button, "Press X to leave the battle."])
check("the offer, the question, staying and the leave are logged",
      [$log.grep(/still waiting after 10 s \(Slow\), cancel now asks whether to leave the battle/).size, $log.grep(/asked the player whether to leave/).size,
       $log.grep(/the player stays in the battle/).size, $log.grep(/the player left the battle during the wait \(Slow\)/).size], [1, 2, 1, 1])
$leave = false
$confirm = nil

$live.set("live.tick ending", "ending" => "forfeit")
check("an ending the DLL tells ends the wait and closes the box", [waiting.wait_for(scene, "Ending") { nil }, waiting_root.call], [:forfeit, nil])
$live.set("live.tick ending", nil)

sync.finish
sync.join_world(:host, "w2", [2], "the party")
$log.clear
turns = 0
names_seen = :none
waiting.wait_for(scene, "Odd", lambda { raise "boom" }) do
  names_seen = waiting_lines[1] if turns == 1
  (turns += 1) == 3 ? :ok : nil
end
check("a details that fails is logged once and the names line stays empty, the wait going on",
      [$log.grep(/the waiting box could not name whom it waits for: RuntimeError: boom/).size, names_seen, turns], [1, nil, 3])
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
check("the three-argument open sets the text and names, and frames below 0 set no seconds", waiting_lines, { 0 => "Waiting for Host...", 1 => "Still choosing: A" })
check("leave? before the offer says no", waiting.leave?(box, 5), false)
check("close closes the box and returns nil, also for none", [waiting.close(box), box.root.open?, waiting.close(nil)], [nil, false, nil])

# The waiting box in the layout: never narrower than its lines need.
leave_width = waiting.offer(waiting::LEAVE_LOSES_TEXT).size * 8 + 2 * waiting::PADDING
box = waiting.open("Now")
check("the waiting box is known to the layout by its name, resized in width alone, as wide at least as its longest leave offer needs",
      [registered_box(:waiting_box), box.root.min_size], [["Waiting box", leave_width, waiting::HEIGHT, :width], [leave_width, waiting::HEIGHT]])
waiting.close(box)
long = "Waiting for the whole party's commands, all of them, every one..."
box = waiting.open(long)
check("and as its text needs, as far as its width where it starts", [box.root.min_size[0], waiting.least_width(["x" * 100])], [waiting::WIDTH, waiting::WIDTH])
waiting.close(box)

# A reconnect that deals the world's seats anew keeps the battle: the guest who comes back on the
# host's old seat is the same guest, the host keeps its own seat in the battle, a guest away is
# waited for, and only the world's word that they are gone takes them out.
peers.all.replace([peers::Peer.new(2, { "id" => "id-a", "name" => "Player A" }, nil, false)])
$my_seat = 0
sync.join_world(:host, "w9", [2], "the party")
sync.battle_started
guest = peers.all.first
$my_seat = 2
guest.seat = 0
$sent.clear
sync::Channel.post("ready")
sync.take(guest, { "battle" => "commands", "bid" => "w9", :payload => "c1" })
check("after the seats were dealt anew the host sends to the guest's new seat and takes their messages as before",
      [$sent.map(&:first), sync::Channel.take_from("commands", 2), sync.own_seat, sync.player_seats], [[0], "c1", 0, [2]])
check("and the battle goes on with them", [sync::Channel.world_gone?, sync.guests_in], [false, [2]])
$world_bridge.answer("live.admit") { |_request| nil }
$log.clear
sync.take(guest, { "battle" => "commands", "bid" => "w9", :payload => "c2" })
check("a message the DLL does not check is left out, logged", [sync::Channel.take_from("commands", 2), $log.grep(/commands: the DLL did not check it/).size], [nil, 1])
$world_bridge.answer("live.admit") { |request| $live.answer("live.admit", request) }
guest.away = 900
$sent.clear
sync::Channel.post("ready")
check("a guest away is sent nothing and stays in the battle", [$sent, sync::Channel.world_gone?, sync.guests_in], [[], false, [2]])
guest.away = nil
sync::Seats.presence(guest, :gone)
peers.all.clear
$live.set("live.tick world", "ending" => "gone", "left" => [2], "departed" => [[2, 0]])
check("the world telling they are gone goes to the DLL, which takes them out",
      [sync::Channel.world_gone?, $live.asked("live.tick").last["gone"], sync.guests_in], [true, [2], []])
$live.set("live.tick world", nil)
sync.finish
check("and the battle's seats are forgotten as it finishes", sync.own_seat, 2)
$my_seat = 0

# Messages lost over a reconnect come again: each carries its number, whoever sees a player come
# back asks for what came after the last number taken, and each number is taken once and in order.
peers.all.replace([peers::Peer.new(2, { "id" => "id-a", "name" => "Player A" }, nil, false)])
sync.join_world(:host, "w10", [2], "the party")
sync.battle_started
guest = peers.all.first
numbered = lambda { |number, kind, body| sync.take(guest, { "battle" => kind, "bid" => "w10", "sq" => number, :payload => body }) }
numbered.call(1, "ready", "")
numbered.call(3, "commands", "c3")
numbered.call(2, "commands", "c2")
numbered.call(2, "commands", "c2")
check("numbered messages are taken once and in order",
      [sync::Channel.take_from("ready", 2), (1..3).map { sync::Channel.take_from("commands", 2) }], ["", ["c2", "c3", nil]])
guest.away = 900
$sent.clear
sync::Channel.post("waiting", "0")
sync::Channel.post("events", "e1")
guest.away = nil
guest.seat = 5
sync::Sequence.presence(guest, :back)
asked = $sent.map { |seat, message| [seat, message["battle"], message["sq"]] }
check("messages to a guest away wait, and the guest back is asked for what they sent after the last taken",
      asked, [[5, "resync", 3]])
$sent.clear
sync.take(guest, { "battle" => "resync", "bid" => "w10", "sq" => 0, :payload => "" })
check("a guest who asks again gets the messages after the last they took, numbered as before",
      $sent.map { |seat, message| [seat, message["battle"], message["sq"]] }, [[5, "waiting", 1], [5, "events", 2]])
$frames = 0
numbered.call(5, "commands", "c5")
check("a message after one that never came is held", sync::Channel.take_from("commands", 2), nil)
$frames = 900
check("until the world's grace ran out, then taken", sync::Channel.take_from("commands", 2), "c5")
sync.finish

# The host's wait for the commands names who still chooses, and tells the guests, whose boxes
# name them too.
live = sync::Live
peers.all.replace([peers::Peer.new(2, { "name" => "Player A" }, nil, false), peers::Peer.new(3, { "name" => "Player B" }, nil, false)])
$my_seat = 0
sync.join_world(:host, "w4", [2, 3], "the party")
sync.battle_started
live.forget_waiting
$sent.clear
$frames = 0
seen = []
commands = wire_line([[]])
$inject = lambda do |frame|
  seen << waiting_lines[1] if [2, 5].include?(frame)
  sync::Channel.receive(2, "commands", commands) if frame == 3
  sync::Channel.receive(3, "commands", commands) if frame == 6
end
answer = live.host_guests_commands(scene)
$inject = nil
check("the host's wait for the commands names who still chooses", [answer, seen], [true, ["Still choosing: Player A, Player B", "Still choosing: Player B"]])
tells = $live.asked("live.phase").select { |request| request["op"] == "tell" }.map { |request| request["seats"] }
posted = $sent.select { |_, f| f["battle"] == "waiting" }.map { |seat, f| [seat, f[:payload]] }
check("and asks the DLL to tell the guests whom it waits for, nobody once answered, posting each tell to every guest",
      [tells.chunk_while { |a, b| a == b }.map(&:first), posted.chunk_while { |a, b| a == b }.map(&:first).uniq],
      [[[2, 3], [3], []], [[2, "2,3"], [3, "2,3"], [2, "3"], [3, "3"], [2, ""], [3, ""]]])
sync.finish

# Cancel while the host waits for the commands goes back to the host's own commands, keeping the
# commands that came, as players press it to choose again; only a confirmed leave leaves.
sync.join_world(:host, "w4e", [2, 3], "the party")
sync.battle_started
live.forget_waiting
steps = $live.asked("live.phase").size
$sent.clear
$frames = 0
$commands_phase = false
$actor_cleared = false
$inject = lambda do |frame|
  sync::Channel.receive(2, "commands", commands) if frame == 1
  $leave = frame == 3
end
answer = live.host_guests_commands(scene)
$inject = nil
$leave = false
told = $sent.select { |seat, f| seat == 2 && f["battle"] == "waiting" }.map { |_, f| f[:payload] }
check("a single Cancel while the host waits for the commands goes back to the host's own, keeping those that came",
      [answer, $commands_phase, $actor_cleared, $live.asked("live.phase").drop(steps).select { |request| request["op"] == "answer" }.map { |request| request["seat"] }], [false, true, true, [2]])
check("and leaves nothing, the guests seeing the host choose again",
      [$sent.any? { |_, message| %w(leave forfeit).include?(message["battle"]) }, told.last], [false, "0,3"])
sync.finish

sync.join_world(:host, "w4f", [2], "the party")
# The numpad's 0 with Num Lock off, which $numpad_off presses.
key = Mod_Framework::UI::Key
triggered = key.method(:triggered?)
key.define_singleton_method(:triggered?) { |code| (code == Mod_Framework::UI::NUMPAD_ZERO[1] && $numpad_off) || triggered.call(code) }
wait_back = lambda do |leave, numpad = false|
  $asked = []
  $frames = 0
  $inject = lambda do |frame|
    $offer_seen = waiting_lines[2] if frame == waiting::LEAVE_FRAMES + 1
    $leave = !numpad && frame == waiting::LEAVE_FRAMES + 2
    $numpad_off = numpad && frame == waiting::LEAVE_FRAMES + 2
    $confirm = leave if frame == waiting::LEAVE_FRAMES + 4
  end
  answer = waiting.wait_for(scene, "Waiting for the party's commands...", nil, waiting::WAITING_PREFIX, true) { nil }
  $inject = nil
  $leave = false
  $numpad_off = false
  $confirm = nil
  [answer, $asked, $offer_seen]
end
check("past the offer cancel asks first, and choosing again goes back",
      wait_back.call(false), [:back, [[waiting::LEAVE_QUESTION, waiting::BACK_CHOICES]], "Press X to choose again or leave."])
check("while a confirmed leave leaves", wait_back.call(true)[0], :left)
check("the numpad's 0 with Num Lock off asks as Cancel does", wait_back.call(true, true)[0, 2], [:left, [[waiting::LEAVE_QUESTION, waiting::BACK_CHOICES]]])
sync.finish

# Enemies that fall while the host waits for the commands, as a Raid World's pools kill them, win
# the battle at once, and the turn the host waited in never starts.
$live.set("live.end early", "process" => "win", "reason" => "its enemies fell while it waited for commands")
fall_in_wait = lambda do |bid, seats|
  sync.join_world(:host, bid, seats, "the party")
  sync.battle_started
  $frames = 0
  $judged = 0
  $turns_started = 0
  $ending = false
  open = []
  $inject = lambda do |frame|
    open << waiting.active?
    $game_troop.members.each { |enemy| enemy.dead = true } if frame == 3
  end
  scene.turn_start
  $inject = nil
  result = [$turns_started, $judged, $frames, open.uniq, waiting.active?]
  $game_troop.members.each { |enemy| enemy.dead = false }
  $ending = false
  sync.finish
  result
end
check("enemies that fall while the host waits for the party's commands win once, the turn never starting",
      fall_in_wait.call("w4b", [2, 3]), [0, 1, 3, [true], false])
check("as while it waits for one guest's commands", fall_in_wait.call("w4c", [2]), [0, 1, 3, [true], false])
check("and the wait ends as won, as the DLL decides", [$live.asked("live.end").last(2).map { |request| request["reason"] }, $log.grep(/ends early in turn \d+: its enemies fell while it waited for commands/).size],
      [["won", "won"], 2])
$live.set("live.end early", nil)
sync.join_world(:host, "w4d", [2], "the party")
sync.battle_started
$live.change_view("solo" => true)
$turns_started = 0
$ending = true
scene.turn_start
$ending = false
check("a turn whose battle ended before it starts is left out", [$turns_started, $log.grep(/the battle ended before turn \d+ started/).size], [0, 1])
sync.finish

# A guest names whom the host waits for, as the host last told, itself left out.
$my_seat = 2
peers.all.replace([peers::Peer.new(0, { "name" => "Host" }, nil, false), peers::Peer.new(3, { "name" => "Player B" }, nil, false)])
sync.join_world(:guest, "w5", [0], "Host")
sync.battle_started
live.forget_waiting
check("a guest names nobody before the host told", live.host_waits_for, [])
$live.set("live.phase host_waiting", "taken" => [[0, 2, 3], [2, 3]], "seats" => [2, 3])
$log.clear
check("then whom the DLL says the host last told, itself left out, each word logged",
      [live.host_waits_for, $log.grep(/the host still waits for/).size], [["Player B"], 2])
$live.set("live.phase host_waiting", "taken" => [[]], "seats" => [])
check("and nobody once the host answered everyone", live.host_waits_for, [])

# The guest's box while the host's stream stalls names them too.
playback.reset
$live.set("live.phase host_waiting", "taken" => [], "seats" => [0, 3])
$frames = 0
$leave = false
seen = nil
$asked = []
$inject = lambda do |frame|
  seen = waiting_lines if frame == sync::QUIET_FRAMES + 2
  $leave = frame == sync::QUIET_FRAMES + waiting::LEAVE_FRAMES + 2
  $confirm = true if $leave
end
outcome = playback.run(scene)
$inject = nil
$leave = false
$confirm = nil
$live.set("live.phase host_waiting", nil)
check("the guest's box while the host's stream stalls names whom the host waits for, with the seconds",
      [outcome, seen], [[:left], { 0 => "Waiting for Host...", 1 => "Still choosing: Host, Player B", 2 => "0 s" }])
check("and the guest leaves only once it confirmed leaving", $asked, [[waiting::LEAVE_QUESTION, waiting::LEAVE_CHOICES]])
sync.finish

# What another game's values name that this game lacks becomes nil, never a symbol made of its text.
# Makes this game's objects of the values the DLL read of a line.
#
# @param values [Array] The plain values.
# @return [Array] The objects.
read = lambda { |*values| sync::Wire.objects(values) }
base = read.call("base_item" => { "skill" => 3 })[0]
check("an equipped item wraps the skill it names", [base.class, base.object], [Game_BaseItem, $data_skills[3]])
odd = read.call("result" => [["1x", 1]])[0]
check("an action result takes no field it lacks", [odd.class, odd.instance_variables.map(&:to_s).include?("@1x"), odd.hp_damage], [Game_ActionResult, false, 0])
read.call("symbol" => "hp_damage")
symbols = Symbol.all_symbols.size
check("a symbol this game lacks reads as unknown", read.call("symbol" => "zzz_never_seen_symbol_123"), [nil])
check("and is never made", [Symbol.all_symbols.size <= symbols, Symbol.all_symbols.map(&:to_s).include?("zzz_never_seen_symbol_123")], [true, false])
check("a symbol this game has reads back", read.call({ "symbol" => "hp_damage" }, { "action" => "count" }), [:hp_damage, sync::Wire::ActionKind.new(:count)])
check("a database id past the game's table reads as unknown", [read.call("skill" => 200), read.call(2**70)], [[nil], [2**70]])

# The host's names that fail to read leave every name as it is.
names = sync::Names
$game_party.own = [Game_Actor.new(1)]
$game_troop.members = [Game_Enemy.new(0, 31)]
names.setup(wire_line([["x"], []]))
setup = $live.asked("live.guest_setup").last
$live.set("live.swap", "Enemy31 and Actor1")
check("the guest hands the DLL the host's names with its own of the same places, the host's party being its troop in a duel, and shows texts as the DLL swaps them",
      [setup["names"], setup["own"], names.swap("x and Actor1"), $live.asked("live.swap").last], [wire_line([["x"], []]), [["Enemy31"], ["Actor1"]], "Enemy31 and Actor1", "x and Actor1"])
$live.set("live.swap", nil)
party_side = sync.method(:party_side)
sync.define_singleton_method(:party_side) { raise "broken" }
$log.clear
names.setup(wire_line([["x"], []]))
sync.define_singleton_method(:party_side, party_side)
check("the host's names that fail to read are shown unswapped, logged once",
      [names.swap("x"), $log.grep(/could not read the host's names, showing them unswapped: RuntimeError: broken/).size], ["x", 1])

# The guest leaves out a line of the host's stream or a message of the battle's mode that fails,
# and plays on with the rest.
$my_seat = 2
sync.join_world(:guest, "h1", [0], "Host")
sync.battle_started
playback.reset
playback.instance_variable_set(:@stats, Hash.new(0))
coop_mode = sync.mode
take = coop_mode.method(:take)
coop_mode.define_singleton_method(:take) { |*| raise "bad party" }
$log.clear
$live.set("live.mode kinds", ["coop_party"])
$live.set("live.take_stream", "lines" => [["turn", 3]], "events" => 1, "unreadable" => 2, "others_choose" => 0,
                              "logs" => [["unreadable_event", "left out an unreadable line of the host's stream"]] * 2)
sync::Channel.receive(0, "coop_party", "anything")
sync::Channel.receive(0, "events", "a send with two bad lines")
event = playback.next_event(scene)
coop_mode.define_singleton_method(:take, take)
$live.set("live.take_stream", nil)
$live.set("live.mode kinds", nil)
check("the guest plays the line the DLL keeps of a send with bad ones, counting them and logging the reason once",
      [event, playback.instance_variable_get(:@stats)[:unreadable], playback.instance_variable_get(:@stats)[:events], $log.grep(/left out an unreadable line/).size], [["turn", 3], 2, 1, 1])
check("and leaves out a message of the mode that fails, logged once", $log.grep(/left out the host's coop_party, which failed: RuntimeError: bad party/).size, 1)

# A send the DLL does not check is left out.
$world_bridge.answer("live.take_stream") { |_request| nil }
playback.reset
sync::Channel.receive(0, "events", "a send")
check("a send the DLL does not check is left out", playback.next_event(scene), nil)
$world_bridge.answer("live.take_stream") { |request| $live.answer("live.take_stream", request) }

# A time stop whose character is no battler here ends at once.
$game_party.od_turn = 0
$game_party.od_user = nil
$log.clear
playback.play(scene, ["time_stop", 5, "x"])
check("a time stop without a battler ends, logged", [$game_party.od_turn, $game_party.od_user, $log.grep(/ended the host's time stop of 5 turns/).size], [0, nil, 1])
playback.play(scene, ["time_stop", 5, hero])
check("a battler's time stop is taken", [$game_party.od_turn, $game_party.od_user], [5, hero])
$log.clear
playback.play(scene, ["time_stop", 0, nil])
check("and its end, without a log line", [$game_party.od_turn, $game_party.od_user, $log.grep(/time stop/).size], [0, nil, 0])

# The host's cut-ins and screen effects as the DLL keeps them; the DLL's checks are its own tests'.
Object.send(:remove_const, :MGQ_MpCoopScene)
load_script "coop_scene"
# A picture that notes what was done to it.
class Game_Picture
  attr_reader :done
  def initialize; @done = []; end
  def show(*args); @done << [:show, *args]; end
  def move(*args); @done << [:move, *args]; end
  def erase; @done << [:erase]; end
end
# A screen that notes its effects and makes its pictures as they are asked for.
class Game_Screen
  attr_reader :done, :pictures
  def initialize; @done = []; @pictures = Hash.new { |all, number| all[number] = Game_Picture.new }; end
  def start_flash(*args); @done << [:flash, *args]; end
  def start_shake(*args); @done << [:shake, *args]; end
end
# The troop, whose screen is made on first use.
class Game_Troop; def screen; @screen ||= Game_Screen.new; end; end
$log.clear
# Plays events as the guest takes them from the host's stream.
#
# @param events [Array<Array>] The events.
played = lambda { |*events| taken.call(*events).each { |event| playback.play(scene, event) } }
played.call(["picture.show", 3, "cutin_alice.v2", 0, 10, 20.5, 100, 100, 255, 0], ["picture.move", 3, 0, 10, 20, 100, 100, 0, 0, 30])
check("a cut-in whose name holds a dot shows and moves", $game_troop.screen.pictures[3].done.map(&:first), [:show, :move])
played.call(["picture.show", 3, "MissingFace", 0, 10, 20, 100, 100, 255, 0])
check("one this game lacks erases the picture's place instead", $game_troop.screen.pictures[3].done.last, [:erase])
played.call(["screen.start_flash", Color.new(255, 255, 255, 170), 20], ["screen.start_shake", 5, 5, 10])
check("the screen takes a flash of a color and a shake", $game_troop.screen.done.map(&:first), [:flash, :shake])
check("and nothing raised", $log.grep(/could not play/).size, 0)
sync.finish
