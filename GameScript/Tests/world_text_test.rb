#----------------------------------------------------------------
#  world_text_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Checked the description scrolled with the mouse wheel and its scrollbar
#                            - Created
#
#----------------------------------------------------------------

# Covers the text screen, world_text.rbx: a text longer than its box scrolling inside it with a dim
# "..." before it, a short one where the game puts a name, the description broken over the lines of
# a taller box at words, stars of a password inside the box, and what is typed in one frame drawn
# once with one sound. The game's Window_NameEdit stands in with its own layout.

require_relative "support"

# Stand-ins for the game's pictures, windows and scenes.
Rect = Struct.new(:x, :y, :width, :height) do
  def set(other); self.x, self.y, self.width, self.height = other.to_a; end
  def empty; set([0, 0, 0, 0]); end
end
class Color
  attr_accessor :alpha
  def initialize(*); @alpha = 255; end
end
module Graphics
  def self.width; 640; end
  def self.height; 480; end
end

# A window's contents, which keep the underlines filled and the texts drawn since they were cleared.
class Contents
  attr_reader :fills, :texts, :clears
  def initialize; @fills = []; @texts = []; @clears = 0; end
  def clear; @fills.clear; @texts.clear; @clears += 1; end
  def fill_rect(rect, _color); @fills << rect.dup; end
end

# Window_Base as far as Window_NameEdit draws: the font's "A" 14 pixels wide, lines 24 high.
class Window_Base
  attr_accessor :x, :y, :width, :height, :visible
  attr_reader :contents, :cursor_rect
  def initialize(x, y, width, height)
    @x, @y, @width, @height = x, y, width, height
    @cursor_rect = Rect.new(0, 0, 0, 0)
    @visible = true
    create_contents
  end
  def standard_padding; 12; end
  def line_height; 24; end
  def fitting_height(lines); lines * line_height + standard_padding * 2; end
  def contents_width; width - standard_padding * 2; end
  def contents_height; height - standard_padding * 2; end
  def create_contents; @contents = Contents.new; end
  def text_size(text); Rect.new(0, 0, text.to_s.length * 14, line_height); end
  def normal_color; Color.new; end
  def change_color(_color, enabled = true); @enabled = enabled; end
  def draw_text(*args)
    rect = args[0].is_a?(Rect) ? args[0].dup : Rect.new(*args[0, 4])
    text = args[0].is_a?(Rect) ? args[1] : args[4]
    contents.texts << [text.to_s, rect, @enabled]
  end
  def deactivate; end
  def activate; end
  def show; @visible = true; end
  def hide; @visible = false; end
end
class Window_Selectable < Window_Base; end

# The game's Window_NameEdit, its layout and drawing as the game has them.
class Window_NameEdit < Window_Base
  attr_reader :name, :index, :max_char
  def initialize(actor, max_char)
    x = (Graphics.width - 360) / 2
    y = (Graphics.height - (fitting_height(4) + fitting_height(9) + 8)) / 2
    super(x, y, 360, fitting_height(4))
    @actor = actor
    @max_char = max_char
    @default_name = @name = actor.name[0, @max_char]
    @index = @name.size
    deactivate
    refresh
  end
  def restore_default
    @name = @default_name
    @index = @name.size
    refresh
    !@name.empty?
  end
  def add(ch)
    return false if @index >= @max_char
    @name += ch
    @index += 1
    refresh
    true
  end
  def back
    return false if @index == 0
    @index -= 1
    @name = @name[0, @index]
    refresh
    true
  end
  def face_width; 96; end
  def char_width; text_size("A").width; end
  def left
    name_center = (contents_width + face_width) / 2
    name_width = (@max_char + 1) * char_width
    [name_center - name_width / 2, contents_width - name_width].min
  end
  def item_rect(index); Rect.new(left + index * char_width, 36, char_width, line_height); end
  def underline_rect(index)
    rect = item_rect(index)
    rect.x += 1
    rect.y += rect.height - 4
    rect.width -= 2
    rect.height = 2
    rect
  end
  def underline_color; color = normal_color; color.alpha = 48; color; end
  def draw_underline(index); contents.fill_rect(underline_rect(index), underline_color); end
  def draw_char(index)
    rect = item_rect(index)
    rect.x -= 1
    rect.width += 4
    change_color(normal_color)
    draw_text(rect, @name[index] || "")
  end
  def refresh
    contents.clear
    draw_actor_face(@actor, 0, 0)
    @max_char.times { |i| draw_underline(i) }
    @name.size.times { |i| draw_char(i) }
    cursor_rect.set(item_rect(@index))
  end
end

# The game's letters, placed below the box as the game places them.
class Window_NameInput < Window_Selectable
  def initialize(edit_window)
    super(edit_window.x, edit_window.y + edit_window.height + 8, edit_window.width, fitting_height(9))
    @edit_window = edit_window
  end
  def set_handler(*); end
end
class Scene_Base
  def start; end
  def update; end
  def terminate; end
  def scene_changing?; @returned == true; end
  def return_scene; @returned = true; end
end
class Scene_MenuBase < Scene_Base; end
$sounds = []
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end

# Stand-ins for the mod's base script and the world screen.
$typed = ["", 0]
module MGQ_Multiplayer
  module Link
    def self.typing(_on); end
    def self.take_typed; typed = $typed; $typed = ["", 0]; typed; end
  end
  module Background; def self.running?; true; end; end
  module Mouse; def self.position; $mouse; end; def self.wheel; $wheel.to_i; end; end
end
# The scrollbar of ui.rbx, which records what it was asked to draw.
$scrollbars = []
module MGQ_MpUi
  module Style
    SCROLLBAR_WIDTH = 4
    def self.draw_scrollbar(*args); $scrollbars << args[1..-1]; end
  end
end
module MGQ_MpWorld
  class << self; attr_accessor :text_result; end
  def self.log(_line); end
  def self.gamepad_pressed?; false; end
end

load_script "ui_text_box"
load_script "world_text"

# Tells whether a rectangle lies inside the box, allowing a character the pixel to its left and the
# three to its right the game draws it with.
#
# @param rect [Rect] The rectangle.
# @param width [Integer] The box's width.
# @param slack [Boolean] Whether it is a character's rectangle.
# @return [Boolean] Whether it does.
def inside?(rect, width, slack = false)
  rect.x + (slack ? 1 : 0) >= 0 && rect.x + rect.width - (slack ? 3 : 0) <= width
end

# Tells whether everything drawn in a window, the cursor too, lies inside its box.
#
# @param window [Window_MpTextEdit] The window.
# @return [Boolean] Whether it does.
def all_inside?(window)
  width = window.contents_width
  texts = window.contents.texts.reject { |_text, rect, _| rect.y == 0 || rect.width == width }
  inside?(window.cursor_rect, width) && window.contents.fills.all? { |rect| inside?(rect, width) } &&
    texts.all? { |_text, rect, _| inside?(rect, width, true) }
end

# The characters a window drew in the box, left to right and top to bottom, without the caption,
# the hint and MORE.
#
# @param window [Window_MpTextEdit] The window.
# @return [String] The characters.
def drawn(window)
  texts = window.contents.texts.reject { |text, rect, _| rect.y == 0 || rect.width == window.contents_width || text == Window_MpTextEdit::MORE }
  texts.sort_by { |_text, rect, _| [rect.y, rect.x] }.map { |text, _, _| text }.join
end

# Tells whether a window drew MORE, dim, before the text.
#
# @param window [Window_MpTextEdit] The window.
# @return [Boolean] Whether it did.
def more?(window)
  window.contents.texts.any? { |text, _rect, enabled| text == Window_MpTextEdit::MORE && enabled == false }
end

# A short text box, as the player's name: laid out as the game lays out a name.
short = Window_MpTextEdit.new("Your name", "", :max_chars => 16)
game_left = [(336 + 0) / 2 - 17 * 14 / 2, 336 - 17 * 14].min
check("a short box sits where the game puts a name of its length", [short.left, (0..16).map { |index| short.item_rect(index).to_a }],
      [game_left, (0..16).map { |index| [game_left + index * 14, 36, 14, 24] }])
check("and underlines all its places with no MORE", [short.contents.fills.size, more?(short)], [16, false])
16.times { short.add("a") }
check("a full short box keeps its text and cursor in sight", [short.add("a"), drawn(short), all_inside?(short)], [false, "a" * 16, true])

# The mod's name: up to 300 characters on one line.
mod = Window_MpTextEdit.new("The mod's name", "", :max_chars => 300)
added = (1..300).map { |count| mod.add((97 + count % 26).chr) }
check("a long box takes characters up to its most", [added.all?, mod.add("x"), mod.name.size], [true, false, 300])
check("and shows the end of the text with the cursor after it, all inside the box", [mod.left >= 0, all_inside?(mod), drawn(mod), mod.cursor_rect.x], [true, true, mod.name[-22..-1], 23 * 14])
check("with a dim ... before it while the start is out of sight", more?(mod), true)
mod.back
check("Backspace scrolls back by one", [drawn(mod), mod.cursor_rect.x, all_inside?(mod)], [mod.name[-22..-1], 23 * 14, true])
mod.back while mod.name.size > 23
check("once the text fits the box it starts at the left again without the ...", [drawn(mod), more?(mod), mod.cursor_rect.x], [mod.name, false, 23 * 14])
mod.back
check("and the cursor moves left with Backspace", mod.cursor_rect.x, 22 * 14)

# A text longer than the box from the start keeps all of it and shows its end.
long = Window_MpTextEdit.new("The mod's name", "b" * 250 + "c" * 50, :max_chars => 300)
check("a long text it starts with is kept whole and shows its end", [long.name.size, drawn(long), more?(long), all_inside?(long)], [300, "c" * 22, true, true])

# A world's id: 32 characters, more than the box shows.
id = Window_MpTextEdit.new("The world's id", "", :max_chars => 32)
32.times { id.add("f") }
check("a whole world id stays inside the box", [id.name.size, all_inside?(id), more?(id)], [32, true, true])

# A password longer than the box, as stars.
password = Window_MpTextEdit.new("Password", "", :max_chars => 100, :masked => true)
60.times { password.add("p") }
check("a password's stars stay inside the box too", [drawn(password), all_inside?(password)], ["*" * 22, true])

# The description: a taller box of four lines, broken at words.
area = Window_MpTextEdit.new("What the world is about", "", :max_chars => 1000, :area => true)
input = Window_NameInput.new(area)
check("a box of several lines is four lines taller, the letters still on the screen", [area.height, area.y, input.y + input.height <= Graphics.height], [area.fitting_height(7), 20, true])
check("an empty one underlines its four lines and shows no ...", [area.contents.fills.map(&:y).uniq.size, more?(area)], [4, false])
words = %w[the world where monsters and humans live together in peace once the hero returns home]
text = ""
text += "#{words[text.size % words.size]} " while text.size < 1000
text = text[0, 1000]
added = text.each_char.map { |char| area.add(char) }
check("it takes the description up to its most", [added.all?, area.add("x"), area.name], [true, false, text])
lines = area.lines
breaks = lines[0..-2].map { |start, length| [text[start + length - 1], text[start + length]] }
check("it breaks the text at words", breaks.all? { |last, after| last == " " || after == " " }, true)
check("no line is longer than the box", lines.all? { |_start, length| length <= area.line_chars }, true)
shown = lines[-4..-1].map { |start, length| text[start, length].delete(" ") }.join
check("it shows the last four lines with the cursor after the text, all inside the box",
      [drawn(area).delete(" "), all_inside?(area), area.cursor_rect.y, more?(area)], [shown, true, 36 + 3 * 24, true])
check("the lines stay above the hint", area.contents.texts.all? { |_text, rect, _| rect.y == 0 || rect.y + rect.height <= area.contents_height - area.line_height }, true)
long_word = Window_MpTextEdit.new("What the world is about", "x" * 50, :max_chars => 1000, :area => true)
check("a word longer than a line breaks inside it", long_word.lines, [[0, 22], [22, 22], [44, 6]])

# The description scrolled with the mouse wheel.
count = area.lines.size
area.refresh
check("a scrollbar right of the lines tells where the last four of them lie",
      $scrollbars.last, [area.contents_width - 4, 36, 4 * 24, count - 4, 4, count])
$mouse = [area.x + 50, area.y + 50]
$wheel = 2
check("the wheel turned up over it scrolls two lines back, the cursor's line out of sight without its cursor",
      [area.scroll_by_wheel, area.top_line, area.cursor_rect.to_a, more?(area), $scrollbars.last[3]], [true, count - 6, [0, 0, 0, 0], true, count - 6])
$wheel = 999
check("up to the first line, without the ...", [area.scroll_by_wheel, area.top_line, more?(area)], [true, 0, false])
check("and no farther", area.scroll_by_wheel, false)
$wheel = -1
$mouse = [5, 5]
check("nothing while the mouse points elsewhere", [area.scroll_by_wheel, area.top_line], [false, 0])
area.back
check("a change to the text shows the cursor's line again", [area.top_line, area.cursor_rect.y], [area.lines.size - 4, 36 + 3 * 24])
$wheel = 1
$mouse = [short.x + 10, short.y + 10]
check("a box of one line takes no wheel", short.scroll_by_wheel, false)
$wheel = nil
$mouse = nil

# Typing on the keyboard: what came in one frame is drawn once, with one sound.
scene = Scene_MpText.new
scene.prepare(:mod_name, "The mod's name", "", :max_chars => 300)
scene.start
edit = scene.instance_variable_get(:@edit_window)
clears = edit.contents.clears
$typed = ["a" * 120, 1]
scene.update
check("a pasted text is drawn once with one sound", [edit.name.size, edit.contents.clears - clears, $sounds], [120, 1, ["cursor"]])
$sounds.clear
$typed = ["b" * 200, 1]
scene.update
check("a paste past the most plays the buzzer once and keeps what fits", [edit.name.size, $sounds], [300, ["buzzer"]])
$sounds.clear
$typed = ["\b\b\b", 1]
scene.update
check("Backspaces in one frame play the cancel sound once", [edit.name.size, $sounds], [297, ["cancel"]])
$typed = ["\r", 1]
scene.update
check("Enter hands the text back", MGQ_MpWorld.text_result, [:mod_name, "a" * 120 + "b" * 177])
