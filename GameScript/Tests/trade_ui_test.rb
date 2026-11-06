#----------------------------------------------------------------
#  trade_ui_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Left the screen's parts and keys to the in-game suite, since the UI layer draws them, and kept the scene's flows
#                            - Dropped the stand-in's copy of the clamp of an amount, which the rules in C# decide
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

# Covers the scene of the trade screen, ui_trade.rbx: it opens the screen's window of the UI layer,
# returns once the trade ended, cancels a trade whose window closed or never opened, and has the
# chat follow it. The screen's parts and keys are the in-game suite's (32_step9_b_trade.rb).

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

# The trade, as trade.rbx keeps it: the actions note what they were handed in $calls.
module MGQ_MpTrade
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
  # Sets how many of an item the player offers, as many as asked.
  def self.set_amount(item, amount)
    $calls << [:amount, item.name, amount]
    raise "the bag broke" if $bag_breaks
    session = @session
    return unless session && session.stage == :open

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
    # As many of an item as asked.
    def self.amount(_item, wanted); { "amount" => wanted, "why" => nil }; end
    # An offer by its gold and each item's token and amount.
    def self.key(offer); [offer.gold.to_i, offer.entries.map { |entry| [entry.token, entry.amount] }]; end
  end
end

load_script "ui_trade"
open_fake_ui { ["", 0] }
$world_bridge.answer("ui.tree.layout") { |_changes| {} }

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

# The screen opens over the trade and returns once the trade ended.
new_trade
scene = open_scene
check("the screen opens as one window of the layer", [scene.screen && scene.screen.open?, $trade_log.last],
      [true, "trade screen opened for trade 012345 with Tester A"])
screen = scene.screen
MGQ_MpTrade.session = nil
scene.update
check("the trade ending closes the window and returns", [screen.open?, $returned, $calls, $trade_log.last], [false, 1, [], "trade screen closed, the trade ended"])

# A window that closed while the trade goes on, or never opened, cancels the trade.
new_trade
scene = open_scene
scene.screen.close
check("a window closed while the trade goes on cancels the trade and returns", [$calls, $returned], [[[:cancel]], 1])
new_trade
Mod_Framework.available = false
scene = Scene_MpTrade.new
scene.start
check("a window the framework refuses is logged, the trade cancelled and the scene returned",
      [$trade_log.last, $calls, $returned], ["the trade screen's window did not open, so the trade is cancelled", [[:cancel]], 1])

check("the chat follows the trade screen", $followed, [Scene_MpTrade])
