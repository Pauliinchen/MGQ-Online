#----------------------------------------------------------------
#  coop_gather.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Registered the encounter hook through core_hooks.rbx instead of a wrap of its own
#                            - Gathered, held and called for the leader's story only the members synced with the leader, who follow it
#                            - Logged every gathering message sent and taken, the hold's end and why, teleports and their reason, calls ignored, waits for a free moment, standing still and encounters kept away
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
# member who follows the leader's story (see MGQ_MpCoopStory.follows_leader?) stands near them,
# thirty seconds at most: members get five seconds to finish what they do, then are brought over
# once free, and stand still while the scene plays. It starts without those who did not come, who
# play on; a member who plays their own story is never called. A member may also teleport to the leader on their own. The story
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
    log("forgot #{[@hold && 'the held story', @gather && "#{@gather[:name]}'s call", @asked && 'the question where the leader stands'].compact.join(', ')}") if @hold || @gather || @asked
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
    sent = MGQ_MpCoopEvents.tell(seat, kind, fields)
    place = fields["map"] ? " (map #{fields['map']} #{fields['x']},#{fields['y']}#{fields['warp_ban'] == 1 ? ', warping banned' : ''})" : ""
    log("sent #{kind} to #{seat < 0 ? 'the party' : "seat #{seat}"}#{place}#{sent ? '' : ', which failed'}")
    sent
  end

  # Takes a message about gathering, handed over by coop_events.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    log("got #{message['pevent']} from #{MGQ_MpOverworldSync.who(peer)}#{message['map'] ? " (map #{message['map']} #{message['x']},#{message['y']}#{message['warp_ban'] == '1' ? ', warping banned' : ''})" : ''}")
    return answer_where(peer) if message["pevent"] == "where"
    return log("ignored #{message['pevent']}: #{MGQ_MpOverworldSync.who(peer)} does not lead the party") unless MGQ_MpCoop.party_leader.equal?(peer)

    if %w(gather follow).include?(message["pevent"]) && !MGQ_MpCoopEvents.following?
      return log("ignored #{message['pevent']}: not synced with #{MGQ_MpOverworldSync.who(peer)}, the player plays their own story")
    end

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
    log("stopped holding the story: another event started on the map") if @hold
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

    leading = MGQ_MpCoopEvents.leading_story?
    if !leading || gathered?
      since = @hold[:since]
      @hold = nil
      log(leading ? "the party is here after #{(Graphics.frame_count - since) / 60} s: the story starts" : "released the story: no member follows the player's story")
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
      log("calling the party again, still waiting for #{missing.join(', ')}")
      gather
    end
    true
  rescue => e
    @hold = nil
    log("holding the story failed: #{e.class}: #{e.message}")
    false
  end

  # As leader, lists the members who follow the player's story, through coop_story.rbx.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
  def self.followers
    defined?(MGQ_MpCoopStory) ? MGQ_MpCoopStory.synced_members : []
  end

  # Reports whether every party member who follows the player's story stands near the player, on
  # the player's map.
  #
  # @return [Boolean] Whether they do.
  def self.gathered?
    missing.empty?
  end

  # Names the party members who follow the player's story and do not stand near the player yet;
  # those who play their own story are never waited for.
  #
  # @return [Array<String>] Their names.
  def self.missing
    here = [$game_map.map_id, $game_player.x, $game_player.y]
    followers.reject { |peer| near_place?(peer.state, here) }.map { |peer| peer.state["name"].to_s }
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
    if near_place?(own_place, place)
      log("stays: the player stands near #{peer.state['name']} already")
      return @gather = nil
    end
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
    @transfer_from = player.transfer? && MGQ_MpCoopEvents.telling? && MGQ_MpCoopEvents.leading_story? ? [$game_map.map_id, player.x, player.y] : nil
    log("the story moves the player from map #{@transfer_from[0]} #{@transfer_from[1]},#{@transfer_from[2]}; the members near come along") if @transfer_from
  end

  # As leader, takes along the members who stood near when the story moved the player elsewhere,
  # such as a theater show's stage or a story's own teleport. Called after
  # Game_Player#perform_transfer.
  def self.after_transfer
    from = @transfer_from
    @transfer_from = nil
    return unless from && MGQ_MpCoopEvents.leading_story?

    along = followers.select { |peer| near_place?(peer.state, from) }
    return log("took nobody along to map #{$game_map.map_id}: no member stood near") if along.empty?

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
    log("following #{peer.state['name']} to map #{place[0]} #{place[1]},#{place[2]} as soon as the player is free")
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
    return log("no teleport: the player #{lead == :me ? 'leads the party' : 'is in no party'}") unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)

    name = lead.state["name"].to_s
    if near_place?(own_place, [lead.state["map"].to_i, lead.state["x"].to_i, lead.state["y"].to_i])
      log("no teleport: the player stands near #{name} already")
      return MGQ_MpOverworldSync.notice("You are with #{name} already.")
    end

    log("teleporting to #{name}: asking where they stand")
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
    return tell(peer.seat, "come", place_fields) if MGQ_MpCoop.party_leader == :me && MGQ_MpCoop::Party.member?(peer.state)

    log("did not answer #{MGQ_MpOverworldSync.who(peer)} where the player stands: #{MGQ_MpCoop.party_leader == :me ? 'not a member' : 'the player does not lead the party'}")
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
    return log("ignored #{peer.state['name']}'s place: the player #{asked ? 'asked too long ago' : 'never asked'}") unless asked && within?(asked, CALL_LAPSE_FRAMES)
    return log("no teleport: the player stands near #{peer.state['name']} already") if near_place?(own_place, place)

    log("teleporting to #{peer.state['name']} on map #{place[0]} #{place[1]},#{place[2]} as soon as the player is free")
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

  # Keeps a random encounter away while the leader's call brings the player over, drawing new
  # steps for ones that ran out, which would start a battle the moment the player arrives.
  #
  # @param player [Game_Player] The player.
  # @return [Boolean] false, since no battle starts.
  def self.keep_encounter_away(player)
    log("kept a random encounter away: the leader's call brings the player over") if player.mgq_mp_renew_encounter_steps
    false
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
  # on the player's map and they follow it. A member it started without plays on elsewhere.
  #
  # @return [Boolean] Whether they do.
  def self.blocked?
    lead = MGQ_MpCoop.party_leader
    lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && lead.state["telling"] == "1" && lead.state["map"].to_i == $game_map.map_id && MGQ_MpCoopEvents.following?
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
    return note_busy unless place && MGQ_MpOverworldSync.map_free?

    map_id, x, y, direction = place
    gather = @gather
    @gather = nil
    return log("dropped #{gather[:name]}'s call: the player is no longer in a party") unless MGQ_MpCoop.in_party?

    reason = gather[:follow] ? "the story moved them" : (gather[:asked] ? "the player asked to teleport" : "their story scene called")
    log("#{gather[:follow] ? 'followed' : 'came to'} #{gather[:name]} on map #{map_id} #{x},#{y}, from map #{$game_map.map_id} #{$game_player.x},#{$game_player.y}: #{reason}")
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

  # Logs once per call why the player does not come to the leader yet, once its five seconds passed.
  def self.note_busy
    gather = @gather
    return unless gather && !gather[:busy_logged] && !within?(gather[:since], GATHER_FRAMES)

    gather[:busy_logged] = true
    log("waiting to come to #{gather[:name]}: #{settled? ? 'the player is busy with an event, a message, a screen or a transfer' : 'the map has not settled after a PvP battle or a fade'}")
  end

  # Logs once the player starts or stops standing still for the leader's story scene on their map.
  def self.note_blocked
    blocked = blocked?
    return if blocked == (@blocked ? true : false)

    @blocked = blocked
    log(blocked ? "standing still: the leader's story plays on map #{$game_map.map_id}" : "free to move: the leader's story no longer plays here")
  rescue
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
  MGQ_MpHooks.after(Game_Map, :update, "coop_gather") do
    MGQ_MpCoopGather.update
    MGQ_MpCoopGather.note_blocked
  end

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

# What gathering asks of the player.

class Game_Player
  # Draws the steps to the next random encounter anew when they ran out.
  #
  # @return [Boolean] Whether they had run out.
  def mgq_mp_renew_encounter_steps
    return false if @encounter_count > 0

    make_encounter_count
    true
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # A random encounter when its steps ran out, but none while the leader's story scene is about to
  # bring the player over.
  MGQ_MpHooks.around(Game_Player, :encounter, "coop_gather") do |player, _args, original|
    (MGQ_MpCoopGather.coming? rescue false) ? MGQ_MpCoopGather.keep_encounter_away(player) : original.call
  end
rescue => e
  MGQ_MpCoopGather.log("encounter hook FAILED: #{e.class}: #{e.message}")
end
