#----------------------------------------------------------------
#  coop_gather.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Forgot the calls, the question where the leader stands and the hold once the world closes or a save is loaded, and counted a moment before a loaded save's frame count as long past
#                            - Took the party's leader from coop.rbx and whether a PvP battle runs from coop_events.rbx
#      Paulinchen  2026-10-04: Told coop_castle.rbx where a member brought into the Pocket Castle came from
#                            - Kept a story's call out of a PvP battle, dropped one a duel's end puts the game back over, and moved a member only on a settled map
#                            - Took the members near the leader along wherever the story moves the leader, and logged gathering, calls and arrivals
#                            - Told whether the player only waits for the party's story, which keeps the chat open
#                            - Created
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

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op gather"

  # Reports whether a moment lies less than some frames back.
  #
  # Loading a save sets the frame count back to the save's, so a moment noted before the load counts
  # as long past.
  #
  # @param since [Integer] The moment's Graphics.frame_count.
  # @param frames [Integer] The frames.
  # @return [Boolean] Whether it does.
  def self.within?(since, frames)
    elapsed = Graphics.frame_count - since
    elapsed >= 0 && elapsed < frames
  end

  # Forgets the leader's story scene the player holds, the leader's call and the player's question
  # where the leader stands, as when the world closes or a save is loaded.
  def self.forget
    @hold = nil
    @gather = nil
    @asked = nil
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
    return unless MGQ_MpCoop.party_leader.equal?(peer)

    place = [message["map"].to_i, message["x"].to_i, message["y"].to_i, message["d"].to_i]
    case message["pevent"]
    when "gather" then called(peer, place, message["warp_ban"] == "1")
    when "come" then answered(peer, place, message["warp_ban"] == "1")
    when "follow" then followed(peer, place, message["warp_ban"] == "1")
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
    log("gathering the party for a story scene on map #{$game_map.map_id}, waiting for #{missing.join(', ')}")
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

    leading = MGQ_MpCoop.party_leading?
    if !leading || gathered?
      @hold = nil
      MGQ_MpOverworldSync.notice("The party is here.") if leading
      return false
    end

    unless within?(@hold[:since], HOLD_FRAMES)
      @hold = nil
      MGQ_MpOverworldSync.notice("The story starts without #{missing.join(', ')}.")
      log("the story starts without #{missing.join(', ')}")
      return false
    end

    unless within?(@hold[:called], CALL_FRAMES)
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
    return log_once([:duel_call, Graphics.frame_count / HOLD_FRAMES], "a call came during a PvP battle, which keeps it out") if MGQ_MpCoopEvents.pvp_running?

    unless @gather
      MGQ_MpOverworldSync.notice("#{peer.state['name']}'s story is starting. You join them in #{GATHER_FRAMES / 60} seconds.")
      @gather = { :since => Graphics.frame_count, :name => peer.state["name"].to_s }
      log("called by #{peer.state['name']} to map #{place[0]} #{place[1]},#{place[2]}")
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

  # As leader, notes where the player stands before a transfer, to take the members standing near
  # along when the story moves the player. Called before Game_Player#perform_transfer.
  #
  # @param player [Game_Player] The player.
  def self.before_transfer(player)
    @transfer_from = player.transfer? && MGQ_MpCoopEvents.telling? && MGQ_MpCoop.party_leading? ? [$game_map.map_id, player.x, player.y] : nil
  end

  # As leader, takes along the members who stood near when the story moved the player elsewhere,
  # such as a theater show's stage or a story's own teleport. Called after
  # Game_Player#perform_transfer.
  def self.after_transfer
    from = @transfer_from
    @transfer_from = nil
    return unless from && MGQ_MpCoop.party_leading?

    along = MGQ_MpCoop::Party.members.select { |peer| near_place?(peer.state, from) }
    return if along.empty?

    along.each { |peer| tell(peer.seat, "follow", place_fields) }
    log("took #{along.map { |peer| peer.state['name'] }.join(', ')} along to map #{$game_map.map_id} #{$game_player.x},#{$game_player.y}")
  rescue => e
    log("taking the party along failed: #{e.class}: #{e.message}")
  end

  # Takes the leader's call to follow them, whom their story moved elsewhere: the player comes at
  # once, as soon as they are free.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param place [Array<Integer>] Where the leader stands now: map, x, y and direction.
  # @param warp_ban [Boolean] Whether warping is banned there.
  def self.followed(peer, place, warp_ban)
    @gather = { :since => Graphics.frame_count - GATHER_FRAMES, :name => peer.state["name"].to_s, :place => place,
                :warp_ban => warp_ban, :called => Graphics.frame_count, :follow => true }
  end

  # Reports whether the leader's story pages of a map reach the player: the player's map, or the
  # one they are about to follow the leader to, whose pages wait until they arrived.
  #
  # @param map_id [Integer] The map the leader tells the story on.
  # @return [Boolean] Whether they do.
  def self.story_map?(map_id)
    map_id == $game_map.map_id || (!@gather.nil? && @gather[:follow] && @gather[:place][0] == map_id)
  end

  # As member, asks the leader where they stand, to come over as soon as the player is free.
  def self.join_leader
    lead = MGQ_MpCoop.party_leader
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
    tell(peer.seat, "come", place_fields) if MGQ_MpCoop.party_leader == :me && MGQ_MpCoop::Party.member?(peer.state)
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
    return unless asked && within?(asked, CALL_LAPSE_FRAMES)
    return if near_place?(own_place, place)

    @gather = { :since => Graphics.frame_count - GATHER_FRAMES, :name => peer.state["name"].to_s, :place => place,
                :warp_ban => warp_ban, :called => Graphics.frame_count, :asked => true }
  end

  # Reports whether the leader's story scene is about to bring the player over, which keeps random
  # encounters and co-op battles away so no battle holds the player up.
  #
  # @return [Boolean] Whether it is.
  def self.coming?
    !@gather.nil? && within?(@gather[:called], CALL_LAPSE_FRAMES)
  end

  # Tells where the player comes to for the leader's story scene, once its five seconds passed and
  # the map settled.
  #
  # @return [Array<Integer>, nil] The leader's map, x, y and direction, nil while none or not yet.
  def self.come?
    gather = pending_call
    gather && !within?(gather[:since], GATHER_FRAMES) && settled? ? gather[:place] : nil
  end

  # Reports whether the map settled enough to take the player elsewhere: no PvP battle runs or puts
  # the game back, and the screen is not fading.
  #
  # A duel puts its snapshot of the game back as the map starts again, and a transfer started then
  # left the screen black.
  #
  # @return [Boolean] Whether it did.
  def self.settled?
    !MGQ_MpCoopEvents.pvp_running? && !($game_temp && $game_temp.in_memory_battle) && Graphics.brightness == 255
  end

  # Forgets the leader's call, as when a duel puts the game back as it was before it, so the player
  # answers the leader's next call on a settled map.
  #
  # @param reason [String] Why, for the log.
  def self.drop_call(reason)
    return unless @gather

    log("dropped #{@gather[:name]}'s call: #{reason}")
    @gather = nil
  end

  # The leader's call the player has yet to answer, forgetting it once the calls stopped.
  #
  # @return [Hash, nil] The call: :since, :name, :place, :warp_ban and :called; nil for none.
  def self.pending_call
    return nil unless @gather
    return @gather if within?(@gather[:called], CALL_LAPSE_FRAMES)

    MGQ_MpOverworldSync.notice(lapse_notice(@gather))
    log("#{@gather[:name]}'s call lapsed")
    @gather = nil
  end

  # Tells the player why the leader's call lapsed.
  #
  # @param gather [Hash] The call, see pending_call.
  # @return [String] The notice.
  def self.lapse_notice(gather)
    return "You were too busy to teleport to #{gather[:name]}." if gather[:asked]
    return "#{gather[:name]}'s story went on without you." if gather[:follow]

    "#{gather[:name]}'s story started without you."
  end

  # Tells what the line above the player's own head says about the party's story, if anything:
  # the leader's wait, or a member's time left before coming over.
  #
  # @return [String, nil] The line.
  def self.own_line
    return "Gathering the party . . ." if @hold && MGQ_MpCoop.party_leading?

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
    lead = MGQ_MpCoop.party_leader
    lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && lead.state["telling"] == "1" && lead.state["map"].to_i == $game_map.map_id
  end

  # Reports whether the player only waits for the party's story: as leader while it gathers, as
  # member while called, held by it or reading its pages. The chat stays open meanwhile.
  #
  # @return [Boolean] Whether they do.
  def self.waiting?
    (holding_story? && MGQ_MpCoop.party_leading?) || coming? || blocked? || MGQ_MpCoopEvents.mirroring?
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
    gather = @gather
    @gather = nil
    return unless MGQ_MpCoop.in_party?

    log("#{gather[:follow] ? 'followed' : 'came to'} #{gather[:name]} on map #{map_id} #{x},#{y}, from map #{$game_map.map_id}")
    MGQ_MpCoopCastle.arriving(map_id) if defined?(MGQ_MpCoopCastle)
    warp_ban = gather[:warp_ban]
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

# The calls and the hold go once the world closes, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpCoopGather.forget unless in_world }
rescue => e
  MGQ_MpCoopGather.log("overworld sync FAILED: #{e.class}: #{e.message}")
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

  # Around the player's transfer, the leader takes along the members the story moves with them.
  MGQ_MpHooks.before(Game_Player, :perform_transfer, "coop_gather") { MGQ_MpCoopGather.before_transfer(self) }
  MGQ_MpHooks.after(Game_Player, :perform_transfer, "coop_gather") { MGQ_MpCoopGather.after_transfer }

  # A loaded save starts the frame count anew, so the calls and the hold of before it go.
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "coop_gather") { |_contents| MGQ_MpCoopGather.forget }
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
