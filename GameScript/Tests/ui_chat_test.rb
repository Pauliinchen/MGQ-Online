#----------------------------------------------------------------
#  ui_chat_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Reached the Mod Framework's engine under its own name
#                            - Left how the UI layer draws the chat to the in-game suite and kept the gates, the model's calls and the bubbles' players
#      Paulinchen  2026-11-05: Handed the kept size as the width and lines the DLL reads
#                            - Checked that a scene whose class has no name reaches the chat's model by the class it builds on
#      Paulinchen  2026-11-01: Checked the chat on the Mod Framework's components against the chat's model
#                            - Checked the chat box opening over a window that hosts the scene
#      Paulinchen  2026-10-31: Kept the boxes' places in the Mod Framework's settings
#                            - Checked the boxes registered with the Mod Framework's layout
#      Paulinchen  2026-10-30: Dropped the checks of a missing method and of two equal constants
#      Paulinchen  2026-10-23: Acted on typing a frame after it, as the text box in C# reports it
#                            - Read the lines sent through the DLL's chat.send, and the names the DLL numbers
#                            - Read the lines sent here
#                            - Checked that the live map behind a menu shows no chat log
#      Paulinchen  2026-10-22: Checked the chat box and its log in a scene of menus such as a shop
#                            - Checked that a mod loaded later keeps its hook in a shop
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

# Covers ui_chat.rbx against the chat's model on the fake bridge (chat_support.rb): where the log
# shows and starts, the hotkey and the gates that open the box, the typing and the keys handed to
# the model, the rows of the view's lines, the bubbles' players, and the game's own lines. How the
# UI layer draws the chat is the in-game suite's (32_step9_b_chat.rb); the chat's rules are
# MGQOnline.Game.Tests'.

# The game's font, as far as the components measure with it.
class Font
  attr_accessor :name, :size, :color, :bold, :italic, :outline, :shadow, :out_color

  # Makes a font of 24 pixels.
  def initialize; @size = 24; end
end

# The game's picture, as far as the components measure texts on it: half the font's size a
# character.
class Bitmap
  attr_reader :width, :height, :font

  # Makes a picture with a font.
  def initialize(width = 1, height = 1); @width, @height, @font = width, height, Font.new; end
  # Measures a text.
  def text_size(text); Struct.new(:width, :height).new(text.to_s.size * @font.size.to_i / 2, @font.size.to_i); end
  # Answers that it was never freed.
  def disposed?; false; end
end

require_relative "world_support"

engine = Mod_Framework::UI::Engine
chat = MGQ_MpChat
model = $fake_chat
friend = { "id" => "friend", "name" => "Friend", "sprite" => "Actor2", "index" => 3, "map" => 5, "x" => 10, "y" => 10, "d" => 4, "speed" => 4, "hidden" => 0, "scene" => "map" }
$inbox << entry("seat", 0)
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts

# A character's place on the screen, which a bubble follows.
class Game_Character; def screen_x; 0; end; end

# The chats' colors, which the framework's DLL takes as names in the game, taken as names here.
declarations = Mod_Framework::UI::Engine::Declarations
known_color = declarations.method(:color?)
declarations.define_singleton_method(:color?) { |value| MGQ_MpChat::CHANNEL_RGB.key?(value) || known_color.call(value) }

# Stands in for whether the action wheel is open, which ui_actions.rbx tells, from $wheel_open.
MGQ_MpActions.define_singleton_method(:wheel_open?) { $wheel_open ? true : false }

# Posts a view of the chat's model and lets the frame take it.
#
# @param changes [Hash] What differs from the view the model holds.
def view(changes)
  $fake_chat.post(changes)
  ui_frame
end

# The log on the map: nothing to show, then lines.
map_frame
check("with nothing to show the log shows nowhere, so the player arranges it only while it shows lines", chat.root, nil)
lines = [["[Party] ", "Friend: ", "wait at the inn", "member", "party", "friend", nil], ["", "* ", "Friend left the battle.", "system", nil, nil, 6]]
view("lines" => lines)
map_frame
check("a line shows the log in the map's own place", [chat.root && chat.root.open?, chat.place], [true, :chat])
height = chat::TAB_ROW + chat::ROW * 6 + chat::BOX_ROW
check("it starts at the bottom left, above the status line, 400 wide and 6 lines high", chat.default_place(:chat), [[8, 480 - 96 - height], [400, height]])
$player_ini["chat_size"] = [450, 8]
check("a size kept in chat_size by earlier builds is its default", chat.default_place(:chat)[1], [450, chat::TAB_ROW + chat::ROW * 8 + chat::BOX_ROW])
$player_ini["chat_size"] = [300, 2]
check("one smaller than the least size starts at the least", chat.default_place(:chat)[1], chat::MIN_SIZE)
$player_ini.delete("chat_size")
rows = chat.rows(false)
check("a line shows its tag in the chat's color, the name in the sender's and the text plain, and no name takes a click while the box is closed",
      rows[0], [{ :text => "[Party] ", :color => :mgq_online_chat_party }, { :text => "Friend: ", :color => :ally }, { :text => "wait at the inn" }])
check("a game line's mark is dim, and a line in its last frames fades", [rows[1][:parts][0][:color], rows[1][:opacity]], [:dim, 255 * 6 / 12])
check("open, another player's name takes a click", chat.rows(true)[0][1][:data], "friend")
check("the tabs show above the closed log only while one holds unread lines", [chat.unread_shown?, (view("unread" => ["global"]); chat.unread_shown?)],
      [false, true])
view("unread" => [])

# The hotkey opens the box through the model, which the others see.
$pressed = MGQ_MpHotkeys.code(:chat)
map_frame
check("T opens the box through the chat's model, naming the keys that close it as it types, Esc and Numpad 0, not the X that types an x",
      [model.requests("chat.open"), chat.typing?], [[{ "key" => true, "scene" => "Scene_Map", "close" => "Esc or Numpad 0" }], true])
MGQ_MpOverworldSync.tick
check("the others see the player types", MGQ_MpOverworldSync::Me.scene, "typing")
check("the box names the chat it sends to in its color, and the empty box its hint without a close key",
      [chat.label, chat.label_color, chat.hint], ["Global:", nil, chat::BOX_HINT])
chat.typed("hi")
check("what is typed goes to the model with the caret at its end", model.requests("chat.typed").last, { "text" => "hi", "cursor" => 2 })
chat.key("Alt+Up")
chat.key("Alt+Right")
check("Alt with Up brings back a line sent and Alt with Right steps the tabs, through the model", model.requests("chat.alt"), [[0, -1], [1, 0]])
chat.key("Tab")
check("Tab without names showing does nothing", model.requests("chat.take_pick"), [])
model.view = model.view.merge("suggestions" => ["Friend", "Fiona"])
chat.take_name(1)
check("a name taken from the box's list is picked through the model, then taken", [model.requests("chat.pick"), model.requests("chat.take_pick").size], [[1], 1])
model.view = model.view.merge("channel" => "whisper", "whisper_to" => "Friend")
chat.take_view(model.view)
check("the box names whom it whispers to, in the whisper's color", [chat.label, chat.label_color], ["To Friend:", :mgq_online_chat_whisper])
chat.pick_tab("help")
model.view = model.view.merge("tab" => "help")
chat.take_view(model.view)
check("on the help tab the box takes no typing and its hint names the close keys", [chat.help_tab?, chat.hint.start_with?(chat::HELP_HINT)], [true, true])
check("a tab picked goes to the model", model.requests("chat.tab"), ["help"])
model.view = model.view.merge("tab" => "all", "channel" => "global", "whisper_to" => nil, "suggestions" => [])
chat.cancelled
check("cancel closes the box through the model, the log staying", [model.requests("chat.close"), chat.typing?, chat.root.open?], [["cancel"], false, true])
chat.start_typing
chat.enter
check("Enter goes to the model, which closes the box", [model.requests("chat.enter").size, chat.typing?], [1, false])

# The gates of the map.
$game_message.busy = true
$pressed = MGQ_MpHotkeys.code(:chat)
map_frame
check("an event's message lets the box open", chat.typing?, true)
chat.stop_typing
$pressed = MGQ_MpHotkeys.code(:chat)
$scene_change_ok = false
Scene_Map.new.update
check("also from the map's update while the message stops the map's own", chat.typing?, true)
chat.stop_typing
$scene_change_ok = true
$game_message.busy = false
# An event interpreter whose running is set from outside.
class Interpreter; attr_writer :running; def running?; @running ? true : false; end; end
$game_map.interpreter.running = true
$pressed = MGQ_MpHotkeys.code(:chat)
map_frame
check("an event without a message keeps the box shut", chat.typing?, false)
# Stands in for coop_gather.rbx, waiting for the party's story while $party_waiting is set.
module MGQ_MpCoopGather; def self.waiting?; $party_waiting; end; end
$party_waiting = true
$pressed = MGQ_MpHotkeys.code(:chat)
map_frame
check("but it opens while the player waits for the party's story", chat.typing?, true)
$party_waiting = false
$game_map.interpreter.running = false
chat.stop_typing
$wheel_open = true
$pressed = MGQ_MpHotkeys.code(:chat)
map_frame
check("the action wheel keeps T from opening the box", chat.typing?, false)
$wheel_open = false

# A scene of menus the chat follows, such as a shop: a question of a mod holds the buttons there.
class Scene_TestShop < Scene_Base; end
chat.follow_scene(Scene_TestShop)
shop = Scene_TestShop.new
SceneManager.scene = shop
engine::Capture.start(:confirm)
$pressed = MGQ_MpHotkeys.code(:chat)
shop.update_basic
check("while a question of a mod holds the buttons in a shop, the chat key waits", chat.typing?, false)
engine::Capture.stop(:confirm)
$pressed = MGQ_MpHotkeys.code(:chat)
shop.update_basic
check("without it the chat key opens the box in the shop's place", [chat.typing?, chat.place], [true, :menu_chat])
chat.stop_typing
staged = []
$world_fake.answer("chat.scene") { |request| staged << request; nil }
SceneManager.scene = Class.new(Scene_TestShop).new
MGQ_MpOverworldSync.tick
MGQ_Multiplayer::Bridge.frame
check("a scene whose class has no name, such as one a mod makes, reaches the chat's model by the class it builds on", staged.last["scene"], "Scene_TestShop")
$world_fake.answer("chat.scene") { |_request| nil }
SceneManager.scene = Scene_Map.new
map_frame
check("back on the map the log shows in the map's place again", chat.place, :chat)

# The bubbles.
view("bubbles" => { 2 => ["hello", "party"], chat::OWN_SEAT => ["hi", "global"] })
check("a bubble shows over each sender the view names, following their ghost or the player",
      [chat.bubbles.keys.sort, chat.bubble_character(2).equal?(MGQ_MpOverworldSync::Peers.at(2).ghost), chat.bubble_character(chat::OWN_SEAT).equal?($game_player)],
      [[chat::OWN_SEAT, 2], true, true])
$wheel_open = true
hidden = chat.bubble_hidden?(chat::OWN_SEAT)
$wheel_open = false
check("the player's own bubble hides while the action wheel is open", [hidden, chat.bubble_hidden?(chat::OWN_SEAT)], [true, false])
view("bubbles" => { 2 => ["hello", "party"] })
check("a bubble the view no longer has goes", chat.bubbles.keys, [2])
$inbox << entry("message", 2, told(friend.merge("map" => 9)))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
check("a sender who leaves the map hides their bubble instead of leaving it where they stood", chat.bubble_hidden?(2), true)

# The game's own lines, and the world closing.
chat.system("Friend left the battle.")
check("a game line goes to the model", model.requests("chat.game_line"), ["Friend left the battle."])
$open = false
MGQ_MpOverworldSync.tick
check("closing the world closes the log and the bubbles", [chat.root, chat.bubbles], [nil, {}])
$open = true
