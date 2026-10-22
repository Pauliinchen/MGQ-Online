#----------------------------------------------------------------
#  ui_chat_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-22: Checked the chat box and its log in a scene of menus such as a shop
#                            - Checked the relay's notice handed to the notification box
#      Paulinchen  2026-10-12: Checked the relay's notice in red between slashes
#                            - Checked the open log scrolled with the mouse wheel and its scrollbar
#                            - Checked every chat tab going back to All as the world closes
#      Paulinchen  2026-10-11: Checked the dimmed tabs with the closed log's last line
#                            - Expected the chat to start in and return to the global chat
#                            - Checked the chat log's places in the layout
#                            - Checked the open chat drawn in the preset's frame
#                            - Checked the map chat, /s, the untagged global chat and the Whisper tab
#                            - Created
#
#----------------------------------------------------------------

# Covers ui_chat.rbx: the lines sent that Alt with up and down bring back, /r answering the last
# player who whispered, the sound of a whisper that arrives while the chat box is closed, a paste,
# which the DLL hands over as typed text, the tabs drawn dimmed above the closed log while one
# holds unread lines, the Whisper tab shown only once a whisper happened, the chats' commands,
# tags and colors, and the log's places in the layout and its frame in the preset. The rest of the
# chat is covered by overworld_test.rb, whose stand-in for the chat log's sprite and canvas the one
# below mirrors.

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
check("a line brought back and sent again is sent once more and kept once", [chat.log_lines.last, chat.history.last(2)], ["Me: line 25", ["line 24", "line 25"]])

check("the global chat is the one chosen first, and a /w naming nobody shows no Whisper tab", [chat.channel, chat.whisper_tab?, chat.tabs], [:global, false, [:all, :global, :map, :party]])
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

# The game's sprite, which updates nothing.
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
# The game's picture, whose new one is always the canvas above.
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
{ :@layout_id => :chat, :@wrapped => {}, :@tab_spots => [], :@name_spots => [], :@size => [400, 6], :@width => 400, :@rows => 6, :@bottom_room => 96, :@resting_z => 100,
  :@menu_sprite => Struct.new(:visible, :bitmap, :x, :y, :z).new(false) }.each { |name, value| log_sprite.instance_variable_set(name, value) }
# The tab names drawn.
tab_names = lambda { parts.map { |_, text, _| text } & MGQ_MpChat::TAB_NAMES.values }
# The fills in the closed log's shade.
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
lasting = chat.instance_variable_get(:@log).map { |line| [line, line.left] }
lasting.each { |line, _| line.left = 0 }
log_sprite.update
check("once the closed log's lines ran out, it draws no tabs, though chats hold unread lines", [chat.unread_tabs, tab_names.call], [[:global, :whisper], []])
lasting.each { |line, left| line.left = left }
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

# The game's color, which keeps its values.
class Color
  # Its values, nil where not given.
  attr_reader :red, :green, :blue, :alpha
  # Creates a color.
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

# The open log scrolled with the mouse wheel, three rows a notch, and its scrollbar.
(1..12).each { |n| chat.system("wheel line #{n}") }
chat.start_typing
log_sprite.update
# The scrollbar's fills, each x, y, width and height.
bars = lambda { events.select { |kind, args| kind == :fill && args[2] == MGQ_MpUi::Style::SCROLLBAR_WIDTH }.map { |_, args| args[0, 4] } }
total = chat.log_entries.size
thumb = 6 * 19 * 6 / total
check("the open log draws a scrollbar right of its rows, its thumb at the newest",
      bars.call, [[400 - 9, Sprite_MpChatLog::TAB_ROW, 4, 6 * 19], [400 - 9, Sprite_MpChatLog::TAB_ROW + 6 * 19 - thumb, 4, thumb]])
$mouse = [100, 250]
$wheel = 1
log_sprite.update
check("the wheel turned up over it scrolls three rows a notch", [chat.scroll, bars.call.last[1]], [3, Sprite_MpChatLog::TAB_ROW + (6 * 19 - thumb) * (total - 9) / (total - 6)])
$wheel = -2
log_sprite.update
check("turned down it scrolls back no farther than the newest row", chat.scroll, 0)
$wheel = 1
$mouse = [620, 20]
log_sprite.update
check("nothing while the mouse points elsewhere", chat.scroll, 0)
$wheel = nil
$mouse = nil
chat.stop_typing
log_sprite.update
check("the closed log draws no scrollbar", bars.call, [])

# The hints and the help name the new controls.
check("the empty box's hint points at Alt and fits the row, no longer than the Alt hint",
      [Sprite_MpChatLog::BOX_HINT.include?("Alt"), Sprite_MpChatLog::BOX_HINT.size <= Sprite_MpChatLog::ALT_HINT.size], [true, true])
check("the Alt hint names up and down, and that a drag moves or resizes", [Sprite_MpChatLog::ALT_HINT.include?("↑↓: sent"), Sprite_MpChatLog::ALT_HINT.include?("Drag: move, resize")], [true, true])
check("the help names /r, the sent lines and the paste", [MGQ_MpChat::HELP.any? { |line| line.start_with?("/r") }, MGQ_MpChat::HELP.any? { |line| line.include?("Ctrl+V") }], [true, true])
check("the help says Alt and a drag move or resize the chat and a double click puts it back",
      MGQ_MpChat::HELP.any? { |line| line.include?("move or resize the chat") && line.include?("double click put it back") }, true)

# Closing the world forgets the lines sent and whom /r answers.
$open = false
MGQ_MpOverworldSync.tick
check("closing the world forgets the lines sent and whom /r answers", [chat.history, chat.reply_to], [[], nil])
check("and the Whisper tab with the whisper chat, for the global chat", [chat.whisper_tab?, chat.tabs.include?(:whisper), chat.channel, chat.tab], [false, false, :global, :all])
$open = true
$inbox << entry("message", friend_seat, told(friend))
MGQ_MpOverworldSync.tick

# A chat tab picked goes back to All with the global chat as the world closes, so the next world
# shows the lines it sends.
chat.start_typing
chat.select_tab(:party, "in the test")
chat.stop_typing
$open = false
MGQ_MpOverworldSync.tick
check("the Party tab goes back to All as the world closes, with the global chat", [chat.tab, chat.channel], [:all, :global])
$open = true
$inbox << entry("message", friend_seat, told(friend))
MGQ_MpOverworldSync.tick
send_line("hello")
check("the player's own global line shows in the closed log of the next world", chat.log_lines.include?("Me: hello"), true)
chat.start_typing
check("and in the open one", chat.log_lines.include?("Me: hello"), true)
chat.select_tab(:map, "in the test")
chat.open_help
$open = false
MGQ_MpOverworldSync.tick
check("the help opened from the Map tab goes back to All too, forgetting the tab it came from",
      [chat.tab, chat.channel, chat.instance_variable_get(:@before_help)], [:all, :global, nil])
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

# The log's places in the layout and its frame in the preset, drawn on pictures that keep their
# size and measure as the game's VL Gothic does: half the font's size for an ASCII character, the
# whole size for any other, such as an arrow.
layout = MGQ_MpUi::Layout
style = MGQ_MpUi::Style
log_class = Sprite_MpChatLog
# The game's viewport, as far as its depth.
class Viewport; attr_accessor :z; def dispose; end; end
# The game's sprite, with its picture, place, depth and viewport.
class Sprite
  # Its picture, place, depth and whether it shows.
  attr_accessor :bitmap, :x, :y, :z, :visible
  # The viewport it lies in.
  attr_reader :viewport
  # Creates a visible sprite at the top left.
  def initialize(viewport = nil); @viewport = viewport; @x = @y = @z = 0; @visible = true; end
  # Frees nothing.
  def dispose; end
end
# A picture that keeps its size and records its fills and texts.
class Picture
  # The picture's font.
  Font = Struct.new(:size, :color, :bold, :outline, :out_color)
  # Its size, its font, and the fills and texts drawn, each with its place and size.
  attr_reader :width, :height, :font, :fills, :texts
  # Creates an empty picture in a font of 16.
  def initialize(width, height); @width, @height = width, height; @font = Font.new(16); @fills = []; @texts = []; end
  # Measures a text as VL Gothic does: half the size for an ASCII character, the whole size for others.
  def self.measure(text, size); text.to_s.each_char.inject(0) { |sum, char| sum + (char.ord < 128 ? size / 2 : size) }; end
  # The picture's whole rectangle.
  def rect; Rect.new(0, 0, @width, @height); end
  # Measures a text in the picture's font.
  def text_size(text); Rect.new(0, 0, Picture.measure(text, font.size), font.size); end
  # Records a text drawn with its rectangle and font size.
  def draw_text(x, y, width, height, text, _align = 0); @texts << [x, y, width, height, text.to_s, font.size]; end
  # Records a fill with its rectangle and color.
  #
  # @param args [Array] A rectangle and a color, or x, y, width, height and a color.
  def fill_rect(*args)
    x, y, width, height, color = args[0].is_a?(Rect) ? [args[0].x, args[0].y, args[0].width, args[0].height, args[1]] : args
    @fills << [x, y, width, height, color]
  end
  # Forgets the fills and texts.
  def clear; @fills.clear; @texts.clear; end
  # Frees nothing.
  def dispose; end
end
Bitmap.define_singleton_method(:new) { |width, height| Picture.new(width, height) }
# The rectangle the layout offers a box, nil without an offer.
offered = lambda do |id|
  offer = layout.instance_variable_get(:@offers).find { |each| each.id == id }
  offer && offer.rect.to_a
end
# Forgets the places kept and offered.
forget_places = lambda { layout.instance_variable_get(:@stored).clear; layout.instance_variable_set(:@offers, []) }
# The log's height for a number of rows: the tabs, the rows and the chat box's row.
high = lambda { |rows| log_class::TAB_ROW + log_class::ROW * (rows + 1) }

check("the map's, the battle's and the menus' log are boxes of their own, resized both ways, no smaller than the tabs, the hints and the list of names need",
      [:chat, :battle_chat, :menu_chat].map { |id| box = layout.instance_variable_get(:@boxes)[id]; box && [box.name, box.min_width, box.min_height, box.resize] },
      [["Chat", 400, high.call(MGQ_MpChat::SUGGESTIONS), :both], ["Battle chat", 400, high.call(MGQ_MpChat::SUGGESTIONS), :both], ["Menu chat", 400, high.call(MGQ_MpChat::SUGGESTIONS), :both]])
check("the chat keeps no resizing of its own", [chat.respond_to?(:resize), chat.respond_to?(:keep_size)], [false, false])
check("the chat's Alt is the layout's", MGQ_MpChat::ALT_KEY, layout::ALT_KEY)

$player_ini.delete("chat_size")
chat.instance_variable_set(:@size, nil)
forget_places.call
map_log = log_class.new(:chat, log_class::STATUS_ROOM, 100)
chat.start_typing
map_log.update
check("the map's log starts where it lay before: at the left, standing on the status line's room, at the default size",
      [offered.call(:chat), map_log.bitmap.width, map_log.bitmap.height, map_log.x, map_log.y], [[8, 480 - 96 - high.call(6), 400, high.call(6)], 400, high.call(6), 8, 480 - 96 - high.call(6)])
$player_ini["chat_size"] = "450x8"
chat.instance_variable_set(:@size, nil)
map_log.update
check("a size kept in chat_size by earlier builds is its default", offered.call(:chat), [8, 480 - 96 - high.call(8), 450, high.call(8)])
$player_ini["chat_size"] = "250x2"
chat.instance_variable_set(:@size, nil)
map_log.update
check("one smaller than the least size starts at the least", offered.call(:chat), [8, 480 - 96 - high.call(5), 400, high.call(5)])
$player_ini["chat_size"] = "450x8"
chat.instance_variable_set(:@size, nil)

$player_ini["ui_chat"] = "100,40,520,200"
forget_places.call
map_log.update
check("a place kept as ui_chat is honored, with the whole rows that fit its height, the picture standing on its bottom",
      [offered.call(:chat), map_log.instance_variable_get(:@rows), map_log.x, map_log.y], [[100, 51, 520, high.call(8)], 8, 100, 51])
$player_ini["ui_chat"] = "100,40,520,#{high.call(9) - 1}"
forget_places.call
map_log.update
check("a pixel short of another row keeps the rows", map_log.instance_variable_get(:@rows), 8)
$player_ini["ui_chat"] = "100,40,520,#{high.call(9)}"
forget_places.call
map_log.update
check("a whole row more adds one", [map_log.instance_variable_get(:@rows), offered.call(:chat)], [9, [100, 40, 520, high.call(9)]])
$player_ini["ui_chat"] = "0,0,50,20"
forget_places.call
map_log.update
check("a kept place smaller than the least is drawn at the least", [offered.call(:chat), map_log.instance_variable_get(:@rows)], [[0, 0, 400, high.call(5)], 5])

# At the least size every tab and hint fits.
hint_fits = lambda do |hint|
  row = map_log.bitmap.texts.find { |text| text[4] == hint }
  row && Picture.measure(hint, row[5]) <= row[2] && row[0] + row[2] <= map_log.bitmap.width ? row[5] : nil
end
chat.choose(:global)
map_log.update
check("the empty box's hint fits the least width in the small font", hint_fits.call(log_class::BOX_HINT), style::SMALL_SIZE)
chat.choose(:whisper)
whisper_to = chat.whisper_to
chat.instance_variable_set(:@whisper_to, nil)
$down = [MGQ_MpChat::ALT_KEY]
map_log.update
check("the Alt hint fits after the longest chat's label, in the tiny font", [hint_fits.call(log_class::ALT_HINT), map_log.bitmap.texts.any? { |text| text[4] == "Whisper:" }], [style::TINY_SIZE, true])
check("while Alt is held the open chat's outline is white", map_log.bitmap.fills.any? { |fill| fill[4].equal?(log_class::RESIZE_OUTLINE) }, true)
$down = []
chat.instance_variable_set(:@whisper_to, whisper_to)
chat.open_help
map_log.update
spots = map_log.instance_variable_get(:@tab_spots)
check("the help tab's hint fits too, and every tab, the help tab at the far right, without overlapping",
      [hint_fits.call(log_class::HELP_HINT), spots.map(&:first), spots.each_cons(2).all? { |(_, left, width), (_, right, _)| left + width <= right }, spots.last[1] + spots.last[2]],
      [style::TINY_SIZE, MGQ_MpChat::TABS + [:help], true, 400])
chat.select_tab(:all, "in the test")

# The open chat in the preset's frame, open under the picked tab, Legacy's one pixel of edge.
MGQ_MpUi::Theme.apply("Legacy", "in the test")
map_log.update
picture = map_log.bitmap
_, at, width = map_log.instance_variable_get(:@tab_spots).find { |tab, _, _| tab == :all }
top_edge = picture.fills.index { |fill| fill[0..3] == [0, log_class::TAB_ROW, 400, 1] && fill[4].equal?(style::EDGE) }
gap = picture.fills.index { |fill| fill[0..3] == [at + 1, log_class::TAB_ROW, width - 2, 1] && fill[4].equal?(style::BACK) }
check("the open chat is framed in the preset's edge, opened under the picked tab", [!top_edge.nil?, !gap.nil? && gap > top_edge], [true, true])
picture.clear
map_log.update
check("an unchanged log is not drawn again", picture.fills, [])
MGQ_MpUi::Theme.apply("Monarch", "in the test")
map_log.update
gap = picture.fills.index { |fill| fill[0..3] == [at + 2, log_class::TAB_ROW, width - 4, 2] && fill[4].equal?(style::BACK) }
check("a change of the preset draws it anew, its rim outermost and the gap as deep as the frame",
      [picture.fills.any? { |fill| fill[4].equal?(style::RIM) }, !gap.nil?], [true, true])
MGQ_MpUi::Theme.apply("Legacy", "in the test")
chat.open_menu(MGQ_MpChat::Line.new("Friend", "hi", :other, :global, 0, nil, "friend"), [50, 300])
map_log.update
menu = map_log.instance_variable_get(:@menu_sprite).bitmap
check("a player's menu lies in the preset's box",
      [menu.fills.first[0..3] == [0, 0, menu.width, menu.height] && menu.fills.first[4].equal?(style::BACK), menu.fills.any? { |fill| fill[4].equal?(style::EDGE) }], [true, true])
chat.close_menu("in the test")

# The layout alone moves and resizes the log.
$player_ini["ui_chat"] = "100,40,520,200"
forget_places.call
map_log.update
before = offered.call(:chat)
$down = [MGQ_MpChat::ALT_KEY]
$mouse_held = true
$mouse = [map_log.x + 20, map_log.y + map_log.bitmap.height - 4]
map_log.update
$mouse = [map_log.x + 80, map_log.y - 40]
map_log.update
$mouse_held = false
map_log.update
$down = []
check("Alt and a drag on the open log leave its size and place to the layout", [$player_ini["chat_size"], offered.call(:chat)], ["450x8", before])

battle_log = log_class.new(:battle_chat, log_class::BATTLE_ROOM, 200)
battle_log.update
check("the battle's log starts above the battle's windows at chat_size's size, apart from the map's place",
      [offered.call(:battle_chat), offered.call(:chat)], [[8, 480 - 200 - high.call(8), 450, high.call(8)], before])
$player_ini["chat_size"] = "450x14"
chat.instance_variable_set(:@size, nil)
battle_log.update
check("its default draws only the rows that fit above the battle's windows", offered.call(:battle_chat), [8, 480 - 200 - high.call(12), 450, high.call(12)])
$player_ini["ui_battle_chat"] = "200,10,420,150"
forget_places.call
battle_log.update
map_log.update
check("a place kept as ui_battle_chat moves the battle's log alone", [offered.call(:battle_chat), offered.call(:chat)], [[200, 10 + 150 - high.call(5), 420, high.call(5)], before])

chat.stop_typing
$inbox << entry("message", friend_seat, "chat=still here\nname=Friend\n\n")
MGQ_MpOverworldSync.tick
layout.instance_variable_set(:@offers, [])
map_log.update
check("the closed log is offered while it shows lines, so it moves without opening the box", offered.call(:chat), before)
$open = false
MGQ_MpOverworldSync.tick
layout.instance_variable_set(:@offers, [])
map_log.update
check("and not once it shows nothing", offered.call(:chat), nil)

# The relay's notice, such as a new release's, which reaches the chat as an admin's line named
# MGQ_MpChat::NOTICE_NAME, and the notification box, which stands in here.
module MGQ_MpNotices; def self.announce(text); ($announced ||= []) << text; end; end
chat.take_line(nil, "MGQ Online 0.6.5 is out.", MGQ_MpChat::NOTICE_NAME, :global, true)
check("the relay's notice goes to the notification box too", $announced, ["MGQ Online 0.6.5 is out."])
notice = chat.instance_variable_get(:@log).last
check("the relay's notice shows red between slashes, without a name or tag",
      [notice.to_s, notice.who, map_log.text_color(notice)], ["// MGQ Online 0.6.5 is out. //", :notice, log_class::NOTICE_COLOR])
check("in every tab", MGQ_MpChat::TABS.all? { |tab| notice.shown_in?(tab) }, true)
chat.take_line(nil, "hello", MGQ_MpChat::NOTICE_NAME, :global, false)
check("a player of that name says a plain line", [chat.instance_variable_get(:@log).last.who, map_log.text_color(chat.instance_variable_get(:@log).last)], [:other, MGQ_MpUi::Style::TEXT])
chat.take_line(nil, "hi", "Global", :global, true)
check("and an admin's line of another name stays an admin's", chat.instance_variable_get(:@log).last.to_s, "[Admin] Global: hi")

# A scene of menus the chat follows, such as a shop: the chat box opens with its key after each
# frame, takes typing there and shows its log, and goes once another scene shows.
class Scene_TestShop; def update_basic; end; def terminate; end; end
$open = true
chat.stop_typing
chat.follow_scene(Scene_TestShop)
shop = Scene_TestShop.new
SceneManager.scene = shop
$pressed = MGQ_MpHotkeys.code(:chat)
shop.update_basic
check("the chat key opens the chat box in a shop, which shows the menus' log", [chat.typing?, shop.instance_variable_get(:@mgq_mp_chat_log).class], [true, Sprite_MpChatLog])
chat.tick(true)
check("and the box stays open while the shop shows", chat.typing?, true)
SceneManager.scene = Object.new
chat.tick(true)
check("another scene closes it", chat.typing?, false)
SceneManager.scene = shop
MGQ_Multiplayer::Capture.start(:confirm)
$pressed = MGQ_MpHotkeys.code(:chat)
shop.update_basic
check("while a question of the mod holds the buttons there, the chat key waits", chat.typing?, false)
MGQ_Multiplayer::Capture.stop(:confirm)
shop.terminate
check("the log goes with the shop", shop.instance_variable_get(:@mgq_mp_chat_log), nil)
