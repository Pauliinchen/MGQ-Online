#----------------------------------------------------------------
#  ui_chat_test.rb
#
#  Changelog:
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

# Covers ui_chat.rbx on the Mod Framework's components against the chat's model on the fake bridge
# (chat_support.rb) and the component tree (bridge_support.rb): where the log shows and starts, the
# hotkey and the gates that open the box, the typing, the keys and the clicks handed to the model,
# the view shown in the tabs, the lines and the box, the player's menu, the bubbles on their
# players, and the game's own lines. The chat's rules are MGQOnline.Game.Tests'.

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

ui = Mod_Framework::UI
chat = MGQ_MpChat
tree = $fake_tree
model = $fake_chat
friend = { "id" => "friend", "name" => "Friend", "sprite" => "Actor2", "index" => 3, "map" => 5, "x" => 10, "y" => 10, "d" => 4, "speed" => 4, "hidden" => 0, "scene" => "map" }
$inbox << entry("seat", 0)
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts

# Tells a part of the open log's root.
#
# @param name [Symbol] :tabs, :lines, :row, :label or :field.
# @return [Mod_Framework::UI::Component] The part.
def part(name)
  MGQ_MpChat.instance_variable_get(:"@#{name}")
end

# Posts a view of the chat's model and lets the frame take it.
#
# @param changes [Hash] What differs from the view the model holds.
def view(changes)
  $fake_chat.post(changes)
  ui_frame
end

# The log on the map, closed and empty.
map_frame
root = chat.root
expected_height = chat::TAB_ROW + chat::ROW * 6 + chat::BOX_ROW
check("the map shows the log in its own place, at the bottom left above the status line, its box closed",
      [root.open?, root.id, root.place_name, root.at, root.size, root.frame, root.closable, root.z, root.mouse],
      [true, :chat, "Chat", [8, 480 - 96 - expected_height], [400, expected_height], false, false, 99, :parts])
check("with no line to show it hides, so the player arranges it only while it shows lines", root.hide_while.call, true)
check("the three places are listed for Interface Positions before the log shows there",
      [:chat, :battle_chat, :menu_chat].map { |id| registered_box(id) && registered_box(id)[0] }, ["Chat", "Battle chat", "Menu chat"])
$player_ini["chat_size"] = [450, 8]
check("a size kept in chat_size by earlier builds is its default", chat.default_place(:chat),
      [[8, 480 - 96 - (chat::TAB_ROW + chat::ROW * 8 + chat::BOX_ROW)], [450, chat::TAB_ROW + chat::ROW * 8 + chat::BOX_ROW]])
$player_ini["chat_size"] = [300, 2]
check("one smaller than the least size starts at the least", chat.default_place(:chat)[1], chat::MIN_SIZE)
$player_ini.delete("chat_size")

# The closed log's lines.
closed_lines = [["[Party] ", "Friend: ", "wait at the inn", "member", "party", "friend", nil], ["", "* ", "Friend left the battle.", "system", nil, nil, 6]]
view("lines" => closed_lines, "unread" => [])
rows = part(:lines).rows
check("a line shows its tag in the chat's color, the name in the sender's and the text plain, and no name takes a click while the box is closed",
      [rows[0].map { |each| [each[:text], each[:color]] }, rows[0].any? { |each| each.key?(:data) }],
      [[["[Party] ", chat::CHANNEL_COLORS["party"]], ["Friend: ", ui::Style::MEMBER], ["wait at the inn", ui::Style::TEXT]], false])
check("a game line's mark is dim, and a line in its last frames fades", [rows[1][:parts][0][:color], rows[1][:opacity]], [ui::Style::DIM, 255 * 6 / 12])
check("the closed log shows, but its tabs only while one holds unread lines", [root.hide_while.call, part(:tabs).visible?], [false, false])
view("unread" => ["global"])
check("a tab with unread lines marks its tab and shows the tabs dimmed", [part(:tabs).visible?, part(:tabs).opacity, part(:tabs).tab(1).badge],
      [true, chat::CLOSED_TABS_OPACITY, true])
view("lines" => [], "unread" => [])

# The hotkey opens the box, which holds the game's buttons and types.
$pressed = MGQ_MpHotkeys.code(:chat)
map_frame
ui_frame
field = part(:field)
check("T opens the box through the chat's model, naming the keys that close it as it types, Esc and Numpad 0, not the X that types an x",
      model.requests("chat.open"), [{ "key" => true, "scene" => "Scene_Map", "close" => "Esc or Numpad 0" }])
check("open, the log is framed above everything, takes clicks and holds the game's buttons, its field typing",
      [root.frame, root.closable, root.captures, root.z, root.mouse, part(:row).visible?, field.editor.nil?, $mgq_text_input ? true : false],
      [true, true, true, ui::Z[:typing], true, true, false, true])
check("the others see the player types", MGQ_MpOverworldSync::Me.scene, "typing")
check("the box names the chat it sends to in its color, and the empty box its hint without a close key",
      [part(:label).text, part(:label).color, field.placeholder], ["Global:", chat::CHANNEL_COLORS["global"], chat::BOX_HINT])
check("the tabs, the label and the field draw in the small font", [part(:tabs).font_size, part(:label).font_size, field.font_size], [:small, :small, :small])

# Typing, Enter and the keys with Alt go to the model.
$typed = "hi"
map_frame
check("what is typed goes to the model with the caret", model.requests("chat.typed").last, { "text" => "hi", "cursor" => 2 })
field.caret = 1
view("lines" => [["", "* ", "Friend joined.", "system", nil, nil, nil]])
check("a line that comes keeps the caret where the player moved it", [field.text, field.caret], ["hi", 1])
view("box" => ["hi", 2, false], "channel" => "party")
view("box" => ["", 0, false])
check("a view that took a command out of the box sets the field's text and caret, and the label its chat", [field.text, field.caret, part(:label).text], ["", 0, "Party:"])
tree.post([[field.node, "key", 0x26 | 0x100], [field.node, "key", 0x27 | 0x100]])
ui_frame
check("Alt with Up brings back a line sent and Alt with Right steps the tabs, through the model", model.requests("chat.alt"), [[0, -1], [1, 0]])
view("tabs" => %w[all global map party whisper], "tab" => "map")
check("the tabs the view names show, the picked one lit", [(0..5).map { |index| part(:tabs).tab(index).visible? }, part(:tabs).index],
      [[true, true, true, true, true, false], 2])
tree.post([[part(:tabs).tab(3).node, "click"]])
ui_frame
check("a click on a tab picks it through the model", model.requests("chat.tab"), ["party"])

# The names that fit a whisper.
view("box" => ["/w F", 4, false], "suggestions" => ["Friend", "Fiona"], "pick" => 0)
check("the names that fit show over the field", field.completions, ["Friend", "Fiona"])
tree.post([[field.node, "key", 0x28]])
ui_frame
tree.post([[field.node, "key", 0x09]])
ui_frame
check("Down moves the pick through the model and Tab takes it", [model.requests("chat.pick"), model.requests("chat.take_pick").size], [[1], 1])
view("box" => ["/w F", 4, false], "suggestions" => ["Friend", "Fiona"], "pick" => 1)
check("the pick the model holds lights in the field's list", field.completion_index, 1)
view("pick" => 0)
model.calls.clear
names = ui::Tree.roots.find { |each| each.is_a?(ui::CompletionBox) }
names.instance_variable_get(:@list).emit(:submit, "Fiona", 1)
ui_frame
check("a click on the second name picks it through the model before taking it", model.calls, [["chat.pick", 1], ["chat.take_pick", nil]])
view("box" => ["", 0, false], "suggestions" => [], "channel" => "whisper", "whisper_to" => "Friend")
check("the box names whom it whispers to", part(:label).text, "To Friend:")

# The help tab takes no typing.
view("tab" => "help", "box" => ["", 0, true])
check("on the help tab the field takes no typing and its hint names the close keys",
      [field.read_only, part(:label).text, field.placeholder], [true, "Help:", "#{chat::HELP_HINT} #{ui.close_hint}"])
view("tab" => "all", "box" => ["", 0, false], "channel" => "global", "whisper_to" => nil)

# A player's menu from their name.
view("lines" => [["", "Friend: ", "hello", "other", "global", "friend", nil], ["", "Me: ", "hi", "me", "global", nil, nil]])
rows = part(:lines).rows
check("open, another player's name takes a click, the player's own not", rows.map { |row| row.find { |each| each[:data] } ? true : false }, [true, false])
$mouse = [120, 300]
logged = logged_lines { part(:lines).emit(:click, rows[0], rows[0][0]) }
menu = ui::Menu.current
choices = menu.instance_variable_get(:@choices).map { |choice| choice[:text] }
check("a click on it opens their menu at the pointer, above the box, with what the scripts offer and a whisper",
      [menu.nil?, choices.last, choices.size > 1, menu.z > root.z, logged.grep(/menu of Friend opened from the chat/).size], [false, "Whisper", true, true, 1])
menu.close(:cancel)
check("cancel closes the menu alone", [ui::Menu.current, chat.typing?], [nil, true])

# A battle keeps the box open in its own place.
battle = Scene_Battle.new
SceneManager.scene = battle
view("box" => ["on my way", 9, false])
battle.update_basic
check("in a battle the log shows in the battle's place, the open box keeping its text",
      [chat.root.id, chat.root.open?, root.open?, part(:field).text, chat.root.z], [:battle_chat, true, false, "on my way", ui::Z[:typing]])
logged_lines { part(:lines).emit(:click, part(:lines).rows[0], part(:lines).rows[0][0]) }
menu = ui::Menu.current
check("off the map a name's menu offers the whisper alone", menu.instance_variable_get(:@choices).map { |choice| choice[:text] }, ["Whisper"])
menu.instance_variable_get(:@list).emit(:submit, nil, 0)
ui_frame
check("which whispers to that player through the model", model.requests("chat.whisper"), [2])

# Cancel closes the box; the log stays.
$sounds.clear
$down = [ui::ESCAPE_KEY]
tree.post([[chat.root.node, "cancel"]])
ui_frame
$down = []
check("cancel closes the box through the model once, with one cancel sound, the log staying",
      [model.requests("chat.close"), $sounds.count("cancel"), chat.typing?, chat.root.open?, chat.root.closable, part(:field).editor],
      [["cancel (Esc)"], 1, false, true, false, nil])
check("the closed log's lines and tabs take no clicks, so they reach the game's windows below", [part(:lines).mouse, part(:tabs).mouse], [false, false])
SceneManager.scene = Scene_Map.new
map_frame
check("back on the map the log shows in the map's place again", chat.root.id, :chat)

# Enter sends through the model, which closes the box.
chat.start_typing
ui_frame
$typed = "\r"
map_frame
check("Enter goes to the model, and the closed box gives the keys back at once", [model.requests("chat.enter").size, chat.typing?, $mgq_text_input ? true : false], [1, false, false])

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
MGQ_MpActions.wheel.instance_variable_set(:@open, true)
$pressed = MGQ_MpHotkeys.code(:chat)
map_frame
check("the action wheel keeps T from opening the box", chat.typing?, false)
MGQ_MpActions.wheel.instance_variable_set(:@open, false)
# A scene of menus the chat follows, such as a shop: a question of a mod holds the buttons there,
# while a window that hosts the scene, such as the trade screen's, holds none over it.
class Scene_TestShop < Scene_Base; end
chat.follow_scene(Scene_TestShop)
shop = Scene_TestShop.new
SceneManager.scene = shop
ui::Capture.start(:confirm)
$pressed = MGQ_MpHotkeys.code(:chat)
shop.update_basic
check("while a question of a mod holds the buttons in a shop, the chat key waits", chat.typing?, false)
ui::Capture.stop(:confirm)
host = ui::Window.new(:title => "Trade", :size => :screen, :hosts_scene => true).open
$pressed = MGQ_MpHotkeys.code(:chat)
shop.update_basic
check("a window that hosts the scene, such as the trade screen's, holds the buttons but none over the scene: the chat key opens the box over it",
      [ui::Capture.on?, chat.typing?], [true, true])
chat.stop_typing
host.close
staged = []
$world_fake.answer("chat.scene") { |request| staged << request; nil }
SceneManager.scene = Class.new(Scene_TestShop).new
MGQ_MpOverworldSync.tick
MGQ_Multiplayer::Bridge.frame
check("a scene whose class has no name, such as one a mod makes, reaches the chat's model by the class it builds on", staged.last["scene"], "Scene_TestShop")
$world_fake.answer("chat.scene") { |_request| nil }
SceneManager.scene = Scene_Map.new

# The bubbles.
view("bubbles" => { 2 => ["hello", "party"], chat::OWN_SEAT => ["hi", "global"] })
friend_bubble = chat.bubbles[2]
own_bubble = chat.bubbles[chat::OWN_SEAT]
check("a bubble follows its sender's ghost just over their name, in their line's chat's color, the player's own over their ping",
      [friend_bubble.open?, friend_bubble.follow.equal?(MGQ_MpOverworldSync::Peers.at(2).ghost), friend_bubble.lift, friend_bubble.color, friend_bubble.text,
       own_bubble.follow.equal?($game_player), own_bubble.lift],
      [true, true, chat::GHOST_LIFT, chat::CHANNEL_COLORS["party"], "hello", true, chat::OWN_LIFT])
$inbox << entry("message", 2, told(friend.merge("party" => "theirs", "invite" => 1)))
MGQ_MpOverworldSync.tick
chat.place_bubbles
check("a line over the name lifts the bubble above it", friend_bubble.lift, chat::GHOST_LIFT + chat::LINE_LIFT)
MGQ_MpActions.wheel.instance_variable_set(:@open, true)
hidden = own_bubble.hide_while.call
MGQ_MpActions.wheel.instance_variable_set(:@open, false)
check("the player's own bubble hides while the action wheel is open", [hidden, own_bubble.hide_while.call], [true, false])
view("bubbles" => { 2 => ["hello", "party"] })
check("a bubble the view no longer has closes", [own_bubble.open?, chat.bubbles.keys], [false, [2]])

# Bubbles of players this map does not show.
$inbox << entry("message", 3, told(friend.merge("id" => "far", "name" => "Far", "map" => 9)))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
view("bubbles" => { 2 => ["hello", "party"], 3 => ["far away", "global"] })
far_bubble = chat.bubbles[3]
check("a Global line from a player on another map makes a bubble that follows no one and stays hidden, while the bubble of a player here shows",
      [far_bubble.open?, far_bubble.follow, far_bubble.hide_while.call, friend_bubble.hide_while.call], [true, nil, true, false])
$inbox << entry("message", 2, told(friend.merge("map" => 9)))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
chat.place_bubbles
check("a sender who leaves the map while their bubble shows hides it instead of leaving it where they stood",
      [friend_bubble.open?, friend_bubble.follow, friend_bubble.hide_while.call], [true, nil, true])

# The game's own lines, and the world closing.
chat.system("Friend left the battle.")
check("a game line goes to the model", model.requests("chat.game_line"), ["Friend left the battle."])
$open = false
MGQ_MpOverworldSync.tick
check("closing the world closes the log and the bubbles", [chat.root, friend_bubble.open?, chat.bubbles], [nil, false, {}])
$open = true
