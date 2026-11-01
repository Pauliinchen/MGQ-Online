#----------------------------------------------------------------
#  overworld_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#                            - Read the ghosts' labels, the own ping, the own line and the world status from the Mod Framework's components
#                            - Opened the action wheel through the Mod Framework's hotkey and read its pick from the framework's wheel
#                            - Left the chat's checks to ui_chat_test.rb and the chat model's tests, the chat's messages to C#
#      Paulinchen  2026-10-31: Placed the wheel's choices and read the capture and the typing through the Mod Framework
#      Paulinchen  2026-10-30: Answered the teleports' view from the party's stand-in
#                            - Dropped the fade checks
#                            - Dropped the checks that restate pixel positions
#      Paulinchen  2026-10-23: Opened the action wheel by its key and took a choice in the frame after confirm
#                            - Acted on typing a frame after it, as the text box in C# reports it
#                            - Played the DLL's events in place of the inbox and left the rules it keeps to its own tests
#                            - Checked the player's frame and the routes handed to the DLL, and the chat and party actions asked of it
#                            - Checked a player away whose seat another player took
#      Paulinchen  2026-10-17: Checked the teleport to the story on the action wheel
#      Paulinchen  2026-10-13: Checked that the relay's push of a Raid World's squad rules goes to its route
#      Paulinchen  2026-10-12: Checked that the players already in a world the player enters come without a notice
#                            - Checked when the time the player entered their map is set anew
#                            - Checked that nobody is told a state on the title screen
#      Paulinchen  2026-10-11: Chose the map chat before sending its line
#                            - Checked the status line's place and width in the layout
#                            - Left the chat log's resizing to ui_chat_test.rb
#                            - Checked the action wheel's boxes, the picked one lit and a redraw after a preset change
#                            - Checked the map chat, its tags and colors, and the hidden Whisper tab
#                            - Checked that a player outside the party is named in plain white
#                            - Checked the line above the player's head, the wheel's hint and their fading
#                            - Compared the chat log's text with the style's text color and gave the font an outline color
#                            - Checked the seconds left after a doing in the line above the player's head
#                            - Checked the frames a party invite stands for still, and none once it stopped
#                            - Checked a ghost's name color and the keyboard of a player typing
#                            - Read a label's colors by text and checked a ping past 999 ms
#      Paulinchen  2026-10-10: Checked the share left, max HP and defeat in the relay's boss pool push
#                            - Expected the teleport to the leader on the wheel of a member near them
#      Paulinchen  2026-10-09: Checked that the relay's push of a Raid World's boss pool goes to its route
#                            - Checked that the relay's push of a Raid World's difficulty goes to its route
#                            - Checked that the relay's push of a world's rule on other mods goes to its route
#                            - Checked that a stranger's ghost is solid in a Raid World and see-through in a Classic world
#      Paulinchen  2026-10-08: Checked the outline for a follower sprite this game lacks and the graphics kept
#                            - Checked that the relay's push of a Raid World's story goes to its route
#                            - Checked which tabs a line marks unread and that the All tab takes them as seen
#                            - Checked that a ghost's name tag numbers a name two players share
#                            - Started the status's frame count anew before checking a new connection's seat
#                            - Checked the global, say and party chats, their commands and the log's tabs
#                            - Checked that the numpad's Insert closes the chat box with Num Lock off
#                            - Checked the menu a click on a sender's name opens
#                            - Checked whispers, the help tab, the bubbles' chats and dropped Alt numpad typing
#                            - Checked a log drawn with the mouse held and that no player poses as an admin
#                            - Checked the name menu's leaving choices, its battle choices and its hint
#                            - Checked the closed log's whispers, separators, numbered names and the say chat's map
#                            - Checked that a line of a player whose name another shares shows their numbered name
#                            - Checked Numpad 0 after a menu, global lines too fast and lines broken after the name
#      Paulinchen  2026-10-07: Checked the lines mirrored to the relay and an admin's line from it
#                            - Checked scrolling the chat log
#                            - Checked that the numpad's 0 closes the chat box
#                            - Checked the stand-in for a sprite this game lacks
#                            - Checked the player's seat kept from the inbox and the status until the world closes
#                            - Checked that the status line breaks a long notice into rows
#      Paulinchen  2026-10-06: Checked that a joiner counts once admitted and a player on a new seat is moved
#                            - Checked that the chat box opens while a message shows
#                            - Checked that Discord hears of the world code
#                            - Checked that the wheel keeps its pick once the arrows are let go
#                            - Found the wheel's choices by their place on the ring and checked its layout
#                            - Steered the action wheel with the arrows held
#      Paulinchen  2026-10-05: Checked that an open chat box takes typing and closes while a message shows
#      Paulinchen  2026-10-04: Checked that a label goes above the labels already on its tile
#                            - Checked the party chat and the colors of the senders' names in the chat log
#                            - Checked that the chat box opens while the player waits for the party's story
#                            - Checked that the chat hotkey does not type its own character into the box it opened
#                            - Read the cursor's blink frames from MGQ_MpUi::TextEdit
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked that a member's party choice on the wheel teleports to the leader
#                            - Checked the word wrap in MGQ_MpUi
#                            - Followed the choices to the scripts that offer them
#                            - Checked that a party counts only whom its leader admitted and keeps a dropped player
#                            - Read the hotkeys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#                            - Checked that a named invite stands longer and a decline ends it
#      Paulinchen  2026-10-02: Checked what Discord hears of the open world
#                            - Checked that the state marker tells states apart from the scripts' messages
#                            - Checked that a full party turns away one player too many and cannot be joined
#      Paulinchen  2026-10-01: Checked the chat in battles and the game's own lines in the chat log
#                            - Checked the globe in the wheel's middle
#                            - Checked the followers behind a party member's ghost
#                            - Took the open world's stand-ins from world_support.rb
#                            - Checked the wheel's middle, invites naming a player, and the size and leader of a party
#                            - Checked that only the party's leader invites and removes members
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers the open world as overworld_sync.rbx, ui_actions.rbx, overworld.rbx, coop.rbx and
# coop_squad.rbx play it together over the DLL's world room: the player's frame handed to it, the
# other players it tells of, their ghosts and their followers, the action wheel and the party's view,
# pings and routes. The room's own rules and the chat's are MGQOnline.Game.Tests'.

# Stands in for the game's save loading and new game, which overworld_sync.rbx hooks as it loads.
module DataManager; def self.load_game_without_rescue(index); true; end; def self.setup_new_game; end; end

require_relative "hud_support"
require_relative "party_support"
answer_party($world_bridge)

# Stands in for the game's sprites, of which this game lacks "$missing".
module Cache
  def self.character(name)
    raise Errno::ENOENT, "Graphics/Characters/#{name}" if name == "$missing"
  end
end
# Stands in for RGSS's load_data, with Luka's sprite in the actors.
#
# @param path [String] The data file.
# @return [Object] Its data.
def load_data(path)
  path == "Data/Actors.rvdata2" ? [nil, Struct.new(:character_name, :character_index).new("Luka", 0)] : Object.new
end
# The script read Luka's sprite as it loaded, before the data file above stood in.
MGQ_MpOverworld.read_stand_in

# The DLL is handed the routes once, and the player's frame as text, only once it changed.
world_frame
routes = $staged_world.select { |topic, _| topic == "world.routes" }
frames = $staged_world.select { |topic, _| topic == "world.me" }
check("the routes go to the DLL once, the chat's left to C#", [routes.size, routes[0][1].map { |field, _gate| field } & %w[chat whisper pchat]], [1, []])
check("the player's frame goes to the DLL, the state as text", [frames.size, frames[0][1]["in_world"], frames[0][1]["state"].values_at("map", "x", "y")], [1, true, %w[5 3 4]])
check("without the fields the DLL adds", frames[0][1]["state"].keys & %w[id name since ping party], [])
$staged_world.clear
world_frame
check("quiet while nothing changes", $staged_world, [])
$game_player.x = 4
world_frame
world_frame
check("a step is handed over once", $staged_world.map { |_, frame| frame["state"]["x"] }, ["4"])
$staged_world.clear

# The DLL's events of a player make a peer and a ghost on the same map; the notices are the DLL's.
friend = { "id" => "friend", "name" => "Friend", "sprite" => "Actor2", "index" => 3, "map" => 5, "x" => 10, "y" => 10, "d" => 4, "speed" => 4, "hidden" => 0, "scene" => "map" }
peers = MGQ_MpOverworldSync::Peers
$world_bridge.post("world.peer", { "seat" => 2, "state" => plain_state(friend), "member" => false })
$world_bridge.post("world.labels", { 2 => "Friend" })
$world_bridge.post("world.notice", "Friend joined the world.")
world_frame
check("the DLL's peer, its name and its notice reach the mirror", [!peers.at(2).nil?, peers.label_of(peers.at(2)), MGQ_MpOverworldSync::Status.lines], [true, "Friend", ["Friend joined the world."]])
MGQ_MpOverworld.update_ghosts
peer = MGQ_MpOverworld.ghosts.first
ghost, state = peer.ghost, peer.state
check("ghost where the friend stands", [ghost.x, ghost.y, ghost.character_name, ghost.character_index], [10, 10, "Actor2", 3])
check("ghost faces as the friend", ghost.direction, 4)
$inbox << entry("message", 2, told(friend.merge("sprite" => "$missing", "index" => 2)))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
check("a sprite this game lacks shows Luka's of the game's data instead", [ghost.character_name, ghost.character_index], ["Luka", 0])
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
check("and the friend's own again once they show one this game has", [ghost.character_name, ghost.character_index], ["Actor2", 3])
check("and a ghost is never only an outline", ghost.respond_to?(:outline), false)

# A name two players share is numbered above the second one's head as the DLL numbers it, and the
# tag is drawn anew once the other left.
$inbox << entry("message", 9, told(friend.merge("id" => "aa-other")))
MGQ_MpOverworldSync::Peers.take_labels(9 => "Friend", 2 => "Friend (2)")
MGQ_MpOverworldSync.tick
other = MGQ_MpOverworldSync::Peers.at(9)
ghost_sprite = Struct.new(:x, :y, :height, :visible, :opacity).new(0, 0, 32, true, 255)
tag = MGQ_MpOverworld::GhostLabel.new(ghost_sprite, peer)
tag.update(peer)
check("a ghost's label is a box following its ghost's sprite, above its head", [tag.root.open?, tag.root.follow.equal?(ghost_sprite), tag.root.side], [true, true, :above])
check("a name two players share shows as the DLL numbers it", [MGQ_MpOverworld.name_tag(other), texts_of(tag.root).first], ["Friend", "Friend (2)"])
MGQ_MpOverworldSync::Peers.remove(9)
MGQ_MpOverworldSync::Peers.take_labels(2 => "Friend")
tag.update(peer)
check("and the label is built anew with the plain name once the other left", texts_of(tag.root).first, "Friend")

# The name is in its player's color, and a player typing shows the keyboard, apart from the
# event's bubble.
icons_of = lambda { parts_of_kind(tag.root, Mod_Framework::UI::Icon).map(&:icon) }
$inbox << entry("message", 2, told(friend.merge("scene" => "typing")))
MGQ_MpOverworldSync.tick
tag.update(peer)
check("a player typing shows the keyboard, which is no bubble of an event, the one the party box takes from the row",
      [icons_of.call, MGQ_MpOverworld::TYPING_ICON == MGQ_MpOverworld::STATE_ICONS["event"], MGQ_MpOverworld::STATE_ICONS["typing"]],
      [[MGQ_MpOverworld::TYPING_ICON], false, MGQ_MpOverworld::TYPING_ICON])
check("a player outside the party is named in plain text", part_with_text(tag.root, "Friend").color, :text)
$inbox << entry("message", 2, told(friend.merge("scene" => "event")))
MGQ_MpOverworldSync.tick
tag.update(peer)
check("an event shows its own bubble", icons_of.call, [MGQ_MpOverworld::STATE_ICONS["event"]])
peer.state["hidden"] = 1
check("the label hides while its player's state says the ghost is hidden", tag.root.send(:hidden_now?), true)
peer.state.delete("hidden")
tag.close
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick

# The graphics checked stay few however many names the others send, the longest unused forgotten.
100.times { |n| MGQ_MpOverworld.graphic?(:character, "$missing") if n % 10 == 0; MGQ_MpOverworld.graphic?(:character, "Other#{n}") }
graphics = MGQ_MpOverworld.instance_variable_get(:@graphics)
check("at most MOST_GRAPHICS_KEPT graphics are kept, one in use stays", [graphics.size, graphics.key?("character/$missing"), graphics.key?("character/Other0")],
      [MGQ_MpOverworld::MOST_GRAPHICS_KEPT, true, false])

# The outline marks the visible pixels of a frame that border a transparent one or the frame's edge.

# A pixel, of which the outline reads only the alpha.
Pixel = Struct.new(:alpha)
sheet = Object.new
sheet.define_singleton_method(:get_pixel) { |x, y| Pixel.new((1..4).include?(x) && (1..3).include?(y) ? 255 : 0) }
marked = []
outline = Object.new
green = MGQ_MpOverworld::OUTLINE_COLORS[:member]
outline.define_singleton_method(:set_pixel) { |x, y, color| marked << [x, y] if color.equal?(green) }
MGQ_MpOverworld.outline_frame(sheet, outline, Rect.new(0, 0, 6, 5), green)
check("the outline marks only the edge of what is visible", marked.sort, [[1, 1], [1, 2], [1, 3], [2, 1], [2, 3], [3, 1], [3, 3], [4, 1], [4, 2], [4, 3]])
marked.clear
MGQ_MpOverworld.outline_frame(sheet, outline, Rect.new(2, 1, 2, 3), green)
check("and the frame's edge counts as transparent", marked.size, 6)

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

# Opens the action wheel, holds the arrows and presses the buttons given for a frame, and lets the
# world tick.
#
# @param buttons [Array<Symbol>] The buttons, such as :DOWN and :C.
def wheel(*buttons)
  open_action_wheel
  directions = buttons & Mod_Framework::UI::Wheel::DIRECTIONS
  $held = directions.map { |direction| arrows(direction) }.flatten
  $buttons.concat(buttons - directions)
  map_frame
  $held = []
  # The choice confirm picked is taken in the frame after.
  map_frame
  MGQ_MpOverworldSync.tick
end
# Opens the action wheel with its hotkey: the hotkey opens it after one frame's tick, and C# in
# the next.
def open_action_wheel
  $pressed = true
  map_frame
  map_frame
end
# Tells where the action wheel's pick sits.
#
# @return [Symbol, nil] :CENTER, a direction, or nil for none.
def picked
  pick = MGQ_MpActions.wheel.selected
  pick == :center ? :CENTER : pick && MGQ_MpActions.wheel_places[MGQ_MpActions.wheel_choices.index(pick)]
end
# Reads a choice of the action wheel.
#
# @param direction [Symbol] Where the choice sits, such as :UP.
# @return [Array] Its text and whether it can be taken.
def option(direction); o = MGQ_MpActions.wheel_options[direction]; [o.text, !o.run.nil?]; end
# Finds the arrows held to point at a direction.
#
# @param direction [Symbol] One of Mod_Framework::UI::Wheel::DIRECTIONS.
# @return [Array<Symbol>] The arrows.
def arrows(direction)
  { :UP => [:UP], :UP_RIGHT => [:UP, :RIGHT], :RIGHT => [:RIGHT], :DOWN_RIGHT => [:DOWN, :RIGHT], :DOWN => [:DOWN],
    :DOWN_LEFT => [:DOWN, :LEFT], :LEFT => [:LEFT], :UP_LEFT => [:UP, :LEFT] }[direction]
end
# The ring's choices here, in their order: the party's invite, leaving the party, the teleport to
# the story and the chat.
PARTY, LEAVE, STORY, CHAT = MGQ_MpActions.wheel_places
# The middle, which the World overview fills in the game.
MGQ_MpActions.wheel_center { MGQ_MpActions::Option.new("World (F11)", lambda { $world_ran = MGQ_MpActions.wheel.open? }, nil, 3988) }
$game_player.x, $game_player.y = 20, 20
$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 40, "y" => 40)))
MGQ_MpOverworldSync.tick
check("four choices spread over the ring", [PARTY, LEAVE, STORY, CHAT], [:UP, :RIGHT, :DOWN, :LEFT])
check("nobody near: invite greyed", option(PARTY), ["Invite to a party", false])
check("a Classic world has no story to teleport to", option(STORY), ["Teleport to the story", false])
check("chat offered, and a direction without a choice has none", [option(CHAT), MGQ_MpActions.wheel_options.key?(:DOWN_RIGHT)], [["Chat (T)", true], false])
check("the wheel's choices are the registered ones in their order, those that cannot be taken dim",
      MGQ_MpActions.wheel_choices.map { |choice| [choice[:text], choice[:enabled]] }, [PARTY, LEAVE, STORY, CHAT].map { |direction| option(direction) })
open_action_wheel
check("B opens the wheel and holds the buttons", [MGQ_MpActions.wheel.open?, Mod_Framework::UI::Capture.on?], [true, true])
check("the wheel opens on its middle", picked, :CENTER)
$buttons << :C
map_frame
taken_frame = [MGQ_MpActions.wheel.open?, $world_ran]
map_frame
check("confirm on the middle closes the wheel and runs its choice in the frame after, the wheel closed", [taken_frame, $world_ran], [[false, nil], false])
open_action_wheel
$held = [:UP]
$buttons << :C
map_frame
check("a greyed choice buzzes, keeps the wheel open and says why in the status line",
      [MGQ_MpActions.wheel.open?, MGQ_MpOverworldSync::Status.lines.last, $sounds.last], [true, "Nobody is near enough to invite.", "buzzer"])
$held = arrows(CHAT)
map_frame
check("the arrows held pick the choice they point at", picked, CHAT)
$held = []
$pressed = true
map_frame
check("B closes the wheel and gives the buttons back", [MGQ_MpActions.wheel.open?, Mod_Framework::UI::Capture.on?], [false, false])
open_action_wheel
$buttons << :B
map_frame
check("cancel closes too", MGQ_MpActions.wheel.open?, false)
MGQ_MpOverworld.update_ghosts
ghost = MGQ_MpOverworld.ghosts.first.ghost
check("a stranger is see-through", ghost.opacity, MGQ_MpOverworld::STRANGER_OPACITY)
MGQ_MpWorld.define_singleton_method(:raid?) { $raid_world }
$raid_world = true
MGQ_MpOverworld.update_ghosts
check("but solid in a Raid World, where everyone on the map shares it", ghost.opacity, MGQ_MpOverworld::SOLID_OPACITY)
$raid_world = false
MGQ_MpOverworld.update_ghosts
check("and see-through again in a Classic world", ghost.opacity, MGQ_MpOverworld::STRANGER_OPACITY)

$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 21, "y" => 22)))
MGQ_MpOverworldSync.tick
check("someone near: invite first", option(PARTY), ["Invite to a party", true])
my_party = "mep1"
invite_ends = MGQ_Multiplayer::Bridge.frame_number + MGQ_MpCoop::INVITE_FRAMES
$party_answer = party_view(my_party, [], -1, "inviting" => true, "invite_ends" => invite_ends)
wheel(:UP, :C)
$party_answer = nil
check("inviting asks the DLL and takes the view it answers", [$party_calls.last, MGQ_MpCoop::Party.inviting?, MGQ_MpActions.wheel.open?], [["invite", nil], true, false])
check("the invite tells the frames it stands for still, by the frame the DLL says it ends at", MGQ_MpCoop::Party.invite_frames_left,
      invite_ends - MGQ_Multiplayer::Bridge.frame_number)
check("line above the own head, with the invite's seconds left", MGQ_MpActions.own_line, "Inviting to a party (15 s) . . .")

# The doings join with their seconds left; a lapse that is no Time counts as none, and a doing
# that fails is left out, logged once. The log says the line without the seconds, once.
doings = MGQ_MpActions.instance_variable_get(:@doings)
kept = doings.dup
MGQ_MpActions.own_doing_from { ["Asking Player A to teleport", Time.now + 3600] }
MGQ_MpActions.own_doing_from { "Offering a trade" }
MGQ_MpActions.own_doing_from { ["Broken", 600] }
MGQ_MpActions.own_doing_from { raise "boom" }
logged = []
writer = MGQ_Multiplayer::Log.method(:write)
MGQ_Multiplayer::Log.define_singleton_method(:write) { |message| logged << message }
line = MGQ_MpActions.own_line
again = MGQ_MpActions.own_line
MGQ_Multiplayer::Log.define_singleton_method(:write, writer)
check("the doings join with their seconds left, a lapse that is no Time counting as none, a failing one left out",
      [line, again], ["Inviting to a party (15 s), Asking Player A to teleport (3600 s), Offering a trade, Broken . . ."] * 2)
check("the failing doing is logged once, and the line once without the seconds", logged,
      ["actions: a line or doing failed: RuntimeError: boom", "actions: the line above the player's head says: Inviting to a party, Asking Player A to teleport, Offering a trade, Broken . . ."])
doings.replace(kept)
moment = Time.at(1_000_000)
check("the seconds left are written after the doing, rounded up, and left out once lapsed",
      [MGQ_MpActions.doing_text(["x", moment + 45], moment), MGQ_MpActions.doing_text(["x", moment + 0.5], moment)[1], MGQ_MpActions.doing_text(["x", moment], moment)[1], MGQ_MpActions.doing_text(["x", moment - 1], moment)[1]],
      [["x", "x (45 s)"], "x (1 s)", "x", "x"])
check("a doing without a time, with nil or with a frame count by mistake stays the text", [MGQ_MpActions.doing_text("x"), MGQ_MpActions.doing_text(["x", nil]), MGQ_MpActions.doing_text(["x", 600])], [["x", "x"]] * 3)
check("a lapse in frames lies as many seconds ahead", (MGQ_MpActions.lapse_in(600) - Time.now - 10).abs < 1, true)

# The line above the player's own head: half the screen wide, cut to that, in the style's own
# color, fading in and out with its picture kept.

# A sprite with the place, picture and visibility the scripts set.
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :opacity, :visible
  def disposed?; false; end
  def dispose; end
end
# Stands in for RGSS bitmaps, which measure each character at 9 pixels and note the texts drawn.
class Bitmap
  # A bitmap's font.
  Font = Struct.new(:size, :color, :bold, :outline, :out_color)
  attr_reader :texts, :width, :height, :font
  def initialize(width = 1, height = 1); @width, @height = width, height; @texts = []; @font = Font.new; end
  def clear; @texts.clear; end
  def fill_rect(*); end
  def text_size(text); Rect.new(0, 0, text.to_s.size * 9, 18); end
  def draw_text(x, y, w, _h, text, align = 0); @texts << [x, y, w, text, font.size, font.color, align]; end
  def stretch_blt(*); end
  def dispose; end
end
own_lines = MGQ_MpActions.method(:own_lines)
MGQ_MpActions.define_singleton_method(:own_lines) { $own_line && [$own_line, $own_line.gsub(/ \(\d+ s\)/, "")] }
$own_line = "Inviting to a party (15 s) . . ."
own = MGQ_MpOverworld::OwnLine.new
own.update
own_label = own.root.children.first
check("the own line is a box half the screen wide following the player, whose sprite the map rebuilds on a transfer, in the own color, fading",
      [own.root.follow, own.root.width, own_label.color, own.root.fade, own_label.text], [:player, 320, :own, true, "Inviting to a party (15 s) . . ."])
$own_line = "Asking Player A to teleport (45 s), Offering a trade (30 s) . . ."
own.update
check("two doings whose seconds overflow the line show without the seconds, which the line cuts, so no countdown that fits is lost",
      own_label.text, "Asking Player A to teleport, Offering a trade . . .")
$own_line = "Asking A (45 s), Trade (30 s) . . ."
own.update
check("while a line that fits keeps every countdown", own_label.text, "Asking A (45 s), Trade (30 s) . . .")
$own_line = nil
own.update
check("gone, the line hides with its text kept while it fades out", [own.root.send(:hidden_now?), own_label.text], [true, "Asking A (45 s), Trade (30 s) . . ."])
own.close
MGQ_MpActions.define_singleton_method(:own_lines, own_lines)

check("an invite can be stopped", option(LEAVE), ["Stop inviting", true])

$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 21, "y" => 22, "party" => my_party)))
take_party(my_party, [MGQ_MpOverworldSync::Peers.at(2)], 2)
MGQ_MpOverworldSync.tick
check("once the DLL counts the friend in, the invite has no frames left", [MGQ_MpCoop::Party.inviting?, MGQ_MpCoop::Party.invite_frames_left], [false, 0])
check("members", MGQ_MpCoop::Party.members.map { |peer| peer.state["name"] }, ["Friend"])
MGQ_MpOverworld.update_ghosts
check("a member is solid", ghost.opacity, 255)
check("the label knows the member", MGQ_MpOverworld.ghosts.first.member, true)
member_tag = MGQ_MpOverworld::GhostLabel.new(ghost_sprite, peer)
member_tag.update(peer)
check("and names them in the members' color, with the party's size after the name in it too",
      [part_with_text(member_tag.root, "Friend").color, part_with_text(member_tag.root, "2 / 4").color], [:ally, :ally])
member_tag.close
# The view makes Friend the party's leader, whom the player stands near already.
check("a member is not invited again, the wheel offers the teleport to the leader instead", option(PARTY), ["Teleport to Friend", false])

# A member's ghost has the followers they show, which step where the one before stood.
check("followers are told only once shown", MGQ_MpOverworldSync::Me.current.values_at("trail", "follow"), ["", 0])
[21, 22, 23, 24].each do |x|
  $inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => x, "y" => 22, "party" => my_party, "trail" => "Actor5*1|Actor6*2")))
  MGQ_MpOverworldSync.tick
  MGQ_MpOverworld.update_ghosts
end
check("a member's ghost has their followers", ghost.followers.map { |f| [f.character_name, f.character_index] }, [["Actor5", 1], ["Actor6", 2]])
$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 24, "y" => 22, "party" => my_party, "trail" => "Actor5*1|$missing*2")))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
check("a follower whose sprite this game lacks shows only the outline of Luka's",
      ghost.followers.map { |f| [f.character_name, f.character_index, f.outline] }, [["Actor5", 1, nil], ["Luka", 0, :member]])
outlined = ghost.followers.last
outlined.look_like("$missing", 2, Struct.new(:member, :move_speed, :opacity, :transparent).new(false, 4, 255, false))
check("in white once its player is no longer in the party", outlined.outline, :stranger)
check("each a step behind the one before", [ghost.x, ghost.followers.map(&:x)], [24, [23, 22]])
$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 24, "y" => 40, "party" => my_party, "trail" => "Actor5*1")))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts
check("a jump gathers the followers, as many as told", ghost.followers.map { |f| [f.x, f.y] }, [[24, 40]])

$party_answer = party_view(nil)
wheel(LEAVE, :C)
$party_answer = nil
MGQ_MpOverworld.update_ghosts
check("a stranger's ghost has no followers", ghost.followers, [])
check("leaving asks the DLL", [$party_calls.last, MGQ_MpCoop::Party.id], [["leave", nil], nil])
check("no party to leave", option(LEAVE), ["Leave the party", false])

$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 20, "y" => 21, "party" => "theirs", "invite" => 1)))
MGQ_MpOverworldSync.tick
check("an inviter shows the invite line", MGQ_MpOverworldSync.label_line_of(MGQ_MpOverworldSync::Peers.at(2)).to_a[0], "Invites to a party (B)")
check("an invite nearby is offered", option(PARTY), ["Accept Friend's invite", true])
$party_answer = party_view("theirs", [MGQ_MpOverworldSync::Peers.at(2)], 2)
wheel(:UP, :C)
$party_answer = nil
check("accepting an invite asks the DLL to join the inviter and takes their party", [$party_calls.last, MGQ_MpCoop::Party.id], [["join", 2], "theirs"])
$inbox << entry("message", 2, told(friend.merge("map" => 5, "x" => 20, "y" => 21, "party" => "", "invite" => 0)))
take_party("theirs")
MGQ_MpOverworldSync.tick

open_action_wheel
SceneManager.scene = Scene_Battle.new
map_frame
check("leaving the map closes the wheel", [MGQ_MpActions.wheel.open?, Mod_Framework::UI::Capture.on?], [false, false])
SceneManager.scene = Scene_Map.new
$open = false
MGQ_MpOverworldSync.tick
check("closing the world forgets the players", MGQ_MpOverworldSync::Peers.empty?, true)
take_party(nil)
$open = true
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick

$pushes = []
MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::STORY_FIELD) { |peer, message| $pushes << [peer, message[MGQ_MpOverworldSync::STORY_FIELD], message[:relay]] }
$world_bridge.post("world.route", { "field" => MGQ_MpOverworldSync::STORY_FIELD, "seat" => nil, "fields" => { MGQ_MpOverworldSync::STORY_FIELD => "7" }, "body" => "", "relay" => true })
world_frame
check("the relay's push the DLL routes goes to its route without a sender, marked as the relay's", $pushes, [[nil, "7", true]])
MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::MODS_RULE_FIELD) { |peer, message| $pushes << [peer, message[MGQ_MpOverworldSync::MODS_RULE_FIELD], message["mods"], message[:relay]] }
message_from(nil, { MGQ_MpOverworldSync::MODS_RULE_FIELD => "1", "mods" => "!Level Cap; Party Sheet" }, "", true)
check("with every field the push carries", $pushes.last, [nil, "1", "!Level Cap; Party Sheet", true])

# A bitmap that measures each character at 10 pixels.
class FakeBitmap; def text_size(text); Struct.new(:width).new(text.size * 10); end; end
check("wrapping at spaces", Mod_Framework::UI.wrap(FakeBitmap.new, "aaa bbb ccc", 70), ["aaa bbb", "ccc"])
check("wrapping a long word", Mod_Framework::UI.wrap(FakeBitmap.new, "abcdefghij", 40), ["abcd", "efgh", "ij"])

# Pings and the connection, as the DLL tells them.
ping = MGQ_MpOverworldSync::Ping

# Plays the DLL telling how the connection stands.
#
# @param ping [Integer, nil] The milliseconds, nil for no connection.
# @param problem [String, nil] What the line says of the connection, nil while it stands.
def status_of(ping, problem = nil)
  $world_bridge.post("world.status", { "seat" => 0, "problem" => problem, "ping" => ping, "map" => 5, "since" => 1_000 })
  world_frame
end
check("no ping before the first pong", [ping.measured, MGQ_MpOverworld.ping_label(ping.measured)], [nil, nil])
status_of(40, "Reconnecting . . .")
check("the ping the DLL tells is taken, and its problem shows first", [ping.measured, MGQ_MpOverworldSync::Status.lines.first], [40, "Reconnecting . . ."])
status_of(40)
check("and goes once the connection stands", MGQ_MpOverworldSync::Status.lines.include?("Reconnecting . . ."), false)
check("colors by quality", [MGQ_MpOverworld.ping_label(50)[0], MGQ_MpOverworld.ping_label(50)[1].equal?(MGQ_MpOverworld::PING_COLORS[0][1]),
                            MGQ_MpOverworld.ping_label(150)[1].equal?(MGQ_MpOverworld::PING_COLORS[1][1]), MGQ_MpOverworld.ping_label(999)[1].equal?(MGQ_MpOverworld::PING_COLORS[2][1])],
      ["50 ms", true, true, true])
check("a ping past 999 ms shows as 999+ ms, red", [MGQ_MpOverworld.ping_label(1234)[0], MGQ_MpOverworld.ping_label(1234)[1].equal?(Mod_Framework::UI::Style::BAD), MGQ_MpOverworld.ping_label(999)[0]], ["999+ ms", true, "999 ms"])
status_of(nil)
check("no connection, no ping shown", [ping.measured, MGQ_MpOverworld.ping_label(ping.measured)], [nil, nil])

# Scripts' messages that name a map are not states.

# Stands in for the shared story's events, noting each message taken in $taken_events.
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

# Stands in for the battle sync, noting each message taken in $taken_battle.
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
check("a player whose connection dropped is kept, unseen", MGQ_MpOverworldSync::Peers.at(2).away.nil?, false)
MGQ_MpOverworld.update_ghosts
check("without their ghost", MGQ_MpOverworldSync::Peers.at(2).ghost, nil)
kept = MGQ_MpOverworldSync::Peers.at(2)
$world_bridge.post("world.peer_moved", { "seat" => 6, "from" => 2 })
$world_bridge.post("world.peer", { "seat" => 6, "state" => plain_state(friend), "member" => false })
world_frame
check("a player the DLL moves to another seat is the same player there, back",
      [MGQ_MpOverworldSync::Peers.at(2), MGQ_MpOverworldSync::Peers.at(6).equal?(kept), MGQ_MpOverworldSync::Peers.at(6).away, MGQ_MpOverworldSync::Peers.all.size], [nil, true, nil, 1])
left = []
MGQ_MpOverworldSync.on_leave { |peer| left << peer.seat }
$world_bridge.post("world.peer_left", { "seat" => 6 })
world_frame
check("a player the DLL forgets leaves the mirror, and the scripts hear of it", [MGQ_MpOverworldSync::Peers.empty?, left], [true, [6]])
$inbox << entry("message", 3, told(friend.merge("seat" => 3)))
MGQ_MpOverworldSync.tick
$open = false
MGQ_MpOverworldSync.tick
check("closing the world forgets everyone", MGQ_MpOverworldSync::Peers.empty?, true)

# Notices run out.
$open = true
(MGQ_MpOverworldSync::NOTICE_FRAMES + 1).times { MGQ_MpOverworldSync.tick }
check("notices ran out", MGQ_MpOverworldSync::Status.lines, [])

# The party's routes, which the DLL's gate passes.
$gate = []
MGQ_MpCoop.route("gtest") { |peer, message| $gate << [peer.seat, message["gtest"]] }
$open = true
$inbox << entry("message", 4, told(friend.merge("x" => 50, "y" => 50)))
MGQ_MpOverworldSync.tick
mine = "me-p1"
MGQ_MpOverworldSync::Peers.at(4).state["party"] = mine
take_party(mine, [MGQ_MpOverworldSync::Peers.at(4)])
check("a party route is registered with the party's gate", MGQ_MpOverworldSync.instance_variable_get(:@gates)["gtest"], "party")
$inbox << entry("message", 4, "gtest=mine\nparty=#{mine}\n\n")
MGQ_MpOverworldSync.tick
check("a message the gate passed reaches its script", $gate, [[4, "mine"]])
$sent.clear
MGQ_MpCoop.tell(4, "gtest", "hello", "extra" => 1)
check("tell adds the party id", [$sent.last[0], $sent.last[1].include?("gtest=hello
party=#{mine}
extra=1")], [4, true])

# Two players of the same name, found apart by the name the DLL numbers, and nobody by none.
peers = MGQ_MpOverworldSync::Peers
$inbox << entry("message", 8, told(friend.merge("id" => "zz-twin")))
peers.take_labels(4 => "Friend", 8 => "Friend (2)")
MGQ_MpOverworldSync.tick
check("a name the DLL numbers finds each player apart",
      [peers.named("Friend").seat, peers.named("Friend (2)").seat, peers.label_of(peers.at(8))], [4, 8, "Friend (2)"])
check("nobody is found by a missing id or name", [peers.with_id(nil), peers.with_id(""), peers.named(nil)], [nil, nil, nil])
peers.remove(8)

# The wheel's middle, which it opens on, and the pick it keeps once the arrows are let go.
open_action_wheel
$held = [:UP]
map_frame
check("an arrow held picks its side", picked, :UP)
$held = []
map_frame
check("letting go keeps the choice", picked, :UP)
$held = [:UP, :RIGHT]
map_frame
check("a diagonal, which the wheel has no choice for, picks the middle too", picked, :CENTER)
$held = []
MGQ_MpActions.wheel.close

# How the ring spreads and lays out its choices.
mirror = { :UP_RIGHT => :UP_LEFT, :RIGHT => :LEFT, :DOWN_RIGHT => :DOWN_LEFT }
mirror.merge!(mirror.invert)
check("every count of choices comes out mirror-symmetric",
      (1..8).all? { |count| places = Mod_Framework::UI::Wheel.places(count); places.map { |d| mirror[d] || d }.sort == places.sort }, true)
check("four take the sides, five the two lower diagonals for the bottom, six a hexagon",
      [Mod_Framework::UI::Wheel.places(4), Mod_Framework::UI::Wheel.places(5), Mod_Framework::UI::Wheel.places(6)],
      [[:UP, :RIGHT, :DOWN, :LEFT], [:UP, :RIGHT, :DOWN_RIGHT, :DOWN_LEFT, :LEFT], [:UP, :UP_RIGHT, :DOWN_RIGHT, :DOWN, :DOWN_LEFT, :UP_LEFT]])
before = MGQ_MpActions.wheel_places.size
(Mod_Framework::UI::Wheel::DIRECTIONS.size - before + 1).times { |index| MGQ_MpActions.wheel_choice(100 + index) { MGQ_MpActions::NO_OPTION } }
check("a ring holds eight choices at most", MGQ_MpActions.wheel_places.size, Mod_Framework::UI::Wheel::DIRECTIONS.size)
MGQ_MpActions.instance_variable_get(:@choices).reject! { |order, _, _| order >= 100 }

# Invites the DLL finds reaching the player, and the player's own, which the DLL keeps.
far = MGQ_MpOverworldSync::Peers.at(4)
far.state.merge!("party" => "far-p", "invite" => "1", "invite_to" => "other-id,me", "map" => "9")
take_party(nil, [], -1, "inviters" => [4], "parties" => { "far-p" => [1, 4] })
check("an invite the DLL finds reaching the player is offered in the overview", [MGQ_MpCoop::Party.invited_by?(far), MGQ_MpCoop::Offers.peer_option(far).text], [true, "Accept party invite"])
take_party(nil, [], -1, "inviters" => [4], "parties" => { "far-p" => [4, 4] })
check("but closed while their party is full", [MGQ_MpCoop::Offers.peer_option(far).run, MGQ_MpCoop::Offers.notice_of(far)], [nil, nil])
MGQ_MpCoop::Party.decline(far)
MGQ_MpCoop::Party.invite("friend")
MGQ_MpCoop::Party.stop_inviting
check("declining and the player's own invites ask the DLL", $party_calls.last(3), [["decline", 4], ["invite", "friend"], ["stop_inviting", nil]])

# The size and leader of a party, as the view tells them.
far.state.merge!("party" => "me-p2", "invite" => "0")
take_party("me-p2", [far])
badges = [MGQ_MpOverworld.party_badge(:me), MGQ_MpOverworld.party_badge(far)]
check("a party of two shows its size on both, and one of them leads", [badges.map { |b| b[0] }, badges.count { |b| b[1] }], [["2 / 4", "2 / 4"], 1])
check("the leader is the one the view names", [MGQ_MpCoop.leads?(:me), MGQ_MpCoop.leads?(far)], [true, false])
far.state["party"] = "theirs"
take_party("me-p2")
check("a player alone shows no size", [MGQ_MpOverworld.party_badge(:me), MGQ_MpOverworld.party_badge(far)], [nil, nil])

# Only the party's leader invites and removes members.
far.state["party"] = "me-p2"
take_party("me-p2", [far])
check("the leader may invite more", MGQ_MpCoop::Party.may_invite?, true)
MGQ_MpCoop::Party.remove(far)
check("and removes a member through the DLL", $party_calls.last, ["remove", 4])
take_party("me-p2", [far], 4)
MGQ_MpOverworldSync.tick
check("a member may not invite, and teleports to the leader with the wheel's party choice instead",
      [MGQ_MpCoop::Party.may_invite?, MGQ_MpCoop::Offers.invite_refusal("full"), MGQ_MpActions.wheel_options[PARTY].text.start_with?("Teleport to ")],
      [false, "Only the party's leader invites.", true])
take_party(nil)

# The relay dealing the seats anew, as the DLL's events tell it: a player who takes the seat of one
# away leaves them kept aside, the same player once they tell from another seat, and gone only once
# the DLL forgets them; each change of their presence reaches the scripts.
MGQ_MpOverworldSync::Peers.clear
$left = []
$presence = []
MGQ_MpOverworldSync.on_leave { |peer| $left << peer.seat }
MGQ_MpOverworldSync.on_presence { |peer, change| $presence << change if peer.state["id"] == "friend" }
other = friend.merge("id" => "zz-other", "name" => "Other")
$world_bridge.post("world.peer", { "seat" => 2, "state" => plain_state(friend), "member" => false })
$world_bridge.post("world.peer_away", { "seat" => 2 })
$world_bridge.post("world.peer_displaced", { "seat" => 2 })
$world_bridge.post("world.peer", { "seat" => 2, "state" => plain_state(other), "member" => false })
world_frame
kept = MGQ_MpOverworldSync::Peers.kept_with_id("friend")
check("a player telling from the seat of one away leaves them kept aside, unseen",
      [$left, MGQ_MpOverworldSync::Peers.at(2).state["id"], kept && kept.away, MGQ_MpOverworldSync::Peers.all.map { |peer| peer.state["id"] }, MGQ_MpOverworldSync::Peers.empty?],
      [[], "zz-other", true, ["zz-other"], false])
$world_bridge.post("world.peer_moved", { "seat" => 4, "from" => 2, "id" => "friend" })
$world_bridge.post("world.peer", { "seat" => 4, "state" => plain_state(friend), "member" => false })
world_frame
check("who come back on another seat as the same player, told away, moved and back",
      [MGQ_MpOverworldSync::Peers.at(4).equal?(kept), kept.away, MGQ_MpOverworldSync::Peers.at(2).state["id"], $left, $presence], [true, nil, "zz-other", [], [:away, :moved, :back]])
$world_bridge.post("world.peer_away", { "seat" => 4 })
$world_bridge.post("world.peer_displaced", { "seat" => 4 })
$world_bridge.post("world.peer_moved", { "seat" => 4, "from" => 2, "id" => "zz-other" })
$world_bridge.post("world.peer", { "seat" => 4, "state" => plain_state(other), "member" => false })
$world_bridge.post("world.peer_left", { "seat" => 4, "id" => "friend" })
world_frame
check("and gone once the DLL forgets them, the player now on their old seat kept",
      [$left, $presence.last, MGQ_MpOverworldSync::Peers.kept_with_id("friend"), MGQ_MpOverworldSync::Peers.at(4).state["id"]], [[4], :gone, nil, "zz-other"])

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

# The player's own ping above their head: the crown while they lead, the party's size and the ping.
measured = MGQ_MpOverworldSync::Ping.method(:measured)
MGQ_MpOverworldSync::Ping.define_singleton_method(:measured) { $measured }
$measured = nil
own_ping = MGQ_MpOverworld::OwnPing.new
party_badge = MGQ_MpOverworld.method(:party_badge)
MGQ_MpOverworld.define_singleton_method(:party_badge) { |_player| $badge }
$badge = nil
own_ping.update
check("the own ping is a box following the player, hidden without a party or a ping", [own_ping.root.follow, own_ping.root.send(:hidden_now?)], [:player, true])
$measured = 45
$badge = ["2 / 4", true]
own_ping.update
check("leading a party, it shows the crown, the party's size in the members' color and the ping in its own",
      [parts_of_kind(own_ping.root, Mod_Framework::UI::Icon).map(&:icon), texts_of(own_ping.root), part_with_text(own_ping.root, "2 / 4").color,
       part_with_text(own_ping.root, "45 ms").color.equal?(MGQ_MpOverworld.ping_label(45)[1]), own_ping.root.send(:hidden_now?)],
      [[MGQ_MpOverworld::CROWN_ICON], ["2 / 4", "45 ms"], :ally, true, false])
own_ping.close
MGQ_MpOverworld.define_singleton_method(:party_badge, party_badge)
MGQ_MpOverworldSync::Ping.define_singleton_method(:measured, measured)

# The status line: the notices wrapped, the newest at the bottom, its oldest rows going out at the
# top.
long = "You follow Tester A's story while in the party. You are as far along, so you keep what you play together."
kept_notices = MGQ_MpOverworldSync::Status.instance_variable_get(:@notices).dup
MGQ_MpOverworldSync::Status.instance_variable_set(:@notices, [])
MGQ_MpOverworldSync::Status.notice("Short.", 4)
MGQ_MpOverworldSync::Status.notice(long)
line = MGQ_MpOverworld::WorldStatus.new
line.update
root = line.root
labels = parts_of_kind(root, Mod_Framework::UI::Label)
check("in a world the status line opens at the bottom left as the movable World status, widened only, under the game's windows",
      [root.open?, root.id, root.place_name, root.at, root.size, root.resizable, root.min_size, root.under_windows],
      [true, :world_status, "World status", [8, 480 - 88 - 8], [400, 88], :width, [266, 88], true])
check("each notice a wrapped label with its icon before its first row, the newest at the bottom of a box that keeps its newest rows",
      [labels.map(&:text), labels.map(&:wrap), labels.map(&:icon), root.tail], [["Short.", long], [true, true], [4, false], true])
$open = false
line.update
check("outside a world it closes", root.open?, false)
$open = true
line.update
check("and opens again in one, empty while there is nothing to tell", root.open?, true)
line.close
MGQ_MpOverworldSync::Status.instance_variable_set(:@notices, kept_notices)

# The player's seat and when they entered their map, as the DLL tells them, and the seat forgotten
# once the world closes.
me = MGQ_MpOverworldSync::Me
$world_bridge.post("world.status", { "seat" => 5, "problem" => nil, "ping" => nil, "map" => 5, "since" => 1_234 })
world_frame
check("the seat and the time the player entered their map are the DLL's", [me.seat, me.map_since], [5, 1_234])
$game_map.map_id = 6
$map_since = 5_678
check("on a map the DLL has not seen the player on yet, it is asked at once", me.map_since, 5_678)
$game_map.map_id = 5
$map_since = nil
$open = false
MGQ_MpOverworldSync.tick
check("the world closing forgets the seat", me.seat, -1)
$open = true

# A loaded save or a new game enter their map anew, which the DLL is told.
$staged_world.clear
DataManager.load_game_without_rescue(0)
DataManager.setup_new_game
world_frame
check("a loaded save and a new game have the DLL forget when the player entered their map",
      $staged_world.count { |topic, _| topic == "world.reset_since" }, 2)

# The title screen keeps the previous game's map, which the DLL is not handed.
$staged_world.clear
SceneManager.scene = Scene_Title.new
$game_player.x += 1
world_frame
check("on the title screen the DLL is handed no state", [$staged_world.map { |_, frame| frame["state"] }, me.current], [[nil], nil])
SceneManager.scene = Scene_Base.new
$new_game_pending = true
world_frame
check("nor while a world's new game waits there, as through the world screen's fade-out", me.current, nil)
$new_game_pending = false
SceneManager.scene = Scene_Map.new
world_frame
check("once the map starts the DLL is handed the state", $staged_world.last[1]["state"]["x"], $game_player.x.to_s)
