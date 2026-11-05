#----------------------------------------------------------------
#  coop_teleport_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Read the scripts' clock from $frame_count
#      Paulinchen  2026-11-01: Dropped the stand-in of a lapse after a frame count, which no script asks for any more
#      Paulinchen  2026-10-31: Expected places and teleports without a warp ban
#      Paulinchen  2026-10-30: Checked the script's wiring to the DLL's requests on the stand-in bridge
#      Paulinchen  2026-10-28: Read the frames of a teleport from the gather stand-in
#      Paulinchen  2026-10-11: Checked that the line above the head names a request to another member
#                            - Stood in for the line above the player's head with its doings and lapses
#      Paulinchen  2026-10-10: Checked that an allowed teleport waits a minute for a busy player
#                            - Created
#
#----------------------------------------------------------------

# Covers coop_teleport.rbx over the DLL's requests (MGQOnline.Game.Tests covers their rules): the
# player's place handed over each frame, the offers and the state read from the DLL's view, the
# actions asked of the DLL, and a member's allow bringing the player over.

require_relative "support"
require_relative "rules_support"
require_relative "party_support"

# Stands in for the mod's log, printing each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
# Stands in for RGSS graphics; the scripts' clock reads $frame_count.
module Graphics; def self.brightness; 255; end; end
clock_from { $frame_count }
# Stands in for the game's event interpreter.
class Game_Interpreter; def execute_command; end; end
# Stands in for the game's map.
class Game_Map; attr_accessor :map_id; def initialize; @map_id = 3; end; def update(main = false); end; end
# Stands in for the game's player, who notes the transfer reserved.
class Game_Player
  attr_accessor :x, :y
  def initialize; @x = 0; @y = 0; end
  def direction; 2; end
  def encounter; true; end
  def movable?; true; end
  def perform_transfer; end
  def transfer?; false; end
  def make_encounter_count; end
  attr_accessor :reserved
  def reserve_transfer(*args); @reserved = args; end
end
# Stands in for the shared story's events, with no PvP battle running.
module MGQ_MpCoopEvents; def self.pvp_running?; false; end; end
# Stands in for the game's map scene.
class Scene_Map; def update_call_menu; end; end
# Stands in for the game's save loading.
module DataManager; def self.extract_save_contents(contents); end; end
# Stands in for the player's actions: the line above the player's head, whose lapses are the seconds
# left, and the offers, kept in $offers.
module MGQ_MpActions
  # An option of a row in the World overview.
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  # An entry of the notification box.
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)
  def self.own_doing_from(&doing); ($doings ||= []) << doing; end
  def self.lapse_in(frames); frames / 60.0; end
  def self.offer(offers); $offers = offers; end
end
# Stands in for the world's sync, keeping the handlers the scripts register and the notices shown.
module MGQ_MpOverworldSync
  # The other players in the world, kept in $peers.
  module Peers
    # Another player: their seat and the state they told.
    Peer = Struct.new(:seat, :state)
    def self.all; $peers; end
  end
  # The player, whose id is "me".
  module Me; def self.id; "me"; end; end
  def self.on_tick(&block); ($ticks ||= []) << block; end
  def self.state_fields(&block); $state_fields = block; end
  def self.notice(text); $notices << text; end
  def self.who(peer); peer == :me ? "the player" : peer.state["name"].to_s; end
  def self.in_world?; true; end
  def self.map_free?; $map_free; end
end
# Stands in for the party, led by $leader, whose messages land in $sent.
module MGQ_MpCoop
  # Color of the invite line.
  INVITE_COLOR = :invite
  # The party: every player whose state names party "p1".
  module Party
    def self.members; $peers.select { |peer| member?(peer.state) }; end
    def self.member?(state); state["party"] == "p1"; end
  end
  def self.in_party?; true; end
  def self.party_leader; $leader; end
  def self.party_leading?; $leader == :me; end
  def self.tell(seat, field, value, fields = {}); $sent << [seat, { field => value }.merge(fields)]; true; end
  def self.route(field, &handler); end
end

load_script "coop_scope"
load_script "coop_gather"
load_script "coop_teleport"
fake = answer_party(open_rules_bridge)

teleport = MGQ_MpCoopTeleport
tick = lambda { |in_world| $ticks.each { |each| each.call(in_world) } }
$frame_count = 1000
$sent = []
$notices = []
$game_switches = {}
$game_map = Game_Map.new
$game_player = Game_Player.new
leader = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "l", "name" => "Leader", "party" => "p1" })
friend = MGQ_MpOverworldSync::Peers::Peer.new(3, { "id" => "f", "name" => "Friend", "party" => "p1" })
$peers = [leader, friend]
$leader = leader

tick.call(false)
check("outside a world the script asks the DLL nothing and offers nothing", [$teleport_calls, $offers.peer_option(friend), $state_fields.call], [[], nil, { "tpask" => "" }])

tick.call(true)
check("each frame in a world hands the DLL where the player stands", $teleport_calls.last, ["tp.view", { "map" => 3, "x" => 0, "y" => 0, "d" => 2 }])
check("and offers each member the teleport the view names", [$offers.peer_option(leader).text, $offers.peer_option(friend).text], ["Teleport to Leader", "Ask to teleport to Friend"])
check("each closing the World overview", $offers.peer_option(friend).leaves, true)
check("the wheel's teleport to the leader is the same", teleport.option(leader).text, "Teleport to Leader")
$offers.peer_option(friend).run.call
check("choosing it asks the DLL by the member's seat", $teleport_calls.last, ["tp.ask", 3])

# The DLL keeps a request of the player and one of the friend's.
$teleport_view = {
  "tpask" => "f:n1",
  "doing" => { "text" => "Asking Friend to teleport", "ends" => MGQ_Multiplayer::Bridge.frame_number + 1800 }, "own" => ["Stop asking to teleport"],
  "members" => { 3 => { "text" => "Ask to teleport to Friend", "refusal" => "Your request to Friend stands.", "request" => "x1", "allow" => "Allow teleport",
                        "call" => "Asks to teleport to you", "notice" => "Friend asks to teleport to you", "action" => "Allow" } },
}
tick.call(true)
check("the state tells the request the DLL keeps", $state_fields.call, { "tpask" => "f:n1" })
check("the line above the head counts it down by the bridge's frames", $doings.map { |doing| doing.call }.compact, [["Asking Friend to teleport", 30.0]])
check("the wheel's teleport is closed with the DLL's reason", [teleport.option(friend).run, teleport.option(friend).refusal], [nil, "Your request to Friend stands."])
check("the World overview shows the friend's request", [$offers.call_of(friend), $offers.peer_option(friend).text], [["Asks to teleport to you", :invite], "Allow teleport"])
notice = $offers.notice_of(friend)
check("as does the notification box", [notice.key, notice.text, notice.color, notice.action, notice.mark], [[:teleport, 3], "Friend asks to teleport to you", :invite, "Allow", "x1"])
check("but not for a member without one", $offers.notice_of(leader), nil)
notice.take.call
check("allowing hands the DLL the seat and where the player stands", $teleport_calls.last, ["tp.allow", { "seat" => 3, "place" => { "map" => 3, "x" => 0, "y" => 0, "d" => 2 } }])
notice.decline.call
check("declining hands the DLL the seat", $teleport_calls.last, ["tp.decline", 3])
fake.answer("tp.allow") { |_request| raise FakeBridge::BadRequest, "No player sits at seat 3." }
notice.take.call
check("an action the DLL fails keeps the view it answered last", [$state_fields.call, $offers.notice_of(friend)&.text], [{ "tpask" => "f:n1" }, "Friend asks to teleport to you"])
answer_teleports(fake)
$offers.own_options.first.run.call
check("the own row's choice takes the request back", $teleport_calls.last, ["tp.stop", "the player stopped asking"])
DataManager.extract_save_contents({})
check("a loaded save makes the DLL forget it", $teleport_calls.last, ["tp.forget", "a save was loaded"])
$teleport_view = nil

# A member lets the player come.
fake.post("tp.allowed", { "name" => "Friend", "map" => 7, "x" => 4, "y" => 4, "d" => 2 })
fake.post("tp.notice", "Teleporting to Friend . . .")
$map_free = false
MGQ_Multiplayer::Bridge.frame
check("the DLL's allow brings the player over once free", [MGQ_MpCoopGather.coming?, MGQ_MpCoopGather.pending_call[:place]], [true, [7, 4, 4, 2]])
check("with the DLL's notice", $notices.last, "Teleporting to Friend . . .")
$map_free = true
MGQ_MpCoopGather.update
check("and teleports the player once free", [$game_player.reserved, MGQ_MpCoopGather.coming?], [[7, 4, 4, 2], false])
