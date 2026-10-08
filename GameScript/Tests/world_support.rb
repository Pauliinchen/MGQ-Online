#----------------------------------------------------------------
#  world_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-08: Told the keys held from $down, and the mouse from $mouse
#      Paulinchen  2026-10-07: Stood in for the chat lines mirrored to the relay
#      Paulinchen  2026-10-06: Read the texts of the line at the bottom left here, since overworld_sync.rbx no longer offers them
#                            - Kept the buttons held while any screen holds them, as Multiplayer.rb does
#                            - Told the buttons held past the capture, from $held, and loaded ui_wheel.rbx
#      Paulinchen  2026-10-05: Gave the map an update and whether a message stops its own
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#                            - Loaded core_hotkeys.rbx, renamed from mp_keys.rbx
#      Paulinchen  2026-10-02: Loaded mp_keys.rbx, with Player.ini's settings kept in $player_ini
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# What the tests of the open world share: stand-ins for the game and the DLL, the scripts every
# one of them builds on (core_hotkeys.rbx, overworld_sync.rbx, ui_actions.rbx, ui_chat.rbx,
# overworld.rbx, coop.rbx and coop_squad.rbx), helpers that feed the world room, and a player standing on
# map 5 of an open world.

require_relative "support"

# Stand-ins for the game.
class Sprite; def initialize(*); end; end
module Graphics; def self.update; end; end
class Spriteset_Map; def update; end; def dispose; end; end
Rect = Struct.new(:x, :y, :width, :height)
class Game_Map
  attr_accessor :map_id, :interpreter, :display_name
  def update(main = false); end
end
class Game_Message; attr_accessor :busy; def busy?; @busy; end; end
class Interpreter; def running?; false; end; end
class Scene_Map; def update; end; def update_scene; end; def scene_changing?; false; end; def scene_change_ok?; $scene_change_ok != false; end; end
class Window_Base; def initialize(*); end; end unless defined?(Window_Base)
class Scene_Battle; def update_basic; end; end
class Spriteset_Battle; def update; end; def dispose; end; end
module SceneManager; class << self; attr_accessor :scene; end; def self.run; end; end
module NWConst; module Config; CONTENTS = [{}]; DATA = {}; DATA_TEXT = {}; DEFAULT = {}; end; end
class Game_Character
  attr_reader :x, :y, :direction, :character_name, :character_index, :opacity, :move_speed, :transparent
  def initialize; @x = 0; @y = 0; @direction = 2; end
  def distance_x_from(x); @x - x; end
  def distance_y_from(y); @y - y; end
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
  def followers; []; end
  def refresh; end
  def transfer?; false; end
end
$game_party = Struct.new(:party_member_max, :all_members, :stand_members).new(8, [], [])
System = Struct.new(:variables, :switches)
$data_system = System.new([], [])
$game_variables = []
$game_switches = []
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
  module Key
    def self.pressed?(code); p = $pressed == code || ($pressed == true && code == 0x42); $pressed = false if p; p; end
    def self.down?(code); ($down || []).include?(code); end
    def self.triggered?(code); pressed?(code); end
  end
  module Mouse; def self.held?; $mouse_held == true; end; def self.position; $mouse; end; end
  module Log; def self.write(m); puts "  log: #{m}"; end; end
  module Capture
    @owners = []
    def self.start(owner); @owners.push(owner) unless @owners.include?(owner); end
    def self.stop(owner); @owners.delete(owner); end
    def self.on?; !@owners.empty?; end
    def self.press?(button); ($held || []).include?(button); end
    def self.trigger?(button); $buttons.delete(button) ? true : false; end
    def self.repeat?(button); $buttons.delete(button) ? true : false; end
  end
  module Player
    def self.name; "Me"; end
    def self.setting(key); $player_ini[key]; end
    def self.store(key, value); $player_ini[key] = value.to_s; true; end
  end
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
$player_ini = {}

load_script "core_hotkeys"
load_script "ui"
load_script "ui_text_box"
load_script "overworld_sync"
load_script "ui_wheel"
load_script "ui_actions"
load_script "ui_chat"
load_script "overworld"
load_script "coop"
load_script "coop_squad"

# One frame on the map: the wheel's keys, then the chat's, as the hooks run them.
def map_frame; MGQ_MpActions.on_map; MGQ_MpChat.on_map; end

$said = []
module MGQ_MpOverworldSync::Link
  def self.next_entry; $inbox.shift; end
  def self.send_to(target, text); $sent << [target, text]; true; end
  def self.say(text); $said << text; true; end
  def self.status; { "state" => "open", "ping" => $status_ping }; end
end

# The texts the line at the bottom left of the map shows, without their icons, which the tests read.
module MGQ_MpOverworldSync::Status
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

$open = true
$game_map = Game_Map.new; $game_map.map_id = 5; $game_map.interpreter = Interpreter.new
$game_message = Game_Message.new
$game_player = Player.new(3, 4, 2, "Actor1", 0, 4, false, nil)
SceneManager.scene = Scene_Map.new
