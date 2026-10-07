#----------------------------------------------------------------
#  trade_ui_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-07: Created
#
#----------------------------------------------------------------

# Covers the trade screen, ui_trade.rbx: an offer's first row, whose head never runs into whether
# its player confirmed, and the status line, which shows a message about the trade while it lasts.
# The game's windows stand in, measuring each character at four tenths of the font's size.

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

load File.join(SCRIPTS_DIR, "ui_trade.rbx")

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
check("a name cut to nothing still ends in dots", MGQ_MpTradeUi.fit_name("Tester", 0) { |shown| shown.size }, "...")

session = MGQ_MpTrade::Session.new("Tester A", false, :open, nil, nil)
MGQ_MpTrade.note = "You cannot carry more High-Quality Herb."
check("the status line shows a message about the trade while it lasts", MGQ_MpTradeUi.status_line(session), "You cannot carry more High-Quality Herb.")
MGQ_MpTrade.note = nil
check("then how the trade stands", MGQ_MpTradeUi.status_line(session), "Confirm once both offers are right. Any change takes both confirmations back.")

