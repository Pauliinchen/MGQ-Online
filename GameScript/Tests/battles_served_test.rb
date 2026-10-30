#----------------------------------------------------------------
#  battles_served_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Checked that a String held as bytes crosses to C# as text
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
# and end, through a stand-in for the DLL's mp_battle_* exports.

require_relative "battle_support"
require_relative "rules_support"

# Stands in for the DLL's mp_battle_* exports: the calls are kept in $dll_calls, the battle's state
# is $dll_state, which a serve the relay refuses for the session ($lasting) names from then on, and
# the entries waiting on the channel are $dll_entries.
module MGQ_Multiplayer
  def self.available?; true; end
  module Link
    def self.function(name)
      lambda do |*args|
        $dll_calls << [name, args.map { |arg| arg.is_a?(String) ? arg.chomp("\0") : arg }]
        $dll_state = "#{$dll_state}\nlasting=#{$lasting}" if name == "mp_battle_serve" && $lasting
        name == "mp_battle_open" ? ($dll_opens ? 1 : 0) : 1
      end
    end
    def self.read(name, _size)
      name == "mp_battle_state" ? $dll_state.to_s : $dll_entries.shift.to_s
    end
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| key, value = line.split("=", 2); state[key] = value if value }
      state
    end
  end
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
# The DLL's front of a served battle: what the scripts hand it is kept, and it passes on hot
# requests of the battle $front_battle, sends what it is handed, and tells the server's state
# $front_state.
$front_calls = []
$world_bridge.answer("served.fronts") { |request| $front_calls << ["fronts", request]; request["coop"] == "hot" && request["bid"] == $front_battle }
$world_bridge.answer("served.forward") { |request| $front_calls << ["forward", request]; true }
$world_bridge.answer("served.left") { |request| $front_calls << ["left", request]; true }
$world_bridge.answer("served.front_state") { $front_state }
# The setup C# writes and reads: here the facts the script hands over, kept in $written_facts and
# as JSON, read back as C# reads them (a mod's files' hashes by path).
$world_bridge.answer("served.setup.write") { |facts| $written_facts = facts; JSON.generate(facts) }
$world_bridge.answer("served.setup.read") do |text|
  begin
    facts = JSON.parse(text)
    mods = facts["mods"].select { |mod| mod.is_a?(Array) && mod[0].is_a?(String) && !mod[0].empty? && mod[3].is_a?(Array) }
    facts["mods"] = mods.map { |key, kind, version, files| [key, kind, version, Hash[files.select { |pair| pair.is_a?(Array) && pair[1].to_s =~ /\A[0-9a-f]{64}\z/ }]] }
    facts["squad"] = Array(facts["squad"])
    facts
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
join = MGQ_MpBattlesSync::Wire.line(["7,8,9", [[50, 5], [60, 6], [70, 7]], 8])

# Gathers a co-op battle the friend joins, with the battle server answering as $dll_state says.
#
# @return [Array] What gather answered and the battle's id.
def gather_with_friend(scene, friend, join)
  BattleManager.setup(40, true, false)
  BattleManager.instance_variable_set(:@can_escape, true)
  BattleManager.instance_variable_set(:@can_lose, false)
  bid = MGQ_MpBattlesSync.battle_id
  $sent.clear
  $dll_calls.clear
  $frames = 0
  $inject = lambda { |frame| MGQ_MpBattlesSync.take(friend, { "battle" => "join", "bid" => bid, :payload => join }) if frame == 3 }
  answer = MGQ_MpBattlesCoop.gather(scene)
  $inject = nil
  [answer, bid]
end

# Tells the kinds of the battle's messages sent through the world room.
#
# @return [Array<String>] The kinds.
def sent_kinds
  $sent.map { |_seat, text| fields_of(text)["battle"] }.compact
end

# A relay without a battle server: the starter hosts, and asks no more this session.
$dll_state = "state=refused\ncode=no_server"
$lasting = "no_server"
answer, = gather_with_friend(scene, friend, join)
check("a relay without a battle server leaves the battle to the starter, who sends the roster through the world room",
      [answer, sent_kinds.include?("roster"), sent_kinds.include?("serve"), MGQ_MpBattlesSync.role], [nil, true, false, :host])
check("after asking the relay once and letting go of the battle channel",
      $dll_calls.map(&:first), %w(mp_battle_serve mp_battle_close))
check("and no later battle of the session asks again", MGQ_MpBattlesServed.available?, false)
check("which the log tells", $log.grep(/did not take battle .* \(no_server\): the starter hosts it, and every later battle of this session/).size, 1)
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish
$lasting = nil

# A busy battle server: this battle stays with the starter, the next asks again.
$dll_state = "state=refused\ncode=busy"
answer, = gather_with_friend(scene, friend, join)
check("a busy battle server leaves this battle to the starter", [answer, sent_kinds.include?("roster")], [nil, true])
check("and the next battle asks again", MGQ_MpBattlesServed.available?, true)
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish

# The DLL does not start asking: the starter hosts at once.
$dll_state = nil
failing = MGQ_MpBattlesServed::Link.method(:serve)
MGQ_MpBattlesServed::Link.define_singleton_method(:serve) { |*| false }
answer, = gather_with_friend(scene, friend, join)
MGQ_MpBattlesServed::Link.define_singleton_method(:serve, failing)
check("a DLL that does not start asking leaves the battle to the starter", [answer, sent_kinds.include?("roster")], [nil, true])
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish

# The battle server takes the battle.
$dll_state = "state=served"
answer, bid = gather_with_friend(scene, friend, join)
serve_call = $dll_calls.find { |name, _| name == "mp_battle_serve" }
check("a battle the server takes makes the starter its guest", [answer, MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.served?, MGQ_MpBattlesServed.starter?], [:guest, :guest, true, true])
check("asked for with the world, the battle and both players' seats", serve_call[1][0, 3], ["world-1", bid, "0,2"])
check("the starter hands C# the facts of the setup", JSON.parse(serve_call[1][3]).keys,
      %w(scripts data troop escape lose map rates enemies players level switches variables raid pool tiers starter squad mods settings widths))
setup = MGQ_MpBattlesServed.read_setup(serve_call[1][3])
check("the setup names the troop, how the battle ends, the map and the level",
      [setup[:troop], setup[:escape], setup[:lose], setup[:map], setup[:level], setup[:raid]], [40, true, false, 5, 30, false])
check("its fingerprints", [setup[:scripts], setup[:data]], ["0badf00d", "1:data"])
check("its arranged players, the starter first", setup[:players].map { |player| [player.seat, player.name, player.builds] }, [[0, "Me", "1,2,3"], [2, "Friend", "7,8,9"]])
check("the starter of a battle the server never started fights its encounter as its own", MGQ_MpBattlesCoop.never_got(:gone), :gone)
check("and the switches and variables that are set, these among them", [setup[:switches].include?(12), setup[:switches] - (1..200).select { |id| $game_switches[id] == true }, setup[:variables]], [true, [], [[150, 3]]])
serve = $sent.map { |seat, text| [seat, fields_of(text)] }.find { |_, fields| fields["battle"] == "serve" }
check("the guests are told to follow it to the server", [serve[0], MGQ_MpBattlesSync::Wire.parse(serve[1][:payload])], [2, [bid]])
check("no roster goes through the world room", sent_kinds.include?("roster"), false)
check("the starter opens the battle channel", [$dll_calls.find { |name, _| name == "mp_battle_open" }, MGQ_MpBattlesServed.channel], [["mp_battle_open", ["world-1", bid]], :opening])

# The battle channel opens and carries the server's roster.
$dll_entries << "kind=seat\nseat=0\n\n"
MGQ_MpBattlesServed.drain
check("the seat entry opens the channel", MGQ_MpBattlesServed.channel, :open)
$dll_entries << "kind=message\nseat=250\n\nbattle=roster\nbid=other\n\nwrong"
$dll_entries << "kind=message\nseat=250\n\nbattle=roster\nbid=#{bid}\n\nthe roster"
check("the server's message reaches the battle, one for another battle does not", MGQ_MpBattlesSync::Channel.take("roster"), "the roster")
check("which the log tells", $log.grep(/ignored roster from the battle channel: it is for another battle/).size, 1)

# The starter's messages go to the server over the channel.
$dll_calls.clear
$sent.clear
MGQ_MpBattlesSync::Channel.post("commands", "the commands")
check("a message of the battle goes to the server's seat over the channel, not the world room",
      [$dll_calls, $sent], [[["mp_battle_send", [250, "battle=commands\nbid=#{bid}\n\nthe commands"]]], []])

# The channel ends.
$dll_entries << "kind=closed\nseat=0\ncode=ended\n\n"
check("a closed entry ends the battle for the guest", [MGQ_MpBattlesServed.closed?, $log.grep(/the battle channel closed: ended/).size], [true, 1])
$dll_calls.clear
MGQ_MpBattlesSync.finish
check("finishing closes the ended channel at the DLL, which forgets it", [$dll_calls, MGQ_MpBattlesServed.channel, MGQ_MpBattlesServed.starter?, MGQ_MpBattlesSync.served?], [[["mp_battle_close", []]], nil, false, false])
MGQ_MpBattlesCoop.ended

# A guest follows the host to the server.
BattleManager.setup(40, true, false)
bid = MGQ_MpBattlesSync.battle_id
$dll_calls.clear
MGQ_MpBattlesServed.follow(MGQ_MpBattlesSync::Wire.line(["other"]))
check("a serve for another battle is ignored", [$dll_calls, MGQ_MpBattlesSync.served?, $log.grep(/ignored a serve for battle other/).size], [[], false, 1])
MGQ_MpBattlesServed.follow(MGQ_MpBattlesSync::Wire.line([bid]))
check("one for the battle makes the player the server's guest, not its starter",
      [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.served?, MGQ_MpBattlesServed.starter?, $dll_calls], [:guest, true, false, [["mp_battle_open", ["world-1", bid]]]])

# The channel never opens: the DLL ends it in time.
$dll_state = "state=opening"
$dll_entries.clear
MGQ_MpBattlesServed.drain
check("a channel still opening waits", MGQ_MpBattlesServed.channel, :opening)
$dll_entries << "kind=closed\nseat=0\ncode=open_timeout\n\n"
MGQ_MpBattlesServed.drain
check("a channel that does not open in time ends", [MGQ_MpBattlesServed.channel, $log.grep(/did not open within 10 s/).size], [:closed, 1])
$dll_calls.clear
MGQ_MpBattlesSync.finish
check("and is closed at the DLL", $dll_calls, [["mp_battle_close", []]])
MGQ_MpBattlesCoop.ended

# The DLL does not open the channel.
BattleManager.setup(40, true, false)
$dll_opens = false
MGQ_MpBattlesServed.follow(MGQ_MpBattlesSync::Wire.line([MGQ_MpBattlesSync.battle_id]))
check("a channel the DLL does not open ends the battle for the guest", [MGQ_MpBattlesServed.channel, MGQ_MpBattlesServed.closed?], [:closed, true])
$frames = 0
ending = MGQ_MpBattlesCoop.join(scene)
check("a guest whose served battle ends before its roster never fights it alone, but goes back to the map, told why",
      [ending, MGQ_MpBattlesSync.take_missed], [:broken, "The server's battle ended before you could join."])
$dll_opens = true
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# The starter as the served battle's front: the DLL decides which requests to join go to the
# server, sends them with the states and fields the script hands it, and keeps the server's state.
$dll_state = "state=served"
_answer, bid = gather_with_friend(scene, friend, join)
$front_battle = bid
$dll_entries << "kind=seat\nseat=0\n\n"
MGQ_MpBattlesServed.drain
joiner = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "id-joiner", "name" => "Joiner", "map" => "5", "scene" => "map", "x" => "3" }, nil, false)
MGQ_MpOverworldSync::Peers.all.push(joiner)
$front_calls.clear
MGQ_MpBattlesCoop.take(joiner, { "coop" => "hot", "bid" => bid, "troop" => "5", "enemies" => "31:320:300:0", "seats" => "2", "map" => "5" })
forward = $front_calls.find { |kind, _| kind == "forward" }
check("the starter asks the DLL whether a request to join its served battle goes to the server, with its kind and battle",
      $front_calls.first, ["fronts", { "coop" => "hot", "bid" => bid }])
check("and hands it the asking player's seat, the id and name of its player and of those it brings along, and the request's fields",
      [forward[1]["seat"], forward[1]["states"], MGQ_MpBattlesServed.hash_of(forward[1]["fields"]).values_at("coop", "troop", "seats")],
      [4, [[4, [["id", "id-joiner"], ["name", "Joiner"]]], [2, [["id", "id-friend"], ["name", "Friend"]]]], ["hot", "5", "2"]])
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
$dll_entries << "kind=message\nseat=2\n\nbattle=front_out\nbid=#{bid}\n\n" + MGQ_MpBattlesSync::Wire.line([4, "map_coop=hot_ok\n\n"])
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
BattleManager.setup(40, true, false)
bid = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesServed.instance_variable_set(:@server, true)
MGQ_MpBattlesServed.instance_variable_set(:@setup, { :starter => 0, :players => [] })
MGQ_MpBattlesServed.instance_variable_set(:@channel, :open)
taken = []
coop_take = MGQ_MpBattlesCoop.method(:take)
MGQ_MpBattlesCoop.define_singleton_method(:take) { |peer, message| taken << [peer.seat, peer.state["name"], message["coop"], message["troop"]] }
request = MGQ_MpBattlesSync::Wire.line([7, [[7, [["id", "id-late"], ["name", "Late"]]]], [["coop", "hot"], ["bid", bid], ["troop", "5"]]])
$dll_entries << "kind=message\nseat=0\n\nbattle=front_in\nbid=#{bid}\n\n#{request}"
$dll_entries << "kind=message\nseat=3\n\nbattle=front_in\nbid=#{bid}\n\n#{request}"
MGQ_MpBattlesServed.drain
check("the server takes a request its starter passed on, its player known by the state passed with it, and one from anyone else not",
      [taken, MGQ_MpOverworldSync::Peers.at(7) && MGQ_MpOverworldSync::Peers.at(7).state], [[[7, "Late", "hot", "5"]], { "id" => "id-late", "name" => "Late" }])
$dll_entries << "kind=message\nseat=0\n\nbattle=front_left\nbid=#{bid}\n\n" + MGQ_MpBattlesSync::Wire.line([7])
MGQ_MpBattlesServed.drain
check("and forgets a player who left the world, as the starter tells", MGQ_MpOverworldSync::Peers.at(7), nil)
MGQ_MpBattlesCoop.define_singleton_method(:take, coop_take)
$dll_calls.clear
check("the server's message to the world's room goes to its starter", MGQ_MpBattlesServed.front_out(4, "map_coop=hot_no\n\n"), true)
out = $dll_calls.find { |name, _| name == "mp_battle_send" }[1]
check("over the battle channel", [out[0], fields_of(out[1])["battle"], MGQ_MpBattlesSync::Wire.parse(fields_of(out[1])[:payload])], [0, "front_out", [4, "map_coop=hot_no\n\n"]])
MGQ_MpBattlesServed.instance_variable_set(:@server, nil)
MGQ_MpBattlesServed.instance_variable_set(:@setup, nil)
MGQ_MpBattlesServed.instance_variable_set(:@channel, nil)
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# A player the server takes in late comes onto its channel, by its invite or its answer.
$dll_calls.clear
MGQ_MpBattlesCoop.accept(friend, { "coop" => "invite", "bid" => "late1", "troop" => "40", "escape" => "1", "lose" => "0", "seats" => "0", "map" => "5", "hot" => "1", "served" => "1" })
check("an invite of a served battle makes the player the server's guest",
      [MGQ_MpBattlesSync.role, MGQ_MpBattlesSync.served?, $dll_calls.find { |name, _| name == "mp_battle_open" }], [:guest, true, ["mp_battle_open", ["world-1", "late1"]]])
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.join_world(:guest, "late2", [0], "Friend")
$dll_calls.clear
MGQ_MpBattlesHotjoin.join_late("escape" => true, "lose" => false, "release" => [], "stays_out" => [], "host" => { "escape" => true, "lose" => false, "rates" => "", "served" => true })
check("and so does a served battle's answer to the player's encounter", [MGQ_MpBattlesSync.served?, $dll_calls.find { |name, _| name == "mp_battle_open" }], [true, ["mp_battle_open", ["world-1", "late2"]]])
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# A guest of the server sends to the server alone, also once the roster names the other players,
# and hears through it of one who leaves.
$dll_state = "state=served"
_answer, bid = gather_with_friend(scene, friend, join)
$dll_entries << "kind=seat\nseat=0\n\n"
MGQ_MpBattlesServed.drain
MGQ_MpBattlesCoop.instance_variable_set(:@players, [MGQ_MpBattlesCoop::Player.new(0, "Me", "", [], 8), MGQ_MpBattlesCoop::Player.new(2, "Friend", "", [], 8)])
$dll_calls.clear
MGQ_MpBattlesSync::Channel.post("commands", "x")
check("a guest's message goes to the server's seat alone, never to another player's", $dll_calls.map { |name, args| [name, args[0]] }, [["mp_battle_send", 250]])
$notices = []
$dll_entries << "kind=message\nseat=250\n\nbattle=departed\nbid=#{bid}\n\n" + MGQ_MpBattlesSync::Wire.line([2])
MGQ_MpBattlesServed.drain
check("the server's word that a player left shows as their own leave would", $notices.grep(/Friend left the battle/).size, 1)
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended
BattleManager.setup(40, true, false)
bid = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesServed.instance_variable_set(:@server, true)
MGQ_MpBattlesSync.serve_over_channel(:host, bid, [1, 2], "the players")
$dll_calls.clear
MGQ_MpBattlesSync.take_served(1, { "battle" => "leave", "bid" => bid, :payload => "" })
departed = $dll_calls.select { |name, _| name == "mp_battle_send" }.map { |_, args| [args[0], fields_of(args[1])["battle"], MGQ_MpBattlesSync::Wire.parse(fields_of(args[1])[:payload])] }
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
MGQ_MpBattlesCoop.settle(scene)
check("the last player in the server's battle fights on there, which no player of its own takes over",
      [formed, aborted, MGQ_MpBattlesSync.role, $log.grep(/goes on alone/)], [[[2]], [], :host, []])
MGQ_MpBattlesSync.guest_left(2)
MGQ_MpBattlesCoop.settle(scene)
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
BattleManager.setup(40, true, false)
bid = MGQ_MpBattlesSync.battle_id
MGQ_MpBattlesServed.instance_variable_set(:@server, true)
MGQ_MpBattlesSync.serve_over_channel(:host, bid, [1, 2], "the players")
MGQ_MpBattlesServed.instance_variable_set(:@channel, :open)
$dll_state = "state=open\nin=1,2\nout="
$presence_calls = []
$dll_entries << "kind=out\nseat=1\n\n" << "kind=in\nseat=1\n\n"
MGQ_MpBattlesServed.drain
check("the server hands a player's drop from the battle channel and their return to the presence of the players",
      $presence_calls, [[:away, 1], [:back, 1]])
check("and keeps them in the battle meanwhile", [MGQ_MpBattlesSync::Channel.served_gone?, MGQ_MpBattlesSync.guests_in], [false, [1, 2]])
MGQ_MpBattlesSync::Seats.presence(MGQ_MpOverworldSync::Peers::Peer.new(1, { "name" => "Me" }, nil, false), :gone)
check("until the presence tells they are gone", [MGQ_MpBattlesSync::Channel.served_gone?, MGQ_MpBattlesSync.guests_in], [false, [2]])
MGQ_MpBattlesServed.instance_variable_set(:@server, nil)
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# The world's mods the starter runs, and its options of them, go with the setup.
module MGQ_MpWorldMods
  def self.served_mods; [["teamboostfix", "upload", "1.0", [["Team_Boost_Fix.rb", "a" * 64], ["bad", "x"]]], ["broken", 5], ["ownmod", "", "", []]]; end
  def self.served_settings; "mod_rate=i:2"; end
end
BattleManager.setup(40, true, false)
setup = MGQ_MpBattlesServed.read_setup(MGQ_MpBattlesServed.setup_text([MGQ_MpBattlesCoop::Player.new(0, "Me", "1,2,3", [], 8)], nil))
check("the setup names the world's mods the starter runs, with their files' hashes, and its options of them",
      [setup[:mods], setup[:settings]], [[["teamboostfix", "upload", "1.0", { "Team_Boost_Fix.rb" => "a" * 64 }], ["ownmod", "", "", {}]], "mod_rate=i:2"])
check("a Classic world's setup carries no squad rules", setup[:squad], nil)
check("the setup carries the widths of the troop's pictures as the starter measures them, which the battle server has none of",
      setup[:widths], [[31, 160], [32, 160]])
$squad = { :luka => false, :formation => 0, :front => 4, :raid_front => 3 }
setup = MGQ_MpBattlesServed.read_setup(MGQ_MpBattlesServed.setup_text([MGQ_MpBattlesCoop::Player.new(0, "Me", "1,2,3", [], 8)], nil))
check("a Raid World's carries the world's", setup[:squad], $squad)
$squad = nil
check("and the server plays one whose setup carries none by the defaults",
      MGQ_MpBattlesServed.default_squad, { :luka => false, :formation => 4, :front => 1, :raid_front => 1 })
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# A Float or a Symbol among the facts, which the bridge does not carry.
BattleManager.setup(40, true, false)
$game_troop.members[0].screen_x = 320.5
text = MGQ_MpBattlesServed.setup_text([MGQ_MpBattlesCoop::Player.new(0, "Me", "1,2,3", [[0.25, :guard]], 8)], nil)
check("a Float or a Symbol among the facts crosses the bridge tagged, so the setup is still written",
      [text.empty?, $written_facts["enemies"][0][1], $written_facts["players"][0][3]], [false, { "float" => "320.5" }, [[{ "float" => "0.25" }, { "symbol" => "guard" }]]])
check("and any other object as its text, as the battle line wrote it", MGQ_MpBattlesServed.plain_fact([1, nil, true, "a", (1..2)]), [1, nil, true, "a", "1..2"])
check("a String the game holds as bytes crosses as text, which C# reads every fact's String as",
      MGQ_MpBattlesServed.plain_fact(["mod_rate=i:2".force_encoding("ASCII-8BIT")]).map(&:encoding), [Encoding::UTF_8])
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
