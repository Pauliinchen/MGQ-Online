#----------------------------------------------------------------
#  ui_leader_hud_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-13: Expected the single player row from ui_single_player.rbx, not from the HUD
#                            - Checked the HUD outside a world by its single player setting
#      Paulinchen  2026-10-12: Checked the Small HUD at the screen edges and a refused size hotkey while typing
#                            - Created
#
#----------------------------------------------------------------

# Covers the Leader HUD, ui_leader_hud.rbx: the Formation Leader's face or map sprite, name, level,
# bars and levels' progress in the Large and Small sizes, the hotkey that switches them, hiding it,
# its place in the layout, the room it takes from the notification box and the map's top left
# windows, and its Mod Config rows.

require_relative "world_support"

# A text drawn on a picture: what, where, how wide, its font's size and color, aligned how.
Text = Struct.new(:text, :x, :y, :width, :size, :color, :align)

# Stands in for the game's picture, recording the texts, fills, gradients and faces or sprites drawn
# on it, each character 8 pixels wide.
class Bitmap
  # The picture's font.
  Font = Struct.new(:size, :color, :bold, :outline, :out_color)
  attr_reader :texts, :fills, :gradients, :faces, :font, :width, :height
  # Makes an empty picture.
  def initialize(width = 1, height = 1); @width = width; @height = height; @font = Font.new; clear; end
  # Answers whether the picture was disposed.
  def disposed?; @disposed ? true : false; end
  # Forgets everything drawn.
  def clear; @texts = []; @fills = []; @gradients = []; @faces = []; end
  # Records a fill, given by a rectangle or by its sides, as its sides and color.
  def fill_rect(*args); @fills << (args.size == 2 ? args[0].to_a + [args[1]] : args); end
  # Records a gradient fill.
  def gradient_fill_rect(x, y, width, height, left, right); @gradients << [x, y, width, height, left, right]; end
  # Measures a text at 8 pixels a character and 16 high.
  def text_size(text); Rect.new(0, 0, text.to_s.size * 8, 16); end
  # Records a text in the font's size and color.
  def draw_text(x, y, width, _height, text, align = 0); @texts << Text.new(text, x, y, width, font.size, font.color, align); end
  # Records a part of a face or sprite sheet drawn: the sheet, the part and where it lands.
  def stretch_blt(dest, sheet, source, *_); @faces << [sheet, source.to_a, dest.to_a]; end
  # Disposes of the picture.
  def dispose; @disposed = true; end
end
# Gives the sprite stand-in what the HUD sets and calls.
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :visible, :opacity, :viewport
  # Takes the viewport.
  def initialize(viewport = nil); @viewport = viewport; end
  # Stands in for the sprite's update, which does nothing here.
  def update; end
  # Disposes of the sprite.
  def dispose; @disposed = true; end
  # Answers whether the sprite was disposed.
  def disposed?; @disposed ? true : false; end
end
# Stands in for the game's cache of faces and character sheets.
module Cache
  # Answers a face by its name.
  def self.face(name); "face:#{name}"; end
  # Answers the sheet in $sheet for every character.
  def self.character(_name); $sheet; end
end

# A sheet of eight characters in frames of 32 by 48, whose sixth character's standing frame facing
# down (128, 192) draws its figure 24 wide and 36 high, from 4 pixels in and 12 below the frame's
# top; every other pixel is see-through.
class Sheet
  # The figure's left, top, width and height on the sheet.
  FIGURE = [132, 204, 24, 36]
  # Answers the sheet's width.
  def width; 384; end
  # Answers the sheet's height.
  def height; 384; end
  # Answers a pixel's color: opaque inside the figure, see-through elsewhere.
  #
  # @param x [Integer] The pixel's column.
  # @param y [Integer] The pixel's row.
  # @return [Color] The color.
  def get_pixel(x, y)
    left, top, width, height = FIGURE
    Color.new(0, 0, 0, x.between?(left, left + width - 1) && y.between?(top, top + height - 1) ? 255 : 0)
  end
end
$sheet = Sheet.new
# Stands in for the emote wheel, which stays shut, unless a test defined it already.
module MGQ_MpEmotes; def self.open?; false; end; end unless defined?(MGQ_MpEmotes)
# Stands in for the game's names of HP and MP.
module Vocab; def self.hp_a; "HP"; end; def self.mp_a; "MP"; end; end
# Stands in for the map's top left windows, which the HUD moves by their y.
class Window_Stand
  attr_accessor :y
  # Places the window at a height.
  def initialize(y); @y = y; end
  # Answers that the window is never disposed.
  def disposed?; false; end
end
# Gives the message stand-in whether it shows and where.
class Game_Message; attr_accessor :visible, :position; end
# Stands in for a Mod Config Remake that reads the rows the mod keeps from the mod.
module ModConfigRemake; def self.mod_stored?(_key); true; end; end
# The Mod Config's rows, the last of them the Return row, which the mod's rows go before.
NWConst::Config::MOD_CONTENTS = [{ :key => :return }] unless NWConst::Config.const_defined?(:MOD_CONTENTS)

# The Formation Leader: a character at base level 30 halfway to the next, at the job's highest level,
# and just come to a race level.
class Leader
  # The character's base, job and race levels.
  LEVELS = { :base => 30, :class => 20, :tribe => 5 }
  attr_accessor :hp, :mp, :name
  # Makes Alice with 189 HP and 40 MP.
  def initialize; @hp = 189; @mp = 40; @name = "Alice"; end
  # Answers the character's id.
  def id; 1; end
  # Answers the face sheet.
  def face_name; "alice_fc1"; end
  # Answers the face's index on its sheet.
  def face_index; 5; end
  # Answers the character sheet.
  def character_name; "Actor1"; end
  # Answers the character's index on its sheet.
  def character_index; 5; end
  # Answers the base level.
  def base_level; LEVELS[:base]; end
  # Answers the most HP.
  def mhp; 252; end
  # Answers the most MP.
  def mmp; 80; end
  # Answers the share of HP left.
  def hp_rate; @hp.to_f / mhp; end
  # Answers the share of MP left.
  def mp_rate; @mp.to_f / mmp; end
  # Answers the job's id.
  def class_id; 7; end
  # Answers the race's id.
  def tribe_id; 9; end
  # Answers the base level's experience.
  def base_exp; 1500; end
  # Answers the job's experience.
  def class_exp; 9000; end
  # Answers the race's experience.
  def tribe_exp; 400; end
  # Answers whether a kind of level is at its highest, which only the job's is.
  def max_level?(kind); kind == :class; end
  # Answers the experience the current base or race level starts at.
  def current_level_exp(kind); { :base => 1000, :tribe => 400 }[kind]; end
  # Answers the experience the next base or race level starts at.
  def next_level_exp(kind); { :base => 2000, :tribe => 800 }[kind]; end
end
leader = Leader.new
$game_party.define_singleton_method(:leader) { $leader }
$leader = leader

load_script "ui_leader_hud"

style = MGQ_MpUi::Style
hud = MGQ_MpLeaderHud
box_class = Sprite_MpLeaderHud
layout = MGQ_MpUi::Layout
stored = layout.instance_variable_get(:@stored)
# Tells where the HUD offers itself to the layout, nil while it offers nothing.
offered = lambda { offer = layout.instance_variable_get(:@offers).find { |each| each.id == :leader_hud }; offer && offer.rect.to_a }
box = box_class.new(:viewport3)
# Finds a text drawn on the HUD.
text = lambda { |wanted| box.bitmap.texts.find { |each| each.text == wanted } }
large = box_class.layout(hud::LARGE)
small = box_class.layout(hud::SMALL)
large_height = box_class.height(large)

check("the box is movable as Leader HUD, never resized, at least as large as the Small size",
      layout.instance_variable_get(:@boxes)[:leader_hud].to_a, ["Leader HUD", 170, box_class.height(small), :none])
check("its rows in the Mod Config: on and off, then the size, both kept by the mod",
      NWConst::Config::MOD_CONTENTS.select { |row| row[:mod_stored] }.map { |row| [row[:key], row[:values].call] }.last(2),
      [[:mp_leader_hud, ["On", "Off"]], [:mp_leader_hud_size, ["Large", "Small"]]])
check("both in the Settings, the single player row left to ui_single_player.rbx",
      [NWConst::Config::MOD_CONTENTS.select { |row| row[:mod_stored] }.last(2).map { |row| row[:name] },
       NWConst::Config::MOD_CONTENTS.any? { |row| row[:key] == hud::SP_SHOWN_OPTION }],
      [[MGQ_MpUi::OPTION_PREFIX + hud::SHOWN_OPTION_NAME, MGQ_MpUi::OPTION_PREFIX + hud::SIZE_OPTION_NAME], false])

# The Large size shows the face, the name, the level, both bars with their numbers and the levels'
# progress.
box.update
check("it shows at once in the Large size until the player picks another, at the top left, offered to the layout where it lies",
      [box.instance_variable_get(:@motion).shown?, box.x, box.y, box.bitmap.width, offered.call], [true, 8, 8, 240, [8, 8, 240, large_height]])
check("the face, the sheet's sixth, shrunk into the square beside the name and both bars",
      box.bitmap.faces, [["face:alice_fc1", [96, 96, 96, 96], [8, 8, 56, 56]]])
name = text.call("Alice")
level = text.call("Lv 30")
check("the name in the text color beside the base level at the right in the heading color",
      [name.nil?, name && name.color, level && [level.color, level.align, level.x + level.width]], [false, style::TEXT, [style::HEADING, 2, 240 - 8]])
check("the HP and MP bars' names and numbers inside them",
      [text.call("HP").nil?, text.call("189 / 252").align, text.call("MP").nil?, text.call("40 / 80").size], [false, 2, false, style::TINY_SIZE])
bars = box.bitmap.gradients
check("the HP bar red and three quarters full, the MP bar half full",
      [bars[0][4..5], bars[0][2], bars[1][2]], [box_class::HP_COLORS, ((240 - 8 - 70) * 0.75).round, ((240 - 8 - 70) * 0.5).round])
check("the base level half done, the job at its highest full, the race just begun empty, across the box",
      [bars.size, bars[2][2], bars[3][2], bars[2][4..5], bars[3][4..5]], [4, 112, 224, box_class::EXP_COLORS[:base], box_class::EXP_COLORS[:class]])
check("the room it takes below the top of the screen for the notification box", hud.room, 8 + large_height + 4)

# The map's top left windows move below the HUD.
scene = Scene_Map.new
name_window = Window_Stand.new(0)
medal_window = Window_Stand.new(0)
scene.instance_variable_set(:@map_name_window, name_window)
scene.instance_variable_set(:@gain_medal_window, medal_window)
SceneManager.scene = scene
hud.lower_windows
check("the map's name and the medal just won move below it", [name_window.y, medal_window.y], [hud.room, hud.room])

# The Small size draws smaller, with the whole map sprite in place of the face.
hud.resize("Small")
box.update
check("the Small size keeps Player.ini's choice and draws smaller, the bars without numbers",
      [$player_ini["leader_hud_size"], box.bitmap.width, box.bitmap.height, text.call("HP"), text.call("189 / 252"), box.bitmap.gradients.size],
      ["Small", 170, box_class.height(small), nil, nil, 4])
check("the name and level still show", [text.call("Alice").nil?, text.call("Lv 30").nil?], [false, false])
check("in place of the face, the sixth character's whole figure standing and facing down, shrunk into the square, standing on its bottom",
      box.bitmap.faces.map { |_sheet, source, dest| [source.to_a, dest] }, [[[132, 204, 24, 36], [12, 7, 23, 34]]])
hud.resize("Large")

# The size's hotkey switches the sizes, but not while the player types.
$sounds = []
$pressed = 0x48
hud.on_map
check("H makes it small, kept in Player.ini, with the cursor's sound", [hud.size, $player_ini["leader_hud_size"], $sounds], ["Small", "Small", ["cursor"]])
$pressed = 0x48
hud.on_map
check("and large again", hud.size, "Large")
MGQ_MpChat.singleton_class.send(:alias_method, :leader_hud_test_typing?, :typing?)
MGQ_MpChat.define_singleton_method(:typing?) { true }
logged = []
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
$mgq_text_input = true
$pressed = 0x48
hud.on_map
$mgq_text_input = nil
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| puts "  log: #{line}" }
check("while the chat box is open the key changes nothing and the letter typed stays out of the log", [hud.size, logged], ["Large", []])
MGQ_MpChat.singleton_class.send(:alias_method, :typing?, :leader_hud_test_typing?)

# A change of HP or of the preset draws the HUD anew.
leader.hp = 63
box.update
check("a change of HP draws it anew", box.bitmap.gradients[0][2], ((240 - 8 - 70) * 0.25).round)
MGQ_MpUi::Theme.apply("Monarch", "a test")
box.update
monarch = box.bitmap.fills.size
MGQ_MpUi::Theme.apply("Legacy", "a test")
box.update
check("a preset change draws it anew, its frame with the preset's rim", monarch - box.bitmap.fills.size, 4)

# A message at the top, turning the HUD off and a party without a leader hide it.
$game_message.visible = true
$game_message.position = 0
box.update
check("a message at the top hides it and gives its room back", [box.instance_variable_get(:@motion).shown?, hud.room], [false, 0])
hud.lower_windows
check("and the map's windows go back where the game put them", [name_window.y, medal_window.y], [0, 0])
$game_message.visible = false
box.update
check("it shows again once the message is gone", box.instance_variable_get(:@motion).shown?, true)
hud.show(false)
box.update
check("turned off it hides, kept in Player.ini", [box.instance_variable_get(:@motion).shown?, $player_ini["leader_hud"], hud.room], [false, "0", 0])
logged = []
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
$pressed = 0x48
hud.on_map
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| puts "  log: #{line}" }
check("while it is off the key changes nothing and the log says why",
      [hud.size, logged.grep(/ignored/)], ["Large", ["keys: hotkey H (Leader HUD Size) ignored: the HUD is off"]])
hud.show(true)
$leader = nil
box.update
check("a party without a leader shows nothing", box.instance_variable_get(:@motion).shown?, false)
$leader = leader

# Outside a world the single player row decides, inside a world the Settings row.
in_world = MGQ_MpOverworldSync.method(:in_world?)
hud.show(false)
MGQ_MpOverworldSync.define_singleton_method(:in_world?) { false }
box.update
check("outside a world the single player row follows the Settings row until the player sets it",
      [hud.on?, box.instance_variable_get(:@motion).shown?], [false, false])
hud.show_sp(true)
box.update
check("set, the single player row decides whatever the Settings row says",
      [hud.on?, box.instance_variable_get(:@motion).shown?, $player_ini["sp_leader_hud"]], [true, true, "1"])
hud.show_sp(false)
box.update
check("turned off there it hides, kept in Player.ini apart from the Settings row",
      [hud.on?, box.instance_variable_get(:@motion).shown?, $player_ini["sp_leader_hud"]], [false, false, "0"])
check("so the size hotkey changes nothing there", hud.busy_reason, "the HUD is off")
hud.show(true)
MGQ_MpOverworldSync.define_singleton_method(:in_world?, in_world)
box.update
check("inside a world the Settings row decides, whatever the single player row says", [hud.on?, box.instance_variable_get(:@motion).shown?], [true, true])
hud.show_sp(true)

# Its place under a strip at the top and where the player left it, as high as the Legacy preset's
# frame leaves it.
large_height = box_class.height(large)
MGQ_MpUi.top_room = 30
box.update
check("a strip at the top moves its default down", [box.y, offered.call[1], hud.room], [38, 38, 8 + large_height + 4])
$player_ini["ui_leader_hud"] = "300,200,10,10"
stored.clear
box.update
check("a place the player left it in holds whatever the strip, as large as its size, and takes no room at the top left",
      [box.x, box.y, offered.call, hud.room], [300, 200, [300, 200, 240, large_height], 0])
$player_ini.delete("ui_leader_hud")
stored.clear
MGQ_MpUi.top_room = 0

# Dragged into the bottom right corner in the Small size, the HUD stays on the screen in either size;
# the preset's frame is thinner than at the start, when the layout learned the HUD's least size.
hud.resize("Small")
box.update
$down = [layout::ALT_KEY, layout::LEFT_BUTTON]
$mouse = [box.x + 10, box.y + 10]
layout.tick
$mouse = [2000, 2000]
layout.tick
$down = []
layout.tick
box.update
small_height = box_class.height(small)
check("the Small size dragged into the bottom right corner stays there, kept in Player.ini",
      [offered.call, $player_ini["ui_leader_hud"]], [[640 - 170, 480 - small_height, 170, small_height], "470,#{480 - small_height},170,#{small_height}"])
hud.resize("Large")
box.update
check("the Large size from there stays wholly on the screen", offered.call, [640 - 240, 480 - large_height, 240, large_height])
$player_ini.delete("ui_leader_hud")
stored.clear
$mouse = nil
