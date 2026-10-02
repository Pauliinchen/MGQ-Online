#----------------------------------------------------------------
#  mp_battles_team.rbx
#
#  Changelog:
#      Paulinchen  2026-10-02: Took the Frontline's size from mp_coop_squad.rbx
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Team duels: a duel a party's leader takes part in is fought by both sides' parties. Each side is
# a party, or a single player, whose players bring their share of the Frontline as in a co-op battle
# (mp_coop_squad.rbx); a single player brings their whole Frontline. The challenger hosts, through
# mp_battles_sync.rbx: every game has its own side as its party and the other side as its troop.
# A player who leaves the duel leaves their characters behind, which the first player of their side
# still in it commands from then on.
#
# mp_battles_duel.rbx gathers the players on the map; this script holds the sides once the duel
# starts. It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesTeam
  @own = []
  @other = []
  @same_side = false
  @heirs = {}
  @opponents = {}

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("team duel: #{message}")
  rescue
  end

  # Reports whether this game's side is the host's.
  #
  # @return [Boolean] Whether it is.
  def self.same_side?
    @same_side
  end

  # The players of this game's side, see MGQ_MpBattlesCoop.arrange.
  #
  # @return [Array<Array>] The players.
  def self.own
    @own
  end

  # The players of the other side, see MGQ_MpBattlesCoop.arrange.
  #
  # @return [Array<Array>] The players.
  def self.other
    @other
  end

  # Keeps the sides of the duel about to start.
  #
  # @param own [Array<Array>] The players of this game's side, see MGQ_MpBattlesCoop.arrange.
  # @param other [Array<Array>] The players of the other side.
  # @param same_side [Boolean] Whether this game's side is the host's.
  def self.prepare(own, other, same_side)
    @own = own
    @other = other
    @same_side = same_side
    @heirs = {}
    @opponents = {}
  end

  # Names who leads the other side, whose team Discord says the player fights.
  #
  # @return [String] The name of the other side's first player.
  def self.opponent_name
    @other.first ? @other.first[1].to_s : ""
  end

  # Rebuilds the other side's characters on its players' Frontline, in its order, each owned by
  # its player. Called by MGQ_MpBattlesPvp::Battle.start for the troop.
  #
  # @return [Array<MGQ_MpBattlesPvp::Opponent>] The characters.
  def self.opponents
    @other.map do |player|
      seat, name, builds = player
      members = MGQ_MpActors::Builds.parse(builds.to_s, MGQ_MpCoopSquad::FRONTLINE)
      MGQ_MpBattlesCoop.lines_of(player)[0].map { |place| opponent(seat, name.to_s, members[place], place) }
    end.flatten.compact
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

    @opponents[[seat, place]] ||= MGQ_MpBattlesPvp::Opponent.new(member, name).tap do |opponent|
      opponent.mp_seat = seat
      opponent.mp_place = place
    end
  rescue => e
    log("could not rebuild actor #{member.actor_id} of #{name}: #{e.class}: #{e.message}")
    nil
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

  # Reports whether a guest stands on the host's side. Asked by the host.
  #
  # @param seat [Integer] The guest's world seat.
  # @return [Boolean] Whether they do.
  def self.same_side_as_host?(seat)
    @own.any? { |player_seat, *| player_seat == seat }
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
    MGQ_MpBattlesSync.team? && heir_of(ally.mp_seat) == MGQ_MpBattlesCoop.own_seat
  end

  # Lists the players of a side still in the duel: the host and the guests who did not leave.
  #
  # @param side [Array<Array>] The side's players.
  # @return [Array<Integer>] Their seats, in the side's order.
  def self.staying(side)
    host = MGQ_MpBattlesCoop.own_seat
    side.map { |seat, *| seat }.select { |seat| seat == host || MGQ_MpBattlesSync.guests_in.include?(seat) }
  end

  # Reports whether every player of the other side left. Asked by the host.
  #
  # @return [Boolean] Whether they did.
  def self.other_side_gone?
    staying(@other).empty?
  end

  # As host, hands the characters of the players who left to the first player of their side
  # still in the duel, told to the guests between two of the host's sends. Called when a command
  # phase starts.
  def self.settle
    changed = false
    [@own, @other].each do |side|
      heir = staying(side).first
      side.each do |seat, *|
        next if staying(side).include?(seat) || @heirs[seat] == heir

        @heirs[seat] = heir
        changed = true
      end
    end
    return unless changed

    MGQ_MpBattlesSync::Recorder.flush if MGQ_MpBattlesSync::Recorder.active?
    MGQ_MpBattlesSync::Channel.post("team_heirs", MGQ_MpBattlesSync::Wire.line([@heirs.reject { |_, heir| heir.nil? }.to_a.flatten]))
    log("characters taken over: #{@heirs.inspect}")
  rescue => e
    log("settling the sides failed: #{e.class}: #{e.message}")
  end

  # As guest, takes who commands the characters of the players who left.
  #
  # @param body [String] Pairs of seats, see settle.
  def self.take_heirs(body)
    pairs = Array(MGQ_MpBattlesSync::Wire.parse(body.to_s)[0])
    @heirs = Hash[pairs.each_slice(2).select { |pair| pair.size == 2 }]
  rescue => e
    log("taking who commands failed: #{e.class}: #{e.message}")
  end
end
