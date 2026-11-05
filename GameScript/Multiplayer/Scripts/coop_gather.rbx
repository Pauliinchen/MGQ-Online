#----------------------------------------------------------------
#  coop_gather.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Logged only what a forget dropped, never a false entry
#                            - Told and read whether a telling moves the world's story on as true or false, which the DLL writes as 1 or 0
#                            - Asked the DLL's one decision whether a telling moves the world's story on, which decides whom it takes along
#                            - Left what a call, follow or teleport leaves of the player's scene and place to the one guard of the game's flow, the followers a map left hidden among it
#                            - Counted its moments by the bridge's frame
#      Paulinchen  2026-10-31: Stopped carrying the warp ban along with a call, a follow or a teleport
#      Paulinchen  2026-10-28: Kept the calls, the hold and the follow offers with their frames in the DLL
#                            - Read a Raid World's tellers from the tellings the relay told of
#      Paulinchen  2026-10-24: Took the warp and escape bans the teller's scene set on the map the player is on the way to
#                            - Followed a teller at once whose scene that runs by itself the player's game keeps from starting
#                            - Held the player no longer for a telling nothing of which came for thirty seconds
#      Paulinchen  2026-10-23: Took the player out of their own scene before a call, follow or teleport moves them
#                            - Pulled a Raid World viewer along at once only when the telling moves the world's story on
#      Paulinchen  2026-10-12: Let a player in a Classic world move while the teller fights the story's battle
#                            - Told whether a battle invite comes from the player whose story calls
#      Paulinchen  2026-10-11: Showed the player's followers again after a call, follow or teleport
#                            - Told whether a call, follow or teleport is ready to bring the player over
#                            - Looked for maps from 1000 on through the game's own file name
#                            - Named the leader's wait and a member's time left above the player's head
#                            - Counted the frames a moment has left in one place
#      Paulinchen  2026-10-10: Let a Raid World's follow wait a minute for the player to be free
#                            - Kept the follow the player took while on the way and shortly after arriving
#                            - Let a player in a Raid World move while the teller fights the story's battle
#                            - Moved the teleport to the leader to coop_teleport.rbx
#                            - Let a teleport the player asked for wait a minute for them to be free
#                            - Told the player that a call or teleport to a missing map cannot be taken
#                            - Followed a Raid World's teller at once only while watching, and offered others to follow
#                            - Let an accepted follow wait a minute, and a call over a teleport lapse as a call
#      Paulinchen  2026-10-09: Read the warp ban's switch from story_state.rbx
#                            - Called the players a Raid World's story takes along in one message
#                            - Kept whom the story took along for the whole telling
#      Paulinchen  2026-10-08: Gathered nobody in a Raid World and took everyone on the map along
#                            - Offered a teleport to the story in a Raid World
#                            - Took the teleport to the story to the relay's endpoint of the world's story
#                            - Kept telling the story to the players a Raid World's story took along until they arrive
#                            - Took the followers and the teller from MGQ_MpCoop::Scope
#      Paulinchen  2026-10-07: Dropped a call to a map this game lacks
#                            - Registered the encounter hook through core_hooks.rbx
#                            - Gathered, held and called only the members synced with the leader
#                            - Logged gathering messages, the hold, teleports, calls and waits
#      Paulinchen  2026-10-06: Forgot the calls and the hold once the world closes or a save is loaded
#                            - Took the party's leader from coop.rbx and whether a PvP battle runs from coop_events.rbx
#      Paulinchen  2026-10-04: Told coop_castle.rbx where a member brought into the Pocket Castle came from
#                            - Kept a story's call out of a PvP battle and moved a member only on a settled map
#                            - Took the members near the leader along wherever the story moves the leader
#                            - Told whether the player only waits for the party's story
#                            - Created
#
#----------------------------------------------------------------

# Gathering a party for the leader's story scenes. A story scene the leader starts waits until every
# member who follows the leader's story (see MGQ_MpCoopStory.follows_leader?) stands near them,
# thirty seconds at most: members get five seconds to finish what they do, then are brought over once
# free, and stand still while the scene plays. It starts without those who did not come, who play
# on; a member who plays their own story is never called. The story scenes themselves are sorted
# and told by coop_events.rbx, which hands this script its messages. A teleport to another member,
# see coop_teleport.rbx, brings the player over here too. A Raid World gathers nobody, since
# whoever is on the map watches, but a story that moves its teller elsewhere calls everyone on the
# map along (see take_raid), and anyone may teleport to the story on their own. The calls, the
# hold and the offers with their frames are the DLL's (MGQOnline.Game's Telling/GatherCalls,
# behind the topics of GatherTopics); this script reads the game and moves the player.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopGather
  # The DLL's topics of the calls, see GatherTopics in MGQOnline.Game.
  CALLED_TOPIC = "gather.called"
  COME_TO_TOPIC = "gather.come_to"
  FOLLOWED_TOPIC = "gather.followed"
  BAN_TOPIC = "gather.ban"
  FRAME_TOPIC = "gather.frame"
  TAKE_TOPIC = "gather.take"
  CALLING_BATTLE_TOPIC = "gather.calling_battle"
  DROP_CALL_TOPIC = "gather.drop_call"
  HOLD_TOPIC = "gather.hold"
  DROP_HOLD_TOPIC = "gather.drop_hold"
  HOLDING_TOPIC = "gather.holding"
  OFFER_TOPIC = "gather.offer"
  FOLLOW_OFFER_TOPIC = "gather.follow_offer"
  ACCEPT_TOPIC = "gather.accept"
  DECLINE_TOPIC = "gather.decline"
  FORGET_TOPIC = "gather.forget"
  FORGET_OFFERS_TOPIC = "gather.forget_offers"

  # Tiles a member may stand away from the leader, on the leader's map, to count as gathered.
  GATHER_TILES = 3

  # What a teleport to the story calls the place it goes to, as a call names its leader.
  STORY_NAME = "the story"

  # What the leader reads as their story scene starts gathering the party.
  GATHERING_TEXT = "Gathering the party for the story . . ."

  # How the calls stand while the DLL does not answer: no call, nothing held.
  NO_STATE = { "coming" => false, "pending" => nil, "notice" => nil, "come" => nil, "waited" => false, "follow" => nil, "holding" => false, "doing" => nil }

  # How the calls stand this frame, with the frame it was read at, see state.
  @state = nil
  # Whether the DLL may keep a call, a follow or the hold, so state reads it: set as one comes, unset
  # once the DLL answers that none stands.
  @active = false
  # The interpreter of the story scene the player holds for the party as leader, nil for none.
  @hold = nil
  # The names of the tellers whose offers to follow stand, by their id, mirroring the DLL's.
  @offers = {}
  # The values that move the world's story on as the player's telling started, see
  # note_story_progress; nil outside a Raid World.
  @told_progress = nil
  # The call whose wait for a busy player was logged: its name and start.
  @busy_logged = nil

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "co-op gather"

  # Counts the frames left until some frames after a moment have passed, for coop_teleport.rbx.
  #
  # @param since [Integer] The moment, a frame of the bridge.
  # @param frames [Integer] The frames.
  # @return [Integer] The frames left, 0 or less once they passed.
  def self.frames_left(since, frames)
    since + frames - MGQ_Multiplayer::Bridge.frame_number
  end

  # Reports whether a moment lies less than some frames back, for coop_teleport.rbx.
  #
  # @param since [Integer] The moment, a frame of the bridge.
  # @param frames [Integer] The frames.
  # @return [Boolean] Whether it does.
  def self.within?(since, frames)
    frames_left(since, frames) > 0
  end

  # Reads how the calls stand, once per frame: the call the player has yet to answer, where they
  # come to, the follow they take, the hold and the line above their head; a call that lapsed
  # tells the player so once.
  #
  # The DLL is asked only while a call, a follow or the hold may stand, since the map asks every
  # frame.
  #
  # @return [Hash] The state, see GatherTopics.Frame; NO_STATE while none stands or the DLL does
  #   not answer.
  def self.state
    return NO_STATE unless @active

    frame = MGQ_Multiplayer::Bridge.frame_number
    return @state[1] if @state && @state[0] == frame

    missing = @hold && MGQ_MpCoop.party_leading? ? self.missing : []
    answer = MGQ_Multiplayer::Bridge.call(FRAME_TOPIC, "settled" => settled?, "leading" => MGQ_MpCoop.party_leading?, "missing" => missing) || NO_STATE
    @state = [frame, answer]
    @active = false if answer["idle"]
    if answer["notice"]
      MGQ_MpOverworldSync.notice(answer["notice"])
      log("a call lapsed: #{answer['notice']}")
    end
    answer
  rescue => e
    log_once(:state, "reading the calls failed: #{e.class}: #{e.message}")
    NO_STATE
  end

  # Forgets the state read this frame, as a call changed it.
  def self.refresh
    @state = nil
  end

  # Reads the calls from the DLL again, as a call, a follow or the hold came.
  def self.wake
    @active = true
    refresh
  end

  # Forgets the leader's story scene the player holds and the leader's call, as when the world
  # closes or a save is loaded.
  def self.forget
    return unless @active || @hold

    forgotten = MGQ_Multiplayer::Bridge.call(FORGET_TOPIC)
    @hold = nil
    @active = false
    refresh
    return unless forgotten && (forgotten["held"] || forgotten["call"])

    dropped = []
    dropped << "the held story" if forgotten["held"]
    dropped << "#{forgotten['call']}'s call" if forgotten["call"]
    log("forgot #{dropped.join(', ')}")
  end

  # Forgets where the story was last told, whom it took along and the offers to follow its tellers,
  # as when the world closes.
  def self.forget_story_place
    @story_place = nil
    MGQ_Multiplayer::Bridge.call(FORGET_OFFERS_TOPIC) unless @offers.empty?
    @offers = {}
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
    place = fields["map"] ? " (map #{fields['map']} #{fields['x']},#{fields['y']})" : ""
    log("sent #{kind} to #{seat < 0 ? 'the party' : "seat #{seat}"}#{place}#{sent ? '' : ', which failed'}")
    sent
  end

  # Takes a message about gathering, handed over by coop_events.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    log("got #{message['pevent']} from #{MGQ_MpOverworldSync.who(peer)}#{message['map'] ? " (map #{message['map']} #{message['x']},#{message['y']})" : ''}")
    return take_raid(peer, message) if MGQ_MpCoop::Scope.raid?
    return log("ignored #{message['pevent']}: #{MGQ_MpOverworldSync.who(peer)} does not lead the party") unless MGQ_MpCoop.party_leader.equal?(peer)

    if %w(gather follow).include?(message["pevent"]) && !MGQ_MpCoopEvents.following?
      return log("ignored #{message['pevent']}: not synced with #{MGQ_MpOverworldSync.who(peer)}, the player plays their own story")
    end

    place = [message["map"].to_i, message["x"].to_i, message["y"].to_i, message["d"].to_i]
    case message["pevent"]
    when "gather" then called(peer, place)
    when "follow" then followed(peer, place)
    end
  rescue => e
    log("taking #{message['pevent']} failed: #{e.class}: #{e.message}")
  end

  # Takes a message about gathering in a Raid World, which gathers nobody: only the story's call
  # to follow where it moved its teller, sent to everyone who was on the teller's map. The player
  # follows at once only while they watch the teller's story and it moves the world's story on,
  # else it is offered, see offer_follow.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take_raid(peer, message)
    return log("ignored #{message['pevent']}: a Raid World gathers nobody") unless message["pevent"] == "follow"

    place = [message["map"].to_i, message["x"].to_i, message["y"].to_i, message["d"].to_i]
    reason = follow_refusal(peer, message)
    reason ? offer_follow(peer, place, reason) : followed(peer, place)
  end

  # Tells why the player does not follow a Raid World's teller at once where their story moved
  # them: only a player who watches that teller's story (the relay told of their telling, on the
  # player's track) and is not behind the world's does, and only when the telling moves the world's
  # story on (see moves_story?) or the player's game keeps its own copy of the telling's event that
  # runs by itself from starting.
  #
  # A talk that sets values of its own and moves its teller, as a minigame does, is sorted as story
  # too, which would pull every player watching along. A scene that runs by itself and moves its
  # teller without moving the story on would start again for every player left behind (issue 61).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  # @param message [Hash] The call's fields, "moves" false for a telling that does not move the world's
  #   story on; a call without it, from an earlier build, is followed at once as before.
  # @return [String, nil] The reason, nil when the player follows at once.
  def self.follow_refusal(peer, message)
    return "the player's story is behind the world's" if MGQ_MpCoopEvents.behind?
    return "the relay told of no telling of #{MGQ_MpOverworldSync.who(peer)}'s on the player's track" unless MGQ_MpCoop::Scope.watches?(peer)
    return nil unless message["moves"] == false
    return "#{MGQ_MpOverworldSync.who(peer)}'s telling does not move the world's story on" unless MGQ_MpCoopEvents.keeps_autorun_of?(peer)

    log("follows #{MGQ_MpOverworldSync.who(peer)} though their telling does not move the world's story on: the player's game keeps its own copy of the scene, which runs by itself, from starting")
    nil
  end

  # Offers the player in the notification box to follow a Raid World's teller whose story moved
  # them elsewhere, see Offers.notice_of; a newer move of the same teller replaces the offer.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  # @param place [Array<Integer>] Where the teller stands now: map, x, y and direction.
  # @param reason [String] Why the player does not follow at once, for the log.
  def self.offer_follow(peer, place, reason)
    id = peer.state["id"].to_s
    @offers[id] = peer.state["name"].to_s
    MGQ_Multiplayer::Bridge.call(OFFER_TOPIC, "id" => id, "name" => @offers[id], "place" => place)
    log("offered to follow #{MGQ_MpOverworldSync.who(peer)} to map #{place[0]} #{place[1]},#{place[2]} in the notification box: #{reason}")
  end

  # Finds the standing offer to follow a teller, dropping it once a telling the relay told of ended,
  # the player came to its map or it stood a minute.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  # @return [Hash, nil] The offer: :name, :place and :since; nil for none.
  def self.follow_offer(peer)
    id = peer.state["id"].to_s
    return nil unless @offers.key?(id)

    answer = MGQ_Multiplayer::Bridge.call(FOLLOW_OFFER_TOPIC, "id" => id, "telling" => MGQ_MpCoop::Scope.telling?(peer), "map" => $game_map.map_id)
    return { :name => answer["name"], :place => answer["place"], :since => answer["since"] } if answer && answer["name"]

    name = @offers.delete(id)
    log("dropped the offer to follow #{name}: #{answer ? answer['dropped'] : 'the DLL does not keep it'}")
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
    id = peer.state["id"].to_s
    offer = MGQ_Multiplayer::Bridge.call(ACCEPT_TOPIC, "id" => id, "telling" => MGQ_MpCoop::Scope.telling?(peer), "map" => $game_map.map_id)
    @offers.delete(id)
    return log("did not follow #{MGQ_MpOverworldSync.who(peer)}: the offer no longer stands") unless offer && offer["name"]

    followed(peer, offer["place"])
  rescue => e
    log("following a teller failed: #{e.class}: #{e.message}")
  end

  # Drops the offer to follow a teller, which the player declined.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
  def self.decline_follow(peer)
    id = peer.state["id"].to_s
    name = MGQ_Multiplayer::Bridge.call(DECLINE_TOPIC, "id" => id)
    @offers.delete(id)
    log("declined to follow #{name}") if name
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
    @hold = interpreter
    MGQ_Multiplayer::Bridge.call(HOLD_TOPIC)
    wake
    gather
    MGQ_MpOverworldSync.notice(GATHERING_TEXT)
    log("gathering the party for a story scene on map #{$game_map.map_id}, waiting for #{missing.join(', ')}")
  end

  # Forgets the story scene the player held, as when another event starts on the map.
  def self.drop_hold
    return unless @hold

    @hold = nil
    MGQ_Multiplayer::Bridge.call(DROP_HOLD_TOPIC)
    refresh
    log("stopped holding the story: another event started on the map")
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
  # every few seconds, and starting it without those who did not come after thirty seconds. Asked
  # before each of the interpreter's commands.
  #
  # @param interpreter [Game_Interpreter] The interpreter about to run a command.
  # @return [Boolean] Whether it waits.
  def self.holding?(interpreter)
    return false unless @hold && @hold.equal?(interpreter)

    names = missing
    answer = MGQ_Multiplayer::Bridge.call(HOLDING_TOPIC, "leading" => MGQ_MpCoopEvents.leading_story?, "gathered" => gathered?, "missing" => names)
    refresh
    return @hold = nil unless answer

    MGQ_MpOverworldSync.notice(answer["notice"]) if answer["notice"]
    log(answer["released"]) if answer["released"]
    if answer["call_again"]
      log("calling the party again, still waiting for #{names.join(', ')}")
      gather
    end
    @hold = nil unless answer["wait"]
    answer["wait"] ? true : false
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

  # Takes the leader's call to their story scene: the player comes over in a few seconds, unless
  # they stand near already; a PvP battle keeps it out, and a call takes over a teleport the player
  # asked for.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param place [Array<Integer>] Where the leader stands: map, x, y and direction.
  def self.called(peer, place)
    near = near_place?(own_place, place)
    pvp = MGQ_MpCoopEvents.pvp_running?
    answer = MGQ_Multiplayer::Bridge.call(CALLED_TOPIC, "name" => peer.state["name"].to_s, "id" => peer.state["id"].to_s, "place" => place, "near" => near, "pvp" => pvp)
    wake
    return log("stays: the player stands near #{peer.state['name']} already") if near
    return log_once([:duel_call, MGQ_Multiplayer::Bridge.frame_number / 1800], "a call came during a PvP battle, which keeps it out") if pvp

    MGQ_MpOverworldSync.notice(answer["notice"]) if answer && answer["notice"]
    log("called by #{peer.state['name']} to map #{place[0]} #{place[1]},#{place[2]}")
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
  # on the map, saying whether the telling moves the world's story on (see moves_story?), and their
  # games decide whether they follow at once (see take_raid). Called after
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
    if raid
      # The map's gate takes the call only for the map the others are on.
      fields["mmap"] = from[0]
      fields["moves"] = moves_story? ? true : false
      MGQ_MpCoopEvents.tell_each(along, "follow", fields)
    else
      along.each { |peer| tell(peer.seat, "follow", fields) }
    end
    offered = raid && fields["moves"] == false ? ", as an offer: the telling does not move the world's story on" : ""
    log("took #{along.map { |peer| peer.state['name'] }.join(', ')} along to map #{$game_map.map_id} #{$game_player.x},#{$game_player.y}#{offered}")
  rescue => e
    log("taking the party along failed: #{e.class}: #{e.message}")
  end

  # As teller in a Raid World, notes the values that move the world's story on as the telling
  # starts, see moves_story?. Called by coop_events.rbx as a new telling starts.
  def self.note_story_progress
    @told_progress = MGQ_MpCoop::Scope.raid? ? MGQ_MpCoopEvents.story_progress : nil
  rescue => e
    @told_progress = nil
    log("noting the story's progress failed: #{e.class}: #{e.message}")
  end

  # As teller in a Raid World, asks the DLL's one decision whether the telling moves the world's
  # story on, see MGQ_MpCoopEvents.moves_story?.
  #
  # @return [Boolean] Whether it does.
  def self.moves_story?
    MGQ_MpCoopEvents.moves_story?(@told_progress)
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
  # once, as soon as they are free. In a Raid World the follow waits a minute for that, as a
  # teleport the player asked for does, since the story calls once and the teller's pages, a battle
  # or a menu keep the player busy longer than a call lasts; a Classic leader's next scene calls
  # again.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param place [Array<Integer>] Where the leader stands now: map, x, y and direction.
  def self.followed(peer, place)
    log("following #{peer.state['name']} to map #{place[0]} #{place[1]},#{place[2]} as soon as the player is free")
    MGQ_Multiplayer::Bridge.call(FOLLOWED_TOPIC, "name" => peer.state["name"].to_s, "id" => peer.state["id"].to_s, "place" => place, "raid" => MGQ_MpCoop::Scope.raid?)
    wake
  end

  # Finds the follow the player takes: a teller's call to follow where their story moved them while
  # it stands and the player is on the way, and in a Raid World for a while after they arrived.
  #
  # A Raid World's teller is whoever the relay tells of, which it keeps on the map the telling
  # left while the story's next event has yet to start, and the player may arrive in that moment.
  #
  # @return [Hash, nil] The follow: the teller's :id and :name, and :place, their map, x, y and
  #   direction; nil for none.
  def self.follow_taken
    follow = state["follow"]
    follow ? { :id => follow["id"], :name => follow["name"], :place => follow["place"] } : nil
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

  # Notes where the story is told, by the player or by anyone else in the world, which a teleport
  # to the story goes to. Called after the map's update, in a Raid World alone.
  def self.note_story_place
    return unless MGQ_MpCoop::Scope.raid?

    if MGQ_MpCoopEvents.story_playing?
      @story_place = [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction]
      return
    end
    teller = MGQ_MpOverworldSync::Peers.present.find { |peer| MGQ_MpCoop::Scope.telling?(peer) }
    return unless teller

    @story_place = [teller.state["map"].to_i, teller.state["x"].to_i, teller.state["y"].to_i, teller.state["d"].to_i]
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

    come_to(STORY_NAME, place)
    MGQ_MpOverworldSync.notice("Teleporting to #{STORY_NAME} . . .")
  rescue => e
    log("teleporting to the story failed: #{e.class}: #{e.message}")
  end

  # Brings the player to a place the player asked to teleport to, as soon as they are free, within a
  # minute.
  #
  # @param name [String] Whom or what the place is, for the line above the player's head.
  # @param place [Array<Integer>] The map, x, y and direction.
  def self.come_to(name, place)
    log("teleporting to #{name} on map #{place[0]} #{place[1]},#{place[2]} as soon as the player is free")
    MGQ_Multiplayer::Bridge.call(COME_TO_TOPIC, "name" => name, "place" => place)
    wake
  end

  # Reports whether a call, a follow or a teleport is ready to bring the player over once they are
  # free, which the pages of the teller's story give way to (see MGQ_MpCoopEvents.page_done?): read on
  # the old map, they would keep the player busy while the story went on without them.
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
    state["coming"] ? true : false
  end

  # Reports whether a battle another player invites to belongs to the story that calls the player
  # over: its host is the player whose call stands, and it runs on the map the call leads to.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The battle's host.
  # @param map_id [Integer] The battle's map.
  # @return [Boolean] Whether it does.
  def self.calling_battle?(peer, map_id)
    MGQ_Multiplayer::Bridge.call(CALLING_BATTLE_TOPIC, "id" => peer.state["id"].to_s, "map" => map_id) ? true : false
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

  # Tells where the player comes to for the leader's story scene, once their frames passed and the
  # map settled.
  #
  # @return [Array<Integer>, nil] The leader's map, x, y and direction, nil while none or not yet.
  def self.come?
    state["come"]
  end

  # Reports whether the map settled enough to take the player elsewhere: no PvP battle runs or puts
  # the game back, and the screen is not fading.
  #
  # A duel puts its snapshot of the game back as the map starts again, and a transfer started then
  # would leave the screen black.
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
    name = MGQ_Multiplayer::Bridge.call(DROP_CALL_TOPIC)
    refresh
    log("dropped #{name}'s call: #{reason}") if name
  end

  # The leader's call the player has yet to answer, forgotten once the calls stopped.
  #
  # @return [Hash, nil] The call: :since, :name, :id, :place, :follow and :asked; nil for none.
  def self.pending_call
    call = state["pending"]
    return nil unless call

    { :since => call["since"], :name => call["name"], :id => call["id"], :place => call["place"], :follow => call["follow"], :asked => call["asked"] }
  end

  # Names what the player is doing for the line above their own head, if anything: as leader the
  # members the story still waits for and how long it holds, as member the time left before coming
  # over, or that they come once free.
  #
  # The leader's doing says "Gathering" as the notice of the story's call does, not "Waiting for"
  # as a battle's waiting box, since it names the same wait as that notice.
  #
  # @return [String, Array, nil] The doing, with the moment it lapses while one is known, nil for none.
  def self.own_doing
    doing = state["doing"]
    return nil unless doing

    doing["left"] ? [doing["text"], MGQ_MpActions.lapse_in(doing["left"])] : doing["text"]
  end

  # Reports whether the player has to stand still: while the story scene they see plays on the
  # player's map, their leader's or in a Raid World the teller's there. A member it started
  # without plays on elsewhere, and so does a player whose story does not match the teller's.
  #
  # A teller in the story's battle holds nobody: a player who came after its invites could
  # otherwise neither move nor join it until it ended. Nor does a telling nothing of which reached
  # the player for a while, see MGQ_MpCoop::Scope.silent?.
  #
  # @return [Boolean] Whether they do.
  def self.blocked?
    lead = MGQ_MpCoop::Scope.teller
    return false unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && MGQ_MpCoop::Scope.telling?(lead)
    return false unless lead.state["map"].to_i == $game_map.map_id && MGQ_MpCoop::Scope.watches?(lead)

    lead.state["scene"] != "battle" && !MGQ_MpCoop::Scope.silent?(lead)
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

  # Writes where the player stands.
  #
  # @return [Hash] "map", "x", "y" and "d".
  def self.place_fields
    { "map" => $game_map.map_id, "x" => $game_player.x, "y" => $game_player.y, "d" => $game_player.direction }
  end

  # Keeps a ban of the place the teller's scene set on the map the player is on the way to, which
  # the player takes on arriving.
  #
  # @param id [Integer] The ban's switch, see MGQ_MpStoryState::PLACE_BANS.
  # @param banned [Boolean] Whether it is on.
  # @param map [Integer] The teller's map.
  def self.take_place_ban(id, banned, map)
    kept = MGQ_Multiplayer::Bridge.call(BAN_TOPIC, "id" => id, "on" => banned ? true : false, "map" => map)
    log("ignored the teller's switch #{id}=#{banned} on map #{map}: the player is on map #{$game_map.map_id} and not on the way there") unless kept
  end

  # Moves the player to the leader once a story scene's frames passed, once the player is free: on
  # the map, with no event, message, transfer or battle of their own in the way. What a scene of the
  # player's own left under way, such as an ending's walk, and the place they leave are put back
  # first (see MGQ_MpFlowGuard.leave). Called after the map's update.
  def self.update
    # The map may have settled since the calls were read earlier this frame.
    refresh
    place = come?
    return note_busy unless place && MGQ_MpOverworldSync.map_free?

    taken = MGQ_Multiplayer::Bridge.call(TAKE_TOPIC, "raid" => MGQ_MpCoop::Scope.raid?)
    refresh
    return unless taken
    return log("dropped #{taken['name']}'s call: the player is no longer in a party") unless MGQ_MpCoop::Scope.sharing?

    map_id, x, y, direction = place
    unless map_id == $game_map.map_id || map_known?(map_id)
      MGQ_MpOverworldSync.notice("Cannot teleport to #{taken['name']}.")
      return log("dropped #{taken['name']}'s call to map #{map_id}: this game has no such map")
    end

    reason = taken["follow"] ? "the story moved them" : (taken["asked"] ? "the player asked to teleport" : "their story scene called")
    log("#{taken['follow'] ? 'followed' : 'came to'} #{taken['name']} on map #{map_id} #{x},#{y}, from map #{$game_map.map_id} #{$game_player.x},#{$game_player.y}: #{reason}")
    MGQ_MpCoopCastle.arriving(map_id) if defined?(MGQ_MpCoopCastle)
    elsewhere = map_id != $game_map.map_id
    MGQ_MpFlowGuard.leave("the player went to #{taken['name']}: #{reason}", false, elsewhere) if defined?(MGQ_MpFlowGuard)
    if elsewhere
      $game_player.reserve_transfer(map_id, x, y, direction > 0 ? direction : 2)
    else
      $game_player.moveto(x, y)
      $game_player.set_direction(direction) if direction > 0
    end
    taken["bans"].each { |id, banned| $game_switches[id] = banned }
  rescue => e
    log("coming to the leader failed: #{e.class}: #{e.message}")
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

  # Logs once per call why the player does not come to the leader yet, once the call's frames passed.
  def self.note_busy
    call = state["pending"]
    return unless call && state["waited"]

    key = [call["name"], call["since"]]
    return if @busy_logged == key

    @busy_logged = key
    log("waiting to come to #{call['name']}: #{settled? ? 'the player is busy with an event, a message, a screen or a transfer' : 'the map has not settled after a PvP battle or a fade'}")
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

  # A loaded save puts the player where the save stood, so the calls and the hold of before it go.
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
