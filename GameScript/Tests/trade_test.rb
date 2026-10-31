#----------------------------------------------------------------
#  trade_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Expected the plainer texts the player reads
#      Paulinchen  2026-10-30: Checked the trades to recover the DLL hands over
#                            - Checked that the relay hears of a saved trade through the DLL
#                            - Checked the trade through the DLL's view and events, and the clamps before an offer goes to it
#      Paulinchen  2026-10-23: Checked that a trade's id leaves the game's rand as it was
#      Paulinchen  2026-10-17: Checked the trade's place on the wheel next to the teleport to the story
#      Paulinchen  2026-10-12: Checked the offer and confirmation going out again once a failed message does
#                            - Checked the offer and confirmation going out again once the other player is back
#                            - Checked that a message of an unknown trade is answered with a cancel
#                            - Checked offers too long for the relay
#                            - Checked when trades to recover are asked for
#      Paulinchen  2026-10-11: Checked the head line while offering a trade and waiting for one to open
#      Paulinchen  2026-10-08: Checked that an invalid trade id is turned down with its own notice
#                            - Checked the invalid reason the offering player sees
#      Paulinchen  2026-10-07: Checked that an accepted trade that cannot open is turned down with a notice
#                            - Checked that a loaded autosave forgets the slot a trade saves into
#                            - Looked DLL signatures up in the export table of Multiplayer.rb
#                            - Tested the messages kept for the trade screen
#      Paulinchen  2026-10-06: Tested confirming after a cancelled commit and cancels while the relay decides
#                            - Tested that the relay hears of a trade only once a save holds it
#                            - Tested the room checks and enchantment prefixes
#                            - Tested a world made before the world list and fetching again after a failure
#                            - Checked each DLL call's arguments against its signature
#                            - Gave the world a folder id apart from its directory id
#                            - Created
#
#----------------------------------------------------------------
# Covers trades, trade.rbx with the action wheel: offering and accepting a trade, what the DLL is
# handed each frame, the clamps of an offer before the DLL gets it, the DLL's view and events,
# applying and saving a trade the relay committed, items that may not be traded, enchanted copies,
# and recovering a trade the relay committed. The DLL's trade stands in on the fake bridge, its
# rules covered by MGQOnline.Game.Tests.

require_relative "world_support"

# Stand-ins for the game's items and party.
module RPG
  # The game's base of items, weapons and armors.
  class BaseItem
    # The entry's id and name.
    attr_reader :id, :name
    # Creates an entry.
    def initialize(id, name); @id, @name = id, name; end
    # Whether each copy is an item of its own.
    def uniq_item?; false; end
    # Whether it carries enchantments.
    def enchant_item?; false; end
  end
  # An item of the database, maybe a key item or an enchantment stone.
  class Item < BaseItem
    # Creates an item.
    def initialize(id, name, key = false, stone = false); super(id, name); @key, @stone = key, stone; end
    # Whether it is a key item.
    def key_item?; @key; end
    # Whether it is an enchantment stone.
    def enchant_stone?; @stone; end
  end
  # A weapon of the database.
  class Weapon < BaseItem; end
  # An armor of the database.
  class Armor < BaseItem; end
end

# An enchantment of the database, with the name prefixes it rolls.
Enchantment = Struct.new(:prefix, :rare_prefix)

# An enchanted sword, which only one game has, with enchantment 5.
class EnchantedSword < RPG::Weapon
  # The name prefix its enchantment rolled.
  attr_accessor :prefix
  # Creates the sword with its rolls.
  def initialize(rolls); super(9, "Sword"); @rolls = rolls; @prefix = ""; @enchants = [5]; end
  # Each copy is an item of its own.
  def uniq_item?; true; end
  # It carries enchantments.
  def enchant_item?; true; end
  # The rolls that tell this copy apart.
  def rolls; @rolls; end
end

$data_items = [nil, RPG::Item.new(1, "Potion"), RPG::Item.new(2, "Royal Key", true), RPG::Item.new(3, "Ruby", false, true)]
$data_weapons = [nil, RPG::Weapon.new(1, "Club"), RPG::Weapon.new(2, "Spear")]
$data_armors = [nil, RPG::Armor.new(1, "Cap")]
$data_classes = [nil, nil, nil, nil, nil, Enchantment.new(["Dull", "Sharp"], ["Legendary"])]

# The game's party: up to 99 of each item, gold up to the game's most.
class Game_Party
  # The gold and the copies added as items of their own.
  attr_reader :gold, :added
  # Creates a party without items or gold.
  def initialize; @counts = Hash.new(0); @gold = 0; @added = []; end
  # The most gold the party holds.
  def max_gold; 999_999_999; end
  # How many of an item the party holds.
  def item_number(item); @counts[item]; end
  # Adds or removes copies of an item, between 0 and 99.
  def gain_item(item, amount, *); @counts[item] = [[@counts[item] + amount, 0].max, 99].min; @counts.delete(item) if @counts[item] == 0; end
  # Removes copies of an item.
  def lose_item(item, amount, *); gain_item(item, -amount); end
  # Adds or removes gold, between 0 and the most.
  def gain_gold(amount); @gold = [[@gold + amount, 0].max, max_gold].min; end
  # Removes gold.
  def lose_gold(amount); gain_gold(-amount); end
  # Records a copy added as an item of its own.
  def add_item_data(item, number); @added << item; end
  # The party holds at most two copies of each kind.
  def uniq_max_item_number(item); 2; end
  # How many copies of an item's kind the party holds.
  def uniq_item_number(item); @counts.keys.count { |held| held.uniq_item? && held.class == item.class }; end
  # Everything the party holds.
  def held; @counts.keys; end
  # The items held.
  def items; held.select { |item| item.is_a?(RPG::Item) }; end
  # The weapons held.
  def weapons; held.select { |item| item.is_a?(RPG::Weapon) }; end
  # The armors held.
  def armors; held.select { |item| item.is_a?(RPG::Armor) }; end
end
# The game's system data.
class Game_System; end

# The game's data manager: four slots; a save fails while $save_fails, and each save is recorded in
# $saved.
module DataManager
  # The number of save slots.
  def self.savefile_max; 4; end
  # The file of a slot.
  def self.make_filename(index); "Save/Save#{index + 1}.rvdata2"; end
  # Saves into a slot as the game does, a failure answered with false.
  #
  # @param index [Integer] The slot.
  # @return [Boolean] Whether it saved.
  def self.save_game(index)
    save_game_without_rescue(index)
  rescue IOError
    false
  end
  # Saves into a slot, failing while $save_fails.
  def self.save_game_without_rescue(index); raise IOError, "the disk is full" if $save_fails; $saved << index; true; end
  # Loads any slot.
  def self.load_game_without_rescue(index); true; end
  # Sets up nothing.
  def self.setup_new_game; end
end

# The enchanted copies' text, as core_actors.rbx writes them.
module MGQ_MpActors
  # Enchanted copies as text.
  module Items
    # Writes a copy's rolls.
    def self.write(item); "ew9.#{item.rolls}"; end
    # Reads a copy back, nil for a text that is none.
    def self.read(text); text =~ /\Aew9\.(\d+)\z/ ? EnchantedSword.new($1.to_i) : nil; end
  end
end

# The DLL, always there and up to date.
module MGQ_Multiplayer
  # The DLL is always there.
  def self.available?; true; end
  # The game is never outdated.
  def self.outdated?; false; end
end
# The open world, with its folder id and its directory id.
module MGQ_MpWorld; World = Struct.new(:id, :directory_id); def self.world; World.new("f1", "w1"); end; end
# The trade screen.
class Scene_MpTrade; end
# The game's scene manager: each scene called is recorded in $called.
module SceneManager; def self.call(scene); $called << scene; end; end

$dll = []
$saved = []
$called = []
$game_party = Game_Party.new
$game_system = Game_System.new
load_script "trade"

trade = MGQ_MpTrade
potion, key, ruby = $data_items[1], $data_items[2], $data_items[3]
spear = $data_weapons[2]
$game_party.gain_item(potion, 5)
$game_party.gain_item(key, 1)
$game_party.gain_gold(100)

# The trade's id in these checks.
TID = "0123456789abcdef01234567"

# The DLL's trade, standing in: each action is recorded in $trade_calls and answered with
# $trade_view, an offer bumping the player's revision; what the scripts tell each frame goes to
# $trade_ticks.
$trade_calls = []
$trade_ticks = []
$trade_view = { "session" => nil, "accepted" => nil }
%w[accept decline confirm cancel].each do |action|
  $world_bridge.answer("trade.#{action}") { |request| $trade_calls << [action, request]; $trade_view }
end
$world_bridge.answer("trade.offer") do |offer|
  $trade_calls << ["offer", offer]
  session = $trade_view["session"]
  $trade_view = $trade_view.merge("session" => session.merge("my_rev" => session["my_rev"] + 1, "confirmed" => false)) if session
  $trade_view
end
$world_bridge.answer("trade.tick") { |frame| $trade_ticks << frame; nil }
# The relay hears through the DLL that a save holds a trade, recorded in $dll.
$world_bridge.answer("trade.done") { |id| $dll << ["trade.done", id]; nil }

# Writes the DLL's view of an open trade with Friend.
#
# @param fields [Hash] The session's fields that differ.
# @return [Hash] The view.
def open_view(fields = {})
  session = { "id" => TID, "partner" => "friend", "name" => "Friend", "stage" => "open", "my_rev" => 0, "their_rev" => 0, "confirmed" => false,
              "their_confirmed" => false, "relay_id" => nil, "leaving" => nil, "unsent" => nil, "refusal" => nil }
  { "session" => session.merge(fields), "accepted" => nil }
end

# Plays an event of the DLL's trade, taken at the next drain.
#
# @param topic [String] The event.
# @param payload [Object] Its payload.
def from_dll(topic, payload)
  $world_bridge.post(topic, payload)
  MGQ_Multiplayer::Bridge.frame
end

# Lets the trade follow its frames, as the world does every frame.
#
# @param frames [Integer] How many.
def ticks(frames = 1); frames.times { MGQ_MpTrade.tick(true) }; end
# The trade's doing as the line above the player's head shows it.
#
# The lapse was built from the clock a moment before, so the seconds shown are the frames left,
# rounded up.
#
# @return [String, nil] The doing as shown, nil for none.
def doing_shown
  doing = MGQ_MpTrade.own_doing
  doing ? MGQ_MpActions.doing_text(doing)[1] : nil
end

friend = { "id" => "friend", "name" => "Friend", "sprite" => "Actor2", "index" => 0, "map" => 5, "x" => 4, "y" => 4, "d" => 2, "speed" => 4, "hidden" => 0, "scene" => "map" }
$inbox << entry("seat", 0) << entry("in", 2) << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
peer = MGQ_MpOverworldSync::Peers.at(2)
DataManager.load_game_without_rescue(2)

# The wheel and offering a trade.
check("the wheel's ring holds the trade after the duel's place, here the right", MGQ_MpActions.wheel_places, [:UP, :RIGHT, :DOWN_RIGHT, :DOWN_LEFT, :LEFT])
check("someone near: trade offered", [MGQ_MpActions.wheel_options[:RIGHT].text, !MGQ_MpActions.wheel_options[:RIGHT].run.nil?], ["Trade", true])
MGQ_MpActions.wheel_options[:RIGHT].run.call
check("an offer is told, never as a field named trade, which marks trade messages",
      [MGQ_MpOverworldSync::Me.current["trading"], MGQ_MpOverworldSync::Me.current.key?("trade"), MGQ_MpActions.own_line =~ /\AOffering a trade \(\d+ s\) \. \. \.\z/ ? true : false], [1, false, true])
check("and the line above the player's head names the offer with the seconds it stands for", [doing_shown, (trade.own_doing[1] - MGQ_MpActions.lapse_in(MGQ_MpCoop::INVITE_FRAMES)).abs < 1],
      ["Offering a trade (15 s)", true])
ticks(5 * 60)
check("counting them down", doing_shown, "Offering a trade (10 s)")
$inbox << entry("message", 2, told(friend.merge("map" => 6)))
MGQ_MpOverworldSync.tick
check("the overview offers no trade with a player on another map", MGQ_MpTrade::Offers.peer_option(peer).run, nil)
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick

# What the DLL is handed each frame, once it changed.
MGQ_Multiplayer::Bridge.frame
check("the DLL is handed the offer and the world, the player free",
      $trade_ticks.last, { "busy" => nil, "inviting" => true, "targets" => [], "world" => "w1", "on_map" => true, "save" => $game_system.object_id })
$trade_ticks.clear
ticks
MGQ_Multiplayer::Bridge.frame
check("and nothing while nothing changed", $trade_ticks, [])
SceneManager.scene = Scene_Item.new
ticks
MGQ_Multiplayer::Bridge.frame
check("a menu keeps the map from being free", $trade_ticks.last["busy"], "the map is not free")
SceneManager.scene = Scene_Map.new

# Accepting another player's trade.
SceneManager.scene = Scene_Item.new
trade.accept(peer)
check("a player not free on the map cannot accept", [$trade_calls, MGQ_MpOverworldSync::Status.lines.last], [[], "Finish what you are doing first."])
SceneManager.scene = Scene_Map.new
$trade_view = { "session" => nil, "accepted" => { "id" => "friend", "name" => "Friend", "ends" => MGQ_Multiplayer::Bridge.frame_number + 360 } }
trade.accept(peer)
check("accepting stops the player's own offer and has the DLL accept it", [trade.inviting?, $trade_calls.last], [false, ["accept", 2]])
check("then waits for the trade above the player's head, as long as the DLL waits", doing_shown, "Waiting for Friend's trade (6 s)")
120.times { MGQ_Multiplayer::Bridge.frame }
check("counting the bridge's frames down", doing_shown, "Waiting for Friend's trade (4 s)")

# The trade opens.
trade.invite
$trade_view = open_view
from_dll("trade.stop_offering", nil)
from_dll("trade.open_screen", { "id" => TID, "partner" => "friend", "name" => "Friend" })
from_dll("trade.view", $trade_view)
check("a trade that opened stops the player's offer and starts with empty offers",
      [trade.inviting?, trade.session.id, trade.session.mine, trade.own_doing], [false, TID, MGQ_MpTrade::Offer.new(0, []), nil])
$called.clear
trade.on_map
check("the map opens the trade screen", $called, [Scene_MpTrade])

# Both offers: the bag and the party's gold hold an offer back before the DLL gets it.
$trade_calls.clear
trade.set_amount(key, 1)
check("key items stay out of an offer", [trade.session.mine.entries, $trade_calls], [[], []])
trade.set_amount(potion, 9)
check("an offer takes at most what the bag holds", trade.session.mine.entries.map(&:amount), [5])
trade.set_amount(potion, 3)
trade.set_gold(500)
check("and at most the party's gold", trade.session.mine.gold, 100)
trade.set_gold(0)
trade.set_gold(0)
check("each change goes to the DLL as the offer reads, an unchanged one not",
      $trade_calls, [["offer", "g0;i1*5"], ["offer", "g0;i1*3"], ["offer", "g100;i1*3"], ["offer", "g0;i1*3"]])
check("whose answer counts the revisions", trade.session.my_rev, 4)
from_dll("trade.their_offer", { "rev" => 1, "text" => "g50;w2*1" })
check("the other player's offer is read as this game's items", [trade.session.theirs.gold, trade.session.theirs.entries.map { |e| [e.item, e.amount] }], [50, [[spear, 1]]])

# Confirming.
$trade_calls.clear
trade.toggle_confirm
check("confirming hands the DLL what the bag cannot take, here nothing", $trade_calls, [["confirm", nil]])
from_dll("trade.their_offer", { "rev" => 2, "text" => "g0;i2*1" })
trade.toggle_confirm
check("or why it cannot", $trade_calls.last, ["confirm", "Friend's offer holds key items."])
check("which the confirm button tells too", trade.confirm_refusal, "Friend's offer holds key items.")
from_dll("trade.view", open_view("my_rev" => 4, "their_rev" => 2, "refusal" => "The offers hold too many items for one trade. Take some out."))
check("after the trade's own reasons", trade.confirm_refusal, "The offers hold too many items for one trade. Take some out.")
from_dll("trade.view", open_view("my_rev" => 4, "their_rev" => 2, "confirmed" => true))
$trade_calls.clear
trade.toggle_confirm
check("taking a confirmation back checks nothing", $trade_calls, [["confirm", nil]])
from_dll("trade.note", "Both offers are empty.")
check("a message for the trade screen is kept", trade.note, "Both offers are empty.")
ticks(MGQ_MpTrade::NOTE_FRAMES)
check("for a few seconds", trade.note, nil)
lines = logged_lines { from_dll("trade.view", open_view("my_rev" => 4, "their_rev" => 2, "stage" => "committing", "relay_id" => "#{TID}00020004")) }
check("both confirmed: the relay decides, which is logged with the items",
      [trade.session.stage, lines.grep(/both confirmed, trade 01234567 \(my r4, their r2\) sent to the relay: I give 0 gold, i1 Potion x3; I get 0 gold, i2 Royal Key x1/).size],
      [:committing, 1])
$trade_calls.clear
trade.set_amount(potion, 1)
check("nothing changes while the relay decides", [trade.session.mine.entries.map(&:amount), $trade_calls], [[3], []])

# The relay commits: the trade is applied and saved.
relay_id = "#{TID}00020004"
$dll.clear
from_dll("trade.apply", { "id" => relay_id, "name" => "Friend", "mine" => "g0;i1*3", "theirs" => "g60;w2*1" })
check("the trade moves the items and gold", [$game_party.item_number(potion), $game_party.item_number(spear), $game_party.gold], [2, 1, 160])
check("the save notes it, saves into the slot loaded last and tells the relay",
      [$game_system.instance_variable_get(:@mgq_mp_trades), $saved, $dll.last], [[relay_id], [2], ["trade.done", relay_id]])
check("the trade ends with a notice", [trade.session, MGQ_MpOverworldSync::Status.lines.last], [nil, "Trade with Friend complete, game saved."])
$save_fails = true
$dll.clear
from_dll("trade.apply", { "id" => "#{TID}00030005", "name" => "Friend", "mine" => "g0", "theirs" => "g0" })
check("a trade the save could not hold stays undone at the relay",
      [$dll.map(&:first), MGQ_MpOverworldSync::Status.lines.last], [[], "Trade with Friend complete. Save your game."])
$save_fails = false
DataManager.save_game(1)
check("until the next save in the world holds it", $dll.map(&:first), ["trade.done"])
DataManager.load_game_without_rescue(2)

# Other players who could not trade, and a trade that ended.
trade.invite("friend")
from_dll("trade.declined", { "seat" => 2, "id" => "friend", "reason" => "no", "accepted" => false })
check("a player who declined is no longer named by the offer", trade.targets, [])
from_dll("trade.open_screen", { "id" => TID, "partner" => "friend", "name" => "Friend" })
from_dll("trade.note", "The trade could not be completed. Try again.")
from_dll("trade.closed", nil)
check("a trade that ended forgets its screen and its message", [trade.session, trade.note, trade.instance_variable_get(:@open_screen)], [nil, nil, false])
trade.stop

# What may not be taken.
offer = MGQ_MpTrade::Items.read_offer("g0;i2*1")
check("an offer with key items cannot be confirmed", MGQ_MpTrade::Items.receive_refusal(offer, "Friend"), "Friend's offer holds key items.")
offer = MGQ_MpTrade::Items.read_offer("g0;i77*1")
check("nor one with items this game lacks", MGQ_MpTrade::Items.receive_refusal(offer, "Friend"), "Friend's offer holds items your game does not know.")
offer = MGQ_MpTrade::Items.read_offer("g0;i1*98")
check("nor more than the bag can carry", MGQ_MpTrade::Items.receive_refusal(offer, "Friend"), "You cannot carry more Potion.")
check("counting what the own offer gives away", MGQ_MpTrade::Items.receive_refusal(offer, "Friend", MGQ_MpTrade::Items.read_offer("g0;i1*1")), nil)
offer = MGQ_MpTrade::Items.read_offer("g999999999")
check("and the gold it gives away", [MGQ_MpTrade::Items.receive_refusal(offer, "Friend"), MGQ_MpTrade::Items.receive_refusal(offer, "Friend", MGQ_MpTrade::Items.read_offer("g160"))],
      ["You cannot carry that much gold.", nil])
check("enchant stones may be traded", MGQ_MpTrade::Items.tradeable?(ruby), true)

# Enchanted copies.
sword = EnchantedSword.new(7)
sword.prefix = "Sharp"
$game_party.gain_item(sword, 1)
token = MGQ_MpTrade::Items.token(sword)
check("an enchanted copy is written with its data and its prefix's enchantment and place", token, "uew9.7~5p1")
copy = MGQ_MpTrade::Items.item_of(token)
check("and read back as a new copy with the same prefix", [copy.class, copy.rolls, copy.prefix], [EnchantedSword, 7, "Sharp"])
$data_classes[5] = Enchantment.new(["Nibui", "Surudoi"], ["Densetsu"])
check("which a game in another language names in its own", MGQ_MpTrade::Items.item_of(token).prefix, "Surudoi")
$data_classes[5] = Enchantment.new(["Dull", "Sharp"], ["Legendary"])
sword.prefix = "Legendary"
check("a rare prefix names its own list", MGQ_MpTrade::Items.token(sword), "uew9.7~5r0")
sword.prefix = "Sharp"
MGQ_MpTrade::Items.apply(MGQ_MpTrade::Items.read_offer("g0;#{token}*1"), MGQ_MpTrade::Items.read_offer("g0;uew9.8~*1"))
check("applying gives the own copy away and keeps the other's as the party's own",
      [$game_party.item_number(sword), $game_party.added.map(&:rolls), $game_party.weapons.select(&:uniq_item?).map(&:rolls)], [0, [8], [8]])


# Recovering a trade the relay committed, after a save was loaded that has the first trade.
$game_system = Game_System.new
$game_system.instance_variable_set(:@mgq_mp_trades, [relay_id])
$dll.clear
$saved.clear
$trade_ticks.clear
before = [$game_party.item_number(potion), $game_party.gold]
ticks
MGQ_Multiplayer::Bridge.frame
check("the DLL is told the save loaded, by which it asks the relay once per save", $trade_ticks.last.values_at("on_map", "save"), [true, $game_system.object_id])
from_dll("trade.recover", { "save" => $game_system.object_id, "trades" => [["a" * 32, "friend", "g0;i1*1", "g5;i1*1"], [relay_id, "friend", "g0;i1*3", "g60;w2*1"]] })
check("the trades the DLL found wait for the map's own frame",
      [[$game_party.item_number(potion), $game_party.gold], $dll.map(&:first), $saved], [before, [], []])
trade.on_map
check("where a trade the save lacks is applied, one it has only told the relay",
      [[$game_party.item_number(potion), $game_party.gold], $dll.map(&:first), $saved],
      [[before[0], before[1] + 5], ["trade.done", "trade.done"], [2]])
trade.on_map
check("and only once", $dll.size, 2)

# Trades to recover wait until the player is free on the map.
$game_system = Game_System.new
$dll.clear
$saved.clear
before = $game_party.gold
SceneManager.scene = Scene_Battle.new
from_dll("trade.recover", { "save" => $game_system.object_id, "trades" => [["d" * 32, "friend", "g0", "g7"]] })
trade.on_map
check("trades found in a battle apply and save nothing there", [$game_party.gold, $dll, $saved], [before, [], []])
SceneManager.scene = Scene_Map.new
$game_message.busy = true
trade.on_map
check("nor on the map while a message shows", [$game_party.gold, $dll, $saved], [before, [], []])
$game_message.busy = false
trade.on_map
check("but on the next frame the player is free on the map, saved once", [$game_party.gold, $dll.map(&:first), $saved], [before + 7, ["trade.done"], [2]])

# Trades to recover that wait while another save is loaded.
$dll.clear
$saved.clear
$game_message.busy = true
from_dll("trade.recover", { "save" => $game_system.object_id, "trades" => [["e" * 32, "friend", "g0", "g9"]] })
trade.on_map
$game_system = Game_System.new
$game_message.busy = false
trade.on_map
check("are dropped once another save was loaded, which the DLL asks the relay for anew", [$game_party.gold, $dll, $saved], [before + 7, [], []])

# Trades to recover that wait as the world closes.
$game_message.busy = true
from_dll("trade.recover", { "save" => $game_system.object_id, "trades" => [["f" * 32, "friend", "g0", "g4"]] })
trade.on_map
trade.tick(false)
$game_message.busy = false
trade.on_map
check("are forgotten once the world closed", [$game_party.gold, $dll, MGQ_MpTrade::Recovery.instance_variable_get(:@recovered)], [before + 7, [], nil])
DataManager.load_game_without_rescue(2)

# A trade that fails partway.
def $game_party.gain_item(item, amount, *rest)
  raise ArgumentError, "the bag broke" if $bag_breaks && amount > 0
  super
end
$bag_breaks = true
before = [$game_party.item_number(potion), $game_party.gold]
mine, theirs = MGQ_MpTrade::Items.read_offer("g10;i1*1"), MGQ_MpTrade::Items.read_offer("g0;w2*1")
results = [MGQ_MpTrade::Recovery.apply_once("c" * 32, mine, theirs), MGQ_MpTrade::Recovery.apply_once("c" * 32, mine, theirs)]
check("a trade that fails partway is applied once only",
      [results, [$game_party.item_number(potion), $game_party.gold]], [[false, true], [before[0] - 1, before[1] - 10]])
$bag_breaks = false


# A world made before the world list.
# A world without a directory id.
module MGQ_MpWorld; def self.world; World.new("f1", nil); end; end
check("a world made before the world list offers no trades",
      [trade.available?, MGQ_MpTrade::Offers.wheel_option.refusal], [false, "Trading is off in this world."])

# The save after a trade goes into a slot, never into an autosave, whose index is its name.
MGQ_MpTrade::Saving.slot = 2
MGQ_MpTrade::Saving.slot = "01"
check("loading an autosave forgets the slot a trade saves into instead of failing the load", MGQ_MpTrade::Saving.instance_variable_get(:@slot), nil)
