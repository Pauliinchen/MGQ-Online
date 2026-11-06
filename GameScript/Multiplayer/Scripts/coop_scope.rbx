#----------------------------------------------------------------
#  coop_scope.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Logged a silent telling once per player, without the frame in its key
#      Paulinchen  2026-11-05: Read whether another player tells the story as true or false
#                            - Handed the ids a map message names to the DLL as a list, which it writes
#                            - Counted the scope's times by the bridge's frame
#                            - Told whether the screens the mod opens on its own wait, while the followed teller tells or a battle's invite is open
#      Paulinchen  2026-10-28: Took a Raid World's tellers from the tellings the relay told of on the player's track, and its viewers from their tracks
#      Paulinchen  2026-10-24: Let a teller's telling hold the player no longer once nothing of it came for thirty seconds
#      Paulinchen  2026-10-23: Left the map's message gate to the DLL
#      Paulinchen  2026-10-12: Sent a Classic world's message for several members as one party message
#      Paulinchen  2026-10-11: Kept a viewer watching a Raid telling after taking its story values
#      Paulinchen  2026-10-10: Kept the followed teller while their state briefly tells nothing
#      Paulinchen  2026-10-09: Sent a message for the map or several players as one message
#                            - Counted a teller with a dropped connection as telling until forgotten
#                            - Preferred the teller who took the player along or whose pages they follow
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# Whom the player shares the map and the story with: the party in a Classic world, everyone on the
# map in a Raid World. coop_npcs.rbx, coop_castle.rbx, coop_events.rbx, coop_gather.rbx and
# coop_scene.rbx ask MGQ_MpCoop::Scope instead of the party, and send their messages through it:
# through the party's gate (MGQ_MpCoop.route) in a Classic world, through the map's gate
# (MGQ_MpCoop.route_map) in a Raid World; both gates are the DLL's (MGQOnline.Game's WorldRoom).
# The party chat, removing a member, invites and duels keep the party's gate in both; co-op battles
# use the map's gate in a Raid World (see battles_coop.rbx).
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoop
  # What starts the field of a message for the map's gate, so the party's gate and the map's never
  # take each other's messages.
  MAP_PREFIX = "map_"

  # The field of a message for the map's gate that names the ids of the players it is for, comma
  # separated; a message without it is for everyone on its map.
  TO_FIELD = "mto"

  # Hands the messages marked by a field to a script, once the DLL's map gate let them pass: from
  # another player on the player's map, or for it or the map the story takes the player to, and
  # naming the player in TO_FIELD when the message names anyone.
  #
  # @param field [String] The field, such as "npcs".
  # @yieldparam peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @yieldparam message [Hash] The message's fields, the field's value under the field itself.
  def self.route_map(field, &handler)
    MGQ_MpOverworldSync.route(MAP_PREFIX + field, "map") { |peer, message| handler.call(peer, message.merge(field => message[MAP_PREFIX + field])) }
  end

  # Sends a message through the map's gate to one player, or to everyone on the player's map.
  #
  # Everyone on the map gets one message to the whole world, which the map's gate of every game
  # sorts, since the relay ends a connection that sends more than its limit per second.
  #
  # @param seat [Integer] The player's seat, -1 for everyone on the map.
  # @param field [String] The field that marks it, such as "npcs".
  # @param value [Object] The field's value.
  # @param fields [Hash] Its other fields; "mmap" names the map it is for, the player's by default.
  # @return [Boolean] Whether it went out, true while nobody else is on the map.
  def self.tell_map(seat, field, value, fields = {})
    message = { MAP_PREFIX + field => value, "mmap" => $game_map.map_id }.merge(fields)
    return MGQ_MpOverworldSync.tell(seat, message) if seat >= 0
    return true if Scope.peers_on($game_map.map_id).empty?

    MGQ_MpOverworldSync.tell(-1, message)
  end

  # Sends one message through the map's gate to several players, whom it names in TO_FIELD, so
  # it costs one message whatever their number.
  #
  # @param peers [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  # @param field [String] The field that marks it, such as "pevent".
  # @param value [Object] The field's value.
  # @param fields [Hash] Its other fields; "mmap" names the map it is for, the player's by default.
  # @return [Boolean] Whether it went out, true for nobody.
  def self.tell_map_to(peers, field, value, fields = {})
    return true if peers.empty?
    return tell_map(peers.first.seat, field, value, fields) if peers.size == 1

    # Those the story took along may stand on another map, so the message goes out without asking
    # who is on the player's.
    message = { MAP_PREFIX + field => value, "mmap" => $game_map.map_id }.merge(fields)
    MGQ_MpOverworldSync.tell(-1, message.merge(TO_FIELD => peers.map { |peer| peer.state["id"].to_s }))
  end

  # Reports whether a screen the mod opens on its own, such as a replayed event's message or a
  # question of the catch-up, waits: while the teller whose story the player follows tells it, or
  # while a battle's invite is open for the player.
  #
  # A screen that opened between the teller's pages kept the player busy until the battle's
  # invite lapsed (issue 79).
  #
  # @return [Boolean] Whether it waits.
  def self.screens_wait?
    Scope.teller_tells? || (defined?(MGQ_MpBattlesCoop) && MGQ_MpBattlesCoop.invite_open?) ? true : false
  end

  # Whom the player shares the map and the story with, by the type of the open world: Classic
  # shares within the party, Raid with everyone on the map. Each question goes to Classic or Raid.
  module Scope
    extend MGQ_MpLog

    # What starts this script's lines in the log.
    LOG_TAG = "co-op scope"

    # Frames a teller's telling may hold the player while nothing of it reaches them, thirty
    # seconds, see silent?.
    #
    # A teller's game that said it told on the map for eight minutes and sent nothing kept every
    # player there from moving (issue 61).
    SILENT_FRAMES = 1800

    # Frames between two questions of silent? after which a hold counts as new, one second.
    HOLD_GAP_FRAMES = 60

    # The teller something of whose telling reached the player last: :teller, their player id,
    # :frame, when it came, and :asked, when silent? last asked; nil before any.
    @heard = nil

    # Notes that something of a teller's telling reached the player: a page, its end or a change
    # of the scene. Called by coop_events.rbx and coop_scene.rbx.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
    def self.heard_from(peer)
      @heard = { :teller => peer.state["id"].to_s, :frame => MGQ_Multiplayer::Bridge.frame_number, :asked => MGQ_Multiplayer::Bridge.frame_number }
    end

    # Reports whether a teller's telling that holds the player sent nothing of it for
    # SILENT_FRAMES, so it holds them no longer; a hold not asked about for HOLD_GAP_FRAMES starts
    # the count anew. Asked every frame of a hold by coop_gather.rbx and coop_events.rbx.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
    # @return [Boolean] Whether it did.
    def self.silent?(peer)
      now = MGQ_Multiplayer::Bridge.frame_number
      id = peer.state["id"].to_s
      heard = @heard
      @heard = heard = { :teller => id, :frame => now } unless heard && heard[:teller] == id && now - heard[:asked].to_i <= HOLD_GAP_FRAMES
      heard[:asked] = now
      return false if now - heard[:frame] < SILENT_FRAMES

      log_once([:silent, id], "#{MGQ_MpOverworldSync.who(peer)}'s telling holds the player no longer: nothing of it reached the player for #{SILENT_FRAMES / 60} s")
      true
    end

    # Reports whether a Raid World is open, through world.rbx.
    #
    # @return [Boolean] Whether one is.
    def self.raid?
      defined?(MGQ_MpWorld) && MGQ_MpWorld.respond_to?(:raid?) && MGQ_MpWorld.raid? ? true : false
    rescue
      false
    end

    # Finds the scope of the open world.
    #
    # @return [Module] Raid in a Raid World, else Classic.
    def self.current
      raid? ? Raid : Classic
    end

    # Lists the other players the player shares the map with: the party members on it, or everyone
    # on it.
    #
    # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
    def self.peers_here
      current.peers_here
    end

    # Finds the player whose game moves the map's events: of the player and the others given, the
    # one who entered the map first, the lower player id among equals, so every game finds the same.
    #
    # @param peers [Array<MGQ_MpOverworldSync::Peers::Peer>] The others on the map.
    # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol] The player, :me for the player.
    def self.sync_host(peers = peers_here)
      first([:me] + peers)
    end

    # Finds who tells the story the player shares: the party's leader, or the player telling it
    # on the player's map.
    #
    # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The teller, :me for the player, nil
    #   for none.
    def self.teller
      current.teller
    end

    # Lists the others whom the player's story is told to: the members synced with them, or the
    # players on the map who play the player's track.
    #
    # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
    def self.viewers
      current.viewers
    end

    # Reports whether another player's story pages may reach the player: they are the teller.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [Boolean] Whether they may.
    def self.story_from?(peer)
      current.story_from?(peer)
    end

    # Reports whether the player sees the teller's story: synced with the leader, or told of the
    # teller's telling by the relay, which tells of the tellings on the player's track alone.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
    # @return [Boolean] Whether they do.
    def self.watches?(peer)
      current.watches?(peer)
    end

    # Reports whether another player tells the story: their state says so in a Classic world, the
    # relay told of their telling in a Raid World.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [Boolean] Whether they do.
    def self.telling?(peer)
      current.telling?(peer)
    end

    # Reports whether the teller whose story the player follows tells it now.
    #
    # @return [Boolean] Whether they do.
    def self.teller_tells?
      teller = self.teller
      follows_teller? && teller.is_a?(MGQ_MpOverworldSync::Peers::Peer) && telling?(teller) ? true : false
    end

    # Reports whether another player tells the story the player shares, so the player's own story
    # events wait for them.
    #
    # @return [Boolean] Whether one does.
    def self.follows_teller?
      current.follows_teller?
    end

    # Reports whether the player tells their story to the others: as a leader with synced members,
    # or while nobody else tells it on the map.
    #
    # @return [Boolean] Whether they do.
    def self.leads_story?
      current.leads_story?
    end

    # Reports whether the player shares the map with anyone at all: plays in a party, or in a Raid
    # World.
    #
    # @return [Boolean] Whether they do.
    def self.sharing?
      current.sharing?
    end

    # Sends a message through the scope's gate.
    #
    # @param seat [Integer] A player's seat, -1 for everyone the scope reaches.
    # @param field [String] The field that marks it, such as "npcs".
    # @param value [Object] The field's value.
    # @param fields [Hash] Its other fields.
    # @return [Boolean] Whether it went out.
    def self.tell(seat, field, value, fields = {})
      current.tell(seat, field, value, fields)
    end

    # Sends a message through the scope's gate to several players.
    #
    # @param peers [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
    # @param field [String] The field that marks it, such as "pevent".
    # @param value [Object] The field's value.
    # @param fields [Hash] Its other fields.
    # @return [Boolean] Whether it went out to every one.
    def self.tell_each(peers, field, value, fields = {})
      current.tell_each(peers, field, value, fields)
    end

    # Lists the other players on a map whose connection stands.
    #
    # @param map_id [Integer] The map.
    # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
    def self.peers_on(map_id)
      MGQ_MpOverworldSync::Peers.present.select { |peer| peer.state["map"].to_i == map_id }
    end

    # Finds the first of players by when they entered their map, then by their id.
    #
    # @param players [Array<MGQ_MpOverworldSync::Peers::Peer, Symbol>] The players, :me for the
    #   player.
    # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The first, nil for none.
    def self.first(players)
      players.min_by { |player| key_of(player) }
    end

    # The order players on a map go by: when they entered it, then their id.
    #
    # @param player [MGQ_MpOverworldSync::Peers::Peer, Symbol] The player, :me for the player.
    # @return [Array] Milliseconds since 1970 and the id.
    def self.key_of(player)
      return [MGQ_MpOverworldSync::Me.map_since.to_i, MGQ_MpOverworldSync::Me.id.to_s] if player == :me

      [player.state["since"].to_i, player.state["id"].to_s]
    end

    # Reports whether a map is the player's, or the one the story takes them to, see
    # MGQ_MpCoopGather.story_map?.
    #
    # @param map_id [Integer] The map.
    # @return [Boolean] Whether it is.
    def self.story_map?(map_id)
      return MGQ_MpCoopGather.story_map?(map_id) if defined?(MGQ_MpCoopGather)

      $game_map && map_id == $game_map.map_id ? true : false
    end

    # The scope of a Classic world: the party.
    module Classic
      # Lists the other party members on the player's map whose connection stands.
      #
      # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
      def self.peers_here
        return [] unless MGQ_MpOverworldSync.in_world?
        return [] unless MGQ_MpCoop::Party.id

        MGQ_MpOverworldSync::Peers.all.select { |peer| peer.member && MGQ_MpOverworldSync::Peers.on_this_map?(peer) }
      end

      # Finds the party's leader, who tells the party's story.
      #
      # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil
      #   outside a party.
      def self.teller
        MGQ_MpCoop.party_leader
      end

      # Lists the members synced with the player's story, through coop_story.rbx.
      #
      # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
      def self.viewers
        defined?(MGQ_MpCoopStory) ? MGQ_MpCoopStory.synced_members : []
      end

      # Reports whether another player is the party's leader.
      #
      # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
      # @return [Boolean] Whether they are.
      def self.story_from?(peer)
        teller.equal?(peer)
      end

      # Reports whether the player follows the leader's story, through coop_events.rbx.
      #
      # @param _peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
      # @return [Boolean] Whether they do.
      def self.watches?(_peer)
        defined?(MGQ_MpCoopEvents) && MGQ_MpCoopEvents.following? ? true : false
      end

      # Reports whether the player follows the leader's story, through coop_story.rbx.
      #
      # @return [Boolean] Whether they do.
      def self.follows_teller?
        defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.follows_leader? ? true : false
      end

      # Reports whether the player leads members synced with their story, through coop_story.rbx.
      #
      # @return [Boolean] Whether they do.
      def self.leads_story?
        defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.leading_synced? ? true : false
      end

      # Reports whether another player tells the story, as their state says.
      #
      # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
      # @return [Boolean] Whether they do.
      def self.telling?(peer)
        peer.state["telling"] == true
      end

      # Reports whether the player plays in a party with someone else.
      #
      # @return [Boolean] Whether they do.
      def self.sharing?
        MGQ_MpCoop.in_party?
      end

      # Sends a message through the party's gate.
      #
      # @param seat [Integer] A member's seat, -1 for everyone, who ignore it outside the party.
      # @param field [String] The field that marks it.
      # @param value [Object] The field's value.
      # @param fields [Hash] Its other fields.
      # @return [Boolean] Whether it went out.
      def self.tell(seat, field, value, fields)
        MGQ_MpCoop.tell(seat, field, value, fields)
      end

      # Sends a message through the party's gate to several members: to a lone one by their seat,
      # to more as one message for the whole party, which those it is not for ignore, see
      # story_from? and watches?.
      #
      # @param peers [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
      # @param field [String] The field that marks it.
      # @param value [Object] The field's value.
      # @param fields [Hash] Its other fields.
      # @return [Boolean] Whether it went out, true for nobody.
      def self.tell_each(peers, field, value, fields)
        return true if peers.empty?
        return tell(peers[0].seat, field, value, fields) if peers.size == 1

        tell(-1, field, value, fields)
      end
    end

    # The scope of a Raid World: everyone on the map, party or not. Who tells is the relay's
    # word: the tellings it told of on the player's track (MGQ_MpWorldStory.telling_of), which
    # every game hears before the teller's first page; who views is whoever plays that track.
    module Raid
      # Lists the other players on the player's map whose connection stands.
      #
      # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
      def self.peers_here
        return [] unless MGQ_MpOverworldSync.in_world? && $game_map

        Scope.peers_on($game_map.map_id)
      end

      # Finds whose story the player shares: their own while they tell it, else of the players whose
      # telling the relay told of who stand on the player's map, or on the map the story takes the
      # player to, the one whose story took the player along or whose pages the player follows, else
      # the one whose story the player follows to where it moved them (followed_on_the_way), else
      # the one who entered their map first.
      #
      # The teller's own map, as their state tells it, says where their scene plays: the telling's
      # lock moves to a new map only with the story's next event there.
      #
      # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The teller, :me for the player, nil
      #   for none.
      def self.teller
        return :me if own_telling?

        candidates = tellers.select { |peer| Scope.story_map?(peer.state["map"].to_i) }
        followed_teller_ids.each do |id|
          followed = candidates.find { |peer| peer.state["id"].to_s == id }
          return followed if followed
        end
        followed_on_the_way || Scope.first(candidates)
      end

      # Finds the teller whose story the player follows to where it moved them, on that map, whether
      # or not their state says they tell, see MGQ_MpCoopGather.follow_taken.
      #
      # Their state says they tell nothing while the game's transfer process runs between the
      # story's events, and the follow ends by itself, so this stops on its own.
      #
      # @return [MGQ_MpOverworldSync::Peers::Peer, nil] The teller, nil for none.
      def self.followed_on_the_way
        return nil unless defined?(MGQ_MpCoopGather) && MGQ_MpCoopGather.respond_to?(:follow_taken)

        follow = MGQ_MpCoopGather.follow_taken
        return nil unless follow

        MGQ_MpOverworldSync::Peers.all.find { |peer| peer.state["id"].to_s == follow[:id] && peer.state["map"].to_i == follow[:place][0] }
      end

      # Lists the others whose telling the relay told of on the player's track, those whose
      # connection is down included while the relay keeps their lock.
      #
      # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
      def self.tellers
        MGQ_MpOverworldSync::Peers.all.select { |peer| telling?(peer) }
      end

      # Reports whether the relay told of another player's telling on the player's track, through
      # world_story.rbx.
      #
      # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
      # @return [Boolean] Whether it did.
      def self.telling?(peer)
        defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.telling_of(peer.seat) ? true : false
      end

      # Reports whether another player plays the player's track, as their state tells it.
      #
      # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
      # @return [Boolean] Whether they do.
      def self.same_track?(peer)
        track = defined?(MGQ_MpWorldStory) ? MGQ_MpWorldStory.track : nil
        track && peer.state["trk"].to_s == track ? true : false
      end

      # Names the tellers the player keeps over the order of the map: the one whose story takes the
      # player along now (MGQ_MpCoopGather.followed_id), then the one whose pages the player follows
      # (MGQ_MpCoopEvents.heard_from).
      #
      # @return [Array<String>] Their ids, the first kept first.
      def self.followed_teller_ids
        ids = []
        ids << MGQ_MpCoopGather.followed_id if defined?(MGQ_MpCoopGather) && MGQ_MpCoopGather.respond_to?(:followed_id)
        ids << MGQ_MpCoopEvents.heard_from if defined?(MGQ_MpCoopEvents) && MGQ_MpCoopEvents.respond_to?(:heard_from)
        ids.compact.map { |id| id.to_s }
      end

      # Reports whether the player tells their story now, through coop_events.rbx.
      #
      # @return [Boolean] Whether they do.
      def self.own_telling?
        defined?(MGQ_MpCoopEvents) && MGQ_MpCoopEvents.telling? ? true : false
      end

      # Lists the players on the map, and those the story took along who are not there yet, who
      # play the player's track (same_track?), which a player behind the world does not.
      #
      # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
      def self.viewers
        along = defined?(MGQ_MpCoopGather) && MGQ_MpCoopGather.respond_to?(:taken_along) ? MGQ_MpCoopGather.taken_along : []
        (peers_here + along).uniq.select { |peer| same_track?(peer) }
      end

      # Reports whether another player's story pages may reach the player: they tell the story here.
      #
      # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
      # @return [Boolean] Whether they may.
      def self.story_from?(peer)
        teller.equal?(peer)
      end

      # Reports whether the player sees the teller's story: the relay told of their telling, which
      # it does for the tellings on the player's track alone.
      #
      # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
      # @return [Boolean] Whether they do.
      def self.watches?(peer)
        telling?(peer)
      end

      # Reports whether another player tells the story here.
      #
      # @return [Boolean] Whether one does.
      def self.follows_teller?
        teller.is_a?(MGQ_MpOverworldSync::Peers::Peer)
      end

      # Reports whether the player may tell their story: nobody else tells it here.
      #
      # @return [Boolean] Whether they may.
      def self.leads_story?
        !follows_teller?
      end

      # Reports whether the player shares the map: a world is open.
      #
      # @return [Boolean] Whether one is.
      def self.sharing?
        MGQ_MpOverworldSync.in_world?
      end

      # Sends a message through the map's gate.
      #
      # @param seat [Integer] A player's seat, -1 for everyone on the map.
      # @param field [String] The field that marks it.
      # @param value [Object] The field's value.
      # @param fields [Hash] Its other fields.
      # @return [Boolean] Whether it went out.
      def self.tell(seat, field, value, fields)
        MGQ_MpCoop.tell_map(seat, field, value, fields)
      end

      # Sends one message through the map's gate to several players.
      #
      # @param peers [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
      # @param field [String] The field that marks it.
      # @param value [Object] The field's value.
      # @param fields [Hash] Its other fields.
      # @return [Boolean] Whether it went out.
      def self.tell_each(peers, field, value, fields)
        MGQ_MpCoop.tell_map_to(peers, field, value, fields)
      end
    end
  end
end
