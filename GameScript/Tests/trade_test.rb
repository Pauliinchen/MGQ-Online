#----------------------------------------------------------------
#  trade_test.rb
#
#  Changelog:
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

# Covers trades, trade.rbx with the action wheel: offering and accepting a trade, both offers and
# their confirmations, the commit through the relay, applying a trade, the save after it, items
# that may not be traded, enchanted copies, and recovering a trade the relay committed. The DLL's
# trade functions stand in.

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

# The DLL's trade functions.
module MGQ_Multiplayer
  # The DLL is always there.
  def self.available?; true; end
  # The game is never outdated.
  def self.outdated?; false; end
  # The link to the DLL: each call is checked against its signature and recorded in $dll.
  module Link
    # A DLL function whose calls are checked, recorded in $dll and answered with 1.
    #
    # @param name [String] The export.
    # @return [Proc] The function.
    def self.function(name)
      lambda do |*args|
        check_dll_call(name, args)
        $dll << [name] + args.map { |arg| arg.to_s.chomp("\0") }
        1
      end
    end
    # The relay's answer about a trade from $relay_state, and the trades to recover from $pending_list.
    #
    # @param name [String] The export.
    # @param _size [Integer] The buffer's size.
    # @return [String] The answer.
    def self.read(name, _size)
      name == "mp_trade_state" ? $relay_state : $pending_list
    end
  end
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
$relay_state = ""
$pending_list = "state=done\n\n"
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
check("the wheel's ring holds the trade after the duel's place, here the right", MGQ_MpActions.wheel_places, [:UP, :RIGHT, :DOWN, :LEFT])
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

# The other player accepts, and both open the trade.
$sent.clear
$inbox << entry("message", 2, "trade=accept\n\n")
MGQ_MpOverworldSync.tick
opened = trade_sent.last
check("an accepted offer opens the trade with an id", [opened[1]["trade"], opened[1]["tid"].to_s =~ /\A[0-9a-f]{24}\z/ ? true : false, trade.inviting?, trade.own_doing], ["open", true, false, nil])
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
trade.accept(peer)
check("accepting a trade stops the player's own offer and waits for the trade above the player's head, six seconds at most",
      [trade.inviting?, doing_shown], [false, "Waiting for Friend's trade (6 s)"])
ticks(2 * 60)
check("counting them down", doing_shown, "Waiting for Friend's trade (4 s)")
SceneManager.scene = Scene_Item.new
$sent.clear
$inbox << entry("message", 2, "trade=open\ntid=#{'b' * 24}\n\n")
MGQ_MpOverworldSync.tick
check("a trade the player accepted but cannot open now, here in the menu, is turned down with a notice",
      [trade.session, trade_sent.map { |_, f| [f["trade"], f["reason"]] }, MGQ_MpOverworldSync::Status.lines.last],
      [nil, [["decline", "busy"]], "The trade with Friend could not open: finish what you are doing first."])
check("which ends the wait above the player's head", trade.own_doing, nil)
SceneManager.scene = Scene_Map.new
trade.accept(peer)
$sent.clear
$inbox << entry("message", 2, "trade=open\ntid=not-an-id\n\n")
MGQ_MpOverworldSync.tick
check("a trade id that is not valid is turned down as invalid, telling the player only that it could not open",
      [trade.session, trade_sent.map { |_, f| [f["trade"], f["reason"]] }, MGQ_MpOverworldSync::Status.lines.last],
      [nil, [["decline", "invalid"]], "The trade with Friend could not open."])
trade.invite
$inbox << entry("message", 2, "trade=accept\n\n")
MGQ_MpOverworldSync.tick
tid = trade_sent.last[1]["tid"]
$inbox << entry("message", 2, "trade=decline\ntid=#{tid}\nreason=invalid\n\n")
MGQ_MpOverworldSync.tick
check("the player who offered it sees that the trade could not open, not that the other is busy",
      [trade.session, MGQ_MpOverworldSync::Status.lines.last], [nil, "The trade could not open."])
$inbox << entry("message", 2, "trade=decline\nreason=newer\n\n")
MGQ_MpOverworldSync.tick
check("a reason of another build says the other player cannot trade now", MGQ_MpOverworldSync::Status.lines.last, "Friend cannot trade now.")
trade.invite
$sent.clear
$inbox << entry("message", 2, "trade=accept\n\n")
MGQ_MpOverworldSync.tick
tid = trade_sent.last[1]["tid"]
trade.set_amount(potion, 1)
trade.toggle_confirm
$inbox << entry("message", 2, "trade=confirm\ntid=#{tid}\nmine=0\nyours=1\n\n")
MGQ_MpOverworldSync.tick
expired_id = trade.session.relay_id
$relay_state = "trade=#{expired_id}\nstate=cancelled\nreason=expired"
$sent.clear
ticks(MGQ_MpTrade::POLL_FRAMES)
check("an expired commit opens the trade again, unconfirmed",
      [trade.session.stage, trade.session.confirmed, MGQ_MpOverworldSync::Status.lines.last], [:open, false, "The trade timed out before both games confirmed it."])
check("and tells the own offer again under a new revision", trade_sent.map { |_, f| [f["trade"], f["rev"]] }, [["offer", "2"]])
trade.toggle_confirm
$inbox << entry("message", 2, "trade=confirm\ntid=#{tid}\nmine=0\nyours=2\n\n")
MGQ_MpOverworldSync.tick
check("so confirming again names a trade of its own at the relay", [trade.session.stage, trade.session.relay_id == expired_id], [:committing, false])
$relay_state = "trade=#{trade.session.relay_id}\nstate=cancelled\nreason=cancelled"
ticks(MGQ_MpTrade::POLL_FRAMES)
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
check("the relay's answer waits for the map's own frame",
      [[$game_party.item_number(potion), $game_party.gold], $dll.map(&:first), $saved], [before, ["mp_trade_pending"], []])
trade.on_map
check("where a trade the save lacks is applied, one it has only told the relay",
      [[$game_party.item_number(potion), $game_party.gold], $dll.map(&:first), $saved],
      [[before[0], before[1] + 5], ["mp_trade_pending", "mp_trade_done", "mp_trade_done"], [2]])
ticks
trade.on_map
check("and the relay is not asked again for the same save", $dll.size, 3)

# Trades to recover wait until the player is free on the map.
$game_system = Game_System.new
$dll.clear
$saved.clear
before = $game_party.gold
$pending_list = "state=busy\n\n"
ticks
SceneManager.scene = Scene_Battle.new
$pending_list = "state=done\n\ntrade=#{'d' * 32}\tfriend=g7|me=g0"
ticks(3)
trade.on_map
check("an answer that comes in a battle applies and saves nothing there", [$game_party.gold, $dll.map(&:first), $saved], [before, ["mp_trade_pending"], []])
SceneManager.scene = Scene_Map.new
$game_message.busy = true
ticks
trade.on_map
check("nor on the map while a message shows", [$game_party.gold, $dll.map(&:first), $saved], [before, ["mp_trade_pending"], []])
$game_message.busy = false
trade.on_map
check("but on the next frame the player is free on the map, saved once",
      [$game_party.gold, $dll.map(&:first), $saved], [before + 7, ["mp_trade_pending", "mp_trade_done"], [2]])
trade.on_map
check("and only once", [$game_party.gold, $dll.size, $saved], [before + 7, 2, [2]])

# Trades to recover that wait while another save is loaded.
$game_system = Game_System.new
$dll.clear
$saved.clear
$pending_list = "state=done\n\ntrade=#{'e' * 32}\tfriend=g9|me=g0"
$game_message.busy = true
ticks(2)
trade.on_map
$game_system = Game_System.new
$game_message.busy = false
trade.on_map
check("are dropped once another save was loaded", [$game_party.gold, $dll.map(&:first), $saved], [before + 7, ["mp_trade_pending"], []])
ticks(2)
trade.on_map
check("and the relay is asked again for the new save, whose trades then apply",
      [$game_party.gold, $dll.map(&:first), $saved], [before + 16, ["mp_trade_pending", "mp_trade_pending", "mp_trade_done"], [2]])

# Trades to recover that wait as the world closes.
$game_system = Game_System.new
$dll.clear
$pending_list = "state=done\n\ntrade=#{'f' * 32}\tfriend=g4|me=g0"
$game_message.busy = true
ticks(2)
trade.on_map
trade.tick(false)
$game_message.busy = false
trade.on_map
check("are forgotten once the world closed", [$game_party.gold, $dll.map(&:first), MGQ_MpTrade::Recovery.instance_variable_get(:@recovered)], [before + 16, ["mp_trade_pending"], nil])
DataManager.load_game_without_rescue(2)
$pending_list = "state=done\n\n"
ticks(2)

# Opens a trade the other player accepted, offers a potion, and has both confirm it, which commits it.
#
# @return [String] The trade's id at the relay.
def committed_trade
  MGQ_MpTrade.invite
  $sent.clear
  $inbox << entry("message", 2, "trade=accept\n\n")
  MGQ_MpOverworldSync.tick
  tid = trade_sent.last[1]["tid"]
  MGQ_MpTrade.set_amount($data_items[1], 1)
  MGQ_MpTrade.toggle_confirm
  $inbox << entry("message", 2, "trade=confirm\ntid=#{tid}\nmine=0\nyours=#{MGQ_MpTrade.session.my_rev}\n\n")
  MGQ_MpOverworldSync.tick
  $dll.clear
  $sent.clear
  MGQ_MpTrade.session.relay_id
end

# Cancels while the relay decides.
$pending_list = "state=done\n\n"
$inbox << entry("in", 2) << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
id = committed_trade
trade.cancel
check("a cancel while the relay decides tells the other player and the relay, and waits for its answer",
      [trade_sent.last[1].values_at("trade", "reason"), $dll.map(&:first), trade.session.stage], [["cancel", "off"], ["mp_trade_cancel"], :committing])
$relay_state = "trade=#{id}\nstate=cancelled\nreason=cancelled"
ticks(MGQ_MpTrade::POLL_FRAMES)
check("which ends the trade instead of opening it again", [trade.session, MGQ_MpOverworldSync::Status.lines.last], [nil, "You cancelled the trade."])
id = committed_trade
$inbox << entry("message", 2, "trade=cancel\ntid=#{trade.session.id}\nreason=off\n\n")
MGQ_MpOverworldSync.tick
check("the other player's cancel while the relay decides cancels the commit there", [trade.session.leaving, $dll.map(&:first)], ["Friend cancelled the trade.", ["mp_trade_cancel"]])
$relay_state = "trade=#{id}\nstate=cancelled\nreason=cancelled"
ticks(MGQ_MpTrade::POLL_FRAMES)
check("and ends the trade once the relay cancelled it", [trade.session, MGQ_MpOverworldSync::Status.lines.last], [nil, "Friend cancelled the trade."])
id = committed_trade
$relay_state = "trade=#{id}\nstate=failed\nerror=The relay could not be reached."
ticks(MGQ_MpTrade::POLL_FRAMES)
check("a failed commit is cancelled at the relay and told to the other player",
      [$dll.map(&:first) - ["mp_trade_pending"], trade_sent.last[1].values_at("trade", "reason"), trade.session], [["mp_trade_cancel"], ["cancel", "relay"], nil])

# A trade the save cannot hold.
ticks
id = committed_trade
$save_fails = true
$relay_state = "trade=#{id}\nstate=committed"
ticks(MGQ_MpTrade::POLL_FRAMES)
check("a trade the save could not hold stays undone at the relay",
      [$dll.map(&:first), MGQ_MpOverworldSync::Status.lines.last], [[], "Trade with Friend complete. Save your game, the trade could not."])
$save_fails = false
DataManager.save_game(1)
check("until the next save in the world holds it", $dll.map(&:first), ["mp_trade_done"])

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

# Asking the relay again after a failed fetch.
$game_system = Game_System.new
$pending_list = "state=failed\nerror=The relay could not be reached.\n\n"
$dll.clear
ticks(2)
ticks(MGQ_MpTrade::RETRY_FRAMES)
check("a failed fetch is asked again later", $dll.map(&:first), ["mp_trade_pending", "mp_trade_pending"])
$pending_list = "state=done\n\n"
ticks

# Messages for the trade screen, which the map's notices do not reach.
trade.invite
$sent.clear
$inbox << entry("message", 2, "trade=accept\n\n")
MGQ_MpOverworldSync.tick
trade.toggle_confirm
check("a refused confirmation is kept for the trade screen", trade.note, "Both offers are empty.")
ticks(MGQ_MpTrade::NOTE_FRAMES)
check("for a few seconds", trade.note, nil)
trade.toggle_confirm
trade.cancel
check("and forgotten once the trade ends", trade.note, nil)

# The other player away and back while the trade is open: what may have been lost goes out again.

# Opens a trade the other player accepted.
#
# @return [String] The trade's id.
def opened_trade
  MGQ_MpTrade.invite
  $sent.clear
  $inbox << entry("message", 2, "trade=accept\n\n")
  MGQ_MpOverworldSync.tick
  trade_sent.last[1]["tid"]
end
# Has the other player's connection drop for a moment, then come back.
#
# @param state [Hash] Their state as they tell it once back.
def away_and_back(state)
  $inbox << entry("out", 2)
  MGQ_MpOverworldSync.tick
  ticks(30)
  $sent.clear
  $inbox << entry("in", 2) << entry("message", 2, told(state))
  MGQ_MpOverworldSync.tick
  ticks
end
# The trade messages sent, as kind, revision, confirmed revisions and payload.
resent = lambda { trade_sent.map { |_, f| f.values_at("trade", "rev", "mine", "yours", :payload) } }
$game_party.gain_item(potion, 1)
tid = opened_trade
trade.set_amount(potion, 1)
trade.toggle_confirm
away_and_back(friend)
check("the other player back, the last offer and the confirmation go out again",
      resent.call, [["offer", "1", nil, nil, "g0;i1*1"], ["confirm", nil, "1", "0", ""]])
trade.toggle_confirm
away_and_back(friend)
check("unconfirmed, the confirmation taken back goes out again", resent.call, [["offer", "1", nil, nil, "g0;i1*1"], ["unconfirm", nil, nil, nil, ""]])
# Sends that fail while $send_fails.
module MGQ_MpOverworldSync::Link; def self.send_to(target, text); $sent << [target, text]; !$send_fails; end; end
$send_fails = true
lines = logged_lines { trade.set_amount(potion, 0) }
check("a message that cannot go out is logged so, not as sent",
      [lines.grep(/could not send offer to Friend/).size, lines.grep(/sent offer/).size], [1, 0])
$send_fails = false
trade.cancel
id = committed_trade
away_and_back(friend)
check("nothing goes out again while the relay decides", trade_sent, [])
$relay_state = "trade=#{id}\nstate=cancelled\nreason=cancelled"
trade.cancel
ticks(MGQ_MpTrade::POLL_FRAMES)

# Messages that could not go out go out again once messages do.
tid = opened_trade
trade.set_amount(potion, 1)
trade.instance_variable_set(:@poll, 0)
$send_fails = true
lines = logged_lines { trade.toggle_confirm; ticks(MGQ_MpTrade::POLL_FRAMES * 3) }
check("a confirm that cannot go out marks the trade, whose tries to send again log their messages only the first time",
      [trade.session.unsent, lines.grep(/go out again once messages to Friend do/).size, lines.grep(/could not send confirm/).size], [3, 1, 2])
$send_fails = false
$sent.clear
ticks(MGQ_MpTrade::POLL_FRAMES - 1)
check("the next try waits for the relay's beat", trade_sent, [])
lines = logged_lines { ticks }
check("then the last offer and the confirmation go out again and the mark is cleared",
      [resent.call, trade.session.unsent, lines.grep(/again: messages to Friend go out again after 4 tries/).size],
      [[["offer", "1", nil, nil, "g0;i1*1"], ["confirm", nil, "1", "0", ""]], nil, 1])
$sent.clear
ticks(MGQ_MpTrade::POLL_FRAMES * 2)
check("and nothing more goes out once they did", trade_sent, [])
$send_fails = true
trade.toggle_confirm
$send_fails = false
$sent.clear
ticks(MGQ_MpTrade::POLL_FRAMES)
check("a lost unconfirm goes out again, at the first try that works", [resent.call, trade.session.unsent],
      [[["offer", "1", nil, nil, "g0;i1*1"], ["unconfirm", nil, nil, nil, ""]], nil])
$send_fails = true
trade.set_amount(potion, 0)
$send_fails = false
away_and_back(friend)
check("the other player back clears the mark once the offer and confirmation state went out",
      [resent.call, trade.session.unsent], [[["offer", "2", nil, nil, "g0"], ["unconfirm", nil, nil, nil, ""]], nil])
trade.cancel
$send_fails = true
id = committed_trade
check("a confirm that could not go out while the relay decides on it", [trade.session.stage, trade.session.unsent], [:committing, 0])
$send_fails = false
$sent.clear
ticks(MGQ_MpTrade::POLL_FRAMES * 2)
check("is not tried again before the relay answers", trade_sent, [])
$relay_state = "trade=#{id}\nstate=cancelled\nreason=cancelled"
trade.cancel
ticks(MGQ_MpTrade::POLL_FRAMES)

# Messages of a trade the game does not have.
$sent.clear
$inbox << entry("message", 2, "trade=offer\ntid=#{'c' * 24}\nrev=3\n\ng10")
MGQ_MpOverworldSync.tick
check("an offer of a trade the game does not have is answered with a cancel",
      trade_sent.map { |seat, f| [seat, f.values_at("trade", "tid", "reason")] }, [[2, ["cancel", "c" * 24, "off"]]])
$sent.clear
$inbox << entry("message", 2, "trade=cancel\ntid=#{'c' * 24}\nreason=off\n\n")
MGQ_MpOverworldSync.tick
check("but a cancel is never answered, so two games never answer each other", trade_sent, [])
tid = opened_trade
$sent.clear
$inbox << entry("message", 2, "trade=confirm\ntid=#{'d' * 24}\nmine=1\nyours=0\n\n")
MGQ_MpOverworldSync.tick
check("as is a confirm of an older trade while another runs, which stays open",
      [trade_sent.map { |_, f| f.values_at("trade", "tid") }, trade.session.id], [[["cancel", "d" * 24]], tid])

# Offers too long for the relay.
many = lambda { |count| "g0" + ";w2*1" * count }
$sent.clear
trade.set_amount(potion, 1)
$inbox << entry("message", 2, "trade=offer\ntid=#{tid}\nrev=1\n\n#{many.call(6550)}")
MGQ_MpOverworldSync.tick
$dll.clear
trade.toggle_confirm
check("offers longer than the relay takes cannot be confirmed, the player told to take some out",
      [trade.agreed_text(trade.session).bytesize > MGQ_MpTrade::MAX_OFFERS_BYTES, trade.session.confirmed, trade.note, $dll],
      [true, false, "The offers hold too many items for one trade. Take some out.", []])
$inbox << entry("message", 2, "trade=offer\ntid=#{tid}\nrev=2\n\n#{many.call(6549)}")
MGQ_MpOverworldSync.tick
trade.toggle_confirm
$inbox << entry("message", 2, "trade=confirm\ntid=#{tid}\nmine=2\nyours=1\n\n")
MGQ_MpOverworldSync.tick
check("offers just short of it still go to the relay",
      [trade.agreed_text(trade.session).bytesize, trade.session.stage, $dll.map(&:first)], [MGQ_MpTrade::MAX_OFFERS_BYTES - 3, :committing, ["mp_trade_commit"]])
$relay_state = "trade=#{trade.session.relay_id}\nstate=cancelled\nreason=cancelled"
trade.cancel
ticks(MGQ_MpTrade::POLL_FRAMES)

# A world made before the world list.
# A world without a directory id.
module MGQ_MpWorld; def self.world; World.new("f1", nil); end; end
check("a world made before the world list offers no trades",
      [trade.available?, MGQ_MpTrade::Offers.wheel_option.refusal], [false, "This world was made before the world list, so it cannot trade."])

# The save after a trade goes into a slot, never into an autosave, whose index is its name.
MGQ_MpTrade::Saving.slot = 2
MGQ_MpTrade::Saving.slot = "01"
check("loading an autosave forgets the slot a trade saves into instead of failing the load", MGQ_MpTrade::Saving.instance_variable_get(:@slot), nil)
