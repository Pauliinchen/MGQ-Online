#----------------------------------------------------------------
#  world_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Reached the Mod Framework's engine under its own name
#                            - Stood in for UI.in_front? of the Mod Framework
#      Paulinchen  2026-11-05: Kept each message sent as the scripts hand it and took the fields of each message told as the test writes them
#                            - Kept true or false and whole numbers in the stand-in of Player.ini as the DLL hands them back
#                            - Wrote a state as the DLL writes its fields
#                            - Stood in for the world room's sending and the player's id through the DLL's topics
#                            - Dropped the stand-in of the game's frame counter, which no script reads; the bridge's frame counts
#      Paulinchen  2026-11-01: Fired the Mod Framework's hotkeys after each map frame and gave the message and the player what the free map asks
#                            - Stopped loading the deleted ui_boxes.rbx
#                            - Stood in for the DLL's chat model
#                            - Dropped the chat log's lines, which the chat's model holds
#      Paulinchen  2026-10-31: Stood in for the Mod Framework's window, keys, mouse and capture, which the scripts read now
#      Paulinchen  2026-10-23: Counted the frames ui_frame ended
#                            - Typed through the stand-in text box at the end of each frame
#                            - Played the world room's inbox into the scripts' mirror through world_room_support.rb
#                            - Answered the rules' topics through the bridge, such as the ids coop.rbx makes up
#                            - Read the chat log's lines here
#                            - Showed the HUD over the map's spriteset
#      Paulinchen  2026-10-22: Gave the scenes' base its basics and its end
#      Paulinchen  2026-10-12: Stood in for the notice of an unreadable Player.ini
#                            - Told the mouse wheel's notches from $wheel
#                            - Stood in for the title screen and a world's waiting new game
#      Paulinchen  2026-10-11: Loaded ui_theme.rbx and ui_layout.rbx after ui.rbx
#                            - Kept a color's values
#                            - Gave the screen its size and frame count and stood in for the scenes' base
#      Paulinchen  2026-10-10: Loaded coop_gather.rbx and coop_teleport.rbx
#      Paulinchen  2026-10-08: Loaded coop_scope.rbx after coop.rbx
#                            - Told the keys held from $down and the mouse from $mouse
#                            - Answered a mirrored chat line as the DLL does
#                            - Stood in for the game's character sprite
#      Paulinchen  2026-10-07: Stood in for the chat lines mirrored to the relay
#      Paulinchen  2026-10-06: Read the texts of the bottom left line here
#                            - Kept the buttons held while any screen holds them
#                            - Told the buttons held past the capture and loaded ui_wheel.rbx
#      Paulinchen  2026-10-05: Gave the map an update and whether a message stops its own
#      Paulinchen  2026-10-04: Followed the scripts to their new names
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#                            - Loaded core_hotkeys.rbx
#      Paulinchen  2026-10-02: Loaded mp_keys.rbx with Player.ini's settings in $player_ini
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# What the tests of the open world share: stand-ins for the game and the DLL, the scripts every one
# of them builds on, helpers that feed the world room, and a player standing on map 5 of an open
# world.

require_relative "rules_support"

# Stands in for the game's sprite, taking any arguments.
class Sprite; def initialize(*); end; end
# Stands in for the game's character sprite.
class Sprite_Character < Sprite; end
# Stands in for the screen: 640 by 480.
module Graphics; def self.update; end; def self.width; 640; end; def self.height; 480; end; end
# Stands in for the map's spriteset, which shows the HUD.
class Spriteset_Map; def update; end; def dispose; end; def mgq_mp_hud?; true; end; end
# Stands in for the scenes' base.
class Scene_Base; def update; end; def update_basic; end; def start; end; def terminate; end; end
# Stands in for the title screen.
class Scene_Title < Scene_Base; end
# A rectangle, as the game's Rect holds one.
Rect = Struct.new(:x, :y, :width, :height)
# Stands in for the game's map: its id, its interpreter and the name it shows.
class Game_Map
  attr_accessor :map_id, :interpreter, :display_name
  # Stands in for the map's update, which does nothing here.
  def update(main = false); end
end
# Stands in for the game's message, busy while busy is set, never shown.
class Game_Message; attr_accessor :busy, :visible; def busy?; @busy; end; end
# Stands in for the map's interpreter, which never runs.
class Interpreter; def running?; false; end; end
# Stands in for the map scene, which allows a change of scene unless $scene_change_ok is false.
class Scene_Map; def update; end; def update_scene; end; def scene_changing?; false; end; def scene_change_ok?; $scene_change_ok != false; end; end
# Stands in for the game's window base unless a test defined one already.
class Window_Base; def initialize(*); end; end unless defined?(Window_Base)
# Stands in for the battle scene.
class Scene_Battle; def update_basic; end; end
# Stands in for the battle's spriteset.
class Spriteset_Battle; def update; end; def dispose; end; end
# Stands in for the scene manager, which holds the scene a test sets.
module SceneManager; class << self; attr_accessor :scene; end; def self.run; end; end
# Stands in for the game's config tables, all empty.
module NWConst; module Config; CONTENTS = [{}]; DATA = {}; DATA_TEXT = {}; DEFAULT = {}; end; end
# Stands in for the game's character: a tile, a direction and a graphic, moving a tile a step.
class Game_Character
  attr_reader :x, :y, :direction, :character_name, :character_index, :opacity, :move_speed, :transparent
  # Starts at 0, 0 facing down.
  def initialize; @x = 0; @y = 0; @direction = 2; end
  # Answers how far the character stands right of a column.
  def distance_x_from(x); @x - x; end
  # Answers how far the character stands below a row.
  def distance_y_from(y); @y - y; end
  # Places the character on a tile.
  def moveto(x, y); @x, @y = x, y; end
  # Takes a sheet and an index on it as the character's graphic.
  def set_graphic(name, index); @character_name, @character_index = name, index; end
  # Turns the character.
  def set_direction(d); @direction = d; end
  # Stands in for the character's update, which does nothing here.
  def update; end
  # Answers that the character never stands between tiles.
  def moving?; false; end
  # Turns the character and moves it a tile that way.
  #
  # @param d [Integer] The direction: 2 down, 4 left, 6 right, 8 up.
  def move_straight(d)
    @direction = d
    case d when 2 then @y += 1 when 8 then @y -= 1 when 4 then @x -= 1 when 6 then @x += 1 end
  end
end
# Stands in for the game's player: a tile, a direction, a graphic, a speed and a vehicle.
Player = Struct.new(:x, :y, :direction, :character_name, :character_index, :real_move_speed, :transparent, :vehicle, :vehicle_type) do
  # Answers whether the player flies the airship.
  def in_airship?; vehicle_type == :airship; end
  # Answers whether the player sails the boat.
  def in_boat?; vehicle_type == :boat; end
  # Answers whether the player sails the ship.
  def in_ship?; vehicle_type == :ship; end
  # Answers that nobody follows the player.
  def followers; []; end
  # Stands in for the player's refresh, which does nothing here.
  def refresh; end
  # Answers that no transfer waits.
  def transfer?; false; end
  # Answers that no move route moves the player.
  def move_route_forcing; false; end
end
$game_party = Struct.new(:party_member_max, :all_members, :stand_members).new(8, [], [])
# The game's system data: the names of its variables and switches.
System = Struct.new(:variables, :switches)
$data_system = System.new([], [])
$game_variables = []
$game_switches = []
# Stands in for the item menu.
class Scene_Item; end
# Stands in for the equipment menu.
class Scene_EquipStoneActor; end
# Stands in for the Library.
class Scene_Library_H; end
# Stands in for the casino's slots.
class Scene_Slot; end

$sent = []
$in_front = true
$pressed = false
$buttons = []
$typed = ""
$sounds = []
# Stands in for the game's sounds, recording each one played in $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
# A color that keeps its values, which draw_outlined copies the font's color by.
class Color
  attr_accessor :red, :green, :blue, :alpha
  # Keeps the color's values.
  def initialize(red = nil, green = nil, blue = nil, alpha = nil); @red = red; @green = green; @blue = blue; @alpha = alpha; end
end
# Stands in for the game window: in front while $in_front is set.
module Mod_Framework::UI; def self.in_front?; $in_front; end; end
# Stands in for the keyboard: the key $pressed names is pressed once, and $down lists the keys
# held.
module Mod_Framework::UI::Engine::Key
  # Answers whether a key is pressed, once: the code in $pressed, or B when $pressed is true.
  def self.pressed?(code); p = $pressed == code || ($pressed == true && code == 0x42); $pressed = false if p; p; end
  # Answers whether a key is held, as $down lists it.
  def self.down?(code); ($down || []).include?(code); end
  # Answers as pressed? does.
  def self.triggered?(code); pressed?(code); end
  # Counts the frames ui_frame ended.
  def self.frame; $ui_frames.to_i; end
end
# Stands in for the mouse: held while $mouse_held is true, at $mouse, its wheel's notches in $wheel.
module Mod_Framework::UI::Engine::Mouse; def self.held?; $mouse_held == true; end; def self.position; $mouse; end; def self.wheel; $wheel.to_i; end; end
# Stands in for holding the game's buttons, held while any screen holds them; $held lists the
# buttons held and $buttons those pressed, each read once.
module Mod_Framework::UI::Engine::Capture
  @owners = []
  # Holds the buttons for a screen.
  def self.start(owner); @owners.push(owner) unless @owners.include?(owner); end
  # Lets a screen's hold go.
  def self.stop(owner); @owners.delete(owner); end
  # Answers whether any screen holds the buttons.
  def self.on?; !@owners.empty?; end
  # Answers whether a button is held, as $held lists it.
  def self.press?(button); ($held || []).include?(button); end
  # Answers whether a button was pressed, taking it from $buttons.
  def self.trigger?(button); $buttons.delete(button) ? true : false; end
  # Answers whether a button repeats, taking it from $buttons.
  def self.repeat?(button); $buttons.delete(button) ? true : false; end
end
# Stands in for the parts of Multiplayer.rb the scripts call.
module MGQ_Multiplayer
  # Stands in for the log, which prints each line.
  module Log; def self.write(m); puts "  log: #{m}"; end; end
  # Stands in for Player.ini: the player named Me, the settings in $player_ini and the notice of an
  # unreadable file in $player_ini_notice.
  module Player
    # Answers the player's name.
    def self.name; "Me"; end
    # Reads a setting from $player_ini.
    def self.setting(key); $player_ini[key]; end
    # Keeps a setting in $player_ini as the DLL hands it back: true or false and whole numbers as they are, the rest as text.
    def self.store(key, value); $player_ini[key] = value == true || value == false || value.is_a?(Integer) ? value : value.to_s; true; end
    # Hands out the notice in $player_ini_notice once.
    def self.take_notice; notice = $player_ini_notice; $player_ini_notice = nil; notice; end
    # Answers the player's id, which the DLL tells: always me.
    def self.id; "me"; end
  end
end
# Stands in for the world: open while $open is set, its new game waiting while $new_game_pending is.
module MGQ_MpWorld; def self.open?; $open; end; def self.new_game_pending?; $new_game_pending; end; end
$player_ini = {}

require_relative "world_room_support"
require_relative "chat_support"
$inbox = WorldInbox.new

load_script "core_hotkeys"
load_script "ui_online"
load_script "overworld_sync"
load_script "ui_actions"
load_script "ui_chat"
load_script "overworld"
load_script "coop"
load_script "coop_scope"
load_script "coop_squad"
load_script "coop_gather"
load_script "coop_teleport"

# The bridge to the fake models of the interface, the text box typing what $typed holds, the
# component tree and the chat's model.
$world_fake, $fake_ui = open_fake_ui { text = $typed.to_s; $typed = ""; [text, text.size] }
$fake_chat = FakeChat.new($world_fake)

# Runs one frame on the map: the action wheel's choice, then the chat's keys, then the end of the
# frame, as Graphics.update ends it, which types what $typed holds into an open text box, and the
# hotkeys of the next frame, which open and close the wheels.
def map_frame; MGQ_MpActions.on_map; MGQ_MpChat.on_map; ui_frame; Mod_Framework::Hotkeys.fire; end

# Stands in for the world room's sending: the messages sent in $sent, as the scripts hand them.
module MGQ_MpOverworldSync::Port
  # Records a message in $sent, which always goes out.
  def self.send_to(target, fields, body); $sent << [target, sent_message(fields, body)]; true; end
end

# Lets the tests read the line at the bottom left of the map.
module MGQ_MpOverworldSync::Status
  # Tells the texts the line shows, without their icons.
  def self.lines; shown.map(&:first); end
end

# An entry of the world room's inbox, as the DLL hands it out.
#
# @param kind [String] "seat", "in", "out" or "message".
# @param seat [Integer] The seat it is about.
# @param message [Hash] A message's fields as the DLL reads them, its body under :payload.
# @return [Hash] The entry.
def entry(kind, seat, message = {})
  { "kind" => kind, "seat" => seat.to_s, :payload => message }
end

# A state another game told, its fields as the DLL reads them.
#
# @param state [Hash] The state's fields.
# @return [Hash] The message.
def told(state)
  { "state" => "1" }.merge(state)
end

# A player standing on map 5 of an open world.
$open = true
$game_map = Game_Map.new; $game_map.map_id = 5; $game_map.interpreter = Interpreter.new
$game_message = Game_Message.new
$game_player = Player.new(3, 4, 2, "Actor1", 0, 4, false, nil)
SceneManager.scene = Scene_Map.new

# The DLL's side of the bridge, answering the rules' topics, such as the ids coop.rbx makes up.
open_rules_bridge
