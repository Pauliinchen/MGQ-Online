#----------------------------------------------------------------
#  battles_served_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Read the setup back as the DLL hands it, fixed per case, instead of as a copy of how C# reads it
#                            - Kept and handed the battle channel's messages as fields instead of through a copy of the DLL's codec
#                            - Answered the squad math with fixed values per case
#                            - Hosted the battles and took the joins as the co-op topics' fixed answers say
#                            - Answered the live battle's checks with the values each case sets and checked what the scripts ask
#                            - Handed the starter's mod options as values
#                            - Checked that a request is passed on with its fields as values
#                            - Wrote and read the battle lines through the codec's stand-in and checked the facts the script hands over through the battle line's values
#                            - Stood in for the DLL's topics of the battle channel in place of its exports
#      Paulinchen  2026-10-31: Checked that the battle server counts the players of its battle without itself
#                            - Checked that the battle server tells the starter its front state again once the starter comes onto the channel
#                            - Checked that a String held as bytes crosses to C# as text
#      Paulinchen  2026-10-30: Checked the widths of the troop's pictures in the setup
#                            - Stood in for the setup C# writes and reads, handed the facts the script collects
#                            - Checked that a Float or a Symbol among the facts still writes the setup
#                            - Stood in for the DLL's serve, channel and front, which keep the time-outs, the lasting refusals and the server's messages for the world
#                            - Joined a served battle late from the outcome the DLL tells
#      Paulinchen  2026-10-23: Checked the squad rules a setup carries and their defaults
#                            - Checked that the server keeps a player who drops from the battle channel until gone
#                            - Checked a served battle that ends before its roster
#      Paulinchen  2026-10-15: Checked the starter as the front of its served battle and players who join it late
#                            - Checked that the last player of the server's battle fights on there and a battle every player left ends
#                            - Checked the world's mods and the starter's options of them in the setup
#                            - Checked that a guest sends to the server alone and hears of a player who leaves
#                            - Created
#
#----------------------------------------------------------------

# Covers co-op battles the battle server hosts, battles_served.rbx with battles_coop.rbx and
# battles_sync.rbx, on a player's game: the starter handing a gathered battle to the server or
# hosting it when the relay refuses, a guest following, and the battle channel's entries, sends
# and end, through a stand-in for the DLL's topics of the battle channel (served.*).

require_relative "battle_support"
require_relative "rules_support"

# The mod's base script, available.
module MGQ_Multiplayer
  def self.available?; true; end
end
# The world the player is in and its game data.
module MGQ_MpWorld
  World = Struct.new(:directory_id)
  def self.world; World.new("world-1"); end
  def self.squad; $squad; end
  def self.squad_from(rules); rules.is_a?(Hash) ? { :luka => rules["luka"], :formation => rules["formation"], :front => rules["front"], :raid_front => rules["raid_front"] } : nil; end
  module GameData; def self.fingerprint; "1:data"; end; end
end
open_rules_bridge
# The DLL's arrangement of the battles' players below, by the players
# handed over, each [id, first, party_member_max, characters], answered as [index, Frontline,
# Backline] of each in their order.
$rule_answers.cases("squad.arrange", {
  [["id-me", true, 8, 3], ["id-friend", false, 8, 3]] => [[0, 2, 1], [1, 2, 1]],
  [["id-friend", false, 8, 1]] => [[0, 1, 0]]
}) { |request| request["players"] }
$rule_answers.set("squad.shares", [[2, 2], [2, 2]])
# The DLL's battle channel: the calls are kept in $dll_calls, a send once per seat with the message
# as the scripts hand it; the battle's state is $dll_state, which a serve the relay refuses for the
# session ($lasting) names from then on; the entries waiting on the channel are $dll_entries.
$world_bridge.answer("served.serve") do |request|
  $dll_calls << ["served.serve", request.values_at("world", "battle", "seats", "setup")]
  $dll_state = ($dll_state || {}).merge("lasting" => $lasting) if $lasting
  true
end
$world_bridge.answer("served.open") { |request| $dll_calls << ["served.open", request.values_at("world", "battle")]; $dll_opens }
$world_bridge.answer("served.send") do |request|
  request["seats"].each { |seat| $dll_calls << ["served.send", [seat, sent_message({ "battle" => request["kind"], "bid" => request["bid"] }, request["body"])]] }
end
$world_bridge.answer("served.receive") { taken = $dll_entries.dup; $dll_entries.clear; taken }
$world_bridge.answer("served.state") { $dll_state }
$world_bridge.answer("served.close") { $dll_calls << ["served.close", []]; nil }

# An entry of the battle channel as the DLL hands it.
#
# @param kind [String] "seat", "in", "out", "message" or "closed".
# @param seat [Integer] The seat it is of.
# @param message [Hash, nil] A message's fields as the DLL reads them, its body under :payload.
# @param code [String, nil] Why a closed channel ended.
# @return [Hash] The entry.
def channel_entry(kind, seat, message = nil, code = nil)
  entry = { "kind" => kind, "seat" => seat, "code" => code }
  return entry unless message

  entry.merge("fields" => message.reject { |key, _| key == :payload }, "body" => message[:payload].to_s)
end
# The DLL's front of a served battle: what the scripts hand it is kept, and it passes on hot
# requests of the battle $front_battle, sends what it is handed, and tells the server's state
# $front_state.
$front_calls = []
$world_bridge.answer("served.fronts") { |request| $front_calls << ["fronts", request]; request["coop"] == "hot" && request["bid"] == $front_battle }
$world_bridge.answer("served.forward") { |request| $front_calls << ["forward", request]; true }
$world_bridge.answer("served.left") { |request| $front_calls << ["left", request]; true }
$world_bridge.answer("served.front_state") { $front_state }
# The setup C# writes and reads (ServedSetupTests): here the facts the script hands over, kept in
# $written_facts and as JSON, and read back as the DLL hands them, which a test sets in $read_facts
# for its case, else the facts as written; a text that is no setup reads as none.
$read_facts = nil
$world_bridge.answer("served.setup.write") { |facts| $written_facts = facts; JSON.generate(facts) }
$world_bridge.answer("served.setup.read") do |text|
  begin
    $read_facts || JSON.parse(text)
  rescue JSON::ParserError
    nil
  end
end
# The game's switches and variables as the game keeps them, in lists.
class Game_Switches; def initialize; @data = []; end; def [](i); @data[i] || false; end; def []=(i, v); @data[i] = v; end; end
class Game_Variables; def initialize; @data = []; end; def [](i); @data[i] || 0; end; def []=(i, v); @data[i] = v; end; end
# The troop the battle fights, as the database keeps it.
class Game_Troop; def troop; Struct.new(:id).new(40); end; end
load_script "battles_served"
MGQ_MpBattlesServed.instance_variable_set(:@scripts_fingerprint, "0badf00d")

$dll_calls = []
$dll_entries = []
$dll_opens = true
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_switches[12] = true
$game_variables[150] = 3
$game_variables[151] = 0
mine = [Game_Actor.new(1), Game_Actor.new(2), Game_Actor.new(3)]
$game_party.own = mine
friend = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "id-friend", "name" => "Friend", "map" => "5", "scene" => "map" }, nil, true)
MGQ_MpOverworldSync::Peers.all.push(friend)
$my_seat = 0
$leader = :me
$sync_level = 30
scene = Scene_Battle.new
$scene_now = scene
join = wire_line(["7,8,9", [[50, 5], [60, 6], [70, 7]], 8])

# Sets up troop 40 as a battle the DLL's matchmaking hosts, inviting the friend.
def host_battle
  $coop.hosts("sb1", [2])
  BattleManager.setup(40, true, false)
  $coop.hosts(nil)
end

# Gathers a co-op battle the friend joins, with the battle server answering as $dll_state says.
#
# @param scene [Scene_Battle] The battle.
# @param friend [MGQ_MpOverworldSync::Peers::Peer] The friend.
# @param join [String] The friend's join.
# @return [Array] What gather answered and the battle's id.
def gather_with_friend(scene, friend, join)
  host_battle
  BattleManager.instance_variable_set(:@can_escape, true)
  BattleManager.instance_variable_set(:@can_lose, false)
  bid = MGQ_MpBattlesSync.battle_id
  $sent.clear
  $dll_calls.clear
  $frames = 0
  $coop.gathered([friend.seat, join])
  answer = MGQ_MpBattlesCoop.gather(scene)
  [answer, bid]
end

# Tells the kinds of the battle's messages sent through the world room.
#
# @return [Array<String>] The kinds.
def sent_kinds
  $sent.map { |_seat, message| message["battle"] }.compact
end

# A relay without a battle server: the starter hosts, and asks no more this session.
$dll_state = { "state" => "refused", "code" => "no_server" }
$lasting = "no_server"
answer, = gather_with_friend(scene, friend, join)
check("a relay without a battle server leaves the battle to the starter, who sends the roster through the world room",
      [answer, sent_kinds.include?("roster"), sent_kinds.include?("serve"), MGQ_MpBattlesSync.role], [nil, true, false, :host])
check("after asking the relay once and letting go of the battle channel",
      $dll_calls.map(&:first), %w(served.serve served.close))
check("and no later battle of the session asks again", MGQ_MpBattlesServed.available?, false)
check("which the log tells", $log.grep(/did not take battle .* \(no_server\): the starter hosts it, and every later battle of this session/).size, 1)
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish
$lasting = nil

# A busy battle server: this battle stays with the starter, the next asks again.
$dll_state = { "state" => "refused", "code" => "busy" }
answer, = gather_with_friend(scene, friend, join)
check("a busy battle server leaves this battle to the starter", [answer, sent_kinds.include?("roster")], [nil, true])
check("and the next battle asks again", MGQ_MpBattlesServed.available?, true)
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish

# The DLL does not start asking: the starter hosts at once.
$dll_state = nil
failing = MGQ_MpBattlesServed::Port.method(:serve)
MGQ_MpBattlesServed::Port.define_singleton_method(:serve) { |*| false }
answer, = gather_with_friend(scene, friend, join)
MGQ_MpBattlesServed::Port.define_singleton_method(:serve, failing)
check("a DLL that does not start asking leaves the battle to the starter", [answer, sent_kinds.include?("roster")], [nil, true])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish

# The battle server takes the battle.
$dll_state = { "state" => "served" }
answer, bid = gather_with_friend(scene, friend, join)
serve_call = $dll_calls.find { |name, _| name == "served.serve" }
check("a battle the server takes makes the starter its guest", [answer, MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.served?, MGQ_MpBattlesServed.starter?], [:guest, :guest, true, true])
check("asked for with the world, the battle and both players' seats", serve_call[1][0, 3], ["world-1", bid, [0, 2]])
check("the starter hands C# the facts of the setup", JSON.parse(serve_call[1][3]).keys,
      %w(scripts data troop escape lose map rates enemies players level switches variables raid pool tiers starter squad mods settings widths))
setup = MGQ_MpBattlesServed.read_setup(serve_call[1][3])
check("the setup names the troop, how the battle ends, the map and the level",
      [setup[:troop], setup[:escape], setup[:lose], setup[:map], setup[:level], setup[:raid]], [40, true, false, 5, 30, false])
check("its fingerprints", [setup[:scripts], setup[:data]], ["0badf00d", "1:data"])
check("its arranged players, the starter first", setup[:players].map { |player| [player.seat, player.name, player.builds] }, [[0, "Me", "1,2,3"], [2, "Friend", "7,8,9"]])
check("the starter of a battle the server never started fights its encounter as its own", MGQ_MpBattlesCoop.never_got(:gone), :gone)
check("and the switches and variables that are set, these among them", [setup[:switches].include?(12), setup[:switches] - (1..200).select { |id| $game_switches[id] == true }, setup[:variables]], [true, [], [[150, 3]]])
serve = $sent.find { |_, fields| fields["battle"] == "serve" }
check("the guests are told to follow it to the server", [serve[0], wire_values(serve[1][:payload])], [2, [bid]])
check("no roster goes through the world room", sent_kinds.include?("roster"), false)
check("the starter opens the battle channel", [$dll_calls.find { |name, _| name == "served.open" }, MGQ_MpBattlesServed.channel], [["served.open", ["world-1", bid]], :opening])

# The battle channel opens and carries the server's roster.
$dll_entries << channel_entry("seat", 0)
MGQ_MpBattlesServed.drain
check("the seat entry opens the channel", MGQ_MpBattlesServed.channel, :open)
$live.set("live.admit") { |request| request["bid"] == "other" && ["served_dropped\troster\tother", "ignored roster from the battle channel: it is for another battle"] }
$dll_entries << channel_entry("message", 250, { "battle" => "roster", "bid" => "other", :payload => "wrong" })
$dll_entries << channel_entry("message", 250, { "battle" => "roster", "bid" => bid, :payload => "the roster" })
roster = MGQ_MpBattlesSync::Channel.take("roster")
check("the server's message goes to the DLL's check as one of the battle channel", $live.asked("live.admit").last(2).map { |request| [request["channel"], request["bid"], request["kind"]] },
      [[true, "other", "roster"], [true, bid, "roster"]])
check("and reaches the battle, one the DLL refuses does not", roster, "the roster")
check("which the log tells with the DLL's reason", $log.grep(/ignored roster from the battle channel: it is for another battle/).size, 1)
$live.set("live.admit", nil)

# The starter's messages go to the server over the channel.
$dll_calls.clear
$sent.clear
MGQ_MpBattlesSync::Channel.post("commands", "the commands")
check("a message of the battle goes to the server's seat over the channel, not the world room",
      [$dll_calls, $sent], [[["served.send", [250, { "battle" => "commands", "bid" => bid, :payload => "the commands" }]]], []])

# The channel ends.
$dll_entries << channel_entry("closed", 0, nil, "ended")
check("a closed entry ends the battle for the guest", [MGQ_MpBattlesServed.closed?, $log.grep(/the battle channel closed: ended/).size], [true, 1])
$dll_calls.clear
MGQ_MpBattlesSync.finish
check("finishing closes the ended channel at the DLL, which forgets it", [$dll_calls, MGQ_MpBattlesServed.channel, MGQ_MpBattlesServed.starter?, MGQ_MpBattlesSync.served?], [[["served.close", []]], nil, false, false])
MGQ_MpBattlesCoop.ended

# A guest follows the host to the server.
host_battle
bid = MGQ_MpBattlesSync.battle_id
$dll_calls.clear
MGQ_MpBattlesServed.follow(wire_line(["other"]))
check("a serve for another battle is ignored", [$dll_calls, MGQ_MpBattlesSync.served?, $log.grep(/ignored a serve for battle other/).size], [[], false, 1])
MGQ_MpBattlesServed.follow(wire_line([bid]))
check("one for the battle makes the player the server's guest, not its starter",
      [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.served?, MGQ_MpBattlesServed.starter?, $dll_calls], [:guest, true, false, [["served.open", ["world-1", bid]]]])

# The channel never opens: the DLL ends it in time.
$dll_state = { "state" => "opening" }
$dll_entries.clear
MGQ_MpBattlesServed.drain
check("a channel still opening waits", MGQ_MpBattlesServed.channel, :opening)
$dll_entries << channel_entry("closed", 0, nil, "open_timeout")
MGQ_MpBattlesServed.drain
check("a channel that does not open in time ends", [MGQ_MpBattlesServed.channel, $log.grep(/did not open within 10 s/).size], [:closed, 1])
$dll_calls.clear
MGQ_MpBattlesSync.finish
check("and is closed at the DLL", $dll_calls, [["served.close", []]])
MGQ_MpBattlesCoop.ended

# The DLL does not open the channel.
host_battle
$dll_opens = false
MGQ_MpBattlesServed.follow(wire_line([MGQ_MpBattlesSync.battle_id]))
check("a channel the DLL does not open ends the battle for the guest", [MGQ_MpBattlesServed.channel, MGQ_MpBattlesServed.closed?], [:closed, true])
$frames = 0
$live.set("live.tick ending", "ending" => "broken")
ending = MGQ_MpBattlesCoop.join(scene)
$live.set("live.tick ending", nil)
check("a guest whose served battle broke off before its roster never fights it alone, but goes back to the map, told why",
      [ending, MGQ_MpBattlesSync.take_missed], [:broken, "The server's battle ended before you could join."])
$dll_opens = true
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# The starter as the served battle's front: the DLL decides which requests to join go to the
# server, sends them with the states and fields the script hands it, and keeps the server's state.
$dll_state = { "state" => "served" }
_answer, bid = gather_with_friend(scene, friend, join)
$front_battle = bid
$dll_entries << channel_entry("seat", 0)
MGQ_MpBattlesServed.drain
joiner = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "id-joiner", "name" => "Joiner", "map" => "5", "scene" => "map", "x" => "3" }, nil, false)
MGQ_MpOverworldSync::Peers.all.push(joiner)
$front_calls.clear
MGQ_MpBattlesCoop.take(joiner, { "coop" => "hot", "bid" => bid, "troop" => "5", "enemies" => "31:320:300:0", "seats" => [2], "map" => "5" })
forward = $front_calls.find { |kind, _| kind == "forward" }
check("the starter asks the DLL whether a request to join its served battle goes to the server, with its kind and battle",
      $front_calls.first, ["fronts", { "coop" => "hot", "bid" => bid }])
check("and hands it the asking player's seat, the id and name of its player and of those it brings along, and the request's fields",
      [forward[1]["seat"], forward[1]["states"], forward[1]["fields"].values_at("coop", "troop", "seats")],
      [4, [[4, [["id", "id-joiner"], ["name", "Joiner"]]], [2, [["id", "id-friend"], ["name", "Friend"]]]], ["hot", "5", [2]]])
$front_calls.clear
MGQ_MpBattlesCoop.take(joiner, { "coop" => "decline", "bid" => bid })
check("a message the DLL does not pass on stays the starter's own", $front_calls.map(&:first), ["fronts"])

$front_state = nil
check("the starter tells the served battle as its own, no count of its players before the server told one",
      [MGQ_MpBattlesServed.front_fields(%w(rb rbh)), MGQ_MpBattlesServed.front_fields(%w(rbn))], [{ "rb" => bid, "rbh" => "0" }, { "rbn" => 0 }])
$front_state = { "rbn" => "2" }
check("then with the server's count the DLL kept", MGQ_MpBattlesServed.front_fields(%w(rbn)), { "rbn" => "2" })
$front_calls.clear
MGQ_MpBattlesServed.peer_left(joiner)
check("and tells the server a player left the world", $front_calls, [["left", { "seat" => 4 }]])
$dll_entries << channel_entry("message", 2, { "battle" => "front_out", "bid" => bid, :payload => wire_line([4, fake_message({ "map_coop" => "hot_ok" })]) })
MGQ_MpBattlesServed.drain
check("a front message the DLL left to the script is ignored", $log.grep(/ignored front_out from seat 2/).size, 1)
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended
$front_calls.clear
check("a battle that finished has no front", [MGQ_MpBattlesServed.front_fields(%w(rbn)), MGQ_MpBattlesServed.fronts?({ "coop" => "hot", "bid" => bid }), $front_calls], [nil, false, []])

# The battle server takes what its front passes on as the world's room would hand it over.
module MGQ_MpOverworldSync
  module Peers
    def self.take(seat, state); @all.reject! { |peer| peer.seat == seat }; @all << Peer.new(seat, state, nil, false); end
    def self.remove(seat, _reason = nil); @all.reject! { |peer| peer.seat == seat }; end
  end
end
host_battle
bid = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesServed.instance_variable_set(:@server, true)
MGQ_MpBattlesServed.instance_variable_set(:@setup, { :starter => 0, :players => [] })
MGQ_MpBattlesServed.instance_variable_set(:@channel, :open)
taken = []
coop_take = MGQ_MpBattlesCoop.method(:take)
MGQ_MpBattlesCoop.define_singleton_method(:take) { |peer, message| taken << [peer.seat, peer.state["name"], message["coop"], message["troop"]] }
request = wire_line([7, [[7, [["id", "id-late"], ["name", "Late"]]]], [["coop", "hot"], ["bid", bid], ["troop", "5"]]])
$dll_entries << channel_entry("message", 0, { "battle" => "front_in", "bid" => bid, :payload => request })
$dll_entries << channel_entry("message", 3, { "battle" => "front_in", "bid" => bid, :payload => request })
MGQ_MpBattlesServed.drain
check("the server takes a request its starter passed on, its player known by the state passed with it, and one from anyone else not",
      [taken, MGQ_MpOverworldSync::Peers.at(7) && MGQ_MpOverworldSync::Peers.at(7).state], [[[7, "Late", "hot", "5"]], { "id" => "id-late", "name" => "Late" }])
$dll_entries << channel_entry("message", 0, { "battle" => "front_left", "bid" => bid, :payload => wire_line([7]) })
MGQ_MpBattlesServed.drain
check("and forgets a player who left the world, as the starter tells", MGQ_MpOverworldSync::Peers.at(7), nil)
MGQ_MpBattlesCoop.define_singleton_method(:take, coop_take)
$dll_calls.clear
check("the server's message to the world's room goes to its starter", MGQ_MpBattlesServed.front_out(4, { "map_coop" => "hot_no" }, ""), true)
out = $dll_calls.find { |name, _| name == "served.send" }[1]
check("over the battle channel", [out[0], out[1]["battle"], wire_values(out[1][:payload])], [0, "front_out", [4, fake_message({ "map_coop" => "hot_no" })]])
MGQ_MpBattlesServed.instance_variable_set(:@server, nil)
MGQ_MpBattlesServed.instance_variable_set(:@setup, nil)
MGQ_MpBattlesServed.instance_variable_set(:@channel, nil)
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# A player the server takes in late comes onto its channel, by its invite or its answer.
$dll_calls.clear
MGQ_MpBattlesCoop.accept(friend, { "coop" => "invite", "bid" => "late1", "troop" => "40", "escape" => "1", "lose" => "0", "seats" => "0", "map" => "5", "hot" => "1", "served" => "1" })
check("an invite of a served battle makes the player the server's guest",
      [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.served?, $dll_calls.find { |name, _| name == "served.open" }], [:guest, true, ["served.open", ["world-1", "late1"]]])
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.join_world(:guest, "late2", [0], "Friend")
$dll_calls.clear
MGQ_MpBattlesHotjoin.join_late("escape" => true, "lose" => false, "release" => [], "stays_out" => [], "host" => { "escape" => true, "lose" => false, "rates" => "", "served" => true })
check("and so does a served battle's answer to the player's encounter", [MGQ_MpBattlesSync.served?, $dll_calls.find { |name, _| name == "served.open" }], [true, ["served.open", ["world-1", "late2"]]])
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# A guest of the server sends to the server alone, also once the roster names the other players,
# and hears through it of one who leaves.
$dll_state = { "state" => "served" }
_answer, bid = gather_with_friend(scene, friend, join)
$dll_entries << channel_entry("seat", 0)
MGQ_MpBattlesServed.drain
MGQ_MpBattlesCoop.instance_variable_set(:@players, [MGQ_MpBattlesCoop::Player.new(0, "Me", "", [], 8), MGQ_MpBattlesCoop::Player.new(2, "Friend", "", [], 8)])
$dll_calls.clear
MGQ_MpBattlesSync::Channel.post("commands", "x")
check("a guest's message goes to the server's seat alone, never to another player's", $dll_calls.map { |name, args| [name, args[0]] }, [["served.send", 250]])
$notices = []
$dll_entries << channel_entry("message", 250, { "battle" => "departed", "bid" => bid, :payload => wire_line([2]) })
MGQ_MpBattlesServed.drain
check("the server's word that a player left shows as their own leave would", $notices.grep(/Friend left the battle/).size, 1)
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended
host_battle
bid = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesServed.instance_variable_set(:@server, true)
# The battle the server takes over runs on.
$live.set("live.join", "running" => true)
MGQ_MpBattlesSync.serve_over_channel(:host, bid, [1, 2], "the players")
$live.set("live.join", nil)
check("the server counts the players of its battle for those who would join it, not itself", MGQ_MpBattlesHotjoin.players_count, 2)
$dll_calls.clear
MGQ_MpBattlesSync.take_served(1, { "battle" => "leave", "bid" => bid, :payload => "" })
departed = $dll_calls.select { |name, _| name == "served.send" }.map { |_, args| [args[0], args[1]["battle"], wire_values(args[1][:payload])] }
check("the server tells the battle's other players of one who leaves", departed, [[2, "departed", [1]]])
formed = []
form = MGQ_MpBattlesCoop.method(:form)
MGQ_MpBattlesCoop.define_singleton_method(:form) { |_scene, players| formed << players.map(&:seat) }
abort = BattleManager.method(:process_abort)
aborted = []
BattleManager.define_singleton_method(:process_abort) { aborted << true }
MGQ_MpBattlesCoop.instance_variable_set(:@players, [MGQ_MpBattlesCoop::Player.new(1, "Me", "1", [], 8), MGQ_MpBattlesCoop::Player.new(2, "Friend", "2", [], 8)])
MGQ_MpBattlesCoop.instance_variable_set(:@members, [])
MGQ_MpBattlesSync.guest_left(1)
$coop.set("coop.settle", "staying" => [2], "left" => [1], "outcome" => "reform")
MGQ_MpBattlesCoop.settle(scene)
check("the server asks the DLL to settle its battle as the server's", $coop.asked("coop.settle").last["served"], true)
check("the last player in the server's battle fights on there, which no player of its own takes over",
      [formed, aborted, MGQ_MpBattlesSync.role, $log.grep(/goes on alone/)], [[[2]], [], :host, []])
MGQ_MpBattlesSync.guest_left(2)
$coop.set("coop.settle", "staying" => [], "left" => [2], "outcome" => "abandon")
MGQ_MpBattlesCoop.settle(scene)
$coop.set("coop.settle", nil)
check("a battle every player left ends", [formed.size, aborted], [1, [true]])
MGQ_MpBattlesCoop.define_singleton_method(:form, form)
BattleManager.define_singleton_method(:process_abort, abort)
MGQ_MpBattlesServed.instance_variable_set(:@server, nil)
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# On the server a player's drop from the battle channel is a pause: the presence of the players
# keeps them away for the world's grace, and only its word that they are gone takes them out.
module MGQ_MpOverworldSync
  module Peers
    def self.wait_for(seat); $presence_calls << [:away, seat]; end
    def self.come_back(seat); $presence_calls << [:back, seat]; end
  end
end
host_battle
bid = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesServed.instance_variable_set(:@server, true)
$live.set("live.join", "running" => true)
MGQ_MpBattlesSync.serve_over_channel(:host, bid, [1, 2], "the players")
$live.set("live.join", nil)
MGQ_MpBattlesServed.instance_variable_set(:@channel, :open)
$dll_state = { "state" => "open", "in" => [1, 2], "out" => [] }
$presence_calls = []
$dll_entries << channel_entry("out", 1) << channel_entry("in", 1)
MGQ_MpBattlesServed.drain
check("the server hands a player's drop from the battle channel and their return to the presence of the players",
      $presence_calls, [[:away, 1], [:back, 1]])
check("and tells the DLL nobody gone meanwhile", [MGQ_MpBattlesSync::Channel.served_gone?, $live.asked("live.tick").last["gone"], MGQ_MpBattlesSync.guests_in], [false, [], [1, 2]])
MGQ_MpBattlesSync::Seats.presence(MGQ_MpOverworldSync::Peers::Peer.new(1, { "name" => "Me" }, nil, false), :gone)
$live.set("live.tick served", "left" => [1], "departed" => [[1, 1]])
check("until the presence tells they are gone, and takes them out as the DLL answers",
      [MGQ_MpBattlesSync::Channel.served_gone?, $live.asked("live.tick").last["gone"], MGQ_MpBattlesSync.guests_in], [false, [1], [2]])
$live.set("live.tick served", nil)
MGQ_MpBattlesServed.instance_variable_set(:@setup, { :starter => 1 })
$dll_calls.clear
MGQ_MpBattlesServed.tell_front_state
MGQ_MpBattlesServed.tell_front_state
$dll_entries << channel_entry("in", 1)
MGQ_MpBattlesServed.drain
MGQ_MpBattlesServed.tell_front_state
told = $dll_calls.select { |name, args| name == "served.send" && args[1]["battle"] == "front_state" }.map { |_, args| args[0] }
check("the server tells the starter its unchanged front state again once the starter comes onto the battle channel, as a tell before may not have reached it",
      told, [1, 1])
MGQ_MpBattlesServed.instance_variable_set(:@setup, nil)
MGQ_MpBattlesServed.instance_variable_set(:@server, nil)
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# The world's mods the starter runs, and its options of them, go with the setup.
module MGQ_MpWorldMods
  def self.served_mods; [["teamboostfix", "upload", "1.0", [["Team_Boost_Fix.rb", "a" * 64], ["bad", "x"]]], ["broken", 5], ["ownmod", "", "", []]]; end
  def self.served_settings; [["mod_rate", 2], ["mod_scale", 1.5]]; end
end
host_battle
text = MGQ_MpBattlesServed.setup_text([MGQ_MpBattlesCoop::Player.new(0, "Me", "1,2,3", [], 8)], nil)
check("the setup hands the DLL the world's mods the starter runs, with their files' hashes, and its options of them",
      [$written_facts["mods"], $written_facts["settings"]], [MGQ_MpWorldMods.served_mods, [["mod_rate", 2], ["mod_scale", { "float" => "1.5" }]]])
$read_facts = $written_facts.merge("mods" => [["teamboostfix", "upload", "1.0", { "Team_Boost_Fix.rb" => "a" * 64 }]])
setup = MGQ_MpBattlesServed.read_setup(text)
check("and takes them as the DLL reads them back", [setup[:mods], setup[:settings]],
      [[["teamboostfix", "upload", "1.0", { "Team_Boost_Fix.rb" => "a" * 64 }]], [["mod_rate", 2], ["mod_scale", { "float" => "1.5" }]]])
$read_facts = nil
check("a Classic world's setup carries no squad rules", setup[:squad], nil)
check("the setup carries the widths of the troop's pictures as the starter measures them, which the battle server has none of",
      setup[:widths], [[31, 160], [32, 160]])
$squad = { :luka => false, :formation => 0, :front => 4, :raid_front => 3 }
$rule_answers.set("squad.served", { "luka" => false, "formation" => 0, "front" => 4, "raid_front" => 3 })
setup = MGQ_MpBattlesServed.read_setup(MGQ_MpBattlesServed.setup_text([MGQ_MpBattlesCoop::Player.new(0, "Me", "1,2,3", [], 8)], nil))
check("a Raid World's carries the world's, which the server reads through the DLL",
      [setup[:squad], $rule_answers.asked("squad.served").last], [$squad, [["luka", false], ["formation", 0], ["front", 4], ["raid_front", 3]]])
$rule_answers.set("squad.served", nil)
$squad = nil
check("and the server plays one whose setup carries none by the defaults",
      MGQ_MpBattlesServed.default_squad, { :luka => false, :formation => 4, :front => 1, :raid_front => 1 })
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# A Float or a Symbol among the facts, which the bridge does not carry.
host_battle
$game_troop.members[0].screen_x = 320.5
text = MGQ_MpBattlesServed.setup_text([MGQ_MpBattlesCoop::Player.new(0, "Me", "1,2,3", [[0.25, :guard]], 8)], nil)
check("a Float or a Symbol among the facts crosses the bridge tagged, so the setup is still written",
      [text.empty?, $written_facts["enemies"][0][1], $written_facts["players"][0][3]], [false, { "float" => "320.5" }, [[{ "float" => "0.25" }, { "symbol" => "guard" }]]])
check("and any other object as its text, as the battle line wrote it", MGQ_MpBattlesSync::Wire.plain([1, nil, true, "a", (1..2)]), [1, nil, true, "a", "1..2"])
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# A setup C# does not read.
check("a setup C# does not read is none", MGQ_MpBattlesServed.read_setup("not a setup"), nil)

# Outside a world, and on the battle server.
in_world = MGQ_MpOverworldSync.method(:in_world?)
MGQ_MpOverworldSync.define_singleton_method(:in_world?) { false }
check("outside a world no battle goes to the server", MGQ_MpBattlesServed.available?, false)
MGQ_MpOverworldSync.define_singleton_method(:in_world?, in_world)
MGQ_MpBattlesServed.instance_variable_set(:@server, true)
check("nor on the battle server itself", MGQ_MpBattlesServed.available?, false)
MGQ_MpBattlesServed.instance_variable_set(:@server, nil)
