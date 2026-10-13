#----------------------------------------------------------------
#  world_support.rb
#
#  Changelog:
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

require_relative "support"

# Stands in for the game's sprite, taking any arguments.
class Sprite; def initialize(*); end; end
# Stands in for the game's character sprite.
class Sprite_Character < Sprite; end
# Stands in for the screen: 640 by 480, its frame count read from $frame.
module Graphics; def self.update; end; def self.width; 640; end; def self.height; 480; end; def self.frame_count; $frame.to_i; end; end
# Stands in for the map's spriteset.
class Spriteset_Map; def update; end; def dispose; end; end
# Stands in for the scenes' base.
class Scene_Base; def update; end; def start; end; end
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
# Stands in for the game's message, busy while busy is set.
class Game_Message; attr_accessor :busy; def busy?; @busy; end; end
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
$inbox = []
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
# Stands in for the parts of Multiplayer.rb the scripts call.
module MGQ_Multiplayer
  # Stands in for the game window: in front while $in_front is set, always running.
  module Background; def self.in_front?; $in_front; end; def self.running?; true; end; end
  # Stands in for the keyboard: the key $pressed names is pressed once, and $down lists the keys
  # held.
  module Key
    # Answers whether a key is pressed, once: the code in $pressed, or B when $pressed is true.
    def self.pressed?(code); p = $pressed == code || ($pressed == true && code == 0x42); $pressed = false if p; p; end
    # Answers whether a key is held, as $down lists it.
    def self.down?(code); ($down || []).include?(code); end
    # Answers as pressed? does.
    def self.triggered?(code); pressed?(code); end
  end
  # Stands in for the mouse: held while $mouse_held is true, at $mouse, its wheel's notches in $wheel.
  module Mouse; def self.held?; $mouse_held == true; end; def self.position; $mouse; end; def self.wheel; $wheel.to_i; end; end
  # Stands in for the log, which prints each line.
  module Log; def self.write(m); puts "  log: #{m}"; end; end
  # Stands in for holding the game's buttons, held while any screen holds them; $held lists the
  # buttons held and $buttons those pressed, each read once.
  module Capture
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
  # Stands in for Player.ini: the player named Me, the settings in $player_ini and the notice of an
  # unreadable file in $player_ini_notice.
  module Player
    # Answers the player's name.
    def self.name; "Me"; end
    # Reads a setting from $player_ini.
    def self.setting(key); $player_ini[key]; end
    # Keeps a setting in $player_ini as text.
    def self.store(key, value); $player_ini[key] = value.to_s; true; end
    # Hands out the notice in $player_ini_notice once.
    def self.take_notice; notice = $player_ini_notice; $player_ini_notice = nil; notice; end
  end
  # Stands in for the DLL's link: the player's id is always me, whether the player types goes to
  # $typing_on, and what they typed comes from $typed.
  module Link
    # Answers the player's id.
    def self.player_id; "me"; end
    # Records whether the player types in $typing_on.
    def self.typing(on); $typing_on = on; end
    # Hands out the text in $typed once, counting a key per character.
    def self.take_typed; text = $typed; $typed = ""; [text, text.size]; end
    # Reads a description as the DLL writes it: key=value lines, an empty line, the payload.
    #
    # @param text [String] The description.
    # @return [Hash] The fields, the payload under :payload.
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| k, v = line.split("=", 2); state[k] = v if v }
      state
    end
  end
end
# Stands in for the world: open while $open is set, its new game waiting while $new_game_pending is.
module MGQ_MpWorld; def self.open?; $open; end; def self.new_game_pending?; $new_game_pending; end; end
$player_ini = {}

load_script "core_hotkeys"
load_script "ui"
load_script "ui_theme"
load_script "ui_layout"
load_script "ui_text_box"
load_script "overworld_sync"
load_script "ui_wheel"
load_script "ui_actions"
load_script "ui_chat"
load_script "overworld"
load_script "coop"
load_script "coop_scope"
load_script "coop_squad"
load_script "coop_gather"
load_script "coop_teleport"

# Runs one frame on the map: the wheel's keys, then the chat's.
def map_frame; MGQ_MpActions.on_map; MGQ_MpChat.on_map; end

$said = []
# Stands in for the world room's link: the inbox in $inbox, the messages sent in $sent, the chat
# lines mirrored in $said, and an open connection.
module MGQ_MpOverworldSync::Link
  # Hands out the oldest entry of $inbox.
  def self.next_entry; $inbox.shift; end
  # Records a message in $sent, which always goes out.
  def self.send_to(target, text); $sent << [target, text]; true; end
  # Records a mirrored chat line in $said and answers $say_result, 1 (the relay got it) by default.
  def self.say(text); $said << text; $say_result || 1; end
  # Answers an open connection with the ping in $status_ping.
  def self.status; { "state" => "open", "ping" => $status_ping }; end
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
  { "state" => 1 }.merge(state).map { |k, v| "#{k}=#{v}" }.join("\n") + "\n\n"
end

# A player standing on map 5 of an open world.
$open = true
$game_map = Game_Map.new; $game_map.map_id = 5; $game_map.interpreter = Interpreter.new
$game_message = Game_Message.new
$game_player = Player.new(3, 4, 2, "Actor1", 0, 4, false, nil)
SceneManager.scene = Scene_Map.new
