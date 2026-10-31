#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#                            - Called the script without a warp ban
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Writes the golden cases of a story's calls next to this file, cases.json, from coop_gather.rbx as
# it kept them before they moved to C# (MGQOnline.Game's Telling/GatherCalls): a leader's call to
# a story scene, a follow where a story moved its teller, a teleport the player asked for, the
# leader's hold of a scene while the party gathers, and the offers to follow a Raid World's teller,
# each with its frames. Each scenario is a list of steps; a step's operation runs at its frame, then
# the step records what the script answered. MGQOnline.Game.Tests replays them against the C#
# machine, and the script tests' stand-in (GameScript/Tests/gather_support.rb) is checked against
# them.
#
# It runs on the coop_gather.rbx of commit d7bc93af, which still kept the rules, with the
# stand-ins below, on Ruby 3.3:
#
#   git show d7bc93af:GameScript/Multiplayer/Scripts/coop_gather.rbx > old_gather.rbx
#   ruby fixtures/gather/make_fixtures.rb old_gather.rbx

require "json"
require_relative "../../GameScript/Tests/support"

# The log, which the cases leave out.
module MGQ_Multiplayer::Log; def self.write(_line); end; end

# The frame counter the script reads.
$frame = 0
module Graphics; def self.frame_count; $frame; end; def self.brightness; 255; end; end

# The notices shown, which the cases record.
$notices = []
# The messages sent, which the cases record.
$sent = []

# The map's interpreter, which holds a scene.
class Game_Interpreter; def execute_command; end; end

# The map, map 3.
class Game_Map; attr_accessor :map_id; def initialize; @map_id = 3; end; def update(main = false); end; end

# The player, at 0,0, who reserved no transfer.
class Game_Player
  Followers = Struct.new(:visible)
  attr_accessor :x, :y
  attr_reader :followers
  def initialize; @x = 0; @y = 0; @followers = Followers.new(true); end
  def refresh; end
  def direction; 2; end
  def movable?; true; end
  def perform_transfer; end
  def transfer?; false; end
  def make_encounter_count; end
end

# The map scene.
class Scene_Map; def update_call_menu; end; end
# The game's saves.
module DataManager; def self.extract_save_contents(contents); end; end
# The actions: the line above the player's head and the offers.
module MGQ_MpActions
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)
  def self.own_doing_from(&doing); end
  def self.lapse_in(frames); frames; end
  def self.lapse_at(since, frames); since + frames - Graphics.frame_count; end
  def self.offer(_offers); end
end
# The world: the other players from $peers, notices in $notices.
module MGQ_MpOverworldSync
  module Peers; Peer = Struct.new(:seat, :state); def self.present; $peers; end; def self.all; $peers; end; end
  def self.on_tick(&block); end
  def self.notice(text); $notices << text; end
  def self.who(peer); peer == :me ? "the player" : peer.state["name"].to_s; end
  def self.in_world?; true; end
  def self.map_free?; true; end
  module Me; def self.map_since; 2000; end; def self.id; "me"; end; end
end
# The party: led by $leader with the members $members.
module MGQ_MpCoop
  INVITE_COLOR = :invite
  module Party; def self.members; $members; end; end
  def self.party_leader; $leader; end
  def self.party_leading?; $leader == :me; end
  def self.in_party?; true; end
  module Scope
    def self.raid?; $raid; end
    def self.sharing?; true; end
    def self.viewers; $members; end
    def self.watches?(peer); $watching.include?(peer.state["id"]); end
    def self.telling?(peer); $telling_peers.include?(peer.state["id"]); end
    def self.teller; nil; end
    def self.peers_on(_map); []; end
    def self.silent?(_peer); false; end
  end
end
# The shared story's events: the player tells while $telling, is behind while $behind.
module MGQ_MpCoopEvents
  def self.pvp_running?; $pvp ? true : false; end
  def self.behind?; $behind ? true : false; end
  def self.keeps_autorun_of?(_peer); false; end
  def self.telling?; $telling ? true : false; end
  def self.story_playing?; $telling ? true : false; end
  def self.leading_story?; true; end
  def self.tell(seat, kind, fields = {}); $sent << [seat, kind, fields]; true; end
  def self.tell_each(peers, kind, fields = {}); $sent << [peers.map { |peer| peer.seat }, kind, fields]; true; end
end
# The story's state: the warp ban's switch, which the script of that commit reads.
module MGQ_MpStoryState; WARP_BAN = 100; end

script = ARGV[0] || abort("Name the coop_gather.rbx of commit d7bc93af, see the header.")
load File.join(SCRIPTS_DIR, "core_log.rbx")
load File.join(SCRIPTS_DIR, "core_hooks.rbx")
load File.join(SCRIPTS_DIR, "core_game_access.rbx")
load File.expand_path(script)
GATHER = MGQ_MpCoopGather

$game_map = Game_Map.new
$game_player = Game_Player.new
$game_switches = {}
$raid = false
$telling = false
$behind = false
$pvp = false
$watching = []
$telling_peers = []
$members = []
$leader = nil
LEADER = MGQ_MpOverworldSync::Peers::Peer.new(2, { "name" => "Leader", "id" => "leader", "map" => "9", "x" => "10", "y" => "10" })
OTHER = MGQ_MpOverworldSync::Peers::Peer.new(3, { "name" => "Other", "id" => "other", "map" => "9", "x" => "10", "y" => "10" })
TELLER = MGQ_MpOverworldSync::Peers::Peer.new(4, { "name" => "Teller", "id" => "t", "map" => "8", "x" => "1", "y" => "2", "d" => "2" })
PEERS = { "leader" => LEADER, "other" => OTHER, "t" => TELLER }
PLACE = [9, 10, 10, 2]

# The scenarios, each its name and steps.
SCENARIOS = []

# Records a scenario of steps.
#
# @param name [String] What the scenario shows.
# @param steps [Array<Hash>] The operations, see run_step.
def scenario(name, steps)
  $frame = 5000
  $notices = []
  $sent = []
  $raid = false
  $telling = false
  $behind = false
  $pvp = false
  $watching = []
  $telling_peers = []
  $members = []
  $leader = nil
  $game_map.map_id = 3
  GATHER.forget
  GATHER.forget_story_place
  GATHER.instance_variable_set(:@taken_follow, nil)
  GATHER.instance_variable_set(:@transfer_from, nil)
  recorded = steps.map { |step| step.merge("answer" => run_step(step)) }
  SCENARIOS << { "name" => name, "steps" => recorded }
end

# Runs one operation and reads what the script answers.
#
# @param step [Hash] "op" and its fields: "frame" (the frame it runs at), "called" ("by", a peer,
#   "place"), "come_to" ("name", "place"), "followed" ("by", "place"), "raid" (whether a Raid World
#   is open), "map" (the player's map), "pvp" (whether a PvP battle runs), "drop_call", "forget",
#   "hold", "holding" (asked before a command: "leading", "gathered"), "drop_hold", "arrived" (the
#   follow brought the player over), "offer" ("by", "place", "moves"), "watch" (the peers watched),
#   "telling" (the peers whose telling the relay told of), "accept" ("by"), "decline" ("by"),
#   "behind".
# @return [Hash] What the script answers after the step.
def run_step(step)
  $frame = step["frame"] if step["frame"]
  $notices.clear
  $sent.clear
  answer = {}
  case step["op"]
  when "called" then GATHER.called(PEERS[step["by"]], step["place"])
  when "come_to" then GATHER.come_to(step["name"], step["place"], nil)
  when "followed" then GATHER.followed(PEERS[step["by"]], step["place"], false)
  when "raid" then $raid = step["raid"]
  when "map" then $game_map.map_id = step["map"]
  when "pvp" then $pvp = step["pvp"]
  when "behind" then $behind = step["behind"]
  when "drop_call" then GATHER.drop_call("the test")
  when "forget" then GATHER.forget
  when "hold"
    $leader = :me
    $members = step["members"].map { |id| PEERS[id] }
    GATHER.hold(Game_Interpreter.new)
  when "members" then $members = step["members"].map { |id| PEERS[id] }
  when "holding"
    answer["holding"] = GATHER.holding?(GATHER.instance_variable_get(:@hold) ? GATHER.instance_variable_get(:@hold)[:interpreter] : Game_Interpreter.new)
  when "drop_hold" then GATHER.drop_hold
  when "arrived"
    gather = GATHER.instance_variable_get(:@gather)
    GATHER.instance_variable_set(:@taken_follow, { :id => gather[:id], :name => gather[:name], :place => gather[:place], :since => $frame })
    GATHER.instance_variable_set(:@gather, nil)
  when "offer" then GATHER.take(PEERS[step["by"]], { "pevent" => "follow", "map" => step["place"][0].to_s, "x" => step["place"][1].to_s, "y" => step["place"][2].to_s, "d" => step["place"][3].to_s, "moves" => step["moves"] }.reject { |_key, value| value.nil? })
  when "watch" then $watching = step["peers"]
  when "telling" then $telling_peers = step["peers"]
  when "accept" then GATHER.accept_follow(PEERS[step["by"]])
  when "decline" then GATHER.decline_follow(PEERS[step["by"]])
  end
  pending = GATHER.pending_call
  answer["coming"] = GATHER.coming?
  answer["due"] = GATHER.due?
  answer["pending"] = pending ? { "name" => pending[:name], "place" => pending[:place], "follow" => pending[:follow] ? true : false, "asked" => pending[:asked] ? true : false } : nil
  answer["come"] = GATHER.come?
  answer["doing"] = GATHER.own_doing
  answer["followed_id"] = GATHER.followed_id
  answer["story_map"] = [8, 9].select { |map| GATHER.story_map?(map) }
  answer["calling_battle"] = PEERS.keys.select { |id| GATHER.calling_battle?(PEERS[id], 9) }
  answer["holding_story"] = GATHER.holding_story?
  answer["offers"] = PEERS.keys.select { |id| GATHER.follow_offer(PEERS[id]) }
  answer["notices"] = $notices.dup
  answer["sent"] = $sent.map { |seat, kind, _fields| [seat, kind] }
  answer
end

scenario("a leader's call brings the member over after GATHER_FRAMES once settled, lapses once the calls stop, and a battle of the caller on its map belongs to it", [
  { "op" => "called", "by" => "leader", "place" => PLACE, "frame" => 5000 },
  { "op" => "holding", "frame" => 5120 },
  { "op" => "holding", "frame" => 5300 },
  { "op" => "called", "by" => "leader", "place" => PLACE, "frame" => 5301 },
  { "op" => "holding", "frame" => 5302 },
  { "op" => "holding", "frame" => 5302 + 360 },
  { "op" => "holding", "frame" => 5302 + 361 },
])

scenario("a call from before a loaded save's lower frame count is long past, and a loaded save forgets a call", [
  { "op" => "called", "by" => "leader", "place" => PLACE, "frame" => 5000 },
  { "op" => "holding", "frame" => 100 },
  { "op" => "called", "by" => "leader", "place" => PLACE, "frame" => 100 },
  { "op" => "forget", "frame" => 101 },
])

scenario("a teleport the player asked for comes at once and waits a minute, and a leader's call that takes it over lapses as a call does", [
  { "op" => "come_to", "name" => "Friend", "place" => [4, 1, 1, 2], "frame" => 5000 },
  { "op" => "holding", "frame" => 5001 },
  { "op" => "come_to", "name" => "Friend", "place" => [4, 1, 1, 2], "frame" => 6000 },
  { "op" => "holding", "frame" => 6000 + 3599 },
  { "op" => "holding", "frame" => 6000 + 3600 },
  { "op" => "come_to", "name" => "Friend", "place" => [4, 1, 1, 2], "frame" => 7000 },
  { "op" => "called", "by" => "leader", "place" => PLACE, "frame" => 7001 },
  { "op" => "holding", "frame" => 7001 + 360 },
])

scenario("a Classic follow comes at once and lapses as a call does; a Raid follow waits a minute and names its teller while on the way and shortly after arriving", [
  { "op" => "followed", "by" => "leader", "place" => [8, 1, 2, 2], "frame" => 5000 },
  { "op" => "holding", "frame" => 5000 + 360 },
  { "op" => "raid", "raid" => true, "frame" => 6000 },
  { "op" => "followed", "by" => "t", "place" => [8, 1, 2, 2], "frame" => 6000 },
  { "op" => "holding", "frame" => 6000 + 1200 },
  { "op" => "arrived", "frame" => 6000 + 1201 },
  { "op" => "map", "map" => 8, "frame" => 6000 + 1202 },
  { "op" => "holding", "frame" => 6000 + 1202 + 359 },
  { "op" => "holding", "frame" => 6000 + 1202 + 360 },
  { "op" => "followed", "by" => "t", "place" => [8, 1, 2, 2], "frame" => 8000 },
  { "op" => "holding", "frame" => 8000 + 3600 },
])

scenario("a call during a PvP battle is kept out, and a dropped call is forgotten", [
  { "op" => "pvp", "pvp" => true, "frame" => 5000 },
  { "op" => "called", "by" => "leader", "place" => PLACE, "frame" => 5000 },
  { "op" => "pvp", "pvp" => false, "frame" => 5001 },
  { "op" => "called", "by" => "leader", "place" => PLACE, "frame" => 5001 },
  { "op" => "drop_call", "frame" => 5002 },
])

scenario("a leader's story waits for the party, calling again every CALL_FRAMES, until everyone is near or HOLD_FRAMES passed", [
  { "op" => "hold", "members" => ["leader", "other"], "frame" => 5000 },
  { "op" => "holding", "frame" => 5001 },
  { "op" => "holding", "frame" => 5180 },
  { "op" => "holding", "frame" => 5181 },
  { "op" => "members", "members" => [], "frame" => 5182 },
  { "op" => "holding", "frame" => 5182 },
  { "op" => "hold", "members" => ["leader"], "frame" => 6000 },
  { "op" => "holding", "frame" => 6000 + 1799 },
  { "op" => "holding", "frame" => 6000 + 1800 },
  { "op" => "hold", "members" => ["leader"], "frame" => 7000 },
  { "op" => "drop_hold", "frame" => 7001 },
])

scenario("a Raid World offers a follow to a player whose telling the relay told of nothing of, which stands a minute, ends with a telling seen, or once the player is on that map", [
  { "op" => "raid", "raid" => true, "frame" => 5000 },
  { "op" => "offer", "by" => "t", "place" => [8, 1, 2, 2], "frame" => 5000 },
  { "op" => "holding", "frame" => 5000 + 3599 },
  { "op" => "holding", "frame" => 5000 + 3600 },
  { "op" => "offer", "by" => "t", "place" => [8, 1, 2, 2], "frame" => 9000 },
  { "op" => "telling", "peers" => ["t"], "frame" => 9001 },
  { "op" => "telling", "peers" => [], "frame" => 9002 },
  { "op" => "offer", "by" => "t", "place" => [8, 1, 2, 2], "frame" => 9100 },
  { "op" => "map", "map" => 8, "frame" => 9101 },
  { "op" => "map", "map" => 3, "frame" => 9102 },
  { "op" => "offer", "by" => "t", "place" => [8, 1, 2, 2], "frame" => 9200 },
  { "op" => "decline", "by" => "t", "frame" => 9201 },
  { "op" => "offer", "by" => "t", "place" => [8, 1, 2, 2], "frame" => 9300 },
  { "op" => "accept", "by" => "t", "frame" => 9301 },
])

scenario("a Raid World's follow is taken at once by a player watching the telling that moves the story on, offered to one behind or to one of a telling that does not", [
  { "op" => "raid", "raid" => true, "frame" => 5000 },
  { "op" => "watch", "peers" => ["t"], "frame" => 5000 },
  { "op" => "telling", "peers" => ["t"], "frame" => 5000 },
  { "op" => "offer", "by" => "t", "place" => [8, 1, 2, 2], "frame" => 5000 },
  { "op" => "forget", "frame" => 5001 },
  { "op" => "offer", "by" => "t", "place" => [8, 1, 2, 2], "moves" => "0", "frame" => 5002 },
  { "op" => "decline", "by" => "t", "frame" => 5003 },
  { "op" => "behind", "behind" => true, "frame" => 5004 },
  { "op" => "offer", "by" => "t", "place" => [8, 1, 2, 2], "frame" => 5004 },
])

lines = SCENARIOS.map { |entry| "    " + JSON.generate(entry) }
constants = { "gather_frames" => GATHER::GATHER_FRAMES, "call_frames" => GATHER::CALL_FRAMES, "hold_frames" => GATHER::HOLD_FRAMES, "call_lapse_frames" => GATHER::CALL_LAPSE_FRAMES,
              "asked_lapse_frames" => GATHER::ASKED_LAPSE_FRAMES, "follow_offer_frames" => GATHER::FOLLOW_OFFER_FRAMES, "gather_tiles" => GATHER::GATHER_TILES, "named_missing" => GATHER::NAMED_MISSING }
text = "{\n  \"source\": \"coop_gather.rbx at d7bc93af, Ruby #{RUBY_VERSION}\",\n  \"frames\": #{JSON.generate(constants)},\n  \"scenarios\": [\n#{lines.join(",\n")}\n  ]\n}\n"
File.write(File.join(__dir__, "cases.json"), text)
puts "wrote #{SCENARIOS.size} scenarios"
