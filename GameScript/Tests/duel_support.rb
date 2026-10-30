#----------------------------------------------------------------
#  duel_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# What the duel's tests share: stand-ins for the PvP battle, the live battle, the co-op battles and
# the team battles a duel starts, and FakeDuels, the DLL's duel topics on the fake bridge, which
# records what the script hands over and answers a view the test sets. The handshake itself is
# MGQOnline.Game.Tests'. Loads battles_duel.rbx.

require_relative "world_support"

# The mod, available and up to date.
module MGQ_Multiplayer
  # Answers that the mod is installed.
  def self.available?; true; end
  # Answers that the mod is up to date.
  def self.outdated?; false; end
end

# Stands in for the battles, with none running.
module MGQ_MpBattles
  # Answers that no battle runs.
  def self.running?; false; end
end

# Stands in for the builds of characters: a member is a line that starts with "member=".
module MGQ_MpActors
  # Reads builds by the stand-in rule.
  module Builds
    # Reads the members of a text.
    def self.parse(text, limit); text.to_s.split("\n").select { |line| line.start_with?("member=") }.first(limit); end
  end
end

# Stands in for the PvP battles.
module MGQ_MpBattlesPvp
  # The player's team, the game's fingerprint in $game_print and the Backline in $backline_wanted.
  module Team
    # Answers the game's fingerprint.
    def self.game; $game_print; end
    # Writes the player's team, noting its rule.
    def self.build; @sent = $backline_wanted; "backline=#{$backline_wanted ? 1 : 0}\nmember=me"; end
    # Answers whether the team sent last carried the Backline.
    def self.sent_backline?; @sent ? true : false; end
    # Reads a team's members.
    def self.parse(text); MGQ_MpActors::Builds.parse(text, 20); end
  end
  # The player's rule of the Backline, kept in $backline_wanted.
  module Backline
    # Answers the rule.
    def self.wanted?; $backline_wanted; end
  end
  # The PvP battle, noting each start in $started; $start_fails makes it fail.
  module Battle
    # Answers whether a battle runs: from its start until the next look, unless it failed.
    def self.running?; running = @started; @started = false; running; end
    # Notes a start.
    def self.start(name, members, backline = false)
      @started = !$start_fails
      $started << [name, members, backline, block_given? ? yield : nil]
    end
  end
end

# Stands in for the live battle, its role in $role and the battles joined in $joined.
module MGQ_MpBattlesSync
  # Writes values as tab-separated text, nested ones as hex of Marshal.
  module Wire
    # Writes values.
    def self.line(values); values.all? { |v| v.is_a?(String) || v.is_a?(Numeric) } ? values.join("\t") : "M:" + Marshal.dump(values).unpack1("H*"); end
    # Reads values.
    def self.parse(text); text.start_with?("M:") ? Marshal.load([text[2..-1]].pack("H*")) : text.split("\t"); end
  end
  # Answers the live battle's role.
  def self.role; $role; end
  # Notes a battle joined.
  def self.join_world(*args); $joined << args; end
end

# The player, in seat 0.
module MGQ_MpOverworldSync::Me
  # Answers the player's seat.
  def self.seat; 0; end
end

# Stands in for the co-op battles.
module MGQ_MpBattlesCoop
  # The most characters a Frontline brings.
  MOST_CHARACTERS = 14
  # A player of a battle as the co-op battles record them.
  Player = Struct.new(:seat, :name, :builds, :vitals, :max, :order, :front, :bench) do
    # Reads a player from their fields.
    def self.read(fields); fields.is_a?(self) ? fields : new(*fields); end
    # Reads players from their fields.
    def self.read_all(list); Array(list).map { |fields| read(fields) }; end
  end
  # Answers the player's Frontline and party_member_max.
  def self.team_build; ["member=a\nmember=b", 8]; end
end

# Stands in for the team battles, noting the sides prepared in $prepared.
module MGQ_MpBattlesTeam
  # Notes the sides.
  def self.prepare(*args); $prepared = args; end
  # Names the other side.
  def self.opponent_name; "Side leader"; end
  # Lists the opponents.
  def self.opponents; [:opponents]; end
end

# The DLL's duel topics on the fake bridge: every request recorded, each action answered with
# @view, the begin answered with @begin.
class FakeDuels
  # The topics that answer the view.
  VIEW_TOPICS = %w[duel.take duel.challenge duel.stop duel.accept duel.decline duel.team duel.withdraw duel.view]

  # @return [Array<Array>] Each request as [topic, request].
  attr_reader :calls

  # @return [Array<Hash>] Each player's frame staged.
  attr_reader :frames

  # @return [Hash] The view the actions answer.
  attr_accessor :view

  # @return [Boolean] Whether the duel waiting to start may begin.
  attr_accessor :begin

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @calls = []
    @frames = []
    @view = MGQ_MpBattlesDuel::NO_VIEW
    @begin = true
    VIEW_TOPICS.each { |topic| fake.answer(topic) { |request| @calls << [topic, request]; @view } }
    fake.answer("duel.frame") { |request| @frames << request; nil }
    fake.answer("duel.begin") { |request| @calls << ["duel.begin", request]; @begin }
  end

  # Lists the requests of a topic.
  #
  # @param topic [String] The topic.
  # @return [Array] The requests.
  def requests(topic)
    @calls.select { |name, _| name == topic }.map(&:last)
  end
end

$game_print = "game-1"
$started = []
$joined = []
$backline_wanted = false

load_script "battles_duel"

$duels = FakeDuels.new($world_bridge)
MGQ_Multiplayer::Bridge.open($world_bridge)

# Plays the DLL posting a duel event, taken at the frame's drain.
#
# @param topic [String] The event's topic, such as "duel.start".
# @param payload [Object] Its payload.
def duel_event(topic, payload)
  $world_bridge.post(topic, payload)
  MGQ_Multiplayer::Bridge.frame
end
