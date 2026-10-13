#----------------------------------------------------------------
#  coop_gather_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Checked which battles belong to a leader's call
#      Paulinchen  2026-10-11: Checked that a follow to another map shows the followers the map left behind hidden
#                            - Stood in for the player's followers
#                            - Checked that a map from 1000 on is found in the folder the game keeps it in
#                            - Checked the gathering lines above the heads of a member and the leader
#                            - Stood in for the line above the head and the members synced with the story
#      Paulinchen  2026-10-10: Checked that a Raid World's follow taken at once waits a minute for a busy player
#                            - Checked that a taken Raid World follow names its teller and map for a while
#                            - Checked that a Raid World's teller in the story's battle holds nobody
#                            - Checked that a loaded save forgets a teleport the player asked for
#                            - Checked who follows a Raid World's teller at once and who is offered to
#                            - Checked that a teleport to a map this game lacks tells the player so
#                            - Checked early follow offers, follows of a busy player and calls over teleports
#                            - Stood in for the offers, the free map, the reserved transfer and a story behind
#      Paulinchen  2026-10-09: Stood in for the warp ban of story_state.rbx
#                            - Stood in for MGQ_MpCoopEvents.tell_each
#                            - Checked how the story takes players along and names its teller
#                            - Stood in for MGQ_MpOverworldSync::Peers.all
#      Paulinchen  2026-10-08: Checked gathering, following and teleports to the story in a Raid World
#                            - Checked the players taken along and the warp ban a story teleport takes
#                            - Checked that a teleport to the story goes to the endpoint the relay keeps
#      Paulinchen  2026-10-06: Created
#
#----------------------------------------------------------------

# Covers coop_gather.rbx: a leader's call lapses, and a loaded save or the world closing forgets the
# calls, a teleport the player asked for and the hold. In a Raid World nobody is gathered: players
# follow the story's teller, and a teleport goes to the story.

require_relative "support"

# Stands in for the mod's log, printing each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
# Stands in for RGSS graphics, whose frame count is $frame_count.
module Graphics; def self.frame_count; $frame_count; end; def self.brightness; 255; end; end
# Stands in for the game's event interpreter.
class Game_Interpreter; def execute_command; end; end
# Stands in for the game's map.
class Game_Map; attr_accessor :map_id; def initialize; @map_id = 3; end; def update(main = false); end; end
# Stands in for the game's player.
class Game_Player
  # The player's followers, shown while visible.
  Followers = Struct.new(:visible)
  attr_accessor :x, :y
  attr_reader :followers
  def initialize; @x = 0; @y = 0; @followers = Followers.new(true); end
  def refresh; end
  def direction; 2; end
  def encounter; true; end
  def movable?; true; end
  def perform_transfer; end
  def transfer?; false; end
  def make_encounter_count; end
end
# Stands in for the game's map scene.
class Scene_Map; def update_call_menu; end; end
# Stands in for the game's save loading.
module DataManager; def self.extract_save_contents(contents); end; end
# Stands in for the player's actions: the line above the player's head, whose lapses are the seconds
# left, and the offers, kept in $offers.
module MGQ_MpActions
  # An entry of the notification box.
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)
  def self.own_doing_from(&doing); ($doings ||= []) << doing; end
  def self.lapse_in(frames); frames / 60.0; end
  def self.lapse_at(since, frames); lapse_in(since + frames - Graphics.frame_count); end
  def self.offer(offers); $offers = offers; end
end
# Stands in for the world's sync, keeping the tick handler and the notices shown.
module MGQ_MpOverworldSync
  # The other players in the world, each a Peer of a seat and the state they told.
  module Peers; Peer = Struct.new(:seat, :state); end
  def self.on_tick(&block); $tick = block; end
  def self.notice(text); ($notices ||= []) << text; end
end
# Stands in for the party, led by $leader, whose one member is $member.
module MGQ_MpCoop
  # Color of the invite line.
  INVITE_COLOR = :invite
  # The party's members.
  module Party; def self.members; [$member]; end; end
  def self.party_leader; $leader; end
  def self.party_leading?; $leader == :me; end
  def self.in_party?; true; end
end
# Stands in for the shared story's events, whose messages land in $sent.
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
check("and the line above their head counts the seconds down before they come over", gather.own_doing, ["Joining Leader", 5.0])
$frame_count += 2 * 60
check("as the frames pass", gather.own_doing, ["Joining Leader", 3.0])
$frame_count += MGQ_MpCoopGather::GATHER_FRAMES - 2 * 60
check("then names that they come once free, without a time", gather.own_doing, "Joining Leader once free")
$frame_count += MGQ_MpCoopGather::CALL_LAPSE_FRAMES
check("until the calls stop", [gather.coming?, gather.own_doing], [false, nil])

$leader.state["id"] = "leader"
other = MGQ_MpOverworldSync::Peers::Peer.new(3, { "name" => "Other", "id" => "other" })
gather.called($leader, place)
check("a battle of the calling leader on the map the call leads to belongs to the call, one elsewhere or of another player does not",
      [gather.calling_battle?($leader, 9), gather.calling_battle?($leader, 4), gather.calling_battle?(other, 9)], [true, false, false])
$frame_count += MGQ_MpCoopGather::CALL_LAPSE_FRAMES + 1
check("nor once the call lapsed", gather.calling_battle?($leader, 9), false)

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

gather.come_to("Leader", place, false)
check("a member teleporting to another is coming", gather.coming?, true)
DataManager.extract_save_contents({})
check("until a save is loaded", gather.coming?, false)

gather.come_to("Friend", [4, 1, 1, 2], false)
gather.called($leader, place)
$frame_count += MGQ_MpCoopGather::CALL_LAPSE_FRAMES
check("a leader's call that takes over a teleport the player asked for lapses as a call does",
      [gather.pending_call, $notices.last], [nil, "Leader's story started without you."])

# Stands in for the shared story, whose members synced with the leader's story are the party's.
module MGQ_MpCoopStory; def self.synced_members; MGQ_MpCoop::Party.members; end; end
$member = $leader
$leader = :me
gather.hold(Game_Interpreter.new)
check("the leader's story waits for the party", gather.holding_story?, true)
check("and the line above the leader's head names who is still missing, with the time the story holds, through the doing the script registered",
      [gather.own_doing, $doings.map { |doing| doing.call }], [["Gathering: Leader", 30.0], [["Gathering: Leader", 30.0]]])
$frame_count += 10 * 60
check("counting it down", gather.own_doing, ["Gathering: Leader", 20.0])
# A party of four members, none on the player's map.
module MGQ_MpCoop::Party
  def self.members
    (1..4).map { |n| MGQ_MpOverworldSync::Peers::Peer.new(n + 1, { "name" => "Player #{n}", "map" => "9", "x" => "10", "y" => "10" }) }
  end
end
check("naming two missing members at most and how many more", gather.own_doing, ["Gathering: Player 1, Player 2 +2", 20.0])
# The party of the one member again.
module MGQ_MpCoop::Party; def self.members; [$member]; end; end
DataManager.extract_save_contents({})
check("until a save is loaded", gather.holding_story?, false)
check("the frames a moment has left count down from the frames given, into the past, which within? reads",
      [gather.frames_left($frame_count - 100, 300), gather.frames_left($frame_count - 400, 300), gather.frames_left($frame_count + 50, 300),
       gather.within?($frame_count - 100, 300), gather.within?($frame_count - 400, 300), gather.within?($frame_count + 50, 300)],
      [200, -100, 350, true, false, false])

# A Raid World gathers nobody: whoever is on the map watches.

# Stands in for the world, a Raid World while $raid is set.
module MGQ_MpWorld; def self.raid?; $raid; end; end
# The world's sync in an open world, whose messages land in $told and whose map is free while
# $map_free is set.
module MGQ_MpOverworldSync
  def self.in_world?; true; end
  def self.who(peer); peer == :me ? "the player" : peer.state["name"].to_s; end
  def self.tell(seat, fields); $told << [seat, fields]; true; end
  def self.map_free?; $map_free; end
  # The player, on their map since frame 2000.
  module Me; def self.map_since; 2000; end; def self.id; "me"; end; end
  # The other players, kept in $peers.
  module Peers
    def self.present; $peers; end
    def self.all; $peers; end
    def self.on_this_map?(peer); peer.state["map"].to_i == $game_map.map_id; end
  end
end
# The shared story's events, telling while $telling and behind while $behind, which send through
# coop_scope.rbx.
module MGQ_MpCoopEvents
  def self.behind?; $behind; end
  def self.telling?; $telling; end
  def self.story_playing?; $telling; end
  def self.leading_story?; MGQ_MpCoop::Scope.leads_story?; end
  def self.told_markers; $telling ? [12, 0, 0, 0] : nil; end
  def self.tell(seat, kind, fields = {}); MGQ_MpCoop::Scope.tell(seat, "pevent", kind, fields); end
  def self.tell_each(peers, kind, fields = {}); MGQ_MpCoop::Scope.tell_each(peers, "pevent", kind, fields); end
end
# Stands in for story_state.rbx, whose WARP_BAN names the switch that bans warping.
module MGQ_MpStoryState; WARP_BAN = 100; end
# How far each story is: markers read as coop_story.rbx reads them, the player's own in $own_markers.
module MGQ_MpCoopStory
  def self.read_markers(text); values = text.to_s.split(","); values.size == 4 ? values.map(&:to_i) : nil; end
  def self.own_markers; $own_markers; end
end
# A player whose transfer is set from outside, and who notes the transfer reserved.
class Game_Player
  attr_writer :transfer
  attr_accessor :reserved
  def transfer?; @transfer ? true : false; end
  def reserve_transfer(*args); @reserved = args; end
end
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
teller.state["scene"] = "battle"
check("while the teller fights the story's battle, a player who came late may move and join it", gather.blocked?, false)
teller.state["scene"] = "event"
check("and stands still again once the story goes on", gather.blocked?, true)
gather.take(teller, { "pevent" => "gather", "map" => "3", "x" => "5", "y" => "5" })
check("a call to gather is ignored", gather.coming?, false)
gather.take(teller, { "pevent" => "follow", "map" => "8", "x" => "1", "y" => "2", "d" => "2" })
check("but the story moving its teller elsewhere takes the player along", [gather.coming?, gather.story_map?(8)], [true, true])
check("whose teller the player follows", gather.followed_id, "t")
$map_free = false
$frame_count += 20 * 60
gather.update
check("still while the player is busy for 20 s, since the story calls once", [gather.coming?, gather.followed_id, gather.story_map?(8)], [true, "t", true])
$frame_count += MGQ_MpCoopGather::ASKED_LAPSE_FRAMES
check("until a minute passed", [gather.pending_call, gather.followed_id, $notices.last], [nil, nil, "Teller's story went on without you."])
gather.forget

# Only a player who watches the teller's story and is not behind the world's follows at once; any
# other is offered to follow in the notification box while the teller tells there.
follow = { "pevent" => "follow", "map" => "8", "x" => "1", "y" => "2", "d" => "2" }
teller.state["tsm"] = "9,0,0,0"
gather.take(teller, follow)
notice = $offers.notice_of(teller)
check("a player whose story differs from the teller's does not follow at once", gather.coming?, false)
check("but is offered to in the notification box", [notice.text, notice.action, notice.color, notice.key],
      ["Teller's story moved on to map 8. Follow?", "Follow", :invite, [:story_follow, 4]])
check("which leaves the World overview's rows alone", [$offers.call_of(teller), $offers.peer_option(teller), $offers.own_options], [nil, nil, []])
teller.state.merge!("map" => "8", "place" => "Iliasville")
check("naming the place once the teller's state tells it from there", $offers.notice_of(teller).text, "Teller's story moved on to Iliasville. Follow?")
$offers.notice_of(teller).take.call
check("following brings the player there as a follow of that teller",
      [gather.coming?, gather.pending_call[:place], gather.followed_id, $offers.notice_of(teller)], [true, [8, 1, 2, 2], "t", nil])
$map_free = true
$game_player.followers.visible = false
gather.update
check("taken, the follow still names its teller and map while the player is on the way and after they arrived",
      [$game_player.reserved, gather.coming?, gather.followed_id, gather.story_map?(8)], [[8, 1, 2, 2], false, "t", true])
check("and shows the followers the map left behind hidden, such as Hades after a defeat", $game_player.followers.visible, true)
$frame_count += MGQ_MpCoopGather::CALL_LAPSE_FRAMES
check("until CALL_LAPSE_FRAMES passed", [gather.followed_id, gather.story_map?(8)], [nil, false])
$game_player.reserved = nil
$map_free = false
gather.forget
gather.take(teller, follow)
$offers.notice_of(teller).decline.call
check("declining drops the offer", [$offers.notice_of(teller), gather.coming?], [nil, false])
gather.take(teller, follow)
teller.state["telling"] = "0"
check("an offer that comes before the teller's state tells them telling stands", $offers.notice_of(teller).nil?, false)
teller.state["telling"] = "1"
$offers.notice_of(teller)
teller.state["telling"] = "0"
check("an offer ends with the teller's telling", $offers.notice_of(teller), nil)
teller.state["telling"] = "1"
gather.take(teller, follow)
$offers.notice_of(teller).take.call
$map_free = false
$frame_count += 20 * 60
gather.update
check("a follow accepted while the player is busy for 20 s still stands", [gather.coming?, gather.followed_id], [true, "t"])
$frame_count += MGQ_MpCoopGather::ASKED_LAPSE_FRAMES
check("until a minute passed", [gather.pending_call, $notices.last], [nil, "Teller's story went on without you."])
gather.take(teller, follow)
$frame_count += MGQ_MpCoopGather::FOLLOW_OFFER_FRAMES
check("or after a minute", $offers.notice_of(teller), nil)
teller.state.delete("tsm")
$behind = true
gather.take(teller, follow)
check("a player behind the world's story is offered to follow too, though their story matches", [gather.coming?, $offers.notice_of(teller).nil?], [false, false])
$behind = false
gather.forget_story_place
check("the world closing forgets the offers", $offers.notice_of(teller), nil)
teller.state["map"] = "3"
teller.state.delete("place")

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
check("even once the telling ended", [gather.coming?, gather.own_doing], [true, "Joining the story once free"])
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

# The endpoint of the world's story that the relay keeps wins.

# Stands in for world_story.rbx, whose endpoint the relay keeps is $relay_end.
module MGQ_MpWorldStory; def self.endpoint; $relay_end; end; end
$relay_end = [9, 7, 8, 2]
check("a teleport to the story goes to the endpoint the relay keeps", gather.story_endpoint, [9, 7, 8, 2])
gather.join_story
check("whose warp ban this game does not know, so the player keeps their own", gather.pending_call[:warp_ban], nil)
gather.forget
$relay_end = nil
check("and where this game saw the story told while the relay keeps none", gather.story_endpoint[0], 3)

# A call or a teleport to a map this game lacks is dropped, which the player is told.

# Stands in for RGSS's load_data, which finds no file.
#
# @param path [String] The file.
def load_data(path); raise Errno::ENOENT, path; end
$map_free = true
gather.come_to("Friend", [77, 1, 1, 2], false)
gather.update
check("a teleport to a map this game lacks tells the player so", [gather.coming?, $notices.last, $game_player.reserved],
      [false, "Cannot teleport to Friend: this game has no map 77.", nil])

# A map from 1000 on lies in a folder of its own, which only the game's map_file_name finds.

# Stands in for the game's map file name, which keeps a map from 1000 on in Data/Map/Data.
#
# @param map_id [Integer] The map.
# @return [String] The map's file.
def DataManager.map_file_name(map_id); "Data/Map/Data/Map#{format('%03d', map_id % 1000)}.rvdata2"; end
# Stands in for RGSS's load_data, which finds only map 1650's file.
#
# @param path [String] The file.
def load_data(path); raise Errno::ENOENT, path unless path == "Data/Map/Data/Map650.rvdata2"; end
check("a map from 1000 on is found where the game keeps it", [gather.map_file(1650), gather.map_known?(1650)], ["Data/Map/Data/Map650.rvdata2", true])
class << DataManager; remove_method :map_file_name; end
$raid = false
