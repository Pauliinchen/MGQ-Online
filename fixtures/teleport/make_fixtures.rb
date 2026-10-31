#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#                            - Left the warp ban out of the places and the teleports
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the teleport requests next to this file, cases.json, from
# coop_teleport.rbx as it kept them before they moved to C# (MGQOnline.Game's
# Teleports/TeleportRequests): asking, the leader allowing at once, a member allowing or declining,
# the time-out, taking a request back, the forget on a loaded save and a stray answer. Each scenario
# is a list of steps; a step's operation runs at its frame, then the step records what the script
# sent, showed, logged and offered. MGQOnline.Game.Tests replays them against the C# machine.
#
# It runs on the coop_teleport.rbx of commit 40f11e4d, which still kept the rules, with the
# stand-ins below, on Ruby 3.3:
#
#   git show 40f11e4d:GameScript/Multiplayer/Scripts/coop_teleport.rbx > old_teleport.rbx
#   ruby fixtures/teleport/make_fixtures.rb old_teleport.rbx

require "json"
require_relative "../../GameScript/Tests/support"

# The log, whose lines the cases record.
$logs = []
module MGQ_Multiplayer::Log; def self.write(line); $logs << line; end; end

# The frame counter the script reads.
$frame = 0
module Graphics; def self.frame_count; $frame; end; end

# The notices shown, the messages sent and the teleports started, which the cases record.
$notices = []
$sent = []
$come_to = []

# The map, the player's own map.
class Game_Map; attr_accessor :map_id; def initialize; @map_id = 3; end; end
# The player, where they stand and face.
class Game_Player
  attr_accessor :x, :y, :direction
  def initialize; @x = 0; @y = 0; @direction = 2; end
end
# The game's saves, whose loading the script hooks.
module DataManager; def self.extract_save_contents(_contents); end; end

# The actions: the options, the notices, and the moments a lapse falls on, here frames left.
module MGQ_MpActions
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)
  def self.own_doing_from(&_doing); end
  def self.lapse_in(frames); frames; end
  def self.lapse_at(since, frames); since + frames - Graphics.frame_count; end
  def self.offer(_offers); end
end

# The world: the other players from $peers, notices into $notices, messages written as
# overworld_sync.rbx's Me.encode writes them.
module MGQ_MpOverworldSync
  module Peers; Peer = Struct.new(:seat, :state); def self.all; $peers; end; end
  module Me; def self.id; "me000001"; end; end
  def self.on_tick(&_block); end
  def self.state_fields(&_block); end
  def self.on_observe(&_block); end
  def self.notice(text); $notices << text; end
  def self.who(peer); peer == :me ? "the player" : "#{peer.state['name']} (seat #{peer.seat})"; end
  def self.encode(state); state.map { |key, value| "#{key}=#{value.to_s.gsub(/[\r\n]/, ' ')}" }.join("\n") + "\n\n"; end
end

# The party: its id $party, its members those who name it, led by $leader; a tell is written as
# coop.rbx's tell writes it, and fails while $tell_fails.
module MGQ_MpCoop
  NAMED_INVITE_FRAMES = 3600
  INVITE_COLOR = :invite
  module Party
    def self.id; $party; end
    def self.member?(state); !$party.nil? && state["party"] == $party; end
    def self.members; $peers.select { |peer| member?(peer.state) }; end
  end
  def self.in_party?; !$party.nil? && !Party.members.empty?; end
  def self.party_leader; in_party? ? $leader : nil; end
  def self.route(_field, &_handler); end
  def self.random_id(_length); $nonce = $nonce.to_i + 1; "n#{$nonce}"; end
  def self.tell(seat, field, value, fields = {})
    $sent << [seat, MGQ_MpOverworldSync.encode({ field => value, "party" => Party.id }.merge(fields))]
    !$tell_fails
  end
end

# The gathering: its near check, the player's place and frame count as coop_gather.rbx of 40f11e4d
# kept them, and the teleports started, into $come_to.
module MGQ_MpCoopGather
  GATHER_TILES = 3
  def self.near_place?(state, place)
    state["map"].to_i == place[0] && [(state["x"].to_i - place[1]).abs, (state["y"].to_i - place[2]).abs].max <= GATHER_TILES
  end
  def self.own_place; { "map" => $game_map.map_id, "x" => $game_player.x, "y" => $game_player.y }; end
  def self.place_fields
    { "map" => $game_map.map_id, "x" => $game_player.x, "y" => $game_player.y, "d" => $game_player.direction }
  end
  def self.frames_left(since, frames); since + frames - Graphics.frame_count; end
  def self.within?(since, frames); left = frames_left(since, frames); left > 0 && left <= frames; end
  def self.come_to(name, place, _warp_ban); $come_to << [name, place]; end
end

script = ARGV[0] || abort("Name the coop_teleport.rbx of commit 40f11e4d, see the header.")
load File.join(SCRIPTS_DIR, "core_log.rbx")
load File.join(SCRIPTS_DIR, "core_hooks.rbx")
load File.join(SCRIPTS_DIR, "core_game_access.rbx")
load File.expand_path(script)
TELEPORT = MGQ_MpCoopTeleport

$game_map = Game_Map.new
$game_player = Game_Player.new

# The other players, by id: the party's leader, a member who does not lead, and a player of another
# party, on maps far from the player.
def peers
  {
    "leader01" => MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "leader01", "name" => "Leader", "map" => "9", "x" => "10", "y" => "10" }),
    "friend01" => MGQ_MpOverworldSync::Peers::Peer.new(3, { "id" => "friend01", "name" => "Friend", "map" => "7", "x" => "4", "y" => "4" }),
    "strange1" => MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "strange1", "name" => "Stranger", "party" => "strange1p2", "map" => "7", "x" => "4", "y" => "4" }),
  }
end

# The scenarios, each its name, who leads and its steps.
SCENARIOS = []

# Records a scenario of steps.
#
# @param name [String] What the scenario shows.
# @param leader [String] "leader01" for the leader's party the player joined, "me" for the party
#   the player leads.
# @param steps [Array<Hash>] The operations, see run_step.
def scenario(name, leader, steps)
  $frame = 1000
  $nonce = 0
  $tell_fails = false
  $game_map.map_id = 3
  $game_player.x = 0
  $game_player.y = 0
  $game_player.direction = 2
  $by_id = peers
  $peers = $by_id.values
  $party = leader == "me" ? "me000001p1" : "leader01p1"
  $leader = leader == "me" ? :me : $by_id["leader01"]
  $peers.each { |peer| peer.state["party"] ||= $party }
  $peers.delete($by_id["leader01"]) if leader == "me"
  TELEPORT.forget("the test")
  recorded = steps.map { |step| step.merge("answer" => run_step(step)) }
  SCENARIOS << { "name" => name, "leader" => leader, "steps" => recorded }
end

# Runs one operation and reads what the script answers.
#
# @param step [Hash] "op" and its fields: "frame" (the frame it runs at), "ask" ("to"), "take"
#   ("from", "kind", "fields"), "request" ("from", "tpask", the request their state tells),
#   "observe" ("from"), "allow" ("from"), "decline" ("from"), "stop", "tick" ("in_world"), "load",
#   "place" ("map", "x", "y", "d"), "party" ("of", "party", the party their state names),
#   "fails" (whether the messages sent fail).
# @return [Hash] What the script answers after the step.
def run_step(step)
  $frame = step["frame"] if step["frame"]
  $logs.clear
  $notices.clear
  $sent.clear
  $come_to.clear
  case step["op"]
  when "ask" then TELEPORT.ask($by_id[step["to"]])
  when "take" then TELEPORT.take($by_id[step["from"]], { "ptp" => step["kind"], "party" => $party }.merge(step["fields"]))
  when "request" then $by_id[step["from"]].state["tpask"] = step["tpask"]
  when "observe" then TELEPORT.observe($by_id[step["from"]])
  when "allow" then TELEPORT.allow($by_id[step["from"]])
  when "decline" then TELEPORT.decline($by_id[step["from"]])
  when "stop" then TELEPORT.stop_asking("the player stopped asking")
  when "tick" then TELEPORT.tick(step["in_world"])
  when "load" then DataManager.extract_save_contents({})
  when "place"
    $game_map.map_id = step["map"]
    $game_player.x = step["x"]
    $game_player.y = step["y"]
    $game_player.direction = step["d"]
  when "party" then $by_id[step["of"]].state["party"] = step["party"]
  when "fails" then $tell_fails = step["fails"]
  end
  read_answer
end

# Reads what the script shows after a step: its messages, notices, log lines and teleports, the
# request its state tells, and its offers for each other player, its own row and its doing.
#
# @return [Hash] The answer.
def read_answer
  offers = {}
  $peers.each do |peer|
    id = peer.state["id"]
    notice = TELEPORT::Offers.notice_of(peer)
    option = TELEPORT::Offers.peer_option(peer)
    member = MGQ_MpCoop::Party.member?(peer.state)
    teleport = member ? TELEPORT.option(peer) : nil
    offers[id] = {
      "call" => TELEPORT::Offers.call_of(peer) && TELEPORT::Offers.call_of(peer)[0],
      "notice" => notice && [notice.text, notice.action, notice.mark],
      "option" => option && [option.text, option.refusal, !option.run.nil?],
      "teleport" => teleport && [teleport.text, teleport.refusal, !teleport.run.nil?],
    }
  end
  {
    "sent" => $sent.dup, "notices" => $notices.dup, "logs" => $logs.dup, "come_to" => $come_to.dup,
    "tpask" => TELEPORT.state_fields["tpask"], "offers" => offers, "own" => TELEPORT::Offers.own_options.map(&:text), "doing" => TELEPORT.own_doing,
  }
end

FAR = { "op" => "place", "map" => 3, "x" => 0, "y" => 0, "d" => 2 }

scenario("a member teleports to the leader at once, ignoring answers from another member or to an older request", "leader01", [
  { "op" => "ask", "to" => "leader01", "frame" => 1000 },
  { "op" => "take", "from" => "friend01", "kind" => "allow", "fields" => { "nonce" => "n1", "map" => "5", "x" => "1", "y" => "1", "d" => "2" }, "frame" => 1010 },
  { "op" => "take", "from" => "leader01", "kind" => "allow", "fields" => { "nonce" => "n0", "map" => "5", "x" => "1", "y" => "1", "d" => "2" }, "frame" => 1020 },
  { "op" => "take", "from" => "leader01", "kind" => "allow", "fields" => { "map" => "9", "x" => "10", "y" => "10", "d" => "4", "nonce" => "n1" }, "frame" => 1030 },
  { "op" => "ask", "to" => "leader01", "frame" => 1040 },
  { "op" => "place", "map" => 9, "x" => 11, "y" => 12, "d" => 8, "frame" => 1050 },
  { "op" => "take", "from" => "leader01", "kind" => "allow", "fields" => { "map" => "9", "x" => "10", "y" => "10", "d" => "4", "nonce" => "n2" }, "frame" => 1060 },
  { "op" => "ask", "to" => "leader01", "frame" => 1070 },
])

scenario("the leader lets a member come at once, once, and never answers a player outside the party", "me", [
  { "op" => "place", "map" => 3, "x" => 5, "y" => 6, "d" => 4, "frame" => 1000 },
  { "op" => "request", "from" => "friend01", "tpask" => "me000001:x1", "frame" => 1001 },
  { "op" => "observe", "from" => "friend01", "frame" => 1002 },
  { "op" => "observe", "from" => "friend01", "frame" => 1003 },
  { "op" => "request", "from" => "strange1", "tpask" => "me000001:y1", "frame" => 1004 },
  { "op" => "observe", "from" => "strange1", "frame" => 1005 },
  { "op" => "request", "from" => "friend01", "tpask" => "other999:x2", "frame" => 1006 },
  { "op" => "observe", "from" => "friend01", "frame" => 1007 },
])

scenario("a member who does not lead allows or declines a request in the notification box, each once", "leader01", [
  { "op" => "request", "from" => "friend01", "tpask" => "me000001:x2", "frame" => 1000 },
  { "op" => "observe", "from" => "friend01", "frame" => 1001 },
  { "op" => "allow", "from" => "friend01", "frame" => 1002 },
  { "op" => "allow", "from" => "friend01", "frame" => 1003 },
  { "op" => "request", "from" => "friend01", "tpask" => "me000001:x3", "frame" => 1004 },
  { "op" => "decline", "from" => "friend01", "frame" => 1005 },
  { "op" => "request", "from" => "friend01", "tpask" => "me000001:x4", "frame" => 1006 },
  { "op" => "fails", "fails" => true, "frame" => 1007 },
  { "op" => "allow", "from" => "friend01", "frame" => 1008 },
  { "op" => "request", "from" => "friend01", "tpask" => "", "frame" => 1009 },
])

scenario("asking another member waits for their answer: declined, allowed, replaced and taken back", "leader01", [
  { "op" => "ask", "to" => "friend01", "frame" => 1000 },
  { "op" => "take", "from" => "friend01", "kind" => "deny", "fields" => { "nonce" => "n1" }, "frame" => 1100 },
  { "op" => "ask", "to" => "friend01", "frame" => 1200 },
  { "op" => "take", "from" => "friend01", "kind" => "allow", "fields" => { "map" => "7", "x" => "4", "y" => "4", "d" => "2", "nonce" => "n2" }, "frame" => 1300 },
  { "op" => "ask", "to" => "friend01", "frame" => 1400 },
  { "op" => "ask", "to" => "leader01", "frame" => 1500 },
  { "op" => "stop", "frame" => 1600 },
  { "op" => "stop", "frame" => 1700 },
])

scenario("a request runs out after a minute, ends once its member left the party, and goes with a loaded save or the world's close", "leader01", [
  { "op" => "ask", "to" => "friend01", "frame" => 1000 },
  { "op" => "tick", "in_world" => true, "frame" => 2800 },
  { "op" => "tick", "in_world" => true, "frame" => 4599 },
  { "op" => "tick", "in_world" => true, "frame" => 4600 },
  { "op" => "ask", "to" => "friend01", "frame" => 5000 },
  { "op" => "party", "of" => "friend01", "party" => "other999p3", "frame" => 5001 },
  { "op" => "tick", "in_world" => true, "frame" => 5002 },
  { "op" => "party", "of" => "friend01", "party" => "leader01p1", "frame" => 5003 },
  { "op" => "ask", "to" => "friend01", "frame" => 5004 },
  { "op" => "load", "frame" => 5005 },
  { "op" => "tick", "in_world" => true, "frame" => 5006 },
  { "op" => "ask", "to" => "friend01", "frame" => 5007 },
  { "op" => "tick", "in_world" => false, "frame" => 5008 },
])

scenario("a player standing near a member already neither asks nor teleports to them", "leader01", [
  { "op" => "place", "map" => 7, "x" => 5, "y" => 4, "d" => 2, "frame" => 1000 },
  { "op" => "ask", "to" => "friend01", "frame" => 1001 },
  FAR.merge("frame" => 1002),
  { "op" => "ask", "to" => "friend01", "frame" => 1003 },
  { "op" => "place", "map" => 7, "x" => 7, "y" => 1, "d" => 2, "frame" => 1004 },
  { "op" => "take", "from" => "friend01", "kind" => "allow", "fields" => { "map" => "7", "x" => "4", "y" => "4", "d" => "2", "nonce" => "n1" }, "frame" => 1005 },
])

scenario("an answer of an unknown kind ends the request, and an answer nobody asked for is ignored", "leader01", [
  { "op" => "take", "from" => "friend01", "kind" => "deny", "fields" => { "nonce" => "n1" }, "frame" => 1000 },
  { "op" => "ask", "to" => "friend01", "frame" => 1001 },
  { "op" => "take", "from" => "friend01", "kind" => "maybe", "fields" => { "nonce" => "n1" }, "frame" => 1002 },
])

lines = SCENARIOS.map { |entry| "    " + JSON.generate(entry) }
constants = { "ask_frames" => TELEPORT::ASK_FRAMES, "nonce_length" => TELEPORT::NONCE_LENGTH, "gather_tiles" => MGQ_MpCoopGather::GATHER_TILES, "field" => TELEPORT::FIELD }
text = "{\n  \"source\": \"coop_teleport.rbx at 40f11e4d, Ruby #{RUBY_VERSION}\",\n  \"constants\": #{JSON.generate(constants)},\n  \"scenarios\": [\n#{lines.join(",\n")}\n  ]\n}\n"
File.write(File.join(__dir__, "cases.json"), text)
puts "wrote #{SCENARIOS.size} scenarios"
