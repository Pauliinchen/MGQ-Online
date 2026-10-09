#----------------------------------------------------------------
#  coop_gather_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Stood in for the warp ban of story_state.rbx, which names it now
#                            - Stood in for MGQ_MpCoopEvents.tell_each, through which the story calls those it takes along in one message
#                            - Checked that the story calls those it takes along in one message, keeps them through a moment between its events, and names its teller as the one the player follows
#                            - Stood in for MGQ_MpOverworldSync::Peers.all, among whom the teller is found now
#      Paulinchen  2026-10-08: Checked a Raid World: nobody is gathered, everyone on the map follows where the story moves its teller, only a player whose story matches stands still, and a teleport goes to where the story was told
#                            - Checked that the story keeps telling the players it took along until they arrive, and that a teleport to the story takes over the warp ban there
#                            - Checked that a teleport to the story goes to the endpoint the relay keeps, where this game saw the story told only while the relay keeps none
#      Paulinchen  2026-10-06: Created
#
#----------------------------------------------------------------

# Covers coop_gather.rbx where time and the world end what it waits for: a leader's call lapses, and
# a loaded save or the world closing forgets the calls, the question where the leader stands and the
# hold, since a loaded save sets the frame count back. In a Raid World nobody is gathered, and a
# teleport goes to the story.

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
end
class Scene_Map; def update_call_menu; end; end
module DataManager; def self.extract_save_contents(contents); end; end
module MGQ_MpActions; def self.own_line_from(&line); end; end
module MGQ_MpOverworldSync
  module Peers; Peer = Struct.new(:seat, :state); end
  def self.on_tick(&block); $tick = block; end
  def self.notice(text); ($notices ||= []) << text; end
end
module MGQ_MpCoop
  module Party; def self.members; [$member]; end; end
  def self.party_leader; $leader; end
  def self.party_leading?; $leader == :me; end
  def self.in_party?; true; end
end
module MGQ_MpCoopEvents
  def self.pvp_running?; false; end
  def self.tell(seat, kind, fields = {}); ($sent ||= []) << [seat, kind]; true; end
end

load_script "coop_scope"
load_script "coop_gather"

gather = MGQ_MpCoopGather
$game_map = Game_Map.new
$game_player = Game_Player.new
$leader = MGQ_MpOverworldSync::Peers::Peer.new(2, { "name" => "Leader", "map" => "9", "x" => "10", "y" => "10" })
place = [9, 10, 10, 2]
$frame_count = 5000

gather.called($leader, place)
check("a member the leader calls is coming", gather.coming?, true)
$frame_count += MGQ_MpCoopGather::CALL_LAPSE_FRAMES
check("until the calls stop", gather.coming?, false)

gather.called($leader, place)
$frame_count = 100
check("a call from before a loaded save's lower frame count is long past", gather.coming?, false)

gather.called($leader, place)
DataManager.extract_save_contents({})
check("a loaded save forgets the call", gather.coming?, false)

gather.called($leader, place)
$tick.call(true)
check("an open world keeps it", gather.coming?, true)
$tick.call(false)
check("the world closing forgets it", gather.coming?, false)

gather.join_leader
check("a member asks the leader where they stand", $sent.last, [2, "where"])
DataManager.extract_save_contents({})
gather.answered($leader, place, false)
check("and a loaded save forgets the question", gather.coming?, false)

$member = $leader
$leader = :me
gather.hold(Game_Interpreter.new)
check("the leader's story waits for the party", gather.holding_story?, true)
DataManager.extract_save_contents({})
check("until a save is loaded", gather.holding_story?, false)

# A Raid World gathers nobody: whoever is on the map watches.
module MGQ_MpWorld; def self.raid?; $raid; end; end
module MGQ_MpOverworldSync
  def self.in_world?; true; end
  def self.who(peer); peer == :me ? "the player" : peer.state["name"].to_s; end
  def self.tell(seat, fields); $told << [seat, fields]; true; end
  module Me; def self.map_since; 2000; end; def self.id; "me"; end; end
  module Peers
    def self.present; $peers; end
    def self.all; $peers; end
    def self.on_this_map?(peer); peer.state["map"].to_i == $game_map.map_id; end
  end
end
module MGQ_MpCoopEvents
  def self.telling?; $telling; end
  def self.story_playing?; $telling; end
  def self.leading_story?; MGQ_MpCoop::Scope.leads_story?; end
  def self.told_markers; $telling ? [12, 0, 0, 0] : nil; end
  def self.tell(seat, kind, fields = {}); MGQ_MpCoop::Scope.tell(seat, "pevent", kind, fields); end
  def self.tell_each(peers, kind, fields = {}); MGQ_MpCoop::Scope.tell_each(peers, "pevent", kind, fields); end
end
# The switch that bans warping, as story_state.rbx names it.
module MGQ_MpStoryState; WARP_BAN = 100; end
# How far each story is, as coop_story.rbx reads it.
module MGQ_MpCoopStory
  def self.read_markers(text); values = text.to_s.split(","); values.size == 4 ? values.map(&:to_i) : nil; end
  def self.own_markers; $own_markers; end
end
# A player whose transfer is set from outside.
class Game_Player; attr_writer :transfer; def transfer?; @transfer ? true : false; end; end
$raid = true
$telling = false
$told = []
$own_markers = [12, 0, 0, 0]
$game_variables = {}
$game_switches = {}
$game_map = Game_Map.new
$game_player = Game_Player.new
teller = MGQ_MpOverworldSync::Peers::Peer.new(4, { "name" => "Teller", "id" => "t", "map" => "3", "x" => "5", "y" => "5", "d" => "2", "since" => "1000", "telling" => "1", "sm" => "12,0,0,0" })
behind = MGQ_MpOverworldSync::Peers::Peer.new(5, { "name" => "Behind", "id" => "b", "map" => "3", "x" => "9", "y" => "9", "since" => "1500", "sm" => "8,0,0,0" })
$peers = [teller, behind]
check("a Raid World holds no story for anyone to gather", MGQ_MpCoopGather.gathered?, true)
check("a player whose story matches the teller's stands still while it plays on their map", gather.blocked?, true)
teller.state["tsm"] = "9,0,0,0"
check("one whose story does not match plays on", gather.blocked?, false)
teller.state.delete("tsm")
gather.take(teller, { "pevent" => "gather", "map" => "3", "x" => "5", "y" => "5" })
check("a call to gather is ignored", gather.coming?, false)
gather.take(teller, { "pevent" => "follow", "map" => "8", "x" => "1", "y" => "2", "d" => "2" })
check("but the story moving its teller elsewhere takes the player along", [gather.coming?, gather.story_map?(8)], [true, true])
check("whose teller the player follows", gather.followed_id, "t")
gather.forget

$peers = [behind, teller]
teller.state["map"] = "3"
teller.state["telling"] = "0"
$telling = true
$game_player.transfer = true
gather.before_transfer($game_player)
$game_player.transfer = false
$game_map.map_id = 8
gather.after_transfer
check("the player telling the story takes everyone on the map along, even one whose story differs",
      $told.map { |seat, fields| [seat, fields["map_pevent"], fields["mmap"], fields["map"]] }, [[-1, "follow", 3, 8]])
check("in one message that names them", $told.last[1]["mto"], "b,t")
check("and keeps telling them the story on their way", gather.taken_along, [behind, teller])
$telling = false
check("none outside a telling", gather.taken_along, [])
$telling = true
check("but still them as the story's next event goes on with it", gather.taken_along, [behind, teller])
behind.state["map"] = "8"
teller.state["map"] = "8"
check("until they arrived", gather.taken_along, [])
behind.state["map"] = "3"
$telling = false
$game_map.map_id = 3
$peers = [teller, behind]
teller.state["telling"] = "1"

gather.forget_story_place
gather.join_story
check("a teleport to the story needs a story told", $notices.last, "Nobody has told the story yet.")
$peers = [teller]
teller.state["map"] = "6"
gather.note_story_place
check("it goes to where the story was told last", gather.story_endpoint, [6, 5, 5, 2])
teller.state["telling"] = "0"
gather.note_story_place
gather.join_story
check("even once the telling ended", [gather.coming?, gather.own_line], [true, "Joining the story once free . . ."])
check("keeping the player's warp ban while the teller's is unknown", gather.pending_call[:warp_ban], nil)
gather.forget
teller.state.merge!("telling" => "1", "twb" => "1")
gather.note_story_place
gather.join_story
check("and taking over the one where the story is told", gather.pending_call[:warp_ban], true)
gather.forget
$telling = true
$game_switches[100] = false
gather.note_story_place
$telling = false
$peers = []
$game_map.map_id = 4
gather.join_story
check("the player's own telling notes the warp ban where they stand", [gather.story_endpoint[0], gather.pending_call[:warp_ban]], [3, false])
gather.forget
$game_map.map_id = 3

# The endpoint the relay keeps of the world's story, which world_story.rbx tells, wins.
module MGQ_MpWorldStory; def self.endpoint; $relay_end; end; end
$relay_end = [9, 7, 8, 2]
check("a teleport to the story goes to the endpoint the relay keeps", gather.story_endpoint, [9, 7, 8, 2])
gather.join_story
check("whose warp ban this game does not know, so the player keeps their own", gather.pending_call[:warp_ban], nil)
gather.forget
$relay_end = nil
check("and where this game saw the story told while the relay keeps none", gather.story_endpoint[0], 3)
$raid = false
