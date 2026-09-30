#----------------------------------------------------------------
#  overworld_test.rb
#
#  Changelog:
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers the open world as mp_overworld_sync.rbx, mp_actions.rbx, mp_chat.rbx, mp_overworld.rbx and
# mp_coop.rbx play it together: states, other players and their ghosts, the action wheel and parties,
# chat, pings, and the gate of the party's messages.

require_relative "support"

# Stand-ins for the game.
class Sprite; def initialize(*); end; end
module Graphics; def self.update; end; end
class Spriteset_Map; def update; end; def dispose; end; end
class Game_Map
  attr_accessor :map_id, :interpreter
  def update(main = false); end
end
class Game_Message; attr_accessor :busy; def busy?; @busy; end; end
class Interpreter; def running?; false; end; end
class Scene_Map; def update_scene; end; def scene_changing?; false; end; end
class Scene_Battle; end
module SceneManager; class << self; attr_accessor :scene; end; end
class Game_Character
  attr_reader :x, :y, :direction, :character_name, :character_index, :opacity
  def initialize; @x = 0; @y = 0; @direction = 2; end
  def moveto(x, y); @x, @y = x, y; end
  def set_graphic(name, index); @character_name, @character_index = name, index; end
  def set_direction(d); @direction = d; end
  def update; end
  def moving?; false; end
  def move_straight(d)
    @direction = d
    case d when 2 then @y += 1 when 8 then @y -= 1 when 4 then @x -= 1 when 6 then @x += 1 end
  end
end
Player = Struct.new(:x, :y, :direction, :character_name, :character_index, :real_move_speed, :transparent, :vehicle, :vehicle_type) do
  def in_airship?; vehicle_type == :airship; end
  def in_boat?; vehicle_type == :boat; end
  def in_ship?; vehicle_type == :ship; end
end
class Scene_Item; end
class Scene_EquipStoneActor; end
class Scene_Library_H; end
class Scene_Slot; end

$sent = []
$inbox = []
$in_front = true
$pressed = false
$buttons = []
$typed = ""
$sounds = []
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
class Color; def initialize(*); end; end
module MGQ_Multiplayer
  module Background; def self.in_front?; $in_front; end; def self.running?; true; end; end
  module Key; def self.pressed?(code); p = $pressed == code || ($pressed == true && code == 0x42); $pressed = false if p; p; end; end
  module Log; def self.write(m); puts "  log: #{m}"; end; end
  module Capture
    def self.start(owner); @owner = owner; end
    def self.stop(owner); @owner = nil if @owner == owner; end
    def self.on?; !@owner.nil?; end
    def self.trigger?(button); $buttons.delete(button) ? true : false; end
    def self.repeat?(button); $buttons.delete(button) ? true : false; end
  end
  module Player; def self.name; "Me"; end; end
  module Link
    def self.player_id; "me"; end
    def self.typing(on); $typing_on = on; end
    def self.take_typed; text = $typed; $typed = ""; [text, text.size]; end
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| k, v = line.split("=", 2); state[k] = v if v }
      state
    end
  end
end
module MGQ_MpWorld; def self.open?; $open; end; end

load_script "mp_overworld_sync"
load_script "mp_actions"
load_script "mp_chat"
load_script "mp_overworld"
load_script "mp_coop"

# One frame on the map: the wheel's keys, then the chat's, as the hooks run them.
def map_frame; MGQ_MpActions.on_map; MGQ_MpChat.on_map; end

module MGQ_MpOverworldSync::Link
  def self.next_entry; $inbox.shift; end
  def self.send_to(target, text); $sent << [target, text]; true; end
  def self.status; { "state" => "open", "ping" => $status_ping }; end
end

# An entry of the world room's inbox, as the DLL hands it out.
#
# @param kind [String] "seat", "in", "out" or "message".
# @param seat [Integer] The seat it is about.
# @param payload [String] A message's text.
# @return [Hash] The entry.
def entry(kind, seat, payload = "")
  { "kind" => kind, "seat" => seat.to_s, :payload => payload }
end

# Writes a state as another game sends it.
#
# @param state [Hash] The state's fields.
# @return [String] The message.
def told(state)
  state.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n\n"
end

$open = true
$game_map = Game_Map.new; $game_map.map_id = 5; $game_map.interpreter = Interpreter.new
$game_message = Game_Message.new
$game_player = Player.new(3, 4, 2, "Actor1", 0, 4, false, nil)
SceneManager.scene = Scene_Map.new

# A new seat tells everyone everything.
$inbox << entry("seat", 0)
MGQ_MpOverworldSync.tick
check("told everyone on the seat", $sent.map { |t, _| t }, [-1])
check("told the position", $sent[0][1].include?("x=3\ny=4"), true)
$sent.clear

# Nothing changed, nothing sent; a step is sent once.
MGQ_MpOverworldSync.tick
check("quiet while nothing changes", $sent.size, 0)
$game_player.x = 4
MGQ_MpOverworldSync.tick
MGQ_MpOverworldSync.tick
check("a step is sent once", $sent.size, 1)
$sent.clear

# A newcomer is told everything, to its seat only.
$inbox << entry("in", 2)
MGQ_MpOverworldSync.tick
check("told the newcomer only", $sent.map { |t, _| t }, [2])
$sent.clear

# The newcomer's state makes a peer, a notice and a ghost on the same map.
friend = { "id" => "friend", "name" => "Friend", "sprite" => "Actor2", "index" => 3, "map" => 5, "x" => 10, "y" => 10, "d" => 4, "speed" => 4, "hidden" => 0, "scene" => "map" }
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
check("joined notice", MGQ_MpOverworldSync::Status.lines, ["Friend joined the world."])
MGQ_MpOverworld.update_ghosts
peer = MGQ_MpOverworld.ghosts.first
ghost, state = peer.ghost, peer.state
check("ghost where the friend stands", [ghost.x, ghost.y, ghost.character_name, ghost.character_index], [10, 10, "Actor2", 3])
check("ghost faces as the friend", ghost.direction, 4)

# One tile away: the ghost walks; far away: it jumps.
$inbox << entry("message", 2, told(friend.merge("x" => 11)))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
check("ghost walked one tile", [ghost.x, ghost.y, ghost.direction], [11, 10, 6])
$inbox << entry("message", 2, told(friend.merge("x" => 11, "y" => 30)))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
check("ghost jumped far", [ghost.x, ghost.y], [11, 30])
$inbox << entry("message", 2, told(friend.merge("x" => 13, "y" => 30)))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
MGQ_MpOverworld.update_ghosts
check("ghost caught up two tiles by walking", [ghost.x, ghost.y], [13, 30])

# Another map: the ghost goes; back: it comes again.
$inbox << entry("message", 2, told(friend.merge("map" => 6)))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
check("no ghost for another map", MGQ_MpOverworld.ghosts, [])

# What the player does.
$game_message.busy = true
check("event while a message shows", MGQ_MpOverworldSync::Me.scene, "event")
$game_message.busy = false
SceneManager.scene = Scene_Battle.new
check("battle", MGQ_MpOverworldSync::Me.scene, "battle")
SceneManager.scene = Object.new
check("menu", MGQ_MpOverworldSync::Me.scene, "menu")
{ Scene_Item => "items", Scene_EquipStoneActor => "equip", Scene_Library_H => "library", Scene_Slot => "casino" }.each do |scene, expected|
  SceneManager.scene = scene.new
  check("screen #{scene}", MGQ_MpOverworldSync::Me.scene, expected)
end
$in_front = false
check("away in a menu", MGQ_MpOverworldSync::Me.scene, "away")
SceneManager.scene = Scene_Battle.new
check("battle stays battle while away", MGQ_MpOverworldSync::Me.scene, "battle")
$in_front = true
SceneManager.scene = Scene_Map.new
$game_player.vehicle_type = :ship
check("sailing", MGQ_MpOverworldSync::Me.scene, "sailing")
$game_player.vehicle_type = :airship
check("flying", MGQ_MpOverworldSync::Me.scene, "flying")
$game_player.vehicle_type = nil
check("walking", MGQ_MpOverworldSync::Me.scene, "map")
check("every state but walking has an icon", (%w[battle event menu items equip shop casino library sailing flying away] - MGQ_MpOverworld::STATE_ICONS.keys), [])

# The party, through the action wheel.
# Opens the action wheel, presses buttons in it and lets a frame pass.
#
# @param buttons [Array<Symbol>] The buttons, such as :DOWN and :C.
def wheel(*buttons); $pressed = true; map_frame; $buttons.concat(buttons); map_frame; MGQ_MpOverworldSync.tick; end
# Reads a choice of the action wheel.
#
# @param direction [Symbol] Where the choice sits, such as :UP.
# @return [Array] Its text and whether it can be taken.
def option(direction); o = MGQ_MpActions.wheel_options[direction]; [o.text, !o.run.nil?]; end
$game_player.x, $game_player.y = 20, 20
$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 40, "y" => 40)))
MGQ_MpOverworldSync.tick
check("nobody near: invite greyed", option(:UP), ["Invite to a party", false])
check("chat offered, duel greyed", [option(:LEFT), option(:RIGHT)], [["Chat (T)", true], ["Duel", false]])
$pressed = true
map_frame
check("B opens the wheel and holds the buttons", [MGQ_MpActions::Wheel.open?, MGQ_Multiplayer::Capture.on?], [true, true])
check("the first choice that can be taken is picked", MGQ_MpActions::Wheel.selected, :LEFT)
$buttons << :UP << :C
map_frame
check("a greyed choice says why", [MGQ_MpActions::Wheel.open?, MGQ_MpOverworldSync::Status.lines.last, $sounds.last], [true, "Nobody is near enough to invite.", "buzzer"])
$buttons << :LEFT
map_frame
check("arrows pick", MGQ_MpActions::Wheel.selected, :LEFT)
$pressed = true
map_frame
check("B closes the wheel and gives the buttons back", [MGQ_MpActions::Wheel.open?, MGQ_Multiplayer::Capture.on?], [false, false])
MGQ_MpActions::Wheel.open
$buttons << :B
map_frame
check("cancel closes too", MGQ_MpActions::Wheel.open?, false)
MGQ_MpOverworld.update_ghosts
ghost = MGQ_MpOverworld.ghosts.first.ghost
check("a stranger is see-through", ghost.opacity, MGQ_MpOverworld::STRANGER_OPACITY)

$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 21, "y" => 22)))
MGQ_MpOverworldSync.tick
check("someone near: invite first", option(:UP), ["Invite to a party", true])
$sent.clear
wheel(:C)
check("inviting", [MGQ_MpCoop::Party.inviting?, MGQ_MpActions::Wheel.open?], [true, false])
my_party = MGQ_MpCoop::Party.id
check("the invite is told", $sent.last[1].include?("invite=1") && $sent.last[1].include?("party=#{my_party}"), true)
check("line above the own head", MGQ_MpActions.own_line, "Inviting to a party . . .")
check("an invite can be stopped", option(:DOWN), ["Stop inviting", true])

$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 21, "y" => 22, "party" => my_party)))
MGQ_MpOverworldSync.tick
check("the friend joined", MGQ_MpOverworldSync::Status.lines.last, "Friend joined your party.")
check("inviting stops once one joined", MGQ_MpCoop::Party.inviting?, false)
check("members", MGQ_MpCoop::Party.members.map { |peer| peer.state["name"] }, ["Friend"])
MGQ_MpOverworld.update_ghosts
check("a member is solid", ghost.opacity, 255)
check("the label knows the member", MGQ_MpOverworld.ghosts.first.member, true)
check("a member is not invited again", option(:UP), ["Invite to a party", false])

wheel(:DOWN, :C)
check("left", [MGQ_MpCoop::Party.id, MGQ_MpOverworldSync::Status.lines.last], [nil, "You left the party."])
check("no party to leave", option(:DOWN), ["Leave the party", false])

$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 20, "y" => 21, "party" => "theirs", "invite" => 1)))
MGQ_MpOverworldSync.tick
check("an inviter shows the invite line", MGQ_MpOverworldSync.label_line_of(MGQ_MpOverworldSync::Peers.at(2)).to_a[0], "Invites to a party (B)")
check("an invite nearby is offered", option(:UP), ["Accept Friend's invite", true])
taken = []
MGQ_MpChat.singleton_class.send(:alias_method, :harness_receive, :receive)
MGQ_MpChat.define_singleton_method(:receive) { |peer, message| taken << [peer && peer.seat, message["chat"]] }
$inbox << entry("message", 2, "chat=hello\n\n")
MGQ_MpOverworldSync.tick
check("a chat line goes to the chat", taken, [[2, "hello"]])
MGQ_MpChat.singleton_class.send(:alias_method, :receive, :harness_receive)
wheel(:C)
check("accepting an invite takes their party", MGQ_MpCoop::Party.id, "theirs")
check("joined notice", MGQ_MpOverworldSync::Status.lines.last, "You joined Friend's party.")
$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 20, "y" => 21, "party" => "", "invite" => 0)))
MGQ_MpOverworldSync.tick
check("the friend leaving is noticed", MGQ_MpOverworldSync::Status.lines.last, "Friend left your party.")

$pressed = true
map_frame
SceneManager.scene = Scene_Battle.new
MGQ_MpOverworldSync.tick
check("leaving the map closes the wheel", [MGQ_MpActions::Wheel.open?, MGQ_Multiplayer::Capture.on?], [false, false])
SceneManager.scene = Scene_Map.new
$open = false
MGQ_MpOverworldSync.tick
check("closing the world leaves the party", MGQ_MpCoop::Party.id, nil)
$open = true
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick

# Chat.
chat = MGQ_MpChat
$pressed = 0x54
map_frame
check("T opens the chat box and holds the buttons", [chat.typing?, $typing_on, MGQ_Multiplayer::Capture.on?], [true, true, true])
check("the others see the player types", MGQ_MpOverworldSync::Me.scene, "typing")
before = chat.typed
$typed = "a"
map_frame
check("each character makes a new text, so the box redraws", [chat.typed, before.equal?(chat.typed), before], ["a", false, ""])
$typed = "\b"
map_frame
$pressed = true
$typed = "hi thereX\b"
map_frame
check("typing, backspace, and B types instead of opening the wheel", [chat.typed, MGQ_MpActions::Wheel.open?], ["hi there", false])
check("the cursor follows the typing", chat.cursor, 8)
$buttons << :LEFT
map_frame
$buttons << :LEFT
map_frame
$typed = "X"
map_frame
check("left moves the cursor and typing goes in there", [chat.typed, chat.cursor], ["hi theXre", 7])
$typed = "\b"
map_frame
$pressed = 0x2E
map_frame
check("backspace removes before the cursor, delete after it", [chat.typed, chat.cursor], ["hi thee", 6])
$pressed = 0x24
map_frame
$buttons << :LEFT
map_frame
$typed = "\b"
map_frame
check("home goes to the start, where left and backspace stop", [chat.typed, chat.cursor], ["hi thee", 0])
$pressed = 0x23
map_frame
$buttons << :RIGHT
map_frame
$pressed = 0x2E
map_frame
check("end goes to the end, where right and delete stop", [chat.typed, chat.cursor], ["hi thee", 7])
$typed = "\bre"
map_frame
check("the cursor shows right after a change", chat.cursor_shown?, true)
MGQ_MpChat::BLINK_FRAMES.times { map_frame }
check("then blinks", chat.cursor_shown?, false)
$sent.clear
$typed = "\r"
map_frame
check("enter sends and closes", [chat.typing?, $typing_on, MGQ_Multiplayer::Capture.on?], [false, false, false])
check("the line is told", $sent.last[1].include?("chat=hi there") && !$sent.last[1].include?("map="), true)
check("own line in the log and bubble", [chat.log_lines.last, chat.bubble(:me)], ["Me: hi there", "hi there"])

$inbox << entry("message", 2, "chat=hello\x01 you\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
check("a friend's line", [chat.log_lines.last, chat.bubble(2)], ["Friend: hello you", "hello you"])
$inbox << entry("message", 7, "chat=who am i\nname=Stranger\n\n")
MGQ_MpOverworldSync.tick
check("a line before the first state names the sender", chat.log_lines.last, "Stranger: who am i")

wheel(:LEFT, :C)
check("the wheel opens the chat box", [chat.typing?, MGQ_MpActions::Wheel.open?, MGQ_Multiplayer::Capture.on?], [true, false, true])
$typed = "never sent\e"
map_frame
check("escape closes without sending", [chat.typing?, chat.log_lines.last], [false, "Stranger: who am i"])
chat.start_typing
$typed = "x" * 130
map_frame
check("a line stops at the most characters", chat.typed.size, MGQ_MpChat::MAX_LENGTH)
chat.stop_typing

(MGQ_MpChat::BUBBLE_FRAMES + 1).times { MGQ_MpOverworldSync.tick }
check("bubbles run out", chat.senders, [])
check("log lines stay a while longer", chat.log_lines.size, 3)
(MGQ_MpChat::LOG_FRAMES).times { MGQ_MpOverworldSync.tick }
check("then the log goes quiet", chat.log_lines, [])
chat.start_typing
check("but shows again while typing", chat.log_lines.size, 3)
SceneManager.scene = Scene_Battle.new
MGQ_MpOverworldSync.tick
check("leaving the map closes the chat box", [chat.typing?, MGQ_Multiplayer::Capture.on?], [false, false])
SceneManager.scene = Scene_Map.new

class FakeBitmap; def text_size(text); Struct.new(:width).new(text.size * 10); end; end
check("wrapping at spaces", chat.wrap(FakeBitmap.new, "aaa bbb ccc", 70), ["aaa bbb", "ccc"])
check("wrapping a long word", chat.wrap(FakeBitmap.new, "abcdefghij", 40), ["abcd", "efgh", "ij"])

# Pings.
ping = MGQ_MpOverworldSync::Ping
# Has the world connection report a ping, and lets the frames pass until the game looks at it.
#
# @param value [String, nil] The milliseconds, nil for no connection.
def status_ping(value); $status_ping = value; (MGQ_MpOverworldSync::STATUS_FRAMES + 2).times { MGQ_MpOverworldSync.tick }; end
check("no ping before the first pong", [ping.measured, ping.told, MGQ_MpOverworld.ping_label(ping.told)], [nil, "", nil])
$sent.clear
status_ping("40")
check("the first ping is taken and told", [ping.measured, ping.told], [40, "40"])
check("the others hear the ping", $sent.last[1][/ping=(\d*)/, 1], "40")
$sent.clear
status_ping("52")
check("a small change is only shown", [ping.measured, ping.told, $sent.size], [52, "40", 0])
status_ping("65")
check("a big change is told", [ping.told, $sent.size], ["65", 1])
status_ping("300")
status_ping("330")
check("the step grows with the ping", ping.told, "300")
check("colors by quality", [MGQ_MpOverworld.ping_label(50)[0], MGQ_MpOverworld.ping_label(50)[1].equal?(MGQ_MpOverworld::PING_COLORS[0][1]),
                            MGQ_MpOverworld.ping_label(150)[1].equal?(MGQ_MpOverworld::PING_COLORS[1][1]), MGQ_MpOverworld.ping_label(999)[1].equal?(MGQ_MpOverworld::PING_COLORS[2][1])],
      ["50 ms", true, true, true])
status_ping(nil)
check("no connection, no ping shown", ping.measured, nil)

# Scripts' messages that name a map are not states.
module MGQ_MpCoopEvents; def self.take(peer, message); ($taken_events ||= []) << [peer && peer.seat, message["pevent"], message["map"]]; end; end
MGQ_MpOverworldSync.route("pevent") { |peer, message| MGQ_MpCoopEvents.take(peer, message) }
before = MGQ_MpOverworldSync::Peers.at(2).state.dup
$inbox << entry("message", 2, "pevent=travel
party=p1
map=77
x=1
y=2
d=2

")
MGQ_MpOverworldSync.tick
check("a script's message with a map goes to its script", $taken_events, [[2, "travel", "77"]])
check("and leaves the sender's state alone", MGQ_MpOverworldSync::Peers.at(2).state, before)

module MGQ_MpBattlesSync; def self.take(peer, message); ($taken_battle ||= []) << [message["battle"], message[:payload]]; end; end
MGQ_MpOverworldSync.route("battle") { |peer, message| MGQ_MpBattlesSync.take(peer, message) }
$inbox << entry("message", 2, "battle=join
bid=b1

first line	second
third")
MGQ_MpOverworldSync.tick
check("a script's message keeps its body", $taken_battle, [["join", "first line	second
third"]])

# Leaving, and closing the world.
$inbox << entry("out", 2)
MGQ_MpOverworldSync.tick
check("left notice", MGQ_MpOverworldSync::Status.lines.last, "Friend left the world.")
check("no peers left", MGQ_MpOverworldSync::Peers.empty?, true)
$inbox << entry("message", 3, told(friend.merge("seat" => 3)))
MGQ_MpOverworldSync.tick
$open = false
MGQ_MpOverworldSync.tick
check("closing the world forgets everyone", MGQ_MpOverworldSync::Peers.empty?, true)

# Notices run out.
$open = true
(MGQ_MpOverworldSync::NOTICE_FRAMES + 1).times { MGQ_MpOverworldSync.tick }
check("notices ran out", MGQ_MpOverworldSync::Status.lines, [])

# The party gate: messages of another party are dropped, those of the own party handed on.
$gate = []
MGQ_MpCoop.route("gtest") { |peer, message| $gate << [peer.seat, message["gtest"]] }
$open = true
$inbox << entry("message", 4, told(friend.merge("x" => 50, "y" => 50)))
MGQ_MpOverworldSync.tick
MGQ_MpCoop::Party.invite
mine = MGQ_MpCoop::Party.id
$inbox << entry("message", 4, "gtest=theirs
party=other

")
$inbox << entry("message", 4, "gtest=mine
party=#{mine}

")
$inbox << entry("message", 9, "gtest=unknown
party=#{mine}

")
MGQ_MpOverworldSync.tick
check("the gate hands on only the own party from a known player", $gate, [[4, "mine"]])
$sent.clear
MGQ_MpCoop.tell(4, "gtest", "hello", "extra" => 1)
check("tell adds the party id", [$sent.last[0], $sent.last[1].include?("gtest=hello
party=#{mine}
extra=1")], [4, true])
