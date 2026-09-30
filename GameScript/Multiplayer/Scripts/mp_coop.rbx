#----------------------------------------------------------------
#  mp_coop.rbx
#
#  Changelog:
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Everything players of a world do as a party: who is in the player's party, and the party's
# messages. The party scripts after it (mp_coop_events.rbx, mp_coop_npcs.rbx, mp_coop_story.rbx
# and mp_battle_coop.rbx) register here for their fields; this script takes those messages from
# mp_overworld_sync.rbx, drops those of another party, and hands on the rest.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoop
  # Tiles another player may be away, on the same map, to be invited or to accept.
  NEAR_TILES = 2

  # Frames an invite stands, fifteen seconds at 60 frames per second.
  INVITE_FRAMES = 900

  # Color of the invite line above a ghost's name and above the player's own head.
  INVITE_COLOR = Color.new(255, 224, 128)

  @routes = {}

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("co-op: #{message}")
  rescue
  end

  # Shows a notice at the bottom left of the map.
  #
  # @param text [String] The notice.
  def self.notice(text)
    MGQ_MpOverworldSync::Status.notice(text)
  end

  # Lists the other players of the world.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.peers
    MGQ_MpOverworldSync::Peers.all
  end

  # Hands the party's messages marked by a field to a script, once they come from another member
  # of the player's party.
  #
  # @param field [String] The field, such as "story".
  # @yieldparam peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @yieldparam message [Hash] The message's fields.
  def self.route(field, &handler)
    @routes[field] = handler
    MGQ_MpOverworldSync.route(field) { |peer, message| take(field, peer, message) }
  end

  # Takes a message of the party, dropping one of another party or from a player the game does not
  # know yet.
  #
  # @param field [String] The field that marks it.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(field, peer, message)
    return unless peer && Party.id && message["party"] == Party.id

    @routes[field].call(peer, message)
  end

  # Sends a message of the party to one member or to everyone, who ignore it outside the party.
  #
  # @param seat [Integer] The member's seat, -1 for everyone.
  # @param field [String] The field that marks it, such as "story".
  # @param value [Object] The field's value, such as the kind of message.
  # @param fields [Hash] Its other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, field, value, fields = {})
    message = { field => value, "party" => Party.id }.merge(fields)
    MGQ_MpOverworldSync::Link.send_to(seat, MGQ_MpOverworldSync::Me.encode(message))
  end

  # The fields the party adds to the state the player's game tells the others.
  #
  # @return [Hash] The fields.
  def self.state_fields
    { "party" => Party.id.to_s, "invite" => Party.inviting? ? 1 : 0 }
  end

  # Lets an invite run out, and forgets the party once no world is open. Called every frame in
  # every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    in_world ? Party.count_down : Party.reset
  end

  # Tells what the line above a ghost's name says: their invite, while they are outside the party.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  # @return [Array, nil] The text and its color, nil for none.
  def self.label_line(peer)
    peer.state["invite"] == "1" && !peer.member ? ["Invites to a party (B)", INVITE_COLOR] : nil
  end

  # The player's party: the others who share its id. Every game says its party's id and whether it
  # invites in the state it sends anyway, so joining needs no message of its own: a player who
  # accepts takes the inviter's id, and the inviter sees them join by it.
  module Party
    @id = nil
    @invite_frames = 0

    # The party's id, nil while the player is in none.
    #
    # @return [String, nil] The id.
    def self.id
      @id
    end

    # Reports whether the player invites to a party now.
    #
    # @return [Boolean] Whether they do.
    def self.inviting?
      @invite_frames > 0
    end

    # Reports whether another player is in the player's party.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether they are.
    def self.member?(state)
      !@id.nil? && state["party"] == @id
    end

    # Lists the other players in the party.
    #
    # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
    def self.members
      MGQ_MpCoop.peers.select { |peer| member?(peer.state) }
    end

    # Finds the party's leader: the member who made the party, whose id starts the party's id, or
    # the member with the lowest id while they are gone, so every member's game finds the same one.
    #
    # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil outside a party.
    def self.leader
      return nil unless @id

      candidates = [[MGQ_MpOverworldSync::Me.identity[0].to_s, :me]] + members.map { |peer| [peer.state["id"].to_s, peer] }
      maker = candidates.find { |id, _| !id.empty? && id[0, 8] == @id[0, 8] }
      (maker || candidates.min_by { |id, _| id })[1]
    end

    # Leaves the party and forgets any invite, as when the world closes.
    def self.reset
      @id = nil
      @invite_frames = 0
    end

    # Lets an invite run out, and forgets a party nobody joined. Called every frame.
    def self.count_down
      return unless @invite_frames > 0

      @invite_frames -= 1
      @id = nil if @invite_frames == 0 && members.empty?
    end

    # Invites the players nearby, making a party of one for them to join.
    def self.invite
      @id ||= "#{MGQ_Multiplayer::Link.player_id[0, 8]}#{rand(36**6).to_s(36)}"
      @invite_frames = INVITE_FRAMES
    end

    # Stops inviting, forgetting a party nobody joined.
    def self.stop_inviting
      @invite_frames = 0
      @id = nil if members.empty?
    end

    # Joins the party of a player who invites.
    #
    # @param inviter [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.join(inviter)
      left = @id && !members.empty?
      @id = inviter.state["party"]
      @invite_frames = 0
      MGQ_MpCoop.notice("#{left ? 'You left your party and joined' : 'You joined'} #{inviter.state['name']}'s party.")
      MGQ_MpCoop.peers.each { |peer| peer.member = member?(peer.state) }
    end

    # Leaves the party.
    def self.leave
      reset
      MGQ_MpCoop.notice("You left the party.")
      MGQ_MpCoop.peers.each { |peer| peer.member = false }
    end

    # Notices a player coming into or going out of the party, and stops inviting once one joined.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player, with what they just told.
    def self.observe(peer)
      member = member?(peer.state)
      return if member == peer.member

      peer.member = member
      if member
        @invite_frames = 0
        MGQ_MpCoop.notice("#{peer.state['name']} joined your party.")
      else
        MGQ_MpCoop.notice("#{peer.state['name']} left your party.")
      end
    end

    # Forgets a party nobody is left in once a member left the world.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.observe_leaving(peer)
      @id = nil if peer.member && members.empty? && !inviting?
    end

    # Reports whether another player stands near the player, on the same map.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether they do.
    def self.near?(state)
      state["map"].to_i == $game_map.map_id &&
        [(state["x"].to_i - $game_player.x).abs, (state["y"].to_i - $game_player.y).abs].max <= NEAR_TILES
    end
  end
end

# What the party takes part in of the world's messages, through mp_overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpCoop.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoop.state_fields }
  MGQ_MpOverworldSync.on_observe { |peer| MGQ_MpCoop::Party.observe(peer) }
  MGQ_MpOverworldSync.on_leave { |peer| MGQ_MpCoop::Party.observe_leaving(peer) }
  MGQ_MpOverworldSync.label_line { |peer| MGQ_MpCoop.label_line(peer) }
rescue => e
  MGQ_MpCoop.log("overworld sync FAILED: #{e.class}: #{e.message}")
end
