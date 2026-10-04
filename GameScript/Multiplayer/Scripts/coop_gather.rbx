#----------------------------------------------------------------
#  coop_gather.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# Gathering a party for the leader's story scenes. A story scene the leader starts waits until every
# member stands near them, thirty seconds at most: members get five seconds to finish what they do,
# then are brought over once free, and stand still while the scene plays. It starts without those
# who did not come, who play on. A member may also teleport to the leader on their own. The story
# scenes themselves are sorted and told by coop_events.rbx, which hands this script its messages.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopGather
  # Frames a member gets to finish what they do before a story scene brings them to the leader,
  # five seconds at 60 frames per second.
  GATHER_FRAMES = 300

  # Tiles a member may stand away from the leader, on the leader's map, to count as gathered.
  GATHER_TILES = 3

  # Frames between two calls of the members while the leader's story scene waits, three seconds.
  CALL_FRAMES = 180

  # Frames the leader's story scene waits for the party at most before it starts without the
  # members who did not come, thirty seconds.
  HOLD_FRAMES = 1800

  # Frames without a call after which a member's call lapses, two calls missed: the leader's story
  # started without them, or the leader left.
  CALL_LAPSE_FRAMES = CALL_FRAMES * 2

  @hold = nil
  @gather = nil

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Game_Player.method_defined?(:mgq_mp_coop_gather_encounter)
  end

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "co-op gather"

  # Finds the leader of the player's party, through coop_events.rbx.
  #
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil outside a party.
  def self.leader
    MGQ_MpCoopEvents.leader
  end

  # Reports whether the player leads a party with other members in it.
  #
  # @return [Boolean] Whether they do.
  def self.leading?
    MGQ_MpCoopEvents.leading?
  end

  # Sends the party a message about gathering.
  #
  # @param seat [Integer] A member's seat, -1 for everyone, who ignore it outside the party.
  # @param kind [String] What it is about.
  # @param fields [Hash] Its other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, fields = {})
    MGQ_MpCoopEvents.tell(seat, kind, fields)
  end

  # Takes a message about gathering, handed over by coop_events.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    return answer_where(peer) if message["pevent"] == "where"
    return unless leader.equal?(peer)

    place = [message["map"].to_i, message["x"].to_i, message["y"].to_i, message["d"].to_i]
    case message["pevent"]
    when "gather" then called(peer, place, message["warp_ban"] == "1")
    when "come" then answered(peer, place, message["warp_ban"] == "1")
    end
  rescue => e
    log("taking #{message['pevent']} failed: #{e.class}: #{e.message}")
  end

  # As leader, holds a story scene until every member stands near: calls them now and every few
  # seconds while it waits.
  #
  # @param interpreter [Game_Interpreter] The map's interpreter, which waits at its first command.
  def self.hold(interpreter)
    @hold = { :interpreter => interpreter, :since => Graphics.frame_count, :called => Graphics.frame_count }
    gather
    MGQ_MpOverworldSync.notice("Gathering the party for the story . . .")
  end

  # Forgets the story scene the player held, as when another event starts on the map.
  def self.drop_hold
    @hold = nil
  end

  # Reports whether the leader's story scene waits for the party now.
  #
  # @return [Boolean] Whether it does.
  def self.holding_story?
    !@hold.nil?
  end

  # As leader, calls the party members to where the player stands.
  def self.gather
    tell(-1, "gather", place_fields)
  end

  # Reports whether the leader's story scene still waits for the party, calling the members again
  # every CALL_FRAMES, and starting it without those who did not come after HOLD_FRAMES. Asked
  # before each of the interpreter's commands.
  #
  # @param interpreter [Game_Interpreter] The interpreter about to run a command.
  # @return [Boolean] Whether it waits.
  def self.holding?(interpreter)
    return false unless @hold && @hold[:interpreter].equal?(interpreter)

    if !leading? || gathered?
      @hold = nil
      MGQ_MpOverworldSync.notice("The party is here.") if leading?
      return false
    end

    if Graphics.frame_count - @hold[:since] >= HOLD_FRAMES
      @hold = nil
      MGQ_MpOverworldSync.notice("The story starts without #{missing.join(', ')}.")
      return false
    end

    if Graphics.frame_count - @hold[:called] >= CALL_FRAMES
      @hold[:called] = Graphics.frame_count
      gather
    end
    true
  rescue => e
    @hold = nil
    log("holding the story failed: #{e.class}: #{e.message}")
    false
  end

  # Reports whether every party member stands near the player, on the player's map.
  #
  # @return [Boolean] Whether they do.
  def self.gathered?
    missing.empty?
  end

  # Names the party members who do not stand near the player yet.
  #
  # @return [Array<String>] Their names.
  def self.missing
    here = [$game_map.map_id, $game_player.x, $game_player.y]
    MGQ_MpCoop::Party.members.reject { |peer| near_place?(peer.state, here) }.map { |peer| peer.state["name"].to_s }
  end

  # Reports whether a player stands near a place.
  #
  # @param state [Hash] What the player last told, or the player's own "map", "x" and "y".
  # @param place [Array<Integer>] The place's map, x and y.
  # @return [Boolean] Whether they stand within GATHER_TILES of it.
  def self.near_place?(state, place)
    state["map"].to_i == place[0] && [(state["x"].to_i - place[1]).abs, (state["y"].to_i - place[2]).abs].max <= GATHER_TILES
  end

  # Takes the leader's call to their story scene: the player comes over in GATHER_FRAMES, unless
  # they stand near already.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param place [Array<Integer>] Where the leader stands: map, x, y and direction.
  # @param warp_ban [Boolean] Whether warping is banned where the leader stands.
  def self.called(peer, place, warp_ban = false)
    return @gather = nil if near_place?(own_place, place)

    unless @gather
      MGQ_MpOverworldSync.notice("#{peer.state['name']}'s story is starting. You join them in #{GATHER_FRAMES / 60} seconds.")
      @gather = { :since => Graphics.frame_count, :name => peer.state["name"].to_s }
    end
    @gather[:place] = place
    @gather[:warp_ban] = warp_ban
    @gather[:called] = Graphics.frame_count
  end

  # Writes where the player stands, as near_place? reads a player's state.
  #
  # @return [Hash] "map", "x" and "y".
  def self.own_place
    { "map" => $game_map.map_id, "x" => $game_player.x, "y" => $game_player.y }
  end

  # As member, asks the leader where they stand, to come over as soon as the player is free.
  def self.join_leader
    lead = leader
    return unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)

    name = lead.state["name"].to_s
    if near_place?(own_place, [lead.state["map"].to_i, lead.state["x"].to_i, lead.state["y"].to_i])
      return MGQ_MpOverworldSync.notice("You are with #{name} already.")
    end

    @asked = Graphics.frame_count
    tell(lead.seat, "where")
    MGQ_MpOverworldSync.notice("Teleporting to #{name} . . .")
  rescue => e
    log("asking for the leader's place failed: #{e.class}: #{e.message}")
  end

  # As leader, tells a member who asked where the player stands.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.answer_where(peer)
    tell(peer.seat, "come", place_fields) if leader == :me && MGQ_MpCoop::Party.member?(peer.state)
  end

  # Takes the leader's answer to join_leader: the player comes over at once, unless they never
  # asked or stand near already.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param place [Array<Integer>] Where the leader stands: map, x, y and direction.
  # @param warp_ban [Boolean] Whether warping is banned where the leader stands.
  def self.answered(peer, place, warp_ban)
    asked = @asked
    @asked = nil
    return unless asked && Graphics.frame_count - asked < CALL_LAPSE_FRAMES
    return if near_place?(own_place, place)

    @gather = { :since => Graphics.frame_count - GATHER_FRAMES, :name => peer.state["name"].to_s, :place => place,
                :warp_ban => warp_ban, :called => Graphics.frame_count, :asked => true }
  end

  # Reports whether the leader's story scene is about to bring the player over, which keeps random
  # encounters and co-op battles away so no battle holds the player up.
  #
  # @return [Boolean] Whether it is.
  def self.coming?
    !@gather.nil? && Graphics.frame_count - @gather[:called] < CALL_LAPSE_FRAMES
  end

  # Tells where the player comes to for the leader's story scene, once its five seconds passed.
  #
  # @return [Array<Integer>, nil] The leader's map, x, y and direction, nil while none or not yet.
  def self.come?
    gather = pending_call
    gather && Graphics.frame_count - gather[:since] >= GATHER_FRAMES ? gather[:place] : nil
  end

  # The leader's call the player has yet to answer, forgetting it once the calls stopped.
  #
  # @return [Hash, nil] The call: :since, :name, :place, :warp_ban and :called; nil for none.
  def self.pending_call
    return nil unless @gather
    return @gather if Graphics.frame_count - @gather[:called] < CALL_LAPSE_FRAMES

    MGQ_MpOverworldSync.notice(@gather[:asked] ? "You were too busy to teleport to #{@gather[:name]}." : "#{@gather[:name]}'s story started without you.")
    @gather = nil
  end

  # Tells what the line above the player's own head says about the party's story, if anything:
  # the leader's wait, or a member's time left before coming over.
  #
  # @return [String, nil] The line.
  def self.own_line
    return "Gathering the party . . ." if @hold && leading?

    gather = pending_call
    return nil unless gather

    seconds = (GATHER_FRAMES - (Graphics.frame_count - gather[:since]) + 59) / 60
    seconds > 0 ? "Joining #{gather[:name]} in #{seconds} s . . ." : "Joining #{gather[:name]} once free . . ."
  end

  # Reports whether the player, a member, has to stand still: while their leader's story scene plays
  # on the player's map. A member it started without plays on elsewhere.
  #
  # @return [Boolean] Whether they do.
  def self.blocked?
    lead = leader
    lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && lead.state["telling"] == "1" && lead.state["map"].to_i == $game_map.map_id
  end

  # Reports whether the player only waits for the party's story: as leader while it gathers, as
  # member while called, held by it or reading its pages. The chat stays open meanwhile.
  #
  # @return [Boolean] Whether they do.
  def self.waiting?
    (holding_story? && leading?) || coming? || blocked? || MGQ_MpCoopEvents.mirroring?
  rescue
    false
  end

  # Writes where the player stands, and whether warping is banned there.
  #
  # @return [Hash] "map", "x", "y", "d" and "warp_ban".
  def self.place_fields
    { "map" => $game_map.map_id, "x" => $game_player.x, "y" => $game_player.y, "d" => $game_player.direction,
      "warp_ban" => warp_ban? ? 1 : 0 }
  end

  # Reports whether warping, such as with a Harpy Feather, is banned where the player stands.
  #
  # @return [Boolean] Whether it is.
  def self.warp_ban?
    defined?(MGQ_MpCoopStory) && $game_switches[MGQ_MpCoopStory::WARP_BAN] ? true : false
  end

  # Takes over the warp ban of the place the leader's story scene brought the player to.
  #
  # The game sets the ban in the events a player walks through to enter or leave a cave, which a
  # player brought over never touches, so the ban of the place they left would stay.
  #
  # @param banned [Boolean] Whether warping is banned where the leader stands.
  def self.take_warp_ban(banned)
    $game_switches[MGQ_MpCoopStory::WARP_BAN] = banned if defined?(MGQ_MpCoopStory)
  end

  # Moves the player to the leader once a story scene's five seconds passed, once the player is
  # free: on the map, with no event, message, transfer or battle of their own in the way. Called
  # after the map's update.
  def self.update
    place = come?
    return unless place && MGQ_MpOverworldSync.map_free?

    map_id, x, y, direction = place
    warp_ban = @gather[:warp_ban]
    @gather = nil
    return unless MGQ_MpCoop.in_party?

    if map_id == $game_map.map_id
      $game_player.moveto(x, y)
      $game_player.set_direction(direction) if direction > 0
    else
      $game_player.reserve_transfer(map_id, x, y, direction > 0 ? direction : 2)
    end
    take_warp_ban(warp_ban)
  rescue => e
    log("coming to the leader failed: #{e.class}: #{e.message}")
  end
end

# The line above the player's own head while the leader's story calls them, through ui_actions.rbx.

begin
  MGQ_MpActions.own_line_from { MGQ_MpCoopGather.own_line }
rescue => e
  MGQ_MpCoopGather.log("actions FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # Before an event command runs, its interpreter waits while the leader's story scene waits for
  # the party.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "coop_gather") do
    begin
      Fiber.yield while MGQ_MpCoopGather.holding?(self)
    rescue FiberError
      # An interpreter run outside a fiber cannot wait, so its command runs at once.
    end
  end

  # After the map's update, the player is brought to the leader's story scene when they are free.
  MGQ_MpHooks.after(Game_Map, :update, "coop_gather") { MGQ_MpCoopGather.update }

  # The player stands still and opens no menu while their leader's story scene plays.
  MGQ_MpHooks.hold_player("coop_gather") { MGQ_MpCoopGather.blocked? }
rescue => e
  MGQ_MpCoopGather.log("hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpCoopGather.hookable?
  begin
    class Game_Player
      alias mgq_mp_coop_gather_encounter encounter

      # Starts a random encounter when its steps ran out, but not while the leader's story scene is
      # about to bring the player over.
      #
      # @return [Boolean] Whether a battle starts.
      def encounter
        return mgq_mp_coop_gather_encounter unless (MGQ_MpCoopGather.coming? rescue false)

        # Steps that ran out while called would start a battle the moment the player arrives.
        make_encounter_count if @encounter_count <= 0
        false
      end
    end
  rescue => e
    MGQ_MpCoopGather.log("encounter hook FAILED: #{e.class}: #{e.message}")
  end
end
