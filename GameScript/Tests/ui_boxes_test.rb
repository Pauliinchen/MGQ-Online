#----------------------------------------------------------------
#  ui_boxes_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers what MGQ Online's old screens keep of their own, ui_online.rbx and ui_boxes.rbx: the color of
# a player, the list box and the message box, their places in the Mod Framework's layout, and the
# list windows' mouse wheel and scrollbar. The framework's style, motion, question box and text
# boxes are its own tests'.

require_relative "bridge_support"

# Stand-ins for the game and the mod's base script.
$log = []
$keys_down = []
$buttons = []
$sounds = []
$watched = []
$frame = 0
$player_ini = {}
# The mod's base script: the log in $log, the keys held in $keys_down, the buttons in $buttons and
# Player.ini in $player_ini.
module MGQ_Multiplayer
  # The mod's log, kept in $log.
  module Log; def self.write(message); $log << message; end; end
  # Windows' keys: those watched go to $watched, those in $keys_down are held and triggered.
  module Mod_Framework::UI::Key
    # Records the keys watched in $watched.
    def self.watch(*codes); $watched.concat(codes); end
    # Whether a key in $keys_down was pressed.
    def self.triggered?(code); $keys_down.include?(code); end
    # Whether a key in $keys_down is pressed.
    def self.pressed?(code); $keys_down.include?(code); end
    # Whether a key in $keys_down is held.
    def self.down?(code); $keys_down.include?(code); end
  end
  # The mouse, off the screen.
  module Mod_Framework::UI::Mouse; def self.position; nil; end; end
  # The capture: kept by its owners, its buttons taken from $buttons once each.
  module Mod_Framework::UI::Capture
    @owners = []
    # Adds an owner of the capture.
    def self.start(owner); @owners.push(owner) unless @owners.include?(owner); end
    # Removes an owner of the capture.
    def self.stop(owner); @owners.delete(owner); end
    # Whether anyone holds the capture.
    def self.on?; !@owners.empty?; end
    # Takes a button from $buttons as pressed.
    def self.trigger?(button); $buttons.delete(button) ? true : false; end
    # Takes a button from $buttons as repeated.
    def self.repeat?(button); $buttons.delete(button) ? true : false; end
  end
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
# Mod Config with its Return row alone.
module NWConst; module Config; MOD_CONTENTS = [{ :key => :return }]; end; end
# The game's rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# A font that keeps one color of its own, as RGSS does: color hands out that color and color=
# copies a color's values into it.
class Font < Struct.new(:size, :color, :bold, :outline, :out_color)
  # Copies a color's values into the font's own color.
  #
  # @param value [Color] The color.
  def color=(value)
    self[:color] ||= Color.new
    self[:color].red, self[:color].green, self[:color].blue, self[:color].alpha = value.red, value.green, value.blue, value.alpha
  end
end
# A picture that records its texts, its fills and how many outline copies it drew.
class Bitmap
  # Its size, its font, the texts and fills drawn, the outline copies and whether a text was drawn
  # with the font's own outline on.
  attr_reader :width, :height, :font, :texts, :fills, :outlines, :outlined_twice
  # Creates an empty picture in a white font of 24 without an outline.
  def initialize(width, height); @width = width; @height = height; @font = Font.new(24, Color.new(255, 255, 255, 255), false, false, nil); @texts = []; @fills = []; @outlines = 0; end
  # The picture's whole rectangle.
  def rect; Rect.new(0, 0, @width, @height); end
  # Measures a text at half the font's size a character.
  def text_size(text); Rect.new(0, 0, text.to_s.size * @font.size / 2, @font.size); end
  # Records a text drawn, or counts it as an outline copy when drawn in the outline's color.
  #
  # @param x [Integer] Its left.
  # @param y [Integer] Its top.
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  # @param text [String] The text.
  # @param align [Integer] Its alignment.
  def draw_text(x, y, width, height, text, align = 0)
    @outlined_twice = true if @font.outline
    if @font.color == MGQ_MpUi::Style::OUTLINE
      @outlines += 1
    else
      @texts << [x, y, text, @font.size, @font.color.dup, align]
    end
  end
  # Records a fill with its rectangle and color.
  #
  # @param args [Array] A rectangle and a color, or x, y, width, height and a color.
  def fill_rect(*args)
    x, y, w, h, color = args[0].is_a?(Rect) ? [args[0].x, args[0].y, args[0].width, args[0].height, args[1]] : args
    @fills << [x, y, w, h, color]
  end
  # Forgets the texts, fills and outline copies.
  def clear; @texts.clear; @fills.clear; @outlines = 0; end
  # Frees the picture.
  def dispose; @disposed = true; end
  # Whether the picture was freed.
  def disposed?; @disposed ? true : false; end
end
# The game's sprite.
class Sprite
  # Its picture, place, depth, origin, opacity, whether it shows and its viewport.
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :opacity, :visible, :viewport
  # Creates a visible, opaque sprite at the top left.
  def initialize(viewport = nil); @viewport = viewport; @x = @y = @z = @ox = @oy = 0; @opacity = 255; @visible = true; end
  # Updates nothing.
  def update; end
  # Frees the sprite.
  def dispose; @disposed = true; end
  # Whether the sprite was freed.
  def disposed?; @disposed ? true : false; end
end
# The game's screen of 640 by 480 pixels, at frame $frame.
module Graphics; def self.width; 640; end; def self.height; 480; end; def self.frame_count; $frame; end; def self.update; end; end
# The game's system sounds: each one played is added to $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
# The game's scene manager, whose scene is $scene.
module SceneManager; def self.scene; $scene; end; end
# The game's scene base, which does nothing.
class Scene_Base; def update; end; def start; end; end
# The game's window base, which draws nothing.
class Window_Base; def initialize(*); end; end
# The open world, whose player is me.
module MGQ_MpOverworldSync; module Me; def self.id; "me"; end; end; end
# The party p1.
module MGQ_MpCoop; module Party; def self.member?(state); state["party"] == "p1"; end; end; end
$scene = Scene_Base.new

load_script "core_hotkeys"
load_script "ui_online"
load_script "ui_boxes"

style = MGQ_MpUi::Style

# The color of a player.
colors = MGQ_MpPlayerColor
# Another player: their seat, their state and whether they are in the party.
Peer = Struct.new(:seat, :state, :member)
peer = Peer.new(2, { "id" => "p-other", "name" => "Player A" }, false)
mate = Peer.new(3, { "id" => "p-mate" }, true)
check("the player themself is OWN", [colors.of(:me), colors.of("me"), colors.of(peer, nil, true), colors.label(:me)], [style::OWN, style::OWN, style::OWN, "own"])
check("a party member is MEMBER", [colors.of(mate), colors.of(peer, true), colors.of({ "id" => "x", "party" => "p1" }), colors.label(mate)], [style::MEMBER, style::MEMBER, style::MEMBER, "member"])
check("anyone else is plain text, whatever their id", [colors.of(peer), colors.of("p-other"), colors.of({ "id" => "p-other", "party" => "p2" }), colors.label(peer), colors.const_defined?(:PALETTE)],
      [style::TEXT, style::TEXT, style::TEXT, "plain", false])
check("nobody reads as plain text, without raising", [colors.of(""), colors.of(Object.new), colors.of(nil), colors.label("")], [style::TEXT, style::TEXT, style::TEXT, "plain"])

# The list box: placed by the screen's size, its title cut before its note, an item before what
# lies at its right, the hint naming the numpad's 0, fading in on show and out on hide.
list = Sprite_MpListBox
check("the list box lies SIDE from the sides and TOP and BOTTOM from the top and bottom of the screen, with as many rows as fit",
      [list.box.to_a, list.list_rows], [[40, 32, 560, 404], 14])
box = list.new
long = "A name that goes on and on and on far past the room it has"
view = list::View.of(long, "Players", [[:head, "Online"], [:item, long, :good, "a note"]])
box.show(view)
# The texts the list box drew in a font size.
drawn = lambda { |size| box.bitmap.texts.select { |t| t[3] == size } }
title, note = drawn.call(style::TITLE_SIZE).partition { |t| t[5] == 0 }.map(&:first)
item = drawn.call(style::TEXT_SIZE).find { |t| t[4] == style::GOOD }
hint = drawn.call(style::SMALL_SIZE).last
check("it fades in on show, hidden until then", [box.visible, box.opacity, box.x, box.y], [true, 0, 40, 32])
style::FADE_FRAMES.times { box.update }
check("the title is cut before its note, which is in GOOD at the right",
      [title[2].end_with?(MGQ_MpUi::ELLIPSIS), box.bitmap.text_size(title[2]).width <= 540 - box.bitmap.text_size("Players").width - style::PAD, note[2], note[4] == style::GOOD, note[5]],
      [true, true, "Players", true, 2])
check("an item is cut before its right-hand text, in its color", [item[2].end_with?(MGQ_MpUi::ELLIPSIS), box.bitmap.text_size(item[2]).width <= item[0] + 560 - 24 - 16 - 120 - 24], [true, true])
check("the hint names the numpad's 0, in DIM, and the box fills with BACK", [hint[2], hint[4] == style::DIM, box.bitmap.fills.first[4] == style::BACK],
      ["Up and down: move   X, Numpad 0 or a click outside: close", true, true])
long_hint = "A hint that goes on and on and on and on and on and on far past the box's width, Esc or Numpad 0: close"
box.show(list::View.of("Title", nil, [[:item, "An item", :plain, nil]], long_hint))
hint = drawn.call(style::TINY_SIZE).last
check("a hint wider than the box is drawn whole and smaller, never cut, since its end names the keys",
      [hint && hint[2], hint && hint[4] == style::DIM, box.bitmap.texts.any? { |t| t[2].end_with?(MGQ_MpUi::ELLIPSIS) }], [long_hint, true, false])
box.hide
box.update
check("hide fades it out, the picture kept meanwhile", [box.visible, box.opacity < 255, box.bitmap.texts.empty?], [true, true, false])
(style::FADE_FRAMES - 1).times { box.update }

# The message box: as wide as the screen leaves between SIDE on either side, centred, its title
# cut to it and its hint drawn whole.
message = Sprite_MpMessageBox.new
long_hint = "A hint that goes on and on and on and on and on and on far past the box's width"
message.show("A title that goes on and on and on and on far past the box's width", "Some text.", long_hint)
check("the message box is as wide as the screen leaves, centred", [message.bitmap.width, message.x, message.y], [480, 80, (480 - message.bitmap.height) / 2])
title, hint = message.bitmap.texts.values_at(0, -1)
check("its title is cut to its width, its hint drawn whole and smaller", [title[2].end_with?(MGQ_MpUi::ELLIPSIS), hint[2], hint[3], hint[4] == style::DIM],
      [true, long_hint, style::TINY_SIZE, true])

# The list box in the layout: where the player left it, at its size, its mouse tests following it.
open_fake_ui { ["", 0] }
layout = MGQ_MpUi::Layout
stored = layout.instance_variable_get(:@stored)
# The rectangle the layout offers a box, nil without an offer.
offered = lambda { |id| (offer = layout.instance_variable_get(:@offers).find { |o| o.id == id }) && offer.rect.to_a }
# Keeps a box's place in the framework's settings, or forgets it for nil, and has the layout read it
# anew.
place = lambda { |id, text| text ? Mod_Framework::Settings.store("ui_#{id}", text) : Mod_Framework::Settings.forget("ui_#{id}"); stored.delete(id) }
place.call(:list_box, "100,60,480,200")
box = list.new
mods = (1..8).map { |n| [:item, "Mod number #{n} with a long name", :plain, "listed", [["!", :red, false], ["?", :orange, n == 1]]] }
view = list::View.of("Mods of the world", nil, [[:head, "Mods", ["Required", "Essential"]]] + mods)
box.show(view)
box.update
check("a list box kept in the framework's settings draws there at its size, with the lines that fit, and offers itself to the layout",
      [list.rect.to_a, [box.x, box.y, box.bitmap.width, box.bitmap.height], list.list_rows, offered.call(:list_box)], [[100, 60, 480, 200], [100, 60, 480, 200], 5, [100, 60, 480, 200]])
check("its mouse tests follow it", [list.inside?(120, 70), list.inside?(50, 40), list.line_at(150, 60 + 30 + 24 + 3, view), list.button_at(100 + 480 - 6 - 70 + 5, 2)], [true, false, 1, 2])

# At its least size the list box still shows every column, three lines and the whole hint.
place.call(:list_box, "0,0,100,50")
box.show(view)
texts = box.bitmap.texts.map { |t| t[2] }
check("a list box squeezed below its least size keeps it: the title, three lines and the hint", [list.rect.to_a, list.list_rows, [box.bitmap.width, box.bitmap.height]], [[0, 0, 460, 132], 3, [460, 132]])
check("and draws every column: the item cut before what its right end says, both buttons and their titles, and the hint whole",
      [texts.count("listed"), texts.count("!"), texts.count("?"), texts.include?("Required") && texts.include?("Essential"), texts.last, texts.any? { |t| t.start_with?("Mod number 1") && t.end_with?(MGQ_MpUi::ELLIPSIS) }],
      [2, 2, 2, true, list.hint, true])
view.selected = view.items.last
box.show(view)
check("a box too low for the item picked scrolls it into sight", [view.scroll, box.bitmap.texts.any? { |t| t[2].start_with?("Mod number 8") }], [6, true])
check("and draws a scrollbar right of the lines, its thumb at their end",
      box.bitmap.fills.select { |f| f[2] == style::SCROLLBAR_WIDTH }.map { |f| f[0, 4] }, [[460 - 4 - 4, 30, 4, 72], [460 - 4 - 4, 30 + 48, 4, 24]])
place.call(:list_box, "0,0,640,300")
view.pick(1)
box.show(view)
check("a wider box gives the items the room the fixed columns leave", box.bitmap.texts.map { |t| t[2] }.include?("Mod number 1 with a long name"), true)
MGQ_MpUi::Theme.apply("Monarch", "a test")
box.show(view)
check("a new interface look draws the box anew in its colors", box.bitmap.fills.first[4].to_a, [36, 10, 14, 235])
MGQ_MpUi::Theme.apply("Legacy", "a test")

# A list whose note or hint needs more takes a larger least width, never more than where it starts.
check("a list's least width takes its note beside the title's start and its hint, up to the box's width where it starts",
      [list.least_width(list::View.of("T", nil, [])), list.least_width(list::View.of("T", "x" * 40, [])), list.least_width(list::View.of("T", nil, [], "x" * 100))], [460, 2 * 10 + 144 + 40 * 10 + 6, 560])
place.call(:list_box, "0,0,470,200")
box.show(list::View.of("T", nil, [], "x" * 100))
check("which the layout then holds the box to", [registered_box(:list_box)[1], box.bitmap.width], [560, 560])
place.call(:list_box, nil)
box.dispose

# The message box in the layout: its width kept in the framework's settings, its height following the lines.
place.call(:message_box, "20,400,240,10")
message.show("Title", "Some words that need more than one line in a narrower box.", "Esc: close")
lines = message.bitmap.texts.size - 2
check("a message box kept in the framework's settings takes its width, as high as its lines need, wholly on the screen, and offers itself",
      [message.bitmap.width, lines, message.bitmap.height, message.x, message.y, offered.call(:message_box)],
      [240, 3, 30 + 3 * 24 + 22 + 12, 20, 480 - 136, [20, 344, 240, 136]])
place.call(:message_box, "20,400,100,10")
Sprite_MpMessageBox.follow_layouts
check("a narrower one keeps its least width, followed every frame without another show", [message.bitmap.width, Sprite_MpMessageBox.least_width("Esc: close")], [168, 168])
check("a hint takes the least width it needs whole, up to the box's width where it starts",
      [Sprite_MpMessageBox.least_width("x" * 30), Sprite_MpMessageBox.least_width("x" * 100)], [30 * 7 + 24, 480])
place.call(:message_box, nil)
message.dispose
check("a freed message box no longer follows the layout", Sprite_MpMessageBox.boxes.include?(message), false)

# The list windows' wheel and scrollbar, on a stand-in for the game's Window_Selectable.
class FakeListWindow
  # Its place, size, depth, whether it takes input, the cursor's row and its viewport.
  attr_accessor :x, :y, :width, :height, :z, :active, :index, :viewport
  # Whether it shows and every row selected.
  attr_reader :visible, :selected
  # Creates a visible window of four rows a page, the cursor on its first row.
  def initialize(rows); @rows = rows; @top = 0; @x = 100; @y = 50; @width = 200; @height = 4 * 24 + 24; @z = 100; @visible = true; @active = true; @index = 0; @selected = []; end
  # Updates nothing.
  def update; end
  # Frees the window.
  def dispose; @disposed = true; end
  # Shows or hides the window.
  def visible=(visible); @visible = visible; end
  # The window is always open.
  def open?; true; end
  # The padding around the contents.
  def padding; 12; end
  # The padding below the contents.
  def padding_bottom; 12; end
  # The number of rows.
  def row_max; @rows; end
  # The number of items.
  def item_max; @rows; end
  # One column.
  def col_max; 1; end
  # Four rows a page.
  def page_row_max; 4; end
  # The first row in sight.
  def top_row; @top; end
  # Scrolls to a row, never past the last page.
  def top_row=(row); @top = [[row, row_max - page_row_max].min, 0].max; end
  # Puts the cursor on a row and records it.
  def select(index); @index = index; @selected << index; end
  # Counts the cursor's updates.
  def update_cursor; @cursor_updates = (@cursor_updates || 0) + 1; end
end
# The list window as the mod's list windows are: it scrolls with the wheel and draws a scrollbar.
class ScrollingFakeList < FakeListWindow
  include MGQ_MpScrollingWindow
end
Mod_Framework::UI::Mouse.define_singleton_method(:position) { $mouse }
Mod_Framework::UI::Mouse.define_singleton_method(:wheel) { $wheel.to_i }
window = ScrollingFakeList.new(10)
$mouse = [150, 80]
$wheel = 0
window.update
bar = window.scrollbar
check("a list with more rows than fit shows its scrollbar in its right padding, above it, as high as its rows",
      [bar.visible, bar.x, bar.y, bar.z, bar.bitmap.height, bar.bitmap.fills.map { |f| f[0, 4] }], [true, 100 + 200 - 8, 62, 101, 96, [[0, 0, 4, 96], [0, 0, 4, 38]]])
$wheel = -2
window.update
check("the wheel turned down over it scrolls two rows, the cursor moved along onto the first in sight, the bar following",
      [window.top_row, window.index, bar.bitmap.fills.last[1]], [2, 2, 58 * 2 / 6])
$wheel = 1
window.update
check("turned up it scrolls back a row, the cursor staying while in sight", [window.top_row, window.index, window.selected], [1, 2, [2]])
$mouse = [50, 80]
window.update
check("nothing while the mouse points elsewhere", window.top_row, 1)
$mouse = [150, 80]
window.active = false
window.update
check("nor while the window waits behind another with its cursor", window.top_row, 1)
window.index = -1
window.update
check("but a window without a cursor scrolls", window.top_row, 0)
fits = ScrollingFakeList.new(3)
fits.update
check("a list whose rows fit shows no scrollbar and does not scroll", [fits.scrollbar.visible, fits.top_row], [false, 0])
window.visible = false
check("hiding the window hides its scrollbar at once", bar.visible, false)
window.dispose
check("disposing the window frees its scrollbar", [bar.disposed?, bar.bitmap.disposed?], [true, true])
$wheel = 0
$mouse = nil

