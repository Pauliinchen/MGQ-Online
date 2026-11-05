#----------------------------------------------------------------
#  coop_gather_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the calls, the hold and the offers with fixed values and checked what goes to the DLL and what the player gets of its answers
#                            - Told whether a telling moves the world's story on as true or false
#                            - Told the telling of the story as true or false
#                            - Expected the ids a map message names as a list
#                            - Checked that whom a telling takes along follows the DLL's one decision, with the progress noted as it started
#                            - Checked that a follow hands the move to the one guard of the game's flow, which shows the followers the map left hidden
#                            - Read the scripts' clock from $frame_count and dropped the check of a call from before a loaded save, since the clock never goes back
#      Paulinchen  2026-11-01: Dropped the stand-in of a lapse after a frame count, which no script asks for any more
#      Paulinchen  2026-10-31: Dropped the warp ban a teleport to the story took
#                            - Expected the plainer texts the player reads
#      Paulinchen  2026-10-28: Answered the calls, the hold and the offers through the bridge from their golden cases
#                            - Took a Raid World's tellers from the relay's tellings
#      Paulinchen  2026-10-24: Checked that a viewer follows at once a scene that runs by itself and would start again in their game
#                            - Checked that a telling nothing of which comes for thirty seconds holds the player no longer
#      Paulinchen  2026-10-23: Checked that a Raid World viewer follows at once only a telling that moves the world's story on
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

# Covers coop_gather.rbx with fixed answers of the DLL (telling_support.rb): what a leader's call, a
# teleport, the hold and the offers hand the DLL, what the player sees and where they go by its
# answers, and that a loaded save or the world closing has the DLL forget them. In a Raid World
# nobody is gathered: players follow the story's teller, and a teleport goes to the story. When a
# call lapses, what the hold waits for and how long an offer stands is GatherCallsTests' to cover.

require_relative "support"
require_relative "rules_support"

# Stands in for the mod's log, printing each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
# Stands in for RGSS graphics; the scripts' clock reads $frame_count.
module Graphics; def self.brightness; 255; end; end
clock_from { $frame_count }
# Stands in for the game's event interpreter.
class Game_Interpreter; def execute_command; end; end
# Stands in for the game's map.
class Game_Map; attr_accessor :map_id; def initialize; @map_id = 3; end; def update(main = false); end; def interpreter; @interpreter ||= Game_Interpreter.new; end; end
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
# Stands in for the shared story's events, whose messages land in $sent, led by the party's leader.
module MGQ_MpCoopEvents
  def self.pvp_running?; false; end
  def self.leading_story?; $leader == :me; end
  def self.tell(seat, kind, fields = {}); ($sent ||= []) << [seat, kind]; true; end
end

# Stands in for the one guard of the game's flow (coop_flow.rbx), noting each move away in $flow_leaves.
module MGQ_MpFlowGuard; def self.leave(reason, whole = false, elsewhere = false); ($flow_leaves ||= []) << [reason, whole, elsewhere]; end; end
load_script "coop_scope"
load_script "coop_gather"
open_rules_bridge

gather = MGQ_MpCoopGather
$game_map = Game_Map.new
$game_player = Game_Player.new
$leader = MGQ_MpOverworldSync::Peers::Peer.new(2, { "name" => "Leader", "id" => "leader", "map" => "9", "x" => "10", "y" => "10" })
place = [9, 10, 10, 2]
$frame_count = 5000
# Has the DLL answer how the calls stand: as with none standing, but for the fields given.
calls = lambda do |fields|
  $tells.set("gather.frame", { "coming" => false, "pending" => nil, "notice" => nil, "come" => nil, "waited" => false, "follow" => nil, "holding" => false,
                               "doing" => nil, "idle" => false }.merge(fields))
  gather.refresh
end
# Counts the times the calls were read.
frames_asked = lambda { $tells.asked("gather.frame").size }

check("before any call the map's frames ask the DLL nothing", [gather.coming?, frames_asked.call], [false, 0])
$tells.set("gather.called", "notice" => "Leader's story is starting. You join them in 5 seconds.")
calls.call("coming" => true, "doing" => { "text" => "Joining Leader", "left" => 300 })
gather.called($leader, place)
check("a leader's call hands the DLL who calls and where, that the player stands elsewhere and fights no duel, and shows the notice it answers",
      [$tells.asked("gather.called").last, $notices.last],
      [{ "name" => "Leader", "id" => "leader", "place" => [9, 10, 10, 2], "near" => false, "pvp" => false }, "Leader's story is starting. You join them in 5 seconds."])
check("then the calls tell that the player is coming, and the line above their head counts the frames left down in seconds",
      [gather.coming?, gather.own_doing], [true, ["Joining Leader", 5.0]])
check("read once per frame, with whether the map settled and the player leads", [frames_asked.call, $tells.asked("gather.frame").last],
      [1, { "settled" => true, "leading" => false, "missing" => [] }])
calls.call("notice" => "Leader's story started without you.", "idle" => true)
$frame_count += 1
gather.coming?
asked = frames_asked.call
$frame_count += 1
gather.update
check("a call the DLL says lapsed is told once, and the map's frames ask nothing more until the next call comes",
      [$notices.count("Leader's story started without you."), frames_asked.call - asked, gather.coming?], [1, 0, false])

$tells.set("gather.calling_battle", true)
check("whether a battle belongs to the call is asked with its host and map", [gather.calling_battle?($leader, 9), $tells.asked("gather.calling_battle").last],
      [true, { "id" => "leader", "map" => 9 }])
$tells.set("gather.calling_battle", nil)

calls.call("coming" => true)
gather.called($leader, place)
$tells.set("gather.forget", "held" => false, "call" => "Leader")
lines = logged_lines { DataManager.extract_save_contents({}) }
check("a loaded save has the DLL forget the call, logged, and reads it no more", [gather.coming?, $tells.asked("gather.forget").size, lines.grep(/forgot .*Leader's call/).size], [false, 1, 1])
gather.called($leader, place)
$tick.call(true)
check("an open world keeps it", gather.coming?, true)
$tick.call(false)
check("the world closing has the DLL forget it", [gather.coming?, $tells.asked("gather.forget").size], [false, 2])
gather.come_to("Friend", [4, 1, 1, 2])
check("a teleport the player asked for hands the DLL whom to and where, and is read as a call", [$tells.asked("gather.come_to").last, gather.coming?],
      [{ "name" => "Friend", "place" => [4, 1, 1, 2] }, true])
DataManager.extract_save_contents({})
check("until a save is loaded", gather.coming?, false)

# Stands in for the shared story, whose members synced with the leader's story are the party's.
module MGQ_MpCoopStory; def self.synced_members; MGQ_MpCoop::Party.members; end; end
$member = $leader
$leader = :me
$sent = []
held = Game_Interpreter.new
calls.call("holding" => true, "doing" => { "text" => "Gathering: Leader", "left" => 1800 })
gather.hold(held)
check("the leader's story scene holds, has the DLL hold it, calls the party and says so",
      [gather.holding_story?, $tells.asked("gather.hold").size, $sent.last, $notices.last], [true, 1, [-1, "gather"], "Gathering the party for the story . . ."])
check("and the line above the leader's head is the doing the DLL names, through the doing the script registered",
      [gather.own_doing, $doings.map { |doing| doing.call }], [["Gathering: Leader", 30.0], [["Gathering: Leader", 30.0]]])
# A party of four members, none on the player's map.
module MGQ_MpCoop::Party
  def self.members
    (1..4).map { |n| MGQ_MpOverworldSync::Peers::Peer.new(n + 1, { "name" => "Player #{n}", "map" => "9", "x" => "10", "y" => "10" }) }
  end
end
gather.refresh
gather.own_doing
check("the calls are read with the names of the members still missing", $tells.asked("gather.frame").last,
      { "settled" => true, "leading" => true, "missing" => ["Player 1", "Player 2", "Player 3", "Player 4"] })
# The party of the one member again.
module MGQ_MpCoop::Party; def self.members; [$member]; end; end
$sent.clear
$tells.set("gather.holding", "wait" => true, "call_again" => true, "notice" => nil, "released" => nil)
check("before each command the held scene asks the DLL with who is missing, and calls the party again when it says so",
      [gather.holding?(held), $tells.asked("gather.holding").last, $sent], [true, { "leading" => true, "gathered" => false, "missing" => ["Leader"] }, [[-1, "gather"]]])
$tells.set("gather.holding", "wait" => false, "call_again" => false, "notice" => "The story starts without Leader.", "released" => "the story starts without Leader")
check("and lets the story start once the DLL says so, with its notice", [gather.holding?(held), gather.holding_story?, $notices.last],
      [false, false, "The story starts without Leader."])
$tells.set("gather.holding", nil)
gather.hold(held)
DataManager.extract_save_contents({})
check("a loaded save forgets the hold", gather.holding_story?, false)
calls.call({})

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
# coop_scope.rbx; the DLL's one decision reads the world's progress from $progress and answers
# whether a telling moves the world's story on from $moves, noting the progress it was told in
# $told_progress.
module MGQ_MpCoopEvents
  def self.story_progress; $progress; end
  def self.moves_story?(told); $told_progress = told; $moves; end
  def self.behind?; $behind; end
  def self.keeps_autorun_of?(peer); $kept_autorun == peer.state["id"]; end
  def self.telling?; $telling; end
  def self.story_playing?; $telling; end
  def self.leading_story?; MGQ_MpCoop::Scope.leads_story?; end
  def self.tell(seat, kind, fields = {}); MGQ_MpCoop::Scope.tell(seat, "pevent", kind, fields); end
  def self.tell_each(peers, kind, fields = {}); MGQ_MpCoop::Scope.tell_each(peers, "pevent", kind, fields); end
end

# The world's story: the player's track from $track, and the tellings the relay told of on it from
# $tellings, by seat.
module MGQ_MpWorldStory
  def self.track; $track; end
  def self.telling_of(seat); $tellings[seat]; end
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
$track = "world"
$game_variables = {}
$game_switches = {}
$game_map = Game_Map.new
$game_player = Game_Player.new
teller = MGQ_MpOverworldSync::Peers::Peer.new(4, { "name" => "Teller", "id" => "t", "map" => "3", "x" => "5", "y" => "5", "d" => "2", "since" => "1000", "trk" => "world" })
behind = MGQ_MpOverworldSync::Peers::Peer.new(5, { "name" => "Behind", "id" => "b", "map" => "3", "x" => "9", "y" => "9", "since" => "1500", "trk" => "t2" })
$peers = [teller, behind]
$tellings = { 4 => ["t1", 3, "map:3:1:1"] }
check("a Raid World holds no story for anyone to gather", MGQ_MpCoopGather.gathered?, true)
check("a player the relay told of the teller's telling stands still while it plays on their map", gather.blocked?, true)
$tellings.delete(4)
check("one it told of no telling of theirs, as a player on another track, plays on", gather.blocked?, false)
$tellings[4] = ["t1", 3, "map:3:1:1"]
teller.state["scene"] = "battle"
check("while the teller fights the story's battle, a player who came late may move and join it", gather.blocked?, false)
teller.state["scene"] = "event"
check("and stands still again once the story goes on", gather.blocked?, true)
# A hold asked every half second, as the game asks it every frame.
hold_for = lambda { |frames| (frames / 30).times { $frame_count += 30; gather.blocked? }; gather.blocked? }
check("a telling nothing of which comes for 30 s holds the player no longer (issue 61)",
      [hold_for.call(MGQ_MpCoop::Scope::SILENT_FRAMES - 60), hold_for.call(60)], [true, false])
MGQ_MpCoop::Scope.heard_from(teller)
check("one that sends something holds them again", hold_for.call(MGQ_MpCoop::Scope::SILENT_FRAMES - 60), true)
$frame_count += MGQ_MpCoop::Scope::SILENT_FRAMES
check("and a hold after a pause counts anew", gather.blocked?, true)
called = $tells.asked("gather.called").size
gather.take(teller, { "pevent" => "gather", "map" => "3", "x" => "5", "y" => "5" })
check("a call to gather is ignored", $tells.asked("gather.called").size, called)
gather.take(teller, { "pevent" => "follow", "map" => "8", "x" => "1", "y" => "2", "d" => "2" })
check("but the story moving its teller elsewhere has the DLL follow them, also from an earlier build that does not say whether it moves the world's story on",
      $tells.asked("gather.followed").last, { "name" => "Teller", "id" => "t", "place" => [8, 1, 2, 2], "raid" => true })
calls.call("coming" => true, "follow" => { "id" => "t", "name" => "Teller", "place" => [8, 1, 2, 2] })
check("the follow the DLL names tells whose teller the player follows and whose pages and scene of the map it leads to reach them",
      [gather.followed_id, gather.story_map?(8), gather.story_map?(5)], ["t", true, false])
calls.call({})
gather.forget

# Only a player who watches the teller's story and is not behind the world's follows at once; any
# other is offered to follow in the notification box while the DLL keeps the offer.
follow = { "pevent" => "follow", "map" => "8", "x" => "1", "y" => "2", "d" => "2" }
offered = lambda { $tells.asked("gather.offer").size }
followed = lambda { $tells.asked("gather.followed").size }
$tellings.delete(4)
before = [offered.call, followed.call]
gather.take(teller, follow)
check("a player on another track, whom the relay told of no telling of the teller, does not follow at once, but the DLL keeps an offer",
      [offered.call - before[0], followed.call - before[1], $tells.asked("gather.offer").last], [1, 0, { "id" => "t", "name" => "Teller", "place" => [8, 1, 2, 2] }])
$tells.set("gather.follow_offer", "name" => "Teller", "place" => [8, 1, 2, 2], "since" => 7000)
notice = $offers.notice_of(teller)
check("which the notification box offers as the DLL answers it", [notice.text, notice.action, notice.color, notice.key, notice.mark],
      ["Teller's story moved on to map 8. Follow?", "Follow", :invite, [:story_follow, 4], 7000])
check("asked with whether the teller tells and the player's map", $tells.asked("gather.follow_offer").last, { "id" => "t", "telling" => false, "map" => 3 })
check("which leaves the World overview's rows alone", [$offers.call_of(teller), $offers.peer_option(teller), $offers.own_options], [nil, nil, []])
teller.state.merge!("map" => "8", "place" => "Iliasville")
check("naming the place once the teller's state tells it from there", $offers.notice_of(teller).text, "Teller's story moved on to Iliasville. Follow?")
$tells.set("gather.accept", "name" => "Teller", "place" => [8, 1, 2, 2], "since" => 7000)
$offers.notice_of(teller).take.call
check("following has the DLL take the offer and follows that teller there",
      [$tells.asked("gather.accept").last, $tells.asked("gather.followed").last, $offers.notice_of(teller)],
      [{ "id" => "t", "telling" => false, "map" => 3 }, { "name" => "Teller", "id" => "t", "place" => [8, 1, 2, 2], "raid" => true }, nil])
calls.call("coming" => true, "come" => [8, 1, 2, 2], "follow" => { "id" => "t", "name" => "Teller", "place" => [8, 1, 2, 2] })
$tells.set("gather.take", "name" => "Teller", "id" => "t", "place" => [8, 1, 2, 2], "follow" => true, "asked" => false, "bans" => [[94, false]])
$map_free = true
$game_switches[94] = true
$game_player.followers.visible = false
gather.update
check("once free, the player takes the follow the DLL hands, goes there and takes the bans the DLL kept for the arrival",
      [$tells.asked("gather.take").last, $game_player.reserved, $game_switches[94]], [{ "raid" => true }, [8, 1, 2, 2], false])
check("and hands the move to the guard of the game's flow as one to another map, which shows the followers the map left behind hidden, such as Hades after a defeat",
      $flow_leaves.last, ["the player went to Teller: the story moved them", false, true])
$tells.set("gather.take", nil)
calls.call({})
$game_player.reserved = nil
$map_free = false
gather.forget
$tells.set("gather.decline", "Teller")
gather.take(teller, follow)
$offers.notice_of(teller).decline.call
check("declining has the DLL drop the offer, and the box shows it no more", [$tells.asked("gather.decline").last, $offers.notice_of(teller)], [{ "id" => "t" }, nil])
gather.take(teller, follow)
$tells.set("gather.follow_offer", "dropped" => "their telling ended")
lines = logged_lines { $offers.notice_of(teller) }
check("an offer the DLL says ended leaves the box, logged with why", [$offers.notice_of(teller), lines.grep(/dropped the offer to follow Teller: their telling ended/).size], [nil, 1])
$tells.set("gather.follow_offer", "name" => "Teller", "place" => [8, 1, 2, 2], "since" => 7000)
$tellings[4] = ["t1", 8, "map:3:1:1"]
$behind = true
before = [offered.call, followed.call]
gather.take(teller, follow)
check("a player behind the world's story is offered to follow, though their story matches", [offered.call - before[0], followed.call - before[1]], [1, 0])
$behind = false
gather.take(teller, follow.merge("moves" => false))
check("a player watching is only offered to follow a telling that does not move the world's story on, as a minigame's that moves its teller",
      [offered.call - before[0], followed.call - before[1]], [2, 0])
$kept_autorun = "t"
gather.take(teller, follow.merge("moves" => false))
check("but follows at once when the player's game keeps its own copy of the teller's scene, which runs by itself, from starting (issue 61)",
      [offered.call - before[0], followed.call - before[1]], [2, 1])
$kept_autorun = nil
gather.forget_story_place
check("the world closing has the DLL forget the offers", [$tells.asked("gather.forget_offers").size, $offers.notice_of(teller)], [1, nil])
$tells.set("gather.follow_offer", nil)
teller.state["map"] = "3"
teller.state.delete("place")
gather.forget
calls.call({})

$peers = [behind, teller]
teller.state["map"] = "3"
teller.state["telling"] = false
$telling = true
$game_player.transfer = true
gather.before_transfer($game_player)
$game_player.transfer = false
$game_map.map_id = 8
gather.after_transfer
check("the player telling the story takes everyone on the map along, even one whose story differs",
      $told.map { |seat, fields| [seat, fields["map_pevent"], fields["mmap"], fields["map"]] }, [[-1, "follow", 3, 8]])
check("in one message that names them", $told.last[1]["mto"], %w[b t])
check("saying that the telling does not move the world's story on while no story of the world runs", $told.last[1]["moves"], false)

# Stands in for the world's story's end point.
module MGQ_MpWorldStory
  def self.endpoint; $relay_end; end
end
moves = lambda do |decided|
  $progress = [12, 0]
  gather.note_story_progress
  $progress = [13, 0]
  $moves = decided
  $game_player.transfer = true
  gather.before_transfer($game_player)
  $game_player.transfer = false
  gather.after_transfer
  [$told.last[1]["moves"], $told_progress]
end
check("whom a telling calls to follow at once is the DLL's one decision, asked with the progress as the telling started",
      [moves.call(true), moves.call(false)], [[true, [12, 0]], [false, [12, 0]]])
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
teller.state["telling"] = true

gather.forget_story_place
gather.join_story
check("a teleport to the story needs a story told", $notices.last, "Nobody has told the story yet.")
$peers = [teller]
teller.state["map"] = "6"
gather.note_story_place
check("it goes to where the story was told last", gather.story_endpoint, [6, 5, 5, 2])
teller.state["telling"] = false
gather.note_story_place
gather.join_story
check("even once the telling ended, handed to the DLL as a teleport to the story",
      [$tells.asked("gather.come_to").last, $notices.last], [{ "name" => "the story", "place" => [6, 5, 5, 2] }, "Teleporting to the story . . ."])
gather.forget
$telling = true
gather.note_story_place
$telling = false
$peers = []
$game_map.map_id = 4
gather.join_story
check("the player's own telling notes where they stand", [gather.story_endpoint[0], $tells.asked("gather.come_to").last["place"][0]], [3, 3])
gather.forget
$game_map.map_id = 3

# The endpoint of the world's story that the relay keeps wins.

# Stands in for world_story.rbx, whose endpoint the relay keeps is $relay_end.
module MGQ_MpWorldStory; def self.endpoint; $relay_end; end; end
$relay_end = [9, 7, 8, 2]
check("a teleport to the story goes to the endpoint the relay keeps", gather.story_endpoint, [9, 7, 8, 2])
gather.forget
$relay_end = nil
check("and where this game saw the story told while the relay keeps none", gather.story_endpoint[0], 3)

# A call or a teleport to a map this game lacks is dropped, which the player is told.

# Stands in for RGSS's load_data, which finds no file.
#
# @param path [String] The file.
def load_data(path); raise Errno::ENOENT, path; end
$map_free = true
gather.come_to("Friend", [77, 1, 1, 2])
calls.call("coming" => true, "come" => [77, 1, 1, 2])
$tells.set("gather.take", "name" => "Friend", "id" => nil, "place" => [77, 1, 1, 2], "follow" => false, "asked" => true, "bans" => [])
gather.update
check("a teleport to a map this game lacks tells the player so", [$notices.last, $game_player.reserved], ["Cannot teleport to Friend.", nil])
$tells.set("gather.take", nil)
calls.call({})

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
