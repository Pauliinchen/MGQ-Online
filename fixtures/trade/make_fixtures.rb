#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the trade's handshake and session next to this file, cases.json, from
# trade.rbx as it kept them before they moved to C# (commit eae042b7, which this generator reads
# through git, so it runs again on later commits). Each scenario is a list of steps; a step's
# operations run, then its frames (MGQ_MpTrade.tick), and the step records what the operations and
# the frames did: the trade messages sent, the notices, the relay calls and the trade as it stands.
# It also records agreed_text and relay_id for a few pairs of players. MGQOnline.Game.Tests replays
# them against the C# trade.
#
#   ruby fixtures/trade/make_fixtures.rb

require "json"
require "tempfile"
require_relative "../../GameScript/Tests/world_support"

# The commit whose trade.rbx kept the rules.
SOURCE_COMMIT = "eae042b7"

# The trade's id the player makes up as the one who offered it.
TRADE_ID = "0123456789abcdef01234567"

# The log stays quiet; the cases record what the rules did, not their lines.
module MGQ_Multiplayer::Log; def self.write(_line); end; end

# Stand-ins for the game's items.
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
  # An item of the database.
  class Item < BaseItem
    # Whether it is a key item.
    def key_item?; false; end
    # Whether it is an enchantment stone.
    def enchant_stone?; false; end
  end
  # A weapon of the database.
  class Weapon < BaseItem; end
  # An armor of the database.
  class Armor < BaseItem; end
end

$data_items = [nil, RPG::Item.new(1, "Potion")]
$data_weapons = [nil, RPG::Weapon.new(1, "Club")]
$data_armors = [nil]
$data_classes = [nil]

# The game's party: up to 99 of each item and gold.
class Game_Party
  # The gold.
  attr_reader :gold
  # Creates a party with 9 potions and 100 gold.
  def initialize; @counts = Hash.new(0); @counts[$data_items[1]] = 9; @gold = 100; end
  # The most gold the party holds.
  def max_gold; 999_999_999; end
  # How many of an item the party holds.
  def item_number(item); @counts[item]; end
  # The items held.
  def items; @counts.keys; end
  # No weapons are held.
  def weapons; []; end
  # No armors are held.
  def armors; []; end
end
# The game's system data.
class Game_System; end
# The game's data manager, which never saves here.
module DataManager
  # Saves nothing.
  def self.save_game(_index); false; end
end
# The DLL: ready, its trade functions recorded in $dll, the relay's answer read from $relay_state.
module MGQ_Multiplayer
  # The DLL is always there.
  def self.available?; true; end
  # The game is never outdated.
  def self.outdated?; false; end
  # The DLL's functions.
  module Link
    # A function whose calls are recorded and answered with 1; a commit starts out sending, as the
    # DLL's commit replaces the one before.
    #
    # @param name [String] The export.
    # @return [Proc] The function.
    def self.function(name)
      lambda do |*args|
        call = [name] + args.map { |arg| arg.to_s.chomp("\0") }
        $dll << call
        $relay_state = "trade=#{call[2]}\nstate=sending" if name == "mp_trade_commit"
        1
      end
    end
    # The relay's answer about the commit, or an empty list of trades to recover.
    def self.read(name, _size); name == "mp_trade_state" ? $relay_state : "state=done\n\n"; end
  end
end
# The open world, with its directory id.
module MGQ_MpWorld; World = Struct.new(:id, :directory_id); def self.world; World.new("f1", "w1"); end; end
# The trade screen.
class Scene_MpTrade; end
# The scene manager's call, which only opens the trade screen here.
module SceneManager; def self.call(_scene); end; end
# Sends that fail while $send_fails.
module MGQ_MpOverworldSync::Link; def self.send_to(target, text); $sent << [target, text]; !$send_fails; end; end

$game_party = Game_Party.new
$game_system = Game_System.new
$dll = []
$relay_state = ""

source = `git -C "#{File.expand_path('../..', __dir__)}" show #{SOURCE_COMMIT}:GameScript/Multiplayer/Scripts/trade.rbx`
raise "git could not read trade.rbx of #{SOURCE_COMMIT}" if source.empty?

# The script held the other player's untouched offer as no text, so the two games compared different
# offers until its owner changed it; the cases hold it as the empty offer, as C# does.
untouched = source.sub!('Offer.new(0, []), Offer.new(0, []), "",', 'Offer.new(0, []), Offer.new(0, []), "g0",')
raise "trade.rbx of #{SOURCE_COMMIT} starts a session in another way" unless untouched

script = Tempfile.new(["trade", ".rbx"])
script.write(source)
script.close
load script.path

# The trade's id stays the same in every case, so the C# side can be handed it.
module MGQ_MpCoop; def self.random_id(_length, _radix = 36); TRADE_ID; end; end

# A committed trade is recorded as applied and never saved: applying, saving and the notice after
# them stay the scripts' once the session moved.
$applied = []
module MGQ_MpTrade::Recovery
  # Records the trade's id and both offers, applied in full.
  def self.apply_once(id, mine, theirs); $applied << [id, MGQ_MpTrade::Items.write_offer(mine), MGQ_MpTrade::Items.write_offer(theirs)]; true; end
  # Saves nothing.
  def self.finish; false; end
end

# The notice after an applied trade, which stays the scripts'.
APPLIED_NOTICE = "Trade with Friend complete. Save your game."

# Records every notice.
$notices = []
module MGQ_MpOverworldSync::Status
  class << self
    alias_method :harness_notice, :notice
    # Records the notice, then shows it.
    def notice(text, icon = nil); $notices << text; harness_notice(text, icon); end
  end
end

FRIEND = { "id" => "friend", "name" => "Friend", "sprite" => "Actor2", "index" => 0, "map" => 5, "x" => 4, "y" => 4, "d" => 2, "speed" => 4, "hidden" => 0, "scene" => "map" }

# Forgets every trade and the other player, and has the other player stand next to the player.
def fresh
  MGQ_MpTrade.reset
  MGQ_MpTrade.instance_variable_set(:@poll, 0)
  MGQ_MpTrade::Recovery.instance_variable_set(:@checked, [MGQ_MpTrade.world_id, $game_system.object_id])
  MGQ_MpOverworldSync::Peers.instance_variable_set(:@peers, {})
  SceneManager.scene = Scene_Map.new
  $send_fails = false
  $relay_state = ""
  $inbox << entry("seat", 0) << entry("in", 2) << entry("message", 2, told(FRIEND))
end

# Describes the trade as it stands.
#
# @return [Hash] The trade's view: the session, nil for none, and the accepted trade waiting to open.
def view
  trade = MGQ_MpTrade
  session = trade.session
  accepted = trade.instance_variable_get(:@accepted)
  {
    "session" => session && {
      "id" => session.id, "partner" => session.partner, "stage" => session.stage.to_s, "my_rev" => session.my_rev,
      "their_rev" => session.their_rev, "confirmed" => session.confirmed ? true : false,
      "their_confirmed" => session.their_confirmed? ? true : false, "relay_id" => session.relay_id,
      "leaving" => session.leaving, "unsent" => session.unsent, "away" => session.away
    },
    "accepted" => accepted && accepted[:id],
    "open_screen" => trade.instance_variable_get(:@open_screen) ? true : false,
  }
end

# Runs one operation as the scripts or the other player do.
#
# @param op [Array] The operation: ["message", text] from the other player, ["out"] or ["back"]
#   for their connection, ["invite"], ["accept"], ["decline"] (the notification box's), ["gold", n],
#   ["potions", n], ["confirm"], ["cancel"], ["busy", true or false], ["send_fails", true or false]
#   or ["relay", text] for the relay's answer about the commit.
# @return [Array] The operation as the C# side replays it.
def run(op)
  trade = MGQ_MpTrade
  peer = MGQ_MpOverworldSync::Peers.at(2)
  case op[0]
  when "message" then $inbox << entry("message", 2, op[1])
  when "out" then $inbox << entry("out", 2)
  when "back" then $inbox << entry("in", 2) << entry("message", 2, told(FRIEND))
  when "invite" then trade.invite
  when "accept" then trade.accept(peer)
  when "decline" then trade.decline(peer, "no")
  when "gold", "potions"
    before = trade.session.my_rev
    op[0] == "gold" ? trade.set_gold(op[1]) : trade.set_amount($data_items[1], op[1])
    return ["offer", trade.session.my_rev == before ? nil : MGQ_MpTrade::Items.write_offer(trade.session.mine)]
  when "confirm"
    session = trade.session
    refusal = session && MGQ_MpTrade::Items.receive_refusal(session.theirs, session.name, session.mine)
    trade.toggle_confirm
    return ["confirm", refusal]
  when "cancel" then trade.cancel
  when "busy" then SceneManager.scene = op[1] ? Scene_Item.new : Scene_Map.new
  when "send_fails" then $send_fails = op[1]
  when "relay"
    $relay_state = op[1].sub("%RELAY%", trade.session.relay_id.to_s)
    return ["relay", $relay_state]
  else raise "unknown operation #{op[0]}"
  end
  op
end

# Tells what the scripts hand the C# trade: the player's offer and why they are busy.
#
# @return [Hash] "inviting", "targets" and "busy".
def handed_now
  invite = MGQ_MpTrade.instance_variable_get(:@invite)
  { "inviting" => invite.inviting?, "targets" => invite.targets.dup, "busy" => SceneManager.scene.is_a?(Scene_Map) ? nil : "the map is not free" }
end

# Plays a scenario.
#
# @param name [String] Its name.
# @param steps [Array<Array>] Each step's operations and frames.
# @return [Hash] The scenario with what each step did.
def scenario(name, steps)
  fresh
  played = steps.map do |ops, frames|
    $sent.clear
    $notices.clear
    $dll.clear
    $applied.clear
    # What the scripts hand over before the first of the other player's messages, which the C#
    # room takes in the frame after.
    handed = nil
    replayed = ops.map do |op|
      handed ||= handed_now if %w[message out back].include?(op[0])
      run(op)
    end
    handed ||= handed_now
    frames.times { MGQ_MpTrade.tick(true) }
    sent = $sent.map { |seat, text| [seat, text] }.select { |_, text| text.start_with?("trade=") }
    dll = $dll.select { |call| %w[mp_trade_commit mp_trade_cancel].include?(call[0]) }
    notices = $notices - [APPLIED_NOTICE]
    { "ops" => replayed, "handed" => handed, "frames" => frames,
      "outcome" => JSON.parse(JSON.generate({ "sent" => sent, "notices" => notices, "relay" => dll, "applied" => $applied.dup, "view" => view })) }
  end
  { "name" => name, "steps" => played }
end

# A message of the trade from the other player.
#
# @param fields [Hash] The fields after "trade".
# @param body [String] What follows them.
# @return [String] The message.
def from_friend(kind, fields = {}, body = "")
  ({ "trade" => kind }.merge(fields)).map { |key, value| "#{key}=#{value}" }.join("\n") + "\n\n" + body
end

tid = TRADE_ID
opened = [[["invite"], ["message", from_friend("accept")]], 1]
scenarios = [
  scenario("open as the player who offered", [
    [[["invite"]], 1],
    [[["message", from_friend("accept")]], 1],
  ]),
  scenario("accept another's trade and open it", [
    [[["accept"]], 1],
    [[["message", from_friend("open", "tid" => tid)]], 1],
  ]),
  scenario("an accepted trade that never opens", [
    [[["accept"]], 361],
  ]),
  scenario("an accept without an offer is declined as gone", [
    [[["message", from_friend("accept")]], 1],
  ]),
  scenario("an accept while busy is declined as busy", [
    [[["invite"], ["busy", true]], 1],
    [[["message", from_friend("accept")]], 1],
  ]),
  scenario("an open of a trade not accepted is answered with a cancel", [
    [[["message", from_friend("open", "tid" => tid)]], 1],
  ]),
  scenario("an open with an id that is not valid is declined as invalid", [
    [[["accept"]], 1],
    [[["message", from_friend("open", "tid" => "not-an-id")]], 1],
  ]),
  scenario("an open while busy is declined as busy", [
    [[["accept"], ["busy", true]], 1],
    [[["message", from_friend("open", "tid" => tid)]], 1],
  ]),
  scenario("declines with their reasons", [
    [[["invite"], ["message", from_friend("decline", "reason" => "no")]], 1],
    [[["accept"], ["message", from_friend("decline", "reason" => "busy")]], 1],
    [[["message", from_friend("decline", "reason" => "newer")]], 1],
    opened,
    [[["message", from_friend("decline", "tid" => tid, "reason" => "invalid")]], 1],
  ]),
  scenario("the player declines an offer", [
    [[["decline"]], 1],
  ]),
  scenario("strays", [
    [[["message", from_friend("offer", "tid" => "c" * 24, "rev" => 3) + "g10"]], 1],
    [[["message", from_friend("confirm", "tid" => "c" * 24, "mine" => 1, "yours" => 0)]], 1],
    [[["message", from_friend("cancel", "tid" => "c" * 24, "reason" => "off")]], 1],
    opened,
    [[["message", from_friend("unconfirm", "tid" => "d" * 24)]], 1],
    [[["message", from_friend("bogus", "tid" => tid)]], 1],
  ]),
  scenario("offers, confirmations and a change dropping both", [
    opened,
    [[["potions", 3], ["gold", 500], ["gold", 0], ["potions", 3]], 1],
    [[["message", from_friend("offer", "tid" => tid, "rev" => 1) + "g50;w1*1"]], 1],
    [[["confirm"]], 1],
    [[["message", from_friend("confirm", "tid" => tid, "mine" => 1, "yours" => 2)]], 1],
    [[["message", from_friend("offer", "tid" => tid, "rev" => 2) + "g60;w1*1"]], 1],
    [[["message", from_friend("offer", "tid" => tid, "rev" => 1) + "g70"]], 1],
    [[["confirm"], ["confirm"], ["confirm"]], 1],
    [[["message", from_friend("unconfirm", "tid" => tid)]], 1],
    [[["potions", 2]], 1],
  ]),
  scenario("both confirm, and the relay commits", [
    opened,
    [[["potions", 1], ["message", from_friend("offer", "tid" => tid, "rev" => 1) + "g5"]], 1],
    [[["confirm"], ["message", from_friend("confirm", "tid" => tid, "mine" => 1, "yours" => 1)]], 1],
    [[["potions", 2], ["relay", "trade=%RELAY%\nstate=waiting"]], 15],
    [[["relay", "trade=%RELAY%\nstate=committed"]], 15],
  ]),
  scenario("the relay turns the commit down, and the other changes theirs while it decides", [
    opened,
    [[["potions", 1], ["confirm"], ["message", from_friend("confirm", "tid" => tid, "mine" => 0, "yours" => 1)]], 1],
    [[["relay", "trade=%RELAY%\nstate=cancelled\nreason=expired"]], 15],
    [[["confirm"], ["message", from_friend("confirm", "tid" => tid, "mine" => 0, "yours" => 2)]], 1],
    [[["message", from_friend("offer", "tid" => tid, "rev" => 1) + "g3"]], 1],
    [[["relay", "trade=%RELAY%\nstate=cancelled\nreason=cancelled"]], 15],
  ]),
  scenario("a gift commits the untouched own offer as an empty one", [
    opened,
    [[["message", from_friend("offer", "tid" => tid, "rev" => 1) + "g5"]], 1],
    [[["confirm"], ["message", from_friend("confirm", "tid" => tid, "mine" => 1, "yours" => 0)]], 1],
    [[["relay", "trade=%RELAY%\nstate=cancelled\nreason=differ"]], 15],
  ]),
  scenario("empty offers cannot be confirmed", [
    opened,
    [[["confirm"]], 1],
  ]),
  scenario("cancels", [
    opened,
    [[["cancel"]], 1],
    opened,
    [[["message", from_friend("cancel", "tid" => tid, "reason" => "off")]], 1],
    opened,
    [[["potions", 1], ["confirm"], ["message", from_friend("confirm", "tid" => tid, "mine" => 0, "yours" => 1)]], 1],
    [[["cancel"], ["cancel"]], 1],
    [[["relay", "trade=%RELAY%\nstate=cancelled\nreason=cancelled"]], 15],
    opened,
    [[["potions", 1], ["confirm"], ["message", from_friend("confirm", "tid" => tid, "mine" => 0, "yours" => 1)]], 1],
    [[["message", from_friend("cancel", "tid" => tid, "reason" => "off")]], 1],
    [[["relay", "trade=%RELAY%\nstate=cancelled\nreason=cancelled"]], 15],
    opened,
    [[["potions", 1], ["confirm"], ["message", from_friend("confirm", "tid" => tid, "mine" => 0, "yours" => 1)]], 1],
    [[["relay", "trade=%RELAY%\nstate=failed\nerror=The server could not be reached. Check your internet connection."]], 15],
  ]),
  scenario("the other player away and back", [
    opened,
    [[["potions", 1], ["confirm"]], 1],
    [[["out"]], 30],
    [[["back"]], 1],
    [[["confirm"], ["out"]], 30],
    [[["back"]], 1],
  ]),
  scenario("the other player gone for good", [
    opened,
    [[["out"]], 900],
    [[], 1],
  ]),
  scenario("messages that could not go out go out again", [
    opened,
    [[["potions", 1], ["send_fails", true], ["confirm"]], 45],
    [[["send_fails", false]], 14],
    [[], 1],
    [[], 30],
    [[["send_fails", true], ["confirm"], ["send_fails", false]], 15],
  ]),
]

# Writes the offers and the id the relay knows a trade by for a pair of players.
#
# @param me [String] The player's id.
# @param partner [String] The other player's id.
# @param mine [String] The player's offer.
# @param theirs [String] The other's offer.
# @param my_rev [Integer] The player's offer's revision.
# @param their_rev [Integer] The other's.
# @return [Hash] The case.
def agreed(me, partner, mine, theirs, my_rev, their_rev)
  session = MGQ_MpTrade::Session.new(TRADE_ID, partner, "Partner", nil, nil, theirs, my_rev, their_rev)
  MGQ_MpTrade::Items.define_singleton_method(:write_offer) { |_offer| mine }
  MGQ_MpOverworldSync::Me.define_singleton_method(:id) { me }
  { "me" => me, "partner" => partner, "mine" => mine, "theirs" => theirs, "my_rev" => my_rev, "their_rev" => their_rev,
    "agreed_text" => MGQ_MpTrade.agreed_text(session), "relay_id" => MGQ_MpTrade.relay_id(session) }
end

agreements = [
  agreed("aa11", "bb22", "g0;i1*3", "g60;w2*1", 4, 1),
  agreed("bb22", "aa11", "g60;w2*1", "g0;i1*3", 1, 4),
  agreed("B", "a", "g1", "g2", 0, 0),
  agreed("me", "friend", "g0;uew9.7~5p1*1", "g10", 65_536, 65_537),
  agreed("f0", "f", "g0", "g0;a1*99", 255, 4096),
]

cases = { "trade_id" => TRADE_ID, "me" => "me", "friend" => FRIEND, "scenarios" => scenarios, "agreed" => agreements }
File.write(File.join(__dir__, "cases.json"), JSON.pretty_generate(cases) + "\n")
puts "wrote #{scenarios.size} scenarios and #{agreements.size} agreements"
