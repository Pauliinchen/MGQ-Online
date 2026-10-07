#----------------------------------------------------------------
#  trade_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Gave the world a folder id apart from its directory id, which the relay knows
#                            - Created
#
#----------------------------------------------------------------

# Covers trades, trade.rbx with the action wheel: offering and accepting a trade, both offers and
# their confirmations, the commit through the relay, applying a trade, the save after it, items
# that may not be traded, enchanted copies, and recovering a trade the relay committed. The DLL's
# trade functions stand in.

require_relative "world_support"

# Stand-ins for the game's items and party.
module RPG
  class BaseItem
    attr_reader :id, :name
    def initialize(id, name); @id, @name = id, name; end
    def uniq_item?; false; end
    def enchant_item?; false; end
  end
  class Item < BaseItem
    def initialize(id, name, key = false, stone = false); super(id, name); @key, @stone = key, stone; end
    def key_item?; @key; end
    def enchant_stone?; @stone; end
  end
  class Weapon < BaseItem; end
  class Armor < BaseItem; end
end

# An enchanted sword, which only one game has.
class EnchantedSword < RPG::Weapon
  attr_accessor :prefix
  def initialize(rolls); super(9, "Sword"); @rolls = rolls; @prefix = ""; end
  def uniq_item?; true; end
  def enchant_item?; true; end
  def rolls; @rolls; end
end

$data_items = [nil, RPG::Item.new(1, "Potion"), RPG::Item.new(2, "Royal Key", true), RPG::Item.new(3, "Ruby", false, true)]
$data_weapons = [nil, RPG::Weapon.new(1, "Club"), RPG::Weapon.new(2, "Spear")]
$data_armors = [nil, RPG::Armor.new(1, "Cap")]

class Game_Party
  attr_reader :gold, :added
  def initialize; @counts = Hash.new(0); @gold = 0; @added = []; end
  def max_gold; 999_999_999; end
  def item_number(item); @counts[item]; end
  def gain_item(item, amount, *); @counts[item] = [[@counts[item] + amount, 0].max, 99].min; @counts.delete(item) if @counts[item] == 0; end
  def lose_item(item, amount, *); gain_item(item, -amount); end
  def gain_gold(amount); @gold = [[@gold + amount, 0].max, max_gold].min; end
  def lose_gold(amount); gain_gold(-amount); end
  def add_item_data(item, number); @added << item; end
  def uniq_max_item_number(item); 2; end
  def uniq_item_number(item); @counts.keys.count { |held| held.uniq_item? && held.class == item.class }; end
  def held; @counts.keys; end
  def items; held.select { |item| item.is_a?(RPG::Item) }; end
  def weapons; held.select { |item| item.is_a?(RPG::Weapon) }; end
  def armors; held.select { |item| item.is_a?(RPG::Armor) }; end
end
class Game_System; end

module DataManager
  def self.savefile_max; 4; end
  def self.make_filename(index); "Save/Save#{index + 1}.rvdata2"; end
  def self.save_game(index); save_game_without_rescue(index); end
  def self.save_game_without_rescue(index); $saved << index; true; end
  def self.load_game_without_rescue(index); true; end
  def self.setup_new_game; end
end

# The enchanted copies' text, as core_actors.rbx writes them.
module MGQ_MpActors
  module Items
    def self.write(item); "ew9.#{item.rolls}"; end
    def self.read(text); text =~ /\Aew9\.(\d+)\z/ ? EnchantedSword.new($1.to_i) : nil; end
  end
end

# The DLL's trade functions.
module MGQ_Multiplayer
  def self.available?; true; end
  def self.outdated?; false; end
  module Link
    def self.function(name, _arguments)
      lambda { |*args| $dll << [name] + args.map { |arg| arg.to_s.chomp("\0") }; 1 }
    end
    def self.read(name, _size)
      name == "mp_trade_state" ? $relay_state : $pending_list
    end
  end
end
module MGQ_MpWorld; World = Struct.new(:id, :directory_id); def self.world; World.new("f1", "w1"); end; end
class Scene_MpTrade; end
module SceneManager; def self.call(scene); $called << scene; end; end

$dll = []
$saved = []
$called = []
$relay_state = ""
$pending_list = ""
$game_party = Game_Party.new
$game_system = Game_System.new

load_script "trade"

trade = MGQ_MpTrade
potion, key, ruby = $data_items[1], $data_items[2], $data_items[3]
spear = $data_weapons[2]
$game_party.gain_item(potion, 5)
$game_party.gain_item(key, 1)
$game_party.gain_gold(100)

# Reads the trade messages this game sent.
#
# @return [Array<Array>] Each one's seat and fields, its body under :payload.
def trade_sent
  $sent.map { |seat, text| [seat, MGQ_Multiplayer::Link.parse(text)] }.select { |_, fields| fields["trade"] }
end
# Lets the trade follow its frames, as the world does every frame.
#
# @param frames [Integer] How many.
def ticks(frames = 1); frames.times { MGQ_MpTrade.tick(true) }; end

friend = { "id" => "friend", "name" => "Friend", "sprite" => "Actor2", "index" => 0, "map" => 5, "x" => 4, "y" => 4, "d" => 2, "speed" => 4, "hidden" => 0, "scene" => "map" }
$inbox << entry("seat", 0) << entry("in", 2) << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
peer = MGQ_MpOverworldSync::Peers.at(2)
DataManager.load_game_without_rescue(2)

# The wheel and offering a trade.
check("the wheel's ring holds the trade after the duel's place, here the right", MGQ_MpActions.wheel_places, [:UP, :RIGHT, :DOWN, :LEFT])
check("someone near: trade offered", [MGQ_MpActions.wheel_options[:RIGHT].text, !MGQ_MpActions.wheel_options[:RIGHT].run.nil?], ["Trade", true])
MGQ_MpActions.wheel_options[:RIGHT].run.call
check("an offer is told, never as a field named trade, which marks trade messages", [MGQ_MpOverworldSync::Me.current["trading"], MGQ_MpOverworldSync::Me.current.key?("trade"), MGQ_MpActions.own_line], [1, false, "Offering a trade . . ."])
$inbox << entry("message", 2, told(friend.merge("map" => 6)))
MGQ_MpOverworldSync.tick
check("the overview offers no trade with a player on another map", MGQ_MpTrade::Offers.peer_option(peer).run, nil)
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick

# The other player accepts, and both open the trade.
$sent.clear
$inbox << entry("message", 2, "trade=accept\n\n")
MGQ_MpOverworldSync.tick
opened = trade_sent.last
check("an accepted offer opens the trade with an id", [opened[1]["trade"], opened[1]["tid"].to_s =~ /\A[0-9a-f]{24}\z/ ? true : false, trade.inviting?], ["open", true, false])
tid = opened[1]["tid"]
trade.on_map
check("the map opens the trade screen", $called, [Scene_MpTrade])

# Both offers.
$sent.clear
trade.set_amount(key, 1)
check("key items stay out of an offer", trade.session.mine.entries, [])
trade.set_amount(potion, 9)
check("an offer takes at most what the bag holds", trade.session.mine.entries.map(&:amount), [5])
trade.set_amount(potion, 3)
trade.set_gold(500)
check("and at most the party's gold", trade.session.mine.gold, 100)
trade.set_gold(0)
check("each change is told with its revision", trade_sent.map { |_, f| [f["trade"], f["rev"], f[:payload]] },
      [["offer", "1", "g0;i1*5"], ["offer", "2", "g0;i1*3"], ["offer", "3", "g100;i1*3"], ["offer", "4", "g0;i1*3"]])
$inbox << entry("message", 2, "trade=offer\ntid=#{tid}\nrev=1\n\ng50;w2*1")
MGQ_MpOverworldSync.tick
check("the other player's offer is read", [trade.session.theirs.gold, trade.session.theirs.entries.map { |e| [e.item, e.amount] }], [50, [[spear, 1]]])

# Confirming and committing.
$sent.clear
trade.toggle_confirm
check("confirming names both revisions", trade_sent.last[1].values_at("trade", "mine", "yours"), ["confirm", "4", "1"])
$inbox << entry("message", 2, "trade=offer\ntid=#{tid}\nrev=2\n\ng60;w2*1")
MGQ_MpOverworldSync.tick
check("a change of the other offer takes the confirmation back", trade.session.confirmed, false)
trade.toggle_confirm
$inbox << entry("message", 2, "trade=confirm\ntid=#{tid}\nmine=2\nyours=3\n\n")
MGQ_MpOverworldSync.tick
check("a confirmation of older offers does not commit", trade.session.stage, :open)
$dll.clear
$inbox << entry("message", 2, "trade=confirm\ntid=#{tid}\nmine=2\nyours=4\n\n")
MGQ_MpOverworldSync.tick
relay_id = tid + "0002" + "0004"
check("both confirmed: the offers go to the relay, ordered by player id", [trade.session.stage, $dll.last],
      [:committing, ["mp_trade_commit", "w1", relay_id, "friend", "friend=g60;w2*1|me=g0;i1*3"]])
check("the relay's id names the revisions, so a later confirmation is a trade of its own", relay_id.size, 32)
trade.set_amount(potion, 1)
check("nothing changes while the relay decides", trade.session.mine.entries.map(&:amount), [3])

# The relay commits.
$relay_state = "trade=#{relay_id}\nstate=committed"
ticks(MGQ_MpTrade::POLL_FRAMES)
check("the trade moves the items and gold", [$game_party.item_number(potion), $game_party.item_number(spear), $game_party.gold], [2, 1, 160])
check("the save notes it, saves into the slot loaded last and tells the relay",
      [$game_system.instance_variable_get(:@mgq_mp_trades), $saved, $dll.last], [[relay_id], [2], ["mp_trade_done", "w1", relay_id]])
check("the trade ends with a notice", [trade.session, MGQ_MpOverworldSync::Status.lines.last], [nil, "Trade with Friend complete, game saved."])

# What may not be taken.
offer = MGQ_MpTrade::Items.read_offer("g0;i2*1")
check("an offer with key items cannot be confirmed", MGQ_MpTrade::Items.receive_refusal(offer, "Friend"), "Friend's offer holds key items.")
offer = MGQ_MpTrade::Items.read_offer("g0;i77*1")
check("nor one with items this game lacks", MGQ_MpTrade::Items.receive_refusal(offer, "Friend"), "Friend's offer holds items your game does not know.")
offer = MGQ_MpTrade::Items.read_offer("g0;i1*98")
check("nor more than the bag can carry", MGQ_MpTrade::Items.receive_refusal(offer, "Friend"), "You cannot carry more Potion.")
check("enchant stones may be traded", MGQ_MpTrade::Items.tradeable?(ruby), true)

# Enchanted copies.
sword = EnchantedSword.new(7)
sword.prefix = "Sharp"
$game_party.gain_item(sword, 1)
token = MGQ_MpTrade::Items.token(sword)
check("an enchanted copy is written with its data and its prefix", token, "uew9.7~5368617270")
copy = MGQ_MpTrade::Items.item_of(token)
check("and read back as a new copy with the same prefix", [copy.class, copy.rolls, copy.prefix], [EnchantedSword, 7, "Sharp"])
MGQ_MpTrade::Items.apply(MGQ_MpTrade::Items.read_offer("g0;#{token}*1"), MGQ_MpTrade::Items.read_offer("g0;uew9.8~*1"))
check("applying gives the own copy away and keeps the other's as the party's own",
      [$game_party.item_number(sword), $game_party.added.map(&:rolls), $game_party.weapons.select(&:uniq_item?).map(&:rolls)], [0, [8], [8]])

# Declining, leaving, and a relay that turns the commit down.
trade.invite
$sent.clear
$inbox << entry("message", 2, "trade=accept\n\n")
MGQ_MpOverworldSync.tick
tid = trade_sent.last[1]["tid"]
$inbox << entry("message", 2, "trade=cancel\ntid=#{tid}\nreason=off\n\n")
MGQ_MpOverworldSync.tick
check("the other player cancels", [trade.session, MGQ_MpOverworldSync::Status.lines.last], [nil, "Friend cancelled the trade."])
trade.invite
$sent.clear
$inbox << entry("message", 2, "trade=accept\n\n")
MGQ_MpOverworldSync.tick
tid = trade_sent.last[1]["tid"]
trade.set_amount(potion, 1)
trade.toggle_confirm
$inbox << entry("message", 2, "trade=confirm\ntid=#{tid}\nmine=0\nyours=1\n\n")
MGQ_MpOverworldSync.tick
$relay_state = "trade=#{trade.session.relay_id}\nstate=cancelled\nreason=expired"
ticks(MGQ_MpTrade::POLL_FRAMES)
check("an expired commit opens the trade again, unconfirmed",
      [trade.session.stage, trade.session.confirmed, MGQ_MpOverworldSync::Status.lines.last], [:open, false, "The trade timed out before both games confirmed it."])
$inbox << entry("out", 2)
MGQ_MpOverworldSync.tick
ticks(MGQ_MpTrade::AWAY_FRAMES + 1)
check("a player gone longer than the rejoin time ends the trade", [trade.session, MGQ_MpOverworldSync::Status.lines.last], [nil, "Friend left."])

# Recovering a trade the relay committed, after a save was loaded that has the first trade.
$game_system = Game_System.new
$game_system.instance_variable_set(:@mgq_mp_trades, [relay_id])
$dll.clear
$saved.clear
before = [$game_party.item_number(potion), $game_party.gold]
$pending_list = "state=busy\n\n"
ticks
check("the map asks the relay for trades to recover once per save", $dll.map(&:first), ["mp_trade_pending"])
$pending_list = "state=done\n\ntrade=#{'a' * 32}\tfriend=g5;i1*1|me=g0;i1*1\ntrade=#{relay_id}\tfriend=g60;w2*1|me=g0;i1*3"
ticks
check("a trade the save lacks is applied, one it has only told the relay",
      [[$game_party.item_number(potion), $game_party.gold], $dll.map(&:first), $saved],
      [[before[0], before[1] + 5], ["mp_trade_pending", "mp_trade_done", "mp_trade_done"], [2]])
ticks
check("and the relay is not asked again for the same save", $dll.size, 3)
