#----------------------------------------------------------------
#  battles_sync_test.rb
#
#  Changelog:
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

# The waiting box in the layout: where the player left it, at its width, never narrower than its
# lines need.
layout = MGQ_MpUi::Layout
stored = layout.instance_variable_get(:@stored)
registered = lambda { layout.instance_variable_get(:@boxes)[:waiting_box].to_a }
offered = lambda { (offer = layout.instance_variable_get(:@offers).find { |o| o.id == :waiting_box }) && offer.rect.to_a }
place = lambda { |text| $player_ini = text ? { "ui_waiting_box" => text } : {}; stored.delete(:waiting_box) }
leave_width = waiting::LEAVE_TEXT.size * 8 + 2 * waiting::PADDING
box = waiting.open("Now")
check("the waiting box is known to the layout by its name, resized in width alone, as wide at least as its leave offer needs",
      [registered.call, offered.call], [["Waiting box", leave_width, waiting::HEIGHT, :width], [140, 120, 360, 96]])
waiting.close(box)
long = "Waiting for the party's commands..."
box = waiting.open(long)
check("and as its text needs, as far as its width where it starts", [registered.call[1], waiting.least_width(box.window.contents, ["x" * 100])], [long.size * 8 + 24, waiting::WIDTH])
waiting.close(box)

place.call("10,300,500,0")
box = waiting.open("Waiting for Host...", lambda { ["Player A", "Player B"] }, "Still choosing: ")
waiting.refresh(box, 0)
window = box.window
check("a waiting box kept in Player.ini opens there at its width, draws its lines and offers itself to the layout",
      [[window.x, window.y, window.width, window.height], window.contents.lines, offered.call],
      [[10, 300, 500, 96], { 0 => "Waiting for Host...", 1 => "Still choosing: Player A, Player B", 2 => "0 s" }, [10, 300, 500, 96]])
place.call("10,300,250,0")
waiting.refresh(box, 1)
lines = window.contents.lines
check("a new width makes new contents with every line drawn anew, the names cut to it",
      [window.width, window.contents.width, lines[0], lines[1].start_with?("Still choosing: ") && lines[1].end_with?(MGQ_MpUi::ELLIPSIS), lines[2]], [250, 226, "Waiting for Host...", true, "0 s"])
place.call("10,300,100,0")
waiting.refresh(box, 2)
check("never narrower than its text and the leave offer need whole", [window.width, window.contents.lines[2]], [leave_width, "0 s"])
waiting.close(box)
place.call(nil)

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

# Enemies that fall while the host waits for the commands, as a Raid World's pools kill them, win
# the battle at once, and the turn the host waited in never starts.
fall_in_wait = lambda do |bid, seats|
  sync.join_world(:host, bid, seats, "the party")
  sync.battle_started
  live.instance_variable_set(:@answered, [])
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
check("and the wait ends as won", $log.grep(/ends early in turn \d+: its enemies fell while it waited for commands/).size, 2)
sync.join_world(:host, "w4d", [2], "the party")
sync.battle_started
sync.instance_variable_set(:@solo, true)
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

# A hostile line on the wire reads as nil or as unknown values, never raising or making a symbol.
wire = sync::Wire
check("an equipped item reads one skill, item, state, weapon or armor token, anything else as unknown",
      [wire.parse("g+"), wire.parse("gi5"), wire.parse("gx"), wire.parse("ggk1")], [[nil], [nil], [nil], [nil]])
equipped = wire.parse("gk3")[0]
check("and wraps the skill it names", [equipped.class, equipped.object], [Game_BaseItem, $data_skills[3]])
check("a long chain of item marks reads as unknown", wire.parse("g" * 10_000 + "k1"), [nil])
odd = wire.parse("{\t:1x\ti1\t}")[0]
check("an action result takes no field it lacks", [odd.class, odd.instance_variables.map(&:to_s).include?("@1x"), odd.hp_damage], [Game_ActionResult, false, 0])
wire.parse(":hp_damage")
symbols = Symbol.all_symbols.size
check("a symbol this game lacks reads as unknown", wire.parse(":zzz_never_seen_symbol_123"), [nil])
check("and is never made", [Symbol.all_symbols.size <= symbols, Symbol.all_symbols.map(&:to_s).include?("zzz_never_seen_symbol_123")], [true, false])
check("a symbol this game has reads back", wire.parse(":hp_damage\txcount"), [:hp_damage, sync::Wire::ActionKind.new(:count)])
check("a database id too large for the game reads as unknown", [wire.parse("k#{2**70}"), wire.parse("k200"), wire.parse("i#{2**70}")], [[nil], [nil], [2**70]])
nest = lambda { |depth| (["["] * depth + ["i1"] + ["]"] * depth).join("\t") }
check("a line nests at most 8 deep", [wire.parse(nest.call(8)), wire.parse(nest.call(9)), wire.parse(Array.new(1000, "[").join("\t"))],
      [[[[[[[[[[1]]]]]]]]], nil, nil])
check("a line longer than the relay delivers is not read", [wire.parse("s" + "x" * wire::MAX_LINE_BYTES), wire.parse("s" + "x" * 1000).size], [nil, 1])

# The host's names that fail to read leave every name as it is.
names = sync::Names
names.instance_variable_set(:@swaps, { "x" => "y" })
names.instance_variable_set(:@pattern, /x/)
parse = wire.method(:parse)
wire.define_singleton_method(:parse) { |*| raise "broken" }
$log.clear
names.setup("anything")
wire.define_singleton_method(:parse, parse)
check("the host's names that fail to read are shown unswapped, logged once",
      [names.swap("x"), $log.grep(/could not read the host's names, showing them unswapped: RuntimeError: broken/).size], ["x", 1])

# The guest leaves out a line of the host's stream or a message of the battle's mode that fails,
# and plays on with the rest.
$my_seat = 2
sync.join_world(:guest, "h1", [0], "Host")
sync.battle_started
playback.reset
playback.instance_variable_set(:@stats, Hash.new(0))
wire.define_singleton_method(:parse) { |line, &block| line == "boom" ? raise("boom") : parse.call(line, &block) }
coop_mode = sync.mode
take = coop_mode.method(:take)
coop_mode.define_singleton_method(:take) { |*| raise "bad party" }
$log.clear
sync::Channel.receive(0, "coop_party", "anything")
sync::Channel.receive(0, "events", ["boom", nest.call(9), sync::Wire.line(["turn", 3])].join("\n"))
event = playback.next_event(scene)
wire.define_singleton_method(:parse, parse)
coop_mode.define_singleton_method(:take, take)
check("the guest plays the good line of a send with bad ones", [event, playback.instance_variable_get(:@stats)[:unreadable], playback.instance_variable_get(:@stats)[:events]], [["turn", 3], 2, 1])
check("and leaves out a message of the mode that fails, logged once", $log.grep(/left out the host's coop_party, which failed: RuntimeError: bad party/).size, 1)

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

# The host's cut-ins and screen effects are checked as the story's are in coop_scene.rbx.
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
playback.play(scene, ["picture.show", 3, "cutin_alice.v2", 0, 10, 20.5, 100, 100, 255, 0])
playback.play(scene, ["picture.move", 3, 0, 10, 20, 100, 100, 0, 0, 30])
check("a cut-in whose name holds a dot shows and moves", $game_troop.screen.pictures[3].done.map(&:first), [:show, :move])
playback.play(scene, ["picture.show", 3, "MissingFace", 0, 10, 20, 100, 100, 255, 0])
check("one this game lacks erases the picture's place instead", $game_troop.screen.pictures[3].done.last, [:erase])
playback.play(scene, ["picture.show", 4, "cutin", 0, Float::INFINITY, 20, 100, 100, 255, 0])
playback.play(scene, ["picture.move", 4, 0, 10, 20, 100, 100, 0, 0, -1])
playback.play(scene, ["picture.show", 4, "../cutin", 0, 10, 20, 100, 100, 255, 0])
check("a place past the limits, a negative duration or a path is left out", $game_troop.screen.pictures[4].done, [])
playback.play(scene, ["screen.start_flash", Color.new(255, 255, 255, 170), 20])
playback.play(scene, ["screen.start_flash", "white", 20])
playback.play(scene, ["screen.start_shake", 5, 5, 10])
playback.play(scene, ["screen.start_shake", 50, 5, 10])
check("the screen takes a flash of a color and a shake within the editor's range alone",
      $game_troop.screen.done.map(&:first), [:flash, :shake])
check("and nothing raised, the calls left out logged once",
      [$log.grep(/could not play/).size, $log.grep(/left out the host's (picture|screen) call/).size], [0, 4])
sync.finish
