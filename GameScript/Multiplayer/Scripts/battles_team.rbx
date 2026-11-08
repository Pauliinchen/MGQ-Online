#----------------------------------------------------------------
#  battles_team.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Built the other side's characters through the battler factory
#      Paulinchen  2026-10-30: Left the sides' answers of the duel's mode to the battle modes' defaults
#                            - Kept who commands the characters of who left in the DLL
#      Paulinchen  2026-10-23: Named the player by their seat in the battle
#      Paulinchen  2026-10-12: Took only pairs of seats as who commands the characters of who left
#                            - Left out the players of a side that do not read
#      Paulinchen  2026-10-07: Named players and characters through battles_sync.rbx
#                            - Logged the sides, the rebuilt opponents and who takes over
#      Paulinchen  2026-10-04: Renamed from mp_battles_team.rbx
#      Paulinchen  2026-10-03: Registered the team duel's Mode
#                            - Read the sides' players as MGQ_MpBattlesCoop::Player records
#                            - Sent messages, showed notices and read the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Took the Frontline's size from coop_squad.rbx
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Team duels: a duel a party's leader takes part in is fought by both sides' parties. Each side is
# a party, or a single player, whose players bring their share of the Frontline as in a co-op battle
# (coop_squad.rbx); a single player brings their whole Frontline. The challenger hosts, through
# battles_sync.rbx: every game has its own side as its party and the other side as its troop.
# A player who leaves the duel leaves their characters behind, which the first player of their side
# still in it commands from then on.
#
# battles_duel.rbx gathers the players on the map; this script holds the sides once the duel
# starts. It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesTeam
  # The players of this game's side.
  @own = []

  # The players of the other side.
  @other = []

  # Whether this game's side is the host's.
  @same_side = false

  # The seat of who commands the characters of each player who left, nil when their side is gone,
  # as the DLL keeps them (MGQOnline.Game's TeamSides); read every frame by commands?.
  @heirs = {}

  # The other side's rebuilt characters by their owner's seat and place.
  @opponents = {}

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "team duel"

  # The DLL's topic of the duel's sides (MGQOnline.Game's TeamSides, behind LiveTopics).
  SIDES_TOPIC = "live.team"

  # Reports whether this game's side is the host's.
  #
  # @return [Boolean] Whether it is.
  def self.same_side?
    @same_side
  end

  # The players of this game's side, see MGQ_MpBattlesCoop.arrange.
  #
  # @return [Array<MGQ_MpBattlesCoop::Player>] The players.
  def self.own
    @own
  end

  # The players of the other side, see MGQ_MpBattlesCoop.arrange.
  #
  # @return [Array<MGQ_MpBattlesCoop::Player>] The players.
  def self.other
    @other
  end

  # Keeps the sides of the duel about to start.
  #
  # @param own [Array<MGQ_MpBattlesCoop::Player, Array>] The players of this game's side as
  #   MGQ_MpBattlesCoop.arrange gives them, or their fields.
  # @param other [Array<MGQ_MpBattlesCoop::Player, Array>] The players of the other side.
  # @param same_side [Boolean] Whether this game's side is the host's.
  def self.prepare(own, other, same_side)
    @own = MGQ_MpBattlesCoop::Player.read_all(own)
    @other = MGQ_MpBattlesCoop::Player.read_all(other)
    @same_side = same_side
    sides("prepare", "own" => @own.map(&:seat), "other" => @other.map(&:seat), "same_side" => same_side ? true : false)
    @opponents = {}
    log("sides, the player's #{same_side ? 'hosting' : 'guest'} side: #{side_text(@own)}; the other side: #{side_text(@other)}")
  end

  # Describes a side's players with their share of the Frontline, for the log.
  #
  # @param side [Array<MGQ_MpBattlesCoop::Player>] The side's players.
  # @return [String] Each player's name, seat and characters.
  def self.side_text(side)
    side.map { |player| MGQ_MpBattlesCoop.player_text(player) }.join(" | ")
  rescue
    "#{side.size} players"
  end

  # Logs the line a block makes, which never raises: a line that cannot be made is left out.
  #
  # @yieldreturn [String] The line.
  def self.say
    log(yield)
  rescue
  end

  # Describes who commands the characters of the players who left, for the log.
  #
  # @return [String] Each player who left and who took their characters over.
  def self.heirs_text
    @heirs.map { |seat, heir| "#{MGQ_MpBattlesSync.who(seat)} by #{heir ? MGQ_MpBattlesSync.who(heir) : 'nobody, their side is gone'}" }.join(", ")
  end

  # Asks the DLL's sides of the duel a step, and keeps who commands the characters of who left.
  #
  # @param op [String] The step, such as "settle".
  # @param fields [Hash] What it needs.
  # @return [Hash] What it answers, empty while the DLL does not answer.
  def self.sides(op, fields = {})
    reply = MGQ_Multiplayer::Bridge.call(SIDES_TOPIC, { "op" => op }.merge(fields))
    return {} unless reply.is_a?(Hash)

    @heirs = Hash[Array(reply["heirs"]).map { |seat, heir| [seat, heir] }]
    reply
  end

  # Names who leads the other side, the opponent Discord shows.
  #
  # @return [String] The name of the other side's first player.
  def self.opponent_name
    @other.first ? @other.first.name.to_s : ""
  end

  # Rebuilds the other side's characters on its players' Frontline, in its order, each owned by
  # its player. Called by MGQ_MpBattlesPvp::Battle.start for the troop.
  #
  # @return [Array<MGQ_MpBattlesPvp::Opponent>] The characters.
  def self.opponents
    opponents = @other.map do |player|
      members = MGQ_MpActors::Builds.parse(player.builds.to_s, MGQ_MpCoopSquad::FRONTLINE)
      player.lines[0].map { |place| opponent(player.seat, player.name.to_s, members[place], place) }
    end.flatten.compact
    say { "the other side fights with #{MGQ_MpBattlesCoop.members_text(opponents)}" }
    opponents
  end

  # Rebuilds one of the other side's characters, once per duel.
  #
  # @param seat [Integer] Its owner's world seat.
  # @param name [String] Its owner's name.
  # @param member [MGQ_MpActors::Builds::Member, nil] Its build.
  # @param place [Integer] Its place among its owner's characters.
  # @return [MGQ_MpBattlesPvp::Opponent, nil] The character, nil when it cannot be rebuilt.
  def self.opponent(seat, name, member, place)
    return nil unless member

    return @opponents[[seat, place]] if @opponents[[seat, place]]

    opponent = MGQ_MpBattlers.opponent(member, name)
    return nil unless opponent

    opponent.mp_seat = seat
    opponent.mp_place = place
    say { "rebuilt #{MGQ_MpBattlesSync.named(opponent)} of seat #{seat}, place #{place}, Lv#{member.base_level}" }
    @opponents[[seat, place]] = opponent
  end

  # Makes this game's side the party: the player's own characters and the others of their side.
  # Called as the duel's battle starts.
  #
  # @param scene [Scene_Battle] The battle.
  def self.form(scene)
    MGQ_MpBattlesCoop.form(scene, @own)
  rescue => e
    log("forming the side failed: #{e.class}: #{e.message}")
  end

  # Finds who commands the characters of a player who left.
  #
  # @param seat [Integer] The world seat of the player who left.
  # @return [Integer, nil] The seat of the player who took them over, nil for none.
  def self.heir_of(seat)
    @heirs[seat]
  end

  # Reports whether this game's player commands a character of their side: one of a player who
  # left, which they took over.
  #
  # @param ally [Game_MpAlly] The character.
  # @return [Boolean] Whether they do.
  def self.commands?(ally)
    MGQ_MpBattlesSync.team? && heir_of(ally.mp_seat) == MGQ_MpBattlesSync.own_seat
  end

  # Reports whether every player of the other side left, the host and the guests who did not leave,
  # as the DLL's sides tell. Asked by the host.
  #
  # @return [Boolean] Whether they did.
  def self.other_side_gone?
    sides("gone", "host" => MGQ_MpBattlesSync.own_seat)["gone"] ? true : false
  end

  # As host, hands the characters of the players who left to the first player of their side
  # still in the duel, as the DLL's sides decide, told to the guests between two of the host's
  # sends. Called when a command phase starts.
  def self.settle
    post = sides("settle", "host" => MGQ_MpBattlesSync.own_seat)["post"]
    return unless post

    MGQ_MpBattlesSync::Recorder.flush if MGQ_MpBattlesSync::Recorder.active?
    MGQ_MpBattlesSync::Channel.post("team_heirs", post)
    say { "characters taken over: #{heirs_text}" }
  rescue => e
    log("settling the sides failed: #{e.class}: #{e.message}")
  end

  # As guest, takes who commands the characters of the players who left, the pairs of seats the
  # DLL's sides read of the host's message.
  #
  # @param body [String] Pairs of seats, see settle.
  def self.take_heirs(body)
    broken = sides("take", "body" => body.to_s)["broken"]
    log_once(:heirs, "dropped who commands the characters of who left where the host sent no pair of seats") if broken
    say { "took who commands the characters of who left: #{heirs_text}" }
  rescue => e
    log("taking who commands failed: #{e.class}: #{e.message}")
  end
end

# What a team duel does differently in a live battle: each game's side is its party, the players
# of the host's side command the host's party, and who left hands their characters to their side.
# Which guests stand on the host's side, the players of both sides, who took over whose characters,
# whether the other side is gone and the heirs' message in the stream are MGQ_MpBattles::Mode's,
# which the DLL answers from the sides prepare hands it.
module MGQ_MpBattlesTeam::Mode
  extend MGQ_MpBattles::Mode

  # (see MGQ_MpBattles::Mode#same_side?)
  def self.same_side?
    MGQ_MpBattlesTeam.same_side?
  end

  # (see MGQ_MpBattles::Mode#host_start)
  def self.host_start(scene)
    MGQ_MpBattlesTeam.form(scene)
    nil
  end

  # (see MGQ_MpBattles::Mode#guest_start)
  def self.guest_start(scene)
    MGQ_MpBattlesTeam.form(scene)
    nil
  end

  # (see MGQ_MpBattles::Mode#settle)
  def self.settle(_scene)
    MGQ_MpBattlesTeam.settle
  end

  # (see MGQ_MpBattles::Mode#take)
  def self.take(_kind, _scene, body)
    MGQ_MpBattlesTeam.take_heirs(body)
  end
end

# What a team duel does differently in a live battle, through battles.rbx.

begin
  MGQ_MpBattles.mode(:team, MGQ_MpBattlesTeam::Mode)
rescue => e
  MGQ_MpBattlesTeam.log("mode FAILED: #{e.class}: #{e.message}")
end
