#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Left the party steps of a standing invite to the C# rule
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the world room's rules next to this file, cases.json, from the scripts
# that kept them before they moved to C#: overworld_sync.rbx (the other players, their settle and
# away windows, the player's state, the inbox, ping and status), coop.rbx (the party) and
# coop_scope.rbx (the party's and the map's message gates). Each scenario is a list of steps; a
# step's operations run, then one frame (MGQ_MpOverworldSync.tick), after "wait" frames before it,
# and the step records what the frame did. MGQOnline.Game.Tests replays them against the C# room.
# The party steps where a player joins while the invite stands no longer come from here: they were
# written anew from the C# rule once an invite stood for everyone it reached.
#
# It runs on the scripts of the commit that added it, with the stand-ins of
# GameScript/Tests/world_support.rb, on Ruby 3.3:
#
#   ruby fixtures/peers/make_fixtures.rb

require "json"
require_relative "../../GameScript/Tests/world_support"

# The log stays quiet; the cases record what the rules did, not their lines.
module MGQ_Multiplayer::Log; def self.write(_line); end; end

# RGSS3's Ruby 1.9.2 folds ASCII letters only, as the game's names are compared; Ruby 3.3 folds
# all of Unicode.
class String
  alias_method :harness_downcase, :downcase
  # Folds ASCII letters only.
  def downcase(*); harness_downcase(:ascii); end
end

# The clock the player's map entry is stamped by, in seconds, which a step may move.
$clock = 1_700_000_000
class << Time
  alias_method :harness_now, :now
  # Answers the harness clock.
  def now; at($clock); end
end

# The player's id, as long as a real one's start, which a party's id begins with.
module MGQ_Multiplayer::Link; def self.player_id; "me000000"; end; end

# A Raid World while $raid is set.
module MGQ_MpWorld; def self.raid?; $raid ? true : false; end; end

# The connection as the DLL tells it: open on $status_seat with the ping $status_ping.
module MGQ_MpOverworldSync::Link
  # Answers the connection's status.
  def self.status; { "state" => $status_state || "open", "seat" => $status_seat.to_s, "ping" => $status_ping.to_s }; end
end

# The map the story takes the player to, besides their own, from $story_map.
module MGQ_MpCoop::Scope
  # Answers whether a map is the player's or the story's.
  def self.story_map?(map_id); map_id == $game_map.map_id || (!$story_map.nil? && map_id == $story_map); end
end

# Party ids end in a counted suffix in place of random letters.
module MGQ_MpCoop
  # Answers the next counted suffix.
  def self.random_id(_length); "p#{$ids += 1}"; end
end

# The probe routes: one of every gate, recording what reaches them.
$routed = []
MGQ_MpOverworldSync.route("probe") { |peer, message| $routed << ["probe", peer && peer.seat, message] }
MGQ_MpCoop.route("pprobe") { |peer, message| $routed << ["pprobe", peer && peer.seat, message] }
MGQ_MpCoop.route_map("mprobe") { |peer, message| $routed << ["mprobe", peer && peer.seat, message] }
%w[story_rev boss_key difficulty_value squad_value raid_bosses_value mods_rule_value].each do |field|
  MGQ_MpOverworldSync.route(field) { |peer, message| $routed << [field, peer && peer.seat, message] }
end

# Records every notice.
$notices = []
module MGQ_MpOverworldSync::Status
  class << self
    alias_method :harness_notice, :notice
    # Records the notice, then shows it.
    def notice(text, icon = nil); $notices << text; harness_notice(text, icon); end
  end
end

# The fields the C# room adds to the player's state; the rest is what Ruby hands over.
OWN_FIELDS = %w[id name since ping party party_members invite invite_to]

# The Ruby part of the player's state at each frame, as the C# room is handed it.
$ruby_state = nil
module MGQ_MpOverworldSync::Me
  class << self
    alias_method :harness_current, :current
    # Records the Ruby part of the state.
    def current
      state = harness_current
      $ruby_state = state && state.reject { |key, _| OWN_FIELDS.include?(key) }
      state
    end
  end
end

# Writes fields as a message.
#
# @param fields [Hash] The fields.
# @return [String] The message.
def message_text(fields)
  fields.map { |key, value| "#{key}=#{value}" }.join("\n") + "\n\n"
end

# Turns a message's fields into plain JSON values.
#
# @param message [Hash] The fields, the body under :payload and the relay's mark under :relay.
# @return [Hash] The fields, the body under "(payload)" when there is one, "(relay)" when marked.
def plain(message)
  fields = message.reject { |key, _| key.is_a?(Symbol) }
  fields["(payload)"] = message[:payload] unless message[:payload].to_s.empty?
  fields["(relay)"] = true if message[:relay]
  fields
end

# Forgets everything the scripts keep, as a game that just started.
def fresh
  sync = MGQ_MpOverworldSync
  sync::Peers.instance_variable_set(:@peers, {})
  sync::Peers.instance_variable_set(:@in_world, 0)
  %i[@told @failing @seat @since @since_map @identity].each { |name| sync::Me.instance_variable_set(name, nil) }
  sync::Status.instance_variable_set(:@frames, 0)
  sync::Status.instance_variable_set(:@notices, [])
  sync::Status.instance_variable_set(:@problem, nil)
  sync::Status.instance_variable_set(:@logged_connection, nil)
  sync::Ping.instance_variable_set(:@told, "")
  sync::Ping.instance_variable_set(:@measured, nil)
  MGQ_MpCoop::Party.reset
  MGQ_MpCoop::Party.instance_variable_set(:@invites_seen, {})
  $open = true
  $raid = false
  $story_map = nil
  $status_seat = nil
  $status_ping = nil
  $status_state = nil
  $clock = 1_700_000_000
  $ids = 0
  $game_map.map_id = 5
  $game_player.x = 3
  $game_player.y = 4
  $inbox.clear
  $sent.clear
end

# Runs one operation of a step.
#
# @param op [Array] The operation and its arguments.
def run(op)
  party = MGQ_MpCoop::Party
  peers = MGQ_MpOverworldSync::Peers
  case op[0]
  when "seat" then $status_seat = op[1]; $inbox << { "kind" => "seat", "seat" => op[1].to_s, "others" => "", :payload => "" }
  when "in", "out" then $inbox << entry(op[0], op[1])
  when "state" then $inbox << entry("message", op[1], told(op[2]))
  when "message" then $inbox << entry("message", op[1], message_text(op[2]) + op[3].to_s)
  when "relay" then $inbox << op[2].merge("kind" => op[1], :payload => op[3].to_s)
  when "me"
    $game_map.map_id = op[1]["map"] if op[1]["map"]
    $game_player.x = op[1]["x"] if op[1]["x"]
    $game_player.y = op[1]["y"] if op[1]["y"]
  when "world" then $open = op[1]
  when "raid" then $raid = op[1]
  when "story_map" then $story_map = op[1]
  when "ping" then $status_ping = op[1]
  when "status" then $status_state = op[1]
  when "clock" then $clock = op[1]
  when "reset_since" then MGQ_MpOverworldSync::Me.reset_map_since
  when "invite" then party.invite(op[1])
  when "stop_inviting" then party.stop_inviting
  when "join" then party.join(peers.at(op[1]))
  when "decline" then party.decline(peers.at(op[1]))
  when "leave" then party.leave
  when "remove" then party.remove(peers.at(op[1]))
  else raise "unknown operation #{op[0]}"
  end
end

# Tells what one frame did and how things stand after it.
#
# @return [Hash] The frame's outcome.
def outcome
  party = MGQ_MpCoop::Party
  leader = MGQ_MpCoop.leader_of(party.id)
  peers = MGQ_MpOverworldSync::Peers
  {
    "sent" => $sent.map { |seat, text| [seat, plain(MGQ_Multiplayer::Link.parse(text.dup))] },
    "notices" => $notices.dup,
    "routed" => $routed.map { |field, seat, message| [field, seat, plain(message)] },
    "peers" => peers.all.map { |peer| [peer.seat, peer.state["id"].to_s, peer.away ? true : false, peer.member ? true : false] },
    "labels" => peers.labeled.map { |label, peer| [peer.seat, label] },
    "seat" => MGQ_MpOverworldSync::Me.instance_variable_get(:@seat),
    "problem" => MGQ_MpOverworldSync::Status.instance_variable_get(:@problem),
    "party" => {
      "id" => party.id,
      "admitted" => party.admitted,
      "joining" => party.instance_variable_get(:@joining),
      "inviting" => party.inviting?,
      "invite_left" => party.invite_frames_left,
      "targets" => party.targets,
      "leader" => leader == :me ? -1 : (leader && leader.seat),
      "members" => party.members.map(&:seat),
    },
  }
end

# Plays a scenario's steps.
#
# @param steps [Array<Array>] Each step's operations.
# @return [Array<Hash>] Each step's operations, the Ruby part of the state at its frame and its
#   outcome.
def play(steps)
  fresh
  steps.map do |ops|
    waits = ops.select { |op| op[0] == "wait" }.map { |op| op[1] }.sum
    actions = ops.reject { |op| op[0] == "wait" }
    $sent.clear
    $notices.clear
    $routed.clear
    actions.each { |op| run(op) }
    waits.times { MGQ_MpOverworldSync.tick }
    $ruby_state = nil
    MGQ_MpOverworldSync.tick
    # Through JSON at once, since the scripts change the lists they hand out later on.
    { "ops" => ops, "state" => $ruby_state, "in_world" => $open ? true : false, "outcome" => JSON.parse(JSON.generate(outcome)) }
  end
end

# A player's state as their game tells it.
#
# @param id [String] Their id.
# @param name [String] Their name.
# @param more [Hash] Other fields, such as "x".
# @return [Hash] The state's fields.
def player(id, name, more = {})
  { "id" => id, "name" => name, "sprite" => "Actor2", "index" => 3, "map" => 5, "x" => 10, "y" => 10, "d" => 2, "speed" => 4, "hidden" => 0, "scene" => "map" }.merge(more)
end

A = player("aaaaaaaa", "Anna")
B = player("bbbbbbbb", "Bert")
C = player("cccccccc", "Cleo")
D = player("dddddddd", "Dora")
E = player("eeeeeeee", "Emil")

SCENARIOS = {
  # A new seat tells everyone the state, a newcomer is told alone, and only a change is told.
  "own state" => [
    [["seat", 0]],
    [],
    [["me", { "x" => 4 }]],
    [["in", 2]],
    [["clock", 1_700_000_100], ["me", { "map" => 7 }]],
    [["clock", 1_700_000_200], ["me", { "map" => 5 }]],
    [["clock", 1_700_000_300], ["reset_since"]],
    [["ping", 50], ["wait", 30]],
    [["ping", 60], ["wait", 29]],
    [["ping", 75], ["wait", 29]],
    [["ping", 200], ["wait", 29]],
    [["status", "reconnecting"], ["wait", 29]],
    [["status", "open"], ["wait", 29]],
    [["world", false]],
    [["world", true], ["seat", 1]],
  ],
  # Players already in the world come without a notice for SETTLE_FRAMES; later ones join with one.
  "settle window" => [
    [["seat", 0], ["state", 2, A]],
    [["wait", 298], ["state", 3, B]],
    [["state", 4, C]],
    [["state", 5, D]],
    [["state", 5, D.merge("x" => 11)]],
    [["out", 5]],
  ],
  # A player away is kept REJOIN_FRAMES; one back in time stays, one who moved seats too, and a
  # stranger on their seat replaces them.
  "away window" => [
    [["seat", 0], ["state", 2, A], ["state", 3, B], ["state", 4, C], ["wait", 301]],
    [["out", 2]],
    [["wait", 100], ["state", 2, A.merge("x" => 12)]],
    [["out", 3]],
    [["wait", 897]],
    [],
    [["out", 4], ["state", 5, C]],
    [["state", 6, D], ["out", 6]],
    [["state", 6, E]],
    [["seat", 1]],
    [["wait", 899]],
    [["world", false]],
  ],
  # Names several players share are numbered by id, whatever their case, and a player away has none.
  "labels" => [
    [["seat", 0], ["state", 2, player("zzzzzzzz", "Kim")], ["state", 3, player("aaaaaaaa", "kim")], ["state", 4, player("mmmmmmmm", "KIM")], ["state", 5, player("nnnnnnnn", "")]],
    [["out", 3]],
    [["state", 6, player("bbbbbbbb", "Élise")], ["state", 7, player("cccccccc", "élise")]],
  ],
  # Relay pushes and messages reach their routes; a message nobody takes is dropped.
  "routes" => [
    [["seat", 0], ["state", 2, A]],
    [["relay", "story", { "rev" => "12" }], ["relay", "boss", { "key" => "k 1", "left" => "0.5", "max" => "900", "defeated" => "0", "by" => "" }]],
    [["relay", "difficulty", { "value" => "3" }], ["relay", "squad", { "value" => "1 4 4 4" }], ["relay", "raid_bosses", { "value" => "1" }]],
    [["relay", "mods_rule", { "value" => "1", "mods" => "a\tb" }], ["relay", "mods_rule", { "value" => "0" }]],
    [["message", 2, { "probe" => "1", "x" => "y" }, "the body"], ["message", 3, { "probe" => "2" }], ["message", 2, { "nobody" => "1" }]],
    [["message", 2, { "probe" => "1", "state" => "1" }]],
  ],
  # The party's gate takes only an admitted member's messages of the player's party.
  "party gate" => [
    [["seat", 0], ["state", 2, A.merge("x" => 4, "y" => 4)], ["state", 3, B], ["message", 4, { "pprobe" => "1", "party" => "x" }]],
    [["message", 2, { "pprobe" => "1", "party" => "x" }]],
    [["invite"], ["message", 2, { "pprobe" => "1", "party" => "me000000p1" }]],
    [["state", 2, A.merge("x" => 4, "y" => 4, "party" => "me000000p1")], ["message", 2, { "pprobe" => "2", "party" => "me000000p1" }], ["message", 2, { "pprobe" => "3", "party" => "other" }]],
    [["message", 3, { "pprobe" => "4", "party" => "me000000p1" }], ["state", 3, B.merge("party" => "me000000p1")], ["message", 3, { "pprobe" => "5", "party" => "me000000p1" }]],
  ],
  # The map's gate takes messages for the player's map or the story's, and those naming the player.
  "map gate" => [
    [["seat", 0], ["state", 2, A], ["state", 3, B.merge("map" => 9)], ["message", 4, { "map_mprobe" => "1", "mmap" => "5" }]],
    [["message", 2, { "map_mprobe" => "1", "mmap" => "5" }], ["message", 3, { "map_mprobe" => "2", "mmap" => "9" }], ["message", 3, { "map_mprobe" => "3", "mmap" => "5" }]],
    [["story_map", 9], ["message", 3, { "map_mprobe" => "4", "mmap" => "9" }], ["message", 3, { "map_mprobe" => "5", "mmap" => "8" }]],
    [["message", 2, { "map_mprobe" => "6", "mmap" => "5", "mto" => "bbbbbbbb,me000000" }], ["message", 2, { "map_mprobe" => "7", "mmap" => "5", "mto" => "bbbbbbbb" }]],
    [["out", 2], ["message", 2, { "map_mprobe" => "8", "mmap" => "5" }]],
  ],
  # An invite near: the invitee joins, the leader admits them and stops inviting; the late window
  # still lets another join, after it one is turned away.
  "party near" => [
    [["seat", 0], ["state", 2, A.merge("x" => 4, "y" => 5)], ["state", 3, B.merge("x" => 5, "y" => 6)], ["state", 4, C.merge("x" => 9, "y" => 9)], ["wait", 301]],
    [["invite"]],
    [["wait", 10], ["state", 2, A.merge("x" => 4, "y" => 5, "party" => "me000000p1")]],
    [["wait", 100], ["state", 3, B.merge("x" => 5, "y" => 6, "party" => "me000000p1")]],
    [["wait", 100], ["state", 4, C.merge("x" => 9, "y" => 9, "party" => "me000000p1")]],
    [["state", 4, C.merge("x" => 9, "y" => 9, "party" => "")]],
    [["state", 2, A.merge("x" => 4, "y" => 5, "party" => "")]],
    [["remove", 3]],
    [["state", 3, B.merge("x" => 5, "y" => 6, "party" => "me000000p1")]],
    [["state", 3, B.merge("x" => 5, "y" => 6, "party" => "")]],
  ],
  # A named invite stands a minute and stops naming a player who declines; one nobody took runs out.
  "party named" => [
    [["seat", 0], ["state", 2, A.merge("map" => 9)], ["state", 3, B.merge("map" => 9)], ["wait", 301]],
    [["invite", "aaaaaaaa"]],
    [["invite", "bbbbbbbb"], ["wait", 50]],
    [["message", 2, { "party_decline" => "1" }]],
    [["message", 4, { "party_decline" => "1" }], ["message", 3, { "party_decline" => "1" }], ["wait", 3000]],
    [["wait", 548]],
    [],
    [["invite"], ["wait", 898]],
    [],
    [["invite"], ["stop_inviting"]],
  ],
  # The player joins another's party: waiting until admitted, a leader who did not make the party,
  # being removed or turned away, and a full party.
  "party joined" => [
    [["seat", 0], ["state", 2, A.merge("x" => 4, "y" => 4, "party" => "aaaaaaaap1", "invite" => 1)], ["state", 3, B.merge("party" => "aaaaaaaap1", "party_members" => "bbbbbbbb")], ["wait", 301]],
    [["join", 2]],
    [["state", 2, A.merge("x" => 4, "y" => 4, "party" => "aaaaaaaap1", "invite" => 0, "party_members" => "bbbbbbbb,me000000")]],
    [["message", 3, { "kick" => "1", "party" => "aaaaaaaap1" }]],
    [["message", 2, { "kick" => "full", "party" => "aaaaaaaap1" }]],
    [["state", 2, A.merge("x" => 4, "y" => 4, "party" => "aaaaaaaap1", "invite" => 1, "party_members" => "bbbbbbbb")], ["join", 2]],
    [["message", 2, { "kick" => "late", "party" => "aaaaaaaap1" }]],
    [["state", 4, C.merge("party" => "aaaaaaaap1")], ["state", 5, D.merge("party" => "aaaaaaaap1")], ["join", 2]],
    [["state", 2, A.merge("x" => 4, "y" => 4, "party" => "aaaaaaaap1", "invite" => 1, "party_members" => "bbbbbbbb,me000000")], ["join", 2], ["decline", 2]],
  ],
  # A party holds MAX_PLAYERS: one more is turned away, and a full party cannot be joined.
  "party full" => [
    [["seat", 0], ["state", 2, A.merge("x" => 4, "y" => 4)], ["state", 3, B.merge("x" => 4, "y" => 5)], ["state", 4, C.merge("x" => 5, "y" => 5)], ["state", 5, D.merge("x" => 5, "y" => 4)], ["wait", 301]],
    [["invite"]],
    [["state", 2, A.merge("x" => 4, "y" => 4, "party" => "me000000p1")]],
    [["state", 3, B.merge("x" => 4, "y" => 5, "party" => "me000000p1")], ["state", 4, C.merge("x" => 5, "y" => 5, "party" => "me000000p1")]],
    [["state", 5, D.merge("x" => 5, "y" => 4, "party" => "me000000p1")]],
    [["leave"], ["state", 6, E.merge("x" => 3, "y" => 3, "party" => "eeeeeeeep1", "invite" => 1)], ["state", 2, A.merge("x" => 4, "y" => 4, "party" => "eeeeeeeep1")], ["state", 3, B.merge("x" => 4, "y" => 5, "party" => "eeeeeeeep1")], ["state", 4, C.merge("x" => 5, "y" => 5, "party" => "eeeeeeeep1")]],
    [["join", 6]],
  ],
  # The maker gone, the lowest id leads; a member leaving the world ends a party nobody else is in.
  "party leader" => [
    [["seat", 0], ["state", 2, A.merge("x" => 4, "y" => 4, "party" => "zzzzzzzzp9", "party_members" => "aaaaaaaa,bbbbbbbb,me000000")], ["state", 3, B.merge("x" => 4, "y" => 4, "party" => "zzzzzzzzp9")], ["state", 4, player("zzzzzzzz", "Zed", "party" => "zzzzzzzzp9", "party_members" => "aaaaaaaa,bbbbbbbb,me000000")], ["wait", 301]],
    [["join", 4]],
    [["out", 4], ["wait", 899]],
    [["state", 2, A.merge("x" => 4, "y" => 4, "party" => "zzzzzzzzp9", "party_members" => "bbbbbbbb,me000000")]],
    [["leave"]],
    [["invite"], ["state", 2, A.merge("x" => 4, "y" => 4, "party" => "me000000p1")]],
    [["out", 2], ["wait", 899]],
  ],
}

cases = {
  "routes" => MGQ_MpOverworldSync.instance_variable_get(:@routes).keys.map do |field|
    gate = MGQ_MpCoop.instance_variable_get(:@routes).key?(field) ? "party" : (field.start_with?(MGQ_MpCoop::MAP_PREFIX) && MGQ_MpCoop.instance_variable_get(:@map_routes).key?(field[MGQ_MpCoop::MAP_PREFIX.size..-1]) ? "map" : nil)
    [field, gate]
  end,
  "scenarios" => SCENARIOS.map { |name, steps| { "name" => name, "steps" => play(steps) } },
}
File.write(File.join(__dir__, "cases.json"), JSON.pretty_generate(cases) + "\n")
puts "wrote #{cases['scenarios'].size} scenarios"
