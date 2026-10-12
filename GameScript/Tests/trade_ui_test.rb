#----------------------------------------------------------------
#  trade_ui_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Checked that a cut with few measures cuts where a letter at a time does
#                            - Checked that a list's picture holds only the rows around those shown, also while it scrolls and after it shrinks
#      Paulinchen  2026-10-11: Checked that the game's help window on the trade screen wears the interface look without the game's tint, loading ui_theme.rbx
#                            - Checked the confirm box before cancelling the trade, with a stand-in that records the question and answers
#                            - Checked that a no after the trade ended under the box leaves the disposed commands alone
#      Paulinchen  2026-10-07: Cut names through MGQ_MpUi.cut, loading ui.rbx first
#                            - Created
#
#----------------------------------------------------------------

# Covers the trade screen, ui_trade.rbx: an offer's first row, whose head never runs into whether
# its player confirmed, the status line, which shows a message about the trade while it lasts,
# the confirm box before cancelling, and the lists' pictures, which hold only the rows shown. The game's windows stand in, measuring each character at
# four tenths of the font's size.

require_relative "support"

# Stand-ins for the game's windows.
Color = Struct.new(:red, :green, :blue, :alpha)
Rect = Struct.new(:x, :y, :width, :height)
Font = Struct.new(:size)
Bitmap = Struct.new(:font)
class Window_Base
  attr_reader :drawn, :contents
  def initialize(*); @drawn = []; @contents = Bitmap.new(Font.new(24)); end
  def text_size(text); Rect.new(0, 0, (text.to_s.size * contents.font.size * 0.4).ceil, 24); end
  def reset_font_settings; contents.font.size = 24; end
  def change_color(color, *); @color = color; end
  def system_color; :system; end
  def draw_text(*args)
    rect, text = args[0].is_a?(Rect) ? [args[0], args[1]] : [Rect.new(*args[0, 4]), args[4]]
    @drawn << [rect, text.to_s, text_size(text).width]
  end
end
class Window_Selectable < Window_Base; def deactivate; end; end
class Window_HorzCommand < Window_Selectable; end
class Scene_MenuBase; end

# The trade, as trade.rbx keeps it.
module MGQ_MpTrade
  Session = Struct.new(:name, :confirmed, :stage, :leaving, :their_confirm)
  class << self; attr_accessor :note, :session; end
  def self.confirm_refusal; nil; end
end

class Sprite; def initialize(*); end; end
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

# A window of the game's own class on the trade screen wears the interface look, now and after a
# change of it, without the game's tint.
class Tone; attr_reader :values; def set(*values); @values = values; end; end
# The game's help window: its update tints it in the game's window color, as the game's does.
class HelpWindow < Window_Base
  attr_accessor :windowskin, :back_opacity
  def tone; @tone ||= Tone.new; end
  def disposed?; false; end
  def update; update_tone; end
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
  attr_accessor :oy, :item_max
  attr_reader :heights, :drawn
  def initialize(rows); @item_max = rows; @heights = []; create_contents; end
  def col_max; 1; end
  def item_height; 24; end
  def page_row_max; 10; end
  def page_item_max; page_row_max * col_max; end
  def row_max; [(item_max + col_max - 1) / col_max, 1].max; end
  def item_rect(index); Rect.new(0, index / col_max * item_height, 100, item_height); end
  def create_contents; @heights << contents_height; @drawn = []; end
  def draw_item(index); @drawn << [index, item_rect(index).y - oy]; end
end
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
