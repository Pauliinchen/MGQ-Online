#----------------------------------------------------------------
#  mp_coop.rbx
#
#  Changelog:
#      Paulinchen  2026-10-02: Named the key the player bound to the action wheel in the invite line above a ghost
#                            - Told whether the player plays in a party with someone else, for every party script
#                            - Told which page an event shows, for the party's events and NPCs
#                            - Turned away, as the leader, a player who joined a full party, and refused to join a full party
#                            - Kept the invite's frames and targets in MGQ_MpCoop::Invite, which duels share
#      Paulinchen  2026-10-01: Kept a party to four players, one per place of the Frontline
#                            - Invited a player anywhere in the world by their id, besides the players nearby
#                            - Told the size and the leader of any party, not only the player's own
#                            - Told Discord the size of the player's party through the Discord mod
#                            - Let only the leader invite, and let the leader remove members, whose games then leave the party
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Everything players of a world do as a party: who is in the player's party, and the party's
# messages. The party scripts after it (mp_coop_events.rbx, mp_coop_npcs.rbx, mp_coop_story.rbx
# and mp_battles_coop.rbx) register here for their fields; this script takes those messages from
# mp_overworld_sync.rbx, drops those of another party, and hands on the rest.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoop
  # Tiles another player may be away, on the same map, to be invited or to accept.
  NEAR_TILES = 2

  # Frames an invite stands, fifteen seconds at 60 frames per second.
  INVITE_FRAMES = 900

  # Players a party holds at most, one per place of the Frontline they share.
  MAX_PLAYERS = 4

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
    { "party" => Party.id.to_s, "invite" => Party.inviting? ? 1 : 0, "invite_to" => Party.targets.join(",") }
  end

  # Reports whether the player plays in a party of an open world with someone else in it.
  #
  # @return [Boolean] Whether they do.
  def self.in_party?
    MGQ_MpOverworldSync.in_world? && !Party.id.nil? && !Party.members.empty?
  end

  # Counts the players of a party, the player included when it is theirs.
  #
  # @param id [String, nil] The party's id.
  # @return [Integer] The players, 0 for no party.
  def self.size_of(id)
    return 0 if id.to_s.empty?

    peers.count { |peer| peer.state["party"] == id } + (id == Party.id ? 1 : 0)
  end

  # Finds the leader of a party: the player who made it, whose id starts the party's id, or the
  # player of it with the lowest id while they are gone, so every game finds the same one.
  #
  # @param id [String, nil] The party's id.
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil for no party.
  def self.leader_of(id)
    return nil if id.to_s.empty?

    candidates = peers.select { |peer| peer.state["party"] == id }.map { |peer| [peer.state["id"].to_s, peer] }
    candidates.unshift([MGQ_MpOverworldSync::Me.identity[0].to_s, :me]) if id == Party.id
    return nil if candidates.empty?

    maker = candidates.find { |player_id, _| !player_id.empty? && player_id[0, 8] == id[0, 8] }
    (maker || candidates.min_by { |player_id, _| player_id })[1]
  end

  # The fields the Discord mod publishes about the player's party, which Discord shows as its size,
  # such as "(2 of 4)".
  #
  # @return [Hash] The party's id and its players, none outside a world's party of two or more.
  def self.status_fields
    size = MGQ_MpOverworldSync.in_world? ? size_of(Party.id) : 0
    size >= 2 ? { "mp_party" => Party.id, "mp_party_size" => size, "mp_party_max" => MAX_PLAYERS } : {}
  end

  # Reports whether a player leads their party of two or more.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, Symbol] The player, :me for the player.
  # @return [Boolean] Whether they do.
  def self.leads?(peer)
    id = peer == :me ? Party.id : peer.state["party"]
    size_of(id) >= 2 && (peer == :me ? leader_of(id) == :me : leader_of(id).equal?(peer))
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
    peer.state["invite"] == "1" && !peer.member ? ["Invites to a party (#{MGQ_MpKeys.label(:wheel)})", INVITE_COLOR] : nil
  end

  # A standing invite of the player: to the players nearby, and to players anywhere named by their
  # id, for INVITE_FRAMES. The party and duels each keep one.
  class Invite
    # Starts with no invite standing.
    def initialize
      stop
    end

    # Reports whether another player's invite reaches the player: one who invites, standing near
    # or naming the player.
    #
    # @param state [Hash] What the other player last told.
    # @param flag [String] The state field that says they invite, such as "invite".
    # @param named [String] The state field with the ids they invite from afar, such as "invite_to".
    # @param anywhere [Boolean] Whether an invite naming the player counts wherever the inviter stands.
    # @return [Boolean] Whether it does.
    def self.reaches_me?(state, flag, named, anywhere = true)
      return false unless state[flag] == "1"

      Party.near?(state) || (anywhere && state[named].to_s.split(",").include?(MGQ_MpOverworldSync::Me.identity[0].to_s))
    end

    # Reports whether the invite stands.
    #
    # @return [Boolean] Whether it does.
    def inviting?
      @frames > 0
    end

    # The ids of the players the invite reaches wherever they are, besides those nearby.
    #
    # @return [Array<String>] The ids, none while no invite stands.
    def targets
      inviting? ? @targets : []
    end

    # Reports whether the invite reaches another player: standing near, or named.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether it does.
    def covers?(state)
      inviting? && (Party.near?(state) || @targets.include?(state["id"].to_s))
    end

    # Invites for INVITE_FRAMES from now, keeping the targets of an invite that stands.
    #
    # @param target_id [String, nil] The id of a player the invite reaches wherever they are.
    def invite(target_id = nil)
      @targets = [] unless inviting?
      @targets << target_id.to_s if target_id && !@targets.include?(target_id.to_s)
      @frames = INVITE_FRAMES
    end

    # Stops inviting.
    def stop
      @frames = 0
      @targets = []
    end

    # Lets the invite run out. Called every frame.
    #
    # @return [Boolean] Whether it ran out this frame.
    def count_down
      return false unless inviting?

      @frames -= 1
      return false if inviting?

      stop
      true
    end
  end

  # The player's party: the others who share its id. Every game says its party's id and whether it
  # invites in the state it sends anyway, so joining needs no message of its own: a player who
  # accepts takes the inviter's id, and the inviter sees them join by it.
  module Party
    @id = nil
    @invite = Invite.new

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
      @invite.inviting?
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
      MGQ_MpCoop.leader_of(@id)
    end

    # The ids of the players the invite reaches wherever they are, besides those nearby.
    #
    # @return [Array<String>] The ids, none while the player does not invite.
    def self.targets
      @invite.targets
    end

    # Reports whether another player's invite reaches the player: one who invites, outside the
    # player's party, standing near or naming the player.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @param anywhere [Boolean] Whether an invite naming the player counts wherever the inviter stands.
    # @return [Boolean] Whether it does.
    def self.invited_by?(peer, anywhere = true)
      !member?(peer.state) && Invite.reaches_me?(peer.state, "invite", "invite_to", anywhere)
    end

    # Reports whether a party holds as many players as it may.
    #
    # @param id [String, nil] The party's id, the player's own party's by default.
    # @return [Boolean] Whether it is full.
    def self.full?(id = @id)
      MGQ_MpCoop.size_of(id) >= MAX_PLAYERS
    end

    # Leaves the party and forgets any invite, as when the world closes.
    def self.reset
      @id = nil
      @invite.stop
    end

    # Lets an invite run out, and forgets a party nobody joined. Called every frame.
    def self.count_down
      @id = nil if @invite.count_down && members.empty?
    end

    # Invites the players nearby, and a player anywhere in the world when named, making a party of
    # one for them to join.
    #
    # @param target_id [String, nil] The id of a player the invite reaches wherever they are.
    def self.invite(target_id = nil)
      @invite.invite(target_id)
      @id ||= "#{MGQ_Multiplayer::Link.player_id[0, 8]}#{rand(36**6).to_s(36)}"
    end

    # Stops inviting, forgetting a party nobody joined.
    def self.stop_inviting
      @invite.stop
      @id = nil if members.empty?
    end

    # Joins the party of a player who invites.
    #
    # @param inviter [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.join(inviter)
      return MGQ_MpCoop.notice("#{inviter.state['name']}'s party is full.") if full?(inviter.state["party"])

      left = @id && !members.empty?
      @id = inviter.state["party"]
      @invite.stop
      MGQ_MpCoop.notice("#{left ? 'You left your party and joined' : 'You joined'} #{inviter.state['name']}'s party.")
      MGQ_MpCoop.peers.each { |peer| peer.member = member?(peer.state) }
    end

    # Leaves the party.
    def self.leave
      reset
      MGQ_MpCoop.notice("You left the party.")
      MGQ_MpCoop.peers.each { |peer| peer.member = false }
    end

    # Reports whether the player may invite more players: outside a party, or as its leader.
    #
    # @return [Boolean] Whether they may.
    def self.may_invite?
      members.empty? || leader == :me
    end

    # Removes a member from the party, as its leader: the member's game leaves it.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
    def self.remove(peer)
      return unless leader == :me && member?(peer.state)

      MGQ_MpCoop.tell(peer.seat, "kick", 1)
      MGQ_MpCoop.notice("You removed #{peer.state['name']} from the party.")
    end

    # Leaves the party once its leader removed the player, or turned them away from a full party.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who removed them, which counts only from the leader.
    # @param reason [String, nil] "full" when the party was full as the player joined.
    def self.removed_by(peer, reason = nil)
      return unless leader.equal?(peer)

      reset
      MGQ_MpCoop.notice(reason == "full" ? "#{peer.state['name']}'s party is full." : "#{peer.state['name']} removed you from the party.")
      MGQ_MpCoop.peers.each { |other| other.member = false }
    end

    # Notices a player coming into or going out of the party, and stops inviting once one joined.
    # As the leader, turns away a player who joined a party already full, since two players may
    # accept before either sees the other join.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player, with what they just told.
    def self.observe(peer)
      member = member?(peer.state)
      return if member == peer.member

      peer.member = member
      if member
        @invite.stop
        return turn_away(peer) if leader == :me && MGQ_MpCoop.size_of(@id) > MAX_PLAYERS

        MGQ_MpCoop.notice("#{peer.state['name']} joined your party.")
      else
        MGQ_MpCoop.notice("#{peer.state['name']} left your party.")
      end
    end

    # Sends a player who joined a full party away again, as its leader.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.turn_away(peer)
      MGQ_MpCoop.tell(peer.seat, "kick", "full")
      MGQ_MpCoop.notice("#{peer.state['name']} could not join, the party is full.")
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

class Game_Event
  # Tells which page the event shows, which the party's events and NPCs compare between games.
  #
  # @return [Integer] The page's index, -1 for none.
  def mgq_mp_page
    @page ? @event.pages.index(@page).to_i : -1
  end
end

# What the party takes part in of the world's messages, through mp_overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpCoop.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoop.state_fields }
  MGQ_MpOverworldSync.on_observe { |peer| MGQ_MpCoop::Party.observe(peer) }
  MGQ_MpOverworldSync.on_leave { |peer| MGQ_MpCoop::Party.observe_leaving(peer) }
  MGQ_MpOverworldSync.label_line { |peer| MGQ_MpCoop.label_line(peer) }
  MGQ_MpCoop.route("kick") { |peer, message| MGQ_MpCoop::Party.removed_by(peer, message["kick"]) }
rescue => e
  MGQ_MpCoop.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Discord shows the party's size, through the Discord mod's bridge when it is installed.
begin
  MGQ_Discord::Bridge.add_status { |_scene| MGQ_MpCoop.status_fields } if MGQ_Multiplayer::Discord.available?
rescue => e
  MGQ_MpCoop.log("status source FAILED: #{e.class}: #{e.message}")
end
