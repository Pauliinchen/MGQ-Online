#----------------------------------------------------------------
#  story_found_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Covered a key item an event used up leaving every player who holds it, with the Yggdrasil Fruit the Queen Harpy takes
#                            - Kept the party from holding less than none of an item, as the game does
#                            - Checked that a story reset uses up no key item
#                            - Created
#
#----------------------------------------------------------------

# Covers story_found.rbx in a Classic party, over the DLL's topic (MGQOnline.Game.Tests covers its
# rule): a key item a member found reaches the player once and its next gain adds none, what the
# player finds goes to the party, a Small Medal not, a member who joins hears what the player found,
# a key item the leader only lends counts for nothing, a key item an event of a member's game used
# up leaves every player who holds it, and a story reset uses none up.

require_relative "support"
require_relative "bridge_support"

$log = []
# Stands in for the mod's log, keeping its lines in $log.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end
# Stands in for RGSS graphics, whose frame count is $frame_count.
module Graphics; def self.frame_count; $frame_count; end; end
# An item of the database, a key item or not, with its description.
module RPG; class Item < Struct.new(:id, :name, :key, :description); def key_item?; key == true; end; end; end
$data_items = []
$data_items[32] = RPG::Item.new(32, "Small Medal", true, "[Item] Small medals are scattered all over the world.")
$data_items[151] = RPG::Item.new(151, "Lump of Iron", true, "[Material] Common metal that can be forged into many armaments.")
$data_items[503] = RPG::Item.new(503, "Soldier's Key", true, "[Key Item] Opens a chest in the Cave of Trials.")
$data_items[1801] = RPG::Item.new(1801, "CD: Beginning of the Adventure", true, "[CD] Music CD containing 6 songs.")
$data_items[502] = RPG::Item.new(502, "Storehouse Key", true)
$data_items[610] = RPG::Item.new(610, "Fortune Teller Permit", true)
$data_items[600] = RPG::Item.new(600, "Herb", false)
$data_items[568] = RPG::Item.new(568, "Warp Stone", true, "[Key Item] Teleports to a place.")
$data_items[508] = RPG::Item.new(508, "Yggdrasil Fruit", true, "[Key Item] Miraculous medicine capable of purging all diseases.")
# Stands in for the system, which the save keeps.
class Game_System; end
# Stands in for the party: items by id.
class Game_Party
  def initialize; @items = Hash.new(0); end
  def gain_item(item, amount); @items[item.id] = [@items[item.id] + amount, 0].max; end
  def lose_item(item, amount); gain_item(item, -amount); end
  def item_number(item); @items[item.id]; end
end
# Stands in for the map, which updates each frame.
class Game_Map; def update(_main = false); end; end
# Stands in for the save's loading and a new game.
module DataManager; def self.setup_new_game; end; def self.load_game_without_rescue(_index); end; end
# A member of the world as the sync knows them.
Peer = Struct.new(:state)
# Stands in for the world: the notices kept in $notices.
module MGQ_MpOverworldSync; def self.who(peer); peer.state["name"]; end; def self.notice(text, _icon = nil); $notices << text; end; end
# Stands in for the party of a Classic world: its members in $members, the messages told kept in
# $told and the routes of the found and used up items in $routes by field.
module MGQ_MpCoop
  def self.in_party?; true; end
  def self.tell(seat, field, value, fields); $told << [seat, field, value, fields]; true; end
  def self.route(field, &handler); ($routes ||= {})[field] = handler; end
  module Scope; def self.raid?; false; end; end
  module Party; def self.members; $members; end; end
end
# Stands in for the replayer: a replay runs while $replaying is set, and the player stands free.
module MGQ_MpStoryReplay; def self.running?; $replaying ? true : false; end; def self.free?; true; end; end
# Stands in for the story's keys: the commands of an event running now in $place, nil outside every
# event, inside a story reset while $resetting is set.
module MGQ_MpStoryKeys; def self.command_places; $place; end; def self.applying?; false; end; def self.resetting?; $resetting ? true : false; end; end
# Stands in for the party's story: the key items the leader lent, by id, in $lent.
module MGQ_MpCoopStory
  def self.lending?; @lending ? true : false; end
  def self.lent_count(id); $lent[id].to_i; end
  def self.lend(item, amount); @lending = true; $game_party.gain_item(item, amount); ensure @lending = false; end
end

load_script "story_found"

fake = FakeBridge.new
MGQ_Multiplayer::Bridge.open(fake)
$asked = []
fake.answer("found.check") do |request|
  $asked << request
  held = request["held"].dup
  spent = request["spent"].dup
  take = []
  request["used"].sort.each do |use|
    next if spent.include?(use)

    spent << use
    next unless held[use.to_i].to_i > 0

    take << use.to_i
    held[use.to_i] -= 1
  end
  used = request["used"].map { |use| use.to_i }
  give = request["found"].select { |id| held[id] == 0 && !request["got"].include?(id) && !used.include?(id) }
  { "give" => give, "trim" => [], "take" => take, "spent" => spent.sort,
    "got" => (request["got"] | request["held"].keys.select { |id| request["held"][id] > 0 } | give).sort }
end
found = lambda { |peer, ids| $routes["found"].call(peer, "found" => 1, "ids" => ids) }
used = lambda { |peer, uses| $routes["used"].call(peer, "used" => 1, "uses" => uses) }
look = lambda { $frame_count += 60; MGQ_MpStoryFound.update }

ana = Peer.new({ "id" => "a1", "name" => "Ana" })
$frame_count = 1000
$game_system = Game_System.new
$game_party = Game_Party.new
$members = [ana]
$told = []
$notices = []
$lent = {}

# The player joins Ana's party: the first look tells Ana what the player found, nothing yet.
MGQ_MpStoryFound.update
check("the first look in a party tells nothing while the player found nothing", $told, [])

# Ana found the Fortune Teller Permit: the player, who never held one, gets it once, with a notice.
found.call(ana, "610")
MGQ_MpStoryFound.update
check("a key item a member found reaches the player who never held it, with a notice naming the member",
      [$game_party.item_number($data_items[610]), $notices], [1, ["Ana found Fortune Teller Permit, and you got it too."]])
$game_party.gain_item($data_items[610], 1)
check("the player's own run of the event that gives it gives no second one", $game_party.item_number($data_items[610]), 1)
$game_party.lose_item($data_items[610], 1)
$frame_count += 60
MGQ_MpStoryFound.update
check("one the player held once stays away after an event took it", $game_party.item_number($data_items[610]), 0)

# What the player gains goes to the party, a key item only, ores and CDs among them, Small Medals
# not; a lent key item counts for nothing.
$told.clear
[502, 151, 1801, 32, 600].each { |id| $game_party.gain_item($data_items[id], 1) }
check("a key item, an ore and a CD the player gains go to the party, a Small Medal and another item not",
      $told.map { |told| told[3]["ids"] }, %w(502 151 1801))
$told.clear
$game_party.gain_item($data_items[502], 1)
check("one the party heard of already goes to the party no second time", $told, [])
$told.clear
MGQ_MpCoopStory.lend($data_items[503], 1)
$lent[503] = 1
check("a key item the leader lends goes nowhere", $told, [])
$frame_count += 60
MGQ_MpStoryFound.update
check("and counts as no item the player held, nor does a Small Medal", [$asked.last["got"] & [503, 32], $asked.last["held"].key?(32)], [[], false])

# A member who joins hears everything the player found.
cara = Peer.new({ "id" => "c3", "name" => "Cara" })
$members = [ana, cara]
$frame_count += 60
MGQ_MpStoryFound.update
check("a member who joins hears every item the player found or held", $told.find { |told| told[1] == "found" }[3]["ids"].split(",").map { |id| id.to_i }.sort, [151, 502, 610, 1801])

# The Queen Harpy event takes the Yggdrasil Fruit (map 88, event 4, page 1, command 63) that Nero
# gave (map 340, event 23): the player's game tells the party the use once, and only while an
# event of their own game takes a copy they hold.
fruit = $data_items[508]
$told.clear
$game_party.gain_item(fruit, 1)
$told.clear
$place = "map:88:4:1@63"
$game_party.lose_item(fruit, 1)
uses = $told.select { |told| told[1] == "used" }.map { |told| told[3]["uses"] }
$game_party.lose_item(fruit, 1)
check("an event of the player's that uses up a key item tells the party one use of it, and one that takes none tells nothing",
      [uses.size, uses.first.to_s =~ /\A508\.U[0-9a-z]+\z/ ? true : false, $told.size], [1, true, 1])
harpy = uses.first
$told.clear
$game_party.gain_item(fruit, 1)
$told.clear
$replaying = true
$game_party.lose_item(fruit, 1)
$replaying = false
$place = nil
$game_party.gain_item(fruit, 1)
$game_party.lose_item(fruit, 1)
$place = "map:88:4:1@63"
$game_party.gain_item($data_items[32], 2)
$game_party.lose_item($data_items[32], 1)
$game_party.gain_item($data_items[600], 2)
$game_party.lose_item($data_items[600], 1)
check("a replay's loss, a loss outside every event, a Small Medal and another item tell nothing", $told, [])
$game_party.gain_item(fruit, 1)
$game_party.lose_item(fruit, 1)
second = $told.last[3]["uses"]
check("the same event using it up a second time is a use of its own", [second =~ /\A508\.U/ ? true : false, second == harpy], [true, false])

# A member got the Yggdrasil Fruit from Ana's find, and Ana gave hers to the Queen Harpy: the
# member loses it too, so Lucretia's page (map 88, event 4, page 2, which takes a held Yggdrasil
# Fruit and adds Lucretia, actor 323) stays shut until the next one comes.
$place = nil
$game_system = Game_System.new
$game_party = Game_Party.new
$told.clear
$notices.clear
found.call(ana, "508")
look.call
got = $game_party.item_number(fruit)
used.call(ana, harpy)
look.call
check("a member who got the Yggdrasil Fruit from another player's find loses it once that player's event used it up, with a notice",
      [got, $game_party.item_number(fruit), $notices.last], [1, 0, "Ana used up Yggdrasil Fruit, and yours is gone too."])
lucretia = $game_party.item_number(fruit) > 0
check("so Lucretia's page, which asks for a held Yggdrasil Fruit, does not open early", lucretia, false)
$place = "map:88:4:1@63"
$game_party.lose_item(fruit, 1)
$place = nil
check("the member's own run of the Queen Harpy event, holding none, takes and tells nothing", [$game_party.item_number(fruit), $told], [0, []])
$game_party.gain_item(fruit, 1)
look.call
check("the next Yggdrasil Fruit the member gets comes whole and stays", $game_party.item_number(fruit), 1)
used.call(ana, second)
look.call
look.call
check("a later use by an event of Ana's takes that one too, once", [$game_party.item_number(fruit), $asked.last["spent"].sort], [0, [harpy, second].sort])

# A player who lacks a key item another member's event used up loses nothing, and a find of it
# heard afterwards gives no copy.
$game_system = Game_System.new
$game_party = Game_Party.new
$notices.clear
used.call(ana, harpy)
look.call
found.call(ana, "508")
look.call
check("a player who lacks a used up key item loses nothing and gets no copy from its find", [$game_party.item_number(fruit), $notices], [0, []])
$told.clear
$members = [ana]
look.call
$members = [ana, cara]
look.call
check("a member who joins hears every use the player knows", $told.find { |told| told[1] == "used" }[3]["uses"], harpy)

# A use the player's own game made is the same use when another member's game makes it at the same
# command.
$game_system = Game_System.new
$game_party = Game_Party.new
$game_party.gain_item(fruit, 1)
$place = "map:88:4:1@63"
$game_party.lose_item(fruit, 1)
$place = nil
$game_party.gain_item(fruit, 1)
used.call(ana, harpy)
look.call
check("another member's use at the command the player's own game used it up at takes nothing more", $game_party.item_number(fruit), 1)

# The return to the Great Decision runs the Final Chapter's reset (common event 154 through the
# Reset at map 889), which takes the route's key items, as a Warp Stone at command 44: the player's
# own one goes, no use is noted, and another player who holds one keeps it.
stone = $data_items[568]
$game_system = Game_System.new
$game_party = Game_Party.new
$game_party.gain_item(stone, 1)
$told.clear
$place = "map:889:3:1@405>ce:265@3>ce:266@2>ce:154@44"
$resetting = true
$game_party.lose_item(stone, 1)
$resetting = false
$place = nil
heard = $told.select { |told| told[1] == "used" }.map { |told| told[3]["uses"] }
check("a story reset takes the player's own Warp Stone and notes no use of it", [$game_party.item_number(stone), heard, MGQ_MpStoryFound.spent], [0, [], []])
$game_system = Game_System.new
$game_party = Game_Party.new
$game_party.gain_item(stone, 1)
heard.each { |uses| used.call(ana, uses) }
look.call
check("so another player who holds one keeps it", $game_party.item_number(stone), 1)
