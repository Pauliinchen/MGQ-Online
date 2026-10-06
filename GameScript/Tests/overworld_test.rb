#----------------------------------------------------------------
#  overworld_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Checked that Discord hears of the world code, which its invites carry
#                            - Checked that the wheel keeps its pick once the arrows are let go
#                            - Found the wheel's choices by their place on the ring, and checked how the ring spreads and lays out its choices
#                            - Steered the action wheel with the arrows held, and checked the middle while none or a diagonal is held
#      Paulinchen  2026-10-05: Checked that an open chat box takes typing and closes while a message shows
#      Paulinchen  2026-10-04: Checked that a label goes above the labels already on its tile
#                            - Checked the party chat and the colors of the senders' names in the chat log
#                            - Checked that the chat box opens while the player waits for the party's story and stays open once it plays
#                            - Checked that the chat key does not type its own character into the box it opened
#                            - Read the cursor's blink frames from MGQ_MpUi::TextEdit
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked that a member's party choice on the wheel teleports to the leader
#                            - Checked the word wrap where it lives now, in MGQ_MpUi
#                            - Followed the choices to the scripts that offer them
#                            - Checked that a party counts only whom its leader admitted, and that a player whose connection dropped is kept for a while
#                            - Read the bound keys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#                            - Checked that an invite naming a player from afar stands longer, and that a decline ends it for them
#      Paulinchen  2026-10-02: Checked what Discord hears of the open world
#                            - Checked that the state marker tells states apart from the scripts' messages
#                            - Checked that a full party turns away one player too many and cannot be joined
#      Paulinchen  2026-10-01: Checked the chat in battles and the game's own lines in the chat log
#                            - Checked the globe in the wheel's middle
#                            - Checked the followers behind a party member's ghost
#                            - Took the open world's stand-ins from world_support.rb, which the duel and overview tests share
#                            - Checked the wheel's middle, invites naming a player, and the size and leader of a party
#                            - Checked that only the party's leader invites and removes members
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers the open world as overworld_sync.rbx, ui_actions.rbx, ui_chat.rbx, overworld.rbx,
# coop.rbx and coop_squad.rbx play it together: states, other players, their ghosts and their
# followers, the action wheel and parties, chat, pings, and the gate of the party's messages.

require_relative "world_support"

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
def wheel(*buttons)
  $pressed = true
  map_frame
  directions = buttons & MGQ_MpWheel::DIRECTIONS
  $held = directions.map { |direction| arrows(direction) }.flatten
  $buttons.concat(buttons - directions)
  map_frame
  $held = []
  MGQ_MpOverworldSync.tick
end
# Reads a choice of the action wheel.
#
# @param direction [Symbol] Where the choice sits, such as :UP.
# @return [Array] Its text and whether it can be taken.
def option(direction); o = MGQ_MpActions.wheel_options[direction]; [o.text, !o.run.nil?]; end
# The arrows held to point at a direction.
#
# @param direction [Symbol] One of MGQ_MpWheel::DIRECTIONS.
# @return [Array<Symbol>] The arrows.
def arrows(direction)
  row, column = MGQ_MpWheel::STEPS.key(direction)
  [row < 0 ? :UP : nil, row > 0 ? :DOWN : nil, column < 0 ? :LEFT : nil, column > 0 ? :RIGHT : nil].compact
end
# The ring's choices here, in their order: the party's invite, leaving the party and the chat.
PARTY, LEAVE, CHAT = MGQ_MpActions.wheel_places
$game_player.x, $game_player.y = 20, 20
$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 40, "y" => 40)))
MGQ_MpOverworldSync.tick
check("three choices spread over the ring", [PARTY, LEAVE, CHAT], [:UP, :DOWN_RIGHT, :DOWN_LEFT])
check("nobody near: invite greyed", option(PARTY), ["Invite to a party", false])
check("chat offered, and a direction without a choice has none", [option(CHAT), MGQ_MpActions.wheel_options.key?(:RIGHT)], [["Chat (T)", true], false])
$pressed = true
map_frame
check("B opens the wheel and holds the buttons", [MGQ_MpActions::Wheel.open?, MGQ_Multiplayer::Capture.on?], [true, true])
check("the wheel opens on its middle", MGQ_MpActions::Wheel.selected, :CENTER)
$held = [:UP]
$buttons << :C
map_frame
check("a greyed choice says why", [MGQ_MpActions::Wheel.open?, MGQ_MpOverworldSync::Status.lines.last, $sounds.last], [true, "Nobody is near enough to invite.", "buzzer"])
$held = arrows(CHAT)
map_frame
check("the arrows held pick the choice they point at", MGQ_MpActions::Wheel.selected, CHAT)
$held = []
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
check("someone near: invite first", option(PARTY), ["Invite to a party", true])
$sent.clear
wheel(:UP, :C)
check("inviting", [MGQ_MpCoop::Party.inviting?, MGQ_MpActions::Wheel.open?], [true, false])
my_party = MGQ_MpCoop::Party.id
check("the invite is told", $sent.last[1].include?("invite=1") && $sent.last[1].include?("party=#{my_party}"), true)
check("line above the own head", MGQ_MpActions.own_line, "Inviting to a party . . .")
check("an invite can be stopped", option(LEAVE), ["Stop inviting", true])

$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 21, "y" => 22, "party" => my_party)))
MGQ_MpOverworldSync.tick
check("the friend joined", MGQ_MpOverworldSync::Status.lines.last, "Friend joined your party.")
check("inviting stops once one joined", MGQ_MpCoop::Party.inviting?, false)
check("members", MGQ_MpCoop::Party.members.map { |peer| peer.state["name"] }, ["Friend"])
MGQ_MpOverworld.update_ghosts
check("a member is solid", ghost.opacity, 255)
check("the label knows the member", MGQ_MpOverworld.ghosts.first.member, true)
check("a member is not invited again", option(PARTY), ["Invite to a party", false])

# A member's ghost has the followers they show, which step where the one before stood.
check("followers are told only once shown", [$sent.last[1].include?("trail=\n"), $sent.last[1].include?("follow=0")], [true, true])
[21, 22, 23, 24].each do |x|
  $inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => x, "y" => 22, "party" => my_party, "trail" => "Actor5*1|Actor6*2")))
  MGQ_MpOverworldSync.tick
  MGQ_MpOverworld.update_ghosts
end
check("a member's ghost has their followers", ghost.followers.map { |f| [f.character_name, f.character_index] }, [["Actor5", 1], ["Actor6", 2]])
check("each a step behind the one before", [ghost.x, ghost.followers.map(&:x)], [24, [23, 22]])
$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 24, "y" => 40, "party" => my_party, "trail" => "Actor5*1")))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
check("a jump gathers the followers, as many as told", ghost.followers.map { |f| [f.x, f.y] }, [[24, 40]])

wheel(LEAVE, :C)
MGQ_MpOverworld.update_ghosts
check("a stranger's ghost has no followers", ghost.followers, [])
check("left", [MGQ_MpCoop::Party.id, MGQ_MpOverworldSync::Status.lines.last], [nil, "You left the party."])
check("no party to leave", option(LEAVE), ["Leave the party", false])

$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 20, "y" => 21, "party" => "theirs", "invite" => 1)))
MGQ_MpOverworldSync.tick
check("an inviter shows the invite line", MGQ_MpOverworldSync.label_line_of(MGQ_MpOverworldSync::Peers.at(2)).to_a[0], "Invites to a party (B)")
check("an invite nearby is offered", option(PARTY), ["Accept Friend's invite", true])
taken = []
MGQ_MpChat.singleton_class.send(:alias_method, :harness_receive, :receive)
MGQ_MpChat.define_singleton_method(:receive) { |peer, message| taken << [peer && peer.seat, message["chat"]] }
$inbox << entry("message", 2, "chat=hello\n\n")
MGQ_MpOverworldSync.tick
check("a chat line goes to the chat", taken, [[2, "hello"]])
MGQ_MpChat.singleton_class.send(:alias_method, :receive, :harness_receive)
wheel(:UP, :C)
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
$typed = "t"
map_frame
check("the T that opened the box, arriving after it, is left out", chat.typed, "")
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
MGQ_MpUi::TextEdit::BLINK_FRAMES.times { map_frame }
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

wheel(CHAT, :C)
check("the wheel opens the chat box", [chat.typing?, MGQ_MpActions::Wheel.open?, MGQ_Multiplayer::Capture.on?], [true, false, true])
$typed = "never sent\e"
map_frame
check("escape closes without sending", [chat.typing?, chat.log_lines.last], [false, "Stranger: who am i"])
chat.start_typing
$typed = "x" * 130
map_frame
check("a line stops at the most characters", chat.typed.size, MGQ_MpChat::MAX_LENGTH)
chat.stop_typing
chat.start_typing(0x54)
$typed = "go"
map_frame
check("a first character other than the key's is typed", chat.typed, "go")
chat.stop_typing
chat.start_typing(0x54)
(MGQ_MpChat::KEY_ECHO_FRAMES + 1).times { map_frame }
$typed = "t"
map_frame
check("as is the key's character once its echo could no longer come", chat.typed, "t")
chat.stop_typing

(MGQ_MpChat::BUBBLE_FRAMES + 1).times { MGQ_MpOverworldSync.tick }
check("bubbles run out", chat.senders, [])
check("log lines stay a while longer", chat.log_lines.size, 3)
(MGQ_MpChat::LOG_FRAMES).times { MGQ_MpOverworldSync.tick }
check("then the log goes quiet", chat.log_lines, [])
chat.start_typing
check("but shows again while typing", chat.log_lines.size, 3)
battle = Scene_Battle.new
SceneManager.scene = battle
MGQ_MpOverworldSync.tick
check("a battle keeps the chat box open", [chat.typing?, MGQ_Multiplayer::Capture.on?], [true, true])
$typed = "in battle\r"
battle.update_basic
check("and its line goes out from the battle", [chat.typing?, chat.log_lines.last], [false, "Me: in battle"])
$pressed = MGQ_MpHotkeys.code(:chat)
battle.update_basic
check("T opens the chat box in a battle too", chat.typing?, true)
SceneManager.scene = Scene_Item.new
MGQ_MpOverworldSync.tick
check("a menu closes the chat box", [chat.typing?, MGQ_Multiplayer::Capture.on?], [false, false])
SceneManager.scene = Scene_Map.new
chat.system("Friend left the battle.")
check("the game's own lines go to the log too", chat.log_lines.last, "* Friend left the battle.")

# The chat while an event runs, and while the party's story waits.
$game_message.busy = true
$pressed = 0x54
map_frame
check("an event's message keeps the chat box shut", chat.typing?, false)
module MGQ_MpCoopGather; def self.waiting?; $party_waiting; end; end
$party_waiting = true
$pressed = 0x54
map_frame
check("but it opens while the player waits for the party's story", chat.typing?, true)
$party_waiting = false
$typed = "on"
map_frame
check("and stays open, keeping the line, once the story plays", [chat.typing?, chat.typed], [true, "on"])
# A message on screen stops the map's own update, so the map's update itself types into the box.
map = Scene_Map.new
$scene_change_ok = false
$typed = "ly"
map.update
check("while a message shows, the box still takes typing", chat.typed, "only")
$typed = "\e"
map.update
check("and closes, giving the buttons back to the message", [chat.typing?, MGQ_Multiplayer::Capture.on?], [false, false])
chat.start_typing
$scene_change_ok = true
$typed = "x"
map.update
check("without a message the map's own update types, not the map", chat.typed, "")
chat.stop_typing
$game_message.busy = false

class FakeBitmap; def text_size(text); Struct.new(:width).new(text.size * 10); end; end
check("wrapping at spaces", MGQ_MpUi.wrap(FakeBitmap.new, "aaa bbb ccc", 70), ["aaa bbb", "ccc"])
check("wrapping a long word", MGQ_MpUi.wrap(FakeBitmap.new, "abcdefghij", 40), ["abcd", "efgh", "ij"])

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

# A state may carry a field named like a route: the marker keeps it a state.
MGQ_MpOverworldSync.state_fields { { "battle" => "clash", "kept" => 1 } }
state = MGQ_MpOverworldSync::Me.current
check("a state keeps a field named like a route, and carries the marker", [state["battle"], state["kept"], state["state"]], ["clash", 1, 1])
$taken_battle = nil
$inbox << entry("message", 2, told(friend.merge("x" => 12, "battle" => "clash")))
MGQ_MpOverworldSync.tick
check("a state with a route's field is taken as a state, not by the route",
      [$taken_battle, MGQ_MpOverworldSync::Peers.at(2).state["x"]], [nil, "12"])
$inbox << entry("message", 2, "map=5
x=1

")
MGQ_MpOverworldSync.tick
check("a message with a map but no marker is no state", MGQ_MpOverworldSync::Peers.at(2).state["x"], "12")

# Leaving, and closing the world.
$inbox << entry("out", 2)
MGQ_MpOverworldSync.tick
check("a player whose connection dropped is kept for a while, unseen",
      [MGQ_MpOverworldSync::Peers.at(2).away.nil?, MGQ_MpOverworldSync::Status.lines.include?("Friend left the world.")], [false, false])
MGQ_MpOverworld.update_ghosts
check("without their ghost", MGQ_MpOverworldSync::Peers.at(2).ghost, nil)
$inbox << entry("message", 6, told(friend))
MGQ_MpOverworldSync.tick
check("and is the same player once they tell again, on any seat",
      [MGQ_MpOverworldSync::Peers.at(2), MGQ_MpOverworldSync::Peers.at(6).away, MGQ_MpOverworldSync::Peers.all.size, MGQ_MpOverworldSync::Status.lines.grep(/joined the world/).size], [nil, nil, 1, 0])
$inbox << entry("seat", 0)
MGQ_MpOverworldSync.tick
check("the player's own new connection keeps the others for as long", MGQ_MpOverworldSync::Peers.at(6).away.nil?, false)
(MGQ_MpOverworldSync::REJOIN_FRAMES + 1).times { MGQ_MpOverworldSync.tick }
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
$sent.clear
chat.start_typing
$typed = "/p anyone?\r"
map_frame
check("outside a party the party chat sends nothing and says why",
      [$sent, MGQ_MpOverworldSync::Status.lines.last, chat.typing?], [[], "You are in no party, so nobody hears the party chat.", false])
MGQ_MpCoop::Party.invite
mine = MGQ_MpCoop::Party.id
MGQ_MpOverworldSync::Peers.at(4).state["party"] = mine
$inbox << entry("message", 4, "gtest=uninvited\nparty=#{mine}\n\n")
MGQ_MpOverworldSync.tick
check("a player the leader did not admit is not heard, though they name the party", $gate, [])
MGQ_MpCoop::Party.admitted << "friend"
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

# The party chat, and the senders' colors.
$sent.clear
chat.start_typing
$typed = "/p meet at the inn\r"
map_frame
party_line = $sent.last && $sent.last[1]
check("a line starting with /p goes to the party only", [party_line.include?("pchat=meet at the inn\n"), party_line.include?("party=#{mine}"), party_line =~ /^chat=/ ? true : false],
      [true, true, false])
check("and shows tagged in the player's own log", [chat.log_lines.last, chat.log_entries.last.who], ["[Party] Me: meet at the inn", :me])
$inbox << entry("message", 4, "pchat=on my way\nname=Friend\nparty=#{mine}\n\n")
$inbox << entry("message", 4, "chat=hello all\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
check("a member's party line and world line show, their name in the member's color",
      chat.log_entries.last(2).map { |line| [line.to_s, line.who] }, [["[Party] Friend: on my way", :member], ["Friend: hello all", :member]])
$inbox << entry("message", 4, "pchat=sneaky\nname=Friend\nparty=other\n\n")
MGQ_MpOverworldSync.tick
check("another party's line is never heard", chat.log_lines.last, "Friend: hello all")
parts = []
font = Struct.new(:color, :size, :outline).new
canvas = Object.new
canvas.define_singleton_method(:font) { font }
canvas.define_singleton_method(:text_size) { |text| Struct.new(:width).new(text.size * 10) }
canvas.define_singleton_method(:draw_text) { |x, _y, _w, _h, text| parts << [x, text, font.color] }
log_sprite = Sprite_MpChatLog.allocate
log_sprite.define_singleton_method(:bitmap) { canvas }
colors = { Sprite_MpChatLog::PARTY_TAG_COLOR => :tag, Sprite_MpChatLog::NAME_COLORS[:member] => :member, Sprite_MpChatLog::TEXT_COLOR => :text }
log_sprite.draw_row("[Party] Friend: on my way", chat.log_entries[-2], 0)
check("the log draws the tag, then the name in its color, then the line", parts.map { |x, text, color| [x, text, colors[color]] },
      [[4, "[Party] ", :tag], [84, "Friend: ", :member], [164, "on my way", :text]])
parts.clear
log_sprite.draw_row("on my way", nil, 0)
check("a row that goes on a line is all text", parts.map { |_, text, color| [text, colors[color]] }, [["on my way", :text]])

# The wheel's middle, which it opens on, and the pick it keeps once the arrows are let go.
MGQ_MpActions::Wheel.open
$held = [:UP]
map_frame
check("an arrow held picks its side", MGQ_MpActions::Wheel.selected, :UP)
$held = []
map_frame
check("letting go keeps the choice", MGQ_MpActions::Wheel.selected, :UP)
$held = [:UP, :RIGHT]
map_frame
check("a diagonal, which the wheel has no choice for, picks the middle too", MGQ_MpActions::Wheel.selected, :CENTER)
$held = []
MGQ_MpActions::Wheel.close

# How the ring spreads and lays out its choices.
mirror = { :UP_RIGHT => :UP_LEFT, :RIGHT => :LEFT, :DOWN_RIGHT => :DOWN_LEFT }
mirror.merge!(mirror.invert)
check("every count of choices comes out mirror-symmetric",
      (1..8).all? { |count| places = MGQ_MpWheel.places(count); places.map { |d| mirror[d] || d }.sort == places.sort }, true)
check("four take the sides, five the two lower diagonals for the bottom, six a hexagon",
      [MGQ_MpWheel.places(4), MGQ_MpWheel.places(5), MGQ_MpWheel.places(6)],
      [[:UP, :RIGHT, :DOWN, :LEFT], [:UP, :RIGHT, :DOWN_RIGHT, :DOWN_LEFT, :LEFT], [:UP, :UP_RIGHT, :DOWN_RIGHT, :DOWN, :DOWN_LEFT, :UP_LEFT]])
boxes = Sprite_MpActionWheel.layout(MGQ_MpWheel.places(4))
check("four choices sit where the wheel always had them",
      [:UP, :RIGHT, :DOWN, :LEFT, :CENTER].map { |d| [boxes[d].x, boxes[d].y] }, [[-100, -94], [20, -37], [-100, 4], [-220, -37], [-13, -37]])
boxes = Sprite_MpActionWheel.layout(MGQ_MpWheel.places(6))
check("the top and bottom boxes clear the diagonal ones beside the player",
      [boxes[:UP].y + boxes[:UP].height <= boxes[:UP_RIGHT].y, boxes[:DOWN].y >= boxes[:DOWN_RIGHT].y + boxes[:DOWN_RIGHT].height], [true, true])
before = MGQ_MpActions.wheel_places.size
(MGQ_MpWheel::DIRECTIONS.size - before + 1).times { |index| MGQ_MpActions.wheel_choice(100 + index) { MGQ_MpActions::NO_OPTION } }
check("a ring holds eight choices at most", MGQ_MpActions.wheel_places.size, MGQ_MpWheel::DIRECTIONS.size)
MGQ_MpActions.instance_variable_get(:@choices).reject! { |order, _, _| order >= 100 }

# Invites that name a player reach them anywhere.
far = MGQ_MpOverworldSync::Peers.at(4)
far.state.merge!("party" => "far-p", "invite" => "1", "invite_to" => "other-id", "map" => "9")
check("an invite naming someone else does not reach the player from afar", MGQ_MpCoop::Party.invited_by?(far), false)
far.state["invite_to"] = "other-id,me"
check("one naming the player does", MGQ_MpCoop::Party.invited_by?(far), true)
check("but not in the wheel, which needs the inviter near", MGQ_MpCoop::Party.invited_by?(far, false), false)
MGQ_MpCoop::Party.stop_inviting
MGQ_MpCoop::Party.invite("friend")
check("the player's invite names its target", [MGQ_MpOverworldSync::Me.current["invite_to"], MGQ_MpCoop::Party.targets], ["friend", ["friend"]])
MGQ_MpCoop::Party.invite
check("a wheel invite keeps the targets of the standing invite", MGQ_MpCoop::Party.targets, ["friend"])
(MGQ_MpCoop::INVITE_FRAMES + 1).times { MGQ_MpCoop::Party.count_down }
check("an invite naming a player stands longer than one to those near", MGQ_MpCoop::Party.targets, ["friend"])
(MGQ_MpCoop::NAMED_INVITE_FRAMES - MGQ_MpCoop::INVITE_FRAMES).times { MGQ_MpCoop::Party.count_down }
check("the targets run out with the invite", MGQ_MpCoop::Party.targets, [])
MGQ_MpCoop::Party.invite(far.state["id"])
$inbox << entry("message", 4, "party_decline=1\n\n")
MGQ_MpOverworldSync.tick
check("a player who declines is no longer named, and the inviter hears it", [MGQ_MpCoop::Party.targets, MGQ_MpOverworldSync::Status.lines.last.to_s.end_with?("declined your party invite.")],
      [[], true])
MGQ_MpCoop::Party.stop_inviting

# The size and leader of a party.
MGQ_MpCoop::Party.invite
far.state.merge!("party" => MGQ_MpCoop::Party.id, "invite" => "0")
MGQ_MpCoop::Party.admitted << far.state["id"]
badges = [MGQ_MpOverworld.party_badge(:me), MGQ_MpOverworld.party_badge(far)]
check("a party of two shows its size on both, and one of them leads", [badges.map { |b| b[0] }, badges.count { |b| b[1] }], [["2 / 4", "2 / 4"], 1])
check("the leader is the one the party's id names, else the lowest id", MGQ_MpCoop.leads?(far), true)
far.state["party"] = "theirs"
check("a player alone shows no size", [MGQ_MpOverworld.party_badge(:me), MGQ_MpOverworld.party_badge(far)], [nil, nil])

# Only the party's leader invites and removes members.
MGQ_MpCoop::Party.reset
MGQ_MpCoop::Party.invite
far.state.merge!("party" => MGQ_MpCoop::Party.id, "invite" => "0", "id" => "zz-far")
MGQ_MpCoop::Party.admitted << "zz-far"
check("the leader may invite more", MGQ_MpCoop::Party.may_invite?, true)
$sent.clear
MGQ_MpCoop::Party.remove(far)
check("and removes a member by telling their game", [$sent.last[0], $sent.last[1].include?("kick=1"), MGQ_MpCoop::Party.members], [4, true, []])
far.state["id"] = "aa-far"
MGQ_MpCoop::Party.admitted << "aa-far"
check("a member may not invite, and teleports to the leader with the wheel's party choice instead",
      [MGQ_MpCoop::Party.may_invite?, MGQ_MpCoop::Offers.invite_refusal("full"), MGQ_MpActions.wheel_options[PARTY].text.start_with?("Teleport to ")],
      [false, "Only the party's leader invites.", true])
MGQ_MpCoop::Party.remove(far)
check("nor remove", $sent.size, 1)
$inbox << entry("message", 4, "kick=1\nparty=#{MGQ_MpCoop::Party.id}\n\n")
MGQ_MpOverworldSync.tick
check("the leader's removal makes the member's game leave", [MGQ_MpCoop::Party.id, MGQ_MpOverworldSync::Status.lines.last], [nil, "Friend removed you from the party."])

# A party past its size: the leader turns away whoever joins one too many, and nobody joins a full one.
MGQ_MpCoop::Party.reset
(10..13).each { |seat| MGQ_MpCoop::Party.invite("zz-m#{seat}") }
full = MGQ_MpCoop::Party.id
(10..13).each { |seat| $inbox << entry("message", seat, told(friend.merge("id" => "zz-m#{seat}", "name" => "M#{seat}", "party" => full))) }
$sent.clear
MGQ_MpOverworldSync.tick
check("the leader turns away the fifth player", [$sent.select { |_, text| text.include?("kick=full") }.map(&:first), MGQ_MpOverworldSync::Status.lines.last],
      [[13], "M13 could not join, the party is full."])

# A player the invite did not reach names the party: the leader turns them away, and they are no member.
MGQ_MpCoop::Party.reset
MGQ_MpCoop::Party.invite("zz-m10")
$inbox << entry("message", 10, told(friend.merge("id" => "zz-m10", "name" => "M10", "party" => MGQ_MpCoop::Party.id)))
$inbox << entry("message", 11, told(friend.merge("id" => "zz-m11", "name" => "M11", "party" => MGQ_MpCoop::Party.id, "x" => 40)))
(MGQ_MpCoop::LATE_FRAMES + 1).times { MGQ_MpCoop::Party.count_down }
$sent.clear
MGQ_MpOverworldSync.tick
check("the leader admits whom the invite reached, and turns away who only names the party",
      [MGQ_MpCoop::Party.members.map(&:seat), MGQ_MpCoop::Party.admitted, $sent.select { |_, text| text.include?("kick=late") }.map(&:first)], [[10], ["zz-m10"], [11]])
check("and tells whom it admitted", MGQ_MpOverworldSync::Me.current["party_members"], "zz-m10")
$inbox << entry("message", 11, told(friend.merge("id" => "zz-m11", "name" => "M11", "party" => MGQ_MpCoop::Party.id, "x" => 41)))
$sent.clear
MGQ_MpOverworldSync.tick
check("once", $sent.select { |_, text| text.include?("kick=") }, [])

# A member takes the leader's word on who is in the party.
MGQ_MpCoop::Party.reset
leader = MGQ_MpOverworldSync::Peers.at(10)
leader.state.merge!("party" => "zz-m10", "invite" => "1", "party_members" => "zz-m12")
(11..12).each { |seat| MGQ_MpOverworldSync::Peers.at(seat).state["party"] = "zz-m10" }
MGQ_MpCoop::Party.join(leader)
check("a member counts the leader and whom the leader admitted", MGQ_MpCoop::Party.members.map(&:seat), [10, 12])
$inbox << entry("message", 10, told(leader.state.merge("party_members" => "zz-m12,zz-m11,me")))
MGQ_MpOverworldSync.tick
check("and whom the leader admits later", MGQ_MpCoop::Party.members.map(&:seat), [10, 11, 12])
$inbox << entry("out", 10)
(MGQ_MpOverworldSync::REJOIN_FRAMES + 1).times { MGQ_MpOverworldSync.tick }
check("the party outlasts its leader, and the lowest id leads", [MGQ_MpCoop::Party.members.map(&:seat), MGQ_MpCoop::Party.leader == :me], [[11, 12], true])
(10..13).each { |seat| $inbox << entry("message", seat, told(friend.merge("id" => "zz-m#{seat}", "name" => "M#{seat}", "party" => full))) }
MGQ_MpOverworldSync.tick

MGQ_MpCoop::Party.reset
MGQ_MpCoop::Party.join(MGQ_MpOverworldSync::Peers.at(10))
check("a full party cannot be joined", [MGQ_MpCoop::Party.id, MGQ_MpOverworldSync::Status.lines.last], [nil, "M10's party is full."])

# Discord hears of the open world: its name, its players, its seats and the code its invites carry.
valley = Struct.new(:name, :id, :seats, :code, :directory_id).new("Valley", "w1", 8, "mgqmp2;abcdefghjkmnpqrs;r1;8", "d1")
MGQ_MpWorld.define_singleton_method(:world) { valley }
MGQ_MpOverworldSync::Peers.clear
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
check("Discord hears of the world, its players and its code", MGQ_MpOverworldSync.status_fields,
      { "mp_world" => "Valley", "mp_world_id" => "w1", "mp_world_size" => 2, "mp_world_max" => 8, "mp_world_invite" => "mgqmp2;abcdefghjkmnpqrs;r1;8" })
valley.directory_id = nil
check("but not of the code of a world from before the directory, which an invite could not find", MGQ_MpOverworldSync.status_fields.key?("mp_world_invite"), false)
$open = false
check("and of none once it closed", MGQ_MpOverworldSync.status_fields, {})
$open = true

# A ghost's label goes above the labels already on its tile.
CharacterSprite = Struct.new(:x, :y, :height, :visible, :opacity)
stacked = Sprite_MpGhostLabel.allocate
class << stacked; attr_accessor :x, :y, :visible; end
lone = MGQ_MpOverworldSync::Peers::Peer.new(9, { "name" => "Lone", "scene" => "map", "ping" => "20" }, nil, false)
stacked.instance_variable_set(:@shown, ["Lone", "map", "20", false, MGQ_MpOverworldSync.label_line_of(lone), MGQ_MpOverworld.party_badge(lone)])
taken = stacked.show(CharacterSprite.new(100, 200, 48, true, 255), lone, Sprite_MpOwnPing::HEIGHT)
check("a label on the player's tile goes above the player's ping, and tells the room it takes",
      [stacked.y, taken], [200 - 48 - Sprite_MpGhostLabel::LINE * 2 + 4 - Sprite_MpOwnPing::HEIGHT, Sprite_MpGhostLabel::LINE])
