#----------------------------------------------------------------
#  trade_ui_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-24: Updated the help window through the game's window base, which every window's look follows
#      Paulinchen  2026-10-12: Checked cuts with few measures
#                            - Checked the lists scrolled with the mouse wheel
#                            - Checked that a list's picture holds only the rows around those shown
#      Paulinchen  2026-10-11: Checked the help window's interface look on the trade screen and loaded ui_theme.rbx
#                            - Checked the confirm box before cancelling the trade
#                            - Checked a no after the trade ended under the box
#      Paulinchen  2026-10-07: Cut names through MGQ_MpUi.cut and loaded ui.rbx
#                            - Created
#
#----------------------------------------------------------------

# Covers the trade screen, ui_trade.rbx: an offer's first row, whose head never runs into whether
# its player confirmed, the status line, the confirm box before cancelling, the help window's look,
# and the lists' pictures, which hold only the rows shown and scroll with the mouse wheel.

require_relative "support"

# Stand-ins for the game's windows.

# The game's color.
Color = Struct.new(:red, :green, :blue, :alpha)
# The game's rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# The game's font, as far as its size.
Font = Struct.new(:size)
# The game's picture, as far as its font.
Bitmap = Struct.new(:font)
# The game's window base: measures each character at four tenths of the font's size and keeps what
# it draws.
class Window_Base
  # The texts drawn, each [rect, text, width], and the window's picture.
  attr_reader :drawn, :contents
  # Creates the window with a picture in the game's font size of 24.
  def initialize(*); @drawn = []; @contents = Bitmap.new(Font.new(24)); end
  # Measures a text at four tenths of the font's size a character.
  def text_size(text); Rect.new(0, 0, (text.to_s.size * contents.font.size * 0.4).ceil, 24); end
  # Puts the game's font size back.
  def reset_font_settings; contents.font.size = 24; end
  # Keeps the color of the next texts.
  def change_color(color, *); @color = color; end
  # The color of the game's labels.
  def system_color; :system; end
  # Keeps a text drawn with its rectangle and width.
  #
  # @param args [Array] A rectangle and a text, or x, y, width, height and a text.
  def draw_text(*args)
    rect, text = args[0].is_a?(Rect) ? [args[0], args[1]] : [Rect.new(*args[0, 4]), args[4]]
    @drawn << [rect, text.to_s, text_size(text).width]
  end
  # Updates the window, tinting it as the game's does.
  def update; update_tone; end
  # Tints nothing.
  def update_tone; end
end
# The game's window with a cursor.
class Window_Selectable < Window_Base; def deactivate; end; end
# The game's row of commands.
class Window_HorzCommand < Window_Selectable; end
# The game's base of menu scenes.
class Scene_MenuBase; end

# The trade, as trade.rbx keeps it.
module MGQ_MpTrade
  # A trade: the other player's name, whether the player confirmed, its stage, the notice it closes
  # with and the revisions the other player confirmed.
  Session = Struct.new(:name, :confirmed, :stage, :leaving, :their_confirm)
  # The message about the trade and the trade under way.
  class << self; attr_accessor :note, :session; end
  # Nothing keeps the player from confirming.
  def self.confirm_refusal; nil; end
end

# The game's sprite, which draws nothing.
class Sprite; def initialize(*); end; end
# Player.ini without settings.
module MGQ_Multiplayer; module Player; def self.setting(_key); nil; end; end; end
load_script "ui"
load_script "ui_theme"
load_script "ui_trade"

# Draws an offer's first row in a window as wide as one half of the trade screen.
#
# @param own [Boolean] Whether it shows the player's offer.
# @param name [String] The other player's name.
# @return [Array<Array>] Each text drawn, with its rect and its width.
def head_of(own, name)
  window = Window_MpTradeOffer.new(0, 0, 272, 200, own)
  window.instance_variable_set(:@session, MGQ_MpTrade::Session.new(name, false, :open, nil, nil))
  window.instance_variable_set(:@rows, [:head, :gold, :item])
  window.define_singleton_method(:confirmed?) { |_session| false }
  window.draw_head(Rect.new(4, 0, 240, 24))
  $head_window = window
  window.drawn
end

# Tells whether an offer's head ends before the status beside it, with the gap between them.
fits = lambda do |drawn|
  status, head = drawn
  head[0].x + head[2] <= status[0].x + status[0].width - status[2] - MGQ_MpTradeUi::HEAD_GAP
end
drawn = head_of(false, "Tester A")
check("a short name shows whole beside the status", [drawn.map { |_, text| text }, fits.call(drawn)], [["Not confirmed", "Tester A (1)"], true])
drawn = head_of(false, "A" * 32)
check("the longest name is cut to fit beside the status, which stays whole",
      [drawn[0][1], drawn[1][1].end_with?("... (1)"), fits.call(drawn)], ["Not confirmed", true, true])
drawn = head_of(true, "Tester A")
check("the own offer's head fits as well", [drawn[1][1], fits.call(drawn)], ["You (1)", true])
check("and the rows after the head draw in the game's font again", $head_window.contents.font.size, 24)
narrow = Object.new
narrow.define_singleton_method(:text_size) { |text| Rect.new(0, 0, text.size, 24) }
check("a name cut to nothing still ends in dots", MGQ_MpUi.cut(narrow, "Tester", 0), "...")
check("a name cut keeps what follows it whole", MGQ_MpUi.cut(narrow, "Tester", 8, " (1)"), "T... (1)")
measures = 0
counting = Object.new
counting.define_singleton_method(:text_size) { |text| measures += 1; Rect.new(0, 0, text.size * 7 + text.count(" ") * 2, 24) }
# Cuts a text as cutting a letter at a time would, measuring with counting.
one_by_one = lambda do |text, width, tail|
  next "#{text}#{tail}" if counting.text_size("#{text}#{tail}").width <= width

  head = text
  head = head[0...-1].rstrip while !head.empty? && counting.text_size("#{head}...#{tail}").width > width
  "#{head}...#{tail}"
end
sentence = "Strange crying has been heard from the eastern side of Iliasville, where the poison marsh is."
same = [0, 20, 90, 200, 400, 700].product(["", " (2)"]).all? { |width, tail| MGQ_MpUi.cut(counting, sentence, width, tail) == one_by_one.call(sentence, width, tail) }
measures = 0
MGQ_MpUi.cut(counting, sentence, 200)
check("a long text is cut where cutting a letter at a time would cut it, with a handful of measures", [same, measures <= 9], [true, true])

session = MGQ_MpTrade::Session.new("Tester A", false, :open, nil, nil)
MGQ_MpTrade.note = "You cannot carry more High-Quality Herb."
check("the status line shows a message about the trade while it lasts", MGQ_MpTradeUi.status_line(session), "You cannot carry more High-Quality Herb.")
MGQ_MpTrade.note = nil
check("then how the trade stands", MGQ_MpTradeUi.status_line(session), "Confirm once both offers are right. Any change takes both confirmations back.")

# The confirm box before cancelling, which stands in here, recording the question and answering.
asked = []
$answer = false
$opens = true
MGQ_MpUi::Confirm.define_singleton_method(:ask) { |question, choices, &answer| asked << [question] + choices; answer.call($answer) if $opens; $opens }
activated = 0
$disposed = false
commands = Object.new
commands.define_singleton_method(:activate) { activated += 1 }
commands.define_singleton_method(:disposed?) { $disposed }
cancelled = 0
MGQ_MpTrade.define_singleton_method(:cancel) { cancelled += 1 }
scene = Scene_MpTrade.allocate
scene.instance_variable_set(:@command_window, commands)
MGQ_MpTrade.session = session
scene.on_cancel_trade
check("cancelling asks first, naming the other player and what is lost", asked.last, ["Cancel the trade with Tester A? Both offers are lost.", "Cancel trade", "Keep trading"])
check("no keeps trading: the commands take the input back", [cancelled, activated], [0, 1])
$answer = true
scene.on_cancel_trade
check("yes cancels the trade", [cancelled, activated], [1, 1])
$opens = false
scene.on_cancel_trade
check("a box that could not open hands the input back", [cancelled, activated], [1, 2])
$opens = true
$answer = false
$disposed = true
scene.on_cancel_trade
check("no after the trade ended under the box leaves the disposed commands alone", [asked.size, cancelled, activated], [4, 1, 2])
$disposed = false
MGQ_MpTrade.session = nil
scene.on_cancel_trade
check("without a trade nothing is asked", [asked.size, cancelled, activated], [4, 1, 3])

# A window of the game's own class on the trade screen wears the interface look at once and after a
# change of it, without the game's tint.
# The game's tone, which keeps the values set last.
class Tone; attr_reader :values; def set(*values); @values = values; end; end
# The game's help window: its update tints it in the game's window color, as the game's does.
class HelpWindow < Window_Base
  # The window's skin and the opacity of its back.
  attr_accessor :windowskin, :back_opacity
  # The window's tone.
  def tone; @tone ||= Tone.new; end
  # The window is never disposed.
  def disposed?; false; end
  # Tints the window in the game's window color.
  def update_tone; tone.set(9, 9, 9, 0); end
end
MGQ_MpUi::Theme.define_singleton_method(:skin) { :preset_skin }
help = HelpWindow.new
help.update
scene.wear_theme(help)
check("the help window wears the look at once: the preset's skin, the back's opacity and no tint", [help.windowskin, help.back_opacity, help.tone.values], [:preset_skin, MGQ_MpUi::Style::BACK.alpha, [0, 0, 0, 0]])
help.update
check("and keeps no tint as it updates", help.tone.values, [0, 0, 0, 0])
MGQ_MpUi::Theme.apply("Monarch", "a test")
help.update
check("a new look dresses it anew as it updates", help.back_opacity, 235)

# A list laid out as the game's Window_Selectable lays it out: one column, rows of 24 pixels and a
# page of 10 rows, recording the picture's height and the rows drawn into it.
class ListStandIn
  # The picture's scroll and the number of rows.
  attr_accessor :oy, :item_max
  # The heights of each picture made and the rows drawn into the last, each [index, top in the window].
  attr_reader :heights, :drawn
  # Creates the list with its picture.
  def initialize(rows); @item_max = rows; @heights = []; create_contents; end
  # One column.
  def col_max; 1; end
  # Rows of 24 pixels.
  def item_height; 24; end
  # Ten rows a page.
  def page_row_max; 10; end
  # The rows of a page.
  def page_item_max; page_row_max * col_max; end
  # The number of rows, at least one.
  def row_max; [(item_max + col_max - 1) / col_max, 1].max; end
  # A row's rectangle in the whole list.
  def item_rect(index); Rect.new(0, index / col_max * item_height, 100, item_height); end
  # Records the picture's height and forgets the rows drawn.
  def create_contents; @heights << contents_height; @drawn = []; end
  # Records a row drawn with its top in the window.
  def draw_item(index); @drawn << [index, item_rect(index).y - oy]; end
end
# A list that keeps only the rows shown in its picture, as the trade lists do.
class PagedList < ListStandIn; include MGQ_MpTradeUi::VisibleRows; end

# Reports whether the window would show its up and its down scroll arrow.
#
# @param list [PagedList] The list.
# @return [Array<Boolean>] Up, down.
def arrows(list)
  [list.oy > 0, list.heights.last - list.oy > list.page_row_max * list.item_height]
end

check("both trade lists keep only the rows shown in their picture",
      [Window_MpTradeBag, Window_MpTradeOffer].map { |window| window.include?(MGQ_MpTradeUi::VisibleRows) }, [true, true])
list = PagedList.new(1000)
check("a bag of 1000 items makes a picture of 11 rows, not 1000", [list.heights.last, list.oy], [11 * 24, 0])
list.draw_all_items
check("it draws the first page from the window's top", [list.drawn.first, list.drawn.last, list.drawn.size], [[0, 0], [9, 216], 10])
check("at the top only the down arrow shows", arrows(list), [false, true])
list.top_row = 500
check("scrolled into the middle, the picture holds the page and a hidden row on each side", [list.heights.last, list.oy], [12 * 24, 24])
check("the rows shown are drawn from the window's top", [list.drawn.first, list.drawn.last, list.drawn.size], [[500, 0], [509, 216], 10])
check("in the middle both arrows show", arrows(list), [true, true])
list.top_row = 2000
check("scrolling past the end stops at the last page", [list.top_row, list.drawn.last], [990, [999, 216]])
check("at the end only the up arrow shows", arrows(list), [true, false])
list.item_max = 5
list.create_contents
check("a list that shrank under its first row goes back to the top", [list.top_row, list.heights.last, list.oy], [0, 5 * 24, 0])
check("and shows no arrows", arrows(list), [false, false])
empty = PagedList.new(0)
check("an empty list still makes a picture of one row", empty.heights.last, 24)

# The lists scrolled with the mouse wheel, the cursor drawn where its row lies in the new picture.
# The mouse at $mouse, with $wheel notches.
module MGQ_Multiplayer; module Mouse; def self.position; $mouse; end; def self.wheel; $wheel.to_i; end; end; end
# A list as the trade lists are: it keeps the rows shown in its picture and scrolls with the wheel.
class WheelList < ListStandIn
  include MGQ_MpTradeUi::VisibleRows
  include MGQ_MpUi::ScrollingWindow
  # The cursor's row and whether it takes input.
  attr_accessor :index, :active
  # The cursor's top in the window.
  attr_reader :cursor_top
  # The list always shows.
  def visible; true; end
  # The list is always open.
  def open?; true; end
  # The window's left.
  def x; 0; end
  # The window's top.
  def y; 0; end
  # The window's width.
  def width; 640; end
  # The window's height.
  def height; 264; end
  # The window lies in no viewport.
  def viewport; nil; end
  # Puts the cursor on a row.
  def select(index); @index = index; update_cursor; end
  # Places the cursor where its row lies in the picture.
  def update_cursor; @cursor_top = item_rect(@index).y - oy; end
end
check("both trade lists scroll with the wheel and show a scrollbar",
      [Window_MpTradeBag, Window_MpTradeOffer].map { |window| window.include?(MGQ_MpUi::ScrollingWindow) }, [true, true])
list = WheelList.new(1000)
list.index = 0
list.active = true
$mouse = [100, 100]
$wheel = -3
check("the wheel turned down scrolls three rows, the rows drawn anew, the cursor moved onto the first row in sight at the window's top",
      [list.scroll_by_wheel, list.top_row, list.drawn.first, list.index, list.cursor_top], [true, 3, [3, 0], 3, 0])
$wheel = 1
check("turned up a row, the cursor drawn a row lower in the new picture", [list.scroll_by_wheel, list.top_row, list.index, list.cursor_top], [true, 2, 3, 24])
$wheel = nil
$mouse = nil
