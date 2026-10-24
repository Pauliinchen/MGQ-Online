#----------------------------------------------------------------
#  ui_layout_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-24: Checked the Game's Default look and the game's windows wearing the look
#                            - Checked turning the look on the game's windows off
#      Paulinchen  2026-10-12: Counted the scrollbar track among the preset colors
#                            - Followed the settings to their own Mod Config group
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

# Covers the interface presets of ui_theme.rbx, set in place on the style's colors and kept in
# Player.ini, with their Mod Config row, the game's own look and every window wearing the look, the
# framed box of ui.rbx, and the layout of ui_layout.rbx:
# boxes moved and resized with Alt and the mouse, never below their least size or off the screen,
# kept in Player.ini, put back by a double click or the Mod Config, and outlined while Alt is held.

require_relative "support"

# Stand-ins for the game and the mod's base script.
$log = []
$keys_down = []
$mouse = nil
$player_ini = {}
$frame = 0
# The mod's base script: the log in $log, the keys held in $keys_down, the mouse at $mouse and
# Player.ini in $player_ini.
module MGQ_Multiplayer
  # The mod's log, kept in $log.
  module Log; def self.write(message); $log << message; end; end
  # Windows' keys: those in $keys_down are held and triggered.
  module Key
    # Watches nothing.
    def self.watch(*_codes); end
    # Whether a key in $keys_down was pressed.
    def self.triggered?(code); $keys_down.include?(code); end
    # Whether a key in $keys_down is pressed.
    def self.pressed?(code); $keys_down.include?(code); end
    # Whether a key in $keys_down is held.
    def self.down?(code); $keys_down.include?(code); end
  end
  # The mouse at $mouse.
  module Mouse; def self.position; $mouse; end; end
  # The capture, which never triggers a button.
  module Capture; def self.trigger?(_button); false; end; end
  # Player.ini, kept in $player_ini.
  module Player
    # A setting of Player.ini.
    def self.setting(key); $player_ini[key]; end
    # Stores a setting.
    def self.store(key, value); $player_ini[key] = value.to_s; true; end
    # Forgets a setting.
    def self.forget(key); $player_ini.delete(key); true; end
  end
end
# Mod Config Remake, which stores an entry marked :mod_stored.
module ModConfigRemake; def self.mod_stored?(entry); entry[:mod_stored] ? true : false; end; end
# Mod Config with its Return row alone.
module NWConst; module Config; MOD_CONTENTS = [{ :key => :return }]; end; end
# The game's color.
Color = Struct.new(:red, :green, :blue, :alpha)
# The game's rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# The game's font.
Font = Struct.new(:size, :color, :bold, :outline, :out_color)
# A picture that records its fills and texts.
class Bitmap
  # Its size, its font and the fills and texts drawn.
  attr_reader :width, :height, :font, :fills, :texts
  # Creates an empty picture in a white font of 24.
  def initialize(width, height); @width = width; @height = height; @font = Font.new(24, Color.new(255, 255, 255, 255)); @fills = []; @texts = []; end
  # The picture's whole rectangle.
  def rect; Rect.new(0, 0, @width, @height); end
  # Measures a text at half the font's size a character.
  def text_size(text); Rect.new(0, 0, text.to_s.size * @font.size / 2, @font.size); end
  # Records a text drawn with its place.
  def draw_text(x, y, _width, _height, text, _align = 0); @texts << [x, y, text]; end
  # Records a fill with its rectangle and color values.
  #
  # @param args [Array] A rectangle and a color, or x, y, width, height and a color.
  def fill_rect(*args)
    x, y, w, h, color = args[0].is_a?(Rect) ? [args[0].x, args[0].y, args[0].width, args[0].height, args[1]] : args
    @fills << [x, y, w, h, color.to_a]
  end
  # Copies nothing.
  def blt(*); end
  # Clears nothing.
  def clear_rect(*); end
  # Forgets the fills and texts.
  def clear; @fills.clear; @texts.clear; end
  # Frees the picture.
  def dispose; @disposed = true; end
  # Whether the picture was freed.
  def disposed?; @disposed ? true : false; end
end
# The game's sprite.
class Sprite
  # Its picture, place, depth and whether it shows.
  attr_accessor :bitmap, :x, :y, :z, :visible
  # Creates a visible sprite at the top left.
  def initialize(_viewport = nil); @x = @y = @z = 0; @visible = true; end
  # Frees the sprite.
  def dispose; @disposed = true; end
  # Whether the sprite was freed.
  def disposed?; @disposed ? true : false; end
end
# The game's screen of 640 by 480 pixels, at frame $frame.
module Graphics; def self.width; 640; end; def self.height; 480; end; def self.update; end; def self.frame_count; $frame; end; end
# The game's tone.
class Tone
  # Its red, green, blue and gray.
  attr_reader :red, :green, :blue, :gray
  # Creates the tone.
  def initialize(*values); set(*values); end
  # Sets the tone.
  def set(red = 0, green = 0, blue = 0, gray = 0); @red, @green, @blue, @gray = red, green, blue, gray; end
  # The tone's values.
  def to_a; [@red, @green, @blue, @gray]; end
end
# The game's window skin: a grey background, a frame of a black rim and a white line, a see-through
# white cursor and the palette's white normal and blue system text colors.
class GameSkin
  # The skin's whole rectangle.
  def rect; Rect.new(0, 0, 128, 128); end
  # The color of a pixel.
  def get_pixel(x, y)
    return Color.new(60, 60, 60, 255) if x < 64 && y < 64
    return [Color.new(0, 0, 0, 255), Color.new(255, 255, 255, 255), Color.new(128, 128, 128, 255)][y] || Color.new(0, 0, 0, 0) if x == 96 && y < 16
    { [80, 80] => Color.new(255, 255, 255, 32), [64, 96] => Color.new(255, 255, 255, 255), [64, 112] => Color.new(132, 170, 255, 255) }[[x, y]]
  end
end
# The game's cache, which hands out the window skin.
module Cache; SKIN = GameSkin.new; def self.system(_name); SKIN; end; end
# The game's system, in the game's default window color.
$game_system = Struct.new(:window_tone).new(Tone.new(-34, 0, 68, 0))
# The game's window base: a skin, a background opacity of 192 and a tone, which its update sets to
# the game's window color.
class Window_Base
  # The window's skin, the opacity of its background and its tone.
  attr_accessor :windowskin, :back_opacity, :tone
  # Creates the window in the game's skin and window color.
  def initialize(*); @windowskin = Cache.system("Window"); @back_opacity = 192; @tone = Tone.new; update_tone; end
  # Updates the window.
  def update; update_tone; end
  # Tints the window in the game's window color.
  def update_tone; tone.set(*$game_system.window_tone.to_a); end
  # The window is never disposed.
  def disposed?; false; end
end
# The game's scene base, which does nothing.
class Scene_Base; def update; end; def start; end; end

load_script "core_hotkeys"
load_script "ui"
load_script "ui_theme"
load_script "ui_layout"

style = MGQ_MpUi::Style
theme = MGQ_MpUi::Theme
layout = MGQ_MpUi::Layout
# The layout's Alt key.
ALT = layout::ALT_KEY
# The layout's mouse button.
BUTTON = layout::LEFT_BUTTON

# Runs a frame: the tick after Graphics.update, with the mouse at a point, the left Alt and button
# held or not.
#
# @param position [Array(Integer, Integer), nil] The mouse's place.
# @param alt [Boolean] Whether the left Alt is held.
# @param held [Boolean] Whether the left button is held.
# @param offers [Array<Array>] The arguments of each box offered to the layout first.
def frame(position, alt, held, offers = [])
  offers.each { |offer| MGQ_MpUi::Layout.offer(*offer) }
  $mouse = position
  $keys_down = []
  $keys_down << MGQ_MpUi::Layout::ALT_KEY if alt
  $keys_down << MGQ_MpUi::Layout::LEFT_BUTTON if held
  Graphics.update
end

# The presets.
check("the presets, Monarch first, the game's own look last", theme.names, ["Monarch", "Legacy", "Game's Default"])
check("every preset with colors names each of the style's box colors", theme::PRESETS.select { |preset| preset.colors }.map { |preset| preset.colors.keys.sort }.uniq,
      [[:BACK, :EDGE, :FIELD, :HEADING, :PICKED, :PLATE, :RIM, :TAB, :TITLE, :TRACK, :WELL]])
check("Monarch until the player picks another, logged as the default, its colors set in place", [theme.current.name, $log.grep(/interface look Monarch \(the default\)/).size, style::BACK.to_a],
      ["Monarch", 1, [36, 10, 14, 235]])
back = style::BACK
alias_of_back = back
serial = theme.serial
theme.apply("legacy", "a test")
check("a preset sets the style's colors in place, so a constant naming one follows it",
      [style::BACK.equal?(back), alias_of_back.to_a, style::EDGE.to_a, style::RIM.to_a, style::TITLE.to_a, theme.serial], [true, [0, 0, 0, 170], [140, 140, 140, 220], [0, 0, 0, 0], [255, 255, 255, 255], serial + 1])
theme.apply("Nonsense", "a test")
check("an unknown name, such as the old Obsidian, puts the first preset to use", [theme.current.name, style::BACK.to_a], ["Monarch", [36, 10, 14, 235]])
theme.choose("Legacy")
check("choose keeps the pick in Player.ini", [$player_ini[theme::SETTING], theme.current.name], ["Legacy", "Legacy"])
theme.apply("Monarch", "a test")
theme.load
check("load puts the kept preset to use", theme.current.name, "Legacy")

# The game's own look.
theme.apply("game's default", "a test")
check("the game's look takes the skin's background in the window color, the frame's white line in its black rim and the palette's text colors",
      [theme.game?, style::BACK.to_a, style::EDGE.to_a, style::RIM.to_a, style::HEADING.to_a, style::TITLE.to_a],
      [true, [26, 60, 128, 192], [255, 255, 255, 230], [0, 0, 0, 255], [132, 170, 255, 255], [255, 255, 255, 255]])
serial = theme.serial
Graphics.update
check("an unchanged window color draws nothing anew", theme.serial, serial)
$game_system.window_tone = Tone.new(40, 0, 0, 0)
Graphics.update
check("a changed window color colors the boxes anew on the next frame", [style::BACK.to_a, theme.serial], [[100, 60, 60, 192], serial + 1])
$game_system.window_tone = Tone.new(-34, 0, 68, 0)

# Every window wears the look.
# A window of the mod.
class Window_MpTest < Window_Base; include MGQ_MpUi::Theme::Skinned; end
game_window = Window_Base.new
mod_window = Window_MpTest.new
game_window.update
check("with the game's look, a game window keeps the game's skin, its opacity and the window color",
      [game_window.windowskin.equal?(Cache::SKIN), game_window.back_opacity, game_window.tone.to_a], [true, 192, [-34, 0, 68, 0]])
theme.apply("Monarch", "a test")
game_window.update
mod_window.update
check("with a preset, a game window wears the preset's skin untinted and keeps its own opacity",
      [game_window.windowskin.equal?(theme.skin), game_window.back_opacity, game_window.tone.to_a], [true, 192, [0, 0, 0, 0]])
check("and a window of the mod takes the boxes' background opacity", [mod_window.windowskin.equal?(theme.skin), mod_window.back_opacity], [true, 235])
check("a window made while a preset is in use wears it at once", Window_Base.new.tone.to_a, [0, 0, 0, 0])
check("the game's windows wear the look until turned off", theme.game_windows?, true)
theme.dress_game_windows(false)
game_window.update
mod_window.update
check("turned off, a game window goes back to the game's skin and window color, kept in Player.ini, while the mod's keeps the preset",
      [game_window.windowskin.equal?(Cache::SKIN), game_window.tone.to_a, mod_window.windowskin.equal?(theme.skin), $player_ini[theme::GAME_WINDOWS_SETTING]],
      [true, [-34, 0, 68, 0], true, "0"])
theme.dress_game_windows(true)

# The framed box.
bitmap = Bitmap.new(100, 50)
style.draw_box(bitmap, 0, 0, 100, 50)
check("Monarch's box: the back, then the black rim outermost and the gold edge within it",
      bitmap.fills.map { |fill| fill[0, 4] + [fill[4][0]] }, [[0, 0, 100, 50, 36], [0, 0, 100, 1, 0], [0, 49, 100, 1, 0], [0, 1, 1, 48, 0], [99, 1, 1, 48, 0],
                                                            [1, 1, 98, 1, 200], [1, 48, 98, 1, 200], [1, 2, 1, 46, 200], [98, 2, 1, 46, 200]])
check("with a frame two pixels wide", style.frame_width, 2)
theme.apply("Legacy", "a test")
bitmap.clear
style.draw_frame(bitmap, 0, 0, 100, 50)
check("Legacy's frame is the grey edge alone, one pixel wide", [bitmap.fills.map { |fill| fill[4] }.uniq, bitmap.fills.size, style.frame_width], [[[140, 140, 140, 220]], 4, 1])

# The Mod Config rows.
rows = NWConst::Config::MOD_CONTENTS
look = rows.find { |row| row[:key] == theme::OPTION }
positions = rows.find { |row| row[:key] == layout::OPTION }
check("both rows are added before Return, named for the mod, kept by the mod and the player's own",
      [rows.last[:key], look[:name], look[:mod_stored], look[:personal], positions[:name], positions[:sub]],
      [:return, "[MGQ Online Settings] Interface Look", true, true, "[MGQ Online Settings] Interface Positions", true])
look[:on_change].call("Monarch")
check("the look row lists the presets, reads the one in use and picks one", [look[:values].call, look[:value].call, $player_ini["ui_preset"]], [["Monarch", "Legacy", "Game's Default"], "Monarch", "Monarch"])

# The layout: a box at its default.
layout.register(:test_box, "Test box", 200, 100)
layout.register(:wide_box, "Wide box", 150, 0, :width)
default = Rect.new(20, 30, 300, 120)
check("a box lies at its default until moved", [layout.rect(:test_box, default).to_a, layout.moved?(:test_box)], [[20, 30, 300, 120], false])
check("a default smaller than the least size grows to it, and one off the screen comes back onto it",
      [layout.rect(:test_box, Rect.new(-50, 460, 100, 50)).to_a], [[0, 380, 200, 100]])

# Moving: Alt held, the button goes down inside the box, away from its edges.
offer = [:test_box, 20, 30, 300, 120, 10]
frame([100, 80], true, false, [offer])
frame([100, 80], true, true, [offer])
check("Alt with the button down inside a box starts a drag that moves it", [layout.dragging?(:test_box), layout.arranging?], [true, true])
frame([150, 100], true, true, [offer])
check("while dragged, the box draws where the mouse took it", layout.rect(:test_box, default).to_a, [70, 50, 300, 120])
frame([150, 100], true, false, [offer])
check("letting go keeps the place in Player.ini", [layout.dragging?(:test_box), $player_ini["ui_test_box"], layout.rect(:test_box, default).to_a, layout.moved?(:test_box)],
      [false, "70,50,300,120", [70, 50, 300, 120], true])
check("and logs it", $log.last, "layout: moved Test box to 70,50 at 300x120")

# Resizing from the bottom right corner, never below the least size.
offer = [:test_box, 70, 50, 300, 120, 10]
frame([365, 165], true, true, [offer])
frame([100, 60], true, true, [offer])
check("a drag on the corner resizes, never below the least size, its top left staying put", layout.rect(:test_box, default).to_a, [70, 50, 200, 100])
frame([100, 60], true, false, [offer])
offer = [:test_box, 70, 50, 200, 100, 10]
frame([72, 100], true, true, [offer])
frame([20, 100], true, true, [offer])
check("a drag on the left edge widens it to the left, its right edge staying put", layout.rect(:test_box, default).to_a, [18, 50, 252, 100])
frame([-500, 100], true, true, [offer])
check("never past the screen's edge", layout.rect(:test_box, default).to_a, [0, 50, 270, 100])
frame([-500, 100], true, false, [offer])

# A box that resizes in width alone keeps its default's height and moves on its top and bottom edges.
wide_default = Rect.new(10, 10, 200, 40)
wide = [:wide_box, 10, 10, 200, 40, 5]
frame([100, 12], true, true, [wide])
frame([100, 52], true, true, [wide])
check("a width-only box moves on its top edge", layout.rect(:wide_box, wide_default).to_a, [10, 50, 200, 40])
frame([100, 52], true, false, [wide])
check("and keeps its default's height once it is kept", layout.rect(:wide_box, Rect.new(10, 10, 200, 64)).to_a, [10, 50, 200, 64])

# Clicks without Alt, and the topmost of two boxes.
frame([30, 70], false, false)
frame([30, 70], false, true, [[:test_box, 0, 50, 270, 100, 10]])
check("a click without Alt drags nothing", [layout.dragging?(:test_box), layout.arranging?], [false, false])
frame([30, 70], true, false, [[:test_box, 0, 50, 270, 100, 10], [:wide_box, 10, 50, 200, 64, 50]])
frame([30, 70], true, true, [[:test_box, 0, 50, 270, 100, 10], [:wide_box, 10, 50, 200, 64, 50]])
check("Alt with a click on two boxes takes the topmost", [layout.dragging?(:wide_box), layout.dragging?(:test_box)], [true, false])
frame([30, 70], true, false)
check("a click that never moved keeps nothing new", $player_ini["ui_wide_box"], "10,50,200,40")

# Double click puts a box back.
offer = [:test_box, 0, 50, 270, 100, 10]
frame([100, 100], true, true, [offer])
frame([100, 100], true, false, [offer])
frame([101, 100], true, true, [offer])
check("a double click with Alt puts the box back", [layout.moved?(:test_box), $player_ini.key?("ui_test_box"), layout.rect(:test_box, default).to_a, layout.dragging?(:test_box)],
      [false, false, [20, 30, 300, 120], false])
frame([101, 100], true, false, [offer])

# The outlines while Alt is held.
frame([100, 100], true, false, [[:test_box, 20, 30, 300, 120, 10]])
overlay = layout.overlay
check("Alt held shows the overlay above everything, the box outlined and washed under the mouse",
      [overlay.visible, overlay.z, overlay.bitmap.fills.include?([20, 30, 300, 120, layout::WASH.to_a]), overlay.bitmap.texts.map { |text| text[2] }.include?("Test box"),
       overlay.bitmap.texts.map { |text| text[2] }.include?(layout::HINT)], [true, MGQ_MpUi::Z[:layout], true, true, true])
frame([100, 100], false, false, [[:test_box, 20, 30, 300, 120, 10]])
check("letting go of Alt hides it", overlay.visible, false)

# The Mod Config row puts every box back.
check("the positions row says Moved while any box was moved, and offers Default", [positions[:value].call, positions[:values].call], ["Moved", ["Moved", "Default"]])
positions[:on_change].call("Default")
check("Default puts every box back", [layout.any_moved?, $player_ini.keys.grep(/\Aui_/), positions[:value].call, positions[:values].call], [false, ["ui_preset", "ui_game_windows"], "Default", ["Default"]])

# A place in Player.ini that cannot be read.
$player_ini["ui_broken_box"] = "1,2,x,4"
check("an unreadable place leaves the box at its default", layout.rect(:broken_box, default).to_a, [20, 30, 300, 120])
