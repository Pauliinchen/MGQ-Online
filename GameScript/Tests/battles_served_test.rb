#----------------------------------------------------------------
#  battles_served_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Covers co-op battles the battle server hosts, battles_served.rbx with battles_coop.rbx and
# battles_sync.rbx, on a player's game: the starter handing a gathered battle to the server or
# hosting it when the relay refuses, a guest following, and the battle channel's entries, sends
# and end, through a stand-in for the DLL's mp_battle_* exports.

require_relative "battle_support"

# Stands in for the DLL's mp_battle_* exports: the calls are kept in $dll_calls, the battle's state
# is $dll_state, and the entries waiting on the channel are $dll_entries.
module MGQ_Multiplayer
  def self.available?; true; end
  module Link
    def self.function(name)
      ->(*args) { $dll_calls << [name, args.map { |arg| arg.is_a?(String) ? arg.chomp("\0") : arg }]; name == "mp_battle_open" ? ($dll_opens ? 1 : 0) : 1 }
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
  module GameData; def self.fingerprint; "1:data"; end; end
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
answer, = gather_with_friend(scene, friend, join)
check("a relay without a battle server leaves the battle to the starter, who sends the roster through the world room",
      [answer, sent_kinds.include?("roster"), sent_kinds.include?("serve"), MGQ_MpBattlesSync.role], [nil, true, false, :host])
check("after asking the relay once and letting go of the battle channel",
      $dll_calls.map(&:first), %w(mp_battle_serve mp_battle_close))
check("and no later battle of the session asks again", MGQ_MpBattlesServed.available?, false)
check("which the log tells", $log.grep(/did not take battle .* \(no_server\): the starter hosts it, and every later battle of this session/).size, 1)
MGQ_MpBattlesCoop.ended
MGQ_MpBattlesSync.finish
MGQ_MpBattlesServed.instance_variable_set(:@lasting_refusal, nil)

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
setup = MGQ_MpBattlesServed.read_setup(serve_call[1][3])
check("the setup names the troop, how the battle ends, the map and the level",
      [setup[:troop], setup[:escape], setup[:lose], setup[:map], setup[:level], setup[:raid]], [40, true, false, 5, 30, false])
check("its fingerprints", [setup[:scripts], setup[:data]], ["0badf00d", "1:data"])
check("its arranged players, the starter first", setup[:players].map { |player| [player.seat, player.name, player.builds] }, [[0, "Me", "1,2,3"], [2, "Friend", "7,8,9"]])
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

# The channel never opens.
$dll_state = "state=opening"
$dll_entries.clear
MGQ_MpBattlesServed::OPEN_FRAMES.times { MGQ_MpBattlesServed.drain }
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
$dll_opens = true
MGQ_MpBattlesSync.finish
MGQ_MpBattlesCoop.ended

# A setup of another format or without a troop.
check("a setup of another format or without a troop is not read",
      [MGQ_MpBattlesServed.read_setup(MGQ_MpBattlesSync::Wire.line([2, "", "", 40])), MGQ_MpBattlesServed.read_setup(MGQ_MpBattlesSync::Wire.line([1, "", "", "40"])), MGQ_MpBattlesServed.read_setup("")],
      [nil, nil, nil])

# Outside a world, and on the battle server.
in_world = MGQ_MpOverworldSync.method(:in_world?)
MGQ_MpOverworldSync.define_singleton_method(:in_world?) { false }
check("outside a world no battle goes to the server", MGQ_MpBattlesServed.available?, false)
MGQ_MpOverworldSync.define_singleton_method(:in_world?, in_world)
MGQ_MpBattlesServed.instance_variable_set(:@server, true)
check("nor on the battle server itself", MGQ_MpBattlesServed.available?, false)
MGQ_MpBattlesServed.instance_variable_set(:@server, nil)
