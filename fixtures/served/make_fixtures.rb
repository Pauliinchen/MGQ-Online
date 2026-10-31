#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Writes the golden cases of a served battle's front next to this file, front.json, from
# battles_served.rbx as its starter stood in for the battle server in the world's room before that
# moved to the DLL (commit 8d4f6024, which this generator reads through git, so it runs again on
# later commits): the requests to join it the starter passes on to the server (with the states and
# fields the script hands over and the message that goes out), a player who left the world, the
# server's messages for the world's room (passed on or dropped), the server's state the starter
# tells as its own, and which co-op messages the starter passes on. MGQParadox.Multiplayer.Tests
# replays them against BattleSession.
#
#   ruby fixtures/served/make_fixtures.rb

require "json"
require "tempfile"
require_relative "../../GameScript/Tests/support"

# The commit whose battles_served.rbx kept the front.
SOURCE_COMMIT = "8d4f6024"

# The battle's id.
BATTLE = "bf3q2k9x"

# The log stays quiet; the cases record what the rules did, not their lines.
module MGQ_Multiplayer; module Log; def self.write(_line); end; end; end

# The game's classes the battle line codec names.
class Game_Battler; end
# An action.
class Game_Action; end
# An action's result.
class Game_ActionResult; end
# A color.
class Color; end
# A tone.
class Tone; end
# An equipped item.
class Game_BaseItem; end
# The database's entries.
module RPG; class BaseItem; end; class Skill < BaseItem; end; class Item < BaseItem; end; class State < BaseItem; end; class Weapon < BaseItem; end; class Armor < BaseItem; end; end

# Stands in for the live battle: the battle's id and the players' names.
module MGQ_MpBattlesSync
  # The battle's id.
  def self.battle_id; BATTLE; end
  # Names a seat.
  def self.who(seat); "seat #{seat}"; end
  # Keeps what the codec logs.
  def self.log_once(_key, _text); end
end
# Stands in for the world's sync: the player's seat 0, the other players by seat, and what goes
# to the world's room.
module MGQ_MpOverworldSync
  # A player.
  Peer = Struct.new(:seat, :state)
  # The player's own state.
  module Me
    # Writes a message's fields as the room sends them.
    def self.encode(state); state.map { |key, value| "#{key}=#{value.to_s.gsub(/[\r\n]/, ' ')}" }.join("\n") + "\n\n"; end
    # The player's seat.
    def self.seat; 0; end
  end
  # The other players.
  module Peers
    # Finds a player by seat.
    def self.at(seat); $peers[seat]; end
  end
  # The world's room.
  module Link
    # Keeps a message to the room.
    def self.send_to(seat, text); $world << [seat, text]; true; end
  end
  # Names a player.
  def self.who(peer); "seat #{peer.seat}"; end
  # Takes a block run as a player leaves.
  def self.on_leave(&_block); end
end
# Stands in for the co-op battles' prefix of a map's messages.
module MGQ_MpCoop; MAP_PREFIX = "map_"; end
# Stands in for the DLL: a message over the battle channel is kept.
module MGQ_Multiplayer
  # The DLL's link.
  module Link
    # Answers a function of the DLL.
    def self.function(name)
      lambda do |*args|
        $channel << [args[0], args[1].to_s.chomp("\0")] if name == "mp_battle_send"
        1
      end
    end
    # Reads key=value lines, an empty line and the payload.
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| key, value = line.split("=", 2); state[key] = value if value }
      state
    end
  end
end

# Loads a script of the source commit.
#
# @param name [String] The script's name without its extension.
def load_old(name)
  source = `git -C "#{File.expand_path('../..', __dir__)}" show #{SOURCE_COMMIT}:GameScript/Multiplayer/Scripts/#{name}.rbx`
  raise "git could not read #{name}.rbx of #{SOURCE_COMMIT}" if source.empty?

  script = Tempfile.new([name, ".rbx"])
  script.write(source)
  script.close
  load File.join(SCRIPTS_DIR, "core_log.rbx") unless defined?(MGQ_MpLog)
  load script.path
end

load_old("battles_sync_wire")
load_old("battles_served")
SERVED = MGQ_MpBattlesServed
WIRE = MGQ_MpBattlesSync::Wire

# Makes the player the starter of an open served battle.
def as_front
  SERVED.instance_variable_set(:@starter, true)
  SERVED.instance_variable_set(:@channel, :open)
  SERVED.instance_variable_set(:@front_state, nil)
end

$peers = {
  2 => MGQ_MpOverworldSync::Peer.new(2, { "id" => "id-friend", "name" => "Friend", "map" => "5" }),
  4 => MGQ_MpOverworldSync::Peer.new(4, { "id" => "id-joiner", "name" => "Joiner\tTab", "x" => "3" }),
  7 => MGQ_MpOverworldSync::Peer.new(7, { "name" => "No Id" }),
}

# The requests to join: the asking player's seat and the request, as MGQ_MpBattlesCoop.take hands them.
requests = [
  [4, { "coop" => "hot", "bid" => BATTLE, "troop" => "5", "enemies" => "31:320:300:0", "seats" => "2", "map" => "5" }],
  [4, { "coop" => "pick", "bid" => BATTLE, "seats" => "2,4,9,2", :relay => true, "note" => "line\nbreak" }],
  [7, { "coop" => "off", "bid" => BATTLE }],
]
forward = requests.map do |seat, message|
  as_front
  $channel = []
  seats = [seat] + message["seats"].to_s.split(",").map(&:to_i)
  states = seats.uniq.map { |each| $peers[each] }.compact.map do |known|
    [known.seat, SERVED.pairs(known.state.select { |key, _| SERVED::FRONT_STATE_KEYS.include?(key) })]
  end
  fields = SERVED.pairs(message.reject { |key, _| key.is_a?(Symbol) })
  SERVED.forward($peers[seat], message)
  { "seat" => seat, "states" => states, "fields" => fields, "sent" => $channel }
end

as_front
$channel = []
SERVED.peer_left($peers[4])
left = { "seat" => 4, "sent" => $channel }

# The server's messages for the world's room, as the body of a front_out.
outs = [
  WIRE.line([4, "map_coop=hot_ok\nbid=#{BATTLE}\nmmap=5\n\n"]),
  WIRE.line([-1, "coop=invite\nbid=#{BATTLE}\n\n"]),
  WIRE.line([4, "chat=hello\n\n"]),
  WIRE.line(["4", "coop=invite\n\n"]),
  "not\ta [line",
]
front_out = outs.map do |body|
  as_front
  $world = []
  SERVED.take_front_out(body)
  { "body" => body, "world" => $world }
end

as_front
fields_before = SERVED.front_fields(%w(rb rbh rbn))
states = [WIRE.line([[["rbn", "2"], ["other", "x"]]]), WIRE.line([[["rbn", "3"]]]), WIRE.line([[]])]
front_state = states.map do |body|
  SERVED.take_front_state(body)
  { "body" => body, "fields" => SERVED.front_fields(%w(rb rbh rbn)) }
end

fronts = [
  [{ "coop" => "hot", "bid" => BATTLE }, true, :open],
  [{ "coop" => "pick", "bid" => BATTLE }, true, :open],
  [{ "coop" => "off", "bid" => BATTLE }, true, :open],
  [{ "coop" => "decline", "bid" => BATTLE }, true, :open],
  [{ "coop" => "hot", "bid" => "other" }, true, :open],
  [{ "coop" => "hot", "bid" => BATTLE }, true, :opening],
  [{ "coop" => "hot", "bid" => BATTLE }, false, :open],
].map do |message, starter, channel|
  SERVED.instance_variable_set(:@starter, starter)
  SERVED.instance_variable_set(:@channel, channel)
  { "message" => message, "starter" => starter, "open" => channel == :open, "fronts" => SERVED.fronts?(message) }
end

File.write(File.join(__dir__, "front.json"), JSON.pretty_generate("source" => SOURCE_COMMIT, "battle" => BATTLE, "forward" => forward, "left" => left,
                                                                    "front_out" => front_out, "fields_before" => fields_before,
                                                                    "front_state" => front_state, "fronts" => fronts) + "\n")
puts "wrote front.json"
