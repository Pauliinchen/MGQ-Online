#----------------------------------------------------------------
#  trade_ui_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Stood in for an offer's key in place of its text
#      Paulinchen  2026-11-01: Checked the trade screen built of the Mod Framework's components
#      Paulinchen  2026-10-31: Dressed the help window through the Mod Framework's theme, as its hook of Window_Base#update does
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

# Covers the trade screen, ui_trade.rbx, on the Mod Framework's components: the window's parts, an
# offer's head and rows, the status line, the bag's steps, the gold box, confirming, the parts
# greyed while the relay decides, the question before cancelling, the steps back by cancel, the
# scene that hosts the window and returns once the trade ended, and the chat box over the window.

require_relative "bridge_support"

# The game's picture, as far as the framework measures texts on it: ten pixels a character.
class Bitmap
  # The font of the picture.
  Font = Struct.new(:size, :name, :bold, :italic, :outline, :shadow, :color, :out_color)
  # A text's measure.
  Size = Struct.new(:width, :height)
  # The picture's font.
  attr_reader :font
  # Creates the picture in the game's font size of 24.
  def initialize(*); @font = Font.new(24); end
  # Measures a text at ten pixels a character.
  def text_size(text); Size.new(text.to_s.size * 10, 24); end
  # The picture is never disposed.
  def disposed?; false; end
  # Frees nothing.
  def dispose; end
end

# The game's system sounds, noted in $sounds.
module Sound
  # Notes the cursor sound.
  def self.play_cursor; $sounds << :cursor; end
  # Notes the confirm sound.
  def self.play_ok; $sounds << :ok; end
  # Notes the buzzer.
  def self.play_buzzer; $sounds << :buzzer; end
  # Notes the cancel sound.
  def self.play_cancel; $sounds << :cancel; end
end

# The game's terms.
module Vocab; def self.currency_unit; "G"; end; end

# The game's items, with a description and whether a copy is the only one of its kind.
module RPG
  # The game's base of items.
  class BaseItem
    # The entry's id, name, icon and description, and whether it is an enchanted or socketed copy.
    attr_reader :id, :name, :icon_index, :description, :unique
    # Creates an entry.
    def initialize(id, name, unique = false); @id, @name, @unique = id, name, unique; @icon_index = 0; @description = "About #{name}."; end
  end
  # An item.
  class Item < BaseItem; end
  # A weapon.
  class Weapon < BaseItem; end
  # An armor.
  class Armor < BaseItem; end
end

# The game's party, as far as its gold.
Party = Struct.new(:gold)

# The game's base of menu scenes: each return to the scene before is counted in $returned.
class Scene_MenuBase
  # Shows the menu's background.
  def start; end
  # Updates nothing.
  def update; end
  # Ends nothing.
  def terminate; end
  # Counts the return.
  def return_scene; $returned += 1; end
end

# The chat, which notes the scenes it follows.
module MGQ_MpChat; def self.follow_scene(owner); ($followed ||= []) << owner; end; end

# The trade, as trade.rbx keeps it: the actions note what they were handed in $calls, and an amount
# is clamped as trade.rbx clamps it.
module MGQ_MpTrade
  # Most of one item a trade moves.
  MAX_AMOUNT = 99
  # One side's gold and items.
  Offer = Struct.new(:gold, :entries) do
    # Finds an item's entry.
    def entry(token); entries.find { |entry| entry.token == token }; end
  end
  # An item of an offer.
  Entry = Struct.new(:token, :item, :amount)
  # A trade.
  Session = Struct.new(:id, :name, :mine, :theirs, :confirmed, :their_confirmed, :stage, :leaving) do
    # Whether the other player confirmed.
    def their_confirmed?; their_confirmed ? true : false; end
  end
  # The trade, the message about it and why a confirmation does not hold.
  class << self; attr_accessor :session, :note, :refusal; end
  # Notes a log line in $trade_log.
  def self.log(line); $trade_log << line; nil; end
  # Shortens a trade's id.
  def self.short(id); id[0, 6]; end
  # Tells why the player cannot confirm.
  def self.confirm_refusal; @refusal; end
  # Sets how many of an item the player offers, clamped as trade.rbx clamps it.
  def self.set_amount(item, amount)
    $calls << [:amount, item.name, amount]
    raise "the bag broke" if $bag_breaks
    session = @session
    return unless session && session.stage == :open

    amount = [[amount, 0].max, Items.held(item), Items.unique?(item) ? 1 : MAX_AMOUNT].min
    entry = session.mine.entry(Items.token(item))
    return if (entry ? entry.amount : 0) == amount

    if amount == 0 then session.mine.entries.delete(entry)
    elsif entry then entry.amount = amount
    else session.mine.entries << Entry.new(Items.token(item), item, amount)
    end
  end
  # Notes the gold offered.
  def self.set_gold(gold); $calls << [:gold, gold]; end
  # Notes a confirmation.
  def self.toggle_confirm; $calls << [:confirm]; end
  # Notes a cancel.
  def self.cancel; $calls << [:cancel]; end
  # The items of a trade, the bag held in $held.
  module Items
    # How many of an item the bag holds.
    def self.held(item); $held[item] || 0; end
    # Whether it is an enchanted or socketed copy.
    def self.unique?(item); item.unique ? true : false; end
    # Whether it is an enchantment stone.
    def self.stone?(item); item.name.end_with?("Stone"); end
    # The item as text.
    def self.token(item); "#{item.class.name[5, 1]}#{item.id}"; end
    # The item's name for the log.
    def self.label(item); item.name; end
    # The tradeable items held.
    def self.bag; $held.keys.select { |item| $held[item] > 0 }; end
    # An offer by its gold and each item's token and amount.
    def self.key(offer); [offer.gold.to_i, offer.entries.map { |entry| [entry.token, entry.amount] }]; end
  end
end

load_script "ui_trade"
StandInConfirm.install

herb = RPG::Item.new(1, "Medical Herb")
potion = RPG::Item.new(2, "Potion")
stone = RPG::Item.new(3, "Fire Stone")
sword = RPG::Weapon.new(1, "Iron Sword")
ring = RPG::Armor.new(1, "Ring", true)
$held = { herb => 15, potion => 120, stone => 1, sword => 1, ring => 1 }
$game_party = Party.new(12345)

# Starts a test step with a new trade with Tester A and nothing noted.
#
# @return [MGQ_MpTrade::Session] The trade.
def new_trade
  $sounds = []
  $calls = []
  $trade_log = []
  $returned = 0
  $bag_breaks = false
  MGQ_MpTrade.note = nil
  MGQ_MpTrade.refusal = nil
  MGQ_MpTrade.session = MGQ_MpTrade::Session.new("0123456789ab", "Tester A", MGQ_MpTrade::Offer.new(0, []), MGQ_MpTrade::Offer.new(0, []), false, false, :open, nil)
end

# Opens the trade screen's scene with the framework working.
#
# @return [Scene_MpTrade] The scene.
def open_scene
  Mod_Framework.available = true
  scene = Scene_MpTrade.new
  scene.start
  scene
end

# Counts how often a list's rows are handed anew and its rows set one by one.
#
# @param list [Mod_Framework::UI::List] The list.
# @return [Hash] :rows and :row, counting on.
def count_sets(list)
  counts = { :rows => 0, :row => 0 }
  list.define_singleton_method(:rows=) { |value| counts[:rows] += 1; super(value) }
  list.define_singleton_method(:set_row) { |place, row| counts[:row] += 1; super(place, row) }
  counts
end

# Has a component tell that it holds the focus.
#
# @param part [Mod_Framework::UI::Component] The component.
def focus_on(part)
  part.define_singleton_method(:focused?) { true }
end

# The window's parts.
session = new_trade
scene = open_scene
screen = scene.screen
check("the screen opens as one framework window titled with the other player",
      [screen.window.open?, screen.window.title, $trade_log.last], [true, "Trading with Tester A", "trade screen opened for trade 012345 with Tester A"])
check("it has the four tabs and the gold, confirm and cancel buttons",
      [(0..3).map { |index| screen.tabs.tab(index).text }, [screen.gold_button, screen.confirm_button, screen.cancel_button].map { |button| button.text }],
      [["Items", "Weapons", "Armor", "Stones"], ["Gold", "Confirm", "Cancel"]])
mine, theirs = screen.sides[:mine], screen.sides[:theirs]
check("both heads name whose offer it is and that it is not confirmed",
      [mine[:name].text, theirs[:name].text, mine[:mark].text, mine[:mark].color], ["You", "Tester A", "Not confirmed", :dim])
check("a long name gives way before its count and the mark at the right, which stay whole",
      [theirs[:name].shrink, theirs[:name].parent.shrink, theirs[:count].shrink, theirs[:mark].shrink, theirs[:mark].grow], [true, true, false, false, 0])
check("an empty offer shows no count and only its gold", [mine[:count].text, mine[:list].rows], ["", [{ :text => "Gold", :right => "0 G" }]])
check("the bag shows the items of the first tab, none offered", screen.bags[0].rows.map { |row| [row[:item].name, row[:value]] },
      [["Medical Herb", "0 / 15"], ["Potion", "0 / 120"]])

# The status line.
MGQ_MpTrade.note = "You cannot carry more Potion."
scene.update
check("the status line shows a message about the trade while it lasts", screen.status.text, "You cannot carry more Potion.")
MGQ_MpTrade.note = nil
scene.update
check("then how the trade stands", screen.status.text, "Confirm once both offers are right. Any change takes both confirmations back.")

# An offer's rows, set only when something they show changed.
their_rows = count_sets(theirs[:list])
pulses = 0
theirs[:box].define_singleton_method(:pulse) { |*_| pulses += 1 }
session.theirs = MGQ_MpTrade::Offer.new(500, [MGQ_MpTrade::Entry.new("w1", sword, 3), MGQ_MpTrade::Entry.new("u9", nil, 1)])
scene.update
check("their offer shows its gold, an item with its amount and an unknown item faint",
      theirs[:list].rows, [{ :text => "Gold", :right => "500 G" }, { :item => sword, :right => "x3" }, { :text => "Unknown item", :faint => true, :right => "x1" }])
check("their head counts the items", theirs[:count].text, " (2)")
check("their change pulses their box once", [their_rows[:rows], pulses], [1, 1])
scene.update
check("an update with nothing changed sets no rows and pulses nothing", [their_rows[:rows], pulses], [1, 1])
session.their_confirmed = true
scene.update
check("their confirmation sets their rows and mark anew without a pulse", [their_rows[:rows], pulses, theirs[:mark].text, theirs[:mark].color], [2, 1, "Confirmed", :good])

# The bag's steps.
bag = screen.bags[0]
bag_sets = count_sets(bag)
bag.receive("side", 0, 1)
check("Right offers one more: the cursor sound, and only that row drawn anew in the good color",
      [$calls.last, $sounds, bag.row_at(0)[:value], bag.row_at(0)[:right_color], bag_sets], [[:amount, "Medical Herb", 1], [:cursor], "1 / 15", :good, { :rows => 0, :row => 1 }])
scene.update
check("the own offer follows, and the bag is not filled anew", [mine[:count].text, mine[:list].rows[1], bag_sets[:rows]], [" (1)", { :item => herb, :right => "x1" }, 0])
focus_on(bag)
screen.window.emit(:page, 1, false)
check("R offers ten more", bag.row_at(0)[:value], "11 / 15")
screen.window.emit(:page, -1, false)
check("L offers ten fewer", bag.row_at(0)[:value], "1 / 15")
bag.receive("submit", 0)
check("confirm offers all", bag.row_at(0)[:value], "15 / 15")
bag.receive("submit", 0)
check("and again none", [bag.row_at(0)[:value], bag.row_at(0).key?(:right_color)], ["0 / 15", false])
$sounds = []
bag.receive("side", 0, -1)
check("Left at none buzzes and logs why", [$sounds, $trade_log.last], [[:buzzer], "not offering fewer of Medical Herb: none offered"])
bag.receive("submit", 1)
bag.receive("side", 1, 1)
check("an item goes at most 99 times", [bag.row_at(1)[:value], $trade_log.last], ["99 / 120", "not offering more of Potion: a trade moves at most 99"])
screen.tabs.picked(2)
armor = screen.bags[2]
check("picking a tab shows its category and logs it", [armor.rows.map { |row| row[:item].name }, $trade_log.last], [["Ring"], "showing the bag's Armor"])
armor.receive("side", 0, 1)
armor.receive("side", 0, 1)
check("a unique copy goes once", [armor.row_at(0)[:value], $trade_log.last], ["1 / 1", "not offering more of Ring: a unique copy goes once"])
check("an empty tab says so", screen.bags[3].empty_text, "Nothing to trade")

# A bag of 1000 items.
many = (1..1000).map { |id| RPG::Item.new(100 + id, "Herb #{id}") }
kept = $held
$held = Hash[many.map { |item| [item, 5] }]
new_trade
scene = open_scene
screen = scene.screen
bag = screen.bags[0]
sets = count_sets(bag)
bag.receive("side", 500, 1)
scene.update
check("a step in a bag of 1000 items sets one row and hands no rows anew", [sets, bag.row_at(500)[:value]], [{ :rows => 0, :row => 1 }, "1 / 5"])
$held = kept

# Gold.
session = new_trade
session.mine.gold = 40
scene = open_scene
screen = scene.screen
screen.gold_button.receive("click")
box = screen.instance_variable_get(:@gold_box)
field = box.children.find { |part| part.is_a?(Mod_Framework::UI::NumberField) }
note = box.children.find { |part| part.is_a?(Mod_Framework::UI::Label) }
check("the gold box opens at the gold offered, nine digits, the party's gold under them",
      [box.open?, field.value, field.digits, field.max, note.text], [true, 40, 9, 12345, "You have 12345 G"])
field.emit(:submit, 500)
check("its answer offers the gold and logs it", [$calls.last, $trade_log.last, box.open?], [[:gold, 500], "typed 500 gold to offer", false])
screen.gold_button.receive("click")
screen.instance_variable_get(:@gold_box).close(:cancel)
check("closed without an answer it keeps the gold and logs it", [$calls.size, $trade_log.last], [1, "the gold box closed without an offer"])

# Confirming.
screen.confirm_button.receive("click")
check("Confirm confirms with the confirm sound", [$calls.last, $sounds.last], [[:confirm], :ok])
session.confirmed = true
scene.update
check("once confirmed the button reads Unconfirm", screen.confirm_button.text, "Unconfirm")
session.confirmed = false
scene.update
MGQ_MpTrade.refusal = "You cannot carry more Potion."
screen.confirm_button.receive("click")
check("a refused confirm still goes to the trade, buzzes and logs why",
      [$calls.last, $sounds.last, $trade_log.last], [[:confirm], :buzzer, "not confirmed: You cannot carry more Potion."])
MGQ_MpTrade.refusal = nil

# While the relay decides.
moved = []
screen.cancel_button.define_singleton_method(:focus) { moved << :cancel; self }
focus_on(screen.gold_button)
session.stage = :committing
scene.update
greyed = (0..3).map { |index| screen.tabs.tab(index) } + [screen.gold_button, screen.confirm_button] + screen.bags
check("while the relay decides the tabs, gold, confirm and the bag take no input, the offers still do",
      [greyed.map { |part| part.enabled? }.uniq, screen.sides.values.map { |side| side[:list].enabled? }], [[false], [true, true]])
check("and the focus moves from what greyed out to Cancel", moved, [:cancel])
session.stage = :open
scene.update

# The key help follows the focus and names cancel first, so cancel shows when the entries that do
# not fit the window are left out from the last.
room = Struct.new(:width) { def text_width(text, _size); Bitmap.new.text_size(text).width; end }.new(Graphics.width - screen.window.send(:padding_sides).values_at(1, 3).inject(:+))
fitting = lambda { screen.key_help.send(:fitting, room, 0).map { |name, text| name + text } }
check("on the bar the key help names cancel for cancelling the trade, then Up for the offers, all of it in the window",
      [screen.key_help.line, fitting.call.size], ["X or Numpad 0: Cancel the trade  Up: Offers", 2])
focus_on(screen.bags[0])
scene.update
check("in the bag it names cancel to go back, then the steps and all or none, and cancel still shows in the window",
      [screen.key_help.line, fitting.call.first], ["X or Numpad 0: Back  Left/Right: 1 more or less  Q or W: 10 less or more  Z: All or none", "X or Numpad 0: Back"])

# Cancel steps back, then asks.
check("cancel steps back from a bag list to its tab and from an offer to Confirm",
      [screen.bags.each_with_index.map { |list, index| list.cancel_to.equal?(screen.tabs.tab(index)) }.uniq, screen.sides.values.map { |side| side[:list].cancel_to.equal?(screen.confirm_button) }],
      [[true], [true, true]])
$asked = []
screen.window.receive("cancel")
check("cancel on the bar asks first, naming the other player and what is lost, and keeps the window open",
      [$asked.last, screen.window.open?], [["Cancel the trade with Tester A? Both offers are lost.", ["Cancel trade", "Keep trading"]], true])
answer_confirm(false)
check("no keeps trading", [$calls.include?([:cancel]), $trade_log.last], [false, "chose to keep trading"])
screen.cancel_button.receive("click")
check("the Cancel button asks the same", $asked.size, 2)
screen.cancel_button.receive("click")
check("a question that could not open changes nothing and is logged", [$asked.size, $trade_log.last], [2, "the question did not open, so trading goes on"])
answer_confirm(true)
check("yes cancels the trade", $calls.last, [:cancel])

# The trade ends.
new_trade
scene = open_scene
screen = scene.screen
screen.gold_button.receive("click")
box = screen.instance_variable_get(:@gold_box)
MGQ_MpTrade.session = nil
scene.update
check("the trade ending under the gold box closes the box, then the window, and returns",
      [box.open?, screen.window.open?, $returned, $calls, $trade_log.last(2)],
      [false, false, 1, [], ["the gold box closed without an offer", "trade screen closed, the trade ended"]])
new_trade
scene = open_scene
screen = scene.screen
screen.cancel_button.receive("click")
MGQ_MpTrade.session = nil
scene.update
check("the trade ending under the question closes it without an answer of the player's",
      [Mod_Framework::UI::Confirm.open?, screen.window.open?, $calls, $trade_log.include?("chose to keep trading")], [false, false, [], false])

# Failures and a window that does not open.
new_trade
scene = open_scene
$bag_breaks = true
scene.screen.bags[0].receive("side", 0, 1)
scene.update
check("a failing step logs where, closes the window, and the scene cancels the trade and returns",
      [$trade_log.any? { |line| line.start_with?("trade screen failed in the bag: RuntimeError: the bag broke") }, $calls.last, $returned], [true, [:cancel], 1])
new_trade
Mod_Framework.available = false
scene = Scene_MpTrade.new
scene.start
check("a window the framework refuses is logged, the trade cancelled and the scene returned",
      [$trade_log.last, $calls, $returned], ["the trade screen's window did not open, so the trade is cancelled", [[:cancel]], 1])

check("the chat follows the trade screen", $followed, [Scene_MpTrade])

# The chat over the trade screen, which waits while a box holds the game's buttons over the scene
# (ui_chat_test.rb opens it over such a window) and, typing, holds them as :chat with the typing
# flag set. The tree's changes are read last, since reading them uses them up.
new_trade
scene = open_scene
screen = scene.screen
capture = Mod_Framework::UI::Capture
tree = Mod_Framework::UI::Tree
hosted = [screen.window.hosts_scene?, capture.on?, capture.over_scene?]
screen.gold_button.receive("click")
check("the trade window hosts its scene: it holds the buttons but none over the scene, so the chat box opens over it, and the gold box holds them over it",
      [hosted, capture.over_scene?], [[true, true, false], true])
screen.instance_variable_get(:@gold_box).close(:cancel)
$mgq_text_input = true
capture.start(:chat)
typing = [tree.typing_outside?, tree.changes["keys_off"]]
$mgq_text_input = false
capture.stop(:chat)
check("while the chat box types, the trade window takes none of the keys typed, and takes them again once it closed",
      [typing, tree.changes["keys_off"], screen.window.open?], [[true, true], false, true])
