#----------------------------------------------------------------
#  ui_chat_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-11: Checked the map chat chosen with /m, /s sent as text, the global chat untagged in white, a line marked say landing in the map chat, and the Whisper tab hidden until a whisper and again once the world closes
#                            - Created
#
#----------------------------------------------------------------

# Covers ui_chat.rbx: the lines sent that Alt with up and down bring back, /r answering the last
# player who whispered, the sound of a whisper that arrives while the chat box is closed, a paste,
# which the DLL hands over as typed text, the tabs drawn dimmed above the closed log while one
# holds unread lines, the Whisper tab shown only once a whisper happened, and the chats' commands,
# tags and colors. The rest of the chat is covered by overworld_test.rb, whose stand-in for the
# chat log's sprite and canvas the one below mirrors.

require_relative "world_support"

# The whisper's sound, which world_support.rb's Sound lacks.
def Sound.play_recovery; $sounds << "recovery"; end

chat = MGQ_MpChat
friend = { "id" => "friend", "name" => "Friend", "sprite" => "Actor2", "index" => 3, "map" => 5, "x" => 10, "y" => 10, "d" => 4, "speed" => 4, "hidden" => 0, "scene" => "map" }
friend_seat = 2
$inbox << entry("seat", 0)
$inbox << entry("message", friend_seat, told(friend))
MGQ_MpOverworldSync.tick

# Sends a line as typed into the chat box, in a frame of its own.
#
# @param text [String] The line, commands included.
def send_line(text)
  MGQ_MpChat.start_typing
  $typed = "#{text}\r"
  map_frame
end

# Presses a key while the left Alt is held, in a frame of its own.
#
# @param key [Integer] Windows' code of the key.
def alt_press(key)
  $down = [MGQ_MpChat::ALT_KEY]
  $pressed = key
  map_frame
  $down = []
end

# The lines sent, brought back with Alt and up or down.
send_line("first line")
send_line("second line")
send_line("second line")
send_line("/w nobody here")
check("sent lines are kept as typed, commands and refused ones included, a repeat of the last once", chat.history, ["first line", "second line", "/w nobody here"])
chat.start_typing
$typed = "dra"
map_frame
$sounds.clear
alt_press(MGQ_MpChat::UP_KEY)
check("Alt and up bring back the last line sent, the cursor at its end", [chat.typed, chat.cursor, $sounds], ["/w nobody here", 14, ["cursor"]])
alt_press(MGQ_MpChat::UP_KEY)
alt_press(MGQ_MpChat::UP_KEY)
check("again the ones before", chat.typed, "first line")
$sounds.clear
alt_press(MGQ_MpChat::UP_KEY)
check("and stay at the oldest, silent", [chat.typed, $sounds], ["first line", []])
alt_press(MGQ_MpChat::DOWN_KEY)
check("Alt and down go the other way", chat.typed, "second line")
alt_press(MGQ_MpChat::DOWN_KEY)
alt_press(MGQ_MpChat::DOWN_KEY)
check("and past the newest bring the line being typed back", chat.typed, "dra")
alt_press(MGQ_MpChat::DOWN_KEY)
check("where they stay", chat.typed, "dra")
$pressed = MGQ_MpChat::UP_KEY
$buttons << :UP
map_frame
check("up without Alt scrolls the log and leaves the box alone", [chat.typed, chat.scroll], ["dra", 1])
chat.stop_typing
chat.start_typing
$typed = "/help\r"
map_frame
alt_press(MGQ_MpChat::UP_KEY)
check("the help tab, where nobody types, brings no line back", chat.typed, "")
chat.select_tab(:all, "in the test")
chat.stop_typing
(1..25).each { |n| send_line("line #{n}") }
check("the last #{MGQ_MpChat::HISTORY_SIZE} lines are kept", [chat.history.size, chat.history.first, chat.history.last], [MGQ_MpChat::HISTORY_SIZE, "line 6", "line 25"])
chat.start_typing
alt_press(MGQ_MpChat::UP_KEY)
$typed = "\r"
map_frame
check("a line brought back and sent again is sent once more and kept once", [chat.log_lines.last, chat.history.last(2)], ["[Map] Me: line 25", ["line 24", "line 25"]])

check("the map chat is the one chosen first, and a /w naming nobody shows no Whisper tab", [chat.channel, chat.whisper_tab?, chat.tabs], [:map, false, [:all, :global, :map, :party]])
chat.start_typing
$down = [MGQ_MpChat::ALT_KEY]
$pressed = MGQ_MpChat::LEFT_KEY
chat.alt_keys
$down = []
check("nor do Alt and the arrows reach it", chat.tab, :party)
chat.select_tab(:all, "in the test")
chat.choose(:map)
chat.stop_typing

# /r answers the last player who whispered, whose whisper sounds while the box is closed.
$sounds.clear
send_line("/r hello")
check("/r before any whisper is refused", [MGQ_MpOverworldSync::Status.lines.last, chat.reply_to, $sounds.last], ["Nobody has whispered to you yet.", nil, "buzzer"])
$sounds.clear
$inbox << entry("message", friend_seat, "whisper=psst\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
check("a whisper that arrives while the box is closed plays the recovery sound once and is whom /r answers",
      [$sounds, chat.reply_to, chat.log_lines.last], [["recovery"], "Friend", "[Whisper] Friend: psst"])
check("and shows the Whisper tab, last of the chats' tabs, for the rest of the session", [chat.whisper_tab?, chat.tabs], [true, [:all, :global, :map, :party, :whisper]])
chat.start_typing
$sounds.clear
$inbox << entry("message", friend_seat, "whisper=again\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
check("one that arrives while the box is open plays nothing", $sounds, [])
chat.stop_typing
chat.choose(:map)
$sent.clear
send_line("/r back at you")
check("/r whispers to them and chooses the whisper chat to them for the lines after it",
      [$sent.map(&:first), $sent.last[1].include?("whisper=back at you"), chat.channel, chat.whisper_to, chat.log_lines.last],
      [[friend_seat], true, :whisper, "Friend", "[To Friend] Me: back at you"])
chat.choose(:map)
send_line("/r")
check("/r alone chooses the whisper chat to them", [chat.channel, chat.whisper_to, chat.typing?], [:whisper, "Friend", false])
$sounds.clear
$inbox << entry("message", friend_seat, "whisper=one\nname=Friend\n\n")
$inbox << entry("message", friend_seat, "whisper=two\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
check("whispers that arrive in one frame chime once", [$sounds, chat.log_lines.last(2)], [["recovery"], ["[Whisper] Friend: one", "[Whisper] Friend: two"]])
chat.choose(:map)
$inbox << entry("out", friend_seat)
MGQ_MpOverworldSync.tick
send_line("/r")
check("/r alone once they left is refused and leaves the chat as it was", [MGQ_MpOverworldSync::Status.lines.last, chat.channel], ["Friend is not in the world.", :map])
$sent.clear
send_line("/r still there?")
check("/r with a line once they left is refused too, nothing sent", [MGQ_MpOverworldSync::Status.lines.last, $sent, chat.channel], ["Friend is not in the world.", [], :map])
newcomer_seat = 3
$inbox << entry("message", newcomer_seat, told(friend.merge("id" => "other")))
MGQ_MpOverworldSync.tick
send_line("/r secret")
check("/r never goes to another player who took the name of the one who whispered", [MGQ_MpOverworldSync::Status.lines.last, $sent, chat.channel],
      ["Friend is not in the world.", [], :map])
$inbox << entry("message", friend_seat, told(friend))
$inbox << entry("message", newcomer_seat, "whisper=from the second\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
check("a whisper from the second player of a name is theirs to answer", chat.reply_to, "Friend (2)")
$inbox << entry("out", friend_seat)
MGQ_MpOverworldSync.tick
send_line("/r")
check("/r names them as the whisper list does now, not as the log showed them", [chat.channel, chat.whisper_to], [:whisper, "Friend"])
$inbox << entry("out", newcomer_seat)
$inbox << entry("message", friend_seat, told(friend))
MGQ_MpOverworldSync.tick

# A paste: the DLL hands the clipboard's text over in place of Ctrl+V, as typed text, so the chat
# box takes it as it takes typing.
chat.start_typing
$typed = "pasted from the clipboard"
map_frame
check("a paste lands in the box whole, the cursor after it", [chat.typed, chat.cursor], ["pasted from the clipboard", 25])
$sounds.clear
$typed = "x" * (MGQ_MpChat::MAX_LENGTH + 10)
map_frame
check("a paste longer than the box takes is cut and buzzes once", [chat.typed.size, $sounds], [MGQ_MpChat::MAX_LENGTH, ["buzzer"]])
MGQ_MpOverworldSync.tick
$sounds.clear
$typed = "y"
map_frame
check("the next frame buzzes again", $sounds, ["buzzer"])
chat.stop_typing

# The tabs above the closed log while one holds unread lines.
class Sprite; def update; end; end
font = Struct.new(:color, :size, :outline, :bold).new
parts = []
events = []
canvas = Object.new
canvas.define_singleton_method(:font) { font }
canvas.define_singleton_method(:text_size) { |text| Struct.new(:width).new(text.size * 10) }
canvas.define_singleton_method(:draw_text) { |x, _y, _w, _h, text, *_| parts << [x, text, font.color] }
canvas.define_singleton_method(:clear) { parts.clear; events.clear }
canvas.define_singleton_method(:fill_rect) { |*args| events << [:fill, args] }
canvas.define_singleton_method(:rect) { Rect.new(0, 0, 400, 154) }
canvas.define_singleton_method(:width) { 400 }
canvas.define_singleton_method(:height) { Sprite_MpChatLog::TAB_ROW + Sprite_MpChatLog::ROW * 7 }
canvas.define_singleton_method(:dispose) {}
Bitmap = Struct.new(:width, :height)
Bitmap.define_singleton_method(:new) { |*_| canvas }
depth = Struct.new(:z).new(100)
log_sprite = Sprite_MpChatLog.allocate
log_sprite.define_singleton_method(:bitmap) { canvas }
log_sprite.define_singleton_method(:bitmap=) { |_| }
log_sprite.define_singleton_method(:viewport) { depth }
log_sprite.define_singleton_method(:x) { 8 }
log_sprite.define_singleton_method(:y) { 200 }
log_sprite.define_singleton_method(:y=) { |_| }
log_sprite.define_singleton_method(:draw_unread_glow) { |right| events << [:glow, right] }
{ :@wrapped => {}, :@tab_spots => [], :@name_spots => [], :@size => [400, 6], :@width => 400, :@rows => 6, :@bottom_room => 96, :@resting_z => 100,
  :@menu_sprite => Struct.new(:visible, :bitmap, :x, :y, :z).new(false) }.each { |name, value| log_sprite.instance_variable_set(name, value) }
tab_names = lambda { parts.map { |_, text, _| text } & MGQ_MpChat::TAB_NAMES.values }
shades = lambda { events.select { |kind, args| kind == :fill && args[4].equal?(Sprite_MpChatLog::CLOSED_SHADE) } }

chat.start_typing
chat.select_tab(:map, "in the test")
chat.stop_typing
log_sprite.update
check("the closed log draws no tabs while none holds unread lines", [tab_names.call, shades.call, events.count { |kind, _| kind == :glow }], [[], [], 0])
$inbox << entry("message", friend_seat, "chat=hello all\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
log_sprite.update
global = log_sprite.instance_variable_get(:@tab_spots).find { |tab, _, _| tab == :global }
shade = events.index { |kind, args| kind == :fill && args[4].equal?(Sprite_MpChatLog::CLOSED_SHADE) && args[0] == global[1] }
glow = events.index { |kind, right| kind == :glow && right == global[1] + global[2] }
check("a global line that came on the Map tab draws the tabs above the closed log, each under the shade, the Global tab glowing over its shade",
      [tab_names.call, shades.call.size, events.count { |kind, _| kind == :glow }, !shade.nil? && !glow.nil? && shade < glow],
      [MGQ_MpChat::TABS.map { |tab| MGQ_MpChat::TAB_NAMES[tab] }, MGQ_MpChat::TABS.size, 1, true])
$inbox << entry("message", friend_seat, "whisper=you there?\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
log_sprite.update
whisper = log_sprite.instance_variable_get(:@tab_spots).find { |tab, _, _| tab == :whisper }
check("a whisper makes the Whisper tab glow too, although the closed log shows it",
      [chat.unread_tabs, events.select { |kind, _| kind == :glow }.map(&:last).include?(whisper[1] + whisper[2]), chat.log_lines.last],
      [[:global, :whisper], true, "[Whisper] Friend: you there?"])
chat.start_typing
log_sprite.update
check("the open box draws the tabs without the shade, the glow still on", [tab_names.call.empty?, shades.call, events.count { |kind, _| kind == :glow }], [false, [], 2])
chat.select_tab(:all, "in the test")
chat.stop_typing
MGQ_MpOverworldSync.tick
log_sprite.update
check("the All tab takes the lines as seen, after which the closed log draws no tabs", [chat.unread_tabs, tab_names.call], [[], []])

# A line of the closed log fades over its last frames, each part of it at the same alpha; the open
# log fades nothing.
class Color
  attr_reader :red, :green, :blue, :alpha
  def initialize(red = nil, green = nil, blue = nil, alpha = nil); @red, @green, @blue, @alpha = red, green, blue, alpha; end
end
going = chat.log_entries.last
going.left = MGQ_MpUi::Style::FADE_FRAMES / 2
log_sprite.update
faded = parts.select { |_, _, color| color.is_a?(Color) && color.alpha }
check("a line of the closed log fades over its last frames, every part of it at the same alpha",
      [faded.map { |_, text, _| text }.join, faded.map { |_, _, color| color.alpha }.uniq, parts.size > faded.size], [going.to_s, [127], true])
going.left = MGQ_MpUi::Style::FADE_FRAMES
log_sprite.update
check("with FADE_FRAMES left it is whole again", parts.any? { |_, _, color| color.is_a?(Color) && color.alpha }, false)
going.left = 1
chat.start_typing
log_sprite.update
check("the open log fades nothing", parts.any? { |_, _, color| color.is_a?(Color) && color.alpha }, false)
chat.stop_typing
going.left = MGQ_MpChat::LOG_FRAMES

# The hints and the help name the new controls.
check("the empty box's hint points at Alt and fits the row, no longer than the Alt hint",
      [Sprite_MpChatLog::BOX_HINT.include?("Alt"), Sprite_MpChatLog::BOX_HINT.size <= Sprite_MpChatLog::ALT_HINT.size], [true, true])
check("the Alt hint names up and down", Sprite_MpChatLog::ALT_HINT.include?("↑↓: sent lines"), true)
check("the help names /r, the sent lines and the paste", [MGQ_MpChat::HELP.any? { |line| line.start_with?("/r") }, MGQ_MpChat::HELP.any? { |line| line.include?("Ctrl+V") }], [true, true])

# Closing the world forgets the lines sent and whom /r answers.
$open = false
MGQ_MpOverworldSync.tick
check("closing the world forgets the lines sent and whom /r answers", [chat.history, chat.reply_to], [[], nil])
check("and the Whisper tab with the whisper chat, for the map chat", [chat.whisper_tab?, chat.tabs.include?(:whisper), chat.channel, chat.tab], [false, false, :map, :all])
$open = true
$inbox << entry("message", friend_seat, told(friend))
MGQ_MpOverworldSync.tick

# The chats' commands, tags and colors, and the Whisper tab coming back.
$sent.clear
chat.choose(:global)
send_line("/m over here")
check("/m chooses the map chat, whose line is tagged and goes out marked say, as released games read it",
      [chat.channel, chat.log_lines.last, $sent.last[1].include?("ch=say"), $sent.last[1].include?("map=5")], [:map, "[Map] Me: over here", true, true])
send_line("/map still here")
check("as does /map", [chat.channel, chat.log_lines.last], [:map, "[Map] Me: still here"])
chat.choose(:global)
$sent.clear
send_line("/s hi")
check("/s is no command any more, just text in the chat chosen", [chat.channel, chat.log_lines.last, $sent.last[1].include?("ch=")], [:global, "Me: /s hi", false])
send_line("/say hi")
check("nor is /say", [chat.channel, chat.log_lines.last], [:global, "Me: /say hi"])
$inbox << entry("message", friend_seat, "chat=hello world\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
check("a global line has no tag, its tab, text and bubble plain white",
      [chat.log_lines.last, chat.log_entries.last.tag, Sprite_MpChatLog::CHANNEL_COLORS[:global].equal?(MGQ_MpUi::Style::TEXT), Sprite_MpChatLog::COLORED_TEXT.include?(:global)],
      ["Friend: hello world", "", true, false])
$inbox << entry("message", friend_seat, "chat=on your map\nch=say\nmap=5\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
check("a line marked say lands in the map chat, its text in the map chat's color",
      [chat.log_entries.last.channel, chat.log_lines.last, chat.bubble_channel(friend_seat), Sprite_MpChatLog::COLORED_TEXT.include?(:map)], [:map, "[Map] Friend: on your map", :map, true])
check("the chats take the colors of World of Warcraft", [:map, :party, :whisper].map { |channel| Sprite_MpChatLog::CHANNEL_COLORS[channel].instance_eval { [red, green, blue] } },
      [[255, 192, 192], [170, 170, 255], [255, 128, 255]])
check("the help names /m for the map chat and no /s", [MGQ_MpChat::HELP.any? { |line| line.start_with?("/m ") }, MGQ_MpChat::HELP.any? { |line| line.start_with?("/s ") }], [true, false])
check("no whisper since the world opened again shows no Whisper tab", chat.tabs.include?(:whisper), false)
chat.choose(:whisper)
check("choosing the whisper chat shows it and lands on it", [chat.tabs.last, chat.channel], [:whisper, :whisper])
$open = false
MGQ_MpOverworldSync.tick
$open = true
$inbox << entry("message", friend_seat, told(friend))
MGQ_MpOverworldSync.tick
chat.whisper("Friend")
check("as does a whisper chosen from a player's menu", [chat.tabs.last, chat.channel, chat.whisper_to], [:whisper, :whisper, "Friend"])
