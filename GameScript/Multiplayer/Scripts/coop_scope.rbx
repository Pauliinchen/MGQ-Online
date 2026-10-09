#----------------------------------------------------------------
#  coop_scope.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# Whom the player shares the map and the story with: the party in a Classic world, everyone on the
# map in a Raid World. coop_npcs.rbx, coop_castle.rbx, coop_events.rbx, coop_gather.rbx and
# coop_scene.rbx ask MGQ_MpCoop::Scope instead of the party, and send their messages through it:
# through the party's gate (MGQ_MpCoop.route) in a Classic world, through the map's gate
# (MGQ_MpCoop.route_map) in a Raid World. The party chat, removing a member, invites and duels keep
# the party's gate in both; co-op battles use the map's gate in a Raid World (see battles_coop.rbx).
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoop
  # What starts the field of a message for the map's gate, so the party's gate and the map's never
  # take each other's messages.
  MAP_PREFIX = "map_"

  @map_routes = {}

  # Hands the messages marked by a field to a script, once they come from another player on the
  # player's map, or on the map the story takes the player to.
  #
  # @param field [String] The field, such as "npcs".
  # @yieldparam peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @yieldparam message [Hash] The message's fields, the field's value under the field itself.
  def self.route_map(field, &handler)
    @map_routes[field] = handler
    MGQ_MpOverworldSync.route(MAP_PREFIX + field) { |peer, message| take_map(field, peer, message) }
  end

  # Takes a message for the map's gate, dropping one from a player elsewhere or not known yet.
  #
  # @param field [String] The field the script registered.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take_map(field, peer, message)
    reason = map_drop_reason(peer, message)
    if reason
      sender = peer ? peer.state["id"] : nil
      Scope.log_once([:dropped, field, reason, sender], "dropped a #{field} message from #{MGQ_MpOverworldSync.who(peer)}: #{reason}")
      return
    end

    @map_routes[field].call(peer, message.merge(field => message[MAP_PREFIX + field]))
  end

  # Tells why the map's gate drops a message.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields; "mmap" names the map it is for.
  # @return [String, nil] The reason, nil when the gate takes it.
  def self.map_drop_reason(peer, message)
    return "the sender has not told their state yet" unless peer
    return "no map is set up" unless $game_map
    return nil if MGQ_MpOverworldSync::Peers.on_this_map?(peer) || Scope.story_map?(message["mmap"].to_i)

    "it is for map #{message['mmap']}, from a player on map #{peer.state['map']}, and the player is on map #{$game_map.map_id}"
  end

  # Sends a message through the map's gate to one player, or to everyone on the player's map.
  #
  # @param seat [Integer] The player's seat, -1 for everyone on the map.
  # @param field [String] The field that marks it, such as "npcs".
  # @param value [Object] The field's value.
  # @param fields [Hash] Its other fields; "mmap" names the map it is for, the player's by default.
  # @return [Boolean] Whether it went out to every seat.
  def self.tell_map(seat, field, value, fields = {})
    message = { MAP_PREFIX + field => value, "mmap" => $game_map.map_id }.merge(fields)
    return MGQ_MpOverworldSync.tell(seat, message) if seat >= 0

    Scope.peers_on($game_map.map_id).map { |peer| MGQ_MpOverworldSync.tell(peer.seat, message) }.all?
  end

  # Whom the player shares the map and the story with, by the type of the open world: Classic
  # shares within the party, Raid with everyone on the map. Each question goes to Classic or Raid.
  module Scope
    extend MGQ_MpLog

    # What starts this script's lines in Multiplayer InGame.log.
    LOG_TAG = "co-op scope"

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

    # Lists the other players the player shares the map with: the party members on it, or everyone on it.
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
    # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The teller, :me for the player, nil for none.
    def self.teller
      current.teller
    end

    # Lists the others whom the player's story is told to: the members synced with them, or the
    # players on the map whose story is where the player's was when the telling started.
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

    # Reports whether the player sees the teller's story: synced with the leader, or with a story
    # where the teller's was when the telling started.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
    # @return [Boolean] Whether they do.
    def self.watches?(peer)
      current.watches?(peer)
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

    # Reports whether the player shares the map with anyone at all: plays in a party, or in a Raid World.
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

    # Lists the other players on a map whose connection stands.
    #
    # @param map_id [Integer] The map.
    # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
    def self.peers_on(map_id)
      MGQ_MpOverworldSync::Peers.present.select { |peer| peer.state["map"].to_i == map_id }
    end

    # Finds the first of players by when they entered their map, then by their id.
    #
    # @param players [Array<MGQ_MpOverworldSync::Peers::Peer, Symbol>] The players, :me for the player.
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
      # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil outside a party.
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
    end

    # The scope of a Raid World: everyone on the map, party or not.
    module Raid
      # Lists the other players on the player's map whose connection stands.
      #
      # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
      def self.peers_here
        return [] unless MGQ_MpOverworldSync.in_world? && $game_map

        Scope.peers_on($game_map.map_id)
      end

      # Finds whose story the player shares: their own while they tell it, else of the players whose
      # state says they tell it on the player's map, or on the map the story takes the player to,
      # the one who entered their map first.
      #
      # A story that moves its teller onto a map where another player tells one goes on, since only
      # two tellings started at the same moment break the tie, see first_teller_here.
      #
      # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The teller, :me for the player, nil for none.
      def self.teller
        return :me if telling?

        Scope.first(MGQ_MpOverworldSync::Peers.present.select { |peer| peer.state["telling"] == "1" && Scope.story_map?(peer.state["map"].to_i) })
      end

      # Finds who of the players telling the story on the player's map, the player included while
      # telling, entered the map first: of two who start telling at the same moment, the one who
      # goes on.
      #
      # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The first, :me for the player, nil for none.
      def self.first_teller_here
        tellers = peers_here.select { |peer| peer.state["telling"] == "1" }
        tellers << :me if telling?
        Scope.first(tellers)
      end

      # Reports whether the player tells their story now, through coop_events.rbx.
      #
      # @return [Boolean] Whether they do.
      def self.telling?
        defined?(MGQ_MpCoopEvents) && MGQ_MpCoopEvents.telling? ? true : false
      end

      # Lists the players on the map, and those the story took along who are not there yet, whose
      # story is where the player's was when their telling started, which a player behind's is not.
      #
      # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
      def self.viewers
        told = told_markers
        return [] unless told

        along = defined?(MGQ_MpCoopGather) ? MGQ_MpCoopGather.taken_along : []
        (peers_here + along).uniq.select { |peer| markers(peer.state["sm"]) == told }
      end

      # Reports whether another player's story pages may reach the player: they tell the story here,
      # or nobody's state says so yet, since a teller's state and their pages travel apart.
      #
      # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
      # @return [Boolean] Whether they may.
      def self.story_from?(peer)
        lead = teller
        lead.nil? || lead.equal?(peer)
      end

      # Reports whether the player's story is where the teller's was when their telling started.
      #
      # @param peer [MGQ_MpOverworldSync::Peers::Peer] The teller.
      # @return [Boolean] Whether it is.
      def self.watches?(peer)
        theirs = markers(peer.state["tsm"]) || markers(peer.state["sm"])
        mine = own_markers
        !theirs.nil? && theirs == mine
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

      # Reads how far a story is, as a state tells it, through coop_story.rbx.
      #
      # @param text [String, nil] The values, comma separated.
      # @return [Array<Integer>, nil] The values, nil for none.
      def self.markers(text)
        defined?(MGQ_MpCoopStory) ? MGQ_MpCoopStory.read_markers(text) : nil
      end

      # How far the player's own story is, through coop_story.rbx.
      #
      # @return [Array<Integer>, nil] The values, nil before the game's variables exist.
      def self.own_markers
        defined?(MGQ_MpCoopStory) && $game_variables ? MGQ_MpCoopStory.own_markers : nil
      end

      # How far the player's story was when their telling started, or is now outside one.
      #
      # @return [Array<Integer>, nil] The values.
      def self.told_markers
        told = defined?(MGQ_MpCoopEvents) ? MGQ_MpCoopEvents.told_markers : nil
        told || own_markers
      end
    end
  end
end
