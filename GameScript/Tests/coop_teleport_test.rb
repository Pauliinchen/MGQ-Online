#----------------------------------------------------------------
#  coop_teleport_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-11: Checked that a request to another member is named in the line above the player's head with the seconds it stands for still, and one to the leader not
#                            - Stood in for the line above the player's head with its doings and lapses
#      Paulinchen  2026-10-10: Checked that an allowed teleport waits a minute for a busy player, as long as the request stood
#                            - Created
#
#----------------------------------------------------------------

# Covers coop_teleport.rbx: a member teleports to the party's leader at once, to any other member
# once that member allows it; a request is declined, taken back, replaced, runs out and goes with a
# loaded save or the world's close.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
module Graphics; def self.frame_count; $frame_count; end; def self.brightness; 255; end; end
class Game_Interpreter; def execute_command; end; end
class Game_Map; attr_accessor :map_id; def initialize; @map_id = 3; end; def update(main = false); end; end
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
module MGQ_MpCoopEvents; def self.pvp_running?; false; end; end
class Scene_Map; def update_call_menu; end; end
module DataManager; def self.extract_save_contents(contents); end; end
# The line above the player's head, whose lapse stands in as the seconds left, which the checks read.
module MGQ_MpActions
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)
  def self.own_doing_from(&doing); ($doings ||= []) << doing; end
  def self.lapse_in(frames); frames / 60.0; end
  def self.lapse_at(since, frames); lapse_in(since + frames - Graphics.frame_count); end
  def self.offer(offers); $offers = offers; end
end
module MGQ_MpOverworldSync
  module Peers
    Peer = Struct.new(:seat, :state)
    def self.all; $peers; end
  end
  module Me; def self.id; "me"; end; end
  def self.on_tick(&block); ($ticks ||= []) << block; end
  def self.state_fields(&block); $state_fields = block; end
  def self.on_observe(&block); $observe = block; end
  def self.notice(text); $notices << text; end
  def self.who(peer); peer == :me ? "the player" : peer.state["name"].to_s; end
  def self.in_world?; true; end
  def self.map_free?; $map_free; end
end
module MGQ_MpCoop
  NAMED_INVITE_FRAMES = 3600
  INVITE_COLOR = :invite
  module Party
    def self.members; $peers.select { |peer| member?(peer.state) }; end
    def self.member?(state); state["party"] == "p1"; end
  end
  def self.in_party?; true; end
  def self.party_leader; $leader; end
  def self.party_leading?; $leader == :me; end
  def self.tell(seat, field, value, fields = {}); $sent << [seat, { field => value }.merge(fields)]; true; end
  def self.route(field, &handler); $route = [field, handler]; end
  def self.random_id(length); $nonce = $nonce.to_i + 1; "n#{$nonce}"; end
end
module MGQ_MpStoryState; WARP_BAN = 100; end

load_script "coop_scope"
load_script "coop_gather"
load_script "coop_teleport"

teleport = MGQ_MpCoopTeleport
$frame_count = 1000
$sent = []
$notices = []
$game_switches = {}
$game_map = Game_Map.new
$game_player = Game_Player.new
leader = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "l", "name" => "Leader", "party" => "p1", "map" => "9", "x" => "10", "y" => "10" })
friend = MGQ_MpOverworldSync::Peers::Peer.new(3, { "id" => "f", "name" => "Friend", "party" => "p1", "map" => "7", "x" => "4", "y" => "4" })
stranger = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "s", "name" => "Stranger", "party" => "p2", "map" => "7", "x" => "4", "y" => "4" })
$peers = [leader, friend, stranger]
$leader = leader
own_state = lambda { $state_fields.call["tpask"] }
take = lambda { |peer, fields| $route[1].call(peer, fields.merge(MGQ_MpCoopTeleport::FIELD => fields["kind"])) }

check("the overview offers no teleport to a player outside the party", $offers.peer_option(stranger), nil)
check("a teleport to the leader needs no asking", [$offers.peer_option(leader).text, $offers.peer_option(friend).text],
      ["Teleport to Leader", "Ask to teleport to Friend"])
check("each closes the World overview", $offers.peer_option(friend).leaves, true)

# A member teleports to the leader, whose game lets them come at once.
$offers.peer_option(leader).run.call
check("the request names the leader in the player's state", own_state.call, "l:n1")
check("and says the player teleports", $notices.last, "Teleporting to Leader . . .")
check("without a line above the player's head, since the leader answers at once", teleport.own_doing, nil)
check("asking again while it stands is refused", $offers.peer_option(leader).refusal, "Your request to Leader stands.")
take.call(friend, { "kind" => "allow", "nonce" => "n1", "map" => "5", "x" => "1", "y" => "1", "d" => "2" })
check("an answer from another member is ignored", own_state.call, "l:n1")
take.call(leader, { "kind" => "allow", "nonce" => "n0", "map" => "5", "x" => "1", "y" => "1", "d" => "2" })
check("and one to an older request", own_state.call, "l:n1")
take.call(leader, { "kind" => "allow", "nonce" => "n1", "map" => "9", "x" => "10", "y" => "10", "d" => "4", "warp_ban" => "1" })
check("the leader's answer brings the player over once free", [MGQ_MpCoopGather.coming?, MGQ_MpCoopGather.pending_call[:place], MGQ_MpCoopGather.pending_call[:warp_ban]],
      [true, [9, 10, 10, 4], true])
check("and ends the request", own_state.call, "")
$map_free = false
$frame_count += 20 * 60
MGQ_MpCoopGather.update
check("an answer that comes while the player is busy for 20 s still stands", MGQ_MpCoopGather.coming?, true)
$map_free = true
MGQ_MpCoopGather.update
check("and teleports the player once free", [$game_player.reserved, MGQ_MpCoopGather.coming?], [[9, 10, 10, 4], false])
MGQ_MpCoopGather.come_to("Leader", [9, 10, 10, 4], nil)
$map_free = false
$frame_count += MGQ_MpCoopGather::ASKED_LAPSE_FRAMES
check("one that waits a minute for the player lapses with a notice",
      [MGQ_MpCoopGather.coming?, MGQ_MpCoopGather.pending_call, $notices.last], [false, nil, "You were too busy to teleport to Leader."])
$game_player.reserved = nil
MGQ_MpCoopGather.forget

# As leader, the player lets a member come at once.
$leader = :me
friend.state["tpask"] = "me:x1"
$sent.clear
$observe.call(friend)
check("the leader answers a member's request with where they stand", $sent.map { |seat, f| [seat, f["ptp"], f["nonce"], f["map"]] }, [[3, "allow", "x1", 3]])
$observe.call(friend)
check("once", $sent.size, 1)
check("and shows no request to allow", $offers.notice_of(friend), nil)
stranger.state["tpask"] = "me:y1"
$observe.call(stranger)
check("a player outside the party is never answered", $sent.size, 1)
check("nor shown", [$offers.notice_of(stranger), $offers.call_of(stranger)], [nil, nil])

# Another member's request waits until the player allows it.
$leader = leader
friend.state["tpask"] = "me:x2"
$sent.clear
$observe.call(friend)
check("a member who does not lead answers nothing by themselves", $sent, [])
notice = $offers.notice_of(friend)
check("the notification box shows the request", [notice.text, notice.action, notice.color], ["Friend asks to teleport to you", "Allow", :invite])
check("as does the World overview", [$offers.call_of(friend), $offers.peer_option(friend).text], [["Asks to teleport to you", :invite], "Allow teleport"])
notice.take.call
check("allowing tells the member where the player stands", $sent.map { |seat, f| [seat, f["ptp"], f["nonce"]] }, [[3, "allow", "x2"]])
check("after which the request shows no more", [$offers.notice_of(friend), $offers.peer_option(friend).text], [nil, "Ask to teleport to Friend"])
friend.state["tpask"] = "me:x3"
$sent.clear
$offers.notice_of(friend).decline.call
check("declining tells the member", $sent.map { |seat, f| [seat, f["ptp"], f["nonce"]] }, [[3, "deny", "x3"]])
friend.state["tpask"] = "me:x4"
$sent.clear
$offers.notice_of(friend).take.call
$offers.notice_of(friend)
check("a request answered once is never answered twice", $sent.size, 1)
friend.state["tpask"] = ""

# The player asks another member.
$offers.peer_option(friend).run.call
check("asking another member names them in the state", own_state.call, "f:n2")
check("and says they have to allow it", $notices.last, "You asked Friend to let you teleport to them.")
check("the line above the player's head names the request with the minute it stands for, through the doings of every script here",
      $doings.map { |doing| doing.call }, [nil, ["Asking Friend to teleport", 60.0]])
check("the player's own row may take it back", $offers.own_options.map(&:text), ["Stop asking to teleport"])
take.call(friend, { "kind" => "deny", "nonce" => "n2" })
check("a declined request ends with a notice", [own_state.call, $notices.last, MGQ_MpCoopGather.coming?], ["", "Friend declined your teleport.", false])
$offers.peer_option(friend).run.call
take.call(friend, { "kind" => "allow", "nonce" => "n3", "map" => "7", "x" => "4", "y" => "4", "d" => "2" })
check("an allowed one brings the player over", [MGQ_MpCoopGather.pending_call[:name], $notices.last], ["Friend", "Teleporting to Friend . . ."])
MGQ_MpCoopGather.forget

$offers.peer_option(friend).run.call
$offers.peer_option(leader).run.call
check("a newer request replaces the one before", own_state.call, "l:n5")
$offers.own_options.first.run.call
check("taking it back clears the state", [own_state.call, $offers.own_options], ["", []])

$offers.peer_option(friend).run.call
$frame_count += MGQ_MpCoopTeleport::ASK_FRAMES / 2
check("the line counts the request down", teleport.own_doing, ["Asking Friend to teleport", 30.0])
$frame_count += MGQ_MpCoopTeleport::ASK_FRAMES / 2
$ticks.each { |tick| tick.call(true) }
check("a request nobody answers runs out with a notice", [own_state.call, $notices.last], ["", "Friend did not answer your teleport."])
check("and leaves the line", teleport.own_doing, nil)
$offers.peer_option(friend).run.call
friend.state["party"] = "p2"
$ticks.each { |tick| tick.call(true) }
check("one to a member who left the party ends", own_state.call, "")
friend.state["party"] = "p1"
$offers.peer_option(friend).run.call
DataManager.extract_save_contents({})
check("a loaded save takes it back", own_state.call, "")
$offers.peer_option(friend).run.call
$ticks.each { |tick| tick.call(false) }
check("as does the world's close", own_state.call, "")

$game_map.map_id = 7
$game_player.x = 5
$game_player.y = 4
check("the player standing near a member already cannot teleport to them", [$offers.peer_option(friend).run, $offers.peer_option(friend).refusal], [nil, "You are with Friend already."])
