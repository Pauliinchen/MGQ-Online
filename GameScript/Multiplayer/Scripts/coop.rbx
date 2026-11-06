#----------------------------------------------------------------
#  coop.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Asked before removing a member or leaving the party through UI.confirm
#      Paulinchen  2026-11-05: Read the invites and the players they name as values
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#                            - Dropped register_option, the rows going into the Mod Framework's options
#                            - Left the party chat to the DLL's chat
#      Paulinchen  2026-10-23: Left the party, its invites and its message gate to the DLL, reading its view each frame
#                            - Made up ids through the DLL instead of the game's rand
#      Paulinchen  2026-10-17: Offered the teleport to the story on the action wheel
#      Paulinchen  2026-10-11: Told the frames an invite has left
#                            - Counted the invite's seconds down above the player's head
#                            - Asked before the World overview leaves the party or removes a member
#      Paulinchen  2026-10-10: Offered the teleport to the leader in a Raid World too
#      Paulinchen  2026-10-09: Closed the teleport to the story to players behind the world's story
#      Paulinchen  2026-10-08: Offered a teleport to the story in a Raid World
#      Paulinchen  2026-10-07: Added helpers the party scripts shared copies of
#                            - Logged invites, admissions, the leader and dropped party messages
#      Paulinchen  2026-10-06: Counted the player as a leader candidate only once admitted
#                            - Added party_leader and party_leading?
#                            - Added the party's choices to the action wheel by order
#      Paulinchen  2026-10-04: Handed the party chat's lines to ui_chat.rbx through the party's gate
#                            - Teleported to the leader through coop_gather.rbx
#                            - Renamed from mp_coop.rbx
#      Paulinchen  2026-10-03: Offered a party's members a teleport to its leader
#                            - Offered the party's choices and invites through MGQ_MpActions
#                            - Sent messages and read the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Counted only the players the leader admitted as members
#                            - Read the bound hotkeys through MGQ_MpHotkeys
#                            - Listed an event's pages
#                            - Let an invite to a player named from afar stand a minute
#                            - Declined party invites
#      Paulinchen  2026-10-02: Named the action wheel's hotkey in the invite line above a ghost
#                            - Told whether the player plays in a party
#                            - Told which page an event shows
#                            - Turned away joiners of a full party and refused to join one
#                            - Kept the invite's frames and targets in MGQ_MpCoop::Invite
#      Paulinchen  2026-10-01: Kept a party to four players
#                            - Invited a player anywhere in the world by their id
#                            - Told the size and the leader of any party
#                            - Told Discord the size of the player's party
#                            - Let only the leader invite and remove members
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Everything players of a world do as a party: who is in the player's party, and the party's
# messages. The DLL keeps the party (MGQOnline.Game's Party: invites, joining, admitting, turning
# away, leaving, the leader) and its message gate; this script reads the party's view the DLL
# posts, asks the DLL for the player's party actions, and offers them. The party scripts after it
# (coop_events.rbx, coop_scene.rbx, coop_npcs.rbx, coop_story.rbx, battles_coop.rbx and
# battles_duel.rbx) register here for their fields, as does the party chat of ui_chat.rbx, whose
# messages the DLL hands on only from the party's admitted members. Whether a script shares with
# the party or with the map is up to coop_scope.rbx.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoop
  # Tiles another player may be away, on the same map, to be invited or to accept.
  NEAR_TILES = 2

  # Frames a trade offer stands, fifteen seconds at 60 frames per second, as long as the DLL lets a
  # party invite stand.
  INVITE_FRAMES = 900

  # Frames an invite to a player named from afar stands, a minute: they first have to notice it in
  # the notification box (ui_notices.rbx) or the World overview.
  NAMED_INVITE_FRAMES = 3600

  # Players a party holds at most, one per place of the Frontline they share.
  MAX_PLAYERS = 4

  # Color of the invite line above a ghost's name and above the player's own head.
  INVITE_COLOR = MGQ_MpActions::LINE_COLOR

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "co-op"

  # Hands the party's messages marked by a field to a script, once the DLL's party gate let them
  # pass: from an admitted member of the player's party, naming it.
  #
  # @param field [String] The field, such as "story".
  # @yieldparam peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @yieldparam message [Hash] The message's fields.
  def self.route(field, &handler)
    MGQ_MpOverworldSync.route(field, "party", &handler)
  end

  # Names a player of the world by their id, for the log.
  #
  # @param player_id [String] The id.
  # @return [String] Their name, or the start of the id when nobody known has it.
  def self.name_of(player_id)
    return MGQ_MpOverworldSync::Me.identity[1].to_s if player_id.to_s == MGQ_MpOverworldSync::Me.id

    peer = MGQ_MpOverworldSync::Peers.all.find { |other| other.state["id"].to_s == player_id.to_s }
    peer ? peer.state["name"].to_s : player_id.to_s[0, 8]
  rescue
    player_id.to_s[0, 8]
  end

  # Counts the bytes of a message's fields, for the log.
  #
  # @param fields [Hash] The fields.
  # @return [Integer] Their keys' and values' bytes.
  def self.bytes_of(fields)
    fields.inject(0) { |sum, (key, value)| sum + key.to_s.bytesize + value.to_s.bytesize }
  rescue
    0
  end

  # Names an event of the map for the log.
  #
  # @param id [Integer] The event's id.
  # @return [String] A space and its name in quotes, empty for none.
  def self.event_name(id)
    event = $game_map.events[id]
    event && event.respond_to?(:mgq_mp_name) ? " '#{event.mgq_mp_name}'" : ""
  rescue
    ""
  end

  # The topic that makes up ids, from randomness of the DLL's own.
  RANDOM_ID_TOPIC = "id.random"

  # Makes up an id of random digits and letters, such as a party's or a battle's.
  #
  # The game's rand drives the replay seeds of battles, so an id drawn from it would shift them.
  #
  # @param length [Integer] How many characters.
  # @param radix [Integer] The base the id is written in, 36 for digits and letters.
  # @return [String] The id, empty while the DLL does not answer.
  def self.random_id(length, radix = 36)
    MGQ_Multiplayer::Bridge.call(RANDOM_ID_TOPIC, { "length" => length, "radix" => radix }).to_s
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
    MGQ_MpOverworldSync.tell(seat, message)
  end

  # Reports whether the player plays in a party of an open world with someone else in it.
  #
  # @return [Boolean] Whether they do.
  def self.in_party?
    MGQ_MpOverworldSync.in_world? && !Party.id.nil? && !Party.members.empty?
  end

  # Finds the leader of the player's party of an open world with someone else in it.
  #
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil outside such a party.
  def self.party_leader
    in_party? ? Party.leader : nil
  end

  # Reports whether the player leads a party with other members in it.
  #
  # @return [Boolean] Whether they do.
  def self.party_leading?
    party_leader == :me && !Party.members.empty?
  end

  # Counts the players of a party, the player included when it is theirs, as the party's view
  # tells.
  #
  # @param id [String, nil] The party's id.
  # @return [Integer] The players, 0 for no party.
  def self.size_of(id)
    return 0 if id.to_s.empty?

    Party.party_of(id)[0]
  end

  # Lists the other players of a party: of the player's own only those its leader admitted, of
  # another party everyone who names it.
  #
  # @param id [String] The party's id.
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.players_of(id)
    id == Party.id ? Party.members : MGQ_MpOverworldSync::Peers.all.select { |peer| peer.state["party"] == id }
  end

  # Finds the leader of a party, as the DLL finds it: the player who made it, or the one of it with
  # the lowest id while they are gone.
  #
  # @param id [String, nil] The party's id.
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil for no party.
  def self.leader_of(id)
    return nil if id.to_s.empty?

    Party.player_at(Party.party_of(id)[1])
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

  # Tells what the line above a ghost's name says: their invite, while they are outside the party.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  # @return [Array, nil] The text and its color, nil for none.
  def self.label_line(peer)
    peer.state["invite"] && !peer.member ? ["Invites to a party (#{MGQ_MpHotkeys.label(:wheel)})", INVITE_COLOR] : nil
  end

  # A standing invite of the player: to the players nearby, and to players anywhere named by their
  # id, for INVITE_FRAMES. A trade offer keeps one; the party's and the duel's are the DLL's.
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
      return false unless state[flag]

      Party.near?(state) || (anywhere && Array(state[named]).include?(MGQ_MpOverworldSync::Me.id))
    end

    # Reports whether the invite stands.
    #
    # @return [Boolean] Whether it does.
    def inviting?
      @frames > 0
    end

    # Tells the frames the invite stands for still.
    #
    # @return [Integer] The frames, 0 while no invite stands.
    def frames_left
      inviting? ? @frames : 0
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

    # Invites for INVITE_FRAMES from now, or NAMED_INVITE_FRAMES for a player named, keeping the
    # targets of an invite that stands and the longer time left.
    #
    # @param target_id [String, nil] The id of a player the invite reaches wherever they are.
    def invite(target_id = nil)
      @targets = [] unless inviting?
      @targets << target_id.to_s if target_id && !@targets.include?(target_id.to_s)
      @frames = [@frames, target_id ? NAMED_INVITE_FRAMES : INVITE_FRAMES].max
    end

    # Stops inviting.
    def stop
      @frames = 0
      @targets = []
    end

    # Stops naming a player, as once they declined; the invite still reaches them while they stand near.
    #
    # @param target_id [String] Their id.
    def drop(target_id)
      @targets.delete(target_id.to_s)
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

  # The player's party as the DLL keeps it (MGQOnline.Game's Party): its view, which the DLL posts
  # whenever it changed and answers after every action, and the actions themselves. The scripts read
  # it many times a frame, so every read is of the view, never a call.
  module Party
    # The view outside a party.
    NONE = {
      "id" => nil, "leader" => nil, "members" => [], "member_ids" => [], "admitted" => [], "admitted_me" => false,
      "inviting" => false, "invite_ends" => 0, "targets" => [], "inviters" => [], "may_invite" => true, "parties" => {},
    }

    # Where a party none of the players names stands: nobody in it, no leader.
    NO_PARTY = [0, nil]

    # The view as the DLL posted it last.
    @view = NONE

    # Takes the party's view, and whom of the players it counts.
    #
    # @param view [Hash] The view, see NONE for its fields.
    def self.take_view(view)
      return unless view.is_a?(Hash)

      @view = view
      MGQ_MpOverworldSync::Peers.take_members(view["members"])
    end

    # The party's id, nil while the player is in none.
    #
    # @return [String, nil] The id.
    def self.id
      @view["id"]
    end

    # Reports whether the player invites to a party now.
    #
    # @return [Boolean] Whether they do.
    def self.inviting?
      @view["inviting"] ? true : false
    end

    # Tells the frames the player's invite stands for still.
    #
    # @return [Integer] The frames, 0 while the player invites nobody.
    def self.invite_frames_left
      inviting? ? [@view["invite_ends"] - MGQ_Multiplayer::Bridge.frame_number, 0].max : 0
    end

    # The ids of the players the party's leader admitted, which the leader keeps and every member
    # takes from the leader.
    #
    # @return [Array<String>] The ids, none outside a party.
    def self.admitted
      @view["admitted"]
    end

    # Reports whether the player belongs to their party as its leader counts it: they made it, or
    # the leader admitted them since they joined.
    #
    # @return [Boolean] Whether they do.
    def self.admitted_me?
      @view["admitted_me"] ? true : false
    end

    # Reports whether another player is in the player's party, as the DLL counted them by their
    # last state.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether they are.
    def self.member?(state)
      !id.nil? && state["party"] == id && @view["member_ids"].include?(state["id"].to_s)
    end

    # Lists the other players in the party.
    #
    # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
    def self.members
      MGQ_MpOverworldSync::Peers.all.select { |peer| member?(peer.state) }
    end

    # Finds the leader of the player's party, as MGQ_MpCoop.leader_of finds it.
    #
    # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil outside a party.
    def self.leader
      player_at(@view["leader"])
    end

    # Tells a party's size and its leader's seat, as the view tells them.
    #
    # @param id [String] The party's id.
    # @return [Array(Integer, Integer)] The players, the player included in their own, and the
    #   leader's seat, -1 for the player, nil for none.
    def self.party_of(id)
      @view["parties"][id] || NO_PARTY
    end

    # Finds a player by the seat the view names them by.
    #
    # @param seat [Integer, nil] The seat, -1 for the player.
    # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The player, :me for the player, nil for
    #   none.
    def self.player_at(seat)
      return nil if seat.nil?

      seat < 0 ? :me : MGQ_MpOverworldSync::Peers.at(seat)
    end

    # The ids of the players the invite reaches wherever they are, besides those nearby.
    #
    # @return [Array<String>] The ids, none while the player does not invite.
    def self.targets
      @view["targets"]
    end

    # Reports whether another player's invite reaches the player: one who invites, outside the
    # player's party, standing near or naming the player.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [Boolean] Whether it does.
    def self.invited_by?(peer)
      @view["inviters"].include?(peer.seat)
    end

    # Reports whether a party holds as many players as it may.
    #
    # @param id [String, nil] The party's id, the player's own party's by default.
    # @return [Boolean] Whether it is full.
    def self.full?(id = self.id)
      MGQ_MpCoop.size_of(id) >= MAX_PLAYERS
    end

    # Reports whether the player may invite more players: outside a party, or as its leader.
    #
    # @return [Boolean] Whether they may.
    def self.may_invite?
      @view["may_invite"] ? true : false
    end

    # Invites the players nearby, and a player anywhere in the world when named, making a party of
    # one for them to join.
    #
    # @param target_id [String, nil] The id of a player the invite reaches wherever they are.
    def self.invite(target_id = nil)
      act("party.invite", target_id && target_id.to_s)
    end

    # Stops inviting, forgetting a party nobody joined.
    def self.stop_inviting
      act("party.stop_inviting")
    end

    # Joins the party of a player who invites.
    #
    # @param inviter [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.join(inviter)
      act("party.join", inviter.seat)
    end

    # Declines the invite of a player, telling them.
    #
    # @param inviter [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.decline(inviter)
      act("party.decline", inviter.seat)
    end

    # Leaves the party.
    def self.leave
      act("party.leave")
    end

    # Removes a member from the party, as its leader: the member's game leaves it.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
    def self.remove(peer)
      act("party.remove", peer.seat)
    end

    # Asks the DLL for an action of the party, and takes the view it answers.
    #
    # @param topic [String] The action's topic.
    # @param request [Object] What it takes, nil for nothing.
    def self.act(topic, request = nil)
      take_view(MGQ_Multiplayer::Bridge.call(topic, request))
    end

    # Reports whether another player stands near the player, on the same map, as duels and trades
    # count it; the party's own invites the DLL counts the same.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether they do.
    def self.near?(state)
      state["map"].to_i == $game_map.map_id &&
        [(state["x"].to_i - $game_player.x).abs, (state["y"].to_i - $game_player.y).abs].max <= NEAR_TILES
    end
  end

  # What the party offers between two players, through ui_actions.rbx: its choices on the action
  # wheel and in the World overview, and its invites in the overview and the notification box.
  module Offers
    # The wheel's party choice: as a party's member, teleporting to its leader; else accepting the
    # invite of a player nearby, or inviting the players nearby who are outside the party.
    #
    # @return [MGQ_MpActions::Option] The choice.
    def self.wheel_option
      teleport = teleport_option
      return teleport if teleport

      option = MGQ_MpActions::Option
      near = MGQ_MpOverworldSync::Peers.all.select { |peer| Party.near?(peer.state) && !Party.member?(peer.state) }
      inviter = near.find { |peer| peer.state["invite"] }
      if inviter
        full = Party.full?(inviter.state["party"])
        return option.new("Accept #{inviter.state['name']}'s invite", full ? nil : lambda { Party.join(inviter) }, "The party is full.")
      end
      refusal = invite_refusal("The party is full.")
      return option.new("Invite to a party", nil, refusal) if refusal

      option.new("Invite to a party", near.empty? ? nil : lambda { Party.invite }, "Nobody is near enough to invite.")
    end

    # The choice of a party's member that teleports them to the party's leader, see
    # MGQ_MpCoopTeleport.option.
    #
    # @return [MGQ_MpActions::Option, nil] The choice, nil for the leader and outside a party.
    def self.teleport_option
      lead = MGQ_MpCoop.party_leader
      return nil unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && defined?(MGQ_MpCoopTeleport)

      MGQ_MpCoopTeleport.option(lead)
    end

    # The choice that teleports the player to the story in a Raid World, which closes the World
    # overview too. A player behind the world's story cannot play it there, so it is closed to them.
    #
    # @return [MGQ_MpActions::Option, nil] The choice, nil in a Classic world.
    def self.story_option
      return nil unless Scope.raid? && defined?(MGQ_MpCoopGather)
      if defined?(MGQ_MpWorldCatchup) && MGQ_MpWorldCatchup.holds_story?
        return MGQ_MpActions::Option.new("Teleport to the story", nil, MGQ_MpWorldCatchup.refusal_text, nil, true)
      end

      known = !MGQ_MpCoopGather.story_endpoint.nil?
      MGQ_MpActions::Option.new("Teleport to the story", known ? lambda { MGQ_MpCoopGather.join_story } : nil, "Nobody has told the story yet.", nil, true)
    end

    # The wheel's choice that teleports the player to the story, as the World overview's does.
    #
    # @return [MGQ_MpActions::Option] The choice, closed in a Classic world.
    def self.wheel_story_option
      story_option || MGQ_MpActions::Option.new("Teleport to the story", nil, "Only a Raid World has a story to teleport to.")
    end

    # The wheel's choice that leaves the party, or stops an invite nobody took.
    #
    # @return [MGQ_MpActions::Option] The choice.
    def self.wheel_leave_option
      party_options(false).first || MGQ_MpActions::Option.new("Leave the party", nil, "You are in no party.")
    end

    # What the World overview asks before the leader removes a member, with the member's name.
    REMOVE_QUESTION = "Remove %s from the party?"

    # The choices of REMOVE_QUESTION.
    REMOVE_CHOICES = ["Remove", "Keep"]

    # What the World overview asks before the player leaves the party.
    #
    # The wheel's choices ask nothing, since picking a wheel's side and confirming it is a
    # deliberate pair of steps already.
    LEAVE_QUESTION = "Leave the party?"

    # The choices of LEAVE_QUESTION.
    LEAVE_CHOICES = ["Leave", "Stay"]

    # Asks a question in the Mod Framework's question box, its no lit first.
    #
    # @param question [String] The question.
    # @param choices [Array(String, String)] The yes and the no.
    # @yieldparam yes [Boolean] Whether the player said yes.
    def self.ask(question, choices, &answer)
      Mod_Framework::UI.confirm(question, :yes => choices[0], :no => choices[1], &answer)
    end

    # Tells why the player may not invite now.
    #
    # @param full [String] What to say of a full party.
    # @return [String, nil] The reason, nil while they may.
    def self.invite_refusal(full)
      return "Only the party's leader invites." unless Party.may_invite?

      Party.full? ? full : nil
    end

    # The party choice for another player in the World overview: accepting their invite, removing
    # them as the party's leader, which asks first, else inviting them, which only a leader or a
    # player outside a party may. The teleport to a member is coop_teleport.rbx's.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @return [MGQ_MpActions::Option, nil] The choice, nil for a member while the player does not lead.
    def self.peer_option(peer)
      option = MGQ_MpActions::Option
      if Party.invited_by?(peer)
        return option.new("Accept party invite", Party.full?(peer.state["party"]) ? nil : lambda { Party.join(peer) }, "Their party is full.")
      end
      if Party.member?(peer.state)
        return nil unless Party.leader == :me

        return option.new("Remove from party", lambda { ask(REMOVE_QUESTION % peer.state["name"], REMOVE_CHOICES) { |yes| Party.remove(peer) if yes } }, nil)
      end
      refusal = invite_refusal("Your party is full.")
      return option.new("Invite to party", nil, refusal) if refusal
      return option.new("Invited to party", nil, "Your invite to #{peer.state['name']} stands.") if Party.targets.include?(peer.state["id"].to_s)

      option.new("Invite to party", lambda { Party.invite(peer.state["id"]) }, nil)
    end

    # The choices on the player's own row of the World overview: leaving the party, which asks
    # first, stopping an invite, and in a Raid World the teleport to the story.
    #
    # @return [Array<MGQ_MpActions::Option>] The choices.
    def self.own_options
      party_options(true) + [story_option].compact
    end

    # The party choices of the player's own: leaving the party, and stopping an invite.
    #
    # @param asking [Boolean] Whether leaving asks the player first, as the World overview does.
    # @return [Array<MGQ_MpActions::Option>] The choices, none outside a party and without an invite.
    def self.party_options(asking)
      choices = []
      unless Party.members.empty?
        # The party may have dissolved while the box asked, and leaving none would still say so.
        leave = asking ? lambda { ask(LEAVE_QUESTION, LEAVE_CHOICES) { |yes| Party.leave if yes && !Party.members.empty? } } : lambda { Party.leave }
        choices << MGQ_MpActions::Option.new("Leave the party", leave, nil)
      end
      choices << MGQ_MpActions::Option.new("Stop inviting", lambda { Party.stop_inviting }, nil) if Party.inviting?
      choices
    end

    # Tells another player's party invite, when it reaches the player.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [Array, nil] The text and its color, nil for none.
    def self.call_of(peer)
      Party.invited_by?(peer) ? ["Invites you to a party", INVITE_COLOR] : nil
    end

    # Tells another player's party invite for the notification box, while it reaches the player
    # and their party has room.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Notice, nil] The invite, nil for none.
    def self.notice_of(peer)
      return nil unless Party.invited_by?(peer) && !Party.full?(peer.state["party"])

      MGQ_MpActions::Notice.new([:party, peer.seat], "#{peer.state['name']} invites you to a party", INVITE_COLOR, "Accept",
                                lambda { Party.join(peer) }, lambda { Party.decline(peer) }, peer.state["party"])
    end

    # Names what the player is doing for the line above their own head, with when it lapses.
    #
    # @return [Array, nil] That they invite and when the invite runs out, nil while they do not.
    def self.own_doing
      Party.inviting? ? ["Inviting to a party", MGQ_MpActions.lapse_in(Party.invite_frames_left)] : nil
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

  # Lists the event's pages, which tell a chest whichever page it shows.
  #
  # @return [Array<RPG::Event::Page>] The pages.
  def mgq_mp_pages
    @event.pages
  end

  # Tells the event's name in the editor, which the party's logs name an event by.
  #
  # @return [String] The name, empty for none.
  def mgq_mp_name
    @event ? @event.name.to_s : ""
  rescue
    ""
  end
end

# What the party takes part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.label_line { |peer| MGQ_MpCoop.label_line(peer) }
  MGQ_Multiplayer::Bridge.on("party.view") { |view| MGQ_MpCoop::Party.take_view(view) }
rescue => e
  MGQ_MpCoop.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What the party adds to the action wheel, the World overview and the notification box, through
# ui_actions.rbx.

begin
  MGQ_MpActions.offer(MGQ_MpCoop::Offers)
  MGQ_MpActions.wheel_choice(10) { MGQ_MpCoop::Offers.wheel_option }
  MGQ_MpActions.wheel_choice(40) { MGQ_MpCoop::Offers.wheel_leave_option }
  MGQ_MpActions.wheel_choice(45) { MGQ_MpCoop::Offers.wheel_story_option }
  MGQ_MpActions.own_doing_from { MGQ_MpCoop::Offers.own_doing }
rescue => e
  MGQ_MpCoop.log("actions FAILED: #{e.class}: #{e.message}")
end

# Discord shows the party's size, through the Discord mod's bridge when it is installed.
begin
  MGQ_Discord::Bridge.add_status { |_scene| MGQ_MpCoop.status_fields } if MGQ_Multiplayer::Discord.available?
rescue => e
  MGQ_MpCoop.log("status source FAILED: #{e.class}: #{e.message}")
end
