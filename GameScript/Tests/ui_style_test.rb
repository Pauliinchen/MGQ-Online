#----------------------------------------------------------------
#  ui_style_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-24: Checked that the confirm box opens on the title screen, where the game counts no frames
#      Paulinchen  2026-10-12: Checked the scrollbars and the list windows' wheel
#      Paulinchen  2026-10-11: Checked the list, message and confirm boxes in the layout
#                            - Checked that an outlined text is drawn without the font's own outline
#                            - Checked that an outlined text keeps its color and a stranger is plain white
#                            - Created
#
#----------------------------------------------------------------

# Covers what the mod's boxes share in ui.rbx: the style's colors, sizes and drawing helpers, the
# motion of a sprite, the color of a player, the confirm box, the list box and the message box,
# their places in the layout, the scrollbar and the list windows' mouse wheel.

require_relative "support"

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
  module Key
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
  module Mouse; def self.position; nil; end; end
  # The capture: kept by its owners, its buttons taken from $buttons once each.
  module Capture
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
# The game's color.
Color = Struct.new(:red, :green, :blue, :alpha)
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
load_script "ui"
load_script "ui_theme"
load_script "ui_layout"

style = MGQ_MpUi::Style

# The style's values.
check("a member's color is GOOD itself, and there is no white besides the style's text", [style::MEMBER.equal?(style::GOOD), MGQ_MpUi.const_defined?(:WHITE)], [true, false])
check("the sizes, the padding and the timings", [style::TITLE_SIZE, style::TEXT_SIZE, style::SMALL_SIZE, style::TINY_SIZE, style::PAD, style::FADE_FRAMES, style::SLIDE_FRAMES, style::LINGER_FRAMES],
      [20, 18, 16, 14, 6, 12, 8, 180])
check("the confirm box lies above every box and below the typing chat", [MGQ_MpUi::Z[:confirm] > MGQ_MpUi::Z[:boxes], MGQ_MpUi::Z[:confirm] < MGQ_MpUi::Z[:typing]], [true, true])

# The drawing helpers.
bitmap = Bitmap.new(300, 100)
style.use_font(bitmap, 18, style::GOOD)
check("use_font sets the size and color, never bold, with the solid outline", bitmap.font.to_a, [18, style::GOOD, false, true, style::OUTLINE])
style.draw_outlined(bitmap, 0, 0, 100, 24, "Hi", 2)
check("draw_outlined draws four copies straight around the text, then the text in its color, aligned",
      [bitmap.outlines, bitmap.texts, bitmap.font.color], [4, [[0, 0, "Hi", 18, style::GOOD, 2]], style::GOOD])
bitmap.clear
style.use_font(bitmap, 18, style::OWN)
style.draw_outlined(bitmap, 0, 0, 100, 24, "Name")
check("draw_outlined leaves the text in its color though setting the outline's color overwrites the font's own",
      [bitmap.texts.map { |t| t[4] }, bitmap.font.color, bitmap.outlines], [[style::OWN], style::OWN, 4])
check("draw_outlined draws without the font's own outline, which would double the solid one, and turns it back on after",
      [bitmap.outlined_twice, bitmap.font.outline], [nil, true])
bitmap.clear
plate = style.draw_plate(bitmap, 10, 5, 200, 20, "abcd")
check("draw_plate fills the text's width with the padding on either side, centered", [plate.to_a, bitmap.fills], [[86, 5, 48, 20], [[86, 5, 48, 20, style::PLATE]]])
check("capped by the box", style.draw_plate(bitmap, 10, 5, 30, 20, "abcd").to_a, [10, 5, 30, 20])
check("from the left when asked", style.draw_plate(bitmap, 10, 5, 200, 20, "abcd", 0).to_a, [10, 5, 48, 20])
bitmap.clear
check("nothing for an empty text", [style.draw_plate(bitmap, 10, 5, 200, 20, "").to_a, bitmap.fills], [[10, 5, 0, 20], []])
plate = style.draw_plated(bitmap, 10, 5, 200, 20, "abcd")
check("draw_plated returns the plate and draws the text", [plate.to_a, bitmap.texts.map { |t| t[2] }, bitmap.outlines], [[86, 5, 48, 20], ["abcd"], 4])
whole = Color.new(255, 96, 96, 255)
check("faded leaves a color with FADE_FRAMES or more frames left as the object it is", [style.faded(whole, style::FADE_FRAMES).equal?(whole), style.faded(whole, 500).equal?(whole)], [true, true])
check("and lowers its alpha over the last frames, never below 0, a color without an alpha counted as opaque",
      [style.faded(whole, 6).to_a, style.faded(whole, 0).alpha, style.faded(whole, -3).alpha, style.faded(Color.new(1, 2, 3), 3).to_a], [[255, 96, 96, 127], 0, 0, [1, 2, 3, 63]])

# The motion of a sprite: a fade in with a slide.
sprite = Sprite.new
sprite.x, sprite.y = 100, 50
motion = MGQ_MpUi::Motion.new(sprite)
check("a new motion leaves the sprite hidden", [sprite.visible, sprite.opacity, motion.hidden?, motion.shown?, motion.moving?], [false, 0, true, false, false])
motion.show(-40, 0)
check("show puts it at its offset, visible with opacity 0", [sprite.visible, sprite.x, sprite.y, sprite.opacity, motion.shown?], [true, 60, 50, 0, true])
steps = (1..style::SLIDE_FRAMES).map { motion.update }
check("after SLIDE_FRAMES it stands at its place, still fading in", [sprite.x, steps.uniq, motion.moving?], [100, [true], true])
(style::FADE_FRAMES - style::SLIDE_FRAMES).times { motion.update }
check("after FADE_FRAMES it is opaque and still, and update says so", [sprite.opacity, motion.moving?, motion.update], [255, false, false])

# A fade out, turned back halfway.
motion.hide
check("hide heads for 0 with the sprite still visible", [motion.shown?, motion.hidden?, sprite.visible], [false, false, true])
6.times { motion.update }
halfway = sprite.opacity
motion.show(-40, 0)
check("show during a fade out turns the opacity back without a jump", [sprite.x, sprite.opacity, halfway > 0 && halfway < 255, motion.shown?], [100, halfway, true, true])
style::FADE_FRAMES.times { motion.update }
check("and arrives at full opacity", [sprite.opacity, motion.moving?], [255, false])
motion.hide
style::FADE_FRAMES.times { motion.update }
check("a fade out ends invisible", [sprite.opacity, sprite.visible, motion.hidden?, motion.moving?], [0, false, true, false])

# A hide during a slide keeps the slide running.
motion.show(-40, 0)
2.times { motion.update }
motion.hide
(style::SLIDE_FRAMES - 2).times { motion.update }
check("hide during a slide keeps the slide running while the opacity falls", [sprite.x, sprite.opacity, sprite.visible], [100, 0, false])

# Placing and sliding.
other = Sprite.new
other.x, other.y = 10, 10
sliding = MGQ_MpUi::Motion.new(other)
sliding.show
sliding.slide_to(50, 60)
check("the first slide_to on a motion never placed places at once", [other.x, other.y], [50, 60])
sliding.slide_to(90, 60)
check("slide_to keeps the sprite where it stood", [other.x, sliding.moving?], [50, true])
style::SLIDE_FRAMES.times { sliding.update }
check("and arrives after SLIDE_FRAMES", other.x, 90)
sliding.place(0, 0)
check("place moves without a slide", [other.x, other.y], [0, 0])
sliding.slide_to(40, 0)
other.dispose
check("update on a disposed sprite returns false and writes nothing", [sliding.update, other.x], [false, 0])
sliding.hide
sliding.show(-40, 0)
sliding.place(5, 5)
sliding.slide_to(9, 9)
check("nor do show, place and slide_to", [other.x, other.y, other.visible], [0, 0, true])

# The color of a player.
colors = MGQ_MpUi::PlayerColor
# Another player: their seat, their state and whether they are in the party.
Peer = Struct.new(:seat, :state, :member)
peer = Peer.new(2, { "id" => "p-other", "name" => "Player A" }, false)
mate = Peer.new(3, { "id" => "p-mate" }, true)
check("the player themself is OWN", [colors.of(:me), colors.of("me"), colors.of(peer, nil, true), colors.label(:me)], [style::OWN, style::OWN, style::OWN, "own"])
check("a party member is MEMBER", [colors.of(mate), colors.of(peer, true), colors.of({ "id" => "x", "party" => "p1" }), colors.label(mate)], [style::MEMBER, style::MEMBER, style::MEMBER, "member"])
check("anyone else is plain text, whatever their id", [colors.of(peer), colors.of("p-other"), colors.of({ "id" => "p-other", "party" => "p2" }), colors.label(peer), colors.const_defined?(:PALETTE)],
      [style::TEXT, style::TEXT, style::TEXT, "plain", false])
check("nobody reads as plain text, without raising", [colors.of(""), colors.of(Object.new), colors.of(nil), colors.label("")], [style::TEXT, style::TEXT, style::TEXT, "plain"])

# The confirm box.
confirm = MGQ_MpUi::Confirm
capture = MGQ_Multiplayer::Capture

# Opens a box with the frame moved on, so its keys read.
#
# @param confirm [Module] The confirm box.
# @return [Array<Boolean>] Where the answers land.
def ask_box(confirm)
  $keys_down = []
  $buttons = []
  $sounds.clear
  answers = []
  confirm.ask("Leave the party?", ["Leave", "Stay"]) { |yes| answers << yes }
  $frame += 1
  answers
end

$frame = 10
answers = []
check("an empty question is refused and logged", [confirm.ask("", ["Yes", "No"]), confirm.open?, $log.last], [false, false, "ui: confirm box refused: the question is empty"])
check("ask opens the box", confirm.ask("Leave the party?", ["Leave", "Stay"]) { |yes| answers << yes }, true)
sprite = confirm.instance_variable_get(:@sprite)
check("which takes the buttons and watches the accept and decline keys", [confirm.open?, capture.on?, $watched.include?(0x59), $watched.include?(0x4E)], [true, true, true, true])
check("and draws the question, both labels and the hint with the keys, above every box",
      [sprite.bitmap.texts.map { |t| t[2] }, sprite.z], [["Leave the party?", "Leave", "Stay", "Leave: Y   Stay: N, Esc or Numpad 0   Enter: the picked one"], MGQ_MpUi::Z[:confirm]])
check("with its back in its frame first and no picked, on its plate at the right",
      [sprite.bitmap.fills.first[0, 2], sprite.bitmap.fills.select { |f| f[4] == style::PICKED }.map { |f| f[0, 2] }], [[0, 0], [[Sprite_MpConfirmBox::WIDTH / 2 + style::PAD, 6 + 24 + 6]]])
check("centred on the screen", [sprite.x, sprite.y], [120, (480 - sprite.bitmap.height) / 2])
check("a second ask while one is open is refused and logged", [confirm.ask("Again?", ["Yes", "No"]), $log.last], [false, "ui: confirm box refused: one is open (Leave the party?)"])

# The guards: nothing reads in the frame of ask, nor while the player types.
$buttons << :B
confirm.tick
check("a tick in the frame of ask reads no key", [confirm.open?, sprite.disposed?, $buttons], [true, false, [:B]])
$frame += 1
$buttons = []
$mgq_text_input = true
$keys_down = [0x4E]
confirm.tick
check("nor while the player types into a text box", [confirm.open?, sprite.disposed?], [true, false])
$mgq_text_input = nil

# An answer takes two ticks: the first reads it, the second hands it over.
confirm.tick
check("the decline key answers: the cancel sound plays and the box is gone, but the box is still open and holds the buttons",
      [$sounds.last, sprite.disposed?, confirm.open?, capture.on?, answers], ["cancel", true, true, true, []])
check("a second ask between the two ticks is refused", confirm.ask("Again?", ["Yes", "No"]), false)
$buttons = [:B]
confirm.tick
check("the next tick reads no key, gives the buttons back and calls the block once with no", [$buttons, confirm.open?, capture.on?, answers], [[:B], false, false, [false]])
$buttons = []

answers = ask_box(confirm)
$keys_down = [0x59]
confirm.tick
confirm.tick
check("the accept key answers yes with the ok sound", [answers, $sounds.last], [[true], "ok"])
answers = ask_box(confirm)
$buttons << :B
confirm.tick
confirm.tick
check("cancel answers no", [answers, $sounds.last], [[false], "cancel"])
answers = ask_box(confirm)
$keys_down = [0x60]
confirm.tick
confirm.tick
check("the numpad's 0 answers no", [answers, $sounds.last], [[false], "cancel"])
answers = ask_box(confirm)
$buttons << :RIGHT
confirm.tick
moved = confirm.instance_variable_get(:@sprite)
check("right moves the pick to yes with the cursor sound, drawn on its plate at the left", [$sounds.last, moved.bitmap.fills.last[0]], ["cursor", style::PAD])
$buttons << :C
confirm.tick
confirm.tick
check("confirm then answers yes", [answers, $sounds.last], [[true], "ok"])
answers = ask_box(confirm)
$buttons << :C
confirm.tick
confirm.tick
check("confirm alone answers no, which is picked first", [answers, $sounds.last], [[false], "cancel"])

# A close from outside and a scene change answer no in the next tick.
answers = ask_box(confirm)
confirm.close("test")
check("close takes the box off the screen at once", [confirm.instance_variable_get(:@sprite), confirm.open?, $log.last], [nil, true, "ui: confirm box answered Stay (test): Leave the party?"])
confirm.tick
confirm.tick
check("and the block gets no once in the next tick, without a sound", [answers, $sounds], [[false], []])
answers = ask_box(confirm)
$scene = Scene_Base.new
confirm.tick
check("a scene change answers no", [confirm.instance_variable_get(:@sprite), $log.last], [nil, "ui: confirm box answered Stay (the scene changed): Leave the party?"])
confirm.tick
check("in the next tick", [answers, confirm.open?], [[false], false])
answers = ask_box(confirm)
$mgq_text_input = true
$scene = Scene_Base.new
confirm.tick
confirm.tick
$mgq_text_input = nil
check("a scene change answers no while the player types too", [answers, confirm.open?], [[false], false])

# A tick that fails answers no, so the box never holds the buttons for good.
answers = ask_box(confirm)
reading = confirm.method(:read_keys)
confirm.define_singleton_method(:read_keys) { raise "boom" }
confirm.tick
confirm.define_singleton_method(:read_keys, reading)
check("a tick that fails is logged, takes the box off the screen and keeps no",
      [$log.last, confirm.instance_variable_get(:@sprite), confirm.open?, confirm.instance_variable_get(:@answer)],
      ["ui: confirm box tick failed: RuntimeError: boom", nil, true, [false, "the tick failed"]])
confirm.tick
check("which the next tick hands over, giving the buttons back", [answers, confirm.open?, capture.on?], [[false], false, false])

# The hook after every scene's update.
$log.clear
MGQ_MpHooks.report
check("the box ticks after every scene's update, the boxes follow the layout after every frame, and the box leaves after every scene's start",
      $log.grep(/hooks: ui: follows 3, wraps 0 game method\(s\): follows Scene_Base#update, #<Class:Graphics>#update, Scene_Base#start\z/).size, 1)
answers = ask_box(confirm)
$keys_down = [0x59]
$scene.update
$scene.update
check("so a scene's update answers it", answers, [true])

# A scene that starts while the box is open: a start may wait in a loop of its own before any
# update, so the box answers no and finishes at once.
answers = ask_box(confirm)
$sounds.clear
$scene.start
check("a scene's start answers no at once, giving the buttons back without a sound",
      [answers, confirm.open?, capture.on?, confirm.instance_variable_get(:@sprite), $sounds, $log.last],
      [[false], false, false, nil, [], "ui: confirm box answered Stay (the scene changed): Leave the party?"])
$scene.start
check("and a start with no box open does nothing", [answers, confirm.open?], [[false], false])
boxes = MGQ_MpUi::Layout.instance_variable_get(:@boxes)
check("a scene's start makes the boxes known to the layout, the list box and the message box not shown yet at their least sizes",
      [[:list_box, :message_box, :confirm_box].map { |id| boxes[id] && [boxes[id].name, boxes[id].resize] }, boxes[:list_box].to_a[1, 2], boxes[:message_box].to_a[1, 2]],
      [[["List box", :both], ["Message box", :width], ["Confirm box", :width]], [460, 132], [168, 88]])

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
check("and is opaque after FADE_FRAMES", box.opacity, 255)
check("the title is cut before its note, which is in GOOD at the right",
      [title[2].end_with?(MGQ_MpUi::ELLIPSIS), box.bitmap.text_size(title[2]).width <= 540 - box.bitmap.text_size("Players").width - style::PAD, note[2], note[4] == style::GOOD, note[5]],
      [true, true, "Players", true, 2])
check("an item is cut before its right-hand text, in its color", [item[2].end_with?(MGQ_MpUi::ELLIPSIS), box.bitmap.text_size(item[2]).width <= item[0] + 560 - 24 - 16 - 120 - 24], [true, true])
check("the hint names the numpad's 0, in DIM, and the box fills with BACK", [hint[2], hint[4] == style::DIM, box.bitmap.fills.first[4] == style::BACK],
      ["Up and down: move   Esc, Numpad 0 or a click outside: close", true, true])
long_hint = "A hint that goes on and on and on and on and on and on far past the box's width, Esc or Numpad 0: close"
box.show(list::View.of("Title", nil, [[:item, "An item", :plain, nil]], long_hint))
hint = drawn.call(style::TINY_SIZE).last
check("a hint wider than the box is drawn whole and smaller, never cut, since its end names the keys",
      [hint && hint[2], hint && hint[4] == style::DIM, box.bitmap.texts.any? { |t| t[2].end_with?(MGQ_MpUi::ELLIPSIS) }], [long_hint, true, false])
box.hide
box.update
check("hide fades it out, the picture kept meanwhile", [box.visible, box.opacity < 255, box.bitmap.texts.empty?], [true, true, false])
(style::FADE_FRAMES - 1).times { box.update }
check("until it is gone", [box.visible, box.opacity], [false, 0])

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
layout = MGQ_MpUi::Layout
stored = layout.instance_variable_get(:@stored)
# The rectangle the layout offers a box, nil without an offer.
offered = lambda { |id| (offer = layout.instance_variable_get(:@offers).find { |o| o.id == id }) && offer.rect.to_a }
# Keeps a box's place in Player.ini, or forgets it for nil, and has the layout read it anew.
place = lambda { |id, text| text ? $player_ini["ui_#{id}"] = text : $player_ini.delete("ui_#{id}"); stored.delete(id) }
place.call(:list_box, "100,60,480,200")
box = list.new
mods = (1..8).map { |n| [:item, "Mod number #{n} with a long name", :plain, "listed", [["!", :red, false], ["?", :orange, n == 1]]] }
view = list::View.of("Mods of the world", nil, [[:head, "Mods", ["Required", "Essential"]]] + mods)
box.show(view)
box.update
check("a list box kept in Player.ini draws there at its size, with the lines that fit, and offers itself to the layout",
      [list.rect.to_a, [box.x, box.y, box.bitmap.width, box.bitmap.height], list.list_rows, offered.call(:list_box)], [[100, 60, 480, 200], [100, 60, 480, 200], 5, [100, 60, 480, 200]])
check("its mouse tests follow it", [list.inside?(120, 70), list.inside?(50, 40), list.line_at(150, 60 + 30 + 24 + 3, view), list.button_at(100 + 480 - 6 - 70 + 5, 2)], [true, false, 1, 2])

# At its least size the list box still shows every column, three lines and the whole hint.
place.call(:list_box, "0,0,100,50")
box.show(view)
texts = box.bitmap.texts.map { |t| t[2] }
check("a list box squeezed below its least size keeps it: the title, three lines and the hint", [list.rect.to_a, list.list_rows, [box.bitmap.width, box.bitmap.height]], [[0, 0, 460, 132], 3, [460, 132]])
check("and draws every column: the item cut before what its right end says, both buttons and their titles, and the hint whole",
      [texts.count("listed"), texts.count("!"), texts.count("?"), texts.include?("Required") && texts.include?("Essential"), texts.last, texts.any? { |t| t.start_with?("Mod number 1") && t.end_with?(MGQ_MpUi::ELLIPSIS) }],
      [2, 2, 2, true, list::HINT, true])
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
check("which the layout then holds the box to", [MGQ_MpUi::Layout.instance_variable_get(:@boxes)[:list_box].min_width, box.bitmap.width], [560, 560])
place.call(:list_box, nil)
box.dispose

# The message box in the layout: its width kept in Player.ini, its height following the lines.
place.call(:message_box, "20,400,240,10")
message.show("Title", "Some words that need more than one line in a narrower box.", "Esc: close")
lines = message.bitmap.texts.size - 2
check("a message box kept in Player.ini takes its width, as high as its lines need, wholly on the screen, and offers itself",
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

# The confirm box in the layout: its width kept in Player.ini, its choices and hint following it.
place.call(:confirm_box, "10,20,500,0")
answers = ask_box(confirm)
sprite = confirm.instance_variable_get(:@sprite)
check("a confirm box kept in Player.ini takes its width and place, its no choice on its plate at the right",
      [[sprite.x, sprite.y, sprite.bitmap.width], sprite.bitmap.fills.select { |f| f[4] == style::PICKED }.map { |f| f[0, 3] }, offered.call(:confirm_box)],
      [[10, 20, 500], [[500 / 2 + style::PAD, 6 + 24 + 6, 500 / 2 - 2 * style::PAD]], [10, 20, 500, sprite.bitmap.height]])
check("its least width keeps both labels on their plates and the hint as whole as where it starts",
      [Sprite_MpConfirmBox.least_width("Leave", "Stay", "x"), Sprite_MpConfirmBox.least_width("A" * 30, "No", "x"), Sprite_MpConfirmBox.least_width("Leave", "Stay", "x" * 100)],
      [Sprite_MpConfirmBox::MIN_WIDTH, 2 * (30 * 9 + 4 * style::PAD), 400])
confirm.close("test")
confirm.tick
place.call(:confirm_box, "10,20,100,0")
ask_box(confirm)
check("a narrower one keeps the least width its labels and hint need", confirm.instance_variable_get(:@sprite).bitmap.width, 400)
confirm.close("test")
confirm.tick
place.call(:confirm_box, nil)

# The scrollbar every scrolling box draws: a track and a thumb as long as the share in sight,
# placed by the first line in sight, and nothing while every line fits.
bitmap = Bitmap.new(50, 200)
style.draw_scrollbar(bitmap, 10, 20, 100, 0, 10, 10)
check("a scrollbar draws nothing while every line fits", bitmap.fills, [])
style.draw_scrollbar(bitmap, 10, 20, 100, 0, 10, 40)
style.draw_scrollbar(bitmap, 10, 20, 100, 30, 10, 40)
check("its track in the track's color, its thumb in the edge color, at the top and at the end",
      bitmap.fills.map { |f| f[0, 4] + [f[4].equal?(style::EDGE)] },
      [[10, 20, 4, 100, false], [10, 20, 4, 25, true], [10, 20, 4, 100, false], [10, 95, 4, 25, true]])
bitmap.clear
style.draw_scrollbar(bitmap, 0, 0, 100, 0, 1, 1000)
check("a thumb never gets shorter than SCROLLBAR_THUMB", bitmap.fills.last[3], style::SCROLLBAR_THUMB)

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
  include MGQ_MpUi::ScrollingWindow
end
MGQ_Multiplayer::Mouse.define_singleton_method(:position) { $mouse }
MGQ_Multiplayer::Mouse.define_singleton_method(:wheel) { $wheel.to_i }
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

# The confirm box opens on the title screen too, where the game's frame count raises.
class << Graphics; alias_method :counted_frames, :frame_count; def frame_count; raise TypeError, "nil can't be coerced into Fixnum"; end; end
opened = MGQ_MpUi::Confirm.ask("Restart the game now?", ["Restart", "Later"]) { |_yes| }
check("the confirm box opens while the game counts no frames", [opened, MGQ_MpUi::Confirm.open?], [true, true])
MGQ_MpUi::Confirm.close
class << Graphics; alias_method :frame_count, :counted_frames; end
