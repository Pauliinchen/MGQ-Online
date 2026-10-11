#----------------------------------------------------------------
#  coop_gather.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Showed the player's followers again when a call, a follow or a teleport takes them to another map, since the events that show them again on leaving a place such as Hades never ran and Formation stayed shut
#                            - Told whether a call, a follow or a teleport is ready to bring the player over, and had the pages of the teller's story give way to it
#                            - Looked for a map from 1000 on in the folder the game keeps it in, through the game's own file name, so a follow or teleport there is no longer dropped as a map this game lacks
#                            - Named the leader's wait and a member's time left before coming over as doings of the line above the player's head, which writes the seconds, and named the members still missing in the leader's doing, two at most and how many more
#                            - Counted the frames a moment has left in one place, which within? and a member's doing share
#      Paulinchen  2026-10-10: Let a Raid World's follow wait a minute for the player to be free instead of six seconds, since the story calls once and a follower kept busy longer, by the teller's pages, a battle or a menu, lost the follow and started their own copy of the story
#                            - Kept the follow of a teller's story the player took while they are on the way and for CALL_LAPSE_FRAMES after they arrived, which names that teller and takes their pages from the new map meanwhile
#                            - Let a player in a Raid World move while the teller fights the story's battle, so one who came late may join it
#                            - Moved the teleport to the party's leader to coop_teleport.rbx, which brings the player over through come_to
#                            - Let a teleport the player asked for wait a minute for the player to be free, as long as the request stood, instead of six seconds
#                            - Told the player that a call or teleport to a map this game lacks cannot be taken, besides the log line
#                            - Followed a Raid World's teller whose story moved on at once only while the player watches it and is not behind, and offered every other player to follow in the notification box while the teller tells there, a minute at most
#                            - Let a follow the player accepted in the notification box wait a minute for them to be free, and a leader's call that takes over a teleport the player asked for lapse as a call does
#      Paulinchen  2026-10-09: Read the warp ban's switch from story_state.rbx instead of coop_story.rbx
#                            - Called the players a Raid World's story takes along in one message instead of one per player
#                            - Kept whom the story took along for the whole telling, not only its first event, and named the teller whose call the player follows
#      Paulinchen  2026-10-08: Gathered nobody in a Raid World, where whoever is on the map watches, and took everyone on the map along where the story moves its teller
#                            - Offered a teleport to the story in a Raid World, to where the story was last told until the relay keeps its endpoint, with that place's warp ban
#                            - Took the teleport to the story to the endpoint the relay keeps of the world's story, where this game last saw the story told only while the relay keeps none
#                            - Kept telling the story to the players a Raid World's story took along until they arrive
#                            - Took the followers and the teller from MGQ_MpCoop::Scope
#      Paulinchen  2026-10-07: Dropped a call to a map this game lacks, which ended the game at the transfer
#                            - Registered the encounter hook through core_hooks.rbx instead of a wrap of its own
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
# play on; a member who plays their own story is never called. The story scenes themselves are
# sorted and told by coop_events.rbx, which hands this script its messages. A teleport to another
# member, see coop_teleport.rbx, brings the player over here too.
#
# A Raid World gathers nobody: whoever is on the map watches. A story that moves its teller elsewhere
# calls everyone on the map along: a player who watches it and is not behind the world's story
# follows at once, any other is offered to follow in the notification box. Anyone may teleport to
# the story on their own.
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

  # Members the leader's doing names as still missing at most; the rest are counted, so the line
  # above the leader's head stays within its width.
  NAMED_MISSING = 2

  # Frames the leader's story scene waits for the party at most before it starts without the
  # members who did not come, thirty seconds.
  HOLD_FRAMES = 1800

  # Frames without a call after which a member's call lapses, two calls missed: the leader's story
  # started without them, or the leader left.
  CALL_LAPSE_FRAMES = CALL_FRAMES * 2

  # Frames a teleport the player asked for, or a Raid World's follow, waits for the player to be
  # free before it lapses, a minute, as long as a request to another member stands (see
  # MGQ_MpCoopTeleport::ASK_FRAMES).
  ASKED_LAPSE_FRAMES = 3600

  # Frames an offer to follow a Raid World's teller whose story moved on stands in the notification
  # box at most, a minute.
  FOLLOW_OFFER_FRAMES = 3600

  # What a teleport to the story calls the place it goes to, as a call names its leader.
  STORY_NAME = "the story"

  @hold = nil
  @gather = nil
  @follow_offers = {}

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op gather"

  # Counts the frames left until some frames after a moment have passed.
  #
  # @param since [Integer] The moment's Graphics.frame_count.
  # @param frames [Integer] The frames.
  # @return [Integer] The frames left, 0 or less once they passed, more than frames for a moment
  #   that lies ahead.
  def self.frames_left(since, frames)
    since + frames - Graphics.frame_count
  end

  # Reports whether a moment lies less than some frames back.
  #
  # Loading a save sets the frame count back to the save's, so a moment noted before the load counts
  # as long past.
  #
  # @param since [Integer] The moment's Graphics.frame_count.
  # @param frames [Integer] The frames.
  # @return [Boolean] Whether it does.
  def self.within?(since, frames)
    left = frames_left(since, frames)
    left > 0 && left <= frames
  end

  # Forgets the leader's story scene the player holds and the leader's call, as when the world
  # closes or a save is loaded.
  def self.forget
    log("forgot #{[@hold && 'the held story', @gather && "#{@gather[:name]}'s call"].compact.join(', ')}") if @hold || @gather
    @hold = nil
    @gather = nil
    @taken_follow = nil
  end

  # Forgets where the story was last told, whom it took along and the offers to follow its tellers,
  # as when the world closes.
  def self.forget_story_place
    @story_place = nil
    @story_warp_ban = nil
    @follow_offers.clear
    forget_taken_along
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
    return take_raid(peer, message) if MGQ_MpCoop::Scope.raid?
    return log("ignored #{message['pevent']}: #{MGQ_MpOverworldSync.who(peer)} does not lead the party") unless MGQ_MpCoop.party_leader.equal?(peer)

    if %w(gather follow).include?(message["pevent"]) && !MGQ_MpCoopEvents.following?
      return log("ignored #{message['pevent']}: not synced with #{MGQ_MpOverworldSync.who(peer)}, the player plays their own story")
    end

    place = [message["map"].to_i, message["x"].to_i, message["y"].to_i, message["d"].to_i]
    case message["pevent"]
    when "gather" then called(peer, place, message["warp_ban"] == "1")
    when "follow" then followed(peer, place, message["warp_ban"] == "1")
    end
  rescue => e
    log("taking #{message['pevent']} failed: #{e.class}: #{e.message}")
  end

  # Takes a message about gathering in a Raid World, which gathers nobody: only the story's call
  # to follow where it moved its teller, sent to everyone who was on the teller's map. The player
  # follows at once only while they watch the teller's story, else it is offered, see offer_follow.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take_raid(peer, message)
    return log("ignored #{message['pevent']}: a Raid World gathers nobody") unless message["pevent"] == "follow"

    place = [message["map"].to_i, message["x"].to_i, message["y"].to_i, message["d"].to_i]
    warp_ban = message["warp_ban"] == "1"
    reason = follow_refusal(peer)
    reason ? offer_follow(peer, place, warp_ban, reason) : followed(peer, place, warp_ban)
  end

  # Tells why the player does not follow a Raid World's teller at once where their story moved
  # them: only a player who watches that teller's story and is not behind the world's does.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  # @return [String, nil] The reason, nil when the player follows at once.
  def self.follow_refusal(peer)
    return "the player's story is behind the world's" if MGQ_MpCoopEvents.behind?
    return "the player's story is not where #{MGQ_MpOverworldSync.who(peer)}'s is" unless MGQ_MpCoop::Scope.watches?(peer)

    nil
  end

  # Offers the player in the notification box to follow a Raid World's teller whose story moved
  # them elsewhere, see Offers.notice_of; a newer move of the same teller replaces the offer.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  # @param place [Array<Integer>] Where the teller stands now: map, x, y and direction.
  # @param warp_ban [Boolean] Whether warping is banned there.
  # @param reason [String] Why the player does not follow at once, for the log.
  def self.offer_follow(peer, place, warp_ban, reason)
    @follow_offers[peer.state["id"].to_s] = { :name => peer.state["name"].to_s, :place => place, :warp_ban => warp_ban, :since => Graphics.frame_count }
    log("offered to follow #{MGQ_MpOverworldSync.who(peer)} to map #{place[0]} #{place[1]},#{place[2]} in the notification box: #{reason}")
  end

  # Finds the standing offer to follow a teller, dropping it once their telling ended, the player
  # came to its map or FOLLOW_OFFER_FRAMES passed.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  # @return [Hash, nil] The offer: :name, :place, :warp_ban, :since and :seen once the teller's
  #   state told them telling; nil for none.
  def self.follow_offer(peer)
    id = peer.state["id"].to_s
    offer = @follow_offers[id]
    return nil unless offer

    reason = follow_offer_end(peer, offer)
    return offer unless reason

    @follow_offers.delete(id)
    log("dropped the offer to follow #{offer[:name]}: #{reason}")
    nil
  end

  # Tells why an offer to follow a teller ends, noting in the offer once their state told them
  # telling.
  #
  # The teller's state travels apart from the follow and may still say they are not telling when
  # it arrives, so only a telling seen to end drops the offer.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  # @param offer [Hash] The offer, see follow_offer.
  # @return [String, nil] The reason, nil while it stands.
  def self.follow_offer_end(peer, offer)
    telling = peer.state["telling"] == "1"
    offer[:seen] = true if telling
    return "their telling ended" if offer[:seen] && !telling
    return "it stood #{FOLLOW_OFFER_FRAMES / 60} s" unless within?(offer[:since], FOLLOW_OFFER_FRAMES)
    return "the player is on that map already" if $game_map && $game_map.map_id == offer[:place][0]

    nil
  end

  # Writes the notification box's line of an offer to follow a teller, naming the place as the
  # teller's state names it once they told it from there, else the map's id.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  # @param offer [Hash] The offer, see follow_offer.
  # @return [String] The line.
  def self.follow_text(peer, offer)
    map_id = offer[:place][0]
    place = peer.state["map"].to_i == map_id ? peer.state["place"].to_s : ""
    "#{offer[:name]}'s story moved on to #{place.empty? ? "map #{map_id}" : place}. Follow?"
  end

  # Follows a teller whose offer the player accepted, as a player who watches their story would at
  # once.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  def self.accept_follow(peer)
    offer = follow_offer(peer)
    return log("did not follow #{MGQ_MpOverworldSync.who(peer)}: the offer no longer stands") unless offer

    @follow_offers.delete(peer.state["id"].to_s)
    followed(peer, offer[:place], offer[:warp_ban])
  rescue => e
    log("following a teller failed: #{e.class}: #{e.message}")
  end

  # Drops the offer to follow a teller, which the player declined.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  def self.decline_follow(peer)
    offer = @follow_offers.delete(peer.state["id"].to_s)
    log("declined to follow #{offer[:name]}") if offer
  end

  # What gathering adds to the notification box: the offers to follow a Raid World's teller whose
  # story moved on, see offer_follow.
  module Offers
    # Tells nothing to the World overview, whose own row offers the teleport to the story.
    #
    # @param _peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [nil] Always.
    def self.call_of(_peer)
      nil
    end

    # Tells the offer to follow a teller for the notification box.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Notice, nil] The offer, nil for none.
    def self.notice_of(peer)
      offer = MGQ_MpCoopGather.follow_offer(peer)
      return nil unless offer

      MGQ_MpActions::Notice.new([:story_follow, peer.seat], MGQ_MpCoopGather.follow_text(peer, offer), MGQ_MpCoop::INVITE_COLOR, "Follow",
                                lambda { MGQ_MpCoopGather.accept_follow(peer) }, lambda { MGQ_MpCoopGather.decline_follow(peer) }, offer[:since])
    end

    # Adds no choice to another player's menu.
    #
    # @param _peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [nil] Always.
    def self.peer_option(_peer)
      nil
    end

    # Adds no choice to the player's own row.
    #
    # @return [Array] None.
    def self.own_options
      []
    end
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

  # As teller, lists those who follow the player's story, see MGQ_MpCoop::Scope.viewers.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.followers
    MGQ_MpCoop::Scope.viewers
  end

  # Reports whether every party member who follows the player's story stands near the player, on
  # the player's map; always in a Raid World, where whoever is on the map watches.
  #
  # @return [Boolean] Whether they do.
  def self.gathered?
    MGQ_MpCoop::Scope.raid? || missing.empty?
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

    if @gather.nil?
      MGQ_MpOverworldSync.notice("#{peer.state['name']}'s story is starting. You join them in #{GATHER_FRAMES / 60} seconds.")
      @gather = { :since => Graphics.frame_count, :name => peer.state["name"].to_s }
      log("called by #{peer.state['name']} to map #{place[0]} #{place[1]},#{place[2]}")
    elsif @gather[:asked] || @gather[:lapse]
      log("#{peer.state['name']}'s call to map #{place[0]} #{place[1]},#{place[2]} takes over the teleport to #{@gather[:name]}, and lapses as a call does")
      @gather.delete(:asked)
      @gather.delete(:lapse)
      @gather[:name] = peer.state["name"].to_s
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
  # such as a theater show's stage or a story's own teleport; in a Raid World calls everyone who was
  # on the map, whose games decide whether they follow at once (see take_raid). Called after
  # Game_Player#perform_transfer.
  def self.after_transfer
    from = @transfer_from
    @transfer_from = nil
    return unless from && MGQ_MpCoopEvents.leading_story?

    raid = MGQ_MpCoop::Scope.raid?
    along = raid ? (MGQ_MpCoop::Scope.peers_on(from[0]) + taken_along).uniq : followers.select { |peer| near_place?(peer.state, from) }
    @taken_along = along.map { |peer| peer.state["id"].to_s } if raid
    return log("took nobody along to map #{$game_map.map_id}: nobody stood near") if along.empty?

    fields = place_fields
    # In a Raid World the map's gate takes the call only for the map the others are on.
    fields["mmap"] = from[0] if raid
    if raid
      MGQ_MpCoopEvents.tell_each(along, "follow", fields)
    else
      along.each { |peer| tell(peer.seat, "follow", fields) }
    end
    log("took #{along.map { |peer| peer.state['name'] }.join(', ')} along to map #{$game_map.map_id} #{$game_player.x},#{$game_player.y}")
  rescue => e
    log("taking the party along failed: #{e.class}: #{e.message}")
  end

  # As teller in a Raid World, lists the players the story took along who are not on the player's
  # map yet, whose state still names the map they left, so the story's pages and scene reach them
  # on the way. None outside a telling; the next telling forgets them, see
  # MGQ_MpCoopEvents.note_telling_start.
  #
  # The story's next event starts in the frame its last one ended, so the list outlasts the moment
  # between them.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.taken_along
    return [] unless @taken_along && MGQ_MpCoopEvents.telling?

    along = MGQ_MpOverworldSync::Peers.present.select { |peer| @taken_along.include?(peer.state["id"].to_s) }
    arrived = along.select { |peer| peer.state["map"].to_i == $game_map.map_id }
    @taken_along -= arrived.map { |peer| peer.state["id"].to_s }
    along - arrived
  end

  # Forgets whom the story took along, as when a new telling starts.
  def self.forget_taken_along
    @taken_along = nil
  end

  # Takes the leader's call to follow them, whom their story moved elsewhere: the player comes at
  # once, as soon as they are free. In a Raid World the follow waits ASKED_LAPSE_FRAMES for that, as
  # a teleport the player asked for does, since the story calls once and the teller's pages, a
  # battle or a menu keep the player busy longer than CALL_LAPSE_FRAMES; a Classic leader's next
  # scene calls again.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param place [Array<Integer>] Where the leader stands now: map, x, y and direction.
  # @param warp_ban [Boolean] Whether warping is banned there.
  def self.followed(peer, place, warp_ban)
    log("following #{peer.state['name']} to map #{place[0]} #{place[1]},#{place[2]} as soon as the player is free")
    @gather = { :since => Graphics.frame_count - GATHER_FRAMES, :name => peer.state["name"].to_s, :place => place,
                :warp_ban => warp_ban, :called => Graphics.frame_count, :follow => true, :id => peer.state["id"].to_s }
    @gather[:lapse] = ASKED_LAPSE_FRAMES if MGQ_MpCoop::Scope.raid?
  end

  # Finds the follow the player takes: a teller's call to follow where their story moved them while
  # it stands and the player is on the way, and in a Raid World for CALL_LAPSE_FRAMES after they
  # arrived.
  #
  # A Raid World's teller is whoever's state says they tell, which says nothing between the story's
  # events, while the game's transfer process runs, and the player may arrive in that moment.
  #
  # @return [Hash, nil] The follow: the teller's :id and :name, and :place, their map, x, y and
  #   direction; nil for none.
  def self.follow_taken
    return @gather if @gather && @gather[:follow] && coming?

    @taken_follow && within?(@taken_follow[:since], CALL_LAPSE_FRAMES) ? @taken_follow : nil
  end

  # Names the teller whose story takes the player along now, see follow_taken.
  #
  # @return [String, nil] Their id, nil while no story takes the player along.
  def self.followed_id
    follow = follow_taken
    follow ? follow[:id] : nil
  end

  # Reports whether the leader's story pages of a map reach the player: the player's map, or the
  # one they follow the leader to, whose pages wait until they arrived.
  #
  # @param map_id [Integer] The map the leader tells the story on.
  # @return [Boolean] Whether they do.
  def self.story_map?(map_id)
    return true if map_id == $game_map.map_id

    follow = follow_taken
    follow && follow[:place][0] == map_id ? true : false
  end

  # Finds where a teleport to the story goes: the endpoint the relay keeps of the world's story (see
  # MGQ_MpWorldStory.endpoint), else where the story was last told in the world, by the player or
  # anyone else, as far as this game saw.
  #
  # @return [Array<Integer>, nil] The map, x, y and direction, nil while none is known.
  def self.story_endpoint
    relay = defined?(MGQ_MpWorldStory) ? MGQ_MpWorldStory.endpoint : nil
    relay || @story_place
  end

  # Tells whether warping is banned where a teleport to the story goes, known only where this game
  # saw the story told.
  #
  # @param place [Array<Integer>] Where it goes, see story_endpoint.
  # @return [Boolean, nil] Whether it is, nil while unknown.
  def self.story_warp_ban(place)
    @story_place && @story_place[0, 3] == place[0, 3] ? @story_warp_ban : nil
  end

  # Notes where the story is told, by the player or by anyone else in the world, which a teleport
  # to the story goes to, and whether warping is banned there. Called after the map's update, in a
  # Raid World alone.
  def self.note_story_place
    return unless MGQ_MpCoop::Scope.raid?

    if MGQ_MpCoopEvents.story_playing?
      @story_place = [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction]
      @story_warp_ban = warp_ban?
      return
    end
    teller = MGQ_MpOverworldSync::Peers.present.find { |peer| peer.state["telling"] == "1" }
    return unless teller

    @story_place = [teller.state["map"].to_i, teller.state["x"].to_i, teller.state["y"].to_i, teller.state["d"].to_i]
    @story_warp_ban = teller.state.key?("twb") ? teller.state["twb"] == "1" : nil
  rescue => e
    log_once(:story_place, "noting where the story is told failed: #{e.class}: #{e.message}")
  end

  # Teleports the player to the story, see story_endpoint, as soon as they are free.
  def self.join_story
    place = story_endpoint
    unless place
      log("no teleport to the story: this game saw nobody tell it yet")
      return MGQ_MpOverworldSync.notice("Nobody has told the story yet.")
    end
    if near_place?(own_place, place)
      log("no teleport to the story: the player stands there already")
      return MGQ_MpOverworldSync.notice("You are at the story already.")
    end

    come_to(STORY_NAME, place, story_warp_ban(place))
    MGQ_MpOverworldSync.notice("Teleporting to #{STORY_NAME} . . .")
  rescue => e
    log("teleporting to the story failed: #{e.class}: #{e.message}")
  end

  # Brings the player to a place the player asked to teleport to, as soon as they are free, within
  # ASKED_LAPSE_FRAMES.
  #
  # @param name [String] Whom or what the place is, for the line above the player's head.
  # @param place [Array<Integer>] The map, x, y and direction.
  # @param warp_ban [Boolean, nil] Whether warping is banned there, nil when unknown, which keeps the player's.
  def self.come_to(name, place, warp_ban)
    log("teleporting to #{name} on map #{place[0]} #{place[1]},#{place[2]} as soon as the player is free")
    @gather = { :since => Graphics.frame_count - GATHER_FRAMES, :name => name, :place => place,
                :warp_ban => warp_ban, :called => Graphics.frame_count, :asked => true, :lapse => ASKED_LAPSE_FRAMES }
  end

  # Tells after how many frames without a call a call lapses: its own lapse, as a teleport the
  # player asked for has, else CALL_LAPSE_FRAMES.
  #
  # @param gather [Hash] The call, see pending_call.
  # @return [Integer] The frames.
  def self.lapse_of(gather)
    gather[:lapse] || CALL_LAPSE_FRAMES
  end

  # Reports whether a call, a follow or a teleport is ready to bring the player over once they are
  # free, which the pages of the teller's story give way to (see MGQ_MpCoopEvents.read?): read on
  # the old map, they kept the player busy while the story went on without them.
  #
  # @return [Boolean] Whether one is.
  def self.due?
    come? ? true : false
  end

  # Reports whether the leader's story scene is about to bring the player over, which keeps random
  # encounters and co-op battles away so no battle holds the player up.
  #
  # @return [Boolean] Whether it is.
  def self.coming?
    !@gather.nil? && within?(@gather[:called], lapse_of(@gather))
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
  # @return [Hash, nil] The call: :since, :name, :place, :warp_ban and :called, and :lapse for one
  #   with its own (see lapse_of); nil for none.
  def self.pending_call
    return nil unless @gather
    return @gather if within?(@gather[:called], lapse_of(@gather))

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

  # Names what the player is doing for the line above their own head, if anything: as leader the
  # members the story still waits for, NAMED_MISSING at most and how many more, and how long it
  # holds, as member the time left before coming over, or that they come once free.
  #
  # The leader's doing says "Gathering" as the notice of the story's call does, not "Waiting for"
  # as a battle's waiting box, since it names the same wait as that notice.
  #
  # @return [String, Array, nil] The doing, with the moment it lapses while one is known, nil for none.
  def self.own_doing
    if @hold && MGQ_MpCoop.party_leading?
      names = missing
      more = names.size - NAMED_MISSING
      text = names.empty? ? "Gathering the party" : "Gathering: #{names.first(NAMED_MISSING).join(', ')}#{" +#{more}" if more > 0}"
      return [text, MGQ_MpActions.lapse_at(@hold[:since], HOLD_FRAMES)]
    end

    gather = pending_call
    return nil unless gather

    left = frames_left(gather[:since], GATHER_FRAMES)
    left > 0 ? ["Joining #{gather[:name]}", MGQ_MpActions.lapse_in(left)] : "Joining #{gather[:name]} once free"
  end

  # Reports whether the player has to stand still: while the story scene they see plays on the
  # player's map, their leader's or in a Raid World the teller's there. A member it started
  # without plays on elsewhere, and so does a player whose story does not match the teller's.
  #
  # A Raid World's teller in the story's battle holds nobody: a player who came after its invites
  # could otherwise neither move nor join it until it ended.
  #
  # @return [Boolean] Whether they do.
  def self.blocked?
    lead = MGQ_MpCoop::Scope.teller
    return false unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && lead.state["telling"] == "1"
    return false unless lead.state["map"].to_i == $game_map.map_id && MGQ_MpCoop::Scope.watches?(lead)

    !(MGQ_MpCoop::Scope.raid? && lead.state["scene"] == "battle")
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
    defined?(MGQ_MpStoryState) && $game_switches[MGQ_MpStoryState::WARP_BAN] ? true : false
  end

  # Takes over the warp ban of the place the leader's story scene brought the player to.
  #
  # The game sets the ban in the events a player walks through to enter or leave a cave, which a
  # player brought over never touches, so the ban of the place they left would stay.
  #
  # @param banned [Boolean, nil] Whether warping is banned where the leader stands, nil when unknown,
  #   which keeps the player's.
  def self.take_warp_ban(banned)
    $game_switches[MGQ_MpStoryState::WARP_BAN] = banned if defined?(MGQ_MpStoryState) && !banned.nil?
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
    return log("dropped #{gather[:name]}'s call: the player is no longer in a party") unless MGQ_MpCoop::Scope.sharing?

    unless map_id == $game_map.map_id || map_known?(map_id)
      MGQ_MpOverworldSync.notice("Cannot teleport to #{gather[:name]}: this game has no map #{map_id}.")
      return log("dropped #{gather[:name]}'s call to map #{map_id}: this game has no such map")
    end

    reason = gather[:follow] ? "the story moved them" : (gather[:asked] ? "the player asked to teleport" : "their story scene called")
    log("#{gather[:follow] ? 'followed' : 'came to'} #{gather[:name]} on map #{map_id} #{x},#{y}, from map #{$game_map.map_id} #{$game_player.x},#{$game_player.y}: #{reason}")
    @taken_follow = { :id => gather[:id], :name => gather[:name], :place => place, :since => Graphics.frame_count } if gather[:follow] && MGQ_MpCoop::Scope.raid?
    MGQ_MpCoopCastle.arriving(map_id) if defined?(MGQ_MpCoopCastle)
    warp_ban = gather[:warp_ban]
    elsewhere = map_id != $game_map.map_id
    if elsewhere
      $game_player.reserve_transfer(map_id, x, y, direction > 0 ? direction : 2)
    else
      $game_player.moveto(x, y)
      $game_player.set_direction(direction) if direction > 0
    end
    take_warp_ban(warp_ban)
    show_followers if elsewhere
  rescue => e
    log("coming to the leader failed: #{e.class}: #{e.message}")
  end

  # Shows the player's followers again as they leave for another map.
  #
  # The game shows them again only in the events a player walks through to leave a place that hid
  # them, such as Hades after a defeat, which a player brought over never touches, and the menu's
  # Formation stays shut while they are hidden.
  def self.show_followers
    followers = $game_player.followers
    return if followers.visible

    followers.visible = true
    $game_player.refresh
    log("showed the player's followers again, which the map they left had hidden")
  end

  # Reports whether this game has a map, reading its file once per map.
  #
  # A leader whose game has maps this one lacks, such as a mod's, would otherwise end this game at
  # the transfer, which loads the map's file past every rescue.
  #
  # @param map_id [Integer] The map.
  # @return [Boolean] Whether its data loads, always outside the game.
  def self.map_known?(map_id)
    return true unless defined?(load_data)

    @known_maps ||= {}
    return @known_maps[map_id] if @known_maps.key?(map_id)

    @known_maps[map_id] = begin
      load_data(map_file(map_id))
      true
    rescue StandardError, Errno::ENOENT
      false
    end
  end

  # Names a map's data file as the game loads it.
  #
  # The game keeps the maps from 1000 on in folders of their own (Map/Data, Map2/Data, ...), which
  # only its own DataManager.map_file_name knows.
  #
  # @param map_id [Integer] The map.
  # @return [String] The file, such as "Data/Map407.rvdata2" or "Map/Data/Map650.rvdata2".
  def self.map_file(map_id)
    DataManager.respond_to?(:map_file_name) ? DataManager.map_file_name(map_id) : sprintf("Data/Map%03d.rvdata2", map_id)
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
    log(blocked ? "standing still: the leader's story plays on map #{$game_map.map_id}" : "free to move: the leader's story no longer plays here, or its teller fights a battle")
  rescue
  end
end

# The line above the player's own head while the leader's story gathers or calls them, and the
# offers to follow a Raid World's teller in the notification box, through ui_actions.rbx.

begin
  MGQ_MpActions.own_doing_from { MGQ_MpCoopGather.own_doing }
  MGQ_MpActions.offer(MGQ_MpCoopGather::Offers)
rescue => e
  MGQ_MpCoopGather.log("actions FAILED: #{e.class}: #{e.message}")
end

# The calls, the hold and where the story was told go once the world closes, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick do |in_world|
    unless in_world
      MGQ_MpCoopGather.forget
      MGQ_MpCoopGather.forget_story_place
    end
  end
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
    MGQ_MpCoopGather.note_story_place
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

# What the pages of the teller's story give way to, through coop_events.rbx.

begin
  MGQ_MpCoopEvents.give_way_to { MGQ_MpCoopGather.due? ? "the story's call to come over" : nil }
rescue => e
  MGQ_MpCoopGather.log("giving way FAILED: #{e.class}: #{e.message}")
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
